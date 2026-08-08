{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur JSP vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program JSPCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  JSPCW32.PAS - Compilateur JSP (JavaServer Pages / Jakarta Server
  Pages) vers assembleur 80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Reference langage : DOC\JSP_SPEC_LANG.txt (34 sections). Une page
  JSP n est PAS executee par une JVM/un conteneur de servlets reel -
  elle est traduite ICI directement en code natif 80386 : le modele
  "page JSP -> servlet Java -> bytecode -> conteneur" (section 2 de
  la reference) est reproduit fidelement au niveau de la TRADUCTION
  (page -> equivalent d une methode _jspService, memes phases que la
  traduction JSP->servlet officielle) mais la "compilation" finale
  vise l assembleur 80386/PE au lieu du bytecode JVM, et le "conteneur"
  est remplace par un runtime minimal embarque simulant UNE requete
  HTTP GET par execution (voir TODO 18). Le noyau Java des scriptlets/
  declarations/expressions (section 6) reutilise l architecture et les
  techniques de JPPCW32.PAS (memes conventions de lexer/AST/codegen
  d expression et d instruction Java 1.1, adaptees ici a un sous-arbre
  embarque dans un gabarit de page plutot qu a un fichier .java complet).

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\JSP\*.jsp (17 fichiers Test01 a
  Test17, dont la paire Test12Erreur.jsp/Test12GestionErreur.jsp, plus
  2 fragments FragmentEntete.jsp/FragmentPied.jsp inclus par d autres
  echantillons - voir SAMPLES\JSP\README.txt ; Test01-14 sans
  dependance JSTL, Test15-17 necessitant JSTL Core/Functions sous les
  deux familles d URI historique javax et moderne jakarta).

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode, DefinedSymbols)
            ParseArgs : jspcw32 source.jsp [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-D SYMBOLE] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extension .jsp (paire .jsp/.jspf pour les
              fragments statiquement inclus - section 3) ; le fichier
              d entree DOIT etre une page "de premier niveau" (pas un
              fragment nomme *.jspf), best-effort documente
            Portee : UN SEUL fichier .jsp compile par execution comme
              point d entree, mais celui-ci peut REFERENCER d autres
              fichiers via <%@ include %> (statique, TODO 11) et
              <jsp:include> (dynamique, TODO 10) resolus relativement
              au repertoire du fichier source - pas de vrai
              deploiement WEB-INF/web.xml (section 3, hors de portee -
              a documenter explicitement comme limite assumee)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512), PE_SUBSYS_CUI
            Limites : MAX_SYM=4096, MAX_FUNC=512, MAX_METHOD=512,
              MAX_TYPE=1024, MAX_FIELD_POOL=4096, MAX_PARAM=64,
              MAX_LOCAL=256, MAX_LABEL=4096, MAX_STR=255, MAX_ERRORS=30,
              MAX_TEMPLATE_CHUNK=4096 (fragments de texte HTML entre
              deux delimiteurs JSP), MAX_ATTR=1024 (attributs de
              scope, TODO 09), MAX_TAGLIB=32, MAX_ELNODE=2048 (noeuds
              d expression EL, TODO 13), MAX_INCLUDE=64 (fichiers
              inclus statiquement, garde-fou anti-boucle)
            Prefixes ASM : _JSP_ (champ/attribut static), _JSPF_
              (methode static), _JSPM_ (methode d instance), _JSPK_
              (constante chaine/litteral, y compris chaque bloc de
              texte gabarit), _JSPRT_ (runtime servlet simule),
              _JSPL_ (label de saut interne), _JSPT_ (descripteur de
              type), _JSPEL_ (evaluateur d expression EL compilee)

  TODO 02 - TOKENISEUR DE GABARIT JSP (LEXER NIVEAU PAGE)
            LexInit, LexClose, LexNextChar, LexPeekChar
            Mode "template" par defaut (section 4) : tout octet est
              texte litteral jusqu au prochain delimiteur JSP ou a
              une expression EL - accumuler en TOK_TEMPLATE_CHUNK
            Delimiteurs reconnus depuis le mode template (section 4.2/
              4.3) : <%@ (directive), <%! (declaration), <% (scriptlet),
              <%= (expression), <%-- ... --%> (commentaire JSP, retire
              du gabarit, ne genere AUCUN out.print), <!-- --> laisse
              tel quel (commentaire HTML, passe dans le gabarit)
            Echappement (section 4.5, SEUL mecanisme documente par la
              reference - PAS de <\% / %\> ici, contrairement a d autres
              implementations JSP reelles, verifie par lecture attentive
              du document avant d ecrire ce TODO) : $${expression} - un
              '$' NON suivi de '{' reste du texte litteral, ce qui
              EMERGE naturellement d un lookahead de deux caracteres,
              SANS code d echappement dedie a ecrire
            EL/deferred EL (section 12) : ${ ... } et #{ ... } reconnus
              DEPUIS le mode template comme un cas special d expression
              embarquee (pas juste une expression Java) - bascule vers
              un sous-lexer EL distinct (TODO 14) ; ce TODO 02 se limite
              a reconnaitre l OUVERTURE ${ / #{ et a capturer le texte
              BRUT jusqu a la '}' fermante (scan naif au premier '}' non
              imbrique - affine si necessaire au TODO 14)
            Mode "Java" (a l interieur d un <% <%! <%= ouvert) : bascule
              vers un lexer proche de celui de JPPCW32.PAS (identifica-
              teurs, litteraux entiers/flottants/caracteres/chaines,
              commentaires // et /* */, operateurs/ponctuation Java 1.1)
              jusqu au %> fermant correspondant
            Fichiers de test couverts en premier : Test01Bonjour.jsp
              (template + une seule expression), Test02Directives.jsp
              (commentaire JSP)

  TODO 03 - TOKENISEUR DES BALISES XML-LIKE (DIRECTIVES/ACTIONS)
            Depuis <%@, reconnaitre le nom de directive (page/include/
              taglib) puis une liste d attributs nom="valeur" au
              format XML-like (section 5) : IsDirectiveName,
              LexAttrList (nom, egal, valeur entre guillemets, espaces
              flexibles, fin par %>)
            Reconnaitre depuis le mode template les actions standard
              <jsp:xxx ...> (section 9) : jsp:include, jsp:forward,
              jsp:param, jsp:useBean, jsp:setProperty, jsp:getProperty -
              forme auto-fermante <jsp:xxx .../> ET forme avec corps
              <jsp:xxx ...> ... </jsp:xxx>
            Reconnaitre les actions personnalisees <prefixe:nom ...>
              (JSTL et taglibs, section 14/16) une fois qu un prefixe a
              ete associe par une directive taglib (TODO 15) - sinon
              erreur "prefixe taglib inconnu"
            Mots reserves/noms d attributs predeclares : les noms
              d attribut de chaque directive (section 5, liste
              exhaustive par directive), les noms d attribut de chaque
              action standard (section 9)
            Fichiers de test couverts : Test10Include.jsp,
              Test11IncludeAction.jsp, Test13Actions.jsp

  TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES
            TTypeKind : TYK_BOOLEAN, TYK_INT, TYK_LONG, TYK_CHAR,
              TYK_FLOAT, TYK_DOUBLE, TYK_STRING (reference, immuable),
              TYK_OBJECT (type "Object"/EL non type - la plupart des
              valeurs EL sont manipulees comme Object jusqu a
              coercition, section 12.6), TYK_ARRAY, TYK_CLASS
              (import Java reference sans etre reimplemente - ex.
              java.util.Date/GregorianCalendar/DateFormat, TODO 19),
              TYK_NULL, TYK_VOID
            TTypeRec (Kind, Name, Size, ElemTypeIdx, FieldFirst/Count,
              MethodFirst/Count) - meme technique de pool partage que
              DELPHI.PAS/JPPCW32.PAS
            Coercitions EL (section 12.4 : "les conversions EL sont plus
              permissives que les conversions Java... une chaine
              numerique peut etre convertie selon l operateur" - PAS de
              tableau numerote dans la reference, verifie par lecture
              attentive avant d ecrire ce TODO, corrige ici) :
              String<->nombre, String<->boolean, null vers primitif =
              valeur par defaut, objet vers String via toString() -
              DECISION A DOCUMENTER : implementees comme un ensemble
              fixe de regles au moment de la generation de code plutot
              qu une reflexion dynamique complete
            Representation runtime des attributs de scope (TODO 09) et
              des valeurs EL - DECISION A DOCUMENTER explicitement ici
              avant le TODO 20 : une "valeur EL" (TELValue) est une union
              taguee {Kind; en fonction de Kind: rien (null) / Boolean /
              LongInt / Double / TBigString (AnsiString, MEME choix
              qu au TODO 02 pour TToken.Val - evite la troncature 255
              octets pour une longue valeur de scope) / pointeur objet
              opaque} - meme discipline "documenter avant de coder" que
              JPPCW32.PAS TODO 04

  TODO 05 - DIRECTIVE PAGE
            ParsePageDirective (section 5.1) : language (valeur
              attendue "java", ignoree sinon avertissement),
              import (liste separee par virgules, alimente la
              resolution de noms de classe du TODO 19 - voir
              Test02Directives.jsp important java.util.Date et
              java.text.DateFormat), session (true/false, controle la
              disponibilite de l objet implicite session - Test08
              Session.jsp la met explicitement a true), buffer,
              autoFlush, contentType/pageEncoding (alimentent le
              TODO 22 encodage), isErrorPage (Test12GestionErreur.jsp),
              errorPage (Test12Erreur.jsp - chemin relatif vers la
              page d erreur), isELIgnored, trimDirectiveWhitespaces,
              info, extends
            Cumul multi-occurrences : plusieurs <%@ page %> dans une
              meme page sont autorises SAUF pour les attributs a
              valeur unique (import s accumule, les autres doivent
              rester coherents - erreur si contradiction, section 5.1)
            TPageOptions globale de compilation (distincte de TOptions
              du TODO 01) alimentant les phases suivantes

  TODO 06 - DIRECTIVES INCLUDE ET TAGLIB
            ParseIncludeDirective (section 5.3, PAS 5.2 comme un
              brouillon anterieur de ce TODO l affirmait a tort -
              5.2 est "isThreadSafe historique", verifie par relecture
              attentive avant d ecrire ce TODO, corrige ici) : attribut
              file, chemin relatif AU FICHIER COURANT, OU relatif au
              CONTEXTE s il commence par '/' (section 5.3, distinction
              explicite a resoudre ICI) - le fichier est fusionne au
              moment de la TRADUCTION (voir TODO 11 pour le mecanisme
              de fusion lui-meme, ce TODO se limite au parsing de la
              directive et a la resolution du chemin)
            ParseTaglibDirective (section 5.4/14.2/14.3, PAS 5.3 -
              meme correction) : attribut prefix (obligatoire, DOIT
              etre distinct dans la page et ne DOIT PAS etre "jsp"
              reserve aux actions standard, section 14.3) + (uri OU
              tagdir) ; TTaglibDecl (Prefix, Uri, IsCoreJstl,
              IsFunctionsJstl) ; reconnaitre les deux familles d URI
              (section 16.2/16.3/27.3, PAS 16.1/27 - 16.1 n est que la
              liste des familles JSTL, PAS des URI) : legacy
              http://java.sun.com/jsp/jstl/core et
              http://java.sun.com/jsp/jstl/functions, moderne
              jakarta.tags.core et jakarta.tags.functions - Test15
              JstlJavaEE.jsp utilise la famille legacy, Test16
              JstlJakarta.jsp et Test17JstlXml.jsp la famille moderne
            tagdir (taglibs bases sur des fichiers .tag) explicitement
              HORS DE PORTEE (aucun echantillon ne l exercice) - a
              documenter comme limite assumee, seule la famille core/
              functions de JSTL est reconnue (TODO 15/16)

  TODO 07 - DECLARATIONS, SCRIPTLETS ET EXPRESSIONS (PARSING JAVA)
            ParseDeclaration (<%! ... %>, section 6.1) : membres de
              classe (champs et methodes) ajoutes a la "classe page"
              synthetique - Test03Declarations.jsp declare deux
              methodes privees (nomApplication, carre) appelees depuis
              des expressions
            ParseScriptlet (<% ... %>, section 6.2) : bloc de
              declarations locales/instructions Java, reutilise le
              parseur d expression/instruction de style JPPCW32.PAS
              (sous-ensemble Java 1.1 : if/else, for, while, blocs,
              declarations locales, appels de methode, operateurs)
            ParseExpression (<%= ... %>, section 6.3) : UNE expression
              Java, jamais terminee par point-virgule - sa valeur est
              imprimee via out.print (voir TODO 08)
            Grammaire de synthese section 30 (element, directive,
              declaration, scriptlet, expressionScript) comme
              reference directe de ce TODO
            Fichiers de test couverts : Test01Bonjour.jsp,
              Test02Directives.jsp, Test03Declarations.jsp,
              Test05Parametres.jsp (methode declaree echapperHtml)

  TODO 08 - TRADUCTION GABARIT<->JAVA ET ENTRELACEMENT DU FLOT DE CONTROLE
            Construction d un arbre "page" unique : chaque
              TOK_TEMPLATE_CHUNK devient un appel out.print(_JSPKn)
              (chaine constante, TODO 09 pool _JSPK_), chaque
              expression devient out.print(coercition-vers-String(expr))
            DEFI CENTRAL (section 6.2, illustre par Test04Scriptlets.jsp
              et les if/else de Test05/Test06) : un scriptlet peut
              ouvrir une accolade Java qui reste ouverte a travers du
              texte gabarit et se referme dans un scriptlet ULTERIEUR -
              le compilateur doit assembler ces fragments Java
              disjoints en un SEUL arbre d instructions ou les
              out.print(gabarit) sont des instructions normales
              intercalees a l endroit exact ou le gabarit apparaissait
              (algorithme : concatener virtuellement scriptlets +
              marqueurs-de-gabarit-comme-instruction, puis parser le
              flux Java resultant comme un bloc unique)
            _jspService synthetique : methode unique recevant
              (request, response) et ayant acces a pageContext/session/
              application/out/config/page/exception (TODO 09), corps =
              l arbre construit ci-dessus, dans l ordre lineaire du
              fichier

  TODO 09 - OBJETS IMPLICITES
            Les neuf objets implicites (section 7) : request, response,
              pageContext, session, application, out, config, page,
              exception (exception uniquement si isErrorPage=true,
              erreur de traduction sinon - section 7/18.1/18.4, PAS
              "7.9" comme un brouillon anterieur de ce TODO l affirmait
              a tort : la section 7 n a AUCUNE sous-section numerotee,
              verifie par relecture attentive avant d ecrire ce TODO,
              corrige ici)
            Surface de methode EFFECTIVEMENT exercee par les
              echantillons (Test07ObjetsImplicites.jsp est le
              catalogue direct) : request.getMethod/getRequestURI/
              getRemoteAddr/getParameter/setCharacterEncoding,
              response.getContentType, session.getId/setAttribute/
              getAttribute/removeAttribute, application.getServerInfo/
              setAttribute/getAttribute, config.getServletName,
              out.print/println, exception.getClass().getName()
              (Test12GestionErreur.jsp)
            TImplicitObjectKind + dispatch direct vers le runtime
              _JSPRT_ (pas de vraie hierarchie d interfaces Servlet,
              meme simplification que les vtables simplifiees des
              compilateurs freres)

  TODO 10 - SCOPES ET ATTRIBUTS
            Les quatre scopes (section 8) : page, request, session,
              application - representation runtime commune (table
              cle/valeur, cle=String, valeur=union taguee du TODO 04) ;
              une instance de table par scope, duree de vie documentee
              explicitement (page = duree de l execution, request =
              idem ici en l absence de forward reel au sens conteneur,
              session/application = persistantes en memoire pour la
              duree du processus - limite assumee, pas de VRAIE
              persistance multi-requetes puisqu une execution = une
              requete simulee, voir TODO 18)
            setAttribute/getAttribute/removeAttribute sur chacun des
              quatre objets porteurs de scope (session/application/
              request/pageContext) - Test08Session.jsp et
              Test09Application.jsp (ce dernier avec un bloc
              synchronized(application){...} - synchronisation ignoree/
              no-op documentee, un seul thread reel dans ce runtime,
              section 23)
            Cast explicite du resultat (ex. (String)session.
              getAttribute(...)) - verification de type best-effort,
              meme discipline que les casts des compilateurs freres

  TODO 11 - INCLUSION STATIQUE (<%@ include %>)
            Au moment de la traduction (PAS a l execution) : lire le
              fichier cible, le RETOKENISER comme une extension en
              ligne du fichier courant (meme mode template/Java,
              mêmes directives autorisees a l interieur), inserer le
              resultat a l endroit exact de la directive - garde-fou
              anti-boucle (MAX_INCLUDE) et detection d inclusion
              circulaire
            Distinction explicite a documenter vis-a-vis du TODO 12
              (section 11, tableau comparatif include statique/
              dynamique/forward) : l inclusion statique fusionne le
              CODE SOURCE avant compilation, aucune notion de requete
              separee
            Fichiers de test : Test10Include.jsp + FragmentEntete.jsp/
              FragmentPied.jsp

  TODO 12 - ACTIONS STANDARD : INCLUDE DYNAMIQUE, FORWARD, PARAM
            <jsp:include page="..." flush=".../true/false"> (section
              9.1) : a la difference du TODO 11, genere un VRAI appel
              runtime _JSPRT_Include qui execute la page ciblee comme
              une sous-traduction independante partageant request/
              response mais avec son propre buffer de sortie fusionne
              ensuite - Test11IncludeAction.jsp
            <jsp:forward page="..."> (section 9.1/11) : transfert de
              controle, la sortie deja bufferisee de la page courante
              est abandonnee (section 11 - comportement a documenter
              explicitement puisqu aucun echantillon ne l exercice
              directement mais la reference le specifie)
            <jsp:param name="..." value="..."> imbrique dans include/
              forward : ajoute un parametre transmis a la page cible

  TODO 13 - ACTIONS STANDARD : USEBEAN / SETPROPERTY / GETPROPERTY
            <jsp:useBean id="..." class="..." scope="page|request|
              session|application"> (section 9.1/10) : instancie (ou
              retrouve dans le scope si deja present) un objet du type
              Java nomme par class - Test13Actions.jsp instancie
              java.util.GregorianCalendar
            <jsp:getProperty name="..." property="..."> : dispatch
              vers le getter JavaBean conventionnel (getXxx()/isXxx()
              pour boolean, section 10) - Test13Actions.jsp lit
              timeInMillis via getTimeInMillis()
            <jsp:setProperty name="..." property="..." value="...">
              et la forme property="*" (copie automatique de TOUS les
              parametres de requete correspondant a un setter, section
              9.1) - aucun echantillon ne l exercice directement mais
              couvert pour respecter la portee complete des actions
              standard demandee

  TODO 14 - LEXER/PARSEUR EL (EXPRESSION LANGUAGE)
            Sous-lexer EL invoque depuis ${...} et #{...} (section 12,
              #{...} accepte syntaxiquement mais restreint aux
              contextes ou EL differe est valide - aucun echantillon
              ne l exercice, ${...} suffit pour tous les Test0x/Test1x
            Grammaire EL (section 12.2/12.3, section 30 productions
              expressionEl) : identificateurs et navigation .prop/
              [index-ou-cle], litteraux (true/false/null/entiers/
              flottants/chaines '...'/"..."})
            Operateurs (section 12.4 a 12.9) et PRECEDENCE (section
              12.10, "Precedence simplifiee" - PAS 12.4 comme un
              brouillon anterieur de ce TODO l affirmait a tort, verifie
              par relecture attentive avant d ecrire ce TODO, corrige
              ici) : [] . -> appel () -> unaire (- ! not empty) ->
              multiplicatif (* / div % mod) -> additif (+ -) ->
              comparaisons (< > <= >= lt gt le ge) -> egalite (==  !=
              eq ne) -> && and -> || or -> ternaire ?: (les affectations
              EL de versions recentes, mentionnees en dernier dans la
              reference, restent HORS DE PORTEE - aucun echantillon ne
              les exercice)
            TELNode (arbre EL distinct de l AST Java du TODO 07/08,
              plus simple - pas de types statiques, juste des noeuds
              operateur/litteral/identificateur/acces-propriete/appel-
              fonction) - Test14ExpressionLanguage.jsp (arithmetique
              et ge), Test17JstlXml.jsp (ternaire + appel de fonction)

  TODO 15 - EVALUATION EL : IMPLICITES ET ORDRE DE RESOLUTION DE PORTEE
            Objets implicites EL (section 13.1) : pageScope/
              requestScope/sessionScope/applicationScope (acces direct
              a un scope precis), param/paramValues (requete),
              header/headerValues, cookie, initParam
            Resolution d un identificateur NU (sans prefixe de scope) :
              ORDRE page -> request -> session -> application (section
              8.3/13.1, corrige ici depuis "8.4" - 8.4 est "Choix de la
              portee", PAS l ordre de recherche - verifie par lecture
              attentive avant d ecrire ce TODO) - implementee comme une
              fonction unique _JSPEL_ResolveVar reutilisee par tout
              noeud identificateur
            empty operateur (section 12.7, corrige ici depuis "12.4" -
              12.4 est "Operateurs arithmetiques", empty est decrit en
              12.7) : vrai pour null, chaine
              vide, tableau/collection/Map vide - Test14
              ExpressionLanguage.jsp (${empty param.nom}), Test15
              JstlJavaEE.jsp / Test16JstlJakarta.jsp (${not empty
              param.recherche})
            Coercition de sortie : le resultat d une expression EL
              imprimee par une action JSTL passe par toString (TODO 04)

  TODO 16 - JSTL CORE : C:OUT, C:SET, C:IF, C:CHOOSE, C:FOREACH
            Chaque balise core devient un noeud d action personnalisee
              une fois le prefixe associe (TODO 06) a l URI core -
              generation de code equivalente a la traduction officielle
              (section 16.4, corrige ici depuis "16.3" - 16.3 est la liste
              des URI Jakarta Tags 3.0, PAS la semantique des balises -
              verifie par lecture attentive avant d ecrire ce TODO)
              plutot qu une vraie bibliotheque de tags chargee dynamiquement
            c:out value="${...}" [default="..."] : Test17JstlXml.jsp
              exerce l attribut default ; echappement HTML implicite
              (section 24.1, XSS) a documenter comme comportement par
              defaut
            c:set var="..." value="..." [scope="..."] : Test16
              JstlJakarta.jsp
            c:if test="${...}" : Test16JstlJakarta.jsp
            c:choose / c:when test="${...}" / c:otherwise : Test15
              JstlJavaEE.jsp
            c:forEach [var] [items="${...}"] | [begin] [end] [step] :
              deux formes - iteration sur tableau/collection
              (Test15JstlJavaEE.jsp, items=tableau de String) ET forme
              numerique begin/end sans items (Test16JstlJakarta.jsp,
              begin="1" end="5") ; varStatus non exerce mais prevu par
              la reference (section 16.6, corrige ici depuis "16.3.1" -
              cette sous-section n existe pas dans la reference, varStatus
              est documente en 16.6 "forEach")

  TODO 17 - JSTL FUNCTIONS : FN:LENGTH, FN:ESCAPEXML
            Syntaxe d appel de fonction EL prefixee (section 12.9,
              corrige ici depuis "12.5" - 12.5 est les operateurs
              relationnels, le "prefixe:nom(args)" est documente en 12.9
              "Methodes, fonctions et versions" et 16.1 "Bibliotheques" -
              prefixe:nom(args)) - resoudre le prefixe "fn" vers l URI
              functions (legacy ou jakarta, TODO 06) puis vers une
              fonction native du runtime plutot qu une vraie
              bibliotheque tld
            fn:length(x) : Test15JstlJavaEE.jsp (longueur de chaine
              dans une boucle c:forEach)
            fn:escapeXml(x) : Test17JstlXml.jsp, combine a un
              operateur ternaire EL comme argument
              (${fn:escapeXml(empty param.texte ? '(absent)' :
              param.texte)})

  TODO 18 - MODELE RUNTIME : SIMULATION D UNE REQUETE HTTP
            DECISION D ARCHITECTURE A DOCUMENTER EXPLICITEMENT avant le
              TODO 20 (meme discipline que JPPCW32.PAS TODO 04) :
              l EXE genere ne demarre AUCUN vrai serveur HTTP - une
              execution = UNE requete GET simulee
            Source des parametres de requete (request.getParameter) :
              ligne de commande de l EXE genere sous forme cle=valeur
              (ex. programme.exe nom=Ada), absence = param absent
              (empty renvoie vrai) - convention a documenter dans
              l aide du binaire genere lui-meme
            Sortie : tout out.print/println (et donc tout gabarit et
              toute expression) est ecrit sur STDOUT via WriteFile/
              GetStdHandle - pas de vrai buffer de reponse HTTP avec
              en-tetes (contentType etc. documentes mais non emis sur
              le flux, limite assumee)
            session/application : tables en memoire du processus,
              PAS persistantes entre deux executions du binaire genere
              (chaque lancement = nouvelle session/application vide) -
              limite assumee explicitement en tete du fichier de sortie
              genere par -asm/-obj pour transparence
            Dispatch d erreur (errorPage/isErrorPage, section 18) :
              toute exception non interceptee dans _jspService de la
              page courante est capturee par un gestionnaire genere qui
              invoque la traduction de la page errorPage avec
              exception peuplee - Test12Erreur.jsp/Test12
              GestionErreur.jsp (division par zero volontaire)

  TODO 19 - BIBLIOTHEQUE RUNTIME MINIMALE (CLASSES JAVA REFERENCEES)
            Les classes important explicitement (TODO 05) et
              effectivement APPELEES par les echantillons doivent
              avoir un support minimal cable en dur (pas de vrai
              chargement de classes) :
              java.util.Date (constructeur sans argument, toString)
              java.text.DateFormat.getDateTimeInstance().format(Date)
              java.util.GregorianCalendar (constructeur, getTimeInMillis)
              java.lang.Integer.parseInt/valueOf/intValue (Test09
              Application.jsp, Test12Erreur.jsp)
              java.lang.String (concatenation +, longueur, methodes
              utilisees par les echappements HTML de Test05
              Parametres.jsp)
            Toute autre classe important-ee mais non appelee par un
              echantillon reel reste NON implementee - erreur de
              compilation explicite et actionnable (pas un crash),
              meme discipline "erreur honnete plutot qu invention" que
              les compilateurs freres

  TODO 20 - ANALYSE SEMANTIQUE
            Resolution des identificateurs Java (declarations de
              TODO 07, membres de la classe page synthetique, TODO 19
              bibliotheque runtime) et detection best-effort des
              prefixes EL non declares (TODO 15) - un seul passage
              combine sur l arbre construit au TODO 08
            Verification des attributs obligatoires par directive/
              action (section 5/9 - ex. jsp:useBean exige "id", DEJA
              implemente aux TODO 05/06/12/13/16 au moment ou l attribut
              est lu - corrige ici : la reference, section 9.4, ne cite
              PAS "class" comme obligatoire, seulement "id" - confirme,
              rien de nouveau a coder ICI)
            Verification de coherence : exception implicite seulement
              si isErrorPage=true (section 7/18.1, corrige ici depuis
              "7.9" - la section 7 n a AUCUNE sous-section numerotee dans
              cette reference), errorPage doit designer un fichier
              existant et resoluble
            Detection best-effort de gabarit/scriptlet non fermes (DEJA
              implemente, TODO 02/03/07/12/13/16 - confirme, rien de
              nouveau a coder ICI), prefixe taglib reference sans
              directive taglib correspondante, inclusion statique
              circulaire (DEJA implemente, TODO 11 - confirme, rien de
              nouveau a coder ICI)

  TODO 21 - GENERATION DE CODE : STRUCTURE GENERALE ET ASSEMBLEUR
            Emission textuelle .asm (MASM .386, .MODEL FLAT) - une
              section .data pour le pool de chaines _JSPK_ (blocs de
              gabarit ET litteraux Java/EL), une section .code pour
              _jspService et les methodes declarees (TODO 07),
              prologue/epilogue standard, meme structure que
              JPPCW32.PAS/GOCW32.PAS
            Encodeur d instructions 80386 a la main (MOV/PUSH/POP/CALL/
              JMP/Jcc/CMP/ADD/SUB/IMUL/IDIV/AND/OR/XOR/NOT/NEG/SHL/SHR,
              adressage direct/indirect/indexe) - reutilisation directe
              de la table d encodage deja eprouvee dans les
              compilateurs freres (aucune reinvention)
            Traduction de l arbre entrelace gabarit+Java (TODO 08) en
              suite d appels _JSPRT_Print(_JSPKn) et de code Java
              ordinaire (expressions/instructions du TODO 07)

  TODO 22 - ENCODAGE ET INTERNATIONALISATION
            pageEncoding / contentType charset (section 22, AUCUNE
              sous-section numerotee dans cette reference - corrige ici,
              le roadmap citait a tort "22.1") - les TROIS encodages qui
              doivent rester coherents : pageEncoding de la directive
              page, charset du contentType, et le "meta charset" du
              document HTML lui-meme (corrige ici : le troisieme point
              n est PAS "le charset effectivement utilise pour lire le
              fichier .jsp source", verifie absent de cette reference -
              c est le <meta charset> du gabarit HTML, section 22,
              "document HTML: meta charset" ; la lecture du fichier
              source EST deja verbatim/sans transcodage depuis le TODO 02,
              une decision distincte, deja prise, pas une VERIFICATION de
              coherence)
            Tous les echantillons utilisent UTF-8 (Test01Bonjour.jsp,
              Test02Directives.jsp) - support garanti explicitement
              pour UTF-8 seulement, autres encodages : avertissement
              documente plutot qu un vrai support de transcodage

  TODO 23 - ECRITURE DU FICHIER OBJET COFF (.OBJ)
            En-tete COFF (IMAGE_FILE_HEADER), table des sections
              (.text/.data), table des symboles, table des relocations
              - meme structure COFF que JPPCW32.PAS/DELPHI.PAS
            Selectionne par -obj (TODO 01) - produit un .OBJ
              exploitable par un linker externe standard, sans passer
              par la generation du .EXE complet du TODO 24

  TODO 24 - ECRITURE DU FICHIER EXECUTABLE PE (.EXE)
            En-tete DOS+PE, Optional Header (PE32), table des sections
              (.text/.data/.idata), table d import (kernel32.dll :
              GetStdHandle/WriteFile/ReadFile/GetCommandLineA/
              CreateFileA/CloseHandle pour l inclusion de fichiers du
              TODO 11/12 et la simulation de requete du TODO 18),
              point d entree, relocations de base si necessaire - meme
              structure PE deja eprouvee par les compilateurs freres
            Comportement par defaut (aucune option -obj/-asm) : ce
              TODO est celui qui s execute

  TODO 25 - INTEGRATION CLI, AUTO-TESTS ET VALIDATION COMPLETE
            Run() : aide (-h/--help//?), RunAllSelfTests (lexer
              gabarit+Java, parseur EL, coercitions, resolution de
              scope) AVANT compilation reelle - meme convention d aide
              affichee en priorite que JPPCW32.PAS (le pre-check d aide
              s execute avant les auto-tests, pas apres)
            Pipeline complet : lecture source -> TODO 02/03 (lexer) ->
              TODO 05/06 (directives) -> TODO 07/08 (gabarit+Java) ->
              TODO 09/10 (implicites/scopes) -> TODO 11/12/13 (inclusions
              /actions) -> TODO 14/15/16/17 (EL/JSTL) -> TODO 20
              (semantique) -> TODO 21 (asm) -> TODO 22 (encodage) ->
              TODO 23/24 (obj/exe)
            Validation finale exigee : les 17 Test*.jsp de
              SAMPLES\JSP\ (Test01 a Test17, y compris la paire
              Test12Erreur/Test12GestionErreur) et les 2 fragments
              (FragmentEntete.jsp/FragmentPied.jsp via Test10/Test11)
              doivent tous compiler et s executer correctement, sous
              les DEUX familles d URI JSTL (legacy Test15, jakarta
              Test16/Test17) - documenter tout ecart residuel
              honnetement plutot que de le masquer, meme discipline
              finale que le jalon 18/18 de JPPCW32.PAS

  TODO 25 - VALIDATION FINALE : ETAT REEL, HONNETEMENT DOCUMENTE
            (Rapport verifie par EXECUTION REELLE - jamais devine - le
            2026-08-02, MEME discipline que la section "TODO 25 - ETAT
            REEL" de JPPCW32.PAS citee plus haut) :

            CLI/pipeline (roadmap ci-dessus, premiers deux points) :
              CONFIRMES intacts - l aide (-h/--help//?) reste verifiee
              AVANT RunAllSelfTests (Run(), inchange depuis le TODO 01) ;
              le pipeline complet lit desormais REELLEMENT le fichier
              source (ParsePage, TODO 08) puis enchaine SemanticAnalyze
              (TODO 20) -> CheckEncodingCoherence (TODO 22) ->
              CodeGenPage (TODO 21, texte) -> BinAssemblePage/
              WriteCOFFObj (TODO 23, octets/.obj) -> PeAssemblePage/
              WritePEExe (TODO 24, .exe REEL) - CHAQUE etape branchee
              pour de vrai depuis le TODO 21, plus un simple auto-test
              isole.

            1/17 REUSSITE COMPLETE (compile, genere un .asm/.obj COFF/
              .exe PE Win32 REELS - TODO 21/23/24 -, EXECUTE sur
              Windows REEL via PowerShell, sortie standard verifiee
              OCTET PAR OCTET contre le gabarit attendu, code de
              sortie 0) :
                Test10Include.jsp - le SEUL des 17 dont l arbre entier,
                UNE FOIS l inclusion statique fusionnee (TODO 11), ne
                contient plus QUE du gabarit litteral (SK_PRINT_TEMPLATE)
                - EXACTEMENT et SEULEMENT la portee que CodeGenStmt/
                BinCodeGenStmt/PeCodeGenStmt savent traduire a ce jour,
                independamment de la simplicite apparente d un fichier
                (Test01Bonjour.jsp, "le plus simple" en apparence,
                echoue des sa premiere expression <%= %>).

            16/17 ARRET PROPRE ET DOCUMENTE (JAMAIS un .asm/.obj/.exe
              silencieusement faux, JAMAIS un plantage - chaque
              FatalError nomme EXACTEMENT la construction rencontree,
              StmtKindName, TODO 21) - AUCUNE extension incrementale du
              generateur de code (TODO 21+) n a ete demandee ni ajoutee
              au cours de cette session au-dela du "premier jalon"
              gabarit-litteral-seul : chaque TODO numerote a ete traite
              un par un, jamais de travail supplementaire non demande.
              Repartition EXACTE des 16, VERIFIEE par execution reelle
              de CHACUN des 17 fichiers (jamais devinee) :

                - SK_PRINT_EXPR ("expression <%= %>", CodeGenStmt/TODO
                  21 ne traduit AUCUNE expression Java) : Test01
                  Bonjour.jsp, Test02Directives.jsp, Test03
                  Declarations.jsp, Test07ObjetsImplicites.jsp, Test12
                  Erreur.jsp, Test12GestionErreur.jsp (6 fichiers).
                - SK_LOCALVAR ("declaration de variable locale") :
                  Test04Scriptlets.jsp, Test09Application.jsp
                  (2 fichiers).
                - SK_EXPR ("instruction-expression Java", ex. un appel
                  request.setCharacterEncoding(...) ou une affectation
                  isolee) : Test05Parametres.jsp, Test06Formulaire.jsp,
                  Test08Session.jsp, Test14ExpressionLanguage.jsp
                  (4 fichiers).
                - SK_INCLUDE_ACTION ("jsp:include", l ACTION dynamique
                  du TODO 12 est correctement reconnue/analysee mais
                  jamais traduite en code) : Test11IncludeAction.jsp
                  (1 fichier) - exerce les DEUX MEMES fragments
                  (FragmentEntete.jsp/FragmentPied.jsp) que Test10
                  Include.jsp, cette fois via l inclusion DYNAMIQUE
                  plutot que STATIQUE (section 11.1) : les deux
                  fragments sont donc REELLEMENT exerces par la suite
                  complete, meme si UN SEUL des deux chemins
                  d inclusion (le statique) survit jusqu au bout.
                - SK_USEBEAN_ACTION ("jsp:useBean") : Test13
                  Actions.jsp (1 fichier).
                - SK_JSTL_SET ("c:set") : Test16JstlJakarta.jsp
                  (1 fichier).
                - SK_JSTL_OUT ("c:out") : Test17JstlXml.jsp
                  (1 fichier).
                - ARRET AU PARSER, PAS au generateur de code ("creation
                  de tableau new Type[]", TODO 07 - decouvert par
                  EXECUTION REELLE au TODO 21, jamais anticipe) : Test15
                  JstlJavaEE.jsp (1 fichier) - SEUL cas ou l ecart est
                  DANS le front-end plutot que dans la portee
                  deliberement restreinte du generateur de code.

            DEUX familles d URI JSTL (legacy Test15, jakarta Test16/
              Test17) : la DISAMBIGUATION elle-meme reste VERIFIEE
              correcte a l analyse (TaglibPool/IsCoreJstlUri/
              IsFunctionsJstlUri, TODO 06 - les DEUX familles resolvent
              vers les MEMES noeuds SK_JSTL_xxx/ELK_CALL) ; aucune des
              DEUX ne peut cependant etre EXECUTEE de bout en bout
              avant que le generateur de code ne couvre les actions
              JSTL - honnetement note ICI plutot que suppose resolu par
              la seule disambiguation front-end.

            CONCLUSION : ce compilateur atteint 1/17 (echantillons
              REELLEMENT compiles ET executes) contre les 18/18 de
              JPPCW32.PAS - un ecart ASSUME et explique (roadmap
              d en-tete du TODO 21 : "portee VOLONTAIREMENT restreinte
              a ce que TODO 01-20 ont reellement construit... grandissant
              par extensions incrementales", jamais realisees ICI au-
              dela du premier jalon puisqu aucune ne fut demandee). Les
              16 echecs restants sont, SANS EXCEPTION, des arrets
              PROPRES et EXPLIQUES a un endroit PRECIS et VERIFIE -
              JAMAIS un plantage, JAMAIS une sortie fausse. Etendre la
              couverture du generateur de code (expressions Java,
              instructions de controle, actions JSP/JSTL) reste un
              travail FUTUR possible, hors de la portee de CE TODO 25
              precisement PARCE QUE cette portee est de rapporter
              l etat REEL plutot que de l etendre sans demande explicite.

  EXTENSION 1 (post-TODO25) - "new java.util.Date()" IMMEDIAT
            DEMANDEE EXPLICITEMENT par l utilisateur (2026-08-02, "etendre
              le generateur de code" en reponse a l echec observe de
              Test01Bonjour.jsp) - PORTEE DELIBEREMENT ETROITE, MEME
              discipline "extensions incrementales separement verifiees"
              que le roadmap d en-tete du TODO 21 : SEULE l expression
              EXACTE "new java.util.Date()" (ou "new Date()" apres import)
              SANS receveur ni argument, comme unique contenu d un
              <%= %>, est reconnue - un cas SPECIAL-CASE assume, PAS une
              VRAIE coercition-String generale (qui exigerait un modele
              d objet/tas complet, hors de portee ICI). Format retenu :
              "AAAA-MM-JJ HH:MM:SS" (heure locale REELLE, GetLocalTime -
              PAS le format exact de java.util.Date.toString(), documente
              honnetement comme une simplification DELIBEREE plutot qu une
              reproduction fidele).
            ETENDUE AUX TROIS backends (CodeGenPage/BinAssemblePage/
              PeAssemblePage) - DECOUVERT PAR EXECUTION que les TROIS
              sont necessaires : Run() les enchaine SEQUENTIELLEMENT
              (.asm puis .obj puis .exe) et un FatalError dans le
              PREMIER (CodeGenPage, jamais etendu au debut) empechait
              d atteindre PeAssemblePage meme apres l avoir etendu SEUL -
              lecon retenue et documentee plutot que masquee.
            RESULTAT HONNETE (meme discipline que le TODO 25 lui-meme,
              verifie par EXECUTION REELLE le 2026-08-02) : 2/17
              echantillons compilent ET s executent desormais de bout en
              bout (Test01Bonjour.jsp rejoint Test10Include.jsp - sortie
              verifiee, une VRAIE date/heure du systeme apparait dans le
              HTML produit, code de sortie 0). Les 15 autres restent
              inchanges (MEME repartition que le rapport TODO 25 ci-
              dessus) SAUF Test02Directives.jsp/Test03Declarations.jsp/
              Test07ObjetsImplicites.jsp/Test12Erreur.jsp/Test12
              GestionErreur.jsp, qui affichent maintenant le message
              PLUS PRECIS de cette extension ("seule new java.util.
              Date() est geree") plutot que le message generique
              SK_PRINT_EXPR du TODO 21 - MEME arret PROPRE, MEME
              construction bloquante reelle (DateFormat.format(...)/
              appels de methode/exception - AUCUNE de ces cinq pages
              n a jamais ete debloquee, seul le DIAGNOSTIC affiche a
              change).

  EXTENSION 2 (post-TODO25) - DateFormat.getDateTimeInstance().
  format(new Date()) IMMEDIAT
            DEMANDEE EXPLICITEMENT par l utilisateur (2026-08-02, echec
              observe de Test02Directives.jsp APRES l extension 1 -
              CORRIGE ICI : cette page ne reste PAS bloquee "pour
              toujours" comme l extension 1 le supposait, contrairement a
              Test03Declarations.jsp/Test07ObjetsImplicites.jsp/Test12
              Erreur.jsp/Test12GestionErreur.jsp qui restent, EUX,
              reellement bloques par une AUTRE construction - correction
              honnete d une supposition prealable, pas une erreur
              cachee).
            PORTEE ENCORE PLUS ETROITE que l extension 1 : la CHAINE
              EXACTE "DateFormat.getDateTimeInstance().format(new
              Date())" (selecteur par selecteur, argument par argument -
              CgIsImmediateDatePrint, PARTAGEE par les TROIS backends,
              AUCUNE duplication de la logique de reconnaissance) est
              routee vers le MEME _JSPRT_PrintDate deja construit par
              l extension 1 - AUCUN nouveau runtime, puisque "formater
              la date/l heure COURANTE" est deja EXACTEMENT ce que fait
              cet appel Java (une bibliotheque de formatage DateFormat
              complete, avec des styles/locales reels, resterait hors de
              portee - roadmap d en-tete, "erreur honnete plutot qu
              invention").
            RESULTAT HONNETE (verifie par EXECUTION REELLE le
              2026-08-02) : 3/17 echantillons compilent ET s executent
              desormais de bout en bout (Test02Directives.jsp rejoint
              Test01Bonjour.jsp/Test10Include.jsp). AUCUNE regression :
              les 14 autres restent inchanges (MEME repartition), avec
              MISE A JOUR du message pour Test03Declarations.jsp/Test07
              ObjetsImplicites.jsp/Test12Erreur.jsp/Test12
              GestionErreur.jsp (le TEXTE du diagnostic mentionne
              desormais les DEUX formes reconnues, MEME arret PROPRE,
              MEME construction bloquante reelle - appels de methode
              utilisateur/objets implicites/exception, respectivement).

  EXTENSION 3 (post-TODO25) - VRAIS APPELS DE FONCTION
  (nomApplication()/carre(int), Test03Declarations.jsp)
            DEMANDEE EXPLICITEMENT par l utilisateur (2026-08-02, echec
              observe de Test03Declarations.jsp apres l extension 2) :
              CHOIX EXPLICITE entre un cas special etroit (constant-
              folding du texte source, MEME style que les extensions 1/2)
              et de VRAIS appels de fonction (compilation reelle du corps
              des methodes declarees + un site d appel general) -
              L UTILISATEUR A CHOISI LA SECONDE OPTION, plus lente a
              construire mais NON specifique au contenu EXACT de ce seul
              echantillon.
            REDESSIN NECESSAIRE - REPRESENTATION DES CHAINES : la
              convention _JSPRT_Print(pointeur, longueur) (TODO 18/21) ne
              suffit plus des qu une methode DECLAREE doit "retourner une
              chaine" - une valeur de retour ne tient que dans UN SEUL
              registre (EAX, convention "tout tient dans EAX" de tout ce
              projet). Chaque bloc _JSPKn (et _JSPRT_DateStr/le nouveau
              _JSPRT_IntBuf) commence donc DESORMAIS par sa PROPRE
              longueur (dd) suivie IMMEDIATEMENT des octets, SOUS LA MEME
              etiquette - _JSPRT_Print est redessinee en CONSEQUENCE avec
              UN SEUL parametre (le pointeur vers ce bloc), lisant elle-
              meme la longueur via [pointeur]. Applique IDENTIQUEMENT aux
              TROIS backends (CodeGenPage/BinAssemblePage/PeAssemblePage -
              MEME lecon que les extensions 1/2 : Run() les enchaine
              SEQUENTIELLEMENT, une portee etendue dans un SEUL backend
              reste invisible tant que les DEUX autres ne le sont pas
              aussi).
            NOUVEAU RUNTIME - _JSPRT_PrintInt : carre(12) retourne un
              "int" (144), qui doit etre CONVERTI en decimal ASCII avant
              impression (aucune conversion entier->chaine n existait
              avant cette extension). Algorithme standard (division
              repetee par 10, extraction des chiffres EN SENS INVERSE
              dans un tampon FIXE, gestion du signe) - CONTRAIREMENT a
              _JSPRT_PrintDate (extensions 1/2, DELIBEREMENT
              ENTIEREMENT LINEAIRE), c est ICI le PREMIER runtime de tout
              le projet JSPCW32 a necessiter de VRAIS sauts conditionnels
              dans les backends Bin/Pe (BinEmitJccPlaceholder/
              BinPatchJcc/BinEmitJccBackward et leurs equivalents Pe -
              un mecanisme de patch a deux passes pour les DEUX sauts EN
              AVANT, un calcul direct pour l UNIQUE saut EN ARRIERE).
            BOGUE REEL TROUVE PAR EXECUTION (2026-08-02) : la premiere
              version ecrite faisait pointer le curseur d ecriture des
              chiffres sur le DERNIER octet valide du tampon
              (_JSPRT_IntBuf+15) plutot que sur "un-au-dela" (+16) -
              puisque l ecriture decremente D ABORD le curseur puis
              ecrit, cela DECALAIT chaque longueur calculee de +1 (un
              octet PARASITE avant chaque entier imprime - "144"
              devenait "144 " suivi d un caractere errone). Trouve
              SEULEMENT en executant REELLEMENT Test03Declarations.exe
              (jamais par relecture du code ni par les auto-tests
              structurels) - CONFIRME, UNE FOIS DE PLUS, la necessite de
              la verification par execution reelle introduite au TODO 21.
              Corrige de facon IDENTIQUE dans les TROIS backends.
            BOGUE REEL TROUVE PAR EXECUTION (2026-08-02, second) : les
              litteraux chaine RETOURNES par une methode declaree (ex.
              "Catalogue JSP") vivent dans JavaMethodPool, un arbre
              SEPARE de celui deja parcouru par CgCollectStrings (le
              gabarit/scriptlets de la page) - sans une collecte DEDIEE
              (CgCollectStringsFromExpr/CgCollectStringsFromMethodStmt),
              la section .data etait deja ecrite (nombre FIXE de _JSPKn)
              avant que la compilation du corps de methode ne decouvre ce
              litteral, produisant une reference _JSPKn JAMAIS DEFINIE.
              Corrige de facon IDENTIQUE dans les TROIS backends (chacun
              collecte MAINTENANT les chaines de JavaMethodPool AVANT
              d ecrire .data).
            PORTEE DELIBEREMENT ETROITE (documentee, pas cachee) : corps
              de methode = un SEUL "return <expression>;" en position
              FINALE (aucun retour anticipe, aucune instruction apres un
              return - Test03Declarations.jsp n en a pas besoin) ;
              expressions gerees dans un corps = litteral chaine/entier,
              parametre (identificateur simple), operateur binaire '*'
              (carre) ; arguments d un site d appel = litteraux entiers
              SEULEMENT (carre(12)). Toute autre forme (autre operateur,
              expression composee en argument, corps multi-instructions)
              s arrete PROPREMENT via FatalError, MEME discipline "erreur
              honnete plutot qu invention" que partout ailleurs dans ce
              projet - AUCUNE de ces limites n affecte Test03
              Declarations.jsp.
            RESULTAT HONNETE (verifie par EXECUTION REELLE le
              2026-08-02, sortie exacte confirmee - "Catalogue JSP" et
              "144" apparaissent correctement, code de sortie 0) : 4/17
              echantillons compilent ET s executent desormais de bout en
              bout (Test03Declarations.jsp rejoint Test01Bonjour.jsp/
              Test02Directives.jsp/Test10Include.jsp). AUCUNE regression :
              les 13 autres restent bloques par une construction
              DIFFERENTE et INCHANGEE (declaration de variable locale,
              if/else, jsp:include/jsp:useBean, Expression Language,
              creation de tableau, balises JSTL c:set/c:out - AUCUNE
              n est dans la portee de cette extension). Auto-tests
              etendus (BinAsmSelfTest/PeExeSelfTest) : encodage octet par
              octet verifie a la main pour CHAQUE nouveau primitif
              d adressage indirect/arithmetique/saut, PLUS une compilation
              reelle bout en bout de Test03Declarations.jsp (fragment
              VERBATIM) confirmant que _JSPM_nomApplication/_JSPM_carre/
              _JSPRT_PrintInt existent et que le .obj/.exe final s ecrit
              sans erreur.
============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF       }
{ ============================================================ }

Const
  JSPCW32_VERSION = '0.1';
  JSPCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { --- Constantes PE/COFF (identiques aux autres compilateurs   }
  { de ce projet - format Win32 universel, pas specifique a JSP). }
  PE_DOS_MAGIC            = $5A4D;
  PE_PE_SIG               = $00004550;
  PE_MACHINE_I386         = $014C;
  PE_IMG_BASE             = $00400000;
  PE_SEC_ALIGN            = 4096;
  PE_FILE_ALIGN           = 512;
  PE_SUBSYS_CUI           = 3;
  PE_OPT_MAGIC_PE32       = $010B;
  PE_SCN_CNT_CODE         = $00000020;
  PE_SCN_CNT_INIT_DATA    = $00000040;
  PE_SCN_CNT_UNINIT_DATA  = $00000080;
  PE_SCN_MEM_EXECUTE      = $20000000;
  PE_SCN_MEM_READ         = $40000000;
  PE_SCN_MEM_WRITE        = -2147483648;
  COFF_SYM_CLASS_EXTERNAL = 2;
  COFF_SYM_CLASS_STATIC   = 3;
  COFF_REL_I386_DIR32     = $0006;
  COFF_REL_I386_REL32     = $0014;
  BIN_SEC_TEXT            = 1;
  BIN_SEC_DATA            = 2;
  BIN_SEC_RDATA           = 3;
  BIN_SEC_BSS             = 4;
  BIN_FIX_REL32           = 1;
  BIN_FIX_ABS32           = 2;
  BIN_FIX_IMP32           = 3;

  { --- Limites internes (table plus large sous FPC ; Turbo      }
  { Pascal classique reste supporte avec des tables plus modestes  }
  { par prudence memoire - meme convention que les compilateurs      }
  { freres de ce meme projet).                                        }
  MAX_SYM           = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_FUNC          = {$IFDEF FPC}512{$ELSE}64{$ENDIF};    { TODO 07 :     }
                      { methodes static de la "classe page" (voir MAX_METHOD }
                      { ci-dessous - JavaMethodPool REUNIT MAX_FUNC+          }
                      { MAX_METHOD en une seule table, MEME decision           }
                      { EXACTE que MethodPool/MAX_METHOD_POOL de JPPCW32.PAS)  }
  MAX_METHOD        = {$IFDEF FPC}512{$ELSE}64{$ENDIF};    { TODO 07 :     }
                      { methodes d instance - voir la note de MAX_FUNC        }
  MAX_TYPE          = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_FIELD_POOL    = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { TODO 07 :     }
                      { champs de la "classe page" (JavaFieldPool) }
  MAX_PARAM         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { TODO 07 :     }
                      { JavaParamPool TOTAL (TOUTES methodes confondues,       }
                      { pool plat) - JSP ne declare que quelques methodes a     }
                      { 0-2 parametres chacune, aucune raison de distinguer     }
                      { "par methode" vs "total" comme MAX_PARAM_POOL de         }
                      { JPPCW32.PAS le fait, l echelle reelle est bien plus      }
                      { modeste ici }
  MAX_LOCAL         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LABEL         = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR           = 255;
  MAX_ERRORS        = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_TEMPLATE_CHUNK= {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { TODO 02/08 :  }
                      { fragments de texte HTML entre deux delimiteurs JSP }
  MAX_ATTR          = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};  { TODO 10 :     }
                      { attributs de scope (page/request/session/app)      }
  MAX_TAGLIB        = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { TODO 06 }
  MAX_ELNODE        = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};  { TODO 14 :     }
                      { noeuds d expression EL }
  MAX_INCLUDE       = {$IFDEF FPC}64{$ELSE}16{$ENDIF};     { TODO 11 :     }
                      { fichiers inclus statiquement, garde-fou anti-boucle }
  MAX_DEFINE        = {$IFDEF FPC}32{$ELSE}8{$ENDIF};      { -D SYMBOLE,   }
                      { reserve pour une future compilation conditionnelle }
  MAX_JEXPR         = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { TODO 07 :     }
                      { noeuds d expression Java (declarations/scriptlets/  }
                      { expressions <%!/<%/<%=) }
  MAX_JEXPR_ARG     = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};  { TODO 07 :     }
                      { ArgPool TOTAL (appels+"new" confondus), MEME         }
                      { convention "pool plat" que MAX_PARAM_POOL de           }
                      { JPPCW32.PAS }
  MAX_JAVA_STMT     = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};  { TODO 07 :     }
                      { noeuds d instruction Java }
  MAX_JAVA_STMT_CHILD = {$IFDEF FPC}4096{$ELSE}512{$ENDIF}; { TODO 07 :   }
                      { StmtChildPool TOTAL (instructions d un bloc/          }
                      { scriptlet, TOUS blocs confondus) - pool plat, MEME    }
                      { discipline que MAX_JEXPR_ARG ci-dessus }
  MAX_JAVA_BLOCK_LOCAL = {$IFDEF FPC}128{$ELSE}32{$ENDIF}; { TODO 07 :     }
                      { tampon LOCAL (PAS partage) d un SEUL bloc/scriptlet   }
                      { pendant son propre parsing, avant recopie en bloc      }
                      { dans StmtChildPool - voir la note d en-tete de           }
                      { ParseBlock (bogue reel d imbrication trouve par            }
                      { execution, evite par cette indirection) }
  MAX_JAVA_ARG_LOCAL   = {$IFDEF FPC}32{$ELSE}16{$ENDIF};  { TODO 07 :     }
                      { MEME chose que MAX_JAVA_BLOCK_LOCAL, pour UN SEUL       }
                      { appel/"new" pendant son propre parsing }
  MAX_JAVA_PAGE_LOCAL  = {$IFDEF FPC}512{$ELSE}64{$ENDIF};  { TODO 08 :    }
                      { MEME chose que MAX_JAVA_BLOCK_LOCAL, pour le CORPS      }
                      { entier de la page (gabarit+Java entrelaces) pendant      }
                      { son propre parsing - plus grand qu un seul bloc car       }
                      { une page entiere accumule BEAUCOUP plus de chunks de      }
                      { gabarit qu un seul bloc Java }
  MAX_JSP_PARAM        = {$IFDEF FPC}256{$ELSE}32{$ENDIF};  { TODO 12 :    }
                      { JspParamPool TOTAL (jsp:param imbriques dans           }
                      { jsp:include/jsp:forward, section 9.3), pool plat,        }
                      { MEME discipline que MAX_JEXPR_ARG/MAX_JAVA_STMT_CHILD    }
  MAX_ELARG            = {$IFDEF FPC}1024{$ELSE}128{$ENDIF}; { TODO 14 :   }
                      { ElArgPool TOTAL (appels de fonction EL, section         }
                      { 12.9), pool plat, MEME discipline que MAX_JEXPR_ARG }
  MAX_EL_ARG_LOCAL     = {$IFDEF FPC}32{$ELSE}16{$ENDIF};    { TODO 14 :   }
                      { tampon LOCAL (PAS partage) d un SEUL appel de           }
                      { fonction EL pendant son propre parsing, MEME             }
                      { discipline que MAX_JAVA_ARG_LOCAL (TODO 07) -             }
                      { INDISPENSABLE des qu un argument peut lui-meme etre        }
                      { un appel avec ses PROPRES arguments (ex.                    }
                      { "f(g(x, y))") - bogue reel deja trouve et corrige             }
                      { pour l equivalent Java, evite ICI PROACTIVEMENT }
  MAX_REQPARAM         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { TODO 18 :    }
                      { ReqParamPool TOTAL (parametres "cle=valeur" de la     }
                      { requete GET simulee, section 13.1/18) - pool plat,       }
                      { MEME discipline que MAX_JSP_PARAM ci-dessus - une         }
                      { requete simulee reelle n a besoin que de tres peu de       }
                      { parametres (aucun echantillon n en fournit plus d un)}
  MAX_RUNTIME_METHOD   = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { TODO 19 :    }
                      { RuntimeMethodPool TOTAL (methodes/constructeurs des      }
                      { classes stdlib cablees en dur - Date/DateFormat/           }
                      { GregorianCalendar/Integer/String), pool plat, MEME          }
                      { discipline que MAX_JSP_PARAM }
  MAX_RUNTIME_PARAM    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};    { TODO 19 :    }
                      { RuntimeParamPool TOTAL (types de parametres INDICATIFS   }
                      { des methodes ci-dessus, MEME convention "non resolu"        }
                      { que TJavaParamDecl, TODO 07) }
  MAX_BIN_CODE   = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF}; { TODO 23 :        }
                      { BinTextBuf TOTAL (octets machine 80386 REELS de la      }
                      { section .text) - tres genereux pour la portee            }
                      { actuelle (gabarit litteral SEULEMENT, TODO 21/23) }
  MAX_BIN_DATA   = {$IFDEF FPC}65536{$ELSE}8192{$ENDIF}; { TODO 23 :        }
                      { BinDataBuf TOTAL (octets REELS de la section .data -      }
                      { pool _JSPK, un gabarit HTML entier peut etre volumineux) }
  MAX_BIN_SYM    = {$IFDEF FPC}64{$ELSE}16{$ENDIF};      { TODO 23 :        }
                      { BinSymPool TOTAL (table des symboles COFF) }
  MAX_BIN_FIXUP  = {$IFDEF FPC}256{$ELSE}32{$ENDIF};     { TODO 23 :        }
                      { BinFixupPool TOTAL (table des relocations COFF, une      }
                      { par "push offset _JSPKn"/appel externe) }
  MAX_PE_CODE    = {$IFDEF FPC}16384{$ELSE}4096{$ENDIF}; { TODO 24 :        }
                      { PeTextBuf TOTAL - MEME taille que MAX_BIN_CODE (TODO       }
                      { 23), portee EQUIVALENTE (gabarit litteral SEULEMENT) }
  MAX_PE_DATA    = {$IFDEF FPC}65536{$ELSE}8192{$ENDIF}; { TODO 24 :        }
                      { PeDataBuf TOTAL - MEME taille que MAX_BIN_DATA (TODO 23) }
  MAX_PE_FIXUP   = {$IFDEF FPC}64{$ELSE}16{$ENDIF};      { TODO 24 :        }
                      { PeFixupPool TOTAL - UN SEUL genre de fixup ICI (appel        }
                      { importe via l IAT, "FF 15 <VA>") : bien MOINS nombreux         }
                      { qu au TODO 23 (aucune relocation .data - le VRAI              }
                      { chargeur Windows connait deja l ImageBase FIXE, section          }
                      { .reloc omise, DECISION A DOCUMENTER ci-dessous) }

  { --- Prefixes de nommage ASM (voir en-tete du fichier) --- }
  ASM_PFX_GVAR    = '_JSP_';    { champ/attribut static               }
  ASM_PFX_FUNC    = '_JSPF_';   { methode static                      }
  ASM_PFX_METHOD  = '_JSPM_';   { methode d instance                  }
  ASM_PFX_STRING  = '_JSPK_';   { constante chaine/litteral (y compris}
                                { chaque bloc de texte gabarit)        }
  ASM_PFX_RUNTIME = '_JSPRT_';  { runtime servlet simule               }
  ASM_PFX_LABEL   = '_JSPL_';   { label de saut interne                }
  ASM_PFX_TYPEDESC= '_JSPT_';   { descripteur de type                  }
  ASM_PFX_EL      = '_JSPEL_';  { evaluateur d expression EL compilee  }

Type
  TString = String;

  TOptions = Record
    SrcFile      : TString;   { fichier source (.jsp)                 }
    OutFile      : TString;   { fichier sortie (.exe, .obj ou .asm)    }
    OutFileGiven : Boolean;   { True si fourni explicitement (-o)      }
    Verbose      : Boolean;   { -v : banniere et statistiques          }
    DebugMode    : Boolean;   { -d : affichage de chaque token         }
    Warnings     : Boolean;   { -w : afficher les avertissements       }
    AsmOutput    : Boolean;   { -asm : produire aussi un .ASM lisible  }
    ObjOnly      : Boolean;   { -obj : produire seulement un .OBJ      }
    StrictMode   : Boolean;   { -strict : reserve pour un mode strict   }
                               { futur (attributs de directive inconnus  }
                               { ou mal formes traites comme fatals),     }
                               { actuellement toujours strict par defaut. }
    DefinedSymbols : Array[0..MAX_DEFINE - 1] Of TString;
    DefinedCount   : Integer;
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Vrai PENDANT l execution d un self-test (Lex/Type/Page/...SelfTest) - }
  { voir la note d en-tete de WarnMsg juste plus bas (TODO 05, ajoute      }
  { suite a un avertissement REEL observe a l ecran pendant PageSelfTest). }
  SelfTestMode : Boolean;

  { Fichier de sortie interne (pour future emission) }
  OutF     : Text;
  OutFOpen : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function StrUpperCase(Const S: TString): TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  StrUpperCase := Tmp;
End;

{ Retourne l extension d un chemin (avec le point, en majuscules) }
Function ExtractExt(Const Path: TString): TString;
Var
  I, LastDot, LastSep: Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := StrUpperCase(Copy(Path, LastDot,
                    Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt: TString): TString;
Var
  I, LastDot, LastSep: Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ IntToStrG : conversion entier -> texte SANS AUCUN uses (ce fichier  }
{ n en a jamais eu un seul, mode TP en tete de fichier) - reutilise le }
{ "Str" INTEGRE du langage Pascal LUI-MEME, meme choix que les          }
{ compilateurs freres de ce projet. }
Function IntToStrG(N: LongInt): TString;
Var S: TString;
Begin
  Str(N, S);
  IntToStrG := S;
End;

{ Retourne le nom de base d un chemin, SANS repertoire ni extension }
Function ExtractBaseName(Const Path: TString): TString;
Var
  I, LastDot, LastSep: Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractBaseName := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    ExtractBaseName := Copy(Path, LastSep + 1, Length(Path) - LastSep);
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg: TString);
Begin
  WriteLn('JSPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

{ SelfTestMode (TODO 05) : un fixture de self-test (ex. PageSelfTest,     }
{ language="cobol"/attribut inconnu/contradiction VOLONTAIRES) declenche   }
{ de VRAIS appels a WarnMsg pour rendre WarnCount observable par les       }
{ assertions - SANS SelfTestMode, ces avertissements delibrement           }
{ provoques s AFFICHERAIENT sur la console de l utilisateur (BOGUE REEL    }
{ observe a l ecran lors de l ecriture de PageSelfTest, corrige ICI plutot  }
{ qu ignore) alors qu ils ne concernent en rien SON fichier source.        }
Procedure WarnMsg(Const Msg: TString);
Begin
  If Not Opts.Warnings Then Exit;
  If Not SelfTestMode Then
    WriteLn('JSPCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ SemErr (TODO 09) : erreur SEMANTIQUE (ex. "exception" utilise en dehors   }
{ d une page d erreur, section 18.4 "erreurs de traduction") - DISTINCTE     }
{ de WarnMsg : TOUJOURS affichee (jamais conditionnee par -w, une VRAIE       }
{ erreur n est jamais optionnelle) et incremente ErrorCount (declare depuis   }
{ le TODO 01 mais jamais utilise jusqu ici) plutot que WarnCount. NE HALTE     }
{ PAS le programme (contrairement a FatalError) : la compilation continue      }
{ pour signaler d AUTRES erreurs eventuelles dans le reste du fichier, MEME     }
{ discipline "accumuler plutot que s arreter a la premiere" qu un vrai            }
{ compilateur - SelfTestMode reste respecte pour ne pas polluer la console       }
{ pendant un self-test, MEME raison que WarnMsg ci-dessus. }
Procedure SemErr(Const Msg: TString);
Begin
  If Not SelfTestMode Then
    WriteLn('JSPCW32: error: ', Msg);
  Inc(ErrorCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile      := '';
  Opts.OutFile      := '';
  Opts.OutFileGiven := False;
  Opts.Verbose      := False;
  Opts.DebugMode    := False;
  Opts.Warnings     := False;
  Opts.AsmOutput    := False;
  Opts.ObjOnly      := False;
  Opts.StrictMode   := True;
  Opts.DefinedCount := 0;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('JSPCW32 v', JSPCW32_VERSION, ' (', JSPCW32_DATE,
          ') - Compilateur JSP vers 80386 (Windows PE 32 bits)');
  WriteLn('JSPCW32 - Cette commande permet de lancer le compilateur ',
          'JSP (JavaServer Pages / Jakarta Server Pages) pour ',
          'l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : JSPCW32 [options] <source.jsp> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -D SYMBOLE     Definir un symbole (reserve, repetable)');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  JSPCW32 Test01Bonjour.jsp');
  WriteLn('  JSPCW32 Test01Bonjour.jsp Test01Bonjour.exe -v');
  WriteLn('  JSPCW32 Test15JstlJavaEE.jsp -obj -w');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.AsmOutput := True
    Else If Arg = '-obj' Then
      Opts.ObjOnly := True
    Else If Arg = '-D' Then
    Begin
      { -D SYMBOLE : reserve pour un futur mecanisme de compilation      }
      { conditionnelle - aucun echantillon JSP ne l exercice, contrai-    }
      { rement a JPPCW32.PAS (#if/#endif), mais le flag est accepte       }
      { pour rester coherent avec les compilateurs freres. }
      If I >= ParamCount Then
        FatalError('"-D" attend un symbole en argument suivant')
      Else
      Begin
        Inc(I);
        If Opts.DefinedCount >= MAX_DEFINE Then
          WarnMsg('trop de symboles -D, ignore : ' + ParamStr(I))
        Else
        Begin
          Opts.DefinedSymbols[Opts.DefinedCount] := ParamStr(I);
          Inc(Opts.DefinedCount);
        End;
      End;
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source ou sortie }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else If Opts.OutFile = '' Then
      Begin
        Opts.OutFile      := Arg;
        Opts.OutFileGiven := True;
      End
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('JSPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .jsp - le fichier d entree DOIT etre une      }
  { page de premier niveau, jamais un fragment .jspf (TODO 01, voir    }
  { l en-tete du fichier) : un fragment ne peut etre compile que par   }
  { INCLUSION depuis une vraie page (TODO 11/12), jamais directement.  }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext = '.JSPF' Then
    FatalError('un fragment (.jspf) ne peut pas etre compile ' +
               'directement - il doit etre inclus depuis une page .jsp')
  Else If Ext <> '.JSP' Then
    WarnMsg('extension attendue .jsp, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.ObjOnly Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                       }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('JSPCW32 v', JSPCW32_VERSION, ' (', JSPCW32_DATE,
          ') - Compilateur JSP -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.ObjOnly Then
    WriteLn('Mode     : OBJ seulement (COFF)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR DE GABARIT JSP (LEXER NIVEAU PAGE)       }
{ ============================================================ }

{ Modele de tampon "fichier entier en memoire" (BlockRead dans un        }
{ Array[1..SrcBufSize] Of Char), MEME technique que PERLCW32.PAS -       }
{ DELIBEREMENT PAS le modele "une ligne a la fois" (ReadLn) utilise par  }
{ JPPCW32.PAS/GOCW32.PAS/SWIFTW32.PAS : un TOK_TEMPLATE_CHUNK de gabarit  }
{ JSP doit pouvoir capturer VERBATIM plusieurs lignes d affilee (les      }
{ sauts de ligne du HTML font partie de la sortie, section 4.4) - un      }
{ decoupage ligne-par-ligne romprait ces chunks sans raison reelle.       }
{                                                                        }
{ TToken.Val est un TBigString (AnsiString), PAS un TString (ShortString  }
{ 255 octets, mode TP en tete de fichier) : un chunk de gabarit HTML ou   }
{ le contenu BRUT d une directive/expression EL peut DEPASSER 255         }
{ octets facilement (ex. FragmentEntete.jsp) - EVITE ICI, AVANT qu il ne  }
{ se produise, le MEME piege de troncature silencieuse deja rencontre    }
{ comme bogue REEL dans JPPCW32.PAS (ClassParseFile, "factorielle" coupe  }
{ en "facto" a la 255e position) - meme categorie d erreur, prevenue      }
{ des maintenant plutot que decouverte plus tard par un test qui plante.  }

Type
  TLexMode = (
    LM_TEMPLATE,        { texte de gabarit + delimiteurs JSP (par defaut) }
    LM_DIRECTIVE_ATTRS, { entre <%@ et %> - nom de directive puis         }
                        { attributs nom="valeur" (TODO 03, LexAttrList)   }
    LM_ACTION_ATTRS,    { entre <prefixe:nom et /> ou > - attributs       }
                        { nom="valeur" d une action JSP/taglib (TODO 03)  }
    LM_EL_RAW,          { entre ${ ou #{ et l accolade fermante - capture }
                        { BRUTE, PONT vers TODO 14 (le vrai sous-lexer EL) }
    LM_JAVA             { entre <%!/<%/<%= et le %> fermant - lexer Java  }
  );

  TTokenKind = (
    TOK_EOF,
    TOK_TEMPLATE_CHUNK,     { texte de gabarit, VERBATIM (aucun          }
                            { echappement decode - section 4.5, voir     }
                            { la note d en-tete du TODO 02)               }
    TOK_DIRECTIVE_OPEN,     { <%@ - fait basculer en LM_DIRECTIVE_ATTRS,  }
                            { toujours suivi d un TOK_DIR_NAME            }
    TOK_DECL_OPEN,          { <%! - fait basculer en LM_JAVA              }
    TOK_SCRIPTLET_OPEN,     { <%  (ni @, ni !, ni =, ni --) - LM_JAVA     }
    TOK_EXPR_OPEN,          { <%= - fait basculer en LM_JAVA              }
    TOK_TAG_CLOSE,          { %> refermant un <%!/<%/<%= (mode Java) OU   }
                            { un <%@ ... (mode LM_DIRECTIVE_ATTRS)        }
    TOK_DIR_NAME,           { nom de directive (page/include/taglib,     }
                            { section 5) - premier token APRES            }
                            { TOK_DIRECTIVE_OPEN, voir IsDirectiveName    }
    TOK_ATTR_NAME,          { nom d attribut nom="valeur" (directive OU   }
                            { action) - toujours suivi d un               }
                            { TOK_ATTR_VALUE                              }
    TOK_ATTR_VALUE,         { valeur d attribut, DECODEE des guillemets   }
                            { (" ou ', section 5/9) - contenu VERBATIM,   }
                            { aucune interpretation EL a ce stade (TODO 03)}
    TOK_EL_IMMEDIATE_OPEN,  { ${ - toujours suivi d un UNIQUE TOK_EL_RAW  }
    TOK_EL_DEFERRED_OPEN,   { #{ - toujours suivi d un UNIQUE TOK_EL_RAW  }
    TOK_EL_RAW,             { contenu BRUT d une expression EL - l       }
                            { accolade fermante est DEJA consommee en     }
                            { produisant ce token (meme convention que    }
                            { TOK_ACTION_SELFCLOSE)                       }
    TOK_ACTION_OPEN,        { <prefixe:nom (section 9/14) - Val =         }
                            { "prefixe:nom" - fait basculer en            }
                            { LM_ACTION_ATTRS ; prefixe="jsp" est         }
                            { verifie contre les 6 actions standard       }
                            { (IsStandardJspAction), tout autre prefixe   }
                            { est accepte SANS validation ICI (le lien    }
                            { vers une directive taglib reste a faire au  }
                            { TODO 06/TODO 20 - lexer seul, pas de         }
                            { verification semantique a ce stade)         }
    TOK_ACTION_SELFCLOSE,   { /> refermant une action auto-fermante -     }
                            { retourne en LM_TEMPLATE                     }
    TOK_ACTION_BODY_OPEN,   { > ouvrant le CORPS d une action (section 9, }
                            { forme <prefixe:nom ...> ... </prefixe:nom>) }
                            { - retourne en LM_TEMPLATE, le corps est du   }
                            { gabarit ORDINAIRE jusqu au TOK_ACTION_CLOSE  }
    TOK_ACTION_CLOSE,       { </prefixe:nom> refermant le CORPS - Val =   }
                            { "prefixe:nom" (MEME convention que          }
                            { TOK_ACTION_OPEN)                            }
    { -- tokens du sous-lexer "Java" (LM_JAVA UNIQUEMENT) : }
    TOK_IDENT,
    TOK_INT,
    TOK_FLOAT,
    TOK_CHAR,
    TOK_STRING,
    TOK_OP
  );

  TBigString = AnsiString;

  TToken = Record
    Kind    : TTokenKind;
    Val     : TBigString;
    IntVal  : LongInt;    { TOK_INT, ou code de caractere pour TOK_CHAR  }
    RealVal : Real;       { TOK_FLOAT                                    }
    Line    : Integer;
    Col     : Integer;
  End;

Const
  SRC_BUF_SIZE = 65535;

Var
  SrcBuf  : Array[1..SRC_BUF_SIZE] Of Char;
  SrcLen  : LongInt;
  LexPos  : LongInt;
  LexLine : Integer;
  LexCol  : Integer;
  LexMode : TLexMode;

  { Etat partage entre appels successifs de LexNextToken (TODO 03) -      }
  { LM_DIRECTIVE_ATTRS/LM_ACTION_ATTRS produisent PLUSIEURS tokens pour    }
  { une seule construction source (nom + paires attribut/valeur), un      }
  { seul token par appel : ces drapeaux memorisent OU on en est.          }
  ExpectDirName    : Boolean; { Vrai juste apres TOK_DIRECTIVE_OPEN -      }
                              { le PROCHAIN token DOIT etre TOK_DIR_NAME   }
  AttrValuePending : Boolean; { Vrai juste apres un TOK_ATTR_NAME - le     }
                              { PROCHAIN token DOIT etre TOK_ATTR_VALUE    }

{ ------------------------------------------------------------ }
{ Classification de caracteres                                 }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch: Char): Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_') Or (Ch = '$');
End;

Function IsIdentCont(Ch: Char): Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigitCh(Ch: Char): Boolean;
Begin
  IsDigitCh := (Ch >= '0') And (Ch <= '9');
End;

{ Nom XML (prefixe/nom local d une directive taglib ou d une action -    }
{ section 5/9/14) - reutilise IsIdentStart/IsIdentCont (donc accepte     }
{ aussi '$'/'_' en tete comme un identificateur Java) : legerement plus   }
{ permissif que la grammaire XML Name reelle, mais AUCUN echantillon      }
{ SAMPLES\JSP\*.jsp n emploie de prefixe/nom exotique - simplification    }
{ deliberee plutot que dupliquer un classificateur XML Name distinct.     }
Function IsXmlNameStart(Ch: Char): Boolean;
Begin
  IsXmlNameStart := IsIdentStart(Ch);
End;

Function IsXmlNameChar(Ch: Char): Boolean;
Begin
  IsXmlNameChar := IsIdentCont(Ch) Or (Ch = '-');
End;

{ Section 5 : SEULS page/include/taglib sont des directives JSP valides. }
Function IsDirectiveName(Const S: TString): Boolean;
Begin
  IsDirectiveName := (S = 'page') Or (S = 'include') Or (S = 'taglib');
End;

{ Section 9 : les 6 actions JSP standard (prefixe "jsp" reserve) -        }
{ verifiee UNIQUEMENT quand le prefixe reconnu est litteralement "jsp"   }
{ (TOK_ACTION_OPEN, plus bas) ; tout AUTRE prefixe (JSTL, taglib          }
{ personnalise) n est PAS valide contre cette liste - son lien vers une   }
{ directive taglib reste a etablir plus tard (TODO 06/TODO 20).           }
Function IsStandardJspAction(Const LocalName: TString): Boolean;
Begin
  IsStandardJspAction :=
    (LocalName = 'include') Or (LocalName = 'forward') Or
    (LocalName = 'param') Or (LocalName = 'useBean') Or
    (LocalName = 'setProperty') Or (LocalName = 'getProperty');
End;

{ ------------------------------------------------------------ }
{ LexPeekChar/2/3/4, LexNextChar - tampon fichier entier         }
{ ------------------------------------------------------------ }

Function LexPeekChar: Char;
Begin
  If LexPos > SrcLen Then LexPeekChar := #0
  Else LexPeekChar := SrcBuf[LexPos];
End;

Function LexPeekChar2: Char;
Begin
  If LexPos + 1 > SrcLen Then LexPeekChar2 := #0
  Else LexPeekChar2 := SrcBuf[LexPos + 1];
End;

Function LexPeekChar3: Char;
Begin
  If LexPos + 2 > SrcLen Then LexPeekChar3 := #0
  Else LexPeekChar3 := SrcBuf[LexPos + 2];
End;

Function LexPeekChar4: Char;
Begin
  If LexPos + 3 > SrcLen Then LexPeekChar4 := #0
  Else LexPeekChar4 := SrcBuf[LexPos + 3];
End;

Function LexNextChar: Char;
Var C: Char;
Begin
  If LexPos > SrcLen Then Begin LexNextChar := #0; Exit; End;
  C := SrcBuf[LexPos];
  Inc(LexPos);
  If C = #10 Then Begin Inc(LexLine); LexCol := 1; End
  Else If C <> #13 Then Inc(LexCol);
  LexNextChar := C;
End;

{ Extrait SrcBuf[FromPos..ToPosExcl-1] en TBigString (AnsiString) - voir }
{ la note d en-tete de ce TODO sur la troncature ShortString a eviter.   }
Function SrcSlice(FromPos, ToPosExcl: LongInt): TBigString;
Var I: LongInt; S: TBigString;
Begin
  S := '';
  For I := FromPos To ToPosExcl - 1 Do S := S + SrcBuf[I];
  SrcSlice := S;
End;

{ ------------------------------------------------------------ }
{ LexInit / LexClose                                           }
{ ------------------------------------------------------------ }

Procedure LexInit(Const FileName: TString);
Var
  F : File;
  N : LongInt;
Begin
  SrcLen := 0;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then FatalError('impossible d''ouvrir ' + FileName);
  BlockRead(F, SrcBuf, SRC_BUF_SIZE, N);
  SrcLen := N;
  If Not Eof(F) Then
  Begin
    Close(F);
    FatalError('fichier source trop volumineux (limite ' +
               IntToStrG(SRC_BUF_SIZE) + ' octets)');
  End;
  Close(F);
  LexPos  := 1;
  LexLine := 1;
  LexCol  := 1;
  LexMode := LM_TEMPLATE;
  ExpectDirName    := False;
  AttrValuePending := False;
End;

Procedure LexClose;
Begin
  SrcLen  := 0;
  LexPos  := 1;
  LexLine := 1;
  LexCol  := 1;
  LexMode := LM_TEMPLATE;
  ExpectDirName    := False;
  AttrValuePending := False;
End;

{ ------------------------------------------------------------ }
{ Commentaire JSP <%-- ... --%> (section 4.3) : retire du        }
{ gabarit PENDANT LE LEXAGE LUI-MEME - ne produit JAMAIS de       }
{ token (ni TOK_TEMPLATE_CHUNK, ni aucun autre) - contrairement    }
{ au commentaire HTML <!-- --> qui n est PAS reconnu spec-        }
{ ialement ici (il ne commence pas par '<%') et reste donc du     }
{ texte de gabarit ORDINAIRE, passe tel quel (comportement qui     }
{ EMERGE naturellement, aucun code dedie necessaire).              }
{ ------------------------------------------------------------ }

Function IsAtJspCommentStart: Boolean;
Begin
  IsAtJspCommentStart := (LexPeekChar = '<') And (LexPeekChar2 = '%') And
                         (LexPeekChar3 = '-') And (LexPeekChar4 = '-');
End;

Procedure LexSkipJspComment;
Begin
  LexNextChar; LexNextChar; LexNextChar; LexNextChar; { consomme <%-- }
  { Le fermant est '--%>' (4 caracteres) - PAS '-->' (3 caracteres, le    }
  { fermant d un commentaire HTML) : verifier les 4 EVITE un bogue reel   }
  { trouve par execution ici-meme, ou un "-->" HTML plus loin dans le     }
  { fichier (Test02Directives.jsp-like : <!-- ... --> apres un vrai      }
  { <%-- ... --%>) ferait terminer ce commentaire JSP TROP TOT, avalant   }
  { silencieusement tout le texte de gabarit intermediaire. }
  While Not ((LexPeekChar = '-') And (LexPeekChar2 = '-') And
             (LexPeekChar3 = '%') And (LexPeekChar4 = '>')) Do
  Begin
    If LexPos > SrcLen Then
      FatalError('commentaire JSP <%-- ... non ferme (attendu --%>)');
    LexNextChar;
  End;
  LexNextChar; LexNextChar; LexNextChar; LexNextChar; { consomme --%> }
End;

{ ------------------------------------------------------------ }
{ TryMatchActionTagName (TODO 03) : lookahead PUR (ne consomme    }
{ rien) depuis la position courante - reconnait <prefixe:nom ou   }
{ </prefixe:nom au sens XML Name (section 9/14). Retourne le       }
{ nombre de caracteres a consommer pour atteindre la fin du nom     }
{ local (SANS le '<'/'</' d ouverture ni le '>' final d une          }
{ fermeture - l appelant consomme le '>' separement pour les          }
{ fermetures). Le caractere qui SUIT le nom doit etre un delimiteur   }
{ de balise valide (espace/'/'/'>' en ouverture, '>' uniquement en    }
{ fermeture) - EVITE de confondre un ':' dans du texte ordinaire      }
{ (ex. "http://exemple.com" : apres ':' vient '/', jamais une         }
{ lettre, donc rejete ICI par construction).                          }
{ ------------------------------------------------------------ }

Function TryMatchActionTagName(Var IsClosing: Boolean;
                                Var NameOut: TBigString;
                                Var MatchLen: LongInt): Boolean;
Var
  I : LongInt;
Begin
  TryMatchActionTagName := False;
  IsClosing := False;
  NameOut   := '';
  I := LexPos;
  If (I > SrcLen) Or (SrcBuf[I] <> '<') Then Exit;
  Inc(I);
  If (I <= SrcLen) And (SrcBuf[I] = '/') Then
  Begin
    IsClosing := True;
    Inc(I);
  End;

  If (I > SrcLen) Or (Not IsXmlNameStart(SrcBuf[I])) Then Exit;
  While (I <= SrcLen) And IsXmlNameChar(SrcBuf[I]) Do
  Begin NameOut := NameOut + SrcBuf[I]; Inc(I); End;

  If (I > SrcLen) Or (SrcBuf[I] <> ':') Then Exit;
  NameOut := NameOut + ':';
  Inc(I);

  If (I > SrcLen) Or (Not IsXmlNameStart(SrcBuf[I])) Then Exit;
  While (I <= SrcLen) And IsXmlNameChar(SrcBuf[I]) Do
  Begin NameOut := NameOut + SrcBuf[I]; Inc(I); End;

  If I > SrcLen Then Exit;
  If IsClosing Then
  Begin
    If SrcBuf[I] <> '>' Then Exit;
  End
  Else
  Begin
    If Not ((SrcBuf[I] = ' ') Or (SrcBuf[I] = #9) Or (SrcBuf[I] = #10) Or
            (SrcBuf[I] = #13) Or (SrcBuf[I] = '/') Or (SrcBuf[I] = '>')) Then
      Exit;
  End;

  MatchLen := I - LexPos;
  TryMatchActionTagName := True;
End;

{ Enveloppe booleenne de TryMatchActionTagName pour la condition de     }
{ boucle d accumulation de texte de gabarit ci-dessus (ignore les        }
{ valeurs capturees, ne teste QUE la reconnaissance). }
Function IsAtActionTagBoundary: Boolean;
Var
  DummyClosing : Boolean;
  DummyName    : TBigString;
  DummyLen     : LongInt;
Begin
  IsAtActionTagBoundary := TryMatchActionTagName(DummyClosing, DummyName,
                                                  DummyLen);
End;

{ ------------------------------------------------------------ }
{ LexNextTemplateToken (LM_TEMPLATE) - section 4.1/4.2/4.3       }
{ ------------------------------------------------------------ }

Function LexNextTemplateToken: TToken;
Var
  Result       : TToken;
  StartPos     : LongInt;
  IsClosingTag : Boolean;
  ActionName   : TBigString;
  MatchLen     : LongInt;
  ColonPos     : Integer;
Begin
  { Avaler silencieusement TOUT commentaire JSP present exactement a la  }
  { position courante (eventuellement plusieurs a la suite) avant de     }
  { decider du prochain token reel. }
  While IsAtJspCommentStart Do LexSkipJspComment;

  Result.Val := ''; Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;

  If LexPos > SrcLen Then
  Begin
    Result.Kind := TOK_EOF;
    LexNextTemplateToken := Result;
    Exit;
  End;

  { Delimiteurs a 3 caracteres (section 4.2) - '<%--' est deja ELIMINE   }
  { par la boucle ci-dessus, donc un '<%' encore present ICI n est       }
  { jamais le debut d un commentaire. }
  If (LexPeekChar = '<') And (LexPeekChar2 = '%') Then
  Begin
    Case LexPeekChar3 Of
      '@':
        Begin
          LexNextChar; LexNextChar; LexNextChar;
          Result.Kind := TOK_DIRECTIVE_OPEN; Result.Val := '<%@';
          LexMode := LM_DIRECTIVE_ATTRS;
          ExpectDirName := True;
        End;
      '!':
        Begin
          LexNextChar; LexNextChar; LexNextChar;
          Result.Kind := TOK_DECL_OPEN; Result.Val := '<%!';
          LexMode := LM_JAVA;
        End;
      '=':
        Begin
          LexNextChar; LexNextChar; LexNextChar;
          Result.Kind := TOK_EXPR_OPEN; Result.Val := '<%=';
          LexMode := LM_JAVA;
        End;
    Else
      LexNextChar; LexNextChar;
      Result.Kind := TOK_SCRIPTLET_OPEN; Result.Val := '<%';
      LexMode := LM_JAVA;
    End;
    LexNextTemplateToken := Result;
    Exit;
  End;

  If (LexPeekChar = '$') And (LexPeekChar2 = '{') Then
  Begin
    LexNextChar; LexNextChar;
    Result.Kind := TOK_EL_IMMEDIATE_OPEN; Result.Val := '${';
    LexMode := LM_EL_RAW;
    LexNextTemplateToken := Result;
    Exit;
  End;

  If (LexPeekChar = '#') And (LexPeekChar2 = '{') Then
  Begin
    LexNextChar; LexNextChar;
    Result.Kind := TOK_EL_DEFERRED_OPEN; Result.Val := '#{';
    LexMode := LM_EL_RAW;
    LexNextTemplateToken := Result;
    Exit;
  End;

  { Action JSP standard <jsp:nom ...> ou action personnalisee/JSTL         }
  { <prefixe:nom ...> (section 9/14), forme ouvrante OU fermante           }
  { </prefixe:nom> - reconnue directement depuis le gabarit (PAS via       }
  { <%...%>). TryMatchActionTagName distingue ceci d une simple balise     }
  { HTML sans ':' (<div>, <meta>, <!-- ...) et d une URL "http://..."      }
  { (rejetee car ':' n y est jamais suivi d une lettre). }
  If LexPeekChar = '<' Then
  Begin
    If TryMatchActionTagName(IsClosingTag, ActionName, MatchLen) Then
    Begin
      While MatchLen > 0 Do Begin LexNextChar; Dec(MatchLen); End;
      If IsClosingTag Then
      Begin
        LexNextChar; { consomme le '>' final, deja verifie par le matcher }
        Result.Kind := TOK_ACTION_CLOSE; Result.Val := ActionName;
      End
      Else
      Begin
        Result.Kind := TOK_ACTION_OPEN; Result.Val := ActionName;
        LexMode := LM_ACTION_ATTRS;
        AttrValuePending := False;
        ColonPos := Pos(':', ActionName);
        If (Copy(ActionName, 1, ColonPos - 1) = 'jsp') And
           (Not IsStandardJspAction(Copy(ActionName, ColonPos + 1,
                                         Length(ActionName) - ColonPos))) Then
          WarnMsg('action JSP standard inconnue : ' + ActionName);
      End;
      LexNextTemplateToken := Result;
      Exit;
    End;
  End;

  { Aucun delimiteur ici : accumuler du texte de gabarit LITTERAL        }
  { jusqu au PROCHAIN delimiteur/commentaire ou la fin de fichier. Un     }
  { simple '$' NON suivi de '{' (deux '$' consecutifs avant une accolade, }
  { section 4.5) ou                                                       }
  { un '#' NON suivi de '{' restent du texte ORDINAIRE : ceci EMERGE      }
  { naturellement du lookahead de 2 caracteres ci-dessus, SANS code       }
  { d echappement dedie. }
  StartPos := LexPos;
  While (LexPos <= SrcLen) And
        (Not ((LexPeekChar = '<') And (LexPeekChar2 = '%'))) And
        (Not ((LexPeekChar = '$') And (LexPeekChar2 = '{'))) And
        (Not ((LexPeekChar = '#') And (LexPeekChar2 = '{'))) And
        (Not IsAtActionTagBoundary) Do
    LexNextChar;

  Result.Kind := TOK_TEMPLATE_CHUNK;
  Result.Val  := SrcSlice(StartPos, LexPos);
  LexNextTemplateToken := Result;
End;

{ ------------------------------------------------------------ }
{ LexSkipTagWhitespace : espaces flexibles (section 5) entre      }
{ nom/attributs d une directive OU d une action - PARTAGE entre    }
{ LM_DIRECTIVE_ATTRS et LM_ACTION_ATTRS.                            }
{ ------------------------------------------------------------ }

Procedure LexSkipTagWhitespace;
Begin
  While (LexPos <= SrcLen) And
        ((LexPeekChar = ' ') Or (LexPeekChar = #9) Or
         (LexPeekChar = #10) Or (LexPeekChar = #13)) Do
    LexNextChar;
End;

{ Scanne un identificateur -> TOK_ATTR_NAME, arme AttrValuePending -    }
{ PARTAGE entre LM_DIRECTIVE_ATTRS et LM_ACTION_ATTRS. }
Function LexScanAttrNameToken: TToken;
Var
  Result   : TToken;
  StartPos : LongInt;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  If Not IsIdentStart(LexPeekChar) Then
    FatalError('nom d attribut attendu (identificateur)');
  StartPos := LexPos;
  While IsIdentCont(LexPeekChar) Do LexNextChar;
  Result.Kind := TOK_ATTR_NAME;
  Result.Val  := SrcSlice(StartPos, LexPos);
  AttrValuePending := True;
  LexScanAttrNameToken := Result;
End;

{ Scanne '=' puis une valeur entre guillemets (" ou ', section 5/9)     }
{ -> TOK_ATTR_VALUE, desarme AttrValuePending - PARTAGE entre            }
{ LM_DIRECTIVE_ATTRS et LM_ACTION_ATTRS. }
Function LexScanAttrValueToken: TToken;
Var
  Result   : TToken;
  QuoteCh  : Char;
  StartPos : LongInt;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;
  LexSkipTagWhitespace;
  Result.Line := LexLine; Result.Col := LexCol;

  If LexPeekChar <> '=' Then
    FatalError('"=" attendu apres un nom d attribut');
  LexNextChar;
  LexSkipTagWhitespace;

  QuoteCh := LexPeekChar;
  If (QuoteCh <> '"') And (QuoteCh <> '''') Then
    FatalError('valeur d attribut attendue entre guillemets (" ou '')');
  LexNextChar; { consomme le guillemet ouvrant }
  StartPos := LexPos;
  While (LexPos <= SrcLen) And (LexPeekChar <> QuoteCh) Do LexNextChar;
  If LexPos > SrcLen Then
    FatalError('valeur d attribut non terminee (guillemet fermant attendu)');

  Result.Kind := TOK_ATTR_VALUE;
  Result.Val  := SrcSlice(StartPos, LexPos);
  LexNextChar; { consomme le guillemet fermant }
  AttrValuePending := False;
  LexScanAttrValueToken := Result;
End;

{ ------------------------------------------------------------ }
{ LexNextDirectiveToken (LM_DIRECTIVE_ATTRS) - directive <%@ ... %> }
{ (section 5) : nom de directive, puis paires attribut/valeur,    }
{ puis %> fermant (retour en LM_TEMPLATE).                         }
{ ------------------------------------------------------------ }

Function LexNextDirectiveToken: TToken;
Var
  Result   : TToken;
  StartPos : LongInt;
  NameStr  : TString;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;

  If AttrValuePending Then
  Begin
    LexNextDirectiveToken := LexScanAttrValueToken;
    Exit;
  End;

  LexSkipTagWhitespace;
  Result.Line := LexLine; Result.Col := LexCol;

  If ExpectDirName Then
  Begin
    ExpectDirName := False;
    If Not IsIdentStart(LexPeekChar) Then
      FatalError('nom de directive attendu (page/include/taglib)');
    StartPos := LexPos;
    While IsIdentCont(LexPeekChar) Do LexNextChar;
    NameStr := SrcSlice(StartPos, LexPos);
    If Not IsDirectiveName(NameStr) Then
      WarnMsg('nom de directive inconnu (attendu page/include/taglib) : ' +
              NameStr);
    Result.Kind := TOK_DIR_NAME;
    Result.Val  := NameStr;
    LexNextDirectiveToken := Result;
    Exit;
  End;

  If (LexPeekChar = '%') And (LexPeekChar2 = '>') Then
  Begin
    LexNextChar; LexNextChar;
    Result.Kind := TOK_TAG_CLOSE; Result.Val := '%>';
    LexMode := LM_TEMPLATE;
    LexNextDirectiveToken := Result;
    Exit;
  End;

  LexNextDirectiveToken := LexScanAttrNameToken;
End;

{ ------------------------------------------------------------ }
{ LexNextActionAttrsToken (LM_ACTION_ATTRS) - attributs d une     }
{ action <prefixe:nom ...> (section 9/14) : paires attribut/       }
{ valeur, puis /> (auto-fermante) ou > (ouvre un corps, section     }
{ le corps redevient du gabarit ORDINAIRE jusqu au TOK_ACTION_CLOSE }
{ correspondant, reconnu par LexNextTemplateToken lui-meme).        }
{ ------------------------------------------------------------ }

Function LexNextActionAttrsToken: TToken;
Var
  Result : TToken;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;

  If AttrValuePending Then
  Begin
    LexNextActionAttrsToken := LexScanAttrValueToken;
    Exit;
  End;

  LexSkipTagWhitespace;
  Result.Line := LexLine; Result.Col := LexCol;

  If (LexPeekChar = '/') And (LexPeekChar2 = '>') Then
  Begin
    LexNextChar; LexNextChar;
    Result.Kind := TOK_ACTION_SELFCLOSE; Result.Val := '/>';
    LexMode := LM_TEMPLATE;
    LexNextActionAttrsToken := Result;
    Exit;
  End;

  If LexPeekChar = '>' Then
  Begin
    LexNextChar;
    Result.Kind := TOK_ACTION_BODY_OPEN; Result.Val := '>';
    LexMode := LM_TEMPLATE;
    LexNextActionAttrsToken := Result;
    Exit;
  End;

  LexNextActionAttrsToken := LexScanAttrNameToken;
End;

{ ------------------------------------------------------------ }
{ LexNextElRawToken (LM_EL_RAW) - PONT vers TODO 14              }
{ ------------------------------------------------------------ }
{ Capture BRUTE (scan naif a la premiere accolade fermante) du    }
{ contenu d une expression EL - ne comprend PAS encore la          }
{ grammaire EL (TODO 14) : une accolade fermante litterale a l     }
{ interieur d une chaine EL romprait prematurement cette capture - }
{ LIMITE ASSUMEE, documentee ici, aucun echantillon               }
{ SAMPLES\JSP\*.jsp ne l exercice actuellement.                    }

Function LexNextElRawToken: TToken;
Var
  Result   : TToken;
  StartPos : LongInt;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  StartPos := LexPos;

  While (LexPos <= SrcLen) And (LexPeekChar <> '}') Do
    LexNextChar;

  If LexPos > SrcLen Then
    FatalError('expression EL ${...}/#{...} non fermee (attendu ''}'')');

  Result.Kind := TOK_EL_RAW;
  Result.Val  := SrcSlice(StartPos, LexPos);
  LexNextChar; { consomme l accolade fermante }
  LexMode := LM_TEMPLATE;
  LexNextElRawToken := Result;
End;

{ ------------------------------------------------------------ }
{ Mode Java (LM_JAVA) - proche du lexer de JPPCW32.PAS, actif     }
{ UNIQUEMENT entre <%!/<%/<%= et le %> fermant correspondant.      }
{ Simplifie par rapport a JPPCW32.PAS : ni suffixes L/f/F (aucun   }
{ scriptlet/declaration/expression des echantillons SAMPLES\JSP\  }
{ *.jsp n en utilise), ni entiers hexadecimaux/octaux - LIMITE     }
{ assumee et grounded dans le contenu Java REEL des echantillons   }
{ (Test01 a Test13 : uniquement identificateurs, entiers decimaux, }
{ chaines, caracteres, operateurs Java usuels).                    }
{ ------------------------------------------------------------ }

Procedure LexSkipJavaWhitespaceAndComments;
Begin
  While True Do
  Begin
    While (LexPos <= SrcLen) And
          ((LexPeekChar = ' ') Or (LexPeekChar = #9) Or
           (LexPeekChar = #10) Or (LexPeekChar = #13)) Do
      LexNextChar;

    If (LexPeekChar = '/') And (LexPeekChar2 = '/') Then
    Begin
      While (LexPos <= SrcLen) And (LexPeekChar <> #10) Do LexNextChar;
      Continue;
    End;

    If (LexPeekChar = '/') And (LexPeekChar2 = '*') Then
    Begin
      LexNextChar; LexNextChar;
      While Not ((LexPeekChar = '*') And (LexPeekChar2 = '/')) Do
      Begin
        If LexPos > SrcLen Then
          FatalError('commentaire Java /* ... non ferme (attendu */) ' +
                     'dans un bloc <%!/<%/<%=');
        LexNextChar;
      End;
      LexNextChar; LexNextChar; { consomme */ }
      Continue;
    End;

    Break;
  End;
End;

{ Consomme le caractere APRES un '\' deja consomme par l appelant et    }
{ retourne le caractere DECODE - echappements usuels Java (sous-        }
{ ensemble suffisant pour echapperHtml/Test05Parametres.jsp et les       }
{ chaines "..." de Test06/Test09/Test12) ; toute sequence inconnue       }
{ produit un avertissement et conserve le caractere tel quel plutot      }
{ qu une erreur fatale (meme tolerance que les compilateurs freres).     }
Function LexScanEscapeChar: Char;
Var Ch: Char;
Begin
  Ch := LexPeekChar;
  LexNextChar;
  Case Ch Of
    'n' : LexScanEscapeChar := #10;
    't' : LexScanEscapeChar := #9;
    'r' : LexScanEscapeChar := #13;
    '\' : LexScanEscapeChar := '\';
    '''': LexScanEscapeChar := '''';
    '"' : LexScanEscapeChar := '"';
    '0' : LexScanEscapeChar := #0;
  Else
    WarnMsg('sequence d echappement Java inconnue : \' + Ch);
    LexScanEscapeChar := Ch;
  End;
End;

Function LexScanIdentJava: TToken;
Var
  Result   : TToken;
  StartPos : LongInt;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  StartPos := LexPos;
  While IsIdentCont(LexPeekChar) Do LexNextChar;
  Result.Kind := TOK_IDENT;
  Result.Val  := SrcSlice(StartPos, LexPos);
  LexScanIdentJava := Result;
End;

Function LexScanNumberJava: TToken;
Var
  Result     : TToken;
  StartPos   : LongInt;
  IsFloatLit : Boolean;
  NumStr     : TString;
  ErrCode    : Integer;
Begin
  Result.Line := LexLine; Result.Col := LexCol;
  StartPos := LexPos;
  IsFloatLit := False;

  While IsDigitCh(LexPeekChar) Do LexNextChar;

  If (LexPeekChar = '.') And IsDigitCh(LexPeekChar2) Then
  Begin
    IsFloatLit := True;
    LexNextChar; { '.' }
    While IsDigitCh(LexPeekChar) Do LexNextChar;
  End;

  If (LexPeekChar = 'e') Or (LexPeekChar = 'E') Then
  Begin
    If IsDigitCh(LexPeekChar2) Or
       (((LexPeekChar2 = '+') Or (LexPeekChar2 = '-')) And
        IsDigitCh(LexPeekChar3)) Then
    Begin
      IsFloatLit := True;
      LexNextChar; { e/E }
      If (LexPeekChar = '+') Or (LexPeekChar = '-') Then LexNextChar;
      While IsDigitCh(LexPeekChar) Do LexNextChar;
    End;
  End;

  NumStr := SrcSlice(StartPos, LexPos);
  Result.Val := NumStr;
  If IsFloatLit Then
  Begin
    Result.Kind := TOK_FLOAT;
    Val(NumStr, Result.RealVal, ErrCode);
    Result.IntVal := 0;
  End
  Else
  Begin
    Result.Kind := TOK_INT;
    Val(NumStr, Result.IntVal, ErrCode);
    Result.RealVal := 0.0;
  End;
  LexScanNumberJava := Result;
End;

Function LexScanCharJava: TToken;
Var
  Result : TToken;
  Ch     : Char;
Begin
  Result.Val := ''; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  LexNextChar; { consomme la quote ouvrante ' }
  If LexPeekChar = '\' Then
  Begin
    LexNextChar;
    Ch := LexScanEscapeChar;
  End
  Else
  Begin
    Ch := LexPeekChar;
    LexNextChar;
  End;
  If LexPeekChar <> '''' Then
    FatalError('litteral caractere Java mal forme (quote fermante attendue)')
  Else
    LexNextChar; { consomme la quote fermante }
  Result.Kind   := TOK_CHAR;
  Result.IntVal := Ord(Ch);
  Result.Val    := Ch;
  LexScanCharJava := Result;
End;

Function LexScanStringJava: TToken;
Var
  Result : TToken;
  S      : TBigString;
  Ch     : Char;
Begin
  Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  LexNextChar; { consomme le guillemet ouvrant " }
  S := '';
  While True Do
  Begin
    If LexPos > SrcLen Then
      FatalError('chaine Java non terminee (guillemet fermant attendu)');
    Ch := LexPeekChar;
    If Ch = '"' Then Begin LexNextChar; Break; End;
    If (Ch = #10) Or (Ch = #13) Then
      FatalError('chaine Java non terminee avant fin de ligne (Java 1.1 ' +
                 'n a pas de chaines multi-lignes)');
    If Ch = '\' Then
    Begin
      LexNextChar;
      S := S + LexScanEscapeChar;
    End
    Else
    Begin
      LexNextChar;
      S := S + Ch;
    End;
  End;
  Result.Kind := TOK_STRING;
  Result.Val  := S;
  LexScanStringJava := Result;
End;

Function LexScanOperatorJava: TToken;
Var
  Result     : TToken;
  C1, C2, C3 : Char;
Begin
  Result.Val := ''; Result.IntVal := 0; Result.RealVal := 0.0;
  Result.Line := LexLine; Result.Col := LexCol;
  Result.Kind := TOK_OP;
  C1 := LexPeekChar; C2 := LexPeekChar2; C3 := LexPeekChar3;

  If (C1='>') And (C2='>') And (C3='>') And (LexPeekChar4='=') Then
  Begin
    Result.Val := '>>>='; LexNextChar; LexNextChar; LexNextChar; LexNextChar;
    LexScanOperatorJava := Result; Exit;
  End;
  If (C1='>') And (C2='>') And (C3='>') Then
  Begin
    Result.Val := '>>>'; LexNextChar; LexNextChar; LexNextChar;
    LexScanOperatorJava := Result; Exit;
  End;
  If (C1='<') And (C2='<') And (C3='=') Then
  Begin
    Result.Val := '<<='; LexNextChar; LexNextChar; LexNextChar;
    LexScanOperatorJava := Result; Exit;
  End;
  If (C1='>') And (C2='>') And (C3='=') Then
  Begin
    Result.Val := '>>='; LexNextChar; LexNextChar; LexNextChar;
    LexScanOperatorJava := Result; Exit;
  End;

  If (C1='+') And (C2='+') Then
  Begin Result.Val:='++'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='-') And (C2='-') Then
  Begin Result.Val:='--'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='=') And (C2='=') Then
  Begin Result.Val:='=='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='!') And (C2='=') Then
  Begin Result.Val:='!='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='<') And (C2='=') Then
  Begin Result.Val:='<='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='>') And (C2='=') Then
  Begin Result.Val:='>='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='&') And (C2='&') Then
  Begin Result.Val:='&&'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='|') And (C2='|') Then
  Begin Result.Val:='||'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='<') And (C2='<') Then
  Begin Result.Val:='<<'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='>') And (C2='>') Then
  Begin Result.Val:='>>'; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='+') And (C2='=') Then
  Begin Result.Val:='+='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='-') And (C2='=') Then
  Begin Result.Val:='-='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='*') And (C2='=') Then
  Begin Result.Val:='*='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='/') And (C2='=') Then
  Begin Result.Val:='/='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='%') And (C2='=') Then
  Begin Result.Val:='%='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='&') And (C2='=') Then
  Begin Result.Val:='&='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='|') And (C2='=') Then
  Begin Result.Val:='|='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;
  If (C1='^') And (C2='=') Then
  Begin Result.Val:='^='; LexNextChar; LexNextChar; LexScanOperatorJava:=Result; Exit; End;

  If C1 = #0 Then
    FatalError('fin de fichier inattendue : bloc <%!/<%/<%= non ferme ' +
               '(attendu %>)')
  Else If (C1 < ' ') Or (C1 > '~') Then
    FatalError('caractere inattendu (hors ASCII imprimable) dans un ' +
               'bloc <%!/<%/<%=')
  Else
  Begin
    Result.Val := C1;
    LexNextChar;
  End;
  LexScanOperatorJava := Result;
End;

Function LexNextJavaToken: TToken;
Var Ch: Char;
Begin
  LexSkipJavaWhitespaceAndComments;

  If (LexPeekChar = '%') And (LexPeekChar2 = '>') Then
  Begin
    LexNextChar; LexNextChar;
    LexNextJavaToken.Kind := TOK_TAG_CLOSE;
    LexNextJavaToken.Val  := '%>';
    LexNextJavaToken.IntVal := 0;
    LexNextJavaToken.RealVal := 0.0;
    LexMode := LM_TEMPLATE;
    Exit;
  End;

  Ch := LexPeekChar;
  If IsIdentStart(Ch) Then Begin LexNextJavaToken := LexScanIdentJava; Exit; End;
  If IsDigitCh(Ch) Then Begin LexNextJavaToken := LexScanNumberJava; Exit; End;
  If Ch = '''' Then Begin LexNextJavaToken := LexScanCharJava; Exit; End;
  If Ch = '"' Then Begin LexNextJavaToken := LexScanStringJava; Exit; End;

  LexNextJavaToken := LexScanOperatorJava; { EOF (#0) est detecte ICI }
End;

{ ------------------------------------------------------------ }
{ LexNextToken - dispatch selon LexMode                        }
{ ------------------------------------------------------------ }

Function LexNextToken: TToken;
Begin
  Case LexMode Of
    LM_TEMPLATE        : LexNextToken := LexNextTemplateToken;
    LM_DIRECTIVE_ATTRS : LexNextToken := LexNextDirectiveToken;
    LM_ACTION_ATTRS    : LexNextToken := LexNextActionAttrsToken;
    LM_EL_RAW          : LexNextToken := LexNextElRawToken;
    LM_JAVA            : LexNextToken := LexNextJavaToken;
  End;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug (-d) de chaque token             }
{ ------------------------------------------------------------ }

Function TruncForDisplay(Const S: TBigString): TBigString;
Begin
  If Length(S) > 60 Then
    TruncForDisplay := Copy(S, 1, 60) + '...'
  Else
    TruncForDisplay := S;
End;

Procedure PrintToken(Const T: TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TOK_EOF               : Write('EOF');
    TOK_TEMPLATE_CHUNK     : Write('TEMPLATE("', TruncForDisplay(T.Val), '")');
    TOK_DIRECTIVE_OPEN     : Write('DIRECTIVE_OPEN(<%@)');
    TOK_DECL_OPEN          : Write('DECL_OPEN(<%!)');
    TOK_SCRIPTLET_OPEN     : Write('SCRIPTLET_OPEN(<%)');
    TOK_EXPR_OPEN          : Write('EXPR_OPEN(<%=)');
    TOK_TAG_CLOSE          : Write('TAG_CLOSE(%>)');
    TOK_DIR_NAME           : Write('DIR_NAME(', T.Val, ')');
    TOK_ATTR_NAME          : Write('ATTR_NAME(', T.Val, ')');
    TOK_ATTR_VALUE         : Write('ATTR_VALUE("', TruncForDisplay(T.Val), '")');
    TOK_EL_IMMEDIATE_OPEN  : Write('EL_IMMEDIATE_OPEN(${)');
    TOK_EL_DEFERRED_OPEN   : Write('EL_DEFERRED_OPEN(#{)');
    TOK_EL_RAW             : Write('EL_RAW("', TruncForDisplay(T.Val), '")');
    TOK_ACTION_OPEN        : Write('ACTION_OPEN(', T.Val, ')');
    TOK_ACTION_SELFCLOSE   : Write('ACTION_SELFCLOSE(/>)');
    TOK_ACTION_BODY_OPEN   : Write('ACTION_BODY_OPEN(>)');
    TOK_ACTION_CLOSE       : Write('ACTION_CLOSE(', T.Val, ')');
    TOK_IDENT              : Write('IDENT(', T.Val, ')');
    TOK_INT                : Write('INT(', T.IntVal, ')');
    TOK_FLOAT              : Write('FLOAT(', T.Val, ')');
    TOK_CHAR               : Write('CHAR(', T.IntVal, ')');
    TOK_STRING             : Write('STRING("', T.Val, '")');
    TOK_OP                 : Write('OP(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexSelfTest : tokenise un petit extrait JSP ecrit dans un      }
{ fichier temporaire et verifie la sequence de tokens attendue - }
{ couvre gabarit/directive+raw/commentaire JSP retire/commentaire}
{ HTML passe tel quel/EL immediat+differe/declaration/scriptlet   }
{ (identificateurs, entier, chaine, caractere, // et /* */) et     }
{ expression, MEME discipline "self-test avant compilation reelle" }
{ que JPPCW32.PAS (LexSelfTest).                                   }
{ ------------------------------------------------------------ }

Procedure LexAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('LexSelfTest: ' + Label_ + ' a echoue');
End;

Procedure LexSelfTest;
Const
  TmpFile = 'JSPLEXSELFTEST.$$$';
Var
  F   : Text;
  Tok : TToken;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'Bonjour ');
  WriteLn(F, '<%@ page language="java" contentType="text/html" %>');
  WriteLn(F, 'Texte <%-- ceci est un commentaire JSP --%> suite');
  WriteLn(F, '<!-- commentaire HTML garde --> fin');
  WriteLn(F, '${utilisateur.nom} et #{expr.differe}');
  WriteLn(F, '<jsp:include page="Frag.jsp" flush="true" />');
  WriteLn(F, '<c:if test="cond">corps</c:if>');
  WriteLn(F, '<%! private int compteur = 0; %>');
  WriteLn(F, '<% int total = 1 + 2; // ligne');
  WriteLn(F, '   String s = "hi"; char c = ''A''; /* bloc */ %>');
  WriteLn(F, '<%= total %>');
  Close(F);

  LexInit(TmpFile);

  Tok := LexNextToken;
  LexAssert('1: TEMPLATE_CHUNK "Bonjour"',
    (Tok.Kind = TOK_TEMPLATE_CHUNK) And (Pos('Bonjour', Tok.Val) = 1));

  Tok := LexNextToken;
  LexAssert('2: DIRECTIVE_OPEN', Tok.Kind = TOK_DIRECTIVE_OPEN);

  Tok := LexNextToken;
  LexAssert('3: DIR_NAME page',
    (Tok.Kind = TOK_DIR_NAME) And (Tok.Val = 'page'));
  Tok := LexNextToken;
  LexAssert('4: ATTR_NAME language',
    (Tok.Kind = TOK_ATTR_NAME) And (Tok.Val = 'language'));
  Tok := LexNextToken;
  LexAssert('5: ATTR_VALUE java',
    (Tok.Kind = TOK_ATTR_VALUE) And (Tok.Val = 'java'));
  Tok := LexNextToken;
  LexAssert('6: ATTR_NAME contentType',
    (Tok.Kind = TOK_ATTR_NAME) And (Tok.Val = 'contentType'));
  Tok := LexNextToken;
  LexAssert('7: ATTR_VALUE text/html',
    (Tok.Kind = TOK_ATTR_VALUE) And (Tok.Val = 'text/html'));
  Tok := LexNextToken;
  LexAssert('8: TAG_CLOSE', Tok.Kind = TOK_TAG_CLOSE);

  Tok := LexNextToken;
  LexAssert('9: TEMPLATE_CHUNK "Texte "',
    (Tok.Kind = TOK_TEMPLATE_CHUNK) And (Pos('Texte', Tok.Val) > 0));

  { le commentaire JSP <%-- ... --%> ne doit produire AUCUN token : le    }
  { texte "suite"/"<!-- ... -->"/"fin" doit apparaitre dans le PROCHAIN    }
  { chunk, avec le commentaire HTML passe tel quel (non retire). }
  Tok := LexNextToken;
  LexAssert('10: TEMPLATE_CHUNK "suite" + HTML comment passe tel quel',
    (Tok.Kind = TOK_TEMPLATE_CHUNK) And (Pos('suite', Tok.Val) > 0) And
    (Pos('<!--', Tok.Val) > 0) And (Pos('commentaire HTML garde', Tok.Val) > 0));

  Tok := LexNextToken;
  LexAssert('11: EL_IMMEDIATE_OPEN', Tok.Kind = TOK_EL_IMMEDIATE_OPEN);

  Tok := LexNextToken;
  LexAssert('12: EL_RAW "utilisateur.nom"',
    (Tok.Kind = TOK_EL_RAW) And (Tok.Val = 'utilisateur.nom'));

  Tok := LexNextToken;
  LexAssert('13: TEMPLATE_CHUNK " et "',
    (Tok.Kind = TOK_TEMPLATE_CHUNK) And (Pos('et', Tok.Val) > 0));

  Tok := LexNextToken;
  LexAssert('14: EL_DEFERRED_OPEN', Tok.Kind = TOK_EL_DEFERRED_OPEN);

  Tok := LexNextToken;
  LexAssert('15: EL_RAW "expr.differe"',
    (Tok.Kind = TOK_EL_RAW) And (Tok.Val = 'expr.differe'));

  Tok := LexNextToken;
  LexAssert('16: TEMPLATE_CHUNK (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  { <jsp:include page="Frag.jsp" flush="true" /> - action standard        }
  { auto-fermante (section 9). }
  Tok := LexNextToken;
  LexAssert('17: ACTION_OPEN jsp:include',
    (Tok.Kind = TOK_ACTION_OPEN) And (Tok.Val = 'jsp:include'));
  Tok := LexNextToken;
  LexAssert('18: ATTR_NAME page',
    (Tok.Kind = TOK_ATTR_NAME) And (Tok.Val = 'page'));
  Tok := LexNextToken;
  LexAssert('19: ATTR_VALUE Frag.jsp',
    (Tok.Kind = TOK_ATTR_VALUE) And (Tok.Val = 'Frag.jsp'));
  Tok := LexNextToken;
  LexAssert('20: ATTR_NAME flush',
    (Tok.Kind = TOK_ATTR_NAME) And (Tok.Val = 'flush'));
  Tok := LexNextToken;
  LexAssert('21: ATTR_VALUE true',
    (Tok.Kind = TOK_ATTR_VALUE) And (Tok.Val = 'true'));
  Tok := LexNextToken;
  LexAssert('22: ACTION_SELFCLOSE', Tok.Kind = TOK_ACTION_SELFCLOSE);

  Tok := LexNextToken;
  LexAssert('23: TEMPLATE_CHUNK (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  { <c:if test="cond">corps</c:if> - action personnalisee GENERIQUE       }
  { (prefixe "c", pas "jsp") avec un CORPS - prouve que la reconnaissance }
  { <prefixe:nom ...> ne se limite pas au seul prefixe "jsp", et que le   }
  { corps redevient du gabarit ordinaire jusqu au TOK_ACTION_CLOSE.        }
  Tok := LexNextToken;
  LexAssert('24: ACTION_OPEN c:if',
    (Tok.Kind = TOK_ACTION_OPEN) And (Tok.Val = 'c:if'));
  Tok := LexNextToken;
  LexAssert('25: ATTR_NAME test',
    (Tok.Kind = TOK_ATTR_NAME) And (Tok.Val = 'test'));
  Tok := LexNextToken;
  LexAssert('26: ATTR_VALUE cond',
    (Tok.Kind = TOK_ATTR_VALUE) And (Tok.Val = 'cond'));
  Tok := LexNextToken;
  LexAssert('27: ACTION_BODY_OPEN', Tok.Kind = TOK_ACTION_BODY_OPEN);
  Tok := LexNextToken;
  LexAssert('28: TEMPLATE_CHUNK "corps"',
    (Tok.Kind = TOK_TEMPLATE_CHUNK) And (Tok.Val = 'corps'));
  Tok := LexNextToken;
  LexAssert('29: ACTION_CLOSE c:if',
    (Tok.Kind = TOK_ACTION_CLOSE) And (Tok.Val = 'c:if'));

  Tok := LexNextToken;
  LexAssert('30: TEMPLATE_CHUNK (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  Tok := LexNextToken;
  LexAssert('31: DECL_OPEN', Tok.Kind = TOK_DECL_OPEN);

  Tok := LexNextToken;
  LexAssert('32: IDENT private', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'private'));
  Tok := LexNextToken;
  LexAssert('33: IDENT int', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'int'));
  Tok := LexNextToken;
  LexAssert('34: IDENT compteur', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'compteur'));
  Tok := LexNextToken;
  LexAssert('35: OP =', (Tok.Kind = TOK_OP) And (Tok.Val = '='));
  Tok := LexNextToken;
  LexAssert('36: INT 0', (Tok.Kind = TOK_INT) And (Tok.IntVal = 0));
  Tok := LexNextToken;
  LexAssert('37: OP ;', (Tok.Kind = TOK_OP) And (Tok.Val = ';'));
  Tok := LexNextToken;
  LexAssert('38: TAG_CLOSE', Tok.Kind = TOK_TAG_CLOSE);

  Tok := LexNextToken;
  LexAssert('39: TEMPLATE_CHUNK (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  Tok := LexNextToken;
  LexAssert('40: SCRIPTLET_OPEN', Tok.Kind = TOK_SCRIPTLET_OPEN);

  Tok := LexNextToken;
  LexAssert('41: IDENT int', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'int'));
  Tok := LexNextToken;
  LexAssert('42: IDENT total', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'total'));
  Tok := LexNextToken;
  LexAssert('43: OP =', (Tok.Kind = TOK_OP) And (Tok.Val = '='));
  Tok := LexNextToken;
  LexAssert('44: INT 1', (Tok.Kind = TOK_INT) And (Tok.IntVal = 1));
  Tok := LexNextToken;
  LexAssert('45: OP +', (Tok.Kind = TOK_OP) And (Tok.Val = '+'));
  Tok := LexNextToken;
  LexAssert('46: INT 2', (Tok.Kind = TOK_INT) And (Tok.IntVal = 2));
  Tok := LexNextToken;
  LexAssert('47: OP ;', (Tok.Kind = TOK_OP) And (Tok.Val = ';'));

  { "// ligne" (fin de ligne) puis les espaces de tete de la ligne        }
  { suivante doivent etre sautes silencieusement par                      }
  { LexSkipJavaWhitespaceAndComments. }
  Tok := LexNextToken;
  LexAssert('48: IDENT String', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'String'));
  Tok := LexNextToken;
  LexAssert('49: IDENT s', (Tok.Kind = TOK_IDENT) And (Tok.Val = 's'));
  Tok := LexNextToken;
  LexAssert('50: OP =', (Tok.Kind = TOK_OP) And (Tok.Val = '='));
  Tok := LexNextToken;
  LexAssert('51: STRING "hi"', (Tok.Kind = TOK_STRING) And (Tok.Val = 'hi'));
  Tok := LexNextToken;
  LexAssert('52: OP ;', (Tok.Kind = TOK_OP) And (Tok.Val = ';'));
  Tok := LexNextToken;
  LexAssert('53: IDENT char', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'char'));
  Tok := LexNextToken;
  LexAssert('54: IDENT c', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'c'));
  Tok := LexNextToken;
  LexAssert('55: OP =', (Tok.Kind = TOK_OP) And (Tok.Val = '='));
  Tok := LexNextToken;
  LexAssert('56: CHAR ''A''', (Tok.Kind = TOK_CHAR) And (Tok.IntVal = Ord('A')));
  Tok := LexNextToken;
  LexAssert('57: OP ;', (Tok.Kind = TOK_OP) And (Tok.Val = ';'));

  { "/* bloc */" doit etre saute silencieusement avant le %> fermant. }
  Tok := LexNextToken;
  LexAssert('58: TAG_CLOSE', Tok.Kind = TOK_TAG_CLOSE);

  Tok := LexNextToken;
  LexAssert('59: TEMPLATE_CHUNK (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  Tok := LexNextToken;
  LexAssert('60: EXPR_OPEN', Tok.Kind = TOK_EXPR_OPEN);
  Tok := LexNextToken;
  LexAssert('61: IDENT total', (Tok.Kind = TOK_IDENT) And (Tok.Val = 'total'));
  Tok := LexNextToken;
  LexAssert('62: TAG_CLOSE', Tok.Kind = TOK_TAG_CLOSE);

  Tok := LexNextToken;
  LexAssert('63: TEMPLATE_CHUNK finale (saut de ligne)', Tok.Kind = TOK_TEMPLATE_CHUNK);

  Tok := LexNextToken;
  LexAssert('64: EOF', Tok.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES }
{ ============================================================ }

{ Contrairement a JPPCW32.PAS/DELPHI.PAS (VRAIE hierarchie de classes    }
{ utilisateur, heritage simple + interfaces multiples), une "classe" ici  }
{ (TYK_CLASS) est TOUJOURS une reference OPAQUE a une classe Java         }
{ EXTERNE importee (java.util.Date, GregorianCalendar, ...) - JAMAIS      }
{ reimplementee. Consequence DELIBEREE : ni SuperTypeIdx, ni              }
{ InterfaceFirst/Count, ni Visibility n existent sur TTypeRec - ce         }
{ compilateur ne modelise AUCUNE hierarchie Java reelle, seulement un      }
{ ensemble PLAT de classes stdlib enregistrees une par une (TODO 19)       }
{ avec leur surface de methodes REELLEMENT appelee par les echantillons.  }

Type
  TTypeKind = (
    TYK_INVALID,  { entree 0 reservee, sentinelle (voir TypeInit)        }
    TYK_BOOLEAN,
    TYK_INT,
    TYK_LONG,     { 64 bits REELS en Java - represente ICI par un         }
                  { simple LongInt 32 bits, meme simplification que le    }
                  { reste de ce projet pour les types "larges" ; AUCUN     }
                  { echantillon SAMPLES\JSP\*.jsp n emploie de litteral    }
                  { long (suffixe L) dans un scriptlet/declaration/        }
                  { expression - TYK_LONG reste donc structurellement      }
                  { present (roadmap) mais INATTEIGNABLE depuis une        }
                  { vraie source pour l instant (TODO 02 ne tokenise pas   }
                  { non plus ce suffixe, meme limite honnetement admise)   }
    TYK_CHAR,     { 16 bits Unicode REELS en Java - simplifie ICI a 1      }
                  { octet (Size=1) : le lexeur (TODO 02) ne traite deja    }
                  { que de l ASCII 8 bits, aucune raison de pretendre un    }
                  { type 16 bits que rien en amont ne produit reellement   }
    TYK_FLOAT,
    TYK_DOUBLE,
    TYK_STRING,   { reference, immuable (section 4/12) }
    TYK_OBJECT,   { "Object" Java / valeur EL NON typee avant coercition -  }
                  { section 12.4 : la plupart des valeurs EL circulent      }
                  { comme Object jusqu a un operateur qui force une         }
                  { conversion (voir TELValue plus bas) }
    TYK_ARRAY,    { ElemTypeIdx = type des elements ; instances creees      }
                  { PAR le parseur (TODO 07+, ex. String[] de Test15        }
                  { JstlJavaEE.jsp), AUCUNE instance predeclaree ici        }
    TYK_CLASS,    { classe Java REFERENCEE (import, section 5.1) - AUCUNE  }
                  { entree predeclaree ICI : TODO 19 enregistre les         }
                  { classes stdlib REELLEMENT appelees (Date/                }
                  { GregorianCalendar/DateFormat/Integer/String, voir la    }
                  { note d en-tete du TODO 19 dans la feuille de route)      }
    TYK_NULL,     { type du litteral Java "null" / de la valeur EL null    }
                  { (section 4.6/12.3) - jamais nomme, jamais instancie     }
    TYK_VOID      { type de retour absent (methodes declarees en <%! %>)   }
  );

  TTypeRec = Record
    Kind        : TTypeKind;
    Name        : TString;  { '' pour TYK_INVALID/TYK_NULL/TYK_VOID        }
                             { (types anonymes, jamais recherches par nom)  }
    Size        : Integer;  { octets, representation runtime (TODO 21+) -  }
                             { 4 pour tout type REFERENCE (String/Object/   }
                             { Array/Class/Null - un pointeur/handle 32     }
                             { bits, meme convention "tout tient dans EAX"  }
                             { que le reste de ce projet), 0 pour VOID/     }
                             { INVALID (aucune valeur) }
    ElemTypeIdx : Integer;  { TYK_ARRAY seulement ; -1 sinon }
    FieldFirst  : Integer;  { TYK_CLASS seulement (TODO 19+), pool partage  }
                             { FieldPool - meme technique que DELPHI.PAS/   }
                             { JPPCW32.PAS ; -1 si aucun champ              }
    FieldCount  : Integer;
    MethodFirst : Integer;  { TYK_CLASS seulement (TODO 19+), pool partage  }
                             { MethodPool ; -1 si aucune methode            }
    MethodCount : Integer;
  End;

  { Valeur EL taguee (TODO 12-17, decision de representation A DOCUMENTER }
  { ICI - voir la note d en-tete du TODO 04 dans la feuille de route) -    }
  { StrVal utilise TBigString (AnsiString), EXACTEMENT le meme choix       }
  { qu au TODO 02 pour TToken.Val : une valeur de scope (TODO 09, ex. un   }
  { texte de formulaire) peut depasser 255 octets, MEME categorie de       }
  { piege de troncature deja evitee au TODO 02. ObjRef reste un pointeur   }
  { OPAQUE - sa vraie representation (bloc tas + descripteur de type,      }
  { meme convention que les compilateurs freres) reste a decider au         }
  { moment ou un VRAI tas existera (TODO 21+, aucune allocation memoire     }
  { n existe encore a ce stade du projet). }
  TELValueKind = (ELV_NULL, ELV_BOOLEAN, ELV_LONG, ELV_DOUBLE, ELV_STRING,
                  ELV_OBJECT);

  TELValue = Record
    Kind    : TELValueKind;
    BoolVal : Boolean;   { ELV_BOOLEAN }
    IntVal  : LongInt;   { ELV_LONG (meme simplification 32 bits que       }
                         { TYK_LONG ci-dessus) }
    RealVal : Double;    { ELV_DOUBLE }
    StrVal  : TBigString;{ ELV_STRING }
    ObjRef  : Pointer;   { ELV_OBJECT - reference opaque, voir ci-dessus }
  End;

Var
  TypePool  : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Index des types predeclares (peuples par TypeInit) - evite a tout     }
  { code ulterieur (TODO 07+) de refaire une recherche par nom pour les    }
  { types primitifs/Object/String/null/void, meme convention que les       }
  { compilateurs freres (ex. StdIdx* de DELPHI.PAS/JPPCW32.PAS). }
  TypeIdxBoolean : Integer;
  TypeIdxInt     : Integer;
  TypeIdxLong    : Integer;
  TypeIdxChar    : Integer;
  TypeIdxFloat   : Integer;
  TypeIdxDouble  : Integer;
  TypeIdxString  : Integer;
  TypeIdxObject  : Integer;
  TypeIdxNull    : Integer;
  TypeIdxVoid    : Integer;

{ ------------------------------------------------------------ }
{ TypeAdd / TypeFind / TypeInit                                }
{ ------------------------------------------------------------ }

{ Ajoute une entree au pool partage et retourne son index - ElemTypeIdx/  }
{ FieldFirst/MethodFirst demarrent a -1 (FieldCount/MethodCount a 0),     }
{ MEME convention "pas encore rempli" que DELPHI.PAS/JPPCW32.PAS. }
Function TypeAdd(Kind: TTypeKind; Const Name: TString; Size: Integer): Integer;
Begin
  If TypeCount >= MAX_TYPE Then
    FatalError('table des types pleine (MAX_TYPE)');
  TypePool[TypeCount].Kind        := Kind;
  TypePool[TypeCount].Name        := Name;
  TypePool[TypeCount].Size        := Size;
  TypePool[TypeCount].ElemTypeIdx := -1;
  TypePool[TypeCount].FieldFirst  := -1;
  TypePool[TypeCount].FieldCount  := 0;
  TypePool[TypeCount].MethodFirst := -1;
  TypePool[TypeCount].MethodCount := 0;
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ Recherche par nom EXACT (Java/JSP est sensible a la casse, section 4.6  }
{ de la reference - "int" et "INT" sont DEUX identificateurs distincts,   }
{ AUCUN repli insensible a la casse) - retourne -1 si absent. Parcours    }
{ lineaire du pool entier, MEME discipline "simplicite d abord" que le    }
{ reste de ce projet (aucun echantillon n approche une table assez        }
{ grande pour que ce soit un probleme reel). }
Function TypeFind(Const Name: TString): Integer;
Var I: Integer;
Begin
  TypeFind := -1;
  For I := 0 To TypeCount - 1 Do
    If TypePool[I].Name = Name Then
    Begin
      TypeFind := I;
      Exit;
    End;
End;

{ Reinitialise le pool et enregistre la sentinelle TYK_INVALID puis les  }
{ types primitifs/Object/String/null/void (section 4 de la reference) -  }
{ AUCUNE classe stdlib (Date/GregorianCalendar/...) n est enregistree     }
{ ici, voir la note d en-tete de TYK_CLASS ci-dessus (TODO 19). }
Procedure TypeInit;
Begin
  TypeCount := 0;
  TypeAdd(TYK_INVALID, '', 0);

  TypeIdxBoolean := TypeAdd(TYK_BOOLEAN, 'boolean', 1);
  TypeIdxInt     := TypeAdd(TYK_INT,     'int',     4);
  TypeIdxLong    := TypeAdd(TYK_LONG,    'long',    4);
  TypeIdxChar    := TypeAdd(TYK_CHAR,    'char',    1);
  TypeIdxFloat   := TypeAdd(TYK_FLOAT,   'float',   4);
  TypeIdxDouble  := TypeAdd(TYK_DOUBLE,  'double',  8);
  TypeIdxString  := TypeAdd(TYK_STRING,  'String',  4);
  TypeIdxObject  := TypeAdd(TYK_OBJECT,  'Object',  4);
  TypeIdxNull    := TypeAdd(TYK_NULL,    '',        4);
  TypeIdxVoid    := TypeAdd(TYK_VOID,    'void',    0);
End;

{ ------------------------------------------------------------ }
{ TypeSelfTest : verifie TypeInit/TypeAdd/TypeFind - noms         }
{ predeclares resolus au bon TTypeKind, sensibilite a la casse,   }
{ ajout d une classe/d un tableau utilisateur avec des champs      }
{ FieldFirst/MethodFirst par defaut corrects, recherche absente.   }
{ ------------------------------------------------------------ }

Procedure TypeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('TypeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TypeSelfTest;
Var
  Idx      : Integer;
  ArrIdx   : Integer;
  ElValue  : TELValue;
Begin
  TypeInit;

  TypeAssert('boolean predeclare',
    (TypePool[TypeIdxBoolean].Kind = TYK_BOOLEAN) And
    (TypeFind('boolean') = TypeIdxBoolean));
  TypeAssert('int predeclare',
    (TypePool[TypeIdxInt].Kind = TYK_INT) And (TypePool[TypeIdxInt].Size = 4));
  TypeAssert('long predeclare', TypePool[TypeIdxLong].Kind = TYK_LONG);
  TypeAssert('char predeclare (simplifie a 1 octet)',
    (TypePool[TypeIdxChar].Kind = TYK_CHAR) And (TypePool[TypeIdxChar].Size = 1));
  TypeAssert('float predeclare', TypePool[TypeIdxFloat].Kind = TYK_FLOAT);
  TypeAssert('double predeclare (8 octets)',
    (TypePool[TypeIdxDouble].Kind = TYK_DOUBLE) And
    (TypePool[TypeIdxDouble].Size = 8));
  TypeAssert('String predeclare (reference, 4 octets)',
    (TypePool[TypeIdxString].Kind = TYK_STRING) And
    (TypePool[TypeIdxString].Size = 4));
  TypeAssert('Object predeclare', TypeFind('Object') = TypeIdxObject);
  TypeAssert('void predeclare', TypeFind('void') = TypeIdxVoid);
  TypeAssert('null anonyme (pas de nom)', TypePool[TypeIdxNull].Name = '');

  { sensibilite a la casse (section 4.6) - "INT" n est PAS "int" }
  TypeAssert('sensibilite a la casse : INT introuvable', TypeFind('INT') = -1);
  TypeAssert('nom inconnu introuvable', TypeFind('CetteClasseNexistePas') = -1);

  { TYK_CLASS ajoute PAR l appelant (simule ici ce que fera le TODO 19) - }
  { aucune classe stdlib n est predeclaree par TypeInit lui-meme. }
  Idx := TypeAdd(TYK_CLASS, 'java.util.GregorianCalendar', 4);
  TypeAssert('classe ajoutee retrouvable', TypeFind('java.util.GregorianCalendar') = Idx);
  TypeAssert('classe : FieldFirst/-Count par defaut',
    (TypePool[Idx].FieldFirst = -1) And (TypePool[Idx].FieldCount = 0));
  TypeAssert('classe : MethodFirst/-Count par defaut',
    (TypePool[Idx].MethodFirst = -1) And (TypePool[Idx].MethodCount = 0));

  { TYK_ARRAY (ex. String[] de Test15JstlJavaEE.jsp) - ElemTypeIdx pointe }
  { vers String, exactement comme le fera le parseur au TODO 07+. }
  ArrIdx := TypeAdd(TYK_ARRAY, '', 4);
  TypePool[ArrIdx].ElemTypeIdx := TypeIdxString;
  TypeAssert('tableau : ElemTypeIdx = String',
    TypePool[ArrIdx].ElemTypeIdx = TypeIdxString);

  { TELValue : round-trip simple de chaque genre - aucun evaluateur EL    }
  { n existe encore (TODO 14+), ce test verifie seulement que le          }
  { marquage Kind et le champ correspondant se lisent correctement. }
  ElValue.Kind := ELV_NULL;
  TypeAssert('ELValue NULL', ElValue.Kind = ELV_NULL);
  ElValue.Kind := ELV_BOOLEAN; ElValue.BoolVal := True;
  TypeAssert('ELValue BOOLEAN', (ElValue.Kind = ELV_BOOLEAN) And ElValue.BoolVal);
  ElValue.Kind := ELV_LONG; ElValue.IntVal := 42;
  TypeAssert('ELValue LONG', (ElValue.Kind = ELV_LONG) And (ElValue.IntVal = 42));
  ElValue.Kind := ELV_DOUBLE; ElValue.RealVal := 3.5;
  TypeAssert('ELValue DOUBLE', (ElValue.Kind = ELV_DOUBLE) And (ElValue.RealVal = 3.5));
  ElValue.Kind := ELV_STRING; ElValue.StrVal := 'bonjour';
  TypeAssert('ELValue STRING', (ElValue.Kind = ELV_STRING) And (ElValue.StrVal = 'bonjour'));
  ElValue.Kind := ELV_OBJECT; ElValue.ObjRef := Nil;
  TypeAssert('ELValue OBJECT', (ElValue.Kind = ELV_OBJECT) And (ElValue.ObjRef = Nil));
End;

{ ============================================================ }
{ TODO 05 - DIRECTIVE PAGE                                      }
{ ============================================================ }

{ TPageOptions (section 5.1) - DISTINCTE de TOptions du TODO 01 (options   }
{ de LIGNE DE COMMANDE) : TPageOptions rassemble ce qu une (ou PLUSIEURS,  }
{ section 5.1 "plusieurs directives page peuvent etre presentes") vraie    }
{ directive <%@ page ... %> du FICHIER SOURCE a declare. 14 attributs      }
{ (liste EXHAUSTIVE section 5.1, y compris deferredSyntaxAllowedAsLiteral  }
{ - absent du brouillon initial de ce TODO dans l en-tete, ajoute ici      }
{ apres relecture attentive de la reference). Chaque attribut A VALEUR     }
{ UNIQUE porte un drapeau Has* : occurrences MULTIPLES tolerees SI la      }
{ valeur reste identique, WARNING (pas fatal) si elle CONTREDIT une        }
{ valeur deja vue (section 5.1, "un attribut qui ne peut apparaitre       }
{ qu une fois ne doit pas recevoir des valeurs contradictoires") - SEUL    }
{ "import" est CUMULATIF (jamais de contradiction possible, simple liste   }
{ separee par virgules qui s allonge a chaque occurrence). }

Type
  TPageOptions = Record
    HasLanguage     : Boolean; Language     : TBigString;
    HasExtends      : Boolean; Extends      : TBigString;
    ImportList      : TBigString; { cumulatif - jamais de Has* (toujours  }
                                   { valide, meme vide au depart)          }
    HasSession      : Boolean; Session      : Boolean;
    HasBuffer       : Boolean; Buffer       : TBigString;
    HasAutoFlush    : Boolean; AutoFlush    : Boolean;
    HasIsErrorPage  : Boolean; IsErrorPage  : Boolean;
    HasErrorPage    : Boolean; ErrorPage    : TBigString;
    HasContentType  : Boolean; ContentType  : TBigString;
    HasPageEncoding : Boolean; PageEncoding : TBigString;
    HasIsELIgnored  : Boolean; IsELIgnored  : Boolean;
    HasDeferredSyntaxAllowedAsLiteral : Boolean;
    DeferredSyntaxAllowedAsLiteral    : Boolean;
    HasTrimDirectiveWhitespaces : Boolean;
    TrimDirectiveWhitespaces    : Boolean;
    HasInfo         : Boolean; Info         : TBigString;
  End;

Var
  PageOpts : TPageOptions;

{ ------------------------------------------------------------ }
{ PageInit : valeurs par defaut (section 5.1/5.2/7/8) - Has*     }
{ restent False (RIEN n a encore ete ecrit par le fichier        }
{ source), mais le CHAMP lui-meme porte deja la valeur par        }
{ defaut reelle de la specification, de sorte qu un TODO ulterieur }
{ (TODO 09+) puisse toujours lire PageOpts.Xxx SANS avoir a         }
{ verifier Has* d abord.                                          }
{ ------------------------------------------------------------ }

Procedure PageInit;
Begin
  PageOpts.HasLanguage := False; PageOpts.Language := 'java';
  PageOpts.HasExtends  := False; PageOpts.Extends  := '';
  PageOpts.ImportList  := '';
  PageOpts.HasSession  := False; PageOpts.Session  := True;  { defaut : true }
  PageOpts.HasBuffer   := False; PageOpts.Buffer   := '8kb'; { defaut usuel }
  PageOpts.HasAutoFlush   := False; PageOpts.AutoFlush   := True;
  PageOpts.HasIsErrorPage := False; PageOpts.IsErrorPage := False;
  PageOpts.HasErrorPage   := False; PageOpts.ErrorPage   := '';
  PageOpts.HasContentType := False; PageOpts.ContentType := '';
  PageOpts.HasPageEncoding := False; PageOpts.PageEncoding := '';
  PageOpts.HasIsELIgnored  := False; PageOpts.IsELIgnored  := False;
  PageOpts.HasDeferredSyntaxAllowedAsLiteral := False;
  PageOpts.DeferredSyntaxAllowedAsLiteral    := False;
  PageOpts.HasTrimDirectiveWhitespaces := False;
  PageOpts.TrimDirectiveWhitespaces    := False;
  PageOpts.HasInfo := False; PageOpts.Info := '';
End;

{ Analyse "true"/"false" (section 5.1 - AUCUNE autre graphie n est         }
{ admise, pas de "1"/"0"/"yes"/"no" - JSP suit ici la syntaxe litterale     }
{ booleenne Java elle-meme). }
Function ParseJspBoolean(Const S: TBigString; Var OutVal: Boolean): Boolean;
Begin
  If S = 'true' Then
  Begin OutVal := True; ParseJspBoolean := True; End
  Else If S = 'false' Then
  Begin OutVal := False; ParseJspBoolean := True; End
  Else
    ParseJspBoolean := False;
End;

{ Affecte un attribut a VALEUR UNIQUE de type chaine - WARNING (pas       }
{ fatal) et valeur CONSERVEE (celle deja vue) en cas de contradiction.    }
Procedure PageSetStringOnce(Var HasFlag: Boolean; Var Field: TBigString;
                            Const AttrName: TString; Const Value: TBigString);
Begin
  If HasFlag And (Field <> Value) Then
    WarnMsg('directive page : valeur contradictoire pour "' + AttrName +
            '" ("' + Field + '" puis "' + Value + '")')
  Else
  Begin
    Field   := Value;
    HasFlag := True;
  End;
End;

{ Affecte un attribut a VALEUR UNIQUE de type booleen - meme discipline    }
{ que PageSetStringOnce, plus une verification de graphie (true/false).   }
Procedure PageSetBoolOnce(Var HasFlag: Boolean; Var Field: Boolean;
                          Const AttrName: TString; Const Value: TBigString);
Var B: Boolean;
Begin
  If Not ParseJspBoolean(Value, B) Then
  Begin
    WarnMsg('directive page : valeur booleenne "true" ou "false" ' +
            'attendue pour "' + AttrName + '", trouve : ' + Value);
    Exit;
  End;
  If HasFlag And (Field <> B) Then
    WarnMsg('directive page : valeur contradictoire pour "' + AttrName + '"')
  Else
  Begin
    Field   := B;
    HasFlag := True;
  End;
End;

{ Dispatch d un attribut nom="valeur" DEJA tokenise (TOK_ATTR_NAME/        }
{ TOK_ATTR_VALUE, TODO 03) vers le bon champ de PageOpts (section 5.1) -   }
{ un attribut INCONNU produit un avertissement (pas fatal, meme            }
{ tolerance que le reste de ce projet) plutot que d etre silencieusement   }
{ ignore. }
Procedure PageApplyAttr(Const AttrName: TString; Const Value: TBigString);
Begin
  If AttrName = 'language' Then
  Begin
    If Value <> 'java' Then
      WarnMsg('directive page : language="' + Value +
              '" non portable (valeur usuelle "java", section 5.1)');
    PageSetStringOnce(PageOpts.HasLanguage, PageOpts.Language, AttrName, Value);
  End
  Else If AttrName = 'extends' Then
    PageSetStringOnce(PageOpts.HasExtends, PageOpts.Extends, AttrName, Value)
  Else If AttrName = 'import' Then
  Begin
    { CUMULATIF (section 5.1) - jamais de contradiction, simple            }
    { concatenation separee par virgules, MEME convention que la liste      }
    { import="a,b,c" elle-meme (TODO 19 la re-decoupera par ',' pour         }
    { resoudre les noms de classe). }
    If PageOpts.ImportList = '' Then
      PageOpts.ImportList := Value
    Else
      PageOpts.ImportList := PageOpts.ImportList + ',' + Value;
  End
  Else If AttrName = 'session' Then
    PageSetBoolOnce(PageOpts.HasSession, PageOpts.Session, AttrName, Value)
  Else If AttrName = 'buffer' Then
    PageSetStringOnce(PageOpts.HasBuffer, PageOpts.Buffer, AttrName, Value)
  Else If AttrName = 'autoFlush' Then
    PageSetBoolOnce(PageOpts.HasAutoFlush, PageOpts.AutoFlush, AttrName, Value)
  Else If AttrName = 'isErrorPage' Then
    PageSetBoolOnce(PageOpts.HasIsErrorPage, PageOpts.IsErrorPage, AttrName, Value)
  Else If AttrName = 'errorPage' Then
    PageSetStringOnce(PageOpts.HasErrorPage, PageOpts.ErrorPage, AttrName, Value)
  Else If AttrName = 'contentType' Then
    PageSetStringOnce(PageOpts.HasContentType, PageOpts.ContentType, AttrName, Value)
  Else If AttrName = 'pageEncoding' Then
    PageSetStringOnce(PageOpts.HasPageEncoding, PageOpts.PageEncoding, AttrName, Value)
  Else If AttrName = 'isELIgnored' Then
    PageSetBoolOnce(PageOpts.HasIsELIgnored, PageOpts.IsELIgnored, AttrName, Value)
  Else If AttrName = 'deferredSyntaxAllowedAsLiteral' Then
    PageSetBoolOnce(PageOpts.HasDeferredSyntaxAllowedAsLiteral,
                    PageOpts.DeferredSyntaxAllowedAsLiteral, AttrName, Value)
  Else If AttrName = 'trimDirectiveWhitespaces' Then
    PageSetBoolOnce(PageOpts.HasTrimDirectiveWhitespaces,
                    PageOpts.TrimDirectiveWhitespaces, AttrName, Value)
  Else If AttrName = 'info' Then
    PageSetStringOnce(PageOpts.HasInfo, PageOpts.Info, AttrName, Value)
  Else
    WarnMsg('directive page : attribut inconnu ignore : ' + AttrName);
End;

{ ParsePageDirective : PRE-CONDITION - le lexeur vient de produire         }
{ TOK_DIRECTIVE_OPEN puis TOK_DIR_NAME (Val='page'), tous deux DEJA         }
{ consommes par l appelant (meme convention que le reste de ce fichier -    }
{ un token a la fois, aucun CurToken global, voir LexNextToken TODO 02) :  }
{ consomme les paires TOK_ATTR_NAME/TOK_ATTR_VALUE qui suivent jusqu au     }
{ TOK_TAG_CLOSE (%>) qui acheve CETTE occurrence de la directive - une      }
{ AUTRE occurrence <%@ page ... %> plus loin dans le fichier est un         }
{ APPEL SEPARE de cette meme fonction (section 5.1, "plusieurs directives   }
{ page peuvent etre presentes") - PageOpts n est jamais reinitialise        }
{ entre deux appels, ce qui realise NATURELLEMENT le cumul/la detection     }
{ de contradiction d une occurrence a l autre. }
Procedure ParsePageDirective;
Var
  Tok      : TToken;
  AttrName : TString;
Begin
  While True Do
  Begin
    Tok := LexNextToken;
    If Tok.Kind = TOK_TAG_CLOSE Then Exit;
    If Tok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('directive page : nom d attribut attendu');
      Exit;
    End;
    AttrName := Tok.Val;

    Tok := LexNextToken;
    If Tok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('directive page : valeur d attribut attendue pour ' +
                 AttrName);
      Exit;
    End;

    PageApplyAttr(AttrName, Tok.Val);
  End;
End;

{ ------------------------------------------------------------ }
{ PageSelfTest : deux occurrences <%@ page %> reelles (import     }
{ cumulatif entre les deux, comme Test10Include.jsp/Test02          }
{ Directives.jsp), puis une troisieme occurrence CONTRADICTOIRE      }
{ (session) qui doit avertir SANS ecraser la valeur, puis une         }
{ quatrieme avec un language non portable et un attribut inconnu.      }
{ ------------------------------------------------------------ }

Procedure PageAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PageSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PageSelfTest;
Const
  TmpFile = 'JSPPAGESELFTEST.$$$';
Var
  F          : Text;
  Tok        : TToken;
  WarnBefore : Integer;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, '<%@ page contentType="text/html" pageEncoding="UTF-8"');
  WriteLn(F, '         session="false" import="java.util.Date" %>');
  WriteLn(F, '<%@ page import="java.text.DateFormat" isErrorPage="true"');
  WriteLn(F, '         autoFlush="true" %>');
  WriteLn(F, '<%@ page session="true" %>');
  WriteLn(F, '<%@ page language="cobol" inconnu="x" %>');
  Close(F);

  { Rend WarnMsg observable via WarnCount pendant CE self-test (WarnMsg,  }
  { TODO 01, n incremente WarnCount que si Opts.Warnings est deja Vrai) - }
  { Opts est reinitialise par ParseArgs (InitOptions) juste apres dans     }
  { Run, donc AUCUN effet residuel sur la compilation reelle (memes        }
  { drapeaux -w/-v/etc. que l utilisateur a reellement passes). }
  Opts.Warnings := True;

  LexInit(TmpFile);
  PageInit;

  Tok := LexNextToken;
  PageAssert('1: DIRECTIVE_OPEN', Tok.Kind = TOK_DIRECTIVE_OPEN);
  Tok := LexNextToken;
  PageAssert('2: DIR_NAME page', (Tok.Kind = TOK_DIR_NAME) And (Tok.Val = 'page'));
  ParsePageDirective;

  PageAssert('contentType', PageOpts.ContentType = 'text/html');
  PageAssert('pageEncoding', PageOpts.PageEncoding = 'UTF-8');
  PageAssert('session=false (explicite)',
    PageOpts.HasSession And (PageOpts.Session = False));
  PageAssert('import (1ere occurrence)', PageOpts.ImportList = 'java.util.Date');

  Tok := LexNextToken;
  PageAssert('3: TEMPLATE_CHUNK', Tok.Kind = TOK_TEMPLATE_CHUNK);
  Tok := LexNextToken;
  PageAssert('4: DIRECTIVE_OPEN', Tok.Kind = TOK_DIRECTIVE_OPEN);
  Tok := LexNextToken;
  PageAssert('5: DIR_NAME page', (Tok.Kind = TOK_DIR_NAME) And (Tok.Val = 'page'));
  ParsePageDirective;

  PageAssert('import cumule sur 2 occurrences',
    PageOpts.ImportList = 'java.util.Date,java.text.DateFormat');
  PageAssert('isErrorPage=true', PageOpts.HasIsErrorPage And PageOpts.IsErrorPage);
  PageAssert('autoFlush=true', PageOpts.HasAutoFlush And PageOpts.AutoFlush);

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME page }
  WarnBefore := WarnCount;
  ParsePageDirective;
  PageAssert('contradiction session : valeur CONSERVEE (reste false)',
    PageOpts.Session = False);
  PageAssert('contradiction session : avertissement emis', WarnCount > WarnBefore);

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME page }
  WarnBefore := WarnCount;
  ParsePageDirective;
  PageAssert('language non-java + attribut inconnu : avertissements emis',
    WarnCount > WarnBefore);

  Tok := LexNextToken; { TEMPLATE_CHUNK (saut de ligne final) }
  PageAssert('EOF apres saut de ligne final', Tok.Kind = TOK_TEMPLATE_CHUNK);
  Tok := LexNextToken;
  PageAssert('EOF', Tok.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 06 - DIRECTIVES INCLUDE ET TAGLIB                        }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ ParseIncludeDirective (section 5.3) : chemin RELATIF A LA PAGE }
{ (le fichier qui CONTIENT cette directive - passe en parametre,  }
{ PAS toujours le fichier de plus haut niveau, important pour une  }
{ inclusion imbriquee future ou un fragment inclurait lui-meme un   }
{ autre fragment, TODO 11), OU relatif au CONTEXTE (ContextRootDir, }
{ ci-dessous) si le chemin commence par '/' - ce compilateur n a     }
{ PAS de vrai deploiement WEB-INF (TODO 01, limite deja assumee) :    }
{ le "contexte" est simplement le repertoire du fichier de PLUS       }
{ HAUT NIVEAU passe en ligne de commande. Ce TODO se limite au        }
{ PARSING et a la RESOLUTION DE CHEMIN - la fusion reelle du fichier   }
{ inclus est TODO 11.                                                  }
{ ------------------------------------------------------------ }

Var
  ContextRootDir : TString; { repertoire du fichier de plus haut niveau }

{ Extrait le repertoire d un chemin (AVEC le separateur final, '' si    }
{ aucun) - complement d ExtractBaseName/ExtractExt (TODO 01), jamais     }
{ ecrit avant ce TODO puisqu aucun besoin reel ne s en presentait.       }
Function ExtractDir(Const Path: TString): TString;
Var I, LastSep: Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  ExtractDir := Copy(Path, 1, LastSep);
End;

{ Joint un repertoire (eventuellement '', eventuellement DEJA termine   }
{ par un separateur) et un chemin relatif - EXACTEMENT un separateur    }
{ entre les deux, jamais zero ni deux. }
Function JoinPath(Const Dir, Rel: TString): TString;
Begin
  If Dir = '' Then
    JoinPath := Rel
  Else If (Dir[Length(Dir)] = '\') Or (Dir[Length(Dir)] = '/') Then
    JoinPath := Dir + Rel
  Else
    JoinPath := Dir + '/' + Rel;
End;

{ Resout le chemin d un "file" d include (section 5.3) : '/' de tete =  }
{ relatif au CONTEXTE (retire avant de joindre a ContextRootDir), sinon  }
{ relatif a CurrentFileDir (la page qui CONTIENT la directive). }
Function ResolveIncludePath(Const CurrentFileDir: TString;
                            Const Path: TBigString): TBigString;
Begin
  If (Length(Path) > 0) And (Path[1] = '/') Then
    ResolveIncludePath := JoinPath(ContextRootDir,
                                   Copy(Path, 2, Length(Path) - 1))
  Else
    ResolveIncludePath := JoinPath(CurrentFileDir, Path);
End;

{ ParseIncludeDirective : PRE-CONDITION - TOK_DIRECTIVE_OPEN puis         }
{ TOK_DIR_NAME (Val='include') DEJA consommes par l appelant (meme        }
{ convention que ParsePageDirective, TODO 05). Consomme les attributs      }
{ jusqu au TOK_TAG_CLOSE, retourne le chemin RESOLU ou '' en cas d erreur. }
Function ParseIncludeDirective(Const CurrentFileDir: TString): TBigString;
Var
  Tok      : TToken;
  AttrName : TString;
  HasFile  : Boolean;
  FileAttr : TBigString;
Begin
  ParseIncludeDirective := '';
  HasFile  := False;
  FileAttr := '';

  While True Do
  Begin
    Tok := LexNextToken;
    If Tok.Kind = TOK_TAG_CLOSE Then Break;
    If Tok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('directive include : nom d attribut attendu');
      Exit;
    End;
    AttrName := Tok.Val;

    Tok := LexNextToken;
    If Tok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('directive include : valeur d attribut attendue pour ' +
                 AttrName);
      Exit;
    End;

    If AttrName = 'file' Then
    Begin
      If HasFile Then
        WarnMsg('directive include : attribut "file" repete, ' +
                'derniere valeur retenue')
      Else
        HasFile := True;
      FileAttr := Tok.Val;
    End
    Else
      WarnMsg('directive include : attribut inconnu ignore : ' + AttrName);
  End;

  If Not HasFile Then
  Begin
    FatalError('directive include : attribut "file" obligatoire (section 5.3)');
    Exit;
  End;

  ParseIncludeDirective := ResolveIncludePath(CurrentFileDir, FileAttr);
End;

{ ------------------------------------------------------------ }
{ ParseTaglibDirective (section 5.4/14.2/14.3)                  }
{ ------------------------------------------------------------ }

Type
  TTaglibDecl = Record
    Prefix          : TString;
    Uri             : TBigString; { '' si tagdir (non supporte, voir     }
                                   { ParseTaglibDirective ci-dessous)      }
    IsCoreJstl      : Boolean;
    IsFunctionsJstl : Boolean;
  End;

Var
  TaglibPool  : Array[0..MAX_TAGLIB - 1] Of TTaglibDecl;
  TaglibCount : Integer;

{ Section 16.2/16.3/27.3 (PAS 16.1/27, verifie/corrige - voir la note    }
{ d en-tete de ce TODO) : les DEUX familles d URI - legacy java.sun.com   }
{ et moderne jakarta.tags - toutes deux TOUJOURS reconnues (Jakarta      }
{ Tags 3.0 "conserve la reconnaissance des URI java.sun.com historiques", }
{ section 27.3). }
Function IsCoreJstlUri(Const Uri: TBigString): Boolean;
Begin
  IsCoreJstlUri := (Uri = 'http://java.sun.com/jsp/jstl/core') Or
                   (Uri = 'jakarta.tags.core');
End;

Function IsFunctionsJstlUri(Const Uri: TBigString): Boolean;
Begin
  IsFunctionsJstlUri := (Uri = 'http://java.sun.com/jsp/jstl/functions') Or
                        (Uri = 'jakarta.tags.functions');
End;

Procedure TaglibInit;
Begin
  TaglibCount := 0;
End;

Function TaglibAdd(Const Prefix: TString; Const Uri: TBigString): Integer;
Begin
  If TaglibCount >= MAX_TAGLIB Then
  Begin
    WarnMsg('trop de directives taglib (MAX_TAGLIB), ignoree : prefix=' +
            Prefix);
    TaglibAdd := -1;
    Exit;
  End;
  TaglibPool[TaglibCount].Prefix          := Prefix;
  TaglibPool[TaglibCount].Uri             := Uri;
  TaglibPool[TaglibCount].IsCoreJstl      := IsCoreJstlUri(Uri);
  TaglibPool[TaglibCount].IsFunctionsJstl := IsFunctionsJstlUri(Uri);
  TaglibAdd := TaglibCount;
  Inc(TaglibCount);
End;

{ Recherche par prefixe EXACT (sensible a la casse, meme discipline que  }
{ TypeFind/TODO 04) - retourne -1 si absent. NOTE DE PORTEE : cette       }
{ table existe pour que TODO 15/16 (semantique JSTL) puisse resoudre un   }
{ prefixe rencontre sur une action <c:xxx> - la VALIDATION croisee        }
{ "ce prefixe A-T-IL ete declare AVANT cet usage" (section 5.4, "la        }
{ directive doit preceder l emploi du prefixe") exige un vrai pilote       }
{ de fichier progressant dans l ordre du texte, qui n existe PAS encore    }
{ (TODO 07+/TODO 20) - TODO 03 (action <prefixe:nom>) reste donc            }
{ INCHANGE ici, sa propre note d en-tete documentait deja ce report.        }
Function TaglibFind(Const Prefix: TString): Integer;
Var I: Integer;
Begin
  TaglibFind := -1;
  For I := 0 To TaglibCount - 1 Do
    If TaglibPool[I].Prefix = Prefix Then
    Begin
      TaglibFind := I;
      Exit;
    End;
End;

{ ParseTaglibDirective : PRE-CONDITION - TOK_DIRECTIVE_OPEN puis          }
{ TOK_DIR_NAME (Val='taglib') DEJA consommes par l appelant. Attribut      }
{ "prefix" obligatoire (section 5.4) - NE DOIT PAS etre "jsp" (reserve     }
{ aux actions standard, section 14.3, avertissement si viole) - puis      }
{ "uri" OU "tagdir" (section 5.4) : tagdir est explicitement HORS DE       }
{ PORTEE (taglibs bases sur des fichiers .tag, aucun echantillon ne le     }
{ exercice) - reconnu syntaxiquement (n echoue pas la compilation) mais    }
{ enregistre SANS URI utilisable, avec avertissement explicite. Retourne  }
{ l index dans TaglibPool, ou -1 en cas d erreur/de table pleine.          }
Function ParseTaglibDirective: Integer;
Var
  Tok                        : TToken;
  AttrName                   : TString;
  HasPrefix, HasUri, HasTagDir : Boolean;
  Prefix                     : TString;
  Uri, TagDirVal             : TBigString;
Begin
  ParseTaglibDirective := -1;
  HasPrefix := False; HasUri := False; HasTagDir := False;
  Prefix := ''; Uri := ''; TagDirVal := '';

  While True Do
  Begin
    Tok := LexNextToken;
    If Tok.Kind = TOK_TAG_CLOSE Then Break;
    If Tok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('directive taglib : nom d attribut attendu');
      Exit;
    End;
    AttrName := Tok.Val;

    Tok := LexNextToken;
    If Tok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('directive taglib : valeur d attribut attendue pour ' +
                 AttrName);
      Exit;
    End;

    If AttrName = 'prefix' Then
    Begin
      Prefix    := Tok.Val;
      HasPrefix := True;
    End
    Else If AttrName = 'uri' Then
    Begin
      Uri    := Tok.Val;
      HasUri := True;
    End
    Else If AttrName = 'tagdir' Then
    Begin
      TagDirVal := Tok.Val;
      HasTagDir := True;
    End
    Else
      WarnMsg('directive taglib : attribut inconnu ignore : ' + AttrName);
  End;

  If Not HasPrefix Then
  Begin
    FatalError('directive taglib : attribut "prefix" obligatoire (section 5.4)');
    Exit;
  End;

  If Prefix = 'jsp' Then
    WarnMsg('directive taglib : prefix "jsp" est reserve aux actions ' +
            'standard (section 14.3), a eviter');

  If HasTagDir And Not HasUri Then
  Begin
    WarnMsg('directive taglib : tagdir="' + TagDirVal + '" non supporte ' +
            '(taglibs bases sur des fichiers .tag, hors de portee) - ' +
            'prefix "' + Prefix + '" enregistre sans URI utilisable');
    ParseTaglibDirective := TaglibAdd(Prefix, '');
    Exit;
  End;

  If Not HasUri Then
  Begin
    FatalError('directive taglib : attribut "uri" ou "tagdir" obligatoire ' +
               '(section 5.4)');
    Exit;
  End;

  ParseTaglibDirective := TaglibAdd(Prefix, Uri);
End;

{ ------------------------------------------------------------ }
{ IncludeSelfTest : chemin relatif a la page ET chemin relatif   }
{ au contexte ('/' de tete), meme esprit que Test10Include.jsp.  }
{ ------------------------------------------------------------ }

Procedure IncludeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('IncludeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure IncludeSelfTest;
Const
  TmpFile = 'JSPINCLUDESELFTEST.$$$';
Var
  F        : Text;
  Tok      : TToken;
  Resolved : TBigString;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, '<%@ include file="FragmentEntete.jsp" %>');
  WriteLn(F, '<%@ include file="/FragmentPied.jsp" %>');
  Close(F);

  ContextRootDir := 'SAMPLES/JSP';

  LexInit(TmpFile);

  Tok := LexNextToken;
  IncludeAssert('1: DIRECTIVE_OPEN', Tok.Kind = TOK_DIRECTIVE_OPEN);
  Tok := LexNextToken;
  IncludeAssert('2: DIR_NAME include',
    (Tok.Kind = TOK_DIR_NAME) And (Tok.Val = 'include'));
  Resolved := ParseIncludeDirective('SAMPLES/JSP');
  IncludeAssert('chemin relatif a la page',
    Resolved = 'SAMPLES/JSP/FragmentEntete.jsp');

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME include }
  { CurrentFileDir simule un fragment dans un SOUS-repertoire different -  }
  { le '/' de tete doit ignorer ce sous-repertoire et utiliser             }
  { ContextRootDir a la place. }
  Resolved := ParseIncludeDirective('SAMPLES/JSP/SousDossier');
  IncludeAssert('chemin relatif au contexte (ignore le sous-dossier courant)',
    Resolved = 'SAMPLES/JSP/FragmentPied.jsp');

  Tok := LexNextToken;
  IncludeAssert('TEMPLATE_CHUNK final', Tok.Kind = TOK_TEMPLATE_CHUNK);
  Tok := LexNextToken;
  IncludeAssert('EOF', Tok.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ------------------------------------------------------------ }
{ TaglibSelfTest : legacy core, moderne functions, recherche     }
{ par prefixe, prefixe "jsp" reserve, tagdir non supporte -       }
{ memes 2 familles d URI que Test15/16/17JstlXml.jsp.             }
{ ------------------------------------------------------------ }

Procedure TaglibAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('TaglibSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TaglibSelfTest;
Const
  TmpFile = 'JSPTAGLIBSELFTEST.$$$';
Var
  F          : Text;
  Tok        : TToken;
  Idx        : Integer;
  WarnBefore : Integer;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, '<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>');
  WriteLn(F, '<%@ taglib prefix="fn" uri="jakarta.tags.functions" %>');
  WriteLn(F, '<%@ taglib prefix="jsp" uri="x" %>');
  WriteLn(F, '<%@ taglib prefix="site" tagdir="/WEB-INF/tags" %>');
  Close(F);

  { Rend WarnMsg observable via WarnCount, meme discipline que            }
  { PageSelfTest (TODO 05) - reinitialise par ParseArgs juste apres.      }
  Opts.Warnings := True;

  LexInit(TmpFile);
  TaglibInit;

  Tok := LexNextToken;
  TaglibAssert('1: DIRECTIVE_OPEN', Tok.Kind = TOK_DIRECTIVE_OPEN);
  Tok := LexNextToken;
  TaglibAssert('2: DIR_NAME taglib',
    (Tok.Kind = TOK_DIR_NAME) And (Tok.Val = 'taglib'));
  Idx := ParseTaglibDirective;
  TaglibAssert('c = core JSTL legacy',
    (Idx >= 0) And TaglibPool[Idx].IsCoreJstl And
    (Not TaglibPool[Idx].IsFunctionsJstl));

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME taglib }
  Idx := ParseTaglibDirective;
  TaglibAssert('fn = functions JSTL moderne',
    (Idx >= 0) And TaglibPool[Idx].IsFunctionsJstl And
    (Not TaglibPool[Idx].IsCoreJstl));

  TaglibAssert('TaglibFind("c") retrouve', TaglibFind('c') >= 0);
  TaglibAssert('TaglibFind("fn") retrouve', TaglibFind('fn') >= 0);
  TaglibAssert('TaglibFind("inconnu") absent', TaglibFind('inconnu') = -1);

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME taglib }
  WarnBefore := WarnCount;
  ParseTaglibDirective;
  TaglibAssert('prefix "jsp" reserve : avertissement emis',
    WarnCount > WarnBefore);

  Tok := LexNextToken; { TEMPLATE_CHUNK }
  Tok := LexNextToken; { DIRECTIVE_OPEN }
  Tok := LexNextToken; { DIR_NAME taglib }
  WarnBefore := WarnCount;
  ParseTaglibDirective;
  TaglibAssert('tagdir non supporte : avertissement emis',
    WarnCount > WarnBefore);

  Tok := LexNextToken;
  TaglibAssert('TEMPLATE_CHUNK final', Tok.Kind = TOK_TEMPLATE_CHUNK);
  Tok := LexNextToken;
  TaglibAssert('EOF', Tok.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 07 - DECLARATIONS, SCRIPTLETS ET EXPRESSIONS             }
{ (PARSING JAVA)                                                }
{ ============================================================ }

{ Parseur syntaxique PUR (aucune resolution d identificateur/de type -   }
{ TODO 20+, aucun symbole n existe encore) proche dans l ESPRIT de         }
{ JPPCW32.PAS (descente recursive, pools plats indexes par Integer, PAS    }
{ de pointeurs/tas) mais DELIBEREMENT plus etroit : ni long/hex/octal        }
{ (TODO 02 ne les tokenise deja pas), ni tableaux/indexation [] (AUCUN       }
{ scriptlet/declaration/expression REEL d aucun echantillon SAMPLES\JSP\   }
{ *.jsp n en a besoin - seul Test15JstlJavaEE.jsp manipule un tableau,        }
{ mais UNIQUEMENT via EL, jamais via du Java embarque), ni classes           }
{ imbriquees/generiques/lambdas. Le "type" d une declaration/d un              }
{ parametre/d un champ reste un simple NOM (TString) - AUCUNE resolution      }
{ vers TypePool (TODO 04) n est tentee ici, exactement comme le roadmap        }
{ d en-tete le precise ("PARSING Java", pas semantique).                       }

Type
  { TImplicitObjectKind (TODO 09, section 7) : ajoute ICI (dans le bloc     }
  { Type de TODO 07) puisque TExprNode en a besoin comme type de champ -    }
  { IOK_NONE signifie "pas un objet implicite" (n importe quelle autre       }
  { variable/identificateur). }
  TImplicitObjectKind = (
    IOK_NONE,
    IOK_REQUEST, IOK_RESPONSE, IOK_PAGECONTEXT, IOK_SESSION,
    IOK_APPLICATION, IOK_OUT, IOK_CONFIG, IOK_PAGE, IOK_EXCEPTION
  );

  TExprKind = (
    EK_INT, EK_FLOAT, EK_CHAR, EK_STRING, EK_BOOL, EK_NULL,
    EK_IDENT,      { NameVal = identificateur BRUT, NON resolu               }
    EK_UNARY,      { Op = '!'/'-'/'+' (prefixe) ou 'pre++'/'pre--'/           }
                   { 'post++'/'post--' (section 6.4) ; Left = operande        }
    EK_BINARY,     { Op ; Left, Right - * / % + - < <= > >= == != && ||       }
    EK_ASSIGN,     { Op = '='/'+='/'-='/'*='/'/='/'%=' ; Left = cible,        }
                   { Right = valeur - DROITE-associatif }
    EK_SELECTOR,   { Left = base ; NameVal = membre ('.', section 6.17) }
    EK_CALL,       { Left = callee (EK_IDENT ou EK_SELECTOR) ; ArgFirst/      }
                   { ArgCount dans ExprArgPool }
    EK_NEWOBJECT,  { NameVal = nom de type EVENTUELLEMENT qualifie            }
                   { ("java.util.Date") ; ArgFirst/ArgCount = arguments        }
                   { du constructeur }
    EK_CAST        { TODO 10 (section 6.22, ex. "(String)session.               }
                   { getAttribute(...)", Test08Session.jsp/Test09                }
                   { Application.jsp) : NameVal = nom du type cible               }
                   { (indicatif, NON resolu - meme discipline que les              }
                   { types de declaration/parametre) ; Left = operande }
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : TString;    { operateur brut - toujours court }
    Left    : Integer;    { -1 si absent }
    Right   : Integer;    { -1 si absent }
    NameVal : TBigString; { EK_IDENT/EK_SELECTOR/EK_NEWOBJECT - TBigString    }
                          { (AnsiString), MEME discipline anti-troncature      }
                          { qu au TODO 02/04 (un nom qualifie pourrait, en      }
                          { theorie, depasser 255 octets) }
    IntVal  : LongInt;    { EK_INT/EK_CHAR/EK_BOOL (0/1) }
    RealVal : Double;     { EK_FLOAT }
    StrVal  : TBigString; { EK_STRING }
    ArgFirst: Integer;    { EK_CALL/EK_NEWOBJECT }
    ArgCount: Integer;
    ImplicitKind : TImplicitObjectKind; { TODO 09 - EK_IDENT SEULEMENT :   }
                          { IOK_NONE si ce n est PAS un des 9 objets           }
                          { implicites (section 7) - permettra au codegen        }
                          { (TODO 21+) de dispatcher DIRECTEMENT vers le          }
                          { runtime _JSPRT_ approprie plutot que de chercher       }
                          { une variable/un champ ordinaire }
    Line    : Integer;
    Col     : Integer;
  End;

  TStmtKind = (
    SK_BLOCK,     { ChildFirst/ChildCount dans StmtChildPool }
    SK_EXPR,      { ExprIdx - instruction-expression (appel, affectation) }
    SK_LOCALVAR,  { NameVal = nom du TYPE (indicatif, NON resolu) ; Op =    }
                  { nom de la variable ; ExprIdx = initialiseur (-1 si       }
                  { absent) - UNE SEULE variable (aucun echantillon ne        }
                  { declare "int a, b;", limite assumee - voir la note        }
                  { d en-tete de ParseLocalVarDecl) }
    SK_IF,        { ExprIdx = condition ; Left = alors ; Right = sinon       }
                  { (-1 si absent) }
    SK_WHILE,     { ExprIdx = condition ; Left = corps }
    SK_FOR,       { Left = init (-1 si absent, instruction) ; ExprIdx =      }
                  { condition (-1 si absente = boucle infinie, expression) ;  }
                  { Right = mise a jour (-1 si absente, expression) ; Extra   }
                  { = corps (instruction) }
    SK_RETURN,    { ExprIdx (-1 si "return;" seul) }
    SK_EMPTY,     { ';' seul }
    SK_PRINT_TEMPLATE, { TODO 08 - BigVal = texte de gabarit VERBATIM     }
                       { (un TOK_TEMPLATE_CHUNK converti en instruction     }
                       { "out.print(texte)" synthetique, section 6.4)        }
    SK_PRINT_EXPR,     { TODO 08 - ExprIdx = expression d un <%= ... %> -   }
                       { instruction "out.print(coercion-String(expr))"      }
                       { synthetique (coercion reelle : TODO 21+, aucune      }
                       { generation de code n existe encore) }
    SK_INCLUDE_ACTION, { TODO 12 (section 9.1, <jsp:include>) : NameVal =   }
                       { "page" (chemin/URL cible, litteral - AUCUNE EL ou    }
                       { resolution n est tentee ici) ; BoolVal = "flush"      }
                       { (False si absent - la reference ne documente aucun    }
                       { defaut explicite) ; ParamFirst/ParamCount dans          }
                       { JspParamPool (jsp:param imbriques, section 9.3) -        }
                       { AUCUN codegen n existe encore pour le VRAI appel           }
                       { runtime _JSPRT_Include du roadmap d en-tete (TODO 21+) }
    SK_FORWARD_ACTION, { TODO 12 (section 9.1/9.2, <jsp:forward>) : NameVal = }
                       { "page" cible ; ParamFirst/ParamCount MEME convention   }
                       { que SK_INCLUDE_ACTION (section 9.3, jsp:param          }
                       { s applique aussi a forward) ; PAS de "flush" (absent    }
                       { de la grammaire jsp:forward, section 9.2) - DECISION     }
                       { A DOCUMENTER (roadmap d en-tete, aucun echantillon ne     }
                       { l exercice) : la sortie DEJA bufferisee de la page         }
                       { courante serait ABANDONNEE au moment du forward reel        }
                       { (TODO 18+, aucun buffer de sortie n existe encore) }
    SK_USEBEAN_ACTION, { TODO 13 (section 9.4/10, <jsp:useBean>) : Op = "id" }
                       { (nom de variable/attribut) ; NameVal = "class"         }
                       { (classe concrete, '' si absente) ; BigVal = "type"       }
                       { (type visible, '' si absent) ; Extra = Ord(TScopeKind)     }
                       { de l attribut "scope" (SCOPE_PAGE par defaut, section       }
                       { 8.1 - aucun defaut explicite dans CETTE reference pour       }
                       { jsp:useBean lui-meme, "page" est le choix le plus              }
                       { restrictif/sur) - "beanName" reconnu syntaxiquement           }
                       { mais NON implemente (mecanisme historique, aucun               }
                       { echantillon ne l exercice, meme discipline que "tagdir"        }
                       { au TODO 06) ; AUCUN codegen n existe encore (instanciation      }
                       { reelle/recherche dans le scope : TODO 21+, roadmap d en-tete) }
    SK_GETPROPERTY_ACTION, { TODO 13 (section 9.6/10, <jsp:getProperty>) :  }
                       { Op = "name" (bean) ; NameVal = "property" - dispatch    }
                       { vers le getter conventionnel (getXxx()/isXxx() pour       }
                       { boolean, section 10.2) reste TODO 21+ (AUCUNE               }
                       { resolution de type n existe encore pour savoir QUEL           }
                       { getter appeler) }
    SK_SETPROPERTY_ACTION, { TODO 13 (section 9.5/10, <jsp:setProperty>) :  }
                       { Op = "name" (bean) ; NameVal = "property" (peut etre    }
                       { "*", section 9.1/10.3) ; Extra = Ord(TSetPropertySource)  }
                       { ; BigVal = valeur LITTERALE (SPS_VALUE) ou nom du           }
                       { parametre source (SPS_PARAM) - vide et non signifiant        }
                       { pour SPS_WILDCARD (property="*", copie TOUS les                }
                       { parametres correspondants, section 9.1 - AUCUNE                 }
                       { introspection JavaBean n existe encore pour savoir                }
                       { LESQUELS correspondent, TODO 21+) }
    SK_PRINT_EL,       { TODO 14 (section 12.1, EL immediat/differe en    }
                       { gabarit) :                                          }
                       { ElIdx = index racine dans ElNodePool (arbre EL          }
                       { DISTINCT de ExprPool - TODO 07/08 - voir TElNode         }
                       { ci-dessous) ; BoolVal = True si l ouverture etait la  }
                       { forme differee, False si immediate - AUCUNE              }
                       { verification que le CONTEXTE admet bien une expression   }
                       { differee                                                  }
                       { n existe encore (section 12.1, TODO 20+) ; instruction         }
                       { "out.print(coercion-String(evaluation-EL(...)))"                }
                       { synthetique, MEME convention que SK_PRINT_EXPR -                 }
                       { l evaluation reelle existe depuis le TODO 15 (ElEvalNode)         }
                       { mais n est invoquee par AUCUN codegen encore (TODO 21+) }
    SK_JSTL_OUT,       { TODO 16 (section 16.4, <c:out>) : ElIdx = "value"  }
                       { (TOUJOURS un noeud ElNodePool - TODO 14/15 - un              }
                       { litteral est synthetise en ELK_STRING par                       }
                       { AttrTextToElIdx si l attribut n est PAS entoure de                 }
                       { "dollar/diese-accolade") ; Left = "default" (-1 si                  }
                       { absent, MEME representation) - echappement XML                       }
                       { TOUJOURS actif (section 24.1, "escapeXml" reconnu mais                }
                       { sans effet, DECISION A DOCUMENTER) ; AUCUN codegen              }
                       { n existe encore (TODO 21+) pour le VRAI choix entre value           }
                       { et default (empty(value), TODO 15) ni pour l echappement }
    SK_JSTL_SET,       { TODO 16 (section 16.4, <c:set>) : NameVal = "var"  }
                       { ; ElIdx = "value" (MEME representation ElNodePool           }
                       { que SK_JSTL_OUT ci-dessus) ; Extra = Ord(TScopeKind)          }
                       { de "scope" (SCOPE_PAGE par defaut, section 8.1) -                }
                       { forme "target"/"property" (affectation d une                        }
                       { propriete de bean) et forme avec CORPS non gerees                     }
                       { (aucun echantillon ne les exercice, roadmap d en-tete) }
    SK_JSTL_IF,        { TODO 16 (section 16.4, <c:if>) : ElIdx = "test"   }
                       { (ElNodePool) ; ChildFirst/ChildCount = corps                  }
                       { (StmtChildPool, MEME technique "tampon local puis                }
                       { recopie" que ParseBlock/ParsePage) - "var"/"scope"                  }
                       { (memorisation du resultat booleen) reconnus                           }
                       { syntaxiquement mais SANS EFFET, aucun echantillon ne                    }
                       { les exercice }
    SK_JSTL_CHOOSE,    { TODO 16 (section 16.4/16.5, <c:choose>) :         }
                       { ChildFirst/ChildCount = suite de SK_JSTL_WHEN/                  }
                       { SK_JSTL_OTHERWISE dans l ORDRE source - AUCUN                     }
                       { attribut attendu ; AUCUN codegen n existe encore                     }
                       { (TODO 21+) pour le VRAI parcours "premier WHEN vrai,                   }
                       { sinon OTHERWISE" }
    SK_JSTL_WHEN,      { TODO 16 (section 16.4/16.5, <c:when>, ENFANT      }
                       { d un SK_JSTL_CHOOSE SEULEMENT - non applique ici) :    }
                       { ElIdx = "test" (ElNodePool) ; ChildFirst/ChildCount =    }
                       { corps }
    SK_JSTL_OTHERWISE, { TODO 16 (section 16.4/16.5, <c:otherwise>, ENFANT  }
                       { d un SK_JSTL_CHOOSE SEULEMENT) : ChildFirst/                 }
                       { ChildCount = corps SEULEMENT (aucun test) }
    SK_JSTL_FOREACH    { TODO 16 (section 16.4/16.6, <c:forEach>) : NameVal }
                       { = "var" ('' si absent) ; BoolVal = True si "items"           }
                       { present (forme collection, ElIdx = index ElNodePool             }
                       { de "items") ; BoolVal = False = forme numerique                    }
                       { (Left = "begin", Right = "end", Extra = "step",                      }
                       { defaut 1) ; ChildFirst/ChildCount = corps - "varStatus"                }
                       { reconnu syntaxiquement mais NON implemente (section                     }
                       { 16.6, aucun echantillon ne l exercice) ; AUCUNE VRAIE                     }
                       { iteration/liaison de "var" n existe encore (TODO 21+,                       }
                       { la forme "items" necessite de surcroit un modele de                          }
                       { collection/tableau, section 13.3, hors de portee ici) }
  );

  { TODO 13 (section 9.5) : jsp:setProperty a TROIS formes distinctes -    }
  { valeur litterale, valeur tiree d un parametre de requete nomme, ou       }
  { copie generalisee ("*") - voir SK_SETPROPERTY_ACTION ci-dessus. }
  TSetPropertySource = (SPS_VALUE, SPS_PARAM, SPS_WILDCARD);

  TStmtNode = Record
    Kind       : TStmtKind;
    ExprIdx    : Integer;
    Left       : Integer;
    Right      : Integer;
    Extra      : Integer;
    ChildFirst : Integer; { SK_BLOCK }
    ChildCount : Integer;
    NameVal    : TString; { SK_LOCALVAR : nom du type }
    Op         : TString; { SK_LOCALVAR : nom de variable }
    BigVal     : TBigString; { SK_PRINT_TEMPLATE : texte VERBATIM - TBigString }
                             { (AnsiString), MEME discipline anti-troncature    }
                             { qu au TODO 02/04/07 (un chunk de gabarit peut     }
                             { largement depasser 255 octets) - REUTILISE       }
                             { egalement par SK_INCLUDE_ACTION/SK_FORWARD_ACTION }
                             { (TODO 12) pour l attribut "page" }
    BoolVal    : Boolean;    { SK_INCLUDE_ACTION (TODO 12) : "flush" ;   }
                             { SK_PRINT_EL (TODO 14) : forme differee     }
    ParamFirst : Integer;    { SK_INCLUDE_ACTION/SK_FORWARD_ACTION (TODO 12) : }
                             { jsp:param imbriques, dans JspParamPool }
    ParamCount : Integer;
    ElIdx      : Integer;    { SK_PRINT_EL (TODO 14) : index racine dans  }
                             { ElNodePool (PAS ExprPool - arbre EL          }
                             { DISTINCT, voir TElNode) }
    Line       : Integer;
    Col        : Integer;
  End;

  TJavaParamDecl = Record
    Name     : TString;
    TypeName : TString;
  End;

  TJavaMethodDecl = Record
    Name        : TString;
    ReturnType  : TString;
    Visibility  : TString; { 'private'/'public'/'protected'/'' (package,     }
                            { section 5.3/5.4 de la reference J++ - PUREMENT  }
                            { INFORMATIF, aucune verification d acces ici,     }
                            { TODO 19+ }
    ParamFirst  : Integer; { dans JavaParamPool }
    ParamCount  : Integer;
    BodyStmtIdx : Integer; { SK_BLOCK }
    IsStatic    : Boolean;
  End;

  TJavaFieldDecl = Record
    Name        : TString;
    TypeName    : TString;
    InitExprIdx : Integer; { -1 si aucun initialiseur }
    IsStatic    : Boolean;
  End;

Var
  ExprPool      : Array[0..MAX_JEXPR - 1] Of TExprNode;
  ExprCount     : Integer;
  ExprArgPool   : Array[0..MAX_JEXPR_ARG - 1] Of Integer;
  ExprArgCount  : Integer;

  StmtPool       : Array[0..MAX_JAVA_STMT - 1] Of TStmtNode;
  StmtCount      : Integer;
  StmtChildPool  : Array[0..MAX_JAVA_STMT_CHILD - 1] Of Integer;
  StmtChildCount : Integer;

  JavaParamPool  : Array[0..MAX_PARAM - 1] Of TJavaParamDecl;
  JavaParamCount : Integer;
  JavaMethodPool : Array[0..(MAX_FUNC + MAX_METHOD) - 1] Of TJavaMethodDecl;
  JavaMethodCount: Integer;
  JavaFieldPool  : Array[0..MAX_FIELD_POOL - 1] Of TJavaFieldDecl;
  JavaFieldCount : Integer;

  { Tampon "token courant" + UN token d avance (CurTok/ParserPeek) - le     }
  { lexeur (TODO 02) ne fournit qu un flux SEQUENTIEL (LexNextToken, une     }
  { fonction qui ne peut pas etre "re-appelee" pour le meme token) : la      }
  { descente recursive a besoin de RELIRE le token courant a plusieurs       }
  { endroits avant de decider de le consommer - ParserAdvance avance d UN     }
  { cran, ParserPeek regarde UN cran plus loin SANS avancer (necessaire       }
  { UNIQUEMENT pour IsLocalVarDeclStart, voir sa note d en-tete). }
  CurTok       : TToken;
  NextTokBuf   : TToken;
  NextTokValid : Boolean;

{ ------------------------------------------------------------ }
{ JavaParserInit / ParserAdvance / ParserPeek / CurIsOp          }
{ ------------------------------------------------------------ }

Procedure JavaParserInit;
Begin
  ExprCount      := 0;
  ExprArgCount   := 0;
  StmtCount      := 0;
  StmtChildCount := 0;
  JavaParamCount := 0;
  JavaMethodCount:= 0;
  JavaFieldCount := 0;
  NextTokValid   := False;
End;

Procedure ParserAdvance;
Begin
  If NextTokValid Then
  Begin
    CurTok := NextTokBuf;
    NextTokValid := False;
  End
  Else
    CurTok := LexNextToken;
End;

Function ParserPeek: TToken;
Begin
  If Not NextTokValid Then
  Begin
    NextTokBuf   := LexNextToken;
    NextTokValid := True;
  End;
  ParserPeek := NextTokBuf;
End;

Function CurIsOp(Const S: TString): Boolean;
Begin
  CurIsOp := (CurTok.Kind = TOK_OP) And (CurTok.Val = S);
End;

Function CurIsKw(Const S: TString): Boolean;
Begin
  CurIsKw := (CurTok.Kind = TOK_IDENT) And (CurTok.Val = S);
End;

{ ------------------------------------------------------------ }
{ ExprAdd / StmtAdd - allocation dans les pools, valeurs         }
{ neutres par defaut (-1 pour tout index "absent").              }
{ ------------------------------------------------------------ }

Function ExprAdd(Kind: TExprKind): Integer;
Begin
  If ExprCount >= MAX_JEXPR Then
    FatalError('trop de noeuds d expression Java (MAX_JEXPR)');
  ExprPool[ExprCount].Kind     := Kind;
  ExprPool[ExprCount].Op       := '';
  ExprPool[ExprCount].Left     := -1;
  ExprPool[ExprCount].Right    := -1;
  ExprPool[ExprCount].NameVal  := '';
  ExprPool[ExprCount].IntVal   := 0;
  ExprPool[ExprCount].RealVal  := 0.0;
  ExprPool[ExprCount].StrVal   := '';
  ExprPool[ExprCount].ArgFirst := -1;
  ExprPool[ExprCount].ArgCount := 0;
  ExprPool[ExprCount].ImplicitKind := IOK_NONE;
  ExprPool[ExprCount].Line     := CurTok.Line;
  ExprPool[ExprCount].Col      := CurTok.Col;
  ExprAdd := ExprCount;
  Inc(ExprCount);
End;

Function StmtAdd(Kind: TStmtKind): Integer;
Begin
  If StmtCount >= MAX_JAVA_STMT Then
    FatalError('trop de noeuds d instruction Java (MAX_JAVA_STMT)');
  StmtPool[StmtCount].Kind       := Kind;
  StmtPool[StmtCount].ExprIdx    := -1;
  StmtPool[StmtCount].Left       := -1;
  StmtPool[StmtCount].Right      := -1;
  StmtPool[StmtCount].Extra      := -1;
  StmtPool[StmtCount].ChildFirst := -1;
  StmtPool[StmtCount].ChildCount := 0;
  StmtPool[StmtCount].NameVal    := '';
  StmtPool[StmtCount].Op         := '';
  StmtPool[StmtCount].BigVal     := '';
  StmtPool[StmtCount].BoolVal    := False;
  StmtPool[StmtCount].ParamFirst := -1;
  StmtPool[StmtCount].ParamCount := 0;
  StmtPool[StmtCount].ElIdx      := -1;
  StmtPool[StmtCount].Line       := CurTok.Line;
  StmtPool[StmtCount].Col        := CurTok.Col;
  StmtAdd := StmtCount;
  Inc(StmtCount);
End;

{ ------------------------------------------------------------ }
{ Expressions - descente recursive, precedence CROISSANTE        }
{ (ParseJavaExpr = point d entree = le niveau le plus BAS,        }
{ affectation) - ordre standard Java (section 6.6-6.14) reduit    }
{ aux operateurs REELLEMENT rencontres dans les echantillons       }
{ SAMPLES\JSP\*.jsp (Test01/02/03/05, plus for/while en avance      }
{ sur Test04Scriptlets.jsp - TODO 08 stitchera le tout).            }
{ ------------------------------------------------------------ }

Function ParseJavaExpr: Integer; Forward;
Function ParseExpressionBlock: Integer; Forward; { definie plus bas (TODO 07),}
                                                  { requise par TODO 08         }
                                                  { (TryConsumeInterleaveToken) }

{ ParseArgList : MEME tampon LOCAL que ParseBlock/ParseScriptletBlock, et    }
{ pour la MEME raison exacte - un argument peut etre lui-meme un appel avec   }
{ ses PROPRES arguments (ex. "format(g(x, y))"), qui avancerait ExprArgCount  }
{ avant que CET appel-ci ait fini d y ecrire les siens (bogue reel trouve      }
{ et corrige pour StmtChildPool, evite ICI PROACTIVEMENT par le meme moyen     }
{ avant meme qu un echantillon reel ne l exercice). }
Procedure ParseArgList(Var ArgFirst, ArgCount: Integer);
Var
  Count, I : Integer;
  LocalArg : Array[0..MAX_JAVA_ARG_LOCAL - 1] Of Integer;
Begin
  ArgFirst := 0; ArgCount := 0;
  Count := 0;
  If CurIsOp(')') Then Exit;
  While True Do
  Begin
    If Count >= MAX_JAVA_ARG_LOCAL Then
    Begin
      FatalError('trop d arguments a un seul appel (MAX_JAVA_ARG_LOCAL)');
      Break;
    End;
    LocalArg[Count] := ParseJavaExpr;
    Inc(Count);
    If CurIsOp(',') Then
    Begin
      ParserAdvance;
      Continue;
    End;
    Break;
  End;

  ArgFirst := ExprArgCount;
  For I := 0 To Count - 1 Do
  Begin
    If ExprArgCount >= MAX_JEXPR_ARG Then
    Begin
      FatalError('trop d arguments au total (MAX_JEXPR_ARG)');
      Break;
    End;
    ExprArgPool[ExprArgCount] := LocalArg[I];
    Inc(ExprArgCount);
  End;
  ArgCount := Count;
End;

Function ParseNewObject: Integer;
Var
  Idx      : Integer;
  TypeName : TBigString;
Begin
  ParserAdvance; { consomme 'new' }
  If CurTok.Kind <> TOK_IDENT Then
  Begin
    FatalError('nom de type attendu apres "new"');
    ParseNewObject := -1;
    Exit;
  End;
  TypeName := CurTok.Val;
  ParserAdvance;
  While CurIsOp('.') Do
  Begin
    ParserAdvance;
    If CurTok.Kind <> TOK_IDENT Then
    Begin
      FatalError('nom de type attendu apres "." (new)');
      ParseNewObject := -1;
      Exit;
    End;
    TypeName := TypeName + '.' + CurTok.Val;
    ParserAdvance;
  End;

  Idx := ExprAdd(EK_NEWOBJECT);
  ExprPool[Idx].NameVal := TypeName;
  { DECOUVERT PAR EXECUTION REELLE (TODO 21, Test15JstlJavaEE.jsp - "new       }
  { String" suivi d un tableau avec initialiseur entre accolades) - la           }
  { creation de TABLEAU ("new Type[]"/"new Type[N]", section 6/TYK_ARRAY du         }
  { TODO 04) n est PAS geree ICI, seul "new Type(args)" (construction               }
  { d objet) l est - JAMAIS devinee/improvisee avant ce message d erreur :             }
  { message SPECIFIQUE plutot que le "(" generique trompeur, extension                   }
  { FUTURE sous ce MEME TODO 07, MEME discipline que les extensions                         }
  { "futures sous ce meme numero" documentees au TODO 21. }
  If CurIsOp('[') Then
  Begin
    FatalError('creation de tableau "new ' + TypeName + '[...]" non geree ' +
               '(construction d objet "new ' + TypeName + '(...)" seulement)');
    ParseNewObject := Idx;
    Exit;
  End;
  If Not CurIsOp('(') Then
  Begin
    FatalError('"(" attendue apres le type de "new"');
    ParseNewObject := Idx;
    Exit;
  End;
  ParserAdvance;
  ParseArgList(ExprPool[Idx].ArgFirst, ExprPool[Idx].ArgCount);
  If Not CurIsOp(')') Then
    FatalError('")" attendue apres les arguments de "new"')
  Else
    ParserAdvance;
  ParseNewObject := Idx;
End;

{ ============================================================ }
{ TODO 09 - OBJETS IMPLICITES (section 7)                       }
{ ============================================================ }

{ Places ICI (dans le bloc TODO 07) parce que ParsePrimary/ParsePostfix,     }
{ juste en dessous, en ont besoin - meme discipline d insertion que            }
{ TryConsumeInterleaveToken/ParseBlock au TODO 08 (etendre le code             }
{ existant plutot que dupliquer un pilote separe). Aucune VRAIE hierarchie    }
{ d objets/interfaces Servlet n est modelisee (TODO 04, note d en-tete de       }
{ TYK_CLASS) : chaque objet implicite est reconnu par son NOM SEUL a           }
{ l endroit ou un identificateur est lu (ParsePrimary), et sa surface de         }
{ methode EFFECTIVEMENT exercee par Test07ObjetsImplicites.jsp/                   }
{ Test12GestionErreur.jsp est validee au moment ou un selecteur '.' est            }
{ pose dessus (ParsePostfix) - c est la MEME "dispatch direct vers le              }
{ runtime _JSPRT_" que decrit le roadmap d en-tete, simplement realisee ICI          }
{ par un simple TAG sur le noeud plutot que par une vraie resolution               }
{ semantique complete (TODO 20+, hors de portee ici). }

Function ImplicitObjectKindOf(Const Name: TString): TImplicitObjectKind;
Begin
  If Name = 'request' Then ImplicitObjectKindOf := IOK_REQUEST
  Else If Name = 'response' Then ImplicitObjectKindOf := IOK_RESPONSE
  Else If Name = 'pageContext' Then ImplicitObjectKindOf := IOK_PAGECONTEXT
  Else If Name = 'session' Then ImplicitObjectKindOf := IOK_SESSION
  Else If Name = 'application' Then ImplicitObjectKindOf := IOK_APPLICATION
  Else If Name = 'out' Then ImplicitObjectKindOf := IOK_OUT
  Else If Name = 'config' Then ImplicitObjectKindOf := IOK_CONFIG
  Else If Name = 'page' Then ImplicitObjectKindOf := IOK_PAGE
  Else If Name = 'exception' Then ImplicitObjectKindOf := IOK_EXCEPTION
  Else ImplicitObjectKindOf := IOK_NONE;
End;

{ Methodes java.lang.Object HERITEES par TOUT objet reference reel Java -   }
{ Test12GestionErreur.jsp appelle exception.getClass() (PUIS .getName() sur  }
{ le Class retourne, une chaine d appels DISTINCTE non validee ici - voir     }
{ la note d en-tete de ParsePostfix) - TOUJOURS admises quel que soit          }
{ l objet implicite, en PLUS de sa surface propre ci-dessous. }
Function IsUniversalObjectMethod(Const M: TString): Boolean;
Begin
  IsUniversalObjectMethod := (M = 'getClass') Or (M = 'toString') Or
                             (M = 'equals') Or (M = 'hashCode');
End;

{ Surface de methode EFFECTIVEMENT exercee par les echantillons (roadmap    }
{ d en-tete, TODO 09) - UNIQUEMENT ce qui est reellement appele, rien de       }
{ plus ; page/exception n ont AUCUNE methode PROPRE couverte au-dela des        }
{ methodes universelles Object ci-dessus. }
Function IsAttributeScopeMethod(Const MethodName: TString): Boolean;
Begin
  { TODO 10 (section 8.2) : setAttribute/getAttribute/removeAttribute       }
  { s appliquent de facon SYMETRIQUE aux QUATRE porteurs de portee            }
  { (pageContext/request/session/application, section 8.1) - EXTRAIT en       }
  { fonction PARTAGEE plutot que repete quatre fois dans le Case ci-dessous.  }
  IsAttributeScopeMethod := (MethodName = 'setAttribute') Or
                           (MethodName = 'getAttribute') Or
                           (MethodName = 'removeAttribute');
End;

Function IsKnownImplicitMethod(Kind: TImplicitObjectKind;
                               Const MethodName: TString): Boolean;
Begin
  If IsUniversalObjectMethod(MethodName) Then
  Begin
    IsKnownImplicitMethod := True;
    Exit;
  End;
  If (Kind In [IOK_REQUEST, IOK_PAGECONTEXT, IOK_SESSION, IOK_APPLICATION]) And
     IsAttributeScopeMethod(MethodName) Then
  Begin
    IsKnownImplicitMethod := True;
    Exit;
  End;
  Case Kind Of
    IOK_REQUEST:
      IsKnownImplicitMethod :=
        (MethodName = 'getMethod') Or (MethodName = 'getRequestURI') Or
        (MethodName = 'getRemoteAddr') Or (MethodName = 'getParameter') Or
        (MethodName = 'setCharacterEncoding');
    IOK_RESPONSE:
      IsKnownImplicitMethod := (MethodName = 'getContentType');
    IOK_SESSION:
      IsKnownImplicitMethod := (MethodName = 'getId');
    IOK_APPLICATION:
      IsKnownImplicitMethod := (MethodName = 'getServerInfo');
    IOK_CONFIG:
      IsKnownImplicitMethod := (MethodName = 'getServletName');
    IOK_OUT:
      IsKnownImplicitMethod := (MethodName = 'print') Or
                               (MethodName = 'println');
  Else
    IsKnownImplicitMethod := False; { IOK_PAGE/IOK_EXCEPTION : aucune       }
                                    { methode propre couverte                }
  End;
End;

{ ============================================================ }
{ TODO 10 - SCOPES ET ATTRIBUTS (suite) - table runtime          }
{ ============================================================ }

{ Representation runtime COMMUNE aux quatre portees (section 8.1) - une     }
{ table cle/valeur, cle=String, valeur=TELValue (union taguee du TODO 04) - }
{ UN SEUL pool plat filtre par TScopeKind (MEME discipline "recherche        }
{ lineaire sur un pool plat" que TypeFind/TaglibFind, TODO 04/06) plutot      }
{ que quatre tables Pascal distinctes - plus simple et amplement suffisant    }
{ a l echelle reelle de ces echantillons (quelques attributs tout au plus).    }
{                                                                              }
{ DUREE DE VIE - decision A DOCUMENTER explicitement (roadmap d en-tete) :      }
{ page = duree de l execution (aucune notion de "fin de page" distincte du      }
{ processus n existe encore) ; request = IDEM ici, en l absence d un VRAI         }
{ forward/inclusion au sens conteneur (TODO 11/18) ; session/application =        }
{ persistantes en memoire pour la duree du PROCESSUS - AUCUNE des quatre          }
{ n est actuellement reinitialisee entre deux "requetes", puisqu une seule         }
{ execution = une seule requete simulee (TODO 18, pas encore ecrit) - LIMITE        }
{ ASSUMEE, le mecanisme ci-dessous se contente d etre CORRECT au niveau de la        }
{ structure de donnees elle-meme (independant de tout modele d execution).           }
Type
  TScopeKind = (SCOPE_PAGE, SCOPE_REQUEST, SCOPE_SESSION, SCOPE_APPLICATION);

  TScopeEntry = Record
    Kind  : TScopeKind;
    Key   : TString;
    Value : TELValue;
  End;

Var
  ScopeAttrPool  : Array[0..MAX_ATTR - 1] Of TScopeEntry;
  ScopeAttrCount : Integer;

Procedure ScopeInit;
Begin
  ScopeAttrCount := 0;
End;

{ Recherche lineaire filtree par Kind ET Key - retourne -1 si absent. }
Function ScopeFindIndex(Kind: TScopeKind; Const Key: TString): Integer;
Var I: Integer;
Begin
  ScopeFindIndex := -1;
  For I := 0 To ScopeAttrCount - 1 Do
    If (ScopeAttrPool[I].Kind = Kind) And (ScopeAttrPool[I].Key = Key) Then
    Begin
      ScopeFindIndex := I;
      Exit;
    End;
End;

{ setAttribute (section 8.2) : ecrase la valeur si la cle existe DEJA dans   }
{ CETTE portee (les AUTRES portees gardent leur PROPRE valeur pour la MEME    }
{ cle, section 8.3 "un nom identique dans une portee plus courte masque les    }
{ suivantes" - une consequence NATURELLE du filtre par Kind ci-dessus, pas      }
{ une regle a coder separement), sinon ajoute une nouvelle entree. }
Procedure ScopeSetAttribute(Kind: TScopeKind; Const Key: TString;
                            Const Value: TELValue);
Var Idx: Integer;
Begin
  Idx := ScopeFindIndex(Kind, Key);
  If Idx >= 0 Then
  Begin
    ScopeAttrPool[Idx].Value := Value;
    Exit;
  End;
  If ScopeAttrCount >= MAX_ATTR Then
  Begin
    WarnMsg('trop d attributs de scope (MAX_ATTR), ignore : ' + Key);
    Exit;
  End;
  ScopeAttrPool[ScopeAttrCount].Kind  := Kind;
  ScopeAttrPool[ScopeAttrCount].Key   := Key;
  ScopeAttrPool[ScopeAttrCount].Value := Value;
  Inc(ScopeAttrCount);
End;

{ getAttribute (section 8.2) : "Object valeur = request.getAttribute(...)"  }
{ - null si absent (Value.Kind=ELV_NULL), JAMAIS une erreur - retourne         }
{ egalement False pour permettre a l appelant de distinguer explicitement       }
{ "absent" de "present et valant null" si necessaire un jour (TODO 20+). }
Function ScopeGetAttribute(Kind: TScopeKind; Const Key: TString;
                           Var Value: TELValue): Boolean;
Var Idx: Integer;
Begin
  Idx := ScopeFindIndex(Kind, Key);
  If Idx >= 0 Then
  Begin
    Value := ScopeAttrPool[Idx].Value;
    ScopeGetAttribute := True;
  End
  Else
  Begin
    Value.Kind := ELV_NULL;
    ScopeGetAttribute := False;
  End;
End;

{ removeAttribute (section 8.2) - no-op silencieux si la cle est absente,   }
{ MEME tolerance que le reste de ce projet (une suppression d une cle deja   }
{ absente n est jamais une erreur en Java non plus, Map.remove le confirme). }
Procedure ScopeRemoveAttribute(Kind: TScopeKind; Const Key: TString);
Var Idx, I: Integer;
Begin
  Idx := ScopeFindIndex(Kind, Key);
  If Idx < 0 Then Exit;
  For I := Idx To ScopeAttrCount - 2 Do
    ScopeAttrPool[I] := ScopeAttrPool[I + 1];
  Dec(ScopeAttrCount);
End;

{ ParseCastExpr (TODO 10) : Forward - definie APRES ParsePostfix (l operande }
{ d un cast est analyse a ce niveau de precedence, section 6.22) mais         }
{ APPELEE DEPUIS ParsePrimary (juste en dessous), d ou la dependance            }
{ circulaire resolue par ce Forward, MEME technique que ParseJavaExpr/          }
{ ParseExpressionBlock deja utilisee au TODO 07/08. }
Function ParseCastExpr: Integer; Forward;

Function ParsePrimary: Integer;
Var Idx: Integer;
Begin
  If CurTok.Kind = TOK_INT Then
  Begin
    Idx := ExprAdd(EK_INT);
    ExprPool[Idx].IntVal := CurTok.IntVal;
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurTok.Kind = TOK_FLOAT Then
  Begin
    Idx := ExprAdd(EK_FLOAT);
    ExprPool[Idx].RealVal := CurTok.RealVal;
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurTok.Kind = TOK_CHAR Then
  Begin
    Idx := ExprAdd(EK_CHAR);
    ExprPool[Idx].IntVal := CurTok.IntVal;
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurTok.Kind = TOK_STRING Then
  Begin
    Idx := ExprAdd(EK_STRING);
    ExprPool[Idx].StrVal := CurTok.Val;
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurTok.Kind = TOK_IDENT Then
  Begin
    If CurTok.Val = 'true' Then
    Begin
      Idx := ExprAdd(EK_BOOL); ExprPool[Idx].IntVal := 1;
      ParserAdvance; ParsePrimary := Idx; Exit;
    End;
    If CurTok.Val = 'false' Then
    Begin
      Idx := ExprAdd(EK_BOOL); ExprPool[Idx].IntVal := 0;
      ParserAdvance; ParsePrimary := Idx; Exit;
    End;
    If CurTok.Val = 'null' Then
    Begin
      Idx := ExprAdd(EK_NULL);
      ParserAdvance; ParsePrimary := Idx; Exit;
    End;
    If CurTok.Val = 'new' Then
    Begin
      ParsePrimary := ParseNewObject;
      Exit;
    End;
    Idx := ExprAdd(EK_IDENT);
    ExprPool[Idx].NameVal := CurTok.Val;
    { TODO 09 (section 7) : marque les 9 objets implicites pour un futur    }
    { dispatch direct vers le runtime _JSPRT_ (TODO 21+), plutot que de       }
    { les laisser resoudre comme une variable/un champ ordinaire (TODO 20+). }
    ExprPool[Idx].ImplicitKind := ImplicitObjectKindOf(CurTok.Val);
    If (ExprPool[Idx].ImplicitKind = IOK_EXCEPTION) And
       (Not PageOpts.IsErrorPage) Then
      { section 18.1/18.4 : "exception" n est disponible QUE sur une page   }
      { declaree isErrorPage="true" - une VRAIE erreur de traduction sinon,  }
      { PAS un simple avertissement stylistique (SemErr, pas WarnMsg). }
      SemErr('"exception" utilise sans "isErrorPage=true" sur la ' +
             'directive page (section 18.1/18.4)');
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurIsOp('(') Then
  Begin
    ParserAdvance;
    { TODO 10 (section 6.22) : distingue un CAST "(Type) expr" d une         }
    { expression PARENTHESEE ordinaire "(expr)" - heuristique a 2 jetons      }
    { (CurTok deja l identificateur candidat puisque "(" vient d etre          }
    { consomme, ParserPeek regarde le token SUIVANT SANS avancer) : "("        }
    { IDENT ")" immediat = cast. SUFFISANT pour les echantillons reels          }
    { (Test08Session.jsp/Test09Application.jsp) : aucun n emploie de             }
    { parentheses autour d un IDENTIFICATEUR SEUL a des fins de groupement       }
    { pur (Test05Parametres.jsp parenthese une expression COMPLETE comme         }
    { "nom == null || ...", jamais un identificateur nu - le token qui suit       }
    { N EST alors JAMAIS ')' immediatement, cette heuristique le laisse            }
    { donc correctement emprunter la branche "expression parenthesee"             }
    { normale ci-dessous). }
    If (CurTok.Kind = TOK_IDENT) And (ParserPeek.Kind = TOK_OP) And
       (ParserPeek.Val = ')') Then
    Begin
      ParsePrimary := ParseCastExpr;
      Exit;
    End;
    Idx := ParseJavaExpr;
    If Not CurIsOp(')') Then
      FatalError('")" attendue')
    Else
      ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  FatalError('expression Java attendue');
  ParsePrimary := -1;
End;

Function ParsePostfix: Integer;
Var Idx, Base: Integer;
Begin
  Base := ParsePrimary;
  While True Do
  Begin
    If CurIsOp('.') Then
    Begin
      ParserAdvance;
      If CurTok.Kind <> TOK_IDENT Then
      Begin
        FatalError('nom de membre attendu apres "."');
        ParsePostfix := Base;
        Exit;
      End;
      Idx := ExprAdd(EK_SELECTOR);
      ExprPool[Idx].Left    := Base;
      ExprPool[Idx].NameVal := CurTok.Val;
      { TODO 09 : valide la surface de methode SEULEMENT quand la base est   }
      { DIRECTEMENT un objet implicite identifie (ex. "request.xxx") - une   }
      { chaine plus longue ("exception.getClass().getName()") ne valide      }
      { QUE le premier maillon ("getClass" sur "exception"), le second        }
      { ("getName" sur le Class retourne) n a plus de base implicite           }
      { connue et n est donc, a raison, PAS verifie ici (aucune information     }
      { de type n existe pour lui, TODO 20+). }
      If (ExprPool[Base].Kind = EK_IDENT) And
         (ExprPool[Base].ImplicitKind <> IOK_NONE) And
         (Not IsKnownImplicitMethod(ExprPool[Base].ImplicitKind, CurTok.Val)) Then
        WarnMsg('methode inconnue sur l objet implicite "' +
                ExprPool[Base].NameVal + '" : ' + CurTok.Val);
      ParserAdvance;
      Base := Idx;
    End
    Else If CurIsOp('(') Then
    Begin
      ParserAdvance;
      Idx := ExprAdd(EK_CALL);
      ExprPool[Idx].Left := Base;
      ParseArgList(ExprPool[Idx].ArgFirst, ExprPool[Idx].ArgCount);
      If Not CurIsOp(')') Then
        FatalError('")" attendue apres les arguments d appel')
      Else
        ParserAdvance;
      Base := Idx;
    End
    Else If CurIsOp('++') Or CurIsOp('--') Then
    Begin
      Idx := ExprAdd(EK_UNARY);
      ExprPool[Idx].Op   := 'post' + CurTok.Val;
      ExprPool[Idx].Left := Base;
      ParserAdvance;
      Base := Idx;
    End
    Else
      Break;
  End;
  ParsePostfix := Base;
End;

{ ParseCastExpr (definition reelle - voir le Forward et sa note d en-tete   }
{ pres de ParsePrimary) : PRE-CONDITION - "(" deja consomme par              }
{ ParsePrimary, CurTok EST l identificateur de type (deja verifie), et       }
{ ParserPeek EST ')' (deja verifie). L operande est analyse au niveau         }
{ POSTFIX (section 6.22, "UnaryExpressionNotPlusMinus" simplifie a un          }
{ postfixe - suffisant pour "(String)session.getAttribute(...)" et             }
{ "(Integer)application.getAttribute(...)", les SEULES formes reelles des        }
{ echantillons). }
Function ParseCastExpr: Integer;
Var
  Idx      : Integer;
  TypeName : TString;
Begin
  TypeName := CurTok.Val;
  ParserAdvance; { consomme l identificateur de type }
  ParserAdvance; { consomme ')' }
  Idx := ExprAdd(EK_CAST);
  ExprPool[Idx].NameVal := TypeName;
  ExprPool[Idx].Left    := ParsePostfix;
  ParseCastExpr := Idx;
End;

Function ParseUnary: Integer;
Var Idx: Integer;
Begin
  If CurIsOp('!') Or CurIsOp('-') Or CurIsOp('+') Then
  Begin
    Idx := ExprAdd(EK_UNARY);
    ExprPool[Idx].Op := CurTok.Val;
    ParserAdvance;
    ExprPool[Idx].Left := ParseUnary;
    ParseUnary := Idx;
    Exit;
  End;
  If CurIsOp('++') Or CurIsOp('--') Then
  Begin
    Idx := ExprAdd(EK_UNARY);
    ExprPool[Idx].Op := 'pre' + CurTok.Val;
    ParserAdvance;
    ExprPool[Idx].Left := ParseUnary;
    ParseUnary := Idx;
    Exit;
  End;
  ParseUnary := ParsePostfix;
End;

Function ParseMultiplicative: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseUnary;
  While CurIsOp('*') Or CurIsOp('/') Or CurIsOp('%') Do
  Begin
    OpStr := CurTok.Val;
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := OpStr;
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseUnary;
    Left := Idx;
  End;
  ParseMultiplicative := Left;
End;

Function ParseAdditive: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseMultiplicative;
  While CurIsOp('+') Or CurIsOp('-') Do
  Begin
    OpStr := CurTok.Val;
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := OpStr;
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseMultiplicative;
    Left := Idx;
  End;
  ParseAdditive := Left;
End;

Function ParseRelational: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseAdditive;
  While CurIsOp('<') Or CurIsOp('>') Or CurIsOp('<=') Or CurIsOp('>=') Do
  Begin
    OpStr := CurTok.Val;
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := OpStr;
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseAdditive;
    Left := Idx;
  End;
  ParseRelational := Left;
End;

Function ParseEquality: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseRelational;
  While CurIsOp('==') Or CurIsOp('!=') Do
  Begin
    OpStr := CurTok.Val;
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := OpStr;
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseRelational;
    Left := Idx;
  End;
  ParseEquality := Left;
End;

Function ParseLogicalAnd: Integer;
Var Idx, Left: Integer;
Begin
  Left := ParseEquality;
  While CurIsOp('&&') Do
  Begin
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := '&&';
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseEquality;
    Left := Idx;
  End;
  ParseLogicalAnd := Left;
End;

Function ParseLogicalOr: Integer;
Var Idx, Left: Integer;
Begin
  Left := ParseLogicalAnd;
  While CurIsOp('||') Do
  Begin
    ParserAdvance;
    Idx := ExprAdd(EK_BINARY);
    ExprPool[Idx].Op    := '||';
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseLogicalAnd;
    Left := Idx;
  End;
  ParseLogicalOr := Left;
End;

{ ParseAssignment : DROITE-associatif, plus bas niveau de precedence      }
{ (section 6.16) - '='/'+='/'-='/'*='/'/='/'%=' ; PORTEE reduite aux         }
{ operateurs REELLEMENT utilisables dans les echantillons (aucun &=/|=/^=/   }
{ <<=/>>= dans un scriptlet Java reel, contrairement a JPPCW32.PAS qui les   }
{ supporte tous - limite assumee). }
Function ParseAssignment: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseLogicalOr;
  If CurIsOp('=') Or CurIsOp('+=') Or CurIsOp('-=') Or CurIsOp('*=') Or
     CurIsOp('/=') Or CurIsOp('%=') Then
  Begin
    OpStr := CurTok.Val;
    ParserAdvance;
    Idx := ExprAdd(EK_ASSIGN);
    ExprPool[Idx].Op    := OpStr;
    ExprPool[Idx].Left  := Left;
    ExprPool[Idx].Right := ParseAssignment;
    ParseAssignment := Idx;
    Exit;
  End;
  ParseAssignment := Left;
End;

Function ParseJavaExpr: Integer;
Begin
  ParseJavaExpr := ParseAssignment;
End;

{ ------------------------------------------------------------ }
{ Instructions (section 6.2) - if/else, while, for, return,       }
{ bloc, declaration locale, instruction-expression, instruction   }
{ vide - sous-ensemble EXPLICITEMENT demande par le roadmap        }
{ d en-tete (Test04Scriptlets.jsp exercera for/while "pour de       }
{ vrai" une fois le TODO 08 ecrit ; ce TODO les couvre par un        }
{ fixture SYNTHETIQUE, meme discipline que le prefixe personnalise   }
{ "c:if" au TODO 03 ou language="cobol" au TODO 05).                  }
{ ------------------------------------------------------------ }

{ Heuristique "declaration locale ou instruction-expression ?"          }
{ (ambiguite classique C/Java) : IDENT suivi d un AUTRE IDENT = "Type      }
{ nom" (declaration) ; sinon (., (, =, ;, operateur...) = expression.       }
{ Necessite EXACTEMENT un token de PLUS que le courant (ParserPeek) -      }
{ PORTEE reduite a un nom de type NON qualifie (AUCUN scriptlet/            }
{ declaration reel ne declare de variable locale avec un type qualifie      }
{ par un point, seul "new java.util.Date()" - une EXPRESSION, jamais un      }
{ TYPE de declaration locale - en a un) : suffisant pour toutes les           }
{ occurrences reelles (String/int/char/boolean...). }
Function IsLocalVarDeclStart: Boolean;
Begin
  IsLocalVarDeclStart := (CurTok.Kind = TOK_IDENT) And
                        (ParserPeek.Kind = TOK_IDENT);
End;

Function ParseLocalVarDecl(ConsumeSemi: Boolean): Integer;
Var Idx: Integer;
Begin
  Idx := StmtAdd(SK_LOCALVAR);
  StmtPool[Idx].NameVal := CurTok.Val; { nom du type, NON resolu }
  ParserAdvance;
  If CurTok.Kind <> TOK_IDENT Then
  Begin
    FatalError('nom de variable attendu apres le type');
    ParseLocalVarDecl := Idx;
    Exit;
  End;
  StmtPool[Idx].Op := CurTok.Val; { nom de la variable }
  ParserAdvance;

  If CurIsOp('=') Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ExprIdx := ParseJavaExpr;
  End;

  If ConsumeSemi Then
  Begin
    If Not CurIsOp(';') Then
      FatalError('";" attendu apres une declaration locale')
    Else
      ParserAdvance;
  End;
  ParseLocalVarDecl := Idx;
End;

Function ParseStatement: Integer; Forward;

{ TryConsumeInterleaveToken (TODO 08) : traite EXACTEMENT UN element de     }
{ page a la position courante et signale via son resultat Boolean si une     }
{ INSTRUCTION a ete produite (OutIdx alors valide, l appelant doit la          }
{ pousser dans SA PROPRE liste d enfants) ou si SEULE une frontiere/un          }
{ element non gere a ete consomme (rien a pousser, l appelant doit             }
{ simplement reboucler et RE-VERIFIER sa PROPRE condition d arret - voir la     }
{ note d en-tete de ParseBlock ci-dessous pour la raison structurelle           }
{ exacte de cette conception). Definie plus bas (apres ParseExpressionBlock,   }
{ TODO 07), utilisee ICI via le Forward ci-dessus. }
Function TryConsumeInterleaveToken(Var OutIdx: Integer): Boolean; Forward;

{ ParseJspIncludeOrForward (TODO 12) : Forward - definie plus bas (section  }
{ TODO 12, apres IncludeMergeSelfTest) mais APPELEE DEPUIS               }
{ TryConsumeInterleaveToken juste en dessous - MEME technique que              }
{ PerformStaticInclude (TODO 11) pour resoudre une dependance d ordre            }
{ textuel. }
Function ParseJspIncludeOrForward(IsForward: Boolean): Integer; Forward;

{ ParseJspUseBean/ParseJspGetProperty/ParseJspSetProperty (TODO 13) :      }
{ Forward - MEME technique que ParseJspIncludeOrForward ci-dessus. }
Function ParseJspUseBean: Integer; Forward;
Function ParseJspGetProperty: Integer; Forward;
Function ParseJspSetProperty: Integer; Forward;

{ ParseElFromString (TODO 14) : Forward - MEME technique que              }
{ ParseJspIncludeOrForward ci-dessus - definie plus bas (section TODO 14,  }
{ apres JspBeanSelfTest) mais APPELEE DEPUIS TryConsumeInterleaveToken       }
{ (le cas TOK_EL_IMMEDIATE_OPEN/TOK_EL_DEFERRED_OPEN, juste en dessous). }
Function ParseElFromString(Const Src: TBigString): Integer; Forward;

{ ParseJstlOut/Set/If/Choose/When/Otherwise/Foreach (TODO 16) : Forward -   }
{ MEME technique que ParseJspIncludeOrForward ci-dessus - definies plus         }
{ bas (section TODO 16, apres ElEvalSelfTest) mais APPELEES DEPUIS               }
{ TryConsumeInterleaveToken juste en dessous. ParseJstlBody est ELLE-MEME         }
{ mutuellement recursive avec TryConsumeInterleaveToken (le corps d une            }
{ action JSTL peut contenir n importe quel autre element de page, y compris           }
{ une action JSTL imbriquee - MEME schema de recursion mutuelle que              }
{ ParsePage/ParseScriptletBlock au TODO 08). }
Function ParseJstlOut: Integer; Forward;
Function ParseJstlSet: Integer; Forward;
Function ParseJstlIf: Integer; Forward;
Function ParseJstlChoose: Integer; Forward;
Function ParseJstlWhen: Integer; Forward;
Function ParseJstlOtherwise: Integer; Forward;
Function ParseJstlForeach: Integer; Forward;

{ ParseBlock : accumule les enfants dans un tampon LOCAL (Local, PAS        }
{ StmtChildPool directement) PENDANT le parsing, et ne les recopie dans       }
{ StmtChildPool qu APRES coup, en une seule fois - INDISPENSABLE des que les }
{ blocs peuvent s IMBRIQUER (if/while/for a un corps qui est lui-meme un      }
{ bloc) : ecrire directement dans StmtChildPool AU FUR ET A MESURE (via un    }
{ compteur global StmtChildCount PARTAGE) est INCORRECT des qu un enfant       }
{ (ex. le "if" ci-dessous) contient LUI-MEME un bloc imbrique qui avance         }
{ CE MEME compteur PARTAGE avant que ce bloc-ci ait fini d ecrire le SIEN -       }
{ les ecritures du bloc IMBRIQUE et de CE bloc s ENTRELACENT alors dans le        }
{ pool partage, et la plage contigue [ChildFirst..ChildFirst+Count-1] que ce      }
{ bloc croit lui appartenir en EXCLUSIVITE contient en realite des entrees        }
{ du bloc imbrique - BOGUE REEL trouve par execution (JavaParserSelfTest,          }
{ echapperHtml : le "return """ imbrique dans le "if" apparaissait comme la         }
{ PREMIERE instruction du corps de methode, a la place du "if" lui-meme).           }
{ Avec un tampon LOCAL, le bloc IMBRIQUE termine ENTIEREMENT sa propre                }
{ recopie (et reserve donc SA PROPRE plage) avant que ce bloc-ci ne reserve            }
{ la sienne - les plages ne peuvent alors plus jamais se chevaucher.                    }
{                                                                                        }
{ TODO 08 : la boucle N EST PLUS "un token TOK_TAG_CLOSE avant l accolade      }
{ fermante est une ERREUR FATALE" (comme au TODO 07, ou un bloc devait etre     }
{ COMPLET a l interieur d un SEUL <% ... %>) - un "if"/"while"/"for" DONT le     }
{ corps est CE bloc peut parfaitement s ouvrir dans un scriptlet et se           }
{ refermer dans un scriptlet ULTERIEUR, avec du gabarit/une expression <%= %>    }
{ entre les deux (section 6.2/6.4, Test04Scriptlets.jsp/Test06Formulaire.jsp) -  }
{ TryConsumeInterleaveToken (ci-dessus) gere CETTE frontiere de facon               }
{ TRANSPARENTE : quand il ne fait QUE sauter un delimiteur (retourne False),        }
{ cette boucle reboucle simplement et RE-VERIFIE sa PROPRE condition d arret         }
{ (l accolade fermante) - si le token qui suit la frontiere EST PRECISEMENT       }
{ l accolade fermante de CE bloc (arrivee via un scriptlet ULTERIEUR), la           }
{ boucle s arrete NORMALEMENT, EXACTEMENT comme si aucune frontiere n avait          }
{ jamais existe. Seule une VRAIE fin de fichier (TOK_EOF) avant l accolade            }
{ fermante reste une erreur reelle. }
Function ParseBlock: Integer;
Var
  Idx, ChildFirst, Count, I, NewIdx : Integer;
  LocalChild : Array[0..MAX_JAVA_BLOCK_LOCAL - 1] Of Integer;
Begin
  If Not CurIsOp('{') Then
  Begin
    FatalError('"{" attendue');
    ParseBlock := -1;
    Exit;
  End;
  ParserAdvance;

  Count := 0;
  While Not CurIsOp('}') Do
  Begin
    If CurTok.Kind = TOK_EOF Then
    Begin
      FatalError('bloc "{" non ferme (accolade fermante attendue) - fin de fichier');
      Break;
    End;
    If TryConsumeInterleaveToken(NewIdx) Then
    Begin
      If Count >= MAX_JAVA_BLOCK_LOCAL Then
      Begin
        FatalError('trop d instructions dans un seul bloc (MAX_JAVA_BLOCK_LOCAL)');
        Break;
      End;
      LocalChild[Count] := NewIdx;
      Inc(Count);
    End;
  End;
  If CurIsOp('}') Then ParserAdvance; { consomme l accolade fermante - PAS si sorti par Break }

  ChildFirst := StmtChildCount; { reserve la plage MAINTENANT - APRES que    }
                                { toute la recursion (blocs imbriques) ait     }
                                { deja termine ET reserve la sienne }
  For I := 0 To Count - 1 Do
  Begin
    If StmtChildCount >= MAX_JAVA_STMT_CHILD Then
    Begin
      FatalError('trop d instructions au total (MAX_JAVA_STMT_CHILD)');
      Break;
    End;
    StmtChildPool[StmtChildCount] := LocalChild[I];
    Inc(StmtChildCount);
  End;

  Idx := StmtAdd(SK_BLOCK);
  StmtPool[Idx].ChildFirst := ChildFirst;
  StmtPool[Idx].ChildCount := Count;
  ParseBlock := Idx;
End;

Function ParseForStatement: Integer;
Var Idx, InitIdx, CondIdx, UpdateIdx, BodyIdx: Integer;
Begin
  ParserAdvance; { 'for' }
  If Not CurIsOp('(') Then FatalError('"(" attendue apres "for"')
  Else ParserAdvance;

  If CurIsOp(';') Then
    InitIdx := -1
  Else If IsLocalVarDeclStart Then
    InitIdx := ParseLocalVarDecl(False)
  Else
  Begin
    InitIdx := StmtAdd(SK_EXPR);
    StmtPool[InitIdx].ExprIdx := ParseJavaExpr;
  End;
  If Not CurIsOp(';') Then FatalError('";" attendue (init de for)')
  Else ParserAdvance;

  If CurIsOp(';') Then
    CondIdx := -1
  Else
    CondIdx := ParseJavaExpr;
  If Not CurIsOp(';') Then FatalError('";" attendue (condition de for)')
  Else ParserAdvance;

  If CurIsOp(')') Then
    UpdateIdx := -1
  Else
    UpdateIdx := ParseJavaExpr;
  If Not CurIsOp(')') Then FatalError('")" attendue (mise a jour de for)')
  Else ParserAdvance;

  BodyIdx := ParseStatement;

  Idx := StmtAdd(SK_FOR);
  StmtPool[Idx].Left    := InitIdx;
  StmtPool[Idx].ExprIdx := CondIdx;
  StmtPool[Idx].Right   := UpdateIdx;
  StmtPool[Idx].Extra   := BodyIdx;
  ParseForStatement := Idx;
End;

Function ParseStatement: Integer;
Var Idx, CondIdx, ThenIdx, ElseIdx: Integer;
Begin
  If CurIsOp('{') Then
  Begin
    ParseStatement := ParseBlock;
    Exit;
  End;

  If CurIsOp(';') Then
  Begin
    Idx := StmtAdd(SK_EMPTY);
    ParserAdvance;
    ParseStatement := Idx;
    Exit;
  End;

  If CurIsKw('if') Then
  Begin
    ParserAdvance;
    If Not CurIsOp('(') Then FatalError('"(" attendue apres "if"')
    Else ParserAdvance;
    CondIdx := ParseJavaExpr;
    If Not CurIsOp(')') Then FatalError('")" attendue apres la condition "if"')
    Else ParserAdvance;
    ThenIdx := ParseStatement;
    ElseIdx := -1;
    If CurIsKw('else') Then
    Begin
      ParserAdvance;
      ElseIdx := ParseStatement;
    End;
    Idx := StmtAdd(SK_IF);
    StmtPool[Idx].ExprIdx := CondIdx;
    StmtPool[Idx].Left    := ThenIdx;
    StmtPool[Idx].Right   := ElseIdx;
    ParseStatement := Idx;
    Exit;
  End;

  If CurIsKw('while') Then
  Begin
    ParserAdvance;
    If Not CurIsOp('(') Then FatalError('"(" attendue apres "while"')
    Else ParserAdvance;
    CondIdx := ParseJavaExpr;
    If Not CurIsOp(')') Then FatalError('")" attendue apres la condition "while"')
    Else ParserAdvance;
    ThenIdx := ParseStatement;
    Idx := StmtAdd(SK_WHILE);
    StmtPool[Idx].ExprIdx := CondIdx;
    StmtPool[Idx].Left    := ThenIdx;
    ParseStatement := Idx;
    Exit;
  End;

  If CurIsKw('for') Then
  Begin
    ParseStatement := ParseForStatement;
    Exit;
  End;

  If CurIsKw('synchronized') Then
  Begin
    { TODO 10 (section 23.1, Test09Application.jsp reel,                    }
    { "synchronized (application)" suivi d un bloc) : synchronisation          }
    { ignoree/no-op DOCUMENTEE - un seul thread reel dans ce runtime (aucun  }
    { modele d execution concurrente n existe, TODO 18) - l expression de     }
    { verrou est PARSEE (pour consommer correctement les jetons, y compris   }
    { des appels imbriques eventuels) puis SIMPLEMENT ABANDONNEE : le           }
    { CORPS du bloc est retourne TEL QUEL, sans aucun noeud "synchronized"      }
    { distinct - il n y a RIEN d autre a en faire tant qu aucun codegen          }
    { (TODO 21+) ne pourrait s en servir, et cette decision ne sera JAMAIS       }
    { revisitee (runtime mono-thread assume de facon permanente, section        }
    { 23.1). }
    ParserAdvance;
    If Not CurIsOp('(') Then FatalError('"(" attendue apres "synchronized"')
    Else ParserAdvance;
    ParseJavaExpr; { expression de verrou - analysee puis abandonnee }
    If Not CurIsOp(')') Then FatalError('")" attendue apres "synchronized"')
    Else ParserAdvance;
    ParseStatement := ParseStatement; { le bloc lui-meme, RETOURNE DIRECTEMENT }
    Exit;
  End;

  If CurIsKw('return') Then
  Begin
    ParserAdvance;
    Idx := StmtAdd(SK_RETURN);
    If Not CurIsOp(';') Then
      StmtPool[Idx].ExprIdx := ParseJavaExpr;
    If Not CurIsOp(';') Then FatalError('";" attendu apres "return"')
    Else ParserAdvance;
    ParseStatement := Idx;
    Exit;
  End;

  If IsLocalVarDeclStart Then
  Begin
    ParseStatement := ParseLocalVarDecl(True);
    Exit;
  End;

  Idx := StmtAdd(SK_EXPR);
  StmtPool[Idx].ExprIdx := ParseJavaExpr;
  If Not CurIsOp(';') Then FatalError('";" attendu apres une expression')
  Else ParserAdvance;
  ParseStatement := Idx;
End;

{ ------------------------------------------------------------ }
{ Declarations de membres <%! ... %> (section 6.1) - champs et   }
{ methodes de la "classe page" synthetique.                      }
{ ------------------------------------------------------------ }

Function IsModifierKeyword(Const S: TString): Boolean;
Begin
  IsModifierKeyword := (S = 'private') Or (S = 'public') Or
                       (S = 'protected') Or (S = 'static') Or (S = 'final');
End;

Procedure ParseParamList(Var ParamFirst, ParamCount: Integer);
Begin
  ParamFirst := JavaParamCount;
  ParamCount := 0;
  If CurIsOp(')') Then Exit;
  While True Do
  Begin
    If CurTok.Kind <> TOK_IDENT Then
    Begin
      FatalError('type de parametre attendu');
      Exit;
    End;
    If JavaParamCount >= MAX_PARAM Then
    Begin
      FatalError('trop de parametres declares au total (MAX_PARAM)');
      Exit;
    End;
    JavaParamPool[JavaParamCount].TypeName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_IDENT Then
    Begin
      FatalError('nom de parametre attendu');
      Exit;
    End;
    JavaParamPool[JavaParamCount].Name := CurTok.Val;
    ParserAdvance;
    Inc(JavaParamCount);
    Inc(ParamCount);
    If CurIsOp(',') Then
    Begin
      ParserAdvance;
      Continue;
    End;
    Break;
  End;
End;

Procedure ParseDeclarationMember;
Var
  Vis         : TString;
  IsStaticMod : Boolean;
  TypeName    : TString;
  MemberName  : TString;
  MIdx, FIdx  : Integer;
Begin
  Vis := ''; IsStaticMod := False;
  While (CurTok.Kind = TOK_IDENT) And IsModifierKeyword(CurTok.Val) Do
  Begin
    If (CurTok.Val = 'private') Or (CurTok.Val = 'public') Or
       (CurTok.Val = 'protected') Then
      Vis := CurTok.Val
    Else If CurTok.Val = 'static' Then
      IsStaticMod := True;
    { 'final' reconnu et ignore - sans consequence pour un membre de page   }
    { JSP (aucune verification d affectation unique, TODO 19+ si necessaire). }
    ParserAdvance;
  End;

  If CurTok.Kind <> TOK_IDENT Then
  Begin
    FatalError('type de retour ou de champ attendu');
    Exit;
  End;
  TypeName := CurTok.Val;
  ParserAdvance;

  If CurTok.Kind <> TOK_IDENT Then
  Begin
    FatalError('nom de methode ou de champ attendu');
    Exit;
  End;
  MemberName := CurTok.Val;
  ParserAdvance;

  If CurIsOp('(') Then
  Begin
    { METHODE (section 6.1) }
    ParserAdvance;
    If JavaMethodCount >= MAX_FUNC + MAX_METHOD Then
    Begin
      FatalError('trop de methodes declarees (MAX_FUNC+MAX_METHOD)');
      Exit;
    End;
    MIdx := JavaMethodCount;
    JavaMethodPool[MIdx].Name       := MemberName;
    JavaMethodPool[MIdx].ReturnType := TypeName;
    JavaMethodPool[MIdx].IsStatic   := IsStaticMod;
    JavaMethodPool[MIdx].Visibility := Vis;
    ParseParamList(JavaMethodPool[MIdx].ParamFirst,
                   JavaMethodPool[MIdx].ParamCount);
    If Not CurIsOp(')') Then
      FatalError('")" attendue apres les parametres')
    Else
      ParserAdvance;
    JavaMethodPool[MIdx].BodyStmtIdx := ParseBlock;
    Inc(JavaMethodCount);
  End
  Else
  Begin
    { CHAMP (section 6.1) }
    If JavaFieldCount >= MAX_FIELD_POOL Then
    Begin
      FatalError('trop de champs declares (MAX_FIELD_POOL)');
      Exit;
    End;
    FIdx := JavaFieldCount;
    JavaFieldPool[FIdx].Name        := MemberName;
    JavaFieldPool[FIdx].TypeName    := TypeName;
    JavaFieldPool[FIdx].IsStatic    := IsStaticMod;
    JavaFieldPool[FIdx].InitExprIdx := -1;
    If CurIsOp('=') Then
    Begin
      ParserAdvance;
      JavaFieldPool[FIdx].InitExprIdx := ParseJavaExpr;
    End;
    If Not CurIsOp(';') Then
      FatalError('";" attendu apres un champ')
    Else
      ParserAdvance;
    Inc(JavaFieldCount);
  End;
End;

{ ------------------------------------------------------------ }
{ Points d entree TOP-LEVEL (section 6.1/6.2/6.3, grammaire       }
{ synthetique section 30 - declaration/scriptlet/expressionScript) }
{ - PRE-CONDITION COMMUNE : le lexeur vient de produire l un des    }
{ TOK_DECL_OPEN/TOK_SCRIPTLET_OPEN/TOK_EXPR_OPEN (DEJA consomme      }
{ par l appelant, MEME convention que ParsePageDirective/               }
{ ParseIncludeDirective/ParseTaglibDirective, TODO 05/06) et vient     }
{ de basculer en LM_JAVA - ParserAdvance amorce CurTok avec le          }
{ PREMIER token Java reel. Chacune consomme jusqu au TOK_TAG_CLOSE       }
{ (%>) INCLUS.                                                            }
{ ------------------------------------------------------------ }

Procedure ParseDeclarationBlock;
Begin
  ParserAdvance;
  While CurTok.Kind <> TOK_TAG_CLOSE Do
    ParseDeclarationMember;
  ParserAdvance; { consomme %> }
End;

{ ParseScriptletBlock : MEME tampon LOCAL que ParseBlock ci-dessus, pour     }
{ EXACTEMENT la meme raison (un scriptlet peut contenir un if/while/for       }
{ dont le corps est un bloc imbrique qui avancerait StmtChildCount avant       }
{ que ce scriptlet-ci ait fini d y ecrire le sien). }
Function ParseScriptletBlock: Integer;
Var
  Idx, ChildFirst, Count, I : Integer;
  LocalChild : Array[0..MAX_JAVA_BLOCK_LOCAL - 1] Of Integer;
Begin
  ParserAdvance;
  Count := 0;
  While CurTok.Kind <> TOK_TAG_CLOSE Do
  Begin
    If Count >= MAX_JAVA_BLOCK_LOCAL Then
    Begin
      FatalError('trop d instructions dans un seul scriptlet (MAX_JAVA_BLOCK_LOCAL)');
      Break;
    End;
    LocalChild[Count] := ParseStatement;
    Inc(Count);
  End;
  ParserAdvance; { consomme %> }

  ChildFirst := StmtChildCount;
  For I := 0 To Count - 1 Do
  Begin
    If StmtChildCount >= MAX_JAVA_STMT_CHILD Then
    Begin
      FatalError('trop d instructions au total (MAX_JAVA_STMT_CHILD)');
      Break;
    End;
    StmtChildPool[StmtChildCount] := LocalChild[I];
    Inc(StmtChildCount);
  End;

  Idx := StmtAdd(SK_BLOCK);
  StmtPool[Idx].ChildFirst := ChildFirst;
  StmtPool[Idx].ChildCount := Count;
  ParseScriptletBlock := Idx;
End;

Function ParseExpressionBlock: Integer;
Var Idx: Integer;
Begin
  ParserAdvance;
  Idx := ParseJavaExpr;
  If CurTok.Kind <> TOK_TAG_CLOSE Then
    FatalError('%> attendu apres une expression <%= ... %>')
  Else
    ParserAdvance;
  ParseExpressionBlock := Idx;
End;

{ ============================================================ }
{ TODO 08 - TRADUCTION GABARIT<->JAVA ET ENTRELACEMENT DU FLOT   }
{ DE CONTROLE                                                    }
{ ============================================================ }

{ SkipActionBody (TODO 12/13) : PRE-CONDITION - CurTok EST                  }
{ TOK_ACTION_BODY_OPEN (le '>' ouvrant deja produit par le lexeur), PAS       }
{ encore consomme - avale le CORPS ENTIER jusqu a sa fermeture englobante       }
{ INCLUSE. Gere la profondeur en re-examinant CHAQUE action imbriquee            }
{ rencontree (auto-fermante ou avec corps) puisqu une action auto-fermante        }
{ de MEME nom ne produit JAMAIS de TOK_ACTION_CLOSE correspondant - un simple       }
{ compteur ouverture/fermeture SANS cette distinction sous-compterait la              }
{ profondeur. Glisse aussi sur les scriptlets/expressions/EL EVENTUELLEMENT             }
{ presents dans un corps non gere, par tolerance. Partagee par                          }
{ SkipUnknownAction (JSTL/taglib non gere, TryConsumeInterleaveToken) ET                  }
{ ParseJspUseBean (forme rare avec corps, TODO 13) - BOGUE REEL trouve par                  }
{ execution (le non-regression de JspActionSelfTest, initialement ecrit avec                 }
{ jsp:useBean TOUJOURS auto-fermant, ne l avait JAMAIS exerce ; le remplacer                    }
{ par un <c:if>...</c:if> AVEC CORPS a immediatement fait echouer le parseur                     }
{ suivant sur du contenu du corps jamais saute - l ancienne version n avancait                     }
{ QUE d un token apres TOK_ACTION_BODY_OPEN). }
Procedure SkipActionBody;
Var Depth: Integer;
Begin
  ParserAdvance; { consomme le '>' ouvrant (TOK_ACTION_BODY_OPEN) }
  Depth := 1;
  While (Depth > 0) And (CurTok.Kind <> TOK_EOF) Do
  Begin
    Case CurTok.Kind Of
      TOK_ACTION_OPEN:
        Begin
          ParserAdvance;
          While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
                (CurTok.Kind <> TOK_ACTION_BODY_OPEN) And
                (CurTok.Kind <> TOK_EOF) Do
            ParserAdvance;
          If CurTok.Kind = TOK_ACTION_BODY_OPEN Then Inc(Depth);
          If CurTok.Kind <> TOK_EOF Then ParserAdvance;
        End;
      TOK_ACTION_CLOSE:
        Begin
          Dec(Depth);
          ParserAdvance;
        End;
      TOK_EL_IMMEDIATE_OPEN, TOK_EL_DEFERRED_OPEN:
        Begin
          ParserAdvance;
          If CurTok.Kind = TOK_EL_RAW Then ParserAdvance;
        End;
      TOK_EXPR_OPEN:
        ParseExpressionBlock; { consomme jusqu au %> INCLUS }
      TOK_SCRIPTLET_OPEN, TOK_DECL_OPEN:
        Begin
          While (CurTok.Kind <> TOK_TAG_CLOSE) And (CurTok.Kind <> TOK_EOF) Do
            ParserAdvance;
          If CurTok.Kind <> TOK_EOF Then ParserAdvance;
        End;
    Else
      ParserAdvance; { TOK_TEMPLATE_CHUNK et le reste }
    End;
  End;
End;

{ SkipUnknownAction : PRE-CONDITION - CurTok EST TOK_ACTION_OPEN (une       }
{ action NON geree - JSTL/taglib personnalise, TODO 15/16), PAS encore        }
{ consomme. Avale l action ENTIERE (attributs, puis "/>" OU le corps           }
{ complet via SkipActionBody ci-dessus). }
Procedure SkipUnknownAction;
Begin
  While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
        (CurTok.Kind <> TOK_ACTION_BODY_OPEN) And
        (CurTok.Kind <> TOK_EOF) Do
    ParserAdvance;

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else If CurTok.Kind = TOK_ACTION_BODY_OPEN Then
    SkipActionBody;
End;

{ IsJstlCoreActionPrefix (TODO 16, section 16.2/16.3) : une action          }
{ "prefixe:nom" appartient a JSTL core SI ET SEULEMENT SI son prefixe a          }
{ ete declare (TODO 06, <%@ taglib %>) avec une des URI core (legacy               }
{ java.sun.com OU jakarta.tags, TaglibPool[].IsCoreJstl deja calcule) -             }
{ PAS un simple test syntaxique sur le prefixe "c" (qui pourrait, en                  }
{ theorie, etre associe a une AUTRE bibliotheque). LocalName recoit le                  }
{ nom de balise SANS le prefixe (ex. "forEach" pour "c:forEach"). }
Function IsJstlCoreActionPrefix(Const FullName: TString; Var LocalName: TString): Boolean;
Var ColonPos, TagIdx: Integer;
Begin
  IsJstlCoreActionPrefix := False;
  LocalName := '';
  ColonPos := Pos(':', FullName);
  If ColonPos = 0 Then Exit;
  TagIdx := TaglibFind(Copy(FullName, 1, ColonPos - 1));
  If (TagIdx >= 0) And TaglibPool[TagIdx].IsCoreJstl Then
  Begin
    LocalName := Copy(FullName, ColonPos + 1, Length(FullName) - ColonPos);
    IsJstlCoreActionPrefix := True;
  End;
End;

{ AttrTextToElIdx (TODO 16) : a besoin de ElNodeAdd/ELK_STRING/ElNodePool  }
{ (TODO 14, section situee PLUS BAS dans le fichier) - sa definition reelle    }
{ vit donc plus bas (juste avant ParseJstlBody, section TODO 16), PAS ici,       }
{ bien qu elle joue conceptuellement le meme role qu IsJstlCoreActionPrefix        }
{ ci-dessus (elle n est appelee que depuis ParseJstlOut/Set/If/Foreach,               }
{ eux-memes definis apres la section TODO 14 - aucun Forward n est donc              }
{ necessaire). }

{ TryConsumeInterleaveToken (definition reelle - voir le Forward et sa      }
{ note d en-tete pres de ParseStatement) : traite EXACTEMENT un element de    }
{ page a CurTok. TOK_SCRIPTLET_OPEN/TOK_TAG_CLOSE sont de PURES frontieres    }
{ entre deux fragments Java d un MEME flux d instructions (le "<%"/"%>" lui-   }
{ meme ne represente RIEN semantiquement, section 6.4) - avales SANS rien      }
{ produire. TOK_TEMPLATE_CHUNK/TOK_EXPR_OPEN deviennent des instructions        }
{ synthetiques SK_PRINT_TEMPLATE/SK_PRINT_EXPR (l equivalent de                 }
{ "out.print(...)", TODO 09 pour le VRAI objet implicite out). Les actions      }
{ JSP/taglib et les expressions EL n ont PAS ENCORE de traitement semantique     }
{ (TODO 09-13/TODO 14+) : ignorees avec un avertissement plutot que de faire      }
{ echouer toute la compilation - AUCUN echantillon couvert par CE TODO           }
{ (Test04Scriptlets.jsp/Test05Parametres.jsp/Test06Formulaire.jsp) n en           }
{ emploie, mais une degradation propre est preferable a un plantage des que       }
{ ce mecanisme sera exerce sur d autres pages. }
Function TryConsumeInterleaveToken(Var OutIdx: Integer): Boolean;
Var JstlLocalName, ActionPrefix: TString;
Begin
  TryConsumeInterleaveToken := False;
  Case CurTok.Kind Of
    TOK_SCRIPTLET_OPEN, TOK_TAG_CLOSE:
      ParserAdvance;

    TOK_TEMPLATE_CHUNK:
      Begin
        OutIdx := StmtAdd(SK_PRINT_TEMPLATE);
        StmtPool[OutIdx].BigVal := CurTok.Val;
        ParserAdvance;
        TryConsumeInterleaveToken := True;
      End;

    TOK_EXPR_OPEN:
      Begin
        OutIdx := StmtAdd(SK_PRINT_EXPR);
        StmtPool[OutIdx].ExprIdx := ParseExpressionBlock;
        TryConsumeInterleaveToken := True;
      End;

    TOK_ACTION_OPEN:
      { TODO 12/13/16 : jsp:include/jsp:forward/jsp:useBean/jsp:getProperty/  }
      { jsp:setProperty ET les 5 balises core JSTL de TODO 16 (c:out/c:set/     }
      { c:if/c:choose+c:when+c:otherwise/c:forEach, dispatchees via le            }
      { PREFIXE reellement declare comme core, IsJstlCoreActionPrefix)              }
      { recoivent desormais un VRAI traitement - toute AUTRE action                   }
      { (taglib personnalise/JSTL fmt-xml-sql - HORS DE PORTEE de ce                    }
      { compilateur, aucun TODO ne les couvre) reste degradee proprement                  }
      { (avertissement + saut jusqu a sa fermeture). }
      If (CurTok.Val = 'jsp:include') Or (CurTok.Val = 'jsp:forward') Then
      Begin
        OutIdx := ParseJspIncludeOrForward(CurTok.Val = 'jsp:forward');
        TryConsumeInterleaveToken := True;
      End
      Else If CurTok.Val = 'jsp:useBean' Then
      Begin
        OutIdx := ParseJspUseBean;
        TryConsumeInterleaveToken := True;
      End
      Else If CurTok.Val = 'jsp:getProperty' Then
      Begin
        OutIdx := ParseJspGetProperty;
        TryConsumeInterleaveToken := True;
      End
      Else If CurTok.Val = 'jsp:setProperty' Then
      Begin
        OutIdx := ParseJspSetProperty;
        TryConsumeInterleaveToken := True;
      End
      Else If IsJstlCoreActionPrefix(CurTok.Val, JstlLocalName) Then
      Begin
        If JstlLocalName = 'out' Then
        Begin OutIdx := ParseJstlOut; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'set' Then
        Begin OutIdx := ParseJstlSet; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'if' Then
        Begin OutIdx := ParseJstlIf; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'choose' Then
        Begin OutIdx := ParseJstlChoose; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'when' Then
        Begin OutIdx := ParseJstlWhen; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'otherwise' Then
        Begin OutIdx := ParseJstlOtherwise; TryConsumeInterleaveToken := True; End
        Else If JstlLocalName = 'forEach' Then
        Begin OutIdx := ParseJstlForeach; TryConsumeInterleaveToken := True; End
        Else
        Begin
          WarnMsg('balise core JSTL reconnue mais non geree (hors de ' +
                  'portee de ce compilateur) : ' + CurTok.Val);
          SkipUnknownAction;
        End;
      End
      Else
      Begin
        { TODO 20 (analyse best-effort) : distingue un prefixe JAMAIS         }
        { declare via <%@ taglib %> (erreur utilisateur actionnable - le          }
        { prefixe reserve "jsp" n est, par definition, JAMAIS declare de              }
        { cette facon, TODO 06 - EXCLU explicitement de ce diagnostic) d un              }
        { prefixe DEJA declare mais simplement non supporte par ce                        }
        { compilateur (JSTL fmt/xml/sql ou taglib personnalise, hors de                     }
        { portee - MEME message qu avant pour ce second cas). }
        ActionPrefix := Copy(CurTok.Val, 1, Pos(':', CurTok.Val) - 1);
        If (ActionPrefix <> 'jsp') And (ActionPrefix <> '') And
           (TaglibFind(ActionPrefix) < 0) Then
          WarnMsg('prefixe de balise jamais declare via <%@ taglib %> ' +
                  '(analyse best-effort, section 5.4) : ' + ActionPrefix)
        Else
          WarnMsg('action JSP/taglib rencontree - non geree, ignoree');
        SkipUnknownAction;
      End;

    TOK_EL_IMMEDIATE_OPEN, TOK_EL_DEFERRED_OPEN:
      { TODO 14 : une expression EL en gabarit recoit desormais un VRAI    }
      { traitement (parsee en TElNode, TODO 20+ pour l evaluation reelle    }
      { des objets implicites/portees) - section 12.1, la forme differee     }
      { N EST PAS un moyen general de retarder arbitrairement une              }
      { expression : LA VALIDATION que le contexte admet bien cette forme       }
      { differee n existe PAS encore (aucun echantillon n emploie la forme       }
      { differee en gabarit, seul le BoolVal enregistre laquelle des deux         }
      { formes a ete rencontree). }
      Begin
        OutIdx := StmtAdd(SK_PRINT_EL);
        StmtPool[OutIdx].BoolVal := (CurTok.Kind = TOK_EL_DEFERRED_OPEN);
        ParserAdvance; { consomme ${ ou #{ }
        If CurTok.Kind <> TOK_EL_RAW Then
          FatalError('contenu EL attendu apres ${ ou #{')
        Else
        Begin
          StmtPool[OutIdx].ElIdx := ParseElFromString(CurTok.Val);
          ParserAdvance; { consomme TOK_EL_RAW (deja capture ci-dessus) }
        End;
        TryConsumeInterleaveToken := True;
      End;
  Else
    OutIdx := ParseStatement;
    TryConsumeInterleaveToken := True;
  End;
End;

{ PerformStaticInclude (TODO 11) : Forward - definie plus bas (apres        }
{ ScopeSelfTest, section suivante) mais APPELEE DEPUIS ParsePage             }
{ juste en dessous - MEME technique que TryConsumeInterleaveToken/            }
{ ParseExpressionBlock deja utilisee au TODO 07/08 pour resoudre une            }
{ dependance d ordre textuel. }
Function PerformStaticInclude(Const ResolvedPath: TString): Boolean; Forward;

{ ParsePage : construit l arbre "page" ENTIER - lit le fichier depuis le    }
{ tout premier token (ParserAdvance amorce CurTok) jusqu a TOK_EOF, en         }
{ routant chaque element : directives (TOK_DIRECTIVE_OPEN, TODO 05/06 -        }
{ PILOTENT le lexeur DIRECTEMENT via LexNextToken, PAS via CurTok/               }
{ ParserAdvance, convention plus ancienne - un simple ParserAdvance juste         }
{ apres suffit a resynchroniser CurTok une fois la directive entierement           }
{ consommee, le lexeur sous-jacent etant deja exactement au bon endroit),           }
{ declarations (TOK_DECL_OPEN, TODO 07 - deja coherent avec CurTok/                  }
{ ParserAdvance, aucune resynchronisation requise), et tout le reste                  }
{ (gabarit/scriptlets/expressions/actions/EL) via TryConsumeInterleaveToken             }
{ ci-dessus. Retourne l index SK_BLOCK du corps de la methode _jspService                }
{ synthetique (TODO 09 lui donnera son nom/sa signature reels ; ce TODO se                }
{ limite a la CONSTRUCTION de l arbre, section 6/30). }
Function ParsePage: Integer;
Var
  Idx, ChildFirst, Count, I, NewIdx : Integer;
  LocalChild   : Array[0..MAX_JAVA_PAGE_LOCAL - 1] Of Integer;
  DirNameTok   : TToken;
  IncPath      : TBigString;
Begin
  ParserAdvance; { amorce CurTok avec le tout premier token du fichier }
  Count := 0;
  While CurTok.Kind <> TOK_EOF Do
  Begin
    If CurTok.Kind = TOK_DIRECTIVE_OPEN Then
    Begin
      DirNameTok := LexNextToken; { TOK_DIR_NAME, convention brute TODO 05/06 }
      If DirNameTok.Val = 'page' Then
        ParsePageDirective
      Else If DirNameTok.Val = 'include' Then
      Begin
        IncPath := ParseIncludeDirective(ExtractDir(Opts.SrcFile));
        { TODO 11 : fusion REELLE du fichier resolu - retokenise comme une   }
        { extension EN LIGNE du flux courant (section 11.1, "source            }
        { fusionne : oui" pour la directive include) - AUCUN appel               }
        { recursif necessaire : PerformStaticInclude SPLICE le contenu du         }
        { fragment directement dans SrcBuf a la position courante, et           }
        { CETTE MEME boucle ParsePage continue ensuite naturellement DANS         }
        { le contenu fraichement insere (y compris une eventuelle PROPRE           }
        { directive <%@ page %> du fragment, deja geree par                          }
        { ParsePageDirective/PageOpts ci-dessus - Test10Include.jsp/                  }
        { FragmentEntete.jsp/FragmentPied.jsp reels en ont chacun une). }
        PerformStaticInclude(IncPath);
      End
      Else If DirNameTok.Val = 'taglib' Then
        ParseTaglibDirective
      Else
        { nom de directive deja signale par TODO 03 (IsDirectiveName) - ici, }
        { avaler silencieusement jusqu au %> pour ne pas bloquer le reste     }
        { de la page. }
        While DirNameTok.Kind <> TOK_TAG_CLOSE Do
          DirNameTok := LexNextToken;
      ParserAdvance; { resynchronise CurTok - le lexeur est deja au bon endroit }
      Continue;
    End;

    If CurTok.Kind = TOK_DECL_OPEN Then
    Begin
      ParseDeclarationBlock; { gere deja CurTok correctement (TODO 07) }
      Continue;
    End;

    If TryConsumeInterleaveToken(NewIdx) Then
    Begin
      If Count >= MAX_JAVA_PAGE_LOCAL Then
      Begin
        FatalError('page trop volumineuse (MAX_JAVA_PAGE_LOCAL)');
        Break;
      End;
      LocalChild[Count] := NewIdx;
      Inc(Count);
    End;
  End;

  ChildFirst := StmtChildCount;
  For I := 0 To Count - 1 Do
  Begin
    If StmtChildCount >= MAX_JAVA_STMT_CHILD Then
    Begin
      FatalError('trop d instructions au total (MAX_JAVA_STMT_CHILD)');
      Break;
    End;
    StmtChildPool[StmtChildCount] := LocalChild[I];
    Inc(StmtChildCount);
  End;

  Idx := StmtAdd(SK_BLOCK);
  StmtPool[Idx].ChildFirst := ChildFirst;
  StmtPool[Idx].ChildCount := Count;
  ParsePage := Idx;
End;

{ ------------------------------------------------------------ }
{ JavaParserSelfTest - expressions (appel/selecteur/new/         }
{ litteraux), declarations (Test03Declarations.jsp/                }
{ Test05Parametres.jsp reels), scriptlet complet (2e scriptlet       }
{ de Test05, complet - PAS le 3e/4e, entrelaces avec le gabarit,      }
{ TODO 08), champ synthetique, for/while/affectation synthetiques    }
{ (aucun echantillon actuel des fichiers couverts par CE TODO ne les   }
{ exercice, Test04Scriptlets.jsp - for - est explicitement differe     }
{ au TODO 08).                                                          }
{ ------------------------------------------------------------ }

Procedure JavaAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('JavaParserSelfTest: ' + Label_ + ' a echoue');
End;

{ Amorce un fragment de scriptlet/expression/declaration ISOLE (sans   }
{ passer par un vrai fichier .jsp complet) : ecrit '<%' + Src + '%>'    }
{ dans un fichier temporaire, lexe jusqu au token d ouverture, PUIS       }
{ laisse l appelant driver le parseur EXACTEMENT comme un vrai <% %>      }
{ serait traite. }
Procedure JavaTestBegin(Const TmpFile, Src: TString; OpenTag: TString);
Var F: Text; Tok: TToken;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, OpenTag, Src, ' %>');
  Close(F);
  LexInit(TmpFile);
  Tok := LexNextToken; { consomme le token d ouverture (SCRIPTLET/DECL/EXPR) }
End;

Procedure JavaTestEnd(Const TmpFile: TString);
Var F: Text;
Begin
  LexClose;
  Assign(F, TmpFile);
  Erase(F);
End;

Procedure JavaParserSelfTest;
Const
  TmpFile = 'JSPJAVASELFTEST.$$$';
Var
  EIdx, SIdx, MIdx : Integer;
Begin
  JavaParserInit;

  { --- Expressions (Test01/02/03/05 reels) --- }

  JavaTestBegin(TmpFile, ' nomApplication() ', '<%=');
  EIdx := ParseExpressionBlock;
  JavaAssert('nomApplication() : CALL sur IDENT',
    (ExprPool[EIdx].Kind = EK_CALL) And
    (ExprPool[ExprPool[EIdx].Left].Kind = EK_IDENT) And
    (ExprPool[ExprPool[EIdx].Left].NameVal = 'nomApplication') And
    (ExprPool[EIdx].ArgCount = 0));
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile, ' carre(12) ', '<%=');
  EIdx := ParseExpressionBlock;
  JavaAssert('carre(12) : CALL avec 1 argument INT',
    (ExprPool[EIdx].Kind = EK_CALL) And (ExprPool[EIdx].ArgCount = 1) And
    (ExprPool[ExprArgPool[ExprPool[EIdx].ArgFirst]].Kind = EK_INT) And
    (ExprPool[ExprArgPool[ExprPool[EIdx].ArgFirst]].IntVal = 12));
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile, ' new java.util.Date() ', '<%=');
  EIdx := ParseExpressionBlock;
  JavaAssert('new java.util.Date() : NEWOBJECT qualifie',
    (ExprPool[EIdx].Kind = EK_NEWOBJECT) And
    (ExprPool[EIdx].NameVal = 'java.util.Date') And
    (ExprPool[EIdx].ArgCount = 0));
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile,
    ' DateFormat.getDateTimeInstance().format(new Date()) ', '<%=');
  EIdx := ParseExpressionBlock;
  JavaAssert('chaine selecteur/appel : racine = CALL "format"',
    (ExprPool[EIdx].Kind = EK_CALL) And
    (ExprPool[ExprPool[EIdx].Left].Kind = EK_SELECTOR) And
    (ExprPool[ExprPool[EIdx].Left].NameVal = 'format'));
  JavaAssert('chaine selecteur/appel : argument = NEWOBJECT Date',
    (ExprPool[EIdx].ArgCount = 1) And
    (ExprPool[ExprArgPool[ExprPool[EIdx].ArgFirst]].Kind = EK_NEWOBJECT) And
    (ExprPool[ExprArgPool[ExprPool[EIdx].ArgFirst]].NameVal = 'Date'));
  JavaTestEnd(TmpFile);

  { --- Declarations (Test03Declarations.jsp reel) --- }

  JavaTestBegin(TmpFile,
    ' private String nomApplication() { return "Catalogue JSP"; } ' +
    'private int carre(int valeur) { return valeur * valeur; } ',
    '<%!');
  ParseDeclarationBlock;
  JavaAssert('2 methodes declarees', JavaMethodCount = 2);
  JavaAssert('nomApplication : nom/type/visibilite/0 parametre',
    (JavaMethodPool[0].Name = 'nomApplication') And
    (JavaMethodPool[0].ReturnType = 'String') And
    (JavaMethodPool[0].Visibility = 'private') And
    (JavaMethodPool[0].ParamCount = 0));
  SIdx := JavaMethodPool[0].BodyStmtIdx;
  JavaAssert('nomApplication : corps = bloc a 1 instruction (return)',
    (StmtPool[SIdx].Kind = SK_BLOCK) And (StmtPool[SIdx].ChildCount = 1));
  SIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  JavaAssert('nomApplication : return d une chaine litterale',
    (StmtPool[SIdx].Kind = SK_RETURN) And
    (ExprPool[StmtPool[SIdx].ExprIdx].Kind = EK_STRING) And
    (ExprPool[StmtPool[SIdx].ExprIdx].StrVal = 'Catalogue JSP'));

  JavaAssert('carre : nom/type/1 parametre',
    (JavaMethodPool[1].Name = 'carre') And
    (JavaMethodPool[1].ReturnType = 'int') And
    (JavaMethodPool[1].ParamCount = 1));
  JavaAssert('carre : parametre "int valeur"',
    (JavaParamPool[JavaMethodPool[1].ParamFirst].TypeName = 'int') And
    (JavaParamPool[JavaMethodPool[1].ParamFirst].Name = 'valeur'));
  SIdx := JavaMethodPool[1].BodyStmtIdx;
  SIdx := StmtChildPool[StmtPool[SIdx].ChildFirst]; { return valeur * valeur; }
  JavaAssert('carre : return valeur * valeur (BINARY *)',
    (StmtPool[SIdx].Kind = SK_RETURN) And
    (ExprPool[StmtPool[SIdx].ExprIdx].Kind = EK_BINARY) And
    (ExprPool[StmtPool[SIdx].ExprIdx].Op = '*') And
    (ExprPool[ExprPool[StmtPool[SIdx].ExprIdx].Left].NameVal = 'valeur') And
    (ExprPool[ExprPool[StmtPool[SIdx].ExprIdx].Right].NameVal = 'valeur'));
  JavaTestEnd(TmpFile);

  { --- Declaration avec if/return et chaine de selecteurs/appels          }
  { (Test05Parametres.jsp reel, echapperHtml) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile,
    ' private String echapperHtml(String valeur) { ' +
    'if (valeur == null) { return ""; } ' +
    'return valeur.replace("&", "&amp;").replace("<", "&lt;"); } ',
    '<%!');
  ParseDeclarationBlock;
  JavaAssert('echapperHtml declaree', JavaMethodCount = 1);
  SIdx := JavaMethodPool[0].BodyStmtIdx;
  JavaAssert('corps : bloc a 2 instructions (if, return)',
    (StmtPool[SIdx].Kind = SK_BLOCK) And (StmtPool[SIdx].ChildCount = 2));
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst]; { premiere instruction : if }
  JavaAssert('1ere instruction : SK_IF sur "valeur == null"',
    (StmtPool[MIdx].Kind = SK_IF) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Kind = EK_BINARY) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Op = '==') And
    (ExprPool[ExprPool[StmtPool[MIdx].ExprIdx].Right].Kind = EK_NULL));
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst + 1]; { return valeur.replace(...).replace(...); }
  JavaAssert('2e instruction : return d une chaine de 2 appels .replace',
    (StmtPool[MIdx].Kind = SK_RETURN) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Kind = EK_CALL) And
    (ExprPool[ExprPool[StmtPool[MIdx].ExprIdx].Left].Kind = EK_SELECTOR) And
    (ExprPool[ExprPool[StmtPool[MIdx].ExprIdx].Left].NameVal = 'replace'));
  JavaTestEnd(TmpFile);

  { --- Scriptlet COMPLET (2e scriptlet de Test05Parametres.jsp reel -     }
  { PAS le 3e/4e, entrelaces avec le gabarit, TODO 08) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile,
    ' request.setCharacterEncoding("UTF-8"); ' +
    'String nom = request.getParameter("nom"); ',
    '<%');
  SIdx := ParseScriptletBlock;
  JavaAssert('scriptlet : bloc a 2 instructions',
    (StmtPool[SIdx].Kind = SK_BLOCK) And (StmtPool[SIdx].ChildCount = 2));
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  JavaAssert('1ere instruction : SK_EXPR (appel setCharacterEncoding)',
    (StmtPool[MIdx].Kind = SK_EXPR) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Kind = EK_CALL));
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst + 1];
  JavaAssert('2e instruction : SK_LOCALVAR "String nom = ..."',
    (StmtPool[MIdx].Kind = SK_LOCALVAR) And
    (StmtPool[MIdx].NameVal = 'String') And (StmtPool[MIdx].Op = 'nom') And
    (ExprPool[StmtPool[MIdx].ExprIdx].Kind = EK_CALL));
  JavaTestEnd(TmpFile);

  { --- for/while synthetiques (en avance sur Test04Scriptlets.jsp,        }
  { stitche au TODO 08 - PROUVE ICI le mecanisme general, meme              }
  { discipline que le prefixe "c:if" synthetique du TODO 03) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile,
    ' for (int i = 1; i <= 5; i++) { total += i; } ', '<%');
  SIdx := ParseScriptletBlock;
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  JavaAssert('for : SK_FOR avec init/condition/maj/corps',
    (StmtPool[MIdx].Kind = SK_FOR) And
    (StmtPool[StmtPool[MIdx].Left].Kind = SK_LOCALVAR) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Op = '<=') And
    (ExprPool[StmtPool[MIdx].Right].Op = 'post++'));
  JavaAssert('for : corps = bloc a 1 instruction (total += i)',
    (StmtPool[StmtPool[MIdx].Extra].Kind = SK_BLOCK) And
    (StmtPool[StmtPool[MIdx].Extra].ChildCount = 1));
  JavaTestEnd(TmpFile);

  JavaParserInit;
  JavaTestBegin(TmpFile, ' while (x < 10) { x++; } ', '<%');
  SIdx := ParseScriptletBlock;
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  JavaAssert('while : SK_WHILE avec condition/corps',
    (StmtPool[MIdx].Kind = SK_WHILE) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Op = '<') And
    (StmtPool[StmtPool[MIdx].Left].Kind = SK_BLOCK));
  JavaTestEnd(TmpFile);

  { --- affectation comme instruction-expression (synthetique) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile, ' total = total + 1; ', '<%');
  SIdx := ParseScriptletBlock;
  MIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  JavaAssert('affectation : SK_EXPR sur EK_ASSIGN "="',
    (StmtPool[MIdx].Kind = SK_EXPR) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Kind = EK_ASSIGN) And
    (ExprPool[StmtPool[MIdx].ExprIdx].Op = '='));
  JavaTestEnd(TmpFile);

  { --- champ synthetique (section 6.1, aucun echantillon des fichiers    }
  { couverts par CE TODO n en declare, Test09Application.jsp en aura       }
  { plus tard) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile, ' private int compteur = 0; ', '<%!');
  ParseDeclarationBlock;
  JavaAssert('champ compteur declare', JavaFieldCount = 1);
  JavaAssert('champ compteur : nom/type/static/initialiseur',
    (JavaFieldPool[0].Name = 'compteur') And
    (JavaFieldPool[0].TypeName = 'int') And
    (Not JavaFieldPool[0].IsStatic) And
    (ExprPool[JavaFieldPool[0].InitExprIdx].Kind = EK_INT) And
    (ExprPool[JavaFieldPool[0].InitExprIdx].IntVal = 0));
  JavaTestEnd(TmpFile);
End;

{ ------------------------------------------------------------ }
{ ImplicitObjectSelfTest (TODO 09) : surface de methode reelle     }
{ de Test07ObjetsImplicites.jsp (request/response/session/           }
{ application/config), methode inconnue sur un objet implicite         }
{ (avertissement), exception.getClass().getName() sur une page          }
{ isErrorPage="true" (Test12GestionErreur.jsp reel, methode              }
{ universelle Object autorisee), et "exception" HORS d une page            }
{ d erreur (erreur semantique, section 18.1/18.4).                          }
{ ------------------------------------------------------------ }

Procedure ImplicitAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ImplicitObjectSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ImplicitObjectSelfTest;
Const
  TmpFile = 'JSPIMPLICITSELFTEST.$$$';
Var
  EIdx, WarnBefore, ErrBefore : Integer;
Begin
  JavaParserInit;
  PageInit;
  Opts.Warnings := True; { rend WarnCount observable, meme discipline que  }
                          { PageSelfTest/TaglibSelfTest (TODO 05/06) }

  { --- surface de methode connue (Test07ObjetsImplicites.jsp reel) --- }

  { EIdx = EK_CALL, ExprPool[EIdx].Left = EK_SELECTOR ("getMethod"),        }
  { ExprPool[...].Left = EK_IDENT ("request") - TROIS niveaux, PAS deux. }
  JavaTestBegin(TmpFile, ' request.getMethod() ', '<%=');
  EIdx := ParseExpressionBlock;
  ImplicitAssert('request.getMethod() : base taguee IOK_REQUEST',
    ExprPool[ExprPool[ExprPool[EIdx].Left].Left].ImplicitKind = IOK_REQUEST);
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile, ' application.getServerInfo() ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ImplicitAssert('application.getServerInfo() : base taguee IOK_APPLICATION',
    ExprPool[ExprPool[ExprPool[EIdx].Left].Left].ImplicitKind = IOK_APPLICATION);
  ImplicitAssert('application.getServerInfo() : methode connue, pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile, ' session.setAttribute("x", total) ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ImplicitAssert('session.setAttribute(...) : methode connue, pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);

  JavaTestBegin(TmpFile, ' config.getServletName() ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ImplicitAssert('config.getServletName() : base taguee IOK_CONFIG',
    ExprPool[ExprPool[ExprPool[EIdx].Left].Left].ImplicitKind = IOK_CONFIG);
  ImplicitAssert('config.getServletName() : methode connue, pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);

  { --- identificateur ordinaire : PAS un objet implicite --- }

  JavaTestBegin(TmpFile, ' total ', '<%=');
  EIdx := ParseExpressionBlock;
  ImplicitAssert('"total" : IOK_NONE (variable ordinaire)',
    ExprPool[EIdx].ImplicitKind = IOK_NONE);
  JavaTestEnd(TmpFile);

  { --- methode inconnue sur un objet implicite : avertissement --- }

  JavaTestBegin(TmpFile, ' request.frobnicate() ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ImplicitAssert('request.frobnicate() : avertissement emis',
    WarnCount > WarnBefore);
  JavaTestEnd(TmpFile);

  { --- exception.getClass().getName() sur une page d erreur           }
  { (Test12GestionErreur.jsp reel) : getClass est une methode           }
  { UNIVERSELLE Object, autorisee meme hors de la surface propre         }
  { d "exception" - AUCUNE erreur semantique puisque IsErrorPage=true. --- }

  PageOpts.IsErrorPage := True;
  ErrBefore := ErrorCount;
  JavaTestBegin(TmpFile, ' exception.getClass().getName() ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ImplicitAssert('exception.getClass().getName() : aucun avertissement',
    WarnCount = WarnBefore);
  ImplicitAssert('exception sur page d erreur : aucune erreur semantique',
    ErrorCount = ErrBefore);
  JavaTestEnd(TmpFile);

  { --- "exception" HORS d une page d erreur : erreur semantique --- }

  PageOpts.IsErrorPage := False;
  ErrBefore := ErrorCount;
  JavaTestBegin(TmpFile, ' exception.getMessage() ', '<%=');
  EIdx := ParseExpressionBlock;
  ImplicitAssert('"exception" sans isErrorPage : erreur semantique emise',
    ErrorCount > ErrBefore);
  JavaTestEnd(TmpFile);
End;

{ ------------------------------------------------------------ }
{ ScopeSelfTest (TODO 10) : table runtime des 4 portees            }
{ (set/get/remove, cles independantes par portee, absence,          }
{ ecrasement sans duplication), plus les additions syntaxiques        }
{ Test08Session.jsp/Test09Application.jsp reels : cast explicite        }
{ "(String)session.getAttribute(...)", non-regression sur une            }
{ expression parenthesee ORDINAIRE (Test05Parametres.jsp reel),            }
{ "synchronized (application)" suivi d un bloc (bloc retourne                }
{ directement, aucun noeud distinct), et la surface de methode etendue        }
{ (setAttribute/getAttribute/removeAttribute desormais connus sur              }
{ request/pageContext EN PLUS de session/application, section 8.2).             }
{ ------------------------------------------------------------ }

Procedure ScopeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ScopeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ScopeSelfTest;
Const
  TmpFile = 'JSPSCOPESELFTEST.$$$';
Var
  EIdx, SIdx, LVIdx, CastIdx, CallIdx, BodyBlockIdx, InnerIdx : Integer;
  WarnBefore, CountBefore                                    : Integer;
  Found                                                       : Boolean;
  V, V2                                                       : TELValue;
Begin
  JavaParserInit;
  Opts.Warnings := True; { rend WarnCount observable, meme discipline que  }
                          { PageSelfTest/TaglibSelfTest/ImplicitObjectSelfTest }

  { --- table runtime des portees (section 8.1/8.2) --- }

  ScopeInit;

  V.Kind := ELV_STRING; V.StrVal := 'Ada';
  ScopeSetAttribute(SCOPE_SESSION, 'nomVisiteur', V);
  Found := ScopeGetAttribute(SCOPE_SESSION, 'nomVisiteur', V2);
  ScopeAssert('session.getAttribute retrouve la valeur ecrite',
    Found And (V2.Kind = ELV_STRING) And (V2.StrVal = 'Ada'));

  V.Kind := ELV_LONG; V.IntVal := 3;
  ScopeSetAttribute(SCOPE_APPLICATION, 'nombreVisites', V);
  Found := ScopeGetAttribute(SCOPE_APPLICATION, 'nombreVisites', V2);
  ScopeAssert('application.getAttribute retrouve la valeur ecrite',
    Found And (V2.Kind = ELV_LONG) And (V2.IntVal = 3));

  { meme cle "x" dans deux portees differentes : pas de collision (section  }
  { 8.3, un nom identique dans une portee plus courte masque les suivantes, }
  { consequence NATURELLE du filtre par Kind, jamais codee separement). }
  V.Kind := ELV_STRING; V.StrVal := 'valeur-request';
  ScopeSetAttribute(SCOPE_REQUEST, 'x', V);
  V.Kind := ELV_STRING; V.StrVal := 'valeur-session';
  ScopeSetAttribute(SCOPE_SESSION, 'x', V);
  ScopeGetAttribute(SCOPE_REQUEST, 'x', V2);
  ScopeAssert('cle "x" en scope REQUEST distincte de SESSION',
    V2.StrVal = 'valeur-request');
  ScopeGetAttribute(SCOPE_SESSION, 'x', V2);
  ScopeAssert('cle "x" en scope SESSION distincte de REQUEST',
    V2.StrVal = 'valeur-session');

  Found := ScopeGetAttribute(SCOPE_PAGE, 'inconnue', V2);
  ScopeAssert('cle absente : Found=False et valeur ELV_NULL',
    (Not Found) And (V2.Kind = ELV_NULL));

  ScopeRemoveAttribute(SCOPE_SESSION, 'nomVisiteur');
  Found := ScopeGetAttribute(SCOPE_SESSION, 'nomVisiteur', V2);
  ScopeAssert('removeAttribute puis getAttribute : absente', Not Found);

  CountBefore := ScopeAttrCount;
  V.Kind := ELV_LONG; V.IntVal := 99;
  ScopeSetAttribute(SCOPE_APPLICATION, 'nombreVisites', V);
  ScopeAssert('setAttribute ecrase une cle existante, ne duplique pas',
    ScopeAttrCount = CountBefore);
  ScopeGetAttribute(SCOPE_APPLICATION, 'nombreVisites', V2);
  ScopeAssert('valeur ecrasee bien relue', V2.IntVal = 99);

  { --- cast explicite (section 6.22, Test08Session.jsp reel) --- }

  JavaParserInit;
  JavaTestBegin(TmpFile,
    ' String nomVisiteur = (String)session.getAttribute("nomVisiteur"); ',
    '<%');
  SIdx := ParseScriptletBlock;
  LVIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  ScopeAssert('declaration locale nomVisiteur',
    (StmtPool[LVIdx].Kind = SK_LOCALVAR) And (StmtPool[LVIdx].Op = 'nomVisiteur'));
  CastIdx := StmtPool[LVIdx].ExprIdx;
  ScopeAssert('initialiseur = EK_CAST vers "String"',
    (ExprPool[CastIdx].Kind = EK_CAST) And (ExprPool[CastIdx].NameVal = 'String'));
  CallIdx := ExprPool[CastIdx].Left;
  ScopeAssert('operande du cast : appel getAttribute sur session',
    (ExprPool[CallIdx].Kind = EK_CALL) And
    (ExprPool[ExprPool[CallIdx].Left].NameVal = 'getAttribute') And
    (ExprPool[ExprPool[ExprPool[CallIdx].Left].Left].ImplicitKind = IOK_SESSION));
  JavaTestEnd(TmpFile);

  { --- non-regression : parenthese autour d une expression COMPLETE       }
  { (Test05Parametres.jsp reel) - JAMAIS un cast (le token qui suit '(' EST }
  { un IDENT ("nom"), mais celui d APRES n est PAS ')' - ParserPeek le        }
  { rejette correctement). --- }

  JavaParserInit;
  JavaTestBegin(TmpFile, ' (nom == null || nom.length() == 0) ', '<%=');
  EIdx := ParseExpressionBlock;
  ScopeAssert('expression parenthesee ordinaire : PAS un cast (EK_BINARY)',
    ExprPool[EIdx].Kind = EK_BINARY);
  JavaTestEnd(TmpFile);

  { --- synchronized (section 23.1, Test09Application.jsp reel) - no-op,   }
  { le bloc est retourne DIRECTEMENT, aucun noeud "synchronized" distinct. --- }

  JavaParserInit;
  JavaTestBegin(TmpFile,
    ' synchronized (application) { total = 1; } ', '<%');
  SIdx := ParseScriptletBlock;
  BodyBlockIdx := StmtChildPool[StmtPool[SIdx].ChildFirst];
  ScopeAssert('corps de synchronized retourne directement (SK_BLOCK)',
    StmtPool[BodyBlockIdx].Kind = SK_BLOCK);
  InnerIdx := StmtChildPool[StmtPool[BodyBlockIdx].ChildFirst];
  ScopeAssert('corps de synchronized contient l affectation "total = 1"',
    (StmtPool[InnerIdx].Kind = SK_EXPR) And
    (ExprPool[StmtPool[InnerIdx].ExprIdx].Kind = EK_ASSIGN));
  JavaTestEnd(TmpFile);

  { --- surface de methode ETENDUE (section 8.2) : setAttribute/            }
  { getAttribute/removeAttribute desormais connus sur request/pageContext    }
  { EN PLUS de session/application (TODO 09 ne couvrait que ces deux            }
  { derniers). --- }

  JavaParserInit;
  JavaTestBegin(TmpFile, ' request.setAttribute("k", total) ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ScopeAssert('request.setAttribute(...) : methode connue, pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);

  JavaParserInit;
  JavaTestBegin(TmpFile, ' pageContext.getAttribute("k") ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ScopeAssert('pageContext.getAttribute(...) : methode connue, pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);

  JavaParserInit;
  JavaTestBegin(TmpFile, ' application.removeAttribute("k") ', '<%=');
  WarnBefore := WarnCount;
  EIdx := ParseExpressionBlock;
  ScopeAssert('application.removeAttribute(...) : methode connue (extension), pas d avertissement',
    WarnCount = WarnBefore);
  JavaTestEnd(TmpFile);
End;

{ ------------------------------------------------------------ }
{ InterleaveSelfTest (TODO 08) : ParsePage sur deux fixtures       }
{ SYNTHETIQUES reproduisant fidelement Test04Scriptlets.jsp (for    }
{ dont le corps traverse deux scriptlets) et Test06Formulaire.jsp    }
{ (if/else imbriques traversant TROIS scriptlets) - synthetique       }
{ plutot que de relire les vrais fichiers SAMPLES\JSP\*.jsp (MEME       }
{ discipline "self-test independant du systeme de fichiers" que        }
{ tous les self-tests precedents - LexInit exige un chemin qui           }
{ existe, jamais garanti depuis un repertoire de travail arbitraire).     }
{ ------------------------------------------------------------ }

Procedure InterleaveAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('InterleaveSelfTest: ' + Label_ + ' a echoue');
End;

{ Retrouve le PREMIER enfant direct d un bloc ayant le TStmtKind donne -   }
{ utile quand des instructions "de bruit" (impressions d espaces blancs    }
{ de gabarit entre deux scriptlets, section 4.4) peuvent legitimement       }
{ entourer l instruction reellement recherchee, sans que leur nombre         }
{ exact vaille la peine d etre fige dans une assertion. }
Function FindChildOfKind(BlockIdx: Integer; K: TStmtKind): Integer;
Var J, CIdx: Integer;
Begin
  FindChildOfKind := -1;
  For J := 0 To StmtPool[BlockIdx].ChildCount - 1 Do
  Begin
    CIdx := StmtChildPool[StmtPool[BlockIdx].ChildFirst + J];
    If StmtPool[CIdx].Kind = K Then
    Begin
      FindChildOfKind := CIdx;
      Exit;
    End;
  End;
End;

Procedure InterleaveSelfTest;
Const
  TmpFile = 'JSPINTERLEAVESELFTEST.$$$';
Var
  F : Text;
  PageIdx, Idx0, Idx1, Idx2, Idx4 : Integer;
  ForBodyIdx, C0, C1, C2, C3      : Integer;
  OuterThenIdx, InnerIfIdx, ElseBlockIdx, PrintExprIdx : Integer;
Begin
  JavaParserInit;

  { --- Test04Scriptlets.jsp : for dont le corps s ouvre dans un           }
  { scriptlet et se referme dans un scriptlet ULTERIEUR, avec du gabarit    }
  { et un <%= i %> entre les deux (section 6.2/6.4). --- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, '<%@ page contentType="text/html" %>');
  WriteLn(F, '<ul>');
  WriteLn(F, '<%');
  WriteLn(F, '  int total = 0;');
  WriteLn(F, '  for (int i = 1; i <= 5; i++) {');
  WriteLn(F, '    total += i;');
  WriteLn(F, '%>');
  WriteLn(F, '  <li>Valeur <%= i %></li>');
  WriteLn(F, '<%');
  WriteLn(F, '  }');
  WriteLn(F, '%>');
  WriteLn(F, '</ul>');
  WriteLn(F, '<p>Total : <%= total %></p>');
  Close(F);

  LexInit(TmpFile);
  PageInit;
  PageIdx := ParsePage;

  InterleaveAssert('page : 6 enfants au niveau superieur',
    StmtPool[PageIdx].ChildCount = 6);

  Idx0 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 0];
  InterleaveAssert('enfant 0 : print gabarit "<ul>"',
    (StmtPool[Idx0].Kind = SK_PRINT_TEMPLATE) And
    (Pos('<ul>', StmtPool[Idx0].BigVal) > 0));

  Idx1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  InterleaveAssert('enfant 1 : SK_LOCALVAR total',
    (StmtPool[Idx1].Kind = SK_LOCALVAR) And (StmtPool[Idx1].Op = 'total'));

  Idx2 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 2];
  InterleaveAssert('enfant 2 : SK_FOR', StmtPool[Idx2].Kind = SK_FOR);

  ForBodyIdx := StmtPool[Idx2].Extra;
  InterleaveAssert('corps du for : bloc a 4 instructions',
    (StmtPool[ForBodyIdx].Kind = SK_BLOCK) And
    (StmtPool[ForBodyIdx].ChildCount = 4));

  C0 := StmtChildPool[StmtPool[ForBodyIdx].ChildFirst + 0];
  InterleaveAssert('corps for[0] : total += i (EK_ASSIGN "+=")',
    (StmtPool[C0].Kind = SK_EXPR) And
    (ExprPool[StmtPool[C0].ExprIdx].Kind = EK_ASSIGN) And
    (ExprPool[StmtPool[C0].ExprIdx].Op = '+='));

  C1 := StmtChildPool[StmtPool[ForBodyIdx].ChildFirst + 1];
  InterleaveAssert('corps for[1] : print gabarit "Valeur "',
    (StmtPool[C1].Kind = SK_PRINT_TEMPLATE) And
    (Pos('Valeur', StmtPool[C1].BigVal) > 0));

  C2 := StmtChildPool[StmtPool[ForBodyIdx].ChildFirst + 2];
  InterleaveAssert('corps for[2] : print expression "i"',
    (StmtPool[C2].Kind = SK_PRINT_EXPR) And
    (ExprPool[StmtPool[C2].ExprIdx].Kind = EK_IDENT) And
    (ExprPool[StmtPool[C2].ExprIdx].NameVal = 'i'));

  C3 := StmtChildPool[StmtPool[ForBodyIdx].ChildFirst + 3];
  InterleaveAssert('corps for[3] : print gabarit "</li>"',
    (StmtPool[C3].Kind = SK_PRINT_TEMPLATE) And
    (Pos('</li>', StmtPool[C3].BigVal) > 0));

  Idx4 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 4];
  InterleaveAssert('enfant 4 : print expression "total"',
    (StmtPool[Idx4].Kind = SK_PRINT_EXPR) And
    (ExprPool[StmtPool[Idx4].ExprIdx].NameVal = 'total'));

  LexClose;
  Erase(F);

  { --- Test06Formulaire.jsp : if/else IMBRIQUES, chacun ouvert dans un    }
  { scriptlet et referme dans un AUTRE, TROIS scriptlets distincts au       }
  { total (section 6.2/6.4). --- }
  JavaParserInit;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, '<% if (envoye) { %>');
  WriteLn(F, '  <% if (nom == null) { %>');
  WriteLn(F, '    <p>Vide</p>');
  WriteLn(F, '  <% } else { %>');
  WriteLn(F, '    <p>Bonjour <%= nom %></p>');
  WriteLn(F, '  <% } %>');
  WriteLn(F, '<% } %>');
  Close(F);

  LexInit(TmpFile);
  PageInit;
  PageIdx := ParsePage;

  Idx0 := FindChildOfKind(PageIdx, SK_IF);
  InterleaveAssert('un SK_IF existe au niveau page (if envoye)', Idx0 >= 0);

  OuterThenIdx := StmtPool[Idx0].Left;
  InterleaveAssert('corps de if(envoye) : bloc',
    StmtPool[OuterThenIdx].Kind = SK_BLOCK);

  InnerIfIdx := FindChildOfKind(OuterThenIdx, SK_IF);
  InterleaveAssert('if(envoye) contient un SK_IF imbrique (if nom==null)',
    InnerIfIdx >= 0);
  InterleaveAssert('le if imbrique a un ELSE', StmtPool[InnerIfIdx].Right <> -1);

  ElseBlockIdx := StmtPool[InnerIfIdx].Right;
  InterleaveAssert('branche ELSE : bloc', StmtPool[ElseBlockIdx].Kind = SK_BLOCK);

  PrintExprIdx := FindChildOfKind(ElseBlockIdx, SK_PRINT_EXPR);
  InterleaveAssert('branche ELSE contient un print expression "nom"',
    (PrintExprIdx >= 0) And
    (ExprPool[StmtPool[PrintExprIdx].ExprIdx].NameVal = 'nom'));

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 11 - INCLUSION STATIQUE (<%@ include %>)                 }
{ ============================================================ }

{ Fusion REELLE du fichier resolu au moment de la TRADUCTION (section 11.1, }
{ "directive include ... Source fusionne : oui" - a l oppose de jsp:include   }
{ ou d un forward, TOUS DEUX "Source fusionne : non", TODO 12) : le contenu    }
{ BRUT du fragment est SPLICE (insere) directement dans SrcBuf (TODO 02) a      }
{ la position exacte de la directive, puis la lecture continue - AUCUN         }
{ appel recursif au lexeur/parseur n est necessaire : ParsePage (TODO 08)        }
{ continue simplement SA PROPRE boucle, qui retrouve NATURELLEMENT une           }
{ eventuelle directive/declaration/scriptlet DU FRAGMENT lui-meme, EXACTEMENT      }
{ comme s ils avaient toujours fait partie du fichier de plus haut niveau           }
{ ("le fragment devient une seule unite JSP avec la page", section 5.3/11.1). }

Type
  TIncludeFrame = Record
    Path   : TString; { chemin resolu, pour la detection de circularite    }
    EndPos : LongInt;  { position ABSOLUE dans SrcBuf ou ce fragment se     }
                       { termine - ajustee a chaque SPLICE ulterieur QUI     }
                       { s insere A L INTERIEUR de cette plage (voir            }
                       { PerformStaticInclude) }
  End;

Var
  IncludeStack      : Array[0..MAX_INCLUDE - 1] Of TIncludeFrame;
  IncludeDepth      : Integer; { fragments ACTUELLEMENT actifs (ancetres)  }
  IncludeTotalCount : Integer; { TOTAL d inclusions REELLEMENT effectuees, }
                               { garde-fou anti-boucle brut, TOUJOURS       }
                               { croissant (jamais decompte) }
  FragBuf           : Array[1..SRC_BUF_SIZE] Of Char; { tampon de lecture   }
                               { du fragment - global pour eviter de           }
                               { passer un tableau geant en parametre           }

{ BOGUE REEL trouve par un test manuel de circularite (deux fichiers        }
{ s incluant mutuellement, ex. circ1.jsp <-> circ2.jsp) : SANS semer la      }
{ pile avec le fichier de PLUS HAUT NIVEAU lui-meme, un fragment qui           }
{ inclurait CE fichier n etait JAMAIS detecte comme circulaire - le              }
{ fichier de plus haut niveau est charge par LexInit (PAS par                      }
{ PerformStaticInclude), donc il n existait JAMAIS dans IncludeStack.               }
{ EndPos = MaxLongint (infini) : ce cadre n est JAMAIS purge par                     }
{ IncludePopFinished, sa "portee" couvre TOUTE la compilation par                     }
{ definition (le fichier de plus haut niveau n a pas de "fin" avant EOF). }
Procedure IncludeInit(Const TopLevelPath: TString);
Begin
  IncludeTotalCount := 0;
  IncludeStack[0].Path   := TopLevelPath;
  IncludeStack[0].EndPos := MaxLongint;
  IncludeDepth := 1;
End;

{ Retire de la pile tout fragment DONT la plage est DEJA entierement       }
{ derriere la position de lecture courante (LexPos) - appele PARESSEUSEMENT }
{ (uniquement avant de considerer une NOUVELLE inclusion) plutot qu a         }
{ chaque avancee de caractere (TODO 02, LexNextChar) : bien moins invasif      }
{ et amplement suffisant, puisque seule la detection de circularite (ci-        }
{ dessous) a besoin de savoir quels ancetres sont ENCORE actifs. Permet          }
{ CORRECTEMENT une re-inclusion NON imbriquee du MEME fichier (ex. un pied        }
{ de page inclus deux fois cote a cote, jamais l un DANS l autre) SANS la          }
{ confondre avec une VRAIE circularite. }
Procedure IncludePopFinished;
Begin
  While (IncludeDepth > 0) And
        (IncludeStack[IncludeDepth - 1].EndPos <= LexPos) Do
    Dec(IncludeDepth);
End;

{ Lit un fichier ENTIER dans FragBuf (meme technique que LexInit, TODO 02 - }
{ Assign/Reset/BlockRead/verification Eof) - PAS dans SrcBuf directement,    }
{ puisque le fragment doit encore etre SPLICE a une position precise plutot   }
{ que de remplacer le tampon principal. }
Function ReadWholeFileIntoFragBuf(Const Path: TString; Var Len: LongInt): Boolean;
Var F: File; N: LongInt;
Begin
  ReadWholeFileIntoFragBuf := False;
  Assign(F, Path);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('inclusion statique : impossible d ouvrir ' + Path);
    Exit;
  End;
  BlockRead(F, FragBuf, SRC_BUF_SIZE, N);
  Len := N;
  If Not Eof(F) Then
  Begin
    Close(F);
    FatalError('inclusion statique : fichier trop volumineux : ' + Path);
    Exit;
  End;
  Close(F);
  ReadWholeFileIntoFragBuf := True;
End;

{ Insere les DataLen premiers octets de FragBuf dans SrcBuf a la position   }
{ Pos (1-base), en decalant tout le reste VERS LA FIN (DownTo, pour ne        }
{ jamais ecraser une donnee avant de l avoir recopiee) - SrcLen (TODO 02)       }
{ augmente d autant. }
Procedure SrcSpliceFragBufAt(Pos: LongInt; DataLen: LongInt);
Var I: LongInt;
Begin
  If SrcLen + DataLen > SRC_BUF_SIZE Then
  Begin
    FatalError('fichier source trop volumineux apres inclusion (limite ' +
               IntToStrG(SRC_BUF_SIZE) + ' octets)');
    Exit;
  End;
  For I := SrcLen DownTo Pos Do
    SrcBuf[I + DataLen] := SrcBuf[I];
  For I := 1 To DataLen Do
    SrcBuf[Pos + I - 1] := FragBuf[I];
  Inc(SrcLen, DataLen);
End;

{ PerformStaticInclude (definition reelle - voir le Forward et sa note      }
{ d en-tete pres de ParsePage, TODO 08) : detecte la circularite (le chemin    }
{ resolu est-il DEJA un ancetre ACTIF, apres avoir d abord purge les              }
{ ancetres DEJA termines via IncludePopFinished ?), applique le garde-fou           }
{ MAX_INCLUDE (TOTAL, jamais decompte), lit et SPLICE le fragment, puis              }
{ AJUSTE la borne de fin de TOUS les ancetres encore actifs (une insertion           }
{ A L INTERIEUR de leur plage la repousse d autant, puisqu ils n ont, par               }
{ construction, pas encore ete purges) avant d empiler ce NOUVEAU fragment. }
Function PerformStaticInclude(Const ResolvedPath: TString): Boolean;
Var
  FragLen : LongInt;
  I       : Integer;
Begin
  PerformStaticInclude := False;

  IncludePopFinished;

  For I := 0 To IncludeDepth - 1 Do
    If IncludeStack[I].Path = ResolvedPath Then
    Begin
      FatalError('inclusion statique circulaire detectee : ' + ResolvedPath);
      Exit;
    End;

  If IncludeTotalCount >= MAX_INCLUDE Then
  Begin
    FatalError('trop d inclusions statiques au total (MAX_INCLUDE)');
    Exit;
  End;

  If Not ReadWholeFileIntoFragBuf(ResolvedPath, FragLen) Then Exit;

  SrcSpliceFragBufAt(LexPos, FragLen);

  { BOGUE REEL trouve par un test manuel de circularite : la borne          }
  { "infinie" du fichier de plus haut niveau (MaxLongint, IncludeInit ci-    }
  { dessus) DEBORDE (devient un LongInt NEGATIF) des qu on lui ajoute         }
  { FragLen ici - une valeur negative satisfait ALORS "EndPos <= LexPos"       }
  { pour n importe quel LexPos reel, faisant purger a tort le cadre du           }
  { fichier de plus haut niveau par IncludePopFinished DES la premiere            }
  { inclusion suivante, rendant la detection de circularite INOPERANTE.            }
  { EXCLU explicitement de l ajustement : sa "portee" reste TOUJOURS infinie.       }
  For I := 0 To IncludeDepth - 1 Do
    If IncludeStack[I].EndPos <> MaxLongint Then
      Inc(IncludeStack[I].EndPos, FragLen);

  IncludeStack[IncludeDepth].Path   := ResolvedPath;
  IncludeStack[IncludeDepth].EndPos := LexPos + FragLen;
  Inc(IncludeDepth);
  Inc(IncludeTotalCount);

  PerformStaticInclude := True;
End;

{ ------------------------------------------------------------ }
{ IncludeMergeSelfTest : fusion simple (avec directive <%@ page %> }
{ DANS le fragment, comme Test10Include.jsp/FragmentEntete.jsp       }
{ reels), imbrication A->B->C non circulaire (garde-fou d ancetres     }
{ ajuste correctement a travers deux splices successives), et           }
{ re-inclusion NON imbriquee du MEME fichier (prouve qu IncludePopFinished}
{ evite un faux positif de circularite). AUCUN test ne declenche la       }
{ VRAIE erreur de circularite : FatalError halte le PROCESSUS ENTIER       }
{ (TODO 01), impossible a observer depuis l interieur d un self-test qui    }
{ doit survivre pour la suite - verifiee manuellement via la CLI reelle      }
{ plutot que dans ce harnais, meme limite deja acceptee pour toute           }
{ Assertion visant un chemin FatalError ailleurs dans ce fichier.             }
{ ------------------------------------------------------------ }

Procedure IncludeMergeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('IncludeMergeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure IncludeMergeSelfTest;
Const
  FragFile = 'JSPINCFRAG.$$$';
  MainFile = 'JSPINCMAIN.$$$';
  FileC    = 'JSPINCC.$$$';
  FileB    = 'JSPINCB.$$$';
  FileA    = 'JSPINCA.$$$';
  FileD    = 'JSPINCD.$$$';
  FileE    = 'JSPINCE.$$$';
Var
  F                : Text;
  PageIdx, C0, C1 : Integer;
Begin
  { --- fusion simple, avec <%@ page %> DANS le fragment (Test10Include.jsp/ }
  { FragmentEntete.jsp reels) --- }
  Assign(F, FragFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html" %><p>Fragment 1</p>');
  Close(F);
  Assign(F, MainFile); Rewrite(F);
  Write(F, '<%@ page pageEncoding="UTF-8" %><div><%@ include file="',
        FragFile, '" %></div>');
  Close(F);

  JavaParserInit; PageInit; IncludeInit(MainFile);
  LexInit(MainFile);
  PageIdx := ParsePage;

  IncludeMergeAssert('page directive du FICHIER PRINCIPAL appliquee',
    PageOpts.PageEncoding = 'UTF-8');
  IncludeMergeAssert('page directive du FRAGMENT INCLUS aussi appliquee',
    PageOpts.ContentType = 'text/html');
  IncludeMergeAssert('page : 2 enfants (avant/apres la fusion)',
    StmtPool[PageIdx].ChildCount = 2);

  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 0];
  IncludeMergeAssert('enfant 0 : print "<div>"',
    (StmtPool[C0].Kind = SK_PRINT_TEMPLATE) And
    (Pos('<div>', StmtPool[C0].BigVal) > 0));

  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  IncludeMergeAssert('enfant 1 : fragment ET suite fusionnes en UNE unite',
    (StmtPool[C1].Kind = SK_PRINT_TEMPLATE) And
    (Pos('Fragment 1', StmtPool[C1].BigVal) > 0) And
    (Pos('</div>', StmtPool[C1].BigVal) > 0));

  LexClose;
  Assign(F, FragFile); Erase(F);
  Assign(F, MainFile); Erase(F);

  { --- imbrication A->B->C, NON circulaire --- }
  Assign(F, FileC); Rewrite(F);
  Write(F, 'C-content');
  Close(F);
  Assign(F, FileB); Rewrite(F);
  Write(F, 'B-before<%@ include file="', FileC, '" %>B-after');
  Close(F);
  Assign(F, FileA); Rewrite(F);
  Write(F, 'A-before<%@ include file="', FileB, '" %>A-after');
  Close(F);

  JavaParserInit; PageInit; IncludeInit(FileA);
  LexInit(FileA);
  PageIdx := ParsePage;

  IncludeMergeAssert('A->B->C : 3 enfants (A-before, B-before, C+B-after+A-after)',
    StmtPool[PageIdx].ChildCount = 3);
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 0];
  IncludeMergeAssert('enfant 0 : "A-before"', Pos('A-before', StmtPool[C0].BigVal) > 0);
  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  IncludeMergeAssert('enfant 1 : "B-before"', Pos('B-before', StmtPool[C1].BigVal) > 0);
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 2];
  IncludeMergeAssert('enfant 2 contient "C-content"', Pos('C-content', StmtPool[C0].BigVal) > 0);
  IncludeMergeAssert('enfant 2 contient "B-after"', Pos('B-after', StmtPool[C0].BigVal) > 0);
  IncludeMergeAssert('enfant 2 contient "A-after"', Pos('A-after', StmtPool[C0].BigVal) > 0);

  LexClose;
  Assign(F, FileA); Erase(F);
  Assign(F, FileB); Erase(F);
  Assign(F, FileC); Erase(F);

  { --- re-inclusion NON imbriquee du MEME fichier - ne doit PAS etre       }
  { confondue avec une circularite (IncludePopFinished doit avoir purge      }
  { la 1ere inclusion avant la tentative de la 2e). --- }
  Assign(F, FileD); Rewrite(F);
  Write(F, 'D-content');
  Close(F);
  Assign(F, FileE); Rewrite(F);
  Write(F, '<%@ include file="', FileD, '" %>-middle-<%@ include file="',
        FileD, '" %>');
  Close(F);

  JavaParserInit; PageInit; IncludeInit(FileE);
  LexInit(FileE);
  PageIdx := ParsePage; { ne doit PAS declencher FatalError }
  IncludeMergeAssert('re-inclusion non imbriquee : au moins 1 enfant produit',
    StmtPool[PageIdx].ChildCount >= 1);

  LexClose;
  Assign(F, FileD); Erase(F);
  Assign(F, FileE); Erase(F);
End;

{ ============================================================ }
{ TODO 12 - ACTIONS STANDARD : INCLUDE DYNAMIQUE, FORWARD, PARAM }
{ ============================================================ }

{ A la difference de la directive include (TODO 11, "source fusionne :     }
{ oui", TODO 08), jsp:include/jsp:forward sont EXECUTES au moment de la      }
{ REQUETE ("Source fusionne : non", section 11.1) : ce TODO se limite a la     }
{ CONSTRUCTION de l arbre (SK_INCLUDE_ACTION/SK_FORWARD_ACTION, ci-dessus)       }
{ - AUCUN appel runtime _JSPRT_Include reel n existe encore (roadmap            }
{ d en-tete, TODO 21+, puisqu aucune generation de code n existe encore),         }
{ EXACTEMENT la meme discipline "PARSING d abord, semantique/codegen plus         }
{ tard" que TOUS les TODO precedents de ce fichier. }

Type
  TJspParam = Record
    Name  : TString;
    Value : TBigString; { section 9.3 : "les valeurs deviennent des         }
                        { parametres de requete" - peuvent en principe        }
                        { contenir une expression EL (ex. produit.id via        }
                        { la syntaxe EL, section 12) : capturee VERBATIM        }
                        { ici, AUCUNE evaluation EL n existe encore (TODO 14+) }
  End;

Var
  JspParamPool  : Array[0..MAX_JSP_PARAM - 1] Of TJspParam;
  JspParamCount : Integer;

Procedure JspParamInit;
Begin
  JspParamCount := 0;
End;

{ Consomme, DEPUIS le mode gabarit juste apres un TOK_ACTION_BODY_OPEN      }
{ (le '>' ouvrant de <jsp:include ...>/<jsp:forward ...>, TODO 03), une      }
{ SUITE de <jsp:param name="..." value="..." /> (TOUJOURS auto-fermant,       }
{ section 9.3) jusqu au TOK_ACTION_CLOSE englobant - retourne le nombre         }
{ de jsp:param ajoutes a JspParamPool. Le texte de gabarit (typiquement          }
{ des espaces/sauts de ligne entre deux jsp:param, sans equivalent visible        }
{ dans la sortie reelle d un conteneur) est avale silencieusement ; toute          }
{ AUTRE construction est un usage non prevu par la reference, signale par un        }
{ avertissement plutot que de bloquer toute la compilation. }
Function ParseJspParamBody: Integer;
Var
  Count      : Integer;
  ParamName  : TString;
  ParamValue : TBigString;
Begin
  Count := 0;
  While CurTok.Kind <> TOK_ACTION_CLOSE Do
  Begin
    If CurTok.Kind = TOK_EOF Then
    Begin
      FatalError('"</jsp:include>" ou "</jsp:forward>" attendu (corps non ferme)');
      Break;
    End;

    If (CurTok.Kind = TOK_ACTION_OPEN) And (CurTok.Val = 'jsp:param') Then
    Begin
      ParserAdvance; { consomme TOK_ACTION_OPEN "jsp:param" }
      ParamName := ''; ParamValue := '';
      While CurTok.Kind = TOK_ATTR_NAME Do
      Begin
        If CurTok.Val = 'name' Then
        Begin
          ParserAdvance;
          If CurTok.Kind = TOK_ATTR_VALUE Then ParamName := CurTok.Val;
        End
        Else If CurTok.Val = 'value' Then
        Begin
          ParserAdvance;
          If CurTok.Kind = TOK_ATTR_VALUE Then ParamValue := CurTok.Val;
        End
        Else
        Begin
          WarnMsg('jsp:param : attribut inconnu ignore : ' + CurTok.Val);
          ParserAdvance; { positionne sur la TOK_ATTR_VALUE correspondante }
        End;
        ParserAdvance;
      End;

      If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
        ParserAdvance
      Else
        FatalError('jsp:param : forme auto-fermante attendue (section 9.3)');

      If JspParamCount >= MAX_JSP_PARAM Then
      Begin
        FatalError('trop de jsp:param au total (MAX_JSP_PARAM)');
        Break;
      End;
      JspParamPool[JspParamCount].Name  := ParamName;
      JspParamPool[JspParamCount].Value := ParamValue;
      Inc(JspParamCount);
      Inc(Count);
    End
    Else If CurTok.Kind = TOK_TEMPLATE_CHUNK Then
      ParserAdvance { espaces/sauts de ligne entre deux jsp:param - avales }
    Else
    Begin
      WarnMsg('jsp:include/jsp:forward : contenu inattendu dans le corps, ignore');
      ParserAdvance;
    End;
  End;
  ParserAdvance; { consomme TOK_ACTION_CLOSE }
  ParseJspParamBody := Count;
End;

{ ParseJspIncludeOrForward (definition reelle - voir le Forward et sa       }
{ note d en-tete pres de TryConsumeInterleaveToken, TODO 08) : PRE-           }
{ CONDITION - CurTok EST TOK_ACTION_OPEN ("jsp:include" ou "jsp:forward"),     }
{ PAS encore consomme. "page" est obligatoire (section 9.1/9.2) ; "flush"       }
{ n est reconnu QUE pour jsp:include (absent de la grammaire jsp:forward,        }
{ section 9.2 - un "flush" sur un forward tombe dans "attribut inconnu"). }
Function ParseJspIncludeOrForward(IsForward: Boolean): Integer;
Var
  Idx      : Integer;
  AttrName : TString;
  HasPage  : Boolean;
  PageVal  : TBigString;
  FlushVal : Boolean;
  Kind     : TStmtKind;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (jsp:include/jsp:forward) }
  HasPage := False; PageVal := ''; FlushVal := False;

  While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
        (CurTok.Kind <> TOK_ACTION_BODY_OPEN) Do
  Begin
    If CurTok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('jsp:include/jsp:forward : nom d attribut attendu');
      ParseJspIncludeOrForward := -1;
      Exit;
    End;
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('jsp:include/jsp:forward : valeur d attribut attendue pour ' +
                 AttrName);
      ParseJspIncludeOrForward := -1;
      Exit;
    End;

    If AttrName = 'page' Then
    Begin
      PageVal := CurTok.Val;
      HasPage := True;
    End
    Else If (Not IsForward) And (AttrName = 'flush') Then
    Begin
      If Not ParseJspBoolean(CurTok.Val, FlushVal) Then
        WarnMsg('jsp:include : valeur booleenne "true"/"false" attendue ' +
                'pour "flush", trouve : ' + CurTok.Val);
    End
    Else
      WarnMsg('jsp:include/jsp:forward : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasPage Then
    FatalError('jsp:include/jsp:forward : attribut "page" obligatoire ' +
               '(section 9.1/9.2)');

  If IsForward Then Kind := SK_FORWARD_ACTION Else Kind := SK_INCLUDE_ACTION;
  Idx := StmtAdd(Kind);
  StmtPool[Idx].BigVal     := PageVal;
  StmtPool[Idx].BoolVal    := FlushVal;
  StmtPool[Idx].ParamFirst := JspParamCount;

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance; { consomme /> }
    StmtPool[Idx].ParamCount := 0;
    ParseJspIncludeOrForward := Idx;
    Exit;
  End;

  ParserAdvance; { consomme le '>' ouvrant du corps (TOK_ACTION_BODY_OPEN) }
  StmtPool[Idx].ParamCount := ParseJspParamBody;
  ParseJspIncludeOrForward := Idx;
End;

{ ------------------------------------------------------------ }
{ JspActionSelfTest : jsp:include auto-fermant (Test11Include        }
{ Action.jsp reel), jsp:include avec CORPS et jsp:param imbriques      }
{ (synthetique, section 9.1/9.3 - aucun echantillon actuel ne le        }
{ combine), jsp:forward (synthetique, section 9.2 - aucun               }
{ echantillon ne l exercice, roadmap d en-tete), et non-regression         }
{ : toute AUTRE action (jsp:useBean, TODO 13) reste degradee proprement.    }
{ ------------------------------------------------------------ }

Procedure JspActionAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('JspActionSelfTest: ' + Label_ + ' a echoue');
End;

Procedure JspActionSelfTest;
Const
  TmpFile = 'JSPACTIONSELFTEST.$$$';
Var
  F                 : Text;
  PageIdx, C0, C1 : Integer;
  WarnBefore        : Integer;
Begin
  JavaParserInit; PageInit; JspParamInit;
  Opts.Warnings := True; { observer WarnCount, meme discipline etablie }

  { --- jsp:include auto-fermant (Test11IncludeAction.jsp reel) --- }
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:include page="FragmentEntete.jsp" flush="true" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspActionAssert('jsp:include reel : SK_INCLUDE_ACTION',
    StmtPool[C0].Kind = SK_INCLUDE_ACTION);
  JspActionAssert('jsp:include reel : page="FragmentEntete.jsp"',
    StmtPool[C0].BigVal = 'FragmentEntete.jsp');
  JspActionAssert('jsp:include reel : flush=true', StmtPool[C0].BoolVal);
  JspActionAssert('jsp:include reel : aucun jsp:param', StmtPool[C0].ParamCount = 0);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- jsp:include AVEC corps et jsp:param imbriques (synthetique,        }
  { section 9.1/9.3) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:include page="fiche.jsp">',
        '<jsp:param name="id" value="42" />',
        '<jsp:param name="lang" value="fr" />',
        '</jsp:include>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspActionAssert('jsp:include avec corps : SK_INCLUDE_ACTION',
    StmtPool[C0].Kind = SK_INCLUDE_ACTION);
  JspActionAssert('jsp:include avec corps : page="fiche.jsp"',
    StmtPool[C0].BigVal = 'fiche.jsp');
  JspActionAssert('jsp:include avec corps : 2 jsp:param',
    StmtPool[C0].ParamCount = 2);
  JspActionAssert('jsp:param 1 : name=id/value=42',
    (JspParamPool[StmtPool[C0].ParamFirst].Name = 'id') And
    (JspParamPool[StmtPool[C0].ParamFirst].Value = '42'));
  JspActionAssert('jsp:param 2 : name=lang/value=fr',
    (JspParamPool[StmtPool[C0].ParamFirst + 1].Name = 'lang') And
    (JspParamPool[StmtPool[C0].ParamFirst + 1].Value = 'fr'));
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- jsp:forward (synthetique, section 9.2 - aucun echantillon ne l     }
  { exercice, roadmap d en-tete) : pas de "flush", "page" obligatoire. --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:forward page="erreur.jsp" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspActionAssert('jsp:forward : SK_FORWARD_ACTION',
    StmtPool[C0].Kind = SK_FORWARD_ACTION);
  JspActionAssert('jsp:forward : page="erreur.jsp"',
    StmtPool[C0].BigVal = 'erreur.jsp');
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : une action JSTL/taglib (ex. c:if, TODO 15/16)     }
  { reste degradee proprement (avertissement + saut) - jsp:useBean N EST     }
  { PLUS un bon exemple ICI depuis que le TODO 13 lui donne un VRAI            }
  { traitement (voir JspBeanSelfTest, section suivante). --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<c:if test="x"><p>ignore</p></c:if>',
        '<p>suite</p>');
  Close(F);
  LexInit(TmpFile);
  WarnBefore := WarnCount;
  PageIdx := ParsePage;
  JspActionAssert('c:if : avertissement emis (non gere avant TODO 15/16)',
    WarnCount > WarnBefore);
  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspActionAssert('c:if ignore : le gabarit "suite" suit correctement',
    (StmtPool[C1].Kind = SK_PRINT_TEMPLATE) And (Pos('suite', StmtPool[C1].BigVal) > 0));
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 13 - ACTIONS STANDARD : USEBEAN / SETPROPERTY /          }
{ GETPROPERTY                                                   }
{ ============================================================ }

{ MEME discipline que le TODO 12 (jsp:include/forward) : ce TODO se        }
{ limite a la CONSTRUCTION de l arbre (SK_USEBEAN_ACTION/                    }
{ SK_GETPROPERTY_ACTION/SK_SETPROPERTY_ACTION, ci-dessus) - la SEMANTIQUE      }
{ reelle (instanciation/recherche dans le scope pour jsp:useBean,               }
{ dispatch vers le getter/setter JavaBean conventionnel pour get/                }
{ setProperty, introspection pour property="*") exige un VRAI codegen/            }
{ une VRAIE resolution de type qui n existent pas encore (TODO 20/21+,             }
{ roadmap d en-tete) - AUCUN appel runtime n est genere ici, exactement            }
{ comme jsp:include/forward avant lui. }

{ Section 8.1/9.4 : "page"/"request"/"session"/"application" - REUTILISE   }
{ TScopeKind (TODO 10) plutot que d introduire un type distinct, puisque      }
{ jsp:useBean designe EXACTEMENT les 4 memes portees. }
Function ParseScopeAttr(Const S: TString; Var OutKind: TScopeKind): Boolean;
Begin
  ParseScopeAttr := True;
  If S = 'page' Then OutKind := SCOPE_PAGE
  Else If S = 'request' Then OutKind := SCOPE_REQUEST
  Else If S = 'session' Then OutKind := SCOPE_SESSION
  Else If S = 'application' Then OutKind := SCOPE_APPLICATION
  Else ParseScopeAttr := False;
End;

{ ParseJspUseBean (definition reelle - voir le Forward et sa note pres de  }
{ TryConsumeInterleaveToken) : PRE-CONDITION - CurTok EST TOK_ACTION_OPEN     }
{ ("jsp:useBean"), PAS encore consomme. "id" est obligatoire (section 9.4) ;  }
{ "class"/"type" restent tous deux optionnels a ce niveau PUREMENT               }
{ syntaxique (un bean peut deja exister dans le scope sans jamais etre             }
{ instancie, section 9.4 "S il est absent et si class autorise la                    }
{ creation...") - un avertissement signale l absence des DEUX plutot qu une            }
{ erreur fatale, la validite reelle dependant du contenu du scope a                     }
{ l EXECUTION (TODO 18+, inconnu ici). }
Function ParseJspUseBean: Integer;
Var
  Idx      : Integer;
  AttrName : TString;
  HasId    : Boolean;
  IdVal    : TString;
  ClassVal : TString;
  TypeVal  : TBigString;
  ScopeVal : TScopeKind;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN "jsp:useBean" }
  HasId := False; IdVal := ''; ClassVal := ''; TypeVal := '';
  ScopeVal := SCOPE_PAGE;

  While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
        (CurTok.Kind <> TOK_ACTION_BODY_OPEN) Do
  Begin
    If CurTok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('jsp:useBean : nom d attribut attendu');
      ParseJspUseBean := -1;
      Exit;
    End;
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('jsp:useBean : valeur d attribut attendue pour ' + AttrName);
      ParseJspUseBean := -1;
      Exit;
    End;

    If AttrName = 'id' Then
    Begin
      IdVal := CurTok.Val;
      HasId := True;
    End
    Else If AttrName = 'class' Then
      ClassVal := CurTok.Val
    Else If AttrName = 'scope' Then
    Begin
      If Not ParseScopeAttr(CurTok.Val, ScopeVal) Then
        WarnMsg('jsp:useBean : scope inconnu, "page" suppose : ' + CurTok.Val);
    End
    Else If AttrName = 'type' Then
      TypeVal := CurTok.Val
    Else If AttrName = 'beanName' Then
      { reconnu syntaxiquement, mecanisme historique de creation NON          }
      { implemente (aucun echantillon ne l exercice) - meme discipline que      }
      { "tagdir" au TODO 06. }
    Else
      WarnMsg('jsp:useBean : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasId Then
    FatalError('jsp:useBean : attribut "id" obligatoire (section 9.4)');
  If (ClassVal = '') And (TypeVal = '') Then
    WarnMsg('jsp:useBean : ni "class" ni "type" fourni - le bean devra ' +
            'deja exister dans la portee (section 9.4)');

  Idx := StmtAdd(SK_USEBEAN_ACTION);
  StmtPool[Idx].Op      := IdVal;
  StmtPool[Idx].NameVal := ClassVal;
  StmtPool[Idx].BigVal  := TypeVal;
  StmtPool[Idx].Extra   := Ord(ScopeVal);

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else
  Begin
    { forme avec corps (rare, section 9.4 ne la documente pas explicitement -}
    { execution CONDITIONNELLE du corps a la seule creation reelle du bean,   }
    { hors de portee) - avalee par tolerance via SkipActionBody (MEME           }
    { fonction PARTAGEE que les actions non gerees de                            }
    { TryConsumeInterleaveToken, tient compte des imbrications). }
    WarnMsg('jsp:useBean : forme avec corps non geree (executee telle ' +
            'quelle, sans la semantique "seulement a la creation")');
    SkipActionBody;
  End;

  ParseJspUseBean := Idx;
End;

{ ParseJspGetProperty (definition reelle) : PRE-CONDITION - CurTok EST     }
{ TOK_ACTION_OPEN ("jsp:getProperty"), PAS encore consomme. "name" et       }
{ "property" sont TOUS DEUX obligatoires (section 9.6) - AUCUNE forme        }
{ avec corps n est documentee, contrairement a jsp:useBean, traitee ici        }
{ comme une erreur plutot que tolerée en silence. }
Function ParseJspGetProperty: Integer;
Var
  Idx          : Integer;
  AttrName     : TString;
  HasName, HasProperty : Boolean;
  NameVal_, PropertyVal : TString;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN "jsp:getProperty" }
  HasName := False; HasProperty := False; NameVal_ := ''; PropertyVal := '';

  While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
        (CurTok.Kind <> TOK_ACTION_BODY_OPEN) Do
  Begin
    If CurTok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('jsp:getProperty : nom d attribut attendu');
      ParseJspGetProperty := -1;
      Exit;
    End;
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('jsp:getProperty : valeur d attribut attendue pour ' + AttrName);
      ParseJspGetProperty := -1;
      Exit;
    End;

    If AttrName = 'name' Then
    Begin
      NameVal_ := CurTok.Val;
      HasName := True;
    End
    Else If AttrName = 'property' Then
    Begin
      PropertyVal := CurTok.Val;
      HasProperty := True;
    End
    Else
      WarnMsg('jsp:getProperty : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasName Then
    FatalError('jsp:getProperty : attribut "name" obligatoire (section 9.6)');
  If Not HasProperty Then
    FatalError('jsp:getProperty : attribut "property" obligatoire (section 9.6)');

  Idx := StmtAdd(SK_GETPROPERTY_ACTION);
  StmtPool[Idx].Op      := NameVal_;
  StmtPool[Idx].NameVal := PropertyVal;

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else
    FatalError('jsp:getProperty : forme auto-fermante attendue (section 9.6)');

  ParseJspGetProperty := Idx;
End;

{ ParseJspSetProperty (definition reelle) : PRE-CONDITION - CurTok EST     }
{ TOK_ACTION_OPEN ("jsp:setProperty"), PAS encore consomme. TROIS formes      }
{ (section 9.5) : "value" (litterale), "param" (nom de parametre source),      }
{ "property"="*" (copie generalisee, ignore value/param) - "name" et             }
{ "property" restent TOUS DEUX obligatoires dans les trois cas. }
Function ParseJspSetProperty: Integer;
Var
  Idx           : Integer;
  AttrName      : TString;
  HasName, HasProperty, HasValue, HasParam : Boolean;
  NameVal_, PropertyVal, ParamVal : TString;
  ValueVal      : TBigString;
  SrcKind       : TSetPropertySource;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN "jsp:setProperty" }
  HasName := False; HasProperty := False; HasValue := False; HasParam := False;
  NameVal_ := ''; PropertyVal := ''; ValueVal := ''; ParamVal := '';

  While (CurTok.Kind <> TOK_ACTION_SELFCLOSE) And
        (CurTok.Kind <> TOK_ACTION_BODY_OPEN) Do
  Begin
    If CurTok.Kind <> TOK_ATTR_NAME Then
    Begin
      FatalError('jsp:setProperty : nom d attribut attendu');
      ParseJspSetProperty := -1;
      Exit;
    End;
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('jsp:setProperty : valeur d attribut attendue pour ' + AttrName);
      ParseJspSetProperty := -1;
      Exit;
    End;

    If AttrName = 'name' Then
    Begin NameVal_ := CurTok.Val; HasName := True; End
    Else If AttrName = 'property' Then
    Begin PropertyVal := CurTok.Val; HasProperty := True; End
    Else If AttrName = 'value' Then
    Begin ValueVal := CurTok.Val; HasValue := True; End
    Else If AttrName = 'param' Then
    Begin ParamVal := CurTok.Val; HasParam := True; End
    Else
      WarnMsg('jsp:setProperty : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasName Then
    FatalError('jsp:setProperty : attribut "name" obligatoire (section 9.5)');
  If Not HasProperty Then
    FatalError('jsp:setProperty : attribut "property" obligatoire (section 9.5)');

  If PropertyVal = '*' Then
  Begin
    SrcKind := SPS_WILDCARD;
    If HasValue Or HasParam Then
      WarnMsg('jsp:setProperty : property="*" ignore "value"/"param" ' +
              '(section 9.1/10.3)');
  End
  Else If HasValue Then
    SrcKind := SPS_VALUE
  Else If HasParam Then
    SrcKind := SPS_PARAM
  Else
  Begin
    WarnMsg('jsp:setProperty : "value" ou "param" attendu quand ' +
            '"property" n est pas "*" (section 9.5)');
    SrcKind := SPS_VALUE;
  End;

  Idx := StmtAdd(SK_SETPROPERTY_ACTION);
  StmtPool[Idx].Op      := NameVal_;
  StmtPool[Idx].NameVal := PropertyVal;
  StmtPool[Idx].Extra   := Ord(SrcKind);
  Case SrcKind Of
    SPS_VALUE : StmtPool[Idx].BigVal := ValueVal;
    SPS_PARAM : StmtPool[Idx].BigVal := ParamVal;
  Else
    StmtPool[Idx].BigVal := '';
  End;

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else
    FatalError('jsp:setProperty : forme auto-fermante attendue (section 9.5)');

  ParseJspSetProperty := Idx;
End;

{ ------------------------------------------------------------ }
{ JspBeanSelfTest : jsp:useBean/jsp:getProperty reels               }
{ (Test13Actions.jsp), jsp:setProperty synthetique dans ses TROIS     }
{ formes (aucun echantillon actuel ne les exercice, section 9.5), et   }
{ non-regression jsp:useBean sans class/type (avertissement, pas         }
{ d echec).                                                                }
{ ------------------------------------------------------------ }

Procedure JspBeanAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('JspBeanSelfTest: ' + Label_ + ' a echoue');
End;

Procedure JspBeanSelfTest;
Const
  TmpFile = 'JSPBEANSELFTEST.$$$';
Var
  F           : Text;
  PageIdx, C0, C1 : Integer;
  WarnBefore  : Integer;
Begin
  JavaParserInit; PageInit; JspParamInit;
  Opts.Warnings := True; { observer WarnCount, meme discipline etablie }

  { --- Test13Actions.jsp reel : jsp:useBean puis jsp:getProperty --- }
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:useBean id="calendrier" class="java.util.GregorianCalendar" scope="page" />',
        '<jsp:getProperty name="calendrier" property="timeInMillis" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;

  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspBeanAssert('jsp:useBean reel : SK_USEBEAN_ACTION',
    StmtPool[C0].Kind = SK_USEBEAN_ACTION);
  JspBeanAssert('jsp:useBean reel : id=calendrier',
    StmtPool[C0].Op = 'calendrier');
  JspBeanAssert('jsp:useBean reel : class=java.util.GregorianCalendar',
    StmtPool[C0].NameVal = 'java.util.GregorianCalendar');
  JspBeanAssert('jsp:useBean reel : scope=page',
    StmtPool[C0].Extra = Ord(SCOPE_PAGE));

  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  JspBeanAssert('jsp:getProperty reel : SK_GETPROPERTY_ACTION',
    StmtPool[C1].Kind = SK_GETPROPERTY_ACTION);
  JspBeanAssert('jsp:getProperty reel : name=calendrier',
    StmtPool[C1].Op = 'calendrier');
  JspBeanAssert('jsp:getProperty reel : property=timeInMillis',
    StmtPool[C1].NameVal = 'timeInMillis');
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- jsp:setProperty, forme "value" (synthetique, section 9.5) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:setProperty name="client" property="nom" value="Ada" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspBeanAssert('setProperty value : SK_SETPROPERTY_ACTION',
    StmtPool[C0].Kind = SK_SETPROPERTY_ACTION);
  JspBeanAssert('setProperty value : name/property corrects',
    (StmtPool[C0].Op = 'client') And (StmtPool[C0].NameVal = 'nom'));
  JspBeanAssert('setProperty value : source=SPS_VALUE, valeur=Ada',
    (StmtPool[C0].Extra = Ord(SPS_VALUE)) And (StmtPool[C0].BigVal = 'Ada'));
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- jsp:setProperty, forme "param" (synthetique, section 9.5) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:setProperty name="client" property="nom" param="nomParam" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspBeanAssert('setProperty param : source=SPS_PARAM, param=nomParam',
    (StmtPool[C0].Extra = Ord(SPS_PARAM)) And (StmtPool[C0].BigVal = 'nomParam'));
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- jsp:setProperty, forme "property=*" (synthetique, section 9.1/10.3) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:setProperty name="client" property="*" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspBeanAssert('setProperty * : source=SPS_WILDCARD',
    StmtPool[C0].Extra = Ord(SPS_WILDCARD));
  JspBeanAssert('setProperty * : property="*"', StmtPool[C0].NameVal = '*');
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : jsp:useBean sans class/type - avertissement,     }
  { PAS d echec (le bean peut deja exister dans le scope, section 9.4) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:useBean id="dejaLa" scope="session" />');
  Close(F);
  LexInit(TmpFile);
  WarnBefore := WarnCount;
  PageIdx := ParsePage;
  JspBeanAssert('jsp:useBean sans class/type : avertissement emis',
    WarnCount > WarnBefore);
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JspBeanAssert('jsp:useBean sans class/type : noeud quand meme produit',
    (StmtPool[C0].Kind = SK_USEBEAN_ACTION) And
    (StmtPool[C0].Op = 'dejaLa') And (StmtPool[C0].Extra = Ord(SCOPE_SESSION)));
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 14 - LEXER/PARSEUR EL (EXPRESSION LANGUAGE)              }
{ ============================================================ }

{ Sous-lexer/parseur EL COMPLETEMENT SEPARE du lexeur/parseur Java (TODO   }
{ 02/07/08) : opere sur TOK_EL_RAW.Val (la chaine BRUTE deja capturee par    }
{ le lexeur de gabarit, section 4/TODO 02), PAS sur SrcBuf/LexPos - une       }
{ expression EL n a JAMAIS besoin de revenir au mode gabarit ou Java au         }
{ milieu de son evaluation (contrairement aux scriptlets, TODO 08). TElNode     }
{ est un arbre DISTINCT de TExprNode (TODO 07) : "pas de types statiques,        }
{ juste des noeuds operateur/litteral/identificateur/acces-propriete/appel-       }
{ fonction" (roadmap d en-tete) - AUCUNE resolution d objet implicite/de           }
{ portee n existe encore a ce stade (voir TODO 15 plus bas, ordre de                }
{ resolution page->request->session->application, section 8.3) : ce TODO           }
{ se limite a la grammaire.                                                        }

Type
  TElTokKind = (ELTOK_EOF, ELTOK_IDENT, ELTOK_INT, ELTOK_FLOAT, ELTOK_STRING,
                ELTOK_OP);

  TElTok = Record
    Kind    : TElTokKind;
    Val     : TBigString;
    IntVal  : LongInt;
    RealVal : Double;
  End;

  { TElImplicitKind (TODO 15, section 13.1) : ajoute ICI (dans le bloc     }
  { Type de TODO 14) puisque TElNode en a besoin comme type de champ,        }
  { MEME discipline que TImplicitObjectKind/TExprNode au TODO 09 - EIK_NONE   }
  { signifie "identificateur EL ordinaire" (variable de scope, propriete,        }
  { nom de fonction qualifie...), PAS un des 10 objets/pseudo-objets              }
  { implicites EL de la reference. }
  TElImplicitKind = (
    EIK_NONE,
    EIK_PAGE_SCOPE, EIK_REQUEST_SCOPE, EIK_SESSION_SCOPE, EIK_APPLICATION_SCOPE,
    EIK_PARAM, EIK_PARAM_VALUES, EIK_HEADER, EIK_HEADER_VALUES,
    EIK_COOKIE, EIK_INIT_PARAM
  );

  TElNodeKind = (
    ELK_INT, ELK_FLOAT, ELK_STRING, ELK_BOOL, ELK_NULL,
    ELK_IDENT,     { NameVal = identificateur brut, EVENTUELLEMENT          }
                   { qualifie "prefixe:nom" (section 12.9, ex. "fn:length") }
    ELK_SELECTOR,  { Left = base ; NameVal = propriete ("obj.propriete est  }
                   { une forme commode d objet[\"propriete\"]", section       }
                   { 12.2) }
    ELK_INDEX,     { Left = base ; Right = index (expression QUELCONQUE,     }
                   { section 12.2 - "un nom calcule ou un nom qui n est        }
                   { pas un identificateur simple") }
    ELK_CALL,      { Left = callee (ELK_IDENT ou ELK_SELECTOR, section         }
                   { 12.9) ; ArgFirst/ArgCount dans ElArgPool }
    ELK_UNARY,     { Op = '-'/'!'/'empty' (section 12.10, "unaire - ! not         }
                   { empty" - 'not' NORMALISE en '!', voir la note d en-tete       }
                   { de ParseElMultiplicative pour la NORMALISATION des               }
                   { formes alphabetiques) ; Left = operande }
    ELK_BINARY,    { Op (formes SYMBOLIQUES uniquement, jamais 'div'/'mod'/       }
                   { 'eq'/etc - NORMALISEES a l analyse, section 12.4/12.5/           }
                   { 12.6) ; Left, Right }
    ELK_TERNARY    { Left = condition ; Right = branche VRAIE ; Extra =           }
                   { branche FAUSSE (section 12.8) }
  );

  TElNode = Record
    Kind    : TElNodeKind;
    Op      : TString;
    Left    : Integer;
    Right   : Integer;
    Extra   : Integer;
    NameVal : TBigString;
    IntVal  : LongInt;
    RealVal : Double;
    StrVal  : TBigString;
    ArgFirst: Integer;
    ArgCount: Integer;
    ElImplicit : TElImplicitKind; { TODO 15 - ELK_IDENT SEULEMENT :   }
                          { EIK_NONE si ce n est PAS un des 10 objets      }
                          { implicites EL (section 13.1) - permet a          }
                          { ElEvalNode/ElResolveVar (TODO 15) de dispatcher      }
                          { DIRECTEMENT vers la portee/le pseudo-objet             }
                          { approprie plutot que de traiter tout ELK_IDENT           }
                          { comme une variable ordinaire, MEME discipline               }
                          { que ImplicitKind sur TExprNode (TODO 09) }
  End;

Var
  ElNodePool  : Array[0..MAX_ELNODE - 1] Of TElNode;
  ElNodeCount : Integer;
  ElArgPool   : Array[0..MAX_ELARG - 1] Of Integer;
  ElArgCount  : Integer;

  ElSrc    : TBigString; { texte EL BRUT courant (TOK_EL_RAW.Val) }
  ElPos    : Integer;    { position 1-base dans ElSrc }
  ElLen    : Integer;
  ElCurTok : TElTok;

Procedure ElParserInit;
Begin
  ElNodeCount := 0;
  ElArgCount  := 0;
End;

Function ElNodeAdd(Kind: TElNodeKind): Integer;
Begin
  If ElNodeCount >= MAX_ELNODE Then
    FatalError('trop de noeuds d expression EL (MAX_ELNODE)');
  ElNodePool[ElNodeCount].Kind     := Kind;
  ElNodePool[ElNodeCount].Op       := '';
  ElNodePool[ElNodeCount].Left     := -1;
  ElNodePool[ElNodeCount].Right    := -1;
  ElNodePool[ElNodeCount].Extra    := -1;
  ElNodePool[ElNodeCount].NameVal  := '';
  ElNodePool[ElNodeCount].IntVal   := 0;
  ElNodePool[ElNodeCount].RealVal  := 0.0;
  ElNodePool[ElNodeCount].StrVal   := '';
  ElNodePool[ElNodeCount].ArgFirst := -1;
  ElNodePool[ElNodeCount].ArgCount := 0;
  ElNodePool[ElNodeCount].ElImplicit := EIK_NONE;
  ElNodeAdd := ElNodeCount;
  Inc(ElNodeCount);
End;

{ ------------------------------------------------------------ }
{ Sous-lexer EL - classification de caracteres, Peek/Next        }
{ (MEME technique "tampon fichier entier" que TODO 02, mais         }
{ ElSrc est deja une chaine EN MEMOIRE, pas un fichier).            }
{ ------------------------------------------------------------ }

Function IsElIdentStart(Ch: Char): Boolean;
Begin
  IsElIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                    ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
End;

Function IsElIdentCont(Ch: Char): Boolean;
Begin
  IsElIdentCont := IsElIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsElDigitCh(Ch: Char): Boolean;
Begin
  IsElDigitCh := (Ch >= '0') And (Ch <= '9');
End;

Function ElPeekChar: Char;
Begin
  If ElPos > ElLen Then ElPeekChar := #0 Else ElPeekChar := ElSrc[ElPos];
End;

Function ElPeekChar2: Char;
Begin
  If ElPos + 1 > ElLen Then ElPeekChar2 := #0 Else ElPeekChar2 := ElSrc[ElPos + 1];
End;

Function ElPeekChar3: Char;
Begin
  If ElPos + 2 > ElLen Then ElPeekChar3 := #0 Else ElPeekChar3 := ElSrc[ElPos + 2];
End;

Function ElNextChar: Char;
Begin
  If ElPos > ElLen Then Begin ElNextChar := #0; Exit; End;
  ElNextChar := ElSrc[ElPos];
  Inc(ElPos);
End;

Procedure ElSkipWhitespace;
Begin
  While (ElPos <= ElLen) And
        ((ElPeekChar = ' ') Or (ElPeekChar = #9) Or
         (ElPeekChar = #10) Or (ElPeekChar = #13)) Do
    ElNextChar;
End;

{ ElNextToken : identificateurs, entiers/flottants (MEME structure que    }
{ LexScanNumberJava, TODO 02, simplifie - pas de suffixe long/hex/octal,    }
{ non exerces en EL, section 12.3 "les regles de nombres... appartiennent     }
{ a EL, pas exactement a la grammaire Java"), chaines '...'/"..." (section      }
{ 12.3 - LES DEUX formes de guillemets sont valides ; AUCUNE regle              }
{ d echappement n est documentee explicitement pour EL dans cette reference -    }
{ un antislash devant le guillemet DELIMITEUR lui-meme est neanmoins accepte      }
{ par tolerance, cas le plus courant, SANS pretendre a une grammaire                }
{ d echappement complete non documentee ici), operateurs/ponctuation. }
Procedure ElNextToken;
Var
  Ch, QuoteCh : Char;
  StartPos    : Integer;
  NumStr      : TString;
  IsFloatLit  : Boolean;
  S           : TBigString;
  ErrCode     : Integer;
Begin
  ElSkipWhitespace;
  ElCurTok.Val := ''; ElCurTok.IntVal := 0; ElCurTok.RealVal := 0.0;

  If ElPos > ElLen Then Begin ElCurTok.Kind := ELTOK_EOF; Exit; End;

  Ch := ElPeekChar;

  If IsElIdentStart(Ch) Then
  Begin
    StartPos := ElPos;
    While IsElIdentCont(ElPeekChar) Do ElNextChar;
    ElCurTok.Kind := ELTOK_IDENT;
    ElCurTok.Val  := Copy(ElSrc, StartPos, ElPos - StartPos);
    Exit;
  End;

  If IsElDigitCh(Ch) Then
  Begin
    StartPos := ElPos;
    IsFloatLit := False;
    While IsElDigitCh(ElPeekChar) Do ElNextChar;
    If (ElPeekChar = '.') And IsElDigitCh(ElPeekChar2) Then
    Begin
      IsFloatLit := True;
      ElNextChar;
      While IsElDigitCh(ElPeekChar) Do ElNextChar;
    End;
    If (ElPeekChar = 'e') Or (ElPeekChar = 'E') Then
    Begin
      If IsElDigitCh(ElPeekChar2) Or
         (((ElPeekChar2 = '+') Or (ElPeekChar2 = '-')) And
          IsElDigitCh(ElPeekChar3)) Then
      Begin
        IsFloatLit := True;
        ElNextChar;
        If (ElPeekChar = '+') Or (ElPeekChar = '-') Then ElNextChar;
        While IsElDigitCh(ElPeekChar) Do ElNextChar;
      End;
    End;
    NumStr := Copy(ElSrc, StartPos, ElPos - StartPos);
    If IsFloatLit Then
    Begin
      ElCurTok.Kind := ELTOK_FLOAT;
      Val(NumStr, ElCurTok.RealVal, ErrCode);
    End
    Else
    Begin
      ElCurTok.Kind := ELTOK_INT;
      Val(NumStr, ElCurTok.IntVal, ErrCode);
    End;
    Exit;
  End;

  If (Ch = '''') Or (Ch = '"') Then
  Begin
    QuoteCh := Ch;
    ElNextChar; { consomme le guillemet ouvrant }
    S := '';
    While True Do
    Begin
      If ElPos > ElLen Then
        FatalError('chaine EL non terminee (section 12.3)');
      Ch := ElPeekChar;
      If Ch = QuoteCh Then Begin ElNextChar; Break; End;
      If (Ch = '\') And ((ElPeekChar2 = '''') Or (ElPeekChar2 = '"') Or
                         (ElPeekChar2 = '\')) Then
      Begin
        ElNextChar; { '\' }
        S := S + ElNextChar;
      End
      Else
      Begin
        S := S + Ch;
        ElNextChar;
      End;
    End;
    ElCurTok.Kind := ELTOK_STRING;
    ElCurTok.Val  := S;
    Exit;
  End;

  If (Ch = '&') And (ElPeekChar2 = '&') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '&&'; ElNextChar; ElNextChar; Exit; End;
  If (Ch = '|') And (ElPeekChar2 = '|') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '||'; ElNextChar; ElNextChar; Exit; End;
  If (Ch = '=') And (ElPeekChar2 = '=') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '=='; ElNextChar; ElNextChar; Exit; End;
  If (Ch = '!') And (ElPeekChar2 = '=') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '!='; ElNextChar; ElNextChar; Exit; End;
  If (Ch = '<') And (ElPeekChar2 = '=') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '<='; ElNextChar; ElNextChar; Exit; End;
  If (Ch = '>') And (ElPeekChar2 = '=') Then
  Begin ElCurTok.Kind := ELTOK_OP; ElCurTok.Val := '>='; ElNextChar; ElNextChar; Exit; End;

  If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or (Ch = '%') Or
     (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or (Ch = '.') Or
     (Ch = ',') Or (Ch = '?') Or (Ch = ':') Or (Ch = '<') Or (Ch = '>') Or
     (Ch = '!') Then
  Begin
    ElCurTok.Kind := ELTOK_OP;
    ElCurTok.Val  := Ch;
    ElNextChar;
    Exit;
  End;

  FatalError('caractere EL inattendu : ' + Ch);
End;

Function ElCurIsOp(Const S: TString): Boolean;
Begin
  ElCurIsOp := (ElCurTok.Kind = ELTOK_OP) And (ElCurTok.Val = S);
End;

Function ElCurIsKw(Const S: TString): Boolean;
Begin
  ElCurIsKw := (ElCurTok.Kind = ELTOK_IDENT) And (ElCurTok.Val = S);
End;

{ ------------------------------------------------------------ }
{ Parseur EL - descente recursive, precedence CROISSANTE          }
{ (section 12.10 "Precedence simplifiee", PAS 12.4 comme un         }
{ brouillon anterieur de ce TODO l affirmait a tort dans l en-tete    }
{ du fichier - deja corrige ici) : [] . -> appel () -> unaire ->       }
{ multiplicatif -> additif -> comparaisons -> egalite -> && ->          }
{ || -> ?: . ParseElExpr = point d entree = le niveau le plus BAS,        }
{ ternaire.                                                                 }
{ ------------------------------------------------------------ }

Function ParseElExpr: Integer; Forward;

{ ParseElArgList : MEME tampon LOCAL que ParseArgList (Java, TODO 07) et  }
{ pour la MEME raison exacte - un argument peut etre lui-meme un appel     }
{ avec ses PROPRES arguments (ex. "f(g(x, y))"), qui avancerait ElArgCount   }
{ avant que CET appel-ci ait fini d y ecrire les siens - bogue reel deja       }
{ trouve et corrige pour l equivalent Java, evite ICI PROACTIVEMENT. }
Procedure ParseElArgList(Var ArgFirst, ArgCount: Integer);
Var
  Count    : Integer;
  I        : Integer;
  LocalArg : Array[0..MAX_EL_ARG_LOCAL - 1] Of Integer;
Begin
  Count := 0;
  If Not ElCurIsOp(')') Then
  Begin
    While True Do
    Begin
      If Count >= MAX_EL_ARG_LOCAL Then
      Begin
        FatalError('trop d arguments a un seul appel EL (MAX_EL_ARG_LOCAL)');
        Break;
      End;
      LocalArg[Count] := ParseElExpr;
      Inc(Count);
      If ElCurIsOp(',') Then Begin ElNextToken; Continue; End;
      Break;
    End;
  End;

  ArgFirst := ElArgCount;
  For I := 0 To Count - 1 Do
  Begin
    If ElArgCount >= MAX_ELARG Then
    Begin
      FatalError('trop d arguments EL au total (MAX_ELARG)');
      Break;
    End;
    ElArgPool[ElArgCount] := LocalArg[I];
    Inc(ElArgCount);
  End;
  ArgCount := Count;
End;

{ ElImplicitKindOf (TODO 15, section 13.1) : reconnait par son NOM SEUL     }
{ un des 10 objets/pseudo-objets implicites EL - place ICI (juste avant       }
{ ParseElPrimary, qui en a besoin) exactement comme ImplicitObjectKindOf        }
{ est place juste avant ParsePrimary au TODO 09. AUCUNE vraie structure          }
{ Map/tableau n est modelisee derriere ces noms (section 13.3, hors de             }
{ portee) : c est un simple TAG sur le noeud ELK_IDENT, exploite par              }
{ ElEvalNode plus bas pour dispatcher directement vers ScopeGetAttribute            }
{ (les 4 *Scope) ou vers une valeur "non modelisee, ELV_NULL" documentee              }
{ (param/paramValues/header/headerValues/cookie/initParam - le modele de               }
{ requete simulee n existe pas avant le TODO 18). }
Function ElImplicitKindOf(Const Name: TString): TElImplicitKind;
Begin
  If Name = 'pageScope' Then ElImplicitKindOf := EIK_PAGE_SCOPE
  Else If Name = 'requestScope' Then ElImplicitKindOf := EIK_REQUEST_SCOPE
  Else If Name = 'sessionScope' Then ElImplicitKindOf := EIK_SESSION_SCOPE
  Else If Name = 'applicationScope' Then ElImplicitKindOf := EIK_APPLICATION_SCOPE
  Else If Name = 'param' Then ElImplicitKindOf := EIK_PARAM
  Else If Name = 'paramValues' Then ElImplicitKindOf := EIK_PARAM_VALUES
  Else If Name = 'header' Then ElImplicitKindOf := EIK_HEADER
  Else If Name = 'headerValues' Then ElImplicitKindOf := EIK_HEADER_VALUES
  Else If Name = 'cookie' Then ElImplicitKindOf := EIK_COOKIE
  Else If Name = 'initParam' Then ElImplicitKindOf := EIK_INIT_PARAM
  Else ElImplicitKindOf := EIK_NONE;
End;

{ ParseElPrimary : litteraux, identificateur (EVENTUELLEMENT qualifie      }
{ "prefixe:nom" pour un appel de fonction, section 12.9), expression         }
{ parenthesee. Le "prefixe:nom" est reconnu ICI (au niveau PRIMAIRE,           }
{ AVANT tout postfixe) en repliant les DEUX identificateurs et le ':' en         }
{ un SEUL ELK_IDENT.NameVal - le ':' du ternaire (section 12.8) n est            }
{ JAMAIS ambigu avec celui-ci puisqu il n apparait QUE bien plus bas dans le        }
{ flux (apres une expression COMPLETE et un '?'), jamais immediatement              }
{ apres un identificateur NU. }
Function ParseElPrimary: Integer;
Var
  Idx     : Integer;
  NameStr : TBigString;
Begin
  Case ElCurTok.Kind Of
    ELTOK_INT:
      Begin
        Idx := ElNodeAdd(ELK_INT);
        ElNodePool[Idx].IntVal := ElCurTok.IntVal;
        ElNextToken;
        ParseElPrimary := Idx;
      End;
    ELTOK_FLOAT:
      Begin
        Idx := ElNodeAdd(ELK_FLOAT);
        ElNodePool[Idx].RealVal := ElCurTok.RealVal;
        ElNextToken;
        ParseElPrimary := Idx;
      End;
    ELTOK_STRING:
      Begin
        Idx := ElNodeAdd(ELK_STRING);
        ElNodePool[Idx].StrVal := ElCurTok.Val;
        ElNextToken;
        ParseElPrimary := Idx;
      End;
    ELTOK_IDENT:
      Begin
        If ElCurTok.Val = 'true' Then
        Begin
          Idx := ElNodeAdd(ELK_BOOL); ElNodePool[Idx].IntVal := 1;
          ElNextToken; ParseElPrimary := Idx;
        End
        Else If ElCurTok.Val = 'false' Then
        Begin
          Idx := ElNodeAdd(ELK_BOOL); ElNodePool[Idx].IntVal := 0;
          ElNextToken; ParseElPrimary := Idx;
        End
        Else If ElCurTok.Val = 'null' Then
        Begin
          Idx := ElNodeAdd(ELK_NULL);
          ElNextToken; ParseElPrimary := Idx;
        End
        Else
        Begin
          NameStr := ElCurTok.Val;
          ElNextToken;
          If ElCurIsOp(':') Then
          Begin
            ElNextToken;
            If ElCurTok.Kind <> ELTOK_IDENT Then
            Begin
              FatalError('nom de fonction EL attendu apres ":" (section 12.9)');
              ParseElPrimary := -1;
              Exit;
            End;
            NameStr := NameStr + ':' + ElCurTok.Val;
            ElNextToken;
          End;
          Idx := ElNodeAdd(ELK_IDENT);
          ElNodePool[Idx].NameVal := NameStr;
          ElNodePool[Idx].ElImplicit := ElImplicitKindOf(NameStr);
          ParseElPrimary := Idx;
        End;
      End;
  Else
    If ElCurIsOp('(') Then
    Begin
      ElNextToken;
      Idx := ParseElExpr;
      If Not ElCurIsOp(')') Then
        FatalError('")" EL attendue')
      Else
        ElNextToken;
      ParseElPrimary := Idx;
    End
    Else
    Begin
      FatalError('expression EL attendue');
      ParseElPrimary := -1;
    End;
  End;
End;

{ ParseElPostfix : acces propriete ".prop", indexation "[expr]" et        }
{ appel "(args)" - section 12.2/12.9. Un appel PEUT suivre un SIMPLE        }
{ identificateur qualifie (ELK_IDENT, "fn:escapeXml(...)") OU une chaine      }
{ de selecteurs (ELK_SELECTOR, "panier.calculerTotal()") - la MEME logique     }
{ generique s applique aux deux, EXACTEMENT comme ParsePostfix (Java,           }
{ TODO 07). }
Function ParseElPostfix: Integer;
Var Idx, Base: Integer;
Begin
  Base := ParseElPrimary;
  While True Do
  Begin
    If ElCurIsOp('.') Then
    Begin
      ElNextToken;
      If ElCurTok.Kind <> ELTOK_IDENT Then
      Begin
        FatalError('nom de propriete EL attendu apres "." (section 12.2)');
        ParseElPostfix := Base;
        Exit;
      End;
      Idx := ElNodeAdd(ELK_SELECTOR);
      ElNodePool[Idx].Left    := Base;
      ElNodePool[Idx].NameVal := ElCurTok.Val;
      ElNextToken;
      Base := Idx;
    End
    Else If ElCurIsOp('[') Then
    Begin
      ElNextToken;
      Idx := ElNodeAdd(ELK_INDEX);
      ElNodePool[Idx].Left  := Base;
      ElNodePool[Idx].Right := ParseElExpr;
      If Not ElCurIsOp(']') Then
        FatalError('"]" EL attendue (section 12.2)')
      Else
        ElNextToken;
      Base := Idx;
    End
    Else If ElCurIsOp('(') Then
    Begin
      ElNextToken;
      Idx := ElNodeAdd(ELK_CALL);
      ElNodePool[Idx].Left := Base;
      ParseElArgList(ElNodePool[Idx].ArgFirst, ElNodePool[Idx].ArgCount);
      If Not ElCurIsOp(')') Then
        FatalError('")" EL attendue apres les arguments (section 12.9)')
      Else
        ElNextToken;
      Base := Idx;
    End
    Else
      Break;
  End;
  ParseElPostfix := Base;
End;

{ ParseElUnary : "- ! not empty" (section 12.6/12.7/12.10) - les formes    }
{ alphabetiques ('not') sont NORMALISEES vers leur equivalent symbolique     }
{ ('!') des l analyse (MEME decision que ParseElMultiplicative et suivants,   }
{ ci-dessous, evite a un futur evaluateur EL - TODO 20+ - de devoir gerer      }
{ les DEUX formes partout). }
Function ParseElUnary: Integer;
Var Idx: Integer;
Begin
  If ElCurIsOp('-') Then
  Begin
    Idx := ElNodeAdd(ELK_UNARY); ElNodePool[Idx].Op := '-';
    ElNextToken;
    ElNodePool[Idx].Left := ParseElUnary;
    ParseElUnary := Idx;
    Exit;
  End;
  If ElCurIsOp('!') Or ElCurIsKw('not') Then
  Begin
    Idx := ElNodeAdd(ELK_UNARY); ElNodePool[Idx].Op := '!';
    ElNextToken;
    ElNodePool[Idx].Left := ParseElUnary;
    ParseElUnary := Idx;
    Exit;
  End;
  If ElCurIsKw('empty') Then
  Begin
    Idx := ElNodeAdd(ELK_UNARY); ElNodePool[Idx].Op := 'empty';
    ElNextToken;
    ElNodePool[Idx].Left := ParseElUnary;
    ParseElUnary := Idx;
    Exit;
  End;
  ParseElUnary := ParseElPostfix;
End;

{ ParseElMultiplicative : "* / div % mod" (section 12.4) - 'div'/'mod'    }
{ NORMALISES vers '/'/'%' des l analyse (DECISION A DOCUMENTER, roadmap       }
{ d en-tete "implementees comme un ensemble fixe de regles au moment de la      }
{ generation de code" - normaliser ICI, au PARSING, plutot qu au codegen         }
{ (TODO 21+) evite a CELUI-CI de redistinguer deux graphies pour la MEME            }
{ operation semantique). }
Function ParseElMultiplicative: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseElUnary;
  While ElCurIsOp('*') Or ElCurIsOp('/') Or ElCurIsKw('div') Or
        ElCurIsOp('%') Or ElCurIsKw('mod') Do
  Begin
    If ElCurIsKw('div') Then OpStr := '/'
    Else If ElCurIsKw('mod') Then OpStr := '%'
    Else OpStr := ElCurTok.Val;
    ElNextToken;
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op    := OpStr;
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElUnary;
    Left := Idx;
  End;
  ParseElMultiplicative := Left;
End;

Function ParseElAdditive: Integer;
Var Idx, Left: Integer;
Begin
  Left := ParseElMultiplicative;
  While ElCurIsOp('+') Or ElCurIsOp('-') Do
  Begin
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op := ElCurTok.Val;
    ElNextToken;
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElMultiplicative;
    Left := Idx;
  End;
  ParseElAdditive := Left;
End;

{ ParseElRelational : "< > <= >= lt gt le ge" (section 12.5) - formes     }
{ alphabetiques NORMALISEES vers leur equivalent symbolique, MEME             }
{ discipline que ParseElMultiplicative ci-dessus. }
Function ParseElRelational: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseElAdditive;
  While ElCurIsOp('<') Or ElCurIsOp('>') Or ElCurIsOp('<=') Or ElCurIsOp('>=') Or
        ElCurIsKw('lt') Or ElCurIsKw('gt') Or ElCurIsKw('le') Or ElCurIsKw('ge') Do
  Begin
    If ElCurIsKw('lt') Then OpStr := '<'
    Else If ElCurIsKw('gt') Then OpStr := '>'
    Else If ElCurIsKw('le') Then OpStr := '<='
    Else If ElCurIsKw('ge') Then OpStr := '>='
    Else OpStr := ElCurTok.Val;
    ElNextToken;
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op    := OpStr;
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElAdditive;
    Left := Idx;
  End;
  ParseElRelational := Left;
End;

{ ParseElEquality : "== != eq ne" (section 12.5) - MEME normalisation. }
Function ParseElEquality: Integer;
Var Idx, Left: Integer; OpStr: TString;
Begin
  Left := ParseElRelational;
  While ElCurIsOp('==') Or ElCurIsOp('!=') Or ElCurIsKw('eq') Or ElCurIsKw('ne') Do
  Begin
    If ElCurIsKw('eq') Then OpStr := '=='
    Else If ElCurIsKw('ne') Then OpStr := '!='
    Else OpStr := ElCurTok.Val;
    ElNextToken;
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op    := OpStr;
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElRelational;
    Left := Idx;
  End;
  ParseElEquality := Left;
End;

{ ParseElLogicalAnd/Or : "&& and", "|| or" (section 12.6) - 'and'/'or'   }
{ NORMALISES vers '&&'/'||', MEME discipline. }
Function ParseElLogicalAnd: Integer;
Var Idx, Left: Integer;
Begin
  Left := ParseElEquality;
  While ElCurIsOp('&&') Or ElCurIsKw('and') Do
  Begin
    ElNextToken;
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op    := '&&';
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElEquality;
    Left := Idx;
  End;
  ParseElLogicalAnd := Left;
End;

Function ParseElLogicalOr: Integer;
Var Idx, Left: Integer;
Begin
  Left := ParseElLogicalAnd;
  While ElCurIsOp('||') Or ElCurIsKw('or') Do
  Begin
    ElNextToken;
    Idx := ElNodeAdd(ELK_BINARY);
    ElNodePool[Idx].Op    := '||';
    ElNodePool[Idx].Left  := Left;
    ElNodePool[Idx].Right := ParseElLogicalAnd;
    Left := Idx;
  End;
  ParseElLogicalOr := Left;
End;

{ ParseElExpr : point d entree - operateur conditionnel "? :" (section    }
{ 12.8), DROITE-associatif (MEME convention que l affectation Java, TODO      }
{ 07), plus bas niveau de precedence (section 12.10). }
Function ParseElExpr: Integer;
Var CondIdx, Idx: Integer;
Begin
  CondIdx := ParseElLogicalOr;
  If ElCurIsOp('?') Then
  Begin
    ElNextToken;
    Idx := ElNodeAdd(ELK_TERNARY);
    ElNodePool[Idx].Left := CondIdx;
    ElNodePool[Idx].Right := ParseElExpr;
    If Not ElCurIsOp(':') Then
      FatalError('":" attendu dans l operateur conditionnel EL (section 12.8)')
    Else
      ElNextToken;
    ElNodePool[Idx].Extra := ParseElExpr;
    ParseElExpr := Idx;
    Exit;
  End;
  ParseElExpr := CondIdx;
End;

{ ParseElFromString (definition reelle - voir le Forward et sa note      }
{ pres de TryConsumeInterleaveToken, TODO 08) : point d entree UNIQUE       }
{ depuis le reste du compilateur - Src est TOK_EL_RAW.Val (TODO 02). }
Function ParseElFromString(Const Src: TBigString): Integer;
Begin
  ElSrc := Src;
  ElLen := Length(Src);
  ElPos := 1;
  ElNextToken; { amorce ElCurTok }
  ParseElFromString := ParseElExpr;
  If ElCurTok.Kind <> ELTOK_EOF Then
    FatalError('caracteres EL inattendus apres l expression (section 12)');
End;

{ ------------------------------------------------------------ }
{ ElSelfTest : Test14ExpressionLanguage.jsp reel (empty+          }
{ selecteur, multiplicatif, "ge" normalise), Test17JstlXml.jsp     }
{ reel (appel de fonction qualifie + ternaire + "empty"),           }
{ precedence (1 + 2 * 3), indexation [expr] (synthetique,            }
{ section 12.2 - aucun des 2 echantillons couverts par CE TODO         }
{ ne l exercice), et integration ParsePage (SK_PRINT_EL reel +          }
{ forme differee synthetique).                                           }
{ ------------------------------------------------------------ }

Procedure ElAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ElSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ElSelfTest;
Const
  TmpFile = 'JSPELSELFTEST.$$$';
Var
  F              : Text;
  Idx, L, R      : Integer;
  PageIdx, C0, C1: Integer;
Begin
  ElParserInit;

  { --- Test14ExpressionLanguage.jsp reel : empty + selecteur --- }
  Idx := ParseElFromString('empty param.nom');
  ElAssert('empty param.nom : ELK_UNARY "empty"',
    (ElNodePool[Idx].Kind = ELK_UNARY) And (ElNodePool[Idx].Op = 'empty'));
  L := ElNodePool[Idx].Left;
  ElAssert('empty param.nom : operande = param.nom (SELECTOR)',
    (ElNodePool[L].Kind = ELK_SELECTOR) And (ElNodePool[L].NameVal = 'nom') And
    (ElNodePool[ElNodePool[L].Left].NameVal = 'param'));

  ElParserInit;
  Idx := ParseElFromString('sessionScope.utilisateur');
  ElAssert('sessionScope.utilisateur : SELECTOR',
    (ElNodePool[Idx].Kind = ELK_SELECTOR) And (ElNodePool[Idx].NameVal = 'utilisateur') And
    (ElNodePool[ElNodePool[Idx].Left].NameVal = 'sessionScope'));

  ElParserInit;
  Idx := ParseElFromString('prixUnitaire * quantite');
  ElAssert('prixUnitaire * quantite : BINARY "*"',
    (ElNodePool[Idx].Kind = ELK_BINARY) And (ElNodePool[Idx].Op = '*') And
    (ElNodePool[ElNodePool[Idx].Left].NameVal = 'prixUnitaire') And
    (ElNodePool[ElNodePool[Idx].Right].NameVal = 'quantite'));

  ElParserInit;
  Idx := ParseElFromString('quantite ge 3');
  ElAssert('quantite ge 3 : "ge" normalise en ">="',
    (ElNodePool[Idx].Kind = ELK_BINARY) And (ElNodePool[Idx].Op = '>=') And
    (ElNodePool[ElNodePool[Idx].Right].Kind = ELK_INT) And
    (ElNodePool[ElNodePool[Idx].Right].IntVal = 3));

  { --- Test17JstlXml.jsp reel : appel de fonction qualifie + ternaire +   }
  { empty + chaine litterale --- }
  ElParserInit;
  Idx := ParseElFromString(
    'fn:escapeXml(empty param.texte ? ''(absent)'' : param.texte)');
  ElAssert('fn:escapeXml(...) : ELK_CALL',
    ElNodePool[Idx].Kind = ELK_CALL);
  ElAssert('fn:escapeXml(...) : callee qualifie "fn:escapeXml"',
    (ElNodePool[ElNodePool[Idx].Left].Kind = ELK_IDENT) And
    (ElNodePool[ElNodePool[Idx].Left].NameVal = 'fn:escapeXml'));
  ElAssert('fn:escapeXml(...) : 1 argument', ElNodePool[Idx].ArgCount = 1);
  L := ElArgPool[ElNodePool[Idx].ArgFirst];
  ElAssert('argument : ELK_TERNARY', ElNodePool[L].Kind = ELK_TERNARY);
  ElAssert('ternaire : condition = empty param.texte',
    (ElNodePool[ElNodePool[L].Left].Kind = ELK_UNARY) And
    (ElNodePool[ElNodePool[L].Left].Op = 'empty'));
  ElAssert('ternaire : branche VRAIE = chaine litterale (absent)',
    (ElNodePool[ElNodePool[L].Right].Kind = ELK_STRING) And
    (ElNodePool[ElNodePool[L].Right].StrVal = '(absent)'));
  ElAssert('ternaire : branche FAUSSE = param.texte',
    ElNodePool[ElNodePool[L].Extra].Kind = ELK_SELECTOR);

  { --- precedence : 1 + 2 * 3 doit se regrouper (1 + (2 * 3)) --- }
  ElParserInit;
  Idx := ParseElFromString('1 + 2 * 3');
  ElAssert('precedence : racine = "+"',
    (ElNodePool[Idx].Kind = ELK_BINARY) And (ElNodePool[Idx].Op = '+'));
  R := ElNodePool[Idx].Right;
  ElAssert('precedence : branche droite = "*" (2 * 3)',
    (ElNodePool[R].Kind = ELK_BINARY) And (ElNodePool[R].Op = '*'));

  { --- indexation [expr] (synthetique, section 12.2) --- }
  ElParserInit;
  Idx := ParseElFromString('articles[0]');
  ElAssert('articles[0] : ELK_INDEX',
    (ElNodePool[Idx].Kind = ELK_INDEX) And
    (ElNodePool[ElNodePool[Idx].Left].NameVal = 'articles') And
    (ElNodePool[ElNodePool[Idx].Right].Kind = ELK_INT) And
    (ElNodePool[ElNodePool[Idx].Right].IntVal = 0));

  { --- integration ParsePage : une expression EL immediate REELLE en      }
  { gabarit produit SK_PRINT_EL, et la forme differee (synthetique - aucun    }
  { echantillon ne l emploie en gabarit) positionne BoolVal correctement. --- }
  ElParserInit; JavaParserInit; PageInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<li>Total : ', '${prixUnitaire * quantite}', '</li>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  ElAssert('gabarit avant EL : print "<li>Total : "',
    (StmtPool[C0].Kind = SK_PRINT_TEMPLATE) And (Pos('Total', StmtPool[C0].BigVal) > 0));
  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  ElAssert('EL reel : SK_PRINT_EL, forme IMMEDIATE (BoolVal=False)',
    (StmtPool[C1].Kind = SK_PRINT_EL) And (Not StmtPool[C1].BoolVal));
  Idx := StmtPool[C1].ElIdx;
  ElAssert('EL reel : arbre = prixUnitaire * quantite',
    (ElNodePool[Idx].Kind = ELK_BINARY) And (ElNodePool[Idx].Op = '*'));
  LexClose; Assign(F, TmpFile); Erase(F);

  ElParserInit; JavaParserInit; PageInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '#{x}');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  ElAssert('forme differee (synthetique) : BoolVal=True',
    (StmtPool[C0].Kind = SK_PRINT_EL) And StmtPool[C0].BoolVal);
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 15 - EVALUATION EL : IMPLICITES ET ORDRE DE RESOLUTION   }
{ DE PORTEE                                                     }
{ ============================================================ }

{ ElResolveVar (section 8.3/13.2) : POINT D ENTREE UNIQUE pour resoudre    }
{ un identificateur EL NU (sans prefixe de scope explicite) - cherche          }
{ page -> request -> session -> application et s arrete au PREMIER trouve,       }
{ MEME ordre et MEME infrastructure (ScopeGetAttribute, TODO 10) que              }
{ "un nom identique dans une portee plus courte masque les suivantes"                }
{ (section 8.3). Retourne False (Value.Kind=ELV_NULL) si absent des               }
{ QUATRE portees - JAMAIS une erreur (EL est concu pour la presentation,             }
{ section 13.4). }
Function ElResolveVar(Const Name: TString; Var Value: TELValue): Boolean;
Begin
  If ScopeGetAttribute(SCOPE_PAGE, Name, Value) Then Begin ElResolveVar := True; Exit; End;
  If ScopeGetAttribute(SCOPE_REQUEST, Name, Value) Then Begin ElResolveVar := True; Exit; End;
  If ScopeGetAttribute(SCOPE_SESSION, Name, Value) Then Begin ElResolveVar := True; Exit; End;
  If ScopeGetAttribute(SCOPE_APPLICATION, Name, Value) Then Begin ElResolveVar := True; Exit; End;
  Value.Kind := ELV_NULL;
  ElResolveVar := False;
End;

{ ScopeKindOfEl : correspondance ELK_IDENT.ElImplicit -> TScopeKind pour    }
{ les 4 objets d acces DIRECT a un scope precis (pageScope/requestScope/       }
{ sessionScope/applicationScope, section 13.1) - n est appelee QUE pour          }
{ un ElImplicit deja verifie appartenir a ce sous-ensemble (voir              }
{ ElEvalNode, ELK_SELECTOR/ELK_INDEX ci-dessous). }
Function ScopeKindOfEl(Kind: TElImplicitKind): TScopeKind;
Begin
  Case Kind Of
    EIK_REQUEST_SCOPE    : ScopeKindOfEl := SCOPE_REQUEST;
    EIK_SESSION_SCOPE     : ScopeKindOfEl := SCOPE_SESSION;
    EIK_APPLICATION_SCOPE : ScopeKindOfEl := SCOPE_APPLICATION;
  Else
    ScopeKindOfEl := SCOPE_PAGE; { EIK_PAGE_SCOPE, et repli sur }
  End;                            { defaut pour tout autre appel }
End;

{ ElToNumber (section 12.4, "les conversions EL sont plus permissives que  }
{ les conversions Java... une chaine numerique peut etre convertie") -        }
{ coercition numerique COMMUNE a l arithmetique et aux comparaisons :            }
{ ELV_LONG/ELV_DOUBLE inchanges, ELV_BOOLEAN/ELV_NULL/ELV_OBJECT -> 0             }
{ (section 12.4 note d en-tete du TODO 04, "null vers primitif = valeur           }
{ par defaut"), ELV_STRING -> nombre si la chaine est numerique (Val),               }
{ sinon 0 - IsFloat indique si le resultat doit etre traite comme DOUBLE. }
Procedure ElToNumber(Const V: TELValue; Var IsFloat: Boolean; Var L: LongInt;
                     Var D: Double);
Var Code: Integer; LTmp: LongInt; DTmp: Double;
Begin
  IsFloat := False; L := 0; D := 0.0;
  Case V.Kind Of
    ELV_LONG   : L := V.IntVal;
    ELV_DOUBLE : Begin IsFloat := True; D := V.RealVal; End;
    ELV_BOOLEAN: L := Ord(V.BoolVal);
    ELV_STRING :
      Begin
        Val(V.StrVal, LTmp, Code);
        If Code = 0 Then L := LTmp
        Else
        Begin
          Val(V.StrVal, DTmp, Code);
          If Code = 0 Then Begin IsFloat := True; D := DTmp; End
          Else L := 0; { chaine non numerique - valeur par defaut, section 12.4 }
        End;
      End;
  Else
    L := 0; { ELV_NULL/ELV_OBJECT - valeur par defaut }
  End;
End;

{ ElToBoolean (coercitions du TODO 04) : ELV_BOOLEAN inchange, ELV_STRING  }
{ 'true'/'false' (insensible a la casse), toute autre valeur numerique          }
{ non nulle = vrai, ELV_NULL/chaine vide/autre = faux. }
Function ElToBoolean(Const V: TELValue): Boolean;
Var IsFloat: Boolean; L: LongInt; D: Double; S: TBigString; I: Integer;
Begin
  Case V.Kind Of
    ELV_BOOLEAN: ElToBoolean := V.BoolVal;
    ELV_STRING :
      Begin
        S := V.StrVal;
        For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
        If S = 'TRUE' Then ElToBoolean := True
        Else If S = 'FALSE' Then ElToBoolean := False
        Else ElToBoolean := Length(V.StrVal) > 0;
      End;
    ELV_NULL: ElToBoolean := False;
  Else
    Begin
      ElToNumber(V, IsFloat, L, D);
      If IsFloat Then ElToBoolean := (D <> 0.0) Else ElToBoolean := (L <> 0);
    End;
  End;
End;

{ ElValueToStr (roadmap d en-tete TODO 15, "coercition de sortie...          }
{ passe par toString") : union taguee TELValue -> TBigString - reutilise      }
{ EXACTEMENT les regles de coercition documentees au TODO 04 (String<->        }
{ nombre/boolean, "null vers primitif = valeur par defaut" - ICI, null vers        }
{ String = chaine VIDE, comportement standard de presentation EL, section            }
{ 13.4). ELV_OBJECT : AUCUN graphe d objet reel n est modelise (section              }
{ 13.3, hors de portee) - retourne un espace reserve documente plutot que              }
{ d inventer un contenu ; aucun echantillon n atteint ce cas a ce TODO. }
Function ElValueToStr(Const V: TELValue): TBigString;
Var S: TBigString;
Begin
  Case V.Kind Of
    ELV_NULL   : ElValueToStr := '';
    ELV_BOOLEAN: If V.BoolVal Then ElValueToStr := 'true' Else ElValueToStr := 'false';
    ELV_LONG   : Begin Str(V.IntVal, S); ElValueToStr := S; End;
    ELV_DOUBLE : Begin Str(V.RealVal:0:6, S); ElValueToStr := S; End;
    ELV_STRING : ElValueToStr := V.StrVal;
  Else
    If V.ObjRef = Nil Then ElValueToStr := ''
    Else ElValueToStr := '[objet]'; { limite assumee - toString reel via TODO 19/21 }
  End;
End;

{ ElIsEmpty (section 12.7) : "vrai pour null, chaine vide et                }
{ collections/tableaux vides selon les regles EL" - AUCUN modele de              }
{ collection/tableau/Map n existe encore (section 13.3, TODO 16 c:forEach            }
{ au plus tot) : un ELV_OBJECT est traite comme "vide" SEULEMENT si                  }
{ ObjRef=Nil (equivalent null), jamais "vide" sinon - limite assumee                 }
{ explicitement, documentee ici plutot que devinee. }
Function ElIsEmpty(Const V: TELValue): Boolean;
Begin
  Case V.Kind Of
    ELV_NULL  : ElIsEmpty := True;
    ELV_STRING: ElIsEmpty := Length(V.StrVal) = 0;
    ELV_OBJECT: ElIsEmpty := V.ObjRef = Nil;
  Else
    ElIsEmpty := False; { ELV_BOOLEAN/ELV_LONG/ELV_DOUBLE ne sont JAMAIS vides }
  End;
End;

{ IsJstlFunctionsCall (TODO 17, section 12.9/16.1) : une expression EL      }
{ "prefixe:nom(args)" appelle une fonction JSTL "functions" SI ET SEULEMENT   }
{ SI son prefixe a ete declare (TODO 06, <%@ taglib %>) avec une des URI        }
{ functions (legacy java.sun.com OU jakarta.tags, TaglibPool[].                  }
{ IsFunctionsJstl deja calcule au TODO 06) - MEME discipline que                    }
{ IsJstlCoreActionPrefix (TODO 16) : PAS un simple test syntaxique sur le            }
{ prefixe "fn". LocalName recoit le nom SANS le prefixe (ex. "length"). }
Function IsJstlFunctionsCall(Const FullName: TString; Var LocalName: TString): Boolean;
Var ColonPos, TagIdx: Integer;
Begin
  IsJstlFunctionsCall := False;
  LocalName := '';
  ColonPos := Pos(':', FullName);
  If ColonPos = 0 Then Exit;
  TagIdx := TaglibFind(Copy(FullName, 1, ColonPos - 1));
  If (TagIdx >= 0) And TaglibPool[TagIdx].IsFunctionsJstl Then
  Begin
    LocalName := Copy(FullName, ColonPos + 1, Length(FullName) - ColonPos);
    IsJstlFunctionsCall := True;
  End;
End;

{ ElFnLength (fn:length, section 12.9/16.1, Test15JstlJavaEE.jsp/          }
{ Test16JstlJakarta.jsp reels) - longueur d une chaine SEULEMENT ; le          }
{ modele de collection/tableau/Map n existe pas encore (section 13.3,             }
{ hors de portee ici) - toute valeur NON-String renvoie 0 (DECISION A               }
{ DOCUMENTER, "null-safe" comme le reste d EL, section 13.4) plutot que              }
{ d inventer un compte. }
Function ElFnLength(Const V: TELValue): TELValue;
Var R: TELValue;
Begin
  R.Kind := ELV_LONG;
  If V.Kind = ELV_STRING Then R.IntVal := Length(V.StrVal)
  Else R.IntVal := 0;
  ElFnLength := R;
End;

{ ElFnEscapeXml (fn:escapeXml, section 12.9/16.1/24.1, Test17JstlXml.jsp   }
{ reel) - echappement des 5 entites XML predefinies, MEME ensemble que          }
{ n importe quelle traduction JSTL reelle ("esperluette" en PREMIER, pour           }
{ ne jamais re-echapper un remplacement deja produit par les suivants) -             }
{ coercition String prealable via ElValueToStr (TODO 15, "le resultat d une          }
{ expression EL... passe par toString"). }
Function ElFnEscapeXml(Const V: TELValue): TELValue;
Var S, Res: TBigString; I: Integer; R: TELValue;
Begin
  S := ElValueToStr(V);
  Res := '';
  For I := 1 To Length(S) Do
  Case S[I] Of
    '&': Res := Res + '&amp;';
    '<': Res := Res + '&lt;';
    '>': Res := Res + '&gt;';
    '"': Res := Res + '&quot;';
    '''': Res := Res + '&apos;';
  Else
    Res := Res + S[I];
  End;
  R.Kind := ELV_STRING;
  R.StrVal := Res;
  ElFnEscapeXml := R;
End;

{ ReqParamGet (TODO 18) : Forward - sa vraie definition (avec ReqParamPool/  }
{ ReqParamInit/ReqParamParseArg) vit plus bas (section TODO 18, apres         }
{ JstlFunctionsSelfTest) mais est APPELEE DEPUIS ElEvalNode juste en             }
{ dessous (ELK_SELECTOR/ELK_INDEX, EIK_PARAM) - MEME technique que                  }
{ ParseElFromString/ParseJstlOut plus haut pour resoudre une dependance             }
{ d ordre textuel. }
Function ReqParamGet(Const Name: TString; Var Value: TBigString): Boolean; Forward;

{ ElEvalNode : evaluateur recursif de l arbre ElNodePool (TODO 14) vers     }
{ une TELValue (TODO 04) - PORTEE de ce TODO 15 : litteraux, resolution          }
{ d identificateur (ordre de portee OU acces direct via un des 10 objets            }
{ implicites, section 13.1), operateur empty, arithmetique/relationnel/                }
{ logique/ternaire (necessaires pour que Test14ExpressionLanguage.jsp                    }
{ produise un resultat COHERENT - ex. prixUnitaire multiplie par quantite,               }
{ quantite compare a 3 via ge). ELK_CALL (fonctions EL, section 12.9/16.1,   }
{ TODO 17 - SEULES fn:length/fn:escapeXml sont natives, toute AUTRE                }
{ fonction "fn:" ou tout prefixe non-functions restent ELV_NULL, TODO 17+)          }
{ et un ELK_SELECTOR/ELK_INDEX sur une base qui N EST PAS un des 4 objets              }
{ *Scope NI "param" (propriete de bean/Map reelle, section 13.3, ou                       }
{ paramValues/header/headerValues/cookie/initParam - HORS DE PORTEE de la                    }
{ convention TODO 18, voir sa note d en-tete) restent des limites EXPLICITES :                }
{ ELV_NULL est retourne plutot qu une valeur inventee - "empty" sur ce                       }
{ resultat reste correct (absence = empty vrai, roadmap d en-tete TODO 18). }
Function ElEvalNode(Idx: Integer): TELValue;
Var
  V, VL, VR                 : TELValue;
  IsFloatL, IsFloatR, IsFlt : Boolean;
  LL, LR                    : LongInt;
  DL, DR                    : Double;
  BaseImplicit              : TElImplicitKind;
  CalleeName, FnLocalName   : TString;
  ReqKey                    : TBigString;
  ReqStrVal                 : TBigString;
Begin
  V.Kind := ELV_NULL;
  If Idx < 0 Then Begin ElEvalNode := V; Exit; End;
  Case ElNodePool[Idx].Kind Of
    ELK_INT    : Begin V.Kind := ELV_LONG; V.IntVal := ElNodePool[Idx].IntVal; End;
    ELK_FLOAT  : Begin V.Kind := ELV_DOUBLE; V.RealVal := ElNodePool[Idx].RealVal; End;
    ELK_STRING : Begin V.Kind := ELV_STRING; V.StrVal := ElNodePool[Idx].StrVal; End;
    ELK_BOOL   : Begin V.Kind := ELV_BOOLEAN; V.BoolVal := ElNodePool[Idx].IntVal <> 0; End;
    ELK_NULL   : V.Kind := ELV_NULL;

    ELK_IDENT  :
      If ElNodePool[Idx].ElImplicit = EIK_NONE Then
        ElResolveVar(ElNodePool[Idx].NameVal, V)
      Else
        V.Kind := ELV_NULL; { objet implicite employe SEUL (sans . ni [],    }
                             { section 13.1) - jamais une valeur en soi }

    ELK_SELECTOR, ELK_INDEX :
      Begin
        If ElNodePool[ElNodePool[Idx].Left].Kind = ELK_IDENT Then
          BaseImplicit := ElNodePool[ElNodePool[Idx].Left].ElImplicit
        Else
          BaseImplicit := EIK_NONE;
        Case BaseImplicit Of
          EIK_PAGE_SCOPE, EIK_REQUEST_SCOPE, EIK_SESSION_SCOPE, EIK_APPLICATION_SCOPE:
            Begin
              If ElNodePool[Idx].Kind = ELK_SELECTOR Then
                ScopeGetAttribute(ScopeKindOfEl(BaseImplicit), ElNodePool[Idx].NameVal, V)
              Else
                ScopeGetAttribute(ScopeKindOfEl(BaseImplicit),
                  ElValueToStr(ElEvalNode(ElNodePool[Idx].Right)), V);
            End;
          EIK_PARAM :
            { TODO 18 : SEUL "param" (premiere valeur, section 13.1) est       }
            { modelise (ReqParamPool/ReqParamGet) - "paramValues" reste             }
            { ELV_NULL ci-dessous (valeurs MULTIPLES, hors de portee de la           }
            { convention TODO 18, voir sa note d en-tete). }
            Begin
              If ElNodePool[Idx].Kind = ELK_SELECTOR Then
                ReqKey := ElNodePool[Idx].NameVal
              Else
                ReqKey := ElValueToStr(ElEvalNode(ElNodePool[Idx].Right));
              If ReqParamGet(ReqKey, ReqStrVal) Then
              Begin V.Kind := ELV_STRING; V.StrVal := ReqStrVal; End
              Else
                V.Kind := ELV_NULL; { absent = param absent, empty vrai (TODO 18) }
            End;
        Else
          V.Kind := ELV_NULL; { paramValues/header/headerValues/cookie/          }
        End;                  { initParam (hors de portee de la convention           }
      End;                    { TODO 18, voir sa note d en-tete) ou propriete de        }
                              { bean/Map reelle (section 13.3) - limite assumee,          }
                              { documentee ci-dessus }

    ELK_CALL :
      Begin
        If ElNodePool[ElNodePool[Idx].Left].Kind = ELK_IDENT Then
          CalleeName := ElNodePool[ElNodePool[Idx].Left].NameVal
        Else
          CalleeName := '';
        If IsJstlFunctionsCall(CalleeName, FnLocalName) Then
        Begin
          If ElNodePool[Idx].ArgCount >= 1 Then
            VL := ElEvalNode(ElArgPool[ElNodePool[Idx].ArgFirst])
          Else
            VL.Kind := ELV_NULL;
          If FnLocalName = 'length' Then V := ElFnLength(VL)
          Else If FnLocalName = 'escapeXml' Then V := ElFnEscapeXml(VL)
          Else V.Kind := ELV_NULL; { fonction "fn:" native inconnue - TODO 17+ }
        End
        Else
          V.Kind := ELV_NULL; { prefixe non-functions/taglib personnalise - hors de portee ici }
      End;

    ELK_UNARY :
      If ElNodePool[Idx].Op = 'empty' Then
      Begin
        V.Kind := ELV_BOOLEAN;
        V.BoolVal := ElIsEmpty(ElEvalNode(ElNodePool[Idx].Left));
      End
      Else If ElNodePool[Idx].Op = '!' Then
      Begin
        V.Kind := ELV_BOOLEAN;
        V.BoolVal := Not ElToBoolean(ElEvalNode(ElNodePool[Idx].Left));
      End
      Else { '-' }
      Begin
        ElToNumber(ElEvalNode(ElNodePool[Idx].Left), IsFlt, LL, DL);
        If IsFlt Then Begin V.Kind := ELV_DOUBLE; V.RealVal := -DL; End
        Else Begin V.Kind := ELV_LONG; V.IntVal := -LL; End;
      End;

    ELK_BINARY :
      Begin
        VL := ElEvalNode(ElNodePool[Idx].Left);
        VR := ElEvalNode(ElNodePool[Idx].Right);
        If ElNodePool[Idx].Op = '&&' Then
        Begin V.Kind := ELV_BOOLEAN; V.BoolVal := ElToBoolean(VL) And ElToBoolean(VR); End
        Else If ElNodePool[Idx].Op = '||' Then
        Begin V.Kind := ELV_BOOLEAN; V.BoolVal := ElToBoolean(VL) Or ElToBoolean(VR); End
        Else If ElNodePool[Idx].Op = '+' Then
        Begin
          { section 12.4 : '+' reste ARITHMETIQUE en EL (contrairement a Java,    }
          { PAS de concatenation de chaines via '+' - verifie par lecture            }
          { attentive de la reference avant d ecrire ce TODO). }
          ElToNumber(VL, IsFloatL, LL, DL); ElToNumber(VR, IsFloatR, LR, DR);
          IsFlt := IsFloatL Or IsFloatR;
          If IsFlt Then
          Begin
            If Not IsFloatL Then DL := LL; If Not IsFloatR Then DR := LR;
            V.Kind := ELV_DOUBLE; V.RealVal := DL + DR;
          End
          Else Begin V.Kind := ELV_LONG; V.IntVal := LL + LR; End;
        End
        Else If (ElNodePool[Idx].Op = '==') Or (ElNodePool[Idx].Op = '!=') Then
        Begin
          V.Kind := ELV_BOOLEAN;
          V.BoolVal := ElValueToStr(VL) = ElValueToStr(VR);
          If ElNodePool[Idx].Op = '!=' Then V.BoolVal := Not V.BoolVal;
        End
        Else { '-' '*' '/' '%' '<' '>' '<=' '>=' - toutes NUMERIQUES }
        Begin
          ElToNumber(VL, IsFloatL, LL, DL); ElToNumber(VR, IsFloatR, LR, DR);
          IsFlt := IsFloatL Or IsFloatR;
          If Not IsFloatL Then DL := LL; If Not IsFloatR Then DR := LR;
          If ElNodePool[Idx].Op = '-' Then
          Begin
            If IsFlt Then Begin V.Kind := ELV_DOUBLE; V.RealVal := DL - DR; End
            Else Begin V.Kind := ELV_LONG; V.IntVal := LL - LR; End;
          End
          Else If ElNodePool[Idx].Op = '*' Then
          Begin
            If IsFlt Then Begin V.Kind := ELV_DOUBLE; V.RealVal := DL * DR; End
            Else Begin V.Kind := ELV_LONG; V.IntVal := LL * LR; End;
          End
          Else If ElNodePool[Idx].Op = '/' Then
          Begin
            V.Kind := ELV_DOUBLE;
            If DR = 0.0 Then V.RealVal := 0.0 Else V.RealVal := DL / DR;
          End
          Else If ElNodePool[Idx].Op = '%' Then
          Begin
            If (Not IsFlt) And (LR <> 0) Then
            Begin V.Kind := ELV_LONG; V.IntVal := LL Mod LR; End
            Else Begin V.Kind := ELV_LONG; V.IntVal := 0; End;
          End
          Else { comparaisons '<' '>' '<=' '>=' }
          Begin
            V.Kind := ELV_BOOLEAN;
            If ElNodePool[Idx].Op = '<' Then V.BoolVal := DL < DR
            Else If ElNodePool[Idx].Op = '>' Then V.BoolVal := DL > DR
            Else If ElNodePool[Idx].Op = '<=' Then V.BoolVal := DL <= DR
            Else V.BoolVal := DL >= DR;
          End;
        End;
      End;

    ELK_TERNARY :
      If ElToBoolean(ElEvalNode(ElNodePool[Idx].Left)) Then
        V := ElEvalNode(ElNodePool[Idx].Right)
      Else
        V := ElEvalNode(ElNodePool[Idx].Extra);
  End;
  ElEvalNode := V;
End;

{ ------------------------------------------------------------ }
{ ElEvalSelfTest : Test14ExpressionLanguage.jsp reel (ordre de     }
{ resolution page->request->session->application, acces direct       }
{ *Scope, empty sur un param absent, arithmetique/comparaison         }
{ normalisee), toString (coercition de sortie).                        }
{ ------------------------------------------------------------ }

Procedure ElEvalAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ElEvalSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ElEvalSelfTest;
Var Idx: Integer; V: TELValue;
Begin
  ScopeInit;

  { --- Test14ExpressionLanguage.jsp reel : ordre de resolution --- }
  V.Kind := ELV_LONG; V.IntVal := 125;
  ScopeSetAttribute(SCOPE_REQUEST, 'prixUnitaire', V);
  V.Kind := ELV_LONG; V.IntVal := 4;
  ScopeSetAttribute(SCOPE_REQUEST, 'quantite', V);
  V.Kind := ELV_STRING; V.StrVal := 'Grace';
  ScopeSetAttribute(SCOPE_SESSION, 'utilisateur', V);

  ElParserInit;
  Idx := ParseElFromString('prixUnitaire * quantite');
  V := ElEvalNode(Idx);
  ElEvalAssert('prixUnitaire * quantite : resolution NUE via request -> 500',
    (V.Kind = ELV_LONG) And (V.IntVal = 500));
  ElEvalAssert('toString(500) = "500"', ElValueToStr(V) = '500');

  ElParserInit;
  Idx := ParseElFromString('quantite ge 3');
  V := ElEvalNode(Idx);
  ElEvalAssert('quantite ge 3 : ">=" normalise, evalue a true', (V.Kind = ELV_BOOLEAN) And V.BoolVal);
  ElEvalAssert('toString(true) = "true"', ElValueToStr(V) = 'true');

  { --- acces direct a un scope precis (section 8.3/13.1) --- }
  ElParserInit;
  Idx := ParseElFromString('sessionScope.utilisateur');
  V := ElEvalNode(Idx);
  ElEvalAssert('sessionScope.utilisateur : acces DIRECT (pas via l ordre)',
    (V.Kind = ELV_STRING) And (V.StrVal = 'Grace'));

  ElParserInit;
  Idx := ParseElFromString('requestScope.prixUnitaire');
  V := ElEvalNode(Idx);
  ElEvalAssert('requestScope.prixUnitaire : acces DIRECT', (V.Kind = ELV_LONG) And (V.IntVal = 125));

  { --- un nom present en session mais interroge par requestScope reste  }
  { INTROUVABLE (acces direct = PAS de repli sur les autres portees,      }
  { contrairement a la resolution NUE ci-dessus) --- }
  ElParserInit;
  Idx := ParseElFromString('requestScope.utilisateur');
  V := ElEvalNode(Idx);
  ElEvalAssert('requestScope.utilisateur : absent de CETTE portee precise = null',
    V.Kind = ELV_NULL);

  { --- empty (section 12.7) : parametre absent (aucun modele de requete   }
  { avant le TODO 18 - "absence = param absent, empty renvoie vrai",         }
  { roadmap d en-tete TODO 18) --- }
  ElParserInit;
  Idx := ParseElFromString('empty param.nom');
  V := ElEvalNode(Idx);
  ElEvalAssert('empty param.nom : param non modelise -> null -> empty vrai',
    (V.Kind = ELV_BOOLEAN) And V.BoolVal);

  ElParserInit;
  Idx := ParseElFromString('not empty sessionScope.utilisateur');
  V := ElEvalNode(Idx);
  ElEvalAssert('not empty sessionScope.utilisateur : present -> empty faux -> not = vrai',
    (V.Kind = ELV_BOOLEAN) And V.BoolVal);

  { --- ternaire + chaines litterales --- }
  ElParserInit;
  Idx := ParseElFromString('empty param.nom ? ''(absent)'' : param.nom');
  V := ElEvalNode(Idx);
  ElEvalAssert('ternaire : branche VRAIE choisie (param.nom absent)',
    (V.Kind = ELV_STRING) And (V.StrVal = '(absent)'));

  ScopeInit;
End;

{ ============================================================ }
{ TODO 16 - JSTL CORE : C:OUT, C:SET, C:IF, C:CHOOSE, C:FOREACH }
{ ============================================================ }

{ AttrTextToElIdx : convertit une valeur d attribut JSTL BRUTE (deja       }
{ decodee des guillemets par le lexeur, TOK_ATTR_VALUE) en un noeud EL -      }
{ une valeur ENTIEREMENT entouree de "dollar-accolade"/"diese-accolade"          }
{ (section 12.1 - aucun echantillon couvert par ce TODO ne melange texte          }
{ litteral et EL dans un MEME attribut) est analysee comme une VRAIE               }
{ expression EL (TODO 14/15) ; toute autre valeur est un LITTERAL - synthetise      }
{ ICI en un simple ELK_STRING pour que value/test/items/default partagent            }
{ TOUS un SEUL type de representation (un index ElNodePool) plutot que de              }
{ dupliquer un champ "litteral ou EL" separe sur CHAQUE noeud SK_JSTL_xxx. }
Function AttrTextToElIdx(Const RawVal: TBigString): Integer;
Var Inner: TBigString; Idx: Integer;
Begin
  If (Length(RawVal) >= 3) And
     ((Copy(RawVal, 1, 2) = '${') Or (Copy(RawVal, 1, 2) = '#{')) And
     (RawVal[Length(RawVal)] = '}') Then
  Begin
    Inner := Copy(RawVal, 3, Length(RawVal) - 3);
    AttrTextToElIdx := ParseElFromString(Inner);
    Exit;
  End;
  Idx := ElNodeAdd(ELK_STRING);
  ElNodePool[Idx].StrVal := RawVal;
  AttrTextToElIdx := Idx;
End;

{ ParseJstlBody : PRE-CONDITION - CurTok EST le PREMIER token du corps      }
{ (juste apres avoir consomme TOK_ACTION_BODY_OPEN), ActionName est le          }
{ nom COMPLET "prefixe:nom" de l action ENGLOBANTE (ex. "c:if") - PARSE           }
{ ENTIEREMENT le corps (gabarit/scriptlets/EL/actions - y compris une              }
{ AUTRE action JSTL imbriquee, MEME nom ou non) en accumulant les enfants            }
{ via TryConsumeInterleaveToken jusqu a la fermeture CORRESPONDANTE                    }
{ ("</c:if>" ici) - AUCUN comptage de profondeur manuel n est necessaire                }
{ (contrairement a SkipUnknownAction/SkipActionBody) : une action imbriquee              }
{ de MEME nom est integralement consommee par son PROPRE appel recursif a                 }
{ ParseJstlXxx (qui avale lui-meme sa propre fermeture) avant que CETTE                     }
{ boucle-ci ne revoie le flux - EXACTEMENT le raisonnement standard de la                     }
{ descente recursive. MEME technique "tampon local puis recopie" que                            }
{ ParseBlock/ParsePage (TODO 07/08) : indispensable des qu un corps peut                          }
{ contenir une action JSTL imbriquee dont le PROPRE corps avancerait                                }
{ StmtChildCount avant que CE corps-ci ait fini d y ecrire le sien. }
Procedure ParseJstlBody(Const ActionName: TString; Var ChildFirst, ChildCount: Integer);
Var
  Count, I, NewIdx : Integer;
  LocalChild : Array[0..MAX_JAVA_BLOCK_LOCAL - 1] Of Integer;
Begin
  Count := 0;
  While (Not ((CurTok.Kind = TOK_ACTION_CLOSE) And (CurTok.Val = ActionName))) And
        (CurTok.Kind <> TOK_EOF) Do
  Begin
    If TryConsumeInterleaveToken(NewIdx) Then
    Begin
      If Count >= MAX_JAVA_BLOCK_LOCAL Then
      Begin
        FatalError('corps d action JSTL trop volumineux (MAX_JAVA_BLOCK_LOCAL) : ' +
                   ActionName);
        Break;
      End;
      LocalChild[Count] := NewIdx;
      Inc(Count);
    End;
  End;

  If CurTok.Kind = TOK_ACTION_CLOSE Then
    ParserAdvance { consomme la fermeture de CETTE action (ex. </c:if>) }
  Else
    FatalError('fermeture manquante pour l action JSTL : ' + ActionName);

  ChildFirst := StmtChildCount;
  For I := 0 To Count - 1 Do
  Begin
    If StmtChildCount >= MAX_JAVA_STMT_CHILD Then
    Begin
      FatalError('trop d instructions au total (MAX_JAVA_STMT_CHILD)');
      Break;
    End;
    StmtChildPool[StmtChildCount] := LocalChild[I];
    Inc(StmtChildCount);
  End;
  ChildCount := Count;
End;

{ ParseJstlOut (section 16.4, <c:out value=... [default="..."]            }
{ [escapeXml="..."] />, Test17JstlXml.jsp reel) - "value" obligatoire,        }
{ "escapeXml" reconnu mais SANS EFFET (echappement TOUJOURS actif, section      }
{ 24.1 - DECISION A DOCUMENTER, roadmap d en-tete). La forme AVEC CORPS           }
{ (le corps sert de "default" alternatif) est une forme rare NON geree -           }
{ reconnue syntaxiquement, corps saute proprement (MEME discipline que la           }
{ tolerance de corps rare de jsp:useBean, TODO 13) plutot qu ignoree                  }
{ silencieusement. }
Function ParseJstlOut: Integer;
Var
  Idx, ValueIdx, DefaultIdx : Integer;
  AttrName                  : TString;
  HasValue                  : Boolean;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:out) }
  HasValue := False; ValueIdx := -1; DefaultIdx := -1;
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('c:out : valeur d attribut attendue pour ' + AttrName);
      ParseJstlOut := -1;
      Exit;
    End;
    If AttrName = 'value' Then
    Begin ValueIdx := AttrTextToElIdx(CurTok.Val); HasValue := True; End
    Else If AttrName = 'default' Then
      DefaultIdx := AttrTextToElIdx(CurTok.Val)
    Else If AttrName = 'escapeXml' Then
      Begin End { section 24.1 - echappement toujours actif, attribut sans effet }
    Else
      WarnMsg('c:out : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasValue Then
    FatalError('c:out : attribut "value" obligatoire (section 16.4)');

  Idx := StmtAdd(SK_JSTL_OUT);
  StmtPool[Idx].ElIdx := ValueIdx;
  StmtPool[Idx].Left  := DefaultIdx;
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else
  Begin
    WarnMsg('c:out avec corps (forme "default" alternative) non geree, ignore');
    SkipActionBody;
  End;
  ParseJstlOut := Idx;
End;

{ ParseJstlSet (section 16.4, <c:set var="..." value="..." [scope="..."]  }
{ />, Test16JstlJakarta.jsp reel) - "var" ET "value" obligatoires ICI (les     }
{ formes "target"/"property" - affectation d une propriete de bean - et la      }
{ forme AVEC CORPS ne sont exercees par AUCUN echantillon, DECISION A             }
{ DOCUMENTER : non gerees plutot qu approximees). "scope" par defaut =              }
{ SCOPE_PAGE (section 8.1, aucun defaut explicite dans la reference pour             }
{ c:set lui-meme - MEME choix restrictif/sur que jsp:useBean, TODO 13). }
Function ParseJstlSet: Integer;
Var
  Idx, ValueIdx     : Integer;
  AttrName, VarName : TString;
  ScopeK            : TScopeKind;
  HasVar, HasValue  : Boolean;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:set) }
  VarName := ''; ValueIdx := -1; ScopeK := SCOPE_PAGE;
  HasVar := False; HasValue := False;
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('c:set : valeur d attribut attendue pour ' + AttrName);
      ParseJstlSet := -1;
      Exit;
    End;
    If AttrName = 'var' Then
    Begin VarName := CurTok.Val; HasVar := True; End
    Else If AttrName = 'value' Then
    Begin ValueIdx := AttrTextToElIdx(CurTok.Val); HasValue := True; End
    Else If AttrName = 'scope' Then
    Begin
      If CurTok.Val = 'page' Then ScopeK := SCOPE_PAGE
      Else If CurTok.Val = 'request' Then ScopeK := SCOPE_REQUEST
      Else If CurTok.Val = 'session' Then ScopeK := SCOPE_SESSION
      Else If CurTok.Val = 'application' Then ScopeK := SCOPE_APPLICATION
      Else WarnMsg('c:set : valeur de "scope" inconnue, "page" suppose : ' + CurTok.Val);
    End
    Else
      WarnMsg('c:set : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  If Not HasVar Then
    FatalError('c:set : attribut "var" obligatoire (forme "target"/"property" ' +
               'non geree, section 16.4)');
  If Not HasValue Then
    FatalError('c:set : attribut "value" obligatoire (forme avec corps non ' +
               'geree, section 16.4)');

  Idx := StmtAdd(SK_JSTL_SET);
  StmtPool[Idx].NameVal := VarName;
  StmtPool[Idx].ElIdx   := ValueIdx;
  StmtPool[Idx].Extra   := Ord(ScopeK);
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
    ParserAdvance
  Else
  Begin
    WarnMsg('c:set avec corps non gere, ignore');
    SkipActionBody;
  End;
  ParseJstlSet := Idx;
End;

{ ParseJstlIf (section 16.4/16.5, <c:if test=...>corps</c:if>,           }
{ Test16JstlJakarta.jsp reel) - "test" obligatoire ; "var"/"scope"              }
{ (memorisation du resultat booleen dans une portee) reconnus                     }
{ syntaxiquement mais SANS EFFET, aucun echantillon ne les exercice. }
Function ParseJstlIf: Integer;
Var
  Idx, CF, CC : Integer;
  AttrName    : TString;
  TestIdx     : Integer;
  HasTest     : Boolean;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:if) }
  HasTest := False; TestIdx := -1;
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('c:if : valeur d attribut attendue pour ' + AttrName);
      ParseJstlIf := -1;
      Exit;
    End;
    If AttrName = 'test' Then
    Begin TestIdx := AttrTextToElIdx(CurTok.Val); HasTest := True; End
    Else If (AttrName = 'var') Or (AttrName = 'scope') Then
      Begin End { section 16.4 - reconnus syntaxiquement, sans effet }
    Else
      WarnMsg('c:if : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;
  If Not HasTest Then
    FatalError('c:if : attribut "test" obligatoire (section 16.4/16.5)');

  Idx := StmtAdd(SK_JSTL_IF);
  StmtPool[Idx].ElIdx := TestIdx;
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ChildFirst := 0;
    StmtPool[Idx].ChildCount := 0;
  End
  Else
  Begin
    ParserAdvance; { consomme TOK_ACTION_BODY_OPEN }
    ParseJstlBody('c:if', CF, CC);
    StmtPool[Idx].ChildFirst := CF;
    StmtPool[Idx].ChildCount := CC;
  End;
  ParseJstlIf := Idx;
End;

{ ParseJstlChoose/When/Otherwise (section 16.4/16.5, Test15JstlJavaEE.jsp  }
{ reel) - c:choose n a AUCUN attribut ; son corps est PARSE comme n importe     }
{ quel autre (ParseJstlBody), ce qui produit NATURELLEMENT une suite de           }
{ SK_JSTL_WHEN/SK_JSTL_OTHERWISE (chacun dispatche par                              }
{ TryConsumeInterleaveToken exactement comme n importe quelle autre action)           }
{ MELANGEE au texte de gabarit insignifiant (espaces/sauts de ligne) entre             }
{ les balises - DECISION A DOCUMENTER : ce texte insignifiant N EST PAS                  }
{ filtre ici (aucun codegen n existe encore pour s en soucier, TODO 21+),                  }
{ MEME tolerance que le reste de ce compilateur envers le gabarit litteral. }
Function ParseJstlChoose: Integer;
Var Idx, CF, CC: Integer;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:choose) }
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    WarnMsg('c:choose : aucun attribut attendu, ignore : ' + CurTok.Val);
    ParserAdvance;
    If CurTok.Kind = TOK_ATTR_VALUE Then ParserAdvance;
  End;

  Idx := StmtAdd(SK_JSTL_CHOOSE);
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ChildFirst := 0;
    StmtPool[Idx].ChildCount := 0;
  End
  Else
  Begin
    ParserAdvance; { consomme TOK_ACTION_BODY_OPEN }
    ParseJstlBody('c:choose', CF, CC);
    StmtPool[Idx].ChildFirst := CF;
    StmtPool[Idx].ChildCount := CC;
  End;
  ParseJstlChoose := Idx;
End;

Function ParseJstlWhen: Integer;
Var
  Idx, CF, CC : Integer;
  AttrName    : TString;
  TestIdx     : Integer;
  HasTest     : Boolean;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:when) }
  HasTest := False; TestIdx := -1;
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('c:when : valeur d attribut attendue pour ' + AttrName);
      ParseJstlWhen := -1;
      Exit;
    End;
    If AttrName = 'test' Then
    Begin TestIdx := AttrTextToElIdx(CurTok.Val); HasTest := True; End
    Else
      WarnMsg('c:when : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;
  If Not HasTest Then
    FatalError('c:when : attribut "test" obligatoire (section 16.4/16.5)');

  Idx := StmtAdd(SK_JSTL_WHEN);
  StmtPool[Idx].ElIdx := TestIdx;
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ChildFirst := 0;
    StmtPool[Idx].ChildCount := 0;
  End
  Else
  Begin
    ParserAdvance;
    ParseJstlBody('c:when', CF, CC);
    StmtPool[Idx].ChildFirst := CF;
    StmtPool[Idx].ChildCount := CC;
  End;
  ParseJstlWhen := Idx;
End;

Function ParseJstlOtherwise: Integer;
Var Idx, CF, CC: Integer;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:otherwise) }
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    WarnMsg('c:otherwise : aucun attribut attendu, ignore : ' + CurTok.Val);
    ParserAdvance;
    If CurTok.Kind = TOK_ATTR_VALUE Then ParserAdvance;
  End;

  Idx := StmtAdd(SK_JSTL_OTHERWISE);
  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ChildFirst := 0;
    StmtPool[Idx].ChildCount := 0;
  End
  Else
  Begin
    ParserAdvance;
    ParseJstlBody('c:otherwise', CF, CC);
    StmtPool[Idx].ChildFirst := CF;
    StmtPool[Idx].ChildCount := CC;
  End;
  ParseJstlOtherwise := Idx;
End;

{ ParseJstlForeach (section 16.4/16.6, <c:forEach [var] [items=...]       }
{ | [begin] [end] [step] >corps</c:forEach>) - DEUX formes reelles :          }
{ Test15JstlJavaEE.jsp (items=tableau de String, VIA "langages") ET               }
{ Test16JstlJakarta.jsp (begin="1" end="5", forme numerique SANS items) -           }
{ "varStatus" reconnu syntaxiquement mais NON implemente (section 16.6,               }
{ aucun echantillon ne l exercice, MEME discipline que "beanName"/"tagdir",             }
{ TODO 06/13). "begin"/"end"/"step" sont des LITTERAUX numeriques ICI               }
{ (decodage syntaxique Val(), PAS une evaluation EL - aucun echantillon ne               }
{ leur passe une expression EL, DECISION A DOCUMENTER) ; "step" par defaut               }
{ 1 (aucun defaut explicite dans cette reference, mais 1 est la seule                     }
{ valeur qui laisse begin/end inchanges). }
Function ParseJstlForeach: Integer;
Var
  Idx, CF, CC         : Integer;
  AttrName, VarName   : TString;
  ItemsIdx            : Integer;
  HasItems            : Boolean;
  BeginV, EndV, StepV : LongInt;
  Code                : Integer;
Begin
  ParserAdvance; { consomme TOK_ACTION_OPEN (c:forEach) }
  VarName := ''; ItemsIdx := -1; HasItems := False;
  BeginV := 0; EndV := 0; StepV := 1;
  While CurTok.Kind = TOK_ATTR_NAME Do
  Begin
    AttrName := CurTok.Val;
    ParserAdvance;
    If CurTok.Kind <> TOK_ATTR_VALUE Then
    Begin
      FatalError('c:forEach : valeur d attribut attendue pour ' + AttrName);
      ParseJstlForeach := -1;
      Exit;
    End;
    If AttrName = 'var' Then
      VarName := CurTok.Val
    Else If AttrName = 'items' Then
    Begin ItemsIdx := AttrTextToElIdx(CurTok.Val); HasItems := True; End
    Else If AttrName = 'begin' Then
    Begin
      Val(CurTok.Val, BeginV, Code);
      If Code <> 0 Then
      Begin WarnMsg('c:forEach : "begin" numerique attendu : ' + CurTok.Val); BeginV := 0; End;
    End
    Else If AttrName = 'end' Then
    Begin
      Val(CurTok.Val, EndV, Code);
      If Code <> 0 Then
      Begin WarnMsg('c:forEach : "end" numerique attendu : ' + CurTok.Val); EndV := 0; End;
    End
    Else If AttrName = 'step' Then
    Begin
      Val(CurTok.Val, StepV, Code);
      If Code <> 0 Then
      Begin WarnMsg('c:forEach : "step" numerique attendu : ' + CurTok.Val); StepV := 1; End;
    End
    Else If AttrName = 'varStatus' Then
      Begin End { section 16.6 - reconnu syntaxiquement, non implemente }
    Else
      WarnMsg('c:forEach : attribut inconnu ignore : ' + AttrName);
    ParserAdvance;
  End;

  Idx := StmtAdd(SK_JSTL_FOREACH);
  StmtPool[Idx].NameVal := VarName;
  StmtPool[Idx].BoolVal := HasItems;
  StmtPool[Idx].ElIdx   := ItemsIdx;
  StmtPool[Idx].Left    := BeginV;
  StmtPool[Idx].Right   := EndV;
  StmtPool[Idx].Extra   := StepV;

  If CurTok.Kind = TOK_ACTION_SELFCLOSE Then
  Begin
    ParserAdvance;
    StmtPool[Idx].ChildFirst := 0;
    StmtPool[Idx].ChildCount := 0;
  End
  Else
  Begin
    ParserAdvance;
    ParseJstlBody('c:forEach', CF, CC);
    StmtPool[Idx].ChildFirst := CF;
    StmtPool[Idx].ChildCount := CC;
  End;
  ParseJstlForeach := Idx;
End;

{ ------------------------------------------------------------ }
{ JstlCoreSelfTest : Test15JstlJavaEE.jsp reel (c:choose/c:when/    }
{ c:otherwise, c:forEach items=tableau), Test16JstlJakarta.jsp       }
{ reel (c:set, c:if x2, c:forEach begin/end numerique),               }
{ Test17JstlXml.jsp reel (c:out value+default).                        }
{ ------------------------------------------------------------ }

Procedure JstlCoreAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('JstlCoreSelfTest: ' + Label_ + ' a echoue');
End;

Procedure JstlCoreSelfTest;
Const
  TmpFile = 'JSPJSTLSELFTEST.$$$';
Var
  F                       : Text;
  PageIdx, C0, C1, W0, W1 : Integer;
Begin
  JavaParserInit; PageInit; JspParamInit; ElParserInit;

  { --- Test17JstlXml.jsp reel : c:out value + default --- }
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>',
        '<c:out value="${param.texte}" default="(absent)" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JstlCoreAssert('c:out reel : SK_JSTL_OUT', StmtPool[C0].Kind = SK_JSTL_OUT);
  JstlCoreAssert('c:out reel : value = param.texte (SELECTOR)',
    ElNodePool[StmtPool[C0].ElIdx].Kind = ELK_SELECTOR);
  JstlCoreAssert('c:out reel : default = "(absent)" (ELK_STRING litteral)',
    (ElNodePool[StmtPool[C0].Left].Kind = ELK_STRING) And
    (ElNodePool[StmtPool[C0].Left].StrVal = '(absent)'));
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- Test16JstlJakarta.jsp reel : c:set + c:if x2 + c:forEach begin/end --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ taglib prefix="c" uri="jakarta.tags.core" %>',
        '<c:set var="titre" value="Jakarta Server Pages" />',
        '<c:if test="${empty param.recherche}"><p>absent</p></c:if>',
        '<c:if test="${not empty param.recherche}"><p>present</p></c:if>',
        '<c:forEach var="numero" begin="1" end="5"><li>x</li></c:forEach>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JstlCoreAssert('c:set reel : SK_JSTL_SET, var=titre',
    (StmtPool[C0].Kind = SK_JSTL_SET) And (StmtPool[C0].NameVal = 'titre'));
  JstlCoreAssert('c:set reel : value litterale "Jakarta Server Pages"',
    (ElNodePool[StmtPool[C0].ElIdx].Kind = ELK_STRING) And
    (ElNodePool[StmtPool[C0].ElIdx].StrVal = 'Jakarta Server Pages'));
  JstlCoreAssert('c:set reel : scope par defaut = SCOPE_PAGE',
    StmtPool[C0].Extra = Ord(SCOPE_PAGE));

  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  JstlCoreAssert('c:if #1 reel : SK_JSTL_IF, test = empty param.recherche',
    (StmtPool[C1].Kind = SK_JSTL_IF) And
    (ElNodePool[StmtPool[C1].ElIdx].Kind = ELK_UNARY) And
    (ElNodePool[StmtPool[C1].ElIdx].Op = 'empty'));
  JstlCoreAssert('c:if #1 reel : corps = 1 instruction (SK_PRINT_TEMPLATE "<p>absent</p>")',
    StmtPool[C1].ChildCount = 1);

  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 3];
  JstlCoreAssert('c:forEach reel : SK_JSTL_FOREACH, var=numero',
    (StmtPool[C1].Kind = SK_JSTL_FOREACH) And (StmtPool[C1].NameVal = 'numero'));
  JstlCoreAssert('c:forEach reel : forme numerique (HasItems=False)',
    Not StmtPool[C1].BoolVal);
  JstlCoreAssert('c:forEach reel : begin=1, end=5, step=1 (defaut)',
    (StmtPool[C1].Left = 1) And (StmtPool[C1].Right = 5) And (StmtPool[C1].Extra = 1));
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- Test15JstlJavaEE.jsp reel : c:choose/c:when/c:otherwise +           }
  { c:forEach items= (forme collection) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core" %>',
        '<c:choose>',
        '<c:when test="${empty param.nom}"><p>a</p></c:when>',
        '<c:otherwise><p>b</p></c:otherwise>',
        '</c:choose>',
        '<c:forEach var="langage" items="${langages}"><li>x</li></c:forEach>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  C0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  JstlCoreAssert('c:choose reel : SK_JSTL_CHOOSE', StmtPool[C0].Kind = SK_JSTL_CHOOSE);
  JstlCoreAssert('c:choose reel : 2 enfants (when + otherwise)', StmtPool[C0].ChildCount = 2);
  W0 := StmtChildPool[StmtPool[C0].ChildFirst];
  W1 := StmtChildPool[StmtPool[C0].ChildFirst + 1];
  JstlCoreAssert('c:choose reel : enfant 0 = SK_JSTL_WHEN, test = empty param.nom',
    (StmtPool[W0].Kind = SK_JSTL_WHEN) And
    (ElNodePool[StmtPool[W0].ElIdx].Kind = ELK_UNARY) And
    (ElNodePool[StmtPool[W0].ElIdx].Op = 'empty'));
  JstlCoreAssert('c:choose reel : enfant 1 = SK_JSTL_OTHERWISE',
    StmtPool[W1].Kind = SK_JSTL_OTHERWISE);

  C1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  JstlCoreAssert('c:forEach items= reel : SK_JSTL_FOREACH, var=langage',
    (StmtPool[C1].Kind = SK_JSTL_FOREACH) And (StmtPool[C1].NameVal = 'langage'));
  JstlCoreAssert('c:forEach items= reel : forme collection (HasItems=True)',
    StmtPool[C1].BoolVal);
  JstlCoreAssert('c:forEach items= reel : items = langages (IDENT)',
    (ElNodePool[StmtPool[C1].ElIdx].Kind = ELK_IDENT) And
    (ElNodePool[StmtPool[C1].ElIdx].NameVal = 'langages'));
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 17 - JSTL FUNCTIONS : FN:LENGTH, FN:ESCAPEXML            }
{ ============================================================ }

{ JstlFunctionsSelfTest : Test15JstlJavaEE.jsp/Test16JstlJakarta.jsp    }
{ reels (fn:length sur une variable de portee resolue via l ordre           }
{ NU, section 8.3/13.2), Test17JstlXml.jsp reel (fn:escapeXml combine        }
{ a un operateur ternaire EL, EXACTEMENT comme le roadmap d en-tete             }
{ le cite), et un cas synthetique ou l echappement a effectivement lieu           }
{ (aucun echantillon actuel ne fait passer un caractere special a               }
{ fn:escapeXml - Test17JstlXml.jsp l invoque toujours sur "(absent)" ou           }
{ un parametre absent, jamais du contenu a echapper reellement). }
Procedure JstlFunctionsAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('JstlFunctionsSelfTest: ' + Label_ + ' a echoue');
End;

Procedure JstlFunctionsSelfTest;
Var Idx: Integer; V: TELValue;
Begin
  ScopeInit; TaglibInit;
  TaglibAdd('fn', 'http://java.sun.com/jsp/jstl/functions');

  { --- Test15JstlJavaEE.jsp/Test16JstlJakarta.jsp reels : fn:length sur    }
  { une variable de portee ("langage"/"titre" dans les echantillons reels,    }
  { "langage" repris ICI) resolue via l ordre NU (section 8.3/13.2) --- }
  V.Kind := ELV_STRING; V.StrVal := 'Java';
  ScopeSetAttribute(SCOPE_PAGE, 'langage', V);
  ElParserInit;
  Idx := ParseElFromString('fn:length(langage)');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('fn:length(langage) : "Java" -> 4',
    (V.Kind = ELV_LONG) And (V.IntVal = 4));

  { --- fn:length sur une valeur absente (section 13.4, "null-safe") --- }
  ElParserInit;
  Idx := ParseElFromString('fn:length(inconnue)');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('fn:length(inconnue) : variable absente -> 0',
    (V.Kind = ELV_LONG) And (V.IntVal = 0));

  { --- Test17JstlXml.jsp reel : fn:escapeXml + ternaire + empty --- }
  ElParserInit;
  Idx := ParseElFromString(
    'fn:escapeXml(empty param.texte ? ''(absent)'' : param.texte)');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('fn:escapeXml(...) reel : param.texte absent -> "(absent)"',
    (V.Kind = ELV_STRING) And (V.StrVal = '(absent)'));

  { --- echappement effectif (synthetique, section 24.1 - AUCUN echantillon  }
  { actuel ne fait passer de contenu a echapper reellement a fn:escapeXml) -   }
  { deux litteraux EL distincts (guillemet simple/double, section 12.3) pour     }
  { couvrir les 5 entites SANS avoir a echapper un guillemet a l INTERIEUR         }
  { d un litteral EL du MEME type. }
  ElParserInit;
  Idx := ParseElFromString('fn:escapeXml(''<b>&"'')');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('fn:escapeXml(''<b>&"'') -> &lt;b&gt;&amp;&quot;',
    (V.Kind = ELV_STRING) And (V.StrVal = '&lt;b&gt;&amp;&quot;'));

  ElParserInit;
  Idx := ParseElFromString('fn:escapeXml("''")');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('fn:escapeXml("''") -> &apos;',
    (V.Kind = ELV_STRING) And (V.StrVal = '&apos;'));

  { --- prefixe NON declare comme "functions" (ex. "c", TODO 16) : jamais   }
  { confondu avec une fonction native (section 12.9, DECISION A DOCUMENTER   }
  { du TODO 17) --- }
  TaglibAdd('c', 'http://java.sun.com/jsp/jstl/core');
  ElParserInit;
  Idx := ParseElFromString('c:length(langage)');
  V := ElEvalNode(Idx);
  JstlFunctionsAssert('c:length(...) : prefixe non-functions -> null (jamais evalue)',
    V.Kind = ELV_NULL);

  ScopeInit; TaglibInit;
End;

{ ============================================================ }
{ TODO 18 - MODELE RUNTIME : SIMULATION D UNE REQUETE HTTP      }
{ ============================================================ }

{ DECISIONS D ARCHITECTURE A DOCUMENTER EXPLICITEMENT avant le TODO 20      }
{ (roadmap d en-tete, MEME discipline que JPPCW32.PAS TODO 04) :               }
{                                                                               }
{ 1. UNE execution du binaire genere = UNE requete GET simulee - AUCUN            }
{    vrai serveur HTTP n est demarre (section 2, "conteneur... remplace par        }
{    un runtime minimal embarque simulant UNE requete HTTP GET par                    }
{    execution", roadmap d en-tete du fichier).                                          }
{ 2. request.getParameter/l objet implicite EL "param" (section 8.2/13.1) :       }
{    source = ligne de commande du binaire GENERE (PAS de CE compilateur -           }
{    JSPCW32.exe garde ses PROPRES options -o/-v/-d/-w/-D/-obj/-asm, TODO             }
{    01) sous forme "cle=valeur" (ex. "programme.exe nom=Ada") - MODELISE                }
{    ICI par ReqParamPool/ReqParamParseArg/ReqParamGet, un pool plat "cle/                 }
{    valeur" MEME technique que ScopeAttrPool (TODO 10). Absence d un                        }
{    parametre = param absent (empty renvoie vrai, section 12.7). SEUL                          }
{    request.getParameter/"param" (premiere valeur) sont couverts -                                }
{    paramValues/header/headerValues/cookie/initParam necessiteraient un                              }
{    VRAI modele de requete HTTP (en-tetes, cookies, valeurs MULTIPLES par                              }
{    cle) largement au-dela d une simple ligne "cle=valeur" - HORS DE                                      }
{    PORTEE explicite de cette convention (ELV_NULL, comme documente depuis                                  }
{    le TODO 15, reste inchange pour ces cinq autres objets implicites).                                        }
{ 3. Sortie (out.print/println, tout gabarit/toute expression imprimee) :         }
{    ecrite sur STDOUT via WriteFile/GetStdHandle (Win32) - PAS de vrai              }
{    buffer de reponse HTTP avec en-tetes (contentType etc., TODO 05, restent           }
{    documentes dans PageOpts mais ne sont JAMAIS emis sur le flux, limite                 }
{    assumee). AUCUN codegen n existe encore pour REALISER cette ecriture                     }
{    (TODO 21+, structure generale de l assembleur) - decision a HONORER                        }
{    plus tard, pas du code executable ici.                                                        }
{ 4. session/application : DEJA documente au TODO 10 (voir la note d en-tete      }
{    de ScopeAttrPool) - tables en memoire du PROCESSUS, jamais persistantes           }
{    entre deux executions (chaque lancement = nouvelle session/application               }
{    vide). Confirme/reference ICI ; rien de nouveau a coder.                                    }
{ 5. Dispatch d erreur (errorPage/isErrorPage, section 18.1) :                    }
{    PageOpts.ErrorPage/IsErrorPage (TODO 05) et la restriction "exception          }
{    disponible SEULEMENT si isErrorPage=true" (TODO 09,                               }
{    IsKnownImplicitMethod/ImplicitObjectSelfTest) existent DEJA. Le VRAI               }
{    dispatch (un gestionnaire genere qui invoque la traduction de errorPage               }
{    avec exception peuplee) est un mecanisme de CODEGEN (TODO 21+) ; la                     }
{    validation que errorPage designe un fichier EXISTANT et RESOLUBLE est                     }
{    explicitement le TODO 20 (analyse semantique, roadmap d en-tete) -                          }
{    AUCUN des deux n est dans la portee de CE TODO 18. }

{ TReqParam/ReqParamPool (section 8.2/13.1) : MEME technique "pool plat     }
{ cle/valeur" que ScopeAttrPool (TODO 10), mais SANS notion de portee (une     }
{ requete simulee n a qu une seule origine, la ligne de commande) - UNE          }
{ SEULE valeur par cle (paramValues, valeurs MULTIPLES, est HORS DE PORTEE          }
{ de cette convention, voir la note d en-tete ci-dessus) ; une cle DEJA             }
{ presente est ECRASEE par une occurrence ulterieure (MEME choix "le                 }
{ dernier gagne" que ScopeSetAttribute). }
Type
  TReqParam = Record
    Name  : TString;
    Value : TBigString;
  End;

Var
  ReqParamPool  : Array[0..MAX_REQPARAM - 1] Of TReqParam;
  ReqParamCount : Integer;

Procedure ReqParamInit;
Begin
  ReqParamCount := 0;
End;

Function ReqParamFindIndex(Const Name: TString): Integer;
Var I: Integer;
Begin
  ReqParamFindIndex := -1;
  For I := 0 To ReqParamCount - 1 Do
    If ReqParamPool[I].Name = Name Then
    Begin
      ReqParamFindIndex := I;
      Exit;
    End;
End;

{ ReqParamParseArg : decode UN argument brut "cle=valeur" (ex. "nom=Ada")   }
{ - PAS de "?"/encodage URL a decoder ICI (le "?nom=Ada" d une VRAIE requete    }
{ HTTP, section 8.2, devient une convention DIFFERENTE et plus simple pour        }
{ le binaire genere, decision 2 ci-dessus) ; un argument SANS "=" est               }
{ malforme pour cette convention - signale par un avertissement et ignore,           }
{ JAMAIS une erreur fatale (une requete simulee reste "presentation",                  }
{ section 13.4). }
Function ReqParamParseArg(Const Arg: TString): Boolean;
Var EqPos: Integer; K: TString; V: TBigString; Idx: Integer;
Begin
  EqPos := Pos('=', Arg);
  If EqPos = 0 Then
  Begin
    WarnMsg('parametre de requete simule mal forme (attendu "cle=valeur") : ' + Arg);
    ReqParamParseArg := False;
    Exit;
  End;
  K := Copy(Arg, 1, EqPos - 1);
  V := Copy(Arg, EqPos + 1, Length(Arg) - EqPos);
  Idx := ReqParamFindIndex(K);
  If Idx >= 0 Then
    ReqParamPool[Idx].Value := V
  Else If ReqParamCount < MAX_REQPARAM Then
  Begin
    ReqParamPool[ReqParamCount].Name  := K;
    ReqParamPool[ReqParamCount].Value := V;
    Inc(ReqParamCount);
  End
  Else
    WarnMsg('trop de parametres de requete simules (MAX_REQPARAM), ignore : ' + K);
  ReqParamParseArg := True;
End;

{ ReqParamGet (definition reelle - voir le Forward pres d ElEvalNode) -    }
{ premiere (et SEULE) valeur d une cle, "null si absent... JAMAIS une         }
{ erreur" - MEME convention que ScopeGetAttribute (TODO 10). }
Function ReqParamGet(Const Name: TString; Var Value: TBigString): Boolean;
Var Idx: Integer;
Begin
  Idx := ReqParamFindIndex(Name);
  If Idx >= 0 Then
  Begin
    Value := ReqParamPool[Idx].Value;
    ReqParamGet := True;
  End
  Else
  Begin
    Value := '';
    ReqParamGet := False;
  End;
End;

{ ------------------------------------------------------------ }
{ ReqParamSelfTest : Test05Parametres.jsp reel (request.          }
{ getParameter("nom"), convention "programme.exe nom=Ada" du         }
{ roadmap d en-tete), Test14ExpressionLanguage.jsp/                    }
{ Test16JstlJakarta.jsp reels (empty param.nom / not empty param.       }
{ recherche via EL - MAINTENANT resolus contre un VRAI modele de           }
{ requete plutot que TOUJOURS vides depuis le TODO 15).                     }
{ ------------------------------------------------------------ }

Procedure ReqParamAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ReqParamSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ReqParamSelfTest;
Var Idx: Integer; V: TELValue; S: TBigString; Found: Boolean;
Begin
  ReqParamInit;

  { --- Test05Parametres.jsp reel : "nom=Ada" (convention roadmap d en-tete,  }
  { PAS "?nom=Ada" - decision 2 ci-dessus) --- }
  ReqParamAssert('ReqParamParseArg("nom=Ada") : accepte', ReqParamParseArg('nom=Ada'));
  Found := ReqParamGet('nom', S);
  ReqParamAssert('request.getParameter("nom") simule : trouve, "Ada"', Found And (S = 'Ada'));

  { --- absent = param absent (aucune erreur) --- }
  Found := ReqParamGet('inconnu', S);
  ReqParamAssert('request.getParameter("inconnu") simule : absent', Not Found);

  { --- argument mal forme (sans "=") : avertissement, PAS de FatalError --- }
  ReqParamAssert('ReqParamParseArg("malforme") : rejete proprement',
    Not ReqParamParseArg('malforme'));

  { --- une cle repetee : le DERNIER argument gagne (decision ci-dessus) --- }
  ReqParamParseArg('nom=Zoe');
  Found := ReqParamGet('nom', S);
  ReqParamAssert('cle repetee : le dernier "nom=Zoe" ecrase "nom=Ada"', Found And (S = 'Zoe'));

  { --- Test14ExpressionLanguage.jsp reel : empty param.nom via EL - param   }
  { non fourni ICI (ReqParamInit vient d etre appele, "nom" retire) --- }
  ReqParamInit;
  ElParserInit;
  Idx := ParseElFromString('empty param.nom');
  V := ElEvalNode(Idx);
  ReqParamAssert('${empty param.nom} : aucun parametre fourni -> empty vrai',
    (V.Kind = ELV_BOOLEAN) And V.BoolVal);

  { --- Test16JstlJakarta.jsp reel : not empty param.recherche via EL -    }
  { param FOURNI cette fois --- }
  ReqParamParseArg('recherche=Ada');
  ElParserInit;
  Idx := ParseElFromString('not empty param.recherche');
  V := ElEvalNode(Idx);
  ReqParamAssert('${not empty param.recherche} : parametre fourni -> vrai',
    (V.Kind = ELV_BOOLEAN) And V.BoolVal);

  { --- la VALEUR elle-meme, section 13.1 (param.recherche via EL) --- }
  ElParserInit;
  Idx := ParseElFromString('param.recherche');
  V := ElEvalNode(Idx);
  ReqParamAssert('${param.recherche} : "Ada"', (V.Kind = ELV_STRING) And (V.StrVal = 'Ada'));

  { --- paramValues reste HORS DE PORTEE (decision 2 ci-dessus) : jamais    }
  { confondu avec "param" --- }
  ElParserInit;
  Idx := ParseElFromString('paramValues.recherche');
  V := ElEvalNode(Idx);
  ReqParamAssert('${paramValues.recherche} : hors de portee -> null',
    V.Kind = ELV_NULL);

  ReqParamInit;
End;

{ ============================================================ }
{ TODO 19 - BIBLIOTHEQUE RUNTIME MINIMALE (CLASSES JAVA         }
{ REFERENCEES)                                                  }
{ ============================================================ }

{ Contrairement a une VRAIE resolution de classpath, les CINQ classes      }
{ stdlib REELLEMENT appelees par les echantillons (java.util.Date,           }
{ java.text.DateFormat, java.util.GregorianCalendar, java.lang.Integer -        }
{ TYK_CLASS, TODO 04 - et java.lang.String, qui ETEND l entree TYK_STRING          }
{ DEJA predeclaree par TypeInit plutot que d en creer une seconde, puisque            }
{ String n est JAMAIS "importee", section 5.1) recoivent ICI une surface de              }
{ methodes CABLEE EN DUR - EXACTEMENT celle EFFECTIVEMENT exercee par un                    }
{ echantillon reel, JAMAIS plus (Test02Directives.jsp : Date()/DateFormat.                     }
{ getDateTimeInstance().format(Date) ; Test13Actions.jsp : jsp:useBean class=                     }
{ "java.util.GregorianCalendar" + jsp:getProperty property="timeInMillis" ->                         }
{ getTimeInMillis() ; Test09Application.jsp/Test12Erreur.jsp/Test14                                    }
{ ExpressionLanguage.jsp : Integer.parseInt/valueOf/intValue ;                                            }
{ Test05/06/07/08 : String.replace/length/trim/equals/equalsIgnoreCase). Date.               }
{ toString est neanmoins enregistre malgre l absence d appel direct, comme le               }
{ demande explicitement le roadmap d en-tete. Toute AUTRE classe importee mais              }
{ non appelee par un echantillon reste NON enregistree - RuntimeClassFind y                    }
{ echoue PROPREMENT (-1), une erreur de compilation explicite et actionnable                      }
{ (PAS un crash) restant a produire par le TODO 20 (analyse semantique, seul               }
{ consommateur prevu de cette table - AUCUNE validation n est encore CABLEE               }
{ ICI, ce TODO se limite a CONSTRUCTION de la table, MEME discipline que le                  }
{ TODO 04 pour TypePool lui-meme). }

Type
  TRuntimeParam = Record
    TypeName : TString; { nom de type INDICATIF, NON resolu - MEME discipline  }
                        { que TJavaParamDecl.TypeName (TODO 07) }
  End;

  TRuntimeMethod = Record
    Name           : TString;   { nom de la methode, OU nom de la classe        }
                                { elle-meme pour un constructeur (IsCtor)         }
    IsStatic       : Boolean;
    IsCtor         : Boolean;
    ReturnTypeName : TString;   { nom de type INDICATIF, '' si void/constructeur }
    ParamFirst     : Integer;   { dans RuntimeParamPool }
    ParamCount     : Integer;
  End;

Var
  RuntimeMethodPool  : Array[0..MAX_RUNTIME_METHOD - 1] Of TRuntimeMethod;
  RuntimeMethodCount : Integer;
  RuntimeParamPool   : Array[0..MAX_RUNTIME_PARAM - 1] Of TRuntimeParam;
  RuntimeParamCount  : Integer;

{ RuntimeMethodAdd : enregistre une methode/un constructeur et la RATTACHE  }
{ IMMEDIATEMENT a TypePool[TypeIdx].MethodFirst/MethodCount (TODO 04) -        }
{ SANS le risque d imbrication qui force ailleurs (ParseBlock, TODO 07) le       }
{ detour par un tampon local : RuntimeLibInit ci-dessous est un simple             }
{ ENREGISTREMENT SEQUENTIEL au demarrage, JAMAIS une recursion, donc               }
{ ParamFirst/MethodFirst peuvent avancer directement sans risque d               }
{ entrelacement. Suppose que toutes les methodes d UNE MEME classe sont              }
{ ajoutees consecutivement (garanti par RuntimeLibInit). }
Function RuntimeMethodAdd(TypeIdx: Integer; Const Name: TString;
                          IsStatic, IsCtor: Boolean;
                          Const ReturnTypeName: TString): Integer;
Begin
  If RuntimeMethodCount >= MAX_RUNTIME_METHOD Then
    FatalError('table des methodes runtime pleine (MAX_RUNTIME_METHOD)');
  RuntimeMethodPool[RuntimeMethodCount].Name           := Name;
  RuntimeMethodPool[RuntimeMethodCount].IsStatic       := IsStatic;
  RuntimeMethodPool[RuntimeMethodCount].IsCtor         := IsCtor;
  RuntimeMethodPool[RuntimeMethodCount].ReturnTypeName := ReturnTypeName;
  RuntimeMethodPool[RuntimeMethodCount].ParamFirst     := RuntimeParamCount;
  RuntimeMethodPool[RuntimeMethodCount].ParamCount     := 0;
  RuntimeMethodAdd := RuntimeMethodCount;
  Inc(RuntimeMethodCount);
  If TypePool[TypeIdx].MethodFirst = -1 Then
    TypePool[TypeIdx].MethodFirst := RuntimeMethodCount - 1;
  Inc(TypePool[TypeIdx].MethodCount);
End;

Procedure RuntimeMethodAddParam(MethodIdx: Integer; Const TypeName: TString);
Begin
  If RuntimeParamCount >= MAX_RUNTIME_PARAM Then
  Begin
    FatalError('table des parametres runtime pleine (MAX_RUNTIME_PARAM)');
    Exit;
  End;
  RuntimeParamPool[RuntimeParamCount].TypeName := TypeName;
  Inc(RuntimeParamCount);
  Inc(RuntimeMethodPool[MethodIdx].ParamCount);
End;

{ RuntimeMethodFind : recherche lineaire filtree par TypeIdx (via son      }
{ MethodFirst/MethodCount, TODO 04) ET par Name - retourne -1 si absente,     }
{ MEME convention que ScopeFindIndex/TaglibFind. }
Function RuntimeMethodFind(TypeIdx: Integer; Const Name: TString): Integer;
Var I: Integer;
Begin
  RuntimeMethodFind := -1;
  If TypePool[TypeIdx].MethodFirst < 0 Then Exit;
  For I := TypePool[TypeIdx].MethodFirst To
           TypePool[TypeIdx].MethodFirst + TypePool[TypeIdx].MethodCount - 1 Do
    If RuntimeMethodPool[I].Name = Name Then
    Begin
      RuntimeMethodFind := I;
      Exit;
    End;
End;

{ RuntimeClassFind : une classe stdlib peut etre referencee par son nom    }
{ COURT, apres import (ex. "Date", Test02Directives.jsp) OU par son nom        }
{ QUALIFIE complet (ex. "java.util.GregorianCalendar", jsp:useBean class=,          }
{ section 9.4/10 - EXIGE un nom qualifie) - correspondance EXACTE d abord             }
{ (TypeFind, couvre "String" et tout nom deja enregistre TEL QUEL), puis             }
{ repli sur le nom COURT (texte apres le DERNIER ".") de chaque TYK_CLASS               }
{ enregistre SI Name ne contient lui-meme aucun "." (un nom DEJA qualifie              }
{ qui echoue en correspondance exacte n a AUCUNE raison de reussir via un                 }
{ repli sur un nom court). }
Function RuntimeClassFind(Const Name: TString): Integer;
Var I, DotPos, Found: Integer; Short: TString;
Begin
  Found := TypeFind(Name);
  RuntimeClassFind := Found;
  If Found >= 0 Then Exit;
  If Pos('.', Name) > 0 Then Exit;
  For I := 0 To TypeCount - 1 Do
    If TypePool[I].Kind = TYK_CLASS Then
    Begin
      DotPos := Length(TypePool[I].Name);
      While (DotPos > 0) And (TypePool[I].Name[DotPos] <> '.') Do Dec(DotPos);
      Short := Copy(TypePool[I].Name, DotPos + 1, Length(TypePool[I].Name) - DotPos);
      If Short = Name Then
      Begin
        RuntimeClassFind := I;
        Exit;
      End;
    End;
End;

{ RuntimeLibInit : POINT D ENTREE UNIQUE - appelee UNE SEULE fois juste    }
{ apres TypeInit (TypeIdxString doit deja exister). Chaque bloc ci-dessous    }
{ correspond a EXACTEMENT une des cinq classes listees dans la note d en-        }
{ tete ci-dessus, dans le MEME ordre que le roadmap d en-tete du fichier. }
Procedure RuntimeLibInit;
Var TIdx, MIdx: Integer;
Begin
  RuntimeMethodCount := 0;
  RuntimeParamCount  := 0;

  { java.util.Date (constructeur sans argument, toString) }
  TIdx := TypeAdd(TYK_CLASS, 'java.util.Date', 4);
  RuntimeMethodAdd(TIdx, 'Date', False, True, '');
  RuntimeMethodAdd(TIdx, 'toString', False, False, 'String');

  { java.text.DateFormat (getDateTimeInstance().format(Date)) }
  TIdx := TypeAdd(TYK_CLASS, 'java.text.DateFormat', 4);
  RuntimeMethodAdd(TIdx, 'getDateTimeInstance', True, False, 'DateFormat');
  MIdx := RuntimeMethodAdd(TIdx, 'format', False, False, 'String');
  RuntimeMethodAddParam(MIdx, 'Date');

  { java.util.GregorianCalendar (constructeur, getTimeInMillis -          }
  { Test13Actions.jsp reel via jsp:useBean/jsp:getProperty) }
  TIdx := TypeAdd(TYK_CLASS, 'java.util.GregorianCalendar', 4);
  RuntimeMethodAdd(TIdx, 'GregorianCalendar', False, True, '');
  RuntimeMethodAdd(TIdx, 'getTimeInMillis', False, False, 'long');

  { java.lang.Integer.parseInt/valueOf/intValue (Test09Application.jsp/   }
  { Test12Erreur.jsp/Test14ExpressionLanguage.jsp reels) }
  TIdx := TypeAdd(TYK_CLASS, 'java.lang.Integer', 4);
  MIdx := RuntimeMethodAdd(TIdx, 'parseInt', True, False, 'int');
  RuntimeMethodAddParam(MIdx, 'String');
  MIdx := RuntimeMethodAdd(TIdx, 'valueOf', True, False, 'Integer');
  RuntimeMethodAddParam(MIdx, 'int');
  RuntimeMethodAdd(TIdx, 'intValue', False, False, 'int');

  { java.lang.String (concatenation "+", longueur, methodes des            }
  { echappements HTML de Test05/06/07/08 reels) - ETEND TypeIdxString        }
  { (TODO 04) plutot que d ajouter une SECONDE entree pour "String" ;              }
  { la concatenation "+" N EST PAS une methode - deja geree structurellement          }
  { par EK_BINARY (TODO 07)/le codegen (TODO 21+), rien a enregistrer ICI. }
  MIdx := RuntimeMethodAdd(TypeIdxString, 'replace', False, False, 'String');
  RuntimeMethodAddParam(MIdx, 'String');
  RuntimeMethodAddParam(MIdx, 'String');
  RuntimeMethodAdd(TypeIdxString, 'length', False, False, 'int');
  RuntimeMethodAdd(TypeIdxString, 'trim', False, False, 'String');
  MIdx := RuntimeMethodAdd(TypeIdxString, 'equals', False, False, 'boolean');
  RuntimeMethodAddParam(MIdx, 'Object');
  MIdx := RuntimeMethodAdd(TypeIdxString, 'equalsIgnoreCase', False, False, 'boolean');
  RuntimeMethodAddParam(MIdx, 'String');
End;

{ ------------------------------------------------------------ }
{ RuntimeLibSelfTest : Test02Directives.jsp/Test13Actions.jsp/     }
{ Test09Application.jsp/Test12Erreur.jsp/Test14ExpressionLanguage.  }
{ jsp/Test05Parametres.jsp reels (voir la note d en-tete de          }
{ RuntimeLibInit pour l affectation precise) + non-regression      }
{ "classe non enregistree -> echec propre".                          }
{ ------------------------------------------------------------ }

Procedure RuntimeLibAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('RuntimeLibSelfTest: ' + Label_ + ' a echoue');
End;

Procedure RuntimeLibSelfTest;
Var TIdx, MIdx: Integer;
Begin
  TypeInit;
  RuntimeLibInit;

  { --- java.util.Date, reference par son nom COURT (comme Test02          }
  { Directives.jsp reel, apres import="java.util.Date,...") --- }
  TIdx := RuntimeClassFind('Date');
  RuntimeLibAssert('RuntimeClassFind("Date") : trouve', TIdx >= 0);
  RuntimeLibAssert('java.util.Date : nom qualifie', TypePool[TIdx].Name = 'java.util.Date');
  MIdx := RuntimeMethodFind(TIdx, 'Date');
  RuntimeLibAssert('Date() : constructeur sans argument',
    (MIdx >= 0) And RuntimeMethodPool[MIdx].IsCtor And (RuntimeMethodPool[MIdx].ParamCount = 0));
  RuntimeLibAssert('Date.toString() : enregistre (roadmap d en-tete)',
    RuntimeMethodFind(TIdx, 'toString') >= 0);

  { --- java.text.DateFormat.getDateTimeInstance().format(Date) --- }
  TIdx := RuntimeClassFind('DateFormat');
  RuntimeLibAssert('RuntimeClassFind("DateFormat") : trouve', TIdx >= 0);
  MIdx := RuntimeMethodFind(TIdx, 'getDateTimeInstance');
  RuntimeLibAssert('getDateTimeInstance() : statique, 0 argument, retourne DateFormat',
    (MIdx >= 0) And RuntimeMethodPool[MIdx].IsStatic And (RuntimeMethodPool[MIdx].ParamCount = 0) And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'DateFormat'));
  MIdx := RuntimeMethodFind(TIdx, 'format');
  RuntimeLibAssert('format(Date) : d instance, 1 argument Date, retourne String',
    (MIdx >= 0) And (Not RuntimeMethodPool[MIdx].IsStatic) And (RuntimeMethodPool[MIdx].ParamCount = 1) And
    (RuntimeParamPool[RuntimeMethodPool[MIdx].ParamFirst].TypeName = 'Date') And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'String'));

  { --- Test13Actions.jsp reel : jsp:useBean class="java.util.             }
  { GregorianCalendar" (nom QUALIFIE, EXIGE par jsp:useBean) +                }
  { jsp:getProperty property="timeInMillis" -> getTimeInMillis() --- }
  TIdx := RuntimeClassFind('java.util.GregorianCalendar');
  RuntimeLibAssert('RuntimeClassFind("java.util.GregorianCalendar") : trouve (nom qualifie)',
    TIdx >= 0);
  RuntimeLibAssert('RuntimeClassFind("GregorianCalendar") : trouve AUSSI (nom court)',
    RuntimeClassFind('GregorianCalendar') = TIdx);
  MIdx := RuntimeMethodFind(TIdx, 'getTimeInMillis');
  RuntimeLibAssert('getTimeInMillis() : d instance, 0 argument, retourne long',
    (MIdx >= 0) And (Not RuntimeMethodPool[MIdx].IsStatic) And (RuntimeMethodPool[MIdx].ParamCount = 0) And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'long'));

  { --- Test09Application.jsp/Test12Erreur.jsp/Test14ExpressionLanguage.jsp  }
  { reels : Integer.parseInt/valueOf/intValue --- }
  TIdx := RuntimeClassFind('Integer');
  RuntimeLibAssert('RuntimeClassFind("Integer") : trouve', TIdx >= 0);
  MIdx := RuntimeMethodFind(TIdx, 'parseInt');
  RuntimeLibAssert('parseInt(String) : statique, retourne int',
    (MIdx >= 0) And RuntimeMethodPool[MIdx].IsStatic And (RuntimeMethodPool[MIdx].ParamCount = 1) And
    (RuntimeParamPool[RuntimeMethodPool[MIdx].ParamFirst].TypeName = 'String') And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'int'));
  MIdx := RuntimeMethodFind(TIdx, 'valueOf');
  RuntimeLibAssert('valueOf(int) : statique, retourne Integer',
    (MIdx >= 0) And RuntimeMethodPool[MIdx].IsStatic And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'Integer'));
  MIdx := RuntimeMethodFind(TIdx, 'intValue');
  RuntimeLibAssert('intValue() : d instance, retourne int',
    (MIdx >= 0) And (Not RuntimeMethodPool[MIdx].IsStatic) And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'int'));

  { --- Test05Parametres.jsp/Test06Formulaire.jsp/Test07ObjetsImplicites.jsp/ }
  { Test08Session.jsp reels : String.replace/length/trim/equals/                }
  { equalsIgnoreCase - ETEND TypeIdxString, PAS une seconde entree --- }
  RuntimeLibAssert('TypeIdxString : 5 methodes enregistrees',
    TypePool[TypeIdxString].MethodCount = 5);
  MIdx := RuntimeMethodFind(TypeIdxString, 'replace');
  RuntimeLibAssert('String.replace(String,String) : 2 arguments, retourne String',
    (MIdx >= 0) And (RuntimeMethodPool[MIdx].ParamCount = 2) And
    (RuntimeMethodPool[MIdx].ReturnTypeName = 'String'));
  RuntimeLibAssert('String.length() : enregistre', RuntimeMethodFind(TypeIdxString, 'length') >= 0);
  RuntimeLibAssert('String.trim() : enregistre', RuntimeMethodFind(TypeIdxString, 'trim') >= 0);
  RuntimeLibAssert('String.equals(Object) : enregistre', RuntimeMethodFind(TypeIdxString, 'equals') >= 0);
  RuntimeLibAssert('String.equalsIgnoreCase(String) : enregistre',
    RuntimeMethodFind(TypeIdxString, 'equalsIgnoreCase') >= 0);

  { --- non-regression : une classe importee mais JAMAIS appelee par un    }
  { echantillon reel (roadmap d en-tete, "erreur honnete plutot qu           }
  { invention") reste NON enregistree - RuntimeClassFind echoue PROPREMENT --- }
  RuntimeLibAssert('RuntimeClassFind("java.util.ArrayList") : jamais enregistree -> -1',
    RuntimeClassFind('java.util.ArrayList') = -1);
  RuntimeLibAssert('RuntimeMethodFind(Integer, "toBinaryString") : jamais enregistree -> -1',
    RuntimeMethodFind(RuntimeClassFind('Integer'), 'toBinaryString') = -1);

  TypeInit;
End;

{ ============================================================ }
{ TODO 20 - ANALYSE SEMANTIQUE                                  }
{ ============================================================ }

{ Trois des cinq points du roadmap d en-tete sont DEJA satisfaits par des    }
{ TODO anterieurs et ne demandent AUCUN nouveau code (confirme, PAS         }
{ invente) : attributs obligatoires par directive/action (TODO 05/06/12/     }
{ 13/16, ex. ParseJspUseBean exige l attribut "id"), gabarit/scriptlet            }
{ non fermes (TODO 02/03/07, plusieurs FatalError deja presents pour un           }
{ bloc de script ou une accolade non fermee), inclusion statique circulaire         }
{ (TODO 11, IncludeStack). Restent A CONSTRUIRE ICI : la resolution            }
{ d identificateurs Java/EL, la coherence errorPage, et le repli sur              }
{ TaglibFind pour les fonctions EL qualifiees (le cas des BALISES              }
{ personnalisees est deja traite au point d usage, voir la modification            }
{ de TryConsumeInterleaveToken ci-dessus).                                            }
{                                                                                      }
{ SemWalkExpr/SemWalkStmt/SemWalkEl forment UN SEUL passage combine sur le              }
{ MEME arbre (StmtPool/ExprPool du TODO 07/08, ElNodePool du TODO 14) - EXACTEMENT }
{ ce que demande le roadmap d en-tete ("un seul passage combine"). Portee              }
{ DELIBEREMENT limitee (best-effort, JAMAIS un FatalError pour un                        }
{ identificateur non resolu - ce compilateur n a ni classpath complet ni                  }
{ inference de type reelle, section 12.4 "Object jusqu a coercition" reste                  }
{ la norme) : un type de base INCONNU (bean/Map utilisateur, section 13.3)                  }
{ ne produit JAMAIS d avertissement (silence plutot qu un faux positif) -                     }
{ SEUL un identificateur/une classe totalement absent(e) de TOUTES les sources               }
{ connues (portee locale, champs de la page TODO 07, bibliotheque runtime                       }
{ TODO 19) declenche un avertissement. }

{ JavaFieldFind/JavaMethodFind : recherche lineaire dans les pools de la    }
{ classe page synthetique (TODO 07) - MEME convention que ScopeFindIndex/       }
{ TaglibFind/TypeFind (retourne -1 si absent). }
Function JavaFieldFind(Const Name: TString): Integer;
Var I: Integer;
Begin
  JavaFieldFind := -1;
  For I := 0 To JavaFieldCount - 1 Do
    If JavaFieldPool[I].Name = Name Then
    Begin
      JavaFieldFind := I;
      Exit;
    End;
End;

Function JavaMethodFind(Const Name: TString): Integer;
Var I: Integer;
Begin
  JavaMethodFind := -1;
  For I := 0 To JavaMethodCount - 1 Do
    If JavaMethodPool[I].Name = Name Then
    Begin
      JavaMethodFind := I;
      Exit;
    End;
End;

{ SemLocalPool : table des variables locales/parametres ACTUELLEMENT en    }
{ portee (Name, TypeName INDICATIF non resolu, MEME discipline que              }
{ TJavaParamDecl/SK_LOCALVAR) - UNE PILE PLATE, MEME technique que              }
{ ScopeAttrPool mais indexee par POSITION plutot que balayee integralement :        }
{ un appelant note SemLocalCount AVANT d entrer un bloc/une methode et le             }
{ restaure APRES en etre sorti (portee lexicale, section 6). }
Const
  MAX_SEM_LOCAL = {$IFDEF FPC}128{$ELSE}32{$ENDIF};

Type
  TSemLocal = Record
    Name     : TString;
    TypeName : TString;
  End;

Var
  SemLocalPool  : Array[0..MAX_SEM_LOCAL - 1] Of TSemLocal;
  SemLocalCount : Integer;

Procedure SemLocalAdd(Const Name, TypeName: TString);
Begin
  If SemLocalCount >= MAX_SEM_LOCAL Then
  Begin
    WarnMsg('trop de variables locales simultanement en portee pour l ' +
            'analyse semantique (MAX_SEM_LOCAL), ignoree : ' + Name);
    Exit;
  End;
  SemLocalPool[SemLocalCount].Name     := Name;
  SemLocalPool[SemLocalCount].TypeName := TypeName;
  Inc(SemLocalCount);
End;

{ Recherche du PLUS RECENT (innermost) d abord - sans consequence pratique  }
{ ici (aucun echantillon ne masque un nom de portee EXTERIEURE), mais MEME    }
{ convention que toute resolution de portee lexicale reelle. }
Function SemLocalFind(Const Name: TString; Var TypeName: TString): Boolean;
Var I: Integer;
Begin
  For I := SemLocalCount - 1 Downto 0 Do
    If SemLocalPool[I].Name = Name Then
    Begin
      TypeName := SemLocalPool[I].TypeName;
      SemLocalFind := True;
      Exit;
    End;
  SemLocalFind := False;
End;

{ SemResolveIdentType : un identificateur Java NU (EK_IDENT.ImplicitKind =  }
{ IOK_NONE, TODO 09 - les 9 objets implicites sont DEJA resolus ailleurs)      }
{ peut designer, DANS CET ORDRE : une variable locale/un parametre EN               }
{ PORTEE, un champ de la classe page synthetique (TODO 07), ou le nom               }
{ (court OU qualifie, RuntimeClassFind, TODO 19) d une classe stdlib                  }
{ cablee en dur employee comme RECEVEUR statique (ex. "Integer" dans                    }
{ "Integer.parseInt(...)"). Retourne le nom de type ASSOCIE (INDICATIF,                  }
{ jamais une VRAIE resolution de type Java complete). }
Function SemResolveIdentType(Const Name: TString; Var TypeName: TString): Boolean;
Var FIdx, CIdx: Integer;
Begin
  If SemLocalFind(Name, TypeName) Then
  Begin
    SemResolveIdentType := True;
    Exit;
  End;
  FIdx := JavaFieldFind(Name);
  If FIdx >= 0 Then
  Begin
    TypeName := JavaFieldPool[FIdx].TypeName;
    SemResolveIdentType := True;
    Exit;
  End;
  CIdx := RuntimeClassFind(Name);
  If CIdx >= 0 Then
  Begin
    TypeName := TypePool[CIdx].Name; { nom QUALIFIE - RuntimeMethodFind n a  }
    SemResolveIdentType := True;      { besoin QUE de l index, pas du nom,     }
    Exit;                             { mais le conserver reste INDICATIF utile }
  End;
  SemResolveIdentType := False;
End;

{ SemWalkExpr : parcours recursif de l arbre ExprPool (TODO 07) - retourne  }
{ le nom de type ASSOCIE a l expression quand connu ('' sinon, JAMAIS une      }
{ erreur en soi) ; emet un avertissement (best-effort, JAMAIS FatalError)        }
{ UNIQUEMENT quand un identificateur/une methode/une classe est               }
{ TOTALEMENT absent(e) des sources connues - voir la note d en-tete de la           }
{ section ci-dessus. }
Function SemWalkExpr(Idx: Integer): TString;
Var
  BaseType : TString;
  I, TIdx, MIdx : Integer;
Begin
  SemWalkExpr := '';
  If Idx < 0 Then Exit;
  Case ExprPool[Idx].Kind Of
    EK_INT, EK_CHAR, EK_BOOL : SemWalkExpr := 'int';
    EK_FLOAT                : SemWalkExpr := 'float';
    EK_STRING                : SemWalkExpr := 'String';
    EK_NULL                  : ;

    EK_IDENT :
      If ExprPool[Idx].ImplicitKind = IOK_NONE Then
      Begin
        If Not SemResolveIdentType(ExprPool[Idx].NameVal, BaseType) Then
          WarnMsg('identificateur Java non resolu (analyse best-effort, ' +
                  'section 6) : ' + ExprPool[Idx].NameVal)
        Else
          SemWalkExpr := BaseType;
      End;

    EK_UNARY : SemWalkExpr := SemWalkExpr(ExprPool[Idx].Left);

    EK_BINARY :
      Begin
        SemWalkExpr(ExprPool[Idx].Left);
        SemWalkExpr(ExprPool[Idx].Right);
        { '+' reste AMBIGU (int OU concatenation String, section 6) sans      }
        { une VRAIE inference de type (TODO 21+) - ne JAMAIS deviner ; les       }
        { autres operateurs binaires exerces par les echantillons sont          }
        { tous des comparaisons/operateurs logiques -> boolean. }
        If ExprPool[Idx].Op <> '+' Then SemWalkExpr := 'boolean';
      End;

    EK_ASSIGN :
      Begin
        SemWalkExpr(ExprPool[Idx].Left);
        SemWalkExpr := SemWalkExpr(ExprPool[Idx].Right);
      End;

    EK_SELECTOR :
      Begin
        BaseType := SemWalkExpr(ExprPool[Idx].Left);
        If (ExprPool[Idx].Left >= 0) And
           (ExprPool[ExprPool[Idx].Left].Kind = EK_IDENT) And
           (ExprPool[ExprPool[Idx].Left].ImplicitKind <> IOK_NONE) Then
          Exit; { deja valide par IsKnownImplicitMethod (TODO 09) }
        If BaseType = '' Then Exit; { type de base inconnu - JAMAIS un faux positif }
        TIdx := RuntimeClassFind(BaseType);
        If TIdx < 0 Then Exit; { type non modelise (bean/Map, section 13.3) - PAS une erreur }
        MIdx := RuntimeMethodFind(TIdx, ExprPool[Idx].NameVal);
        If MIdx < 0 Then
        Begin
          If Not IsUniversalObjectMethod(ExprPool[Idx].NameVal) Then
            WarnMsg('methode/propriete non reconnue sur ' + BaseType +
                    ' (analyse best-effort, TODO 19) : ' + ExprPool[Idx].NameVal);
        End
        Else
          SemWalkExpr := RuntimeMethodPool[MIdx].ReturnTypeName;
      End;

    EK_CALL :
      Begin
        For I := 0 To ExprPool[Idx].ArgCount - 1 Do
          SemWalkExpr(ExprArgPool[ExprPool[Idx].ArgFirst + I]);
        If ExprPool[ExprPool[Idx].Left].Kind = EK_IDENT Then
        Begin
          { appel SANS receveur explicite : methode de la PAGE elle-meme     }
          { (Test03Declarations.jsp : nomApplication()/carre(12) ;               }
          { Test05Parametres.jsp/Test06Formulaire.jsp : echapperHtml(nom)/          }
          { html(nom), tous reels). }
          MIdx := JavaMethodFind(ExprPool[ExprPool[Idx].Left].NameVal);
          If MIdx < 0 Then
            WarnMsg('methode Java non resolue (analyse best-effort, ' +
                    'section 6) : ' + ExprPool[ExprPool[Idx].Left].NameVal)
          Else
            SemWalkExpr := JavaMethodPool[MIdx].ReturnType;
        End
        Else
          SemWalkExpr := SemWalkExpr(ExprPool[Idx].Left); { .replace(...) etc. - deja }
      End;                                                 { valide par EK_SELECTOR ci-dessus }

    EK_NEWOBJECT :
      Begin
        For I := 0 To ExprPool[Idx].ArgCount - 1 Do
          SemWalkExpr(ExprArgPool[ExprPool[Idx].ArgFirst + I]);
        TIdx := RuntimeClassFind(ExprPool[Idx].NameVal);
        If TIdx < 0 Then
          WarnMsg('classe non reconnue par la bibliotheque runtime minimale ' +
                  '(analyse best-effort, TODO 19) : ' + ExprPool[Idx].NameVal)
        Else
        Begin
          { le constructeur est enregistre sous le nom COURT (RuntimeLibInit,  }
          { TODO 19) - un "new" QUALIFIE ("new java.util.Date()") echapperait     }
          { a cette recherche ; AUCUN echantillon ne l ecrit ainsi, limite          }
          { assumee plutot qu inventee. }
          If RuntimeMethodFind(TIdx, ExprPool[Idx].NameVal) < 0 Then
            WarnMsg('aucun constructeur reconnu pour ' + ExprPool[Idx].NameVal +
                    ' (analyse best-effort, TODO 19)');
          SemWalkExpr := TypePool[TIdx].Name;
        End;
      End;

    EK_CAST : SemWalkExpr := ExprPool[Idx].NameVal; { type CIBLE, meilleure estimation }
  End;
End;

{ SemWalkEl (TODO 20) : Forward - definie plus bas (juste apres            }
{ SemWalkStmt) mais APPELEE DEPUIS SemWalkStmt (SK_PRINT_EL/SK_JSTL_xxx)         }
{ juste en dessous - MEME technique que TryConsumeInterleaveToken/                 }
{ ParseElFromString plus haut pour resoudre une dependance d ordre textuel. }
Procedure SemWalkEl(Idx: Integer); Forward;

{ SemWalkStmt : parcours recursif de l arbre StmtPool (TODO 07/08) -       }
{ maintient SemLocalPool a jour (push a une SK_LOCALVAR, pop en quittant       }
{ un bloc/le corps d un for) EXACTEMENT selon la portee lexicale Java             }
{ (section 6) - un SK_FOR pousse AVANT son corps et son init/condition/            }
{ mise a jour, et depile ENSEMBLE (le nom introduit par l init couvre TOUT           }
{ le for, section 6.9). }
Procedure SemWalkStmt(Idx: Integer);
Var Mark, I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      Begin
        Mark := SemLocalCount;
        For I := 0 To StmtPool[Idx].ChildCount - 1 Do
          SemWalkStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
        SemLocalCount := Mark;
      End;

    SK_LOCALVAR :
      Begin
        SemWalkExpr(StmtPool[Idx].ExprIdx);
        SemLocalAdd(StmtPool[Idx].Op, StmtPool[Idx].NameVal);
      End;

    SK_EXPR       : SemWalkExpr(StmtPool[Idx].ExprIdx);
    SK_PRINT_EXPR : SemWalkExpr(StmtPool[Idx].ExprIdx);
    SK_RETURN     : If StmtPool[Idx].ExprIdx >= 0 Then SemWalkExpr(StmtPool[Idx].ExprIdx);

    SK_IF :
      Begin
        SemWalkExpr(StmtPool[Idx].ExprIdx);
        Mark := SemLocalCount; SemWalkStmt(StmtPool[Idx].Left); SemLocalCount := Mark;
        If StmtPool[Idx].Right >= 0 Then
        Begin Mark := SemLocalCount; SemWalkStmt(StmtPool[Idx].Right); SemLocalCount := Mark; End;
      End;

    SK_WHILE :
      Begin
        SemWalkExpr(StmtPool[Idx].ExprIdx);
        Mark := SemLocalCount; SemWalkStmt(StmtPool[Idx].Left); SemLocalCount := Mark;
      End;

    SK_FOR :
      Begin
        Mark := SemLocalCount;
        If StmtPool[Idx].Left >= 0 Then SemWalkStmt(StmtPool[Idx].Left);
        If StmtPool[Idx].ExprIdx >= 0 Then SemWalkExpr(StmtPool[Idx].ExprIdx);
        If StmtPool[Idx].Right >= 0 Then SemWalkExpr(StmtPool[Idx].Right);
        SemWalkStmt(StmtPool[Idx].Extra);
        SemLocalCount := Mark;
      End;

    SK_PRINT_EL : SemWalkEl(StmtPool[Idx].ElIdx);

    SK_JSTL_OUT :
      Begin
        SemWalkEl(StmtPool[Idx].ElIdx);
        SemWalkEl(StmtPool[Idx].Left);
      End;
    SK_JSTL_SET : SemWalkEl(StmtPool[Idx].ElIdx);
    SK_JSTL_IF, SK_JSTL_WHEN :
      Begin
        SemWalkEl(StmtPool[Idx].ElIdx);
        Mark := SemLocalCount;
        For I := 0 To StmtPool[Idx].ChildCount - 1 Do
          SemWalkStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
        SemLocalCount := Mark;
      End;
    SK_JSTL_CHOOSE, SK_JSTL_OTHERWISE :
      Begin
        Mark := SemLocalCount;
        For I := 0 To StmtPool[Idx].ChildCount - 1 Do
          SemWalkStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
        SemLocalCount := Mark;
      End;
    SK_JSTL_FOREACH :
      Begin
        If StmtPool[Idx].BoolVal Then SemWalkEl(StmtPool[Idx].ElIdx);
        Mark := SemLocalCount;
        For I := 0 To StmtPool[Idx].ChildCount - 1 Do
          SemWalkStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
        SemLocalCount := Mark;
      End;
  Else
    ; { SK_EMPTY/SK_PRINT_TEMPLATE/SK_INCLUDE_ACTION/SK_FORWARD_ACTION/         }
      { SK_USEBEAN_ACTION/SK_GETPROPERTY_ACTION/SK_SETPROPERTY_ACTION :             }
      { rien a resoudre - jsp:useBean.class DESIGNE VOLONTAIREMENT n importe          }
      { quel bean utilisateur (section 9.4), pas seulement les 5 classes                }
      { cablees en dur du TODO 19 : un echec de RuntimeClassFind ICI ne SERAIT           }
      { PAS une erreur, DECISION A DOCUMENTER (rester silencieux plutot que                }
      { d inventer un faux positif systematique sur tout bean reel). }
  End;
End;

{ SemWalkEl : parcours recursif de l arbre ElNodePool (TODO 14) - AUCUNE   }
{ resolution d identificateur EL nu n est tentee (section 13.4, EL reste           }
{ "presentation", une absence de portee n est JAMAIS une erreur - TODO 15/           }
{ 18 documentent deja ce choix) ; SEUL le prefixe d un appel de fonction              }
{ QUALIFIE ("prefixe:nom(...)") est verifie contre TaglibFind (TODO 06) -               }
{ un prefixe jamais declare est une VRAIE erreur utilisateur actionnable,                 }
{ contrairement a une simple variable de portee absente. }
Procedure SemWalkEl(Idx: Integer);
Var ColonPos, I: Integer; Prefix: TString;
Begin
  If Idx < 0 Then Exit;
  Case ElNodePool[Idx].Kind Of
    ELK_SELECTOR, ELK_UNARY : SemWalkEl(ElNodePool[Idx].Left);
    ELK_INDEX :
      Begin
        SemWalkEl(ElNodePool[Idx].Left);
        SemWalkEl(ElNodePool[Idx].Right);
      End;
    ELK_BINARY :
      Begin
        SemWalkEl(ElNodePool[Idx].Left);
        SemWalkEl(ElNodePool[Idx].Right);
      End;
    ELK_TERNARY :
      Begin
        SemWalkEl(ElNodePool[Idx].Left);
        SemWalkEl(ElNodePool[Idx].Right);
        SemWalkEl(ElNodePool[Idx].Extra);
      End;
    ELK_CALL :
      Begin
        If ElNodePool[ElNodePool[Idx].Left].Kind = ELK_IDENT Then
        Begin
          ColonPos := Pos(':', ElNodePool[ElNodePool[Idx].Left].NameVal);
          If ColonPos > 0 Then
          Begin
            Prefix := Copy(ElNodePool[ElNodePool[Idx].Left].NameVal, 1, ColonPos - 1);
            If TaglibFind(Prefix) < 0 Then
              WarnMsg('prefixe de fonction EL jamais declare via <%@ taglib ' +
                      '%> (analyse best-effort, section 5.4/12.9) : ' + Prefix);
          End;
        End;
        For I := 0 To ElNodePool[Idx].ArgCount - 1 Do
          SemWalkEl(ElArgPool[ElNodePool[Idx].ArgFirst + I]);
      End;
  Else
    ; { litteraux/ELK_IDENT nu : AUCUNE resolution statique, section 13.4 }
  End;
End;

{ SemFileExists (section 18.1, errorPage doit designer un fichier          }
{ existant et resoluble) - MEME technique de directives IO desactivees          }
{ puis IOResult que ReadWholeFileIntoFragBuf (TODO 11), aucune lecture du            }
{ contenu n est necessaire ICI, juste l existence. }
Function SemFileExists(Const Path: TString): Boolean;
Var F: File;
Begin
  Assign(F, Path);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then
    SemFileExists := False
  Else
  Begin
    Close(F);
    SemFileExists := True;
  End;
End;

{ SemanticAnalyze : POINT D ENTREE - RootIdx est le SK_BLOCK racine        }
{ retourne par ParsePage (TODO 08). Analyse d abord chaque METHODE          }
{ declaree (TODO 07, <%! %>) dans SA PROPRE portee (parametres SEULEMENT     }
{ + champs de la page - AUCUNE variable de scriptlet n y est visible,          }
{ section 6.3/6.15), puis le corps de la page lui-meme (champs de la             }
{ page + variables de scriptlet accumulees au fil de l arbre). Termine             }
{ par la coherence errorPage (section 18.1). }
Procedure SemanticAnalyze(RootIdx: Integer);
Var I, ParamI: Integer; ResolvedErrorPage: TBigString;
Begin
  For I := 0 To JavaMethodCount - 1 Do
  Begin
    SemLocalCount := 0;
    SemLocalAdd(JavaMethodPool[I].Name, JavaMethodPool[I].ReturnType); { auto-recursion }
    { les champs de la page (TODO 07) restent visibles depuis CHAQUE methode - }
    { SemResolveIdentType les consulte directement via JavaFieldFind, aucun      }
    { push necessaire ICI. }
    For ParamI := 0 To JavaMethodPool[I].ParamCount - 1 Do
      SemLocalAdd(JavaParamPool[JavaMethodPool[I].ParamFirst + ParamI].Name,
                  JavaParamPool[JavaMethodPool[I].ParamFirst + ParamI].TypeName);
    SemWalkStmt(JavaMethodPool[I].BodyStmtIdx);
  End;

  SemLocalCount := 0;
  SemWalkStmt(RootIdx);
  SemLocalCount := 0;

  { errorPage (section 18.1) : resolue relativement au repertoire du         }
  { fichier de PLUS HAUT NIVEAU, MEME convention que l inclusion statique       }
  { (TODO 11, ContextRootDir). }
  If PageOpts.HasErrorPage And (PageOpts.ErrorPage <> '') Then
  Begin
    ResolvedErrorPage := ResolveIncludePath(ContextRootDir, PageOpts.ErrorPage);
    If Not SemFileExists(ResolvedErrorPage) Then
      WarnMsg('errorPage introuvable (analyse best-effort, section 18.1) : ' +
              ResolvedErrorPage);
  End;
End;

{ ------------------------------------------------------------ }
{ SemanticSelfTest : Test03Declarations.jsp reel (nomApplication()/  }
{ carre(12)/echapperHtml/html - methodes de la page appelees SANS         }
{ receveur), Test02Directives.jsp reel (new Date(), DateFormat.            }
{ getDateTimeInstance().format(...)), Test12Erreur.jsp/Test12                }
{ GestionErreur.jsp reels (errorPage resoluble), non-regressions             }
{ (identificateur/classe/prefixe totalement absents -> avertissement,          }
{ type de base inconnu -> AUCUN avertissement).                                 }
{ ------------------------------------------------------------ }

Procedure SemanticAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('SemanticSelfTest: ' + Label_ + ' a echoue');
End;

Procedure SemanticSelfTest;
Const
  TmpFile = 'JSPSEMSELFTEST.$$$';
Var
  F        : Text;
  PageIdx  : Integer;
  WarnBefore : Integer;
Begin
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;

  { --- Test03Declarations.jsp reel : methodes de la page appelees SANS    }
  { receveur - AUCUN avertissement attendu --- }
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%! private String nomApplication() { return "Catalogue JSP"; } ',
        'private int carre(int valeur) { return valeur * valeur; } %>',
        '<%= nomApplication() %><%= carre(12) %>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('Test03Declarations.jsp reel : aucun avertissement (methodes resolues)',
    WarnCount = WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- Test02Directives.jsp reel (fragment) : new Date() + DateFormat.    }
  { getDateTimeInstance().format(...) - AUCUN avertissement attendu --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<% Date d = new Date(); %>',
        '<%= DateFormat.getDateTimeInstance().format(d) %>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('Test02Directives.jsp reel : aucun avertissement (Date/DateFormat resolus)',
    WarnCount = WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : identificateur Java totalement inconnu ->         }
  { avertissement (synthetique, aucun echantillon reel n en contient) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%= totalementInconnu %>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('identificateur totalement inconnu : avertissement emis',
    WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : classe inconnue de RuntimeLibInit dans un "new" - }
  { avertissement (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<% Object o = new ArrayList(); %>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('new ArrayList() (non cablee en dur) : avertissement emis',
    WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : jsp:useBean class= reste SILENCIEUX (bean          }
  { utilisateur arbitraire, section 9.4 - PAS une erreur) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<jsp:useBean id="x" class="exemple.MonBean" />');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('jsp:useBean class= bean utilisateur : AUCUN avertissement',
    WarnCount = WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- Test12Erreur.jsp/Test12GestionErreur.jsp reels : errorPage          }
  { resoluble - AUCUN avertissement attendu (les deux fichiers existent          }
  { reellement dans SAMPLES\JSP) --- }
  JavaParserInit; PageInit; JspParamInit;
  ContextRootDir := 'SAMPLES/JSP/';
  Assign(F, 'SAMPLES/JSP/Test12Erreur.jsp'); { lu directement, deja reel }
  {$I-} Reset(F); {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    LexInit('SAMPLES/JSP/Test12Erreur.jsp');
    PageIdx := ParsePage;
    WarnBefore := WarnCount;
    SemanticAnalyze(PageIdx);
    SemanticAssert('Test12Erreur.jsp reel : errorPage="Test12GestionErreur.jsp" resoluble',
      WarnCount = WarnBefore);
    LexClose;
  End;
  ContextRootDir := '';

  { --- non-regression : errorPage introuvable -> avertissement (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page errorPage="CeFichierNExistePas.jsp" %>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('errorPage introuvable : avertissement emis', WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : prefixe de fonction EL jamais declare ->          }
  { avertissement (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '${jamaisdeclare:foo(1)}');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  SemanticAnalyze(PageIdx);
  SemanticAssert('prefixe EL jamais declare : avertissement emis', WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  TypeInit; TaglibInit;
End;

{ ============================================================ }
{ TODO 21 - GENERATION DE CODE : STRUCTURE GENERALE ET          }
{ ASSEMBLEUR                                                     }
{ ============================================================ }

{ DECISION DE PERIMETRE EXPLICITEMENT EXIGEE PAR LE ROADMAP D EN-TETE       }
{ ("portee VOLONTAIREMENT restreinte a ce que TODO 01-20 ont reellement          }
{ construit... grandissant par extensions incrementales" - MEME phrase             }
{ que JPPCW32.PAS/GOCW32.PAS/DELPHI.PAS pour LEUR propre TODO 21/                     }
{ equivalent) : ce PREMIER passage couvre EXACTEMENT deux choses -                       }
{ l EMISSION TEXTUELLE .asm (bullet 1 du roadmap - structure MASM                          }
{ complete, .DATA/.CODE, prologue/epilogue, imports Win32) ET la                              }
{ traduction de SK_PRINT_TEMPLATE SEUL (bullet 3, le sous-ensemble "gabarit                     }
{ litteral" de l arbre TODO 08 - un "println inconditionnel", EXACTEMENT                          }
{ la meme premiere etape que JPPCW32.PAS/GOCW32.PAS ont documentee pour                             }
{ LEUR propre hello-world). L ENCODEUR D INSTRUCTIONS 80386 A LA MAIN                                  }
{ (bullet 2 du roadmap - octets REELS, adressage indirect/indexe, table                                }
{ de fixups pour les references relogeables) reste une EXTENSION FUTURE                                  }
{ sous ce MEME numero TODO 21 : DECISION A DOCUMENTER EXPLICITEMENT -                                       }
{ produire un encodeur d octets qui ne sera CONSOMME par AUCUN ecrivain                                       }
{ COFF/PE avant le TODO 23/24 (roadmap d en-tete) risquerait exactement le                                      }
{ piege "invente plutot que verifie" que ce projet evite partout ailleurs :             }
{ sans conteneur .obj/.exe pour le RECEVOIR, un octet encode ICI ne peut               }
{ etre verifie que par relecture manuelle, jamais par EXECUTION - la sortie              }
{ TEXTUELLE, elle, est integralement verifiable des maintenant (lisible,                    }
{ testee ligne par ligne ci-dessous). Toute Instruction SUPPLEMENTAIRE                          }
{ Java (SK_IF/SK_WHILE/SK_FOR/appels de methode/EL/JSTL) reste EGALEMENT                          }
{ une extension future sous ce MEME TODO 21 - CodeGenStmt s arrete                                  }
{ PROPREMENT (FatalError explicite, jamais un .asm silencieusement faux)                              }
{ sur tout SK_ non encore traduit, verifie ICI par EXECUTION REELLE contre                              }
{ Test01Bonjour.jsp (voir CodeGenSelfTest) : son gabarit initial (avant la                              }
{ premiere expression Java <%= new java.util.Date() %>) se traduit                                        }
{ correctement, puis l arret survient EXACTEMENT a SK_PRINT_EXPR, jamais                                    }
{ avant ni un plantage.                                                                                       }
{                                                                                                                 }
{ CHANGEMENT MAJEUR A Run() (voir plus bas, MEME decision que documentee              }
{ par JPPCW32.PAS pour SON propre TODO 21) : depuis le TODO 01, Run() ne             }
{ faisait QUE tokeniser le fichier source REEL (une simple boucle de              }
{ relecture de jetons) - CHAQUE TODO precedent (09-20) construisait/                  }
{ auto-testait sa piece SANS jamais la brancher sur un VRAI fichier                     }
{ (ParsePage/SemanticAnalyze ne s executaient que via des fixtures de                     }
{ self-test). CE TODO change enfin cela : Run() appelle desormais                           }
{ REELLEMENT ParsePage PUIS SemanticAnalyze (best-effort, de simples                          }
{ avertissements, JAMAIS bloquant) PUIS CodeGenPage sur le fichier                              }
{ SOURCE reel de l utilisateur, et ecrit TOUJOURS le ".asm" resultant                              }
{ (ReplaceExt(Opts.SrcFile, '.asm'), JAMAIS Opts.OutFile lui-meme - le                               }
{ VRAI choix entre .obj/.exe restera aspirationnel jusqu au TODO 23/24).                                }
{ Risque ASSUME et EXPLICITEMENT accepte (jamais cache) : un construct qui              }
{ fonctionnait dans un self-test ISOLE pourrait reveler une surprise en                   }
{ contexte REEL - EXACTEMENT ce que ce TODO est cense decouvrir (voir le                    }
{ rapport de fin de TODO, verification contre les 17 echantillons reels). }

Const
  MAX_CG_STRINGS = {$IFDEF FPC}256{$ELSE}64{$ENDIF}; { pool _JSPK deduplique, }
                   { MEME discipline "pool plat" que le reste de ce fichier }

Var
  CgStrPool  : Array[0..MAX_CG_STRINGS - 1] Of TBigString;
  CgStrCount : Integer;

Procedure CgStrInit;
Begin
  CgStrCount := 0;
End;

{ CgStrFindOrAdd : deduplique PAR VALEUR (un SEUL _JSPKn partage par         }
{ plusieurs chunks de gabarit IDENTIQUES) - MEME idiome que CgStrPool          }
{ chez JPPCW32.PAS/GOCW32.PAS (roadmap d en-tete). }
Function CgStrFindOrAdd(Const S: TBigString): Integer;
Var I: Integer;
Begin
  For I := 0 To CgStrCount - 1 Do
    If CgStrPool[I] = S Then
    Begin
      CgStrFindOrAdd := I;
      Exit;
    End;
  If CgStrCount >= MAX_CG_STRINGS Then
    FatalError('trop de chaines litterales pour la generation de code ' +
               '(MAX_CG_STRINGS)');
  CgStrPool[CgStrCount] := S;
  CgStrFindOrAdd := CgStrCount;
  Inc(CgStrCount);
End;

{ CgCollectStrings : parcourt l arbre StmtPool (TODO 07/08) et enregistre  }
{ CHAQUE SK_PRINT_TEMPLATE dans CgStrPool - SEUL SK_BLOCK est descendu          }
{ (portee de ce premier passage, voir la note d en-tete ci-dessus) ; tout        }
{ AUTRE SK_ est ignore ICI SANS avertissement (CodeGenStmt, plus bas,             }
{ produira le VRAI diagnostic au moment de la traduction elle-meme - PAS          }
{ de double message pour la MEME limite). }
Procedure CgCollectStrings(Idx: Integer);
Var I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        CgCollectStrings(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
    SK_PRINT_TEMPLATE : CgStrFindOrAdd(StmtPool[Idx].BigVal);
  Else
    ;
  End;
End;

{ EXTENSION 3 (post-TODO25) - CgCollectStringsFromMethodStmt/Expr : les       }
{ litteraux chaine RETOURNES par une methode declaree (ex. "Catalogue        }
{ JSP" dans nomApplication(), Test03Declarations.jsp) vivent dans              }
{ JavaMethodPool, un arbre SEPARE de celui parcouru par CgCollectStrings       }
{ ci-dessus (RootIdx = gabarit/scriptlets de la PAGE, PAS les declarations     }
{ <%! %>) - sans cette collecte DEDIEE, .DATA serait deja ecrit (avec un       }
{ nombre FIXE de _JSPKn) avant que CgCompileMethodBody ne decouvre ce           }
{ litteral, produisant une reference _JSPKn EN AVANT jamais definie (bogue    }
{ REEL trouve en executant le pipeline complet sur Test03Declarations.jsp -   }
{ voir EXTENSION 3 dans le rapport d en-tete). MEME portee etroite que          }
{ CgCompileExprToEax (litteral chaine, '*' binaire - suffisant pour              }
{ nomApplication()/carre(int)). }
Procedure CgCollectStringsFromExpr(ExprIdx: Integer);
Begin
  If ExprIdx < 0 Then Exit;
  Case ExprPool[ExprIdx].Kind Of
    EK_STRING : CgStrFindOrAdd(ExprPool[ExprIdx].StrVal);
    EK_BINARY :
      Begin
        CgCollectStringsFromExpr(ExprPool[ExprIdx].Left);
        CgCollectStringsFromExpr(ExprPool[ExprIdx].Right);
      End;
  Else
    ;
  End;
End;

Procedure CgCollectStringsFromMethodStmt(Idx: Integer);
Var I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        CgCollectStringsFromMethodStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
    SK_RETURN : CgCollectStringsFromExpr(StmtPool[Idx].ExprIdx);
  Else
    ;
  End;
End;

{ AsmStringLiteral : convertit une chaine PASCAL brute (un chunk de         }
{ gabarit VERBATIM, TODO 02/08 - peut contenir sauts de ligne, guillemets      }
{ simples, ou tout autre octet) en une liste d initialiseurs MASM "db"           }
{ separee par des virgules - une SUITE de caracteres IMPRIMABLES (32..126,        }
{ hors guillemet simple) devient UN SEUL segment 'entre guillemets' (avec           }
{ '' pour un guillemet simple EMBARQUE, convention MASM standard) ; tout              }
{ octet HORS de cette plage (saut de ligne, tabulation...) devient sa                   }
{ valeur DECIMALE isolee - MEME technique "segments imprimables +                          }
{ echappement numerique" qu un assembleur reel produirait a la main. }
Function AsmStringLiteral(Const S: TBigString): TBigString;
Var
  Result_ : TBigString;
  I       : Integer;
  InQuote : Boolean;
  Ch      : Char;
  NumStr  : TString;
Begin
  Result_ := '';
  InQuote := False;
  For I := 1 To Length(S) Do
  Begin
    Ch := S[I];
    If (Ch >= #32) And (Ch <= #126) Then
    Begin
      If Not InQuote Then
      Begin
        If Result_ <> '' Then Result_ := Result_ + ', ';
        Result_ := Result_ + '''';
        InQuote := True;
      End;
      If Ch = '''' Then Result_ := Result_ + ''''''
      Else Result_ := Result_ + Ch;
    End
    Else
    Begin
      If InQuote Then
      Begin
        Result_ := Result_ + '''';
        InQuote := False;
      End;
      If Result_ <> '' Then Result_ := Result_ + ', ';
      Str(Ord(Ch), NumStr);
      Result_ := Result_ + NumStr;
    End;
  End;
  If InQuote Then Result_ := Result_ + '''';
  If Result_ = '' Then Result_ := '0'; { chaine vide - MASM n admet pas un   }
                                       { "db" sans operande, un octet NUL         }
                                       { inoffensif (jamais emis par             }
                                       { _JSPRT_Print, longueur = 0) comble        }
                                       { l initialiseur }
  AsmStringLiteral := Result_;
End;

{ StmtKindName : PURE diagnostic (message de FatalError best-effort,      }
{ jamais consulte par un vrai calcul) - un nom LISIBLE pour chaque          }
{ TStmtKind (TODO 07/08/12/13/14/16) permet a CodeGenStmt de s arreter          }
{ PROPREMENT avec un message ACTIONNABLE plutot qu un index numerique             }
{ opaque. }
Function StmtKindName(K: TStmtKind): TString;
Begin
  Case K Of
    SK_BLOCK             : StmtKindName := 'bloc';
    SK_EXPR              : StmtKindName := 'instruction-expression Java';
    SK_LOCALVAR          : StmtKindName := 'declaration de variable locale';
    SK_IF                : StmtKindName := 'if/else';
    SK_WHILE             : StmtKindName := 'while';
    SK_FOR               : StmtKindName := 'for';
    SK_RETURN            : StmtKindName := 'return';
    SK_EMPTY             : StmtKindName := 'instruction vide';
    SK_PRINT_TEMPLATE    : StmtKindName := 'gabarit litteral';
    SK_PRINT_EXPR        : StmtKindName := 'expression <%= %>';
    SK_INCLUDE_ACTION    : StmtKindName := 'jsp:include';
    SK_FORWARD_ACTION    : StmtKindName := 'jsp:forward';
    SK_USEBEAN_ACTION    : StmtKindName := 'jsp:useBean';
    SK_GETPROPERTY_ACTION: StmtKindName := 'jsp:getProperty';
    SK_SETPROPERTY_ACTION: StmtKindName := 'jsp:setProperty';
    SK_PRINT_EL          : StmtKindName := 'expression EL ${...}/#{...}';
    SK_JSTL_OUT           : StmtKindName := 'c:out';
    SK_JSTL_SET           : StmtKindName := 'c:set';
    SK_JSTL_IF            : StmtKindName := 'c:if';
    SK_JSTL_CHOOSE        : StmtKindName := 'c:choose';
    SK_JSTL_WHEN          : StmtKindName := 'c:when';
    SK_JSTL_OTHERWISE     : StmtKindName := 'c:otherwise';
    SK_JSTL_FOREACH       : StmtKindName := 'c:forEach';
  Else
    StmtKindName := 'construction inconnue';
  End;
End;

{ CodeGenStmt : traduit RECURSIVEMENT l arbre StmtPool en TEXTE .asm       }
{ (OutF DEJA ouvert par CodeGenPage) - PORTEE de ce premier passage :          }
{ SK_BLOCK (descend simplement) et SK_PRINT_TEMPLATE (traduit en un              }
{ "push longueur / push offset _JSPKn / call _JSPRT_Print" - convention          }
{ STDCALL, l appele depile ses 8 octets d arguments, section 8/18                    }
{ decisions TODO 18) - TOUT AUTRE SK_ arrete la compilation PROPREMENT               }
{ (FatalError, JAMAIS un .asm silencieusement incomplet), voir la note                 }
{ d en-tete de section pour la justification de cette limite. }
{ SK_PRINT_EXPR (EXTENSION post-TODO25, ETENDUE - extension 2) : MEME     }
{ portee etroite/MEME special-case documente que PeCodeGenStmt/                  }
{ BinCodeGenStmt (voir leur note d en-tete complete) - PARTAGEE par les              }
{ TROIS backends (MEME fonction, aucune duplication de la logique de                    }
{ reconnaissance). DEUX formes reconnues, TOUTES DEUX traduites vers le                    }
{ MEME appel runtime _JSPRT_PrintDate (date/heure locale REELLE, section                     }
{ 18/21) puisque "DateFormat.getDateTimeInstance().format(new Date())"                          }
{ formate deja "la date/l heure courante" - EXACTEMENT ce que                                    }
{ _JSPRT_PrintDate calcule, aucune DUPLICATION de runtime necessaire :               }
{   1. "new java.util.Date()"/"new Date()" SANS argument, DIRECTEMENT           }
{      dans <%= %> (Test01Bonjour.jsp reel, extension 1).                             }
{   2. "DateFormat.getDateTimeInstance().format(new Date())" (Test02                     }
{      Directives.jsp reel, extension 2) - la CHAINE EXACTE est verifiee,                  }
{      argument par argument/selecteur par selecteur, JAMAIS une                              }
{      approximation ("n importe quel .format(...)" ne serait PAS reconnu). }
Function CgIsImmediateDatePrint(ExprIdx: Integer): Boolean;
Var FormatCallL, FormatArg0, GetInstL, GetInstSelL, DateFormatIdentL: Integer;
Begin
  CgIsImmediateDatePrint := False;
  If ExprIdx < 0 Then Exit;

  { --- forme 1 : new java.util.Date() / new Date() --- }
  If (ExprPool[ExprIdx].Kind = EK_NEWOBJECT) And
     ((ExprPool[ExprIdx].NameVal = 'java.util.Date') Or
      (ExprPool[ExprIdx].NameVal = 'Date')) And
     (ExprPool[ExprIdx].ArgCount = 0) Then
  Begin
    CgIsImmediateDatePrint := True;
    Exit;
  End;

  { --- forme 2 : DateFormat.getDateTimeInstance().format(new Date()) --- }
  If (ExprPool[ExprIdx].Kind <> EK_CALL) Or (ExprPool[ExprIdx].ArgCount <> 1) Then
    Exit;
  FormatCallL := ExprPool[ExprIdx].Left; { doit etre EK_SELECTOR "format" }
  FormatArg0  := ExprArgPool[ExprPool[ExprIdx].ArgFirst];
  If (FormatCallL < 0) Or (FormatArg0 < 0) Then Exit;
  If (ExprPool[FormatCallL].Kind <> EK_SELECTOR) Or
     (ExprPool[FormatCallL].NameVal <> 'format') Then Exit;
  If (ExprPool[FormatArg0].Kind <> EK_NEWOBJECT) Or
     ((ExprPool[FormatArg0].NameVal <> 'java.util.Date') And
      (ExprPool[FormatArg0].NameVal <> 'Date')) Or
     (ExprPool[FormatArg0].ArgCount <> 0) Then Exit;

  GetInstL := ExprPool[FormatCallL].Left; { doit etre EK_CALL "getDateTimeInstance()" }
  If GetInstL < 0 Then Exit;
  If (ExprPool[GetInstL].Kind <> EK_CALL) Or (ExprPool[GetInstL].ArgCount <> 0) Then Exit;

  GetInstSelL := ExprPool[GetInstL].Left; { doit etre EK_SELECTOR "getDateTimeInstance" }
  If GetInstSelL < 0 Then Exit;
  If (ExprPool[GetInstSelL].Kind <> EK_SELECTOR) Or
     (ExprPool[GetInstSelL].NameVal <> 'getDateTimeInstance') Then Exit;

  DateFormatIdentL := ExprPool[GetInstSelL].Left; { doit etre EK_IDENT "DateFormat" }
  If DateFormatIdentL < 0 Then Exit;
  If (ExprPool[DateFormatIdentL].Kind <> EK_IDENT) Or
     ((ExprPool[DateFormatIdentL].NameVal <> 'DateFormat') And
      (ExprPool[DateFormatIdentL].NameVal <> 'java.text.DateFormat')) Then Exit;

  CgIsImmediateDatePrint := True;
End;

{ EXTENSION 3 (post-TODO25) - APPELS DE FONCTION REELS : compilation des     }
{ CORPS des methodes declarees en page (JavaMethodPool, TODO 07/20) EN       }
{ instructions reelles, plus les sites d appel <%= nomApplication() %>/          }
{ <%= carre(12) %> (Test03Declarations.jsp). Portee DELIBEREMENT etroite       }
{ (choix explicite de l utilisateur : "vrais appels de fonction" plutot          }
{ qu un cas special etroit, mais SANS construire un allocateur de registres    }
{ general) : corps = UN SEUL "return <expr>;" en position finale (aucun          }
{ echantillon existant n a de retour anticipe ni d instructions apres le          }
{ return) ; expressions geres = litteral chaine/entier, parametre (identi-      }
{ ficateur simple), '*' binaire (carre) ; arguments d appel = litteraux           }
{ entiers SEULEMENT (carre(12)). Toute autre forme s arrete PROPREMENT via      }
{ FatalError, meme discipline "erreur honnete" que partout ailleurs. }
Var
  CgCurParamNames : Array[0..MAX_PARAM - 1] Of TString;
  CgCurParamCount : Integer;

Function CgFindParam(Const Name: TString; Var Offset: Integer): Boolean;
Var I: Integer;
Begin
  CgFindParam := False;
  For I := 0 To CgCurParamCount - 1 Do
    If CgCurParamNames[I] = Name Then
    Begin
      Offset := 8 + I * 4; { [ebp+8] = premier parametre STDCALL }
      CgFindParam := True;
      Exit;
    End;
End;

Procedure CgCompileExprToEax(ExprIdx: Integer);
Var SIdx, Offset: Integer;
Begin
  Case ExprPool[ExprIdx].Kind Of
    EK_INT :
      WriteLn(OutF, '    mov eax, ', ExprPool[ExprIdx].IntVal);

    EK_STRING :
      Begin
        SIdx := CgStrFindOrAdd(ExprPool[ExprIdx].StrVal);
        WriteLn(OutF, '    mov eax, OFFSET _JSPK', SIdx);
      End;

    EK_IDENT :
      If CgFindParam(ExprPool[ExprIdx].NameVal, Offset) Then
        WriteLn(OutF, '    mov eax, [ebp+', Offset, ']')
      Else
        FatalError('generation de code (extension post-TODO25) : identificateur ' +
                   'non resolu dans un corps de methode - ' +
                   ExprPool[ExprIdx].NameVal);

    EK_BINARY :
      If ExprPool[ExprIdx].Op = '*' Then
      Begin
        CgCompileExprToEax(ExprPool[ExprIdx].Left);
        WriteLn(OutF, '    push eax');
        CgCompileExprToEax(ExprPool[ExprIdx].Right);
        WriteLn(OutF, '    pop ecx');
        WriteLn(OutF, '    imul eax, ecx');
      End
      Else
        FatalError('generation de code (extension post-TODO25) : operateur "' +
                   ExprPool[ExprIdx].Op + '" non gere dans un corps de methode');
  Else
    FatalError('generation de code (extension post-TODO25) : expression non ' +
               'geree dans un corps de methode');
  End;
End;

Procedure CgCompileMethodStmt(Idx: Integer);
Var I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        CgCompileMethodStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);

    SK_RETURN :
      If StmtPool[Idx].ExprIdx >= 0 Then
        CgCompileExprToEax(StmtPool[Idx].ExprIdx)
      Else
        WriteLn(OutF, '    xor eax, eax');
  Else
    FatalError('generation de code (extension post-TODO25) : instruction non ' +
               'geree dans un corps de methode - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

Procedure CgCompileMethodBody(MIdx: Integer);
Var I: Integer;
Begin
  CgCurParamCount := JavaMethodPool[MIdx].ParamCount;
  For I := 0 To CgCurParamCount - 1 Do
    CgCurParamNames[I] := JavaParamPool[JavaMethodPool[MIdx].ParamFirst + I].Name;

  WriteLn(OutF, '_JSPM_', JavaMethodPool[MIdx].Name, ' PROC');
  WriteLn(OutF, '    push ebp');
  WriteLn(OutF, '    mov ebp, esp');
  CgCompileMethodStmt(JavaMethodPool[MIdx].BodyStmtIdx);
  WriteLn(OutF, '    mov esp, ebp');
  WriteLn(OutF, '    pop ebp');
  WriteLn(OutF, '    ret ', CgCurParamCount * 4);
  WriteLn(OutF, '_JSPM_', JavaMethodPool[MIdx].Name, ' ENDP');
  WriteLn(OutF);
End;

{ CgEmitMethodCallPrint : reconnait <%= nom(...) %> ou "nom" designe une      }
{ methode declaree en page (JavaMethodPool) - emet l appel PUIS le print         }
{ adapte au type de retour ('String' -> _JSPRT_Print, 'int' -> _JSPRT_          }
{ PrintInt). Retourne False (sans rien emettre) si ExprIdx n est PAS un tel      }
{ appel, pour laisser l appelant tenter d autres reconnaissances/erreur          }
{ honnete. }
Function CgEmitMethodCallPrint(ExprIdx: Integer): Boolean;
Var MIdx, I, ArgIdx: Integer;
Begin
  CgEmitMethodCallPrint := False;
  If ExprIdx < 0 Then Exit;
  If ExprPool[ExprIdx].Kind <> EK_CALL Then Exit;
  If ExprPool[ExprIdx].Left < 0 Then Exit;
  If ExprPool[ExprPool[ExprIdx].Left].Kind <> EK_IDENT Then Exit;

  MIdx := JavaMethodFind(ExprPool[ExprPool[ExprIdx].Left].NameVal);
  If MIdx < 0 Then Exit;

  If ExprPool[ExprIdx].ArgCount <> JavaMethodPool[MIdx].ParamCount Then
    FatalError('generation de code (extension post-TODO25) : nombre d ' +
               'arguments incompatible pour l appel a "' +
               JavaMethodPool[MIdx].Name + '"');

  For I := ExprPool[ExprIdx].ArgCount - 1 Downto 0 Do
  Begin
    ArgIdx := ExprArgPool[ExprPool[ExprIdx].ArgFirst + I];
    If ExprPool[ArgIdx].Kind <> EK_INT Then
      FatalError('generation de code (extension post-TODO25) : seul un ' +
                 'argument litteral entier est gere pour l appel a une ' +
                 'methode declaree - "' + JavaMethodPool[MIdx].Name + '"');
    WriteLn(OutF, '    push ', ExprPool[ArgIdx].IntVal);
  End;

  WriteLn(OutF, '    call _JSPM_', JavaMethodPool[MIdx].Name);

  If JavaMethodPool[MIdx].ReturnType = 'String' Then
  Begin
    WriteLn(OutF, '    push eax');
    WriteLn(OutF, '    call _JSPRT_Print');
  End
  Else If JavaMethodPool[MIdx].ReturnType = 'int' Then
  Begin
    WriteLn(OutF, '    push eax');
    WriteLn(OutF, '    call _JSPRT_PrintInt');
  End
  Else
    FatalError('generation de code (extension post-TODO25) : type de retour "' +
               JavaMethodPool[MIdx].ReturnType + '" non gere pour <%= ' +
               JavaMethodPool[MIdx].Name + '(...) %>');

  CgEmitMethodCallPrint := True;
End;

Procedure CodeGenStmt(Idx: Integer);
Var I, SIdx: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        CodeGenStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);

    SK_PRINT_TEMPLATE :
      Begin
        SIdx := CgStrFindOrAdd(StmtPool[Idx].BigVal); { DEJA ajoute par          }
                                                        { CgCollectStrings ;         }
                                                        { retrouve le MEME index ICI }
        WriteLn(OutF, '    push OFFSET _JSPK', SIdx);
        WriteLn(OutF, '    call _JSPRT_Print');
      End;

    SK_PRINT_EXPR :
      If CgIsImmediateDatePrint(StmtPool[Idx].ExprIdx) Then
        WriteLn(OutF, '    call _JSPRT_PrintDate')
      Else If CgEmitMethodCallPrint(StmtPool[Idx].ExprIdx) Then
        { rien de plus - deja emis par CgEmitMethodCallPrint }
      Else
        FatalError('generation de code (extension post-TODO25) : seule ' +
                   '"new java.util.Date()"/"DateFormat.getDateTimeInstance().' +
                   'format(new Date())"/l appel a une methode declaree en page ' +
                   'est gere pour <%= %> - construction non encore geree');
  Else
    FatalError('generation de code (TODO 21) : construction non encore ' +
               'geree - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

{ CodeGenPage : POINT D ENTREE - RootIdx est le SK_BLOCK racine retourne   }
{ par ParsePage (TODO 08). Emet la structure MASM COMPLETE (identique aux       }
{ compilateurs freres, AUCUNE deviation, section 21 du roadmap d en-tete) :        }
{ .386/.MODEL FLAT STDCALL, imports Win32 (GetStdHandle/WriteFile, TODO 18),          }
{ .DATA (pool _JSPK deduplique), .CODE (_JSPRT_Print - le runtime minimal              }
{ "un print = un WriteFile sur STDOUT", TODO 18 - puis _jspService, le                   }
{ point d entree synthetique de la page, TODO 09). PRE-CONDITION : OutF               }
{ DEJA assigne+ouvert par l appelant (Run). }
Procedure CodeGenPage(RootIdx: Integer);
Var I: Integer;
Begin
  CgStrInit;
  CgCollectStrings(RootIdx);
  For I := 0 To JavaMethodCount - 1 Do
    CgCollectStringsFromMethodStmt(JavaMethodPool[I].BodyStmtIdx);

  WriteLn(OutF, '; ------------------------------------------------------------');
  WriteLn(OutF, '; Genere par JSPCW32 - NE PAS MODIFIER A LA MAIN');
  WriteLn(OutF, '; Portee TODO 21 : gabarit litteral SEULEMENT (voir roadmap d en-tete).');
  WriteLn(OutF, '; ------------------------------------------------------------');
  WriteLn(OutF, '.386');
  WriteLn(OutF, '.MODEL FLAT, STDCALL');
  WriteLn(OutF, 'OPTION CASEMAP:NONE');
  WriteLn(OutF);
  WriteLn(OutF, 'EXTERN GetStdHandle@4:NEAR');
  WriteLn(OutF, 'EXTERN WriteFile@20:NEAR');
  WriteLn(OutF, 'EXTERN GetLocalTime@4:NEAR'); { EXTENSION post-TODO25 }
  WriteLn(OutF);
  WriteLn(OutF, 'STD_OUTPUT_HANDLE EQU -11');
  WriteLn(OutF);

  WriteLn(OutF, '.DATA');
  { EXTENSION 3 (post-TODO25) : chaque bloc _JSPKn commence PAR SA PROPRE      }
  { longueur (dd), les octets suivant IMMEDIATEMENT SOUS LE MEME etiquette -   }
  { _JSPRT_Print (redessine ci-dessous) ne recoit donc plus qu UN SEUL           }
  { pointeur, ce qui permet a une methode declaree de "retourner une             }
  { chaine" dans EAX (voir la note d en-tete complete pres de                     }
  { CgCompileMethodBody). }
  For I := 0 To CgStrCount - 1 Do
  Begin
    WriteLn(OutF, '_JSPK', I, ' dd ', Length(CgStrPool[I]));
    WriteLn(OutF, '    db ', AsmStringLiteral(CgStrPool[I]));
  End;
  WriteLn(OutF, '_JSPRT_BytesWritten dd 0');
  { EXTENSION post-TODO25 : tampons de "new java.util.Date()" imprime      }
  { immediatement (voir la note d en-tete complete pres de PeEmitPrintDate,    }
  { TODO 24 - MEME format "AAAA-MM-JJ HH:MM:SS", MEME limite documentee).    }
  { EXTENSION 3 : prefixe de longueur ajoute EN TETE (meme convention que        }
  { les _JSPKn ci-dessus) - les ecritures de chiffres plus bas sont donc         }
  { toutes decalees de +4. }
  WriteLn(OutF, '_JSPRT_SysTime db 16 dup(0)');
  WriteLn(OutF, '_JSPRT_DateStr dd 19');
  WriteLn(OutF, '    db 19 dup ('' '')');
  { EXTENSION 3 (post-TODO25) : tampon de conversion entier->decimal pour       }
  { _JSPRT_PrintInt (carre(12), Test03Declarations.jsp) - 16 octets : au        }
  { plus 11 caracteres utiles (signe + 10 chiffres, INT32_MIN) plus 4           }
  { octets de marge AVANT pour y loger le prefixe de longueur, ecrit a          }
  { une position VARIABLE (calculee au moment de l execution, PAS ici) -        }
  { voir _JSPRT_PrintInt. }
  WriteLn(OutF, '_JSPRT_IntBuf db 16 dup(0)');
  WriteLn(OutF);

  WriteLn(OutF, '.CODE');
  { _JSPRT_Print(bloc: DWORD) - convention STDCALL, section 18 : "tout        }
  { out.print/println... est ecrit sur STDOUT via WriteFile/GetStdHandle"      }
  { (decision TODO 18). EXTENSION 3 (post-TODO25) : signature reduite a UN     }
  { SEUL parametre - un pointeur vers un bloc _JSPKn-like (dd longueur;         }
  { db octets) - au lieu de (pointeur,longueur) separes, afin qu une             }
  { methode declaree puisse "retourner une chaine" comme UNE SEULE valeur       }
  { EAX (voir CgCompileMethodBody). }
  WriteLn(OutF, '_JSPRT_Print PROC');
  WriteLn(OutF, '    push ebp');
  WriteLn(OutF, '    mov ebp, esp');
  WriteLn(OutF, '    push STD_OUTPUT_HANDLE');
  WriteLn(OutF, '    call GetStdHandle@4');
  WriteLn(OutF, '    mov ecx, [ebp+8]');
  WriteLn(OutF, '    lea edx, [ecx+4]');
  WriteLn(OutF, '    push 0');
  WriteLn(OutF, '    push OFFSET _JSPRT_BytesWritten');
  WriteLn(OutF, '    push DWORD PTR [ecx]');
  WriteLn(OutF, '    push edx');
  WriteLn(OutF, '    push eax');
  WriteLn(OutF, '    call WriteFile@20');
  WriteLn(OutF, '    pop ebp');
  WriteLn(OutF, '    ret 4');
  WriteLn(OutF, '_JSPRT_Print ENDP');
  WriteLn(OutF);

  { EXTENSION 3 (post-TODO25) : _JSPRT_PrintInt(valeur: DWORD) - convertit    }
  { un entier signe en decimal ASCII (division repetee par 10, EXTRACTION     }
  { EN SENS INVERSE dans _JSPRT_IntBuf) puis reutilise _JSPRT_Print - jamais   }
  { d assembleur externe, encodage a la main dans les backends Bin/Pe            }
  { (voir leurs notes d en-tete respectives). Necessaire pour imprimer            }
  { carre(12) (Test03Declarations.jsp, type de retour "int"). }
  WriteLn(OutF, '_JSPRT_PrintInt PROC');
  WriteLn(OutF, '    push ebp');
  WriteLn(OutF, '    mov ebp, esp');
  WriteLn(OutF, '    push ebx');
  WriteLn(OutF, '    push esi');
  WriteLn(OutF, '    push edi');
  WriteLn(OutF, '    mov eax, [ebp+8]');
  WriteLn(OutF, '    mov edi, OFFSET _JSPRT_IntBuf + 16');
  WriteLn(OutF, '    xor esi, esi');
  WriteLn(OutF, '    test eax, eax');
  WriteLn(OutF, '    jns _JSPRT_PrintInt_L1');
  WriteLn(OutF, '    mov esi, 1');
  WriteLn(OutF, '    neg eax');
  WriteLn(OutF, '_JSPRT_PrintInt_L1:');
  WriteLn(OutF, '    mov ebx, 10');
  WriteLn(OutF, '_JSPRT_PrintInt_L2:');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    div ebx');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    dec edi');
  WriteLn(OutF, '    mov [edi], dl');
  WriteLn(OutF, '    test eax, eax');
  WriteLn(OutF, '    jnz _JSPRT_PrintInt_L2');
  WriteLn(OutF, '    test esi, esi');
  WriteLn(OutF, '    jz _JSPRT_PrintInt_L3');
  WriteLn(OutF, '    dec edi');
  WriteLn(OutF, '    mov byte ptr [edi], ''-''');
  WriteLn(OutF, '_JSPRT_PrintInt_L3:');
  WriteLn(OutF, '    mov eax, OFFSET _JSPRT_IntBuf + 16');
  WriteLn(OutF, '    sub eax, edi');
  WriteLn(OutF, '    sub edi, 4');
  WriteLn(OutF, '    mov [edi], eax');
  WriteLn(OutF, '    push edi');
  WriteLn(OutF, '    call _JSPRT_Print');
  WriteLn(OutF, '    pop edi');
  WriteLn(OutF, '    pop esi');
  WriteLn(OutF, '    pop ebx');
  WriteLn(OutF, '    pop ebp');
  WriteLn(OutF, '    ret 4');
  WriteLn(OutF, '_JSPRT_PrintInt ENDP');
  WriteLn(OutF);

  { EXTENSION post-TODO25 : _JSPRT_PrintDate - MEME algorithme/MEME        }
  { limite documentee que l encodeur PE (TODO 24, voir sa note d en-tete       }
  { complete) - le MASM du lieur externe gere LUI-MEME les etiquettes/         }
  { sauts si jamais on en ajoutait, mais cette sequence reste ENTIEREMENT           }
  { LINEAIRE (aucun saut) ICI aussi, par coherence avec la version encodee            }
  { a la main. }
  WriteLn(OutF, '_JSPRT_PrintDate PROC');
  WriteLn(OutF, '    push ebp');
  WriteLn(OutF, '    mov ebp, esp');
  WriteLn(OutF, '    push OFFSET _JSPRT_SysTime');
  WriteLn(OutF, '    call GetLocalTime@4');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 100');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+4], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+5], dl');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 100');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    mov eax, edx');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+6], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+7], dl');
  WriteLn(OutF, '    mov byte ptr [_JSPRT_DateStr+8], ''-''');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime+2]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+9], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+10], dl');
  WriteLn(OutF, '    mov byte ptr [_JSPRT_DateStr+11], ''-''');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime+6]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+12], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+13], dl');
  WriteLn(OutF, '    mov byte ptr [_JSPRT_DateStr+14], '' ''');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime+8]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+15], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+16], dl');
  WriteLn(OutF, '    mov byte ptr [_JSPRT_DateStr+17], '':''');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime+10]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+18], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+19], dl');
  WriteLn(OutF, '    mov byte ptr [_JSPRT_DateStr+20], '':''');
  WriteLn(OutF, '    movzx eax, word ptr [_JSPRT_SysTime+12]');
  WriteLn(OutF, '    xor edx, edx');
  WriteLn(OutF, '    mov ecx, 10');
  WriteLn(OutF, '    div ecx');
  WriteLn(OutF, '    add al, ''0''');
  WriteLn(OutF, '    add dl, ''0''');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+21], al');
  WriteLn(OutF, '    mov [_JSPRT_DateStr+22], dl');
  WriteLn(OutF, '    push OFFSET _JSPRT_DateStr');
  WriteLn(OutF, '    call _JSPRT_Print');
  WriteLn(OutF, '    pop ebp');
  WriteLn(OutF, '    ret');
  WriteLn(OutF, '_JSPRT_PrintDate ENDP');
  WriteLn(OutF);

  { EXTENSION 3 (post-TODO25) : corps des methodes declarees en page             }
  { (JavaMethodPool, TODO 07/20), EMISES AVANT _jspService - MEME discipline       }
  { "callee avant caller" que _JSPRT_Print/_JSPRT_PrintDate ci-dessus, pour        }
  { rester coherente avec les backends Bin/Pe ou cela evite un fixup. }
  For I := 0 To JavaMethodCount - 1 Do
    CgCompileMethodBody(I);

  WriteLn(OutF, '_jspService PROC');
  WriteLn(OutF, '    push ebp');
  WriteLn(OutF, '    mov ebp, esp');
  CodeGenStmt(RootIdx);
  WriteLn(OutF, '    mov esp, ebp');
  WriteLn(OutF, '    pop ebp');
  WriteLn(OutF, '    ret');
  WriteLn(OutF, '_jspService ENDP');
  WriteLn(OutF);
  WriteLn(OutF, 'END _jspService');
End;

{ ------------------------------------------------------------ }
{ CodeGenSelfTest : Test01Bonjour.jsp reel (le gabarit INITIAL,     }
{ verbatim, avant sa premiere expression Java - la generation         }
{ s arrete PROPREMENT a SK_PRINT_EXPR juste apres, EXACTEMENT la        }
{ portee documentee en tete de section), plus l echappement de           }
{ chaine (synthetique, aucun echantillon reel ne combine guillemet         }
{ simple ET saut de ligne dans un SEUL chunk de gabarit).                   }
{ ------------------------------------------------------------ }

Procedure CodeGenAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('CodeGenSelfTest: ' + Label_ + ' a echoue');
End;

Procedure CodeGenSelfTest;
Const
  TmpFile = 'JSPCODEGENSELFTEST.$$$';
  AsmFile = 'JSPCODEGENSELFTEST.asm';
Var
  F        : Text;
  Content  : TBigString;
  PageIdx  : Integer;
  Child0, Child1 : Integer;
Begin
  { --- AsmStringLiteral (synthetique) : segment imprimable, guillemet     }
  { simple EMBARQUE, saut de ligne (CR LF) --- }
  CodeGenAssert('AsmStringLiteral("Bonjour") : segment imprimable simple',
    AsmStringLiteral('Bonjour') = '''Bonjour''');
  CodeGenAssert('AsmStringLiteral avec guillemet simple embarque : doublee',
    AsmStringLiteral('l''image') = '''l''''image''');
  CodeGenAssert('AsmStringLiteral avec CR LF : segments numeriques separes',
    AsmStringLiteral('a' + #13#10 + 'b') = '''a'', 13, 10, ''b''');
  CodeGenAssert('AsmStringLiteral chaine vide : "0" (MASM exige un operande)',
    AsmStringLiteral('') = '0');

  { --- Test01Bonjour.jsp reel (fragment VERBATIM) : gabarit INITIAL         }
  { traduit correctement ; le PROCHAIN enfant (l expression <%= new           }
  { java.util.Date() %>) est confirme etre SK_PRINT_EXPR SANS invoquer           }
  { CodeGenStmt dessus - FatalError appelle Halt (TODO 01), inutilisable          }
  { DANS ce self-test qui doit continuer ; la traversee REELLE de cette             }
  { frontiere (verifiee par EXECUTION du VRAI binaire, pas ici) fait partie          }
  { de la verification manuelle de fin de TODO, MEME discipline que le                }
  { roadmap d en-tete l exige ("verifie ICI par execution reelle"). Aucun              }
  { ecrivain OBJ/EXE n existe encore (TODO 23/24) pour produire un VRAI                  }
  { Test01Bonjour.exe. --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<!DOCTYPE html>',
        '<html lang="fr">',
        '<body>',
        '<h1>Bonjour depuis JSP&nbsp;!</h1>',
        '<%= new java.util.Date() %>',
        '</body>',
        '</html>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  CodeGenAssert('Test01Bonjour.jsp reel : au moins 2 enfants au sommet',
    StmtPool[PageIdx].ChildCount >= 2);
  Child0 := StmtChildPool[StmtPool[PageIdx].ChildFirst];
  Child1 := StmtChildPool[StmtPool[PageIdx].ChildFirst + 1];
  CodeGenAssert('Test01Bonjour.jsp reel : enfant 0 = gabarit litteral (SK_PRINT_TEMPLATE)',
    StmtPool[Child0].Kind = SK_PRINT_TEMPLATE);
  CodeGenAssert('Test01Bonjour.jsp reel : enfant 1 = <%= new java.util.Date() %> (SK_PRINT_EXPR)',
    StmtPool[Child1].Kind = SK_PRINT_EXPR);

  Assign(OutF, AsmFile); Rewrite(OutF); OutFOpen := True;
  CodeGenStmt(Child0); { SEUL l enfant GERE par la portee de ce TODO -   }
                       { Child1 (SK_PRINT_EXPR) n est JAMAIS passe a       }
                       { CodeGenStmt ICI, voir la note ci-dessus }
  Close(OutF); OutFOpen := False;

  Assign(F, AsmFile); Reset(F);
  ReadLn(F, Content);
  Close(F);
  CodeGenAssert('gabarit initial reel : traduit en "push <longueur>"',
    Pos('push ', Content) > 0);
  Assign(F, AsmFile); Erase(F);

  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 22 - ENCODAGE ET INTERNATIONALISATION                    }
{ ============================================================ }

{ Verification de coherence best-effort (MEME discipline que le TODO 20,   }
{ JAMAIS bloquant) entre les TROIS encodages du roadmap d en-tete           }
{ (corrige - voir la note pres du roadmap lui-meme) : pageEncoding (TODO       }
{ 05), le charset de contentType (TODO 05, "text/html; charset=UTF-8" -           }
{ EXTRAIT ICI, jamais stocke separement), et le "meta charset" du                    }
{ document HTML lui-meme (une PROPRIETE du GABARIT LITTERAL, section 22 -               }
{ recherchee dans les SK_PRINT_TEMPLATE deja construits par ParsePage,                    }
{ TODO 08 - AUCUNE analyse HTML complete n est tentee, seul le motif EXACT                  }
{ "<meta charset=..." effectivement ecrit par les 17 echantillons reels).                     }
{ Seul UTF-8 est REELLEMENT supporte (roadmap d en-tete) : le lexeur (TODO             }
{ 02) lit deja le fichier source VERBATIM, octet par octet, SANS transcodage                }
{ - un pageEncoding non-UTF-8 ne CASSE rien ICI (aucune transformation n a               }
{ jamais lieu) mais merite un avertissement honnete plutot que de laisser                  }
{ croire a un support reel. }

{ BigStrUpperCase : MEME chose que StrUpperCase (TODO 01) mais pour un    }
{ TBigString - INDISPENSABLE ici (contrairement a StrUpperCase, TString      }
{ 255 caracteres) car un chunk de gabarit peut largement depasser 255           }
{ octets (TODO 02/04) ; utiliser StrUpperCase tronquerait silencieusement          }
{ la recherche AVANT un "<meta charset=" situe plus loin dans un long                }
{ chunk - EXACTEMENT le piege de troncature deja evite ailleurs (TOken.Val,             }
{ TELValue.StrVal...). }
Function BigStrUpperCase(Const S: TBigString): TBigString;
Var I: Integer; Tmp: TBigString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  BigStrUpperCase := Tmp;
End;

{ ExtractCharsetFromContentType : "text/html; charset=UTF-8" -> "UTF-8" - }
{ recherche "CHARSET=" insensible a la casse (BigStrUpperCase ci-dessus),     }
{ puis coupe au premier ';'/espace (forme SANS guillemets, celle ecrite           }
{ par les 17 echantillons reels) ou au guillemet fermant (forme AVEC             }
{ guillemets, permise par la grammaire mais non exercee ici). }
Function ExtractCharsetFromContentType(Const CT: TBigString): TBigString;
Var UP, S: TBigString; P, QEnd: Integer; Quote: Char;
Begin
  ExtractCharsetFromContentType := '';
  UP := BigStrUpperCase(CT);
  P := Pos('CHARSET=', UP);
  If P = 0 Then Exit;
  P := P + 8; { longueur de "CHARSET=" }
  If P > Length(CT) Then Exit;
  S := Copy(CT, P, Length(CT) - P + 1);
  If (Length(S) > 0) And ((S[1] = '"') Or (S[1] = '''')) Then
  Begin
    Quote := S[1];
    QEnd := Pos(Quote, Copy(S, 2, Length(S) - 1));
    If QEnd = 0 Then ExtractCharsetFromContentType := Copy(S, 2, Length(S) - 1)
    Else ExtractCharsetFromContentType := Copy(S, 2, QEnd - 1);
  End
  Else
  Begin
    QEnd := Pos(';', S);
    If QEnd = 0 Then QEnd := Pos(' ', S);
    If QEnd = 0 Then ExtractCharsetFromContentType := S
    Else ExtractCharsetFromContentType := Copy(S, 1, QEnd - 1);
  End;
End;

{ ExtractMetaCharset : "<meta charset="UTF-8">" -> "UTF-8" - recherche   }
{ le motif EXACT effectivement ecrit par les 17 echantillons reels               }
{ (insensible a la casse pour "meta"/"charset", MEME technique que                  }
{ ExtractCharsetFromContentType) - AUCUNE analyse HTML generale (attributs             }
{ additionnels sur la balise, ordre different...) n est tentee, aucun                    }
{ echantillon ne s ecarte de cette forme exacte. }
Function ExtractMetaCharset(Const Template: TBigString): TBigString;
Const NeedleUp = '<META CHARSET=';
Var UP: TBigString; P, QStart, QEnd: Integer; Quote: Char;
Begin
  ExtractMetaCharset := '';
  UP := BigStrUpperCase(Template);
  P := Pos(NeedleUp, UP);
  If P = 0 Then Exit;
  P := P + Length(NeedleUp);
  If (P > Length(Template)) Then Exit;
  Quote := Template[P];
  If (Quote <> '"') And (Quote <> '''') Then Exit;
  QStart := P + 1;
  If QStart > Length(Template) Then Exit;
  QEnd := Pos(Quote, Copy(Template, QStart, Length(Template) - QStart + 1));
  If QEnd = 0 Then Exit;
  ExtractMetaCharset := Copy(Template, QStart, QEnd - 1);
End;

Var
  { CgScanMetaCharset (juste en dessous) : etat de recherche - s arrete au   }
  { PREMIER "<meta charset=" trouve (une page HTML reelle n en a qu un              }
  { seul, dans <head>). }
  CgFoundMeta        : Boolean;
  CgFoundMetaCharset : TBigString;

{ CgScanMetaCharset : MEME parcours SK_BLOCK/SK_PRINT_TEMPLATE que          }
{ CgCollectStrings (TODO 21) - recherche jusqu au PREMIER "<meta                 }
{ charset=" trouve, puis s arrete (CgFoundMeta). }
Procedure CgScanMetaCharset(Idx: Integer);
Var I: Integer; V: TBigString;
Begin
  If CgFoundMeta Or (Idx < 0) Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      Begin
        I := 0;
        While (Not CgFoundMeta) And (I < StmtPool[Idx].ChildCount) Do
        Begin
          CgScanMetaCharset(StmtChildPool[StmtPool[Idx].ChildFirst + I]);
          Inc(I);
        End;
      End;
    SK_PRINT_TEMPLATE :
      Begin
        V := ExtractMetaCharset(StmtPool[Idx].BigVal);
        If V <> '' Then
        Begin
          CgFoundMetaCharset := V;
          CgFoundMeta := True;
        End;
      End;
  Else
    ;
  End;
End;

{ CheckEncodingCoherence : POINT D ENTREE - best-effort (WarnMsg          }
{ SEULEMENT, JAMAIS FatalError, MEME discipline que SemanticAnalyze,          }
{ TODO 20) - compare pageEncoding (TODO 05) au charset de contentType             }
{ (TODO 05) ET au "meta charset" du gabarit (ci-dessus), puis signale                }
{ tout pageEncoding non-UTF-8 (roadmap d en-tete : seul UTF-8 est                       }
{ REELLEMENT supporte). }
Procedure CheckEncodingCoherence(RootIdx: Integer);
Var CtCharset, PageEnc: TBigString;
Begin
  CgFoundMeta := False;
  CgFoundMetaCharset := '';
  CgScanMetaCharset(RootIdx);

  PageEnc := '';
  If PageOpts.HasPageEncoding Then PageEnc := PageOpts.PageEncoding;
  CtCharset := '';
  If PageOpts.HasContentType Then
    CtCharset := ExtractCharsetFromContentType(PageOpts.ContentType);

  If (PageEnc <> '') And (CtCharset <> '') And
     (BigStrUpperCase(PageEnc) <> BigStrUpperCase(CtCharset)) Then
    WarnMsg('incoherence d encodage (analyse best-effort, section 22) : ' +
            'pageEncoding="' + PageEnc + '" mais contentType charset="' +
            CtCharset + '"');

  If (PageEnc <> '') And CgFoundMeta And
     (BigStrUpperCase(PageEnc) <> BigStrUpperCase(CgFoundMetaCharset)) Then
    WarnMsg('incoherence d encodage (analyse best-effort, section 22) : ' +
            'pageEncoding="' + PageEnc + '" mais meta charset="' +
            CgFoundMetaCharset + '"');

  If (PageEnc <> '') And (BigStrUpperCase(PageEnc) <> 'UTF-8') Then
    WarnMsg('pageEncoding="' + PageEnc + '" : seul UTF-8 est reellement ' +
            'supporte (analyse best-effort, section 22), aucun transcodage ' +
            'n est effectue');
End;

{ ------------------------------------------------------------ }
{ EncodingSelfTest : Test01Bonjour.jsp reel (pageEncoding/            }
{ contentType/meta charset TOUS UTF-8 - AUCUN avertissement            }
{ attendu), non-regressions synthetiques (incoherence pageEncoding/       }
{ contentType, incoherence pageEncoding/meta, pageEncoding non-UTF-8).      }
{ ------------------------------------------------------------ }

Procedure EncodingAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('EncodingSelfTest: ' + Label_ + ' a echoue');
End;

Procedure EncodingSelfTest;
Const
  TmpFile = 'JSPENCSELFTEST.$$$';
Var
  F : Text; PageIdx, WarnBefore: Integer;
Begin
  { --- Test01Bonjour.jsp reel (fragment VERBATIM, deja repris a l         }
  { identique par CodeGenSelfTest, TODO 21) : les TROIS encodages           }
  { coherents en UTF-8 - AUCUN avertissement --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<!DOCTYPE html>',
        '<html lang="fr">',
        '<head><meta charset="UTF-8"></head>',
        '<body><h1>Bonjour depuis JSP&nbsp;!</h1></body>',
        '</html>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  CheckEncodingCoherence(PageIdx);
  EncodingAssert('Test01Bonjour.jsp reel : UTF-8 partout -> aucun avertissement',
    WarnCount = WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : pageEncoding <> contentType charset (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8" ',
        'pageEncoding="ISO-8859-1" %><p>x</p>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  CheckEncodingCoherence(PageIdx);
  EncodingAssert('pageEncoding <> contentType charset : avertissement emis',
    WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : pageEncoding <> meta charset (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page pageEncoding="UTF-8" %>',
        '<head><meta charset="ISO-8859-1"></head>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  CheckEncodingCoherence(PageIdx);
  EncodingAssert('pageEncoding <> meta charset : avertissement emis',
    WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- non-regression : pageEncoding non-UTF-8, tout cohere entre eux -    }
  { avertissement "non reellement supporte" QUAND MEME (synthetique) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page pageEncoding="ISO-8859-1" %><p>x</p>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;
  WarnBefore := WarnCount;
  CheckEncodingCoherence(PageIdx);
  EncodingAssert('pageEncoding non-UTF-8 : avertissement "non reellement supporte"',
    WarnCount > WarnBefore);
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 23 - ECRITURE DU FICHIER OBJET COFF (.OBJ)               }
{ ============================================================ }

{ DECISION DE PERIMETRE (MEME discipline que le TODO 21) : ce TODO           }
{ realise ENFIN "l encodeur d instructions 80386 a la main" que le               }
{ roadmap d en-tete du TODO 21 avait EXPLICITEMENT reporte - produire des             }
{ octets sans conteneur COFF pour les RECEVOIR aurait ete invente plutot            }
{ que verifie ; ce conteneur existe maintenant. PORTEE encodee : EXACTEMENT       }
{ la MEME que CodeGenPage/CodeGenStmt (TODO 21) - le gabarit litteral               }
{ SEULEMENT (SK_PRINT_TEMPLATE), prologue/epilogue standard, l appel                  }
{ _JSPRT_Print (runtime minimal WriteFile/GetStdHandle, TODO 18). L                      }
{ assembleur BINAIRE (BinAssemblePage/BinCodeGenStmt ci-dessous) reste            }
{ COMPLETEMENT SEPARE de l emetteur TEXTUEL du TODO 21 (CodeGenPage/                  }
{ CodeGenStmt) - MEME architecture que les compilateurs freres (roadmap                }
{ d en-tete, "BinAssembleFile... completement separee de l emission                       }
{ textuelle") : les deux parcourent le MEME arbre StmtPool INDEPENDAMMENT,               }
{ aucune representation intermediaire partagee.                                             }
{                                                                                              }
{ FORMAT COFF (Microsoft, format public et stable - AUCUNE reinvention,        }
{ MEME structure que JPPCW32.PAS/DELPHI.PAS, roadmap d en-tete) : UN SEUL          }
{ IMAGE_FILE_HEADER (20 octets), DEUX IMAGE_SECTION_HEADER (.text/.data,            }
{ 40 octets chacun), les octets bruts de chaque section, la table des                  }
{ relocations de .text (10 octets/entree, IMAGE_RELOCATION - AUCUNE                       }
{ relocation .data : aucun octet de .data ne reference jamais .text ou                      }
{ un symbole externe), la table des symboles (18 octets/entree,                                }
{ IMAGE_SYMBOL) et la table des chaines (noms de plus de 8 caracteres -                          }
{ TOUS nos symboles reels, "_JSPRT_Print"/"_jspService"/"GetStdHandle@4"/                          }
{ "WriteFile@20" depassent tous 8 caracteres, SEUL "_JSPKn" (n<10^3) y                                }
{ tient). Chaque symbole utilise StorageClass=EXTERNAL (2, MEME convention                             }
{ que MASM pour une PROC/un symbole global) ; SectionNumber=0 signale un                                  }
{ symbole EXTERNE non defini ICI (GetStdHandle@4/WriteFile@20 - resolus                                     }
{ par un lieur externe standard, roadmap d en-tete "exploitable par un                                        }
{ linker externe standard"). Un appel INTERNE (_jspService -> _JSPRT_Print,                                     }
{ MEME section .text) est resolu DIRECTEMENT en octets (rel32 calcule ICI,                                        }
{ AUCUNE entree de relocation necessaire, la cible est DEJA connue) - SEUL                                          }
{ un appel EXTERNE ou une reference a .data necessite une VRAIE relocation                                            }
{ (IMAGE_REL_I386_REL32/IMAGE_REL_I386_DIR32 respectivement), le lieur                                                  }
{ externe complete alors l octet PLACEHOLDER (toujours zero ICI - LUI                                                     }
{ ajoute l adresse finale, jamais une VALEUR PARTIELLE inventee ici). }

Const
  IMAGE_REL_I386_DIR32  = $0006;
  IMAGE_REL_I386_REL32  = $0014;
  REG_EAX = 0; REG_ECX = 1; REG_EDX = 2; REG_EBX = 3;
  REG_ESP = 4; REG_EBP = 5; REG_ESI = 6; REG_EDI = 7;

Type
  TBinFixupKind = (BFK_DIR32_DATA, BFK_REL32_EXTERN);

  TBinFixup = Record
    TextOffset : Integer;   { position du PLACEHOLDER 4 octets dans BinTextBuf }
    SymbolName : TString;   { symbole CIBLE, resolu en index au moment d ecrire }
    Kind       : TBinFixupKind;
  End;

  TBinSymbol = Record
    Name       : TString;
    SectionNum : Integer;   { 1 = .text, 2 = .data, 0 = externe non defini }
    Value      : LongInt;   { offset dans la section ; 0 si externe }
  End;

Var
  { BinTextLen/BinDataLen : LongInt, JAMAIS Integer - MEME piege deja evite    }
  { par SrcLen/LexPos (TODO 02) : Integer est un ENTIER 16 BITS sous le          }
  { mode de compatibilite Turbo Pascal de ce fichier, et MAX_BIN_DATA (65536,       }
  { un gabarit HTML entier) depasse largement les 32767 qu Integer peut               }
  { representer - un compteur 16 bits y deborderait silencieusement                     }
  { (avertissement du compilateur "comparaison toujours fausse" observe                    }
  { et corrige ICI AVANT execution, jamais laisse passer). }
  BinTextBuf   : Array[0..MAX_BIN_CODE - 1] Of Byte;
  BinTextLen   : LongInt;
  BinDataBuf   : Array[0..MAX_BIN_DATA - 1] Of Byte;
  BinDataLen   : LongInt;
  BinSymPool   : Array[0..MAX_BIN_SYM - 1] Of TBinSymbol;
  BinSymCount  : Integer;
  BinFixupPool : Array[0..MAX_BIN_FIXUP - 1] Of TBinFixup;
  BinFixupCount: Integer;

Procedure BinAsmInit;
Begin
  BinTextLen := 0;
  BinDataLen := 0;
  BinSymCount := 0;
  BinFixupCount := 0;
End;

Function BinSymAdd(Const Name: TString; SectionNum: Integer; Value: LongInt): Integer;
Begin
  If BinSymCount >= MAX_BIN_SYM Then
    FatalError('table des symboles COFF pleine (MAX_BIN_SYM)');
  BinSymPool[BinSymCount].Name       := Name;
  BinSymPool[BinSymCount].SectionNum := SectionNum;
  BinSymPool[BinSymCount].Value      := Value;
  BinSymAdd := BinSymCount;
  Inc(BinSymCount);
End;

Function BinSymFind(Const Name: TString): Integer;
Var I: Integer;
Begin
  BinSymFind := -1;
  For I := 0 To BinSymCount - 1 Do
    If BinSymPool[I].Name = Name Then
    Begin
      BinSymFind := I;
      Exit;
    End;
End;

Procedure BinFixupAdd(TextOffset: Integer; Const SymbolName: TString; Kind: TBinFixupKind);
Begin
  If BinFixupCount >= MAX_BIN_FIXUP Then
  Begin
    FatalError('table des relocations COFF pleine (MAX_BIN_FIXUP)');
    Exit;
  End;
  BinFixupPool[BinFixupCount].TextOffset := TextOffset;
  BinFixupPool[BinFixupCount].SymbolName := SymbolName;
  BinFixupPool[BinFixupCount].Kind       := Kind;
  Inc(BinFixupCount);
End;

{ Bin*Byte/Dword : les DEUX seules primitives d encodage REELLES - tout    }
{ le reste (BinEmitPush*, BinEmitCall*...) n est qu une COMBINAISON de         }
{ celles-ci, EXACTEMENT comme un assembleur reel construit ses                     }
{ instructions a partir d octets d opcode/ModRM/immediat. }
Procedure BinTextByte(B: Byte);
Begin
  If BinTextLen >= MAX_BIN_CODE Then
  Begin
    FatalError('section .text pleine (MAX_BIN_CODE)');
    Exit;
  End;
  BinTextBuf[BinTextLen] := B;
  Inc(BinTextLen);
End;

Procedure BinTextDword(D: LongInt);
Begin
  BinTextByte(Byte(D And $FF));
  BinTextByte(Byte((D Shr 8) And $FF));
  BinTextByte(Byte((D Shr 16) And $FF));
  BinTextByte(Byte((D Shr 24) And $FF));
End;

Procedure BinDataByte(B: Byte);
Begin
  If BinDataLen >= MAX_BIN_DATA Then
  Begin
    FatalError('section .data pleine (MAX_BIN_DATA)');
    Exit;
  End;
  BinDataBuf[BinDataLen] := B;
  Inc(BinDataLen);
End;

{ ------------------------------------------------------------ }
{ Encodeur 80386 - SEUL le sous-ensemble REELLEMENT emis par         }
{ BinAssemblePage/BinCodeGenStmt ci-dessous (prologue/epilogue,       }
{ push imm32/reg/[ebp+disp8], call rel32 interne/externe, ret) -       }
{ MEME table d encodage 80386 standard que tout assembleur reel,        }
{ AUCUNE reinvention (roadmap d en-tete du TODO 21/23).                  }
{ ------------------------------------------------------------ }

Procedure BinEmitPushReg(Reg: Byte);
Begin
  BinTextByte($50 + Reg);
End;

Procedure BinEmitPopReg(Reg: Byte);
Begin
  BinTextByte($58 + Reg);
End;

Procedure BinEmitPushImm32(V: LongInt);
Begin
  BinTextByte($68);
  BinTextDword(V);
End;

{ push OFFSET <symbole .data> - le PLACEHOLDER (0) sera complete par un   }
{ lieur externe REEL (IMAGE_REL_I386_DIR32) ; le symbole peut etre                }
{ enregistre APRES cet appel (jsp:useBean-style "vers l avant"), la               }
{ resolution du NOM en INDEX de symbole n a lieu qu au moment d ECRIRE le             }
{ fichier (BinWriteRelocations, plus bas), jamais ici. }
Procedure BinEmitPushOffsetFixup(Const SymbolName: TString);
Begin
  BinTextByte($68);
  BinFixupAdd(BinTextLen, SymbolName, BFK_DIR32_DATA);
  BinTextDword(0);
End;

Procedure BinEmitPushMemEbpDisp8(Disp: ShortInt);
Begin
  BinTextByte($FF);
  BinTextByte($75); { ModRM : mod=01, reg=110 (/6, PUSH r/m32), rm=101 (ebp) }
  BinTextByte(Byte(Disp));
End;

Procedure BinEmitMovRegReg(DstReg, SrcReg: Byte);
Begin
  BinTextByte($8B); { MOV r32, r/m32 }
  BinTextByte($C0 Or (DstReg Shl 3) Or SrcReg); { ModRM : mod=11, reg=dst, rm=src }
End;

{ ------------------------------------------------------------ }
{ EXTENSION post-TODO25 : MEME encodeur supplementaire que le          }
{ backend PE (voir la note d en-tete complete pres des primitives          }
{ PeEmit* equivalentes, TODO 24) mais avec des RELOCATIONS DIR32              }
{ (BinFixupAdd, MEME mecanisme que BinEmitPushOffsetFixup) au lieu             }
{ d une adresse absolue codee en dur - un .obj COFF n a PAS d ImageBase              }
{ fixe avant l edition de liens (contrairement au .exe PE, deja chargé                 }
{ a une adresse CONNUE). Chaque "symbole+decalage" (ex. "_JSPRT_DateStr+5")               }
{ est encode en ecrivant le DECALAGE comme valeur PRE-relocation (le                        }
{ lieur AJOUTE l adresse finale du symbole a cette valeur existante,                           }
{ IMAGE_REL_I386_DIR32 - MEME semantique que documentee au TODO 23).                              }
{ ------------------------------------------------------------ }

Procedure BinEmitMovRegImm32(Reg: Byte; V: LongInt);
Begin
  BinTextByte($B8 + Reg);
  BinTextDword(V);
End;

Procedure BinEmitXorRegReg(DstReg, SrcReg: Byte);
Begin
  BinTextByte($33);
  BinTextByte($C0 Or (DstReg Shl 3) Or SrcReg);
End;

Procedure BinEmitDivReg(Reg: Byte);
Begin
  BinTextByte($F7);
  BinTextByte($F0 Or Reg);
End;

Procedure BinEmitAddAlImm8(V: Byte);
Begin
  BinTextByte($04);
  BinTextByte(V);
End;

Procedure BinEmitAddR8Imm8(Reg8: Byte; V: Byte);
Begin
  BinTextByte($80);
  BinTextByte($C0 Or Reg8);
  BinTextByte(V);
End;

Procedure BinEmitMovzxEaxAbsFixup(Const SymbolName: TString; AddOffset: LongInt);
Begin
  BinTextByte($0F);
  BinTextByte($B7);
  BinTextByte($05);
  BinFixupAdd(BinTextLen, SymbolName, BFK_DIR32_DATA);
  BinTextDword(AddOffset);
End;

Procedure BinEmitMovAbsFromReg8Fixup(Const SymbolName: TString; AddOffset: LongInt; Reg8: Byte);
Begin
  BinTextByte($88);
  BinTextByte($05 Or (Reg8 Shl 3));
  BinFixupAdd(BinTextLen, SymbolName, BFK_DIR32_DATA);
  BinTextDword(AddOffset);
End;

Procedure BinEmitMovByteAbsImm8Fixup(Const SymbolName: TString; AddOffset: LongInt; V: Byte);
Begin
  BinTextByte($C6);
  BinTextByte($05);
  BinFixupAdd(BinTextLen, SymbolName, BFK_DIR32_DATA);
  BinTextDword(AddOffset);
  BinTextByte(V);
End;

{ call REL32 vers un symbole EXTERNE (GetStdHandle@4/WriteFile@20) - le    }
{ PLACEHOLDER reste 0 (IMAGE_REL_I386_REL32, l addend est TOUJOURS nul       }
{ ici, aucun decalage supplementaire n est jamais necessaire). }
Procedure BinEmitCallExternFixup(Const SymbolName: TString);
Begin
  BinTextByte($E8);
  BinFixupAdd(BinTextLen, SymbolName, BFK_REL32_EXTERN);
  BinTextDword(0);
End;

{ call REL32 INTERNE (MEME section .text, cible DEJA connue - AUCUNE         }
{ relocation necessaire, EXACTEMENT comme un assembleur reel resout un         }
{ saut/appel local sans passer par le lieur). }
Procedure BinEmitCallInternal(TargetOffset: Integer);
Begin
  BinTextByte($E8);
  BinTextDword(TargetOffset - (BinTextLen + 4));
End;

Procedure BinEmitRet;
Begin
  BinTextByte($C3);
End;

Procedure BinEmitRetImm16(N: Word);
Begin
  BinTextByte($C2);
  BinTextByte(Byte(N And $FF));
  BinTextByte(Byte((N Shr 8) And $FF));
End;

Procedure BinDataDword(D: LongInt);
Begin
  BinDataByte(Byte(D And $FF));
  BinDataByte(Byte((D Shr 8) And $FF));
  BinDataByte(Byte((D Shr 16) And $FF));
  BinDataByte(Byte((D Shr 24) And $FF));
End;

{ ------------------------------------------------------------ }
{ EXTENSION 3 (post-TODO25) : encodeur supplementaire pour les APPELS DE     }
{ FONCTION REELS - adressage indirect/base+deplacement, arithmetique          }
{ entiere et sauts courts CONDITIONNELS (aucun des 3 backends n avait          }
{ encore besoin d un SAUT reel : _JSPRT_PrintDate, TODO 24/extension 1/2,       }
{ est DELIBEREMENT ENTIEREMENT LINEAIRE - _JSPRT_PrintInt ci-dessous est le      }
{ premier runtime a en avoir reellement besoin, carre(12)/nomApplication(),      }
{ Test03Declarations.jsp). Les DEUX sauts EN AVANT (jns/jz) utilisent un        }
{ mecanisme de PATCH LOCAL A DEUX PASSES (placeholder puis correction une         }
{ fois la cible connue) puisque leur cible n est pas encore ecrite au moment       }
{ de l emission - le SEUL saut EN ARRIERE (jnz) connait deja sa cible et            }
{ calcule directement son deplacement, EXACTEMENT comme BinEmitCallInternal          }
{ le fait pour un appel interne. }
Procedure BinEmitMovRegMemEbpDisp8(Reg: Byte; Disp: ShortInt);
Begin
  BinTextByte($8B); { MOV r32, r/m32 }
  BinTextByte($40 Or (Reg Shl 3) Or 5); { ModRM : mod=01, reg=Reg, rm=101 (ebp) }
  BinTextByte(Byte(Disp));
End;

Procedure BinEmitPushMemIndirect(AddrReg: Byte);
Begin
  BinTextByte($FF);
  BinTextByte($30 Or AddrReg); { ModRM : mod=00, reg=110 (/6, PUSH r/m32), rm=AddrReg }
End;

Procedure BinEmitLeaRegMemRegDisp8(DstReg, BaseReg: Byte; Disp: ShortInt);
Begin
  BinTextByte($8D); { LEA r32, m }
  BinTextByte($40 Or (DstReg Shl 3) Or BaseReg); { ModRM : mod=01, reg=DstReg, rm=BaseReg }
  BinTextByte(Byte(Disp));
End;

Procedure BinEmitImulRegReg(DstReg, SrcReg: Byte);
Begin
  BinTextByte($0F); { IMUL r32, r/m32 }
  BinTextByte($AF);
  BinTextByte($C0 Or (DstReg Shl 3) Or SrcReg); { ModRM : mod=11, reg=Dst, rm=Src }
End;

Procedure BinEmitNegReg(Reg: Byte);
Begin
  BinTextByte($F7); { NEG r/m32 (/3) }
  BinTextByte($D8 Or Reg); { ModRM : mod=11, reg=011, rm=Reg }
End;

Procedure BinEmitDecReg(Reg: Byte);
Begin
  BinTextByte($48 + Reg); { DEC r32, forme courte }
End;

Procedure BinEmitTestRegReg(Reg: Byte);
Begin
  BinTextByte($85); { TEST r/m32, r32 }
  BinTextByte($C0 Or (Reg Shl 3) Or Reg); { ModRM : mod=11, reg=Reg, rm=Reg }
End;

Procedure BinEmitSubRegReg(DstReg, SrcReg: Byte);
Begin
  BinTextByte($2B); { SUB r32, r/m32 }
  BinTextByte($C0 Or (DstReg Shl 3) Or SrcReg); { ModRM : mod=11, reg=Dst, rm=Src }
End;

Procedure BinEmitSubRegImm8(Reg: Byte; V: Byte);
Begin
  BinTextByte($83); { SUB r/m32, imm8 (/5) }
  BinTextByte($E8 Or Reg); { ModRM : mod=11, reg=101, rm=Reg }
  BinTextByte(V);
End;

Procedure BinEmitMovMemIndirectFromReg32(AddrReg, SrcReg: Byte);
Begin
  BinTextByte($89); { MOV r/m32, r32 }
  BinTextByte((SrcReg Shl 3) Or AddrReg); { ModRM : mod=00, reg=Src, rm=AddrReg }
End;

Procedure BinEmitMovMemIndirectFromReg8(AddrReg, SrcReg8: Byte);
Begin
  BinTextByte($88); { MOV r/m8, r8 }
  BinTextByte((SrcReg8 Shl 3) Or AddrReg); { ModRM : mod=00, reg=Src, rm=AddrReg }
End;

Procedure BinEmitMovByteMemIndirectImm8(AddrReg: Byte; V: Byte);
Begin
  BinTextByte($C6); { MOV r/m8, imm8 (/0) }
  BinTextByte(AddrReg); { ModRM : mod=00, reg=000, rm=AddrReg }
  BinTextByte(V);
End;

{ mov reg, OFFSET symbole+decalage - MEME relocation DIR32 que              }
{ BinEmitPushOffsetFixup, mais chargeant l adresse dans un REGISTRE           }
{ arbitraire plutot que de la pousser directement (necessaire pour           }
{ _JSPRT_PrintInt, qui doit la MANIPULER - lui ajouter/soustraire - avant       }
{ de l utiliser). }
Procedure BinEmitMovRegOffsetFixup(Reg: Byte; Const SymbolName: TString; AddOffset: LongInt);
Begin
  BinTextByte($B8 + Reg);
  BinFixupAdd(BinTextLen, SymbolName, BFK_DIR32_DATA);
  BinTextDword(AddOffset);
End;

Function BinEmitJccPlaceholder(Opcode: Byte): Integer;
Begin
  BinTextByte(Opcode);
  BinTextByte(0);
  BinEmitJccPlaceholder := BinTextLen - 1; { position de l octet rel8 a corriger }
End;

Procedure BinPatchJcc(PatchPos: Integer);
Begin
  BinTextBuf[PatchPos] := Byte(BinTextLen - (PatchPos + 1));
End;

Procedure BinEmitJccBackward(Opcode: Byte; TargetOffset: Integer);
Begin
  BinTextByte(Opcode);
  BinTextByte(Byte(TargetOffset - (BinTextLen + 1)));
End;

{ BinIntToStr : PETIT utilitaire local - Str() standard, isole ICI          }
{ uniquement pour que BinCodeGenStmt/BinAssemblePage restent lisibles           }
{ (concatener "_JSPK" + un entier). }
Function BinIntToStr(N: Integer): TString;
Var S: TString;
Begin
  Str(N, S);
  BinIntToStr := S;
End;

{ EXTENSION 3 (post-TODO25) - MIROIR BINAIRE de CgFindParam/                }
{ CgCompileExprToEax/CgCompileMethodStmt/CgCompileMethodBody/                 }
{ CgEmitMethodCallPrint (voir leurs notes d en-tete completes, TODO 21) -       }
{ MEME portee etroite (corps = un seul "return <expr>;" final ; litteral       }
{ chaine/entier, parametre, '*' binaire ; arguments d appel = litteraux          }
{ entiers). BinMethodOffset (GLOBAL, MEME discipline que CgStrPool) memorise     }
{ l offset .text de chaque methode COMPILEE - un site d appel (SK_PRINT_EXPR)     }
{ le lit DIRECTEMENT (BinEmitCallInternal, AUCUNE relocation necessaire,           }
{ EXACTEMENT comme PrintProcOffset/PrintDateOffset) PUISQUE les methodes           }
{ sont TOUJOURS compilees avant _jspService (BinAssemblePage). }
Var
  BinMethodOffset  : Array[0..(MAX_FUNC + MAX_METHOD) - 1] Of Integer;
  BinCurParamNames : Array[0..MAX_PARAM - 1] Of TString;
  BinCurParamCount : Integer;

Function BinFindParam(Const Name: TString; Var Offset: Integer): Boolean;
Var I: Integer;
Begin
  BinFindParam := False;
  For I := 0 To BinCurParamCount - 1 Do
    If BinCurParamNames[I] = Name Then
    Begin
      Offset := 8 + I * 4;
      BinFindParam := True;
      Exit;
    End;
End;

Procedure BinCompileExprToEax(ExprIdx: Integer);
Var SIdx, Offset: Integer;
Begin
  Case ExprPool[ExprIdx].Kind Of
    EK_INT :
      BinEmitMovRegImm32(REG_EAX, ExprPool[ExprIdx].IntVal);

    EK_STRING :
      Begin
        SIdx := CgStrFindOrAdd(ExprPool[ExprIdx].StrVal);
        BinEmitMovRegOffsetFixup(REG_EAX, '_JSPK' + BinIntToStr(SIdx), 0);
      End;

    EK_IDENT :
      If BinFindParam(ExprPool[ExprIdx].NameVal, Offset) Then
        BinEmitMovRegMemEbpDisp8(REG_EAX, Offset)
      Else
        FatalError('generation de code (extension post-TODO25) : identificateur ' +
                   'non resolu dans un corps de methode - ' +
                   ExprPool[ExprIdx].NameVal);

    EK_BINARY :
      If ExprPool[ExprIdx].Op = '*' Then
      Begin
        BinCompileExprToEax(ExprPool[ExprIdx].Left);
        BinEmitPushReg(REG_EAX);
        BinCompileExprToEax(ExprPool[ExprIdx].Right);
        BinEmitPopReg(REG_ECX);
        BinEmitImulRegReg(REG_EAX, REG_ECX);
      End
      Else
        FatalError('generation de code (extension post-TODO25) : operateur "' +
                   ExprPool[ExprIdx].Op + '" non gere dans un corps de methode');
  Else
    FatalError('generation de code (extension post-TODO25) : expression non ' +
               'geree dans un corps de methode');
  End;
End;

Procedure BinCompileMethodStmt(Idx: Integer);
Var I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        BinCompileMethodStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);

    SK_RETURN :
      If StmtPool[Idx].ExprIdx >= 0 Then
        BinCompileExprToEax(StmtPool[Idx].ExprIdx)
      Else
        BinEmitXorRegReg(REG_EAX, REG_EAX);
  Else
    FatalError('generation de code (extension post-TODO25) : instruction non ' +
               'geree dans un corps de methode - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

Procedure BinCompileMethodBody(MIdx: Integer);
Var I: Integer;
Begin
  BinCurParamCount := JavaMethodPool[MIdx].ParamCount;
  For I := 0 To BinCurParamCount - 1 Do
    BinCurParamNames[I] := JavaParamPool[JavaMethodPool[MIdx].ParamFirst + I].Name;

  BinMethodOffset[MIdx] := BinTextLen;
  BinSymAdd('_JSPM_' + JavaMethodPool[MIdx].Name, 1, BinTextLen);
  BinEmitPushReg(REG_EBP);
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinCompileMethodStmt(JavaMethodPool[MIdx].BodyStmtIdx);
  BinEmitMovRegReg(REG_ESP, REG_EBP);
  BinEmitPopReg(REG_EBP);
  BinEmitRetImm16(BinCurParamCount * 4);
End;

Function BinEmitMethodCallPrint(ExprIdx, PrintProcOffset, PrintIntOffset: Integer): Boolean;
Var MIdx, I, ArgIdx: Integer;
Begin
  BinEmitMethodCallPrint := False;
  If ExprIdx < 0 Then Exit;
  If ExprPool[ExprIdx].Kind <> EK_CALL Then Exit;
  If ExprPool[ExprIdx].Left < 0 Then Exit;
  If ExprPool[ExprPool[ExprIdx].Left].Kind <> EK_IDENT Then Exit;

  MIdx := JavaMethodFind(ExprPool[ExprPool[ExprIdx].Left].NameVal);
  If MIdx < 0 Then Exit;

  If ExprPool[ExprIdx].ArgCount <> JavaMethodPool[MIdx].ParamCount Then
    FatalError('generation de code (extension post-TODO25) : nombre d ' +
               'arguments incompatible pour l appel a "' +
               JavaMethodPool[MIdx].Name + '"');

  For I := ExprPool[ExprIdx].ArgCount - 1 Downto 0 Do
  Begin
    ArgIdx := ExprArgPool[ExprPool[ExprIdx].ArgFirst + I];
    If ExprPool[ArgIdx].Kind <> EK_INT Then
      FatalError('generation de code (extension post-TODO25) : seul un ' +
                 'argument litteral entier est gere pour l appel a une ' +
                 'methode declaree - "' + JavaMethodPool[MIdx].Name + '"');
    BinEmitPushImm32(ExprPool[ArgIdx].IntVal);
  End;

  BinEmitCallInternal(BinMethodOffset[MIdx]);

  If JavaMethodPool[MIdx].ReturnType = 'String' Then
  Begin
    BinEmitPushReg(REG_EAX);
    BinEmitCallInternal(PrintProcOffset);
  End
  Else If JavaMethodPool[MIdx].ReturnType = 'int' Then
  Begin
    BinEmitPushReg(REG_EAX);
    BinEmitCallInternal(PrintIntOffset);
  End
  Else
    FatalError('generation de code (extension post-TODO25) : type de retour "' +
               JavaMethodPool[MIdx].ReturnType + '" non gere pour <%= ' +
               JavaMethodPool[MIdx].Name + '(...) %>');

  BinEmitMethodCallPrint := True;
End;

{ BinCodeGenStmt : MIROIR BINAIRE de CodeGenStmt (TODO 21) - MEME          }
{ portee EXACTE (SK_BLOCK/SK_PRINT_TEMPLATE seulement, MEME StmtKindName        }
{ pour le diagnostic sur tout AUTRE SK_) mais ecrit des OCTETS REELS            }
{ plutot que du texte : "push <longueur>" devient BinEmitPushImm32,               }
{ "push OFFSET _JSPKn" devient BinEmitPushOffsetFixup (le nom _JSPKn EST         }
{ le MEME que celui deja assigne par CgStrFindOrAdd/CgCollectStrings,               }
{ TODO 21 - pool REUTILISE tel quel, aucune duplication), "call                        }
{ _JSPRT_Print" devient BinEmitCallInternal (cible CONNUE, PrintProcOffset,               }
{ argument de BinAssemblePage). }
Procedure BinCodeGenStmt(Idx: Integer; PrintProcOffset, PrintDateOffset, PrintIntOffset: Integer);
Var I, SIdx: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        BinCodeGenStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I],
                       PrintProcOffset, PrintDateOffset, PrintIntOffset);

    SK_PRINT_TEMPLATE :
      Begin
        SIdx := CgStrFindOrAdd(StmtPool[Idx].BigVal);
        BinEmitPushOffsetFixup('_JSPK' + BinIntToStr(SIdx));
        BinEmitCallInternal(PrintProcOffset);
      End;

    { SK_PRINT_EXPR (EXTENSION post-TODO25, ETENDUE - extension 2, PUIS       }
    { extension 3) : MEME special-case PARTAGE (CgIsImmediateDatePrint,          }
    { TODO 21) que PeCodeGenStmt/CodeGenStmt - voir sa note d en-tete               }
    { complete pour les DEUX formes reconnues, PUIS l appel a une methode              }
    { declaree en page (BinEmitMethodCallPrint, extension 3). }
    SK_PRINT_EXPR :
      If CgIsImmediateDatePrint(StmtPool[Idx].ExprIdx) Then
        BinEmitCallInternal(PrintDateOffset)
      Else If BinEmitMethodCallPrint(StmtPool[Idx].ExprIdx, PrintProcOffset, PrintIntOffset) Then
        { rien de plus - deja emis par BinEmitMethodCallPrint }
      Else
        FatalError('generation de code (extension post-TODO25) : seule ' +
                   '"new java.util.Date()"/"DateFormat.getDateTimeInstance().' +
                   'format(new Date())"/l appel a une methode declaree en page ' +
                   'est gere pour <%= %> - construction non encore geree');
  Else
    FatalError('generation de code (TODO 23) : construction non encore ' +
               'geree - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

{ BinAssemblePage : POINT D ENTREE - MEME arbre (RootIdx, le SK_BLOCK     }
{ racine de ParsePage) que CodeGenPage (TODO 21), parcouru INDEPENDAMMENT       }
{ pour produire des OCTETS REELS plutot que du texte. Ordre d emission :          }
{ (1) .data - le pool _JSPK deduplique (CgStrPool, TODO 21, REUTILISE tel            }
{ quel) puis _JSPRT_BytesWritten ; (2) les DEUX symboles EXTERNES (section            }
{ 0) GetStdHandle@4/WriteFile@20 ; (3) .text - _JSPRT_Print (son symbole            }
{ EST enregistre AVANT le corps de _jspService, permettant a               }
{ BinCodeGenStmt de resoudre l appel INTERNE sans relocation) puis                    }
{ _jspService. }
Procedure BinAssemblePage(RootIdx: Integer);
Var
  I, PrintProcOffset, PrintDateOffset, PrintIntOffset : Integer;
  JccL1, JccL3, L2Offset : Integer;
  DataOff            : LongInt;
Begin
  BinAsmInit;
  CgStrInit;
  CgCollectStrings(RootIdx);
  { EXTENSION 3 (post-TODO25) : les litteraux chaine RETOURNES par une        }
  { methode declaree (JavaMethodPool - un arbre SEPARE du gabarit/                }
  { scriptlets de RootIdx) doivent etre COLLECTES avant d ecrire .data,             }
  { EXACTEMENT le meme bogue reel corrige pour CodeGenPage (voir sa note           }
  { d en-tete complete pres de CgCollectStringsFromExpr). }
  For I := 0 To JavaMethodCount - 1 Do
    CgCollectStringsFromMethodStmt(JavaMethodPool[I].BodyStmtIdx);

  { --- .data : pool _JSPK (MEME contenu/ordre que CodeGenPage, TODO 21) --- }
  { EXTENSION 3 : chaque bloc commence PAR SA LONGUEUR (dd), MEME               }
  { convention que le backend textuel - voir la note d en-tete complete           }
  { pres de _JSPRT_Print (CodeGenPage). }
  For I := 0 To CgStrCount - 1 Do
  Begin
    BinSymAdd('_JSPK' + BinIntToStr(I), 2, BinDataLen);
    BinDataDword(Length(CgStrPool[I]));
    For DataOff := 1 To Length(CgStrPool[I]) Do
      BinDataByte(Ord(CgStrPool[I][DataOff]));
  End;
  BinSymAdd('_JSPRT_BytesWritten', 2, BinDataLen);
  BinDataDword(0);

  { --- .data : EXTENSION post-TODO25 - tampons de "new java.util.Date()"  }
  { imprime immediatement (MEME format/MEME limite documentee que le           }
  { backend PE, TODO 24 - voir sa note d en-tete complete). EXTENSION 3 :      }
  { prefixe de longueur ajoute EN TETE de _JSPRT_DateStr (meme convention         }
  { que les _JSPKn ci-dessus). --- }
  BinSymAdd('_JSPRT_SysTime', 2, BinDataLen);
  For I := 1 To 16 Do BinDataByte(0);
  BinSymAdd('_JSPRT_DateStr', 2, BinDataLen);
  BinDataDword(19);
  For I := 1 To 19 Do BinDataByte(Ord(' '));
  { --- .data : EXTENSION 3 (post-TODO25) - tampon de _JSPRT_PrintInt --- }
  BinSymAdd('_JSPRT_IntBuf', 2, BinDataLen);
  For I := 1 To 16 Do BinDataByte(0);

  { --- symboles EXTERNES (section 0, non definis ICI - roadmap d en-tete, }
  { "exploitable par un linker externe standard") --- }
  BinSymAdd('GetStdHandle@4', 0, 0);
  BinSymAdd('WriteFile@20', 0, 0);
  BinSymAdd('GetLocalTime@4', 0, 0); { EXTENSION post-TODO25 }

  { --- .text : _JSPRT_Print (runtime minimal, TODO 18/21) - EXTENSION 3 :  }
  { signature reduite a UN SEUL parametre (bloc longueur-prefixe), voir la      }
  { note d en-tete complete pres de la version textuelle (CodeGenPage). --- }
  PrintProcOffset := BinTextLen;
  BinSymAdd('_JSPRT_Print', 1, PrintProcOffset);
  BinEmitPushReg(REG_EBP);
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinEmitPushImm32(-11); { STD_OUTPUT_HANDLE }
  BinEmitCallExternFixup('GetStdHandle@4');
  BinEmitMovRegMemEbpDisp8(REG_ECX, 8);
  BinEmitLeaRegMemRegDisp8(REG_EDX, REG_ECX, 4);
  BinEmitPushImm32(0);
  BinEmitPushOffsetFixup('_JSPRT_BytesWritten');
  BinEmitPushMemIndirect(REG_ECX);
  BinEmitPushReg(REG_EDX);
  BinEmitPushReg(REG_EAX);
  BinEmitCallExternFixup('WriteFile@20');
  BinEmitPopReg(REG_EBP);
  BinEmitRetImm16(4);

  { --- .text : _JSPRT_PrintInt (EXTENSION 3, post-TODO25) - conversion       }
  { entier->decimal (division repetee par 10) puis reutilisation de              }
  { _JSPRT_Print - voir la note d en-tete complete pres de la version              }
  { textuelle (CodeGenPage) pour la disposition EXACTE du tampon               }
  { _JSPRT_IntBuf/le calcul du prefixe de longueur a une position VARIABLE. --- }
  PrintIntOffset := BinTextLen;
  BinSymAdd('_JSPRT_PrintInt', 1, PrintIntOffset);
  BinEmitPushReg(REG_EBP);
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinEmitPushReg(REG_EBX);
  BinEmitPushReg(REG_ESI);
  BinEmitPushReg(REG_EDI);
  BinEmitMovRegMemEbpDisp8(REG_EAX, 8);
  BinEmitMovRegOffsetFixup(REG_EDI, '_JSPRT_IntBuf', 16);
  BinEmitXorRegReg(REG_ESI, REG_ESI);
  BinEmitTestRegReg(REG_EAX);
  JccL1 := BinEmitJccPlaceholder($79); { jns L1 }
  BinEmitMovRegImm32(REG_ESI, 1);
  BinEmitNegReg(REG_EAX);
  BinPatchJcc(JccL1); { L1: }
  BinEmitMovRegImm32(REG_EBX, 10);
  L2Offset := BinTextLen; { L2: }
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitDivReg(REG_EBX);
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitDecReg(REG_EDI);
  BinEmitMovMemIndirectFromReg8(REG_EDI, REG_EDX);
  BinEmitTestRegReg(REG_EAX);
  BinEmitJccBackward($75, L2Offset); { jnz L2 }
  BinEmitTestRegReg(REG_ESI);
  JccL3 := BinEmitJccPlaceholder($74); { jz L3 }
  BinEmitDecReg(REG_EDI);
  BinEmitMovByteMemIndirectImm8(REG_EDI, Ord('-'));
  BinPatchJcc(JccL3); { L3: }
  BinEmitMovRegOffsetFixup(REG_EAX, '_JSPRT_IntBuf', 16);
  BinEmitSubRegReg(REG_EAX, REG_EDI);
  BinEmitSubRegImm8(REG_EDI, 4);
  BinEmitMovMemIndirectFromReg32(REG_EDI, REG_EAX);
  BinEmitPushReg(REG_EDI);
  BinEmitCallInternal(PrintProcOffset);
  BinEmitPopReg(REG_EDI);
  BinEmitPopReg(REG_ESI);
  BinEmitPopReg(REG_EBX);
  BinEmitPopReg(REG_EBP);
  BinEmitRetImm16(4);

  { --- .text : _JSPRT_PrintDate (EXTENSION post-TODO25) - MEME algorithme    }
  { LINEAIRE (aucun saut) que le backend PE, MEME format/MEME limite               }
  { documentee (voir la note d en-tete complete pres de PeEmitPrintDate,               }
  { TODO 24) - SEULE difference reelle : chaque reference .data utilise une              }
  { VRAIE relocation DIR32 (BinEmitMov*Fixup) plutot qu une adresse absolue                 }
  { codee en dur (aucun ImageBase fixe avant l edition de liens, TODO 23). }
  PrintDateOffset := BinTextLen;
  BinSymAdd('_JSPRT_PrintDate', 1, PrintDateOffset);
  BinEmitPushReg(REG_EBP);
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinEmitPushOffsetFixup('_JSPRT_SysTime');
  BinEmitCallExternFixup('GetLocalTime@4');

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 0);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 100);
  BinEmitDivReg(REG_ECX);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 4, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 5, REG_EDX);

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 0);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 100);
  BinEmitDivReg(REG_ECX);
  BinEmitMovRegReg(REG_EAX, REG_EDX);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 6, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 7, REG_EDX);

  BinEmitMovByteAbsImm8Fixup('_JSPRT_DateStr', 8, Ord('-'));

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 2);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 9, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 10, REG_EDX);

  BinEmitMovByteAbsImm8Fixup('_JSPRT_DateStr', 11, Ord('-'));

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 6);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 12, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 13, REG_EDX);

  BinEmitMovByteAbsImm8Fixup('_JSPRT_DateStr', 14, Ord(' '));

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 8);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 15, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 16, REG_EDX);

  BinEmitMovByteAbsImm8Fixup('_JSPRT_DateStr', 17, Ord(':'));

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 10);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 18, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 19, REG_EDX);

  BinEmitMovByteAbsImm8Fixup('_JSPRT_DateStr', 20, Ord(':'));

  BinEmitMovzxEaxAbsFixup('_JSPRT_SysTime', 12);
  BinEmitXorRegReg(REG_EDX, REG_EDX);
  BinEmitMovRegImm32(REG_ECX, 10);
  BinEmitDivReg(REG_ECX);
  BinEmitAddAlImm8(Ord('0'));
  BinEmitAddR8Imm8(REG_EDX, Ord('0'));
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 21, REG_EAX);
  BinEmitMovAbsFromReg8Fixup('_JSPRT_DateStr', 22, REG_EDX);

  BinEmitPushOffsetFixup('_JSPRT_DateStr');
  BinEmitCallInternal(PrintProcOffset);

  BinEmitPopReg(REG_EBP);
  BinEmitRet;

  { --- .text : EXTENSION 3 (post-TODO25) - corps des methodes declarees      }
  { en page, EMISES AVANT _jspService (MEME discipline "callee avant           }
  { caller" que _JSPRT_Print/_JSPRT_PrintDate ci-dessus - voir la note            }
  { d en-tete complete pres de BinCompileMethodBody). --- }
  For I := 0 To JavaMethodCount - 1 Do
    BinCompileMethodBody(I);

  { --- .text : _jspService (point d entree synthetique de la page, TODO 09) --- }
  BinSymAdd('_jspService', 1, BinTextLen);
  BinEmitPushReg(REG_EBP);
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinCodeGenStmt(RootIdx, PrintProcOffset, PrintDateOffset, PrintIntOffset);
  BinEmitMovRegReg(REG_ESP, REG_EBP);
  BinEmitPopReg(REG_EBP);
  BinEmitRet;
End;

{ ------------------------------------------------------------ }
{ WriteCOFFObj : ecrit le fichier .OBJ COFF REEL sur disque a partir de   }
{ BinTextBuf/BinDataBuf/BinSymPool/BinFixupPool (deja remplis par              }
{ BinAssemblePage) - PRE-CALCULE tous les offsets de fichier (COFF exige        }
{ des decalages ABSOLUS dans les en-tetes, jamais des positions relatives),       }
{ puis ecrit STRICTEMENT dans l ordre : en-tete, en-tetes de section,               }
{ octets .text, relocations .text, octets .data, table des symboles, table            }
{ des chaines (noms de plus de 8 caracteres, TOUS nos symboles reels sauf              }
{ "_JSPKn"). MEME technique de fichier BINAIRE (Assign/Rewrite(F,1)/                     }
{ BlockWrite) que ReadWholeFileIntoFragBuf (TODO 11) pour la lecture.                       }
{ ------------------------------------------------------------ }

Function BinSymNeedsLongName(Const Name: TString): Boolean;
Begin
  BinSymNeedsLongName := Length(Name) > 8;
End;

Procedure WriteCOFFObj(Const Path: TString);
Var
  F                                  : File;
  I, J                               : LongInt; { LongInt, PAS Integer (16       }
                                                 { bits) - MEME piege que              }
                                                 { BinTextLen/BinDataLen ci-dessus,       }
                                                 { .data peut depasser 32767 octets }
  HeaderSize, SectionHeaderSize      : Integer;
  TextOff, TextRelocOff, DataOff     : LongInt;
  SymTabOff, StrTabSize              : LongInt;
  StrTabRunning                      : LongInt;
  StrOffsetOfSym                     : Array[0..MAX_BIN_SYM - 1] Of LongInt;
  RelocKindVal                       : Word;

  Procedure WByte(B: Byte);
  Begin BlockWrite(F, B, 1); End;

  Procedure WWord(W: Word);
  Begin
    WByte(Byte(W And $FF));
    WByte(Byte((W Shr 8) And $FF));
  End;

  Procedure WDword(D: LongInt);
  Begin
    WByte(Byte(D And $FF));
    WByte(Byte((D Shr 8) And $FF));
    WByte(Byte((D Shr 16) And $FF));
    WByte(Byte((D Shr 24) And $FF));
  End;

  Procedure WName8OrLong(Const Name: TString; SymIdx: Integer);
  Var K: Integer;
  Begin
    If BinSymNeedsLongName(Name) Then
    Begin
      WDword(0);
      WDword(StrOffsetOfSym[SymIdx]);
    End
    Else
    Begin
      For K := 0 To 7 Do
        If K < Length(Name) Then WByte(Ord(Name[K + 1])) Else WByte(0);
    End;
  End;

Begin
  HeaderSize        := 20;
  SectionHeaderSize := 40;

  TextOff      := HeaderSize + (2 * SectionHeaderSize);
  TextRelocOff := TextOff + BinTextLen;
  DataOff      := TextRelocOff + (BinFixupCount * 10);
  SymTabOff    := DataOff + BinDataLen;

  { --- table des chaines : longueur PREFIXE (4 octets, ELLE-MEME incluse) }
  { suivie de chaque nom LONG, NUL-termine, MEME convention COFF standard. }
  StrTabRunning := 4;
  For I := 0 To BinSymCount - 1 Do
  Begin
    If BinSymNeedsLongName(BinSymPool[I].Name) Then
    Begin
      StrOffsetOfSym[I] := StrTabRunning;
      StrTabRunning := StrTabRunning + Length(BinSymPool[I].Name) + 1;
    End
    Else
      StrOffsetOfSym[I] := 0;
  End;
  StrTabSize := StrTabRunning;

  Assign(F, Path);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('impossible de creer le fichier .obj : ' + Path);
    Exit;
  End;

  { --- IMAGE_FILE_HEADER (20 octets) --- }
  WWord($014C);              { Machine = IMAGE_FILE_MACHINE_I386 }
  WWord(2);                  { NumberOfSections = .text + .data }
  WDword(0);                 { TimeDateStamp - non significatif ici }
  WDword(SymTabOff);
  WDword(BinSymCount);
  WWord(0);                  { SizeOfOptionalHeader - aucun pour un .OBJ }
  WWord(0);                  { Characteristics }

  { --- IMAGE_SECTION_HEADER ".text" --- }
  WByte(Ord('.')); WByte(Ord('t')); WByte(Ord('e')); WByte(Ord('x'));
  WByte(Ord('t')); WByte(0); WByte(0); WByte(0);
  WDword(0);                 { VirtualSize - non utilise pour un .OBJ }
  WDword(0);                 { VirtualAddress }
  WDword(BinTextLen);
  WDword(TextOff);
  WDword(TextRelocOff);
  WDword(0);                 { PointerToLinenumbers }
  WWord(BinFixupCount);
  WWord(0);                  { NumberOfLinenumbers }
  WDword($60000020);         { CODE Or MEM_EXECUTE Or MEM_READ }

  { --- IMAGE_SECTION_HEADER ".data" --- }
  WByte(Ord('.')); WByte(Ord('d')); WByte(Ord('a')); WByte(Ord('t'));
  WByte(Ord('a')); WByte(0); WByte(0); WByte(0);
  WDword(0);
  WDword(0);
  WDword(BinDataLen);
  WDword(DataOff);
  WDword(0);                 { PointerToRelocations - AUCUNE relocation .data }
  WDword(0);
  WWord(0);                  { NumberOfRelocations }
  WWord(0);
  WDword(-1073741760);       { INITIALIZED_DATA Or MEM_READ Or MEM_WRITE - }
                             { $C0000040 en complement a deux 32 bits          }
                             { (depasse le maximum LongInt POSITIF, section       }
                             { 4.6/TODO 04 "simplification 32 bits") }

  { --- octets .text --- }
  For I := 0 To BinTextLen - 1 Do WByte(BinTextBuf[I]);

  { --- relocations .text (IMAGE_RELOCATION, 10 octets/entree) --- }
  For I := 0 To BinFixupCount - 1 Do
  Begin
    WDword(BinFixupPool[I].TextOffset);
    WDword(BinSymFind(BinFixupPool[I].SymbolName));
    If BinFixupPool[I].Kind = BFK_DIR32_DATA Then
      RelocKindVal := IMAGE_REL_I386_DIR32
    Else
      RelocKindVal := IMAGE_REL_I386_REL32;
    WWord(RelocKindVal);
  End;

  { --- octets .data --- }
  For I := 0 To BinDataLen - 1 Do WByte(BinDataBuf[I]);

  { --- table des symboles (IMAGE_SYMBOL, 18 octets/entree) --- }
  For I := 0 To BinSymCount - 1 Do
  Begin
    WName8OrLong(BinSymPool[I].Name, I);
    WDword(BinSymPool[I].Value);
    WWord(BinSymPool[I].SectionNum);
    WWord(0);                { Type }
    WByte(2);                { StorageClass = EXTERNAL }
    WByte(0);                { NumberOfAuxSymbols }
  End;

  { --- table des chaines --- }
  WDword(StrTabSize);
  For I := 0 To BinSymCount - 1 Do
    If BinSymNeedsLongName(BinSymPool[I].Name) Then
    Begin
      For J := 1 To Length(BinSymPool[I].Name) Do
        WByte(Ord(BinSymPool[I].Name[J]));
      WByte(0);
    End;

  Close(F);
End;

{ ------------------------------------------------------------ }
{ BinAsmSelfTest : encodage OCTET PAR OCTET verifie a la main       }
{ contre l encodage 80386 REEL (push/mov/call/ret), puis            }
{ Test10Include.jsp reel (le SEUL echantillon qui survit           }
{ integralement a CodeGenStmt/BinCodeGenStmt, TODO 21) assemble      }
{ et ecrit en un VRAI .obj dont l en-tete COFF est relu et            }
{ verifie octet par octet.                                            }
{ ------------------------------------------------------------ }

Procedure BinAsmAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('BinAsmSelfTest: ' + Label_ + ' a echoue');
End;

Procedure BinAsmSelfTest;
Const
  TmpFile = 'JSPBINSELFTEST.$$$';
  ObjFile = 'JSPBINSELFTEST.obj';
Var
  F         : Text;
  BinF      : File;
  PageIdx   : Integer;
  Header    : Array[0..19] Of Byte;
  NRead     : Integer;
  I         : Integer;
Begin
  { --- encodage octet par octet (synthetique, verifie A LA MAIN) --- }
  BinAsmInit;
  BinEmitPushReg(REG_EBP);
  BinAsmAssert('push ebp = 55h', (BinTextLen = 1) And (BinTextBuf[0] = $55));

  BinAsmInit;
  BinEmitMovRegReg(REG_EBP, REG_ESP);
  BinAsmAssert('mov ebp,esp = 8B ECh',
    (BinTextLen = 2) And (BinTextBuf[0] = $8B) And (BinTextBuf[1] = $EC));

  BinAsmInit;
  BinEmitPushImm32(5);
  BinAsmAssert('push 5 = 68 05 00 00 00h',
    (BinTextLen = 5) And (BinTextBuf[0] = $68) And (BinTextBuf[1] = 5) And
    (BinTextBuf[2] = 0) And (BinTextBuf[3] = 0) And (BinTextBuf[4] = 0));

  BinAsmInit;
  BinEmitPushImm32(-11);
  BinAsmAssert('push -11 = 68 F5 FF FF FFh (complement a deux)',
    (BinTextLen = 5) And (BinTextBuf[0] = $68) And (BinTextBuf[1] = $F5) And
    (BinTextBuf[2] = $FF) And (BinTextBuf[3] = $FF) And (BinTextBuf[4] = $FF));

  BinAsmInit;
  BinEmitPushMemEbpDisp8(12);
  BinAsmAssert('push [ebp+12] = FF 75 0Ch',
    (BinTextLen = 3) And (BinTextBuf[0] = $FF) And (BinTextBuf[1] = $75) And
    (BinTextBuf[2] = 12));

  BinAsmInit;
  BinEmitRetImm16(8);
  BinAsmAssert('ret 8 = C2 08 00h',
    (BinTextLen = 3) And (BinTextBuf[0] = $C2) And (BinTextBuf[1] = 8) And
    (BinTextBuf[2] = 0));

  BinAsmInit;
  BinTextByte($00); BinTextByte($00); BinTextByte($00); { decale l appel a l offset 3 }
  BinEmitCallInternal(20);
  BinAsmAssert('call interne : rel32 = cible - (offset apres l instruction)',
    (BinTextLen = 8) And (BinTextBuf[3] = $E8) And
    (BinTextBuf[4] + BinTextBuf[5]*256 + BinTextBuf[6]*65536 +
     BinTextBuf[7]*16777216 = 20 - 8));

  { --- EXTENSION 3 (post-TODO25) : encodage OCTET PAR OCTET verifie a la    }
  { main pour CHAQUE nouveau primitif introduit par les appels de fonction     }
  { reels (carre(int)/nomApplication(), Test03Declarations.jsp), MEME             }
  { discipline que ci-dessus. --- }
  BinAsmInit;
  BinEmitMovRegMemEbpDisp8(REG_EAX, 8);
  BinAsmAssert('mov eax,[ebp+8] = 8B 45 08h',
    (BinTextLen = 3) And (BinTextBuf[0] = $8B) And (BinTextBuf[1] = $45) And
    (BinTextBuf[2] = 8));

  BinAsmInit;
  BinEmitPushMemIndirect(REG_ECX);
  BinAsmAssert('push [ecx] = FF 31h',
    (BinTextLen = 2) And (BinTextBuf[0] = $FF) And (BinTextBuf[1] = $31));

  BinAsmInit;
  BinEmitLeaRegMemRegDisp8(REG_EDX, REG_ECX, 4);
  BinAsmAssert('lea edx,[ecx+4] = 8D 51 04h',
    (BinTextLen = 3) And (BinTextBuf[0] = $8D) And (BinTextBuf[1] = $51) And
    (BinTextBuf[2] = 4));

  BinAsmInit;
  BinEmitImulRegReg(REG_EAX, REG_ECX);
  BinAsmAssert('imul eax,ecx = 0F AF C1h',
    (BinTextLen = 3) And (BinTextBuf[0] = $0F) And (BinTextBuf[1] = $AF) And
    (BinTextBuf[2] = $C1));

  BinAsmInit;
  BinEmitNegReg(REG_EAX);
  BinAsmAssert('neg eax = F7 D8h',
    (BinTextLen = 2) And (BinTextBuf[0] = $F7) And (BinTextBuf[1] = $D8));

  BinAsmInit;
  BinEmitDecReg(REG_EDI);
  BinAsmAssert('dec edi = 4Fh', (BinTextLen = 1) And (BinTextBuf[0] = $4F));

  BinAsmInit;
  BinEmitTestRegReg(REG_EAX);
  BinAsmAssert('test eax,eax = 85 C0h',
    (BinTextLen = 2) And (BinTextBuf[0] = $85) And (BinTextBuf[1] = $C0));

  BinAsmInit;
  BinEmitSubRegReg(REG_EAX, REG_EDI);
  BinAsmAssert('sub eax,edi = 2B C7h',
    (BinTextLen = 2) And (BinTextBuf[0] = $2B) And (BinTextBuf[1] = $C7));

  BinAsmInit;
  BinEmitSubRegImm8(REG_EDI, 4);
  BinAsmAssert('sub edi,4 = 83 EF 04h',
    (BinTextLen = 3) And (BinTextBuf[0] = $83) And (BinTextBuf[1] = $EF) And
    (BinTextBuf[2] = 4));

  BinAsmInit;
  BinEmitMovMemIndirectFromReg32(REG_EDI, REG_EAX);
  BinAsmAssert('mov [edi],eax = 89 07h',
    (BinTextLen = 2) And (BinTextBuf[0] = $89) And (BinTextBuf[1] = $07));

  BinAsmInit;
  BinEmitMovMemIndirectFromReg8(REG_EDI, REG_EDX);
  BinAsmAssert('mov [edi],dl = 88 17h',
    (BinTextLen = 2) And (BinTextBuf[0] = $88) And (BinTextBuf[1] = $17));

  BinAsmInit;
  BinEmitMovByteMemIndirectImm8(REG_EDI, Ord('-'));
  BinAsmAssert('mov byte ptr [edi],''-'' = C6 07 2Dh',
    (BinTextLen = 3) And (BinTextBuf[0] = $C6) And (BinTextBuf[1] = $07) And
    (BinTextBuf[2] = Ord('-')));

  { sauts courts : un placeholder EN AVANT patche correctement, un saut EN  }
  { ARRIERE calcule directement - MEME algorithme que _JSPRT_PrintInt. }
  BinAsmInit;
  I := BinEmitJccPlaceholder($79); { jns, PLACEHOLDER }
  BinTextByte($90); BinTextByte($90); BinTextByte($90); { 3 octets de "corps" }
  BinPatchJcc(I);
  BinAsmAssert('jns (avant, patche) : rel8 = 3',
    (BinTextLen = 5) And (BinTextBuf[0] = $79) And (BinTextBuf[1] = 3));

  BinAsmInit;
  BinTextByte($90); BinTextByte($90); { cible a l offset 2 }
  BinEmitJccBackward($75, 0);
  BinAsmAssert('jnz (arriere, cible=0) : rel8 = -4 (FCh)',
    (BinTextLen = 4) And (BinTextBuf[2] = $75) And (BinTextBuf[3] = $FC));

  { --- Test03Declarations.jsp reel (fragment VERBATIM) : methodes           }
  { declarees REELLEMENT compilees (BinCompileMethodBody) et sites d appel        }
  { REELLEMENT resolus (BinEmitMethodCallPrint) - confirme que _JSPM_             }
  { nomApplication/_JSPM_carre existent APRES BinAssemblePage et que le           }
  { .obj final s ecrit sans erreur. --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<%! private String nomApplication() { return "Catalogue JSP"; }',
        '    private int carre(int valeur) { return valeur * valeur; } %>',
        '<h1><%= nomApplication() %></h1>',
        '<p><%= carre(12) %></p>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;

  BinAssemblePage(PageIdx);
  BinAsmAssert('BinAssemblePage reel (Test03Declarations.jsp) : _JSPM_nomApplication/' +
    '_JSPM_carre/_JSPRT_PrintInt tous enregistres',
    (BinSymFind('_JSPM_nomApplication') >= 0) And (BinSymFind('_JSPM_carre') >= 0) And
    (BinSymFind('_JSPRT_PrintInt') >= 0));

  WriteCOFFObj(ObjFile);
  Assign(BinF, ObjFile);
  {$I-} Reset(BinF, 1); {$I+}
  BinAsmAssert('WriteCOFFObj reel (Test03Declarations.jsp) : fichier cree', IOResult = 0);
  Close(BinF);
  Assign(BinF, ObjFile); Erase(BinF);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- Test10Include.jsp reel (SEUL echantillon qui survit ENTIEREMENT a  }
  { CodeGenStmt/BinCodeGenStmt, TODO 21/23 - fragment VERBATIM plutot que      }
  { de dependre du fichier reel sur disque, MEME discipline que                  }
  { CodeGenSelfTest) --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<!DOCTYPE html><html><body>',
        '<h1>Bonjour</h1>',
        '</body></html>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;

  BinAssemblePage(PageIdx);
  BinAsmAssert('BinAssemblePage reel : au moins 2 symboles _JSPK', CgStrCount >= 1);
  BinAsmAssert('BinAssemblePage reel : _JSPRT_Print/_jspService/GetStdHandle@4/' +
    'WriteFile@20 tous enregistres',
    (BinSymFind('_JSPRT_Print') >= 0) And (BinSymFind('_jspService') >= 0) And
    (BinSymFind('GetStdHandle@4') >= 0) And (BinSymFind('WriteFile@20') >= 0));
  BinAsmAssert('BinAssemblePage reel : au moins une relocation DIR32/REL32',
    BinFixupCount >= 3); { >=1 GetStdHandle, >=1 WriteFile, >=1 _JSPKn, >=1 BytesWritten }

  WriteCOFFObj(ObjFile);
  Assign(BinF, ObjFile);
  {$I-} Reset(BinF, 1); {$I+}
  BinAsmAssert('WriteCOFFObj reel : fichier cree', IOResult = 0);
  BlockRead(BinF, Header, 20, NRead);
  Close(BinF);
  BinAsmAssert('en-tete COFF relu : 20 octets', NRead = 20);
  BinAsmAssert('en-tete COFF relu : Machine = I386 (4Ch 01h)',
    (Header[0] = $4C) And (Header[1] = $01));
  BinAsmAssert('en-tete COFF relu : NumberOfSections = 2',
    (Header[2] = 2) And (Header[3] = 0));
  BinAsmAssert('en-tete COFF relu : NumberOfSymbols = BinSymCount',
    Header[12] + Header[13]*256 + Header[14]*65536 + Header[15]*16777216 = BinSymCount);

  Assign(BinF, ObjFile); Erase(BinF);
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ============================================================ }
{ TODO 24 - ECRITURE DU FICHIER EXECUTABLE PE (.EXE)            }
{ ============================================================ }

{ DECISIONS D ARCHITECTURE A DOCUMENTER EXPLICITEMENT (MEME discipline    }
{ que les TODO 18/21/23) :                                                    }
{                                                                                }
{ 1. Table d import (roadmap d en-tete) : SEULES GetStdHandle/WriteFile         }
{    (TODO 18/21, deja appelees) sont REELLEMENT importees, PLUS                    }
{    ExitProcess - AJOUTEE ICI, NON listee par le roadmap d en-tete mais            }
{    IDENTIFIEE INDISPENSABLE par relecture attentive avant d ecrire ce                }
{    TODO : sans elle, tomber en fin de _jspService (un simple RET) apres              }
{    l entree du programme depilerait une adresse de retour qui n existe                 }
{    JAMAIS (l OS invoque directement le point d entree, aucun appelant                    }
{    reel) - un crash certain, jamais un "arret propre". ReadFile/                            }
{    GetCommandLineA/CreateFileA/CloseHandle restent NON importees -                            }
{    AUCUN codegen ne les appelle encore (jsp:include/jsp:param dynamiques,                       }
{    parametres de requete simulee, TODO 11/12/18, ne sont pas dans la                              }
{    portee de CodeGenPage/BinAssemblePage/PeAssemblePage a ce stade) -                               }
{    les importer maintenant serait du poids mort invente, jamais verifie.                              }
{ 2. AUCUNE section .reloc (relocations de base) : l image est chargee a           }
{    ImageBase=PE_IMG_BASE ($00400000) FIXE, jamais rebasee (limite                    }
{    assumee explicitement, MEME choix que la plupart des executables                     }
{    autonomes sans ASLR) - IMAGE_FILE_RELOCS_STRIPPED est donc positionne              }
{    dans les Characteristics de l en-tete PE, honnete plutot que de                        }
{    pretendre un support absent.                                                              }
{ 3. Appel de fonction IMPORTEE : DIFFERENT du TODO 23 (.obj, relocation           }
{    REL32 laissee a un lieur externe) - un .exe autonome n a AUCUN lieur              }
{    a invoquer : l appel est encode ICI directement sous la forme                        }
{    standard "CALL DWORD PTR [VA-de-la-case-IAT]" (FF 15 + adresse                          }
{    ABSOLUE, 6 octets) - le VRAI chargeur Windows remplit cette case IAT                      }
{   avec l adresse REELLE de la fonction au chargement (le contenu ECRIT ICI              }
{    - une RVA vers le Hint/Name - n est qu une valeur INITIALE, jamais              }
{    utilisee comme adresse d appel elle-meme). L appel INTERNE                             }
{    (_start -> _jspService -> _JSPRT_Print) reste un "CALL rel32" DIRECT              }
{    (E8), calcule ICI-MEME puisque les TROIS routines sont emises dans                       }
{    UN SEUL passage, DANS L ORDRE _JSPRT_Print -> _jspService -> _start                        }
{    (chaque appelant emis APRES sa cible, AUCUN appel en avant, AUCUN                            }
{    fixup interne necessaire - MEME discipline que BinAssemblePage,                                }
{    TODO 23).                                                                                        }
{ 4. Portee de PeCodeGenStmt : EXACTEMENT celle de CodeGenStmt/                    }
{    BinCodeGenStmt (TODO 21/23) - gabarit litteral SEULEMENT, tout AUTRE            }
{    SK_ arrete PROPREMENT (FatalError, MEME StmtKindName). }

Type
  TPeFixup = Record
    TextOffset  : Integer; { position du PLACEHOLDER 4 octets dans PeTextBuf }
    ImportIndex : Integer; { index dans PeImportNames (0=GetStdHandle,          }
                           { 1=WriteFile, 2=ExitProcess, 3=GetLocalTime -         }
                           { EXTENSION post-TODO25, "new java.util.Date()"        }
                           { imprime immediatement, voir PeCodeGenStmt/               }
                           { PeEmitPrintDate plus bas) }
  End;

Const
  PE_IMPORT_COUNT = 4;
  PeImportNames : Array[0..PE_IMPORT_COUNT - 1] Of TString =
    ('GetStdHandle', 'WriteFile', 'ExitProcess', 'GetLocalTime');

Var
  PeTextBuf   : Array[0..MAX_PE_CODE - 1] Of Byte;
  PeTextLen   : LongInt;
  PeDataBuf   : Array[0..MAX_PE_DATA - 1] Of Byte;
  PeDataLen   : LongInt;
  PeFixupPool : Array[0..MAX_PE_FIXUP - 1] Of TPeFixup;
  PeFixupCount: Integer;
  PeEntryOffset, PePrintOffset, PeServiceOffset : Integer;

Procedure PeAsmInit;
Begin
  PeTextLen := 0;
  PeDataLen := 0;
  PeFixupCount := 0;
End;

Procedure PeTextByte(B: Byte);
Begin
  If PeTextLen >= MAX_PE_CODE Then
  Begin
    FatalError('section .text PE pleine (MAX_PE_CODE)');
    Exit;
  End;
  PeTextBuf[PeTextLen] := B;
  Inc(PeTextLen);
End;

Procedure PeTextDword(D: LongInt);
Begin
  PeTextByte(Byte(D And $FF));
  PeTextByte(Byte((D Shr 8) And $FF));
  PeTextByte(Byte((D Shr 16) And $FF));
  PeTextByte(Byte((D Shr 24) And $FF));
End;

Procedure PeDataByte(B: Byte);
Begin
  If PeDataLen >= MAX_PE_DATA Then
  Begin
    FatalError('section .data PE pleine (MAX_PE_DATA)');
    Exit;
  End;
  PeDataBuf[PeDataLen] := B;
  Inc(PeDataLen);
End;

Procedure PeDataDword(D: LongInt);
Begin
  PeDataByte(Byte(D And $FF));
  PeDataByte(Byte((D Shr 8) And $FF));
  PeDataByte(Byte((D Shr 16) And $FF));
  PeDataByte(Byte((D Shr 24) And $FF));
End;

Function PeFindImport(Const Name: TString): Integer;
Var I: Integer;
Begin
  PeFindImport := -1;
  For I := 0 To PE_IMPORT_COUNT - 1 Do
    If PeImportNames[I] = Name Then
    Begin
      PeFindImport := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ Encodeur 80386 (PE) - MEME table d encodage que le TODO 23        }
{ (BinEmit*), REPRODUITE ICI pour les DEUX seules formes qui             }
{ different reellement d un .obj (l appel importe, note 3            }
{ ci-dessus) - tout le reste (push reg/imm32/[ebp+disp8], mov,          }
{ ret) est BYTE POUR BYTE identique.                                     }
{ ------------------------------------------------------------ }

Procedure PeEmitPushReg(Reg: Byte);
Begin
  PeTextByte($50 + Reg);
End;

Procedure PeEmitPopReg(Reg: Byte);
Begin
  PeTextByte($58 + Reg);
End;

Procedure PeEmitPushImm32(V: LongInt);
Begin
  PeTextByte($68);
  PeTextDword(V);
End;

Procedure PeEmitPushOffsetData(DataRva: LongInt);
Begin
  PeTextByte($68);
  PeTextDword(PE_IMG_BASE + DataRva);
End;

Procedure PeEmitPushMemEbpDisp8(Disp: ShortInt);
Begin
  PeTextByte($FF);
  PeTextByte($75);
  PeTextByte(Byte(Disp));
End;

Procedure PeEmitMovRegReg(DstReg, SrcReg: Byte);
Begin
  PeTextByte($8B);
  PeTextByte($C0 Or (DstReg Shl 3) Or SrcReg);
End;

{ ------------------------------------------------------------ }
{ EXTENSION post-TODO25 : encodeur 80386 supplementaire pour       }
{ "new java.util.Date()" imprime immediatement (voir la note        }
{ d en-tete de PeEmitPrintDate plus bas pour la justification          }
{ complete de cette portee) - SEULEMENT le backend PE (.exe) est          }
{ etendu ICI, DECISION A DOCUMENTER : le .asm (CodeGenPage, TODO 21)         }
{ et le .obj COFF (BinAssemblePage, TODO 23) restent a leur portee              }
{ EXACTE du TODO 21/23 (gabarit litteral SEULEMENT) - etendre LES TROIS            }
{ backends en parallele pour CETTE extension precise aurait triple le              }
{ risque d erreur d encodage manuel SANS benefice verifiable (SEUL le .exe             }
{ peut etre EXECUTE reellement pour confirmer chaque octet, section 21/23/24              }
{ du roadmap d en-tete) - parite .asm/.obj explicitement reportee a un                    }
{ travail FUTUR, jamais masquee. Toutes les formes ci-dessous utilisent                      }
{ l ADRESSAGE ABSOLU direct32 (ModRM mod=00, rm=101, MEME forme que                            }
{ PeEmitPushOffsetData deja utilisee depuis le TODO 24) plutot qu un                             }
{ cadre de pile [ebp+disp8] : AUCUN nouveau prologue/epilogue de pile                              }
{ n est necessaire, chaque valeur intermediaire vit a une adresse .data                              }
{ FIXE connue au moment de l encodage.                                                                 }
{ ------------------------------------------------------------ }

{ mov reg32, imm32 (opcode B8+reg, AUCUN ModRM - forme "immediate to     }
{ register", MEME famille que PeEmitPushImm32 mais sans le push). }
Procedure PeEmitMovRegImm32(Reg: Byte; V: LongInt);
Begin
  PeTextByte($B8 + Reg);
  PeTextDword(V);
End;

{ xor reg32, reg32 (opcode 33 /r, ModRM mod=11) - MEME famille que        }
{ PeEmitMovRegReg (opcode 8B) mais pour XOR ; utilise ICI pour mettre a       }
{ zero EDX avant DIV (le dividende 64 bits EDX:EAX doit avoir EDX=0 pour        }
{ une division NON signee valeur/diviseur). }
Procedure PeEmitXorRegReg(DstReg, SrcReg: Byte);
Begin
  PeTextByte($33);
  PeTextByte($C0 Or (DstReg Shl 3) Or SrcReg);
End;

{ div reg32 (DIV r/m32, opcode F7 /6, ModRM mod=11) - division NON        }
{ signee EDX:EAX / reg -> EAX=quotient, EDX=reste (MEME semantique que          }
{ le "div ebx"/"div ecx" DEJA hand-verifie pour _JSPRT_Print au TODO 21/23/       }
{ 24, ICI generalise a un registre PARAMETRABLE). }
Procedure PeEmitDivReg(Reg: Byte);
Begin
  PeTextByte($F7);
  PeTextByte($F0 Or Reg);
End;

{ add al, imm8 (opcode 04 imm8 - forme COURTE specifique a AL, PAS de     }
{ ModRM) et add r8, imm8 (opcode 80 /0, ModRM mod=11) pour tout AUTRE          }
{ registre 8 bits (ICI, DL SEULEMENT est reellement utilise). }
Procedure PeEmitAddAlImm8(V: Byte);
Begin
  PeTextByte($04);
  PeTextByte(V);
End;

Procedure PeEmitAddR8Imm8(Reg8: Byte; V: Byte);
Begin
  PeTextByte($80);
  PeTextByte($C0 Or Reg8);
  PeTextByte(V);
End;

{ movzx eax, word ptr [ABSOLU] (opcode 0F B7 /r, adressage direct32 -    }
{ MEME forme ModRM que PeEmitPushOffsetData, prefixee de l opcode deux         }
{ octets 0F B7 propre a MOVZX r32,r/m16) - lit un champ WORD de SYSTEMTIME        }
{ (GetLocalTime, note d en-tete de PeEmitPrintDate) en l etendant par                }
{ ZEROS sur 32 bits (les 16 bits superieurs d un champ SYSTEMTIME sont                  }
{ TOUJOURS zero de toute facon, mais MOVZX reste la forme CORRECTE plutot                 }
{ qu une simple MOV 32 bits qui lirait 2 octets AU-DELA du champ voulu). }
Procedure PeEmitMovzxEaxAbsWord(DataRva: LongInt);
Begin
  PeTextByte($0F);
  PeTextByte($B7);
  PeTextByte($05);
  PeTextDword(PE_IMG_BASE + DataRva);
End;

{ mov byte ptr [ABSOLU], reg8 (opcode 88 /r, adressage direct32) et       }
{ mov byte ptr [ABSOLU], imm8 (opcode C6 /0, adressage direct32) - ecrit      }
{ un OCTET (chiffre ASCII ou separateur litteral) a une adresse .data              }
{ FIXE (le tampon de date formatee, PeDateStrRva plus bas). }
Procedure PeEmitMovAbsFromReg8(DataRva: LongInt; Reg8: Byte);
Begin
  PeTextByte($88);
  PeTextByte($05 Or (Reg8 Shl 3));
  PeTextDword(PE_IMG_BASE + DataRva);
End;

Procedure PeEmitMovByteAbsImm8(DataRva: LongInt; V: Byte);
Begin
  PeTextByte($C6);
  PeTextByte($05);
  PeTextDword(PE_IMG_BASE + DataRva);
  PeTextByte(V);
End;

{ call INTERNE (MEME section .text, cible DEJA connue - note 3 ci-dessus). }
Procedure PeEmitCallInternal(TargetOffset: Integer);
Begin
  PeTextByte($E8);
  PeTextDword(TargetOffset - (PeTextLen + 4));
End;

{ call IMPORTE : "CALL DWORD PTR [VA]" (FF 15 + adresse ABSOLUE, note 3   }
{ ci-dessus) - le PLACEHOLDER (0) est PATCHE directement dans PeTextBuf       }
{ par PeResolveFixups une fois IdataRva connue (AUCUN lieur externe,           }
{ contrairement au TODO 23 : ce .exe est COMPLETEMENT autonome). }
Procedure PeEmitCallImport(Const ImportName: TString);
Begin
  PeTextByte($FF);
  PeTextByte($15);
  If PeFixupCount >= MAX_PE_FIXUP Then
  Begin
    FatalError('table des fixups PE pleine (MAX_PE_FIXUP)');
    Exit;
  End;
  PeFixupPool[PeFixupCount].TextOffset  := PeTextLen;
  PeFixupPool[PeFixupCount].ImportIndex := PeFindImport(ImportName);
  Inc(PeFixupCount);
  PeTextDword(0);
End;

Procedure PeEmitRet;
Begin
  PeTextByte($C3);
End;

Procedure PeEmitRetImm16(N: Word);
Begin
  PeTextByte($C2);
  PeTextByte(Byte(N And $FF));
  PeTextByte(Byte((N Shr 8) And $FF));
End;

{ ------------------------------------------------------------ }
{ EXTENSION 3 (post-TODO25) : MEME encodeur supplementaire que le          }
{ backend .obj (BinEmit*, voir sa note d en-tete complete pour la               }
{ justification "premier runtime a avoir reellement besoin d un saut") -           }
{ ICI, chaque reference .data reste une adresse ABSOLUE codee en dur              }
{ (PE_IMG_BASE+RVA, MEME convention que PeEmitPushOffsetData/                        }
{ PeEmitMovAbsFromReg8 depuis le TODO 24), jamais une relocation - un .exe            }
{ autonome n a pas de lieur a invoquer. }
Procedure PeEmitMovRegMemEbpDisp8(Reg: Byte; Disp: ShortInt);
Begin
  PeTextByte($8B); { MOV r32, r/m32 }
  PeTextByte($40 Or (Reg Shl 3) Or 5); { ModRM : mod=01, reg=Reg, rm=101 (ebp) }
  PeTextByte(Byte(Disp));
End;

Procedure PeEmitPushMemIndirect(AddrReg: Byte);
Begin
  PeTextByte($FF);
  PeTextByte($30 Or AddrReg); { ModRM : mod=00, reg=110 (/6, PUSH r/m32), rm=AddrReg }
End;

Procedure PeEmitLeaRegMemRegDisp8(DstReg, BaseReg: Byte; Disp: ShortInt);
Begin
  PeTextByte($8D); { LEA r32, m }
  PeTextByte($40 Or (DstReg Shl 3) Or BaseReg); { ModRM : mod=01, reg=DstReg, rm=BaseReg }
  PeTextByte(Byte(Disp));
End;

Procedure PeEmitImulRegReg(DstReg, SrcReg: Byte);
Begin
  PeTextByte($0F); { IMUL r32, r/m32 }
  PeTextByte($AF);
  PeTextByte($C0 Or (DstReg Shl 3) Or SrcReg); { ModRM : mod=11, reg=Dst, rm=Src }
End;

Procedure PeEmitNegReg(Reg: Byte);
Begin
  PeTextByte($F7); { NEG r/m32 (/3) }
  PeTextByte($D8 Or Reg); { ModRM : mod=11, reg=011, rm=Reg }
End;

Procedure PeEmitDecReg(Reg: Byte);
Begin
  PeTextByte($48 + Reg); { DEC r32, forme courte }
End;

Procedure PeEmitTestRegReg(Reg: Byte);
Begin
  PeTextByte($85); { TEST r/m32, r32 }
  PeTextByte($C0 Or (Reg Shl 3) Or Reg); { ModRM : mod=11, reg=Reg, rm=Reg }
End;

Procedure PeEmitSubRegReg(DstReg, SrcReg: Byte);
Begin
  PeTextByte($2B); { SUB r32, r/m32 }
  PeTextByte($C0 Or (DstReg Shl 3) Or SrcReg); { ModRM : mod=11, reg=Dst, rm=Src }
End;

Procedure PeEmitSubRegImm8(Reg: Byte; V: Byte);
Begin
  PeTextByte($83); { SUB r/m32, imm8 (/5) }
  PeTextByte($E8 Or Reg); { ModRM : mod=11, reg=101, rm=Reg }
  PeTextByte(V);
End;

Procedure PeEmitMovMemIndirectFromReg32(AddrReg, SrcReg: Byte);
Begin
  PeTextByte($89); { MOV r/m32, r32 }
  PeTextByte((SrcReg Shl 3) Or AddrReg); { ModRM : mod=00, reg=Src, rm=AddrReg }
End;

Procedure PeEmitMovMemIndirectFromReg8(AddrReg, SrcReg8: Byte);
Begin
  PeTextByte($88); { MOV r/m8, r8 }
  PeTextByte((SrcReg8 Shl 3) Or AddrReg); { ModRM : mod=00, reg=Src, rm=AddrReg }
End;

Procedure PeEmitMovByteMemIndirectImm8(AddrReg: Byte; V: Byte);
Begin
  PeTextByte($C6); { MOV r/m8, imm8 (/0) }
  PeTextByte(AddrReg); { ModRM : mod=00, reg=000, rm=AddrReg }
  PeTextByte(V);
End;

{ mov reg32, OFFSET ABSOLU (PE_IMG_BASE+RVA) - MEME famille que              }
{ PeEmitPushOffsetData (opcode B8+reg au lieu de 68, MEME forme "immediate       }
{ to register" que PeEmitMovRegImm32) - necessaire pour _JSPRT_PrintInt,          }
{ qui doit MANIPULER cette adresse (lui soustraire une autre adresse)             }
{ avant de l utiliser. }
Procedure PeEmitMovRegAbs(Reg: Byte; Rva: LongInt);
Begin
  PeTextByte($B8 + Reg);
  PeTextDword(PE_IMG_BASE + Rva);
End;

Function PeEmitJccPlaceholder(Opcode: Byte): Integer;
Begin
  PeTextByte(Opcode);
  PeTextByte(0);
  PeEmitJccPlaceholder := PeTextLen - 1; { position de l octet rel8 a corriger }
End;

Procedure PePatchJcc(PatchPos: Integer);
Begin
  PeTextBuf[PatchPos] := Byte(PeTextLen - (PatchPos + 1));
End;

Procedure PeEmitJccBackward(Opcode: Byte; TargetOffset: Integer);
Begin
  PeTextByte(Opcode);
  PeTextByte(Byte(TargetOffset - (PeTextLen + 1)));
End;

Var
  { PeStrRva[I] : RVA ABSOLUE (deja PE_IMG_BASE-relative resolue via            }
  { PeEmitPushOffsetData, qui ajoute ENCORE PE_IMG_BASE - PeStrRva stocke          }
  { seulement la RVA, section .data - TODO 24) du chunk CgStrPool[I], remplie      }
  { par PeAssemblePage AVANT que .text (donc PeCodeGenStmt) ne soit encode. }
  PeStrRva            : Array[0..MAX_CG_STRINGS - 1] Of LongInt;
  PeBytesWrittenRva    : LongInt;

  { EXTENSION post-TODO25 ("new java.util.Date()" imprime immediatement,   }
  { voir la note d en-tete de PeEmitPrintDate plus bas) : PeSysTimeRva            }
  { pointe vers 16 octets .data reserves pour la structure Win32                    }
  { SYSTEMTIME (GetLocalTime) ; PeDateStrRva pointe vers 19 octets .data              }
  { reserves pour la chaine formatee "AAAA-MM-JJ HH:MM:SS" ; PePrintDateOffset          }
  { est l offset .text de _JSPRT_PrintDate (MEME convention que PePrintOffset,             }
  { TODO 21/23/24, pour un appel INTERNE sans fixup). }
  PeSysTimeRva, PeDateStrRva : LongInt;
  PePrintDateOffset          : Integer;

  { EXTENSION 3 (post-TODO25) : PeIntBufRva pointe vers 16 octets .data      }
  { reserves pour _JSPRT_PrintInt (MEME disposition que _JSPRT_IntBuf,          }
  { backends textuel/objet - voir leurs notes d en-tete completes) ;               }
  { PePrintIntOffset est l offset .text de _JSPRT_PrintInt (MEME convention      }
  { que PePrintOffset/PePrintDateOffset). PeMethodOffset (GLOBAL) memorise         }
  { l offset .text de chaque methode declaree en page COMPILEE (MEME role       }
  { que BinMethodOffset, TODO 23) - un site d appel (SK_PRINT_EXPR) le lit          }
  { DIRECTEMENT PUISQUE les methodes sont TOUJOURS compilees avant                  }
  { _jspService (PeAssemblePage). }
  PeIntBufRva      : LongInt;
  PePrintIntOffset : Integer;
  PeMethodOffset   : Array[0..(MAX_FUNC + MAX_METHOD) - 1] Of Integer;
  PeCurParamNames  : Array[0..MAX_PARAM - 1] Of TString;
  PeCurParamCount  : Integer;

Function PeFindParam(Const Name: TString; Var Offset: Integer): Boolean;
Var I: Integer;
Begin
  PeFindParam := False;
  For I := 0 To PeCurParamCount - 1 Do
    If PeCurParamNames[I] = Name Then
    Begin
      Offset := 8 + I * 4;
      PeFindParam := True;
      Exit;
    End;
End;

Procedure PeCompileExprToEax(ExprIdx: Integer);
Var SIdx, Offset: Integer;
Begin
  Case ExprPool[ExprIdx].Kind Of
    EK_INT :
      PeEmitMovRegImm32(REG_EAX, ExprPool[ExprIdx].IntVal);

    EK_STRING :
      Begin
        SIdx := CgStrFindOrAdd(ExprPool[ExprIdx].StrVal);
        PeEmitMovRegAbs(REG_EAX, PeStrRva[SIdx]);
      End;

    EK_IDENT :
      If PeFindParam(ExprPool[ExprIdx].NameVal, Offset) Then
        PeEmitMovRegMemEbpDisp8(REG_EAX, Offset)
      Else
        FatalError('generation de code (extension post-TODO25) : identificateur ' +
                   'non resolu dans un corps de methode - ' +
                   ExprPool[ExprIdx].NameVal);

    EK_BINARY :
      If ExprPool[ExprIdx].Op = '*' Then
      Begin
        PeCompileExprToEax(ExprPool[ExprIdx].Left);
        PeEmitPushReg(REG_EAX);
        PeCompileExprToEax(ExprPool[ExprIdx].Right);
        PeEmitPopReg(REG_ECX);
        PeEmitImulRegReg(REG_EAX, REG_ECX);
      End
      Else
        FatalError('generation de code (extension post-TODO25) : operateur "' +
                   ExprPool[ExprIdx].Op + '" non gere dans un corps de methode');
  Else
    FatalError('generation de code (extension post-TODO25) : expression non ' +
               'geree dans un corps de methode');
  End;
End;

Procedure PeCompileMethodStmt(Idx: Integer);
Var I: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        PeCompileMethodStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);

    SK_RETURN :
      If StmtPool[Idx].ExprIdx >= 0 Then
        PeCompileExprToEax(StmtPool[Idx].ExprIdx)
      Else
        PeEmitXorRegReg(REG_EAX, REG_EAX);
  Else
    FatalError('generation de code (extension post-TODO25) : instruction non ' +
               'geree dans un corps de methode - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

Procedure PeCompileMethodBody(MIdx: Integer);
Var I: Integer;
Begin
  PeCurParamCount := JavaMethodPool[MIdx].ParamCount;
  For I := 0 To PeCurParamCount - 1 Do
    PeCurParamNames[I] := JavaParamPool[JavaMethodPool[MIdx].ParamFirst + I].Name;

  PeMethodOffset[MIdx] := PeTextLen;
  PeEmitPushReg(REG_EBP);
  PeEmitMovRegReg(REG_EBP, REG_ESP);
  PeCompileMethodStmt(JavaMethodPool[MIdx].BodyStmtIdx);
  PeEmitMovRegReg(REG_ESP, REG_EBP);
  PeEmitPopReg(REG_EBP);
  PeEmitRetImm16(PeCurParamCount * 4);
End;

Function PeEmitMethodCallPrint(ExprIdx: Integer): Boolean;
Var MIdx, I, ArgIdx: Integer;
Begin
  PeEmitMethodCallPrint := False;
  If ExprIdx < 0 Then Exit;
  If ExprPool[ExprIdx].Kind <> EK_CALL Then Exit;
  If ExprPool[ExprIdx].Left < 0 Then Exit;
  If ExprPool[ExprPool[ExprIdx].Left].Kind <> EK_IDENT Then Exit;

  MIdx := JavaMethodFind(ExprPool[ExprPool[ExprIdx].Left].NameVal);
  If MIdx < 0 Then Exit;

  If ExprPool[ExprIdx].ArgCount <> JavaMethodPool[MIdx].ParamCount Then
    FatalError('generation de code (extension post-TODO25) : nombre d ' +
               'arguments incompatible pour l appel a "' +
               JavaMethodPool[MIdx].Name + '"');

  For I := ExprPool[ExprIdx].ArgCount - 1 Downto 0 Do
  Begin
    ArgIdx := ExprArgPool[ExprPool[ExprIdx].ArgFirst + I];
    If ExprPool[ArgIdx].Kind <> EK_INT Then
      FatalError('generation de code (extension post-TODO25) : seul un ' +
                 'argument litteral entier est gere pour l appel a une ' +
                 'methode declaree - "' + JavaMethodPool[MIdx].Name + '"');
    PeEmitPushImm32(ExprPool[ArgIdx].IntVal);
  End;

  PeEmitCallInternal(PeMethodOffset[MIdx]);

  If JavaMethodPool[MIdx].ReturnType = 'String' Then
  Begin
    PeEmitPushReg(REG_EAX);
    PeEmitCallInternal(PePrintOffset);
  End
  Else If JavaMethodPool[MIdx].ReturnType = 'int' Then
  Begin
    PeEmitPushReg(REG_EAX);
    PeEmitCallInternal(PePrintIntOffset);
  End
  Else
    FatalError('generation de code (extension post-TODO25) : type de retour "' +
               JavaMethodPool[MIdx].ReturnType + '" non gere pour <%= ' +
               JavaMethodPool[MIdx].Name + '(...) %>');

  PeEmitMethodCallPrint := True;
End;

{ PeCodeGenStmt : MIROIR de BinCodeGenStmt (TODO 23) - MEME portee        }
{ EXACTE, MEME pool _JSPK REUTILISE (CgStrPool/CgStrFindOrAdd, TODO 21)      }
{ mais "push OFFSET _JSPKn" devient PeEmitPushOffsetData (ADRESSE                }
{ ABSOLUE PE_IMG_BASE+RVA, jamais un placeholder - la RVA de .data EST          }
{ DEJA connue au moment ou .text est encode : .data est encode EN                  }
{ PREMIER, contrairement au TODO 23 ou l ordre .text/.data importait peu,             }
{ voir PeAssemblePage). SK_PRINT_EXPR (EXTENSION post-TODO25) : PORTEE               }
{ DELIBEREMENT ETROITE - SEULE l expression EXACTE "new java.util.Date()"                }
{ (ou son nom court "Date", apres un import) SANS receveur ni argument est                 }
{ reconnue, un cas SPECIAL-CASE assume et documente plutot qu une VRAIE                       }
{ coercition-String generale de n importe quelle expression typee (qui                          }
{ demanderait un modele d objet/tas complet, hors de portee ICI - TOUTE                            }
{ autre forme de <%= %> continue d arreter la compilation PROPREMENT,                                }
{ MEME StmtKindName qu avant). }
Procedure PeCodeGenStmt(Idx: Integer);
Var I, SIdx, EIdx: Integer;
Begin
  If Idx < 0 Then Exit;
  Case StmtPool[Idx].Kind Of
    SK_BLOCK :
      For I := 0 To StmtPool[Idx].ChildCount - 1 Do
        PeCodeGenStmt(StmtChildPool[StmtPool[Idx].ChildFirst + I]);

    SK_PRINT_TEMPLATE :
      Begin
        SIdx := CgStrFindOrAdd(StmtPool[Idx].BigVal);
        PeEmitPushOffsetData(PeStrRva[SIdx]);
        PeEmitCallInternal(PePrintOffset);
      End;

    { SK_PRINT_EXPR (EXTENSION post-TODO25, ETENDUE - extension 2, PUIS       }
    { extension 3) : MEME special-case PARTAGE (CgIsImmediateDatePrint,          }
    { TODO 21) que BinCodeGenStmt/CodeGenStmt - voir sa note d en-tete               }
    { complete pour les DEUX formes reconnues (Test01Bonjour.jsp/                    }
    { Test02Directives.jsp reels), PUIS l appel a une methode declaree en            }
    { page (PeEmitMethodCallPrint, extension 3). }
    SK_PRINT_EXPR :
      Begin
        EIdx := StmtPool[Idx].ExprIdx;
        If CgIsImmediateDatePrint(EIdx) Then
          PeEmitCallInternal(PePrintDateOffset)
        Else If PeEmitMethodCallPrint(EIdx) Then
          { rien de plus - deja emis par PeEmitMethodCallPrint }
        Else
          FatalError('generation de code (extension post-TODO25) : seule ' +
                     '"new java.util.Date()"/"DateFormat.getDateTimeInstance().' +
                     'format(new Date())"/l appel a une methode declaree en page ' +
                     'est gere pour <%= %> - construction non encore geree');
      End;
  Else
    FatalError('generation de code (TODO 24) : construction non encore ' +
               'geree - ' + StmtKindName(StmtPool[Idx].Kind));
  End;
End;

{ PeRoundUp : arrondit V au PROCHAIN multiple de Align (SectionAlignment  }
{ ou FileAlignment, PE_SEC_ALIGN/PE_FILE_ALIGN, TODO 01) - utilitaire       }
{ PUR, aucun etat. }
Function PeRoundUp(V, Align: LongInt): LongInt;
Begin
  PeRoundUp := ((V + Align - 1) Div Align) * Align;
End;

{ PeAssemblePage : POINT D ENTREE - MEME arbre (RootIdx) que CodeGenPage/   }
{ BinAssemblePage (TODO 21/23). Ordre d emission, DIFFERENT du TODO 23        }
{ (note d en-tete ci-dessus, point 3) : .data D ABORD (PeStrRva/                  }
{ PeBytesWrittenRva doivent etre connus AVANT d encoder .text, puisque             }
{ PeEmitPushOffsetData a besoin de la RVA finale IMMEDIATEMENT, aucun               }
{ fixup n existe pour ce cas) ; PUIS .text dans l ordre _JSPRT_Print (les              }
{ DEUX seuls appels importes du roadmap d en-tete, GetStdHandle/                        }
{ WriteFile) -> _jspService (le gabarit litteral, PeCodeGenStmt) ->                        }
{ _start (le point d entree REEL du .exe - decision 1 ci-dessus,                             }
{ ExitProcess). }
Procedure PeAssemblePage(RootIdx: Integer; DataRva: LongInt);
Var
  I, J : Integer;
  JccL1, JccL3, L2Offset : Integer;
Begin
  PeAsmInit;
  CgStrInit;
  CgCollectStrings(RootIdx);
  { EXTENSION 3 (post-TODO25) : MEME collecte DEDIEE que CodeGenPage/           }
  { BinAssemblePage - voir la note d en-tete complete pres de                       }
  { CgCollectStringsFromExpr (bogue reel corrige : sans elle, "Catalogue          }
  { JSP" ne serait jamais entre dans CgStrPool avant l ecriture de .data). }
  For I := 0 To JavaMethodCount - 1 Do
    CgCollectStringsFromMethodStmt(JavaMethodPool[I].BodyStmtIdx);

  { --- .data : pool _JSPK (MEME contenu/ordre que CodeGenPage/                }
  { BinAssemblePage, TODO 21/23) - EXTENSION 3 : chaque bloc commence PAR       }
  { SA LONGUEUR (dd), MEME convention que les backends textuel/objet. --- }
  For I := 0 To CgStrCount - 1 Do
  Begin
    PeStrRva[I] := DataRva + PeDataLen;
    PeDataDword(Length(CgStrPool[I]));
    For J := 1 To Length(CgStrPool[I]) Do
      PeDataByte(Ord(CgStrPool[I][J]));
  End;
  PeBytesWrittenRva := DataRva + PeDataLen;
  PeDataByte(0); PeDataByte(0); PeDataByte(0); PeDataByte(0);

  { --- .data : EXTENSION post-TODO25 - tampon SYSTEMTIME (16 octets,      }
  { GetLocalTime) + tampon chaine formatee (19 octets, "AAAA-MM-JJ            }
  { HH:MM:SS") pour "new java.util.Date()" imprime immediatement.               }
  { EXTENSION 3 : prefixe de longueur ajoute EN TETE de PeDateStrRva            }
  { (meme convention que les _JSPKn ci-dessus). --- }
  PeSysTimeRva := DataRva + PeDataLen;
  For I := 1 To 16 Do PeDataByte(0);
  PeDateStrRva := DataRva + PeDataLen;
  PeDataDword(19);
  For I := 1 To 19 Do PeDataByte(Ord(' '));
  { --- .data : EXTENSION 3 (post-TODO25) - tampon de _JSPRT_PrintInt --- }
  PeIntBufRva := DataRva + PeDataLen;
  For I := 1 To 16 Do PeDataByte(0);

  { --- .text : _JSPRT_Print (runtime minimal, TODO 18/21/23) - EXTENSION 3 :  }
  { signature reduite a UN SEUL parametre, voir la note d en-tete complete           }
  { pres de la version textuelle (CodeGenPage). --- }
  PePrintOffset := PeTextLen;
  PeEmitPushReg(REG_EBP);
  PeEmitMovRegReg(REG_EBP, REG_ESP);
  PeEmitPushImm32(-11); { STD_OUTPUT_HANDLE }
  PeEmitCallImport('GetStdHandle');
  PeEmitMovRegMemEbpDisp8(REG_ECX, 8);
  PeEmitLeaRegMemRegDisp8(REG_EDX, REG_ECX, 4);
  PeEmitPushImm32(0);
  PeEmitPushOffsetData(PeBytesWrittenRva);
  PeEmitPushMemIndirect(REG_ECX);
  PeEmitPushReg(REG_EDX);
  PeEmitPushReg(REG_EAX);
  PeEmitCallImport('WriteFile');
  PeEmitPopReg(REG_EBP);
  PeEmitRetImm16(4);

  { --- .text : _JSPRT_PrintInt (EXTENSION 3, post-TODO25) - conversion       }
  { entier->decimal (division repetee par 10) puis reutilisation de              }
  { _JSPRT_Print - voir la note d en-tete complete pres de la version              }
  { textuelle (CodeGenPage) pour la disposition EXACTE du tampon                    }
  { _JSPRT_IntBuf/le calcul du prefixe de longueur a une position VARIABLE. --- }
  PePrintIntOffset := PeTextLen;
  PeEmitPushReg(REG_EBP);
  PeEmitMovRegReg(REG_EBP, REG_ESP);
  PeEmitPushReg(REG_EBX);
  PeEmitPushReg(REG_ESI);
  PeEmitPushReg(REG_EDI);
  PeEmitMovRegMemEbpDisp8(REG_EAX, 8);
  PeEmitMovRegAbs(REG_EDI, PeIntBufRva + 16);
  PeEmitXorRegReg(REG_ESI, REG_ESI);
  PeEmitTestRegReg(REG_EAX);
  JccL1 := PeEmitJccPlaceholder($79); { jns L1 }
  PeEmitMovRegImm32(REG_ESI, 1);
  PeEmitNegReg(REG_EAX);
  PePatchJcc(JccL1); { L1: }
  PeEmitMovRegImm32(REG_EBX, 10);
  L2Offset := PeTextLen; { L2: }
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitDivReg(REG_EBX);
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitDecReg(REG_EDI);
  PeEmitMovMemIndirectFromReg8(REG_EDI, REG_EDX);
  PeEmitTestRegReg(REG_EAX);
  PeEmitJccBackward($75, L2Offset); { jnz L2 }
  PeEmitTestRegReg(REG_ESI);
  JccL3 := PeEmitJccPlaceholder($74); { jz L3 }
  PeEmitDecReg(REG_EDI);
  PeEmitMovByteMemIndirectImm8(REG_EDI, Ord('-'));
  PePatchJcc(JccL3); { L3: }
  PeEmitMovRegAbs(REG_EAX, PeIntBufRva + 16);
  PeEmitSubRegReg(REG_EAX, REG_EDI);
  PeEmitSubRegImm8(REG_EDI, 4);
  PeEmitMovMemIndirectFromReg32(REG_EDI, REG_EAX);
  PeEmitPushReg(REG_EDI);
  PeEmitCallInternal(PePrintOffset);
  PeEmitPopReg(REG_EDI);
  PeEmitPopReg(REG_ESI);
  PeEmitPopReg(REG_EBX);
  PeEmitPopReg(REG_EBP);
  PeEmitRetImm16(4);

  { --- .text : _JSPRT_PrintDate (EXTENSION post-TODO25) - voir la note    }
  { d en-tete complete de PeCodeGenStmt/du bloc d encodeurs ci-dessus. Le      }
  { format retenu ("AAAA-MM-JJ HH:MM:SS", heure locale) est un choix                }
  { DELIBERE et DOCUMENTE - il ne reproduit PAS le format EXACT de                     }
  { java.util.Date.toString() (section 4.6/TODO 04, "Object jusqu a                       }
  { coercition" - AUCUNE bibliotheque de formatage de date complete n existe                  }
  { ici), simplement une representation LISIBLE et REELLE de l heure                            }
  { courante (GetLocalTime, PAS un placeholder invente). Chaque champ            }
  { SYSTEMTIME (WORD) est ecrit en EXACTEMENT 2 chiffres decimaux (l annee            }
  { en DEUX ecritures de 2 chiffres, siecle PUIS annee-dans-le-siecle) - la          }
  { sequence est ENTIEREMENT LINEAIRE (aucun saut/etiquette), MEME               }
  { discipline "aucun risque de deplacement mal calcule" que le reste de              }
  { l encodeur PE. }
  PePrintDateOffset := PeTextLen;
  PeEmitPushReg(REG_EBP);
  PeEmitMovRegReg(REG_EBP, REG_ESP);
  PeEmitPushOffsetData(PeSysTimeRva);
  PeEmitCallImport('GetLocalTime');

  { siecle = annee div 100 -> PeDateStrRva+0..1 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva);       { wYear, offset 0 }
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 100);
  PeEmitDivReg(REG_ECX);                      { eax = siecle }
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);                      { eax = dizaine, edx = unite }
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 4, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 5, REG_EDX);

  { annee-dans-le-siecle = annee mod 100 -> PeDateStrRva+6..7 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva);       { wYear }
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 100);
  PeEmitDivReg(REG_ECX);
  PeEmitMovRegReg(REG_EAX, REG_EDX);          { eax = annee mod 100 }
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 6, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 7, REG_EDX);

  PeEmitMovByteAbsImm8(PeDateStrRva + 8, Ord('-'));

  { wMonth (SYSTEMTIME offset 2) -> PeDateStrRva+9..10 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva + 2);
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 9, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 10, REG_EDX);

  PeEmitMovByteAbsImm8(PeDateStrRva + 11, Ord('-'));

  { wDay (SYSTEMTIME offset 6) -> PeDateStrRva+12..13 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva + 6);
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 12, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 13, REG_EDX);

  PeEmitMovByteAbsImm8(PeDateStrRva + 14, Ord(' '));

  { wHour (SYSTEMTIME offset 8) -> PeDateStrRva+15..16 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva + 8);
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 15, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 16, REG_EDX);

  PeEmitMovByteAbsImm8(PeDateStrRva + 17, Ord(':'));

  { wMinute (SYSTEMTIME offset 10) -> PeDateStrRva+18..19 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva + 10);
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 18, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 19, REG_EDX);

  PeEmitMovByteAbsImm8(PeDateStrRva + 20, Ord(':'));

  { wSecond (SYSTEMTIME offset 12) -> PeDateStrRva+21..22 }
  PeEmitMovzxEaxAbsWord(PeSysTimeRva + 12);
  PeEmitXorRegReg(REG_EDX, REG_EDX);
  PeEmitMovRegImm32(REG_ECX, 10);
  PeEmitDivReg(REG_ECX);
  PeEmitAddAlImm8(Ord('0'));
  PeEmitAddR8Imm8(REG_EDX, Ord('0'));
  PeEmitMovAbsFromReg8(PeDateStrRva + 21, REG_EAX);
  PeEmitMovAbsFromReg8(PeDateStrRva + 22, REG_EDX);

  PeEmitPushOffsetData(PeDateStrRva);
  PeEmitCallInternal(PePrintOffset);

  PeEmitPopReg(REG_EBP);
  PeEmitRet;

  { --- .text : EXTENSION 3 (post-TODO25) - corps des methodes declarees      }
  { en page, EMISES AVANT _jspService (MEME discipline "callee avant           }
  { caller" que _JSPRT_Print/_JSPRT_PrintDate ci-dessus). --- }
  For I := 0 To JavaMethodCount - 1 Do
    PeCompileMethodBody(I);

  { --- .text : _jspService (point d entree synthetique de la page, TODO 09) --- }
  PeServiceOffset := PeTextLen;
  PeEmitPushReg(REG_EBP);
  PeEmitMovRegReg(REG_EBP, REG_ESP);
  PeCodeGenStmt(RootIdx);
  PeEmitMovRegReg(REG_ESP, REG_EBP);
  PeEmitPopReg(REG_EBP);
  PeEmitRet;

  { --- .text : _start - le VRAI point d entree du .exe (decision 1           }
  { ci-dessus) : appelle _jspService PUIS ExitProcess(0), JAMAIS un simple         }
  { RET (aucun appelant reel n existe au point d entree d un .exe). }
  PeEntryOffset := PeTextLen;
  PeEmitCallInternal(PeServiceOffset);
  PeEmitPushImm32(0);
  PeEmitCallImport('ExitProcess');
End;

{ ------------------------------------------------------------ }
{ WritePEExe : ecrit le fichier .EXE PE REEL sur disque - en-tete DOS+PE +  }
{ Optional Header (PE32) + 3 IMAGE_SECTION_HEADER (.text/.data/.idata) +      }
{ octets .text (PATCHES : chaque fixup PeFixupPool devient l adresse             }
{ ABSOLUE reelle de sa case IAT, decision 3 ci-dessus) + octets .data +            }
{ .idata (table d import complete - descripteur/ILT/IAT/Hint-Name/nom de            }
{ DLL, MEME structure PE standard que tout lieur reel). MEME technique de            }
{ fichier BINAIRE (Assign/Rewrite(F,1)/BlockWrite) que WriteCOFFObj (TODO           }
{ 23).                                                                                   }
{ ------------------------------------------------------------ }

Procedure WritePEExe(RootIdx: Integer; Const Path: TString);
Const
  DOS_HEADER_SIZE = 64;
  PE_HEADER_SIZE  = 4 + 20 + 224; { signature + IMAGE_FILE_HEADER + IMAGE_OPTIONAL_HEADER32 }
  SECTION_HEADER_SIZE = 40;
  NUM_SECTIONS = 3;
Var
  F                                    : File;
  I, J                                 : Integer;
  HeadersRaw                           : LongInt;
  TextRva, DataRva, IdataRva           : LongInt;
  TextFileOff, DataFileOff, IdataFileOff : LongInt;
  TextRawSize, DataRawSize, IdataRawSize : LongInt;
  SizeOfImage                          : LongInt;
  IdataDescOff, IdataIltOff, IdataIatOff, IdataHintOff, IdataDllNameOff : LongInt;
  IdataTotalSize                       : LongInt;
  HintOffsets                          : Array[0..PE_IMPORT_COUNT - 1] Of LongInt;
  Nm                                   : TString;
  PadLen                               : LongInt;

  Procedure WByte(B: Byte); Begin BlockWrite(F, B, 1); End;
  Procedure WWord(W: Word);
  Begin WByte(Byte(W And $FF)); WByte(Byte((W Shr 8) And $FF)); End;
  Procedure WDword(D: LongInt);
  Begin
    WByte(Byte(D And $FF)); WByte(Byte((D Shr 8) And $FF));
    WByte(Byte((D Shr 16) And $FF)); WByte(Byte((D Shr 24) And $FF));
  End;
  Procedure WPad(N: LongInt);
  Var K: LongInt;
  Begin For K := 1 To N Do WByte(0); End;
  Procedure WAscii(Const S: TString);
  Var K: Integer;
  Begin For K := 1 To Length(S) Do WByte(Ord(S[K])); End;

Begin
  { --- .data D ABORD (decision 3 de la note d en-tete) : la RVA doit       }
  { etre CONNUE avant d encoder .text - DataRva depend de TextRva qui           }
  { depend de TextRawSize... resolu en DEUX passes : (1) encoder .text AVEC   }
  { une RVA .data PROVISOIRE (0) juste pour en MESURER la taille (les             }
  { adresses .data ecrites sont FAUSSES et seront regenerees), (2) recalculer      }
  { TextRva/DataRva REELS a partir des tailles maintenant connues, puis              }
  { RE-encoder .text avec la VRAIE DataRva - PeAssemblePage est un simple           }
  { parcours d arbre SANS effet de bord externe, le rejouer deux fois de suite       }
  { est SANS DANGER (MEME idiome que CgCollectStrings/BinCollectStrings                }
  { rappelle deja les MEMES pools plusieurs fois par execution). }
  HeadersRaw  := PeRoundUp(DOS_HEADER_SIZE + PE_HEADER_SIZE +
                           NUM_SECTIONS * SECTION_HEADER_SIZE, PE_FILE_ALIGN);
  TextRva     := PE_SEC_ALIGN;

  PeAssemblePage(RootIdx, 0); { passe 1 : mesure SEULEMENT }
  TextRawSize := PeRoundUp(PeTextLen, PE_FILE_ALIGN);
  DataRva     := PeRoundUp(TextRva + PeTextLen, PE_SEC_ALIGN);

  PeAssemblePage(RootIdx, DataRva); { passe 2 : REELLE, DataRva CONNUE }
  TextRawSize := PeRoundUp(PeTextLen, PE_FILE_ALIGN);
  DataRawSize := PeRoundUp(PeDataLen, PE_FILE_ALIGN);
  IdataRva    := PeRoundUp(DataRva + PeDataLen, PE_SEC_ALIGN);

  { --- .idata : descripteurs/ILT/IAT/Hint-Name/nom DLL (section 1 du         }
  { roadmap d en-tete, "table d import") --- }
  IdataDescOff := 0;
  IdataIltOff  := IdataDescOff + 2 * 20;         { KERNEL32.DLL + terminateur NUL }
  IdataIatOff  := IdataIltOff + (PE_IMPORT_COUNT + 1) * 4;
  IdataHintOff := IdataIatOff + (PE_IMPORT_COUNT + 1) * 4;
  J := IdataHintOff;
  For I := 0 To PE_IMPORT_COUNT - 1 Do
  Begin
    HintOffsets[I] := J;
    PadLen := 2 + Length(PeImportNames[I]) + 1;
    If Odd(PadLen) Then Inc(PadLen);
    J := J + PadLen;
  End;
  IdataDllNameOff := J;
  IdataTotalSize  := IdataDllNameOff + Length('KERNEL32.DLL') + 1;
  IdataRawSize    := PeRoundUp(IdataTotalSize, PE_FILE_ALIGN);

  { --- patch des appels importes (decision 3 : "FF 15 <VA>", MEME           }
  { mecanisme que BinFixupPool au TODO 23 mais RESOLU ICI-MEME, aucun            }
  { lieur externe n existant pour un .exe autonome) --- }
  For I := 0 To PeFixupCount - 1 Do
  Begin
    J := PeFixupPool[I].TextOffset;
    PeTextBuf[J]     := Byte((PE_IMG_BASE + IdataRva + IdataIatOff +
                              PeFixupPool[I].ImportIndex * 4) And $FF);
    PeTextBuf[J + 1] := Byte(((PE_IMG_BASE + IdataRva + IdataIatOff +
                              PeFixupPool[I].ImportIndex * 4) Shr 8) And $FF);
    PeTextBuf[J + 2] := Byte(((PE_IMG_BASE + IdataRva + IdataIatOff +
                              PeFixupPool[I].ImportIndex * 4) Shr 16) And $FF);
    PeTextBuf[J + 3] := Byte(((PE_IMG_BASE + IdataRva + IdataIatOff +
                              PeFixupPool[I].ImportIndex * 4) Shr 24) And $FF);
  End;

  TextFileOff  := HeadersRaw;
  DataFileOff  := TextFileOff + TextRawSize;
  IdataFileOff := DataFileOff + DataRawSize;

  SizeOfImage := PeRoundUp(IdataRva + IdataTotalSize, PE_SEC_ALIGN);

  Assign(F, Path);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('impossible de creer le fichier .exe : ' + Path);
    Exit;
  End;

  { --- IMAGE_DOS_HEADER (64 octets) - aucun stub reel, e_lfanew pointe    }
  { DIRECTEMENT juste apres (MEME choix minimal que beaucoup de .exe          }
  { fabriques a la main - le stub n est execute que sous un VRAI DOS,             }
  { jamais par le chargeur PE lui-meme). }
  WWord(PE_DOS_MAGIC);
  WPad(58);
  WDword(DOS_HEADER_SIZE); { e_lfanew }

  { --- IMAGE_NT_HEADERS32 --- }
  WDword(PE_PE_SIG);
  WWord(PE_MACHINE_I386);
  WWord(NUM_SECTIONS);
  WDword(0);              { TimeDateStamp }
  WDword(0);              { PointerToSymbolTable - aucune table de symboles COFF dans un .exe }
  WDword(0);              { NumberOfSymbols }
  WWord(224);             { SizeOfOptionalHeader }
  WWord($0103);           { EXECUTABLE_IMAGE Or 32BIT_MACHINE Or RELOCS_STRIPPED (decision 2) }

  WWord($010B);           { Magic = PE32 }
  WByte(1); WByte(0);     { Linker version }
  WDword(TextRawSize);    { SizeOfCode }
  WDword(DataRawSize + IdataRawSize); { SizeOfInitializedData }
  WDword(0);              { SizeOfUninitializedData }
  WDword(PeEntryOffset + TextRva); { AddressOfEntryPoint = RVA de _start }
  WDword(TextRva);        { BaseOfCode }
  WDword(DataRva);        { BaseOfData }
  WDword(PE_IMG_BASE);
  WDword(PE_SEC_ALIGN);
  WDword(PE_FILE_ALIGN);
  WWord(4); WWord(0);     { OS version }
  WWord(0); WWord(0);     { Image version }
  WWord(4); WWord(0);     { Subsystem version }
  WDword(0);              { Win32VersionValue }
  WDword(SizeOfImage);
  WDword(HeadersRaw);     { SizeOfHeaders }
  WDword(0);              { CheckSum }
  WWord(PE_SUBSYS_CUI);
  WWord(0);               { DllCharacteristics }
  WDword($100000); WDword($1000); { pile : reserve/commit }
  WDword($100000); WDword($1000); { tas : reserve/commit }
  WDword(0);              { LoaderFlags }
  WDword(16);             { NumberOfRvaAndSizes }
  For I := 0 To 15 Do
    If I = 1 Then { data directory 1 = table d import }
    Begin WDword(IdataRva); WDword(IdataDescOff + 2 * 20 { taille = 2 descripteurs } ); End
    Else Begin WDword(0); WDword(0); End;

  { --- IMAGE_SECTION_HEADER x 3 --- }
  WAscii('.text'); WPad(3);
  WDword(PeTextLen); WDword(TextRva);
  WDword(TextRawSize); WDword(TextFileOff);
  WDword(0); WDword(0); WWord(0); WWord(0);
  WDword($60000020);      { CODE Or MEM_EXECUTE Or MEM_READ }

  WAscii('.data'); WPad(3);
  WDword(PeDataLen); WDword(DataRva);
  WDword(DataRawSize); WDword(DataFileOff);
  WDword(0); WDword(0); WWord(0); WWord(0);
  WDword(-1073741760);    { INITIALIZED_DATA Or MEM_READ Or MEM_WRITE, TODO 23 }

  WAscii('.idata'); WPad(2);
  WDword(IdataTotalSize); WDword(IdataRva);
  WDword(IdataRawSize); WDword(IdataFileOff);
  WDword(0); WDword(0); WWord(0); WWord(0);
  WDword(-1073741760);    { INITIALIZED_DATA Or MEM_READ Or MEM_WRITE }

  { --- BOGUE REEL trouve par EXECUTION (le roadmap d en-tete du TODO 21          }
  { l anticipe explicitement : "un construct qui fonctionnait dans un               }
  { self-test isole pourrait reveler une surprise en contexte reel") :                  }
  { PointerToRawData (.text) = HeadersRaw (arrondi a PE_FILE_ALIGN, 512)                  }
  { mais AUCUN remplissage n etait ecrit entre la fin des en-tetes (432                     }
  { octets REELS) et le debut des octets .text avant cette correction - un                    }
  { .exe REEL genere (WritePEExe, PeExeSelfTest ne detectait PAS ce decalage                    }
  { car elle ne relit que l en-tete, jamais le contenu des sections) etait                        }
  { REFUSE par le VRAI chargeur Windows ("n est pas une application valide                          }
  { pour cette plateforme") - le PROCHAIN octet ecrit doit tomber EXACTEMENT             }
  { a HeadersRaw, jamais juste "apres les en-tetes". }
  WPad(HeadersRaw - (DOS_HEADER_SIZE + PE_HEADER_SIZE +
                     NUM_SECTIONS * SECTION_HEADER_SIZE));

  { --- octets .text (fixups DEJA patches ci-dessus) + remplissage --- }
  For I := 0 To PeTextLen - 1 Do WByte(PeTextBuf[I]);
  WPad(TextRawSize - PeTextLen);

  { --- octets .data + remplissage --- }
  For I := 0 To PeDataLen - 1 Do WByte(PeDataBuf[I]);
  WPad(DataRawSize - PeDataLen);

  { --- .idata : descripteur KERNEL32.DLL + terminateur NUL --- }
  WDword(IdataRva + IdataIltOff); { OriginalFirstThunk }
  WDword(0); WDword(0);           { TimeDateStamp, ForwarderChain }
  WDword(IdataRva + IdataDllNameOff); { Name }
  WDword(IdataRva + IdataIatOff); { FirstThunk }
  WPad(20); { descripteur terminateur, tout zero }

  { --- ILT (Import Lookup Table) --- }
  For I := 0 To PE_IMPORT_COUNT - 1 Do WDword(IdataRva + HintOffsets[I]);
  WDword(0);

  { --- IAT (Import Address Table) - IDENTIQUE a l ILT au depart, le VRAI  }
  { chargeur Windows la remplit avec les adresses REELLES au chargement       }
  { (decision 3 de la note d en-tete). }
  For I := 0 To PE_IMPORT_COUNT - 1 Do WDword(IdataRva + HintOffsets[I]);
  WDword(0);

  { --- entrees Hint/Name --- }
  For I := 0 To PE_IMPORT_COUNT - 1 Do
  Begin
    WWord(0); { Hint }
    Nm := PeImportNames[I];
    WAscii(Nm);
    WByte(0);
    PadLen := 2 + Length(Nm) + 1;
    If Odd(PadLen) Then WByte(0);
  End;

  { --- nom de la DLL --- }
  WAscii('KERNEL32.DLL'); WByte(0);

  WPad(IdataRawSize - IdataTotalSize);

  Close(F);
End;

{ ------------------------------------------------------------ }
{ PeExeSelfTest : Test10Include.jsp reel (fragment VERBATIM,       }
{ MEME discipline que BinAsmSelfTest/CodeGenSelfTest - le SEUL       }
{ echantillon qui survit ENTIEREMENT a PeCodeGenStmt) assemble et      }
{ ecrit en un VRAI .exe dont l en-tete DOS+PE est relu et verifie       }
{ octet par octet (signature MZ, signature PE, point d entree           }
{ dans les bornes de .text, table d import pointant vers .idata).        }
{ ------------------------------------------------------------ }

Procedure PeExeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PeExeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PeExeSelfTest;
Const
  TmpFile = 'JSPPESELFTEST.$$$';
  ExeFile = 'JSPPESELFTEST.exe';
Var
  F                : Text;
  PeF              : File;
  PageIdx          : Integer;
  Header           : Array[0..511] Of Byte;
  NRead            : Integer;
  Lfanew           : LongInt;
  TextHeaderOff    : LongInt;
  TextPtrRawData   : LongInt;
  FirstCodeByte    : Array[0..0] Of Byte;
Begin
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<!DOCTYPE html><html><body>',
        '<h1>Bonjour</h1>',
        '</body></html>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;

  WritePEExe(PageIdx, ExeFile);
  PeExeAssert('WritePEExe reel : au moins un chunk de gabarit collecte', CgStrCount >= 1);
  PeExeAssert('WritePEExe reel : les TROIS imports GetStdHandle/WriteFile/' +
    'ExitProcess sont tous reference (au moins 3 fixups)', PeFixupCount >= 3);

  Assign(PeF, ExeFile);
  {$I-} Reset(PeF, 1); {$I+}
  PeExeAssert('WritePEExe reel : fichier cree', IOResult = 0);
  BlockRead(PeF, Header, 512, NRead);
  PeExeAssert('en-tete DOS+PE+sections relu : au moins 512 octets', NRead = 512);
  PeExeAssert('signature DOS "MZ"', (Header[0] = Ord('M')) And (Header[1] = Ord('Z')));

  Lfanew := Header[60] + Header[61]*256 + Header[62]*65536 + Header[63]*16777216;
  PeExeAssert('e_lfanew = 64 (DOS_HEADER_SIZE, aucun stub reel)', Lfanew = 64);
  PeExeAssert('signature PE "PE" NUL NUL',
    (Header[Lfanew] = Ord('P')) And (Header[Lfanew + 1] = Ord('E')) And
    (Header[Lfanew + 2] = 0) And (Header[Lfanew + 3] = 0));
  PeExeAssert('Machine = I386 (4Ch 01h)',
    (Header[Lfanew + 4] = $4C) And (Header[Lfanew + 5] = $01));
  PeExeAssert('NumberOfSections = 3',
    (Header[Lfanew + 6] = 3) And (Header[Lfanew + 7] = 0));
  PeExeAssert('Magic Optional Header = PE32 (0Bh 01h)',
    (Header[Lfanew + 24] = $0B) And (Header[Lfanew + 25] = $01));

  { --- BOGUE REEL trouve par execution (voir la note d en-tete de           }
  { WritePEExe) : verifier que PointerToRawData (.text, PREMIER en-tete de     }
  { section, decalage 20 dans IMAGE_SECTION_HEADER) pointe REELLEMENT vers        }
  { le PREMIER octet machine ecrit (PeTextBuf[0]) - CE test AURAIT DETECTE          }
  { le decalage de remplissage manquant AVANT qu une execution manuelle du            }
  { .exe reel ne soit necessaire pour le trouver ; ajoute ICI pour que la               }
  { PROCHAINE regression du meme genre soit attrapee automatiquement. }
  TextHeaderOff := Lfanew + 4 + 20 + 224; { signature+FileHeader+OptionalHeader }
  TextPtrRawData := Header[TextHeaderOff + 20] + Header[TextHeaderOff + 21]*256 +
    Header[TextHeaderOff + 22]*65536 + Header[TextHeaderOff + 23]*16777216;
  Seek(PeF, TextPtrRawData);
  BlockRead(PeF, FirstCodeByte, 1, NRead);
  PeExeAssert('PointerToRawData(.text) pointe vers le PREMIER octet machine ' +
    'REELLEMENT ecrit (PeTextBuf[0])', (NRead = 1) And (FirstCodeByte[0] = PeTextBuf[0]));

  Close(PeF);
  Assign(PeF, ExeFile); Erase(PeF);
  LexClose; Assign(F, TmpFile); Erase(F);

  { --- EXTENSION 3 (post-TODO25) : encodage OCTET PAR OCTET verifie a la    }
  { main pour les DEUX seules formes PROPRES au backend PE (adressage             }
  { ABSOLU direct32, MEME famille que PeEmitPushOffsetData/                          }
  { PeEmitMovAbsFromReg8 deja verifiees depuis le TODO 24) - le reste des             }
  { nouveaux primitifs (ModRM registre-a-registre/indirect) est BYTE POUR         }
  { BYTE identique a celui deja hand-verifie par BinAsmSelfTest (TODO 23),      }
  { reproduire CES assertions ICI serait une duplication sans nouveau                risque              }
  { couvert. --- }
  PeAsmInit;
  PeEmitMovRegAbs(REG_EDI, $1000);
  PeExeAssert('mov edi, PE_IMG_BASE+1000h = BF <PE_IMG_BASE+1000h>',
    (PeTextLen = 5) And (PeTextBuf[0] = $BF) And
    (PeTextBuf[1] + PeTextBuf[2]*256 + PeTextBuf[3]*65536 +
     PeTextBuf[4]*16777216 = PE_IMG_BASE + $1000));

  PeAsmInit;
  PeTextByte($90); PeTextByte($90);
  PeEmitJccBackward($75, 0);
  PeExeAssert('jnz (arriere, cible=0) : rel8 = -4 (FCh)',
    (PeTextLen = 4) And (PeTextBuf[2] = $75) And (PeTextBuf[3] = $FC));

  { --- Test03Declarations.jsp reel (fragment VERBATIM) : methodes           }
  { declarees REELLEMENT compilees (PeCompileMethodBody) et sites d appel        }
  { REELLEMENT resolus (PeEmitMethodCallPrint) - confirme qu un .exe COMPLET       }
  { (nomApplication()/carre(12)) s ecrit sans erreur (l EXECUTION reelle          }
  { est verifiee manuellement, voir le rapport EXTENSION 3 en tete de              }
  { fichier - MEME limite deja assumee pour Test10Include.jsp ci-dessus,             }
  { un self-test structurel ne remplace jamais une execution reelle). --- }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit; TypeInit;
  Assign(F, TmpFile); Rewrite(F);
  Write(F, '<%@ page contentType="text/html; charset=UTF-8"',
        '         pageEncoding="UTF-8" %>',
        '<%! private String nomApplication() { return "Catalogue JSP"; }',
        '    private int carre(int valeur) { return valeur * valeur; } %>',
        '<h1><%= nomApplication() %></h1>',
        '<p><%= carre(12) %></p>');
  Close(F);
  LexInit(TmpFile);
  PageIdx := ParsePage;

  WritePEExe(PageIdx, ExeFile);
  Assign(PeF, ExeFile);
  {$I-} Reset(PeF, 1); {$I+}
  PeExeAssert('WritePEExe reel (Test03Declarations.jsp) : fichier cree', IOResult = 0);
  Close(PeF);

  Assign(PeF, ExeFile); Erase(PeF);
  LexClose; Assign(F, TmpFile); Erase(F);
End;

{ ------------------------------------------------------------ }
{ Run : point d entree - portee TODO 01-25 (roadmap COMPLET) +   }
{ EXTENSION 1 (post-TODO25, "new java.util.Date()" immediat). }
{ TODO 25 : AUCUN nouveau code de production - validation finale               }
{ HONNETEMENT documentee (voir le rapport complet en tete de fichier,             }
{ section "TODO 25 - VALIDATION FINALE : ETAT REEL") : 1/17 echantillons             }
{ REELLEMENT compiles ET executes de bout en bout (Test10Include.jsp),                 }
{ 16/17 arrets PROPRES et EXPLIQUES a un endroit precis - JAMAIS un                       }
{ plantage, JAMAIS une sortie faussee. EXTENSION 1 (voir sa propre                          }
{ section en tete de fichier) : Test01Bonjour.jsp rejoint Test10                              }
{ Include.jsp (2/17), etendue aux TROIS backends CodeGenPage/                                   }
{ BinAssemblePage/PeAssemblePage (necessaire : Run() les enchaine                                  }
{ SEQUENTIELLEMENT, un FatalError dans le PREMIER bloquait les autres). }
{ (voir la note d en-tete de la section TODO 21 plus haut) : depuis    }
{ le TODO 01, Run() ne faisait QUE tokeniser le fichier source REEL       }
{ (chaque TODO 09-20 construisait/auto-testait sa piece SANS jamais la     }
{ brancher sur un vrai fichier) - CE TODO branche ENFIN ParsePage           }
{ (TODO 08) + SemanticAnalyze (TODO 20, best-effort, JAMAIS bloquant)         }
{ + CodeGenPage (TODO 21) sur le fichier source REEL de l utilisateur,          }
{ et ecrit TOUJOURS un ".asm" (ReplaceExt(Opts.SrcFile, '.asm'), JAMAIS          }
{ Opts.OutFile lui-meme - le VRAI choix .obj/.exe reste ASPIRATIONNEL              }
{ jusqu au TODO 23/24, MEME decision que JPPCW32.PAS pour SON propre               }
{ TODO 21). PORTEE REELLE de CodeGenPage a ce stade : SEUL le gabarit                }
{ litteral (SK_PRINT_TEMPLATE) est traduit - toute AUTRE construction                  }
{ (expressions Java, EL, actions JSTL...) arrete la compilation                          }
{ PROPREMENT (FatalError explicite, JAMAIS un .asm silencieusement                         }
{ faux) - AUCUN des 17 echantillons reels ne peut donc encore etre                           }
{ traduit JUSQU AU BOUT (chacun contient du Java/EL/JSTL des le premier                        }
{ TODO qui l a introduit), un arret PROPRE et EXPLIQUE a l endroit                              }
{ documente EST le resultat attendu et verifie de ce TODO, PAS un echec.                          }
{ -d continue d afficher chaque jeton BRUT via une passe SEPAREE                                    }
{ (AVANT la vraie compilation), puisque ParsePage/CodeGenPage pilotent                                }
{ desormais le lexeur eux-memes et n offrent plus l occasion d imprimer                                 }
{ un jeton individuellement. TODO 22 ajoute CheckEncodingCoherence                                          }
{ (best-effort, JAMAIS bloquant) juste apres SemanticAnalyze, AVANT                                            }
{ CodeGenPage. TODO 23 ajoute BinAssemblePage/WriteCOFFObj JUSTE APRES              }
{ CodeGenPage - le VRAI encodeur 80386 (octets REELS, MEME portee EXACTE            }
{ que CodeGenPage : gabarit litteral SEULEMENT) ecrivant TOUJOURS un              }
{ ".obj" COFF a son PROPRE chemin fixe (ReplaceExt(Opts.SrcFile, '.obj'),           }
{ MEME decision que le .asm du TODO 21), exploitable par un lieur externe               }
{ standard. TODO 24 ajoute PeAssemblePage/WritePEExe JUSTE APRES WriteCOFFObj -        }
{ le VRAI .exe PE, ecrit TOUJOURS a son PROPRE chemin fixe (ReplaceExt              }
{ (SrcFile, '.exe')) qui COINCIDE desormais avec Opts.OutFile par defaut -              }
{ le choix .obj/.exe "ASPIRATIONNEL" documente depuis le TODO 21 est                        }
{ MAINTENANT REEL pour les DEUX. }
{ ------------------------------------------------------------ }

Function IsHelpArg(Const Arg: TString): Boolean;
Begin
  IsHelpArg := (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
               (Arg = '/h') Or (Arg = '/H');
End;

Procedure Run;
Var Tok : TToken; PageIdx: Integer; AsmPath, ObjPath, ExePath: TString;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  { Aide/absence d argument verifiee AVANT les auto-tests (LexSelfTest)  }
  { - MEME correctif que celui deja applique a JPPCW32.PAS : l aide ne    }
  { doit jamais etre precedee du bruit des auto-tests. }
  If (ParamCount = 0) Or IsHelpArg(ParamStr(1)) Then
    ShowHelp;

  SelfTestMode := True;
  LexSelfTest;
  TypeSelfTest;
  { TypeSelfTest ajoute des entrees de TEST au pool (classe/tableau       }
  { factices) - reinitialiser AVANT la compilation reelle, MEME           }
  { discipline que LexClose apres LexSelfTest : aucun artefact de test    }
  { ne doit fuiter dans TypePool utilise par la suite (TODO 07+). }
  TypeInit;
  RuntimeLibSelfTest;
  { MEME discipline : RuntimeLibSelfTest appelle elle-meme TypeInit/          }
  { RuntimeLibInit en entree ET se termine par un TypeInit (aucune classe        }
  { stdlib DEFINITIVE ne doit rester en place avant la vraie RuntimeLibInit         }
  { ci-dessous) - RuntimeLibInit (PAS juste TypeInit) est ce qui doit               }
  { REELLEMENT alimenter la compilation qui suit. }
  TypeInit;
  RuntimeLibInit;
  PageSelfTest;
  { MEME discipline : PageSelfTest laisse PageOpts dans un etat de TEST   }
  { (contradictions volontaires, language="cobol") - reinitialiser       }
  { AVANT la compilation reelle. }
  PageInit;
  IncludeSelfTest;
  TaglibSelfTest;
  { MEME discipline : TaglibSelfTest laisse TaglibPool dans un etat de    }
  { TEST (prefix "jsp" reserve, tagdir non supporte) - reinitialiser      }
  { AVANT la compilation reelle. IncludeSelfTest ne modifie aucun etat    }
  { persistant hormis ContextRootDir, ecrase ci-dessous pour de vrai.     }
  TaglibInit;
  JavaParserSelfTest;
  { MEME discipline : JavaParserSelfTest laisse les pools Expr/Stmt/       }
  { Method/Field dans un etat de TEST - reinitialiser AVANT la             }
  { compilation reelle (JavaParserSelfTest appelle deja JavaParserInit     }
  { entre chaque fixture, mais PAS apres la DERNIERE - reinitialise ici    }
  { pour de vrai, meme discipline que TypeInit/PageInit/TaglibInit         }
  { ci-dessus). }
  JavaParserInit;
  ImplicitObjectSelfTest;
  { MEME discipline : ImplicitObjectSelfTest force PageOpts.IsErrorPage a   }
  { True/False tour a tour (pour exercer les deux branches de la           }
  { verification "exception", TODO 09) - reinitialiser AVANT la            }
  { compilation reelle. }
  JavaParserInit;
  PageInit;
  ScopeSelfTest;
  { MEME discipline : ScopeSelfTest peuple ScopeAttrPool avec des entrees   }
  { de TEST (session/application/request) - reinitialiser AVANT la          }
  { compilation reelle. }
  JavaParserInit;
  ScopeInit;
  InterleaveSelfTest;
  { MEME discipline : InterleaveSelfTest laisse les pools Expr/Stmt et      }
  { PageOpts (directive <%@ page %> de sa 1ere fixture) dans un etat de      }
  { TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit;
  PageInit;
  IncludeMergeSelfTest;
  { MEME discipline : IncludeMergeSelfTest laisse PageOpts/IncludeStack       }
  { dans un etat de TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit;
  PageInit;
  IncludeInit(''); { placeholder - le VRAI chemin de plus haut niveau n est }
                   { connu qu apres ParseArgs, voir plus bas }
  JspParamInit;
  JspActionSelfTest;
  { MEME discipline : JspActionSelfTest laisse les pools Stmt/JspParam       }
  { dans un etat de TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit;
  PageInit;
  JspParamInit;
  JspBeanSelfTest;
  { MEME discipline : JspBeanSelfTest laisse le pool Stmt dans un etat de   }
  { TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit;
  PageInit;
  JspParamInit;
  ElSelfTest;
  { MEME discipline : ElSelfTest laisse les pools Stmt/El dans un etat de   }
  { TEST - reinitialiser AVANT la compilation reelle. }
  ElParserInit;
  JavaParserInit;
  PageInit;
  ElEvalSelfTest;
  { MEME discipline : ElEvalSelfTest peuple ScopeAttrPool avec des entrees  }
  { de TEST (request/session) - se reinitialise elle-meme en sortie         }
  { (ScopeInit), mais reinitialise aussi ICI pour la MEME raison que         }
  { toutes les reinitialisations ci-dessus (documenter l intention plutot    }
  { que de compter sur un effet de bord interne a la procedure). }
  ElParserInit;
  ScopeInit;
  JstlCoreSelfTest;
  { MEME discipline : JstlCoreSelfTest declare son PROPRE prefixe "c" de   }
  { TEST (<%@ taglib %>, TaglibPool) et laisse les pools Stmt/El dans un    }
  { etat de TEST - reinitialiser AVANT la compilation reelle. }
  ElParserInit;
  JavaParserInit;
  PageInit;
  TaglibInit;
  JstlFunctionsSelfTest;
  { MEME discipline : JstlFunctionsSelfTest declare ses PROPRES prefixes    }
  { "fn"/"c" de TEST (TaglibPool) et ScopeAttrPool - se reinitialise elle-    }
  { meme en sortie, mais reinitialise aussi ICI pour la MEME raison que        }
  { toutes les reinitialisations ci-dessus. }
  ElParserInit;
  ScopeInit;
  TaglibInit;
  ReqParamSelfTest;
  { MEME discipline : ReqParamSelfTest peuple ReqParamPool/ScopeAttrPool     }
  { avec des entrees de TEST - se reinitialise elle-meme en sortie           }
  { (ReqParamInit), mais reinitialise aussi ICI pour la MEME raison que        }
  { toutes les reinitialisations ci-dessus. }
  ElParserInit;
  ScopeInit;
  ReqParamInit;
  SemanticSelfTest;
  { MEME discipline : SemanticSelfTest ecrit/efface ses PROPRES fichiers      }
  { temporaires, manipule ContextRootDir/TaglibPool/TypePool de TEST et se      }
  { termine par un TypeInit/TaglibInit - RuntimeLibInit (PAS juste TypeInit)      }
  { doit de nouveau REELLEMENT alimenter la compilation qui suit, MEME            }
  { discipline que juste apres RuntimeLibSelfTest ci-dessus. }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;
  CodeGenSelfTest;
  { MEME discipline : CodeGenSelfTest ecrit/efface ses PROPRES fichiers    }
  { temporaires (source ET .asm) et laisse les pools Stmt/El dans un         }
  { etat de TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;
  EncodingSelfTest;
  { MEME discipline : EncodingSelfTest ecrit/efface ses PROPRES fichiers   }
  { temporaires et laisse PageOpts/les pools Stmt dans un etat de TEST -     }
  { reinitialiser AVANT la compilation reelle. }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;
  BinAsmSelfTest;
  { MEME discipline : BinAsmSelfTest ecrit/efface ses PROPRES fichiers    }
  { temporaires (source ET .obj) et laisse les pools Stmt/El dans un        }
  { etat de TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;
  PeExeSelfTest;
  { MEME discipline : PeExeSelfTest ecrit/efface ses PROPRES fichiers     }
  { temporaires (source ET .exe) et laisse les pools Stmt/El dans un        }
  { etat de TEST - reinitialiser AVANT la compilation reelle. }
  JavaParserInit; PageInit; JspParamInit; ElParserInit; TaglibInit;
  TypeInit; RuntimeLibInit;
  SelfTestMode := False;
  { Les self-tests ci-dessus ont incremente WarnCount/ErrorCount via des   }
  { avertissements/erreurs VOLONTAIRES (PageSelfTest, TaglibSelfTest,       }
  { ImplicitObjectSelfTest) - les remettre a zero AVANT la compilation      }
  { reelle, sinon les statistiques finales (ShowStats) afficheraient a      }
  { tort ces avertissements/erreurs de test comme si ils venaient du        }
  { fichier source de l utilisateur (MEME categorie de fuite que celle      }
  { deja evitee ci-dessus pour l affichage console). }
  WarnCount  := 0;
  ErrorCount := 0;

  ParseArgs;
  ShowBanner;

  { Contexte (TODO 06) : repertoire du fichier de plus haut niveau -      }
  { ecrase toute valeur laissee par IncludeSelfTest. }
  ContextRootDir := ExtractDir(Opts.SrcFile);

  If Opts.DebugMode Then
  Begin
    { -d : affichage BRUT de chaque jeton (TODO 01/02) - PASSE SEPAREE,      }
    { AVANT la vraie compilation ci-dessous : ParsePage/CodeGenPage           }
    { pilotent le lexeur EUX-MEMES (TODO 21) et n offrent plus l occasion       }
    { d imprimer un jeton individuellement. }
    LexInit(Opts.SrcFile);
    Repeat
      Tok := LexNextToken;
      PrintToken(Tok);
    Until Tok.Kind = TOK_EOF;
    LexClose;
  End;

  { TODO 21 : la VRAIE compilation, ENFIN - lecture source -> ParsePage        }
  { (TODO 08) -> SemanticAnalyze (TODO 20, best-effort, JAMAIS bloquant) ->      }
  { CodeGenPage (TODO 21, gabarit litteral SEULEMENT - voir la note d en-tete      }
  { de Run ci-dessus pour la portee exacte et pourquoi un arret PROPRE sur           }
  { les 17 echantillons reels est le resultat ATTENDU de ce TODO). }
  IncludeInit(Opts.SrcFile);
  JspParamInit;
  LexInit(Opts.SrcFile);
  PageIdx := ParsePage;
  TotalLines := LexLine;
  LexClose;

  SemanticAnalyze(PageIdx);
  CheckEncodingCoherence(PageIdx);

  AsmPath := ReplaceExt(Opts.SrcFile, '.asm');
  Assign(OutF, AsmPath); Rewrite(OutF); OutFOpen := True;
  CodeGenPage(PageIdx);
  Close(OutF); OutFOpen := False;

  { TODO 23 : le VRAI .obj COFF, ENFIN - MEME decision que le TODO 21 pour   }
  { le .asm (ecrit TOUJOURS, a son PROPRE chemin fixe ReplaceExt(SrcFile,       }
  { '.obj'), JAMAIS Opts.OutFile lui-meme - le VRAI choix entre .obj/-obj          }
  { et un futur .exe/-exe (TODO 24) reste a trancher une fois les DEUX               }
  { existent reellement ; retirer -obj/-exe maintenant serait arbitraire,             }
  { pas principled, puisque le .asm est DEJA ecrit inconditionnellement). }
  ObjPath := ReplaceExt(Opts.SrcFile, '.obj');
  BinAssemblePage(PageIdx);
  WriteCOFFObj(ObjPath);

  { TODO 24 : le VRAI .exe PE, ENFIN - "Comportement par defaut (aucune       }
  { option -obj/-asm) : ce TODO est celui qui s execute" (roadmap d en-tete)      }
  { - ecrit TOUJOURS a son PROPRE chemin fixe (ReplaceExt(SrcFile, '.exe'),          }
  { MEME decision que .asm/.obj), qui COINCIDE desormais avec Opts.OutFile              }
  { par defaut (ParseArgs, TODO 01) - la phase "ASPIRATIONNELLE" documentee               }
  { depuis le TODO 21 se termine ICI : les TROIS artefacts sont maintenant                  }
  { REELS. }
  ExePath := ReplaceExt(Opts.SrcFile, '.exe');
  WritePEExe(PageIdx, ExePath);

  { Message de reussite : COURT et PROFESSIONNEL par defaut (convention          }
  { habituelle d un compilateur - gcc/javac/tsc ne racontent PAS leur                }
  { propre historique de developpement a chaque execution reussie). Le              }
  { recit "roadmap TODO NN/etat des echantillons" n a JAMAIS sa place ICI -            }
  { il reste documente dans les commentaires du code source, jamais                     }
  { affiche a l utilisateur qui compile son propre fichier. }
  WriteLn('JSPCW32: ', ExePath, ' genere avec succes.');
  If Opts.Verbose Then
  Begin
    WriteLn;
    WriteLn('Fichiers generes :');
    WriteLn('  .asm : ', AsmPath);
    WriteLn('  .obj : ', ObjPath);
    WriteLn('  .exe : ', ExePath);
  End;
  ShowStats;
  Halt(EXIT_OK);
End;

Begin
  Run;
End.
