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
  MAX_LOCAL         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LABEL         = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR           = 255;
  MAX_ERRORS        = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_CLASS         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_INTERFACE     = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
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
  CurToken.Kind    := TOK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.RealVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  LexNextLine;
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
      LexNextLine;
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

    { '#if'/'#else'/'#elif'/'#endif' : voir la note d en-tete - une   }
    { VRAIE directive Microsoft (TODO 17), pas un token de ce lexeur.   }
    { BOGUE REEL trouve par EXECUTION (Test15Conditionnelle.jpp) : une   }
    { premiere version de cette garde exigeait LexColNo=1 (esperant       }
    { detecter "'#' est le PREMIER caractere de la ligne") - toujours       }
    { FAUSSE en pratique, puisque CHAQUE directive de l echantillon           }
    { reel est INDENTEE (l espace en tete est deja consomme par le              }
    { Continue juste au-dessus AVANT d atteindre ce test, LexColNo n est          }
    { alors JAMAIS egal a 1) : '#' tombait donc silencieusement dans le            }
    { dernier "Else" generique de LexScanOperator (un caractere ASCII               }
    { imprimable ordinaire), au lieu de s arreter PROPREMENT ici comme               }
    { documente. AUCUNE colonne particuliere n est en realite necessaire :           }
    { '#' n apparait JAMAIS ailleurs dans du code Java/J++ REEL (aucun               }
    { operateur ne l utilise), le simple fait de l atteindre ICI (apres              }
    { que tout espace/tabulation en tete de ligne soit deja saute par le              }
    { Continue ci-dessus) suffit donc a elle seule. }
    If Ch = '#' Then
      FatalError('directive de compilation conditionnelle Microsoft ' +
        '"#..." non couverte pour cette premiere passe (TODO 17, voir ' +
        'l''en-tete du fichier - non encore ecrit)');

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

{ ------------------------------------------------------------ }
{ Run : point d entree - portee TODO 01-02 (options + lexeur       }
{ SEULEMENT). Aucun analyseur/generateur de code n existe encore     }
{ (TODO 03+) : cette passe ouvre reellement le fichier source,        }
{ produit TOUS ses tokens (afficher chaque token si -d) puis           }
{ s arrete PROPREMENT - MEME etat exact ("seulement tokeniser") que      }
{ GOCW32.PAS/SWIFTW32.PAS au sortir de leur propre TODO 02, avant          }
{ qu aucun analyseur syntaxique ne soit ecrit. }
Procedure Run;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;

  LexSelfTest;

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

  Repeat
    LexNextToken;
    PrintToken(CurToken);
  Until CurToken.Kind = TOK_EOF;

  LexClose;

  WriteLn('JPPCW32: ', TokenCount, ' tokens produits (', TotalLines,
    ' lignes) - seulement tokenise pour l''instant (TODO 03+).');
  ShowStats;
End;

BEGIN
  Run;
END.
