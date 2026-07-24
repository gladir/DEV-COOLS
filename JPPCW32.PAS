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
            import de type unique et import a la demande (.*)
              (12.8-12.9) - PORTEE : un SEUL fichier .jpp par
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
              jpp/Test18JDirect.jpp (imports com.ms.*)

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
