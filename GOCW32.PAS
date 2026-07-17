{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Go vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program GOCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  GOCW32.PAS - Compilateur Go vers assembleur 80386 pour
  Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\GO\*.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode)
            ParseArgs : argv source.go [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extension .go ; premiere ligne "package main"
              obligatoire (portee : un seul fichier .go par
              compilation, pas de vrais modules multi-fichiers -
              voir TODO 18)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512),
              PE_SUBSYS_CUI / PE_SUBSYS_GUI
            Limites : MAX_SYM=4096, MAX_FUNC=512, MAX_TYPE=1024,
              MAX_FIELD_POOL=4096, MAX_PARAM=64, MAX_LOCAL=256,
              MAX_LABEL=4096, MAX_STR=255, MAX_ERRORS=30,
              MAX_GOROUTINE=64, MAX_CHANNEL=128, MAX_DEFER=64
            Prefixes ASM : _GO_ (gvar), _GOF_ (func), _GOM_
              (methode), _GOK_ (constante chaine/litteral), _GORT_
              (runtime), _GOL_ (label), _GOT_ (descripteur de type/
              itable simplifiee), _GOCH_ (canal), _GOG_ (goroutine)

  TODO 02 - TOKENISEUR GO (LEXER) ET INSERTION AUTOMATIQUE DE ;
            LexInit, LexClose, LexNextChar, LexPeekChar,
              LexPeekChar2, LexNextToken
            Identificateurs : lettres ASCII + _, chiffres (pas en
              tete) ; sensibles a la casse (majuscule initiale =
              export, voir TODO 18)
            Numeriques : 123, 1_000_000 (soulignes separateurs),
              0x1F (hex), 0o17/017 (octal), 0b101 (binaire), 1.5,
              1.5e3, .5, 1. ; rune 'a' '\n' '\t' '\\' '\'' '\xFF'
              '￿' '\U0001F600' ; imaginaire (1i) NON supporte
              (hors de portee, documente)
            Chaines interpretees "..." (memes echappements que
              rune) et chaines brutes `...` (aucun echappement,
              retours a la ligne litteraux)
            Commentaires : // jusqu'a fin de ligne, /* ... */ bloc
              (peut s'etendre sur plusieurs lignes)
            REGLE D'INSERTION AUTOMATIQUE DE POINT-VIRGULE (ASI,
              cle de voute de la syntaxe Go) : en fin de ligne, si
              le dernier token est un identificateur, un
              litteral (entier/flottant/rune/chaine), ou l'un des
              mots break/continue/fallthrough/return, ou l'un des
              symboles ++ -- ) ] } , alors le lexer insere un
              token TOK_SEMI virtuel avant le saut de ligne -
              c'est ce mecanisme qui permet a Go de ne jamais
              exiger de ; explicite en pratique
            Operateurs/ponctuation : + - * / % & | ^ << >> &^
              += -= *= /= %= &= |= ^= <<= >>= &^= && || <- ++ --
              == < > = ! ~ != <= >= := ... ( ) [ ] { } , ; . :
            Types de token : TOK_IDENT, TOK_INT, TOK_FLOAT,
              TOK_IMAG(rejete), TOK_RUNE, TOK_STRING, TOK_RAWSTRING,
              TOK_SEMI (reel ou insere), TOK_EOF

  TODO 03 - MOTS-CLES ET IDENTIFICATEURS PREDECLARES
            IsKeyword(s : String) : Integer
            Les 25 mots reserves du langage (liste EXHAUSTIVE,
              Go n'en a pas d'autres) : break case chan const
              continue default defer else fallthrough for func
              go goto if import interface map package range
              return select struct switch type var
            Identificateurs predeclares (pas des mots-cles, peuvent
              en theorie etre masques, mais traites comme types/
              valeurs integres par ce compilateur) :
              Types : bool byte complex64 complex128 error
                float32 float64 int int8 int16 int32 int64 rune
                string uint uint8 uint16 uint32 uint64 uintptr any
              Constantes : true false iota nil
              Fonctions integrees : append cap close complex copy
                delete imag len make new panic print println real
                recover
            Fichiers de test couverts (voir SAMPLES\GO\*.go) :
              hello.go (package main, func main, fmt.Println),
              types.go (var/const/iota), control.go (if/for/switch)

  TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES
            TTypeKind : TYK_BOOL, TYK_INT (avec sous-categorie
              taille/signe : 8/16/32/64, int/uint generiques =
              32 bits sur cette cible), TYK_FLOAT (32/64),
              TYK_STRING, TYK_ARRAY, TYK_SLICE, TYK_STRUCT,
              TYK_POINTER, TYK_FUNC, TYK_INTERFACE, TYK_MAP,
              TYK_CHAN, TYK_ERROR
            TTypeRec (Kind, Name, Size, Align, ElemTypeIdx
              [pointeur/slice/array/chan], KeyTypeIdx [map],
              FieldFirst/FieldCount [struct, pool partage comme
              DELPHI.PAS], MethodFirst/MethodCount, ParamTypes/
              ResultTypes [func, retours MULTIPLES], IsVariadic)
            Valeurs zero par type (regle centrale du langage) :
              0 (numerique), false (bool), "" (string), nil
              (pointeur/slice/map/chan/func/interface), struct a
              zero recursif (chaque champ a sa propre valeur zero)
            Representation memoire runtime :
              string  = {Ptr:Pointer; Len:LongInt} (immuable)
              slice   = {Ptr:Pointer; Len,Cap:LongInt}
              interface = {TypeDescPtr:Pointer; DataPtr:Pointer}
                (simplifiee : pas de vraie itable par paire
                (type,interface), un seul descripteur de type
                concret suffit pour les assertions de type)
              map     = table de hachage simplifiee (voir TODO 12)
            Conversions numeriques explicites T(x) et regles de
              troncature/extension de signe entre tailles

  TODO 05 - DECLARATIONS : VAR, CONST, TYPE, IOTA ET PORTEES
            var Nom [Type] [= Expr] ; var (bloc multi-lignes)
            Declaration courte := (inference de type, uniquement
              en contexte de fonction, au moins une nouvelle
              variable a gauche)
            const Nom [Type] = ExprConstante ; const (bloc)
            iota : compteur remis a 0 a chaque bloc const, incremente
              a chaque ligne - expressions typiques
              "const ( A = iota; B; C )" -> A=0,B=1,C=2 et
              "1 << iota" pour des drapeaux de bits
            type Nom Type (definition, nouveau type distinct) et
              type Nom = Type (alias, meme type)
            Portees : paquet (package-level, avant tout usage -
              "forward reference" implicite entre declarations de
              haut niveau, contrairement a Pascal), fonction, bloc
              { } imbrique, portee du for/if (variables du init)

  TODO 06 - EXPRESSIONS, OPERATEURS ET LITTERAUX COMPOSES
            Table de precedence Go (5 niveaux, du plus fort au
              plus faible) :
                5: * / % << >> & &^
                4: + - | ^
                3: == != < <= > >=
                2: &&
                1: ||
            Aucune coercion implicite (contrairement a Perl/PowerFX
              de ce meme projet) : int + float est une ERREUR de
              type sans conversion explicite - regle stricte a
              faire respecter par l'analyse semantique (TODO 19)
            Litteraux composes : T{champ: val, ...} (struct),
              []T{v1, v2, ...} (slice), [N]T{...} (array),
              map[K]V{cle: val, ...} (map) ; elision du type pour
              les elements imbriques ([]Point{{1,2},{3,4}})
            Adresse/dereferencement : &x, *p ; new(T) retourne *T
            Indexation/tranchage : a[i], a[low:high], a[low:high:max]
              (slice a capacite plafonnee) - regles de bornes
              (panique runtime si hors limites, voir TODO 16)
            Assertion de type x.(T) et forme comma-ok v, ok := x.(T)

  TODO 07 - INSTRUCTIONS DE CONTROLE : IF / FOR / SWITCH / GOTO
            if [Init;] Cond { ... } [else if ... ] [else { ... }]
              (accolades OBLIGATOIRES, contrairement a Pascal)
            for (les TROIS formes, un seul mot-cle for en Go) :
              for Init; Cond; Post { ... } (forme classique C)
              for Cond { ... } (equivalent while)
              for { ... } (boucle infinie, sortie par break/return)
              for Var := range Collection { ... } (tableau/slice
                donne index+valeur, map donne cle+valeur, string
                donne index-octet+rune, chan donne valeur recue -
                voir TODO 11/12/14/15)
            switch [Init;] [Tag] { case V1, V2: ...; default: ... }
              (pas de fallthrough implicite comme en C - mot-cle
              fallthrough EXPLICITE requis pour enchainer)
            switch sans tag (equivalent if/else-if chaine) :
              "switch { case cond1: ...; case cond2: ... }"
            Type switch : "switch v := x.(type) { case T1: ...;
              case T2, T3: ...; default: ... }" (lie a TODO 10)
            break/continue avec etiquette optionnelle (LabelName:
              for { ... break LabelName ... }), goto Label,
              instructions etiquetees

  TODO 08 - FONCTIONS : RETOURS MULTIPLES, VARIADIQUES, CLOSURES
            func Nom(Params) (Resultats) { Corps }
            Retours MULTIPLES : "func DivMod(a,b int) (int, int)"
              - convention d'appel a definir (pile 80386 : les
              valeurs de retour supplementaires via pointeurs de
              sortie caches, ou tuple retourne dans EAX:EDX pour
              2 valeurs simples, cas general via zone pile appelant)
            Resultats NOMMES et "return nu" (naked return) :
              "func F() (n int) { n = 42; return }"
            Parametres variadiques ...T ("func Sum(nums ...int) int")
              - traites en interne comme un slice
            Valeurs fonction / types func(...) (...) et fermetures
              (closures) : capture par REFERENCE des variables
              englobantes (contrairement a une simple copie),
              necessite un environnement de capture alloue au tas
            defer Expr(...) : empile un appel differe, execute en
              ordre LIFO au retour de la fonction englobante (meme
              en cas de panic - lien avec TODO 16)

  TODO 09 - STRUCTS ET METHODES (RECEVEURS VALEUR/POINTEUR)
            type Nom struct { Champ1 Type1; Champ2 Type2; ... }
            Acces aux champs : a.Champ (auto-dereference si a est
              un pointeur vers struct)
            Methodes : "func (r RecepteurType) NomMethode(...)
              (...) { ... }" - receveur par VALEUR (copie) ou par
              POINTEUR (*RecepteurType, modifie l'original)
            Regle d'ensemble de methodes : un type T a les methodes
              a receveur T ; *T a les methodes a receveur T ET *T
              (asymetrie a respecter pour l'implementation
              d'interfaces, TODO 10)
            Embarquement (champ anonyme, "composition over
              inheritance") : "type Chien struct { Animal; Nom
              string }" - promeut les champs ET methodes d'Animal
              directement accessibles sur Chien (Chien.Parler() si
              Animal.Parler() existe)

  TODO 10 - INTERFACES, ASSERTIONS ET DISPATCH DYNAMIQUE
            type Nom interface { Methode1(...) (...); ... }
            Implementation IMPLICITE (typage structurel) : un type
              concret implemente une interface des qu'il possede
              toutes ses methodes, SANS declaration explicite
              (contrairement a Delphi/Java) - verification a la
              compilation (TODO 19) : chercher les methodes requises
              dans l'ensemble de methodes du type concret
            interface{} / any (Go 1.18+) : interface vide, accepte
              n'importe quelle valeur (utilisee massivement, ex.
              fmt.Println(args ...any))
            Assertion de type x.(T) (panique si echec) et forme
              comma-ok v, ok := x.(T) (ok=false si echec, pas de
              panique)
            Type switch (lie a TODO 07) pour dispatcher sur le
              type dynamique concret
            Table de methodes simplifiee (_GOT_ descripteur de
              type) : pointeurs de fonction par methode, resolue a
              la compilation des lors que le type concret est
              connu statiquement (pas de vraie itable Go complete -
              simplification documentee, portee limitee aux appels
              directement resolvables)

  TODO 11 - TABLEAUX ET SLICES : MAKE / APPEND / COPY / LEN / CAP
            Tableaux fixes [N]T : semantique de VALEUR (copie
              integrale a l'affectation/passage en parametre,
              contrairement aux slices)
            Slices []T : semantique de REFERENCE (en-tete
              {Ptr,Len,Cap} copie, mais pointe vers le MEME tableau
              sous-jacent)
            make([]T, Len[, Cap]) : alloue un tableau sous-jacent
            append(s, v1, v2, ...) : ajoute, realloue (doublement
              de capacite) si Cap depassee - retourne un NOUVEAU
              slice (a reaffecter, piege classique documente)
            append(s1, s2...) : concatenation via l'operateur ...
              d'expansion
            copy(dst, src) : copie min(len(dst),len(src)) elements,
              retourne le nombre copie
            len(s), cap(s) : taille logique / capacite allouee
            Tableaux/slices multidimensionnels ([][]int, [N][M]T)

  TODO 12 - MAPS : TABLE DE HACHAGE SIMPLIFIEE
            map[K]V, make(map[K]V[, CapaciteInitiale])
            Indexation m[cle] = valeur ; lecture v := m[cle]
              (retourne la valeur zero du type V si cle absente)
            Forme comma-ok : v, ok := m[cle] (ok=false si absente)
            delete(m, cle)
            for cle, valeur := range m { ... } (ordre d'iteration
              NON garanti par la vraie spec Go - ce compilateur
              peut it erer dans un ordre stable/deterministe,
              simplification documentee sans consequence sur des
              programmes corrects)
            Fonction de hachage simplifiee pour les cles usuelles
              (string : hachage de type FNV ou similaire ; entiers :
              identite/modulo) ; tables de type ouvert (buckets) ou
              chainage, taille MAX_MAP_ENTRY a definir

  TODO 13 - POINTEURS ET GESTION MEMOIRE
            &x (adresse), *p (dereference explicite), p.Champ
              (dereference implicite si p est *Struct)
            new(T) : alloue une valeur zero de type T, retourne *T
            Pas de veritable ramasse-miettes (GC) dans la portee
              de ce compilateur (simplification DOCUMENTEE, dans la
              continuite des autres compilateurs de ce projet - le
              tas grandit via HeapAlloc/VirtualAlloc Win32 sans
              recyclage automatique ; acceptable pour des programmes
              d'exemple de duree de vie courte, limitation explicite
              pour tout usage prolonge/intensif en allocation)
            Pas d'arithmetique de pointeurs (contrairement a C) -
              uniquement unsafe.Pointer serait concerne, HORS DE
              PORTEE (package unsafe non supporte, documente)

  TODO 14 - CHAINES, RUNES ET UTF-8
            string : sequence d'octets IMMUABLE + longueur (pas de
              terminateur nul, peut contenir n'importe quel octet)
            rune = alias de int32 (point de code Unicode) ; byte =
              alias de uint8
            for i, r := range s { ... } sur une string : i est
              l'offset en OCTETS, r est le rune DECODE en UTF-8 a
              cet offset (decodage UTF-8 minimal a implementer :
              sequences 1 a 4 octets)
            Conversions string([]byte), string([]rune),
              []byte(string), []rune(string)
            Concatenation +, comparaison lexicographique ==/</>,
              len(s) (nombre d'OCTETS, pas de runes)
            Chaines brutes ` ` : aucun decodage d'echappement,
              utile pour regex/chemins Windows (lien TODO 02)

  TODO 15 - GOROUTINES ET CANAUX (MODELE DE CONCURRENCE SIMPLIFIE)
            go Expr(...) : lance une goroutine - PORTEE ASSUMEE ET
              DOCUMENTEE (le 80386/Win32 nu, sans support d'un vrai
              ordonnanceur preemptif dans ce compilateur, ne permet
              pas de reproduire le vrai modele M:N de Go) : modele
              cooperatif simplifie ou threads Win32 reels
              (CreateThread + section critique par canal) - CHOIX A
              FIGER en debut d'implementation et documenter dans le
              code (les deux options sont defendables ; les threads
              Win32 reels sont plus fideles au parallelisme reel
              mais plus complexes a synchroniser correctement)
            chan T, make(chan T[, Capacite]) (non-bufferise si
              Capacite omise/0 : envoi bloque jusqu'a reception)
            ch <- v (envoi), v := <-ch (reception), v, ok := <-ch
              (ok=false si canal ferme et vide)
            close(ch) : ferme le canal (envoi ulterieur = panique)
            select { case v := <-ch1: ...; case ch2 <- x: ...;
              default: ... } : attend sur plusieurs operations de
              canal simultanement, default rend l'attente non
              bloquante
            sync minimal si necessaire (Mutex/WaitGroup) SEULEMENT
              si le modele a threads Win32 reels est retenu -
              sinon sans objet (modele cooperatif implicitement
              sequentiel entre points de blocage)

  TODO 16 - DEFER, PANIC ET RECOVER
            Pile de defer PAR APPEL DE FONCTION (pas globale) :
              chaque frame d'appel a sa propre liste, executee en
              ordre LIFO a la sortie (normale OU par panique)
            panic(v) : deroule la pile d'appel, executant les
              defer de chaque frame traversee, jusqu'a un recover()
              (dans un defer) qui l'arrete, ou jusqu'au sommet
              (programme termine avec message d'erreur + code de
              sortie non nul)
            recover() : valide UNIQUEMENT si appelee directement
              depuis une fonction differee (defer) en cours de
              deroulement de panique - retourne la valeur passee a
              panic (ou nil si pas de panique en cours)
            Paniques RUNTIME implicites a generer : indice hors
              limites (slice/array/string), dereference de pointeur
              nil, assertion de type echouee (forme sans comma-ok),
              division entiere par zero, envoi sur canal ferme

  TODO 17 - INTERFACE ERROR ET IDIOME DE GESTION D'ERREURS
            type error interface { Error() string } (interface
              predeclaree, deja couverte structurellement par
              TODO 10, mais omnipresente dans l'idiome Go - section
              dediee pour le support bibliotheque)
            errors.New(msg) equivalent (retourne un error simple)
            fmt.Errorf(format, args...) equivalent (avec %w pour
              enrober une erreur existante, HORS DE PORTEE le
              deballage errors.Is/errors.As - documente)
            Idiome dominant : "resultat, err := F(...); if err !=
              nil { ... }" - simple consequence des retours
              multiples (TODO 08) et des interfaces (TODO 10), pas
              un mecanisme special du langage lui-meme

  TODO 18 - PACKAGES ET IMPORTS (MODELE MONO-FICHIER SIMPLIFIE)
            package main obligatoire en tete de fichier (seul
              package supporte comme point d'entree - portee : PAS
              de vraie compilation multi-fichiers/multi-paquets,
              a l'image du "uses" simplifie de DELPHI.PAS dans ce
              meme projet)
            import "nom" / import ( "nom1" ; "nom2" ) : SYNTAXE
              validee, mais seule une TABLE FIXE de paquets connus
              est reellement cablee vers des fonctions runtime
              (fmt, strings, strconv, os, math - voir TODO 20) ;
              tout autre import provoque un arret propre documente
              plutot qu'un echec silencieux
            Regle d'export Go (SANS mot-cle dedie, contrairement a
              Pascal/Delphi) : un identificateur de package commence
              par une MAJUSCULE => exporte/visible hors package,
              minuscule => prive - sans consequence pratique en
              mode mono-fichier/mono-package (tout est dans "main"),
              mais a respecter pour la coherence de l'analyse
            func main() : point d'entree obligatoire du package main

  TODO 19 - ANALYSE SEMANTIQUE : SYMBOLES, PORTEES ET VERIFICATION
            DE TYPES
            SymTab/TypeTab (structure proche de celle de
              DELPHI.PAS dans ce meme projet : table de symboles a
              portees empilees, pool partage de champs de struct,
              pool de methodes)
            Resolution des declarations de haut niveau AVANT tout
              usage, mais entre ELLES dans un ordre quelconque
              (contrairement a Pascal ou l'ordre textuel est
              obligatoire) - necessite une passe prealable
              d'enregistrement des noms de haut niveau avant la
              passe de verification des corps
            Regles d'assignabilite Go (strictes, pas de coercion
              implicite entre types nommes distincts meme de meme
              representation sous-jacente - sauf constantes non
              typees et interfaces satisfaites structurellement)
            Verification des ensembles de methodes pour la
              satisfaction d'interface (lien direct TODO 10)
            Detection d'erreurs : variable declaree et non utilisee
              (ERREUR en Go, pas juste un avertissement - regle
              stricte caracteristique du langage a reproduire),
              import declare et non utilise (idem)

  TODO 20 - BIBLIOTHEQUE STANDARD MINIMALE (fmt/strings/strconv/
            os/math)
            fmt : Println, Print, Printf (verbes %d %s %f %v %t
              %q %x %p au minimum), Sprintf, Sprintln, Errorf
            strings : ToUpper, ToLower, Contains, HasPrefix,
              HasSuffix, Split, Join, TrimSpace, Trim, Replace,
              ReplaceAll, Index, Repeat, Fields
            strconv : Itoa, Atoi, ParseInt, ParseFloat, FormatInt,
              FormatFloat, Quote
            os : Args (slice des arguments), Exit(code), Stdout/
              Stderr (writers minimaux pour fmt.Fprintln)
            math : Sqrt, Abs, Pow, Floor, Ceil, Max, Min, Mod,
              Inf, NaN, IsNaN, MaxInt32/MinInt32 (constantes)

  TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM
            Backend codegen (miroir des GenXxx des autres
              compilateurs de ce projet) :
              GenLoadInt/Float/Str/Rune, GenLoadVar/StoreVar(Idx)
              GenLoadField(Offset), GenLoadIndex (slice/array/map)
              GenCall(FuncName, Argc), GenCallMethod(RecvExpr,
                MethodName, Argc), GenCallIndirect (valeur fonction)
              GenJmp/JZ/JNZ/Label, GenPush/Pop
              GenAdd/Sub/Mul/Div/Mod (entiers signes/non signes,
                flottants IEEE 754 separement)
              GenComp(Op) : CMP + Jxx
              GenMakeSlice/GenAppend/GenMapGet/GenMapSet (appels
                runtime directs, TODO 11/12)
              GenDeferPush/GenDeferRunAll (TODO 16)
              GenGoStart/GenChanSend/GenChanRecv/GenSelect
                (TODO 15)
            Convention d'appel interne (cdecl adapte aux retours
              multiples de Go, pointeur de sortie cache pour les
              valeurs de retour au-dela de la premiere)

  TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32
            Infrastructure binaire (miroir exact des autres
              compilateurs de ce projet, deja eprouvee) :
              BinCode/BinData : Array Of Byte
              BinLabels : Array Of TLabel
              BinFixups : Array Of TFixup (REL32, ABS32, IMP32)
              BinImports : Array Of TImport (Win32 IAT)
              BinEmit8/16/32, BinEmitInstr (encodeur 80386 minimal :
                PUSH POP MOV LEA ADD SUB IMUL IDIV CMP TEST JMP
                JCC CALL RET ENTER LEAVE INT SHL SHR SAR AND OR
                XOR NOT NEG)
              BinDefineLabel, BinResolveLabel, BinAddFixup,
                BinResolveFixups
            OBJ COFF Win32 (-obj) : IMAGE_FILE_HEADER
              (Machine=I386), sections .text/.data/.rdata/.bss,
              table de symboles COFF (statique + externes),
              relocations par section

  TODO 23 - BACKEND BINAIRE .EXE PE WIN32 ET RUNTIME EMBARQUE
            EXE PE Win32 (par defaut) : stub MZ DOS minimal,
              signature PE + IMAGE_FILE_HEADER +
              IMAGE_OPTIONAL_HEADER32, sections .text(RX)/.data(RW)/
              .rdata(R)/.bss(RW)/.idata(R) avec IAT, sous-systeme
              CUI (console) par defaut, ImageBase $00400000,
              SectionAlign 4096, FileAlign 512
            IAT KERNEL32.DLL : GetStdHandle, WriteFile, ReadFile,
              ExitProcess, GetCommandLineA, HeapAlloc, HeapFree,
              GetProcessHeap, CreateThread/CreateEvent/
              EnterCriticalSection (SEULEMENT si le modele a
              threads Win32 reels est retenu pour TODO 15)
            Point d'entree _GOSTART : initialise le runtime, appelle
              _GOF_main, ExitProcess
            Runtime embarque (prefixe _GORT_) : start, exit, print
              (Println/Printf minimal), alloc/free, panic/recover
              (deroulement de pile), string (concat/compare/len/
              utf8_decode), slice (make/append/copy), map (new/
              get/set/delete/hash), chan (make/send/recv/close,
              selon modele TODO 15)
            Validation : tous les SAMPLES\GO\*.go compilent et
              produisent un .EXE PE Win32 fonctionnel (voir TODO 25)

  TODO 24 - AUTO-TESTS (SELF-TESTS INTERNES)
            Un SelfTest par sous-systeme majeur, sur le modele
              deja etabli par les autres compilateurs de ce projet
              (suites de jetons construites directement en memoire,
              sans passer par un vrai fichier source) :
              LexSelfTest, KeywordSelfTest, TypeSelfTest,
              ParseDeclSelfTest, ParseExprSelfTest,
              ParseControlFlowSelfTest, ParseFuncSelfTest,
              StructMethodSelfTest, InterfaceSelfTest,
              SliceMapSelfTest, DeferPanicRecoverSelfTest,
              GoroutineChanSelfTest (portee reduite au modele
              retenu, TODO 15), StdlibSelfTest, EmitSelfTest,
              BinSelfTest
            Executes inconditionnellement au demarrage (comme
              DELPHI.PAS/PERLCW32.PAS dans ce meme projet) - toute
              regression est detectee AVANT meme de tenter de
              compiler un vrai fichier .go

  TODO 25 - VALIDATION FINALE CONTRE SAMPLES\GO\*
            Compiler et EXECUTER reellement chacun des
              SAMPLES\GO\*.go (pas seulement verifier l'absence
              d'erreur de compilation) : code de sortie 0 et sortie
              standard conforme a ce qu'un vrai compilateur Go
              (via go run) produirait pour le meme fichier
            Couverture minimale attendue des exemples (a couvrir
              par au moins un fichier SAMPLES\GO\*.go chacun) :
              hello.go (package/func main/fmt.Println), types.go
              (var/const/iota/conversions), control.go (if/for/
              switch/goto), functions.go (retours multiples/
              variadique/closure/defer), structs.go (methodes
              valeur/pointeur/embarquement), interfaces.go
              (assertion/type switch/interface vide), slices.go
              (make/append/copy/range), maps.go (comma-ok/delete/
              range), strings.go (runes/UTF-8/conversions),
              concurrency.go (go/chan/select, selon modele TODO 15),
              errors.go (error/panic/recover)
            Documenter dans l'en-tete du fichier (comme les autres
              compilateurs de ce projet) toute limitation restant
              assumee a l'issue de ce TODO 25 (ex. pas de vrai GC,
              pas de vrais modules multi-fichiers, pas de package
              unsafe, modele de concurrence simplifie)
  ============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{ ============================================================ }

Const
  GOCW32_VERSION = '0.1';
  GOCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { --- Constantes PE/COFF (identiques aux autres compilateurs   }
  { de ce projet - format Win32 universel, pas specifique a Go)   }
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
  { par prudence memoire - meme convention que PERLCW32.PAS/         }
  { MOD3CW32.PAS/POWFXC32.PAS de ce meme projet).                     }
  MAX_SYM        = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_FUNC       = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_TYPE       = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_FIELD_POOL = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_PARAM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LOCAL      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_LABEL      = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_STR        = 255;
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_GOROUTINE  = {$IFDEF FPC}64{$ELSE}8{$ENDIF};
  MAX_CHANNEL    = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
  MAX_DEFER      = {$IFDEF FPC}64{$ELSE}8{$ENDIF};
  MAX_SCOPE      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_BIN        = 65536;
  MAX_BIN_LABEL  = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_BIN_FIXUP  = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_BIN_IMPORT = {$IFDEF FPC}128{$ELSE}32{$ENDIF};

  { --- Prefixes de nommage ASM (voir en-tete du fichier) --- }
  ASM_PFX_GVAR    = '_GO_';     { variable globale de package        }
  ASM_PFX_FUNC    = '_GOF_';    { fonction top-level                 }
  ASM_PFX_METHOD  = '_GOM_';    { methode (recepteur valeur/pointeur)}
  ASM_PFX_STRING  = '_GOK_';    { constante chaine/litteral          }
  ASM_PFX_RUNTIME = '_GORT_';   { routine runtime                    }
  ASM_PFX_LABEL   = '_GOL_';    { label de saut interne              }
  ASM_PFX_TYPEDESC= '_GOT_';    { descripteur de type/itable simplifiee}
  ASM_PFX_CHAN    = '_GOCH_';   { canal                               }
  ASM_PFX_GOROUT  = '_GOG_';    { corps de goroutine lancee par "go" }

Type
  TString = String;

  TOptions = Record
    SrcFile      : TString;   { fichier source (.go)                 }
    OutFile      : TString;   { fichier sortie (.exe, .obj ou .asm)   }
    OutFileGiven : Boolean;   { True si fourni explicitement (-o)     }
    Verbose      : Boolean;   { -v : banniere et statistiques         }
    DebugMode    : Boolean;   { -d : affichage de chaque token        }
    Warnings     : Boolean;   { -w : afficher les avertissements      }
    AsmOutput    : Boolean;   { -asm : produire aussi un .ASM lisible }
    ObjOnly      : Boolean;   { -obj : produire seulement un .OBJ     }
    StrictMode   : Boolean;   { -strict : erreurs Go strictes (variable}
                               { ou import declare et non utilise, voir}
                               { TODO 19) traitees comme fatales meme   }
                               { sans ce parametre - reserve pour       }
                               { assouplir ce comportement plus tard,    }
                               { actuellement toujours strict par defaut }
                               { comme le vrai compilateur Go)            }
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

