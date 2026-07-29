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
            Sequences d echappement du gabarit (section 4.5) : <\% et
              %\> pour un delimiteur litteral
            EL/deferred EL (section 12) : ${ ... } et #{ ... } reconnus
              DEPUIS le mode template comme un cas special d expression
              embarquee (pas juste une expression Java) - bascule vers
              un sous-lexer EL distinct (TODO 13), $$ et \$ litteraux
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
            Coercitions EL (section 12.6, tableau de coercition A->B) :
              String<->nombre, String<->boolean, null vers primitif =
              valeur par defaut, objet vers String via toString() -
              DECISION A DOCUMENTER : implementees comme un ensemble
              fixe de regles au moment de la generation de code plutot
              qu une reflexion dynamique complete
            Representation runtime des attributs de scope (TODO 09) et
              des valeurs EL - DECISION A DOCUMENTER explicitement ici
              avant le TODO 20 : une "valeur EL" est une union taguee
              {Kind; en fonction de Kind: LongInt / Double / Boolean /
              PChar-vers-buffer-longueur-prefixee / pointeur objet} -
              meme discipline "documenter avant de coder" que
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
            ParseIncludeDirective (section 5.2) : attribut file,
              chemin relatif au fichier courant - le fichier est
              fusionne au moment de la TRADUCTION (voir TODO 11 pour
              le mecanisme de fusion lui-meme, ce TODO se limite au
              parsing de la directive et a la resolution du chemin)
            ParseTaglibDirective (section 5.3/14.2) : attribut prefix
              (obligatoire) + (uri OU tagdir) ; TTaglibDecl (Prefix,
              Uri, IsCoreJstl, IsFunctionsJstl) ; reconnaitre les deux
              familles d URI (section 16.1/27) : legacy
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
              ne l exercice, ${...} suffit pour tous les Test*)
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
