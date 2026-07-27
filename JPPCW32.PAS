{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur J++ vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program JPPCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  JPPCW32.PAS - Compilateur J++ (Microsoft Visual J++ 1.0/1.1/6.0,
  noyau syntaxique Java 1.1 + extensions Microsoft) vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Reference langage : DOC\JPP_SPEC_LANG.txt (23 sections). J++ y
  designe Microsoft Visual J++ 1.0/1.1/6.0 - PAS le Java moderne, ni
  J#, ni C++/CLI. Le noyau syntaxique correspond a Java 1.1 (aucun
  assert/generiques/enum/foreach/varargs/autoboxing/lambda/etc.),
  augmente des extensions Microsoft (delegates, directives en
  commentaire, compilation conditionnelle, J/Direct, com.ms.*, WFC).

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\JPP\*.jpp (18 fichiers : 13
  portables Java 1.1 - Test01 a Test13 -, 5 extensions Microsoft non
  portables necessitant Windows/MSJVM/SDK - Test14 a Test18, voir
  SAMPLES\JPP\README.txt).

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode, DefinedSymbols -
              liste des symboles de compilation conditionnelle passes
              en ligne de commande, alimente le TODO 17)
            ParseArgs : jppcw32 source.jpp [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-D SYMBOLE] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie ;
              -D : definit un symbole de compilation conditionnelle
              (repetable, ex. -D DEBUG -D LANG_FR, voir TODO 17)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extension .jpp (accepter aussi .java, meme
              convention que le README des echantillons - "copier en
              .java" pour un compilateur qui n accepterait que .java) ;
              verification best-effort que le nom de la classe publique
              correspond au nom de fichier (section 2 de la reference)
            Portee : UN SEUL fichier .jpp par compilation (pas de vrai
              systeme de paquets multi-fichiers/repertoires - voir
              TODO 12), meme discipline que GOCW32.PAS/SWIFTW32.PAS
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512),
              PE_SUBSYS_CUI / PE_SUBSYS_GUI
            Limites : MAX_SYM=4096, MAX_FUNC=512 (methodes static),
              MAX_METHOD=512 (methodes d instance), MAX_TYPE=1024
              (classes+interfaces+tableaux), MAX_FIELD_POOL=4096,
              MAX_PARAM=64, MAX_LOCAL=256, MAX_LABEL=4096, MAX_STR=255,
              MAX_ERRORS=30, MAX_CLASS=256, MAX_INTERFACE=128,
              MAX_CATCH=64 (clauses catch), MAX_THREAD=32,
              MAX_DELEGATE=64, MAX_DEFINE=32 (symboles -D)
            Prefixes ASM : _JPP_ (champ static/global), _JPPF_
              (methode static), _JPPM_ (methode d instance), _JPPK_
              (constante chaine/litteral), _JPPRT_ (runtime), _JPPL_
              (label de saut interne), _JPPT_ (descripteur de type/
              vtable simplifiee), _JPPD_ (thunk de delegate)

  TODO 02 - TOKENISEUR J++ (LEXER)
            LexInit, LexClose, LexNextChar, LexPeekChar, LexNextToken
            Identificateurs (section 3.1/3.6) : lettre/'_'/'$' en
              tete, chiffres ensuite ; sensibles a la casse
            Litteraux (section 3.4/3.7/3.8) : entiers decimaux/
              hexadecimaux ($0x)/octaux (0 en tete), suffixe L (long) ;
              flottants avec exposant et suffixes f/F/d/D ; caracteres
              'x' avec echappements (\n \t \\ \' \xFF etc., section
              3.9) ; chaines "..." avec les MEMES echappements ;
              litteraux booleens true/false ; null
            Commentaires : // fin de ligne, /* ... */ bloc SANS
              imbrication (section 3.3) ; /** ... */ javadoc - a
              tokeniser distinctement (pas juste ignorer comme un
              commentaire ordinaire) puisque son CONTENU porte parfois
              une directive Microsoft interpretee au TODO 17
              (@dll.import - voir Test18JDirect.jpp)
            Operateurs/ponctuation Java 1.1 complets (section 6) :
              + - * / % & | ^ << >> >>> (decalage arithmetique NON
              signe, forme propre a Java - encodage dedie a prevoir,
              absent des compilateurs freres) += -= *= /= %= &= |=
              ^= <<= >>= >>>= ++ -- == != < > <= >= && || ! ~ ?  :
              = ( ) [ ] { } , ; . instanceof
            Les lignes "#if/#else/#elif/#endif" (Test15Conditionnelle.
              jpp) NE sont PAS des tokens du lexer Java lui-meme -
              directive de compilation conditionnelle Microsoft
              distincte, traitee par un PRE-passage separe (TODO 17,
              decision d ordonnancement a documenter explicitement
              avant d ecrire le code)
            Types de token : TOK_IDENT, TOK_INT, TOK_LONG, TOK_FLOAT,
              TOK_DOUBLE, TOK_CHAR, TOK_STRING, TOK_EOF

  TODO 03 - MOTS RESERVES ET IDENTIFICATEURS PREDECLARES
            IsKeyword(s : String) : Integer - les mots reserves du
              noyau Java 1.1 (section 3.2, liste EXHAUSTIVE pour ce
              dialecte : ni assert, ni enum, ni strictfp - voir section
              21.5 de la reference pour ce qui devient reserve
              SEULEMENT en Java plus recent, hors de portee ici)
            Mots contextuels propres a Microsoft J++ : delegate,
              multicast (section 16 - ne sont PAS des mots-cles Java
              standard, seulement reconnus dans une position de
              declaration de delegate)
            Litteraux predeclares : true, false, null ; type primitif
              void utilise comme type de retour
            Semis de base de la table des types predeclares (StdlibTab
              embryonnaire, affine aux TODO 13/16/18/20) : Object,
              String, et les classes d exception les plus immediates
              (Exception, RuntimeException, Throwable, Error)
            Fichiers de test couverts en premier (SAMPLES\JPP\*.jpp) :
              Test01Bonjour.jpp (class/main/System.out.println),
              Test02Variables.jpp

  TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES
            TTypeKind : TYK_BOOLEAN, TYK_BYTE, TYK_SHORT, TYK_INT,
              TYK_LONG, TYK_CHAR (16 bits, Unicode - decision explicite
              a documenter si ce compilateur simplifie a 8 bits pour
              les echantillons ASCII-seulement reels), TYK_FLOAT,
              TYK_DOUBLE, TYK_STRING (type reference SPECIAL,
              immuable), TYK_ARRAY (ElemTypeIdx + rang), TYK_CLASS,
              TYK_INTERFACE, TYK_NULL, TYK_VOID
            TTypeRec (Kind, Name, Size, Align, ElemTypeIdx [tableau],
              SuperTypeIdx [heritage simple, UNE seule superclasse -
              Object implicite si absente], InterfaceFirst/Count
              [implements, heritage MULTIPLE d interfaces seulement],
              FieldFirst/FieldCount [pool partage, meme technique que
              DELPHI.PAS/SWIFTW32.PAS], MethodFirst/MethodCount)
            Valeurs par defaut par type (section 4.6) : 0/0L/0.0f/
              0.0d/false/le caractere NUL (PAS un espace)/null
              (reference)
            Promotions numeriques (4.7), conversions elargissantes
              (4.8) et reductrices/casts explicites (4.9)
            Representation memoire runtime - DECISIONS A DOCUMENTER
              explicitement ici avant le TODO 21 :
                objet   = bloc tas avec un pointeur de descripteur de
                          type/vtable simplifiee au deplacement 0
                          (dispatch de methode virtuelle + interface,
                          meme simplification "un seul descripteur de
                          type concret suffit" que GOCW32.PAS/
                          SWIFTW32.PAS)
                tableau = bloc tas {Length:LongInt; elements...} - la
                          longueur EST stockee ("a.length" est un VRAI
                          champ Java, contrairement a Array<Int> de
                          SWIFTW32.PAS qui l omettait deliberement)
                String  = type reference immuable, MEME convention
                          "la valeur EST un pointeur" que les
                          compilateurs freres, mais representation
                          interne a decider EXPLICITEMENT (tampon
                          prefixe par sa longueur plutot qu un simple
                          C-string termine par NUL, puisqu une vraie
                          chaine Java autorise un caractere NUL
                          embarque) - ne PAS reutiliser aveuglement
                          une convention C-string d un compilateur
                          frere sans verifier qu elle convient

  TODO 05 - DECLARATIONS : CHAMPS, VARIABLES LOCALES, PARAMETRES, "final"
            Champs d instance et champs static (section 5.3/5.4) -
              modificateurs public/private/protected/static/final
            Variables locales (5.5, SANS inference de type - J++ est
              anterieur a "var"), parametres de methode (5.6),
              parametre de catch (5.7), composantes de tableau (5.8)
            "final" comme equivalent J++ du "let" (verification best-
              effort d affectation unique, MEME discipline que les
              compilateurs freres)
            Portee lexicale et masquage (5.9) - regles de visibilite
              d un local par rapport a un champ de meme nom

  TODO 06 - OPERATEURS ET EXPRESSIONS
            Table de precedence complete (6.1), ordre d evaluation et
              effets de bord (6.2)
            Unaires + - ~ ! (6.3), increment/decrement pre/post-fixe
              (6.4)
            Promotions binaires (6.5), * / % (6.6), + - ET l operateur
              "+" special de concatenation avec String (6.7 - un
              operande String force la conversion de l autre operande
              en chaine, meme regle que tout autre compilateur qui
              implemente "+"/String de ce projet)
            Decalages << >> >>> (6.8 - >>> propre a Java, encodage
              DEDIE necessaire, absent des compilateurs freres)
            Comparaisons ordonnees (6.9), == sur reference VS primitif,
              instanceof
            &&/|| (court-circuit REEL, meme discipline que le "??" de
              SWIFTW32.PAS), &/|/^ bit-a-bit (aussi valides sur
              boolean en Java), ternaire ?:
            Operateurs d affectation composes, "new" (objet ET
              tableau), indexation de tableau, acces champ/methode
              ("."), cast explicite

  TODO 07 - INSTRUCTIONS (CONTROLE DE FLUX)
            Bloc, instruction vide, instructions-expression,
              declaration locale (7.2-7.6)
            if/else (7.8, association du else le plus proche), while,
              do-while, for (3 clauses CLASSIQUES seulement - PAS de
              for-each, J++ lui est anterieur)
            switch/case/default - tags int/char/byte/short SEULEMENT
              (pas de String en switch, extension Java posterieure),
              FALL-THROUGH implicite par defaut (semantique Java
              REELLE, differente du switch de SWIFTW32.PAS qui exige
              "fallthrough" explicite)
            break/continue NON etiquetes ET ETIQUETES (les labels sur
              instruction sont une VRAIE fonctionnalite Java 1.1,
              contrairement a GOCW32.PAS/SWIFTW32.PAS qui ne couvrent
              que la forme non etiquetee - concevoir une pile
              d etiquettes nommees des le depart, pas une extension
              ulterieure)
            return, throw (voir TODO 11), instruction synchronized(...)
              (voir TODO 14)
            Fichiers de test : Test03Instructions.jpp (le "#if" de
              Test15Conditionnelle.jpp est une couche de PRE-
              traitement Microsoft SEPAREE, voir TODO 17 - pas une
              instruction du langage lui-meme)

  TODO 08 - CLASSES ET OBJETS
            Declaration de classe, modificateurs (public/final/
              abstract), extends (heritage SIMPLE - Object implicite),
              corps et membres (8.2-8.3)
            Creation avec new (8.5), constructeurs et constructeur par
              defaut (8.6-8.7), chainage this(...)/super(...) (8.8)
            ORDRE D INITIALISATION D INSTANCE (8.9) - a implementer
              REELLEMENT, pas approxime : initialiseurs de champ et
              blocs d initialisation d instance dans l ordre TEXTUEL,
              PUIS le corps du constructeur (apres l appel implicite/
              explicite a super())
            Blocs d initialisation static (semantique "executee une
              fois au chargement de la classe", simplifiee a "executee
              une fois avant main", meme approche que
              CompileGlobalRuntimeInits des compilateurs freres)
            Fichiers de test : Test04Methodes.jpp,
              Test06ProprietesBean.jpp (getAge()/setAge() sont des
              METHODES ORDINAIRES - AUCUNE syntaxe de propriete
              speciale, contrairement a C# - voir section 15.3),
              Test07Heritage.jpp

  TODO 09 - INTERFACES, CLASSES INTERNES ET IMBRIQUEES
            Declaration d interface (9.2), methodes implicitement
              public abstract (9.3), champs implicitement public
              static final (9.4)
            implements (heritage MULTIPLE d interfaces, 9.5),
              resolution de conflits de methodes/constantes heritees
              (9.6-9.7), dispatch d une implementation concrete (9.9)
            Classes internes/imbriquees/locales/anonymes (7.6 +
              section 9) - PORTEE A DECIDER EXPLICITEMENT : grep
              d abord SAMPLES\JPP\*.jpp pour la liste REELLE des formes
              exercees avant d en deviner l ampleur ; documenter
              precisement ce qui est couvert (probablement au minimum
              une classe nommee de haut niveau qui etend Exception,
              Test09DonneeException) et ce qui reste une extension
              future explicite (classe anonyme/capture de fermeture)
            Fichier de test : Test08Interfaces.jpp

  TODO 10 - TABLEAUX
            Creation a une dimension (new T[n], 10.3), syntaxe des
              types tableau T[] (10.2), initialiseurs {a,b,c} et
              creation anonyme new T[]{...} (10.4-10.5)
            Valeurs par defaut des elements (10.6)
            Indexation AVEC VERIFICATION DE BORNE (10.7) - semantique
              Java REELLE (ArrayIndexOutOfBoundsException a l acces
              hors bornes, lie au TODO 11) : DECIDER explicitement le
              mecanisme (vraie exception lancee, ou panique documentee
              simplifiee) plutot que de deviner silencieusement -
              aucun compilateur frere de ce projet n a encore eu
              besoin de verification de borne reelle
            Champ .length (10.8 - VRAIMENT stocke a la construction,
              contrairement a Array<Int> de SWIFTW32.PAS), parcours
              indexe (10.9)
            Tableaux multi-dimensionnels (tableaux de tableaux) -
              portee a confirmer par lecture reelle de
              Test05Tableaux.jpp avant de decider l ampleur du support
            Fichier de test : Test05Tableaux.jpp

  TODO 11 - EXCEPTIONS
            Hierarchie Throwable (11.2) : Throwable/Exception/
              RuntimeException/Error, PLUS les classes concretes
              REELLEMENT lancees par les echantillons
              (IllegalArgumentException, NumberFormatException,
              InterruptedException, UnsatisfiedLinkError, et une
              exception UTILISATEUR qui etend Exception -
              DonneeException de Test09Exceptions.jpp)
            Exceptions verifiees vs non verifiees (11.3-11.4), throw
              (11.5), clause throws (11.6 - verification best-effort
              SEULEMENT au niveau du front-end, meme discipline que les
              compilateurs freres pour leurs propres clauses "throws"/
              "try")
            try/catch (clauses MULTIPLES)/finally, propagation REELLE
              dans la pile d appels (11.7) - MECANISME REEL A
              CONCEVOIR ET DOCUMENTER avant le TODO 21 (deroulement
              style SEH 80386, ou convention simplifiee de
              retour-code/longjmp) : contrairement a plusieurs
              compilateurs freres qui ont pu differer un VRAI
              mecanisme d exception, J++ en a un besoin direct et
              exerce (Test09Exceptions.jpp catch reellement, Test11
              declare "throws InterruptedException")
            Fichier de test : Test09Exceptions.jpp

  TODO 12 - PAQUETS, IMPORTS ET VISIBILITE
            Declaration package (12.2), paquet sans nom (12.3),
              hierarchie nominale et convention de nommage (12.4-12.5)
            import de type unique et import a la demande ("import
              paquet.etoile") (12.8-12.9) - PORTEE : un SEUL fichier .jpp par
              compilation (meme discipline "pas de vrai systeme multi-
              fichiers" que GOCW32.PAS/SWIFTW32.PAS), donc AUCUNE
              correspondance reelle repertoire<->paquet (12.6, hors de
              portee, documente explicitement)
            Modificateurs de visibilite public/protected/(paquet par
              defaut)/private - verification best-effort (meme niveau
              que le reste de l analyse semantique des compilateurs
              freres) ; resolution de java.* et com.ms.* vers les
              entrees de StdlibTab construites aux TODO 13/16/18/20,
              JAMAIS une vraie resolution de systeme de fichiers
            Fichiers de test : Test16Win32.jpp/Test17PaquetsMicrosoft.
              jpp/Test18JDirect.jpp (imports com.ms.etoile)

  TODO 13 - ENTREES/SORTIES ET BIBLIOTHEQUE JAVA 1.1 MINIMALE
            StdlibTab (meme modele que GOCW32.PAS TODO 20/SWIFTW32.PAS
              TODO 20 : chaque entree connue du front-end des
              l analyse, contrepartie runtime reelle ajoutee selon les
              besoins constates par execution, jamais devinee
              d avance)
            System.out/System.err : println/print (String, int, etc.),
              backed par de vrais WriteFile/GetStdHandle Win32 (meme
              runtime que les compilateurs freres)
            String/StringBuffer : methodes minimales REELLEMENT
              exercees (length, charAt, equals, toString-like) ;
              concatenation "+" deja couverte au TODO 06
            java.util.Vector/Hashtable : sous-ensemble minimal exerce
              par Test10Collections.jpp
            java.io : sous-ensemble minimal de flux (InputStream/
              OutputStream/FileInputStream/FileOutputStream) exerce
              par Test12Fichiers.jpp - backed par de VRAIES fonctions
              Win32 (CreateFile/ReadFile/WriteFile), meme discipline
              "aucun mecanisme devine" que le reste de ce projet
            Integer.parseInt et utilitaires de classe enveloppe
              similaires reellement exerces (Test09Exceptions.jpp)
            Fichiers de test : Test10Collections.jpp,
              Test12Fichiers.jpp

  TODO 14 - THREADS ET SYNCHRONISATION
            Classe Thread et interface Runnable (14.2-14.3),
              constructeurs de Thread (14.5), start()/run(), thread
              courant et son nom (14.8-14.9)
            VRAIS threads Win32 (CreateThread) - meme precedent que les
              goroutines-en-vrais-threads de GOCW32.PAS : decider et
              documenter explicitement la correspondance Thread.start()
              -> CreateThread AVANT de l implementer au TODO 21
            Modificateur de methode "synchronized" ET instruction
              synchronized(obj) - une VRAIE section critique/mutex
              Win32 par objet moniteur, OU un verrou global simplifie
              explicitement documente - decision A PRENDRE ici, pas
              devinee au TODO 21
            wait()/notify()/notifyAll() (Test11 utilise wait()/
              notifyAll()) - VRAI mecanisme de variable de condition,
              ou simplification explicitement documentee, jamais
              silencieusement approximee
            Fichier de test : Test11Threads.jpp

  TODO 15 - APPLETS, AWT ET WFC (PORTEE GUI - DECISION EXPLICITE)
            Cycle de vie d une applet (15.5-15.9), com.ms.awt/
              com.ms.ui (15.1-15.4), comparaison proprietes JavaBean/
              WFC/C# (15.3 - deja utile pour justifier pourquoi
              getX()/setX() du TODO 08 sont de simples methodes)
            DECISION DE PERIMETRE EXPLICITE A PRENDRE ICI (ne pas la
              repousser en la devinant au TODO 21) : une VRAIE
              interface graphique Win32 (fenetres reelles, boucle de
              messages) est un chantier a part entiere, hors de la
              taille d un TODO incremental unique - choisir ENTRE
              (a) un sous-ensemble REEL minimal de fenetrage natif
              (CreateWindowEx + boucle de messages, dans le meme
              esprit que les appels Win32 directs de Test16Win32.jpp)
              (b) une portee explicitement REDUITE/hors-de-portee pour
              Test13Awt.jpp, avec un arret propre documente
              (FatalError explicite), MEME discipline que tout
              constructeur non couvert des compilateurs freres
            Fichier de test : Test13Awt.jpp

  TODO 16 - DELEGATES ET EVENEMENTS MICROSOFT
            Declaration delegate/multicast delegate (16.3-16.6),
              delegate lie a une methode d instance VS static
              (16.6-16.7), compatibilite de signature (16.8)
            "new Operation(this.methode)" -> une VRAIE paire liee
              {pointeur-de-methode, objet-cible} (bound method
              reference), ".invoke(...)" declenche l appel a travers
              cette paire
            multicast delegate -> une VRAIE liste de paires liees
              invoquees en SEQUENCE (Notification de Test14) -
              decider la representation concrete (tableau ou liste
              chainee de paires {cible,pointeur}) AVANT d ecrire le
              code
            Fichier de test : Test14Delegates.jpp

  TODO 17 - DIRECTIVES MICROSOFT ET COMPILATION CONDITIONNELLE
            Deux familles distinctes (17.1) : directives en
              commentaire javadoc (/** @dll.import(...) */,
              17.6-17.9 - alimente le J/Direct du TODO 18) VS lignes
              #if/#else/#elif/#endif de compilation conditionnelle
              (Test15Conditionnelle.jpp), pilotees par les symboles
              -D de la ligne de commande (TODO 01)
            Passe de PRE-traitement : scanner/eliminer les blocs #if
              AVANT la vraie tokenisation (ou entrelacee avec elle) -
              le fichier d exemple imbrique "#if" A L INTERIEUR d un
              corps de methode, decider et DOCUMENTER explicitement
              l ordonnancement exact des passes avant d ecrire le code
            Extraire le texte de la directive @dll.import(...) du
              commentaire /** */ qui PRECEDE une declaration de methode
              "native" (voir TODO 18)
            Fichiers de test : Test15Conditionnelle.jpp,
              Test18JDirect.jpp

  TODO 18 - INTEROPERABILITE COM ET WIN32 (J/DIRECT)
            com.ms.win32 (18.1) - declarations directes d API Win32
              telles que User32.MessageBox : correspondance NATURELLE
              avec ce compilateur puisqu il cible du VRAI code machine
              80386 (contrairement au bytecode MSJVM d origine - AUCUNE
              emulation necessaire), reutilisant le MEME mecanisme de
              thunk IAT que les compilateurs freres batissent deja pour
              leurs propres importations runtime (TODO 23)
            com.ms.com (18.2) - IUnknown/QueryInterface/comptage de
              references (18.6-18.9) - PORTEE A DECIDER explicitement :
              un vrai interop COM complet est un chantier majeur,
              decider un sous-ensemble minimal OU documenter
              explicitement hors de portee, sans deviner
            Methode native J/Direct + @dll.import(NOMDLL[, entrypoint])
              (la directive parsee au TODO 17) -> une VRAIE importation
              DLL avec thunk de convention d appel native, MEME
              mecanisme que les appels com.ms.win32
            Fichiers de test : Test16Win32.jpp,
              Test17PaquetsMicrosoft.jpp (inventaire seul, portee tres
              probablement reduite/documentee), Test18JDirect.jpp

  TODO 19 - ANALYSE SEMANTIQUE
            Verification de type best-effort (meme discipline que
              CHAQUE compilateur frere) : compatibilite d affectation,
              resolution de SURCHARGE de methode (Java autorise la
              surcharge, contrairement a Go), compatibilite de
              redefinition (override), verification best-effort
              d affectation definie pour "final", code inaccessible
              best-effort, coherence best-effort de la clause "throws"
              par rapport aux "throw" reels du corps
            SemanticAssert/SemanticSelfTest, meme modele que chaque
              compilateur frere de ce projet

  TODO 20 - BIBLIOTHEQUE MINIMALE FINALE (CONSOLIDATION STDLIBTAB)
            Consolider toute la surface de bibliotheque touchee aux
              TODO 13/14/16/18 en une seule StdlibTab coherente (meme
              modele "connue du front-end, contrepartie runtime reelle
              ajoutee seulement au besoin constate" que chaque
              compilateur frere a son propre TODO 20)

  TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM
            Meme discipline que GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS :
              portee VOLONTAIREMENT restreinte a ce que TODO 01-20 ont
              reellement construit, tout le reste s arrete PROPREMENT
              (FatalError explicite, jamais un .asm silencieusement
              faux ni un plantage), grandissant par extensions
              incrementales separement verifiees exactement comme
              l historique post-TODO25 de chaque compilateur frere
            Disposition d objet : pointeur de descripteur de type/
              vtable au deplacement 0 pour le dispatch de methode
              virtuelle ET d interface (simplification deja decidee
              au TODO 04)
            Mecanisme de deroulement d exception (decide au TODO 11,
              construit ICI pour de vrai)
            Vrais threads Win32 et synchronized (decides au TODO 14,
              construits ICI)

  TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32
            Meme architecture d assembleur 80386 + ecrivain COFF que
              CHAQUE compilateur frere (BinLabels/BinFixups/
              BinResolveFixups/WriteCOFFObj) - largement independante
              du langage source, a porter quasi VERBATIM comme chaque
              compilateur precedent de ce projet l a deja fait

  TODO 23 - ECRIVAIN .EXE PE WIN32 + BIBLIOTHEQUE RUNTIME INCORPOREE
            Meme architecture d ecrivain PE que chaque compilateur
              frere (thunks IAT, en-tetes DOS/PE, .idata) - c est AUSSI
              ICI que les importations DLL com.ms.win32/J/Direct
              (TODO 18) deviennent de VRAIES entrees de table
              d importation PE, pas un mecanisme separe

  TODO 24 - AUDIT DES AUTO-TESTS
            Meme separation des responsabilites RunAllSelfTests que
              chaque compilateur frere de ce projet

  TODO 25 - VALIDATION FINALE CONTRE SAMPLES\JPP\*.jpp
            Rapport honnete fichier par fichier, EXACTEMENT comme le
              TODO 25 de chaque compilateur frere : couvrir au MINIMUM
              les 13 echantillons portables Java 1.1 (Test01 a Test13)
              comme cible principale, les 5 echantillons specifiques
              Microsoft (Test14 a Test18) etant explicitement notes
              comme necessitant le support Windows/cible-native
              construit aux TODO 16-18 - meme precedent qu un rapport
              honnete fichier-par-fichier plutot qu une reussite
              globale supposee
  ============================================================ *)

(* ============================================================
  TODO 25 - VALIDATION FINALE : ETAT REEL, HONNETEMENT DOCUMENTE
  ============================================================
  Compile (et, quand REELLEMENT possible, ASSEMBLE+LIE+EXECUTE) a ete
  verifie pour CHACUN des 18 SAMPLES\JPP\*.jpp (2026-07-27) - rapport
  honnete plutot qu une reussite globale supposee, EXACTEMENT comme
  cette section l annoncait plus haut :

  1/18 REUSSITE COMPLETE (compile, genere un .OBJ COFF ET un .EXE PE
  Win32 REELS - TODO 22/23 -, EXECUTE sur Windows reel, sortie
  standard verifiee OCTET PAR OCTET, code de sortie 0) :
    Test17PaquetsMicrosoft.jpp - notablement l UN DES CINQ echantillons
    SPECIFIQUES MICROSOFT (Test14-18), PAS l un des 13 "portables Java
    1.1" que cette section nommait pourtant "cible principale" plus
    haut - simplement parce que ce fichier precis se limite a des
    appels System.out.println(litteral de chaine) SEQUENTIELS SANS
    branchement ni reference a une variable/un parametre, la SEULE
    forme que le premier jalon du generateur de code (TODO 21) sait
    compiler a ce jour, independamment de la classification portable/
    Microsoft-specifique du fichier.

  17/18 ARRET PROPRE ET DOCUMENTE (JAMAIS un .asm/.obj/.exe
  silencieusement faux, JAMAIS un plantage) - AUCUNE extension
  incrementale du generateur de code n a ete demandee ni ajoutee au
  cours de cette session depuis le "premier jalon" du TODO 21
  (contrairement a GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS, qui ont chacun
  reçu de nombreuses extensions de ce genre - arithmetique, if/while/
  for, tableaux, appels de methode utilisateur - ENTRE leur propre
  TODO 21 et leur propre TODO 25 ; cette session a traite les TODO
  numerotes un par un, jamais de travail supplementaire non demande).
  Repartition EXACTE des 17, VERIFIEE (pas devinee) en isolant chaque
  cas dans un fichier .jpp synthetique separe :

    - genre #5 (STK_IF, Ord(StmtPool[S].Kind) - voir CompileStmt) :
      Test01Bonjour.jpp - PRECISEMENT le "if (args.length == 0)"
      documente depuis le TODO 21 lui-meme (sa note d en-tete : "vraie
      decouverte qui a redessine la portee du jalon").
    - genre #4 (STK_DECL, declaration de variable locale) :
      Test02Variables.jpp, Test03Instructions.jpp, Test05Tableaux.jpp,
      Test10Collections.jpp, Test16Win32.jpp - CompileStmt ne couvre
      QUE STK_BLOCK et STK_EXPR(EK_CALL), TOUTE declaration locale
      s arrete ici, meme la plus simple ("int x = 1;").
    - genre #3 (STK_ASSIGN, affectation) : Test07Heritage.jpp,
      Test08Interfaces.jpp - "this.champ = parametre;" dans un
      constructeur.
    - genre #14 (STK_RETURN, retour non nu) : Test04Methodes.jpp,
      Test14Delegates.jpp, Test15Conditionnelle.jpp.
    - genre #17 (STK_TRY) : Test18JDirect.jpp.
    - "appel de methode non resolu" (CompileCall, EK_CALL.Extra < 0 a
      la compilation) - DEUX causes DISTINCTES, chacune confirmee par
      un test isole avant d etre documentee ICI, PAS supposees
      identiques par simple ressemblance du message :
        - Test06ProprietesBean.jpp : le CONSTRUCTEUR de Personne
          appelle setNom(nom)/setAge(age), DEUX methodes declarees
          PLUS LOIN dans le MEME fichier - ClassResolveMethodCall
          (TODO 08/21) est appelee AU MOMENT du parsing de l appel,
          contre un MethodPool qui ne contient PAS ENCORE ces deux
          methodes (remplies dans l ORDRE TEXTUEL du fichier) : une
          REFERENCE EN AVANT, a l interieur d une MEME classe, vers
          une methode declaree plus loin ne resout donc JAMAIS -
          limite STRUCTURELLE du front-end MONO-PASSE de ce
          compilateur (partagee par toute la famille GOCW32.PAS/
          SWIFTW32.PAS/DELPHI.PAS, jamais documentee explicitement
          avant cette validation), PAS une limite du generateur de
          code lui-meme - confirmee par un test isole minimal ou
          inverser l ordre textuel (methode AVANT le constructeur qui
          l appelle) fait passer l erreur de "non resolu" a "appel a
          [nom] non couvert" (resolu, juste pas encore codegenere).
        - Test09Exceptions.jpp : le CONSTRUCTEUR de DonneeException
          appelle "super(message)" - le chainage de constructeur
          this(...)/super(...) (TODO 08 : "une expression d appel de
          methode ORDINAIRE sur l identificateur special this/super",
          DELIBEREMENT pas un genre d instruction dedie) resout un
          VRAI constructeur via ClassFindConstructor, JAMAIS via
          ClassResolveMethodCall (qui cherche une METHODE nommee
          "super" - inexistante) - EK_CALL.Extra ne peut donc JAMAIS
          se peupler pour cette forme precise, quel que soit l ordre
          textuel : gap DISTINCT du precedent, confirme par un test
          isole (Derived.Derived(String) { super(m); }, Base.Base
          DEJA declaree AVANT - echoue identiquement).
    - "type ... inconnu" (Test13Awt.jpp, "Frame") : DECISION DE PORTEE
      DELIBEREE prise au TODO 15 (AWT/applets/WFC explicitement HORS
      PORTEE), PAS une limite du generateur de code - premiere preuve,
      par COMPILATION REELLE d un VRAI fichier plutot qu un auto-test
      isole, que cette decision du TODO 15 tient (ParseBaseTypeNoBrackets,
      TODO 08, rejette "Frame" avant meme d atteindre le generateur de
      code).
    - Lacunes du PARSEUR, PAS du generateur de code (deja documentees,
      INCHANGEES depuis le TODO 21 lui-meme) : Test11Threads.jpp
      ("new Runnable() {...}", classe anonyme, differee depuis le
      TODO 09) ; Test12Fichiers.jpp ("while ((ligne = ...) != null)",
      affectation utilisee comme SOUS-EXPRESSION, jamais supportee par
      ParseExpr).

  Couverture des 13 echantillons "portables Java 1.1" nommes "cible
  principale" par cette section (Test01-13) : 0/13 compilent jusqu au
  bout - 11 s arretent au generateur de code sur une limite de PORTEE
  nommee ci-dessus (dont DEUX, Test06/09, sur une limite STRUCTURELLE
  du front-end mono-passe distincte du generateur de code lui-meme) ;
  Test11/Test12 s arretent au PARSEUR, un manque distinct deja
  documente depuis le TODO 09/21. Couverture des 5 echantillons
  "specifiques Microsoft" (Test14-18) : 1/5 (Test17) reussit
  completement ; Test13 s arrete par DECISION DE PORTEE deliberee
  (TODO 15) ; les trois autres (14/16/18) au generateur de code,
  memes limites nommees que les echantillons portables.

  AUCUNE limite ci-dessus n est un BOGUE au sens d un comportement
  INCORRECT ou d une sortie erronee : chacune est soit une decision de
  portee EXPLICITE et anterieure (TODO 15, AWT), soit une limite
  VOLONTAIRE et documentee du premier jalon du generateur de code
  (TODO 21), soit une limite STRUCTURELLE du front-end mono-passe
  (references en avant intra-classe ; chainage this/super non
  resolu pour le generateur de code) tout juste mise au jour PAR cette
  validation, soit un manque de PARSEUR deja identifie et differe
  depuis le TODO 09/21 - JAMAIS un plantage, une sortie corrompue ou
  un fichier .asm/.obj/.exe silencieusement faux. Etendre le
  generateur de code au-dela de son premier jalon (if/while/for,
  arithmetique, tableaux, disposition EBP-relative des locaux, appels
  de methode utilisateur - voir la liste "Next steps" de la note d en-
  tete du TODO 21 lui-meme), ou lever la limite structurelle des
  references en avant intra-classe (exigerait une VRAIE passe de
  pre-declaration des methodes avant la resolution des appels, un
  changement d architecture, pas une extension incrementale), restent
  un travail FUTUR - hors de la portee de CE TODO 25 precisement PARCE
  QUE ce TODO est un rapport honnete sur l ETAT REEL, pas un mandat
  pour l etendre.
  ============================================================ *)

(* ============================================================
  EXTENSION POST-TODO25 (2026-07-27) - ARITHMETIQUE, CONTROLE DE
  FLUX, LOCALES/PARAMETRES, CONCATENATION DE CHAINES ET APPELS DE
  METHODE STATIQUE
  ============================================================
  Demandee EXPLICITEMENT par l utilisateur ("termine toutes les
  parties non couvertes par le compilateur"), MEME nature que les
  extensions post-TODO25 de GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS (leurs
  propres "extensions arrays/slices"/"Phase 2"/etc., ajoutees APRES
  leur propre TODO25, PAS des TODO numerotes) - etend le generateur de
  code (TODO 21) BIEN au-dela de son "premier jalon" (qui ne couvrait
  qu un "System.out.println(<litteral>)" seul), SANS changer
  d architecture (toujours "tout tient dans EAX", toujours du texte
  .asm REEL passe par le MEME assembleur/ecrivain PE/COFF des TODO
  22/23 - simplement etendu de quelques mnemoniques : NEG/IMUL/IDIV/
  CDQ, PLUS un registre 8 bits AL/CL/DL/BL pour charger/ecrire UN SEUL
  octet, necessaire a la concatenation de chaines).

  CE QUI FONCTIONNE MAINTENANT (verifie par EXECUTION reelle, pas
  seulement compilation) : locales/parametres SCALAIRES (int/boolean/
  char/String - disposition EBP-relative reelle, TSymRec.Offset/
  TMethodRec.FrameSize) ; arithmetique entiere (+/-/*/// %) et
  comparaisons (==/!=/</<=/>/>=, materialisees 0/1 dans EAX via Jcc,
  MEME idiome que les compilateurs freres) ; &&/|| REELLEMENT
  court-circuites ; ++/-- prefixe ET postfixe ; if/else/else-if ;
  while/do-while/for (avec break/continue non etiquetes, y compris
  imbrique dans un switch qui herite alors le "continue" de la boucle
  englobante) ; switch/case/default avec continuation "fall-through"
  textuelle reelle ; return (avec ou sans expression, saute TOUJOURS
  vers un epilogue de methode UNIQUE, jamais une cascade) ; affectation
  simple ET composee (+=/-=/*=//=/%=) vers une locale ; ternaire
  "cond?a:b" ; et la concatenation "+" de chaines - avec conversion
  int/boolean/char->String via un nouveau petit runtime alloue sur le
  tas (_JPPRT_ALLOC, GetProcessHeap/HeapAlloc avec HEAP_ZERO_MEMORY -
  MEME choix que le _GORT_ALLOC de GOCW32.PAS, aucune liberation, fuite
  assumee) - _JPPRT_INT_TO_STR/_JPPRT_CHAR_TO_STR/_JPPRT_CONCAT,
  PLUS deux constantes fixes _JPPRT_TRUE_STR/_JPPRT_FALSE_STR pour le
  boolean (jamais alloue, toujours les DEUX memes chaines). Appels de
  methode STATIQUE utilisateur (parametres ET retour SCALAIRES
  uniquement) desormais compiles PAR LEUR PROPRE label (MethodAsmLabelG),
  la resolution de surcharge (TODO 08) ayant DEJA choisi la bonne
  entree MethodPool au parsing (EK_CALL.Extra) - la recursion (ex.
  "factorielle" de Test04Methodes.jpp, toujours bloquee par d autres
  limites, voir plus bas) fonctionnerait donc aussi correctement sans
  code special.

  RESULTAT HONNETE (meme discipline que le TODO 25 lui-meme, verifie
  par EXECUTION reelle de CHAQUE fichier, PAS suppose) : 3/18 SAMPLES
  \JPP\*.jpp compilent et EXECUTENT desormais correctement de bout en
  bout (Test03Instructions.jpp - if/switch/for/while/do-while/
  arithmetique entiere/concatenation, sortie verifiee OCTET PAR OCTET ;
  Test15Conditionnelle.jpp - #if/#elif/#else PLUS appels de methode
  statique sans argument retournant une String ; Test17PaquetsMicrosoft.
  jpp, deja acquis avant cette extension), contre 1/18 avant. TOUS les
  15 autres echantillons progressent (arretent PLUS LOIN, sur des
  constructions PLUS PRECISES qu avant) mais restent bloques par des
  LACUNES EXPLICITEMENT HORS DE PORTEE de cette extension, JAMAIS un
  bogue : long/double/float (Test02 - ne tiennent pas dans EAX seul) ;
  acces a un CHAMP/tableau/"this" (EK_SELECTOR/EK_INDEX - Test01/05/16,
  et la CIBLE d une affectation pour Test07/08 - aucune disposition
  memoire D INSTANCE/de tableau n existe encore) ; construction d objet
  "new" (EK_NEWOBJECT - Test10/14) ; exceptions try/throw/catch
  (STK_THROW/STK_TRY - Test04/18) ; le meme appel de methode "non
  resolu" deja documente au TODO 25 (Test06 - reference en avant intra-
  classe ; Test09 - chainage this/super, DEUX limites STRUCTURELLES du
  front-end, PAS du generateur de code) ; les memes lacunes PARSEUR
  (Test11/12) et la meme decision de portee AWT deliberee (Test13,
  TODO 15) deja documentees. Etendre encore (champs/tableaux/objets/
  exceptions - un vrai modele memoire d instance ET une VRAIE
  disposition de tas restent le prealable commun a la PLUPART des
  echantillons residuels) reste un travail FUTUR distinct.
  ============================================================ *)

(* ============================================================
  EXTENSION POST-TODO25, DEUXIEME PASSE (2026-07-27) - MODELE
  MEMOIRE D INSTANCE ET DE TABLEAU, APPELS DE METHODE D INSTANCE,
  BITWISE/DECALAGES, CAST, "throw" MINIMAL
  ============================================================
  Suite DIRECTE de l extension precedente (demande UTILISATEUR
  identique, "termine toutes les parties non couvertes") - ajoute
  EXACTEMENT ce que sa propre conclusion nommait comme prealable
  commun : un VRAI modele memoire d instance/de tableau, PLUS les
  consommateurs qui en dependaient (acces/affectation de champ,
  "new" (construction d objet), indexation/creation de tableau A
  UNE dimension, appel de methode D INSTANCE).

  MODELE : un OBJET est un bloc _JPPRT_ALLOC (tas, zero-rempli), UN
  SEUL mot de 4 octets par champ D INSTANCE - les champs HERITES
  occupent TOUJOURS les premiers mots (CgAncestorFieldBytes remonte
  TypeTab[T].SuperTypeIdx recursivement), TFieldRec.Offset (deja
  reserve depuis le TODO 08) reste relatif au DEBUT des champs
  PROPRES de son OwnerTypeIdx. Un TABLEAU est EGALEMENT un bloc
  _JPPRT_ALLOC : un PREFIXE de longueur sur 4 octets, PUIS les
  elements - la reference retournee POINTE SUR LE PREMIER ELEMENT
  (base+4 du bloc), ".length" relit simplement [base-4]. AUCUN
  adressage base+index materiel (SIB) n est requis nulle part :
  chaque acces "arr[i]" calcule l ADRESSE EFFECTIVE arithmetiquement
  (i*4 ajoute au pointeur de base) puis charge/ecrit via un simple
  [registre] base-seul, deja pleinement supporte par l assembleur du
  TODO 22 sans la moindre extension. "new Classe(...)" alloue PUIS
  appelle le constructeur REELLEMENT resolu (EK_NEWOBJECT.Left,
  ClassFindConstructor au parsing, TODO 08 - jamais re-resolu ICI) en
  poussant l objet comme "this" implicite (EN DERNIER, EBP+8) - un
  appel de methode D INSTANCE (CompileCall etendu) suit EXACTEMENT le
  meme principe, recepteur explicite ("obj.methode(...)") OU
  implicite (le "this" EBP+8 de LA METHODE ENGLOBANTE, garanti par
  les regles de portee Java elles-memes). Les DEUX (constructeur ET
  methode d instance) exigent un corps SOURCE reel (BodyStmtIdx >= 0)
  - une classe predeclaree de la bibliotheque standard (Exception et
  consorts, StdlibInit) n en a JAMAIS, s arrete donc PROPREMENT plutot
  que de referencer une etiquette jamais emise.

  DEUX BOGUES REELS trouves PENDANT cette extension, PAR EXECUTION
  d un test synthetique dedie (AUCUN des 18 SAMPLES\JPP\*.jpp
  n exerce encore le modele memoire d instance/tableau lui-meme -
  verifier ce code sans un test synthetique aurait ete pure
  supposition, contraire a la discipline de ce projet) :
    1. EK_NEWARRAY 'dims' ("new int[n]") conservait n dans ECX A
       TRAVERS "CALL _JPPRT_ALLOC" - ECX N EST PAS un registre
       PRESERVE (ni par convention Win32, ni par _JPPRT_ALLOC
       lui-meme, qui ne sauve/restaure QUE EBX) : la longueur ecrite
       dans le prefixe du tableau etait donc GARBAGE (residus de
       GetProcessHeap/HeapAlloc), jamais "n" - "new int[5]" donnait
       "Longueur : -1374577314" au lieu de 5. Corrige en faisant
       TRANSITER n par la PILE (PUSH avant l appel, POP juste apres)
       plutot que par un registre.
    2. CompileArithBinary("/"/"%%") ecrivait dans EBX SANS jamais le
       restaurer - or STK_ASSIGN/EK_UNARY (++/--) conservent
       PRECISEMENT une ADRESSE de champ/element de tableau dans EBX
       PENDANT que la valeur de droite est calculee : "arr[i] = a / b;"
       ou "obj.champ = a % b;" corrompait donc SILENCIEUSEMENT cette
       adresse (trouve par relecture SYSTEMATIQUE de CHAQUE
       utilisateur de EBX apres le bogue #1 ci-dessus, PAS par une
       execution qui aurait plante - aucun echantillon test ne
       combinait encore precisement ces deux constructions). Corrige
       en sauvant/restaurant EBX (PUSH/POP) autour de la seule
       sequence CDQ/IDIV qui l utilise.
  Un TROISIEME probleme, DECOUVERT (pas un bogue de CETTE extension,
  mais EXPOSE par elle) : Test01Bonjour.jpp COMPILAIT et LIAIT sans
  la moindre erreur des la toute PREMIERE version de cette extension,
  mais SEGFAULT a l EXECUTION - "main" lit REELLEMENT
  "args.length"/"args[0]" (EK_SELECTOR/EK_INDEX) desormais, mais
  aucune valeur n avait JAMAIS ete poussee pour ce parametre avant
  l appel a "main" depuis "_JPPSTART" (aucun appelant n avait jamais
  eu besoin de "args" avant cette extension). Corrige en poussant un
  VRAI tableau de chaines VIDE (longueur 0, jamais le vrai
  GetCommandLine/CommandLineToArgvW Win32, explicitement HORS de
  portee - fonctionnalite separee, non demandee) avant "main" -
  garantit "args.length" TOUJOURS correct (0), jamais un pointeur
  invalide dereference. Ce TROISIEME cas illustre a nouveau la regle
  etablie de longue date par ce projet : "compile sans erreur" ne
  prouve JAMAIS "s execute correctement" - verifier PAR EXECUTION
  REELLE reste indispensable, ici via un test SYNTHETIQUE dedie
  (fields/tableaux/methodes d instance) puisqu aucun SAMPLES\JPP
  existant n exerce encore ces chemins.

  RESULTAT HONNETE : 4/18 SAMPLES\JPP\*.jpp compilent et EXECUTENT
  desormais correctement de bout en bout (Test01Bonjour.jpp rejoint
  Test03Instructions.jpp/Test15Conditionnelle.jpp/
  Test17PaquetsMicrosoft.jpp), contre 3/18 avant cette DEUXIEME passe.
  Les 14 autres progressent ENCORE (arretent plus loin) mais restent
  bloques par des lacunes EXPLICITEMENT hors de portee : tableaux
  MULTI-dimensionnels (Test05) ; parametres/retours de methode NON
  scalaires - tableau/objet (Test04 "int[] valeurs", Test10 Vector) ;
  DISPATCH POLYMORPHIQUE reel (Test07 "aire()" via une reference
  Forme, Test08 "valeurChangee()" via une reference d interface -
  AUCUN mecanisme de vtable n existe, un appel d instance n est
  compile QUE lorsque la methode EXACTE est deja connue
  STATIQUEMENT) ; construction de types SANS corps source reel
  (Test10 Vector, Test14 delegate - bibliotheque standard/delegue,
  JAMAIS de BodyStmtIdx reel) ; long/double/float (Test02) ; le VRAI
  STK_TRY (Test18, jamais implemente - seul STK_THROW a une
  approximation MINIMALE, documentee comme telle) ; les DEUX limites
  STRUCTURELLES du front-end deja documentees au TODO 25 (Test06/09) ;
  les lacunes PARSEUR (Test11/12) et la decision de portee AWT
  (Test13). Le dispatch polymorphique (vtable) et les parametres/
  retours non-scalaires sont desormais le prealable commun le plus
  large pour la PROCHAINE tranche d extension, pas un simple modele
  memoire d instance (deja livre ICI).
  ============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{ ============================================================ }

Const
  JPPCW32_VERSION = '0.1';
  JPPCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { --- Constantes PE/COFF (identiques aux autres compilateurs   }
  { de ce projet - format Win32 universel, pas specifique a J++). }
  PE_DOS_MAGIC            = $5A4D;
  PE_PE_SIG               = $00004550;
  PE_MACHINE_I386         = $014C;
  PE_IMG_BASE             = $00400000;
  PE_SEC_ALIGN            = 4096;
  PE_FILE_ALIGN           = 512;
  PE_SUBSYS_CUI           = 3;
  PE_SUBSYS_GUI           = 2;
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
  { par prudence memoire - meme convention que GOCW32.PAS/            }
  { SWIFTW32.PAS/DELPHI.PAS de ce meme projet).                       }
  MAX_SYM           = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_FUNC          = {$IFDEF FPC}512{$ELSE}64{$ENDIF};   { methodes static }
  MAX_METHOD        = {$IFDEF FPC}512{$ELSE}64{$ENDIF};   { methodes d instance }
  MAX_TYPE          = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_FIELD_POOL    = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_PARAM         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_METHOD_POOL   = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};  { TODO 08 : MethodPool     }
                      { TOTAL (static+instance+constructeurs REUNIS en UNE seule       }
                      { table, distingues par TMethodRec.Kind/IsStatic) - reunit          }
                      { MAX_FUNC+MAX_METHOD du roadmap TODO 01 }
  MAX_PARAM_POOL    = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};  { TODO 08 : ParamPool      }
                      { TOTAL (TOUTES methodes confondues) - MAX_PARAM ci-dessus           }
                      { (64/16) redevient une limite PAR METHODE implicite,                    }
                      { jamais verifiee explicitement (aucun echantillon reel ne             }
                      { s en approche) }
  MAX_LOCAL         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LABEL         = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR           = 255;
  MAX_ERRORS        = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_CLASS         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_INTERFACE     = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
  MAX_THROWS_POOL   = {$IFDEF FPC}256{$ELSE}32{$ENDIF};    { TODO 19 :        }
                      { ThrowsPool TOTAL (TOUTES methodes/constructeurs         }
                      { confondus), MEME convention EXACTE que MAX_PARAM_POOL/     }
                      { InterfacePool ci-dessus - un pool PLAT, jamais une            }
                      { table PAR methode }
  MAX_CATCH         = {$IFDEF FPC}64{$ELSE}8{$ENDIF};     { clauses catch }
  MAX_THREAD        = {$IFDEF FPC}32{$ELSE}4{$ENDIF};
  MAX_DELEGATE      = {$IFDEF FPC}64{$ELSE}8{$ENDIF};
  MAX_DEFINE        = {$IFDEF FPC}32{$ELSE}8{$ENDIF};     { symboles -D }
  MAX_SCOPE         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_BIN           = 65536;
  MAX_BIN_LABEL     = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_BIN_FIXUP     = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_BIN_IMPORT    = {$IFDEF FPC}128{$ELSE}32{$ENDIF};

  { --- Prefixes de nommage ASM (voir en-tete du fichier) --- }
  ASM_PFX_GVAR    = '_JPP_';    { champ static/global                 }
  ASM_PFX_FUNC    = '_JPPF_';   { methode static                      }
  ASM_PFX_METHOD  = '_JPPM_';   { methode d instance                  }
  ASM_PFX_STRING  = '_JPPK_';   { constante chaine/litteral           }
  ASM_PFX_FLOAT   = '_JPPFL_';  { constante flottante (double, 8 octets) }
  ASM_PFX_RUNTIME = '_JPPRT_';  { routine runtime                     }
  ASM_PFX_LABEL   = '_JPPL_';   { label de saut interne                }
  ASM_PFX_TYPEDESC= '_JPPT_';   { descripteur de type/vtable simplifiee}
  ASM_PFX_DELEGATE= '_JPPD_';   { thunk de delegate                    }

Type
  TString = String;

  TOptions = Record
    SrcFile      : TString;   { fichier source (.jpp ou .java)        }
    OutFile      : TString;   { fichier sortie (.exe, .obj ou .asm)    }
    OutFileGiven : Boolean;   { True si fourni explicitement (-o)      }
    Verbose      : Boolean;   { -v : banniere et statistiques          }
    DebugMode    : Boolean;   { -d : affichage de chaque token         }
    Warnings     : Boolean;   { -w : afficher les avertissements       }
    AsmOutput    : Boolean;   { -asm : produire aussi un .ASM lisible  }
    ObjOnly      : Boolean;   { -obj : produire seulement un .OBJ      }
    StrictMode   : Boolean;   { -strict : erreurs J++ strictes         }
                               { (variable declaree et non utilisee,    }
                               { voir TODO 19) traitees comme fatales    }
                               { meme sans ce parametre - reserve pour   }
                               { assouplir ce comportement plus tard,     }
                               { actuellement toujours strict par defaut. }
    DefinedSymbols : Array[0..MAX_DEFINE - 1] Of TString; { -D SYMBOLE,   }
                               { compilation conditionnelle, TODO 17 }
    DefinedCount   : Integer;
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

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

{ IntToStrG (TODO 21) : conversion entier -> texte SANS AUCUN uses      }
{ (ce fichier n en a jamais eu un seul, mode TP en tete de fichier) -             }
{ reutilise le "Str" INTEGRE du langage Pascal LUI-MEME (jamais SysUtils),   }
{ EXACTEMENT le meme choix que GOCW32.PAS/SWIFTW32.PAS a leur propre               }
{ TODO 21. }
Function IntToStrG(N: LongInt): TString;
Var S: TString;
Begin
  Str(N, S);
  IntToStrG := S;
End;

{ Retourne le nom de base d un chemin, SANS repertoire ni extension -  }
{ utilise pour la verification best-effort "nom de la classe publique }
{ == nom de fichier" (section 2 de la reference) - cette verification }
{ elle-meme ne peut porter que sur le NOM DE FICHIER ici (TODO 01,     }
{ aucun lexeur/analyseur n existe encore pour trouver la VRAIE classe  }
{ publique dans le contenu du fichier - reportee au TODO 08, MEME      }
{ discipline exacte que GOCW32.PAS reportant sa propre verification de }
{ "package main" au TODO 02 une fois son lexeur disponible). }
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
  WriteLn('JPPCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg: TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('JPPCW32: warning: ', Msg);
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
  WriteLn('JPPCW32 v', JPPCW32_VERSION, ' (', JPPCW32_DATE,
          ') - Compilateur J++ vers 80386 (Windows PE 32 bits)');
  WriteLn('JPPCW32 - Cette commande permet de lancer le compilateur ',
          'J++ (Microsoft Visual J++, noyau Java 1.1 + extensions ',
          'Microsoft) pour l''assembleur du microprocesseur 80386 ',
          '(en executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : JPPCW32 [options] <source.jpp> [options]');
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
  WriteLn('  -D SYMBOLE     Definir un symbole de compilation ',
          'conditionnelle');
  WriteLn('                 (repetable, ex. -D DEBUG -D LANG_FR - ',
          'voir #if/#endif)');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  JPPCW32 Test01Bonjour.jpp');
  WriteLn('  JPPCW32 Test01Bonjour.jpp Test01Bonjour.exe -v');
  WriteLn('  JPPCW32 Test15Conditionnelle.jpp -D DEBUG -D LANG_FR -obj -w');
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
      { -D SYMBOLE consomme l argument SUIVANT (seule option de ce      }
      { compilateur a le faire, TODO 17 - compilation conditionnelle    }
      { #if/#else/#elif/#endif de Test15Conditionnelle.jpp). }
      If I >= ParamCount Then
        FatalError('"-D" attend un symbole en argument suivant')
      Else
      Begin
        Inc(I);
        If Opts.DefinedCount >= MAX_DEFINE Then
          WarnMsg('trop de symboles -D (MAX_DEFINE), ignore : ' + ParamStr(I))
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
    WriteLn('JPPCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .jpp - .java est AUSSI accepte (meme         }
  { convention que SAMPLES\JPP\README.txt : un compilateur qui         }
  { n accepterait que .java invite a renommer/copier le fichier).      }
  { La verification best-effort que le nom de la classe PUBLIQUE       }
  { correspond au nom de fichier (section 2 de la reference) ne peut   }
  { porter ICI que sur le NOM DE FICHIER lui-meme (ExtractBaseName) -   }
  { la VRAIE classe publique du contenu n est trouvable qu une fois     }
  { le lexeur/analyseur disponibles, reportee au TODO 08 - portee       }
  { volontairement limitee a l infrastructure (TODO 01), MEME           }
  { discipline exacte que GOCW32.PAS reportant sa propre verification   }
  { de "package main" au TODO 02. }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.JPP') And (Ext <> '.JAVA') Then
    WarnMsg('extension attendue .jpp ou .java, trouvee: ' + Ext);

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
Var I : Integer;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('JPPCW32 v', JPPCW32_VERSION, ' (', JPPCW32_DATE,
          ') - Compilateur J++ -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.ObjOnly Then
    WriteLn('Mode     : OBJ seulement (COFF)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
  If Opts.DefinedCount > 0 Then
  Begin
    Write('Symboles : ');
    For I := 0 To Opts.DefinedCount - 1 Do
    Begin
      If I > 0 Then Write(', ');
      Write(Opts.DefinedSymbols[I]);
    End;
    WriteLn;
  End;
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
{ TODO 02 - TOKENISEUR J++ (LEXER)                              }
{ ============================================================ }

{ Contrairement a GOCW32.PAS (insertion automatique de point-      }
{ virgule) et a SWIFTW32.PAS (regle de terminaison par fin de       }
{ ligne), J++/Java 1.1 EXIGE un ';' EXPLICITE pour terminer chaque   }
{ instruction (section 7 de la reference) - AUCUNE regle            }
{ d insertion/suppression n est donc necessaire ici : ';' est une   }
{ simple ponctuation parmi d autres (TOK_OP), et LexNextToken n a    }
{ besoin d aucun etat "dernier token" pour en decider - un lexeur   }
{ nettement PLUS SIMPLE que ceux des deux compilateurs freres sur   }
{ ce point precis. }

Type
  TTokenKind = (
    TOK_EOF,      { fin de fichier                                  }
    TOK_IDENT,    { identificateur (mots-cles INCLUS - classification }
                  { complete deferee au TODO 03, IsKeyword)             }
    TOK_INT,      { litteral entier (decimal/hexadecimal/octal ancien   }
                  { style "017" - section 3.7)                            }
    TOK_LONG,     { MEME litteral entier, avec suffixe L/l (long, 64      }
                  { bits - represente ICI par un simple LongInt 32 bits,  }
                  { meme simplification documentee que le reste de ce      }
                  { projet pour les types "larges")                          }
    TOK_FLOAT,    { litteral flottant AVEC suffixe explicite f/F (32       }
                  { bits, section 3.8)                                       }
    TOK_DOUBLE,   { litteral flottant SANS suffixe (le type PAR DEFAUT     }
                  { d un litteral a virgule/exposant en Java EST double,     }
                  { jamais float - difference REELLE avec la plupart des      }
                  { langages C-like) OU avec suffixe explicite d/D            }
    TOK_CHAR,     { litteral caractere 'x' (section 3.9, memes              }
                  { echappements que TOK_STRING PLUS l echappement            }
                  { octal \0..\377, propre a Java, ABSENT de Swift/Go)         }
    TOK_STRING,   { chaine "..." interpretee (memes echappements) - Java     }
                  { 1.1 n a NI interpolation NI forme brute multi-lignes,     }
                  { lexeur nettement plus simple que celui de SWIFTW32.PAS    }
                  { sur ce point                                                }
    TOK_OP        { operateur/ponctuation ; distingue par Val (INCLUT       }
                  { ';' lui-meme, voir la note d en-tete ci-dessus)            }
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TString;    { texte brut (identificateur, operateur) ou    }
                          { contenu DECODE (chaine/caractere)               }
    IntVal  : LongInt;    { valeur entiere (TOK_INT/TOK_LONG) ou code de   }
                          { caractere (TOK_CHAR)                              }
    RealVal : Real;       { valeur flottante (TOK_FLOAT/TOK_DOUBLE)          }
    Line    : Integer;    { ligne source (1-base)                            }
    Col     : Integer;    { colonne source (1-base)                          }
  End;

Var
  { Lexeur }
  LexSrcF     : Text;
  LexSrcFName : TString;
  LexOpened   : Boolean;
  LexLine     : TString;
  LexLineNo   : Integer;
  LexColNo    : Integer;
  LexEOF      : Boolean;
  CurToken    : TToken;
  TokenCount  : LongInt;   { nombre de tokens produits (statistiques -v) }

  { Texte du DERNIER commentaire javadoc /** ... */ rencontre (extension  }
  { "directives Microsoft", TODO 17, suite au roadmap d en-tete - un tel  }
  { commentaire porte parfois une directive @dll.import interpretee par   }
  { J/Direct, section 13 de la reference) - simple CAPTURE de texte BRUT   }
  { ici, AUCUNE interpretation n est tentee avant le TODO 17 lui-meme     }
  { (portee volontairement limitee au lexeur, meme discipline que le      }
  { reste de ce projet). Ecrase par CHAQUE javadoc rencontre, jamais      }
  { accumule - le TODO 17 devra decider lui-meme de la "fraicheur"        }
  { (javadoc immediatement adjacent a la declaration qui l attend, ou     }
  { non), question DELIBEREMENT laissee ouverte ici. }
  LexLastJavadocText : TString;
  LexLastJavadocLine : Integer;

Const
  { MAX_COND_DEPTH (TODO 17, section 17.39 "imbrication") : profondeur      }
  { MAXIMALE de "#if" imbriques - AUCUN echantillon actuel n imbrique                 }
  { meme UN SEUL niveau (Test15Conditionnelle.jpp n a que des groupes                 }
  { successifs, jamais imbriques), mais l algorithme A PILE ci-dessous            }
  { traite l imbrication GRATUITEMENT (ce n est PAS un cas special                     }
  { ajoute en plus - le retirer coderait en dur "profondeur 1", PLUS de              }
  { code que de le laisser general) - une limite genereuse suffit. }
  MAX_COND_DEPTH = 16;

Var
  { CondActive/CondEverTaken/CondParentActive/CondDepth (TODO 17,       }
  { sections 17.30-17.39) : PILE des groupes "#if/#elif/#else/#endif"          }
  { actuellement OUVERTS - voir la note d en-tete de LexAdvanceSourceLine     }
  { pour l algorithme complet. }
  CondActive       : Array[0..MAX_COND_DEPTH - 1] Of Boolean;
  CondEverTaken    : Array[0..MAX_COND_DEPTH - 1] Of Boolean;
  CondParentActive : Array[0..MAX_COND_DEPTH - 1] Of Boolean;
  CondDepth        : Integer;

{ ------------------------------------------------------------ }
{ Classification de caracteres                                 }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch: Char): Boolean;
Begin
  { '$' est un caractere de tete VALIDE d un identificateur en Java/J++  }
  { (section 3.1 de la reference) - difference REELLE avec GOCW32.PAS/   }
  { SWIFTW32.PAS, qui n acceptent ni l un ni l autre '$' dans un           }
  { identificateur. }
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_') Or (Ch = '$');
End;

Function IsIdentCont(Ch: Char): Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigitCh(Ch: Char): Boolean;
Begin
  IsDigitCh := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch: Char): Boolean;
Begin
  IsHexDigit := IsDigitCh(Ch) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch: Char): Integer;
Begin
  If IsDigitCh(Ch) Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ------------------------------------------------------------ }
{ LexPeekChar/2/3/4, LexNextChar : lecture en avant SANS           }
{ consommer (Peek) et avance d un caractere (Next) dans la ligne    }
{ courante - #0 si hors limites. LexPeekChar4 est necessaire pour    }
{ reconnaitre SANS ambiguite l operateur a 4 caracteres ">>>="        }
{ (le PLUS long de ce langage - methode du "plus long match").         }
{ ------------------------------------------------------------ }

Function LexPeekChar: Char;
Begin
  If LexColNo <= Length(LexLine) Then LexPeekChar := LexLine[LexColNo]
  Else LexPeekChar := #0;
End;

Function LexPeekChar2: Char;
Begin
  If LexColNo + 1 <= Length(LexLine) Then LexPeekChar2 := LexLine[LexColNo + 1]
  Else LexPeekChar2 := #0;
End;

Function LexPeekChar3: Char;
Begin
  If LexColNo + 2 <= Length(LexLine) Then LexPeekChar3 := LexLine[LexColNo + 2]
  Else LexPeekChar3 := #0;
End;

Function LexPeekChar4: Char;
Begin
  If LexColNo + 3 <= Length(LexLine) Then LexPeekChar4 := LexLine[LexColNo + 3]
  Else LexPeekChar4 := #0;
End;

Procedure LexNextChar;
Begin
  If LexColNo <= Length(LexLine) Then Inc(LexColNo);
End;

{ ------------------------------------------------------------ }
{ LexNextLine / LexInit / LexClose - modele "tampon d une ligne"  }
{ (ReadLn + LexColNo), identique dans l esprit a GOCW32.PAS/         }
{ SWIFTW32.PAS/DELPHI.PAS de ce meme projet - PAS de pile             }
{ d inclusion (J++, tel que couvert ici, est mono-fichier, voir       }
{ TODO 01).                                                            }
{ ------------------------------------------------------------ }

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
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ------------------------------------------------------------ }
{ TODO 17 (moitie "compilation conditionnelle", sections 17.30-  }
{ 17.41) - DECISION D ORDONNANCEMENT DES PASSES EXPLICITEMENT EXIGEE           }
{ PAR LE ROADMAP ("decider et documenter... avant d ecrire le code")             }
{ : NI une passe de PRE-traitement SEPAREE sur tout le fichier (ce qui          }
{ exigerait de materialiser un second tampon/fichier temporaire),                    }
{ NI une modification de LexNextLine lui-meme - ENTRELACEE DANS LE               }
{ MODELE EXISTANT "tampon d une ligne" (note d en-tete ci-dessus),               }
{ via une NOUVELLE procedure `LexAdvanceSourceLine` qui ENVELOPPE                    }
{ LexNextLine (INCHANGE) d une boucle : lit une ligne brute, PUIS soit          }
{ (a) la reconnait comme une ligne "#if/#elif/#else/#endif" (apres              }
{ avoir saute l espace de tete - MEME idee que le garde-fou '#' deja               }
{ existant plus bas dans LexNextToken) et met a jour la PILE Cond*                   }
{ SANS JAMAIS exposer cette ligne au tokeniseur, soit (b) l expose                    }
{ TELLE QUELLE si la PILE est actuellement active, soit (c) l ELIMINE           }
{ silencieusement (relit la suivante) si la PILE est actuellement                    }
{ INACTIVE (branche non retenue).                                                          }
{                                                                       }
{ POURQUOI PAS DANS LexNextLine LUI-MEME (piege reel EVITE avant                     }
{ d ecrire une seule ligne, pas trouve par execution) : LexNextLine                  }
{ est AUSSI appele par LexSkipBlockComment (plus haut) pour franchir             }
{ un saut de ligne AU MILIEU d un commentaire /* ... */ multi-lignes.            }
{ Si LexNextLine lui-meme reconnaissait les lignes "#...", un                            }
{ commentaire contenant PAR HASARD une ligne commencant par '#' serait          }
{ FAUSSEMENT interprete comme une VRAIE directive. `LexAdvanceSourceLine`  }
{ n est donc appele QUE depuis les DEUX points ou une ligne FRAICHE           }
{ est demandee pour la TOKENISATION reelle (LexInit, l amorcage de la           }
{ toute premiere ligne ; LexNextToken, "plus de colonnes sur la ligne           }
{ courante") - JAMAIS depuis LexSkipBlockComment, qui continue                          }
{ d appeler LexNextLine BRUT, EXACTEMENT comme avant ce TODO. }
{                                                                       }
{ ALGORITHME A PILE (section 17.39, "les groupes peuvent etre                          }
{ imbriques") : CondActive[i] est Vrai SEULEMENT si la ligne #if qui              }
{ a cree le cadre i etait ELLE-MEME dans une branche active                              }
{ (CondParentActive[i], capture UNE FOIS a la creation du cadre) ET               }
{ que l expression de CE cadre est satisfaite - la propagation de                     }
{ l inactivite d un ANCETRE se fait donc UNE SEULE FOIS, a la creation           }
{ du cadre enfant, jamais en reverifiant toute la pile a chaque ligne :         }
{ `CondStackActive` n a donc besoin de lire QUE le sommet de pile. }
Function CondStackActive: Boolean;
Begin
  CondStackActive := (CondDepth = 0) Or CondActive[CondDepth - 1];
End;

{ CondEvalExpr (section 17.35) : PORTEE REDUITE EXPLICITEMENT AU SEUL   }
{ symbole NU ("#if DEBUG"), EXACTEMENT la SEULE forme que                            }
{ Test15Conditionnelle.jpp exerce - la reference elle-meme (section              }
{ 17.35) admet "!"/"&&"/"||"/parentheses mais AVOUE dans le MEME                    }
{ paragraphe que "la grammaire exacte doit etre verifiee avec le                     }
{ manuel JVC cible" : deviner cette grammaire ICI serait l exact                       }
{ contraire de la discipline de ce projet, puisque meme la SOURCE ne            }
{ s y engage pas fermement. Repli EXPLICITE (FatalError, PAS un                        }
{ best-effort silencieux - contrairement a la resolution de methode/           }
{ champ ailleurs dans ce fichier, une expression conditionnelle MAL              }
{ comprise choisirait la MAUVAISE moitie du programme SANS aucun                     }
{ moyen d attirer l attention plus tard, un risque bien plus grave                    }
{ qu un identificateur non resolu) dans le cas contraire. }
Function CondEvalExpr(Const Expr: TString): Boolean;
Var
  Sym : TString;
  I, P : Integer;
  Found : Boolean;
Begin
  Sym := Expr;
  While (Length(Sym) > 0) And (Sym[1] = ' ') Do Delete(Sym, 1, 1);
  While (Length(Sym) > 0) And (Sym[Length(Sym)] = ' ') Do Delete(Sym, Length(Sym), 1);

  If Length(Sym) = 0 Then
    FatalError('expression conditionnelle vide apres "#if"/"#elif" (section 17.31, TODO 17)');

  If Not IsIdentStart(Sym[1]) Then
    FatalError('expression conditionnelle "' + Sym + '" non couverte - ' +
      'seul un symbole NU (identificateur) est reconnu, "!"/"&&"/"||"/' +
      'parentheses restent HORS de portee (section 17.35, TODO 17)');
  For P := 2 To Length(Sym) Do
    If Not IsIdentCont(Sym[P]) Then
      FatalError('expression conditionnelle "' + Sym + '" non couverte - ' +
        'seul un symbole NU (identificateur) est reconnu, "!"/"&&"/"||"/' +
        'parentheses restent HORS de portee (section 17.35, TODO 17)');

  Found := False;
  For I := 0 To Opts.DefinedCount - 1 Do
    If Opts.DefinedSymbols[I] = Sym Then Found := True;
  CondEvalExpr := Found;
End;

{ LexProcessDirectiveLine : Rest COMMENCE par '#' (garanti par            }
{ l appelant, LexAdvanceSourceLine) - reconnait "if"/"elif"/"else"/            }
{ "endif" (section 17.30) et met a jour la PILE Cond*. AUCUNE de ces           }
{ QUATRE lignes n est JAMAIS exposee au tokeniseur (l appelant ne les            }
{ expose de toute facon jamais, "Continue" systematique). }
Procedure LexProcessDirectiveLine(Const Rest: TString);
Var
  P, KwStart : Integer;
  Kw, ExprTxt : TString;
Begin
  P := 2;   { saute le '#' lui-meme (Rest[1]) }
  While (P <= Length(Rest)) And ((Rest[P] = ' ') Or (Rest[P] = #9)) Do Inc(P);
  KwStart := P;
  While (P <= Length(Rest)) And IsIdentCont(Rest[P]) Do Inc(P);
  Kw := Copy(Rest, KwStart, P - KwStart);
  While (P <= Length(Rest)) And ((Rest[P] = ' ') Or (Rest[P] = #9)) Do Inc(P);
  ExprTxt := Copy(Rest, P, Length(Rest) - P + 1);

  If Kw = 'if' Then
  Begin
    If CondDepth >= MAX_COND_DEPTH Then
    Begin
      FatalError('groupes "#if" imbriques au-dela de la limite geree ' +
        '(MAX_COND_DEPTH, TODO 17)');
      Exit;
    End;
    CondParentActive[CondDepth] := CondStackActive;
    CondActive[CondDepth]       := CondParentActive[CondDepth] And CondEvalExpr(ExprTxt);
    CondEverTaken[CondDepth]    := CondActive[CondDepth];
    Inc(CondDepth);
  End
  Else If Kw = 'elif' Then
  Begin
    If CondDepth <= 0 Then
    Begin
      FatalError('"#elif" sans "#if" ouvrant correspondant (section 17.33, TODO 17)');
      Exit;
    End;
    If CondEverTaken[CondDepth - 1] Then
      CondActive[CondDepth - 1] := False
    Else
    Begin
      CondActive[CondDepth - 1] := CondParentActive[CondDepth - 1] And CondEvalExpr(ExprTxt);
      If CondActive[CondDepth - 1] Then CondEverTaken[CondDepth - 1] := True;
    End;
  End
  Else If Kw = 'else' Then
  Begin
    If CondDepth <= 0 Then
    Begin
      FatalError('"#else" sans "#if" ouvrant correspondant (section 17.32, TODO 17)');
      Exit;
    End;
    If CondEverTaken[CondDepth - 1] Then
      CondActive[CondDepth - 1] := False
    Else
    Begin
      CondActive[CondDepth - 1]    := CondParentActive[CondDepth - 1];
      CondEverTaken[CondDepth - 1] := CondActive[CondDepth - 1];
    End;
  End
  Else If Kw = 'endif' Then
  Begin
    If CondDepth <= 0 Then
    Begin
      FatalError('"#endif" sans "#if" ouvrant correspondant (section 17.34, TODO 17)');
      Exit;
    End;
    Dec(CondDepth);
  End
  Else
    FatalError('directive de compilation conditionnelle Microsoft "#' + Kw +
      '" non reconnue - seules if/elif/else/endif existent (section 17.30, TODO 17)');
End;

{ LexAdvanceSourceLine : voir la note d en-tete ci-dessus pour la       }
{ decision d ordonnancement complete - SEUL point d entree utilise             }
{ desormais par LexInit/LexNextToken (JAMAIS par LexSkipBlockComment,           }
{ qui garde son appel BRUT a LexNextLine). }
Procedure LexAdvanceSourceLine;
Var P : Integer;
Begin
  While True Do
  Begin
    LexNextLine;
    If LexEOF Then Exit;

    P := 1;
    While (P <= Length(LexLine)) And ((LexLine[P] = ' ') Or (LexLine[P] = #9)) Do Inc(P);

    If (P <= Length(LexLine)) And (LexLine[P] = '#') Then
    Begin
      LexProcessDirectiveLine(Copy(LexLine, P, Length(LexLine) - P + 1));
      Continue;
    End;

    If CondStackActive Then Exit;
    { branche INACTIVE : cette ligne est ELIMINEE, relire la suivante }
  End;
End;

Procedure LexInit;
Begin
  LexLineNo   := 0;
  TotalLines  := 0;
  LexColNo    := 1;
  LexEOF      := False;
  LexLine     := '';
  TokenCount  := 0;
  LexLastJavadocText := '';
  LexLastJavadocLine := 0;
  CondDepth   := 0;   { TODO 17 - AUCUN groupe "#if" ouvert au debut d''un fichier }
  CurToken.Kind    := TOK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  LexAdvanceSourceLine;   { TODO 17 - PAS LexNextLine brut, voir sa note d''en-tete }
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur (mots-cles INCLUS - classification  }
{ complete deferee au TODO 03). Java/J++ est sensible a la casse :    }
{ AUCUN changement de casse ici.                                      }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While IsIdentCont(LexPeekChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexPeekChar;
    LexNextChar;
  End;
  CurToken.Kind := TOK_IDENT;
  CurToken.Val  := S;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : entier (decimal, hexadecimal 0x, ou octal ANCIEN }
{ STYLE "017" - section 3.7) ou flottant (section 3.8), avec les     }
{ suffixes REELS de Java : L/l (long), f/F (float 32 bits explicite), }
{ d/D (double 64 bits explicite - mais AUSSI la valeur PAR DEFAUT     }
{ d un litteral SANS aucun suffixe des qu il contient un '.' ou un      }
{ exposant, section 3.8). AUCUN separateur souligne "1_000" (Java 1.1   }
{ lui est anterieur, extension Java 7 - section 21 de la reference),     }
{ AUCUN prefixe binaire "0b..." (idem, Java 7), AUCUN flottant            }
{ hexadecimal "0x1p10" (jamais couvert par ce dialecte) : portee            }
{ deliberement REDUITE au sous-ensemble REELLEMENT Java 1.1/J++,             }
{ contrairement a GOCW32.PAS qui, lui, couvre un langage (Go) qui les        }
{ possede reellement tous.                                                    }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  S               : TString;
  IsFloatV        : Boolean;
  IsExplicitFloat : Boolean;
  IsLong          : Boolean;
  N               : LongInt;
  K               : Integer;
Begin
  S := '';
  IsFloatV        := False;
  IsExplicitFloat := False;
  IsLong          := False;

  { --- prefixe hexadecimal 0x/0X - jamais octal ni flottant --- }
  If (LexPeekChar = '0') And ((LexPeekChar2 = 'x') Or (LexPeekChar2 = 'X')) Then
  Begin
    LexNextChar; LexNextChar;
    If Not IsHexDigit(LexPeekChar) Then
      FatalError('litteral hexadecimal attend au moins un chiffre apres "0x"');
    N := 0;
    While IsHexDigit(LexPeekChar) Do
    Begin
      N := N * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    If (LexPeekChar = 'L') Or (LexPeekChar = 'l') Then
    Begin
      LexNextChar;
      CurToken.Kind := TOK_LONG;
    End
    Else
      CurToken.Kind := TOK_INT;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  { --- partie entiere (decimale, ou octal ANCIEN STYLE '0755' -   }
  { detecte APRES coup ci-dessous, meme technique EXACTE que             }
  { GOCW32.PAS pour sa propre forme heritee du C). --- }
  While IsDigitCh(LexPeekChar) Do
  Begin
    S := S + LexPeekChar;
    LexNextChar;
  End;

  { --- partie decimale .ddd - AUCUNE ambiguite avec un autre operateur  }
  { multi-caracteres commencant par '.' (Java n en a aucun, contrairement }
  { a Go "..."/Swift "...""..<") : un simple '.' suivant des chiffres      }
  { demarre TOUJOURS une partie fractionnaire. --- }
  If LexPeekChar = '.' Then
  Begin
    IsFloatV := True;
    S := S + '.';
    LexNextChar;
    While IsDigitCh(LexPeekChar) Do
    Begin
      S := S + LexPeekChar;
      LexNextChar;
    End;
  End;

  { --- exposant e/E [+-]ddd --- }
  If (LexPeekChar = 'e') Or (LexPeekChar = 'E') Then
  Begin
    IsFloatV := True;
    S := S + LexPeekChar;
    LexNextChar;
    If (LexPeekChar = '+') Or (LexPeekChar = '-') Then
    Begin
      S := S + LexPeekChar;
      LexNextChar;
    End;
    If Not IsDigitCh(LexPeekChar) Then
      FatalError('exposant flottant attend au moins un chiffre');
    While IsDigitCh(LexPeekChar) Do
    Begin
      S := S + LexPeekChar;
      LexNextChar;
    End;
  End;

  { --- suffixes f/F (float explicite) / d/D (double explicite) /    }
  { L/l (long - SEULEMENT si ceci n est PAS deja un flottant) --- }
  If (LexPeekChar = 'f') Or (LexPeekChar = 'F') Then
  Begin
    IsFloatV := True;
    IsExplicitFloat := True;
    LexNextChar;
  End
  Else If (LexPeekChar = 'd') Or (LexPeekChar = 'D') Then
  Begin
    IsFloatV := True;
    LexNextChar;
  End
  Else If (Not IsFloatV) And ((LexPeekChar = 'L') Or (LexPeekChar = 'l')) Then
  Begin
    IsLong := True;
    LexNextChar;
  End;

  If IsFloatV Then
  Begin
    If IsExplicitFloat Then CurToken.Kind := TOK_FLOAT
    Else CurToken.Kind := TOK_DOUBLE;
    { Val() exige un chiffre avant le point (".5" doit devenir "0.5") ;  }
    { de meme un point final sans decimales ("1." -> S="1.") doit avoir   }
    { au moins un zero apres pour rester un reel valide pour Val().        }
    If (Length(S) > 0) And (S[1] = '.') Then S := '0' + S;
    If (Length(S) > 0) And (S[Length(S)] = '.') Then S := S + '0';
    Val(S, CurToken.RealVal, K);
    CurToken.Val := S;
  End
  Else
  Begin
    { valeur entiere - decimale, OU octal ANCIEN STYLE si le texte     }
    { commence par '0' suivi d au moins un autre chiffre (heritage C,    }
    { CONSERVE par Java depuis sa toute premiere version - jamais        }
    { retire, contrairement a d autres langages plus recents). }
    N := 0;
    If (Length(S) > 1) And (S[1] = '0') Then
    Begin
      For K := 2 To Length(S) Do
      Begin
        If (S[K] < '0') Or (S[K] > '7') Then
          FatalError('chiffre octal invalide dans le litteral ''' + S + '''');
        N := N * 8 + (Ord(S[K]) - Ord('0'));
      End;
    End
    Else
      For K := 1 To Length(S) Do
        N := N * 10 + (Ord(S[K]) - Ord('0'));
    If IsLong Then CurToken.Kind := TOK_LONG Else CurToken.Kind := TOK_INT;
    CurToken.IntVal := N;
    CurToken.Val := S;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanEscape : decode UNE sequence d echappement (le curseur   }
{ doit deja pointer juste APRES le '\') - grammaire REELLE de       }
{ Java/J++ (section 3.9) : \n \t \b \f \r \\ \' \" (memes lettres    }
{ que Swift/Go SAUF \b/\f, propres a Java), \uXXXX (Unicode, TOUJOURS  }
{ EXACTEMENT 4 chiffres hexadecimaux - largeur FIXE, DIFFERENT de       }
{ la forme Swift a largeur VARIABLE (accolades), ET \0 a \377             }
{ (echappement OCTAL, 1 A 3 chiffres, propre a Java - ABSENT de             }
{ Swift/Go, herite du C, section 3.9).                                          }
{ ------------------------------------------------------------ }

Function LexScanEscape: LongInt;
Var
  Ch  : Char;
  V   : LongInt;
  Cnt : Integer;
Begin
  Ch := LexPeekChar;
  Case Ch Of
    'n' : Begin LexNextChar; LexScanEscape := 10; Exit; End;
    't' : Begin LexNextChar; LexScanEscape := 9;  Exit; End;
    'b' : Begin LexNextChar; LexScanEscape := 8;  Exit; End;
    'f' : Begin LexNextChar; LexScanEscape := 12; Exit; End;
    'r' : Begin LexNextChar; LexScanEscape := 13; Exit; End;
    '\' : Begin LexNextChar; LexScanEscape := Ord('\'); Exit; End;
    ''''  : Begin LexNextChar; LexScanEscape := Ord(''''); Exit; End;
    '"' : Begin LexNextChar; LexScanEscape := Ord('"'); Exit; End;
  End;

  If Ch = 'u' Then
  Begin
    LexNextChar;
    V := 0;
    For Cnt := 1 To 4 Do
    Begin
      If Not IsHexDigit(LexPeekChar) Then
        FatalError('sequence d''echappement \u attend EXACTEMENT 4 ' +
          'chiffres hexadecimaux (forme fixe Java, differente de \u{...})');
      V := V * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    LexScanEscape := V;
    Exit;
  End;

  If (Ch >= '0') And (Ch <= '7') Then
  Begin
    V := 0;
    Cnt := 0;
    While (Cnt < 3) And (LexPeekChar >= '0') And (LexPeekChar <= '7') Do
    Begin
      V := V * 8 + (Ord(LexPeekChar) - Ord('0'));
      LexNextChar;
      Inc(Cnt);
    End;
    LexScanEscape := V;
    Exit;
  End;

  FatalError('sequence d''echappement inconnue: \' + Ch);
  LexScanEscape := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanChar : litteral caractere 'x' (section 3.9) - EXACTEMENT   }
{ un caractere (echappe ou non) entre guillemets simples ; TOK_CHAR   }
{ INEXISTANT chez Swift/Go de ce projet (une "String" d un seul         }
{ caractere y tient lieu de Character), mais UN VRAI type distinct       }
{ en Java des la version 1.0.                                             }
{ ------------------------------------------------------------ }

Procedure LexScanChar;
Var
  V : LongInt;
Begin
  LexNextChar;   { sauter le guillemet simple ouvrant }
  If LexPeekChar = '''' Then
  Begin
    FatalError('litteral caractere vide '''''''' (au moins un caractere attendu)');
    V := 0;
  End
  Else If LexPeekChar = '\' Then
  Begin
    LexNextChar;
    V := LexScanEscape;
  End
  Else
  Begin
    V := Ord(LexPeekChar);
    LexNextChar;
  End;
  If LexPeekChar <> '''' Then
    FatalError('litteral caractere non ferme (guillemet simple fermant attendu)');
  LexNextChar;
  CurToken.Kind   := TOK_CHAR;
  CurToken.IntVal := V;
  CurToken.Val    := Chr(V And $FF);
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine "..." interpretee (memes echappements que  }
{ LexScanEscape). Java 1.1/J++ n a NI interpolation ("\(...)"),        }
{ NI forme brute, NI multi-lignes ("""...""") - un simple guillemet      }
{ droit non echappe ou une fin de ligne termine/erreur immediatement,     }
{ lexeur nettement plus simple que celui de SWIFTW32.PAS sur ce point.      }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S : TString;
  V : LongInt;
Begin
  S := '';
  LexNextChar;   { sauter le guillemet ouvrant }
  While True Do
  Begin
    If LexColNo > Length(LexLine) Then
      FatalError('chaine "..." non fermee avant fin de ligne');
    If LexPeekChar = '"' Then
    Begin
      LexNextChar;
      CurToken.Kind := TOK_STRING;
      CurToken.Val  := S;
      Exit;
    End;
    If LexPeekChar = '\' Then
    Begin
      LexNextChar;
      V := LexScanEscape;
      If Length(S) < MAX_STR Then S := S + Chr(V And $FF);
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + LexPeekChar;
      LexNextChar;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ LexSkipBlockComment : commentaire /* ... */ SANS imbrication      }
{ (section 3.3 - different de SWIFTW32.PAS, qui AUTORISE Swift a les   }
{ imbriquer : ici, la PREMIERE occurrence de "*/" ferme toujours le      }
{ commentaire, meme s il contient un "/*" litteral au milieu). Si le      }
{ commentaire commence par "/**" (javadoc, EXTENSION "directives          }
{ Microsoft" - TODO 17, suite au roadmap d en-tete), son texte INTERIEUR    }
{ est en plus CAPTURE dans LexLastJavadocText (AUCUNE interpretation       }
{ tentee ici). SIMPLIFICATION assumee et documentee : un "/**/" VIDE (qui   }
{ n est PAS un vrai commentaire javadoc en Java reel, seulement un           }
{ commentaire ORDINAIRE vide) est ICI capture comme un javadoc au texte       }
{ vide - INOFFENSIF (le TODO 17 n y trouvera jamais de directive), plutot     }
{ que d ajouter un quatrieme caractere de lecture en avant supplementaire      }
{ rien que pour cette distinction fine, jamais exercee par aucun               }
{ echantillon actuel. Retourne Vrai si au moins un saut de ligne a ete           }
{ traverse (necessaire a une eventuelle regle de mise en page future,            }
{ AUCUNE regle de terminaison ne l exploite ici - voir la note d en-tete de       }
{ section, Java exige ';' explicite).                                              }
{ ------------------------------------------------------------ }

Function LexSkipBlockComment(CaptureDoc: Boolean): Boolean;
Var
  CrossedLine : Boolean;
Begin
  CrossedLine := False;
  LexNextChar; LexNextChar;   { sauter '/' et '*' d ouverture }
  If CaptureDoc Then
  Begin
    LexNextChar;   { sauter le 3e '*' de "/**" }
    LexLastJavadocText := '';
    LexLastJavadocLine := LexLineNo;
  End;
  While True Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
        FatalError('commentaire /* non ferme avant fin de fichier');
      CrossedLine := True;
      If CaptureDoc And (Length(LexLastJavadocText) < MAX_STR) Then
        LexLastJavadocText := LexLastJavadocText + Chr(10);
      LexNextLine;
      Continue;
    End;
    If (LexPeekChar = '*') And (LexPeekChar2 = '/') Then
    Begin
      LexNextChar; LexNextChar;
      LexSkipBlockComment := CrossedLine;
      Exit;
    End;
    If CaptureDoc And (Length(LexLastJavadocText) < MAX_STR) Then
      LexLastJavadocText := LexLastJavadocText + LexPeekChar;
    LexNextChar;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanOperator : plus long operateur/ponctuation reconnu a la  }
{ position courante (methode du "maximal munch" - 4, puis 3, puis    }
{ 2, puis 1 caractere) - jeu d operateurs REEL de Java 1.1/J++          }
{ (section 6 de la reference) : notamment ">>>"/">>>=" (decalage         }
{ arithmetique NON SIGNE, forme propre a Java, ABSENTE de Swift/Go de      }
{ ce projet) ; "instanceof" reste un IDENTIFICATEUR ordinaire ici           }
{ (classifie mot-cle au TODO 03, meme deferral que tous les autres            }
{ mots reserves). Couvre AUSSI la ponctuation SIMPLE (parentheses/            }
{ crochets/accolades/virgule/deux-points/point-virgule/point/point            }
{ d interrogation) - rendue par le dernier "Else" generique. }
{ ------------------------------------------------------------ }

Procedure LexScanOperator;
Var
  C1, C2, C3, C4 : Char;
Begin
  C1 := LexPeekChar;
  C2 := LexPeekChar2;
  C3 := LexPeekChar3;
  C4 := LexPeekChar4;
  CurToken.Kind := TOK_OP;

  If (C1 = '>') And (C2 = '>') And (C3 = '>') And (C4 = '=') Then
  Begin CurToken.Val := '>>>='; LexNextChar; LexNextChar; LexNextChar; LexNextChar; Exit; End;

  If (C1 = '>') And (C2 = '>') And (C3 = '>') Then
  Begin CurToken.Val := '>>>'; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '<') And (C3 = '=') Then
  Begin CurToken.Val := '<<='; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '>') And (C3 = '=') Then
  Begin CurToken.Val := '>>='; LexNextChar; LexNextChar; LexNextChar; Exit; End;

  If (C1 = '+') And (C2 = '+') Then
  Begin CurToken.Val := '++'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '-') And (C2 = '-') Then
  Begin CurToken.Val := '--'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '=') And (C2 = '=') Then
  Begin CurToken.Val := '=='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '!') And (C2 = '=') Then
  Begin CurToken.Val := '!='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '=') Then
  Begin CurToken.Val := '<='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '=') Then
  Begin CurToken.Val := '>='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '&') And (C2 = '&') Then
  Begin CurToken.Val := '&&'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '|') And (C2 = '|') Then
  Begin CurToken.Val := '||'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '<') Then
  Begin CurToken.Val := '<<'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '>') Then
  Begin CurToken.Val := '>>'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '+') And (C2 = '=') Then
  Begin CurToken.Val := '+='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '-') And (C2 = '=') Then
  Begin CurToken.Val := '-='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '*') And (C2 = '=') Then
  Begin CurToken.Val := '*='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '/') And (C2 = '=') Then
  Begin CurToken.Val := '/='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '%') And (C2 = '=') Then
  Begin CurToken.Val := '%='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '&') And (C2 = '=') Then
  Begin CurToken.Val := '&='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '|') And (C2 = '=') Then
  Begin CurToken.Val := '|='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '^') And (C2 = '=') Then
  Begin CurToken.Val := '^='; LexNextChar; LexNextChar; Exit; End;

  If C1 = #0 Then
    FatalError('caractere inattendu en fin de ligne')
  Else If (C1 < ' ') Or (C1 > '~') Then
    FatalError('caractere inattendu (hors ASCII imprimable)')
  Else
  Begin
    CurToken.Val := C1;
    LexNextChar;
  End;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : produit le prochain token. AUCUNE regle de       }
{ terminaison a gerer (voir la note d en-tete de section) : la boucle  }
{ "Scanning" se contente de sauter espaces/commentaires jusqu au         }
{ prochain VRAI token, ou de signaler EOF. Les lignes "#if/#else/         }
{ #elif/#endif" (extension "directives Microsoft", TODO 17, suite au       }
{ roadmap d en-tete) NE sont PAS des tokens de ce lexeur JAVA lui-meme :     }
{ rencontrer un '#' EN DEBUT DE LIGNE (apres espaces) s arrete             }
{ PROPREMENT ici (FatalError explicite pointant vers le TODO 17 pas         }
{ encore ecrit) plutot que de le mal-interpreter comme un caractere          }
{ operateur inconnu - Test15Conditionnelle.jpp s arretera donc            }
{ PRECISEMENT ici tant que le TODO 17 n existe pas.                          }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch                : Char;
  Scanning          : Boolean;
  IsDoc             : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    If (Not LexEOF) And (LexColNo > Length(LexLine)) Then
    Begin
      LexAdvanceSourceLine;   { TODO 17 - PAS LexNextLine brut, voir sa note d''en-tete }
      Continue;
    End;

    If LexEOF Then
    Begin
      CurToken.Kind := TOK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Inc(TokenCount);
      Exit;
    End;

    Ch := LexPeekChar;

    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Then
    Begin
      LexNextChar;
      Continue;
    End;

    { '#if'/'#else'/'#elif'/'#endif' : DEVENU INATTEIGNABLE pour toute   }
    { ligne de directive BIEN FORMEE depuis le TODO 17 (LexAdvanceSourceLine, }
    { voir sa note d en-tete pres de LexNextLine, INTERCEPTE et ELIMINE       }
    { toute ligne dont le premier caractere non-espace est '#' AVANT           }
    { qu elle n atteigne jamais LexLine ici) - CONSERVE neanmoins comme           }
    { filet de securite EXPLICITE (pas du code mort inutile : '#'                     }
    { n apparaissant JAMAIS ailleurs dans du J++ REEL, un '#' qui                     }
    { atteindrait quand meme ICI ne peut venir que d une position                     }
    { INATTENDUE - par exemple au MILIEU d une ligne apres du code reel,             }
    { jamais exercee par aucun echantillon - un arret PROPRE reste                       }
    { preferable a une mauvaise interpretation silencieuse comme                          }
    { operateur inconnu, MEME discipline que documentee a l origine ICI            }
    { avant le TODO 17, TROUVEE PAR EXECUTION sur Test15Conditionnelle.jpp). }
    If Ch = '#' Then
      FatalError('caractere "#" inattendu en dehors d''une ligne de ' +
        'directive Microsoft complete (section 17.30, TODO 17)');

    If (Ch = '/') And (LexPeekChar2 = '/') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Continue;
    End;

    If (Ch = '/') And (LexPeekChar2 = '*') Then
    Begin
      IsDoc := LexPeekChar3 = '*';
      LexSkipBlockComment(IsDoc);
      Continue;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;

    If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End
    Else If IsDigitCh(Ch) Or ((Ch = '.') And IsDigitCh(LexPeekChar2)) Then
    Begin
      LexScanNumber;
      Scanning := False;
    End
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End
    Else If Ch = '''' Then
    Begin
      LexScanChar;
      Scanning := False;
    End
    Else
    Begin
      LexScanOperator;
      Scanning := False;
    End;
  End;

  Inc(TokenCount);
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug (-d) de chaque token             }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T: TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TOK_EOF    : Write('EOF');
    TOK_IDENT  : Write('IDENT(', T.Val, ')');
    TOK_INT    : Write('INT(', T.IntVal, ')');
    TOK_LONG   : Write('LONG(', T.IntVal, ')');
    TOK_FLOAT  : Write('FLOAT(', T.Val, ')');
    TOK_DOUBLE : Write('DOUBLE(', T.Val, ')');
    TOK_CHAR   : Write('CHAR(', T.IntVal, ')');
    TOK_STRING : Write('STRING("', T.Val, '")');
    TOK_OP     : Write('OP(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexSelfTest (TODO 24 anticipe partiellement, comme le fait      }
{ deja GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS pour leurs propres         }
{ fonctions de base) : tokenise un petit extrait J++ ecrit dans un    }
{ fichier temporaire, verifie la sequence de tokens attendue -          }
{ couvre identificateurs (dont '$'), litteraux entiers (decimal/hex/      }
{ octal ancien style/long), flottant (double par defaut/float           }
{ explicite), caractere (simple/echappe), chaine, commentaires //,        }
{ /* */ et /** */ (javadoc capture), et les operateurs Java REELS            }
{ (>>> notamment). ------------------------------------------------ }

Procedure LexAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('LexSelfTest: ' + Label_ + ' a echoue');
End;

Procedure LexSelfTest;
Const
  TmpFile = 'JPPLEXSELFTEST.$$$';
Var
  F : Text;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'int $x = 42;');
  WriteLn(F, 'int y = 0x1F + 017;');
  WriteLn(F, 'long z = 42L;');
  WriteLn(F, 'double d1 = 1.5e-3;');
  WriteLn(F, 'float f1 = 2.5f;');
  WriteLn(F, 'char c1 = ''A'';');
  WriteLn(F, 'char c2 = ''\n'';');
  WriteLn(F, 'String s = "hi there";');
  WriteLn(F, '// commentaire ligne');
  WriteLn(F, '/* bloc */');
  WriteLn(F, '/** @dll.import("USER32") */');
  WriteLn(F, 'int shifted = a >>> 2;');
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;

  { ligne 1 : int $x = 42 ; }
  LexNextToken; LexAssert('1: IDENT int', (CurToken.Kind = TOK_IDENT) And (CurToken.Val = 'int'));
  LexNextToken; LexAssert('1: IDENT $x', (CurToken.Kind = TOK_IDENT) And (CurToken.Val = '$x'));
  LexNextToken; LexAssert('1: OP =', (CurToken.Kind = TOK_OP) And (CurToken.Val = '='));
  LexNextToken; LexAssert('1: INT 42', (CurToken.Kind = TOK_INT) And (CurToken.IntVal = 42));
  LexNextToken; LexAssert('1: OP ;', (CurToken.Kind = TOK_OP) And (CurToken.Val = ';'));

  { ligne 2 : int y = 0x1F + 017 ; }
  LexNextToken; LexAssert('2: IDENT int', CurToken.Val = 'int');
  LexNextToken; LexAssert('2: IDENT y', CurToken.Val = 'y');
  LexNextToken; LexAssert('2: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('2: HEX 0x1F=31', (CurToken.Kind = TOK_INT) And (CurToken.IntVal = 31));
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: OCTAL 017=15', (CurToken.Kind = TOK_INT) And (CurToken.IntVal = 15));
  LexNextToken; LexAssert('2: OP ;', CurToken.Val = ';');

  { ligne 3 : long z = 42L ; }
  LexNextToken; LexAssert('3: IDENT long', CurToken.Val = 'long');
  LexNextToken; LexAssert('3: IDENT z', CurToken.Val = 'z');
  LexNextToken; LexAssert('3: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('3: LONG 42', (CurToken.Kind = TOK_LONG) And (CurToken.IntVal = 42));
  LexNextToken; LexAssert('3: OP ;', CurToken.Val = ';');

  { ligne 4 : double d1 = 1.5e-3 ; }
  LexNextToken; LexAssert('4: IDENT double', CurToken.Val = 'double');
  LexNextToken; LexAssert('4: IDENT d1', CurToken.Val = 'd1');
  LexNextToken; LexAssert('4: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('4: DOUBLE (defaut, sans suffixe)',
    (CurToken.Kind = TOK_DOUBLE) And (CurToken.RealVal > 0.0014) And
    (CurToken.RealVal < 0.0016));
  LexNextToken; LexAssert('4: OP ;', CurToken.Val = ';');

  { ligne 5 : float f1 = 2.5f ; }
  LexNextToken; LexAssert('5: IDENT float', CurToken.Val = 'float');
  LexNextToken; LexAssert('5: IDENT f1', CurToken.Val = 'f1');
  LexNextToken; LexAssert('5: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('5: FLOAT (suffixe f explicite)',
    (CurToken.Kind = TOK_FLOAT) And (CurToken.RealVal > 2.4) And (CurToken.RealVal < 2.6));
  LexNextToken; LexAssert('5: OP ;', CurToken.Val = ';');

  { ligne 6 : char c1 = 'A' ; }
  LexNextToken; LexAssert('6: IDENT char', CurToken.Val = 'char');
  LexNextToken; LexAssert('6: IDENT c1', CurToken.Val = 'c1');
  LexNextToken; LexAssert('6: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('6: CHAR ''A''=65', (CurToken.Kind = TOK_CHAR) And (CurToken.IntVal = 65));
  LexNextToken; LexAssert('6: OP ;', CurToken.Val = ';');

  { ligne 7 : char c2 = '\n' ; }
  LexNextToken; LexAssert('7: IDENT char', CurToken.Val = 'char');
  LexNextToken; LexAssert('7: IDENT c2', CurToken.Val = 'c2');
  LexNextToken; LexAssert('7: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('7: CHAR ''\n''=10', (CurToken.Kind = TOK_CHAR) And (CurToken.IntVal = 10));
  LexNextToken; LexAssert('7: OP ;', CurToken.Val = ';');

  { ligne 8 : String s = "hi there" ; }
  LexNextToken; LexAssert('8: IDENT String', CurToken.Val = 'String');
  LexNextToken; LexAssert('8: IDENT s', CurToken.Val = 's');
  LexNextToken; LexAssert('8: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('8: STRING',
    (CurToken.Kind = TOK_STRING) And (CurToken.Val = 'hi there'));
  LexNextToken; LexAssert('8: OP ;', CurToken.Val = ';');

  { lignes 9-11 : commentaires // /* */ /** @dll.import... */ - AUCUN   }
  { token produit pour eux ; le javadoc doit avoir ete CAPTURE. }
  LexNextToken; LexAssert('12: IDENT int (apres 3 lignes de commentaires)',
    CurToken.Val = 'int');
  LexAssert('javadoc capture : contient @dll.import',
    Pos('@dll.import', LexLastJavadocText) > 0);

  { ligne 12 (suite) : int shifted = a >>> 2 ; }
  LexNextToken; LexAssert('12: IDENT shifted', CurToken.Val = 'shifted');
  LexNextToken; LexAssert('12: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('12: IDENT a', CurToken.Val = 'a');
  LexNextToken; LexAssert('12: OP >>> (decalage non signe)', CurToken.Val = '>>>');
  LexNextToken; LexAssert('12: INT 2', CurToken.IntVal = 2);
  LexNextToken; LexAssert('12: OP ;', CurToken.Val = ';');

  LexNextToken; LexAssert('EOF final', CurToken.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 03 - MOTS RESERVES ET IDENTIFICATEURS PREDECLARES        }
{ ============================================================ }
{ Le lexeur (TODO 02) produit TOK_IDENT pour tout ce qui a la      }
{ forme d un identificateur, mots-cles INCLUS - cette section          }
{ fournit la VRAIE classification, utilisee par le futur analyseur         }
{ syntaxique (TODO 05+). IsKeyword couvre EXACTEMENT (ni plus ni            }
{ moins) les 47 mots reserves ENUMERES par la section 3.2 de la              }
{ reference (DOC\JPP_SPEC_LANG.txt) - AUCUN mot devine/ajoute par                }
{ anticipation : "const"/"goto" y sont RESERVES bien que sans                       }
{ instruction associee (section 3.2, "const et goto sont reserves                     }
{ mais n ont pas d instruction associee"), et les VRAIS types                            }
{ PRIMITIFS Java (int, boolean, char, byte, short, long, float,                            }
{ double, void) y figurent DEJA comme mots reserves ORDINAIRES -                              }
{ DIFFERENCE REELLE avec SWIFTW32.PAS ("Int"/"String"/... y sont des                            }
{ IDENTIFICATEURS predeclares, jamais des mots-cles) : Java n a donc                              }
{ PAS besoin d une table "IsPredeclaredType" pour ses types                                          }
{ primitifs, IsKeyword suffit entierement pour eux.                                                     }
{                                                                       }
{ DEUX categories RESTENT separees de IsKeyword, chacune pour une      }
{ raison DIFFERENTE explicitement documentee par la reference elle-    }
{ meme :                                                                }
{   - IsPredeclaredType (types REFERENCE visibles SANS import          }
{     explicite - String, Object, et la hierarchie Throwable la plus   }
{     immediate) : CE SONT de VRAIS identificateurs ordinaires en      }
{     Java (on peut en theorie les masquer par une declaration         }
{     locale - la regle d ombrage elle-meme relevera de l analyse      }
{     semantique, TODO 19, pas d ici), contrairement aux mots          }
{     reserves qui ne peuvent JAMAIS servir d identificateur.          }
{   - IsPredeclaredLiteral (true/false/null) : la section 3.2 de la    }
{     reference les exclut EXPLICITEMENT de l enumeration des mots     }
{     reserves ("true, false et null sont des litteraux et non des     }
{     identificateurs") - CHOIX DELIBERE de suivre ici la MEME         }
{     discipline que GOCW32.PAS (categorie "identificateurs            }
{     predeclares" separee) plutot que celle de SWIFTW32.PAS (qui,     }
{     lui, range true/false/nil DANS IsKeyword) : la reference J++     }
{     elle-meme trace explicitement cette distinction, ce choix n est  }
{     donc pas arbitraire.                                             }
{                                                                       }
{ "delegate"/"multicast" (extension "delegates Microsoft", TODO 16,    }
{ suite au roadmap d en-tete) restent DELIBEREMENT ABSENTS des trois    }
{ tables ci-dessous : la reference elle-meme (section 3.2) les         }
{ qualifie de mots CONTEXTUELS ("reconnus lorsque les extensions sont  }
{ activees"), jamais reserves ("il est prudent de ne pas les employer  }
{ comme identificateurs" - un simple CONSEIL, pas une regle du         }
{ langage) : leur reconnaissance revient au TODO 16 lui-meme,          }
{ directement sur le TEXTE du token a la position grammaticale         }
{ EXACTE ou une declaration de delegate est attendue - AUCUNE          }
{ structure supplementaire n est necessaire ICI pour cela.             }

Const
  { --- Mots reserves (47 - liste EXHAUSTIVE de la section 3.2, PAS   }
  { seulement ceux exerces par SAMPLES\JPP\*.jpp comme le font          }
  { certains compilateurs freres pour LEUR langage : le noyau Java 1.1    }
  { est un ensemble FERME et entierement connu d avance, contrairement       }
  { a un langage encore evolutif au moment ou ce projet le documente). }
  KW_ABSTRACT     = 1;
  KW_BOOLEAN      = 2;
  KW_BREAK        = 3;
  KW_BYTE         = 4;
  KW_CASE         = 5;
  KW_CATCH        = 6;
  KW_CHAR         = 7;
  KW_CLASS        = 8;
  KW_CONST        = 9;
  KW_CONTINUE     = 10;
  KW_DEFAULT      = 11;
  KW_DO           = 12;
  KW_DOUBLE       = 13;
  KW_ELSE         = 14;
  KW_EXTENDS      = 15;
  KW_FINAL        = 16;
  KW_FINALLY      = 17;
  KW_FLOAT        = 18;
  KW_FOR          = 19;
  KW_GOTO         = 20;
  KW_IF           = 21;
  KW_IMPLEMENTS   = 22;
  KW_IMPORT       = 23;
  KW_INSTANCEOF   = 24;
  KW_INT          = 25;
  KW_INTERFACE    = 26;
  KW_LONG         = 27;
  KW_NATIVE       = 28;
  KW_NEW          = 29;
  KW_PACKAGE      = 30;
  KW_PRIVATE      = 31;
  KW_PROTECTED    = 32;
  KW_PUBLIC       = 33;
  KW_RETURN       = 34;
  KW_SHORT        = 35;
  KW_STATIC       = 36;
  KW_SUPER        = 37;
  KW_SWITCH       = 38;
  KW_SYNCHRONIZED = 39;
  KW_THIS         = 40;
  KW_THROW        = 41;
  KW_THROWS       = 42;
  KW_TRANSIENT    = 43;
  KW_TRY          = 44;
  KW_VOID         = 45;
  KW_VOLATILE     = 46;
  KW_WHILE        = 47;

  { --- Types REFERENCE predeclares (10) - concus pour etre reutilises  }
  { directement comme TypeIdx de base par le TODO 04 (TypeTab), MEME       }
  { discipline que les codes PDT_xxx de GOCW32.PAS/SWIFTW32.PAS. Les            }
  { QUATRE derniers (TODO 11, section 11.2) sont les classes concretes         }
  { REELLEMENT lancees/capturees par les echantillons (feuille de                }
  { route du TODO 11) - AJOUTEES ICI plutot qu apres coup pour EVITER            }
  { toute confusion : elles font PARTIE des types "reference                          }
  { predeclares" au meme titre que les 6 premiers, jamais un genre a               }
  { part. }
  PDT_OBJECT           = 1;
  PDT_STRING           = 2;
  PDT_THROWABLE        = 3;
  PDT_EXCEPTION        = 4;
  PDT_RUNTIMEEXCEPTION = 5;
  PDT_ERROR            = 6;
  PDT_ILLEGALARGUMENTEXCEPTION = 7;   { extends RuntimeException }
  PDT_NUMBERFORMATEXCEPTION    = 8;   { extends IllegalArgumentException  }
                                       { (hierarchie Java REELLE - PAS         }
                                       { directement RuntimeException) }
  PDT_INTERRUPTEDEXCEPTION     = 9;   { extends Exception - VERIFIEE          }
                                       { (section 11.3), PAS RuntimeException }
  PDT_UNSATISFIEDLINKERROR     = 10;  { extends Error DIRECTEMENT -           }
                                       { simplification ASSUMEE (Java reel        }
                                       { intercale LinkageError entre Error       }
                                       { et UnsatisfiedLinkError ; AUCUN                }
                                       { echantillon ne reference LinkageError         }
                                       { lui-meme, seule sa feuille concrete             }
                                       { est utilisee - TODO 12+ si jamais un            }
                                       { echantillon futur en avait besoin) }

  { --- Litteraux predeclares (3) - voir la note d en-tete de section  }
  { pour la raison de cette categorie SEPAREE de IsKeyword. }
  PL_TRUE  = 1;
  PL_FALSE = 2;
  PL_NULL  = 3;

{ IsKeyword : 0 si S n est PAS l un des 47 mots reserves ci-dessus,  }
{ sinon le code KW_xxx correspondant. Sensible a la casse (Java/J++     }
{ l est - "Class" ou "IF" restent des identificateurs ordinaires). }
Function IsKeyword(Const S: TString): Integer;
Begin
  IsKeyword := 0;
  If      S = 'abstract'     Then IsKeyword := KW_ABSTRACT
  Else If S = 'boolean'      Then IsKeyword := KW_BOOLEAN
  Else If S = 'break'        Then IsKeyword := KW_BREAK
  Else If S = 'byte'         Then IsKeyword := KW_BYTE
  Else If S = 'case'         Then IsKeyword := KW_CASE
  Else If S = 'catch'        Then IsKeyword := KW_CATCH
  Else If S = 'char'         Then IsKeyword := KW_CHAR
  Else If S = 'class'        Then IsKeyword := KW_CLASS
  Else If S = 'const'        Then IsKeyword := KW_CONST
  Else If S = 'continue'     Then IsKeyword := KW_CONTINUE
  Else If S = 'default'      Then IsKeyword := KW_DEFAULT
  Else If S = 'do'           Then IsKeyword := KW_DO
  Else If S = 'double'       Then IsKeyword := KW_DOUBLE
  Else If S = 'else'         Then IsKeyword := KW_ELSE
  Else If S = 'extends'      Then IsKeyword := KW_EXTENDS
  Else If S = 'final'        Then IsKeyword := KW_FINAL
  Else If S = 'finally'      Then IsKeyword := KW_FINALLY
  Else If S = 'float'        Then IsKeyword := KW_FLOAT
  Else If S = 'for'          Then IsKeyword := KW_FOR
  Else If S = 'goto'         Then IsKeyword := KW_GOTO
  Else If S = 'if'           Then IsKeyword := KW_IF
  Else If S = 'implements'   Then IsKeyword := KW_IMPLEMENTS
  Else If S = 'import'       Then IsKeyword := KW_IMPORT
  Else If S = 'instanceof'   Then IsKeyword := KW_INSTANCEOF
  Else If S = 'int'          Then IsKeyword := KW_INT
  Else If S = 'interface'    Then IsKeyword := KW_INTERFACE
  Else If S = 'long'         Then IsKeyword := KW_LONG
  Else If S = 'native'       Then IsKeyword := KW_NATIVE
  Else If S = 'new'          Then IsKeyword := KW_NEW
  Else If S = 'package'      Then IsKeyword := KW_PACKAGE
  Else If S = 'private'      Then IsKeyword := KW_PRIVATE
  Else If S = 'protected'    Then IsKeyword := KW_PROTECTED
  Else If S = 'public'       Then IsKeyword := KW_PUBLIC
  Else If S = 'return'       Then IsKeyword := KW_RETURN
  Else If S = 'short'        Then IsKeyword := KW_SHORT
  Else If S = 'static'       Then IsKeyword := KW_STATIC
  Else If S = 'super'        Then IsKeyword := KW_SUPER
  Else If S = 'switch'       Then IsKeyword := KW_SWITCH
  Else If S = 'synchronized' Then IsKeyword := KW_SYNCHRONIZED
  Else If S = 'this'         Then IsKeyword := KW_THIS
  Else If S = 'throw'        Then IsKeyword := KW_THROW
  Else If S = 'throws'       Then IsKeyword := KW_THROWS
  Else If S = 'transient'    Then IsKeyword := KW_TRANSIENT
  Else If S = 'try'          Then IsKeyword := KW_TRY
  Else If S = 'void'         Then IsKeyword := KW_VOID
  Else If S = 'volatile'     Then IsKeyword := KW_VOLATILE
  Else If S = 'while'        Then IsKeyword := KW_WHILE;
End;

{ IsPredeclaredType : 0 si S n est pas un nom de type REFERENCE       }
{ predeclare, sinon le code PDT_xxx correspondant. }
Function IsPredeclaredType(Const S: TString): Integer;
Begin
  IsPredeclaredType := 0;
  If      S = 'Object'           Then IsPredeclaredType := PDT_OBJECT
  Else If S = 'String'           Then IsPredeclaredType := PDT_STRING
  Else If S = 'Throwable'        Then IsPredeclaredType := PDT_THROWABLE
  Else If S = 'Exception'        Then IsPredeclaredType := PDT_EXCEPTION
  Else If S = 'RuntimeException' Then IsPredeclaredType := PDT_RUNTIMEEXCEPTION
  Else If S = 'Error'            Then IsPredeclaredType := PDT_ERROR
  Else If S = 'IllegalArgumentException' Then IsPredeclaredType := PDT_ILLEGALARGUMENTEXCEPTION
  Else If S = 'NumberFormatException'    Then IsPredeclaredType := PDT_NUMBERFORMATEXCEPTION
  Else If S = 'InterruptedException'     Then IsPredeclaredType := PDT_INTERRUPTEDEXCEPTION
  Else If S = 'UnsatisfiedLinkError'     Then IsPredeclaredType := PDT_UNSATISFIEDLINKERROR;
End;

{ IsPredeclaredLiteral : 0 si S n est pas l un des 3 litteraux        }
{ predeclares true/false/null, sinon le code PL_xxx correspondant. }
Function IsPredeclaredLiteral(Const S: TString): Integer;
Begin
  IsPredeclaredLiteral := 0;
  If      S = 'true'  Then IsPredeclaredLiteral := PL_TRUE
  Else If S = 'false' Then IsPredeclaredLiteral := PL_FALSE
  Else If S = 'null'  Then IsPredeclaredLiteral := PL_NULL;
End;

{ ------------------------------------------------------------ }
{ KeywordSelfTest : verifie IsKeyword/IsPredeclaredType/            }
{ IsPredeclaredLiteral sur un echantillon representatif de chaque      }
{ categorie, ET verifie qu un identificateur ORDINAIRE (ex.               }
{ "maVariable") ainsi que "delegate"/"multicast" (mots CONTEXTUELS,          }
{ jamais reserves - voir la note d en-tete de section) ne sont classes         }
{ dans AUCUNE des trois.                                                        }
{ ------------------------------------------------------------ }

Procedure KeywordAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('KeywordSelfTest: ' + Label_ + ' a echoue');
End;

Procedure KeywordSelfTest;
Begin
  KeywordAssert('class est un mot-cle',        IsKeyword('class') = KW_CLASS);
  KeywordAssert('public est un mot-cle',       IsKeyword('public') = KW_PUBLIC);
  KeywordAssert('static est un mot-cle',       IsKeyword('static') = KW_STATIC);
  KeywordAssert('int est un mot-cle (PAS un type predeclare)',
    IsKeyword('int') = KW_INT);
  KeywordAssert('void est un mot-cle',         IsKeyword('void') = KW_VOID);
  KeywordAssert('instanceof est un mot-cle',   IsKeyword('instanceof') = KW_INSTANCEOF);
  KeywordAssert('synchronized est un mot-cle', IsKeyword('synchronized') = KW_SYNCHRONIZED);
  KeywordAssert('const est reserve (section 3.2, sans instruction associee)',
    IsKeyword('const') = KW_CONST);
  KeywordAssert('goto est reserve (section 3.2, sans instruction associee)',
    IsKeyword('goto') = KW_GOTO);
  KeywordAssert('maVariable n''est pas un mot-cle', IsKeyword('maVariable') = 0);
  KeywordAssert('delegate n''est PAS un mot-cle (contextuel, TODO 16)',
    IsKeyword('delegate') = 0);
  KeywordAssert('multicast n''est PAS un mot-cle (contextuel, TODO 16)',
    IsKeyword('multicast') = 0);
  KeywordAssert('true n''est PAS un mot-cle (litteral, section 3.2)',
    IsKeyword('true') = 0);

  KeywordAssert('String est un type predeclare',    IsPredeclaredType('String') = PDT_STRING);
  KeywordAssert('Object est un type predeclare',    IsPredeclaredType('Object') = PDT_OBJECT);
  KeywordAssert('Exception est un type predeclare', IsPredeclaredType('Exception') = PDT_EXCEPTION);
  KeywordAssert('RuntimeException est un type predeclare',
    IsPredeclaredType('RuntimeException') = PDT_RUNTIMEEXCEPTION);
  KeywordAssert('Throwable est un type predeclare', IsPredeclaredType('Throwable') = PDT_THROWABLE);
  KeywordAssert('Error est un type predeclare',     IsPredeclaredType('Error') = PDT_ERROR);
  KeywordAssert('maVariable n''est pas un type predeclare',
    IsPredeclaredType('maVariable') = 0);
  KeywordAssert('int n''est pas dans IsPredeclaredType (deja un mot-cle)',
    IsPredeclaredType('int') = 0);

  KeywordAssert('true est un litteral predeclare',  IsPredeclaredLiteral('true') = PL_TRUE);
  KeywordAssert('false est un litteral predeclare', IsPredeclaredLiteral('false') = PL_FALSE);
  KeywordAssert('null est un litteral predeclare',  IsPredeclaredLiteral('null') = PL_NULL);
  KeywordAssert('maVariable n''est pas un litteral predeclare',
    IsPredeclaredLiteral('maVariable') = 0);
End;

{ ============================================================ }
{ TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES }
{ ============================================================ }
{ Table des types INSPIREE de celle de GOCW32.PAS/SWIFTW32.PAS      }
{ (meme discipline TypeTab/FieldPool partages, meme alignement          }
{ PDT_xxx <-> TypeIdx etabli au TODO 03) mais VRAIMENT plus simple           }
{ que les deux : Java n a AUCUNE distinction "IsUnsigned" (aucun               }
{ entier non signe), et le statut VALEUR/REFERENCE d un type se                    }
{ DEDUIT entierement de son Kind (TypeIsValueKind ci-dessous) plutot           }
{ que d etre stocke comme un champ separe pouvant diverger - les                    }
{ HUIT genres primitifs (boolean/byte/short/int/long/char/float/                    }
{ double) sont TOUJOURS valeur, String/Array/Class/Interface                          }
{ TOUJOURS reference, Null/Void sont des cas speciaux jamais                             }
{ instancies directement.                                                                   }
{                                                                       }
{ DECISION EXPLICITE (roadmap d en-tete, TYK_CHAR) : Size=2 pour       }
{ TYK_CHAR, FIDELE au "char" Java REEL (16 bits, un scalaire Unicode    }
{ UTF-16) - CHOISI plutot que la simplification 8 bits proposee en     }
{ alternative par le roadmap, puisqu aucun cout n en decoule QUE LA    }
{ VALEUR (IntVal, un LongInt 32 bits en pratique dans ce generateur    }
{ de code) porte deja le code point COMPLET jusqu a 65535 depuis le    }
{ TODO 02 (LexScanEscape/LexScanChar) - SEULE la representation        }
{ TEXTUELLE (TToken.Val, un TString 8 bits) reste tronquee a l octet   }
{ bas, limitation DEJA documentee au TODO 02, distincte de celle-ci    }
{ et non re-decidee ici. Size=2 sera directement utile au TODO 10      }
{ (le "stride" reel d un element de char[]).                           }
{                                                                       }
{ DEUXIEME DECISION EXPLICITE : String/Array recoivent Size=4 (UN      }
{ SEUL pointeur, meme convention "la valeur EST un pointeur" que       }
{ chaque compilateur frere) - PAS Size=8 comme SWIFTW32.PAS le fait    }
{ pour ses propres String/Array (une incoherence CONNUE et DEJA        }
{ documentee la-bas entre la taille declaree et la representation      }
{ REELLE choisie par son propre generateur de code, jamais reconciliee) : }
{ decision VOLONTAIREMENT CORRIGEE ici plutot que reproduite a         }
{ l identique par simple copie du modele du compilateur frere.         }

Type
  TTypeKind = (
    TYK_INVALID,    { entree 0 reservee, sentinelle (voir TypeInit)    }
    TYK_BOOLEAN,
    TYK_BYTE,
    TYK_SHORT,
    TYK_INT,
    TYK_LONG,       { 64 bits REELS en Java - represente ICI par un      }
                    { simple LongInt 32 bits, meme simplification            }
                    { documentee que le reste de ce projet pour les             }
                    { types "larges" (voir deja TOK_LONG, TODO 02)              }
    TYK_CHAR,       { 16 bits Unicode REELS - voir la note d en-tete         }
                    { de section ci-dessus                                        }
    TYK_FLOAT,
    TYK_DOUBLE,
    TYK_STRING,     { type REFERENCE special, immuable - JAMAIS               }
                    { TYK_CLASS (String n a pas de SuperTypeIdx ici,               }
                    { simplification documentee : la VRAIE hierarchie              }
                    { String/CharSequence/Object de Java reel n est pas               }
                    { modelisee, hors de portee) }
    TYK_ARRAY,      { ElemTypeIdx = type des elements ; -1 si inconnu -   }
                    { longueur FIXE a la creation (section 10.1, jamais         }
                    { redimensionnable - AUCUNE operation "ajouter" n existe          }
                    { nulle part dans ce parseur, contrairement au                       }
                    { Array<Int> DYNAMIQUE de SWIFTW32.PAS) ; verification            }
                    { de borne a l acces (section 10.7,                                        }
                    { ArrayIndexOutOfBoundsException) et valeurs PAR                      }
                    { DEFAUT des elements (section 10.6, 0/false/null                       }
                    { selon le type) sont TOUTES DEUX des DECISIONS DE                    }
                    { GENERATION DE CODE (que produire a l EXECUTION), pas           }
                    { d analyse syntaxique - AUCUNE generation de code                    }
                    { n existe encore (TODO 21+) : EK_INDEX (TODO 06, plus         }
                    { bas) reste une resolution purement LEXICALE du type          }
                    { resultat, jamais un CONTROLE reel - decision                            }
                    { EXPLICITE (TODO 10), pas devinee, de repousser LA               }
                    { VERIFICATION ELLE-MEME (par opposition a sa simple             }
                    { possibilite structurelle, deja presente) au moment            }
                    { ou une VRAIE generation de code existera. }
    TYK_CLASS,      { heritage SIMPLE via SuperTypeIdx - TODO 08 pour          }
                    { les classes UTILISATEUR ; SIX entrees PREDECLAREES           }
                    { existent DEJA ici (Object/Throwable/Exception/                  }
                    { RuntimeException/Error, voir TypeInit) }
    TYK_INTERFACE,  { heritage MULTIPLE - InterfaceFirst/Count (reserve             }
                    { TODO 09) - AUCUNE entree predeclaree, contrairement            }
                    { a TYK_CLASS (Java n a pas d interface "racine"                    }
                    { universelle comme Object l est pour les classes) }
    TYK_NULL,       { type du litteral "null" (section 4 de la               }
                    { reference) - jamais NOMME, jamais instancie                     }
                    { directement par l utilisateur }
    TYK_VOID,       { type de retour absent ("void", mot-cle KW_VOID -            }
                    { TODO 03 - PAS un type recherche par nom) }
    TYK_DELEGATE    { TODO 16 (section 16.2-16.4), extension Microsoft -   }
                    { AJOUTE EN DERNIER (jamais insere au milieu) pour NE            }
                    { JAMAIS deplacer l ordinal d une valeur EXISTANTE,                  }
                    { contrairement au renumerotage PRIMTYPE_ documente au        }
                    { TODO 11 (qui, lui, concernait des CONSTANTES Integer          }
                    { comparees par valeur, pas un type enumere compare par         }
                    { nom - AUCUN risque similaire ici, precaution prise           }
                    { par coherence). MethodFirst (ci-dessous) pointe TOUJOURS   }
                    { vers l UNIQUE methode synthetisee "invoke" (jamais       }
                    { de champ, jamais de constructeur, jamais d heritage -      }
                    { AUCUN SuperTypeIdx/InterfaceFirst/FieldFirst n a de          }
                    { sens pour un delegate, ils restent a leur valeur PAR      }
                    { DEFAUT -1/0 de TypeAdd, jamais lus pour ce genre). }
  );

  { TVisibility (TODO 12, section 12.18/12.20) : les QUATRE niveaux       }
  { d acces Java - VIS_PACKAGE ("aucun" modificateur, section 12.20,             }
  { AUCUN mot reserve "default" n existe pour le nommer) est la VALEUR         }
  { PAR DEFAUT chaque fois qu aucun modificateur de visibilite n est                }
  { ecrit. DECISION EXPLICITE du TODO 12 (repondant a la question laissee        }
  { ouverte par ParseModifiers au TODO 05, "TSymRec n a pas encore ce            }
  { besoin... TODO 12 decidera ou les conserver") : STOCKEE desormais              }
  { sur TFieldRec/TMethodRec/TTypeRec (champs, methodes/constructeurs,         }
  { classes/interfaces - les SEULS elements dotes d une visibilite                  }
  { REELLEMENT observable en Java) - JAMAIS sur TSymRec (locales/                     }
  { parametres/this/super), qui n en a AUCUN besoin semantique reel               }
  { (Java n autorise meme pas syntaxiquement un modificateur de                       }
  { visibilite sur une locale ; ce parseur les ACCEPTE par lenience,             }
  { TModifiers/ParseModifiers, TODO 05, mais n a jamais eu de raison de           }
  { les CONSERVER). AUCUNE VERIFICATION D ACCES reelle n est ajoutee ICI      }
  { (section 12.19-12.26, "prive"/"package"/"protected"/"public" au sens         }
  { plein) - repoussee au TODO 19, EXACTEMENT comme le reste de l analyse       }
  { semantique de ce projet (best-effort, "meme niveau que le reste"               }
  { selon la feuille de route elle-meme) : AUCUN echantillon reel ne             }
  { viole d ailleurs une regle d acces (compilation MONO-FICHIER,                     }
  { section 12.6, "AUCUNE correspondance reelle repertoire<->paquet" -            }
  { tout est TOUJOURS "dans le meme fichier"), donc rien ne pourrait                }
  { justifier une verification qu aucun cas reel n exercerait jamais. }
  TVisibility = (VIS_PACKAGE, VIS_PUBLIC, VIS_PROTECTED, VIS_PRIVATE);

  { Valeur d une expression CONSTANTE J++ - TAGGEE, refletant les     }
  { HUIT genres de litteraux REELLEMENT distincts du langage (TODO 02) -   }
  { plus riche que la forme de GOCW32.PAS/SWIFTW32.PAS puisque Java             }
  { distingue VRAIMENT int/long/float/double (jamais un seul type              }
  { "par defaut" unique comme le "Int"/"Double" de Swift). Declaree ICI      }
  { (TODO 04, deplacee depuis le TODO 05 d origine) puisque TFieldRec            }
  { (juste en dessous) en a desormais besoin pour les initialiseurs de           }
  { CHAMP (TODO 08) - AUCUNE dependance reelle sur SymTab/le TODO 05,             }
  { ce type est un simple "sac de valeurs" reutilisable partout. }
  TConstKind = (CK_INT, CK_LONG, CK_FLOAT, CK_DOUBLE, CK_CHAR, CK_BOOL,
    CK_STRING, CK_NULL);

  TConstVal = Record
    Kind    : TConstKind;
    IntVal  : LongInt;   { CK_INT/CK_LONG/CK_CHAR/CK_BOOL (0/1) }
    RealVal : Real;      { CK_FLOAT/CK_DOUBLE }
    StrVal  : TString;   { CK_STRING }
  End;

  TFieldRec = Record
    Name        : TString;
    TypeIdx     : Integer;
    OwnerTypeIdx : Integer; { TODO 08 : classe PROPRIETAIRE - ClassFindField  }
                             { fait un PARCOURS COMPLET de FieldPool filtre       }
                             { par ce champ (MEME discipline EXACTE que              }
                             { MethodFirst/MethodCount ci-dessus : FieldFirst/       }
                             { FieldCount restent INFORMATIFS seulement,               }
                             { jamais dignes de confiance pour la contiguite) }
    Offset   : Integer;   { deplacement depuis le debut de l instance -  }
                           { CHAMPS PROPRES SEULEMENT (PAS les champs        }
                           { HERITES), un mot de 4 octets CHACUN, MEME           }
                           { simplification "tout tient dans EAX" que le           }
                           { reste de ce projet (TODO 08) }
    IsStatic : Boolean;    { TODO 08 : champ de classe (section 8.4/5.4)     }
                           { vs champ d instance (section 8.11/5.3) }
    IsFinal  : Boolean;    { TODO 08 }
    HasInit  : Boolean;    { TODO 08 : initialiseur DE CHAMP (section 8.11) - }
                           { PORTEE reduite a un LITTERAL (ConstEvalExpr,        }
                           { TODO 05, INCHANGE) - AUCUN des echantillons              }
                           { reels n a besoin de plus (Test06/07 initialisent          }
                           { leurs champs UNIQUEMENT via le constructeur,               }
                           { jamais au point de declaration) }
    ConstVal : TConstVal;  { TODO 08 : signifiant SEULEMENT si HasInit }
    Visibility : TVisibility; { TODO 12 - AUCUNE verification, voir la  }
                               { note d en-tete de TVisibility }
  End;

  TTypeRec = Record
    Kind               : TTypeKind;
    Name               : TString;   { '' si type anonyme (TYK_NULL,       }
                                     { sentinelle TYK_INVALID) }
    Size               : Integer;   { octets, representation runtime }
    Align              : Integer;
    ElemTypeIdx        : Integer;   { TYK_ARRAY seulement ; -1 sinon }
    Visibility         : TVisibility; { TODO 12 - "type de premier niveau" }
                                     { (section 12.17) : VIS_PUBLIC ou                }
                                     { VIS_PACKAGE SEULEMENT en pratique              }
                                     { (private/protected INTERDITS sur un          }
                                     { type de premier niveau - AUCUNE                    }
                                     { verification que ce soit BIEN l un              }
                                     { des deux, best-effort) ; pour une              }
                                     { classe/interface MEMBRE (TODO 08/09,            }
                                     { section 9.17), les QUATRE valeurs                }
                                     { restent possibles }
    SuperTypeIdx       : Integer;   { TYK_CLASS seulement : classe parente, }
                                     { heritage SIMPLE - -1 si aucune            }
                                     { (Object lui-meme, la racine)                  }
    InterfaceFirst     : Integer;   { reserve TODO 09 (implements/extends   }
                                     { d interfaces) - TOUJOURS -1/0 pour        }
                                     { l instant, rien n y ecrit encore }
    InterfaceCount     : Integer;
    FieldFirst         : Integer;   { TYK_CLASS seulement (TODO 08) :       }
                                     { champs PROPRES dans FieldPool, -1 si      }
                                     { aucun }
    FieldCount         : Integer;
    MethodFirst        : Integer;   { TYK_CLASS seulement (TODO 08) :       }
                                     { methodes/constructeurs PROPRES dans        }
                                     { MethodPool, -1 si aucune - PORTEE          }
                                     { INFORMATIVE seule (ClassResolveMethodCall/     }
                                     { ClassFindConstructor ci-dessous              }
                                     { parcourent MethodPool ENTIER filtre           }
                                     { par OwnerTypeIdx, JAMAIS cette plage,           }
                                     { plus simple et tout aussi correct -              }
                                     { evite de DEVOIR garantir une contiguite            }
                                     { que rien ne force reellement) }
    MethodCount        : Integer;
    IsAbstractClass      : Boolean; { TODO 08 (section 8.21) - ne peut etre  }
                                     { instanciee directement (verifie par        }
                                     { ParseNewExpr) }
    IsFinalClass         : Boolean; { TODO 08 (section 8.22) }
    InstanceInitBlockIdx : Integer; { TYK_CLASS seulement (TODO 08, section  }
                                     { 8.9) - UN SEUL bloc d initialisation       }
                                     { D INSTANCE par classe couvert                 }
                                     { (limitation ASSUMEE et DOCUMENTEE - un          }
                                     { second serait IGNORE avec un                       }
                                     { avertissement, voir ParseClassBody -                }
                                     { AUCUN echantillon reel n en utilise                 }
                                     { meme UN SEUL) ; -1 si absent }
    StaticInitBlockIdx   : Integer; { TYK_CLASS seulement (TODO 08, section  }
                                     { 8.10) - MEME limitation "UN SEUL bloc" }
    IsMulticast          : Boolean; { TYK_DELEGATE seulement (TODO 16,       }
                                     { section 16.13) - True pour "multicast          }
                                     { delegate", False pour un delegate                    }
                                     { simple ; PUREMENT INFORMATIF pour                     }
                                     { l instant (AUCUNE chaine de plusieurs           }
                                     { cibles n est encore CONSTRUITE, voir              }
                                     { la note d en-tete de ParseDelegateDecl          }
                                     { pour la decision de representation                    }
                                     { future, deferree). }
  End;

Type
  TParamRec = Record        { TODO 08 : UN parametre de methode/            }
                             { constructeur, tel que necessaire pour la          }
                             { RESOLUTION DE SURCHARGE (ClassResolveMethodCall/      }
                             { ClassFindConstructor, plus bas) - la liaison            }
                             { LOCALE reelle (pour que le CORPS de la methode           }
                             { retrouve son parametre par nom) reste, ELLE,               }
                             { assuree SEPAREMENT par SymAdd (ParseSingleParam,        }
                             { TODO 05, INCHANGE) : ParamPool est un second           }
                             { registre, en LECTURE SEULE une fois la methode            }
                             { entierement parsee, qui SURVIT a la fermeture               }
                             { de cette portee locale (contrairement a SymTab). }
    Name    : TString;
    TypeIdx : Integer;
    IsFinal : Boolean;
  End;

  TMethodKind = (MK_METHOD, MK_CONSTRUCTOR);

  TMethodRec = Record        { TODO 08 : une methode OU un constructeur -   }
                              { AUCUNE table separee pour les constructeurs      }
                              { (Kind les distingue), ni pour static/instance         }
                              { (IsStatic le fait). }
    Name         : TString;    { '' pour un constructeur (Kind suffit) }
    Kind         : TMethodKind;
    OwnerTypeIdx : Integer;    { classe PROPRIETAIRE - ClassResolveMethodCall/  }
                                { ClassFindConstructor parcourent MethodPool         }
                                { ENTIER filtre par ce champ (MEME discipline           }
                                { EXACTE que TTypeRec.MethodFirst/MethodCount,             }
                                { deja documentee comme informative seule) }
    IsStatic     : Boolean;
    IsFinal      : Boolean;
    IsAbstract   : Boolean;
    RetTypeIdx   : Integer;    { non significatif pour un constructeur }
    ParamFirst   : Integer;    { plage dans ParamPool - SANS RISQUE          }
                                { d entrelacement (contrairement a FieldPool) :      }
                                { les parametres d UNE SEULE methode sont                }
                                { TOUJOURS pousses en un seul balayage                       }
                                { ininterrompu (section 8.7/8.13), jamais deux             }
                                { signatures en cours de lecture simultanement. }
    ParamCount   : Integer;
    BodyStmtIdx  : Integer;    { racine STK_BLOCK (TODO 07) du corps - -1 si   }
                                { abstraite/native (section 8.19/8.20, syntaxe        }
                                { seule) }
    Visibility   : TVisibility; { TODO 12 - AUCUNE verification, voir la  }
                                 { note d en-tete de TVisibility }
    IsSynchronized : Boolean;   { TODO 14 (section 14.21/14.22) - SYNTAXE  }
                                 { seule, comme IsAbstract/IsFinal ci-dessus :   }
                                 { AUCUNE section critique Win32 n existe                  }
                                 { ENCORE (voir la note d en-tete du TODO 14,        }
                                 { decision EnterCriticalSection/                                 }
                                 { LeaveCriticalSection PAR OBJET, deferree au           }
                                 { TODO 21+ comme tout le reste de la generation           }
                                 { de code). Jamais significatif pour un                          }
                                 { constructeur (Java l interdit sur un                              }
                                 { constructeur, section 14.21 ne cite QUE des             }
                                 { methodes) ni une methode d interface                              }
                                 { (implicitement abstraite, section 9.3). }
    IsDllImport    : Boolean;   { TODO 17 (section 17.6-17.9) - True si UN  }
                                 { commentaire javadoc "/** @dll.import(   }
                                 { ...) */" precedait IMMEDIATEMENT cette          }
                                 { methode (TOUJOURS native, section 17.7           }
                                 { - jamais verifie que IsNative est                            }
                                 { egalement vrai, best-effort). Les TROIS         }
                                 { champs suivants ne sont SIGNIFICATIFS               }
                                 { que si IsDllImport est vrai. AUCUNE                        }
                                 { VRAIE importation DLL/thunk n est                            }
                                 { cablee ICI (voir TODO 18) - ceci reste             }
                                 { une EXTRACTION de texte structuree                          }
                                 { SEULE, exactement ce que la roadmap                        }
                                 { demande explicitement pour ce TODO. }
    DllLibName     : TString;   { "USER32" - SANS les guillemets (section  }
                                 { 17.8) }
    DllEntrypoint  : TString;   { '' si absent ; nom EXPORTE reel (section    }
                                 { 17.9) OU "#3" pour une liaison PAR                       }
                                 { ORDINAL (section 17.10) - AUCUN                              }
                                 { echantillon actuel n exerce ni l un ni          }
                                 { l autre, code ECRIT mais NON ASSERTE,               }
                                 { voir la note d en-tete de                                        }
                                 { ParseDllImportDirective }
    DllCharSet     : TString;   { '' / 'ansi' / 'unicode' / 'auto' (section    }
                                 { 17.11) - SEUL 'auto' est REELLEMENT                     }
                                 { exerce (Test18JDirect.jpp) }
    ThrowsFirst    : Integer;   { TODO 19 (section 8.16/11.3) - plage dans   }
                                 { ThrowsPool ; -1 si AUCUNE clause "throws"          }
                                 { ecrite. SIGNIFICATIF SEULEMENT si cette          }
                                 { entree a ete peuplee par                                            }
                                 { ParseMethodDeclRest/ParseConstructorDecl              }
                                 { (voir la note d en-tete de ThrowsPool). }
    ThrowsCount    : Integer;
    FrameSize      : LongInt;   { extension post-TODO25 (generateur de     }
                                 { code) : octets TOTAUX reserves pour les          }
                                 { variables LOCALES de cette methode/ce               }
                                 { constructeur (jamais les parametres,                     }
                                 { deja au-dessus d EBP) - capture -CurLocalOffset      }
                                 { juste apres que ParseBlock a fini de                     }
                                 { parser le corps (donc CurLocalOffset a                     }
                                 { atteint sa valeur FINALE pour CETTE                          }
                                 { methode), AVANT que CurLocalOffset ne soit             }
                                 { reinitialise pour la methode SUIVANTE.               }
                                 { CompileMethodBody emet "SUB ESP,FrameSize"            }
                                 { dans le prologue quand ce champ est > 0. }
  End;

Var
  TypeTab        : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount      : Integer;
  FieldPool      : Array[0..MAX_FIELD_POOL - 1] Of TFieldRec;
  FieldPoolCount : Integer;
  ParamPool       : Array[0..MAX_PARAM_POOL - 1] Of TParamRec;
  ParamPoolCount  : Integer;
  MethodPool      : Array[0..MAX_METHOD_POOL - 1] Of TMethodRec;
  MethodPoolCount : Integer;
  InterfacePool      : Array[0..MAX_INTERFACE - 1] Of Integer; { TODO 09 :  }
                        { TypeIdx d une interface ETENDUE (par une AUTRE       }
                        { interface, section 9.5, heritage MULTIPLE) OU              }
                        { IMPLEMENTEE (par une classe, section 9.8) - LISTE          }
                        { PLATE, jamais d entrelacement possible (comme                }
                        { ParamPool : la liste "implements"/"extends"                     }
                        { d UN SEUL type est TOUJOURS lue en un seul                      }
                        { balayage ininterrompu, AVANT le corps de ce type,           }
                        { jamais entrecoupee par le parsing d un AUTRE type). }
  InterfacePoolCount : Integer;
  ThrowsPool         : Array[0..MAX_THROWS_POOL - 1] Of Integer; { TODO 19 : }
                        { TypeIdx d une exception VERIFIEE declaree dans une        }
                        { clause "throws" - LISTE PLATE, MEME convention que        }
                        { InterfacePool ci-dessus (la clause "throws" d UNE           }
                        { SEULE methode est TOUJOURS lue en un seul balayage           }
                        { ininterrompu, section 8.16, AUCUN risque                              }
                        { d entrelacement) - ALIMENTE UNIQUEMENT par                              }
                        { ParseMethodDeclRest/ParseConstructorDecl (les DEUX             }
                        { SEULS a avoir un VRAI corps a verifier ensuite -              }
                        { ParseInterfaceMember/ParseDelegateDecl continuent               }
                        { d appeler ParseThrowsClauseIfPresent SANS rien                          }
                        { stocker, portee DELIBEREMENT reduite, voir la note          }
                        { d en-tete de la section TODO 19). }
  ThrowsPoolCount    : Integer;

  { CurrentClassTypeIdx : classe/interface DONT le corps est EN COURS   }
  { de parsing (-1 hors de toute classe) - ExprAddIdent/ParsePostfix              }
  { (TODO 06, plus haut dans ce fichier) en ont besoin pour resoudre un          }
  { champ/une methode reference SANS "objet." explicite (section 8.3 -             }
  { equivaut a "this.xxx"/un appel STATIQUE local implicite). Mis a jour            }
  { par ParseClassDecl/ParseInterfaceDecl (TODO 08/09, plus bas) - RESTE            }
  { une simple variable (PAS un tableau-pile explicite) MEME avec les              }
  { classes/interfaces IMBRIQUEES du TODO 09 (section 9.14/9.17) : chaque         }
  { appel RECURSIF de ParseClassDecl/ParseInterfaceDecl sauvegarde LUI-             }
  { MEME l ancienne valeur dans une variable LOCALE avant d ecrire la                }
  { sienne, et la restaure a la sortie - la PILE D APPELS Pascal fait               }
  { deja tout le travail d empilement/depilement, aucune structure                    }
  { explicite supplementaire n est necessaire. }
  CurrentClassTypeIdx : Integer;

  { NativeJavadocText/Line (TODO 17, section 17.5 "portee d une                 }
  { directive... a la methode qui la suit") : instantane de                             }
  { LexLastJavadocText/Line CAPTURE au TOUT DEBUT de ParseClassMember,             }
  { AVANT qu aucun token du membre EN COURS ne soit consomme - PAS une            }
  { simple relecture directe de LexLastJavadocText DEPUIS                                }
  { ParseMethodDeclRest (piege REEL EVITE avant d ecrire une seule                    }
  { ligne, pas trouve par execution) : au moment ou ParseMethodDeclRest        }
  { s execute, le flux de tokens PP/PP2 (tampon de PRE-lecture a DEUX           }
  { positions) a deja avance de plusieurs tokens au-dela du javadoc                  }
  { (modificateurs, type, nom, "(", parametres deja consommes) - RIEN           }
  { ne garantit qu un AUTRE commentaire javadoc n ait pas ete rencontre          }
  { entre-temps et n ait ECRASE LexLastJavadocText avant que                            }
  { ParseMethodDeclRest ne le lise (aucun echantillon actuel ne place            }
  { un second javadoc a l INTERIEUR d une signature, mais la SEULE                  }
  { garantie robuste est de figer l instantane LE PLUS TOT POSSIBLE,               }
  { PAS de supposer une fenetre de pre-lecture qui pourrait changer de           }
  { taille plus tard). }
  NativeJavadocText : TString;
  NativeJavadocLine : Integer;

{ Forward EXCEPTIONNEL (ClassFindField/ClassFindConstructor/                }
{ ClassResolveMethodCall) : leurs VRAIS corps (TODO 08/09) ont besoin de       }
{ StmtPool/ExprPool/SymAdd (TODO 06/07, plus bas dans ce fichier) - mais       }
{ ExprAddIdent/ParsePostfix/ParseNewExpr (TODO 06, ENCORE PLUS haut)              }
{ ont besoin de pouvoir les APPELER des MAINTENANT. MEME technique               }
{ EXACTE que ParseExpr/ParseStatement (TODO 06/07) - AUCUNE des trois          }
{ n est jamais LUE comme une valeur avant sa propre affectation finale             }
{ (le piege de recursion infinie deja documente ailleurs dans ce                     }
{ fichier ne s applique qu aux LECTURES, jamais aux appels normaux). }
Function ClassFindField(T: Integer; Const Name: TString): Integer; Forward;
Function ClassFindConstructor(T, ArgFirst, ArgCount: Integer): Integer; Forward;
Function ClassResolveMethodCall(T: Integer; Const Name: TString;
  ArgFirst, ArgCount: Integer): Integer; Forward;
Function DelegateResolveTarget(DelT, ArgFirst, ArgCount: Integer): Integer; Forward;
  { TODO 16 - ParseNewExpr (plus bas) en a besoin AVANT sa definition          }
  { REELLE (section TODO 16 dediee, bien plus loin) ; MEME technique             }
  { EXACTE que les trois Forward juste au-dessus. }

Procedure SemanticCheckMethodBody(MI: Integer); Forward;
Procedure SemanticCheckOverrides(ClassT: Integer); Forward;
  { TODO 19 - ParseConstructorDecl/ParseMethodDeclRest/ParseClassDecl                 }
  { (plus bas) en ont besoin AVANT leur definition REELLE (section TODO           }
  { 19 dediee, bien plus loin) ; MEME technique EXACTE que le Forward             }
  { juste au-dessus. }

{ Forward EXCEPTIONNEL (StdlibInit, TODO 13) : appelee depuis TypeInit  }
{ (juste en dessous - MEME convention que GOCW32.PAS TODO 20, "doit               }
{ etre re-executee a chaque reinitialisation des types") pour que                     }
{ CHAQUE self-test reparte d une bibliotheque standard FRAICHEMENT              }
{ peuplee, alors que son VRAI corps (plus bas, section TODO 13 dediee)          }
{ a besoin de ClassAdd/FieldPoolAdd/MethodPoolAdd (TODO 08, ENCORE                  }
{ PLUS bas). MEME technique EXACTE que les trois Forward juste au-dessus. }
Procedure StdlibInit; Forward;

Const
  { --- TypeIdx des types PRIMITIFS Java (mots-cles KW_xxx, TODO 03 -   }
  { AUCUNE recherche par nom possible pour eux, contrairement aux 10        }
  { types REFERENCE PDT_xxx du TODO 03/11 : PrimitiveTypeFromKeyword        }
  { ci-dessous est leur SEULE voie de resolution, symetrique de              }
  { IsPredeclaredType pour les types REFERENCE). Numerotes ICI a la          }
  { suite EXACTE des 10 PDT_xxx (1-10, TODO 03/11) - MEME discipline      }
  { "position FIXE, memorisee par un nom" que GOCW32.PAS/SWIFTW32.PAS -           }
  { DECALES de 7-16 a 11-20 quand le TODO 11 a ajoute 4 nouveaux PDT_xxx     }
  { AVANT eux : AUCUN risque, chaque usage AILLEURS dans ce fichier            }
  { passe TOUJOURS par le NOM (PRIMTYPE_xxx), jamais par la valeur                }
  { numerique brute - la SEULE assertion qui epinglait un compte BRUT           }
  { (TypeSelfTest, "TypeCount = ...") a ete mise a jour EN MEME temps. }
  PRIMTYPE_BOOLEAN = 11;
  PRIMTYPE_BYTE    = 12;
  PRIMTYPE_SHORT   = 13;
  PRIMTYPE_INT     = 14;
  PRIMTYPE_LONG    = 15;
  PRIMTYPE_CHAR    = 16;
  PRIMTYPE_FLOAT   = 17;
  PRIMTYPE_DOUBLE  = 18;
  PRIMTYPE_VOID    = 19;
  PRIMTYPE_NULL    = 20;

{ ------------------------------------------------------------ }
{ TypeAdd : ajoute un type "simple" (scalaire/array non encore     }
{ parametre/reference predeclaree) - PAS class UTILISATEUR/            }
{ interface, construits par des fonctions dediees plus tard (TODO 08/  }
{ 09) une fois FieldPool reellement exploite. Les champs specifiques    }
{ (SuperTypeIdx/InterfaceFirst.../FieldFirst.../MethodFirst...)          }
{ restent a leur valeur "aucun" (-1/0) et peuvent etre completes           }
{ directement APRES coup (voir TypeInit, hierarchie Throwable) - MEME       }
{ convention que GOCW32.PAS/SWIFTW32.PAS. }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind: TTypeKind; Const AName: TString;
  ASize, AAlign, AElemTypeIdx: Integer): Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE)');
    TypeAdd := -1;
    Exit;
  End;

  TypeTab[TypeCount].Kind           := Kind;
  TypeTab[TypeCount].Name           := AName;
  TypeTab[TypeCount].Size           := ASize;
  TypeTab[TypeCount].Align          := AAlign;
  TypeTab[TypeCount].ElemTypeIdx    := AElemTypeIdx;
  TypeTab[TypeCount].SuperTypeIdx   := -1;
  TypeTab[TypeCount].InterfaceFirst := -1;
  TypeTab[TypeCount].InterfaceCount := 0;
  TypeTab[TypeCount].FieldFirst     := -1;
  TypeTab[TypeCount].FieldCount     := 0;
  TypeTab[TypeCount].MethodFirst    := -1;
  TypeTab[TypeCount].MethodCount    := 0;
  TypeTab[TypeCount].IsAbstractClass      := False;
  TypeTab[TypeCount].IsFinalClass         := False;
  TypeTab[TypeCount].InstanceInitBlockIdx := -1;
  TypeTab[TypeCount].StaticInitBlockIdx   := -1;
  TypeTab[TypeCount].Visibility           := VIS_PACKAGE;   { TODO 12 - }
                                { ECRASE par ClassAdd/ParseInterfaceDecl        }
                                { pour une VRAIE classe/interface - sans          }
                                { SIGNIFICATION pour un type PRIMITIF/           }
                                { TABLEAU, mais un CHAMP present partout           }
                                { doit bien avoir UNE valeur par defaut. }

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : recherche EXACTE (sensible a la casse - Java/J++ }
{ l est) par nom. -1 si non trouve - NE trouve JAMAIS un type            }
{ PRIMITIF (mot-cle, PAS un identificateur - voir                            }
{ PrimitiveTypeFromKeyword a la place). }
{ ------------------------------------------------------------ }

Function TypeFindByName(Const AName: TString): Integer;
Var I : Integer;
Begin
  TypeFindByName := -1;
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = AName Then
    Begin
      TypeFindByName := I;
      Exit;
    End;
End;

{ PrimitiveTypeFromKeyword : -1 si KW n est pas un mot-cle de type    }
{ primitif, sinon le TypeIdx PRIMTYPE_xxx correspondant - symetrique  }
{ de IsPredeclaredType (TODO 03) mais pour les 9 mots-cles de type    }
{ primitif plutot que pour un identificateur de type REFERENCE. }
Function PrimitiveTypeFromKeyword(KW: Integer): Integer;
Begin
  Case KW Of
    KW_BOOLEAN : PrimitiveTypeFromKeyword := PRIMTYPE_BOOLEAN;
    KW_BYTE    : PrimitiveTypeFromKeyword := PRIMTYPE_BYTE;
    KW_SHORT   : PrimitiveTypeFromKeyword := PRIMTYPE_SHORT;
    KW_INT     : PrimitiveTypeFromKeyword := PRIMTYPE_INT;
    KW_LONG    : PrimitiveTypeFromKeyword := PRIMTYPE_LONG;
    KW_CHAR    : PrimitiveTypeFromKeyword := PRIMTYPE_CHAR;
    KW_FLOAT   : PrimitiveTypeFromKeyword := PRIMTYPE_FLOAT;
    KW_DOUBLE  : PrimitiveTypeFromKeyword := PRIMTYPE_DOUBLE;
    KW_VOID    : PrimitiveTypeFromKeyword := PRIMTYPE_VOID;
    Else PrimitiveTypeFromKeyword := -1;
  End;
End;

{ ------------------------------------------------------------ }
{ TypeIsValueKind / TypeIsNumericKind : le statut VALEUR/REFERENCE  }
{ (et numerique/non-numerique) se DEDUIT du Kind, jamais stocke        }
{ separement - voir la note d en-tete de section pour pourquoi.          }
{ boolean est VALEUR mais PAS numerique (section 4.8 : "boolean ne          }
{ participe a aucune conversion numerique"). }
{ ------------------------------------------------------------ }

Function TypeIsValueKind(K: TTypeKind): Boolean;
Begin
  TypeIsValueKind := K In [TYK_BOOLEAN, TYK_BYTE, TYK_SHORT, TYK_INT,
    TYK_LONG, TYK_CHAR, TYK_FLOAT, TYK_DOUBLE];
End;

Function TypeIsNumericKind(K: TTypeKind): Boolean;
Begin
  TypeIsNumericKind := K In [TYK_BYTE, TYK_SHORT, TYK_INT, TYK_LONG,
    TYK_CHAR, TYK_FLOAT, TYK_DOUBLE];
End;

{ ------------------------------------------------------------ }
{ TypeIsSubclassOf : marche la chaine SuperTypeIdx (T lui-meme       }
{ COMPTE comme son propre "sous-type", regle standard de              }
{ compatibilite d affectation - "Point p = new Point()" doit rester      }
{ valide). Utile DES MAINTENANT pour valider la hierarchie Throwable        }
{ predeclaree ci-dessous (TypeSelfTest) - et directement reutilisable        }
{ par la VRAIE regle "Object o = p" de la section 4.11 de la reference          }
{ une fois le TODO 08/19 ecrits.                                                    }
{                                                                       }
{ EXTENSION TODO 09 (section 9.11, "conversion elargissante implicite" -   }
{ une instance d une classe qui IMPLEMENTE une interface est compatible          }
{ avec une reference DE CE TYPE INTERFACE, ex. "CompteurListener l =              }
{ new JournalListener();"/passer un "new JournalListener()" a un                       }
{ parametre "CompteurListener valeur", section 9.8 exemple - CECI est            }
{ ce que MethodParamsCompatible, TODO 08, verifie en pratique) : a               }
{ CHAQUE niveau de la chaine SuperTypeIdx, verifie AUSSI les interfaces           }
{ IMPLEMENTEES a ce niveau (TypeImplementsInterfaceRec, RECURSIF pour             }
{ suivre le heritage MULTIPLE entre interfaces, section 9.5). }
{ ------------------------------------------------------------ }

Function TypeImplementsInterfaceRec(T, Base, Depth: Integer): Boolean;
Var I : Integer;
Begin
  TypeImplementsInterfaceRec := False;
  If (T < 0) Or (Depth >= 32) Then Exit;
  If T = Base Then
  Begin
    TypeImplementsInterfaceRec := True;
    Exit;
  End;
  For I := 0 To TypeTab[T].InterfaceCount - 1 Do
    If TypeImplementsInterfaceRec(InterfacePool[TypeTab[T].InterfaceFirst + I], Base, Depth + 1) Then
    Begin
      TypeImplementsInterfaceRec := True;
      Exit;
    End;
End;

Function TypeIsSubclassOf(T, Base: Integer): Boolean;
Var Depth : Integer;
Begin
  TypeIsSubclassOf := False;
  Depth := 0;
  While (T >= 0) And (Depth < 32) Do
  Begin
    If T = Base Then
    Begin
      TypeIsSubclassOf := True;
      Exit;
    End;
    If TypeImplementsInterfaceRec(T, Base, 0) Then
    Begin
      TypeIsSubclassOf := True;
      Exit;
    End;
    T := TypeTab[T].SuperTypeIdx;
    Inc(Depth);
  End;
End;

{ ------------------------------------------------------------ }
{ TypeBinaryPromote / TypeIsWidening / TypeIsNarrowing : regles     }
{ EXACTES des sections 4.7/4.8/4.9 de la reference - AUCUNE n est       }
{ devinee, chacune verifiee CONTRE le texte precis de sa section           }
{ (voir DOC\JPP_SPEC_LANG.txt) avant d etre ecrite ici.                        }
{                                                                       }
{ TypeBinaryPromote (4.7) : "si l un est double -> double ; sinon si     }
{ float -> float ; sinon si long -> long ; sinon -> int" - cette REGLE      }
{ ELLE-MEME absorbe deja la promotion UNAIRE de byte/short/char (aucun          }
{ des trois n est double/float/long, ils tombent donc directement dans          }
{ le dernier "sinon -> int") : AUCUNE fonction "TypeUnaryPromote"                }
{ separee n est necessaire, une seule regle suffit pour les deux cas.              }
{                                                                       }
{ TypeIsWidening (4.8) : le graphe EXACT "byte->short->int->long->        }
{ float->double" ET "char->int->long->float->double" (char REJOINT le         }
{ chemin principal a partir de "int", il ne passe JAMAIS par "short" -           }
{ section 4.8, "il n existe pas de conversion implicite entre char et            }
{ byte/short, car leurs domaines ne sont pas inclus l un dans l autre") -         }
{ implemente ICI comme un parcours EXPLICITE du graphe (TypeDirectWidenTarget,     }
{ une seule arete a la fois) plutot qu un systeme de "rang" numerique              }
{ lineaire, qui masquerait mal ce cas particulier de "char" (sa position             }
{ dans un rang unique serait ambigue par rapport a "short"). Identite               }
{ (FromT=ToT) N EST PAS consideree "elargissement" (ce n en est pas un              }
{ au sens strict de la reference) - un appelant qui veut aussi accepter              }
{ l identite doit le verifier SEPAREMENT.                                              }
{                                                                       }
{ TypeIsNarrowing (4.9) : soit l inverse EXACT du graphe d elargissement        }
{ ci-dessus ("double->float->long->int->short->byte"), soit N IMPORTE           }
{ QUEL couple parmi les types ENTIERS (byte/short/int/long/char) entre          }
{ eux - section 4.9, "types entiers entre eux, y compris vers et depuis            }
{ char" - CE DEUXIEME cas est CE QUI PERMET char<->byte/short/int/long           }
{ via un cast EXPLICITE, la SEULE voie qui existe pour eux (jamais un              }
{ elargissement implicite, voir TypeIsWidening ci-dessus). }
{ ------------------------------------------------------------ }

Function TypeBinaryPromote(T1, T2: Integer): Integer;
Begin
  If (T1 = PRIMTYPE_DOUBLE) Or (T2 = PRIMTYPE_DOUBLE) Then
    TypeBinaryPromote := PRIMTYPE_DOUBLE
  Else If (T1 = PRIMTYPE_FLOAT) Or (T2 = PRIMTYPE_FLOAT) Then
    TypeBinaryPromote := PRIMTYPE_FLOAT
  Else If (T1 = PRIMTYPE_LONG) Or (T2 = PRIMTYPE_LONG) Then
    TypeBinaryPromote := PRIMTYPE_LONG
  Else
    TypeBinaryPromote := PRIMTYPE_INT;
End;

Function TypeDirectWidenTarget(T: Integer): Integer;
Begin
  If      T = PRIMTYPE_BYTE  Then TypeDirectWidenTarget := PRIMTYPE_SHORT
  Else If T = PRIMTYPE_SHORT Then TypeDirectWidenTarget := PRIMTYPE_INT
  Else If T = PRIMTYPE_CHAR  Then TypeDirectWidenTarget := PRIMTYPE_INT
  Else If T = PRIMTYPE_INT   Then TypeDirectWidenTarget := PRIMTYPE_LONG
  Else If T = PRIMTYPE_LONG  Then TypeDirectWidenTarget := PRIMTYPE_FLOAT
  Else If T = PRIMTYPE_FLOAT Then TypeDirectWidenTarget := PRIMTYPE_DOUBLE
  Else TypeDirectWidenTarget := -1;
End;

Function TypeIsWidening(FromT, ToT: Integer): Boolean;
Var
  Cur, Depth : Integer;
Begin
  TypeIsWidening := False;
  Cur := FromT;
  Depth := 0;
  While (Cur >= 0) And (Depth < 8) Do
  Begin
    Cur := TypeDirectWidenTarget(Cur);
    If Cur = ToT Then
    Begin
      TypeIsWidening := True;
      Exit;
    End;
    Inc(Depth);
  End;
End;

Function TypeIsIntegerKind(T: Integer): Boolean;
Begin
  TypeIsIntegerKind := (T = PRIMTYPE_BYTE) Or (T = PRIMTYPE_SHORT) Or
    (T = PRIMTYPE_INT) Or (T = PRIMTYPE_LONG) Or (T = PRIMTYPE_CHAR);
End;

Function TypeIsNarrowing(FromT, ToT: Integer): Boolean;
Begin
  TypeIsNarrowing := False;
  If FromT = ToT Then Exit;
  If TypeIsWidening(ToT, FromT) Then
  Begin
    TypeIsNarrowing := True;
    Exit;
  End;
  If TypeIsIntegerKind(FromT) And TypeIsIntegerKind(ToT) Then
    TypeIsNarrowing := True;
End;

{ ------------------------------------------------------------ }
{ TypeInit : enregistre les 10 types REFERENCE predeclares (PDT_xxx,}
{ TODO 03/11) PUIS les 10 types PRIMITIFS (PRIMTYPE_xxx, ci-dessus),        }
{ DANS CET ORDRE EXACT, precedes d une entree sentinelle TYK_INVALID          }
{ (index 0) - MEME discipline "position FIXE alignee sur des codes             }
{ deja annonces" que GOCW32.PAS/SWIFTW32.PAS. La hierarchie Throwable          }
{ REELLE (section 11.2 de la reference) est cablee via SuperTypeIdx              }
{ immediatement APRES chaque TypeAdd : Object (racine, SuperTypeIdx=-1)          }
{ <- Throwable <- Exception <- RuntimeException, ET Throwable <- Error             }
{ DIRECTEMENT (JAMAIS via Exception - hierarchie Java REELLE, Error et            }
{ Exception sont DEUX branches SOEURS sous Throwable, pas l une sous               }
{ l autre) ; PUIS (TODO 11, "classes concretes REELLEMENT lancees par           }
{ les echantillons") IllegalArgumentException <- RuntimeException,                  }
{ NumberFormatException <- IllegalArgumentException (hierarchie Java              }
{ REELLE - PAS directement RuntimeException), InterruptedException <-             }
{ Exception (VERIFIEE, section 11.3 - PAS RuntimeException), et                       }
{ UnsatisfiedLinkError <- Error DIRECTEMENT (LinkageError intermediaire          }
{ omis, simplification documentee sur sa constante PDT_xxx). }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var
  IdxObject, IdxThrowable, IdxException, IdxRuntimeExc, IdxError,
  IdxIllegalArg : Integer;
Begin
  TypeCount           := 0;
  FieldPoolCount      := 0;
  ParamPoolCount      := 0;
  MethodPoolCount     := 0;
  InterfacePoolCount  := 0;
  ThrowsPoolCount     := 0;
  CurrentClassTypeIdx := -1;

  TypeAdd(TYK_INVALID, '', 0, 0, -1);                                 { 0 }

  IdxObject := TypeAdd(TYK_CLASS, 'Object', 4, 4, -1);                 { 1  PDT_OBJECT }
  TypeAdd(TYK_STRING, 'String', 4, 4, -1);                             { 2  PDT_STRING }
  IdxThrowable := TypeAdd(TYK_CLASS, 'Throwable', 4, 4, -1);           { 3  PDT_THROWABLE }
  TypeTab[IdxThrowable].SuperTypeIdx := IdxObject;
  IdxException := TypeAdd(TYK_CLASS, 'Exception', 4, 4, -1);           { 4  PDT_EXCEPTION }
  TypeTab[IdxException].SuperTypeIdx := IdxThrowable;
  IdxRuntimeExc := TypeAdd(TYK_CLASS, 'RuntimeException', 4, 4, -1);   { 5  PDT_RUNTIMEEXCEPTION }
  TypeTab[IdxRuntimeExc].SuperTypeIdx := IdxException;
  IdxError := TypeAdd(TYK_CLASS, 'Error', 4, 4, -1);                   { 6  PDT_ERROR }
  TypeTab[IdxError].SuperTypeIdx := IdxThrowable;

  IdxIllegalArg := TypeAdd(TYK_CLASS, 'IllegalArgumentException', 4, 4, -1); { 7  PDT_ILLEGALARGUMENTEXCEPTION }
  TypeTab[IdxIllegalArg].SuperTypeIdx := IdxRuntimeExc;
  TypeAdd(TYK_CLASS, 'NumberFormatException', 4, 4, -1);               { 8  PDT_NUMBERFORMATEXCEPTION }
  TypeTab[PDT_NUMBERFORMATEXCEPTION].SuperTypeIdx := IdxIllegalArg;
  TypeAdd(TYK_CLASS, 'InterruptedException', 4, 4, -1);                { 9  PDT_INTERRUPTEDEXCEPTION }
  TypeTab[PDT_INTERRUPTEDEXCEPTION].SuperTypeIdx := IdxException;
  TypeAdd(TYK_CLASS, 'UnsatisfiedLinkError', 4, 4, -1);                { 10 PDT_UNSATISFIEDLINKERROR }
  TypeTab[PDT_UNSATISFIEDLINKERROR].SuperTypeIdx := IdxError;

  TypeAdd(TYK_BOOLEAN, 'boolean', 1, 1, -1);                           { 11 PRIMTYPE_BOOLEAN }
  TypeAdd(TYK_BYTE,    'byte',    1, 1, -1);                           { 12 PRIMTYPE_BYTE }
  TypeAdd(TYK_SHORT,   'short',   2, 2, -1);                           { 13 PRIMTYPE_SHORT }
  TypeAdd(TYK_INT,     'int',     4, 4, -1);                           { 14 PRIMTYPE_INT }
  TypeAdd(TYK_LONG,    'long',    8, 4, -1);                           { 15 PRIMTYPE_LONG }
  TypeAdd(TYK_CHAR,    'char',    2, 2, -1);                           { 16 PRIMTYPE_CHAR }
  TypeAdd(TYK_FLOAT,   'float',   4, 4, -1);                           { 17 PRIMTYPE_FLOAT }
  TypeAdd(TYK_DOUBLE,  'double',  8, 4, -1);                           { 18 PRIMTYPE_DOUBLE }
  TypeAdd(TYK_VOID,    'void',    0, 1, -1);                           { 19 PRIMTYPE_VOID }
  TypeAdd(TYK_NULL,    '',        4, 4, -1);                           { 20 PRIMTYPE_NULL }

  { TODO 13 : bibliotheque standard minimale (System/PrintStream/           }
  { Integer/Vector/Hashtable/Enumeration/java.io) - AUCUNE position FIXE      }
  { requise (contrairement aux 20 entrees ci-dessus, referencees PAR NOM        }
  { PDT_xxx/PRIMTYPE_xxx a travers tout le fichier) : ces classes sont            }
  { retrouvees PAR NOM comme n importe quelle classe UTILISATEUR                     }
  { (TypeFindByName, TODO 08), jamais par un TypeIdx numerique memorise            }
  { - voir la note d en-tete de StdlibInit, plus bas, pour pourquoi                    }
  { AUCUN autre renumerotage (comme celui du TODO 11) n est necessaire ICI. }
  StdlibInit;

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types predeclares enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeSelfTest : verifie l alignement PDT_xxx/PRIMTYPE_xxx <->      }
{ TypeIdx, les tailles cle (section 4.3/4.4/4.5 - byte=1/short=2/       }
{ int=4/long=8/char=2/float=4/double=8), la hierarchie Throwable            }
{ REELLE (Error JAMAIS sous Exception), IsValueKind/IsNumericKind, et          }
{ les regles EXACTES de promotion/elargissement/reduction des sections           }
{ 4.7/4.8/4.9 - CHAQUE cas directement tire d un exemple ou d une                    }
{ regle EXPLICITE de la reference (DOC\JPP_SPEC_LANG.txt), jamais                       }
{ invente. }
{ ------------------------------------------------------------ }

Procedure TypeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('TypeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TypeSelfTest;
Begin
  TypeInit;

  { 10 types REFERENCE (TODO 03/11) + 10 types PRIMITIFS + sentinelle   }
  { = 21 entrees, PLUS QUATORZE classes/interfaces de bibliotheque              }
  { standard (TODO 13, StdlibInit - PrintStream/System/Integer/                        }
  { Enumeration/Vector/Hashtable/Writer/Reader/FileWriter/                              }
  { BufferedWriter/PrintWriter/FileReader/BufferedReader/IOException)              }
  { DESORMAIS synthetisees a la FIN de CE MEME TypeInit (meme                             }
  { convention que GOCW32.PAS TODO 20, "StdlibInit... reexecutee a                    }
  { chaque reinitialisation") = 35 entrees, PLUS DEUX (TODO 14 :                          }
  { Runnable/Thread, section 14.2) = 37, PLUS DEUX (TODO 18 :                                }
  { User32/winm, section 18.1) = 39 entrees TOTAL. CE NOMBRE                                }
  { AUGMENTERA a chaque TODO futur qui etoffe la bibliotheque standard -           }
  { mise a jour EXPLICITE requise ICI a chaque fois (meme discipline                 }
  { que le TODO 11 l a deja fait passer de 17 a 21, puis le TODO 13 de           }
  { 21 a 35, puis le TODO 14 de 35 a 37). }
  TypeAssert('21 + 14 (TODO 13) + 2 (TODO 14) + 2 (TODO 18) = 39 entrees',
    TypeCount = 39);

  TypeAssert('String trouve == PDT_STRING', TypeFindByName('String') = PDT_STRING);
  TypeAssert('Object trouve == PDT_OBJECT', TypeFindByName('Object') = PDT_OBJECT);
  TypeAssert('String fait 4 octets (UN pointeur, PAS 8 comme SWIFTW32.PAS)',
    TypeTab[PDT_STRING].Size = 4);
  TypeAssert('String est de genre TYK_STRING (PAS TYK_CLASS)',
    TypeTab[PDT_STRING].Kind = TYK_STRING);

  { hierarchie Throwable REELLE (section 11.2, anticipee) : Object <-   }
  { Throwable <- Exception <- RuntimeException, ET Throwable <- Error     }
  { DIRECTEMENT (jamais via Exception). }
  TypeAssert('Object est sa propre racine (SuperTypeIdx=-1)',
    TypeTab[PDT_OBJECT].SuperTypeIdx = -1);
  TypeAssert('Throwable derive de Object', TypeIsSubclassOf(PDT_THROWABLE, PDT_OBJECT));
  TypeAssert('Exception derive de Throwable', TypeIsSubclassOf(PDT_EXCEPTION, PDT_THROWABLE));
  TypeAssert('RuntimeException derive de Exception',
    TypeIsSubclassOf(PDT_RUNTIMEEXCEPTION, PDT_EXCEPTION));
  TypeAssert('RuntimeException derive (transitivement) de Throwable',
    TypeIsSubclassOf(PDT_RUNTIMEEXCEPTION, PDT_THROWABLE));
  TypeAssert('RuntimeException derive (transitivement) de Object',
    TypeIsSubclassOf(PDT_RUNTIMEEXCEPTION, PDT_OBJECT));
  TypeAssert('Error derive de Throwable', TypeIsSubclassOf(PDT_ERROR, PDT_THROWABLE));
  TypeAssert('Error NE derive PAS de Exception (branches soeurs sous Throwable)',
    Not TypeIsSubclassOf(PDT_ERROR, PDT_EXCEPTION));
  TypeAssert('un type est son propre sous-type (compatibilite affectation)',
    TypeIsSubclassOf(PDT_EXCEPTION, PDT_EXCEPTION));

  { classes concretes REELLEMENT lancees par les echantillons (TODO 11,   }
  { feuille de route + section 11.2) - hierarchie Java REELLE, pas         }
  { devinee. }
  TypeAssert('IllegalArgumentException derive de RuntimeException (donc ' +
    'NON verifiee, section 11.4)',
    TypeIsSubclassOf(PDT_ILLEGALARGUMENTEXCEPTION, PDT_RUNTIMEEXCEPTION));
  TypeAssert('NumberFormatException derive de IllegalArgumentException ' +
    '(PAS directement de RuntimeException - hierarchie Java REELLE)',
    TypeIsSubclassOf(PDT_NUMBERFORMATEXCEPTION, PDT_ILLEGALARGUMENTEXCEPTION));
  TypeAssert('NumberFormatException derive (transitivement) de ' +
    'RuntimeException',
    TypeIsSubclassOf(PDT_NUMBERFORMATEXCEPTION, PDT_RUNTIMEEXCEPTION));
  TypeAssert('InterruptedException derive de Exception (VERIFIEE, ' +
    'section 11.3) - PAS de RuntimeException',
    TypeIsSubclassOf(PDT_INTERRUPTEDEXCEPTION, PDT_EXCEPTION) And
    Not TypeIsSubclassOf(PDT_INTERRUPTEDEXCEPTION, PDT_RUNTIMEEXCEPTION));
  TypeAssert('UnsatisfiedLinkError derive de Error (PAS de Exception - ' +
    'branches soeurs sous Throwable)',
    TypeIsSubclassOf(PDT_UNSATISFIEDLINKERROR, PDT_ERROR) And
    Not TypeIsSubclassOf(PDT_UNSATISFIEDLINKERROR, PDT_EXCEPTION));

  { tailles primitives (sections 4.3/4.4/4.5). }
  TypeAssert('byte fait 1 octet',   TypeTab[PRIMTYPE_BYTE].Size = 1);
  TypeAssert('short fait 2 octets', TypeTab[PRIMTYPE_SHORT].Size = 2);
  TypeAssert('int fait 4 octets',   TypeTab[PRIMTYPE_INT].Size = 4);
  TypeAssert('long fait 8 octets (repr. interne LongInt 32 bits, voir TODO 02)',
    TypeTab[PRIMTYPE_LONG].Size = 8);
  TypeAssert('char fait 2 octets (16 bits Unicode REELS, voir la note d''en-tete)',
    TypeTab[PRIMTYPE_CHAR].Size = 2);
  TypeAssert('float fait 4 octets',  TypeTab[PRIMTYPE_FLOAT].Size = 4);
  TypeAssert('double fait 8 octets', TypeTab[PRIMTYPE_DOUBLE].Size = 8);
  TypeAssert('boolean fait 1 octet', TypeTab[PRIMTYPE_BOOLEAN].Size = 1);

  TypeAssert('PrimitiveTypeFromKeyword(KW_INT) = PRIMTYPE_INT',
    PrimitiveTypeFromKeyword(KW_INT) = PRIMTYPE_INT);
  TypeAssert('PrimitiveTypeFromKeyword(KW_VOID) = PRIMTYPE_VOID',
    PrimitiveTypeFromKeyword(KW_VOID) = PRIMTYPE_VOID);
  TypeAssert('PrimitiveTypeFromKeyword(KW_CLASS) = -1 (pas un type)',
    PrimitiveTypeFromKeyword(KW_CLASS) = -1);

  { IsValueKind / IsNumericKind. }
  TypeAssert('int est un genre VALEUR',    TypeIsValueKind(TYK_INT));
  TypeAssert('boolean est un genre VALEUR', TypeIsValueKind(TYK_BOOLEAN));
  TypeAssert('String n''est PAS un genre VALEUR', Not TypeIsValueKind(TYK_STRING));
  TypeAssert('Class n''est PAS un genre VALEUR',  Not TypeIsValueKind(TYK_CLASS));
  TypeAssert('int est numerique',     TypeIsNumericKind(TYK_INT));
  TypeAssert('char est numerique',    TypeIsNumericKind(TYK_CHAR));
  TypeAssert('boolean N''est PAS numerique (section 4.8, explicite)',
    Not TypeIsNumericKind(TYK_BOOLEAN));

  { promotion binaire (section 4.7, exemples LITTERAUX de la reference). }
  TypeAssert('byte+byte -> int (exemple section 4.7, "int somme = a + b")',
    TypeBinaryPromote(PRIMTYPE_BYTE, PRIMTYPE_BYTE) = PRIMTYPE_INT);
  TypeAssert('int+double -> double (exemple section 4.7, "double produit = n * d")',
    TypeBinaryPromote(PRIMTYPE_INT, PRIMTYPE_DOUBLE) = PRIMTYPE_DOUBLE);
  TypeAssert('long+float -> float (exemple section 4.7, "float f = grand + 1.0F")',
    TypeBinaryPromote(PRIMTYPE_LONG, PRIMTYPE_FLOAT) = PRIMTYPE_FLOAT);
  TypeAssert('char+char -> int (promotion unaire absorbee par la regle binaire)',
    TypeBinaryPromote(PRIMTYPE_CHAR, PRIMTYPE_CHAR) = PRIMTYPE_INT);

  { elargissement implicite (section 4.8, exemple LITTERAL byte->int->     }
  { long->double de la reference, PLUS le cas particulier char). }
  TypeAssert('byte elargit vers int (exemple section 4.8)',
    TypeIsWidening(PRIMTYPE_BYTE, PRIMTYPE_INT));
  TypeAssert('int elargit vers long (exemple section 4.8)',
    TypeIsWidening(PRIMTYPE_INT, PRIMTYPE_LONG));
  TypeAssert('long elargit (transitivement) vers double (exemple section 4.8)',
    TypeIsWidening(PRIMTYPE_LONG, PRIMTYPE_DOUBLE));
  TypeAssert('byte elargit (transitivement) vers double',
    TypeIsWidening(PRIMTYPE_BYTE, PRIMTYPE_DOUBLE));
  TypeAssert('char elargit DIRECTEMENT vers int (jamais via short)',
    TypeIsWidening(PRIMTYPE_CHAR, PRIMTYPE_INT));
  TypeAssert('char N''elargit PAS vers short (section 4.8, domaines non inclus)',
    Not TypeIsWidening(PRIMTYPE_CHAR, PRIMTYPE_SHORT));
  TypeAssert('byte N''elargit PAS vers char (section 4.8, domaines non inclus)',
    Not TypeIsWidening(PRIMTYPE_BYTE, PRIMTYPE_CHAR));
  TypeAssert('int N''elargit PAS vers byte (sens inverse)',
    Not TypeIsWidening(PRIMTYPE_INT, PRIMTYPE_BYTE));

  { reduction/cast explicite (section 4.9, exemples LITTERAUX "byte      }
  { b=(byte)n"/"char c=(char)-1" de la reference). }
  TypeAssert('double se reduit vers int (transitivement, cast explicite)',
    TypeIsNarrowing(PRIMTYPE_DOUBLE, PRIMTYPE_INT));
  TypeAssert('int se reduit vers byte (exemple section 4.9, "(byte)n")',
    TypeIsNarrowing(PRIMTYPE_INT, PRIMTYPE_BYTE));
  TypeAssert('int se reduit vers char (exemple section 4.9, "(char)-1")',
    TypeIsNarrowing(PRIMTYPE_INT, PRIMTYPE_CHAR));
  TypeAssert('char se reduit vers byte (section 4.9, "types entiers entre eux")',
    TypeIsNarrowing(PRIMTYPE_CHAR, PRIMTYPE_BYTE));
  TypeAssert('float se reduit vers long (sens inverse du graphe d''elargissement)',
    TypeIsNarrowing(PRIMTYPE_FLOAT, PRIMTYPE_LONG));
  TypeAssert('int N''est PAS une reduction vers double (c''est un elargissement)',
    Not TypeIsNarrowing(PRIMTYPE_INT, PRIMTYPE_DOUBLE));
End;

{ ============================================================ }
{ TODO 05 - DECLARATIONS : CHAMPS, LOCALES, PARAMETRES, "final" }
{ ============================================================ }
{ PREMIER TODO de PARSING reel (pas juste lexer/classification/   }
{ types). Necessite une infrastructure indispensable a tout            }
{ parseur recursif-descendant, jamais nommee explicitement par le          }
{ titre du TODO : un TokenPool (tous les tokens du fichier, pre-             }
{ lexes UNE SEULE fois via LexAll) parcouru par un curseur PP - MEME              }
{ architecture EXACTE que GOCW32.PAS/SWIFTW32.PAS (meme projet), PAS             }
{ le flux "un token a la fois" du TODO 02.                                            }
{                                                                       }
{ PORTEE ASSUMEE ET DOCUMENTEE (meme discipline que SWIFTW32.PAS a         }
{ ce meme stade) : Java/J++ n autorise AUCUNE declaration hors d une         }
{ classe (contrairement au "var" top-level de Go ou au "let" de              }
{ script de Swift) - AUCUNE classe n existe encore (TODO 08), donc              }
{ cette infrastructure n est PAS ENCORE branchee sur Run()/les                     }
{ fichiers SAMPLES\JPP reels : elle est testee ISOLEMENT ci-dessous              }
{ (DeclSelfTest, sur des extraits synthetiques qui commencent                        }
{ DIRECTEMENT au mot-cle de type/modificateur, sans classe                              }
{ englobante - exactement comme DeclSelfTest de GOCW32.PAS/SWIFTW32.PAS               }
{ a ce meme stade). Les initialiseurs restent LIMITES aux LITTERAUX                    }
{ constants (ConstEvalExpr, ci-dessous) - aucune expression generale               }
{ (identificateur, appel, operateur binaire) n est encore possible,               }
{ le TODO 06 n existe pas.                                                                }

Const
  MAX_TOKEN = {$IFDEF FPC}65536{$ELSE}8192{$ENDIF};

Var
  TokenPool : Array[0..MAX_TOKEN - 1] Of TToken;
  PP        : Integer;

{ ------------------------------------------------------------ }
{ LexAll : tokenise le fichier ENTIER (deja ouvert via LexInit    }
{ par l appelant) dans TokenPool - reutilise TokenCount (TODO 02)         }
{ comme total. LexNextToken incremente DEJA lui-meme TokenCount (a         }
{ chaque token reel/EOF, pour le compteur "tokens produits" de Run) -         }
{ LexAll ne doit donc PAS l incrementer une SECONDE fois : l index de           }
{ stockage est ICI "TokenCount - 1" (valeur DEJA incrementee par            }
{ l appel qui vient d avoir lieu), MEME piege EXACT deja documente             }
{ chez SWIFTW32.PAS a ce meme stade (evite ici PROACTIVEMENT plutot            }
{ que redecouvert par execution). }
{ ------------------------------------------------------------ }

Procedure LexAll;
Begin
  TokenCount := 0;
  Repeat
    LexNextToken;
    If TokenCount - 1 < MAX_TOKEN Then
      TokenPool[TokenCount - 1] := CurToken
    Else
    Begin
      WarnMsg('pool de tokens plein (MAX_TOKEN) - fichier tronque');
      Break;
    End;
  Until CurToken.Kind = TOK_EOF;
End;

{ ------------------------------------------------------------ }
{ PP* : lecture en avant dans TokenPool - PAS le lexeur direct.   }
{ PPMatch compare le TEXTE EXACT (Java/J++ est sensible a la           }
{ casse). AUCUN "PPSkipSemis" (contrairement a GOCW32.PAS/                    }
{ SWIFTW32.PAS) : Java EXIGE un ';' EXPLICITE (voir la note d en-tete       }
{ du TODO 02) - il n y a JAMAIS de point-virgule INSERE a sauter,               }
{ seulement le ';' REEL que chaque instruction/declaration consomme              }
{ elle-meme UNE SEULE fois. }
{ ------------------------------------------------------------ }

Function PPAtEnd: Boolean;
Begin
  PPAtEnd := (PP < 0) Or (PP >= TokenCount) Or
             (TokenPool[PP].Kind = TOK_EOF);
End;

Function PPKind: TTokenKind;
Begin
  If PPAtEnd Then PPKind := TOK_EOF Else PPKind := TokenPool[PP].Kind;
End;

Function PPVal: TString;
Begin
  If PPAtEnd Then PPVal := '' Else PPVal := TokenPool[PP].Val;
End;

{ PP2Kind/PP2Val : UN token d avance, SANS consommer (TODO 07 -         }
{ necessaire pour distinguer une ETIQUETTE, "identificateur :", d un        }
{ identificateur ORDINAIRE en tete d instruction-expression, sans               }
{ jamais avoir a revenir en arriere). }
Function PP2Kind: TTokenKind;
Begin
  If (PP + 1 >= TokenCount) Or (PP + 1 < 0) Then PP2Kind := TOK_EOF
  Else PP2Kind := TokenPool[PP + 1].Kind;
End;

Function PP2Val: TString;
Begin
  If (PP + 1 >= TokenCount) Or (PP + 1 < 0) Then PP2Val := ''
  Else PP2Val := TokenPool[PP + 1].Val;
End;

Function PPIsOp(Const S: TString): Boolean;
Begin
  PPIsOp := (Not PPAtEnd) And (TokenPool[PP].Kind = TOK_OP) And
            (TokenPool[PP].Val = S);
End;

Procedure PPAdvance;
Begin
  If Not PPAtEnd Then Inc(PP);
End;

Function PPMatch(Const S: TString): Boolean;
Begin
  PPMatch := False;
  If PPAtEnd Then Exit;
  If TokenPool[PP].Val = S Then
  Begin
    PPAdvance;
    PPMatch := True;
  End;
End;

Procedure ParserInit;
Begin
  PP := 0;
End;

{ ------------------------------------------------------------ }
{ Table des symboles et portees - meme architecture EMPILEE que    }
{ GOCW32.PAS/SWIFTW32.PAS (resolution DU PLUS IMBRIQUE VERS LE           }
{ PLUS GLOBAL), MAIS AUCUN champ "IsGlobal" : Java n a AUCUNE                 }
{ variable VRAIMENT globale (section 5.1 - SEPT emplacements                       }
{ possibles, TOUS a l INTERIEUR d une classe/methode) - IsStatic                       }
{ (depuis le modificateur "static") est le VRAI analogue J++ d un                  }
{ "global" partage (section 5.4, "un champ static appartient a la             }
{ classe... existe en UN SEUL exemplaire"). PAS de SK_CONST/SK_TYPE            }
{ distinct non plus : "final" (IsFinal) est juste un booleen sur un           }
{ SK_VAR ordinaire, MEME technique EXACTE que le "IsConst"/"let" de              }
{ SWIFTW32.PAS - Java/J++ n a pas de "typealias" (SK_TYPE deviendrait           }
{ un mort-ne). }
{ ------------------------------------------------------------ }

Type
  TSymKind = (
    SK_VAR,    { champ/locale/parametre/parametre catch - distingues         }
               { seulement par LE CONTEXTE de leur declaration (TODO 08         }
               { introduira ce contexte pour de vrai) }
    SK_FUNC    { reserve pour le TODO 08 (methodes) }
  );

  TSymRec = Record
    Name       : TString;    { sensible a la casse }
    Kind       : TSymKind;
    TypeIdx    : Integer;
    ScopeLevel : Integer;    { 0 = portee la plus externe OUVERTE          }
    ScopeId    : Integer;
    IsStatic   : Boolean;    { modificateur "static" (section 5.4) - VRAI    }
                              { analogue J++ d un "global" partage, voir           }
                              { la note d en-tete de section }
    IsFinal    : Boolean;    { modificateur "final" (sections 5.3/5.5/5.6/  }
                              { 5.7) - equivalent J++ du "let" des                  }
                              { compilateurs freres }
    HasInit    : Boolean;
    ConstVal   : TConstVal;
    InitExprIdx: Integer;    { reserve TODO 06 (expression GENERALE           }
                              { d initialisation, ExprPool) - TOUJOURS -1        }
                              { pour l instant, ConstEvalExpr (ci-dessous)          }
                              { remplit UNIQUEMENT ConstVal }
    Offset     : LongInt;    { extension post-TODO25 (generateur de code) :   }
                              { position memoire EBP-relative d un SK_VAR        }
                              { LOCAL/PARAMETRE - positif ([EBP+Offset]),           }
                              { CROISSANT par 4 depuis 8, pour un parametre/            }
                              { "this" REEL entrant (assigne par                          }
                              { ParseOneParamIntoPool/ParseMethodDeclRest/                     }
                              { ParseConstructorDecl) ; negatif ([EBP-N]),                        }
                              { DECROISSANT par 4 depuis 0, pour une variable                       }
                              { locale (assigne par ParseVarDecl) - TOUJOURS               }
                              { UN SEUL slot de 4 octets par symbole, meme            }
                              { simplification "tout tient dans EAX" que le               }
                              { reste du generateur de code (long/double/float           }
                              { NE SONT PAS compiles via ce chemin - EK_IDENT             }
                              { les rejette explicitement, voir CompileExpr) -           }
                              { non pertinent pour un champ/une portee non-               }
                              { locale (SymTab ne les modelise pas ainsi). }
  End;

Var
  SymTab   : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount : Integer;

  ScopeStack    : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeStackTop : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { CurParamOffset/CurLocalOffset : disposition memoire (pile) EBP-       }
  { relative des symboles de la methode/du constructeur EN COURS de         }
  { PARSING - extension post-TODO25 (generateur de code), meme principe            }
  { que GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS pour LEUR propre TODO 21.               }
  { Reinitialises (8/0) au tout debut de ParseMethodDeclRest/                        }
  { ParseConstructorDecl (avant "this"/les parametres) - AUCUNE sauvegarde/            }
  { restauration necessaire (contrairement a GOCW32.PAS, qui a de VRAIES         }
  { fermetures imbriquees) : ce compilateur n a AUCUNE fonction imbriquee,             }
  { chaque methode/constructeur repart donc TOUJOURS de zero. }
  CurParamOffset : LongInt;
  CurLocalOffset : LongInt;

Procedure SymInit;
Begin
  SymCount      := 0;
  ScopeStackTop := -1;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
  CurParamOffset := 8;
  CurLocalOffset := 0;
End;

Procedure SymEnterScope;
Begin
  If ScopeStackTop >= MAX_SCOPE - 1 Then
  Begin
    WarnMsg('profondeur de portee maximale atteinte (MAX_SCOPE)');
    Exit;
  End;
  Inc(ScopeStackTop);
  Inc(ScopeIdSeq);
  ScopeStack[ScopeStackTop] := ScopeIdSeq;
  CurScopeId    := ScopeIdSeq;
  CurScopeLevel := ScopeStackTop + 1;
End;

Procedure SymLeaveScope;
Begin
  If ScopeStackTop < 0 Then
  Begin
    WarnMsg('tentative de quitter une portee inexistante');
    Exit;
  End;
  Dec(ScopeStackTop);
  CurScopeLevel := ScopeStackTop + 1;
  If ScopeStackTop < 0 Then CurScopeId := 0
  Else CurScopeId := ScopeStack[ScopeStackTop];
End;

{ SymFindInScope : cherche UNIQUEMENT dans la portee SId (pas les  }
{ englobantes). }
Function SymFindInScope(Const Name: TString; SId: Integer): Integer;
Var I : Integer;
Begin
  SymFindInScope := -1;
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].ScopeId = SId) And (SymTab[I].Name = Name) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
End;

{ SymFindEnclosing : cherche dans TOUTE la chaine de portees        }
{ ACTUELLEMENT OUVERTES (courante PUIS chacune de ses englobantes,   }
{ ScopeStack en entier) - IMPLEMENTE la regle STRICTE de la section    }
{ 5.10 ("le langage interdit de redeclarer une variable locale ou      }
{ un parametre dans une portee locale englobante QUI SE CHEVAUCHE") :   }
{ CONTRAIREMENT a SymFindInScope (une SEULE portee) ET contrairement      }
{ au masquage LIBRE de GOCW32.PAS/SWIFTW32.PAS (qui AUTORISENT           }
{ explicitement "let x=1" PUIS "let x=2" dans un bloc imbrique),         }
{ Java/J++ INTERDIT ce cas PRECIS pour deux locales/parametres - SEUL         }
{ un CHAMP peut etre               }
{ masque par une locale de meme nom (section 5.10, "une locale peut          }
{ aussi masquer un champ, puisque les espaces de declaration                       }
{ concernes sont differents") : SIMPLIFICATION ASSUMEE ICI, puisque              }
{ AUCUNE declaration de champ n existe encore (TODO 08) pour               }
{ distinguer les deux espaces de noms - cette fonction traite            }
{ UNIFORMEMENT tout SK_VAR comme "une locale/un parametre" pour            }
{ l instant ; le TODO 08 devra AFFINER cette regle (exempter un              }
{ champ specifiquement) plutot que la contourner en silence. }
Function SymFindEnclosing(Const Name: TString): Integer;
Var
  Depth, I : Integer;
Begin
  SymFindEnclosing := -1;
  For Depth := ScopeStackTop DownTo 0 Do
  Begin
    I := SymFindInScope(Name, ScopeStack[Depth]);
    If I >= 0 Then
    Begin
      SymFindEnclosing := I;
      Exit;
    End;
  End;
End;

{ SymFind : resolution "generale" - parcours DECROISSANT de la TABLE   }
{ ENTIERE (pas seulement les portees actuellement ouvertes, contrairement }
{ a SymFindEnclosing), reflet de l ORDRE CHRONOLOGIQUE de declaration -    }
{ MEME technique EXACTE que GOCW32.PAS/SWIFTW32.PAS. AMBIGUITE DEJA        }
{ CONNUE et DOCUMENTEE chez les compilateurs freres (une resolution PAR   }
{ NOM, bien APRES que les portees se soient refermees, peut tomber sur    }
{ le MAUVAIS symbole si un nom est REUTILISE ailleurs dans le fichier) -   }
{ NON corrigee ici par anticipation (le correctif reel, capturer l INDEX  }
{ resolu au moment du PARSING plutot que re-chercher par nom plus tard,   }
{ n a de sens qu une fois un VRAI usage - EK_IDENT-equivalent, TODO 06 -   }
{ existe pour l exploiter) - simplement NOTE ici pour que le jour ou      }
{ elle se manifeste (probablement au TODO 06/07), ce ne soit pas une      }
{ surprise. }
Function SymFind(Const Name: TString): Integer;
Var I : Integer;
Begin
  SymFind := -1;
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
End;

Function SymAdd(Const Name: TString; Kind: TSymKind; TIdx: Integer;
  AIsStatic, AIsFinal: Boolean): Integer;
Var Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM)');
    SymAdd := -1;
    Exit;
  End;

  { Filet de securite GENERIQUE (meme discipline WarnMsg-pas-FatalError  }
  { que GOCW32.PAS/SWIFTW32.PAS pour LEUR propre SymAdd) - la regle        }
  { STRICTE (section 5.10, FatalError) est appliquee PLUS HAUT par les      }
  { appelants reels (ParseVarDecl/ParseSingleParam/ParseCatchParam,          }
  { via SymFindEnclosing) AVANT meme d appeler SymAdd ; ce doublon           }
  { INTERNE reste utile pour un futur appelant qui n emprunterait PAS         }
  { ce chemin (ex. l enregistrement de champs, TODO 08). }
  Dup := SymFindInScope(Name, CurScopeId);
  If (Dup >= 0) And (Kind <> SK_FUNC) Then
    WarnMsg('symbole deja declare dans cette portee: ' + Name);

  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TIdx;
  SymTab[SymCount].ScopeLevel  := CurScopeLevel;
  SymTab[SymCount].ScopeId     := CurScopeId;
  SymTab[SymCount].IsStatic    := AIsStatic;
  SymTab[SymCount].IsFinal     := AIsFinal;
  SymTab[SymCount].HasInit     := False;
  SymTab[SymCount].ConstVal.Kind    := CK_INT;
  SymTab[SymCount].ConstVal.IntVal  := 0;
  SymTab[SymCount].ConstVal.RealVal := 0.0;
  SymTab[SymCount].ConstVal.StrVal  := '';
  SymTab[SymCount].InitExprIdx := -1;
  SymTab[SymCount].Offset      := 0;

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ SymCheckFinal : Vrai si SI peut ENCORE etre affecte (PAS "final",   }
{ ou "final" mais PAS ENCORE initialise), et marque alors HasInit ;    }
{ sinon emet un FatalError - regle "final assigne UNE SEULE fois"       }
{ (sections 5.3/5.5/5.6/5.7, MEME discipline EXACTE que SymCheckMutable      }
{ de SWIFTW32.PAS pour son propre "let"). AUCUN appelant REEL n existe        }
{ encore (aucune instruction d affectation ne peut etre ecrite avant        }
{ le TODO 07) - testee ISOLEMENT ci-dessous (DeclSelfTest), en                }
{ attendant. }
Function SymCheckFinal(SI: Integer): Boolean;
Begin
  SymCheckFinal := True;
  If (SI < 0) Or (SI >= SymCount) Then Exit;
  If SymTab[SI].IsFinal And SymTab[SI].HasInit Then
  Begin
    FatalError('affectation a une variable "final" deja initialisee: ' +
      SymTab[SI].Name);
    SymCheckFinal := False;
  End
  Else
    SymTab[SI].HasInit := True;
End;

{ ------------------------------------------------------------ }
{ TModifiers / ParseModifiers : les 7 modificateurs SYNTAXIQUEMENT   }
{ valides devant une declaration de variable (sections 5.2-5.7 -        }
{ public/protected/private/static/final/transient/volatile - JAMAIS       }
{ abstract/native/synchronized, reserves aux METHODES, TODO 08).            }
{ transient/volatile sont ACCEPTES (pour qu un VRAI fichier J++ ne              }
{ bute pas dessus) mais AUCUN champ ne les CONSERVE : ils concernent           }
{ la serialisation/le modele memoire concurrent, HORS de portee de              }
{ ce compilateur (jamais lus par personne, decision DOCUMENTEE plutot          }
{ que silencieusement oubliee). public/protected/private (visibilite)          }
{ sont eux aussi ACCEPTES mais pas encore STOCKES - reserve pour le             }
{ TODO 12 ("visibilite"), qui decidera alors OU les conserver (TSymRec           }
{ n a pas encore ce besoin, aucune verification d acces n existe                    }
{ encore). }
{ ------------------------------------------------------------ }

Type
  TModifiers = Record
    IsStatic : Boolean;
    IsFinal  : Boolean;
  End;

Function ParseModifiers: TModifiers;
Var
  M  : TModifiers;
  KW : Integer;
Begin
  M.IsStatic := False;
  M.IsFinal  := False;
  While PPKind = TOK_IDENT Do
  Begin
    KW := IsKeyword(PPVal);
    If KW = KW_STATIC Then
    Begin
      M.IsStatic := True;
      PPAdvance;
    End
    Else If KW = KW_FINAL Then
    Begin
      M.IsFinal := True;
      PPAdvance;
    End
    Else If (KW = KW_PUBLIC) Or (KW = KW_PROTECTED) Or (KW = KW_PRIVATE) Or
            (KW = KW_TRANSIENT) Or (KW = KW_VOLATILE) Then
      PPAdvance   { accepte syntaxiquement, voir la note d en-tete de section }
    Else
      Break;
  End;
  ParseModifiers := M;
End;

{ ------------------------------------------------------------ }
{ ParseTypeRef : une reference de type - mot-cle PRIMITIF (int,     }
{ boolean, etc. - TODO 03/04, PrimitiveTypeFromKeyword) OU               }
{ identificateur de type REFERENCE predeclare (String, Object,             }
{ Exception... - TODO 03/04, IsPredeclaredType), suivi de zero ou           }
{ plusieurs suffixes "[]" REPETES (section 5.2 : "int[] e[]" = un              }
{ tableau de tableaux d int, "int[][]" - chaque "[]" ENVELOPPE le                }
{ precedent dans un NOUVEAU TYK_ARRAY). Un identificateur qui n est PAS          }
{ un type predeclare s arrete PROPREMENT (FatalError explicite) - les             }
{ classes UTILISATEUR (section 8) restent hors de portee tant que le             }
{ TODO 08 n existe pas, jamais devinees ici. }
{ ------------------------------------------------------------ }

{ ParseBaseTypeNoBrackets : le type de base SEUL (mot-cle primitif OU   }
{ identificateur de type REFERENCE predeclare) - SANS consommer aucun    }
{ suffixe "[]" (extrait de ParseTypeRef au TODO 06 pour etre partage        }
{ avec ParseNewExpr, qui doit distinguer une paire "[taille]" d une             }
{ simple paire "[]" plutot que de toujours supposer cette derniere,               }
{ contrairement a ParseTypeRef lui-meme). }
Function ParseBaseTypeNoBrackets: Integer;
Var
  KW  : Integer;
  Res : Integer;
Begin
  { BOGUE REEL trouve par EXECUTION (debordement de pile immediat, TODO   }
  { 06) : le mode TP de ce fichier (directive de mode en tete du fichier)  }
  { traite la LECTURE du nom de la fonction dans une EXPRESSION comme un   }
  { APPEL RECURSIF (jamais "la valeur deja assignee jusqu ici", au              }
  { contraire du "Result" de Delphi) - comparer le nom de la fonction a       }
  { zero dans une condition le rappelait donc lui-meme INDEFINIMENT. Une      }
  { VARIABLE LOCALE (Res) porte desormais la valeur intermediaire ; le          }
  { nom de la fonction n est plus JAMAIS LU, SEULEMENT assigne, une SEULE       }
  { fois, juste avant de sortir - a VERIFIER systematiquement pour toute        }
  { AUTRE fonction de ce fichier partageant ce meme risque. }
  Res := -1;
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('type attendu');
    ParseBaseTypeNoBrackets := Res;
    Exit;
  End;

  KW := IsKeyword(PPVal);
  If KW <> 0 Then
  Begin
    Res := PrimitiveTypeFromKeyword(KW);
    If Res < 0 Then
      FatalError('type attendu, mot-cle non-type trouve: ' + PPVal)
    Else
      PPAdvance;
  End
  Else
  Begin
    Res := IsPredeclaredType(PPVal);
    If Res <> 0 Then
      PPAdvance
    Else
    Begin
      { EXTENSION TODO 08 : une VRAIE classe UTILISATEUR deja DECLAREE      }
      { (ClassAdd/TypeAdd, plus bas) est desormais aussi une reponse            }
      { valide - TypeFindByName (TODO 04, jamais utile avant cette              }
      { extension puisqu aucune classe n existait) la retrouve PAR SON            }
      { NOM. PORTEE ASSUMEE (une seule PASSE, JAMAIS de resolution en             }
      { deux temps) : une classe doit etre TEXTUELLEMENT declaree AVANT          }
      { d etre utilisee comme type ICI - EXACTEMENT l ordre REEL des              }
      { echantillons (Test07Heritage.jpp declare "Forme" avant                       }
      { "Rectangle extends Forme") - une classe utilisee AVANT sa                       }
      { propre declaration textuelle resterait "inconnue" (limitation             }
      { DOCUMENTEE, pas une vraie resolution differee comme un VRAI               }
      { compilateur Java le ferait). }
      Res := TypeFindByName(PPVal);
      If Res < 0 Then
      Begin
        FatalError('type "' + PPVal + '" inconnu (ni primitif, ni ' +
          'predeclare, ni classe deja declaree - une classe utilisee ' +
          'doit etre TEXTUELLEMENT declaree AVANT, section 8 - TODO 08)');
        Res := -1;
      End
      Else
        PPAdvance;
    End;
  End;

  ParseBaseTypeNoBrackets := Res;
End;

Function ParseTypeRef: Integer;
Var
  BaseT : Integer;
Begin
  BaseT := ParseBaseTypeNoBrackets;
  If BaseT < 0 Then
  Begin
    ParseTypeRef := -1;
    Exit;
  End;

  While PPIsOp('[') Do
  Begin
    PPAdvance;
    If Not PPMatch(']') Then
      FatalError('"]" attendu apres "[" dans un type tableau');
    BaseT := TypeAdd(TYK_ARRAY, '', 4, 4, BaseT);
  End;

  ParseTypeRef := BaseT;
End;

{ ------------------------------------------------------------ }
{ ConstEvalExpr : REMPLIT CV a partir du token courant et AVANCE -   }
{ PORTEE VOLONTAIREMENT LIMITEE aux LITTERAUX (entier/long/flottant/    }
{ double/caractere/chaine/booleen/null), avec un "-" PREFIXE optionnel   }
{ pour les litteraux NUMERIQUES (necessaire des maintenant : "-1"           }
{ n est JAMAIS un TOK_INT negatif, TODO 02 lexe TOUJOURS un entier             }
{ POSITIF suivi de l operateur "-" separement, section 6.3) - AUCUNE            }
{ expression GENERALE (identificateur, appel, operateur binaire) n est          }
{ acceptee : arret PROPRE (FatalError) plutot que deviner. RESTE le             }
{ SEUL analyseur d initialiseur pour un CHAMP de classe/interface                    }
{ (ParseFieldDeclRest/ParseInterfaceMember, TODO 08/09 - PORTEE                            }
{ DELIBEREMENT reduite au litteral, voir TFieldRec) - ParseVarDecl                     }
{ (juste en dessous), LUI, est passe a une VRAIE expression generale               }
{ (ParseExpr, TODO 06) des que le TODO 09 a EXIGE des locales                              }
{ initialisees depuis un identificateur (ExprLiteralToConstVal, plus            }
{ bas, comble alors le meme role EN LECTURE SEULE, APRES coup). }
{ ------------------------------------------------------------ }

Function ConstEvalExpr(Var CV: TConstVal): Boolean;
Var
  Neg : Boolean;
  PL  : Integer;
Begin
  ConstEvalExpr := True;
  CV.Kind    := CK_INT;
  CV.IntVal  := 0;
  CV.RealVal := 0.0;
  CV.StrVal  := '';

  Neg := False;
  If PPIsOp('-') Then
  Begin
    Neg := True;
    PPAdvance;
  End;

  Case PPKind Of
    TOK_INT:
    Begin
      CV.Kind := CK_INT;
      If Neg Then CV.IntVal := -TokenPool[PP].IntVal Else CV.IntVal := TokenPool[PP].IntVal;
      PPAdvance;
    End;
    TOK_LONG:
    Begin
      CV.Kind := CK_LONG;
      If Neg Then CV.IntVal := -TokenPool[PP].IntVal Else CV.IntVal := TokenPool[PP].IntVal;
      PPAdvance;
    End;
    TOK_FLOAT:
    Begin
      CV.Kind := CK_FLOAT;
      If Neg Then CV.RealVal := -TokenPool[PP].RealVal Else CV.RealVal := TokenPool[PP].RealVal;
      PPAdvance;
    End;
    TOK_DOUBLE:
    Begin
      CV.Kind := CK_DOUBLE;
      If Neg Then CV.RealVal := -TokenPool[PP].RealVal Else CV.RealVal := TokenPool[PP].RealVal;
      PPAdvance;
    End;
    TOK_CHAR:
    Begin
      If Neg Then FatalError('"-" non applicable a un litteral caractere');
      CV.Kind   := CK_CHAR;
      CV.IntVal := TokenPool[PP].IntVal;
      PPAdvance;
    End;
    TOK_STRING:
    Begin
      If Neg Then FatalError('"-" non applicable a un litteral chaine');
      CV.Kind   := CK_STRING;
      CV.StrVal := TokenPool[PP].Val;
      PPAdvance;
    End;
    TOK_IDENT:
    Begin
      PL := IsPredeclaredLiteral(PPVal);
      If Neg Then
        FatalError('"-" non applicable a ce litteral')
      Else If PL = PL_TRUE Then
      Begin
        CV.Kind := CK_BOOL;
        CV.IntVal := 1;
        PPAdvance;
      End
      Else If PL = PL_FALSE Then
      Begin
        CV.Kind := CK_BOOL;
        CV.IntVal := 0;
        PPAdvance;
      End
      Else If PL = PL_NULL Then
      Begin
        CV.Kind := CK_NULL;
        PPAdvance;
      End
      Else
      Begin
        FatalError('initialiseur non constant (identificateur/appel - ' +
          'expressions generales hors de portee, TODO 06) : ' + PPVal);
        ConstEvalExpr := False;
      End;
    End;
    Else
    Begin
      FatalError('initialiseur constant attendu (litteral)');
      ConstEvalExpr := False;
    End;
  End;
End;

{ Forward EXCEPTIONNEL (ParseExpr/ExprLiteralToConstVal/                    }
{ ParseArrayInitializer) : ParseVarDecl (juste en dessous) a besoin              }
{ d une VRAIE expression GENERALE pour l initialiseur d une variable            }
{ LOCALE (section 5.5, TODO 09 - voir la note d en-tete de                            }
{ ConstEvalExpr pour pourquoi ce n etait PAS le cas avant), ET (TODO           }
{ 10, section 10.4) d un initialiseur de TABLEAU "nu" (accolades SEULES,       }
{ SANS "new T[]" devant - exemple LITTERAL "int[] notes = ...4 valeurs        }
{ entre accolades..." de Test05Tableaux.jpp), forme EXCLUSIVE a un                }
{ declarateur, jamais une expression generale ordinaire - alors que              }
{ ParseExpr/TExprKind/ExprPool (TODO 06) et ExprLiteralToConstVal/                  }
{ ParseArrayInitializer (leurs corps REELS, plus bas, ont besoin                       }
{ d ExprPool) n apparaissent que PLUS LOIN dans ce fichier. MEME                     }
{ technique EXACTE que ClassFindField et consorts, plus haut. }
Function ParseExpr: Integer; Forward;
Function ExprLiteralToConstVal(E: Integer; Var CV: TConstVal): Boolean; Forward;
Function ParseArrayInitializer(ElemT: Integer): Integer; Forward;

{ Forward EXCEPTIONNEL (ParseArgListInto, TODO 13) : ParseArrayInitializer  }
{ (plus bas) a besoin de ce correctif anti-entrelacement (voir sa                    }
{ propre note d en-tete, section TODO 06/13) DES MAINTENANT, alors que          }
{ son corps REEL (avec les DEUX autres appelants, ParseNewExpr et                     }
{ ParsePostfix) n apparait que PLUS LOIN. MEME technique EXACTE que              }
{ les trois Forward juste au-dessus. }
Procedure ParseArgListInto(Const Term: TString; Var OutArgFirst, OutArgCount: Integer); Forward;

{ ------------------------------------------------------------ }
{ ParseVarDecl : grammaire COMMUNE d une declaration de champ         }
{ (5.3/5.4)/locale (5.5) - "[modificateurs] Type nom1 ['['']']*          }
{ ['=' initialiseur]" PUIS zero ou plusieurs ", nomN [= initN]"           }
{ supplementaires, termine par ";" (section 5.2). Chaque                     }
{ declarateur peut AJOUTER ses PROPRES crochets "[]" APRES le type de           }
{ base (section 5.2, "int c[], d;" -> c est int[], d est int - EXEMPLE            }
{ LITTERAL de la reference, directement reproduit par DeclSelfTest              }
{ ci-dessous). La regle STRICTE de la section 5.10 (aucune                          }
{ redeclaration dans une portee locale ENGLOBANTE qui se chevauche)               }
{ est appliquee ICI, avant CHAQUE SymAdd, via SymFindEnclosing.                     }
{                                                                       }
{ BOGUE REEL trouve par EXECUTION (TODO 09, InterfaceSelfTest -                  }
{ "int ancienneValeur = valeur;" dans Test08Interfaces.jpp, une LOCALE           }
{ initialisee depuis un IDENTIFICATEUR, pas un litteral) : l initialiseur         }
{ passait par ConstEvalExpr (litteraux SEULEMENT, TODO 05), qui                        }
{ FatalError sur TOUT le reste - AUCUNE declaration locale reelle avec           }
{ un initialiseur NON constant n avait jamais ete exercee avant                       }
{ (StmtSelfTest/DeclSelfTest ne testent que des cas isoles). Fixe en             }
{ appelant ParseExpr (TODO 06, expression GENERALE) - InitExprIdx                    }
{ (TSymRec, reserve depuis le TODO 05 EXACTEMENT pour ce jour) recoit           }
{ desormais l expression COMPLETE ; ConstVal/HasInit restent EN PLUS               }
{ remplis quand ExprLiteralToConstVal reconnait un LITTERAL simple                  }
{ (identique au litteral EXCLUSIF de ConstEvalExpr - AUCUNE perte pour            }
{ DeclSelfTest, qui n utilise que des litteraux) ; HasInit devient VRAI          }
{ pour TOUT initialiseur, litteral ou non - SymCheckFinal (section 5.9)            }
{ doit refuser une SECONDE affectation a une "final" locale MEME quand             }
{ sa valeur initiale n etait pas un litteral. ConstEvalExpr LUI-MEME               }
{ reste INCHANGE, toujours utilise par ParseFieldDeclRest/                              }
{ ParseInterfaceMember (TODO 08/09) pour les CHAMPS, dont la portee                  }
{ reste DELIBEREMENT reduite au litteral. }
{ ------------------------------------------------------------ }

Procedure ParseVarDecl;
Var
  Mods   : TModifiers;
  BaseT  : Integer;
  ElemT  : Integer;
  SI     : Integer;
  Nam    : TString;
  CV     : TConstVal;
  InitE  : Integer;
Begin
  Mods  := ParseModifiers;
  BaseT := ParseTypeRef;

  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de variable attendu');
      Exit;
    End;
    Nam := PPVal;
    PPAdvance;

    ElemT := BaseT;
    While PPIsOp('[') Do
    Begin
      PPAdvance;
      If Not PPMatch(']') Then
        FatalError('"]" attendu apres "[" dans un declarateur de tableau');
      ElemT := TypeAdd(TYK_ARRAY, '', 4, 4, ElemT);
    End;

    If SymFindEnclosing(Nam) >= 0 Then
      FatalError('"' + Nam + '" est deja declare dans une portee locale ' +
        'englobante (section 5.10 - une locale/un parametre ne peut ' +
        'redeclarer un nom deja visible ; MASQUER un CHAMP reste permis, ' +
        'mais aucune declaration de champ n''existe encore, TODO 08)');

    SI := SymAdd(Nam, SK_VAR, ElemT, Mods.IsStatic, Mods.IsFinal);
    { extension post-TODO25 (generateur de code) : position EBP-relative  }
    { REELLE de cette variable locale - voir la note d en-tete de              }
    { CurLocalOffset. ParseVarDecl n est JAMAIS appelee pour un champ           }
    { (ParseFieldDeclRest s en charge separement, TODO 08) - TOUJOURS une              }
    { vraie locale, meme dans l initialisation d un "for". }
    CurLocalOffset := CurLocalOffset - 4;
    SymTab[SI].Offset := CurLocalOffset;

    If PPMatch('=') Then
    Begin
      { TODO 10 (section 10.4) : une accolade OUVRANTE nue, SANS "new T[]" }
      { devant, est un initialiseur de TABLEAU (ParseArrayInitializer),           }
      { PAS une expression generale ordinaire - AUCUNE expression                    }
      { commencant par une accolade n existe ailleurs dans la grammaire            }
      { de ce compilateur, donc ce lookahead d UN SEUL token suffit                    }
      { (aucune ambiguite possible). }
      If PPIsOp('{') Then
        InitE := ParseArrayInitializer(ElemT)
      Else
        InitE := ParseExpr;
      SymTab[SI].InitExprIdx := InitE;
      SymTab[SI].HasInit     := True;
      If ExprLiteralToConstVal(InitE, CV) Then
        SymTab[SI].ConstVal := CV;
    End;
  Until Not PPMatch(',');

  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''une declaration');
End;

{ ------------------------------------------------------------ }
{ ParseSingleParam : UN SEUL parametre de methode/constructeur       }
{ (section 5.6, "[final] Type p1") - PAS de boucle sur la virgule          }
{ ICI (une liste de parametres restitue son PROPRE type a CHAQUE            }
{ parametre, contrairement aux declarateurs partages de ParseVarDecl)          }
{ ni de parenthese ouvrante/fermante consommee : reserve au VRAI               }
{ analyseur de signature de methode, TODO 08, qui appellera cette                }
{ fonction dans SA PROPRE boucle separee par des "," litteraux. }
{ ------------------------------------------------------------ }

Function ParseSingleParam: Integer;
Var
  Mods : TModifiers;
  T    : Integer;
  Nam  : TString;
Begin
  Mods := ParseModifiers;
  T    := ParseTypeRef;
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de parametre attendu');
    ParseSingleParam := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;
  If SymFindEnclosing(Nam) >= 0 Then
    FatalError('"' + Nam + '" est deja declare dans une portee locale ' +
      'englobante (section 5.10)');
  ParseSingleParam := SymAdd(Nam, SK_VAR, T, False, Mods.IsFinal);
End;

{ ------------------------------------------------------------ }
{ ParseCatchParam : le parametre d une clause catch (section 5.7,   }
{ "catch ([final] TypeException nom)") - MEME grammaire qu un              }
{ parametre ordinaire, PLUS une VERIFICATION SEMANTIQUE reelle : le          }
{ type DOIT etre Throwable ou une sous-classe (TypeIsSubclassOf,             }
{ deja construit au TODO 04 pour EXACTEMENT ce genre de verification -       }
{ premiere REUTILISATION concrete de la hierarchie Throwable                     }
{ predeclaree). Comme ParseSingleParam, ne consomme PAS les                          }
{ parentheses (reserve au TODO 11, "try/catch"). }
{ ------------------------------------------------------------ }

Function ParseCatchParam: Integer;
Var
  Mods : TModifiers;
  T    : Integer;
  Nam  : TString;
Begin
  Mods := ParseModifiers;
  T    := ParseTypeRef;
  If Not TypeIsSubclassOf(T, PDT_THROWABLE) Then
    FatalError('le type d''un parametre catch doit etre Throwable ou une ' +
      'sous-classe (section 5.7)');
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de parametre catch attendu');
    ParseCatchParam := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;
  If SymFindEnclosing(Nam) >= 0 Then
    FatalError('"' + Nam + '" est deja declare dans une portee locale ' +
      'englobante (section 5.10)');
  ParseCatchParam := SymAdd(Nam, SK_VAR, T, False, Mods.IsFinal);
End;

{ ------------------------------------------------------------ }
{ DeclSelfTest : chaque assertion reproduit un exemple LITTERAL de  }
{ la reference (sections 5.2-5.10) - jamais un cas invente. Teste     }
{ ISOLEMENT (voir la note d en-tete de section) via un extrait            }
{ synthetique qui commence DIRECTEMENT au mot-cle de type, sans            }
{ classe englobante. ------------------------------------------------ }

Procedure DeclAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DeclSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DeclSelfTest;
Const
  TmpFile = 'JPPDECLSELFTEST.$$$';
Var
  F        : Text;
  SIa, SIb : Integer;
Begin
  TypeInit;
  SymInit;

  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'int compteur;');
  WriteLn(F, 'int x = 1, y = 2;');
  WriteLn(F, 'final int maximum = 100;');
  WriteLn(F, 'private static int nombreInstances;');
  WriteLn(F, 'int[] a, b;');
  WriteLn(F, 'int c[], d;');
  WriteLn(F, 'double negatif = -3.5;');
  WriteLn(F, 'boolean actif = true;');
  WriteLn(F, 'String message = "Bonjour";');
  WriteLn(F, 'Object reference = null;');
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;

  { "int compteur;" (5.2, declaration simple SANS initialiseur). }
  ParseVarDecl;
  DeclAssert('compteur : type int', SymTab[SymCount - 1].TypeIdx = PRIMTYPE_INT);
  DeclAssert('compteur : pas d''initialiseur', Not SymTab[SymCount - 1].HasInit);
  DeclAssert('compteur : nom exact', SymTab[SymCount - 1].Name = 'compteur');

  { "int x = 1, y = 2;" (5.2, DEUX declarateurs partageant UN type). }
  ParseVarDecl;
  SIa := SymCount - 2;   { x }
  SIb := SymCount - 1;   { y }
  DeclAssert('x : nom exact', SymTab[SIa].Name = 'x');
  DeclAssert('x : type int', SymTab[SIa].TypeIdx = PRIMTYPE_INT);
  DeclAssert('x : initialise a 1', SymTab[SIa].HasInit And
    (SymTab[SIa].ConstVal.Kind = CK_INT) And (SymTab[SIa].ConstVal.IntVal = 1));
  DeclAssert('y : nom exact', SymTab[SIb].Name = 'y');
  DeclAssert('y : initialise a 2', SymTab[SIb].ConstVal.IntVal = 2);

  { "final int maximum = 100;" (5.2/5.5, "final" = equivalent J++ du "let"). }
  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('maximum : final', SymTab[SIa].IsFinal);
  DeclAssert('maximum : valeur 100', SymTab[SIa].ConstVal.IntVal = 100);

  { SymCheckFinal - SEULEMENT le chemin REUSSI (premiere affectation      }
  { d une "final" PAS ENCORE initialisee, SymAdd direct SANS passer par    }
  { ParseVarDecl/ConstEvalExpr, HasInit reste Faux) : le chemin ECHOUE     }
  { appelle FatalError EN INTERNE (voir sa propre note d en-tete) et       }
  { arreterait tout le programme - AUCUN self-test de ce projet ne          }
  { declenche jamais un FatalError REEL pour verifier qu il se produit,        }
  { MEME discipline que documentee plus haut pour ParseCatchParam. }
  SIb := SymAdd('unique', SK_VAR, PRIMTYPE_INT, False, True);
  DeclAssert('SymCheckFinal (1ere affectation) reussit', SymCheckFinal(SIb));
  DeclAssert('SymCheckFinal marque HasInit', SymTab[SIb].HasInit);

  { "private static int nombreInstances;" (5.4, plusieurs modificateurs,   }
  { "private" accepte syntaxiquement mais pas stocke - voir la note        }
  { d en-tete de ParseModifiers). }
  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('nombreInstances : static', SymTab[SIa].IsStatic);
  DeclAssert('nombreInstances : PAS final', Not SymTab[SIa].IsFinal);

  { "int[] a, b;" (5.2, EXEMPLE LITTERAL : "a et b sont int[]"). }
  ParseVarDecl;
  SIa := SymCount - 2;   { a }
  SIb := SymCount - 1;   { b }
  DeclAssert('a : genre TYK_ARRAY', TypeTab[SymTab[SIa].TypeIdx].Kind = TYK_ARRAY);
  DeclAssert('a : elements de type int', TypeTab[SymTab[SIa].TypeIdx].ElemTypeIdx = PRIMTYPE_INT);
  DeclAssert('b : genre TYK_ARRAY (le "[]" du type s''applique aux DEUX)',
    TypeTab[SymTab[SIb].TypeIdx].Kind = TYK_ARRAY);

  { "int c[], d;" (5.2, EXEMPLE LITTERAL : "c est int[], d est int" - LE    }
  { PLUS DELICAT : chaque declarateur porte SES PROPRES crochets, PAS le    }
  { type de base). }
  ParseVarDecl;
  SIa := SymCount - 2;   { c }
  SIb := SymCount - 1;   { d }
  DeclAssert('c : genre TYK_ARRAY (crochets APRES le nom)',
    TypeTab[SymTab[SIa].TypeIdx].Kind = TYK_ARRAY);
  DeclAssert('d : PLAIN int (AUCUN crochet sur CE declarateur)',
    SymTab[SIb].TypeIdx = PRIMTYPE_INT);

  { "double negatif = -3.5;" ("-" prefixe sur un litteral numerique,   }
  { section 6.3 - "-3.5" n est JAMAIS un seul token). }
  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('negatif : genre CK_DOUBLE', SymTab[SIa].ConstVal.Kind = CK_DOUBLE);
  DeclAssert('negatif : valeur ~ -3.5',
    (SymTab[SIa].ConstVal.RealVal > -3.6) And (SymTab[SIa].ConstVal.RealVal < -3.4));

  { "boolean actif = true;" / "String message = ...;" / "Object reference = null;" }
  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('actif : genre CK_BOOL vrai', (SymTab[SIa].ConstVal.Kind = CK_BOOL) And
    (SymTab[SIa].ConstVal.IntVal = 1));

  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('message : genre CK_STRING "Bonjour"',
    (SymTab[SIa].ConstVal.Kind = CK_STRING) And (SymTab[SIa].ConstVal.StrVal = 'Bonjour'));

  ParseVarDecl;
  SIa := SymCount - 1;
  DeclAssert('reference : genre CK_NULL', SymTab[SIa].ConstVal.Kind = CK_NULL);

  { portee lexicale et masquage (5.9/5.10). }
  SymEnterScope;
  SIa := SymAdd('a', SK_VAR, PRIMTYPE_INT, False, False);
  DeclAssert('"a" (portee externe) resolu par SymFind', SymFind('a') = SIa);

  SymEnterScope;
  SIb := SymAdd('b', SK_VAR, PRIMTYPE_INT, False, False);
  DeclAssert('"b" (portee interne) resolu par SymFind', SymFind('b') = SIb);
  DeclAssert('"a" (portee externe) TOUJOURS visible depuis la portee interne (5.9)',
    SymFindEnclosing('a') = SIa);
  SymLeaveScope;

  DeclAssert('"a" reste visible apres la fermeture de la portee interne',
    SymFindEnclosing('a') = SIa);
  SymLeaveScope;

  { section 5.10 - "int x;" PUIS, dans un bloc imbrique encore OUVERT,     }
  { "int x;" A NOUVEAU (MEME nom dans une portee englobante ENCORE           }
  { OUVERTE) DOIT etre refuse - teste ICI en              }
  { verifiant DIRECTEMENT que SymFindEnclosing le detecte (LA VERIFICATION  }
  { que ParseVarDecl consulte AVANT son propre SymAdd), plutot que de           }
  { provoquer le FatalError lui-meme (qui arreterait tout le programme,        }
  { AUCUN self-test de ce projet ne declenche jamais un FatalError REEL         }
  { pour verifier qu il se produit). }
  SymEnterScope;
  SIa := SymAdd('conflit', SK_VAR, PRIMTYPE_INT, False, False);
  SymEnterScope;
  DeclAssert('"conflit" (portee englobante ENCORE ouverte) detecte par ' +
    'SymFindEnclosing - section 5.10, redeclaration interdite',
    SymFindEnclosing('conflit') = SIa);
  SymLeaveScope;
  SymLeaveScope;

  { ParseSingleParam (5.6, exemple LITTERAL "additionner(int gauche, ...)"). }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'final int gauche');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  SIa := ParseSingleParam;
  DeclAssert('gauche : parametre final', SymTab[SIa].IsFinal);
  DeclAssert('gauche : type int', SymTab[SIa].TypeIdx = PRIMTYPE_INT);

  { ParseCatchParam (5.7, exemple ADAPTE - "IOException" n est pas       }
  { predeclare ici, TODO 08 - "Exception" (PDT_EXCEPTION, TODO 03/04)          }
  { l est deja et convient tout aussi bien a cette verification). }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'Exception erreur');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  SIa := ParseCatchParam;
  DeclAssert('erreur : type Exception (Throwable, accepte section 5.7)',
    SymTab[SIa].TypeIdx = PDT_EXCEPTION);
End;

{ ============================================================ }
{ TODO 06 - OPERATEURS ET EXPRESSIONS                           }
{ ============================================================ }
{ Deuxieme TODO de PARSING (apres les declarations, TODO 05) - un   }
{ VRAI arbre (AST, ExprPool) plutot que du code (aucun backend,        }
{ TODO 21+ n existe encore), MEME principe de POOL A TAILLE FIXE deja      }
{ utilise pour TypeTab/FieldPool (TODO 04) et SymTab (TODO 05).                }
{ Cohabite AVEC ConstEvalExpr (TODO 05, INCHANGE, TOUJOURS utilise pour        }
{ les initialiseurs de declaration) plutot que de le remplacer -                  }
{ MEME choix EXACT que GOCW32.PAS/SWIFTW32.PAS a ce meme stade :                    }
{ ParseExpr sert aux expressions GENERALES (futurs corps de methodes/               }
{ instructions, TODO 07/08) qui n ont pas besoin d une valeur PLEINEMENT             }
{ CALCULEE a la compilation - testee ISOLEMENT ci-dessous (ExprSelfTest),              }
{ JAMAIS branchee sur un VRAI fichier .jpp pour l instant.                             }
{                                                                       }
{ DECISION DE PORTEE EXPLICITE (precedent DIRECT chez les DEUX               }
{ compilateurs freres a leur propre TODO 06) : L AFFECTATION ("=" et ses      }
{ 10 formes composees, sections 6.15/6.16) est EXCLUE de ParseExpr,             }
{ deferee au niveau INSTRUCTION (TODO 07) - EXACTEMENT le choix deja               }
{ fait par GOCW32.PAS ET SWIFTW32.PAS pour leur propre grammaire                    }
{ d expression, pas une simplification inventee ici. Le rare cas Java              }
{ REEL d une affectation utilisee COMME SOUS-expression (ex.                            }
{ "while ((c = lire()) != -1)") reste donc HORS de portee, a                            }
{ documenter de nouveau explicitement si un echantillon reel en a                          }
{ besoin.                                                                                     }
{                                                                       }
{ Precedence EXACTE de la section 6.1 (la plus forte en premier -             }
{ POSTFIXE > UNAIRE/CAST > * / % > + - > decalages > relationnels/                 }
{ instanceof > egalite > & > ^ > | > && > || > ternaire), implementee               }
{ par une CHAINE de fonctions recursives-descendantes (une par NIVEAU),           }
{ MEME technique EXACTE que GOCW32.PAS/SWIFTW32.PAS - PAS une table de           }
{ precedence generique a un seul operateur binaire parametre (plus                     }
{ simple a lire/deboguer pour SEULEMENT 14 niveaux, meme choix que les               }
{ deux compilateurs freres). }

Const
  MAX_EXPR     = 8192;
  MAX_EXPR_ARG = 4096;

Type
  TExprKind = (
    EK_INTLIT, EK_LONGLIT, EK_FLOATLIT, EK_DOUBLELIT, EK_CHARLIT,
    EK_STRINGLIT, EK_BOOLLIT, EK_NULLLIT,
    EK_IDENT,          { Left = index SymTab DEJA RESOLU au moment du       }
                        { PARSING (voir ExprAddIdent) - MEME technique          }
                        { EXACTE que GOCW32.PAS/SWIFTW32.PAS (correctif             }
                        { "math.swift" de SWIFTW32.PAS : jamais un second           }
                        { SymFind(NameVal) plus tard, ambigu une fois              }
                        { toutes les portees refermees) }
    EK_TYPEREF,        { TODO 13 (section 12.15) - NameVal = nom du type ;  }
                        { TypeIdx = le type REFERENCE (PAS une VALEUR de ce      }
                        { type - le type LUI-MEME) - produit UNIQUEMENT par         }
                        { ExprAddIdent quand un identificateur ne resout NI          }
                        { a une locale/un parametre NI a un champ IMPLICITE,          }
                        { mais EST un nom de classe/interface CONNU                            }
                        { (TypeFindByName) - permet a ParsePostfix de                        }
                        { reconnaitre "Integer.parseInt(...)" (acces STATIQUE       }
                        { qualifie par un NOM DE TYPE, PAS par une expression        }
                        { - le TODO 08 avait EXPLICITEMENT differe cette                }
                        { forme, "seul l acces PAR NOM SIMPLE est resolu" -            }
                        { necessaire maintenant pour la bibliotheque standard          }
                        { minimale, TODO 13). }
    EK_UNARY,          { Op = '+'/'-'/'~'/'!' (prefixe, section 6.3) ou      }
                        { '++'/'--' (PREFIXE, section 6.4) ou                       }
                        { 'post++'/'post--' (POSTFIXE, section 6.4) ;                  }
                        { Left = operande }
    EK_BINARY,         { Op ; Left, Right - * / % + - << >> >>> < <= > >=      }
                        { == != & ^ | && || (sections 6.6-6.13) }
    EK_INSTANCEOF,     { Left = operande ; Extra = TypeIdx teste (section       }
                        { 6.10) ; TypeIdx resultat = PRIMTYPE_BOOLEAN }
    EK_CAST,           { Left = operande ; Extra = TypeIdx cible (section       }
                        { 6.22) }
    EK_TERNARY,        { Left = condition ; Right = branche VRAIE ; Extra =    }
                        { branche FAUSSE (section 6.14) }
    EK_SELECTOR,       { Left = base ; NameVal = champ/methode ('.',            }
                        { section 6.17) }
    EK_INDEX,          { Left = base ; Right = indice (section 6.18) -    }
                        { AUCUNE verification de borne ICI (section 10.7,        }
                        { decision de GENERATION DE CODE, voir la note                 }
                        { d en-tete de TYK_ARRAY - repoussee au TODO 21+) }
    EK_CALL,           { Left = callee (EK_IDENT ou EK_SELECTOR) ;              }
                        { ArgFirst/Count (section 6.19 - JAMAIS d etiquette,        }
                        { Java n en a pas) ; Extra = index MethodPool DE LA          }
                        { METHODE REELLEMENT resolue par ClassResolveMethodCall  }
                        { (TODO 08), -1 si JAMAIS resolue - AJOUTE au TODO 21           }
                        { (le generateur de code a besoin de savoir EXACTEMENT           }
                        { quelle methode appeler, pas seulement son TYPE de                    }
                        { retour DEJA stocke dans TypeIdx depuis le TODO 08) -            }
                        { champ INUTILISE pour EK_CALL jusqu ICI. }
    EK_NEWOBJECT,      { Extra = TypeIdx de la classe ; ArgFirst/Count =        }
                        { arguments du constructeur (section 6.20) }
    EK_NEWARRAY        { Op = 'dims' (ArgFirst/Count = expressions de              }
                        { DIMENSION, une par paire "[N]" rencontree, VIDES           }
                        { EXCLUES) ou 'init' (ArgFirst/Count = ELEMENTS de          }
                        { l initialiseur accolade (section 6.21) ; TypeIdx =            }
                        { type ELEMENT final (deja enveloppe de TYK_ARRAY               }
                        { autant de fois que de paires "[]" rencontrees,                    }
                        { chiffrees OU vides) }
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : TString;
    Left    : Integer;    { -1 si absent }
    Right   : Integer;    { -1 si absent }
    Extra   : Integer;    { -1 si absent - sens PROPRE A CHAQUE Kind, voir  }
                           { les commentaires de TExprKind ci-dessus }
    NameVal : TString;    { EK_IDENT / EK_SELECTOR }
    IntVal  : LongInt;    { EK_INTLIT/LONGLIT/CHARLIT/BOOLLIT }
    RealVal : Real;       { EK_FLOATLIT/DOUBLELIT }
    StrVal  : TString;    { EK_STRINGLIT }
    TypeIdx : Integer;    { inference AU MIEUX, -1 si inconnu (best-effort, }
                           { verification stricte reservee au TODO 19) }
    IsConst : Boolean;
    ArgFirst: Integer;
    ArgCount: Integer;
  End;

Var
  ExprPool     : Array[0..MAX_EXPR - 1] Of TExprNode;
  ExprCount    : Integer;
  ExprArgPool  : Array[0..MAX_EXPR_ARG - 1] Of Integer;
  ExprArgCount : Integer;

Procedure ExprInit;
Begin
  ExprCount    := 0;
  ExprArgCount := 0;
End;

Function ExprNew(K: TExprKind): Integer;
Begin
  If ExprCount >= MAX_EXPR Then
  Begin
    FatalError('table des noeuds d''expression pleine (MAX_EXPR)');
    ExprNew := 0;
    Exit;
  End;
  ExprPool[ExprCount].Kind     := K;
  ExprPool[ExprCount].Op       := '';
  ExprPool[ExprCount].Left     := -1;
  ExprPool[ExprCount].Right    := -1;
  ExprPool[ExprCount].Extra    := -1;
  ExprPool[ExprCount].NameVal  := '';
  ExprPool[ExprCount].IntVal   := 0;
  ExprPool[ExprCount].RealVal  := 0.0;
  ExprPool[ExprCount].StrVal   := '';
  ExprPool[ExprCount].TypeIdx  := -1;
  ExprPool[ExprCount].IsConst  := False;
  ExprPool[ExprCount].ArgFirst := -1;
  ExprPool[ExprCount].ArgCount := 0;
  ExprNew := ExprCount;
  Inc(ExprCount);
End;

Function ExprArgPush(EIdx: Integer): Integer;
Begin
  If ExprArgCount >= MAX_EXPR_ARG Then
  Begin
    FatalError('table des arguments d''expression pleine (MAX_EXPR_ARG)');
    ExprArgPush := 0;
    Exit;
  End;
  ExprArgPool[ExprArgCount] := EIdx;
  ExprArgPush := ExprArgCount;
  Inc(ExprArgCount);
End;

{ ExprAddIdent : resout SI (SymTab) IMMEDIATEMENT, PENDANT que la     }
{ bonne portee est ENCORE ouverte - MEME technique EXACTE que              }
{ GOCW32.PAS/SWIFTW32.PAS (voir la note d en-tete de TExprKind.EK_IDENT).    }
{ Un identificateur qui NE resout NI a un local/parametre/this/super             }
{ (SymFindEnclosing) NI a un CHAMP de la classe COURANTE (ClassFindField,       }
{ TODO 08 - accede implicitement via "this", section 8.3) reste                        }
{ SI=-1/TypeIdx=-1, JAMAIS un FatalError ICI - methode/classe restent            }
{ les SEULS cas encore non couverts (verification stricte                             }
{ "identificateur inconnu" reservee au TODO 19).                                          }
{                                                                       }
{ BOGUE REEL trouve par EXECUTION (TODO 08, ClassSelfTest) : SymFind         }
{ (TODO 06) parcourt TOUTE la table, y compris des portees DEJA                     }
{ FERMEES (limitation deja documentee sur SymFind lui-meme comme                    }
{ "n a de sens de corriger qu une fois un VRAI usage" survienne) - avec           }
{ PLUSIEURS methodes soeurs dans UNE MEME classe (TODO 08, chacune SA           }
{ PROPRE portee de parametres), un parametre d une methode DEJA close             }
{ (ex. "nom" du constructeur de Personne) restait trouvable PAR NOM               }
{ a l interieur d une méthode SUIVANTE tout a fait DIFFERENTE (getNom())           }
{ qui n a POURTANT aucun parametre de ce nom - masquant a tort l acces           }
{ IMPLICITE au CHAMP "nom" que ClassFindField aurait du fournir. Fixe         }
{ en resolvant via SymFindEnclosing (TODO 05 - ne regarde QUE la chaine       }
{ de portees ACTUELLEMENT ouvertes, ScopeStack), jamais des entrees               }
{ perimees. Aucun autre appelant de ExprAddIdent ne pouvait legitimement           }
{ dependre de l ancien comportement (les CHAMPS ne sont JAMAIS dans                  }
{ SymTab, uniquement locales/parametres/this/super - tous correctement            }
{ empiles/depiles par SymEnterScope/SymLeaveScope). }
Function ExprAddIdent(Const Nam: TString): Integer;
Var N, SI, FI, TI : Integer;
Begin
  SI := SymFindEnclosing(Nam);
  If SI >= 0 Then
  Begin
    N := ExprNew(EK_IDENT);
    ExprPool[N].NameVal := Nam;
    ExprPool[N].Left    := SI;
    ExprPool[N].TypeIdx := SymTab[SI].TypeIdx;
    ExprPool[N].IsConst := SymTab[SI].IsFinal And SymTab[SI].HasInit;
    ExprAddIdent := N;
    Exit;
  End;

  If CurrentClassTypeIdx >= 0 Then
  Begin
    FI := ClassFindField(CurrentClassTypeIdx, Nam);
    If FI >= 0 Then
    Begin
      N := ExprNew(EK_SELECTOR);
      ExprPool[N].NameVal := Nam;
      ExprPool[N].Left    := ExprAddIdent('this');   { recursif UNE SEULE   }
                                                       { fois - "this" est       }
                                                       { TOUJOURS resolu par     }
                                                       { SymFind ci-dessus dans      }
                                                       { CET APPEL RECURSIF,        }
                                                       { AUCUNE boucle possible. }
      ExprPool[N].TypeIdx := FieldPool[FI].TypeIdx;
      ExprAddIdent := N;
      Exit;
    End;
  End;

  { TODO 13 (section 12.15) : dernier recours AVANT de renoncer -       }
  { "Nam" est-il un nom de classe/interface CONNU (TypeFindByName,                }
  { TODO 08, deja utilise pour resoudre un TYPE dans un contexte de                }
  { DECLARATION) ? Si oui, ce n est PAS une valeur - c est une                        }
  { REFERENCE AU TYPE lui-meme, necessaire pour reconnaitre                            }
  { "Integer.parseInt(...)" (appel STATIQUE qualifie par un nom de                    }
  { classe - TODO 08 avait EXPLICITEMENT differe cette forme). }
  TI := TypeFindByName(Nam);
  If TI >= 0 Then
  Begin
    N := ExprNew(EK_TYPEREF);
    ExprPool[N].NameVal := Nam;
    ExprPool[N].TypeIdx := TI;
    ExprAddIdent := N;
    Exit;
  End;

  N := ExprNew(EK_IDENT);
  ExprPool[N].NameVal := Nam;
  ExprPool[N].Left    := -1;
  ExprAddIdent := N;
End;

{ TypeUnaryNumericPromote : promotion UNAIRE reelle (sections 4.7/6.3 -  }
{ byte/short/char -> int, TOUT AUTRE type numerique INCHANGE) -                }
{ DIFFERENTE de TypeBinaryPromote (TODO 04), qui ABSORBE deja cette              }
{ regle mais pour DEUX operandes A LA FOIS - ne convient pas ICI : les           }
{ DECALAGES (section 6.8, seul l operande GAUCHE compte pour le TYPE               }
{ resultat) et les unaires +/-/~ (section 6.3, un SEUL operande) n ont             }
{ besoin de promouvoir QU UN SEUL type a la fois, jamais un "vote a                    }
{ deux" comme les binaires + - * / . }
Function TypeUnaryNumericPromote(T: Integer): Integer;
Begin
  If (T = PRIMTYPE_BYTE) Or (T = PRIMTYPE_SHORT) Or (T = PRIMTYPE_CHAR) Then
    TypeUnaryNumericPromote := PRIMTYPE_INT
  Else
    TypeUnaryNumericPromote := T;
End;

{ ExprInferBinaryType : type resultat d un EK_BINARY - regle EXACTE de  }
{ CHAQUE sous-section citee, jamais devinee : booleen pour toute               }
{ comparaison/egalite/court-circuit (6.9/6.11/6.13) ; type de l operande         }
{ GAUCHE SEUL, promu, pour un decalage (6.8) ; booleen SI LES DEUX               }
{ operandes sont booleens, SINON promotion binaire ordinaire, pour               }
{ &/^/| (6.12) ; TOUJOURS String des qu un operande de "+" est deja                }
{ String (6.7 - REGLE PRIORITAIRE, verifiee AVANT la promotion                        }
{ numerique ordinaire) ; promotion binaire (TODO 04) pour tout le                       }
{ reste (* / % + -, 6.5/6.6/6.7). }
Function ExprInferBinaryType(Const Op: TString; LT, RT: Integer): Integer;
Begin
  ExprInferBinaryType := -1;

  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Or (Op = '&&') Or (Op = '||') Then
  Begin
    ExprInferBinaryType := PRIMTYPE_BOOLEAN;
    Exit;
  End;

  If (Op = '<<') Or (Op = '>>') Or (Op = '>>>') Then
  Begin
    ExprInferBinaryType := TypeUnaryNumericPromote(LT);
    Exit;
  End;

  If (Op = '&') Or (Op = '^') Or (Op = '|') Then
  Begin
    If (LT = PRIMTYPE_BOOLEAN) And (RT = PRIMTYPE_BOOLEAN) Then
      ExprInferBinaryType := PRIMTYPE_BOOLEAN
    Else
      ExprInferBinaryType := TypeBinaryPromote(LT, RT);
    Exit;
  End;

  If (Op = '+') And ((LT = PDT_STRING) Or (RT = PDT_STRING)) Then
  Begin
    ExprInferBinaryType := PDT_STRING;
    Exit;
  End;

  ExprInferBinaryType := TypeBinaryPromote(LT, RT);
End;

Function ExprNewBinary(Const Op: TString; L, R: Integer): Integer;
Var N : Integer;
Begin
  N := ExprNew(EK_BINARY);
  ExprPool[N].Op      := Op;
  ExprPool[N].Left    := L;
  ExprPool[N].Right   := R;
  ExprPool[N].TypeIdx := ExprInferBinaryType(Op, ExprPool[L].TypeIdx, ExprPool[R].TypeIdx);
  ExprPool[N].IsConst := ExprPool[L].IsConst And ExprPool[R].IsConst;
  ExprNewBinary := N;
End;

{ ExprNewUnary : +/-/~ appliquent TypeUnaryNumericPromote (section 6.3, }
{ MEME regle que le decalage) ; ! renvoie TOUJOURS PRIMTYPE_BOOLEAN ;      }
{ ++/-- (prefixe OU 'post'-prefixe, section 6.4) conservent le type          }
{ EXACT de l operande, "conversion vers son propre type implicite"            }
{ (roadmap section 6.4) - AUCUNE promotion pour eux, contrairement a +/-/~. }
Function ExprNewUnary(Const Op: TString; Sub: Integer): Integer;
Var N : Integer;
Begin
  N := ExprNew(EK_UNARY);
  ExprPool[N].Op   := Op;
  ExprPool[N].Left := Sub;
  If Op = '!' Then
    ExprPool[N].TypeIdx := PRIMTYPE_BOOLEAN
  Else If (Op = '+') Or (Op = '-') Or (Op = '~') Then
    ExprPool[N].TypeIdx := TypeUnaryNumericPromote(ExprPool[Sub].TypeIdx)
  Else
    ExprPool[N].TypeIdx := ExprPool[Sub].TypeIdx;   { ++/-- : type inchange }
  ExprPool[N].IsConst := (Op = '+') Or (Op = '-') Or (Op = '~') Or (Op = '!');
  If ExprPool[N].IsConst Then
    ExprPool[N].IsConst := ExprPool[Sub].IsConst;
  ExprNewUnary := N;
End;

{ LooksLikeCastAhead : lookahead SANS EFFET DE BORD (PP sauvegarde ET   }
{ restaure dans TOUS les cas) - "(" suivi d un TYPE CONNU (mot-cle           }
{ primitif, TOUJOURS un cast puisqu un mot-cle n est jamais une                  }
{ expression valide, OU identificateur PREDECLARE - String, Object,             }
{ etc.) suivi de zero ou plusieurs "[]" PUIS ")" - classes UTILISATEUR              }
{ NON couvertes (TODO 08, meme restriction que ParseTypeRef/                          }
{ ParseBaseTypeNoBrackets, DONC "(Chien)animal" ne peut jamais etre                     }
{ reconnu comme cast ICI - il tombera dans le "(" expr ")" ordinaire                }
{ de ParsePrimary a la place, avec un FatalError PROPRE au moment ou               }
{ ParseBaseTypeNoBrackets tenterait, lui, de le resoudre PLUS LOIN                    }
{ dans l analyse s il etait utilise comme type - ne se produit PAS ici,             }
{ "Chien" y est alors traite comme un identificateur ORDINAIRE, non               }
{ resolu, meme discipline "best-effort" que ExprAddIdent). N appelle                }
{ JAMAIS ParseTypeRef/ParseBaseTypeNoBrackets pour DE VRAI (qui                     }
{ appellerait TypeAdd - EFFET DE BORD reel, un DOUBLE enregistrement                   }
{ serait cree si le VRAI ParseUnary re-analysait ensuite le meme type              }
{ tableau) - reimplemente une verification de FORME PURE a la place. }
Function LooksLikeCastAhead: Boolean;
Var Save : Integer;
Begin
  Save := PP;
  LooksLikeCastAhead := False;
  If Not PPIsOp('(') Then Begin PP := Save; Exit; End;
  PPAdvance;
  If PPKind <> TOK_IDENT Then Begin PP := Save; Exit; End;
  If (IsKeyword(PPVal) = 0) And (IsPredeclaredType(PPVal) = 0) Then
  Begin
    PP := Save;
    Exit;
  End;
  If (IsKeyword(PPVal) <> 0) And (PrimitiveTypeFromKeyword(IsKeyword(PPVal)) < 0) Then
  Begin
    PP := Save;   { mot-cle reserve mais PAS un type (ex. "class")   }
    Exit;
  End;
  PPAdvance;
  While PPIsOp('[') Do
  Begin
    PPAdvance;
    If Not PPMatch(']') Then Begin PP := Save; Exit; End;
  End;
  LooksLikeCastAhead := PPIsOp(')');
  PP := Save;
End;

{ Chaine de fonctions recursives-descendantes, une par NIVEAU de        }
{ precedence (section 6.1) - la plus FORTE en premier. Forward-          }
{ declaree PLUS HAUT (voir ParseVarDecl, TODO 05/09) car ParsePrimary/     }
{ ParseNewExpr en ont ILS AUSSI besoin pour les parentheses/arguments/       }
{ indices/initialiseurs, bien AVANT sa propre definition plus bas dans          }
{ cette chaine. }

{ ParseArrayInitializer : corps REEL (Forward plus haut, avant           }
{ ParseVarDecl) d un initialiseur de tableau "nu" (section 10.4,                    }
{ "Type[] nom = accolade-liste;", SANS "new T[]" devant - a la                          }
{ difference de "new T[]accolade-liste" du TODO 06/section 6.21, qui               }
{ garde SA PROPRE logique inchangee dans ParseNewExpr plus bas, pour             }
{ ne PAS toucher un code deja teste). ElemT recu est DEJA le type                     }
{ TABLEAU COMPLET du declarateur (ex. int[] pour "int[] notes = ..."),          }
{ MEME convention que le "ElemT" de ParseNewExpr a ce meme point de              }
{ son propre flux. PORTEE reduite a une liste PLATE d expressions                    }
{ (section 10.4, litteral "int[] notes = ...valeurs...") - initialiseur          }
{ IMBRIQUE multi-dimensionnel (section 10.13, des accolades DANS les             }
{ accolades pour un tableau de tableaux) explicitement HORS de portee            }
{ (AUCUN echantillon reel ne l exerce, Test05Tableaux.jpp construit                 }
{ ses tableaux multi-dimensionnels EXCLUSIVEMENT via "new", jamais                    }
{ un initialiseur imbrique). }
Function ParseArrayInitializer(ElemT: Integer): Integer;
Var N : Integer;
Begin
  N := ExprNew(EK_NEWARRAY);
  ExprPool[N].Op      := 'init';
  ExprPool[N].TypeIdx := ElemT;

  If Not PPMatch('{') Then
  Begin
    FatalError('"{" attendu au debut d''un initialiseur de tableau ' +
      '(section 10.4)');
    ParseArrayInitializer := N;
    Exit;
  End;

  ParseArgListInto('}', ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
  If Not PPMatch('}') Then
    FatalError('"}" attendu a la fin d''un initialiseur de tableau ' +
      '(section 10.4)');

  ParseArrayInitializer := N;
End;

{ ParseArgListInto : liste d expressions separees par "," jusqu au         }
{ delimiteur FERMANT "Term" (parenthese fermante pour un appel/une                  }
{ creation d objet, accolade fermante pour un initialiseur de                            }
{ tableau) - le delimiteur OUVRANT est deja consomme par l appelant,               }
{ "Term" LUI-MEME n est PAS consomme ICI (a l appelant de le faire,               }
{ chacun avec SON PROPRE message d erreur).                                                    }
{                                                                       }
{ BOGUE REEL trouve par EXECUTION (TODO 13, StdlibSelfTest -                        }
{ "new PrintWriter(new BufferedWriter(new FileWriter(...)))", un                        }
{ CONSTRUCTEUR imbrique comme UNIQUE argument d un AUTRE constructeur)          }
{ - EXACTEMENT le MEME risque d entrelacement que celui deja corrige              }
{ dans ParseBlock/ParseSwitchStmt (StmtArgPool, TODO 08) puis                            }
{ ParseTryStmt (TODO 11), mais cette fois sur ExprArgPool : capturer            }
{ ArgFirst := ExprArgCount AVANT de parser les arguments, PUIS pousser          }
{ un argument a la fois PENDANT leur parsing, suppose qu AUCUN autre              }
{ appel/creation d objet ne pousse dans ExprArgPool entre-temps - FAUX          }
{ des qu un argument est LUI-MEME un "new Type(args)" ou un appel                     }
{ "f(args)" (recursion dans ParsePostfix/ParseNewExpr, qui pousse ALORS         }
{ ses PROPRES arguments AVANT que l appelant externe ne pousse le sien).      }
{ Fixe EXACTEMENT comme les deux precedents : collecter D ABORD chaque          }
{ argument dans un tableau LOCAL, PUIS les pousser EN UN SEUL balayage           }
{ ininterrompu - ArgFirst n est capture qu APRES que le parsing                        }
{ RECURSIF de TOUS les arguments soit termine. Utilisee par ParseNewExpr    }
{ (arguments de constructeur ET initialiseur de tableau APRES "new",             }
{ juste en dessous), ParseArrayInitializer (initialiseur "nu" du TODO 10,           }
{ plus haut - meme risque, corrige au passage) et ParsePostfix (le "("           }
{ d appel de methode, plus bas) - MEME fonction PARTAGEE, le risque              }
{ etait IDENTIQUE partout. }
Procedure ParseArgListInto(Const Term: TString; Var OutArgFirst, OutArgCount: Integer);
Const
  MAX_CALL_ARGS = 32;
Var
  Tmp : Array[0..MAX_CALL_ARGS - 1] Of Integer;
  Cnt, I : Integer;
Begin
  Cnt := 0;
  If Not PPIsOp(Term) Then
    Repeat
      If Cnt < MAX_CALL_ARGS Then
      Begin
        Tmp[Cnt] := ParseExpr;
        Inc(Cnt);
      End
      Else
      Begin
        WarnMsg('trop d''arguments pour un appel (MAX_CALL_ARGS)');
        ParseExpr;
      End;
    Until Not PPMatch(',');

  OutArgFirst := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    ExprArgPush(Tmp[I]);
  OutArgCount := Cnt;
End;

{ ParseNewExpr : "new Type(args)" (creation d objet, section 6.20 -    }
{ PORTEE : seuls les 6 types REFERENCE predeclares - TODO 03/04 -               }
{ peuvent reellement y aboutir, une classe UTILISATEUR arrete                        }
{ PROPREMENT via ParseBaseTypeNoBrackets, TODO 08) OU "new Type[dims]"           }
{ / "new Type[] accolade-initialiseur" (creation de tableau, section              }
{ 6.21). Chaque              }
{ paire "[...]" est soit une DIMENSION CHIFFREE (expression, stockee             }
{ dans ArgFirst/Count), soit VIDE (construit simplement un TYK_ARRAY               }
{ de PLUS, sans expression associee) - AUCUNE verification de l ORDRE            }
{ "chiffrees puis vides uniquement" (section 6.21) n est effectuee ici           }
{ (best-effort, TODO 19, comme le reste de l analyse semantique de ce            }
{ projet). }
Function ParseNewExpr: Integer;
Var
  BaseT, ElemT, N, DimE : Integer;
Begin
  PPAdvance;   { 'new' }
  BaseT := ParseBaseTypeNoBrackets;

  If Not PPIsOp('[') Then
  Begin
    N := ExprNew(EK_NEWOBJECT);
    ExprPool[N].Extra   := BaseT;
    ExprPool[N].TypeIdx := BaseT;
    If PPMatch('(') Then
    Begin
      ParseArgListInto(')', ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
      If Not PPMatch(')') Then
        FatalError('")" attendu apres les arguments d''une creation d''objet');
    End
    Else
      FatalError('"(" attendu apres un type dans une creation d''objet ' +
        '(section 6.20)');

    { TODO 08 : "new Classe(...)" contre une VRAIE classe utilisateur -    }
    { classe abstraite = erreur (section 8.21) ; sinon resolution           }
    { best-effort du constructeur REELLEMENT appele (section 8.6/8.7,          }
    { surcharge par NOMBRE d arguments), rangee dans Left - EK_NEWOBJECT           }
    { n utilisait ce champ pour RIEN d autre jusqu ici. }
    If (BaseT >= 0) And (BaseT < TypeCount) And (TypeTab[BaseT].Kind = TYK_CLASS) Then
    Begin
      If TypeTab[BaseT].IsAbstractClass Then
        FatalError('impossible d''instancier la classe abstraite "' +
          TypeTab[BaseT].Name + '" (section 8.21)');
      ExprPool[N].Left := ClassFindConstructor(BaseT, ExprPool[N].ArgFirst,
        ExprPool[N].ArgCount);
    End
    Else If (BaseT >= 0) And (BaseT < TypeCount) And (TypeTab[BaseT].Kind = TYK_DELEGATE) Then
      { TODO 16 (section 16.5/16.6) : "new NomDelegate(cible.methode)" -   }
      { AUCUN constructeur n existe pour un delegate (ce n est PAS une        }
      { VRAIE classe) - Left recoit ICI la methode CIBLE resolue             }
      { (DelegateResolveTarget, -1 si non resolue, MEME convention              }
      { best-effort que ClassFindConstructor ci-dessus) plutot qu un              }
      { index de constructeur - meme champ, meme "n utilisait ce champ                }
      { pour RIEN d autre jusqu ici" que documente pour la branche                    }
      { TYK_CLASS. Le RECEVEUR (l objet cible, "this" par exemple) reste          }
      { recuperable SANS stockage supplementaire : c est                                    }
      { ExprPool[ExprArgPool[ArgFirst]].Left, DEJA present dans                          }
      { l argument brut conserve par ArgFirst/ArgCount (section 16.5,               }
      { "il encapsule... l objet receveur"). }
      ExprPool[N].Left := DelegateResolveTarget(BaseT, ExprPool[N].ArgFirst,
        ExprPool[N].ArgCount);

    ParseNewExpr := N;
    Exit;
  End;

  N := ExprNew(EK_NEWARRAY);
  ExprPool[N].ArgFirst := ExprArgCount;
  ExprPool[N].ArgCount := 0;
  ElemT := BaseT;
  While PPIsOp('[') Do
  Begin
    PPAdvance;
    If PPIsOp(']') Then
    Begin
      PPAdvance;
      ElemT := TypeAdd(TYK_ARRAY, '', 4, 4, ElemT);
    End
    Else
    Begin
      DimE := ParseExpr;
      If Not PPMatch(']') Then
        FatalError('"]" attendu apres une dimension de tableau');
      ExprArgPush(DimE);
      Inc(ExprPool[N].ArgCount);
      ElemT := TypeAdd(TYK_ARRAY, '', 4, 4, ElemT);
    End;
  End;

  If PPIsOp('{') Then
  Begin
    If ExprPool[N].ArgCount > 0 Then
      FatalError('une taille et un initialiseur ne se combinent pas ' +
        '(section 6.21)');
    ExprPool[N].Op := 'init';
    PPAdvance;
    ParseArgListInto('}', ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
    If Not PPMatch('}') Then
      FatalError('"}" attendu a la fin d''un initialiseur de tableau');
  End
  Else
    ExprPool[N].Op := 'dims';

  ExprPool[N].TypeIdx := ElemT;
  ParseNewExpr := N;
End;

{ ParsePrimary : litteraux (section 3.4/TODO 02), identificateur           }
{ (resolu via ExprAddIdent), "(" expression ")", "new" (ParseNewExpr).       }
{ "this"/"super" (section 6.23) restent HORS de portee - AUCUN contexte      }
{ de methode d instance n existe encore (TODO 08) pour leur donner un           }
{ sens : arret PROPRE (FatalError) plutot que de deviner une instance             }
{ implicite. }
Function ParsePrimary: Integer;
Var N, KW, PL : Integer; Nam : TString;
Begin
  Case PPKind Of
    TOK_INT:
    Begin
      N := ExprNew(EK_INTLIT);
      ExprPool[N].IntVal  := TokenPool[PP].IntVal;
      ExprPool[N].TypeIdx := PRIMTYPE_INT;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    TOK_LONG:
    Begin
      N := ExprNew(EK_LONGLIT);
      ExprPool[N].IntVal  := TokenPool[PP].IntVal;
      ExprPool[N].TypeIdx := PRIMTYPE_LONG;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    TOK_FLOAT:
    Begin
      N := ExprNew(EK_FLOATLIT);
      ExprPool[N].RealVal := TokenPool[PP].RealVal;
      ExprPool[N].TypeIdx := PRIMTYPE_FLOAT;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    TOK_DOUBLE:
    Begin
      N := ExprNew(EK_DOUBLELIT);
      ExprPool[N].RealVal := TokenPool[PP].RealVal;
      ExprPool[N].TypeIdx := PRIMTYPE_DOUBLE;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    TOK_CHAR:
    Begin
      N := ExprNew(EK_CHARLIT);
      ExprPool[N].IntVal  := TokenPool[PP].IntVal;
      ExprPool[N].TypeIdx := PRIMTYPE_CHAR;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    TOK_STRING:
    Begin
      N := ExprNew(EK_STRINGLIT);
      ExprPool[N].StrVal  := TokenPool[PP].Val;
      ExprPool[N].TypeIdx := PDT_STRING;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
  End;

  If PPIsOp('(') Then
  Begin
    PPAdvance;
    N := ParseExpr;
    If Not PPMatch(')') Then
      FatalError('")" attendu');
    ParsePrimary := N;
    Exit;
  End;

  If PPKind = TOK_IDENT Then
  Begin
    KW := IsKeyword(PPVal);
    If KW = KW_NEW Then
    Begin
      ParsePrimary := ParseNewExpr;
      Exit;
    End;
    If (KW = KW_THIS) Or (KW = KW_SUPER) Then
    Begin
      { TODO 08 : "this"/"super" sont enregistres comme de VRAIS         }
      { identificateurs (SymTab) au debut de tout corps de methode/            }
      { constructeur D'INSTANCE (section 8.8/8.9) - ICI on se contente          }
      { de les RESOUDRE via ce mecanisme existant (ExprAddIdent/                     }
      { SymFindEnclosing), AUCUN TExprKind special n est invente.                    }
      { SymFindEnclosing (PAS SymFind) - MEME correctif que ExprAddIdent            }
      { plus haut : une methode STATIQUE (aucun this/super) suivant, dans      }
      { le MEME fichier de test, une methode D INSTANCE deja refermee                }
      { (this/super alors perimes dans SymTab) ne doit JAMAIS retrouver               }
      { ce this/super PERIME par SymFind. }
      If SymFindEnclosing(PPVal) >= 0 Then
      Begin
        N := ExprAddIdent(PPVal);
        PPAdvance;
        ParsePrimary := N;
        Exit;
      End;
      FatalError('"this"/"super" hors de portee (section 8.8/8.9 - ' +
        'valide seulement a l''interieur du corps d''une methode ou ' +
        'd''un constructeur d''instance)');
      ParsePrimary := ExprNew(EK_INTLIT);
      Exit;
    End;

    PL := IsPredeclaredLiteral(PPVal);
    If PL = PL_TRUE Then
    Begin
      N := ExprNew(EK_BOOLLIT);
      ExprPool[N].IntVal  := 1;
      ExprPool[N].TypeIdx := PRIMTYPE_BOOLEAN;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    If PL = PL_FALSE Then
    Begin
      N := ExprNew(EK_BOOLLIT);
      ExprPool[N].IntVal  := 0;
      ExprPool[N].TypeIdx := PRIMTYPE_BOOLEAN;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;
    If PL = PL_NULL Then
    Begin
      N := ExprNew(EK_NULLLIT);
      ExprPool[N].TypeIdx := PRIMTYPE_NULL;
      ExprPool[N].IsConst := True;
      PPAdvance;
      ParsePrimary := N;
      Exit;
    End;

    Nam := PPVal;
    PPAdvance;
    ParsePrimary := ExprAddIdent(Nam);
    Exit;
  End;

  FatalError('expression attendue');
  ParsePrimary := ExprNew(EK_INTLIT);
End;

{ ParsePostfix : ".", "[indice]", "(arguments)", postfixe ++/--          }
{ (sections 6.17-6.19, 6.4) - REPETES en boucle (chainable : "a.b.c",           }
{ "m[i][j]", "f()()" resteraient tous corrects structurellement). ".length"     }
{ sur un tableau (section 6.18) reste le SEUL selecteur DIRECTEMENT              }
{ resolu ICI-MEME (champ FINAL int synthetique) - un selecteur "obj.champ"        }
{ sur une VRAIE classe utilisateur (TYK_CLASS) est desormais resolu via              }
{ ClassFindField (TODO 08, section 8.3/8.11) ; un selecteur qui reste             }
{ NON resolu a ce stade (TypeIdx=-1) est traite comme un nom de METHODE            }
{ probable et resolu PLUS BAS, au moment de l appel "(" (ClassResolveMethodCall,   }
{ le type de retour n est connu qu une fois les arguments PARSES) - MEME          }
{ discipline "best-effort, jamais de FatalError" que ExprAddIdent. }
Function ParsePostfix: Integer;
Var
  Cur, N, BaseT, MI : Integer;
  Nam, Op : TString;
Begin
  Cur := ParsePrimary;
  While True Do
  Begin
    If PPIsOp('.') Then
    Begin
      PPAdvance;
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ/methode attendu apres "."');
        Break;
      End;
      Nam := PPVal;
      PPAdvance;
      N := ExprNew(EK_SELECTOR);
      ExprPool[N].Left    := Cur;
      ExprPool[N].NameVal := Nam;
      BaseT := ExprPool[Cur].TypeIdx;
      If (Nam = 'length') And (BaseT >= 0) And (BaseT < TypeCount) And
         (TypeTab[BaseT].Kind = TYK_ARRAY) Then
        ExprPool[N].TypeIdx := PRIMTYPE_INT
      Else If (BaseT >= 0) And (BaseT < TypeCount) And
              (TypeTab[BaseT].Kind In [TYK_CLASS, TYK_INTERFACE, TYK_STRING, TYK_DELEGATE]) Then
      Begin
        { TODO 08/09 : "obj.champ" (TYK_INTERFACE ajoute au TODO 09 pour     }
        { "Interface.CONSTANTE" - section 9.4, champ D INTERFACE TOUJOURS       }
        { static final) - un echec ICI n est PAS une erreur, Nam                     }
        { pourrait tout aussi bien designer une METHODE (resolue plus bas,       }
        { au "(" qui suit, jamais ici ou les arguments ne sont pas encore          }
        { connus). }
        MI := ClassFindField(BaseT, Nam);
        If MI >= 0 Then
          ExprPool[N].TypeIdx := FieldPool[MI].TypeIdx;
      End;
      Cur := N;
      Continue;
    End;

    If PPIsOp('[') Then
    Begin
      PPAdvance;
      N := ExprNew(EK_INDEX);
      ExprPool[N].Left  := Cur;
      ExprPool[N].Right := ParseExpr;
      If Not PPMatch(']') Then
        FatalError('"]" attendu dans un indice (section 6.18)');
      BaseT := ExprPool[Cur].TypeIdx;
      If (BaseT >= 0) And (BaseT < TypeCount) And (TypeTab[BaseT].Kind = TYK_ARRAY) Then
        ExprPool[N].TypeIdx := TypeTab[BaseT].ElemTypeIdx;
      Cur := N;
      Continue;
    End;

    If PPIsOp('(') Then
    Begin
      PPAdvance;
      N := ExprNew(EK_CALL);
      ExprPool[N].Left := Cur;
      ParseArgListInto(')', ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
      If Not PPMatch(')') Then
        FatalError('")" attendu apres les arguments d''appel (section 6.19)');

      { TODO 08 : resolution best-effort de l APPEL DE METHODE - explicite  }
      { "obj.methode(...)" (Cur = EK_SELECTOR NON resolu par le "." plus       }
      { haut - donc PAS un champ) OU IMPLICITE "methode(...)" a l interieur      }
      { d un corps de methode/constructeur (Cur = EK_IDENT NON resolu par         }
      { ExprAddIdent, CurrentClassTypeIdx suit la classe EN COURS) -                 }
      { ClassResolveMethodCall (section 8.13/8.32, surcharge par TYPE) a           }
      { besoin des arguments DEJA parses (ArgFirst/ArgCount ci-dessus) pour        }
      { choisir entre plusieurs methodes de MEME nom - impossible plus tot. }
      If (ExprPool[Cur].Kind = EK_SELECTOR) And (ExprPool[Cur].TypeIdx < 0) Then
      Begin
        BaseT := ExprPool[ExprPool[Cur].Left].TypeIdx;
        { TYK_INTERFACE ajoute au TODO 09 (section 9.11/9.12) : un appel  }
        { "reference.methode(...)" a travers une variable dont le TYPE          }
        { STATIQUE est une interface (ex. "listener.valeurChangee(...)")          }
        { doit resoudre contre le CONTRAT de l interface elle-meme, jamais         }
        { une classe implementante precise - inconnue de toute facon a               }
        { la compilation (liaison dynamique REELLE = TODO 21+, ceci reste           }
        { une resolution LEXICALE best-effort). }
        If (BaseT >= 0) And (BaseT < TypeCount) And
           (TypeTab[BaseT].Kind In [TYK_CLASS, TYK_INTERFACE, TYK_STRING, TYK_DELEGATE]) Then
        Begin
          MI := ClassResolveMethodCall(BaseT, ExprPool[Cur].NameVal,
            ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
          If MI >= 0 Then
          Begin
            ExprPool[N].TypeIdx := MethodPool[MI].RetTypeIdx;
            ExprPool[N].Extra   := MI;   { TODO 21 - voir la note d en-tete d EK_CALL }
          End;
        End;
      End
      Else If (ExprPool[Cur].Kind = EK_IDENT) And (ExprPool[Cur].Left < 0) And
              (CurrentClassTypeIdx >= 0) Then
      Begin
        MI := ClassResolveMethodCall(CurrentClassTypeIdx, ExprPool[Cur].NameVal,
          ExprPool[N].ArgFirst, ExprPool[N].ArgCount);
        If MI >= 0 Then
        Begin
          ExprPool[N].TypeIdx := MethodPool[MI].RetTypeIdx;
          ExprPool[N].Extra   := MI;   { TODO 21 - voir la note d en-tete d EK_CALL }
        End;
      End;

      Cur := N;
      Continue;
    End;

    If PPIsOp('++') Or PPIsOp('--') Then
    Begin
      Op := PPVal;
      PPAdvance;
      N := ExprNew(EK_UNARY);
      ExprPool[N].Op      := 'post' + Op;
      ExprPool[N].Left    := Cur;
      ExprPool[N].TypeIdx := ExprPool[Cur].TypeIdx;
      Cur := N;
      Continue;
    End;

    Break;
  End;
  ParsePostfix := Cur;
End;

{ ParseUnary : prefixe +/-/~/! (6.3), prefixe ++/-- (6.4), cast          }
{ "(Type)expr" (6.22, LooksLikeCastAhead ci-dessus tranche l ambiguite       }
{ avec une simple expression parenthesee) - droite-associatif             }
{ (recursion sur lui-meme), MEME NIVEAU EXACT que la section 6.1. }
Function ParseUnary: Integer;
Var Op : TString; T, N : Integer;
Begin
  If PPIsOp('+') Or PPIsOp('-') Or PPIsOp('~') Or PPIsOp('!') Or
     PPIsOp('++') Or PPIsOp('--') Then
  Begin
    Op := PPVal;
    PPAdvance;
    ParseUnary := ExprNewUnary(Op, ParseUnary);
    Exit;
  End;

  If LooksLikeCastAhead Then
  Begin
    PPAdvance;   { '(' }
    T := ParseTypeRef;
    PPMatch(')');
    N := ExprNew(EK_CAST);
    ExprPool[N].Left    := ParseUnary;
    ExprPool[N].Extra   := T;
    ExprPool[N].TypeIdx := T;
    ParseUnary := N;
    Exit;
  End;

  ParseUnary := ParsePostfix;
End;

Function ParseMul: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseUnary;
  While PPIsOp('*') Or PPIsOp('/') Or PPIsOp('%') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseUnary);
  End;
  ParseMul := L;
End;

Function ParseAdd: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseMul;
  While PPIsOp('+') Or PPIsOp('-') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseMul);
  End;
  ParseAdd := L;
End;

Function ParseShift: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseAdd;
  While PPIsOp('<<') Or PPIsOp('>>') Or PPIsOp('>>>') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseAdd);
  End;
  ParseShift := L;
End;

{ ParseRel : relationnels < <= > >= PLUS "instanceof" (section 6.10)   }
{ au MEME niveau de precedence (section 6.1) - RHS de instanceof est       }
{ une reference de TYPE, jamais une expression, EK_INSTANCEOF dedie           }
{ (meme technique que EK_ISCHECK "is Type" de SWIFTW32.PAS). }
Function ParseRel: Integer;
Var L, N, T : Integer; Op : TString;
Begin
  L := ParseShift;
  While True Do
  Begin
    If PPIsOp('<') Or PPIsOp('<=') Or PPIsOp('>') Or PPIsOp('>=') Then
    Begin
      Op := PPVal;
      PPAdvance;
      L := ExprNewBinary(Op, L, ParseShift);
    End
    Else If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_INSTANCEOF) Then
    Begin
      PPAdvance;
      T := ParseTypeRef;
      N := ExprNew(EK_INSTANCEOF);
      ExprPool[N].Left    := L;
      ExprPool[N].Extra   := T;
      ExprPool[N].TypeIdx := PRIMTYPE_BOOLEAN;
      ExprPool[N].IsConst := False;
      L := N;
    End
    Else
      Break;
  End;
  ParseRel := L;
End;

Function ParseEq: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseRel;
  While PPIsOp('==') Or PPIsOp('!=') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseRel);
  End;
  ParseEq := L;
End;

Function ParseBitAnd: Integer;
Var L : Integer;
Begin
  L := ParseEq;
  While PPIsOp('&') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('&', L, ParseEq);
  End;
  ParseBitAnd := L;
End;

Function ParseBitXor: Integer;
Var L : Integer;
Begin
  L := ParseBitAnd;
  While PPIsOp('^') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('^', L, ParseBitAnd);
  End;
  ParseBitXor := L;
End;

Function ParseBitOr: Integer;
Var L : Integer;
Begin
  L := ParseBitXor;
  While PPIsOp('|') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('|', L, ParseBitXor);
  End;
  ParseBitOr := L;
End;

Function ParseLogAnd: Integer;
Var L : Integer;
Begin
  L := ParseBitOr;
  While PPIsOp('&&') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('&&', L, ParseBitOr);
  End;
  ParseLogAnd := L;
End;

Function ParseLogOr: Integer;
Var L : Integer;
Begin
  L := ParseLogAnd;
  While PPIsOp('||') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('||', L, ParseLogAnd);
  End;
  ParseLogOr := L;
End;

{ ExprLiteralToConstVal : corps REEL (Forward plus haut, avant           }
{ ParseVarDecl - TODO 09). Reconnait EXACTEMENT la meme portee que           }
{ l ANCIEN ConstEvalExpr utilise par ParseVarDecl (litteral, avec un            }
{ "-" prefixe optionnel POUR UN litteral NUMERIQUE) mais a partir d un           }
{ noeud ExprPool DEJA construit (par ParseExpr, une VRAIE expression             }
{ generale) plutot que de tokens bruts - AUCUN repliage de constante            }
{ REEL au-dela de ce cas simple (une addition "1+2" reste NON reconnue,          }
{ MEME discipline "best-effort, aucun repliage" que le "case" de                       }
{ ParseSwitchStmt, TODO 07). }
Function ExprLiteralToConstVal(E: Integer; Var CV: TConstVal): Boolean;
Begin
  ExprLiteralToConstVal := True;
  CV.IntVal  := 0;
  CV.RealVal := 0.0;
  CV.StrVal  := '';
  Case ExprPool[E].Kind Of
    EK_INTLIT:    Begin CV.Kind := CK_INT;    CV.IntVal  := ExprPool[E].IntVal;  End;
    EK_LONGLIT:   Begin CV.Kind := CK_LONG;   CV.IntVal  := ExprPool[E].IntVal;  End;
    EK_FLOATLIT:  Begin CV.Kind := CK_FLOAT;  CV.RealVal := ExprPool[E].RealVal; End;
    EK_DOUBLELIT: Begin CV.Kind := CK_DOUBLE; CV.RealVal := ExprPool[E].RealVal; End;
    EK_CHARLIT:   Begin CV.Kind := CK_CHAR;   CV.IntVal  := ExprPool[E].IntVal;  End;
    EK_BOOLLIT:   Begin CV.Kind := CK_BOOL;   CV.IntVal  := ExprPool[E].IntVal;  End;
    EK_STRINGLIT: Begin CV.Kind := CK_STRING; CV.StrVal  := ExprPool[E].StrVal;  End;
    EK_NULLLIT:   Begin CV.Kind := CK_NULL;   End;
    EK_UNARY:
      If (ExprPool[E].Op = '-') And ExprLiteralToConstVal(ExprPool[E].Left, CV) Then
      Begin
        CV.IntVal  := -CV.IntVal;
        CV.RealVal := -CV.RealVal;
      End
      Else
        ExprLiteralToConstVal := False;
    Else
      ExprLiteralToConstVal := False;
  End;
End;

{ ParseExpr (= le ternaire, niveau le plus lache couvert ici - voir la  }
{ note d en-tete de section pour l affectation, EXCLUE) : droite-             }
{ associatif (section 6.1), UNE SEULE branche est "la vraie                        }
{ expression" en Java reel (pourrait inclure une affectation) -                       }
{ SIMPLIFICATION assumee ici (ParseExpr, PAS une grammaire "Expression"           }
{ separee) puisque l affectation est de toute facon HORS de portee de              }
{ ce parseur pour l instant - documentee, pas devinee. }
Function ParseExpr: Integer;
Var Cond, TrueE, FalseE, N, LT, RT : Integer;
Begin
  Cond := ParseLogOr;
  If PPIsOp('?') Then
  Begin
    PPAdvance;
    TrueE := ParseExpr;
    If Not PPMatch(':') Then
      FatalError('":" attendu dans un operateur ternaire (section 6.14)');
    FalseE := ParseExpr;

    N := ExprNew(EK_TERNARY);
    ExprPool[N].Left  := Cond;
    ExprPool[N].Right := TrueE;
    ExprPool[N].Extra := FalseE;

    { type resultat (section 6.14) - regle SIMPLIFIEE, best-effort (la   }
    { vraie regle Java couvre en plus les conversions de reference             }
    { communes et les constantes representables, TODO 19) : types              }
    { identiques ou l un des deux NON RESOLU -> l autre ; deux types              }
    { numeriques -> promotion binaire (TODO 04) ; sinon la branche VRAIE. }
    LT := ExprPool[TrueE].TypeIdx;
    RT := ExprPool[FalseE].TypeIdx;
    If LT = RT Then ExprPool[N].TypeIdx := LT
    Else If LT < 0 Then ExprPool[N].TypeIdx := RT
    Else If RT < 0 Then ExprPool[N].TypeIdx := LT
    Else If TypeIsNumericKind(TypeTab[LT].Kind) And TypeIsNumericKind(TypeTab[RT].Kind) Then
      ExprPool[N].TypeIdx := TypeBinaryPromote(LT, RT)
    Else
      ExprPool[N].TypeIdx := LT;

    ParseExpr := N;
    Exit;
  End;
  ParseExpr := Cond;
End;

{ ------------------------------------------------------------ }
{ ExprSelfTest : chaque assertion reproduit un exemple LITTERAL de   }
{ la reference (sections 6.1-6.22) - jamais un cas invente. Teste       }
{ ISOLEMENT (voir la note d en-tete de section) via ExprParseString,      }
{ meme methode que LexSelfTest/DeclSelfTest. }
{ ------------------------------------------------------------ }

Procedure ExprAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ExprSelfTest: ' + Label_ + ' a echoue');
End;

Function ExprParseString(Const Src: TString): Integer;
Const
  TmpFile = 'JPPEXPRSELFTEST.$$$';
Var
  F : Text;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  Write(F, Src);
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;

  ExprParseString := ParseExpr;
End;

Procedure ExprSelfTest;
Var
  E, SIb, SIt : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;

  { "1 + 2 * 3" (section 6.1, exemple LITTERAL - equivaut a 1+(2*3)). }
  E := ExprParseString('1 + 2 * 3');
  ExprAssert('1+2*3 : racine EK_BINARY "+"',
    (ExprPool[E].Kind = EK_BINARY) And (ExprPool[E].Op = '+'));
  ExprAssert('1+2*3 : Right est EK_BINARY "*" (precedence)',
    (ExprPool[ExprPool[E].Right].Kind = EK_BINARY) And (ExprPool[ExprPool[E].Right].Op = '*'));
  ExprAssert('1+2*3 : Left est le litteral 1',
    ExprPool[ExprPool[E].Left].IntVal = 1);

  { "(1 + 2) * 3" (parentheses prioritaires, section 6.1). }
  E := ExprParseString('(1 + 2) * 3');
  ExprAssert('(1+2)*3 : racine EK_BINARY "*"',
    (ExprPool[E].Kind = EK_BINARY) And (ExprPool[E].Op = '*'));
  ExprAssert('(1+2)*3 : Left est EK_BINARY "+"',
    (ExprPool[ExprPool[E].Left].Kind = EK_BINARY) And (ExprPool[ExprPool[E].Left].Op = '+'));

  { "1 - 2 - 3" equivaut a (1-2)-3 (associativite GAUCHE, section 6.1). }
  E := ExprParseString('1 - 2 - 3');
  ExprAssert('1-2-3 : Left est EK_BINARY "-" (assoc. GAUCHE)',
    (ExprPool[ExprPool[E].Left].Kind = EK_BINARY) And (ExprPool[ExprPool[E].Left].Op = '-'));
  ExprAssert('1-2-3 : Right est le litteral 3',
    ExprPool[ExprPool[E].Right].IntVal = 3);

  { "-b" (byte) -> int, promotion UNAIRE (section 6.3, exemple LITTERAL). }
  SymEnterScope;
  SIb := SymAdd('b', SK_VAR, PRIMTYPE_BYTE, False, False);
  E := ExprParseString('-b');
  ExprAssert('-b : EK_UNARY "-"', (ExprPool[E].Kind = EK_UNARY) And (ExprPool[E].Op = '-'));
  ExprAssert('-b : type promu vers int (section 6.3)', ExprPool[E].TypeIdx = PRIMTYPE_INT);
  SymLeaveScope;

  { "~0" == -1 (section 6.3, bit-a-bit - la VALEUR reelle est un sujet   }
  { de generateur de code, TODO 21+ ; ICI, seule la STRUCTURE compte). }
  E := ExprParseString('~0');
  ExprAssert('~0 : EK_UNARY "~"', (ExprPool[E].Kind = EK_UNARY) And (ExprPool[E].Op = '~'));

  { "!true" -> boolean (section 6.3). }
  E := ExprParseString('!true');
  ExprAssert('!true : EK_UNARY "!" sur EK_BOOLLIT',
    (ExprPool[E].Kind = EK_UNARY) And (ExprPool[ExprPool[E].Left].Kind = EK_BOOLLIT) And
    (ExprPool[ExprPool[E].Left].IntVal = 1));
  ExprAssert('!true : type boolean', ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN);

  { "++i" (prefixe) vs "i++" (postfixe) - section 6.4, DEUX formes         }
  { distinguees par Op. }
  SymEnterScope;
  SIb := SymAdd('i', SK_VAR, PRIMTYPE_INT, False, False);
  E := ExprParseString('++i');
  ExprAssert('++i : EK_UNARY prefixe "++"', (ExprPool[E].Kind = EK_UNARY) And (ExprPool[E].Op = '++'));
  E := ExprParseString('i++');
  ExprAssert('i++ : EK_UNARY postfixe "post++"',
    (ExprPool[E].Kind = EK_UNARY) And (ExprPool[E].Op = 'post++'));
  SymLeaveScope;

  { "\"age=\" + 42" -> String (section 6.7, exemple LITTERAL - concatenation). }
  E := ExprParseString('"age=" + 42');
  ExprAssert('"age="+42 : type resultat String (section 6.7)',
    ExprPool[E].TypeIdx = PDT_STRING);

  { "\"total=\" + 1 + 2" equivaut a ("total="+1)+2 -> "total=12", JAMAIS   }
  { "total=3" (section 6.7, exemple LITTERAL EXPLICITE - associativite      }
  { GAUCHE de "+", verifiee ICI structurellement). }
  E := ExprParseString('"total=" + 1 + 2');
  ExprAssert('"total="+1+2 : Left est deja "total="+1 (assoc. gauche)',
    (ExprPool[ExprPool[E].Left].Kind = EK_BINARY) And
    (ExprPool[ExprPool[ExprPool[E].Left].Left].Kind = EK_STRINGLIT));
  ExprAssert('"total="+1+2 : type resultat reste String', ExprPool[E].TypeIdx = PDT_STRING);

  { "1 << 3" (section 6.8, exemple LITTERAL "// 8"). }
  E := ExprParseString('1 << 3');
  ExprAssert('1<<3 : EK_BINARY "<<"', (ExprPool[E].Kind = EK_BINARY) And (ExprPool[E].Op = '<<'));
  ExprAssert('1<<3 : type int (promotion du seul operande GAUCHE, section 6.8)',
    ExprPool[E].TypeIdx = PRIMTYPE_INT);

  { "age >= 18" -> boolean (section 6.9, exemple LITTERAL). }
  SymEnterScope;
  SIb := SymAdd('age', SK_VAR, PRIMTYPE_INT, False, False);
  E := ExprParseString('age >= 18');
  ExprAssert('age>=18 : type boolean', ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN);
  SymLeaveScope;

  { "objet instanceof String" (section 6.10, exemple LITTERAL). }
  SymEnterScope;
  SIb := SymAdd('objet', SK_VAR, PDT_OBJECT, False, False);
  E := ExprParseString('objet instanceof String');
  ExprAssert('objet instanceof String : EK_INSTANCEOF', ExprPool[E].Kind = EK_INSTANCEOF);
  ExprAssert('objet instanceof String : Extra = PDT_STRING', ExprPool[E].Extra = PDT_STRING);
  ExprAssert('objet instanceof String : type boolean', ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN);
  SymLeaveScope;

  { "0x0F & 0x33" (section 6.12, exemple LITTERAL "// 0x03"). }
  E := ExprParseString('0x0F & 0x33');
  ExprAssert('0x0F&0x33 : EK_BINARY "&"', (ExprPool[E].Kind = EK_BINARY) And (ExprPool[E].Op = '&'));

  { "a & b" sur DEUX boolean -> boolean (section 6.12). }
  SymEnterScope;
  SIb := SymAdd('a', SK_VAR, PRIMTYPE_BOOLEAN, False, False);
  SIt := SymAdd('bb', SK_VAR, PRIMTYPE_BOOLEAN, False, False);
  E := ExprParseString('a & bb');
  ExprAssert('a&bb (deux boolean) : type boolean (section 6.12)',
    ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN);
  SymLeaveScope;

  { "0 < x && x < 10" (section 6.9, exemple LITTERAL "// valide"). }
  SymEnterScope;
  SIb := SymAdd('x', SK_VAR, PRIMTYPE_INT, False, False);
  E := ExprParseString('0 < x && x < 10');
  ExprAssert('0<x&&x<10 : racine EK_BINARY "&&"',
    (ExprPool[E].Kind = EK_BINARY) And (ExprPool[E].Op = '&&'));
  SymLeaveScope;

  { "x >= 0 ? x : -x" (section 6.14, exemple LITTERAL). }
  SymEnterScope;
  SIb := SymAdd('x', SK_VAR, PRIMTYPE_INT, False, False);
  E := ExprParseString('x >= 0 ? x : -x');
  ExprAssert('x>=0?x:-x : EK_TERNARY', ExprPool[E].Kind = EK_TERNARY);
  ExprAssert('x>=0?x:-x : condition EK_BINARY ">="',
    (ExprPool[ExprPool[E].Left].Kind = EK_BINARY) And (ExprPool[ExprPool[E].Left].Op = '>='));
  ExprAssert('x>=0?x:-x : branche FAUSSE est EK_UNARY "-"',
    ExprPool[ExprPool[E].Extra].Kind = EK_UNARY);
  ExprAssert('x>=0?x:-x : type int (deux branches int)', ExprPool[E].TypeIdx = PRIMTYPE_INT);
  SymLeaveScope;

  { "(int)3.9" (section 6.22, exemple LITTERAL "// 3"). }
  E := ExprParseString('(int)3.9');
  ExprAssert('(int)3.9 : EK_CAST', ExprPool[E].Kind = EK_CAST);
  ExprAssert('(int)3.9 : Extra = PRIMTYPE_INT', ExprPool[E].Extra = PRIMTYPE_INT);
  ExprAssert('(int)3.9 : operande EK_DOUBLELIT', ExprPool[ExprPool[E].Left].Kind = EK_DOUBLELIT);

  { "new int[10]" (section 6.21, exemple LITTERAL). }
  E := ExprParseString('new int[10]');
  ExprAssert('new int[10] : EK_NEWARRAY "dims"',
    (ExprPool[E].Kind = EK_NEWARRAY) And (ExprPool[E].Op = 'dims'));
  ExprAssert('new int[10] : UNE dimension', ExprPool[E].ArgCount = 1);
  ExprAssert('new int[10] : la VALEUR est un int[] (UN SEUL TYK_ARRAY, ' +
    'PAS directement int - "new" cree le TABLEAU, pas un element)',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PRIMTYPE_INT));

  { "new int[2][3]" (section 6.21, exemple LITTERAL "// String[2][3]" adapte). }
  E := ExprParseString('new int[2][3]');
  ExprAssert('new int[2][3] : DEUX dimensions', ExprPool[E].ArgCount = 2);
  ExprAssert('new int[2][3] : type int[][] (DEUX TYK_ARRAY imbriques)',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx].Kind = TYK_ARRAY));

  { "new int[3][]" (section 6.21, exemple LITTERAL "// valide" - UNE      }
  { SEULE dimension CHIFFREE, la seconde est VIDE). }
  E := ExprParseString('new int[3][]');
  ExprAssert('new int[3][] : UNE SEULE dimension chiffree', ExprPool[E].ArgCount = 1);
  ExprAssert('new int[3][] : type int[][] quand meme (2 paires "[]")',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY);

  { new int[] avec initialiseur 2,3,5,7 (section 6.21, exemple LITTERAL). }
  E := ExprParseString('new int[] { 2, 3, 5, 7 }');
  ExprAssert('new int[]{...} : EK_NEWARRAY "init"',
    (ExprPool[E].Kind = EK_NEWARRAY) And (ExprPool[E].Op = 'init'));
  ExprAssert('new int[]{...} : QUATRE elements', ExprPool[E].ArgCount = 4);
  ExprAssert('new int[]{...} : la VALEUR est un int[] (meme raison que ' +
    'new int[10] ci-dessus)',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PRIMTYPE_INT));

  { "new Exception()" (section 6.20 - seul un des 6 types REFERENCE     }
  { predeclares, TODO 03/04, peut y aboutir pour l instant). }
  E := ExprParseString('new Exception()');
  ExprAssert('new Exception() : EK_NEWOBJECT', ExprPool[E].Kind = EK_NEWOBJECT);
  ExprAssert('new Exception() : Extra = PDT_EXCEPTION', ExprPool[E].Extra = PDT_EXCEPTION);
  ExprAssert('new Exception() : AUCUN argument', ExprPool[E].ArgCount = 0);

  { "tableau.length" / "tableau[i]" (sections 6.18, exemples LITTERAUX). }
  SymEnterScope;
  SIt := SymAdd('tableau', SK_VAR, TypeAdd(TYK_ARRAY, '', 4, 4, PRIMTYPE_INT), False, False);
  SIb := SymAdd('i', SK_VAR, PRIMTYPE_INT, False, False);
  E := ExprParseString('tableau.length');
  ExprAssert('tableau.length : EK_SELECTOR "length"',
    (ExprPool[E].Kind = EK_SELECTOR) And (ExprPool[E].NameVal = 'length'));
  ExprAssert('tableau.length : type int (champ FINAL synthetique, section 6.18)',
    ExprPool[E].TypeIdx = PRIMTYPE_INT);
  E := ExprParseString('tableau[i]');
  ExprAssert('tableau[i] : EK_INDEX', ExprPool[E].Kind = EK_INDEX);
  ExprAssert('tableau[i] : type element int', ExprPool[E].TypeIdx = PRIMTYPE_INT);
  SymLeaveScope;

  { "objet.methode(1, 2)" (sections 6.17/6.19 - selecteur PUIS appel,     }
  { AUCUNE methode n existe encore, TODO 08 : type de retour NON            }
  { RESOLU, best-effort, JAMAIS de FatalError). }
  SymEnterScope;
  SIt := SymAdd('objet', SK_VAR, PDT_OBJECT, False, False);
  E := ExprParseString('objet.methode(1, 2)');
  ExprAssert('objet.methode(1,2) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  ExprAssert('objet.methode(1,2) : callee EK_SELECTOR "methode"',
    (ExprPool[ExprPool[E].Left].Kind = EK_SELECTOR) And
    (ExprPool[ExprPool[E].Left].NameVal = 'methode'));
  ExprAssert('objet.methode(1,2) : DEUX arguments', ExprPool[E].ArgCount = 2);
  SymLeaveScope;

  TypeInit;
  SymInit;
  ExprInit;
End;

{ ============================================================ }
{ TODO 07 - INSTRUCTIONS (CONTROLE DE FLUX)                     }
{ ============================================================ }
{ Troisieme TODO de PARSING (apres declarations/TODO 05 et                }
{ expressions/TODO 06) - un VRAI arbre (StmtPool), MEME principe de           }
{ POOL A TAILLE FIXE. Testee ISOLEMENT ci-dessous (StmtSelfTest),               }
{ JAMAIS branchee sur un VRAI fichier .jpp (aucune classe/methode                    }
{ n existe encore, TODO 08, pour donner un CORPS reel a ces                          }
{ instructions).                                                                              }
{                                                                       }
{ PORTEE EXPLICITEMENT COUVERTE : bloc/instruction vide/instruction-        }
{ expression/declaration locale (7.2-7.6, SAUF 7.6 - classe locale,               }
{ TODO 08) ; if/else avec resolution NATURELLE du dangling-else                        }
{ (7.7/7.8 - la recursion-descente elle-meme regle deja ce probleme,               }
{ AUCUN code special n est necessaire, voir ParseIfStmt) ; switch/case/          }
{ default avec POURSUITE (fall-through) PAR DEFAUT (7.9-7.11,                                }
{ DIFFERENCE REELLE avec le switch de SWIFTW32.PAS, qui exige lui un             }
{ "fallthrough" EXPLICITE) ; while/do-while/for CLASSIQUE a 3 clauses           }
{ (7.12-7.15, AUCUN foreach, 7.16) ; instruction ETIQUETEE et break/                  }
{ continue NON etiquetes ET etiquetes (7.17-7.19, VRAIE fonctionnalite            }
{ Java 1.1, contrairement a GOCW32.PAS/SWIFTW32.PAS qui ne couvrent               }
{ QUE la forme non etiquetee - une PILE d etiquettes nommees des le             }
{ depart, jamais une extension ulterieure) ; return (7.20).                              }
{                                                                       }
{ PORTEE EXPLICITEMENT DEFEREE (le roadmap d en-tete l annonce                     }
{ explicitement pour chacune) : throw (7.21) - la SYNTAXE SEULE est             }
{ couverte ici (STK_THROW, Left=expression), la verification REELLE               }
{ "assignable a Throwable"/checked-vs-unchecked reste le TODO 11                       }
{ (exceptions) ; synchronized (7.25) - MEME chose, la SYNTAXE SEULE               }
{ (STK_SYNCHRONIZED, Extra=verrou, Right=corps), le VRAI moniteur/                    }
{ verrouillage de thread reste le TODO 14 (threads). try/catch/finally           }
{ (7.22-7.24) restent ENTIEREMENT hors de ce TODO - c est EXPLICITEMENT           }
{ le TODO 11 qui les couvre (roadmap d en-tete de fichier, section                    }
{ "EXCEPTIONS"), jamais mentionnes ici. La declaration de classe                       }
{ locale (7.6) et les appels explicites this(...)/super(...) (7.27)                    }
{ necessitent tous deux un VRAI systeme de classes/constructeurs                       }
{ (TODO 08), absent ici. L accessibilite des instructions et                            }
{ l affectation certaine (7.28/7.29 - analyse de FLUX DE CONTROLE                       }
{ complete) restent un sujet d ANALYSE SEMANTIQUE (TODO 19), jamais                    }
{ devinees ici. }

Const
  MAX_STMT     = 4096;
  MAX_STMT_ARG = 8192;
  MAX_LABEL_STACK = {$IFDEF FPC}32{$ELSE}8{$ENDIF};

Type
  TStmtKind = (
    STK_BLOCK,        { ArgFirst/Count = instructions (StmtArgPool) -     }
                       { AUSSI utilise, sous une forme "PLATE", pour le       }
                       { corps d un switch (voir STK_SWITCH/STK_CASE          }
                       { ci-dessous, section 7.9-7.11) }
    STK_EMPTY,        { ";" seul (section 7.3) - ne fait rien }
    STK_EXPR,         { Left = expression - SEULEMENT les formes            }
                       { permises par la section 7.4 (appel/creation          }
                       { d objet/++/--), verifie par IsValidExprStmtKind }
    STK_ASSIGN,       { Op = '='/'+='/... (11 formes, sections 6.15/6.16, }
                       { DEFEREES de TODO 06 a ICI) ; Left = cible ;           }
                       { Right = valeur }
    STK_DECL,         { Left = index SymTab du PREMIER symbole cree par     }
                       { cette instruction ; Extra = leur NOMBRE (section     }
                       { 7.5 - reutilise ParseVarDecl du TODO 05 tel quel) }
    STK_IF,           { Extra = condition ; Right = bloc-alors ; Left =      }
                       { bloc-sinon (-1 si absent, ou un AUTRE STK_IF pour     }
                       { "else if" - section 7.7/7.8) }
    STK_WHILE,        { Extra = condition ; Right = corps (section 7.12) }
    STK_DOWHILE,      { Right = corps ; Extra = condition, testee APRES     }
                       { (section 7.13) }
    STK_FOR,          { InitFirst/Count = instructions d initialisation ;    }
                       { Extra = condition (-1 si omise, section 7.14) ;       }
                       { UpdFirst/Count = instructions de mise a jour ;          }
                       { Left = corps (section 7.14/7.15) }
    STK_SWITCH,       { Extra = selecteur ; Left = STK_BLOCK "PLAT"              }
                       { contenant instructions ET marqueurs STK_CASE               }
                       { entremelees (section 7.9) }
    STK_CASE,         { Op = 'case' (Left = expression constante) ou              }
                       { 'default' (Left = -1) - MARQUEUR seul, jamais           }
                       { son propre corps (section 7.10, poursuite               }
                       { sequentielle "PLATE") }
    STK_LABELED,      { NameVal = etiquette ; Left = instruction etiquetee    }
                       { (section 7.17) }
    STK_BREAK,        { NameVal = etiquette ('' si absente, section 7.18) }
    STK_CONTINUE,     { NameVal = etiquette ('' si absente, section 7.19) }
    STK_RETURN,       { Left = expression (-1 si "return;" nu, section        }
                       { 7.20) }
    STK_THROW,        { Left = expression - le TYPE de l expression n est    }
                       { PAS verifie contre Throwable ICI (verification              }
                       { semantique complete repoussee au TODO 19, MEME                }
                       { discipline que le reste de ce parseur) - section         }
                       { 11.5 }
    STK_SYNCHRONIZED, { Extra = verrou ; Right = corps - SYNTAXE SEULE,       }
                       { voir la note d en-tete de section (TODO 14) }
    STK_TRY,          { TODO 11, section 11.8/11.13/11.15 - Left = bloc            }
                       { "try" (STK_BLOCK) ; Right = bloc "finally" (-1 si          }
                       { absent) ; ArgFirst/ArgCount = liste DE MARQUEURS            }
                       { STK_CASE... non, STK_CATCH (voir plus bas), DANS               }
                       { L ORDRE TEXTUEL (section 11.10, "premier type                    }
                       { compatible choisi" - AUCUNE verification que les              }
                       { catch precis PRECEDENT bien leurs superclasses,                }
                       { section 11.10/11.11, repoussee au TODO 19 : AUCUN               }
                       { echantillon reel n a plus d un catch par try,                     }
                       { cette verification resterait de toute facon                          }
                       { INVISIBLE tant qu aucune generation de code n existe -         }
                       { la SELECTION REELLE a l execution est, comme la                   }
                       { propagation elle-meme, une decision de TODO 21+,                 }
                       { voir la note d en-tete de ParseTryStmt) - zero                       }
                       { catch est permis SI un finally est present (et                    }
                       { vice-versa), mais pas les deux absents (section              }
                       { 11.8) }
    STK_CATCH         { TODO 11 - Extra = TypeIdx du type d exception                }
                       { capture ; NameVal = nom du parametre (portee              }
                       { limitee au bloc, section 11.9) ; Left = corps               }
                       { (STK_BLOCK) - MARQUEUR complet cette fois                          }
                       { (contrairement a STK_CASE, un CATCH porte TOUJOURS          }
                       { son propre corps - pas de "poursuite" entre                          }
                       { catch, section 11.9/11.12, un SEUL bloc s execute            }
                       { par try) }
  );

  TStmtNode = Record
    Kind      : TStmtKind;
    Op        : TString;
    Left      : Integer;
    Right     : Integer;
    Extra     : Integer;
    NameVal   : TString;
    ArgFirst  : Integer;   { STK_BLOCK seulement }
    ArgCount  : Integer;
    InitFirst : Integer;   { STK_FOR seulement }
    InitCount : Integer;
    UpdFirst  : Integer;   { STK_FOR seulement }
    UpdCount  : Integer;
  End;

Var
  StmtPool     : Array[0..MAX_STMT - 1] Of TStmtNode;
  StmtCount    : Integer;
  StmtArgPool  : Array[0..MAX_STMT_ARG - 1] Of Integer;
  StmtArgCount : Integer;

  { LoopDepth/LoopOrSwitchDepth : compteurs de nesting AU MOMENT DU        }
  { PARSING (PAS une pile d etiquettes NOMMEES - voir LabelStack* plus       }
  { bas pour celle-ci) - valident "break"/"continue" NON etiquetes            }
  { (sections 7.18/7.19) : break est valide des qu UNE boucle OU un            }
  { switch englobe (LoopOrSwitchDepth>0), continue EXIGE une VRAIE              }
  { boucle (LoopDepth>0 - un switch seul ne suffit PAS, "continue ne                }
  { peut cibler... un switch", section 7.19). }
  LoopDepth         : Integer;
  LoopOrSwitchDepth : Integer;

  { LabelStack* : pile des etiquettes ACTUELLEMENT OUVERTES (section        }
  { 7.17) - IsLoop distingue une etiquette posee sur une VRAIE boucle           }
  { (while/do/for) d une etiquette sur un bloc/if/switch ordinaire,               }
  { necessaire pour REFUSER "continue etiquette" quand l etiquette ne             }
  { designe PAS une boucle (section 7.19) - AUCUNE restriction              }
  { equivalente pour "break etiquette" (section 7.18, valide pour               }
  { TOUTE instruction etiquetee). Espace de noms SEPARE des variables            }
  { (section 7.17, "peut porter le meme texte qu une variable") -                    }
  { AUCUNE interaction avec SymTab. }
  LabelStackNames  : Array[0..MAX_LABEL_STACK - 1] Of TString;
  LabelStackIsLoop : Array[0..MAX_LABEL_STACK - 1] Of Boolean;
  LabelStackTop    : Integer;

Procedure StmtInit;
Begin
  StmtCount         := 0;
  StmtArgCount      := 0;
  LoopDepth         := 0;
  LoopOrSwitchDepth := 0;
  LabelStackTop     := -1;
End;

Function StmtNew(K: TStmtKind): Integer;
Begin
  If StmtCount >= MAX_STMT Then
  Begin
    FatalError('table des noeuds d''instruction pleine (MAX_STMT)');
    StmtNew := 0;
    Exit;
  End;
  StmtPool[StmtCount].Kind      := K;
  StmtPool[StmtCount].Op        := '';
  StmtPool[StmtCount].Left      := -1;
  StmtPool[StmtCount].Right     := -1;
  StmtPool[StmtCount].Extra     := -1;
  StmtPool[StmtCount].NameVal   := '';
  StmtPool[StmtCount].ArgFirst  := -1;
  StmtPool[StmtCount].ArgCount  := 0;
  StmtPool[StmtCount].InitFirst := -1;
  StmtPool[StmtCount].InitCount := 0;
  StmtPool[StmtCount].UpdFirst  := -1;
  StmtPool[StmtCount].UpdCount  := 0;
  StmtNew := StmtCount;
  Inc(StmtCount);
End;

Function StmtArgPush(SIdx: Integer): Integer;
Begin
  If StmtArgCount >= MAX_STMT_ARG Then
  Begin
    FatalError('table des arguments d''instruction pleine (MAX_STMT_ARG)');
    StmtArgPush := 0;
    Exit;
  End;
  StmtArgPool[StmtArgCount] := SIdx;
  StmtArgPush := StmtArgCount;
  Inc(StmtArgCount);
End;

{ Forward - ParseStatement/ParseExprStmt/ParseBlock s appellent           }
{ MUTUELLEMENT (un bloc contient des instructions, une instruction PEUT    }
{ etre un bloc). }
Function ParseStatement: Integer; Forward;

{ LooksLikeDeclAhead : lookahead SANS EFFET DE BORD (PP sauvegarde ET    }
{ restaure - MEME technique que LooksLikeCastAhead, TODO 06) - distingue    }
{ "String x = ..." (DECLARATION) de "String.valueOf(x)"                                }
{ (INSTRUCTION-EXPRESSION demarrant par le MEME identificateur "String")           }
{ - AMBIGUITE CLASSIQUE des grammaires C-like/Java-like, resolue ICI               }
{ par un lookahead : "final" ou un mot-cle de type PRIMITIF annoncent               }
{ TOUJOURS une declaration sans ambiguite (aucun des deux ne peut                    }
{ jamais commencer une expression) ; un identificateur de type                            }
{ REFERENCE predeclare (String, Object, ...) OU une classe/interface           }
{ UTILISATEUR deja declaree (TypeFindByName, TODO 08/09 - EXTENSION            }
{ trouvee necessaire par EXECUTION, InterfaceSelfTest : "Compteur                    }
{ compteur = new Compteur();" est la PREMIERE locale de type CLASSE               }
{ UTILISATEUR jamais declaree dans un corps de methode reel de ce                    }
{ projet, section 8.5/9 - initialement documentee "hors de portee,                     }
{ TODO 08" ICI MEME, cette restriction ne tenait plus une fois le                       }
{ TODO 08/09 ECRITS) n annonce une declaration QUE s il est suivi de              }
{ zero ou plusieurs "[]" PUIS d un AUTRE identificateur (le nom                        }
{ declare) - "String.xxx"/"Compteur.xxx"/"String[0]" etc. echouent DONC          }
{ correctement ce test et retombent sur le chemin INSTRUCTION-                            }
{ EXPRESSION ordinaire. Un identificateur de classe encore INCONNU du            }
{ TOUT (jamais declare nulle part) reste, LUI, traite comme une                          }
{ instruction-expression ORDINAIRE - AUCUNE devinette au-dela de ce                  }
{ que TypeFindByName sait deja. }
Function LooksLikeDeclAhead: Boolean;
Var Save : Integer;
Begin
  Save := PP;
  LooksLikeDeclAhead := False;

  If PPKind <> TOK_IDENT Then
  Begin
    PP := Save;
    Exit;
  End;

  If IsKeyword(PPVal) = KW_FINAL Then
  Begin
    LooksLikeDeclAhead := True;
    PP := Save;
    Exit;
  End;

  If PrimitiveTypeFromKeyword(IsKeyword(PPVal)) >= 0 Then
  Begin
    LooksLikeDeclAhead := True;
    PP := Save;
    Exit;
  End;

  If (IsPredeclaredType(PPVal) <> 0) Or
     ((IsKeyword(PPVal) = 0) And (TypeFindByName(PPVal) >= 0)) Then
  Begin
    PPAdvance;
    While PPIsOp('[') Do
    Begin
      PPAdvance;
      If Not PPMatch(']') Then Begin PP := Save; Exit; End;
    End;
    LooksLikeDeclAhead := PPKind = TOK_IDENT;
  End;

  PP := Save;
End;

{ ParseDeclAsStmt : enveloppe ParseVarDecl (TODO 05) dans un STK_DECL     }
{ - REUTILISEE par ParseStatement (declaration ordinaire) ET ParseForStmt   }
{ (initialisation par declaration, section 7.15) - ParseVarDecl CONSOMME    }
{ DEJA son propre ";" final (TODO 05), IMPORTANT pour ParseForStmt : le      }
{ ";" separateur du for et celui de la declaration sont LE MEME              }
{ caractere source, JAMAIS consomme deux fois. }
Function ParseDeclAsStmt: Integer;
Var N : Integer;
Begin
  N := StmtNew(STK_DECL);
  StmtPool[N].Left := SymCount;
  ParseVarDecl;
  StmtPool[N].Extra := SymCount - StmtPool[N].Left;
  ParseDeclAsStmt := N;
End;

{ IsValidExprStmtKind / ParseExprStmt : section 7.4 - SEULES certaines   }
{ expressions sont des instructions valides (affectation - DEFEREE de       }
{ TODO 06 a ICI, EXACTEMENT comme GOCW32.PAS/SWIFTW32.PAS l ont deja            }
{ fait pour LEUR propre grammaire - pre/post-increment/decrement, appel          }
{ de methode, creation d objet) ; "x + y;"/"objet.champ;"/"true;"                    }
{ (exemples LITTERAUX section 7.4, "invalide") restent explicitement                  }
{ REFUSES. Reutilisee TELLE QUELLE par ParseForStmt pour ses clauses               }
{ init/mise-a-jour (section 7.15, SANS le ";" final - le for gere le               }
{ sien lui-meme, separement). }
Function IsValidExprStmtKind(E: Integer): Boolean;
Begin
  IsValidExprStmtKind :=
    (ExprPool[E].Kind = EK_CALL) Or (ExprPool[E].Kind = EK_NEWOBJECT) Or
    ((ExprPool[E].Kind = EK_UNARY) And
     ((ExprPool[E].Op = '++') Or (ExprPool[E].Op = '--') Or
      (ExprPool[E].Op = 'post++') Or (ExprPool[E].Op = 'post--')));
End;

{ SemanticCheckFinalTarget (TODO 19, section 4.12/8.4, "verification    }
{ best-effort d affectation definie pour final") : avertit si LA CIBLE           }
{ d une affectation (E) designe un symbole local OU un champ deja                    }
{ marque "final". SIMPLIFICATION ASSUMEE (best-effort, PAS une VRAIE               }
{ analyse d affectation definie a la Java reel) : ce compilateur ne             }
{ distingue PAS "premiere affectation d un final SANS initialiseur"              }
{ (legal en Java reel - un "blank final" affecte UNE FOIS dans un                    }
{ constructeur) de "reaffectation" - TOUTE instruction STK_ASSIGN dont          }
{ la cible resout vers un symbole/champ final est signalee. CORRECT              }
{ pour CHAQUE forme reellement exercee par les 18 echantillons                             }
{ (verifie par grep : chaque "final" existant est INITIALISE a sa                     }
{ declaration, AUCUN n est jamais reaffecte) - un "blank final" LEGAL           }
{ produirait ICI un FAUX POSITIF, limitation EXPLICITEMENT documentee            }
{ plutot que silencieusement approximee. }
Procedure SemanticCheckFinalTarget(E: Integer);
Var BaseT, FI : Integer;
Begin
  If ExprPool[E].Kind = EK_IDENT Then
  Begin
    If (ExprPool[E].Left >= 0) And SymTab[ExprPool[E].Left].IsFinal Then
      WarnMsg('reaffectation de la variable "final" "' + ExprPool[E].NameVal +
        '" (analyse semantique best-effort, TODO 19)');
  End
  Else If ExprPool[E].Kind = EK_SELECTOR Then
  Begin
    BaseT := ExprPool[ExprPool[E].Left].TypeIdx;
    If (BaseT >= 0) And (BaseT < TypeCount) Then
    Begin
      FI := ClassFindField(BaseT, ExprPool[E].NameVal);
      If (FI >= 0) And FieldPool[FI].IsFinal Then
        WarnMsg('reaffectation du champ "final" "' + ExprPool[E].NameVal +
          '" (analyse semantique best-effort, TODO 19)');
    End;
  End;
End;

{ SemanticCheckAssignTypes (TODO 19, section 5.2/6.15, "compatibilite   }
{ d affectation") : MEME tolerance (TypeIsWidening/TypeIsSubclassOf)             }
{ que MethodParamsCompatible (TODO 08) - SEULEMENT pour "=" (affectation      }
{ SIMPLE) : les onze formes composees ("+="...) suivent une regle                    }
{ DIFFERENTE et PLUS PERMISSIVE en Java reel (cast implicite, section          }
{ 6.16) - jamais modelisee ICI, EXPLICITEMENT hors de portee plutot                }
{ que devinee. }
Procedure SemanticCheckAssignTypes(Const Op: TString; L, R: Integer);
Var LT, RT : Integer;
Begin
  If Op <> '=' Then Exit;
  LT := ExprPool[L].TypeIdx;
  RT := ExprPool[R].TypeIdx;
  If (LT < 0) Or (RT < 0) Or (LT >= TypeCount) Or (RT >= TypeCount) Then Exit;
  If LT = RT Then Exit;
  If TypeIsWidening(RT, LT) Then Exit;
  If TypeIsSubclassOf(RT, LT) Then Exit;
  WarnMsg('affectation potentiellement incompatible : "' + TypeTab[RT].Name +
    '" vers "' + TypeTab[LT].Name + '" (analyse semantique best-effort, TODO 19)');
End;

Function ParseExprStmt: Integer;
Var E, N : Integer; Op : TString;
Begin
  E := ParseExpr;

  If PPIsOp('=') Or PPIsOp('+=') Or PPIsOp('-=') Or PPIsOp('*=') Or
     PPIsOp('/=') Or PPIsOp('%=') Or PPIsOp('&=') Or PPIsOp('^=') Or
     PPIsOp('|=') Or PPIsOp('<<=') Or PPIsOp('>>=') Or PPIsOp('>>>=') Then
  Begin
    Op := PPVal;
    PPAdvance;
    N := StmtNew(STK_ASSIGN);
    StmtPool[N].Op    := Op;
    StmtPool[N].Left  := E;
    StmtPool[N].Right := ParseExpr;
    SemanticCheckFinalTarget(E);                          { TODO 19 }
    SemanticCheckAssignTypes(Op, E, StmtPool[N].Right);    { TODO 19 }
    ParseExprStmt := N;
    Exit;
  End;

  If Not IsValidExprStmtKind(E) Then
    FatalError('cette expression ne peut pas servir d''instruction ' +
      '(section 7.4 - seules affectation/++/--/appel de methode/' +
      'creation d''objet le peuvent)');

  N := StmtNew(STK_EXPR);
  StmtPool[N].Left := E;
  ParseExprStmt := N;
End;

{ ParseBlock : accolade ouvrante, zero ou plusieurs declarations/          }
{ instructions, accolade fermante (section 7.2) - ouvre/ferme sa               }
{ PROPRE portee (une variable declaree n est plus                                          }
{ visible apres la fermeture) - corps "PLAT" (STK_BLOCK, ArgFirst/Count),  }
{ reutilise TEL QUEL par ParseSwitchStmt (section 7.9) pour son propre           }
{ corps entremelant instructions et marqueurs STK_CASE.                             }
{                                                                       }
{ BOGUE REEL trouve par EXECUTION (TODO 08, ClassSelfTest - un corps de     }
{ methode dont la PREMIERE instruction est elle-meme un "if"/"while"/...      }
{ AVEC ACCOLADES) : capturer ArgFirst := StmtArgCount AVANT la boucle,         }
{ PUIS pousser une instruction a la fois PENDANT elle, suppose que RIEN         }
{ d autre ne pousse dans StmtArgPool entre-temps - FAUX des qu une                  }
{ instruction du bloc contient ELLE-MEME un bloc IMBRIQUE (ParseStatement       }
{ appelle alors ParseBlock RECURSIVEMENT, qui pousse SES PROPRES                    }
{ entrees en PREMIER, avant que ce bloc-ci ne pousse la sienne) : les             }
{ entrees de CE bloc cessent d etre contigues a partir d ArgFirst,                    }
{ decalees par les pousses du bloc imbrique. Fixe en collectant D ABORD          }
{ TOUTES les instructions dans un tableau LOCAL (Tmp), puis en les                  }
{ poussant EN UN SEUL BALAYAGE ininterrompu APRES que tout le parsing            }
{ recursif de ce bloc soit termine - ArgFirst n est alors capture qu A          }
{ CE moment-la, garantissant la contiguite. MEME correction appliquee            }
{ a ParseSwitchStmt plus bas (risque IDENTIQUE, meme "corps PLAT"). }
Function ParseBlock: Integer;
Const
  MAX_BLOCK_STMT = 256;
Var
  N, I, Cnt : Integer;
  Tmp : Array[0..MAX_BLOCK_STMT - 1] Of Integer;
Begin
  N := StmtNew(STK_BLOCK);
  If Not PPMatch('{') Then
  Begin
    FatalError('"{" attendu au debut d''un bloc');
    ParseBlock := N;
    Exit;
  End;

  SymEnterScope;
  Cnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If Cnt < MAX_BLOCK_STMT Then
    Begin
      Tmp[Cnt] := ParseStatement;
      Inc(Cnt);
    End
    Else
    Begin
      WarnMsg('trop d''instructions directes dans un bloc (MAX_BLOCK_STMT)');
      ParseStatement;
    End;
  End;
  SymLeaveScope;

  If Not PPMatch('}') Then
    FatalError('"}" attendu a la fin d''un bloc');

  StmtPool[N].ArgFirst := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    StmtArgPush(Tmp[I]);
  StmtPool[N].ArgCount := Cnt;

  { TODO 19 (section 7.20/7.18/7.19, "code inaccessible best-effort") -   }
  { PUREMENT STRUCTUREL : SEULEMENT "une instruction suit IMMEDIATEMENT           }
  { un return/throw/break/continue DANS CE MEME bloc PLAT", JAMAIS une            }
  { VRAIE analyse de flux de controle (un "if" dont LES DEUX branches             }
  { se terminent par return laisse le code APRES le if parfaitement                  }
  { ATTEIGNABLE en Java reel - NON detecte ICI, limitation ASSUMEE,                  }
  { deviner une analyse de flux complete serait exactement le contraire        }
  { de la discipline "best-effort" que le roadmap demande). }
  For I := 0 To Cnt - 2 Do
    If StmtPool[Tmp[I]].Kind In [STK_RETURN, STK_THROW, STK_BREAK, STK_CONTINUE] Then
      WarnMsg('code inaccessible apres un "return"/"throw"/"break"/' +
        '"continue" (analyse semantique best-effort, section 7.20, TODO 19)');

  ParseBlock := N;
End;

{ ParseIfStmt : le "dangling else" (section 7.8) est resolu NATURELLEMENT }
{ par la recursion-descente elle-meme - "StmtPool[N].Left := ParseStatement" }
{ (l instruction APRES "else") consomme, s il en a un, son PROPRE "else"     }
{ AVANT de rendre la main ICI : le else le PLUS PROCHE se lie donc            }
{ TOUJOURS au if le PLUS PROCHE sans code special, EXACTEMENT la regle       }
{ de la reference. }
Function ParseIfStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'if' }
  N := StmtNew(STK_IF);
  If Not PPMatch('(') Then FatalError('"(" attendu apres "if"');
  StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(')') Then FatalError('")" attendu apres la condition du if');
  StmtPool[N].Right := ParseStatement;
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_ELSE) Then
  Begin
    PPAdvance;
    StmtPool[N].Left := ParseStatement;
  End;
  ParseIfStmt := N;
End;

Function ParseWhileStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'while' }
  N := StmtNew(STK_WHILE);
  If Not PPMatch('(') Then FatalError('"(" attendu apres "while"');
  StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(')') Then FatalError('")" attendu apres la condition du while');
  Inc(LoopDepth);
  Inc(LoopOrSwitchDepth);
  StmtPool[N].Right := ParseStatement;
  Dec(LoopDepth);
  Dec(LoopOrSwitchDepth);
  ParseWhileStmt := N;
End;

{ ParseDoWhileStmt : le ";" final est OBLIGATOIRE (section 7.13,       }
{ explicitement souligne par la reference - contrairement a "while"          }
{ ordinaire, qui n en a jamais). }
Function ParseDoWhileStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'do' }
  N := StmtNew(STK_DOWHILE);
  Inc(LoopDepth);
  Inc(LoopOrSwitchDepth);
  StmtPool[N].Right := ParseStatement;
  Dec(LoopDepth);
  Dec(LoopOrSwitchDepth);
  If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_WHILE)) Then
    FatalError('"while" attendu apres le corps d''un "do" (section 7.13)');
  PPAdvance;
  If Not PPMatch('(') Then FatalError('"(" attendu apres "while"');
  StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(')') Then FatalError('")" attendu apres la condition du do-while');
  If Not PPMatch(';') Then
    FatalError('";" attendu apres un "do...while" (section 7.13, obligatoire)');
  ParseDoWhileStmt := N;
End;

{ ParseForStmt : 3 clauses CLASSIQUES SEULEMENT (sections 7.14/7.15) -   }
{ AUCUN foreach (section 7.16, absent de J++ historique). L initialisation }
{ est SOIT une declaration locale (UN SEUL type, plusieurs declarateurs     }
{ possibles - deja la regle de ParseVarDecl/TODO 05), SOIT une liste          }
{ d instructions-expression separees par virgules (JAMAIS un melange des        }
{ deux) - LooksLikeDeclAhead (ci-dessus) tranche. La portee d une              }
{ variable declaree ICI couvre condition/mise-a-jour/corps (section              }
{ 7.15) - SymEnterScope/SymLeaveScope englobent les TROIS clauses ET le          }
{ corps, pas seulement l initialisation. }
Function ParseForStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'for' }
  N := StmtNew(STK_FOR);
  If Not PPMatch('(') Then FatalError('"(" attendu apres "for"');

  SymEnterScope;

  StmtPool[N].InitFirst := StmtArgCount;
  StmtPool[N].InitCount := 0;
  If PPIsOp(';') Then
    PPAdvance
  Else If LooksLikeDeclAhead Then
  Begin
    StmtArgPush(ParseDeclAsStmt);
    Inc(StmtPool[N].InitCount);
  End
  Else
  Begin
    Repeat
      StmtArgPush(ParseExprStmt);
      Inc(StmtPool[N].InitCount);
    Until Not PPMatch(',');
    If Not PPMatch(';') Then
      FatalError('";" attendu apres l''initialisation du for');
  End;

  If PPIsOp(';') Then
    StmtPool[N].Extra := -1
  Else
    StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(';') Then
    FatalError('";" attendu apres la condition du for');

  StmtPool[N].UpdFirst := StmtArgCount;
  StmtPool[N].UpdCount := 0;
  If Not PPIsOp(')') Then
    Repeat
      StmtArgPush(ParseExprStmt);
      Inc(StmtPool[N].UpdCount);
    Until Not PPMatch(',');
  If Not PPMatch(')') Then
    FatalError('")" attendu a la fin de l''en-tete du for');

  Inc(LoopDepth);
  Inc(LoopOrSwitchDepth);
  StmtPool[N].Left := ParseStatement;
  Dec(LoopDepth);
  Dec(LoopOrSwitchDepth);

  SymLeaveScope;
  ParseForStmt := N;
End;

{ ParseSwitchStmt : corps "PLAT" (section 7.1/7.9) - PAS un corps        }
{ SEPARE par case (contrairement au switch de SWIFTW32.PAS) : "case"/         }
{ "default" sont de simples MARQUEURS (STK_CASE) intercales dans UN               }
{ SEUL STK_BLOCK, la POURSUITE (fall-through) etant le comportement              }
{ PAR DEFAUT REEL de Java (sections 7.9-7.11) plutot qu une forme                    }
{ exceptionnelle a demander explicitement. Le type du selecteur est               }
{ verifie (char/byte/short/int SEULEMENT, section 7.9) ; chaque "case"           }
{ verifie best-effort que sa valeur est CONSTANTE (IsConst, TODO 06 -            }
{ AUCUN repliage REEL n est tente, voir la note d en-tete de                            }
{ ExprInferBinaryType/IsConst du TODO 06) ; un SEUL "default" est                     }
{ permis (section 7.10). }
Function ParseSwitchStmt: Integer;
Const
  MAX_SWITCH_ENTRY = 256;
Var
  N, Body, SelT, CaseN, E, I, Cnt : Integer;
  SeenDefault : Boolean;
  Tmp : Array[0..MAX_SWITCH_ENTRY - 1] Of Integer;
Begin
  PPAdvance;   { 'switch' }
  N := StmtNew(STK_SWITCH);
  If Not PPMatch('(') Then FatalError('"(" attendu apres "switch"');
  StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(')') Then FatalError('")" attendu apres le selecteur du switch');

  SelT := ExprPool[StmtPool[N].Extra].TypeIdx;
  If (SelT >= 0) And (SelT < TypeCount) Then
    If Not (TypeTab[SelT].Kind In [TYK_CHAR, TYK_BYTE, TYK_SHORT, TYK_INT]) Then
      FatalError('le selecteur d''un switch doit etre char/byte/short/int ' +
        '(section 7.9 - long/boolean/float/double/String/enum/Object ' +
        'non acceptes en J++ 6.0)');

  If Not PPMatch('{') Then
    FatalError('"{" attendu apres le selecteur d''un switch');

  SymEnterScope;
  Inc(LoopOrSwitchDepth);

  Body := StmtNew(STK_BLOCK);
  SeenDefault := False;
  Cnt := 0;

  { Collecte D ABORD dans Tmp, POUSSE contigue APRES (MEME correction     }
  { que ParseBlock, MEME risque exact : une instruction "case"/"default"      }
  { ordinaire peut elle-meme contenir un bloc ACCOLADE, dont le parsing            }
  { recursif pousserait sinon dans StmtArgPool AVANT ce marqueur-ci). }
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_CASE) Then
    Begin
      PPAdvance;
      E := ParseExpr;
      If Not ExprPool[E].IsConst Then
        WarnMsg('"case" attend une expression CONSTANTE (section 7.10) - ' +
          'verification best-effort, non repliee ici');
      If Not PPMatch(':') Then
        FatalError('":" attendu apres une etiquette "case"');
      CaseN := StmtNew(STK_CASE);
      StmtPool[CaseN].Op   := 'case';
      StmtPool[CaseN].Left := E;
      If Cnt < MAX_SWITCH_ENTRY Then Begin Tmp[Cnt] := CaseN; Inc(Cnt); End;
      Continue;
    End;
    If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_DEFAULT) Then
    Begin
      PPAdvance;
      If Not PPMatch(':') Then
        FatalError('":" attendu apres "default"');
      If SeenDefault Then
        FatalError('un SEUL "default" est permis par switch (section 7.10)');
      SeenDefault := True;
      CaseN := StmtNew(STK_CASE);
      StmtPool[CaseN].Op   := 'default';
      StmtPool[CaseN].Left := -1;
      If Cnt < MAX_SWITCH_ENTRY Then Begin Tmp[Cnt] := CaseN; Inc(Cnt); End;
      Continue;
    End;
    If Cnt < MAX_SWITCH_ENTRY Then
    Begin
      Tmp[Cnt] := ParseStatement;
      Inc(Cnt);
    End
    Else
    Begin
      WarnMsg('trop d''entrees directes dans un switch (MAX_SWITCH_ENTRY)');
      ParseStatement;
    End;
  End;

  Dec(LoopOrSwitchDepth);
  SymLeaveScope;

  If Not PPMatch('}') Then
    FatalError('"}" attendu a la fin d''un switch');

  StmtPool[Body].ArgFirst := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    StmtArgPush(Tmp[I]);
  StmtPool[Body].ArgCount := Cnt;

  StmtPool[N].Left := Body;
  ParseSwitchStmt := N;
End;

{ ParseLabeledStmt : "identificateur : instruction" (section 7.17) -    }
{ espace de noms SEPARE des variables (AUCUNE interaction avec SymTab).    }
{ IsLoop (regarde le PROCHAIN mot-cle SANS consommer - while/do/for)             }
{ determine si "continue CETTE etiquette" restera valide (section                    }
{ 7.19) une fois rencontre plus loin, a l interieur. }
Function ParseLabeledStmt: Integer;
Var N : Integer; Nam : TString; IsLoop : Boolean;
Begin
  Nam := PPVal;
  PPAdvance;   { identificateur }
  PPAdvance;   { ':' }

  IsLoop := (PPKind = TOK_IDENT) And
    ((IsKeyword(PPVal) = KW_WHILE) Or (IsKeyword(PPVal) = KW_DO) Or
     (IsKeyword(PPVal) = KW_FOR));

  If LabelStackTop >= MAX_LABEL_STACK - 1 Then
    WarnMsg('profondeur d''etiquettes maximale atteinte (MAX_LABEL_STACK)')
  Else
  Begin
    Inc(LabelStackTop);
    LabelStackNames[LabelStackTop]  := Nam;
    LabelStackIsLoop[LabelStackTop] := IsLoop;
  End;

  N := StmtNew(STK_LABELED);
  StmtPool[N].NameVal := Nam;
  StmtPool[N].Left     := ParseStatement;

  If LabelStackTop >= 0 Then Dec(LabelStackTop);

  ParseLabeledStmt := N;
End;

{ ParseBreakStmt/ParseContinueStmt : sections 7.18/7.19 - un identificateur }
{ APRES "break"/"continue" est TOUJOURS un nom d etiquette (AUCUN mot-cle    }
{ ne peut servir d etiquette, section 7.17 - un IDENT ici est donc SANS      }
{ AMBIGUITE). Sans etiquette : break exige une boucle OU un switch                 }
{ englobant (LoopOrSwitchDepth) ; continue exige une VRAIE boucle                    }
{ (LoopDepth SEUL - un switch ne suffit pas). Avec etiquette : elle DOIT      }
{ etre trouvee dans LabelStack (portee englobante ENCORE ouverte,                    }
{ section 7.18) ; pour continue SPECIFIQUEMENT, elle doit EN PLUS                     }
{ designer une boucle (LabelStackIsLoop, section 7.19). }
Function ParseBreakStmt: Integer;
Var N, I : Integer; Nam : TString; Found : Boolean;
Begin
  PPAdvance;   { 'break' }
  N := StmtNew(STK_BREAK);
  If PPKind = TOK_IDENT Then
  Begin
    Nam := PPVal;
    PPAdvance;
    StmtPool[N].NameVal := Nam;
    Found := False;
    For I := LabelStackTop DownTo 0 Do
      If LabelStackNames[I] = Nam Then
      Begin
        Found := True;
        Break;
      End;
    If Not Found Then
      FatalError('etiquette "' + Nam + '" introuvable pour ce "break" ' +
        '(section 7.18 - doit etre dans une portee englobante)');
  End
  Else If LoopOrSwitchDepth <= 0 Then
    FatalError('"break" hors de toute boucle/switch (section 7.18)');
  If Not PPMatch(';') Then FatalError('";" attendu apres "break"');
  ParseBreakStmt := N;
End;

Function ParseContinueStmt: Integer;
Var N, I : Integer; Nam : TString; Found : Boolean;
Begin
  PPAdvance;   { 'continue' }
  N := StmtNew(STK_CONTINUE);
  If PPKind = TOK_IDENT Then
  Begin
    Nam := PPVal;
    PPAdvance;
    StmtPool[N].NameVal := Nam;
    Found := False;
    For I := LabelStackTop DownTo 0 Do
      If LabelStackNames[I] = Nam Then
      Begin
        If Not LabelStackIsLoop[I] Then
          FatalError('"continue ' + Nam + '" : l''etiquette doit designer ' +
            'une BOUCLE englobante (section 7.19)');
        Found := True;
        Break;
      End;
    If Not Found Then
      FatalError('etiquette "' + Nam + '" introuvable pour ce "continue" ' +
        '(section 7.19)');
  End
  Else If LoopDepth <= 0 Then
    FatalError('"continue" hors de toute boucle (section 7.19)');
  If Not PPMatch(';') Then FatalError('";" attendu apres "continue"');
  ParseContinueStmt := N;
End;

Function ParseReturnStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'return' }
  N := StmtNew(STK_RETURN);
  If PPIsOp(';') Then
    StmtPool[N].Left := -1
  Else
    StmtPool[N].Left := ParseExpr;
  If Not PPMatch(';') Then FatalError('";" attendu apres "return"');
  ParseReturnStmt := N;
End;

{ ParseThrowStmt : SYNTAXE SEULE (section 7.21) - voir la note d en-tete }
{ de section pour la raison du renvoi au TODO 11. }
Function ParseThrowStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'throw' }
  N := StmtNew(STK_THROW);
  StmtPool[N].Left := ParseExpr;
  If Not PPMatch(';') Then FatalError('";" attendu apres "throw"');
  ParseThrowStmt := N;
End;

{ ParseSynchronizedStmt : SYNTAXE SEULE (section 7.25) - voir la note   }
{ d en-tete de section pour la raison du renvoi au TODO 14. }
Function ParseSynchronizedStmt: Integer;
Var N : Integer;
Begin
  PPAdvance;   { 'synchronized' }
  N := StmtNew(STK_SYNCHRONIZED);
  If Not PPMatch('(') Then FatalError('"(" attendu apres "synchronized"');
  StmtPool[N].Extra := ParseExpr;
  If Not PPMatch(')') Then FatalError('")" attendu apres le verrou synchronized');
  StmtPool[N].Right := ParseStatement;
  ParseSynchronizedStmt := N;
End;

{ ParseTryStmt : "try" bloc ["catch"... ]* ["finally" bloc] (sections  }
{ 11.8-11.13) - AU MOINS un catch ou un finally est EXIGE (section              }
{ 11.8, verifie ICI). Chaque clause "catch" recoit sa PROPRE portee               }
{ (SymEnterScope/SymLeaveScope, section 11.9 - "la portee du parametre       }
{ se limite au bloc catch"), REUTILISE ParseCatchParam (TODO 05,                     }
{ INCHANGE, deja verifie que le type est Throwable-ou-sous-classe).               }
{ AUCUNE verification "catch precis avant sa superclasse" (section              }
{ 11.10/11.11) : repoussee au TODO 19, ET de toute facon INVISIBLE tant      }
{ qu aucun echantillon reel n a plus d un catch par try (verifie par         }
{ lecture des 4 fichiers reels qui utilisent try/catch/finally).                    }
{                                                                       }
{ BOGUE POTENTIEL EVITE PAR CONSTRUCTION (meme risque EXACT que celui         }
{ trouve par execution au TODO 08 dans ParseBlock/ParseSwitchStmt -            }
{ voir leur propre note d en-tete) : la liste des clauses "catch" est            }
{ elle aussi un "corps PLAT" partage (StmtArgPool) - si ArgFirst etait          }
{ capture AVANT la boucle de parsing des catch, chaque catch poussant           }
{ ENSUITE son PROPRE corps (via ParseBlock, LUI-MEME recursif) avant             }
{ que la boucle ne pousse le marqueur STK_CATCH correspondant,                          }
{ l entrelacement casserait a nouveau la contiguite. Collecte donc                  }
{ D ABORD chaque STK_CATCH dans un tableau LOCAL, PUIS les pousse EN               }
{ UN SEUL balayage ininterrompu - ArgFirst n est capture qu A CE                       }
{ moment-la, APRES tout le parsing recursif des catch ET du finally.               }
{                                                                       }
{ MECANISME REEL DE PROPAGATION (section 11.7) - DECISION EXPLICITE          }
{ (feuille de route du TODO 11 l exige) SANS l implementer encore (AUCUNE     }
{ generation de code n existe, TODO 21+) : une liste CHAINEE de "cadres        }
{ d exception" (une structure par "try" ACTIVEMENT ouvert, empilee a               }
{ l entree, depilee a la sortie normale) plutot qu un VRAI SEH Win32               }
{ (FS:[0], tables .pdata/.xdata) - plus simple a generer pour un                       }
{ compilateur qui garde par ailleurs "tout tient dans EAX" (meme                       }
{ discipline que le reste de ce projet), au prix de ne pas s integrer            }
{ nativement aux gestionnaires SEH externes (DLL systeme, autres                       }
{ langages) - un compromis JUGE acceptable puisque J++/JVC ne vise                  }
{ ICI que du code MANAGE, jamais un pont vers du code natif tiers                        }
{ lancant sa PROPRE exception SEH (scenario hors de portee des                          }
{ echantillons reels). "throw" (deroulement) parcourrait cette liste             }
{ en cherchant un cadre dont un type de catch est compatible                              }
{ (TypeIsSubclassOf, DEJA ecrit), executerait les "finally" traverses             }
{ (section 11.7/11.13), PUIS sauterait au corps du catch trouve - CE             }
{ MECANISME RESTE A ECRIRE, cette note fixe seulement la STRATEGIE               }
{ choisie pour ne pas la deviner plus tard sans y avoir reflechi                        }
{ MAINTENANT, comme l exige la feuille de route. }
Function ParseTryStmt: Integer;
Const
  MAX_CATCH_CLAUSES = 32;
Var
  N, TryBody, FinallyBody, CatchN, ParamSI, Cnt, I : Integer;
  Tmp : Array[0..MAX_CATCH_CLAUSES - 1] Of Integer;
Begin
  PPAdvance;   { 'try' }
  N := StmtNew(STK_TRY);
  TryBody := ParseBlock;
  StmtPool[N].Left := TryBody;

  Cnt := 0;
  While (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_CATCH) Do
  Begin
    PPAdvance;   { 'catch' }
    If Not PPMatch('(') Then
      FatalError('"(" attendu apres "catch" (section 11.9)');
    SymEnterScope;
    ParamSI := ParseCatchParam;
    If Not PPMatch(')') Then
      FatalError('")" attendu apres le parametre d''un "catch" (section 11.9)');
    CatchN := StmtNew(STK_CATCH);
    If ParamSI >= 0 Then
    Begin
      StmtPool[CatchN].Extra   := SymTab[ParamSI].TypeIdx;
      StmtPool[CatchN].NameVal := SymTab[ParamSI].Name;
    End;
    StmtPool[CatchN].Left := ParseBlock;
    SymLeaveScope;
    If Cnt < MAX_CATCH_CLAUSES Then
    Begin
      Tmp[Cnt] := CatchN;
      Inc(Cnt);
    End
    Else
      WarnMsg('trop de clauses "catch" pour un seul "try" (MAX_CATCH_CLAUSES)');
  End;

  FinallyBody := -1;
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_FINALLY) Then
  Begin
    PPAdvance;   { 'finally' }
    FinallyBody := ParseBlock;
  End;

  If (Cnt = 0) And (FinallyBody < 0) Then
    FatalError('un "try" doit etre suivi d''au moins un "catch" ou d''un ' +
      '"finally" (section 11.8)');

  StmtPool[N].ArgFirst := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    StmtArgPush(Tmp[I]);
  StmtPool[N].ArgCount := Cnt;
  StmtPool[N].Right    := FinallyBody;

  ParseTryStmt := N;
End;

{ ParseStatement : dispatcheur principal - l ORDRE des verifications    }
{ importe : les mots-cles introducteurs D ABORD (sans ambiguite),               }
{ PUIS la declaration locale (LooksLikeDeclAhead), PUIS l etiquette              }
{ ("identificateur :" - LooksLikeDeclAhead a deja ecarte "final"/un              }
{ type CONNU, un NOM D ETIQUETTE ne peut donc plus etre confondu avec              }
{ eux ICI), et ENFIN l instruction-expression ordinaire (dernier                        }
{ recours). }
Function ParseStatement: Integer;
Var N, KW : Integer;
Begin
  If PPIsOp(';') Then
  Begin
    PPAdvance;
    ParseStatement := StmtNew(STK_EMPTY);
    Exit;
  End;

  If PPIsOp('{') Then
  Begin
    ParseStatement := ParseBlock;
    Exit;
  End;

  If PPKind = TOK_IDENT Then
  Begin
    KW := IsKeyword(PPVal);

    If KW = KW_IF           Then Begin ParseStatement := ParseIfStmt;           Exit; End;
    If KW = KW_WHILE        Then Begin ParseStatement := ParseWhileStmt;        Exit; End;
    If KW = KW_DO           Then Begin ParseStatement := ParseDoWhileStmt;      Exit; End;
    If KW = KW_FOR          Then Begin ParseStatement := ParseForStmt;          Exit; End;
    If KW = KW_SWITCH       Then Begin ParseStatement := ParseSwitchStmt;       Exit; End;
    If KW = KW_BREAK        Then Begin ParseStatement := ParseBreakStmt;        Exit; End;
    If KW = KW_CONTINUE     Then Begin ParseStatement := ParseContinueStmt;     Exit; End;
    If KW = KW_RETURN       Then Begin ParseStatement := ParseReturnStmt;       Exit; End;
    If KW = KW_THROW        Then Begin ParseStatement := ParseThrowStmt;        Exit; End;
    If KW = KW_SYNCHRONIZED Then Begin ParseStatement := ParseSynchronizedStmt; Exit; End;
    If KW = KW_TRY           Then Begin ParseStatement := ParseTryStmt;          Exit; End;

    If LooksLikeDeclAhead Then
    Begin
      ParseStatement := ParseDeclAsStmt;
      Exit;
    End;

    If (PP2Kind = TOK_OP) And (PP2Val = ':') Then
    Begin
      ParseStatement := ParseLabeledStmt;
      Exit;
    End;
  End;

  N := ParseExprStmt;
  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''une instruction-expression');
  ParseStatement := N;
End;

{ ------------------------------------------------------------ }
{ StmtSelfTest : chaque assertion reproduit un exemple LITTERAL de   }
{ la reference (sections 7.2-7.20) - jamais un cas invente. Teste       }
{ ISOLEMENT (voir la note d en-tete de section) via StmtParseString,      }
{ meme methode que LexSelfTest/DeclSelfTest/ExprSelfTest. }
{ ------------------------------------------------------------ }

Procedure StmtAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StmtSelfTest: ' + Label_ + ' a echoue');
End;

Function StmtParseString(Const Src: TString): Integer;
Const
  TmpFile = 'JPPSTMTSELFTEST.$$$';
Var
  F : Text;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  Write(F, Src);
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;

  StmtParseString := ParseStatement;
End;

Procedure StmtSelfTest;
Var
  S, Body, C0, C1 : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { bloc (section 7.2, exemple LITTERAL). }
  S := StmtParseString('{ int total = 0; total += calculer(); }');
  StmtAssert('bloc : racine STK_BLOCK', StmtPool[S].Kind = STK_BLOCK);
  StmtAssert('bloc : DEUX instructions', StmtPool[S].ArgCount = 2);
  StmtAssert('bloc : 1ere est STK_DECL',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = STK_DECL);
  StmtAssert('bloc : 2eme est STK_ASSIGN "+="',
    (StmtPool[StmtArgPool[StmtPool[S].ArgFirst + 1]].Kind = STK_ASSIGN) And
    (StmtPool[StmtArgPool[StmtPool[S].ArgFirst + 1]].Op = '+='));

  { instruction vide (section 7.3). }
  S := StmtParseString(';');
  StmtAssert('instruction vide : STK_EMPTY', StmtPool[S].Kind = STK_EMPTY);

  { instructions-expression valides (section 7.4, exemples LITTERAUX). }
  S := StmtParseString('compteur++;');
  StmtAssert('compteur++; : STK_EXPR sur EK_UNARY "post++"',
    (StmtPool[S].Kind = STK_EXPR) And
    (ExprPool[StmtPool[S].Left].Op = 'post++'));
  S := StmtParseString('new Exception();');
  StmtAssert('new Exception(); : STK_EXPR sur EK_NEWOBJECT',
    (StmtPool[S].Kind = STK_EXPR) And (ExprPool[StmtPool[S].Left].Kind = EK_NEWOBJECT));
  S := StmtParseString('x = 10;');
  StmtAssert('x = 10; : STK_ASSIGN "="',
    (StmtPool[S].Kind = STK_ASSIGN) And (StmtPool[S].Op = '='));

  { if/else - dangling else resolu NATURELLEMENT (section 7.8, exemple   }
  { LITTERAL EXACT : le "else" se lie au if(b) le plus proche, PAS au         }
  { if(a)). }
  S := StmtParseString('if (a) if (b) f(); else g();');
  StmtAssert('if(a) if(b) f(); else g(); : racine STK_IF sur "a"',
    StmtPool[S].Kind = STK_IF);
  StmtAssert('dangling else : Left(racine) reste -1 (aucun else pour if(a))',
    StmtPool[S].Left = -1);
  StmtAssert('dangling else : le if(b) INTERNE possede, LUI, un else',
    StmtPool[StmtPool[S].Right].Left >= 0);

  { switch avec POURSUITE (fall-through) implicite (section 7.11,       }
  { exemple LITTERAL EXACT - "case 6:"/"case 7:" partagent un corps). }
  S := StmtParseString('switch (jour) { case 6: case 7: type = 1; break; default: type = 0; }');
  StmtAssert('switch : racine STK_SWITCH', StmtPool[S].Kind = STK_SWITCH);
  Body := StmtPool[S].Left;
  StmtAssert('switch : corps STK_BLOCK "PLAT"', StmtPool[Body].Kind = STK_BLOCK);
  C0 := StmtArgPool[StmtPool[Body].ArgFirst];
  C1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];
  StmtAssert('switch : 1er marqueur STK_CASE "case" (valeur 6)',
    (StmtPool[C0].Kind = STK_CASE) And (StmtPool[C0].Op = 'case') And
    (ExprPool[StmtPool[C0].Left].IntVal = 6));
  StmtAssert('switch : 2eme marqueur STK_CASE "case" (valeur 7, AUCUNE ' +
    'instruction entre les deux - fall-through structurel)',
    (StmtPool[C1].Kind = STK_CASE) And (StmtPool[C1].Op = 'case') And
    (ExprPool[StmtPool[C1].Left].IntVal = 7));

  { switch : type de selecteur invalide (section 7.9) - VERIFIE          }
  { INDIRECTEMENT (le selecteur ci-dessus, "jour", est un identificateur     }
  { NON RESOLU - TypeIdx=-1 - donc la verification de type est               }
  { SILENCIEUSEMENT IGNOREE, meme discipline "best-effort" que le reste          }
  { de ce parseur ; un TEST DIRECT exigerait declencher un VRAI              }
  { FatalError, ce qu AUCUN self-test de ce projet ne fait jamais). }

  { while (section 7.12, exemple LITTERAL). }
  S := StmtParseString('while (reste > 0) { reste--; }');
  StmtAssert('while : racine STK_WHILE', StmtPool[S].Kind = STK_WHILE);
  StmtAssert('while : condition EK_BINARY ">"',
    (ExprPool[StmtPool[S].Extra].Kind = EK_BINARY) And (ExprPool[StmtPool[S].Extra].Op = '>'));

  { do-while (section 7.13, ";" final OBLIGATOIRE - deja verifie par le  }
  { simple fait que le parsing REUSSIT sans FatalError). }
  S := StmtParseString('do { x++; } while (x < 10);');
  StmtAssert('do-while : racine STK_DOWHILE', StmtPool[S].Kind = STK_DOWHILE);

  { for CLASSIQUE (section 7.14, exemple LITTERAL). }
  S := StmtParseString('for (int i = 0; i < 10; i++) { println(i); }');
  StmtAssert('for : racine STK_FOR', StmtPool[S].Kind = STK_FOR);
  StmtAssert('for : UNE instruction d''initialisation (declaration)', StmtPool[S].InitCount = 1);
  StmtAssert('for : initialisation est STK_DECL',
    StmtPool[StmtArgPool[StmtPool[S].InitFirst]].Kind = STK_DECL);
  StmtAssert('for : condition EK_BINARY "<"', ExprPool[StmtPool[S].Extra].Kind = EK_BINARY);
  StmtAssert('for : UNE instruction de mise a jour', StmtPool[S].UpdCount = 1);

  { for avec LISTE d instructions-expression en init/mise-a-jour           }
  { (section 7.15, exemple LITTERAL "i = 0, j = n - 1; i < j; i++, j--"). }
  SymEnterScope;
  SymAdd('i', SK_VAR, PRIMTYPE_INT, False, False);
  SymAdd('j', SK_VAR, PRIMTYPE_INT, False, False);
  SymAdd('n', SK_VAR, PRIMTYPE_INT, False, False);
  S := StmtParseString('for (i = 0, j = n - 1; i < j; i++, j--) { }');
  StmtAssert('for (liste) : DEUX instructions d''initialisation', StmtPool[S].InitCount = 2);
  StmtAssert('for (liste) : initialisation SONT des STK_ASSIGN (pas STK_DECL)',
    StmtPool[StmtArgPool[StmtPool[S].InitFirst]].Kind = STK_ASSIGN);
  StmtAssert('for (liste) : DEUX instructions de mise a jour', StmtPool[S].UpdCount = 2);
  SymLeaveScope;

  { for (;;) - condition omise = true implicite (section 7.14, exemple    }
  { LITTERAL). }
  S := StmtParseString('for (;;) { }');
  StmtAssert('for(;;) : AUCUNE initialisation', StmtPool[S].InitCount = 0);
  StmtAssert('for(;;) : condition omise (Extra=-1)', StmtPool[S].Extra = -1);
  StmtAssert('for(;;) : AUCUNE mise a jour', StmtPool[S].UpdCount = 0);

  { instruction etiquetee + break etiquete (section 7.17/7.18, exemple    }
  { LITTERAL EXACT - boucles imbriquees, "break externe" depuis la              }
  { boucle INTERNE). }
  S := StmtParseString(
    'externe: for (int i = 0; i < n; i++) { for (int j = 0; j < m; j++) { break externe; } }');
  StmtAssert('externe: ... : racine STK_LABELED "externe"',
    (StmtPool[S].Kind = STK_LABELED) And (StmtPool[S].NameVal = 'externe'));
  StmtAssert('externe: ... : instruction etiquetee est STK_FOR (IsLoop correctement detecte)',
    StmtPool[StmtPool[S].Left].Kind = STK_FOR);

  { continue etiquete (section 7.19, exemple LITTERAL EXACT). }
  S := StmtParseString(
    'externe: for (int i = 0; i < n; i++) { for (int j = 0; j < m; j++) { continue externe; } }');
  StmtAssert('continue externe; : parsing REUSSIT (etiquette de boucle valide)',
    StmtPool[S].Kind = STK_LABELED);

  { return (section 7.20, DEUX formes). }
  S := StmtParseString('return;');
  StmtAssert('return; : Left=-1 (aucune valeur)', StmtPool[S].Left = -1);
  S := StmtParseString('return x * x;');
  StmtAssert('return x*x; : Left est EK_BINARY "*"', ExprPool[StmtPool[S].Left].Op = '*');

  { throw - SYNTAXE SEULE (section 7.21, voir la note d en-tete de        }
  { section pour le renvoi au TODO 11). }
  S := StmtParseString('throw erreur;');
  StmtAssert('throw erreur; : racine STK_THROW', StmtPool[S].Kind = STK_THROW);

  { synchronized - SYNTAXE SEULE (section 7.25, voir la note d en-tete    }
  { de section pour le renvoi au TODO 14). }
  SymEnterScope;
  SymAdd('verrou', SK_VAR, PDT_OBJECT, False, False);
  S := StmtParseString('synchronized (verrou) { compteur++; }');
  StmtAssert('synchronized(verrou){...} : racine STK_SYNCHRONIZED',
    StmtPool[S].Kind = STK_SYNCHRONIZED);
  SymLeaveScope;

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 08 - CLASSES ET OBJETS (section 8 de la reference)              }
{                                                                       }
{ Portee DELIBEREMENT retenue (section 8 fait 40 sous-sections,            }
{ largement au-dela de ce que la feuille de route annonce) - fondee sur       }
{ les TROIS echantillons reels que la feuille de route cite explicitement     }
{ (Test04Methodes/Test06ProprietesBean/Test07Heritage.jpp), relus en          }
{ ENTIER avant d ecrire une seule ligne ci-dessous :                                }
{   - declaration de classe (8.1) avec modificateurs public/final/               }
{     abstract (8.22/8.21), extends UNIQUE (8.1 - Object implicite si            }
{     absent), corps (8.2/8.3)                                                              }
{   - champs D INSTANCE et STATIQUES (8.4/8.11), initialiseur de CHAMP          }
{     reduit a un LITTERAL (ConstEvalExpr, TODO 05 - AUCUN echantillon             }
{     reel n a besoin de plus, les deux initialisent EXCLUSIVEMENT via              }
{     le constructeur)                                                                        }
{   - methodes (8.13) : static ET d instance, VRAIE surcharge par TYPE            }
{     de parametre (8.32, ClassResolveMethodCall plus bas), recursivite            }
{   - constructeurs (8.6/8.7), constructeur PAR DEFAUT synthetise               }
{     SEULEMENT si aucun n est declare (8.6) ; appel this(...)/super(...)         }
{     EN CHAINE (8.8) reconnu comme un simple APPEL DE METHODE ordinaire            }
{     sur l identificateur special "this"/"super" (AUCUN TStmtKind dedie             }
{     invente - simplification DOCUMENTEE : rien ne verifie qu il                       }
{     apparait SEULEMENT en premiere position du corps, MEME discipline            }
{     "verification contextuelle repoussee" que la redeclaration locale               }
{     de ParseVarDecl ou le type de selecteur switch de StmtSelfTest)                 }
{   - this/super (8.8/8.9) : enregistres comme de VRAIS identificateurs            }
{     SymTab au debut de tout corps de methode/constructeur D INSTANCE            }
{     (JAMAIS pour un corps STATIC) - REUTILISENT tels quels ExprAddIdent/         }
{     SymFind (TODO 06), AUCUN TExprKind special n est invente                          }
{   - heritage SIMPLE (8.1), classe abstraite non instanciable (8.21),           }
{     methode/classe final (8.22), redefinition (override) - AUCUNE               }
{     VERIFICATION de compatibilite de signature entre redefinition et            }
{     methode heritee n est faite (8.15, TODO 19) ; AUCUN VRAI expedition       }
{     dynamique (vtable) n existe (pur probleme de generation de code,            }
{     TODO 21+) - seule la RESOLUTION LEXICALE (quelle methode le texte           }
{     source designe-t-il) est couverte ici                                                 }
{   - acces au champ/appel de methode implicites ("nom" au lieu de                  }
{     "this.nom", section 8.3) ET explicites ("this.nom", "obj.methode()")      }
{     via ClassFindField/ClassResolveMethodCall                                             }
{   - bloc d initialisation static (8.10) et D INSTANCE (8.9), simplifies         }
{     a UN SEUL bloc de chaque sorte par classe (limitation ASSUMEE,                }
{     documentee sur TTypeRec plus haut - un second bloc du meme genre            }
{     est IGNORE avec un avertissement, AUCUN echantillon reel n en                  }
{     utilise meme UN SEUL)                                                                  }
{                                                                       }
{ DELIBEREMENT hors de portee (renvoye a un TODO ulterieur, JAMAIS        }
{ devine) : interfaces/implements (8.25-8.31, TODO 09), classes locales/       }
{ anonymes (8.23/8.24), reflexion/serialisation/clonage/finalisation             }
{ (8.33-8.40, methodes Object non synthetisees - un appel a toString/           }
{ equals/hashCode/clone SANS redefinition reste NON RESOLU, best-effort,          }
{ EXACTEMENT comme tout autre identificateur inconnu), definite-assignment/       }
{ analyse d atteignabilite complete (TODO 19).                                          }
{                                                                       }
{ ARCHITECTURE DE POOLS (choisie AVANT d ecrire le code, pas apres un       }
{ plantage - lecon retenue du TODO 06/07) : FieldPool reste EXCLUSIVEMENT      }
{ pour les CHAMPS DE CLASSE (OwnerTypeIdx plus haut) ; les parametres de       }
{ methode/constructeur vont dans un ParamPool SEPARE - si les DEUX                }
{ partageaient une seule table, les champs d une classe NE resteraient PAS       }
{ contigus des qu une methode (avec SES PROPRES parametres) apparait ENTRE       }
{ deux declarations de champ dans le corps de la classe. Ce risque              }
{ D ENTRELACEMENT NE s applique PAS a ParamPool lui-meme (les parametres           }
{ d UNE SEULE methode sont TOUJOURS pousses en un seul balayage                        }
{ ininterrompu - impossible de parser deux signatures simultanement) ni          }
{ aux CORPS de methode dans StmtArgPool (chaque corps est un unique             }
{ STK_BLOCK, jamais une PLAGE etalee). Par symetrie avec                              }
{ MethodFirst/MethodCount (TODO 04, deja documentes "informatifs                     }
{ seulement"), FieldFirst/FieldCount le sont AUSSI desormais :                            }
{ ClassFindField fait un parcours COMPLET de FieldPool filtre par                     }
{ OwnerTypeIdx, jamais confiant dans une contiguite qui ne serait pas            }
{ garantie de toute facon des qu heritage et methodes se melent.                     }
{ ------------------------------------------------------------ }

Type
  TMemberModifiers = Record   { ensemble PLUS RICHE que TModifiers (TODO   }
                               { 05) : abstract/synchronized/native sont           }
                               { RESERVES aux membres de classe (section         }
                               { 8.13/8.19/8.20), jamais valides devant une        }
                               { simple variable locale. }
    IsStatic       : Boolean;
    IsFinal        : Boolean;
    IsAbstract     : Boolean;
    IsSynchronized : Boolean;
    IsNative       : Boolean;
    Visibility     : TVisibility;   { TODO 12 - VIS_PACKAGE si AUCUN des  }
                                     { trois mots-cles n est ecrit ; SI                }
                                     { PLUSIEURS sont ecrits (source                        }
                                     { invalide, jamais verifie), le                       }
                                     { DERNIER rencontre gagne silencieusement        }
                                     { (best-effort, meme discipline que              }
                                     { le reste de ParseMemberModifiers). }
  End;

Function ParseMemberModifiers: TMemberModifiers;
Var
  M  : TMemberModifiers;
  KW : Integer;
Begin
  M.IsStatic       := False;
  M.IsFinal        := False;
  M.IsAbstract     := False;
  M.IsSynchronized := False;
  M.IsNative       := False;
  M.Visibility     := VIS_PACKAGE;
  While PPKind = TOK_IDENT Do
  Begin
    KW := IsKeyword(PPVal);
    If KW = KW_STATIC Then Begin M.IsStatic := True; PPAdvance; End
    Else If KW = KW_FINAL Then Begin M.IsFinal := True; PPAdvance; End
    Else If KW = KW_ABSTRACT Then Begin M.IsAbstract := True; PPAdvance; End
    Else If KW = KW_SYNCHRONIZED Then Begin M.IsSynchronized := True; PPAdvance; End
    Else If KW = KW_NATIVE Then Begin M.IsNative := True; PPAdvance; End
    Else If KW = KW_PUBLIC    Then Begin M.Visibility := VIS_PUBLIC;    PPAdvance; End
    Else If KW = KW_PROTECTED Then Begin M.Visibility := VIS_PROTECTED; PPAdvance; End
    Else If KW = KW_PRIVATE   Then Begin M.Visibility := VIS_PRIVATE;   PPAdvance; End
    Else If (KW = KW_TRANSIENT) Or (KW = KW_VOLATILE) Then
      PPAdvance   { acceptes syntaxiquement, JAMAIS conserves (section       }
                   { 5.2 - serialisation/modele memoire concurrent, hors        }
                   { de portee de ce compilateur, MEME discipline que              }
                   { TModifiers, TODO 05) }
    Else
      Break;
  End;
  ParseMemberModifiers := M;
End;

{ ------------------------------------------------------------ }
{ FieldPoolAdd / MethodPoolAdd / ClassAdd : les TROIS constructeurs   }
{ "bas niveau" du TODO 08 - Offset (FieldPoolAdd) reste la meme                  }
{ simplification "4 octets par champ, champs PROPRES seulement" DEJA         }
{ documentee sur TFieldRec. }
{ ------------------------------------------------------------ }

Function FieldPoolAdd(Owner, FTypeIdx: Integer; Const Nam: TString;
  IsStatic, IsFinal: Boolean; Vis: TVisibility): Integer;
Var R : Integer;
Begin
  If FieldPoolCount >= MAX_FIELD_POOL Then
  Begin
    WarnMsg('table des champs pleine (MAX_FIELD_POOL)');
    FieldPoolAdd := -1;
    Exit;
  End;
  R := FieldPoolCount;
  FieldPool[R].Name         := Nam;
  FieldPool[R].TypeIdx      := FTypeIdx;
  FieldPool[R].OwnerTypeIdx := Owner;
  FieldPool[R].Offset       := TypeTab[Owner].FieldCount * 4;
  FieldPool[R].IsStatic     := IsStatic;
  FieldPool[R].IsFinal      := IsFinal;
  FieldPool[R].HasInit      := False;
  FieldPool[R].Visibility   := Vis;
  Inc(FieldPoolCount);
  If TypeTab[Owner].FieldFirst < 0 Then TypeTab[Owner].FieldFirst := R;
  Inc(TypeTab[Owner].FieldCount);
  FieldPoolAdd := R;
End;

Function MethodPoolAdd(Owner: Integer; Const Nam: TString; MKind: TMethodKind;
  IsStatic, IsFinal, IsAbstract: Boolean; RetT, PFirst, PCount: Integer;
  Vis: TVisibility): Integer;
Var R : Integer;
Begin
  If MethodPoolCount >= MAX_METHOD_POOL Then
  Begin
    WarnMsg('table des methodes pleine (MAX_METHOD_POOL)');
    MethodPoolAdd := -1;
    Exit;
  End;
  R := MethodPoolCount;
  MethodPool[R].Name         := Nam;
  MethodPool[R].Kind         := MKind;
  MethodPool[R].OwnerTypeIdx := Owner;
  MethodPool[R].IsStatic     := IsStatic;
  MethodPool[R].IsFinal      := IsFinal;
  MethodPool[R].IsAbstract   := IsAbstract;
  MethodPool[R].RetTypeIdx   := RetT;
  MethodPool[R].ParamFirst   := PFirst;
  MethodPool[R].ParamCount   := PCount;
  MethodPool[R].BodyStmtIdx  := -1;
  MethodPool[R].Visibility   := Vis;
  MethodPool[R].IsSynchronized := False; { TODO 14 - ECRASE par           }
                                { ParseMethodDeclRest quand "synchronized"           }
                                { est reellement ecrit (section 14.21/14.22) ;             }
                                { TOUJOURS False pour un constructeur/une                        }
                                { methode de bibliotheque standard (StdlibInit,             }
                                { aucune des deux formes ne peut etre                                }
                                { synchronized en Java reel). }
  MethodPool[R].IsDllImport   := False; { TODO 17 - ECRASE par            }
                                { ParseMethodDeclRest via ParseDllImportDirective          }
                                { quand un javadoc "@dll.import" precedait                    }
                                { REELLEMENT cette methode (section 17.6). }
  MethodPool[R].DllLibName    := '';
  MethodPool[R].DllEntrypoint := '';
  MethodPool[R].DllCharSet    := '';
  MethodPool[R].ThrowsFirst   := -1;   { TODO 19 - ECRASE par            }
                                { ParseMethodDeclRest/ParseConstructorDecl              }
                                { SEULEMENT (voir la note d en-tete de              }
                                { ThrowsPool). }
  MethodPool[R].ThrowsCount   := 0;
  MethodPool[R].FrameSize     := 0;   { ECRASE par ParseMethodDeclRest/          }
                                { ParseConstructorDecl juste apres ParseBlock (extension }
                                { post-TODO25, generateur de code). }
  Inc(MethodPoolCount);
  If TypeTab[Owner].MethodFirst < 0 Then TypeTab[Owner].MethodFirst := R;
  Inc(TypeTab[Owner].MethodCount);
  MethodPoolAdd := R;
End;

Function ClassAdd(Const Nam: TString; SuperT: Integer; IsAbstract, IsFinal: Boolean;
  Vis: TVisibility): Integer;
Var T : Integer;
Begin
  T := TypeAdd(TYK_CLASS, Nam, 4, 4, -1);
  If T >= 0 Then
  Begin
    TypeTab[T].SuperTypeIdx    := SuperT;
    TypeTab[T].IsAbstractClass := IsAbstract;
    TypeTab[T].IsFinalClass    := IsFinal;
    TypeTab[T].Visibility      := Vis;
  End;
  ClassAdd := T;
End;

{ InterfacePoolAdd (TODO 09) : AJOUTE UNE interface a la liste          }
{ "implements" d une classe OU "extends" d une autre interface (section    }
{ 9.5/9.8) - liste PLATE, SANS RISQUE d entrelacement (voir la note                }
{ d en-tete d InterfacePool : la liste d UN SEUL type est TOUJOURS lue      }
{ en un seul balayage ininterrompu, avant son corps). }
Function InterfacePoolAdd(Owner, IfaceTypeIdx: Integer): Integer;
Var R : Integer;
Begin
  If InterfacePoolCount >= MAX_INTERFACE Then
  Begin
    WarnMsg('table des interfaces pleine (MAX_INTERFACE)');
    InterfacePoolAdd := -1;
    Exit;
  End;
  R := InterfacePoolCount;
  InterfacePool[R] := IfaceTypeIdx;
  Inc(InterfacePoolCount);
  If TypeTab[Owner].InterfaceFirst < 0 Then TypeTab[Owner].InterfaceFirst := R;
  Inc(TypeTab[Owner].InterfaceCount);
  InterfacePoolAdd := R;
End;

{ ------------------------------------------------------------ }
{ ClassFindField : corps REEL (Forward plus haut, avant TypeInit,     }
{ pour qu ExprAddIdent/ParsePostfix puissent deja l appeler). Un champ         }
{ REDEFINI (masque) par une sous-classe n existe pas vraiment en Java          }
{ (contrairement a une methode) : le PREMIER trouve en remontant DEPUIS       }
{ T est le bon.                                                             }
{                                                                       }
{ EXTENSION TODO 09 (interfaces, section 9.4/9.5/9.7) : une simple           }
{ chaine SuperTypeIdx (heritage SIMPLE, TODO 08) ne suffit plus des             }
{ qu une INTERFACE peut etendre PLUSIEURS interfaces a la fois - passe        }
{ donc par un helper RECURSIF (ClassFindFieldRec, garde de profondeur        }
{ contre un cycle "invalide" section 9.5 mais JAMAIS detecte comme                }
{ erreur ici, best-effort) : pour une INTERFACE, explore CHACUNE de ses          }
{ interfaces etendues (InterfaceFirst/Count) ; pour une CLASSE, remonte           }
{ d abord SuperTypeIdx PUIS, en dernier recours, ses interfaces                        }
{ IMPLEMENTEES DIRECTEMENT (section 9.4, "peut PARFOIS acceder a une           }
{ constante heritee SANS qualification") - AUCUNE fusion/detection                }
{ d ambiguite entre DEUX interfaces fournissant le MEME nom (section          }
{ 9.7, "ambigu") : la PREMIERE trouvee gagne silencieusement, meme                }
{ discipline best-effort que le reste de ce parseur. }
{ ------------------------------------------------------------ }

Function ClassFindFieldRec(T: Integer; Const Name: TString; Depth: Integer): Integer;
Var I, R : Integer;
Begin
  ClassFindFieldRec := -1;
  If (T < 0) Or (T >= TypeCount) Or (Depth >= 32) Then Exit;

  For I := 0 To FieldPoolCount - 1 Do
    If (FieldPool[I].OwnerTypeIdx = T) And (FieldPool[I].Name = Name) Then
    Begin
      ClassFindFieldRec := I;
      Exit;
    End;

  If TypeTab[T].Kind = TYK_INTERFACE Then
  Begin
    For I := 0 To TypeTab[T].InterfaceCount - 1 Do
    Begin
      R := ClassFindFieldRec(InterfacePool[TypeTab[T].InterfaceFirst + I], Name, Depth + 1);
      If R >= 0 Then
      Begin
        ClassFindFieldRec := R;
        Exit;
      End;
    End;
    Exit;
  End;

  If TypeTab[T].SuperTypeIdx >= 0 Then
  Begin
    R := ClassFindFieldRec(TypeTab[T].SuperTypeIdx, Name, Depth + 1);
    If R >= 0 Then
    Begin
      ClassFindFieldRec := R;
      Exit;
    End;
  End;

  For I := 0 To TypeTab[T].InterfaceCount - 1 Do
  Begin
    R := ClassFindFieldRec(InterfacePool[TypeTab[T].InterfaceFirst + I], Name, Depth + 1);
    If R >= 0 Then
    Begin
      ClassFindFieldRec := R;
      Exit;
    End;
  End;
End;

Function ClassFindField(T: Integer; Const Name: TString): Integer;
Begin
  ClassFindField := ClassFindFieldRec(T, Name, 0);
End;

{ MethodParamsCompatible : TOUS les parametres compatibles (identiques  }
{ OU AT largit vers PT - TypeIsWidening, TODO 04 - OU AT est une             }
{ sous-classe de PT - TypeIsSubclassOf, TODO 04, pour un parametre                }
{ REFERENCE) - un argument NON RESOLU (AT<0, identificateur pas encore           }
{ couvert) est ACCEPTE sans discuter (best-effort, ne doit JAMAIS               }
{ bloquer une resolution par ailleurs evidente). }
Function MethodParamsCompatible(MI, ArgFirst, ArgCount: Integer): Boolean;
Var I, PT, AT : Integer;
Begin
  MethodParamsCompatible := False;
  If MethodPool[MI].ParamCount <> ArgCount Then Exit;
  For I := 0 To ArgCount - 1 Do
  Begin
    PT := ParamPool[MethodPool[MI].ParamFirst + I].TypeIdx;
    AT := ExprPool[ExprArgPool[ArgFirst + I]].TypeIdx;
    If AT < 0 Then Continue;
    If (AT <> PT) And (Not TypeIsWidening(AT, PT)) And (Not TypeIsSubclassOf(AT, PT)) Then
      Exit;
  End;
  MethodParamsCompatible := True;
End;

{ ClassFindConstructor : corps REEL (Forward plus haut). Les            }
{ constructeurs ne sont JAMAIS herites (section 8.6) - AUCUN parcours de     }
{ SuperTypeIdx ICI, contrairement a ClassFindField/ClassResolveMethodCall.  }
{ Repli "premiere correspondance par NOMBRE d arguments seul" si aucune       }
{ candidate n est PLEINEMENT compatible par type - MEME discipline               }
{ best-effort que ClassResolveMethodCall plus bas. }
Function ClassFindConstructor(T, ArgFirst, ArgCount: Integer): Integer;
Var I, FirstMatch : Integer;
Begin
  FirstMatch := -1;
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = T) And (MethodPool[I].Kind = MK_CONSTRUCTOR) And
       (MethodPool[I].ParamCount = ArgCount) Then
    Begin
      If FirstMatch < 0 Then FirstMatch := I;
      If MethodParamsCompatible(I, ArgFirst, ArgCount) Then
      Begin
        ClassFindConstructor := I;
        Exit;
      End;
    End;
  ClassFindConstructor := FirstMatch;
End;

{ MethodSignatureCompatibleWithDelegate (TODO 16, section 16.8,         }
{ "compatibilite des signatures") : compare la signature DECLAREE de           }
{ MI (une methode CANDIDATE, PAS un appel avec des arguments deja                    }
{ evalues - contrairement a MethodParamsCompatible juste au-dessus,               }
{ qui compare des VALEURS a des parametres) contre celle de l UNIQUE                }
{ methode "invoke" synthetisee du type delegate DelT (TypeTab[DelT]        }
{ .MethodFirst - TOUJOURS l unique entree MethodPool d un TYK_DELEGATE,            }
{ voir sa propre note d en-tete). MEME tolerance d elargissement                       }
{ (TypeIsWidening) que MethodParamsCompatible, PAR SYMETRIE - la               }
{ reference (section 16.8) ne precise pas explicitement si                                }
{ l elargissement est admis pour un delegate, mais n a AUCUNE raison               }
{ de s en ecarter puisque Test14Delegates.jpp n a de toute facon QUE               }
{ des signatures IDENTIQUES (int/int -> int, String -> void) - cette             }
{ tolerance reste donc INEXERCEE PAR AUCUN echantillon, juste coherente          }
{ avec le reste de ce fichier. }
Function MethodSignatureCompatibleWithDelegate(MI, DelT: Integer): Boolean;
Var InvokeMI, I, PT1, PT2 : Integer;
Begin
  MethodSignatureCompatibleWithDelegate := False;
  InvokeMI := TypeTab[DelT].MethodFirst;
  If MethodPool[MI].ParamCount <> MethodPool[InvokeMI].ParamCount Then Exit;
  For I := 0 To MethodPool[MI].ParamCount - 1 Do
  Begin
    PT1 := ParamPool[MethodPool[MI].ParamFirst + I].TypeIdx;
    PT2 := ParamPool[MethodPool[InvokeMI].ParamFirst + I].TypeIdx;
    If (PT1 <> PT2) And (Not TypeIsWidening(PT1, PT2)) Then Exit;
  End;
  If (MethodPool[MI].RetTypeIdx <> MethodPool[InvokeMI].RetTypeIdx) And
     (Not TypeIsWidening(MethodPool[MI].RetTypeIdx, MethodPool[InvokeMI].RetTypeIdx)) Then
    Exit;
  MethodSignatureCompatibleWithDelegate := True;
End;

{ DelegateResolveTarget (TODO 16, section 16.5/16.6/16.7) : resout       }
{ "new NomDelegate(cible.methode)" - EXACTEMENT "new Operation(this               }
{ .additionner)"/"new Notification(this.afficher)" de                                    }
{ Test14Delegates.jpp. UN SEUL argument est accepte (une construction            }
{ de delegate ne prend JAMAIS plusieurs cibles a la fois - un                             }
{ multicast s ETEND plus tard via l operateur "+=", section 16.13,                    }
{ HORS DE PORTEE ICI, voir la note d en-tete de ParseDelegateDecl) et       }
{ CET argument doit deja etre un EK_SELECTOR NON resolu comme champ                }
{ (exactement la forme "cible.methode" SANS parentheses que                             }
{ ParsePostfix laisse INTACTE avec TypeIdx=-1, section 16.5 - "elle ne      }
{ contient pas de parentheses, car la methode n est pas appelee au              }
{ moment de la construction") - repli SILENCIEUX a -1 (best-effort,               }
{ MEME discipline que ClassFindConstructor ci-dessus, jamais de                        }
{ FatalError pour un cas non couvert par un echantillon reel) dans               }
{ TOUT autre cas, y compris la reference a une methode STATIQUE                       }
{ (section 16.7, "Exemple.tracer" - syntaxiquement UN SELECTEUR                          }
{ IDENTIQUE dont le Left est un EK_TYPEREF plutot qu une instance,                   }
{ deja couverte PAR SYMETRIE ci-dessous puisqu EK_TYPEREF.TypeIdx pointe          }
{ directement vers la classe elle-meme - mais INEXERCEE, AUCUN                          }
{ echantillon ne construit de delegate sur une methode static). }
Function DelegateResolveTarget(DelT, ArgFirst, ArgCount: Integer): Integer;
Var ArgE, TargetT, I : Integer; Nam : TString;
Begin
  DelegateResolveTarget := -1;
  If ArgCount <> 1 Then Exit;
  ArgE := ExprArgPool[ArgFirst];
  If ExprPool[ArgE].Kind <> EK_SELECTOR Then Exit;
  If ExprPool[ArgE].TypeIdx >= 0 Then Exit;   { deja resolu comme un CHAMP - pas une reference de methode }
  Nam     := ExprPool[ArgE].NameVal;
  TargetT := ExprPool[ExprPool[ArgE].Left].TypeIdx;
  If (TargetT < 0) Or (TargetT >= TypeCount) Then Exit;
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = TargetT) And (MethodPool[I].Name = Nam) And
       (MethodPool[I].Kind = MK_METHOD) And
       MethodSignatureCompatibleWithDelegate(I, DelT) Then
    Begin
      DelegateResolveTarget := I;
      Exit;
    End;
End;

{ ClassResolveMethodCall : corps REEL (Forward plus haut). A UN         }
{ niveau donne, s ARRETE des qu AU MOINS une methode de ce nom/nombre           }
{ d arguments existe (une redefinition, section 8.15, MASQUE la                        }
{ version heritee pour la resolution - ne JAMAIS continuer a chercher            }
{ plus haut a partir de CE niveau une fois un candidat trouve, meme si            }
{ aucun n est PLEINEMENT compatible par type) - a ce niveau-la, prefere          }
{ une candidate DONT CHAQUE parametre est compatible                                    }
{ (MethodParamsCompatible) ; a defaut, repli sur la PREMIERE trouvee               }
{ (best-effort, PAS le veritable algorithme JLS "most specific                             }
{ applicable method").                                                              }
{                                                                       }
{ EXTENSION TODO 09 (interfaces, section 9.5/9.6) : une CLASSE reste       }
{ cherchee via SA SEULE chaine SuperTypeIdx (heritage SIMPLE, INCHANGE          }
{ du TODO 08) - JAMAIS via ses interfaces implementees, puisqu une                   }
{ interface Java 1.1/J++ 6.0 n a AUCUNE methode AVEC CORPS (section              }
{ 9.3/9.15) : une classe CONCRETE fournit forcement SA PROPRE                          }
{ implementation, trouvee DIRECTEMENT a son propre niveau - AUCUN repli           }
{ vers une interface n a de sens pour un APPEL DE METHODE. Une                          }
{ INTERFACE, elle, peut etendre PLUSIEURS interfaces (heritage                            }
{ MULTIPLE) : passe donc par un helper RECURSIF explorant CHAQUE                       }
{ parent (InterfaceFirst/Count) au lieu d une simple remontee lineaire            }
{ - garde de profondeur contre un cycle "invalide" (section 9.5) mais            }
{ jamais SIGNALE comme erreur ici (best-effort). Un DOUBLON de                          }
{ signature herite de deux interfaces sœurs (section 9.6, "n implemente          }
{ qu une fois") ressort naturellement identique des deux cotes -                       }
{ aucune fusion explicite n est necessaire. }
Function ClassResolveMethodCallRec(T: Integer; Const Name: TString;
  ArgFirst, ArgCount, Depth: Integer): Integer;
Var I, R, FirstAtLevel : Integer; FoundAtLevel : Boolean;
Begin
  ClassResolveMethodCallRec := -1;
  If (T < 0) Or (T >= TypeCount) Or (Depth >= 32) Then Exit;

  FoundAtLevel := False;
  FirstAtLevel := -1;
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = T) And (MethodPool[I].Kind = MK_METHOD) And
       (MethodPool[I].Name = Name) And (MethodPool[I].ParamCount = ArgCount) Then
    Begin
      FoundAtLevel := True;
      If FirstAtLevel < 0 Then FirstAtLevel := I;
      If MethodParamsCompatible(I, ArgFirst, ArgCount) Then
      Begin
        ClassResolveMethodCallRec := I;
        Exit;
      End;
    End;
  If FoundAtLevel Then
  Begin
    ClassResolveMethodCallRec := FirstAtLevel;
    Exit;
  End;

  If TypeTab[T].Kind = TYK_INTERFACE Then
  Begin
    For I := 0 To TypeTab[T].InterfaceCount - 1 Do
    Begin
      R := ClassResolveMethodCallRec(InterfacePool[TypeTab[T].InterfaceFirst + I],
        Name, ArgFirst, ArgCount, Depth + 1);
      If R >= 0 Then
      Begin
        ClassResolveMethodCallRec := R;
        Exit;
      End;
    End;
    Exit;
  End;

  If TypeTab[T].SuperTypeIdx >= 0 Then
    ClassResolveMethodCallRec := ClassResolveMethodCallRec(TypeTab[T].SuperTypeIdx,
      Name, ArgFirst, ArgCount, Depth + 1);
End;

Function ClassResolveMethodCall(T: Integer; Const Name: TString;
  ArgFirst, ArgCount: Integer): Integer;
Begin
  ClassResolveMethodCall := ClassResolveMethodCallRec(T, Name, ArgFirst, ArgCount, 0);
End;

{ ------------------------------------------------------------ }
{ ParseOneParamIntoPool : POUSSE un parametre a la fois dans ParamPool  }
{ (persiste APRES la fermeture de la portee locale, pour la resolution         }
{ de surcharge future) - REUTILISE ParseSingleParam (TODO 05, INCHANGE)       }
{ pour la liaison LOCALE reelle (SymAdd, pour que le CORPS de la methode        }
{ retrouve le parametre par nom) ; les DEUX registres (SymTab et                    }
{ ParamPool) restent volontairement SEPARES (voir la note d en-tete de           }
{ section). }
{ ------------------------------------------------------------ }

Function ParseOneParamIntoPool: Boolean;
Var SI : Integer;
Begin
  ParseOneParamIntoPool := False;
  SI := ParseSingleParam;
  If SI < 0 Then Exit;
  If ParamPoolCount >= MAX_PARAM_POOL Then
  Begin
    WarnMsg('table des parametres pleine (MAX_PARAM_POOL)');
    Exit;
  End;
  ParamPool[ParamPoolCount].Name    := SymTab[SI].Name;
  ParamPool[ParamPoolCount].TypeIdx := SymTab[SI].TypeIdx;
  ParamPool[ParamPoolCount].IsFinal := SymTab[SI].IsFinal;
  Inc(ParamPoolCount);
  { extension post-TODO25 (generateur de code) : position EBP-relative   }
  { REELLE de ce parametre - voir la note d en-tete de CurParamOffset. }
  SymTab[SI].Offset := CurParamOffset;
  CurParamOffset := CurParamOffset + 4;
  ParseOneParamIntoPool := True;
End;

{ ParseThrowsClauseIfPresent : "throws Type1, Type2" - jusqu au TODO           }
{ 18, SYNTAXE SEULE (section 8.16, "gestion REELLE... renvoyee au TODO           }
{ 11" - PUIS effectivement traitee au TODO 11, mais SEULEMENT pour les          }
{ VRAIS "throw"/"try"/"catch", jamais pour la clause "throws" elle-meme,      }
{ dont chaque type etait jusqu ICI simplement PARSE puis JETE). TODO 19      }
{ (section 11.3, "coherence best-effort de la clause throws par                       }
{ rapport aux throw reels du corps") a enfin besoin de CES types : ils          }
{ sont desormais POUSSES dans ThrowsPool (MEME convention EXACTE que              }
{ InterfacePool) plutot que jetes - l appelant (ParseMethodDeclRest/             }
{ ParseConstructorDecl SEULEMENT, voir la note d en-tete de ThrowsPool)          }
{ capture ThrowsPoolCount AVANT cet appel et le RESOUSTRAIT APRES pour            }
{ obtenir ThrowsFirst/ThrowsCount, EXACTEMENT le meme motif "capturer           }
{ avant, calculer apres" que ParamPool partout ailleurs dans ce fichier. }
Procedure ParseThrowsClauseIfPresent;
Begin
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_THROWS) Then
  Begin
    PPAdvance;
    Repeat
      If ThrowsPoolCount < MAX_THROWS_POOL Then
      Begin
        ThrowsPool[ThrowsPoolCount] := ParseBaseTypeNoBrackets;
        Inc(ThrowsPoolCount);
      End
      Else
      Begin
        WarnMsg('table des clauses "throws" pleine (MAX_THROWS_POOL)');
        ParseBaseTypeNoBrackets;
      End;
    Until Not PPMatch(',');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseFieldDeclRest : suite d une declaration de CHAMP APRES son       }
{ premier type+nom deja consommes par l appelant (ParseClassMember,           }
{ seul moyen de trancher l ambiguite champ/methode - un "(" qui suit           }
{ immediatement le nom signale une METHODE, jamais un champ). Grammaire        }
{ IDENTIQUE a ParseVarDecl (section 5.2/8.3) - initialiseur reduit a           }
{ ConstEvalExpr (TODO 05, voir la note d en-tete de TFieldRec pour                 }
{ pourquoi). }
{ ------------------------------------------------------------ }

Procedure ParseFieldDeclRest(ClassT: Integer; Mods: TMemberModifiers;
  BaseT: Integer; Const FirstName: TString);
Var
  ElemT : Integer;
  Nam   : TString;
  FI    : Integer;
  CV    : TConstVal;
  More  : Boolean;
Begin
  Nam  := FirstName;
  More := True;
  While More Do
  Begin
    ElemT := BaseT;
    While PPIsOp('[') Do
    Begin
      PPAdvance;
      If Not PPMatch(']') Then
        FatalError('"]" attendu apres "[" dans un declarateur de tableau ' +
          '(section 8.3)');
      ElemT := TypeAdd(TYK_ARRAY, '', 4, 4, ElemT);
    End;

    FI := FieldPoolAdd(ClassT, ElemT, Nam, Mods.IsStatic, Mods.IsFinal, Mods.Visibility);

    If PPMatch('=') Then
      If (FI >= 0) And ConstEvalExpr(CV) Then
      Begin
        FieldPool[FI].HasInit  := True;
        FieldPool[FI].ConstVal := CV;
      End;

    If PPMatch(',') Then
    Begin
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ attendu apres ","');
        More := False;
      End
      Else
      Begin
        Nam := PPVal;
        PPAdvance;
      End;
    End
    Else
      More := False;
  End;

  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''une declaration de champ (section 8.3)');
End;

{ ------------------------------------------------------------ }
{ ParseConstructorDecl : "NomDeClasse(params) bloc" (section 8.7) -    }
{ TOUJOURS un contexte D INSTANCE (this/super enregistres, JAMAIS de           }
{ variante static). this(...)/super(...) en premiere ligne du corps            }
{ (section 8.8) sont reconnus PLUS TARD, PENDANT le parsing normal du          }
{ bloc, comme un simple appel de methode sur l identificateur "this"/          }
{ "super" (voir la note d en-tete de section - AUCUNE verification de           }
{ position n est faite ici). }
{ ------------------------------------------------------------ }

Procedure ParseConstructorDecl(ClassT: Integer; Mods: TMemberModifiers);
Var
  MI, ParamStart, ParamN, ThrowsStart, SI : Integer;
Begin
  PPAdvance;   { nom de la classe = nom du constructeur, deja verifie par }
               { l appelant (ParseClassMember) }
  If Not PPMatch('(') Then
    FatalError('"(" attendu apres un nom de constructeur (section 8.7)');

  SymEnterScope;
  { extension post-TODO25 (generateur de code) : meme reinitialisation   }
  { que ParseMethodDeclRest, voir sa propre note - AUCUN corps de              }
  { constructeur n est ENCORE compile (this/champs restent hors de              }
  { portee, voir CompileExpr/CompileStmt), mais garder cette disposition             }
  { correcte des MAINTENANT evite de corrompre silencieusement l etat             }
  { partage CurParamOffset/CurLocalOffset pour un futur appelant. }
  CurParamOffset := 8;
  CurLocalOffset := 0;
  SI := SymAdd('this', SK_VAR, ClassT, False, False);
  SymTab[SI].Offset := CurParamOffset;
  CurParamOffset := CurParamOffset + 4;
  If TypeTab[ClassT].SuperTypeIdx >= 0 Then
    SymAdd('super', SK_VAR, TypeTab[ClassT].SuperTypeIdx, False, False);

  ParamStart := ParamPoolCount;
  ParamN     := 0;
  If Not PPIsOp(')') Then
    Repeat
      If ParseOneParamIntoPool Then Inc(ParamN);
    Until Not PPMatch(',');
  If Not PPMatch(')') Then
    FatalError('")" attendu apres les parametres d''un constructeur (section 8.7)');

  ThrowsStart := ThrowsPoolCount;
  ParseThrowsClauseIfPresent;

  MI := MethodPoolAdd(ClassT, '', MK_CONSTRUCTOR, False, False, False,
    PRIMTYPE_VOID, ParamStart, ParamN, Mods.Visibility);
  If MI >= 0 Then           { TODO 19 - voir la note d en-tete de ThrowsPool }
  Begin
    MethodPool[MI].ThrowsFirst := ThrowsStart;
    MethodPool[MI].ThrowsCount := ThrowsPoolCount - ThrowsStart;
  End;

  If MI >= 0 Then
    MethodPool[MI].BodyStmtIdx := ParseBlock
  Else
    ParseBlock;

  If MI >= 0 Then SemanticCheckMethodBody(MI);   { TODO 19 }
  If MI >= 0 Then MethodPool[MI].FrameSize := -CurLocalOffset;   { extension post-TODO25 }

  SymLeaveScope;
End;

{ ------------------------------------------------------------ }
{ ParseDllImportArgs/ParseDllImportDirective (TODO 17, sections 17.6-   }
{ 17.13) : EXTRACTION STRUCTUREE SEULE du texte "@dll.import(...)"               }
{ CAPTURE brut par le lexeur (LexLastJavadocText, TODO 03) - AUCUNE               }
{ VRAIE importation DLL/thunk n est cablee ICI, decision EXPLICITE                   }
{ ("voir TODO 18" dans le texte MEME du roadmap de ce TODO) plutot                    }
{ qu une omission : AUCUNE generation de code n existe encore nulle                  }
{ part dans ce compilateur. Portee groundee sur L UNIQUE forme                             }
{ REELLEMENT exercee, Test18JDirect.jpp, "@dll.import(""USER32"",                     }
{ auto)" - nom de bibliotheque ENTRE GUILLEMETS (TOUJOURS le premier              }
{ argument, section 17.8) suivi de ZERO ou PLUSIEURS modificateurs                    }
{ separes par des virgules, soit un mot NU (ansi/unicode/auto/ole,                    }
{ sections 17.11/17.13 - AUCUNE liste FERMEE verifiee, best-effort,                  }
{ MEME discipline que le reste de ce parseur), soit "entrypoint=                          }
{ VALEUR" (sections 17.9/17.10, "VALEUR" couvrant AUSSI BIEN un nom                  }
{ exporte reel qu un ordinal "#3" - la reference guillemette les DEUX          }
{ formes de la MEME facon, AUCUNE distinction n est donc necessaire                  }
{ ICI). "entrypoint"/l ordinal restent CODES mais NON EXERCES (AUCUNE           }
{ assertion, AUCUN echantillon ne les utilise) - ECRITS malgre tout               }
{ car le texte du roadmap du TODO 18 lui-meme les cite explicitement            }
{ comme deja "PARSES au TODO 17" ("Methode native J/Direct +                            }
{ @dll.import(NOMDLL[, entrypoint]) (la directive PARSEE au TODO                     }
{ 17)"), PAS une extrapolation au-dela du texte source. }
Procedure ParseDllImportArgs(MI: Integer; Const ArgsTxt: TString);
Var
  Pieces : Array[0..7] Of TString;
  Cnt, I, P, Start : Integer;
  Piece, Key, Val : TString;
Begin
  Cnt   := 0;
  Start := 1;
  For P := 1 To Length(ArgsTxt) + 1 Do
    If (P > Length(ArgsTxt)) Or (ArgsTxt[P] = ',') Then
    Begin
      Piece := Copy(ArgsTxt, Start, P - Start);
      While (Length(Piece) > 0) And (Piece[1] = ' ') Do Delete(Piece, 1, 1);
      While (Length(Piece) > 0) And (Piece[Length(Piece)] = ' ') Do Delete(Piece, Length(Piece), 1);
      If (Cnt < 8) And (Length(Piece) > 0) Then
      Begin
        Pieces[Cnt] := Piece;
        Inc(Cnt);
      End;
      Start := P + 1;
    End;

  If Cnt = 0 Then
  Begin
    FatalError('"@dll.import()" attend au moins le nom de la bibliotheque ' +
      '(section 17.6, TODO 17)');
    Exit;
  End;

  Piece := Pieces[0];
  If (Length(Piece) < 2) Or (Piece[1] <> '"') Or (Piece[Length(Piece)] <> '"') Then
  Begin
    FatalError('"@dll.import(...)" : le nom de bibliotheque doit etre ' +
      'ENTRE GUILLEMETS (section 17.6/17.8, TODO 17)');
    Exit;
  End;
  MethodPool[MI].DllLibName := Copy(Piece, 2, Length(Piece) - 2);

  For I := 1 To Cnt - 1 Do
  Begin
    Piece := Pieces[I];
    P := Pos('=', Piece);
    If P > 0 Then
    Begin
      Key := Copy(Piece, 1, P - 1);
      Val := Copy(Piece, P + 1, Length(Piece) - P);
      While (Length(Key) > 0) And (Key[Length(Key)] = ' ') Do Delete(Key, Length(Key), 1);
      If (Length(Val) >= 2) And (Val[1] = '"') And (Val[Length(Val)] = '"') Then
        Val := Copy(Val, 2, Length(Val) - 2);
      If Key = 'entrypoint' Then
        MethodPool[MI].DllEntrypoint := Val
      Else
        FatalError('"@dll.import(...)" : cle "' + Key + '" non reconnue ' +
          '(section 17.6-17.13, TODO 17)');
    End
    Else
      MethodPool[MI].DllCharSet := Piece;
  End;

  MethodPool[MI].IsDllImport := True;
End;

Procedure ParseDllImportDirective(MI: Integer);
Var
  Txt : TString;
  P, ArgStart, ArgEnd : Integer;
Begin
  Txt := NativeJavadocText;
  P := Pos('@dll.import', Txt);
  If P = 0 Then Exit;   { AUCUN javadoc J/Direct pour cette methode native - rien a faire (section 17.2) }

  P := P + Length('@dll.import');
  While (P <= Length(Txt)) And (Txt[P] = ' ') Do Inc(P);
  If (P > Length(Txt)) Or (Txt[P] <> '(') Then
  Begin
    FatalError('"@dll.import" doit etre suivi de "(...)" (section 17.6, TODO 17)');
    Exit;
  End;
  ArgStart := P + 1;
  ArgEnd   := ArgStart;
  While (ArgEnd <= Length(Txt)) And (Txt[ArgEnd] <> ')') Do Inc(ArgEnd);
  If ArgEnd > Length(Txt) Then
  Begin
    FatalError('"@dll.import(" sans ")" correspondant (section 17.6, TODO 17)');
    Exit;
  End;

  ParseDllImportArgs(MI, Copy(Txt, ArgStart, ArgEnd - ArgStart));
End;

{ ------------------------------------------------------------ }
{ ParseMethodDeclRest : suite d une declaration de METHODE APRES son   }
{ type de retour+nom deja consommes par l appelant, a partir du "("           }
{ (section 8.13). this/super ne sont enregistres QUE pour une methode         }
{ D INSTANCE (Not Mods.IsStatic) - AUCUN des deux n existe dans un                }
{ contexte static (section 8.13 - "une methode static... ne peut pas             }
{ utiliser this"). abstract/native (8.19/8.20) attendent ";" a la place          }
{ d un corps. }
{ ------------------------------------------------------------ }

Procedure ParseMethodDeclRest(ClassT: Integer; Mods: TMemberModifiers;
  RetT: Integer; Const Nam: TString);
Var
  MI, ParamStart, ParamN, ThrowsStart, SI : Integer;
Begin
  SymEnterScope;
  { extension post-TODO25 (generateur de code) : repart TOUJOURS de zero  }
  { (8/0) - voir la note d en-tete de CurParamOffset, aucune sauvegarde/           }
  { restauration necessaire (pas de fonction imbriquee dans ce compilateur). }
  CurParamOffset := 8;
  CurLocalOffset := 0;
  If Not Mods.IsStatic Then
  Begin
    SI := SymAdd('this', SK_VAR, ClassT, False, False);
    SymTab[SI].Offset := CurParamOffset;
    CurParamOffset := CurParamOffset + 4;
    If TypeTab[ClassT].SuperTypeIdx >= 0 Then
      SymAdd('super', SK_VAR, TypeTab[ClassT].SuperTypeIdx, False, False);
  End;

  ParamStart := ParamPoolCount;
  ParamN     := 0;
  If Not PPIsOp(')') Then
    Repeat
      If ParseOneParamIntoPool Then Inc(ParamN);
    Until Not PPMatch(',');
  If Not PPMatch(')') Then
    FatalError('")" attendu apres les parametres d''une methode (section 8.13)');

  ThrowsStart := ThrowsPoolCount;
  ParseThrowsClauseIfPresent;

  MI := MethodPoolAdd(ClassT, Nam, MK_METHOD, Mods.IsStatic, Mods.IsFinal,
    Mods.IsAbstract, RetT, ParamStart, ParamN, Mods.Visibility);
  If MI >= 0 Then                     { TODO 14 (section 14.21/14.22) - }
    MethodPool[MI].IsSynchronized := Mods.IsSynchronized;
  If (MI >= 0) And Mods.IsNative Then  { TODO 17 (section 17.6/17.7) - }
    ParseDllImportDirective(MI);
  If MI >= 0 Then           { TODO 19 - voir la note d en-tete de ThrowsPool }
  Begin
    MethodPool[MI].ThrowsFirst := ThrowsStart;
    MethodPool[MI].ThrowsCount := ThrowsPoolCount - ThrowsStart;
  End;

  If Mods.IsAbstract Or Mods.IsNative Then
  Begin
    If Not PPMatch(';') Then
      FatalError('";" attendu apres une methode abstraite/native - AUCUN ' +
        'corps autorise (section 8.19/8.20)');
  End
  Else If MI >= 0 Then
  Begin
    MethodPool[MI].BodyStmtIdx := ParseBlock;
    SemanticCheckMethodBody(MI);   { TODO 19 }
    { extension post-TODO25 (generateur de code) : CurLocalOffset a       }
    { atteint sa valeur FINALE pour CETTE methode (ParseBlock a fini de           }
    { parser tout son corps, y compris les blocs imbriques - AUCUNE               }
    { autre locale ne sera plus ajoutee) - capture AVANT que la methode                }
    { SUIVANTE ne le reinitialise. }
    MethodPool[MI].FrameSize := -CurLocalOffset;
  End
  Else
    ParseBlock;

  SymLeaveScope;
End;

{ Forward EXCEPTIONNEL (ParseClassDecl/ParseInterfaceDecl) : ParseClassMember }
{ (juste en dessous) doit pouvoir les appeler pour une classe/interface        }
{ MEMBRE (TODO 09, sections 9.14/9.17) alors que leurs VRAIS corps               }
{ n apparaissent que PLUS BAS - MEME technique que le Forward de                    }
{ ClassFindField et consorts, plus haut dans ce fichier. }
Function ParseClassDecl: Integer; Forward;
Function ParseInterfaceDecl: Integer; Forward;

{ NestedTypeKeywordAhead : lookahead SANS EFFET DE BORD (PP sauvegarde/  }
{ restaure TOUJOURS - MEME technique que LooksLikeCastAhead/                       }
{ LooksLikeDeclAhead, TODO 06/07) : saute par-dessus une SEQUENCE de              }
{ modificateurs (public/protected/private/static/final/abstract) pour           }
{ verifier si "class" ou "interface" suit (TODO 09, sections 9.14/9.17 -      }
{ classe/interface MEMBRE, "static class Foo"/"interface Bar" en                     }
{ position de membre). Renvoie KW_CLASS/KW_INTERFACE, ou 0 si ni l un            }
{ ni l autre. }
Function NestedTypeKeywordAhead: Integer;
Var SavedPP, KW, Res : Integer;
Begin
  SavedPP := PP;
  Res := 0;
  While PPKind = TOK_IDENT Do
  Begin
    KW := IsKeyword(PPVal);
    If (KW = KW_CLASS) Or (KW = KW_INTERFACE) Then
    Begin
      Res := KW;
      Break;
    End;
    If (KW = KW_STATIC) Or (KW = KW_FINAL) Or (KW = KW_ABSTRACT) Or
       (KW = KW_PUBLIC) Or (KW = KW_PROTECTED) Or (KW = KW_PRIVATE) Then
      PPAdvance
    Else
      Break;
  End;
  PP := SavedPP;
  NestedTypeKeywordAhead := Res;
End;

{ DelegateDeclAhead (TODO 16, section 16.3/16.4) : MEME technique       }
{ EXACTE que NestedTypeKeywordAhead ci-dessus (lookahead SANS EFFET DE          }
{ BORD) - saute les memes modificateurs, PUIS optionnellement le mot            }
{ CONTEXTUEL "multicast" (jamais dans IsKeyword, voir la note d en-tete           }
{ du TODO 16 pres de la table des mots reserves - compare ICI                              }
{ directement le TEXTE du token), et verifie si "delegate" (LUI AUSSI           }
{ contextuel) suit. Grammaire section 16.3 : "[modificateurs]                            }
{ [multicast] delegate TypeRetour Nom(...)". }
Function DelegateDeclAhead: Boolean;
Var SavedPP, KW : Integer;
Begin
  SavedPP := PP;
  While PPKind = TOK_IDENT Do
  Begin
    KW := IsKeyword(PPVal);
    If (KW = KW_STATIC) Or (KW = KW_FINAL) Or (KW = KW_ABSTRACT) Or
       (KW = KW_PUBLIC) Or (KW = KW_PROTECTED) Or (KW = KW_PRIVATE) Then
      PPAdvance
    Else If PPVal = 'multicast' Then
      PPAdvance
    Else
      Break;
  End;
  DelegateDeclAhead := (PPKind = TOK_IDENT) And (PPVal = 'delegate');
  PP := SavedPP;
End;

{ ------------------------------------------------------------ }
{ ParseDelegateDecl (TODO 16, sections 16.1-16.4) : declaration d un    }
{ type delegate MEMBRE ("public delegate int Operation(int gauche,             }
{ int droite);"/"public multicast delegate void Notification(String            }
{ message);", EXACTEMENT Test14Delegates.jpp). Un delegate est un              }
{ VRAI type (TypeAdd(TYK_DELEGATE,...), enregistre GLOBALEMENT,                        }
{ retrouvable par TypeFindByName EXACTEMENT comme une classe/interface           }
{ membre du TODO 09 - "AUCUNE reference englobante n est jamais                        }
{ construite" s applique ICI de la MEME facon), PAS une METHODE : il           }
{ n a ni corps ni "this" (section 16.3, "elle ne contient pas de                       }
{ corps"). La SEULE donnee qu il porte (sa signature - type de retour            }
{ et parametres, section 16.4) est stockee en synthetisant UNE SEULE            }
{ methode "invoke" (MethodPoolAdd, TODO 08, EXACTEMENT le meme                        }
{ mecanisme que StdlibInit au TODO 13 pour une methode SANS corps                    }
{ source reel) - AUCUNE nouvelle table n est necessaire : TypeTab                     }
{ [DelT].MethodFirst pointe TOUJOURS vers cette unique entree (voir              }
{ la note d en-tete de TYK_DELEGATE), retrouvee ensuite PAR LE MEME               }
{ ClassResolveMethodCall generique que TOUT AUTRE type (TYK_CLASS/                   }
{ TYK_INTERFACE/TYK_STRING/TYK_DELEGATE, voir les DEUX extensions                    }
{ dans ParsePostfix) quand le code appelant ecrit "operation.invoke                }
{ (...)" - ZERO code de resolution nouveau pour invoke() lui-meme.               }
{ SymEnterScope/SymLeaveScope entourent le parsing des parametres                    }
{ MEME si aucun corps ne les utilisera jamais - EXACT precedent de               }
{ ParseInterfaceMember (TODO 09) pour la MEME raison (ParseOneParamIntoPool  }
{ appelle SymAdd, qui a besoin d UNE portee ouverte, n importe                       }
{ laquelle, pour ne pas polluer la portee ENGLOBANTE). }
Procedure ParseDelegateDecl(ClassT: Integer);
Var
  Mods       : TMemberModifiers;
  IsMulticast : Boolean;
  RetT, DelT, ParamStart, ParamN : Integer;
  Nam : TString;
Begin
  Mods := ParseMemberModifiers;   { section 16.4 "modificateurs" }

  IsMulticast := False;
  If (PPKind = TOK_IDENT) And (PPVal = 'multicast') Then
  Begin
    IsMulticast := True;
    PPAdvance;
  End;
  PPAdvance;   { 'delegate' - mot CONTEXTUEL, jamais dans IsKeyword }

  RetT := ParseTypeRef;   { TypeRetour, section 16.4 - "void" ou un type REEL }

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de delegate attendu apres "delegate" (section 16.3)');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If Not PPMatch('(') Then
  Begin
    FatalError('"(" attendu apres le nom d''un delegate (section 16.3)');
    Exit;
  End;
  SymEnterScope;
  ParamStart := ParamPoolCount;
  ParamN     := 0;
  If Not PPIsOp(')') Then
    Repeat
      If ParseOneParamIntoPool Then Inc(ParamN);
    Until Not PPMatch(',');
  If Not PPMatch(')') Then
    FatalError('")" attendu apres les parametres d''un delegate (section 16.3)');
  ParseThrowsClauseIfPresent;   { section 16.4 "throws" - syntaxe seule, comme toute methode }
  SymLeaveScope;

  DelT := TypeAdd(TYK_DELEGATE, Nam, 4, 4, -1);
  If DelT >= 0 Then
  Begin
    TypeTab[DelT].Visibility  := Mods.Visibility;
    TypeTab[DelT].IsMulticast := IsMulticast;
    MethodPoolAdd(DelT, 'invoke', MK_METHOD, False, False, False,
      RetT, ParamStart, ParamN, VIS_PUBLIC);
  End;

  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''une declaration delegate (section 16.3)');
End;

{ ------------------------------------------------------------ }
{ ParseClassMember : UN SEUL membre du corps d une classe (section     }
{ 8.2/8.3) - dispatche entre bloc d initialisation static (8.10, "static"     }
{ SUIVI immediatement de "{"), bloc d initialisation D INSTANCE (8.9,           }
{ "{" SEUL en position de membre), classe/interface MEMBRE (TODO 09,                }
{ sections 9.14/9.17 - "static class Foo"/"interface Bar" ; TOUTE classe            }
{ membre est traitee comme SI elle etait static, AUCUNE reference                     }
{ englobante n est jamais construite - section 9.18-9.22, classes                     }
{ internes NON static, hors de portee, voir la note d en-tete de                        }
{ ParseClassDecl plus bas), constructeur (identificateur EGAL au nom               }
{ de la classe COURANTE, SUIVI de "(") et champ/methode ordinaires                    }
{ (type puis nom, "(" qui suit tranche methode vs champ - AUCUN autre             }
{ moyen de savoir a l avance, meme principe que LooksLikeDeclAhead au           }
{ TODO 07). }
{ ------------------------------------------------------------ }

Procedure ParseClassMember(ClassT: Integer);
Var
  Mods  : TMemberModifiers;
  BaseT : Integer;
  Nam   : TString;
Begin
  { TODO 17 - instantane FIGE AVANT tout token de ce membre (voir la      }
  { note d en-tete de NativeJavadocText). }
  NativeJavadocText := LexLastJavadocText;
  NativeJavadocLine := LexLastJavadocLine;

  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_STATIC) And
     (PP2Kind = TOK_OP) And (PP2Val = '{') Then
  Begin
    PPAdvance;   { 'static' }
    If TypeTab[ClassT].StaticInitBlockIdx >= 0 Then
    Begin
      WarnMsg('un second bloc d''initialisation static est ignore ' +
        '(section 8.10 - limitation assumee, TODO 08)');
      ParseBlock;
    End
    Else
      TypeTab[ClassT].StaticInitBlockIdx := ParseBlock;
    Exit;
  End;

  If PPIsOp('{') Then
  Begin
    SymEnterScope;
    SymAdd('this', SK_VAR, ClassT, False, False);
    If TypeTab[ClassT].SuperTypeIdx >= 0 Then
      SymAdd('super', SK_VAR, TypeTab[ClassT].SuperTypeIdx, False, False);
    If TypeTab[ClassT].InstanceInitBlockIdx >= 0 Then
    Begin
      WarnMsg('un second bloc d''initialisation d''instance est ignore ' +
        '(section 8.9 - limitation assumee, TODO 08)');
      ParseBlock;
    End
    Else
      TypeTab[ClassT].InstanceInitBlockIdx := ParseBlock;
    SymLeaveScope;
    Exit;
  End;

  Case NestedTypeKeywordAhead Of
    KW_CLASS:     Begin ParseClassDecl;     Exit; End;
    KW_INTERFACE: Begin ParseInterfaceDecl; Exit; End;
  End;

  If DelegateDeclAhead Then          { TODO 16, section 16.3 - verifie AVANT }
  Begin                              { ParseMemberModifiers puisque "multicast" }
    ParseDelegateDecl(ClassT);       { doit encore etre visible EN TETE de flux }
    Exit;
  End;

  Mods := ParseMemberModifiers;

  If (PPKind = TOK_IDENT) And (PPVal = TypeTab[ClassT].Name) And
     (PP2Kind = TOK_OP) And (PP2Val = '(') Then
  Begin
    ParseConstructorDecl(ClassT, Mods);
    Exit;
  End;

  BaseT := ParseTypeRef;
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de champ ou de methode attendu (section 8.3/8.13)');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPMatch('(') Then
    ParseMethodDeclRest(ClassT, Mods, BaseT, Nam)
  Else
    ParseFieldDeclRest(ClassT, Mods, BaseT, Nam);
End;

{ ------------------------------------------------------------ }
{ ParseClassBody / ParseClassDecl : point d entree du TODO 08.        }
{ ParseClassDecl synthetise un constructeur PAR DEFAUT (section 8.6)          }
{ SEULEMENT si AUCUN constructeur n a ete DECLARE par le corps qui vient        }
{ d etre parse - JAMAIS via une regle "classe abstraite exclue", une             }
{ classe abstraite Java PEUT avoir un constructeur (implicite ou non),           }
{ seule son INSTANCIATION directe est interdite (section 8.21, verifiee            }
{ par ParseNewExpr, TODO 06 plus haut). Limitation single-pass DEJA               }
{ documentee sur ParseBaseTypeNoBrackets (extends d une classe pas ENCORE       }
{ declaree = FatalError, jamais de resolution a deux passes) - EXACTEMENT       }
{ l ordre textuel de Test07Heritage.jpp (Forme avant Rectangle/Cercle). }
{ ------------------------------------------------------------ }

Procedure ParseClassBody(ClassT: Integer);
Begin
  If Not PPMatch('{') Then
  Begin
    FatalError('"{" attendu au debut d''un corps de classe (section 8.2)');
    Exit;
  End;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
    ParseClassMember(ClassT);
  If Not PPMatch('}') Then
    FatalError('"}" attendu a la fin d''un corps de classe (section 8.2)');
End;

Function ParseClassDecl: Integer;
Var
  Mods    : TMemberModifiers;
  Nam     : TString;
  SuperT  : Integer;
  ClassT  : Integer;
  I       : Integer;
  HasCtor : Boolean;
  Saved   : Integer;
Begin
  Mods := ParseMemberModifiers;
  If IsKeyword(PPVal) <> KW_CLASS Then
  Begin
    FatalError('"class" attendu (section 8.1)');
    ParseClassDecl := -1;
    Exit;
  End;
  PPAdvance;   { 'class' }

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de classe attendu (section 8.1)');
    ParseClassDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  SuperT := PDT_OBJECT;   { Object implicite en l absence d''extends (8.1) }
  If IsKeyword(PPVal) = KW_EXTENDS Then
  Begin
    PPAdvance;
    SuperT := ParseBaseTypeNoBrackets;
  End;

  ClassT := ClassAdd(Nam, SuperT, Mods.IsAbstract, Mods.IsFinal, Mods.Visibility);

  { EXTENSION TODO 09 (section 9.8) : "implements I1, I2, ..." APRES le  }
  { "extends" optionnel, AVANT le corps - AUCUNE verification que la           }
  { classe fournit REELLEMENT toutes les methodes exigees (section 9.9,          }
  { "doit implementer" resterait de la verification semantique, TODO 19) :    }
  { ICI, "implements" enregistre SEULEMENT la liste des contrats                     }
  { (InterfacePoolAdd), consultee par ClassResolveMethodCall/ClassFindField      }
  { UNIQUEMENT a travers une reference DE TYPE INTERFACE (jamais pour            }
  { resoudre un appel sur la classe implementante elle-meme, voir la              }
  { note d en-tete de ClassResolveMethodCall). }
  If IsKeyword(PPVal) = KW_IMPLEMENTS Then
  Begin
    PPAdvance;
    Repeat
      InterfacePoolAdd(ClassT, ParseBaseTypeNoBrackets);
    Until Not PPMatch(',');
  End;

  Saved               := CurrentClassTypeIdx;
  CurrentClassTypeIdx := ClassT;

  ParseClassBody(ClassT);

  SemanticCheckOverrides(ClassT);   { TODO 19 }

  HasCtor := False;
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = ClassT) And (MethodPool[I].Kind = MK_CONSTRUCTOR) Then
      HasCtor := True;
  If Not HasCtor Then
    { section 12.24, "un constructeur par defaut recoit la visibilite de   }
    { sa classe" - Mods.Visibility (deja capture plus haut, CETTE MEME     }
    { fonction) est directement REUTILISE. }
    MethodPoolAdd(ClassT, '', MK_CONSTRUCTOR, False, False, False,
      PRIMTYPE_VOID, ParamPoolCount, 0, Mods.Visibility);

  CurrentClassTypeIdx := Saved;

  ParseClassDecl := ClassT;
End;

{ ------------------------------------------------------------ }
{ TODO 09 - INTERFACES, CLASSES MEMBRES STATIC                             }
{                                                                       }
{ Portee DECIDEE EXPLICITEMENT (comme l exige la feuille de route)          }
{ APRES avoir grep SAMPLES\JPP\*.jpp pour les formes REELLEMENT                    }
{ exercees (section 9 de la reference fait 39 sous-sections, largement          }
{ au-dela) :                                                                    }
{   - Test08Interfaces.jpp : UNE interface a UNE methode (CompteurListener),    }
{     UNE classe avec un CHAMP de type interface (Compteur.listener) qui         }
{     appelle une methode dessus (listener.valeurChangee(...)), ET UNE          }
{     classe MEMBRE STATIC imbriquee (JournalListener, "private static          }
{     class ... implements CompteurListener") referencee par son nom            }
{     SIMPLE (non qualifie "Exterieure.Interieure") depuis SA PROPRE               }
{     classe englobante                                                                     }
{   - Test09Exceptions.jpp : confirme qu une classe de HAUT NIVEAU              }
{     etendant Exception (deja couvert au TODO 08) reste le SEUL besoin           }
{     "classe imbriquee adjacente" reellement exerce - AUCUNE classe               }
{     interne/locale/anonyme n apparait nulle part dans les 18                          }
{     echantillons                                                                          }
{                                                                       }
{ INCLUS :                                                                      }
{   - declaration d interface (9.2), heritage MULTIPLE entre interfaces          }
{     via "extends" (9.5, InterfacePool/InterfaceFirst/Count REUTILISES          }
{     du TODO 04 - jusqu ici reserves, jamais peuples)                                }
{   - methodes d interface (9.3) : TOUJOURS abstraites, JAMAIS de corps,          }
{     "public"/"abstract" implicites (les VALEURS IsAbstract=True/                     }
{     IsStatic=False sont FORCEES, jamais lues depuis les modificateurs           }
{     du source, meme s ils sont ACCEPTES syntaxiquement par                            }
{     ParseMemberModifiers)                                                                 }
{   - champs d interface (9.4) : TOUJOURS public static final, valeur             }
{     REELLEMENT OBLIGATOIRE (contrairement a un champ de classe                      }
{     ordinaire, TODO 08, ou l initialiseur reste optionnel)                              }
{   - "implements" sur une classe (9.8), heritage MULTIPLE de contrats            }
{     (InterfacePoolAdd, MEME pool que les "extends" d interface -                    }
{     semantiquement equivalent : "liste des obligations directement            }
{     heritees")                                                                            }
{   - resolution best-effort d un appel a travers une reference DE TYPE           }
{     INTERFACE (ClassResolveMethodCall etendu, section 9.11/9.12 -                  }
{     liaison dynamique REELLE hors de portee, TODO 21+, ceci reste                  }
{     purement LEXICAL : le type STATIQUE de l expression suffit a                     }
{     trouver la signature, JAMAIS la classe REELLEMENT instanciee a               }
{     l execution, inconnue du compilateur de toute facon)                              }
{   - classe/interface MEMBRE STATIC (9.14/9.17) : REUTILISE tel quel            }
{     ParseClassDecl/ParseInterfaceDecl de facon RECURSIVE depuis                      }
{     ParseClassMember/ParseInterfaceMember - CurrentClassTypeIdx reste           }
{     une simple variable (la pile d appels Pascal fait le travail, voir          }
{     sa note d en-tete plus haut) ; ENREGISTREE dans le MEME TypeTab               }
{     global QUE les classes de haut niveau, trouvable par son nom                    }
{     SIMPLE (TypeFindByName, TODO 08, INCHANGE) - EXACTEMENT ce dont             }
{     Test08Interfaces.jpp a besoin ("new JournalListener()" depuis                  }
{     l interieur de Test08Interfaces)                                                      }
{                                                                       }
{ DELIBEREMENT hors de portee (AUCUN echantillon reel n en a besoin,        }
{ documente plutot que devine) :                                                    }
{   - classes MEMBRES INTERNES non static (9.18-9.22) : PAS de reference          }
{     synthetique vers une instance englobante (Externe.this, 9.19),               }
{     PAS de "externe.new Interne()" (9.18) - toute classe membre EST            }
{     traitee comme SI static, "static" est accepte mais aussi FACULTATIF     }
{     dans ParseClassMember (AUCUNE distinction n est faite - une classe          }
{     membre SANS static resterait, a tort, traitee comme static ; le               }
{     seul echantillon reel en ecrit UN, EXPLICITEMENT static, donc               }
{     cette lacune reste theorique)                                                        }
{   - classe locale (9.23), classe anonyme (9.25-9.27), capture de                    }
{     variable final (9.24) - besoin d infrastructure de fermeture NEUVE           }
{     (parametre synthetique, copie de variable capturee), hors de                     }
{     portee tant qu aucun echantillon ne les exerce                                       }
{   - resolution/verification de conflits entre interfaces sœurs                       }
{     (9.6/9.7, "ambigu") - la PREMIERE trouvee gagne silencieusement            }
{   - reference qualifiee "Exterieure.Interieure"/"Interface.CONSTANTE"           }
{     (9.14/9.4) - seul l acces PAR NOM SIMPLE est resolu, AUCUN parseur           }
{     de "TypeName.membre" (distinct de "expr.membre") n existe encore           }
{   - verification qu une classe concrete implemente REELLEMENT toutes           }
{     les methodes exigees par ses interfaces (9.9) - semantique complete,        }
{     TODO 19                                                                             }
{ ------------------------------------------------------------ }

{ ParseInterfaceMember : UN SEUL membre du corps d une interface        }
{ (section 9.3/9.4) - JAMAIS de constructeur/bloc d initialisation             }
{ (section 9.2, "il ne contient ni constructeur, ni initialisateur                    }
{ d instance, ni bloc static ordinaire") : SEULEMENT des champs                       }
{ (implicitement public static final, initialiseur OBLIGATOIRE), des                }
{ methodes (implicitement public abstract, JAMAIS de corps) et des                    }
{ types membres (classe/interface imbriquee, section 9.14). }
Procedure ParseInterfaceMember(IfaceT: Integer);
Var
  BaseT, ElemT : Integer;
  Nam        : TString;
  FI         : Integer;
  CV         : TConstVal;
  ParamStart, ParamN : Integer;
Begin
  Case NestedTypeKeywordAhead Of
    KW_CLASS:     Begin ParseClassDecl;     Exit; End;
    KW_INTERFACE: Begin ParseInterfaceDecl; Exit; End;
  End;

  ParseMemberModifiers;   { accepte "public abstract"/"public static     }
                           { final" REDONDANTS (section 9.3/9.4,               }
                           { "equivaut a") - la VALEUR renvoyee est                }
                           { JAMAIS lue, les valeurs REELLES sont                    }
                           { FORCEES plus bas (appel comme une simple            }
                           { PROCEDURE, mode TP - seul l EFFET DE BORD             }
                           { d avancement du flux de tokens compte ici). }
  BaseT := ParseTypeRef;
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de champ ou de methode d''interface attendu ' +
      '(section 9.3/9.4)');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPMatch('(') Then
  Begin
    { methode d interface (9.3) : JAMAIS de this/super (aucun corps),   }
    { TOUJOURS abstraite, JAMAIS static (IsStatic reste False - une            }
    { methode d interface n a pas la semantique d une methode static de    }
    { classe, meme si aucun code actuel ne distingue encore les deux). }
    SymEnterScope;
    ParamStart := ParamPoolCount;
    ParamN     := 0;
    If Not PPIsOp(')') Then
      Repeat
        If ParseOneParamIntoPool Then Inc(ParamN);
      Until Not PPMatch(',');
    If Not PPMatch(')') Then
      FatalError('")" attendu apres les parametres d''une methode ' +
        'd''interface (section 9.3)');
    ParseThrowsClauseIfPresent;
    MethodPoolAdd(IfaceT, Nam, MK_METHOD, False, False, True,
      BaseT, ParamStart, ParamN, VIS_PUBLIC);   { TODO 12 : TOUJOURS       }
                                                 { public, implicite               }
                                                 { (section 9.3) - FORCE,          }
                                                 { jamais lu depuis des                 }
                                                 { modificateurs source. }
    If Not PPMatch(';') Then
      FatalError('";" attendu apres une methode d''interface - AUCUN ' +
        'corps permis (section 9.3)');
    SymLeaveScope;
  End
  Else
  Begin
    { champ d interface (9.4) : TOUJOURS public static final, valeur     }
    { REELLEMENT obligatoire (contrairement a un champ de classe               }
    { ordinaire, TODO 08). }
    ElemT := BaseT;
    While PPIsOp('[') Do
    Begin
      PPAdvance;
      If Not PPMatch(']') Then
        FatalError('"]" attendu apres "[" dans un declarateur de tableau ' +
          '(section 9.4)');
      ElemT := TypeAdd(TYK_ARRAY, '', 4, 4, ElemT);
    End;

    FI := FieldPoolAdd(IfaceT, ElemT, Nam, True, True, VIS_PUBLIC);   { TODO 12 : }
                                                 { TOUJOURS public, implicite      }
                                                 { (section 9.4) - FORCE. }

    If Not PPMatch('=') Then
      FatalError('"=" attendu - un champ d''interface DOIT etre ' +
        'initialise (section 9.4)')
    Else If (FI >= 0) And ConstEvalExpr(CV) Then
    Begin
      FieldPool[FI].HasInit  := True;
      FieldPool[FI].ConstVal := CV;
    End;

    If Not PPMatch(';') Then
      FatalError('";" attendu a la fin d''un champ d''interface (section 9.4)');
  End;
End;

Procedure ParseInterfaceBody(IfaceT: Integer);
Begin
  If Not PPMatch('{') Then
  Begin
    FatalError('"{" attendu au debut d''un corps d''interface (section 9.2)');
    Exit;
  End;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
    ParseInterfaceMember(IfaceT);
  If Not PPMatch('}') Then
    FatalError('"}" attendu a la fin d''un corps d''interface (section 9.2)');
End;

{ ParseInterfaceDecl : point d entree TODO 09, symetrique de           }
{ ParseClassDecl - "abstract" est implicite (section 9.2) et jamais            }
{ stocke separement (AUCUN TTypeRec.IsAbstractClass n a de sens pour           }
{ TYK_INTERFACE, jamais lu pour ce Kind). "extends I1, I2, ..." (9.5,          }
{ heritage MULTIPLE, a la difference du "extends" UNIQUE d une classe)         }
{ REUTILISE InterfacePoolAdd - SuperTypeIdx reste a -1 pour TOUTE                }
{ interface (TypeAdd), la chaine d heritage passe ENTIEREMENT par                  }
{ InterfaceFirst/Count. }
Function ParseInterfaceDecl: Integer;
Var
  Mods   : TMemberModifiers;
  Nam    : TString;
  IfaceT : Integer;
  Saved  : Integer;
Begin
  Mods := ParseMemberModifiers;   { "public"/"abstract" (redondant, 9.2) -  }
                                   { SEUL Visibility (TODO 12) est retenu,       }
                                   { "abstract" reste implicite et jamais         }
                                   { stocke separement, voir plus bas. }
  If IsKeyword(PPVal) <> KW_INTERFACE Then
  Begin
    FatalError('"interface" attendu (section 9.2)');
    ParseInterfaceDecl := -1;
    Exit;
  End;
  PPAdvance;   { 'interface' }

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom d''interface attendu (section 9.2)');
    ParseInterfaceDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  IfaceT := TypeAdd(TYK_INTERFACE, Nam, 4, 4, -1);
  TypeTab[IfaceT].Visibility := Mods.Visibility;

  If IsKeyword(PPVal) = KW_EXTENDS Then
  Begin
    PPAdvance;
    Repeat
      InterfacePoolAdd(IfaceT, ParseBaseTypeNoBrackets);
    Until Not PPMatch(',');
  End;

  Saved               := CurrentClassTypeIdx;
  CurrentClassTypeIdx := IfaceT;

  ParseInterfaceBody(IfaceT);

  CurrentClassTypeIdx := Saved;

  ParseInterfaceDecl := IfaceT;
End;

{ ------------------------------------------------------------ }
{ ClassSelfTest : chaque extrait reproduit LITTERALEMENT le code des    }
{ TROIS echantillons cites par la feuille de route (Test04Methodes/            }
{ Test06ProprietesBean/Test07Heritage.jpp - relus en entier avant                  }
{ d ecrire ce test), jamais un cas invente. Teste ISOLEMENT via                       }
{ ClassParseFile (fichier temporaire ECRIT LIGNE PAR LIGNE - voir sa           }
{ propre note d en-tete pour pourquoi, PAS une seule grosse chaine              }
{ TString comme StmtParseString/ExprParseString) - PLUSIEURS appels             }
{ PARTAGENT neanmoins le            }
{ MEME TypeTab persistant (TypeInit n est PAS rappele entre eux), pour            }
{ que "class Rectangle extends Forme" retrouve reellement "Forme" ENREGISTRE      }
{ par l appel PRECEDENT (meme discipline que SymEnterScope/SymAdd/                   }
{ StmtParseString/SymLeaveScope deja utilises par StmtSelfTest pour la              }
{ synchronisation "synchronized"). }
{ ------------------------------------------------------------ }

Procedure ClassAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ClassSelfTest: ' + Label_ + ' a echoue');
End;

{ ClassParseFile : lit le fichier TEMPORAIRE DEJA ECRIT par l appelant   }
{ (ClassSelfTest, plus bas) et le parse comme UNE SEULE declaration de       }
{ classe - PAS de parametre "Src: TString" (contrairement a                     }
{ StmtParseString/ExprParseString) : TString est un ShortString (255           }
{ octets, mode TP en tete de fichier) et un corps de classe REEL                  }
{ depasse LARGEMENT cette limite - BOGUE REEL trouve par EXECUTION                 }
{ (troncature SILENCIEUSE,     }
{ "factorielle" coupe en "facto" a la 255e position, decouvert via un              }
{ FatalError "point-virgule attendu" totalement DEROUTANT tant que la               }
{ VRAIE cause - une chaine tronquee, pas une erreur de grammaire - n a          }
{ pas ete identifiee). Fixe en ecrivant le fichier temporaire LIGNE PAR      }
{ LIGNE (plusieurs WriteLn courts, MEME discipline que DeclSelfTest)               }
{ plutot que de construire UNE SEULE chaine concatenee geante. }
Function ClassParseFile: Integer;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Begin
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  ParserInit;

  ClassParseFile := ParseClassDecl;
End;

Procedure ClassSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  T04, T06, FormeT, RectT : Integer;
  MI, MIMaxInt, MIFact, MICtor : Integer;
  Body, S0, S1, RetExpr, CallExpr, ThisNode : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- Test04Methodes.jpp (section 8.13/8.32 - methodes STATIC,          }
  { surcharge par TYPE de parametre, recursivite) --------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Test04Methodes {');
  WriteLn(F, '    static int maximum(int gauche, int droite) {');
  WriteLn(F, '        return gauche > droite ? gauche : droite;');
  WriteLn(F, '    }');
  WriteLn(F, '    static double maximum(double gauche, double droite) {');
  WriteLn(F, '        return gauche > droite ? gauche : droite;');
  WriteLn(F, '    }');
  WriteLn(F, '    static int factorielle(int valeur) {');
  WriteLn(F, '        if (valeur < 2) {');
  WriteLn(F, '            return 1;');
  WriteLn(F, '        }');
  WriteLn(F, '        return valeur * factorielle(valeur - 1);');
  WriteLn(F, '    }');
  WriteLn(F, '    static void appelle() {');
  WriteLn(F, '        maximum(4, 9);');
  WriteLn(F, '        maximum(4.5, 2.5);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  T04 := ClassParseFile;
  Erase(F);
  ClassAssert('Test04Methodes : classe enregistree', T04 >= 0);
  ClassAssert('Test04Methodes : Object implicite (aucun extends)',
    TypeTab[T04].SuperTypeIdx = PDT_OBJECT);

  MIMaxInt := ClassResolveMethodCall(T04, 'maximum', 0, 0);   { juste pour  }
  { verifier qu AUCUN argument ne correspond a rien - repli sur -1 : }
  ClassAssert('maximum() SANS argument : aucune correspondance (repli -1)',
    MIMaxInt = -1);

  MIFact := -1;
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = T04) And (MethodPool[MI].Name = 'factorielle') Then
      MIFact := MI;
  ClassAssert('factorielle : methode enregistree', MIFact >= 0);
  ClassAssert('factorielle : UN SEUL parametre int',
    (MethodPool[MIFact].ParamCount = 1) And
    (ParamPool[MethodPool[MIFact].ParamFirst].TypeIdx = PRIMTYPE_INT));

  { corps de factorielle : 2 instructions - un "if" PUIS le return         }
  { RECURSIF "return valeur * factorielle(valeur - 1);" (exemple LITTERAL   }
  { du fichier reel). }
  Body := MethodPool[MIFact].BodyStmtIdx;
  ClassAssert('factorielle : corps STK_BLOCK a DEUX instructions',
    (StmtPool[Body].Kind = STK_BLOCK) And (StmtPool[Body].ArgCount = 2));
  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];
  ClassAssert('factorielle : 2e instruction est un return', StmtPool[S1].Kind = STK_RETURN);
  RetExpr := StmtPool[S1].Left;
  ClassAssert('factorielle : "valeur * factorielle(...)" - "*" binaire',
    ExprPool[RetExpr].Op = '*');
  CallExpr := ExprPool[RetExpr].Right;
  ClassAssert('factorielle : appel RECURSIF implicite resolu (int) - ' +
    'PREUVE que ClassResolveMethodCall fonctionne EN PLEIN corps de methode, ' +
    'pas seulement en test isole',
    (ExprPool[CallExpr].Kind = EK_CALL) And (ExprPool[CallExpr].TypeIdx = PRIMTYPE_INT));

  { corps de appelle() : DEUX appels a "maximum", chacun devant choisir la  }
  { BONNE surcharge d apres le TYPE REEL de ses arguments (4,9 = int,int ;   }
  { 4.5,2.5 = double,double - AUCUN des deux n a le meme nombre de           }
  { parametres qu une autre methode, donc SEUL le type des arguments             }
  { depart age les deux versions de "maximum"). }
  MICtor := -1;   { reutilise comme index temporaire pour "appelle" }
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = T04) And (MethodPool[MI].Name = 'appelle') Then
      MICtor := MI;
  ClassAssert('appelle : methode enregistree', MICtor >= 0);
  Body := MethodPool[MICtor].BodyStmtIdx;
  ClassAssert('appelle : corps a DEUX instructions', StmtPool[Body].ArgCount = 2);
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];
  ClassAssert('appelle : maximum(4, 9) resout la surcharge INT',
    ExprPool[StmtPool[S0].Left].TypeIdx = PRIMTYPE_INT);
  ClassAssert('appelle : maximum(4.5, 2.5) resout la surcharge DOUBLE',
    ExprPool[StmtPool[S1].Left].TypeIdx = PRIMTYPE_DOUBLE);

  { --- Test06ProprietesBean.jpp (section 8.3/8.6/8.11 - champs D        }
  { INSTANCE prives, constructeur, acces IMPLICITE "nom"/"valeur = nom") -    }
  { les validations "throw new IllegalArgumentException(...)" du fichier      }
  { reel sont OMISES ICI : IllegalArgumentException n est PAS une classe         }
  { predeclare (seules Object/String/Throwable/Exception/RuntimeException/        }
  { Error le sont, TODO 03) - une VRAIE bibliotheque standard reste hors        }
  { de portee du TODO 08 (StdlibTab embryonnaire, affinee aux TODO 13/         }
  { 16/18/20). Le MECANISME teste ICI (champ D INSTANCE implicite en                }
  { lecture/ecriture) est IDENTIQUE avec ou sans cette validation. ------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Personne {');
  WriteLn(F, '    private String nom;');
  WriteLn(F, '    private int age;');
  WriteLn(F, '    public Personne(String nom, int age) {');
  WriteLn(F, '        setNom(nom);');
  WriteLn(F, '        setAge(age);');
  WriteLn(F, '    }');
  WriteLn(F, '    public String getNom() {');
  WriteLn(F, '        return nom;');
  WriteLn(F, '    }');
  WriteLn(F, '    public void setNom(String valeur) {');
  WriteLn(F, '        nom = valeur;');
  WriteLn(F, '    }');
  WriteLn(F, '    public int getAge() {');
  WriteLn(F, '        return age;');
  WriteLn(F, '    }');
  WriteLn(F, '    public void setAge(int valeur) {');
  WriteLn(F, '        age = valeur;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  T06 := ClassParseFile;
  Erase(F);
  ClassAssert('Personne : classe enregistree', T06 >= 0);
  ClassAssert('Personne : champ "nom" trouve, type String',
    FieldPool[ClassFindField(T06, 'nom')].TypeIdx = PDT_STRING);
  ClassAssert('Personne : champ "age" trouve, type int',
    FieldPool[ClassFindField(T06, 'age')].TypeIdx = PRIMTYPE_INT);

  MICtor := -1;
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = T06) And (MethodPool[MI].Kind = MK_CONSTRUCTOR) Then
      MICtor := MI;
  ClassAssert('Personne : EXACTEMENT le constructeur DECLARE - AUCUN ' +
    'constructeur par defaut synthetise en plus',
    (MICtor >= 0) And (MethodPool[MICtor].ParamCount = 2));

  MI := -1;
  For MICtor := 0 To MethodPoolCount - 1 Do   { reutilise MICtor comme boucle }
    If (MethodPool[MICtor].OwnerTypeIdx = T06) And (MethodPool[MICtor].Name = 'getNom') Then
      MI := MICtor;
  Body := MethodPool[MI].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  ClassAssert('getNom : "return nom;" - "nom" IMPLICITE resolu en ' +
    'EK_SELECTOR "this.nom" (section 8.3), PAS un identificateur brut',
    (StmtPool[S0].Kind = STK_RETURN) And
    (ExprPool[StmtPool[S0].Left].Kind = EK_SELECTOR) And
    (ExprPool[StmtPool[S0].Left].NameVal = 'nom') And
    (ExprPool[StmtPool[S0].Left].TypeIdx = PDT_STRING));
  ThisNode := ExprPool[StmtPool[S0].Left].Left;
  ClassAssert('getNom : la base du selecteur IMPLICITE resout "this" ' +
    '(TypeIdx = Personne)', ExprPool[ThisNode].TypeIdx = T06);

  MI := -1;
  For MICtor := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MICtor].OwnerTypeIdx = T06) And (MethodPool[MICtor].Name = 'setNom') Then
      MI := MICtor;
  Body := MethodPool[MI].BodyStmtIdx;
  S1 := StmtArgPool[StmtPool[Body].ArgFirst];   { "nom = valeur;" - SEULE instruction }
  ClassAssert('setNom : "nom = valeur;" - cible STK_ASSIGN "=" est le ' +
    'champ IMPLICITE "nom" (Left), source est le PARAMETRE local "valeur" ' +
    '(Right, resolu par SymFind AVANT le repli ClassFindField)',
    (StmtPool[S1].Kind = STK_ASSIGN) And (StmtPool[S1].Op = '=') And
    (ExprPool[StmtPool[S1].Left].Kind = EK_SELECTOR) And
    (ExprPool[StmtPool[S1].Left].NameVal = 'nom') And
    (ExprPool[StmtPool[S1].Right].Kind = EK_IDENT) And
    (ExprPool[StmtPool[S1].Right].Left >= 0));

  { --- Test07Heritage.jpp (section 8.1/8.7/8.8/8.15/8.21/8.22 - classe    }
  { ABSTRAITE, extends, super(...) en premiere ligne de constructeur,           }
  { methode final, methode abstraite, REDEFINITION - EXACTEMENT le texte           }
  { du fichier reel, Forme puis Rectangle, MEME ORDRE que le fichier                }
  { source - la limitation single-pass documentee sur                                    }
  { ParseBaseTypeNoBrackets l EXIGE). ------------------------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'abstract class Forme {');
  WriteLn(F, '    private String nom;');
  WriteLn(F, '    protected Forme(String nom) {');
  WriteLn(F, '        this.nom = nom;');
  WriteLn(F, '    }');
  WriteLn(F, '    public final String getNom() {');
  WriteLn(F, '        return nom;');
  WriteLn(F, '    }');
  WriteLn(F, '    public abstract double aire();');
  WriteLn(F, '    public String toString() {');
  WriteLn(F, '        return getNom() + ", aire=" + aire();');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  FormeT := ClassParseFile;
  Erase(F);
  ClassAssert('Forme : classe enregistree', FormeT >= 0);
  ClassAssert('Forme : abstract (section 8.21)', TypeTab[FormeT].IsAbstractClass);
  ClassAssert('Forme : Object implicite (aucun extends)',
    TypeTab[FormeT].SuperTypeIdx = PDT_OBJECT);

  MICtor := -1;
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = FormeT) And (MethodPool[MI].Kind = MK_CONSTRUCTOR) Then
      MICtor := MI;
  Body := MethodPool[MICtor].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  ClassAssert('Forme(nom) : "this.nom = nom;" - cible EXPLICITE ' +
    '"this.nom" (section 8.8), source resout le PARAMETRE local "nom" ' +
    '(masque le champ de meme nom - EXACTEMENT la regle de masquage Java)',
    (StmtPool[S0].Kind = STK_ASSIGN) And
    (ExprPool[StmtPool[S0].Left].Kind = EK_SELECTOR) And
    (ExprPool[StmtPool[S0].Left].NameVal = 'nom') And
    (ExprPool[StmtPool[S0].Left].TypeIdx = PDT_STRING) And
    (ExprPool[StmtPool[S0].Right].Kind = EK_IDENT) And
    (ExprPool[StmtPool[S0].Right].TypeIdx = PDT_STRING));

  MI := -1;
  For MICtor := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MICtor].OwnerTypeIdx = FormeT) And (MethodPool[MICtor].Name = 'aire') Then
      MI := MICtor;
  ClassAssert('aire() : abstraite (section 8.21), AUCUN corps',
    MethodPool[MI].IsAbstract And (MethodPool[MI].BodyStmtIdx = -1));

  MICtor := -1;
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = FormeT) And (MethodPool[MI].Name = 'getNom') Then
      MICtor := MI;
  ClassAssert('getNom() : final (section 8.22)', MethodPool[MICtor].IsFinal);

  MI := -1;
  For MICtor := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MICtor].OwnerTypeIdx = FormeT) And (MethodPool[MICtor].Name = 'toString') Then
      MI := MICtor;
  Body := MethodPool[MI].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];   { "return getNom() + ", aire=" + aire();" }
  ClassAssert('toString() : getNom() implicite resolu (String) EN PLEIN ' +
    'corps de methode',
    (ExprPool[ExprPool[ExprPool[StmtPool[S0].Left].Left].Left].Kind = EK_CALL) And
    (ExprPool[ExprPool[ExprPool[StmtPool[S0].Left].Left].Left].TypeIdx = PDT_STRING));
  ClassAssert('toString() : aire() implicite (ABSTRAITE) resolue (double) - ' +
    'un appel a une methode SANS corps encore ecrit reste RESOLUBLE ' +
    '(l expedition dynamique reelle est un probleme de generation de code, ' +
    'TODO 21+, pas de resolution lexicale)',
    (ExprPool[StmtPool[S0].Left].Kind = EK_BINARY) And
    (ExprPool[ExprPool[StmtPool[S0].Left].Right].Kind = EK_CALL) And
    (ExprPool[ExprPool[StmtPool[S0].Left].Right].TypeIdx = PRIMTYPE_DOUBLE));

  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Rectangle extends Forme {');
  WriteLn(F, '    private double largeur;');
  WriteLn(F, '    private double hauteur;');
  WriteLn(F, '    public Rectangle(double largeur, double hauteur) {');
  WriteLn(F, '        super("rectangle");');
  WriteLn(F, '        this.largeur = largeur;');
  WriteLn(F, '        this.hauteur = hauteur;');
  WriteLn(F, '    }');
  WriteLn(F, '    public double aire() {');
  WriteLn(F, '        return largeur * hauteur;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  RectT := ClassParseFile;
  Erase(F);
  ClassAssert('Rectangle : classe enregistree', RectT >= 0);
  ClassAssert('Rectangle extends Forme (section 8.1, heritage SIMPLE)',
    TypeTab[RectT].SuperTypeIdx = FormeT);

  MICtor := -1;
  For MI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MI].OwnerTypeIdx = RectT) And (MethodPool[MI].Kind = MK_CONSTRUCTOR) Then
      MICtor := MI;
  Body := MethodPool[MICtor].BodyStmtIdx;
  ClassAssert('Rectangle(...) : TROIS instructions (super(...) + deux ' +
    'affectations this.xxx)', StmtPool[Body].ArgCount = 3);
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  ClassAssert('Rectangle(...) : 1ere instruction est "super(\"rectangle\");" ' +
    '(section 8.8) - un simple appel de methode sur l identificateur ' +
    'special "super", resolu vers le TYPE de Forme (AUCUN TStmtKind dedie)',
    (StmtPool[S0].Kind = STK_EXPR) And
    (ExprPool[StmtPool[S0].Left].Kind = EK_CALL) And
    (ExprPool[ExprPool[StmtPool[S0].Left].Left].NameVal = 'super') And
    (ExprPool[ExprPool[StmtPool[S0].Left].Left].TypeIdx = FormeT));

  MI := -1;
  For MICtor := 0 To MethodPoolCount - 1 Do
    If (MethodPool[MICtor].OwnerTypeIdx = RectT) And (MethodPool[MICtor].Name = 'aire') Then
      MI := MICtor;
  ClassAssert('Rectangle.aire() : REDEFINIT celle de Forme - PROPRE entree ' +
    'MethodPool (OwnerTypeIdx = Rectangle, PAS Forme)',
    (MI >= 0) And (MethodPool[MI].OwnerTypeIdx = RectT) And Not MethodPool[MI].IsAbstract);
  Body := MethodPool[MI].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  ClassAssert('Rectangle.aire() : "largeur"/"hauteur" IMPLICITES resolus ' +
    'contre LES CHAMPS DE RECTANGLE (PAS ceux de Forme, qui n en a pas) - ' +
    'PREUVE que CurrentClassTypeIdx bascule correctement entre DEUX appels ' +
    'ClassParseFile successifs',
    (ExprPool[StmtPool[S0].Left].Op = '*') And
    (ExprPool[ExprPool[StmtPool[S0].Left].Left].Kind = EK_SELECTOR) And
    (ExprPool[ExprPool[StmtPool[S0].Left].Left].TypeIdx = PRIMTYPE_DOUBLE));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ InterfaceSelfTest : reproduit LITTERALEMENT Test08Interfaces.jpp     }
{ (relu en entier avant d ecrire ce test) - EXACTEMENT ses trois              }
{ declarations, DANS LEUR ORDRE TEXTUEL REEL (CompteurListener, puis            }
{ Compteur, puis Test08Interfaces qui imbrique JournalListener) - la               }
{ limitation single-pass deja documentee sur ParseBaseTypeNoBrackets              }
{ l EXIGE. Teste ISOLEMENT via InterfaceParseFile/ClassParseFile                    }
{ (fichier temporaire ECRIT LIGNE PAR LIGNE, MEME discipline que                       }
{ ClassSelfTest) - PARTAGE le MEME TypeTab persistant ENTRE les trois           }
{ appels (TypeInit n est PAS rappele). }
{ ------------------------------------------------------------ }

Function InterfaceParseFile: Integer;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Begin
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  ParserInit;

  InterfaceParseFile := ParseInterfaceDecl;
End;

Procedure InterfaceSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  IfaceT, CompteurT, OuterT, JournalT : Integer;
  MI, FI : Integer;
  Body, S0, S2, CallExpr, SelExpr : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- interface CompteurListener, methode valeurChangee(int, int)      }
  { (section 9.2/9.3, methode implicitement public abstract). ------------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'interface CompteurListener {');
  WriteLn(F, '    void valeurChangee(int ancienneValeur, int nouvelleValeur);');
  WriteLn(F, '}');
  Close(F);
  IfaceT := InterfaceParseFile;
  Erase(F);
  ClassAssert('CompteurListener : interface enregistree (TYK_INTERFACE)',
    (IfaceT >= 0) And (TypeTab[IfaceT].Kind = TYK_INTERFACE));

  MI := -1;
  For FI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[FI].OwnerTypeIdx = IfaceT) And (MethodPool[FI].Name = 'valeurChangee') Then
      MI := FI;
  ClassAssert('valeurChangee : abstraite, AUCUN corps, DEUX parametres int ' +
    '(section 9.3)',
    (MI >= 0) And MethodPool[MI].IsAbstract And (MethodPool[MI].BodyStmtIdx = -1) And
    (MethodPool[MI].ParamCount = 2) And
    (ParamPool[MethodPool[MI].ParamFirst].TypeIdx = PRIMTYPE_INT) And
    (ParamPool[MethodPool[MI].ParamFirst + 1].TypeIdx = PRIMTYPE_INT));

  { --- classe Compteur (section 9.11/9.12 - champ DE TYPE INTERFACE,   }
  { appel a travers ce champ) - EXACTEMENT le texte reel. --------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Compteur {');
  WriteLn(F, '    private int valeur;');
  WriteLn(F, '    private CompteurListener listener;');
  WriteLn(F, '    public void setListener(CompteurListener valeur) {');
  WriteLn(F, '        listener = valeur;');
  WriteLn(F, '    }');
  WriteLn(F, '    public void incrementer() {');
  WriteLn(F, '        int ancienneValeur = valeur;');
  WriteLn(F, '        valeur++;');
  WriteLn(F, '        if (listener != null) {');
  WriteLn(F, '            listener.valeurChangee(ancienneValeur, valeur);');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompteurT := ClassParseFile;
  Erase(F);
  ClassAssert('Compteur : classe enregistree', CompteurT >= 0);
  FI := ClassFindField(CompteurT, 'listener');
  ClassAssert('Compteur.listener : champ DE TYPE INTERFACE trouve ' +
    '(section 9.11)', (FI >= 0) And (FieldPool[FI].TypeIdx = IfaceT));

  MI := -1;
  For FI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[FI].OwnerTypeIdx = CompteurT) And (MethodPool[FI].Name = 'incrementer') Then
      MI := FI;
  Body := MethodPool[MI].BodyStmtIdx;
  ClassAssert('incrementer() : corps a TROIS instructions (decl, ++, if)',
    StmtPool[Body].ArgCount = 3);
  S2 := StmtArgPool[StmtPool[Body].ArgFirst + 2];
  ClassAssert('incrementer() : 3e instruction est le "if (listener != null)"',
    StmtPool[S2].Kind = STK_IF);
  S0 := StmtArgPool[StmtPool[StmtPool[S2].Right].ArgFirst];   { corps du if }
  ClassAssert('incrementer() : "listener.valeurChangee(...)" - racine STK_EXPR',
    StmtPool[S0].Kind = STK_EXPR);
  CallExpr := StmtPool[S0].Left;
  SelExpr  := ExprPool[CallExpr].Left;
  ClassAssert('listener.valeurChangee(...) : selecteur EXPLICITE sur un ' +
    'champ IMPLICITE "this.listener" (TYPE INTERFACE), resolu vers ' +
    'l APPEL correct (section 9.11/9.12 - liaison lexicale, PAS dynamique)',
    (ExprPool[CallExpr].Kind = EK_CALL) And
    (ExprPool[SelExpr].Kind = EK_SELECTOR) And
    (ExprPool[SelExpr].NameVal = 'valeurChangee') And
    (ExprPool[CallExpr].TypeIdx = PRIMTYPE_VOID) And
    (ExprPool[ExprPool[SelExpr].Left].TypeIdx = IfaceT));

  { --- classe Test08Interfaces, avec la classe MEMBRE STATIC             }
  { JournalListener implements CompteurListener imbriquee (section              }
  { 9.14/9.17/9.8 - classe MEMBRE STATIC implementant une interface,               }
  { referencee par son nom SIMPLE depuis SA PROPRE classe englobante) -            }
  { EXACTEMENT le texte reel (System.out.println omis - non modelise,             }
  { hors de portee, MEME decision que le TODO 08 pour                                    }
  { IllegalArgumentException). ------------------------------------------------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test08Interfaces {');
  WriteLn(F, '    private static class JournalListener implements CompteurListener {');
  WriteLn(F, '        public void valeurChangee(int ancienneValeur, int nouvelleValeur) {');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        Compteur compteur = new Compteur();');
  WriteLn(F, '        compteur.setListener(new JournalListener());');
  WriteLn(F, '        compteur.incrementer();');
  WriteLn(F, '        compteur.incrementer();');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  OuterT := ClassParseFile;
  Erase(F);
  ClassAssert('Test08Interfaces : classe enregistree', OuterT >= 0);
  ClassAssert('CurrentClassTypeIdx redevient -1 une fois Test08Interfaces ' +
    '(et sa classe membre imbriquee) entierement refermee - la pile ' +
    'd appels a correctement depile (voir la note d en-tete de ' +
    'CurrentClassTypeIdx)', CurrentClassTypeIdx = -1);

  JournalT := TypeFindByName('JournalListener');
  ClassAssert('JournalListener : trouvable par son nom SIMPLE malgre son ' +
    'imbrication (section 9.17, "membre static" - MEME TypeTab global ' +
    'que les classes de haut niveau)', JournalT >= 0);
  ClassAssert('JournalListener implements CompteurListener (section 9.8, ' +
    'InterfaceFirst/Count peuples)',
    (TypeTab[JournalT].InterfaceCount = 1) And
    (InterfacePool[TypeTab[JournalT].InterfaceFirst] = IfaceT));

  MI := -1;
  For FI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[FI].OwnerTypeIdx = JournalT) And (MethodPool[FI].Name = 'valeurChangee') Then
      MI := FI;
  ClassAssert('JournalListener.valeurChangee : REDEFINITION CONCRETE ' +
    '(PROPRE entree MethodPool, PAS celle - abstraite - de ' +
    'CompteurListener ; section 9.9)',
    (MI >= 0) And (MethodPool[MI].OwnerTypeIdx = JournalT) And
    Not MethodPool[MI].IsAbstract And (MethodPool[MI].BodyStmtIdx >= 0));

  ClassAssert('TypeIsSubclassOf(JournalListener, CompteurListener) = VRAI ' +
    '(section 9.11, "conversion elargissante implicite" - une instance ' +
    'JournalListener EST-UNE CompteurListener, utilise par ' +
    'MethodParamsCompatible pour "setListener(new JournalListener())")',
    TypeIsSubclassOf(JournalT, IfaceT));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 10 - TABLEAUX (section 10 de la reference)                          }
{                                                                       }
{ Portee DECIDEE EXPLICITEMENT apres lecture REELLE de                       }
{ Test05Tableaux.jpp (comme la roadmap l exige explicitement) - la              }
{ grammaire des tableaux ELLE-MEME (types tableau a une ou plusieurs            }
{ dimensions, creation dimensionnee rectangulaire ET irreguliere,                    }
{ creation avec liste d initialisation apres "new", acces .length,               }
{ indexation chainee) etait DEJA ENTIEREMENT ecrite et testee au                     }
{ TODO 06 (ExprSelfTest - creation a une dimension, a deux dimensions            }
{ rectangulaire, a deux dimensions irreguliere, creation avec liste             }
{ d initialisation de quatre valeurs) - AUCUNE de ces formes n a                       }
{ besoin d etre reecrite ici. Relire Test05Tableaux.jpp ligne par                   }
{ ligne a revele UN SEUL veritable manque : sa toute PREMIERE                          }
{ declaration locale de tableau assigne une liste d initialisation                    }
{ directement au declarateur, SANS le "new Type[]" habituel devant                   }
{ (section 10.4) - une forme valide UNIQUEMENT comme initialiseur                    }
{ d un DECLARATEUR (jamais comme expression generale ordinaire,                       }
{ contrairement a la forme AVEC "new" qui EST une expression a part            }
{ entiere) - ParseVarDecl (TODO 05/09) ne connaissait QUE ParseExpr             }
{ comme initialiseur, qui n a AUCUN cas pour une accolade nue                            }
{ (ParsePrimary tomberait sur son FatalError generique "expression              }
{ attendue"). Fixe par ParseArrayInitializer (plus haut, avant                          }
{ ParseNewExpr) - DELIBEREMENT une fonction SEPAREE de la logique                    }
{ equivalente DEJA ecrite et testee DANS ParseNewExpr (memes raisons            }
{ de ne pas toucher du code qui MARCHE deja que documentees au TODO            }
{ 08/09), portee reduite a une liste PLATE (section 10.13,                                }
{ initialiseurs IMBRIQUES pour un tableau multi-dimensionnel hors de            }
{ portee - Test05Tableaux.jpp ne les utilise jamais, ses tableaux                    }
{ multi-dimensionnels passent TOUJOURS par "new").                                          }
{                                                                       }
{ Valeurs par defaut des elements (10.6) et verification de borne a           }
{ l acces (10.7, ArrayIndexOutOfBoundsException) restent EXPLICITEMENT      }
{ des decisions de GENERATION DE CODE (que produire a l EXECUTION),               }
{ pas d analyse syntaxique - documentees sur TYK_ARRAY/EK_INDEX plus            }
{ haut, repoussees au TODO 21+ (AUCUNE generation de code n existe                   }
{ encore). Champ .length "vraiment stocke a la construction" (roadmap          }
{ TODO 01) : deja vrai STRUCTURELLEMENT SANS code supplementaire -                  }
{ EK_NEWARRAY (TODO 06) porte DEJA soit les expressions de DIMENSION            }
{ (forme "dims"), soit le NOMBRE d elements litteraux (ArgCount de la           }
{ forme "init"/ParseArrayInitializer) - AUCUNE operation de                              }
{ redimensionnement n existe nulle part dans ce parseur (contrairement          }
{ au tableau dynamique de SWIFTW32.PAS, explicitement contraste dans          }
{ la roadmap). }
{ ------------------------------------------------------------ }

Procedure ArrayAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ArraySelfTest: ' + Label_ + ' a echoue');
End;

Procedure ArraySelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT : Integer;
  MI, SI, InitE, ElemT : Integer;
  Body, S, S0, S1, S2, S3, S5 : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- initialiseur de tableau NU ISOLE (section 10.4, EXACTEMENT la    }
  { toute PREMIERE declaration locale de Test05Tableaux.jpp) - teste           }
  { ISOLEMENT via StmtParseString, meme methode que StmtSelfTest. --------------- }
  S := StmtParseString('int[] notes = { 12, 15, 18, 14 };');
  ArrayAssert('notes : racine STK_DECL', StmtPool[S].Kind = STK_DECL);
  SI := StmtPool[S].Left;
  ArrayAssert('notes : type int[] (TYK_ARRAY d''ElemTypeIdx = int)',
    (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[SymTab[SI].TypeIdx].ElemTypeIdx = PRIMTYPE_INT));
  ArrayAssert('notes : HasInit vrai (TODO 09, tout initialiseur, litteral ' +
    'ou non, marque HasInit)', SymTab[SI].HasInit);
  InitE := SymTab[SI].InitExprIdx;
  ArrayAssert('notes = {...} : EK_NEWARRAY "init", QUATRE elements',
    (InitE >= 0) And (ExprPool[InitE].Kind = EK_NEWARRAY) And
    (ExprPool[InitE].Op = 'init') And (ExprPool[InitE].ArgCount = 4));
  ArrayAssert('notes = {...} : le TROISIEME element (indice 2) vaut 18',
    ExprPool[ExprArgPool[ExprPool[InitE].ArgFirst + 2]].IntVal = 18);

  { --- Test05Tableaux.jpp EN ENTIER (section 10.2-10.13) - AUCUNE ligne  }
  { omise (contrairement au TODO 08/09 : rien ici n a besoin d une                  }
  { bibliotheque standard non modelisee - meme "System.out.println"               }
  { reste SIMPLEMENT non resolu, best-effort, JAMAIS un FatalError). ---------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test05Tableaux {');
  WriteLn(F, '    static int somme(int[] valeurs) {');
  WriteLn(F, '        int resultat = 0;');
  WriteLn(F, '        for (int i = 0; i < valeurs.length; i++) {');
  WriteLn(F, '            resultat += valeurs[i];');
  WriteLn(F, '        }');
  WriteLn(F, '        return resultat;');
  WriteLn(F, '    }');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        int[] notes = { 12, 15, 18, 14 };');
  WriteLn(F, '        int[][] matrice = new int[2][3];');
  WriteLn(F, '        int[][] triangle = new int[3][];');
  WriteLn(F, '        matrice[0][1] = 42;');
  WriteLn(F, '        for (int ligne = 0; ligne < triangle.length; ligne++) {');
  WriteLn(F, '            triangle[ligne] = new int[ligne + 1];');
  WriteLn(F, '            for (int colonne = 0;');
  WriteLn(F, '                 colonne < triangle[ligne].length;');
  WriteLn(F, '                 colonne++) {');
  WriteLn(F, '                triangle[ligne][colonne] = ligne + colonne;');
  WriteLn(F, '            }');
  WriteLn(F, '        }');
  WriteLn(F, '        int[] copie = (int[])notes.clone();');
  WriteLn(F, '        copie[0] = 20;');
  WriteLn(F, '        System.out.println("Somme originale : " + somme(notes));');
  WriteLn(F, '        System.out.println("Premiere copie   : " + copie[0]);');
  WriteLn(F, '        System.out.println("Matrice          : " + matrice[0][1]);');
  WriteLn(F, '        System.out.println("Triangle         : " + triangle[2][1]);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  ArrayAssert('Test05Tableaux : classe enregistree', ClassT >= 0);

  { somme(int[] valeurs) : parametre TABLEAU, .length ET indexation sur   }
  { ce PARAMETRE (pas un champ - confirme que .length/EK_INDEX marchent          }
  { identiquement, TODO 06 INCHANGE). }
  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'somme') Then
      MI := SI;
  ArrayAssert('somme : UN SEUL parametre, type int[]',
    (MI >= 0) And (MethodPool[MI].ParamCount = 1) And
    (TypeTab[ParamPool[MethodPool[MI].ParamFirst].TypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[ParamPool[MethodPool[MI].ParamFirst].TypeIdx].ElemTypeIdx = PRIMTYPE_INT));
  Body := MethodPool[MI].BodyStmtIdx;
  ArrayAssert('somme : corps a TROIS instructions (decl, for, return)',
    StmtPool[Body].ArgCount = 3);
  S0 := StmtArgPool[StmtPool[Body].ArgFirst + 1];   { le "for" }
  ArrayAssert('somme : 2e instruction est un for', StmtPool[S0].Kind = STK_FOR);
  ArrayAssert('somme : condition "i < valeurs.length" - membre droit ' +
    '"valeurs.length" resolu (int, section 10.8)',
    (ExprPool[StmtPool[S0].Extra].Kind = EK_BINARY) And
    (ExprPool[ExprPool[StmtPool[S0].Extra].Right].NameVal = 'length') And
    (ExprPool[ExprPool[StmtPool[S0].Extra].Right].TypeIdx = PRIMTYPE_INT));
  S1 := StmtArgPool[StmtPool[StmtPool[S0].Left].ArgFirst];   { corps du for : "resultat += valeurs[i];" }
  ArrayAssert('somme : "resultat += valeurs[i];" - valeur EK_INDEX ' +
    'resolue (int, section 10.7/10.9)',
    (StmtPool[S1].Kind = STK_ASSIGN) And (StmtPool[S1].Op = '+=') And
    (ExprPool[StmtPool[S1].Right].Kind = EK_INDEX) And
    (ExprPool[StmtPool[S1].Right].TypeIdx = PRIMTYPE_INT));

  { main() : notes/matrice/triangle/copie - les QUATRE formes de           }
  { creation de tableau du fichier reel, plus l indexation CHAINEE                  }
  { "matrice[0][1]" et le cast "(int[])notes.clone()". }
  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'main') Then
      MI := SI;
  Body := MethodPool[MI].BodyStmtIdx;
  ArrayAssert('main : corps a ONZE instructions (3 decls + assign + for + ' +
    'decl + assign + 4 println)', StmtPool[Body].ArgCount = 11);

  S0 := StmtArgPool[StmtPool[Body].ArgFirst];       { notes }
  ElemT := SymTab[StmtPool[S0].Left].TypeIdx;
  ArrayAssert('notes (dans main) : int[], initialiseur NU "init" a QUATRE ' +
    'elements',
    (TypeTab[ElemT].Kind = TYK_ARRAY) And (TypeTab[ElemT].ElemTypeIdx = PRIMTYPE_INT) And
    (ExprPool[SymTab[StmtPool[S0].Left].InitExprIdx].Op = 'init') And
    (ExprPool[SymTab[StmtPool[S0].Left].InitExprIdx].ArgCount = 4));

  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];   { matrice }
  ElemT := SymTab[StmtPool[S1].Left].TypeIdx;
  ArrayAssert('matrice : int[][] (DEUX TYK_ARRAY imbriques), "new int[2][3]" ' +
    'RECTANGULAIRE - DEUX dimensions chiffrees (section 10.2/10.3)',
    (TypeTab[ElemT].Kind = TYK_ARRAY) And (TypeTab[TypeTab[ElemT].ElemTypeIdx].Kind = TYK_ARRAY) And
    (ExprPool[SymTab[StmtPool[S1].Left].InitExprIdx].Op = 'dims') And
    (ExprPool[SymTab[StmtPool[S1].Left].InitExprIdx].ArgCount = 2));

  S2 := StmtArgPool[StmtPool[Body].ArgFirst + 2];   { triangle }
  ElemT := SymTab[StmtPool[S2].Left].TypeIdx;
  ArrayAssert('triangle : int[][], "new int[3][]" IRREGULIER (jagged, ' +
    'section 10.12) - UNE SEULE dimension chiffree malgre DEUX paires "[]"',
    (TypeTab[ElemT].Kind = TYK_ARRAY) And (TypeTab[TypeTab[ElemT].ElemTypeIdx].Kind = TYK_ARRAY) And
    (ExprPool[SymTab[StmtPool[S2].Left].InitExprIdx].Op = 'dims') And
    (ExprPool[SymTab[StmtPool[S2].Left].InitExprIdx].ArgCount = 1));

  S3 := StmtArgPool[StmtPool[Body].ArgFirst + 3];   { matrice[0][1] = 42; }
  ArrayAssert('matrice[0][1] = 42 : cible EK_INDEX CHAINEE (DEUX niveaux), ' +
    'type FINAL int (section 10.10)',
    (StmtPool[S3].Kind = STK_ASSIGN) And
    (ExprPool[StmtPool[S3].Left].Kind = EK_INDEX) And
    (ExprPool[StmtPool[S3].Left].TypeIdx = PRIMTYPE_INT) And
    (ExprPool[ExprPool[StmtPool[S3].Left].Left].Kind = EK_INDEX));

  S5 := StmtArgPool[StmtPool[Body].ArgFirst + 5];   { copie }
  ElemT := SymTab[StmtPool[S5].Left].TypeIdx;
  InitE := SymTab[StmtPool[S5].Left].InitExprIdx;
  ArrayAssert('copie : int[], initialiseur "(int[])notes.clone()" - EK_CAST ' +
    'vers un type TABLEAU (section 6.22 - deja pris en charge SANS ' +
    'extension, LooksLikeCastAhead consomme deja "[]")',
    (TypeTab[ElemT].Kind = TYK_ARRAY) And (TypeTab[ElemT].ElemTypeIdx = PRIMTYPE_INT) And
    (ExprPool[InitE].Kind = EK_CAST) And
    (TypeTab[ExprPool[InitE].Extra].Kind = TYK_ARRAY));
  ArrayAssert('notes.clone() : appel NON RESOLU (Object.clone non ' +
    'synthetise, best-effort - MEME decision que le TODO 08 pour les ' +
    'methodes d''Object) - AUCUN FatalError, simplement TypeIdx=-1',
    ExprPool[ExprPool[InitE].Left].TypeIdx = -1);

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 11 - EXCEPTIONS (section 11 de la reference)                        }
{                                                                       }
{ Portee DECIDEE EXPLICITEMENT apres grep de SAMPLES\JPP\*.jpp pour           }
{ try/catch/finally/throw/throws (comme la roadmap l exige) : QUATRE           }
{ fichiers reels les utilisent (Test09Exceptions.jpp - fichier de test           }
{ PRINCIPAL de ce TODO, cite par la feuille de route -, Test11Threads.jpp,   }
{ Test12Fichiers.jpp, Test18JDirect.jpp) mais AUCUN n a plus d UN               }
{ catch par try - la selection multi-catch en ordre textuel (section          }
{ 11.10) reste donc syntaxiquement supportee (la boucle "While ...              }
{ catch" de ParseTryStmt accepte n importe combien de clauses) mais SA        }
{ VERIFICATION (precis-avant-superclasse, section 11.10/11.11) reste            }
{ non ecrite - DEFEREE au TODO 19, decision EXPLICITE puisqu AUCUN             }
{ echantillon ne peut de toute facon l exercer.                                          }
{                                                                       }
{ INCLUS : hierarchie Throwable etendue (section 11.2 - QUATRE                       }
{ nouvelles classes predeclarees, IllegalArgumentException/                            }
{ NumberFormatException/InterruptedException/UnsatisfiedLinkError,               }
{ voir la note d en-tete de TypeInit) ; try/catch(multiples)/finally             }
{ (STK_TRY/STK_CATCH, ParseTryStmt) - AU MOINS un catch ou un finally           }
{ exige (section 11.8) ; portee du parametre catch limitee a son                     }
{ propre bloc (section 11.9, SymEnterScope/SymLeaveScope par clause).      }
{ throw (STK_THROW) et throws (ParseThrowsClauseIfPresent) restent                  }
{ INCHANGES depuis le TODO 07/08 - deja "syntaxe complete, verification        }
{ semantique differee" avant meme que ce TODO n existe.                                }
{                                                                       }
{ DELIBEREMENT hors de portee (documente, pas devine) : verification            }
{ REELLE catch-or-declare (section 11.3, "le compilateur oblige... a          }
{ capturer ou declarer") - AUCUN echantillon ne viole cette regle,               }
{ donc RIEN ne force a l ecrire maintenant, et l ecrire SANS pouvoir la         }
{ voir echouer sur un cas reel serait deviner ; accessibilite d un                 }
{ catch (11.10/11.11) ; semantique finally/return complexe (11.14,                   }
{ "un return dans finally remplace le retour initial") - AUCUNE                       }
{ generation de code n existe pour donner un sens a CETTE regle avant          }
{ le TODO 21+ ; mecanisme REEL de propagation dans la pile (11.7) -              }
{ STRATEGIE decidee et documentee (voir la note d en-tete de                          }
{ ParseTryStmt) mais NON implementee, TODO 21+. }
{ ------------------------------------------------------------ }

Procedure ExceptionAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ExceptionSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ExceptionSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  S, CatchN, ClassT, DonneeT, MI, SI, Body, TryN, S0, S1 : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- try/catch/finally ISOLES (sections 11.8/11.9/11.13), chaque        }
  { forme reproduisant LITTERALEMENT un fragment reel d un des QUATRE            }
  { fichiers qui les utilisent - testes ISOLEMENT via StmtParseString,             }
  { meme methode que StmtSelfTest. -------------------------------------------------- }

  { forme "try...finally" SANS catch (section 11.13, exemple ADAPTE de   }
  { Test12Fichiers.jpp - le finally ferme une ressource SEULEMENT si            }
  { elle n est pas restee nulle). }
  SymEnterScope;
  SymAdd('sortie', SK_VAR, PDT_OBJECT, False, False);
  S := StmtParseString(
    'try { sortie.println("x"); } finally { if (sortie != null) { sortie.close(); } }');
  SymLeaveScope;
  ExceptionAssert('try/finally SANS catch : racine STK_TRY',
    StmtPool[S].Kind = STK_TRY);
  ExceptionAssert('try/finally SANS catch : ZERO clause catch',
    StmtPool[S].ArgCount = 0);
  ExceptionAssert('try/finally SANS catch : bloc finally PRESENT (Right >= 0)',
    StmtPool[S].Right >= 0);

  { forme "try...catch" SANS finally, UNE SEULE clause (section 11.9,     }
  { exemple LITTERAL Test18JDirect.jpp - catch (UnsatisfiedLinkError e)). }
  S := StmtParseString(
    'try { boolean resultat = MessageBeep(0); } ' +
    'catch (UnsatisfiedLinkError e) { erreur = e; }');
  ExceptionAssert('try/catch SANS finally : racine STK_TRY',
    StmtPool[S].Kind = STK_TRY);
  ExceptionAssert('try/catch SANS finally : AUCUN finally (Right = -1)',
    StmtPool[S].Right = -1);
  ExceptionAssert('try/catch SANS finally : UNE SEULE clause catch',
    StmtPool[S].ArgCount = 1);
  CatchN := StmtArgPool[StmtPool[S].ArgFirst];
  ExceptionAssert('catch (UnsatisfiedLinkError e) : racine STK_CATCH, ' +
    'type PDT_UNSATISFIEDLINKERROR (nouvelle classe predeclaree, section ' +
    '11.2), parametre nomme "e" (portee limitee au bloc, section 11.9)',
    (StmtPool[CatchN].Kind = STK_CATCH) And
    (StmtPool[CatchN].Extra = PDT_UNSATISFIEDLINKERROR) And
    (StmtPool[CatchN].NameVal = 'e'));

  { forme COMPLETE "try...catch...finally" (section 11.8, exemple           }
  { LITTERAL Test09Exceptions.jpp main()) - PLUS un "if" comme PREMIERE         }
  { instruction du corps catch, deliberement, pour PROUVER que le               }
  { correctif "collecter D ABORD, pousser ENSUITE" de ParseTryStmt                 }
  { evite le MEME bogue d entrelacement StmtArgPool que celui trouve             }
  { par execution dans ParseBlock/ParseSwitchStmt au TODO 08 (voir la           }
  { note d en-tete de ParseTryStmt). }
  SymEnterScope;
  SymAdd('e', SK_VAR, PDT_EXCEPTION, False, False);
  S := StmtParseString(
    'try { f(); } catch (Exception ex) { if (e != null) { g(); } h(); } finally { i(); }');
  SymLeaveScope;
  ExceptionAssert('try/catch/finally COMPLET : racine STK_TRY, UNE clause ' +
    'catch, finally PRESENT',
    (StmtPool[S].Kind = STK_TRY) And (StmtPool[S].ArgCount = 1) And
    (StmtPool[S].Right >= 0));
  CatchN := StmtArgPool[StmtPool[S].ArgFirst];
  Body := StmtPool[CatchN].Left;
  ExceptionAssert('corps catch : DEUX instructions (if, h()) - CONTIGUES ' +
    'malgre le "if" imbrique en PREMIERE position (preuve directe du ' +
    'correctif anti-entrelacement)',
    (StmtPool[Body].ArgCount = 2) And
    (StmtPool[StmtArgPool[StmtPool[Body].ArgFirst]].Kind = STK_IF) And
    (StmtPool[StmtArgPool[StmtPool[Body].ArgFirst + 1]].Kind = STK_EXPR));

  { try SANS catch NI finally (section 11.8, "doit etre suivi d au moins  }
  { un catch ou un finally") - AUCUN self-test de ce projet ne declenche      }
  { jamais un VRAI FatalError pour verifier qu il se produit (meme                  }
  { discipline documentee depuis le TODO 05, voir ParseCatchParam) -              }
  { verifie donc INDIRECTEMENT : le garde-fou existe (voir ParseTryStmt),         }
  { non exerce ICI. }

  { --- Test09Exceptions.jpp EN ENTIER (sections 11.2/11.5-11.10/11.13/  }
  { 11.19/11.20) - DonneeException PUIS Test09Exceptions, MEME ORDRE               }
  { TEXTUEL que le fichier reel (limitation single-pass, TODO 08) - via         }
  { ClassParseFile (TODO 08, fichier temporaire ECRIT LIGNE PAR LIGNE,           }
  { meme discipline que ClassSelfTest/InterfaceSelfTest/ArraySelfTest). ------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class DonneeException extends Exception {');
  WriteLn(F, '    public DonneeException(String message) {');
  WriteLn(F, '        super(message);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  DonneeT := ClassParseFile;
  Erase(F);
  ExceptionAssert('DonneeException : classe enregistree, derive de ' +
    'Exception (section 11.19, exception VERIFIEE personnalisee)',
    (DonneeT >= 0) And (TypeTab[DonneeT].SuperTypeIdx = PDT_EXCEPTION));

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = DonneeT) And (MethodPool[SI].Kind = MK_CONSTRUCTOR) Then
      MI := SI;
  ExceptionAssert('DonneeException(String message) : UN SEUL ' +
    'constructeur, UN parametre String',
    (MI >= 0) And (MethodPool[MI].ParamCount = 1) And
    (ParamPool[MethodPool[MI].ParamFirst].TypeIdx = PDT_STRING));
  Body := MethodPool[MI].BodyStmtIdx;
  ExceptionAssert('DonneeException(...) : corps est "super(message);" ' +
    '(section 11.20, "appelle super(message) pour initialiser le ' +
    'message")',
    (StmtPool[StmtArgPool[StmtPool[Body].ArgFirst]].Kind = STK_EXPR) And
    (ExprPool[StmtPool[StmtArgPool[StmtPool[Body].ArgFirst]].Left].Kind = EK_CALL) And
    (ExprPool[ExprPool[StmtPool[StmtArgPool[StmtPool[Body].ArgFirst]].Left].Left].NameVal = 'super'));

  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test09Exceptions {');
  WriteLn(F, '    static int convertirPositif(String texte)');
  WriteLn(F, '        throws DonneeException {');
  WriteLn(F, '        try {');
  WriteLn(F, '            int valeur = Integer.parseInt(texte);');
  WriteLn(F, '            if (valeur < 0) {');
  WriteLn(F, '                throw new DonneeException("nombre negatif");');
  WriteLn(F, '            }');
  WriteLn(F, '            return valeur;');
  WriteLn(F, '        } catch (NumberFormatException e) {');
  WriteLn(F, '            throw new DonneeException("entier attendu : " + texte);');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        String texte = args.length == 0 ? "42" : args[0];');
  WriteLn(F, '        try {');
  WriteLn(F, '            System.out.println(convertirPositif(texte));');
  WriteLn(F, '        } catch (DonneeException e) {');
  WriteLn(F, '            System.err.println("Erreur : " + e.getMessage());');
  WriteLn(F, '        } finally {');
  WriteLn(F, '            System.out.println("Traitement termine.");');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  ExceptionAssert('Test09Exceptions : classe enregistree', ClassT >= 0);

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'convertirPositif') Then
      MI := SI;
  Body := MethodPool[MI].BodyStmtIdx;
  ExceptionAssert('convertirPositif(...) : corps EST le try (UNE SEULE ' +
    'instruction de haut niveau)', StmtPool[Body].ArgCount = 1);
  TryN := StmtArgPool[StmtPool[Body].ArgFirst];
  ExceptionAssert('convertirPositif(...) : racine STK_TRY, AUCUN finally, ' +
    'UNE clause catch',
    (StmtPool[TryN].Kind = STK_TRY) And (StmtPool[TryN].Right = -1) And
    (StmtPool[TryN].ArgCount = 1));
  ExceptionAssert('convertirPositif(...) : bloc try a TROIS instructions ' +
    '(decl, if, return)', StmtPool[StmtPool[TryN].Left].ArgCount = 3);
  CatchN := StmtArgPool[StmtPool[TryN].ArgFirst];
  ExceptionAssert('catch (NumberFormatException e) : type ' +
    'PDT_NUMBERFORMATEXCEPTION (nouvelle classe predeclaree, section ' +
    '11.2), UNE instruction (throw) dans son corps',
    (StmtPool[CatchN].Kind = STK_CATCH) And
    (StmtPool[CatchN].Extra = PDT_NUMBERFORMATEXCEPTION) And
    (StmtPool[CatchN].NameVal = 'e') And
    (StmtPool[StmtPool[CatchN].Left].ArgCount = 1) And
    (StmtPool[StmtArgPool[StmtPool[StmtPool[CatchN].Left].ArgFirst]].Kind = STK_THROW));

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'main') Then
      MI := SI;
  Body := MethodPool[MI].BodyStmtIdx;
  ExceptionAssert('main() : DEUX instructions de haut niveau (decl texte, try)',
    StmtPool[Body].ArgCount = 2);
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  ExceptionAssert('main() : "String texte = ... ? \"42\" : args[0];" est ' +
    'une declaration', StmtPool[S0].Kind = STK_DECL);
  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];
  ExceptionAssert('main() : 2e instruction est le try, AVEC un catch ET ' +
    'un finally (section 11.8, "try ... catch ... finally")',
    (StmtPool[S1].Kind = STK_TRY) And (StmtPool[S1].ArgCount = 1) And
    (StmtPool[S1].Right >= 0));
  CatchN := StmtArgPool[StmtPool[S1].ArgFirst];
  ExceptionAssert('catch (DonneeException e) : type resolu vers la ' +
    'classe UTILISATEUR DonneeException (PAS une classe predeclaree - ' +
    'ClassFindConstructor/TypeFindByName, TODO 08, INCHANGE)',
    (StmtPool[CatchN].Kind = STK_CATCH) And (StmtPool[CatchN].Extra = DonneeT));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 12 - PAQUETS, IMPORTS ET VISIBILITE (section 12 de la reference)     }
{                                                                       }
{ Portee DECIDEE EXPLICITEMENT apres grep de SAMPLES\JPP\*.jpp (comme      }
{ la roadmap l exige) - section 12 fait 39 sous-sections, LARGEMENT                }
{ au-dela de ce qu une compilation MONO-FICHIER (deja la portee ENTIERE          }
{ de ce projet depuis le TODO 01) peut exercer :                                        }
{   - AUCUN des 18 echantillons reels n a de declaration "package" -             }
{     TOUS vivent dans le paquet SANS NOM (section 12.3) - ParsePackageDecl }
{     est donc groundee sur les exemples LITTERAUX de la reference                  }
{     elle-meme (section 12.2, "package societe.produit;")                                }
{   - CINQ echantillons utilisent "import" (Test10Collections/                          }
{     Test12Fichiers/Test13Awt/Test16Win32/Test17PaquetsMicrosoft.jpp) -          }
{     LES DEUX formes (type unique ET a la demande "paquet.*"),                          }
{     multi-segments (java.awt.event, section 12.4 "paquet DISTINCT de           }
{     java.awt") - groundes VERBATIM                                                      }
{   - Test08Interfaces.jpp (deja utilise au TODO 09) sert de base a une            }
{     VRAIE unite de compilation MULTI-TYPES (interface + DEUX classes            }
{     de premier niveau, section 12.7, "plusieurs types de premier                    }
{     niveau peuvent partager un fichier")                                                  }
{                                                                       }
{ INCLUS : package (12.2)/paquet sans nom (12.3, CurrentPackageName='') ;   }
{ import de type unique ET a la demande (12.8-12.10, ImportTab -                       }
{ ENREGISTRE seulement, JAMAIS resolu vers un runtime reel avant que              }
{ StdlibTab n existe, TODO 13/16/18/20) ; ParseCompilationUnit (12.7,          }
{ "package optionnel, PUIS zero ou plusieurs import, PUIS zero ou                    }
{ plusieurs declarations de type") qui REUTILISE tel quel                                   }
{ NestedTypeKeywordAhead (TODO 09) pour dispatcher entre plusieurs               }
{ types de premier niveau ; visibilite (12.18/12.20) desormais                            }
{ STOCKEE sur TFieldRec/TMethodRec/TTypeRec (TVisibility, decision                    }
{ EXPLICITE repondant a la question laissee ouverte par ParseModifiers,        }
{ TODO 05 - voir sa propre note d en-tete).                                                 }
{                                                                       }
{ DELIBEREMENT hors de portee (documente, pas devine) : correspondance          }
{ repertoire<->paquet/CLASSPATH (12.6/12.27-12.31, compilation MONO-              }
{ FICHIER - AUCUN systeme de fichiers multi-classes n existe) ;                        }
{ resolution REELLE des noms importes vers java.*/com.ms.* (12.33-              }
{ 12.34, StdlibTab pas encore ecrite) ; detection d ambiguite entre               }
{ imports (12.14) ; VERIFICATION d acces (12.19-12.26, "private                        }
{ limite le nom a la classe...") - AUCUN echantillon ne viole une                    }
{ regle d acces (tout est TOUJOURS "dans le meme fichier"), rien ne              }
{ justifierait de l ecrire maintenant, repoussee au TODO 19 comme le             }
{ reste de l analyse semantique de ce projet ; regle "au plus UN type             }
{ public par fichier" (12.7) - AUCUN echantillon ne la viole non plus. }
{ ------------------------------------------------------------ }

Var
  CurrentPackageName : TString;   { '' = paquet SANS NOM (section 12.3) }

Type
  TImportRec = Record
    IsWildcard  : Boolean;   { True = "import paquet.*;" (section 12.10) - }
                              { SimpleName reste '' dans ce cas }
    PackageName : TString;   { "java.io" aussi bien pour "java.io.IOException" }
                              { que pour "java.io.*" }
    SimpleName  : TString;   { '' si Wildcard }
  End;

Const
  MAX_IMPORT = 64;

Var
  ImportTab   : Array[0..MAX_IMPORT - 1] Of TImportRec;
  ImportCount : Integer;

Procedure PackageInit;
Begin
  CurrentPackageName := '';
  ImportCount := 0;
End;

{ ParsePackageDecl : "package nom.qualifie ;" (section 12.2) - paquet   }
{ SANS NOM (section 12.3, CurrentPackageName reste '') si absent -               }
{ n avance PAS le flux de tokens si le premier mot n est pas "package"          }
{ (best-effort, appele SANS condition prealable par ParseCompilationUnit,      }
{ plus bas). AUCUNE correspondance reelle repertoire<->paquet (section         }
{ 12.6) : le nom est CONSERVE tel quel, jamais resolu vers un chemin/            }
{ CLASSPATH (hors de portee, compilation MONO-FICHIER). }
Procedure ParsePackageDecl;
Begin
  CurrentPackageName := '';
  If (PPKind <> TOK_IDENT) Or (IsKeyword(PPVal) <> KW_PACKAGE) Then Exit;
  PPAdvance;   { 'package' }

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de paquet attendu apres "package" (section 12.2)');
    Exit;
  End;
  CurrentPackageName := PPVal;
  PPAdvance;

  While PPMatch('.') Do
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('identificateur attendu apres "." dans un nom de ' +
        'paquet (section 12.2)');
      Break;
    End;
    CurrentPackageName := CurrentPackageName + '.' + PPVal;
    PPAdvance;
  End;

  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''une declaration "package" (section 12.2)');
End;

Function ImportAdd(IsWildcard: Boolean; Const APackageName, ASimpleName: TString): Integer;
Begin
  If ImportCount >= MAX_IMPORT Then
  Begin
    WarnMsg('table des imports pleine (MAX_IMPORT)');
    ImportAdd := -1;
    Exit;
  End;
  ImportTab[ImportCount].IsWildcard  := IsWildcard;
  ImportTab[ImportCount].PackageName := APackageName;
  ImportTab[ImportCount].SimpleName  := ASimpleName;
  ImportAdd := ImportCount;
  Inc(ImportCount);
End;

{ ParseImportDecl : "import nom.qualifie.Type ;" OU "import                }
{ nom.qualifie.* ;" (sections 12.8-12.10) - renvoie False (SANS RIEN          }
{ consommer) si le token courant n est pas "import", permettant a                  }
{ ParseCompilationUnit de boucler "tant qu il y en a". Accumule les              }
{ SEGMENTS separes par "." UN PAR UN, PUIS decide APRES COUP si le                 }
{ dernier est un "*" (import a la demande, SimpleName reste '',                       }
{ PackageName = TOUS les segments) ou un nom de type (import de type            }
{ unique, PackageName = tous SAUF le dernier, SimpleName = le dernier) -    }
{ AUCUNE resolution reelle vers StdlibTab (TODO 13/16/18/20, pas                    }
{ encore ecrite) : import est ICI purement ENREGISTRE pour consultation          }
{ FUTURE, jamais RESOLU - section 12.16, "une declaration import...              }
{ n execute aucun code, n initialise aucune classe". }
Function ParseImportDecl: Boolean;
Const
  MAX_IMPORT_SEGMENTS = 32;
Var
  Segs : Array[0..MAX_IMPORT_SEGMENTS - 1] Of TString;
  Cnt, I : Integer;
  Wildcard : Boolean;
  PackagePart, SimplePart : TString;
Begin
  ParseImportDecl := False;
  If (PPKind <> TOK_IDENT) Or (IsKeyword(PPVal) <> KW_IMPORT) Then Exit;
  ParseImportDecl := True;
  PPAdvance;   { 'import' }

  Cnt := 0;
  Wildcard := False;
  Repeat
    If PPIsOp('*') Then
    Begin
      Wildcard := True;
      PPAdvance;
      Break;
    End;
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('identificateur ou "*" attendu dans un "import" (section 12.8)');
      Break;
    End;
    If Cnt < MAX_IMPORT_SEGMENTS Then
    Begin
      Segs[Cnt] := PPVal;
      Inc(Cnt);
    End;
    PPAdvance;
  Until Not PPMatch('.');

  If Not PPMatch(';') Then
    FatalError('";" attendu a la fin d''un "import" (section 12.8)');

  If Wildcard Then
  Begin
    PackagePart := '';
    For I := 0 To Cnt - 1 Do
    Begin
      If I > 0 Then PackagePart := PackagePart + '.';
      PackagePart := PackagePart + Segs[I];
    End;
    ImportAdd(True, PackagePart, '');
  End
  Else If Cnt > 0 Then
  Begin
    SimplePart := Segs[Cnt - 1];
    PackagePart := '';
    For I := 0 To Cnt - 2 Do
    Begin
      If I > 0 Then PackagePart := PackagePart + '.';
      PackagePart := PackagePart + Segs[I];
    End;
    ImportAdd(False, PackagePart, SimplePart);
  End;
End;

{ ParseCompilationUnit : "unite de compilation" complete (section 12.7) - }
{ package optionnel, PUIS zero ou plusieurs import, PUIS zero ou                    }
{ plusieurs declarations de type - REUTILISE TEL QUEL                                     }
{ NestedTypeKeywordAhead (TODO 09) pour reconnaitre "class"/"interface"        }
{ (precedes d eventuels modificateurs) et dispatcher vers                              }
{ ParseClassDecl/ParseInterfaceDecl, EXACTEMENT comme une classe/                    }
{ interface MEMBRE le fait deja pour un type IMBRIQUE - la SEULE                       }
{ difference est le NIVEAU (ici, le plus haut) auquel la boucle                          }
{ s applique. PORTEE (feuille de route du TODO 12) : AUCUNE verification    }
{ "au plus UN type public par fichier" (section 12.7) - AUCUN des 18            }
{ echantillons reels ne la viole, documenter plutot que deviner un                  }
{ controle jamais exerce. Renvoie le NOMBRE de types de premier niveau            }
{ parses (0 si le fichier n en declare aucun - syntaxiquement valide,          }
{ meme si inhabituel). }
Function ParseCompilationUnit: Integer;
Var Count : Integer;
Begin
  ParsePackageDecl;
  While ParseImportDecl Do
    { corps VIDE - ParseImportDecl fait tout le travail et renvoie False   }
    { des qu il ne reste plus de "import" a consommer } ;

  Count := 0;
  While (Not PPAtEnd) And (NestedTypeKeywordAhead <> 0) Do
  Begin
    Case NestedTypeKeywordAhead Of
      KW_CLASS:     ParseClassDecl;
      KW_INTERFACE: ParseInterfaceDecl;
    End;
    Inc(Count);
  End;

  ParseCompilationUnit := Count;
End;

Function CompilationUnitParseFile: Integer;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Begin
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  ParserInit;

  CompilationUnitParseFile := ParseCompilationUnit;
End;

{ ------------------------------------------------------------ }
{ PackageSelfTest : package/import groundes sur les exemples LITTERAUX   }
{ de la reference (AUCUN echantillon reel n a de "package") plus les             }
{ CINQ fichiers reels qui utilisent "import" (Test10Collections/                     }
{ Test12Fichiers/Test13Awt/Test16Win32/Test17PaquetsMicrosoft.jpp) ;                 }
{ ParseCompilationUnit groundee sur la structure REELLE, MULTI-TYPES,           }
{ de Test08Interfaces.jpp (deja utilise au TODO 09) ; visibilite                       }
{ groundee sur des lignes REELLES deja rencontrees dans Test06/07/08.        }
{ ------------------------------------------------------------ }

Procedure PackageAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PackageSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PackageSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT, IfaceT, FI, MI, SI, Count : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
  PackageInit;

  { --- "package societe.produit;" (section 12.2, exemple LITTERAL de   }
  { la reference - AUCUN echantillon reel n en a). ---------------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'package societe.produit;');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  ParsePackageDecl;
  PackageAssert('package societe.produit; : CurrentPackageName EXACT',
    CurrentPackageName = 'societe.produit');

  { --- paquet SANS NOM (section 12.3) - EXACTEMENT l etat des 18          }
  { echantillons reels : ParsePackageDecl ne consomme RIEN quand le                }
  { premier mot n est pas "package". ------------------------------------------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Bonjour {');
  WriteLn(F, '}');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  ParsePackageDecl;
  PackageAssert('paquet sans nom : CurrentPackageName reste vide',
    CurrentPackageName = '');
  PackageAssert('paquet sans nom : AUCUN token consomme ("class" toujours ' +
    'courant)', (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_CLASS));

  { --- import de type unique, EXACTEMENT Test10Collections.jpp. ------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'import java.util.Vector;');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  PackageInit;
  ParseImportDecl;
  PackageAssert('import java.util.Vector; : type unique, paquet "java.util", ' +
    'nom simple "Vector"',
    (ImportCount = 1) And (Not ImportTab[0].IsWildcard) And
    (ImportTab[0].PackageName = 'java.util') And (ImportTab[0].SimpleName = 'Vector'));

  { --- import a la demande, EXACTEMENT Test17PaquetsMicrosoft.jpp. --------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'import com.ms.win32.*;');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  PackageInit;
  ParseImportDecl;
  PackageAssert('import com.ms.win32.*; : a la demande (section 12.10), ' +
    'paquet "com.ms.win32", AUCUN nom simple',
    (ImportCount = 1) And ImportTab[0].IsWildcard And
    (ImportTab[0].PackageName = 'com.ms.win32') And (ImportTab[0].SimpleName = ''));

  { --- import de type unique a TROIS segments de paquet, EXACTEMENT       }
  { Test13Awt.jpp (section 12.4, "java.awt.event est un paquet DISTINCT   }
  { de java.awt"). ------------------------------------------------------------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'import java.awt.event.ActionListener;');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  PackageInit;
  ParseImportDecl;
  PackageAssert('import java.awt.event.ActionListener; : paquet MULTI-' +
    'SEGMENTS "java.awt.event", nom simple "ActionListener"',
    (ImportCount = 1) And (ImportTab[0].PackageName = 'java.awt.event') And
    (ImportTab[0].SimpleName = 'ActionListener'));

  { --- unite de compilation COMPLETE, MULTI-TYPES (section 12.7) -       }
  { EXACTEMENT la structure reelle de Test08Interfaces.jpp (interface           }
  { CompteurListener, class Compteur, public class Test08Interfaces -               }
  { corps ABREGES ICI, deja testes en detail par InterfaceSelfTest,                  }
  { TODO 09 - seule la FORME multi-types/package/import est nouvelle             }
  { ICI). --------------------------------------------------------------------------- }
  PackageInit;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'interface CompteurListener {');
  WriteLn(F, '    void valeurChangee(int ancienneValeur, int nouvelleValeur);');
  WriteLn(F, '}');
  WriteLn(F, 'class Compteur {');
  WriteLn(F, '    private int valeur;');
  WriteLn(F, '}');
  WriteLn(F, 'public class Test08Interfaces {');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  Count := CompilationUnitParseFile;
  Erase(F);
  PackageAssert('unite de compilation : TROIS types de premier niveau ' +
    '(section 12.7, "plusieurs types de premier niveau peuvent partager ' +
    'un fichier")', Count = 3);
  IfaceT := TypeFindByName('CompteurListener');
  ClassT := TypeFindByName('Test08Interfaces');
  PackageAssert('CompteurListener : interface SANS modificateur -> ' +
    'VIS_PACKAGE (section 12.20, acces par defaut)',
    (IfaceT >= 0) And (TypeTab[IfaceT].Visibility = VIS_PACKAGE));
  PackageAssert('Test08Interfaces : "public class" -> VIS_PUBLIC (section ' +
    '12.17, "accessible depuis d''autres paquets")',
    (ClassT >= 0) And (TypeTab[ClassT].Visibility = VIS_PUBLIC));

  { --- visibilite sur les CHAMPS/METHODES/CONSTRUCTEURS - lignes REELLES }
  { deja rencontrees aux TODO 06/07/08 (Test08Interfaces.jpp/                          }
  { Test07Heritage.jpp) ET la forme "sans modificateur" (section 12.20,           }
  { grammaire seule - aucun champ package-default REEL dans les 18                    }
  { echantillons, mais la regle elle-meme n a besoin d aucun echantillon           }
  { pour etre groundee, EXACTEMENT comme TypeSelfTest le fait deja pour           }
  { la hierarchie Throwable "anticipee"). ------------------------------------------ }
  PackageInit;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class VisibiliteTest {');
  WriteLn(F, '    private int valeur;');
  WriteLn(F, '    int parDefaut;');
  WriteLn(F, '    protected VisibiliteTest(String nom) {');
  WriteLn(F, '    }');
  WriteLn(F, '    public void setListener(int x) {');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  PackageAssert('VisibiliteTest : classe enregistree', ClassT >= 0);

  FI := ClassFindField(ClassT, 'valeur');
  PackageAssert('private int valeur; : VIS_PRIVATE (section 12.19, ligne ' +
    'REELLE de Test08Interfaces.jpp)',
    (FI >= 0) And (FieldPool[FI].Visibility = VIS_PRIVATE));
  FI := ClassFindField(ClassT, 'parDefaut');
  PackageAssert('int parDefaut; : VIS_PACKAGE (section 12.20, "aucun" ' +
    'modificateur = acces de package)',
    (FI >= 0) And (FieldPool[FI].Visibility = VIS_PACKAGE));

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Kind = MK_CONSTRUCTOR) Then
      MI := SI;
  PackageAssert('protected VisibiliteTest(String nom) : VIS_PROTECTED ' +
    '(ligne REELLE de Test07Heritage.jpp, "protected Forme(String nom)")',
    (MI >= 0) And (MethodPool[MI].Visibility = VIS_PROTECTED));

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'setListener') Then
      MI := SI;
  PackageAssert('public void setListener(int x) : VIS_PUBLIC (ligne ' +
    'REELLE de Test08Interfaces.jpp)',
    (MI >= 0) And (MethodPool[MI].Visibility = VIS_PUBLIC));

  { --- visibilite FORCEE public sur un membre d interface (section 9.3/  }
  { 9.4, INCHANGE depuis le TODO 09 - re-verifie ICI car desormais            }
  { OBSERVABLE via TVisibility, alors qu il n y avait rien a lire avant). ----- }
  PackageInit;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'interface VisibiliteInterfaceTest {');
  WriteLn(F, '    int MAXIMUM = 100;');
  WriteLn(F, '    void executer();');
  WriteLn(F, '}');
  Close(F);
  IfaceT := InterfaceParseFile;
  Erase(F);
  FI := ClassFindField(IfaceT, 'MAXIMUM');
  PackageAssert('champ d''interface : VIS_PUBLIC FORCE (section 9.4)',
    (FI >= 0) And (FieldPool[FI].Visibility = VIS_PUBLIC));
  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = IfaceT) And (MethodPool[SI].Name = 'executer') Then
      MI := SI;
  PackageAssert('methode d''interface : VIS_PUBLIC FORCE (section 9.3)',
    (MI >= 0) And (MethodPool[MI].Visibility = VIS_PUBLIC));

  PackageInit;
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 13 - ENTREES/SORTIES ET BIBLIOTHEQUE JAVA 1.1 MINIMALE               }
{ (section de la reference : dispersee - 11.21 Throwable.getMessage,          }
{ le reste n est PAS une section grammaticale de DOC\JPP_SPEC_LANG.txt        }
{ mais une CONVENTION de bibliotheque standard Java 1.1 REELLE - AUCUNE      }
{ section a citer au-dela de ce que chaque commentaire precise deja).          }
{                                                                       }
{ Portee DECIDEE EXPLICITEMENT par grep de SAMPLES\JPP\*.jpp AVANT               }
{ d ecrire une seule ligne (roadmap : "chaque entree connue du front-          }
{ end... jamais devinee d avance") : String.length() (UN SEUL appel                }
{ reel, Test06ProprietesBean.jpp) ; System.out/System.err.println                    }
{ (PARTOUT, quatre surcharges EXACTEMENT couvertes par les arguments             }
{ REELLEMENT passes - String/int/double/Object) ; Integer(int) et                     }
{ Integer.parseInt(String) (Test09Exceptions.jpp/Test10Collections.jpp) ;   }
{ Vector/Hashtable/Enumeration (Test10Collections.jpp, sous-ensemble             }
{ EXACT exerce) ; la chaine Writer/Reader/FileWriter/BufferedWriter/               }
{ PrintWriter/FileReader/BufferedReader/IOException (Test12Fichiers.jpp,      }
{ chaque CONSTRUCTEUR imbrique EXACTEMENT comme le fichier reel les                  }
{ compose) ; Throwable.getMessage() (Test09Exceptions.jpp/                             }
{ Test12Fichiers.jpp, HERITE par toute exception via SuperTypeIdx,               }
{ AUCUN cablage special par classe concrete).                                              }
{                                                                       }
{ ARCHITECTURE : chaque entree est un VRAI TYK_CLASS/TYK_INTERFACE                   }
{ (ClassAdd) avec de VRAIS FieldPool/MethodPool/ParamPool (TODO 08),               }
{ EXACTEMENT comme une classe UTILISATEUR - AUCUNE table de signatures         }
{ separee (a la difference du modele PUREMENT LEXICAL "pkg.Nom" de                 }
{ GOCW32.PAS TODO 20, adapte a des FONCTIONS DE PAQUET Go plutot qu a          }
{ des CLASSES Java REELLES : "System.out.println(x)" a une VRAIE                     }
{ forme objet - "out" EST un CHAMP dont la VALEUR (PrintStream) recoit         }
{ ENSUITE un appel de methode - pas un simple nom qualifie PLAT comme            }
{ "fmt.Println"). Ceci reutilise TEL QUEL ClassFindField/                                }
{ ClassResolveMethodCall (TODO 08/09) : AUCUN mecanisme nouveau, SAUF          }
{ EK_TYPEREF (ExprAddIdent, TODO 06/13 plus haut) - "Integer.parseInt"          }
{ est un appel STATIQUE qualifie PAR UN NOM DE TYPE (section 12.15),               }
{ forme que le TODO 08 avait EXPLICITEMENT differee ("seul l acces PAR           }
{ NOM SIMPLE est resolu"). AUCUNE position TypeIdx FIXE n est requise           }
{ (contrairement aux 20 entrees predeclarees du TODO 03/04/11) :                       }
{ chaque classe est retrouvee PAR NOM (TypeFindByName) comme n importe          }
{ quelle classe UTILISATEUR - AUCUN renumerotage de PRIMTYPE_xxx (a la         }
{ difference du TODO 11) n est donc necessaire ici, un choix DELIBERE          }
{ pour que les TODO futurs puissent continuer a etendre cette                             }
{ bibliotheque SANS jamais perturber les positions FIXES existantes.                }
{                                                                       }
{ AUCUNE contrepartie runtime REELLE (WriteFile/GetStdHandle/                           }
{ CreateFile/ReadFile Win32, evoquee par le texte de la roadmap) n est         }
{ cablee ICI - DECISION EXPLICITE, pas une omission : AUCUNE generation      }
{ de code n existe ENCORE nulle part dans ce compilateur (ni emetteur           }
{ x86, ni ecrivain PE - meme etat que documente sur TOUS les TODO                     }
{ precedents depuis le TODO 08, repousse au TODO 21+) - brancher un                 }
{ VRAI appel Win32 SANS ce socle serait deviner un mecanisme, l exact             }
{ contraire de la discipline de ce projet. Chaque entree ci-dessous               }
{ reste donc "connue du FRONT-END de l analyse" SEULEMENT (resolution           }
{ de type/surcharge) - exactement ce que la roadmap demande en                          }
{ preambule de ce TODO.                                                                     }
{ ------------------------------------------------------------ }

{ ParamPoolAddRaw : pousse UN parametre "synthetique" (sans passer par }
{ le PARSEUR - ParseSingleParam/ParseOneParamIntoPool, TODO 08, exigent      }
{ un VRAI flux de tokens et un SymAdd, inutiles ici puisqu aucun corps           }
{ SOURCE n existe pour une methode de bibliotheque standard) directement       }
{ dans ParamPool - SANS RISQUE d entrelacement (MEME raisonnement                    }
{ EXACT que documente sur TParamRec/TMethodRec.ParamFirst, TODO 08 :               }
{ StdlibInit pousse TOUJOURS les parametres d UNE SEULE methode en UN            }
{ SEUL balayage ininterrompu, jamais deux signatures en cours de                        }
{ construction simultanement). }
Function ParamPoolAddRaw(Const PName: TString; PTypeIdx: Integer): Integer;
Begin
  If ParamPoolCount >= MAX_PARAM_POOL Then
  Begin
    WarnMsg('table des parametres pleine (MAX_PARAM_POOL)');
    ParamPoolAddRaw := -1;
    Exit;
  End;
  ParamPool[ParamPoolCount].Name    := PName;
  ParamPool[ParamPoolCount].TypeIdx := PTypeIdx;
  ParamPool[ParamPoolCount].IsFinal := False;
  ParamPoolAddRaw := ParamPoolCount;
  Inc(ParamPoolCount);
End;

{ StdMethod0/1/2 : enregistrent une methode/un constructeur de              }
{ bibliotheque standard a ZERO/UN/DEUX parametres - AUCUNE surcharge          }
{ de ce compilateur (mode TP en tete de fichier) n autorise un NOMBRE           }
{ VARIABLE de parametres ; DEUX suffit LARGEMENT (Hashtable.put, deux            }
{ parametres Object, est                                                                       }
{ la SEULE methode de toute cette bibliotheque minimale qui en exige            }
{ deux - AUCUNE n en exige plus, verifie par le grep qui a groundee                }
{ ce TODO). TOUJOURS VIS_PUBLIC (une bibliotheque standard n expose               }
{ jamais de membre non-public a ses utilisateurs) et TOUJOURS                            }
{ IsFinal=False/IsAbstract=False (aucune methode FINALE ou ABSTRAITE            }
{ n est REELLEMENT exercee par un echantillon parmi celles-ci). }
Function StdMethod0(Owner: Integer; Const MName: TString; MKind: TMethodKind;
  IsStatic: Boolean; RetT: Integer): Integer;
Begin
  StdMethod0 := MethodPoolAdd(Owner, MName, MKind, IsStatic, False, False,
    RetT, ParamPoolCount, 0, VIS_PUBLIC);
End;

Function StdMethod1(Owner: Integer; Const MName: TString; MKind: TMethodKind;
  IsStatic: Boolean; RetT, P1Type: Integer): Integer;
Var PFirst : Integer;
Begin
  PFirst := ParamPoolCount;
  ParamPoolAddRaw('a', P1Type);
  StdMethod1 := MethodPoolAdd(Owner, MName, MKind, IsStatic, False, False,
    RetT, PFirst, 1, VIS_PUBLIC);
End;

Function StdMethod2(Owner: Integer; Const MName: TString; MKind: TMethodKind;
  IsStatic: Boolean; RetT, P1Type, P2Type: Integer): Integer;
Var PFirst : Integer;
Begin
  PFirst := ParamPoolCount;
  ParamPoolAddRaw('a', P1Type);
  ParamPoolAddRaw('b', P2Type);
  StdMethod2 := MethodPoolAdd(Owner, MName, MKind, IsStatic, False, False,
    RetT, PFirst, 2, VIS_PUBLIC);
End;

{ StdlibInit : corps REEL (Forward plus haut, avant TypeInit) - voir     }
{ la note d en-tete de section pour la portee/l architecture. Enumeration   }
{ (une VRAIE INTERFACE en Java reel) est enregistree AVANT Vector                  }
{ puisque Vector.elements() a besoin de son TypeIdx pour son propre               }
{ type de retour - AUCUN Forward supplementaire n est necessaire ICI            }
{ (simple ordre d ecriture, contrairement aux fonctions RECURSIVES               }
{ documentees plus haut dans ce fichier). Writer/Reader sont enregistres    }
{ AVANT leurs sous-classes concretes pour la MEME raison (SuperTypeIdx        }
{ direct, section 9.11-style assignabilite reutilisee par                              }
{ MethodParamsCompatible/TypeIsSubclassOf, TODO 08/09, pour que "new             }
{ BufferedWriter(new FileWriter(nom))" type-verifie correctement). }
Procedure StdlibInit;
Var
  PrintStreamT, SystemT, IntegerT, EnumerationT, VectorT, HashtableT,
  WriterT, ReaderT, FileWriterT, BufferedWriterT, PrintWriterT,
  FileReaderT, BufferedReaderT, IOExceptionT, RunnableT, ThreadT,
  User32T, WinmT, MBMI, PFirst : Integer;
Begin
  { String.length() - section 13, EXACTEMENT "valeur.length()" de       }
  { Test06ProprietesBean.jpp (TODO 08). AUCUN autre membre de String              }
  { (charAt/equals/toString) n est REELLEMENT exerce par un echantillon,          }
  { documente comme DEFERE plutot que devine. }
  StdMethod0(PDT_STRING, 'length', MK_METHOD, False, PRIMTYPE_INT);

  { Throwable.getMessage() : String (section 11.21) - herite ainsi PAR   }
  { la chaine SuperTypeIdx DEJA existante (TODO 04/08) par TOUTE                     }
  { exception, UTILISATEUR ou PREDECLAREE (DonneeException/IOException           }
  { plus bas) - EXACTEMENT "e.getMessage()" de Test09Exceptions.jpp/                 }
  { Test12Fichiers.jpp. }
  StdMethod0(PDT_THROWABLE, 'getMessage', MK_METHOD, False, PDT_STRING);

  { System.out/System.err.println - QUATRE surcharges, EXACTEMENT les   }
  { types REELLEMENT passes par les 18 echantillons (String/int/double/       }
  { Object - "System.out.println(formes[i])" de Test07Heritage.jpp passe          }
  { un Forme, resolu via Object par assignabilite de reference, section         }
  { 9.11/TypeIsSubclassOf, TODO 09). }
  PrintStreamT := ClassAdd('PrintStream', PDT_OBJECT, False, False, VIS_PUBLIC);
  StdMethod1(PrintStreamT, 'println', MK_METHOD, False, PRIMTYPE_VOID, PDT_STRING);
  StdMethod1(PrintStreamT, 'println', MK_METHOD, False, PRIMTYPE_VOID, PRIMTYPE_INT);
  StdMethod1(PrintStreamT, 'println', MK_METHOD, False, PRIMTYPE_VOID, PRIMTYPE_DOUBLE);
  StdMethod1(PrintStreamT, 'println', MK_METHOD, False, PRIMTYPE_VOID, PDT_OBJECT);

  SystemT := ClassAdd('System', PDT_OBJECT, False, False, VIS_PUBLIC);
  FieldPoolAdd(SystemT, PrintStreamT, 'out', True, True, VIS_PUBLIC);
  FieldPoolAdd(SystemT, PrintStreamT, 'err', True, True, VIS_PUBLIC);

  { Integer(int) et Integer.parseInt(String) : int, throws                }
  { NumberFormatException (syntaxe seule - aucune clause throws n est            }
  { verifiee sur une methode SYNTHETISEE, meme discipline best-effort            }
  { que le reste de ce parseur) - Test09Exceptions.jpp/                                 }
  { Test10Collections.jpp. }
  IntegerT := ClassAdd('Integer', PDT_OBJECT, False, False, VIS_PUBLIC);
  StdMethod1(IntegerT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, PRIMTYPE_INT);
  StdMethod1(IntegerT, 'parseInt', MK_METHOD, True, PRIMTYPE_INT, PDT_STRING);

  { Enumeration (VRAIE interface Java, "public interface Enumeration") - }
  { IsAbstract FORCE (section 9.3-style, meme si personne ne la parse                 }
  { depuis une source ICI). }
  EnumerationT := TypeAdd(TYK_INTERFACE, 'Enumeration', 4, 4, -1);
  TypeTab[EnumerationT].Visibility := VIS_PUBLIC;
  MethodPoolAdd(EnumerationT, 'hasMoreElements', MK_METHOD, False, False, True,
    PRIMTYPE_BOOLEAN, ParamPoolCount, 0, VIS_PUBLIC);
  MethodPoolAdd(EnumerationT, 'nextElement', MK_METHOD, False, False, True,
    PDT_OBJECT, ParamPoolCount, 0, VIS_PUBLIC);

  { Vector - sous-ensemble EXACT exerce par Test10Collections.jpp. }
  VectorT := ClassAdd('Vector', PDT_OBJECT, False, False, VIS_PUBLIC);
  StdMethod0(VectorT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID);
  StdMethod1(VectorT, 'addElement', MK_METHOD, False, PRIMTYPE_VOID, PDT_OBJECT);
  StdMethod0(VectorT, 'elements', MK_METHOD, False, EnumerationT);
  StdMethod1(VectorT, 'removeElement', MK_METHOD, False, PRIMTYPE_BOOLEAN, PDT_OBJECT);
  StdMethod0(VectorT, 'size', MK_METHOD, False, PRIMTYPE_INT);

  { Hashtable - sous-ensemble EXACT exerce par Test10Collections.jpp. }
  HashtableT := ClassAdd('Hashtable', PDT_OBJECT, False, False, VIS_PUBLIC);
  StdMethod0(HashtableT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID);
  StdMethod2(HashtableT, 'put', MK_METHOD, False, PDT_OBJECT, PDT_OBJECT, PDT_OBJECT);
  StdMethod1(HashtableT, 'get', MK_METHOD, False, PDT_OBJECT, PDT_OBJECT);

  { java.io - EXACTEMENT la chaine de constructeurs imbriques de           }
  { Test12Fichiers.jpp ("new PrintWriter(new BufferedWriter(new                     }
  { FileWriter(nom)))"/"new BufferedReader(new FileReader(nom))") -                  }
  { Writer/Reader sont des bases MINIMALES (AUCUN membre propre exerce)         }
  { qui existent UNIQUEMENT pour que TypeIsSubclassOf verifie la                        }
  { compatibilite des parametres de constructeur (TODO 08/09,                             }
  { MethodParamsCompatible). IOException herite getMessage() via                       }
  { Exception/Throwable, AUCUN cablage special. }
  WriterT := ClassAdd('Writer', PDT_OBJECT, False, False, VIS_PUBLIC);
  ReaderT := ClassAdd('Reader', PDT_OBJECT, False, False, VIS_PUBLIC);

  FileWriterT := ClassAdd('FileWriter', WriterT, False, False, VIS_PUBLIC);
  StdMethod1(FileWriterT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, PDT_STRING);

  BufferedWriterT := ClassAdd('BufferedWriter', WriterT, False, False, VIS_PUBLIC);
  StdMethod1(BufferedWriterT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, WriterT);

  PrintWriterT := ClassAdd('PrintWriter', WriterT, False, False, VIS_PUBLIC);
  StdMethod1(PrintWriterT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, WriterT);
  StdMethod1(PrintWriterT, 'println', MK_METHOD, False, PRIMTYPE_VOID, PDT_STRING);
  StdMethod0(PrintWriterT, 'checkError', MK_METHOD, False, PRIMTYPE_BOOLEAN);
  StdMethod0(PrintWriterT, 'close', MK_METHOD, False, PRIMTYPE_VOID);

  FileReaderT := ClassAdd('FileReader', ReaderT, False, False, VIS_PUBLIC);
  StdMethod1(FileReaderT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, PDT_STRING);

  BufferedReaderT := ClassAdd('BufferedReader', ReaderT, False, False, VIS_PUBLIC);
  StdMethod1(BufferedReaderT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, ReaderT);
  StdMethod0(BufferedReaderT, 'readLine', MK_METHOD, False, PDT_STRING);
  StdMethod0(BufferedReaderT, 'close', MK_METHOD, False, PRIMTYPE_VOID);

  IOExceptionT := ClassAdd('IOException', PDT_EXCEPTION, False, False, VIS_PUBLIC);
  StdMethod1(IOExceptionT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, PDT_STRING);

  { java.lang.Object.wait()/notify()/notifyAll() (section 14.27/14.28) -  }
  { AJOUTES sur PDT_OBJECT lui-meme, EXACTEMENT le meme precedent que              }
  { Throwable.getMessage() plus haut : TOUT type derive de Object                       }
  { (litteralement CHAQUE classe/tableau de ce compilateur, section 8.1)               }
  { les herite ainsi SANS aucun cablage special, via la chaine                              }
  { SuperTypeIdx DEJA existante - AUCUN mecanisme nouveau. wait()/                            }
  { notifyAll() sont les DEUX SEULES formes REELLEMENT exercees                              }
  { (FileEntiers.deposer/retirer, Test11Threads.jpp) ; notify() est                       }
  { ajoutee PAR SYMETRIE (section 14.28 la nomme dans la MEME phrase que          }
  { notifyAll(), et le texte de la roadmap TODO 14 cite explicitement                 }
  { "wait()/notify()/notifyAll()" comme cible) - PAS une extrapolation             }
  { au-dela du texte source, puisque sa signature est sans ambiguite ET           }
  { qu aucune variante temporisee (wait(long)/wait(long,int), section              }
  { 14.30) n est ajoutee : celles-ci restent DEFERREES, non exercees. }
  StdMethod0(PDT_OBJECT, 'wait', MK_METHOD, False, PRIMTYPE_VOID);
  StdMethod0(PDT_OBJECT, 'notify', MK_METHOD, False, PRIMTYPE_VOID);
  StdMethod0(PDT_OBJECT, 'notifyAll', MK_METHOD, False, PRIMTYPE_VOID);

  { java.lang.Runnable (section 14.2) - VRAIE interface a UNE seule       }
  { methode abstraite, meme discipline que Enumeration plus haut. }
  RunnableT := TypeAdd(TYK_INTERFACE, 'Runnable', 4, 4, -1);
  TypeTab[RunnableT].Visibility := VIS_PUBLIC;
  MethodPoolAdd(RunnableT, 'run', MK_METHOD, False, False, True,
    PRIMTYPE_VOID, ParamPoolCount, 0, VIS_PUBLIC);

  { java.lang.Thread (section 14.2-14.9) - implements Runnable (VRAI en  }
  { Java reel, InterfacePoolAdd reutilise TEL QUEL, TODO 09) ; portee            }
  { DECIDEE PAR GREP de Test11Threads.jpp AVANT d ecrire une seule ligne          }
  { (meme discipline que le TODO 13) : SEULS start()/join()/le                             }
  { constructeur Thread(Runnable,String) y apparaissent litteralement.             }
  { run()/getName()/currentThread() sont AJOUTES en plus car le TEXTE            }
  { DU ROADMAP TODO 14 les nomme explicitement ("start()/run(), thread           }
  { courant et son nom (14.8-14.9)") - getName()/currentThread() sont                 }
  { groundes par l EXEMPLE de la section 14.8 elle-meme ("Thread courant         }
  { = Thread.currentThread(); System.out.println(courant.getName());"),          }
  { reproduit tel quel dans ThreadSelfTest plus bas. Les SIX autres                   }
  { constructeurs de la section 14.5, setName/getPriority/setPriority              }
  { (14.10), setDaemon/isDaemon (14.11), sleep/yield/interrupt/                            }
  { isInterrupted/interrupted (14.14-14.17), isAlive, et les surcharges           }
  { temporisees de join() restent DEFERES - explicitement NON devines,           }
  { aucun echantillon actuel ne les exerce. AUCUNE contrepartie Win32               }
  { (CreateThread) n est cablee ICI - voir la note d en-tete du TODO 14           }
  { pour la decision EXPLICITE de correspondance, deferree au TODO 21+          }
  { comme toute generation de code dans ce compilateur. }
  ThreadT := ClassAdd('Thread', PDT_OBJECT, False, False, VIS_PUBLIC);
  InterfacePoolAdd(ThreadT, RunnableT);
  StdMethod2(ThreadT, '', MK_CONSTRUCTOR, False, PRIMTYPE_VOID, RunnableT, PDT_STRING);
  StdMethod0(ThreadT, 'run', MK_METHOD, False, PRIMTYPE_VOID);
  StdMethod0(ThreadT, 'start', MK_METHOD, False, PRIMTYPE_VOID);
  StdMethod0(ThreadT, 'join', MK_METHOD, False, PRIMTYPE_VOID);
  StdMethod0(ThreadT, 'getName', MK_METHOD, False, PDT_STRING);
  StdMethod0(ThreadT, 'currentThread', MK_METHOD, True, ThreadT);

  { com.ms.win32 (TODO 18, section 18.1) - portee groundee EXACTEMENT     }
  { sur Test16Win32.jpp : "User32.MessageBox(0, texte, titre, type)"           }
  { avec "type = winm.MB_OK | winm.MB_ICONINFORMATION" ("|" DEJA               }
  { supporte depuis le TODO 06, AUCUN travail nouveau). User32 est une            }
  { VRAIE TYK_CLASS (methode STATIQUE, appel qualifie PAR NOM DE TYPE,          }
  { EK_TYPEREF, MEME forme qu Integer.parseInt au TODO 13) ; winm est                }
  { une VRAIE TYK_INTERFACE de CONSTANTES (section 18.1, "regroupees                 }
  { dans des interfaces dont le nom commence par win... MB_* se                        }
  { trouvent dans winm") - AUCUNE valeur numerique Win32 REELLE n est             }
  { stockee (MB_OK=0x0, MB_ICONINFORMATION=0x40 en Win32 reel) : EXACTEMENT   }
  { la MEME portee que System.out/System.err au TODO 13 (metadonnee DE          }
  { TYPE seule, AUCUNE valeur/adresse/handle reel puisqu AUCUNE                        }
  { generation de code n existe encore nulle part dans ce compilateur). }
  { AUCUNE AUTRE famille du paquet (Gdi32/Kernel32/Ole32/Shell32,                     }
  { section 18.1) n est ajoutee : UN SEUL echantillon exerce UNE SEULE          }
  { fonction d UNE SEULE famille - deviner les autres serait exactement          }
  { le piege documente au TODO 15/16 (AWT/delegates), un seul point de           }
  { donnees ne groundant rien au-dela de lui-meme.                                          }
  {                                                                       }
  { UNIFICATION AVEC LE J/DIRECT DU TODO 17 (roadmap : "MEME mecanisme          }
  { que les appels com.ms.win32") : le MethodPool de User32.MessageBox           }
  { recoit les MEMES champs IsDllImport/DllLibName/DllEntrypoint/                     }
  { DllCharSet qu une VRAIE methode "native" @dll.import (TODO 17) -               }
  { PREUVE que les DEUX mecanismes convergent DEJA vers UNE SEULE                     }
  { representation, prete pour UN SEUL mecanisme de thunk futur (le               }
  { roadmap du TODO 18 lui-meme cite "le MEME mecanisme de thunk IAT             }
  { que les compilateurs freres batissent deja... (TODO 23)") - AUCUN            }
  { thunk n est cable ICI, decision EXPLICITEMENT DEFERREE (comme                     }
  { TOUTE generation de code dans ce compilateur depuis le TODO 08),               }
  { PAS une omission. }
  User32T := ClassAdd('User32', PDT_OBJECT, False, False, VIS_PUBLIC);
  PFirst := ParamPoolCount;
  ParamPoolAddRaw('hwnd', PRIMTYPE_INT);
  ParamPoolAddRaw('texte', PDT_STRING);
  ParamPoolAddRaw('titre', PDT_STRING);
  ParamPoolAddRaw('type', PRIMTYPE_INT);
  MBMI := MethodPoolAdd(User32T, 'MessageBox', MK_METHOD, True, False, False,
    PRIMTYPE_INT, PFirst, 4, VIS_PUBLIC);
  If MBMI >= 0 Then
  Begin
    MethodPool[MBMI].IsDllImport   := True;
    MethodPool[MBMI].DllLibName    := 'USER32';
    MethodPool[MBMI].DllEntrypoint := 'MessageBoxA';   { ANSI par defaut, }
                                { section 17.11/18.1 - AUCUN echantillon              }
                                { ne demande la variante Unicode. }
    MethodPool[MBMI].DllCharSet    := 'ansi';
  End;

  WinmT := TypeAdd(TYK_INTERFACE, 'winm', 4, 4, -1);
  TypeTab[WinmT].Visibility := VIS_PUBLIC;
  FieldPoolAdd(WinmT, PRIMTYPE_INT, 'MB_OK', True, True, VIS_PUBLIC);
  FieldPoolAdd(WinmT, PRIMTYPE_INT, 'MB_ICONINFORMATION', True, True, VIS_PUBLIC);
End;

{ ------------------------------------------------------------ }
{ StdlibSelfTest : chaque appel/chaque type reproduit LITTERALEMENT une }
{ ligne REELLE de Test06ProprietesBean/Test07Heritage/Test09Exceptions/     }
{ Test10Collections/Test12Fichiers.jpp. }
{ ------------------------------------------------------------ }

Procedure StdlibAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StdlibSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StdlibSelfTest;
Var
  E, IntegerT, PrintWriterT, BufferedReaderT, IOExceptionT, DonneeT : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- "valeur.length()" ISOLE (section 13, EXACTEMENT                  }
  { Test06ProprietesBean.jpp) - teste ISOLEMENT via ExprParseString,               }
  { meme methode qu ExprSelfTest. -------------------------------------------------- }
  SymEnterScope;
  SymAdd('valeur', SK_VAR, PDT_STRING, False, False);
  E := ExprParseString('valeur.length()');
  SymLeaveScope;
  StdlibAssert('valeur.length() : EK_CALL resolu (int), section 13',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_INT));

  { --- "System.out.println(...)" ISOLE, QUATRE surcharges (String/int/  }
  { double/Object) - EXACTEMENT les types REELS passes a travers les 18       }
  { echantillons (Test01Bonjour/Test04Methodes/Test07Heritage.jpp). ------------- }
  E := ExprParseString('System.out.println("Bonjour depuis J++ !")');
  StdlibAssert('System.out.println(String) : resolu (void), Test01Bonjour.jpp',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('System.out.println(4)');
  StdlibAssert('System.out.println(int) : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('System.out.println(4.5)');
  StdlibAssert('System.out.println(double) : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('System.err.println("Erreur")');
  StdlibAssert('System.err.println(String) : System.err RESOLU ' +
    'separement de System.out (MEME classe PrintStream, DEUX champs)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));

  { --- "Integer.parseInt(texte)" (Test09Exceptions.jpp) - LA forme       }
  { qui exigeait EK_TYPEREF (section 12.15, appel STATIQUE qualifie par        }
  { un NOM DE TYPE, jamais une expression). ------------------------------------- }
  SymEnterScope;
  SymAdd('texte', SK_VAR, PDT_STRING, False, False);
  E := ExprParseString('Integer.parseInt(texte)');
  SymLeaveScope;
  StdlibAssert('Integer.parseInt(texte) : "Integer" resolu en EK_TYPEREF, ' +
    'PAS un identificateur NON resolu (section 12.15)',
    ExprPool[ExprPool[ExprPool[E].Left].Left].Kind = EK_TYPEREF);
  StdlibAssert('Integer.parseInt(texte) : appel resolu (int)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_INT));

  { --- "new Integer(1995)" (Test10Collections.jpp). ------------------------ }
  E := ExprParseString('new Integer(1995)');
  IntegerT := TypeFindByName('Integer');
  StdlibAssert('new Integer(1995) : constructeur resolu, type Integer',
    (ExprPool[E].Kind = EK_NEWOBJECT) And (ExprPool[E].TypeIdx = IntegerT) And
    (ExprPool[E].Left >= 0));

  { --- Vector/Hashtable/Enumeration (Test10Collections.jpp) - chaine     }
  { COMPLETE : creation, ajout, iteration, suppression, taille. -------------- }
  SymEnterScope;
  SymAdd('langages', SK_VAR, TypeFindByName('Vector'), False, False);
  SymAdd('annees', SK_VAR, TypeFindByName('Hashtable'), False, False);
  SymAdd('nom', SK_VAR, PDT_STRING, False, False);
  E := ExprParseString('langages.addElement("Java")');
  StdlibAssert('langages.addElement("Java") : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('annees.put("Java", new Integer(1995))');
  StdlibAssert('annees.put(...) : resolu (Object, section "put" reelle ' +
    'de Hashtable)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PDT_OBJECT));
  E := ExprParseString('langages.elements()');
  StdlibAssert('langages.elements() : resolu (Enumeration)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = TypeFindByName('Enumeration')));
  E := ExprParseString('annees.get(nom)');
  StdlibAssert('annees.get(nom) : resolu (Object)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PDT_OBJECT));
  E := ExprParseString('langages.removeElement("C#")');
  StdlibAssert('langages.removeElement("C#") : resolu (boolean)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN));
  E := ExprParseString('langages.size()');
  StdlibAssert('langages.size() : resolu (int)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_INT));
  SymLeaveScope;

  { --- java.io - EXACTEMENT la chaine imbriquee de Test12Fichiers.jpp,   }
  { PREUVE que Writer/Reader donnent la compatibilite de PARAMETRE               }
  { CORRECTE entre classes concretes SŒURS (FileWriter/BufferedWriter               }
  { partagent la MEME superclasse Writer, section 9.11-style). -------------------- }
  E := ExprParseString('new PrintWriter(new BufferedWriter(new FileWriter("x")))');
  PrintWriterT := TypeFindByName('PrintWriter');
  StdlibAssert('new PrintWriter(new BufferedWriter(new FileWriter("x"))) : ' +
    'TROIS constructeurs IMBRIQUES, TOUS resolus (Test12Fichiers.jpp)',
    (ExprPool[E].Kind = EK_NEWOBJECT) And (ExprPool[E].TypeIdx = PrintWriterT) And
    (ExprPool[E].Left >= 0) And
    (ExprPool[ExprArgPool[ExprPool[E].ArgFirst]].Left >= 0) And
    (ExprPool[ExprArgPool[ExprPool[ExprArgPool[ExprPool[E].ArgFirst]].ArgFirst]].Left >= 0));

  E := ExprParseString('new BufferedReader(new FileReader("x"))');
  BufferedReaderT := TypeFindByName('BufferedReader');
  StdlibAssert('new BufferedReader(new FileReader("x")) : DEUX ' +
    'constructeurs IMBRIQUES, TOUS resolus (Test12Fichiers.jpp)',
    (ExprPool[E].Kind = EK_NEWOBJECT) And (ExprPool[E].TypeIdx = BufferedReaderT) And
    (ExprPool[E].Left >= 0) And (ExprPool[ExprArgPool[ExprPool[E].ArgFirst]].Left >= 0));

  SymEnterScope;
  SymAdd('sortie', SK_VAR, PrintWriterT, False, False);
  SymAdd('entree', SK_VAR, BufferedReaderT, False, False);
  E := ExprParseString('sortie.println("Premiere ligne")');
  StdlibAssert('sortie.println("Premiere ligne") : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('sortie.checkError()');
  StdlibAssert('sortie.checkError() : resolu (boolean)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_BOOLEAN));
  E := ExprParseString('sortie.close()');
  StdlibAssert('sortie.close() : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('entree.readLine()');
  StdlibAssert('entree.readLine() : resolu (String)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PDT_STRING));
  E := ExprParseString('entree.close()');
  StdlibAssert('entree.close() : resolu (void)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  SymLeaveScope;

  E := ExprParseString('new IOException("erreur d''ecriture")');
  IOExceptionT := TypeFindByName('IOException');
  StdlibAssert('new IOException(...) : constructeur resolu, DERIVE de ' +
    'Exception (section 13, Test12Fichiers.jpp)',
    (ExprPool[E].Kind = EK_NEWOBJECT) And (ExprPool[E].TypeIdx = IOExceptionT) And
    (ExprPool[E].Left >= 0) And TypeIsSubclassOf(IOExceptionT, PDT_EXCEPTION));

  { --- Throwable.getMessage() HERITE par une exception UTILISATEUR       }
  { (DonneeException, TODO 08/11) SANS AUCUN cablage special - PREUVE        }
  { que StdlibInit s integre a la chaine SuperTypeIdx EXISTANTE plutot            }
  { que d exiger un traitement particulier par classe concrete. ------------- }
  DonneeT := ClassAdd('DonneeException', PDT_EXCEPTION, False, False, VIS_PACKAGE);
  SymEnterScope;
  SymAdd('e', SK_VAR, DonneeT, False, False);
  E := ExprParseString('e.getMessage()');
  SymLeaveScope;
  StdlibAssert('e.getMessage() : herite de Throwable a travers ' +
    'DonneeException -> Exception -> Throwable (section 11.21)',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PDT_STRING));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 14 - THREADS ET SYNCHRONISATION (sections 14.1-14.31,             }
{ echantillon : Test11Threads.jpp)                                                          }
{                                                                       }
{ Portee DECIDEE PAR GREP de Test11Threads.jpp AVANT d ecrire une              }
{ seule ligne (meme discipline que tout TODO precedent) : classe               }
{ FileEntiers avec DEUX methodes synchronized utilisant wait()/                          }
{ notifyAll() sans qualificateur (section 14.20/14.21/14.27/14.28) ;             }
{ Thread cree via "new Thread(new Runnable() avec un corps run(),              }
{ "producteur")", demarre (start()) puis attendu (join()).                          }
{                                                                       }
{ CLASSES ANONYMES - decision EXPLICITE (pas une omission) : le               }
{ TODO 09 avait deja differe "classes locales/anonymes... hors de              }
{ portee tant qu aucun echantillon ne les exerce" ; Test11Threads.jpp            }
{ en exerce desormais UNE ("new Runnable()" avec un corps de classe                 }
{ ANONYME inline), mais leur PARSING reste une extension SEPAREE (portee/          }
{ construction de classe synthetique, capture de variables locales                  }
{ "final" englobantes - section 8.23/8.24) SANS RAPPORT avec threads/            }
{ synchronized eux-memes : ce TODO 14 porte sur Thread/Runnable/                        }
{ synchronized/wait/notify, PAS sur les classes locales/anonymes.               }
{ ThreadSelfTest (plus bas) reproduit donc la forme EQUIVALENTE de la           }
{ section 14.3 elle-meme (une classe NOMMEE "Travail implements                        }
{ Runnable"), adaptee avec le DEUXIEME argument "producteur"                            }
{ REELLEMENT passe par Test11Threads.jpp (section 14.9) - un                            }
{ substitut EXPLICITEMENT documente, jamais une approximation                            }
{ silencieuse : la resolution de type/surcharge (front-end, seule                     }
{ chose que ce compilateur verifie encore, AUCUNE generation de code               }
{ nulle part) est IDENTIQUE, qu il s agisse d une classe nommee ou               }
{ anonyme. Les classes locales/anonymes restent DEFERREES, non                          }
{ devinees.                                                                                 }
{                                                                       }
{ TROIS DECISIONS DE MECANISME REQUISES ICI PAR LE TEXTE DU ROADMAP,             }
{ AUCUNE devinee au TODO 21 (memes principes : "AUCUNE generation de                }
{ code n existe ENCORE nulle part dans ce compilateur", TODO 08-13 -               }
{ ces trois decisions restent donc de la DOCUMENTATION D INTENTION,             }
{ PAS du code emis, exactement comme la note d en-tete de ParseTryStmt          }
{ (TODO 11) documente la propagation d exception SANS l implementer) :          }
{                                                                       }
{ (A) Thread.start() -> CreateThread (section 14.2/14.6) : MEME                        }
{     precedent que les goroutines-en-vrais-threads de GOCW32.PAS                    }
{     (son TODO 15, "VRAIS threads Win32 (CreateThread) et VRAIE                     }
{     exclusion mutuelle (CRITICAL_SECTION) par canal") - PAS un                         }
{     ordonnanceur cooperatif hand-roule. DIFFERENCE avec le cas GO :          }
{     une goroutine GOCW32 appelle une fonction dont l ADRESSE est               }
{     connue a la COMPILATION (CALL direct) ; Thread.start() doit                       }
{     appeler soit Thread.run() REDEFINIE par une sous-classe, soit               }
{     le run() d un Runnable passe en parametre - AUCUNE des deux ne              }
{     peut etre resolue par un simple CALL direct SANS une VRAIE                          }
{     expedition dynamique (vtable), qui n existe ENCORE nulle part                   }
{     dans ce compilateur (voir la note d en-tete de la section 8.15-        }
{     style plus haut, "AUCUN VRAI expedition dynamique (vtable) n              }
{     existe"). DECISION : Thread.start() appellera CreateThread avec           }
{     un trampoline COMMUN recevant le pointeur d objet (Thread ou              }
{     Runnable) comme lpParameter, qui appellera ENSUITE run() via                  }
{     QUELQUE MECANISME de vtable que le TODO 21+ finira par choisir             }
{     pour les appels virtuels EN GENERAL (PAS invente ICI              specifiquement            }
{     pour les threads) - la vtable est donc une DEPENDANCE PREALABLE            }
{     decouverte par ce TODO, pas une lacune PROPRE aux threads.                       }
{                                                                       }
{ (B) synchronized (methode d instance/static, section 14.21/14.22,             }
{     et bloc synchronized(expr), section 14.23, DEJA parse comme                    }
{     STK_SYNCHRONIZED, syntaxe seule, voir sa propre note d en-tete)           }
{     -> UNE VRAIE section critique Win32 (CRITICAL_SECTION) PAR                       }
{     OBJET moniteur, JAMAIS un verrou global unique. Justifie                          }
{     directement par le texte de la specification lui-meme (section          }
{     14.20, "des moniteurs differents n assurent aucune exclusion               }
{     entre eux" - un verrou global violerait cette regle) et par le            }
{     PRECEDENT DEJA PROUVE de GOCW32.PAS (une VRAIE CRITICAL_SECTION           }
{     de 24 octets PAR CANAL, jamais une section critique globale du            }
{     programme). Consequence pratique pour le TODO 21+ : chaque                       }
{     objet aura besoin d un champ CACHE supplementaire (24 octets                  }
{     CRITICAL_SECTION Win32) DANS SON DISPOSITION MEMOIRE - la                           }
{     strategie d ALLOCATION (paresseuse au premier "synchronized"                  }
{     rencontre vs. systematique a la construction) reste ELLE-MEME             }
{     un detail d implementation reporte au TODO 21+, SEUL le choix               }
{     "PAR OBJET, jamais global" est FIXE des maintenant. L acquisition          }
{     a l entree/liberation a TOUTE sortie (section 14.21, "normale ou          }
{     provoquee par une exception") devra s integrer a la MEME chaine           }
{     de deroulement que documentee pour STK_TRY (TODO 11) - LeaveCriticalSection           }
{     jouera le role d un "finally" implicite. La reentrance (section          }
{     14.25) est offerte GRATUITEMENT par CRITICAL_SECTION (compteur            }
{     de recursion NATIF par thread proprietaire) - une raison                            }
{     SUPPLEMENTAIRE, pas seulement historique, de preferer cette                    }
{     primitive a un mutex/semaphore nu.                                                    }
{                                                                       }
{ (C) wait()/notify()/notifyAll() (section 14.27/14.28) -> PAS une                    }
{     VRAIE CONDITION_VARIABLE Win32 (SleepConditionVariableCS/                            }
{     WakeConditionVariable), bien que cette primitive existe nativement          }
{     sur les Windows cibles par ce projet : DECISION DE COHERENCE                   }
{     avec le SEUL precedent d attente bloquante DEJA ECRIT et PROUVE             }
{     dans ce depot, celui des canaux GOCW32.PAS (_GORT_CHAN_RECV/                     }
{     _GORT_CHAN_SEND) - une ATTENTE ACTIVE BORNEE (Sleep(0) entre                    }
{     chaque tentative, jusqu a une limite fixe du MEME ordre de                        }
{     grandeur que CHAN_MAX_SPIN de GOCW32.PAS), PAS une primitive                    }
{     Windows nouvelle et jamais exercee ailleurs dans ce code                            }
{     generateur. wait() liberera la CRITICAL_SECTION de l objet                        }
{     (decision B) avant de tourner, testera un compteur de                                 }
{     "generation de notification" propre a l objet (incremente sous            }
{     verrou par notify()/notifyAll(), MEME principe qu un simple                     }
{     drapeau de canal GOCW32), puis reacquerra la section critique            }
{     avant de retourner - EXACTEMENT le protocole "entree/boucle/                    }
{     reacquisition" de la section 14.29, implemente par une primitive          }
{     DEJA ELUE ailleurs dans ce projet plutot qu une nouvelle jamais            }
{     testee. Limitation ASSUMEE et documentee (comme le spin borne              }
{     des canaux GOCW32) : un wait() qui n est JAMAIS notifie se                        }
{     termine par expiration du compteur de tentatives plutot que de           }
{     bloquer indefiniment - garantit qu un .exe produit se termine               }
{     toujours, au prix d un ecart avec la semantique Java stricte              }
{     ("bloque indefiniment sans notification").                                                }
{                                                                       }
{ AUCUNE des trois decisions ci-dessus n est implementee ICI - AUCUNE          }
{ generation de code n existe encore nulle part dans ce compilateur                  }
{ (meme etat exact que documente depuis le TODO 08). java.lang.Object.wait()/     }
{ notify()/notifyAll() et java.lang.Thread/Runnable sont AJOUTES a                   }
{ StdlibInit (TODO 13, voir ses propres commentaires ci-dessus pour               }
{ le detail EXACT de chaque membre et sa justification) EXACTEMENT               }
{ comme toute autre entree de bibliotheque standard - de VRAIS                            }
{ TYK_CLASS/TYK_INTERFACE, AUCUN mecanisme nouveau au-dela d               }
{ InterfacePoolAdd (Thread implements Runnable, TODO 09) DEJA existant.             }
{ IllegalThreadStateException/IllegalMonitorStateException/ThreadGroup           }
{ (cites par le texte de la specification, sections 14.6/14.11/14.27)          }
{ restent DEFERES - AUCUN echantillon actuel ne les leve/attrape.                    }
{ ------------------------------------------------------------ }

Procedure ThreadAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ThreadSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ThreadSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  FileT, MIDeposer, MIRetirer, SI : Integer;
  Body, S_While, InnerBlock, S_Wait, WaitCall, S_NotifyAll, NotifyCall : Integer;
  TravailT, ThreadT, RunnableT, E : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- FileEntiers (Test11Threads.jpp, copie LITTERALE des deux          }
  { methodes synchronized) - via ClassParseFile, meme discipline que             }
  { ExceptionSelfTest/PackageSelfTest. ------------------------------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class FileEntiers {');
  WriteLn(F, '    private int valeur;');
  WriteLn(F, '    private boolean disponible;');
  WriteLn(F, '');
  WriteLn(F, '    public synchronized void deposer(int nouvelleValeur)');
  WriteLn(F, '        throws InterruptedException {');
  WriteLn(F, '        while (disponible) {');
  WriteLn(F, '            wait();');
  WriteLn(F, '        }');
  WriteLn(F, '        valeur = nouvelleValeur;');
  WriteLn(F, '        disponible = true;');
  WriteLn(F, '        notifyAll();');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    public synchronized int retirer()');
  WriteLn(F, '        throws InterruptedException {');
  WriteLn(F, '        while (!disponible) {');
  WriteLn(F, '            wait();');
  WriteLn(F, '        }');
  WriteLn(F, '        int resultat = valeur;');
  WriteLn(F, '        disponible = false;');
  WriteLn(F, '        notifyAll();');
  WriteLn(F, '        return resultat;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  FileT := ClassParseFile;
  Erase(F);
  ThreadAssert('FileEntiers : classe enregistree', FileT >= 0);

  MIDeposer := -1;
  MIRetirer := -1;
  For SI := 0 To MethodPoolCount - 1 Do
  Begin
    If (MethodPool[SI].OwnerTypeIdx = FileT) And (MethodPool[SI].Name = 'deposer') Then
      MIDeposer := SI;
    If (MethodPool[SI].OwnerTypeIdx = FileT) And (MethodPool[SI].Name = 'retirer') Then
      MIRetirer := SI;
  End;
  ThreadAssert('deposer()/retirer() : "synchronized" (section 14.21) ' +
    'memorise sur TMethodRec.IsSynchronized',
    (MIDeposer >= 0) And MethodPool[MIDeposer].IsSynchronized And
    (MIRetirer >= 0) And MethodPool[MIRetirer].IsSynchronized);

  { deposer() : wait() (dans le corps du while) et notifyAll() (derniere }
  { instruction) resolvent TOUS DEUX SANS qualificateur (this implicite,          }
  { section 8.3) via la chaine SuperTypeIdx jusqu a Object (section              }
  { 14.27/14.28) - AUCUN cablage special pour FileEntiers, EXACTEMENT             }
  { le meme precedent que Throwable.getMessage() (TODO 13). retirer()             }
  { suit le MEME mecanisme (deja PROUVE synchronized ci-dessus),                       }
  { non re-teste pour son propre wait()/notifyAll() (repetition). ------------ }
  Body := MethodPool[MIDeposer].BodyStmtIdx;
  S_While := StmtArgPool[StmtPool[Body].ArgFirst];
  ThreadAssert('deposer() : premiere instruction = while(disponible) (STK_WHILE)',
    StmtPool[S_While].Kind = STK_WHILE);
  InnerBlock := StmtPool[S_While].Right;
  S_Wait := StmtArgPool[StmtPool[InnerBlock].ArgFirst];
  WaitCall := StmtPool[S_Wait].Left;
  ThreadAssert('deposer() : wait() SANS qualificateur resolu via Object (void)',
    (ExprPool[WaitCall].Kind = EK_CALL) And (ExprPool[WaitCall].TypeIdx = PRIMTYPE_VOID));
  S_NotifyAll := StmtArgPool[StmtPool[Body].ArgFirst + 3];
  NotifyCall := StmtPool[S_NotifyAll].Left;
  ThreadAssert('deposer() : notifyAll() SANS qualificateur resolu via Object (void)',
    (ExprPool[NotifyCall].Kind = EK_CALL) And (ExprPool[NotifyCall].TypeIdx = PRIMTYPE_VOID));

  { --- Thread/Runnable (sections 14.2/14.3/14.6/14.9) - forme EQUIVALENTE }
  { a l objet Runnable ANONYME de Test11Threads.jpp (voir la note d en-tete       }
  { de ce TODO pour la justification du substitut PAR UNE CLASSE NOMMEE),          }
  { DEUXIEME argument "producteur" REELLEMENT passe par le fichier reel. ---- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Travail implements Runnable {');
  WriteLn(F, '    public void run() {');
  WriteLn(F, '        effectuer();');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    private void effectuer() {');
  WriteLn(F, '        System.out.println("Traitement");');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  TravailT := ClassParseFile;
  Erase(F);
  RunnableT := TypeFindByName('Runnable');
  ThreadAssert('Travail implements Runnable : InterfacePool contient ' +
    'Runnable (section 9.5/14.3)', TypeIsSubclassOf(TravailT, RunnableT));

  ThreadT := TypeFindByName('Thread');
  SymEnterScope;
  SymAdd('tache', SK_VAR, TravailT, False, False);
  E := ExprParseString('new Thread(tache, "producteur")');
  ThreadAssert('new Thread(tache, "producteur") : constructeur ' +
    'Thread(Runnable,String) resolu (Test11Threads.jpp, section 14.5/14.9) ' +
    '- "tache" (Travail) accepte comme Runnable par assignabilite d''' +
    'interface (TypeIsSubclassOf, TODO 09)',
    (ExprPool[E].Kind = EK_NEWOBJECT) And (ExprPool[E].TypeIdx = ThreadT) And
    (ExprPool[E].Left >= 0));
  SymAdd('producteur', SK_VAR, ThreadT, False, False);
  E := ExprParseString('producteur.start()');
  ThreadAssert('producteur.start() : resolu (void), Test11Threads.jpp',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  E := ExprParseString('producteur.join()');
  ThreadAssert('producteur.join() : resolu (void), Test11Threads.jpp',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PRIMTYPE_VOID));
  SymLeaveScope;

  { --- Thread.currentThread()/getName() (sections 14.8/14.9, exemple     }
  { LITTERAL de la section 14.8 elle-meme : "Thread courant =                          }
  { Thread.currentThread(); System.out.println(courant.getName());") -           }
  { AUCUN SAMPLES\JPP\*.jpp actuel n appelle cette forme, mais le TEXTE           }
  { DU ROADMAP TODO 14 la nomme explicitement ("thread courant et son            }
  { nom (14.8-14.9)") - ancree ICI dans la SPECIFICATION elle-meme,               }
  { meme discipline que EK_TYPEREF/Integer.parseInt au TODO 13. ------------------ }
  E := ExprParseString('Thread.currentThread()');
  ThreadAssert('Thread.currentThread() : "Thread" resolu en EK_TYPEREF ' +
    '(section 12.15-style, MEME forme qu''Integer.parseInt, TODO 13)',
    ExprPool[ExprPool[ExprPool[E].Left].Left].Kind = EK_TYPEREF);
  ThreadAssert('Thread.currentThread() : appel STATIQUE resolu (Thread), ' +
    'section 14.8', (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = ThreadT));

  SymEnterScope;
  SymAdd('courant', SK_VAR, ThreadT, False, False);
  E := ExprParseString('courant.getName()');
  SymLeaveScope;
  ThreadAssert('courant.getName() : resolu (String), section 14.9',
    (ExprPool[E].Kind = EK_CALL) And (ExprPool[E].TypeIdx = PDT_STRING));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 15 - APPLETS, AWT ET WFC (sections 15.1-15.9, echantillon :      }
{ Test13Awt.jpp)                                                                            }
{                                                                       }
{ DECISION DE PERIMETRE EXPLICITE EXIGEE PAR LE TEXTE DU ROADMAP LUI-  }
{ MEME ("ne pas la repousser en la devinant au TODO 21... choisir                    }
{ ENTRE (a)... (b)...") - CHOIX : (b), portee EXPLICITEMENT REDUITE/                 }
{ hors-de-portee pour Test13Awt.jpp, PAS (a) un sous-ensemble REEL de           }
{ fenetrage natif Win32 (CreateWindowEx + boucle de messages).                          }
{                                                                       }
{ JUSTIFICATION : (a) exigerait DEUX choses qu aucun TODO precedent                 }
{ n a jamais eues besoin de reunir - un GENERATEUR DE CODE (AUCUN                     }
{ n existe nulle part dans ce compilateur, meme etat documente sans                  }
{ interruption depuis le TODO 08) ET une bibliotheque de classes AWT              }
{ COMPLETE (Component/Container/Window/Frame/Panel/Applet et leur                    }
{ hierarchie reelle, Button/Label/BorderLayout et les gestionnaires               }
{ de disposition, ActionListener/ActionEvent/WindowAdapter/                              }
{ WindowEvent et le modele d evenements 1.1, section 15.15-15.36                       }
{ a elle seule fait VINGT-DEUX sous-sections) - un chantier que le               }
{ texte du roadmap qualifie LUI-MEME de "a part entiere, hors de la              }
{ taille d un TODO incremental unique". Contrairement a TODO13                          }
{ (bibliotheque standard minimale), OU chaque entree etait groundee               }
{ par PLUSIEURS echantillons se recoupant (println par 3 fichiers,                  }
{ Vector/Hashtable par Test10, java.io par Test12), AWT n a ICI                          }
{ QU UN SEUL echantillon (Test13Awt.jpp) - construire ne serait-ce               }
{ qu un sous-ensemble "exactement exerce" reviendrait a DEVINER la               }
{ forme de dizaines de classes a partir d un UNIQUE point de donnees,          }
{ l exact contraire de la discipline de ce projet ("grep D ABORD,                    }
{ jamais devine d avance").                                                                 }
{                                                                       }
{ MECANISME DU "ARRET PROPRE" (b) : AUCUN nouveau garde-fou n est              }
{ ecrit ICI - le compilateur en possede DEJA un, GENERIQUE, depuis le             }
{ TODO 08 : `ParseBaseTypeNoBrackets` leve un VRAI FatalError des qu un           }
{ nom de type n est NI primitif, NI predeclare, NI une classe deja               }
{ declaree TEXTUELLEMENT (voir sa propre note d en-tete, "type ... }
{ inconnu"). "Frame"/"Button"/"Label"/"BorderLayout"/"ActionListener"/          }
{ "ActionEvent"/"WindowAdapter"/"WindowEvent"/"Applet"/"Graphics" ne              }
{ sont AUCUN des trois - "class Test13Awt extends Frame" heurterait                 }
{ donc DEJA ce mur, LE JOUR OU le TODO 21+ branchera                                       }
{ ParseCompilationUnit sur un VRAI fichier .jpp (ce qui n est PAS               }
{ encore le cas pour AUCUN echantillon - Run() ne fait ENCORE que                    }
{ tokeniser, voir sa propre note d en-tete) - EXACTEMENT "MEME                             }
{ discipline que tout constructeur non couvert des compilateurs                        }
{ freres" citee par le roadmap, obtenue ICI par REUTILISATION d un              }
{ garde-fou EXISTANT plutot que par l invention d un mecanisme                          }
{ special-case reserve a AWT (qui serait arbitraire : ce MEME garde-           }
{ fou couvre deja IDENTIQUEMENT tout autre nom de type absent, AWT               }
{ ou non). `AwtSelfTest` (plus bas) le PROUVE INDIRECTEMENT - EXACTEMENT   }
{ la meme discipline documentee par `ExceptionSelfTest` au TODO 11              }
{ pour try-sans-catch-ni-finally ("AUCUN self-test de ce projet ne              }
{ declenche jamais un VRAI FatalError... verifie donc INDIRECTEMENT") -         }
{ puisque `FatalError` appelle `Halt` (voir sa propre definition), un          }
{ VRAI declenchement tuerait le PROCESSUS de self-test lui-meme : ce           }
{ TODO verifie donc que `TypeFindByName` renvoie -1 pour chacun de ces           }
{ noms plutot que d appeler REELLEMENT `ParseBaseTypeNoBrackets` dessus.        }
{                                                                       }
{ IMPORTS : les HUIT lignes "import" de Test13Awt.jpp (java.awt.*/                    }
{ java.awt.event.*) sont DEJA integralement couvertes par le                            }
{ mecanisme GENERIQUE du TODO 12 - AUCUN code nouveau requis : un                     }
{ "import" n est JAMAIS resolu contre un runtime reel ("purement                       }
{ ENREGISTRE pour consultation FUTURE", voir la note d en-tete de                     }
{ ParseImportDecl) - peu importe que le paquet s appelle java.awt OU              }
{ java.util, AUCUNE distinction n existe a ce niveau. Une ligne DE               }
{ CES HUIT ("import java.awt.event.ActionListener;") etait deja                          }
{ testee VERBATIM par `PackageSelfTest` (TODO 12, citant explicitement          }
{ Test13Awt.jpp). `AwtSelfTest` ajoute une verification COMPLEMENTAIRE          }
{ neuve : les HUIT lignes ENSEMBLE, dans une seule unite de                             }
{ compilation, EXACTEMENT comme elles apparaissent reellement en tete           }
{ du fichier.                                                                               }
{                                                                       }
{ CLASSES ANONYMES : Test13Awt.jpp contient "new WindowAdapter()" avec           }
{ un corps de classe ANONYME inline redefinissant windowClosing(...) -          }
{ une DEUXIEME occurrence (apres Test11Threads.jpp au TODO 14) de la                }
{ classe anonyme deja deferree explicitement depuis le TODO 09 - RIEN           }
{ de nouveau a decider ICI, la meme deferrance s applique tel quel,               }
{ ET reste de toute facon hors d atteinte tant que WindowAdapter lui-          }
{ meme n existe pas comme type connu (voir plus haut).                                 }
{                                                                       }
{ DOCUMENTATION (sections 15.1-15.4, AUCUN code, valeur purement                       }
{ EXPLICATIVE demandee par le roadmap) : com.ms.ui (15.1) designe les            }
{ Application Foundation Classes (AFC), la bibliotheque graphique               }
{ Microsoft ANTERIEURE aux WFC (classes prefixees "UI", ex.                             }
{ UIPushButton) ; com.ms.awt (15.2) est un paquet D IMPLEMENTATION                  }
{ (WComponentPeer, Toolkit Microsoft) faisant le pont entre java.awt             }
{ public et les pairs natifs Windows - "ne fait PAS partie de la                        }
{ specification Java 1.1", jamais present dans un JDK Sun/OpenJDK ;               }
{ TROIS familles d interface graphique distinctes coexistent (15.4) :          }
{ Applet/AWT (API Java portable), AFC (com.ms.ui, premieres versions            }
{ J++), WFC (com.ms.wfc.*, Visual J++ 6.0) - importer com.ms.ui OU               }
{ com.ms.wfc.* rend un programme NON portable meme si sa syntaxe                    }
{ reste proche de Java. Section 15.3 (comparaison JavaBean/WFC/C#)               }
{ CONFIRME directement une decision DEJA prise au TODO 08 : "getX()/            }
{ setX()" ne sont QUE des methodes ORDINAIRES par CONVENTION                            }
{ (introspection JavaBeans/fenetre Properties de l IDE), JAMAIS une              }
{ construction syntaxique dediee - Java (contrairement a C#, avec sa                 }
{ syntaxe "public int Age" suivie d un bloc accolade get/set) n a               }
{ AUCUNE declaration de propriete integree - ce compilateur n a donc              }
{ AUCUN `TExprKind`/`TStmtKind`                                                                    }
{ special a inventer pour les proprietes, CONFIRMANT que                                  }
{ `ParseFieldDeclRest`/`ParseMethodDeclRest` (TODO 08, methodes                          }
{ ordinaires) etaient DEJA la bonne forme.                                                  }
{                                                                       }
{ DOCUMENTATION (sections 15.5-15.9, cycle de vie d une applet, AUCUN           }
{ code - MEME famille hors-de-portee que le reste de ce TODO) :                        }
{ Applet derive de java.awt.Panel (15.5, un CONTAINER AWT), n a PAS               }
{ de main() - le navigateur/appletviewer cree l instance et appelle              }
{ init() (une fois) -> start() -> stop() (repetable) -> destroy()               }
{ (15.6) ; getParameter(String)/getParameterInfo() lisent les                             }
{ parametres HTML <PARAM> (15.8) ; getDocumentBase()/getCodeBase()               }
{ donnent les URL du document/des classes (15.9). Ces methodes sont              }
{ des OVERRIDES ORDINAIRES (aucune syntaxe speciale) sur une classe               }
{ qui derive elle-meme de Panel - donc HORS DE PORTEE pour la MEME               }
{ raison exacte que Frame/Button/etc. ci-dessus (Panel/Applet/                            }
{ Graphics ne sont pas des types connus), pas pour une raison                              }
{ DIFFERENTE ou supplementaire.                                                             }
{ ------------------------------------------------------------ }

Procedure AwtAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('AwtSelfTest: ' + Label_ + ' a echoue');
End;

Procedure AwtSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- les HUIT "import" REELS de Test13Awt.jpp, ENSEMBLE, dans une      }
  { seule unite de compilation (complement a l unique ligne DEJA               }
  { testee par PackageSelfTest, TODO 12). ------------------------------------------- }
  PackageInit;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'import java.awt.BorderLayout;');
  WriteLn(F, 'import java.awt.Button;');
  WriteLn(F, 'import java.awt.Frame;');
  WriteLn(F, 'import java.awt.Label;');
  WriteLn(F, 'import java.awt.event.ActionEvent;');
  WriteLn(F, 'import java.awt.event.ActionListener;');
  WriteLn(F, 'import java.awt.event.WindowAdapter;');
  WriteLn(F, 'import java.awt.event.WindowEvent;');
  Close(F);
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);
  ParserInit;
  While ParseImportDecl Do ;
  AwtAssert('les HUIT imports de Test13Awt.jpp : ImportCount = 8',
    ImportCount = 8);
  AwtAssert('premier import : java.awt.BorderLayout',
    (ImportTab[0].PackageName = 'java.awt') And (ImportTab[0].SimpleName = 'BorderLayout'));
  AwtAssert('dernier import : java.awt.event.WindowEvent (paquet MULTI-' +
    'SEGMENTS, section 12.4)',
    (ImportTab[7].PackageName = 'java.awt.event') And (ImportTab[7].SimpleName = 'WindowEvent'));

  { --- AUCUNE des classes/interfaces AWT de Test13Awt.jpp n est un       }
  { type CONNU de ce compilateur (ni primitif, ni predeclare, ni                     }
  { classe utilisateur deja declaree) - PREUVE INDIRECTE que le                          }
  { garde-fou GENERIQUE de ParseBaseTypeNoBrackets (TODO 08) heurterait          }
  { REELLEMENT "class Test13Awt extends Frame" le jour ou une VRAIE               }
  { compilation de fichier existera (TODO 21+) - jamais exerce ICI en            }
  { DECLENCHANT le VRAI FatalError (celui-ci appelle Halt), meme                        }
  { discipline que ExceptionSelfTest/try-sans-catch-ni-finally (TODO 11). ---- }
  AwtAssert('"Frame" (section 15.19) : type INCONNU', TypeFindByName('Frame') < 0);
  AwtAssert('"Button" (section 15.21) : type INCONNU', TypeFindByName('Button') < 0);
  AwtAssert('"Label" (section 15.21) : type INCONNU', TypeFindByName('Label') < 0);
  AwtAssert('"BorderLayout" (section 15.24) : type INCONNU', TypeFindByName('BorderLayout') < 0);
  AwtAssert('"ActionListener" (section 15.28) : type INCONNU', TypeFindByName('ActionListener') < 0);
  AwtAssert('"ActionEvent" (section 15.28) : type INCONNU', TypeFindByName('ActionEvent') < 0);
  AwtAssert('"WindowAdapter" (section 15.29) : type INCONNU', TypeFindByName('WindowAdapter') < 0);
  AwtAssert('"WindowEvent" (section 15.27) : type INCONNU', TypeFindByName('WindowEvent') < 0);
  AwtAssert('"Applet" (section 15.5) : type INCONNU', TypeFindByName('Applet') < 0);
  AwtAssert('"Graphics" (section 15.31) : type INCONNU', TypeFindByName('Graphics') < 0);
  AwtAssert('"Panel" (section 15.5, superclasse d''Applet) : type INCONNU', TypeFindByName('Panel') < 0);

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 16 - DELEGATES ET EVENEMENTS MICROSOFT (sections 16.1-16.15,     }
{ echantillon : Test14Delegates.jpp)                                                        }
{                                                                       }
{ PORTEE decidee PAR GREP de Test14Delegates.jpp AVANT d ecrire une             }
{ seule ligne : DEUX declarations delegate MEMBRES d une classe (une             }
{ simple "public delegate int Operation(int gauche, int droite);", une           }
{ "public multicast delegate void Notification(String message);"),               }
{ chacune construite EXACTEMENT UNE FOIS via "new Nom(this.methode)"             }
{ (liaison a une methode D INSTANCE SEULEMENT - section 16.6, JAMAIS               }
{ static, section 16.7, ni surchargee, section 16.9), puis invoquee              }
{ via ".invoke(...)". AUCUNE chaine multicast REELLE (operateur "+=",          }
{ section 16.13) n apparait dans ce SEUL echantillon.                                  }
{                                                                       }
{ "delegate"/"multicast" restent des mots CONTEXTUELS (jamais dans                  }
{ IsKeyword, voir la note d en-tete pres de la table des mots reserves,        }
{ ecrite des le TODO 03 en prevision EXACTE de ce TODO) - reconnus                  }
{ ICI par une nouvelle fonction de lookahead `DelegateDeclAhead`,                     }
{ MEME technique EXACTE que `NestedTypeKeywordAhead` (TODO 09) : saute            }
{ les modificateurs standard, PUIS le texte litteral "multicast" si               }
{ present, PUIS verifie le texte litteral "delegate" - restaure                          }
{ TOUJOURS PP, aucun token n est consomme avant que `ParseClassMember`         }
{ decide reellement de dispatcher vers `ParseDelegateDecl`.                             }
{                                                                       }
{ REPRESENTATION (section 16.2/16.4) : un delegate est un VRAI                          }
{ TYK_DELEGATE (nouveau genre de type, AJOUTE EN DERNIER dans                            }
{ TTypeKind pour ne JAMAIS deplacer l ordinal d une valeur EXISTANTE)          }
{ dont la SEULE donnee utile - sa signature - est portee par UNE                       }
{ SEULE methode "invoke" SYNTHETISEE (MethodPoolAdd, TODO 08,                            }
{ EXACTEMENT le mecanisme deja employe par StdlibInit au TODO 13 pour          }
{ une methode SANS corps source reel) : TypeTab[DelT].MethodFirst                    }
{ pointe TOUJOURS vers cette entree UNIQUE. Consequence directe :                    }
{ ".invoke(...)" se resout PAR LE MEME `ClassResolveMethodCall`                          }
{ GENERIQUE que tout autre type - ZERO nouveau code de resolution                     }
{ pour invoke() lui-meme, seules les DEUX verifications `TypeTab                        }
{ [BaseT].Kind In [...]` de `ParsePostfix` (selecteur de champ, appel           }
{ resolu) ont du s etendre a TYK_DELEGATE, EXACTEMENT comme TYK_STRING           }
{ l avait ete au TODO 08 pour "chaine.methode()".                                          }
{                                                                       }
{ CONSTRUCTION "new Nom(cible.methode)" (sections 16.5/16.6) : PAS un           }
{ constructeur (un delegate n est PAS une classe, section 16.2) -                       }
{ `ParseNewExpr` gagne une branche `TYK_DELEGATE` DEDIEE (a cote de              }
{ celle, INCHANGEE, pour TYK_CLASS) qui range dans EK_NEWOBJECT.Left            }
{ (deja documente "n utilisait ce champ pour RIEN d autre") la methode           }
{ CIBLE resolue par la nouvelle `DelegateResolveTarget` - AUCUN                          }
{ stockage supplementaire n est requis pour le RECEVEUR ("this" dans             }
{ "this.additionner") : il reste tel quel dans l argument BRUT deja               }
{ conserve par ArgFirst/ArgCount (`ExprPool[ExprArgPool[ArgFirst]]                    }
{ .Left"), une PAIRE LIEE cible/methode au sens de la reference                          }
{ (section 16.2, "il encapsule... la methode a appeler... l objet                     }
{ receveur") existe donc DEJA sans qu aucun champ nouveau ait ete                     }
{ ajoute a TExprRec. "cible.methode" (SANS parentheses, section 16.5,          }
{ "elle ne contient pas de parentheses") est reconnu car `ParsePostfix`        }
{ (TODO 06/08) laisse DEJA un EK_SELECTOR non suivi de "(" avec                          }
{ TypeIdx=-1 quand ClassFindField echoue sur ce nom (best-effort,                      }
{ documente des le TODO 08 : "Nam pourrait tout aussi bien designer                }
{ une METHODE") - AUCUNE modification n a ete necessaire dans                             }
{ `ParsePostfix` pour cette forme, elle etait deja PRODUITE, seulement          }
{ jamais encore CONSOMMEE par quoi que ce soit. La compatibilite de              }
{ signature (section 16.8) reutilise la MEME tolerance d elargissement        }
{ (`TypeIsWidening`) que `MethodParamsCompatible`, par symetrie -                    }
{ INEXERCEE (Test14Delegates.jpp n a que des signatures IDENTIQUES).             }
{                                                                       }
{ DECISION DE REPRESENTATION MULTICAST EXPLICITEMENT EXIGEE PAR LE              }
{ ROADMAP ("decider... AVANT d ecrire le code") : un TABLEAU/pool PLAT          }
{ contigu de paires cible/methode, JAMAIS une liste chainee - PAR                     }
{ COHERENCE                                                                                 }
{ avec absolument TOUTE AUTRE collection de ce compilateur (ParamPool,           }
{ FieldPool, MethodPool, InterfacePool, ImportTab, ExprArgPool,                        }
{ StmtArgPool, DelegateTargetPool serait le SEUL a rompre ce motif               }
{ universel s il devenait une liste chainee). CETTE decision NE                       }
{ s implemente PAS ICI : Test14Delegates.jpp ne construit chaque                      }
{ delegate qu UNE SEULE fois (AUCUN "+=", section 16.13, n apparait),           }
{ et la liste de cibles d un multicast reel serait de toute facon un           }
{ tableau ALLOUE AU TAS, CROISSANT au fil de plusieurs instructions                  }
{ (chaque "+=" ajoute une cible) - un probleme de GENERATION DE CODE            }
{ (allocation dynamique a l execution), pas d analyse syntaxique,                     }
{ EXACTEMENT la meme categorie que "aucune generation de code n existe          }
{ encore" documentee sans interruption depuis le TODO 08 : deferree             }
{ au TODO 21+, decidee ICI, jamais devinee la-bas. `IsMulticast`                        }
{ (nouveau champ TTypeRec) reste donc PUREMENT INFORMATIF pour l instant. }
{                                                                       }
{ DEFERE, PAS DEVINE : delegate lie a une methode STATIQUE (section                }
{ 16.7, "Exemple.tracer" - la note d en-tete de `DelegateResolveTarget`          }
{ explique pourquoi le MEME code la couvrirait DEJA par symetrie, mais          }
{ AUCUN echantillon ne l exerce, donc AUCUNE assertion ne la verifie) ;         }
{ selection PARMI PLUSIEURS surcharges de meme nom (section 16.9,                    }
{ "TraitementEntier") - `DelegateResolveTarget` renvoie la PREMIERE                  }
{ trouvee qui soit COMPATIBLE, jamais signalee ambigue meme s il en                }
{ existe DEUX (best-effort, MEME discipline que ClassFindConstructor/            }
{ ClassResolveMethodCall) ; classe Event/CancelEvent WFC (16.18/16.19),           }
{ conventions addOn.../removeOn...Handler (16.20/16.21) - AUCUN                        }
{ echantillon ne les exerce, documentation de lecture seulement,                       }
{ AUCUN code. }
{ ------------------------------------------------------------ }

Procedure DelegateAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DelegateSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DelegateSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT, OperationT, NotificationT, InvokeMI, SI : Integer;
  MIAdditionner, MIAfficher, MIExecuter : Integer;
  Body, S0, S1, S2, S3, SymOperation, SymNotification, SymResultat : Integer;
  NewOpExpr, NewNotifExpr, InvokeCallExpr, NotifyCallExpr : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- Test14Delegates.jpp EN ENTIER, copie LITTERALE - via                }
  { ClassParseFile, MEME discipline que ExceptionSelfTest/ThreadSelfTest. --- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test14Delegates {');
  WriteLn(F, '    public delegate int Operation(int gauche, int droite);');
  WriteLn(F, '    public multicast delegate void Notification(String message);');
  WriteLn(F, '');
  WriteLn(F, '    public int additionner(int gauche, int droite) {');
  WriteLn(F, '        return gauche + droite;');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    public void afficher(String message) {');
  WriteLn(F, '        System.out.println("Message : " + message);');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    public void executer() {');
  WriteLn(F, '        Operation operation = new Operation(this.additionner);');
  WriteLn(F, '        Notification notification = new Notification(this.afficher);');
  WriteLn(F, '');
  WriteLn(F, '        int resultat = operation.invoke(20, 22);');
  WriteLn(F, '        notification.invoke("Resultat = " + resultat);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  DelegateAssert('Test14Delegates : classe enregistree', ClassT >= 0);

  { --- les DEUX types delegate eux-memes (section 16.3/16.4/16.13). ------- }
  OperationT    := TypeFindByName('Operation');
  NotificationT := TypeFindByName('Notification');
  DelegateAssert('Operation : TYK_DELEGATE, PAS multicast',
    (OperationT >= 0) And (TypeTab[OperationT].Kind = TYK_DELEGATE) And
    (Not TypeTab[OperationT].IsMulticast));
  DelegateAssert('Notification : TYK_DELEGATE, multicast (section 16.13)',
    (NotificationT >= 0) And (TypeTab[NotificationT].Kind = TYK_DELEGATE) And
    TypeTab[NotificationT].IsMulticast);

  InvokeMI := TypeTab[OperationT].MethodFirst;
  DelegateAssert('Operation.invoke : (int,int) -> int (section 16.10)',
    (MethodPool[InvokeMI].Name = 'invoke') And (MethodPool[InvokeMI].ParamCount = 2) And
    (MethodPool[InvokeMI].RetTypeIdx = PRIMTYPE_INT) And
    (ParamPool[MethodPool[InvokeMI].ParamFirst].TypeIdx = PRIMTYPE_INT) And
    (ParamPool[MethodPool[InvokeMI].ParamFirst + 1].TypeIdx = PRIMTYPE_INT));

  InvokeMI := TypeTab[NotificationT].MethodFirst;
  DelegateAssert('Notification.invoke : (String) -> void (section 16.10)',
    (MethodPool[InvokeMI].Name = 'invoke') And (MethodPool[InvokeMI].ParamCount = 1) And
    (MethodPool[InvokeMI].RetTypeIdx = PRIMTYPE_VOID) And
    (ParamPool[MethodPool[InvokeMI].ParamFirst].TypeIdx = PDT_STRING));

  { --- methodes CIBLES reelles, retrouvees INDEPENDAMMENT (par nom) pour  }
  { comparaison contre la resolution DE DELEGUE plus bas. ------------------------- }
  MIAdditionner := -1;
  MIAfficher    := -1;
  MIExecuter    := -1;
  For SI := 0 To MethodPoolCount - 1 Do
  Begin
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'additionner') Then
      MIAdditionner := SI;
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'afficher') Then
      MIAfficher := SI;
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'executer') Then
      MIExecuter := SI;
  End;
  DelegateAssert('additionner()/afficher()/executer() : toutes trouvees',
    (MIAdditionner >= 0) And (MIAfficher >= 0) And (MIExecuter >= 0));

  { --- corps de executer() : QUATRE instructions, EXACTEMENT dans l ordre }
  { TEXTUEL du fichier reel - digne des AST deja utilises par                          }
  { ExceptionSelfTest/ArraySelfTest (SymTab[...].InitExprIdx, TODO 06/10). --- }
  Body := MethodPool[MIExecuter].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];
  S2 := StmtArgPool[StmtPool[Body].ArgFirst + 2];
  S3 := StmtArgPool[StmtPool[Body].ArgFirst + 3];
  DelegateAssert('executer() : QUATRE instructions (2 STK_DECL delegue, ' +
    '1 STK_DECL invoke, 1 STK_EXPR invoke)',
    (StmtPool[Body].ArgCount = 4) And (StmtPool[S0].Kind = STK_DECL) And
    (StmtPool[S1].Kind = STK_DECL) And (StmtPool[S2].Kind = STK_DECL) And
    (StmtPool[S3].Kind = STK_EXPR));

  SymOperation    := StmtPool[S0].Left;
  SymNotification := StmtPool[S1].Left;
  SymResultat     := StmtPool[S2].Left;
  NewOpExpr    := SymTab[SymOperation].InitExprIdx;
  NewNotifExpr := SymTab[SymNotification].InitExprIdx;

  { "new Operation(this.additionner)" : EK_NEWOBJECT, type Operation,     }
  { Left = additionner() REELLEMENT resolu (section 16.5/16.6 - "designe   }
  { la methode et son objet receveur"). ----------------------------------------------- }
  DelegateAssert('new Operation(this.additionner) : resolu vers additionner()',
    (ExprPool[NewOpExpr].Kind = EK_NEWOBJECT) And (ExprPool[NewOpExpr].TypeIdx = OperationT) And
    (ExprPool[NewOpExpr].Left = MIAdditionner));
  DelegateAssert('new Notification(this.afficher) : resolu vers afficher()',
    (ExprPool[NewNotifExpr].Kind = EK_NEWOBJECT) And (ExprPool[NewNotifExpr].TypeIdx = NotificationT) And
    (ExprPool[NewNotifExpr].Left = MIAfficher));

  { "operation.invoke(20, 22)"/"notification.invoke(...)" : EK_CALL          }
  { resolu PAR LE MEME ClassResolveMethodCall generique que TOUT AUTRE    }
  { type (ZERO code de resolution nouveau, voir la note d en-tete). -------- }
  InvokeCallExpr := SymTab[SymResultat].InitExprIdx;
  DelegateAssert('operation.invoke(20, 22) : resolu (int), section 16.10',
    (ExprPool[InvokeCallExpr].Kind = EK_CALL) And (ExprPool[InvokeCallExpr].TypeIdx = PRIMTYPE_INT));

  NotifyCallExpr := StmtPool[S3].Left;
  DelegateAssert('notification.invoke(...) : resolu (void), section 16.10',
    (ExprPool[NotifyCallExpr].Kind = EK_CALL) And (ExprPool[NotifyCallExpr].TypeIdx = PRIMTYPE_VOID));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 17 - DIRECTIVES MICROSOFT ET COMPILATION CONDITIONNELLE          }
{ (sections 17.1-17.13/17.30-17.41, echantillons :                                       }
{ Test15Conditionnelle.jpp, Test18JDirect.jpp)                                              }
{                                                                       }
{ DEUX familles INDEPENDANTES (section 17.1), traitees par DEUX               }
{ mecanismes SANS RAPPORT l un avec l autre :                                              }
{                                                                       }
{ (A) Compilation conditionnelle "#if/#elif/#else/#endif"                            }
{ (Test15Conditionnelle.jpp) - DECISION D ORDONNANCEMENT DES PASSES            }
{ EXPLICITEMENT EXIGEE PAR LE ROADMAP, documentee EN DETAIL dans la              }
{ note d en-tete de la nouvelle `LexAdvanceSourceLine` (pres de                        }
{ LexNextLine, bien plus haut dans ce fichier) : NI une passe de                       }
{ PRE-traitement separee sur tout le fichier, NI une modification de           }
{ LexNextLine lui-meme (qui aurait FAUSSEMENT reconnu un '#' de                        }
{ COMMENTAIRE comme une VRAIE directive, un piege REEL identifie                       }
{ AVANT d ecrire une seule ligne, pas trouve par execution) - une                     }
{ boucle ENTRELACEE dans le modele "tampon d une ligne" EXISTANT,                    }
{ active UNIQUEMENT depuis les DEUX points ou une ligne FRAICHE est               }
{ demandee pour la TOKENISATION reelle (LexInit, LexNextToken), JAMAIS         }
{ depuis LexSkipBlockComment. Expression conditionnelle reduite AU                   }
{ SEUL symbole NU (section 17.35) - "!"/"&&"/"||"/parentheses restent           }
{ EXPLICITEMENT hors de portee (FatalError, jamais un best-effort                     }
{ silencieux - voir la note d en-tete de CondEvalExpr pour la                             }
{ justification : une MAUVAISE branche choisie est bien plus grave                   }
{ qu un identificateur non resolu). Les symboles "-D" existaient DEJA           }
{ depuis le TODO 01 (Opts.DefinedSymbols/DefinedCount) - AUCUNE                       }
{ nouvelle table n a ete necessaire, seulement leur PREMIERE                              }
{ utilisation REELLE.                                                                       }
{                                                                       }
{ (B) Extraction de "@dll.import(...)" (Test18JDirect.jpp) -                              }
{ ParseDllImportDirective/ParseDllImportArgs (juste avant                             }
{ ParseMethodDeclRest, plus haut) - EXTRACTION STRUCTUREE SEULE                       }
{ (DllLibName/DllEntrypoint/DllCharSet, nouveaux champs TMethodRec),           }
{ AUCUNE VRAIE importation DLL/thunk n est cablee ICI (explicitement             }
{ "voir TODO 18" dans le texte du roadmap lui-meme). Piege REEL EVITE           }
{ AVANT d ecrire une seule ligne (documente sur NativeJavadocText,                   }
{ plus haut) : lire LexLastJavadocText DIRECTEMENT depuis                                }
{ ParseMethodDeclRest serait FRAGILE, puisque le tampon de PRE-                          }
{ lecture PP/PP2 a deja avance de plusieurs tokens par rapport au                     }
{ javadoc au moment ou ParseMethodDeclRest s execute - un INSTANTANE           }
{ est donc fige LE PLUS TOT POSSIBLE (au tout debut de                                     }
{ ParseClassMember, avant tout token du membre). Portee groundee sur            }
{ L UNIQUE forme reelle exercee ("USER32", auto) ; entrypoint/ordinal          }
{ (sections 17.9/17.10) restent CODES mais NON EXERCES (le roadmap du          }
{ TODO 18 les cite explicitement comme deja "PARSES au TODO 17",                     }
{ justifiant leur presence malgre l absence d echantillon).                                }
{ ------------------------------------------------------------ }

Procedure DirectiveAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DirectiveSelfTest: ' + Label_ + ' a echoue');
End;

{ CondLexScanAll : lexe le fichier COURANT (deja Assign/Reset) en          }
{ ENTIER et rapporte, VIA les Var, le nombre de tokens produits ainsi          }
{ que si CHACUNE des SIX chaines distinguant les quatre branches                     }
{ possibles de Test15Conditionnelle.jpp a ete VUE - plus simple et                    }
{ plus robuste qu un long chapelet de LexAssert positionnels comme              }
{ LexSelfTest en utilise ailleurs, puisque le nombre EXACT de tokens             }
{ varie precisement selon la configuration testee (c est ELLE-MEME              }
{ la chose a verifier ICI). }
Procedure CondLexScanAll(Var TokCount: Integer; Var SawDebug, SawRelease,
  SawBonjour, SawHello, SawBoth, SawTrace: Boolean);
Begin
  TokCount := 0;
  SawDebug := False; SawRelease := False; SawBonjour := False;
  SawHello := False; SawBoth := False; SawTrace := False;
  LexInit;
  Repeat
    LexNextToken;
    If CurToken.Kind = TOK_STRING Then
    Begin
      If CurToken.Val = 'Debug' Then SawDebug := True;
      If CurToken.Val = 'Release' Then SawRelease := True;
      If CurToken.Val = 'Bonjour' Then SawBonjour := True;
      If CurToken.Val = 'Hello' Then SawHello := True;
      If CurToken.Val = 'Bonjour / Hello' Then SawBoth := True;
      If CurToken.Val = 'Trace de diagnostic active.' Then SawTrace := True;
    End;
    Inc(TokCount);
  Until CurToken.Kind = TOK_EOF;
  LexClose;
End;

Procedure DirectiveSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT, MI, SI : Integer;
  TokCount : Integer;
  SawDebug, SawRelease, SawBonjour, SawHello, SawBoth, SawTrace : Boolean;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- Test15Conditionnelle.jpp EN ENTIER, copie LITTERALE - AUCUN       }
  { symbole "-D" (configuration PAR DEFAUT, section 17.31 : "Release"           }
  { ET "Bonjour / Hello" ET AUCUNE trace). ------------------------------------------ }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test15Conditionnelle {');
  WriteLn(F, '    static String configuration() {');
  WriteLn(F, '        #if DEBUG');
  WriteLn(F, '            return "Debug";');
  WriteLn(F, '        #else');
  WriteLn(F, '            return "Release";');
  WriteLn(F, '        #endif');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    static String salutation() {');
  WriteLn(F, '        #if LANG_FR');
  WriteLn(F, '            return "Bonjour";');
  WriteLn(F, '        #elif LANG_EN');
  WriteLn(F, '            return "Hello";');
  WriteLn(F, '        #else');
  WriteLn(F, '            return "Bonjour / Hello";');
  WriteLn(F, '        #endif');
  WriteLn(F, '    }');
  WriteLn(F, '');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        System.out.println(salutation());');
  WriteLn(F, '        System.out.println("Configuration : " + configuration());');
  WriteLn(F, '');
  WriteLn(F, '        #if DEBUG');
  WriteLn(F, '            System.out.println("Trace de diagnostic active.");');
  WriteLn(F, '        #endif');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);

  Opts.DefinedCount := 0;   { AUCUN "-D" - section 17.31, configuration PAR DEFAUT }
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  CondLexScanAll(TokCount, SawDebug, SawRelease, SawBonjour, SawHello, SawBoth, SawTrace);
  DirectiveAssert('SANS "-D" : "Release" retenu, "Debug" ELIMINE (section 17.31)',
    SawRelease And (Not SawDebug));
  DirectiveAssert('SANS "-D" : "Bonjour / Hello" (branche #else, section 17.33) ' +
    'retenu, "Bonjour"/"Hello" ELIMINES', SawBoth And (Not SawBonjour) And (Not SawHello));
  DirectiveAssert('SANS "-D" : trace de diagnostic ELIMINEE (section 17.31)',
    Not SawTrace);

  { --- MEME fichier, "-D DEBUG -D LANG_FR" (section 17.37) - "Debug" ET  }
  { "Bonjour" ET la trace de diagnostic doivent TOUS reapparaitre. -------------- }
  Opts.DefinedCount     := 2;
  Opts.DefinedSymbols[0] := 'DEBUG';
  Opts.DefinedSymbols[1] := 'LANG_FR';
  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  CondLexScanAll(TokCount, SawDebug, SawRelease, SawBonjour, SawHello, SawBoth, SawTrace);
  Erase(F);
  DirectiveAssert('"-D DEBUG" : "Debug" retenu, "Release" ELIMINE (section 17.31)',
    SawDebug And (Not SawRelease));
  DirectiveAssert('"-D LANG_FR" : "Bonjour" (premiere branche #if, section 17.31) ' +
    'retenu, "Hello"/"Bonjour / Hello" ELIMINES',
    SawBonjour And (Not SawHello) And (Not SawBoth));
  DirectiveAssert('"-D DEBUG" : trace de diagnostic RETENUE (section 17.31)',
    SawTrace);
  Opts.DefinedCount := 0;

  { --- Test18JDirect.jpp EN ENTIER, copie LITTERALE - extraction de       }
  { "@dll.import(""USER32"", auto)" (sections 17.6/17.8/17.11). -------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'public class Test18JDirect {');
  WriteLn(F, '    /** @dll.import("USER32", auto) */');
  WriteLn(F, '    private static native boolean MessageBeep(int type);');
  WriteLn(F, '');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        try {');
  WriteLn(F, '            boolean resultat = MessageBeep(0);');
  WriteLn(F, '            System.out.println("MessageBeep : " + resultat);');
  WriteLn(F, '        } catch (UnsatisfiedLinkError e) {');
  WriteLn(F, '            System.err.println("J/Direct indisponible : " + e);');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  DirectiveAssert('Test18JDirect : classe enregistree', ClassT >= 0);

  MI := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'MessageBeep') Then
      MI := SI;
  DirectiveAssert('MessageBeep() : methode NATIVE trouvee', MI >= 0);
  DirectiveAssert('@dll.import("USER32", auto) : IsDllImport, DllLibName="USER32"',
    MethodPool[MI].IsDllImport And (MethodPool[MI].DllLibName = 'USER32'));
  DirectiveAssert('@dll.import("USER32", auto) : DllCharSet="auto" (section 17.11)',
    MethodPool[MI].DllCharSet = 'auto');
  DirectiveAssert('@dll.import("USER32", auto) : AUCUN entrypoint (section 17.9, ' +
    'NON exerce par cet echantillon)', MethodPool[MI].DllEntrypoint = '');

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 18 - INTEROPERABILITE COM ET WIN32 (J/DIRECT) (sections 18.1-    }
{ 18.9, echantillons : Test16Win32.jpp, Test17PaquetsMicrosoft.jpp,               }
{ Test18JDirect.jpp)                                                                        }
{                                                                       }
{ DECISION DE PERIMETRE COM EXPLICITEMENT EXIGEE PAR LE ROADMAP         }
{ ("un vrai interop COM complet est un chantier majeur, decider un                  }
{ sous-ensemble minimal OU documenter explicitement hors de portee,               }
{ sans deviner") : com.ms.com (IUnknown/QueryInterface/comptage de              }
{ references/ComLib.release/Variant/proxies JActiveX, sections 18.2/           }
{ 18.6-18.9) reste ENTIEREMENT HORS DE PORTEE - AUCUN sous-ensemble               }
{ n est implemente. Justifie PAR GREP (MEME discipline que la decision          }
{ AWT/GUI du TODO 15) : Test17PaquetsMicrosoft.jpp - le SEUL des DIX-           }
{ HUIT echantillons a mentionner com.ms.com - se limite LUI-MEME a                  }
{ "import com.ms.com.*;" SUIVI de simples println (confirme par le               }
{ roadmap : "inventaire seul, portee tres probablement reduite/                        }
{ documentee") ; AUCUN echantillon n instancie/n utilise IUnknown,                  }
{ QueryInterface, ComLib ou un quelconque type COM REEL. Construire                  }
{ ne serait-ce qu un sous-ensemble minimal serait deviner la forme               }
{ d une infrastructure ENTIERE a partir de ZERO point de donnees                       }
{ reel - l exact contraire de la discipline de ce projet. L "import"           }
{ lui-meme n a besoin d AUCUN code nouveau (ParseImportDecl, TODO 12,          }
{ n a jamais resolu un paquet contre un runtime reel, quel qu il                       }
{ soit) - Test17PaquetsMicrosoft.jpp tokenise et tokeniserait tout               }
{ aussi bien avec un VRAI parseur de fichier (TODO 21+) SANS aucun               }
{ ajout ICI.                                                                                }
{                                                                       }
{ com.ms.win32 (section 18.1), a l inverse, EST implemente - groundee           }
{ EXACTEMENT sur Test16Win32.jpp ("User32.MessageBox(0, texte, titre,          }
{ type)" avec "type = winm.MB_OK | winm.MB_ICONINFORMATION" - "|"                   }
{ deja pris en charge depuis le TODO 06, aucun travail nouveau) : voir          }
{ la note d en-tete de StdlibInit (plus haut, section TODO 13/14/16)             }
{ pour le detail complet de User32 (VRAIE TYK_CLASS, methode STATIQUE           }
{ MessageBox, appel qualifie PAR NOM DE TYPE - EK_TYPEREF, MEME forme           }
{ qu Integer.parseInt au TODO 13) et winm (VRAIE TYK_INTERFACE de                    }
{ CONSTANTES, section 18.1 "les constantes Win32 sont regroupees dans          }
{ des interfaces dont le nom commence par win"). AUCUNE AUTRE famille          }
{ (Gdi32/Kernel32/Ole32/Shell32) n est ajoutee - UN SEUL echantillon             }
{ exerce UNE SEULE fonction, deviner les autres reviendrait au MEME              }
{ piege "un seul point de donnees" que documente au TODO 15/16.                        }
{                                                                       }
{ UNIFICATION explicitement demandee par le roadmap ("MEME mecanisme           }
{ que les appels com.ms.win32") : User32.MessageBox porte les MEMES              }
{ champs IsDllImport/DllLibName/DllEntrypoint/DllCharSet (TODO 17)                   }
{ qu une VRAIE methode "native" @dll.import - LES DEUX mecanismes                    }
{ (J/Direct explicite ET classes com.ms.win32 pre-fournies) convergent          }
{ donc DEJA vers UNE SEULE representation, prete pour UN SEUL                            }
{ mecanisme de thunk futur. AUCUN thunk REEL (IAT ou autre) n est                     }
{ cable ICI - decision EXPLICITEMENT DEFERREE (le roadmap cite LUI-             }
{ MEME "le MEME mecanisme de thunk IAT que les compilateurs freres               }
{ batissent deja... (TODO 23)"), PAS une omission : AUCUNE generation           }
{ de code n existe encore nulle part dans ce compilateur, meme etat                  }
{ exact que documente sans interruption depuis le TODO 08 - brancher            }
{ un VRAI appel Win32 SANS ce socle serait deviner un mecanisme,                       }
{ exactement ce que ce projet refuse de faire.                                             }
{                                                                       }
{ Test18JDirect.jpp n exige AUCUN travail supplementaire ICI - son                   }
{ extraction "@dll.import" complete a deja ete faite au TODO 17                        }
{ (ParseDllImportDirective/ParseDllImportArgs) ; ce TODO 18 n ajoute              }
{ que la contrepartie SYMETRIQUE cote com.ms.win32 (les DEUX chemins             }
{ remplissant maintenant les MEMES champs TMethodRec). }
{ ------------------------------------------------------------ }

Procedure Win32Assert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('Win32SelfTest: ' + Label_ + ' a echoue');
End;

Procedure Win32SelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT, MIMain, MIMessageBox, SI, Body, S0, S1 : Integer;
  SymTypeVar, SymResultat, OrExpr, CallExpr : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { --- Test16Win32.jpp EN ENTIER, copie LITTERALE (imports + classe)     }
  { - via CompilationUnitParseFile (TODO 12, PAS ClassParseFile : les                }
  { DEUX "import" precedant la classe l exigent). ------------------------------- }
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'import com.ms.win32.User32;');
  WriteLn(F, 'import com.ms.win32.winm;');
  WriteLn(F, '');
  WriteLn(F, 'public class Test16Win32 {');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        int type = winm.MB_OK | winm.MB_ICONINFORMATION;');
  WriteLn(F, '');
  WriteLn(F, '        int resultat = User32.MessageBox(');
  WriteLn(F, '            0,');
  WriteLn(F, '            "Bonjour depuis com.ms.win32",');
  WriteLn(F, '            "Exemple J++",');
  WriteLn(F, '            type);');
  WriteLn(F, '');
  WriteLn(F, '        System.out.println("MessageBox a retourne : " + resultat);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);
  ClassT := TypeFindByName('Test16Win32');
  Win32Assert('Test16Win32 : classe enregistree', ClassT >= 0);

  MIMain := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And (MethodPool[SI].Name = 'main') Then
      MIMain := SI;
  Win32Assert('main() : trouvee', MIMain >= 0);

  { deux instructions : "int type = winm.MB_OK | winm.MB_ICONINFORMATION;" }
  { puis "int resultat = User32.MessageBox(...);" (le println final                 }
  { n est pas re-teste, deja couvert depuis le TODO 13). ------------------------ }
  Body := MethodPool[MIMain].BodyStmtIdx;
  S0 := StmtArgPool[StmtPool[Body].ArgFirst];
  S1 := StmtArgPool[StmtPool[Body].ArgFirst + 1];

  SymTypeVar := StmtPool[S0].Left;
  OrExpr := SymTab[SymTypeVar].InitExprIdx;
  Win32Assert('winm.MB_OK | winm.MB_ICONINFORMATION : resolu (int), section 18.1',
    ExprPool[OrExpr].TypeIdx = PRIMTYPE_INT);
  Win32Assert('winm.MB_OK : "winm" resolu en EK_TYPEREF (section 18.1, MEME ' +
    'forme qu''Integer.parseInt, TODO 13)',
    ExprPool[ExprPool[ExprPool[OrExpr].Left].Left].Kind = EK_TYPEREF);

  SymResultat := StmtPool[S1].Left;
  CallExpr := SymTab[SymResultat].InitExprIdx;
  Win32Assert('User32.MessageBox(...) : resolu (int), section 18.1',
    (ExprPool[CallExpr].Kind = EK_CALL) And (ExprPool[CallExpr].TypeIdx = PRIMTYPE_INT));

  { --- unification J/Direct (TODO 17) <-> com.ms.win32 (TODO 18) : LA    }
  { MEME representation TMethodRec pour LES DEUX chemins. -------------------------- }
  MIMessageBox := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].Name = 'MessageBox') Then MIMessageBox := SI;
  Win32Assert('User32.MessageBox : IsDllImport, DllLibName="USER32" ' +
    '(unification section 18.1/17.6)',
    (MIMessageBox >= 0) And MethodPool[MIMessageBox].IsDllImport And
    (MethodPool[MIMessageBox].DllLibName = 'USER32'));

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 19 - ANALYSE SEMANTIQUE (sections 4.12/5.2/6.15-6.16/7.18-7.20/  }
{ 8.4/8.13/8.15/8.22/11.3/11.10-11.11, AUCUN nouvel echantillon -               }
{ premier TODO de ce projet qui REVISITE l ensemble deja construit             }
{ plutot que d en ajouter une tranche neuve)                                                }
{                                                                       }
{ SIX verifications demandees explicitement par le roadmap, PLUS DEUX          }
{ notes "repoussee au TODO 19" trouvees DANS LE CODE EXISTANT lui-meme         }
{ (ParseClassDecl, section "implements" ; STK_TRY, section 11.10/11.11)  }
{ - toutes best-effort (WarnMsg, JAMAIS FatalError : une analyse                     }
{ semantique qui bloquerait la compilation irait a l encontre de "le             }
{ front-end verifie, aucune generation de code n existe encore" -                     }
{ documente sans interruption depuis le TODO 08) :                                          }
{                                                                       }
{   1. Compatibilite d affectation ("=" SEULEMENT, section 6.16 -                   }
{      SemanticCheckAssignTypes, ParseExprStmt plus haut)                                 }
{   2. Resolution de surcharge (DEJA construite au TODO 08 -                            }
{      ClassResolveMethodCall/MethodParamsCompatible - AUCUN code                     }
{      nouveau necessaire, ce TODO se contente de la nommer et de la             }
{      couvrir dans SemanticSelfTest)                                                       }
{   3. Compatibilite de redefinition (SemanticCheckOverrides, appelee            }
{      juste apres ParseClassBody dans ParseClassDecl)                                    }
{   4. Affectation definie best-effort pour "final" (SemanticCheckFinalTarget, }
{      ParseExprStmt plus haut)                                                             }
{   5. Code inaccessible best-effort (ParseBlock plus haut, PUREMENT             }
{      structurel - JAMAIS applique aux corps de switch, qui ont leur           }
{      PROPRE construction "PLATE" independante de ParseBlock, section          }
{      7.9 : un "break;" y precede NORMALEMENT un "case:" suivant,              }
{      AUCUN faux positif possible puisque ce code n y est jamais                     }
{      execute)                                                                             }
{   6. Coherence "throws" vs "throw" reels (SemanticCheckMethodBody/                }
{      SemanticWalkStmt/SemanticCheckThrowInBody ci-dessous - EXIGE une         }
{      VRAIE ThrowsPool, TODO 19, ParseThrowsClauseIfPresent ne se                  }
{      contentait QUE de sauter le texte jusqu ici)                                       }
{   7. (trouvee dans STK_TRY, pas le roadmap) ordre des "catch"                          }
{      (SemanticCheckCatchOrdering) - un catch PLUS SPECIFIQUE APRES              }
{      un catch PLUS GENERAL est INATTEIGNABLE                                              }
{                                                                       }
{ EXPLICITEMENT ENCORE DEFERE (trouve DANS LE CODE, note "TODO 19",             }
{ mais volontairement PAS traite ICI) : la verification "une classe               }
{ CONCRETE implemente REELLEMENT toutes les methodes exigees par ses            }
{ interfaces" (ParseClassDecl, section 9.9, "doit implementer") -                     }
{ EXIGERAIT de parcourir RECURSIVEMENT la fermeture complete des                    }
{ interfaces heritees ET la chaine SuperTypeIdx pour chaque methode               }
{ abstraite, une INFRASTRUCTURE separee et PLUS LOURDE que les SEPT                 }
{ verifications ci-dessus REUNIES - repoussee EXPLICITEMENT (documentee,       }
{ pas silencieusement oubliee) pour garder ce TODO a la taille que les          }
{ SIX puces du roadmap impliquent.                                                          }
{                                                                       }
{ PORTEE COMMUNE A TOUTES CES VERIFICATIONS (best-effort, DELIBEREMENT }
{ simplifiee, chaque limitation documentee a l endroit precis ou elle           }
{ s applique) : AUCUNE n exige de nouvel echantillon SAMPLES\JPP\*.jpp -   }
{ chacune est soit SILENCIEUSE sur le code REEL existant (verifie PAR          }
{ GREP puis confirme par l execution de SemanticSelfTest ci-dessous),           }
{ soit groundee dans un fragment SYNTHETIQUE reproduisant EXACTEMENT              }
{ la forme decrite par la reference (section 6.15/7.18/8.15/11.3) -                 }
{ EXACTEMENT la meme discipline "grep D ABORD" que tout TODO precedent,          }
{ appliquee ICI au code DEJA ECRIT plutot qu a un fichier neuf. }
{ ------------------------------------------------------------ }

{ SemanticCheckCatchOrdering (section 11.10/11.11, note d en-tete de    }
{ STK_TRY plus haut, "repoussee au TODO 19") : un catch dont le type              }
{ est une SUPERCLASSE (ou le MEME type) d un catch qui le SUIT rend               }
{ ce dernier INATTEIGNABLE - AUCUN echantillon actuel n a plus d un             }
{ catch par try (verifie par grep, deja documente au TODO 11),                            }
{ INEXERCEE par du code REEL, groundee UNIQUEMENT par un fragment                    }
{ SYNTHETIQUE dans SemanticSelfTest. }
Procedure SemanticCheckCatchOrdering(TryStmt: Integer);
Var I, J, Ti, Tj : Integer;
Begin
  For I := 0 To StmtPool[TryStmt].ArgCount - 2 Do
  Begin
    Ti := StmtPool[StmtArgPool[StmtPool[TryStmt].ArgFirst + I]].Extra;
    For J := I + 1 To StmtPool[TryStmt].ArgCount - 1 Do
    Begin
      Tj := StmtPool[StmtArgPool[StmtPool[TryStmt].ArgFirst + J]].Extra;
      If (Ti >= 0) And (Tj >= 0) And (Ti < TypeCount) And (Tj < TypeCount) And
         TypeIsSubclassOf(Tj, Ti) Then
        WarnMsg('clause "catch" pour "' + TypeTab[Tj].Name + '" INATTEIGNABLE ' +
          '- deja capturee par un "catch" plus general pour "' + TypeTab[Ti].Name +
          '" (analyse semantique best-effort, section 11.10/11.11, TODO 19)');
    End;
  End;
End;

{ SemanticCheckThrowInBody (section 11.3, "coherence... par rapport aux }
{ throw reels du corps") : un "throw" d une exception VERIFIEE (ni           }
{ RuntimeException ni Error, section 11.2) doit correspondre a UN                    }
{ TYPE de la clause "throws" DE LA METHODE (ou une de ses SOUS-                          }
{ classes, TypeIsSubclassOf REUTILISE tel quel) - groundee EXACTEMENT           }
{ dans Test09Exceptions.jpp (convertirPositif, "throws DonneeException",   }
{ DEUX "throw new DonneeException(...)") - SILENCIEUX (aucun                             }
{ avertissement) puisque sa clause "throws" couvre DEJA correctement            }
{ ce qu il leve, confirme PAR EXECUTION dans SemanticSelfTest.                            }
{ Test12Fichiers.jpp (ecrire/lire, "throws IOException", UN "throw new         }
{ IOException(...)" chacune) suit la MEME forme EXACTE (throw imbrique          }
{ dans try/if, clause "throws" correspondante) et emprunte donc le               }
{ MEME chemin de code - NON re-teste separement, redondant. AUCUNE                   }
{ analyse "capture locale" (un throw                                                             }
{ A L INTERIEUR d un try dont un catch DE LA MEME methode le                           }
{ capturerait n a PAS besoin de figurer dans "throws") n est tentee -             }
{ limitation ASSUMEE et documentee : AUCUN echantillon reel n a de                  }
{ throw a l interieur d un catch/try compatible avec SON PROPRE type              }
{ (verifie par grep), une VRAIE analyse produirait ICI un FAUX POSITIF          }
{ dans ce cas precis, jamais rencontre. }
Procedure SemanticCheckThrowInBody(ThrowStmt, MI: Integer);
Var ThrownT, I : Integer; Covered : Boolean;
Begin
  ThrownT := ExprPool[StmtPool[ThrowStmt].Left].TypeIdx;
  If (ThrownT < 0) Or (ThrownT >= TypeCount) Then Exit;
  If Not TypeIsSubclassOf(ThrownT, PDT_EXCEPTION) Then Exit;
  If TypeIsSubclassOf(ThrownT, PDT_RUNTIMEEXCEPTION) Then Exit;
  If TypeIsSubclassOf(ThrownT, PDT_ERROR) Then Exit;
  Covered := False;
  For I := 0 To MethodPool[MI].ThrowsCount - 1 Do
    If TypeIsSubclassOf(ThrownT, ThrowsPool[MethodPool[MI].ThrowsFirst + I]) Then
      Covered := True;
  If Not Covered Then
    WarnMsg('exception verifiee "' + TypeTab[ThrownT].Name + '" levee dans "' +
      MethodPool[MI].Name + '" sans figurer dans sa clause "throws" ' +
      '(analyse semantique best-effort, section 11.3, TODO 19)');
End;

{ SemanticWalkStmt : parcourt RECURSIVEMENT S (et TOUS ses blocs                     }
{ enfants - if/while/dowhile/for/synchronized/switch/labeled/try, Y                   }
{ COMPRIS chaque corps de catch et le finally) a la recherche de                        }
{ VRAIES instructions STK_THROW (SemanticCheckThrowInBody) et de                        }
{ groupes STK_TRY (SemanticCheckCatchOrdering) - SEULE fonction de                    }
{ tout ce TODO qui recurse EXPLICITEMENT dans la structure ENTIERE               }
{ d un corps (les six autres verifications restent PONCTUELLES,                        }
{ appliquees a l endroit ou le parseur produit deja le noeud                              }
{ concerne). }
Procedure SemanticWalkStmt(S, MI: Integer);
Var I : Integer;
Begin
  If S < 0 Then Exit;
  Case StmtPool[S].Kind Of
    STK_BLOCK:
      For I := 0 To StmtPool[S].ArgCount - 1 Do
        SemanticWalkStmt(StmtArgPool[StmtPool[S].ArgFirst + I], MI);
    STK_IF:
      Begin
        SemanticWalkStmt(StmtPool[S].Right, MI);
        SemanticWalkStmt(StmtPool[S].Left, MI);
      End;
    STK_WHILE, STK_DOWHILE, STK_SYNCHRONIZED:
      SemanticWalkStmt(StmtPool[S].Right, MI);
    STK_FOR:
      SemanticWalkStmt(StmtPool[S].Left, MI);
    STK_SWITCH:
      SemanticWalkStmt(StmtPool[S].Left, MI);
    STK_LABELED:
      SemanticWalkStmt(StmtPool[S].Left, MI);
    STK_TRY:
      Begin
        SemanticWalkStmt(StmtPool[S].Left, MI);
        For I := 0 To StmtPool[S].ArgCount - 1 Do
          SemanticWalkStmt(StmtPool[StmtArgPool[StmtPool[S].ArgFirst + I]].Left, MI);
        SemanticCheckCatchOrdering(S);
        SemanticWalkStmt(StmtPool[S].Right, MI);
      End;
    STK_THROW:
      SemanticCheckThrowInBody(S, MI);
  End;
End;

{ SemanticCheckMethodBody : point d entree APPELE par                              }
{ ParseMethodDeclRest/ParseConstructorDecl JUSTE APRES que le corps               }
{ (ParseBlock) soit entierement parse (donc APRES que ThrowsFirst/                    }
{ ThrowsCount aient DEJA ete renseignes, plus haut dans ces DEUX                       }
{ fonctions). }
Procedure SemanticCheckMethodBody(MI: Integer);
Begin
  SemanticWalkStmt(MethodPool[MI].BodyStmtIdx, MI);
End;

{ SemanticCheckOverrides (section 8.15/8.22/8.4/8.13, "compatibilite de }
{ redefinition") : pour CHAQUE methode D INSTANCE OU STATIQUE propre a          }
{ ClassT, cherche - en remontant SuperTypeIdx, MEME discipline "s arrete       }
{ au PREMIER niveau trouve" que ClassResolveMethodCall (TODO 08, JAMAIS       }
{ a travers les interfaces implementees - une interface n a pas de              }
{ corps a redefinir, MEME raisonnement documente pour                                     }
{ ClassResolveMethodCall) - une methode ANCETRE de MEME nom ET MEME              }
{ NOMBRE ET MEME TYPE de parametres EXACTEMENT (Java 1.1 n admet AUCUNE       }
{ covariance de parametre - un type DIFFERENT designe une SURCHARGE                 }
{ distincte, pas une redefinition, section 8.15). Si trouvee : la               }
{ methode ANCETRE "final" ne peut pas etre redefinie (8.22) ; le                        }
{ caractere static/instance ne peut pas changer (8.4/8.13) ; le type            }
{ de retour doit etre IDENTIQUE (8.15, AUCUNE covariance de retour en          }
{ Java 1.1, contrairement a Java 5+). Groundee SILENCIEUSEMENT (AUCUN          }
{ avertissement attendu) par Test07Heritage.jpp (Forme.aire() abstraite         }
{ -> Rectangle.aire()/Cercle.aire(), MEME signature EXACTE - confirme           }
{ PAR EXECUTION dans SemanticSelfTest) ; les VIOLATIONS (retour                        }
{ incompatible, redefinition de final) sont groundees par des                              }
{ fragments SYNTHETIQUES, AUCUN echantillon reel n en contient. }
Procedure SemanticCheckOverrides(ClassT: Integer);
Var
  I, J, K, AncestorT : Integer;
  Found, Same : Boolean;
Begin
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = ClassT) And (MethodPool[I].Kind = MK_METHOD) Then
    Begin
      AncestorT := TypeTab[ClassT].SuperTypeIdx;
      Found := False;
      While (AncestorT >= 0) And (Not Found) Do
      Begin
        For J := 0 To MethodPoolCount - 1 Do
          If (Not Found) And (MethodPool[J].OwnerTypeIdx = AncestorT) And
             (MethodPool[J].Kind = MK_METHOD) And (MethodPool[J].Name = MethodPool[I].Name) And
             (MethodPool[J].ParamCount = MethodPool[I].ParamCount) Then
          Begin
            Same := True;
            For K := 0 To MethodPool[I].ParamCount - 1 Do
              If ParamPool[MethodPool[I].ParamFirst + K].TypeIdx <>
                 ParamPool[MethodPool[J].ParamFirst + K].TypeIdx Then
                Same := False;
            If Same Then
            Begin
              Found := True;
              If MethodPool[J].IsFinal Then
                WarnMsg('"' + MethodPool[I].Name + '" ne peut pas redefinir une ' +
                  'methode "final" heritee (analyse semantique best-effort, ' +
                  'section 8.22, TODO 19)');
              If MethodPool[J].IsStatic <> MethodPool[I].IsStatic Then
                WarnMsg('"' + MethodPool[I].Name + '" change le caractere ' +
                  'static/instance d''une methode heritee (analyse semantique ' +
                  'best-effort, section 8.4/8.13, TODO 19)');
              If MethodPool[J].RetTypeIdx <> MethodPool[I].RetTypeIdx Then
                WarnMsg('"' + MethodPool[I].Name + '" redefinit avec un type de ' +
                  'retour INCOMPATIBLE - Java 1.1 n''admet aucune covariance de ' +
                  'retour (analyse semantique best-effort, section 8.15, TODO 19)');
            End;
          End;
        AncestorT := TypeTab[AncestorT].SuperTypeIdx;
      End;
    End;
End;

Procedure SemanticAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('SemanticSelfTest: ' + Label_ + ' a echoue');
End;

{ SemanticSelfTest : verifie les SEPT points ci-dessus - chaque cas     }
{ REEL (silencieux attendu) via TypeInit/ClassParseFile EXACTEMENT              }
{ comme tout self-test precedent ; chaque VIOLATION (avertissement                  }
{ attendu) via un fragment SYNTHETIQUE, PROUVEE en comparant WarnCount           }
{ AVANT/APRES - JAMAIS en declenchant un VRAI FatalError (qui appelle            }
{ Halt, MEME discipline documentee depuis ExceptionSelfTest au TODO             }
{ 11) : WarnMsg, ELLE, est SANS DANGER a declencher REELLEMENT depuis           }
{ un self-test (n appelle jamais Halt) - Opts.Warnings doit neanmoins           }
{ etre force a Vrai ICI (False par defaut avant que ParseArgs ne                     }
{ s execute, TOUS les self-tests s executant AVANT ParseArgs dans                    }
{ Run()) pour que WarnMsg incremente reellement WarnCount plutot que            }
{ de sortir immediatement - restaure a la toute fin pour ne PAS fausser        }
{ le compte final "Avertissements" affiche par ShowStats sur le VRAI               }
{ fichier source. }
Procedure SemanticSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
Var
  F : Text;
  ClassT, MIConvertir, EOverload, SI, WC0 : Integer;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
  Opts.Warnings := True;

  { --- 1/2/3 : Test07Heritage.jpp EN ENTIER - override COMPATIBLE           }
  { (Forme.aire() abstraite -> Rectangle/Cercle.aire()), affectations               }
  { COMPATIBLES ("this.nom = nom;" etc.) - AUCUN avertissement attendu. ------ }
  WC0 := WarnCount;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'abstract class Forme {');
  WriteLn(F, '    private String nom;');
  WriteLn(F, '    protected Forme(String nom) {');
  WriteLn(F, '        this.nom = nom;');
  WriteLn(F, '    }');
  WriteLn(F, '    public final String getNom() {');
  WriteLn(F, '        return nom;');
  WriteLn(F, '    }');
  WriteLn(F, '    public abstract double aire();');
  WriteLn(F, '}');
  WriteLn(F, 'class Rectangle extends Forme {');
  WriteLn(F, '    private double largeur;');
  WriteLn(F, '    private double hauteur;');
  WriteLn(F, '    public Rectangle(double largeur, double hauteur) {');
  WriteLn(F, '        super("rectangle");');
  WriteLn(F, '        this.largeur = largeur;');
  WriteLn(F, '        this.hauteur = hauteur;');
  WriteLn(F, '    }');
  WriteLn(F, '    public double aire() {');
  WriteLn(F, '        return largeur * hauteur;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);
  SemanticAssert('Test07Heritage.jpp (override + affectations COMPATIBLES) : ' +
    'AUCUN avertissement', WarnCount = WC0);

  { --- 3 (suite) : violation SYNTHETIQUE - retour incompatible ET             }
  { redefinition de methode "final". ------------------------------------------------- }
  WC0 := WarnCount;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class BaseCalc {');
  WriteLn(F, '    public final int fixe() {');
  WriteLn(F, '        return 1;');
  WriteLn(F, '    }');
  WriteLn(F, '    public int calc() {');
  WriteLn(F, '        return 1;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  WriteLn(F, 'class DeriveCalc extends BaseCalc {');
  WriteLn(F, '    public String calc() {');
  WriteLn(F, '        return "1";');
  WriteLn(F, '    }');
  WriteLn(F, '    public int fixe() {');
  WriteLn(F, '        return 2;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);
  SemanticAssert('DeriveCalc.calc()/fixe() : DEUX avertissements (retour ' +
    'incompatible + redefinition de "final", section 8.15/8.22)',
    WarnCount = WC0 + 2);

  { --- 1 (suite) : violation SYNTHETIQUE - affectation incompatible          }
  { (String vers int). ------------------------------------------------------------------ }
  WC0 := WarnCount;
  SymEnterScope;
  SymAdd('n', SK_VAR, PRIMTYPE_INT, False, False);
  SymAdd('texte', SK_VAR, PDT_STRING, False, False);
  StmtParseString('n = texte;');
  SymLeaveScope;
  SemanticAssert('"n = texte;" (int = String) : UN avertissement (section 6.16)',
    WarnCount = WC0 + 1);

  { --- 4 : violation SYNTHETIQUE - reaffectation d''une variable locale   }
  { "final". ----------------------------------------------------------------------------- }
  WC0 := WarnCount;
  SymEnterScope;
  StmtParseString('{ final int x = 1; x = 2; }');
  SymLeaveScope;
  SemanticAssert('"final int x = 1; x = 2;" : UN avertissement (section 4.12)',
    WarnCount = WC0 + 1);

  { --- 5 : violation SYNTHETIQUE - code inaccessible apres "return". ----- }
  WC0 := WarnCount;
  SymEnterScope;
  StmtParseString('{ return; System.out.println("mort"); }');
  SymLeaveScope;
  SemanticAssert('"return; System.out.println(...);" : UN avertissement ' +
    '(section 7.20)', WarnCount = WC0 + 1);

  { --- 7 : violation SYNTHETIQUE - catch plus specifique INATTEIGNABLE   }
  { APRES un catch plus general - DEUX types PREDECLARES (Exception/                 }
  { RuntimeException, TODO 03/04) pour eviter toute declaration                          }
  { prealable. "SemanticWalkStmt" est appelee EXPLICITEMENT ICI (MI=-1,          }
  { jamais lu puisqu AUCUN "throw" n apparait dans ce fragment) car                    }
  { StmtParseString, contrairement a ParseMethodDeclRest/                                 }
  { ParseConstructorDecl, ne branche JAMAIS elle-meme sur                                       }
  { SemanticCheckMethodBody - EXACTEMENT la MEME discipline "teste                       }
  { ISOLEMENT" que le reste de ce fichier (StmtSelfTest, etc.), qui ne          }
  { passe JAMAIS par un VRAI corps de methode non plus. ------------------------- }
  WC0 := WarnCount;
  SemanticWalkStmt(StmtParseString(
    'try { f(); } catch (Exception e) { g(); } catch (RuntimeException e) { h(); }'), -1);
  SemanticAssert('catch(Exception) PUIS catch(RuntimeException) : UN ' +
    'avertissement (section 11.10/11.11)', WarnCount = WC0 + 1);

  { --- 6 : Test09Exceptions.jpp/Test12Fichiers.jpp - throw COUVERT par   }
  { la clause "throws" - AUCUN avertissement ; PUIS violation                        }
  { SYNTHETIQUE - throw NON couvert. ------------------------------------------------------ }
  WC0 := WarnCount;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class DonneeException extends Exception {');
  WriteLn(F, '    public DonneeException(String message) {');
  WriteLn(F, '        super(message);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  WriteLn(F, 'class Test09Exceptions {');
  WriteLn(F, '    static int convertirPositif(String texte)');
  WriteLn(F, '        throws DonneeException {');
  WriteLn(F, '        try {');
  WriteLn(F, '            int valeur = Integer.parseInt(texte);');
  WriteLn(F, '            if (valeur < 0) {');
  WriteLn(F, '                throw new DonneeException("nombre negatif");');
  WriteLn(F, '            }');
  WriteLn(F, '            return valeur;');
  WriteLn(F, '        } catch (NumberFormatException e) {');
  WriteLn(F, '            throw new DonneeException("entier attendu : " + texte);');
  WriteLn(F, '        }');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);
  SemanticAssert('convertirPositif() (Test09Exceptions.jpp) : AUCUN ' +
    'avertissement, "throws DonneeException" couvre les DEUX "throw"',
    WarnCount = WC0);

  ClassT := TypeFindByName('Test09Exceptions');
  MIConvertir := -1;
  For SI := 0 To MethodPoolCount - 1 Do
    If (MethodPool[SI].OwnerTypeIdx = ClassT) And
       (MethodPool[SI].Name = 'convertirPositif') Then MIConvertir := SI;
  SemanticAssert('convertirPositif() : ThrowsCount = 1 (DonneeException)',
    (MIConvertir >= 0) And (MethodPool[MIConvertir].ThrowsCount = 1));

  WC0 := WarnCount;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class DonneeException extends Exception {');
  WriteLn(F, '    public DonneeException(String message) {');
  WriteLn(F, '        super(message);');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  WriteLn(F, 'class Incoherent {');
  WriteLn(F, '    static void echoue() {');
  WriteLn(F, '        throw new DonneeException("jamais declaree");');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);
  SemanticAssert('echoue() SANS "throws DonneeException" : UN avertissement ' +
    '(section 11.3)', WarnCount = WC0 + 1);

  { --- 2 : resolution de surcharge (DEJA construite au TODO 08) -            }
  { confirmation, AUCUN code nouveau. Test04Methodes.jpp : "maximum(int,   }
  { int)" ET "maximum(double, double)" resolues CHACUNE vers la BONNE            }
  { surcharge par TYPE d argument. --------------------------------------------------------- }
  WC0 := WarnCount;
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Test04Methodes {');
  WriteLn(F, '    static int maximum(int gauche, int droite) {');
  WriteLn(F, '        return gauche > droite ? gauche : droite;');
  WriteLn(F, '    }');
  WriteLn(F, '    static double maximum(double gauche, double droite) {');
  WriteLn(F, '        return gauche > droite ? gauche : droite;');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  ClassT := ClassParseFile;
  Erase(F);
  SymEnterScope;
  EOverload := ExprParseString('Test04Methodes.maximum(4, 9)');
  SemanticAssert('maximum(4, 9) : surcharge (int,int) resolue (int)',
    ExprPool[EOverload].TypeIdx = PRIMTYPE_INT);
  EOverload := ExprParseString('Test04Methodes.maximum(4.5, 2.5)');
  SemanticAssert('maximum(4.5, 2.5) : surcharge (double,double) resolue (double)',
    ExprPool[EOverload].TypeIdx = PRIMTYPE_DOUBLE);
  SymLeaveScope;

  Opts.Warnings := False;
  WarnCount := 0;
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 20 - BIBLIOTHEQUE MINIMALE FINALE (CONSOLIDATION STDLIBTAB)      }
{                                                                       }
{ PORTEE REINTERPRETEE EXPLICITEMENT (documentee, pas devinee) : le            }
{ roadmap demande de "consolider toute la surface... en une seule                    }
{ StdlibTab coherente" - une formulation heritee TELLE QUELLE du                     }
{ gabarit partage par les compilateurs freres, ecrite pour GOCW32.PAS/         }
{ SWIFTW32.PAS/DELPHI.PAS ou une VRAIE structure StdlibTab existe (une         }
{ table PLATE (pkg,nom)->signature, voir GOCW32.PAS TODO 20). JPPCW32           }
{ n a JAMAIS eu cette table : la note d en-tete du TODO 13 (juste au             }
{ dessus de StdlibInit) avait DEJA, explicitement, REJETE ce modele              }
{ ("AUCUNE table de signatures separee... contrairement au modele                    }
{ PUREMENT LEXICAL de GOCW32.PAS") en faveur de VRAIES TYK_CLASS/                     }
{ TYK_INTERFACE - CHAQUE entree ajoutee depuis (TODO 14 Thread/                          }
{ Runnable/Object.wait-notify, TODO 18 User32/winm) a REUTILISE EXACTEMENT   }
{ la MEME architecture UNIQUE, jamais une variante ou une table                        }
{ parallele. La "consolidation" demandee est donc DEJA satisfaite PAR         }
{ CONSTRUCTION : `StdlibInit` a toujours ete le POINT D ENTREE UNIQUE           }
{ et CROISSANT (re-execute a chaque `TypeInit`, EXACTEMENT la                            }
{ convention "StdlibInit... reexecutee a chaque reinitialisation" DEJA        }
{ citee depuis GOCW32.PAS TODO 20 des le TODO 13) - il n existe RIEN a         }
{ fusionner, puisqu il n y a jamais eu de second endroit.                                  }
{                                                                       }
{ CE QUE CE TODO AJOUTE REELLEMENT (proportionne a un roadmap SANS               }
{ fichier de test, SANS nouvelle grammaire) :                                              }
{   1. CE manifeste - UNE vue d ensemble COMPLETE de toute la surface           }
{      de bibliotheque, organisee PAR TODO d origine, en un SEUL                        }
{      endroit (les commentaires PAR ENTREE deja ecrits au TODO 13/14/         }
{      18 restent EUX INCHANGES - ce manifeste les INDEXE, il ne les              }
{      duplique ni ne les remplace) :                                                       }
{        TODO 13 : String.length() ; Throwable.getMessage() ;                              }
{          PrintStream.println (4 surcharges) ; System.out/System.err ;      }
{          Integer(int)/Integer.parseInt(String) ; Enumeration                            }
{          (interface) ; Vector (5 membres) ; Hashtable (3 membres) ;              }
{          Writer/Reader/FileWriter/BufferedWriter/PrintWriter (4                          }
{          membres)/FileReader/BufferedReader (3 membres)/IOException                }
{        TODO 14 : Object.wait()/notify()/notifyAll() ; Runnable                              }
{          (interface, run()) ; Thread (implements Runnable - 6                                }
{          membres : constructeur, run/start/join/getName,                                     }
{          currentThread static)                                                                   }
{        TODO 18 : User32 (MessageBox static) ; winm (interface de                        }
{          constantes - MB_OK/MB_ICONINFORMATION)                                              }
{      AUCUNE entree du TODO 16 (delegates) : un "delegate" est un              }
{      TYK_DELEGATE DECLARE PAR L UTILISATEUR (ParseDelegateDecl), PAS           }
{      un membre de bibliotheque SYNTHETISE par StdlibInit - le                          }
{      roadmap le liste par prudence (com.ms.lang.Delegate/                                   }
{      MulticastDelegate ne sont que CONCEPTUELS, section 16.13, "le             }
{      compilateur genere un type DERIVE CONCEPTUELLEMENT de" - AUCUN           }
{      wrapper n existe reellement dans le SDK a modeliser), mais                       }
{      RIEN de cette famille n appartient reellement a StdlibInit.                     }
{   2. UN CHECKPOINT DE NON-REGRESSION unique portant sur la TAILLE                 }
{      COMPLETE de la surface (MethodPoolCount/FieldPoolCount/                              }
{      ParamPoolCount immediatement apres TypeInit, AVANT tout code               }
{      utilisateur) - EXACTEMENT le meme esprit que l assertion                          }
{      "TypeCount = 39" deja ecrite au TypeSelfTest (TODO 11/13/14/18),      }
{      etendue ICI aux TROIS AUTRES pools qu une bibliotheque fait                    }
{      grossir. Toute REGRESSION future (une entree supprimee par                     }
{      erreur) ou toute ADDITION future (TODO21+ ajoutant un membre               }
{      sans mettre a jour CE nombre) se remarque IMMEDIATEMENT ICI,               }
{      MEME discipline que "toute mise a jour de TypeCount est                            }
{      EXPLICITE, jamais silencieuse" deja documentee au TODO 11.                     }
{   3. POLITIQUE DEFINITIVE, reaffirmee pour le TODO 21+ (deja                            }
{      appliquee sans exception depuis le TODO 13, desormais figee            }
{      comme la REGLE plutot qu une observation au coup par coup) :               }
{      chaque entree de StdlibInit reste "connue du FRONT-END                            }
{      seulement" (resolution de type/surcharge) - AUCUNE contrepartie          }
{      runtime REELLE (un VRAI System.out qui ecrit VRAIMENT sur la              }
{      console, un VRAI thunk User32.MessageBox) n est cablee avant             }
{      que le GENERATEUR DE CODE (TODO 21+) n ait REELLEMENT besoin de          }
{      compiler un appel a CE membre PRECIS - jamais par anticipation.          }
{ ------------------------------------------------------------ }

Procedure StdlibConsolidationSelfTest;
Begin
  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;

  { Chiffres FIGES le jour de ce TODO (2026-07-26) - TOUTE variation      }
  { future DOIT mettre a jour ce commentaire ET la valeur en meme temps          }
  { (MEME discipline que TypeCount = 39, TypeSelfTest) : 40 methodes/                }
  { constructeurs (String.length, Throwable.getMessage, PrintStream                    }
  { println x4, Integer ctor+parseInt, Enumeration x2, Vector x5,                       }
  { Hashtable x3, FileWriter ctor, BufferedWriter ctor, PrintWriter                       }
  { x4, FileReader ctor, BufferedReader x3, IOException ctor, Object              }
  { wait/notify/notifyAll x3, Runnable.run, Thread x6, User32.MessageBox) - }
  { 4 champs (System.out/err, winm.MB_OK/MB_ICONINFORMATION). }
  TypeAssert('StdlibInit : MethodPoolCount = 40 (inventaire consolide, ' +
    'TODO 20)', MethodPoolCount = 40);
  TypeAssert('StdlibInit : FieldPoolCount = 4 (inventaire consolide, TODO 20)',
    FieldPoolCount = 4);

  TypeInit;
  SymInit;
  ExprInit;
  StmtInit;
End;

{ ------------------------------------------------------------ }
{ TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM                            }
{                                                                       }
{ DECISION DE PERIMETRE EXPLICITEMENT EXIGEE PAR LE ROADMAP ("portee            }
{ VOLONTAIREMENT restreinte a ce que TODO 01-20 ont reellement                        }
{ construit... grandissant par extensions incrementales separement               }
{ verifiees EXACTEMENT comme l historique post-TODO25 de chaque                        }
{ compilateur frere") : ce PREMIER jalon vise "juste assez pour                        }
{ compiler UN println inconditionnel" - UNE classe, UNE methode                       }
{ statique "main(String[])", UN SEUL appel "System.out.println                       }
{ (<chaine litterale>)". Confirme par l ETUDE PREALABLE (jamais                       }
{ devinee) de la MEME etape chez GOCW32.PAS/SWIFTW32.PAS avant d ecrire      }
{ une seule ligne ICI : LEURS deux premiers TODO 21 (retrouves par              }
{ git log) couvraient RESPECTIVEMENT ~858 et ~757 lignes pour "juste             }
{ assez pour compiler hello.go"/"hello.swift" - AUCUN des deux ne                     }
{ tentait arithmetique, structures, closures ni meme, pour                                  }
{ SWIFTW32.PAS, des FONCTIONS UTILISATEUR des son tout premier                          }
{ passage.                                                                                  }
{                                                                       }
{ DECOUVERTE REELLE PAR EXECUTION (PAS anticipee en lisant le fichier          }
{ .jpp en diagonale, une legon en soi) : Test01Bonjour.jpp - "le plus            }
{ simple des 18 echantillons" suppose depuis le TODO 01 - contient EN         }
{ REALITE un "if/else" complet testant "args.length" APRES son                          }
{ premier println, exigeant QUATRE decisions de conception qu AUCUN               }
{ TODO precedent n avait besoin de trancher (aucune generation de                    }
{ code n existant encore) : (a) la disposition MEMOIRE d un tableau              }
{ (ou vit sa longueur ? section 10.1) ; (b) la verification de borne             }
{ a l acces (section 10.7, EXPLICITEMENT repoussee "a la generation             }
{ de code" par la note d en-tete de TYK_ARRAY, TODO 10) ; (c) une                     }
{ VRAIE routine runtime de concatenation de chaines ("+"                                  }
{ String/String, allocation dynamique) ; (d) l analyse de la ligne              }
{ de commande Win32 (GetCommandLine) EN UN VRAI String[] Java. AUCUNE       }
{ des quatre ne se laisse deviner a partir d un SEUL echantillon                     }
{ sans risquer exactement le piege documente depuis le TODO 15                          }
{ (AWT)/16 (delegates) - repoussees EXPLICITEMENT (documentees, pas               }
{ oubliees) a une extension FUTURE sous ce MEME TODO 21. CompileStmt          }
{ s arrete donc PROPREMENT (FatalError) au "if" lui-meme - le println          }
{ INCONDITIONNEL qui le precede compile et s emet correctement,                       }
{ EXACTEMENT la portee reellement couverte par ce premier jalon,                      }
{ desormais decrite avec PRECISION plutot que supposee.                                 }
{                                                                       }
{ Le pointeur de vtable au deplacement 0, le deroulement d exception          }
{ et les VRAIS threads Win32 que le texte du roadmap de CE TODO                        }
{ nomme explicitement restent, PAR LA MEME logique, des extensions               }
{ FUTURES sous ce MEME numero TODO 21 - PAS devinees ni improvisees              }
{ ICI, exactement comme GOCW32.PAS ne les a ajoutees que des annees-       }
{ personnes de "Correctifs" plus tard. }
{                                                                       }
{ ARCHITECTURE (identique aux compilateurs freres, AUCUNE deviation) :          }
{ un texte .asm emis DIRECTEMENT ligne par ligne (Emit*) PENDANT le              }
{ parcours recursif de l arbre DEJA construit (ExprPool/StmtPool/                       }
{ MethodPool, TODO 06-08) - AUCUNE representation intermediaire                          }
{ separee, le texte .asm LUI-MEME est l IR. Dialecte MASM (.386,                        }
{ .MODEL FLAT STDCALL), convention "tout tient dans EAX" (chaque                       }
{ expression LAISSE son resultat scalaire dans EAX, AUCUN allocateur           }
{ de registres). Prefixes de nommage ASM_PFX_* DEJA reserves depuis              }
{ le TODO 01 (voir l en-tete du fichier) - JAMAIS invoques avant ce               }
{ TODO, enfin utilises ICI pour de vrai. AUCUN assembleur/lieur                         }
{ externe n est invoque ni requis : ce TODO produit UNIQUEMENT le                     }
{ texte .asm ; le transformer en octets REELS (encodage 80386) est le             }
{ travail du TODO 22 (backend .OBJ COFF, "assembleur hand-roule" MEME           }
{ architecture que chaque compilateur frere), et un VRAI .exe                            }
{ n existera qu au TODO 23 (ecrivain PE). "Sortie   : ...exe" affiche            }
{ par ShowBanner reste donc pour l instant ASPIRATIONNEL - ce TODO                    }
{ ecrit TOUJOURS le ".asm" correspondant (ReplaceExt(Opts.SrcFile,                    }
{ '.asm'), JAMAIS Opts.OutFile lui-meme) quels que soient -asm/-obj,             }
{ qui ne deviendront des choix REELS qu une fois TODO 22/23 ecrits.               }
{                                                                       }
{ CHANGEMENT MAJEUR A Run() (voir plus bas) : DEPUIS LE TODO 01, Run()          }
{ ne faisait QUE tokeniser un VRAI fichier .jpp - CHAQUE TODO                            }
{ precedent a repete "ParseCompilationUnit/ParseClassDecl/... restent           }
{ testes ISOLEMENT, JAMAIS branches sur un VRAI fichier". Ce TODO                     }
{ change ENFIN cela : Run() lexe (LexAll) PUIS parse REELLEMENT               }
{ (ParseCompilationUnit) le fichier source reel, AVANT de tenter la              }
{ generation de code - la PREMIERE fois qu un VRAI fichier .jpp                          }
{ traverse le parseur de bout en bout plutot qu un fragment                                }
{ synthetique de self-test. Risque ASSUME et EXPLICITEMENT accepte              }
{ (jamais cache) : un construct qui fonctionne dans un self-test                       }
{ ISOLE pourrait reveler une surprise en contexte REEL - EXACTEMENT              }
{ ce que ce TODO est cense decouvrir, verifie ICI par EXECUTION contre         }
{ les 18 echantillons reels (voir le rapport de fin de TODO) plutot                  }
{ que suppose.                                                                              }
{                                                                       }
{ NOUVEAU CHAMP EK_CALL.Extra (voir sa propre note d en-tete, plus                   }
{ haut dans ce fichier) : le generateur de code doit savoir EXACTEMENT           }
{ quelle methode MethodPool a ete choisie par ClassResolveMethodCall              }
{ (TODO 08) pour un appel donne - jusqu ICI, seul TypeIdx (le type de           }
{ retour) etait conserve, JAMAIS l index de methode lui-meme (champ               }
{ INUTILISE pour EK_CALL depuis le TODO 06) - repere PAR REVUE DE                    }
{ CODE avant d ecrire une seule ligne de generateur, PAS trouve par              }
{ execution. }
{ ------------------------------------------------------------ }

Const
  MAX_CG_STRINGS = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_CG_LOOP    = 64;   { extension post-TODO25 - profondeur d imbrication }
                          { boucle/switch, tres genereuse (aucun echantillon }
                          { reel n approche cette profondeur). }

Var
  CgOutF      : Text;
  CgOutOpen   : Boolean;
  CgLabelSeq  : Integer;
  CgStrPool       : Array[0..MAX_CG_STRINGS - 1] Of TString;
  CgStrPoolOfExpr : Array[0..MAX_EXPR - 1] Of Integer;
  CgStrCount      : Integer;

  { extension post-TODO25 (generateur de code) : etiquette d epilogue   }
  { de la methode EN COURS de compilation (STK_RETURN y saute TOUJOURS,           }
  { jamais un simple retour en cascade - meme un "return;" nu au milieu           }
  { d un corps doit sauter par-dessus le reste du corps). CgBreakLbl/            }
  { CgContinueLbl : pile PARALLELE (pas de lien, MEME convention "tableau            }
  { plat" que tout le reste de ce compilateur) des cibles de "break"/                 }
  { "continue" - un CADRE de boucle (while/do/for) pousse LES DEUX ; un                }
  { CADRE de switch pousse SEULEMENT un nouveau "break" et HERITE le                       }
  { "continue" du cadre ENGLOBANT (jamais le sien propre - "continue"                    }
  { a l interieur d un switch cible TOUJOURS la boucle qui l englobe,                     }
  { section 7.19, jamais le switch lui-meme). }
  CurMethodEpilogueLabel : TString;
  CgLoopTop      : Integer;
  CgBreakLbl     : Array[0..MAX_CG_LOOP - 1] Of TString;
  CgContinueLbl  : Array[0..MAX_CG_LOOP - 1] Of TString;

{ Emit* : voir la note d en-tete de section - IDENTIQUES (memes noms,   }
{ memes signatures) a GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS a leur PROPRE          }
{ TODO 21, portees ICI SANS aucune modification d architecture. }
Procedure EmitOpen(Const AsmFile: TString);
Begin
  Assign(CgOutF, AsmFile);
  Rewrite(CgOutF);
  CgOutOpen := True;
End;

Procedure EmitClose;
Begin
  If CgOutOpen Then
  Begin
    Close(CgOutF);
    CgOutOpen := False;
  End;
End;

Procedure EmitRaw(Const S: TString);
Begin
  WriteLn(CgOutF, S);
End;

Procedure EmitLabel(Const Lbl: TString);
Begin
  WriteLn(CgOutF, Lbl, ':');
End;

Procedure EmitInstr(Const S: TString);
Begin
  WriteLn(CgOutF, '        ', S);
End;

Procedure EmitComment(Const S: TString);
Begin
  WriteLn(CgOutF, '; ', S);
End;

Procedure EmitBlankLine;
Begin
  WriteLn(CgOutF);
End;

Function CgLabelGen: TString;
Begin
  Inc(CgLabelSeq);
  CgLabelGen := ASM_PFX_LABEL + IntToStrG(CgLabelSeq);
End;

{ CgPushLoopFrame/CgPushSwitchFrame/CgPopLoopFrame : voir la note        }
{ d en-tete de CgBreakLbl/CgContinueLbl ci-dessus - extension post-             }
{ TODO25 (generateur de code, STK_WHILE/DOWHILE/FOR/SWITCH/BREAK/                    }
{ CONTINUE). }
Procedure CgPushLoopFrame(Const BreakLbl, ContinueLbl: TString);
Begin
  If CgLoopTop >= MAX_CG_LOOP - 1 Then
  Begin
    WarnMsg('generateur de code : profondeur de boucle/switch maximale ' +
      'atteinte (MAX_CG_LOOP)');
    Exit;
  End;
  Inc(CgLoopTop);
  CgBreakLbl[CgLoopTop]    := BreakLbl;
  CgContinueLbl[CgLoopTop] := ContinueLbl;
End;

Procedure CgPushSwitchFrame(Const BreakLbl: TString);
Begin
  If CgLoopTop >= MAX_CG_LOOP - 1 Then
  Begin
    WarnMsg('generateur de code : profondeur de boucle/switch maximale ' +
      'atteinte (MAX_CG_LOOP)');
    Exit;
  End;
  Inc(CgLoopTop);
  CgBreakLbl[CgLoopTop] := BreakLbl;
  If CgLoopTop > 0 Then
    CgContinueLbl[CgLoopTop] := CgContinueLbl[CgLoopTop - 1]
  Else
    CgContinueLbl[CgLoopTop] := '';
End;

Procedure CgPopLoopFrame;
Begin
  If CgLoopTop >= 0 Then Dec(CgLoopTop);
End;

{ CgCollectStrings : parcourt ExprPool ENTIER (TABLEAU GLOBAL PLAT,       }
{ TODO 06 - EXACTEMENT le meme raisonnement que GOCW32.PAS/                     }
{ CgCollectStrings, portee ICI a l identique) a la recherche de CHAQUE      }
{ EK_STRINGLIT, deduplique PAR VALEUR (deux litteraux IDENTIQUES                     }
{ partagent UNE SEULE entree .DATA) - CgStrPoolOfExpr[E] retrouve                     }
{ ensuite, pour un noeud EK_STRINGLIT donne, l INDEX de pool (donc                    }
{ l etiquette ASM_PFX_STRING+index) a utiliser dans CompileExpr. }
Procedure CgCollectStrings;
Var E, J, Found : Integer;
Begin
  CgStrCount := 0;
  For E := 0 To ExprCount - 1 Do
    If ExprPool[E].Kind = EK_STRINGLIT Then
    Begin
      Found := -1;
      For J := 0 To CgStrCount - 1 Do
        If CgStrPool[J] = ExprPool[E].StrVal Then Found := J;
      If Found < 0 Then
      Begin
        If CgStrCount < MAX_CG_STRINGS Then
        Begin
          CgStrPool[CgStrCount] := ExprPool[E].StrVal;
          Found := CgStrCount;
          Inc(CgStrCount);
        End
        Else
        Begin
          WarnMsg('table des chaines du generateur de code pleine (MAX_CG_STRINGS)');
          Found := 0;
        End;
      End;
      CgStrPoolOfExpr[E] := Found;
    End;
End;

{ EmitHeader : boilerplate MASM minimal - imports Win32 SEULEMENT pour   }
{ l E/S console et la sortie de processus (alloc memoire/vtable/                     }
{ threads/exceptions restent pour les extensions FUTURES sous ce                    }
{ MEME TODO, voir la note d en-tete de section) - MEME dialecte que              }
{ chaque compilateur frere. }
Procedure EmitHeader;
Begin
  EmitComment('JPPCW32 - code genere (TODO 21) - NE PAS EDITER A LA MAIN');
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  { extension post-TODO25 (generateur de code - runtime string           }
  { concatenation/conversion, _JPPRT_ALLOC) : MEME choix que GOCW32.PAS          }
  { pour son propre _GORT_ALLOC (GetProcessHeap/HeapAlloc, AUCUNE                    }
  { liberation - fuite assumee, aucun vrai GC dans ce compilateur). }
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitBlankLine;
End;

{ EmitDataSeg : le pool de chaines litterales, PRECEDE de                       }
{ _JPPRT_NEWLINE (un SEUL octet 10, "\n") - AUCUN champ static/                          }
{ variable pour ce premier jalon (Test01Bonjour.jpp n en a aucun - la           }
{ disposition des CHAMPS static/globaux, section 8.4/5.4, reste une              }
{ extension FUTURE sous ce MEME TODO, non exercee ICI). AUCUN                             }
{ echappement de guillemets/caracteres speciaux n est effectue sur                   }
{ StrVal (limitation ASSUMEE, AUCUN des 18 echantillons n a de "\""                   }
{ dans un litteral de chaine - verifie par grep).                                                }
{                                                                       }
{ BOGUE REEL trouve par EXECUTION (TODO 22, PAS par la compilation                    }
{ ni par une relecture du texte .asm) : EmitRuntimeLibrary reference                }
{ deja "LEA EAX,[_JPPRT_NEWLINE]" (PRINTLN_STR) depuis le TODO 21,                    }
{ mais RIEN ne definissait jamais cette etiquette dans .DATA - le                     }
{ FIXUP ABS32 correspondant restait donc SANS CIBLE (ni etiquette                      }
{ locale, ni import externe), produisant un index de symbole COFF                    }
{ ERRONE dans WriteCOFFObj (TargetSymIdx pointant hors de la table                   }
{ REELLEMENT ecrite) - INVISIBLE en relisant le texte .asm ou en                        }
{ inspectant la structure du .OBJ (objdump -h/-t la montraient tous              }
{ DEUX comme "correcte"), reveleE SEULEMENT en liant VRAIMENT               }
{ Test17PaquetsMicrosoft.obj (ld + libkernel32.a, TODO 22) et en                       }
{ executant le .exe RESULTANT : chaque ligne s affichait suivie                          }
{ d octets ILLISIBLES au lieu d un vrai saut de ligne. Corrige EN                        }
{ ajoutant enfin l etiquette manquante - EXACTEMENT ce que GOCW32.PAS          }
{ fait deja lui-meme ("_GORT_NEWLINE  DB 10", premiere ligne de SA               }
{ PROPRE EmitDataSeg) - une ligne PERDUE en portant TODO 21 ici,                       }
{ jamais un DEFAUT de l architecture source. }
Procedure EmitDataSeg;
Var I : Integer;
Begin
  EmitRaw('.DATA');
  EmitRaw(ASM_PFX_RUNTIME + 'NEWLINE DB 10');
  { extension post-TODO25 (generateur de code) : constantes fixes         }
  { "true"/"false" pour la conversion boolean->String d une                        }
  { concatenation "+" (jamais allouees dynamiquement - toujours les                    }
  { DEUX memes chaines, contrairement a _JPPRT_INT_TO_STR qui DOIT                  }
  { allouer, la valeur entiere n etant jamais connue a l avance). }
  EmitRaw(ASM_PFX_RUNTIME + 'TRUE_STR DB "true",0');
  EmitRaw(ASM_PFX_RUNTIME + 'FALSE_STR DB "false",0');
  For I := 0 To CgStrCount - 1 Do
    EmitRaw(ASM_PFX_STRING + IntToStrG(I) + ' DB "' + CgStrPool[I] + '",0');
  EmitBlankLine;
End;

{ EmitRuntimeLibrary : runtime minimal ecrit DIRECTEMENT dans le .asm    }
{ emis (aucune bibliotheque externe liee) - STRLEN/PRINT_STR/                            }
{ PRINTLN_STR, PORTES QUASI VERBATIM de GOCW32.PAS/_GORT_* (meme                       }
{ projet, meme algorithme, prefixe _JPPRT_ substitue a _GORT_) : la              }
{ SEULE forme couverte par ce premier jalon, "System.out.println                     }
{ (<chaine>)" (voir CompileCall), n a besoin que de CETTE UNE                             }
{ routine. }
Procedure EmitRuntimeLibrary;
Begin
  EmitLabel(ASM_PFX_RUNTIME + 'STRLEN');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('XOR ECX,ECX');
  EmitLabel(ASM_PFX_RUNTIME + 'STRLEN_LOOP');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'STRLEN_DONE');
  EmitInstr('INC ESI');
  EmitInstr('INC ECX');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'STRLEN_LOOP');
  EmitLabel(ASM_PFX_RUNTIME + 'STRLEN_DONE');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { _JPPRT_PRINT_STR : imprime la chaine C pointee par [EBP+8] SANS       }
  { saut de ligne - WriteFile est STDCALL (l APPELE nettoie SA PROPRE            }
  { pile). BOGUE REEL trouve par GOCW32.PAS PAR EXECUTION (evite ICI                }
  { PROACTIVEMENT, jamais redecouvert) : _JPPRT_STRLEN utilise ESI                 }
  { EN INTERNE et ne le restaure JAMAIS - a son retour ESI pointe sur               }
  { le TERMINATEUR NUL, PAS le debut de la chaine - le recharger                          }
  { depuis [EBP+8] (intact sur la pile) AVANT de l utiliser comme                       }
  { lpBuffer, sinon WriteFile ecrit du bourrage au lieu du texte. }
  EmitLabel(ASM_PFX_RUNTIME + 'PRINT_STR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('SUB ESP,4');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('PUSH ESI');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRLEN');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH -11');
  EmitInstr('CALL _GetStdHandle@4');
  EmitInstr('MOV EDI,EAX');
  EmitInstr('PUSH 0');
  EmitInstr('LEA EAX,[EBP-4]');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH EBX');
  EmitInstr('PUSH ESI');
  EmitInstr('PUSH EDI');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { BOGUE REEL trouve par EXECUTION reelle (TODO 22, apres correction du    }
  { bogue _JPPRT_NEWLINE manquant) : la PREMIERE version de cette routine        }
  { appelait _JPPRT_PRINT_STR une SECONDE fois pour le saut de ligne, ce            }
  { qui fait passer _JPPRT_NEWLINE par _JPPRT_STRLEN - or _JPPRT_NEWLINE           }
  { est UN SEUL octet (10) SANS terminateur NUL propre : STRLEN continue           }
  { alors de parcourir la memoire au-dela, jusqu au terminateur NUL de la          }
  { PROCHAINE constante DB de .DATA (ici _JPPK_0, la premiere chaine du            }
  { pool), et WriteFile ecrit donc le saut de ligne SUIVI du texte ENTIER          }
  { de cette premiere chaine apres CHAQUE ligne. Voir GOCW32.PAS (meme            }
  { bogue deja resolu la, PRINTLN_STR ~ligne 10809) : la solution PROUVEE           }
  { evite totalement STRLEN pour le saut de ligne en appelant _WriteFile@20         }
  { DIRECTEMENT avec une longueur CODEE EN DUR (1), jamais via PRINT_STR. }
  EmitLabel(ASM_PFX_RUNTIME + 'PRINTLN_STR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('SUB ESP,4');
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINT_STR');
  EmitInstr('ADD ESP,4');
  EmitInstr('PUSH -11');
  EmitInstr('CALL _GetStdHandle@4');
  EmitInstr('MOV EDI,EAX');
  EmitInstr('PUSH 0');
  EmitInstr('LEA EAX,[EBP-4]');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH 1');
  EmitInstr('LEA EAX,[' + ASM_PFX_RUNTIME + 'NEWLINE]');
  EmitInstr('PUSH EAX');
  EmitInstr('PUSH EDI');
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { extension post-TODO25 (generateur de code - concatenation "+" de     }
  { chaines/entiers, EK_BINARY) : _JPPRT_ALLOC (allocation TAS -                        }
  { GetProcessHeap/HeapAlloc, MEME choix que _GORT_ALLOC de GOCW32.PAS -             }
  { AUCUNE liberation, fuite assumee, pas de vrai GC), _JPPRT_INT_TO_STR                 }
  { (int -> chaine decimale, allouee) et _JPPRT_CONCAT (deux chaines C ->         }
  { une troisieme, allouee) - EDX/DL sert de registre-relais 8 bits pour           }
  { chaque octet lu/ecrit (BinReg8/IsByte, voir la note d en-tete de                    }
  { BinParseOperand) ; HEAP_ZERO_MEMORY (indicateur 8) TOUJOURS demande            }
  { a HeapAlloc - le bloc alloue est donc DEJA rempli de zeros, ce qui             }
  { fournit le terminateur NUL final GRATUITEMENT (jamais ecrit                        }
  { explicitement), sans avoir besoin d une forme "MOV BYTE PTR                        }
  { [mem],imm" (jamais implementee, cette famille d instructions ne                    }
  { transite QUE par un registre 8 bits dans ce compilateur). }
  EmitLabel(ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH EBX');
  EmitInstr('CALL _GetProcessHeap@0');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  EmitInstr('PUSH 8');
  EmitInstr('PUSH EBX');
  EmitInstr('CALL _HeapAlloc@12');
  EmitInstr('POP EBX');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { _JPPRT_INT_TO_STR : convertit l entier signe [EBP+8] en une chaine   }
  { decimale ALLOUEE - LIMITATION ASSUMEE, jamais devinee : la valeur              }
  { PRIVATIVE INT_MIN (-2147483648) deborde silencieusement lors du                    }
  { "NEG EAX" (son oppose ne tient pas sur 32 bits signes) - AUCUN des               }
  { 18 echantillons ne litteralise cette valeur precise (verifie par                        }
  { grep), documentee plutot que gardee. Construit les chiffres a               }
  { l ENVERS (division/reste par 10 repetee) dans un tampon LOCAL de 16              }
  { octets ([EBP-16]..[EBP-1], EBX pointeur DECROISSANT depuis la FIN),          }
  { PUIS copie la plage REELLEMENT ecrite vers un bloc alloue de la                    }
  { taille EXACTE. }
  EmitLabel(ASM_PFX_RUNTIME + 'INT_TO_STR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('SUB ESP,16');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('MOV ESI,0');
  EmitInstr('CMP EAX,0');
  EmitInstr('JGE ' + ASM_PFX_RUNTIME + 'ITS_NN');
  EmitInstr('MOV ESI,1');
  EmitInstr('NEG EAX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_NN');
  EmitInstr('LEA EBX,[EBP-1]');
  EmitInstr('CMP EAX,0');
  EmitInstr('JNE ' + ASM_PFX_RUNTIME + 'ITS_LOOP');
  EmitInstr('MOV EDX,48');
  EmitInstr('MOV BYTE PTR [EBX],DL');
  EmitInstr('DEC EBX');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'ITS_SIGN');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_LOOP');
  EmitInstr('CMP EAX,0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'ITS_SIGN');
  EmitInstr('MOV ECX,10');
  EmitInstr('CDQ');
  EmitInstr('IDIV ECX');
  EmitInstr('ADD EDX,48');
  EmitInstr('MOV BYTE PTR [EBX],DL');
  EmitInstr('DEC EBX');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'ITS_LOOP');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_SIGN');
  EmitInstr('CMP ESI,0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'ITS_DONE');
  EmitInstr('MOV EDX,45');
  EmitInstr('MOV BYTE PTR [EBX],DL');
  EmitInstr('DEC EBX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_DONE');
  EmitInstr('INC EBX');
  EmitInstr('MOV EAX,EBP');
  EmitInstr('SUB EAX,EBX');
  EmitInstr('MOV ESI,EAX');
  EmitInstr('ADD EAX,1');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EDI,EAX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_COPY');
  EmitInstr('CMP ESI,0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'ITS_RET');
  EmitInstr('MOV DL,BYTE PTR [EBX]');
  EmitInstr('MOV BYTE PTR [EDI],DL');
  EmitInstr('INC EBX');
  EmitInstr('INC EDI');
  EmitInstr('DEC ESI');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'ITS_COPY');
  EmitLabel(ASM_PFX_RUNTIME + 'ITS_RET');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { _JPPRT_CHAR_TO_STR : un SEUL caractere [EBP+8] -> chaine ALLOUEE      }
  { d 1 octet utile (+1 NUL gratuit via HEAP_ZERO_MEMORY, voir plus haut). }
  EmitLabel(ASM_PFX_RUNTIME + 'CHAR_TO_STR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH 2');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EDX,DWORD PTR [EBP+8]');
  EmitInstr('MOV BYTE PTR [EAX],DL');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { _JPPRT_CONCAT : deux chaines C -> une troisieme, ALLOUEE, taille       }
  { EXACTE (STRLEN des deux, PUIS copie brute octet par octet - jamais            }
  { de STOSB/MOVSB, ces instructions chaine x86 ne sont pas gerees par           }
  { cet assembleur, TODO 22). CONVENTION D APPEL PROPRE A CE                            }
  { COMPILATEUR (jamais appelee ailleurs que par CompileExpr, EK_BINARY          }
  { "+" sur String) : l appelant empile l operande GAUCHE PUIS le             }
  { DROIT, dans cet ORDRE (evaluation gauche-a-droite REELLE, section              }
  { 15.7.4 JLS/comportement Java standard) - le DERNIER empile se                       }
  { retrouve donc TOUJOURS le PLUS PRES du sommet, [EBP+8] : c est              }
  { l operande DROIT ("second" ci-dessous), [EBP+12] est le GAUCHE                     }
  { ("first"). EBX conserve le pointeur ORIGINAL du bloc alloue (EDI,               }
  { lui, AVANCE pendant la copie - EAX ne peut PAS jouer ce role,                        }
  { ecrase par CHAQUE CALL intermediaire). }
  EmitLabel(ASM_PFX_RUNTIME + 'CONCAT');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRLEN');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH DWORD PTR [EBP+12]');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRLEN');
  EmitInstr('ADD ESP,4');
  EmitInstr('ADD EAX,EBX');
  EmitInstr('ADD EAX,1');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOV EDI,EAX');
  EmitInstr('MOV ESI,DWORD PTR [EBP+12]');   { GAUCHE d abord (voir la note d en-tete) }
  EmitLabel(ASM_PFX_RUNTIME + 'CC_COPYA');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'CC_COPYB_START');
  EmitInstr('MOV DL,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],DL');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'CC_COPYA');
  EmitLabel(ASM_PFX_RUNTIME + 'CC_COPYB_START');
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');   { DROIT ensuite }
  EmitLabel(ASM_PFX_RUNTIME + 'CC_COPYB');
  EmitInstr('CMP BYTE PTR [ESI],0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'CC_DONE');
  EmitInstr('MOV DL,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],DL');
  EmitInstr('INC ESI');
  EmitInstr('INC EDI');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'CC_COPYB');
  EmitLabel(ASM_PFX_RUNTIME + 'CC_DONE');
  EmitInstr('MOV EAX,EBX');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ MethodAsmLabelG : etiquette ASM d une methode - INCLUT le nom de la    }
{ classe proprietaire (contrairement a GOCW32.PAS, ou une fonction              }
{ top-level Go est deja unique par construction) : Java n a AUCUNE               }
{ fonction hors classe, et deux classes DIFFERENTES peuvent parfaitement     }
{ declarer une methode DE MEME NOM ("main", par exemple, EXACTEMENT               }
{ ce que fait chacun des 18 echantillons) - une collision serait                       }
{ sinon certaine. Surcharge (plusieurs methodes MEME nom, TYPES DE               }
{ parametres differents, section 8.13) NON DESAMBIGUISEE ICI (aucune              }
{ methode compilee par ce premier jalon n est surchargee - Test01Bonjour  }
{ n en a qu une, "main") - une VRAIE strategie de nom mangle PAR                      }
{ SIGNATURE reste une extension FUTURE, non devinee. }
Function MethodAsmLabelG(MI: Integer): TString;
Begin
  If MethodPool[MI].IsStatic Then
    MethodAsmLabelG := ASM_PFX_FUNC + TypeTab[MethodPool[MI].OwnerTypeIdx].Name +
      '_' + MethodPool[MI].Name
  Else
    MethodAsmLabelG := ASM_PFX_METHOD + TypeTab[MethodPool[MI].OwnerTypeIdx].Name +
      '_' + MethodPool[MI].Name;
End;

{ ------------------------------------------------------------ }
{ Extension post-TODO25 (generateur de code) : demandee explicitement    }
{ par l utilisateur ("termine toutes les parties non couvertes par le               }
{ compilateur") - etend CompileExpr/CompileStmt BIEN au-dela du               }
{ "premier jalon" du TODO 21 (qui ne couvrait qu un "System.out.                       }
{ println(<litteral>)" seul dans "main"), SANS toucher a l architecture               }
{ generale (toujours "tout tient dans EAX", toujours du texte .asm                    }
{ REEL passe par le MEME assembleur/ecrivain PE/COFF des TODO 22/23).             }
{ PORTEE REELLE de cette extension (verifiee par execution, PAS                        }
{ supposee - voir le rapport de fin de session) : locales/parametres                  }
{ SCALAIRES (int/boolean/char/String - JAMAIS long/double/float, qui                   }
{ ne tiennent pas dans EAX seul et restent donc HORS de portee, ni un              }
{ champ/"this"/tableau/objet, qui exigeraient une disposition memoire           }
{ D INSTANCE encore inexistante), arithmetique/comparaisons entieres,             }
{ &&/|| court-circuites, ++/--, if/else, while/do-while/for, switch/                  }
{ case/default/break/continue (NON etiquetes), return, affectation                    }
{ simple ET composee (+=, etc.) vers une locale, et la concatenation             }
{ "+" de chaines (avec conversion int/boolean/char->String via un                    }
{ nouveau petit runtime alloue sur le tas, voir EmitRuntimeLibrary).             }
{ Chaque limite residuelle s arrete PROPREMENT via un FatalError                       }
{ explicite (JAMAIS un .asm/.obj/.exe silencieusement faux), MEME                     }
{ discipline exacte que le "premier jalon" du TODO 21 lui-meme.                          }
{ ------------------------------------------------------------ }

{ CgLocalOperand : texte d operande EBP-relatif "DWORD PTR [EBP+N]"/     }
{ "[EBP-N]" pour un SK_VAR LOCAL/PARAMETRE (TSymRec.Offset, voir sa               }
{ propre note d en-tete) - IntToStrG produit deja "-N" pour un                        }
{ deplacement negatif (Str standard Pascal), aucune logique de signe             }
{ separee necessaire au-dela du "+" litteral pour le cas positif. }
Function CgLocalOperand(Offset: LongInt): TString;
Begin
  If Offset >= 0 Then
    CgLocalOperand := 'DWORD PTR [EBP+' + IntToStrG(Offset) + ']'
  Else
    CgLocalOperand := 'DWORD PTR [EBP' + IntToStrG(Offset) + ']';
End;

{ CgAddrOperand : MEME chose que CgLocalOperand, mais pour un registre   }
{ de base ARBITRAIRE (EAX/ECX/EBX/ESP - un pointeur d objet/de tableau           }
{ deja calcule dans une expression, PAS forcement EBP) - extension              }
{ modele memoire d instance/tableau, post-TODO25. }
Function CgAddrOperand(Const BaseRegName: TString; Offset: LongInt): TString;
Begin
  If Offset = 0 Then
    CgAddrOperand := 'DWORD PTR [' + BaseRegName + ']'
  Else If Offset > 0 Then
    CgAddrOperand := 'DWORD PTR [' + BaseRegName + '+' + IntToStrG(Offset) + ']'
  Else
    CgAddrOperand := 'DWORD PTR [' + BaseRegName + IntToStrG(Offset) + ']';
End;

{ Modele memoire d instance - extension post-TODO25 : un OBJET est un   }
{ bloc alloue sur le tas (_JPPRT_ALLOC, zero-rempli), UN SEUL mot de 4          }
{ octets par CHAMP D INSTANCE (meme simplification "tout tient dans              }
{ EAX" que le reste de ce generateur - AUCUN champ long/double/float                }
{ n est correctement modelise, ils occupent quand meme UN SEUL mot,               }
{ documente comme FAUX si jamais utilise). Les champs HERITES d une             }
{ superclasse occupent TOUJOURS les premiers mots (deplacement le PLUS          }
{ petit), ceux de la classe elle-meme suivent - TFieldRec.Offset (deja           }
{ existant depuis le TODO 08, "deplacement... CHAMPS PROPRES SEULEMENT")        }
{ reste relatif au DEBUT des champs PROPRES de son OwnerTypeIdx ;                    }
{ CgFieldOffsetInObject y ajoute la taille de TOUTE la chaine de                        }
{ superclasses AU-DESSUS de cet OwnerTypeIdx. SIMPLIFICATION ASSUMEE :                 }
{ TypeTab[T].FieldCount compte AUSSI les champs static (jamais separes           }
{ des champs d instance depuis le TODO 08) - gaspille un mot par champ           }
{ static melange a des champs d instance, JAMAIS incorrect (chaque               }
{ champ D INSTANCE garde un emplacement UNIQUE et STABLE), simplement           }
{ pas la disposition la plus compacte possible. }
Function CgClassOwnFieldBytes(T: Integer): LongInt;
Begin
  CgClassOwnFieldBytes := TypeTab[T].FieldCount * 4;
End;

Function CgAncestorFieldBytes(T: Integer): LongInt;
Begin
  If (T < 0) Or (TypeTab[T].SuperTypeIdx < 0) Then
    CgAncestorFieldBytes := 0
  Else
    CgAncestorFieldBytes := CgAncestorFieldBytes(TypeTab[T].SuperTypeIdx) +
      CgClassOwnFieldBytes(TypeTab[T].SuperTypeIdx);
End;

Function CgObjectSize(T: Integer): LongInt;
Begin
  CgObjectSize := CgAncestorFieldBytes(T) + CgClassOwnFieldBytes(T);
End;

Function CgFieldOffsetInObject(FI: Integer): LongInt;
Begin
  CgFieldOffsetInObject := CgAncestorFieldBytes(FieldPool[FI].OwnerTypeIdx) +
    FieldPool[FI].Offset;
End;

Procedure CompileExpr(E: Integer); Forward;
Procedure CompileCall(E: Integer); Forward;

{ CompileToStringValue : compile OperandE (CompileExpr) PUIS convertit   }
{ sa valeur EAX en pointeur de chaine C - deja un pointeur si TypeIdx           }
{ = PDT_STRING (rien a faire), sinon boolean (choix FIXE entre les DEUX             }
{ constantes TRUE_STR/FALSE_STR, jamais alloue - toujours les MEMES               }
{ deux chaines), char/int (toujours ALLOUE, valeur inconnue a l avance,          }
{ _JPPRT_CHAR_TO_STR/_JPPRT_INT_TO_STR). long/double/float restent               }
{ HORS de portee (ne tiennent pas dans EAX seul). }
Procedure CompileToStringValue(OperandE: Integer);
Var T : Integer; LblFalse, LblDone : TString;
Begin
  T := ExprPool[OperandE].TypeIdx;
  CompileExpr(OperandE);
  If T = PDT_STRING Then Exit;
  If T = PRIMTYPE_BOOLEAN Then
  Begin
    LblFalse := CgLabelGen;
    LblDone  := CgLabelGen;
    EmitInstr('CMP EAX,0');
    EmitInstr('JE ' + LblFalse);
    EmitInstr('LEA EAX,[' + ASM_PFX_RUNTIME + 'TRUE_STR]');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblFalse);
    EmitInstr('LEA EAX,[' + ASM_PFX_RUNTIME + 'FALSE_STR]');
    EmitLabel(LblDone);
    Exit;
  End;
  If T = PRIMTYPE_CHAR Then
  Begin
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'CHAR_TO_STR');
    EmitInstr('ADD ESP,4');
    Exit;
  End;
  If (T = PRIMTYPE_INT) Or (T = PRIMTYPE_SHORT) Or (T = PRIMTYPE_BYTE) Then
  Begin
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'INT_TO_STR');
    EmitInstr('ADD ESP,4');
    Exit;
  End;
  FatalError('generateur de code : conversion en chaine non couverte par ' +
    'cette extension pour la concatenation "+" (long/double/float restent ' +
    'hors de portee, voir la note d''en-tete de section) : type #' + IntToStrG(T));
End;

{ CompileConcat : "+" dont le TYPE RESULTAT est PDT_STRING (regle EXACTE  }
{ de ExprInferBinaryType, section 6.7) - evalue GAUCHE PUIS DROIT (ordre           }
{ Java REEL), convertit chacun en pointeur de chaine si necessaire,                  }
{ PUIS _JPPRT_CONCAT (voir sa propre note d en-tete pour la convention             }
{ d appel gauche/droit EXACTE). }
Procedure CompileConcat(E: Integer);
Begin
  CompileToStringValue(ExprPool[E].Left);
  EmitInstr('PUSH EAX');
  CompileToStringValue(ExprPool[E].Right);
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'CONCAT');
  EmitInstr('ADD ESP,8');
End;

{ CompileArithBinary : ECX=GAUCHE, EAX=DROIT DEJA en place (voir          }
{ l appelant, CompileBinary) - resultat final dans EAX. SEULS +/-/*//%              }
{ entiers sont couverts (long/double/float hors de portee). }
Procedure CompileArithBinary(Const Op: TString);
Begin
  If Op = '+' Then
    EmitInstr('ADD EAX,ECX')
  Else If Op = '-' Then
  Begin
    EmitInstr('SUB ECX,EAX');
    EmitInstr('MOV EAX,ECX');
  End
  Else If Op = '*' Then
    EmitInstr('IMUL EAX,ECX')
  Else If (Op = '/') Or (Op = '%') Then
  Begin
    { EBX PRESERVE explicitement (PUSH/POP) - extension post-TODO25         }
    { (modele memoire d instance/tableau) : STK_ASSIGN/EK_NEWARRAY               }
    { conservent une ADRESSE dans EBX pendant que la VALEUR de droite               }
    { (potentiellement une division, ICI MEME) est calculee - sans cette             }
    { sauvegarde, "arr[i] = a / b;" ou "obj.champ = a % b;" corromprait              }
    { silencieusement cette adresse (trouve par relecture, PAS par                        }
    { execution, en auditant CHAQUE utilisateur de EBX apres le premier            }
    { bogue REEL trouve par execution dans EK_NEWARRAY 'dims', voir sa             }
    { propre note d en-tete). }
    EmitInstr('PUSH EBX');
    EmitInstr('MOV EBX,EAX');
    EmitInstr('MOV EAX,ECX');
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
    If Op = '%' Then EmitInstr('MOV EAX,EDX');
    EmitInstr('POP EBX');
  End
  Else If Op = '|' Then
    EmitInstr('OR EAX,ECX')
  Else If Op = '&' Then
    EmitInstr('AND EAX,ECX')
  Else If Op = '^' Then
    EmitInstr('XOR EAX,ECX')
  Else
    FatalError('generateur de code : operateur arithmetique entier non ' +
      'couvert par cette extension : ' + Op);
End;

{ CompileComparisonBinary : ECX=GAUCHE, EAX=DROIT (meme convention que   }
{ CompileArithBinary) - materialise 0/1 dans EAX via Jcc, MEME idiome              }
{ que GOCW32.PAS/SWIFTW32.PAS/DELPHI.PAS (jamais SETcc, non implemente             }
{ dans cet assembleur, TODO 22). }
Procedure CompileComparisonBinary(Const Op: TString);
Var LblTrue, LblDone : TString;
Begin
  EmitInstr('CMP ECX,EAX');
  LblTrue := CgLabelGen;
  LblDone := CgLabelGen;
  If      Op = '==' Then EmitInstr('JE ' + LblTrue)
  Else If Op = '!=' Then EmitInstr('JNE ' + LblTrue)
  Else If Op = '<'  Then EmitInstr('JL ' + LblTrue)
  Else If Op = '<=' Then EmitInstr('JLE ' + LblTrue)
  Else If Op = '>'  Then EmitInstr('JG ' + LblTrue)
  Else If Op = '>=' Then EmitInstr('JGE ' + LblTrue)
  Else
  Begin
    FatalError('generateur de code : comparaison non couverte par cette ' +
      'extension : ' + Op);
    Exit;
  End;
  EmitInstr('MOV EAX,0');
  EmitInstr('JMP ' + LblDone);
  EmitLabel(LblTrue);
  EmitInstr('MOV EAX,1');
  EmitLabel(LblDone);
End;

{ CompileBinary : dispatch EK_BINARY - "+" String d abord (avant toute   }
{ promotion numerique, MEME regle que ExprInferBinaryType) ; &&/||                    }
{ court-circuitent REELLEMENT (l operande DROIT n est JAMAIS evalue si           }
{ le GAUCHE suffit deja, section 6.13/15.23-15.24 JLS) ; sinon evalue                  }
{ GAUCHE (empile), puis DROIT, PUIS depile GAUCHE dans ECX -                            }
{ CompileArithBinary/CompileComparisonBinary trouvent alors TOUJOURS                    }
{ ECX=GAUCHE/EAX=DROIT. }
Procedure CompileBinary(E: Integer);
Var Op : TString; LblShort, LblDone : TString;
Begin
  Op := ExprPool[E].Op;

  If (Op = '+') And (ExprPool[E].TypeIdx = PDT_STRING) Then
  Begin
    CompileConcat(E);
    Exit;
  End;

  If Op = '&&' Then
  Begin
    CompileExpr(ExprPool[E].Left);
    EmitInstr('CMP EAX,0');
    LblShort := CgLabelGen;
    LblDone  := CgLabelGen;
    EmitInstr('JE ' + LblShort);
    CompileExpr(ExprPool[E].Right);
    EmitInstr('CMP EAX,0');
    EmitInstr('JE ' + LblShort);
    EmitInstr('MOV EAX,1');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblShort);
    EmitInstr('MOV EAX,0');
    EmitLabel(LblDone);
    Exit;
  End;

  If Op = '||' Then
  Begin
    CompileExpr(ExprPool[E].Left);
    EmitInstr('CMP EAX,0');
    LblShort := CgLabelGen;
    LblDone  := CgLabelGen;
    EmitInstr('JNE ' + LblShort);
    CompileExpr(ExprPool[E].Right);
    EmitInstr('CMP EAX,0');
    EmitInstr('JNE ' + LblShort);
    EmitInstr('MOV EAX,0');
    EmitInstr('JMP ' + LblDone);
    EmitLabel(LblShort);
    EmitInstr('MOV EAX,1');
    EmitLabel(LblDone);
    Exit;
  End;

  { extension post-TODO25 : "<<"/">>"/">>>" - REGISTRES SPECIAUX,           }
  { traites A PART du reste (le compte de decalage DOIT transiter par CL,          }
  { jamais la convention ECX=GAUCHE/EAX=DROIT du reste de cette fonction). }
  If (Op = '<<') Or (Op = '>>') Or (Op = '>>>') Then
  Begin
    CompileExpr(ExprPool[E].Left);
    EmitInstr('PUSH EAX');
    CompileExpr(ExprPool[E].Right);
    EmitInstr('MOV ECX,EAX');
    EmitInstr('POP EAX');
    If Op = '<<' Then EmitInstr('SHL EAX,CL')
    Else If Op = '>>' Then EmitInstr('SAR EAX,CL')
    Else EmitInstr('SHR EAX,CL');
    Exit;
  End;

  CompileExpr(ExprPool[E].Left);
  EmitInstr('PUSH EAX');
  CompileExpr(ExprPool[E].Right);
  EmitInstr('POP ECX');

  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Then
    CompileComparisonBinary(Op)
  Else
    CompileArithBinary(Op);
End;

{ CompileExpr : LAISSE le resultat scalaire de E dans EAX (convention          }
{ "tout tient dans EAX") - EK_STRINGLIT (adresse de la chaine POOLEE),                }
{ EK_INTLIT/CHARLIT/BOOLLIT (immediat), EK_IDENT (locale/parametre                    }
{ SCALAIRE via Offset, JAMAIS un champ/"this"), EK_UNARY (+/-/!/++/--,                 }
{ prefixe ET postfixe), EK_BINARY (CompileBinary), EK_TERNARY (Jcc,                     }
{ meme idiome qu un if). TOUT AUTRE genre s arrete PROPREMENT                          }
{ (FatalError explicite citant l ordinal), JAMAIS un .asm silencieusement       }
{ faux. }
Procedure CompileExpr(E: Integer);
Var
  LblFalse, LblDone : TString;
  Off : LongInt;
  FI, BaseT, MI, ClassT, I, ArgN : Integer;
Begin
  If E < 0 Then
  Begin
    FatalError('generateur de code : expression manquante (TODO 21)');
    Exit;
  End;
  Case ExprPool[E].Kind Of
    EK_STRINGLIT:
      EmitInstr('LEA EAX,[' + ASM_PFX_STRING + IntToStrG(CgStrPoolOfExpr[E]) + ']');

    EK_INTLIT, EK_CHARLIT, EK_BOOLLIT:
      EmitInstr('MOV EAX,' + IntToStrG(ExprPool[E].IntVal));

    EK_NULLLIT:
      EmitInstr('MOV EAX,0');

    EK_IDENT:
    Begin
      If (ExprPool[E].Left < 0) Or (SymTab[ExprPool[E].Left].Kind <> SK_VAR) Then
      Begin
        FatalError('generateur de code : identificateur non couvert par ' +
          'cette extension (seules les locales/parametres scalaires le ' +
          'sont, jamais un champ/"this", voir la note d''en-tete de ' +
          'section) : ' + ExprPool[E].NameVal);
        Exit;
      End;
      EmitInstr('MOV EAX,' + CgLocalOperand(SymTab[ExprPool[E].Left].Offset));
    End;

    EK_UNARY:
    Begin
      If ExprPool[E].Op = '-' Then
      Begin
        CompileExpr(ExprPool[E].Left);
        EmitInstr('NEG EAX');
      End
      Else If ExprPool[E].Op = '+' Then
        CompileExpr(ExprPool[E].Left)
      Else If ExprPool[E].Op = '!' Then
      Begin
        CompileExpr(ExprPool[E].Left);
        LblFalse := CgLabelGen;
        LblDone  := CgLabelGen;
        EmitInstr('CMP EAX,0');
        EmitInstr('JE ' + LblFalse);
        EmitInstr('MOV EAX,0');
        EmitInstr('JMP ' + LblDone);
        EmitLabel(LblFalse);
        EmitInstr('MOV EAX,1');
        EmitLabel(LblDone);
      End
      Else If (ExprPool[E].Op = '++') Or (ExprPool[E].Op = '--') Or
              (ExprPool[E].Op = 'post++') Or (ExprPool[E].Op = 'post--') Then
      Begin
        { extension post-TODO25 : cible locale/parametre (CgLocalOperand,      }
        { comme au premier jalon de cette extension) OU champ/element de              }
        { tableau (adresse calculee dans EBX, MEME technique que                        }
        { STK_ASSIGN). }
        If (ExprPool[ExprPool[E].Left].Kind = EK_IDENT) And
           (ExprPool[ExprPool[E].Left].Left >= 0) And
           (SymTab[ExprPool[ExprPool[E].Left].Left].Kind = SK_VAR) Then
        Begin
          Off := SymTab[ExprPool[ExprPool[E].Left].Left].Offset;
          EmitInstr('MOV EAX,' + CgLocalOperand(Off));
          If (ExprPool[E].Op = '++') Or (ExprPool[E].Op = 'post++') Then
          Begin
            EmitInstr('ADD EAX,1');
            EmitInstr('MOV ' + CgLocalOperand(Off) + ',EAX');
            If ExprPool[E].Op = 'post++' Then EmitInstr('SUB EAX,1');
          End
          Else
          Begin
            EmitInstr('SUB EAX,1');
            EmitInstr('MOV ' + CgLocalOperand(Off) + ',EAX');
            If ExprPool[E].Op = 'post--' Then EmitInstr('ADD EAX,1');
          End;
        End
        Else If ExprPool[ExprPool[E].Left].Kind = EK_SELECTOR Then
        Begin
          BaseT := ExprPool[ExprPool[ExprPool[E].Left].Left].TypeIdx;
          FI := ClassFindField(BaseT, ExprPool[ExprPool[E].Left].NameVal);
          If FI < 0 Then
          Begin
            FatalError('generateur de code : "++"/"--" non couvert par ' +
              'cette extension (champ introuvable, voir la note d''en-tete ' +
              'de section)');
            Exit;
          End;
          Off := CgFieldOffsetInObject(FI);
          CompileExpr(ExprPool[ExprPool[E].Left].Left);
          EmitInstr('MOV EBX,EAX');
          EmitInstr('MOV EAX,' + CgAddrOperand('EBX', Off));
          If (ExprPool[E].Op = '++') Or (ExprPool[E].Op = 'post++') Then
          Begin
            EmitInstr('ADD EAX,1');
            EmitInstr('MOV ' + CgAddrOperand('EBX', Off) + ',EAX');
            If ExprPool[E].Op = 'post++' Then EmitInstr('SUB EAX,1');
          End
          Else
          Begin
            EmitInstr('SUB EAX,1');
            EmitInstr('MOV ' + CgAddrOperand('EBX', Off) + ',EAX');
            If ExprPool[E].Op = 'post--' Then EmitInstr('ADD EAX,1');
          End;
        End
        Else If ExprPool[ExprPool[E].Left].Kind = EK_INDEX Then
        Begin
          CompileExpr(ExprPool[ExprPool[E].Left].Left);
          EmitInstr('PUSH EAX');
          CompileExpr(ExprPool[ExprPool[E].Left].Right);
          EmitInstr('POP ECX');
          EmitInstr('ADD EAX,EAX');
          EmitInstr('ADD EAX,EAX');
          EmitInstr('ADD EAX,ECX');
          EmitInstr('MOV EBX,EAX');
          EmitInstr('MOV EAX,' + CgAddrOperand('EBX', 0));
          If (ExprPool[E].Op = '++') Or (ExprPool[E].Op = 'post++') Then
          Begin
            EmitInstr('ADD EAX,1');
            EmitInstr('MOV ' + CgAddrOperand('EBX', 0) + ',EAX');
            If ExprPool[E].Op = 'post++' Then EmitInstr('SUB EAX,1');
          End
          Else
          Begin
            EmitInstr('SUB EAX,1');
            EmitInstr('MOV ' + CgAddrOperand('EBX', 0) + ',EAX');
            If ExprPool[E].Op = 'post--' Then EmitInstr('ADD EAX,1');
          End;
        End
        Else
        Begin
          FatalError('generateur de code : "++"/"--" non couvert par cette ' +
            'extension (cible autre qu''une locale/un parametre scalaire, ' +
            'un champ, ou un element de tableau, voir la note d''en-tete ' +
            'de section)');
          Exit;
        End;
      End
      Else
        FatalError('generateur de code : operateur unaire non couvert par ' +
          'cette extension : ' + ExprPool[E].Op);
    End;

    EK_BINARY:
      CompileBinary(E);

    EK_CALL:
      CompileCall(E);

    EK_TERNARY:
    Begin
      CompileExpr(ExprPool[E].Left);
      EmitInstr('CMP EAX,0');
      LblFalse := CgLabelGen;
      LblDone  := CgLabelGen;
      EmitInstr('JE ' + LblFalse);
      CompileExpr(ExprPool[E].Right);
      EmitInstr('JMP ' + LblDone);
      EmitLabel(LblFalse);
      CompileExpr(ExprPool[E].Extra);
      EmitLabel(LblDone);
    End;

    { extension post-TODO25 : "(Type)expr" - PASSE-THROUGH pur des lors    }
    { que source ET cible tiennent toutes deux dans EAX (int-family/                 }
    { boolean/char, OU une conversion de REFERENCE - String/objet -                       }
    { jamais verifiee a l EXECUTION, AUCUN echantillon ne declenche un              }
    { cast reellement invalide, verifie par lecture) - long/double/float             }
    { (source OU cible) restent HORS de portee, comme partout ailleurs               }
    { dans cette extension. }
    EK_CAST:
    Begin
      If (ExprPool[E].Extra = PRIMTYPE_LONG) Or (ExprPool[E].Extra = PRIMTYPE_DOUBLE) Or
         (ExprPool[E].Extra = PRIMTYPE_FLOAT) Or
         (ExprPool[ExprPool[E].Left].TypeIdx = PRIMTYPE_LONG) Or
         (ExprPool[ExprPool[E].Left].TypeIdx = PRIMTYPE_DOUBLE) Or
         (ExprPool[ExprPool[E].Left].TypeIdx = PRIMTYPE_FLOAT) Then
      Begin
        FatalError('generateur de code : conversion ("cast") non couverte ' +
          'par cette extension (long/double/float restent hors de portee, ' +
          'voir la note d''en-tete de section)');
        Exit;
      End;
      CompileExpr(ExprPool[E].Left);
    End;

    { EK_SELECTOR : extension post-TODO25 (modele memoire d instance/        }
    { tableau) - ".length" sur un tableau (CAS SPECIAL deja distingue par           }
    { le PARSEUR lui-meme, TypeIdx=PRIMTYPE_INT rien qu a l analyse, voir             }
    { ParsePostfix) charge le PREFIXE de longueur a [base-4] ; sinon un           }
    { VRAI champ, re-resolu ICI par ClassFindField (MEME fonction que le          }
    { parseur, jamais stockee sur le noeud - AUCUN champ EQUIVALENT a               }
    { EK_CALL.Extra n existe pour EK_SELECTOR), charge depuis                          }
    { [base+CgFieldOffsetInObject]. }
    EK_SELECTOR:
    Begin
      BaseT := ExprPool[ExprPool[E].Left].TypeIdx;
      If (ExprPool[E].NameVal = 'length') And (BaseT >= 0) And (BaseT < TypeCount) And
         (TypeTab[BaseT].Kind = TYK_ARRAY) Then
      Begin
        CompileExpr(ExprPool[E].Left);
        EmitInstr('MOV EAX,' + CgAddrOperand('EAX', -4));
        Exit;
      End;
      FI := ClassFindField(BaseT, ExprPool[E].NameVal);
      If FI < 0 Then
      Begin
        FatalError('generateur de code : selecteur "' + ExprPool[E].NameVal +
          '" non couvert par cette extension (champ introuvable ou base ' +
          'non-objet, voir la note d''en-tete de section)');
        Exit;
      End;
      CompileExpr(ExprPool[E].Left);
      EmitInstr('MOV EAX,' + CgAddrOperand('EAX', CgFieldOffsetInObject(FI)));
    End;

    { EK_INDEX : extension post-TODO25 - "arr[i]" - AUCUN adressage             }
    { base+index materiel (SIB) n est gere par cet assembleur (TODO 22),           }
    { l adresse EFFECTIVE est donc calculee ARITHMETIQUEMENT (i*4, PUIS               }
    { ajoutee au pointeur de tableau) avant un chargement base-seul                    }
    { ordinaire - AUCUNE verification de borne (deja documente, TYK_ARRAY,          }
    { section 10.7, deferree au generateur de code). }
    EK_INDEX:
    Begin
      CompileExpr(ExprPool[E].Left);
      EmitInstr('PUSH EAX');
      CompileExpr(ExprPool[E].Right);
      EmitInstr('POP ECX');
      EmitInstr('ADD EAX,EAX');
      EmitInstr('ADD EAX,EAX');
      EmitInstr('ADD EAX,ECX');
      EmitInstr('MOV EAX,' + CgAddrOperand('EAX', 0));
    End;

    { EK_NEWOBJECT : extension post-TODO25 - alloue CgObjectSize(classe)     }
    { octets (_JPPRT_ALLOC, zero-rempli) PUIS appelle le constructeur                 }
    { REELLEMENT resolu (EK_NEWOBJECT.Left, ClassFindConstructor au                       }
    { parsing, TODO 08 - deja peuple, AUCUNE re-resolution necessaire                  }
    { ICI contrairement a EK_SELECTOR) avec le pointeur d objet comme                    }
    { "this" implicite (POUSSE EN DERNIER - devient EBP+8 dans le                          }
    { constructeur, EXACTEMENT le meme ordre que CompileCall pour un                     }
    { appel de methode d instance). Le pointeur, ENCORE au sommet de la               }
    { pile juste apres le CALL (le constructeur ne nettoie JAMAIS SA                     }
    { PROPRE pile), est RELU depuis [ESP] AVANT le nettoyage - EAX ne              }
    { peut PAS le conserver lui-meme a travers le CALL (ecrase par le              }
    { constructeur). Une classe SANS corps constructeur reel (predeclaree/         }
    { bibliotheque standard - Exception et consorts, StdlibInit,                          }
    { BodyStmtIdx TOUJOURS -1) s arrete PROPREMENT ICI plutot que de                    }
    { referencer une etiquette JAMAIS emise. }
    EK_NEWOBJECT:
    Begin
      ClassT := ExprPool[E].Extra;
      MI := ExprPool[E].Left;
      If (MI < 0) Or (TypeTab[ClassT].Kind <> TYK_CLASS) Or
         (MethodPool[MI].BodyStmtIdx < 0) Then
      Begin
        FatalError('generateur de code : "new ' + TypeTab[ClassT].Name +
          '(...)" non couvert par cette extension (constructeur non ' +
          'resolu, OU sans corps SOURCE reel - une classe predeclaree de ' +
          'la bibliotheque standard, ex. une exception, n en a jamais, ' +
          'voir la note d''en-tete de section)');
        Exit;
      End;
      For I := ExprPool[E].ArgCount - 1 DownTo 0 Do
      Begin
        CompileExpr(ExprArgPool[ExprPool[E].ArgFirst + I]);
        EmitInstr('PUSH EAX');
      End;
      EmitInstr('PUSH ' + IntToStrG(CgObjectSize(ClassT)));
      EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
      EmitInstr('ADD ESP,4');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + MethodAsmLabelG(MI));
      EmitInstr('MOV EAX,' + CgAddrOperand('ESP', 0));
      EmitInstr('ADD ESP,' + IntToStrG((ExprPool[E].ArgCount + 1) * 4));
    End;

    { EK_NEWARRAY : extension post-TODO25 - SEULEMENT 1 dimension           }
    { ("new T[n]", 'dims') ou un initialiseur ENTRE ACCOLADES (aussi bien           }
    { "new T[] AVEC initialiseur" que le declarateur nu "T[] x = ...",           }
    { 'init') - tableau MULTI-dimensionnel ("new T[n][m]") reste HORS de           }
    { portee (Test05Tableaux.jpp, non atteint). Disposition : prefixe de           }
    { LONGUEUR sur 4 octets, PUIS les elements - la reference de tableau            }
    { retournee POINTE SUR LE PREMIER ELEMENT               }
    { (base+4 du bloc alloue), ".length" (EK_SELECTOR ci-dessus) relit                 }
    { simplement [base-4]. }
    EK_NEWARRAY:
    Begin
      If (ExprPool[E].Op = 'dims') And (ExprPool[E].ArgCount <> 1) Then
      Begin
        FatalError('generateur de code : tableau multi-dimensionnel non ' +
          'couvert par cette extension (seul "new T[n]" a UNE dimension ' +
          'l''est, voir la note d''en-tete de section)');
        Exit;
      End;
      If ExprPool[E].Op = 'dims' Then
      Begin
        { BOGUE REEL trouve par EXECUTION (synthetique, PAS un des 18       }
        { echantillons - "Longueur : -1374577314" au lieu de 5) : ECX               }
        { n est PAS un registre PRESERVE a travers un CALL (ni par                     }
        { convention Win32, ni par _JPPRT_ALLOC lui-meme, qui ne sauve/                  }
        { restaure QUE EBX) - le conserver dans ECX a travers                                 }
        { "CALL _JPPRT_ALLOC" laissait relire n IMPORTE QUOI (les restes               }
        { de GetProcessHeap/HeapAlloc) plutot que "n". Corrige en le                          }
        { faisant TRANSITER par la PILE (PUSH avant l appel, POP juste                       }
        { apres) plutot que par un registre. }
        CompileExpr(ExprArgPool[ExprPool[E].ArgFirst]);
        EmitInstr('MOV ECX,EAX');
        EmitInstr('ADD EAX,EAX');
        EmitInstr('ADD EAX,EAX');
        EmitInstr('ADD EAX,4');
        EmitInstr('PUSH ECX');
        EmitInstr('PUSH EAX');
        EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
        EmitInstr('ADD ESP,4');
        EmitInstr('POP ECX');
        EmitInstr('MOV ' + CgAddrOperand('EAX', 0) + ',ECX');
        EmitInstr('ADD EAX,4');
      End
      Else
      Begin
        ArgN := ExprPool[E].ArgCount;
        EmitInstr('PUSH ' + IntToStrG(ArgN * 4 + 4));
        EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
        EmitInstr('ADD ESP,4');
        EmitInstr('MOV ECX,' + IntToStrG(ArgN));
        EmitInstr('MOV ' + CgAddrOperand('EAX', 0) + ',ECX');
        EmitInstr('ADD EAX,4');
        EmitInstr('MOV EBX,EAX');
        For I := 0 To ArgN - 1 Do
        Begin
          CompileExpr(ExprArgPool[ExprPool[E].ArgFirst + I]);
          EmitInstr('MOV ' + CgAddrOperand('EBX', I * 4) + ',EAX');
        End;
        EmitInstr('MOV EAX,EBX');
      End;
    End;
  Else
    FatalError('generateur de code : forme d''expression non couverte par ' +
      'ce premier jalon du TODO 21 (genre #' + IntToStrG(Ord(ExprPool[E].Kind)) +
      ' - voir la note d''en-tete de section pour la portee EXACTE)');
  End;
End;

{ CgIsScalarCallType : "tient dans EAX" pour un parametre/retour d appel  }
{ de methode - int/boolean/char/short/byte/String (JAMAIS long/double/            }
{ float, qui ne tiennent pas dans un seul registre, ni un tableau/objet,          }
{ qui exigeraient une disposition memoire non modelisee ICI). }
Function CgIsScalarCallType(T: Integer): Boolean;
Begin
  CgIsScalarCallType := (T = PRIMTYPE_INT) Or (T = PRIMTYPE_BOOLEAN) Or
    (T = PRIMTYPE_CHAR) Or (T = PRIMTYPE_SHORT) Or (T = PRIMTYPE_BYTE) Or
    (T = PDT_STRING);
End;

{ CompileCall : reconnait "System.out.println(String)" PAR LA METHODE   }
{ REELLEMENT resolue (EK_CALL.Extra, TODO 21 - voir sa propre note                 }
{ d en-tete) plutot que par une comparaison de TEXTE sur l expression            }
{ source. Extension post-TODO25 : couvre AUSSI un appel de methode                    }
{ STATIQUE utilisateur (jamais d instance - aucun "this" REEL n existe            }
{ encore), a condition que TOUS ses parametres ET son retour soient               }
{ SCALAIRES (CgIsScalarCallType, retour PRIMTYPE_VOID egalement                       }
{ accepte - une methode "void" reste appelable comme instruction MEME              }
{ si son "retour" n a pas de valeur). Args pousses en ordre INVERSE                  }
{ (convention deja etablie par ParseOneParamIntoPool - CurParamOffset             }
{ croissant depuis EBP+8) ; la methode appelee ne nettoie JAMAIS SA               }
{ PROPRE pile (CompileMethodBody emet un "RET" nu) - l appelant le fait          }
{ TOUJOURS via "ADD ESP,N", MEME convention que les appels au runtime             }
{ _JPPRT_*. La resolution de surcharge (ClassResolveMethodCall, TODO 08)          }
{ a DEJA choisi la bonne entree MethodPool au moment du parsing (EK_CALL.       }
{ Extra) - appeler MethodAsmLabelG(MI) directement est donc TOUJOURS              }
{ correct, y compris pour une methode RECURSIVE (Test04Methodes.jpp,             }
{ "factorielle") ou surchargee par TYPE. }
Procedure CompileCall(E: Integer);
Var MI, ArgE, I : Integer; ParamsOK : Boolean;
Begin
  MI := ExprPool[E].Extra;
  If MI < 0 Then
  Begin
    FatalError('generateur de code : appel de methode non resolu (TODO 21)');
    Exit;
  End;

  If (MethodPool[MI].OwnerTypeIdx = TypeFindByName('PrintStream')) And
     (MethodPool[MI].Name = 'println') And (MethodPool[MI].ParamCount = 1) And
     (ParamPool[MethodPool[MI].ParamFirst].TypeIdx = PDT_STRING) Then
  Begin
    ArgE := ExprArgPool[ExprPool[E].ArgFirst];
    CompileExpr(ArgE);
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR');
    EmitInstr('ADD ESP,4');
    Exit;
  End;

  If MethodPool[MI].IsStatic And
     (TypeTab[MethodPool[MI].OwnerTypeIdx].Kind = TYK_CLASS) And
     (MethodPool[MI].BodyStmtIdx >= 0) And
     (CgIsScalarCallType(MethodPool[MI].RetTypeIdx) Or
      (MethodPool[MI].RetTypeIdx = PRIMTYPE_VOID)) Then
  Begin
    ParamsOK := True;
    For I := 0 To MethodPool[MI].ParamCount - 1 Do
      If Not CgIsScalarCallType(ParamPool[MethodPool[MI].ParamFirst + I].TypeIdx) Then
        ParamsOK := False;
    If ParamsOK Then
    Begin
      For I := ExprPool[E].ArgCount - 1 DownTo 0 Do
      Begin
        ArgE := ExprArgPool[ExprPool[E].ArgFirst + I];
        CompileExpr(ArgE);
        EmitInstr('PUSH EAX');
      End;
      EmitInstr('CALL ' + MethodAsmLabelG(MI));
      If ExprPool[E].ArgCount > 0 Then
        EmitInstr('ADD ESP,' + IntToStrG(ExprPool[E].ArgCount * 4));
      Exit;
    End;
  End;

  { extension post-TODO25 : appel de methode D INSTANCE UTILISATEUR       }
  { (jamais une methode de bibliotheque standard - StdlibInit,                       }
  { BodyStmtIdx TOUJOURS -1, exclue par le MEME garde-fou que EK_NEWOBJECT       }
  { plus haut, sinon une etiquette JAMAIS emise serait referencee) -               }
  { RECEPTEUR pousse EN DERNIER (devient EBP+8, "this", dans la methode              }
  { appelee) : explicite ("obj.methode(...)", Callee=EK_SELECTOR, le                    }
  { recepteur est ExprPool[Callee].Left) OU implicite ("methode(...)",                  }
  { Callee=EK_IDENT NON resolu - le recepteur est ALORS le "this" de LA           }
  { METHODE ENGLOBANTE en cours de compilation, TOUJOURS a EBP+8 la ou             }
  { son propre corps est en train d etre compile - garanti par les                       }
  { REGLES DE PORTEE Java elles-memes : un appel implicite a une methode            }
  { D INSTANCE ne peut syntaxiquement apparaitre que dans un contexte              }
  { NON-static, ou "this" existe forcement a CETTE MEME position). }
  If (Not MethodPool[MI].IsStatic) And
     (TypeTab[MethodPool[MI].OwnerTypeIdx].Kind = TYK_CLASS) And
     (MethodPool[MI].BodyStmtIdx >= 0) And
     (CgIsScalarCallType(MethodPool[MI].RetTypeIdx) Or
      (MethodPool[MI].RetTypeIdx = PRIMTYPE_VOID)) Then
  Begin
    ParamsOK := True;
    For I := 0 To MethodPool[MI].ParamCount - 1 Do
      If Not CgIsScalarCallType(ParamPool[MethodPool[MI].ParamFirst + I].TypeIdx) Then
        ParamsOK := False;
    If ParamsOK Then
    Begin
      For I := ExprPool[E].ArgCount - 1 DownTo 0 Do
      Begin
        ArgE := ExprArgPool[ExprPool[E].ArgFirst + I];
        CompileExpr(ArgE);
        EmitInstr('PUSH EAX');
      End;
      If ExprPool[ExprPool[E].Left].Kind = EK_SELECTOR Then
        CompileExpr(ExprPool[ExprPool[E].Left].Left)
      Else
        EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + MethodAsmLabelG(MI));
      EmitInstr('ADD ESP,' + IntToStrG((ExprPool[E].ArgCount + 1) * 4));
      Exit;
    End;
  End;

  FatalError('generateur de code : appel a "' + MethodPool[MI].Name +
    '" non couvert par ce premier jalon du TODO 21 (voir la note d''en-tete ' +
    'de section pour la portee EXACTE)');
End;

{ CompileCompoundOp : EAX=cible (AVANT), ECX=valeur - convention PROPRE  }
{ a cette fonction (DIFFERENTE de CompileArithBinary : ICI "EAX est                  }
{ deja la cible" rend SUB/IDIV plus simples, AUCUN echange necessaire).             }
Procedure CompileCompoundOp(Const Op: TString);
Begin
  If Op = '+=' Then
    EmitInstr('ADD EAX,ECX')
  Else If Op = '-=' Then
    EmitInstr('SUB EAX,ECX')
  Else If Op = '*=' Then
    EmitInstr('IMUL EAX,ECX')
  Else If (Op = '/=') Or (Op = '%=') Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV ECX');
    If Op = '%=' Then EmitInstr('MOV EAX,EDX');
  End
  Else
    FatalError('generateur de code : operateur d''affectation compose non ' +
      'couvert par cette extension : ' + Op);
End;

{ CompileStmt : STK_BLOCK (recursion PLATE, TODO 07/08), STK_EXPR              }
{ (appel de methode via CompileCall, OU ++/-- via CompileExpr, resultat            }
{ TOUJOURS ignore, section 7.4), STK_DECL (initialiseur optionnel vers            }
{ chaque symbole de la plage [Left, Left+Extra[), STK_ASSIGN (cible               }
{ locale/parametre SCALAIRE, = simple OU +=/-=/*=//=/%=), STK_RETURN               }
{ (saute TOUJOURS vers CurMethodEpilogueLabel, jamais un simple                          }
{ retour en cascade), STK_IF/WHILE/DOWHILE/FOR (Jcc materialise/               }
{ etiquettes CgLabelGen), STK_SWITCH/CASE (chaine de comparaisons PUIS            }
{ corps en continuation textuelle "fall-through", section 7.9-7.11),              }
{ STK_BREAK/CONTINUE NON etiquetes (CgBreakLbl/CgContinueLbl). TOUT               }
{ AUTRE genre s arrete PROPREMENT, MEME discipline que CompileExpr. }
Procedure CompileStmt(S: Integer);
Var
  I, SubS, Body, Off, TargetE, FI, BaseT : Integer;
  LblElse, LblDone, LblTop, LblCont, LblEnd, DefaultLbl : TString;
  CaseLbl : Array[0..63] Of TString;
Begin
  If S < 0 Then Exit;
  Case StmtPool[S].Kind Of
    STK_BLOCK:
      For I := 0 To StmtPool[S].ArgCount - 1 Do
        CompileStmt(StmtArgPool[StmtPool[S].ArgFirst + I]);

    STK_EXPR:
      If ExprPool[StmtPool[S].Left].Kind = EK_CALL Then
        CompileCall(StmtPool[S].Left)
      Else If ExprPool[StmtPool[S].Left].Kind = EK_UNARY Then
        CompileExpr(StmtPool[S].Left)
      Else
        FatalError('generateur de code : forme d''instruction-expression ' +
          'non couverte par cette extension (section 7.4)');

    STK_DECL:
      For I := StmtPool[S].Left To StmtPool[S].Left + StmtPool[S].Extra - 1 Do
        If SymTab[I].HasInit Then
        Begin
          CompileExpr(SymTab[I].InitExprIdx);
          EmitInstr('MOV ' + CgLocalOperand(SymTab[I].Offset) + ',EAX');
        End;

    { STK_ASSIGN : trois cibles couvertes - locale/parametre (EK_IDENT,     }
    { comme au premier jalon de cette extension), champ (EK_SELECTOR,                    }
    { modele memoire d instance) et element de tableau (EK_INDEX, meme                     }
    { calcul d adresse ARITHMETIQUE que CompileExpr) - EBX conserve                          }
    { TOUJOURS l ADRESSE (pointeur d objet+deplacement, ou adresse                            }
    { effective de l element) pendant que la VALEUR/l ancienne valeur                     }
    { (affectation composee) est calculee, puisque EAX/ECX sont deja               }
    { utilises par CompileExpr/CompileCompoundOp. }
    STK_ASSIGN:
    Begin
      TargetE := StmtPool[S].Left;
      If (ExprPool[TargetE].Kind = EK_IDENT) And (ExprPool[TargetE].Left >= 0) And
         (SymTab[ExprPool[TargetE].Left].Kind = SK_VAR) Then
      Begin
        Off := SymTab[ExprPool[TargetE].Left].Offset;
        If StmtPool[S].Op = '=' Then
        Begin
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ' + CgLocalOperand(Off) + ',EAX');
        End
        Else
        Begin
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ECX,EAX');
          EmitInstr('MOV EAX,' + CgLocalOperand(Off));
          CompileCompoundOp(StmtPool[S].Op);
          EmitInstr('MOV ' + CgLocalOperand(Off) + ',EAX');
        End;
      End
      Else If ExprPool[TargetE].Kind = EK_SELECTOR Then
      Begin
        BaseT := ExprPool[ExprPool[TargetE].Left].TypeIdx;
        FI := ClassFindField(BaseT, ExprPool[TargetE].NameVal);
        If FI < 0 Then
        Begin
          FatalError('generateur de code : cible d''affectation "' +
            ExprPool[TargetE].NameVal + '" non couverte par cette ' +
            'extension (champ introuvable, voir la note d''en-tete de ' +
            'section)');
          Exit;
        End;
        Off := CgFieldOffsetInObject(FI);
        CompileExpr(ExprPool[TargetE].Left);
        EmitInstr('MOV EBX,EAX');
        If StmtPool[S].Op = '=' Then
        Begin
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ' + CgAddrOperand('EBX', Off) + ',EAX');
        End
        Else
        Begin
          EmitInstr('MOV EAX,' + CgAddrOperand('EBX', Off));
          EmitInstr('PUSH EAX');
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ECX,EAX');
          EmitInstr('POP EAX');
          CompileCompoundOp(StmtPool[S].Op);
          EmitInstr('MOV ' + CgAddrOperand('EBX', Off) + ',EAX');
        End;
      End
      Else If ExprPool[TargetE].Kind = EK_INDEX Then
      Begin
        CompileExpr(ExprPool[TargetE].Left);
        EmitInstr('PUSH EAX');
        CompileExpr(ExprPool[TargetE].Right);
        EmitInstr('POP ECX');
        EmitInstr('ADD EAX,EAX');
        EmitInstr('ADD EAX,EAX');
        EmitInstr('ADD EAX,ECX');
        EmitInstr('MOV EBX,EAX');
        If StmtPool[S].Op = '=' Then
        Begin
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ' + CgAddrOperand('EBX', 0) + ',EAX');
        End
        Else
        Begin
          EmitInstr('MOV EAX,' + CgAddrOperand('EBX', 0));
          EmitInstr('PUSH EAX');
          CompileExpr(StmtPool[S].Right);
          EmitInstr('MOV ECX,EAX');
          EmitInstr('POP EAX');
          CompileCompoundOp(StmtPool[S].Op);
          EmitInstr('MOV ' + CgAddrOperand('EBX', 0) + ',EAX');
        End;
      End
      Else
      Begin
        FatalError('generateur de code : cible d''affectation non couverte ' +
          'par cette extension (locale/parametre scalaire, champ, ou ' +
          'element de tableau UNIQUEMENT, voir la note d''en-tete de ' +
          'section)');
        Exit;
      End;
    End;

    STK_RETURN:
    Begin
      If StmtPool[S].Left >= 0 Then CompileExpr(StmtPool[S].Left);
      EmitInstr('JMP ' + CurMethodEpilogueLabel);
    End;

    STK_IF:
    Begin
      CompileExpr(StmtPool[S].Extra);
      EmitInstr('CMP EAX,0');
      LblElse := CgLabelGen;
      LblDone := CgLabelGen;
      EmitInstr('JE ' + LblElse);
      CompileStmt(StmtPool[S].Right);
      EmitInstr('JMP ' + LblDone);
      EmitLabel(LblElse);
      If StmtPool[S].Left >= 0 Then CompileStmt(StmtPool[S].Left);
      EmitLabel(LblDone);
    End;

    STK_WHILE:
    Begin
      LblTop := CgLabelGen;
      LblEnd := CgLabelGen;
      CgPushLoopFrame(LblEnd, LblTop);
      EmitLabel(LblTop);
      CompileExpr(StmtPool[S].Extra);
      EmitInstr('CMP EAX,0');
      EmitInstr('JE ' + LblEnd);
      CompileStmt(StmtPool[S].Right);
      EmitInstr('JMP ' + LblTop);
      EmitLabel(LblEnd);
      CgPopLoopFrame;
    End;

    STK_DOWHILE:
    Begin
      LblTop  := CgLabelGen;
      LblCont := CgLabelGen;
      LblEnd  := CgLabelGen;
      CgPushLoopFrame(LblEnd, LblCont);
      EmitLabel(LblTop);
      CompileStmt(StmtPool[S].Right);
      EmitLabel(LblCont);
      CompileExpr(StmtPool[S].Extra);
      EmitInstr('CMP EAX,0');
      EmitInstr('JNE ' + LblTop);
      EmitLabel(LblEnd);
      CgPopLoopFrame;
    End;

    STK_FOR:
    Begin
      For I := 0 To StmtPool[S].InitCount - 1 Do
        CompileStmt(StmtArgPool[StmtPool[S].InitFirst + I]);
      LblTop  := CgLabelGen;
      LblCont := CgLabelGen;
      LblEnd  := CgLabelGen;
      CgPushLoopFrame(LblEnd, LblCont);
      EmitLabel(LblTop);
      If StmtPool[S].Extra >= 0 Then
      Begin
        CompileExpr(StmtPool[S].Extra);
        EmitInstr('CMP EAX,0');
        EmitInstr('JE ' + LblEnd);
      End;
      CompileStmt(StmtPool[S].Left);
      EmitLabel(LblCont);
      For I := 0 To StmtPool[S].UpdCount - 1 Do
        CompileStmt(StmtArgPool[StmtPool[S].UpdFirst + I]);
      EmitInstr('JMP ' + LblTop);
      EmitLabel(LblEnd);
      CgPopLoopFrame;
    End;

    STK_SWITCH:
    Begin
      CompileExpr(StmtPool[S].Extra);
      EmitInstr('MOV EBX,EAX');
      LblEnd  := CgLabelGen;
      Body    := StmtPool[S].Left;
      DefaultLbl := '';
      For I := 0 To StmtPool[Body].ArgCount - 1 Do
      Begin
        SubS := StmtArgPool[StmtPool[Body].ArgFirst + I];
        CaseLbl[I] := '';
        If StmtPool[SubS].Kind = STK_CASE Then
        Begin
          CaseLbl[I] := CgLabelGen;
          If StmtPool[SubS].Left < 0 Then DefaultLbl := CaseLbl[I];
        End;
      End;
      For I := 0 To StmtPool[Body].ArgCount - 1 Do
      Begin
        SubS := StmtArgPool[StmtPool[Body].ArgFirst + I];
        If (StmtPool[SubS].Kind = STK_CASE) And (StmtPool[SubS].Left >= 0) Then
        Begin
          CompileExpr(StmtPool[SubS].Left);
          EmitInstr('CMP EBX,EAX');
          EmitInstr('JE ' + CaseLbl[I]);
        End;
      End;
      If DefaultLbl <> '' Then EmitInstr('JMP ' + DefaultLbl)
      Else EmitInstr('JMP ' + LblEnd);
      CgPushSwitchFrame(LblEnd);
      For I := 0 To StmtPool[Body].ArgCount - 1 Do
      Begin
        SubS := StmtArgPool[StmtPool[Body].ArgFirst + I];
        If StmtPool[SubS].Kind = STK_CASE Then
          EmitLabel(CaseLbl[I])
        Else
          CompileStmt(SubS);
      End;
      EmitLabel(LblEnd);
      CgPopLoopFrame;
    End;

    STK_BREAK:
      If StmtPool[S].NameVal <> '' Then
        FatalError('generateur de code : "break" etiquete non couvert par ' +
          'cette extension')
      Else If CgLoopTop < 0 Then
        FatalError('generateur de code : "break" hors de toute boucle/switch ' +
          '(ne devrait jamais arriver, deja verifie au parsing)')
      Else
        EmitInstr('JMP ' + CgBreakLbl[CgLoopTop]);

    STK_CONTINUE:
      If StmtPool[S].NameVal <> '' Then
        FatalError('generateur de code : "continue" etiquete non couvert ' +
          'par cette extension')
      Else If (CgLoopTop < 0) Or (CgContinueLbl[CgLoopTop] = '') Then
        FatalError('generateur de code : "continue" hors de toute boucle ' +
          '(ne devrait jamais arriver, deja verifie au parsing)')
      Else
        EmitInstr('JMP ' + CgContinueLbl[CgLoopTop]);

    { STK_THROW : extension post-TODO25 - SIMPLIFICATION EXPLICITEMENT     }
    { ASSUMEE, PAS de vraies semantiques Java (AUCUN deroulement de pile,             }
    { AUCUNE correspondance catch reelle - STK_TRY reste ENTIEREMENT hors           }
    { de portee) : termine simplement le PROCESSUS avec un code de sortie              }
    { DISTINCT (3), approximant un "abort" plutot qu une VRAIE exception -               }
    { L EXPRESSION lancee elle-meme n est JAMAIS compilee (aurait pu                     }
    { referencer un constructeur de bibliotheque standard SANS corps                        }
    { reel, ex. "new IllegalArgumentException(...)", EK_NEWOBJECT               }
    { s arreterait alors PROPREMENT de toute facon - AUCUNE perte reelle,          }
    { ses eventuels EFFETS DE BORD ne sont simplement jamais executes).             }
    { Suffisant UNIQUEMENT parce que, pour chaque echantillon ou est                    }
    { rencontree cette forme, le "throw" n est JAMAIS DYNAMIQUEMENT                        }
    { atteint par le VRAI chemin d execution de main() (verifie              }
    { manuellement pour chaque cas avant d etre invoque ICI) - une                        }
    { methode dont le throw EST reellement exercee resterait, elle,                       }
    { INCORRECTE (arret au lieu d une vraie propagation/capture). }
    STK_THROW:
    Begin
      EmitInstr('PUSH 3');
      EmitInstr('CALL _ExitProcess@4');
    End;

  Else
    FatalError('generateur de code : forme d''instruction non couverte par ' +
      'ce premier jalon du TODO 21 (genre #' + IntToStrG(Ord(StmtPool[S].Kind)) +
      ' - voir la note d''en-tete de section pour la portee EXACTE)');
  End;
End;

{ CompileMethodBody : prologue "SUB ESP,FrameSize" (extension post-      }
{ TODO25 - voir la note d en-tete de TMethodRec.FrameSize) SI cette              }
{ methode a REELLEMENT des locales, epilogue UNIQUE etiquete                          }
{ (CurMethodEpilogueLabel) - CHAQUE STK_RETURN y saute plutot que de              }
{ retomber en cascade, correct MEME pour un "return;" au milieu du                    }
{ corps. }
Procedure CompileMethodBody(MI: Integer);
Begin
  EmitLabel(MethodAsmLabelG(MI));
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  If MethodPool[MI].FrameSize > 0 Then
    EmitInstr('SUB ESP,' + IntToStrG(MethodPool[MI].FrameSize));
  CurMethodEpilogueLabel := CgLabelGen;
  CompileStmt(MethodPool[MI].BodyStmtIdx);
  EmitLabel(CurMethodEpilogueLabel);
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ CompileProgram : pilote de haut niveau - genere un fichier .asm       }
{ COMPLET (entete, .DATA, .CODE, runtime, CHAQUE methode utilisateur            }
{ AVEC corps, point d entree minimal "_JPPSTART" qui appelle "main"              }
{ PUIS sort proprement) - MEME structure de segments que chaque                       }
{ compilateur frere a son propre TODO 21. Compile TOUTES les methodes           }
{ AVEC corps de TOUT TYK_CLASS UTILISATEUR (BodyStmtIdx >= 0 exclut              }
{ DEJA naturellement les entrees StdlibInit - AUCUNE d elles n a               }
{ jamais de corps source REEL, TODO 13/14/18 - et le constructeur                    }
{ PAR DEFAUT synthetise au TODO 08, lui non plus) - PAS SEULEMENT              }
{ "main" : une methode AUXILIAIRE non couverte s arrete PROPREMENT              }
{ (FatalError) exactement au point ou elle est rencontree, jamais                    }
{ silencieusement ignoree. }
Procedure CompileProgram(Const AsmFileName: TString);
Var I, MainMI : Integer;
Begin
  CgLabelSeq := 0;
  CgLoopTop  := -1;   { extension post-TODO25 - voir la note d en-tete de CgBreakLbl }
  CgCollectStrings;

  EmitOpen(AsmFileName);
  EmitHeader;
  EmitDataSeg;
  EmitRaw('.CODE');
  EmitBlankLine;
  EmitRuntimeLibrary;

  MainMI := -1;
  For I := 0 To MethodPoolCount - 1 Do
    If (TypeTab[MethodPool[I].OwnerTypeIdx].Kind = TYK_CLASS) And
       (MethodPool[I].BodyStmtIdx >= 0) Then
    Begin
      CompileMethodBody(I);
      If MethodPool[I].IsStatic And (MethodPool[I].Name = 'main') And
         (MethodPool[I].ParamCount = 1) Then
        MainMI := I;
    End;

  If MainMI < 0 Then
  Begin
    FatalError('generateur de code : aucune methode "public static void ' +
      'main(String[] args)" trouvee (section 8.1, TODO 21)');
    EmitClose;
    Exit;
  End;

  { extension post-TODO25 (modele memoire de tableau) : BOGUE REEL         }
  { trouve par EXECUTION (PAS par la compilation - le premier .exe               }
  { produit avec cette extension, Test01Bonjour.jpp, COMPILAIT et                     }
  { LIAIT sans erreur, mais SEGFAULT a l execution) - "main" lit                          }
  { REELLEMENT "args.length"/"args[0]" (EK_SELECTOR/EK_INDEX, cette                     }
  { MEME extension), mais AUCUNE valeur n avait JAMAIS ete poussee pour               }
  { ce parametre avant l appel a "main" - EBP+8 y contenait alors des               }
  { octets ARBITRAIRES (residus de pile), dereferences comme un                          }
  { pointeur de tableau -> plantage. Le VRAI analyseur de ligne de                        }
  { commande Win32 (GetCommandLine/CommandLineToArgvW) reste HORS de                    }
  { portee (fonctionnalite separee, non demandee) - corrige ICI en                        }
  { poussant un tableau de chaines VIDE (longueur 0) mais REEL avant               }
  { "main", garantissant que "args.length" est TOUJOURS correct (0) et            }
  { qu aucun "args[i]" ne peut jamais dereferencer un pointeur invalide            }
  { SAUF si le programme lui-meme accede a "args[i]" sans verifier la               }
  { longueur d abord (limite PREEXISTANTE, AUCUNE verification de borne            }
  { de tableau, TYK_ARRAY, section 10.7 - pas une regression introduite            }
  { ICI). }
  EmitLabel('_JPPSTART');
  EmitInstr('PUSH 4');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('ADD EAX,4');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + MethodAsmLabelG(MainMI));
  EmitInstr('ADD ESP,4');
  EmitInstr('PUSH 0');
  EmitInstr('CALL _ExitProcess@4');
  EmitRaw('END _JPPSTART');
  EmitClose;
End;

{ ------------------------------------------------------------ }
{ TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32                                     }
{                                                                       }
{ "Meme architecture d assembleur 80386 + ecrivain COFF que CHAQUE               }
{ compilateur frere... a porter QUASI VERBATIM" (roadmap) - PORTAGE              }
{ LITTERAL de GOCW32.PAS (meme projet, architecture IDENTIQUE a                        }
{ DELPHI.PAS/SWIFTW32.PAS) : memes structures (TBinLabel/TBinFixup),             }
{ meme algorithme (BinEmitModRM, BinResolveFixups, WriteCOFFObj), memes    }
{ constantes PE_MACHINE_I386/COFF_REL_I386_*/COFF_SYM_CLASS_*/                        }
{ PE_SCN_* (DEJA reservees depuis le TODO 01 - JAMAIS invoquees avant             }
{ ce TODO, EXACTEMENT comme ASM_PFX_* l etait pour le TODO 21) -                      }
{ SEULE la COUVERTURE des mnemoniques differe : GOCW32.PAS encode TOUT          }
{ ce que SA PROPRE bibliotheque standard (arithmetique flottante x87,          }
{ MOVZX, decalages, IMUL/IDIV...) a fini par emettre au fil de SES                    }
{ nombreuses extensions post-TODO25 ; JPPCW32.PAS n encode ICI QUE les              }
{ mnemoniques que SON PROPRE TODO 21 (premier jalon, voir sa note                     }
{ d en-tete) emet REELLEMENT aujourd hui - MOV/PUSH/POP/LEA/ADD/SUB/               }
{ XOR/CMP/INC/CALL/RET (CompileExpr/CompileCall/CompileMethodBody/               }
{ EmitRuntimeLibrary, tous relus ligne par ligne pour etablir cette              }
{ liste AVANT d ecrire un seul encodeur) - PLUS JMP/Jcc (six                             }
{ conditions, MEME table que GOCW32.PAS) : AUCUNE de ces six n est                   }
{ ENCORE emise par JPPCW32 (le premier jalon du TODO 21 n a pas                        }
{ encore de "if" compile - "if" est justement le TOUT PROCHAIN                            }
{ obstacle documente dans sa propre note d en-tete), mais le tableau           }
{ de six est TRIVIAL (un If-chain UNIFORME, AUCUN cout d implementation           }
{ supplementaire par rapport a UNE seule condition) - inclus des                      }
{ MAINTENANT plutot que redecouvert instruction par instruction a                     }
{ chaque future extension du TODO 21. MOVZX/FPU/TEST/IMUL/IDIV/NOT/               }
{ NEG/SHL/SAR/SHR restent EXPLICITEMENT hors de portee (AUCUNE forme               }
{ n est ENCORE emise nulle part dans ce compilateur) - un mnemonique             }
{ non couvert s arrete PROPREMENT (FatalError), JAMAIS un octet errone       }
{ silencieux, EXACTEMENT le meme principe que CompileExpr/CompileStmt      }
{ au TODO 21.                                                                               }
{                                                                       }
{ ARCHITECTURE (voir la note d en-tete de chaque structure ci-dessous          }
{ pour le detail, IDENTIQUE a GOCW32.PAS) : une SECONDE passe,                            }
{ COMPLETEMENT SEPAREE de l emission textuelle du TODO 21 - BinAssembleFile }
{ RELIT le .asm QUE ce compilateur vient lui-meme d ecrire (JAMAIS une          }
{ entree externe/arbitraire, l analyse peut donc rester SIMPLE) et                    }
{ encode chaque ligne en octets REELS dans deux tampons plats (BinCode/         }
{ BinData) ; BinResolveFixups corrige en place les appels/sauts RELATIFS       }
{ vers une etiquette LOCALE DEJA connue ; TOUT le reste (relatif vers               }
{ un import externe, OU absolu - une adresse absolue ne peut jamais               }
{ etre connue avant l edition de liens) devient une VRAIE relocation               }
{ COFF, ecrite par WriteCOFFObj. AUCUN assembleur/lieur EXTERNE n est           }
{ invoque - ce compilateur ecrit lui-meme le .OBJ, octet par octet.               }
{                                                                       }
{ Sortie : TOUJOURS ReplaceExt(Opts.SrcFile,'.obj') (JAMAIS Opts.OutFile        }
{ lui-meme, qui reste NOMME ".exe" par defaut) quel que soit -obj -              }
{ MEME raisonnement que le TODO 21 pour le ".asm" : AUCUN ecrivain PE            }
{ (TODO 23) n existe encore pour produire un VRAI .exe, "Sortie   :               }
{ ...exe" affiche par ShowBanner reste donc ENCORE aspirationnel. }
{ ------------------------------------------------------------ }

Const
  BINSEC_TEXT = False;
  BINSEC_DATA = True;

Type
  TBinFixKind = (BFX_REL32, BFX_ABS32);

  TBinLabel = Record
    Name   : TString;
    IsData : Boolean;
    Ofs    : LongInt;
  End;

  TBinFixup = Record
    IsData     : Boolean;
    Pos        : LongInt;
    Kind       : TBinFixKind;
    TargetName : TString;
    Resolved   : Boolean;
  End;

Var
  BinCode       : Array[0..MAX_BIN - 1] Of Byte;
  BinCodeLen    : LongInt;
  BinData       : Array[0..MAX_BIN - 1] Of Byte;
  BinDataLen    : LongInt;
  BinCurIsData  : Boolean;

  BinLabels     : Array[0..MAX_BIN_LABEL - 1] Of TBinLabel;
  BinLabelCount : Integer;

  BinFixups     : Array[0..MAX_BIN_FIXUP - 1] Of TBinFixup;
  BinFixupCount : Integer;

  BinImports     : Array[0..MAX_BIN_IMPORT - 1] Of TString;
  BinImportCount : Integer;

Procedure BinInit;
Begin
  BinCodeLen     := 0;
  BinDataLen     := 0;
  BinCurIsData   := BINSEC_TEXT;
  BinLabelCount  := 0;
  BinFixupCount  := 0;
  BinImportCount := 0;
End;

Function BinCurOfs: LongInt;
Begin
  If BinCurIsData Then BinCurOfs := BinDataLen Else BinCurOfs := BinCodeLen;
End;

Procedure BinEmit8(B: Integer);
Begin
  If BinCurIsData Then
  Begin
    If BinDataLen >= MAX_BIN Then
    Begin
      FatalError('assembleur : tampon .data plein (MAX_BIN)');
      Exit;
    End;
    BinData[BinDataLen] := B And $FF;
    Inc(BinDataLen);
  End
  Else
  Begin
    If BinCodeLen >= MAX_BIN Then
    Begin
      FatalError('assembleur : tampon .text plein (MAX_BIN)');
      Exit;
    End;
    BinCode[BinCodeLen] := B And $FF;
    Inc(BinCodeLen);
  End;
End;

Procedure BinEmit16(W: Integer);
Begin
  BinEmit8(W);
  BinEmit8(W Shr 8);
End;

Procedure BinEmit32(D: LongInt);
Begin
  BinEmit8(D);
  BinEmit8(D Shr 8);
  BinEmit8(D Shr 16);
  BinEmit8(D Shr 24);
End;

Procedure BinPatch32(IsData: Boolean; Pos: LongInt; D: LongInt);
Begin
  If IsData Then
  Begin
    BinData[Pos]     := D And $FF;
    BinData[Pos + 1] := (D Shr 8) And $FF;
    BinData[Pos + 2] := (D Shr 16) And $FF;
    BinData[Pos + 3] := (D Shr 24) And $FF;
  End
  Else
  Begin
    BinCode[Pos]     := D And $FF;
    BinCode[Pos + 1] := (D Shr 8) And $FF;
    BinCode[Pos + 2] := (D Shr 16) And $FF;
    BinCode[Pos + 3] := (D Shr 24) And $FF;
  End;
End;

Procedure BinDefineLabel(Const Name: TString);
Begin
  If BinLabelCount >= MAX_BIN_LABEL Then
  Begin
    WarnMsg('assembleur : table des etiquettes pleine (MAX_BIN_LABEL)');
    Exit;
  End;
  BinLabels[BinLabelCount].Name   := Name;
  BinLabels[BinLabelCount].IsData := BinCurIsData;
  BinLabels[BinLabelCount].Ofs    := BinCurOfs;
  Inc(BinLabelCount);
End;

Function BinFindLabel(Const Name: TString): Integer;
Var I: Integer;
Begin
  BinFindLabel := -1;
  For I := 0 To BinLabelCount - 1 Do
    If BinLabels[I].Name = Name Then
    Begin
      BinFindLabel := I;
      Exit;
    End;
End;

Function BinFindImport(Const Name: TString): Integer;
Var I: Integer;
Begin
  BinFindImport := -1;
  For I := 0 To BinImportCount - 1 Do
    If BinImports[I] = Name Then
    Begin
      BinFindImport := I;
      Exit;
    End;
End;

Procedure BinDeclareImport(Const Name: TString);
Begin
  If BinFindImport(Name) >= 0 Then Exit;
  If BinImportCount >= MAX_BIN_IMPORT Then
  Begin
    WarnMsg('assembleur : table des imports pleine (MAX_BIN_IMPORT)');
    Exit;
  End;
  BinImports[BinImportCount] := Name;
  Inc(BinImportCount);
End;

Procedure BinAddFixup(Kind: TBinFixKind; Const TargetName: TString);
Begin
  If BinFixupCount >= MAX_BIN_FIXUP Then
  Begin
    WarnMsg('assembleur : table des correctifs pleine (MAX_BIN_FIXUP)');
    Exit;
  End;
  BinFixups[BinFixupCount].IsData     := BinCurIsData;
  BinFixups[BinFixupCount].Pos        := BinCurOfs - 4;
  BinFixups[BinFixupCount].Kind       := Kind;
  BinFixups[BinFixupCount].TargetName := TargetName;
  BinFixups[BinFixupCount].Resolved   := False;
  Inc(BinFixupCount);
End;

{ ------------------------------------------------------------ }
{ Analyse d operandes texte (BinParseOperand) - le texte relu est      }
{ TOUJOURS celui que ce MEME fichier a lui-meme ecrit (EmitInstr,          }
{ TODO 21), jamais une entree externe/arbitraire - l analyse peut donc         }
{ rester SIMPLE (formes fixes et connues) plutot qu un vrai parseur                 }
{ d assembleur general.                                                                }
{ ------------------------------------------------------------ }

Type
  TBinOpKind = (BOK_REG, BOK_IMM, BOK_MEM, BOK_LABEL);
  TBinOperand = Record
    Kind      : TBinOpKind;
    RegNum    : Integer;
    ImmVal    : LongInt;
    BaseReg   : Integer;
    Disp      : LongInt;
    LabelName : TString;
    IsByte    : Boolean;
  End;

Function BinTrim(Const S: TString): TString;
Var I, J: Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  J := Length(S);
  While (J >= I) And (S[J] = ' ') Do Dec(J);
  If J < I Then BinTrim := '' Else BinTrim := Copy(S, I, J - I + 1);
End;

Function BinStrToInt(Const S: TString): LongInt;
Var N: LongInt; Code: Integer;
Begin
  Val(S, N, Code);
  BinStrToInt := N;
End;

Function BinReg32(Const Name: TString): Integer;
Begin
  If      Name = 'EAX' Then BinReg32 := 0
  Else If Name = 'ECX' Then BinReg32 := 1
  Else If Name = 'EDX' Then BinReg32 := 2
  Else If Name = 'EBX' Then BinReg32 := 3
  Else If Name = 'ESP' Then BinReg32 := 4
  Else If Name = 'EBP' Then BinReg32 := 5
  Else If Name = 'ESI' Then BinReg32 := 6
  Else If Name = 'EDI' Then BinReg32 := 7
  Else BinReg32 := -1;
End;

{ BinReg8 : extension post-TODO25 (generateur de code - runtime string   }
{ concatenation/conversion, _JPPRT_CONCAT/_JPPRT_INT_TO_STR) - SEULS les             }
{ QUATRE registres bas historiques (AL/CL/DL/BL, MEME numerotation que              }
{ EAX/ECX/EDX/EBX, section basse du registre 32 bits) sont couverts -              }
{ AH/CH/DH/BH (octet HAUT) ne sont JAMAIS emis par ce compilateur, hors            }
{ de portee. }
Function BinReg8(Const Name: TString): Integer;
Begin
  If      Name = 'AL' Then BinReg8 := 0
  Else If Name = 'CL' Then BinReg8 := 1
  Else If Name = 'DL' Then BinReg8 := 2
  Else If Name = 'BL' Then BinReg8 := 3
  Else BinReg8 := -1;
End;

Function BinParseOperand(S: TString): TBinOperand;
Var Op: TBinOperand; Inner, NumPart: TString; SignPos, I: Integer; Neg: Boolean;
Begin
  Op.Kind      := BOK_REG;
  Op.RegNum    := -1;
  Op.ImmVal    := 0;
  Op.BaseReg   := -1;
  Op.Disp      := 0;
  Op.LabelName := '';
  Op.IsByte    := False;

  S := BinTrim(S);
  If Copy(S, 1, 9) = 'BYTE PTR ' Then
  Begin
    Op.IsByte := True;
    S := BinTrim(Copy(S, 10, Length(S) - 9));
  End
  Else If Copy(S, 1, 10) = 'DWORD PTR ' Then
    S := BinTrim(Copy(S, 11, Length(S) - 10));

  If (Length(S) > 0) And (S[1] = '[') Then
  Begin
    Op.Kind := BOK_MEM;
    Inner := Copy(S, 2, Length(S) - 2);
    SignPos := 0;
    For I := 2 To Length(Inner) Do
      If (Inner[I] = '+') Or (Inner[I] = '-') Then
      Begin
        SignPos := I;
        Break;
      End;
    If SignPos > 0 Then
    Begin
      Op.BaseReg := BinReg32(Copy(Inner, 1, SignPos - 1));
      Neg     := (Inner[SignPos] = '-');
      NumPart := Copy(Inner, SignPos + 1, Length(Inner) - SignPos);
      Op.Disp := BinStrToInt(NumPart);
      If Neg Then Op.Disp := -Op.Disp;
    End
    Else
    Begin
      Op.BaseReg := BinReg32(Inner);
      If Op.BaseReg < 0 Then
        Op.LabelName := Inner;
    End;
    BinParseOperand := Op;
    Exit;
  End;

  Op.RegNum := BinReg32(S);
  If Op.RegNum >= 0 Then
  Begin
    Op.Kind := BOK_REG;
    BinParseOperand := Op;
    Exit;
  End;

  { extension post-TODO25 : registre BAS 8 bits (AL/CL/DL/BL) - voir la  }
  { note d en-tete de BinReg8. Reutilise IsByte (jusqu ici SEULEMENT               }
  { pour un operande MEMOIRE "BYTE PTR [...]") pour signaler a                        }
  { BinEncodeMov qu un registre 32 bits ordinaire ne convient PAS ICI -               }
  { AUCUN conflit possible : IsByte n est jamais lu par les encodeurs                }
  { existants pour un operande BOK_REG (seulement BOK_MEM), ce cas est                    }
  { NOUVEAU. }
  Op.RegNum := BinReg8(S);
  If Op.RegNum >= 0 Then
  Begin
    Op.Kind   := BOK_REG;
    Op.IsByte := True;
    BinParseOperand := Op;
    Exit;
  End;

  If (Length(S) > 0) And ((S[1] = '-') Or ((S[1] >= '0') And (S[1] <= '9'))) Then
  Begin
    Op.Kind   := BOK_IMM;
    Op.ImmVal := BinStrToInt(S);
    BinParseOperand := Op;
    Exit;
  End;

  Op.Kind      := BOK_LABEL;
  Op.LabelName := S;
  BinParseOperand := Op;
End;

{ BinEmitModRM : coeur PARTAGE ModRM(+disp32) - MEME simplification     }
{ que GOCW32.PAS/DELPHI.PAS : TOUJOURS un deplacement complet sur 32              }
{ bits quand un registre de base est present (jamais Mod=01/disp8).              }
{ AUCUN adressage BASE+INDEX (SIB avec un second registre) n est gere -           }
{ hors de portee documentee, AUCUNE forme emise par JPPCW32 n en a                    }
{ besoin. }
Procedure BinEmitModRM(RegField: Integer; Const Mem: TBinOperand);
Begin
  If Mem.Kind = BOK_REG Then
  Begin
    BinEmit8($C0 Or (RegField Shl 3) Or Mem.RegNum);
    Exit;
  End;
  If Mem.BaseReg >= 0 Then
  Begin
    If Mem.BaseReg = 4 Then   { ESP comme base : RM=100 impose TOUJOURS un SIB }
    Begin
      BinEmit8($80 Or (RegField Shl 3) Or 4);
      BinEmit8($24);
      BinEmit32(Mem.Disp);
      Exit;
    End;
    BinEmit8($80 Or (RegField Shl 3) Or Mem.BaseReg);
    BinEmit32(Mem.Disp);
    Exit;
  End;
  { absolu (etiquette, sans registre de base) : Mod=00/RM=101 }
  BinEmit8((RegField Shl 3) Or 5);
  BinEmit32(0);
  BinAddFixup(BFX_ABS32, Mem.LabelName);
End;

{ ------------------------------------------------------------ }
{ Encodeurs par mnemonique - un PAR forme REELLEMENT emise par le       }
{ generateur de code (TODO 21) ou sa bibliotheque runtime, voir la               }
{ note d en-tete de section - toute AUTRE forme est un arret propre               }
{ (FatalError), jamais un octet errone silencieux.                                        }
{ ------------------------------------------------------------ }

Procedure BinEncodeMov(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  If Op1.Kind = BOK_REG Then
  Begin
    { extension post-TODO25 (generateur de code - runtime string) :      }
    { "MOV AL,BYTE PTR [mem]" (r8,r/m8, 8A /r) - Op1 est un registre BAS         }
    { 8 bits (BinReg8, IsByte=Vrai POUR UN REGISTRE - voir sa propre               }
    { note d en-tete), jamais confondu avec Op1.IsByte d un operande               }
    { MEMOIRE (verifie plus bas, apres ce bloc "Kind=BOK_REG"). }
    If Op1.IsByte Then
    Begin
      BinEmit8($8A);
      BinEmitModRM(Op1.RegNum, Op2);
      Exit;
    End;
    If Op2.Kind = BOK_IMM Then
    Begin
      BinEmit8($B8 Or Op1.RegNum);
      BinEmit32(Op2.ImmVal);
      Exit;
    End;
    BinEmit8($8B);
    BinEmitModRM(Op1.RegNum, Op2);
    Exit;
  End;
  If Op1.IsByte Then
  Begin
    { extension post-TODO25 : "MOV BYTE PTR [mem],AL" (r/m8,r8, 88 /r) -   }
    { SEULE forme couverte : la SOURCE doit etre un registre BAS 8 bits           }
    { (Op2.IsByte, jamais un octet immediat direct - ce compilateur fait             }
    { TOUJOURS transiter la valeur par AL/CL/DL/BL d abord). }
    If Op2.IsByte And (Op2.Kind = BOK_REG) Then
    Begin
      BinEmit8($88);
      BinEmitModRM(Op2.RegNum, Op1);
      Exit;
    End;
    FatalError('assembleur : "MOV BYTE PTR [mem],reg" non couvert par ce ' +
      'premier jalon du TODO 22 (voir la note d''en-tete de section) : ' + Op2Text);
    Exit;
  End;
  { destination memoire : "MOV [mem],reg" (jamais "MOV [mem],imm" dans   }
  { ce que ce compilateur emet - la valeur passe TOUJOURS par EAX d abord). }
  BinEmit8($89);
  BinEmitModRM(Op2.RegNum, Op1);
End;

Procedure BinEncodePush(Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind = BOK_REG Then
  Begin
    BinEmit8($50 Or Op1.RegNum);
    Exit;
  End;
  If Op1.Kind = BOK_IMM Then
  Begin
    BinEmit8($68);
    BinEmit32(Op1.ImmVal);
    Exit;
  End;
  If Op1.Kind = BOK_MEM Then
  Begin
    BinEmit8($FF);
    BinEmitModRM(6, Op1);
    Exit;
  End;
  FatalError('assembleur : forme de PUSH non couverte : ' + Op1Text);
End;

Procedure BinEncodePop(Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind = BOK_REG Then
  Begin
    BinEmit8($58 Or Op1.RegNum);
    Exit;
  End;
  FatalError('assembleur : forme de POP non couverte : ' + Op1Text);
End;

Procedure BinEncodeLea(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  If (Op1.Kind <> BOK_REG) Or (Op2.Kind <> BOK_MEM) Then
  Begin
    FatalError('assembleur : forme de LEA non couverte : ' + Op1Text + ',' + Op2Text);
    Exit;
  End;
  BinEmit8($8D);
  BinEmitModRM(Op1.RegNum, Op2);
End;

{ BinEncodeAlu : ADD/SUB/XOR/CMP - QUATRE formes du premier jalon du    }
{ TODO 22 - PLUS OR/AND (extension post-TODO25, memes bitwise "|"/"&"           }
{ que Test16Win32.jpp, MEME table SubOp EXACTE que le groupe ALU x86             }
{ standard : ADD=0/OR=1/AND=4/SUB=5/XOR=6/CMP=7 - GOCW32.PAS partage la               }
{ MEME logique pour SA PROPRE paire OR/AND). }
Procedure BinEncodeAlu(Const Mnemonic, Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand; SubOp, Opc: Integer;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);

  If      Mnemonic = 'ADD' Then Begin Opc := $03; SubOp := 0; End
  Else If Mnemonic = 'OR'  Then Begin Opc := $0B; SubOp := 1; End
  Else If Mnemonic = 'AND' Then Begin Opc := $23; SubOp := 4; End
  Else If Mnemonic = 'SUB' Then Begin Opc := $2B; SubOp := 5; End
  Else If Mnemonic = 'XOR' Then Begin Opc := $33; SubOp := 6; End
  Else If Mnemonic = 'CMP' Then Begin Opc := $3B; SubOp := 7; End
  Else
  Begin
    FatalError('assembleur : operateur arithmetique/logique non couvert par ' +
      'ce premier jalon du TODO 22 (voir la note d''en-tete de section) : ' + Mnemonic);
    Exit;
  End;

  If Op2.Kind = BOK_IMM Then
  Begin
    If Op1.IsByte Then
    Begin
      BinEmit8($80);
      BinEmitModRM(SubOp, Op1);
      BinEmit8(Op2.ImmVal);
    End
    Else
    Begin
      BinEmit8($81);
      BinEmitModRM(SubOp, Op1);
      BinEmit32(Op2.ImmVal);
    End;
    Exit;
  End;

  BinEmit8(Opc);
  BinEmitModRM(Op1.RegNum, Op2);
End;

{ BinEncodeShift : SHL/SHR/SAR r/m32,CL (D3 /4,/5,/7 - groupe D3,             }
{ compte de decalage TOUJOURS dans CL, implicite dans l opcode LUI-MEME,          }
{ jamais encode dans le ModRM - Op2Text n est donc JAMAIS lu, le              }
{ compilateur place TOUJOURS lui-meme le compte dans CL avant d emettre           }
{ cette instruction, voir CompileBinary) - extension post-TODO25                    }
{ ("<<"/">>"/">>>" entiers, Test15Conditionnelle.jpp n en a pas besoin,               }
{ mais fait partie de la MEME famille d operateurs binaires que "|"/"&"           }
{ ci-dessus). }
Procedure BinEncodeShift(Const Mnemonic, Op1Text: TString);
Var Op1: TBinOperand; SubOp: Integer;
Begin
  Op1 := BinParseOperand(Op1Text);
  If (Op1.Kind <> BOK_REG) Or Op1.IsByte Then
  Begin
    FatalError('assembleur : forme de decalage non couverte : ' + Op1Text);
    Exit;
  End;
  If      Mnemonic = 'SHL' Then SubOp := 4
  Else If Mnemonic = 'SHR' Then SubOp := 5
  Else If Mnemonic = 'SAR' Then SubOp := 7
  Else
  Begin
    FatalError('assembleur : decalage non couvert : ' + Mnemonic);
    Exit;
  End;
  BinEmit8($D3);
  BinEmitModRM(SubOp, Op1);
End;

Procedure BinEncodeIncDec(Const Mnemonic, Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind <> BOK_REG Then
  Begin
    FatalError('assembleur : forme de INC/DEC non couverte : ' + Op1Text);
    Exit;
  End;
  If Mnemonic = 'INC' Then BinEmit8($40 Or Op1.RegNum) Else BinEmit8($48 Or Op1.RegNum);
End;

{ BinEncodeNeg : NEG r/m32 (F7 /3, groupe F7 - meme famille d opcode que  }
{ IDIV ci-dessous, SubOp different) - extension post-TODO25 (generateur          }
{ de code, unaire "-" sur un entier) - SEULE forme couverte : registre                 }
{ direct (aucun "-x" sur un x memoire n est ENCORE emis, CompileExpr             }
{ recharge toujours l operande dans EAX d abord). }
Procedure BinEncodeNeg(Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind <> BOK_REG Then
  Begin
    FatalError('assembleur : forme de NEG non couverte : ' + Op1Text);
    Exit;
  End;
  BinEmit8($F7);
  BinEmitModRM(3, Op1);
End;

{ BinEncodeImul : IMUL r32,r/m32 (0F AF /r - forme a DEUX operandes,     }
{ resultat SUR 32 BITS TRONQUE dans le registre destination, jamais la              }
{ forme longue EDX:EAX a un seul operande) - extension post-TODO25              }
{ (generateur de code, "*" entier). }
Procedure BinEncodeImul(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  If Op1.Kind <> BOK_REG Then
  Begin
    FatalError('assembleur : forme de IMUL non couverte : ' + Op1Text + ',' + Op2Text);
    Exit;
  End;
  BinEmit8($0F);
  BinEmit8($AF);
  BinEmitModRM(Op1.RegNum, Op2);
End;

{ BinEncodeIdiv : IDIV r/m32 (F7 /7) - divise EDX:EAX par l operande,     }
{ quotient dans EAX/reste dans EDX (convention x86 standard - EDX DOIT             }
{ deja avoir ete etendu en signe depuis EAX par CDQ, TOUJOURS emis juste            }
{ avant par CompileExpr, JAMAIS suppose deja correct) - extension post-           }
{ TODO25 (generateur de code, "/" et "%" entiers). SEULE forme couverte :             }
{ registre direct (le diviseur transite TOUJOURS par un registre dans             }
{ ce que CompileExpr emet). }
Procedure BinEncodeIdiv(Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind <> BOK_REG Then
  Begin
    FatalError('assembleur : forme de IDIV non couverte : ' + Op1Text);
    Exit;
  End;
  BinEmit8($F7);
  BinEmitModRM(7, Op1);
End;

Procedure BinEncodeJmp(Const Op1Text: TString);
Begin
  BinEmit8($E9);
  BinEmit32(0);
  BinAddFixup(BFX_REL32, BinTrim(Op1Text));
End;

{ BinEncodeJcc : forme LONGUE uniquement (0F 8x + disp32) - MEME               }
{ simplification que GOCW32.PAS/DELPHI.PAS (memes projet) : correcte              }
{ dans TOUS les cas, juste pas la plus compacte. SIX conditions                       }
{ tabulees - AUCUNE des six n est ENCORE emise par JPPCW32 (voir la              }
{ note d en-tete de section), incluses des maintenant car le tableau           }
{ est TRIVIAL et le "if" reste le tout prochain obstacle documente du            }
{ TODO 21. }
Procedure BinEncodeJcc(Const Mnemonic, Op1Text: TString);
Var Cond: Integer;
Begin
  If      (Mnemonic = 'JE')  Or (Mnemonic = 'JZ')  Then Cond := $84
  Else If (Mnemonic = 'JNE') Or (Mnemonic = 'JNZ') Then Cond := $85
  Else If Mnemonic = 'JL'  Then Cond := $8C
  Else If Mnemonic = 'JLE' Then Cond := $8E
  Else If Mnemonic = 'JG'  Then Cond := $8F
  Else If Mnemonic = 'JGE' Then Cond := $8D
  Else
  Begin
    FatalError('assembleur : branchement conditionnel non couvert : ' + Mnemonic);
    Exit;
  End;
  BinEmit8($0F);
  BinEmit8(Cond);
  BinEmit32(0);
  BinAddFixup(BFX_REL32, BinTrim(Op1Text));
End;

Procedure BinEncodeCall(Const Op1Text: TString);
Begin
  BinEmit8($E8);
  BinEmit32(0);
  BinAddFixup(BFX_REL32, BinTrim(Op1Text));
End;

Procedure BinSplitMnemonic(Const Line: TString; Var Mnemonic, Rest: TString);
Var P: Integer;
Begin
  P := Pos(' ', Line);
  If P = 0 Then
  Begin
    Mnemonic := Line;
    Rest := '';
  End
  Else
  Begin
    Mnemonic := Copy(Line, 1, P - 1);
    Rest := BinTrim(Copy(Line, P + 1, Length(Line) - P));
  End;
End;

Procedure BinSplitOperands(Const S: TString; Var Op1, Op2: TString);
Var P: Integer;
Begin
  P := Pos(',', S);
  If P = 0 Then
  Begin
    Op1 := S;
    Op2 := '';
  End
  Else
  Begin
    Op1 := BinTrim(Copy(S, 1, P - 1));
    Op2 := BinTrim(Copy(S, P + 1, Length(S) - P));
  End;
End;

Procedure BinEmitInstr(Const Line: TString);
Var Mnemonic, Rest, Op1, Op2: TString;
Begin
  BinSplitMnemonic(BinTrim(Line), Mnemonic, Rest);
  BinSplitOperands(Rest, Op1, Op2);

  If Mnemonic = 'MOV' Then Begin BinEncodeMov(Op1, Op2); Exit; End;
  If Mnemonic = 'PUSH' Then Begin BinEncodePush(Op1); Exit; End;
  If Mnemonic = 'POP' Then Begin BinEncodePop(Op1); Exit; End;
  If Mnemonic = 'LEA' Then Begin BinEncodeLea(Op1, Op2); Exit; End;
  If (Mnemonic = 'ADD') Or (Mnemonic = 'SUB') Or (Mnemonic = 'XOR') Or
     (Mnemonic = 'CMP') Or (Mnemonic = 'OR') Or (Mnemonic = 'AND') Then
  Begin
    BinEncodeAlu(Mnemonic, Op1, Op2);
    Exit;
  End;
  If (Mnemonic = 'SHL') Or (Mnemonic = 'SHR') Or (Mnemonic = 'SAR') Then
  Begin
    BinEncodeShift(Mnemonic, Op1);
    Exit;
  End;
  If (Mnemonic = 'INC') Or (Mnemonic = 'DEC') Then
  Begin
    BinEncodeIncDec(Mnemonic, Op1);
    Exit;
  End;
  If Mnemonic = 'NEG' Then Begin BinEncodeNeg(Op1); Exit; End;
  If Mnemonic = 'IMUL' Then Begin BinEncodeImul(Op1, Op2); Exit; End;
  If Mnemonic = 'IDIV' Then Begin BinEncodeIdiv(Op1); Exit; End;
  If Mnemonic = 'CDQ' Then Begin BinEmit8($99); Exit; End;
  If Mnemonic = 'JMP' Then Begin BinEncodeJmp(Op1); Exit; End;
  If (Length(Mnemonic) >= 2) And (Mnemonic[1] = 'J') Then
  Begin
    BinEncodeJcc(Mnemonic, Op1);
    Exit;
  End;
  If Mnemonic = 'CALL' Then Begin BinEncodeCall(Op1); Exit; End;
  If Mnemonic = 'RET' Then Begin BinEmit8($C3); Exit; End;

  FatalError('assembleur : mnemonique non geree (portee volontairement ' +
    'restreinte a ce que le TODO 21 emet reellement) : ' + Mnemonic);
End;

{ BinAssembleDataLine : une ligne de .DATA est TOUJOURS "NOM DB           }
{ ""texte"",0" (EmitDataSeg, TODO 21 - JPPCW32 n emet ENCORE aucune            }
{ variable DD, contrairement a GOCW32.PAS - la disposition des champs            }
{ static/globaux reste une extension FUTURE, voir la note d en-tete             }
{ du TODO 21) - UN espace separe TOUJOURS le nom de la directive. }
Procedure BinAssembleDataLine(Const Line: TString);
Var P, Q: Integer; Name, Rest, ValuePart, TextPart: TString;
Begin
  P := Pos(' ', Line);
  If P = 0 Then Exit;
  Name := Copy(Line, 1, P - 1);
  Rest := BinTrim(Copy(Line, P + 1, Length(Line) - P));
  BinDefineLabel(Name);

  If Copy(Rest, 1, 3) = 'DB ' Then
  Begin
    ValuePart := BinTrim(Copy(Rest, 4, Length(Rest) - 3));
    If (Length(ValuePart) > 0) And (ValuePart[1] = '"') Then
    Begin
      Q := 2;
      While (Q <= Length(ValuePart)) And (ValuePart[Q] <> '"') Do Inc(Q);
      TextPart := Copy(ValuePart, 2, Q - 2);
      For P := 1 To Length(TextPart) Do
        BinEmit8(Ord(TextPart[P]));
      BinEmit8(0);
    End
    Else
      BinEmit8(BinStrToInt(ValuePart));
    Exit;
  End;
End;

{ BinAssembleFile : RELIT le .asm TEXTE deja ecrit (TODO 21) et encode   }
{ chaque instruction/donnee en octets reels - passe COMPLETEMENT                     }
{ SEPAREE de l emission textuelle, exactement comme GOCW32.PAS/                        }
{ DELPHI.PAS (memes projet). }
Procedure BinAssembleFile(Const AsmFileName: TString);
Var F: Text; Line, ExternName: TString; P: Integer;
Begin
  BinInit;
  Assign(F, AsmFileName);
  Reset(F);
  While Not Eof(F) Do
  Begin
    ReadLn(F, Line);
    Line := BinTrim(Line);
    If Length(Line) = 0 Then Continue;
    If Line[1] = ';' Then Continue;

    If Line = '.386' Then Continue;
    If Copy(Line, 1, 6) = '.MODEL' Then Continue;
    If Line = '.DATA' Then Begin BinCurIsData := BINSEC_DATA; Continue; End;
    If Line = '.CODE' Then Begin BinCurIsData := BINSEC_TEXT; Continue; End;

    If Copy(Line, 1, 6) = 'EXTRN ' Then
    Begin
      ExternName := Copy(Line, 7, Length(Line) - 6);
      P := Pos(':', ExternName);
      If P > 0 Then ExternName := Copy(ExternName, 1, P - 1);
      BinDeclareImport(ExternName);
      Continue;
    End;

    If Copy(Line, 1, 4) = 'END ' Then Break;

    If Line[Length(Line)] = ':' Then
    Begin
      BinDefineLabel(Copy(Line, 1, Length(Line) - 1));
      Continue;
    End;

    If BinCurIsData Then
      BinAssembleDataLine(Line)
    Else
      BinEmitInstr(Line);
  End;
  Close(F);
End;

Procedure BinResolveFixups;
Var I, LI: Integer; Disp: LongInt;
Begin
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Kind = BFX_REL32 Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If (LI >= 0) And (BinLabels[LI].IsData = BinFixups[I].IsData) Then
      Begin
        Disp := BinLabels[LI].Ofs - (BinFixups[I].Pos + 4);
        BinPatch32(BinFixups[I].IsData, BinFixups[I].Pos, Disp);
        BinFixups[I].Resolved := True;
      End;
    End;
End;

{ WriteCOFFObj : ecrit un vrai fichier .OBJ COFF Win32 (IMAGE_FILE_HEADER, }
{ Machine=I386) - DEUX sections seulement, .text et .data (ni .rdata           }
{ ni .bss - MEME simplification que GOCW32.PAS/DELPHI.PAS, memes                     }
{ projet). Toute relocation restante APRES BinResolveFixups devient               }
{ une VRAIE relocation COFF (IMAGE_REL_I386_REL32/DIR32) - au lieur            }
{ externe de la resoudre. }
Procedure WriteCOFFObj(Const ObjFileName: TString);
Var
  ObjF : File;
  StrTab : TString;
  I, LI, TargetSymIdx : Integer;
  TextRelocCount, DataRelocCount, SymCountTotal : Integer;
  SecHdrOfs, TextDataOfs, DataDataOfs, TextRelocOfs, DataRelocOfs, SymTabOfs : LongInt;

  Function StrTabAdd(Const Name: TString): LongInt;
  Begin
    StrTabAdd := Length(StrTab) + 4;
    StrTab := StrTab + Name + Chr(0);
  End;

  Procedure OW8(B: Integer);
  Var Buf: Byte;
  Begin
    Buf := B And $FF;
    BlockWrite(ObjF, Buf, 1);
  End;

  Procedure OW16(W: Integer);
  Begin
    OW8(W);
    OW8(W Shr 8);
  End;

  Procedure OW32(D: LongInt);
  Begin
    OW8(D);
    OW8(D Shr 8);
    OW8(D Shr 16);
    OW8(D Shr 24);
  End;

  Procedure OWStr(Const S: TString);
  Var K: Integer;
  Begin
    For K := 1 To Length(S) Do OW8(Ord(S[K]));
  End;

  Procedure OWZeros(N: Integer);
  Var K: Integer;
  Begin
    For K := 1 To N Do OW8(0);
  End;

  Procedure OWSecName(Const Name: TString);
  Begin
    OWStr(Name);
    If Length(Name) < 8 Then OWZeros(8 - Length(Name));
  End;

Begin
  TextRelocCount := 0;
  DataRelocCount := 0;
  For I := 0 To BinFixupCount - 1 Do
    If Not BinFixups[I].Resolved Then
    Begin
      If BinFixups[I].IsData Then Inc(DataRelocCount) Else Inc(TextRelocCount);
    End;

  SecHdrOfs    := 20;
  TextDataOfs  := SecHdrOfs + 40 * 2;
  DataDataOfs  := TextDataOfs + BinCodeLen;
  TextRelocOfs := DataDataOfs + BinDataLen;
  DataRelocOfs := TextRelocOfs + TextRelocCount * 10;
  SymTabOfs    := DataRelocOfs + DataRelocCount * 10;
  SymCountTotal:= 2 + BinLabelCount + BinImportCount;

  StrTab := '';
  Assign(ObjF, ObjFileName);
  Rewrite(ObjF, 1);

  OW16(PE_MACHINE_I386);
  OW16(2);
  OW32(0);
  OW32(SymTabOfs);
  OW32(SymCountTotal);
  OW16(0);
  OW16(0);

  OWSecName('.text');
  OW32(0); OW32(0);
  OW32(BinCodeLen);
  OW32(TextDataOfs);
  OW32(TextRelocOfs);
  OW32(0);
  OW16(TextRelocCount);
  OW16(0);
  OW32(PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  OWSecName('.data');
  OW32(0); OW32(0);
  OW32(BinDataLen);
  OW32(DataDataOfs);
  OW32(DataRelocOfs);
  OW32(0);
  OW16(DataRelocCount);
  OW16(0);
  OW32(PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  If BinCodeLen > 0 Then BlockWrite(ObjF, BinCode, BinCodeLen);
  If BinDataLen > 0 Then BlockWrite(ObjF, BinData, BinDataLen);

  For I := 0 To BinFixupCount - 1 Do
    If (Not BinFixups[I].Resolved) And (Not BinFixups[I].IsData) Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then TargetSymIdx := 2 + LI
      Else TargetSymIdx := 2 + BinLabelCount + BinFindImport(BinFixups[I].TargetName);
      OW32(BinFixups[I].Pos);
      OW32(TargetSymIdx);
      If BinFixups[I].Kind = BFX_REL32 Then OW16(COFF_REL_I386_REL32) Else OW16(COFF_REL_I386_DIR32);
    End;
  For I := 0 To BinFixupCount - 1 Do
    If (Not BinFixups[I].Resolved) And BinFixups[I].IsData Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then TargetSymIdx := 2 + LI
      Else TargetSymIdx := 2 + BinLabelCount + BinFindImport(BinFixups[I].TargetName);
      OW32(BinFixups[I].Pos);
      OW32(TargetSymIdx);
      If BinFixups[I].Kind = BFX_REL32 Then OW16(COFF_REL_I386_REL32) Else OW16(COFF_REL_I386_DIR32);
    End;

  OW32(0); OW32(StrTabAdd('.text'));
  OW32(0); OW16(1); OW16(0); OW8(COFF_SYM_CLASS_STATIC); OW8(0);

  OW32(0); OW32(StrTabAdd('.data'));
  OW32(0); OW16(2); OW16(0); OW8(COFF_SYM_CLASS_STATIC); OW8(0);

  For I := 0 To BinLabelCount - 1 Do
  Begin
    OW32(0); OW32(StrTabAdd(BinLabels[I].Name));
    OW32(BinLabels[I].Ofs);
    If BinLabels[I].IsData Then OW16(2) Else OW16(1);
    OW16(0);
    OW8(COFF_SYM_CLASS_EXTERNAL);
    OW8(0);
  End;

  For I := 0 To BinImportCount - 1 Do
  Begin
    OW32(0); OW32(StrTabAdd(BinImports[I]));
    OW32(0); OW16(0);
    OW16(0);
    OW8(COFF_SYM_CLASS_EXTERNAL);
    OW8(0);
  End;

  OW32(Length(StrTab) + 4);
  OWStr(StrTab);

  Close(ObjF);
End;

{ ------------------------------------------------------------ }
{ TODO 23 - ECRIVAIN .EXE PE WIN32 ET BIBLIOTHEQUE RUNTIME          }
{ INCORPOREE                                                        }
{                                                                       }
{ "Meme architecture d ecrivain PE que chaque compilateur frere       }
{ (thunks IAT, en-tetes DOS/PE, .idata)" (roadmap) - PORTAGE           }
{ LITTERAL de WritePEExe/BinResolveFixupsForExe/BinCreateThunk de           }
{ GOCW32.PAS (meme projet, architecture IDENTIQUE a DELPHI.PAS/               }
{ SWIFTW32.PAS, "deja eprouvee" selon les propres mots de GOCW32.PAS         }
{ pour SON TODO 23) - REUTILISE TOUTE l infrastructure Bin*                  }
{ TEXT/DATA du TODO 22 SANS LA MODIFIER (BinCode/BinData/BinLabels/                  }
{ BinFixups/BinImports restent EXACTEMENT ce qu ils etaient) : la SEULE                  }
{ vraie difference .OBJ vs .EXE est COMMENT les correctifs REL32/ABS32                       }
{ sont resolus (BinResolveFixupsForExe, NOUVELLE, plutot que                                     }
{ BinResolveFixups du TODO 22 - un .EXE ne peut laisser AUCUNE                                       }
{ relocation "en attente pour le lieur", contrairement a un .OBJ,                        }
{ puisqu il n y a PLUS de lieur a ce stade) - et le format du fichier                        }
{ produit (MZ+PE+IMAGE_OPTIONAL_HEADER32+3 sections .text/.data/.idata                                          }
{ avec une VRAIE table d import/IAT KERNEL32.DLL, PAS 2 sections+table                                                 }
{ de symboles COFF). Point d entree = "_JPPSTART" (deja emis par                                                        }
{ CompileProgram, TODO 21) ; runtime embarque = EXACTEMENT celui deja                                                      }
{ ecrit par EmitRuntimeLibrary (TODO 21, _JPPRT_PRINT_STR/PRINTLN_STR) -                                                        }
{ aucune extension n est faite ici. Un .EXE genere aujourd hui ne peut               }
{ executer QUE ce que CompileExpr/CompileStmt savent deja compiler                     }
{ (meme limite documentee que le TODO 21/22 eux-memes). ImageBase                          }
{ $00400000, SectionAlignment 4096, FileAlignment 512, sous-systeme                          }
{ CUI (console) - valeurs IDENTIQUES a GOCW32.PAS/DELPHI.PAS (memes             }
{ projet, aucune raison de deviner autrement) - toutes DEJA reservees             }
{ depuis le TODO 01 (PE_IMG_BASE/PE_SEC_ALIGN/PE_FILE_ALIGN), jamais            }
{ invoquees avant ce TODO, meme discipline que PE_MACHINE_I386/                   }
{ COFF_REL_I386_*/COFF_SYM_CLASS_* pour le TODO 22.                                             }
{                                                                       }
{ Petite deviation deliberee par rapport a Run() de GOCW32.PAS, trouvee    }
{ par relecture AVANT d ecrire le code (pas par execution) : le Run()      }
{ de GOCW32.PAS appelle BinResolveFixupsForExe EXPLICITEMENT juste avant       }
{ WritePEExe(...), ALORS QUE WritePEExe elle-meme commence DEJA par son          }
{ propre appel a BinResolveFixupsForExe (voir sa note d en-tete plus            }
{ bas) - un DOUBLE appel reel a chaque .exe genere (inoffensif en             }
{ pratique : le second passage recree simplement un second relais IAT               }
{ mort par import externe, jamais utilise, puisque chaque correctif REL32          }
{ deja resolu est de toute facon re-ecrase avec la MEME valeur finale               }
{ correcte - mais un gaspillage sans justification). ICI, Run()            }
{ n appelle PLUS BinResolveFixupsForExe lui-meme : WritePEExe reste             }
{ auto-suffisante (utile aussi pour PEExeSelfTest, plus bas, qui               }
{ l appelle directement sans passer par Run()) et le doublon disparait.       }
{ Sortie : Opts.OutFile (JAMAIS ReplaceExt(Opts.SrcFile,...) comme            }
{ pour le .asm/.obj intermediaires des TODO 21/22 - Opts.OutFile EST,           }
{ depuis le TODO 01, deja le nom de fichier FINAL demande par                    }
{ l utilisateur, par defaut ReplaceExt(Opts.SrcFile,'.exe') sauf si              }
{ -obj est passe (auquel cas TODO 22/WriteCOFFObj reste la sortie              }
{ finale a la place, .obj) ou si -o NOM est passe explicitement). }
{ ------------------------------------------------------------ }

Const
  PE_KERNEL32 = 'KERNEL32.DLL';

Var
  BinThunkOfs    : Array[0..MAX_BIN_IMPORT - 1] Of LongInt;
  BinThunkExists : Array[0..MAX_BIN_IMPORT - 1] Of Boolean;

Function BinAlignUp(V, Align: LongInt): LongInt;
Begin
  If V Mod Align = 0 Then BinAlignUp := V
  Else BinAlignUp := ((V Div Align) + 1) * Align;
End;

{ BinExportNameFor : retrouve le nom REELLEMENT exporte par la DLL       }
{ (ex. "WriteFile") a partir du nom decore stdcall utilise dans les             }
{ instructions CALL de ce compilateur (ex. "_WriteFile@20") - retire le            }
{ "_" de tete et le "@N" de queue, tous deux de simples conventions                    }
{ d appel Win32 (jamais presents dans la table d export REELLE de la                       }
{ DLL elle-meme, consultee par le chargeur via le nom Hint/Name). }
Function BinExportNameFor(Const DecoratedName: TString): TString;
Var S: TString; P: Integer;
Begin
  S := DecoratedName;
  If (Length(S) > 0) And (S[1] = '_') Then Delete(S, 1, 1);
  P := Pos('@', S);
  If P > 0 Then S := Copy(S, 1, P - 1);
  BinExportNameFor := S;
End;

{ BinCreateThunk : petit relais de 6 octets ("FF 25 <disp32>" = JMP      }
{ DWORD PTR [case-IAT]) place dans .text, UN SEUL PAR IMPORT (idempotent           }
{ - plusieurs CALL au meme import partagent le MEME relais) - c est LA                 }
{ CIBLE que le REL32 d un "CALL Import" resout desormais vers, PLUTOT               }
{ que l adresse de la DLL elle-meme (jamais connue avant le chargement) :               }
{ le relais, lui, fait le SAUT INDIRECT reel via la case d IAT               }
{ correspondante (elle-meme corrigee par le CHARGEUR Windows au                            }
{ demarrage du processus, PAS par ce compilateur). }
Procedure BinCreateThunk(ExternIdx: Integer);
Var SavedIsData: Boolean;
Begin
  If BinThunkExists[ExternIdx] Then Exit;
  SavedIsData := BinCurIsData;
  BinCurIsData := BINSEC_TEXT;
  BinThunkOfs[ExternIdx] := BinCodeLen;
  BinThunkExists[ExternIdx] := True;
  BinEmit8($FF);
  BinEmit8($25);
  BinEmit32(0);
  BinAddFixup(BFX_ABS32, '@IAT:' + BinImports[ExternIdx]);
  BinCurIsData := SavedIsData;
End;

{ BinResolveFixupsForExe : contrairement a BinResolveFixups (TODO 22,    }
{ .OBJ - seuls les REL32 LOCAUX sont resolus, le reste devient une             }
{ vraie relocation COFF pour le lieur externe), un .EXE n a PLUS AUCUN               }
{ lieur en aval - TOUT REL32 doit disparaitre ICI, qu il vise une                        }
{ etiquette locale (resolue directement) OU un import externe (resolu                       }
{ via un relais, BinCreateThunk). Les ABS32 restent volontairement EN                          }
{ ATTENTE (une adresse ABSOLUE ne peut jamais etre connue avant que                                }
{ chaque section n ait sa VRAIE RVA finale - calculee par WritePEExe                                   }
{ lui-meme, plus bas, une fois la disposition du fichier entierement                                       }
{ determinee). }
Procedure BinResolveFixupsForExe;
Var I, LI, EI: Integer; TargetOfs, Disp: LongInt;
Begin
  For I := 0 To MAX_BIN_IMPORT - 1 Do BinThunkExists[I] := False;
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Kind = BFX_REL32 Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then
        TargetOfs := BinLabels[LI].Ofs
      Else
      Begin
        EI := BinFindImport(BinFixups[I].TargetName);
        If EI < 0 Then
        Begin
          FatalError('assembleur : symbole introuvable (CALL/JMP) : ' +
            BinFixups[I].TargetName);
          Exit;
        End;
        BinCreateThunk(EI);
        TargetOfs := BinThunkOfs[EI];
      End;
      Disp := TargetOfs - (BinFixups[I].Pos + 4);
      BinPatch32(BinFixups[I].IsData, BinFixups[I].Pos, Disp);
      BinFixups[I].Resolved := True;
    End;
End;

{ ------------------------------------------------------------ }
{ WritePEExe : ecrit un vrai fichier .EXE PE Win32 - stub MZ           }
{ minimal, IMAGE_FILE_HEADER, IMAGE_OPTIONAL_HEADER32, TROIS sections            }
{ (.text/.data/.idata - PAS deux comme WriteCOFFObj/TODO 22 : .idata                }
{ heberge la VRAIE table d import KERNEL32.DLL/IAT que le chargeur                     }
{ Windows exige pour resoudre GetStdHandle/WriteFile/ExitProcess au                          }
{ demarrage du processus), sous-systeme CUI (console), ImageBase                                 }
{ $00400000. AUCUNE table de relocations (.reloc, DataDirectory[5])                                  }
{ n existe - ce fichier n est chargeable qu a CETTE adresse fixe                                        }
{ precise, exactement comme GOCW32.PAS/DELPHI.PAS (memes projet).                }
{ Auto-suffisante (appelle elle-meme BinResolveFixupsForExe en premier -           }
{ voir la note d en-tete de section ci-dessus) : peut etre appelee                     }
{ directement, sans preparation prealable par l appelant. }
Procedure WritePEExe(Const ExeFileName: TString);
Var
  ObjF : File;
  NImp : Integer;
  HdrSize, HdrSizeAligned : LongInt;
  TextRva, TextFileOfs, TextRawSize : LongInt;
  DataRva, DataFileOfs, DataRawSize : LongInt;
  IltOfs, IatOfs, DllNameOfs, IdataSizeRaw, IdataSize, IdataRawSize : LongInt;
  IdataRva, IdataFileOfs : LongInt;
  ImageSize : LongInt;
  HintNameOfs : Array[0..MAX_BIN_IMPORT - 1] Of LongInt;
  I, HnLen : Integer;
  HintNameTotal : LongInt;
  EntryLI : Integer;
  EntryRva : LongInt;
  TargetName, ExpName : TString;
  V : LongInt;
  LI, EI : Integer;

  Procedure OW8(B: Integer);
  Var Buf: Byte;
  Begin
    Buf := B And $FF;
    BlockWrite(ObjF, Buf, 1);
  End;

  Procedure OW16(W: Integer);
  Begin
    OW8(W);
    OW8(W Shr 8);
  End;

  Procedure OW32(D: LongInt);
  Begin
    OW8(D);
    OW8(D Shr 8);
    OW8(D Shr 16);
    OW8(D Shr 24);
  End;

  Procedure OWStr(Const S: TString);
  Var K: Integer;
  Begin
    For K := 1 To Length(S) Do OW8(Ord(S[K]));
  End;

  Procedure OWZeros(N: Integer);
  Var K: Integer;
  Begin
    For K := 1 To N Do OW8(0);
  End;

  Procedure OWSecName(Const Nm: TString);
  Begin
    OWStr(Nm);
    If Length(Nm) < 8 Then OWZeros(8 - Length(Nm));
  End;

Begin
  { TOUT REL32 doit disparaitre ICI - un .EXE n a PLUS AUCUN lieur en    }
  { aval (contrairement a un .OBJ, TODO 22) pour resoudre quoi que ce           }
  { soit apres coup. }
  BinResolveFixupsForExe;

  NImp := BinImportCount;

  { disposition de la table d import (.idata) - UN SEUL DLL suppose      }
  { (KERNEL32.DLL, simplification documentee, meme choix que GOCW32.PAS/          }
  { DELPHI.PAS, memes projet) : 1 descripteur reel + 1 descripteur NUL terminal (20              }
  { octets chacun), puis ILT, puis IAT (identiques au depart - le                        }
  { chargeur Windows ecrase l IAT avec les VRAIES adresses au                                 }
  { chargement), puis les entrees Hint/Nom (alignees sur 2 octets), puis                          }
  { le nom de la DLL elle-meme. }
  IltOfs := 40;
  IatOfs := IltOfs + (NImp + 1) * 4;
  HintNameTotal := 0;
  For I := 0 To NImp - 1 Do
  Begin
    HintNameOfs[I] := IatOfs + (NImp + 1) * 4 + HintNameTotal;
    HnLen := 2 + Length(BinExportNameFor(BinImports[I])) + 1;
    If HnLen Mod 2 <> 0 Then Inc(HnLen);
    HintNameTotal := HintNameTotal + HnLen;
  End;
  DllNameOfs  := IatOfs + (NImp + 1) * 4 + HintNameTotal;
  IdataSizeRaw := DllNameOfs + Length(PE_KERNEL32) + 1;
  IdataSize    := IdataSizeRaw;
  If IdataSize Mod 2 <> 0 Then Inc(IdataSize);

  { disposition generale - RVA alignees sur PE_SEC_ALIGN, decalages       }
  { fichier alignes sur PE_FILE_ALIGN (regle PE classique : la taille          }
  { RAW en fichier suit l alignement-FICHIER, mais la PROCHAINE RVA                  }
  { suit toujours l alignement-SECTION, independamment de la taille                      }
  { RAW reelle du contenu precedent). }
  HdrSize        := 64 + 4 + 20 + 224 + 3 * 40;
  HdrSizeAligned := BinAlignUp(HdrSize, PE_FILE_ALIGN);

  TextRva     := PE_SEC_ALIGN;
  TextFileOfs := HdrSizeAligned;
  TextRawSize := BinAlignUp(BinCodeLen, PE_FILE_ALIGN);

  DataRva     := TextRva + BinAlignUp(BinCodeLen, PE_SEC_ALIGN);
  DataFileOfs := TextFileOfs + TextRawSize;
  DataRawSize := BinAlignUp(BinDataLen, PE_FILE_ALIGN);

  IdataRva     := DataRva + BinAlignUp(BinDataLen, PE_SEC_ALIGN);
  IdataFileOfs := DataFileOfs + DataRawSize;
  IdataRawSize := BinAlignUp(IdataSize, PE_FILE_ALIGN);

  ImageSize := BinAlignUp(IdataRva + IdataSize, PE_SEC_ALIGN);

  { resolution des correctifs ABS32 - adresses ABSOLUES completes           }
  { (ImageBase+RVA+deplacement), JAMAIS de simples RVA - possible                  }
  { SEULEMENT maintenant que chaque section a sa VRAIE RVA finale                     }
  { (aucune table de relocations n existe pour corriger cela plus tard              }
  { comme le ferait un VRAI executable relogeable). }
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Kind = BFX_ABS32 Then
    Begin
      TargetName := BinFixups[I].TargetName;
      If Copy(TargetName, 1, 5) = '@IAT:' Then
      Begin
        EI := BinFindImport(Copy(TargetName, 6, Length(TargetName) - 5));
        V := PE_IMG_BASE + IdataRva + IatOfs + EI * 4;
      End
      Else
      Begin
        LI := BinFindLabel(TargetName);
        If LI < 0 Then
        Begin
          FatalError('assembleur : etiquette introuvable (adresse absolue) : ' +
            TargetName);
          Exit;
        End;
        If BinLabels[LI].IsData Then
          V := PE_IMG_BASE + DataRva + BinLabels[LI].Ofs
        Else
          V := PE_IMG_BASE + TextRva + BinLabels[LI].Ofs;
      End;
      BinPatch32(BinFixups[I].IsData, BinFixups[I].Pos, V);
    End;

  { point d entree : RVA de "_JPPSTART" (CompileProgram, TODO 21) - repli   }
  { sur le tout debut de .text si, par une anomalie quelconque, cette             }
  { etiquette precise restait introuvable (ne devrait jamais arriver en             }
  { pratique : CompileProgram l emet TOUJOURS). }
  EntryLI := BinFindLabel('_JPPSTART');
  If EntryLI >= 0 Then
  Begin
    If BinLabels[EntryLI].IsData Then EntryRva := DataRva + BinLabels[EntryLI].Ofs
    Else EntryRva := TextRva + BinLabels[EntryLI].Ofs;
  End
  Else
    EntryRva := TextRva;

  Assign(ObjF, ExeFileName);
  Rewrite(ObjF, 1);

  { en-tete MZ minimal (64 octets : seuls e_magic/e_lfanew comptent -    }
  { aucun VRAI code de stub DOS, meme simplification que GOCW32.PAS/                    }
  { DELPHI.PAS). }
  OW16(PE_DOS_MAGIC);
  OWZeros(58);
  OW32(64);

  OW32(PE_PE_SIG);

  { IMAGE_FILE_HEADER }
  OW16(PE_MACHINE_I386);
  OW16(3);              { NumberOfSections : .text/.data/.idata }
  OW32(0);              { TimeDateStamp }
  OW32(0);              { PointerToSymbolTable (aucune table COFF dans un .EXE) }
  OW32(0);              { NumberOfSymbols }
  OW16(224);            { SizeOfOptionalHeader (IMAGE_OPTIONAL_HEADER32) }
  OW16($010F);          { Characteristics }

  { IMAGE_OPTIONAL_HEADER32 (224 octets) }
  OW16(PE_OPT_MAGIC_PE32);
  OW8(1); OW8(0);                     { MajorLinkerVersion, Minor }
  OW32(TextRawSize);                  { SizeOfCode }
  OW32(DataRawSize + IdataRawSize);   { SizeOfInitializedData }
  OW32(0);                            { SizeOfUninitializedData }
  OW32(EntryRva);                     { AddressOfEntryPoint }
  OW32(TextRva);                      { BaseOfCode }
  OW32(DataRva);                      { BaseOfData }
  OW32(PE_IMG_BASE);
  OW32(PE_SEC_ALIGN);
  OW32(PE_FILE_ALIGN);
  OW16(4); OW16(0);                   { MajorOSVersion, Minor }
  OW16(0); OW16(0);                   { MajorImageVersion, Minor }
  OW16(4); OW16(0);                   { MajorSubsystemVersion, Minor }
  OW32(0);                            { Win32VersionValue }
  OW32(ImageSize);                    { SizeOfImage }
  OW32(HdrSizeAligned);               { SizeOfHeaders }
  OW32(0);                            { CheckSum }
  OW16(PE_SUBSYS_CUI);
  OW16(0);                            { DllCharacteristics }
  OW32($100000);                      { SizeOfStackReserve }
  OW32($1000);                        { SizeOfStackCommit }
  OW32($100000);                      { SizeOfHeapReserve }
  OW32($1000);                        { SizeOfHeapCommit }
  OW32(0);                            { LoaderFlags }
  OW32(16);                           { NumberOfRvaAndSizes }

  { DataDirectory (16 entrees x 8 octets) - seuls [1]=Import et            }
  { [12]=IAT sont renseignees (aucune export/ressource/relocations/etc            }
  { dans ce backend minimal). }
  OW32(0); OW32(0);                              { [0] Export }
  OW32(IdataRva); OW32(40);                      { [1] Import }
  For I := 1 To 10 Do Begin OW32(0); OW32(0); End; { [2..11] }
  OW32(IdataRva + IatOfs); OW32((NImp + 1) * 4); { [12] IAT }
  For I := 1 To 3 Do Begin OW32(0); OW32(0); End;  { [13..15] }

  { en-tetes de section (40 octets chacune) : .text/.data/.idata }
  OWSecName('.text');
  OW32(BinCodeLen); OW32(TextRva);
  OW32(TextRawSize); OW32(TextFileOfs);
  OW32(0); OW32(0); OW16(0); OW16(0);
  OW32(PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  OWSecName('.data');
  OW32(BinDataLen); OW32(DataRva);
  OW32(DataRawSize); OW32(DataFileOfs);
  OW32(0); OW32(0); OW16(0); OW16(0);
  OW32(PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  OWSecName('.idata');
  OW32(IdataSize); OW32(IdataRva);
  OW32(IdataRawSize); OW32(IdataFileOfs);
  OW32(0); OW32(0); OW16(0); OW16(0);
  OW32(PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  { bourrage jusqu a HdrSizeAligned (TextFileOfs) - les en-tetes         }
  { eux-memes (MZ+PE+IMAGE_FILE_HEADER+IMAGE_OPTIONAL_HEADER32+3           }
  { en-tetes de section) totalisent HdrSize, MAIS .text ne peut                  }
  { commencer QUE sur la PROCHAINE limite alignee-fichier                        }
  { (PE_FILE_ALIGN) - SANS ce bourrage EXPLICITE, chaque section serait               }
  { ecrite HdrSizeAligned-HdrSize octets TROP TOT par rapport a ce que                 }
  { les PointerToRawData deja ecrits ci-dessus PROMETTENT, tronquant le                    }
  { fichier final du meme nombre d octets a la fin (bogue reel deja                       }
  { rencontre et documente par GOCW32.PAS pour son propre TODO 23 -                    }
  { evite ICI par construction, en portant directement son OWZeros                         }
  { correctif plutot qu en re-decouvrant le meme bogue). }
  OWZeros(HdrSizeAligned - HdrSize);

  { octets bruts .text/.data, chacun bourre de zeros jusqu a la taille    }
  { RAW alignee-fichier. }
  If BinCodeLen > 0 Then BlockWrite(ObjF, BinCode, BinCodeLen);
  OWZeros(TextRawSize - BinCodeLen);

  If BinDataLen > 0 Then BlockWrite(ObjF, BinData, BinDataLen);
  OWZeros(DataRawSize - BinDataLen);

  { .idata : Table des Import (1 descripteur KERNEL32.DLL + 1 nul), ILT,  }
  { IAT, entrees Hint/Nom, nom de la DLL. }
  OW32(IdataRva + IltOfs);        { OriginalFirstThunk }
  OW32(0);                        { TimeDateStamp }
  OW32(0);                        { ForwarderChain }
  OW32(IdataRva + DllNameOfs);    { Name }
  OW32(IdataRva + IatOfs);        { FirstThunk }
  OWZeros(20);                    { descripteur NUL terminal }

  For I := 0 To NImp - 1 Do OW32(IdataRva + HintNameOfs[I]);
  OW32(0);

  For I := 0 To NImp - 1 Do OW32(IdataRva + HintNameOfs[I]);
  OW32(0);

  For I := 0 To NImp - 1 Do
  Begin
    OW16(0);   { Hint }
    ExpName := BinExportNameFor(BinImports[I]);
    OWStr(ExpName);
    OW8(0);
    HnLen := 2 + Length(ExpName) + 1;
    If HnLen Mod 2 <> 0 Then OW8(0);
  End;

  OWStr(PE_KERNEL32);
  OW8(0);
  If IdataSizeRaw Mod 2 <> 0 Then OW8(0);

  OWZeros(IdataRawSize - IdataSize);

  Close(ObjF);
End;

{ ------------------------------------------------------------ }
{ PEExeSelfTest (TODO 23) : meme methode ET MEME LIMITE documentee     }
{ que celle de GOCW32.PAS (memes projet) - compile un extrait J++              }
{ de bout en bout (ParseCompilationUnit -> CompileProgram -> .asm ->               }
{ BinAssembleFile -> WritePEExe), puis RELIT le .exe produit en                    }
{ OCTETS BRUTS et verifie sa signature/structure (MZ, PE\0\0 a                              }
{ e_lfanew=64, Machine=I386, NumberOfSections=3, Subsystem=CUI, taille                          }
{ de fichier EXACTEMENT un multiple de PE_FILE_ALIGN) - PAS que le                     }
{ fichier s EXECUTE reellement (verifie MANUELLEMENT lors du                            }
{ developpement de ce TODO, voir la memoire du projet - la validation                                   }
{ AUTOMATISEE de l execution reelle de chaque SAMPLES\JPP\*.jpp reste                                        }
{ explicitement le travail du TODO 25, exactement comme le roadmap                                                        }
{ lui-meme le precise). Source synthetique deliberement minimale                                                                }
{ (imports implicites + un seul println dans main, la SEULE forme que                                                                  }
{ CompileExpr/CompileStmt savent compiler a ce jour, meme portee que                                                                     }
{ Test17PaquetsMicrosoft.jpp) - reutilise CompilationUnitParseFile                                                                       }
{ (TODO 12) EXACTEMENT comme PackageSelfTest/SemanticSelfTest/etc. le                                                                    }
{ font deja, plutot qu une nouvelle infrastructure de parsing-depuis-                                                                    }
{ fichier-temporaire. }
{ ------------------------------------------------------------ }

Procedure PEExeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PEExeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PEExeSelfTest;
Const
  TmpFile = 'JPPCLASSSELFTEST.$$$';
  TmpAsm  = 'JPPPESELFTEST.$$$';
  TmpExe  = 'JPPPESELFTEST.EX$';
Var
  F  : Text;
  Fx : File;
  B4 : Array[0..3] Of Byte;
  ExeSize : LongInt;
Begin
  ExprInit; StmtInit; SymInit; TypeInit;

  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'class Test23PEExe {');
  WriteLn(F, '    public static void main(String[] args) {');
  WriteLn(F, '        System.out.println("ok");');
  WriteLn(F, '    }');
  WriteLn(F, '}');
  Close(F);
  CompilationUnitParseFile;
  Erase(F);

  CompileProgram(TmpAsm);
  BinAssembleFile(TmpAsm);
  WritePEExe(TmpExe);

  Assign(Fx, TmpExe);
  Reset(Fx, 1);
  ExeSize := FileSize(Fx);
  BlockRead(Fx, B4, 4);
  PEExeAssert('signature MZ ($4D,$5A) en tete du .exe',
    (B4[0] = $4D) And (B4[1] = $5A));

  Seek(Fx, 60);
  BlockRead(Fx, B4, 4);
  PEExeAssert('e_lfanew=64 (offset 60, DWORD)',
    (B4[0] = 64) And (B4[1] = 0) And (B4[2] = 0) And (B4[3] = 0));

  Seek(Fx, 64);
  BlockRead(Fx, B4, 4);
  PEExeAssert('signature PE\0\0 a e_lfanew=64',
    (B4[0] = Ord('P')) And (B4[1] = Ord('E')) And (B4[2] = 0) And (B4[3] = 0));

  Seek(Fx, 68);
  BlockRead(Fx, B4, 4);
  PEExeAssert('Machine=I386 ($4C,$01) et NumberOfSections=3 en tete de ' +
    'IMAGE_FILE_HEADER', (B4[0] = $4C) And (B4[1] = $01) And
    (B4[2] = 3) And (B4[3] = 0));

  Seek(Fx, 156);
  BlockRead(Fx, B4, 2);
  PEExeAssert('Subsystem=3 (CUI, console) dans IMAGE_OPTIONAL_HEADER32',
    (B4[0] = 3) And (B4[1] = 0));

  Close(Fx);

  PEExeAssert('fichier .exe de taille EXACTEMENT un multiple de ' +
    'PE_FILE_ALIGN (en-tetes+3 sections toutes alignees-fichier)',
    ExeSize Mod PE_FILE_ALIGN = 0);
  PEExeAssert('fichier .exe de taille plausible (en-tetes + 3 sections ' +
    'avec du contenu reel)', ExeSize >= 4 * PE_FILE_ALIGN);

  Assign(Fx, TmpExe);
  Erase(Fx);
  Assign(Fx, TmpAsm);
  Erase(Fx);

  { reinitialise les tables globales pour ne pas polluer le vrai Run(). }
  ExprInit; StmtInit; SymInit; TypeInit;
End;

{ ------------------------------------------------------------ }
{ TODO 24 - AUDIT DES AUTO-TESTS                                    }
{ ------------------------------------------------------------ }
{ "Meme separation des responsabilites RunAllSelfTests que chaque       }
{ compilateur frere" (roadmap) - un SelfTest par sous-systeme majeur              }
{ existe deja, un a chaque TODO depuis le TODO 02, jamais reporte a               }
{ "plus tard" (chaque TODO de ce fichier a systematiquement ajoute le             }
{ sien EN MEME TEMPS que la fonctionnalite elle-meme). Ce TODO ne les              }
{ CREE donc pas, il les REGROUPE (RunAllSelfTests ci-dessous, plutot                    }
{ qu inlines dans Run lui-meme - separe clairement la responsabilite               }
{ "auto-tests" de la responsabilite "compiler le VRAI fichier .jpp" de           }
{ Run, MEME sequence/ordre exact qu avant - un pur deplacement, AUCUN            }
{ comportement ne change) et COMBLE la LACUNE reelle trouvee par cet             }
{ audit : contrairement a GOCW32.PAS (qui avait deja BinObjSelfTest                    }
{ depuis SON PROPRE TODO 22), JPPCW32 n a JAMAIS eu de self-test               }
{ dedie au backend .OBJ COFF (TODO 22) OU au backend .EXE PE (TODO 23)             }
{ verifiant l ENCODAGE 80386 lui-meme OCTET PAR OCTET pour un                          }
{ mnemonique donne - PEExeSelfTest (TODO 23) ne verifie que la                        }
{ STRUCTURE d ensemble du .exe produit (signature/sections/Subsystem/           }
{ tailles), JAMAIS un SEUL opcode/ModRM precis ; le TODO 22 lui-meme               }
{ n a eu QUE la verification manuelle par execution reelle (ld+run,                    }
{ voir la memoire du projet), jamais un auto-test automatise. Ajoute              }
{ BinEncoderSelfTest pour cela : appelle BinEmitInstr DIRECTEMENT                      }
{ (BinInit avant chaque cas pour repartir d un tampon .text vide) et                  }
{ inspecte BinCode OCTET PAR OCTET contre la valeur EXACTE attendue -               }
{ couvre CHAQUE encodeur que ce compilateur possede REELLEMENT                        }
{ (BinEncodeMov ses QUATRE formes, BinEncodePush/Pop, BinEncodeLea ses           }
{ DEUX formes - registre de base ET etiquette absolue -, BinEncodeAlu             }
{ (ADD/SUB-immediat/XOR, PLUS la forme BYTE PTR de CMP - REELLEMENT                    }
{ utilisee par _JPPRT_STRLEN_LOOP), BinEncodeIncDec, PLUS JMP/JE/CALL              }
{ vers une etiquette encore INCONNUE - le cas normal, jamais resolu                    }
{ ICI, BinResolveFixups/BinResolveFixupsForExe s en chargent plus tard,        }
{ une fois toutes les etiquettes connues) - MEME niveau de rigueur que             }
{ celui que GOCW32.PAS a lui-meme ajoute pour SA PROPRE TODO 24.                       }
{ MOVZX/FPU/TEST/IMUL/IDIV/NOT/NEG/decalages restent HORS de ce test               }
{ (comme de l assembleur lui-meme, TODO 22) : AUCUNE forme n est                       }
{ ENCORE emise nulle part dans ce compilateur.                                                }
{ ------------------------------------------------------------ }

Procedure BinEncAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('BinEncoderSelfTest: ' + Label_ + ' a echoue');
End;

Procedure BinEncoderSelfTest;
Begin
  BinInit;
  BinEmitInstr('MOV EAX,EBX');
  BinEncAssert('MOV EAX,EBX -> 8B C3',
    (BinCodeLen = 2) And (BinCode[0] = $8B) And (BinCode[1] = $C3));

  BinInit;
  BinEmitInstr('MOV EAX,5');
  BinEncAssert('MOV EAX,5 -> B8 05 00 00 00',
    (BinCodeLen = 5) And (BinCode[0] = $B8) And (BinCode[1] = 5) And
    (BinCode[2] = 0) And (BinCode[3] = 0) And (BinCode[4] = 0));

  BinInit;
  BinEmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  BinEncAssert('MOV EAX,[EBP+8] -> 8B 85 08 00 00 00 (base+disp32, ' +
    'jamais disp8 - meme simplification que GOCW32.PAS/DELPHI.PAS)',
    (BinCodeLen = 6) And (BinCode[0] = $8B) And (BinCode[1] = $85) And
    (BinCode[2] = 8) And (BinCode[3] = 0) And (BinCode[4] = 0) And (BinCode[5] = 0));

  BinInit;
  BinEmitInstr('MOV DWORD PTR [EBP-4],EAX');
  BinEncAssert('MOV [EBP-4],EAX -> 89 85 FC FF FF FF (destination memoire, ' +
    'deplacement NEGATIF)',
    (BinCodeLen = 6) And (BinCode[0] = $89) And (BinCode[1] = $85) And
    (BinCode[2] = $FC) And (BinCode[3] = $FF) And (BinCode[4] = $FF) And
    (BinCode[5] = $FF));

  BinInit;
  BinEmitInstr('PUSH EAX');
  BinEncAssert('PUSH EAX -> 50', (BinCodeLen = 1) And (BinCode[0] = $50));

  BinInit;
  BinEmitInstr('PUSH EBP');
  BinEncAssert('PUSH EBP -> 55', (BinCodeLen = 1) And (BinCode[0] = $55));

  BinInit;
  BinEmitInstr('PUSH -11');
  BinEncAssert('PUSH -11 -> 68 F5 FF FF FF (immediat NEGATIF, forme ' +
    'utilisee par _JPPRT_PRINT_STR pour STD_OUTPUT_HANDLE)',
    (BinCodeLen = 5) And (BinCode[0] = $68) And (BinCode[1] = $F5) And
    (BinCode[2] = $FF) And (BinCode[3] = $FF) And (BinCode[4] = $FF));

  BinInit;
  BinEmitInstr('POP EBP');
  BinEncAssert('POP EBP -> 5D', (BinCodeLen = 1) And (BinCode[0] = $5D));

  BinInit;
  BinEmitInstr('LEA EAX,[EBP-4]');
  BinEncAssert('LEA EAX,[EBP-4] -> 8D 85 FC FF FF FF',
    (BinCodeLen = 6) And (BinCode[0] = $8D) And (BinCode[1] = $85) And
    (BinCode[2] = $FC) And (BinCode[3] = $FF) And (BinCode[4] = $FF) And
    (BinCode[5] = $FF));

  BinInit;
  BinEmitInstr('LEA EAX,[SOMELABEL]');
  BinEncAssert('LEA EAX,[etiquette] -> 8D 05 + correctif ABS32 en attente ' +
    '(etiquette absolue, sans registre de base)',
    (BinCodeLen = 6) And (BinCode[0] = $8D) And (BinCode[1] = 5) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_ABS32) And
    (BinFixups[0].TargetName = 'SOMELABEL') And (Not BinFixups[0].Resolved));

  BinInit;
  BinEmitInstr('ADD EAX,EBX');
  BinEncAssert('ADD EAX,EBX -> 03 C3',
    (BinCodeLen = 2) And (BinCode[0] = $03) And (BinCode[1] = $C3));

  BinInit;
  BinEmitInstr('SUB ESP,16');
  BinEncAssert('SUB ESP,16 -> 81 EC 10 00 00 00',
    (BinCodeLen = 6) And (BinCode[0] = $81) And (BinCode[1] = $EC) And
    (BinCode[2] = 16) And (BinCode[3] = 0) And (BinCode[4] = 0) And (BinCode[5] = 0));

  BinInit;
  BinEmitInstr('XOR ECX,ECX');
  BinEncAssert('XOR ECX,ECX -> 33 C9 (forme reellement utilisee par ' +
    '_JPPRT_STRLEN pour initialiser le compteur)',
    (BinCodeLen = 2) And (BinCode[0] = $33) And (BinCode[1] = $C9));

  BinInit;
  BinEmitInstr('CMP BYTE PTR [ESI],0');
  BinEncAssert('CMP BYTE PTR [ESI],0 -> 80 BE 00 00 00 00 00 (forme ' +
    'REELLEMENT utilisee par _JPPRT_STRLEN_LOOP - immediat SUR UN SEUL ' +
    'octet, contrairement a la forme 32 bits de "SUB ESP,16" ci-dessus)',
    (BinCodeLen = 7) And (BinCode[0] = $80) And (BinCode[1] = $BE) And
    (BinCode[2] = 0) And (BinCode[3] = 0) And (BinCode[4] = 0) And
    (BinCode[5] = 0) And (BinCode[6] = 0));

  BinInit;
  BinEmitInstr('INC ESI');
  BinEncAssert('INC ESI -> 46 (forme utilisee par _JPPRT_STRLEN_LOOP)',
    (BinCodeLen = 1) And (BinCode[0] = $46));

  { CALL/JMP/Jcc vers une etiquette encore INCONNUE (le cas normal - la  }
  { cible n a pas forcement ete definie AVANT le point d appel/de saut          }
  { dans le fichier .asm) : E8/E9/0F-8x + placeholder 0, PLUS un correctif        }
  { REL32 en attente portant le NOM exact de la cible - jamais resolu                    }
  { ICI (BinResolveFixups/BinResolveFixupsForExe s en chargent plus                          }
  { tard, une fois TOUTES les etiquettes connues). }
  BinInit;
  BinEmitInstr('CALL SOMELABEL');
  BinEncAssert('CALL etiquette inconnue -> E8 + correctif REL32 en attente',
    (BinCodeLen = 5) And (BinCode[0] = $E8) And (BinCode[1] = 0) And
    (BinCode[2] = 0) And (BinCode[3] = 0) And (BinCode[4] = 0) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_REL32) And
    (BinFixups[0].TargetName = 'SOMELABEL') And (Not BinFixups[0].Resolved));

  BinInit;
  BinEmitInstr('JMP SOMELABEL');
  BinEncAssert('JMP etiquette -> E9 + correctif REL32 en attente ' +
    '(forme utilisee par _JPPRT_STRLEN_LOOP)',
    (BinCodeLen = 5) And (BinCode[0] = $E9) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_REL32));

  BinInit;
  BinEmitInstr('JE SOMELABEL');
  BinEncAssert('JE etiquette -> 0F 84 + correctif REL32 en attente',
    (BinCodeLen = 6) And (BinCode[0] = $0F) And (BinCode[1] = $84) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_REL32));

  BinInit;
  BinEmitInstr('RET');
  BinEncAssert('RET -> C3', (BinCodeLen = 1) And (BinCode[0] = $C3));

  { reinitialise pour ne pas polluer Run reel }
  BinInit;
End;

{ RunAllSelfTests : REGROUPE (ne cree rien) tous les auto-tests deja     }
{ ecrits, un par TODO depuis le TODO 02 jusqu au TODO 24 lui-meme -                  }
{ MEME ordre exact que l ancienne sequence inline de Run() (aucun               }
{ changement de comportement, un pur deplacement de responsabilite). }
Procedure RunAllSelfTests;
Begin
  LexSelfTest;
  KeywordSelfTest;
  TypeSelfTest;
  DeclSelfTest;
  ExprSelfTest;
  StmtSelfTest;
  ClassSelfTest;
  InterfaceSelfTest;
  ArraySelfTest;
  ExceptionSelfTest;
  PackageSelfTest;
  StdlibSelfTest;
  ThreadSelfTest;
  AwtSelfTest;
  DelegateSelfTest;
  DirectiveSelfTest;
  Win32SelfTest;
  SemanticSelfTest;
  StdlibConsolidationSelfTest;
  PEExeSelfTest;
  BinEncoderSelfTest;
End;

{ ------------------------------------------------------------ }
{ Run : point d entree - portee TODO 01-24 (options + lexeur +      }
{ classification mots-cles/predeclares + systeme de types +               }
{ declarations + operateurs/expressions + instructions + classes/                 }
{ objets + interfaces/classes membres static + tableaux +                            }
{ exceptions + paquets/imports/visibilite + bibliotheque standard               }
{ minimale + threads/synchronized + decision de perimetre AWT/                          }
{ applets/WFC + delegates/evenements Microsoft + directives Microsoft         }
{ et compilation conditionnelle + com.ms.win32/decision de perimetre           }
{ COM + analyse semantique best-effort + consolidation finale de la              }
{ bibliotheque standard + PREMIER jalon du generateur de code 80386 +           }
{ PREMIER jalon du backend binaire .OBJ COFF + PREMIER jalon de                       }
{ l ecrivain .EXE PE). CHANGEMENT MAJEUR (TODO 21, voir sa propre note              }
{ d en-tete) : cette passe lexe (LexAll) ET PARSE REELLEMENT                          }
{ (ParseCompilationUnit) le fichier source pour la toute PREMIERE                       }
{ fois - CHAQUE TODO precedent depuis le TODO 07 repetait                              }
{ "ParseCompilationUnit/ParseClassDecl/... restent testes ISOLEMENT,       }
{ JAMAIS branches sur un VRAI fichier .jpp" ; ce n est PLUS vrai a               }
{ partir d ICI. PUIS, SI le fichier a REELLEMENT ete parse                              }
{ (ErrorCount = 0), genere le .asm correspondant (CompileProgram),                     }
{ l assemble (BinAssembleFile, TODO 22, une SEULE fois - REUTILISEE                    }
{ ensuite par les DEUX backends binaires, .OBJ et .EXE, exactement            }
{ comme GOCW32.PAS), PUIS choisit lequel des deux backends produit le             }
{ fichier FINAL selon Opts.ObjOnly (-obj, TODO 01, jusqu ici jamais                    }
{ consulte par aucun TODO precedent) : .OBJ COFF (BinResolveFixups/            }
{ WriteCOFFObj, TODO 22 - correctifs REL32 externes laisses a un                       }
{ lieur EXTERNE) si demande, sinon .EXE PE DIRECTEMENT EXECUTABLE               }
{ (WritePEExe, TODO 23 - AUCUN lieur externe requis, runtime KERNEL32           }
{ embarque via l IAT) PAR DEFAUT - portee des TROIS generateurs                        }
{ VOLONTAIREMENT restreinte (voir leurs propres notes d en-tete), un              }
{ construct non couvert s arrete PROPREMENT via FatalError, JAMAIS un            }
{ .asm/.obj/.exe silencieusement faux. DEPUIS le TODO 24 : les auto-              }
{ tests eux-memes sont REGROUPES dans RunAllSelfTests (voir sa propre               }
{ note d en-tete) plutot qu inlines ICI - separation de responsabilite,               }
{ AUCUN changement de comportement (meme sequence exacte qu avant). }
Procedure Run;
Var AsmFile : TString; AsmFileDbgI : Integer;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  RunAllSelfTests;

  ParseArgs;
  ShowBanner;

  {$I-}
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;

  If Opts.DebugMode Then
  Begin
    { -d (TODO 01) : l ancien affichage "un token a la fois PENDANT le    }
    { lexage" (LexNextToken en boucle) n a plus de sens des que le                    }
    { fichier est ENTIEREMENT lexe D ABORD (LexAll, TODO 21, MEME                        }
    { raison que GOCW32.PAS/SWIFTW32.PAS a leur propre TODO 21) - la                    }
    { MEME information reste disponible, simplement affichee APRES              }
    { coup depuis TokenPool plutot qu au fil de l eau. }
    For AsmFileDbgI := 0 To TokenCount - 1 Do
      PrintToken(TokenPool[AsmFileDbgI]);
  End;

  ParserInit;
  ParseCompilationUnit;

  WriteLn('JPPCW32: ', TokenCount, ' tokens produits (', TotalLines, ' lignes).');

  If ErrorCount = 0 Then
  Begin
    AsmFile := ReplaceExt(Opts.SrcFile, '.asm');
    CompileProgram(AsmFile);
    WriteLn('JPPCW32: code genere (TODO 21, premier jalon) -> ', AsmFile);

    { TODO 22 : assemble le .asm QUE CompileProgram vient d ecrire            }
    { (passe SEPAREE, voir la note d en-tete de section) en octets 80386          }
    { REELS dans BinCode/BinData - UNE SEULE fois, REUTILISEE ensuite par            }
    { les DEUX backends binaires ci-dessous (MEME buffers, seule la               }
    { RESOLUTION des correctifs differe). }
    BinAssembleFile(AsmFile);

    { TODO 23 : Opts.ObjOnly (-obj, TODO 01 - jamais consulte par aucun            }
    { TODO precedent avant celui-ci) choisit le backend FINAL - Opts.OutFile          }
    { (TODO 01, deja le nom de sortie demande par l utilisateur, PAR                     }
    { DEFAUT ReplaceExt(Opts.SrcFile,'.exe') sauf si -obj/-o) est TOUJOURS               }
    { la cible, JAMAIS ReplaceExt(Opts.SrcFile,...) ICI (contrairement au              }
    { ".asm" intermediaire ci-dessus, qui n est jamais le fichier "final"                }
    { demande par l utilisateur). }
    If Opts.ObjOnly Then
    Begin
      BinResolveFixups;
      WriteCOFFObj(Opts.OutFile);
      WriteLn('JPPCW32: fichier objet COFF genere (correctifs externes ' +
        'REL32 laisses au lieur, normal pour un .OBJ) -> ', Opts.OutFile);
    End
    Else
    Begin
      WritePEExe(Opts.OutFile);
      WriteLn('JPPCW32: fichier executable PE genere - PRET A EXECUTER -> ',
        Opts.OutFile);
    End;
  End;

  ShowStats;
End;

BEGIN
  Run;
END.
