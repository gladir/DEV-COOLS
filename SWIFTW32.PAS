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

BEGIN
END.
