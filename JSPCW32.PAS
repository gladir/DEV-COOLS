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
              erreur de traduction sinon - section 7.9/18)
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
            Grammaire EL (section 12.2 a 12.5, section 30 productions
              expressionEl) : identificateurs et navigation .prop/
              [index-ou-cle], litteraux (true/false/null/entiers/
              flottants/chaines '...'/"..."})
            Operateurs et PRECEDENCE (section 12.4, tableau de
              precedence) : [] . -> unaire (- not ! empty) ->
              multiplicatif (* / div % mod) -> additif (+ -) ->
              relationnel (< > <= >= lt gt le ge) -> egalite (==  !=
              eq ne) -> && and -> || or -> ternaire ?:
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
              8.4/13.1) - implementee comme une fonction unique
              _JSPEL_ResolveVar reutilisee par tout noeud identificateur
            empty operateur (section 12.4) : vrai pour null, chaine
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
              (section 16.3) plutot qu une vraie bibliotheque de tags
              chargee dynamiquement
            c:out value="${...}" [default="..."] : Test17JstlXml.jsp
              exerce l attribut default ; echappement HTML implicite
              (section 24, XSS) a documenter comme comportement par
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
              la reference (section 16.3.1)

  TODO 17 - JSTL FUNCTIONS : FN:LENGTH, FN:ESCAPEXML
            Syntaxe d appel de fonction EL prefixee (section 12.5,
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
              TODO 07, membres de la classe page synthetique) et EL
              (TODO 15) - un seul passage combine sur l arbre construit
              au TODO 08
            Verification des attributs obligatoires par directive/
              action (section 5/9 - ex. jsp:useBean exige id et class)
            Verification de coherence : exception implicite seulement
              si isErrorPage=true (section 7.9), errorPage doit
              designer un fichier existant et resoluble
            Detection best-effort de gabarit/scriptlet non fermes,
              prefixe taglib reference sans directive taglib
              correspondante, inclusion statique circulaire (TODO 11)

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
            pageEncoding / contentType charset (section 22) - les
              TROIS encodages qui doivent rester coherents (section
              22.1) : pageEncoding de la directive page, charset du
              contentType, et le charset effectivement utilise pour
              lire le fichier .jsp source lui-meme
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
    EK_NEWOBJECT   { NameVal = nom de type EVENTUELLEMENT qualifie            }
                   { ("java.util.Date") ; ArgFirst/ArgCount = arguments        }
                   { du constructeur }
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
    SK_EMPTY      { ';' seul }
  );

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
    ParserAdvance;
    ParsePrimary := Idx;
    Exit;
  End;
  If CurIsOp('(') Then
  Begin
    ParserAdvance;
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
Function ParseBlock: Integer;
Var
  Idx, ChildFirst, Count, I : Integer;
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
    If CurTok.Kind = TOK_TAG_CLOSE Then
    Begin
      FatalError('bloc "{" non ferme (accolade fermante attendue) avant %>');
      Break;
    End;
    If Count >= MAX_JAVA_BLOCK_LOCAL Then
    Begin
      FatalError('trop d instructions dans un seul bloc (MAX_JAVA_BLOCK_LOCAL)');
      Break;
    End;
    LocalChild[Count] := ParseStatement;
    Inc(Count);
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
{ Run : point d entree - portee TODO 01-07 (options + lexeur de  }
{ gabarit/directives/actions + table des types + parseur des      }
{ directives page/include/taglib + parseur Java des declarations/  }
{ scriptlets/expressions). AUCUN entrelacement gabarit<->Java/       }
{ analyseur semantique/codegen n existe encore (TODO 08 et suivants) :}
{ Run tokenise le fichier source en entier (affichant chaque token    }
{ si -d) puis rapporte honnetement que l analyse syntaxique COMPLETE   }
{ n est pas encore implementee, plutot que de simuler un resultat.      }
{ ------------------------------------------------------------ }

Function IsHelpArg(Const Arg: TString): Boolean;
Begin
  IsHelpArg := (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
               (Arg = '/h') Or (Arg = '/H');
End;

Procedure Run;
Var Tok : TToken;
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
  SelfTestMode := False;
  { Les self-tests ci-dessus ont incremente WarnCount via des             }
  { avertissements VOLONTAIRES (PageSelfTest, TaglibSelfTest) - le         }
  { remettre a zero AVANT la compilation reelle, sinon les statistiques    }
  { finales (ShowStats) afficheraient a tort ces avertissements de test    }
  { comme si ils venaient du fichier source de l utilisateur (MEME         }
  { categorie de fuite que celle deja evitee ci-dessus pour l affichage    }
  { console). }
  WarnCount := 0;

  ParseArgs;
  ShowBanner;

  { Contexte (TODO 06) : repertoire du fichier de plus haut niveau -      }
  { ecrase toute valeur laissee par IncludeSelfTest. }
  ContextRootDir := ExtractDir(Opts.SrcFile);

  LexInit(Opts.SrcFile);
  Repeat
    Tok := LexNextToken;
    PrintToken(Tok);
    If Tok.Kind = TOK_TEMPLATE_CHUNK Then
      { statistique grossiere : compte les sauts de ligne du gabarit,    }
      { seule notion de "ligne" disponible tant que TODO 03+ n existe    }
      { pas encore de vrai suivi ligne par ligne du fichier entier. }
      TotalLines := LexLine;
  Until Tok.Kind = TOK_EOF;
  LexClose;

  WriteLn('JSPCW32: lexeur de gabarit/directives/actions + table des ',
          'types + parseur des directives page/include/taglib + parseur ',
          'Java (declarations/scriptlets/expressions) (TODO 01-07) en ',
          'place - entrelacement gabarit<->Java et generation de code ',
          'non encore implementes (TODO 08 a 24).');
  ShowStats;
  Halt(EXIT_OK);
End;

Begin
  Run;
End.
