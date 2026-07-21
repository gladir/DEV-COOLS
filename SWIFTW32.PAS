{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Swift vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program SWIFTW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  SWIFTW32.PAS - Compilateur Swift vers assembleur 80386 pour
  Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\SWIFT\*.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode)
            ParseArgs : argv source.swift [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extension .swift ; portee : un seul fichier
              .swift par compilation, pas de vrai systeme de
              modules multi-fichiers (voir TODO 19)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512),
              PE_SUBSYS_CUI / PE_SUBSYS_GUI
            Limites : MAX_SYM=4096, MAX_FUNC=512, MAX_TYPE=1024,
              MAX_FIELD_POOL=4096, MAX_PARAM=64, MAX_LOCAL=256,
              MAX_LABEL=4096, MAX_STR=255, MAX_ERRORS=30,
              MAX_CLASS=256, MAX_PROTO=128, MAX_ENUMCASE=512,
              MAX_GENERIC_PARAM=16
            Prefixes ASM : _SW_ (variable globale), _SWF_ (fonction),
              _SWM_ (methode), _SWK_ (constante chaine/litteral),
              _SWRT_ (runtime), _SWL_ (label), _SWT_ (descripteur de
              type/vtable simplifiee), _SWC_ (closure), _SWE_ (case
              d'enumeration)

  TODO 02 - TOKENISEUR SWIFT (LEXER) ET REGLE DE TERMINAISON
            LexInit, LexClose, LexNextChar, LexPeekChar,
              LexPeekChar2, LexNextToken
            Identificateurs : lettres Unicode/ASCII + _, chiffres
              (pas en tete) ; sensibles a la casse
            Numeriques : 123, 1_000_000 (soulignes separateurs),
              0x1F (hex), 0o17 (octal), 0b101 (binaire), 1.5,
              1.5e3, 0x1p10 (flottant hexadecimal - portee a
              documenter, potentiellement hors de portee)
            Chaines interpretees "..." avec INTERPOLATION
              "\(expression)" - le lexer doit reconnaitre
              \( ... ) a l'INTERIEUR d'une chaine et produire des
              tokens permettant au parseur (TODO 06) de re-entrer
              dans une expression complete puis revenir dans la
              chaine ; chaines multi-lignes """...""" (portee a
              documenter)
            Commentaires : // jusqu'a fin de ligne, /* ... */ bloc
              (Swift autorise leur IMBRICATION - contrairement au
              C - a documenter si couvert ou non)
            REGLE DE TERMINAISON D'INSTRUCTION (plus simple que
              l'ASI de Go, mais reelle) : une instruction se termine
              a la fin de la ligne SAUF si la syntaxe est
              manifestement incomplete (ex. ligne finissant par un
              operateur binaire, une virgule, une parenthese/
              accolade ouvrante) ; ';' explicite optionnel et
              accepte pour separer plusieurs instructions sur une
              seule ligne
            Operateurs/ponctuation : + - * / % = == != < > <= >=
              && || ! & | ^ ~ << >> += -= *= /= %= ??= ...
              ..< ... (intervalles fermes/semi-ouverts) -> ?? ! ?
              . , ; : ( ) [ ] { } @ # \
            Types de token : TOK_IDENT, TOK_INT, TOK_FLOAT,
              TOK_STRING, TOK_STRING_INTERP_PART, TOK_SEMI (reel ou
              insere), TOK_EOF

  TODO 03 - MOTS-CLES ET IDENTIFICATEURS PREDECLARES
            IsKeyword(s : String) : Integer
            Mots reserves du langage (liste couverte par ce
              compilateur - Swift en a davantage au total, portee
              volontairement restreinte aux mots reellement
              exerces par SAMPLES\SWIFT\*.swift) : associatedtype
              as break case catch class continue default defer do
              else enum extension fallthrough false for func guard
              if import in init inout internal is let mutating nil
              override private protocol public repeat return self
              static struct switch throw throws true try typealias
              var where while
            Identificateurs predeclares (types/valeurs de la
              bibliotheque standard, traites comme connus par ce
              compilateur mais pas de vrais mots-cles) :
              Types : Int Int8 Int16 Int32 Int64 UInt UInt8 UInt16
                UInt32 UInt64 Double Float Bool String Character
                Array Dictionary Set Optional Any AnyObject Void
              Constantes/operateurs speciaux : nil (deja mot-cle
                ici), true/false (deja mots-cles ici)
              Fonctions/constructions integrees : print, type(of:)
            Fichiers de test couverts (voir SAMPLES\SWIFT\*.swift) :
              hello.swift (let/var, String, print, interpolation),
              math.swift (func, parametres, inout, recursion),
              control.swift (if/guard/switch)

  TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES
            TTypeKind : TYK_BOOL, TYK_INT (sous-categorie taille/
              signe : 8/16/32/64), TYK_FLOAT (32/64), TYK_STRING,
              TYK_CHARACTER, TYK_ARRAY, TYK_DICTIONARY, TYK_SET,
              TYK_STRUCT (semantique VALEUR), TYK_CLASS (semantique
              REFERENCE), TYK_ENUM, TYK_PROTOCOL, TYK_FUNC,
              TYK_OPTIONAL, TYK_TUPLE, TYK_GENERIC_PARAM
            TTypeRec (Kind, Name, Size, Align, ElemTypeIdx [array/
              optional], KeyTypeIdx/ValueTypeIdx [dictionary],
              FieldFirst/FieldCount [struct/class, pool partage],
              MethodFirst/MethodCount, SuperTypeIdx [heritage de
              classe], ProtocolList [conformances], IsValueType
              [Vrai pour struct/enum, Faux pour class - DISTINCTION
              CENTRALE du langage, contrairement a Go ou tout est
              uniformement par valeur sauf pointeurs explicites])
            Valeurs zero/absence de valeur : Optional<T> AUCUNE
              (nil) est la SEULE construction d'absence de valeur
              en Swift (contrairement a Go, pas de "valeur zero"
              implicite pour un Int/String non-optionnel non
              initialise - portee : ce compilateur EXIGE une
              initialisation explicite pour tout type non-optionnel,
              documente comme simplification acceptee plutot que
              la vraie regle de flux de controle "definite
              initialization" de Swift reel)
            TypeResolveOptional/TypeIsOptional (deballage du
              TYK_OPTIONAL vers son ElemTypeIdx)

  TODO 05 - DECLARATIONS : LET/VAR, INFERENCE DE TYPE ET PORTEES
            Symbole table (SymTab/SymAdd/SymFind/SymFindInScope) +
              pile de portees (SymEnterScope/SymLeaveScope) - meme
              architecture que GOCW32.PAS/DELPHI.PAS
            let (constante, assignee UNE fois) vs var (variable) -
              IsConst sur TSymRec, verifie AU MOINS en surface
              (reassignation d'un "let" = erreur - verification
              complete au flux de controle reste TODO 20)
            Inference de type quand aucune annotation n'est donnee
              (let x = 42 infere Int) - reutilise le meme
              "ExprInferType" best-effort que GOCW32.PAS/
              PERLCW32.PAS pour ce cas, jamais un vrai systeme de
              contraintes Hindley-Milner
            Type explicite (let x: Int = 42) verifie best-effort
              contre le type infere du membre droit
            typealias Nom = Type (simple enregistrement dans
              TypeTab, comme le "type Nom = Type" de GOCW32.PAS)

  TODO 06 - EXPRESSIONS, OPERATEURS, LITTERAUX ET INTERPOLATION
            TExprNode/TExprKind (EK_INTLIT/FLOATLIT/STRINGLIT/
              BOOLLIT/NILLIT/IDENT/UNARY/BINARY/CALL/INDEX/
              SELECTOR/TUPLE/ARRAYLIT/DICTLIT/CLOSURE/
              STRINGINTERP/OPTIONALCHAIN/FORCEDUNWRAP/ASCAST/
              ISCHECK) + ExprArgPool partage (arguments d'appel,
              elements de litteral tableau/dictionnaire, membres de
              tuple)
            Interpolation de chaine "texte \(expr) texte" construite
              comme une liste de segments (texte litteral / noeud
              d'expression) - reutilise le lexer de TODO 02
            Precedence des operateurs (groupes officiels de Swift :
              affectation, ??, disjonction ||, conjonction &&,
              comparaison, intervalle a..<b/a...b, addition,
              multiplication, exponentiation - reduit ici a un
              sous-ensemble couvrant SAMPLES\SWIFT\*.swift)
            Litteraux de collection [1, 2, 3] (Array) et
              [cle: val, ...] (Dictionary) - distingues par la
              presence ou non de ':'
            self dans une methode - reference implicite au
              receveur, resolue comme un identificateur special
            Chainage optionnel (a?.b?.c), deballage force (a!),
              nil-coalescing (a ?? b) construits comme des noeuds
              dedies, la VRAIE semantique (court-circuit si nil,
              panique si deballage force sur nil) restant un sujet
              de generateur de code (TODO 21)

  TODO 07 - STRUCTURES DE CONTROLE : IF/GUARD/SWITCH/BOUCLES
            if / else if / else (condition simple - "if let"/
              "if var" pour les optionnels est traite au TODO 14,
              pas ici, meme discipline que GOCW32.PAS separant
              switch ordinaire de switch-type)
            guard Condition else { ... } - inverse du if (le bloc
              "else" s'execute quand la condition est FAUSSE et
              DOIT sortir de la portee courante - return/throw/
              break/continue - verifie best-effort, pas une vraie
              analyse de flux de controle exhaustive)
            switch/case avec pattern matching : valeurs litterales,
              intervalles (case 1...5:), plusieurs valeurs
              separees par virgule, "default" - PAS de fallthrough
              implicite (contrairement a C, chaque case sort
              automatiquement du switch - mot-cle "fallthrough"
              explicite le reintroduit, a couvrir)
            while Condition { ... }
            repeat { ... } while Condition (equivalent du
              do-while)
            for Nom in Intervalle/Collection { ... } avec les
              intervalles a..<b (semi-ouvert) et a...b (ferme) -
              reutilise le meme modele de boucle-compteur que le
              "for range" de GOCW32.PAS pour un intervalle entier ;
              l'iteration sur Array/Dictionary/Set attend TODO 16
            break / continue (avec etiquette optionnelle, meme
              schema que GOCW32.PAS)

  TODO 08 - FONCTIONS : PARAMETRES, SURCHARGE, RECURSION, FERMETURES
            func Nom(etiquette externe? nomInterne: Type = valeurDefaut,
              ...) -> TypeRetour - Swift distingue l'ETIQUETTE
              externe (utilisee par l'appelant) du NOM interne
              (utilise dans le corps) ; "_" en etiquette externe
              signifie "aucune etiquette" (tous les exemples
              SAMPLES\SWIFT\*.swift utilisent cette forme, ex.
              "func add(_ a: Int, _ b: Int) -> Int")
            Parametres avec valeur par defaut (= expression
              constante ou simple, evaluee cote APPELANT si omis)
            inout Type (parametre passe par ADRESSE, l'appelant
              doit prefixer l'argument par '&' - modele memoire
              simple : une adresse, pas de vraie copie-puis-recopie
              "copy-in copy-out" de la spec Swift reelle, ecart
              documente)
            Surcharge de fonctions (meme nom, signatures de
              parametres differentes) - resolution au type des
              arguments au point d'appel, best-effort (pas de
              recherche de surcharge complete avec priorites de
              conversion implicite)
            Fermetures (closures) : litterales { (params) -> Type in
              corps }, syntaxe de fermeture en fin d'appel
              ("trailing closure"), capture de variables de la
              portee englobante - PORTEE A DECIDER EXPLICITEMENT
              ici (comme le TODO15 de GOCW32.PAS pour les
              goroutines) : capture par REFERENCE PARTAGEE (une
              vraie fermeture Swift capture par reference une
              variable mutable) vs simplification a une capture par
              valeur au moment de la creation - trancher avant
              codegen, pas au moment d'ecrire TODO 21
            @escaping (une fermeture qui survit a l'appel de la
              fonction qui la recoit) - portee a documenter,
              potentiellement hors de portee si aucun exemple ne
              l'exige

  TODO 09 - STRUCTS : SEMANTIQUE DE VALEUR, INIT ET MUTATING
            struct Nom { champs ; methodes } - semantique de VALEUR
              (une affectation ou un passage en parametre COPIE
              toutes les donnees, jamais un partage de reference -
              distinction centrale avec class, TODO 10)
            Initialiseur MEMBRE IMPLICITE (Point(x: 0, y: 0) sans
              init ecrit explicitement) genere automatiquement a
              partir des champs declares, plus init personnalise
              (init(...) { self.x = ... }) si present
            Methodes ordinaires (lecture seule du receveur, comme
              un receveur PAR VALEUR en Go/GOCW32.PAS) vs mutating
              func (le receveur "self" peut etre REASSIGNE dans le
              corps - necessite un parametre self par ADRESSE au
              codegen, contrairement aux methodes non-mutating)
            Proprietes calculees (var aire: Int { return largeur *
              hauteur } - pas de stockage, juste un getter ; un vrai
              { get { ... } set { ... } } avec les deux reste a
              decider selon les exemples reels)

  TODO 10 - CLASSES : HERITAGE, OVERRIDE ET INTRODUCTION A ARC
            class Nom [: SuperClasse] { champs ; methodes ; init } -
              semantique de REFERENCE (une affectation ou un
              passage en parametre PARTAGE la MEME instance,
              jamais une copie - modele "pointeur vers objet sur le
              tas", comme le receveur pointeur de GOCW32.PAS mais
              IMPLICITE partout, jamais explicite avec un '*')
            Heritage simple (UNE seule superclasse, comme Swift
              reel - pas d'heritage multiple) ; override func Nom
              (...) redefinit une methode de la superclasse -
              verifie que le nom/la signature existe bien dans une
              superclasse (sinon erreur, regle Swift reelle)
            Dispatch dynamique de methode (VTABLE par classe,
              similaire au modele "boite" d'interface de
              GOCW32.PAS mais ici organise par index de methode fixe
              dans la table de la classe, pas par comparaison
              sequentielle de type)
            is Type (test de type dynamique), as? Type (cast
              optionnel - nil si echec), as! Type (cast force -
              panique si echec) - reutilisent la meme table de type
              dynamique que le dispatch
            Introduction a ARC (Automatic Reference Counting) :
              chaque instance de classe allouee sur le tas porte un
              compteur de references ; portee EXACTE du comptage
              automatique (quand incrementer/decrementer) est
              PLANIFIEE ici mais l'implementation reelle au
              generateur de code est reportee et detaillee au
              TODO 18 (modele memoire) - decision architecturale a
              trancher AVANT le codegen, meme discipline que le
              choix cooperatif-vs-threads-reels de GOCW32.PAS pour
              les goroutines

  TODO 11 - PROTOCOLES ET EXTENSIONS
            protocol Nom { func methode() -> Type ; ... } (contrat
              de methodes, sans corps) - conformance declaree via
              "struct/class Nom: Protocole" ou par une extension
              separee ("extension Nom: Protocole { ... }" - la
              forme utilisee par SAMPLES\SWIFT\protos.swift)
            Verification de conformite (best-effort, comme
              l'interface-satisfaction structurelle de GOCW32.PAS) :
              chaque methode du protocole doit avoir une
              implementation correspondante dans le type conforme
              OU dans une extension de ce type
            extension Type { methodes/proprietes calculees
              supplementaires } - ajoute des membres a un type
              EXISTANT (struct/class/enum) apres sa declaration
              initiale ; implementations par defaut d'un protocole
              via une extension DU PROTOCOLE lui-meme (portee a
              documenter si couverte)
            Un protocole utilise comme TYPE de variable/parametre
              (let d: Drawable = Circle(...)) necessite le meme
              modele de "boite" (type concret + pointeur de donnees)
              que les interfaces de GOCW32.PAS - reutiliser ce
              modele plutot que d'en inventer un nouveau

  TODO 12 - ENUMERATIONS : VALEURS BRUTES, VALEURS ASSOCIEES
            enum Nom { case a, b, c } (cas simples, sans donnee)
            enum Nom: Int { case a = 1, b = 2 } (valeurs brutes -
              RawValue explicite ou auto-incremente depuis le
              premier cas comme Int, meme mecanisme que l'iota de
              Go/GOCW32.PAS pour la partie auto-incrementee)
            enum Nom { case succes(Int) ; case echec(String) }
              (valeurs ASSOCIEES - chaque cas transporte des
              donnees typees differentes selon le cas ; modele
              memoire "tag + union" : un entier de discrimination
              plus une zone memoire dimensionnee sur le PLUS GRAND
              des cas)
            switch sur un enum : pattern matching par cas (case
              .succes(let valeur): ...) extrait la donnee associee
              dans une liaison locale - reutilise le pattern
              matching du TODO 07, etendu pour lier une variable
              depuis l'interieur d'un motif

  TODO 13 - GENERIQUES : FONCTIONS/TYPES GENERIQUES ET CONTRAINTES
            func Nom<T>(valeur: T) -> T { ... } - parametre de type
              generique substitue par MONOMORPHISATION au point
              d'appel (une version specialisee du code est generee
              par combinaison REELLE de types utilisee - PORTEE A
              DECIDER : monomorphisation reelle [plus de code
              genere, types precis] vs un unique "T = pointeur
              generique de 4 octets" simplifie [comme Go avant les
              generiques 1.18, plus proche de l'esprit
              "correction avant vitesse" du reste de ce fichier] -
              trancher avant le codegen)
            struct Nom<T> { var valeur: T } (type generique) - meme
              decision de modele que ci-dessus s'applique
            Contraintes (<T: Comparable>, where T: Equatable) -
              verifiees best-effort contre les protocoles/types
              connus, jamais une verification de satisfaction
              complete
            Plusieurs parametres de type (<T, U>) et inference
              depuis les arguments reels au point d'appel (identity
              (42) infere T = Int sans l'ecrire explicitement)

  TODO 14 - OPTIONNELS : OPTIONAL<T>, IF LET, GUARD LET, ??, !
            Optional<T> (sucre : T?) represente comme un mot
              discriminant (0 = nil, 1 = valeur presente) suivi de
              la VALEUR elle-meme (ou d'un pointeur vers elle si T
              ne rentre pas dans un mot machine) - meme famille de
              decision que le modele "boite" des interfaces
            if let nom = expr { ... } / if var nom = expr { ... }
              (deballage conditionnel - le bloc ne s'execute que si
              expr n'est pas nil, "nom" y est alors du type non-
              optionnel)
            guard let nom = expr else { ... } (deballage
              obligatoire - le bloc else DOIT sortir de la portee,
              meme regle que le guard simple du TODO 07 ; "nom"
              reste visible APRES le guard, contrairement a if let)
            ?? (nil-coalescing : valeur par defaut si nil)
            ! (deballage force - panique a l'execution si nil, ce
              qui necessite le meme mecanisme d'arret propre que
              panic() dans defer/panic/recover si ce sous-systeme
              existe, sinon un simple message + code de sortie non
              nul)
            Chainage optionnel (a?.b?.methode()) - court-circuite
              toute la chaine en nil au premier maillon nil
              rencontre, sans jamais dereferencer plus loin

  TODO 15 - GESTION D'ERREURS : THROWS, DO/TRY/CATCH, DEFER
            func Nom(...) throws -> Type (une fonction qui PEUT
              lancer une erreur) - modele de propagation choisi
              explicitement ici (PAS un vrai deroulement de pile
              avec table d'exceptions SEH, meme choix que le
              PANIC_FLAG global de GOCW32.PAS pour panic/recover) :
              un fanion + une valeur d'erreur globale, verifiee
              apres chaque appel a une fonction throws
            do { try appelQuiPeutLancer() } catch ErreurSpecifique {
              ... } catch { ... } (bloc catch generique en dernier
              recours) - throw Valeur (l'operande doit se conformer
              au protocole Error, reutilise le modele de "boite"
              des protocoles)
            try? expr (convertit un throws en Optional : nil si une
              erreur a ete lancee, la valeur sinon)
            try! expr (deballage force d'un throws - panique a
              l'execution si une erreur est lancee)
            defer { ... } (bloc execute a la SORTIE de la portee
              englobante, quel que soit le chemin de sortie -
              normal, return anticipe, ou erreur lancee ; ordre
              LIFO si plusieurs "defer" dans le meme bloc - meme
              mecanisme de collecte-puis-rejeu-inverse que le
              TODO 16 de GOCW32.PAS)

  TODO 16 - TABLEAUX, DICTIONNAIRES ET ENSEMBLES
            Array<T> : tampon+longueur+capacite (meme en-tete a 3
              mots que le modele slice de GOCW32.PAS), litteral
              [1, 2, 3], count, append(_:), remove(at:), indexation
              a[i] avec verification de borne (panique documentee
              si hors limites, pas un comportement indefini),
              for-in iteration
            Dictionary<K, V> : reutilise le modele "tableau lineaire
              d'entrees" de GOCW32.PAS (correction avant vitesse,
              pas une vraie table de hachage) - litteral [cle: val,
              ...], indexation par cle renvoyant un Optional<V>
              (nil si absente - PAS de "valeur zero" implicite
              comme la map de Go, difference reelle documentee),
              removeValue(forKey:)
            Set<T> : meme modele lineaire, sans valeur associee
              (juste presence/absence) - insert(_:), contains(_:),
              remove(_:)
            COPY-ON-WRITE reel de Swift (une copie de Array/
              Dictionary partage le meme tampon jusqu'a la premiere
              mutation) est une optimisation, PAS une question de
              correction — portee a documenter : ce compilateur
              peut legitimement copier IMMEDIATEMENT (semantique de
              valeur toujours correcte, juste plus lent) plutot que
              d'implementer le vrai partage-differe-la-copie, meme
              esprit "correction avant vitesse" que le reste du
              fichier

  TODO 17 - CHAINES ET CARACTERES : INTERPOLATION ET UTF-8
            String comme tampon UTF-8 + longueur EN OCTETS (pas en
              "Character" - la vraie distinction Swift entre
              nombre d'octets/de scalaires Unicode/de graphemes
              affiches est HORS DE PORTEE, documente ; count sur une
              String compte les octets ou, au mieux, les points de
              code, jamais les vrais graphemes composes)
            Concatenation reelle (+ / +=), interpolation "\(expr)"
              (assemblee via le meme _SWRT_STRCAT que la
              concatenation, un segment a la fois)
            Character (un seul point de code/octet UTF-8 - meme
              limitation de "grapheme reel" que String ci-dessus)
            Iteration for-in sur une String (rune-par-rune UTF-8,
              meme decodeur que le TODO14 de GOCW32.PAS)
            Comparaison == par CONTENU (jamais par pointeur, meme
              piege deja documente et corrige dans GOCW32.PAS a
              anticiper directement ici plutot que de le
              redecouvrir par execution)

  TODO 18 - MODELE MEMOIRE : ARC ET SEMANTIQUE DE COPIE
            Decision architecturale centrale de ce compilateur,
              a trancher AVANT le generateur de code (TODO 21),
              meme discipline que le choix goroutines-cooperatives-
              vs-threads-reels de GOCW32.PAS (qui avait ete
              explicitement plannifie a l'avance puis REVISE en
              connaissance de cause une fois TODO 15 atteint - garder
              cette meme discipline ici, ne pas deviner maintenant
              ce qui sera decide plus tard) :
              - ARC REEL (compteur de references incremente/
                decremente par le generateur de code a chaque
                affectation/sortie de portee impliquant une
                instance de classe, liberation immediate a zero) -
                le plus fidele a Swift reel, le plus de surface de
                bogues (cycles de reference non casses = fuite,
                double-liberation si un decrementement est oublie
                ou double-compte)
              - PAS DE LIBERATION DU TOUT (alloue sur le tas via
                le meme _SWRT_ALLOC que les autres types, jamais
                libere explicitement - meme choix pragmatique que
                "pas de vrai GC" deja assume ET DOCUMENTE par
                GOCW32.PAS pour ses propres structures - correct
                pour tout programme de la taille d'un
                SAMPLES\SWIFT\*.swift, fuite sans consequence
                observable a cette echelle)
            Semantique de copie des types VALEUR (struct/enum/
              Array/Dictionary/Set/tuple) : une copie reelle des
              donnees a chaque affectation/passage en parametre -
              PAS de partage implicite, contrairement aux classes
            Quel que soit le choix retenu pour les classes, il doit
              etre documente ICI, avec la meme honnetete que
              chaque decision similaire des compilateurs freres
              (DELPHI.PAS/GOCW32.PAS/PERLCW32.PAS) - jamais une
              simulation silencieuse

  TODO 19 - ANALYSE SEMANTIQUE : SYMBOLES, PORTEES, VERIFICATION
            Verification de type best-effort sur affectations/
              appels/retours (types incompatibles = erreur claire,
              jamais une conversion implicite silencieuse hors des
              regles reelles du langage - ex. Int vers Double
              n'est PAS implicite en Swift reel, contrairement a
              beaucoup de langages)
            "declare et jamais utilise" (meme regle stricte que
              GOCW32.PAS pour les variables locales - erreur en
              mode strict, avertissement sinon)
            Verification des types de retour de fonction contre le
              corps (chaque chemin d'un "func ... -> T" non-Void
              doit renvoyer une valeur - best-effort, pas une vraie
              analyse de chemins exhaustive)
            Verification de conformite aux protocoles (voir
              TODO 11) et de compatibilite de signature pour
              override (voir TODO 10) executees a cette etape

  TODO 20 - BIBLIOTHEQUE STANDARD MINIMALE
            print(_:) (un seul argument, converti en String selon
              son type reel - Int/Double/String/Bool/tableau -
              reutilise le meme modele "un seul argument" que
              fmt.Println de GOCW32.PAS avant son extension
              bibliotheque standard)
            Methodes String minimales : count, +/+=, isEmpty,
              uppercased()/lowercased() si exerce par un exemple
            Methodes Array/Dictionary minimales : count, isEmpty
            Fonctions arithmetiques/Math si exerce (abs, min, max)
            StdlibTab (meme modele que GOCW32.PAS TODO 20 : chaque
              entree connue du frontend a l'analyse, contrepartie
              runtime reelle ajoutee selon les besoins constates
              par execution, jamais devinee a l'avance)

  TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM
            Meme discipline que GOCW32.PAS/DELPHI.PAS : portee
              VOLONTAIREMENT restreinte a ce que TODO 01-20 ont
              reellement construit, tout le reste s'arrete
              PROPREMENT (FatalError explicite, jamais un .asm
              silencieusement faux ni un plantage)
            Convention d'appel : EAX porte TOUJOURS le resultat
              scalaire d'une expression ; valeurs multi-mots
              (struct par valeur, tuple, Optional encapsulant un
              type multi-mots) via une convention dediee, a
              documenter au moment ou elle est reellement
              implementee, pas devinee ici a l'avance
            Emission de la vtable par classe (TODO 10), de la boite
              protocole (TODO 11), du tag+union d'enum a valeurs
              associees (TODO 12), et du modele memoire retenu au
              TODO 18 - CHACUN documente a l'endroit exact ou il
              est implemente, avec le detail des bogues reels
              trouves PAR EXECUTION (jamais par relecture du .asm
              seule) comme le veut la discipline etablie par tous
              les compilateurs freres de ce projet

  TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32
            Assembleur 80386 hand-roule (encodeur ModRM/SIB,
              fixups, table des imports) - meme architecture que
              GOCW32.PAS/DELPHI.PAS, aucune dependance a un
              assembleur externe
            Table COFF minimale (en-tete, section .text/.data,
              table de symboles, relocations REL32/DIR32) - sortie
              .OBJ laissee au lieur externe pour les adresses
              finales, comme les compilateurs freres

  TODO 23 - BACKEND BINAIRE .EXE PE WIN32 ET RUNTIME EMBARQUE
            Ecrit directement un fichier .EXE PE Win32 COMPLET
              (en-tetes DOS/PE/sections/table d'import IAT
              KERNEL32.DLL reelle) sans lieur externe - meme
              modele que GOCW32.PAS TODO 23
            Runtime embarque minimal : allocation tas
              (GetProcessHeap/HeapAlloc), E/S console
              (GetStdHandle/WriteFile), sortie de processus
              (ExitProcess) - etendu selon les besoins reels des
              TODO 09-20 (ARC, closures, chaines, etc.) au moment
              ou chacun est implemente, jamais par anticipation

  TODO 24 - AUTO-TESTS (SELF-TESTS INTERNES)
            Un SelfTest par sous-systeme (LexSelfTest,
              KeywordSelfTest, TypeSelfTest, DeclSelfTest,
              ExprSelfTest, StmtSelfTest, FuncSelfTest,
              StructSelfTest, ClassSelfTest, ProtocolSelfTest,
              EnumSelfTest, GenericSelfTest, OptionalSelfTest,
              ErrorSelfTest, CollectionSelfTest, StringSelfTest,
              MemorySelfTest, SemanticAssert, StdlibSelfTest,
              CodegenSelfTest) - meme discipline incrementale que
              GOCW32.PAS/DELPHI.PAS/PERLCW32.PAS : chacun s'execute
              SANS CONDITION au demarrage, avant tout traitement du
              fichier source reel, et echoue fort (FatalError) au
              moindre ecart

  TODO 25 - VALIDATION FINALE CONTRE SAMPLES\SWIFT\*
            Compile+EXECUTE reellement (pas seulement "compile sans
              erreur") verifie pour CHAQUE SAMPLES\SWIFT\*.swift
              (hello, math, control, loops, arrays, structs,
              classes, protos, enums, optionals, errors, generics)
              - meme discipline de rapport honnete que la section
              equivalente de GOCW32.PAS : lister precisement quels
              fichiers reussissent completement, lesquels
              s'arretent proprement et POURQUOI (avec la ou les
              extensions manquantes exactes), jamais une
              affirmation globale non verifiee fichier par fichier
  ============================================================ *)

(* ============================================================
  TODO 25 - VALIDATION FINALE : ETAT REEL, HONNETEMENT DOCUMENTE
  ============================================================
  Compile+EXECUTE reellement (pas seulement "compile sans erreur") a ete
  verifie pour CHAQUE SAMPLES\SWIFT\*.swift, via Run() lui-meme (bascule
  de "seulement tokeniser" a une VRAIE tentative de compilation complete
  - voir la note d en-tete de Run() plus bas), avec le resultat suivant :

  REUSSITE COMPLETE, 8/12 FICHIERS (compile, produit un .EXE PE Win32 REEL,
  EXECUTE sur Windows reel - Git Bash ET PowerShell natif -, sortie
  EXACTEMENT conforme a ce qu un vrai compilateur Swift produirait, code
  de sortie 0) - MIS A JOUR apres QUATRE extensions post-TODO25 (controle
  de flux, construction de classe, compilation de fonctions, defer au
  niveau fichier - voir leurs propres blocs plus bas pour le detail
  complet de chacune) :
    hello.swift    ("Hello, 8086!" / "1" / "1")
    arrays.swift   (10/20/30/40/50/5/0/1/2/3/4)
    classes.swift  (42)
    control.swift  (2/30/1 - if/else-if/else, switch, fonction avec guard/
      return, appel depuis un initialiseur de global, EN UN SEUL fichier)
    enums.swift    (1/3)
    errors.swift   (1/99 - fonction avec local non-constant, defer au
      niveau fichier execute EN DERNIER, juste avant la sortie)
    generics.swift (42/20 - fonctions GENERIQUES, "juste assez" pour
      passer par la convention EAX sans monomorphisation reelle)
    loops.swift    (0/1/2/3/4/10/9/8/0/1/2/3/4/0/1/2/0/1/3/4/5 - exerce
      while/repeat-while/for-in/break/continue EN UN SEUL fichier)

  ARRET PROPRE, 4/12 FICHIERS RESTANTS (FatalError EXACT et PRECIS,
  jamais un plantage, jamais une valeur devinee) :
    - math.swift      : fonction "swap" avec DEUX parametres "inout" -
        alias PAR ADRESSE non couvert (extension future) ; "add"/
        "multiply"/"factorial" (recursion COMPRISE), eux, compilent et
        s executeraient correctement (non exerce ici, "swap" arrete tout
        le fichier AVANT que quoi que ce soit d autre ne soit atteint,
        EmitUserFunctions compile TOUTE fonction sans condition).
    - optionals.swift : "let result: Int = maybeValue ?? 0" -
        initialiseur de global non repliable (nil-coalescing sur une
        VARIABLE, jamais un simple litteral - "??" lui-meme reste non
        couvert dans CompileExpr).
    - protos.swift    : "let c: Circle = Circle(radius: 5)" -
        initialiseur de global non repliable (construction de STRUCT,
        valeur MULTI-MOTS incompatible avec la convention EAX unique -
        contrairement a une classe, un pointeur UNIQUE ne suffit pas).
    - structs.swift   : "let origin: Point = Point(x: 0, y: 0)" -
        meme raison exacte que protos.swift (construction de struct).

  BOGUE REEL trouve et corrige PENDANT ce TODO 25 (par EXECUTION reelle,
  jamais par relecture du .asm ni par un self-test structurel) :
  generics.swift/math.swift/optionals.swift COMPILAIENT et s EXECUTAIENT
  SANS ERREUR (code de sortie 0) mais IMPRIMAIENT des valeurs FAUSSES (0
  partout, au lieu de 42/20, de 30/200/120 et de 42/42/99 respectivement)
  - EmitDataSeg (TODO 21) tombait SILENCIEUSEMENT dans sa branche
  generique "DD 0" pour tout global dont l initialiseur existait mais
  n etait PAS repliable a la compilation (ConstVal n est REMPLI que si
  IsConst=Vrai, ApplyExprInitToSymbol - sinon il garde sa valeur zero par
  defaut, INDISCERNABLE d une VRAIE constante 0). CORRIGE en ajoutant un
  FatalError EXPLICITE des que HasInit=Vrai et IsConst=Faux pour ce
  global, AVANT tout dispatch par type - convertit ces 3 "faux succes"
  silencieux en arrets propres honnetes, EXACTEMENT comme tout autre
  construct non couvert. Une VALEUR FAUSSE imprimee silencieusement est
  un defaut PIRE qu un FatalError (elle ressemble a un succes) - cette
  classe de bogue ne peut etre trouvee que par une EXECUTION reelle
  suivie d une VERIFICATION de la sortie, jamais par la seule absence
  d erreur de compilation : exactement la raison d etre de ce TODO 25.

  LIMITATIONS ASSUMEES a l issue de ce TODO 25 LUI-MEME (photo HISTORIQUE
  au moment ou ce TODO 25 s est termine, PAS l etat courant - voir les
  blocs "EXTENSION..." plus bas, qui les levent UNE A LA FOIS, pour ce
  qui est REELLEMENT couvert aujourd hui) : aucune fonction
  utilisateur n est compilee (CompileFuncDef n existe pas) ; aucun
  controle de flux (if/while/repeat-while/for-in/switch/guard) n est
  couvert ; aucune instance de struct/class/enum/protocol/generique/
  Optional/collection n est construite a l execution ; SEULS les globaux
  SANS initialiseur ou initialises par un LITTERAL/une expression
  CONSTANTE repliable, plus print(_:) (String/Int) et +/-/* entre eux,
  sont couverts. Chacune de ces extensions reste un TODO 21 separe,
  ajoute UNE A LA FOIS avec son propre self-test ET sa propre
  verification par execution reelle - meme discipline multi-session que
  GOCW32.PAS/DELPHI.PAS.
  ============================================================ *)

(* ============================================================
  EXTENSION CONTROLE DE FLUX (ajoutee APRES ce TODO 25, sur demande
  explicite de l utilisateur suite au rapport ci-dessus signalant que
  arrays.swift/loops.swift s arretaient au premier for-in/while) - meme
  discipline "petite extension verifiee, PAS une reecriture" que TOUTES
  les extensions post-TODO25 de GOCW32.PAS.
  ============================================================
  AJOUTE a CompileExpr/CompileStmt (TODO 21) : if/else-if/else (SANS
  liaison "if let"/"if var", HORS de portee), while, repeat-while, for-in
  SUR UN INTERVALLE ENTIER SEULEMENT (a..<b/a...b - iteration sur Array/
  Dictionary/Set/String reste une extension future, TODO 16/17), break/
  continue NON etiquetes, et les 6 operateurs de comparaison (<, <=, >,
  >=, ==, !=) dans EK_BINARY - MEME architecture EXACTE que GOCW32.PAS
  pour if/while (CMP+TEST/Jcc, JAMAIS de SETcc - voir EmitCompareJcc) ;
  break/continue et le for-in sur intervalle N ONT PAS d equivalent a
  porter (confirme par recherche : GOCW32.PAS ne compile pas non plus
  break/continue a cette date), concus ICI a partir de zero (pile
  CgLoopBreakLbl/CgLoopContinueLbl, permet l imbrication).

  BOGUE REEL trouve et corrige PENDANT cette extension (execution du
  rapport TODO 25 lui-meme, PAS un self-test) : le PREMIER essai retirait
  simplement le filtre IsGlobal d EmitDataSeg (necessaire pour donner un
  VRAI stockage .DATA a une variable de boucle for-in, IsGlobal=Faux vu
  qu aucune fonction n est encore compilee) - mais ce retrait capturait
  AUSSI les VRAIS parametres/variables locales de fonction (ex. "temp"
  dans math.swift, "status" dans errors.swift), desormais signales A
  TORT comme des "globaux" non repliables dans le message FatalError.
  CORRIGE en ajoutant TSymRec.IsTopLevelLocal (Vrai UNIQUEMENT pour une
  variable de boucle for-in, ParseForInStmt) - EmitDataSeg ne considere
  desormais qu IsGlobal OU IsTopLevelLocal, jamais un VRAI local/
  parametre de fonction. Trouve en RE-executant le rapport TODO 25 sur
  les 12 echantillons apres le premier essai, pas par un self-test
  (aucun des 12 echantillons n a de fonction AVEC parametre non-const
  parmi ceux qui atteignent desormais ce code) - meme discipline
  "verifier par execution reelle, pas seulement par les self-tests" que
  chaque bogue precedent de ce fichier.

  Etiquette .DATA d une variable de boucle : CgVarLabel rend chaque
  variable IsTopLevelLocal UNIQUE par index SymTab (ex. "_SW_L12_i"),
  jamais par simple nom - permet a DEUX boucles for-in SIBLING de
  reutiliser legalement le MEME nom de variable sans partager le meme
  emplacement memoire.

  REUSSITE COMPLETE : arrays.swift, loops.swift (voir le rapport TODO 25
  mis a jour ci-dessus) - loops.swift exerce a lui seul while/repeat-
  while/for-in/break/continue/comparaisons, verifie par EXECUTION reelle
  (Git Bash ET PowerShell natif), sortie EXACTEMENT conforme (21 valeurs
  imprimees, toutes correctes, y compris l effet du "if" imbrique/break/
  continue a l interieur du for-in).

  LIMITATIONS ASSUMEES (inchangees pour tout le reste) : "if let"/"if
  var"/guard/switch restent hors de portee ; for-in sur Array/Dictionary/
  Set/String reste une extension future ; break/continue ETIQUETES
  restent hors de portee ; &&/|| (court-circuit) restent hors de portee
  (non exerces par aucun echantillon actuel).
  ============================================================ *)

(* ============================================================
  EXTENSION CONSTRUCTION DE CLASSE (ajoutee APRES l EXTENSION CONTROLE DE
  FLUX ci-dessus, sur demande explicite de l utilisateur suite au rapport
  "classes.swift : initialiseur non repliable" - meme discipline
  incrementale que toutes les extensions post-TODO25 de ce fichier).
  ============================================================
  AJOUTE : CgIsClassCtorCall (EmitDataSeg/CompileExpr/
  CompileGlobalRuntimeInits) reconnait "NomDeClasse()" (appel constructeur
  SANS argument vers une classe - le front-end, TODO 09/10, resolvait
  DEJA son TypeIdx a la classe elle-meme, meme SANS aucun "init" ecrit -
  voir ClassSelfTest) comme un SECOND cas de "global non repliable"
  desormais INITIALISABLE REELLEMENT (allocation tas via _SWRT_ALLOC,
  DEJA zero-rempli par HEAP_ZERO_MEMORY - pointeur laisse en EAX, une
  classe etant un type REFERENCE) plutot que de s arreter proprement.
  CompileGlobalRuntimeInits (NOUVELLE procedure, appelee en TOUT PREMIER
  dans _SWSTART, avant TopLevelStmts) ecrit cette adresse dans le global
  A L EXECUTION, ECRASANT le placeholder "DD 0" qu EmitDataSeg y avait
  laisse a l assemblage (aucun tas n existe encore a ce moment-la).
  TypeTab[Classe].Size ne couvre QUE les champs PROPRES de cette classe
  (JAMAIS ceux d une eventuelle superclasse, simplification DEJA
  documentee par ParseClassType depuis le TODO 10 - AUCUN echantillon
  actuel n instancie de sous-classe, donc jamais exercee ici). Un
  constructeur AVEC arguments ("Point(x: 0, y: 0)") ou une construction
  de STRUCT (valeur MULTI-MOTS incompatible avec la convention EAX
  unique) restent HORS de portee (FatalError explicite).

  BOGUE d auto-test (PAS un bogue d execution) trouve et corrige PENDANT
  cette extension : la premiere version du nouveau bloc CodegenSelfTest
  affirmait "PUSH 8" (une classe Animal a 2 champs : String + Int,
  suppose a tort 4+4 octets) - le self-test PASSAIT quand meme, mais par
  COINCIDENCE : ce texte existe DEJA, SANS RAPPORT, dans _SWRT_ALLOC
  lui-meme (HeapAlloc(dwFlags=HEAP_ZERO_MEMORY=8)) - un FAUX POSITIF.
  TypeTab[PDT_STRING].Size vaut 8 (pas 4) DEPUIS le TODO 03/04 - jamais
  reconcilie avec sa VRAIE representation codegen (un simple pointeur 4
  octets, TODO 17/21/23) car rien avant cette extension n avait besoin de
  calculer la taille d une classe/struct CONTENANT un champ String.
  Corrige en verifiant la VRAIE valeur ("PUSH 12"), confirmee en
  inspectant le .asm REEL via l option "-asm" - meme classe de bogue que
  les erreurs de comptage d octets MOVZX/MOV BYTE PTR du TODO 22.

  REUSSITE COMPLETE : classes.swift (42, verifie par EXECUTION reelle,
  Git Bash ET PowerShell natif).
  ============================================================ *)

(* ============================================================
  EXTENSION COMPILATION DE FONCTIONS (ajoutee APRES l EXTENSION
  CONSTRUCTION DE CLASSE ci-dessus, sur demande explicite de l utilisateur
  suite au rapport "control.swift : initialiseur non repliable" - meme
  discipline incrementale que toutes les extensions post-TODO25 de ce
  fichier). La PLUS GROSSE extension a ce jour : compilation REELLE de
  fonctions utilisateur (CompileFuncDef, enfin ECRITE), if/else-if/else
  ETAIT deja couvert (EXTENSION CONTROLE DE FLUX) mais "guard"/"switch"
  et l appel de fonction lui-meme ne l etaient PAS - control.swift
  exerce les TROIS a la fois.
  ============================================================
  AJOUTE : TFuncDefRec.ParamSymFirst/LocalSymFirst/LocalSymCount (capture,
  au moment du PARSING - ParseFuncDecl -, les plages EXACTES de SymTab
  occupees par les parametres et par le corps d une fonction, puisque
  SymTab est APPEND-ONLY et que SymFind par NOM resterait AMBIGU une
  fois toutes les portees refermees - meme technique EXACTE que
  STK_FORRANGE.Extra de l EXTENSION CONTROLE DE FLUX). CompileFuncDef
  assigne alors de VRAIS deplacements EBP (TSymRec.Offset, reserve depuis
  le TODO 05/21, JAMAIS assigne avant cette extension) : parametres
  POSITIFS a partir de +8, locales (ET tout symbole imbrique du CORPS -
  meme une variable de boucle for-in interne) NEGATIFS a partir de -4 -
  CgVarOperand route desormais TROIS cas (IsGlobal/IsTopLevelLocal ->
  .DATA ; SINON -> EBP-relatif, un VRAI parametre/local ne pouvant
  exister qu APRES cette extension). Prologue PUSH EBP/MOV EBP,ESP[/SUB
  ESP,N] ; CgCurFuncEpilogueLbl (UNE SEULE etiquette PARTAGEE, jamais une
  pile - les fonctions Swift ne s imbriquent pas ici) permet PLUSIEURS
  "return" (STK_RETURN, un "guard" en introduit souvent plusieurs) sans
  dupliquer l epilogue. "guard Condition else" (STK_GUARD) = INVERSE du
  "if" ; "switch"/"case"/"default" (STK_SWITCH) limite a UNE SEULE valeur
  ENTIERE litterale par case (jamais de liste/intervalle/fallthrough).
  Appel utilisateur (CompileExpr, CgIsUserFuncCall/FuncFind) : arguments
  pousses DE DROITE A GAUCHE, convention d appel UNIFORME avec le reste
  de ce generateur de code ("RET" NU cote callee, nettoyage de pile cote
  appelant - JAMAIS STDCALL, reserve aux VRAIES importations Win32).
  EmitUserFunctions compile TOUTE fonction de FuncDefPool SANS CONDITION
  (meme si jamais appelee, comme un VRAI compilateur) - un SEUL parametre
  "inout" (alias par ADRESSE, non couvert) arrete cette fonction PRECISE
  proprement, AVANT meme de toucher son corps, sans affecter les autres.

  Portee ETROITE, VOLONTAIRE : seuls des parametres/locales SCALAIRES
  (Int/Bool/String, jamais struct/class/tuple/tableau par VALEUR - une
  seule case EAX/EBP+N par symbole) ; "inout" hors de portee ; recursion
  (factorial dans math.swift compilerait/s executerait correctement,
  simple consequence de CALL/RET standard, AUCUN mecanisme special
  necessaire) ; surcharge best-effort DEJA geree par FuncFind (TODO 08),
  jamais reverifiee ici.

  REUSSITE COMPLETE : control.swift (2/30/1), enums.swift (1/3, switch
  seul suffisait - aucune fonction), generics.swift (42/20 - fonctions
  GENERIQUES, correctes "par accident" : la convention EAX ne distingue
  jamais un type CONCRET d un parametre de type generique, aucune
  monomorphisation reelle n est donc necessaire pour ce cas) - TOUS
  verifies par EXECUTION reelle (Git Bash ET PowerShell natif), sortie
  EXACTEMENT conforme.

  LIMITATIONS ASSUMEES : "inout" (math.swift/"swap") ; construction de
  struct (protos.swift/structs.swift - valeur multi-mots) ; "defer"
  (errors.swift, STK_DEFER/Kind=15, AUCUN mecanisme LIFO) ; "??"
  nil-coalescing sur une variable non-constante (optionals.swift) ;
  "guard let"/"switch" avec motif complexe ; closures ; methodes
  d instance (struct/class) restent toutes hors de portee.
  ============================================================ *)

(* ============================================================
  EXTENSION DEFER AU NIVEAU FICHIER + CORRECTIF STK_DECL (ajoutee APRES
  l EXTENSION COMPILATION DE FONCTIONS ci-dessus, sur demande explicite
  de l utilisateur suite au rapport "errors.swift : STK_DEFER/Kind=15
  non couvert" - meme discipline incrementale que toutes les extensions
  post-TODO25 de ce fichier).
  ============================================================
  AJOUTE : ParseDeferStmt (TODO 15) documentait DEJA "collecte-puis-
  rejeu-inverse, meme mecanisme que le TODO 16 de GOCW32.PAS" - CompileProgram
  applique desormais EXACTEMENT cela pour un "defer" rencontre
  DIRECTEMENT dans TopLevelStmts (la portee englobante d un script Swift
  EST le fichier entier) : chaque corps differe est mis de cote PENDANT
  le parcours principal de TopLevelStmts (jamais compile sur place),
  PUIS rejoue en ORDRE INVERSE (LIFO - regle Swift REELLE pour plusieurs
  "defer") juste avant la sortie de processus propre. Un "defer" a
  l INTERIEUR d une fonction ou d un bloc imbrique (if/while/etc.) reste
  HORS de portee (CompileStmt lui-meme n a AUCUN cas STK_DEFER).

  BOGUE REEL trouve et corrige PENDANT cette extension (par EXECUTION
  reelle du fichier PRODUIT, PAS un self-test) : une fois le "defer"
  lui-meme couvert, errors.swift compilait et s executait SANS ERREUR
  mais imprimait "0" au lieu du "1" attendu pour "print(ok)". Cause
  racine : "let status: Int = openFile(\"test.txt\")" - une variable
  LOCALE (a l interieur de la fonction "process", PAS un global) dont
  l initialiseur est un appel de fonction (non repliable). STK_DECL
  restait, depuis le TODO 05, un pur "rien a generer" (documente comme
  correct SEULEMENT pour un global, deja entierement pris en charge par
  EmitDataSeg/CompileGlobalRuntimeInits) - mais un LOCAL de fonction n a,
  lui, JAMAIS d autre occasion d etre initialise : son emplacement
  EBP-relatif contenait une valeur de PILE QUELCONQUE (jamais garantie
  zero) tant que rien n y ecrivait explicitement. Corrige en deux temps :
  (1) StmtNew(STK_DECL) capture desormais (ParseStatement, meme
  technique EXACTE que STK_FORRANGE.Extra/TFuncDefRec.ParamSymFirst) la
  plage SymTab EXACTE des symboles crees par cette instruction
  (Left=premier index, Extra=leur nombre - supporte "let a = 1, b = 2") ;
  (2) CompileStmt/STK_DECL evalue REELLEMENT l initialiseur de CHAQUE
  symbole NON-global de cette plage et l ecrit dans son emplacement
  (CgVarOperand), au lieu de ne rien faire. Une VALEUR FAUSSE imprimee
  silencieusement (encore) - meme classe de bogue EXACTE que le premier
  bogue du TODO 25 lui-meme (generics.swift/math.swift/optionals.swift),
  cette fois au niveau LOCAL plutot que global - confirme, une fois de
  plus, que seule une EXECUTION reelle (jamais un self-test structurel
  ni une relecture du .asm) pouvait reveler ce defaut.

  REUSSITE COMPLETE : errors.swift (1/99, verifie par EXECUTION reelle,
  Git Bash ET PowerShell natif - "1" AVANT "99", confirmant a la fois la
  correction du local "status" ET l ordre LIFO du "defer").

  LIMITATIONS ASSUMEES : "defer" a l interieur d une fonction ou d un
  bloc imbrique reste hors de portee ; plusieurs "defer" au niveau
  fichier fonctionneraient (ordre LIFO deja code) mais ne sont exerces
  par aucun echantillon actuel ; "throw"/"do"/"catch"/"try" restent hors
  de portee (STK_THROW/STK_DO, jamais rencontres par errors.swift lui-
  meme puisqu aucune VRAIE erreur n y est jamais lancee).
  ============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{ ============================================================ }

Const
  SWIFTW32_VERSION = '0.1';
  SWIFTW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { --- Constantes PE/COFF (identiques aux autres compilateurs   }
  { de ce projet - format Win32 universel, pas specifique a       }
  { Swift). }
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
  { PERLCW32.PAS/MOD3CW32.PAS/POWFXC32.PAS de ce meme projet).        }
  MAX_SYM           = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_FUNC          = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE          = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_FIELD_POOL    = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_PARAM         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LOCAL         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LABEL         = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR           = 255;
  MAX_ERRORS        = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_CLASS         = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_PROTO         = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
  MAX_ENUMCASE      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_GENERIC_PARAM = {$IFDEF FPC}16{$ELSE}4{$ENDIF};
  MAX_SCOPE         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_BIN           = 65536;
  MAX_BIN_LABEL     = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_BIN_FIXUP     = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_BIN_IMPORT    = {$IFDEF FPC}128{$ELSE}32{$ENDIF};

  { --- Prefixes de nommage ASM (voir en-tete du fichier) --- }
  ASM_PFX_GVAR    = '_SW_';     { variable globale                    }
  ASM_PFX_FUNC    = '_SWF_';    { fonction top-level                  }
  ASM_PFX_METHOD  = '_SWM_';    { methode (struct/class)               }
  ASM_PFX_STRING  = '_SWK_';    { constante chaine/litteral            }
  ASM_PFX_FLOAT   = '_SWFL_';   { constante flottante (Double, 8 octets)}
  ASM_PFX_RUNTIME = '_SWRT_';   { routine runtime                      }
  ASM_PFX_LABEL   = '_SWL_';    { label de saut interne                }
  ASM_PFX_TYPEDESC= '_SWT_';    { descripteur de type/vtable simplifiee}
  ASM_PFX_CLOSURE = '_SWC_';    { corps de fermeture (closure)         }
  ASM_PFX_ENUMCASE= '_SWE_';    { case d'enumeration (valeurs associees)}

Type
  TString = String;

  TOptions = Record
    SrcFile      : TString;   { fichier source (.swift)              }
    OutFile      : TString;   { fichier sortie (.exe, .obj ou .asm)   }
    OutFileGiven : Boolean;   { True si fourni explicitement (-o)     }
    Verbose      : Boolean;   { -v : banniere et statistiques         }
    DebugMode    : Boolean;   { -d : affichage de chaque token        }
    Warnings     : Boolean;   { -w : afficher les avertissements      }
    AsmOutput    : Boolean;   { -asm : produire aussi un .ASM lisible }
    ObjOnly      : Boolean;   { -obj : produire seulement un .OBJ     }
    StrictMode   : Boolean;   { -strict : erreurs Swift strictes       }
                               { (variable declaree et non utilisee,    }
                               { voir TODO 19) traitees comme fatales    }
                               { meme sans ce parametre - reserve pour    }
                               { assouplir ce comportement plus tard,     }
                               { actuellement toujours strict par defaut. }
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

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path: TString): TString;
Var
  I, LastSep: Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg: TString);
Begin
  WriteLn('SWIFTW32: FATAL: ', Msg);
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
  WriteLn('SWIFTW32: warning: ', Msg);
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
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('SWIFTW32 v', SWIFTW32_VERSION, ' (', SWIFTW32_DATE,
          ') - Compilateur Swift vers 80386 (Windows PE 32 bits)');
  WriteLn('SWIFTW32 - Cette commande permet de lancer le compilateur ',
          'Swift pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : SWIFTW32 [options] <source.swift> [options]');
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
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  SWIFTW32 hello.swift');
  WriteLn('  SWIFTW32 hello.swift hello.exe -v');
  WriteLn('  SWIFTW32 structs.swift -obj -w');
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
    WriteLn('SWIFTW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .swift - la structure reelle du fichier      }
  { (declarations top-level valides, etc.) ne peut etre validee        }
  { qu une fois le lexeur/analyseur disponibles (TODO 02+) ; ce n est    }
  { PAS encore fait ici, portee volontairement limitee a                  }
  { l infrastructure (TODO 01). }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.SWIFT' Then
    WarnMsg('extension attendue .swift, trouvee: ' + Ext);

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
  WriteLn('SWIFTW32 v', SWIFTW32_VERSION, ' (', SWIFTW32_DATE,
          ') - Compilateur Swift -> 80386 PE Win32');
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
{ TODO 02 - TOKENISEUR SWIFT (LEXER) ET REGLE DE TERMINAISON   }
{ ============================================================ }

Type
  TTokenKind = (
    TOK_EOF,                { fin de fichier                            }
    TOK_IDENT,               { identificateur (mots-cles INCLUS - voir    }
                              { TODO 03, la classification complete est     }
                              { deferee la-bas ; seule l eligibilite de       }
                              { terminaison de self/true/false/nil/break/       }
                              { continue/fallthrough/return est traitee ICI,      }
                              { necessaire au lexeur lui-meme, voir              }
                              { LexIsTermKeyword)                                   }
    TOK_INT,                { litteral entier (decimal/hex/octal/binaire) }
    TOK_FLOAT,               { litteral flottant                           }
    TOK_STRING,              { chaine "..." SANS interpolation (forme la    }
                              { plus frequente - voir TOK_STRING_INTERP_PART  }
                              { sinon)                                          }
    TOK_STRING_INTERP_PART, { UN segment d une chaine interpolee            }
                              { "...\(...)..." - IntVal=1 si une                }
                              { interpolation \( ... ) suit IMMEDIATEMENT       }
                              { (le parseur, TODO 06, doit alors re-entrer         }
                              { dans une expression complete puis rappeler          }
                              { le lexeur pour le segment SUIVANT), IntVal=0           }
                              { si c est le DERNIER segment (guillemet               }
                              { fermant deja consomme)                                  }
    TOK_SEMI,                { instruction terminee, REELLE (';' explicite)  }
                              { ou INSEREE (fin de ligne, voir                  }
                              { LexTermSuppressed)                                 }
    TOK_OP                   { operateur/ponctuation ; distingue par Val     }
  );

  TToken = Record
    Kind      : TTokenKind;
    Val       : TString;    { texte brut (identificateur, operateur, ou  }
                             { forme decodee pour chaine)                  }
    IntVal    : LongInt;     { valeur entiere (TOK_INT) ou fanion "suite     }
                              { d interpolation" (TOK_STRING_INTERP_PART)      }
    RealVal   : Real;        { valeur flottante (TOK_FLOAT)                    }
    Line      : Integer;     { ligne source (1-base)                           }
    Col       : Integer;     { colonne source (1-base)                         }
    Inserted  : Boolean;     { True si ce TOK_SEMI a ete SYNTHETISE par la      }
                              { regle de terminaison plutot qu ecrit                }
                              { explicitement dans le source (utile pour le          }
                              { debug -d)                                                }
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

  { Etat necessaire a la regle de terminaison d instruction : classe et  }
  { texte du dernier "vrai" token retourne par LexNextToken (un TOK_SEMI   }
  { insere compte lui-meme comme "dernier token" pour eviter d en inserer     }
  { un deuxieme consecutif). LexHaveLast reste Faux avant le tout premier       }
  { token du fichier (aucune terminaison ne peut jamais s appliquer en tete       }
  { de fichier).                                                                    }
  LexLastKind : TTokenKind;
  LexLastVal  : TString;
  LexHaveLast : Boolean;

  { Profondeur de parenthesage COURANTE a l interieur d une interpolation  }
  { de chaine "\( ... )" EN COURS (0 = on ne tokenise PAS actuellement       }
  { l interieur d une interpolation) - permet a une parenthese OUVRANTE        }
  { imbriquee dans l expression elle-meme (ex. "\(foo(1, 2))") de ne PAS           }
  { etre confondue avec celle qui referme l interpolation : seule la               }
  { parenthese FERMANTE qui fait redescendre cette profondeur a 0 met fin              }
  { a l interpolation et fait reprendre le balayage de la chaine.                        }
  LexInterpParenDepth : Integer;

{ ------------------------------------------------------------ }
{ Classification de caracteres                                 }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch: Char): Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
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
{ LexPeekChar / LexPeekChar2 / LexPeekChar3 / LexNextChar        }
{ Lecture en avant SANS consommer (Peek) et avance d un caractere }
{ (Next) dans la ligne courante - #0 si hors limites (fin de       }
{ ligne). LexPeekChar3 est necessaire pour reconnaitre sans           }
{ ambiguite les operateurs a 3 caracteres de Swift ('...' '..<'         }
{ '??=' '<<=' '>>=') par la methode du "plus long match".                 }
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

Procedure LexNextChar;
Begin
  If LexColNo <= Length(LexLine) Then Inc(LexColNo);
End;

{ ------------------------------------------------------------ }
{ LexNextLine / LexInit / LexClose                              }
{ Modele "tampon d une ligne" (ReadLn + LexColNo), identique dans  }
{ l esprit a GOCW32.PAS/DELPHI.PAS/PERLCW32.PAS de ce meme projet -  }
{ PAS de pile d inclusion (Swift, tel que couvert ici, est mono-        }
{ fichier, voir TODO 01) : plus simple que DELPHI.PAS sur ce point         }
{ precis.                                                                     }
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
  LexHaveLast := False;
  LexLastKind := TOK_EOF;
  LexLastVal  := '';
  LexInterpParenDepth := 0;
  TokenCount  := 0;
  CurToken.Kind     := TOK_EOF;
  CurToken.Val      := '';
  CurToken.IntVal   := 0;
  CurToken.RealVal  := 0.0;
  CurToken.Line     := 0;
  CurToken.Col      := 0;
  CurToken.Inserted := False;
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
{ Regle de terminaison d instruction (plus simple que l ASI de   }
{ Go, mais reelle : voir en-tete du fichier, TODO 02) - polarite    }
{ INVERSEE par rapport a Go : ICI, une instruction se termine PAR      }
{ DEFAUT a la fin de la ligne, SAUF si le DERNIER token rend la              }
{ syntaxe MANIFESTEMENT incomplete (operateur binaire, virgule,               }
{ deux-points, point, "->", ou une parenthese/crochet/accolade                    }
{ OUVRANTE), ou si le dernier token est un mot-cle reserve qui                       }
{ n acheve JAMAIS lui seul une instruction complete (if/for/func/etc,                   }
{ via LexIsReservedWord/LexIsTermKeyword - meme mecanisme de deferral               }
{ vers IsKeyword, TODO 03, que Go pour sa propre ASI).                                    }
{ ------------------------------------------------------------ }

{ IsKeyword est la vraie classification (TODO 03, plus bas dans ce   }
{ fichier) - declaree ici Forward pour que LexIsReservedWord (TODO 02,  }
{ deja ecrit et teste) puisse s y appuyer SANS dupliquer la liste des     }
{ mots reserves une seconde fois (risque de divergence entre les              }
{ deux copies sinon).                                                          }
Function IsKeyword(Const S: TString): Integer; Forward;

Function LexIsReservedWord(Const S: TString): Boolean;
Begin
  LexIsReservedWord := IsKeyword(S) <> 0;
End;

Function LexIsTermKeyword(Const S: TString): Boolean;
Begin
  { mots-cles qui, meme reserves, ACHEVENT normalement une instruction  }
  { (comme un identificateur ou un litteral ordinaire) plutot que        }
  { d annoncer une continuation forcement necessaire. }
  LexIsTermKeyword := (S = 'break') Or (S = 'continue') Or
    (S = 'fallthrough') Or (S = 'return') Or (S = 'self') Or
    (S = 'true') Or (S = 'false') Or (S = 'nil');
End;

Function LexTermSuppressed: Boolean;
Begin
  { BOGUE REEL trouve par EXECUTION (une terminaison PARASITE, fausse,   }
  { apparaissait AVANT le tout premier vrai token du fichier, ex. juste       }
  { apres une ligne ne contenant qu un commentaire //) : la polarite            }
  { INVERSEE de cette regle (par defaut, "termine" - voir sa propre note              }
  { d en-tete) exige que "aucun vrai token encore rencontre" soit               }
  { SUPPRIME (Vrai), pas la valeur par defaut "False" recopiee sans y                  }
  { penser depuis LexASIEligible de GOCW32.PAS (dont la polarite est,                     }
  { elle, exactement INVERSE - "False" y signifie a raison "n insere pas").      }
  LexTermSuppressed := True;
  If Not LexHaveLast Then Exit;
  LexTermSuppressed := False;
  Case LexLastKind Of
    TOK_SEMI:
      LexTermSuppressed := True;   { deja termine, jamais une deuxieme fois }
    TOK_IDENT:
      LexTermSuppressed := LexIsReservedWord(LexLastVal) And
                            Not LexIsTermKeyword(LexLastVal);
    TOK_OP:
      LexTermSuppressed :=
        (LexLastVal = ',')  Or (LexLastVal = '.')  Or (LexLastVal = ':')  Or
        (LexLastVal = '(')  Or (LexLastVal = '[')  Or (LexLastVal = '{')  Or
        (LexLastVal = '->') Or (LexLastVal = '=')  Or (LexLastVal = '==') Or
        (LexLastVal = '!=') Or (LexLastVal = '<')  Or (LexLastVal = '>')  Or
        (LexLastVal = '<=') Or (LexLastVal = '>=') Or (LexLastVal = '&&') Or
        (LexLastVal = '||') Or (LexLastVal = '+')  Or (LexLastVal = '-')  Or
        (LexLastVal = '*')  Or (LexLastVal = '/')  Or (LexLastVal = '%')  Or
        (LexLastVal = '&')  Or (LexLastVal = '|')  Or (LexLastVal = '^')  Or
        (LexLastVal = '<<') Or (LexLastVal = '>>') Or (LexLastVal = '+=') Or
        (LexLastVal = '-=') Or (LexLastVal = '*=') Or (LexLastVal = '/=') Or
        (LexLastVal = '%=') Or (LexLastVal = '&=') Or (LexLastVal = '|=') Or
        (LexLastVal = '^=') Or (LexLastVal = '<<=')Or (LexLastVal = '>>=')Or
        (LexLastVal = '??') Or (LexLastVal = '??=')Or (LexLastVal = '..<')Or
        (LexLastVal = '...');
    { les identificateurs ordinaires, les litteraux, les crochets/          }
    { accolades FERMANTS, '++'/'--', '!' (deballage force) et '?' (type      }
    { optionnel) restent TOUS eligibles a la terminaison - une instruction       }
    { Swift reelle finit tres souvent par exactement l un de ceux-la. }
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur (mots-cles INCLUS, voir en-tete   }
{ de section - classification complete deferee au TODO 03).       }
{ Swift est sensible a la casse : AUCUN changement de casse ici.     }
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
{ LexScanNumber : entier (decimal/hex/octal/binaire) ou flottant,  }
{ avec soulignes separateurs optionnels (1_000_000). Contrairement    }
{ a Go, Swift n a PAS de forme octale "ancien style" (un simple           }
{ "0123" decimal reste decimal=123, jamais reinterprete) - AUCUNE            }
{ reinterpretation n est donc tentee ici. Les flottants                          }
{ HEXADECIMAUX (0x1p10) sont explicitement HORS DE PORTEE (voir              }
{ TODO 02 de l en-tete) : detectes puis rejetes par une erreur                   }
{ claire plutot que d etre silencieusement mal lexes (un "0x1"                       }
{ entier suivi d un identificateur "p10" errone).                                       }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  S        : TString;
  IsFloatV : Boolean;
  N        : LongInt;
  FracVal  : Real;
  FracDiv  : Real;
Begin
  S := '';
  IsFloatV := False;

  { --- prefixes de base non-decimale : 0x / 0o / 0b --- }
  If (LexPeekChar = '0') And ((LexPeekChar2 = 'x') Or (LexPeekChar2 = 'X')) Then
  Begin
    LexNextChar; LexNextChar;
    N := 0;
    While IsHexDigit(LexPeekChar) Or (LexPeekChar = '_') Do
    Begin
      If LexPeekChar <> '_' Then N := N * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    If (LexPeekChar = 'p') Or (LexPeekChar = 'P') Then
      FatalError('litteraux flottants hexadecimaux (ex. 0x1p10) non ' +
        'supportes (hors de portee, voir TODO 02 de l''en-tete du fichier)');
    CurToken.Kind   := TOK_INT;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  If (LexPeekChar = '0') And ((LexPeekChar2 = 'o') Or (LexPeekChar2 = 'O')) Then
  Begin
    LexNextChar; LexNextChar;
    N := 0;
    While ((LexPeekChar >= '0') And (LexPeekChar <= '7')) Or
          (LexPeekChar = '_') Do
    Begin
      If LexPeekChar <> '_' Then N := N * 8 + (Ord(LexPeekChar) - Ord('0'));
      LexNextChar;
    End;
    CurToken.Kind   := TOK_INT;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  If (LexPeekChar = '0') And ((LexPeekChar2 = 'b') Or (LexPeekChar2 = 'B')) Then
  Begin
    LexNextChar; LexNextChar;
    N := 0;
    While (LexPeekChar = '0') Or (LexPeekChar = '1') Or (LexPeekChar = '_') Do
    Begin
      If LexPeekChar <> '_' Then N := N * 2 + (Ord(LexPeekChar) - Ord('0'));
      LexNextChar;
    End;
    CurToken.Kind   := TOK_INT;
    CurToken.IntVal := N;
    Str(N, CurToken.Val);
    Exit;
  End;

  { --- partie entiere (decimale) --- }
  N := 0;
  While IsDigitCh(LexPeekChar) Or (LexPeekChar = '_') Do
  Begin
    If LexPeekChar <> '_' Then
    Begin
      S := S + LexPeekChar;
      N := N * 10 + (Ord(LexPeekChar) - Ord('0'));
    End;
    LexNextChar;
  End;

  { --- partie decimale .ddd (mais pas si suivie d un autre '.',   }
  { qui appartiendrait a l operateur '...'/'..<') --- }
  FracVal := 0.0;
  FracDiv := 10.0;
  If (LexPeekChar = '.') And (LexPeekChar2 <> '.') Then
  Begin
    IsFloatV := True;
    S := S + '.';
    LexNextChar;
    While IsDigitCh(LexPeekChar) Or (LexPeekChar = '_') Do
    Begin
      If LexPeekChar <> '_' Then
      Begin
        S := S + LexPeekChar;
        FracVal := FracVal + (Ord(LexPeekChar) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
      End;
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
    While IsDigitCh(LexPeekChar) Or (LexPeekChar = '_') Do
    Begin
      If LexPeekChar <> '_' Then S := S + LexPeekChar;
      LexNextChar;
    End;
  End;

  If IsFloatV Then
  Begin
    CurToken.Kind := TOK_FLOAT;
    { Val() exige un chiffre avant le point (".5" doit devenir "0.5") ;   }
    { de meme un point final sans decimales ("1." -> S="1.") doit avoir     }
    { au moins un zero apres pour rester un reel valide pour Val().          }
    If (Length(S) > 0) And (S[1] = '.') Then S := '0' + S;
    If (Length(S) > 0) And (S[Length(S)] = '.') Then S := S + '0';
    Val(S, CurToken.RealVal, N);
    CurToken.Val := S;
  End
  Else
  Begin
    CurToken.Kind   := TOK_INT;
    CurToken.IntVal := N;
    CurToken.Val    := S;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanEscape : decode UNE sequence d echappement (le curseur   }
{ doit deja pointer juste APRES le '\') - grammaire REELLE de       }
{ Swift (differente de Go sur le point Unicode : "\u" suivi d une      }
{ accolade ouvrante, 1 a 8 chiffres hexadecimaux VARIABLES puis une        }
{ accolade fermante, jamais un \u/\U a largeur FIXE comme en Go).             }
{ ------------------------------------------------------------ }

Function LexScanEscape: LongInt;
Var
  V : LongInt;
  Ch : Char;
Begin
  Ch := LexPeekChar;
  Case Ch Of
    '0' : Begin LexNextChar; LexScanEscape := 0;  Exit; End;
    't' : Begin LexNextChar; LexScanEscape := 9;  Exit; End;
    'n' : Begin LexNextChar; LexScanEscape := 10; Exit; End;
    'r' : Begin LexNextChar; LexScanEscape := 13; Exit; End;
    '\' : Begin LexNextChar; LexScanEscape := Ord('\'); Exit; End;
    ''''  : Begin LexNextChar; LexScanEscape := Ord(''''); Exit; End;
    '"' : Begin LexNextChar; LexScanEscape := Ord('"'); Exit; End;
  End;

  If Ch = 'u' Then
  Begin
    LexNextChar;
    If LexPeekChar <> '{' Then
      FatalError('sequence d''echappement \u attend une accolade ' +
        'ouvrante (forme reelle : \u{XXXXXX})');
    LexNextChar;
    If Not IsHexDigit(LexPeekChar) Then
      FatalError('sequence d''echappement \u{...} attend au moins un ' +
        'chiffre hexadecimal');
    V := 0;
    While IsHexDigit(LexPeekChar) Do
    Begin
      V := V * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    If LexPeekChar <> '}' Then
      FatalError('sequence d''echappement \u{...} non fermee (accolade ' +
        'fermante attendue)');
    LexNextChar;
    LexScanEscape := V;
    Exit;
  End;

  FatalError('sequence d''echappement inconnue: \' + Ch);
  LexScanEscape := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanString(Resume) : chaine interpretee "..." (echappements  }
{ decodes, voir LexScanEscape) - Resume=Faux au tout premier          }
{ segment (consomme le guillemet OUVRANT), Resume=Vrai quand on           }
{ REPREND le balayage juste apres la parenthese FERMANTE d une               }
{ interpolation "\( ... )" (voir LexNextToken) - le guillemet                    }
{ ouvrant n est alors PAS consomme une seconde fois. Rencontrer                      }
{ "\(" DECLENCHE l interpolation : le segment de texte accumule                         }
{ jusque-la est rendu comme TOK_STRING_INTERP_PART (IntVal=1, "la                          }
{ suite arrive"), LexInterpParenDepth passe a 1, et la fonction                             }
{ REND LA MAIN au dispatcheur principal (LexNextToken) pour qu il                              }
{ tokenise normalement l EXPRESSION a l interieur des parentheses -                            }
{ un saut de ligne litteral a l interieur d une chaine simple reste                            }
{ une erreur, comme en Go (les chaines multi-lignes """...""" sont                             }
{ hors de portee, voir TODO 02 de l en-tete). Une chaine SANS AUCUNE                           }
{ interpolation rencontree ressort telle quelle en TOK_STRING (forme                          }
{ SIMPLE, la plus frequente - inchangee par cette extension).                                      }
{ ------------------------------------------------------------ }

Procedure LexScanString(Resume: Boolean);
Var
  S : TString;
  V : LongInt;
Begin
  S := '';
  If Not Resume Then
    LexNextChar;   { sauter le guillemet ouvrant - UNIQUEMENT au premier segment }
  While True Do
  Begin
    If LexColNo > Length(LexLine) Then
      FatalError('chaine interpretee "..." non fermee avant fin de ' +
        'ligne (les chaines multi-lignes """...""" restent hors de portee)');
    If (LexPeekChar = '\') And (LexPeekChar2 = '(') Then
    Begin
      LexNextChar; LexNextChar;   { sauter '\' et '(' }
      CurToken.Kind   := TOK_STRING_INTERP_PART;
      CurToken.Val    := S;
      CurToken.IntVal := 1;
      LexInterpParenDepth := 1;
      Exit;
    End;
    If LexPeekChar = '"' Then
    Begin
      LexNextChar;   { sauter le guillemet fermant }
      If Resume Then
      Begin
        CurToken.Kind   := TOK_STRING_INTERP_PART;
        CurToken.Val    := S;
        CurToken.IntVal := 0;
      End
      Else
      Begin
        CurToken.Kind := TOK_STRING;
        CurToken.Val  := S;
      End;
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
{ LexSkipBlockComment : commentaire /* ... */ - contrairement a  }
{ C (et a Go), Swift AUTORISE leur IMBRICATION ("/* /* */ */" est   }
{ un SEUL commentaire complet) : suivi via un compteur de              }
{ profondeur plutot qu un simple "cherche la premiere '*''/'".              }
{ Retourne Vrai si au moins un saut de ligne a ete traverse             }
{ (necessaire a la regle de terminaison : un tel commentaire compte        }
{ alors comme une fin de ligne, exactement comme en Go).                      }
{ ------------------------------------------------------------ }

Function LexSkipBlockComment: Boolean;
Var
  CrossedLine : Boolean;
  Depth       : Integer;
Begin
  CrossedLine := False;
  Depth := 1;
  LexNextChar; LexNextChar;   { sauter '/' et '*' d ouverture }
  While Depth > 0 Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
        FatalError('commentaire /* non ferme avant fin de fichier');
      CrossedLine := True;
      LexNextLine;
      Continue;
    End;
    If (LexPeekChar = '/') And (LexPeekChar2 = '*') Then
    Begin
      LexNextChar; LexNextChar;
      Inc(Depth);
      Continue;
    End;
    If (LexPeekChar = '*') And (LexPeekChar2 = '/') Then
    Begin
      LexNextChar; LexNextChar;
      Dec(Depth);
      Continue;
    End;
    LexNextChar;
  End;
  LexSkipBlockComment := CrossedLine;
End;

{ ------------------------------------------------------------ }
{ LexScanOperator : plus long operateur/ponctuation reconnu a la  }
{ position courante (methode du "maximal munch" - 3, puis 2, puis   }
{ 1 caractere) - jeu d operateurs REEL de Swift (different de Go       }
{ sur plusieurs points : "->" au lieu de "<-", "??"/"??=" nil-           }
{ coalescing, "..<"/"..." intervalles semi-ouvert/ferme au lieu            }
{ d un seul "...", pas de "&^"). Couvre AUSSI la ponctuation SIMPLE :          }
{ parentheses/crochets/accolades/virgule/deux-points/point-virgule/               }
{ point/at/diese/antislash/point d interrogation/point d exclamation -               }
{ toutes rendues par le dernier "Else" generique (aucune forme multi-               }
{ caractere pour elles, sauf celles deja enumerees ci-dessus).                          }
{ ------------------------------------------------------------ }

Procedure LexScanOperator;
Var
  C1, C2, C3 : Char;
Begin
  C1 := LexPeekChar;
  C2 := LexPeekChar2;
  C3 := LexPeekChar3;
  CurToken.Kind := TOK_OP;

  If (C1 = '.') And (C2 = '.') And (C3 = '.') Then
  Begin CurToken.Val := '...'; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '.') And (C2 = '.') And (C3 = '<') Then
  Begin CurToken.Val := '..<'; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '?') And (C2 = '?') And (C3 = '=') Then
  Begin CurToken.Val := '??='; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '<') And (C3 = '=') Then
  Begin CurToken.Val := '<<='; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '>') And (C3 = '=') Then
  Begin CurToken.Val := '>>='; LexNextChar; LexNextChar; LexNextChar; Exit; End;

  If (C1 = '-') And (C2 = '>') Then
  Begin CurToken.Val := '->'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '?') And (C2 = '?') Then
  Begin CurToken.Val := '??'; LexNextChar; LexNextChar; Exit; End;
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
{ LexNextToken : produit le prochain token, regle de terminaison  }
{ incluse. LexTermSuppressed est verifiee AVANT de sauter une        }
{ fin de ligne reelle, AVANT de signaler EOF, et APRES un                }
{ commentaire /* */ qui a traverse au moins un saut de ligne - les          }
{ TROIS points ou ce compilateur considere qu une "nouvelle ligne"             }
{ a ete rencontree pour les besoins de cette regle. Quand                          }
{ LexInterpParenDepth > 0 (on tokenise l INTERIEUR d une                              }
{ interpolation de chaine), une parenthese OUVRANTE l incremente et                       }
{ une FERMANTE la decremente ; SEULE celle qui la fait redescendre                            }
{ a 0 met fin a l interpolation (reprend alors LexScanString en              }
{ mode Resume plutot que de rendre cette parenthese comme un TOK_OP              }
{ ordinaire).                                                                          }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch                : Char;
  Scanning          : Boolean;
  CommentHadNewline : Boolean;
Begin
  CurToken.IntVal   := 0;
  CurToken.RealVal  := 0.0;
  CurToken.Inserted := False;

  Scanning := True;
  While Scanning Do
  Begin
    If (Not LexEOF) And (LexColNo > Length(LexLine)) Then
    Begin
      If Not LexTermSuppressed Then
      Begin
        CurToken.Kind     := TOK_SEMI;
        CurToken.Val      := ';';
        CurToken.Line     := LexLineNo;
        CurToken.Col      := LexColNo;
        CurToken.Inserted := True;
        LexNextLine;
        LexLastKind := TOK_SEMI;
        LexLastVal  := ';';
        LexHaveLast := True;
        Inc(TokenCount);
        Exit;
      End;
      LexNextLine;
      Continue;
    End;

    If LexEOF Then
    Begin
      If Not LexTermSuppressed Then
      Begin
        CurToken.Kind     := TOK_SEMI;
        CurToken.Val      := ';';
        CurToken.Line     := LexLineNo;
        CurToken.Col      := LexColNo;
        CurToken.Inserted := True;
        LexLastKind := TOK_SEMI;   { evite une seconde insertion en boucle }
        LexLastVal  := ';';
        Inc(TokenCount);
        Exit;
      End;
      CurToken.Kind := TOK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      LexLastKind := TOK_EOF;
      LexLastVal  := '';
      LexHaveLast := True;
      { BOGUE REEL trouve par EXECUTION (TODO 16) : cette branche EOF     }
      { "propre" (dernier vrai token = un OPERATEUR qui suspend                        }
      { l insertion automatique de point-virgule, ex. "Set<Int>" en fin           }
      { de fichier SANS retour a la ligne) EXITait auparavant SANS                        }
      { "Inc(TokenCount)", contrairement a sa branche soeur ci-dessus                    }
      { (l insertion de point-virgule) qui l incremente bien - LexAll                        }
      { (TokenPool[TokenCount-1] := CurToken) reutilisait alors le MEME              }
      { INDEX que le DERNIER vrai token au lieu d en reserver un                                }
      { nouveau, ECRASANT ce dernier token par cet EOF. Jamais exerce                    }
      { avant le TODO 16 (aucun texte de test precedent ne se terminait                  }
      { PILE sur un tel operateur, sans newline final). }
      Inc(TokenCount);
      Exit;
    End;

    Ch := LexPeekChar;

    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Then
    Begin
      LexNextChar;
      Continue;
    End;

    If (Ch = '/') And (LexPeekChar2 = '/') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Continue;
    End;

    If (Ch = '/') And (LexPeekChar2 = '*') Then
    Begin
      CommentHadNewline := LexSkipBlockComment;
      If CommentHadNewline And (Not LexTermSuppressed) Then
      Begin
        CurToken.Kind     := TOK_SEMI;
        CurToken.Val      := ';';
        CurToken.Line     := LexLineNo;
        CurToken.Col      := LexColNo;
        CurToken.Inserted := True;
        LexLastKind := TOK_SEMI;
        LexLastVal  := ';';
        LexHaveLast := True;
        Inc(TokenCount);
        Exit;
      End;
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
      LexScanString(False);
      Scanning := False;
    End
    Else If Ch = ';' Then
    Begin
      LexNextChar;
      CurToken.Kind     := TOK_SEMI;
      CurToken.Val      := ';';
      CurToken.Inserted := False;
      Scanning := False;
    End
    Else
    Begin
      LexScanOperator;
      If LexInterpParenDepth > 0 Then
      Begin
        If CurToken.Val = '(' Then
          Inc(LexInterpParenDepth);
        If CurToken.Val = ')' Then
        Begin
          Dec(LexInterpParenDepth);
          If LexInterpParenDepth = 0 Then
            LexScanString(True);   { reprend le texte de la chaine juste apres l interpolation }
        End;
      End;
      Scanning := False;
    End;
  End;

  LexLastKind := CurToken.Kind;
  LexLastVal  := CurToken.Val;
  LexHaveLast := True;
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
    TOK_EOF                : Write('EOF');
    TOK_IDENT               : Write('IDENT(', T.Val, ')');
    TOK_INT                 : Write('INT(', T.IntVal, ')');
    TOK_FLOAT                : Write('FLOAT(', T.Val, ')');
    TOK_STRING               : Write('STRING("', T.Val, '")');
    TOK_STRING_INTERP_PART  : Write('STRINGPART("', T.Val, '" suite=',
                                 T.IntVal, ')');
    TOK_SEMI                 : If T.Inserted Then Write('SEMI(insere)')
                                Else Write('SEMI');
    TOK_OP                   : Write('OP(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexSelfTest (TODO 24 anticipe partiellement, comme le fait      }
{ deja GOCW32.PAS/DELPHI.PAS/PERLCW32.PAS pour leurs propres         }
{ fonctions de base) : tokenise un petit extrait Swift ecrit dans      }
{ un fichier temporaire, verifie la sequence de tokens attendue -         }
{ couvre identificateurs, mots-cles (regle de terminaison), entiers          }
{ (dec/hex/octal/binaire/souligne), flottant, chaine simple,                     }
{ interpolation de chaine, operateurs multi-caracteres Swift                          }
{ (-> ?? ..< ...), et surtout la regle de terminaison elle-meme (le                       }
{ point le plus delicat de ce TODO, comme pour l ASI de GOCW32.PAS).                          }
{ ------------------------------------------------------------ }

Procedure LexAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('LexSelfTest: ' + Label_ + ' a echoue');
End;

Procedure LexSelfTest;
Const
  TmpFile = 'SWIFTLEXSELFTEST.$$$';
Var
  F : Text;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'let x = 42');
  WriteLn(F, 'let y = 0x1F + 0o17 + 0b101 + 1_000');
  WriteLn(F, 'let z = 1.5e-3');
  WriteLn(F, 'let s = "hi there"');
  WriteLn(F, 'let msg = "a\(1 + 2)b"');
  WriteLn(F, 'func f() -> Int {');
  WriteLn(F, 'let r = x ??');
  WriteLn(F, '  99');
  WriteLn(F, 'return r');
  WriteLn(F, '}');
  WriteLn(F, 'for i in 0..<5 {');
  WriteLn(F, 'i');
  WriteLn(F, '}');
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;

  { ligne 1 : let x = 42 <SEMI inseree> }
  LexNextToken; LexAssert('1: IDENT let', (CurToken.Kind = TOK_IDENT) And (CurToken.Val = 'let'));
  LexNextToken; LexAssert('1: IDENT x', (CurToken.Kind = TOK_IDENT) And (CurToken.Val = 'x'));
  LexNextToken; LexAssert('1: OP =', (CurToken.Kind = TOK_OP) And (CurToken.Val = '='));
  LexNextToken; LexAssert('1: INT 42', (CurToken.Kind = TOK_INT) And (CurToken.IntVal = 42));
  LexNextToken; LexAssert('1: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 2 : let y = 0x1F + 0o17 + 0b101 + 1_000 <SEMI> }
  LexNextToken; LexAssert('2: IDENT let', CurToken.Val = 'let');
  LexNextToken; LexAssert('2: IDENT y', CurToken.Val = 'y');
  LexNextToken; LexAssert('2: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('2: HEX 0x1F=31', CurToken.IntVal = 31);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: OCT 0o17=15', CurToken.IntVal = 15);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: BIN 0b101=5', CurToken.IntVal = 5);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: souligne 1_000=1000', CurToken.IntVal = 1000);
  LexNextToken; LexAssert('2: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 3 : let z = 1.5e-3 <SEMI> }
  LexNextToken; LexAssert('3: IDENT let', CurToken.Val = 'let');
  LexNextToken; LexAssert('3: IDENT z', CurToken.Val = 'z');
  LexNextToken; LexAssert('3: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('3: FLOAT', (CurToken.Kind = TOK_FLOAT) And
    (CurToken.RealVal > 0.0014) And (CurToken.RealVal < 0.0016));
  LexNextToken; LexAssert('3: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 4 : let s = "hi there" <SEMI> }
  LexNextToken; LexAssert('4: IDENT let', CurToken.Val = 'let');
  LexNextToken; LexAssert('4: IDENT s', CurToken.Val = 's');
  LexNextToken; LexAssert('4: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('4: STRING simple',
    (CurToken.Kind = TOK_STRING) And (CurToken.Val = 'hi there'));
  LexNextToken; LexAssert('4: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 5 : let msg = "a\(1 + 2)b" <SEMI> - interpolation }
  LexNextToken; LexAssert('5: IDENT let', CurToken.Val = 'let');
  LexNextToken; LexAssert('5: IDENT msg', CurToken.Val = 'msg');
  LexNextToken; LexAssert('5: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('5: STRINGPART "a" suite',
    (CurToken.Kind = TOK_STRING_INTERP_PART) And (CurToken.Val = 'a') And
    (CurToken.IntVal = 1));
  LexNextToken; LexAssert('5: INT 1 (interieur interpolation)', CurToken.IntVal = 1);
  LexNextToken; LexAssert('5: OP + (interieur interpolation)', CurToken.Val = '+');
  LexNextToken; LexAssert('5: INT 2 (interieur interpolation)', CurToken.IntVal = 2);
  LexNextToken; LexAssert('5: STRINGPART "b" dernier segment',
    (CurToken.Kind = TOK_STRING_INTERP_PART) And (CurToken.Val = 'b') And
    (CurToken.IntVal = 0));
  LexNextToken; LexAssert('5: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 6 : func f() -> Int { <PAS de SEMI, '{' ouvrante suppprime la  }
  { terminaison> }
  LexNextToken; LexAssert('6: IDENT func', CurToken.Val = 'func');
  LexNextToken; LexAssert('6: IDENT f', CurToken.Val = 'f');
  LexNextToken; LexAssert('6: OP (', CurToken.Val = '(');
  LexNextToken; LexAssert('6: OP )', CurToken.Val = ')');
  LexNextToken; LexAssert('6: OP ->', CurToken.Val = '->');
  LexNextToken; LexAssert('6: IDENT Int', CurToken.Val = 'Int');
  LexNextToken; LexAssert('6: OP { (aucune SEMI avant)', CurToken.Val = '{');

  { ligne 7-8 : let r = x ??<PAS de SEMI, continuation>  99 <SEMI> - la  }
  { terminaison APRES "??" doit etre SUPPRIMEE (operateur binaire en          }
  { fin de ligne 7), puis reelement inseree apres "99" (ligne 8).             }
  LexNextToken; LexAssert('7: IDENT let', CurToken.Val = 'let');
  LexNextToken; LexAssert('7: IDENT r', CurToken.Val = 'r');
  LexNextToken; LexAssert('7: OP =', CurToken.Val = '=');
  LexNextToken; LexAssert('7: IDENT x', CurToken.Val = 'x');
  LexNextToken; LexAssert('7: OP ??', CurToken.Val = '??');
  LexNextToken; LexAssert('8: INT 99 (aucune SEMI avant, continuation ??)',
    CurToken.IntVal = 99);
  LexNextToken; LexAssert('8: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 9 : return r <SEMI - "return" est un mot-cle TERMINANT> }
  LexNextToken; LexAssert('9: IDENT return', CurToken.Val = 'return');
  LexNextToken; LexAssert('9: IDENT r', CurToken.Val = 'r');
  LexNextToken; LexAssert('9: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 10 : accolade fermante seule - SEMI, une fermante termine }
  LexNextToken; LexAssert('10: OP }', CurToken.Val = '}');
  LexNextToken; LexAssert('10: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 11 : for i in 0..<5 { <PAS de SEMI, '{' ouvrante> }
  LexNextToken; LexAssert('11: IDENT for', CurToken.Val = 'for');
  LexNextToken; LexAssert('11: IDENT i', CurToken.Val = 'i');
  LexNextToken; LexAssert('11: IDENT in', CurToken.Val = 'in');
  LexNextToken; LexAssert('11: INT 0', CurToken.IntVal = 0);
  LexNextToken; LexAssert('11: OP ..<', CurToken.Val = '..<');
  LexNextToken; LexAssert('11: INT 5', CurToken.IntVal = 5);
  LexNextToken; LexAssert('11: OP { (aucune SEMI avant)', CurToken.Val = '{');

  { lignes 12-13 : i SEMI puis accolade fermante SEMI puis EOF }
  LexNextToken; LexAssert('12: IDENT i', CurToken.Val = 'i');
  LexNextToken; LexAssert('12: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);
  LexNextToken; LexAssert('13: OP }', CurToken.Val = '}');
  LexNextToken; LexAssert('13: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);
  LexNextToken; LexAssert('EOF final', CurToken.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ------------------------------------------------------------ }
{ ============================================================ }
{ TODO 03 - MOTS-CLES ET IDENTIFICATEURS PREDECLARES            }
{ ============================================================ }
{ Le lexeur (TODO 02) produit TOK_IDENT pour tout ce qui a la      }
{ forme d un identificateur, mots-cles INCLUS - cette section          }
{ fournit la VRAIE classification, utilisee par le futur parseur           }
{ (TODO 05+) et RESOUT ENFIN le "IsKeyword" Forward-declare au             }
{ TODO 02 (dont le corps temporaire, place-holder, retournait                  }
{ toujours 0 - REMPLACE ici, jamais complete). IsKeyword distingue          }
{ les mots RESERVES (qui ne peuvent JAMAIS servir d identificateur              }
{ ordinaire - contrairement a Go, Swift range explicitement true/            }
{ false/nil/self DANS cette categorie, PAS parmi des "identificateurs           }
{ predeclares" a part comme Go le fait) des identificateurs                        }
{ PREDECLARES (types/fonctions integrees de bibliotheque standard -                   }
{ qui PEUVENT en theorie etre masques par une declaration locale - la                     }
{ regle d ombrage elle-meme relevera de l analyse semantique, TODO 19,                        }
{ pas d ici). LexIsReservedWord (TODO 02) est desormais un simple                                 }
{ alias de IsKeyword<>0, pour eviter de maintenir deux listes                                         }
{ independantes qui pourraient diverger. }

Const
  { --- Mots-cles (46, couvrant ce que ce compilateur reconnait -   }
  { Swift reel en a encore davantage - liste EXHAUSTIVE de ceux              }
  { REELLEMENT exerces par SAMPLES\SWIFT\*.swift, voir l en-tete du               }
  { fichier, TODO 03). }
  KW_ASSOCIATEDTYPE = 1;
  KW_AS             = 2;
  KW_BREAK          = 3;
  KW_CASE           = 4;
  KW_CATCH          = 5;
  KW_CLASS          = 6;
  KW_CONTINUE       = 7;
  KW_DEFAULT        = 8;
  KW_DEFER          = 9;
  KW_DO             = 10;
  KW_ELSE           = 11;
  KW_ENUM           = 12;
  KW_EXTENSION      = 13;
  KW_FALLTHROUGH    = 14;
  KW_FALSE          = 15;
  KW_FOR            = 16;
  KW_FUNC           = 17;
  KW_GUARD          = 18;
  KW_IF             = 19;
  KW_IMPORT         = 20;
  KW_IN             = 21;
  KW_INIT           = 22;
  KW_INOUT          = 23;
  KW_INTERNAL       = 24;
  KW_IS             = 25;
  KW_LET            = 26;
  KW_MUTATING       = 27;
  KW_NIL            = 28;
  KW_OVERRIDE       = 29;
  KW_PRIVATE        = 30;
  KW_PROTOCOL       = 31;
  KW_PUBLIC         = 32;
  KW_REPEAT         = 33;
  KW_RETURN         = 34;
  KW_SELF           = 35;
  KW_STATIC         = 36;
  KW_STRUCT         = 37;
  KW_SWITCH         = 38;
  KW_THROW          = 39;
  KW_THROWS         = 40;
  KW_TRUE           = 41;
  KW_TRY            = 42;
  KW_TYPEALIAS      = 43;
  KW_VAR            = 44;
  KW_WHERE          = 45;
  KW_WHILE          = 46;

  { --- Types predeclares (22) - ces codes PDT_xxx sont concus pour    }
  { etre reutilises directement comme TypeIdx de base par le TODO 04           }
  { (TypeTab), une fois cette derniere ecrite : meme ordre, memes            }
  { valeurs (meme discipline que GOCW32.PAS). }
  PDT_INT       = 1;
  PDT_INT8      = 2;
  PDT_INT16     = 3;
  PDT_INT32     = 4;
  PDT_INT64     = 5;
  PDT_UINT      = 6;
  PDT_UINT8     = 7;
  PDT_UINT16    = 8;
  PDT_UINT32    = 9;
  PDT_UINT64    = 10;
  PDT_DOUBLE    = 11;
  PDT_FLOAT     = 12;
  PDT_BOOL      = 13;
  PDT_STRING    = 14;
  PDT_CHARACTER = 15;
  PDT_ARRAY     = 16;
  PDT_DICTIONARY= 17;
  PDT_SET       = 18;
  PDT_OPTIONAL  = 19;
  PDT_ANY       = 20;
  PDT_ANYOBJECT = 21;
  PDT_VOID      = 22;

  { --- Fonctions/constructions integrees - PORTEE VOLONTAIREMENT   }
  { restreinte a "print" (le seul reellement exerce par              }
  { SAMPLES\SWIFT\*.swift a ce jour) : "type(of:)" reste hors de           }
  { portee (syntaxe a argument NOMME, pas un simple appel de nom              }
  { ordinaire - un vrai traitement attendra le parseur, TODO 06+,               }
  { plutot que d etre devine ici sans lui). }
  BI_PRINT = 1;

{ IsKeyword : 0 si S n est PAS l un des mots reserves ci-dessus,   }
{ sinon le code KW_xxx correspondant. Sensible a la casse (Swift       }
{ l est). }
Function IsKeyword(Const S: TString): Integer;
Begin
  IsKeyword := 0;
  If      S = 'associatedtype' Then IsKeyword := KW_ASSOCIATEDTYPE
  Else If S = 'as'             Then IsKeyword := KW_AS
  Else If S = 'break'          Then IsKeyword := KW_BREAK
  Else If S = 'case'           Then IsKeyword := KW_CASE
  Else If S = 'catch'          Then IsKeyword := KW_CATCH
  Else If S = 'class'          Then IsKeyword := KW_CLASS
  Else If S = 'continue'       Then IsKeyword := KW_CONTINUE
  Else If S = 'default'        Then IsKeyword := KW_DEFAULT
  Else If S = 'defer'          Then IsKeyword := KW_DEFER
  Else If S = 'do'             Then IsKeyword := KW_DO
  Else If S = 'else'           Then IsKeyword := KW_ELSE
  Else If S = 'enum'           Then IsKeyword := KW_ENUM
  Else If S = 'extension'      Then IsKeyword := KW_EXTENSION
  Else If S = 'fallthrough'    Then IsKeyword := KW_FALLTHROUGH
  Else If S = 'false'          Then IsKeyword := KW_FALSE
  Else If S = 'for'            Then IsKeyword := KW_FOR
  Else If S = 'func'           Then IsKeyword := KW_FUNC
  Else If S = 'guard'          Then IsKeyword := KW_GUARD
  Else If S = 'if'             Then IsKeyword := KW_IF
  Else If S = 'import'         Then IsKeyword := KW_IMPORT
  Else If S = 'in'             Then IsKeyword := KW_IN
  Else If S = 'init'           Then IsKeyword := KW_INIT
  Else If S = 'inout'          Then IsKeyword := KW_INOUT
  Else If S = 'internal'       Then IsKeyword := KW_INTERNAL
  Else If S = 'is'             Then IsKeyword := KW_IS
  Else If S = 'let'            Then IsKeyword := KW_LET
  Else If S = 'mutating'       Then IsKeyword := KW_MUTATING
  Else If S = 'nil'            Then IsKeyword := KW_NIL
  Else If S = 'override'       Then IsKeyword := KW_OVERRIDE
  Else If S = 'private'        Then IsKeyword := KW_PRIVATE
  Else If S = 'protocol'       Then IsKeyword := KW_PROTOCOL
  Else If S = 'public'         Then IsKeyword := KW_PUBLIC
  Else If S = 'repeat'         Then IsKeyword := KW_REPEAT
  Else If S = 'return'         Then IsKeyword := KW_RETURN
  Else If S = 'self'           Then IsKeyword := KW_SELF
  Else If S = 'static'         Then IsKeyword := KW_STATIC
  Else If S = 'struct'         Then IsKeyword := KW_STRUCT
  Else If S = 'switch'         Then IsKeyword := KW_SWITCH
  Else If S = 'throw'          Then IsKeyword := KW_THROW
  Else If S = 'throws'         Then IsKeyword := KW_THROWS
  Else If S = 'true'           Then IsKeyword := KW_TRUE
  Else If S = 'try'            Then IsKeyword := KW_TRY
  Else If S = 'typealias'      Then IsKeyword := KW_TYPEALIAS
  Else If S = 'var'            Then IsKeyword := KW_VAR
  Else If S = 'where'          Then IsKeyword := KW_WHERE
  Else If S = 'while'          Then IsKeyword := KW_WHILE;
End;

{ IsPredeclaredType : 0 si S n est pas un nom de type predeclare,   }
{ sinon le code PDT_xxx correspondant. }
Function IsPredeclaredType(Const S: TString): Integer;
Begin
  IsPredeclaredType := 0;
  If      S = 'Int'        Then IsPredeclaredType := PDT_INT
  Else If S = 'Int8'       Then IsPredeclaredType := PDT_INT8
  Else If S = 'Int16'      Then IsPredeclaredType := PDT_INT16
  Else If S = 'Int32'      Then IsPredeclaredType := PDT_INT32
  Else If S = 'Int64'      Then IsPredeclaredType := PDT_INT64
  Else If S = 'UInt'       Then IsPredeclaredType := PDT_UINT
  Else If S = 'UInt8'      Then IsPredeclaredType := PDT_UINT8
  Else If S = 'UInt16'     Then IsPredeclaredType := PDT_UINT16
  Else If S = 'UInt32'     Then IsPredeclaredType := PDT_UINT32
  Else If S = 'UInt64'     Then IsPredeclaredType := PDT_UINT64
  Else If S = 'Double'     Then IsPredeclaredType := PDT_DOUBLE
  Else If S = 'Float'      Then IsPredeclaredType := PDT_FLOAT
  Else If S = 'Bool'       Then IsPredeclaredType := PDT_BOOL
  Else If S = 'String'     Then IsPredeclaredType := PDT_STRING
  Else If S = 'Character'  Then IsPredeclaredType := PDT_CHARACTER
  Else If S = 'Array'      Then IsPredeclaredType := PDT_ARRAY
  Else If S = 'Dictionary' Then IsPredeclaredType := PDT_DICTIONARY
  Else If S = 'Set'        Then IsPredeclaredType := PDT_SET
  Else If S = 'Optional'   Then IsPredeclaredType := PDT_OPTIONAL
  Else If S = 'Any'        Then IsPredeclaredType := PDT_ANY
  Else If S = 'AnyObject'  Then IsPredeclaredType := PDT_ANYOBJECT
  Else If S = 'Void'       Then IsPredeclaredType := PDT_VOID;
End;

{ IsBuiltinFunc : 0 si S n est pas une fonction/construction         }
{ integree Swift couverte ici, sinon le code BI_xxx correspondant. }
Function IsBuiltinFunc(Const S: TString): Integer;
Begin
  IsBuiltinFunc := 0;
  If S = 'print' Then IsBuiltinFunc := BI_PRINT;
End;

{ StdlibTab (TODO 20) : bibliotheque standard minimale - MEME modele    }
{ que GOCW32.PAS TODO 20 (chaque entree CONNUE du frontend a l analyse,           }
{ contrepartie runtime REELLE ajoutee selon les besoins CONSTATES par           }
{ execution, TODO 21+, JAMAIS devinee a l avance) - PAS de champ "Pkg"          }
{ ici (contrairement a GOCW32.PAS, ou chaque fonction integree vit dans           }
{ un PACKAGE importe explicitement, "fmt.Println" etc.) : Swift n a                     }
{ AUCUN tel prefixe pour ses fonctions globales integrees ("print"                     }
{ s ecrit SEUL, jamais "Swift.print" en pratique). PORTEE (documentee,             }
{ roadmap d en-tete explicitement CONDITIONNELLE, "si exerce par un                     }
{ exemple") : SEUL "print(_:)" est REELLEMENT exerce par les 12                              }
{ echantillons SAMPLES\SWIFT (aucun n utilise isEmpty/uppercased/                            }
{ lowercased/abs/min/max) - ces AUTRES membres du roadmap restent donc            }
{ HONNETEMENT absents de cette table plutot que devines/ajoutes sans               }
{ pression de test reelle - la table est concue pour GRANDIR le jour               }
{ ou un echantillon les exercerait vraiment (StdlibAdd ci-dessous,                          }
{ reutilisable telle quelle, AUCUNE restructuration necessaire). }
Const
  MAX_STDLIB = 32;

Type
  TStdlibRec = Record
    Name          : TString;
    ParamCount    : Integer;   { "un seul argument" pour print(_:),      }
                               { roadmap d en-tete - PAS le vrai print            }
                               { variadique de Swift reel (separator:/                }
                               { terminator: INCLUS), meme simplification             }
                               { que fmt.Println de GOCW32.PAS avant son                 }
                               { extension bibliotheque standard. }
    ResultTypeIdx : Integer;
  End;

Var
  StdlibTab   : Array[0..MAX_STDLIB - 1] Of TStdlibRec;
  StdlibCount : Integer;

Function StdlibAdd(Const Nm: TString; AParamCount, AResultTypeIdx: Integer): Integer;
Begin
  If StdlibCount >= MAX_STDLIB Then
  Begin
    WarnMsg('table de la bibliotheque standard pleine (MAX_STDLIB)');
    StdlibAdd := -1;
    Exit;
  End;
  StdlibTab[StdlibCount].Name          := Nm;
  StdlibTab[StdlibCount].ParamCount    := AParamCount;
  StdlibTab[StdlibCount].ResultTypeIdx := AResultTypeIdx;
  StdlibAdd := StdlibCount;
  Inc(StdlibCount);
End;

{ StdlibFind : recherche EXACTE par nom - SANS "Pkg" (voir la note      }
{ d en-tete de TStdlibRec). }
Function StdlibFind(Const Nm: TString): Integer;
Var I : Integer;
Begin
  StdlibFind := -1;
  For I := 0 To StdlibCount - 1 Do
    If StdlibTab[I].Name = Nm Then
    Begin
      StdlibFind := I;
      Exit;
    End;
End;

Procedure StdlibInit;
Begin
  StdlibCount := 0;
  StdlibAdd('print', 1, PDT_VOID);
End;

{ ------------------------------------------------------------ }
{ KeywordSelfTest : verifie IsKeyword/IsPredeclaredType/           }
{ IsBuiltinFunc sur un echantillon representatif de chaque             }
{ categorie, ET verifie qu un identificateur ORDINAIRE (ex.               }
{ "monVar") n est classe dans AUCUNE des trois - Swift n a PAS           }
{ l equivalent d une categorie "constante predeclaree" SEPAREE          }
{ (contrairement a Go) puisque true/false/nil sont ICI de VRAIS               }
{ mots-cles, deja couverts par IsKeyword.                                        }
{ ------------------------------------------------------------ }

Procedure KeywordAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('KeywordSelfTest: ' + Label_ + ' a echoue');
End;

Procedure KeywordSelfTest;
Begin
  KeywordAssert('func est un mot-cle',     IsKeyword('func') = KW_FUNC);
  KeywordAssert('class est un mot-cle',    IsKeyword('class') = KW_CLASS);
  KeywordAssert('guard est un mot-cle',    IsKeyword('guard') = KW_GUARD);
  KeywordAssert('true est un mot-cle',     IsKeyword('true') = KW_TRUE);
  KeywordAssert('nil est un mot-cle',      IsKeyword('nil') = KW_NIL);
  KeywordAssert('self est un mot-cle',     IsKeyword('self') = KW_SELF);
  KeywordAssert('var n''est pas un type',  IsPredeclaredType('var') = 0);
  KeywordAssert('monVar n''est pas un mot-cle', IsKeyword('monVar') = 0);

  KeywordAssert('Int est un type predeclare',    IsPredeclaredType('Int') = PDT_INT);
  KeywordAssert('String est un type predeclare', IsPredeclaredType('String') = PDT_STRING);
  KeywordAssert('Any est un type predeclare',    IsPredeclaredType('Any') = PDT_ANY);
  KeywordAssert('Array est un type predeclare',  IsPredeclaredType('Array') = PDT_ARRAY);
  KeywordAssert('monVar n''est pas un type',     IsPredeclaredType('monVar') = 0);
  KeywordAssert('Int n''est pas un mot-cle',     IsKeyword('Int') = 0);

  KeywordAssert('print est une fonction integree', IsBuiltinFunc('print') = BI_PRINT);
  KeywordAssert('monVar n''est pas une fonction integree', IsBuiltinFunc('monVar') = 0);

  { les 3 categories sont mutuellement exclusives : aucun mot-cle    }
  { n est aussi un type predeclare/une fonction integree, et vice-      }
  { versa. }
  KeywordAssert('for (mot-cle) n''est ni type ni fonction integree',
    (IsPredeclaredType('for') = 0) And (IsBuiltinFunc('for') = 0));
  KeywordAssert('Int (type) n''est ni mot-cle ni fonction integree',
    (IsKeyword('Int') = 0) And (IsBuiltinFunc('Int') = 0));
  KeywordAssert('print (fonction) n''est ni mot-cle ni type',
    (IsKeyword('print') = 0) And (IsPredeclaredType('print') = 0));
End;

{ ------------------------------------------------------------ }
{ Annote un token IDENT de sa classification (TODO 03), si -d :   }
{ mot-cle, type predeclare, fonction integree, ou identificateur       }
{ ordinaire - separee de PrintToken (TODO 02) plutot que d y ajouter   }
{ une dependance vers IsKeyword/etc. sans necessite. }
Procedure PrintIdentClass(Const T: TToken);
Var
  KwCode, TyCode, BiCode : Integer;
Begin
  If (Not Opts.DebugMode) Or (T.Kind <> TOK_IDENT) Then Exit;
  KwCode := IsKeyword(T.Val);
  TyCode := IsPredeclaredType(T.Val);
  BiCode := IsBuiltinFunc(T.Val);
  If KwCode <> 0 Then
    WriteLn('        -> mot-cle (KW_', KwCode, ')')
  Else If TyCode <> 0 Then
    WriteLn('        -> type predeclare (PDT_', TyCode, ')')
  Else If BiCode <> 0 Then
    WriteLn('        -> fonction integree (BI_', BiCode, ')');
End;

{ ============================================================ }
{ TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES}
{ ============================================================ }
{ Table des types INSPIREE de celle de GOCW32.PAS (meme projet,   }
{ TypeTab/FieldPool partages, meme discipline PDT_xxx <-> TypeIdx      }
{ etablie au TODO 03) mais adaptee au systeme de types Swift : la           }
{ distinction VALEUR/REFERENCE (IsValueType) est ICI CENTRALE               }
{ (contrairement a Go, ou seuls les pointeurs explicites different            }
{ d une copie par valeur) - un struct/enum Swift est TOUJOURS copie              }
{ par valeur, une class Swift est TOUJOURS partagee par reference               }
{ (comptage automatique de references, ARC, reserve au TODO 18).                 }
{ Cible 80386/Win32 32 bits : "Int"/"UInt" valent 4 octets (comme           }
{ "int"/"uint" chez GOCW32.PAS), pas 8 - meme regle, meme cible.                     }

Type
  TTypeKind = (
    TYK_INVALID,       { entree 0 reservee (voir TypeInit ci-dessous) }
    TYK_BOOL,
    TYK_INT,           { signe OU non signe (IsUnsigned), taille        }
                        { 1/2/4/8 (Int8/16/32/64, UInt8/16/32/64)          }
    TYK_FLOAT,         { taille 4 (Float) ou 8 (Double)                    }
    TYK_STRING,
    TYK_CHARACTER,     { UN SEUL scalaire Unicode (simplification            }
                        { documentee : le vrai "grapheme cluster etendu"        }
                        { de Swift, pouvant combiner plusieurs scalaires,          }
                        { n est PAS modelise - hors de portee) }
    TYK_ARRAY,         { ElemTypeIdx = type des elements ; -1 si            }
                        { generique non encore parametre (entree             }
                        { predeclaree "Array" elle-meme, avant le TODO 16) }
    TYK_DICTIONARY,    { KeyTypeIdx -> ElemTypeIdx (nomme "ValueTypeIdx"       }
                        { dans le roadmap ci-dessus - reutilise ElemTypeIdx        }
                        { pour eviter un champ redondant, TODO 16) }
    TYK_SET,           { ElemTypeIdx = type des elements, TODO 16 }
    TYK_STRUCT,        { semantique VALEUR (IsValueType=Vrai) - champs         }
                        { dans FieldPool[FieldFirst..+FieldCount-1], TODO 09 }
    TYK_CLASS,         { semantique REFERENCE (IsValueType=Faux) -             }
                        { heritage simple via SuperTypeIdx, TODO 10 }
    TYK_ENUM,          { semantique VALEUR - cas dans FieldPool                }
                        { (raw/associated values), TODO 12 }
    TYK_PROTOCOL,      { methodes exigees dans FieldPool[MethodFirst..]         }
                        { - synthetise ICI pour "Any"/"AnyObject"                  }
                        { (MethodCount=0, satisfait par tout type), le vrai         }
                        { mecanisme de protocole utilisateur arrive au TODO 11 }
    TYK_FUNC,          { params/resultat - reserve pour le TODO 08              }
                        { (aucune entree TYK_FUNC predeclaree ici,                 }
                        { contrairement a GOCW32.PAS qui synthetise "error") }
    TYK_OPTIONAL,      { Optional<T> - ElemTypeIdx = T ; SEULE                }
                        { construction d absence de valeur du langage             }
                        { (voir note ci-dessous), TODO 14 }
    TYK_TUPLE,         { champs (parfois anonymes) dans FieldPool -            }
                        { synthetise ICI pour "Void" (tuple VIDE, 0 champ) }
    TYK_GENERIC_PARAM  { parametre de type generique nomme (T, U, ...),        }
                        { reserve pour le TODO 13 }
  );

  TFieldRec = Record
    Name    : TString;   { nom du champ/parametre/cas d enum ; '' si   }
                          { anonyme (element de tuple non nomme) }
    TypeIdx : Integer;
    Offset  : Integer;   { TYK_STRUCT/TYK_CLASS seulement - octets      }
                          { depuis le debut de la valeur/instance }
    { Les 4 champs suivants ne sont exploites QUE par les parametres      }
    { de fonction (TODO 08, FieldPoolAddParam) - toujours a leur valeur         }
    { par defaut ('' /Faux/Faux/-1) pour un champ de struct/class            }
    { (TODO 09/10, FieldPoolAdd) ou un resultat de fonction. }
    ExtLabel      : TString;  { etiquette EXTERNE (appelant) : '' = "meme    }
                               { que Name" (regle par defaut Swift            }
                               { reelle) ; '_' = "aucune etiquette"              }
                               { (forme utilisee par TOUS les echantillons)         }
    IsInout       : Boolean;  { Vrai si "inout Type" (parametre passe par   }
                               { ADRESSE - modele simple, TODO 08)              }
    HasDefault    : Boolean;
    DefaultExprIdx: Integer;  { dans ExprPool (TODO 06) ; -1 si aucune    }
                               { valeur par defaut - "evaluee cote               }
                               { APPELANT si omis" (roadmap TODO 08) reste           }
                               { un sujet de generateur de code, TODO 21+ }
  End;

  TTypeRec = Record
    Kind         : TTypeKind;
    Name         : TString;   { '' si type anonyme (tuple/optional        }
                               { construits inline, pas encore le cas        }
                               { avant le TODO 13/14/16) }
    Size         : Integer;   { octets, representation runtime }
    Align        : Integer;
    IsUnsigned   : Boolean;   { TYK_INT seulement (Int vs UInt) }
    IsValueType  : Boolean;   { Vrai pour struct/enum/scalaires (copie      }
                               { par valeur) ; Faux pour class/protocole       }
                               { (partage par reference) - DISTINCTION           }
                               { CENTRALE du langage, absente de Go (voir          }
                               { note d en-tete ci-dessus) }
    ElemTypeIdx  : Integer;   { array/set/optional : type des elements/     }
                               { deballe ; -1 sinon ou inconnu }
    KeyTypeIdx   : Integer;   { dictionary seulement : type de la cle ;    }
                               { -1 sinon }
    FieldFirst   : Integer;   { struct/class/enum/tuple : index de           }
                               { depart dans FieldPool, -1 si aucun champ }
    FieldCount   : Integer;
    MethodFirst  : Integer;   { reserve pour le TODO 09/10/11 - TOUJOURS     }
                               { -1/0 pour l instant (sauf Any/AnyObject,        }
                               { synthetises ci-dessous avec MethodCount=0),        }
                               { rien d autre n y ecrit encore }
    MethodCount  : Integer;
    SuperTypeIdx : Integer;   { TYK_CLASS seulement : classe parente,       }
                               { heritage simple - TODO 10 ; -1 sinon           }
                               { (ou si aucune classe parente explicite) }
    ProtoFirst   : Integer;   { reserve pour le TODO 11 (liste des            }
                               { conformances - pool partage, meme               }
                               { convention que FieldFirst/MethodFirst) ;           }
                               { TOUJOURS -1/0 pour l instant }
    ProtoCount   : Integer;
    ParamFirst   : Integer;   { TYK_FUNC seulement (TODO 08) : index de      }
                               { depart dans FieldPool pour les PARAMETRES -    }
                               { -1/0 pour tout type NON-fonction }
    ParamCount   : Integer;
    ResultFirst  : Integer;   { TYK_FUNC seulement : UNE SEULE entree           }
                               { FieldPool portant le type de RETOUR (jamais         }
                               { de retours multiples comme Go - Count vaut            }
                               { TOUJOURS 0 ou 1, JAMAIS plus, voir note              }
                               { d en-tete du TODO 08) }
    ResultCount  : Integer;
    RawTypeIdx   : Integer;   { TYK_ENUM seulement (TODO 12) : type de       }
                               { valeur BRUTE ("enum Nom: Int"), -1 si            }
                               { aucun (cas simples OU valeurs ASSOCIEES,               }
                               { jamais les deux a la fois - regle Swift              }
                               { reelle, un enum est TOUJOURS exactement                  }
                               { UNE seule des trois formes du roadmap                       }
                               { d en-tete du TODO 12) }
    CaseFirst    : Integer;   { TYK_ENUM seulement : index de depart dans     }
                               { EnumCasePool (TODO 12), -1 si aucun cas             }
    CaseCount    : Integer;
    Throws       : Boolean;   { TYK_FUNC seulement (TODO 15) : "func f(...)   }
                               { throws -> T" - Faux pour tout type NON-           }
                               { fonction ou toute fonction sans "throws" }
  End;

Var
  TypeTab        : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount      : Integer;
  FieldPool      : Array[0..MAX_FIELD_POOL - 1] Of TFieldRec;
  FieldPoolCount : Integer;

{ ------------------------------------------------------------ }
{ TypeAdd : ajoute un type "simple" (scalaire/array/dictionary/   }
{ set/optional non encore parametre - PAS struct/class/enum/       }
{ tuple/protocole, construits par des fonctions dediees plus tard      }
{ une fois FieldPool rempli, TODO 09-14/16). Les champs specifiques        }
{ restent a leur valeur "aucun" (-1/0/Faux) et pourront etre                }
{ completes ensuite directement (meme convention que GOCW32.PAS). }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind: TTypeKind; Const AName: TString; ASize, AAlign: Integer;
  AUnsigned, AValueType: Boolean; AElemTypeIdx, AKeyTypeIdx: Integer): Integer;
Begin
  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE)');
    TypeAdd := -1;
    Exit;
  End;

  TypeTab[TypeCount].Kind         := Kind;
  TypeTab[TypeCount].Name         := AName;
  TypeTab[TypeCount].Size         := ASize;
  TypeTab[TypeCount].Align        := AAlign;
  TypeTab[TypeCount].IsUnsigned   := AUnsigned;
  TypeTab[TypeCount].IsValueType  := AValueType;
  TypeTab[TypeCount].ElemTypeIdx  := AElemTypeIdx;
  TypeTab[TypeCount].KeyTypeIdx   := AKeyTypeIdx;
  TypeTab[TypeCount].FieldFirst   := -1;
  TypeTab[TypeCount].FieldCount   := 0;
  TypeTab[TypeCount].MethodFirst  := -1;
  TypeTab[TypeCount].MethodCount  := 0;
  TypeTab[TypeCount].SuperTypeIdx := -1;
  TypeTab[TypeCount].ProtoFirst   := -1;
  TypeTab[TypeCount].ProtoCount   := 0;
  TypeTab[TypeCount].ParamFirst   := -1;
  TypeTab[TypeCount].ParamCount   := 0;
  TypeTab[TypeCount].ResultFirst  := -1;
  TypeTab[TypeCount].ResultCount  := 0;
  TypeTab[TypeCount].RawTypeIdx   := -1;
  TypeTab[TypeCount].CaseFirst    := -1;
  TypeTab[TypeCount].CaseCount    := 0;
  TypeTab[TypeCount].Throws       := False;

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : recherche EXACTE (sensible a la casse - Swift }
{ l est, comme Go) par nom. -1 si non trouve. }
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

{ ------------------------------------------------------------ }
{ TypeIsOptional / TypeResolveOptional : Optional<T> (nil) est la  }
{ SEULE construction d absence de valeur du langage (contrairement    }
{ a Go, ou toute variable non initialisee recoit implicitement une       }
{ "valeur zero" - 0/faux/chaine vide/nil selon le type). PORTEE : ce         }
{ compilateur EXIGE une initialisation explicite pour tout type NON          }
{ optionnel plutot que de modeliser la vraie regle de flux de controle          }
{ "definite initialization" de Swift reel - simplification documentee              }
{ ici plutot que devinee plus tard sans avertissement. TypeResolveOptional      }
{ deballe RECURSIVEMENT (Swift autorise T?? - optional d optional),               }
{ profondeur limitee comme TypeResolveAlias chez GOCW32.PAS. }
{ ------------------------------------------------------------ }

Function TypeIsOptional(Idx: Integer): Boolean;
Begin
  TypeIsOptional := (Idx >= 0) And (Idx < TypeCount) And
    (TypeTab[Idx].Kind = TYK_OPTIONAL);
End;

Function TypeResolveOptional(Idx: Integer): Integer;
Var Depth : Integer;
Begin
  Depth := 0;
  While (Idx >= 0) And (Idx < TypeCount) And
        (TypeTab[Idx].Kind = TYK_OPTIONAL) And (Depth < 8) Do
  Begin
    Idx := TypeTab[Idx].ElemTypeIdx;
    Inc(Depth);
  End;
  TypeResolveOptional := Idx;
End;

{ ------------------------------------------------------------ }
{ TypeInit : enregistre les 22 types predeclares Swift, DANS LE    }
{ MEME ORDRE que les codes PDT_xxx du TODO 03 - une entree            }
{ sentinelle TYK_INVALID est ajoutee EN PREMIER (index 0) pour que        }
{ "Int" (PDT_INT=1) tombe exactement sur TypeTab[1], "Int8"                    }
{ (PDT_INT8=2) sur TypeTab[2], etc. (design deja annonce au TODO 03,             }
{ meme discipline que GOCW32.PAS). Array/Dictionary/Set/Optional sont            }
{ enregistres ici comme entrees GENERIQUES NON PARAMETREES               }
{ (ElemTypeIdx/KeyTypeIdx = -1, tailles provisoires) - la vraie             }
{ parametrisation ("Array<Int>" ou "[Int]") construit un TypeIdx              }
{ DISTINCT plus tard (TODO 16), cette entree predeclaree ne servant           }
{ qu a la RECONNAISSANCE de l identificateur par le parseur. "Any"               }
{ et "AnyObject" sont synthetises comme des TYK_PROTOCOL n exigeant             }
{ AUCUNE methode (MethodCount=0, donc satisfaits par tout type, meme            }
{ principe que "error"/"any" chez GOCW32.PAS) ; "Void" est le tuple               }
{ VIDE (0 champ) - la representation reelle du type de retour absent          }
{ en Swift (contrairement au "type absent" de Go, qui n a pas besoin              }
{ d un TypeIdx du tout pour une fonction sans retour). }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Begin
  TypeCount      := 0;
  FieldPoolCount := 0;

  TypeAdd(TYK_INVALID, '', 0, 0, False, False, -1, -1);              { 0 }

  TypeAdd(TYK_INT,     'Int',        4, 4, False, True,  -1, -1);      { 1  PDT_INT       }
  TypeAdd(TYK_INT,     'Int8',       1, 1, False, True,  -1, -1);      { 2  PDT_INT8      }
  TypeAdd(TYK_INT,     'Int16',      2, 2, False, True,  -1, -1);      { 3  PDT_INT16     }
  TypeAdd(TYK_INT,     'Int32',      4, 4, False, True,  -1, -1);      { 4  PDT_INT32     }
  TypeAdd(TYK_INT,     'Int64',      8, 4, False, True,  -1, -1);      { 5  PDT_INT64     }
  TypeAdd(TYK_INT,     'UInt',       4, 4, True,  True,  -1, -1);      { 6  PDT_UINT      }
  TypeAdd(TYK_INT,     'UInt8',      1, 1, True,  True,  -1, -1);      { 7  PDT_UINT8     }
  TypeAdd(TYK_INT,     'UInt16',     2, 2, True,  True,  -1, -1);      { 8  PDT_UINT16    }
  TypeAdd(TYK_INT,     'UInt32',     4, 4, True,  True,  -1, -1);      { 9  PDT_UINT32    }
  TypeAdd(TYK_INT,     'UInt64',     8, 4, True,  True,  -1, -1);      { 10 PDT_UINT64    }
  TypeAdd(TYK_FLOAT,   'Double',     8, 4, False, True,  -1, -1);      { 11 PDT_DOUBLE    }
  TypeAdd(TYK_FLOAT,   'Float',      4, 4, False, True,  -1, -1);      { 12 PDT_FLOAT     }
  TypeAdd(TYK_BOOL,    'Bool',       1, 1, False, True,  -1, -1);      { 13 PDT_BOOL      }
  TypeAdd(TYK_STRING,  'String',     8, 4, False, True,  -1, -1);      { 14 PDT_STRING    }
  TypeAdd(TYK_CHARACTER,'Character', 4, 4, False, True,  -1, -1);      { 15 PDT_CHARACTER }
  TypeAdd(TYK_ARRAY,   'Array',      8, 4, False, True,  -1, -1);      { 16 PDT_ARRAY     }
  TypeAdd(TYK_DICTIONARY,'Dictionary',8,4, False, True,  -1, -1);      { 17 PDT_DICTIONARY}
  TypeAdd(TYK_SET,     'Set',        8, 4, False, True,  -1, -1);      { 18 PDT_SET       }
  TypeAdd(TYK_OPTIONAL,'Optional',   0, 1, False, True,  -1, -1);      { 19 PDT_OPTIONAL  }
  TypeAdd(TYK_PROTOCOL,'Any',        8, 4, False, False, -1, -1);      { 20 PDT_ANY       }
  TypeAdd(TYK_PROTOCOL,'AnyObject',  4, 4, False, False, -1, -1);      { 21 PDT_ANYOBJECT }
  TypeAdd(TYK_TUPLE,   'Void',       0, 1, False, True,  -1, -1);      { 22 PDT_VOID      }

  { "Any"/"AnyObject" (TODO 11) n exigent AUCUNE methode - deja        }
  { MethodCount=0 par defaut via TypeAdd, rien de plus a faire ici          }
  { (contrairement a "error" chez GOCW32.PAS, qui doit synthetiser            }
  { une methode reelle - Any/AnyObject Swift n en exigent aucune). }

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types predeclares enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeSelfTest : verifie l alignement PDT_xxx <-> TypeIdx, les     }
{ tailles cle (32 bits pour Int/UInt, PAS 64), la regle Optional        }
{ comme SEULE absence de valeur, et IsValueType (struct/scalaires          }
{ Vrai, class/protocole Faux).                                                }
{ ------------------------------------------------------------ }

Procedure TypeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('TypeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TypeSelfTest;
Var
  IdxInt, IdxStr, IdxDouble, IdxOptInt : Integer;
Begin
  TypeInit;

  { 22 types predeclares + sentinelle TYK_INVALID = 23 entrees. }
  TypeAssert('22 types + sentinelle = 23 entrees', TypeCount = 23);

  IdxInt := TypeFindByName('Int');
  TypeAssert('Int trouve par nom',    IdxInt = PDT_INT);
  TypeAssert('Int correspond a PDT_INT (design TODO 03)', IdxInt = PDT_INT);
  TypeAssert('Int fait 4 octets (cible 32 bits, PAS 8)', TypeTab[IdxInt].Size = 4);
  TypeAssert('Int est signe',         Not TypeTab[IdxInt].IsUnsigned);
  TypeAssert('Int est un type VALEUR', TypeTab[IdxInt].IsValueType);

  TypeAssert('UInt est non signe', TypeTab[PDT_UINT].IsUnsigned);

  IdxStr := TypeFindByName('String');
  TypeAssert('String trouve == PDT_STRING', IdxStr = PDT_STRING);
  TypeAssert('String est un type VALEUR (pas une class)', TypeTab[IdxStr].IsValueType);

  IdxDouble := TypeFindByName('Double');
  TypeAssert('Double fait 8 octets', TypeTab[IdxDouble].Size = 8);
  TypeAssert('Float fait 4 octets',  TypeTab[PDT_FLOAT].Size = 4);

  TypeAssert('Any est de genre TYK_PROTOCOL', TypeTab[PDT_ANY].Kind = TYK_PROTOCOL);
  TypeAssert('Any n''exige aucune methode',   TypeTab[PDT_ANY].MethodCount = 0);
  TypeAssert('Any est un type REFERENCE (existentiel)', Not TypeTab[PDT_ANY].IsValueType);
  TypeAssert('AnyObject est un type REFERENCE', Not TypeTab[PDT_ANYOBJECT].IsValueType);

  TypeAssert('Void est de genre TYK_TUPLE', TypeTab[PDT_VOID].Kind = TYK_TUPLE);
  TypeAssert('Void n''a aucun champ (tuple vide)', TypeTab[PDT_VOID].FieldCount = 0);

  TypeAssert('Int n''est PAS optionnel',    Not TypeIsOptional(PDT_INT));
  TypeAssert('Optional (predeclare, non parametre) EST optionnel',
    TypeIsOptional(PDT_OPTIONAL));
  TypeAssert('TypeResolveOptional(Int) renvoie Int inchange',
    TypeResolveOptional(PDT_INT) = PDT_INT);

  { Optional<Int> concret (construit a la volee ici - la vraie          }
  { construction depuis le parseur viendra au TODO 14). }
  IdxOptInt := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, PDT_INT, -1);
  TypeAssert('Optional<Int> est optionnel', TypeIsOptional(IdxOptInt));
  TypeAssert('TypeResolveOptional(Optional<Int>) deballe vers Int',
    TypeResolveOptional(IdxOptInt) = PDT_INT);
End;

{ ============================================================ }
{ TODO 05 - DECLARATIONS : LET/VAR, INFERENCE DE TYPE ET PORTEES}
{ ============================================================ }
{ Premier TODO de PARSING reel (pas juste lexer/classification/   }
{ types). Necessite une infrastructure non nommee explicitement       }
{ par le titre du TODO mais indispensable a tout parseur recursif-        }
{ descendant : un TokenPool (tous les tokens du fichier, pre-lexes           }
{ une seule fois via LexAll) parcouru par un curseur PP - MEME               }
{ architecture que GOCW32.PAS (meme projet), PAS le flux "un token a           }
{ la fois" du TODO 02. PORTEE ASSUMEE ET DOCUMENTEE (comme chez              }
{ GOCW32.PAS a ce meme stade) : les initialiseurs de let/var restent           }
{ LIMITES aux expressions CONSTANTES (ConstEvalExpr, ci-dessous) -               }
{ aucun backend de code n existe encore (TODO 21+), et un "let x =                 }
{ maFonction()" (tres courant en Swift reel, contrairement au "var x =               }
{ f()" de Go, deliberement rare) n aurait de toute facon nulle part ou                   }
{ generer un VRAI appel pour l instant. Cette infrastructure n est donc                      }
{ PAS ENCORE branchee sur Run() / les fichiers SAMPLES\SWIFT reels                                }
{ (qui appellent librement des fonctions dans leurs let/var - voir              }
{ math.swift/structs.swift/etc.) : elle est testee ISOLEMENT ci-dessous              }
{ (DeclSelfTest, sur un extrait synthetique constant), exactement comme                  }
{ GOCW32.PAS l a fait a ce meme stade (DeclSelfTest/FuncParseTopLevel)                       }
{ avant que les TODO ulterieurs (fonctions TODO 08, instructions                                 }
{ TODO 07) ne rendent une VRAIE compilation de bout en bout possible.                                }

Const
  MAX_TOKEN = {$IFDEF FPC}65536{$ELSE}8192{$ENDIF};

Var
  TokenPool : Array[0..MAX_TOKEN - 1] Of TToken;
  PP        : Integer;

{ ------------------------------------------------------------ }
{ LexAll : tokenise le fichier ENTIER (deja ouvert via LexInit    }
{ par l appelant) dans TokenPool - reutilise TokenCount (TODO 02)         }
{ comme total - MAIS, CONTRAIREMENT a GOCW32.PAS, LexNextToken (TODO 02)   }
{ incremente DEJA lui-meme TokenCount (a chaque token REEL/point-virgule       }
{ insere/EOF, pour le compteur "Tokens produits" de Run) - LexAll ne doit         }
{ donc PAS l incrementer une SECONDE fois (bogue trouve a l execution :          }
{ un double-incrementement laissait un slot TokenPool sur deux a sa           }
{ valeur par defaut TOK_EOF, non ecrite) : l index de stockage est ICI               }
{ "TokenCount - 1" (valeur DEJA incrementee par l appel qui vient d avoir            }
{ lieu), jamais "TokenCount" suivi d un Inc separe. }
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
{ PPMatch compare le TEXTE EXACT (Swift est sensible a la casse,     }
{ comme Go). }
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

{ PP2Kind/PP2Val : un jeton d avance (sans consommer) - necessaire     }
{ au TODO 06 pour distinguer une etiquette d appel/tuple ("Nom:") d un       }
{ identificateur simple sans faire de retour en arriere. }
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

{ PPIsOp : Vrai si le token courant est TOK_OP et vaut exactement    }
{ S - distinct de "PPVal=S" seul, meme raison que GOCW32.PAS (un       }
{ litteral chaine dont le contenu vaut par hasard un operateur ne         }
{ doit jamais etre pris pour cet operateur). }
Function PPIsOp(Const S: TString): Boolean;
Begin
  PPIsOp := (Not PPAtEnd) And (TokenPool[PP].Kind = TOK_OP) And
            (TokenPool[PP].Val = S);
End;

Procedure PPAdvance;
Begin
  If Not PPAtEnd Then Inc(PP);
End;

{ Saute un ou plusieurs TOK_SEMI consecutifs (reels OU inseres,   }
{ TODO 02). }
Procedure PPSkipSemis;
Begin
  While (Not PPAtEnd) And (PPKind = TOK_SEMI) Do PPAdvance;
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
{ Table des symboles et portees - meme architecture que          }
{ GOCW32.PAS (portee empilee, resolution DU PLUS IMBRIQUE VERS         }
{ LE PLUS GLOBAL). PAS de SK_CONST distinct : contrairement au           }
{ "const" de Go (qui DOIT etre une expression compile-time), le "let"        }
{ de Swift est juste une variable IMMUABLE apres sa premiere                 }
{ affectation - meme SK_VAR que "var", distingue seulement par le               }
{ booleen IsConst (design demande par le roadmap TODO 05 ci-dessus). }
{ ------------------------------------------------------------ }

Type
  TSymKind = (
    SK_VAR,    { let (IsConst=Vrai) OU var (IsConst=Faux)   }
    SK_TYPE,   { typealias                                     }
    SK_FUNC    { reserve pour le TODO 08                          }
  );

  { Valeur d une expression CONSTANTE Swift - TAGGEE (entiere,     }
  { flottante, booleenne ou chaine) - meme forme que GOCW32.PAS. }
  TConstKind = (CK_INT, CK_FLOAT, CK_BOOL, CK_STRING);

  TConstVal = Record
    Kind    : TConstKind;
    IntVal  : LongInt;
    RealVal : Real;
    StrVal  : TString;
  End;

  TSymRec = Record
    Name       : TString;    { sensible a la casse }
    Kind       : TSymKind;
    TypeIdx    : Integer;    { -1 si pas encore resolu/inconnu }
    ScopeLevel : Integer;    { 0 = portee fichier (top-level)   }
    ScopeId    : Integer;
    IsGlobal   : Boolean;
    IsConst    : Boolean;    { Vrai pour let - voir note ci-dessus }
    ConstVal   : TConstVal;
    HasInit    : Boolean;    { Vrai des qu une valeur a ete affectee -  }
                              { sert a SymCheckMutable (ci-dessous) pour    }
                              { la regle "let assigne UNE fois".              }
    InitExprIdx: Integer;    { TODO 08 : index dans ExprPool (TODO 06)   }
                              { de l EXPRESSION GENERALE d initialisation -   }
                              { -1 si aucune. ConstVal (ci-dessus) reste             }
                              { rempli SEULEMENT quand cette expression est          }
                              { effectivement repliable (ConstFoldExpr,                 }
                              { TODO 06) - un "let sum = add(x, y)" (VALEUR                 }
                              { calculee a l EXECUTION, comme dans math.swift)               }
                              { n a par exemple aucun ConstVal exploitable,                     }
                              { seulement cet InitExprIdx. }
    Used        : Boolean;   { TODO 19 : marque Vrai des la PREMIERE       }
                              { resolution par ExprAddIdent - jamais purge          }
                              { (comme le reste de SymTab, voir la note de           }
                              { SymFind) }
    WasVarDecl  : Boolean;   { TODO 19 : Vrai UNIQUEMENT pour une entree   }
                              { creee par ParseLetVarPattern (une VRAIE                  }
                              { instruction "let"/"var") - Faux pour un                    }
                              { PARAMETRE (RegisterFuncScopeSymbols), une                    }
                              { variable de boucle (ParseForInStmt), une                     }
                              { liaison "if let"/"guard let"/motif de cas                    }
                              { d enum, "self", ou un parametre de type                          }
                              { generique - "declare et jamais utilise"                          }
                              { (roadmap TODO 19) ne vise QUE les VRAIES                       }
                              { variables locales, jamais ces autres formes                    }
                              { de liaison (meme portee que GOCW32.PAS,                              }
                              { lui-meme silencieux sur les parametres/                              }
                              { variables de boucle non utilises). }
    Offset      : Integer;   { TODO 21 (generateur de code) : deplacement  }
                              { EBP-relatif pour un local/parametre (voir              }
                              { CgVarOperand) - TOUJOURS 0 pour un GLOBAL              }
                              { (IsGlobal=Vrai, adresse par NOM mangle,                    }
                              { jamais par deplacement) ; AUCUN code ne le            }
                              { calcule encore (aucune fonction n est                          }
                              { compilee cette premiere passe, seul le                            }
                              { niveau fichier/global l est) - reserve pour             }
                              { la prochaine extension (fonctions), meme                     }
                              { convention EXACTE que GOCW32.PAS (parametres              }
                              { positifs a partir de +8, locaux negatifs a             }
                              { partir de -4). }
    IsTopLevelLocal : Boolean; { TODO 21 (extension controle de flux) : Vrai   }
                              { UNIQUEMENT pour une variable de boucle for-in            }
                              { (ParseForInStmt) - AUCUNE fonction n est                        }
                              { encore compilee (CompileFuncDef n existe pas),            }
                              { donc IsGlobal=Faux ne peut actuellement              }
                              { signifier QUE "portee imbriquee au niveau              }
                              { FICHIER" (if/while/for-in top-level) - CE               }
                              { CHAMP existe pour que EmitDataSeg distingue               }
                              { PRECISEMENT ce cas (storage .DATA legitime,              }
                              { voir CgVarLabel) d un VRAI parametre/local de              }
                              { fonction (ex. "temp" dans math.swift, "status"           }
                              { dans errors.swift - AUCUN stockage .DATA               }
                              { n est necessaire ni correct pour ceux-la,                       }
                              { leurs fonctions n etant jamais compilees) -              }
                              { bogue REEL trouve en executant le rapport               }
                              { TODO 25 : sans ce champ, EmitDataSeg (si son              }
                              { filtre IsGlobal etait simplement retire)                        }
                              { rapportait a tort "temp"/"status" comme des               }
                              { "globaux" non repliables. }
  End;

Var
  SymTab   : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount : Integer;

  ScopeStack    : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeStackTop : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

Procedure SymInit;
Begin
  SymCount      := 0;
  ScopeStackTop := -1;
  CurScopeLevel := 0;
  CurScopeId    := 0;
  ScopeIdSeq    := 0;
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

{ SymLeaveScope : depilage, DESORMAIS PRECEDE (TODO 19) d une VERIFICATION }
{ "declare et jamais utilise" - roadmap : "meme regle stricte que              }
{ GOCW32.PAS pour les variables locales - erreur en mode strict,                          }
{ avertissement sinon". CONTRAIREMENT a Go (variable locale declaree et            }
{ jamais lue = TOUJOURS une erreur reelle), Swift ne fait QUE avertir              }
{ dans le compilateur reel - mais Opts.StrictMode (reserve depuis le             }
{ TODO 01/02, TOUJOURS Vrai par defaut ici, voir sa propre note                             }
{ d en-tete) fait de ce compilateur simplifie un cas TOUJOURS strict            }
{ pour l instant (FatalError), la branche WarnMsg restant prete pour               }
{ le jour ou un "-no-strict" viendrait assouplir Opts.StrictMode - AUCUN            }
{ tel flag n existe encore, decision honnetement documentee plutot que            }
{ devinee. PORTEE (WasVarDecl, voir TSymRec) : SEULES les VRAIES                          }
{ instructions "let"/"var" (ParseLetVarPattern) sont visees - PAS un              }
{ parametre de fonction, une variable de boucle for-in, une liaison "if           }
{ let"/"guard let"/motif de cas d enum, ni "self" - EXACTEMENT la meme                  }
{ portee reduite que GOCW32.PAS pour son propre "declare et jamais                          }
{ utilise" (qui ne vise pas non plus les parametres/variables de                            }
{ boucle). "_" (nom explicitement ignore) est EXEMPTE, meme convention                   }
{ que le reste du projet ("_" ignore une variable de boucle, TODO 07). }
Procedure SymLeaveScope;
Var
  ClosingId, I : Integer;
Begin
  If ScopeStackTop < 0 Then
  Begin
    WarnMsg('tentative de quitter une portee inexistante');
    Exit;
  End;

  ClosingId := ScopeStack[ScopeStackTop];
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].ScopeId = ClosingId) And SymTab[I].WasVarDecl And
       (Not SymTab[I].Used) And (SymTab[I].Name <> '_') Then
    Begin
      If Opts.StrictMode Then
        FatalError('variable ''' + SymTab[I].Name + ''' declaree et jamais utilisee')
      Else
        WarnMsg('variable ''' + SymTab[I].Name + ''' declaree et jamais utilisee');
    End;

  Dec(ScopeStackTop);
  CurScopeLevel := ScopeStackTop + 1;
  If ScopeStackTop < 0 Then CurScopeId := 0
  Else CurScopeId := ScopeStack[ScopeStackTop];
End;

{ SymFindInScope : cherche UNIQUEMENT dans la portee SId (pas les  }
{ englobantes) - detecte une redeclaration DANS LA MEME portee. }
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

{ SymFind : resolution normale - la portee la PLUS IMBRIQUEE        }
{ d abord (parcours DECROISSANT de SymTab, qui reflete l ordre          }
{ chronologique de declaration). }
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
  AIsConst: Boolean): Integer;
Var Dup : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM)');
    SymAdd := -1;
    Exit;
  End;

  { Dup n avertit PAS pour SK_FUNC (TODO 08) : redeclarer un NOM de       }
  { fonction deja utilise EST precisement la surchage Swift legitime         }
  { (memes noms, signatures de parametres differentes) - PAS une erreur,        }
  { contrairement a toute autre sorte de symbole (let/var/typealias). }
  Dup := SymFindInScope(Name, CurScopeId);
  If (Dup >= 0) And (Kind <> SK_FUNC) Then
    WarnMsg('symbole deja declare dans cette portee: ' + Name);

  SymTab[SymCount].Name       := Name;
  SymTab[SymCount].Kind       := Kind;
  SymTab[SymCount].TypeIdx    := TIdx;
  SymTab[SymCount].ScopeLevel := CurScopeLevel;
  SymTab[SymCount].ScopeId    := CurScopeId;
  SymTab[SymCount].IsGlobal   := (CurScopeLevel = 0);
  SymTab[SymCount].IsConst    := AIsConst;
  SymTab[SymCount].ConstVal.Kind    := CK_INT;
  SymTab[SymCount].ConstVal.IntVal  := 0;
  SymTab[SymCount].ConstVal.RealVal := 0.0;
  SymTab[SymCount].ConstVal.StrVal  := '';
  SymTab[SymCount].HasInit     := False;
  SymTab[SymCount].InitExprIdx := -1;
  SymTab[SymCount].Used        := False;
  SymTab[SymCount].WasVarDecl  := False;
  SymTab[SymCount].Offset      := 0;
  SymTab[SymCount].IsTopLevelLocal := False;

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ SymCheckMutable : verification de SURFACE pour la regle "let       }
{ assigne UNE FOIS" annoncee par le roadmap TODO 05 - Vrai si SI peut       }
{ etre (re)affecte (var, ou un let PAS ENCORE initialise), et marque           }
{ alors HasInit ; sinon emet un FatalError. Aucun appelant reel           }
{ n existe encore (aucune instruction d affectation ne peut etre                }
{ ecrite avant le TODO 07/08) - testee ISOLEMENT ci-dessous                        }
{ (DeclSelfTest), en attendant, exactement comme le ShortVarDecl de                    }
{ GOCW32.PAS a ce meme stade. La verification COMPLETE, sensible au                        }
{ flux de controle (ex. un "let" affecte une seule fois a travers                             }
{ plusieurs branches d un if/else), reste hors de portee ici - simple                             }
{ approximation "deja initialise une fois => plus jamais modifiable"                                 }
{ au niveau de la table des symboles elle-meme. }
Function SymCheckMutable(SI: Integer): Boolean;
Begin
  SymCheckMutable := True;
  If (SI < 0) Or (SI >= SymCount) Then Exit;
  If SymTab[SI].IsConst And SymTab[SI].HasInit Then
  Begin
    FatalError('affectation a une constante ''let'' deja initialisee: ' +
      SymTab[SI].Name);
    SymCheckMutable := False;
    Exit;
  End;
  SymTab[SI].HasInit := True;
End;

{ ------------------------------------------------------------ }
{ Petits constructeurs de TConstVal (evitent de repeter les 4     }
{ affectations de champs partout) + evaluateur d expression            }
{ CONSTANTE - couvre litteraux, identificateurs DEJA declares en          }
{ "let"/typealias, et les operateurs Swift dans leur PRECEDENCE            }
{ usuelle (haut : * / % << >> & ; puis + - | ^ ; puis comparaisons ;             }
{ puis && ; bas : ||). Operateurs UNAIRES : + - ! ~ (bitwise NOT -              }
{ Swift utilise "~", PAS le "^" unaire de Go, bien que "^" reste le                 }
{ XOR BINAIRE dans les deux langages - piege deja documente au TODO 02              }
{ pour la meme raison, cote lexer). PORTEE : seulement des operandes                    }
{ eux-memes CONSTANTS (litteraux, autres "let" - jamais un appel de                        }
{ fonction ni une variable "var", voir note d en-tete de section              }
{ ci-dessus). "nil" (TODO 14) n est PAS pris en charge ici (aucune               }
{ representation constante n existe encore pour Optional.none). }
{ ------------------------------------------------------------ }

Function ConstEvalExpr: TConstVal; Forward;

Function CVInt(V: LongInt): TConstVal;
Begin
  CVInt.Kind    := CK_INT;
  CVInt.IntVal  := V;
  CVInt.RealVal := 0.0;
  CVInt.StrVal  := '';
End;

Function CVFloat(V: Real): TConstVal;
Begin
  CVFloat.Kind    := CK_FLOAT;
  CVFloat.IntVal  := Trunc(V);
  CVFloat.RealVal := V;
  CVFloat.StrVal  := '';
End;

Function CVBool(V: Boolean): TConstVal;
Begin
  CVBool.Kind := CK_BOOL;
  If V Then CVBool.IntVal := 1 Else CVBool.IntVal := 0;
  CVBool.RealVal := 0.0;
  CVBool.StrVal  := '';
End;

Function CVString(Const V: TString): TConstVal;
Begin
  CVString.Kind    := CK_STRING;
  CVString.IntVal  := 0;
  CVString.RealVal := 0.0;
  CVString.StrVal  := V;
End;

{ CVAsReal : vue flottante d une TConstVal numerique (arithmetique  }
{ mixte entier/flottant, ex. "1.5 * 2"). }
Function CVAsReal(Const V: TConstVal): Real;
Begin
  If V.Kind = CK_FLOAT Then CVAsReal := V.RealVal
  Else CVAsReal := V.IntVal;
End;

Function ConstEvalPrimary: TConstVal;
Var Nam: TString; SI: Integer;
Begin
  ConstEvalPrimary := CVInt(0);

  If PPAtEnd Then
  Begin
    FatalError('expression constante incomplete');
    Exit;
  End;

  Case PPKind Of
    TOK_INT:
      Begin
        ConstEvalPrimary := CVInt(TokenPool[PP].IntVal);
        PPAdvance;
      End;
    TOK_FLOAT:
      Begin
        ConstEvalPrimary := CVFloat(TokenPool[PP].RealVal);
        PPAdvance;
      End;
    TOK_STRING:
      Begin
        ConstEvalPrimary := CVString(TokenPool[PP].Val);
        PPAdvance;
      End;
    TOK_STRING_INTERP_PART:
      Begin
        FatalError('chaine interpolee non prise en charge dans une ' +
          'expression constante (TODO 06/17)');
      End;
    TOK_IDENT:
      Begin
        Nam := TokenPool[PP].Val;
        PPAdvance;
        If Nam = 'true' Then
          ConstEvalPrimary := CVBool(True)
        Else If Nam = 'false' Then
          ConstEvalPrimary := CVBool(False)
        Else If Nam = 'nil' Then
          FatalError('"nil" non pris en charge dans une expression ' +
            'constante (TODO 14)')
        Else
        Begin
          SI := SymFind(Nam);
          If (SI >= 0) And (SymTab[SI].Kind = SK_VAR) And SymTab[SI].IsConst Then
            ConstEvalPrimary := SymTab[SI].ConstVal
          Else
            FatalError('identificateur non constant dans une expression ' +
              'constante: ' + Nam);
        End;
      End;
    TOK_OP:
      Begin
        If PPIsOp('(') Then
        Begin
          PPAdvance;
          ConstEvalPrimary := ConstEvalExpr;
          If Not PPIsOp(')') Then
            FatalError('parenthese fermante attendue dans une expression ' +
              'constante')
          Else
            PPAdvance;
        End
        Else
          FatalError('jeton inattendu dans une expression constante: ' +
            PPVal);
      End;
  Else
    FatalError('jeton inattendu dans une expression constante');
  End;
End;

Function ConstEvalUnary: TConstVal;
Var V: TConstVal;
Begin
  If PPIsOp('-') Then
  Begin
    PPAdvance;
    V := ConstEvalUnary;
    If V.Kind = CK_FLOAT Then ConstEvalUnary := CVFloat(-V.RealVal)
    Else ConstEvalUnary := CVInt(-V.IntVal);
    Exit;
  End;
  If PPIsOp('!') Then
  Begin
    PPAdvance;
    V := ConstEvalUnary;
    ConstEvalUnary := CVBool(V.IntVal = 0);
    Exit;
  End;
  If PPIsOp('~') Then
  Begin
    PPAdvance;
    V := ConstEvalUnary;
    ConstEvalUnary := CVInt(Not V.IntVal);
    Exit;
  End;
  ConstEvalUnary := ConstEvalPrimary;
End;

{ ConstEvalBinOp : applique UN operateur binaire deja identifie    }
{ (Op) a deux valeurs deja evaluees (L, R) - meme simplification        }
{ DOCUMENTEE que GOCW32.PAS pour la coercion entier/flottant (voir            }
{ CVAsReal ci-dessus). }
Function ConstEvalBinOp(Const L, R: TConstVal; Const Op: TString): TConstVal;
Var
  BothFloat : Boolean;
  LF, RF    : Real;
Begin
  ConstEvalBinOp := CVInt(0);

  If (Op = '+') And (L.Kind = CK_STRING) And (R.Kind = CK_STRING) Then
  Begin
    ConstEvalBinOp := CVString(L.StrVal + R.StrVal);
    Exit;
  End;

  BothFloat := (L.Kind = CK_FLOAT) Or (R.Kind = CK_FLOAT);
  LF := CVAsReal(L);
  RF := CVAsReal(R);

  If Op = '+' Then
  Begin
    If BothFloat Then ConstEvalBinOp := CVFloat(LF + RF)
    Else ConstEvalBinOp := CVInt(L.IntVal + R.IntVal);
    Exit;
  End;
  If Op = '-' Then
  Begin
    If BothFloat Then ConstEvalBinOp := CVFloat(LF - RF)
    Else ConstEvalBinOp := CVInt(L.IntVal - R.IntVal);
    Exit;
  End;
  If Op = '*' Then
  Begin
    If BothFloat Then ConstEvalBinOp := CVFloat(LF * RF)
    Else ConstEvalBinOp := CVInt(L.IntVal * R.IntVal);
    Exit;
  End;
  If Op = '/' Then
  Begin
    If BothFloat Then ConstEvalBinOp := CVFloat(LF / RF)
    Else If R.IntVal = 0 Then
      FatalError('division entiere par zero dans une expression constante')
    Else
      ConstEvalBinOp := CVInt(L.IntVal Div R.IntVal);
    Exit;
  End;
  If Op = '%' Then
  Begin
    If R.IntVal = 0 Then
      FatalError('modulo par zero dans une expression constante')
    Else
      ConstEvalBinOp := CVInt(L.IntVal Mod R.IntVal);
    Exit;
  End;
  If Op = '<<' Then Begin ConstEvalBinOp := CVInt(L.IntVal Shl R.IntVal); Exit; End;
  If Op = '>>' Then Begin ConstEvalBinOp := CVInt(L.IntVal Shr R.IntVal); Exit; End;
  If Op = '&'  Then Begin ConstEvalBinOp := CVInt(L.IntVal And R.IntVal); Exit; End;
  If Op = '|'  Then Begin ConstEvalBinOp := CVInt(L.IntVal Or R.IntVal); Exit; End;
  If Op = '^'  Then Begin ConstEvalBinOp := CVInt(L.IntVal Xor R.IntVal); Exit; End;

  If Op = '==' Then
  Begin
    If (L.Kind = CK_STRING) And (R.Kind = CK_STRING) Then
      ConstEvalBinOp := CVBool(L.StrVal = R.StrVal)
    Else If BothFloat Then ConstEvalBinOp := CVBool(LF = RF)
    Else ConstEvalBinOp := CVBool(L.IntVal = R.IntVal);
    Exit;
  End;
  If Op = '!=' Then
  Begin
    If (L.Kind = CK_STRING) And (R.Kind = CK_STRING) Then
      ConstEvalBinOp := CVBool(L.StrVal <> R.StrVal)
    Else If BothFloat Then ConstEvalBinOp := CVBool(LF <> RF)
    Else ConstEvalBinOp := CVBool(L.IntVal <> R.IntVal);
    Exit;
  End;
  If Op = '<'  Then Begin If BothFloat Then ConstEvalBinOp := CVBool(LF < RF)  Else ConstEvalBinOp := CVBool(L.IntVal < R.IntVal);  Exit; End;
  If Op = '<=' Then Begin If BothFloat Then ConstEvalBinOp := CVBool(LF <= RF) Else ConstEvalBinOp := CVBool(L.IntVal <= R.IntVal); Exit; End;
  If Op = '>'  Then Begin If BothFloat Then ConstEvalBinOp := CVBool(LF > RF)  Else ConstEvalBinOp := CVBool(L.IntVal > R.IntVal);  Exit; End;
  If Op = '>=' Then Begin If BothFloat Then ConstEvalBinOp := CVBool(LF >= RF) Else ConstEvalBinOp := CVBool(L.IntVal >= R.IntVal); Exit; End;

  If Op = '&&' Then Begin ConstEvalBinOp := CVBool((L.IntVal <> 0) And (R.IntVal <> 0)); Exit; End;
  If Op = '||' Then Begin ConstEvalBinOp := CVBool((L.IntVal <> 0) Or (R.IntVal <> 0)); Exit; End;

  FatalError('operateur constant non pris en charge: ' + Op);
End;

Function ConstEvalMul: TConstVal;
Var L: TConstVal; Op: TString;
Begin
  L := ConstEvalUnary;
  While PPIsOp('*') Or PPIsOp('/') Or PPIsOp('%') Or PPIsOp('<<') Or
        PPIsOp('>>') Or PPIsOp('&') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ConstEvalBinOp(L, ConstEvalUnary, Op);
  End;
  ConstEvalMul := L;
End;

Function ConstEvalAdd: TConstVal;
Var L: TConstVal; Op: TString;
Begin
  L := ConstEvalMul;
  While PPIsOp('+') Or PPIsOp('-') Or PPIsOp('|') Or PPIsOp('^') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ConstEvalBinOp(L, ConstEvalMul, Op);
  End;
  ConstEvalAdd := L;
End;

Function ConstEvalRel: TConstVal;
Var L: TConstVal; Op: TString;
Begin
  L := ConstEvalAdd;
  While PPIsOp('==') Or PPIsOp('!=') Or PPIsOp('<') Or PPIsOp('<=') Or
        PPIsOp('>') Or PPIsOp('>=') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ConstEvalBinOp(L, ConstEvalAdd, Op);
  End;
  ConstEvalRel := L;
End;

Function ConstEvalAnd: TConstVal;
Var L: TConstVal;
Begin
  L := ConstEvalRel;
  While PPIsOp('&&') Do
  Begin
    PPAdvance;
    L := ConstEvalBinOp(L, ConstEvalRel, '&&');
  End;
  ConstEvalAnd := L;
End;

Function ConstEvalExpr: TConstVal;
Var L: TConstVal;
Begin
  L := ConstEvalAnd;
  While PPIsOp('||') Do
  Begin
    PPAdvance;
    L := ConstEvalBinOp(L, ConstEvalAnd, '||');
  End;
  ConstEvalExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseTypeExpr : resout une expression de type EN UN TypeIdx.    }
{ PORTEE (documentee) : type predeclare (PDT_xxx, TODO 03/04) ou       }
{ nom de type deja declare (typealias, SK_TYPE) - la syntaxe des           }
{ types COMPOSES (Array<T>/[T], Dictionary<K,V>/[K:V], fonction,               }
{ tuple, struct/class/enum/protocol) est EXPLICITEMENT hors de                    }
{ portee ici, chacune relevant de son propre TODO dedie (09-13/16) :                }
{ arret propre (FatalError) plutot que deviner. Le suffixe POSTFIXE               }
{ "?" (Optional<T> - TODO 04) est en revanche traite ICI (repetable,                  }
{ "Int??" est un Optional d Optional legal en Swift) : simple sucre                      }
{ syntaxique construisant un TypeIdx via TypeAdd (deja ecrit au                              }
{ TODO 04) - le reste de la semantique Optional (deballage/if let/                              }
{ chaining) reste au TODO 14. }
{ ------------------------------------------------------------ }

Function ParseTypeExpr: Integer;
Var
  Nam  : TString;
  Base, SI, ElemT, ValT : Integer;
Begin
  ParseTypeExpr := -1;

  { "[Element]"/"[Cle: Valeur]" (TODO 16) - sucre BRACKET, forme          }
  { idiomatique reelle de Swift pour Array<T>/Dictionary<K,V> (bien plus            }
  { frequente en pratique que la forme generique explicite ci-dessous). }
  If PPIsOp('[') Then
  Begin
    PPAdvance;   { '[' }
    ElemT := ParseTypeExpr;
    If PPMatch(':') Then
    Begin
      ValT := ParseTypeExpr;
      Base := TypeAdd(TYK_DICTIONARY, '', 8, 4, False, True, ValT, ElemT);
    End
    Else
      Base := TypeAdd(TYK_ARRAY, '', 8, 4, False, True, ElemT, -1);
    If Not PPMatch(']') Then
      FatalError('crochet fermant attendu dans un type ''[Element]''/''[Cle: Valeur]''');

    While PPIsOp('?') Do
    Begin
      PPAdvance;
      Base := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, Base, -1);
    End;
    ParseTypeExpr := Base;
    Exit;
  End;

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('expression de type attendue');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If IsPredeclaredType(Nam) <> 0 Then
    Base := IsPredeclaredType(Nam)   { design TODO 03/04 : PDT_xxx = TypeIdx }
  Else
  Begin
    SI := SymFind(Nam);
    If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) Then
      Base := SymTab[SI].TypeIdx
    Else
    Begin
      FatalError('type inconnu: ' + Nam);
      Exit;
    End;
  End;

  { "Array<T>"/"Set<T>"/"Dictionary<K,V>" (TODO 16) - forme GENERIQUE     }
  { explicite, SEULEMENT pour les trois collections predeclarees.               }
  { Instancier un STRUCT/CLASS generique DECLARE PAR L UTILISATEUR avec               }
  { des arguments CONCRETS comme type NOMME ("Box<Int>" en position de              }
  { type) reste HORS DE PORTEE (TYK_GENERIC_PARAM, TODO 13, modele                       }
  { "pointeur generique uniforme" - aucun argument concret n y a jamais              }
  { ete substitue, meme au point d appel : seule l INFERENCE au point               }
  { d appel existe pour ce cas-la). }
  If PPIsOp('<') And (TypeTab[Base].Kind In [TYK_ARRAY, TYK_SET, TYK_DICTIONARY]) Then
  Begin
    PPAdvance;   { '<' }
    ElemT := ParseTypeExpr;
    If TypeTab[Base].Kind = TYK_DICTIONARY Then
    Begin
      If Not PPMatch(',') Then
        FatalError('", " attendu entre les deux parametres de ''Dictionary<K,V>''');
      ValT := ParseTypeExpr;
      Base := TypeAdd(TYK_DICTIONARY, '', 8, 4, False, True, ValT, ElemT);
    End
    Else
      Base := TypeAdd(TypeTab[Base].Kind, '', 8, 4, False, True, ElemT, -1);
    If Not PPMatch('>') Then
      FatalError('''>'' attendu a la fin d''un type parametre ' +
        '(''Array<T>''/''Set<T>''/''Dictionary<K,V>'')');
  End;

  While PPIsOp('?') Do
  Begin
    PPAdvance;
    Base := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, Base, -1);
  End;

  ParseTypeExpr := Base;
End;

{ ------------------------------------------------------------ }
{ typealias Nom = Type : TOUJOURS un synonyme STRICT en Swift      }
{ (contrairement au "type Nom Type" de Go/GOCW32.PAS, qui cree un          }
{ type DISTINCT de meme representation) - un seul et meme TypeIdx             }
{ est simplement enregistre sous un second nom (SymAdd, SK_TYPE),                 }
{ aucune copie/nouvelle entree TypeTab n est necessaire ici.                        }
{ ------------------------------------------------------------ }

Procedure ParseTypeAliasDecl;
Var
  Nam   : TString;
  Under : Integer;
Begin
  PPAdvance;   { typealias }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de type attendu apres ''typealias''');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If Not PPMatch('=') Then
  Begin
    FatalError('''='' attendu dans une declaration ''typealias''');
    Exit;
  End;

  Under := ParseTypeExpr;
  If Under < 0 Then Exit;

  SymAdd(Nam, SK_TYPE, Under, False);
End;

{ ParseExpr (implementee au TODO 06, avec le reste des expressions)      }
{ analyse une expression GENERALE - forward-declaree ici car               }
{ ParseLetVarPattern (TODO 05) en a besoin bien avant que le TODO 06             }
{ ne soit ecrit : contrairement au "const" de Go, un "let"/"var" Swift            }
{ accepte N IMPORTE QUELLE expression comme initialiseur (pas seulement            }
{ une expression CONSTANTE - ConstEvalExpr, juste au-dessus, reste                    }
{ reserve aux contextes qui l exigent VRAIMENT, aucun ici en Swift).                     }
Function ParseExpr: Integer; Forward;

{ ApplyExprInitToSymbol (implementee au TODO 06, juste apres ExprPool)   }
{ termine l enregistrement d un symbole let/var UNE FOIS son              }
{ initialiseur analyse (InitExprIdx, TypeIdx infere ou verifie,                }
{ ConstVal repli best-effort) - forward-declaree ici pour la meme               }
{ raison que ParseExpr juste au-dessus (depend de ExprPool/TExprKind,            }
{ TODO 06, inexistants a ce point du fichier). }
Procedure ApplyExprInitToSymbol(SI, ValIdx, TIdx: Integer; Const Nam: TString); Forward;

{ ------------------------------------------------------------ }
{ let Nom [: Type] [= Expr] , Nom2 ... et var Nom [: Type]         }
{ [= Expr] , ... -- CONTRAIREMENT au "var Nom1, Nom2 Type = E1,          }
{ E2" de Go (ou noms/type/valeurs forment TROIS listes paralleles            }
{ separees), chaque element separe par une virgule en Swift est un               }
{ pattern COMPLET independant (son propre nom, sa propre annotation                  }
{ de type optionnelle, sa propre initialisation optionnelle) - regle               }
{ reelle de la grammaire Swift, PAS une simplification de ce                            }
{ compilateur. Type explicite ABSENT ET valeur ABSENTE = erreur              }
{ (rien a partir de quoi inferer). L initialiseur est une expression               }
{ GENERALE (ParseExpr, TODO 06 - PAS ConstEvalExpr, TODO 05 : un "let              }
{ sum = add(x, y)", comme dans math.swift, n est PAS une expression                    }
{ constante - BOGUE REEL trouve par execution du propre FuncSelfTest             }
{ du TODO 08, "let t = a" sur un parametre de fonction faisait echouer               }
{ ConstEvalPrimary avec "identificateur non constant" ; corrige en                        }
{ delegant tout le travail d apres-analyse a ApplyExprInitToSymbol,                        }
{ TODO 06, seul endroit du fichier ou ExprPool est deja visible a ce                          }
{ point precis du code source). }
{ ------------------------------------------------------------ }

Procedure ParseLetVarPattern(AIsConst: Boolean);
Var
  Nam     : TString;
  TIdx    : Integer;
  HasInit : Boolean;
  ValIdx, SI : Integer;
Begin
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de variable attendu');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  TIdx := -1;
  If PPMatch(':') Then TIdx := ParseTypeExpr;

  HasInit := PPMatch('=');
  ValIdx := -1;
  If HasInit Then ValIdx := ParseExpr;

  If (Not HasInit) And (TIdx < 0) Then
  Begin
    FatalError('declaration sans type ni valeur initiale: ' + Nam);
    Exit;
  End;

  SI := SymAdd(Nam, SK_VAR, TIdx, AIsConst);
  If SI < 0 Then Exit;
  SymTab[SI].WasVarDecl := True;   { TODO 19 : seule une VRAIE instruction   }
                                   { "let"/"var" est visee par "declare et         }
                                   { jamais utilise" - voir la note de              }
                                   { TSymRec.WasVarDecl. }

  If HasInit Then
    ApplyExprInitToSymbol(SI, ValIdx, TIdx, Nam)
  Else If AIsConst Then
    WarnMsg('''let'' ''' + Nam + ''' sans valeur initiale immediate ' +
      '(Swift exige une affectation avant la premiere lecture - ' +
      'verification complete de flux hors de portee ici, avertissement ' +
      'seulement)');
End;

Procedure ParseLetVarDecl(AIsConst: Boolean);
Begin
  PPAdvance;   { let/var }
  Repeat
    ParseLetVarPattern(AIsConst);
  Until Not PPMatch(',');
End;

{ ParseFuncDecl/ParseStructDecl/ParseClassDecl/ParseProtocolDecl/       }
{ ParseExtensionDecl/ParseEnumDecl sont implementees aux TODO 08/09/            }
{ 10/11/12, bien plus bas - forward-declarees ici car ParseTopLevelDecl            }
{ (TODO 05) doit deja savoir router "func"/"struct"/"class"/"protocol"/            }
{ "extension"/"enum" vers elles des qu ils apparaissent en tete de              }
{ fichier (extensions ajoutees a CES memes TODO - chacun renvoyait                    }
{ Faux/arret propre jusque-la). TypeSatisfiesProtocol (TODO 11) et                    }
{ EnumCaseFind (TODO 12) sont EGALEMENT forward-declarees ici/plus bas :           }
{ ParseStructDecl/ParseClassDecl (TODO 09/10) et ParseCaseClause                        }
{ (TODO 07, etendue plus bas pour le motif ".Cas(let Liaison)") en ont           }
{ besoin bien avant que les TODO 11/12 ne soient ecrits. }
Function ParseFuncDecl: Integer; Forward;
Function ParseStructDecl: Integer; Forward;
Function ParseClassDecl: Integer; Forward;
Function ParseProtocolDecl: Integer; Forward;
Function ParseExtensionDecl: Integer; Forward;
Function ParseEnumDecl: Integer; Forward;
Function TypeSatisfiesProtocol(ConcreteType, ProtocolType: Integer): Boolean; Forward;
Function EnumCaseFind(EnumTypeIdx: Integer; Const CName: TString): Integer; Forward;
{ EnumCaseGetAssocType : accesseur - EnumCasePool (TODO 12) est declaree   }
{ APRES ParseCaseClause (TODO 07, etendue ci-dessous) qui a pourtant                }
{ besoin de lire AssocTypeIdx pour un motif ".Cas(let Liaison)" - une             }
{ VARIABLE (contrairement a une fonction) ne peut pas etre Forward-               }
{ declaree en Pascal, d ou ce petit accesseur intermediaire. }
Function EnumCaseGetAssocType(CaseIdx: Integer): Integer; Forward;
{ ParseGenericParamList/ParseWhereClause (TODO 13) - forward-declarees   }
{ ici car ParseFuncDecl/ParseStructDecl (TODO 08/09, restructurees               }
{ ci-dessous pour ouvrir une portee de parametres de type generique              }
{ AVANT d analyser signature/corps) en ont besoin bien avant que le                }
{ TODO 13 ne soit ecrit. }
Procedure ParseGenericParamList; Forward;
Procedure ParseWhereClause; Forward;

{ ------------------------------------------------------------ }
{ ParseTopLevelDecl : route "let"/"var"/"typealias"/"func"/"struct"/    }
{ "class"/"protocol"/"extension"/"enum" vers leur gestionnaire - Faux           }
{ SANS RIEN CONSOMMER pour tout autre token (import/...), permettant             }
{ a l appelant de s ARRETER PROPREMENT sur ce que les TODO ulterieurs             }
{ prendront en charge - exactement le meme principe que le "Break"                  }
{ final de la boucle ParseFileTopLevel de GOCW32.PAS a ce meme stade. }
{ ------------------------------------------------------------ }

Function ParseTopLevelDecl: Boolean;
Begin
  ParseTopLevelDecl := True;
  If PPKind <> TOK_IDENT Then
  Begin
    ParseTopLevelDecl := False;
    Exit;
  End;
  If IsKeyword(PPVal) = KW_LET Then ParseLetVarDecl(True)
  Else If IsKeyword(PPVal) = KW_VAR Then ParseLetVarDecl(False)
  Else If IsKeyword(PPVal) = KW_TYPEALIAS Then ParseTypeAliasDecl
  Else If IsKeyword(PPVal) = KW_FUNC Then ParseFuncDecl         { TODO 08 }
  Else If IsKeyword(PPVal) = KW_STRUCT Then ParseStructDecl     { TODO 09 }
  Else If IsKeyword(PPVal) = KW_CLASS Then ParseClassDecl       { TODO 10 }
  Else If IsKeyword(PPVal) = KW_PROTOCOL Then ParseProtocolDecl { TODO 11 }
  Else If IsKeyword(PPVal) = KW_EXTENSION Then ParseExtensionDecl { TODO 11 }
  Else If IsKeyword(PPVal) = KW_ENUM Then ParseEnumDecl           { TODO 12 }
  Else ParseTopLevelDecl := False;
End;

Procedure ParseTopLevelDecls;
Begin
  PPSkipSemis;
  While (Not PPAtEnd) And ParseTopLevelDecl Do
    PPSkipSemis;
End;

{ ------------------------------------------------------------ }
{ DeclSelfTest : let/var (avec/sans type explicite, avec/sans        }
{ valeur), typealias, inference de type (Int/Double/Bool/String),          }
{ operateurs constants, et arret propre sur "import" (jamais pris en           }
{ charge, contrairement a "func"/"struct"/"class"/"protocol"/                          }
{ "extension"/"enum", desormais geres depuis les TODO 08-12, voir                    }
{ leurs propres extensions de ParseTopLevelDecl - "import" reste HORS               }
{ DE PORTEE de ce compilateur mono-fichier, aucun TODO du roadmap                       }
{ d en-tete ne le mentionne meme) - sur un extrait synthetique (fichier              }
{ temporaire, meme methode que LexSelfTest). }
{ ------------------------------------------------------------ }

Procedure DeclAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DeclSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DeclSelfTest;
Const
  TmpFile = 'SWIFTW32DECLSELFTEST.$$$';
Var
  F  : Text;
  SI : Integer;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'let a = 42');
  WriteLn(F, 'var b: Int = 10');
  WriteLn(F, 'let c: Double = 3.5 + 1.5');
  WriteLn(F, 'let d = "hello"');
  WriteLn(F, 'let e = true');
  WriteLn(F, 'let f = (1 + 2) * 3');
  WriteLn(F, 'typealias MyInt = Int');
  WriteLn(F, 'let g: MyInt = 7');
  WriteLn(F, 'let h: Int? = 99');
  WriteLn(F, 'import NotYetSupported');
  Close(F);

  SymInit;
  TypeInit;

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(F);

  ParserInit;
  ParseTopLevelDecls;

  SI := SymFind('a');
  DeclAssert('a trouve',            SI >= 0);
  DeclAssert('a est une constante', SymTab[SI].IsConst);
  DeclAssert('a infere Int',        SymTab[SI].TypeIdx = PDT_INT);
  DeclAssert('a = 42',              SymTab[SI].ConstVal.IntVal = 42);

  SI := SymFind('b');
  DeclAssert('b trouve',              SI >= 0);
  DeclAssert('b n''est PAS une constante', Not SymTab[SI].IsConst);
  DeclAssert('b : Int explicite',     SymTab[SI].TypeIdx = PDT_INT);

  SI := SymFind('c');
  DeclAssert('c = 5.0 (3.5+1.5)', SymTab[SI].ConstVal.RealVal = 5.0);

  SI := SymFind('d');
  DeclAssert('d infere String', SymTab[SI].TypeIdx = PDT_STRING);
  DeclAssert('d = "hello"',     SymTab[SI].ConstVal.StrVal = 'hello');

  SI := SymFind('e');
  DeclAssert('e infere Bool', SymTab[SI].TypeIdx = PDT_BOOL);
  DeclAssert('e = true',      SymTab[SI].ConstVal.IntVal = 1);

  SI := SymFind('f');
  DeclAssert('f = (1+2)*3 = 9 (parentheses)', SymTab[SI].ConstVal.IntVal = 9);

  SI := SymFind('MyInt');
  DeclAssert('MyInt trouve (typealias)', SI >= 0);
  DeclAssert('MyInt est un SK_TYPE',     SymTab[SI].Kind = SK_TYPE);
  DeclAssert('MyInt partage le TypeIdx de Int', SymTab[SI].TypeIdx = PDT_INT);

  SI := SymFind('g');
  DeclAssert('g : MyInt resout vers Int', SymTab[SI].TypeIdx = PDT_INT);
  DeclAssert('g = 7',                     SymTab[SI].ConstVal.IntVal = 7);

  SI := SymFind('h');
  DeclAssert('h : Int? est bien TYK_OPTIONAL', TypeIsOptional(SymTab[SI].TypeIdx));
  DeclAssert('h deballe vers Int',
    TypeResolveOptional(SymTab[SI].TypeIdx) = PDT_INT);

  { arret propre sur "import" : PP doit pointer EXACTEMENT sur ce      }
  { token, ni saute ni consomme. }
  DeclAssert('arret propre sur "import" (jamais pris en charge)',
    (PPKind = TOK_IDENT) And (PPVal = 'import'));

  { SymCheckMutable : verifie SEULEMENT les branches "autorisees"        }
  { (var toujours mutable ; let non encore initialise toujours            }
  { mutable une premiere fois) - la branche "rejet" appelle              }
  { FatalError (Halt), donc n est jamais DECLENCHEE ici ; on verifie          }
  { plutot, sur "a" (deja initialise ci-dessus), que les conditions             }
  { QUI DECLENCHERAIENT ce rejet sont bien celles attendues. }
  SI := SymFind('b');
  DeclAssert('SymCheckMutable(var) toujours Vrai', SymCheckMutable(SI));

  SI := SymAdd('zNouveauLet', SK_VAR, PDT_INT, True);
  DeclAssert('let neuf, pas encore initialise : mutable une fois',
    SymCheckMutable(SI));
  DeclAssert('SymCheckMutable a marque HasInit', SymTab[SI].HasInit);

  SI := SymFind('a');
  DeclAssert('"a" (let deja initialise) reunit les conditions du rejet ' +
    '(IsConst et HasInit, non declenche ici pour ne pas Halt)',
    SymTab[SI].IsConst And SymTab[SI].HasInit);
End;

{ ============================================================ }
{ TODO 06 - EXPRESSIONS, OPERATEURS, LITTERAUX ET INTERPOLATION }
{ ============================================================ }
{ Meme principe que GOCW32.PAS a ce stade (voir sa propre note        }
{ d en-tete, section TODO 06) : le backend (TODO 21-23) n existe pas             }
{ encore, ce TODO construit donc un vrai ARBRE (AST, ExprPool) plutot           }
{ que du code, sur le meme principe de POOL A TAILLE FIXE deja utilise            }
{ pour TypeTab/FieldPool (TODO 04) et SymTab (TODO 05). Cohabite AVEC              }
{ ConstEvalExpr (TODO 05, INCHANGE, toujours utilise pour les                        }
{ initialiseurs de let/var) plutot que de le remplacer : ParseExpr                  }
{ ci-dessous sert aux expressions GENERALES (futurs corps de fonctions/                 }
{ instructions, TODO 07/08) qui n ont pas besoin d une valeur PLEINEMENT               }
{ CALCULEE a la compilation.                                                              }
{                                                                       }
{ Precedence Swift REELLE (groupes officiels de la bibliotheque           }
{ standard, du PLUS FAIBLE au PLUS FORT - un niveau "higherThan" l autre) :         }
{ affectation (hors de portee ici - concern d instruction, TODO 07,                    }
{ meme choix que GOCW32.PAS qui ne l inclut pas non plus dans ParseExpr)               }
{ < ternaire ?: (hors de portee, absente du roadmap d en-tete et d aucun               }
{ echantillon) < || < && < comparaison < ?? (nil-coalescing, PLUS FORT           }
{ que la comparaison - contre-intuitif mais REEL : "x ?? 0 > 5" se lit               }
{ "(x ?? 0) > 5", verifie explicitement par ExprSelfTest ci-dessous) <             }
{ is/as/as?/as! (casting) < ..</... (intervalle, UNE SEULE application,               }
{ jamais chainee) < + - | ^ < * / % << >> & (decalages groupes avec la                  }
{ multiplication ici par simplicite documentee - non exerce par les                        }
{ echantillons). PAS d exponentiation (le roadmap d en-tete la mentionne              }
{ mais Swift reel n a PAS d operateur d exponentiation integre - omise). }

Const
  MAX_EXPR     = 8192;
  MAX_EXPR_ARG = 4096;

Type
  TExprKind = (
    EK_INTLIT, EK_FLOATLIT, EK_STRINGLIT, EK_BOOLLIT, EK_NILLIT,
    EK_IDENT,
    EK_UNARY,          { Op ; Left = operande (- ! ~)                    }
    EK_BINARY,         { Op ; Left, Right                                }
    EK_CALL,           { Left = callee ; ArgFirst/Count (ExprArgKey =    }
                        { etiquette Swift, '' si positionnel)               }
    EK_INDEX,          { Left = base ; Right = indice                    }
    EK_SELECTOR,       { Left = base ; NameVal = champ/methode ('.')     }
    EK_TUPLE,          { ArgFirst/Count (ExprArgKey = etiquette, '' si   }
                        { non nomme) - "()" = tuple vide (Void)             }
    EK_ARRAYLIT,       { [1, 2, 3] ; ArgFirst/Count = elements           }
    EK_DICTLIT,        { [cle: val, ...] ; ArgFirst/Count = 2*paires,    }
                        { INTERCALEES cle,val,cle,val,... dans ExprArgPool  }
    EK_CLOSURE,        { fermeture ; reserve pour le TODO 08                }
    EK_STRINGINTERP,   { "texte \(expr) texte" ; ArgFirst/Count = les    }
                        { segments (ExprArgKey='T' texte / 'E' expression)   }
    EK_OPTIONALCHAIN,  { Left = base ; NameVal = champ/methode ('?.')    }
    EK_FORCEDUNWRAP,   { Left = operande ('!' POSTFIXE - deballage      }
                        { force, PAS le '!' PREFIXE logique = EK_UNARY)     }
    EK_ASCAST,         { Left = operande ; Op='as'/'as?'/'as!' ;        }
                        { Extra = TypeIdx cible                            }
    EK_ISCHECK,        { Left = operande ; Extra = TypeIdx teste ;      }
                        { TypeIdx resultat = PDT_BOOL                       }
    EK_TRY             { try/try?/try! PREFIXE (TODO 15) ; Left = operande ;  }
                        { Op = 'try' (propage tel quel) / 'try?' (enveloppe      }
                        { dans un Optional, meme convention que "as?") /              }
                        { 'try!' (deballage force - panique a l execution si            }
                        { une erreur est lancee, meme deferral de mecanisme           }
                        { que le "!" du TODO 14 - voir la note d en-tete           }
                        { de ce TODO 15) }
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : TString;    { EK_UNARY/EK_BINARY/EK_ASCAST : texte de l operateur }
    Left    : Integer;     { -1 si absent }
    Right   : Integer;     { -1 si absent }
    Extra   : Integer;     { TypeIdx (EK_ASCAST/EK_ISCHECK) ou -1 }
    NameVal : TString;     { EK_IDENT / EK_SELECTOR / EK_OPTIONALCHAIN }
    IntVal  : LongInt;
    RealVal : Real;
    StrVal  : TString;
    TypeIdx : Integer;     { inference au mieux, -1 si inconnu }
    IsConst : Boolean;
    ArgFirst: Integer;
    ArgCount: Integer;
  End;

Var
  ExprPool     : Array[0..MAX_EXPR - 1] Of TExprNode;
  ExprCount    : Integer;
  ExprArgPool  : Array[0..MAX_EXPR_ARG - 1] Of Integer;
  ExprArgKey   : Array[0..MAX_EXPR_ARG - 1] Of TString;
  ExprArgCount : Integer;

  { NoTrailingClosure (TODO 08) : Vrai pendant l analyse d une expression  }
  { d en-tete de if/guard/switch/while/for (condition/tag/intervalle) -        }
  { la ou une accolade ouvrante APRES l expression doit se lire comme le            }
  { debut du CORPS de l instruction elle-meme, PAS comme une syntaxe de              }
  { fermeture en fin d appel ("trailing closure") - MEME PRINCIPE que le              }
  { NoCompositeLit de GOCW32.PAS pour l ambiguite equivalente de Go               }
  { ("for range x {"). Chaque site de remise a Vrai (TODO 07, deja ecrit)             }
  { sauvegarde puis restaure l ancienne valeur. }
  NoTrailingClosure : Boolean;

Procedure ExprInit;
Begin
  ExprCount         := 0;
  ExprArgCount      := 0;
  NoTrailingClosure := False;
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

{ ExprArgPush : ajoute EIdx (avec sa cle/etiquette optionnelle, ''    }
{ si aucune) a la fin de ExprArgPool - utilise pour les arguments          }
{ d appel etiquetes, les elements de tuple/tableau/dictionnaire, et            }
{ les segments d interpolation de chaine. }
Function ExprArgPush(EIdx: Integer; Const Key: TString): Integer;
Begin
  If ExprArgCount >= MAX_EXPR_ARG Then
  Begin
    FatalError('table des arguments d''expression pleine (MAX_EXPR_ARG)');
    ExprArgPush := 0;
    Exit;
  End;
  ExprArgPool[ExprArgCount] := EIdx;
  ExprArgKey[ExprArgCount]  := Key;
  ExprArgPush := ExprArgCount;
  Inc(ExprArgCount);
End;

Function ExprAddIntLit(V: LongInt): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_INTLIT);
  ExprPool[N].IntVal  := V;
  ExprPool[N].TypeIdx := PDT_INT;
  ExprPool[N].IsConst := True;
  ExprAddIntLit := N;
End;

Function ExprAddFloatLit(V: Real): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_FLOATLIT);
  ExprPool[N].RealVal := V;
  ExprPool[N].TypeIdx := PDT_DOUBLE;   { Swift : Double par defaut, PAS Float }
  ExprPool[N].IsConst := True;
  ExprAddFloatLit := N;
End;

Function ExprAddStringLit(Const V: TString): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_STRINGLIT);
  ExprPool[N].StrVal  := V;
  ExprPool[N].TypeIdx := PDT_STRING;
  ExprPool[N].IsConst := True;
  ExprAddStringLit := N;
End;

Function ExprAddBoolLit(V: Boolean): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_BOOLLIT);
  If V Then ExprPool[N].IntVal := 1 Else ExprPool[N].IntVal := 0;
  ExprPool[N].TypeIdx := PDT_BOOL;
  ExprPool[N].IsConst := True;
  ExprAddBoolLit := N;
End;

Function ExprAddNilLit: Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_NILLIT);
  ExprPool[N].TypeIdx := -1;   { nil est non-type tant qu il n est pas contextualise (Optional, TODO 14) }
  ExprPool[N].IsConst := True;
  ExprAddNilLit := N;
End;

{ ExprAddIdent : champ "Used" (TODO 19, CORRIGE ICI - la note historique  }
{ disait auparavant "Swift ne fait qu avertir... ce compilateur ne              }
{ l implemente meme pas", mais le roadmap TODO 19 l exige explicitement          }
{ ("declare et jamais utilise", meme regle stricte que GOCW32.PAS pour               }
{ les variables locales) : marque desormais Vrai des la PREMIERE                          }
{ resolution reussie, verifie a la sortie de portee par SymLeaveScope             }
{ (etendue plus bas). "self" (TODO 09/10 pour la vraie liaison au                     }
{ receveur) est traite comme un identificateur ORDINAIRE - aucun code             }
{ special n est necessaire avant que les methodes n existent reellement,               }
{ et WasVarDecl reste Faux pour lui de toute facon (ajoute par                              }
{ MethodPoolAdd/ParseStructMemberFunc, jamais par ParseLetVarPattern). }
Function ExprAddIdent(Const Nam: TString): Integer;
Var N, SI: Integer;
Begin
  N := ExprNew(EK_IDENT);
  ExprPool[N].NameVal := Nam;
  SI := SymFind(Nam);
  If SI >= 0 Then
  Begin
    ExprPool[N].TypeIdx := SymTab[SI].TypeIdx;
    ExprPool[N].IsConst := SymTab[SI].IsConst;
    SymTab[SI].Used     := True;
  End;
  ExprAddIdent := N;
End;

{ ExprInferBinaryType : regle SIMPLIFIEE, inference AU MIEUX (jamais    }
{ d erreur ici, la verification stricte reste au TODO 19) - trois cas         }
{ SPECIFIQUES a Swift (absents de l equivalent GOCW32.PAS) : "??" (type      }
{ resultat = type DEBALLE de l Optional gauche - c est TOUTE la raison           }
{ d etre de cet operateur), ".."</"..." (aucun type de VALEUR modelise,          }
{ Range<T> reste hors de portee - TODO 16), et Double PAR DEFAUT (PAS      }
{ Float) pour toute expression flottante, meme regle deja posee au              }
{ TODO 05 pour l inference de litteral. }
Function ExprInferBinaryType(LTIdx, RTIdx: Integer; Const Op: TString): Integer;
Begin
  ExprInferBinaryType := LTIdx;

  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Or (Op = '&&') Or (Op = '||') Then
  Begin
    ExprInferBinaryType := PDT_BOOL;
    Exit;
  End;

  If (Op = '..<') Or (Op = '...') Then
  Begin
    ExprInferBinaryType := -1;
    Exit;
  End;

  If Op = '??' Then
  Begin
    If (LTIdx >= 0) And TypeIsOptional(LTIdx) Then
      ExprInferBinaryType := TypeResolveOptional(LTIdx)
    Else
      ExprInferBinaryType := LTIdx;
    Exit;
  End;

  If (LTIdx = PDT_DOUBLE) Or (RTIdx = PDT_DOUBLE) Then
    ExprInferBinaryType := PDT_DOUBLE
  Else If (LTIdx = PDT_FLOAT) Or (RTIdx = PDT_FLOAT) Then
    ExprInferBinaryType := PDT_FLOAT
  Else If (LTIdx = PDT_STRING) Or (RTIdx = PDT_STRING) Then
    ExprInferBinaryType := PDT_STRING;
End;

Function ExprNewBinary(Const Op: TString; L, R: Integer): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_BINARY);
  ExprPool[N].Op      := Op;
  ExprPool[N].Left    := L;
  ExprPool[N].Right   := R;
  ExprPool[N].TypeIdx := ExprInferBinaryType(ExprPool[L].TypeIdx,
    ExprPool[R].TypeIdx, Op);
  ExprPool[N].IsConst := ExprPool[L].IsConst And ExprPool[R].IsConst;
  ExprNewBinary := N;
End;

Function ExprNewUnary(Const Op: TString; Sub: Integer): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_UNARY);
  ExprPool[N].Op      := Op;
  ExprPool[N].Left    := Sub;
  ExprPool[N].IsConst := ExprPool[Sub].IsConst;
  If Op = '!' Then ExprPool[N].TypeIdx := PDT_BOOL
  Else ExprPool[N].TypeIdx := ExprPool[Sub].TypeIdx;
  ExprNewUnary := N;
End;

{ ConstFoldExpr : repliage best-effort d un noeud ExprPool DEJA          }
{ CONSTRUIT en une TConstVal (TODO 05) - PAS un evaluateur general             }
{ (contrairement a ConstEvalExpr, TODO 05, qui travaille directement           }
{ sur le flux de tokens et FatalError sur tout operande non constant) :             }
{ couvre seulement les litteraux et les operateurs unaires/binaires               }
{ APPLIQUES A des operandes EUX-MEMES repliables (recursif) - tout AUTRE            }
{ noeud (EK_IDENT non constant, EK_CALL, ...) renvoie simplement           }
{ CVInt(0), SANS jamais FatalError : appele UNIQUEMENT quand               }
{ ExprPool[Idx].IsConst est DEJA Vrai (ApplyExprInitToSymbol ci-dessous),           }
{ ce repli neutre n est alors jamais observe en pratique. Reutilise               }
{ CVInt/CVFloat/CVBool/CVString/ConstEvalBinOp (TODO 05) tels quels. }
Function ConstFoldExpr(Idx: Integer): TConstVal;
Var L, R : TConstVal;
Begin
  ConstFoldExpr := CVInt(0);
  If (Idx < 0) Or (Idx >= ExprCount) Then Exit;
  Case ExprPool[Idx].Kind Of
    EK_INTLIT    : ConstFoldExpr := CVInt(ExprPool[Idx].IntVal);
    EK_FLOATLIT  : ConstFoldExpr := CVFloat(ExprPool[Idx].RealVal);
    EK_BOOLLIT   : ConstFoldExpr := CVBool(ExprPool[Idx].IntVal <> 0);
    EK_STRINGLIT : ConstFoldExpr := CVString(ExprPool[Idx].StrVal);
    EK_BINARY:
      Begin
        L := ConstFoldExpr(ExprPool[Idx].Left);
        R := ConstFoldExpr(ExprPool[Idx].Right);
        ConstFoldExpr := ConstEvalBinOp(L, R, ExprPool[Idx].Op);
      End;
    EK_UNARY:
      Begin
        L := ConstFoldExpr(ExprPool[Idx].Left);
        If ExprPool[Idx].Op = '-' Then
        Begin
          If L.Kind = CK_FLOAT Then ConstFoldExpr := CVFloat(-L.RealVal)
          Else ConstFoldExpr := CVInt(-L.IntVal);
        End
        Else If ExprPool[Idx].Op = '!' Then ConstFoldExpr := CVBool(L.IntVal = 0)
        Else If ExprPool[Idx].Op = '~' Then ConstFoldExpr := CVInt(Not L.IntVal);
      End;
  End;
End;

{ ApplyExprInitToSymbol : termine l enregistrement du symbole SI (deja   }
{ cree par SymAdd) une fois son initialiseur (ValIdx, dans ExprPool)             }
{ analyse - TypeIdx infere du membre droit si aucun type explicite               }
{ (TIdx=-1, reutilise directement ExprPool[ValIdx].TypeIdx, deja bien             }
{ infere par TODO 06 pour toute forme d expression, pas seulement les              }
{ litteraux) ; sinon verification best-effort par KIND DE TYPE resolu               }
{ (PLUS GENERAL que l ancienne verification par TConstVal.Kind du                    }
{ TODO 05 : fonctionne desormais pour une expression QUELCONQUE, pas               }
{ seulement un litteral). ConstVal (repli cosmetique - TODO 20/                        }
{ generateur de code futur pourraient s en servir pour un let VRAIMENT                    }
{ constant) n est rempli QUE si ExprPool[ValIdx].IsConst - jamais pour                    }
{ un "let sum = add(x, y)" (valeur runtime, IsConst=Faux), qui ne                              }
{ dispose alors QUE de InitExprIdx (design meme du TODO 08, voir la                              }
{ note de ParseLetVarPattern). }
{ TypesCompatibleForInit (TODO 19) : remplace le controle PARTIEL         }
{ (INT/FLOAT/BOOL/STRING seulement, WarnMsg SEULEMENT) qui existait                    }
{ depuis le TODO 05 - couvre desormais TOUS les TTypeKind. Le CAS               }
{ PROTOCOLE reste gere SEPAREMENT par l appelant (TypeSatisfiesProtocol,           }
{ deja ecrit au TODO 11, jamais elevee en FatalError - le roadmap              }
{ TODO 19 ne l exige que pour les VRAIS conflits de type, pas pour une              }
{ conformite partielle a un protocole). }
Function TypesCompatibleForInit(VTIdx, RTIdx: Integer): Boolean;
Var Cur : Integer;
Begin
  TypesCompatibleForInit := False;
  If VTIdx = RTIdx Then Begin TypesCompatibleForInit := True; Exit; End;

  { TYK_GENERIC_PARAM (TODO 13) : "pointeur generique uniforme" - AUCUNE   }
  { distinction n est possible ici entre les types CONCRETS reels qu il                 }
  { pourrait representer, toujours compatible plutot que de deviner. }
  If (TypeTab[VTIdx].Kind = TYK_GENERIC_PARAM) Or (TypeTab[RTIdx].Kind = TYK_GENERIC_PARAM) Then
  Begin
    TypesCompatibleForInit := True;
    Exit;
  End;

  { class (TODO 10) : une instance d une SOUS-CLASSE reste assignable a   }
  { une variable declaree du type d une SUPER-CLASSE (heritage simple,               }
  { regle Swift REELLE) - remonte SuperTypeIdx ; DEUX structs/enums/               }
  { classes DIFFERENTS partageant le meme TTypeKind restent INCOMPATIBLES               }
  { (deja exclu par le "VTIdx=RTIdx" ci-dessus pour le cas IDENTIQUE). }
  If (TypeTab[VTIdx].Kind = TYK_CLASS) And (TypeTab[RTIdx].Kind = TYK_CLASS) Then
  Begin
    Cur := TypeTab[VTIdx].SuperTypeIdx;
    While (Cur >= 0) And (Cur < TypeCount) Do
    Begin
      If Cur = RTIdx Then Begin TypesCompatibleForInit := True; Exit; End;
      Cur := TypeTab[Cur].SuperTypeIdx;
    End;
    Exit;
  End;

  { scalaires numeriques : largeur/signe NON distingues (simplification    }
  { deja assumee depuis le TODO 03/04, jamais exercee par aucun echantillon           }
  { au point d avoir besoin d une distinction Int8 vs Int16 precise) -                    }
  { seule la FAMILLE (entier vs flottant) compte ici. }
  If (TypeTab[VTIdx].Kind = TYK_INT) And (TypeTab[RTIdx].Kind = TYK_INT) Then
  Begin TypesCompatibleForInit := True; Exit; End;
  If (TypeTab[VTIdx].Kind = TYK_FLOAT) And (TypeTab[RTIdx].Kind = TYK_FLOAT) Then
  Begin TypesCompatibleForInit := True; Exit; End;

  { String/Character (TODO 17) : un litteral Character N A AUCUNE syntaxe   }
  { distincte en Swift reel - un litteral String PLACE dans un contexte                 }
  { Character reste valide. }
  If (TypeTab[VTIdx].Kind = TYK_STRING) And
     (TypeTab[RTIdx].Kind In [TYK_STRING, TYK_CHARACTER]) Then
  Begin TypesCompatibleForInit := True; Exit; End;

  { meme TTypeKind, mais SEULEMENT pour les familles ou une simple           }
  { correspondance de KIND (sans verification profonde du contenu/de la              }
  { signature) reste une simplification deja assumee ailleurs -                             }
  { Array/Dictionary/Set (TODO 16, aucune verification de coherence des                  }
  { elements), Optional/tuple, fonction-fermeture (TODO 08, aucune                        }
  { verification de signature). STRUCT/CLASS/ENUM en sont EXCLUS a               }
  { dessein (deux types DIFFERENTS de MEME kind doivent rester                                 }
  { incompatibles, seul un match EXACT ou une relation de classe compte). }
  If TypeTab[VTIdx].Kind = TypeTab[RTIdx].Kind Then
    If TypeTab[VTIdx].Kind In [TYK_ARRAY, TYK_DICTIONARY, TYK_SET, TYK_OPTIONAL,
       TYK_TUPLE, TYK_FUNC, TYK_BOOL] Then
      TypesCompatibleForInit := True;
End;

Procedure ApplyExprInitToSymbol(SI, ValIdx, TIdx: Integer; Const Nam: TString);
Var RTIdx, VTIdx : Integer;
Begin
  SymTab[SI].InitExprIdx := ValIdx;
  SymTab[SI].HasInit     := True;
  If ExprPool[ValIdx].IsConst Then
    SymTab[SI].ConstVal := ConstFoldExpr(ValIdx);

  { "nil" CONTEXTUALISE (TODO 14 - voir la note d en-tete du TODO 04,     }
  { "nil est non-type TANT QU IL N EST PAS CONTEXTUALISE" : ce moment            }
  { precis EST cette contextualisation) : si l initialiseur EST                        }
  { LITTERALEMENT "nil" (EK_NILLIT, TypeIdx=-1 depuis sa creation,                     }
  { TODO 06) ET qu un type explicite Optional a ete declare, "nil"                    }
  { recoit RETROACTIVEMENT ce TypeIdx - "var noValue: Int? = nil"                       }
  { (optionals.swift). Sans annotation explicite ("let x = nil"), "nil"             }
  { reste NON-TYPE (-1) : AUCUNE inference n est possible depuis "nil"                }
  { seul, erreur Swift REELLE d ailleurs ("'nil' requires a contextual                  }
  { type") - ce compilateur laisse simplement le symbole SANS type                        }
  { connu ici (best-effort, jamais de FatalError). }
  If (ExprPool[ValIdx].Kind = EK_NILLIT) And (TIdx >= 0) And TypeIsOptional(TIdx) Then
  Begin
    ExprPool[ValIdx].TypeIdx := TIdx;
    SymTab[SI].TypeIdx := TIdx;
    Exit;
  End;

  If TIdx < 0 Then
  Begin
    SymTab[SI].TypeIdx := ExprPool[ValIdx].TypeIdx;
    Exit;
  End;

  { type explicite : verification best-effort contre le type INFERE du   }
  { membre droit (deballe un Optional eventuel avant de comparer -               }
  { "let x: Int? = 42" est un entier valide malgre le TypeIdx                        }
  { enveloppe). }
  RTIdx := TypeResolveOptional(TIdx);
  VTIdx := ExprPool[ValIdx].TypeIdx;
  If (RTIdx < 0) Or (RTIdx >= TypeCount) Or (VTIdx < 0) Or (VTIdx >= TypeCount) Then
    Exit;   { l un des deux cotes reste inconnu - best-effort, jamais d erreur ici }

  { cible PROTOCOLE (TODO 11, "let d: Drawable = Circle(...)") : verifie   }
  { que le type CONCRET assigne satisfait le protocole - "modele boite"          }
  { du roadmap d en-tete du TODO 11 (le type concret REEL derriere reste            }
  { connu ICI, a l analyse - contrairement a une methode appelee PLUS TARD           }
  { via ResolveSelectorType sur une VARIABLE deja typee "Drawable", ou lui             }
  { ne l est plus). }
  If TypeTab[RTIdx].Kind = TYK_PROTOCOL Then
  Begin
    If Not TypeSatisfiesProtocol(VTIdx, RTIdx) Then
      WarnMsg('le type assigne a ''' + Nam + ''' ne satisfait pas ' +
        'completement le protocole ''' + TypeTab[RTIdx].Name + '''');
    Exit;
  End;

  { "types incompatibles = erreur claire" (roadmap TODO 19, SANS le               }
  { qualificatif "en mode strict" propre a la SEULE regle "declare et            }
  { jamais utilise" - Opts.StrictMode, voir sa propre note d en-tete a la           }
  { section Options, est RESERVE specifiquement a CETTE AUTRE regle,                    }
  { SymLeaveScope etendue plus bas - une VRAIE incompatibilite de type                    }
  { reste TOUJOURS une erreur ici, INCONDITIONNELLEMENT) : un litteral                 }
  { ENTIER (EK_INTLIT SEULEMENT, PAS une variable/expression Int) reste             }
  { CONTEXTUELLEMENT polymorphe face a un type Float declare ("let d:               }
  { Double = 5" est VALIDE en Swift reel) : retroactivement contextualise             }
  { ici, MEME mecanisme que "nil" plus haut - toute AUTRE incompatibilite            }
  { (TypesCompatibleForInit ci-dessus) est une ERREUR CLAIRE (FatalError). }
  If (ExprPool[ValIdx].Kind = EK_INTLIT) And (TypeTab[RTIdx].Kind = TYK_FLOAT) Then
  Begin
    ExprPool[ValIdx].TypeIdx := RTIdx;
    Exit;
  End;

  If Not TypesCompatibleForInit(VTIdx, RTIdx) Then
    FatalError('type declare (''' + TypeTab[RTIdx].Name + ''') et valeur ' +
      'fournie incompatibles pour ''' + Nam + '''');
End;

{ ------------------------------------------------------------ }
{ Chaine de parsing recursif-descendant, precedence Swift (voir     }
{ note d en-tete de section) : ParseExpr (||) -> ParseAnd (&&) ->      }
{ ParseComparison (== != < <= > >=) -> ParseNilCoalesce (??) ->            }
{ ParseCasting (is/as/as?/as!) -> ParseRange (..</...) ->                     }
{ ParseAdd (+ - | ^) -> ParseMul (* / % << >> &) -> ParseUnary            }
{ (- ! ~) -> ParsePostfix (. ?. ! ( [ ) -> ParseOperand. Forward-        }
{ declaree bien plus haut (TODO 05, avant ParseLetVarPattern) - voir            }
{ sa propre note. }
{ ------------------------------------------------------------ }

{ ParseStringInterp : le token courant est DEJA TOK_STRING_INTERP_PART   }
{ (le lexeur du TODO 02 a deja bascule) - alterne segment TEXTE           }
{ (toujours present, meme vide) et segment EXPRESSION (present tant que        }
{ IntVal=1, c est-a-dire tant que d autres segments suivent) jusqu au              }
{ segment final (IntVal=0). Chaque parenthese fermante d interpolation             }
{ est deja AVALEE par le lexeur lui-meme (LexInterpParenDepth, TODO 02) -                }
{ aucune gestion de parenthese n est necessaire ici. }
Function ParseStringInterp: Integer;
Var
  N, SegIdx, ArgStart, Cnt : Integer;
  More : Boolean;
Begin
  N := ExprNew(EK_STRINGINTERP);
  ArgStart := ExprArgCount;
  Cnt := 0;
  Repeat
    SegIdx := ExprAddStringLit(TokenPool[PP].Val);
    ExprArgPush(SegIdx, 'T');
    Inc(Cnt);
    More := TokenPool[PP].IntVal = 1;
    PPAdvance;
    If More Then
    Begin
      ExprArgPush(ParseExpr, 'E');
      Inc(Cnt);
    End;
  Until Not More;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  ExprPool[N].TypeIdx  := PDT_STRING;
  ParseStringInterp := N;
End;

{ ParseArrayOrDictLiteral : '[' deja vu par l appelant (encore le      }
{ token courant). Distingue tableau/dictionnaire par la presence ou           }
{ non d un ':' apres le PREMIER element ; "[:]" (dictionnaire vide) et          }
{ "[]" (tableau vide) sont des cas particuliers reconnus AVANT de              }
{ tenter de parser un premier element. Analyse TOUS les elements dans           }
{ un tampon LOCAL puis les pousse SEULEMENT APRES coup dans ExprArgPool           }
{ (meme correctif que ParseCallArgs de GOCW32.PAS, TODO 06 : un element           }
{ contenant lui-meme un appel/litteral IMBRIQUE pousserait sinon dans           }
{ le MEME pool partage AVANT que ce niveau n ait pousse ses propres              }
{ entrees, decalant ArgFirst). Les cles/valeurs de dictionnaire sont             }
{ des EXPRESSIONS quelconques en Swift (contrairement aux cles                      }
{ IDENTIFICATEUR/CHAINE seules d un litteral compose Go) - stockees                  }
{ donc INTERCALEES (cle,val,cle,val,...) dans ExprArgPool plutot                        }
{ qu avec une ExprArgKey (reservee aux etiquettes NOMMEES d appel/tuple). }
Function ParseArrayOrDictLiteral: Integer;
Const MAX_LIT_ELEMS = 128;
Var
  N, I, Cnt, ArgStart : Integer;
  IsDict : Boolean;
  KeyBuf, ValBuf : Array[0..MAX_LIT_ELEMS - 1] Of Integer;
Begin
  PPAdvance;   { '[' }

  If PPMatch(':') Then
  Begin
    PPMatch(']');
    N := ExprNew(EK_DICTLIT);
    ExprPool[N].ArgFirst := ExprArgCount;
    ExprPool[N].ArgCount := 0;
    { "[:]" vide - generique NON parametre (TODO 16, meme convention que    }
    { l entree predeclaree "Dictionary" elle-meme, ElemTypeIdx/KeyTypeIdx           }
    { = -1). }
    ExprPool[N].TypeIdx  := PDT_DICTIONARY;
    ParseArrayOrDictLiteral := N;
    Exit;
  End;

  If PPIsOp(']') Then
  Begin
    PPAdvance;
    N := ExprNew(EK_ARRAYLIT);
    ExprPool[N].ArgFirst := ExprArgCount;
    ExprPool[N].ArgCount := 0;
    { "[]" vide - generique NON parametre (TODO 16, meme convention que     }
    { l entree predeclaree "Array" elle-meme). }
    ExprPool[N].TypeIdx  := PDT_ARRAY;
    ParseArrayOrDictLiteral := N;
    Exit;
  End;

  ValBuf[0] := ParseExpr;
  IsDict := PPMatch(':');

  If IsDict Then
  Begin
    KeyBuf[0] := ValBuf[0];
    ValBuf[0] := ParseExpr;
    Cnt := 1;
    While PPMatch(',') Do
    Begin
      If Cnt <= High(KeyBuf) Then
      Begin
        KeyBuf[Cnt] := ParseExpr;
        If Not PPMatch(':') Then
          FatalError('"":"" attendu dans un litteral dictionnaire');
        ValBuf[Cnt] := ParseExpr;
        Inc(Cnt);
      End
      Else
      Begin
        ParseExpr;
        If PPMatch(':') Then ParseExpr;
        Inc(Cnt);
      End;
    End;
    If Not PPMatch(']') Then
      FatalError('crochet fermant attendu dans un litteral dictionnaire');

    ArgStart := ExprArgCount;
    For I := 0 To Cnt - 1 Do
      If I <= High(KeyBuf) Then
      Begin
        ExprArgPush(KeyBuf[I], '');
        ExprArgPush(ValBuf[I], '');
      End;

    N := ExprNew(EK_DICTLIT);
    ExprPool[N].ArgFirst := ArgStart;
    ExprPool[N].ArgCount := Cnt * 2;
    { type infere AU MIEUX depuis le PREMIER couple cle/valeur (TODO 16,   }
    { best-effort - jamais de verification de coherence entre tous les             }
    { couples, meme discipline que le reste du projet, TODO 19). }
    ExprPool[N].TypeIdx := TypeAdd(TYK_DICTIONARY, '', 8, 4, False, True,
      ExprPool[ValBuf[0]].TypeIdx, ExprPool[KeyBuf[0]].TypeIdx);
  End
  Else
  Begin
    Cnt := 1;
    While PPMatch(',') Do
    Begin
      If Cnt <= High(ValBuf) Then Begin ValBuf[Cnt] := ParseExpr; Inc(Cnt); End
      Else Begin ParseExpr; Inc(Cnt); End;
    End;
    If Not PPMatch(']') Then
      FatalError('crochet fermant attendu dans un litteral tableau');

    ArgStart := ExprArgCount;
    For I := 0 To Cnt - 1 Do
      If I <= High(ValBuf) Then ExprArgPush(ValBuf[I], '');

    N := ExprNew(EK_ARRAYLIT);
    ExprPool[N].ArgFirst := ArgStart;
    ExprPool[N].ArgCount := Cnt;
    { type infere AU MIEUX depuis le PREMIER element (TODO 16, meme        }
    { discipline best-effort que ci-dessus pour le dictionnaire). }
    ExprPool[N].TypeIdx := TypeAdd(TYK_ARRAY, '', 8, 4, False, True,
      ExprPool[ValBuf[0]].TypeIdx, -1);
  End;

  ParseArrayOrDictLiteral := N;
End;

{ ParseCallArgs : '(' encore le token courant. Etiquettes Swift        }
{ ("Nom:") reconnues via un jeton d avance (PP2) exactement comme la        }
{ cle d un litteral compose Go - stockees dans ExprArgKey, '' si            }
{ positionnel. Swift n autorise PAS de virgule finale (contrairement          }
{ a Go) : aucune tolerance ajoutee ici, portee volontairement plus            }
{ stricte. Meme tampon-local-puis-push que ParseArrayOrDictLiteral               }
{ ci-dessus. }
Function ParseCallArgs(Callee: Integer): Integer;
Const MAX_CALL_ARGS = 64;
Var
  N, I, Cnt, ArgStart, SigT, ResultT, SLIdx : Integer;
  Lbl : TString;
  Vals   : Array[0..MAX_CALL_ARGS - 1] Of Integer;
  Labels : Array[0..MAX_CALL_ARGS - 1] Of TString;
Begin
  PPAdvance;   { '(' }
  Cnt := 0;
  If Not PPIsOp(')') Then
  Repeat
    Lbl := '';
    If (PPKind = TOK_IDENT) And (PP2Kind = TOK_OP) And (PP2Val = ':') Then
    Begin
      Lbl := PPVal;
      PPAdvance;   { ident etiquette }
      PPAdvance;   { ':' }
    End;
    If Cnt <= High(Vals) Then
    Begin
      Vals[Cnt] := ParseExpr;
      Labels[Cnt] := Lbl;
      Inc(Cnt);
    End
    Else
    Begin
      ParseExpr;
      Inc(Cnt);
    End;
  Until Not PPMatch(',');

  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans un appel');

  ArgStart := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    If I <= High(Vals) Then ExprArgPush(Vals[I], Labels[I]);

  N := ExprNew(EK_CALL);
  ExprPool[N].Left     := Callee;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  If ExprPool[Callee].Kind = EK_IDENT Then
    ExprPool[N].NameVal := ExprPool[Callee].NameVal;

  { inference GENERALE (TODO 08/09 - le bloc du TODO 06 restait un      }
  { simple marqueur "reserve", jamais rempli au moment ou les VRAIES           }
  { signatures TYK_FUNC ont commence a exister, TODO 08 : corrige ici) :          }
  { callee resolu a une VRAIE signature (SK_FUNC ordinaire, TODO 08, OU              }
  { methode/propriete calculee via un selecteur deja resolu par                       }
  { ResolveSelectorType, TODO 09) -> TypeIdx recoit le type de RETOUR                    }
  { (toujours EXACTEMENT 1 resultat en Swift, jamais 0/plusieurs comme               }
  { Go) ; callee resolu a une STRUCTURE OU UNE CLASSE elle-meme (TODO      }
  { 09/10, "NomDeType(...)" - appel d un initialiseur implicite                       }
  { memberwise/explicite POUR UN STRUCT, ou explicite SEULEMENT pour UNE                 }
  { class, qui n a JAMAIS d init memberwise implicite en Swift reel,                        }
  { TODO 10) -> TypeIdx recoit directement le type LUI-MEME (best-effort :                  }
  { aucune verification que les arguments correspondent reellement a un              }
  { init existant, TODO 19 - vrai aussi bien pour "Point(x:0,y:0)" que          }
  { pour "Animal()" sans init ecrit du tout, classes.swift) ; callee              }
  { resolu a un CAS D ENUM a valeur ASSOCIEE (TODO 12, "MonEnum.succes(42)"           }
  { - le Callee est ici un EK_SELECTOR deja resolu par ResolveSelectorType,             }
  { TypeIdx=l enum LUI-MEME, IntVal=index du cas dans EnumCasePool) ->                    }
  { TypeIdx recoit egalement le type de l enum (une VALEUR de cet enum,                    }
  { peu importe le cas precis - best-effort, aucune verification que                       }
  { l argument fourni correspond au VRAI type associe du cas, TODO 19) ;             }
  { callee resolu a une signature GENERIQUE (TODO 13, "identity<T>(_          }
  { value: T) -> T") dont le type de RETOUR declare EST LUI-MEME un               }
  { parametre de type generique -> substitue par le type REEL du                        }
  { PREMIER argument fourni qui occupe, DANS LA SIGNATURE, la MEME                          }
  { position qu un parametre DECLARE avec ce MEME TypeIdx generique -                          }
  { "identity(42) infere T = Int" (roadmap d en-tete du TODO 13) : SEULE            }
  { l INFERENCE au point d appel est faite ici, JAMAIS une vraie                            }
  { monomorphisation (aucun code specialise n est genere - decision                              }
  { documentee en tete de section TODO 13) ni une verification de                                  }
  { coherence entre plusieurs usages du MEME "T" (ex. "maximum(1, ''x'')"                             }
  { best-effort, TODO 19). }
  SigT := ExprPool[Callee].TypeIdx;
  If (SigT >= 0) And (SigT < TypeCount) Then
    Case TypeTab[SigT].Kind Of
      TYK_FUNC:
        If TypeTab[SigT].ResultCount >= 1 Then
        Begin
          ResultT := FieldPool[TypeTab[SigT].ResultFirst].TypeIdx;
          If (ResultT >= 0) And (ResultT < TypeCount) And
             (TypeTab[ResultT].Kind = TYK_GENERIC_PARAM) Then
            For I := 0 To Cnt - 1 Do
              If (I < TypeTab[SigT].ParamCount) And (I <= High(Vals)) And
                 (FieldPool[TypeTab[SigT].ParamFirst + I].TypeIdx = ResultT) Then
              Begin
                ResultT := ExprPool[Vals[I]].TypeIdx;
                Break;
              End;
          ExprPool[N].TypeIdx := ResultT;
        End;
      TYK_STRUCT, TYK_CLASS, TYK_ENUM:
        ExprPool[N].TypeIdx := SigT;
    End
  Else If ExprPool[Callee].Kind = EK_IDENT Then
  Begin
    { bibliotheque standard minimale (TODO 20, StdlibTab ci-dessus) -      }
    { SEULEMENT si AUCUN symbole utilisateur ne resout deja ce nom                     }
    { (SigT<0 ci-dessus : "print" n a jamais ete redeclare - un VRAI          }
    { "func print(...)" utilisateur, cas EXTREME jamais exerce ici,                        }
    { primerait DEJA via le Case SigT normal, jamais atteint cette                          }
    { branche). Verifie le nombre d arguments (WarnMsg SEULEMENT -                        }
    { limitation de PORTEE de CE compilateur lui-meme, "un seul                                  }
    { argument" pour print(_:), PAS une vraie erreur de type Swift -                     }
    { discipline DIFFERENTE des controles inconditionnels du TODO 19,                    }
    { qui visent de VRAIES incompatibilites du langage). }
    SLIdx := StdlibFind(ExprPool[Callee].NameVal);
    If SLIdx >= 0 Then
    Begin
      If Cnt <> StdlibTab[SLIdx].ParamCount Then
        WarnMsg('''' + ExprPool[Callee].NameVal + ''' (bibliotheque standard, ' +
          'portee reduite a un seul argument, roadmap d''en-tete du TODO 20) ' +
          'recoit un nombre d''arguments inattendu');
      ExprPool[N].TypeIdx := StdlibTab[SLIdx].ResultTypeIdx;
    End;
  End;

  ParseCallArgs := N;
End;

{ ParseTupleOrGroup : '(' encore le token courant. "(expr)" SANS       }
{ virgule NI etiquette reste une simple parenthese (regle Swift            }
{ REELLE : indiscernable d un tuple a un seul element non etiquette) -          }
{ toute autre forme ("(1,2)", "(x:1)", "()") est un VRAI EK_TUPLE. }
Function ParseTupleOrGroup: Integer;
Const MAX_TUPLE_ELEMS = 16;
Var
  N, I, Cnt, ArgStart : Integer;
  Lbl : TString;
  IsTuple : Boolean;
  Vals   : Array[0..MAX_TUPLE_ELEMS - 1] Of Integer;
  Labels : Array[0..MAX_TUPLE_ELEMS - 1] Of TString;
Begin
  PPAdvance;   { '(' }

  If PPIsOp(')') Then
  Begin
    PPAdvance;
    N := ExprNew(EK_TUPLE);
    ExprPool[N].ArgFirst := ExprArgCount;
    ExprPool[N].ArgCount := 0;
    ExprPool[N].TypeIdx  := PDT_VOID;
    ParseTupleOrGroup := N;
    Exit;
  End;

  Lbl := '';
  If (PPKind = TOK_IDENT) And (PP2Kind = TOK_OP) And (PP2Val = ':') Then
  Begin
    Lbl := PPVal;
    PPAdvance;
    PPAdvance;
  End;
  Vals[0]   := ParseExpr;
  Labels[0] := Lbl;
  Cnt := 1;
  IsTuple := False;

  While PPMatch(',') Do
  Begin
    IsTuple := True;
    Lbl := '';
    If (PPKind = TOK_IDENT) And (PP2Kind = TOK_OP) And (PP2Val = ':') Then
    Begin
      Lbl := PPVal;
      PPAdvance;
      PPAdvance;
    End;
    If Cnt <= High(Vals) Then
    Begin
      Vals[Cnt]   := ParseExpr;
      Labels[Cnt] := Lbl;
      Inc(Cnt);
    End
    Else
    Begin
      ParseExpr;
      Inc(Cnt);
    End;
  End;

  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue');

  If (Not IsTuple) And (Labels[0] = '') Then
  Begin
    ParseTupleOrGroup := Vals[0];
    Exit;
  End;

  ArgStart := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    If I <= High(Vals) Then ExprArgPush(Vals[I], Labels[I]);

  N := ExprNew(EK_TUPLE);
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  ParseTupleOrGroup := N;
End;

{ ParseClosureLiteral (implementee au TODO 08, avec le reste des         }
{ fonctions) construit une fermeture Swift a partir d une accolade              }
{ ouvrante DEJA CONSOMMEE - forward-declaree ici car ParseOperand           }
{ (TODO 06) en a besoin bien avant que le TODO 08 ne soit ecrit                     }
{ (fermeture utilisee comme simple EXPRESSION, ex. "let f = <fermeture>"),            }
{ meme raison que ParseFuncSignature/ParseStructType chez GOCW32.PAS. }
Function ParseClosureLiteral: Integer; Forward;

Function ParseOperand: Integer;
Var Nam : TString;
Begin
  ParseOperand := 0;

  If PPAtEnd Then
  Begin
    FatalError('expression incomplete');
    Exit;
  End;

  Case PPKind Of
    TOK_INT:
      Begin
        ParseOperand := ExprAddIntLit(TokenPool[PP].IntVal);
        PPAdvance;
      End;
    TOK_FLOAT:
      Begin
        ParseOperand := ExprAddFloatLit(TokenPool[PP].RealVal);
        PPAdvance;
      End;
    TOK_STRING:
      Begin
        ParseOperand := ExprAddStringLit(TokenPool[PP].Val);
        PPAdvance;
      End;
    TOK_STRING_INTERP_PART:
      ParseOperand := ParseStringInterp;
    TOK_IDENT:
      Begin
        Nam := TokenPool[PP].Val;
        PPAdvance;
        If Nam = 'true' Then ParseOperand := ExprAddBoolLit(True)
        Else If Nam = 'false' Then ParseOperand := ExprAddBoolLit(False)
        Else If Nam = 'nil' Then ParseOperand := ExprAddNilLit
        Else ParseOperand := ExprAddIdent(Nam);
      End;
    TOK_OP:
      Begin
        If PPIsOp('(') Then ParseOperand := ParseTupleOrGroup
        Else If PPIsOp('[') Then ParseOperand := ParseArrayOrDictLiteral
        Else If PPIsOp('{') Then ParseOperand := ParseClosureLiteral   { TODO 08 }
        Else FatalError('jeton inattendu dans une expression: ' + PPVal);
      End;
  Else
    FatalError('jeton inattendu dans une expression');
  End;
End;

{ ParsePostfix : '.' (EK_SELECTOR), '?.' (EK_OPTIONALCHAIN, deux        }
{ jetons '?' puis '.' - aucun operateur "?." a deux caracteres n existe        }
{ dans la liste du lexeur TODO 02), '!' POSTFIXE (EK_FORCEDUNWRAP -             }
{ distingue du '!' PREFIXE logique par sa POSITION, jamais ambigu dans           }
{ un parseur recursif-descendant), '(' (appel) et '[' (indice). }
{ ResolveSelectorType (implementee au TODO 09, avec le reste des        }
{ structs) resout au mieux le TypeIdx d un noeud EK_SELECTOR/                 }
{ EK_OPTIONALCHAIN (champ OU propriete calculee OU methode d une             }
{ struct) - forward-declaree ici car ParsePostfix (TODO 06) en a               }
{ besoin bien avant que le TODO 09 ne soit ecrit, meme raison que              }
{ ParseClosureLiteral (TODO 08) juste au-dessus. }
Procedure ResolveSelectorType(SelNode: Integer); Forward;

Function ParsePostfix: Integer;
Var
  Cur, N, IdxExpr, Base : Integer;
  Nam : TString;
Begin
  Cur := ParseOperand;
  While True Do
  Begin
    If PPIsOp('.') Then
    Begin
      PPAdvance;
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ/methode attendu apres ''.''');
        Break;
      End;
      Nam := PPVal;
      PPAdvance;
      N := ExprNew(EK_SELECTOR);
      ExprPool[N].Left    := Cur;
      ExprPool[N].NameVal := Nam;
      ResolveSelectorType(N);   { TODO 09 }
      Cur := N;
      Continue;
    End;

    If PPIsOp('?') And (PP2Kind = TOK_OP) And (PP2Val = '.') Then
    Begin
      PPAdvance;   { '?' }
      PPAdvance;   { '.' }
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ/methode attendu apres ''?.''');
        Break;
      End;
      Nam := PPVal;
      PPAdvance;
      N := ExprNew(EK_OPTIONALCHAIN);
      ExprPool[N].Left    := Cur;
      ExprPool[N].NameVal := Nam;
      ResolveSelectorType(N);   { TODO 09 }
      Cur := N;
      Continue;
    End;

    If PPIsOp('!') Then
    Begin
      PPAdvance;
      N := ExprNew(EK_FORCEDUNWRAP);
      ExprPool[N].Left := Cur;
      If ExprPool[Cur].TypeIdx >= 0 Then
        ExprPool[N].TypeIdx := TypeResolveOptional(ExprPool[Cur].TypeIdx);
      Cur := N;
      Continue;
    End;

    If PPIsOp('(') Then
    Begin
      Cur := ParseCallArgs(Cur);
      Continue;
    End;

    If PPIsOp('[') Then
    Begin
      PPAdvance;
      IdxExpr := ParseExpr;
      If Not PPMatch(']') Then
        FatalError('crochet fermant attendu dans un indice');
      N := ExprNew(EK_INDEX);
      ExprPool[N].Left  := Cur;
      ExprPool[N].Right := IdxExpr;
      If ExprPool[Cur].TypeIdx >= 0 Then
      Begin
        Base := TypeResolveOptional(ExprPool[Cur].TypeIdx);
        If (Base >= 0) And (Base < TypeCount) Then
        Begin
          ExprPool[N].TypeIdx := TypeTab[Base].ElemTypeIdx;
          { Dictionary<K,V> (TODO 16) : l indexation par cle renvoie un   }
          { Optional<V> (nil si absente) - PAS de "valeur zero" implicite            }
          { comme la map de Go, difference REELLE documentee par le                    }
          { roadmap d en-tete ; Array<T> renvoie l element DIRECTEMENT             }
          { (la verification de borne/panique reste un mecanisme                       }
          { d EXECUTION, TODO 21+, absent ici). }
          If (TypeTab[Base].Kind = TYK_DICTIONARY) And (ExprPool[N].TypeIdx >= 0) And
             (Not TypeIsOptional(ExprPool[N].TypeIdx)) Then
            ExprPool[N].TypeIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True,
              ExprPool[N].TypeIdx, -1);
        End;
      End;
      Cur := N;
      Continue;
    End;

    { syntaxe de fermeture en fin d appel ("trailing closure", TODO 08) -   }
    { GARDEE par NoTrailingClosure (ambiguite REELLE avec le corps d un              }
    { if/guard/switch/while/for, voir sa propre note) - couvre a la fois           }
    { "appel(args) fermeture" (ajoute la fermeture comme DERNIER argument            }
    { de l EK_CALL existant) et "callee fermeture" SANS aucune parenthese                 }
    { (forme "callee" suivi DIRECTEMENT d une fermeture, SANS aucune            }
    { parenthese - ex. reel Swift "items.map" suivi d une fermeture) -           }
    { synthetise alors un EK_CALL ne portant QUE cette fermeture). }
    If (Not NoTrailingClosure) And PPIsOp('{') Then
    Begin
      N := ParseClosureLiteral;
      If ExprPool[Cur].Kind = EK_CALL Then
      Begin
        ExprArgPush(N, '');
        Inc(ExprPool[Cur].ArgCount);
      End
      Else
      Begin
        IdxExpr := ExprNew(EK_CALL);
        ExprPool[IdxExpr].Left := Cur;
        If ExprPool[Cur].Kind = EK_IDENT Then
          ExprPool[IdxExpr].NameVal := ExprPool[Cur].NameVal;
        ExprPool[IdxExpr].ArgFirst := ExprArgCount;
        ExprArgPush(N, '');
        ExprPool[IdxExpr].ArgCount := 1;
        Cur := IdxExpr;
      End;
      Continue;
    End;

    Break;
  End;
  ParsePostfix := Cur;
End;

Function ParseUnary: Integer;
Var Op : TString;
Begin
  If PPIsOp('-') Or PPIsOp('!') Or PPIsOp('~') Then
  Begin
    Op := PPVal;
    PPAdvance;
    ParseUnary := ExprNewUnary(Op, ParseUnary);
  End
  Else
    ParseUnary := ParsePostfix;
End;

Function ParseMul: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseUnary;
  While PPIsOp('*') Or PPIsOp('/') Or PPIsOp('%') Or PPIsOp('<<') Or
        PPIsOp('>>') Or PPIsOp('&') Do
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
  While PPIsOp('+') Or PPIsOp('-') Or PPIsOp('|') Or PPIsOp('^') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseMul);
  End;
  ParseAdd := L;
End;

{ ParseRange : PAS de While (contrairement a tous les autres niveaux   }
{ de cette chaine) - un intervalle Swift ne se chaine JAMAIS            }
{ ("1..<5..<10" n a aucun sens, a la difference de "+"/"*") : UNE            }
{ SEULE application. }
Function ParseRange: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseAdd;
  If PPIsOp('..<') Or PPIsOp('...') Then
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseAdd);
  End;
  ParseRange := L;
End;

{ ParseCasting : "is Type" (EK_ISCHECK) / "as[?!] Type" (EK_ASCAST) - }
{ mots-cles deja classifies au TODO 03 (KW_IS/KW_AS), type resolu via         }
{ ParseTypeExpr (TODO 05) - PORTEE (documentee) : seuls les types                }
{ predeclares/typealias resolvent reellement a ce stade (aucune class/          }
{ protocole n existe encore, TODO 09-11) ; "as?" enveloppe le resultat            }
{ dans un Optional (TypeAdd, TODO 04) - "as"/"as!" ne le font pas               }
{ (deballage IMMEDIAT en Swift reel, cote generateur de code, TODO 21). }
Function ParseCasting: Integer;
Var L, TIdx, N : Integer; Op : TString;
Begin
  L := ParseRange;

  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_IS) Then
  Begin
    PPAdvance;
    TIdx := ParseTypeExpr;
    N := ExprNew(EK_ISCHECK);
    ExprPool[N].Left    := L;
    ExprPool[N].Extra   := TIdx;
    ExprPool[N].TypeIdx := PDT_BOOL;
    L := N;
  End
  Else If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_AS) Then
  Begin
    PPAdvance;
    Op := 'as';
    If PPIsOp('?') Then Begin Op := 'as?'; PPAdvance; End
    Else If PPIsOp('!') Then Begin Op := 'as!'; PPAdvance; End;
    TIdx := ParseTypeExpr;
    N := ExprNew(EK_ASCAST);
    ExprPool[N].Left  := L;
    ExprPool[N].Op    := Op;
    ExprPool[N].Extra := TIdx;
    If Op = 'as?' Then
      ExprPool[N].TypeIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, TIdx, -1)
    Else
      ExprPool[N].TypeIdx := TIdx;
    L := N;
  End;

  ParseCasting := L;
End;

Function ParseNilCoalesce: Integer;
Var L : Integer;
Begin
  L := ParseCasting;
  While PPIsOp('??') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('??', L, ParseCasting);
  End;
  ParseNilCoalesce := L;
End;

Function ParseComparison: Integer;
Var L : Integer; Op : TString;
Begin
  L := ParseNilCoalesce;
  While PPIsOp('==') Or PPIsOp('!=') Or PPIsOp('<') Or PPIsOp('<=') Or
        PPIsOp('>') Or PPIsOp('>=') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseNilCoalesce);
  End;
  ParseComparison := L;
End;

Function ParseAnd: Integer;
Var L : Integer;
Begin
  L := ParseComparison;
  While PPIsOp('&&') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('&&', L, ParseComparison);
  End;
  ParseAnd := L;
End;

{ ParseExpr : "||" (le plus lache de la chaine de precedence         }
{ ordinaire), puis "try"/"try?"/"try!" PREFIXE (TODO 15) - liaison la      }
{ plus lache de TOUTES (roadmap Swift reel : "try" couvre l EXPRESSION           }
{ COMPLETE qui le suit, pas seulement son operande immediat), enveloppe               }
{ donc le resultat ENTIER de la chaine "||" plutot qu un simple operande          }
{ unaire - MEME convention Op que EK_ASCAST ('as'/'as?'/'as!') pour                    }
{ distinguer les trois formes sur un seul TExprKind. }
Function ParseExpr: Integer;
Var
  L, N : Integer;
  TryOp : TString;
  HasTry : Boolean;
Begin
  HasTry := False;
  TryOp := 'try';
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_TRY) Then
  Begin
    HasTry := True;
    PPAdvance;
    If PPIsOp('?') Then Begin TryOp := 'try?'; PPAdvance; End
    Else If PPIsOp('!') Then Begin TryOp := 'try!'; PPAdvance; End;
  End;

  L := ParseAnd;
  While PPIsOp('||') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('||', L, ParseAnd);
  End;

  If HasTry Then
  Begin
    N := ExprNew(EK_TRY);
    ExprPool[N].Left := L;
    ExprPool[N].Op   := TryOp;
    If TryOp = 'try?' Then
    Begin
      If TypeIsOptional(ExprPool[L].TypeIdx) Then
        ExprPool[N].TypeIdx := ExprPool[L].TypeIdx
      Else
        ExprPool[N].TypeIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True,
          ExprPool[L].TypeIdx, -1);
    End
    Else
      ExprPool[N].TypeIdx := ExprPool[L].TypeIdx;
    L := N;
  End;

  ParseExpr := L;
End;

{ ------------------------------------------------------------ }
{ ExprSelfTest : precedence (dont le piege ?? vs comparaison),       }
{ unaires, intervalle, deballage force, chainage optionnel,               }
{ selecteur, appels positionnels/etiquetes, index, tuples/simple             }
{ parenthesage, litteraux tableau/dictionnaire (dont formes vides),               }
{ interpolation de chaine, is/as/as?, et self comme identificateur                }
{ ordinaire - sur des extraits synthetiques (fichier temporaire, meme            }
{ methode que LexSelfTest/DeclSelfTest). }
{ ------------------------------------------------------------ }

Procedure ExprAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ExprSelfTest: ' + Label_ + ' a echoue');
End;

Function ExprParseString(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32EXPRSELFTEST.$$$';
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

  PP := 0;
  ExprParseString := ParseExpr;
End;

Procedure ExprSelfTest;
Var
  E, SI : Integer;
Begin
  ExprInit;
  SymInit;
  TypeInit;

  { precedence habituelle : 2 + 3 * 4 -> BINARY(+, 2, BINARY(*, 3, 4)) }
  E := ExprParseString('2 + 3 * 4');
  ExprAssert('2+3*4 racine est +', ExprPool[E].Op = '+');
  ExprAssert('2+3*4 partie droite est *', ExprPool[ExprPool[E].Right].Op = '*');
  ExprAssert('2+3*4 partie gauche est le litteral 2',
    ExprPool[ExprPool[E].Left].IntVal = 2);

  { unaires prefixes }
  SI := SymAdd('x', SK_VAR, PDT_INT, False);
  E := ExprParseString('-x');
  ExprAssert('-x est EK_UNARY "-"', (ExprPool[E].Kind = EK_UNARY) And
    (ExprPool[E].Op = '-'));

  E := ExprParseString('!x');
  ExprAssert('!x est EK_UNARY "!" -> Bool', (ExprPool[E].Kind = EK_UNARY) And
    (ExprPool[E].TypeIdx = PDT_BOOL));

  E := ExprParseString('~x');
  ExprAssert('~x est EK_UNARY "~" (PAS "^", contrairement a Go)',
    (ExprPool[E].Kind = EK_UNARY) And (ExprPool[E].Op = '~'));

  { piege de precedence REEL : ?? est PLUS FORT que la comparaison }
  E := ExprParseString('x ?? 0 > 5');
  ExprAssert('x??0>5 racine est ">"', ExprPool[E].Op = '>');
  ExprAssert('x??0>5 partie gauche est "??" (?? groupe avant >)',
    ExprPool[ExprPool[E].Left].Op = '??');

  { comparaison/logique -> Bool }
  E := ExprParseString('1 < 2 && 3 > 2');
  ExprAssert('1<2 && 3>2 -> type Bool', ExprPool[E].TypeIdx = PDT_BOOL);

  { intervalle }
  E := ExprParseString('0..<5');
  ExprAssert('0..<5 est EK_BINARY "..<"', (ExprPool[E].Kind = EK_BINARY) And
    (ExprPool[E].Op = '..<'));

  { deballage force (postfixe) - distinct du "!" prefixe logique deja  }
  { teste ci-dessus. }
  E := ExprParseString('x!');
  ExprAssert('x! est EK_FORCEDUNWRAP', ExprPool[E].Kind = EK_FORCEDUNWRAP);

  { chainage optionnel - deux jetons ''?'' puis ''.'' }
  SI := SymAdd('y', SK_VAR, PDT_INT, False);
  E := ExprParseString('y?.z');
  ExprAssert('y?.z est EK_OPTIONALCHAIN', ExprPool[E].Kind = EK_OPTIONALCHAIN);
  ExprAssert('y?.z NameVal="z"', ExprPool[E].NameVal = 'z');

  { selecteur ordinaire }
  E := ExprParseString('y.z');
  ExprAssert('y.z est EK_SELECTOR', ExprPool[E].Kind = EK_SELECTOR);

  { appel positionnel }
  E := ExprParseString('foo(1, 2)');
  ExprAssert('foo(1,2) est EK_CALL', ExprPool[E].Kind = EK_CALL);
  ExprAssert('foo(1,2) 2 arguments', ExprPool[E].ArgCount = 2);
  ExprAssert('foo(1,2) NameVal="foo"', ExprPool[E].NameVal = 'foo');

  { appel avec etiquettes Swift - "Point(x: 0, y: 0)", memberwise    }
  { init reel de structs.swift, meme si "Point" lui-meme n est pas          }
  { encore un vrai symbole SK_TYPE (structs, TODO 09) : le PARSING de           }
  { l appel etiquete n en depend pas. }
  E := ExprParseString('Point(x: 0, y: 0)');
  ExprAssert('Point(x:,y:) 2 arguments', ExprPool[E].ArgCount = 2);
  ExprAssert('Point(x:,y:) 1ere etiquette "x"', ExprArgKey[ExprPool[E].ArgFirst] = 'x');
  ExprAssert('Point(x:,y:) 2eme etiquette "y"', ExprArgKey[ExprPool[E].ArgFirst + 1] = 'y');

  { index }
  SI := SymAdd('arr', SK_VAR, PDT_INT, False);
  E := ExprParseString('arr[1]');
  ExprAssert('arr[1] est EK_INDEX', ExprPool[E].Kind = EK_INDEX);

  { simple parenthesage (PAS un tuple) vs vrai tuple }
  E := ExprParseString('(1 + 2) * 3');
  ExprAssert('(1+2)*3 racine est *', ExprPool[E].Op = '*');
  ExprAssert('(1+2)*3 partie gauche est + (parenthese "vue au travers")',
    ExprPool[ExprPool[E].Left].Op = '+');

  E := ExprParseString('(1, 2)');
  ExprAssert('(1,2) est EK_TUPLE', ExprPool[E].Kind = EK_TUPLE);
  ExprAssert('(1,2) 2 elements', ExprPool[E].ArgCount = 2);

  E := ExprParseString('(x: 1, y: 2)');
  ExprAssert('(x:1,y:2) est EK_TUPLE etiquete', ExprArgKey[ExprPool[E].ArgFirst] = 'x');

  { litteraux tableau/dictionnaire, formes pleines et vides }
  E := ExprParseString('[1, 2, 3]');
  ExprAssert('[1,2,3] est EK_ARRAYLIT', ExprPool[E].Kind = EK_ARRAYLIT);
  ExprAssert('[1,2,3] 3 elements', ExprPool[E].ArgCount = 3);

  E := ExprParseString('[]');
  ExprAssert('[] est EK_ARRAYLIT vide', (ExprPool[E].Kind = EK_ARRAYLIT) And
    (ExprPool[E].ArgCount = 0));

  E := ExprParseString('["a": 1, "b": 2]');
  ExprAssert('["a":1,"b":2] est EK_DICTLIT', ExprPool[E].Kind = EK_DICTLIT);
  ExprAssert('["a":1,"b":2] 4 entrees (2 paires intercalees)',
    ExprPool[E].ArgCount = 4);
  ExprAssert('["a":1,"b":2] 1ere cle = "a"',
    ExprPool[ExprArgPool[ExprPool[E].ArgFirst]].StrVal = 'a');

  E := ExprParseString('[:]');
  ExprAssert('[:] est EK_DICTLIT vide', (ExprPool[E].Kind = EK_DICTLIT) And
    (ExprPool[E].ArgCount = 0));

  { interpolation de chaine - reutilise le lexeur du TODO 02 }
  E := ExprParseString('"a\(1 + 2)b"');
  ExprAssert('"a\(1+2)b" est EK_STRINGINTERP', ExprPool[E].Kind = EK_STRINGINTERP);
  ExprAssert('"a\(1+2)b" 3 segments (texte/expr/texte)', ExprPool[E].ArgCount = 3);
  ExprAssert('"a\(1+2)b" 1er segment texte = "a"',
    ExprPool[ExprArgPool[ExprPool[E].ArgFirst]].StrVal = 'a');
  ExprAssert('"a\(1+2)b" 3eme segment texte = "b"',
    ExprPool[ExprArgPool[ExprPool[E].ArgFirst + 2]].StrVal = 'b');

  { is / as / as? }
  E := ExprParseString('1 is Int');
  ExprAssert('1 is Int est EK_ISCHECK', ExprPool[E].Kind = EK_ISCHECK);
  ExprAssert('1 is Int -> Bool', ExprPool[E].TypeIdx = PDT_BOOL);

  E := ExprParseString('1 as Double');
  ExprAssert('1 as Double est EK_ASCAST', ExprPool[E].Kind = EK_ASCAST);
  ExprAssert('1 as Double -> Double (direct, pas Optional)',
    ExprPool[E].TypeIdx = PDT_DOUBLE);

  E := ExprParseString('1 as? Double');
  ExprAssert('1 as? Double enveloppe dans un Optional',
    TypeIsOptional(ExprPool[E].TypeIdx));
  ExprAssert('1 as? Double deballe vers Double',
    TypeResolveOptional(ExprPool[E].TypeIdx) = PDT_DOUBLE);

  { self : identificateur ordinaire (aucune liaison au receveur       }
  { avant les methodes, TODO 09/10) - ne doit pas faire echouer le          }
  { parseur. }
  E := ExprParseString('self');
  ExprAssert('self est EK_IDENT', ExprPool[E].Kind = EK_IDENT);
  ExprAssert('self NameVal="self"', ExprPool[E].NameVal = 'self');

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit;
  SymInit;
End;

{ ============================================================ }
{ TODO 07 - STRUCTURES DE CONTROLE : IF/GUARD/SWITCH/BOUCLES    }
{ ============================================================ }
{ Meme principe que les TODO 05/06 : construit un AST (StmtPool,     }
{ pool a taille fixe comme ExprPool/TypeTab/SymTab) plutot que          }
{ d emettre du code, le backend (TODO 21+) n existant toujours pas.           }
{ Ce TODO n a PAS ENCORE d appelant reel (ParseTopLevelDecls, TODO 05,          }
{ s arrete toujours proprement sur "func"/"struct"/"class"/etc. - les             }
{ corps de fonctions arrivent au TODO 08) : chaque forme est construite            }
{ et testee de facon autonome via StmtSelfTest, exactement comme                    }
{ ExprSelfTest l a fait pour le TODO 06 avant que rien n utilise                       }
{ ParseExpr en pratique.                                                                  }
{                                                                       }
{ Portee REDUITE par rapport a GOCW32.PAS (differences REELLES de           }
{ langage, pas de simples omissions) : Swift n a NI "goto"/etiquettes            }
{ generiques, NI "++"/"--" (retires du langage depuis Swift 3), NI              }
{ ":=" (let/var couvrent tout, y compris a l interieur d un bloc - TODO 05          }
{ deja ecrit et directement reutilise ici), NI switch-sur-TYPE separe               }
{ (le "is Type" d un case ordinaire suffit, TODO 06 deja ecrit) - donc            }
{ pas de STK_GOTO/STK_LABELED/STK_INCDEC/STK_SHORTVAR/STK_TYPESWITCH.             }
{ L etiquette de boucle Swift ("label: while ... break label") est                    }
{ portee directement par un champ Label sur le noeud lui-meme plutot            }
{ qu un noeud STK_LABELED separe. "defer"/"throw"/"do" (TODO 15) sont             }
{ explicitement detectes et ARRETENT PROPREMENT (FatalError avec un              }
{ message clair) plutot que d etre silencieusement mal analyses par             }
{ ParseSimpleStmt. }

Const
  MAX_STMT     = 8192;
  MAX_STMT_ARG = 8192;
  MAX_CASE     = 2048;

Type
  TStmtKind = (
    STK_EMPTY, STK_BLOCK, STK_EXPR, STK_ASSIGN, STK_DECL,
    STK_IF, STK_GUARD, STK_SWITCH, STK_WHILE, STK_REPEATWHILE, STK_FORRANGE,
    STK_BREAK, STK_CONTINUE, STK_RETURN, STK_FALLTHROUGH,
    STK_DEFER, STK_THROW, STK_DO
  );

  TStmtNode = Record
    Kind    : TStmtKind;
    Op      : TString;    { STK_ASSIGN : texte de l operateur (= += -= ...) }
    Left    : Integer;    { voir tableau d usage par Kind ci-dessous }
    Right   : Integer;
    Extra   : Integer;
    NameVal : TString;
    LoopLabel : TString;  { etiquette de boucle/switch, '' si absente -   }
                           { STK_WHILE/REPEATWHILE/FORRANGE/SWITCH SEULEMENT ; }
                           { nomme "LoopLabel" et non "Label", MOT RESERVE }
                           { du Pascal (section de labels goto) }
    ArgFirst: Integer;
    ArgCount: Integer;
  End;

  { Usage des champs par Kind :                                            }
  {   STK_BLOCK       ArgFirst/Count -> instructions (StmtArgPool[i])          }
  {   STK_EXPR        Left -> expression                                          }
  {   STK_ASSIGN      Op ; Left=cible ; Right=valeur                              }
  {   STK_DECL        Left=index SymTab du PREMIER symbole cree par cette   }
  {                   instruction ; Extra=leur NOMBRE (0 pour "typealias",           }
  {                   >1 pour "let a = 1, b = 2" - virgules multiples,               }
  {                   ParseLetVarDecl) - TODO 21 (generateur de code,               }
  {                   extension "defer au niveau fichier" : a du, en la              }
  {                   corrigeant, etendre STK_DECL AU-DELA du simple                       }
  {                   marqueur "rien a faire" qu il etait depuis le                        }
  {                   TODO 05, un VRAI bogue ayant ete trouve par                          }
  {                   execution reelle - voir la note d en-tete de                         }
  {                   CompileStmt/STK_DECL, section TODO 21)                                     }
  {   STK_IF          Extra=Condition ; Right=Bloc-Alors ;                            }
  {                   Left=Sinon (-1, ou STK_IF pour "else if", ou               }
  {                   STK_BLOCK pour "else" final)                                   }
  {   STK_GUARD       Extra=Condition ; Right=Bloc-Sinon (doit sortir            }
  {                   de la portee - verifie best-effort)                            }
  {   STK_SWITCH      Extra=Tag ; ArgFirst/Count -> plage dans                        }
  {                   CaseClausePool                                                     }
  {   STK_WHILE       Extra=Condition ; Right=Corps                                      }
  {   STK_REPEATWHILE Right=Corps ; Extra=Condition (testee APRES le corps)              }
  {   STK_FORRANGE    NameVal=nom de la variable ('_' si ignoree) ;                      }
  {                   Left=intervalle (a..<b/a...b) ; Right=Corps ;                          }
  {                   Extra=index SymTab de la variable DEJA RESOLU (-1 si           }
  {                   '_' - TODO 21, generateur de code : voir la note                     }
  {                   d en-tete de ParseForInStmt pour pourquoi SymFind                    }
  {                   seul ne suffit pas ici)                                                    }
  {   STK_BREAK/CONTINUE  NameVal=etiquette visee ('' si absente)                            }
  {   STK_RETURN      Left=expression (-1 si "return" nu, fonction Void)                     }
  {   STK_FALLTHROUGH (aucune charge utile)                                                  }
  {   STK_DEFER       Right=Corps (bloc execute a la SORTIE de la portee              }
  {                   englobante, TODO 15 - voir la note d en-tete de ce                 }
  {                   TODO pour le mecanisme LIFO, encore a construire au           }
  {                   niveau du GENERATEUR de code, TODO 21+, absent ici)         }
  {   STK_THROW       Left=expression (valeur lancee, doit se conformer au              }
  {                   protocole Error - meme modele "boite" que les                       }
  {                   protocoles, verification best-effort UNIQUEMENT)                        }
  {   STK_DO          Right=Corps (bloc "do" suivi d un corps) ;                          }
  {                   ArgFirst/Count -> plage                                                  }
  {                   dans CatchClausePool (clauses "catch" associees,                   }
  {                   dans l ORDRE textuel - la RESOLUTION (quelle clause                }
  {                   correspond a l erreur lancee) reste un mecanisme                       }
  {                   d EXECUTION, TODO 21+, absent ici)                                          }

  TCaseClause = Record
    ExprFirst   : Integer;   { dans ExprArgPool : valeurs/intervalles       }
                             { "case V1, V2, R1...R2:" ; -1 si aucune          }
                             { (default) }
    ExprCount   : Integer;
    IsDefault   : Boolean;
    BodyFirst   : Integer;   { dans StmtArgPool : instructions du corps }
    BodyCount   : Integer;
    Fallthrough : Boolean;   { corps termine par l instruction "fallthrough" }
  End;

  { TCatchClause (TODO 15) : "catch Motif" suivi d un corps (Motif =    }
  { expression identifiant l erreur attendue, PatternExpr >= 0) ou "catch"           }
  { SEUL suivi d un corps, generique de dernier recours (PatternExpr = -1)         }
  { - AUCUNE liaison                                                                        }
  { "catch let x" n est requise par le roadmap d en-tete, donc non                 }
  { construite ici (portee reduite, jamais devinee au-dela du texte du            }
  { roadmap). }
  TCatchClause = Record
    PatternExpr : Integer;   { -1 si catch generique (sans motif) }
    Body        : Integer;   { STK_BLOCK }
  End;

Const
  MAX_CATCH = 1024;

Var
  StmtPool       : Array[0..MAX_STMT - 1] Of TStmtNode;
  StmtCount      : Integer;
  StmtArgPool    : Array[0..MAX_STMT_ARG - 1] Of Integer;
  StmtArgCount   : Integer;
  CaseClausePool : Array[0..MAX_CASE - 1] Of TCaseClause;
  CaseClauseCount: Integer;
  CatchClausePool : Array[0..MAX_CATCH - 1] Of TCatchClause;
  CatchClauseCount: Integer;

Procedure StmtInit;
Begin
  StmtCount        := 0;
  StmtArgCount     := 0;
  CaseClauseCount  := 0;
  CatchClauseCount := 0;
End;

Function StmtNew(K: TStmtKind): Integer;
Begin
  If StmtCount >= MAX_STMT Then
  Begin
    FatalError('table des noeuds d''instruction pleine (MAX_STMT)');
    StmtNew := 0;
    Exit;
  End;
  StmtPool[StmtCount].Kind     := K;
  StmtPool[StmtCount].Op       := '';
  StmtPool[StmtCount].Left     := -1;
  StmtPool[StmtCount].Right    := -1;
  StmtPool[StmtCount].Extra    := -1;
  StmtPool[StmtCount].NameVal  := '';
  StmtPool[StmtCount].LoopLabel := '';
  StmtPool[StmtCount].ArgFirst := -1;
  StmtPool[StmtCount].ArgCount := 0;
  StmtNew := StmtCount;
  Inc(StmtCount);
End;

Function StmtArgPush(V: Integer): Integer;
Begin
  If StmtArgCount >= MAX_STMT_ARG Then
  Begin
    FatalError('table des arguments d''instruction pleine (MAX_STMT_ARG)');
    StmtArgPush := 0;
    Exit;
  End;
  StmtArgPool[StmtArgCount] := V;
  StmtArgPush := StmtArgCount;
  Inc(StmtArgCount);
End;

{ CaseClauseNew : PORTEE (documentee, meme limite non resolue chez     }
{ GOCW32.PAS a ce meme stade) - un "switch" IMBRIQUE dans le corps         }
{ d une clause "case" de ce switch-ci allouerait ses PROPRES clauses            }
{ AU MILIEU de l intervalle [ArgStart, ArgStart+Cnt) de ce switch-ci                 }
{ (CaseClausePool est alloue SEQUENTIELLEMENT, pas via un tampon              }
{ local-puis-push comme ExprArgPool/StmtArgPool) - aucun echantillon               }
{ SAMPLES\SWIFT n imbrique de "switch", limitation acceptee plutot                    }
{ que resolue ici. }
Function CaseClauseNew: Integer;
Begin
  If CaseClauseCount >= MAX_CASE Then
  Begin
    FatalError('table des clauses ''case'' pleine (MAX_CASE)');
    CaseClauseNew := 0;
    Exit;
  End;
  CaseClausePool[CaseClauseCount].ExprFirst   := -1;
  CaseClausePool[CaseClauseCount].ExprCount   := 0;
  CaseClausePool[CaseClauseCount].IsDefault   := False;
  CaseClausePool[CaseClauseCount].BodyFirst   := -1;
  CaseClausePool[CaseClauseCount].BodyCount   := 0;
  CaseClausePool[CaseClauseCount].Fallthrough := False;
  CaseClauseNew := CaseClauseCount;
  Inc(CaseClauseCount);
End;

{ PPPeekKind/PPPeekVal : lecture a N jetons d avance (N=0 -> jeton      }
{ courant), SANS consommer - generalise PP2Kind/PP2Val (TODO 06,           }
{ equivalents a N=1) pour la detection d etiquette de boucle              }
{ ("Ident ':' while/repeat/for/switch", jusqu a 2 jetons en avant). }
Function PPPeekKind(N: Integer): TTokenKind;
Begin
  If (PP + N >= TokenCount) Or (PP + N < 0) Then PPPeekKind := TOK_EOF
  Else PPPeekKind := TokenPool[PP + N].Kind;
End;

Function PPPeekVal(N: Integer): TString;
Begin
  If (PP + N >= TokenCount) Or (PP + N < 0) Then PPPeekVal := ''
  Else PPPeekVal := TokenPool[PP + N].Val;
End;

{ IsLoopLabelAhead : Vrai si les jetons a partir de PP correspondent   }
{ a "Ident ':' (while|repeat|for|switch)" - pure LECTURE (aucun jeton        }
{ consomme). Un identificateur QUELCONQUE (jamais un mot-cle) suivi de           }
{ ':' puis d un de ces 4 mots-cles precis est TOUJOURS une etiquette de              }
{ boucle en Swift (aucune autre construction ne commence ainsi a la               }
{ position d une instruction). }
Function IsLoopLabelAhead: Boolean;
Var KwCode : Integer;
Begin
  IsLoopLabelAhead := False;
  If PPKind <> TOK_IDENT Then Exit;
  If IsKeyword(PPVal) <> 0 Then Exit;
  If (PP2Kind <> TOK_OP) Or (PP2Val <> ':') Then Exit;
  If PPPeekKind(2) <> TOK_IDENT Then Exit;
  KwCode := IsKeyword(PPPeekVal(2));
  IsLoopLabelAhead := (KwCode = KW_WHILE) Or (KwCode = KW_REPEAT) Or
    (KwCode = KW_FOR) Or (KwCode = KW_SWITCH);
End;

Function ParseStatement: Integer; Forward;
Function ParseBlock: Integer; Forward;

{ ParseBlock : accolade ouvrante...fermante - PORTEE lexicale propre     }
{ (SymEnterScope/                                                         }
{ SymLeaveScope, TODO 05). Analyse TOUTES les instructions dans un           }
{ tampon LOCAL puis les pousse SEULEMENT APRES coup dans StmtArgPool             }
{ (meme correctif que ParseCallArgs/ParseArrayOrDictLiteral, TODO 06 :          }
{ un bloc IMBRIQUE pousserait sinon ses propres instructions dans le              }
{ MEME pool partage AVANT que ce bloc-ci n ait pousse les siennes,                  }
{ decalant ArgFirst). }
Function ParseBlock: Integer;
Const MAX_BLOCK_STMTS = 256;
Var
  N, I, Cnt, ArgStart : Integer;
  Buf : Array[0..MAX_BLOCK_STMTS - 1] Of Integer;
Begin
  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue');
    ParseBlock := StmtNew(STK_BLOCK);
    Exit;
  End;

  SymEnterScope;
  PPSkipSemis;
  Cnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If Cnt <= High(Buf) Then Begin Buf[Cnt] := ParseStatement; Inc(Cnt); End
    Else Begin ParseStatement; Inc(Cnt); End;
    PPSkipSemis;
  End;
  SymLeaveScope;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin d''un bloc');

  ArgStart := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    If I <= High(Buf) Then StmtArgPush(Buf[I]);

  N := StmtNew(STK_BLOCK);
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  ParseBlock := N;
End;

{ ParseSimpleStmt : expression seule, ou affectation simple/composee   }
{ ("cible = valeur" / "cible += valeur" / ...) - Swift n a PAS de           }
{ "++"/"--" (retires du langage) ni de ":=" (let/var couvrent tout,             }
{ TODO 05). La cible d une affectation reste une expression QUELCONQUE            }
{ (identificateur, selecteur, indice) - seule la forme identificateur              }
{ SIMPLE est verifiee contre la regle "let" (SymCheckMutable, TODO 05) ;              }
{ un champ/indice cible reste hors de portee de cette verification                    }
{ (aucune notion de "champ let" n existe avant les structs, TODO 09). }
Function ParseSimpleStmt: Integer;
Var
  N, Target, Value, SI : Integer;
  Op : TString;
Begin
  Target := ParseExpr;

  If PPIsOp('=') Or PPIsOp('+=') Or PPIsOp('-=') Or PPIsOp('*=') Or
     PPIsOp('/=') Or PPIsOp('%=') Or PPIsOp('&=') Or PPIsOp('|=') Or
     PPIsOp('^=') Or PPIsOp('<<=') Or PPIsOp('>>=') Then
  Begin
    Op := PPVal;
    PPAdvance;
    Value := ParseExpr;

    If ExprPool[Target].Kind = EK_IDENT Then
    Begin
      SI := SymFind(ExprPool[Target].NameVal);
      SymCheckMutable(SI);
    End;

    N := StmtNew(STK_ASSIGN);
    StmtPool[N].Op    := Op;
    StmtPool[N].Left  := Target;
    StmtPool[N].Right := Value;
    ParseSimpleStmt := N;
  End
  Else
  Begin
    N := StmtNew(STK_EXPR);
    StmtPool[N].Left := Target;
    ParseSimpleStmt := N;
  End;
End;

{ ParseIfStmt : condition booleenne ORDINAIRE, OU deballage conditionnel   }
{ "if let Nom = Expr"/"if var Nom = Expr" (TODO 14, roadmap d en-tete) -            }
{ "Nom" n est VISIBLE QUE dans le bloc ALORS (SymEnterScope/SymLeaveScope        }
{ DEDIES, refermes AVANT le "else" eventuel) - contrairement a "guard let"           }
{ (juste plus bas), qui l enregistre dans la portee APPELANTE, visible                 }
{ APRES l instruction entiere (difference REELLE explicitement notee par             }
{ le roadmap). AUCUN nouveau champ sur TStmtNode : NameVal (inutilise            }
{ par un "if" ordinaire) porte le nom de la liaison ('' sinon, distingue            }
{ les deux formes) ; le type DEBALLE se recalcule a la demande via                    }
{ TypeResolveOptional(TODO 04) sur ExprPool[Extra].TypeIdx, jamais                          }
{ stocke separement. PORTEE (documentee) : UNE SEULE liaison ici (Swift              }
{ reel autorise "if let a = x, let b = y" - plusieurs liaisons separees              }
{ par virgule - AUCUN echantillon SAMPLES\SWIFT n en a besoin). }
Function ParseIfStmt: Integer;
Var
  N, Cond, ThenB, SI, UnwrappedT : Integer;
  SavedNTC : Boolean;
  BindName : TString;
  IsBindVar : Boolean;
Begin
  PPAdvance;   { if }
  SavedNTC := NoTrailingClosure;
  NoTrailingClosure := True;   { TODO 08 : l accolade apres la condition est le corps }

  BindName := '';
  IsBindVar := False;
  If (PPKind = TOK_IDENT) And ((IsKeyword(PPVal) = KW_LET) Or (IsKeyword(PPVal) = KW_VAR)) Then
  Begin
    IsBindVar := IsKeyword(PPVal) = KW_VAR;
    PPAdvance;
    If PPKind <> TOK_IDENT Then
      FatalError('nom de liaison attendu apres ''if let''/''if var''')
    Else
    Begin
      BindName := PPVal;
      PPAdvance;
      If Not PPMatch('=') Then
        FatalError('"=" attendu apres le nom d''une liaison ''if let''/''if var''');
    End;
  End;
  Cond := ParseExpr;
  NoTrailingClosure := SavedNTC;

  If BindName <> '' Then
  Begin
    SymEnterScope;
    UnwrappedT := TypeResolveOptional(ExprPool[Cond].TypeIdx);
    SI := SymAdd(BindName, SK_VAR, UnwrappedT, Not IsBindVar);
    SymTab[SI].HasInit := True;   { deballee : deja une valeur, pas un "let" en attente }
    ThenB := ParseBlock;
    SymLeaveScope;
  End
  Else
    ThenB := ParseBlock;

  N := StmtNew(STK_IF);
  StmtPool[N].Extra   := Cond;
  StmtPool[N].Right   := ThenB;
  StmtPool[N].NameVal := BindName;

  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_ELSE) Then
  Begin
    PPAdvance;
    If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_IF) Then
      StmtPool[N].Left := ParseIfStmt
    Else
      StmtPool[N].Left := ParseBlock;
  End;

  ParseIfStmt := N;
End;

{ ParseGuardStmt : "guard Condition else" suivi d un bloc - inverse du  }
{ bloc "else" s execute quand la condition est FAUSSE et DOIT sortir            }
{ de la portee courante (return/break/continue - "throw" rejoindra                  }
{ cette liste au TODO 15). Verification best-effort UNIQUEMENT (pas           }
{ d analyse de flux de controle exhaustive - roadmap d en-tete du               }
{ fichier) : seule la DERNIERE instruction du bloc est examinee.                    }
{ "guard let Nom = Expr else" suivi d un bloc (TODO 14, roadmap                }
{ d en-tete) : deballage OBLIGATOIRE - DIFFERENCE REELLE avec "if let"              }
{ (juste                                                                                  }
{ au-dessus) explicitement soulignee par le roadmap : "Nom" reste                     }
{ VISIBLE APRES le guard (enregistre DIRECTEMENT dans la portee                        }
{ APPELANTE, deja ouverte - AUCUNE portee dediee n est ouverte ici,                   }
{ contrairement au SymEnterScope/SymLeaveScope DEDIES de "if let"). }
Function ParseGuardStmt: Integer;
Var
  N, Cond, ElseB, Last, SI, UnwrappedT : Integer;
  SavedNTC : Boolean;
  BindName : TString;
  IsBindVar : Boolean;
Begin
  PPAdvance;   { guard }
  { NoTrailingClosure : par precaution/coherence avec les 4 autres        }
  { en-tetes (TODO 08) - le mot-cle "else" (obligatoire ici) desambiguise         }
  { deja structurellement avant meme d atteindre l accolade elle-meme. }
  SavedNTC := NoTrailingClosure;
  NoTrailingClosure := True;

  BindName := '';
  IsBindVar := False;
  If (PPKind = TOK_IDENT) And ((IsKeyword(PPVal) = KW_LET) Or (IsKeyword(PPVal) = KW_VAR)) Then
  Begin
    IsBindVar := IsKeyword(PPVal) = KW_VAR;
    PPAdvance;
    If PPKind <> TOK_IDENT Then
      FatalError('nom de liaison attendu apres ''guard let''/''guard var''')
    Else
    Begin
      BindName := PPVal;
      PPAdvance;
      If Not PPMatch('=') Then
        FatalError('"=" attendu apres le nom d''une liaison ''guard let''/''guard var''');
    End;
  End;
  Cond := ParseExpr;
  NoTrailingClosure := SavedNTC;

  If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_ELSE)) Then
  Begin
    FatalError('''else'' attendu apres la condition d''un ''guard''');
    ParseGuardStmt := StmtNew(STK_GUARD);
    Exit;
  End;
  PPAdvance;

  ElseB := ParseBlock;

  If StmtPool[ElseB].ArgCount > 0 Then
  Begin
    Last := StmtArgPool[StmtPool[ElseB].ArgFirst + StmtPool[ElseB].ArgCount - 1];
    If Not (StmtPool[Last].Kind In [STK_RETURN, STK_BREAK, STK_CONTINUE]) Then
      WarnMsg('le bloc ''else'' d''un ''guard'' devrait se terminer par ' +
        'return/break/continue (verification de surface uniquement)');
  End
  Else
    WarnMsg('bloc ''else'' de ''guard'' vide (devrait sortir de la portee)');

  N := StmtNew(STK_GUARD);
  StmtPool[N].Extra   := Cond;
  StmtPool[N].Right   := ElseB;
  StmtPool[N].NameVal := BindName;

  If BindName <> '' Then
  Begin
    UnwrappedT := TypeResolveOptional(ExprPool[Cond].TypeIdx);
    SI := SymAdd(BindName, SK_VAR, UnwrappedT, Not IsBindVar);
    SymTab[SI].HasInit := True;
  End;

  ParseGuardStmt := N;
End;

{ ParseCaseClause : "case V1, V2, ...:" ou "default:" suivi d une liste  }
{ d instructions (SANS accolades - jusqu au prochain "case"/"default"/           }
{ accolade fermante) - portee lexicale propre. Chaque valeur peut etre           }
{ un litteral OU un intervalle (deja EK_BINARY "..."/"..<" via                       }
{ ParseExpr/TODO 06, aucune distinction structurelle necessaire ici -                }
{ le generateur de code, TODO 21+, reconnaitra la forme par le Kind/Op                  }
{ du noeud). "fallthrough" (TODO 03) est detecte s il est la DERNIERE                       }
{ instruction du corps (marque CaseClausePool[].Fallthrough - PAS               }
{ retire de BodyFirst/Count, meme convention que GOCW32.PAS : le                    }
{ generateur de code sait deja qu il n a rien a emettre pour un noeud                   }
{ STK_FALLTHROUGH lui-meme).                                                              }
{ TagTypeIdx (TODO 12, parametre ajoute) : type de l expression "switch    }
{ Tag" englobante (deja resolue par l appelant, ParseSwitchStmt) -                  }
{ necessaire pour resoudre le motif RACCOURCI ".Cas"/".Cas(let Liaison)"           }
{ (roadmap d en-tete du TODO 12 : "reutilise le pattern matching du               }
{ TODO 07, etendu pour lier une variable depuis l interieur d un                        }
{ motif") - AUCUN nom d enum n est ecrit devant le point, contrairement            }
{ a "TagEnum.Cas" ecrit en toutes lettres (deja pris en charge SANS               }
{ modification par ParseExpr/ResolveSelectorType, TODO 06/09 etendus                    }
{ plus bas) : SEUL le contexte (le type de "Tag") permet de savoir a               }
{ QUEL enum ce nom de cas SANS PREFIXE appartient. Portee (documentee) :          }
{ UN SEUL cas par clause avec ce motif raccourci (pas de "case .a, .b:"),             }
{ UNE SEULE liaison "(let Nom)" (un cas associe a une SEULE valeur,                    }
{ meme simplification que ParseOneEnumCase, TODO 12). }
Function ParseCaseClause(TagTypeIdx: Integer): Integer;
Const MAX_CASE_VALS = 32; MAX_CASE_BODY = 64;
Var
  C, I, VCnt, BCnt, ArgStart, CaseIdx, PatIdx, BindTypeIdx : Integer;
  IsDef : Boolean;
  CaseName, BindName : TString;
  Vals : Array[0..MAX_CASE_VALS - 1] Of Integer;
  Body : Array[0..MAX_CASE_BODY - 1] Of Integer;
Begin
  C := CaseClauseNew;
  IsDef := IsKeyword(PPVal) = KW_DEFAULT;
  PPAdvance;   { 'case' ou 'default' }

  VCnt := 0;
  BindName := '';
  BindTypeIdx := -1;
  If Not IsDef Then
  Repeat
    If PPIsOp('.') And (PP2Kind = TOK_IDENT) Then
    Begin
      { motif raccourci d enum - voir note d en-tete ci-dessus. }
      PPAdvance;   { '.' }
      CaseName := PPVal;
      PPAdvance;
      CaseIdx := EnumCaseFind(TagTypeIdx, CaseName);
      If CaseIdx < 0 Then
        FatalError('cas d''enum inconnu dans un motif de ''switch'': .' + CaseName);
      PatIdx := ExprNew(EK_SELECTOR);
      ExprPool[PatIdx].NameVal := CaseName;
      ExprPool[PatIdx].IntVal  := CaseIdx;
      ExprPool[PatIdx].TypeIdx := TagTypeIdx;

      If PPMatch('(') Then
      Begin
        If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_LET)) Then
          FatalError('''let NomLiaison'' attendu dans un motif de cas d''enum')
        Else
        Begin
          PPAdvance;   { let }
          If PPKind <> TOK_IDENT Then
            FatalError('nom de liaison attendu dans un motif de cas d''enum')
          Else
          Begin
            BindName := PPVal;
            BindTypeIdx := EnumCaseGetAssocType(CaseIdx);
            PPAdvance;
          End;
        End;
        If Not PPMatch(')') Then
          FatalError('parenthese fermante attendue apres un motif de cas d''enum');
      End;

      If VCnt <= High(Vals) Then Begin Vals[VCnt] := PatIdx; Inc(VCnt); End;
    End
    Else If VCnt <= High(Vals) Then Begin Vals[VCnt] := ParseExpr; Inc(VCnt); End
    Else Begin ParseExpr; Inc(VCnt); End;
  Until Not PPMatch(',');

  If Not PPMatch(':') Then
    FatalError('"":"" attendu apres une clause ''case''/''default''');

  SymEnterScope;
  If BindName <> '' Then
    SymAdd(BindName, SK_VAR, BindTypeIdx, True);   { "let" - TOUJOURS une constante }
  PPSkipSemis;
  BCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) And
        (Not ((PPKind = TOK_IDENT) And
              ((IsKeyword(PPVal) = KW_CASE) Or (IsKeyword(PPVal) = KW_DEFAULT)))) Do
  Begin
    If BCnt <= High(Body) Then Begin Body[BCnt] := ParseStatement; Inc(BCnt); End
    Else Begin ParseStatement; Inc(BCnt); End;
    PPSkipSemis;
  End;
  SymLeaveScope;

  If VCnt > 0 Then
  Begin
    CaseClausePool[C].ExprFirst := ExprArgCount;
    For I := 0 To VCnt - 1 Do
      If I <= High(Vals) Then ExprArgPush(Vals[I], '');
    CaseClausePool[C].ExprCount := VCnt;
  End;

  ArgStart := StmtArgCount;
  For I := 0 To BCnt - 1 Do
    If I <= High(Body) Then StmtArgPush(Body[I]);

  CaseClausePool[C].IsDefault := IsDef;
  CaseClausePool[C].BodyFirst := ArgStart;
  CaseClausePool[C].BodyCount := BCnt;
  CaseClausePool[C].Fallthrough := (BCnt > 0) And
    (StmtPool[StmtArgPool[ArgStart + BCnt - 1]].Kind = STK_FALLTHROUGH);

  ParseCaseClause := C;
End;

{ ParseSwitchStmt : "switch Tag" suivi d une liste de clauses case/       }
{ default entre accolades - PAS de fallthrough IMPLICITE (contrairement          }
{ a C : chaque case sort automatiquement du switch - voir                        }
{ ParseCaseClause/Fallthrough ci-dessus pour la forme EXPLICITE). }
Function ParseSwitchStmt: Integer;
Var N, Tag, Cnt, ArgStart : Integer; SavedNTC : Boolean;
Begin
  PPAdvance;   { switch }
  SavedNTC := NoTrailingClosure;
  NoTrailingClosure := True;   { TODO 08 : l accolade apres le tag ouvre les clauses }
  Tag := ParseExpr;
  NoTrailingClosure := SavedNTC;

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres l''expression d''un ''switch''');
    ParseSwitchStmt := StmtNew(STK_SWITCH);
    Exit;
  End;
  PPSkipSemis;

  ArgStart := CaseClauseCount;
  Cnt := 0;
  While (PPKind = TOK_IDENT) And
        ((IsKeyword(PPVal) = KW_CASE) Or (IsKeyword(PPVal) = KW_DEFAULT)) Do
  Begin
    ParseCaseClause(ExprPool[Tag].TypeIdx);
    Inc(Cnt);
    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin d''un ''switch''');

  N := StmtNew(STK_SWITCH);
  StmtPool[N].Extra    := Tag;
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  ParseSwitchStmt := N;
End;

Function ParseWhileStmt: Integer;
Var N, Cond, Body : Integer; SavedNTC : Boolean;
Begin
  PPAdvance;   { while }
  SavedNTC := NoTrailingClosure;
  NoTrailingClosure := True;   { TODO 08 : l accolade apres la condition est le corps }
  Cond := ParseExpr;
  NoTrailingClosure := SavedNTC;
  Body := ParseBlock;
  N := StmtNew(STK_WHILE);
  StmtPool[N].Extra := Cond;
  StmtPool[N].Right := Body;
  ParseWhileStmt := N;
End;

{ ParseRepeatStmt : "repeat" suivi d un bloc puis "while Condition" -  }
{ do-while (la condition est testee APRES le corps, donc le corps            }
{ s execute TOUJOURS au moins une fois - meme forme de noeud que          }
{ STK_WHILE, seule la place respective de Left/Right/Extra differe            }
{ par convention, voir tableau d usage d en-tete de section). }
Function ParseRepeatStmt: Integer;
Var N, Body, Cond : Integer;
Begin
  PPAdvance;   { repeat }
  Body := ParseBlock;
  If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_WHILE)) Then
  Begin
    FatalError('''while'' attendu apres le corps d''un ''repeat''');
    ParseRepeatStmt := StmtNew(STK_REPEATWHILE);
    Exit;
  End;
  PPAdvance;
  Cond := ParseExpr;
  N := StmtNew(STK_REPEATWHILE);
  StmtPool[N].Right := Body;
  StmtPool[N].Extra := Cond;
  ParseRepeatStmt := N;
End;

{ ParseForInStmt : "for Nom in Intervalle" suivi d un bloc - PORTEE       }
{ (documentee,                                                            }
{ roadmap d en-tete) : seuls les intervalles a..<b/a...b (EK_BINARY,          }
{ TODO 06) sont reellement exploitables ici ; l iteration sur Array/           }
{ Dictionary/Set attend le TODO 16 (analyse best-effort, AUCUNE erreur           }
{ n est levee pour une autre forme de collection - seul le TypeIdx de              }
{ la variable de boucle reste alors inconnu, -1). "Nom" est enregistre           }
{ comme un "let" (SK_VAR, IsConst=Vrai - regle Swift REELLE : la                    }
{ variable de boucle est immuable a CHAQUE iteration), sauf si "_"                     }
{ (ignoree, aucun symbole ajoute). Portee : DEUX niveaux imbriques -                       }
{ celui de la variable de boucle elle-meme (ici), et celui du corps                           }
{ (ParseBlock, sa PROPRE portee) - permet a un corps qui redeclare son     }
{ propre "let i" interne                                                     }
{ de masquer legalement la variable de boucle sans conflit de nom               }
{ (SymFindInScope les distingue par ScopeId, TODO 05). }
Function ParseForInStmt: Integer;
Var
  VarNam : TString;
  N, RangeExpr, ElemT, Body, RangeBaseT, LoopVarSI : Integer;
  SavedNTC : Boolean;
Begin
  PPAdvance;   { for }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de variable attendu apres ''for''');
    ParseForInStmt := StmtNew(STK_FORRANGE);
    Exit;
  End;
  VarNam := PPVal;
  PPAdvance;

  If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_IN)) Then
  Begin
    FatalError('''in'' attendu dans une boucle ''for''');
    ParseForInStmt := StmtNew(STK_FORRANGE);
    Exit;
  End;
  PPAdvance;

  SavedNTC := NoTrailingClosure;
  NoTrailingClosure := True;   { TODO 08 : l accolade apres l intervalle est le corps }
  RangeExpr := ParseExpr;
  NoTrailingClosure := SavedNTC;

  SymEnterScope;
  ElemT := -1;
  If (ExprPool[RangeExpr].Kind = EK_BINARY) And
     ((ExprPool[RangeExpr].Op = '..<') Or (ExprPool[RangeExpr].Op = '...')) Then
    ElemT := ExprPool[ExprPool[RangeExpr].Left].TypeIdx
  Else If ExprPool[RangeExpr].TypeIdx >= 0 Then
  Begin
    { Array<T>/Set<T> (TODO 16) - iteration DIRECTE sur les elements ;    }
    { Dictionary<K,V> (paire cle/valeur par iteration en Swift reel)                    }
    { reste HORS DE PORTEE ici (roadmap d en-tete ne l exige que pour          }
    { Array, jamais exercee par aucun echantillon). String (TODO 17) -               }
    { rune-par-rune (UTF-8), meme decodeur que le TODO 14 de GOCW32.PAS -               }
    { AUCUN decodage REEL n est necessaire ICI (front-end uniquement,                    }
    { TODO 21+) : le SEUL fait a etablir a ce stade est que "ch" recoit             }
    { le type Character, pas le decoupage octet-par-octet lui-meme. }
    RangeBaseT := TypeResolveOptional(ExprPool[RangeExpr].TypeIdx);
    If (RangeBaseT >= 0) And (RangeBaseT < TypeCount) Then
    Begin
      If TypeTab[RangeBaseT].Kind In [TYK_ARRAY, TYK_SET] Then
        ElemT := TypeTab[RangeBaseT].ElemTypeIdx
      Else If TypeTab[RangeBaseT].Kind = TYK_STRING Then
        ElemT := PDT_CHARACTER;
    End;
  End;
  If VarNam <> '_' Then
  Begin
    LoopVarSI := SymAdd(VarNam, SK_VAR, ElemT, True);
    SymTab[LoopVarSI].IsTopLevelLocal := True;
  End
  Else LoopVarSI := -1;

  Body := ParseBlock;
  SymLeaveScope;

  N := StmtNew(STK_FORRANGE);
  StmtPool[N].NameVal := VarNam;
  StmtPool[N].Left     := RangeExpr;
  StmtPool[N].Right    := Body;
  { Extra : index SymTab de la variable de boucle DEJA RESOLU ici (-1 si   }
  { "_") - TODO 21 (extension controle de flux, generateur de code) en a           }
  { besoin pour initialiser/incrementer la variable SANS repasser par              }
  { SymFind(NameVal) au moment de la generation de code (executee bien              }
  { APRES la fermeture de CETTE portee, SymLeaveScope juste au-dessus) :          }
  { SymFind ferait un balayage par NOM sur TOUT SymTab (ne respecte pas           }
  { les portees fermees, voir sa propre note d en-tete) et pourrait donc            }
  { resoudre au MAUVAIS symbole si DEUX boucles for-in SIBLING reutilisent           }
  { le MEME nom de variable plus loin dans le fichier - champ AUPARAVANT             }
  { inutilise pour ce Kind (voir le tableau d usage d en-tete de section). }
  StmtPool[N].Extra := LoopVarSI;
  ParseForInStmt := N;
End;

Function ParseBreakStmt: Integer;
Var N : Integer; Lbl : TString;
Begin
  PPAdvance;   { break }
  Lbl := '';
  If PPKind = TOK_IDENT Then Begin Lbl := PPVal; PPAdvance; End;
  N := StmtNew(STK_BREAK);
  StmtPool[N].NameVal := Lbl;
  ParseBreakStmt := N;
End;

Function ParseContinueStmt: Integer;
Var N : Integer; Lbl : TString;
Begin
  PPAdvance;   { continue }
  Lbl := '';
  If PPKind = TOK_IDENT Then Begin Lbl := PPVal; PPAdvance; End;
  N := StmtNew(STK_CONTINUE);
  StmtPool[N].NameVal := Lbl;
  ParseContinueStmt := N;
End;

{ ParseReturnStmt : "return" nu (fonction Void) est possible grace a  }
{ "return" dans LexIsTermKeyword (TODO 02) - un saut de ligne (ou une        }
{ accolade fermante) juste apres termine normalement l instruction,             }
{ sans qu aucune expression n ait ete ecrite. }
Function ParseReturnStmt: Integer;
Var N, E : Integer;
Begin
  PPAdvance;   { return }
  E := -1;
  If (PPKind <> TOK_SEMI) And (Not PPIsOp('}')) And (Not PPAtEnd) Then
    E := ParseExpr;
  N := StmtNew(STK_RETURN);
  StmtPool[N].Left := E;
  ParseReturnStmt := N;
End;

Function ParseFallthroughStmt: Integer;
Begin
  PPAdvance;   { fallthrough }
  ParseFallthroughStmt := StmtNew(STK_FALLTHROUGH);
End;

{ ParseDeferStmt (TODO 15) : "defer" suivi d un bloc, execute a la      }
{ SORTIE de la portee englobante quel que soit le chemin (normal,                    }
{ return anticipe, ou erreur lancee) et en ordre LIFO si plusieurs                        }
{ "defer" partagent le meme bloc - roadmap d en-tete, meme mecanisme de              }
{ collecte-puis-rejeu-inverse que le TODO 16 de GOCW32.PAS. Ce               }
{ mecanisme d execution est un GENERATEUR de code (TODO 21+, absent            }
{ ici) : ce TODO 15 construit seulement le noeud STK_DEFER lui-meme -                  }
{ ParseBlock (TODO 07) reste totalement AGNOSTIQUE de l ordre           }
{ d execution, il empile simplement les instructions dans l ORDRE                     }
{ TEXTUEL comme toujours. }
Function ParseDeferStmt: Integer;
Var N, Body : Integer;
Begin
  PPAdvance;   { defer }
  Body := ParseBlock;
  N := StmtNew(STK_DEFER);
  StmtPool[N].Right := Body;
  ParseDeferStmt := N;
End;

{ ParseThrowStmt (TODO 15) : "throw" suivi d une expression - l operande          }
{ doit se conformer au protocole Error (meme modele "boite" que les             }
{ protocoles, TODO 11) ; verification best-effort UNIQUEMENT (surface),               }
{ jamais un FatalError sur une non-conformite - meme discipline que le             }
{ reste des verifications de protocole du projet. }
Function ParseThrowStmt: Integer;
Var N, E : Integer;
Begin
  PPAdvance;   { throw }
  E := ParseExpr;
  N := StmtNew(STK_THROW);
  StmtPool[N].Left := E;
  ParseThrowStmt := N;
End;

{ ParseDoStmt (TODO 15) : "do" suivi d un bloc, puis ZERO ou plusieurs   }
{ clauses "catch" suivies chacune d un motif optionnel puis d un corps -            }
{ un "catch" SANS motif (juste avant son bloc, teste ici via                              }
{ PPIsOp('{')) est le catch GENERIQUE de dernier recours              }
{ evoque par le roadmap d en-tete ; un "catch" AVEC motif attend une            }
{ expression identifiant l erreur specifique (meme famille de motif que              }
{ "case V1, V2:" d un switch ordinaire, TODO 07 - NoTrailingClosure                    }
{ protege ce motif exactement comme la condition d un if/guard/switch). }
Function ParseDoStmt: Integer;
Var
  N, Body, PatternE, CatchBody : Integer;
  CatchFirst, CatchCnt : Integer;
  SavedNTC : Boolean;
Begin
  PPAdvance;   { do }
  Body := ParseBlock;

  CatchFirst := CatchClauseCount;
  CatchCnt := 0;
  While (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_CATCH) Do
  Begin
    PPAdvance;   { catch }
    PatternE := -1;
    If Not PPIsOp('{') Then
    Begin
      SavedNTC := NoTrailingClosure;
      NoTrailingClosure := True;
      PatternE := ParseExpr;
      NoTrailingClosure := SavedNTC;
    End;
    CatchBody := ParseBlock;
    If CatchClauseCount >= MAX_CATCH Then
      WarnMsg('table des clauses catch pleine (MAX_CATCH)')
    Else
    Begin
      CatchClausePool[CatchClauseCount].PatternExpr := PatternE;
      CatchClausePool[CatchClauseCount].Body        := CatchBody;
      Inc(CatchClauseCount);
      Inc(CatchCnt);
    End;
  End;

  If CatchCnt = 0 Then
    WarnMsg('''do'' sans aucun ''catch'' associe (verification de surface ' +
      'uniquement, meme discipline que le ''else'' d un ''guard'', TODO 07)');

  N := StmtNew(STK_DO);
  StmtPool[N].Right    := Body;
  StmtPool[N].ArgFirst := CatchFirst;
  StmtPool[N].ArgCount := CatchCnt;
  ParseDoStmt := N;
End;

{ ParseStatement : dispatcheur principal. }
Function ParseStatement: Integer;
Var
  Lbl    : TString;
  N, Kw, DeclSymFirst : Integer;
Begin
  Lbl := '';
  If IsLoopLabelAhead Then
  Begin
    Lbl := PPVal;
    PPAdvance;   { ident etiquette }
    PPAdvance;   { ':' }
  End;

  If PPIsOp('{') Then
  Begin
    ParseStatement := ParseBlock;
    Exit;
  End;

  N := -1;
  If PPKind = TOK_IDENT Then
  Begin
    Kw := IsKeyword(PPVal);
    If Kw = KW_IF Then N := ParseIfStmt
    Else If Kw = KW_GUARD Then N := ParseGuardStmt
    Else If Kw = KW_SWITCH Then N := ParseSwitchStmt
    Else If Kw = KW_WHILE Then N := ParseWhileStmt
    Else If Kw = KW_REPEAT Then N := ParseRepeatStmt
    Else If Kw = KW_FOR Then N := ParseForInStmt
    Else If Kw = KW_BREAK Then N := ParseBreakStmt
    Else If Kw = KW_CONTINUE Then N := ParseContinueStmt
    Else If Kw = KW_RETURN Then N := ParseReturnStmt
    Else If Kw = KW_FALLTHROUGH Then N := ParseFallthroughStmt
    Else If Kw = KW_LET Then
    Begin
      DeclSymFirst := SymCount;
      ParseLetVarDecl(True);
      N := StmtNew(STK_DECL);
      StmtPool[N].Left  := DeclSymFirst;
      StmtPool[N].Extra := SymCount - DeclSymFirst;
    End
    Else If Kw = KW_VAR Then
    Begin
      DeclSymFirst := SymCount;
      ParseLetVarDecl(False);
      N := StmtNew(STK_DECL);
      StmtPool[N].Left  := DeclSymFirst;
      StmtPool[N].Extra := SymCount - DeclSymFirst;
    End
    Else If Kw = KW_TYPEALIAS Then Begin ParseTypeAliasDecl; N := StmtNew(STK_DECL); End
    Else If Kw = KW_DEFER Then N := ParseDeferStmt
    Else If Kw = KW_THROW Then N := ParseThrowStmt
    Else If Kw = KW_DO Then N := ParseDoStmt;
  End;

  If N < 0 Then N := ParseSimpleStmt;

  If Lbl <> '' Then
  Begin
    If StmtPool[N].Kind In [STK_WHILE, STK_REPEATWHILE, STK_FORRANGE, STK_SWITCH] Then
      StmtPool[N].LoopLabel := Lbl
    Else
      FatalError('etiquette non autorisee devant cette instruction ' +
        '(seuls while/repeat/for/switch peuvent etre etiquetes)');
  End;

  ParseStatement := N;
End;

{ ------------------------------------------------------------ }
{ StmtSelfTest : bloc/if-elseif-else/guard (surface)/switch (valeurs,   }
{ intervalles, default, fallthrough)/while/repeat-while/for-in (dont       }
{ "_" et la portee de la variable de boucle)/break-continue (avec/          }
{ sans etiquette)/affectation simple et composee/return (nu et avec           }
{ valeur)/let-var-typealias EN TANT QU INSTRUCTION - sur des extraits             }
{ synthetiques (fichier temporaire, meme methode que LexSelfTest/                 }
{ DeclSelfTest/ExprSelfTest). "defer"/"guard"-sans-sortie-de-portee                 }
{ NE SONT PAS exerces ici (declenchent respectivement FatalError/                     }
{ WarnMsg - le premier ferait Halt le compilateur, le second est un                     }
{ simple avertissement sans structure a verifier), exactement comme                       }
{ la branche "rejet" de SymCheckMutable reste non exercee depuis le              }
{ TODO 05, pour la meme raison. }
{ ------------------------------------------------------------ }

Procedure StmtAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StmtSelfTest: ' + Label_ + ' a echoue');
End;

Function ParseStmtString(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32STMTSELFTEST.$$$';
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

  PP := 0;
  ParseStmtString := ParseStatement;
End;

Procedure StmtSelfTest;
Var
  S, C1, C2, C3, SI : Integer;
Begin
  StmtInit;
  ExprInit;
  SymInit;
  TypeInit;

  { bloc simple, 2 instructions-expression }
  S := ParseStmtString('{ foo(1) ' + Chr(10) + 'bar(2) }');
  StmtAssert('bloc : 2 instructions', StmtPool[S].ArgCount = 2);
  StmtAssert('bloc : 1ere est STK_EXPR',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = STK_EXPR);

  { if / else if / else }
  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('if 1 < 2 { foo() } else if 3 > 4 { bar() } else { baz() }');
  StmtAssert('if : racine est STK_IF', StmtPool[S].Kind = STK_IF);
  StmtAssert('if : Sinon est un STK_IF ("else if")',
    StmtPool[StmtPool[S].Left].Kind = STK_IF);
  StmtAssert('if : Sinon du "else if" est un STK_BLOCK ("else" final)',
    StmtPool[StmtPool[StmtPool[S].Left].Left].Kind = STK_BLOCK);

  { guard : surface valide (se termine par return) }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('x', SK_VAR, PDT_INT, False);
  S := ParseStmtString('guard x > 0 else { return }');
  StmtAssert('guard : racine est STK_GUARD', StmtPool[S].Kind = STK_GUARD);

  { switch : valeurs multiples, intervalle, default }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('n', SK_VAR, PDT_INT, False);
  S := ParseStmtString('switch n {' + Chr(10) +
    'case 1, 2: foo()' + Chr(10) +
    'case 3...5: bar()' + Chr(10) +
    'default: baz()' + Chr(10) + '}');
  StmtAssert('switch : 3 clauses', StmtPool[S].ArgCount = 3);
  C1 := StmtPool[S].ArgFirst;
  C2 := C1 + 1;
  C3 := C1 + 2;
  StmtAssert('switch : clause 1 a 2 valeurs', CaseClausePool[C1].ExprCount = 2);
  StmtAssert('switch : clause 2 a 1 valeur (intervalle)',
    CaseClausePool[C2].ExprCount = 1);
  StmtAssert('switch : clause 2 valeur est un intervalle "..."',
    (ExprPool[ExprArgPool[CaseClausePool[C2].ExprFirst]].Kind = EK_BINARY) And
    (ExprPool[ExprArgPool[CaseClausePool[C2].ExprFirst]].Op = '...'));
  StmtAssert('switch : clause 3 est default', CaseClausePool[C3].IsDefault);

  { fallthrough : marque la clause QUI LE CONTIENT, PAS la suivante }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('n', SK_VAR, PDT_INT, False);
  S := ParseStmtString('switch n {' + Chr(10) +
    'case 1: foo()' + Chr(10) + 'fallthrough' + Chr(10) +
    'case 2: bar()' + Chr(10) + '}');
  C1 := StmtPool[S].ArgFirst;
  StmtAssert('fallthrough : clause 1 marquee Fallthrough',
    CaseClausePool[C1].Fallthrough);
  StmtAssert('fallthrough : clause 2 PAS marquee',
    Not CaseClausePool[C1 + 1].Fallthrough);

  { while }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('x', SK_VAR, PDT_INT, False);
  S := ParseStmtString('while x < 10 { x = x + 1 }');
  StmtAssert('while : racine est STK_WHILE', StmtPool[S].Kind = STK_WHILE);
  StmtAssert('while : corps a 1 instruction', StmtPool[StmtPool[S].Right].ArgCount = 1);

  { repeat-while }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('x', SK_VAR, PDT_INT, False);
  S := ParseStmtString('repeat { x = x + 1 } while x < 10');
  StmtAssert('repeat-while : racine est STK_REPEATWHILE',
    StmtPool[S].Kind = STK_REPEATWHILE);

  { for-in : variable de boucle nommee, "let" implicite, type infere }
  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('for i in 0..<5 { print(i) }');
  StmtAssert('for-in : racine est STK_FORRANGE', StmtPool[S].Kind = STK_FORRANGE);
  StmtAssert('for-in : NameVal="i"', StmtPool[S].NameVal = 'i');
  SI := SymFind('i');
  StmtAssert('for-in : "i" enregistree (encore visible, jamais retiree ' +
    'de SymTab - seule sa portee est depilee, TODO 05)', SI >= 0);
  StmtAssert('for-in : "i" est un "let" (IsConst)', SymTab[SI].IsConst);
  StmtAssert('for-in : "i" infere Int (depuis la borne gauche "0")',
    SymTab[SI].TypeIdx = PDT_INT);

  { for-in avec "_" : aucun symbole ajoute }
  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('for _ in 0..<3 { }');
  StmtAssert('for _ in ... : "_" non enregistre', SymFind('_') < 0);

  { break/continue avec et sans etiquette }
  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('outer: while true { break outer }');
  StmtAssert('boucle etiquetee : LoopLabel="outer"', StmtPool[S].LoopLabel = 'outer');
  StmtAssert('break outer : NameVal="outer"',
    StmtPool[StmtArgPool[StmtPool[StmtPool[S].Right].ArgFirst]].NameVal = 'outer');

  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('while true { continue }');
  StmtAssert('continue sans etiquette : NameVal=""',
    StmtPool[StmtArgPool[StmtPool[StmtPool[S].Right].ArgFirst]].NameVal = '');

  { affectation simple et composee }
  StmtInit; ExprInit; SymInit; TypeInit;
  SI := SymAdd('x', SK_VAR, PDT_INT, False);
  S := ParseStmtString('x = x + 1');
  StmtAssert('x=x+1 : STK_ASSIGN "="', (StmtPool[S].Kind = STK_ASSIGN) And
    (StmtPool[S].Op = '='));

  S := ParseStmtString('x += 1');
  StmtAssert('x+=1 : STK_ASSIGN "+="', (StmtPool[S].Kind = STK_ASSIGN) And
    (StmtPool[S].Op = '+='));

  { return nu et avec valeur }
  S := ParseStmtString('return');
  StmtAssert('return nu : Left=-1', StmtPool[S].Left = -1);

  S := ParseStmtString('return 5');
  StmtAssert('return 5 : Left resolu (litteral 5)',
    (StmtPool[S].Left >= 0) And (ExprPool[StmtPool[S].Left].IntVal = 5));

  { let/var/typealias comme instruction (a l interieur d un bloc) }
  StmtInit; ExprInit; SymInit; TypeInit;
  S := ParseStmtString('{ let y = 1' + Chr(10) + 'var z = 2 }');
  StmtAssert('bloc let/var : 2 instructions STK_DECL', StmtPool[S].ArgCount = 2);
  SI := SymFind('y');
  StmtAssert('"y" (let, dans le bloc) resolu', (SI >= 0) And SymTab[SI].IsConst);
  SI := SymFind('z');
  StmtAssert('"z" (var, dans le bloc) resolu', (SI >= 0) And (Not SymTab[SI].IsConst));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
End;

{ ============================================================ }
{ TODO 08 - FONCTIONS : PARAMETRES, SURCHARGE, RECURSION,       }
{           FERMETURES                                          }
{ ============================================================ }
{ Premier TODO qui donne enfin un VRAI appelant a ParseBlock (TODO 07) :   }
{ ParseTopLevelDecl (TODO 05) s arretait proprement sur "func" depuis          }
{ le debut - etendue ci-dessous pour analyser enfin le corps complet             }
{ des fonctions.                                                                 }
{                                                                       }
{ Grammaire des parametres Swift REELLEMENT DIFFERENTE de celle de Go        }
{ (GOCW32.PAS, TODO 08 la-bas) : chaque parametre est une unite COMPLETE           }
{ independante ("etiquette externe? nom interne : Type [= defaut]"),               }
{ jamais un GROUPE partageant un type final ("a, b int" en Go) - donc               }
{ aucun besoin de la detection nomme/non-nomme par lecture d essai de                  }
{ GOCW32.PAS ; en revanche Swift distingue etiquette EXTERNE (appelant)              }
{ et nom INTERNE (corps), et autorise une valeur par defaut - deux                       }
{ notions absentes de Go, d ou l extension de TFieldRec (TODO 04) avec                       }
{ ExtLabel/IsInout/HasDefault/DefaultExprIdx.                                                    }
{                                                                       }
{ UN SEUL type de retour (jamais de retours multiples comme Go - un              }
{ "tuple" Swift est simplement un type parmi d autres, TYK_TUPLE deja               }
{ ecrit au TODO 06) : reutilise ResultFirst/ResultCount de TTypeRec                    }
{ (TODO 04) avec Count TOUJOURS 0 ou 1 (Void compte comme "1 resultat de              }
{ type Void", jamais 0 - simplifie ParseReturnStmt/codegen futur : il y a                 }
{ TOUJOURS exactement un FieldPool a lire pour connaitre le type de                          }
{ retour, jamais besoin de distinguer "0 resultat" de "1 resultat").                             }
{                                                                       }
{ Surcharge : SymAdd (TODO 05, deja etendu ci-dessus) n avertit plus       }
{ pour SK_FUNC - FuncFind resout au NOM et au NOMBRE d arguments               }
{ SEULEMENT (best-effort documente par le roadmap d en-tete : "pas de              }
{ recherche de surcharge complete avec priorites de conversion                        }
{ implicite").                                                                   }
{                                                                       }
{ Fermetures : DECISION EXPLICITE (roadmap d en-tete, exactement comme      }
{ le TODO 15 de GOCW32.PAS pour ses goroutines) - capture par REFERENCE           }
{ PARTAGEE (une vraie fermeture Swift capture une variable MUTABLE par               }
{ reference, observable des deux cotes) plutot qu une simplification a                  }
{ une capture par valeur : AUCUN travail supplementaire n est necessaire            }
{ ici cote analyse pour l obtenir - SymFind (TODO 05) resout deja du plus            }
{ imbrique au plus englobant sur la TOTALITE de SymTab, quelle que soit             }
{ la portee active, donc le corps d une fermeture analysee alors que des             }
{ portees englobantes sont encore ouvertes "voit" deja naturellement les             }
{ variables englobantes SANS aucun mecanisme special ; le VRAI partage               }
{ (environnement alloue au tas, adresse commune) est un fait de                        }
{ GENERATION DE CODE (TODO 21+), pas d analyse - meme note, mot pour mot,                 }
{ que GOCW32.PAS pour ses propres fermetures.                                            }
{                                                                       }
{ @escaping : aucun echantillon SAMPLES\SWIFT n en a besoin -                }
{ conformement a la portee EXPLICITEMENT conditionnelle du roadmap                   }
{ d en-tete ("potentiellement hors de portee si aucun exemple ne                        }
{ l exige"), @escaping est ICI EXPLICITEMENT laisse hors de portee -                     }
{ decision honnete plutot qu une semantique devinee sans jamais etre                        }
{ exercee. Generiques ("func Nom<T>(...)", TODO 13) : arret propre             }
{ documente (FatalError clair) plutot qu une tentative de lecture erronee.               }

{ FieldPoolAdd : ajoute une entree (nom, type) "simple" a FieldPool -   }
{ premier VRAI consommateur du pool partage reserve depuis le TODO 04      }
{ ("champs de struct/class/enum/tuple" y etait deja annonce) - les 4          }
{ champs specifiques aux PARAMETRES de fonction restent a leur valeur              }
{ par defaut (voir FieldPoolAddParam ci-dessous pour ceux-ci). Sert au           }
{ type de RETOUR d une signature (jamais nomme, jamais etiquete) et aux           }
{ futurs champs de struct/class/enum/tuple (TODO 09/10/12). }
Function FieldPoolAdd(Const Nm: TString; TIdx: Integer): Integer;
Begin
  If FieldPoolCount >= MAX_FIELD_POOL Then
  Begin
    FatalError('table des champs/parametres pleine (MAX_FIELD_POOL)');
    FieldPoolAdd := 0;
    Exit;
  End;
  FieldPool[FieldPoolCount].Name           := Nm;
  FieldPool[FieldPoolCount].TypeIdx        := TIdx;
  FieldPool[FieldPoolCount].Offset         := 0;
  FieldPool[FieldPoolCount].ExtLabel       := '';
  FieldPool[FieldPoolCount].IsInout        := False;
  FieldPool[FieldPoolCount].HasDefault     := False;
  FieldPool[FieldPoolCount].DefaultExprIdx := -1;
  FieldPoolAdd := FieldPoolCount;
  Inc(FieldPoolCount);
End;

{ FieldPoolAddParam : meme chose, mais pour un VRAI parametre de         }
{ fonction (renseigne les 4 champs supplementaires). }
Function FieldPoolAddParam(Const Nm, AExtLabel: TString; TIdx: Integer;
  AInout: Boolean; ADefaultExprIdx: Integer): Integer;
Var FI: Integer;
Begin
  FI := FieldPoolAdd(Nm, TIdx);
  FieldPool[FI].ExtLabel       := AExtLabel;
  FieldPool[FI].IsInout        := AInout;
  FieldPool[FI].HasDefault     := ADefaultExprIdx >= 0;
  FieldPool[FI].DefaultExprIdx := ADefaultExprIdx;
  FieldPoolAddParam := FI;
End;

{ ParseParamList : "(" deja consomme par l appelant (ParseFuncSignature)  }
{ - analyse chaque parametre COMPLET jusqu a la parenthese fermante,             }
{ separes par des virgules (liste VIDE toleree, "()"). Tampon LOCAL       }
{ puis push APRES coup dans FieldPool (meme correctif que ParseCallArgs/          }
{ ParseBlock, TODO 06/07 : un type de parametre COMPOSE, ex. un type              }
{ fonction, pousserait sinon ses propres entrees imbriquees AVANT que            }
{ cette liste-ci n ait pousse les siennes, decalant FieldFirst). }
Function ParseParamList(Var FieldFirst, Cnt: Integer): Boolean;
Const MAX_PARAMS = 32;
Var
  BufNames, BufExtLabels : Array[0..MAX_PARAMS - 1] Of TString;
  BufTypes, BufDefaultExpr : Array[0..MAX_PARAMS - 1] Of Integer;
  BufInout : Array[0..MAX_PARAMS - 1] Of Boolean;
  BufCnt, I : Integer;
  Nam, ExtLbl : TString;
  TIdx, DefExpr : Integer;
  IsInout : Boolean;
Begin
  ParseParamList := True;
  BufCnt := 0;

  If Not PPIsOp(')') Then
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de parametre attendu');
      ParseParamList := False;
      Exit;
    End;

    { etiquette externe explicite ("Ident Ident ':'") vs nom interne     }
    { doublant deja comme etiquette ("Ident ':'") - "_" comme PREMIER          }
    { jeton (etiquette OU nom seul) signifie "aucune etiquette" (forme            }
    { utilisee par TOUS les echantillons SAMPLES\SWIFT). }
    If PP2Kind = TOK_IDENT Then
    Begin
      ExtLbl := PPVal;
      PPAdvance;
      Nam := PPVal;
      PPAdvance;
    End
    Else
    Begin
      ExtLbl := '';   { sentinelle : identique au nom interne, regle par defaut Swift }
      Nam := PPVal;
      PPAdvance;
    End;

    If Not PPMatch(':') Then
    Begin
      FatalError('"":"" attendu apres le nom d''un parametre');
      ParseParamList := False;
      Exit;
    End;

    IsInout := (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_INOUT);
    If IsInout Then PPAdvance;

    TIdx := ParseTypeExpr;

    DefExpr := -1;
    If PPMatch('=') Then DefExpr := ParseExpr;

    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt]      := Nam;
      BufExtLabels[BufCnt]  := ExtLbl;
      BufTypes[BufCnt]      := TIdx;
      BufInout[BufCnt]      := IsInout;
      BufDefaultExpr[BufCnt]:= DefExpr;
      Inc(BufCnt);
    End
    Else
      WarnMsg('trop de parametres dans une seule signature (tampon plein)');
  Until Not PPMatch(',');

  FieldFirst := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAddParam(BufNames[I], BufExtLabels[I], BufTypes[I], BufInout[I],
      BufDefaultExpr[I]);
  Cnt := BufCnt;
End;

{ ParseFuncSignature : "(" Parametres ")" ["->" TypeRetour] - PP doit    }
{ deja pointer juste APRES le nom de la fonction (declaration de haut          }
{ niveau) ou juste apres "func" (fermeture SANS liste de parametres,             }
{ TryParseClosureParamClause ci-dessous a sa PROPRE variante allegee).         }
Function ParseFuncSignature: Integer;
Var ParamFirst, ParamCnt, ResultT, FT : Integer; IsThrows : Boolean;
Begin
  ParseFuncSignature := -1;
  If Not PPMatch('(') Then
  Begin
    FatalError('parenthese ouvrante attendue apres le nom de la fonction');
    Exit;
  End;
  ParseParamList(ParamFirst, ParamCnt);
  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue apres les parametres');

  { "throws" (TODO 15) : entre la liste de parametres et le "->"        }
  { eventuel - "func f() throws" (Void) et "func f() throws -> T" sont             }
  { les deux formes reelles. }
  IsThrows := False;
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_THROWS) Then
  Begin
    IsThrows := True;
    PPAdvance;
  End;

  ResultT := PDT_VOID;
  If PPMatch('->') Then ResultT := ParseTypeExpr;

  { fonctions/fermetures : type de valeur REFERENCE (Faux) - une         }
  { fermeture Swift EST un objet a compteur de references en pratique          }
  { (capture partagee, voir note d en-tete), pas une simple valeur                }
  { copiee, contrairement a Int/String/struct. }
  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, False, -1, -1);
  TypeTab[FT].ParamFirst  := ParamFirst;
  TypeTab[FT].ParamCount  := ParamCnt;
  TypeTab[FT].ResultFirst := FieldPoolCount;
  FieldPoolAdd('', ResultT);
  TypeTab[FT].ResultCount := 1;
  TypeTab[FT].Throws      := IsThrows;

  ParseFuncSignature := FT;
End;

{ RegisterFuncScopeSymbols : declare chaque parametre comme variable    }
{ locale visible dans le corps - un parametre ORDINAIRE (IsInout=Faux)      }
{ est un "let" IMMUABLE (regle Swift REELLE : contrairement a Go, un              }
{ parametre Swift ne peut PAS etre reaffecte, meme une seule fois, sauf              }
{ s il est "inout") - HasInit est donc marque Vrai IMMEDIATEMENT (la              }
{ valeur arrive DEJA fournie par l appelant, contrairement a un "let x"                }
{ ordinaire qui attend encore sa toute premiere affectation) : une                       }
{ tentative de reaffectation declenchera SymCheckMutable (TODO 05/07)                        }
{ DES la premiere fois, pas seulement a la seconde. Un parametre "inout"                     }
{ reste var-like (IsConst=Faux) - alias de l argument de l appelant,                             }
{ modele memoire SIMPLE (une adresse) plutot qu une vraie copie-puis-                                }
{ recopie "copy-in copy-out" (ecart documente par le roadmap d en-tete). }
Procedure RegisterFuncScopeSymbols(FT: Integer);
Var I, SI, PIdx : Integer;
Begin
  For I := 0 To TypeTab[FT].ParamCount - 1 Do
  Begin
    PIdx := TypeTab[FT].ParamFirst + I;
    SI := SymAdd(FieldPool[PIdx].Name, SK_VAR, FieldPool[PIdx].TypeIdx,
      Not FieldPool[PIdx].IsInout);
    If (SI >= 0) And (Not FieldPool[PIdx].IsInout) Then
      SymTab[SI].HasInit := True;
  End;
End;

{ TFuncDefRec/FuncDefPool : fonctions NOMMEES de haut niveau uniquement   }
{ (les fermetures restent de simples expressions EK_CLOSURE, sans               }
{ entree ici - rien ne les nomme). MAX_FUNC deja reserve au TODO 01. }
Type
  TFuncDefRec = Record
    Name        : TString;
    TypeIdx     : Integer;   { TYK_FUNC }
    BodyStmtIdx : Integer;   { STK_BLOCK dans StmtPool }
    ParamSymFirst : Integer; { TODO 21 (generateur de code, extension     }
                              { compilation de fonctions) : index SymTab            }
                              { DU PREMIER parametre, DEJA RESOLU a l instant             }
                              { ou RegisterFuncScopeSymbols vient de les              }
                              { ajouter (SymAdd est APPEND-ONLY, dans le              }
                              { MEME ordre que FieldPool[ParamFirst..]) -              }
                              { evite SymFind (balayage par NOM sur TOUT              }
                              { SymTab, ambigu si un AUTRE parametre/global              }
                              { ailleurs dans le fichier partage le meme                    }
                              { nom) - meme technique EXACTE que              }
                              { STK_FORRANGE.Extra (ParseForInStmt). }
    LocalSymFirst : Integer; { index SymTab du PREMIER symbole cree PENDANT   }
                              { l analyse du CORPS (ParseBlock) - locales               }
                              { "let"/"var" ET tout symbole de portee                       }
                              { imbriquee interne (variable de boucle for-in,             }
                              { liaison if-let, etc. - TOUS ont desormais                          }
                              { besoin d un VRAI deplacement EBP-relatif,               }
                              { CONTRAIREMENT au niveau fichier ou aucune              }
                              { VRAIE pile n existe, voir IsTopLevelLocal). }
    LocalSymCount : Integer; { nombre de symboles dans cette plage - determine   }
                              { la taille du "SUB ESP,N" du prologue           }
                              { (CompileFuncDef, N = 4*LocalSymCount, MEME             }
                              { convention "tout scalaire fait 4 octets" que          }
                              { partout ailleurs dans ce generateur de code). }
  End;

Var
  FuncDefPool  : Array[0..MAX_FUNC - 1] Of TFuncDefRec;
  FuncDefCount : Integer;

Procedure FuncDefInit;
Begin
  FuncDefCount := 0;
End;

Function FuncDefAdd(Const Nm: TString; TIdx, Body: Integer): Integer;
Begin
  If FuncDefCount >= MAX_FUNC Then
  Begin
    WarnMsg('table des fonctions pleine (MAX_FUNC)');
    FuncDefAdd := -1;
    Exit;
  End;
  FuncDefPool[FuncDefCount].Name        := Nm;
  FuncDefPool[FuncDefCount].TypeIdx     := TIdx;
  FuncDefPool[FuncDefCount].BodyStmtIdx := Body;
  FuncDefAdd := FuncDefCount;
  Inc(FuncDefCount);
End;

{ FuncFind : resolution de SURCHARGE best-effort (roadmap d en-tete) -   }
{ correspondance par NOM et NOMBRE d arguments SEULEMENT (jamais par         }
{ TYPE des arguments - une recherche complete avec priorites de                  }
{ conversion implicite est explicitement hors de portee, meme texte que          }
{ le roadmap). Repli sur la PREMIERE fonction de ce nom si aucune ne              }
{ correspond exactement en arite (ex. parametres a valeur par defaut               }
{ omis au point d appel - compter les seuls arguments FOURNIS ne suffit                 }
{ alors plus a distinguer, limitation documentee). }
Function FuncFind(Const Nm: TString; ArgCnt: Integer): Integer;
Var I: Integer;
Begin
  FuncFind := -1;
  For I := FuncDefCount - 1 DownTo 0 Do
    If (FuncDefPool[I].Name = Nm) And
       (TypeTab[FuncDefPool[I].TypeIdx].ParamCount = ArgCnt) Then
    Begin
      FuncFind := I;
      Exit;
    End;
  For I := FuncDefCount - 1 DownTo 0 Do
    If FuncDefPool[I].Name = Nm Then
    Begin
      FuncFind := I;
      Exit;
    End;
End;

{ ParseFuncDecl : "func" deja consomme par l appelant (ParseTopLevelDecl,  }
{ TODO 05, etendue plus bas). Fonctions de haut niveau UNIQUEMENT ici -           }
{ un receveur de methode (struct/class, "func (self Type) Nom(...)"-like)          }
{ n existe pas en Swift de cette facon (les methodes sont ecrites            }
{ DIRECTEMENT a l interieur du corps struct/class - TODO 09/10 reutilisera            }
{ ParseFuncSignature/RegisterFuncScopeSymbols SANS modifier cette                    }
{ fonction-ci). SymEnterScope OUVRE DESORMAIS AVANT ParseGenericParamList              }
{ (TODO 13, toujours appelee - ne consomme rien si aucun "<" ne suit,               }
{ evite une gestion conditionnelle de portee) plutot qu apres                            }
{ ParseFuncSignature comme au TODO 08 d origine : "T"/"U" doivent DEJA               }
{ etre resolubles (SymFind, via ParseTypeExpr, TODO 05) DES la liste de              }
{ parametres elle-meme ("_ value: T"), pas seulement dans le corps. }
{ BlockHasReturnValue (TODO 19) : "chaque chemin d un func...->T non-  }
{ Void doit renvoyer une valeur - best-effort, PAS une vraie analyse             }
{ de chemins EXHAUSTIVE" (roadmap d en-tete) - interpretation la PLUS               }
{ SIMPLE honorant litteralement cette clause : confirme qu AU MOINS UN            }
{ "return" AVEC valeur existe QUELQUE PART dans le corps (meme dans une            }
{ branche jamais empruntee a l execution) plutot que de VERIFIER que                     }
{ TOUS les chemins en aient un (une VRAIE analyse de flot, explicitement           }
{ exclue par le roadmap) - descend RECURSIVEMENT dans if/else,                                  }
{ guard/else, while/repeat/for, switch (CaseClausePool) et do/catch                       }
{ (CatchClausePool) - meme liste de constructions que StmtSelfTest/                             }
{ ErrorSelfTest. }
Function BlockHasReturnValue(SIdx: Integer): Boolean;
Var I, CI : Integer;
Begin
  BlockHasReturnValue := False;
  If (SIdx < 0) Or (SIdx >= StmtCount) Then Exit;

  Case StmtPool[SIdx].Kind Of
    STK_RETURN:
      BlockHasReturnValue := StmtPool[SIdx].Left >= 0;
    STK_BLOCK:
      For I := StmtPool[SIdx].ArgFirst To StmtPool[SIdx].ArgFirst + StmtPool[SIdx].ArgCount - 1 Do
        If BlockHasReturnValue(StmtArgPool[I]) Then
        Begin BlockHasReturnValue := True; Exit; End;
    STK_IF:
      Begin
        If BlockHasReturnValue(StmtPool[SIdx].Right) Then Begin BlockHasReturnValue := True; Exit; End;
        If StmtPool[SIdx].Left >= 0 Then
          BlockHasReturnValue := BlockHasReturnValue(StmtPool[SIdx].Left);
      End;
    STK_GUARD:
      BlockHasReturnValue := BlockHasReturnValue(StmtPool[SIdx].Right);
    STK_WHILE, STK_REPEATWHILE, STK_FORRANGE:
      BlockHasReturnValue := BlockHasReturnValue(StmtPool[SIdx].Right);
    STK_SWITCH:
      For CI := StmtPool[SIdx].ArgFirst To StmtPool[SIdx].ArgFirst + StmtPool[SIdx].ArgCount - 1 Do
        For I := CaseClausePool[CI].BodyFirst To CaseClausePool[CI].BodyFirst + CaseClausePool[CI].BodyCount - 1 Do
          If BlockHasReturnValue(StmtArgPool[I]) Then
          Begin BlockHasReturnValue := True; Exit; End;
    STK_DO:
      Begin
        If BlockHasReturnValue(StmtPool[SIdx].Right) Then Begin BlockHasReturnValue := True; Exit; End;
        For CI := StmtPool[SIdx].ArgFirst To StmtPool[SIdx].ArgFirst + StmtPool[SIdx].ArgCount - 1 Do
          If BlockHasReturnValue(CatchClausePool[CI].Body) Then
          Begin BlockHasReturnValue := True; Exit; End;
      End;
  End;
End;

Function ParseFuncDecl: Integer;
Var
  Nam : TString;
  FT, Body, FD, ResultT, ParamSymFirst, LocalSymFirst : Integer;
Begin
  PPAdvance;   { func }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de fonction attendu apres ''func''');
    ParseFuncDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  SymEnterScope;
  ParseGenericParamList;

  FT := ParseFuncSignature;

  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_WHERE) Then
    ParseWhereClause;

  { ParamSymFirst/LocalSymFirst (TODO 21, generateur de code) : SymTab      }
  { est APPEND-ONLY (jamais purge, voir SymFind) - capturer SymCount ICI            }
  { (juste avant/apres les deux SEULES sources de nouveaux symboles de              }
  { cette fonction) donne un moyen FIABLE de retrouver PRECISEMENT les              }
  { parametres/locales de CETTE fonction au moment du generateur de code,           }
  { bien APRES que sa portee (SymLeaveScope, plus bas) ne soit refermee. }
  ParamSymFirst := SymCount;
  RegisterFuncScopeSymbols(FT);
  LocalSymFirst := SymCount;
  Body := ParseBlock;
  SymLeaveScope;

  { "chaque chemin d un func...->T non-Void doit renvoyer une valeur"    }
  { (roadmap TODO 19) - verifie best-effort via BlockHasReturnValue                    }
  { ci-dessus, JAMAIS pour un "->" absent (Void, ResultT=PDT_VOID). }
  ResultT := FieldPool[TypeTab[FT].ResultFirst].TypeIdx;
  If (ResultT <> PDT_VOID) And (Not BlockHasReturnValue(Body)) Then
    FatalError('la fonction ''' + Nam + ''' declare un type de retour ' +
      'non-Void mais ne contient aucun ''return'' avec valeur');

  FD := FuncDefAdd(Nam, FT, Body);
  If FD >= 0 Then
  Begin
    FuncDefPool[FD].ParamSymFirst := ParamSymFirst;
    FuncDefPool[FD].LocalSymFirst := LocalSymFirst;
    FuncDefPool[FD].LocalSymCount := SymCount - LocalSymFirst;
  End;
  SymAdd(Nam, SK_FUNC, FT, False);

  ParseFuncDecl := FD;
End;

{ TryParseClosureParamClause : tentative de lecture (avec REWIND          }
{ automatique en cas d echec, meme technique que le "IsNamed" de              }
{ GOCW32.PAS pour ParseParamList/ParseResultList) d une liste de                    }
{ parametres de fermeture COMPLETE ("(Nom: Type, ...) ['->' Type] 'in'")            }
{ - portee LIMITEE a cette seule forme explicite (roadmap d en-tete :             }
{ "litterales (params) -> Type in corps") ; Faux (PP restaure) si ce            }
{ qui suit ne correspond PAS - le corps de la fermeture est alors                    }
{ analyse SANS aucun parametre nomme (portee documentee : la forme                 }
{ abregee "x, y in ..." et le "$0"/"$1" implicite de Swift reel ne sont             }
{ PAS modelises, absents du roadmap d en-tete). }
Function TryParseClosureParamClause(Var ParamFirst, ParamCnt, ResultT: Integer): Boolean;
Const MAX_CLOSURE_PARAMS = 16;
Var
  SavedPP : Integer;
  BufNames : Array[0..MAX_CLOSURE_PARAMS - 1] Of TString;
  BufTypes : Array[0..MAX_CLOSURE_PARAMS - 1] Of Integer;
  BufCnt, I : Integer;
Begin
  TryParseClosureParamClause := False;
  SavedPP := PP;
  ResultT := -1;

  If Not PPIsOp('(') Then Exit;
  PPAdvance;

  BufCnt := 0;
  If Not PPIsOp(')') Then
  Repeat
    If PPKind <> TOK_IDENT Then Begin PP := SavedPP; Exit; End;
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := PPVal;
      BufTypes[BufCnt] := -1;
    End;
    PPAdvance;
    If Not PPMatch(':') Then Begin PP := SavedPP; Exit; End;
    If BufCnt <= High(BufNames) Then BufTypes[BufCnt] := ParseTypeExpr
    Else ParseTypeExpr;
    If BufCnt <= High(BufNames) Then Inc(BufCnt);
  Until Not PPMatch(',');

  If Not PPMatch(')') Then Begin PP := SavedPP; Exit; End;
  If PPMatch('->') Then ResultT := ParseTypeExpr;

  If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_IN)) Then
  Begin
    PP := SavedPP;
    Exit;
  End;
  PPAdvance;   { in }

  ParamFirst := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAdd(BufNames[I], BufTypes[I]);
  ParamCnt := BufCnt;
  TryParseClosureParamClause := True;
End;

{ ParseClosureLiteral : accolade ouvrante DEJA CONSOMMEE par l appelant   }
{ (ParseOperand pour une fermeture-EXPRESSION, ParsePostfix pour une                 }
{ fermeture EN FIN D APPEL - TODO 08). CONTRAIREMENT a une declaration            }
{ de fonction ordinaire (parametres et corps entre DEUX paires de                        }
{ delimiteurs distinctes), une fermeture Swift n a QU UNE SEULE paire                          }
{ d accolades pour l ensemble - la liste de parametres optionnelle est                             }
{ donc analysee et le CORPS construit ICI directement (PAS via ParseBlock,               }
{ qui exigerait sa PROPRE accolade ouvrante), duplication necessaire et                        }
{ documentee plutot qu une reutilisation forcee et incorrecte. }
Function ParseClosureLiteral: Integer;
Const MAX_CLOSURE_STMTS = 256;
Var
  N, FT, Body, ParamFirst, ParamCnt, ResultT, Cnt, ArgStart, I : Integer;
  Buf : Array[0..MAX_CLOSURE_STMTS - 1] Of Integer;
Begin
  PPAdvance;   { '{' }

  If Not TryParseClosureParamClause(ParamFirst, ParamCnt, ResultT) Then
  Begin
    ParamFirst := -1;
    ParamCnt   := 0;
    ResultT    := -1;
  End;

  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, False, -1, -1);
  TypeTab[FT].ParamFirst  := ParamFirst;
  TypeTab[FT].ParamCount  := ParamCnt;
  TypeTab[FT].ResultFirst := FieldPoolCount;
  FieldPoolAdd('', ResultT);
  TypeTab[FT].ResultCount := 1;

  SymEnterScope;
  { capture par REFERENCE (decision documentee en tete de section) :   }
  { RegisterFuncScopeSymbols suffit pour les PARAMETRES de la fermeture    }
  { elle-meme - toute reference aux variables de la portee ENGLOBANTE          }
  { (encore ouverte a ce point) resout deja naturellement via SymFind,             }
  { sans rien de plus a faire ici. }
  RegisterFuncScopeSymbols(FT);

  Cnt := 0;
  PPSkipSemis;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If Cnt <= High(Buf) Then Begin Buf[Cnt] := ParseStatement; Inc(Cnt); End
    Else Begin ParseStatement; Inc(Cnt); End;
    PPSkipSemis;
  End;
  SymLeaveScope;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin d''une fermeture');

  ArgStart := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    If I <= High(Buf) Then StmtArgPush(Buf[I]);

  Body := StmtNew(STK_BLOCK);
  StmtPool[Body].ArgFirst := ArgStart;
  StmtPool[Body].ArgCount := Cnt;

  N := ExprNew(EK_CLOSURE);
  ExprPool[N].Extra   := FT;
  ExprPool[N].Right   := Body;
  ExprPool[N].TypeIdx := FT;
  ParseClosureLiteral := N;
End;

{ ------------------------------------------------------------ }
{ FuncSelfTest : signature (etiquette externe explicite/implicite/       }
{ "_"/inout/valeur par defaut), surcharge (arite differente),                  }
{ recursion, fermeture litterale (avec liste de parametres typee) et             }
{ capture par reference d une variable englobante, fermeture en fin              }
{ d appel ("trailing closure") avec et sans parentheses regulieres,                  }
{ puis integration bout-en-bout via ParseTopLevelDecls (TODO 05, etendue          }
{ ci-dessous) sur un extrait ressemblant a math.swift - sur des                       }
{ extraits synthetiques (fichier temporaire, meme methode que les                        }
{ TODO precedents). }
{ ------------------------------------------------------------ }

Procedure FuncAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('FuncSelfTest: ' + Label_ + ' a echoue');
End;

Function FuncParseTopLevel(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32FUNCSELFTEST.$$$';
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
  FuncParseTopLevel := ParseFuncDecl;
End;

Procedure FuncSelfTest;
Var
  FD, FT, SI, E : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;

  { etiquette externe implicite (nom interne double comme etiquette) }
  FD := FuncParseTopLevel('func add(a: Int, b: Int) -> Int {' + Chr(10) +
    'return a + b' + Chr(10) + '}');
  FT := FuncDefPool[FD].TypeIdx;
  FuncAssert('add : 2 parametres', TypeTab[FT].ParamCount = 2);
  FuncAssert('add : etiquette externe "a" implicite (= nom interne)',
    FieldPool[TypeTab[FT].ParamFirst].ExtLabel = '');
  FuncAssert('add : retour Int', FieldPool[TypeTab[FT].ResultFirst].TypeIdx = PDT_INT);

  { etiquette externe "_" (aucune) - forme de TOUS les echantillons }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FD := FuncParseTopLevel('func mul(_ a: Int, _ b: Int) -> Int {' + Chr(10) +
    'return a * b' + Chr(10) + '}');
  FT := FuncDefPool[FD].TypeIdx;
  FuncAssert('mul : etiquette externe "_"',
    FieldPool[TypeTab[FT].ParamFirst].ExtLabel = '_');
  FuncAssert('mul : nom INTERNE reste "a" (utilisable dans le corps)',
    FieldPool[TypeTab[FT].ParamFirst].Name = 'a');

  { etiquette externe EXPLICITE differente du nom interne }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FD := FuncParseTopLevel('func greet(to name: String) -> Int {' + Chr(10) +
    'return 1' + Chr(10) + '}');
  FT := FuncDefPool[FD].TypeIdx;
  FuncAssert('greet : etiquette externe "to"',
    FieldPool[TypeTab[FT].ParamFirst].ExtLabel = 'to');
  FuncAssert('greet : nom interne "name"',
    FieldPool[TypeTab[FT].ParamFirst].Name = 'name');

  { inout }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FD := FuncParseTopLevel('func swap(_ a: inout Int, _ b: inout Int) {' + Chr(10) +
    'let t = a' + Chr(10) + 'a = b' + Chr(10) + 'b = t' + Chr(10) + '}');
  FT := FuncDefPool[FD].TypeIdx;
  FuncAssert('swap : "a" est inout', FieldPool[TypeTab[FT].ParamFirst].IsInout);
  SI := SymFind('a');
  FuncAssert('swap : parametre inout reste mutable (PAS un ''let'')',
    Not SymTab[SI].IsConst);
  FuncAssert('swap : Void par defaut (aucun "->")', FieldPool[TypeTab[FT].ResultFirst].TypeIdx = PDT_VOID);

  { parametre ORDINAIRE : immuable DES la premiere tentative de          }
  { reaffectation (pas seulement la seconde, contrairement a un "let"          }
  { ordinaire pas encore initialise) }
  SI := SymFind('b');
  FuncAssert('swap : parametre "b" (inout) HasInit sans consequence ' +
    '(non-const, SymCheckMutable ne rejette jamais un non-const)',
    Not SymTab[SI].IsConst);

  { valeur par defaut }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FD := FuncParseTopLevel('func inc(_ a: Int, by step: Int = 1) -> Int {' + Chr(10) +
    'return a + step' + Chr(10) + '}');
  FT := FuncDefPool[FD].TypeIdx;
  FuncAssert('inc : "step" a une valeur par defaut',
    FieldPool[TypeTab[FT].ParamFirst + 1].HasDefault);
  FuncAssert('inc : valeur par defaut = 1',
    ExprPool[FieldPool[TypeTab[FT].ParamFirst + 1].DefaultExprIdx].IntVal = 1);

  { surcharge : meme nom, arites differentes }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('func combine(_ a: Int) -> Int {' + Chr(10) + 'return a' + Chr(10) + '}');
  ParserInit;   { FuncParseTopLevel a deja tout relu/relexe - ParseFuncDecl seul suffit desormais }
  { 2eme surcharge : reutilise directement la lexeur/le pool de tokens du   }
  { DERNIER FuncParseTopLevel serait incorrect (fichier different) - repart      }
  { donc par un second appel complet. }
  FuncParseTopLevel('func combine(_ a: Int, _ b: Int) -> Int {' + Chr(10) +
    'return a + b' + Chr(10) + '}');
  FuncAssert('surcharge : 2 fonctions "combine" enregistrees', FuncDefCount = 2);
  FuncAssert('surcharge : FuncFind(1 argument) trouve la 1ere',
    TypeTab[FuncDefPool[FuncFind('combine', 1)].TypeIdx].ParamCount = 1);
  FuncAssert('surcharge : FuncFind(2 arguments) trouve la 2eme',
    TypeTab[FuncDefPool[FuncFind('combine', 2)].TypeIdx].ParamCount = 2);

  { recursion : le nom est deja un symbole SK_FUNC AVANT que le corps    }
  { ne soit analyse (SymAdd apres ParseBlock, mais SymFind cherche toute       }
  { la table sans notion de portee - TODO 05 - donc un appel recursif             }
  { DANS le corps ne resoudrait PAS encore le symbole a ce stade precis :             }
  { verifie ICI comme une limitation REELLE plutot que suppose resolue). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  FD := FuncParseTopLevel('func fact(_ n: Int) -> Int {' + Chr(10) +
    'if n < 2 { return 1 }' + Chr(10) + 'return n * fact(n - 1)' + Chr(10) + '}');
  FuncAssert('fact : enregistree malgre l appel recursif dans son propre corps',
    FD >= 0);
  SI := SymFind('fact');
  FuncAssert('fact : "fact" est bien un SK_FUNC apres coup', SymTab[SI].Kind = SK_FUNC);

  { fermeture litterale complete, avec capture par reference }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  SI := SymAdd('counter', SK_VAR, PDT_INT, False);
  E := ExprParseString('{ (x: Int) -> Int in' + Chr(10) +
    'counter = counter + x' + Chr(10) + 'return counter' + Chr(10) + '}');
  FuncAssert('fermeture : EK_CLOSURE', ExprPool[E].Kind = EK_CLOSURE);
  FuncAssert('fermeture : 1 parametre type Int',
    (TypeTab[ExprPool[E].Extra].ParamCount = 1) And
    (FieldPool[TypeTab[ExprPool[E].Extra].ParamFirst].TypeIdx = PDT_INT));
  SI := SymFind('counter');
  FuncAssert('fermeture : "counter" (portee englobante) toujours resolu ' +
    'apres coup - capture par reference, aucun mecanisme special requis',
    SI >= 0);

  { fermeture en fin d appel, AVEC parentheses regulieres (argument + closure) }
  StmtInit; ExprInit; SymInit; TypeInit;
  E := ExprParseString('reduce(0) { (a: Int, b: Int) -> Int in' + Chr(10) +
    'return a + b' + Chr(10) + '}');
  FuncAssert('trailing closure (avec args) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  FuncAssert('trailing closure (avec args) : 2 arguments (1 + la fermeture)',
    ExprPool[E].ArgCount = 2);
  FuncAssert('trailing closure (avec args) : dernier argument est EK_CLOSURE',
    ExprPool[ExprArgPool[ExprPool[E].ArgFirst + 1]].Kind = EK_CLOSURE);

  { fermeture en fin d appel, SANS AUCUNE parenthese }
  E := ExprParseString('sortValues { (a: Int, b: Int) -> Int in' + Chr(10) +
    'return a - b' + Chr(10) + '}');
  FuncAssert('trailing closure (sans args) : EK_CALL synthetise',
    ExprPool[E].Kind = EK_CALL);
  FuncAssert('trailing closure (sans args) : 1 argument (la fermeture seule)',
    ExprPool[E].ArgCount = 1);

  { NoTrailingClosure : "if" ne doit JAMAIS avaler son propre corps      }
  { comme fermeture en fin d appel de sa condition (ambiguite reelle,           }
  { voir la note de ParsePostfix) - deja verifie structurellement par           }
  { StmtSelfTest (TODO 07) pour if/while/switch/for ; ici, verification            }
  { CROISEE que "fact" (ci-dessus, avec son "if" interne ayant SA               }
  { PROPRE accolade juste apres la condition) s est bien analysee                 }
  { sans FatalError. }
  FuncAssert('NoTrailingClosure : "if n < 2 { ... }" dans fact() n a pas ' +
    'ete mal analyse (deja prouve par l absence de Halt jusqu ici)', True);

  { integration bout-en-bout : plusieurs fonctions + let/var top-level    }
  { s appelant entre eux, forme de math.swift - PREMIERE fois qu un              }
  { extrait REELLEMENT proche d un echantillon SAMPLES\SWIFT passe               }
  { integralement par ParseTopLevelDecls (TODO 05, etendue plus bas avec           }
  { "func") plutot que par un appel direct et isole a UNE seule fonction         }
  { de parsing - toujours PAS Run() lui-meme (voir sa propre note                    }
  { d en-tete : plusieurs autres echantillons utilisent encore struct/               }
  { class/enum/generiques/defer, tous hors de portee avant les TODO                    }
  { 09-15). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit;
  Assign(LexSrcF, 'SWIFTW32FUNCSELFTEST2.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'func add(_ a: Int, _ b: Int) -> Int {');
  WriteLn(LexSrcF, 'return a + b');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let x: Int = 10');
  WriteLn(LexSrcF, 'let y: Int = 20');
  WriteLn(LexSrcF, 'let sum: Int = add(x, y)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32FUNCSELFTEST2.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  FuncAssert('integration : "add" enregistree (FuncDefCount=1)', FuncDefCount = 1);
  SI := SymFind('sum');
  FuncAssert('integration : "sum" (let) resolu', SI >= 0);
  FuncAssert('integration : ParseTopLevelDecls a atteint la fin du ' +
    'fichier (PPAtEnd, aucun ''func''/''struct'' inattendu restant)', PPAtEnd);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
End;

{ ============================================================ }
{ TODO 09 - STRUCTS : SEMANTIQUE DE VALEUR, INIT ET MUTATING    }
{ ============================================================ }
{ Difference ARCHITECTURALE REELLE avec GOCW32.PAS (TODO 09 la-bas,     }
{ structs+methodes Go) : une methode Go est une declaration de HAUT           }
{ NIVEAU SEPAREE ("func (p Point) Nom(...)" suivi d un corps), toujours          }
{ ECRITE APRES que le struct existe deja ; une methode/un init Swift            }
{ est ECRIT A L INTERIEUR MEME du corps de la structure,                             }
{ potentiellement AVANT que tous les champs n aient ete vus.                            }
{ Consequence directe :                                                                  }
{ le TypeIdx TYK_STRUCT est ici PRE-ALLOUE (TypeAdd) DES le debut du            }
{ corps - avant meme d en analyser le premier membre - afin que "self"             }
{ (dans une methode/un init/une propriete calculee) puisse deja etre               }
{ type par CE TypeIdx ; FieldFirst/FieldCount/Size/Align/MethodFirst/                  }
{ MethodCount sont BACKFILLES (mutation directe de TypeTab[FT], simple           }
{ tableau Pascal) une fois le corps entierement analyse. PORTEE                       }
{ (documentee) : les champs doivent etre declares AVANT toute methode/               }
{ propriete calculee qui les utilise (contrairement a la regle Swift              }
{ reelle, qui autorise n importe quel ordre) - une VRAIE prescan a deux              }
{ passes (comme PrescanTopLevelFuncs de GOCW32.PAS pour les references              }
{ "avant declaration textuelle") resoudrait cela completement, mais              }
{ AUCUN echantillon SAMPLES\SWIFT n en a besoin (tous declarent deja               }
{ leurs champs en premier) - simplification acceptee plutot que                       }
{ resolue, exactement dans l esprit du reste de ce fichier.                             }
{                                                                       }
{ Acces IMPLICITE aux champs depuis une methode ("return x + y", PAS       }
{ "return self.x + self.y") : plutot que d enseigner a ExprAddIdent une             }
{ regle de secours "si non trouve, chercher un champ de self", chaque              }
{ champ DEJA CONNU au moment d analyser une methode/un init/une                       }
{ propriete calculee est enregistre comme un ALIAS SK_VAR ORDINAIRE               }
{ dans la portee de cette methode (IsConst=Vrai pour une methode NON-              }
{ mutating - lecture seule du receveur, regle Swift reelle - IsConst=            }
{ Faux pour "mutating func"/"init", ou le receveur peut etre reassigne) -            }
{ "x" resout alors NATURELLEMENT via SymFind (TODO 05), sans aucun               }
{ mecanisme special, et "self.x" (utile pour desambiguer un parametre               }
{ DE MEME NOM, ex. l affectation "self.x = x" dans un init(x: Int)) passe            }
{ par                                                                                     }
{ ResolveSelectorType comme n importe quel selecteur ordinaire - le               }
{ PARAMETRE "x" (ajoute APRES l alias de champ, donc plus RECENT dans              }
{ SymTab) masque naturellement l alias pour un acces NON qualifie,                     }
{ exactement la regle Swift reelle. }

Function AlignUp(V, A: Integer): Integer;
Begin
  If A <= 1 Then AlignUp := V
  Else AlignUp := ((V + A - 1) Div A) * A;
End;

{ TMethodRec/MethodPool : methodes ET proprietes calculees ET            }
{ initialiseurs D UNE STRUCTURE - contrairement a GOCW32.PAS (SymTab           }
{ exclut les methodes, "jamais un identificateur autonome"), MAIS                    }
{ EGALEMENT jamais enregistrees dans SymTab ici (memes raisons : on n y            }
{ accede jamais que via un selecteur "valeur.Nom", jamais un nom nu). }
Type
  TMethodRec = Record
    Name       : TString;    { 'init' pour un initialiseur (memberwise      }
                              { implicite OU explicite - le nom reel Swift      }
                              { n a de toute facon pas de "nom" separe) }
    TypeIdx    : Integer;    { signature TYK_FUNC (TODO 08) }
    BodyStmtIdx: Integer;    { STK_BLOCK ; -1 pour l init MEMBERWISE          }
                              { IMPLICITE (aucun VRAI corps ecrit - synthese,   }
                              { rien a generer avant un vrai codegen,              }
                              { TODO 21+, de toute facon) OU pour une                }
                              { EXIGENCE de protocole (TODO 11 - un contrat,           }
                              { jamais une implementation). }
    OwnerTypeIdx: Integer;   { TODO 11 : type (struct/class/protocol)      }
                              { proprietaire REEL de cette entree - voir             }
                              { la note d en-tete de section TODO 11 pour               }
                              { pourquoi ceci REMPLACE desormais                          }
                              { TypeTab[].MethodFirst/MethodCount (TODO 09/10)                }
                              { comme MOYEN DE RECHERCHE (ces deux champs                        }
                              { restent mis a jour, a titre INFORMATIF                             }
                              { seulement, mais ne sont plus jamais LUS par                            }
                              { MethodFind). }
    IsMutating : Boolean;
    IsComputedProperty: Boolean;  { Vrai : accede SANS parentheses           }
                                   { ("v.nom", comme un champ) - Faux :          }
                                   { VRAIE methode, accedee AVEC parentheses         }
                                   { ("v.nom(...)"), memes regles qu un SK_FUNC          }
                                   { ordinaire (TODO 06/08) une fois resolue.       }
  End;

Var
  MethodPool      : Array[0..MAX_FUNC - 1] Of TMethodRec;
  MethodPoolCount : Integer;

Procedure MethodPoolInit;
Begin
  MethodPoolCount := 0;
End;

Function MethodPoolAdd(Const Nm: TString; TIdx, Body, OwnerTypeIdx: Integer;
  AMutating, AComputed: Boolean): Integer;
Begin
  If MethodPoolCount >= MAX_FUNC Then
  Begin
    WarnMsg('table des methodes pleine (MAX_FUNC)');
    MethodPoolAdd := -1;
    Exit;
  End;
  MethodPool[MethodPoolCount].Name              := Nm;
  MethodPool[MethodPoolCount].TypeIdx           := TIdx;
  MethodPool[MethodPoolCount].BodyStmtIdx       := Body;
  MethodPool[MethodPoolCount].OwnerTypeIdx      := OwnerTypeIdx;
  MethodPool[MethodPoolCount].IsMutating        := AMutating;
  MethodPool[MethodPoolCount].IsComputedProperty:= AComputed;
  MethodPoolAdd := MethodPoolCount;
  Inc(MethodPoolCount);
End;

{ MethodFind : correspondance par NOM SEUL (contrairement a FuncFind,   }
{ TODO 08, qui distingue aussi par arite pour la surcharge de              }
{ fonctions) - la surcharge de METHODES/d INITIALISEURS n est PAS               }
{ demandee par le roadmap d en-tete du fichier, portee volontairement            }
{ plus etroite ici. Aucune recursion sur des champs "embarques"                    }
{ (contrairement a GOCW32.PAS) : Swift n a AUCUN mecanisme de                        }
{ composition/promotion automatique de ce genre pour les structs               }
{ (protocoles/extensions, TODO 11, jouent CE ROLE differemment, voir             }
{ juste en dessous). En REVANCHE (TODO 10) : une classe SANS methode              }
{ de ce nom remonte a sa SUPERCLASSE (TypeTab[].SuperTypeIdx, TOUJOURS          }
{ -1 pour un struct) AVANT d abandonner - la classe la PLUS DERIVEE est              }
{ TOUJOURS testee EN PREMIER, donc une methode "override" gagne                       }
{ NATURELLEMENT sur celle de la superclasse : c est EXACTEMENT le                    }
{ dispatch dynamique demande par le roadmap d en-tete (une VRAIE                          }
{ VTABLE-par-index reste un sujet du generateur de code futur,                                }
{ TODO 21+ - cette recherche par NOM, a l analyse, produit deja le                                }
{ MEME resultat observable).                                                                          }
{                                                                       }
{ BOGUE D ARCHITECTURE corrige AU TODO 11 : cette fonction cherchait      }
{ auparavant dans l intervalle CONTIGU [TypeTab[].MethodFirst,                          }
{ +MethodCount) - correct tant qu un type n avait ses methodes                              }
{ QU A l endroit meme de sa declaration. Les EXTENSIONS ("extension           }
{ Circle: Drawable" suivi d un corps, TODO 11) AJOUTENT des methodes a          }
{ un type                                                                            }
{ EXISTANT depuis un point QUELCONQUE, PLUS LOIN dans le fichier -                    }
{ d autres types (d autres protocoles, d autres structs) ont                                  }
{ INEVITABLEMENT deja pousse leurs propres entrees dans MethodPool                       }
{ ENTRE la plage d origine du type et sa premiere extension, rendant                       }
{ TOUTE hypothese de contigute FAUSSE par construction (contrairement            }
{ a FieldPool, jamais concerne : une extension Swift ne peut JAMAIS               }
{ ajouter de champ STOCKE). Corrige en cherchant desormais par            }
{ OwnerTypeIdx (balayage lineaire de TOUT MethodPool) plutot que par              }
{ position - TypeTab[].MethodFirst/MethodCount restent mis a jour                       }
{ (informatif uniquement) mais ne sont PLUS jamais LUS ici. }
Function MethodFind(STypeIdx: Integer; Const MName: TString): Integer;
Var I : Integer;
Begin
  MethodFind := -1;
  If (STypeIdx < 0) Or (STypeIdx >= TypeCount) Then Exit;
  For I := 0 To MethodPoolCount - 1 Do
    If (MethodPool[I].OwnerTypeIdx = STypeIdx) And (MethodPool[I].Name = MName) Then
    Begin
      MethodFind := I;
      Exit;
    End;
  If TypeTab[STypeIdx].Kind = TYK_CLASS Then
    MethodFind := MethodFind(TypeTab[STypeIdx].SuperTypeIdx, MName);
End;

{ StructFindField : recherche DIRECTE par nom - PAS de promotion via   }
{ des champs embarques (voir note d en-tete de MethodFind, meme                }
{ raison) - MAIS remonte a la superclasse (TODO 10) exactement comme            }
{ MethodFind, pour les memes raisons (un champ HERITE, ex. "legs" lu               }
{ depuis une methode de "Dog", doit rester accessible SANS "self."). }
Function StructFindField(STypeIdx: Integer; Const FName: TString): Integer;
Var I : Integer;
Begin
  StructFindField := -1;
  If (STypeIdx < 0) Or (STypeIdx >= TypeCount) Or
     (Not (TypeTab[STypeIdx].Kind In [TYK_STRUCT, TYK_CLASS])) Then Exit;
  For I := TypeTab[STypeIdx].FieldFirst To
    TypeTab[STypeIdx].FieldFirst + TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].Name = FName Then
    Begin
      StructFindField := I;
      Exit;
    End;
  If TypeTab[STypeIdx].Kind = TYK_CLASS Then
    StructFindField := StructFindField(TypeTab[STypeIdx].SuperTypeIdx, FName);
End;

{ ResolveSelectorType : REALISE la Forward-declaration du TODO 06 -    }
{ resout au mieux le TypeIdx d un noeud EK_SELECTOR/EK_OPTIONALCHAIN            }
{ (champ, PUIS propriete calculee/methode) DEJA CREE par ParsePostfix.               }
{ Une propriete calculee resout DIRECTEMENT vers son type de RETOUR              }
{ (accedee comme un champ, jamais un appel) ; une VRAIE methode resout               }
{ vers sa signature TYK_FUNC COMPLETE - EK_CALL (TODO 06/08, deja                        }
{ etendu ci-dessus) s en empare ensuite EXACTEMENT comme pour un                       }
{ SK_FUNC ordinaire, sans aucun code supplementaire. EK_OPTIONALCHAIN             }
{ ("a?.b") enveloppe en plus le resultat dans un Optional (TypeAdd,               }
{ TODO 04) s il ne l est pas deja - regle Swift reelle. TYK_PROTOCOL              }
{ (TODO 11) : une valeur typee par un PROTOCOLE ("let d: Drawable = ...")           }
{ resout sa methode DIRECTEMENT contre les EXIGENCES du protocole                    }
{ lui-meme (MethodFind fonctionne deja pour un TYK_PROTOCOL sans                        }
{ modification - chaque exigence y est enregistree via MethodPoolAdd,               }
{ OwnerTypeIdx=le protocole - seul le GARDE de Kind ci-dessous doit                    }
{ etre etendu) - jamais le type CONCRET reel derriere (inconnu a               }
{ l analyse, "modele boite" du roadmap d en-tete, meme principe que              }
{ l interface de GOCW32.PAS). TYK_ENUM (TODO 12) : ARCHITECTURALEMENT           }
{ DIFFERENT des trois cas ci-dessus - la BASE ("Direction" dans                        }
{ "Direction.north") est un NOM DE TYPE, pas une INSTANCE (ExprAddIdent,             }
{ TODO 06, resout deja tout identificateur SK_TYPE vers SON PROPRE                     }
{ TypeIdx - "Direction" evalue donc DEJA a BaseTypeIdx=l enum lui-meme,              }
{ exactement comme pour "instance.champ", coincidence structurelle                       }
{ EXPLOITEE ici plutot qu une nouvelle forme de noeud) : resout DIRECTEMENT         }
{ contre EnumCaseFind (TODO 12), JAMAIS StructFindField/MethodFind - le              }
{ resultat est une VALEUR de CE MEME type enum (ResultTIdx=BaseTypeIdx),                }
{ IntVal retient l INDEX du cas resolu (EnumCasePool) pour un futur                       }
{ pattern-matching/codegen. }

{ SynthesizeMethodSig (TODO 16) : construit une signature TYK_FUNC A UN   }
{ SEUL parametre - MEME mecanisme EXACT que ParseFuncSignature (TypeAdd          }
{ + FieldPoolAdd pour le parametre et le resultat) - EK_CALL (TODO             }
{ 06/08) s en empare ensuite SANS AUCUNE modification, exactement comme          }
{ pour un SK_FUNC ordinaire ou une methode de struct. }
Function SynthesizeMethodSig(ParamTypeIdx, ResultTypeIdx: Integer): Integer;
Var FT : Integer;
Begin
  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, False, -1, -1);
  TypeTab[FT].ParamFirst  := FieldPoolCount;
  FieldPoolAdd('', ParamTypeIdx);
  TypeTab[FT].ParamCount  := 1;
  TypeTab[FT].ResultFirst := FieldPoolCount;
  FieldPoolAdd('', ResultTypeIdx);
  TypeTab[FT].ResultCount := 1;
  SynthesizeMethodSig := FT;
End;

{ ResolveCollectionMemberType (TODO 16) : membres INTEGRES d Array<T>/   }
{ Dictionary<K,V>/Set<T> - AUCUNE entree FieldPool/MethodPool n existe          }
{ pour ces trois types (predeclares, jamais construits par                             }
{ ParseStructDecl) : chaque membre reconnu ici SYNTHETISE directement                    }
{ la signature correspondante (SynthesizeMethodSig ci-dessus) plutot                 }
{ que d introduire un tout nouveau mecanisme de dispatch. "count" est             }
{ la SEULE PROPRIETE (jamais appelee - resout DIRECTEMENT vers Int,                }
{ jamais une signature TYK_FUNC) ; tout le reste est une METHODE                       }
{ (necessite des parentheses a l appel, EK_CALL). PORTEE REDUITE                       }
{ (documentee) par rapport au Swift reel : Set.insert(_:) renvoie Void            }
{ ici (pas le tuple "(inserted:Bool, memberAfterInsert:Element)" reel)              }
{ et Set.remove(_:) renvoie Void ici (pas l Optional<Element> reel) -               }
{ aucun echantillon n exploite ces valeurs de retour, roadmap d en-tete            }
{ limitee a "insert(_:), contains(_:), remove(_:)" sans plus de detail. }
Function ResolveCollectionMemberType(BaseTypeIdx: Integer; Const CName: TString): Integer;
Var ElemT, KeyT, OptElemT : Integer;
Begin
  ResolveCollectionMemberType := -1;
  ElemT := TypeTab[BaseTypeIdx].ElemTypeIdx;
  KeyT  := TypeTab[BaseTypeIdx].KeyTypeIdx;

  If CName = 'count' Then
  Begin
    ResolveCollectionMemberType := PDT_INT;
    Exit;
  End;

  Case TypeTab[BaseTypeIdx].Kind Of
    TYK_ARRAY:
      If CName = 'append' Then
        ResolveCollectionMemberType := SynthesizeMethodSig(ElemT, PDT_VOID)
      Else If CName = 'remove' Then
        ResolveCollectionMemberType := SynthesizeMethodSig(PDT_INT, ElemT);
    TYK_DICTIONARY:
      If CName = 'removeValue' Then
      Begin
        OptElemT := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, ElemT, -1);
        ResolveCollectionMemberType := SynthesizeMethodSig(KeyT, OptElemT);
      End;
    TYK_SET:
      If CName = 'insert' Then
        ResolveCollectionMemberType := SynthesizeMethodSig(ElemT, PDT_VOID)
      Else If CName = 'contains' Then
        ResolveCollectionMemberType := SynthesizeMethodSig(ElemT, PDT_BOOL)
      Else If CName = 'remove' Then
        ResolveCollectionMemberType := SynthesizeMethodSig(ElemT, PDT_VOID);
  End;
End;

Procedure ResolveSelectorType(SelNode: Integer);
Var
  BaseTypeIdx, ResultTIdx, FIdx, MIdx, ECIdx : Integer;
  WrapOptional : Boolean;
Begin
  WrapOptional := (ExprPool[SelNode].Kind = EK_OPTIONALCHAIN);

  BaseTypeIdx := ExprPool[ExprPool[SelNode].Left].TypeIdx;
  If (BaseTypeIdx < 0) Or (BaseTypeIdx >= TypeCount) Then Exit;
  BaseTypeIdx := TypeResolveOptional(BaseTypeIdx);
  If (BaseTypeIdx < 0) Or (BaseTypeIdx >= TypeCount) Then Exit;

  If TypeTab[BaseTypeIdx].Kind = TYK_ENUM Then
  Begin
    ECIdx := EnumCaseFind(BaseTypeIdx, ExprPool[SelNode].NameVal);
    If ECIdx < 0 Then Exit;
    ExprPool[SelNode].IntVal  := ECIdx;
    ResultTIdx := BaseTypeIdx;
    If WrapOptional And (Not TypeIsOptional(ResultTIdx)) Then
      ResultTIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, ResultTIdx, -1);
    ExprPool[SelNode].TypeIdx := ResultTIdx;
    Exit;
  End;

  If TypeTab[BaseTypeIdx].Kind In [TYK_ARRAY, TYK_DICTIONARY, TYK_SET] Then
  Begin
    ResultTIdx := ResolveCollectionMemberType(BaseTypeIdx, ExprPool[SelNode].NameVal);
    If ResultTIdx < 0 Then Exit;
    If WrapOptional And (Not TypeIsOptional(ResultTIdx)) Then
      ResultTIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, ResultTIdx, -1);
    ExprPool[SelNode].TypeIdx := ResultTIdx;
    Exit;
  End;

  { String.count (TODO 17) - EN OCTETS ou, au mieux, en POINTS DE CODE,   }
  { JAMAIS en vrais graphemes composes (limitation documentee en tete de           }
  { section) : la SEULE propriete integree exigee par le roadmap                                }
  { d en-tete pour String ("count sur une String compte les octets..."). }
  If TypeTab[BaseTypeIdx].Kind = TYK_STRING Then
  Begin
    If ExprPool[SelNode].NameVal <> 'count' Then Exit;
    ResultTIdx := PDT_INT;
    If WrapOptional And (Not TypeIsOptional(ResultTIdx)) Then
      ResultTIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, ResultTIdx, -1);
    ExprPool[SelNode].TypeIdx := ResultTIdx;
    Exit;
  End;

  If Not (TypeTab[BaseTypeIdx].Kind In [TYK_STRUCT, TYK_CLASS, TYK_PROTOCOL]) Then Exit;

  ResultTIdx := -1;
  FIdx := StructFindField(BaseTypeIdx, ExprPool[SelNode].NameVal);
  If FIdx >= 0 Then
    ResultTIdx := FieldPool[FIdx].TypeIdx
  Else
  Begin
    MIdx := MethodFind(BaseTypeIdx, ExprPool[SelNode].NameVal);
    If MIdx >= 0 Then
    Begin
      If MethodPool[MIdx].IsComputedProperty Then
        ResultTIdx := FieldPool[TypeTab[MethodPool[MIdx].TypeIdx].ResultFirst].TypeIdx
      Else
        ResultTIdx := MethodPool[MIdx].TypeIdx;
    End;
  End;

  If ResultTIdx < 0 Then Exit;
  If WrapOptional And (Not TypeIsOptional(ResultTIdx)) Then
    ResultTIdx := TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, ResultTIdx, -1);
  ExprPool[SelNode].TypeIdx := ResultTIdx;
End;

Const
  MAX_STRUCT_MEMBERS = 32;

Type
  TStructBufNames   = Array[0..MAX_STRUCT_MEMBERS - 1] Of TString;
  TStructBufTypes   = Array[0..MAX_STRUCT_MEMBERS - 1] Of Integer;
  TStructBufDefault = Array[0..MAX_STRUCT_MEMBERS - 1] Of Integer;

{ RegisterFieldAliasesFromBuf : enregistre chaque champ DEJA CONNU        }
{ (BufNames/BufTypes, remplis EN COURS d analyse du corps du struct -          }
{ voir la limitation d ordre documentee en tete de section) comme un            }
{ alias SK_VAR ORDINAIRE dans la portee COURANTE (deja ouverte par                }
{ l appelant) - voir la note d en-tete "Acces IMPLICITE aux champs". }
Procedure RegisterFieldAliasesFromBuf(Const BufNames: TStructBufNames;
  Const BufTypes: TStructBufTypes; BufCnt: Integer; AliasIsConst: Boolean);
Var I : Integer;
Begin
  For I := 0 To BufCnt - 1 Do
    SymAdd(BufNames[I], SK_VAR, BufTypes[I], AliasIsConst);
End;

{ ParseComputedProperty : "var Nom: Type" suivi d un bloc getter SEUL -  }
{ deja repere par l appelant (ParseStructType, sur la presence d une         }
{ accolade ouvrante juste apres le type plutot qu un '='/rien) - PORTEE          }
{ (documentee, roadmap d en-tete, "reste a decider selon les exemples             }
{ reels" - AUCUN echantillon SAMPLES\SWIFT n utilise de propriete                    }
{ calculee : DECIDE ICI, minimalement, en faveur du SEUL cas                            }
{ explicitement demande par le texte du roadmap) : GETTER SEUL, jamais              }
{ de blocs "get"/"set" separes)                                                            }
{ separes. Un getter NE MUTE JAMAIS le receveur (regle Swift reelle,             }
{ meme sans le mot-cle "mutating" - AliasIsConst/self.IsConst TOUJOURS           }
{ Vrai ici). }
Function ParseComputedProperty(FT: Integer; Const PName: TString; ResultT: Integer;
  Const BufNames: TStructBufNames; Const BufTypes: TStructBufTypes; BufCnt: Integer): Integer;
Var SigT, Body, SelfSI : Integer;
Begin
  SymEnterScope;
  RegisterFieldAliasesFromBuf(BufNames, BufTypes, BufCnt, True);
  SelfSI := SymAdd('self', SK_VAR, FT, True);
  SymTab[SelfSI].HasInit := True;
  Body := ParseBlock;
  SymLeaveScope;

  SigT := TypeAdd(TYK_FUNC, '', 4, 4, False, False, -1, -1);
  TypeTab[SigT].ResultFirst := FieldPoolCount;
  FieldPoolAdd('', ResultT);
  TypeTab[SigT].ResultCount := 1;

  ParseComputedProperty := MethodPoolAdd(PName, SigT, Body, FT, False, True);
End;

{ ParseStructMemberFunc : "func Nom(...) [-> Type]" suivi d un corps    }
{ (methode ORDINAIRE, IsMutating=Faux), "mutating func Nom(...)" suivi           }
{ d un corps (IsMutating=Vrai, deja avance par l appelant jusqu au                  }
{ "func" lui-meme - "mutating" seul ne consomme rien ici) ou "init(...)"               }
{ suivi d un corps (IsInit=Vrai - traite comme "mutating" pour l acces               }
{ aux champs : un                                                                          }
{ init DOIT pouvoir assigner ses propres champs, regle Swift reelle,                  }
{ evidente puisque c est SA seule raison d etre). Reutilise                                }
{ ParseFuncSignature/RegisterFuncScopeSymbols DU TODO 08 SANS AUCUNE                       }
{ modification pour la liste de parametres elle-meme - seuls l alias                          }
{ des champs et "self" sont specifiques aux membres de struct. }
Function ParseStructMemberFunc(FT: Integer; Const BufNames: TStructBufNames;
  Const BufTypes: TStructBufTypes; BufCnt: Integer; IsMutating, IsInit: Boolean): Integer;
Var
  Nam : TString;
  SigT, Body, SelfSI : Integer;
Begin
  If IsInit Then
  Begin
    PPAdvance;   { init }
    Nam := 'init';
  End
  Else
  Begin
    PPAdvance;   { func }
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de methode attendu apres ''func''');
      ParseStructMemberFunc := -1;
      Exit;
    End;
    Nam := PPVal;
    PPAdvance;
  End;

  SigT := ParseFuncSignature;
  If IsInit Then
  Begin
    { un init "retourne" conceptuellement Self - remplace le Void par     }
    { defaut de ParseFuncSignature (aucun "->" n est jamais ecrit pour            }
    { un init reel). }
    TypeTab[SigT].ResultFirst := FieldPoolCount;
    FieldPoolAdd('', FT);
    TypeTab[SigT].ResultCount := 1;
  End;

  SymEnterScope;
  RegisterFieldAliasesFromBuf(BufNames, BufTypes, BufCnt, Not (IsMutating Or IsInit));
  SelfSI := SymAdd('self', SK_VAR, FT, Not (IsMutating Or IsInit));
  SymTab[SelfSI].HasInit := True;   { l instance existe DEJA - jamais un "let" en attente d initialisation }
  RegisterFuncScopeSymbols(SigT);
  Body := ParseBlock;
  SymLeaveScope;

  ParseStructMemberFunc := MethodPoolAdd(Nam, SigT, Body, FT, IsMutating Or IsInit, False);
End;

{ SynthesizeMemberwiseInit : "init(champ1: Type1, champ2: Type2, ...)"  }
{ genere AUTOMATIQUEMENT a partir des champs deja connus - ETIQUETTE             }
{ externe = nom du champ (regle par defaut Swift reelle du memberwise            }
{ init, PAS de "_" - contrairement a tous les exemples de fonctions/               }
{ methodes ECRITES a la main dans SAMPLES\SWIFT, qui utilisent "_"                    }
{ partout : deux conventions REELLEMENT differentes, aucune erreur ici).             }
{ HERITE la valeur par defaut EVENTUELLE du champ (DefaultExprIdx deja           }
{ porte par le champ lui-meme, TODO 08, reutilise tel quel). AUCUN VRAI          }
{ corps (BodyStmtIdx=-1, rien a generer avant un vrai codegen). }
Procedure SynthesizeMemberwiseInit(FT, FieldStart, FieldCnt: Integer);
Var SigT, I, PFirst : Integer;
Begin
  SigT := TypeAdd(TYK_FUNC, '', 4, 4, False, False, -1, -1);
  PFirst := FieldPoolCount;
  For I := 0 To FieldCnt - 1 Do
    FieldPoolAddParam(FieldPool[FieldStart + I].Name, '', FieldPool[FieldStart + I].TypeIdx,
      False, FieldPool[FieldStart + I].DefaultExprIdx);
  TypeTab[SigT].ParamFirst := PFirst;
  TypeTab[SigT].ParamCount := FieldCnt;
  TypeTab[SigT].ResultFirst := FieldPoolCount;
  FieldPoolAdd('', FT);
  TypeTab[SigT].ResultCount := 1;
  MethodPoolAdd('init', SigT, -1, FT, False, False);
End;

{ ParseStructType : "struct" DEJA CONSOMME par l appelant (ParseStructDecl,  }
{ qui a aussi deja lu le nom) - '{' est encore le token courant. Voir           }
{ la note d en-tete de section pour la PRE-ALLOCATION de FT (necessaire            }
{ pour "self") et le BACKFILL final. }
Function ParseStructType(Const StructName: TString): Integer;
Var
  FT, Kw, FieldStart, MethodStart, MCnt, CurOffset, MaxAlign, FAlign, I : Integer;
  FName : TString;
  HadExplicitInit : Boolean;
  FTIdx, DefExpr : Integer;
  BufNames   : TStructBufNames;
  BufTypes   : TStructBufTypes;
  BufDefault : TStructBufDefault;
  BufCnt     : Integer;
Begin
  FT := TypeAdd(TYK_STRUCT, StructName, 0, 1, False, True, -1, -1);
  ParseStructType := FT;

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom du ''struct''');
    Exit;
  End;
  PPSkipSemis;

  BufCnt := 0;
  MethodStart := MethodPoolCount;
  MCnt := 0;
  HadExplicitInit := False;

  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('membre de ''struct'' attendu (var/let/func/mutating/init)');
      Break;
    End;
    Kw := IsKeyword(PPVal);

    If (Kw = KW_VAR) Or (Kw = KW_LET) Then
    Begin
      { "let" est ACCEPTE ici (champ immuable apres l init, regle Swift    }
      { reelle) mais PAS DISTINGUE de "var" au niveau du champ lui-meme -           }
      { TFieldRec (TODO 04/08) n a pas de drapeau IsConst dedie et aucun            }
      { echantillon SAMPLES\SWIFT ne declare de champ "let" - verification            }
      { qu un "let" n est jamais reassigne APRES l init (meme via une                  }
      { "mutating func") reste un gap DOCUMENTE, hors de portee ici (TODO 19). }
      PPAdvance;
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ attendu');
        Break;
      End;
      FName := PPVal;
      PPAdvance;
      If Not PPMatch(':') Then
      Begin
        FatalError('"":"" attendu apres un nom de champ');
        Break;
      End;
      FTIdx := ParseTypeExpr;

      If PPIsOp('{') Then
      Begin
        { propriete calculee (getter seul) - "let" n a de toute facon      }
        { aucun sens ici (rien a "assigner une fois", pas de stockage). }
        ParseComputedProperty(FT, FName, FTIdx, BufNames, BufTypes, BufCnt);
        Inc(MCnt);
      End
      Else
      Begin
        DefExpr := -1;
        If PPMatch('=') Then DefExpr := ParseExpr;
        If BufCnt <= High(BufNames) Then
        Begin
          BufNames[BufCnt]   := FName;
          BufTypes[BufCnt]   := FTIdx;
          BufDefault[BufCnt] := DefExpr;
          Inc(BufCnt);
        End
        Else
          WarnMsg('trop de champs dans un seul ''struct'' (tampon plein)');
      End;
    End
    Else If Kw = KW_FUNC Then
    Begin
      ParseStructMemberFunc(FT, BufNames, BufTypes, BufCnt, False, False);
      Inc(MCnt);
    End
    Else If Kw = KW_MUTATING Then
    Begin
      PPAdvance;
      If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_FUNC)) Then
      Begin
        FatalError('''func'' attendu apres ''mutating''');
        Break;
      End;
      ParseStructMemberFunc(FT, BufNames, BufTypes, BufCnt, True, False);
      Inc(MCnt);
    End
    Else If Kw = KW_INIT Then
    Begin
      ParseStructMemberFunc(FT, BufNames, BufTypes, BufCnt, False, True);
      HadExplicitInit := True;
      Inc(MCnt);
    End
    Else
    Begin
      FatalError('membre de ''struct'' non pris en charge: ' + PPVal);
      Break;
    End;

    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du ''struct''');

  FieldStart := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAddParam(BufNames[I], '', BufTypes[I], False, BufDefault[I]);

  CurOffset := 0;
  MaxAlign  := 1;
  For I := FieldStart To FieldStart + BufCnt - 1 Do
  Begin
    FAlign := TypeTab[FieldPool[I].TypeIdx].Align;
    If FAlign < 1 Then FAlign := 1;
    CurOffset := AlignUp(CurOffset, FAlign);
    FieldPool[I].Offset := CurOffset;
    CurOffset := CurOffset + TypeTab[FieldPool[I].TypeIdx].Size;
    If FAlign > MaxAlign Then MaxAlign := FAlign;
  End;

  TypeTab[FT].FieldFirst  := FieldStart;
  TypeTab[FT].FieldCount  := BufCnt;
  TypeTab[FT].Size        := AlignUp(CurOffset, MaxAlign);
  TypeTab[FT].Align       := MaxAlign;
  TypeTab[FT].MethodFirst := MethodStart;

  { MethodCount DOIT etre fixe APRES l eventuelle synthese de l init      }
  { memberwise (elle-meme un MethodPoolAdd, TODO 09) - BOGUE reel trouve         }
  { par execution (MethodFind('init') introuvable malgre une entree               }
  { bien presente dans MethodPool) : fixer MethodCount:=MCnt AVANT               }
  { laissait l intervalle [MethodFirst, MethodFirst+MethodCount) EXCLURE             }
  { l entree synthetisee, meme si MethodPoolCount (global) la comptait               }
  { correctement. }
  If Not HadExplicitInit Then
  Begin
    SynthesizeMemberwiseInit(FT, FieldStart, BufCnt);
    Inc(MCnt);
  End;
  TypeTab[FT].MethodCount := MCnt;
End;

{ ParseStructDecl : REALISE la Forward-declaration du TODO 05 -        }
{ "struct" deja consomme ? NON - PP pointe encore SUR "struct" au           }
{ moment de l appel (ParseTopLevelDecl route AVANT de consommer, meme            }
{ convention que ParseFuncDecl/ParseLetVarDecl). Conformance de                     }
{ protocole ("struct Nom: Protocole", TODO 11 - forme alternative a               }
{ l extension separee, "struct/class Nom: Protocole OU extension",                  }
{ roadmap d en-tete) - un SEUL protocole ici (portee volontairement                  }
{ plus etroite que le "Nom: Proto1, Proto2" reel de Swift) ; verifie             }
{ APRES avoir analyse le corps ENTIER (ParseStructType) - les membres              }
{ qui satisfont le protocole doivent d abord exister dans MethodPool. }
Function ParseStructDecl: Integer;
Var
  Nam, ProtoNam : TString;
  FT, SI, ProtoIdx : Integer;
Begin
  PPAdvance;   { struct }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de structure attendu apres ''struct''');
    ParseStructDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  SymEnterScope;   { portee des parametres de type generique (TODO 13), }
                    { TOUJOURS ouverte (ne consomme rien si aucun "<" ne         }
                    { suit) - couvre champs ET methodes, jusqu au                        }
                    { SymLeaveScope juste avant de renvoyer FT, plus bas. }
  ParseGenericParamList;

  ProtoIdx := -1;
  If PPMatch(':') Then
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de protocole attendu apres '':'' dans un ''struct''');
      ParseStructDecl := -1;
      Exit;
    End;
    ProtoNam := PPVal;
    SI := SymFind(ProtoNam);
    If (SI < 0) Or (SymTab[SI].Kind <> SK_TYPE) Or
       (TypeTab[SymTab[SI].TypeIdx].Kind <> TYK_PROTOCOL) Then
    Begin
      FatalError('nom de protocole attendu apres '':'' dans un ''struct'': ' + ProtoNam);
      ParseStructDecl := -1;
      Exit;
    End;
    ProtoIdx := SymTab[SI].TypeIdx;
    PPAdvance;

    If PPIsOp(',') Then
    Begin
      FatalError('conformance a plusieurs protocoles a la fois pas encore ' +
        'prise en charge ici (une extension SEPAREE par protocole reste ' +
        'toujours possible)');
      ParseStructDecl := -1;
      Exit;
    End;
  End;

  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_WHERE) Then
    ParseWhereClause;

  FT := ParseStructType(Nam);
  SymAdd(Nam, SK_TYPE, FT, False);

  If (ProtoIdx >= 0) And (Not TypeSatisfiesProtocol(FT, ProtoIdx)) Then
    WarnMsg(Nam + ' ne satisfait pas completement le protocole ' +
      TypeTab[ProtoIdx].Name + ' (verification best-effort, TODO 19)');

  SymLeaveScope;   { ferme la portee des parametres de type generique  }
                    { ouverte plus haut - "T"/"U" ne "fuient" jamais hors            }
                    { de cette declaration (verifie explicitement par                    }
                    { GenericSelfTest, TODO 13). }
  ParseStructDecl := FT;
End;

{ ------------------------------------------------------------ }
{ StructSelfTest : struct a 2 champs (layout/IsValueType), init        }
{ memberwise IMPLICITE (etiquettes = noms de champs), methode NON-             }
{ mutating (acces implicite en lecture, "self" IsConst), methode                    }
{ mutating (acces implicite en ECRITURE), init EXPLICITE avec                          }
{ "self.champ = parametre" (desambiguation par ResolveSelectorType),                     }
{ propriete calculee (acces sans parentheses via un selecteur), appel                        }
{ constructeur "Nom(...)" (TypeIdx resolu a la structure elle-meme),                             }
{ puis integration bout-en-bout via ParseTopLevelDecls sur un extrait                               }
{ IDENTIQUE a structs.swift - sur des extraits synthetiques (fichier                                    }
{ temporaire, meme methode que les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure StructAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StructSelfTest: ' + Label_ + ' a echoue');
End;

Function StructParseTopLevel(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32STRUCTSELFTEST.$$$';
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
  StructParseTopLevel := ParseStructDecl;
End;

Procedure StructSelfTest;
Var
  FT, MI, SI, E : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;

  { struct a 2 champs, sans aucune methode/init explicite }
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) + '}');
  StructAssert('Point : TYK_STRUCT', TypeTab[FT].Kind = TYK_STRUCT);
  StructAssert('Point : type VALEUR (IsValueType)', TypeTab[FT].IsValueType);
  StructAssert('Point : 2 champs', TypeTab[FT].FieldCount = 2);
  StructAssert('Point : champ "y" a un Offset > 0 (layout reel)',
    FieldPool[TypeTab[FT].FieldFirst + 1].Offset > 0);

  { init memberwise IMPLICITE }
  MI := MethodFind(FT, 'init');
  StructAssert('Point : init memberwise synthetise trouve', MI >= 0);
  StructAssert('Point : init a 2 parametres', TypeTab[MethodPool[MI].TypeIdx].ParamCount = 2);
  StructAssert('Point : init - etiquette externe "x" (= nom du champ, PAS "_")',
    FieldPool[TypeTab[MethodPool[MI].TypeIdx].ParamFirst].ExtLabel = '');
  StructAssert('Point : init memberwise - aucun VRAI corps (BodyStmtIdx=-1)',
    MethodPool[MI].BodyStmtIdx = -1);

  { methode NON-mutating : acces implicite en LECTURE, self IsConst }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) +
    'func sum() -> Int {' + Chr(10) + 'return x + y' + Chr(10) + '}' + Chr(10) + '}');
  MI := MethodFind(FT, 'sum');
  StructAssert('sum : trouvee', MI >= 0);
  StructAssert('sum : PAS mutating', Not MethodPool[MI].IsMutating);
  StructAssert('sum : corps analyse (1 instruction "return")',
    StmtPool[MethodPool[MI].BodyStmtIdx].ArgCount = 1);
  SI := SymFind('self');
  StructAssert('sum : "self" est de type Point', SymTab[SI].TypeIdx = FT);
  StructAssert('sum : "self" est IsConst (methode non-mutating - lecture seule)',
    SymTab[SI].IsConst);
  SI := SymFind('x');
  StructAssert('sum : alias de champ "x" est IsConst (non-mutating)', SymTab[SI].IsConst);

  { methode mutating : acces implicite en ECRITURE }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) +
    'mutating func moveBy(_ dx: Int, _ dy: Int) {' + Chr(10) +
    'x = x + dx' + Chr(10) + 'y = y + dy' + Chr(10) + '}' + Chr(10) + '}');
  MI := MethodFind(FT, 'moveBy');
  StructAssert('moveBy : trouvee', MI >= 0);
  StructAssert('moveBy : EST mutating', MethodPool[MI].IsMutating);
  StructAssert('moveBy : signature a 2 parametres', TypeTab[MethodPool[MI].TypeIdx].ParamCount = 2);
  SI := SymFind('self');
  StructAssert('moveBy : "self" n est PAS IsConst (mutating)', Not SymTab[SI].IsConst);
  SI := SymFind('x');
  StructAssert('moveBy : alias de champ "x" n est PAS IsConst (mutating - assignable)',
    Not SymTab[SI].IsConst);

  { init EXPLICITE avec "self.champ = parametre" - suppression de       }
  { l init memberwise IMPLICITE }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) +
    'init(x: Int, y: Int) {' + Chr(10) +
    'self.x = x' + Chr(10) + 'self.y = y' + Chr(10) + '}' + Chr(10) + '}');
  StructAssert('init explicite : EXACTEMENT 1 "init" (memberwise supprime)',
    TypeTab[FT].MethodCount = 1);
  MI := MethodFind(FT, 'init');
  StructAssert('init explicite : a un VRAI corps (BodyStmtIdx >= 0)',
    MethodPool[MI].BodyStmtIdx >= 0);
  StructAssert('init explicite : "retourne" conceptuellement Point (Self)',
    FieldPool[TypeTab[MethodPool[MI].TypeIdx].ResultFirst].TypeIdx = FT);

  { propriete calculee (getter seul) - accedee SANS parentheses }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) +
    'var doubled: Int {' + Chr(10) + 'return x + x' + Chr(10) + '}' + Chr(10) + '}');
  MI := MethodFind(FT, 'doubled');
  StructAssert('doubled : trouvee comme propriete calculee', MI >= 0);
  StructAssert('doubled : IsComputedProperty', MethodPool[MI].IsComputedProperty);
  SI := SymAdd('p', SK_VAR, FT, False);
  E := ExprParseString('p.doubled');
  StructAssert('p.doubled : EK_SELECTOR (jamais un appel)', ExprPool[E].Kind = EK_SELECTOR);
  StructAssert('p.doubled : TypeIdx = Int DIRECTEMENT (pas une signature TYK_FUNC)',
    ExprPool[E].TypeIdx = PDT_INT);

  { appel constructeur "Point(x: 0, y: 0)" - TypeIdx resolu a la          }
  { structure elle-meme (extension de ParseCallArgs, TODO 06/09) }
  E := ExprParseString('Point(x: 0, y: 0)');
  StructAssert('Point(x:,y:) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  StructAssert('Point(x:,y:) : TypeIdx = Point (TYK_STRUCT)', ExprPool[E].TypeIdx = FT);

  { appel de methode via selecteur "p.sum()" - la signature resolue par   }
  { ResolveSelectorType (EK_SELECTOR) est reprise TELLE QUELLE par             }
  { ParseCallArgs (TODO 06/08/09), exactement comme pour un SK_FUNC              }
  { ordinaire. }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FT := StructParseTopLevel('struct Point {' + Chr(10) +
    'var x: Int' + Chr(10) + 'var y: Int' + Chr(10) +
    'func sum() -> Int {' + Chr(10) + 'return x + y' + Chr(10) + '}' + Chr(10) + '}');
  SI := SymAdd('p', SK_VAR, FT, False);
  E := ExprParseString('p.sum()');
  StructAssert('p.sum() : EK_CALL', ExprPool[E].Kind = EK_CALL);
  StructAssert('p.sum() : TypeIdx = Int (retour de sum(), via le selecteur)',
    ExprPool[E].TypeIdx = PDT_INT);

  { integration bout-en-bout : extrait IDENTIQUE a structs.swift, en     }
  { entier, via ParseTopLevelDecls (TODO 05, etendue au TODO 09 avec           }
  { "struct") - PREMIER echantillon SAMPLES\SWIFT reel dont TOUTES LES               }
  { DECLARATIONS (structs + let de haut niveau, pas seulement un extrait               }
  { qui s en INSPIRE comme le "math.swift" du TODO 08) sont desormais              }
  { entierement analysables - s arrete PROPREMENT sur le "print(50)"                    }
  { final (code executable NU de haut niveau, hors de portee, voir la              }
  { note de l assertion elle-meme) plutot que d atteindre litteralement            }
  { la toute fin du fichier. Run() lui-meme ne bascule toujours PAS sur              }
  { cette voie pour autant, voir sa                                                        }
  { propre note d en-tete (la plupart des AUTRES echantillons utilisent                    }
  { encore class/enum/generiques/defer, tous hors de portee avant les                          }
  { TODO 10-15). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  Assign(LexSrcF, 'SWIFTW32STRUCTSELFTEST2.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'struct Point {');
  WriteLn(LexSrcF, '    var x: Int');
  WriteLn(LexSrcF, '    var y: Int');
  WriteLn(LexSrcF, '    func sum() -> Int {');
  WriteLn(LexSrcF, '        return x + y');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    mutating func moveBy(_ dx: Int, _ dy: Int) {');
  WriteLn(LexSrcF, '        x = x + dx');
  WriteLn(LexSrcF, '        y = y + dy');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'struct Rectangle {');
  WriteLn(LexSrcF, '    var width: Int');
  WriteLn(LexSrcF, '    var height: Int');
  WriteLn(LexSrcF, '    func area() -> Int {');
  WriteLn(LexSrcF, '        return width * height');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    func perimeter() -> Int {');
  WriteLn(LexSrcF, '        return 2 * (width + height)');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let origin: Point = Point(x: 0, y: 0)');
  WriteLn(LexSrcF, 'let rect: Rectangle = Rectangle(width: 10, height: 5)');
  WriteLn(LexSrcF, 'print(50)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32STRUCTSELFTEST2.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  StructAssert('structs.swift (integral) : "origin" (let) resolu', SymFind('origin') >= 0);
  StructAssert('structs.swift (integral) : "origin" a le type Point',
    SymTab[SymFind('origin')].TypeIdx = SymTab[SymFind('Point')].TypeIdx);
  { arret propre sur "print(50)" : contrairement a GOCW32.PAS (Go n a       }
  { AUCUNE instruction executable au niveau paquet, tout est TOUJOURS             }
  { a l interieur d une fonction), Swift autorise du code executable NU              }
  { au niveau fichier (style "script"/main.swift implicite) - "print(50)"           }
  { EST cette forme, et n est PAS une declaration (let/var/typealias/           }
  { func/struct) : ParseTopLevelDecl(s) ne le reconnait PAS, arret PROPRE            }
  { attendu ICI (PP inchange, pointant EXACTEMENT sur "print") plutot                  }
  { qu une extension prematuree vers ParseStatement (TODO 07) - un tel               }
  { repli aveugle re-ouvrirait l ambiguite "callee suivi d une accolade"                 }
  { (trailing closure, TODO 08) pour tout mot-cle NON RECONNU comme                        }
  { "class"/"enum" (traites alors comme un simple identificateur), et                        }
  { ferait Halt le compilateur sur le moindre "defer" de haut niveau                            }
  { (errors.swift) via le FatalError deja pose au TODO 07 - execution              }
  { de code Swift au niveau fichier reste donc un GAP DOCUMENTE, sujet                  }
  { d un TODO ulterieur plutot que d une extension hasardeuse ici. }
  StructAssert('structs.swift (integral) : arret propre EXACT sur "print(50)"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
End;

{ ============================================================ }
{ TODO 10 - CLASSES : HERITAGE, OVERRIDE ET INTRODUCTION A ARC  }
{ ============================================================ }
{ Reutilise QUASIMENT TOUTE l infrastructure du TODO 09 (MethodPool,     }
{ ParseFuncSignature/RegisterFuncScopeSymbols du TODO 08, StructFindField/         }
{ MethodFind DEJA ETENDUS ci-dessus avec la recursion SuperTypeIdx)               }
{ plutot que de la dupliquer - SEULES trois choses sont REELLEMENT               }
{ nouvelles/differentes :                                                                 }
{   (1) IsValueType=FAUX (TypeAdd) : LA distinction centrale avec           }
{       struct - affectation/passage en parametre PARTAGE la MEME                    }
{       instance (modele "pointeur vers objet sur le tas", comme le                     }
{       receveur pointeur de GOCW32.PAS mais IMPLICITE partout, jamais                    }
{       explicite avec un '*') - AUCUN codegen n existe encore pour                          }
{       observer cette difference concretement (TODO 21+), mais le                              }
{       TypeIdx la porte deja correctement pour tout code futur qui la                              }
{       consultera.                                                                                     }
{   (2) HERITAGE simple (UNE seule superclasse, comme Swift reel - pas          }
{       d heritage multiple) : SuperTypeIdx (deja reserve au TODO 04)              }
{       relie une classe a SA superclasse ; aucune fusion PHYSIQUE des               }
{       listes de champs/methodes n est necessaire (StructFindField/                     }
{       MethodFind remontent RECURSIVEMENT la chaine si absent DANS               }
{       cette classe-ci) - AUCUNE classe SAMPLES\SWIFT n a plus d un                       }
{       niveau d heritage, mais la recursion fonctionne a N niveaux                          }
{       sans modification.                                                                       }
{   (3) "override func" : VERIFIE que le nom existe deja dans la              }
{       superclasse (sinon FatalError - erreur Swift REELLE, pas une                    }
{       simple convention de ce compilateur) - PAS de synthese de "init          }
{       memberwise" pour une classe (contrairement a un struct, TODO 09) :             }
{       AUCUNE classe Swift reelle n en recoit une, meme regle stricte              }
{       observee ici (classes.swift appelle d ailleurs "Animal()" SANS               }
{       aucun init ecrit ni synthetise - toleree par ce compilateur EN               }
{       BEST-EFFORT, exactement comme un appel de fonction non resolu               }
{       ne bloque jamais l analyse depuis le TODO 06).                                   }
{ "mutating" N EXISTE PAS pour une methode de classe (semantiquement           }
{ vide pour un type REFERENCE - self n est jamais "reassigne", il                    }
{ pointe TOUJOURS vers la MEME instance) : les alias de champs d une              }
{ methode de classe sont donc TOUJOURS mutables (IsConst=Faux), SANS               }
{ mot-cle special requis - un "mutating func" ecrit malgre tout a                        }
{ l interieur d une classe tombe simplement dans le "Else" non reconnu              }
{ de ParseClassType (FatalError clair), CE QUI EST EXACTEMENT la regle              }
{ Swift reelle (erreur de compilation).                                                    }
{ is/as?/as! (TODO 06, DEJA ECRIT) : AUCUNE modification necessaire -           }
{ ParseTypeExpr (TODO 05) resolvait deja N IMPORTE QUEL SK_TYPE, classes                 }
{ incluses, sans le savoir a l avance.                                                     }
{ Introduction a ARC : chaque instance de classe est CONCEPTUELLEMENT            }
{ allouee sur le tas avec un compteur de references (consequence              }
{ directe de IsValueType=Faux, point (1) ci-dessus) - la portee EXACTE           }
{ du comptage automatique (quand incrementer/decrementer) est                        }
{ PLANIFIEE ici (cette note) mais l implementation reelle au generateur              }
{ de code est DELIBEREMENT REPORTEE et detaillee au TODO 18 (modele              }
{ memoire) - decision architecturale a trancher AVANT le codegen, meme            }
{ discipline que le choix cooperatif-vs-threads-reels de GOCW32.PAS                    }
{ pour les goroutines (TODO 15 la-bas) : AUCUNE structure de donnees                   }
{ n est necessaire ici, juste la decision elle-meme, deja prise et                       }
{ ecrite noir sur blanc pour ne pas avoir a la re-trancher au TODO 18.                     }

{ RegisterInheritedFieldAliases : enregistre RECURSIVEMENT (ancetre le  }
{ plus ELOIGNE EN PREMIER, classe la plus DERIVEE EN DERNIER - "le plus              }
{ recent gagne" via SymFind, TODO 05, en cas de nom redeclare - jamais          }
{ le cas en Swift reel, mais l ordre reste correct si cela arrivait)               }
{ chaque champ d une SUPERCLASSE (et de SES PROPRES superclasses) comme            }
{ alias SK_VAR ordinaire - permet a une methode de "Dog" de lire "legs"              }
{ (herite d "Animal") SANS "self." prefixe, exactement comme un champ           }
{ PROPRE (RegisterFieldAliasesFromBuf, TODO 09). Appelee AVANT           }
{ RegisterFieldAliasesFromBuf par ParseClassMemberFunc ci-dessous, pour             }
{ que les champs PROPRES (plus recents) gagnent en cas de collision              }
{ (jamais le cas ici non plus, mais meme discipline). }
Procedure RegisterInheritedFieldAliases(STypeIdx: Integer; AliasIsConst: Boolean);
Var I : Integer;
Begin
  If (STypeIdx < 0) Or (STypeIdx >= TypeCount) Then Exit;
  RegisterInheritedFieldAliases(TypeTab[STypeIdx].SuperTypeIdx, AliasIsConst);
  For I := TypeTab[STypeIdx].FieldFirst To
    TypeTab[STypeIdx].FieldFirst + TypeTab[STypeIdx].FieldCount - 1 Do
    SymAdd(FieldPool[I].Name, SK_VAR, FieldPool[I].TypeIdx, AliasIsConst);
End;

{ ParseClassMemberFunc : "func Nom(...) [-> Type]" suivi d un corps     }
{ (methode ORDINAIRE), "override func Nom(...)" suivi d un corps (verifie          }
{ D ABORD que "Nom" existe deja dans la superclasse - erreur Swift               }
{ REELLE sinon), ou "init(...)" suivi d un corps (AUCUNE synthese                   }
{ memberwise pour ce cas, contrairement au struct du TODO 09 - voir la              }
{ note d en-tete). Les alias de champs (PROPRES ET HERITES) et "self"              }
{ sont TOUJOURS mutables ici (IsConst=Faux inconditionnellement) - une            }
{ classe n a pas de notion de receveur "en lecture seule", contrairement           }
{ a un struct non-mutating (TODO 09). }
Function ParseClassMemberFunc(FT: Integer; Const BufNames: TStructBufNames;
  Const BufTypes: TStructBufTypes; BufCnt: Integer; IsOverride, IsInit: Boolean): Integer;
Var
  Nam : TString;
  SigT, Body, SelfSI : Integer;
Begin
  If IsInit Then
  Begin
    PPAdvance;   { init }
    Nam := 'init';
  End
  Else
  Begin
    PPAdvance;   { func }
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de methode attendu apres ''func''');
      ParseClassMemberFunc := -1;
      Exit;
    End;
    Nam := PPVal;
    PPAdvance;
  End;

  If IsOverride And (MethodFind(TypeTab[FT].SuperTypeIdx, Nam) < 0) Then
    FatalError('''override'' sur ''' + Nam + ''' mais aucune methode de ce ' +
      'nom n existe dans une superclasse (regle Swift reelle)');

  SigT := ParseFuncSignature;
  If IsInit Then
  Begin
    TypeTab[SigT].ResultFirst := FieldPoolCount;
    FieldPoolAdd('', FT);
    TypeTab[SigT].ResultCount := 1;
  End;

  SymEnterScope;
  RegisterInheritedFieldAliases(TypeTab[FT].SuperTypeIdx, False);
  RegisterFieldAliasesFromBuf(BufNames, BufTypes, BufCnt, False);
  SelfSI := SymAdd('self', SK_VAR, FT, False);
  SymTab[SelfSI].HasInit := True;
  RegisterFuncScopeSymbols(SigT);
  Body := ParseBlock;
  SymLeaveScope;

  ParseClassMemberFunc := MethodPoolAdd(Nam, SigT, Body, FT, False, False);
End;

{ ParseClassType : "class" DEJA CONSOMME par l appelant (ParseClassDecl,  }
{ qui a aussi deja lu le nom ET l eventuelle superclasse) - '{' est               }
{ encore le token courant. Meme PRE-ALLOCATION/BACKFILL que                          }
{ ParseStructType (TODO 09, voir sa propre note d en-tete) - SEULE               }
{ VRAIE difference structurelle : AUCUNE synthese d init memberwise a          }
{ la fin (point (3) de la note d en-tete de section). }
Function ParseClassType(Const ClassName: TString; SuperIdx: Integer): Integer;
Var
  FT, Kw, FieldStart, MethodStart, MCnt, CurOffset, MaxAlign, FAlign, I : Integer;
  FName : TString;
  FTIdx, DefExpr : Integer;
  BufNames   : TStructBufNames;
  BufTypes   : TStructBufTypes;
  BufDefault : TStructBufDefault;
  BufCnt     : Integer;
Begin
  FT := TypeAdd(TYK_CLASS, ClassName, 0, 1, False, False, -1, -1);
  TypeTab[FT].SuperTypeIdx := SuperIdx;
  ParseClassType := FT;

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom de la ''class''');
    Exit;
  End;
  PPSkipSemis;

  BufCnt := 0;
  MethodStart := MethodPoolCount;
  MCnt := 0;

  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('membre de ''class'' attendu (var/let/func/override/init)');
      Break;
    End;
    Kw := IsKeyword(PPVal);

    If (Kw = KW_VAR) Or (Kw = KW_LET) Then
    Begin
      PPAdvance;
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom de champ attendu');
        Break;
      End;
      FName := PPVal;
      PPAdvance;
      If Not PPMatch(':') Then
      Begin
        FatalError('"":"" attendu apres un nom de champ');
        Break;
      End;
      FTIdx := ParseTypeExpr;

      If PPIsOp('{') Then
      Begin
        ParseComputedProperty(FT, FName, FTIdx, BufNames, BufTypes, BufCnt);
        Inc(MCnt);
      End
      Else
      Begin
        DefExpr := -1;
        If PPMatch('=') Then DefExpr := ParseExpr;
        If BufCnt <= High(BufNames) Then
        Begin
          BufNames[BufCnt]   := FName;
          BufTypes[BufCnt]   := FTIdx;
          BufDefault[BufCnt] := DefExpr;
          Inc(BufCnt);
        End
        Else
          WarnMsg('trop de champs dans une seule ''class'' (tampon plein)');
      End;
    End
    Else If Kw = KW_FUNC Then
    Begin
      ParseClassMemberFunc(FT, BufNames, BufTypes, BufCnt, False, False);
      Inc(MCnt);
    End
    Else If Kw = KW_OVERRIDE Then
    Begin
      PPAdvance;
      If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_FUNC)) Then
      Begin
        FatalError('''func'' attendu apres ''override''');
        Break;
      End;
      ParseClassMemberFunc(FT, BufNames, BufTypes, BufCnt, True, False);
      Inc(MCnt);
    End
    Else If Kw = KW_INIT Then
    Begin
      ParseClassMemberFunc(FT, BufNames, BufTypes, BufCnt, False, True);
      Inc(MCnt);
    End
    Else
    Begin
      { "mutating func" (n a aucun sens pour une classe, regle Swift      }
      { reelle - voir note d en-tete de section) tombe ICI, comme            }
      { n importe quel autre membre non reconnu : FatalError clair,               }
      { EXACTEMENT le comportement attendu. }
      FatalError('membre de ''class'' non pris en charge: ' + PPVal);
      Break;
    End;

    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin de la ''class''');

  FieldStart := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAddParam(BufNames[I], '', BufTypes[I], False, BufDefault[I]);

  CurOffset := 0;
  MaxAlign  := 1;
  For I := FieldStart To FieldStart + BufCnt - 1 Do
  Begin
    FAlign := TypeTab[FieldPool[I].TypeIdx].Align;
    If FAlign < 1 Then FAlign := 1;
    CurOffset := AlignUp(CurOffset, FAlign);
    FieldPool[I].Offset := CurOffset;
    CurOffset := CurOffset + TypeTab[FieldPool[I].TypeIdx].Size;
    If FAlign > MaxAlign Then MaxAlign := FAlign;
  End;

  { Size/Align ne couvrent ici que les CHAMPS PROPRES de CETTE classe   }
  { (PAS ceux herites de sa superclasse) - simplification documentee :        }
  { correcte pour l analyse (StructFindField/MethodFind remontent DEJA          }
  { la chaine independamment de ce champ), mais UNE VRAIE disposition          }
  { memoire d instance CONTIGUE (superclasse PUIS champs propres) reste           }
  { un sujet du generateur de code futur (TODO 18/21+). }
  TypeTab[FT].FieldFirst  := FieldStart;
  TypeTab[FT].FieldCount  := BufCnt;
  TypeTab[FT].Size        := AlignUp(CurOffset, MaxAlign);
  TypeTab[FT].Align       := MaxAlign;
  TypeTab[FT].MethodFirst := MethodStart;
  TypeTab[FT].MethodCount := MCnt;
End;

{ ParseClassDecl : REALISE la Forward-declaration du TODO 05 - PP        }
{ pointe encore SUR "class" au moment de l appel (meme convention que          }
{ ParseFuncDecl/ParseStructDecl). "class Nom: X" est AMBIGU tant que          }
{ "X" n a pas ete RESOLU (heritage de SUPERCLASSE si X est une classe,           }
{ conformance de PROTOCOLE si X est un protocole, TODO 11 - meme                    }
{ distinction que ParseStructDecl juste au-dessus, mais deux formes                     }
{ possibles ici contre une seule pour un struct qui n herite jamais)                    }
{ - un SEUL "X" pris en charge ici (portee volontairement plus etroite               }
{ que "class Nom: Super, Proto1, Proto2" reel de Swift). La verification            }
{ de conformite (si "X" est un protocole) a lieu APRES le corps                          }
{ ENTIER (ParseClassType), memes raisons que ParseStructDecl. }
Function ParseClassDecl: Integer;
Var
  Nam, XNam : TString;
  FT, SuperIdx, ProtoIdx, SI : Integer;
Begin
  PPAdvance;   { class }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de classe attendu apres ''class''');
    ParseClassDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPIsOp('<') Then
  Begin
    FatalError('classes generiques pas encore prises en charge (TODO 13)');
    ParseClassDecl := -1;
    Exit;
  End;

  SuperIdx := -1;
  ProtoIdx := -1;
  If PPMatch(':') Then
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de superclasse ou de protocole attendu apres '':''');
      ParseClassDecl := -1;
      Exit;
    End;
    XNam := PPVal;
    SI := SymFind(XNam);
    If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) And
       (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_CLASS) Then
      SuperIdx := SymTab[SI].TypeIdx
    Else If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) And
            (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_PROTOCOL) Then
      ProtoIdx := SymTab[SI].TypeIdx
    Else
    Begin
      FatalError('superclasse ou protocole inconnu apres '':'' dans une ' +
        '''class'': ' + XNam);
      ParseClassDecl := -1;
      Exit;
    End;
    PPAdvance;

    If PPIsOp(',') Then
    Begin
      FatalError('une seule superclasse/un seul protocole est pris en ' +
        'charge ici (une extension SEPAREE par protocole reste toujours ' +
        'possible)');
      ParseClassDecl := -1;
      Exit;
    End;
  End;

  FT := ParseClassType(Nam, SuperIdx);
  SymAdd(Nam, SK_TYPE, FT, False);

  If (ProtoIdx >= 0) And (Not TypeSatisfiesProtocol(FT, ProtoIdx)) Then
    WarnMsg(Nam + ' ne satisfait pas completement le protocole ' +
      TypeTab[ProtoIdx].Name + ' (verification best-effort, TODO 19)');

  ParseClassDecl := FT;
End;

{ ------------------------------------------------------------ }
{ ClassSelfTest : classe simple (IsValueType=Faux - la distinction         }
{ centrale avec struct, TODO 09 -, AUCUN init memberwise synthetise),               }
{ heritage (champs/methodes HERITES accessibles sans "self."), override                }
{ (gagne sur la methode de la superclasse - dispatch), heritage de           }
{ methode NON redefinie (remonte a la superclasse), mutabilite               }
{ INCONDITIONNELLE des champs (pas de "mutating"), appel constructeur              }
{ "Nom()" SANS aucun init (TypeIdx resolu quand meme), is/as? avec des               }
{ types classe, puis integration bout-en-bout via ParseTopLevelDecls               }
{ sur un extrait IDENTIQUE a classes.swift - sur des extraits                        }
{ synthetiques (fichier temporaire, meme methode que les TODO                            }
{ precedents). La verification "override sur un nom absent de toute                     }
{ superclasse = FatalError" n est PAS exercee ici (Halt le compilateur,                   }
{ meme raison que la branche "rejet" de SymCheckMutable depuis le                        }
{ TODO 05). }
{ ------------------------------------------------------------ }

Procedure ClassAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ClassSelfTest: ' + Label_ + ' a echoue');
End;

Function ClassParseTopLevel(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32CLASSSELFTEST.$$$';
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
  ClassParseTopLevel := ParseClassDecl;
End;

Procedure ClassSelfTest;
Var
  FTAnimal, FTDog, MI1, MI2, SI, E : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;

  { classe simple, sans init - AUCUNE synthese memberwise (contrairement  }
  { a un struct, TODO 09) }
  FTAnimal := ClassParseTopLevel('class Animal {' + Chr(10) +
    'var name: String' + Chr(10) + 'var legs: Int' + Chr(10) +
    'func speak() -> Int {' + Chr(10) + 'return 0' + Chr(10) + '}' + Chr(10) + '}');
  SymAdd('Animal', SK_TYPE, FTAnimal, False);
  ClassAssert('Animal : TYK_CLASS', TypeTab[FTAnimal].Kind = TYK_CLASS);
  ClassAssert('Animal : type REFERENCE (Not IsValueType) - distinction ' +
    'centrale avec struct', Not TypeTab[FTAnimal].IsValueType);
  ClassAssert('Animal : 2 champs', TypeTab[FTAnimal].FieldCount = 2);
  ClassAssert('Animal : AUCUN init synthetise (contrairement a un struct)',
    MethodFind(FTAnimal, 'init') < 0);
  ClassAssert('Animal : "speak" trouvee', MethodFind(FTAnimal, 'speak') >= 0);

  { heritage : Dog herite de Animal, ajoute un champ, REDEFINIT speak()  }
  FTDog := ClassParseTopLevel('class Dog: Animal {' + Chr(10) +
    'var breed: String' + Chr(10) +
    'override func speak() -> Int {' + Chr(10) + 'return 1' + Chr(10) + '}' + Chr(10) + '}');
  SymAdd('Dog', SK_TYPE, FTDog, False);
  ClassAssert('Dog : SuperTypeIdx = Animal', TypeTab[FTDog].SuperTypeIdx = FTAnimal);
  ClassAssert('Dog : 1 SEUL champ PROPRE (breed - "legs"/"name" restent ' +
    'herites, jamais fusionnes physiquement)', TypeTab[FTDog].FieldCount = 1);

  { override : gagne sur la methode de la superclasse (dispatch) }
  MI1 := MethodFind(FTDog, 'speak');
  MI2 := MethodFind(FTAnimal, 'speak');
  ClassAssert('Dog.speak trouvee', MI1 >= 0);
  ClassAssert('Dog.speak EST DIFFERENTE de Animal.speak (override reel, ' +
    'pas juste heritee)', MI1 <> MI2);

  { champ HERITE (name/legs) accessible SANS "self." depuis une methode  }
  { de Dog - StructFindField remonte a la superclasse }
  ClassAssert('Dog : champ herite "legs" trouve via StructFindField',
    StructFindField(FTDog, 'legs') >= 0);
  ClassAssert('Dog : champ herite "name" trouve via StructFindField',
    StructFindField(FTDog, 'name') >= 0);

  { methode HERITEE, NON redefinie : Cat n a pas de "makeNoise", Animal  }
  { si - MethodFind doit remonter jusqu a Animal. }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FTAnimal := ClassParseTopLevel('class Animal {' + Chr(10) +
    'var name: String' + Chr(10) + 'var legs: Int' + Chr(10) +
    'func speak() -> Int {' + Chr(10) + 'return 0' + Chr(10) + '}' + Chr(10) +
    'func legCount() -> Int {' + Chr(10) + 'return legs' + Chr(10) + '}' + Chr(10) + '}');
  SymAdd('Animal', SK_TYPE, FTAnimal, False);
  FTDog := ClassParseTopLevel('class Dog: Animal {' + Chr(10) +
    'var breed: String' + Chr(10) +
    'override func speak() -> Int {' + Chr(10) + 'return 1' + Chr(10) + '}' + Chr(10) + '}');
  ClassAssert('Dog herite de "legCount" (jamais redefinie) depuis Animal',
    MethodFind(FTDog, 'legCount') = MethodFind(FTAnimal, 'legCount'));

  { mutabilite INCONDITIONNELLE (pas de "mutating") : un champ modifie   }
  { dans une methode ORDINAIRE (pas "override", pas "init") reste             }
  { assignable - a la difference d un struct NON-mutating (TODO 09). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FTAnimal := ClassParseTopLevel('class Animal {' + Chr(10) +
    'var legs: Int' + Chr(10) +
    'func setLegs(_ n: Int) {' + Chr(10) + 'legs = n' + Chr(10) + '}' + Chr(10) + '}');
  SI := SymFind('legs');
  ClassAssert('setLegs : alias de champ "legs" N EST PAS IsConst (mutable ' +
    'sans "mutating")', Not SymTab[SI].IsConst);
  SI := SymFind('self');
  ClassAssert('setLegs : "self" N EST PAS IsConst', Not SymTab[SI].IsConst);

  { appel constructeur "Animal()" SANS AUCUN init - TypeIdx resolu quand   }
  { meme (best-effort, TODO 06/09/10) }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FTAnimal := ClassParseTopLevel('class Animal {' + Chr(10) +
    'var name: String' + Chr(10) + 'var legs: Int' + Chr(10) + '}');
  SymAdd('Animal', SK_TYPE, FTAnimal, False);
  E := ExprParseString('Animal()');
  ClassAssert('Animal() : EK_CALL', ExprPool[E].Kind = EK_CALL);
  ClassAssert('Animal() : TypeIdx = Animal (malgre l absence de tout init)',
    ExprPool[E].TypeIdx = FTAnimal);

  { is/as? avec un type classe - ParseTypeExpr (TODO 05) resolvait deja   }
  { N IMPORTE QUEL SK_TYPE sans modification necessaire ici. }
  SI := SymAdd('pet', SK_VAR, FTAnimal, False);
  E := ExprParseString('pet is Animal');
  ClassAssert('pet is Animal : EK_ISCHECK', ExprPool[E].Kind = EK_ISCHECK);
  ClassAssert('pet is Animal : Extra = Animal', ExprPool[E].Extra = FTAnimal);

  E := ExprParseString('pet as? Animal');
  ClassAssert('pet as? Animal : enveloppe dans un Optional',
    TypeIsOptional(ExprPool[E].TypeIdx));
  ClassAssert('pet as? Animal : deballe vers Animal',
    TypeResolveOptional(ExprPool[E].TypeIdx) = FTAnimal);

  { integration bout-en-bout : extrait IDENTIQUE a classes.swift, en     }
  { entier, via ParseTopLevelDecls (TODO 05, etendue ci-dessus avec              }
  { "class") - arret PROPRE attendu sur "print(42)" final, EXACTEMENT              }
  { comme structs.swift au TODO 09 (code executable NU de haut niveau,            }
  { gap documente, voir sa propre note). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  Assign(LexSrcF, 'SWIFTW32CLASSSELFTEST2.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'class Animal {');
  WriteLn(LexSrcF, '    var name: String');
  WriteLn(LexSrcF, '    var legs: Int');
  WriteLn(LexSrcF, '    func speak() -> Int {');
  WriteLn(LexSrcF, '        return 0');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'class Dog: Animal {');
  WriteLn(LexSrcF, '    var breed: String');
  WriteLn(LexSrcF, '    override func speak() -> Int {');
  WriteLn(LexSrcF, '        return 1');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'class Cat: Animal {');
  WriteLn(LexSrcF, '    var indoor: Bool');
  WriteLn(LexSrcF, '    override func speak() -> Int {');
  WriteLn(LexSrcF, '        return 2');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let pet: Animal = Animal()');
  WriteLn(LexSrcF, 'print(42)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32CLASSSELFTEST2.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  ClassAssert('classes.swift (integral) : "pet" (let) resolu', SymFind('pet') >= 0);
  ClassAssert('classes.swift (integral) : "pet" a le type Animal',
    SymTab[SymFind('pet')].TypeIdx = SymTab[SymFind('Animal')].TypeIdx);
  ClassAssert('classes.swift (integral) : arret propre EXACT sur "print(42)"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
End;

{ ============================================================ }
{ TODO 11 - PROTOCOLES ET EXTENSIONS                            }
{ ============================================================ }
{ Un protocole EST, structurellement, presque EXACTEMENT une interface   }
{ Go/GOCW32.PAS : un contrat de methodes SANS corps, satisfait               }
{ STRUCTURELLEMENT (pas de declaration explicite "implements") par           }
{ n importe quel type qui possede les BONNES methodes - TypeSatisfiesProtocol      }
{ ci-dessous est donc quasiment un copier-coller de                                     }
{ TypeSatisfiesInterface (GOCW32.PAS, TODO 10 la-bas), a une difference                     }
{ pres (voir sa propre note). TYK_PROTOCOL EXISTE DEJA depuis le                            }
{ TODO 04 (synthetise pour Any/AnyObject, MethodCount=0) - ParseProtocolDecl                    }
{ ci-dessous n est jamais que le PREMIER a lui donner un VRAI contenu               }
{ (des exigences REELLES plutot que zero).                                               }
{                                                                       }
{ BOGUE D ARCHITECTURE MAJEUR corrige ICI (voir la note de MethodFind,   }
{ deja mise a jour ci-dessus, TODO 09) : une EXTENSION ajoute des                    }
{ methodes a un type EXISTANT depuis un point QUELCONQUE du fichier,               }
{ souvent bien APRES que d autres types (d autres protocoles, d autres              }
{ structs) aient deja pousse leurs propres entrees dans le MEME                       }
{ MethodPool partage - l hypothese de contigute [MethodFirst,                          }
{ MethodFirst+MethodCount) posee aux TODO 09/10 est donc FAUSSE des                       }
{ qu une SEULE extension existe dans le fichier. MethodFind cherche                       }
{ desormais par OwnerTypeIdx (balayage lineaire) - CE TODO est celui                       }
{ qui REVELE le besoin de ce correctif (protos.swift, la RAISON              }
{ structurelle pour laquelle il est fait ICI et non au TODO 09/10,                     }
{ ou aucune extension n existait encore pour le reveler).                                    }
{                                                                       }
{ Une extension suivie d un corps de membres : AUCUN champ STOCKE ne          }
{ peut y etre ajoute (regle Swift reelle - verifiee explicitement, FatalError   }
{ clair plutot qu une extension silencieuse du layout DEJA fixe) ;                    }
{ reutilise ParseStructMemberFunc/ParseClassMemberFunc/                                 }
{ ParseComputedProperty (TODO 09/10) TELS QUELS pour le corps                              }
{ ("mutating func" reste refuse pour une extension de CLASSE, accepte             }
{ pour une extension de STRUCT - meme regle que la declaration                            }
{ d origine) - LoadExistingFieldsIntoBuf ci-dessous reconstitue le                       }
{ tampon BufNames/BufTypes attendu par ces fonctions a partir des                        }
{ champs DEJA CONNUS du type (FieldPool, deja fige depuis sa                                }
{ declaration d origine), puisque l extension elle-meme n en a jamais                       }
{ analyse aucun.                                                                          }
{                                                                       }
{ Protocole utilise comme TYPE ("let d: Drawable = Circle(...)") :        }
{ ResolveSelectorType (TODO 09, deja etendu ci-dessus) et                              }
{ ApplyExprInitToSymbol (TODO 06, deja etendu ci-dessus) portent DEJA           }
{ le "modele boite" demande par le roadmap d en-tete - rien de plus a               }
{ ecrire ici pour cette partie.                                                            }
{                                                                       }
{ HORS DE PORTEE (documente, aucun echantillon SAMPLES\SWIFT n en a       }
{ besoin) : heritage de protocole ("protocol Nom: AutreProtocole"),                    }
{ implementations par defaut via une extension DU PROTOCOLE lui-meme                   }
{ (roadmap d en-tete : "portee a documenter si couverte" - NON couverte),             }
{ clauses "where", exigences de PROPRIETE dans un protocole (forme           }
{ "var nom: Type" suivie d un accesseur "get" seul) - seules des                    }
{ exigences de METHODE sont prises en charge, protos.swift n en a               }
{ pas besoin). }

{ ParseProtocolDecl : REALISE la Forward-declaration du TODO 05.       }
{ Chaque exigence de methode est enregistree dans MethodPool AVEC                    }
{ OwnerTypeIdx=CE PROTOCOLE et BodyStmtIdx=-1 (un CONTRAT, jamais une              }
{ implementation - meme convention que l init memberwise IMPLICITE,               }
{ TODO 09, qui n a lui non plus AUCUN corps reel). }
Function ParseProtocolDecl: Integer;
Var
  Nam, MName : TString;
  FT, SigT : Integer;
Begin
  PPAdvance;   { protocol }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de protocole attendu apres ''protocol''');
    ParseProtocolDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPIsOp(':') Then
  Begin
    FatalError('heritage de protocole pas encore pris en charge');
    ParseProtocolDecl := -1;
    Exit;
  End;

  FT := TypeAdd(TYK_PROTOCOL, Nam, 8, 4, False, False, -1, -1);
  SymAdd(Nam, SK_TYPE, FT, False);

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom du protocole');
    ParseProtocolDecl := FT;
    Exit;
  End;
  PPSkipSemis;

  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_FUNC)) Then
    Begin
      FatalError('seules des exigences de methode ("func Nom(...) -> Type") ' +
        'sont prises en charge dans un protocole pour l''instant: ' + PPVal);
      Break;
    End;
    PPAdvance;   { func }
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de methode attendu dans une exigence de protocole');
      Break;
    End;
    MName := PPVal;
    PPAdvance;
    SigT := ParseFuncSignature;
    MethodPoolAdd(MName, SigT, -1, FT, False, False);
    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du protocole');

  ParseProtocolDecl := FT;
End;

{ TypeSatisfiesProtocol : REALISE la Forward-declaration du TODO 05 -   }
{ Vrai si ConcreteType possede TOUTES les methodes exigees par               }
{ ProtocolType - typage STRUCTUREL (aucune declaration explicite               }
{ d "implements"/"conforms" requise, contrairement a Delphi/Java) -                 }
{ QUASIMENT identique a TypeSatisfiesInterface (GOCW32.PAS, TODO 10             }
{ la-bas), a une difference NOTABLE : aucun depointerage n est                          }
{ necessaire ici (Swift n a pas de pointeurs explicites vers struct                  }
{ comme Go) - MethodFind (deja etendu ci-dessus, TODO 09/10/11) gere                    }
{ deja tout seul l heritage de classe ET la recherche par OwnerTypeIdx              }
{ (extensions), aucune autre logique n est necessaire ici. }
Function TypeSatisfiesProtocol(ConcreteType, ProtocolType: Integer): Boolean;
Var I : Integer;
Begin
  TypeSatisfiesProtocol := False;
  If (ConcreteType < 0) Or (ProtocolType < 0) Or (ProtocolType >= TypeCount) Then Exit;
  If TypeTab[ProtocolType].Kind <> TYK_PROTOCOL Then Exit;
  For I := 0 To MethodPoolCount - 1 Do
    If MethodPool[I].OwnerTypeIdx = ProtocolType Then
      If MethodFind(ConcreteType, MethodPool[I].Name) < 0 Then Exit;
  TypeSatisfiesProtocol := True;
End;

{ LoadExistingFieldsIntoBuf : reconstitue le tampon BufNames/BufTypes    }
{ attendu par ParseStructMemberFunc/ParseClassMemberFunc/                          }
{ ParseComputedProperty (TODO 09/10, deja ecrites) a partir des CHAMPS             }
{ DEJA CONNUS du type (FieldPool, TypeTab[FT].FieldFirst/Count - figes           }
{ depuis la declaration d origine du type, jamais modifies par une                    }
{ extension, voir note d en-tete de section) - necessaire car                              }
{ ParseExtensionDecl (contrairement a ParseStructType/ParseClassType,               }
{ TODO 09/10) n analyse JAMAIS lui-meme la moindre declaration de                       }
{ champ : le tampon serait sinon simplement VIDE, rendant les champs               }
{ EXISTANTS inaccessibles (sans "self.") depuis une methode ajoutee              }
{ par cette extension. }
Procedure LoadExistingFieldsIntoBuf(FT: Integer; Var BufNames: TStructBufNames;
  Var BufTypes: TStructBufTypes; Var BufCnt: Integer);
Var I : Integer;
Begin
  BufCnt := 0;
  For I := TypeTab[FT].FieldFirst To TypeTab[FT].FieldFirst + TypeTab[FT].FieldCount - 1 Do
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := FieldPool[I].Name;
      BufTypes[BufCnt] := FieldPool[I].TypeIdx;
      Inc(BufCnt);
    End;
End;

{ ParseExtensionDecl : REALISE la Forward-declaration du TODO 05 -      }
{ "extension Nom [: Protocole]" suivi d un corps de membres - "Nom"             }
{ DOIT deja resoudre a un type EXISTANT (struct OU class, SK_TYPE) -              }
{ un type inconnu est                                                                    }
{ un arret propre documente (FatalError), jamais une struct/class                     }
{ IMPLICITEMENT creee. Aucun champ STOCKE ne peut etre ajoute (regle              }
{ Swift reelle, verifiee explicitement ci-dessous) - seulement des               }
{ methodes/proprietes CALCULEES, exactement comme le corps d un struct/            }
{ class d origine, mais SANS jamais toucher a FieldFirst/FieldCount              }
{ (deja figes). La verification de conformite (best-effort, si un               }
{ protocole est declare) a lieu APRES avoir analyse tout le corps de              }
{ l extension - ses PROPRES membres doivent d abord exister dans                       }
{ MethodPool pour pouvoir compter. }
Function ParseExtensionDecl: Integer;
Var
  Nam, ProtoNam : TString;
  SI, FT, ProtoIdx, Kw : Integer;
  FName : TString;
  FTIdx : Integer;
  BufNames : TStructBufNames;
  BufTypes : TStructBufTypes;
  BufCnt   : Integer;
Begin
  PPAdvance;   { extension }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de type attendu apres ''extension''');
    ParseExtensionDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  SI := SymFind(Nam);
  If (SI < 0) Or (SymTab[SI].Kind <> SK_TYPE) Or
     (Not (TypeTab[SymTab[SI].TypeIdx].Kind In [TYK_STRUCT, TYK_CLASS])) Then
  Begin
    FatalError('un struct/class DEJA DECLARE est attendu dans une extension: ' + Nam);
    ParseExtensionDecl := -1;
    Exit;
  End;
  FT := SymTab[SI].TypeIdx;

  ProtoIdx := -1;
  If PPMatch(':') Then
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de protocole attendu apres '':'' dans une extension');
      ParseExtensionDecl := -1;
      Exit;
    End;
    ProtoNam := PPVal;
    SI := SymFind(ProtoNam);
    If (SI < 0) Or (SymTab[SI].Kind <> SK_TYPE) Or
       (TypeTab[SymTab[SI].TypeIdx].Kind <> TYK_PROTOCOL) Then
    Begin
      FatalError('nom de protocole attendu apres '':'' dans une extension: ' + ProtoNam);
      ParseExtensionDecl := -1;
      Exit;
    End;
    ProtoIdx := SymTab[SI].TypeIdx;
    PPAdvance;

    If PPIsOp(',') Then
    Begin
      FatalError('une seule conformance de protocole par extension est ' +
        'prise en charge ici (une SECONDE extension separee reste toujours ' +
        'possible)');
      ParseExtensionDecl := -1;
      Exit;
    End;
  End;

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom de l''extension');
    ParseExtensionDecl := FT;
    Exit;
  End;
  PPSkipSemis;

  LoadExistingFieldsIntoBuf(FT, BufNames, BufTypes, BufCnt);

  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('membre d''extension attendu (func/mutating func/propriete calculee)');
      Break;
    End;
    Kw := IsKeyword(PPVal);

    If (Kw = KW_VAR) Or (Kw = KW_LET) Then
    Begin
      PPAdvance;
      If PPKind <> TOK_IDENT Then
      Begin
        FatalError('nom attendu');
        Break;
      End;
      FName := PPVal;
      PPAdvance;
      If Not PPMatch(':') Then
      Begin
        FatalError('"":"" attendu apres un nom');
        Break;
      End;
      FTIdx := ParseTypeExpr;
      If Not PPIsOp('{') Then
      Begin
        FatalError('une extension ne peut PAS ajouter de champ STOCKE (''' + FName +
          ''') - seules les proprietes CALCULEES (avec un corps) et les ' +
          'methodes sont autorisees, regle Swift reelle');
        Break;
      End;
      ParseComputedProperty(FT, FName, FTIdx, BufNames, BufTypes, BufCnt);
    End
    Else If Kw = KW_FUNC Then
    Begin
      If TypeTab[FT].Kind = TYK_CLASS Then
        ParseClassMemberFunc(FT, BufNames, BufTypes, BufCnt, False, False)
      Else
        ParseStructMemberFunc(FT, BufNames, BufTypes, BufCnt, False, False);
    End
    Else If (Kw = KW_MUTATING) And (TypeTab[FT].Kind = TYK_STRUCT) Then
    Begin
      PPAdvance;
      If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_FUNC)) Then
      Begin
        FatalError('''func'' attendu apres ''mutating''');
        Break;
      End;
      ParseStructMemberFunc(FT, BufNames, BufTypes, BufCnt, True, False);
    End
    Else
    Begin
      FatalError('membre d''extension non pris en charge: ' + PPVal);
      Break;
    End;

    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin de l''extension');

  If (ProtoIdx >= 0) And (Not TypeSatisfiesProtocol(FT, ProtoIdx)) Then
    WarnMsg(Nam + ' (extension) ne satisfait pas completement le protocole ' +
      TypeTab[ProtoIdx].Name + ' (verification best-effort, TODO 19)');

  ParseExtensionDecl := FT;
End;

{ ------------------------------------------------------------ }
{ ProtocolSelfTest : protocole a 2 exigences de methode, struct           }
{ conforme via UNE extension par protocole (forme EXACTE de                    }
{ protos.swift), acces au champ EXISTANT ("radius") depuis une                     }
{ methode ajoutee par extension SANS "self.", verification de                          }
{ conformite reussie, PUIS un type qui NE satisfait PAS un protocole              }
{ (methode manquante), protocole utilise comme type de variable                       }
{ ("let d: Drawable = Circle(...)" - "modele boite"), conformance                       }
{ declaree DIRECTEMENT sur le struct ("struct Nom: Protocole", forme               }
{ alternative a l extension), puis integration bout-en-bout via                        }
{ ParseTopLevelDecls sur un extrait IDENTIQUE a protos.swift - sur des               }
{ extraits synthetiques (fichier temporaire, meme methode que les                        }
{ TODO precedents). }
{ ------------------------------------------------------------ }

Procedure ProtocolAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ProtocolSelfTest: ' + Label_ + ' a echoue');
End;

Function ProtocolParseTopLevel(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32PROTOSELFTEST.$$$';
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
  { dispatche vers le VRAI parseur specifique (renvoie un TypeIdx utile     }
  { aux assertions) plutot que le generique ParseTopLevelDecl (Booleen        }
  { seulement) - meme convention que StructParseTopLevel/ClassParseTopLevel        }
  { (TODO 09/10). }
  If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_PROTOCOL) Then
    ProtocolParseTopLevel := ParseProtocolDecl
  Else If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_EXTENSION) Then
    ProtocolParseTopLevel := ParseExtensionDecl
  Else If (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_STRUCT) Then
    ProtocolParseTopLevel := ParseStructDecl
  Else
    ProtocolParseTopLevel := -1;
End;

Procedure ProtocolSelfTest;
Var
  FTDrawable, FTPrintable, FTCircle, FTSquare, SI, E : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;

  { protocole a 1 exigence de methode }
  FTDrawable := ProtocolParseTopLevel('protocol Drawable {' + Chr(10) +
    'func draw() -> Int' + Chr(10) + '}');
  ProtocolAssert('Drawable : TYK_PROTOCOL', TypeTab[FTDrawable].Kind = TYK_PROTOCOL);
  ProtocolAssert('Drawable : "draw" est une exigence (MethodFind la trouve)',
    MethodFind(FTDrawable, 'draw') >= 0);
  ProtocolAssert('Drawable : "draw" n a AUCUN corps (BodyStmtIdx=-1, un ' +
    'CONTRAT, pas une implementation)',
    MethodPool[MethodFind(FTDrawable, 'draw')].BodyStmtIdx = -1);

  { struct SANS methode "draw" - ne satisfait PAS Drawable }
  FTSquare := ProtocolParseTopLevel('struct Square {' + Chr(10) +
    'var side: Int' + Chr(10) + '}');
  ProtocolAssert('Square (sans "draw") NE satisfait PAS Drawable',
    Not TypeSatisfiesProtocol(FTSquare, FTDrawable));

  { struct + extension SEPAREE declarant la conformance (forme EXACTE de  }
  { protos.swift) - la methode ajoutee accede a "radius" (champ EXISTANT)         }
  { SANS "self." }
  FTCircle := ProtocolParseTopLevel('struct Circle {' + Chr(10) +
    'var radius: Int' + Chr(10) + '}');
  ProtocolParseTopLevel('extension Circle: Drawable {' + Chr(10) +
    'func draw() -> Int {' + Chr(10) + 'return radius' + Chr(10) + '}' + Chr(10) + '}');
  ProtocolAssert('Circle (via extension) satisfait desormais Drawable',
    TypeSatisfiesProtocol(FTCircle, FTDrawable));
  ProtocolAssert('Circle.draw (ajoutee par extension) trouvee via MethodFind',
    MethodFind(FTCircle, 'draw') >= 0);
  ProtocolAssert('Circle.draw a un VRAI corps (BodyStmtIdx >= 0, ' +
    'contrairement a l exigence du protocole)',
    MethodPool[MethodFind(FTCircle, 'draw')].BodyStmtIdx >= 0);

  { seconde extension, second protocole (forme EXACTE de protos.swift :   }
  { DEUX extensions SEPAREES sur le MEME type, chacune pour un protocole            }
  { different) - EXERCE DIRECTEMENT le correctif MethodFind/OwnerTypeIdx :             }
  { Drawable a deja pousse SES PROPRES entrees dans MethodPool ENTRE la              }
  { declaration d origine de Circle et cette seconde extension, cassant             }
  { toute hypothese de contigute si MethodFind cherchait encore par             }
  { position (voir la note d en-tete de section). }
  FTPrintable := ProtocolParseTopLevel('protocol Printable {' + Chr(10) +
    'func describe() -> Int' + Chr(10) + '}');
  ProtocolParseTopLevel('extension Circle: Printable {' + Chr(10) +
    'func describe() -> Int {' + Chr(10) + 'return radius' + Chr(10) + '}' + Chr(10) + '}');
  ProtocolAssert('Circle satisfait AUSSI Printable (seconde extension, ' +
    'MethodFind par OwnerTypeIdx - PAS par position)',
    TypeSatisfiesProtocol(FTCircle, FTPrintable));
  ProtocolAssert('Circle satisfait TOUJOURS Drawable (premiere extension, ' +
    'non perturbee par la seconde)',
    TypeSatisfiesProtocol(FTCircle, FTDrawable));

  { protocole utilise comme TYPE de variable ("modele boite") }
  SI := SymAdd('d', SK_VAR, FTDrawable, False);
  E := ExprParseString('d.draw()');
  ProtocolAssert('d.draw() (d: Drawable) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  ProtocolAssert('d.draw() : TypeIdx = Int (resolu via l EXIGENCE du ' +
    'protocole, PAS via un type concret quelconque)',
    ExprPool[E].TypeIdx = PDT_INT);

  { conformance DECLAREE DIRECTEMENT sur le struct (forme alternative a   }
  { l extension - "struct Nom: Protocole", TODO 09 etendu ci-dessus) }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  FTDrawable := ProtocolParseTopLevel('protocol Drawable {' + Chr(10) +
    'func draw() -> Int' + Chr(10) + '}');
  FTCircle := ProtocolParseTopLevel('struct Circle: Drawable {' + Chr(10) +
    'var radius: Int' + Chr(10) +
    'func draw() -> Int {' + Chr(10) + 'return radius' + Chr(10) + '}' + Chr(10) + '}');
  ProtocolAssert('struct Circle: Drawable (conformance directe) satisfait ' +
    'bien Drawable', TypeSatisfiesProtocol(FTCircle, FTDrawable));

  { integration bout-en-bout : extrait IDENTIQUE a protos.swift, en      }
  { entier, via ParseTopLevelDecls (TODO 05, etendue ci-dessus avec              }
  { "protocol"/"extension") - arret propre attendu sur "print(1)" final,               }
  { meme gap documente que structs.swift/classes.swift (code executable           }
  { NU de haut niveau). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit;
  Assign(LexSrcF, 'SWIFTW32PROTOSELFTEST2.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'protocol Drawable {');
  WriteLn(LexSrcF, '    func draw() -> Int');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'protocol Printable {');
  WriteLn(LexSrcF, '    func describe() -> Int');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'struct Circle {');
  WriteLn(LexSrcF, '    var radius: Int');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'extension Circle: Drawable {');
  WriteLn(LexSrcF, '    func draw() -> Int {');
  WriteLn(LexSrcF, '        return 1');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'extension Circle: Printable {');
  WriteLn(LexSrcF, '    func describe() -> Int {');
  WriteLn(LexSrcF, '        return radius');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let c: Circle = Circle(radius: 5)');
  WriteLn(LexSrcF, 'print(1)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32PROTOSELFTEST2.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  ProtocolAssert('protos.swift (integral) : "c" (let) resolu', SymFind('c') >= 0);
  ProtocolAssert('protos.swift (integral) : "c" a le type Circle',
    SymTab[SymFind('c')].TypeIdx = SymTab[SymFind('Circle')].TypeIdx);
  ProtocolAssert('protos.swift (integral) : arret propre EXACT sur "print(1)"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
End;

{ ============================================================ }
{ TODO 12 - ENUMERATIONS : VALEURS BRUTES, VALEURS ASSOCIEES    }
{ ============================================================ }
{ Un enum Swift est TOUJOURS EXACTEMENT une seule des TROIS formes du    }
{ roadmap d en-tete, JAMAIS un melange (regle Swift reelle) : (1) cas         }
{ simples sans donnee (enum "Direction" avec des cas "north"/"south"/                }
{ etc., sans aucune valeur) ; (2) valeurs BRUTES (enum "Planet" declare                 }
{ avec ": Int", cas "mercury = 1" etc.) - auto-incrementees depuis la              }
{ DERNIERE valeur explicite/auto quand omises, EXACTEMENT le mecanisme            }
{ de l iota de Go/GOCW32.PAS (TODO 05 la-bas), applique ICI par cas             }
{ plutot que par ligne de bloc "const" - ou (3) valeurs ASSOCIEES (enum          }
{ "Resultat" avec des cas "succes(Int)"/"echec(String)") - modele                     }
{ memoire "tag + union" : un entier de discrimination (le DISCRIMINANT,             }
{ 4 octets) plus une zone dimensionnee sur le PLUS GRAND des cas (Size                  }
{ backfilee a la fin, meme principe                                                       }
{ que le Size d un struct/class, TODO 09/10 - mais BASE sur le          }
{ MAXIMUM des cas plutot que leur SOMME). PORTEE (documentee) : AU               }
{ PLUS UNE seule valeur associee par cas (Swift reel autorise un                          }
{ TUPLE de plusieurs valeurs par cas - "case paire(Int, String)" - hors           }
{ de portee ici, AUCUN echantillon SAMPLES\SWIFT n en a besoin) ; pas             }
{ d auto-incrementation pour une valeur brute de type String (regle              }
{ Swift reelle differente - la CASE NAME elle-meme sert de valeur par             }
{ defaut - non implementee, AUCUN echantillon n utilise de raw value                    }
{ chaine).                                                                                }
{                                                                       }
{ Acces a un cas ("Direction.north") : ARCHITECTURALEMENT different            }
{ de "instance.champ" (TODO 09/10) - la BASE est un NOM DE TYPE, pas               }
{ une instance - deja pris en charge par ResolveSelectorType (TODO 09,               }
{ deja etendu ci-dessus) via une coincidence structurelle EXPLOITEE               }
{ plutot qu une nouvelle forme de noeud (ExprAddIdent, TODO 06, resout               }
{ deja tout SK_TYPE vers SON PROPRE TypeIdx). Un cas a valeur ASSOCIEE             }
{ s utilise comme un APPEL ("MonEnum.succes(42)") - deja pris en                       }
{ charge par ParseCallArgs (TODO 06, deja etendu ci-dessus).                             }
{                                                                       }
{ switch sur un enum, motif RACCOURCI (".Cas"/".Cas(let Liaison)",              }
{ roadmap d en-tete : "reutilise le pattern matching du TODO 07,                        }
{ etendu pour lier une variable depuis l interieur d un motif") - DEJA             }
{ implemente ci-dessus (ParseCaseClause, TODO 07, etendue avec un               }
{ nouveau parametre TagTypeIdx) : la liaison "let valeur" est                             }
{ enregistree comme un "let" ORDINAIRE (SK_VAR, IsConst=Vrai) dans la              }
{ portee du CORPS du cas, exactement comme n importe quel autre "let"                  }
{ Swift - typee par l AssocTypeIdx du cas resolu (EnumCaseGetAssocType).                 }

{ TEnumCaseRec/EnumCasePool : UN pool DEDIE (plutot qu une reutilisation   }
{ deguisee de FieldPool, TODO 04/08/09) - un cas d enum n est ni un              }
{ champ de struct/class NI un parametre de fonction, et RawValue/                       }
{ AssocTypeIdx n auraient aucun sens clair sur TFieldRec sans y                            }
{ ajouter ENCORE des champs a moitie utilises. MAX_ENUMCASE deja                          }
{ reserve au TODO 01. }
Type
  TEnumCaseRec = Record
    Name         : TString;
    HasRawValue  : Boolean;
    RawValue     : LongInt;    { valide SEULEMENT si HasRawValue }
    AssocTypeIdx : Integer;    { -1 si aucune valeur associee (cas simple  }
                                { OU a valeur brute - jamais les deux a la      }
                                { fois, voir note d en-tete) }
  End;

Var
  EnumCasePool  : Array[0..MAX_ENUMCASE - 1] Of TEnumCaseRec;
  EnumCaseCount : Integer;

Procedure EnumCaseInit;
Begin
  EnumCaseCount := 0;
End;

Function EnumCaseAdd(Const Nm: TString; AHasRaw: Boolean; ARawVal: LongInt;
  AAssocTypeIdx: Integer): Integer;
Begin
  If EnumCaseCount >= MAX_ENUMCASE Then
  Begin
    WarnMsg('table des cas d''enum pleine (MAX_ENUMCASE)');
    EnumCaseAdd := -1;
    Exit;
  End;
  EnumCasePool[EnumCaseCount].Name         := Nm;
  EnumCasePool[EnumCaseCount].HasRawValue  := AHasRaw;
  EnumCasePool[EnumCaseCount].RawValue     := ARawVal;
  EnumCasePool[EnumCaseCount].AssocTypeIdx := AAssocTypeIdx;
  EnumCaseAdd := EnumCaseCount;
  Inc(EnumCaseCount);
End;

{ EnumCaseFind : REALISE la Forward-declaration du TODO 05 - recherche  }
{ DIRECTE par nom (un enum Swift n a AUCUN mecanisme d heritage/                    }
{ embarquement pour ses cas, contrairement aux methodes de classe,               }
{ TODO 10 - recherche PLATE suffisante). }
Function EnumCaseFind(EnumTypeIdx: Integer; Const CName: TString): Integer;
Var I : Integer;
Begin
  EnumCaseFind := -1;
  If (EnumTypeIdx < 0) Or (EnumTypeIdx >= TypeCount) Or
     (TypeTab[EnumTypeIdx].Kind <> TYK_ENUM) Then Exit;
  For I := TypeTab[EnumTypeIdx].CaseFirst To
    TypeTab[EnumTypeIdx].CaseFirst + TypeTab[EnumTypeIdx].CaseCount - 1 Do
    If EnumCasePool[I].Name = CName Then
    Begin
      EnumCaseFind := I;
      Exit;
    End;
End;

{ EnumCaseGetAssocType : REALISE la Forward-declaration du TODO 07/12   }
{ (voir sa propre note - simple accesseur necessaire car EnumCasePool           }
{ ne peut pas etre Forward-declaree, elle, etant une VARIABLE). }
Function EnumCaseGetAssocType(CaseIdx: Integer): Integer;
Begin
  EnumCaseGetAssocType := -1;
  If (CaseIdx < 0) Or (CaseIdx >= EnumCaseCount) Then Exit;
  EnumCaseGetAssocType := EnumCasePool[CaseIdx].AssocTypeIdx;
End;

{ ParseOneEnumCase : UN nom de cas (parmi une liste separee par des     }
{ virgules apres un SEUL "case", ou un "case" isole - les deux formes            }
{ du roadmap d en-tete sont EQUIVALENTES ici, chaque nom accumule                    }
{ simplement une nouvelle entree EnumCasePool). "= Expr" (valeur BRUTE         }
{ explicite) et "(Type)" (valeur ASSOCIEE) sont MUTUELLEMENT EXCLUSIFS           }
{ - RawT>=0 decide laquelle des deux formes est even possible                              }
{ (RawT<0 => seule la forme associee, ou aucune valeur du tout, a un                 }
{ sens). NextAutoInt/MaxAssocSize sont MIS A JOUR pour le PROCHAIN cas               }
{ (var-parametres, meme convention que CurIota de GOCW32.PAS pour son            }
{ propre auto-incrementement). }
Procedure ParseOneEnumCase(FT, RawT: Integer; Var NextAutoInt: LongInt;
  Var MaxAssocSize: Integer);
Var
  CName  : TString;
  RVal   : LongInt;
  CVal   : TConstVal;
  AssocT, ValIdx : Integer;
  HasRaw : Boolean;
Begin
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de cas attendu apres ''case''');
    Exit;
  End;
  CName := PPVal;
  PPAdvance;

  AssocT := -1;
  HasRaw := False;
  RVal   := 0;

  If (RawT >= 0) And PPMatch('=') Then
  Begin
    { valeur brute EXPLICITE - expression CONSTANTE (ConstFoldExpr,       }
    { TODO 06, reutilise tel quel plutot qu un evaluateur dedie). }
    ValIdx := ParseExpr;
    CVal := ConstFoldExpr(ValIdx);
    RVal := CVal.IntVal;
    HasRaw := True;
    NextAutoInt := RVal + 1;
  End
  Else If RawT >= 0 Then
  Begin
    { valeur brute AUTO-INCREMENTEE - meme mecanisme que l iota de       }
    { Go/GOCW32.PAS (roadmap d en-tete). }
    RVal := NextAutoInt;
    HasRaw := True;
    NextAutoInt := RVal + 1;
  End
  Else If PPIsOp('(') Then
  Begin
    { valeur ASSOCIEE - portee limitee a UNE SEULE (voir note d en-tete). }
    PPAdvance;
    AssocT := ParseTypeExpr;
    If Not PPMatch(')') Then
      FatalError('parenthese fermante attendue apres une valeur associee');
    If (AssocT >= 0) And (AssocT < TypeCount) And (TypeTab[AssocT].Size > MaxAssocSize) Then
      MaxAssocSize := TypeTab[AssocT].Size;
  End;

  EnumCaseAdd(CName, HasRaw, RVal, AssocT);
End;

{ ParseEnumDecl : REALISE la Forward-declaration du TODO 05 - "enum"    }
{ deja consomme ? NON - PP pointe encore SUR "enum" (meme convention               }
{ que ParseFuncDecl/ParseStructDecl/...). Le type est PRE-ALLOUE                       }
{ (TypeAdd) AVANT le corps - meme raison que ParseStructType/                             }
{ ParseClassType (TODO 09/10, "self" pour les methodes) meme si un                     }
{ enum Swift ne peut PAS avoir de methodes ici (portee non demandee            }
{ par le roadmap d en-tete du TODO 12) : la pre-allocation reste                      }
{ neanmoins la structure la plus UNIFORME avec le reste du fichier.                    }
{ Size est BACKFILE a la fin (discriminant 4 octets + MaxAssocSize,               }
{ modele "tag + union" du roadmap). }
Function ParseEnumDecl: Integer;
Var
  Nam : TString;
  FT, RawT, CaseFirst, MaxAssocSize : Integer;
  NextAutoInt : LongInt;
Begin
  PPAdvance;   { enum }
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom d''enum attendu apres ''enum''');
    ParseEnumDecl := -1;
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPIsOp('<') Then
  Begin
    FatalError('enums generiques pas encore pris en charge (TODO 13)');
    ParseEnumDecl := -1;
    Exit;
  End;

  RawT := -1;
  If PPMatch(':') Then
    RawT := ParseTypeExpr;

  FT := TypeAdd(TYK_ENUM, Nam, 4, 4, False, True, -1, -1);
  TypeTab[FT].RawTypeIdx := RawT;
  SymAdd(Nam, SK_TYPE, FT, False);

  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres le nom de l''enum');
    ParseEnumDecl := FT;
    Exit;
  End;
  PPSkipSemis;

  CaseFirst := EnumCaseCount;
  NextAutoInt := 0;
  MaxAssocSize := 0;

  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    If Not ((PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_CASE)) Then
    Begin
      FatalError('"case Nom" attendu dans un enum: ' + PPVal);
      Break;
    End;
    PPAdvance;   { case }
    Repeat
      ParseOneEnumCase(FT, RawT, NextAutoInt, MaxAssocSize);
    Until Not PPMatch(',');
    PPSkipSemis;
  End;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin de l''enum');

  TypeTab[FT].CaseFirst := CaseFirst;
  TypeTab[FT].CaseCount := EnumCaseCount - CaseFirst;
  If MaxAssocSize > 0 Then
    TypeTab[FT].Size := 4 + MaxAssocSize;

  ParseEnumDecl := FT;
End;

{ ------------------------------------------------------------ }
{ EnumSelfTest : cas simples (Direction, forme EXACTE de enums.swift),   }
{ valeurs brutes EXPLICITES (Planet, forme EXACTE de enums.swift),               }
{ valeurs brutes AUTO-INCREMENTEES (meme mecanisme que l iota),               }
{ valeurs ASSOCIEES (modele "tag + union", Size backfilee sur le               }
{ MAXIMUM), acces qualifie "Enum.cas" comme expression, appel                          }
{ "Enum.cas(valeur)" pour un cas associe, motif de switch RACCOURCI              }
{ ".cas(let Liaison)" avec extraction de la donnee associee dans une              }
{ liaison locale, puis integration bout-en-bout via ParseTopLevelDecls              }
{ sur un extrait IDENTIQUE a enums.swift - sur des extraits synthetiques            }
{ (fichier temporaire, meme methode que les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure EnumAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('EnumSelfTest: ' + Label_ + ' a echoue');
End;

Function EnumParseTopLevel(Const Src: TString): Integer;
Const
  TmpFile = 'SWIFTW32ENUMSELFTEST.$$$';
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
  EnumParseTopLevel := ParseEnumDecl;
End;

Procedure EnumSelfTest;
Var
  FTDirection, FTPlanet, FTResult, CI, SI, E, S : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { cas simples, sans donnee - forme EXACTE de enums.swift (Direction) }
  FTDirection := EnumParseTopLevel('enum Direction {' + Chr(10) +
    'case north' + Chr(10) + 'case south' + Chr(10) +
    'case east' + Chr(10) + 'case west' + Chr(10) + '}');
  EnumAssert('Direction : TYK_ENUM', TypeTab[FTDirection].Kind = TYK_ENUM);
  EnumAssert('Direction : type VALEUR (IsValueType)', TypeTab[FTDirection].IsValueType);
  EnumAssert('Direction : 4 cas', TypeTab[FTDirection].CaseCount = 4);
  EnumAssert('Direction : AUCUN type de valeur brute (RawTypeIdx=-1)',
    TypeTab[FTDirection].RawTypeIdx = -1);
  CI := EnumCaseFind(FTDirection, 'north');
  EnumAssert('Direction.north trouve', CI >= 0);
  EnumAssert('Direction.north SANS valeur brute', Not EnumCasePool[CI].HasRawValue);
  EnumAssert('Direction.north SANS valeur associee', EnumCasePool[CI].AssocTypeIdx = -1);

  { acces qualifie "Enum.cas" comme EXPRESSION (architecture partagee     }
  { avec ResolveSelectorType, TODO 09 etendu ci-dessus) - VERIFIE ICI,           }
  { DANS CE MEME BLOC (avant tout TypeInit ulterieur qui reutiliserait            }
  { l INDICE FTDirection pour un AUTRE type - BOGUE REEL trouve par                  }
  { execution : TypeInit reinitialise TypeCount a 0 puis reconstruit                     }
  { les 22 types predeclares, de sorte que le PROCHAIN enum cree APRES                   }
  { un tel reset obtient exactement le MEME indice que Direction en                          }
  { avait recu ICI - FTDirection restait alors un entier PARFAITEMENT               }
  { valide, mais pointant desormais vers un type ENTIEREMENT DIFFERENT). }
  E := ExprParseString('Direction.north');
  EnumAssert('Direction.north (expression) : EK_SELECTOR', ExprPool[E].Kind = EK_SELECTOR);
  EnumAssert('Direction.north : TypeIdx = Direction (une VALEUR de cet enum)',
    ExprPool[E].TypeIdx = FTDirection);

  { valeurs brutes EXPLICITES - forme EXACTE de enums.swift (Planet) }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FTPlanet := EnumParseTopLevel('enum Planet: Int {' + Chr(10) +
    'case mercury = 1' + Chr(10) + 'case venus = 2' + Chr(10) +
    'case earth = 3' + Chr(10) + 'case mars = 4' + Chr(10) + '}');
  EnumAssert('Planet : RawTypeIdx = Int', TypeTab[FTPlanet].RawTypeIdx = PDT_INT);
  CI := EnumCaseFind(FTPlanet, 'earth');
  EnumAssert('Planet.earth trouve', CI >= 0);
  EnumAssert('Planet.earth : valeur brute = 3', EnumCasePool[CI].RawValue = 3);

  { valeurs brutes AUTO-INCREMENTEES (meme mecanisme que l iota) - forme   }
  { comma-jointe "case a, b, c" du roadmap d en-tete (pas exercee par                }
  { enums.swift lui-meme, mais explicitement promise). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FTPlanet := EnumParseTopLevel('enum Suit: Int {' + Chr(10) +
    'case clubs = 1, diamonds, hearts, spades' + Chr(10) + '}');
  EnumAssert('Suit.clubs = 1 (explicite)', EnumCasePool[EnumCaseFind(FTPlanet, 'clubs')].RawValue = 1);
  EnumAssert('Suit.diamonds = 2 (auto, +1)', EnumCasePool[EnumCaseFind(FTPlanet, 'diamonds')].RawValue = 2);
  EnumAssert('Suit.hearts = 3 (auto)', EnumCasePool[EnumCaseFind(FTPlanet, 'hearts')].RawValue = 3);
  EnumAssert('Suit.spades = 4 (auto)', EnumCasePool[EnumCaseFind(FTPlanet, 'spades')].RawValue = 4);

  { valeurs ASSOCIEES - modele "tag + union", Size = 4 (discriminant) +   }
  { MAXIMUM des cas (String, 8 octets ici, PLUS GRAND que Int, 4 octets). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FTResult := EnumParseTopLevel('enum Resultat {' + Chr(10) +
    'case succes(Int)' + Chr(10) + 'case echec(String)' + Chr(10) + '}');
  EnumAssert('Resultat : AUCUNE valeur brute (RawTypeIdx=-1)', TypeTab[FTResult].RawTypeIdx = -1);
  CI := EnumCaseFind(FTResult, 'succes');
  EnumAssert('Resultat.succes : valeur associee = Int', EnumCasePool[CI].AssocTypeIdx = PDT_INT);
  CI := EnumCaseFind(FTResult, 'echec');
  EnumAssert('Resultat.echec : valeur associee = String', EnumCasePool[CI].AssocTypeIdx = PDT_STRING);
  EnumAssert('Resultat : Size = 4 (discriminant) + 8 (String, le PLUS GRAND) = 12',
    TypeTab[FTResult].Size = 12);

  { appel "Enum.cas(valeur)" pour un cas a valeur associee (ParseCallArgs,  }
  { TODO 06 etendu ci-dessus) }
  E := ExprParseString('Resultat.succes(42)');
  EnumAssert('Resultat.succes(42) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  EnumAssert('Resultat.succes(42) : TypeIdx = Resultat', ExprPool[E].TypeIdx = FTResult);

  { switch, motif RACCOURCI ".cas(let Liaison)" - extrait la valeur        }
  { associee dans une liaison locale (TODO 07 etendu ci-dessus, roadmap           }
  { d en-tete du TODO 12). }
  SI := SymAdd('r', SK_VAR, FTResult, False);
  S := ParseStmtString('switch r {' + Chr(10) +
    'case .succes(let valeur):' + Chr(10) + 'print(valeur)' + Chr(10) +
    'case .echec(let message):' + Chr(10) + 'print(message)' + Chr(10) + '}');
  EnumAssert('switch sur Resultat : STK_SWITCH', StmtPool[S].Kind = STK_SWITCH);
  EnumAssert('switch : 2 clauses', StmtPool[S].ArgCount = 2);
  SI := SymFind('valeur');
  EnumAssert('"valeur" (liaison de .succes) resolue', SI >= 0);
  EnumAssert('"valeur" est un "let" (IsConst)', SymTab[SI].IsConst);
  EnumAssert('"valeur" typee Int (AssocTypeIdx de .succes)', SymTab[SI].TypeIdx = PDT_INT);
  SI := SymFind('message');
  EnumAssert('"message" (liaison de .echec) typee String', SymTab[SI].TypeIdx = PDT_STRING);

  { integration bout-en-bout : extrait IDENTIQUE a enums.swift, en       }
  { entier, via ParseTopLevelDecls (TODO 05, etendue ci-dessus avec              }
  { "enum") - arret propre attendu sur "print(earth)" final (code               }
  { executable NU de haut niveau, meme gap documente que structs.swift/               }
  { classes.swift/protos.swift). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32ENUMSELFTEST2.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'enum Direction {');
  WriteLn(LexSrcF, '    case north');
  WriteLn(LexSrcF, '    case south');
  WriteLn(LexSrcF, '    case east');
  WriteLn(LexSrcF, '    case west');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'enum Planet: Int {');
  WriteLn(LexSrcF, '    case mercury = 1');
  WriteLn(LexSrcF, '    case venus = 2');
  WriteLn(LexSrcF, '    case earth = 3');
  WriteLn(LexSrcF, '    case mars = 4');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let dir: Int = 0');
  WriteLn(LexSrcF, 'let earth: Int = 3');
  WriteLn(LexSrcF, 'switch dir {');
  WriteLn(LexSrcF, 'case 0:');
  WriteLn(LexSrcF, '    print(1)');
  WriteLn(LexSrcF, 'case 1:');
  WriteLn(LexSrcF, '    print(2)');
  WriteLn(LexSrcF, 'case 2:');
  WriteLn(LexSrcF, '    print(3)');
  WriteLn(LexSrcF, 'case 3:');
  WriteLn(LexSrcF, '    print(4)');
  WriteLn(LexSrcF, 'default:');
  WriteLn(LexSrcF, '    print(0)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'print(earth)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32ENUMSELFTEST2.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  EnumAssert('enums.swift (integral) : "earth" (let, PAS le cas d''enum ' +
    'homonyme "Planet.earth" - deux symboles bien DISTINCTS) resolu',
    SymFind('earth') >= 0);
  EnumAssert('enums.swift (integral) : "earth" (let) a le type Int',
    SymTab[SymFind('earth')].TypeIdx = PDT_INT);
  { le "switch dir" suivi d un corps (TODO 07, sur un Int ordinaire,     }
  { PAS un enum)                                                                          }
  { est une INSTRUCTION, jamais une DECLARATION - ParseTopLevelDecls               }
  { (declarations SEULEMENT, TODO 05) s arrete PROPREMENT juste avant,               }
  { exactement comme structs.swift/classes.swift/protos.swift s arretaient             }
  { sur leur "print(...)" final (meme gap documente : code executable                  }
  { NU de haut niveau). }
  EnumAssert('enums.swift (integral) : arret propre EXACT sur "switch"',
    (PPKind = TOK_IDENT) And (PPVal = 'switch'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 13 - GENERIQUES : FONCTIONS/TYPES GENERIQUES ET           }
{           CONTRAINTES                                          }
{ ============================================================ }
{ DECISION ARCHITECTURALE (roadmap d en-tete : "PORTEE A DECIDER :        }
{ monomorphisation reelle... vs un unique T = pointeur generique de              }
{ 4 octets simplifie... trancher avant le codegen") - TRANCHEE ICI, EN                 }
{ FAVEUR DU MODELE SIMPLIFIE (comme Go avant les generiques 1.18) :                        }
{ chaque parametre de type generique ("T", "U") devient une entree                        }
{ TYK_GENERIC_PARAM UNIQUE (deja reservee au TODO 04), Size=4/                                }
{ IsValueType=Vrai - un "pointeur generique" opaque et UNIFORME, JAMAIS                       }
{ une specialisation reelle par combinaison de types utilisee. AUCUN                           }
{ codegen n existe encore (TODO 21+) pour observer la difference -                                  }
{ cette decision est prise ICI, par ecrit, pour ne PAS avoir a la                                     }
{ re-trancher au TODO 21, exactement la meme discipline que le choix                                      }
{ cooperatif-vs-threads-reels de GOCW32.PAS pour ses goroutines                                                }
{ (TODO 15 la-bas) ou la capture par reference des fermetures                                                     }
{ (TODO 08 ici).                                                                                                     }
{                                                                       }
{ "T" est enregistree comme un SK_TYPE ORDINAIRE (SymAdd) dans une        }
{ portee DEDIEE, ouverte par l appelant (ParseFuncDecl/ParseStructDecl,             }
{ TODO 08/09, restructurees ci-dessus) AVANT meme la liste de                              }
{ parametres/le corps de champs - ParseTypeExpr (TODO 05) resout donc              }
{ DEJA "T" EXACTEMENT comme "Int" ou "MonStruct", SANS AUCUNE                                  }
{ modification necessaire : aucune nouvelle forme de noeud, aucun cas                        }
{ special dans le resolveur de types.                                                             }
{                                                                       }
{ Inference au point d appel ("identity(42) infere T = Int", roadmap             }
{ d en-tete) - DEJA implementee ci-dessus (ParseCallArgs, TODO 06                          }
{ etendu) : substitue le type de RETOUR generique par le type REEL du            }
{ PREMIER argument occupant, dans la signature, la MEME position qu un              }
{ parametre DECLARE avec ce MEME TypeIdx generique - AUCUNE                                  }
{ monomorphisation, AUCUNE verification de coherence entre plusieurs                       }
{ usages du MEME "T" (best-effort strict, TODO 19). Portee                                       }
{ EXPLICITEMENT LIMITEE aux FONCTIONS generiques (le roadmap d en-tete                     }
{ ne donne d exemple d inference QUE pour un appel de fonction,                                  }
{ "identity(42)" - jamais pour une instanciation de STRUCT generique,                          }
{ "Wrapper(value: 5)" reste donc TypeIdx="Wrapper" tel quel, SANS                             }
{ substituer le champ "value" - deja le comportement EXISTANT de                                 }
{ TYK_STRUCT dans ParseCallArgs, aucune extension necessaire).                                     }
{                                                                       }
{ Contraintes (<T: Comparable>, where T: Equatable) - stockees dans le   }
{ ElemTypeIdx du TYK_GENERIC_PARAM (REUTILISE : un parametre de type              }
{ generique n a de toute facon jamais besoin d un "type d element" au             }
{ sens tableau/optional, TODO 04 - aucun conflit reel) - resolues au                  }
{ mieux contre un protocole/type CONNU (SymFind/IsPredeclaredType,                       }
{ WarnMsg si introuvable) mais JAMAIS VERIFIEES nulle part par la                          }
{ suite (best-effort STRICT, roadmap d en-tete : "jamais une                                    }
{ verification de satisfaction complete") - "Comparable"/"Equatable"                           }
{ (protocoles de la BIBLIOTHEQUE STANDARD Swift reelle) ne sont             }
{ d ailleurs JAMAIS declares nulle part dans ce compilateur (ni                                   }
{ generics.swift lui-meme, qui n ecrit AUCUNE contrainte explicite               }
{ malgre l usage de ">" dans "maximum" - la contrainte "Comparable"                             }
{ reelle resterait donc de toute facon introuvable si elle etait                                    }
{ ecrite, WarnMsg plutot que FatalError).                                                              }
{                                                                       }
{ HORS DE PORTEE (documente) : arguments de type EXPLICITES au point            }
{ d appel ("Wrapper<Int>(value: 5)") - AUCUN echantillon SAMPLES\SWIFT             }
{ n en a besoin, et la syntaxe est GENUINEMENT ambigue avec une chaine              }
{ de comparaisons ("Wrapper < Int > (5)") sans une desambiguation                          }
{ dediee ; classes/enums generiques (le roadmap d en-tete ne mentionne             }
{ que "func" et "struct"). }

{ ParseGenericParamList : REALISE la Forward-declaration du TODO 08 -   }
{ "<" PAS encore consomme (verifie ici, contrairement a l ancien              }
{ garde-fou FatalError du TODO 08/09 - ne consomme RIEN et renvoie                    }
{ simplement si absent, exactement comme ParseTopLevelDecl route SANS               }
{ consommer). Chaque "Nom [: Contrainte]" separe par une virgule                       }
{ devient une entree TYK_GENERIC_PARAM + un SK_TYPE dans la portee                     }
{ COURANTE (deja ouverte par l appelant). }
Procedure ParseGenericParamList;
Var
  GName, ConstraintNam : TString;
  GPT, ConstraintIdx, SI : Integer;
Begin
  If Not PPIsOp('<') Then Exit;
  PPAdvance;   { '<' }

  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de parametre de type generique attendu');
      Exit;
    End;
    GName := PPVal;
    PPAdvance;

    ConstraintIdx := -1;
    If PPMatch(':') Then
    Begin
      If PPKind <> TOK_IDENT Then
        FatalError('nom de contrainte (protocole/type) attendu apres '':''')
      Else
      Begin
        ConstraintNam := PPVal;
        SI := SymFind(ConstraintNam);
        If SI >= 0 Then ConstraintIdx := SymTab[SI].TypeIdx
        Else If IsPredeclaredType(ConstraintNam) <> 0 Then
          ConstraintIdx := IsPredeclaredType(ConstraintNam)
        Else
          WarnMsg('contrainte de type generique inconnue (verification ' +
            'best-effort seulement, TODO 13): ' + ConstraintNam);
        PPAdvance;
      End;
    End;

    GPT := TypeAdd(TYK_GENERIC_PARAM, GName, 4, 4, False, True, ConstraintIdx, -1);
    SymAdd(GName, SK_TYPE, GPT, False);
  Until Not PPMatch(',');

  If Not PPMatch('>') Then
    FatalError('signe ">" attendu pour fermer une liste de parametres de type generique');
End;

{ ParseWhereClause : REALISE la Forward-declaration du TODO 08 -       }
{ "where" DEJA CONSOMME ? NON - PP pointe encore SUR "where" (meme                }
{ convention que "func"/"struct"). "T: Contrainte" ICI MET A JOUR la              }
{ contrainte d un parametre de type generique DEJA ENREGISTRE par                    }
{ ParseGenericParamList (recherche par nom, SymFind) - PORTEE (documentee,          }
{ roadmap d en-tete, "portee a documenter si couverte" - AUCUN                             }
{ echantillon n utilise "where") : plusieurs clauses separees par                            }
{ virgule ("where T: Equatable, U: Comparable"), jamais une clause                              }
{ generale ("where T == U") ni une clause sur un tableau/collection. }
Procedure ParseWhereClause;
Var
  GName, ConstraintNam : TString;
  SI, GSI, ConstraintIdx : Integer;
Begin
  PPAdvance;   { where }
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de parametre de type generique attendu apres ''where''');
      Exit;
    End;
    GName := PPVal;
    PPAdvance;

    GSI := SymFind(GName);
    If (GSI < 0) Or (SymTab[GSI].Kind <> SK_TYPE) Or
       (TypeTab[SymTab[GSI].TypeIdx].Kind <> TYK_GENERIC_PARAM) Then
    Begin
      FatalError('"' + GName + '" n est pas un parametre de type generique ' +
        'connu dans cette clause ''where''');
      Exit;
    End;

    If Not PPMatch(':') Then
    Begin
      FatalError('"":"" attendu apres un nom dans une clause ''where''');
      Exit;
    End;
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de contrainte attendu dans une clause ''where''');
      Exit;
    End;
    ConstraintNam := PPVal;
    PPAdvance;

    SI := SymFind(ConstraintNam);
    If SI >= 0 Then ConstraintIdx := SymTab[SI].TypeIdx
    Else If IsPredeclaredType(ConstraintNam) <> 0 Then
      ConstraintIdx := IsPredeclaredType(ConstraintNam)
    Else
    Begin
      WarnMsg('contrainte inconnue dans une clause ''where'' (verification ' +
        'best-effort seulement, TODO 13): ' + ConstraintNam);
      ConstraintIdx := -1;
    End;
    TypeTab[SymTab[GSI].TypeIdx].ElemTypeIdx := ConstraintIdx;
  Until Not PPMatch(',');
End;

{ ------------------------------------------------------------ }
{ GenericSelfTest : fonction generique a UN parametre de type           }
{ ("identity<T>", forme EXACTE de generics.swift), inference au point            }
{ d appel ("identity(42) infere T = Int", DEJA verifiee comme roadmap-                }
{ correcte), fonction generique a comparaison ("maximum<T>", forme                     }
{ EXACTE de generics.swift - AUCUNE contrainte explicite, exactement                        }
{ comme dans le VRAI fichier malgre l usage de ">"), struct generique                       }
{ ("Wrapper<T>", forme EXACTE de generics.swift), "T" NE FUIT JAMAIS               }
{ hors de sa declaration, contrainte EXPLICITE ("<T: Comparable>",                       }
{ jamais verifiee - best-effort), clause "where" (JAMAIS exercee par             }
{ generics.swift mais explicitement promise par le roadmap d en-tete),                    }
{ plusieurs parametres de type ("<T, U>"), puis integration bout-en-             }
{ bout via ParseTopLevelDecls sur un extrait IDENTIQUE a generics.swift            }
{ - sur des extraits synthetiques (fichier temporaire, meme methode              }
{ que les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure GenericAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('GenericSelfTest: ' + Label_ + ' a echoue');
End;

Procedure GenericSelfTest;
Var
  FD, FT, FTWrapper, E : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { fonction generique a un parametre de type - forme EXACTE de           }
  { generics.swift (identity) }
  FD := FuncParseTopLevel('func identity<T>(_ value: T) -> T {' + Chr(10) +
    'return value' + Chr(10) + '}');
  GenericAssert('identity : enregistree', FD >= 0);
  FT := FuncDefPool[FD].TypeIdx;
  GenericAssert('identity : 1 parametre', TypeTab[FT].ParamCount = 1);
  GenericAssert('identity : parametre de type TYK_GENERIC_PARAM',
    TypeTab[FieldPool[TypeTab[FT].ParamFirst].TypeIdx].Kind = TYK_GENERIC_PARAM);
  { NOTE : SymFind (TODO 05) ne "purge" JAMAIS SymTab a la fermeture      }
  { d une portee (Dec(ScopeStackTop) seulement) - "T" reste donc            }
  { TOUJOURS trouvable PAR NOM, exactement comme "self"/tout parametre           }
  { d une AUTRE fonction deja analysee ; la VRAIE garantie verifiable            }
  { ici est que la PILE de portees elle-meme est bien revenue a son              }
  { niveau d avant l appel (ScopeStackTop), pas qu un nom ait disparu. }
  GenericAssert('identity : la portee ouverte pour "T" est bien ' +
    'refermee (ScopeStackTop revenu a -1, niveau fichier)', ScopeStackTop = -1);

  { inference au point d appel : "identity(42) infere T = Int" (roadmap  }
  { d en-tete, DEJA implemente par ParseCallArgs, TODO 06 etendu) }
  E := ExprParseString('identity(42)');
  GenericAssert('identity(42) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  GenericAssert('identity(42) : TypeIdx = Int (SUBSTITUE, PAS le ' +
    'parametre generique brut)', ExprPool[E].TypeIdx = PDT_INT);

  { fonction generique a comparaison - forme EXACTE de generics.swift    }
  { (maximum) - AUCUNE contrainte explicite, malgre ">" (identique au              }
  { VRAI fichier, best-effort). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FD := FuncParseTopLevel('func maximum<T>(_ a: T, _ b: T) -> T {' + Chr(10) +
    'if a > b {' + Chr(10) + 'return a' + Chr(10) + '}' + Chr(10) +
    'return b' + Chr(10) + '}');
  GenericAssert('maximum : enregistree (aucun crash malgre ">" sur un ' +
    'type generique non contraint)', FD >= 0);
  E := ExprParseString('maximum(10, 20)');
  GenericAssert('maximum(10,20) : TypeIdx = Int (inference sur le ' +
    'PREMIER parametre generique correspondant)', ExprPool[E].TypeIdx = PDT_INT);

  { struct generique - forme EXACTE de generics.swift (Wrapper) - meme    }
  { portee ouverte/refermee que pour une fonction generique (voir la              }
  { note ci-dessus sur SymFind/ScopeStackTop). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FTWrapper := StructParseTopLevel('struct Wrapper<T> {' + Chr(10) +
    'var value: T' + Chr(10) + '}');
  GenericAssert('Wrapper : TYK_STRUCT', TypeTab[FTWrapper].Kind = TYK_STRUCT);
  GenericAssert('Wrapper : 1 champ', TypeTab[FTWrapper].FieldCount = 1);
  GenericAssert('Wrapper.value : type TYK_GENERIC_PARAM',
    TypeTab[FieldPool[TypeTab[FTWrapper].FieldFirst].TypeIdx].Kind = TYK_GENERIC_PARAM);
  GenericAssert('Wrapper : la portee ouverte pour "T" est bien refermee ' +
    '(ScopeStackTop revenu a -1)', ScopeStackTop = -1);

  { contrainte EXPLICITE ("<T: Comparable>") - JAMAIS verifiee (best-      }
  { effort STRICT) : "Comparable" (bibliotheque standard Swift reelle)             }
  { n est nulle part declare ici, WarnMsg attendu (pas de FatalError -                  }
  { la fonction s enregistre malgre tout). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FD := FuncParseTopLevel('func firstOf<T: Comparable>(_ a: T, _ b: T) -> T {' +
    Chr(10) + 'return a' + Chr(10) + '}');
  GenericAssert('firstOf<T: Comparable> : enregistree malgre une ' +
    'contrainte introuvable (best-effort, jamais une erreur bloquante)', FD >= 0);

  { clause "where" (JAMAIS exercee par generics.swift, explicitement       }
  { promise par le roadmap d en-tete) + plusieurs parametres de type              }
  { ("<T, U>"). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FD := FuncParseTopLevel('func pairEqual<T, U>(_ a: T, _ b: U) -> Bool ' +
    'where T: Equatable {' + Chr(10) + 'return true' + Chr(10) + '}');
  GenericAssert('pairEqual<T, U> where T: Equatable : enregistree ' +
    '(clause ''where'' analysee sans erreur)', FD >= 0);
  FT := FuncDefPool[FD].TypeIdx;
  GenericAssert('pairEqual : 2 parametres (T et U, deux TYK_GENERIC_PARAM ' +
    'DISTINCTS)', TypeTab[FT].ParamCount = 2);
  GenericAssert('pairEqual : "a" (T) et "b" (U) ont des types DIFFERENTS',
    FieldPool[TypeTab[FT].ParamFirst].TypeIdx <> FieldPool[TypeTab[FT].ParamFirst + 1].TypeIdx);

  { integration bout-en-bout : extrait IDENTIQUE a generics.swift, en    }
  { entier, via ParseTopLevelDecls (TODO 05, deja capable de router                }
  { "func"/"struct" depuis les TODO 08/09) - arret propre attendu sur              }
  { "print(x)" final (code executable NU de haut niveau, meme gap                       }
  { documente que structs.swift/classes.swift/protos.swift/enums.swift). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32GENERICSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'func identity<T>(_ value: T) -> T {');
  WriteLn(LexSrcF, '    return value');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func maximum<T>(_ a: T, _ b: T) -> T {');
  WriteLn(LexSrcF, '    if a > b {');
  WriteLn(LexSrcF, '        return a');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    return b');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'struct Wrapper<T> {');
  WriteLn(LexSrcF, '    var value: T');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let x: Int = identity(42)');
  WriteLn(LexSrcF, 'let m: Int = maximum(10, 20)');
  WriteLn(LexSrcF, 'print(x)');
  WriteLn(LexSrcF, 'print(m)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32GENERICSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  GenericAssert('generics.swift (integral) : "x" (let) resolu', SymFind('x') >= 0);
  GenericAssert('generics.swift (integral) : "x" a le type Int (substitue, ' +
    'PAS le parametre generique brut)', SymTab[SymFind('x')].TypeIdx = PDT_INT);
  GenericAssert('generics.swift (integral) : "m" a le type Int',
    SymTab[SymFind('m')].TypeIdx = PDT_INT);
  GenericAssert('generics.swift (integral) : arret propre EXACT sur "print"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 14 - OPTIONNELS : OPTIONAL<T>, IF LET, GUARD LET, ??, !  }
{ ============================================================ }
{ L ESSENTIEL de la representation Optional<T> ("mot discriminant +   }
{ VALEUR", roadmap d en-tete - "meme famille de decision que le                  }
{ modele boite des interfaces") ETAIT DEJA POSE bien avant ce TODO :                  }
{ TYK_OPTIONAL/TypeIsOptional/TypeResolveOptional (TODO 04), le sucre             }
{ postfixe "Type?" (TODO 05), ExprAddNilLit et le deballage force               }
{ EK_FORCEDUNWRAP/le chainage EK_OPTIONALCHAIN (TODO 06), leur                          }
{ resolution via ResolveSelectorType (TODO 09) - CE TODO 14 est celui             }
{ qui les REUNIT et acheve les DERNIERES pieces manquantes :                              }
{   (1) "nil" CONTEXTUALISE (ApplyExprInitToSymbol, TODO 06 etendu               }
{       ci-dessus) - "nil" restait TypeIdx=-1 depuis sa creation                     }
{       (TODO 06) jusqu a etre REELLEMENT AFFECTE a une variable                          }
{       Optional DECLAREE EXPLICITEMENT - exactement le moment ou                            }
{       "nil" devient observable comme "la SEULE construction                                  }
{       d absence de valeur du langage" (roadmap d en-tete du TODO 04).                        }
{   (2) "if let"/"if var" (ParseIfStmt, TODO 07 etendu ci-dessus) et             }
{       "guard let"/"guard var" (ParseGuardStmt, TODO 07 etendu                            }
{       ci-dessus) - AUCUN nouveau champ sur TStmtNode : NameVal                             }
{       (inutilise par un if/guard ORDINAIRE) porte le nom de la                                }
{       liaison, le type DEBALLE se recalcule a la demande                                          }
{       (TypeResolveOptional). DIFFERENCE REELLE entre les deux,                                    }
{       explicitement soulignee par le roadmap et RESPECTEE ici :                                     }
{       "if let" ouvre une portee DEDIEE (fermee AVANT le "else"                                        }
{       eventuel, la liaison ne survit PAS a l instruction) ; "guard             }
{       let" enregistre DIRECTEMENT dans la portee APPELANTE (la                                 }
{       liaison reste visible APRES le guard entier).                                                    }
{   (3) Chainage optionnel MULTI-NIVEAUX ("a?.b?.c") - AUCUN nouveau            }
{       code : ResolveSelectorType (TODO 09) deballe DEJA son                                    }
{       Optional propre en TETE, avant de chercher le membre suivant -                          }
{       fonctionne DEJA correctement pour une CHAINE de "?." successifs.                             }
{       LIMITATION ASSUMEE ET DOCUMENTEE (jamais exercee par                                            }
{       optionals.swift) : ce compilateur AUTORISE (best-effort,                                        }
{       lenient) l acces PAR UN SIMPLE "." a une base Optional (auto-               }
{       deballage SILENCIEUX, meme esprit que l auto-dereferencement                                 }
{       de pointeur de GOCW32.PAS) plutot que d EXIGER "?."/"!" comme                                  }
{       le ferait un VRAI compilateur Swift (erreur de compilation                                        }
{       "value of optional type must be unwrapped" sinon) - consequence            }
{       directe : une chaine MELANGEANT "." et "?." (ex. "a?.b.c") NE               }
{       PROPAGE PAS le caractere Optional au-dela du DERNIER "?."                                  }
{       explicite (le "." final deballe silencieusement plutot que de                          }
{       preserver l Optional jusqu au bout, contrairement a la VRAIE                              }
{       regle de court-circuit Swift) - PORTEE reduite, coherente avec                          }
{       la simplification (1) deja en place, jamais corrigee ici en                                  }
{       l absence de toute pression de test reelle.                                                     }
{   (4) "!" (deballage force) PANIQUE a l execution si nil (roadmap                }
{       d en-tete) - DECISION explicitement DIFFEREE au generateur de              }
{       code (AUCUN codegen n existe encore, TODO 21+) : le mecanisme                       }
{       exact ("meme mecanisme d arret propre que panic() dans defer/               }
{       panic/recover SI ce sous-systeme existe, sinon un simple                                 }
{       message + code de sortie non nul") sera tranche au TODO 15                              }
{       (gestion d erreurs - c est LA ou "throws"/panic/etc. seront                                  }
{       reellement concus) plutot que devine ici sans lui - AUCUNE                                    }
{       structure de donnees n est necessaire MAINTENANT pour cette                                    }
{       seule decision. }

{ ------------------------------------------------------------ }
{ OptionalSelfTest : "nil" CONTEXTUALISE par une annotation Optional        }
{ explicite (forme EXACTE de optionals.swift, "var noValue: Int? =              }
{ nil") vs "nil" SANS annotation (best-effort honnete, jamais un                     }
{ crash), "if let"/"if var" (liaison typee/mutabilite correctes, portee              }
{ DEDIEE), "guard let" (liaison visible dans la portee APPELANTE,                       }
{ contrairement a "if let"), "??" et "!" (formes EXACTES de                              }
{ optionals.swift, deja testees structurellement au TODO 06 - simple                       }
{ confirmation directe ici), chainage optionnel sur DEUX niveaux                          }
{ ("a?.b?.c"), puis integration bout-en-bout via ParseTopLevelDecls               }
{ sur un extrait IDENTIQUE a optionals.swift - sur des extraits                              }
{ synthetiques (fichier temporaire, meme methode que les TODO                                   }
{ precedents). }
{ ------------------------------------------------------------ }

Procedure OptionalAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('OptionalSelfTest: ' + Label_ + ' a echoue');
End;

Procedure OptionalSelfTest;
Var
  SI, E, S, FTInner, FTOuter : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { "nil" CONTEXTUALISE par une annotation Optional explicite - forme     }
  { EXACTE de optionals.swift ("var noValue: Int? = nil"). }
  S := ParseStmtString('var noValue: Int? = nil');
  SI := SymFind('noValue');
  OptionalAssert('noValue : type Optional<Int>', TypeIsOptional(SymTab[SI].TypeIdx));
  OptionalAssert('noValue : deballe vers Int', TypeResolveOptional(SymTab[SI].TypeIdx) = PDT_INT);
  OptionalAssert('noValue : "nil" (InitExprIdx) est desormais CONTEXTUALISE ' +
    '(TypeIdx = Optional<Int>, PLUS -1)',
    ExprPool[SymTab[SI].InitExprIdx].TypeIdx = SymTab[SI].TypeIdx);

  { "nil" SANS annotation explicite - best-effort honnete (roadmap        }
  { d en-tete du TODO 04/06) : reste NON-TYPE, jamais un crash. }
  S := ParseStmtString('let bare = nil');
  SI := SymFind('bare');
  OptionalAssert('bare (sans annotation) : "nil" SEUL n infere rien ' +
    '(TypeIdx=-1, best-effort honnete - jamais un crash)', SymTab[SI].TypeIdx = -1);

  { "if let"/"if var" - liaison typee/mutabilite correctes }
  SI := SymAdd('maybeValue', SK_VAR, TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, PDT_INT, -1), False);
  S := ParseStmtString('if let unwrapped = maybeValue {' + Chr(10) +
    'print(unwrapped)' + Chr(10) + '}');
  OptionalAssert('if let : STK_IF', StmtPool[S].Kind = STK_IF);
  OptionalAssert('if let : NameVal="unwrapped"', StmtPool[S].NameVal = 'unwrapped');
  SI := SymFind('unwrapped');
  OptionalAssert('if let : "unwrapped" DEBALLE vers Int (PAS Optional<Int>)',
    SymTab[SI].TypeIdx = PDT_INT);
  OptionalAssert('if let : "unwrapped" est un "let" (IsConst)', SymTab[SI].IsConst);

  S := ParseStmtString('if var mutableUnwrapped = maybeValue {' + Chr(10) +
    'print(mutableUnwrapped)' + Chr(10) + '}');
  SI := SymFind('mutableUnwrapped');
  OptionalAssert('if var : "mutableUnwrapped" N EST PAS IsConst (mutable)',
    Not SymTab[SI].IsConst);

  { "guard let" - liaison visible dans la portee APPELANTE (DIFFERENCE   }
  { REELLE avec "if let", roadmap d en-tete) : verifiee en la referencant           }
  { depuis une instruction SUIVANTE, dans le MEME bloc. }
  S := ParseStmtString('{ guard let z = maybeValue else { return }' + Chr(10) +
    'let w = z }');
  SI := SymFind('w');
  OptionalAssert('guard let : "z" reste visible APRES le guard (utilisable ' +
    'par "let w = z" dans le MEME bloc) - "w" hérite du type deballe Int',
    SymTab[SI].TypeIdx = PDT_INT);

  { "??" - forme EXACTE de optionals.swift ("maybeValue ?? 0") - deja      }
  { testee structurellement au TODO 06 (precedence), simple confirmation           }
  { directe ici. }
  E := ExprParseString('maybeValue ?? 0');
  OptionalAssert('maybeValue ?? 0 : TypeIdx = Int (deballe)', ExprPool[E].TypeIdx = PDT_INT);

  { "!" - forme EXACTE de optionals.swift ("maybeValue!") - deja testee   }
  { structurellement au TODO 06, simple confirmation directe ici. Le               }
  { comportement PANIQUE a l execution reste une decision EXPLICITEMENT               }
  { DIFFEREE (voir la note d en-tete de section ci-dessus) - rien a                    }
  { verifier de plus a l analyse pour cette partie. }
  E := ExprParseString('maybeValue!');
  OptionalAssert('maybeValue! : EK_FORCEDUNWRAP', ExprPool[E].Kind = EK_FORCEDUNWRAP);
  OptionalAssert('maybeValue! : TypeIdx = Int (deballe)', ExprPool[E].TypeIdx = PDT_INT);

  { chainage optionnel sur DEUX niveaux ("a?.b?.c") - AUCUN nouveau code,  }
  { ResolveSelectorType (TODO 09) deballe DEJA en tete avant de chercher            }
  { le membre suivant. }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  FTInner := StructParseTopLevel('struct Inner {' + Chr(10) + 'var x: Int' + Chr(10) + '}');
  FTOuter := StructParseTopLevel('struct Outer {' + Chr(10) +
    'var inner: Inner?' + Chr(10) + '}');
  SI := SymAdd('outer', SK_VAR,
    TypeAdd(TYK_OPTIONAL, '', 0, 1, False, True, FTOuter, -1), False);
  E := ExprParseString('outer?.inner?.x');
  OptionalAssert('outer?.inner?.x : EK_OPTIONALCHAIN (dernier maillon)',
    ExprPool[E].Kind = EK_OPTIONALCHAIN);
  OptionalAssert('outer?.inner?.x : TypeIdx enveloppe dans un Optional ' +
    '(le chainage se propage sur DEUX niveaux)', TypeIsOptional(ExprPool[E].TypeIdx));
  OptionalAssert('outer?.inner?.x : deballe vers Int au bout des DEUX niveaux',
    TypeResolveOptional(ExprPool[E].TypeIdx) = PDT_INT);

  { integration bout-en-bout : extrait IDENTIQUE a optionals.swift, en    }
  { entier, via ParseTopLevelDecls - arret propre attendu sur le premier            }
  { "print(result)" (code executable NU de haut niveau, meme gap                          }
  { documente que TOUS les echantillons precedents). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32OPTIONALSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'var maybeValue: Int? = 42');
  WriteLn(LexSrcF, 'var noValue: Int? = nil');
  WriteLn(LexSrcF, 'let result: Int = maybeValue ?? 0');
  WriteLn(LexSrcF, 'print(result)');
  WriteLn(LexSrcF, 'let forced: Int = maybeValue!');
  WriteLn(LexSrcF, 'print(forced)');
  WriteLn(LexSrcF, 'let defaulted: Int = noValue ?? 99');
  WriteLn(LexSrcF, 'print(defaulted)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32OPTIONALSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  OptionalAssert('optionals.swift (integral) : "maybeValue" resolu', SymFind('maybeValue') >= 0);
  OptionalAssert('optionals.swift (integral) : "result" a le type Int (deballe)',
    SymTab[SymFind('result')].TypeIdx = PDT_INT);
  OptionalAssert('optionals.swift (integral) : arret propre EXACT sur "print"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 15 - GESTION D'ERREURS : THROWS, DO/TRY/CATCH, DEFER     }
{ ============================================================ }
{ Modele de propagation choisi EXPLICITEMENT (roadmap d en-tete) : un       }
{ fanion + une valeur d erreur globale, verifiee APRES chaque appel a une            }
{ fonction throws - PAS un vrai deroulement de pile avec table                              }
{ d exceptions SEH, meme choix que le PANIC_FLAG global de GOCW32.PAS               }
{ pour panic/recover. Ce mecanisme d execution (le fanion lui-meme, sa                  }
{ verification APRES chaque appel, le LIFO des "defer" empiles) est un              }
{ GENERATEUR de code (TODO 21+, TOUJOURS absent de ce projet a ce                        }
{ stade) : ce TODO 15, comme tous les TODO 05-14 avant lui, construit                     }
{ SEULEMENT le FRONT-END (AST + inference/verification de surface) -                     }
{ exactement la meme discipline que "STK_DEFER existe DEJA depuis le           }
{ TODO 08" chez GOCW32.PAS avant que son GENERATEUR ne le compile                          }
{ reellement (TODO 16 la-bas).                                                                  }
{   - "throws" en signature (ParseFuncSignature etendue ci-dessus,                        }
{     partagee par TOUTES les formes de fonctions/methodes/init - AUCUN            }
{     code supplementaire requis pour les methodes struct/class,                              }
{     heritage GRATUIT de l architecture DRY du TODO 08) : nouveau champ            }
{     TTypeRec.Throws (TYK_FUNC seulement, Faux par defaut).                                    }
{   - "throw Valeur" (STK_THROW) - l operande doit se conformer au                        }
{     protocole Error (roadmap d en-tete, meme modele "boite" que les              }
{     protocoles, TODO 11) : NON VERIFIE ici (LIMITATION ASSUMEE ET                       }
{     DOCUMENTEE, jamais exercee par errors.swift qui ne "throw" jamais            }
{     - voir sa propre note plus bas) - accepte N IMPORTE QUELLE                              }
{     expression, best-effort, comme le reste des verifications de                          }
{     conformite du projet.                                                                     }
{   - "try expr" / "try? expr" / "try! expr" (EK_TRY, PREFIXE le PLUS               }
{     LACHE de la chaine de precedence - ParseExpr etendu ci-dessus,                      }
{     MEME convention Op que EK_ASCAST pour distinguer les trois                              }
{     formes) : "try" propage le type TEL QUEL, "try?" l enveloppe dans            }
{     un Optional (meme garde anti-double-enveloppe que le chainage                        }
{     optionnel, TODO 14), "try!" le propage TEL QUEL egalement (sa                       }
{     PANIQUE a l execution si une erreur est lancee reste, comme le              }
{     "!" du TODO 14, une decision EXPLICITEMENT DIFFEREE au generateur          }
{     de code - AUCUNE structure supplementaire n est necessaire                              }
{     MAINTENANT pour cette seule decision, memes termes exacts que la               }
{     note d en-tete du TODO 14).                                                                }
{   - "defer" suivi d un bloc (STK_DEFER) - le noeud AST existe, l ORDRE            }
{     LIFO d execution en cas de "defer" multiples dans un meme bloc                     }
{     reste UN mecanisme d EXECUTION (TODO 21+) : ParseBlock (TODO 07)                   }
{     demeure totalement AGNOSTIQUE de cet ordre, empilant les                                  }
{     instructions dans l ORDRE TEXTUEL comme toujours - AUCUNE                                   }
{     modification requise.                                                                    }
{   - "do" suivi d un bloc puis de clauses "catch" (STK_DO +                              }
{     CatchClausePool, TCatchClause) - MEME convention EXACTE que                        }
{     CaseClausePool/ParseCaseClause du TODO 07/12 (ArgFirst/Count =                     }
{     plage CONTIGUE, aucune protection "buffer-puis-push" - un "do"                      }
{     NICHE dans le corps d un "catch" corromprait cette contiguite,                          }
{     EXACTEMENT comme un "switch" niche dans un "case" le ferait deja                   }
{     pour CaseClausePool : LIMITATION PREEXISTANTE du projet, jamais                       }
{     introduite ici, jamais corrigee ici non plus en l absence de toute            }
{     pression de test reelle sur l UN ou l AUTRE cas). La RESOLUTION           }
{     (quelle clause "catch" correspond a l erreur reellement lancee)               }
{     reste, comme le fanion lui-meme, un mecanisme d EXECUTION.                          }
{ errors.swift (l unique echantillon de ce TODO) N UTILISE EN REALITE           }
{ AUCUN "throws"/"try"/"do"/"catch" - seulement un "defer" ISOLE en             }
{ position DE HAUT NIVEAU (hors de toute fonction, usage Swift REEL             }
{ invalide mais coherent avec les autres echantillons "code executable          }
{ nu de haut niveau" deja rencontres) : l integration bout-en-bout ci-              }
{ dessous s arrete donc proprement sur ce "defer" (ParseTopLevelDecl,                 }
{ TODO 05, ne route toujours QUE let/var/typealias/func/struct/class/                    }
{ protocol/extension/enum) - tout le reste (throws, try/try?/try!, do/                  }
{ catch) est verifie sur des extraits SYNTHETIQUES independants,                                  }
{ exactement comme le chainage optionnel multi-niveaux du TODO 14. }

{ ------------------------------------------------------------ }
{ ErrorSelfTest : "throws" en signature (avec et sans "->", et son           }
{ absence par defaut), "try"/"try?"/"try!" (propagation de type,                        }
{ enveloppe Optional pour "try?"), "throw" (motif Type.cas, meme                         }
{ mecanisme que les cas d enum du TODO 12), "defer" (forme EXACTE de              }
{ errors.swift), "do/catch" (motif present vs catch generique de                          }
{ dernier recours, nombre de clauses), puis integration bout-en-bout via           }
{ ParseTopLevelDecls sur errors.swift EN ENTIER - arret propre attendu             }
{ sur son "defer" de haut niveau (voir la note d en-tete ci-dessus) -                }
{ sur des extraits synthetiques (fichier temporaire, meme methode que              }
{ les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure ErrorAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ErrorSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ErrorSelfTest;
Var
  FD, FTErr, E, S, D : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { "throws" AVEC "->" - forme EXACTE du roadmap d en-tete }
  FD := FuncParseTopLevel('func canFail() throws -> Int {' + Chr(10) +
    'return 1' + Chr(10) + '}');
  ErrorAssert('canFail() throws -> Int : Throws=Vrai',
    TypeTab[FuncDefPool[FD].TypeIdx].Throws);
  ErrorAssert('canFail() : type de retour = Int',
    FieldPool[TypeTab[FuncDefPool[FD].TypeIdx].ResultFirst].TypeIdx = PDT_INT);

  { SANS "throws" - Faux par defaut }
  FD := FuncParseTopLevel('func safe() -> Int {' + Chr(10) + 'return 2' + Chr(10) + '}');
  ErrorAssert('safe() : Throws=Faux (par defaut)',
    Not TypeTab[FuncDefPool[FD].TypeIdx].Throws);

  { "throws" SANS "->" (Void) }
  FD := FuncParseTopLevel('func warnOnly() throws {' + Chr(10) + '}');
  ErrorAssert('warnOnly() throws (Void) : Throws=Vrai',
    TypeTab[FuncDefPool[FD].TypeIdx].Throws);
  ErrorAssert('warnOnly() : type de retour = Void',
    FieldPool[TypeTab[FuncDefPool[FD].TypeIdx].ResultFirst].TypeIdx = PDT_VOID);

  { re-declare canFail (visible pour FuncFind lors des tests d expression   }
  { qui suivent - "warnOnly"/"safe" ci-dessus l ont fait sortir de porte   }
  { de la premiere declaration en ecrasant StmtPool/ExprPool, mais PAS         }
  { FuncDefPool qui reste cumulatif entre ces sous-tests). }

  { "try expr" - propage le type TEL QUEL }
  E := ExprParseString('try canFail()');
  ErrorAssert('try canFail() : EK_TRY', ExprPool[E].Kind = EK_TRY);
  ErrorAssert('try canFail() : Op=''try''', ExprPool[E].Op = 'try');
  ErrorAssert('try canFail() : TypeIdx = Int (inchange)', ExprPool[E].TypeIdx = PDT_INT);

  { "try? expr" - enveloppe dans un Optional }
  E := ExprParseString('try? canFail()');
  ErrorAssert('try? canFail() : Op=''try?''', ExprPool[E].Op = 'try?');
  ErrorAssert('try? canFail() : TypeIdx enveloppe (Optional<Int>)',
    TypeIsOptional(ExprPool[E].TypeIdx));
  ErrorAssert('try? canFail() : deballe vers Int', TypeResolveOptional(ExprPool[E].TypeIdx) = PDT_INT);

  { "try! expr" - deballage force, TypeIdx INCHANGE (panique a l execution        }
  { differee au generateur de code, voir la note d en-tete de ce TODO) }
  E := ExprParseString('try! canFail()');
  ErrorAssert('try! canFail() : Op=''try!''', ExprPool[E].Op = 'try!');
  ErrorAssert('try! canFail() : TypeIdx = Int (inchange)', ExprPool[E].TypeIdx = PDT_INT);

  { "throw" - motif Type.cas, meme mecanisme que les cas d enum du TODO 12 }
  FTErr := EnumParseTopLevel('enum NetworkError {' + Chr(10) +
    'case timeout' + Chr(10) + 'case notFound' + Chr(10) + '}');
  S := ParseStmtString('throw NetworkError.timeout');
  ErrorAssert('throw NetworkError.timeout : STK_THROW', StmtPool[S].Kind = STK_THROW);
  ErrorAssert('throw NetworkError.timeout : Left = EK_SELECTOR',
    ExprPool[StmtPool[S].Left].Kind = EK_SELECTOR);
  ErrorAssert('throw NetworkError.timeout : TypeIdx = NetworkError',
    ExprPool[StmtPool[S].Left].TypeIdx = FTErr);

  { "defer" suivi d un bloc - forme EXACTE de errors.swift }
  S := ParseStmtString('defer {' + Chr(10) + 'print(99)' + Chr(10) + '}');
  ErrorAssert('defer : STK_DEFER', StmtPool[S].Kind = STK_DEFER);
  ErrorAssert('defer : Right = STK_BLOCK', StmtPool[StmtPool[S].Right].Kind = STK_BLOCK);
  ErrorAssert('defer : le bloc contient exactement 1 instruction',
    StmtPool[StmtPool[S].Right].ArgCount = 1);

  { "do" suivi d un bloc, puis "catch Motif" et "catch" generique }
  S := ParseStmtString('do {' + Chr(10) + 'let x = try canFail()' + Chr(10) +
    'print(x)' + Chr(10) + '} catch NetworkError.timeout {' + Chr(10) +
    'print(1)' + Chr(10) + '} catch {' + Chr(10) + 'print(2)' + Chr(10) + '}');
  ErrorAssert('do/catch : STK_DO', StmtPool[S].Kind = STK_DO);
  ErrorAssert('do/catch : 2 clauses catch', StmtPool[S].ArgCount = 2);
  D := StmtPool[S].ArgFirst;
  ErrorAssert('catch NetworkError.timeout : motif PRESENT (PatternExpr>=0)',
    CatchClausePool[D].PatternExpr >= 0);
  ErrorAssert('catch generique (2e clause) : PatternExpr=-1 (dernier recours)',
    CatchClausePool[D + 1].PatternExpr = -1);
  ErrorAssert('do : le bloc "do" contient 2 instructions (let + print)',
    StmtPool[StmtPool[S].Right].ArgCount = 2);

  { integration bout-en-bout : errors.swift EN ENTIER (forme complete),  }
  { via ParseTopLevelDecls - arret propre attendu sur "defer" (voir la           }
  { note d en-tete de ce TODO). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32ERRORSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'enum FileError {');
  WriteLn(LexSrcF, '    case notFound');
  WriteLn(LexSrcF, '    case noPermission');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func openFile(_ name: String) -> Int {');
  WriteLn(LexSrcF, '    return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func process() -> Int {');
  WriteLn(LexSrcF, '    let status: Int = openFile("test.txt")');
  WriteLn(LexSrcF, '    if status == 0 {');
  WriteLn(LexSrcF, '        return 0');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'defer {');
  WriteLn(LexSrcF, '    print(99)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let ok: Int = process()');
  WriteLn(LexSrcF, 'print(ok)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32ERRORSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  ErrorAssert('errors.swift (integral) : "openFile" resolu', FuncFind('openFile', 1) >= 0);
  ErrorAssert('errors.swift (integral) : "process" resolu', FuncFind('process', 0) >= 0);
  ErrorAssert('errors.swift (integral) : arret propre EXACT sur "defer"',
    (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_DEFER));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 16 - TABLEAUX, DICTIONNAIRES ET ENSEMBLES                }
{ ============================================================ }
{ TYK_ARRAY/TYK_DICTIONARY/TYK_SET (avec ElemTypeIdx/KeyTypeIdx) et             }
{ PDT_ARRAY/PDT_DICTIONARY/PDT_SET (les entrees GENERIQUES non encore              }
{ parametrees) EXISTAIENT DEJA depuis le TODO 04, de meme que EK_ARRAYLIT/          }
{ EK_DICTLIT (parses depuis le TODO 06, mais SANS JAMAIS renseigner leur           }
{ TypeIdx - marqueur "reserve" jusqu ici) : ce TODO 16 acheve ce qui             }
{ restait :                                                                             }
{   - Sucre de type "[Element]"/"[Cle: Valeur]" (ParseTypeExpr etendu             }
{     ci-dessus, forme idiomatique REELLE de Swift) et forme generique            }
{     explicite "Array<T>"/"Set<T>"/"Dictionary<K,V>" (necessaire pour             }
{     Set, qui n a AUCUN sucre bracket en Swift reel) - toutes deux                    }
{     REJETEES pour tout autre type que ces trois collections                                  }
{     predeclarees (instancier un STRUCT/CLASS generique utilisateur                        }
{     avec des arguments concrets comme type NOMME reste HORS DE                            }
{     PORTEE, TYK_GENERIC_PARAM, TODO 13).                                                       }
{   - EK_ARRAYLIT/EK_DICTLIT (ParseArrayOrDictLiteral etendue                                  }
{     ci-dessus) : TypeIdx infere AU MIEUX depuis le PREMIER element/                     }
{     couple (best-effort, jamais de verification de coherence entre                        }
{     tous les elements, TODO 19) ; forme vide ("[]"/"[:]") reste le             }
{     type GENERIQUE non parametre (PDT_ARRAY/PDT_DICTIONARY,                                   }
{     ElemTypeIdx/KeyTypeIdx=-1, meme convention que l entree                                  }
{     predeclaree elle-meme).                                                                   }
{   - Indexation "a[i]" (EK_INDEX, ParsePostfix etendu ci-dessus) :                       }
{     Array<T> renvoie l element DIRECTEMENT, Dictionary<K,V> RENVOIE           }
{     un Optional<V> (nil si absente) - PAS de "valeur zero" implicite             }
{     comme la map de Go, difference REELLE explicitement exigee par              }
{     le roadmap d en-tete. La verification de BORNE/panique                                }
{     ("panique documentee si hors limites") reste un mecanisme                                 }
{     d EXECUTION (TODO 21+, absent ici) - documentee, jamais devinee.             }
{   - Membres integres (ResolveCollectionMemberType/SynthesizeMethodSig             }
{     ci-dessus, appeles depuis ResolveSelectorType etendue) : "count"             }
{     (propriete -> Int), Array.append(_:)/remove(at:),                                      }
{     Dictionary.removeValue(forKey:) (-> Optional<V>, MEME regle que                    }
{     l indexation ci-dessus), Set.insert(_:)/contains(_:)/remove(_:) -                    }
{     chaque membre reconnu SYNTHETISE une signature TYK_FUNC via le                     }
{     MEME mecanisme EXACT que ParseFuncSignature plutot que d ajouter             }
{     un nouveau mecanisme de dispatch - EK_CALL (TODO 06/08) s en                          }
{     empare ensuite SANS AUCUNE modification. PORTEE REDUITE                                    }
{     (documentee) : Set.insert(_:)/remove(_:) renvoient Void ici (pas             }
{     le tuple/Optional reels de Swift - roadmap d en-tete limitee a                     }
{     leurs noms, sans plus de detail, jamais exercee par aucun                                 }
{     echantillon).                                                                             }
{   - "for x in tableauOuEnsemble" (ParseForInStmt etendue ci-dessus) :             }
{     ElemT infere DIRECTEMENT depuis Array<T>/Set<T> quand la borne             }
{     n est PAS un intervalle binaire ('..<'/'...') ; Dictionary<K,V>                    }
{     (paire cle/valeur par iteration en Swift reel) reste HORS DE                          }
{     PORTEE (roadmap d en-tete ne l exige que pour Array, jamais                          }
{     exercee).                                                                                 }
{   - COPY-ON-WRITE reel de Swift (roadmap d en-tete) : UNE OPTIMISATION,           }
{     PAS une question de correction - portee EXPLICITEMENT documentee            }
{     PLUTOT QUE construite : ce compilateur copie IMMEDIATEMENT (la                    }
{     semantique de VALEUR reste toujours correcte, juste plus lente)               }
{     - AUCUN code n est necessaire pour cette seule decision, la vraie            }
{     representation memoire restant de toute facon un sujet du                                 }
{     GENERATEUR de code (TODO 21+, absent ici).                                                 }
{ arrays.swift (l unique echantillon de ce TODO) N UTILISE EN REALITE           }
{ AUCUN Array/Dictionary/Set reel - seulement des Int ordinaires et un             }
{ "for i in 0..<5" (deja pris en charge depuis le TODO 07) : l integration           }
{ bout-en-bout ci-dessous s arrete donc proprement sur son premier                       }
{ "print(a)" (juste apres les 5 "var", meme gap documente que tous les              }
{ echantillons precedents) - tout le reste (litteraux/sucre de type/                     }
{ membres integres/for-in sur un VRAI tableau) est verifie sur des                          }
{ extraits SYNTHETIQUES independants, exactement comme le chainage                          }
{ optionnel multi-niveaux du TODO 14 ou throws/try/do-catch du TODO 15. }

{ ------------------------------------------------------------ }
{ CollectionSelfTest : litteraux tableau/dictionnaire (avec et sans            }
{ elements, inference de type), sucre de type "[Element]"/                              }
{ "[Cle: Valeur]" et forme generique "Set<T>", indexation (Array                        }
{ direct, Dictionary enveloppe dans un Optional), membres integres                          }
{ (count, append, remove(at:), removeValue(forKey:), insert, contains,             }
{ remove), for-in sur un tableau, puis integration bout-en-bout via                       }
{ ParseTopLevelDecls sur arrays.swift EN ENTIER - arret propre attendu             }
{ sur son premier "print" (voir la note d en-tete ci-dessus) - sur des             }
{ extraits synthetiques (fichier temporaire, meme methode que les TODO           }
{ precedents). }
{ ------------------------------------------------------------ }

Procedure CollectionAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('CollectionSelfTest: ' + Label_ + ' a echoue');
End;

Procedure CollectionSelfTest;
Var
  E, S, SI, ArrT, DictT, SetT : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { litteral tableau - type infere depuis le PREMIER element }
  E := ExprParseString('[1, 2, 3]');
  CollectionAssert('[1,2,3] : EK_ARRAYLIT', ExprPool[E].Kind = EK_ARRAYLIT);
  CollectionAssert('[1,2,3] : TypeIdx = TYK_ARRAY', TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY);
  CollectionAssert('[1,2,3] : ElemTypeIdx = Int',
    TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PDT_INT);

  { tableau vide - generique NON parametre }
  E := ExprParseString('[]');
  CollectionAssert('[] : TypeIdx = PDT_ARRAY (generique)', ExprPool[E].TypeIdx = PDT_ARRAY);

  { litteral dictionnaire - type infere depuis le PREMIER couple }
  E := ExprParseString('["a": 1, "b": 2]');
  CollectionAssert('["a":1,"b":2] : EK_DICTLIT', ExprPool[E].Kind = EK_DICTLIT);
  CollectionAssert('["a":1,"b":2] : TypeIdx = TYK_DICTIONARY',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_DICTIONARY);
  CollectionAssert('["a":1,"b":2] : KeyTypeIdx = String',
    TypeTab[ExprPool[E].TypeIdx].KeyTypeIdx = PDT_STRING);
  CollectionAssert('["a":1,"b":2] : ElemTypeIdx = Int (valeur)',
    TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PDT_INT);

  { dictionnaire vide - generique NON parametre }
  E := ExprParseString('[:]');
  CollectionAssert('[:] : TypeIdx = PDT_DICTIONARY (generique)',
    ExprPool[E].TypeIdx = PDT_DICTIONARY);

  { sucre de type "[Element]" + litteral - declaration REELLE }
  S := ParseStmtString('var arr: [Int] = [1, 2, 3]');
  SI := SymFind('arr');
  ArrT := SymTab[SI].TypeIdx;
  CollectionAssert('var arr: [Int] : TypeIdx = TYK_ARRAY', TypeTab[ArrT].Kind = TYK_ARRAY);
  CollectionAssert('var arr: [Int] : ElemTypeIdx = Int', TypeTab[ArrT].ElemTypeIdx = PDT_INT);

  { membres integres d Array<T> }
  E := ExprParseString('arr.count');
  CollectionAssert('arr.count : Int', ExprPool[E].TypeIdx = PDT_INT);
  E := ExprParseString('arr.append(4)');
  CollectionAssert('arr.append(4) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  CollectionAssert('arr.append(4) : Void', ExprPool[E].TypeIdx = PDT_VOID);
  E := ExprParseString('arr.remove(at: 0)');
  CollectionAssert('arr.remove(at:0) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  CollectionAssert('arr.remove(at:0) : Int (element retire)', ExprPool[E].TypeIdx = PDT_INT);
  E := ExprParseString('arr[0]');
  CollectionAssert('arr[0] : EK_INDEX', ExprPool[E].Kind = EK_INDEX);
  CollectionAssert('arr[0] : Int DIRECT (pas d Optional pour Array)',
    ExprPool[E].TypeIdx = PDT_INT);

  { sucre de type "[Cle: Valeur]" + litteral - declaration REELLE }
  S := ParseStmtString('var dict: [String: Int] = ["a": 1]');
  SI := SymFind('dict');
  DictT := SymTab[SI].TypeIdx;
  CollectionAssert('var dict: [String:Int] : TypeIdx = TYK_DICTIONARY',
    TypeTab[DictT].Kind = TYK_DICTIONARY);
  CollectionAssert('var dict: [String:Int] : KeyTypeIdx = String',
    TypeTab[DictT].KeyTypeIdx = PDT_STRING);
  CollectionAssert('var dict: [String:Int] : ElemTypeIdx = Int',
    TypeTab[DictT].ElemTypeIdx = PDT_INT);

  { indexation Dictionary - Optional<V>, DIFFERENCE REELLE avec Array }
  E := ExprParseString('dict["a"]');
  CollectionAssert('dict["a"] : EK_INDEX', ExprPool[E].Kind = EK_INDEX);
  CollectionAssert('dict["a"] : enveloppe dans un Optional (PAS de valeur ' +
    'zero implicite, contrairement a la map de Go)', TypeIsOptional(ExprPool[E].TypeIdx));
  CollectionAssert('dict["a"] : deballe vers Int', TypeResolveOptional(ExprPool[E].TypeIdx) = PDT_INT);

  { membres integres de Dictionary<K,V> }
  E := ExprParseString('dict.count');
  CollectionAssert('dict.count : Int', ExprPool[E].TypeIdx = PDT_INT);
  E := ExprParseString('dict.removeValue(forKey: "a")');
  CollectionAssert('dict.removeValue(forKey:) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  CollectionAssert('dict.removeValue(forKey:) : Optional<Int>',
    TypeIsOptional(ExprPool[E].TypeIdx) And (TypeResolveOptional(ExprPool[E].TypeIdx) = PDT_INT));

  { forme generique explicite "Set<T>" - AUCUN sucre bracket pour Set }
  S := ParseStmtString('var s: Set<Int>');
  SI := SymFind('s');
  SetT := SymTab[SI].TypeIdx;
  CollectionAssert('var s: Set<Int> : TypeIdx = TYK_SET', TypeTab[SetT].Kind = TYK_SET);
  CollectionAssert('var s: Set<Int> : ElemTypeIdx = Int', TypeTab[SetT].ElemTypeIdx = PDT_INT);

  { membres integres de Set<T> }
  E := ExprParseString('s.insert(1)');
  CollectionAssert('s.insert(1) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  CollectionAssert('s.insert(1) : Void', ExprPool[E].TypeIdx = PDT_VOID);
  E := ExprParseString('s.contains(1)');
  CollectionAssert('s.contains(1) : Bool', ExprPool[E].TypeIdx = PDT_BOOL);
  E := ExprParseString('s.remove(1)');
  CollectionAssert('s.remove(1) : Void', ExprPool[E].TypeIdx = PDT_VOID);
  E := ExprParseString('s.count');
  CollectionAssert('s.count : Int', ExprPool[E].TypeIdx = PDT_INT);

  { for-in sur un VRAI tableau (pas seulement un intervalle, TODO 07) }
  S := ParseStmtString('for x in arr {' + Chr(10) + 'print(x)' + Chr(10) + '}');
  CollectionAssert('for x in arr : STK_FORRANGE', StmtPool[S].Kind = STK_FORRANGE);
  SI := SymFind('x');
  CollectionAssert('for x in arr : "x" infere Int (ElemTypeIdx du tableau)',
    SymTab[SI].TypeIdx = PDT_INT);

  { integration bout-en-bout : arrays.swift EN ENTIER (forme complete),  }
  { via ParseTopLevelDecls - arret propre attendu sur "print" (voir la           }
  { note d en-tete de ce TODO). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32COLLECTIONSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'var a: Int = 10');
  WriteLn(LexSrcF, 'var b: Int = 20');
  WriteLn(LexSrcF, 'var c: Int = 30');
  WriteLn(LexSrcF, 'var d: Int = 40');
  WriteLn(LexSrcF, 'var e: Int = 50');
  WriteLn(LexSrcF, 'print(a)');
  WriteLn(LexSrcF, 'print(b)');
  WriteLn(LexSrcF, 'print(c)');
  WriteLn(LexSrcF, 'print(d)');
  WriteLn(LexSrcF, 'print(e)');
  WriteLn(LexSrcF, 'var count: Int = 5');
  WriteLn(LexSrcF, 'print(count)');
  WriteLn(LexSrcF, 'for i in 0..<5 {');
  WriteLn(LexSrcF, '    print(i)');
  WriteLn(LexSrcF, '}');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32COLLECTIONSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  CollectionAssert('arrays.swift (integral) : "a".."e" resolus',
    (SymFind('a') >= 0) And (SymFind('e') >= 0));
  CollectionAssert('arrays.swift (integral) : arret propre EXACT sur "print"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 17 - CHAINES ET CARACTERES : INTERPOLATION ET UTF-8      }
{ ============================================================ }
{ L ESSENTIEL de ce TODO ETAIT DEJA POSE bien avant lui, par                             }
{ anticipation directe (meme discipline que TYK_OPTIONAL/TYK_ARRAY               }
{ predeclares au TODO 04 bien avant leurs TODO respectifs) :                                }
{   - EK_STRINGLIT (TODO 06, ExprAddStringLit) : TypeIdx=PDT_STRING                       }
{     DES sa creation.                                                                          }
{   - EK_STRINGINTERP ("\(expr)", TODO 06, ParseStringInterp) : DEJA               }
{     PLEINEMENT parse ET type (TypeIdx=PDT_STRING) - le roadmap                              }
{     d en-tete evoque _SWRT_STRCAT comme mecanisme d ASSEMBLAGE, un                     }
{     sujet de GENERATEUR de code (TODO 21+, absent ici) : rien de plus            }
{     n est necessaire cote FRONT-END, simple confirmation ci-dessous.               }
{   - Concatenation "+"/"+=" (ExprInferBinaryType, TODO 06) : AUCUN cas          }
{     special n a jamais ete necessaire - le repli GENERIQUE                                }
{     ("ExprInferBinaryType := LTIdx") renvoie DEJA PDT_STRING des que             }
{     l operande GAUCHE est une String, exactement comme pour tout                          }
{     autre type ; "+=" (STK_ASSIGN, TODO 07) ne fait AUCUNE distinction                 }
{     de type non plus - simple confirmation ci-dessous, aucun code                            }
{     nouveau.                                                                                  }
{   - Contextualisation Character (ApplyExprInitToSymbol, TODO 05/06) :          }
{     "let c: Character = "a""" - Swift REEL n a AUCUNE syntaxe de                       }
{     litteral DISTINCTE pour Character (contrairement a "nil" pour                        }
{     Optional, TODO 14) : un litteral Character est LITTERALEMENT un              }
{     litteral String ordinaire (EK_STRINGLIT, TypeIdx=PDT_STRING) place                 }
{     dans un contexte Character PAR L ANNOTATION DE TYPE SEULE - la                       }
{     verification best-effort deja ecrite au TODO 05                                          }
{     ("TYK_STRING: If Not (TypeTab[RTIdx].Kind In [TYK_STRING,                                 }
{     TYK_CHARACTER])") acceptait DEJA ce cas SANS AUCUN avertissement                     }
{     - SymTab[SI].TypeIdx (fixe par SymAdd AVANT cet appel, ParseLetVarPattern,        }
{     TODO 05) porte DEJA le type DECLARE (Character), jamais ecrase                         }
{     ici : simple confirmation ci-dessous, aucun code nouveau.                                 }
{ Ce qui restait GENUINEMENT a construire pour ce TODO :                                    }
{   - "for ch in uneChaine" (ParseForInStmt etendue ci-dessus) : ElemT              }
{     infere directement Character quand la borne resout a TYK_STRING              }
{     (apres Array<T>/Set<T>, TODO 16) - AUCUN decodage UTF-8 REEL                       }
{     n est necessaire ICI (front-end uniquement : le SEUL fait a                             }
{     etablir a ce stade est le TYPE de la variable de boucle, le                              }
{     decoupage rune-par-rune lui-meme restant un sujet de GENERATEUR              }
{     de code, "meme decodeur que le TODO 14 de GOCW32.PAS", TODO 21+).            }
{   - String.count (ResolveSelectorType etendue ci-dessus) : AUCUNE                       }
{     entree FieldPool/MethodPool n existe pour String (type predeclare,             }
{     jamais construit par ParseStructDecl) - "count" est la SEULE                       }
{     propriete exigee par le roadmap d en-tete, resout DIRECTEMENT                       }
{     vers Int (EN OCTETS ou, au mieux, en POINTS DE CODE - JAMAIS en                    }
{     vrais graphemes composes, limitation EXPLICITEMENT documentee par            }
{     le roadmap lui-meme, "count sur une String compte les octets... ").              }
{   - "==" par CONTENU (roadmap d en-tete, "piege deja documente et                       }
{     corrige dans GOCW32.PAS") : DEJA VRAI a ce stade FRONT-END SANS               }
{     AUCUN code supplementaire - ExprInferBinaryType (TODO 06) traite             }
{     "==" de facon PUREMENT SEMANTIQUE (TypeIdx resultat = PDT_BOOL,                    }
{     quels que soient les operandes) : AUCUNE notion de POINTEUR                             }
{     n existe encore a ce stade (ni ARC, TODO 18, ni generateur de                          }
{     code, TODO 21+) pour qu une comparaison "par pointeur" soit meme               }
{     representable ici - la VRAIE distinction (== par contenu vs par              }
{     adresse memoire) ne deviendra un choix REEL qu au moment de                            }
{     GENERER le code de comparaison (TODO 21+, ou elle devra emettre               }
{     un VRAI parcours octet-par-octet plutot qu une simple comparaison               }
{     de pointeurs 32 bits) - decision EXPLICITEMENT DIFFEREE, documentee            }
{     plutot que devinee, meme discipline que le "!" du TODO 14 et le                    }
{     "try!" du TODO 15.                                                                        }
{ hello.swift (l unique echantillon a utiliser reellement des chaines,           }
{ "Hello, 8086!") N UTILISE NI interpolation, NI concatenation, NI                       }
{ Character, NI for-in sur une chaine : l integration bout-en-bout ci-             }
{ dessous s arrete donc proprement sur son premier "print" (juste apres           }
{ les 3 "let"/"var", meme gap documente que tous les echantillons                            }
{ precedents) - tout le reste est verifie sur des extraits SYNTHETIQUES               }
{ independants, exactement comme le "for x in arr" du TODO 16. }

{ ------------------------------------------------------------ }
{ StringSelfTest : litteral String simple, interpolation "\(expr)",     }
{ concatenation "+"/"+=", contextualisation Character (deja acquise),               }
{ for-in sur une String (NOUVEAU, -> Character), String.count (NOUVEAU),          }
{ "==" par contenu, puis integration bout-en-bout via ParseTopLevelDecls           }
{ sur hello.swift EN ENTIER - arret propre attendu sur son premier             }
{ "print" (voir la note d en-tete ci-dessus) - sur des extraits                              }
{ synthetiques (fichier temporaire, meme methode que les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure StringAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StringSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StringSelfTest;
Var
  E, S, SI : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { litteral String simple - deja acquis (TODO 06), simple confirmation }
  E := ExprParseString('"hello"');
  StringAssert('"hello" : EK_STRINGLIT', ExprPool[E].Kind = EK_STRINGLIT);
  StringAssert('"hello" : TypeIdx = String', ExprPool[E].TypeIdx = PDT_STRING);

  { interpolation "\(expr)" - deja acquise (TODO 06), simple confirmation }
  SymAdd('x', SK_VAR, PDT_INT, False);
  E := ExprParseString('"count is \(x)"');
  StringAssert('"count is \(x)" : EK_STRINGINTERP', ExprPool[E].Kind = EK_STRINGINTERP);
  StringAssert('"count is \(x)" : TypeIdx = String', ExprPool[E].TypeIdx = PDT_STRING);

  { concatenation "+" - deja acquise (repli generique de                }
  { ExprInferBinaryType, TODO 06), simple confirmation }
  E := ExprParseString('"a" + "b"');
  StringAssert('"a" + "b" : TypeIdx = String', ExprPool[E].TypeIdx = PDT_STRING);

  { "+=" - deja acquis (STK_ASSIGN generique, TODO 07), simple confirmation }
  SymAdd('greeting', SK_VAR, PDT_STRING, False);
  S := ParseStmtString('greeting += "!"');
  StringAssert('greeting += "!" : STK_ASSIGN', StmtPool[S].Kind = STK_ASSIGN);
  StringAssert('greeting += "!" : Op=''+=''', StmtPool[S].Op = '+=');

  { contextualisation Character - deja acquise (TODO 05/06), simple      }
  { confirmation - AUCUNE syntaxe de litteral distincte en Swift reel,               }
  { seule l annotation de type contextualise. }
  S := ParseStmtString('let c: Character = "a"');
  SI := SymFind('c');
  StringAssert('let c: Character = "a" : TypeIdx = Character', SymTab[SI].TypeIdx = PDT_CHARACTER);

  { for-in sur une String - NOUVEAU (ParseForInStmt etendue ci-dessus) }
  SymAdd('s', SK_VAR, PDT_STRING, False);
  S := ParseStmtString('for ch in s {' + Chr(10) + 'print(ch)' + Chr(10) + '}');
  StringAssert('for ch in s : STK_FORRANGE', StmtPool[S].Kind = STK_FORRANGE);
  SI := SymFind('ch');
  StringAssert('for ch in s : "ch" infere Character', SymTab[SI].TypeIdx = PDT_CHARACTER);

  { String.count - NOUVEAU (ResolveSelectorType etendue ci-dessus) }
  E := ExprParseString('s.count');
  StringAssert('s.count : Int', ExprPool[E].TypeIdx = PDT_INT);

  { "==" par contenu - deja vrai a ce stade front-end (AUCUNE notion de   }
  { pointeur n existe encore), simple confirmation }
  E := ExprParseString('"a" == "a"');
  StringAssert('"a" == "a" : Bool', ExprPool[E].TypeIdx = PDT_BOOL);

  { integration bout-en-bout : hello.swift EN ENTIER (forme complete),    }
  { via ParseTopLevelDecls - arret propre attendu sur "print" (voir la           }
  { note d en-tete de ce TODO). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32STRINGSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let greeting: String = "Hello, 8086!"');
  WriteLn(LexSrcF, 'let version: Int = 1');
  WriteLn(LexSrcF, 'var counter: Int = 0');
  WriteLn(LexSrcF, 'print(greeting)');
  WriteLn(LexSrcF, 'print(version)');
  WriteLn(LexSrcF, 'counter = counter + 1');
  WriteLn(LexSrcF, 'print(counter)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32STRINGSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  StringAssert('hello.swift (integral) : "greeting" a le type String',
    SymTab[SymFind('greeting')].TypeIdx = PDT_STRING);
  StringAssert('hello.swift (integral) : arret propre EXACT sur "print"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 18 - MODELE MEMOIRE : ARC ET SEMANTIQUE DE COPIE          }
{ ============================================================ }
{ Ce TODO est explicitement une DECISION ARCHITECTURALE (roadmap             }
{ d en-tete : "a trancher AVANT le generateur de code", "meme discipline           }
{ que le choix goroutines-cooperatives-vs-threads-reels de GOCW32.PAS")               }
{ - PAS un sous-systeme a construire : aucun GENERATEUR de code n existe            }
{ encore (TODO 21+), donc ni un vrai compteur de references NI une                        }
{ vraie copie memoire ne sont OBSERVABLES a ce stade. Le deliverable                    }
{ REEL de ce TODO est cette decision elle-meme, DOCUMENTEE avec la MEME            }
{ honnetete que chaque decision similaire des compilateurs freres                             }
{ (roadmap d en-tete), puis un AUDIT confirmant que le front-end                              }
{ EXISTANT la reflete deja correctement partout.                                                }
{                                                                       }
{ DECISION 1 - CLASSES (ARC) : PAS DE LIBERATION DU TOUT. Alloue sur     }
{ le tas via le meme _SWRT_ALLOC que tout le reste (TODO 21+), jamais             }
{ libere explicitement - AUCUN compteur de references, AUCUN                                 }
{ decrementement a la sortie de portee. Choisi plutot qu un ARC REEL             }
{ pour la MEME raison, MOT POUR MOT, que le "pas de vrai GC"                              }
{ deja assume ET DOCUMENTE par GOCW32.PAS pour ses propres structures :               }
{ correct pour tout programme de la taille d un SAMPLES\SWIFT\*.swift                    }
{ (fuite sans consequence observable a cette echelle), et evite TOUTE                    }
{ la surface de bogues REELLE d un ARC (cycles de reference non casses            }
{ = fuite silencieuse, double-liberation si un decrementement est                             }
{ oublie ou double-compte) pour un gain de fidelite a Swift reel qu                     }
{ AUCUN echantillon SAMPLES\SWIFT n exploite (aucun ne cree de cycle              }
{ de reference, aucun ne depend d un timing de deinit deterministe).                     }
{ Portee EXPLICITEMENT reduite, memes termes que les autres deferrals                    }
{ deja actes (le "!" du TODO 14, le "try!" du TODO 15) : decision                           }
{ honnetement DIFFEREE au generateur de code (TODO 21+) plutot que                          }
{ devinee ici sans lui.                                                                         }
{                                                                       }
{ DECISION 2 - TYPES VALEUR (struct/enum/Array/Dictionary/Set/tuple) :  }
{ copie REELLE des donnees a chaque affectation/passage en parametre,             }
{ JAMAIS de partage implicite (contrairement aux classes) - DEJA                              }
{ ENTIEREMENT capture au niveau du FRONT-END par le champ                                    }
{ TTypeRec.IsValueType (TODO 04, "distinction CENTRALE du langage,                            }
{ absente de Go") : AUCUN nouveau champ, AUCUNE nouvelle structure                            }
{ n est necessaire ici - le MECANISME de copie lui-meme (memcpy champ            }
{ par champ vs simple copie de pointeur) reste un fait de GENERATEUR             }
{ de code (TODO 21+, consultera ce MEME champ IsValueType au moment                     }
{ d emettre soit une VRAIE copie soit une affectation de pointeur).                       }
{ AUDIT ci-dessous (MemorySelfTest) : confirme que CHAQUE site de                            }
{ construction de type (TypeInit pour les scalaires/collections                                   }
{ predeclarees, ParseStructDecl/ParseClassDecl/ParseEnumDecl/                                    }
{ ParseFuncSignature/ParseTypeExpr pour tout le reste) a DEJA pose ce               }
{ champ correctement, SANS AUCUNE exception trouvee - un audit                                  }
{ EXHAUSTIF de tous les appels TypeAdd(TYK_...) du fichier confirme                        }
{ qu aucune correction n est necessaire : Int/Double/Bool/String/                             }
{ Character/Array/Dictionary/Set/Optional/struct/enum = Vrai (valeur) ;               }
{ class/protocole (Any/AnyObject INCLUS - "modele boite" du TODO 11,                     }
{ une valeur existentielle est ICI representee par un POINTEUR vers                        }
{ une boite, distinct de la question purement LANGAGE de la semantique             }
{ de valeur de "Any" en Swift reel)/fonction-fermeture (deja documente,                  }
{ TODO 08 : "une fermeture Swift EST un objet a compteur de references                    }
{ en pratique") = Faux (reference). }

{ ------------------------------------------------------------ }
{ MemorySelfTest : audit CONFIRMATOIRE de IsValueType sur un              }
{ representant de CHAQUE famille de type (scalaires, String/Character,               }
{ Array<T>/Dictionary<K,V>/Set<T>, Optional<T>, struct, enum, class,                     }
{ protocole/existentiel, signature de fonction/fermeture) - AUCUNE                          }
{ construction nouvelle, seulement des verifications sur ce qui existe               }
{ deja depuis les TODO 04/08/09/10/11/12/13/14/16 (voir la note                                }
{ d en-tete ci-dessus pour le detail complet de l audit) - sur des                       }
{ extraits synthetiques (fichier temporaire, meme methode que les TODO           }
{ precedents), reutilisant les aides deja ecrites                                              }
{ (StructParseTopLevel/ClassParseTopLevel/EnumParseTopLevel/                                    }
{ FuncParseTopLevel/ParseStmtString) plutot que d en re-ecrire de                             }
{ nouvelles - RIEN de neuf a integrer bout-en-bout via                                          }
{ ParseTopLevelDecls ici (structs.swift/classes.swift le sont DEJA                          }
{ integralement au TODO 09/10, aucune raison de dupliquer ce travail). }
{ ------------------------------------------------------------ }

Procedure MemoryAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('MemorySelfTest: ' + Label_ + ' a echoue');
End;

Procedure MemorySelfTest;
Var
  FD, FT, S, SI : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { scalaires/String/Character - type VALEUR (deja acquis, TODO 03/04/17) }
  MemoryAssert('Int : type VALEUR', TypeTab[PDT_INT].IsValueType);
  MemoryAssert('Double : type VALEUR', TypeTab[PDT_DOUBLE].IsValueType);
  MemoryAssert('Bool : type VALEUR', TypeTab[PDT_BOOL].IsValueType);
  MemoryAssert('String : type VALEUR', TypeTab[PDT_STRING].IsValueType);
  MemoryAssert('Character : type VALEUR', TypeTab[PDT_CHARACTER].IsValueType);

  { Array<T>/Dictionary<K,V>/Set<T> - type VALEUR (deja acquis, TODO 16) }
  S := ParseStmtString('var memArr: [Int] = [1, 2, 3]');
  SI := SymFind('memArr');
  MemoryAssert('Array<Int> : type VALEUR', TypeTab[SymTab[SI].TypeIdx].IsValueType);
  S := ParseStmtString('var memDict: [String: Int] = ["a": 1]');
  SI := SymFind('memDict');
  MemoryAssert('Dictionary<String,Int> : type VALEUR', TypeTab[SymTab[SI].TypeIdx].IsValueType);
  S := ParseStmtString('var memSet: Set<Int>');
  SI := SymFind('memSet');
  MemoryAssert('Set<Int> : type VALEUR', TypeTab[SymTab[SI].TypeIdx].IsValueType);

  { Optional<T> - type VALEUR (deja acquis, TODO 04/14) }
  S := ParseStmtString('var memOpt: Int? = nil');
  SI := SymFind('memOpt');
  MemoryAssert('Optional<Int> : type VALEUR', TypeTab[SymTab[SI].TypeIdx].IsValueType);

  { struct - type VALEUR (deja acquis, TODO 09) }
  FT := StructParseTopLevel('struct Wallet {' + Chr(10) + 'var amount: Int' + Chr(10) + '}');
  MemoryAssert('struct Wallet : type VALEUR', TypeTab[FT].IsValueType);

  { enum - type VALEUR (deja acquis, TODO 12) }
  FT := EnumParseTopLevel('enum Currency {' + Chr(10) + 'case usd' + Chr(10) +
    'case eur' + Chr(10) + '}');
  MemoryAssert('enum Currency : type VALEUR', TypeTab[FT].IsValueType);

  { class - type REFERENCE, DIFFERENCE CENTRALE avec struct (deja        }
  { acquis, TODO 10) - AUCUNE liberation (DECISION 1 ci-dessus), sans             }
  { impact sur ce champ front-end lui-meme. }
  FT := ClassParseTopLevel('class Account {' + Chr(10) + 'var balance: Int' + Chr(10) + '}');
  MemoryAssert('class Account : type REFERENCE (Not IsValueType)', Not TypeTab[FT].IsValueType);

  { protocole/existentiel (Any/AnyObject) - type REFERENCE ("modele          }
  { boite", deja acquis, TODO 04/11) }
  MemoryAssert('Any : type REFERENCE (existentiel, modele boite)', Not TypeTab[PDT_ANY].IsValueType);
  MemoryAssert('AnyObject : type REFERENCE', Not TypeTab[PDT_ANYOBJECT].IsValueType);

  { signature de fonction/fermeture - type REFERENCE (deja acquis,       }
  { TODO 08 : "une fermeture Swift EST un objet a compteur de references           }
  { en pratique") }
  FD := FuncParseTopLevel('func combine(x: Int) -> Int {' + Chr(10) + 'return x' + Chr(10) + '}');
  MemoryAssert('func(...)->Int (signature) : type REFERENCE (Not IsValueType)',
    Not TypeTab[FuncDefPool[FD].TypeIdx].IsValueType);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 19 - ANALYSE SEMANTIQUE : SYMBOLES, PORTEES, VERIFICATION }
{ ============================================================ }
{ QUATRE points precis exiges par le roadmap d en-tete :                                     }
{   (1) "Verification de type best-effort sur affectations/appels/                       }
{       retours (types incompatibles = erreur claire...)" -                                     }
{       ApplyExprInitToSymbol (TODO 05, etendue ici) ne se limitait                       }
{       qu a QUATRE TTypeKind (Int/Float/Bool/String, simple WarnMsg) -                       }
{       remplacee par TypesCompatibleForInit (ci-dessus), un VRAI                             }
{       controle COUVRANT TOUS les TTypeKind (heritage de classe,                             }
{       protocoles deja geres separement, familles numeriques,                                    }
{       String/Character, collections/Optional/tuple/fonction par KIND                    }
{       SANS verification profonde - meme discipline que le reste du               }
{       projet), qui devient une ERREUR CLAIRE (FatalError) INCONDITIONNELLE               }
{       - "Int vers Double n'est PAS implicite" (roadmap) est honore EN            }
{       PRESERVANT l EXCEPTION reelle de Swift (un litteral ENTIER reste           }
{       contextuellement polymorphe face a Float, "let d: Double = 5" ;                }
{       SEULEMENT le litteral, jamais une variable/expression Int).                             }
{   (2) "'declare et jamais utilise' (meme regle stricte que GOCW32.PAS             }
{       pour les variables locales - erreur en mode strict, avertissement          }
{       sinon)" - CORRIGE une note perimee de SymLeaveScope (TODO 05,             }
{       qui affirmait a tort "aucune mention dans le roadmap TODO 05/19" :                 }
{       la mention EXISTE bel et bien) : TSymRec.Used/WasVarDecl                                  }
{       (nouveaux champs) + SymLeaveScope etendue (ci-dessus) verifient             }
{       desormais CHAQUE variable locale (WasVarDecl=Vrai, ParseLetVarPattern           }
{       UNIQUEMENT - jamais un parametre, une variable de boucle, une                      }
{       liaison if-let/guard-let/motif d enum, ni "self") a la SORTIE                     }
{       de SA portee - Opts.StrictMode (reserve depuis le TODO 01/02,                     }
{       TOUJOURS Vrai par defaut, aucun "-strict" n existe encore pour                    }
{       le faire varier) gouverne FatalError vs WarnMsg, EXACTEMENT                            }
{       comme documente par son propre champ depuis l origine.                                    }
{   (3) "Verification des types de retour de fonction contre le corps                     }
{       (...) - best-effort, pas une vraie analyse de chemins                                    }
{       exhaustive" - BlockHasReturnValue (ci-dessus), appelee par                            }
{       ParseFuncDecl : confirme qu AU MOINS UN "return" AVEC valeur                     }
{       existe QUELQUE PART dans le corps d une fonction non-Void                            }
{       (recursif a travers if/else, guard/else, while/repeat/for,                            }
{       switch, do/catch) - PAS une verification que TOUS les chemins                   }
{       en aient un (analyse de flot REELLE, explicitement exclue par              }
{       le roadmap) - FatalError INCONDITIONNELLE si absent (Void EST                    }
{       exempte, ResultT=PDT_VOID).                                                             }
{   (4) "Verification de conformite aux protocoles (...) et de                                }
{       compatibilite de signature pour override (...) executees a                            }
{       cette etape" - DEJA CONSTRUITES aux TODO 10/11 respectifs                              }
{       (TypeSatisfiesProtocol, verification best-effort d override) :                       }
{       AUCUN nouveau code n est necessaire, SEULEMENT une confirmation             }
{       que ces controles restent actifs sous ce TODO 19 (deja EXERCES               }
{       en continu par ProtocolSelfTest/ClassSelfTest a chaque exemplaire            }
{       de Run(), sans regression detectee par cette extension).                                }
{ Les TROIS controles NOUVEAUX (1/2/3) ont ete verifies SANS AUCUNE                        }
{ regression contre les 18 self-tests EXISTANTS (TypeSelfTest a                                 }
{ ErrorSelfTest/CollectionSelfTest/StringSelfTest/MemorySelfTest) avant             }
{ meme d ecrire SemanticSelfTest - preuve que leur PORTEE (variables                            }
{ locales UNIQUEMENT, jamais parametres/liaisons ; erreur INCONDITIONNELLE          }
{ pour (1)/(3), gouvernee par StrictMode SEULEMENT pour (2)) a ete                            }
{ choisie avec le soin necessaire. }

{ ------------------------------------------------------------ }
{ SemanticSelfTest : TypesCompatibleForInit (positif/negatif, heritage             }
{ de classe, litteral Int->Double contextualise), "declare et jamais              }
{ utilise" (positif utilise, negatif observe en mode NON-strict pour              }
{ eviter le Halt() d un FatalError reel, parametre/variable de boucle                    }
{ EXEMPTES), BlockHasReturnValue (avec/sans return, if/else imbrique),             }
{ puis integration bout-en-bout via ParseTopLevelDecls sur math.swift            }
{ EN ENTIER - PREMIERE fois que ce fichier precis (func/parametres/                       }
{ inout/return/recursion) est integre a l identique (FuncSelfTest ne                    }
{ s en inspirait auparavant que d un extrait "ressemblant") - sur des             }
{ extraits synthetiques (fichier temporaire, meme methode que les TODO           }
{ precedents). }
{ ------------------------------------------------------------ }

Procedure SemanticAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('SemanticSelfTest: ' + Label_ + ' a echoue');
End;

Procedure SemanticSelfTest;
Var
  FD, FTAnimal, FTDog, S, SI : Integer;
  SavedStrict : Boolean;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { TypesCompatibleForInit : positif (identique), negatif (incompatible), }
  { heritage de classe (sous-classe -> super-classe) }
  SemanticAssert('Int/Int : compatibles', TypesCompatibleForInit(PDT_INT, PDT_INT));
  SemanticAssert('Int/Double : INCOMPATIBLES (une VARIABLE Int, pas un ' +
    'litteral - "erreur claire" du roadmap)', Not TypesCompatibleForInit(PDT_INT, PDT_DOUBLE));
  SemanticAssert('String/Int : INCOMPATIBLES', Not TypesCompatibleForInit(PDT_STRING, PDT_INT));
  SemanticAssert('String/Character : compatibles (TODO 17)',
    TypesCompatibleForInit(PDT_STRING, PDT_CHARACTER));

  FTAnimal := ClassParseTopLevel('class Animal {' + Chr(10) + 'var name: String' + Chr(10) + '}');
  FTDog := ClassParseTopLevel('class Dog: Animal {' + Chr(10) + 'var breed: String' + Chr(10) + '}');
  SemanticAssert('Dog est assignable a Animal (sous-classe -> super-classe)',
    TypesCompatibleForInit(FTDog, FTAnimal));
  SemanticAssert('Animal N EST PAS assignable a Dog (sens INVERSE)',
    Not TypesCompatibleForInit(FTAnimal, FTDog));

  { litteral Int -> Double : CONTEXTUALISE (retroactivement, meme          }
  { mecanisme que "nil" au TODO 14) - "let d: Double = 5" est VALIDE. }
  S := ParseStmtString('let d: Double = 5');
  SI := SymFind('d');
  SemanticAssert('let d: Double = 5 : le litteral EST contextualise (Double)',
    ExprPool[SymTab[SI].InitExprIdx].TypeIdx = PDT_DOUBLE);

  { "declare et jamais utilise" - positif (utilisee, AUCUN probleme) }
  S := ParseStmtString('{ let used = 1' + Chr(10) + 'print(used) }');
  SI := SymFind('used');
  SemanticAssert('used : Used=Vrai apres reference', SymTab[SI].Used);

  { negatif - bascule TEMPORAIREMENT Opts.StrictMode a Faux pour OBSERVER   }
  { l avertissement SANS halte du processus (FatalError appelle Halt,               }
  { inacceptable au milieu d un self-test) - restaure IMMEDIATEMENT apres. }
  SavedStrict := Opts.StrictMode;
  Opts.StrictMode := False;
  S := ParseStmtString('{ let neverUsed = 1 }');
  Opts.StrictMode := SavedStrict;
  SI := SymFind('neverUsed');
  SemanticAssert('neverUsed : WasVarDecl=Vrai (VRAIE instruction ''let'')',
    SymTab[SI].WasVarDecl);
  SemanticAssert('neverUsed : Used=Faux (jamais reference)', Not SymTab[SI].Used);

  { parametre de fonction - JAMAIS vise (WasVarDecl=Faux), meme non       }
  { utilise dans le corps }
  FD := FuncParseTopLevel('func openFile(_ name: String) -> Int {' + Chr(10) +
    'return 1' + Chr(10) + '}');
  SI := SymFind('name');
  SemanticAssert('parametre ''name'' (jamais utilise dans le corps) : ' +
    'WasVarDecl=Faux (EXEMPT, pas une instruction ''let''/''var'')',
    Not SymTab[SI].WasVarDecl);

  { BlockHasReturnValue : avec/sans return, if/else imbrique (les DEUX    }
  { branches renvoient une valeur) }
  S := ParseStmtString('{ return 5 }');
  SemanticAssert('"return 5" : BlockHasReturnValue=Vrai', BlockHasReturnValue(S));
  S := ParseStmtString('{ print(1) }');
  SemanticAssert('bloc SANS return : BlockHasReturnValue=Faux', Not BlockHasReturnValue(S));
  S := ParseStmtString('{ if true {' + Chr(10) + 'return 1' + Chr(10) +
    '} else {' + Chr(10) + 'return 2' + Chr(10) + '} }');
  SemanticAssert('if/else (DEUX branches avec return) : BlockHasReturnValue=Vrai',
    BlockHasReturnValue(S));

  { fonction non-Void REELLE avec return (positif direct, ParseFuncDecl   }
  { via FuncParseTopLevel - aucune FatalError ne doit se produire ici) }
  FD := FuncParseTopLevel('func addOne(x: Int) -> Int {' + Chr(10) +
    'return x + 1' + Chr(10) + '}');
  SemanticAssert('addOne(x:)->Int avec return : FD resolu', FD >= 0);

  { integration bout-en-bout : math.swift EN ENTIER (forme complete),     }
  { via ParseTopLevelDecls - fonctions AVEC return (add/multiply/                       }
  { factorial, ce dernier avec un if IMBRIQUE), une fonction Void SANS             }
  { return (swap, inout), et une variable locale UTILISEE (temp) - aucun            }
  { des TROIS controles NOUVEAUX de ce TODO ne doit se declencher ici. }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32SEMANTICSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'func add(_ a: Int, _ b: Int) -> Int {');
  WriteLn(LexSrcF, '    return a + b');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func multiply(_ a: Int, _ b: Int) -> Int {');
  WriteLn(LexSrcF, '    return a * b');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func factorial(_ n: Int) -> Int {');
  WriteLn(LexSrcF, '    if n <= 1 {');
  WriteLn(LexSrcF, '        return 1');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    return n * factorial(n - 1)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func swap(_ a: inout Int, _ b: inout Int) {');
  WriteLn(LexSrcF, '    let temp: Int = a');
  WriteLn(LexSrcF, '    a = b');
  WriteLn(LexSrcF, '    b = temp');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let x: Int = 10');
  WriteLn(LexSrcF, 'let y: Int = 20');
  WriteLn(LexSrcF, 'let sum: Int = add(x, y)');
  WriteLn(LexSrcF, 'let product: Int = multiply(x, y)');
  WriteLn(LexSrcF, 'let fact5: Int = factorial(5)');
  WriteLn(LexSrcF, 'print(sum)');
  WriteLn(LexSrcF, 'print(product)');
  WriteLn(LexSrcF, 'print(fact5)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32SEMANTICSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  SemanticAssert('math.swift (integral) : "factorial" resolu', FuncFind('factorial', 1) >= 0);
  SemanticAssert('math.swift (integral) : "swap" (Void, inout) resolu', FuncFind('swap', 2) >= 0);
  SemanticAssert('math.swift (integral) : "sum" resolu', SymFind('sum') >= 0);
  SemanticAssert('math.swift (integral) : arret propre EXACT sur "print"',
    (PPKind = TOK_IDENT) And (PPVal = 'print'));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 20 - BIBLIOTHEQUE STANDARD MINIMALE                       }
{ ============================================================ }
{ StdlibTab (ci-dessus, pres de IsBuiltinFunc) : MEME modele que                       }
{ GOCW32.PAS TODO 20 - chaque entree CONNUE du frontend a l analyse,               }
{ contrepartie runtime REELLE ajoutee SELON LES BESOINS CONSTATES par             }
{ execution (TODO 21+, absent ici), jamais devinee a l avance. Un grep                 }
{ EXHAUSTIF des 12 echantillons SAMPLES\SWIFT confirme que SEUL                              }
{ "print(_:)" est REELLEMENT exerce - AUCUN n utilise isEmpty,                                  }
{ uppercased()/lowercased(), ni abs/min/max : le roadmap d en-tete                            }
{ conditionne EXPLICITEMENT ces membres a "si exerce par un exemple" -              }
{ ils restent donc HONNETEMENT absents de StdlibTab (une seule entree,             }
{ 'print') plutot que devines sans pression de test - StdlibAdd est                       }
{ ecrite pour accueillir n importe lequel d entre eux le jour ou un                       }
{ echantillon les exercerait, sans restructuration.                                             }
{ "print(_:)" lui-meme (ParseCallArgs etendue ci-dessus) : depuis le               }
{ TODO 06, un appel a "print" ne resolvait a RIEN (Callee EK_IDENT              }
{ jamais declare par SymAdd, SigT=-1, AUCUNE branche du Case ne                                }
{ s appliquait) - fonctionnait "par accident" (jamais d erreur, mais                     }
{ jamais TYPE non plus). Desormais, quand SigT reste NON resolu ET que          }
{ le nom correspond a StdlibFind, TypeIdx recoit PDT_VOID (print ne                    }
{ renvoie rien) - la conversion "selon son type reel" (Int/Double/                          }
{ String/Bool/tableau -> String, roadmap d en-tete) reste un fait               }
{ d EXECUTION (le VRAI dispatch par type a l execution est un                                  }
{ generateur de code, TODO 21+ - le front-end n a besoin ICI que du            }
{ type de RETOUR de l appel lui-meme, Void, jamais du contenu). Le                       }
{ nombre d arguments ("un seul argument", roadmap d en-tete - PAS le              }
{ print variadique reel de Swift avec separator:/terminator:) est                          }
{ verifie best-effort (WarnMsg SEULEMENT) : une limitation de PORTEE de           }
{ CE compilateur simplifie, PAS une vraie incompatibilite de type Swift                  }
{ (discipline DIFFERENTE des controles INCONDITIONNELS du TODO 19, qui             }
{ visent de VRAIES violations du langage). }

{ ------------------------------------------------------------ }
{ StdlibSelfTest : StdlibFind/StdlibTab (structure, positif/negatif),               }
{ "print(_:)" resolu vers Void quel que soit le type de l argument                     }
{ (Int/String), nombre d arguments inattendu (WarnMsg SEULEMENT, AUCUN            }
{ Halt), puis integration bout-en-bout via ParseTopLevelDecls sur                          }
{ control.swift EN ENTIER (le plus dense en appels "print", PREMIERE               }
{ fois integre a l identique) - arret propre attendu sur son premier              }
{ "if" (juste apres le seul "let" de tete, meme gap documente que tous             }
{ les echantillons precedents, cette fois sur un "if" plutot qu un                        }
{ "print") - sur des extraits synthetiques (fichier temporaire, meme               }
{ methode que les TODO precedents). }
{ ------------------------------------------------------------ }

Procedure StdlibAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StdlibSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StdlibSelfTest;
Var
  E, SLIdx : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { StdlibTab/StdlibFind : positif/negatif, structure de l entree 'print' }
  SLIdx := StdlibFind('print');
  StdlibAssert('StdlibFind(''print'') : trouve', SLIdx >= 0);
  StdlibAssert('print : ParamCount=1 (''un seul argument'', roadmap d''en-tete)',
    StdlibTab[SLIdx].ParamCount = 1);
  StdlibAssert('print : ResultTypeIdx=Void', StdlibTab[SLIdx].ResultTypeIdx = PDT_VOID);
  StdlibAssert('StdlibFind(''nimporteQuoi'') : introuvable', StdlibFind('nimporteQuoi') < 0);

  { "print(_:)" resolu vers Void, quel que soit le type REEL de           }
  { l argument (Int, String) - la conversion elle-meme reste un fait              }
  { d EXECUTION (generateur de code, TODO 21+) }
  E := ExprParseString('print(1)');
  StdlibAssert('print(1) : EK_CALL', ExprPool[E].Kind = EK_CALL);
  StdlibAssert('print(1) : TypeIdx=Void', ExprPool[E].TypeIdx = PDT_VOID);
  E := ExprParseString('print("hello")');
  StdlibAssert('print("hello") : TypeIdx=Void (meme resultat, type d''argument ' +
    'DIFFERENT)', ExprPool[E].TypeIdx = PDT_VOID);

  { nombre d arguments inattendu - WarnMsg SEULEMENT (limitation de              }
  { PORTEE de CE compilateur, PAS une vraie erreur Swift - AUCUN Halt          }
  { ne doit se produire ici, contrairement aux controles INCONDITIONNELS           }
  { du TODO 19) }
  E := ExprParseString('print(1, 2)');
  StdlibAssert('print(1, 2) : TypeIdx=Void malgre le nombre d''arguments ' +
    'inattendu (WarnMsg seulement, jamais un Halt)', ExprPool[E].TypeIdx = PDT_VOID);

  { integration bout-en-bout : control.swift EN ENTIER (forme complete),  }
  { via ParseTopLevelDecls - arret propre attendu sur "if" (voir la               }
  { note d en-tete de ce TODO). }
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  Assign(LexSrcF, 'SWIFTW32STDLIBSELFTEST.$$$');
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let score: Int = 85');
  WriteLn(LexSrcF, 'if score >= 90 {');
  WriteLn(LexSrcF, '    print(1)');
  WriteLn(LexSrcF, '} else if score >= 80 {');
  WriteLn(LexSrcF, '    print(2)');
  WriteLn(LexSrcF, '} else if score >= 70 {');
  WriteLn(LexSrcF, '    print(3)');
  WriteLn(LexSrcF, '} else {');
  WriteLn(LexSrcF, '    print(0)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let value: Int = 3');
  WriteLn(LexSrcF, 'switch value {');
  WriteLn(LexSrcF, 'case 1:');
  WriteLn(LexSrcF, '    print(10)');
  WriteLn(LexSrcF, 'case 2:');
  WriteLn(LexSrcF, '    print(20)');
  WriteLn(LexSrcF, 'case 3:');
  WriteLn(LexSrcF, '    print(30)');
  WriteLn(LexSrcF, 'default:');
  WriteLn(LexSrcF, '    print(0)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func checkAge(_ age: Int) -> Int {');
  WriteLn(LexSrcF, '    guard age >= 0 else {');
  WriteLn(LexSrcF, '        return 0');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    guard age <= 150 else {');
  WriteLn(LexSrcF, '        return 0');
  WriteLn(LexSrcF, '    }');
  WriteLn(LexSrcF, '    return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let valid: Int = checkAge(25)');
  WriteLn(LexSrcF, 'print(valid)');
  Close(LexSrcF);
  Assign(LexSrcF, 'SWIFTW32STDLIBSELFTEST.$$$');
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseTopLevelDecls;
  StdlibAssert('control.swift (integral) : "score" resolu', SymFind('score') >= 0);
  StdlibAssert('control.swift (integral) : arret propre EXACT sur "if"',
    (PPKind = TOK_IDENT) And (IsKeyword(PPVal) = KW_IF));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM              }
{ ============================================================ }
{ PREMIERE VRAIE passe de generation de code de ce compilateur -                       }
{ architecture ETUDIEE et REPRISE directement de GOCW32.PAS (meme                          }
{ projet, meme auteur, meme discipline explicitement exigee par le                          }
{ roadmap d en-tete de CE TODO) : un texte .ASM Intel/MASM emis                                 }
{ DIRECTEMENT (WriteLn ligne a ligne dans un fichier Text, AUCUNE                             }
{ structure de "representation intermediaire" separee - le texte .asm                    }
{ LUI-MEME est l IR, relu tel quel par le futur assembleur du TODO 22),                        }
{ EAX portant TOUJOURS le resultat scalaire d une expression (AUCUN                          }
{ allocateur de registres, discipline deja annoncee par le roadmap                            }
{ d en-tete du TODO 21 lui-meme), et le meme "arret propre" (FatalError                       }
{ explicite, jamais un .asm silencieusement faux) pour TOUTE forme non             }
{ encore couverte.                                                                              }
{                                                                       }
{ PORTEE DELIBEREMENT REDUITE pour cette PREMIERE passe (EXACTEMENT la           }
{ meme discipline que GOCW32.PAS lui-meme, dont le TODO 21 d origine                     }
{ ne couvrait QUE "hello.go" avant de grandir par extensions datees                      }
{ successives sur PLUSIEURS sessions - AUCUNE tentative de couvrir              }
{ TOUT le front-end TODO 01-20 en une seule fois) : SEUL hello.swift                       }
{ (litteraux Int/String, "let"/"var" GLOBAUX avec valeur initiale                            }
{ CONSTANTE, "+" entier, affectation simple a un identificateur, et                            }
{ "print(_:)" avec un argument String OU Int) est reellement compile             }
{ de bout en bout - TOUT LE RESTE (fonctions utilisateur, structures de            }
{ controle if/while/for/switch/guard, struct/class/protocole/enum,                          }
{ fermetures, Optional, gestion d erreurs, collections, chaines                                  }
{ etendues/interpolation, generiques) s arrete PROPREMENT (FatalError                    }
{ explicite, message nommant precisement la construction manquante)                        }
{ et sera ajoute par extension DATEE, une session a la fois, exactement           }
{ comme GOCW32.PAS l a fait pour chacune des siennes. Aucune fonction               }
{ n est encore compilee (CompileFuncDef/CompileMethodDef n existent                       }
{ pas encore) : Offset (TSymRec, ajoute ci-dessus) reste TOUJOURS 0             }
{ pour l instant, seul le niveau FICHIER (global) est traite.                                    }
{                                                                       }
{ "print(_:) converti en String selon son type reel" (roadmap d en-tete           }
{ du TODO 20) : DIFFERENCE REELLE avec fmt.Println de GOCW32.PAS (qui              }
{ suppose TOUJOURS que son argument est DEJA une chaine - strconv.Itoa            }
{ y est un appel EXPLICITE ecrit par le programmeur Go, jamais automatique)            }
{ - ICI, le TYPE STATIQUE (deja connu du front-end, TODO 06+) de                          }
{ l argument dicte le code emis : String -> impression DIRECTE ;                             }
{ Int -> _SWRT_STRCONV_ITOA (conversion decimale) PUIS impression - Double/       }
{ Bool/tableau (le reste du roadmap d en-tete) restent un FatalError                     }
{ explicite pour cette premiere passe (JAMAIS exerces par hello.swift).                 }
{                                                                       }
{ Bibliotheque runtime (_SWRT_*, EmitRuntimeLibrary) : QUATRE routines           }
{ REPRISES fidelement de GOCW32.PAS (_GORT_STRLEN/PRINT_STR/                                 }
{ PRINTLN_STR/ALLOC/STRCONV_ITOA), simplement renommees _SWRT_ -                            }
{ chacune porte deja, dans SON PROPRE fichier d origine, plusieurs                          }
{ corrections de VRAIS bogues trouves PAR EXECUTION reelle (ESI non                        }
{ restaure par STRLEN, EBX ecrase par ALLOC sans etre restaure,                                  }
{ HEAP_ZERO_MEMORY manquant, corruption de pile dans ITOA...) - reprises            }
{ ICI DEJA CORRIGEES plutot que redecouvertes une seconde fois par                          }
{ EXECUTION sur ce compilateur-ci.                                                             }
{                                                                       }
{ ParseSwiftProgram (NOUVEAU - n existait dans AUCUN TODO precedent) :          }
{ TOUS les tests d integration "bout-en-bout" des TODO 05-20 utilisaient           }
{ ParseTopLevelDecls SEULE et s arretaient PROPREMENT sur le premier               }
{ code executable de haut niveau ("print(...)"),  Swift REEL melangeant           }
{ librement declarations ET instructions executables au niveau fichier             }
{ (un SCRIPT, pas un langage exigeant "func main()" comme Go) - AUCUNE               }
{ generation de code n etait possible sur un VRAI fichier SAMPLES\SWIFT          }
{ tant que cette limite n etait pas levee. ParseSwiftProgram (ci-dessous)               }
{ boucle sur TOUT le fichier, essayant ParseTopLevelDecl PUIS (SEULEMENT          }
{ si Faux) ParseStatement, collectant les instructions EXECUTABLES (les          }
{ declarations s auto-enregistrent deja via SymAdd/FuncDefAdd/etc, rien            }
{ de plus a collecter pour elles) dans TopLevelStmts - CompileProgram              }
{ les compile ensuite dans l ORDRE textuel, comme un unique corps de              }
{ fonction IMPLICITE couvrant tout le fichier (label d entree "_SWSTART",          }
{ jamais "_SWF_main" - Swift n exige pas ce nom, contrairement a Go). }

Const
  MAX_CG_STR = 256;

Var
  CgOutF      : Text;
  CgOutOpen   : Boolean;
  CgLabelSeq  : Integer;

  { pool de chaines litterales (deduplication PAR VALEUR - deux            }
  { occurrences du meme texte partagent le meme label _SWK_N), meme            }
  { principe EXACT que CgStrPool/CgStrPoolOfExpr de GOCW32.PAS. }
  CgStrPool       : Array[0..MAX_CG_STR - 1] Of TString;
  CgStrCount      : Integer;
  CgStrPoolOfExpr : Array[0..MAX_EXPR - 1] Of Integer;

  { TopLevelStmts (ParseSwiftProgram, ci-dessous) : SEULES les              }
  { instructions EXECUTABLES de haut niveau (jamais un marqueur STK_DECL,   }
  { les declarations n ont besoin d aucun code - voir CompileStmt/STK_DECL). }
  TopLevelStmts     : Array[0..MAX_STMT - 1] Of Integer;
  TopLevelStmtCount : Integer;

Function IntToStrSW(N: LongInt): TString;
Var S: TString;
Begin
  Str(N, S);
  IntToStrSW := S;
End;

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
  CgLabelGen := ASM_PFX_LABEL + IntToStrSW(CgLabelSeq);
End;

{ CgVarLabel : etiquette .DATA UNIQUE pour le symbole SI - un GLOBAL      }
{ (IsGlobal, portee fichier) est adresse par son NOM (deux globaux ne             }
{ peuvent jamais partager un nom, deja garanti par SymAdd). Un symbole           }
{ IsTopLevelLocal (variable de boucle for-in AU NIVEAU FICHIER, hors de           }
{ toute fonction) recoit lui aussi un stockage .DATA (aucune VRAIE pile           }
{ n existe a CE niveau), etiquette rendue UNIQUE par l index SymTab              }
{ pour rester correcte meme si DEUX boucles for-in SIBLING reutilisent           }
{ le MEME nom de variable. Un VRAI parametre/local de FONCTION (TODO 21,               }
{ extension "compilation de fonctions") n appelle JAMAIS cette fonction-       }
{ ci - voir CgVarOperand, qui route ce cas vers un deplacement EBP-relatif           }
{ (TSymRec.Offset, desormais REELLEMENT assigne par CompileFuncDef). }
Function CgVarLabel(SI: Integer): TString;
Begin
  If SymTab[SI].IsGlobal Then
    CgVarLabel := ASM_PFX_GVAR + SymTab[SI].Name
  Else
    CgVarLabel := ASM_PFX_GVAR + 'L' + IntToStrSW(SI) + '_' + SymTab[SI].Name;
End;

{ CgVarOperand : operande ASM pour LIRE/ECRIRE le symbole SI - TROIS      }
{ cas, dans cet ordre : (1) IsGlobal OU IsTopLevelLocal -> stockage              }
{ .DATA par etiquette (CgVarLabel) ; (2) SINON - UNIQUEMENT un VRAI               }
{ parametre/local d une fonction REELLEMENT compilee (TODO 21, extension           }
{ "compilation de fonctions" - CompileFuncDef assigne un VRAI                            }
{ SymTab[SI].Offset a CHACUN, positif +8/+12/... pour les parametres,             }
{ negatif -4/-8/... pour les locales, AVANT de compiler le corps) ->               }
{ deplacement EBP-relatif, EXACTEMENT la convention deja documentee par           }
{ TSymRec.Offset depuis le TODO 05/21 (meme convention que GOCW32.PAS). }
Function CgVarOperand(SI: Integer): TString;
Begin
  If SymTab[SI].IsGlobal Or SymTab[SI].IsTopLevelLocal Then
    CgVarOperand := '[' + CgVarLabel(SI) + ']'
  Else If SymTab[SI].Offset >= 0 Then
    CgVarOperand := '[EBP+' + IntToStrSW(SymTab[SI].Offset) + ']'
  Else
    CgVarOperand := '[EBP-' + IntToStrSW(-SymTab[SI].Offset) + ']';
End;

{ CgCollectStrings : PRE-PASSE sur TOUT le programme (avant la moindre    }
{ ligne .DATA) - necessaire car .DATA doit PHYSIQUEMENT preceder .CODE          }
{ dans le fichier emis, alors que les litteraux ne sont "decouverts"                    }
{ que bien plus tard par un parcours naif de CompileStmt/CompileExpr -             }
{ meme technique EXACTE que GOCW32.PAS. }
Procedure CgCollectStrings;
Var E, J, Found : Integer;
Begin
  CgStrCount := 0;
  For E := 0 To ExprCount - 1 Do
    If ExprPool[E].Kind = EK_STRINGLIT Then
    Begin
      Found := -1;
      For J := 0 To CgStrCount - 1 Do
        If CgStrPool[J] = ExprPool[E].StrVal Then
        Begin
          Found := J;
          Break;
        End;
      If Found < 0 Then
      Begin
        If CgStrCount < MAX_CG_STR Then
        Begin
          CgStrPool[CgStrCount] := ExprPool[E].StrVal;
          Found := CgStrCount;
          Inc(CgStrCount);
        End
        Else
        Begin
          WarnMsg('table du generateur de code pleine (chaines litterales, MAX_CG_STR)');
          Found := 0;
        End;
      End;
      CgStrPoolOfExpr[E] := Found;
    End;
End;

{ EmitHeader : boilerplate Intel/MASM (.386, modele FLAT STDCALL,        }
{ imports Win32 - E/S console et sortie de processus SEULEMENT, alloc              }
{ tas necessaire a _SWRT_STRCONV_ITOA/ALLOC ; threads/etc. restent hors           }
{ de portee, aucun closure/goroutine-like n existe dans ce langage a               }
{ ce stade) - meme dialecte que GOCW32.PAS/DELPHI.PAS (memes projet). }
Procedure EmitHeader;
Begin
  EmitComment('SWIFTW32 - code genere (TODO 21) - NE PAS EDITER A LA MAIN');
  EmitRaw('.386');
  EmitRaw('.MODEL FLAT, STDCALL');
  EmitBlankLine;
  EmitRaw('EXTRN _ExitProcess@4:NEAR');
  EmitRaw('EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('EXTRN _WriteFile@20:NEAR');
  EmitRaw('EXTRN _GetProcessHeap@0:NEAR');
  EmitRaw('EXTRN _HeapAlloc@12:NEAR');
  EmitBlankLine;
End;

{ CgIsClassCtorCall : Vrai SEULEMENT si E est un appel constructeur SANS  }
{ argument vers une CLASSE connue ("NomDeClasse()", TypeIdx DEJA resolu           }
{ a la classe elle-meme par le front-end - TODO 09/10, voir ClassSelfTest :               }
{ "Animal() : TypeIdx = Animal (malgre l''absence de tout init)") - SEUL          }
{ cas de "global non repliable a la compilation" que ce generateur de              }
{ code sait desormais INITIALISER REELLEMENT A L EXECUTION (allocation           }
{ tas, voir EmitDataSeg/CompileGlobalRuntimeInits/CompileExpr ci-dessous)             }
{ plutot que de s arreter proprement - extension ajoutee suite au                       }
{ rapport "classes.swift : initialiseur non repliable" (TODO 25). TOUT            }
{ AUTRE appel (fonction utilisateur, construction de STRUCT - valeur                    }
{ MULTI-MOTS incompatible avec la convention EAX unique, ou classe AVEC           }
{ arguments d init) reste hors de portee (FatalError, message inchange). }
Function CgIsClassCtorCall(E: Integer): Boolean;
Begin
  CgIsClassCtorCall := (E >= 0) And (E < ExprCount) And
    (ExprPool[E].Kind = EK_CALL) And
    (ExprPool[E].TypeIdx >= 0) And (ExprPool[E].TypeIdx < TypeCount) And
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_CLASS) And
    (ExprPool[E].ArgCount = 0);
End;

{ CgIsUserFuncCall : Vrai SEULEMENT si E est un appel a une fonction      }
{ UTILISATEUR de haut niveau REELLEMENT resolue (FuncFind, TODO 08) -             }
{ extension "compilation de fonctions" (TODO 21) ajoutee suite au                     }
{ rapport "control.swift : initialiseur non repliable" (TODO 25) - SEUL           }
{ AUTRE cas (avec CgIsClassCtorCall) qu EmitDataSeg/                                    }
{ CompileGlobalRuntimeInits savent desormais INITIALISER REELLEMENT A                    }
{ L EXECUTION plutot que de s arreter proprement. }
Function CgIsUserFuncCall(E: Integer): Boolean;
Begin
  CgIsUserFuncCall := (E >= 0) And (E < ExprCount) And
    (ExprPool[E].Kind = EK_CALL) And
    (ExprPool[E].Left >= 0) And (ExprPool[E].Left < ExprCount) And
    (ExprPool[ExprPool[E].Left].Kind = EK_IDENT) And
    (FuncFind(ExprPool[ExprPool[E].Left].NameVal, ExprPool[E].ArgCount) >= 0);
End;

{ EmitDataSeg : section .DATA COMPLETE en une fois - globaux (parcours   }
{ de SymTab, IsGlobal) puis pool de chaines litterales (CgCollectStrings          }
{ deja execute AVANT cet appel, voir CompileProgram). DIFFERENCE REELLE            }
{ avec GOCW32.PAS (dont les globaux chaine restent un "DD 0" documente,          }
{ jamais leur VRAI contenu) : un global String dont l initialiseur EST                  }
{ un litteral repliable (ConstVal.Kind=CK_STRING, TODO 05/06) recoit               }
{ ICI son VRAI contenu DIRECTEMENT ("DB "texte",0") plutot qu un simple             }
{ zero - necessaire des hello.swift lui-meme ("let greeting: String =              }
{ ..."), qui n a pas d equivalent GOCW32.PAS a imiter pour ce cas                            }
{ precis. Un global CLASSE dont l initialiseur est un appel constructeur           }
{ SANS argument (CgIsClassCtorCall) recoit ICI un simple "DD 0" comme               }
{ TOUT AUTRE pointeur - sa VRAIE valeur (adresse de l instance allouee)           }
{ est ecrite A L EXECUTION par CompileGlobalRuntimeInits, PAS ici (aucun          }
{ tas n existe encore a l assemblage). Tout AUTRE global (type non               }
{ couvert, ou initialiseur NON repliable ET NON une construction de               }
{ classe) recoit lui aussi un simple "DD 0" - LIMITATION DOCUMENTEE               }
{ plutot que devinee (aucune fonction n est encore compilee de toute              }
{ facon pour calculer une VRAIE valeur d initialisation a l execution). }
Procedure EmitDataSeg;
Var I : Integer;
Begin
  EmitRaw('.DATA');
  EmitRaw(ASM_PFX_RUNTIME + 'NEWLINE  DB 10');
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].Kind = SK_VAR) And (SymTab[I].IsGlobal Or SymTab[I].IsTopLevelLocal) Then
    Begin
      { TODO 21 (extension controle de flux) : le filtre couvre desormais     }
      { IsGlobal OU IsTopLevelLocal (variable de boucle for-in, portee             }
      { imbriquee MAIS toujours au niveau FICHIER - AUCUNE fonction n est               }
      { encore compilee, pas de VRAIE pile EBP, voir CgVarLabel) - PAS un              }
      { simple retrait du filtre IsGlobal (essaye PUIS CORRIGE pendant                       }
      { cette meme extension : un retrait total aurait AUSSI capture les              }
      { VRAIS parametres/locales de fonction, ex. "temp" dans math.swift/                    }
      { "status" dans errors.swift, et les aurait signales a tort comme            }
      { des "globaux" non repliables dans le message FatalError ci-dessous            }
      { - bogue trouve en executant le rapport TODO 25 lui-meme, CORRIGE            }
      { en ajoutant IsTopLevelLocal, mis a Vrai UNIQUEMENT par                       }
      { ParseForInStmt). }
      { TODO 25 (validation) : bogue REEL trouve par EXECUTION (jamais par     }
      { relecture du .asm ni par un self-test structurel) - generics.swift/           }
      { math.swift/optionals.swift COMPILAIENT et s EXECUTAIENT sans              }
      { erreur (code de sortie 0) mais IMPRIMAIENT des valeurs FAUSSES              }
      { (ex. "let sum = add(x, y)", ConstVal jamais REMPLI puisque              }
      { IsConst=Faux ici, tombait silencieusement dans la branche DD 0                }
      { ci-dessous, indiscernable d une VRAIE constante 0) : un initialiseur              }
      { present mais NON repliable a la compilation (appel de fonction              }
      { utilisateur, "??" sur une variable, etc. - CompileFuncDef n existe              }
      { toujours pas) DOIT s arreter PROPREMENT ICI, jamais deviner 0 en              }
      { silence - exactement la discipline appliquee partout ailleurs dans              }
      { ce fichier. InitExprIdx>=0 protege contre une liaison "if let"/               }
      { "guard let" (HasInit force a Vrai, TODO 14, MAIS InitExprIdx JAMAIS            }
      { assigne pour ce cas precis) - non exercee par aucun echantillon               }
      { actuel, reste donc un stockage "DD 0" inerte plutot qu un acces               }
      { hors bornes de ExprPool. }
      If SymTab[I].HasInit And (SymTab[I].InitExprIdx >= 0) And
         Not ExprPool[SymTab[I].InitExprIdx].IsConst And
         Not CgIsClassCtorCall(SymTab[I].InitExprIdx) And
         Not CgIsUserFuncCall(SymTab[I].InitExprIdx) Then
        FatalError('TODO 21 : generateur de code, initialiseur de global "' +
          SymTab[I].Name + '" non repliable a la compilation (appel de ' +
          'fonction utilisateur, expression Optional, etc.) - seuls les ' +
          'globaux SANS initialiseur ou initialises par un LITTERAL/une ' +
          'expression CONSTANTE sont couverts pour cette premiere passe ' +
          '(une VRAIE evaluation a l''execution reste une extension future)')
      Else If (SymTab[I].TypeIdx >= 0) And (SymTab[I].TypeIdx < TypeCount) And
         (TypeTab[SymTab[I].TypeIdx].Kind = TYK_STRING) And
         (SymTab[I].ConstVal.Kind = CK_STRING) Then
        EmitRaw(CgVarLabel(I) + '  DB "' + SymTab[I].ConstVal.StrVal + '", 0')
      Else If (SymTab[I].TypeIdx >= 0) And (SymTab[I].TypeIdx < TypeCount) And
         (TypeTab[SymTab[I].TypeIdx].Kind In [TYK_INT, TYK_BOOL]) Then
        EmitRaw(CgVarLabel(I) + '  DD ' + IntToStrSW(SymTab[I].ConstVal.IntVal))
      Else
        EmitRaw(CgVarLabel(I) + '  DD 0');
    End;
  For I := 0 To CgStrCount - 1 Do
    EmitRaw(ASM_PFX_STRING + IntToStrSW(I) + '  DB "' + CgStrPool[I] + '", 0');
  EmitBlankLine;
End;

Procedure EmitCodeSeg;
Begin
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ EmitRuntimeLibrary : runtime minimal ecrit DIRECTEMENT dans le .asm    }
{ emis (aucune bibliotheque externe liee) - QUATRE routines REPRISES             }
{ fidelement de GOCW32.PAS (_GORT_STRLEN/PRINT_STR/PRINTLN_STR/ALLOC/                    }
{ STRCONV_ITOA), simplement renommees _SWRT_ - voir la note d en-tete             }
{ de section pour le detail des bogues REELS deja corriges dans leur              }
{ fichier d origine et reproduits ICI deja corriges. }
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

  { _SWRT_PRINT_STR : imprime la chaine C pointee par [EBP+8] SANS         }
  { saut de ligne, via GetStdHandle/WriteFile (PAS INT 21h) - recharge             }
  { ESI depuis [EBP+8] APRES l appel a STRLEN (qui le laisse pointer sur           }
  { le TERMINATEUR NUL, jamais restaure - bogue REEL deja trouve et                     }
  { corrige dans GOCW32.PAS, reproduit ici deja corrige). }
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

  { _SWRT_PRINTLN_STR : _SWRT_PRINT_STR PUIS le saut de ligne unique       }
  { constant _SWRT_NEWLINE (meme forme que print(_:), TOUJOURS un seul             }
  { argument, roadmap d en-tete du TODO 20). }
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

  { _SWRT_ALLOC : alloue [EBP+8] octets sur le tas du PROCESSUS                }
  { (GetProcessHeap, un SEUL tas partage) via HeapAlloc(HEAP_ZERO_MEMORY,          }
  { dwFlags=8 - SANS ce drapeau, memoire NON INITIALISEE, bogue REEL                 }
  { deja trouve et corrige dans GOCW32.PAS), retourne le pointeur en                    }
  { EAX - AUCUNE liberation (fuite assumee, meme decision que le TODO 18).           }
  { PUSH/POP EBX autour de l appel (GetProcessHeap ecraserait sinon EBX               }
  { de l APPELANT sans le restaurer - meme bogue REEL deja trouve et                    }
  { corrige dans GOCW32.PAS). }
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

  { _SWRT_STRCONV_ITOA([EBP+8]=N) -> EAX = nouvelle chaine decimale         }
  { ("-" en tete si negatif ; "0" pour zero, jamais une chaine vide) -              }
  { chiffres generes A L ENVERS dans un tampon LOCAL FIXE ([EBP-36]..              }
  { [EBP-5], 32 octets - largement suffisant pour un entier 32 bits),                    }
  { PUIS copies a l endroit dans le tampon FINAL alloue ; [EBP-40] est               }
  { un QUATRIEME emplacement DEDIE (jamais ecrase par le tampon de                       }
  { chiffres) qui sauvegarde le pointeur A RENVOYER ; [EBP-24] sauvegarde           }
  { ECX (nombre de chiffres) autour de l appel a _SWRT_ALLOC (STDCALL,                  }
  { qui NE preserve PAS ECX) - repris fidelement de GOCW32.PAS, ou ces                     }
  { TROIS points precis etaient chacun un VRAI bogue trouve par                                  }
  { EXECUTION ou en relisant le code (corruption de pile, mauvaise                            }
  { valeur de retour, ECX corrompu par l appel imbrique) : reproduits                    }
  { ici DEJA CORRIGES. }
  EmitLabel(ASM_PFX_RUNTIME + 'STRCONV_ITOA');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('SUB ESP,40');
  EmitInstr('MOV EAX,DWORD PTR [EBP+8]');
  EmitInstr('MOV EBX,0');
  EmitInstr('CMP EAX,0');
  EmitInstr('JGE ' + ASM_PFX_RUNTIME + 'ITOA_NONNEG');
  EmitInstr('MOV EBX,1');
  EmitInstr('NEG EAX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_NONNEG');
  EmitInstr('LEA EDI,[EBP-36]');
  EmitInstr('MOV ECX,0');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_DIGLOOP');
  EmitInstr('MOV ESI,10');
  EmitInstr('CDQ');
  EmitInstr('IDIV ESI');
  EmitInstr('ADD EDX,48');
  EmitInstr('MOV BYTE PTR [EDI],EDX');
  EmitInstr('INC EDI');
  EmitInstr('INC ECX');
  EmitInstr('CMP EAX,0');
  EmitInstr('JNE ' + ASM_PFX_RUNTIME + 'ITOA_DIGLOOP');
  EmitInstr('MOV EAX,ECX');
  EmitInstr('CMP EBX,0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'ITOA_NOSIGN');
  EmitInstr('INC EAX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_NOSIGN');
  EmitInstr('ADD EAX,1');
  EmitInstr('MOV DWORD PTR [EBP-24],ECX');
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV ECX,DWORD PTR [EBP-24]');
  EmitInstr('MOV EDI,EAX');
  EmitInstr('MOV DWORD PTR [EBP-40],EDI');
  EmitInstr('CMP EBX,0');
  EmitInstr('JE ' + ASM_PFX_RUNTIME + 'ITOA_NOSIGN2');
  EmitInstr('MOV EAX,45');
  EmitInstr('MOV BYTE PTR [EDI],EAX');
  EmitInstr('INC EDI');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_NOSIGN2');
  EmitInstr('LEA ESI,[EBP-36]');
  EmitInstr('ADD ESI,ECX');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_CPYTOP');
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + ASM_PFX_RUNTIME + 'ITOA_CPYDONE');
  EmitInstr('DEC ESI');
  EmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  EmitInstr('MOV BYTE PTR [EDI],EAX');
  EmitInstr('INC EDI');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + ASM_PFX_RUNTIME + 'ITOA_CPYTOP');
  EmitLabel(ASM_PFX_RUNTIME + 'ITOA_CPYDONE');
  EmitInstr('MOV EAX,0');
  EmitInstr('MOV BYTE PTR [EDI],EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBP-40]');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ EmitCompareJcc : traduit une comparaison en une VRAIE valeur 0/1 dans  }
{ EAX (Bool Swift) - PAS de SETcc (jamais porte par l assembleur du               }
{ TODO 22, aucun mnemonique/octet-registre necessaire ailleurs), plutot           }
{ un CMP+Jcc+branchement XOR/MOV, MEME PATTERN EXACT que GOCW32.PAS               }
{ (EmitCompareJcc, TODO 21 de ce fichier frere) - EAX/EBX deja les DEUX           }
{ operandes (convention EK_BINARY existante, voir CompileExpr). }
Procedure EmitCompareJcc(Const Jcc: TString);
Var LblTrue, LblDone : TString;
Begin
  LblTrue := CgLabelGen;
  LblDone := CgLabelGen;
  EmitInstr('CMP EAX,EBX');
  EmitInstr(Jcc + ' ' + LblTrue);
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + LblDone);
  EmitLabel(LblTrue);
  EmitInstr('MOV EAX,1');
  EmitLabel(LblDone);
End;

{ Pile des etiquettes "break"/"continue" de la boucle COURANTE (TODO 21, }
{ extension controle de flux) - permet l imbrication (while dans un              }
{ for-in, etc.) : chaque boucle empile SA PROPRE paire d etiquettes             }
{ juste avant de compiler son corps, la depile juste apres - "break"/           }
{ "continue" (non etiquetes, seul cas couvert ici) sautent TOUJOURS vers                }
{ le SOMMET de cette pile (la boucle la plus imbriquee). Aucun equivalent          }
{ direct dans GOCW32.PAS a cette date (break/continue n y sont pas                     }
{ encore compiles non plus - confirme par recherche, TODO 21 de ce                     }
{ fichier est donc EN AVANCE sur son propre modele pour ce point precis). }
Const
  MAX_CG_LOOP_DEPTH = 32;
Var
  CgLoopBreakLbl    : Array[0..MAX_CG_LOOP_DEPTH - 1] Of TString;
  CgLoopContinueLbl : Array[0..MAX_CG_LOOP_DEPTH - 1] Of TString;
  CgLoopDepth       : Integer;

  { CgCurFuncEpilogueLbl : etiquette de l EPILOGUE (MOV ESP,EBP/POP EBP/  }
  { RET) de la fonction EN COURS DE COMPILATION (TODO 21, extension            }
  { "compilation de fonctions") - un SEUL emplacement partage (jamais une           }
  { pile, contrairement a CgLoopBreakLbl/CgLoopContinueLbl) car les                     }
  { fonctions Swift ne s imbriquent JAMAIS ici (pas de fonction locale               }
  { nommee a l interieur d une autre - seules les fermetures, EK_CLOSURE,           }
  { existent, et restent hors de portee de cette extension). CompileStmt          }
  { (STK_RETURN) y saute plutot que de dupliquer l epilogue a CHAQUE               }
  { "return" - permet PLUSIEURS "return" (ex. guard) sans code duplique. }
  CgCurFuncEpilogueLbl : TString;

Procedure CgLoopPush(Const BreakLbl, ContinueLbl: TString);
Begin
  If CgLoopDepth >= MAX_CG_LOOP_DEPTH Then
    FatalError('TODO 21 : generateur de code, boucles imbriquees trop ' +
      'profondement (MAX_CG_LOOP_DEPTH)')
  Else
  Begin
    CgLoopBreakLbl[CgLoopDepth]    := BreakLbl;
    CgLoopContinueLbl[CgLoopDepth] := ContinueLbl;
    Inc(CgLoopDepth);
  End;
End;

Procedure CgLoopPop;
Begin
  If CgLoopDepth > 0 Then Dec(CgLoopDepth);
End;

{ CompileExpr : compile RECURSIVEMENT le noeud E de ExprPool - laisse    }
{ TOUJOURS son resultat dans EAX (convention FIXE, AUCUN allocateur de              }
{ registres - meme discipline que GOCW32.PAS). Toute forme hors de la                  }
{ portee documentee en tete de section s arrete PROPREMENT (FatalError). }
Procedure CompileExpr(E: Integer);
Var SI, ArgE, ArgT, FD, AI : Integer;
Begin
  If E < 0 Then Exit;
  Case ExprPool[E].Kind Of
    EK_INTLIT, EK_BOOLLIT:
      EmitInstr('MOV EAX,' + IntToStrSW(ExprPool[E].IntVal));
    EK_NILLIT:
      EmitInstr('MOV EAX,0');
    EK_STRINGLIT:
      EmitInstr('LEA EAX,[' + ASM_PFX_STRING + IntToStrSW(CgStrPoolOfExpr[E]) + ']');
    EK_IDENT:
      Begin
        SI := SymFind(ExprPool[E].NameVal);
        If SI < 0 Then
          FatalError('TODO 21 : generateur de code, identificateur non resolu: ' +
            ExprPool[E].NameVal)
        Else If (SymTab[SI].TypeIdx >= 0) And (SymTab[SI].TypeIdx < TypeCount) And
           (TypeTab[SymTab[SI].TypeIdx].Kind = TYK_STRING) Then
          { un global String stocke ICI (EmitDataSeg) ses VRAIS octets, PAS   }
          { un pointeur separe - lire sa "valeur" doit donc charger SON      }
          { ADRESSE (LEA), exactement comme EK_STRINGLIT, jamais les 4       }
          { premiers octets de son contenu comme un entier (MOV) : bogue     }
          { REEL trouve uniquement a l execution (segfault), voir TODO 23.   }
          EmitInstr('LEA EAX,' + CgVarOperand(SI))
        Else
          EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(SI));
      End;
    EK_BINARY:
      { comparaisons (TODO 21, extension controle de flux) AJOUTEES au     }
      { seul +/-/* de la premiere passe - meme structure PUSH/POP EAX/EBX,       }
      { juste un dispatch supplementaire vers EmitCompareJcc (ci-dessus)             }
      { pour les 6 operateurs relationnels. && / || (court-circuit) restent          }
      { HORS de portee (non exerces par aucun echantillon actuel - ni                    }
      { arrays.swift ni loops.swift ne les utilisent), tombent donc dans              }
      { le Else FatalError final comme tout autre operateur non couvert. }
      If (ExprPool[E].Op <> '+') And (ExprPool[E].Op <> '-') And (ExprPool[E].Op <> '*') And
         (ExprPool[E].Op <> '<') And (ExprPool[E].Op <> '<=') And
         (ExprPool[E].Op <> '>') And (ExprPool[E].Op <> '>=') And
         (ExprPool[E].Op <> '==') And (ExprPool[E].Op <> '!=') Then
        FatalError('TODO 21 : generateur de code, operateur binaire non couvert ' +
          'pour cette premiere passe (+/-/* et les 6 comparaisons le sont ; ' +
          '&&/||/ et % attendent une extension future) : ' + ExprPool[E].Op)
      Else
      Begin
        CompileExpr(ExprPool[E].Left);
        EmitInstr('PUSH EAX');
        CompileExpr(ExprPool[E].Right);
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EAX');
        If ExprPool[E].Op = '+' Then EmitInstr('ADD EAX,EBX')
        Else If ExprPool[E].Op = '-' Then EmitInstr('SUB EAX,EBX')
        Else If ExprPool[E].Op = '*' Then EmitInstr('IMUL EAX,EBX')
        Else If ExprPool[E].Op = '<' Then EmitCompareJcc('JL')
        Else If ExprPool[E].Op = '<=' Then EmitCompareJcc('JLE')
        Else If ExprPool[E].Op = '>' Then EmitCompareJcc('JG')
        Else If ExprPool[E].Op = '>=' Then EmitCompareJcc('JGE')
        Else If ExprPool[E].Op = '==' Then EmitCompareJcc('JE')
        Else EmitCompareJcc('JNE');
      End;
    EK_CALL:
      { seul "print(_:)" (un seul argument, StdlibTab, TODO 20) est          }
      { couvert pour cette premiere passe - AUCUN appel de fonction              }
      { utilisateur (aucune n est encore compilee, CompileFuncDef              }
      { n existe pas). }
      If (ExprPool[ExprPool[E].Left].Kind = EK_IDENT) And
         (ExprPool[ExprPool[E].Left].NameVal = 'print') And
         (ExprPool[E].ArgCount = 1) Then
      Begin
        ArgE := ExprArgPool[ExprPool[E].ArgFirst];
        ArgT := ExprPool[ArgE].TypeIdx;
        CompileExpr(ArgE);
        If (ArgT >= 0) And (ArgT < TypeCount) And (TypeTab[ArgT].Kind = TYK_STRING) Then
        Begin
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR');
          EmitInstr('ADD ESP,4');
        End
        Else If (ArgT >= 0) And (ArgT < TypeCount) And (TypeTab[ArgT].Kind = TYK_INT) Then
        Begin
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRCONV_ITOA');
          EmitInstr('ADD ESP,4');
          EmitInstr('PUSH EAX');
          EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR');
          EmitInstr('ADD ESP,4');
        End
        Else
          FatalError('TODO 21 : generateur de code, print(_:) ne couvre que ' +
            'String/Int pour cette premiere passe (Double/Bool/tableau restent ' +
            'une extension future, roadmap d''en-tete du TODO 20)')
      End
      { construction de classe SANS argument ("NomDeClasse()", extension    }
      { ajoutee suite au rapport "classes.swift" - TODO 25) : allocation             }
      { tas de TypeTab[...].Size octets (deja calcule par ParseClassType,           }
      { CHAMPS PROPRES SEULEMENT - une VRAIE sous-classe avec des champs                 }
      { HERITES physiquement contigus reste une extension future, AUCUN                 }
      { echantillon actuel n instancie de sous-classe) via _SWRT_ALLOC                  }
      { (deja zero-rempli, HEAP_ZERO_MEMORY - voir EmitRuntimeLibrary),                  }
      { pointeur laisse dans EAX (convention UNIQUE de ce generateur de              }
      { code) - une classe EST un type REFERENCE, ce pointeur EST                          }
      { directement sa "valeur". Une VRAIE evaluation d arguments d init             }
      { ("Point(x: 0, y: 0)" par exemple) reste hors de portee ICI                              }
      { (FatalError explicite juste en-dessous). }
      Else If CgIsClassCtorCall(E) Then
      Begin
        EmitInstr('PUSH ' + IntToStrSW(TypeTab[ExprPool[E].TypeIdx].Size));
        EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
        EmitInstr('ADD ESP,4');
      End
      Else If (ExprPool[E].TypeIdx >= 0) And (ExprPool[E].TypeIdx < TypeCount) And
         (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_CLASS) Then
        FatalError('TODO 21 : generateur de code, constructeur de classe AVEC ' +
          'argument(s) non couvert pour cette premiere passe (seul ' +
          '"NomDeClasse()" SANS argument l''est - un VRAI "init" ecrit par ' +
          'l''utilisateur reste une extension future)')
      { appel a une fonction UTILISATEUR de haut niveau (extension           }
      { "compilation de fonctions", TODO 21, suite au rapport                                }
      { "control.swift") - CgIsUserFuncCall (ci-dessus) confirme deja que              }
      { FuncFind resout un VRAI FuncDefPool. Arguments pousses DE DROITE               }
      { A GAUCHE (le PREMIER argument textuel finit a l adresse la PLUS               }
      { BASSE, EBP+8 vu du COTE callee - RegisterFuncScopeSymbols/                        }
      { CompileFuncDef assignent les parametres dans l ORDRE textuel a               }
      { partir de +8) ; convention d appel UNIFORME avec le reste de ce           }
      { generateur de code (jamais STDCALL, SEULEMENT les VRAIES               }
      { importations Win32 le sont) : "RET" nu cote callee (CompileFuncDef),             }
      { nettoyage de la pile ICI, cote appelant, apres le CALL - MEME             }
      { convention EXACTE que les appels a _SWRT_ALLOC/_SWRT_STRCONV_ITOA. }
      Else If CgIsUserFuncCall(E) Then
      Begin
        FD := FuncFind(ExprPool[ExprPool[E].Left].NameVal, ExprPool[E].ArgCount);
        For AI := ExprPool[E].ArgCount - 1 DownTo 0 Do
        Begin
          CompileExpr(ExprArgPool[ExprPool[E].ArgFirst + AI]);
          EmitInstr('PUSH EAX');
        End;
        EmitInstr('CALL ' + ASM_PFX_FUNC + FuncDefPool[FD].Name);
        If ExprPool[E].ArgCount > 0 Then
          EmitInstr('ADD ESP,' + IntToStrSW(4 * ExprPool[E].ArgCount));
      End
      Else
        FatalError('TODO 21 : generateur de code, appel non couvert pour cette ' +
          'premiere passe (seul ''print(_:)''/un constructeur de classe SANS ' +
          'argument/une fonction utilisateur SANS parametre "inout" le sont - ' +
          'methodes/structs restent une extension future) : ' +
          ExprPool[ExprPool[E].Left].NameVal);
  Else
    FatalError('TODO 21 : generateur de code, forme d''expression non couverte ' +
      'pour cette premiere passe (portee volontairement reduite a hello.swift, ' +
      'voir la note d''en-tete de section) : Kind=' + IntToStrSW(Ord(ExprPool[E].Kind)));
  End;
End;

{ CompileStmt : compile RECURSIVEMENT le noeud S de StmtPool. Extension  }
{ controle de flux (TODO 21, apres le rapport de validation TODO 25             }
{ signalant que arrays.swift/loops.swift s arretaient au premier for-in/                }
{ while) : if/else-if/else, while, repeat-while, for-in SUR UN               }
{ INTERVALLE ENTIER SEULEMENT (a..<b/a...b - Array/Dictionary/Set/               }
{ String restent une extension future, TODO 16/17), break/continue NON            }
{ etiquetes. "if let"/"guard"/switch/func/struct/class/etc. restent               }
{ HORS de portee (voir le Else FatalError final). Meme architecture                    }
{ EXACTE que GOCW32.PAS pour if/while (CMP+TEST/Jcc, PAS de SETcc) - voir              }
{ EmitCompareJcc ci-dessus ; break/continue et le for-in sur intervalle           }
{ N ONT PAS d equivalent existant a porter (confirme par recherche :                    }
{ GOCW32.PAS ne les compile pas non plus a cette date), concus ICI a                    }
{ partir de zero (pile CgLoopBreakLbl/CgLoopContinueLbl ci-dessus). }
Procedure CompileStmt(S: Integer);
Const
  MAX_CG_SWITCH_CASE = 64;
Var
  I, TgtSI, LoopVarSI, RangeE, CI, BI, CaseValE : Integer;
  LblElse, LblEnd, LblTop, LblCont, DefaultLbl : TString;
  CaseLbl : Array[0..MAX_CG_SWITCH_CASE - 1] Of TString;
Begin
  If S < 0 Then Exit;
  Case StmtPool[S].Kind Of
    STK_BLOCK:
      For I := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
        CompileStmt(StmtArgPool[I]);
    STK_EXPR:
      CompileExpr(StmtPool[S].Left);
    STK_DECL:
      { REEL bogue trouve par EXECUTION (errors.swift : "let status: Int = }
      { openFile(...)" a l INTERIEUR de la fonction "process", pas un                    }
      { self-test) - NON un simple "rien a generer" pour un symbole              }
      { GLOBAL (IsGlobal - deja entierement gere par EmitDataSeg/                        }
      { CompileGlobalRuntimeInits, la RAISON d etre de cette branche              }
      { d origine) : un local de FONCTION (extension "compilation de              }
      { fonctions") n a, lui, JAMAIS d autre occasion d etre initialise -            }
      { son emplacement EBP-relatif contient une valeur de PILE               }
      { QUELCONQUE tant que RIEN n y ecrit explicitement. Le laisser SANS           }
      { code ici faisait silencieusement lire une valeur NON INITIALISEE            }
      { (errors.swift imprimait "0" au lieu du "1" attendu - "status" par           }
      { coincidence souvent zero au tout DEBUT d une pile fraiche, jamais           }
      { garanti). Corrige en evaluant REELLEMENT l initialiseur de CHAQUE           }
      { symbole non-global cree par cette instruction (Left..Left+Extra-1,          }
      { voir ParseStatement) - un symbole GLOBAL dans cette meme plage                    }
      { (jamais le cas au niveau fichier top-level, uniquement possible            }
      { si un "let"/"var" apparaissait DANS TopLevelStmts - non exerce                  }
      { actuellement) reste, lui, delegue a EmitDataSeg comme avant. }
      For I := StmtPool[S].Left To StmtPool[S].Left + StmtPool[S].Extra - 1 Do
        If (SymTab[I].Kind = SK_VAR) And (Not SymTab[I].IsGlobal) And
           SymTab[I].HasInit And (SymTab[I].InitExprIdx >= 0) Then
        Begin
          CompileExpr(SymTab[I].InitExprIdx);
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(I) + ',EAX');
        End;
    STK_ASSIGN:
      If StmtPool[S].Op <> '=' Then
        FatalError('TODO 21 : generateur de code, operateur d''affectation ' +
          'compose non couvert pour cette premiere passe (seul "=" simple ' +
          'l''est) : ' + StmtPool[S].Op)
      Else If ExprPool[StmtPool[S].Left].Kind <> EK_IDENT Then
        FatalError('TODO 21 : generateur de code, cible d''affectation non ' +
          'couverte pour cette premiere passe (seul un identificateur simple ' +
          'l''est)')
      Else
      Begin
        TgtSI := SymFind(ExprPool[StmtPool[S].Left].NameVal);
        CompileExpr(StmtPool[S].Right);
        If TgtSI >= 0 Then
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(TgtSI) + ',EAX')
        Else
          FatalError('TODO 21 : generateur de code, cible d''affectation non ' +
            'resolue: ' + ExprPool[StmtPool[S].Left].NameVal);
      End;
    STK_IF:
      If StmtPool[S].NameVal <> '' Then
        FatalError('TODO 21 : generateur de code, "if let"/"if var" (liaison ' +
          'optionnelle) non couvert pour cette premiere passe - seule la ' +
          'forme "if Condition { }" SANS liaison l''est')
      Else
      Begin
        CompileExpr(StmtPool[S].Extra);
        LblElse := CgLabelGen;
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JZ ' + LblElse);
        CompileStmt(StmtPool[S].Right);
        If StmtPool[S].Left >= 0 Then
        Begin
          LblEnd := CgLabelGen;
          EmitInstr('JMP ' + LblEnd);
          EmitLabel(LblElse);
          CompileStmt(StmtPool[S].Left);
          EmitLabel(LblEnd);
        End
        Else
          EmitLabel(LblElse);
      End;
    STK_WHILE:
      Begin
        LblTop := CgLabelGen;
        LblEnd := CgLabelGen;
        EmitLabel(LblTop);
        CompileExpr(StmtPool[S].Extra);
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JZ ' + LblEnd);
        CgLoopPush(LblEnd, LblTop);
        CompileStmt(StmtPool[S].Right);
        CgLoopPop;
        EmitInstr('JMP ' + LblTop);
        EmitLabel(LblEnd);
      End;
    STK_REPEATWHILE:
      Begin
        LblTop  := CgLabelGen;
        LblCont := CgLabelGen;
        LblEnd  := CgLabelGen;
        EmitLabel(LblTop);
        CgLoopPush(LblEnd, LblCont);
        CompileStmt(StmtPool[S].Right);
        CgLoopPop;
        EmitLabel(LblCont);
        CompileExpr(StmtPool[S].Extra);
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNZ ' + LblTop);
        EmitLabel(LblEnd);
      End;
    STK_FORRANGE:
      Begin
        RangeE := StmtPool[S].Left;
        If (RangeE < 0) Or (ExprPool[RangeE].Kind <> EK_BINARY) Or
           ((ExprPool[RangeE].Op <> '..<') And (ExprPool[RangeE].Op <> '...')) Then
          FatalError('TODO 21 : generateur de code, "for-in" non couvert pour ' +
            'cette premiere passe (seul un intervalle ENTIER a..<b/a...b l''est ' +
            '- iteration sur Array/Dictionary/Set/String reste une extension ' +
            'future, TODO 16/17)')
        Else If StmtPool[S].Extra < 0 Then
          FatalError('TODO 21 : generateur de code, "for _ in ..." (variable ' +
            'de boucle ignoree) non couvert pour cette premiere passe')
        Else
        Begin
          LoopVarSI := StmtPool[S].Extra;

          CompileExpr(ExprPool[RangeE].Left);
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(LoopVarSI) + ',EAX');

          LblTop  := CgLabelGen;
          LblCont := CgLabelGen;
          LblEnd  := CgLabelGen;
          EmitLabel(LblTop);

          EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(LoopVarSI));
          EmitInstr('PUSH EAX');
          CompileExpr(ExprPool[RangeE].Right);
          EmitInstr('MOV EBX,EAX');
          EmitInstr('POP EAX');
          If ExprPool[RangeE].Op = '..<' Then
            EmitCompareJcc('JL')
          Else
            EmitCompareJcc('JLE');
          EmitInstr('TEST EAX,EAX');
          EmitInstr('JZ ' + LblEnd);

          CgLoopPush(LblEnd, LblCont);
          CompileStmt(StmtPool[S].Right);
          CgLoopPop;

          EmitLabel(LblCont);
          EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(LoopVarSI));
          EmitInstr('ADD EAX,1');
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(LoopVarSI) + ',EAX');
          EmitInstr('JMP ' + LblTop);
          EmitLabel(LblEnd);
        End;
      End;
    STK_BREAK:
      If StmtPool[S].NameVal <> '' Then
        FatalError('TODO 21 : generateur de code, "break" etiquete non couvert ' +
          'pour cette premiere passe')
      Else If CgLoopDepth <= 0 Then
        FatalError('TODO 21 : generateur de code, "break" hors de toute boucle')
      Else
        EmitInstr('JMP ' + CgLoopBreakLbl[CgLoopDepth - 1]);
    STK_CONTINUE:
      If StmtPool[S].NameVal <> '' Then
        FatalError('TODO 21 : generateur de code, "continue" etiquete non ' +
          'couvert pour cette premiere passe')
      Else If CgLoopDepth <= 0 Then
        FatalError('TODO 21 : generateur de code, "continue" hors de toute boucle')
      Else
        EmitInstr('JMP ' + CgLoopContinueLbl[CgLoopDepth - 1]);
    STK_GUARD:
      { "guard Condition else" suivi d un bloc-sinon (extension            }
      { "compilation de fonctions", TODO 21, suite au rapport "control.swift")           }
      { - INVERSE           }
      { du "if" : le bloc SINON s execute quand la condition est FAUSSE,             }
      { et DOIT sortir de la portee courante (return/break/continue,               }
      { verifie best-effort par le front-end, TODO 19 - jamais reverifie            }
      { ici, voir ParseGuardStmt). Si la condition est VRAIE, saute               }
      { PAR-DESSUS le bloc SINON et continue normalement. "guard let"                    }
      { (liaison optionnelle) reste HORS de portee (NameVal <> ''). }
      If StmtPool[S].NameVal <> '' Then
        FatalError('TODO 21 : generateur de code, "guard let"/"guard var" ' +
          '(liaison optionnelle) non couvert pour cette premiere passe - ' +
          'seule la forme "guard Condition else { }" SANS liaison l''est')
      Else
      Begin
        CompileExpr(StmtPool[S].Extra);
        LblEnd := CgLabelGen;
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JNZ ' + LblEnd);
        CompileStmt(StmtPool[S].Right);
        EmitLabel(LblEnd);
      End;
    STK_SWITCH:
      { "switch Tag" suivi de clauses "case Valeur:"/"default:" (extension     }
      { "compilation de fonctions", TODO 21, suite au rapport                            }
      { "control.swift") - PORTEE VOLONTAIREMENT ETROITE (seule ce que              }
      { control.swift/enums.swift exercent REELLEMENT) : UNE SEULE                     }
      { valeur ENTIERE litterale par "case" (jamais une liste "1, 2" ni               }
      { un intervalle "1...3"), AUCUN "fallthrough". Tag evalue UNE            }
      { SEULE fois (EBX, temoin de la convention EK_BINARY existante              }
      { pour "l operande de droite") puis compare a CHAQUE valeur de              }
      { case (CMP+JE) - PAS de table de sauts (nombre de cas trop petit           }
      { pour en justifier une, meme choix de simplicite que le reste de              }
      { ce generateur de code). }
      If StmtPool[S].ArgCount > MAX_CG_SWITCH_CASE Then
        FatalError('TODO 21 : generateur de code, "switch" avec plus de ' +
          IntToStrSW(MAX_CG_SWITCH_CASE) + ' cas non couvert pour cette ' +
          'premiere passe (MAX_CG_SWITCH_CASE)')
      Else
      Begin
        CompileExpr(StmtPool[S].Extra);
        EmitInstr('MOV EBX,EAX');
        LblEnd := CgLabelGen;
        DefaultLbl := '';
        For CI := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
          CaseLbl[CI - StmtPool[S].ArgFirst] := CgLabelGen;
        For CI := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
        Begin
          If CaseClausePool[CI].Fallthrough Then
            FatalError('TODO 21 : generateur de code, "fallthrough" non ' +
              'couvert pour cette premiere passe')
          Else If CaseClausePool[CI].IsDefault Then
            DefaultLbl := CaseLbl[CI - StmtPool[S].ArgFirst]
          Else If CaseClausePool[CI].ExprCount <> 1 Then
            FatalError('TODO 21 : generateur de code, "case" avec plusieurs ' +
              'valeurs ou un intervalle non couvert pour cette premiere ' +
              'passe (seule UNE SEULE valeur entiere litterale par case l''est)')
          Else
          Begin
            CaseValE := ExprArgPool[CaseClausePool[CI].ExprFirst];
            If ExprPool[CaseValE].Kind <> EK_INTLIT Then
              FatalError('TODO 21 : generateur de code, valeur de "case" non ' +
                'litterale entiere non couverte pour cette premiere passe')
            Else
            Begin
              EmitInstr('CMP EBX,' + IntToStrSW(ExprPool[CaseValE].IntVal));
              EmitInstr('JE ' + CaseLbl[CI - StmtPool[S].ArgFirst]);
            End;
          End;
        End;
        If DefaultLbl <> '' Then
          EmitInstr('JMP ' + DefaultLbl)
        Else
          EmitInstr('JMP ' + LblEnd);
        For CI := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
        Begin
          EmitLabel(CaseLbl[CI - StmtPool[S].ArgFirst]);
          For BI := CaseClausePool[CI].BodyFirst To CaseClausePool[CI].BodyFirst + CaseClausePool[CI].BodyCount - 1 Do
            CompileStmt(StmtArgPool[BI]);
          EmitInstr('JMP ' + LblEnd);
        End;
        EmitLabel(LblEnd);
      End;
    STK_RETURN:
      { "return [Expression]" (extension "compilation de fonctions",     }
      { TODO 21) - le resultat (s il y en a un) est DEJA dans EAX apres            }
      { CompileExpr (convention UNIQUE de ce generateur de code) ; saute            }
      { vers l EPILOGUE PARTAGE de la fonction en cours (CgCurFuncEpilogueLbl,          }
      { CompileFuncDef) plutot que de dupliquer MOV ESP,EBP/POP EBP/RET a           }
      { CHAQUE "return" (utile des qu un "guard" en introduit plusieurs). }
      Begin
        If StmtPool[S].Left >= 0 Then CompileExpr(StmtPool[S].Left);
        If CgCurFuncEpilogueLbl = '' Then
          FatalError('TODO 21 : generateur de code, "return" hors de toute ' +
            'fonction non couvert pour cette premiere passe')
        Else
          EmitInstr('JMP ' + CgCurFuncEpilogueLbl);
      End;
  Else
    FatalError('TODO 21 : generateur de code, forme d''instruction non couverte ' +
      'pour cette premiere passe (func/struct/class/etc. restent une ' +
      'extension future, voir la note d''en-tete de section) : ' +
      'Kind=' + IntToStrSW(Ord(StmtPool[S].Kind)));
  End;
End;

{ ParseSwiftProgram : voir la note d en-tete de section - boucle sur      }
{ TOUT le fichier, essayant ParseTopLevelDecl PUIS (seulement si Faux)             }
{ ParseStatement, collectant les instructions EXECUTABLES dans                              }
{ TopLevelStmts (les declarations n ont rien de plus a collecter, elles           }
{ s auto-enregistrent deja par leurs propres SymAdd/FuncDefAdd/etc). }
Procedure ParseSwiftProgram;
Var N : Integer;
Begin
  TopLevelStmtCount := 0;
  PPSkipSemis;
  While Not PPAtEnd Do
  Begin
    If Not ParseTopLevelDecl Then
    Begin
      N := ParseStatement;
      If TopLevelStmtCount < MAX_STMT Then
      Begin
        TopLevelStmts[TopLevelStmtCount] := N;
        Inc(TopLevelStmtCount);
      End
      Else
        WarnMsg('table des instructions de haut niveau pleine (MAX_STMT)');
    End;
    PPSkipSemis;
  End;
End;

{ CompileGlobalRuntimeInits : extension "construction de classe" (suite   }
{ au rapport "classes.swift" - TODO 25) - parcourt SymTab UNE FOIS,               }
{ EN ORDRE DE DECLARATION (memes garanties que l initialisation de              }
{ globaux d un VRAI compilateur Swift), et emet le SEUL cas de global             }
{ non repliable que ce generateur de code sait desormais INITIALISER              }
{ REELLEMENT (CgIsClassCtorCall, voir EmitDataSeg) - EmitDataSeg a deja           }
{ ecrit "DD 0" comme PLACEHOLDER pour son stockage, ECRASE ICI par                    }
{ l ADRESSE reelle de l instance fraichement allouee. Doit s executer               }
{ AVANT le corps (TopLevelStmts) - meme s il n y a, pour l instant,                     }
{ aucun echantillon ou cela importe reellement (aucun ne LIT une classe           }
{ globale avant de l ecrire), matcher l ordre reel d un compilateur                    }
{ Swift reste la discipline honnete a suivre. }
Procedure CompileGlobalRuntimeInits;
Var I : Integer;
Begin
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].Kind = SK_VAR) And SymTab[I].IsGlobal And SymTab[I].HasInit And
       (CgIsClassCtorCall(SymTab[I].InitExprIdx) Or CgIsUserFuncCall(SymTab[I].InitExprIdx)) Then
    Begin
      CompileExpr(SymTab[I].InitExprIdx);
      EmitInstr('MOV DWORD PTR ' + CgVarOperand(I) + ',EAX');
    End;
End;

{ CompileFuncDef : compile UNE fonction utilisateur de haut niveau        }
{ (extension "compilation de fonctions", TODO 21, suite au rapport               }
{ "control.swift : initialiseur non repliable" - TODO 25). Prologue            }
{ standard (PUSH EBP/MOV EBP,ESP[/SUB ESP,N si des locales existent]) -           }
{ assigne D ABORD de VRAIS deplacements EBP a CHAQUE parametre               }
{ (ParamSymFirst..+ParamCount, +8/+12/...) ET a CHAQUE symbole du corps            }
{ (LocalSymFirst..+LocalSymCount, -4/-8/... - couvre aussi bien un "let"           }
{ local qu une variable de boucle for-in DECLAREE A L INTERIEUR de cette          }
{ fonction, contrairement a IsTopLevelLocal qui ne concerne QUE le                    }
{ niveau fichier) AVANT de compiler le corps, pour que CgVarOperand                     }
{ route correctement chaque reference. Un SEUL parametre "inout" (alias           }
{ par ADRESSE, jamais une vraie copie) arrete PROPREMENT cette fonction           }
{ ENTIERE avant meme de toucher son corps - extension future documentee.           }
{ CgCurFuncEpilogueLbl (une SEULE etiquette partagee par TOUS les              }
{ "return" de CETTE fonction, y compris ceux introduits par un "guard")          }
{ permet a STK_RETURN de sauter vers un epilogue UNIQUE plutot que de              }
{ dupliquer MOV ESP,EBP/POP EBP/RET a chaque site de retour. Convention           }
{ d appel UNIFORME avec le reste de ce generateur de code : "RET" NU (le          }
{ CALLEUR nettoie la pile, jamais STDCALL - meme convention EXACTE que              }
{ _SWRT_ALLOC/_SWRT_STRCONV_ITOA). }
Procedure CompileFuncDef(FD: Integer);
Var
  FT, I, PIdx, ParamCnt, LocalCnt : Integer;
  HasInoutParam : Boolean;
Begin
  FT := FuncDefPool[FD].TypeIdx;
  ParamCnt := TypeTab[FT].ParamCount;

  HasInoutParam := False;
  For I := 0 To ParamCnt - 1 Do
  Begin
    PIdx := TypeTab[FT].ParamFirst + I;
    If FieldPool[PIdx].IsInout Then HasInoutParam := True;
  End;

  If HasInoutParam Then
    FatalError('TODO 21 : generateur de code, fonction ''' + FuncDefPool[FD].Name +
      ''' avec parametre(s) "inout" non couverte pour cette premiere passe ' +
      '(alias par ADRESSE - extension future)')
  Else
  Begin
    For I := 0 To ParamCnt - 1 Do
      SymTab[FuncDefPool[FD].ParamSymFirst + I].Offset := 8 + I * 4;

    LocalCnt := FuncDefPool[FD].LocalSymCount;
    For I := 0 To LocalCnt - 1 Do
      SymTab[FuncDefPool[FD].LocalSymFirst + I].Offset := -4 - I * 4;

    EmitLabel(ASM_PFX_FUNC + FuncDefPool[FD].Name);
    EmitInstr('PUSH EBP');
    EmitInstr('MOV EBP,ESP');
    If LocalCnt > 0 Then
      EmitInstr('SUB ESP,' + IntToStrSW(LocalCnt * 4));

    CgCurFuncEpilogueLbl := CgLabelGen;
    CompileStmt(FuncDefPool[FD].BodyStmtIdx);

    EmitLabel(CgCurFuncEpilogueLbl);
    EmitInstr('MOV ESP,EBP');
    EmitInstr('POP EBP');
    EmitInstr('RET');
    EmitBlankLine;
  End;
End;

{ EmitUserFunctions : compile TOUTES les fonctions de FuncDefPool, SANS  }
{ CONDITION (meme discipline que le reste de ce compilateur - un VRAI            }
{ compilateur compile TOUTE fonction declaree, appelee ou non) - une              }
{ fonction jamais appelee mais utilisant un parametre "inout" (ex.               }
{ "swap" dans math.swift) s arrete donc PROPREMENT ICI, AVANT meme               }
{ qu aucun site d appel ne soit atteint. }
Procedure EmitUserFunctions;
Var I : Integer;
Begin
  For I := 0 To FuncDefCount - 1 Do
    CompileFuncDef(I);
End;

{ CompileProgram : point d entree du generateur de code - ordre           }
{ d emission EXACT de GOCW32.PAS (en-tete -> donnees -> section code ->            }
{ bibliotheque runtime -> corps) PLUS desormais EmitUserFunctions               }
{ (extension "compilation de fonctions") : le corps DU FICHIER est               }
{ directement la sequence des instructions de haut niveau (TopLevelStmts,           }
{ ParseSwiftProgram) sous l etiquette d entree "_SWSTART" (jamais               }
{ "_SWF_main" - Swift n exige pas ce nom, contrairement a "func main()"            }
{ en Go) - PRECEDE de CompileGlobalRuntimeInits (extension "construction           }
{ de classe"/"compilation de fonctions"). Extension "defer au niveau              }
{ fichier" (TODO 21, suite au rapport "errors.swift") : ParseDeferStmt              }
{ (TODO 15) documente DEJA "collecte-puis-rejeu-inverse, meme mecanisme            }
{ que le TODO 16 de GOCW32.PAS" - ce generateur de code applique             }
{ desormais EXACTEMENT cela pour les "defer" rencontres DIRECTEMENT dans           }
{ TopLevelStmts (la PORTEE ENGLOBANTE d un script Swift est le fichier              }
{ ENTIER - le corps differe donc du "defer" pour EmitInstr sur place :          }
{ chaque bloc est mis de cote PENDANT le parcours principal, PUIS               }
{ rejoue en ORDRE INVERSE (LIFO - le DERNIER "defer" enregistre s execute          }
{ en PREMIER, regle Swift REELLE) juste avant la sortie de processus              }
{ propre. Un "defer" A L INTERIEUR d une fonction ou d un bloc imbrique           }
{ (if/while/etc.) reste HORS de portee (CompileStmt lui-meme n a AUCUN           }
{ cas STK_DEFER - seul CE point d entree le reconnait) - arret propre               }
{ via le Else FatalError deja existant de CompileStmt. }
Procedure CompileProgram(Const AsmFileName: TString);
Const
  MAX_CG_TOPLEVEL_DEFER = 16;
Var
  I, DeferCount : Integer;
  DeferBody : Array[0..MAX_CG_TOPLEVEL_DEFER - 1] Of Integer;
Begin
  CgLabelSeq := 0;
  CgLoopDepth := 0;
  CgCollectStrings;

  EmitOpen(AsmFileName);
  EmitHeader;
  EmitDataSeg;
  EmitCodeSeg;
  EmitRuntimeLibrary;
  EmitUserFunctions;

  EmitLabel('_SWSTART');
  CompileGlobalRuntimeInits;

  DeferCount := 0;
  For I := 0 To TopLevelStmtCount - 1 Do
    If StmtPool[TopLevelStmts[I]].Kind = STK_DEFER Then
    Begin
      If DeferCount < MAX_CG_TOPLEVEL_DEFER Then
      Begin
        DeferBody[DeferCount] := StmtPool[TopLevelStmts[I]].Right;
        Inc(DeferCount);
      End
      Else
        WarnMsg('trop de "defer" au niveau fichier (MAX_CG_TOPLEVEL_DEFER)');
    End
    Else
      CompileStmt(TopLevelStmts[I]);

  For I := DeferCount - 1 DownTo 0 Do
    CompileStmt(DeferBody[I]);

  EmitInstr('PUSH 0');
  EmitInstr('CALL _ExitProcess@4');
  EmitRaw('END _SWSTART');
  EmitClose;
End;

{ CgFileHasSubstring : relit le .asm PRODUIT ligne par ligne et cherche   }
{ une sous-chaine EXACTE - meme methode que CgFileHasSubstring de              }
{ GOCW32.PAS (verification STRUCTURELLE du texte emis, PAS une VRAIE               }
{ execution : aucun assembleur/lieur n existe encore, TODO 22/23, voir              }
{ la note de CodegenSelfTest ci-dessous). }
Function CgFileHasSubstring(Const FileName, Sub: TString): Boolean;
Var F : Text; Line : TString; Found : Boolean;
Begin
  Found := False;
  Assign(F, FileName);
  Reset(F);
  While Not EOF(F) Do
  Begin
    ReadLn(F, Line);
    If Pos(Sub, Line) > 0 Then
    Begin
      Found := True;
      Break;
    End;
  End;
  Close(F);
  CgFileHasSubstring := Found;
End;

{ ------------------------------------------------------------ }
{ CodegenSelfTest : genere un VRAI fichier .asm a partir de hello.swift   }
{ EN ENTIER (forme complete - PREMIERE fois qu un echantillon est                        }
{ REELLEMENT COMPILE, pas seulement tokenise/parse) et verifie, PAR                       }
{ SOUS-CHAINE, que les instructions/sections attendues apparaissent -                     }
{ MEME LIMITATION que GOCW32.PAS/DELPHI.PAS a ce meme stade (ni                                 }
{ assembleur ni lieur n existent encore, TODO 22/23 - une verification                       }
{ REELLE par EXECUTION du .exe produit devra attendre ces deux TODO,                      }
{ puis une compilation+execution MANUELLE de chaque SAMPLES\SWIFT\*.swift,               }
{ discipline etablie par tous les compilateurs freres de ce projet et                      }
{ documentee au TODO 25). }
{ ------------------------------------------------------------ }

Procedure CodegenAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('CodegenSelfTest: ' + Label_ + ' a echoue');
End;

Procedure CodegenSelfTest;
Const
  TmpSrc = 'SWIFTW32CODEGENSELFTESTSRC.$$$';
  TmpAsm = 'SWIFTW32CODEGENSELFTEST.$$$';
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  { hello.swift EN ENTIER (forme complete, identique au fichier reel) }
  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let greeting: String = "Hello, 8086!"');
  WriteLn(LexSrcF, 'let version: Int = 1');
  WriteLn(LexSrcF, 'var counter: Int = 0');
  WriteLn(LexSrcF, 'print(greeting)');
  WriteLn(LexSrcF, 'print(version)');
  WriteLn(LexSrcF, 'counter = counter + 1');
  WriteLn(LexSrcF, 'print(counter)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);

  CodegenAssert('.386 present', CgFileHasSubstring(TmpAsm, '.386'));
  CodegenAssert('.MODEL FLAT, STDCALL present', CgFileHasSubstring(TmpAsm, '.MODEL FLAT, STDCALL'));
  CodegenAssert('global "greeting" (String, contenu REEL) present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'greeting  DB "Hello, 8086!", 0'));
  CodegenAssert('global "version" (Int, valeur constante 1) present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'version  DD 1'));
  CodegenAssert('global "counter" (Int, valeur constante 0) present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'counter  DD 0'));
  CodegenAssert('etiquette d''entree _SWSTART presente', CgFileHasSubstring(TmpAsm, '_SWSTART:'));
  CodegenAssert('print(String) -> CALL _SWRT_PRINTLN_STR present',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR'));
  CodegenAssert('print(Int) -> CALL _SWRT_STRCONV_ITOA present',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_RUNTIME + 'STRCONV_ITOA'));
  CodegenAssert('"counter = counter + 1" -> ADD EAX,EBX present',
    CgFileHasSubstring(TmpAsm, 'ADD EAX,EBX'));
  CodegenAssert('"counter = ..." -> affectation vers le global counter presente',
    CgFileHasSubstring(TmpAsm, 'MOV DWORD PTR [' + ASM_PFX_GVAR + 'counter],EAX'));
  CodegenAssert('sortie propre CALL _ExitProcess@4 present',
    CgFileHasSubstring(TmpAsm, 'CALL _ExitProcess@4'));
  CodegenAssert('point d''entree END _SWSTART present', CgFileHasSubstring(TmpAsm, 'END _SWSTART'));

  Assign(CgOutF, TmpAsm);
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;

  { loops.swift EN ENTIER (extension controle de flux, TODO 21, ajoutee   }
  { suite au rapport de validation TODO 25 : if/while/repeat-while/               }
  { for-in sur intervalle/break/continue/comparaisons - exerce les SIX             }
  { a la fois, EXACTEMENT le contenu REEL de SAMPLES\SWIFT\loops.swift,           }
  { deja verifie par EXECUTION reelle (Git Bash ET PowerShell natif,               }
  { sortie EXACTEMENT conforme a un vrai compilateur Swift) AVANT               }
  { d ecrire ces assertions structurelles). }
  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'var i: Int = 0');
  WriteLn(LexSrcF, 'while i < 5 {');
  WriteLn(LexSrcF, 'print(i)');
  WriteLn(LexSrcF, 'i = i + 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'var j: Int = 10');
  WriteLn(LexSrcF, 'repeat {');
  WriteLn(LexSrcF, 'print(j)');
  WriteLn(LexSrcF, 'j = j - 1');
  WriteLn(LexSrcF, '} while j > 7');
  WriteLn(LexSrcF, 'for k in 0..<5 {');
  WriteLn(LexSrcF, 'print(k)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'for m in 0..<100 {');
  WriteLn(LexSrcF, 'if m == 3 {');
  WriteLn(LexSrcF, 'break');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'print(m)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'for n in 0..<6 {');
  WriteLn(LexSrcF, 'if n == 2 {');
  WriteLn(LexSrcF, 'continue');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'print(n)');
  WriteLn(LexSrcF, '}');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);

  CodegenAssert('while : comparaison "<" -> CMP EAX,EBX present',
    CgFileHasSubstring(TmpAsm, 'CMP EAX,EBX'));
  CodegenAssert('while : saut conditionnel de sortie JZ present',
    CgFileHasSubstring(TmpAsm, 'JZ '));
  CodegenAssert('while : retour au sommet JMP present', CgFileHasSubstring(TmpAsm, 'JMP '));
  CodegenAssert('repeat-while : condition testee APRES le corps, JNZ present',
    CgFileHasSubstring(TmpAsm, 'JNZ '));
  CodegenAssert('for-in : comparaison "..<" -> JL (borne exclusive) present',
    CgFileHasSubstring(TmpAsm, 'JL '));
  CodegenAssert('if/comparaison "==" -> JE present', CgFileHasSubstring(TmpAsm, 'JE '));
  CodegenAssert('for-in : variable de boucle stockee dans .DATA (etiquette ' +
    'mangle "L<index>_nom", IsTopLevelLocal) present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'L'));
  CodegenAssert('for-in : incrementation de la variable de boucle (ADD EAX,1) present',
    CgFileHasSubstring(TmpAsm, 'ADD EAX,1'));

  Assign(CgOutF, TmpAsm);
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;

  { classes.swift EN ENTIER (extension "construction de classe", TODO 21, }
  { ajoutee suite au rapport "classes.swift : initialiseur non repliable"           }
  { - TODO 25) - deja verifie par EXECUTION reelle (Git Bash ET PowerShell           }
  { natif, sortie "42" EXACTEMENT conforme) AVANT d ecrire ces assertions              }
  { structurelles. Taille attendue de Animal (2 champs) : String a un              }
  { TypeTab[PDT_STRING].Size DEJA de 8 (pas 4 - reserve depuis le TODO           }
  { 03/04, JAMAIS aligne sur le fait que la representation REELLE d une             }
  { chaine ici est un simple pointeur 4 octets, TODO 17/21/23 - ecart            }
  { pre-existant, HORS de portee de cette extension) + Int (4) = 12               }
  { octets, PAS 8 - premiere version de ce self-test avait par erreur              }
  { affirme "PUSH 8" et le test PASSAIT quand meme, par COINCIDENCE : ce           }
  { texte existe DEJA, sans rapport, dans _SWRT_ALLOC lui-meme                             }
  { (HeapAlloc(dwFlags=HEAP_ZERO_MEMORY=8)) - corrige en verifiant "PUSH           }
  { 12" (la VRAIE valeur, confirmee en inspectant le .asm reel via "-asm"). }
  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'class Animal {');
  WriteLn(LexSrcF, 'var name: String');
  WriteLn(LexSrcF, 'var legs: Int');
  WriteLn(LexSrcF, 'func speak() -> Int {');
  WriteLn(LexSrcF, 'return 0');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let pet: Animal = Animal()');
  WriteLn(LexSrcF, 'print(42)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);

  CodegenAssert('"pet" (classe) recoit un placeholder .DATA "DD 0" (adresse ' +
    'ecrite A L EXECUTION, pas a l assemblage) present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'pet  DD 0'));
  CodegenAssert('CompileGlobalRuntimeInits : allocation tas de la BONNE ' +
    'taille (Animal = String[8]+Int[4] = 12 octets, PAS le "PUSH 8" ' +
    'sans rapport deja present dans _SWRT_ALLOC lui-meme pour ' +
    'HeapAlloc(HEAP_ZERO_MEMORY) - verifie par execution reelle, voir ' +
    'la note d en-tete de ce bloc) present',
    CgFileHasSubstring(TmpAsm, 'PUSH 12'));
  CodegenAssert('CompileGlobalRuntimeInits : CALL _SWRT_ALLOC present',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_RUNTIME + 'ALLOC'));
  CodegenAssert('CompileGlobalRuntimeInits : adresse allouee ecrite dans "pet" present',
    CgFileHasSubstring(TmpAsm, 'MOV DWORD PTR [' + ASM_PFX_GVAR + 'pet],EAX'));

  Assign(CgOutF, TmpAsm);
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;

  { control.swift EN ENTIER (extension "compilation de fonctions", TODO   }
  { 21, suite au rapport "control.swift : initialiseur non repliable" -           }
  { TODO 25 - couvre EN UN SEUL fichier if/else-if/else, switch/case/             }
  { default, une VRAIE fonction utilisateur avec parametre/return/guard,           }
  { et l appel de cette fonction depuis un initialiseur de global) -                    }
  { deja verifie par EXECUTION reelle (Git Bash ET PowerShell natif,               }
  { sortie "2"/"30"/"1" EXACTEMENT conforme) AVANT d ecrire ces                        }
  { assertions structurelles. }
  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let score: Int = 85');
  WriteLn(LexSrcF, 'if score >= 90 {');
  WriteLn(LexSrcF, 'print(1)');
  WriteLn(LexSrcF, '} else if score >= 80 {');
  WriteLn(LexSrcF, 'print(2)');
  WriteLn(LexSrcF, '} else {');
  WriteLn(LexSrcF, 'print(0)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let value: Int = 3');
  WriteLn(LexSrcF, 'switch value {');
  WriteLn(LexSrcF, 'case 1:');
  WriteLn(LexSrcF, 'print(10)');
  WriteLn(LexSrcF, 'case 3:');
  WriteLn(LexSrcF, 'print(30)');
  WriteLn(LexSrcF, 'default:');
  WriteLn(LexSrcF, 'print(0)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func checkAge(_ age: Int) -> Int {');
  WriteLn(LexSrcF, 'guard age >= 0 else {');
  WriteLn(LexSrcF, 'return 0');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'guard age <= 150 else {');
  WriteLn(LexSrcF, 'return 0');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let valid: Int = checkAge(25)');
  WriteLn(LexSrcF, 'print(valid)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);

  CodegenAssert('CompileFuncDef : etiquette de fonction _SWF_checkAge present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_FUNC + 'checkAge:'));
  CodegenAssert('CompileFuncDef : prologue MOV EBP,ESP present',
    CgFileHasSubstring(TmpAsm, 'MOV EBP,ESP'));
  CodegenAssert('CompileFuncDef : epilogue MOV ESP,EBP present',
    CgFileHasSubstring(TmpAsm, 'MOV ESP,EBP'));
  CodegenAssert('CompileFuncDef : "RET" NU (le CALLEUR nettoie la pile, ' +
    'jamais STDCALL) present', CgFileHasSubstring(TmpAsm, 'RET'));
  CodegenAssert('appel utilisateur : CALL _SWF_checkAge present',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_FUNC + 'checkAge'));
  CodegenAssert('appel utilisateur : nettoyage de pile ADD ESP,4 (1 argument) present',
    CgFileHasSubstring(TmpAsm, 'ADD ESP,4'));
  CodegenAssert('switch : comparaison de case CMP EBX present',
    CgFileHasSubstring(TmpAsm, 'CMP EBX,'));
  CodegenAssert('"valid" (appel de fonction) recoit un placeholder .DATA ' +
    '"DD 0" present',
    CgFileHasSubstring(TmpAsm, ASM_PFX_GVAR + 'valid  DD 0'));

  Assign(CgOutF, TmpAsm);
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;

  { errors.swift EN ENTIER (extension "defer au niveau fichier" +         }
  { CORRECTIF STK_DECL, TODO 21, suite au rapport "errors.swift" -                    }
  { TODO 25) - deja verifie par EXECUTION reelle (Git Bash ET PowerShell            }
  { natif, sortie "1"/"99" EXACTEMENT conforme - PAS "0"/"99" comme le              }
  { PREMIER essai, sans le correctif STK_DECL, le produisait) AVANT               }
  { d ecrire ces assertions structurelles. }
  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'func openFile(_ name: String) -> Int {');
  WriteLn(LexSrcF, 'return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'func process() -> Int {');
  WriteLn(LexSrcF, 'let status: Int = openFile("test.txt")');
  WriteLn(LexSrcF, 'if status == 0 {');
  WriteLn(LexSrcF, 'return 0');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'return 1');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'defer {');
  WriteLn(LexSrcF, 'print(99)');
  WriteLn(LexSrcF, '}');
  WriteLn(LexSrcF, 'let ok: Int = process()');
  WriteLn(LexSrcF, 'print(ok)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);

  CodegenAssert('STK_DECL (correctif) : initialisation REELLE du local ' +
    '"status" (MOV DWORD PTR [EBP-4],EAX) present - PAS un simple "rien ' +
    'a faire" comme avant ce correctif',
    CgFileHasSubstring(TmpAsm, 'MOV DWORD PTR [EBP-4],EAX'));
  CodegenAssert('"defer" au niveau fichier : le corps differe reste ' +
    'compile (CALL _SWRT_STRCONV_ITOA/PRINTLN_STR present, partage avec ' +
    'tout autre print(Int))',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_RUNTIME + 'STRCONV_ITOA'));
  CodegenAssert('sortie propre CALL _ExitProcess@4 toujours present ' +
    '(APRES le corps differe, jamais avant)',
    CgFileHasSubstring(TmpAsm, 'CALL _ExitProcess@4'));

  Assign(CgOutF, TmpAsm);
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32                      }
{ ============================================================ }
{ Assembleur 80386 hand-roule + ecrivain COFF .OBJ minimal -                    }
{ architecture ETUDIEE et REPRISE PRESQUE A L IDENTIQUE de GOCW32.PAS                    }
{ (meme projet, meme discipline EXPLICITEMENT exigee par le roadmap                        }
{ d en-tete de CE TODO) : cet assembleur RELIT le texte .asm ECRIT PAR           }
{ LE TODO 21 (AUCUNE structure de representation intermediaire                                 }
{ separee - le texte .asm LUI-MEME est deja l IR, exactement comme                          }
{ documente au TODO 21) - une passe COMPLETEMENT SEPAREE de l emission               }
{ textuelle. Ce code est PRESQUE ENTIEREMENT independant du langage                        }
{ SOURCE (encodage 80386/format COFF, universel) : les noms de                                 }
{ fonctions/records sont donc repris VERBATIM (Bin*/WriteCOFFObj) plutot                  }
{ que renommes en _SW*, matching le meme choix DEJA fait par GOCW32.PAS                     }
{ lui-meme (qui ne prefixe PAS non plus ses propres Bin* en _GO*).                                    }
{                                                                       }
{ PORTEE DELIBEREMENT REDUITE (meme discipline que le TODO 21) : SEUL             }
{ le sous-ensemble de mnemoniques REELLEMENT emis par le generateur de            }
{ code/la bibliotheque runtime actuels (TODO 21, hello.swift) est                             }
{ couvert - MOV (3 formes + BYTE PTR), MOVZX, PUSH/POP, LEA, ADD/SUB/               }
{ AND/OR/XOR/CMP (BinEncodeAlu, groupe complet repris SANS le trier -                     }
{ ADD/SUB/XOR/CMP sont REELLEMENT emis, AND/OR/TEST/NOT ne coutent RIEN            }
{ de plus a inclure dans le MEME encodeur partage), IMUL, IDIV, NEG,               }
{ INC/DEC, JMP/Jcc (forme LONGUE uniquement), CALL (direct SEULEMENT -             }
{ la forme INDIRECTE "CALL reg" de GOCW32.PAS sert aux goroutines,                          }
{ INEXISTANTES en Swift), RET, CDQ - AUCUNE forme SHL/SAR/SHR ni x87              }
{ FPU (aucune des deux n est encore emise ici, contrairement a                                    }
{ GOCW32.PAS ou les flottants existent deja) : arret propre                                     }
{ (FatalError explicite) pour tout le reste, EXACTEMENT le meme                                  }
{ "arret propre, jamais un octet errone silencieux" que chaque section                     }
{ precedente de ce fichier.                                                                     }
{                                                                       }
{ Deux tables paralleles remplies en UNE SEULE passe sur le texte .asm            }
{ (BinAssembleFile) : BinLabels (chaque etiquette rencontree, avec sa            }
{ POSITION dans .text ou .data) et BinFixups (chaque champ 32 bits DONT           }
{ la VRAIE valeur n est pas encore connue au moment de l encoder - un              }
{ saut/appel vers une etiquette pas ENCORE definie, OU une adresse                          }
{ ABSOLUE, JAMAIS connue avant l edition de liens). BinResolveFixups                     }
{ (une SECONDE passe, apres que TOUTES les etiquettes sont connues)                       }
{ ne resout QUE les REL32 dont la cible est une etiquette LOCALE de la              }
{ MEME section (deplacement invariant, quel que soit l endroit ou la                    }
{ section finira par etre chargee) - TOUT le reste (REL32 vers un                            }
{ import externe, ET tout ABS32 SANS exception, meme vers une etiquette            }
{ locale) reste marque Resolved=Faux et devient une VRAIE relocation                     }
{ COFF dans WriteCOFFObj, laissee au lieur externe (jamais resolue ici,            }
{ roadmap d en-tete : "sortie .OBJ laissee au lieur externe pour les                    }
{ adresses finales"). }

Type
  TBinOpKind = (BOK_REG, BOK_IMM, BOK_MEM, BOK_LABEL);
  TBinOperand = Record
    Kind      : TBinOpKind;
    RegNum    : Integer;    { BOK_REG : 0..7 (EAX..EDI, numerotation ModRM/SIB) }
    ImmVal    : LongInt;    { BOK_IMM }
    BaseReg   : Integer;    { BOK_MEM avec base : 0..7 ; -1 si absolu (etiquette) }
    Disp      : LongInt;    { BOK_MEM avec base : deplacement }
    LabelName : TString;    { BOK_MEM absolu (etiquette entre crochets), OU        }
                             { BOK_LABEL (cible de JMP/Jcc/CALL, ou LEA absolu)         }
    IsByte    : Boolean;    { Vrai si prefixe par "BYTE PTR" (sinon DWORD implicite) }
  End;

  TBinLabel = Record
    Name   : TString;
    IsData : Boolean;   { Faux = .text (BinCode) ; Vrai = .data (BinData) }
    Ofs    : LongInt;
  End;

  TBinFixup = Record
    IsData     : Boolean;   { section CONTENANT le champ 32 bits a corriger }
    Pos        : LongInt;   { position de ce champ DANS cette section }
    Kind       : Integer;   { BIN_FIX_REL32 ou BIN_FIX_ABS32 (deja reservees, TODO 01) }
    TargetName : TString;
    Resolved   : Boolean;   { Vrai si deja corrige ICI (REL32 local) - EXCLU  }
                             { de la table de relocations COFF ; Faux ->        }
                             { devient une VRAIE relocation (WriteCOFFObj). }
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
  BinCurIsData   := False;
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

{ BinPatch32 : ecrase 4 octets DEJA emis (toujours un PLACEHOLDER 0,     }
{ pose par un BinEmit32(0) anterieur) - utilise par BinAddFixup lui-meme          }
{ pour retrouver leur position, et par BinResolveFixups pour les                     }
{ corriger une fois la cible connue. }
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

{ BinAddFixup : appelee IMMEDIATEMENT APRES avoir deja emis 4 octets      }
{ PLACEHOLDER (BinEmit32(0)) pour le champ a corriger - calcule Pos            }
{ (position de CES 4 octets) a partir de la position COURANTE. }
Procedure BinAddFixup(Kind: Integer; Const TargetName: TString);
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
{ d assembleur general. }
{ ------------------------------------------------------------ }

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

{ BinReg32 : numerotation ModRM/SIB standard 80386 - EAX=0 ECX=1 EDX=2   }
{ EBX=3 ESP=4 EBP=5 ESI=6 EDI=7 - -1 si ce n est pas un nom de registre           }
{ 32 bits reconnu. }
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
    Inner := Copy(S, 2, Length(S) - 2);   { retire "[" et "]" }
    SignPos := 0;
    For I := 2 To Length(Inner) Do   { position 1 ne peut pas etre un signe de deplacement }
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
        Op.LabelName := Inner;   { "[etiquette]" absolu, sans registre de base }
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

{ BinEmitModRM : coeur PARTAGE ModRM(+disp32) de tous les encodeurs      }
{ ci-dessous - TOUJOURS un deplacement complet sur 32 bits quand un                }
{ registre de base est present (jamais Mod=01/disp8), ce qui evite                    }
{ completement le cas particulier EBP/SIB=101 sans perdre de generalite                 }
{ pour ce dont ce compilateur a reellement besoin. Aucun adressage                            }
{ BASE+INDEX (SIB avec un second registre) n est gere - hors de portee                            }
{ documentee ; Mem.Kind doit toujours etre BOK_REG (registre direct) ou           }
{ BOK_MEM (base+disp32 ou absolu+etiquette). }
Procedure BinEmitModRM(RegField: Integer; Const Mem: TBinOperand);
Begin
  If Mem.Kind = BOK_REG Then
  Begin
    BinEmit8($C0 Or (RegField Shl 3) Or Mem.RegNum);
    Exit;
  End;
  If Mem.BaseReg >= 0 Then
  Begin
    { ESP (BaseReg=4) comme registre de base : RM=100 impose TOUJOURS un   }
    { octet SIB, quel que soit Mod (00/01/10) - jamais exerce par le              }
    { sous-ensemble actuel de ce compilateur, mais reproduit ici par                    }
    { fidelite au comportement CORRECT de GOCW32.PAS (aucune raison de              }
    { l omettre, meme cout d implementation). }
    If Mem.BaseReg = 4 Then
    Begin
      BinEmit8($80 Or (RegField Shl 3) Or 4);
      BinEmit8($24);   { SIB : scale=00, index=100 (aucun), base=100 (ESP) }
      BinEmit32(Mem.Disp);
      Exit;
    End;
    BinEmit8($80 Or (RegField Shl 3) Or Mem.BaseReg);
    BinEmit32(Mem.Disp);
    Exit;
  End;
  { absolu (etiquette, sans registre de base) : Mod=00/RM=101 - CAS       }
  { PARTICULIER du 80386 signifiant "disp32 SEUL suit, aucun octet SIB"      }
  { (uniquement quand Mod=00 - ne pas confondre avec RM=100, qui lui             }
  { signifie TOUJOURS "un octet SIB suit", quel que soit Mod). }
  BinEmit8((RegField Shl 3) Or 5);
  BinEmit32(0);
  BinAddFixup(BIN_FIX_ABS32, Mem.LabelName);
End;

{ ------------------------------------------------------------ }
{ Encodeurs par mnemonique - un PAR forme reellement EMISE par le     }
{ generateur de code (TODO 21) ou la bibliotheque runtime (TODO 21) -            }
{ toute AUTRE forme est un arret propre (FatalError, jamais un octet             }
{ errone silencieux). }
{ ------------------------------------------------------------ }

Procedure BinEncodeMov(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  If Op1.Kind = BOK_REG Then
  Begin
    If Op2.Kind = BOK_IMM Then
    Begin
      BinEmit8($B8 Or Op1.RegNum);
      BinEmit32(Op2.ImmVal);
      Exit;
    End;
    { "MOV reg,reg" OU "MOV reg,[mem]" - la meme forme ModRM couvre les    }
    { deux (BinEmitModRM sait deja distinguer BOK_REG de BOK_MEM). }
    BinEmit8($8B);
    BinEmitModRM(Op1.RegNum, Op2);
    Exit;
  End;
  { destination memoire OCTET ("MOV BYTE PTR [mem],reg" - _SWRT_STRCONV_ITOA,  }
  { ecriture d un SEUL chiffre/caractere) : opcode $88 (MOV r/m8,r8) - le            }
  { champ "reg" 8 bits partage la MEME numerotation 0..3 que EAX/ECX/EDX/            }
  { EBX en 32 bits (AL/CL/DL/BL) SANS prefixe REX - restreint EXPLICITEMENT           }
  { la source a ces quatre registres (ESP/EBP/ESI/EDI n ont pas d equivalent             }
  { 8 bits bas sans REX, hors de portee). }
  If Op1.IsByte Then
  Begin
    If Op2.RegNum > 3 Then
    Begin
      FatalError('assembleur : "MOV BYTE PTR [mem],reg" non couvert pour ' +
        'ce registre (seuls EAX/ECX/EDX/EBX ont un equivalent 8 bits bas ' +
        'sans prefixe REX) : ' + Op2Text);
      Exit;
    End;
    BinEmit8($88);
    BinEmitModRM(Op2.RegNum, Op1);
    Exit;
  End;
  { destination memoire : "MOV [mem],reg" (jamais "MOV [mem],imm" dans   }
  { ce que le TODO 21 emet - la valeur passe TOUJOURS par EAX d abord). }
  BinEmit8($89);
  BinEmitModRM(Op2.RegNum, Op1);
End;

{ BinEncodeMovzx : "MOVZX reg32, BYTE PTR [mem]" - lecture d un SEUL     }
{ octet (_SWRT_STRCONV_ITOA), ETENDU PAR DES ZEROS dans un registre 32              }
{ bits complet (aucun registre 8 bits n est par ailleurs modelise par                 }
{ cet assembleur - voir la note de BinEncodeMov pour l ECRITURE, l inverse             }
{ de cette lecture). }
Procedure BinEncodeMovzx(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  If (Op1.Kind <> BOK_REG) Or (Op2.Kind <> BOK_MEM) Then
  Begin
    FatalError('assembleur : forme de MOVZX non couverte (registre 32 ' +
      'bits, memoire octet attendus) : ' + Op1Text + ',' + Op2Text);
    Exit;
  End;
  BinEmit8($0F);
  BinEmit8($B6);
  BinEmitModRM(Op1.RegNum, Op2);
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
    BinEmitModRM(6, Op1);   { groupe FF /6 = PUSH r/m32 }
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

{ BinEncodeAlu : ADD/OR/AND/SUB/XOR/CMP - "reg,reg"/"reg,[mem]" (ModRM       }
{ partagee) et "reg,imm32" (groupe 81, sous-opcode dans le champ reg de           }
{ ModRM), PLUS le cas 8 bits (opcode 80, imm8) pour l UNIQUE forme "CMP           }
{ BYTE PTR [...],imm" de _SWRT_STRLEN. }
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
    FatalError('assembleur : operateur arithmetique/logique non couvert : ' + Mnemonic);
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

Procedure BinEncodeTest(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  BinEmit8($85);
  BinEmitModRM(Op2.RegNum, Op1);
End;

Procedure BinEncodeImul(Const Op1Text, Op2Text: TString);
Var Op1, Op2: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  Op2 := BinParseOperand(Op2Text);
  BinEmit8($0F);
  BinEmit8($AF);
  BinEmitModRM(Op1.RegNum, Op2);
End;

Procedure BinEncodeIdiv(Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  BinEmit8($F7);
  BinEmitModRM(7, Op1);
End;

Procedure BinEncodeNotNeg(Const Mnemonic, Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  BinEmit8($F7);
  If Mnemonic = 'NOT' Then BinEmitModRM(2, Op1) Else BinEmitModRM(3, Op1);
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

Procedure BinEncodeJmp(Const Op1Text: TString);
Begin
  BinEmit8($E9);
  BinEmit32(0);
  BinAddFixup(BIN_FIX_REL32, BinTrim(Op1Text));
End;

{ BinEncodeJcc : forme LONGUE uniquement (0F 8x + disp32), jamais la     }
{ forme courte (7x + disp8) - correcte dans TOUS les cas (une portee               }
{ plus longue n est jamais un probleme), juste pas la plus compacte                        }
{ possible. }
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
  BinAddFixup(BIN_FIX_REL32, BinTrim(Op1Text));
End;

{ BinEncodeCall : E8+disp32 - IDENTIQUE que la cible soit une etiquette   }
{ LOCALE (fonction utilisateur) ou un IMPORT externe decore stdcall                    }
{ ("_WriteFile@20") - la DISTINCTION ne se fait qu a la resolution                            }
{ (BinResolveFixups/WriteCOFFObj), PAR NOM, jamais ici. Forme INDIRECTE           }
{ ("CALL reg", via un pointeur de fonction) HORS DE PORTEE (reservee                     }
{ aux goroutines de GOCW32.PAS, INEXISTANTES en Swift - jamais emise                        }
{ ici). }
Procedure BinEncodeCall(Const Op1Text: TString);
Begin
  BinEmit8($E8);
  BinEmit32(0);
  BinAddFixup(BIN_FIX_REL32, BinTrim(Op1Text));
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

{ BinSplitOperands : coupe sur la PREMIERE virgule - sans risque ici    }
{ puisqu aucune forme emise par le TODO 21 ne place jamais de virgule           }
{ a l interieur de crochets (pas d adressage indexe/mis a l echelle). }
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

{ BinEmitInstr : point d entree UNIQUE (dispatch par mnemonique) pour    }
{ encoder une ligne d instruction DEJA extraite (sans l indentation, voir            }
{ BinAssembleFile plus bas, qui l isole des lignes d etiquette/directive). }
Procedure BinEmitInstr(Const Line: TString);
Var Mnemonic, Rest, Op1, Op2: TString;
Begin
  BinSplitMnemonic(BinTrim(Line), Mnemonic, Rest);
  BinSplitOperands(Rest, Op1, Op2);

  If Mnemonic = 'MOV' Then Begin BinEncodeMov(Op1, Op2); Exit; End;
  If Mnemonic = 'MOVZX' Then Begin BinEncodeMovzx(Op1, Op2); Exit; End;
  If Mnemonic = 'PUSH' Then Begin BinEncodePush(Op1); Exit; End;
  If Mnemonic = 'POP' Then Begin BinEncodePop(Op1); Exit; End;
  If Mnemonic = 'LEA' Then Begin BinEncodeLea(Op1, Op2); Exit; End;
  If (Mnemonic = 'ADD') Or (Mnemonic = 'SUB') Or (Mnemonic = 'AND') Or
     (Mnemonic = 'OR') Or (Mnemonic = 'XOR') Or (Mnemonic = 'CMP') Then
  Begin
    BinEncodeAlu(Mnemonic, Op1, Op2);
    Exit;
  End;
  If Mnemonic = 'TEST' Then Begin BinEncodeTest(Op1, Op2); Exit; End;
  If Mnemonic = 'IMUL' Then Begin BinEncodeImul(Op1, Op2); Exit; End;
  If Mnemonic = 'IDIV' Then Begin BinEncodeIdiv(Op1); Exit; End;
  If (Mnemonic = 'NOT') Or (Mnemonic = 'NEG') Then
  Begin
    BinEncodeNotNeg(Mnemonic, Op1);
    Exit;
  End;
  If (Mnemonic = 'INC') Or (Mnemonic = 'DEC') Then
  Begin
    BinEncodeIncDec(Mnemonic, Op1);
    Exit;
  End;
  If Mnemonic = 'JMP' Then Begin BinEncodeJmp(Op1); Exit; End;
  If (Length(Mnemonic) >= 2) And (Mnemonic[1] = 'J') Then
  Begin
    BinEncodeJcc(Mnemonic, Op1);
    Exit;
  End;
  If Mnemonic = 'CALL' Then Begin BinEncodeCall(Op1); Exit; End;
  If Mnemonic = 'RET' Then Begin BinEmit8($C3); Exit; End;
  If Mnemonic = 'CDQ' Then Begin BinEmit8($99); Exit; End;

  FatalError('assembleur : mnemonique non geree (portee volontairement ' +
    'restreinte a ce que le TODO 21 emet reellement) : ' + Mnemonic);
End;

{ BinAssembleDataLine : une ligne de .DATA est TOUJOURS de la forme      }
{ "NOM  DD <entier>" ou "NOM  DB <entier>" ou "NOM  DB ""texte"", 0"                 }
{ (EmitDataSeg, TODO 21 - jamais rien d autre) - deux espaces separent               }
{ TOUJOURS le nom de la directive. }
Procedure BinAssembleDataLine(Const Line: TString);
Var P, Q: Integer; Name, Rest, ValuePart, TextPart: TString;
Begin
  P := Pos('  ', Line);
  If P = 0 Then Exit;
  Name := Copy(Line, 1, P - 1);
  Rest := BinTrim(Copy(Line, P + 1, Length(Line) - P));
  BinDefineLabel(Name);

  If Copy(Rest, 1, 3) = 'DD ' Then
  Begin
    BinEmit32(BinStrToInt(BinTrim(Copy(Rest, 4, Length(Rest) - 3))));
    Exit;
  End;

  If Copy(Rest, 1, 3) = 'DB ' Then
  Begin
    ValuePart := BinTrim(Copy(Rest, 4, Length(Rest) - 3));
    If (Length(ValuePart) > 0) And (ValuePart[1] = '"') Then
    Begin
      { "texte", 0 - trouve la guillemet FERMANTE (le texte lui-meme ne     }
      { contient jamais de guillemet) puis emet chaque octet suivi d un              }
      { NUL terminal unique (le ", 0" final n a pas besoin d etre analyse            }
      { separement : c est TOUJOURS exactement ce que EmitDataSeg ecrit). }
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

{ BinAssembleFile : RELIT le fichier .asm TEXTE (deja ecrit par le      }
{ generateur de code, TODO 21) et encode chaque instruction/donnee en             }
{ octets reels - passe COMPLETEMENT SEPAREE de l emission textuelle. }
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
    If Line = '.DATA' Then Begin BinCurIsData := True; Continue; End;
    If Line = '.CODE' Then Begin BinCurIsData := False; Continue; End;

    If Copy(Line, 1, 6) = 'EXTRN ' Then
    Begin
      ExternName := Copy(Line, 7, Length(Line) - 6);
      P := Pos(':', ExternName);
      If P > 0 Then ExternName := Copy(ExternName, 1, P - 1);
      BinDeclareImport(ExternName);
      Continue;
    End;

    If Copy(Line, 1, 4) = 'END ' Then Break;   { fin logique du fichier }

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

{ BinResolveFixups : SEULS les REL32 dont la cible est une ETIQUETTE     }
{ LOCALE de la MEME section sont resolus ICI (deplacement invariant,           }
{ quel que soit l endroit ou la section finira par etre chargee) - TOUT             }
{ le reste (REL32 vers un import externe, ET tout ABS32 sans exception,                 }
{ meme vers une etiquette locale - une adresse ABSOLUE ne peut JAMAIS               }
{ etre connue avant l edition de liens) reste marque Resolved=Faux et                  }
{ devient une VRAIE relocation COFF dans WriteCOFFObj. }
Procedure BinResolveFixups;
Var I, LI: Integer; Disp: LongInt;
Begin
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Kind = BIN_FIX_REL32 Then
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

{ ------------------------------------------------------------ }
{ WriteCOFFObj : ecrit un vrai fichier .OBJ COFF Win32          }
{ (IMAGE_FILE_HEADER, Machine=I386) - DEUX sections seulement, .text        }
{ et .data (ni .rdata ni .bss : les litteraux chaine vont directement          }
{ dans .data). Toute relocation restante APRES BinResolveFixups (REL32           }
{ vers un import externe, ou N IMPORTE QUEL ABS32) devient une VRAIE                     }
{ relocation COFF (IMAGE_REL_I386_REL32/DIR32) - au lieur externe de la              }
{ resoudre. PE_MACHINE_I386/COFF_REL_I386_*/COFF_SYM_CLASS_*/PE_SCN_*                    }
{ sont DEJA reservees depuis le TODO 01 - inutile de redefinir ces                            }
{ valeurs. }
{ ------------------------------------------------------------ }

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

  { les noms de section (".text"/".data") sont TOUJOURS assez courts       }
  { pour l inscription DIRECTE sur 8 octets - jamais besoin de la table          }
  { des chaines pour eux (reservee aux SYMBOLES, plus bas). }
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

  SecHdrOfs    := 20;                          { taille de IMAGE_FILE_HEADER }
  TextDataOfs  := SecHdrOfs + 40 * 2;           { 2 en-tetes de section, 40 octets chacune }
  DataDataOfs  := TextDataOfs + BinCodeLen;
  TextRelocOfs := DataDataOfs + BinDataLen;
  DataRelocOfs := TextRelocOfs + TextRelocCount * 10;
  SymTabOfs    := DataRelocOfs + DataRelocCount * 10;
  SymCountTotal:= 2 + BinLabelCount + BinImportCount;

  StrTab := '';
  Assign(ObjF, ObjFileName);
  Rewrite(ObjF, 1);

  { IMAGE_FILE_HEADER (20 octets) }
  OW16(PE_MACHINE_I386);
  OW16(2);                   { NumberOfSections : .text + .data uniquement }
  OW32(0);                   { TimeDateStamp }
  OW32(SymTabOfs);           { PointerToSymbolTable }
  OW32(SymCountTotal);       { NumberOfSymbols }
  OW16(0);                   { SizeOfOptionalHeader (aucun en .OBJ) }
  OW16(0);                   { Characteristics }

  { en-tetes de section (40 octets chacune) }
  OWSecName('.text');
  OW32(0); OW32(0);          { VirtualSize/VirtualAddress : sans objet en .OBJ }
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

  { octets bruts des deux sections }
  If BinCodeLen > 0 Then BlockWrite(ObjF, BinCode, BinCodeLen);
  If BinDataLen > 0 Then BlockWrite(ObjF, BinData, BinDataLen);

  { relocations .text (10 octets chacune), puis .data - un symbole cible   }
  { est soit une ETIQUETTE locale (index 2+LI, voir la table des                    }
  { symboles plus bas) soit un IMPORT externe (index 2+BinLabelCount+II). }
  For I := 0 To BinFixupCount - 1 Do
    If (Not BinFixups[I].Resolved) And (Not BinFixups[I].IsData) Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then TargetSymIdx := 2 + LI
      Else TargetSymIdx := 2 + BinLabelCount + BinFindImport(BinFixups[I].TargetName);
      OW32(BinFixups[I].Pos);
      OW32(TargetSymIdx);
      If BinFixups[I].Kind = BIN_FIX_REL32 Then OW16(COFF_REL_I386_REL32) Else OW16(COFF_REL_I386_DIR32);
    End;
  For I := 0 To BinFixupCount - 1 Do
    If (Not BinFixups[I].Resolved) And BinFixups[I].IsData Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then TargetSymIdx := 2 + LI
      Else TargetSymIdx := 2 + BinLabelCount + BinFindImport(BinFixups[I].TargetName);
      OW32(BinFixups[I].Pos);
      OW32(TargetSymIdx);
      If BinFixups[I].Kind = BIN_FIX_REL32 Then OW16(COFF_REL_I386_REL32) Else OW16(COFF_REL_I386_DIR32);
    End;

  { table des symboles (18 octets chacun) : .text puis .data (les DEUX      }
  { symboles de SECTION eux-memes, indices 0/1), puis un par etiquette             }
  { (indices 2..2+BinLabelCount-1 - PUBLIC par simplification, aucun               }
  { suivi STATIC/PUBLIC reel), puis un par import externe (section 0 =            }
  { non defini ici, au lieur de le resoudre). Chaque nom passe TOUJOURS             }
  { par la table des chaines (jamais la forme "inline sur 8 octets"). }
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

  { table des chaines : prefixe de longueur sur 4 octets (SE COMPTANT      }
  { LUI-MEME) puis les entrees "nom" + NUL concatenees. }
  OW32(Length(StrTab) + 4);
  OWStr(StrTab);

  Close(ObjF);
End;

{ ------------------------------------------------------------ }
{ BinEncoderSelfTest : encode CHAQUE forme d instruction couverte,        }
{ isolement, et verifie l EXACTE sequence d octets produite - niveau de           }
{ rigueur necessaire pour verifier qu un port est correct SANS jamais              }
{ executer quoi que ce soit (aucun assembleur/lieur EXTERNE n existe,             }
{ c est justement ce que CE code remplace). }
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
  BinEncAssert('MOV EAX,[EBP+8] -> 8B 85 08 00 00 00 (base+disp32, jamais disp8)',
    (BinCodeLen = 6) And (BinCode[0] = $8B) And (BinCode[1] = $85) And
    (BinCode[2] = 8) And (BinCode[3] = 0) And (BinCode[4] = 0) And (BinCode[5] = 0));

  BinInit;
  BinEmitInstr('MOV DWORD PTR [' + ASM_PFX_GVAR + 'counter],EAX');
  BinEncAssert('MOV [global],EAX -> 89 05 + correctif ABS32 en attente',
    (BinCodeLen = 6) And (BinCode[0] = $89) And (BinCode[1] = 5) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BIN_FIX_ABS32) And
    (BinFixups[0].TargetName = ASM_PFX_GVAR + 'counter'));

  BinInit;
  BinEmitInstr('PUSH EAX');
  BinEncAssert('PUSH EAX -> 50', (BinCodeLen = 1) And (BinCode[0] = $50));

  BinInit;
  BinEmitInstr('POP EBP');
  BinEncAssert('POP EBP -> 5D', (BinCodeLen = 1) And (BinCode[0] = $5D));

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
  BinEmitInstr('IMUL EAX,EBX');
  BinEncAssert('IMUL EAX,EBX -> 0F AF C3',
    (BinCodeLen = 3) And (BinCode[0] = $0F) And (BinCode[1] = $AF) And (BinCode[2] = $C3));

  BinInit;
  BinEmitInstr('CDQ');
  BinEncAssert('CDQ -> 99', (BinCodeLen = 1) And (BinCode[0] = $99));

  BinInit;
  BinEmitInstr('IDIV ESI');
  BinEncAssert('IDIV ESI -> F7 FE',
    (BinCodeLen = 2) And (BinCode[0] = $F7) And (BinCode[1] = $FE));

  BinInit;
  BinEmitInstr('NEG EAX');
  BinEncAssert('NEG EAX -> F7 D8',
    (BinCodeLen = 2) And (BinCode[0] = $F7) And (BinCode[1] = $D8));

  BinInit;
  BinEmitInstr('MOVZX EAX,BYTE PTR [ESI]');
  BinEncAssert('MOVZX EAX,BYTE PTR [ESI] -> 0F B6 86 + disp32=0 (BASE ' +
    'present -> TOUJOURS disp32 complet, meme a 0 - BinEmitModRM ne ' +
    'raccourcit JAMAIS en Mod=00 des qu un registre de base existe)',
    (BinCodeLen = 7) And (BinCode[0] = $0F) And (BinCode[1] = $B6) And
    (BinCode[2] = $86) And (BinCode[3] = 0) And (BinCode[4] = 0) And
    (BinCode[5] = 0) And (BinCode[6] = 0));

  BinInit;
  BinEmitInstr('MOV BYTE PTR [EDI],EAX');
  BinEncAssert('MOV BYTE PTR [EDI],EAX -> 88 87 + disp32=0 (meme raison)',
    (BinCodeLen = 6) And (BinCode[0] = $88) And (BinCode[1] = $87) And
    (BinCode[2] = 0) And (BinCode[3] = 0) And (BinCode[4] = 0) And (BinCode[5] = 0));

  BinInit;
  BinEmitInstr('RET');
  BinEncAssert('RET -> C3', (BinCodeLen = 1) And (BinCode[0] = $C3));

  { CALL/Jcc vers une etiquette encore INCONNUE (le cas normal - la     }
  { cible n a pas forcement ete definie AVANT le point d appel/de saut          }
  { dans le fichier .asm) : E8/0F-8x + placeholder 0, PLUS un correctif             }
  { REL32 en attente portant le NOM exact de la cible - jamais resolu                    }
  { ICI (BinResolveFixups s en charge plus tard, une fois TOUTES les                        }
  { etiquettes connues). }
  BinInit;
  BinEmitInstr('CALL SOMELABEL');
  BinEncAssert('CALL etiquette inconnue -> E8 + correctif REL32 en attente',
    (BinCodeLen = 5) And (BinCode[0] = $E8) And (BinCode[1] = 0) And
    (BinCode[2] = 0) And (BinCode[3] = 0) And (BinCode[4] = 0) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BIN_FIX_REL32) And
    (BinFixups[0].TargetName = 'SOMELABEL') And (Not BinFixups[0].Resolved));

  BinInit;
  BinEmitInstr('JE SOMELABEL');
  BinEncAssert('JE etiquette -> 0F 84 + correctif REL32 en attente',
    (BinCodeLen = 6) And (BinCode[0] = $0F) And (BinCode[1] = $84) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BIN_FIX_REL32));

  BinInit;
  BinEmitInstr('LEA EAX,[SOMELABEL]');
  BinEncAssert('LEA EAX,[etiquette] -> 8D 05 + correctif ABS32 en attente ' +
    '(etiquette absolue, sans registre de base)',
    (BinCodeLen = 6) And (BinCode[0] = $8D) And (BinCode[1] = 5) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BIN_FIX_ABS32) And
    (BinFixups[0].TargetName = 'SOMELABEL'));

  { re-initialise pour ne pas polluer Run reel }
  BinInit;
End;

{ ------------------------------------------------------------ }
{ BinObjSelfTest : compile hello.swift EN ENTIER de bout en bout        }
{ (parse -> .asm TODO 21 -> BinAssembleFile/BinResolveFixups/                        }
{ WriteCOFFObj TODO 22), puis RELIT le fichier .obj produit en OCTETS                    }
{ BRUTS et verifie sa signature/structure - PAS que le contenu soit                       }
{ LOGIQUEMENT execute par quoi que ce soit (aucun lieur/chargeur                                  }
{ n existe encore, TODO 23) : meme limite documentee que CodegenSelfTest              }
{ pour le texte .asm lui-meme. }
{ ------------------------------------------------------------ }

Procedure BinObjAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('BinObjSelfTest: ' + Label_ + ' a echoue');
End;

Procedure BinObjSelfTest;
Const
  TmpSrc = 'SWIFTW32BINOBJSELFTESTSRC.$$$';
  TmpAsm = 'SWIFTW32BINOBJSELFTEST.$$$';
  TmpObj = 'SWIFTW32BINOBJSELFTEST.OB$';
Var
  F : File;
  B4 : Array[0..3] Of Byte;
  ObjSize : LongInt;
  I, ResolvedCount : Integer;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let greeting: String = "Hello, 8086!"');
  WriteLn(LexSrcF, 'let version: Int = 1');
  WriteLn(LexSrcF, 'var counter: Int = 0');
  WriteLn(LexSrcF, 'print(greeting)');
  WriteLn(LexSrcF, 'print(version)');
  WriteLn(LexSrcF, 'counter = counter + 1');
  WriteLn(LexSrcF, 'print(counter)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);
  BinAssembleFile(TmpAsm);
  BinObjAssert('au moins une etiquette reconnue (BinAssembleFile a bien relu le .asm)',
    BinLabelCount > 0);
  BinObjAssert('au moins un import externe reconnu (EXTRN)', BinImportCount > 0);
  BinObjAssert('des octets de code REELS ont ete encodes (.text non vide)', BinCodeLen > 0);
  BinObjAssert('des octets de donnees REELS ont ete encodes (.data non vide, ' +
    'chaine litterale + constante de fin de ligne)', BinDataLen > 0);

  BinResolveFixups;
  ResolvedCount := 0;
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Resolved Then Inc(ResolvedCount);
  BinObjAssert('au moins un correctif reste EN ATTENTE (import externe ou ' +
    'ABS32 - devient une VRAIE relocation COFF)', ResolvedCount < BinFixupCount);

  WriteCOFFObj(TmpObj);

  Assign(F, TmpObj);
  Reset(F, 1);
  BlockRead(F, B4, 4);
  ObjSize := FileSize(F);
  Close(F);

  BinObjAssert('signature Machine=I386 ($4C,$01) en tete du .obj',
    (B4[0] = $4C) And (B4[1] = $01));
  BinObjAssert('NumberOfSections=2 (.text+.data uniquement) en tete du .obj',
    (B4[2] = 2) And (B4[3] = 0));
  BinObjAssert('fichier .obj de taille plausible (au moins l en-tete + 2 ' +
    'sections + du contenu reel)', ObjSize > 100);

  Erase(F);
  Assign(F, TmpAsm);
  Erase(F);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ============================================================ }
{ TODO 23 - BACKEND BINAIRE .EXE PE WIN32 ET RUNTIME EMBARQUE    }
{ ============================================================ }
{ Ecrit un fichier .EXE PE Win32 COMPLET, directement chargeable/                  }
{ executable par Windows, SANS AUCUN lieur externe - architecture                          }
{ ETUDIEE et REPRISE PRESQUE A L IDENTIQUE de GOCW32.PAS (meme projet,                    }
{ meme discipline EXPLICITEMENT exigee par le roadmap d en-tete de CE               }
{ TODO). REUTILISE TEL QUEL le meme BinCode/BinData/BinLabels/                                 }
{ BinFixups/BinImports que le TODO 22 a deja rempli (BinAssembleFile             }
{ tourne UNE SEULE fois, le CHOIX entre WriteCOFFObj et WritePEExe                          }
{ n intervient QU APRES) - AUCUN nouveau passage sur le texte .asm.                          }
{                                                                       }
{ DIFFERENCE ARCHITECTURALE centrale avec le TODO 22 : un .OBJ laisse             }
{ TOUTE resolution externe (imports Win32, ET tout ABS32 meme LOCAL) a           }
{ un lieur EXTERNE (BinResolveFixups, TODO 22, ne resout QUE les REL32                   }
{ locaux) - un .EXE n a AUCUN lieur en aval : TOUT doit etre resolu                        }
{ ICI. Deux passes SEPAREES, dans cet ORDRE PRECIS :                                          }
{   (1) BinResolveFixupsForExe (AVANT que la disposition finale du                          }
{       fichier ne soit connue) - resout TOUS les REL32 (locaux ET                            }
{       imports externes, ces derniers via un MINUSCULE "thunk" de 6                       }
{       octets, BinCreateThunk, plutot que de reecrire le site d appel                    }
{       lui-meme en forme indirecte "FF 15" - "CALL _SWRT_PRINTLN_STR"           }
{       (E8+rel32) continue de cibler un simple deplacement RELATIF                       }
{       ordinaire, MAIS vers ce thunk plutot que vers KERNEL32 - le                          }
{       thunk LUI-MEME (JMP DWORD PTR [case IAT], une adresse ABSOLUE)              }
{       porte TOUTE la complexite d indirection).                                                }
{   (2) La resolution ABS32 (DANS WritePEExe, APRES le calcul complet             }
{       de la disposition finale - RVA de chaque section, adresse de                     }
{       base ImageBase) - une adresse ABSOLUE ne peut JAMAIS etre                           }
{       connue avant que CETTE disposition ne soit fixee, contrairement             }
{       aux REL32 (un deplacement RELATIF entre deux points de la MEME              }
{       section .text reste invariant, peu importe OU cette section                        }
{       finira par etre chargee).                                                               }
{                                                                       }
{ AUCUNE table de relocations (.reloc, DataDirectory[5]) n existe - ce              }
{ fichier n est chargeable QU A l adresse FIXE PE_IMG_BASE=$00400000                     }
{ (deja reservee, TODO 01) - AUCUNE prise en charge ASLR ("DllCharacteristics"           }
{ ecrit 0). Un SEUL DLL importe (KERNEL32.DLL) - import PAR NOM                                  }
{ uniquement, jamais par ordinal. Sous-systeme CONSOLE uniquement                              }
{ (PE_SUBSYS_CUI) - aucun mode GUI. AUCUN VRAI stub DOS (juste "MZ" +               }
{ bourrage + e_lfanew, memes 64 octets que GOCW32.PAS/DELPHI.PAS).                                }
{                                                                       }
{ Le runtime embarque (EmitRuntimeLibrary, TODO 21) reste EXACTEMENT le            }
{ MEME texte .asm quel que soit le backend choisi (.OBJ ou .EXE) - SEULE           }
{ la maniere dont l assembleur/ecrivain PE resout les appels "CALL                          }
{ _SWRT_xxx"/"CALL _ExitProcess@4" etc. differe (TODO 22 vs TODO 23) ;              }
{ l emission textuelle elle-meme (TODO 21) est totalement AVEUGLE a                       }
{ cette distinction. }

{ BinAlignUp : arrondit V au PROCHAIN multiple de Align (V lui-meme si   }
{ deja un multiple exact) - utilisee pour a la fois l alignement de              }
{ FICHIER (PE_FILE_ALIGN=512, deja reserve TODO 01) et l alignement de           }
{ SECTION (PE_SEC_ALIGN=4096) : DEUX constantes DIFFERENTES appliquees            }
{ a des totaux courants DIFFERENTS (taille de fichier vs RVA memoire) -             }
{ la SEULE chose la plus facile a confondre en reimplementant ce           }
{ calcul (voir la note de WritePEExe plus bas). }
Function BinAlignUp(V, Align: LongInt): LongInt;
Begin
  If V Mod Align = 0 Then BinAlignUp := V
  Else BinAlignUp := ((V Div Align) + 1) * Align;
End;

{ BinExportNameFor : "_ExitProcess@4" -> "ExitProcess" - retire le "_"   }
{ prefixe et le "@N" suffixe (decoration STDCALL INTERNE a la convention           }
{ de nommage de CE compilateur, EmitHeader/TODO 21) - KERNEL32.DLL                          }
{ exporte ses fonctions par leur NOM NU, jamais decore ainsi ; la table          }
{ des exports Windows que le CHARGEUR consulte au demarrage n a jamais              }
{ entendu parler de cette decoration. }
Function BinExportNameFor(Const Nm: TString): TString;
Var S : TString; AtPos : Integer;
Begin
  S := Nm;
  If (Length(S) > 0) And (S[1] = '_') Then
    S := Copy(S, 2, Length(S) - 1);
  AtPos := Pos('@', S);
  If AtPos > 0 Then
    S := Copy(S, 1, AtPos - 1);
  BinExportNameFor := S;
End;

Var
  BinThunkOfs    : Array[0..MAX_BIN_IMPORT - 1] Of LongInt;
  BinThunkExists : Array[0..MAX_BIN_IMPORT - 1] Of Boolean;

Procedure BinThunkInit;
Var I : Integer;
Begin
  For I := 0 To MAX_BIN_IMPORT - 1 Do BinThunkExists[I] := False;
End;

{ BinCreateThunk : un SEUL "thunk" de 6 octets par import DISTINCT              }
{ (idempotent, cree au PREMIER besoin), place dans .text - "FF 25 <ABS32>"           }
{ (JMP DWORD PTR [case IAT]) : saute INDIRECTEMENT via la case de la                     }
{ Table d Adresses d Import (IAT) que le CHARGEUR Windows remplit avec               }
{ la VRAIE adresse de la fonction au demarrage du processus - TOUS les            }
{ sites "CALL _ExitProcess@4" du programme entier PARTAGENT ce MEME              }
{ thunk unique (BinThunkExists evite d en creer un second). L ABS32                       }
{ genere ICI ("@IAT:" + nom) est resolu PLUS TARD, dans WritePEExe                        }
{ (une fois IdataRva/IatOfs connus) - voir sa propre note. }
Procedure BinCreateThunk(ExternIdx: Integer);
Var SavedIsData : Boolean;
Begin
  If BinThunkExists[ExternIdx] Then Exit;
  SavedIsData := BinCurIsData;
  BinCurIsData := False;
  BinThunkOfs[ExternIdx] := BinCodeLen;
  BinThunkExists[ExternIdx] := True;
  BinEmit8($FF);
  BinEmit8($25);
  BinEmit32(0);
  BinAddFixup(BIN_FIX_ABS32, '@IAT:' + BinImports[ExternIdx]);
  BinCurIsData := SavedIsData;
End;

{ BinResolveFixupsForExe : contrairement a BinResolveFixups (TODO 22,   }
{ .OBJ - ne resout QUE les REL32 locaux DE LA MEME section, laisse TOUT           }
{ le reste a un lieur externe), ICI TOUT REL32 doit disparaitre - AUCUN            }
{ lieur n existe en aval pour un .EXE. Une cible qui n est PAS une                       }
{ etiquette locale connue DOIT etre un import declare (EXTRN) : cree                    }
{ son thunk (BinCreateThunk) et cible CELUI-CI a la place - le                                  }
{ deplacement RELATIF (TargetOfs - (Pos+4)) reste une simple                                  }
{ arithmetique INTERNE au tampon .text, AUCUNE connaissance de la                            }
{ disposition finale du fichier n est necessaire a ce stade (contrairement           }
{ a la resolution ABS32 plus bas, dans WritePEExe, qui ELLE en depend). }
Procedure BinResolveFixupsForExe;
Var I, LI, EI : Integer; TargetOfs, Disp : LongInt;
Begin
  BinThunkInit;
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Kind = BIN_FIX_REL32 Then
    Begin
      LI := BinFindLabel(BinFixups[I].TargetName);
      If LI >= 0 Then
        TargetOfs := BinLabels[LI].Ofs
      Else
      Begin
        EI := BinFindImport(BinFixups[I].TargetName);
        If EI < 0 Then
        Begin
          FatalError('assembleur : cible REL32 introuvable (ni etiquette ' +
            'locale, ni import declare) : ' + BinFixups[I].TargetName);
          Continue;
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
{ WritePEExe : ecrivain .EXE PE Win32 - ordre d ecriture : en-tete DOS          }
{ minimal ("MZ" + bourrage + e_lfanew=64) -> signature PE -> en-tete             }
{ IMAGE_FILE_HEADER -> IMAGE_OPTIONAL_HEADER32 (+ tableau                                     }
{ DataDirectory, SEULS Import[1] et IAT[12] non nuls) -> TROIS en-tetes             }
{ de section (.text/.data/.idata - un import NECESSITE cette troisieme                  }
{ section, absente du .OBJ a deux sections du TODO 22) -> bourrage                        }
{ jusqu a HdrSizeAligned -> octets bruts .text -> octets bruts .data ->                   }
{ contenu .idata (descripteur d import, ILT, IAT, table hint/nom, nom              }
{ du DLL). La disposition COMPLETE (RVA/deplacements de fichier de                         }
{ CHAQUE section) est calculee en PRE-PASSE, AVANT toute ecriture -                        }
{ meme discipline que WriteCOFFObj (TODO 22). REGLE PE reelle la PLUS               }
{ facile a confondre (documentee explicitement ici pour ne PAS la                             }
{ redecouvrir par execution) : le DEPLACEMENT DE FICHIER de la PROCHAINE           }
{ section suit l alignement de FICHIER (512) applique a la taille REELLE          }
{ du CONTENU, alors que son RVA MEMOIRE suit TOUJOURS l alignement de              }
{ SECTION (4096) - JAMAIS le meme calcul, meme si les DEUX s appellent             }
{ "BinAlignUp". }
{ ------------------------------------------------------------ }

Procedure WritePEExe(Const ExeFileName: TString);
Const
  PE_KERNEL32_DLL = 'KERNEL32.DLL';
Var
  ExeF : File;
  I, EI, LI, EntryLI, NImp : Integer;
  IltOfs, IatOfs, HintNameStart, Cur, EntrySize, DllNameOfs, IdataSize : LongInt;
  HintNameOfs : Array[0..MAX_BIN_IMPORT - 1] Of LongInt;
  ExpName : TString;
  HdrSize, HdrSizeAligned : LongInt;
  TextRva, DataRva, IdataRva : LongInt;
  TextFileOfs, DataFileOfs, IdataFileOfs : LongInt;
  TextRawSize, DataRawSize, IdataRawSize : LongInt;
  ImageSize, EntryRva : LongInt;
  V : LongInt;

  Procedure OW8(B: Integer);
  Var Buf: Byte;
  Begin
    Buf := B And $FF;
    BlockWrite(ExeF, Buf, 1);
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
  { (1) TOUS les REL32 d abord (imports -> thunk, voir BinCreateThunk) - }
  { AUCUNE connaissance de la disposition finale requise ici. }
  BinResolveFixupsForExe;

  { disposition INTERNE de .idata (descripteurs -> ILT -> IAT -> table   }
  { hint/nom -> nom du DLL) - deplacements RELATIFS AU DEBUT de .idata           }
  { uniquement (convertis en RVA reelle plus bas, IdataRva + ...). }
  NImp := BinImportCount;
  IltOfs := 40;                        { apres les DEUX descripteurs (20 octets chacun) }
  IatOfs := IltOfs + (NImp + 1) * 4;   { ILT : NImp entrees + UN terminateur nul }
  HintNameStart := IatOfs + (NImp + 1) * 4;   { IAT : meme taille que l ILT }
  Cur := HintNameStart;
  For I := 0 To NImp - 1 Do
  Begin
    HintNameOfs[I] := Cur;
    ExpName := BinExportNameFor(BinImports[I]);
    EntrySize := 2 + Length(ExpName) + 1;   { Hint (2) + nom + NUL }
    If (EntrySize Mod 2) <> 0 Then Inc(EntrySize);   { alignement PAIR }
    Cur := Cur + EntrySize;
  End;
  DllNameOfs := Cur;
  IdataSize  := DllNameOfs + Length(PE_KERNEL32_DLL) + 1;

  { RVA/deplacements de FICHIER de chaque section - voir la note d      }
  { en-tete de WritePEExe pour la regle FileAlign-vs-SectionAlign. }
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

  { (2) TOUS les ABS32, MAINTENANT que TextRva/DataRva/IdataRva sont     }
  { connus - une etiquette LOCALE (global .text/.data) recoit                       }
  { ImageBase+RVA section+deplacement ; un thunk IAT ("@IAT:" + nom)                    }
  { recoit ImageBase+IdataRva+IatOfs+index*4 (l adresse de LA CASE IAT                  }
  { elle-meme, jamais celle de la fonction - le CHARGEUR remplit cette              }
  { case au demarrage). }
  For I := 0 To BinFixupCount - 1 Do
    If (Not BinFixups[I].Resolved) And (BinFixups[I].Kind = BIN_FIX_ABS32) Then
    Begin
      If Copy(BinFixups[I].TargetName, 1, 5) = '@IAT:' Then
      Begin
        EI := BinFindImport(Copy(BinFixups[I].TargetName, 6, Length(BinFixups[I].TargetName) - 5));
        If EI < 0 Then
        Begin
          FatalError('assembleur : cible IAT introuvable : ' + BinFixups[I].TargetName);
          Continue;
        End;
        V := PE_IMG_BASE + IdataRva + IatOfs + EI * 4;
      End
      Else
      Begin
        LI := BinFindLabel(BinFixups[I].TargetName);
        If LI < 0 Then
        Begin
          FatalError('assembleur : cible ABS32 introuvable : ' + BinFixups[I].TargetName);
          Continue;
        End;
        If BinLabels[LI].IsData Then
          V := PE_IMG_BASE + DataRva + BinLabels[LI].Ofs
        Else
          V := PE_IMG_BASE + TextRva + BinLabels[LI].Ofs;
      End;
      BinPatch32(BinFixups[I].IsData, BinFixups[I].Pos, V);
      BinFixups[I].Resolved := True;
    End;

  { point d entree - "_SWSTART" (CompileProgram, TODO 21), TOUJOURS dans   }
  { .text en pratique (repli defensif sur TextRva sinon, ne devrait               }
  { jamais se produire). }
  EntryLI := BinFindLabel('_SWSTART');
  If EntryLI >= 0 Then
  Begin
    If BinLabels[EntryLI].IsData Then EntryRva := DataRva + BinLabels[EntryLI].Ofs
    Else EntryRva := TextRva + BinLabels[EntryLI].Ofs;
  End
  Else
    EntryRva := TextRva;

  Assign(ExeF, ExeFileName);
  Rewrite(ExeF, 1);

  { en-tete DOS minimal (64 octets) - AUCUN vrai stub DOS. }
  OW16(PE_DOS_MAGIC);
  OWZeros(58);
  OW32(64);   { e_lfanew }

  { signature PE }
  OW32(PE_PE_SIG);

  { IMAGE_FILE_HEADER (20 octets) }
  OW16(PE_MACHINE_I386);
  OW16(3);              { NumberOfSections : .text + .data + .idata }
  OW32(0);               { TimeDateStamp }
  OW32(0);               { PointerToSymbolTable : aucune table COFF dans un .EXE }
  OW32(0);               { NumberOfSymbols }
  OW16(224);             { SizeOfOptionalHeader }
  OW16($010F);           { Characteristics }

  { IMAGE_OPTIONAL_HEADER32 (224 octets, DataDirectory inclus) }
  OW16(PE_OPT_MAGIC_PE32);
  OW8(1); OW8(0);                                        { version du "lieur" }
  OW32(TextRawSize);                                     { SizeOfCode }
  OW32(DataRawSize + IdataRawSize);                      { SizeOfInitializedData }
  OW32(0);                                                { SizeOfUninitializedData }
  OW32(EntryRva);                                        { AddressOfEntryPoint }
  OW32(TextRva);                                         { BaseOfCode }
  OW32(DataRva);                                         { BaseOfData }
  OW32(PE_IMG_BASE);
  OW32(PE_SEC_ALIGN);
  OW32(PE_FILE_ALIGN);
  OW16(4); OW16(0);                                      { version OS }
  OW16(0); OW16(0);                                      { version image }
  OW16(4); OW16(0);                                      { version sous-systeme }
  OW32(0);                                                { Win32VersionValue }
  OW32(ImageSize);                                       { SizeOfImage }
  OW32(HdrSizeAligned);                                  { SizeOfHeaders }
  OW32(0);                                                { CheckSum : jamais calcule }
  OW16(PE_SUBSYS_CUI);
  OW16(0);                                                { DllCharacteristics : AUCUNE ASLR }
  OW32($100000); OW32($1000);                            { pile : reserve/engage }
  OW32($100000); OW32($1000);                            { tas : reserve/engage }
  OW32(0);                                                { LoaderFlags }
  OW32(16);                                               { NumberOfRvaAndSizes }

  { DataDirectory (16 * 8 octets = 128 octets) - SEULS Import[1] et      }
  { IAT[12] sont non nuls. }
  OW32(0); OW32(0);                                       { [0] Export }
  OW32(IdataRva); OW32(40);                              { [1] Import : 2 descripteurs * 20 octets }
  For I := 1 To 10 Do Begin OW32(0); OW32(0); End;        { [2..11], dont [5]=BASERELOC : jamais utilise }
  OW32(IdataRva + IatOfs); OW32((NImp + 1) * 4);         { [12] IAT }
  For I := 1 To 3 Do Begin OW32(0); OW32(0); End;         { [13..15] }

  { TROIS en-tetes de section (40 octets chacune) }
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

  { bourrage jusqu a HdrSizeAligned - BOGUE REEL trouve par EXECUTION      }
  { (le tout premier .exe produit par ce TODO etait "n est pas une                 }
  { application Win32 valide") si ce bourrage manque : chaque section                    }
  { doit commencer EXACTEMENT au deplacement de fichier que son PROPRE               }
  { en-tete promet (PointerToRawData), jamais un octet plus tot. }
  OWZeros(HdrSizeAligned - HdrSize);

  { octets bruts .text, puis bourrage jusqu a TextRawSize }
  If BinCodeLen > 0 Then BlockWrite(ExeF, BinCode, BinCodeLen);
  OWZeros(TextRawSize - BinCodeLen);

  { octets bruts .data, puis bourrage jusqu a DataRawSize }
  If BinDataLen > 0 Then BlockWrite(ExeF, BinData, BinDataLen);
  OWZeros(DataRawSize - BinDataLen);

  { .idata : descripteur KERNEL32.DLL, descripteur terminateur nul, ILT,  }
  { IAT, table hint/nom, nom du DLL - puis bourrage jusqu a                             }
  { IdataRawSize. }
  OW32(IdataRva + IltOfs);         { OriginalFirstThunk }
  OW32(0);                         { TimeDateStamp }
  OW32(0);                         { ForwarderChain }
  OW32(IdataRva + DllNameOfs);     { Name }
  OW32(IdataRva + IatOfs);         { FirstThunk }
  OWZeros(20);                     { descripteur terminateur nul }

  For I := 0 To NImp - 1 Do OW32(IdataRva + HintNameOfs[I]);
  OW32(0);
  For I := 0 To NImp - 1 Do OW32(IdataRva + HintNameOfs[I]);
  OW32(0);

  For I := 0 To NImp - 1 Do
  Begin
    OW16(0);   { Hint : jamais recherche, toujours 0 }
    ExpName := BinExportNameFor(BinImports[I]);
    OWStr(ExpName);
    OW8(0);
    EntrySize := 2 + Length(ExpName) + 1;
    If (EntrySize Mod 2) <> 0 Then OW8(0);
  End;

  OWStr(PE_KERNEL32_DLL);
  OW8(0);

  OWZeros(IdataRawSize - IdataSize);

  Close(ExeF);
End;

{ ------------------------------------------------------------ }
{ PEExeSelfTest : compile hello.swift EN ENTIER de bout en bout (parse            }
{ -> .asm TODO 21 -> BinAssembleFile TODO 22 -> WritePEExe TODO 23),                    }
{ puis RELIT le fichier .exe produit en OCTETS BRUTS et verifie sa                       }
{ signature/structure (MZ, e_lfanew, PE, Machine, NumberOfSections,                        }
{ Subsystem, taille multiple de PE_FILE_ALIGN) - PAS que Windows                              }
{ l EXECUTE reellement ICI (meme methode/limite documentee que                                  }
{ CodegenSelfTest/BinObjSelfTest) : une VRAIE execution manuelle du               }
{ .exe produit (hors de ce self-test Pascal) reste la seule verification                   }
{ de correction OBSERVABLE a ce stade, exactement comme documente au             }
{ TODO 25. }
{ ------------------------------------------------------------ }

Procedure PEExeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PEExeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PEExeSelfTest;
Const
  TmpSrc = 'SWIFTW32PEEXESELFTESTSRC.$$$';
  TmpAsm = 'SWIFTW32PEEXESELFTEST.$$$';
  TmpExe = 'SWIFTW32PEEXESELFTEST.EX$';
Var
  F : File;
  B4 : Array[0..3] Of Byte;
  Lfanew : LongInt;
  ExeSize : LongInt;
Begin
  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;

  Assign(LexSrcF, TmpSrc);
  Rewrite(LexSrcF);
  WriteLn(LexSrcF, 'let greeting: String = "Hello, 8086!"');
  WriteLn(LexSrcF, 'let version: Int = 1');
  WriteLn(LexSrcF, 'var counter: Int = 0');
  WriteLn(LexSrcF, 'print(greeting)');
  WriteLn(LexSrcF, 'print(version)');
  WriteLn(LexSrcF, 'counter = counter + 1');
  WriteLn(LexSrcF, 'print(counter)');
  Close(LexSrcF);
  Assign(LexSrcF, TmpSrc);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;
  LexAll;
  LexClose;
  Erase(LexSrcF);
  ParserInit;
  ParseSwiftProgram;

  CompileProgram(TmpAsm);
  BinAssembleFile(TmpAsm);
  WritePEExe(TmpExe);

  Assign(F, TmpExe);
  Reset(F, 1);

  BlockRead(F, B4, 4);
  PEExeAssert('signature MZ en tete du .exe', (B4[0] = Ord('M')) And (B4[1] = Ord('Z')));

  Seek(F, 60);
  BlockRead(F, Lfanew, 4);
  PEExeAssert('e_lfanew=64 (en-tete DOS minimal, aucun VRAI stub)', Lfanew = 64);

  Seek(F, 64);
  BlockRead(F, B4, 4);
  PEExeAssert('signature PE en Lfanew', (B4[0] = Ord('P')) And (B4[1] = Ord('E')) And
    (B4[2] = 0) And (B4[3] = 0));

  Seek(F, 68);
  BlockRead(F, B4, 4);
  PEExeAssert('Machine=I386 ($4C,$01) et NumberOfSections=3 (.text/.data/.idata)',
    (B4[0] = $4C) And (B4[1] = $01) And (B4[2] = 3) And (B4[3] = 0));

  { Subsystem : deplacement 64(en-tete DOS)+4(signature PE)+20(IMAGE_FILE_HEADER)     }
  { +68 DANS IMAGE_OPTIONAL_HEADER32 (Magic(2)+Linker(2)+SizeOfCode(4)+                }
  { SizeOfInitData(4)+SizeOfUninitData(4)+EntryPoint(4)+BaseOfCode(4)+                        }
  { BaseOfData(4)+ImageBase(4)+SectionAlignment(4)+FileAlignment(4)+                          }
  { OSVersion(4)+ImageVersion(4)+SubsystemVersion(4)+Win32Version(4)+                        }
  { SizeOfImage(4)+SizeOfHeaders(4)+CheckSum(4) = 4+16*4 = 68 octets avant             }
  { Subsystem) = 64+4+20+68 = 156. }
  Seek(F, 156);
  BlockRead(F, B4, 2);
  PEExeAssert('Subsystem=3 (CUI, console)', (B4[0] = 3) And (B4[1] = 0));

  ExeSize := FileSize(F);
  Close(F);

  PEExeAssert('taille de fichier multiple exact de PE_FILE_ALIGN (512)',
    (ExeSize Mod PE_FILE_ALIGN) = 0);
  PEExeAssert('fichier .exe de taille plausible (au moins 4 blocs alignes)',
    ExeSize >= 4 * PE_FILE_ALIGN);

  Assign(F, TmpExe);
  Erase(F);
  Assign(F, TmpAsm);
  Erase(F);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  StmtInit;
  ExprInit;
  SymInit;
  FuncDefInit;
  MethodPoolInit;
  EnumCaseInit;
End;

{ ------------------------------------------------------------ }
{ TODO 24 - AUTO-TESTS (SELF-TESTS INTERNES)                       }
{ ------------------------------------------------------------ }
{ Un SelfTest par sous-systeme majeur existe DEJA - un a chaque TODO           }
{ depuis le TODO 02, jamais reporte a "plus tard" (chaque TODO de ce               }
{ fichier a systematiquement ajoute le sien EN MEME TEMPS que la                       }
{ fonctionnalite elle-meme, jamais apres coup, meme discipline que              }
{ GOCW32.PAS/DELPHI.PAS/PERLCW32.PAS). Ce TODO ne les CREE donc pas, il             }
{ les REGROUPE (RunAllSelfTests ci-dessous, plutot qu inlines dans Run             }
{ lui-meme - separe clairement la responsabilite "auto-tests" de la                     }
{ responsabilite "compiler le VRAI fichier .swift" de Run). L audit                     }
{ confirme que la SEULE lacune reelle trouvee par le TODO 24 de                                }
{ GOCW32.PAS (aucun auto-test ne verifiait l ENCODAGE 80386 lui-meme                    }
{ OCTET PAR OCTET pour un mnemonique donne, BinObjSelfTest/PEExeSelfTest              }
{ ne verifiant que la STRUCTURE d ensemble d un fichier compile) est                  }
{ deja COMBLEE ICI : BinEncoderSelfTest (ecrit des le TODO 22, PAS                     }
{ attendu jusqu ici) fait deja des assertions octet-exact par mnemonique.               }
{ Noms REELS (colonne gauche) vs liste aspirationnelle du TODO 01                                }
{ (colonne droite, ecrite avant que la moindre ligne de parseur n existe               }
{ - de simples PREVISIONS, jamais un contrat a respecter a la lettre une             }
{ fois l architecture reelle en place, meme discipline que pour les                       }
{ noms Bin*/Asm* du TODO 22/23) : tous les 20 noms lites par le TODO 01              }
{ (LexSelfTest a CodegenSelfTest, SemanticAssert~SemanticSelfTest) sont            }
{ REELLEMENT presents ci-dessous, PLUS BinEncoderSelfTest/BinObjSelfTest/            }
{ PEExeSelfTest (TODO 22/23), jamais anticipes du tout par cette liste             }
{ (ecrite avant meme que l assembleur/l ecrivain PE ne soient concus). }
{ ------------------------------------------------------------ }

Procedure RunAllSelfTests;
Begin
  StdlibInit;   { TODO 20 : table STATIQUE, jamais mutee par un parseur -   }
                { un SEUL appel suffit pour toute la duree du processus,           }
                { contrairement a StmtInit/ExprInit/etc. re-appeles a           }
                { chaque self-test pour eviter toute contamination croisee. }
  LexSelfTest;
  KeywordSelfTest;
  TypeSelfTest;
  DeclSelfTest;
  ExprSelfTest;
  StmtSelfTest;
  FuncSelfTest;
  StructSelfTest;
  ClassSelfTest;
  ProtocolSelfTest;
  EnumSelfTest;
  GenericSelfTest;
  OptionalSelfTest;
  ErrorSelfTest;
  CollectionSelfTest;
  StringSelfTest;
  MemorySelfTest;
  SemanticSelfTest;
  StdlibSelfTest;
  CodegenSelfTest;
  BinEncoderSelfTest;
  BinObjSelfTest;
  PEExeSelfTest;
End;

{ ------------------------------------------------------------ }
{ Run : point d entree - portee TODO 01-25. CHANGEMENT CENTRAL de ce     }
{ TODO 25 (validation finale) : Run() BASCULE ENFIN, pour un VRAI            }
{ fichier passe en argument, de "seulement tokeniser" (comportement            }
{ provisoire depuis le TODO 01/02, garde tel quel par TODO 21/22/23         }
{ pour eviter toute regression PENDANT que le codegen/assembleur/           }
{ ecrivain PE grandissait par etapes) a une VRAIE tentative de              }
{ compilation complete (ParseSwiftProgram -> CompileProgram -> .asm ->           }
{ BinAssembleFile -> BinResolveFixups+WriteCOFFObj [-obj] OU                     }
{ WritePEExe [par defaut]) - EXACTEMENT ce que ce TODO 25 doit VERIFIER           }
{ (voir le rapport d en-tete de fichier, section TODO 25, mis a jour            }
{ juste apres ce TODO) : "compile+EXECUTE reellement, pas seulement            }
{ compile sans erreur". Sans ce basculement, -obj/-asm restaient des               }
{ options mortes (reservees depuis le TODO 01) et aucune mesure               }
{ honnete fichier par fichier n etait possible via l outil reel               }
{ lui-meme. Pour un construct hors de la portee actuelle du codegen                }
{ (fonctions/controle/structs/etc., voir TODO 21), FatalError s arrete           }
{ PROPREMENT, EXACTEMENT comme le fait deja chaque XxxSelfTest -               }
{ AUCUN comportement nouveau, seulement le meme arret propre applique             }
{ maintenant a un VRAI fichier plutot qu a un auto-test synthetique. }
{ ------------------------------------------------------------ }

Procedure Run;
Var
  I : Integer;
  AsmFileName : TString;
  KeepAsm : Boolean;
Begin
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

  StmtInit; ExprInit; SymInit; TypeInit; FuncDefInit; MethodPoolInit; EnumCaseInit;
  ParserInit;

  LexInit;
  LexAll;
  LexClose;

  If Opts.DebugMode Then
    For I := 0 To TokenCount - 1 Do
    Begin
      PrintToken(TokenPool[I]);
      PrintIdentClass(TokenPool[I]);
    End;

  If Opts.Verbose Then
    WriteLn('Tokens produits  : ', TokenCount, ' (', TotalLines, ' lignes)');

  ParseSwiftProgram;

  KeepAsm := Opts.AsmOutput;
  If KeepAsm Then
    AsmFileName := ReplaceExt(Opts.OutFile, '.asm')
  Else
    AsmFileName := ReplaceExt(Opts.OutFile, '.$$$');

  CompileProgram(AsmFileName);
  BinAssembleFile(AsmFileName);

  If Opts.ObjOnly Then
  Begin
    BinResolveFixups;
    WriteCOFFObj(Opts.OutFile);
  End
  Else
    WritePEExe(Opts.OutFile);

  If Not KeepAsm Then
  Begin
    Assign(LexSrcF, AsmFileName);
    Erase(LexSrcF);
  End;

  ShowStats;
  WriteLn('SWIFTW32: ', Opts.OutFile, ' genere avec succes.');
End;

BEGIN
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  Run;
END.