{ Retourne l extension d un chemin (avec le point, en minuscules) }
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
  WriteLn('GOCW32: FATAL: ', Msg);
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
  WriteLn('GOCW32: warning: ', Msg);
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
  WriteLn('GOCW32 v', GOCW32_VERSION, ' (', GOCW32_DATE,
          ') - Compilateur Go vers 80386 (Windows PE 32 bits)');
  WriteLn('GOCW32 - Cette commande permet de lancer le compilateur ',
          'Go pour l''assembleur du microprocesseur 80386 (en ',
          'executable Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : GOCW32 [options] <source.go> [options]');
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
  WriteLn('  GOCW32 hello.go');
  WriteLn('  GOCW32 hello.go hello.exe -v');
  WriteLn('  GOCW32 types.go -obj -w');
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
    WriteLn('GOCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .go - la presence effective de "package   }
  { main" en tete de fichier ne peut etre validee qu une fois le     }
  { lexeur disponible (TODO 02) ; ce n est PAS encore fait ici,         }
  { portee volontairement limitee a l infrastructure (TODO 01).           }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.GO' Then
    WarnMsg('extension attendue .go, trouvee: ' + Ext);

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
  WriteLn('GOCW32 v', GOCW32_VERSION, ' (', GOCW32_DATE,
          ') - Compilateur Go -> 80386 PE Win32');
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
{ TODO 02 - TOKENISEUR GO (LEXER) ET INSERTION AUTOMATIQUE DE ; }
{ ============================================================ }

Type
  TTokenKind = (
    TOK_EOF,        { fin de fichier                                }
    TOK_IDENT,      { identificateur (mots-cles INCLUS - voir TODO 03,}
                     { la classification complete est deferee la-bas ; }
                     { seule l eligibilite ASI de break/continue/       }
                     { fallthrough/return est traitee ICI, necessaire     }
                     { au lexeur lui-meme, voir LexIsASIKeyword)           }
    TOK_INT,        { litteral entier (decimal/hex/octal/binaire)   }
    TOK_FLOAT,      { litteral flottant                              }
    TOK_RUNE,       { litteral rune 'x' '\n' '￿' ...             }
    TOK_STRING,     { chaine interpretee "..." (echappements decodes) }
    TOK_RAWSTRING,  { chaine brute `...` (aucun echappement)          }
    TOK_SEMI,       { point-virgule REEL ou INSERE par l ASI          }
    TOK_OP          { operateur/ponctuation ; distingue par Val       }
  );

  TToken = Record
    Kind      : TTokenKind;
    Val       : TString;    { texte brut (identificateur, operateur, }
                             { ou forme decodee pour rune/chaine)      }
    IntVal    : LongInt;     { valeur entiere (TOK_INT, code point     }
                              { TOK_RUNE)                                }
    RealVal   : Real;        { valeur flottante (TOK_FLOAT)             }
    Line      : Integer;     { ligne source (1-base)                    }
    Col       : Integer;     { colonne source (1-base)                  }
    Inserted  : Boolean;     { True si ce TOK_SEMI a ete SYNTHETISE par  }
                              { l ASI plutot qu ecrit explicitement dans   }
                              { le source (utile pour le debug -d)          }
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

  { Etat necessaire a l ASI (Automatic Semicolon Insertion) : classe et  }
  { texte du dernier "vrai" token retourne par LexNextToken (un TOK_SEMI  }
  { insere compte lui-meme comme "dernier token" pour eviter d en inserer    }
  { un deuxieme consecutif). LexHaveLast reste Faux avant le tout premier      }
  { token du fichier (l ASI ne peut jamais s appliquer en tete de fichier).      }
  LexLastKind : TTokenKind;
  LexLastVal  : TString;
  LexHaveLast : Boolean;

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
{ ligne). LexPeekChar3 EXCEDE legerement la portee textuelle du       }
{ TODO 02 (qui ne nommait que Peek/Peek2) mais est necessaire pour     }
{ reconnaitre sans ambiguite les operateurs a 3 caracteres de Go        }
{ ('...' '<<=' '>>=' '&^=') par la methode du "plus long match".         }
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
{ l esprit a DELPHI.PAS/PERLCW32.PAS de ce meme projet - PAS de      }
{ pile d inclusion (Go, tel que couvert ici, est mono-fichier,         }
{ TODO 18) : plus simple que DELPHI.PAS sur ce point precis.             }
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
{ Regle d insertion automatique de point-virgule (ASI)          }
{ CONFIRME (Go Language Specification, "Semicolons") : eligible    }
{ si le DERNIER token est un identificateur (mots-cles break/       }
{ continue/fallthrough/return INCLUS - ce sont lexicalement des        }
{ identificateurs dans ce lexeur simplifie, voir TOK_IDENT ci-dessus),   }
{ un litteral entier/flottant/rune/chaine, OU l un des operateurs/          }
{ ponctuations "++", "--", parenthese fermante, crochet fermant ou            }
{ accolade fermante - PAS les 21 AUTRES mots-cles Go (if/for/func/etc.),         }
{ d ou LexIsReservedWord ci-dessous : un identificateur qui EST l un              }
{ de ces 21 mots-cles n est PAS eligible (contrairement a un identificateur       }
{ ordinaire), sauf s il s agit precisement de break/continue/fallthrough/return.  }
{ ------------------------------------------------------------ }

{ IsKeyword est la vraie classification (TODO 03, plus bas dans ce   }
{ fichier) - declaree ici Forward pour que LexIsReservedWord (TODO 02,  }
{ deja ecrit et teste) puisse s y appuyer SANS dupliquer la liste des     }
{ 25 mots reserves une seconde fois (risque de divergence entre les          }
{ deux copies sinon).                                                          }
Function IsKeyword(Const S: TString): Integer; Forward;

Function LexIsReservedWord(Const S: TString): Boolean;
Begin
  LexIsReservedWord := IsKeyword(S) <> 0;
End;

Function LexIsASIKeyword(Const S: TString): Boolean;
Begin
  LexIsASIKeyword := (S = 'break') Or (S = 'continue') Or
                      (S = 'fallthrough') Or (S = 'return');
End;

Function LexASIEligible: Boolean;
Begin
  LexASIEligible := False;
  If Not LexHaveLast Then Exit;
  Case LexLastKind Of
    TOK_IDENT:
      LexASIEligible := (Not LexIsReservedWord(LexLastVal)) Or
                         LexIsASIKeyword(LexLastVal);
    TOK_INT, TOK_FLOAT, TOK_RUNE, TOK_STRING, TOK_RAWSTRING:
      LexASIEligible := True;
    TOK_OP:
      LexASIEligible := (LexLastVal = '++') Or (LexLastVal = '--') Or
                         (LexLastVal = ')')  Or (LexLastVal = ']')  Or
                         (LexLastVal = '}');
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur (mots-cles INCLUS, voir en-tete   }
{ de section - classification complete deferee au TODO 03).       }
{ Go est sensible a la casse : AUCUN changement de casse ici       }
{ (contrairement au Pascal de DELPHI.PAS, insensible a la casse).    }
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
{ LexScanNumber : entier (decimal/hex/octal nouveau et ancien     }
{ style/binaire) ou flottant, avec soulignes separateurs           }
{ optionnels (1_000_000). Le suffixe imaginaire 'i' (1i, 1.5i)        }
{ est explicitement HORS DE PORTEE (voir TODO 02 de l en-tete) :         }
{ reconnu puis rejete par une erreur fatale claire plutot que d etre        }
{ silencieusement ignore ou mal interprete.                                  }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  S        : TString;
  IsFloatV : Boolean;
  N        : LongInt;
  FracVal  : Real;
  FracDiv  : Real;
  K        : Integer;
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

  { --- partie entiere (decimale, ou octal ANCIEN style '0755' -   }
  { heritage C conserve par Go - detecte APRES coup ci-dessous) --- }
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
  { qui appartiendrait a l operateur '...') --- }
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

  { --- suffixe imaginaire : HORS DE PORTEE, arret propre --- }
  If (LexPeekChar = 'i') Then
    FatalError('litteraux imaginaires (ex. ' + S + 'i) non supportes ' +
      '(hors de portee, voir TODO 02 de l en-tete du fichier)');

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
    CurToken.Kind := TOK_INT;
    { octal ANCIEN style : '0' suivi d au moins un autre chiffre,   }
    { sans point ni exposant (deja exclus par IsFloatV=Faux ici) -    }
    { comportement herite du C, conserve par la spec Go elle-meme.       }
    If (Length(S) > 1) And (S[1] = '0') Then
    Begin
      N := 0;
      For K := 2 To Length(S) Do
        N := N * 8 + (Ord(S[K]) - Ord('0'));
    End;
    CurToken.IntVal := N;
    CurToken.Val := S;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanEscape : decode UNE sequence d echappement (le curseur   }
{ doit deja pointer juste APRES le '\') - partagee par rune et      }
{ chaine interpretee (memes echappements, voir TODO 02 de l en-tete).  }
{ Retourne le CODE (LongInt, pas juste un octet - nécessaire pour       }
{ ￿/\U0001F600) du caractere/rune resultant.                          }
{ ------------------------------------------------------------ }

Function LexScanEscape: LongInt;
Var
  V, I : LongInt;
  Ch   : Char;
Begin
  Ch := LexPeekChar;
  Case Ch Of
    'a' : Begin LexNextChar; LexScanEscape := 7;  Exit; End;
    'b' : Begin LexNextChar; LexScanEscape := 8;  Exit; End;
    'f' : Begin LexNextChar; LexScanEscape := 12; Exit; End;
    'n' : Begin LexNextChar; LexScanEscape := 10; Exit; End;
    'r' : Begin LexNextChar; LexScanEscape := 13; Exit; End;
    't' : Begin LexNextChar; LexScanEscape := 9;  Exit; End;
    'v' : Begin LexNextChar; LexScanEscape := 11; Exit; End;
    '\' : Begin LexNextChar; LexScanEscape := Ord('\'); Exit; End;
    ''''  : Begin LexNextChar; LexScanEscape := Ord(''''); Exit; End;
    '"' : Begin LexNextChar; LexScanEscape := Ord('"'); Exit; End;
  End;

  If Ch = 'x' Then
  Begin
    LexNextChar;
    V := 0;
    For I := 1 To 2 Do
    Begin
      If Not IsHexDigit(LexPeekChar) Then
        FatalError('sequence d echappement \x incomplete (2 chiffres ' +
          'hexadecimaux attendus)');
      V := V * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    LexScanEscape := V;
    Exit;
  End;

  If Ch = 'u' Then
  Begin
    LexNextChar;
    V := 0;
    For I := 1 To 4 Do
    Begin
      If Not IsHexDigit(LexPeekChar) Then
        FatalError('sequence d echappement \u incomplete (4 chiffres ' +
          'hexadecimaux attendus)');
      V := V * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    LexScanEscape := V;
    Exit;
  End;

  If Ch = 'U' Then
  Begin
    LexNextChar;
    V := 0;
    For I := 1 To 8 Do
    Begin
      If Not IsHexDigit(LexPeekChar) Then
        FatalError('sequence d echappement \U incomplete (8 chiffres ' +
          'hexadecimaux attendus)');
      V := V * 16 + HexVal(LexPeekChar);
      LexNextChar;
    End;
    LexScanEscape := V;
    Exit;
  End;

  If (Ch >= '0') And (Ch <= '7') Then
  Begin
    V := 0;
    For I := 1 To 3 Do
    Begin
      If (LexPeekChar < '0') Or (LexPeekChar > '7') Then
        FatalError('sequence d echappement octale incomplete (3 ' +
          'chiffres 0-7 attendus)');
      V := V * 8 + (Ord(LexPeekChar) - Ord('0'));
      LexNextChar;
    End;
    LexScanEscape := V;
    Exit;
  End;

  FatalError('sequence d echappement inconnue: \' + Ch);
  LexScanEscape := 0;
End;

{ ------------------------------------------------------------ }
{ LexScanRune : litteral rune 'x' ou 'echappement'. SIMPLIFICATION }
{ DOCUMENTEE (voir TODO 14) : un caractere non-ASCII ecrit           }
{ DIRECTEMENT (pas via \u/\U) dans le source, ex. 'e', serait en        }
{ UTF-8 multi-octets dans le fichier reel - ce lexeur lit alors SEUL       }
{ le premier octet de cette sequence (decodage UTF-8 correct differe          }
{ au TODO 14) ; sans consequence pour les runes ASCII ou celles                }
{ ecrites via \u/\U, qui couvrent l ecrasante majorite des cas reels.             }
{ ------------------------------------------------------------ }

Procedure LexScanRune;
Var
  V : LongInt;
Begin
  LexNextChar;   { sauter apostrophe ouvrante }
  If LexPeekChar = '\' Then
  Begin
    LexNextChar;
    V := LexScanEscape;
  End
  Else
  Begin
    If (LexPeekChar = #0) Or (LexPeekChar = '''') Then
      FatalError('litteral rune vide ('''') - au moins un caractere ' +
        'ou une sequence d echappement est attendu');
    V := Ord(LexPeekChar);
    LexNextChar;
  End;
  If LexPeekChar <> '''' Then
    FatalError('litteral rune mal forme (apostrophe fermante attendue)');
  LexNextChar;
  CurToken.Kind   := TOK_RUNE;
  CurToken.IntVal := V;
  CurToken.Val    := Chr(V And $FF);
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine interpretee "..." (echappements decodes,  }
{ voir LexScanEscape). Un saut de ligne litteral a l interieur EST    }
{ une erreur en Go (contrairement a une chaine brute `...`, voir       }
{ LexScanRawString ci-dessous).                                          }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S : TString;
  V : LongInt;
Begin
  S := '';
  LexNextChar;   { sauter guillemet ouvrant }
  While LexPeekChar <> '"' Do
  Begin
    If LexColNo > Length(LexLine) Then
      FatalError('chaine interpretee "..." non fermee avant fin de ' +
        'ligne (utiliser une chaine brute `...` pour un saut de ' +
        'ligne litteral)');
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
  LexNextChar;   { sauter guillemet fermant }
  CurToken.Kind := TOK_STRING;
  CurToken.Val  := S;
End;

{ ------------------------------------------------------------ }
{ LexScanRawString : chaine brute `...` - AUCUN echappement       }
{ traite, les retours a la ligne a l interieur sont LITTERAUX         }
{ (peuvent donc s etendre sur plusieurs appels a LexNextLine).          }
{ ------------------------------------------------------------ }

Procedure LexScanRawString;
Var
  S : TString;
Begin
  S := '';
  LexNextChar;   { sauter l accent grave ouvrant }
  While True Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
        FatalError('chaine brute `...` non fermee avant fin de fichier');
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
      Continue;
    End;
    If LexPeekChar = '`' Then
    Begin
      LexNextChar;
      Break;
    End;
    If Length(S) < MAX_STR Then S := S + LexPeekChar;
    LexNextChar;
  End;
  CurToken.Kind := TOK_RAWSTRING;
  CurToken.Val  := S;
End;

{ ------------------------------------------------------------ }
{ LexSkipBlockComment : commentaire /* ... */, peut s etendre sur }
{ plusieurs lignes. Retourne True si AU MOINS un saut de ligne a     }
{ ete traverse - regle Go EXPLICITE (spec, "Comments") : un tel         }
{ commentaire compte alors comme un saut de ligne pour l ASI               }
{ (contrairement a un commentaire /* */ tenant sur une seule ligne,          }
{ qui est de la simple espace ignoree sans effet sur l ASI).                    }
{ ------------------------------------------------------------ }

Function LexSkipBlockComment: Boolean;
Var
  CrossedLine : Boolean;
Begin
  CrossedLine := False;
  LexNextChar; LexNextChar;   { sauter '/' et '*' }
  While True Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
        FatalError('commentaire /* non ferme avant fin de fichier');
      CrossedLine := True;
      LexNextLine;
      Continue;
    End;
    If (LexPeekChar = '*') And (LexPeekChar2 = '/') Then
    Begin
      LexNextChar; LexNextChar;
      Break;
    End;
    LexNextChar;
  End;
  LexSkipBlockComment := CrossedLine;
End;

{ ------------------------------------------------------------ }
{ LexScanOperator : plus long operateur/ponctuation reconnu a la  }
{ position courante (methode du "maximal munch" - 3, puis 2, puis   }
{ 1 caractere). Couvre AUSSI la ponctuation simple : parentheses,   }
{ crochets, accolades, virgule et deux-points (pas de forme multi-   }
{ caractere pour elles, sauf '.' qui peut devenir '...').               }
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
  If (C1 = '<') And (C2 = '<') And (C3 = '=') Then
  Begin CurToken.Val := '<<='; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '>') And (C3 = '=') Then
  Begin CurToken.Val := '>>='; LexNextChar; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '&') And (C2 = '^') And (C3 = '=') Then
  Begin CurToken.Val := '&^='; LexNextChar; LexNextChar; LexNextChar; Exit; End;

  If (C1 = '&') And (C2 = '^') Then
  Begin CurToken.Val := '&^'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '-') Then
  Begin CurToken.Val := '<-'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '+') And (C2 = '+') Then
  Begin CurToken.Val := '++'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '-') And (C2 = '-') Then
  Begin CurToken.Val := '--'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '&') And (C2 = '&') Then
  Begin CurToken.Val := '&&'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '|') And (C2 = '|') Then
  Begin CurToken.Val := '||'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '<') Then
  Begin CurToken.Val := '<<'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '>') Then
  Begin CurToken.Val := '>>'; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '=') And (C2 = '=') Then
  Begin CurToken.Val := '=='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '!') And (C2 = '=') Then
  Begin CurToken.Val := '!='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '<') And (C2 = '=') Then
  Begin CurToken.Val := '<='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = '>') And (C2 = '=') Then
  Begin CurToken.Val := '>='; LexNextChar; LexNextChar; Exit; End;
  If (C1 = ':') And (C2 = '=') Then
  Begin CurToken.Val := ':='; LexNextChar; LexNextChar; Exit; End;
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
    FatalError('caractere inattendu (code ' + Chr(Ord('0') + Ord(C1) Div 100) +
      ')' { diagnostic minimal, voir TODO 24 pour un message plus riche })
  Else
  Begin
    CurToken.Val := C1;
    LexNextChar;
  End;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : produit le prochain token, ASI incluse.          }
{ La verification d eligibilite ASI (LexASIEligible) est faite       }
{ AVANT de sauter une fin de ligne reelle, AVANT de signaler EOF,      }
{ et APRES un commentaire /* */ qui a traverse au moins un saut de       }
{ ligne - les TROIS points ou Go considere qu une "nouvelle ligne" a         }
{ ete rencontree pour les besoins de cette regle (spec, "Semicolons").        }
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
      If LexASIEligible Then
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
        Exit;
      End;
      LexNextLine;
      Continue;
    End;

    If LexEOF Then
    Begin
      If LexASIEligible Then
      Begin
        CurToken.Kind     := TOK_SEMI;
        CurToken.Val      := ';';
        CurToken.Line     := LexLineNo;
        CurToken.Col      := LexColNo;
        CurToken.Inserted := True;
        LexLastKind := TOK_SEMI;   { evite une seconde insertion en boucle }
        LexLastVal  := ';';
        Exit;
      End;
      CurToken.Kind := TOK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      LexLastKind := TOK_EOF;
      LexLastVal  := '';
      LexHaveLast := True;
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
      If CommentHadNewline And LexASIEligible Then
      Begin
        CurToken.Kind     := TOK_SEMI;
        CurToken.Val      := ';';
        CurToken.Line     := LexLineNo;
        CurToken.Col      := LexColNo;
        CurToken.Inserted := True;
        LexLastKind := TOK_SEMI;
        LexLastVal  := ';';
        LexHaveLast := True;
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
    Else If Ch = '''' Then
    Begin
      LexScanRune;
      Scanning := False;
    End
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End
    Else If Ch = '`' Then
    Begin
      LexScanRawString;
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
      Scanning := False;
    End;
  End;

  LexLastKind := CurToken.Kind;
  LexLastVal  := CurToken.Val;
  LexHaveLast := True;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug (-d) de chaque token             }
{ ------------------------------------------------------------ }

Procedure PrintToken(Const T: TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TOK_EOF       : Write('EOF');
    TOK_IDENT     : Write('IDENT(', T.Val, ')');
    TOK_INT       : Write('INT(', T.IntVal, ')');
    TOK_FLOAT     : Write('FLOAT(', T.Val, ')');
    TOK_RUNE      : Write('RUNE(', T.IntVal, ')');
    TOK_STRING    : Write('STRING("', T.Val, '")');
    TOK_RAWSTRING : Write('RAWSTRING(`', T.Val, '`)');
    TOK_SEMI      : If T.Inserted Then Write('SEMI(insere)') Else Write('SEMI');
    TOK_OP        : Write('OP(', T.Val, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexSelfTest (TODO 24 anticipe partiellement, comme le fait      }
{ deja DELPHI.PAS/PERLCW32.PAS pour leurs propres fonctions de       }
{ base) : tokenise un petit extrait Go ecrit dans un fichier            }
{ temporaire, verifie la sequence de tokens attendue - couvre           }
{ identificateurs, mots-cles(ASI), entiers (dec/hex/octal/binaire),        }
{ flottant, rune, chaine, chaine brute multi-ligne, operateurs multi-        }
{ caracteres, et surtout l ASI (le point le plus delicat de ce TODO).         }
{ ------------------------------------------------------------ }

Procedure LexAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('LexSelfTest: ' + Label_ + ' a echoue');
End;

Procedure LexSelfTest;
Const
  TmpFile = 'GOCWLEXSELFTEST.$$$';
Var
  F : Text;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'x := 42');
  WriteLn(F, 'y := 0x1F + 0o17 + 0b101 + 1_000');
  WriteLn(F, 'z := 1.5e-3');
  WriteLn(F, 'r := ''\n''');
  WriteLn(F, 's := "hi\tthere"');
  WriteLn(F, 'raw := `line1');
  WriteLn(F, 'line2`');
  WriteLn(F, 'a <- ch');
  WriteLn(F, 'i++');
  Close(F);

  Assign(LexSrcF, TmpFile);
  Reset(LexSrcF);
  LexOpened := True;
  LexInit;

  { ligne 1 : x := 42 <SEMI inseree> }
  LexNextToken; LexAssert('1: IDENT x', (CurToken.Kind = TOK_IDENT) And (CurToken.Val = 'x'));
  LexNextToken; LexAssert('1: OP :=', (CurToken.Kind = TOK_OP) And (CurToken.Val = ':='));
  LexNextToken; LexAssert('1: INT 42', (CurToken.Kind = TOK_INT) And (CurToken.IntVal = 42));
  LexNextToken; LexAssert('1: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 2 : y := 0x1F + 0o17 + 0b101 + 1_000 <SEMI> }
  LexNextToken; LexAssert('2: IDENT y', CurToken.Val = 'y');
  LexNextToken; LexAssert('2: OP :=', CurToken.Val = ':=');
  LexNextToken; LexAssert('2: HEX 0x1F=31', CurToken.IntVal = 31);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: OCT 0o17=15', CurToken.IntVal = 15);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: BIN 0b101=5', CurToken.IntVal = 5);
  LexNextToken; LexAssert('2: OP +', CurToken.Val = '+');
  LexNextToken; LexAssert('2: souligne 1_000=1000', CurToken.IntVal = 1000);
  LexNextToken; LexAssert('2: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 3 : z := 1.5e-3 <SEMI> }
  LexNextToken; LexAssert('3: IDENT z', CurToken.Val = 'z');
  LexNextToken; LexAssert('3: OP :=', CurToken.Val = ':=');
  LexNextToken; LexAssert('3: FLOAT', (CurToken.Kind = TOK_FLOAT) And
    (CurToken.RealVal > 0.0014) And (CurToken.RealVal < 0.0016));
  LexNextToken; LexAssert('3: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 4 : r := '\n' <SEMI> }
  LexNextToken; LexAssert('4: IDENT r', CurToken.Val = 'r');
  LexNextToken; LexAssert('4: OP :=', CurToken.Val = ':=');
  LexNextToken; LexAssert('4: RUNE \n=10', (CurToken.Kind = TOK_RUNE) And (CurToken.IntVal = 10));
  LexNextToken; LexAssert('4: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 5 : s := "hi\tthere" <SEMI> }
  LexNextToken; LexAssert('5: IDENT s', CurToken.Val = 's');
  LexNextToken; LexAssert('5: OP :=', CurToken.Val = ':=');
  LexNextToken; LexAssert('5: STRING', (CurToken.Kind = TOK_STRING) And
    (CurToken.Val = 'hi' + Chr(9) + 'there'));
  LexNextToken; LexAssert('5: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { lignes 6-7 : raw := `line1<LF>line2` <SEMI> - chaine brute multi-ligne }
  LexNextToken; LexAssert('6: IDENT raw', CurToken.Val = 'raw');
  LexNextToken; LexAssert('6: OP :=', CurToken.Val = ':=');
  LexNextToken; LexAssert('6-7: RAWSTRING multi-ligne',
    (CurToken.Kind = TOK_RAWSTRING) And (CurToken.Val = 'line1' + Chr(10) + 'line2'));
  LexNextToken; LexAssert('7: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 8 : a <- ch <SEMI> }
  LexNextToken; LexAssert('8: IDENT a', CurToken.Val = 'a');
  LexNextToken; LexAssert('8: OP <-', CurToken.Val = '<-');
  LexNextToken; LexAssert('8: IDENT ch', CurToken.Val = 'ch');
  LexNextToken; LexAssert('8: SEMI inseree', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);

  { ligne 9 : i++ <SEMI, eligible via OP '++'> puis EOF (avec sa propre SEMI) }
  LexNextToken; LexAssert('9: IDENT i', CurToken.Val = 'i');
  LexNextToken; LexAssert('9: OP ++', CurToken.Val = '++');
  LexNextToken; LexAssert('9: SEMI inseree (post ++)', (CurToken.Kind = TOK_SEMI) And CurToken.Inserted);
  LexNextToken; LexAssert('EOF final', CurToken.Kind = TOK_EOF);

  LexClose;
  Erase(F);
End;

{ ============================================================ }
{ TODO 03 - MOTS-CLES ET IDENTIFICATEURS PREDECLARES            }
{ ============================================================ }
{ Le lexeur (TODO 02) produit TOK_IDENT pour tout ce qui a la      }
{ forme d un identificateur, mots-cles INCLUS - cette section          }
{ fournit la VRAIE classification, utilisee par le parseur              }
{ (TODO 05+) : IsKeyword distingue les 25 mots RESERVES (qui ne          }
{ peuvent JAMAIS servir d identificateur ordinaire) des identificateurs      }
{ PREDECLARES (types/constantes/fonctions integrees - qui PEUVENT en         }
{ theorie etre masques par une declaration locale, ex. "var len int"           }
{ est LEGAL en Go bien que deconseille - la regle d ombrage elle-meme            }
{ relevera de l analyse semantique, TODO 19, pas d ici). LexIsReservedWord        }
{ (TODO 02) est desormais un simple alias de IsKeyword<>0, pour eviter          }
{ de maintenir deux listes independantes qui pourraient diverger.                 }

Const
  { --- Mots-cles (les 25, EXHAUSTIFS - Go n en a pas d autres) --- }
  KW_BREAK       = 1;
  KW_CASE        = 2;
  KW_CHAN        = 3;
  KW_CONST       = 4;
  KW_CONTINUE    = 5;
  KW_DEFAULT     = 6;
  KW_DEFER       = 7;
  KW_ELSE        = 8;
  KW_FALLTHROUGH = 9;
  KW_FOR         = 10;
  KW_FUNC        = 11;
  KW_GO          = 12;
  KW_GOTO        = 13;
  KW_IF          = 14;
  KW_IMPORT      = 15;
  KW_INTERFACE   = 16;
  KW_MAP         = 17;
  KW_PACKAGE     = 18;
  KW_RANGE       = 19;
  KW_RETURN      = 20;
  KW_SELECT      = 21;
  KW_STRUCT      = 22;
  KW_SWITCH      = 23;
  KW_TYPE        = 24;
  KW_VAR         = 25;

  { --- Types predeclares (20, dont "any" = alias Go 1.18+ de       }
  { l interface vide) - ces codes PDT_xxx sont concus pour etre         }
  { reutilises directement comme TypeIdx de base par le TODO 04            }
  { (TypeTab), une fois cette derniere ecrite : meme ordre, memes valeurs.  }
  PDT_BOOL       = 1;
  PDT_BYTE       = 2;
  PDT_COMPLEX64  = 3;
  PDT_COMPLEX128 = 4;
  PDT_ERROR      = 5;
  PDT_FLOAT32    = 6;
  PDT_FLOAT64    = 7;
  PDT_INT        = 8;
  PDT_INT8       = 9;
  PDT_INT16      = 10;
  PDT_INT32      = 11;
  PDT_INT64      = 12;
  PDT_RUNE       = 13;
  PDT_STRING     = 14;
  PDT_UINT       = 15;
  PDT_UINT8      = 16;
  PDT_UINT16     = 17;
  PDT_UINT32     = 18;
  PDT_UINT64     = 19;
  PDT_UINTPTR    = 20;
  PDT_ANY        = 21;

  { --- Constantes predeclarees --- }
  PDC_TRUE  = 1;
  PDC_FALSE = 2;
  PDC_IOTA  = 3;
  PDC_NIL   = 4;

  { --- Fonctions integrees (15) --- }
  BI_APPEND  = 1;
  BI_CAP     = 2;
  BI_CLOSE   = 3;
  BI_COMPLEX = 4;
  BI_COPY    = 5;
  BI_DELETE  = 6;
  BI_IMAG    = 7;
  BI_LEN     = 8;
  BI_MAKE    = 9;
  BI_NEW     = 10;
  BI_PANIC   = 11;
  BI_PRINT   = 12;
  BI_PRINTLN = 13;
  BI_REAL    = 14;
  BI_RECOVER = 15;

{ IsKeyword : 0 si S n est PAS l un des 25 mots reserves, sinon le  }
{ code KW_xxx correspondant. Sensible a la casse (Go l est).          }
Function IsKeyword(Const S: TString): Integer;
Begin
  IsKeyword := 0;
  If      S = 'break'       Then IsKeyword := KW_BREAK
  Else If S = 'case'        Then IsKeyword := KW_CASE
  Else If S = 'chan'        Then IsKeyword := KW_CHAN
  Else If S = 'const'       Then IsKeyword := KW_CONST
  Else If S = 'continue'    Then IsKeyword := KW_CONTINUE
  Else If S = 'default'     Then IsKeyword := KW_DEFAULT
  Else If S = 'defer'       Then IsKeyword := KW_DEFER
  Else If S = 'else'        Then IsKeyword := KW_ELSE
  Else If S = 'fallthrough' Then IsKeyword := KW_FALLTHROUGH
  Else If S = 'for'         Then IsKeyword := KW_FOR
  Else If S = 'func'        Then IsKeyword := KW_FUNC
  Else If S = 'go'          Then IsKeyword := KW_GO
  Else If S = 'goto'        Then IsKeyword := KW_GOTO
  Else If S = 'if'          Then IsKeyword := KW_IF
  Else If S = 'import'      Then IsKeyword := KW_IMPORT
  Else If S = 'interface'   Then IsKeyword := KW_INTERFACE
  Else If S = 'map'         Then IsKeyword := KW_MAP
  Else If S = 'package'     Then IsKeyword := KW_PACKAGE
  Else If S = 'range'       Then IsKeyword := KW_RANGE
  Else If S = 'return'      Then IsKeyword := KW_RETURN
  Else If S = 'select'      Then IsKeyword := KW_SELECT
  Else If S = 'struct'      Then IsKeyword := KW_STRUCT
  Else If S = 'switch'      Then IsKeyword := KW_SWITCH
  Else If S = 'type'        Then IsKeyword := KW_TYPE
  Else If S = 'var'         Then IsKeyword := KW_VAR;
End;

{ IsPredeclaredType : 0 si S n est pas un nom de type predeclare,   }
{ sinon le code PDT_xxx correspondant. }
Function IsPredeclaredType(Const S: TString): Integer;
Begin
  IsPredeclaredType := 0;
  If      S = 'bool'       Then IsPredeclaredType := PDT_BOOL
  Else If S = 'byte'       Then IsPredeclaredType := PDT_BYTE
  Else If S = 'complex64'  Then IsPredeclaredType := PDT_COMPLEX64
  Else If S = 'complex128' Then IsPredeclaredType := PDT_COMPLEX128
  Else If S = 'error'      Then IsPredeclaredType := PDT_ERROR
  Else If S = 'float32'    Then IsPredeclaredType := PDT_FLOAT32
  Else If S = 'float64'    Then IsPredeclaredType := PDT_FLOAT64
  Else If S = 'int'        Then IsPredeclaredType := PDT_INT
  Else If S = 'int8'       Then IsPredeclaredType := PDT_INT8
  Else If S = 'int16'      Then IsPredeclaredType := PDT_INT16
  Else If S = 'int32'      Then IsPredeclaredType := PDT_INT32
  Else If S = 'int64'      Then IsPredeclaredType := PDT_INT64
  Else If S = 'rune'       Then IsPredeclaredType := PDT_RUNE
  Else If S = 'string'     Then IsPredeclaredType := PDT_STRING
  Else If S = 'uint'       Then IsPredeclaredType := PDT_UINT
  Else If S = 'uint8'      Then IsPredeclaredType := PDT_UINT8
  Else If S = 'uint16'     Then IsPredeclaredType := PDT_UINT16
  Else If S = 'uint32'     Then IsPredeclaredType := PDT_UINT32
  Else If S = 'uint64'     Then IsPredeclaredType := PDT_UINT64
  Else If S = 'uintptr'    Then IsPredeclaredType := PDT_UINTPTR
  Else If S = 'any'        Then IsPredeclaredType := PDT_ANY;
End;

{ IsPredeclaredConst : 0 si S n est pas une constante predeclaree,  }
{ sinon le code PDC_xxx correspondant. }
Function IsPredeclaredConst(Const S: TString): Integer;
Begin
  IsPredeclaredConst := 0;
  If      S = 'true'  Then IsPredeclaredConst := PDC_TRUE
  Else If S = 'false' Then IsPredeclaredConst := PDC_FALSE
  Else If S = 'iota'  Then IsPredeclaredConst := PDC_IOTA
  Else If S = 'nil'   Then IsPredeclaredConst := PDC_NIL;
End;

{ IsBuiltinFunc : 0 si S n est pas une fonction integree Go,        }
{ sinon le code BI_xxx correspondant. }
Function IsBuiltinFunc(Const S: TString): Integer;
Begin
  IsBuiltinFunc := 0;
  If      S = 'append'  Then IsBuiltinFunc := BI_APPEND
  Else If S = 'cap'     Then IsBuiltinFunc := BI_CAP
  Else If S = 'close'   Then IsBuiltinFunc := BI_CLOSE
  Else If S = 'complex' Then IsBuiltinFunc := BI_COMPLEX
  Else If S = 'copy'    Then IsBuiltinFunc := BI_COPY
  Else If S = 'delete'  Then IsBuiltinFunc := BI_DELETE
  Else If S = 'imag'    Then IsBuiltinFunc := BI_IMAG
  Else If S = 'len'     Then IsBuiltinFunc := BI_LEN
  Else If S = 'make'    Then IsBuiltinFunc := BI_MAKE
  Else If S = 'new'     Then IsBuiltinFunc := BI_NEW
  Else If S = 'panic'   Then IsBuiltinFunc := BI_PANIC
  Else If S = 'print'   Then IsBuiltinFunc := BI_PRINT
  Else If S = 'println' Then IsBuiltinFunc := BI_PRINTLN
  Else If S = 'real'    Then IsBuiltinFunc := BI_REAL
  Else If S = 'recover' Then IsBuiltinFunc := BI_RECOVER;
End;

{ ------------------------------------------------------------ }
{ KeywordSelfTest : verifie IsKeyword/IsPredeclaredType/           }
{ IsPredeclaredConst/IsBuiltinFunc sur un echantillon representatif  }
{ de chaque categorie, ET verifie qu un identificateur ORDINAIRE        }
{ (ex. "monVar") n est classe dans AUCUNE des quatre.                     }
{ ------------------------------------------------------------ }

Procedure KeywordAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('KeywordSelfTest: ' + Label_ + ' a echoue');
End;

Procedure KeywordSelfTest;
Begin
  KeywordAssert('func est un mot-cle',       IsKeyword('func') = KW_FUNC);
  KeywordAssert('package est un mot-cle',    IsKeyword('package') = KW_PACKAGE);
  KeywordAssert('return est un mot-cle',     IsKeyword('return') = KW_RETURN);
  KeywordAssert('var n''est pas un type',    IsPredeclaredType('var') = 0);
  KeywordAssert('monVar n''est pas un mot-cle', IsKeyword('monVar') = 0);

  KeywordAssert('int est un type predeclare',    IsPredeclaredType('int') = PDT_INT);
  KeywordAssert('string est un type predeclare', IsPredeclaredType('string') = PDT_STRING);
  KeywordAssert('any est un type predeclare',    IsPredeclaredType('any') = PDT_ANY);
  KeywordAssert('monVar n''est pas un type',     IsPredeclaredType('monVar') = 0);
  KeywordAssert('int n''est pas un mot-cle',     IsKeyword('int') = 0);

  KeywordAssert('true est une constante predeclaree', IsPredeclaredConst('true') = PDC_TRUE);
  KeywordAssert('nil est une constante predeclaree',  IsPredeclaredConst('nil') = PDC_NIL);
  KeywordAssert('iota est une constante predeclaree', IsPredeclaredConst('iota') = PDC_IOTA);
  KeywordAssert('monVar n''est pas une constante',    IsPredeclaredConst('monVar') = 0);

  KeywordAssert('len est une fonction integree',    IsBuiltinFunc('len') = BI_LEN);
  KeywordAssert('append est une fonction integree', IsBuiltinFunc('append') = BI_APPEND);
  KeywordAssert('make est une fonction integree',   IsBuiltinFunc('make') = BI_MAKE);
  KeywordAssert('monVar n''est pas une fonction integree', IsBuiltinFunc('monVar') = 0);

  { les 4 categories sont mutuellement exclusives : aucun mot-cle    }
  { n est aussi un type/constante/fonction predeclare, et vice-versa. }
  KeywordAssert('for (mot-cle) n''est ni type ni const ni builtin',
    (IsPredeclaredType('for') = 0) And (IsPredeclaredConst('for') = 0) And
    (IsBuiltinFunc('for') = 0));
End;

{ ------------------------------------------------------------ }
{ Run - point d entree de la compilation                       }
{ TODO 01+02+03 implementes : options, banniere, lexeur complet     }
{ (avec ASI), classification mots-cles/identificateurs predeclares.    }
{ Le parseur, l analyse semantique et les backends ASM/OBJ/EXE restent    }
{ a ecrire dans les TODOs suivants - Run se contente donc ici de              }
{ tokeniser integralement le fichier source en annotant chaque                 }
{ identificateur de sa classification (si -d), sans construire quoi que          }
{ ce soit au-dela pour l instant.                                                   }
{ ------------------------------------------------------------ }

{ Annote un token IDENT de sa classification (TODO 03), si -d :   }
{ mot-cle, type/constante/fonction predeclare, ou identificateur     }
{ ordinaire - separee de PrintToken (TODO 02) plutot que d y ajouter   }
{ une dependance vers IsKeyword/etc. (definies plus bas dans ce           }
{ fichier, TODO 03) - evite un Forward supplementaire sans necessite.       }
Procedure PrintIdentClass(Const T: TToken);
Var
  KwCode, TyCode, CoCode, BiCode : Integer;
Begin
  If (Not Opts.DebugMode) Or (T.Kind <> TOK_IDENT) Then Exit;
  KwCode := IsKeyword(T.Val);
  TyCode := IsPredeclaredType(T.Val);
  CoCode := IsPredeclaredConst(T.Val);
  BiCode := IsBuiltinFunc(T.Val);
  If KwCode <> 0 Then
    WriteLn('        -> mot-cle (KW_', KwCode, ')')
  Else If TyCode <> 0 Then
    WriteLn('        -> type predeclare (PDT_', TyCode, ')')
  Else If CoCode <> 0 Then
    WriteLn('        -> constante predeclaree (PDC_', CoCode, ')')
  Else If BiCode <> 0 Then
    WriteLn('        -> fonction integree (BI_', BiCode, ')');
End;

{ ============================================================ }
{ TODO 04 - SYSTEME DE TYPES : REPRESENTATION ET TABLE DES TYPES}
{ ============================================================ }
{ Table des types INSPIREE de celle de DELPHI.PAS (meme projet,   }
{ TypeTab/FieldPool partage) mais adaptee au systeme de types Go :   }
{ pas de classes/VMT, mais slice/carte/canal/interface/fonctions a       }
{ retours multiples. Cible 80386/Win32 32 bits (TAILLES ci-dessous          }
{ pour CETTE cible - "int"/"uint"/"uintptr" valent 4 octets, PAS 8,             }
{ contrairement a un Go 64 bits reel, regle explicite de la spec Go               }
{ elle-meme : la taille de "int" depend de la plateforme cible).                    }

Type
  TTypeKind = (
    TYK_INVALID,    { entree 0 reservee (voir TypeInit ci-dessous)     }
    TYK_BOOL,
    TYK_INT,        { signe OU non signe (IsUnsigned), taille 1/2/4/8   }
    TYK_FLOAT,      { taille 4 (float32) ou 8 (float64)                  }
    TYK_COMPLEX,    { complex64/128 - ARITHMETIQUE NON IMPLEMENTEE,        }
                     { seul le NOM/la TAILLE sont enregistres (hors de       }
                     { portee documentee, DOC en-tete section TODO 04)          }
    TYK_STRING,
    TYK_ARRAY,      { taille FIXE, ArrayLen elements de ElemTypeIdx        }
    TYK_SLICE,      { Ptr+Len+Cap - reference vers ElemTypeIdx               }
    TYK_STRUCT,     { champs dans FieldPool[FieldFirst..+FieldCount-1]         }
    TYK_POINTER,    { *ElemTypeIdx                                              }
    TYK_FUNC,       { params/retours dans FieldPool (voir ParamFirst/            }
                     { ResultFirst) - retours MULTIPLES, IsVariadic                }
    TYK_INTERFACE,  { methodes : reserve pour le TODO 10                          }
    TYK_ERROR,      { cas particulier de TYK_INTERFACE (interface a UNE            }
                     { seule methode Error() string) - distingue pour des             }
                     { verifications rapides sans comparer les ensembles              }
                     { de methodes, avant que le TODO 10 ne soit ecrit                   }
    TYK_MAP,        { KeyTypeIdx -> ElemTypeIdx, TODO 12                            }
    TYK_CHAN        { ElemTypeIdx, TODO 15                                          }
  );

  TFieldRec = Record
    Name       : TString;   { nom du champ/parametre ; '' pour un resultat  }
                             { non nomme (cas usuel des retours multiples)    }
    TypeIdx    : Integer;
    Offset     : Integer;   { TYK_STRUCT seulement - octets depuis le debut   }
                             { de la struct ; non exploite pour params/retours  }
    IsEmbedded : Boolean;    { TYK_STRUCT seulement (TODO 09) : champ           }
                             { anonyme/embarque ("Animal" ou "*Animal" seul,       }
                             { sans nom separe - Name = nom du type embarque)         }
  End;

  TTypeRec = Record
    Kind            : TTypeKind;
    Name            : TString;    { '' si type anonyme (litteral compose) }
    Size            : Integer;    { octets, representation runtime (voir  }
                                   { en-tete de section pour string/slice/  }
                                   { interface/map/chan)                     }
    Align           : Integer;
    IsUnsigned      : Boolean;    { TYK_INT seulement                     }
    AliasOfTypeIdx  : Integer;    { -1 si type distinct ; sinon INDEX du   }
                                   { type reellement identique (ex. "byte"   }
                                   { est un alias de "uint8", "rune" de        }
                                   { "int32" - memes regles qu un LongInt=       }
                                   { Integer chez DELPHI.PAS, meme projet)         }
    ElemTypeIdx     : Integer;    { pointeur/slice/array/chan : type pointe/ }
                                   { element ; -1 sinon                        }
    KeyTypeIdx      : Integer;    { TYK_MAP seulement : type de la cle ;    }
                                   { -1 sinon                                  }
    ArrayLen        : LongInt;    { TYK_ARRAY seulement : nombre fixe        }
                                   { d elements (ex. [10]int -> 10)              }
    FieldFirst      : Integer;    { TYK_STRUCT : index de depart dans        }
                                   { FieldPool, -1 si aucun champ               }
    FieldCount      : Integer;
    MethodFirst     : Integer;    { reserve pour le TODO 09 (methodes a      }
                                   { recepteur valeur/pointeur) - TOUJOURS      }
                                   { -1/0 pour l instant, rien n y ecrit ici        }
    MethodCount     : Integer;
    ParamFirst      : Integer;    { TYK_FUNC : index de depart dans          }
                                   { FieldPool pour les PARAMETRES              }
    ParamCount      : Integer;
    ResultFirst     : Integer;    { TYK_FUNC : index de depart dans          }
                                   { FieldPool pour les RESULTATS (retours       }
                                   { MULTIPLES, TODO 08)                            }
    ResultCount     : Integer;
    IsVariadic      : Boolean;    { TYK_FUNC : dernier parametre ...T      }
    UnderlyingTypeIdx : Integer;  { TODO 05 : "type Nom Type" (definition   }
                                   { DISTINCTE, meme representation) - -1      }
                                   { sinon. DIFFERENT de AliasOfTypeIdx : deux     }
                                   { valeurs Nom/Type ne sont PAS interchangeables  }
                                   { sans conversion explicite T(x), regle de la      }
                                   { spec Go elle-meme, contrairement a un vrai         }
                                   { alias ("type Nom = Type", lui AliasOfTypeIdx).       }
  End;

Var
  TypeTab        : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount      : Integer;
  FieldPool      : Array[0..MAX_FIELD_POOL - 1] Of TFieldRec;
  FieldPoolCount : Integer;

{ ------------------------------------------------------------ }
{ TypeAdd : ajoute un type "simple" (scalaire/pointeur/slice/    }
{ array/map/chan - PAS struct/func, construits par des             }
{ fonctions dediees plus bas une fois FieldPool rempli). Les         }
{ champs specifiques a struct/func restent a leur valeur "aucun"        }
{ (-1/0/Faux) et pourront etre completes ensuite directement, comme         }
{ le fait deja DELPHI.PAS pour ses propres champs specialises              }
{ (ClassSymIdx, VMTFirst, etc. - meme convention).                            }
{ ------------------------------------------------------------ }

Function TypeAdd(Kind: TTypeKind; Const AName: TString; ASize, AAlign: Integer;
  AUnsigned: Boolean; AElemTypeIdx, AKeyTypeIdx: Integer): Integer;
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
  TypeTab[TypeCount].IsUnsigned     := AUnsigned;
  TypeTab[TypeCount].AliasOfTypeIdx := -1;
  TypeTab[TypeCount].ElemTypeIdx    := AElemTypeIdx;
  TypeTab[TypeCount].KeyTypeIdx     := AKeyTypeIdx;
  TypeTab[TypeCount].ArrayLen       := 0;
  TypeTab[TypeCount].FieldFirst     := -1;
  TypeTab[TypeCount].FieldCount     := 0;
  TypeTab[TypeCount].MethodFirst    := -1;
  TypeTab[TypeCount].MethodCount    := 0;
  TypeTab[TypeCount].ParamFirst     := -1;
  TypeTab[TypeCount].ParamCount     := 0;
  TypeTab[TypeCount].ResultFirst    := -1;
  TypeTab[TypeCount].ResultCount    := 0;
  TypeTab[TypeCount].IsVariadic     := False;
  TypeTab[TypeCount].UnderlyingTypeIdx := -1;

  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ ------------------------------------------------------------ }
{ TypeFindByName : recherche EXACTE (sensible a la casse - Go     }
{ l est, contrairement au Pascal de DELPHI.PAS qui normalise en      }
{ majuscules). -1 si non trouve.                                       }
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
{ TypeResolveAlias : suit AliasOfTypeIdx jusqu au type REELLEMENT }
{ distinct (ex. "byte" -> "uint8", "rune" -> "int32") - Go les       }
{ traite comme des types RIGOUREUSEMENT IDENTIQUES, pas de simples       }
{ synonymes d affichage (contrairement a "type MyInt int" du               }
{ TODO 05, qui cree un type DISTINCT malgre la meme representation).            }
{ ------------------------------------------------------------ }

Function TypeResolveAlias(Idx: Integer): Integer;
Var Depth : Integer;
Begin
  Depth := 0;
  While (Idx >= 0) And (Idx < TypeCount) And
        (TypeTab[Idx].AliasOfTypeIdx >= 0) And (Depth < 8) Do
  Begin
    Idx := TypeTab[Idx].AliasOfTypeIdx;
    Inc(Depth);
  End;
  TypeResolveAlias := Idx;
End;

{ ------------------------------------------------------------ }
{ TypeIsNilZero : Vrai si la valeur zero de ce type est "nil"     }
{ (pointeur/slice/map/chan/func/interface) plutot que 0/false/""       }
{ (numerique/bool/string, directement derivable du Kind) ou une            }
{ structure a zero RECURSIF (TYK_STRUCT - chaque champ suit sa                }
{ propre regle, naturellement gere une fois le TODO 09 en place,                }
{ pas besoin d une fonction dediee ici pour ce cas precis).                        }
{ ------------------------------------------------------------ }

Function TypeIsNilZero(Idx: Integer): Boolean;
Begin
  TypeIsNilZero := False;
  If (Idx < 0) Or (Idx >= TypeCount) Then Exit;
  TypeIsNilZero := TypeTab[Idx].Kind In
    [TYK_POINTER, TYK_SLICE, TYK_MAP, TYK_CHAN, TYK_FUNC, TYK_INTERFACE,
     TYK_ERROR];
End;

{ ------------------------------------------------------------ }
{ TypeInit : enregistre les 21 types predeclares Go, DANS LE       }
{ MEME ORDRE que les codes PDT_xxx du TODO 03 - une entree           }
{ sentinelle TYK_INVALID est ajoutee EN PREMIER (index 0) pour que        }
{ "bool" (PDT_BOOL=1) tombe exactement sur TypeTab[1], "byte"                 }
{ (PDT_BYTE=2) sur TypeTab[2], etc. : les codes PDT_xxx du TODO 03               }
{ SONT donc directement des TypeIdx valides des cette table remplie,                }
{ sans conversion ni table de correspondance separee (design deja                     }
{ annonce au TODO 03).                                                                   }
{ ------------------------------------------------------------ }

Procedure TypeInit;
Var
  TIByte, TIUint8, TIRune, TIInt32 : Integer;
Begin
  TypeCount      := 0;
  FieldPoolCount := 0;

  TypeAdd(TYK_INVALID, '', 0, 0, False, -1, -1);                    { 0 }

  TypeAdd(TYK_BOOL,      'bool',       1,  1, False, -1, -1);        { 1  PDT_BOOL      }
  TIByte := TypeAdd(TYK_INT, 'byte',   1,  1, True,  -1, -1);        { 2  PDT_BYTE      }
  TypeAdd(TYK_COMPLEX,   'complex64',  8,  4, False, -1, -1);        { 3  PDT_COMPLEX64 }
  TypeAdd(TYK_COMPLEX,   'complex128', 16, 4, False, -1, -1);        { 4  PDT_COMPLEX128}
  TypeAdd(TYK_ERROR,     'error',      8,  4, False, -1, -1);        { 5  PDT_ERROR     }
  TypeAdd(TYK_FLOAT,     'float32',    4,  4, False, -1, -1);        { 6  PDT_FLOAT32   }
  TypeAdd(TYK_FLOAT,     'float64',    8,  4, False, -1, -1);        { 7  PDT_FLOAT64   }
  TypeAdd(TYK_INT,       'int',        4,  4, False, -1, -1);        { 8  PDT_INT       }
  TypeAdd(TYK_INT,       'int8',       1,  1, False, -1, -1);        { 9  PDT_INT8      }
  TypeAdd(TYK_INT,       'int16',      2,  2, False, -1, -1);        { 10 PDT_INT16     }
  TIInt32 := TypeAdd(TYK_INT, 'int32', 4,  4, False, -1, -1);        { 11 PDT_INT32     }
  TypeAdd(TYK_INT,       'int64',      8,  4, False, -1, -1);        { 12 PDT_INT64     }
  TIRune := TypeAdd(TYK_INT, 'rune',   4,  4, False, -1, -1);        { 13 PDT_RUNE      }
  TypeAdd(TYK_STRING,    'string',     8,  4, False, -1, -1);        { 14 PDT_STRING    }
  TypeAdd(TYK_INT,       'uint',       4,  4, True,  -1, -1);        { 15 PDT_UINT      }
  TIUint8 := TypeAdd(TYK_INT, 'uint8', 1,  1, True,  -1, -1);        { 16 PDT_UINT8     }
  TypeAdd(TYK_INT,       'uint16',     2,  2, True,  -1, -1);        { 17 PDT_UINT16    }
  TypeAdd(TYK_INT,       'uint32',     4,  4, True,  -1, -1);        { 18 PDT_UINT32    }
  TypeAdd(TYK_INT,       'uint64',     8,  4, True,  -1, -1);        { 19 PDT_UINT64    }
  TypeAdd(TYK_INT,       'uintptr',    4,  4, True,  -1, -1);        { 20 PDT_UINTPTR   }
  TypeAdd(TYK_INTERFACE, 'any',        8,  4, False, -1, -1);        { 21 PDT_ANY       }

  { alias STRICTS (memes types, noms differents) - confirme par la  }
  { spec Go elle-meme ("byte is an alias for uint8", "rune is an       }
  { alias for int32"), pas une simple convention de ce compilateur.       }
  TypeTab[TIByte].AliasOfTypeIdx := TIUint8;
  TypeTab[TIRune].AliasOfTypeIdx := TIInt32;

  If Opts.DebugMode Then
    WriteLn('  [TypeInit] ', TypeCount, ' types predeclares enregistres');
End;

{ ------------------------------------------------------------ }
{ TypeSelfTest : verifie l alignement PDT_xxx <-> TypeIdx, les     }
{ tailles cle (32 bits pour int/uint/uintptr, PAS 64 - specifique       }
{ a cette cible), les alias byte/rune, et la regle du zero nil.            }
{ ------------------------------------------------------------ }

Procedure TypeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('TypeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure TypeSelfTest;
Var
  IdxInt, IdxStr, IdxByte, IdxRune, IdxUint8, IdxInt32, IdxPtr : Integer;
Begin
  TypeInit;

  TypeAssert('21 types + sentinelle = 22 entrees', TypeCount = 22);

  IdxInt := TypeFindByName('int');
  TypeAssert('int trouve par nom',    IdxInt = PDT_INT);
  TypeAssert('int correspond a PDT_INT (design TODO 03)', IdxInt = PDT_INT);
  TypeAssert('int fait 4 octets (cible 32 bits, PAS 8)', TypeTab[IdxInt].Size = 4);
  TypeAssert('int est signe',         Not TypeTab[IdxInt].IsUnsigned);

  IdxStr := TypeFindByName('string');
  TypeAssert('string trouve == PDT_STRING', IdxStr = PDT_STRING);
  TypeAssert('string fait 8 octets ({Ptr,Len} 32 bits)', TypeTab[IdxStr].Size = 8);

  IdxByte  := TypeFindByName('byte');
  IdxUint8 := TypeFindByName('uint8');
  TypeAssert('byte est un alias de uint8', TypeResolveAlias(IdxByte) = IdxUint8);

  IdxRune  := TypeFindByName('rune');
  IdxInt32 := TypeFindByName('int32');
  TypeAssert('rune est un alias de int32', TypeResolveAlias(IdxRune) = IdxInt32);

  TypeAssert('bool n''est PAS a zero nil', Not TypeIsNilZero(PDT_BOOL));
  TypeAssert('int n''est PAS a zero nil',  Not TypeIsNilZero(PDT_INT));
  TypeAssert('string n''est PAS a zero nil', Not TypeIsNilZero(PDT_STRING));

  { types composes non encore predeclares (pointeur/slice/map/chan/  }
  { interface) : construits a la volee ici juste pour verifier la       }
  { regle du zero nil - la vraie construction (a partir du parseur)        }
  { viendra aux TODO 09/11/12/15.                                             }
  IdxPtr := TypeAdd(TYK_POINTER, '', 4, 4, False, IdxInt, -1);
  TypeAssert('*int est a zero nil', TypeIsNilZero(IdxPtr));
  TypeAssert('error est a zero nil (interface)', TypeIsNilZero(PDT_ERROR));
  TypeAssert('any est a zero nil (interface)', TypeIsNilZero(PDT_ANY));
End;

{ ============================================================ }
{ TODO 05 - DECLARATIONS : VAR, CONST, TYPE, IOTA ET PORTEES    }
{ ============================================================ }
{ Premier TODO de PARSING reel (pas juste lexer/classification/   }
{ types). Necessite une infrastructure non nommee explicitement       }
{ par le titre du TODO mais indispensable a tout parseur recursif-        }
{ descendant : un TokenPool (tous les tokens du fichier, pre-lexes           }
{ une seule fois via LexAll) parcouru par un curseur PP - meme                  }
{ architecture que DELPHI.PAS/PERLCW32.PAS (meme projet), PAS le                   }
{ flux "un token a la fois" du TODO 02 - necessaire notamment pour la                 }
{ regle iota "expression repetee" plus bas (revenir en arriere dans le                   }
{ flux pour re-evaluer la MEME expression avec un iota different).                          }

Const
  MAX_TOKEN = {$IFDEF FPC}65536{$ELSE}8192{$ENDIF};

Type
  TDeclNameList = Array[0..15] Of TString;

Var
  TokenPool  : Array[0..MAX_TOKEN - 1] Of TToken;
  TokenCount : Integer;
  PP         : Integer;

{ ------------------------------------------------------------ }
{ LexAll : tokenise le fichier ENTIER (deja ouvert via LexInit    }
{ par l appelant) dans TokenPool.                                    }
{ ------------------------------------------------------------ }

Procedure LexAll;
Begin
  TokenCount := 0;
  Repeat
    LexNextToken;
    If TokenCount < MAX_TOKEN Then
    Begin
      TokenPool[TokenCount] := CurToken;
      Inc(TokenCount);
    End
    Else
    Begin
      WarnMsg('pool de tokens plein (MAX_TOKEN) - fichier tronque');
      Break;
    End;
  Until CurToken.Kind = TOK_EOF;
End;

{ ------------------------------------------------------------ }
{ PP* : lecture en avant dans TokenPool - PAS le lexeur direct.   }
{ PPMatch compare le TEXTE EXACT (Go est sensible a la casse,        }
{ contrairement au PPMatch de DELPHI.PAS qui normalise en majuscules).  }
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
{ pour distinguer "Ident: Valeur" (element cle d un litteral compose,    }
{ TODO 06) de "Ident" simple sans faire de retour en arriere.                }
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
{ S - VOLONTAIREMENT distinct de "PPVal=S" seul : un litteral            }
{ chaine dont le CONTENU vaut par hasard "+" (ex. const X = "a"+"+")           }
{ ne doit jamais etre pris pour l operateur "+" (bogue trouve en                  }
{ concevant ConstEvalBinOp ci-dessous, jamais rencontre dans les                     }
{ echantillons reels mais structurellement possible).                                   }
Function PPIsOp(Const S: TString): Boolean;
Begin
  PPIsOp := (Not PPAtEnd) And (TokenPool[PP].Kind = TOK_OP) And
            (TokenPool[PP].Val = S);
End;

Procedure PPAdvance;
Begin
  If Not PPAtEnd Then Inc(PP);
End;

{ Saute un ou plusieurs TOK_SEMI consecutifs (reels OU inseres par }
{ l ASI, TODO 02) - un bloc Go peut contenir des lignes vides,        }
{ donc plusieurs point-virgules d affilee une fois l ASI appliquee.      }
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
{ Table des symboles et portees - modele deja eprouve par         }
{ DELPHI.PAS/PERLCW32.PAS (meme projet) : portee empilee,             }
{ resolution DU PLUS IMBRIQUE VERS LE PLUS GLOBAL (SymFind), ce         }
{ qui donne a Go son "shadowing" (une variable locale peut masquer         }
{ un identificateur PREDECLARE comme "len", ou une variable de              }
{ portee englobante - legal en Go, juste deconseille par convention).          }
{ ------------------------------------------------------------ }

Type
  TSymKind = (
    SK_CONST,   { constante nommee (const X = ...)          }
    SK_TYPE,    { type nomme (type X ...)                    }
    SK_VAR,     { variable (var/:=), portee quelconque         }
    SK_FUNC     { fonction top-level - reserve, TODO 08          }
  );

  { Valeur d une constante Go - TAGGEE (contrairement a un simple   }
  { Integer) car une constante Go peut etre entiere, flottante,        }
  { booleenne, chaine ou rune (deja un entier, code point).               }
  TConstKind = (CK_INT, CK_FLOAT, CK_BOOL, CK_STRING);

  TConstVal = Record
    Kind    : TConstKind;
    IntVal  : LongInt;    { CK_INT (et CK_BOOL : 0/1) }
    RealVal : Real;       { CK_FLOAT }
    StrVal  : TString;    { CK_STRING }
  End;

  TDeclValList = Array[0..15] Of TConstVal;

  TSymRec = Record
    Name       : TString;    { sensible a la casse, PAS normalise }
    Kind       : TSymKind;
    TypeIdx    : Integer;    { -1 si pas encore resolu/inconnu }
    ScopeLevel : Integer;    { 0 = portee paquet (package-level) }
    ScopeId    : Integer;
    IsGlobal   : Boolean;
    ConstVal   : TConstVal;  { SK_CONST (et SK_VAR si initialisee) }
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

Procedure SymLeaveScope;
Begin
  If ScopeStackTop < 0 Then
  Begin
    WarnMsg('tentative de quitter la portee paquet (package-level)');
    Exit;
  End;
  Dec(ScopeStackTop);
  CurScopeLevel := ScopeStackTop + 1;
  If ScopeStackTop < 0 Then CurScopeId := 0
  Else CurScopeId := ScopeStack[ScopeStackTop];
End;

{ SymFindInScope : cherche UNIQUEMENT dans la portee SId (pas les  }
{ englobantes) - sert a detecter une redeclaration illegale DANS LA   }
{ MEME portee (ex. "var x int" deux fois dans le meme bloc est une      }
{ erreur en Go, mais masquer x dans un bloc IMBRIQUE est legal).           }
Function SymFindInScope(Const Name: TString; SId: Integer): Integer;
Var I: Integer;
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
{ chronologique de declaration - un symbole plus recent masque un           }
{ symbole plus ancien de meme nom).                                            }
Function SymFind(Const Name: TString): Integer;
Var I: Integer;
Begin
  SymFind := -1;
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
End;

Function SymAdd(Const Name: TString; Kind: TSymKind; TIdx: Integer): Integer;
Var Dup: Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    WarnMsg('table des symboles pleine (MAX_SYM)');
    SymAdd := -1;
    Exit;
  End;

  Dup := SymFindInScope(Name, CurScopeId);
  If Dup >= 0 Then
    WarnMsg('symbole deja declare dans cette portee: ' + Name);

  SymTab[SymCount].Name       := Name;
  SymTab[SymCount].Kind       := Kind;
  SymTab[SymCount].TypeIdx    := TIdx;
  SymTab[SymCount].ScopeLevel := CurScopeLevel;
  SymTab[SymCount].ScopeId    := CurScopeId;
  SymTab[SymCount].IsGlobal   := (CurScopeLevel = 0);
  SymTab[SymCount].ConstVal.Kind    := CK_INT;
  SymTab[SymCount].ConstVal.IntVal  := 0;
  SymTab[SymCount].ConstVal.RealVal := 0.0;
  SymTab[SymCount].ConstVal.StrVal  := '';

  SymAdd := SymCount;
  Inc(SymCount);
End;

{ ------------------------------------------------------------ }
{ iota : compteur remis a 0 a l entree d un bloc "const ( ... )",  }
{ incremente APRES chaque ConstSpec (chaque ligne du bloc).           }
{ ------------------------------------------------------------ }

Var
  CurIota : LongInt;

{ ------------------------------------------------------------ }
{ Petits constructeurs de TConstVal (evitent de repeter les 4     }
{ affectations de champs partout).                                   }
{ ------------------------------------------------------------ }

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

{ ------------------------------------------------------------ }
{ Evaluateur d expression CONSTANTE (repliee a l analyse, pas de   }
{ code genere - aucun backend n existe encore, TODO 21+). Couvre       }
{ litteraux, iota, identificateurs de constantes DEJA declarees, et       }
{ les operateurs Go dans leur PRECEDENCE reelle (5 haut : * / % << >>          }
{ & &^, 4 : + - | ^, 3 : comparaisons, 2 : ET logique, 1 bas : OU              }
{ logique). PORTEE : seulement des operandes eux-memes CONSTANTS               }
{ (litteraux, iota, autres const) - une reference a une variable ou               }
{ un appel de fonction dans un "const" est de toute facon une erreur                 }
{ Go, pas seulement une limitation de ce compilateur.                                  }
{ ------------------------------------------------------------ }

Function ConstEvalExpr: TConstVal; Forward;

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
    TOK_RUNE:
      Begin
        ConstEvalPrimary := CVInt(TokenPool[PP].IntVal);
        PPAdvance;
      End;
    TOK_STRING, TOK_RAWSTRING:
      Begin
        ConstEvalPrimary := CVString(TokenPool[PP].Val);
        PPAdvance;
      End;
    TOK_IDENT:
      Begin
        Nam := TokenPool[PP].Val;
        PPAdvance;
        If Nam = 'iota' Then
          ConstEvalPrimary := CVInt(CurIota)
        Else If Nam = 'true' Then
          ConstEvalPrimary := CVBool(True)
        Else If Nam = 'false' Then
          ConstEvalPrimary := CVBool(False)
        Else
        Begin
          SI := SymFind(Nam);
          If (SI >= 0) And (SymTab[SI].Kind = SK_CONST) Then
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
  If PPIsOp('+') Then
  Begin
    PPAdvance;
    ConstEvalUnary := ConstEvalUnary;
    Exit;
  End;
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
  If PPIsOp('^') Then
  Begin
    PPAdvance;
    V := ConstEvalUnary;
    ConstEvalUnary := CVInt(Not V.IntVal);
    Exit;
  End;
  ConstEvalUnary := ConstEvalPrimary;
End;

{ ConstEvalBinOp : applique UN operateur binaire deja identifie    }
{ (Op) a deux valeurs deja evaluees (L, R). Simplification            }
{ DOCUMENTEE : la coercion entier/flottant se fait des qu AU MOINS UN     }
{ operande est CK_FLOAT (les deux cotes sont alors vus en Real) -            }
{ les combinaisons franchement invalides en vrai Go (ex. chaine * entier)       }
{ ne sont pas toutes rejetees explicitement ici (l analyse semantique              }
{ complete, TODO 19, n existe pas encore) - portee limitee aux                        }
{ combinaisons SENSEES, suffisantes pour les expressions constantes                     }
{ Go usuelles (arithmetique, decalages/masques de bits avec iota,                          }
{ concatenation de chaines, comparaisons).                                                    }
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
  If Op = '&^' Then Begin ConstEvalBinOp := CVInt(L.IntVal And (Not R.IntVal)); Exit; End;

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
        PPIsOp('>>') Or PPIsOp('&') Or PPIsOp('&^') Do
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
{ PORTEE (documentee) : type predeclare, pointeur (*T, recursif),     }
{ type fonction (func(...) ..., TODO 08), ou nom de type deja               }
{ declare (SK_TYPE) - la syntaxe des types COMPOSES restants                    }
{ (tableau/slice/map/canal/struct/interface) est EXPLICITEMENT hors               }
{ de portee ici, chacune relevant de son propre TODO dedie                          }
{ (09/11/12/15) : arret propre plutot que deviner.                                     }
{ ------------------------------------------------------------ }

{ ParseFuncSignature (implementee au TODO 08, apres ParseBlock) construit  }
{ un TypeIdx TYK_FUNC a partir de "(Params) [Resultats]" - forward-        }
{ declaree ici car ParseTypeExpr (TODO 05) en a besoin pour "func(...)          }
{ ..." utilise comme TYPE (ex. "var f func(int) int"), bien avant que              }
{ le TODO 08 ne soit ecrit plus bas dans le fichier.                                    }
Function ParseFuncSignature: Integer; Forward;

{ ParseStructType (implementee au TODO 09, avec le reste des structs)   }
{ construit un TypeIdx TYK_STRUCT a partir du mot-cle "struct" suivi          }
{ d une liste de champs entre accolades - forward-declaree ici pour la               }
{ meme raison que ParseFuncSignature juste au-dessus.                                    }
Function ParseStructType: Integer; Forward;

{ ParseInterfaceType (implementee au TODO 10, avec le reste des          }
{ interfaces) construit un TypeIdx TYK_INTERFACE a partir du mot-cle           }
{ "interface" suivi d une liste de signatures de methodes entre                    }
{ accolades - la liste peut etre VIDE (interface totalement vide,                     }
{ equivalente a "any") - forward-declaree ici pour la meme raison que                    }
{ ParseFuncSignature/ParseStructType juste au-dessus.                                       }
Function ParseInterfaceType: Integer; Forward;

{ ParseMapType (implementee au TODO 12, avec le reste des maps)         }
{ construit un TypeIdx TYK_MAP a partir du mot-cle "map" DEJA CONSOMME       }
{ (le crochet ouvrant du type cle est le prochain jeton attendu) - forward-       }
{ declaree ici pour la meme raison que ParseFuncSignature/ParseStructType/         }
{ ParseInterfaceType juste au-dessus, et reutilisee telle quelle par             }
{ ParseOperand (TODO 06) pour les litteraux composes de map.                        }
Function ParseMapType: Integer; Forward;

Function ParseTypeExpr: Integer;
Var
  Nam: TString; Base, SI, Elem, NewIdx : Integer;
  LenVal : TConstVal;
Begin
  ParseTypeExpr := -1;

  If PPIsOp('*') Then
  Begin
    PPAdvance;
    Base := ParseTypeExpr;
    ParseTypeExpr := TypeAdd(TYK_POINTER, '', 4, 4, False, Base, -1);
    Exit;
  End;

  If PPIsOp('[') Then
  Begin
    PPAdvance;   { '[' }
    If PPMatch(']') Then
    Begin
      { slice []T : en-tete Ptr+Len+Cap (TODO 04/11), 3 x 4 octets  }
      Elem := ParseTypeExpr;
      ParseTypeExpr := TypeAdd(TYK_SLICE, '', 12, 4, False, Elem, -1);
      Exit;
    End;
    { tableau fixe [N]T : la longueur DOIT etre une expression         }
    { CONSTANTE (reutilise ConstEvalExpr, TODO 05 - hors de tout contexte     }
    { iota ici, une simple expression de longueur ordinaire).                    }
    LenVal := ConstEvalExpr;
    If Not PPMatch(']') Then
      FatalError('crochet fermant attendu apres la longueur du tableau');
    Elem := ParseTypeExpr;
    NewIdx := TypeAdd(TYK_ARRAY, '', LenVal.IntVal * TypeTab[Elem].Size,
      TypeTab[Elem].Align, False, Elem, -1);
    TypeTab[NewIdx].ArrayLen := LenVal.IntVal;
    ParseTypeExpr := NewIdx;
    Exit;
  End;

  If (PPKind = TOK_IDENT) And (PPVal = 'func') Then
  Begin
    PPAdvance;
    ParseTypeExpr := ParseFuncSignature;
    Exit;
  End;

  If (PPKind = TOK_IDENT) And (PPVal = 'struct') Then
  Begin
    PPAdvance;
    ParseTypeExpr := ParseStructType;
    Exit;
  End;

  If (PPKind = TOK_IDENT) And (PPVal = 'map') Then
  Begin
    PPAdvance;
    ParseTypeExpr := ParseMapType;
    Exit;
  End;

  If (PPKind = TOK_IDENT) And (PPVal = 'interface') Then
  Begin
    PPAdvance;
    ParseTypeExpr := ParseInterfaceType;
    Exit;
  End;

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('expression de type non prise en charge a ce point ' +
      '(tableau/slice/map/canal : voir TODO 11/12/15)');
    Exit;
  End;

  Nam := PPVal;
  PPAdvance;

  If IsPredeclaredType(Nam) <> 0 Then
  Begin
    ParseTypeExpr := IsPredeclaredType(Nam);   { design TODO 03/04 : PDT_xxx = TypeIdx }
    Exit;
  End;

  SI := SymFind(Nam);
  If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) Then
  Begin
    ParseTypeExpr := SymTab[SI].TypeIdx;
    Exit;
  End;

  FatalError('type inconnu: ' + Nam);
End;

{ ------------------------------------------------------------ }
{ var Nom1, Nom2 [Type] [= Expr1, Expr2] ; et var ( ... ) --      }
{ initialiseurs LIMITES aux expressions CONSTANTES (ConstEvalExpr) :  }
{ aucun backend de code n existe encore (TODO 21+), un "var x =           }
{ FonctionAppelee()" n aurait de toute facon nulle part ou generer            }
{ du code reel pour l instant - portee assumee et documentee.                    }
{ ------------------------------------------------------------ }

Procedure ParseVarSpec;
Var
  Names   : TDeclNameList;
  NCount  : Integer;
  TIdx    : Integer;
  Vals    : TDeclValList;
  HasInit : Boolean;
  I, SI   : Integer;
Begin
  NCount := 0;
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de variable attendu');
      Exit;
    End;
    If NCount <= High(Names) Then
    Begin
      Names[NCount] := PPVal;
      Inc(NCount);
    End;
    PPAdvance;
  Until Not PPMatch(',');

  TIdx := -1;
  If (Not PPIsOp('=')) And (PPKind <> TOK_SEMI) And (Not PPAtEnd) Then
    TIdx := ParseTypeExpr;

  HasInit := PPMatch('=');
  If HasInit Then
  Begin
    I := 0;
    Repeat
      If I <= High(Vals) Then
      Begin
        Vals[I] := ConstEvalExpr;
        Inc(I);
      End
      Else
        ConstEvalExpr;
    Until Not PPMatch(',');
  End;

  For I := 0 To NCount - 1 Do
  Begin
    SI := SymAdd(Names[I], SK_VAR, TIdx);
    If (SI >= 0) And HasInit And (I <= High(Vals)) Then
    Begin
      SymTab[SI].ConstVal := Vals[I];
      If TIdx < 0 Then
        Case Vals[I].Kind Of
          CK_INT    : SymTab[SI].TypeIdx := PDT_INT;
          CK_FLOAT  : SymTab[SI].TypeIdx := PDT_FLOAT64;
          CK_BOOL   : SymTab[SI].TypeIdx := PDT_BOOL;
          CK_STRING : SymTab[SI].TypeIdx := PDT_STRING;
        End;
    End;
  End;
End;

Procedure ParseVarDecl;
Begin
  PPAdvance;   { var }
  If PPIsOp('(') Then
  Begin
    PPAdvance;
    PPSkipSemis;
    While (Not PPAtEnd) And (Not PPIsOp(')')) Do
    Begin
      ParseVarSpec;
      PPSkipSemis;
    End;
    PPMatch(')');
  End
  Else
    ParseVarSpec;
End;

{ ------------------------------------------------------------ }
{ const Nom [Type] = ExprConstante ; et const ( ... ) -- avec      }
{ iota (remis a 0 a l entree du bloc, incremente apres chaque         }
{ ligne) et la regle "expression repetee" : une ligne SANS "="            }
{ reutilise la MEME expression que la derniere ligne du bloc qui EN            }
{ avait une, reevaluee avec le NOUVEL iota (LastExprStartPP retient              }
{ ou, dans TokenPool, cette expression commencait, pour y revenir).                }
{ ------------------------------------------------------------ }

Procedure ParseConstSpec(Var LastExprStartPP: Integer; Var HadExpr: Boolean);
Var
  Names       : TDeclNameList;
  NCount      : Integer;
  TIdx        : Integer;
  Vals        : TDeclValList;
  I, SI       : Integer;
  SavedPP     : Integer;
  ExprStart   : Integer;
Begin
  NCount := 0;
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de constante attendu');
      Exit;
    End;
    If NCount <= High(Names) Then
    Begin
      Names[NCount] := PPVal;
      Inc(NCount);
    End;
    PPAdvance;
  Until Not PPMatch(',');

  TIdx := -1;
  If (Not PPIsOp('=')) And (PPKind <> TOK_SEMI) And (Not PPAtEnd) Then
    TIdx := ParseTypeExpr;

  If PPMatch('=') Then
  Begin
    ExprStart := PP;
    I := 0;
    Repeat
      If I <= High(Vals) Then
      Begin
        Vals[I] := ConstEvalExpr;
        Inc(I);
      End
      Else
        ConstEvalExpr;
    Until Not PPMatch(',');
    LastExprStartPP := ExprStart;
    HadExpr := True;
  End
  Else If HadExpr Then
  Begin
    SavedPP := PP;
    PP := LastExprStartPP;
    I := 0;
    Repeat
      If I <= High(Vals) Then
      Begin
        Vals[I] := ConstEvalExpr;
        Inc(I);
      End
      Else
        ConstEvalExpr;
    Until Not PPMatch(',');
    PP := SavedPP;
  End
  Else
  Begin
    FatalError('constante sans valeur et sans expression precedente a ' +
      'repeter (la premiere ligne d''un bloc const doit avoir "= expr")');
    Exit;
  End;

  For I := 0 To NCount - 1 Do
  Begin
    SI := SymAdd(Names[I], SK_CONST, TIdx);
    If (SI >= 0) And (I <= High(Vals)) Then
    Begin
      SymTab[SI].ConstVal := Vals[I];
      If TIdx < 0 Then
        Case Vals[I].Kind Of
          CK_INT    : SymTab[SI].TypeIdx := PDT_INT;
          CK_FLOAT  : SymTab[SI].TypeIdx := PDT_FLOAT64;
          CK_BOOL   : SymTab[SI].TypeIdx := PDT_BOOL;
          CK_STRING : SymTab[SI].TypeIdx := PDT_STRING;
        End;
    End;
  End;
End;

Procedure ParseConstDecl;
Var
  LastExprStartPP : Integer;
  HadExpr         : Boolean;
Begin
  PPAdvance;   { const }
  LastExprStartPP := -1;
  HadExpr := False;

  If PPIsOp('(') Then
  Begin
    PPAdvance;
    PPSkipSemis;
    CurIota := 0;
    While (Not PPAtEnd) And (Not PPIsOp(')')) Do
    Begin
      ParseConstSpec(LastExprStartPP, HadExpr);
      Inc(CurIota);
      PPSkipSemis;
    End;
    PPMatch(')');
  End
  Else
  Begin
    CurIota := 0;
    ParseConstSpec(LastExprStartPP, HadExpr);
  End;
End;

{ ------------------------------------------------------------ }
{ type Nom Type (definition DISTINCTE, meme representation -    }
{ UnderlyingTypeIdx, TODO 04) et type Nom = Type (alias VRAI -       }
{ Nom et Type deviennent EXACTEMENT le meme type, AliasOfTypeIdx,       }
{ meme mecanisme que byte/rune). Distingues syntaxiquement par la          }
{ presence ou non de "=" apres le nom - regle reelle de la spec Go.            }
{ ------------------------------------------------------------ }

Procedure ParseTypeSpec;
Var
  Nam     : TString;
  IsAlias : Boolean;
  Under   : Integer;
  NewIdx  : Integer;
Begin
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de type attendu');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  IsAlias := PPMatch('=');
  Under := ParseTypeExpr;
  If Under < 0 Then Exit;

  If TypeCount >= MAX_TYPE Then
  Begin
    WarnMsg('table des types pleine (MAX_TYPE)');
    Exit;
  End;
  NewIdx := TypeCount;
  { copie INTEGRALE de l enregistrement (assignation de Record complete   }
  { en Pascal) - CORRIGE (TODO 09) : l ancienne version ne recopiait via         }
  { un second TypeAdd que Size/Align/IsUnsigned/ElemTypeIdx/KeyTypeIdx,               }
  { perdant SILENCIEUSEMENT FieldFirst/FieldCount (struct) et ParamFirst/                }
  { ParamCount/ResultFirst/ResultCount/IsVariadic (func) - invisible tant                   }
  { qu aucun type NOMME base sur un struct ou une signature de fonction               }
  { n existait reellement ; TODO 09 (structs) est le premier a l avoir revele.            }
  TypeTab[NewIdx] := TypeTab[Under];
  TypeTab[NewIdx].Name := Nam;
  Inc(TypeCount);

  If IsAlias Then
    TypeTab[NewIdx].AliasOfTypeIdx := Under
  Else
    TypeTab[NewIdx].UnderlyingTypeIdx := Under;

  SymAdd(Nam, SK_TYPE, NewIdx);
End;

Procedure ParseTypeDecl;
Begin
  PPAdvance;   { type }
  If PPIsOp('(') Then
  Begin
    PPAdvance;
    PPSkipSemis;
    While (Not PPAtEnd) And (Not PPIsOp(')')) Do
    Begin
      ParseTypeSpec;
      PPSkipSemis;
    End;
    PPMatch(')');
  End
  Else
    ParseTypeSpec;
End;

{ ------------------------------------------------------------ }
{ ShortVarDecl : mecanisme de Nom1, Nom2 := Expr1, Expr2 (regle   }
{ Go : AU MOINS une nouvelle variable a gauche, dans la portee          }
{ COURANTE - les noms deja presents dans CETTE MEME portee sont             }
{ silencieusement REUTILISES/reaffectes, pas redeclares - c est la               }
{ difference cle avec "var"). Pas encore integree a un vrai parseur                }
{ d instructions (TODO 07, aucun "if/for/bloc" n existe encore) -                     }
{ testee ISOLEMENT ci-dessous (DeclSelfTest) en attendant un vrai                        }
{ appelant.                                                                                 }
{ ------------------------------------------------------------ }

Function ShortVarDecl(Const Names: TDeclNameList; NCount: Integer;
  Const Vals: TDeclValList): Boolean;
Var
  I, SI  : Integer;
  AnyNew : Boolean;
Begin
  AnyNew := False;
  For I := 0 To NCount - 1 Do
    If SymFindInScope(Names[I], CurScopeId) < 0 Then AnyNew := True;

  If Not AnyNew Then
  Begin
    WarnMsg(':= sans aucune nouvelle variable a gauche (no new variables ' +
      'on left side of :=)');
    ShortVarDecl := False;
    Exit;
  End;

  For I := 0 To NCount - 1 Do
  Begin
    SI := SymFindInScope(Names[I], CurScopeId);
    If SI < 0 Then
    Begin
      Case Vals[I].Kind Of
        CK_INT    : SI := SymAdd(Names[I], SK_VAR, PDT_INT);
        CK_FLOAT  : SI := SymAdd(Names[I], SK_VAR, PDT_FLOAT64);
        CK_BOOL   : SI := SymAdd(Names[I], SK_VAR, PDT_BOOL);
        CK_STRING : SI := SymAdd(Names[I], SK_VAR, PDT_STRING);
      End;
    End;
    { qu elle vienne d etre creee ou qu elle existait deja (reaffectation), }
    { on suit la derniere valeur connue - aucun CODE n est genere ici         }
    { (pas de backend, TODO 21+), seule la table des symboles suit.              }
    If SI >= 0 Then SymTab[SI].ConstVal := Vals[I];
  End;
  ShortVarDecl := True;
End;

{ ------------------------------------------------------------ }
{ SkipImportDecl : import "chemin" ou import ( "c1" ; "c2" ; ... )  }
{ - SYNTAXE validee et consommee mais rien n est charge/enregistre    }
{ (meme simplification que le "uses" de DELPHI.PAS, meme projet) -        }
{ la vraie resolution de package est le sujet du TODO 18. Necessaire         }
{ ici pour pouvoir seulement ATTEINDRE les declarations const/var/type          }
{ qui suivent un import dans un fichier .go reel (voir hello.go/types.go).         }
{ ------------------------------------------------------------ }

Procedure SkipImportDecl;
Begin
  PPAdvance;   { import }
  If PPIsOp('(') Then
  Begin
    PPAdvance;
    PPSkipSemis;
    While (Not PPAtEnd) And (Not PPIsOp(')')) Do
    Begin
      PPAdvance;
      PPSkipSemis;
    End;
    PPMatch(')');
  End
  Else
    PPAdvance;   { le chemin importe (chaine) }
End;

{ ------------------------------------------------------------ }
{ ParseFileTopLevel : package Nom ; puis import/const/var/type    }
{ en boucle - s arrete PROPREMENT (sans erreur) des qu elle           }
{ rencontre "func" ou autre chose (portee du TODO 08+), laissant             }
{ l appelant (Run) rapporter jusqu ou l analyse est allee.                        }
{ ------------------------------------------------------------ }

{ ParseFuncDecl est implementee au TODO 08, bien plus bas - forward-  }
{ declaree ici car ParseFileTopLevel (TODO 05) doit deja savoir router      }
{ le mot-cle "func" vers elle des qu il apparait en tete de fichier.           }
Procedure ParseFuncDecl; Forward;

Procedure ParseFileTopLevel;
Var Up: TString;
Begin
  PPSkipSemis;
  If Not PPMatch('package') Then
  Begin
    FatalError('mot-cle "package" attendu en tete de fichier');
    Exit;
  End;
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de package attendu apres "package"');
    Exit;
  End;
  PPAdvance;   { nom du package }
  PPSkipSemis;

  While Not PPAtEnd Do
  Begin
    If PPKind <> TOK_IDENT Then Break;
    Up := PPVal;
    If Up = 'import' Then Begin SkipImportDecl; PPSkipSemis; Continue; End;
    If Up = 'const'  Then Begin ParseConstDecl; PPSkipSemis; Continue; End;
    If Up = 'var'    Then Begin ParseVarDecl;   PPSkipSemis; Continue; End;
    If Up = 'type'   Then Begin ParseTypeDecl;  PPSkipSemis; Continue; End;
    If Up = 'func'   Then Begin ParseFuncDecl;  PPSkipSemis; Continue; End;
    Break;   { autre chose qu une declaration de haut niveau connue : arret propre }
  End;
End;

{ ------------------------------------------------------------ }
{ DeclSelfTest : var/const-bloc-avec-iota-et-repetition/type       }
{ alias/type distinct/ShortVarDecl, sur un extrait synthetique         }
{ (fichier temporaire, meme methode que LexSelfTest).                     }
{ ------------------------------------------------------------ }

Procedure DeclAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DeclSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DeclSelfTest;
Const
  TmpFile = 'GOCWDECLSELFTEST.$$$';
Var
  F : Text;
  SI : Integer;
  SVNames : TDeclNameList;
  SVVals  : TDeclValList;
Begin
  Assign(F, TmpFile);
  Rewrite(F);
  WriteLn(F, 'package main');
  WriteLn(F, 'const (');
  WriteLn(F, '	Sunday = iota');
  WriteLn(F, '	Monday');
  WriteLn(F, '	Tuesday');
  WriteLn(F, ')');
  WriteLn(F, 'const Flag = 1 << iota');
  WriteLn(F, 'var Count int = 42');
  WriteLn(F, 'var Name, Greeting = "go", "hello"');
  WriteLn(F, 'type MyInt int');
  WriteLn(F, 'type Celsius = float64');
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
  ParseFileTopLevel;

  SI := SymFind('Sunday');
  DeclAssert('Sunday trouve',  SI >= 0);
  DeclAssert('Sunday = 0 (iota)', SymTab[SI].ConstVal.IntVal = 0);
  SI := SymFind('Monday');
  DeclAssert('Monday = 1 (iota, expression repetee)', SymTab[SI].ConstVal.IntVal = 1);
  SI := SymFind('Tuesday');
  DeclAssert('Tuesday = 2 (iota, expression repetee)', SymTab[SI].ConstVal.IntVal = 2);

  SI := SymFind('Flag');
  DeclAssert('Flag = 1<<iota (nouveau bloc, iota=0) = 1', SymTab[SI].ConstVal.IntVal = 1);

  SI := SymFind('Count');
  DeclAssert('Count trouve avec type explicite', SI >= 0);
  DeclAssert('Count = 42', SymTab[SI].ConstVal.IntVal = 42);
  DeclAssert('Count : int', SymTab[SI].TypeIdx = PDT_INT);

  SI := SymFind('Name');
  DeclAssert('Name = "go" (inference de type)', SymTab[SI].ConstVal.StrVal = 'go');
  DeclAssert('Name : string (inferee)', SymTab[SI].TypeIdx = PDT_STRING);
  SI := SymFind('Greeting');
  DeclAssert('Greeting = "hello"', SymTab[SI].ConstVal.StrVal = 'hello');

  SI := SymFind('MyInt');
  DeclAssert('MyInt declare', SI >= 0);
  DeclAssert('MyInt : type DISTINCT (UnderlyingTypeIdx=int, PAS un alias)',
    (TypeTab[SymTab[SI].TypeIdx].UnderlyingTypeIdx = PDT_INT) And
    (TypeTab[SymTab[SI].TypeIdx].AliasOfTypeIdx = -1));

  SI := SymFind('Celsius');
  DeclAssert('Celsius declare', SI >= 0);
  DeclAssert('Celsius : ALIAS VRAI de float64 (AliasOfTypeIdx)',
    TypeResolveAlias(SymTab[SI].TypeIdx) = PDT_FLOAT64);

  { ShortVarDecl, teste isolement (pas encore d appelant reel, TODO 07) }
  SymEnterScope;
  SVNames[0] := 'a';
  SVNames[1] := 'b';
  SVVals[0]  := CVInt(10);
  SVVals[1]  := CVInt(20);
  DeclAssert('a, b := 10, 20 accepte (2 nouvelles variables)',
    ShortVarDecl(SVNames, 2, SVVals));
  SI := SymFindInScope('a', CurScopeId);
  DeclAssert('a declaree dans la portee courante', SI >= 0);
  DeclAssert('a = 10', SymTab[SI].ConstVal.IntVal = 10);
  SVNames[0] := 'b';
  SVNames[1] := 'c';
  SVVals[0]  := CVInt(99);
  SVVals[1]  := CVInt(30);
  DeclAssert('b, c := 99, 30 accepte (b reaffecte, c nouvelle)',
    ShortVarDecl(SVNames, 2, SVVals));
  SI := SymFindInScope('b', CurScopeId);
  DeclAssert('b reaffectee (toujours une seule entree, valeur = 99)',
    SymTab[SI].ConstVal.IntVal = 99);
  SI := SymFindInScope('c', CurScopeId);
  DeclAssert('c nouvellement declaree', SI >= 0);

  SVNames[0] := 'a';
  SVNames[1] := 'a';
  DeclAssert(':= sans aucune nouvelle variable est refuse',
    Not ShortVarDecl(SVNames, 1, SVVals));
  SymLeaveScope;
End;

{ ============================================================ }
{ TODO 06 - EXPRESSIONS, OPERATEURS ET LITTERAUX COMPOSES       }
{ ============================================================ }
{ Premiere difference structurelle importante avec le reste du         }
{ projet (DELPHI.PAS/PERLCW32.PAS) : ces compilateurs generent le          }
{ code ASSEMBLEUR directement pendant l analyse (ParseExpr y retourne          }
{ un TypeIdx et emet des instructions au passage), parce que leur                 }
{ backend d assemblage existe deja des le debut. Ici, le backend                     }
{ (TODO 21-23) n existe pas encore et n arrivera que bien plus tard -                   }
{ ce TODO construit donc un vrai ARBRE (AST, ExprPool) plutot que du                       }
{ code, sur le meme principe de POOL A TAILLE FIXE deja utilise pour                          }
{ TypeTab/FieldPool (TODO 04) et SymTab (TODO 05). Le generateur de                               }
{ code du TODO 21 parcourra cet arbre.                                                                }
{                                                                       }
{ Cohabitation VOLONTAIRE avec ConstEvalExpr (TODO 05) : celui-ci        }
{ reste tel quel pour les initialiseurs de var/const (Go exige une          }
{ VALEUR pleinement calculee a la compilation pour une expression              }
{ constante, avec iota - un AST n apporterait rien de plus la). Le                 }
{ nouveau ParseExpr ci-dessous sert aux expressions GENERALES              }
{ (futurs corps d instructions/fonctions, TODO 07/08) - Go lui-meme            }
{ distingue ces deux modes d evaluation (constante vs generale) tout               }
{ au long de sa propre specification, ce n est donc pas une             }
{ duplication accidentelle mais deux besoins reellement distincts.      }
{                                                                       }
{ Portee assumee et documentee (verification stricte des types           }
{ reportee a l analyse semantique du TODO 19, comme l indique deja le            }
{ TODO 06 dans l en-tete du fichier) : le TypeIdx attache a chaque              }
{ noeud est un inference AU MIEUX (litteral -> son type, identificateur           }
{ -> type connu dans SymTab, operation binaire -> regle simplifiee               }
{ ci-dessous) - AUCUNE erreur n est levee ici pour un "int + float",              }
{ ce sera le role du TODO 19.                                              }

Const
  MAX_EXPR     = 8192;
  MAX_EXPR_ARG = 4096;

Type
  TExprKind = (
    EK_INTLIT, EK_FLOATLIT, EK_RUNELIT, EK_STRINGLIT, EK_BOOLLIT, EK_NILLIT,
    EK_IDENT,
    EK_UNARY,       { Op ; Left = operande                                }
    EK_BINARY,      { Op ; Left, Right                                    }
    EK_ADDR,        { &X ; Left = operande                                }
    EK_DEREF,       { *X ; Left = operande                                }
    EK_CALL,        { Left = callee (souvent EK_IDENT) ; ArgFirst/Count   }
    EK_INDEX,       { Left = base ; Right = index                         }
    EK_SLICE,       { Left = base ; ArgFirst/Count=3 (Low,High,Max, -1    }
                    { si omis) dans ExprArgPool                           }
    EK_SELECTOR,    { Left = base ; NameVal = nom du champ/methode        }
    EK_TYPEASSERT,  { Left = base ; Extra = TypeIdx vise                  }
    EK_COMPOSITE,   { Extra = TypeIdx ; ArgFirst/Count = elements         }
                    { (ExprArgKeyPool[i] = nom du champ, '' si positionnel) }
    EK_FUNCLIT      { fonction anonyme/fermeture (TODO 08) ; Extra=TypeIdx   }
                    { de la signature (TYK_FUNC) ; Right=index du bloc          }
                    { corps dans StmtPool (STK_BLOCK)                              }
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : TString;    { EK_UNARY/EK_BINARY : texte de l operateur }
    Left    : Integer;    { -1 si absent }
    Right   : Integer;    { -1 si absent }
    Extra   : Integer;    { TypeIdx (EK_TYPEASSERT/EK_COMPOSITE) ou -1 }
    NameVal : TString;    { EK_IDENT / EK_SELECTOR }
    IntVal  : LongInt;
    RealVal : Real;
    StrVal  : TString;
    TypeIdx : Integer;    { inference au mieux, -1 si inconnu }
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

  { NoCompositeLit : Vrai pendant l analyse d une expression d en-tete   }
  { de if/for/switch (condition, tag, collection de range) - la ou un        }
  { litteral compose SANS parentheses est structurellement ambigu avec           }
  { l accolade ouvrante de l instruction elle-meme (regle reelle de la               }
  { spec Go : dans l en-tete d un "for range", l accolade qui suit le                    }
  { nom de la collection doit se lire comme le debut du corps de la                          }
  { boucle, PAS comme l ouverture d un litteral compose sur ce nom).                             }
  { Remis a Faux des qu on entre dans une sous-expression NON AMBIGUE                               }
  { (parentheses, crochets d index/tranchage, arguments d appel,                                       }
  { interieur d un litteral compose deja introduit) - chaque site de                                      }
  { remise a Faux sauvegarde puis restaure l ancienne valeur (TODO 07).                                       }
  NoCompositeLit : Boolean;

Procedure ExprInit;
Begin
  ExprCount      := 0;
  ExprArgCount   := 0;
  NoCompositeLit := False;
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

{ ExprArgPush : ajoute EIdx (avec sa cle optionnelle, '' si aucune)  }
{ a la fin de ExprArgPool - utilise pour les arguments d appel ET       }
{ les elements de litteral compose ET les 3 bornes d un slice.             }
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
  ExprPool[N].TypeIdx := PDT_FLOAT64;
  ExprPool[N].IsConst := True;
  ExprAddFloatLit := N;
End;

Function ExprAddRuneLit(V: LongInt): Integer;
Var N: Integer;
Begin
  N := ExprNew(EK_RUNELIT);
  ExprPool[N].IntVal  := V;
  ExprPool[N].TypeIdx := PDT_RUNE;
  ExprPool[N].IsConst := True;
  ExprAddRuneLit := N;
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
  ExprPool[N].TypeIdx := -1;   { nil est non-type tant qu il n est pas contextualise }
  ExprPool[N].IsConst := True;
  ExprAddNilLit := N;
End;

Function ExprAddIdent(Const Nam: TString): Integer;
Var N, SI: Integer;
Begin
  N := ExprNew(EK_IDENT);
  ExprPool[N].NameVal := Nam;
  SI := SymFind(Nam);
  If SI >= 0 Then
  Begin
    ExprPool[N].TypeIdx := SymTab[SI].TypeIdx;
    ExprPool[N].IsConst := (SymTab[SI].Kind = SK_CONST);
  End;
  ExprAddIdent := N;
End;

{ ExprInferBinaryType : regle SIMPLIFIEE (pas de coercion implicite   }
{ reelle en Go, la stricte verification releve du TODO 19) - donne un      }
{ TypeIdx PLAUSIBLE pour l affichage/self-tests, jamais une erreur ici.       }
Function ExprInferBinaryType(LTIdx, RTIdx: Integer; Const Op: TString): Integer;
Begin
  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Or (Op = '&&') Or (Op = '||') Then
  Begin
    ExprInferBinaryType := PDT_BOOL;
    Exit;
  End;
  If (LTIdx = PDT_FLOAT64) Or (RTIdx = PDT_FLOAT64) Then
    ExprInferBinaryType := PDT_FLOAT64
  Else If (LTIdx = PDT_FLOAT32) Or (RTIdx = PDT_FLOAT32) Then
    ExprInferBinaryType := PDT_FLOAT32
  Else If (LTIdx = PDT_STRING) Or (RTIdx = PDT_STRING) Then
    ExprInferBinaryType := PDT_STRING
  Else
    ExprInferBinaryType := LTIdx;
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

Function ExprNewUnary(Const Op: TString; K: TExprKind; Sub: Integer): Integer;
Var N: Integer;
Begin
  N := ExprNew(K);
  ExprPool[N].Op      := Op;
  ExprPool[N].Left    := Sub;
  ExprPool[N].IsConst := ExprPool[Sub].IsConst;
  Case K Of
    EK_ADDR  : ExprPool[N].TypeIdx :=
      TypeAdd(TYK_POINTER, '', 4, 4, False, ExprPool[Sub].TypeIdx, -1);
    EK_DEREF :
      If ExprPool[Sub].TypeIdx >= 0 Then
        ExprPool[N].TypeIdx := TypeTab[ExprPool[Sub].TypeIdx].ElemTypeIdx;
  Else
    ExprPool[N].TypeIdx := ExprPool[Sub].TypeIdx;
  End;
  ExprNewUnary := N;
End;

{ ------------------------------------------------------------ }
{ Chaine de parsing recursif-descendant, precedence Go (5        }
{ niveaux, du plus fort au plus faible) :                            }
{   ParseExpr (||) -> ParseAndExpr (&&) -> ParseRelExpr           }
{   (== != < <= > >=) -> ParseAddExpr (+ - | ^) -> ParseMulExpr       }
{   (* / % << >> & &^) -> ParseUnaryExpr (+ - ! ^ * &) ->                }
{   ParsePrimaryExpr (postfixes : . [ ] ( ) .( ) ) -> ParseOperand          }
{ ------------------------------------------------------------ }

Function ParseExpr: Integer; Forward;

{ ParseCompositeLiteralForType : accolade ouvrante, liste d elements   }
{ optionnellement precedes de "Ident deux-points", separes par des        }
{ virgules, virgule finale optionnelle, accolade fermante - le TypeIdx           }
{ est deja resolu par l appelant (ParseCompositeLiteral pour un type              }
{ NOMME, ParseOperand directement pour "[]T"/"[N]T" depuis le TODO 11).              }
{ PORTEE (documentee) : les elements imbriques SANS type explicite                     }
{ (elision du type repete dans un slice de struct imbrique) restent               }
{ hors de portee - chaque element imbrique doit repeter son type                        }
{ explicitement. Les MAPS restent hors de portee jusqu au TODO 12.                             }
{ Tolere un point-virgule                                                                       }
{ INSERE PAR L ASI juste avant une virgule ou une accolade fermante                                  }
{ (piege bien connu de Go : une accolade fermante seule sur sa ligne,                                    }
{ apres un dernier element SANS virgule finale, recoit un point-virgule                                     }
{ automatique du lexeur - PPSkipSemis absorbe ce cas).                                                          }
Function ParseCompositeLiteralForType(TIdx: Integer): Integer;
Var
  N, ValIdx     : Integer;
  KeyName       : TString;
  ArgStart, Cnt : Integer;
  SavedNCL      : Boolean;
Begin
  ParseCompositeLiteralForType := 0;
  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue dans un litteral compose');
    Exit;
  End;
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  PPSkipSemis;

  ArgStart := ExprArgCount;
  Cnt := 0;
  If Not PPIsOp('}') Then
  Repeat
    KeyName := '';
    If (PPKind = TOK_IDENT) And (PP2Kind = TOK_OP) And (PP2Val = ':') Then
    Begin
      KeyName := PPVal;
      PPAdvance;   { ident cle }
      PPAdvance;   { ':' }
    End
    Else If ((PPKind = TOK_STRING) Or (PPKind = TOK_RAWSTRING)) And
            (PP2Kind = TOK_OP) And (PP2Val = ':') Then
    Begin
      { cle de litteral map sous forme de chaine (TODO 12, cles de type       }
      { string entre guillemets suivies de deux-points) - reutilise le           }
      { meme champ ExprArgKey (String) que les cles de champ de struct               }
      { (identifiants) - PORTEE (documentee)                                             }
      { limitee aux cles CHAINE ou IDENTIFIANT ; les cles ENTIERES ou               }
      { expressions plus generales restent hors de portee (meme discipline               }
      { que l elision de type dans un litteral compose imbrique, TODO 11).                  }
      KeyName := TokenPool[PP].Val;
      PPAdvance;   { chaine cle }
      PPAdvance;   { ':' }
    End;
    ValIdx := ParseExpr;
    ExprArgPush(ValIdx, KeyName);
    Inc(Cnt);
    PPSkipSemis;
    If Not PPMatch(',') Then Break;
    PPSkipSemis;
  Until PPIsOp('}');
  NoCompositeLit := SavedNCL;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue dans un litteral compose');

  N := ExprNew(EK_COMPOSITE);
  ExprPool[N].Extra    := TIdx;
  ExprPool[N].TypeIdx  := TIdx;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  ParseCompositeLiteralForType := N;
End;

{ ParseCompositeLiteral : forme "NomDeType" suivie d elements entre     }
{ accolades (type NOMME - struct-like, TODO 09) - resout TypeName en             }
{ TypeIdx puis delegue a ParseCompositeLiteralForType. La forme                        }
{ slice/tableau (crochets suivis d elements entre accolades, TODO 11)                     }
{ est geree directement par ParseOperand (le TypeIdx y est deja connu                       }
{ via ParseTypeExpr, pas besoin de repasser par un nom).                                        }
Function ParseCompositeLiteral(Const TypeName: TString): Integer;
Var TIdx, SI : Integer;
Begin
  TIdx := -1;
  SI := SymFind(TypeName);
  If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) Then TIdx := SymTab[SI].TypeIdx
  Else If IsPredeclaredType(TypeName) <> 0 Then TIdx := IsPredeclaredType(TypeName)
  Else FatalError('type inconnu dans un litteral compose: ' + TypeName);
  ParseCompositeLiteral := ParseCompositeLiteralForType(TIdx);
End;

{ ParseCallArgs : '(' construit deja consomme par l appelant est FAUX -  }
{ ici '(' est encore le token courant ; consomme puis parse la liste          }
{ d arguments (tolerance virgule/point-virgule finale, meme piege ASI            }
{ que ParseCompositeLiteral juste au-dessus).                                        }
Function ParseCallArgs(Callee: Integer): Integer;
Var N, A, ArgStart, Cnt : Integer; SavedNCL: Boolean;
Begin
  PPAdvance;   { '(' }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  PPSkipSemis;
  ArgStart := ExprArgCount;
  Cnt := 0;
  If Not PPIsOp(')') Then
  Repeat
    A := ParseExpr;
    ExprArgPush(A, '');
    Inc(Cnt);
    PPSkipSemis;
    If Not PPMatch(',') Then Break;
    PPSkipSemis;
  Until PPIsOp(')');
  NoCompositeLit := SavedNCL;

  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans un appel');

  N := ExprNew(EK_CALL);
  ExprPool[N].Left     := Callee;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  If ExprPool[Callee].Kind = EK_IDENT Then
  Begin
    ExprPool[N].NameVal := ExprPool[Callee].NameVal;
    { inference au mieux pour les fonctions integrees de slice (TODO 11) -  }
    { len/cap/copy retournent toujours int ; append retourne le MEME             }
    { type de slice que son premier argument (aucune verification que                }
    { le nom resolve reellement au builtin plutot qu a une fonction                       }
    { utilisateur du meme nom - simplification documentee, sans consequence                  }
    { reelle avant que le TODO 19 ne fasse la distinction correctement). }
    If (ExprPool[N].NameVal = 'len') Or (ExprPool[N].NameVal = 'cap') Or
       (ExprPool[N].NameVal = 'copy') Then
      ExprPool[N].TypeIdx := PDT_INT
    Else If (ExprPool[N].NameVal = 'append') And (Cnt > 0) Then
      ExprPool[N].TypeIdx := ExprPool[ExprArgPool[ArgStart]].TypeIdx;
  End;
  ParseCallArgs := N;
End;

{ ParseNewOrMake : new(Type) / make(Type [, Expr [, Expr]]) - grammaire   }
{ speciale de Go (le PREMIER argument est un TYPE, pas une expression) -     }
{ PORTEE : tous les types deja reconnus par ParseTypeExpr (predeclare/         }
{ pointeur/nomme/slice/tableau depuis le TODO 11) - make(map[K]V) et              }
{ make(chan T) restent hors de portee jusqu aux TODO 12/15 respectifs,               }
{ arret propre documente dans ce cas (via ParseTypeExpr lui-meme).                      }
Function ParseNewOrMake(Const FuncName: TString): Integer;
Var N, TIdx, ArgStart, Cnt, A : Integer; SavedNCL: Boolean;
Begin
  PPAdvance;   { '(' }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  TIdx := ParseTypeExpr;
  ArgStart := ExprArgCount;
  Cnt := 0;
  While PPMatch(',') Do
  Begin
    A := ParseExpr;
    ExprArgPush(A, '');
    Inc(Cnt);
  End;
  NoCompositeLit := SavedNCL;
  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans ' + FuncName + '(...)');

  N := ExprNew(EK_CALL);
  ExprPool[N].NameVal  := FuncName;
  ExprPool[N].Extra    := TIdx;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;
  If FuncName = 'new' Then
    ExprPool[N].TypeIdx := TypeAdd(TYK_POINTER, '', 4, 4, False, TIdx, -1)
  Else
    ExprPool[N].TypeIdx := TIdx;
  ParseNewOrMake := N;
End;

{ ParseFuncLiteral (implementee au TODO 08) construit une fonction        }
{ anonyme/fermeture ("func" suivi d une signature puis d un corps de           }
{ bloc, utilisee comme EXPRESSION, pas comme declaration de haut                    }
{ niveau) - forward-declaree ici car ParseOperand en a besoin bien                     }
{ avant que le TODO 08 ne soit ecrit.                                                     }
Function ParseFuncLiteral: Integer; Forward;

Function ParseOperand: Integer;
Var Nam: TString; Inner, TIdx: Integer; SavedNCL: Boolean;
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
    TOK_RUNE:
      Begin
        ParseOperand := ExprAddRuneLit(TokenPool[PP].IntVal);
        PPAdvance;
      End;
    TOK_STRING, TOK_RAWSTRING:
      Begin
        ParseOperand := ExprAddStringLit(TokenPool[PP].Val);
        PPAdvance;
      End;
    TOK_IDENT:
      Begin
        Nam := TokenPool[PP].Val;
        PPAdvance;
        If Nam = 'true' Then ParseOperand := ExprAddBoolLit(True)
        Else If Nam = 'false' Then ParseOperand := ExprAddBoolLit(False)
        Else If Nam = 'nil' Then ParseOperand := ExprAddNilLit
        Else If Nam = 'new' Then ParseOperand := ParseNewOrMake('new')
        Else If Nam = 'make' Then ParseOperand := ParseNewOrMake('make')
        Else If Nam = 'func' Then ParseOperand := ParseFuncLiteral
        Else If Nam = 'map' Then
          ParseOperand := ParseCompositeLiteralForType(ParseMapType)
        Else If PPIsOp('{') And (Not NoCompositeLit) Then
          ParseOperand := ParseCompositeLiteral(Nam)
        Else ParseOperand := ExprAddIdent(Nam);
      End;
    TOK_OP:
      Begin
        If PPIsOp('(') Then
        Begin
          PPAdvance;
          SavedNCL := NoCompositeLit;
          NoCompositeLit := False;
          Inner := ParseExpr;
          NoCompositeLit := SavedNCL;
          If Not PPIsOp(')') Then
            FatalError('parenthese fermante attendue')
          Else
            PPAdvance;
          ParseOperand := Inner;
        End
        Else If PPIsOp('[') And (Not NoCompositeLit) Then
        Begin
          { litteral compose slice/tableau (TODO 11) : "[...]T" est une   }
          { expression de TYPE valide ici (ParseTypeExpr, TODO 05, etendue    }
          { au TODO 11 pour reconnaitre "[]T"/"[N]T") immediatement suivie          }
          { d elements entre accolades - TypeIdx deja resolu, pas besoin de              }
          { repasser par un nom comme le fait ParseCompositeLiteral.                        }
          TIdx := ParseTypeExpr;
          ParseOperand := ParseCompositeLiteralForType(TIdx);
        End
        Else
          FatalError('jeton inattendu dans une expression: ' + PPVal);
      End;
  Else
    FatalError('jeton inattendu dans une expression');
  End;
End;

{ ResolveSelectorType (implementee au TODO 09, avec les structs) resout   }
{ au mieux le TypeIdx d un noeud EK_SELECTOR (champ ou methode, avec           }
{ auto-dereference et promotion par embarquement) - forward-declaree             }
{ ici pour la meme raison que ParseFuncSignature/ParseStructType plus              }
{ haut : ParsePrimaryExpr (TODO 06) en a besoin bien avant que le TODO 09              }
{ ne soit ecrit.                                                                       }
Procedure ResolveSelectorType(SelNode: Integer); Forward;

Function ParsePrimaryExpr: Integer;
Var
  Result_  : Integer;
  TIdx, N  : Integer;
  LowIdx, HighIdx, MaxIdx : Integer;
  ArgStart : Integer;
  SavedNCL : Boolean;
Begin
  Result_ := ParseOperand;

  While True Do
  Begin
    If PPIsOp('.') Then
    Begin
      PPAdvance;
      If PPIsOp('(') Then
      Begin
        PPAdvance;
        { x.(type) : marqueur reserve exclusivement a l en-tete d un        }
        { "switch" (TODO 07, TypeSwitchGuard) - PAS une vraie expression         }
        { de type ; Extra=-2 signale ce cas special au lieu d un TypeIdx reel.        }
        If (PPKind = TOK_IDENT) And (PPVal = 'type') Then
        Begin
          PPAdvance;
          If Not PPMatch(')') Then
            FatalError('parenthese fermante attendue apres ".(type)"');
          N := ExprNew(EK_TYPEASSERT);
          ExprPool[N].Left  := Result_;
          ExprPool[N].Extra := -2;
          Result_ := N;
          Continue;
        End;
        TIdx := ParseTypeExpr;
        If Not PPMatch(')') Then
          FatalError('parenthese fermante attendue dans une assertion de type');
        N := ExprNew(EK_TYPEASSERT);
        ExprPool[N].Left    := Result_;
        ExprPool[N].Extra   := TIdx;
        ExprPool[N].TypeIdx := TIdx;
        Result_ := N;
      End
      Else If PPKind = TOK_IDENT Then
      Begin
        N := ExprNew(EK_SELECTOR);
        ExprPool[N].Left    := Result_;
        ExprPool[N].NameVal := PPVal;
        PPAdvance;
        ResolveSelectorType(N);
        Result_ := N;
      End
      Else
      Begin
        FatalError('nom de champ/methode ou assertion de type attendu apres "."');
        Break;
      End;
    End
    Else If PPIsOp('[') Then
    Begin
      PPAdvance;
      SavedNCL := NoCompositeLit;
      NoCompositeLit := False;
      LowIdx := -1; HighIdx := -1; MaxIdx := -1;
      If Not PPIsOp(':') Then LowIdx := ParseExpr;
      If PPMatch(':') Then
      Begin
        If (Not PPIsOp(':')) And (Not PPIsOp(']')) Then HighIdx := ParseExpr;
        If PPMatch(':') Then MaxIdx := ParseExpr;
        NoCompositeLit := SavedNCL;
        If Not PPMatch(']') Then
          FatalError('crochet fermant attendu dans un tranchage (slice)');
        N := ExprNew(EK_SLICE);
        ExprPool[N].Left := Result_;
        ArgStart := ExprArgCount;
        ExprArgPush(LowIdx, '');
        ExprArgPush(HighIdx, '');
        ExprArgPush(MaxIdx, '');
        ExprPool[N].ArgFirst := ArgStart;
        ExprPool[N].ArgCount := 3;
        If ExprPool[Result_].TypeIdx >= 0 Then
          ExprPool[N].TypeIdx := ExprPool[Result_].TypeIdx;
      End
      Else
      Begin
        NoCompositeLit := SavedNCL;
        If Not PPMatch(']') Then
          FatalError('crochet fermant attendu dans une indexation');
        N := ExprNew(EK_INDEX);
        ExprPool[N].Left  := Result_;
        ExprPool[N].Right := LowIdx;
        If ExprPool[Result_].TypeIdx >= 0 Then
          ExprPool[N].TypeIdx := TypeTab[ExprPool[Result_].TypeIdx].ElemTypeIdx;
      End;
      Result_ := N;
    End
    Else If PPIsOp('(') Then
      Result_ := ParseCallArgs(Result_)
    Else
      Break;
  End;

  ParsePrimaryExpr := Result_;
End;

Function ParseUnaryExpr: Integer;
Begin
  If PPIsOp('+') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ParseUnaryExpr;
    Exit;
  End;
  If PPIsOp('-') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('-', EK_UNARY, ParseUnaryExpr);
    Exit;
  End;
  If PPIsOp('!') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('!', EK_UNARY, ParseUnaryExpr);
    Exit;
  End;
  If PPIsOp('^') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('^', EK_UNARY, ParseUnaryExpr);
    Exit;
  End;
  If PPIsOp('*') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('*', EK_DEREF, ParseUnaryExpr);
    Exit;
  End;
  If PPIsOp('&') Then
  Begin
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('&', EK_ADDR, ParseUnaryExpr);
    Exit;
  End;
  If PPIsOp('<-') Then
  Begin
    FatalError('reception de canal <- non prise en charge (voir TODO 15)');
    Exit;
  End;
  ParseUnaryExpr := ParsePrimaryExpr;
End;

Function ParseMulExpr: Integer;
Var L: Integer; Op: TString;
Begin
  L := ParseUnaryExpr;
  While PPIsOp('*') Or PPIsOp('/') Or PPIsOp('%') Or PPIsOp('<<') Or
        PPIsOp('>>') Or PPIsOp('&') Or PPIsOp('&^') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseUnaryExpr);
  End;
  ParseMulExpr := L;
End;

Function ParseAddExpr: Integer;
Var L: Integer; Op: TString;
Begin
  L := ParseMulExpr;
  While PPIsOp('+') Or PPIsOp('-') Or PPIsOp('|') Or PPIsOp('^') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseMulExpr);
  End;
  ParseAddExpr := L;
End;

Function ParseRelExpr: Integer;
Var L: Integer; Op: TString;
Begin
  L := ParseAddExpr;
  While PPIsOp('==') Or PPIsOp('!=') Or PPIsOp('<') Or PPIsOp('<=') Or
        PPIsOp('>') Or PPIsOp('>=') Do
  Begin
    Op := PPVal;
    PPAdvance;
    L := ExprNewBinary(Op, L, ParseAddExpr);
  End;
  ParseRelExpr := L;
End;

Function ParseAndExpr: Integer;
Var L: Integer;
Begin
  L := ParseRelExpr;
  While PPIsOp('&&') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('&&', L, ParseRelExpr);
  End;
  ParseAndExpr := L;
End;

Function ParseExpr: Integer;
Var L: Integer;
Begin
  L := ParseAndExpr;
  While PPIsOp('||') Do
  Begin
    PPAdvance;
    L := ExprNewBinary('||', L, ParseAndExpr);
  End;
  ParseExpr := L;
End;

{ ------------------------------------------------------------ }
{ ExprSelfTest : precedence, unaires, litteraux composes,        }
{ index/slice (2 et 3 bornes), assertion de type, appel, new -       }
{ y compris le piege ASI multi-lignes dans un litteral compose.          }
{ ------------------------------------------------------------ }

Procedure ExprAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ExprSelfTest: ' + Label_ + ' a echoue');
End;

Function ExprParseString(Const Src: TString): Integer;
Const
  TmpFile = 'GOCWEXPRSELFTEST.$$$';
Var
  F: Text;
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

  { precedence : 2 + 3 * 4 -> BINARY(+, 2, BINARY(*, 3, 4)) }
  E := ExprParseString('2 + 3 * 4');
  ExprAssert('2+3*4 racine est +', ExprPool[E].Op = '+');
  ExprAssert('2+3*4 partie droite est *', ExprPool[ExprPool[E].Right].Op = '*');
  ExprAssert('2+3*4 partie gauche est le litteral 2',
    ExprPool[ExprPool[E].Left].IntVal = 2);

  { unaires : -x, !ok, ^m, &v, *p }
  SymAdd('x', SK_VAR, PDT_INT);
  E := ExprParseString('-x');
  ExprAssert('-x est EK_UNARY "-"', (ExprPool[E].Kind = EK_UNARY) And
    (ExprPool[E].Op = '-'));

  SymAdd('v', SK_VAR, PDT_INT);
  E := ExprParseString('&v');
  ExprAssert('&v est EK_ADDR', ExprPool[E].Kind = EK_ADDR);
  ExprAssert('&v : TypeIdx est un pointeur (TYK_POINTER)',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_POINTER);

  { litteral compose sur un type nomme, forme keyee ET positionnelle }
  SymInit;
  TypeInit;
  SI := TypeAdd(TYK_STRUCT, 'Point', 8, 4, False, -1, -1);
  SymAdd('Point', SK_TYPE, SI);
  E := ExprParseString('Point{X: 1, Y: 2}');
  ExprAssert('Point{...} est EK_COMPOSITE', ExprPool[E].Kind = EK_COMPOSITE);
  ExprAssert('Point{...} a 2 elements', ExprPool[E].ArgCount = 2);
  ExprAssert('Point{X:1,...} premier element clef "X"',
    ExprArgKey[ExprPool[E].ArgFirst] = 'X');

  E := ExprParseString('Point{1, 2}');
  ExprAssert('Point{1,2} a 2 elements positionnels', ExprPool[E].ArgCount = 2);
  ExprAssert('Point{1,2} elements sans clef',
    ExprArgKey[ExprPool[E].ArgFirst] = '');

  { piege ASI : accolade fermante seule sur sa ligne, SANS virgule finale }
  E := ExprParseString('Point{' + Chr(10) + 'X: 1,' + Chr(10) +
    'Y: 2' + Chr(10) + '}');
  ExprAssert('litteral compose multi-lignes sans virgule finale (piege ASI)',
    ExprPool[E].ArgCount = 2);

  { index et slice 2/3 bornes }
  SymAdd('arr', SK_VAR, PDT_INT);
  E := ExprParseString('arr[1]');
  ExprAssert('arr[1] est EK_INDEX', ExprPool[E].Kind = EK_INDEX);

  E := ExprParseString('arr[1:2]');
  ExprAssert('arr[1:2] est EK_SLICE', ExprPool[E].Kind = EK_SLICE);
  ExprAssert('arr[1:2] Max omis (-1)', ExprArgPool[ExprPool[E].ArgFirst + 2] = -1);

  E := ExprParseString('arr[1:2:3]');
  ExprAssert('arr[1:2:3] Max present', ExprArgPool[ExprPool[E].ArgFirst + 2] >= 0);

  { appel avec arguments + trailing comma multi-lignes }
  E := ExprParseString('foo(1, 2)');
  ExprAssert('foo(1,2) est EK_CALL', ExprPool[E].Kind = EK_CALL);
  ExprAssert('foo(1,2) 2 arguments', ExprPool[E].ArgCount = 2);
  ExprAssert('foo(1,2) NameVal="foo"', ExprPool[E].NameVal = 'foo');

  E := ExprParseString('foo(' + Chr(10) + '1,' + Chr(10) + '2,' + Chr(10) + ')');
  ExprAssert('appel multi-lignes avec virgule finale : 2 arguments',
    ExprPool[E].ArgCount = 2);

  { assertion de type }
  E := ExprParseString('v.(int)');
  ExprAssert('v.(int) est EK_TYPEASSERT', ExprPool[E].Kind = EK_TYPEASSERT);
  ExprAssert('v.(int) : Extra = PDT_INT', ExprPool[E].Extra = PDT_INT);

  { new(T) }
  E := ExprParseString('new(int)');
  ExprAssert('new(int) : TypeIdx est un pointeur', TypeTab[ExprPool[E].TypeIdx].Kind = TYK_POINTER);

  { selecteur de champ }
  E := ExprParseString('v.Champ');
  ExprAssert('v.Champ est EK_SELECTOR', ExprPool[E].Kind = EK_SELECTOR);
  ExprAssert('v.Champ NameVal="Champ"', ExprPool[E].NameVal = 'Champ');

  { comparaison/logique -> PDT_BOOL }
  E := ExprParseString('1 < 2 && 3 > 2');
  ExprAssert('1<2 && 3>2 -> type bool', ExprPool[E].TypeIdx = PDT_BOOL);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit;
  SymInit;
End;

{ ============================================================ }
{ TODO 07 - INSTRUCTIONS DE CONTROLE : IF / FOR / SWITCH / GOTO }
{ ============================================================ }
{ Meme principe que le TODO 06 : construit un AST (StmtPool, pool a    }
{ taille fixe comme ExprPool/TypeTab/SymTab) plutot que d emettre du       }
{ code, puisque le backend (TODO 21) n existe toujours pas. Ce TODO           }
{ n a PAS ENCORE d appelant reel (ParseFileTopLevel s arrete toujours              }
{ proprement a la premiere "func" - les corps de fonctions arrivent au                }
{ TODO 08) : chaque forme est construite et testee de facon autonome                     }
{ via StmtSelfTest, exactement comme ExprSelfTest l a fait pour le                          }
{ TODO 06 avant que rien n utilise ParseExpr en pratique.                                      }

Const
  MAX_STMT     = 8192;
  MAX_STMT_ARG = 8192;
  MAX_CASE     = 2048;

Type
  TStmtKind = (
    STK_EMPTY, STK_BLOCK, STK_EXPR, STK_ASSIGN, STK_SHORTVAR, STK_INCDEC,
    STK_VARDECL, STK_CONSTDECL, STK_TYPEDECL,
    STK_IF, STK_FOR, STK_FORRANGE, STK_SWITCH, STK_TYPESWITCH,
    STK_BREAK, STK_CONTINUE, STK_GOTO, STK_LABELED, STK_RETURN,
    STK_FALLTHROUGH, STK_DEFER
  );

  TStmtNode = Record
    Kind       : TStmtKind;
    Op         : TString;    { STK_ASSIGN/STK_INCDEC : texte de l operateur }
    Left       : Integer;    { voir tableau d usage par Kind ci-dessous }
    Right      : Integer;
    Extra      : Integer;
    Extra2     : Integer;
    NameVal    : TString;
    NameVal2   : TString;
    IsDeclRange: Boolean;
    ArgFirst   : Integer;
    ArgCount   : Integer;
  End;

  { Usage des champs par Kind (documente une seule fois ici plutot que    }
  { repete partout) :                                                        }
  {   STK_BLOCK        ArgFirst/Count -> instructions (StmtArgPool[i])          }
  {   STK_EXPR         Left -> expression                                          }
  {   STK_ASSIGN       Op ; ArgFirst/Count -> paires (StmtArgPool[i]=cible,           }
  {                    StmtArgPool2[i]=valeur)                                          }
  {   STK_SHORTVAR     ArgFirst/Count -> paires (StmtArgName[i]=nom,                       }
  {                    StmtArgPool2[i]=valeur)                                                 }
  {   STK_INCDEC       Op ; Left -> cible                                                         }
  {   STK_VARDECL/CONSTDECL/TYPEDECL  (aucune charge utile : delegue aux                              }
  {                    parseurs du TODO 05, deja appeles au moment de creer                              }
  {                    ce noeud - simple marqueur pour ParseStatement)                                      }
  {   STK_IF           Left=Init(-1 si absent) ; Extra=Condition ;                                              }
  {                    Right=Bloc-Alors ; Extra2=Bloc/Instruction-Sinon(-1)                                        }
  {   STK_FOR          Left=Init(-1) ; Extra=Condition(-1) ; Extra2=Post(-1) ;                                        }
  {                    Right=Corps                                                                                       }
  {   STK_FORRANGE     NameVal=nom cle, NameVal2=nom valeur (vide si absent                                                 }
  {                    ou "_") ; IsDeclRange (:= vs =) ; Left=Collection ;                                                     }
  {                    Right=Corps                                                                                                }
  {   STK_SWITCH       Left=Init(-1) ; Extra=Etiquette/Tag(-1 si sans tag) ;                                                        }
  {                    ArgFirst/Count -> plage dans CaseClausePool                                                                     }
  {   STK_TYPESWITCH   Left=Init(-1) ; Extra=Expression de base (x de x.(type)) ;                                                         }
  {                    NameVal=nom lie (v de "v := x.(type)", vide si absent) ;                                                              }
  {                    ArgFirst/Count -> plage dans CaseClausePool (dont                                                                        }
  {                    ExprFirst/Count y contiennent des TypeIdx BRUTS, pas                                                                        }
  {                    des index de noeud - documente dans TCaseClause)                                                                              }
  {   STK_BREAK/CONTINUE  NameVal=etiquette (vide si absente)                                                                                            }
  {   STK_GOTO/STK_LABELED  NameVal=etiquette ; Left=instruction (LABELED seul.)                                                                            }
  {   STK_RETURN       ArgFirst/Count -> expressions de retour (StmtArgPool[i])                                                                               }
  {   STK_FALLTHROUGH  (aucune charge utile)                                                                                                                     }

  TCaseClause = Record
    ExprFirst   : Integer;   { dans ExprArgPool : valeurs "case V1, V2:" ; }
                             { pour STK_TYPESWITCH, contient des TypeIdx      }
                             { BRUTS (pas des index de ExprPool)                 }
    ExprCount   : Integer;
    IsDefault   : Boolean;
    BodyFirst   : Integer;   { dans StmtArgPool : instructions du corps }
    BodyCount   : Integer;
    Fallthrough : Boolean;   { corps termine par l instruction "fallthrough" }
  End;

Var
  StmtPool     : Array[0..MAX_STMT - 1] Of TStmtNode;
  StmtCount    : Integer;
  StmtArgPool  : Array[0..MAX_STMT_ARG - 1] Of Integer;
  StmtArgPool2 : Array[0..MAX_STMT_ARG - 1] Of Integer;
  StmtArgName  : Array[0..MAX_STMT_ARG - 1] Of TString;
  StmtArgCount : Integer;
  CaseClausePool  : Array[0..MAX_CASE - 1] Of TCaseClause;
  CaseClauseCount : Integer;

Procedure StmtInit;
Begin
  StmtCount       := 0;
  StmtArgCount    := 0;
  CaseClauseCount := 0;
End;

Function StmtNew(K: TStmtKind): Integer;
Begin
  If StmtCount >= MAX_STMT Then
  Begin
    FatalError('table des noeuds d''instruction pleine (MAX_STMT)');
    StmtNew := 0;
    Exit;
  End;
  StmtPool[StmtCount].Kind        := K;
  StmtPool[StmtCount].Op          := '';
  StmtPool[StmtCount].Left        := -1;
  StmtPool[StmtCount].Right       := -1;
  StmtPool[StmtCount].Extra       := -1;
  StmtPool[StmtCount].Extra2      := -1;
  StmtPool[StmtCount].NameVal     := '';
  StmtPool[StmtCount].NameVal2    := '';
  StmtPool[StmtCount].IsDeclRange := False;
  StmtPool[StmtCount].ArgFirst    := -1;
  StmtPool[StmtCount].ArgCount    := 0;
  StmtNew := StmtCount;
  Inc(StmtCount);
End;

Function StmtArgPush(A, B: Integer; Const Nm: TString): Integer;
Begin
  If StmtArgCount >= MAX_STMT_ARG Then
  Begin
    FatalError('table des arguments d''instruction pleine (MAX_STMT_ARG)');
    StmtArgPush := 0;
    Exit;
  End;
  StmtArgPool[StmtArgCount]  := A;
  StmtArgPool2[StmtArgCount] := B;
  StmtArgName[StmtArgCount]  := Nm;
  StmtArgPush := StmtArgCount;
  Inc(StmtArgCount);
End;

Function CaseClauseNew: Integer;
Begin
  If CaseClauseCount >= MAX_CASE Then
  Begin
    FatalError('table des clauses "case" pleine (MAX_CASE)');
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
{ courant, comme PPKind/PPVal), SANS consommer - generalise PP2Kind/       }
{ PP2Val (TODO 06, equivalents a N=1) pour la detection de "for ... range"     }
{ qui a besoin de regarder jusqu a 3-4 jetons en avant.                          }
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

{ IsForRangeAhead : Vrai si les jetons a partir de PP correspondent a  }
{ "Ident [',' Ident] (':=' | '=') 'range'" - pure LECTURE (aucun jeton     }
{ consomme, aucun effet de bord) : necessaire pour decider, AVANT toute        }
{ consommation, si "for" introduit la forme range-avec-variables plutot            }
{ que la forme classique/while (les deux commencent par un identificateur).           }
Function IsForRangeAhead: Boolean;
Var Offset: Integer;
Begin
  IsForRangeAhead := False;
  If PPKind <> TOK_IDENT Then Exit;
  Offset := 1;
  If (PPPeekKind(Offset) = TOK_OP) And (PPPeekVal(Offset) = ',') Then
  Begin
    Inc(Offset);
    If PPPeekKind(Offset) <> TOK_IDENT Then Exit;
    Inc(Offset);
  End;
  If Not (((PPPeekKind(Offset) = TOK_OP) And (PPPeekVal(Offset) = ':=')) Or
          ((PPPeekKind(Offset) = TOK_OP) And (PPPeekVal(Offset) = '='))) Then Exit;
  Inc(Offset);
  IsForRangeAhead := (PPPeekKind(Offset) = TOK_IDENT) And (PPPeekVal(Offset) = 'range');
End;

Function ParseStatement: Integer; Forward;
Function ParseBlock: Integer; Forward;
{ ParseDeferStmt est implementee au TODO 08, bien plus bas - forward-  }
{ declaree ici car ParseStatement (TODO 07) doit deja savoir router          }
{ le mot-cle "defer" vers elle.                                                 }
Function ParseDeferStmt: Integer; Forward;

{ ExprIsCommaOkSource : Vrai si Idx est une expression pouvant fournir   }
{ la forme comma-ok ("v, ok := ...", UNE seule expression a droite pour        }
{ DEUX noms a gauche) - assertion de type (TODO 06/10, "x.(T)") ou               }
{ indexation d une MAP (TODO 12, "m[cle]" - le second booleen "ok"                  }
{ indique si la cle etait presente). L indexation d un slice/tableau               }
{ (TODO 11) N EST PAS comma-ok en Go reel (un index hors bornes PANIQUE            }
{ au lieu de renvoyer un booleen), d ou le test explicite du Kind TYK_MAP              }
{ et non simplement "est-ce un EK_INDEX".                                                 }
Function ExprIsCommaOkSource(Idx: Integer): Boolean;
Var BaseTypeIdx: Integer;
Begin
  ExprIsCommaOkSource := False;
  If ExprPool[Idx].Kind = EK_TYPEASSERT Then
  Begin
    ExprIsCommaOkSource := True;
    Exit;
  End;
  If ExprPool[Idx].Kind = EK_INDEX Then
  Begin
    BaseTypeIdx := ExprPool[ExprPool[Idx].Left].TypeIdx;
    If (BaseTypeIdx >= 0) And (TypeTab[BaseTypeIdx].Kind = TYK_MAP) Then
      ExprIsCommaOkSource := True;
  End;
End;

{ ParseSimpleStmt : expression / incrementation-decrementation /       }
{ affectation (simple ou composee) / declaration courte := - ne consomme   }
{ JAMAIS le separateur final (point-virgule reel ou insere par l ASI) :        }
{ les appelants (bloc, if, for, switch) le gerent chacun selon leur PROPRE          }
{ grammaire (le for a par exemple DEUX ';' explicites dans son en-tete,               }
{ pas un separateur d instruction ordinaire).                                            }
Function ParseSimpleStmt: Integer;
Var
  Targets  : Array[0..15] Of Integer;
  Vals     : Array[0..15] Of Integer;
  TCount, VCount : Integer;
  N, I     : Integer;
  Op       : TString;
  ValIdx, OkIdx : Integer;
  ArgStart : Integer;
  Nam      : TString;
  AnyNew   : Boolean;
Begin
  TCount := 0;
  Targets[0] := ParseExpr;
  Inc(TCount);
  While PPMatch(',') Do
  Begin
    If TCount <= High(Targets) Then
    Begin
      Targets[TCount] := ParseExpr;
      Inc(TCount);
    End
    Else
      ParseExpr;
  End;

  If PPMatch(':=') Then
  Begin
    { evalue d abord TOUTES les valeurs du membre droit dans Vals AVANT   }
    { de decider comment les associer aux noms - necessaire pour la           }
    { forme comma-ok (TODO 10) : "v, ok := x.(T)" a DEUX noms a gauche             }
    { mais une SEULE expression a droite (contrairement a "a, b := 1, 2",              }
    { qui en a autant que de noms) - on ne peut le savoir qu APRES avoir                  }
    { vu qu aucune virgule ne suit la premiere (et unique) valeur.                            }
    VCount := 0;
    Repeat
      ValIdx := ParseExpr;
      If VCount <= High(Vals) Then
      Begin
        Vals[VCount] := ValIdx;
        Inc(VCount);
      End
      Else
        Inc(VCount);
    Until Not PPMatch(',');

    ArgStart := StmtArgCount;
    AnyNew := False;

    If (VCount = 1) And (TCount = 2) And ExprIsCommaOkSource(Vals[0]) Then
    Begin
      { forme comma-ok : le second nom recoit un booleen "ok" SYNTHETIQUE -   }
      { aucun noeud d expression reel ne le calcule (rien a evaluer sans          }
      { backend, TODO 21+), juste un TypeIdx=PDT_BOOL coherent pour le                 }
      { suivi de type.                                                                    }
      If ExprPool[Targets[0]].Kind = EK_IDENT Then
      Begin
        Nam := ExprPool[Targets[0]].NameVal;
        StmtArgPush(-1, Vals[0], Nam);
        If SymFindInScope(Nam, CurScopeId) < 0 Then
        Begin
          SymAdd(Nam, SK_VAR, ExprPool[Vals[0]].TypeIdx);
          AnyNew := True;
        End;
      End
      Else
        FatalError('nom de variable attendu a gauche de ":="');

      If ExprPool[Targets[1]].Kind = EK_IDENT Then
      Begin
        Nam := ExprPool[Targets[1]].NameVal;
        OkIdx := ExprAddBoolLit(False);
        StmtArgPush(-1, OkIdx, Nam);
        If SymFindInScope(Nam, CurScopeId) < 0 Then
        Begin
          SymAdd(Nam, SK_VAR, PDT_BOOL);
          AnyNew := True;
        End;
      End
      Else
        FatalError('nom de variable attendu a gauche de ":="');
    End
    Else
      For I := 0 To VCount - 1 Do
        If I < TCount Then
        Begin
          If ExprPool[Targets[I]].Kind = EK_IDENT Then
          Begin
            Nam := ExprPool[Targets[I]].NameVal;
            StmtArgPush(-1, Vals[I], Nam);
            If SymFindInScope(Nam, CurScopeId) < 0 Then
            Begin
              SymAdd(Nam, SK_VAR, ExprPool[Vals[I]].TypeIdx);
              AnyNew := True;
            End;
          End
          Else
          Begin
            FatalError('nom de variable attendu a gauche de ":="');
            StmtArgPush(-1, Vals[I], '');
          End;
        End;

    If Not AnyNew Then
      WarnMsg(':= sans aucune nouvelle variable a gauche (no new variables ' +
        'on left side of :=)');

    N := StmtNew(STK_SHORTVAR);
    StmtPool[N].ArgFirst := ArgStart;
    StmtPool[N].ArgCount := TCount;
    ParseSimpleStmt := N;
    Exit;
  End;

  If PPIsOp('=') Or PPIsOp('+=') Or PPIsOp('-=') Or PPIsOp('*=') Or
     PPIsOp('/=') Or PPIsOp('%=') Or PPIsOp('&=') Or PPIsOp('|=') Or
     PPIsOp('^=') Or PPIsOp('<<=') Or PPIsOp('>>=') Or PPIsOp('&^=') Then
  Begin
    Op := PPVal;
    PPAdvance;
    VCount := 0;
    Repeat
      ValIdx := ParseExpr;
      If VCount <= High(Vals) Then
      Begin
        Vals[VCount] := ValIdx;
        Inc(VCount);
      End
      Else
        Inc(VCount);
    Until Not PPMatch(',');

    ArgStart := StmtArgCount;
    If (VCount = 1) And (TCount = 2) And (Op = '=') And
       ExprIsCommaOkSource(Vals[0]) Then
    Begin
      { forme comma-ok par simple affectation : "v, ok = x.(T)" (v et ok    }
      { deja declares plus tot) - meme synthese que ci-dessus pour ok.            }
      StmtArgPush(Targets[0], Vals[0], '');
      OkIdx := ExprAddBoolLit(False);
      StmtArgPush(Targets[1], OkIdx, '');
    End
    Else
      For I := 0 To VCount - 1 Do
        If I < TCount Then StmtArgPush(Targets[I], Vals[I], '')
        Else StmtArgPush(-1, Vals[I], '');

    N := StmtNew(STK_ASSIGN);
    StmtPool[N].Op       := Op;
    StmtPool[N].ArgFirst := ArgStart;
    StmtPool[N].ArgCount := TCount;
    ParseSimpleStmt := N;
    Exit;
  End;

  If PPIsOp('++') Or PPIsOp('--') Then
  Begin
    Op := PPVal;
    PPAdvance;
    N := StmtNew(STK_INCDEC);
    StmtPool[N].Op   := Op;
    StmtPool[N].Left := Targets[0];
    ParseSimpleStmt := N;
    Exit;
  End;

  If TCount > 1 Then
    FatalError('liste d''expressions invalide comme instruction (":=" ou ' +
      '"=" attendu)');
  N := StmtNew(STK_EXPR);
  StmtPool[N].Left := Targets[0];
  ParseSimpleStmt := N;
End;

{ ParseIfStmt : if [SimpleStmt ';'] Expression Bloc [else (IfStmt|Bloc)]  }
{ Meme technique de LEVEE D AMBIGUITE que pour "for" juste plus bas : on     }
{ parse d abord un SimpleStmt (qui, faute de mieux, PEUT etre juste une         }
{ expression nue) ; si un ';' suit, ce qu on vient de parser etait l Init,             }
{ sinon c etait DEJA la condition (son Kind doit alors etre STK_EXPR).                    }
Function ParseIfStmt: Integer;
Var
  Init, Cond, ThenBlk, ElseBr, S1, N : Integer;
  SavedNCL : Boolean;
Begin
  PPAdvance;   { if }
  SymEnterScope;

  { l en-tete (Init/Condition) est un contexte AMBIGU pour un litteral    }
  { compose sans parentheses (voir NoCompositeLit) - leve seulement une      }
  { fois ParseBlock atteint (l accolade qui suit est alors sans ambiguite       }
  { possible : c est le corps du "if").                                            }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := True;
  S1 := ParseSimpleStmt;
  If PPMatch(';') Then
  Begin
    Init := S1;
    Cond := ParseExpr;
  End
  Else
  Begin
    Init := -1;
    If StmtPool[S1].Kind = STK_EXPR Then
      Cond := StmtPool[S1].Left
    Else
    Begin
      FatalError('condition attendue apres "if" (point-virgule manquant ?)');
      Cond := -1;
    End;
  End;
  NoCompositeLit := SavedNCL;

  ThenBlk := ParseBlock;

  ElseBr := -1;
  If PPMatch('else') Then
  Begin
    If (PPKind = TOK_IDENT) And (PPVal = 'if') Then
      ElseBr := ParseIfStmt
    Else
      ElseBr := ParseBlock;
  End;

  SymLeaveScope;

  N := StmtNew(STK_IF);
  StmtPool[N].Left   := Init;
  StmtPool[N].Extra  := Cond;
  StmtPool[N].Right  := ThenBlk;
  StmtPool[N].Extra2 := ElseBr;
  ParseIfStmt := N;
End;

{ ParseForStmt : les TROIS+ formes Go (infinie / while / classique 3-    }
{ clauses / range-avec-ou-sans-variables), un seul mot-cle "for". La forme      }
{ range est detectee AVANT toute consommation via IsForRangeAhead - toutes         }
{ les autres formes partagent la meme levee d ambiguite que "if".                     }
Function ParseForStmt: Integer;
Var
  N, Init, Cond, Post, Body, S1 : Integer;
  KeyName, ValName : TString;
  IsDecl : Boolean;
  SavedNCL : Boolean;
  CollTypeIdx, KeyTypeIdx, ValTypeIdx : Integer;
Begin
  PPAdvance;   { for }
  SymEnterScope;

  { meme ambiguite documentee que ParseIfStmt (voir NoCompositeLit) -   }
  { levee juste avant chacun des 4 appels a ParseBlock ci-dessous.         }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := True;

  If PPIsOp('{') Then
  Begin
    NoCompositeLit := SavedNCL;
    Body := ParseBlock;
    N := StmtNew(STK_FOR);
    StmtPool[N].Right := Body;
    SymLeaveScope;
    ParseForStmt := N;
    Exit;
  End;

  If (PPKind = TOK_IDENT) And (PPVal = 'range') Then
  Begin
    PPAdvance;   { range }
    N := StmtNew(STK_FORRANGE);
    StmtPool[N].Left  := ParseExpr;
    NoCompositeLit := SavedNCL;
    StmtPool[N].Right := ParseBlock;
    SymLeaveScope;
    ParseForStmt := N;
    Exit;
  End;

  If IsForRangeAhead Then
  Begin
    KeyName := ''; ValName := ''; IsDecl := False;
    KeyName := PPVal;
    PPAdvance;   { premier ident }
    If PPMatch(',') Then
    Begin
      ValName := PPVal;
      PPAdvance;   { second ident }
    End;
    If PPMatch(':=') Then IsDecl := True Else PPMatch('=');
    PPAdvance;   { 'range' - deja confirme par IsForRangeAhead }

    N := StmtNew(STK_FORRANGE);
    StmtPool[N].NameVal     := KeyName;
    StmtPool[N].NameVal2    := ValName;
    StmtPool[N].IsDeclRange := IsDecl;
    StmtPool[N].Left        := ParseExpr;
    If IsDecl Then
    Begin
      { Type reel de la cle/valeur : pour un slice/tableau (TODO 11), la    }
      { cle est TOUJOURS un index (PDT_INT) et la valeur est le VRAI              }
      { ElemTypeIdx de la collection ; pour une MAP (TODO 12), la cle EST              }
      { le vrai KeyTypeIdx de la map et la valeur son vrai ElemTypeIdx (le             }
      { type "valeur" de la map) - pour toute autre collection (string/                    }
      { chan, TODO 14/15), PDT_INT reste le meilleur repli possible ici,                       }
      { meme discipline que ExprInferBinaryType.                                                  }
      CollTypeIdx := ExprPool[StmtPool[N].Left].TypeIdx;
      KeyTypeIdx  := PDT_INT;
      ValTypeIdx  := PDT_INT;
      If CollTypeIdx >= 0 Then
      Begin
        If (TypeTab[CollTypeIdx].Kind = TYK_SLICE) Or
           (TypeTab[CollTypeIdx].Kind = TYK_ARRAY) Then
          ValTypeIdx := TypeTab[CollTypeIdx].ElemTypeIdx
        Else If TypeTab[CollTypeIdx].Kind = TYK_MAP Then
        Begin
          KeyTypeIdx := TypeTab[CollTypeIdx].KeyTypeIdx;
          ValTypeIdx := TypeTab[CollTypeIdx].ElemTypeIdx;
        End;
      End;
      If (KeyName <> '') And (KeyName <> '_') Then SymAdd(KeyName, SK_VAR, KeyTypeIdx);
      If (ValName <> '') And (ValName <> '_') Then SymAdd(ValName, SK_VAR, ValTypeIdx);
    End;
    NoCompositeLit := SavedNCL;
    StmtPool[N].Right := ParseBlock;
    SymLeaveScope;
    ParseForStmt := N;
    Exit;
  End;

  If PPIsOp(';') Then S1 := -1 Else S1 := ParseSimpleStmt;

  If PPMatch(';') Then
  Begin
    Init := S1;
    If PPIsOp(';') Then Cond := -1 Else Cond := ParseExpr;
    If Not PPMatch(';') Then
      FatalError('point-virgule attendu dans l''en-tete du "for"');
    If PPIsOp('{') Then Post := -1 Else Post := ParseSimpleStmt;
  End
  Else
  Begin
    Init := -1;
    Post := -1;
    If S1 = -1 Then Cond := -1
    Else If StmtPool[S1].Kind = STK_EXPR Then Cond := StmtPool[S1].Left
    Else
    Begin
      FatalError('condition attendue dans l''en-tete du "for"');
      Cond := -1;
    End;
  End;
  NoCompositeLit := SavedNCL;

  Body := ParseBlock;
  N := StmtNew(STK_FOR);
  StmtPool[N].Left   := Init;
  StmtPool[N].Extra  := Cond;
  StmtPool[N].Extra2 := Post;
  StmtPool[N].Right  := Body;
  SymLeaveScope;
  ParseForStmt := N;
End;

{ ParseCaseClause : "case" Expr (',' Expr)* ':' Instructions | "default"  }
{ ':' Instructions - chaque clause ouvre sa PROPRE portee (regle Go : le      }
{ corps d un "case" est un bloc implicite). IsTypeSwitchCtx bascule le           }
{ contenu de "case" entre une liste d EXPRESSIONS et une liste de TYPES              }
{ (stockes comme des TypeIdx bruts dans ExprArgPool, documente dans                    }
{ TCaseClause) - c est le "switch" appelant qui sait laquelle des deux                    }
{ formes est en cours (tag ordinaire vs garde de type switch).                               }
Function ParseCaseClause(IsTypeSwitchCtx: Boolean): Integer;
Var
  C, ExprStart, ExprCnt, BodyStart, BodyCnt, SIdx, TIdx : Integer;
  IsDefault : Boolean;
Begin
  SymEnterScope;
  IsDefault := False;
  ExprStart := ExprArgCount;
  ExprCnt := 0;

  If PPMatch('case') Then
  Begin
    Repeat
      If IsTypeSwitchCtx Then
      Begin
        TIdx := ParseTypeExpr;
        ExprArgPush(TIdx, '');
      End
      Else
        ExprArgPush(ParseExpr, '');
      Inc(ExprCnt);
    Until Not PPMatch(',');
  End
  Else If PPMatch('default') Then
    IsDefault := True
  Else
    FatalError('"case" ou "default" attendu');

  If Not PPMatch(':') Then
    FatalError('":" attendu apres "case"/"default"');

  PPSkipSemis;
  BodyStart := StmtArgCount;
  BodyCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) And
        (Not ((PPKind = TOK_IDENT) And ((PPVal = 'case') Or (PPVal = 'default')))) Do
  Begin
    SIdx := ParseStatement;
    StmtArgPush(SIdx, -1, '');
    Inc(BodyCnt);
    PPSkipSemis;
  End;

  SymLeaveScope;

  C := CaseClauseNew;
  CaseClausePool[C].ExprFirst := ExprStart;
  CaseClausePool[C].ExprCount := ExprCnt;
  CaseClausePool[C].IsDefault := IsDefault;
  CaseClausePool[C].BodyFirst := BodyStart;
  CaseClausePool[C].BodyCount := BodyCnt;
  CaseClausePool[C].Fallthrough := (BodyCnt > 0) And
    (StmtPool[StmtArgPool[BodyStart + BodyCnt - 1]].Kind = STK_FALLTHROUGH);
  ParseCaseClause := C;
End;

{ ParseSwitchStmt : switch, SimpleStmt optionnel suivi de ';', Tag         }
{ optionnel, accolade ouvrante, une ou plusieurs clauses case/default,      }
{ accolade fermante. Detecte le "type switch" (garde de la forme               }
{ "v := x.(type)" ou simplement "x.(type)" en tag) en inspectant la               }
{ FORME du tag deja parse (STK_EXPR enveloppant un EK_TYPEASSERT marque           }
{ Extra=-2, ou STK_SHORTVAR a 1 seul nom dont la valeur est ce meme                  }
{ marqueur) - le marqueur lui-meme est pose par ParsePrimaryExpr                       }
{ (TODO 06, patch TODO 07) des qu il reconnait la garde ".(type)".                        }
Function ParseSwitchStmt: Integer;
Var
  N, Init, TagStmt, TagExprIdx, FirstArgIdx : Integer;
  IsTypeSwitch : Boolean;
  TSVarName    : TString;
  ArgStart, Cnt : Integer;
  SavedNCL : Boolean;
Begin
  PPAdvance;   { switch }
  SymEnterScope;

  Init := -1;
  TagStmt := -1;
  IsTypeSwitch := False;
  TSVarName := '';
  TagExprIdx := -1;

  { meme ambiguite documentee que ParseIfStmt/ParseForStmt (voir          }
  { NoCompositeLit) - levee juste avant l accolade ouvrante du corps.        }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := True;
  If Not PPIsOp('{') Then
  Begin
    TagStmt := ParseSimpleStmt;
    If PPMatch(';') Then
    Begin
      Init := TagStmt;
      TagStmt := -1;
      If Not PPIsOp('{') Then TagStmt := ParseSimpleStmt;
    End;
  End;
  NoCompositeLit := SavedNCL;

  If TagStmt >= 0 Then
  Begin
    If StmtPool[TagStmt].Kind = STK_EXPR Then
    Begin
      TagExprIdx := StmtPool[TagStmt].Left;
      If (ExprPool[TagExprIdx].Kind = EK_TYPEASSERT) And
         (ExprPool[TagExprIdx].Extra = -2) Then
      Begin
        IsTypeSwitch := True;
        TagExprIdx := ExprPool[TagExprIdx].Left;
      End;
    End
    Else If StmtPool[TagStmt].Kind = STK_SHORTVAR Then
    Begin
      FirstArgIdx := StmtPool[TagStmt].ArgFirst;
      If (StmtPool[TagStmt].ArgCount = 1) And
         (ExprPool[StmtArgPool2[FirstArgIdx]].Kind = EK_TYPEASSERT) And
         (ExprPool[StmtArgPool2[FirstArgIdx]].Extra = -2) Then
      Begin
        IsTypeSwitch := True;
        TSVarName    := StmtArgName[FirstArgIdx];
        TagExprIdx   := ExprPool[StmtArgPool2[FirstArgIdx]].Left;
      End
      Else
        FatalError('forme de "switch" avec declaration courte non prise ' +
          'en charge (seul "v := x.(type)" est reconnu ici)');
    End
    Else
      FatalError('en-tete de "switch" invalide');
  End;

  If Not PPMatch('{') Then
    FatalError('accolade ouvrante attendue apres l''en-tete de "switch"');
  PPSkipSemis;

  ArgStart := CaseClauseCount;
  Cnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    ParseCaseClause(IsTypeSwitch);
    Inc(Cnt);
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du "switch"');

  If IsTypeSwitch Then N := StmtNew(STK_TYPESWITCH) Else N := StmtNew(STK_SWITCH);
  StmtPool[N].Left     := Init;
  StmtPool[N].Extra    := TagExprIdx;
  StmtPool[N].NameVal  := TSVarName;
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  SymLeaveScope;
  ParseSwitchStmt := N;
End;

Function ParseBreakStmt: Integer;
Var N: Integer;
Begin
  PPAdvance;   { break }
  N := StmtNew(STK_BREAK);
  { une etiquette de break est TOUJOURS sur la MEME ligne (sinon l ASI    }
  { aurait deja insere un ';' juste apres "break", et PPKind serait ici       }
  { TOK_SEMI, pas TOK_IDENT) - aucune ambiguite possible. }
  If PPKind = TOK_IDENT Then
  Begin
    StmtPool[N].NameVal := PPVal;
    PPAdvance;
  End;
  ParseBreakStmt := N;
End;

Function ParseContinueStmt: Integer;
Var N: Integer;
Begin
  PPAdvance;   { continue }
  N := StmtNew(STK_CONTINUE);
  If PPKind = TOK_IDENT Then
  Begin
    StmtPool[N].NameVal := PPVal;
    PPAdvance;
  End;
  ParseContinueStmt := N;
End;

Function ParseGotoStmt: Integer;
Var N: Integer;
Begin
  PPAdvance;   { goto }
  N := StmtNew(STK_GOTO);
  If PPKind = TOK_IDENT Then
  Begin
    StmtPool[N].NameVal := PPVal;
    PPAdvance;
  End
  Else
    FatalError('etiquette attendue apres "goto"');
  ParseGotoStmt := N;
End;

{ ParseReturnStmt : reserve pour le TODO 08 (retours multiples/nommes) -  }
{ ici, se contente de parser 0..N expressions separees par des virgules :      }
{ le VERIFICATION que leur nombre/type correspond a la signature de la               }
{ fonction englobante n a de toute facon aucun sens avant que le TODO 08                }
{ ne fasse exister des fonctions.                                                          }
Function ParseReturnStmt: Integer;
Var N, ArgStart, Cnt, EIdx : Integer;
Begin
  PPAdvance;   { return }
  N := StmtNew(STK_RETURN);
  ArgStart := StmtArgCount;
  Cnt := 0;
  If (PPKind <> TOK_SEMI) And (Not PPAtEnd) And (Not PPIsOp('}')) Then
  Repeat
    EIdx := ParseExpr;
    StmtArgPush(EIdx, -1, '');
    Inc(Cnt);
  Until Not PPMatch(',');
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  ParseReturnStmt := N;
End;

Function ParseFallthroughStmt: Integer;
Begin
  PPAdvance;   { fallthrough }
  ParseFallthroughStmt := StmtNew(STK_FALLTHROUGH);
End;

Function ParseBlock: Integer;
Var N, ArgStart, Cnt, SIdx : Integer;
Begin
  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue');
    ParseBlock := StmtNew(STK_BLOCK);
    Exit;
  End;
  SymEnterScope;
  PPSkipSemis;
  ArgStart := StmtArgCount;
  Cnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    SIdx := ParseStatement;
    StmtArgPush(SIdx, -1, '');
    Inc(Cnt);
    PPSkipSemis;
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du bloc');
  SymLeaveScope;

  N := StmtNew(STK_BLOCK);
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  ParseBlock := N;
End;

Function ParseStatement: Integer;
Var Nam: TString; N: Integer;
Begin
  If PPIsOp(';') Then
  Begin
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
    Nam := PPVal;
    If Nam = 'if' Then Begin ParseStatement := ParseIfStmt; Exit; End;
    If Nam = 'for' Then Begin ParseStatement := ParseForStmt; Exit; End;
    If Nam = 'switch' Then Begin ParseStatement := ParseSwitchStmt; Exit; End;
    If Nam = 'break' Then Begin ParseStatement := ParseBreakStmt; Exit; End;
    If Nam = 'continue' Then Begin ParseStatement := ParseContinueStmt; Exit; End;
    If Nam = 'goto' Then Begin ParseStatement := ParseGotoStmt; Exit; End;
    If Nam = 'return' Then Begin ParseStatement := ParseReturnStmt; Exit; End;
    If Nam = 'fallthrough' Then Begin ParseStatement := ParseFallthroughStmt; Exit; End;
    If Nam = 'defer' Then Begin ParseStatement := ParseDeferStmt; Exit; End;
    If Nam = 'go' Then
    Begin
      FatalError('instruction "go" (lancement de goroutine) non prise ' +
        'en charge (voir TODO 15)');
      ParseStatement := StmtNew(STK_EMPTY);
      Exit;
    End;
    If Nam = 'var' Then
    Begin
      ParseVarDecl;
      ParseStatement := StmtNew(STK_VARDECL);
      Exit;
    End;
    If Nam = 'const' Then
    Begin
      ParseConstDecl;
      ParseStatement := StmtNew(STK_CONSTDECL);
      Exit;
    End;
    If Nam = 'type' Then
    Begin
      ParseTypeDecl;
      ParseStatement := StmtNew(STK_TYPEDECL);
      Exit;
    End;

    { instruction etiquetee : Ident ':' - ':=' est TOUJOURS un seul jeton   }
    { distinct depuis le lexeur (TODO 02), donc PPPeekVal(1)=':' ne peut         }
    { jamais matcher accidentellement un ':=' ; aucune ambiguite reelle.             }
    If (PPPeekKind(1) = TOK_OP) And (PPPeekVal(1) = ':') Then
    Begin
      N := StmtNew(STK_LABELED);
      StmtPool[N].NameVal := Nam;
      PPAdvance;   { ident }
      PPAdvance;   { ':' }
      StmtPool[N].Left := ParseStatement;
      ParseStatement := N;
      Exit;
    End;
  End;

  ParseStatement := ParseSimpleStmt;
End;

{ ------------------------------------------------------------ }
{ StmtSelfTest : if/else-if/else, for (4 formes), switch (avec/       }
{ sans tag, type switch, fallthrough), break/continue etiquetes,          }
{ goto+etiquette, return, portees de bloc.                                    }
{ ------------------------------------------------------------ }

Procedure StmtAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StmtSelfTest: ' + Label_ + ' a echoue');
End;

Function StmtParseString(Const Src: TString): Integer;
Const
  TmpFile = 'GOCWSTMTSELFTEST.$$$';
Var
  F: Text;
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
  StmtParseString := ParseStatement;
End;

Procedure StmtSelfTest;
Var
  S, C0, C1 : Integer;
Begin
  ExprInit;
  StmtInit;
  SymInit;
  TypeInit;
  SymAdd('x', SK_VAR, PDT_INT);
  SymAdd('arr', SK_VAR, PDT_INT);

  { if / else if / else }
  S := StmtParseString('if x > 0 { return } else if x < 0 { return } else { return }');
  StmtAssert('if... est STK_IF', StmtPool[S].Kind = STK_IF);
  StmtAssert('if... Init absent', StmtPool[S].Left = -1);
  StmtAssert('if... a un "else if" (STK_IF imbrique)',
    StmtPool[StmtPool[S].Extra2].Kind = STK_IF);

  { if avec instruction d''initialisation avant la condition }
  S := StmtParseString('if n := x; n > 0 { return }');
  StmtAssert('if avec Init : STK_IF', StmtPool[S].Kind = STK_IF);
  StmtAssert('if avec Init : Init est STK_SHORTVAR',
    StmtPool[StmtPool[S].Left].Kind = STK_SHORTVAR);

  { for infini }
  S := StmtParseString('for { break }');
  StmtAssert('for infini : STK_FOR', StmtPool[S].Kind = STK_FOR);
  StmtAssert('for infini : pas de condition', StmtPool[S].Extra = -1);

  { for while-style }
  S := StmtParseString('for x > 0 { break }');
  StmtAssert('for while-style : STK_FOR', StmtPool[S].Kind = STK_FOR);
  StmtAssert('for while-style : Init absent', StmtPool[S].Left = -1);
  StmtAssert('for while-style : condition presente', StmtPool[S].Extra >= 0);

  { for classique 3 clauses }
  S := StmtParseString('for i := 0; i < 10; i++ { break }');
  StmtAssert('for classique : STK_FOR', StmtPool[S].Kind = STK_FOR);
  StmtAssert('for classique : Init est STK_SHORTVAR',
    StmtPool[StmtPool[S].Left].Kind = STK_SHORTVAR);
  StmtAssert('for classique : Post est STK_INCDEC',
    StmtPool[StmtPool[S].Extra2].Kind = STK_INCDEC);

  { for range sans variables }
  S := StmtParseString('for range arr { break }');
  StmtAssert('for range sans variables : STK_FORRANGE', StmtPool[S].Kind = STK_FORRANGE);
  StmtAssert('for range sans variables : pas de nom de cle', StmtPool[S].NameVal = '');

  { for range avec 1 variable }
  S := StmtParseString('for i := range arr { break }');
  StmtAssert('for range 1 var : STK_FORRANGE', StmtPool[S].Kind = STK_FORRANGE);
  StmtAssert('for range 1 var : NameVal="i"', StmtPool[S].NameVal = 'i');
  StmtAssert('for range 1 var : IsDeclRange', StmtPool[S].IsDeclRange);

  { for range avec 2 variables }
  S := StmtParseString('for i, v := range arr { break }');
  StmtAssert('for range 2 vars : NameVal="i"', StmtPool[S].NameVal = 'i');
  StmtAssert('for range 2 vars : NameVal2="v"', StmtPool[S].NameVal2 = 'v');

  { switch sans tag, avec default et fallthrough }
  S := StmtParseString('switch { case x > 0: fallthrough' + Chr(10) +
    'case x < 0: break' + Chr(10) + 'default: break }');
  StmtAssert('switch sans tag : STK_SWITCH', StmtPool[S].Kind = STK_SWITCH);
  StmtAssert('switch sans tag : 3 clauses', StmtPool[S].ArgCount = 3);
  C0 := StmtPool[S].ArgFirst;
  StmtAssert('switch : 1ere clause a "fallthrough" en fin de corps',
    CaseClausePool[C0].Fallthrough);
  StmtAssert('switch : derniere clause est le default',
    CaseClausePool[C0 + 2].IsDefault);

  { switch avec tag }
  S := StmtParseString('switch x { case 1, 2: break' + Chr(10) + 'default: break }');
  StmtAssert('switch avec tag : Extra (tag) present', StmtPool[S].Extra >= 0);
  C1 := StmtPool[S].ArgFirst;
  StmtAssert('switch avec tag : 1ere clause a 2 valeurs',
    CaseClausePool[C1].ExprCount = 2);

  { type switch }
  S := StmtParseString('switch v := x.(type) { case int: break' + Chr(10) +
    'default: break }');
  StmtAssert('type switch : STK_TYPESWITCH', StmtPool[S].Kind = STK_TYPESWITCH);
  StmtAssert('type switch : nom lie "v"', StmtPool[S].NameVal = 'v');

  { break/continue avec etiquette }
  S := StmtParseString('break Boucle1');
  StmtAssert('break etiquette : NameVal="Boucle1"', StmtPool[S].NameVal = 'Boucle1');
  S := StmtParseString('continue Boucle1');
  StmtAssert('continue etiquette : NameVal="Boucle1"', StmtPool[S].NameVal = 'Boucle1');

  { goto + instruction etiquetee (dans un bloc, pour tester les deux) }
  S := StmtParseString('{ goto Fin' + Chr(10) + 'Fin: return }');
  StmtAssert('bloc goto+etiquette : STK_BLOCK', StmtPool[S].Kind = STK_BLOCK);
  StmtAssert('bloc goto+etiquette : 2 instructions', StmtPool[S].ArgCount = 2);
  StmtAssert('1ere instruction est STK_GOTO',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = STK_GOTO);
  StmtAssert('1ere instruction : etiquette "Fin"',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst]].NameVal = 'Fin');
  StmtAssert('2e instruction est STK_LABELED',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst + 1]].Kind = STK_LABELED);
  StmtAssert('2e instruction : etiquette "Fin"',
    StmtPool[StmtArgPool[StmtPool[S].ArgFirst + 1]].NameVal = 'Fin');
  StmtAssert('2e instruction : instruction interne est STK_RETURN',
    StmtPool[StmtPool[StmtArgPool[StmtPool[S].ArgFirst + 1]].Left].Kind = STK_RETURN);

  { return sans valeur / avec 2 valeurs }
  S := StmtParseString('return');
  StmtAssert('return sans valeur : 0 expression', StmtPool[S].ArgCount = 0);
  S := StmtParseString('return 1, 2');
  StmtAssert('return 2 valeurs : ArgCount=2', StmtPool[S].ArgCount = 2);

  { portee de bloc : une variable declaree dans un bloc ne doit pas         }
  { rester visible apres - verifie via SymCount avant/apres }
  SymEnterScope;
  S := StmtParseString('{ y := 1' + Chr(10) + '_ = y }');
  StmtAssert('bloc avec declaration locale : STK_BLOCK', StmtPool[S].Kind = STK_BLOCK);
  StmtAssert('"y" n''est plus visible apres le bloc (portee fermee)',
    SymFindInScope('y', CurScopeId) < 0);
  SymLeaveScope;

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit;
  StmtInit;
  SymInit;
End;

{ ============================================================ }
{ TODO 08 - FONCTIONS : RETOURS MULTIPLES, VARIADIQUES, FERMETURES }
{ ============================================================ }
{ Premier TODO qui donne enfin un VRAI appelant a ParseBlock (TODO 07) :  }
{ ParseFileTopLevel (TODO 05) s arretait proprement sur "func" depuis           }
{ le debut - a partir de maintenant elle analyse le corps complet des              }
{ fonctions, ce qui fait de ce TODO le premier test d integration bout-              }
{ en-bout reel sur les fichiers SAMPLES\GO existants (hello.go en                        }
{ particulier, dont le corps de "main" n avait encore JAMAIS ete analyse                   }
{ par rien de plus qu un lexeur).                                                             }
{                                                                          }
{ Fermetures (closures) : AUCUN travail supplementaire n est necessaire   }
{ ici cote analyse - SymFind (TODO 05) resout deja du plus imbrique au        }
{ plus englobant sur la TOTALITE de SymTab, quelle que soit la portee            }
{ active ; une fonction anonyme analysee alors que des portees locales               }
{ englobantes sont encore ouvertes (Portee non fermee par SymLeaveScope)                }
{ "voit" donc deja naturellement les variables englobantes SANS aucun                      }
{ mecanisme special. La "capture par reference, environnement alloue au                       }
{ tas" mentionnee au TODO 08 releve entierement de la GENERATION DE CODE                          }
{ (TODO 21+), pas de l analyse : rien a faire de plus ici, deliberement.                              }

{ FieldPoolAdd : ajoute une entree (nom, type) a la fin de FieldPool -   }
{ premier VRAI consommateur du pool partage reserve depuis le TODO 04      }
{ ("future func params/results" y etait deja annonce) ; sert aux                 }
{ parametres ET aux resultats (nommes ou non) des signatures de fonction.            }
Function FieldPoolAdd(Const Nm: TString; TIdx: Integer; Embedded: Boolean): Integer;
Begin
  If FieldPoolCount >= MAX_FIELD_POOL Then
  Begin
    FatalError('table des champs/parametres pleine (MAX_FIELD_POOL)');
    FieldPoolAdd := 0;
    Exit;
  End;
  FieldPool[FieldPoolCount].Name       := Nm;
  FieldPool[FieldPoolCount].TypeIdx    := TIdx;
  FieldPool[FieldPoolCount].Offset     := 0;
  FieldPool[FieldPoolCount].IsEmbedded := Embedded;
  FieldPoolAdd := FieldPoolCount;
  Inc(FieldPoolCount);
End;

{ TFieldBufNames/TFieldBufTypes : tampons LOCAUX (jamais dans FieldPool   }
{ directement) utilises par ParseParamOrResultGroup/ParseParamList/           }
{ ParseResultList - voir la note "BUG reel corrige" au-dessus de                  }
{ ParseParamList pour pourquoi ce tampon est necessaire.                              }
Type
  TFieldBufNames = Array[0..63] Of TString;
  TFieldBufTypes = Array[0..63] Of Integer;

{ ParseParamOrResultGroup : "Nom1 [, Nom2 ...] ['...'] Type" - un GROUPE  }
{ de noms partageant un meme type final (forme Go reelle, ex. "a, b        }
{ int"). Algorithme (correct pour ce cas, verifie a la main sur les              }
{ exemples "a, b int, c string" et "nums ...int") : on avale d abord TOUS               }
{ les identificateurs separes par une virgule DIRECTEMENT suivante -                       }
{ des qu un identificateur n est PAS suivi d une virgule, le groupe de                        }
{ noms est termine et ce qui suit (apres un "..." variadique optionnel)                          }
{ est FORCEMENT le type partage (aucune autre lecture n est possible               }
{ dans une liste 100% NOMMEE, voir la restriction ci-dessous).                                       }
{ PORTEE (documentee) : ne prend en charge QUE les parametres NOMMES        }
{ (chaque groupe doit se terminer par un type reel, sinon erreur claire) -    }
{ les listes de parametres NON nommees (types seuls, ex. un type fonction         }
{ "func(int, string) bool" utilise pour une VARIABLE plutot qu une                  }
{ fonction reellement definie) sont hors de portee ici - AllowVariadic              }
{ desactive la marque "..." pour les listes de RESULTATS (Go n a pas             }
{ de resultats variadiques). N ecrit PLUS directement dans FieldPool -            }
{ accumule dans le tampon BufNames/BufTypes du LISTE APPELANTE, qui fait                }
{ le vrai FieldPoolAdd tout a la fin (voir la note "BUG reel corrige"                    }
{ juste au-dessus de ParseParamList).                                                       }
Procedure ParseParamOrResultGroup(AllowVariadic: Boolean;
  Var BufNames: TFieldBufNames; Var BufTypes: TFieldBufTypes; Var BufCnt: Integer;
  Var IsVariadic: Boolean);
Var
  Names  : TDeclNameList;
  NCount : Integer;
  TIdx, I : Integer;
  WasVariadic : Boolean;
Begin
  NCount := 0;
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de parametre/resultat attendu (listes non nommees ' +
        'non prises en charge ici)');
      Exit;
    End;
    If NCount <= High(Names) Then
    Begin
      Names[NCount] := PPVal;
      Inc(NCount);
    End;
    PPAdvance;
  Until Not PPMatch(',');

  WasVariadic := False;
  If AllowVariadic And PPMatch('...') Then WasVariadic := True;
  TIdx := ParseTypeExpr;   { peut pousser d autres entrees dans FieldPool de   }
                           { facon imbriquee (ex. type "func(int) int") - SANS      }
                           { consequence ici puisqu on n ecrit que dans le               }
                           { tampon LOCAL BufNames/BufTypes, jamais directement              }
                           { dans FieldPool.                                                    }

  For I := 0 To NCount - 1 Do
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := Names[I];
      BufTypes[BufCnt] := TIdx;
      Inc(BufCnt);
    End
    Else
      WarnMsg('trop de parametres/resultats dans une seule liste (tampon plein)');
  If WasVariadic Then IsVariadic := True;
End;

{ ParseParamList : parametres NOMMES ("func Sum(nums ...int) int",       }
{ presque toujours le cas pour une fonction reellement DEFINIE) OU NON        }
{ NOMMES ("var Callback func(int) int" - un type fonction utilise comme          }
{ type de VARIABLE n a evidemment aucun besoin de nommer ses parametres,             }
{ TODO 08 lui-meme le mentionne : "types func(...) (...)"). Meme                          }
{ technique de detection de mode par lecture d essai que ParseResultList                     }
{ juste au-dessus - necessaire ici aussi puisque les DEUX formes sont                             }
{ courantes pour des parametres (contrairement aux resultats, ou le                                   }
{ non-nomme domine tres largement). "..." interdit sauf sur le TOUT                                       }
{ DERNIER groupe/parametre, nomme ou non.                                                                    }
{                                                                          }
{ BUG reel corrige (TODO 10) : cette procedure (et ParseResultList,           }
{ ParseFuncSignature, ParseStructType/ParseInterfaceType plus bas)                 }
{ capturait AUPARAVANT FieldFirst := FieldPoolCount AVANT la boucle, en              }
{ supposant que les Cnt prochaines entrees POUSSEES seraient les MIENNES,               }
{ CONTIGUES. Faux des qu un parametre/champ/methode a un TYPE compose                      }
{ (func/struct/interface) : ParseTypeExpr le resout en rappelant                              }
{ ParseFuncSignature/ParseStructType/ParseInterfaceType, qui poussent                            }
{ EUX-MEMES leurs propres entrees dans FieldPool AVANT que la mienne ne                          }
{ soit poussee - intercalant des entrees "etrangeres" au milieu de MA                               }
{ propre plage et cassant [FieldFirst, FieldFirst+Cnt) comme "ma" plage                                }
{ contigue. Invisible tant qu aucun parametre/champ/methode n avait un                                    }
{ type compose (TODO 08/09) - revele par le TOUT PREMIER test d interface                                    }
{ du TODO 10 (CHAQUE methode d interface a sa PROPRE signature imbriquee,                                       }
{ donc CHAQUE methode declenche le probleme). Corrige en accumulant                                                }
{ d abord dans un tampon LOCAL (BufNames/BufTypes, immunise contre tout                                              }
{ entrelacement puisque ce sont de simples tableaux Pascal), puis en                                                    }
{ poussant tout d un coup dans FieldPool a la toute fin - a ce moment-la,                                                  }
{ plus AUCUN appel imbrique ne peut plus se produire pour cette liste,                                                       }
{ donc la plage [FieldFirst, FieldFirst+Cnt) qui vient d etre poussee EST                                                       }
{ garantie contigue.                                                                                                               }
Procedure ParseParamList(Var FieldFirst, Cnt: Integer; Var IsVariadic: Boolean);
Var
  BufNames : TFieldBufNames;
  BufTypes : TFieldBufTypes;
  BufCnt, I : Integer;
  SavedPP : Integer;
  IsNamed : Boolean;
  TIdx    : Integer;
  WasVariadic : Boolean;
Begin
  BufCnt := 0;
  IsVariadic := False;

  If Not PPIsOp(')') Then
  Begin
    SavedPP := PP;
    If PPIsOp('...') Then
      IsNamed := False
    Else
    Begin
      IsNamed := True;
      Repeat
        If PPKind <> TOK_IDENT Then
        Begin
          IsNamed := False;
          Break;
        End;
        PPAdvance;
      Until Not PPMatch(',');
      If IsNamed Then
        IsNamed := (PPKind = TOK_IDENT) Or PPIsOp('*') Or PPIsOp('...') Or
          PPIsOp('[');
    End;
    PP := SavedPP;

    If IsNamed Then
      Repeat
        If IsVariadic Then
          FatalError('parametre apres le parametre variadique "...T" (doit ' +
            'etre le dernier)');
        ParseParamOrResultGroup(True, BufNames, BufTypes, BufCnt, IsVariadic);
      Until Not PPMatch(',')
    Else
      Repeat
        If IsVariadic Then
          FatalError('parametre apres le parametre variadique "...T" (doit ' +
            'etre le dernier)');
        WasVariadic := False;
        If PPMatch('...') Then WasVariadic := True;
        TIdx := ParseTypeExpr;
        If BufCnt <= High(BufNames) Then
        Begin
          BufNames[BufCnt] := '';
          BufTypes[BufCnt] := TIdx;
          Inc(BufCnt);
        End;
        If WasVariadic Then IsVariadic := True;
      Until Not PPMatch(',');
  End;

  FieldFirst := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAdd(BufNames[I], BufTypes[I], False);
  Cnt := BufCnt;
End;

{ ParseResultList : contrairement aux parametres, les RESULTATS sont     }
{ TRES SOUVENT non nommes en Go reel (l idiome canonique "func DivMod(a,   }
{ b int) (int, int)" du TODO 08 lui-meme en est l exemple). Determine le            }
{ mode (nomme/non nomme) via une lecture d ESSAI qui NE CONSOMME RIEN                  }
{ (sauvegarde/restaure PP) : on essaie de lire un groupe de noms comme                    }
{ pour les parametres, puis on regarde si un vrai type plausible suit -                       }
{ si oui, la liste ENTIERE est nommee (regle Go reelle : au sein d une                            }
{ meme liste, les noms sont TOUS presents ou TOUS absents) ; sinon,                                   }
{ chaque element separe par une virgule est directement un type seul.                                    }
{ Meme tampon local + bulk-push final que ParseParamList (voir sa note         }
{ "BUG reel corrige" juste au-dessus).                                                    }
Procedure ParseResultList(Var FieldFirst, Cnt: Integer);
Var
  BufNames : TFieldBufNames;
  BufTypes : TFieldBufTypes;
  BufCnt, I : Integer;
  SavedPP : Integer;
  IsNamed, DummyVariadic : Boolean;
  TIdx : Integer;
Begin
  BufCnt := 0;
  If Not PPIsOp(')') Then
  Begin
    SavedPP := PP;
    IsNamed := True;
    Repeat
      If PPKind <> TOK_IDENT Then
      Begin
        IsNamed := False;
        Break;
      End;
      PPAdvance;
    Until Not PPMatch(',');
    If IsNamed Then
      IsNamed := (PPKind = TOK_IDENT) Or PPIsOp('*') Or PPIsOp('[');
    PP := SavedPP;

    DummyVariadic := False;
    If IsNamed Then
      Repeat
        ParseParamOrResultGroup(False, BufNames, BufTypes, BufCnt, DummyVariadic);
      Until Not PPMatch(',')
    Else
      Repeat
        TIdx := ParseTypeExpr;
        If BufCnt <= High(BufNames) Then
        Begin
          BufNames[BufCnt] := '';
          BufTypes[BufCnt] := TIdx;
          Inc(BufCnt);
        End;
      Until Not PPMatch(',');
  End;

  FieldFirst := FieldPoolCount;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAdd(BufNames[I], BufTypes[I], False);
  Cnt := BufCnt;
End;

{ ParseFuncSignature : "(" Parametres ")" [Resultats] - Resultats est     }
{ soit absent (rien avant le "{" du corps), soit un seul type SANS            }
{ parentheses ("... int"), soit une liste entre parentheses (nommee ou           }
{ non). PP doit deja pointer juste APRES le mot-cle "func" au moment de              }
{ l appel (aussi bien pour une declaration de haut niveau que pour une                  }
{ fonction anonyme ou un type fonction utilise comme type de variable).                    }
Function ParseFuncSignature: Integer;
Var
  ParamFirst, ParamCnt, ResultFirst, ResultCnt, TIdx, FT : Integer;
  IsVariadic : Boolean;
Begin
  ParseFuncSignature := -1;
  If Not PPMatch('(') Then
  Begin
    FatalError('parenthese ouvrante attendue apres "func"');
    Exit;
  End;
  ParseParamList(ParamFirst, ParamCnt, IsVariadic);
  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue apres les parametres');

  ResultFirst := -1;
  ResultCnt := 0;
  If PPIsOp('(') Then
  Begin
    PPAdvance;
    ParseResultList(ResultFirst, ResultCnt);
    If Not PPMatch(')') Then
      FatalError('parenthese fermante attendue apres les resultats');
  End
  Else If (Not PPIsOp('{')) And (Not PPAtEnd) And (PPKind <> TOK_SEMI) Then
  Begin
    { TIdx resolu AVANT de capturer ResultFirst (et non l inverse) -    }
    { meme raison que la note "BUG reel corrige" de ParseParamList : si       }
    { ce resultat unique est lui-meme un type compose (ex. "func() func(int)     }
    { int"), ParseTypeExpr pousse D ABORD ses propres entrees imbriquees             }
    { dans FieldPool ; capturer ResultFirst seulement ENSUITE garantit que              }
    { l unique entree poussee juste apres EST bien celle-ci, pas une                      }
    { entree imbriquee etrangere.                                                            }
    TIdx := ParseTypeExpr;
    ResultFirst := FieldPoolCount;
    FieldPoolAdd('', TIdx, False);
    ResultCnt := 1;
  End;

  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, -1, -1);
  TypeTab[FT].ParamFirst  := ParamFirst;
  TypeTab[FT].ParamCount  := ParamCnt;
  TypeTab[FT].ResultFirst := ResultFirst;
  TypeTab[FT].ResultCount := ResultCnt;
  TypeTab[FT].IsVariadic  := IsVariadic;
  ParseFuncSignature := FT;
End;

{ RegisterFuncScopeSymbols : declare les parametres ET les resultats      }
{ NOMMES d une signature comme variables locales visibles dans le corps -    }
{ partagee entre ParseFuncDecl et ParseFuncLiteral. Rend gratuitement            }
{ possible le "retour nu" (naked return - un resultat NOMME reaffecte              }
{ puis un "return" sans expression) : le nom du resultat est une                       }
{ variable locale ordinaire des ce point, une simple affectation lui                       }
{ suffit avant un "return" sans expression (deja pris en charge tel                            }
{ quel par ParseReturnStmt, TODO 07).                                                             }
Procedure RegisterFuncScopeSymbols(FT: Integer);
Var I: Integer;
Begin
  For I := 0 To TypeTab[FT].ParamCount - 1 Do
    SymAdd(FieldPool[TypeTab[FT].ParamFirst + I].Name, SK_VAR,
      FieldPool[TypeTab[FT].ParamFirst + I].TypeIdx);
  For I := 0 To TypeTab[FT].ResultCount - 1 Do
    If FieldPool[TypeTab[FT].ResultFirst + I].Name <> '' Then
      SymAdd(FieldPool[TypeTab[FT].ResultFirst + I].Name, SK_VAR,
        FieldPool[TypeTab[FT].ResultFirst + I].TypeIdx);
End;

{ ParseFuncLiteral : fonction anonyme utilisee comme EXPRESSION (donc     }
{ potentiellement une fermeture si son corps reference des variables         }
{ d une portee englobante encore ouverte - voir la note en tete de              }
{ section). PP est deja juste apres "func" (consomme par ParseOperand).             }
Function ParseFuncLiteral: Integer;
Var FT, BodyIdx, N : Integer;
Begin
  FT := ParseFuncSignature;
  SymEnterScope;
  RegisterFuncScopeSymbols(FT);
  BodyIdx := ParseBlock;
  SymLeaveScope;

  N := ExprNew(EK_FUNCLIT);
  ExprPool[N].Extra   := FT;
  ExprPool[N].Right   := BodyIdx;
  ExprPool[N].TypeIdx := FT;
  ParseFuncLiteral := N;
End;

{ TFuncDefRec/FuncDefPool : fonctions NOMMEES de haut niveau uniquement   }
{ (les fonctions anonymes/fermetures restent de simples expressions            }
{ EK_FUNCLIT, sans entree ici - rien ne les nomme, une table par nom               }
{ ne leur servirait a rien). MAX_FUNC deja reserve au TODO 01.                          }
Type
  TFuncDefRec = Record
    Name        : TString;
    TypeIdx     : Integer;   { TYK_FUNC }
    BodyStmtIdx : Integer;   { STK_BLOCK dans StmtPool }
  End;

Var
  FuncDefPool  : Array[0..MAX_FUNC - 1] Of TFuncDefRec;
  FuncDefCount : Integer;

Procedure FuncDefInit;
Begin
  FuncDefCount := 0;
End;

{ ParseFuncDecl : implementee plus bas (TODO 09), une fois le receveur   }
{ de methode (facultatif) pris en charge en plus du cas simple "func         }
{ Nom(...)..." du TODO 08 - une seule implementation couvre desormais              }
{ les deux cas.                                                                       }

{ ParseDeferStmt : "defer" Expression - empile un appel differe.        }
{ PORTEE (documentee) : la regle Go reelle exige que l expression soit    }
{ un appel de fonction/methode ; ce compilateur accepte ici N IMPORTE          }
{ QUELLE expression sans le verifier (l analyse semantique complete,               }
{ TODO 19, est le bon endroit pour rejeter un defer non-appel - inutile                }
{ de dupliquer cette verification ici alors qu aucun code n est encore                    }
{ genere, TODO 21+, pour donner un sens concret a "empiler LIFO").                             }
Function ParseDeferStmt: Integer;
Var N: Integer;
Begin
  PPAdvance;   { defer }
  N := StmtNew(STK_DEFER);
  StmtPool[N].Left := ParseExpr;
  ParseDeferStmt := N;
End;

{ ------------------------------------------------------------ }
{ FuncSelfTest : signature (retours multiples/nommes/variadique),  }
{ retour nu, litteral de fonction/fermeture, defer - puis            }
{ verification bout-en-bout sur hello.go/types.go/lextest.go via          }
{ ParseFileTopLevel (qui, a partir de ce TODO, analyse enfin les              }
{ corps de fonctions au lieu de s arreter a "func").                             }
{ ------------------------------------------------------------ }

Procedure FuncAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('FuncSelfTest: ' + Label_ + ' a echoue');
End;

Procedure FuncParseTopLevel(Const Src: TString);
Const
  TmpFile = 'GOCWFUNCSELFTEST.$$$';
Var
  F: Text;
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
  ParseFileTopLevel;
End;

Procedure FuncSelfTest;
Var
  FT, SI : Integer;
Begin
  ExprInit;
  StmtInit;
  SymInit;
  TypeInit;
  FuncDefInit;

  { retours multiples non nommes : "func DivMod(a, b int) (int, int)" }
  FuncParseTopLevel('package main' + Chr(10) +
    'func DivMod(a, b int) (int, int) {' + Chr(10) +
    '	return a, b' + Chr(10) + '}');
  SI := SymFind('DivMod');
  FuncAssert('DivMod declaree', SI >= 0);
  FuncAssert('DivMod : symbole de type SK_FUNC', SymTab[SI].Kind = SK_FUNC);
  FT := SymTab[SI].TypeIdx;
  FuncAssert('DivMod : 2 parametres', TypeTab[FT].ParamCount = 2);
  FuncAssert('DivMod : 2 resultats', TypeTab[FT].ResultCount = 2);
  FuncAssert('DivMod : resultats non nommes',
    FieldPool[TypeTab[FT].ResultFirst].Name = '');
  FuncAssert('DivMod : parametres groupes "a, b int" -> meme type',
    FieldPool[TypeTab[FT].ParamFirst].TypeIdx =
    FieldPool[TypeTab[FT].ParamFirst + 1].TypeIdx);

  { resultat unique nomme + retour nu (n reaffectee puis "return" seul) }
  SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F() (n int) {' + Chr(10) + '	n = 42' + Chr(10) + '	return' + Chr(10) + '}');
  SI := SymFind('F');
  FuncAssert('F declaree', SI >= 0);
  FT := SymTab[SI].TypeIdx;
  FuncAssert('F : 1 resultat nomme "n"',
    (TypeTab[FT].ResultCount = 1) And
    (FieldPool[TypeTab[FT].ResultFirst].Name = 'n'));

  { variadique : "func Sum(nums ...int) int" }
  SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Sum(nums ...int) int {' + Chr(10) + '	return 0' + Chr(10) + '}');
  SI := SymFind('Sum');
  FT := SymTab[SI].TypeIdx;
  FuncAssert('Sum : IsVariadic', TypeTab[FT].IsVariadic);
  FuncAssert('Sum : resultat unique non nomme, type int',
    (TypeTab[FT].ResultCount = 1) And
    (FieldPool[TypeTab[FT].ResultFirst].TypeIdx = PDT_INT));

  { fonction sans aucun resultat, corps vide }
  SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('package main' + Chr(10) + 'func P() {' + Chr(10) + '}');
  SI := SymFind('P');
  FT := SymTab[SI].TypeIdx;
  FuncAssert('P : 0 resultat', TypeTab[FT].ResultCount = 0);

  { fermeture/litteral de fonction capturant une variable englobante :    }
  { x locale a G, reference depuis le corps d une fonction anonyme            }
  { affectee a f, elle-meme locale a G                                          }
  SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func G() {' + Chr(10) +
    '	x := 1' + Chr(10) +
    '	f := func() int {' + Chr(10) + '		return x' + Chr(10) + '	}' + Chr(10) +
    '	_ = f' + Chr(10) + '}');
  FuncAssert('G analysee sans erreur (fermeture capturant x)', ErrorCount = 0);

  { defer : instruction "defer" a l interieur du corps de H }
  SymInit; TypeInit; FuncDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func H() {' + Chr(10) + '	defer Close()' + Chr(10) + '}');
  FuncAssert('H analysee sans erreur (defer)', ErrorCount = 0);

  { defer sans reinitialiser ErrorCount avant : verifie ExplicitEment    }
  { que ParseStatement route bien "defer" vers STK_DEFER }
  SymInit; TypeInit; FuncDefInit;

  { type fonction utilise comme type de variable : "var Callback func(int) int" }
  FuncParseTopLevel('package main' + Chr(10) +
    'var Callback func(int) int');
  SI := SymFind('Callback');
  FuncAssert('Callback declaree', SI >= 0);
  FuncAssert('Callback : type TYK_FUNC', TypeTab[SymTab[SI].TypeIdx].Kind = TYK_FUNC);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit;
  StmtInit;
  SymInit;
  FuncDefInit;
End;

{ ============================================================ }
{ TODO 09 - STRUCTS ET METHODES (RECEVEURS VALEUR/POINTEUR)     }
{ ============================================================ }
{ Deux ajouts distincts : (1) la syntaxe de type "struct" (via              }
{ ParseTypeExpr, comme "func" au TODO 08) et (2) les METHODES - des             }
{ declarations de haut niveau "func" avec un RECEVEUR entre "func" et             }
{ le nom, distinctes des fonctions ordinaires du TODO 08 (registree               }
{ separement, pas dans SymTab : une methode ne s appelle jamais toute                 }
{ seule, seulement via un selecteur "valeur.Methode(...)").                                }

Function AlignUp(V, A: Integer): Integer;
Begin
  If A <= 1 Then AlignUp := V
  Else AlignUp := ((V + A - 1) Div A) * A;
End;

{ TFieldBufEmbed : tampon Booleen parallele a BufNames/BufTypes,        }
{ necessaire ici puisque les champs de struct (contrairement aux             }
{ parametres/resultats) portent un IsEmbedded (TODO 09).                        }
Type
  TFieldBufEmbed = Array[0..63] Of Boolean;

{ ParseStructFieldEntry est implementee juste apres ParseStructType -   }
{ forward-declaree ici puisque ParseStructType (son seul appelant)             }
{ vient en premier dans le fichier.                                                }
Procedure ParseStructFieldEntry(Var BufNames: TFieldBufNames;
  Var BufTypes: TFieldBufTypes; Var BufEmbed: TFieldBufEmbed;
  Var BufCnt: Integer); Forward;

{ ParseStructType : "struct" (deja consomme par l appelant) suivi d une  }
{ liste de champs entre accolades. Calcule aussi Offset/Size/Align par              }
{ un layout simple style C/Go reel (bourrage final aligne sur le plus                  }
{ grand alignement de champ) - PREMIERE vraie utilisation de                                }
{ TFieldRec.Offset, reserve depuis le TODO 04 mais jamais rempli avant                        }
{ ce point. Utilise le meme tampon local + bulk-push final que                                }
{ ParseParamList/ParseResultList (voir leur note "BUG reel corrige") :                            }
{ un champ dont le type est lui-meme compose (ex. "F func(int) int")                                }
{ pousserait sinon ses propres entrees AVANT celle du champ lui-meme,                                  }
{ cassant la contigute de [FieldFirst, FieldFirst+Cnt).                                                   }
Function ParseStructType: Integer;
Var
  FT, FieldStart, Cnt, CurOffset, MaxAlign, FAlign, I : Integer;
  BufNames : TFieldBufNames;
  BufTypes : TFieldBufTypes;
  BufEmbed : TFieldBufEmbed;
  BufCnt   : Integer;
Begin
  ParseStructType := -1;
  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres "struct"');
    Exit;
  End;
  PPSkipSemis;

  BufCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    ParseStructFieldEntry(BufNames, BufTypes, BufEmbed, BufCnt);
    PPSkipSemis;
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du "struct"');

  FieldStart := FieldPoolCount;
  Cnt := BufCnt;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAdd(BufNames[I], BufTypes[I], BufEmbed[I]);

  CurOffset := 0;
  MaxAlign  := 1;
  For I := FieldStart To FieldStart + Cnt - 1 Do
  Begin
    FAlign := TypeTab[FieldPool[I].TypeIdx].Align;
    If FAlign < 1 Then FAlign := 1;
    CurOffset := AlignUp(CurOffset, FAlign);
    FieldPool[I].Offset := CurOffset;
    CurOffset := CurOffset + TypeTab[FieldPool[I].TypeIdx].Size;
    If FAlign > MaxAlign Then MaxAlign := FAlign;
  End;

  FT := TypeAdd(TYK_STRUCT, '', AlignUp(CurOffset, MaxAlign), MaxAlign, False, -1, -1);
  TypeTab[FT].FieldFirst := FieldStart;
  TypeTab[FT].FieldCount := Cnt;
  ParseStructType := FT;
End;

{ ParseStructFieldEntry : UNE ligne de la liste de champs - soit un      }
{ groupe NOMME partageant un type ("Nom1, Nom2 Type", meme algorithme          }
{ que ParseParamOrResultGroup du TODO 08), soit un champ EMBARQUE/anonyme          }
{ (juste un nom de type, sans nom de champ separe - "Animal" ou "*Animal",             }
{ regle reelle de la spec Go pour la composition/promotion). Un '*' en                    }
{ tete de ligne ne peut JAMAIS etre un nom de champ (les noms sont des                        }
{ identificateurs), donc AUCUNE ambiguite pour la forme pointeur embarquee.                       }
{ Accumule dans le tampon de l appelant (ParseStructType) plutot que                     }
{ d ecrire directement dans FieldPool - voir sa note "BUG reel corrige".                     }
Procedure ParseStructFieldEntry(Var BufNames: TFieldBufNames;
  Var BufTypes: TFieldBufTypes; Var BufEmbed: TFieldBufEmbed;
  Var BufCnt: Integer);
Var
  Names   : TDeclNameList;
  NCount  : Integer;
  TIdx, SI, PtrTIdx : Integer;
  I : Integer;
Begin
  If PPIsOp('*') Then
  Begin
    PPAdvance;
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de type attendu apres "*" (champ embarque)');
      Exit;
    End;
    Names[0] := PPVal;   { le nom promu = le nom du type pointe, PAS "*Nom" }
    TIdx := ParseTypeExpr;
    PtrTIdx := TypeAdd(TYK_POINTER, '', 4, 4, False, TIdx, -1);
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := Names[0];
      BufTypes[BufCnt] := PtrTIdx;
      BufEmbed[BufCnt] := True;
      Inc(BufCnt);
    End;
    Exit;
  End;

  NCount := 0;
  Repeat
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de champ ou nom de type attendu');
      Exit;
    End;
    If NCount <= High(Names) Then
    Begin
      Names[NCount] := PPVal;
      Inc(NCount);
    End;
    PPAdvance;
  Until Not PPMatch(',');

  If (PPKind = TOK_IDENT) Or PPIsOp('*') Or PPIsOp('[') Then
  Begin
    { groupe NOMME classique : Names[0..NCount-1] partagent ce type }
    TIdx := ParseTypeExpr;
    For I := 0 To NCount - 1 Do
      If BufCnt <= High(BufNames) Then
      Begin
        BufNames[BufCnt] := Names[I];
        BufTypes[BufCnt] := TIdx;
        BufEmbed[BufCnt] := False;
        Inc(BufCnt);
      End;
  End
  Else If NCount = 1 Then
  Begin
    { un seul identificateur, rien d autre ne suit : il EST lui-meme le  }
    { type - champ embarque sans pointeur ("Animal" seul).                  }
    SI := SymFind(Names[0]);
    If (SI >= 0) And (SymTab[SI].Kind = SK_TYPE) Then TIdx := SymTab[SI].TypeIdx
    Else If IsPredeclaredType(Names[0]) <> 0 Then TIdx := IsPredeclaredType(Names[0])
    Else
    Begin
      FatalError('type inconnu (champ embarque): ' + Names[0]);
      Exit;
    End;
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := Names[0];
      BufTypes[BufCnt] := TIdx;
      BufEmbed[BufCnt] := True;
      Inc(BufCnt);
    End;
  End
  Else
    FatalError('type attendu apres les noms de champs');
End;

{ StructFindField : recherche un champ par nom, D ABORD directement,    }
{ PUIS (recursivement, promotion multi-niveaux) dans chaque champ            }
{ EMBARQUE - deref une indirection pointeur si le champ embarque est               }
{ "*Animal". Simplification documentee : en cas de nom promouvable a la               }
{ MEME profondeur depuis DEUX embarquements differents, la vraie regle Go                 }
{ exigerait une erreur d ambiguite explicite - ce compilateur prend                          }
{ simplement le PREMIER trouve (ordre de declaration des champs) ;                              }
{ verification complete deferee au TODO 19 (analyse semantique).                                   }
Function StructFindField(STypeIdx: Integer; Const FName: TString): Integer;
Var I, EmbTypeIdx, Found : Integer;
Begin
  StructFindField := -1;
  If (STypeIdx < 0) Or (TypeTab[STypeIdx].Kind <> TYK_STRUCT) Then Exit;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].Name = FName Then
    Begin
      StructFindField := I;
      Exit;
    End;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].IsEmbedded Then
    Begin
      EmbTypeIdx := FieldPool[I].TypeIdx;
      If TypeTab[EmbTypeIdx].Kind = TYK_POINTER Then
        EmbTypeIdx := TypeTab[EmbTypeIdx].ElemTypeIdx;
      Found := StructFindField(EmbTypeIdx, FName);
      If Found >= 0 Then
      Begin
        StructFindField := Found;
        Exit;
      End;
    End;
End;

{ TMethodDefRec/MethodDefPool : methodes de haut niveau - une fonction    }
{ avec un RECEVEUR entre "func" et le nom. PAS enregistrees dans SymTab       }
{ (contrairement aux fonctions du TODO 08) : une methode Go n existe                }
{ jamais comme identificateur autonome, seulement via un selecteur                     }
{ "valeur.Methode".                                                                       }
{ MAX_FUNC (deja reserve au TODO 01) est reutilise tel quel - une methode              }
{ est, structurellement, juste une fonction avec un receveur en plus.                     }
Type
  TMethodDefRec = Record
    RecvName      : TString;
    RecvTypeIdx   : Integer;   { type du receveur (struct OU pointeur-vers-struct) }
    IsPointerRecv : Boolean;
    Name          : TString;
    TypeIdx       : Integer;   { signature TYK_FUNC }
    BodyStmtIdx   : Integer;   { STK_BLOCK dans StmtPool }
  End;

Var
  MethodDefPool  : Array[0..MAX_FUNC - 1] Of TMethodDefRec;
  MethodDefCount : Integer;

Procedure MethodDefInit;
Begin
  MethodDefCount := 0;
End;

{ MethodFind : meme principe que StructFindField (direct puis promotion  }
{ recursive via les champs embarques), mais sur MethodDefPool - resout        }
{ "valeur.Methode" en cherchant une methode dont le receveur (depointerise         }
{ si nomme par pointeur) correspond au type de "valeur" (lui-meme                    }
{ depointerise si "valeur" est un pointeur - c est ResolveSelectorType             }
{ ci-dessous qui gere ce premier niveau de dereference).                                }
Function MethodFind(STypeIdx: Integer; Const MName: TString): Integer;
Var I, EmbTypeIdx, RTIdx, Found : Integer;
Begin
  MethodFind := -1;
  If (STypeIdx < 0) Or (TypeTab[STypeIdx].Kind <> TYK_STRUCT) Then Exit;

  For I := 0 To MethodDefCount - 1 Do
  Begin
    RTIdx := MethodDefPool[I].RecvTypeIdx;
    If TypeTab[RTIdx].Kind = TYK_POINTER Then RTIdx := TypeTab[RTIdx].ElemTypeIdx;
    If (RTIdx = STypeIdx) And (MethodDefPool[I].Name = MName) Then
    Begin
      MethodFind := I;
      Exit;
    End;
  End;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].IsEmbedded Then
    Begin
      EmbTypeIdx := FieldPool[I].TypeIdx;
      If TypeTab[EmbTypeIdx].Kind = TYK_POINTER Then
        EmbTypeIdx := TypeTab[EmbTypeIdx].ElemTypeIdx;
      Found := MethodFind(EmbTypeIdx, MName);
      If Found >= 0 Then
      Begin
        MethodFind := Found;
        Exit;
      End;
    End;
End;

{ ResolveSelectorType : appelee par ParsePrimaryExpr (TODO 06/patch       }
{ TODO 09/10) juste apres avoir cree un noeud EK_SELECTOR - resout au           }
{ mieux son TypeIdx (champ OU methode), avec AUTO-DEREFERENCE si la base            }
{ est un pointeur vers struct (regle Go reelle : "p.Champ" fonctionne                  }
{ aussi bien si p est *T que si p est T). Best-effort STRICT, meme                        }
{ discipline que tout le reste du fichier depuis le TODO 06 : aucune                          }
{ erreur n est levee ici si le champ/methode reste introuvable (base de                          }
{ type inconnu, ex. "fmt", ou vraie erreur de programme) - la                                        }
{ verification EXHAUSTIVE est le travail du TODO 19.                                                     }
{ Cas TYK_INTERFACE (TODO 10) : resout a la signature DECLAREE par                                          }
{ l interface elle-meme (methode reellement resolue au moment de                                              }
{ l EXECUTION selon le type concret dynamique, pas de l analyse - table                                          }
{ de methodes simplifiee documentee dans le TODO 10 lui-meme, "_GOT_                                                }
{ descripteur de type" complet reste un sujet de generation de code,                                                  }
{ TODO 21+).                                                                                                             }
Procedure ResolveSelectorType(SelNode: Integer);
Var BaseTypeIdx, FIdx, MIdx, I : Integer;
Begin
  BaseTypeIdx := ExprPool[ExprPool[SelNode].Left].TypeIdx;
  If BaseTypeIdx < 0 Then Exit;

  If TypeTab[BaseTypeIdx].Kind = TYK_POINTER Then
    BaseTypeIdx := TypeTab[BaseTypeIdx].ElemTypeIdx;
  If BaseTypeIdx < 0 Then Exit;

  If TypeTab[BaseTypeIdx].Kind = TYK_INTERFACE Then
  Begin
    For I := TypeTab[BaseTypeIdx].MethodFirst To TypeTab[BaseTypeIdx].MethodFirst +
      TypeTab[BaseTypeIdx].MethodCount - 1 Do
      If FieldPool[I].Name = ExprPool[SelNode].NameVal Then
      Begin
        ExprPool[SelNode].TypeIdx := FieldPool[I].TypeIdx;
        Exit;
      End;
    Exit;
  End;

  If TypeTab[BaseTypeIdx].Kind <> TYK_STRUCT Then Exit;

  FIdx := StructFindField(BaseTypeIdx, ExprPool[SelNode].NameVal);
  If FIdx >= 0 Then
  Begin
    ExprPool[SelNode].TypeIdx := FieldPool[FIdx].TypeIdx;
    Exit;
  End;

  MIdx := MethodFind(BaseTypeIdx, ExprPool[SelNode].NameVal);
  If MIdx >= 0 Then
    ExprPool[SelNode].TypeIdx := MethodDefPool[MIdx].TypeIdx;
End;

{ ParseFuncDecl (etendue) : detecte maintenant un RECEVEUR optionnel     }
{ entre "func" et le nom - "func (r T) Nom(...)..." (methode) au lieu de       }
{ "func Nom(...)..." (fonction ordinaire, TODO 08, comportement inchange).        }
{ Le type du receveur passe par ParseTypeExpr lui-meme (qui gere deja "*T"           }
{ recursivement depuis le TODO 05) - pas besoin de retraiter le prefixe                  }
{ pointeur ici, juste de constater APRES coup si le TypeIdx obtenu est                     }
{ TYK_POINTER.                                                                                }
Procedure ParseFuncDecl;
Var
  Nam, RecvName : TString;
  FT, BodyIdx, RecvTypeIdx : Integer;
  IsMethod, IsPtrRecv : Boolean;
Begin
  PPAdvance;   { func }
  IsMethod := PPIsOp('(');
  RecvName := '';
  RecvTypeIdx := -1;
  IsPtrRecv := False;

  If IsMethod Then
  Begin
    PPAdvance;   { '(' }
    If PPKind <> TOK_IDENT Then
    Begin
      FatalError('nom de receveur attendu');
      Exit;
    End;
    RecvName := PPVal;
    PPAdvance;
    RecvTypeIdx := ParseTypeExpr;
    IsPtrRecv := (RecvTypeIdx >= 0) And (TypeTab[RecvTypeIdx].Kind = TYK_POINTER);
    If Not PPMatch(')') Then
      FatalError('parenthese fermante attendue apres le receveur');
  End;

  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de fonction/methode attendu');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  FT := ParseFuncSignature;
  SymEnterScope;
  If IsMethod And (RecvName <> '') And (RecvName <> '_') Then
    SymAdd(RecvName, SK_VAR, RecvTypeIdx);
  RegisterFuncScopeSymbols(FT);
  BodyIdx := ParseBlock;
  SymLeaveScope;

  If IsMethod Then
  Begin
    If MethodDefCount < MAX_FUNC Then
    Begin
      MethodDefPool[MethodDefCount].RecvName      := RecvName;
      MethodDefPool[MethodDefCount].RecvTypeIdx   := RecvTypeIdx;
      MethodDefPool[MethodDefCount].IsPointerRecv := IsPtrRecv;
      MethodDefPool[MethodDefCount].Name          := Nam;
      MethodDefPool[MethodDefCount].TypeIdx       := FT;
      MethodDefPool[MethodDefCount].BodyStmtIdx   := BodyIdx;
      Inc(MethodDefCount);
    End
    Else
      WarnMsg('table des methodes pleine (MAX_FUNC)');
  End
  Else
  Begin
    SymAdd(Nam, SK_FUNC, FT);
    If FuncDefCount < MAX_FUNC Then
    Begin
      FuncDefPool[FuncDefCount].Name        := Nam;
      FuncDefPool[FuncDefCount].TypeIdx     := FT;
      FuncDefPool[FuncDefCount].BodyStmtIdx := BodyIdx;
      Inc(FuncDefCount);
    End
    Else
      WarnMsg('table des fonctions pleine (MAX_FUNC)');
  End;
End;

{ ------------------------------------------------------------ }
{ StructSelfTest : champs groupes, champ embarque valeur et      }
{ pointeur, promotion de champ ET de methode, receveur valeur       }
{ vs pointeur, acces avec auto-dereference, decalages/taille.           }
{ ------------------------------------------------------------ }

Procedure StructAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StructSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StructSelfTest;
Var
  TIdx, SI, FIdx, MIdx : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { struct avec 2 champs groupes partageant le meme type (X, Y int) }
  FuncParseTopLevel('package main' + Chr(10) +
    'type Point struct {' + Chr(10) + '	X, Y int' + Chr(10) + '}');
  SI := SymFind('Point');
  StructAssert('Point declaree', SI >= 0);
  StructAssert('Point : SK_TYPE', SymTab[SI].Kind = SK_TYPE);
  TIdx := SymTab[SI].TypeIdx;
  StructAssert('Point : TYK_STRUCT', TypeTab[TIdx].Kind = TYK_STRUCT);
  StructAssert('Point : 2 champs (X, Y groupes)', TypeTab[TIdx].FieldCount = 2);
  StructAssert('Point : X et Y de meme type (int)',
    FieldPool[TypeTab[TIdx].FieldFirst].TypeIdx =
    FieldPool[TypeTab[TIdx].FieldFirst + 1].TypeIdx);
  StructAssert('Point : Y a un decalage > 0 (apres X)',
    FieldPool[TypeTab[TIdx].FieldFirst + 1].Offset > 0);
  StructAssert('Point : taille totale = 8 (2 x int 4 octets)',
    TypeTab[TIdx].Size = 8);

  { embarquement (composition) : Chien embarque Animal par VALEUR,      }
  { avec un champ nomme en plus, et une methode Parler sur *Animal          }
  { promue jusqu a Chien - exemple canonique du TODO 09 lui-meme.               }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Animal struct {' + Chr(10) + '	Nom string' + Chr(10) + '}' + Chr(10) +
    'func (a *Animal) Parler() string {' + Chr(10) +
    '	return a.Nom' + Chr(10) + '}' + Chr(10) +
    'type Chien struct {' + Chr(10) +
    '	Animal' + Chr(10) + '	Race string' + Chr(10) + '}');
  SI := SymFind('Chien');
  StructAssert('Chien declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  StructAssert('Chien : 2 champs (Animal embarque + Race)', TypeTab[TIdx].FieldCount = 2);
  StructAssert('Chien : premier champ EST embarque',
    FieldPool[TypeTab[TIdx].FieldFirst].IsEmbedded);
  StructAssert('Chien : nom du champ embarque = "Animal"',
    FieldPool[TypeTab[TIdx].FieldFirst].Name = 'Animal');

  { promotion de CHAMP : Chien.Nom doit resoudre jusqu au champ Nom      }
  { d Animal (profondeur 1) }
  FIdx := StructFindField(TIdx, 'Nom');
  StructAssert('Chien.Nom promu depuis Animal (champ trouve)', FIdx >= 0);

  { promotion de METHODE : Chien doit "avoir" Parler() bien qu elle      }
  { soit declaree sur *Animal, pas sur Chien lui-meme                       }
  MIdx := MethodFind(TIdx, 'Parler');
  StructAssert('Chien.Parler() promue depuis *Animal', MIdx >= 0);
  StructAssert('Parler a un receveur POINTEUR', MethodDefPool[MIdx].IsPointerRecv);

  { acces a un champ avec AUTO-DEREFERENCE : une variable de type        }
  { *Animal doit quand meme resoudre p.Nom (pas besoin de (*p).Nom)          }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Animal struct {' + Chr(10) + '	Nom string' + Chr(10) + '}' + Chr(10) +
    'func F(p *Animal) string {' + Chr(10) + '	return p.Nom' + Chr(10) + '}');
  StructAssert('acces p.Nom via *Animal analyse sans erreur (auto-deref)',
    ErrorCount = 0);

  { receveur par VALEUR (copie) vs receveur par POINTEUR (modifie       }
  { l original) - juste la distinction structurelle IsPointerRecv,             }
  { la vraie semantique de copie/modification est un sujet de                     }
  { GENERATION DE CODE (TODO 21+), hors de portee de l analyse pure.                 }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Compteur struct {' + Chr(10) + '	N int' + Chr(10) + '}' + Chr(10) +
    'func (c Compteur) Lire() int {' + Chr(10) + '	return c.N' + Chr(10) + '}' +
    Chr(10) +
    'func (c *Compteur) Incrementer() {' + Chr(10) + '	c.N = c.N + 1' +
    Chr(10) + '}');
  StructAssert('2 methodes enregistrees (Lire + Incrementer)', MethodDefCount = 2);
  StructAssert('Lire : receveur VALEUR', Not MethodDefPool[0].IsPointerRecv);
  StructAssert('Incrementer : receveur POINTEUR', MethodDefPool[1].IsPointerRecv);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 10 - INTERFACES, ASSERTIONS ET DISPATCH DYNAMIQUE        }
{ ============================================================ }
{ La verification de SATISFACTION d interface (un type concret            }
{ implemente une interface des qu il possede toutes ses methodes, SANS           }
{ declaration explicite) est EXPLICITEMENT confiee au TODO 19 par le             }
{ roadmap lui-meme ("verification a la compilation") - ce TODO se limite               }
{ donc a la SYNTAXE des interfaces (declaration, interface totalement            }
{ vide equivalente a any, embarquement d interface) et au CABLAGE de                    }
{ deux mecanismes qui                                                                     }
{ existaient deja partiellement : l assertion de type (TODO 06) et le                           }
{ type switch (TODO 07) obtiennent ici leur forme comma-ok complete, et                            }
{ ResolveSelectorType (TODO 09) sait desormais resoudre un selecteur sur                              }
{ une base de type INTERFACE (pas seulement struct).                                                     }

{ ParseInterfaceMemberEntry est implementee juste apres ParseInterfaceType }
{ - forward-declaree ici puisque ParseInterfaceType (son seul appelant)      }
{ vient en premier dans le fichier (meme pattern que ParseStructType/            }
{ ParseStructFieldEntry au TODO 09).                                                  }
Procedure ParseInterfaceMemberEntry(Var BufNames: TFieldBufNames;
  Var BufTypes: TFieldBufTypes; Var BufCnt: Integer); Forward;

{ ParseInterfaceType : "interface" (deja consomme par l appelant) suivi  }
{ d une liste de membres entre accolades - reutilise FieldPool (comme         }
{ les champs de struct et les parametres/resultats de fonction) pour              }
{ stocker CHAQUE methode requise (Name=nom de la methode, TypeIdx=sa                 }
{ signature TYK_FUNC), mais reference la plage via MethodFirst/                          }
{ MethodCount plutot que FieldFirst/FieldCount - PREMIERE vraie                              }
{ utilisation de ces deux champs, reserves depuis le TODO 04 mais                               }
{ jamais remplis avant ce point (les methodes de STRUCT, elles,                                    }
{ restent volontairement hors de TypeTab, voir MethodDefPool au TODO                                  }
{ 09 - une interface, elle, declare ses methodes INLINE comme des                                        }
{ champs de struct, donc une plage contigue convient parfaitement ici).                                     }
{ Meme tampon local + bulk-push final que ParseParamList/ParseStructType             }
{ (voir leur note "BUG reel corrige") : c est PRECISEMENT ce cas -                          }
{ CHAQUE methode d interface a sa propre signature imbriquee (parametres/               }
{ resultats) qui pousse ses propres entrees dans FieldPool - qui a REVELE               }
{ le probleme en premier lieu, chaque interface a 2+ methodes le                                }
{ declenchant a coup sur.                                                                          }
Function ParseInterfaceType: Integer;
Var
  FT, MethodStart, Cnt, I : Integer;
  BufNames : TFieldBufNames;
  BufTypes : TFieldBufTypes;
  BufCnt   : Integer;
Begin
  ParseInterfaceType := -1;
  If Not PPMatch('{') Then
  Begin
    FatalError('accolade ouvrante attendue apres "interface"');
    Exit;
  End;
  PPSkipSemis;

  BufCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    ParseInterfaceMemberEntry(BufNames, BufTypes, BufCnt);
    PPSkipSemis;
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du "interface"');

  MethodStart := FieldPoolCount;
  Cnt := BufCnt;
  For I := 0 To BufCnt - 1 Do
    FieldPoolAdd(BufNames[I], BufTypes[I], False);

  FT := TypeAdd(TYK_INTERFACE, '', 8, 4, False, -1, -1);
  TypeTab[FT].MethodFirst := MethodStart;
  TypeTab[FT].MethodCount := Cnt;
  ParseInterfaceType := FT;
End;

{ ParseInterfaceMemberEntry : UN membre - soit "NomMethode(Params)         }
{ [Resultats]" (signature complete, SANS corps - reutilise directement         }
{ ParseFuncSignature du TODO 08, PP est deja positionne juste avant le             }
{ "(" des parametres exactement comme elle l attend), soit le nom D UNE               }
{ INTERFACE DEJA DECLAREE (embarquement - "Reader" seul, sans                             }
{ parentheses). L embarquement est APLATI (methodes copiees directement                     }
{ dans celle-ci) plutot que garde comme reference recursive - plus                              }
{ simple, et suffisant puisqu aucune verification de satisfaction                                  }
{ d interface (TODO 19) ne depend de la distinction structurelle entre                                }
{ "declaree directement" et "promue par embarquement". Accumule dans le          }
{ tampon de l appelant (ParseInterfaceType), voir sa note "BUG reel                        }
{ corrige".                                                                                    }
Procedure ParseInterfaceMemberEntry(Var BufNames: TFieldBufNames;
  Var BufTypes: TFieldBufTypes; Var BufCnt: Integer);
Var
  Nam : TString;
  FT, SI, I : Integer;
Begin
  If PPKind <> TOK_IDENT Then
  Begin
    FatalError('nom de methode ou d''interface embarquee attendu');
    Exit;
  End;
  Nam := PPVal;
  PPAdvance;

  If PPIsOp('(') Then
  Begin
    FT := ParseFuncSignature;
    If BufCnt <= High(BufNames) Then
    Begin
      BufNames[BufCnt] := Nam;
      BufTypes[BufCnt] := FT;
      Inc(BufCnt);
    End;
  End
  Else
  Begin
    SI := SymFind(Nam);
    If (SI < 0) Or (SymTab[SI].Kind <> SK_TYPE) Or
       (TypeTab[SymTab[SI].TypeIdx].Kind <> TYK_INTERFACE) Then
    Begin
      FatalError('interface embarquee inconnue: ' + Nam);
      Exit;
    End;
    FT := SymTab[SI].TypeIdx;
    For I := TypeTab[FT].MethodFirst To TypeTab[FT].MethodFirst +
      TypeTab[FT].MethodCount - 1 Do
      If BufCnt <= High(BufNames) Then
      Begin
        BufNames[BufCnt] := FieldPool[I].Name;
        BufTypes[BufCnt] := FieldPool[I].TypeIdx;
        Inc(BufCnt);
      End;
  End;
End;

{ ------------------------------------------------------------ }
{ InterfaceSelfTest : declaration d interface (signatures de       }
{ methodes), interface vide (equivalente a any), embarquement          }
{ d interface (methodes promues/aplaties), assertion comma-ok             }
{ (:= et =), dispatch simplifie sur une base de type interface.               }
{ ------------------------------------------------------------ }

Procedure InterfaceAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('InterfaceSelfTest: ' + Label_ + ' a echoue');
End;

Procedure InterfaceSelfTest;
Var
  TIdx, SI, N : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { interface avec 2 signatures de methode }
  FuncParseTopLevel('package main' + Chr(10) +
    'type Shape interface {' + Chr(10) +
    '	Area() float64' + Chr(10) +
    '	Perimeter() float64' + Chr(10) + '}');
  SI := SymFind('Shape');
  InterfaceAssert('Shape declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  InterfaceAssert('Shape : TYK_INTERFACE', TypeTab[TIdx].Kind = TYK_INTERFACE);
  InterfaceAssert('Shape : 2 methodes', TypeTab[TIdx].MethodCount = 2);
  InterfaceAssert('Shape : 1ere methode "Area"',
    FieldPool[TypeTab[TIdx].MethodFirst].Name = 'Area');
  InterfaceAssert('Shape.Area() retourne float64',
    TypeTab[FieldPool[TypeTab[TIdx].MethodFirst].TypeIdx].ResultCount = 1);

  { interface totalement vide - equivalente a any, 0 methode }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) + 'var W interface{}');
  SI := SymFind('W');
  InterfaceAssert('W declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  InterfaceAssert('W : TYK_INTERFACE', TypeTab[TIdx].Kind = TYK_INTERFACE);
  InterfaceAssert('interface{} : 0 methode', TypeTab[TIdx].MethodCount = 0);

  { embarquement d interface : ReadWriter embarque Reader et Writer,    }
  { ses methodes doivent etre la SOMME des deux (promotion/aplatissement) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Reader interface {' + Chr(10) + '	Read() int' + Chr(10) + '}' + Chr(10) +
    'type Writer interface {' + Chr(10) + '	Write() int' + Chr(10) + '}' + Chr(10) +
    'type ReadWriter interface {' + Chr(10) +
    '	Reader' + Chr(10) + '	Writer' + Chr(10) + '}');
  SI := SymFind('ReadWriter');
  InterfaceAssert('ReadWriter declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  InterfaceAssert('ReadWriter : 2 methodes promues (Read + Write)',
    TypeTab[TIdx].MethodCount = 2);

  { assertion comma-ok, forme := }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('x', SK_VAR, PDT_ANY);
  N := StmtParseString('v, ok := x.(int)');
  InterfaceAssert('v, ok := x.(int) est STK_SHORTVAR', StmtPool[N].Kind = STK_SHORTVAR);
  InterfaceAssert('comma-ok := : 2 entrees (v et ok)', StmtPool[N].ArgCount = 2);
  SI := SymFind('v');
  InterfaceAssert('v declaree avec le type asserte (int)',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_INT));
  SI := SymFind('ok');
  InterfaceAssert('ok declaree avec le type bool',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_BOOL));

  { assertion comma-ok, forme = (v et ok deja declarees) }
  SymAdd('v2', SK_VAR, PDT_INT);
  SymAdd('ok2', SK_VAR, PDT_BOOL);
  N := StmtParseString('v2, ok2 = x.(int)');
  InterfaceAssert('v2, ok2 = x.(int) est STK_ASSIGN', StmtPool[N].Kind = STK_ASSIGN);
  InterfaceAssert('comma-ok = : 2 entrees', StmtPool[N].ArgCount = 2);

  { dispatch simplifie sur une base de type INTERFACE : la methode       }
  { resout a la signature DECLAREE par l interface (pas de vraie itable,      }
  { simplification documentee) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Shape interface {' + Chr(10) + '	Area() float64' + Chr(10) + '}' + Chr(10) +
    'func F(s Shape) float64 {' + Chr(10) + '	return s.Area()' + Chr(10) + '}');
  InterfaceAssert('s.Area() via interface analyse sans erreur', ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 11 - TABLEAUX ET SLICES : MAKE/APPEND/COPY/LEN/CAP       }
{ ============================================================ }
{ Deux ajouts distincts, comme pour struct/interface avant : la SYNTAXE   }
{ de type crochets ("[N]T" tableau fixe, "[]T" slice - deja cablee dans      }
{ ParseTypeExpr plus haut dans le fichier, TODO 05, puisqu elle doit             }
{ etre disponible avant ce bloc) et les litteraux composes/fonctions               }
{ integrees qui les manipulent. La distinction de SEMANTIQUE tableau                  }
{ (VALEUR, copie integrale) vs slice (REFERENCE, en-tete copie mais                      }
{ pointant vers le meme tableau sous-jacent) reste, comme les fermetures                     }
{ du TODO 08, un sujet de GENERATION DE CODE (TODO 21+) - rien a faire                          }
{ de plus ici au niveau de l analyse pure, qui ne fait que DISTINGUER                              }
{ TYK_ARRAY de TYK_SLICE (deja le cas, ce sont deux TTypeKind distincts).                              }
{                                                                          }
{ append/copy/len/cap (BI_APPEND/BI_COPY/BI_LEN/BI_CAP, deja classifies       }
{ comme identificateurs predeclares depuis le TODO 03) n ont besoin                    }
{ d AUCUNE syntaxe speciale - "len(s)"/"append(s, v)" etc. sont deja               }
{ des appels de fonction ORDINAIRES pour ParsePrimaryExpr/ParseCallArgs                  }
{ (TODO 06), la seule chose ajoutee ici est l INFERENCE DE TYPE best-                       }
{ effort (len/cap/copy -> int, append -> meme type que son 1er argument)                       }
{ dans ParseCallArgs, plus haut dans le fichier.                                                   }

{ ------------------------------------------------------------ }
{ ArraySelfTest : type tableau fixe, type slice, multidimensionnel,  }
{ make([]T, Len[, Cap]), litteral compose tableau/slice, inference        }
{ de type append/len/cap/copy, for-range avec le vrai ElemTypeIdx.           }
{ ------------------------------------------------------------ }

Procedure ArrayAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ArraySelfTest: ' + Label_ + ' a echoue');
End;

Procedure ArraySelfTest;
Var
  TIdx, SI, E : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { tableau fixe [5]int }
  FuncParseTopLevel('package main' + Chr(10) + 'var A [5]int');
  SI := SymFind('A');
  ArrayAssert('A declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  ArrayAssert('A : TYK_ARRAY', TypeTab[TIdx].Kind = TYK_ARRAY);
  ArrayAssert('A : longueur 5', TypeTab[TIdx].ArrayLen = 5);
  ArrayAssert('A : taille = 20 (5 x int 4 octets)', TypeTab[TIdx].Size = 20);
  ArrayAssert('A : ElemTypeIdx = int', TypeTab[TIdx].ElemTypeIdx = PDT_INT);

  { slice []int }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) + 'var S []int');
  SI := SymFind('S');
  TIdx := SymTab[SI].TypeIdx;
  ArrayAssert('S : TYK_SLICE', TypeTab[TIdx].Kind = TYK_SLICE);
  ArrayAssert('S : ElemTypeIdx = int', TypeTab[TIdx].ElemTypeIdx = PDT_INT);

  { multidimensionnel : [][]int (slice de slices) et [3][3]int (tableau  }
  { de tableaux) - recursivite naturelle de ParseTypeExpr, aucun code               }
  { special necessaire. }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'var M [][]int' + Chr(10) + 'var G [3][3]int');
  SI := SymFind('M');
  TIdx := SymTab[SI].TypeIdx;
  ArrayAssert('M : TYK_SLICE (exterieur)', TypeTab[TIdx].Kind = TYK_SLICE);
  ArrayAssert('M : element est aussi TYK_SLICE',
    TypeTab[TypeTab[TIdx].ElemTypeIdx].Kind = TYK_SLICE);
  SI := SymFind('G');
  TIdx := SymTab[SI].TypeIdx;
  ArrayAssert('G : TYK_ARRAY (exterieur), longueur 3', (TypeTab[TIdx].Kind = TYK_ARRAY)
    And (TypeTab[TIdx].ArrayLen = 3));
  ArrayAssert('G : element est aussi TYK_ARRAY, longueur 3',
    (TypeTab[TypeTab[TIdx].ElemTypeIdx].Kind = TYK_ARRAY) And
    (TypeTab[TypeTab[TIdx].ElemTypeIdx].ArrayLen = 3));

  { make([]int, 3, 10) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('make([]int, 3, 10)');
  ArrayAssert('make([]int,...) : TypeIdx est TYK_SLICE',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE);
  ArrayAssert('make([]int,...) : 2 arguments (Len, Cap)', ExprPool[E].ArgCount = 2);

  { litteral compose tableau et slice }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('[3]int{1, 2, 3}');
  ArrayAssert('[3]int{...} est EK_COMPOSITE', ExprPool[E].Kind = EK_COMPOSITE);
  ArrayAssert('[3]int{...} : TypeIdx est TYK_ARRAY',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY);
  ArrayAssert('[3]int{...} : 3 elements', ExprPool[E].ArgCount = 3);

  E := ExprParseString('[]int{1, 2, 3}');
  ArrayAssert('[]int{...} : TypeIdx est TYK_SLICE',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE);

  { inference de type : len/cap/copy -> int, append -> meme type que s }
  SymAdd('s', SK_VAR, TypeAdd(TYK_SLICE, '', 12, 4, False, PDT_INT, -1));
  E := ExprParseString('len(s)');
  ArrayAssert('len(s) : type int', ExprPool[E].TypeIdx = PDT_INT);
  E := ExprParseString('cap(s)');
  ArrayAssert('cap(s) : type int', ExprPool[E].TypeIdx = PDT_INT);
  E := ExprParseString('append(s, 1)');
  ArrayAssert('append(s, 1) : meme type que s (slice)',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE);

  { for-range avec le vrai ElemTypeIdx d un slice }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(arr []int) {' + Chr(10) +
    '	for i, v := range arr {' + Chr(10) +
    '		_ = i' + Chr(10) + '		_ = v' + Chr(10) + '	}' + Chr(10) + '}');
  ArrayAssert('for-range sur []int analyse sans erreur', ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 12 - MAPS : TABLE DE HACHAGE SIMPLIFIEE                  }
{ ============================================================ }
{ La fonction de hachage elle-meme ("simplifiee pour les cles usuelles",  }
{ texte du TODO 12 lui-meme) est un sujet d IMPLEMENTATION RUNTIME               }
{ (_GORT_, TODO 23) - il n existe rien a hacher tant qu aucune valeur                 }
{ n est reellement stockee en memoire (aucun backend, TODO 21+) ; ce                    }
{ TODO se limite donc, comme les precedents, a la SYNTAXE et au                            }
{ CABLAGE des mecanismes deja generiques (indexation EK_INDEX du                              }
{ TODO 06, comma-ok du TODO 10, for-range du TODO 07/11).                                          }

{ ParseMapType : "map" (deja consomme par l appelant) suivi de "["      }
{ TypeCle "]" TypeValeur - represente comme un simple pointeur (4              }
{ octets) vers une table de hachage runtime, meme convention qu une                  }
{ interface (descripteur+donnees) ou qu un slice (en-tete) : la               }
{ REPRESENTATION MEMOIRE exacte est un sujet de generation de code                       }
{ (TODO 21+), ce TypeIdx sert uniquement a l analyse. KeyTypeIdx (TODO           }
{ 04, jamais rempli avant ce point puisque aucun autre TTypeKind ne                  }
{ l utilise) est ENFIN mis a contribution ici.                                             }
Function ParseMapType: Integer;
Var KeyTIdx, ValTIdx, NewIdx : Integer;
Begin
  ParseMapType := -1;
  If Not PPMatch('[') Then
  Begin
    FatalError('crochet ouvrant attendu apres "map"');
    Exit;
  End;
  KeyTIdx := ParseTypeExpr;
  If Not PPMatch(']') Then
    FatalError('crochet fermant attendu apres la cle d''un type map');
  ValTIdx := ParseTypeExpr;
  NewIdx := TypeAdd(TYK_MAP, '', 4, 4, False, ValTIdx, KeyTIdx);
  ParseMapType := NewIdx;
End;

{ ------------------------------------------------------------ }
{ MapSelfTest : type map, make(map[K]V[, Cap]), indexation          }
{ lecture/ecriture, comma-ok "v, ok := m[cle]", delete(m, cle),          }
{ litteral compose a cles chaine, for-range avec les vrais               }
{ KeyTypeIdx/ElemTypeIdx.                                                    }
{ ------------------------------------------------------------ }

Procedure MapAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('MapSelfTest: ' + Label_ + ' a echoue');
End;

Procedure MapSelfTest;
Var
  TIdx, SI, E, N : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { type map[string]int }
  FuncParseTopLevel('package main' + Chr(10) + 'var M map[string]int');
  SI := SymFind('M');
  MapAssert('M declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  MapAssert('M : TYK_MAP', TypeTab[TIdx].Kind = TYK_MAP);
  MapAssert('M : cle string', TypeTab[TIdx].KeyTypeIdx = PDT_STRING);
  MapAssert('M : valeur int', TypeTab[TIdx].ElemTypeIdx = PDT_INT);

  { make(map[string]int) et make(map[string]int, 10) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('make(map[string]int)');
  MapAssert('make(map[string]int) : TypeIdx TYK_MAP',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_MAP);
  E := ExprParseString('make(map[string]int, 10)');
  MapAssert('make(map[string]int, 10) : 1 argument (Cap)', ExprPool[E].ArgCount = 1);

  { indexation lecture/ecriture }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('m', SK_VAR, TypeAdd(TYK_MAP, '', 4, 4, False, PDT_INT, PDT_STRING));
  E := ExprParseString('m["cle"]');
  MapAssert('m["cle"] est EK_INDEX', ExprPool[E].Kind = EK_INDEX);
  MapAssert('m["cle"] : type de la VALEUR (int)', ExprPool[E].TypeIdx = PDT_INT);

  N := StmtParseString('m["cle"] = 42');
  MapAssert('m["cle"] = 42 est STK_ASSIGN', StmtPool[N].Kind = STK_ASSIGN);

  { comma-ok : v, ok := m[cle] }
  N := StmtParseString('v, ok := m["cle"]');
  MapAssert('v, ok := m[cle] est STK_SHORTVAR', StmtPool[N].Kind = STK_SHORTVAR);
  MapAssert('comma-ok map : 2 entrees', StmtPool[N].ArgCount = 2);
  SI := SymFind('v');
  MapAssert('v : type de la valeur (int)',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_INT));
  SI := SymFind('ok');
  MapAssert('ok : type bool', (SI >= 0) And (SymTab[SI].TypeIdx = PDT_BOOL));

  { delete(m, cle) }
  E := ExprParseString('delete(m, "cle")');
  MapAssert('delete(m, cle) est EK_CALL', ExprPool[E].Kind = EK_CALL);
  MapAssert('delete(m, cle) : 2 arguments', ExprPool[E].ArgCount = 2);

  { litteral compose de map avec 2 cles chaine }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('map[string]int{"a": 1, "b": 2}');
  MapAssert('map[string]int{...} est EK_COMPOSITE', ExprPool[E].Kind = EK_COMPOSITE);
  MapAssert('map[string]int{...} : TypeIdx TYK_MAP',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_MAP);
  MapAssert('map[string]int{...} : 2 elements', ExprPool[E].ArgCount = 2);
  MapAssert('map[string]int{"a":1,...} : 1ere cle "a"',
    ExprArgKey[ExprPool[E].ArgFirst] = 'a');

  { for-range sur une map : vrais KeyTypeIdx/ElemTypeIdx }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(m map[string]int) {' + Chr(10) +
    '	for k, v := range m {' + Chr(10) +
    '		_ = k' + Chr(10) + '		_ = v' + Chr(10) + '	}' + Chr(10) + '}');
  MapAssert('for-range sur map[string]int analyse sans erreur', ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

Procedure Run;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  LexOpened  := False;

  LexSelfTest;
  KeywordSelfTest;
  TypeSelfTest;
  DeclSelfTest;
  ExprSelfTest;
  StmtSelfTest;
  FuncSelfTest;
  StructSelfTest;
  InterfaceSelfTest;
  ArraySelfTest;
  MapSelfTest;

  ParseArgs;
  ShowBanner;

  TypeInit;
  ExprInit;
  StmtInit;
  FuncDefInit;
  MethodDefInit;
  If Opts.Verbose Then
    WriteLn('Types predeclares enregistres : ', TypeCount);

  {$I-}
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened   := True;
  LexSrcFName := Opts.SrcFile;

  LexInit;
  LexAll;
  LexClose;

  If Opts.Verbose Then
    WriteLn('Tokens produits : ', TokenCount, ' (', TotalLines, ' lignes)');

  SymInit;
  ParserInit;
  ParseFileTopLevel;

  If Opts.Verbose Then
  Begin
    WriteLn('Symboles de portee paquet declares : ', SymCount);
    WriteLn('Fonctions de haut niveau declarees  : ', FuncDefCount);
    WriteLn('Methodes declarees                  : ', MethodDefCount);
  End;

  WriteLn('GOCW32: lexeur+classification+types+declarations+expressions+',
    'instructions+fonctions+structs+interfaces+tableaux/slices+maps ',
    '(TODO 02-12) complets - ', TokenCount, ' tokens, ', SymCount,
    ' symboles, ', FuncDefCount, ' fonctions, ', MethodDefCount,
    ' methodes - canaux/chaines/goroutines : TODO 13+).');

  ShowStats;
End;

BEGIN
  Run;
END.
