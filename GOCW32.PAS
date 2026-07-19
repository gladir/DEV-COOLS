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

(* ============================================================
  TODO 25 - VALIDATION FINALE : ETAT REEL, HONNETEMENT DOCUMENTE
  (mis a jour APRES le TODO 25 lui-meme : extension arrays/slices
  demandee explicitement par l'utilisateur suite a un rapport de
  "arrays.go ne genere pas d'executable Windows" - voir le nouveau
  bloc "EXTENSION ARRAYS/SLICES" plus bas, qui documente ce qui a
  ete ajoute et pourquoi la liste ci-dessous n'est plus tout a fait
  a jour pour arrays.go specifiquement.)
  ============================================================
  Compile+EXECUTE reellement (pas seulement "compile sans erreur")
  a ete verifie pour CHAQUE SAMPLES\GO\*.go, avec le resultat suivant :

  REUSSITE COMPLETE (compile, produit un .EXE PE Win32 REEL, EXECUTE
  sur Windows reel, code de sortie 0, sortie standard EXACTEMENT
  celle qu'un vrai "go run" produirait) :
    hello.go     - imprime "Hello, world!" (fmt.Println, chaine unique)
    codegen.go   - arithmetique/boucle/if-else (Add/Factorial/Max),
                   imprime "fact plus grand ou egal" (20 > 120 = faux)
    arrays.go    - AJOUTE APRES ce TODO 25 (voir bloc "EXTENSION
                   ARRAYS/SLICES" plus bas) : tableaux fixes, slices
                   (make/append/litteraux composes/len/cap/indexation),
                   for-range - code de sortie 0, verifie CORRECT (pas
                   seulement "ne plante pas") via un test dedie imprimant
                   chaque valeur intermediaire.
    structs.go   - AJOUTE APRES ce TODO 25 (voir bloc "EXTENSION
                   STRUCTS/METHODES/RETOURS MULTIPLES/FLOTTANTS/SWITCH"
                   plus bas) : champs/embarquement/promotion, methodes
                   receveur valeur ET pointeur - code de sortie 0,
                   verifie CORRECT via un test dedie.
    pointers.go  - AJOUTE en meme temps que structs.go (meme bloc) :
                   double dereferencement, new(T) generalise, pointeur
                   vers tableau, tranchage ("slicing", a[low:high]) -
                   code de sortie 0, verifie CORRECT via un test dedie.
    types.go     - AJOUTE en meme temps (meme bloc) : len(chaine)
                   ajoute au passage (garde explicite contre un
                   pointeur NUL) - code de sortie 0, verifie CORRECT.
    interfaces.go - AJOUTE dans une extension ULTERIEURE (voir bloc
                   "EXTENSION INTERFACES" plus bas) : dispatch dynamique
                   de methode, boxing (valeur ET pointeur), assertion de
                   type comma-ok, type switch - code de sortie 0,
                   verifie CORRECT via un test dedie exhaustif.
    semantic.go  - AJOUTE dans la MEME extension (dispatch dynamique de
                   methode a travers un parametre d'interface) - code
                   de sortie 0, sortie "forme non vide" CONFORME a un
                   vrai "go run".

  ARRET PROPRE DOCUMENTE (compile jusqu'au frontend complet -
  lexeur/types/declarations/expressions/instructions/semantique/
  bibliotheque standard, TODO 02-20, TOUS reussissent sans exception
  pour TOUS les fichiers - c'est UNIQUEMENT le GENERATEUR DE CODE,
  TODO 21, qui s'arrete proprement, jamais un plantage ni une sortie
  binaire silencieusement fausse) : channels.go, defer_panic.go,
  errors.go, lextest.go, maps.go, packages.go, stdlib.go, strings.go -
  chacun necessite AU MOINS UNE, et le plus souvent PLUSIEURS EN
  COMBINAISON, des extensions suivantes, AUCUNE desquelles n'est
  couverte par le generateur de code actuel (portee volontairement
  restreinte, decidee et documentee au TODO 21 lui-meme) :
    - maps (disposition memoire, make/index/comma-ok/delete) : maps.go
    - defer/panic/recover (deroulement de pile) : defer_panic.go
    - goroutines/canaux/select (modele cooperatif, TODO 15) :
      channels.go, lextest.go
    - chaines etendues (concatenation reelle, for-range UTF-8
      rune-par-rune, conversions []byte(s)/[]rune(s)/string(x),
      int<->float64) : strings.go
    - bibliotheque standard AU-DELA de fmt.Println/Print(chaine
      unique) - strings.*/strconv.*/math.*/os.*/fmt.Sprintf/Errorf/
      Fprintln, errors.New (StdlibTab, TODO 20, entierement RECONNUE
      par le frontend mais SANS AUCUNE contrepartie runtime au-dela
      de ce seul cas) : errors.go, packages.go, stdlib.go
  Chaque fichier restant necessite au moins UNE de ces categories,
  parfois PLUSIEURS EN COMBINAISON (ex. errors.go a besoin
  d'interfaces - desormais couvert - ET de bibliotheque standard
  etendue - toujours pas) - contrairement a arrays.go/structs.go/
  pointers.go/types.go/interfaces.go/semantic.go (qui, eux, ne
  necessitaient QUE les extensions deja traitees APRES ce TODO 25,
  voir les blocs "EXTENSION" plus bas, sans toucher au reste).

  EXTENSION ARRAYS/SLICES (ajoutee APRES ce TODO 25, sur demande
  explicite de l'utilisateur suite au rapport "arrays.go ne genere
  pas d'executable Windows") : modele memoire documente en detail
  a l'endroit ou il est implemente (avant CompileIndexAddr/
  CompileAddrOf, TODO 21) - resume ici : tableau ([N]T) = valeur
  INLINE (N*taille(T) octets contigus, aucune indirection) ; slice
  ([]T) = POINTEUR (4 octets, meme convention EAX que tout le reste)
  vers un en-tete alloue sur le tas (Data;Len;Cap, 12 octets) via un
  nouvel allocateur runtime _GORT_ALLOC (GetProcessHeap/HeapAlloc,
  AUCUNE liberation - fuite assumee, coherent avec "pas de vrai GC"
  deja documente ci-dessous). Couvre : indexation lecture/ecriture
  (tableau et slice, y compris comme cible d'affectation),
  "var T" (valeur zero reelle - lacune totale PRE-EXISTANTE avant
  cette extension, aucun "var" local n'avait jamais eu de codegen),
  make([]T,len[,cap]), litteraux composes de slice ([]T{...}, valeurs
  arbitraires) et de tableau ([N]T{...}/{} - UNIQUEMENT comme
  initialiseur direct d'un ":=", jamais ailleurs, valeur multi-mots
  incompatible avec la convention EAX unique), len/cap (constante de
  compilation pour un tableau, lecture runtime pour un slice),
  append (un seul element, avec croissance/reallocation reelle -
  meme pointeur d'en-tete conserve, alias partage assume), for-range
  sur tableau/slice. DEUX bogues REELS trouves par EXECUTION (jamais
  par la compilation ni une relecture du .asm) et corriges au passage,
  tous deux dans du code PRE-EXISTANT jamais exerce avant cette
  extension : (1) BinEmitModRM (assembleur, TODO 22) n'emettait jamais
  l'octet SIB obligatoire pour ESP comme registre de base (aucune
  forme "[ESP+N]" n'avait jamais ete generee avant make/append) ;
  (2) SymFind (resolution de nom, TODO 05) cherchait la table des
  symboles ENTIERE sans tenir compte des frontieres de fonction - un
  meme nom de variable locale reutilise dans deux fonctions
  differentes (ex. "total" dans Sum ET main, arrays.go lui-meme)
  masquait alors le bon symbole au moment du GENERATEUR DE CODE
  (execute APRES que tout le fichier ait ete analyse, contrairement
  a l'analyse elle-meme ou cette recherche globale etait correcte) -
  corrige en bornant la recherche aux symboles de la fonction en
  cours de generation (CgRestrictSymRange/TFuncDefRec.SymFirst/
  SymLast), avec repli sur les globaux. LIMITATIONS ASSUMEES de
  cette extension specifiquement : maps/chaines/canaux restent hors
  de portee pour make/len/cap/append/for-range (FatalError explicite,
  jamais simule) ; append ne couvre qu'UN SEUL element ajoute a la
  fois (pas la forme variadique) ; deux slices partageant le meme
  en-tete (ex. "s2 := s1") partagent aussi Len/Cap apres un append
  independant sur l'une des deux, ce qui diverge du vrai Go (copie
  par valeur a l'affectation) - sans consequence pour aucun
  SAMPLES\GO\*.go existant.

  EXTENSION STRUCTS/METHODES/RETOURS MULTIPLES/FLOTTANTS/SWITCH
  (ajoutee, dans la MEME session, APRES l'extension arrays/slices
  ci-dessus, sur demande explicite de l'utilisateur de "terminer" le
  generateur de code - quatre sous-systemes traites successivement,
  chacun verifie par EXECUTION reelle via un test synthetique dedie
  avant de passer au suivant, meme discipline que partout ailleurs
  dans ce fichier) :
    - STRUCTS/METHODES : acces aux champs (lecture/ecriture, PROMOTION
      a travers un champ embarque PAR VALEUR - PAS par pointeur,
      limitation assumee, voir FindFieldWithOffset/FindMethodWithOffset),
      litteraux composes de struct (positionnels et a cle, meme
      restriction "initialiseur direct de := seulement" qu'un tableau),
      appel de methode a RECEVEUR CONNU STATIQUEMENT (JAMAIS a travers
      une interface - voir plus haut, "interfaces" reste hors de
      portee) sur receveur POINTEUR (une adresse) ou VALEUR (VRAIE
      copie, mot par mot, du receveur - CurParamOffset ajuste en
      consequence cote appele, voir la note de ParseFuncDecl/SymAdd).
    - new(T) GENERALISE a n'importe quel type (pas seulement les
      slices via make) - a REVELE au passage un bogue REEL PRE-
      EXISTANT (jamais exerce avant, aucun test anterieur ne relisait
      une valeur juste allouee sans l'avoir explicitement ecrite) :
      _GORT_ALLOC appelait HeapAlloc avec dwFlags=0 au lieu de 8
      (HEAP_ZERO_MEMORY), renvoyant de la memoire NON INITIALISEE
      alors que make/new garantissent tous deux une vraie valeur zero
      en Go reel - corrige.
    - TRANCHAGE ("slicing", "base[low:high]") sur tableau/slice/pointeur
      vers tableau - alloue un NOUVEL en-tete pointant a l'INTERIEUR du
      tampon de donnees SOURCE (aucune copie d'element, vraie semantique
      Go de partage) ; la forme a 3 indices ("base[low:high:max]")
      reste hors de portee.
    - Bogue REEL trouve en corrigeant ce qui precede (encore une fois
      PAR EXECUTION, jamais par la compilation) : CompileIndexAddr/
      STK_FORRANGE calculaient TOUS DEUX l'adresse d'un tableau via
      CompileAddrOf SANS VERIFIER si la base elle-meme etait un
      POINTEUR vers tableau (ex. "pa[0]" ou "pa" est *[3]int) - dans ce
      cas, CompileAddrOf(pa) calcule &pa (l'adresse DE POINTEUR pa
      lui-meme), pas la valeur de pa (qui EST l'adresse du tableau
      vise) : "pa[0]" lisait alors un octet du POINTEUR pa au lieu du
      premier element du tableau. Corrige aux DEUX endroits (et dans
      le nouveau CompileSliceExpr, qui avait le meme piege).
    - RETOURS MULTIPLES : convention "pointeur de sortie cache" (deja
      documentee au TODO 21, jamais implementee avant cette extension)
      - le PREMIER resultat transite par EAX comme toujours ; chaque
      resultat SUIVANT est ECRIT DIRECTEMENT par l'APPELE a l'adresse
      de la variable CIBLE (fournie par l'appelant comme parametre
      CACHE, APRES tous les vrais parametres declares) - rien a
      "extraire" apres l'appel. Couvre UNIQUEMENT l'appel DIRECT d'une
      fonction utilisateur affecte a "r1, r2, ... := F(...)" (jamais
      comme sous-expression generale, jamais une methode).
    - FLOTTANTS (x87) : PORTEE DELIBEREMENT ETROITE - litteraux
      (pool deduplique par VALEUR BINAIRE, .DATA), variables LOCALES
      (lecture FLD/ecriture FSTP), arithmetique binaire +/-/*// SEULE-
      MENT, conversion float->int (FISTP via un scratch commun). AUCUNE
      comparaison flottante, AUCUN parametre/retour de fonction a
      signature flottante, AUCUNE conversion int->float - chacun reste
      un FatalError CLAIR. Valeur TOUJOURS laissee au sommet de la pile
      FPU (ST(0)), JAMAIS dans EAX - convention SEPAREE et PARALLELE
      (CompileFloatExpr), invoquee UNIQUEMENT depuis les quelques points
      d'entree qui savent deja, via ExprIsFloatTyped, qu'ils traitent une
      valeur flottante ; le reste du generateur de code (CompileExpr,
      convention EAX) est INCHANGE. Bogue REEL PRE-EXISTANT trouve au
      passage (aucun global de plus de 4 octets - float64, ou un futur
      struct/tableau global - n'avait jamais ete exerce avant) :
      EmitDataSeg sous-allouait ("DD 0", 4 octets) tout global dont le
      TYPE REEL avait besoin de plus - corrige (Size/4 lignes "DD 0"
      contigues, chacune avec son propre label - BinAssembleDataLine
      exige un label par ligne de donnees).
    - len(chaine) AJOUTE AU PASSAGE (petit gain isole, meme demarche
      que le tranchage pour pointers.go) : reutilise _GORT_STRLEN
      (deja cable pour fmt.Println/Print) avec une garde EXPLICITE
      contre un pointeur NUL (valeur zero reelle d'une chaine non
      initialisee dans ce compilateur - une chaine EST un simple
      pointeur, jamais une paire pointeur+longueur comme une slice) :
      appeler STRLEN sur NUL planterait, alors que "len(\"\")" doit
      honnetement valoir 0 en Go reel.
    - SWITCH (ORDINAIRE)/FALLTHROUGH/GOTO : chaine classique de
      comparaisons SEQUENTIELLES (PAS de table de sauts - simplicite/
      correction avant vitesse, meme discipline que tout le reste de ce
      generateur de code), avec ou sans tag (un switch SANS tag teste
      chaque valeur de case comme sa PROPRE condition booleenne, regle
      Go reelle), fallthrough (saut EXPLICITE vers le corps suivant,
      jamais un enchainement physique implicite - robuste a un
      "default" qui n'est pas en derniere position), goto/etiquettes
      (prefixe ASM UNIQUE par fonction, CurGotoLabelPfx, evite toute
      collision entre deux fonctions reutilisant le meme nom
      d'etiquette). Le TYPE SWITCH ("switch v := x.(type)") restait,
      A CE STADE de cette extension, EXPLICITEMENT hors de portee
      (StmtPool[S].Kind=STK_TYPESWITCH, FatalError clair) : il
      necessite une VRAIE information de type a l'EXECUTION (un
      descripteur de type/interface, qui n'existait pas encore) -
      couvert PLUS TARD par l'EXTENSION INTERFACES ci-dessous. AUCUN
      SAMPLES\GO\*.go n'est debloque par le switch ORDINAIRE seul a
      ce stade (chacun de ceux qui utilisent "switch" a besoin, en
      plus, d'interfaces ou de maps).
  Trois fichiers precedemment bloques rejoignent la liste "REUSSITE
  COMPLETE" grace a ce bloc : structs.go (structs/methodes), pointers.go
  (new generalise/tranchage/double dereferencement - PAS besoin de
  retours multiples/flottants/switch), types.go (len(chaine) SEUL a
  suffi - aucun des quatre autres sous-systemes n'etait necessaire).
  AUCUN autre fichier n'est debloque par les sous-systemes eux-memes
  (retours multiples, flottants, switch/goto) a ce stade : verifie
  explicitement qu'aucun fichier restant n'a besoin QUE d'un seul de
  ces trois - chacun a TOUJOURS besoin, en plus, d'interfaces et/ou de
  bibliotheque standard etendue et/ou de maps/canaux/defer-panic -
  retours multiples/flottants/switch-goto restent donc verifies
  CORRECTS par des tests SYNTHETIQUES dedies plutot que par un
  SAMPLES\GO\*.go existant qui en depend de facon isolee (aucun
  n'existe pour ces trois specifiquement).

  EXTENSION INTERFACES (ajoutee, dans une session ULTERIEURE, sur
  nouvelle demande explicite de l'utilisateur de "terminer" le
  compilateur apres avoir recu, via l'executable REEL, un message de
  portee residuelle mentionnant "interfaces/maps/goroutines/canaux/
  defer/panic/bibliotheque standard etendue") :
    - MODELE MEMOIRE : une valeur d'interface (interface{}/any/error/
      toute interface utilisateur) est un unique POINTEUR de 4 octets
      (meme convention EAX que le reste de ce generateur de code) vers
      une "boite" allouee sur le tas via le _GORT_ALLOC deja existant
      (8 octets : +0 l'index TypeTab du type CONCRET boite - qui sert
      DIRECTEMENT d'etiquette de type a l'execution, aucun descripteur/
      vtable separe n'etant necessaire puisque ce compilateur, comme Go
      lui-meme ici, n'a aucun chargement dynamique de type ; +4 un
      pointeur vers la donnee elle-meme - la valeur INLINE pour un
      scalaire/pointeur/struct/tableau, un pointeur de 8 octets alloue
      a part pour un float64 puisque la boite elle-meme n'a que 4 octets
      utiles cote donnee).
    - BOXING AUTOMATIQUE (CompileBoxValue), a DEUX points d'entree :
      (a) affectation dans une variable DEJA declaree de type interface
      (STK_ASSIGN), (b) passage d'un argument CONCRET a un parametre de
      fonction declare interface/error (verifie via le TypeIdx du
      FieldPool du parametre, CompileCallExpr). Route selon la nature de
      la source : deja une boite (simple copie du pointeur) ; pointeur
      existant (copie directe) ; struct/tableau (copie mot par mot dans
      un nouveau bloc alloue) ; flottant (ExprIsFloatTyped - alloue 8
      octets, FSTP) ; scalaire (alloue 4 octets, MOV).
    - DISPATCH DYNAMIQUE (CompileInterfaceMethodCall) : PAS de vtable -
      une chaine SEQUENTIELLE de comparaisons (CMP/JE) de l'etiquette de
      type de la boite contre chaque candidat de MethodDefPool portant
      le nom de methode appele, meme philosophie "correction avant
      vitesse" que CompileSwitch ; repli sur EAX=0 (jamais un plantage)
      si aucun candidat ne correspond. Le receveur POINTEUR est passe
      directement (DataPtr) ; le receveur VALEUR est copie mot par mot
      depuis DataPtr avant l'appel.
    - TYPE SWITCH (CompileTypeSwitch, STK_TYPESWITCH desormais couvert -
      voir la note maintenant obsolete plus haut) et ASSERTION COMMA-OK
      ("v, ok := x.(T)", dans STK_SHORTVAR) : meme technique de
      comparaison de l'etiquette de type de la boite, cette fois contre
      des TypeIdx CONNUS A LA COMPILATION plutot que des receveurs de
      methode. SIMPLIFICATION ASSUMEE (documentee, pas cachee) : la
      variable liee "v" d'un type switch garde TOUJOURS son type
      d'interface D'ORIGINE (jamais retrecie par case, contrairement au
      vrai Go) - SymFind n'ayant aucune notion de portees lexicales
      SOEURS au sein d'une meme fonction (seulement fonction-contre-
      fonction, via CgRestrictSymRange), un retrecissement par case
      exigerait un symbole PAR CASE, que SymFind ne saurait pas
      distinguer.
    - CINQ BOGUES REELS trouves PAR EXECUTION (jamais par la
      compilation ni une relecture du .asm), tous corriges :
      (1) ParseCallArgs (et, par prudence, quatre autres fonctions
      d'analyse partageant le meme pool d'arguments : ParseCompositeLiteralForType,
      ParseNewOrMake, ParseCaseClause, ParseReturnStmt) capturait
      ArgStart AVANT une boucle appelant ParseExpr, qui pouvait elle-
      meme pousser RECURSIVEMENT dans le MEME pool partage pour un
      appel/litterale/fermeture IMBRIQUE - corrompant ArgFirst/ArgCount
      de l'appel EXTERIEUR des que son premier argument contenait lui-
      meme un appel (ex. fmt.Println(Describe(sh)) sautait purement et
      simplement l'appel interne) ; corrige en tamponnant TOUS les
      arguments dans un tableau LOCAL avant de les pousser, une fois
      l'analyse (y compris toute recursion) entierement terminee - meme
      remede que celui deja en place ailleurs dans ce fichier (ex.
      ParseBlock). (2) quatre sites SymAdd non gardes dans
      ParseSimpleStmt (comma-ok et multi-affectation) enregistraient
      "_" comme un VRAI symbole - un "_ = Describe(s)" SANS RAPPORT,
      plus loin dans le meme fichier, resolvait alors "_" via SymFind
      vers CE symbole (typiquement float64), ce qui aiguillait a tort
      un appel (EK_CALL) vers CompileFloatExpr (qui n'a aucun cas pour
      EK_CALL) - corrige en excluant "_" de ces quatre SymAdd. (3)
      ParseSwitchStmt creait un DOUBLON du symbole de garde d'un type
      switch (deja enregistre par ParseSimpleStmt) au lieu de mettre a
      jour le TypeIdx du symbole EXISTANT - corrige via SymFindInScope.
      (4) mon propre codegen initial du comma-ok ecrivait un immediat
      DIRECTEMENT en memoire pour le booleen "ok" (MOV [var],1) - forme
      que BinEncodeMov ne supporte pas (seulement MOV [mem],reg) -
      corrige en passant par EAX. (5) l'ABSENCE totale de boxing des
      ARGUMENTS d'appel de fonction (seul STK_ASSIGN etait couvert au
      depart) faisait planter tout appel du type F(42) vers un
      parametre "any" (valeur brute dereferencee comme si c'etait deja
      une boite) - corrige par le point d'entree (b) ci-dessus.
    - LIMITATIONS ASSUMEES specifiques a cette extension : aucun
      retrecissement de type dans un type switch (voir plus haut) ;
      assertion de type/type switch UNIQUEMENT testes sur des cibles
      SCALAIRES/chaine (aucun SAMPLES\GO\*.go existant n'exige une
      cible struct/tableau) ; toujours aucune liberation memoire pour
      une boite (meme fuite assumee que les slices, voir plus bas).
  Deux fichiers precedemment bloques rejoignent la liste "REUSSITE
  COMPLETE" grace a ce bloc : interfaces.go (boxing/dispatch/type
  switch/comma-ok, tous exerces), semantic.go (dispatch dynamique de
  methode a travers un parametre d'interface uniquement - pas besoin
  de type switch). errors.go reste bloque : il a besoin d'interfaces
  ET de bibliotheque standard etendue (errors.New/fmt.Errorf) -
  desormais un seul manque au lieu de deux.

  LIMITATIONS ASSUMEES (demandees explicitement par ce TODO 25,
  comme les autres compilateurs de ce projet) :
    - Portee du generateur de code : voir la liste ci-dessus - le
      FRONTEND (lexeur/types/declarations/expressions/instructions/
      analyse semantique/bibliotheque standard, TODO 02-20) couvre
      la totalite du langage decrit par ce roadmap ; SEUL le backend
      (TODO 21-23) reste delibrement partiel.
    - Aucun vrai ramasse-miettes (GC) : depuis l'extension arrays/
      slices (ci-dessus), un ALLOCATEUR reel existe bel et bien
      (_GORT_ALLOC, GetProcessHeap/HeapAlloc) pour les slices - mais
      SANS AUCUNE liberation (_GORT_FREE n'existe pas) : chaque
      make/append/litteral de slice FUIT deliberement. Pour tout le
      reste (map/chan/interface/closure), aucun allocateur n'existe
      encore du tout (new/make(map)/make(chan) non couverts).
    - Aucun vrai module multi-fichiers : un seul fichier .go par
      compilation ("package main" obligatoire, TODO 05/18) - pas de
      "import" d'un autre paquet Go reel, seuls fmt/strings/strconv/
      os/math/errors sont reconnus PAR NOM QUALIFIE (TODO 20).
    - Package "unsafe" : totalement absent, jamais mentionne ni
      reconnu comme import valide (TODO 18).
    - Modele de concurrence : cooperatif simplifie (TODO 15,
      decision documentee sur place) - PAS de vrais threads Win32
      (CreateThread/CreateEvent/EnterCriticalSection ne sont jamais
      emis) ; de toute facon sans consequence pratique aujourd'hui,
      goroutines/canaux n'ayant aucune contrepartie dans le
      generateur de code (TODO 21).
    - Aucune relocation dans le .EXE produit (TODO 23) : chargeable
      SEULEMENT a l'ImageBase fixe $00400000 (pas de section
      .reloc) - suffisant pour un executable autonome simple, pas
      pour une DLL ni pour ASLR.
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
  ASM_PFX_FLOAT   = '_GOFL_';   { constante flottante (double, 8 octets) }
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

  { TODO 19 : Vrai pendant PrescanTopLevelFuncs (passe prealable         }
  { d enregistrement des signatures de fonctions de haut niveau, avant   }
  { la vraie analyse) - FatalError devient alors NON BLOQUANT (n appelle  }
  { pas Halt) puisque cette passe est purement SPECULATIVE : une         }
  { fonction dont la signature reference un type encore inconnu a ce     }
  { stade (declare plus loin dans le fichier) sera de toute facon        }
  { correctement resolue par la vraie passe qui suit juste apres.        }
  PrescanMode : Boolean;
  CurFuncSig  : Integer;   { TODO 19 : TypeIdx (TYK_FUNC) de la fonction/ }
                            { methode dont le corps est EN COURS d etre   }
                            { analyse (-1 hors de tout corps) - permet a  }
                            { ParseReturnStmt de verifier l assignabilite  }
                            { des valeurs retournees vis-a-vis des        }
                            { resultats declares. }

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
  { TODO 19 : pendant le pre-scan des signatures de haut niveau, une      }
  { "erreur fatale" (typiquement : type encore inconnu, car declare plus  }
  { loin dans le fichier) ne doit PAS arreter le programme - elle sera    }
  { re-signalee normalement par la vraie passe si le probleme persiste.   }
  If PrescanMode Then Exit;
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
{ LexDecodeUTF8 (TODO 14) : decode UNE sequence UTF-8 a partir de       }
{ LexPeekChar (1 a 4 octets, regle reelle du standard) et avance le            }
{ lexeur exactement du nombre d octets consommes - remplace la                    }
{ SIMPLIFICATION precedemment documentee ici (un caractere non-ASCII                  }
{ ecrit DIRECTEMENT, pas via \u/\U, ne lisait avant ce TODO que son                      }
{ PREMIER octet). Octet de tete invalide ou octet de continuation             }
{ manquant -> erreur claire + caractere de remplacement Unicode U+FFFD,           }
{ plutot qu un comportement indefini.                                                  }
{ ------------------------------------------------------------ }

Function LexDecodeUTF8: LongInt;
Var
  B0, Len, I : Integer;
  V : LongInt;
Begin
  B0 := Ord(LexPeekChar);
  If (B0 And $80) = 0 Then
  Begin
    LexDecodeUTF8 := B0;
    LexNextChar;
    Exit;
  End;

  If (B0 And $E0) = $C0 Then Begin Len := 2; V := B0 And $1F; End
  Else If (B0 And $F0) = $E0 Then Begin Len := 3; V := B0 And $0F; End
  Else If (B0 And $F8) = $F0 Then Begin Len := 4; V := B0 And $07; End
  Else
  Begin
    FatalError('sequence UTF-8 invalide (octet de tete incorrect)');
    LexNextChar;
    LexDecodeUTF8 := $FFFD;
    Exit;
  End;

  LexNextChar;   { consomme l octet de tete }
  For I := 2 To Len Do
  Begin
    If (Ord(LexPeekChar) And $C0) <> $80 Then
    Begin
      FatalError('sequence UTF-8 invalide (octet de continuation attendu)');
      LexDecodeUTF8 := $FFFD;
      Exit;
    End;
    V := (V Shl 6) Or (Ord(LexPeekChar) And $3F);
    LexNextChar;
  End;
  LexDecodeUTF8 := V;
End;

{ ------------------------------------------------------------ }
{ LexScanRune : litteral rune 'x' ou 'echappement' - un caractere       }
{ non-ASCII ecrit DIRECTEMENT dans le source (pas via \u/\U) passe           }
{ desormais par LexDecodeUTF8 (TODO 14) plutot que de ne lire que son            }
{ premier octet.                                                               }
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
    V := LexDecodeUTF8;
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
{ DerefIfPointer (TODO 13) : suit UN SEUL niveau de TYK_POINTER  }
{ (ElemTypeIdx = type pointe) - centralise la regle Go reelle de           }
{ DEREFERENCEMENT IMPLICITE, jusqu ici recopiee inline SEULEMENT dans           }
{ ResolveSelectorType (TODO 09, "p.Champ" fonctionne aussi bien si p est          }
{ *T que si p est T) - reutilisee au TODO 13 pour etendre EXACTEMENT              }
{ la meme regle a l indexation ("p[i]" sur un p de type *[N]T ou *[]T,               }
{ qui doit se comporter comme "(*p)[i]", jusqu ici un gap non couvert).                  }
{ Un seul niveau (pas de boucle) : Go lui-meme n autorise qu un SEUL                    }
{ niveau de dereferencement implicite (p.Champ marche pour *T, PAS pour                    }
{ **T - il faut alors explicitement (**p).Champ).                                             }
{ ------------------------------------------------------------ }

Function DerefIfPointer(TIdx: Integer): Integer;
Begin
  If (TIdx >= 0) And (TypeTab[TIdx].Kind = TYK_POINTER) Then
    DerefIfPointer := TypeTab[TIdx].ElemTypeIdx
  Else
    DerefIfPointer := TIdx;
End;

{ MethodFind est implementee bien plus bas (TODO 09/10, avec le reste  }
{ des mecanismes de methodes/structs) - forward-declaree ici car            }
{ TypeSatisfiesInterface (TODO 19) en a besoin, et doit elle-meme etre           }
{ utilisable des ParseSimpleStmt (bien avant dans le fichier).                       }
Function MethodFind(STypeIdx: Integer; Const MName: TString): Integer; Forward;

{ ------------------------------------------------------------ }
{ TypeSatisfiesInterface / TypesAssignable (TODO 19)             }
{ ------------------------------------------------------------ }

{ TypeSatisfiesInterface (lien direct TODO 10) : Vrai si            }
{ ConcreteType possede TOUTES les methodes exigees par                  }
{ InterfaceType - typage STRUCTUREL Go reel (aucune declaration              }
{ explicite de type d "implements" requise, contrairement a Delphi/         }
{ Java) - reutilise MethodFind (TODO 09/10) pour chaque methode                 }
{ exigee ; ConcreteType est d abord depointerise (une methode a                    }
{ receveur pointeur compte quand meme, exactement comme pour un                       }
{ acces normal a une methode via ResolveSelectorType).                                    }
Function TypeSatisfiesInterface(ConcreteType, InterfaceType: Integer): Boolean;
Var I, DerefType : Integer;
Begin
  TypeSatisfiesInterface := False;
  If (ConcreteType < 0) Or (InterfaceType < 0) Or
     (InterfaceType >= TypeCount) Then Exit;
  If (TypeTab[InterfaceType].Kind <> TYK_INTERFACE) And
     (TypeTab[InterfaceType].Kind <> TYK_ERROR) Then Exit;
  DerefType := DerefIfPointer(ConcreteType);
  For I := TypeTab[InterfaceType].MethodFirst To
    TypeTab[InterfaceType].MethodFirst + TypeTab[InterfaceType].MethodCount - 1 Do
    If MethodFind(DerefType, FieldPool[I].Name) < 0 Then Exit;
  TypeSatisfiesInterface := True;
End;

{ TypesStructurallyEqual : Vrai si A et B representent le MEME type -    }
{ soit LITTERALEMENT (meme TypeIdx apres resolution d ALIAS,                  }
{ TypeResolveAlias/TODO 04), soit STRUCTURELLEMENT pour un type                    }
{ COMPOSE ANONYME (Name = '' des deux cotes - pointeur/slice/tableau/                  }
{ map/chan ecrit inline, ex. "map[string]int"/"*int"/"[]T") : ce                          }
{ compilateur NE CANONICALISE PAS ces types (chaque occurrence textuelle                     }
{ obtient son PROPRE TypeIdx via TypeAdd), donc DEUX ecritures du MEME                           }
{ type compose anonyme (ex. le resultat declare "*int" d une fonction                               }
{ et le "&x" d un appelant) ont des TypeIdx DIFFERENTS bien qu ils                                       }
{ soient assignables l un a l autre en Go reel - contrairement a deux                                        }
{ types NOMMES distincts (Name non vide des deux cotes), qui restent                                             }
{ TOUJOURS distincts sauf identite exacte (deja testee) - c est                                                     }
{ PRECISEMENT la regle stricte que TODO 19 doit reproduire pour ceux-la.                                                }
Function TypesStructurallyEqual(A, B: Integer): Boolean;
Begin
  TypesStructurallyEqual := False;
  If (A < 0) Or (B < 0) Then Exit;
  A := TypeResolveAlias(A);
  B := TypeResolveAlias(B);
  If A = B Then
  Begin
    TypesStructurallyEqual := True;
    Exit;
  End;
  If TypeTab[A].Kind <> TypeTab[B].Kind Then Exit;
  If (TypeTab[A].Name <> '') Or (TypeTab[B].Name <> '') Then Exit;
  Case TypeTab[A].Kind Of
    TYK_POINTER, TYK_SLICE, TYK_ARRAY, TYK_CHAN:
      TypesStructurallyEqual := (TypeTab[A].ArrayLen = TypeTab[B].ArrayLen) And
        TypesStructurallyEqual(TypeTab[A].ElemTypeIdx, TypeTab[B].ElemTypeIdx);
    TYK_MAP:
      TypesStructurallyEqual :=
        TypesStructurallyEqual(TypeTab[A].KeyTypeIdx, TypeTab[B].KeyTypeIdx) And
        TypesStructurallyEqual(TypeTab[A].ElemTypeIdx, TypeTab[B].ElemTypeIdx);
  End;
End;

{ TypesAssignable : regle d assignabilite Go REELLE, simplifiee -        }
{ deux TypeIdx sont assignables si : (1) l un des deux cote est -1          }
{ (type encore INCONNU, best-effort - ne jamais bloquer sur une                }
{ inconnue) ; (2) ILS SONT STRUCTURELLEMENT IDENTIQUES                            }
{ (TypesStructurallyEqual ci-dessus) - regle STRICTE de Go : deux                    }
{ types NOMMES DISTINCTS de MEME representation sous-jacente (ex.                        }
{ "type Celsius float64") ne sont PAS assignables sans conversion                            }
{ EXPLICITE T(x), contrairement a un VRAI alias ("type Celsius =                                }
{ float64") ; (3) la cible est une interface (TYK_INTERFACE/TYK_ERROR)                              }
{ et la source la satisfait STRUCTURELLEMENT (TypeSatisfiesInterface                                    }
{ ci-dessus).                                                                                                }
Function TypesAssignable(SrcType, DstType: Integer): Boolean;
Begin
  TypesAssignable := True;
  If (SrcType < 0) Or (DstType < 0) Then Exit;
  If TypesStructurallyEqual(SrcType, DstType) Then Exit;
  If (TypeTab[DstType].Kind = TYK_INTERFACE) Or
     (TypeTab[DstType].Kind = TYK_ERROR) Then
  Begin
    TypesAssignable := TypeSatisfiesInterface(SrcType, DstType);
    Exit;
  End;
  TypesAssignable := False;
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

{ FieldPoolAdd est implementee au TODO 08, bien plus bas - forward-     }
{ declaree ici car TypeInit (TODO 17) en a desormais besoin pour                 }
{ synthetiser la methode "Error" de l interface predeclaree "error".              }
Function FieldPoolAdd(Const Nm: TString; TIdx: Integer; Embedded: Boolean): Integer; Forward;

{ ------------------------------------------------------------ }
{ StdlibTab (TODO 20) : bibliotheque standard minimale             }
{ (fmt/strings/strconv/os/math) - AUCUN package n est reellement     }
{ resolu (import simplifie/ignore depuis le TODO 05, meme convention        }
{ que DELPHI.PAS pour "uses") : chaque fonction/valeur reconnue PAR             }
{ NOM QUALIFIE ("pkg.Nom") est ici associee a une signature/un type                }
{ SYNTHETISE directement (pas parse depuis une source Go, exactement                  }
{ comme "error.Error()" en TODO 17) - generalise et REMPLACE la                           }
{ reconnaissance etroite (seulement errors.New/fmt.Errorf) du TODO 17.                        }
{ SLK_FUNC : TypeIdx est une VRAIE signature TYK_FUNC - une fois               }
{ affectee au noeud EK_SELECTOR (ResolveSelectorType, plus bas), le                  }
{ mecanisme GENERIQUE deja existant dans ParseCallArgs (TODO 08/17,                       }
{ "callee resolve a TYK_FUNC") s en empare SANS AUCUN changement : Extra                     }
{ est renseigne, TypeIdx recoit le premier resultat, et le multi-retour                          }
{ de ParseSimpleStmt (TODO 08/17) fonctionne desormais aussi pour              }
{ "n, err := strconv.Atoi(s)" - un vrai bug latent (err jamais declaree,                        }
{ puisqu aucune signature TYK_FUNC n existait pour ce callee avant ce                              }
{ TODO) que ce mecanisme corrige au passage. SLK_VALUE : TypeIdx est le                                }
{ type de la VALEUR elle-meme (os.Args/os.Stdout/os.Stderr/                                                }
{ math.MaxInt32/math.MinInt32 - jamais appelee, juste selectionnee).                                           }
{ ------------------------------------------------------------ }

Const
  MAX_STDLIB = 64;

Type
  TStdlibKind = (SLK_FUNC, SLK_VALUE);
  TStdlibRec = Record
    Pkg     : TString;
    Name    : TString;
    Kind    : TStdlibKind;
    TypeIdx : Integer;
  End;

Var
  StdlibTab   : Array[0..MAX_STDLIB - 1] Of TStdlibRec;
  StdlibCount : Integer;

Function StdlibAdd(Const APkg, AName: TString; AKind: TStdlibKind;
  ATypeIdx: Integer): Integer;
Begin
  If StdlibCount >= MAX_STDLIB Then
  Begin
    WarnMsg('table de la bibliotheque standard pleine (MAX_STDLIB)');
    StdlibAdd := -1;
    Exit;
  End;
  StdlibTab[StdlibCount].Pkg     := APkg;
  StdlibTab[StdlibCount].Name    := AName;
  StdlibTab[StdlibCount].Kind    := AKind;
  StdlibTab[StdlibCount].TypeIdx := ATypeIdx;
  StdlibAdd := StdlibCount;
  Inc(StdlibCount);
End;

{ StdlibFind : recherche EXACTE (sensible a la casse, comme Go       }
{ lui-meme) par (paquet, nom) - lineaire, table de taille fixe             }
{ modeste (MAX_STDLIB), adequat ici (analyse uniquement, aucune                 }
{ contrainte de performance de code genere).                                        }
Function StdlibFind(Const APkg, AName: TString): Integer;
Var I: Integer;
Begin
  StdlibFind := -1;
  For I := 0 To StdlibCount - 1 Do
    If (StdlibTab[I].Pkg = APkg) And (StdlibTab[I].Name = AName) Then
    Begin
      StdlibFind := I;
      Exit;
    End;
End;

{ StdlibMakeFunc : construit une signature TYK_FUNC ne portant QUE      }
{ ses resultats (RCount 0/1/2 - aucune fonction de la bibliotheque             }
{ standard minimale d ici n a besoin de plus de 2 resultats reels)                }
{ - les PARAMETRES ne sont volontairement PAS renseignes (ParamFirst/               }
{ ParamCount restent a -1/0, valeurs par defaut de TypeAdd) puisqu AUCUN               }
{ mecanisme de ce compilateur ne verifie jamais les types d arguments                     }
{ d appel (best-effort partout depuis le TODO 06) - seuls le NOMBRE et                       }
{ les TYPES des RESULTATS ont une consequence observable (multi-retour                          }
{ TODO 08/17, typage d une valeur simple).                                                          }
Function StdlibMakeFunc(RCount, R1, R2: Integer): Integer;
Var FT, RFirst: Integer;
Begin
  RFirst := FieldPoolCount;
  If RCount >= 1 Then FieldPoolAdd('', R1, False);
  If RCount >= 2 Then FieldPoolAdd('', R2, False);
  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, -1, -1);
  TypeTab[FT].ResultFirst := RFirst;
  TypeTab[FT].ResultCount := RCount;
  StdlibMakeFunc := FT;
End;

{ StdlibInit : synthetise chaque entree "au minimum" listee par le      }
{ roadmap du TODO 20 (fmt : Println/Print/Printf/Sprintf/Sprintln/           }
{ Errorf, plus Fprintln - implicite dans la description meme de                  }
{ os.Stdout/Stderr, "writers minimaux pour fmt.Fprintln" ; strings :                  }
{ ToUpper/ToLower/Contains/HasPrefix/HasSuffix/Split/Join/TrimSpace/                       }
{ Trim/Replace/ReplaceAll/Index/Repeat/Fields ; strconv : Itoa/Atoi/                           }
{ ParseInt/ParseFloat/FormatInt/FormatFloat/Quote ; os : Args/Exit/                                }
{ Stdout/Stderr ; math : Sqrt/Abs/Pow/Floor/Ceil/Max/Min/Mod/Inf/NaN/                                  }
{ IsNaN/MaxInt32/MinInt32). Appelee depuis TypeInit (doit etre                                            }
{ re-executee a chaque reinitialisation des types, puisqu elle          }
{ synthetise dans TypeTab/FieldPool comme "error.Error()" le fait                }
{ deja depuis le TODO 17 - memes tables, meme cycle de vie).                        }
Procedure StdlibInit;
Var TSliceStr, TFile: Integer;
Begin
  StdlibCount := 0;

  { fmt }
  StdlibAdd('fmt', 'Println',  SLK_FUNC, StdlibMakeFunc(2, PDT_INT, PDT_ERROR));
  StdlibAdd('fmt', 'Print',    SLK_FUNC, StdlibMakeFunc(2, PDT_INT, PDT_ERROR));
  StdlibAdd('fmt', 'Printf',   SLK_FUNC, StdlibMakeFunc(2, PDT_INT, PDT_ERROR));
  StdlibAdd('fmt', 'Fprintln', SLK_FUNC, StdlibMakeFunc(2, PDT_INT, PDT_ERROR));
  StdlibAdd('fmt', 'Sprintf',  SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('fmt', 'Sprintln', SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('fmt', 'Errorf',   SLK_FUNC, StdlibMakeFunc(1, PDT_ERROR, -1));

  { errors - deja reconnu par nom qualifie depuis le TODO 17            }
  { ("errors.New"), desormais via ce MEME mecanisme generique plutot           }
  { que le special-case etroit d origine (retire de ParseCallArgs). }
  StdlibAdd('errors', 'New', SLK_FUNC, StdlibMakeFunc(1, PDT_ERROR, -1));

  { strings - Split/Fields partagent le MEME TypeIdx "[]string"      }
  { anonyme (TypesStructurallyEqual, TODO 19, les rend de toute facon      }
  { assignables l un a l autre meme sans ce partage - simple economie          }
  { d une allocation TypeTab en plus). }
  TSliceStr := TypeAdd(TYK_SLICE, '', 12, 4, False, PDT_STRING, -1);
  StdlibAdd('strings', 'ToUpper',    SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'ToLower',    SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'Contains',   SLK_FUNC, StdlibMakeFunc(1, PDT_BOOL, -1));
  StdlibAdd('strings', 'HasPrefix',  SLK_FUNC, StdlibMakeFunc(1, PDT_BOOL, -1));
  StdlibAdd('strings', 'HasSuffix',  SLK_FUNC, StdlibMakeFunc(1, PDT_BOOL, -1));
  StdlibAdd('strings', 'Split',      SLK_FUNC, StdlibMakeFunc(1, TSliceStr, -1));
  StdlibAdd('strings', 'Join',       SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'TrimSpace',  SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'Trim',       SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'Replace',    SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'ReplaceAll', SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'Index',      SLK_FUNC, StdlibMakeFunc(1, PDT_INT, -1));
  StdlibAdd('strings', 'Repeat',     SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strings', 'Fields',     SLK_FUNC, StdlibMakeFunc(1, TSliceStr, -1));

  { strconv - Atoi/ParseInt/ParseFloat suivent l idiome (valeur,       }
  { error) EXACTEMENT comme la fonction utilisateur Parse de errors.go       }
  { (TODO 17) - meme mecanisme generique des deux cotes. }
  StdlibAdd('strconv', 'Itoa',        SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strconv', 'Atoi',        SLK_FUNC, StdlibMakeFunc(2, PDT_INT, PDT_ERROR));
  StdlibAdd('strconv', 'ParseInt',    SLK_FUNC, StdlibMakeFunc(2, PDT_INT64, PDT_ERROR));
  StdlibAdd('strconv', 'ParseFloat',  SLK_FUNC, StdlibMakeFunc(2, PDT_FLOAT64, PDT_ERROR));
  StdlibAdd('strconv', 'FormatInt',   SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strconv', 'FormatFloat', SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));
  StdlibAdd('strconv', 'Quote',       SLK_FUNC, StdlibMakeFunc(1, PDT_STRING, -1));

  { os - "File" est un type-support MINIMAL (struct anonyme sans       }
  { champ) juste pour donner a os.Stdout/os.Stderr un TypeIdx COHERENT       }
  { et REUTILISABLE (le meme pour les deux, comme le "*os.File" reel de           }
  { Go) - aucune vraie E/S n existe avant un backend (TODO 21+/23).                  }
  TFile := TypeAdd(TYK_STRUCT, 'File', 0, 1, False, -1, -1);
  StdlibAdd('os', 'Exit',   SLK_FUNC,  StdlibMakeFunc(0, -1, -1));
  StdlibAdd('os', 'Args',   SLK_VALUE, TSliceStr);
  StdlibAdd('os', 'Stdout', SLK_VALUE, TFile);
  StdlibAdd('os', 'Stderr', SLK_VALUE, TFile);

  { math - MaxInt32/MinInt32 sont des VALEURS (constantes predeclarees   }
  { du paquet reel), pas des fonctions - SLK_VALUE, type int32 direct. }
  StdlibAdd('math', 'Sqrt',  SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Abs',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Pow',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Floor', SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Ceil',  SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Max',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Min',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Mod',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'Inf',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'NaN',   SLK_FUNC, StdlibMakeFunc(1, PDT_FLOAT64, -1));
  StdlibAdd('math', 'IsNaN', SLK_FUNC, StdlibMakeFunc(1, PDT_BOOL, -1));
  StdlibAdd('math', 'MaxInt32', SLK_VALUE, PDT_INT32);
  StdlibAdd('math', 'MinInt32', SLK_VALUE, PDT_INT32);
End;

Procedure TypeInit;
Var
  TIByte, TIUint8, TIRune, TIInt32 : Integer;
  ErrorFuncT, RFirst, MFirst : Integer;
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

  { "error" (TODO 17) est l interface predeclaree exigeant une seule       }
  { methode "Error" retournant une string - synthetisee ICI directement          }
  { (pas parsee depuis une source Go, puisque "error" est PREDECLAREE)               }
  { plutot que laissee sans aucune methode comme au TODO 04 (simplification              }
  { alors documentee comme temporaire, en attendant que le TODO 10                            }
  { construise le vrai mecanisme d interface). DOIT venir ICI, APRES                              }
  { l enregistrement complet des 21 types predeclares ci-dessus : le type              }
  { de RESULTAT de cette methode est string (PDT_STRING=14), enregistre                              }
  { PLUS TARD que error lui-meme (PDT_ERROR=5) dans l ordre des codes                                    }
  { PDT_xxx du TODO 03 - impossible d y faire reference avant que string                                }
  { existe reellement dans TypeTab. Ne change PAS le Kind de error (reste                                   }
  { TYK_ERROR, pas TYK_INTERFACE - la distinction "verification rapide"                                        }
  { du TODO 04 reste valable) ; seul ResolveSelectorType (plus bas) doit                                          }
  { desormais traiter les deux Kind de facon identique pour la resolution                                            }
  { de methode.                                                                                                          }
  ErrorFuncT := TypeAdd(TYK_FUNC, '', 4, 4, False, -1, -1);
  RFirst := FieldPoolCount;
  FieldPoolAdd('', PDT_STRING, False);
  TypeTab[ErrorFuncT].ResultFirst := RFirst;
  TypeTab[ErrorFuncT].ResultCount := 1;
  MFirst := FieldPoolCount;
  FieldPoolAdd('Error', ErrorFuncT, False);
  TypeTab[PDT_ERROR].MethodFirst := MFirst;
  TypeTab[PDT_ERROR].MethodCount := 1;

  { bibliotheque standard minimale (TODO 20) - memes tables/cycle de   }
  { vie que "error.Error()" juste au-dessus. }
  StdlibInit;

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

  { 21 types predeclares + sentinelle TYK_INVALID + 1 (TODO 17 : le      }
  { TYK_FUNC synthetise pour la signature "() string" de la methode           }
  { "Error" de l interface predeclaree "error") + 43 (TODO 20 :                    }
  { StdlibInit - 1 "[]string" partagee (strings.Split/Fields/os.Args) +               }
  { 1 "File" (os.Stdout/Stderr) + 41 signatures TYK_FUNC synthetisees,                    }
  { une par fonction reconnue de fmt/errors/strings/strconv/os/math) =                       }
  { 66 entrees. }
  TypeAssert('21 types + sentinelle + 1 (Error()) + 43 (StdlibInit) = 66 entrees',
    TypeCount = 66);

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
    Used       : Boolean;    { TODO 19 : Vrai des la premiere reference   }
                              { LUE (ExprAddIdent) - sert a detecter les   }
                              { variables LOCALES declarees et jamais       }
                              { utilisees (erreur Go reelle, pas juste un    }
                              { avertissement - voir SymLeaveScope).          }
    IsParam    : Boolean;    { TODO 19 : Vrai pour un parametre/resultat   }
                              { nomme/recepteur (RegisterFuncScopeSymbols,   }
                              { ParseFuncDecl) - EXEMPTE de la verification   }
                              { "declaree et non utilisee" (regle Go reelle : }
                              { seules les VRAIES variables locales sont       }
                              { concernees, pas les parametres).                }
    Offset     : Integer;    { TODO 21 : position memoire pour un SK_VAR   }
                              { LOCAL (portee > 0) - positif ([EBP+Offset]),  }
                              { CROISSANT par 4, pour un vrai parametre/         }
                              { recepteur entrant (SymAddIsParam=Vrai au             }
                              { moment de l ajout) ; negatif ([EBP+Offset],              }
                              { donc en pratique [EBP-N]), DECROISSANT de la               }
                              { taille reelle du type, pour un resultat NOMME                 }
                              { ou une variable de corps (var/:=) - non                          }
                              { pertinent (jamais consulte) pour un symbole                        }
                              { de portee paquet (IsGlobal), adresse par son                          }
                              { NOM (ASM_PFX_GVAR+Name) plutot que par un                                }
                              { decalage EBP. }
    HasInit    : Boolean;    { extension arrays/slices : Vrai si ParseVarSpec  }
                              { a rencontre un "= expr" pour ce SK_VAR - permet  }
                              { a CompileStmt (STK_VARDECL) de distinguer "sans     }
                              { valeur initiale" (memoire mise a zero, valeur          }
                              { zero reelle de Go) de "valeur constante fournie"           }
                              { (ConstVal, deja calculee a l analyse). }
  End;

Var
  SymTab   : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount : Integer;

  ScopeStack    : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeStackTop : Integer;
  CurScopeLevel : Integer;
  CurScopeId    : Integer;
  ScopeIdSeq    : Integer;

  { TODO 21 : disposition memoire (pile) des symboles LOCAUX d une      }
  { fonction/methode/fermeture EN COURS d analyse - reinitialises        }
  { (CurParamOffset:=8 ; CurLocalOffset:=0) puis SAUVEGARDES/RESTAURES        }
  { (comme CurFuncSig, TODO 19) autour du corps d une fermeture IMBRIQUEE          }
  { (ParseFuncLiteral), pour que la fonction ENGLOBANTE reprenne EXACTEMENT           }
  { ou elle en etait une fois la fermeture entierement analysee - AUCUN                 }
  { rapport avec ScopeId/ScopeStack ci-dessus (portee LEXICALE pour la                     }
  { resolution de noms, TODO 05) : ici, disposition MEMOIRE pour le                            }
  { generateur de code, TODO 21. }
  CurParamOffset : Integer;
  CurLocalOffset : Integer;
  SymAddIsParam  : Boolean;   { Vrai PENDANT l enregistrement d un VRAI      }
                               { parametre entrant ou d un recepteur              }
                               { (RegisterFuncScopeSymbols/ParseFuncDecl) -             }
                               { indique a SymAdd d utiliser CurParamOffset                 }
                               { (positif, CROISSANT) plutot que CurLocalOffset                 }
                               { (negatif, DECROISSANT) pour LE PROCHAIN symbole                    }
                               { SK_VAR ajoute - un resultat NOMME (registre                           }
                               { SEPAREMENT, meme fonction) reste a Faux :                                }
                               { alloue comme un vrai local, pas comme un                                    }
                               { parametre entrant (regle Go reelle : un                                         }
                               { resultat nomme est alloue par l APPELE, pas                                        }
                               { fourni par l APPELANT).                                                                }

  { extension arrays/slices : voir la note de TFuncDefRec.SymFirst/SymLast   }
  { (TODO 05) - Faux PENDANT toute l ANALYSE (SymFind cherche alors la               }
  { table ENTIERE, comportement INCHANGE, correct puisque rien apres le                  }
  { point courant n existe encore) ; CompileFuncDef (TODO 21) le met a                       }
  { Vrai (borne a la fonction EN COURS de generation) pour la DUREE de son                       }
  { propre corps SEULEMENT, puis le remet a Faux. }
  CgRestrictSymRange : Boolean;
  CgSymRangeFirst    : Integer;
  CgSymRangeLast     : Integer;

Procedure SymInit;
Begin
  SymCount       := 0;
  ScopeStackTop  := -1;
  CurScopeLevel  := 0;
  CurScopeId     := 0;
  ScopeIdSeq     := 0;
  CurParamOffset := 8;
  CurLocalOffset := 0;
  SymAddIsParam  := False;
  CgRestrictSymRange := False;
  CgSymRangeFirst    := 0;
  CgSymRangeLast     := 0;
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

{ TODO 19 : a la fermeture d une portee LOCALE (fonction/bloc), toute      }
{ variable (SK_VAR) declaree DANS CETTE portee et jamais LUE               }
{ (SymTab[I].Used) est une erreur Go REELLE ("declared and not used" -     }
{ contrairement a beaucoup de langages ou ce n est qu un avertissement) -    }
{ l identifiant "_" (blanc) est TOUJOURS exempte, par definition. Les       }
{ constantes/types/fonctions LOCALES ne sont PAS concernes (seules les       }
{ variables le sont en Go reel). Mode strict (Opts.StrictMode, actif par     }
{ defaut) = FatalError, comme le vrai compilateur Go ; sinon, simple         }
{ avertissement (permet de desactiver cette rigueur si besoin, TODO 01).      }
Procedure SymLeaveScope;
Var I, ClosingId: Integer;
Begin
  If ScopeStackTop < 0 Then
  Begin
    WarnMsg('tentative de quitter la portee paquet (package-level)');
    Exit;
  End;
  ClosingId := CurScopeId;
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].ScopeId = ClosingId) And (SymTab[I].Kind = SK_VAR) And
       (Not SymTab[I].IsParam) And
       (Not SymTab[I].Used) And (SymTab[I].Name <> '_') Then
    Begin
      If Opts.StrictMode Then
        FatalError('variable declaree et non utilisee: ' + SymTab[I].Name)
      Else
        WarnMsg('variable declaree et non utilisee: ' + SymTab[I].Name);
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
Var I, HiIdx, LoIdx: Integer;
Begin
  SymFind := -1;
  HiIdx := SymCount - 1;
  LoIdx := 0;
  If CgRestrictSymRange Then
  Begin
    HiIdx := CgSymRangeLast - 1;
    LoIdx := CgSymRangeFirst;
  End;
  For I := HiIdx DownTo LoIdx Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  { restreint et introuvable DANS la fonction courante : repli sur les    }
  { GLOBAUX (portee paquet, visibles PARTOUT, quel que soit l ordre                }
  { textuel de declaration) - cherche alors la table ENTIERE mais                     }
  { n accepte QUE IsGlobal, jamais le local d une AUTRE fonction (c est                    }
  { exactement CE cas - meme nom local reutilise dans deux fonctions                          }
  { differentes, ex. "total" dans Sum ET main, arrays.go - qui produisait                        }
  { silencieusement un RESULTAT ERRONE avant ce correctif). }
  If CgRestrictSymRange Then
    For I := SymCount - 1 DownTo 0 Do
      If (SymTab[I].Name = Name) And SymTab[I].IsGlobal Then
      Begin
        SymFind := I;
        Exit;
      End;
End;

{ LocalSlotSize (TODO 21) : taille (en octets, arrondie a 4 minimum -   }
{ aucun alignement plus strict que 4 n est impose ici, simplification         }
{ documentee : x86-32 tolere un acces non aligne, juste potentiellement            }
{ plus lent, aucune consequence de CORRECTION) reservee sur la pile pour            }
{ un local de type TIdx - 4 par defaut si TIdx est encore inconnu (-1,                 }
{ best-effort, comme partout ailleurs dans ce fichier depuis le TODO 06).                 }
Function LocalSlotSize(TIdx: Integer): Integer;
Begin
  If (TIdx < 0) Or (TIdx >= TypeCount) Then LocalSlotSize := 4
  Else If TypeTab[TIdx].Size < 4 Then LocalSlotSize := 4
  Else LocalSlotSize := TypeTab[TIdx].Size;
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
  SymTab[SymCount].Used             := False;
  SymTab[SymCount].IsParam          := False;
  SymTab[SymCount].HasInit          := False;

  { TODO 21 : disposition memoire - seul un SK_VAR de portee LOCALE     }
  { (ScopeLevel > 0) en a besoin (un global est adresse par son NOM,          }
  { un type/const/fonction n occupe jamais d emplacement sur la pile). }
  SymTab[SymCount].Offset := 0;
  If (Kind = SK_VAR) And (CurScopeLevel > 0) Then
  Begin
    If SymAddIsParam Then
    Begin
      SymTab[SymCount].Offset := CurParamOffset;
      Inc(CurParamOffset, 4);
    End
    Else
    Begin
      Dec(CurLocalOffset, LocalSlotSize(TIdx));
      SymTab[SymCount].Offset := CurLocalOffset;
    End;
  End;

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

{ ParseChanType (implementee au TODO 15, avec le reste des canaux)      }
{ construit un TypeIdx TYK_CHAN a partir du mot-cle "chan" DEJA               }
{ CONSOMME - forward-declaree ici pour la meme raison que                            }
{ ParseFuncSignature/ParseStructType/ParseInterfaceType/ParseMapType                    }
{ juste au-dessus.                                                                }
Function ParseChanType: Integer; Forward;

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

  If PPIsOp('<-') Then
  Begin
    { "<-chan T" (reception seulement) - le marqueur de direction PRECEDE   }
    { "chan" ici, contrairement a "chan<- T" (envoi seulement, marqueur              }
    { APRES "chan" - gere DANS ParseChanType). Direction NON conservee               }
    { dans les deux cas (simplification documentee, TODO 15 : la                        }
    { verification de bon usage d un canal directionnel est un sujet du                    }
    { TODO 19 ; ce compilateur simplifie n a pas non plus besoin de la                        }
    { distinguer pour la generation de code, TODO 21+).                                          }
    PPAdvance;
    If (PPKind <> TOK_IDENT) Or (PPVal <> 'chan') Then
    Begin
      FatalError('"chan" attendu apres "<-" dans un type canal');
      Exit;
    End;
    PPAdvance;
    ParseTypeExpr := ParseChanType;
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

  If (PPKind = TOK_IDENT) And (PPVal = 'chan') Then
  Begin
    PPAdvance;
    ParseTypeExpr := ParseChanType;
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
    FatalError('expression de type non prise en charge a ce point');
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

{ declare tot (avant sa definition reelle, section TODO 07, StmtArgPool) :  }
{ extension arrays/slices, ParseVarSpec doit pouvoir y pousser chaque              }
{ symbole SK_VAR qu il declare, voir plus bas. }
Function StmtArgPush(A, B: Integer; Const Nm: TString): Integer; Forward;

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
      SymTab[SI].HasInit  := True;
      If TIdx < 0 Then
        Case Vals[I].Kind Of
          CK_INT    : SymTab[SI].TypeIdx := PDT_INT;
          CK_FLOAT  : SymTab[SI].TypeIdx := PDT_FLOAT64;
          CK_BOOL   : SymTab[SI].TypeIdx := PDT_BOOL;
          CK_STRING : SymTab[SI].TypeIdx := PDT_STRING;
        End;
    End;
    { extension arrays/slices : enregistre CE symbole dans StmtArgPool     }
    { (via A=SI, B/Nm inutilises) - ParseStatement (cas "var") capture le          }
    { INTERVALLE [StmtArgCount avant/apres ParseVarDecl] pour batir le                 }
    { ArgFirst/ArgCount du noeud STK_VARDECL, seul lien qui permet a                        }
    { CompileStmt de savoir QUELS symboles cette instruction a declares -                        }
    { inoffensif pour un "var" de PORTEE PAQUET (ParseFileTopLevel, ligne                            }
    { 4339) : ces entrees restent simplement inutilisees, aucun noeud                                    }
    { STK_VARDECL n existe a ce niveau. }
    If SI >= 0 Then StmtArgPush(SI, -1, '');
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
{ ImportedPackages (TODO 19) : trace, pour le fichier en cours          }
{ d analyse, chaque paquet importe (reconnu, IsKnownPackage) et si            }
{ AU MOINS UN appel qualifie "pkg.Nom(...)" l a REFERENCE (marque par         }
{ ParseCallArgs) - permet de detecter un "import declare et non              }
{ utilise" (ERREUR Go reelle, meme regle stricte que pour les                    }
{ variables locales - voir SymLeaveScope) a la fin de                              }
{ ParseFileTopLevel. Reinitialise a chaque appel de ParseFileTopLevel               }
{ (partagee par les auto-tests via FuncParseTopLevel ET la vraie                       }
{ compilation).                                                                            }
{ ------------------------------------------------------------ }

Const
  MAX_IMPORT = 32;

Type
  TImportRec = Record
    Name : TString;
    Used : Boolean;
  End;

Var
  ImportedPackages : Array[0..MAX_IMPORT - 1] Of TImportRec;
  ImportedCount    : Integer;

Procedure RegisterImport(Const Nam: TString);
Var I: Integer;
Begin
  For I := 0 To ImportedCount - 1 Do
    If ImportedPackages[I].Name = Nam Then Exit;   { deja enregistre }
  If ImportedCount >= MAX_IMPORT Then Exit;
  ImportedPackages[ImportedCount].Name := Nam;
  ImportedPackages[ImportedCount].Used := False;
  Inc(ImportedCount);
End;

Procedure MarkImportUsed(Const Nam: TString);
Var I: Integer;
Begin
  For I := 0 To ImportedCount - 1 Do
    If ImportedPackages[I].Name = Nam Then
    Begin
      ImportedPackages[I].Used := True;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ IsKnownPackage (TODO 18) : TABLE FIXE des SEULS paquets reellement      }
{ cables a de vraies fonctions runtime (TODO 20 - fmt/strings/strconv/        }
{ os/math), plus "errors" (deja reconnu par nom qualifie depuis le              }
{ TODO 17, "errors.New"). AUCUNE autre bibliotheque standard Go n est                 }
{ implementee - importer autre chose est un ARRET PROPRE DOCUMENTE                       }
{ (FatalError explicite), PAS un echec silencieux qui laisserait                            }
{ l utilisateur croire, a tort, qu un paquet quelconque "fonctionne".                           }
{ ------------------------------------------------------------ }

Function IsKnownPackage(Const Nam: TString): Boolean;
Begin
  IsKnownPackage := (Nam = 'fmt') Or (Nam = 'strings') Or (Nam = 'strconv') Or
    (Nam = 'os') Or (Nam = 'math') Or (Nam = 'errors');
End;

{ ------------------------------------------------------------ }
{ IsExported (TODO 18) : regle d export Go REELLE - un identificateur    }
{ de package est visible hors du package des qu il commence par une              }
{ MAJUSCULE (minuscule = prive), SANS AUCUN mot-cle dedie (contrairement            }
{ a "public"/"private" en Delphi/C++/Java) - fournie ici comme utilitaire            }
{ documente pour la coherence de l analyse, mais SANS AUCUNE consequence               }
{ pratique aujourd hui (roadmap lui-meme) : ce compilateur est mono-                     }
{ fichier/mono-paquet (tout vit dans "main"), donc rien ne peut jamais                     }
{ etre "hors du package" pour de vrai - aucun appelant ne l utilise                           }
{ encore pour REJETER quoi que ce soit, uniquement disponible pour une                          }
{ eventuelle analyse future (TODO 19+) si une vraie compilation multi-                              }
{ paquets etait un jour envisagee (hors de portee actuelle).                                            }
{ ------------------------------------------------------------ }

Function IsExported(Const Nam: TString): Boolean;
Begin
  IsExported := (Length(Nam) > 0) And (Nam[1] >= 'A') And (Nam[1] <= 'Z');
End;

{ ------------------------------------------------------------ }
{ ParseImportDecl : import "chemin" ou import ( "c1" ; "c2" ; ... )  }
{ - SYNTAXE validee ET CHAQUE CHEMIN VERIFIE contre IsKnownPackage           }
{ ci-dessus (TODO 18 - avant ce TODO, "SkipImportDecl" avalait                    }
{ n importe quel import SANS le regarder, meme simplification que le               }
{ "uses" de DELPHI.PAS, meme projet). Rien n est charge/enregistre pour                 }
{ un paquet reconnu (aucune vraie resolution de symboles de package -                      }
{ TODO 20 cable des fonctions PAR NOM QUALIFIE, pas par un vrai import).                       }
{ ------------------------------------------------------------ }

Procedure ParseImportDecl;
Var PkgNam: TString;
Begin
  PPAdvance;   { import }
  If PPIsOp('(') Then
  Begin
    PPAdvance;
    PPSkipSemis;
    While (Not PPAtEnd) And (Not PPIsOp(')')) Do
    Begin
      If (PPKind = TOK_STRING) Or (PPKind = TOK_RAWSTRING) Then
      Begin
        PkgNam := PPVal;
        If Not IsKnownPackage(PkgNam) Then
          FatalError('paquet importe non pris en charge: "' + PkgNam +
            '" (seuls fmt/strings/strconv/os/math/errors sont cables, ' +
            'voir TODO 20)')
        Else
          RegisterImport(PkgNam);
      End;
      PPAdvance;
      PPSkipSemis;
    End;
    PPMatch(')');
  End
  Else
  Begin
    If (PPKind = TOK_STRING) Or (PPKind = TOK_RAWSTRING) Then
    Begin
      PkgNam := PPVal;
      If Not IsKnownPackage(PkgNam) Then
        FatalError('paquet importe non pris en charge: "' + PkgNam +
          '" (seuls fmt/strings/strconv/os/math/errors sont cables, ' +
          'voir TODO 20)')
      Else
        RegisterImport(PkgNam);
    End;
    PPAdvance;   { le chemin importe (chaine) }
  End;
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

{ PrescanTopLevelFuncs est implementee au TODO 19, bien plus bas (juste  }
{ avant ParseFuncDecl, dont elle reutilise les mecanismes) - forward-        }
{ declaree ici car ParseFileTopLevel doit deja pouvoir l appeler AVANT           }
{ sa vraie boucle de declarations (passe prealable d enregistrement des             }
{ signatures de fonctions de haut niveau, permettant les references Go                 }
{ "avant declaration textuelle").                                                          }
Procedure PrescanTopLevelFuncs; Forward;

Procedure ParseFileTopLevel;
Var Up: TString; I: Integer;
Begin
  ImportedCount := 0;
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
  { "package main" OBLIGATOIRE (TODO 18) - seul package supporte comme      }
  { point d entree, portee mono-fichier/mono-paquet assumee (meme                  }
  { simplification que le "uses" de DELPHI.PAS, meme projet) : aucune                  }
  { vraie compilation multi-paquets n est prevue, donc un autre nom de                     }
  { package n a de toute facon aucun sens ici.                                                }
  If PPVal <> 'main' Then
    FatalError('seul "package main" est pris en charge (pas de vraie ' +
      'compilation multi-paquets, voir TODO 18)');
  PPAdvance;   { nom du package }
  PPSkipSemis;

  { TODO 19 : passe prealable - enregistre le nom+signature de chaque   }
  { fonction de haut niveau SANS receveur AVANT d analyser le moindre        }
  { corps, pour que les references Go "avant declaration textuelle"             }
  { (autorisees entre declarations de haut niveau, contrairement a                  }
  { Pascal) resolvent correctement des la premiere passe reelle              }
  { ci-dessous.                                                                    }
  PrescanTopLevelFuncs;

  While Not PPAtEnd Do
  Begin
    If PPKind <> TOK_IDENT Then Break;
    Up := PPVal;
    If Up = 'import' Then Begin ParseImportDecl; PPSkipSemis; Continue; End;
    If Up = 'const'  Then Begin ParseConstDecl; PPSkipSemis; Continue; End;
    If Up = 'var'    Then Begin ParseVarDecl;   PPSkipSemis; Continue; End;
    If Up = 'type'   Then Begin ParseTypeDecl;  PPSkipSemis; Continue; End;
    If Up = 'func'   Then Begin ParseFuncDecl;  PPSkipSemis; Continue; End;
    Break;   { autre chose qu une declaration de haut niveau connue : arret propre }
  End;

  { TODO 19 : "import declare et non utilise" est une erreur Go REELLE,   }
  { exactement comme une variable locale jamais lue (voir SymLeaveScope) -    }
  { meme discipline strict/non-strict (Opts.StrictMode, defaut True                }
  { seulement APRES ParseArgs - donc TOUJOURS False, silencieux, pendant                }
  { les auto-tests qui utilisent ParseFileTopLevel via FuncParseTopLevel).                    }
  For I := 0 To ImportedCount - 1 Do
    If Not ImportedPackages[I].Used Then
    Begin
      If Opts.StrictMode Then
        FatalError('paquet importe et non utilise: "' + ImportedPackages[I].Name + '"')
      Else
        WarnMsg('paquet importe et non utilise: "' + ImportedPackages[I].Name + '"');
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
                    { d arguments ; Extra = TypeIdx de la signature              }
                    { TYK_FUNC du callee si resolue (TODO 17), -1 sinon           }
                    { (callee non resolu ou fonction integree) - permet a               }
                    { ParseSimpleStmt de retrouver le VRAI type de CHAQUE                    }
                    { resultat pour les retours multiples ("n, err := F()")           }
    EK_INDEX,       { Left = base ; Right = index                         }
    EK_SLICE,       { Left = base ; ArgFirst/Count=3 (Low,High,Max, -1    }
                    { si omis) dans ExprArgPool                           }
    EK_SELECTOR,    { Left = base ; NameVal = nom du champ/methode        }
    EK_TYPEASSERT,  { Left = base ; Extra = TypeIdx vise                  }
    EK_COMPOSITE,   { Extra = TypeIdx ; ArgFirst/Count = elements         }
                    { (ExprArgKeyPool[i] = nom du champ, '' si positionnel) }
    EK_FUNCLIT,     { fonction anonyme/fermeture (TODO 08) ; Extra=TypeIdx   }
                    { de la signature (TYK_FUNC) ; Right=index du bloc          }
                    { corps dans StmtPool (STK_BLOCK)                              }
    EK_CONVERT,     { conversion de type explicite "T(x)" (TODO 14) ;       }
                    { Left = expression source ; Extra=TypeIdx=type CIBLE       }
    EK_RECV         { reception de canal "<-ch" (TODO 15) ; Left = canal ;   }
                    { TypeIdx = ElemTypeIdx du canal (type des valeurs recues)   }
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
    SymTab[SI].Used := True;   { TODO 19 : toute reference lue "utilise" }
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
    EK_RECV :
      { "<-ch" (TODO 15) : type des valeurs RECUES = ElemTypeIdx du canal,  }
      { exactement comme EK_DEREF pour un pointeur (meme forme "unaire            }
      { qui devoile ce qu il y a derriere"). }
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
Const MAX_COMPOSITE_ELEMS = 128;
Var
  N, ValIdx, I  : Integer;
  KeyName       : TString;
  ArgStart, Cnt : Integer;
  SavedNCL      : Boolean;
  Vals : Array[0..MAX_COMPOSITE_ELEMS - 1] Of Integer;
  Keys : Array[0..MAX_COMPOSITE_ELEMS - 1] Of TString;
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

  { extension interfaces : meme bogue, et meme correctif, que              }
  { ParseCallArgs (voir sa propre note) - "ArgStart := ExprArgCount"               }
  { capture APRES avoir analyse TOUS les elements (dans Vals/Keys, jamais              }
  { le pool partage directement), plutot qu AVANT : un element contenant                    }
  { un appel ou un litteral compose IMBRIQUE pousserait sinon DANS le                           }
  { MEME pool AVANT que ce niveau n ait pousse ses propres entrees.                                 }
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
    If Cnt < MAX_COMPOSITE_ELEMS Then
    Begin
      Vals[Cnt] := ValIdx;
      Keys[Cnt] := KeyName;
      Inc(Cnt);
    End
    Else
    Begin
      WarnMsg('trop d''elements dans un litteral compose (MAX_COMPOSITE_ELEMS depasse)');
      Inc(Cnt);
    End;
    PPSkipSemis;
    If Not PPMatch(',') Then Break;
    PPSkipSemis;
  Until PPIsOp('}');
  NoCompositeLit := SavedNCL;

  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue dans un litteral compose');

  ArgStart := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    If I < MAX_COMPOSITE_ELEMS Then ExprArgPush(Vals[I], Keys[I]);

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
Const MAX_CALL_ARGS = 64;
Var
  N, A, ArgStart, Cnt, I, CalleeSig : Integer;
  Vals : Array[0..MAX_CALL_ARGS - 1] Of Integer;
  SavedNCL: Boolean; PkgNam: TString;
Begin
  PPAdvance;   { '(' }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  PPSkipSemis;
  { extension interfaces : BOGUE REEL trouve par EXECUTION (jamais par la  }
  { compilation ni une relecture du .asm - "fmt.Println(Describe(5))"                    }
  { plantait, la valeur passee a Println etait "5" au lieu du RESULTAT de              }
  { Describe) : "ArgStart := ExprArgCount" etait capture AVANT la boucle,                  }
  { alors que "A := ParseExpr" (l analyse de CHAQUE argument) peut ELLE-                       }
  { MEME pousser dans le MEME ExprArgPool PARTAGE si cet argument contient                          }
  { un appel IMBRIQUE - les propres entrees de CE NIVEAU se retrouvaient                                 }
  { alors DECALEES apres celles de l appel imbrique, ArgFirst pointant vers                                 }
  { la MAUVAISE plage. Corrige en analysant TOUTES les valeurs D ABORD                                          }
  { (dans un tampon LOCAL, jamais le pool partage), puis en les poussant                                            }
  { TOUTES APRES coup, une fois qu AUCUNE analyse recursive ne peut plus                                                }
  { survenir - ArgStart, capture SEULEMENT maintenant, pointe alors                                                         }
  { TOUJOURS vers les entrees CONTIGUES et CORRECTES de ce niveau. }
  Cnt := 0;
  If Not PPIsOp(')') Then
  Repeat
    A := ParseExpr;
    If Cnt < MAX_CALL_ARGS Then Begin Vals[Cnt] := A; Inc(Cnt); End
    Else
    Begin
      WarnMsg('trop d''arguments dans un appel (MAX_CALL_ARGS depasse)');
      Inc(Cnt);
    End;
    PPSkipSemis;
    If Not PPMatch(',') Then Break;
    PPSkipSemis;
  Until PPIsOp(')');
  NoCompositeLit := SavedNCL;

  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans un appel');

  ArgStart := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    If I < MAX_CALL_ARGS Then ExprArgPush(Vals[I], '');

  N := ExprNew(EK_CALL);
  ExprPool[N].Left     := Callee;
  ExprPool[N].ArgFirst := ArgStart;
  ExprPool[N].ArgCount := Cnt;

  { inference GENERALE (TODO 17) : si le callee resolve a une VRAIE        }
  { signature TYK_FUNC (nom de fonction, methode, ou variable de type            }
  { fonction - TypeIdx du callee EST alors deja cette signature, quel que          }
  { soit le cas), Extra retient cette signature (necessaire a                          }
  { ParseSimpleStmt pour les retours MULTIPLES, "n, err := F()") et                       }
  { TypeIdx recoit le PREMIER resultat declare (usage a une seule                           }
  { valeur, "x := F()"/"return F()"). Ne s applique JAMAIS aux fonctions                        }
  { integrees (len/append/...) puisqu elles ne sont jamais de VRAIS                                }
  { symboles SK_FUNC - leur callee reste toujours non resolu (TypeIdx=-1).                            }
  If (ExprPool[Callee].TypeIdx >= 0) And
     (TypeTab[ExprPool[Callee].TypeIdx].Kind = TYK_FUNC) Then
  Begin
    CalleeSig := ExprPool[Callee].TypeIdx;
    ExprPool[N].Extra := CalleeSig;
    If TypeTab[CalleeSig].ResultCount >= 1 Then
      ExprPool[N].TypeIdx := FieldPool[TypeTab[CalleeSig].ResultFirst].TypeIdx;
  End;

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
      ExprPool[N].TypeIdx := ExprPool[ExprArgPool[ArgStart]].TypeIdx
    Else If ExprPool[N].NameVal = 'recover' Then
      { recover() (TODO 16) retourne la valeur passee a panic(), typee     }
      { "any" en Go reel (interface vide - elle peut etre n importe quoi) ;      }
      { nil si aucune panique n est en cours - meme discipline que les              }
      { autres fonctions integrees ci-dessus, best-effort sans verifier              }
      { que "recover" resolve reellement au builtin. }
      ExprPool[N].TypeIdx := PDT_ANY;
  End
  Else If (ExprPool[Callee].Kind = EK_SELECTOR) And (ExprPool[Callee].Left >= 0)
          And (ExprPool[ExprPool[Callee].Left].Kind = EK_IDENT) Then
  Begin
    { marque le paquet REFERENCE (TODO 19) - le TYPAGE du retour lui-meme  }
    { (errors.New/fmt.Errorf, et desormais tout fmt./strings./strconv./           }
    { os./math. reconnu, TODO 20) n a PLUS besoin d etre special-case ici :             }
    { ResolveSelectorType (appelee plus tot, a la creation du noeud                     }
    { EK_SELECTOR lui-meme) a deja affecte ExprPool[Callee].TypeIdx via                     }
    { StdlibTab si "PkgNam" est un paquet connu - le bloc GENERIQUE                             }
    { juste au-dessus (callee resolvant a TYK_FUNC) s en occupe alors                              }
    { deja, exactement comme pour un symbole SK_FUNC reel.                                            }
    PkgNam := ExprPool[ExprPool[Callee].Left].NameVal;
    MarkImportUsed(PkgNam);
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
Var N, TIdx, ArgStart, Cnt, A, I : Integer; SavedNCL: Boolean;
    Vals : Array[0..3] Of Integer;
Begin
  PPAdvance;   { '(' }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  TIdx := ParseTypeExpr;
  { extension interfaces : meme correctif que ParseCallArgs (voir sa      }
  { propre note) - analyse D ABORD (Vals, jamais le pool partage), pousse            }
  { SEULEMENT APRES, pour rester correct si "len"/"cap" contiennent eux-              }
  { memes un appel imbrique. }
  Cnt := 0;
  While PPMatch(',') Do
  Begin
    A := ParseExpr;
    If Cnt <= High(Vals) Then Begin Vals[Cnt] := A; Inc(Cnt); End
    Else Inc(Cnt);
  End;
  NoCompositeLit := SavedNCL;
  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans ' + FuncName + '(...)');

  ArgStart := ExprArgCount;
  For I := 0 To Cnt - 1 Do
    If I <= High(Vals) Then ExprArgPush(Vals[I], '');

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

{ ParseTypeConversion : "T(x)" - conversion de type EXPLICITE (TODO 14,   }
{ motivee par string([]byte)/[]byte(string)/etc., mais implementee de              }
{ facon GENERALE puisque la syntaxe Go elle-meme ne distingue pas les              }
{ conversions "de chaine" des autres - "int(x)"/"MyType(x)" suivent                    }
{ EXACTEMENT la meme grammaire). TIdx (le type CIBLE) est deja resolu             }
{ par l appelant (ParseOperand, qui a deja distingue une conversion               }
{ d un appel de fonction ordinaire ou d un litteral compose AVANT                        }
{ d appeler cette fonction). Tolere une virgule finale optionnelle                       }
{ (Go l autorise meme pour un seul argument, ex. "int(x,)").                              }
Function ParseTypeConversion(TIdx: Integer): Integer;
Var N, A : Integer; SavedNCL : Boolean;
Begin
  PPAdvance;   { '(' }
  SavedNCL := NoCompositeLit;
  NoCompositeLit := False;
  A := ParseExpr;
  PPMatch(',');
  NoCompositeLit := SavedNCL;
  If Not PPMatch(')') Then
    FatalError('parenthese fermante attendue dans une conversion de type');

  N := ExprNew(EK_CONVERT);
  ExprPool[N].Left    := A;
  ExprPool[N].Extra   := TIdx;
  ExprPool[N].TypeIdx := TIdx;
  ParseTypeConversion := N;
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
        Else If PPIsOp('(') And (SymFind(Nam) >= 0) And
                (SymTab[SymFind(Nam)].Kind = SK_TYPE) Then
          { conversion de type explicite "T(x)" (TODO 14) - un nom DEJA    }
          { resolu dans SymTab en SK_TYPE (declare via "type", visible          }
          { dans la portee courante) gagne TOUJOURS sur la reconnaissance         }
          { en type predeclare, meme regle de priorite que SymFind partout            }
          { ailleurs dans ce fichier (le plus imbrique/le plus recent               }
          { d abord - couvre aussi le cas ou un nom predeclare est masque             }
          { localement par autre chose, ex. "var int = 5" : SI trouve alors          }
          { SK_VAR, pas SK_TYPE, donc cette branche ne matche pas et on                 }
          { retombe correctement sur le fallback identificateur ordinaire).                }
          ParseOperand := ParseTypeConversion(SymTab[SymFind(Nam)].TypeIdx)
        Else If PPIsOp('(') And (SymFind(Nam) < 0) And
                (IsPredeclaredType(Nam) <> 0) Then
          ParseOperand := ParseTypeConversion(IsPredeclaredType(Nam))
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
          { "[...]T" est une expression de TYPE valide ici (ParseTypeExpr,   }
          { TODO 05, etendue au TODO 11 pour reconnaitre "[]T"/"[N]T")               }
          { immediatement suivie SOIT d elements entre accolades (litteral               }
          { compose, TODO 11), SOIT d une parenthese (conversion "[]byte(s)"/               }
          { "[]rune(s)", TODO 14) - TypeIdx deja resolu dans les deux cas,                      }
          { pas besoin de repasser par un nom comme le fait ParseCompositeLiteral.                 }
          TIdx := ParseTypeExpr;
          If PPIsOp('(') Then
            ParseOperand := ParseTypeConversion(TIdx)
          Else
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
        { tranchage (slice) : deref implicite (TODO 13) si la base est un    }
        { pointeur, PUIS - regle Go reelle - le RESULTAT est TOUJOURS un          }
        { slice (TYK_SLICE), meme si la base tranchee etait elle-meme un              }
        { tableau fixe (TYK_ARRAY) ou un pointeur vers un tableau fixe               }
        { (bogue mineur preexistant corrige au passage : avant l existence            }
        { de TYK_ARRAY, TODO 11, cette branche recopiait simplement le                    }
        { TypeIdx de la base sans distinction).                                              }
        TIdx := DerefIfPointer(ExprPool[Result_].TypeIdx);
        If TIdx >= 0 Then
        Begin
          If TypeTab[TIdx].Kind = TYK_ARRAY Then
            ExprPool[N].TypeIdx := TypeAdd(TYK_SLICE, '', 12, 4, False,
              TypeTab[TIdx].ElemTypeIdx, -1)
          Else
            ExprPool[N].TypeIdx := TIdx;
        End;
      End
      Else
      Begin
        NoCompositeLit := SavedNCL;
        If Not PPMatch(']') Then
          FatalError('crochet fermant attendu dans une indexation');
        N := ExprNew(EK_INDEX);
        ExprPool[N].Left  := Result_;
        ExprPool[N].Right := LowIdx;
        { auto-dereference (TODO 13) : "p[i]" sur un p de type *[N]T ou     }
        { *[]T se comporte comme "(*p)[i]" - meme regle Go que le                 }
        { dereferencement implicite deja applique a "p.Champ" (TODO 09).            }
        If ExprPool[Result_].TypeIdx >= 0 Then
          ExprPool[N].TypeIdx :=
            TypeTab[DerefIfPointer(ExprPool[Result_].TypeIdx)].ElemTypeIdx;
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
    PPAdvance;
    ParseUnaryExpr := ExprNewUnary('<-', EK_RECV, ParseUnaryExpr);
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
    STK_FALLTHROUGH, STK_DEFER,
    STK_SEND, STK_GO, STK_SELECT
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
  {   STK_VARDECL      ArgFirst/Count -> symboles SK_VAR declares                                           }
  {                    (StmtArgPool[i]=index SymTab - extension arrays/                                        }
  {                    slices ; StmtArgPool2[i]/StmtArgName[i] inutilises)                                          }
  {   STK_CONSTDECL/TYPEDECL  (aucune charge utile : delegue aux parseurs                                              }
  {                    du TODO 05, deja appeles au moment de creer ce                                                       }
  {                    noeud - simple marqueur pour ParseStatement)                                                             }
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
    HeaderStmt  : Integer;   { STK_SELECT (TODO 15) SEULEMENT : index dans      }
                             { StmtPool de l instruction d envoi/reception -        }
                             { -1 pour un switch/type switch ordinaire ou un              }
                             { "default" de select (ExprFirst/Count restent               }
                             { inutilises ici, un select n a pas de "valeurs                  }
                             { de case", juste UNE operation de canal).                          }
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
  CaseClausePool[CaseClauseCount].HeaderStmt  := -1;
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
{ ParseGoStmt/ParseSelectStmt sont implementees au TODO 15, bien plus     }
{ bas - forward-declarees ici pour la meme raison que ParseDeferStmt              }
{ juste au-dessus.                                                             }
Function ParseGoStmt: Integer; Forward;
Function ParseSelectStmt: Integer; Forward;

{ ExprIsCommaOkSource : Vrai si Idx est une expression pouvant fournir   }
{ la forme comma-ok ("v, ok := ...", UNE seule expression a droite pour        }
{ DEUX noms a gauche) - assertion de type (TODO 06/10, "x.(T)"),                  }
{ indexation d une MAP (TODO 12, "m[cle]" - le second booleen "ok"                    }
{ indique si la cle etait presente), ou reception de canal (TODO 15,                    }
{ "<-ch" - ok=false si le canal est FERME et VIDE). L indexation d un                        }
{ slice/tableau (TODO 11) N EST PAS comma-ok en Go reel (un index hors                    }
{ bornes PANIQUE au lieu de renvoyer un booleen), d ou le test explicite                    }
{ du Kind TYK_MAP et non simplement "est-ce un EK_INDEX".                                       }
Function ExprIsCommaOkSource(Idx: Integer): Boolean;
Var BaseTypeIdx: Integer;
Begin
  ExprIsCommaOkSource := False;
  If ExprPool[Idx].Kind = EK_TYPEASSERT Then
  Begin
    ExprIsCommaOkSource := True;
    Exit;
  End;
  If ExprPool[Idx].Kind = EK_RECV Then
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
        { extension interfaces : BOGUE REEL trouve par EXECUTION (jamais    }
        { par la compilation ni une relecture du .asm) - "_" (identifiant           }
        { blanc Go) n a JAMAIS ete exclu ICI (contrairement, par exemple, a               }
        { STK_SHORTVAR generique plus bas OU au comportement REEL de Go, ou                     }
        { "_" n est JAMAIS une vraie variable stockable) : "_, ok := x.(T)"                          }
        { creait alors un VRAI symbole nomme "_" - partage ensuite, par                                 }
        { erreur, par TOUTE AUTRE cible "_" SANS RAPPORT ailleurs dans la                                    }
        { MEME fonction (SymFind resout au NOM, pas a l identite) - un                                          }
        { symptome trouve via "_ = Describe(s)" (s Shape) resolvant                                                 }
        { accidentellement au "_" cree par un "_, bok := x.(string)"                                                    }
        { totalement independant, plus loin dans la MEME fonction. }
        If (Nam <> '_') And (SymFindInScope(Nam, CurScopeId) < 0) Then
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
        If (Nam <> '_') And (SymFindInScope(Nam, CurScopeId) < 0) Then
        Begin
          SymAdd(Nam, SK_VAR, PDT_BOOL);
          AnyNew := True;
        End;
      End
      Else
        FatalError('nom de variable attendu a gauche de ":="');
    End
    Else If (VCount = 1) And (TCount > 1) And
            (ExprPool[Vals[0]].Kind = EK_CALL) And
            (ExprPool[Vals[0]].Extra >= 0) And
            (TypeTab[ExprPool[Vals[0]].Extra].Kind = TYK_FUNC) And
            (TypeTab[ExprPool[Vals[0]].Extra].ResultCount = TCount) Then
    Begin
      { retours MULTIPLES (TODO 08/17) : "resultat, err := F(...)" - une   }
      { SEULE expression evaluee (l appel) a droite, mais la signature            }
      { DECLAREE de F a EXACTEMENT TCount resultats - chaque nom recoit               }
      { le type REEL du resultat a SA position (FieldPool via                            }
      { ResultFirst+I), pas un TypeIdx generique unique. Meme discipline                     }
      { que la forme comma-ok ci-dessus : aucun code n est genere pour                          }
      { "extraire" la Ieme valeur de retour (TODO 21+), chaque nom pousse                           }
      { simplement une reference a la MEME (et unique) expression d appel.                            }
      For I := 0 To TCount - 1 Do
      Begin
        If ExprPool[Targets[I]].Kind = EK_IDENT Then
        Begin
          Nam := ExprPool[Targets[I]].NameVal;
          StmtArgPush(-1, Vals[0], Nam);
          If (Nam <> '_') And (SymFindInScope(Nam, CurScopeId) < 0) Then
          Begin
            SymAdd(Nam, SK_VAR,
              FieldPool[TypeTab[ExprPool[Vals[0]].Extra].ResultFirst + I].TypeIdx);
            AnyNew := True;
          End;
        End
        Else
        Begin
          FatalError('nom de variable attendu a gauche de ":="');
          StmtArgPush(-1, Vals[0], '');
        End;
      End;
    End
    Else
      For I := 0 To VCount - 1 Do
        If I < TCount Then
        Begin
          If ExprPool[Targets[I]].Kind = EK_IDENT Then
          Begin
            Nam := ExprPool[Targets[I]].NameVal;
            StmtArgPush(-1, Vals[I], Nam);
            If (Nam <> '_') And (SymFindInScope(Nam, CurScopeId) < 0) Then
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
    Else If (VCount = 1) And (TCount > 1) And (Op = '=') And
            (ExprPool[Vals[0]].Kind = EK_CALL) And
            (ExprPool[Vals[0]].Extra >= 0) And
            (TypeTab[ExprPool[Vals[0]].Extra].Kind = TYK_FUNC) And
            (TypeTab[ExprPool[Vals[0]].Extra].ResultCount = TCount) Then
      { retours multiples par simple affectation (TODO 08/17) - meme        }
      { principe que la forme := ci-dessus, noms deja declares plus tot. }
      For I := 0 To TCount - 1 Do
        StmtArgPush(Targets[I], Vals[0], '')
    Else
      For I := 0 To VCount - 1 Do
        If I < TCount Then
        Begin
          { TODO 19 : regle d assignabilite Go REELLE (TypesAssignable) -   }
          { seulement pour "=" simple (les operateurs composes "+=" etc.         }
          { ont une semantique differente, hors de portee ici) et seulement          }
          { quand la cible est un identifiant nomme (evite les cibles                }
          { EK_INDEX/EK_SELECTOR, dont le TypeIdx est deja moins fiable).                }
          If (Op = '=') And (ExprPool[Targets[I]].Kind = EK_IDENT) And
             (Not TypesAssignable(ExprPool[Vals[I]].TypeIdx,
               ExprPool[Targets[I]].TypeIdx)) Then
            WarnMsg('valeur non assignable (types incompatibles) a "' +
              ExprPool[Targets[I]].NameVal + '"');
          StmtArgPush(Targets[I], Vals[I], '');
        End
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

  If PPIsOp('<-') Then
  Begin
    { instruction d envoi (TODO 15) : "Canal <- Valeur" - UNE seule       }
    { expression a gauche (le canal, deja dans Targets[0]) ; contrairement            }
    { a la reception ("<-ch"), l envoi est une INSTRUCTION a part entiere              }
    { en Go (grammaire SendStmt), pas une expression - jamais utilisable                 }
    { comme membre droit d une affectation.                                                  }
    PPAdvance;
    N := StmtNew(STK_SEND);
    StmtPool[N].Left  := Targets[0];
    StmtPool[N].Right := ParseExpr;
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
      { chan (TODO 15), PDT_INT reste le meilleur repli possible ici,                          }
      { meme discipline que ExprInferBinaryType. Pour une STRING (TODO 14),           }
      { la cle est l offset en OCTETS (PDT_INT, deja correct par defaut) et                }
      { la valeur est le RUNE DECODE a cet offset (PDT_RUNE) - le VRAI                          }
      { decodage UTF-8 octet-par-octet reste un sujet d EXECUTION (TODO 21+/                       }
      { 23), aucune valeur n existant encore en memoire ; seul le TYPE de                              }
      { "v" est fixe ici.                                                                                 }
      { deref implicite (TODO 13) : "for i, v := range p" fonctionne aussi   }
      { bien si p est *[N]T (pointeur vers tableau) que si p est [N]T             }
      { directement - meme regle que p.Champ/p[i].                                    }
      CollTypeIdx := DerefIfPointer(ExprPool[StmtPool[N].Left].TypeIdx);
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
        End
        Else If TypeTab[CollTypeIdx].Kind = TYK_STRING Then
          ValTypeIdx := PDT_RUNE;
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
{ TODO 21 : BodyStart/BodyCnt souffrent du MEME bogue d entrelacement    }
{ que ParseBlock (voir sa propre note, juste au-dessus) - corrige avec le      }
{ MEME remede (tampon local puis push en bloc). }
Function ParseCaseClause(IsTypeSwitchCtx: Boolean): Integer;
Const MAX_CASEBODY_BUF = 128;
Var
  C, ExprStart, ExprCnt, BodyStart, BodyCnt, SIdx, TIdx, I : Integer;
  IsDefault : Boolean;
  BodyBuf : Array[0..MAX_CASEBODY_BUF - 1] Of Integer;
  ExprBuf : Array[0..MAX_CASEBODY_BUF - 1] Of Integer;
Begin
  SymEnterScope;
  IsDefault := False;
  ExprCnt := 0;

  { extension interfaces : meme correctif que ParseCallArgs/                }
  { ParseCompositeLiteralForType (voir leurs propres notes) - accumule             }
  { D ABORD dans un tampon LOCAL (ExprBuf), pousse dans ExprArgPool                    }
  { SEULEMENT APRES : une valeur de "case" contenant un appel/litteral                    }
  { compose IMBRIQUE (ex. "case Foo(), Bar():") pousserait sinon dans                          }
  { CE MEME pool avant que cette clause n ait pu y placer SES PROPRES                              }
  { entrees. }
  If PPMatch('case') Then
  Begin
    Repeat
      If IsTypeSwitchCtx Then
        TIdx := ParseTypeExpr
      Else
        TIdx := ParseExpr;
      If ExprCnt < MAX_CASEBODY_BUF Then
      Begin
        ExprBuf[ExprCnt] := TIdx;
        Inc(ExprCnt);
      End
      Else
        Inc(ExprCnt);
    Until Not PPMatch(',');
  End
  Else If PPMatch('default') Then
    IsDefault := True
  Else
    FatalError('"case" ou "default" attendu');

  ExprStart := ExprArgCount;
  For I := 0 To ExprCnt - 1 Do
    If I < MAX_CASEBODY_BUF Then ExprArgPush(ExprBuf[I], '');

  If Not PPMatch(':') Then
    FatalError('":" attendu apres "case"/"default"');

  PPSkipSemis;
  BodyCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) And
        (Not ((PPKind = TOK_IDENT) And ((PPVal = 'case') Or (PPVal = 'default')))) Do
  Begin
    SIdx := ParseStatement;
    If BodyCnt < MAX_CASEBODY_BUF Then
    Begin
      BodyBuf[BodyCnt] := SIdx;
      Inc(BodyCnt);
    End
    Else
      WarnMsg('corps de "case" trop grand pour le tampon local (MAX_CASEBODY_BUF), TODO 21');
    PPSkipSemis;
  End;

  SymLeaveScope;

  BodyStart := StmtArgCount;
  For I := 0 To BodyCnt - 1 Do
    StmtArgPush(BodyBuf[I], -1, '');

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
  N, Init, TagStmt, TagExprIdx, FirstArgIdx, VExistingSI : Integer;
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
        { extension interfaces : "v" a DEJA ete enregistre comme un VRAI    }
        { symbole SK_VAR par le traitement GENERIQUE de ":=" ci-dessus                  }
        { (ParseSimpleStmt, avant meme que CE code n ait pu detecter qu il                  }
        { s agissait en realite d une garde de type switch) - avec pour                             }
        { TYPE celui, sans grand sens, du marqueur EK_TYPEASSERT lui-meme                                }
        { (Extra=-2), PAS un type utilisable. Corrige ICI le TYPE de CE                                      }
        { MEME symbole existant (SymFindInScope, jamais un SECOND SymAdd -                                       }
        { BOGUE REEL trouve par EXECUTION, "variable declaree et non                                                 }
        { utilisee: v" alors que "_= v" REFERENCE bel et bien "v" : un                                                   }
        { second SymAdd ici aurait cree un DOUBLON, le PREMIER - jamais              }
        { marque "utilise" puisque toute reference future resout au             }
        { PLUS RECENT via SymFind - restant en faute au moment de                  }
        { SymLeaveScope). Simplification ASSUMEE (voir aussi la note de                }
        { CompileTypeSwitch, TODO 21) : garde le type DECLARE de x lui-                    }
        { meme (jamais NARROWED vers le type concret du "case" - la regle                      }
        { Go reelle - un symbole PAR CLAUSE romprait SymFind, qui ne                                }
        { distingue que des FONCTIONS entre elles, jamais deux portees                                 }
        { SOEURS dans la MEME fonction). }
        If (TSVarName <> '') And (TSVarName <> '_') Then
        Begin
          VExistingSI := SymFindInScope(TSVarName, CurScopeId);
          If VExistingSI >= 0 Then
            SymTab[VExistingSI].TypeIdx := ExprPool[TagExprIdx].TypeIdx
          Else
            SymAdd(TSVarName, SK_VAR, ExprPool[TagExprIdx].TypeIdx);
        End;
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
Const MAX_RETURN_VALS = 16;
Var N, ArgStart, Cnt, EIdx, I, ExpCnt : Integer;
    Vals : Array[0..MAX_RETURN_VALS - 1] Of Integer;
Begin
  PPAdvance;   { return }
  N := StmtNew(STK_RETURN);
  { extension interfaces : meme correctif que ParseCallArgs (voir sa      }
  { propre note) - accumule D ABORD (Vals), pousse dans StmtArgPool                     }
  { SEULEMENT APRES : une valeur de retour contenant un litteral de                        }
  { fonction (fermeture) AVEC CORPS (un "return" immediatement suivi              }
  { d une fermeture invoquee sur place) pousserait                                       }
  { sinon SES PROPRES instructions dans ce MEME pool avant que "return"                          }
  { n ait pu y placer SA PROPRE entree. }
  Cnt := 0;
  If (PPKind <> TOK_SEMI) And (Not PPAtEnd) And (Not PPIsOp('}')) Then
  Repeat
    EIdx := ParseExpr;
    If Cnt < MAX_RETURN_VALS Then Begin Vals[Cnt] := EIdx; Inc(Cnt); End
    Else Inc(Cnt);
  Until Not PPMatch(',');
  ArgStart := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    If I < MAX_RETURN_VALS Then StmtArgPush(Vals[I], -1, '');
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;

  { TODO 19 : verifie l assignabilite de chaque valeur retournee vis-a-vis  }
  { du resultat DECLARE a la meme position, pour la fonction/methode/         }
  { fermeture ACTUELLEMENT en cours d analyse (CurFuncSig) - "return" nu             }
  { (Cnt=0, resultats deja nommes/assignes) reste hors de portee ici, le               }
  { decompte EXACT est le cas le plus courant et le plus fiable a                          }
  { verifier sans faux positif.                                                              }
  If (CurFuncSig >= 0) And (Cnt > 0) Then
  Begin
    ExpCnt := TypeTab[CurFuncSig].ResultCount;
    If ExpCnt = Cnt Then
    Begin
      For I := 0 To Cnt - 1 Do
        If Not TypesAssignable(ExprPool[StmtArgPool[ArgStart + I]].TypeIdx,
             FieldPool[TypeTab[CurFuncSig].ResultFirst + I].TypeIdx) Then
          WarnMsg('valeur de retour non assignable (types incompatibles) ' +
            'au resultat declare');
    End
    Else
      WarnMsg('nombre de valeurs retournees incompatible avec la ' +
        'signature declaree');
  End;

  ParseReturnStmt := N;
End;

Function ParseFallthroughStmt: Integer;
Begin
  PPAdvance;   { fallthrough }
  ParseFallthroughStmt := StmtNew(STK_FALLTHROUGH);
End;

{ TODO 21 : bogue LATENT depuis le TODO 07, du MEME type que              }
{ l entrelacement de FieldPool trouve au TODO 10 - reste invisible jusqu a          }
{ ce qu un code VERITABLEMENT ecrit/lise StmtArgPool par plage CONTIGUE               }
{ (ici, le generateur de code, premier a vraiment PARCOURIR l arbre StmtPool                 }
{ via ArgFirst/ArgCount plutot que de simplement le CONSTRUIRE). Capturer                        }
{ "ArgStart := StmtArgCount" PUIS pousser une entree par instruction AU FUR            }
{ ET A MESURE (ancien code) suppose que RIEN d autre ne pousse dans                            }
{ StmtArgPool entre deux iterations - FAUX des qu une instruction enfant                             }
{ (ex. une affectation simple, "_= v") pousse ELLE-MEME sa PROPRE entree                                 }
{ (cible/valeur) dans ce MEME pool AVANT que le bloc englobant n ait pu                                      }
{ y pousser SA PROPRE entree (l index de cette instruction) pour CETTE                                           }
{ meme iteration - les deux listes s entrelacent, et la plage                                                        }
{ "ArgFirst/ArgCount" du bloc pointe alors, en partie, vers les entrees                                                  }
{ D UNE AUTRE instruction plutot que les siennes. Corrige EXACTEMENT comme                                                  }
{ au TODO 10 : accumuler dans un TAMPON LOCAL (immunise a l entrelacement)                                                      }
{ et ne pousser dans StmtArgPool qu APRES que plus aucune analyse imbriquee                                                         }
{ ne puisse survenir pour CETTE liste precise - a ce moment, la plage                                                                   }
{ [StmtArgCount-avant-le-bulk-push, +Cnt) est GARANTIE contigue.                                                                            }
Function ParseBlock: Integer;
Const MAX_BLOCK_BUF = 128;
Var
  N, ArgFirst, Cnt, SIdx, I : Integer;
  Buf : Array[0..MAX_BLOCK_BUF - 1] Of Integer;
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
    SIdx := ParseStatement;
    If Cnt < MAX_BLOCK_BUF Then
    Begin
      Buf[Cnt] := SIdx;
      Inc(Cnt);
    End
    Else
      WarnMsg('bloc trop grand pour le tampon local (MAX_BLOCK_BUF), TODO 21');
    PPSkipSemis;
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du bloc');
  SymLeaveScope;

  ArgFirst := StmtArgCount;
  For I := 0 To Cnt - 1 Do
    StmtArgPush(Buf[I], -1, '');

  N := StmtNew(STK_BLOCK);
  StmtPool[N].ArgFirst := ArgFirst;
  StmtPool[N].ArgCount := Cnt;
  ParseBlock := N;
End;

Function ParseStatement: Integer;
Var Nam: TString; N, VArgFirst: Integer;
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
    If Nam = 'go' Then Begin ParseStatement := ParseGoStmt; Exit; End;
    If Nam = 'select' Then Begin ParseStatement := ParseSelectStmt; Exit; End;
    If Nam = 'var' Then
    Begin
      { extension arrays/slices : capture l intervalle StmtArgPool ouvert    }
      { par CHAQUE symbole que ParseVarSpec pousse (voir sa definition,           }
      { section TODO 05) pendant CET appel a ParseVarDecl - aucun autre               }
      { StmtArgPush n intervient entre les deux bornes (une specification                  }
      { "var" ne contient jamais elle-meme d instruction). }
      VArgFirst := StmtArgCount;
      ParseVarDecl;
      N := StmtNew(STK_VARDECL);
      StmtPool[N].ArgFirst := VArgFirst;
      StmtPool[N].ArgCount := StmtArgCount - VArgFirst;
      ParseStatement := N;
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
Var I, SI: Integer;
Begin
  { TODO 21 : SymAddIsParam=Vrai UNIQUEMENT pour ce premier groupe (VRAIS   }
  { parametres entrants, [EBP+8], [EBP+12], ... via CurParamOffset) - un        }
  { resultat NOMME (second groupe plus bas) reste IsParam=Vrai (TODO 19,             }
  { exempte de "declaree/non utilisee") mais PAS SymAddIsParam (regle Go               }
  { reelle : un resultat nomme est alloue par l APPELE sur SA PROPRE pile,               }
  { pas fourni en argument par l appelant - donc CurLocalOffset, negatif).                  }
  SymAddIsParam := True;
  For I := 0 To TypeTab[FT].ParamCount - 1 Do
  Begin
    SI := SymAdd(FieldPool[TypeTab[FT].ParamFirst + I].Name, SK_VAR,
      FieldPool[TypeTab[FT].ParamFirst + I].TypeIdx);
    If SI >= 0 Then SymTab[SI].IsParam := True;   { TODO 19 : exempte de }
                                                    { "declaree/non       }
                                                    { utilisee" (regle Go)}
  End;
  SymAddIsParam := False;
  For I := 0 To TypeTab[FT].ResultCount - 1 Do
    If FieldPool[TypeTab[FT].ResultFirst + I].Name <> '' Then
    Begin
      SI := SymAdd(FieldPool[TypeTab[FT].ResultFirst + I].Name, SK_VAR,
        FieldPool[TypeTab[FT].ResultFirst + I].TypeIdx);
      If SI >= 0 Then SymTab[SI].IsParam := True;
    End;
End;

{ ParseFuncLiteral : fonction anonyme utilisee comme EXPRESSION (donc     }
{ potentiellement une fermeture si son corps reference des variables         }
{ d une portee englobante encore ouverte - voir la note en tete de              }
{ section). PP est deja juste apres "func" (consomme par ParseOperand).             }
Function ParseFuncLiteral: Integer;
Var FT, BodyIdx, N, SavedCFS, SavedParamOfs, SavedLocalOfs : Integer;
Begin
  FT := ParseFuncSignature;

  { TODO 21 : contrairement a une fonction/methode de haut niveau            }
  { (ParseFuncDecl), une fermeture PEUT etre imbriquee dans le corps               }
  { d une autre fonction deja en cours d analyse - sauvegarder/restaurer             }
  { CurParamOffset/CurLocalOffset (meme discipline que CurFuncSig, TODO 19)             }
  { est indispensable pour que la fonction ENGLOBANTE reprenne sa PROPRE                    }
  { disposition memoire EXACTEMENT ou elle en etait, une fois la                                }
  { fermeture entierement analysee (sa PROPRE disposition, elle, repart                            }
  { toujours de zero : [EBP+8]/[EBP-4], comme toute fonction).                                        }
  SavedParamOfs := CurParamOffset;
  SavedLocalOfs := CurLocalOffset;
  CurParamOffset := 8;
  CurLocalOffset := 0;

  SymEnterScope;
  RegisterFuncScopeSymbols(FT);
  SavedCFS := CurFuncSig;   { TODO 19 : une fermeture a SA PROPRE }
  CurFuncSig := FT;         { signature de resultats pour "return" }
  BodyIdx := ParseBlock;
  CurFuncSig := SavedCFS;
  SymLeaveScope;

  CurParamOffset := SavedParamOfs;
  CurLocalOffset := SavedLocalOfs;

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
    LocalFrameSize: Integer; { TODO 21 : octets a reserver (SUB ESP,N)  }
                               { pour TOUS les locaux/resultats nommes - il      }
                               { est CAPITAL que ce champ soit remis a jour           }
                               { LORS DU RATTACHEMENT (voir ParseFuncDecl,               }
                               { cas "deja pre-enregistree" du TODO 19) et pas             }
                               { seulement lors de la creation initiale : le                  }
                               { pre-scan (PrescanTopLevelFuncs) ne parcourt                     }
                               { jamais de corps, donc ne connait JAMAIS la                         }
                               { bonne valeur - seul le VRAI passage (celui                            }
                               { qui analyse reellement le corps) la calcule.                             }
    SymFirst    : Integer;   { extension arrays/slices : plage [SymFirst;   }
    SymLast     : Integer;   { SymLast) dans SymTab (bornes de SymCount           }
                               { juste avant/apres SymEnterScope/SymLeaveScope           }
                               { de CETTE fonction, TODO 08) - permet a CgSymFind                }
                               { (codegen SEULEMENT, TODO 21) de restreindre la                     }
                               { recherche par NOM aux VRAIS locaux/parametres                          }
                               { de CETTE fonction plutot qu a la table ENTIERE :                           }
                               { SymFind (parse-time, inchangee) cherche encore                                 }
                               { globalement, ce qui est CORRECT pendant l analyse                                  }
                               { (rien apres le point courant n existe encore) -                                       }
                               { mais redevient FAUX au codegen, execute APRES que                                        }
                               { TOUT le fichier ait ete analyse : un meme nom de                                             }
                               { variable LOCALE reutilise dans une AUTRE fonction                                                }
                               { (ex. "total" dans Sum ET dans main, arrays.go)                                                      }
                               { masquait alors le bon symbole - BOGUE REEL trouve                                                       }
                               { par EXECUTION reelle (resultat errone, pas un                                                              }
                               { plantage), pas par la compilation ni une relecture                                                            }
                               { du texte .asm. }
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
  PrescanMode := False;
  CurFuncSig  := -1;
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
    LocalFrameSize: Integer;   { TODO 21 : octets a reserver (SUB ESP,N) }
                                { pour TOUS les locaux/resultats nommes -    }
                                { -CurLocalOffset au moment ou le corps a         }
                                { fini d etre analyse. }
    SymFirst      : Integer;   { extension structs/methodes : meme role que  }
    SymLast       : Integer;   { TFuncDefRec.SymFirst/SymLast (voir sa note        }
                                 { propre) - necessaire des que les methodes             }
                                 { sont reellement GENEREES (et non plus                    }
                                 { seulement analysees) pour que CgRestrictSymRange              }
                                 { puisse aussi les borner correctement.                            }
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

{ FindFieldWithOffset/FindMethodWithOffset (extension structs/methodes,   }
{ TODO 21) : memes algorithmes que StructFindField/MethodFind ci-dessus,        }
{ mais accumulent EN PLUS OutOffset = somme des deplacements de champs               }
{ EMBARQUES PAR VALEUR traverses pour atteindre le vrai champ/receveur -             }
{ permet au generateur de code de calculer l adresse promue en une SEULE             }
{ addition (adresse de base + OutOffset), quelle que soit la profondeur                 }
{ de promotion. Limitation ASSUMEE : une promotion qui traverse un champ                 }
{ embarque PAR POINTEUR (ex. struct contenant "*Animal" nu) necessiterait               }
{ un VRAI                                                                                    }
{ dereferencement intermediaire (charger le pointeur, PUIS ajouter le                            }
{ deplacement interne) plutot qu une simple somme arithmetique - ce cas                              }
{ est deliberement IGNORE ici (le champ/methode promu au travers d un                                   }
{ embarquement pointeur reste introuvable, -1, plutot que de calculer une                                   }
{ adresse fausse) ; aucun SAMPLES\GO\*.go existant n embarque un champ par                                       }
{ pointeur, seulement par valeur. }
Function FindFieldWithOffset(STypeIdx: Integer; Const FName: TString; Var OutOffset: Integer): Integer;
Var I, EmbTypeIdx, Found, SubOfs: Integer;
Begin
  FindFieldWithOffset := -1;
  OutOffset := 0;
  If (STypeIdx < 0) Or (TypeTab[STypeIdx].Kind <> TYK_STRUCT) Then Exit;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].Name = FName Then
    Begin
      OutOffset := FieldPool[I].Offset;
      FindFieldWithOffset := I;
      Exit;
    End;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].IsEmbedded And (TypeTab[FieldPool[I].TypeIdx].Kind <> TYK_POINTER) Then
    Begin
      EmbTypeIdx := FieldPool[I].TypeIdx;
      Found := FindFieldWithOffset(EmbTypeIdx, FName, SubOfs);
      If Found >= 0 Then
      Begin
        OutOffset := FieldPool[I].Offset + SubOfs;
        FindFieldWithOffset := Found;
        Exit;
      End;
    End;
End;

Function FindMethodWithOffset(STypeIdx: Integer; Const MName: TString; Var OutOffset: Integer): Integer;
Var I, EmbTypeIdx, RTIdx, Found, SubOfs: Integer;
Begin
  FindMethodWithOffset := -1;
  OutOffset := 0;
  If (STypeIdx < 0) Or (TypeTab[STypeIdx].Kind <> TYK_STRUCT) Then Exit;

  For I := 0 To MethodDefCount - 1 Do
  Begin
    RTIdx := MethodDefPool[I].RecvTypeIdx;
    If TypeTab[RTIdx].Kind = TYK_POINTER Then RTIdx := TypeTab[RTIdx].ElemTypeIdx;
    If (RTIdx = STypeIdx) And (MethodDefPool[I].Name = MName) Then
    Begin
      FindMethodWithOffset := I;
      Exit;
    End;
  End;

  For I := TypeTab[STypeIdx].FieldFirst To TypeTab[STypeIdx].FieldFirst +
    TypeTab[STypeIdx].FieldCount - 1 Do
    If FieldPool[I].IsEmbedded And (TypeTab[FieldPool[I].TypeIdx].Kind <> TYK_POINTER) Then
    Begin
      EmbTypeIdx := FieldPool[I].TypeIdx;
      Found := FindMethodWithOffset(EmbTypeIdx, MName, SubOfs);
      If Found >= 0 Then
      Begin
        OutOffset := FieldPool[I].Offset + SubOfs;
        FindMethodWithOffset := Found;
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
{ TODO 21+). TYK_ERROR (TODO 17) est traite IDENTIQUEMENT a TYK_INTERFACE           }
{ ici - "error" reste son propre TTypeKind distinct (verification rapide,           }
{ TODO 04) mais possede desormais une VRAIE methode "Error" enregistree               }
{ (TypeInit, TODO 17) exactement comme une interface ordinaire.                          }
Procedure ResolveSelectorType(SelNode: Integer);
Var BaseTypeIdx, FIdx, MIdx, I, BaseNode, SLI : Integer;
Begin
  BaseNode := ExprPool[SelNode].Left;
  BaseTypeIdx := ExprPool[BaseNode].TypeIdx;
  If BaseTypeIdx < 0 Then
  Begin
    { TODO 20 : base non resolue (aucun symbole reel - c est le cas       }
    { normal pour un nom de PAQUET comme "fmt"/"math", puisque les             }
    { imports restent simplifies/ignores depuis le TODO 05) - tente               }
    { une resolution PAR NOM QUALIFIE dans la bibliotheque standard                  }
    { minimale (StdlibTab/StdlibFind, TODO 20). Pour une fonction                        }
    { (SLK_FUNC), TypeIdx recoit directement sa signature TYK_FUNC - le                     }
    { mecanisme GENERIQUE deja existant dans ParseCallArgs (TODO 08/17)                        }
    { s en empare ensuite sans aucun changement, exactement comme pour                            }
    { un symbole SK_FUNC reel. Pour une valeur (SLK_VALUE - os.Args/                                  }
    { os.Stdout/os.Stderr/math.MaxInt32/etc.), TypeIdx recoit le type de                                 }
    { la valeur elle-meme directement.                                                                     }
    If ExprPool[BaseNode].Kind = EK_IDENT Then
    Begin
      SLI := StdlibFind(ExprPool[BaseNode].NameVal, ExprPool[SelNode].NameVal);
      If SLI >= 0 Then
        ExprPool[SelNode].TypeIdx := StdlibTab[SLI].TypeIdx;
    End;
    Exit;
  End;

  BaseTypeIdx := DerefIfPointer(BaseTypeIdx);
  If BaseTypeIdx < 0 Then Exit;

  If (TypeTab[BaseTypeIdx].Kind = TYK_INTERFACE) Or
     (TypeTab[BaseTypeIdx].Kind = TYK_ERROR) Then
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

{ SkipBraceBlock (TODO 19) : PP DOIT pointer SUR l accolade ouvrante    }
{ "{" - avance jusqu a APRES la MATCHING accolade fermante, profondeur       }
{ correctement geree pour les blocs imbriques (if/for/switch/etc a               }
{ l interieur) - utilisee par PrescanTopLevelFuncs pour SAUTER un corps               }
{ de fonction sans l analyser (seule la SIGNATURE nous interesse a ce                    }
{ stade).                                                                                    }
Procedure SkipBraceBlock;
Var Depth: Integer;
Begin
  If Not PPMatch('{') Then Exit;
  Depth := 1;
  While (Depth > 0) And (Not PPAtEnd) Do
  Begin
    If PPIsOp('{') Then Inc(Depth)
    Else If PPIsOp('}') Then Dec(Depth);
    PPAdvance;
  End;
End;

{ SkipToNextTopLevelDecl (TODO 19) : avance PP JETON PAR JETON en          }
{ suivant une profondeur COMBINEE de "(", "[" et "{" (incrementee pour           }
{ chacune de ces trois ouvrantes, decrementee pour leur fermante                    }
{ correspondante), jusqu a ce que la profondeur revienne a 0 ET que le                 }
{ jeton COURANT soit l un des mots-cles de haut niveau reconnus                             }
{ ("import"/"const"/"var"/"type"/"func") ou la fin du fichier. PUREMENT                        }
{ MECANIQUE (n interprete JAMAIS le contenu saute) - donc robuste face a                          }
{ n importe quel contenu syntaxiquement valide entre deux declarations                                }
{ (litteraux composes, appels imbriques, litteraux de fonction, etc.),                                    }
{ sans risque de mal interpreter une construction qui ne devrait pas                                          }
{ etre traitee comme une nouvelle declaration de haut niveau. Doit etre                                          }
{ appelee APRES avoir deja consomme le mot-cle de la declaration a       }
{ sauter elle-meme (sinon elle s arreterait immediatement sur CE MEME    }
{ mot-cle, encore courant, a la profondeur 0).                                                                          }
Procedure SkipToNextTopLevelDecl;
Var Depth: Integer;
Begin
  Depth := 0;
  While Not PPAtEnd Do
  Begin
    If (Depth = 0) And (PPKind = TOK_IDENT) And
       ((PPVal = 'import') Or (PPVal = 'const') Or (PPVal = 'var') Or
        (PPVal = 'type') Or (PPVal = 'func')) Then Exit;
    If PPIsOp('(') Or PPIsOp('[') Or PPIsOp('{') Then Inc(Depth)
    Else If PPIsOp(')') Or PPIsOp(']') Or PPIsOp('}') Then Dec(Depth);
    PPAdvance;
  End;
End;

{ PrescanTopLevelFuncs (TODO 19) : PASSE PREALABLE qui enregistre le      }
{ NOM et la SIGNATURE de chaque fonction top-level SANS RECEVEUR (une         }
{ methode reste hors de portee ici - limitation documentee, les                  }
{ methodes restent resolues dans l ordre textuel comme avant TODO 19)                }
{ AVANT que la vraie passe (ParseFileTopLevel) n analyse le moindre                     }
{ corps de fonction - permet les references Go REELLES "avant                              }
{ declaration textuelle" (contrairement a Pascal, ou l ordre textuel                            }
{ est obligatoire). Chaque corps de fonction rencontre ici est SAUTE                                }
{ (SkipBraceBlock) sans etre analyse : aucune instruction n est                                        }
{ construite, aucun symbole LOCAL n est cree - seule la signature                                          }
{ (donc le nom+type de la fonction elle-meme) devient visible pour la                                          }
{ VRAIE passe qui suit. Toute erreur rencontree ICI (typiquement : un                                              }
{ type encore inconnu, car declare plus loin dans le fichier) est                                                      }
{ NON BLOQUANTE (PrescanMode desactive Halt() dans FatalError) - la                                                        }
{ vraie passe la re-signalera normalement si le probleme persiste                                                             }
{ reellement. Les declarations import/const/var/type sont hors de                                                                 }
{ portee de ce pre-scan : on les saute mecaniquement (SkipToNextTopLevelDecl)                                                       }
{ sans y toucher, la vraie passe s en chargera normalement ensuite.                                                                    }
Procedure PrescanTopLevelFuncs;
Var SavedPP, FT, SI : Integer; Nam : TString;
Begin
  SavedPP := PP;
  PrescanMode := True;
  PPSkipSemis;
  While Not PPAtEnd Do
  Begin
    If PPKind <> TOK_IDENT Then Break;
    If PPVal = 'func' Then
    Begin
      PPAdvance;   { func }
      If PPIsOp('(') Then
      Begin
        { methode : hors de portee de ce pre-scan (limitation documentee) -  }
        { reutilise les VRAIS parseurs pour AVANCER PP correctement au-dela      }
        { de la signature (gere donc correctement N IMPORTE QUEL type de              }
        { parametre, y compris un struct/interface/func anonyme) sans RIEN                 }
        { enregistrer (ni SymTab ni MethodDefPool), puis saute le corps.                       }
        PPAdvance;   { '(' }
        If PPKind = TOK_IDENT Then PPAdvance;   { nom du receveur, ignore }
        If Not PPIsOp(')') Then ParseTypeExpr;  { type du receveur }
        PPMatch(')');
        If PPKind = TOK_IDENT Then PPAdvance;   { nom de la methode, ignore }
        ParseFuncSignature;
        If PPIsOp('{') Then SkipBraceBlock;
      End
      Else If PPKind = TOK_IDENT Then
      Begin
        Nam := PPVal;
        PPAdvance;
        FT := ParseFuncSignature;
        SI := SymAdd(Nam, SK_FUNC, FT);
        If (SI >= 0) And (FuncDefCount < MAX_FUNC) Then
        Begin
          FuncDefPool[FuncDefCount].Name          := Nam;
          FuncDefPool[FuncDefCount].TypeIdx       := FT;
          FuncDefPool[FuncDefCount].BodyStmtIdx   := -1;
          FuncDefPool[FuncDefCount].LocalFrameSize:= 0;
          Inc(FuncDefCount);
        End;
        If PPIsOp('{') Then SkipBraceBlock;
      End;
      PPSkipSemis;
    End
    Else If (PPVal = 'import') Or (PPVal = 'const') Or (PPVal = 'var') Or
            (PPVal = 'type') Then
    Begin
      PPAdvance;   { avance au-dela du mot-cle lui-meme AVANT d appeler   }
                    { SkipToNextTopLevelDecl, qui s arreterait sinon                }
                    { IMMEDIATEMENT sur ce meme mot-cle.                                }
      SkipToNextTopLevelDecl;
      PPSkipSemis;
    End
    Else
      Break;
  End;
  PrescanMode := False;
  PP := SavedPP;
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
  FT, BodyIdx, RecvTypeIdx, PreSI, I, SavedCFS, SymFirstMark : Integer;
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

  { TODO 19 : une fonction SANS receveur peut deja avoir ete            }
  { pre-enregistree (nom + signature) par PrescanTopLevelFuncs, AVANT    }
  { meme que la moindre autre declaration de haut level n ait ete          }
  { analysee - permet les references Go REELLES "avant declaration          }
  { textuelle" (contrairement a Pascal). Si c est le cas, on ne cree PAS       }
  { un second symbole/une seconde entree FuncDefPool : on reutilise            }
  { celle deja en place et on se contente d y RATTACHER le VRAI corps              }
  { (et la signature FRAICHE, potentiellement plus complete si un type               }
  { qu elle referencait n etait pas encore connu lors du pre-scan).                     }
  PreSI := -1;
  If Not IsMethod Then
  Begin
    PreSI := SymFindInScope(Nam, 0);
    If (PreSI >= 0) And (SymTab[PreSI].Kind <> SK_FUNC) Then PreSI := -1;
  End;

  FT := ParseFuncSignature;
  If PreSI >= 0 Then SymTab[PreSI].TypeIdx := FT;

  { TODO 21 : une fonction/methode de haut niveau n est JAMAIS imbriquee   }
  { dans une autre (contrairement a une fermeture, ParseFuncLiteral) -            }
  { simple reinitialisation, sans sauvegarde/restauration necessaire.                 }
  CurParamOffset := 8;
  CurLocalOffset := 0;
  SymFirstMark := SymCount;
  SymEnterScope;
  If IsMethod And (RecvName <> '') And (RecvName <> '_') Then
  Begin
    SymAddIsParam := True;
    I := SymAdd(RecvName, SK_VAR, RecvTypeIdx);
    SymAddIsParam := False;
    If I >= 0 Then
    Begin
      SymTab[I].IsParam := True;
      { extension structs/methodes : un receveur PAR VALEUR dont le type   }
      { est un struct occupe SES OCTETS REELS (vraie copie de valeur,             }
      { CompileMethodCall) plutot que le "+4" fixe que SymAdd vient de                 }
      { reserver pour tout AUTRE parametre - corrige CurParamOffset ICI,                    }
      { retroactivement, pour CE symbole SEULEMENT (le receveur est                            }
      { TOUJOURS le premier ajoute, CurParamOffset valait encore 8 a cet                            }
      { instant precis, donc AUCUN autre parametre n a encore ete                                      }
      { positionne a corriger en cascade). }
      If (Not IsPtrRecv) And (RecvTypeIdx >= 0) And
         (TypeTab[RecvTypeIdx].Kind = TYK_STRUCT) And
         (TypeTab[RecvTypeIdx].Size > 4) Then
        CurParamOffset := 8 + TypeTab[RecvTypeIdx].Size;
    End;
  End;
  RegisterFuncScopeSymbols(FT);
  SavedCFS := CurFuncSig;
  CurFuncSig := FT;
  BodyIdx := ParseBlock;
  CurFuncSig := SavedCFS;
  SymLeaveScope;

  If IsMethod Then
  Begin
    If MethodDefCount < MAX_FUNC Then
    Begin
      MethodDefPool[MethodDefCount].RecvName       := RecvName;
      MethodDefPool[MethodDefCount].RecvTypeIdx    := RecvTypeIdx;
      MethodDefPool[MethodDefCount].IsPointerRecv  := IsPtrRecv;
      MethodDefPool[MethodDefCount].Name           := Nam;
      MethodDefPool[MethodDefCount].TypeIdx        := FT;
      MethodDefPool[MethodDefCount].BodyStmtIdx    := BodyIdx;
      MethodDefPool[MethodDefCount].LocalFrameSize := -CurLocalOffset;
      MethodDefPool[MethodDefCount].SymFirst       := SymFirstMark;
      MethodDefPool[MethodDefCount].SymLast        := SymCount;
      Inc(MethodDefCount);
    End
    Else
      WarnMsg('table des methodes pleine (MAX_FUNC)');
  End
  Else If PreSI < 0 Then
  Begin
    SymAdd(Nam, SK_FUNC, FT);
    If FuncDefCount < MAX_FUNC Then
    Begin
      FuncDefPool[FuncDefCount].Name          := Nam;
      FuncDefPool[FuncDefCount].TypeIdx       := FT;
      FuncDefPool[FuncDefCount].BodyStmtIdx   := BodyIdx;
      FuncDefPool[FuncDefCount].LocalFrameSize:= -CurLocalOffset;
      FuncDefPool[FuncDefCount].SymFirst      := SymFirstMark;
      FuncDefPool[FuncDefCount].SymLast       := SymCount;
      Inc(FuncDefCount);
    End
    Else
      WarnMsg('table des fonctions pleine (MAX_FUNC)');
  End
  Else
  Begin
    { deja pre-enregistree (nom+signature+entree FuncDefPool) : y        }
    { rattache simplement le corps maintenant analyse, et rafraichit           }
    { la signature au cas ou elle aurait ete completee ci-dessus - ainsi           }
    { que LocalFrameSize (TODO 21), que le pre-scan n a JAMAIS pu calculer               }
    { correctement puisqu il ne parcourt jamais le corps lui-meme.                          }
    For I := 0 To FuncDefCount - 1 Do
      If FuncDefPool[I].Name = Nam Then
      Begin
        FuncDefPool[I].TypeIdx        := FT;
        FuncDefPool[I].BodyStmtIdx    := BodyIdx;
        FuncDefPool[I].LocalFrameSize := -CurLocalOffset;
        FuncDefPool[I].SymFirst       := SymFirstMark;
        FuncDefPool[I].SymLast        := SymCount;
        Break;
      End;
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

{ ============================================================ }
{ TODO 13 - POINTEURS ET GESTION MEMOIRE                        }
{ ============================================================ }
{ La plupart des mecanismes de ce TODO existaient DEJA, construits           }
{ comme prealables necessaires a des TODO anterieurs : &x/*p (EK_ADDR/            }
{ EK_DEREF, TODO 06), new(T) (ParseNewOrMake, TODO 08), dereferencement                }
{ implicite pour "p.Champ" (ResolveSelectorType, TODO 09). Le vrai                        }
{ travail NEUF ici est double : (1) etendre la MEME regle de                                  }
{ dereferencement implicite, jusqu ici limitee au selecteur de champ,                            }
{ a l indexation/tranchage/for-range (un p de type *[N]T ou *[]T doit                               }
{ se comporter EXACTEMENT comme [N]T/[]T pour "p[i]", "p[a:b]" et                                       }
{ "range p") via un nouvel helper centralise DerefIfPointer, et (2)                                        }
{ documenter EXPLICITEMENT les deux non-fonctionnalites du roadmap                                            }
{ ("Pas de veritable GC" / "Pas d'arithmetique de pointeurs") comme des                                          }
{ ABSENCES DELIBEREES plutot que des oublis :                                                                       }
{   - GC : le tas grandira via HeapAlloc/VirtualAlloc Win32 (TODO 23)               }
{     SANS aucun recyclage automatique - limitation documentee des le                    }
{     depart, dans la continuite des autres compilateurs de ce projet               }
{     (aucun d entre eux n implemente de GC reel non plus).                                }
{   - Arithmetique de pointeurs : ce compilateur n a JAMAIS ajoute + / -        }
{     comme operateurs valides sur un TypeIdx TYK_POINTER (contrairement             }
{     a C) - simple ABSENCE de code plutot qu un rejet actif ; le              }
{     package "unsafe" (seul endroit ou l arithmetique de pointeurs                    }
{     aurait un sens en Go reel) reste totalement hors de portee.                        }

{ ------------------------------------------------------------ }
{ PointerSelfTest : &x/*p, pointeur vers pointeur (**T), new(T)     }
{ pour un type predeclare/struct/slice, comparaison a nil,             }
{ auto-dereference pour le champ ET l indexation ET le for-range,          }
{ affectation A TRAVERS un pointeur ("*p = valeur").                       }
{ ------------------------------------------------------------ }

Procedure PointerAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PointerSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PointerSelfTest;
Var
  TIdx, SI, E, N : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { &x et *p, types associes }
  SymAdd('x', SK_VAR, PDT_INT);
  E := ExprParseString('&x');
  PointerAssert('&x est EK_ADDR', ExprPool[E].Kind = EK_ADDR);
  PointerAssert('&x : TypeIdx est un pointeur vers int',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_POINTER) And
    (TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PDT_INT));

  SymAdd('p', SK_VAR, TypeAdd(TYK_POINTER, '', 4, 4, False, PDT_INT, -1));
  E := ExprParseString('*p');
  PointerAssert('*p est EK_DEREF', ExprPool[E].Kind = EK_DEREF);
  PointerAssert('*p : TypeIdx = int (type pointe)', ExprPool[E].TypeIdx = PDT_INT);

  { pointeur vers pointeur : **T }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) + 'var PP **int');
  SI := SymFind('PP');
  PointerAssert('PP declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  PointerAssert('PP : TYK_POINTER (exterieur)', TypeTab[TIdx].Kind = TYK_POINTER);
  PointerAssert('PP : element est aussi TYK_POINTER',
    TypeTab[TypeTab[TIdx].ElemTypeIdx].Kind = TYK_POINTER);
  PointerAssert('PP : pointeur-vers-pointeur-vers-int',
    TypeTab[TypeTab[TIdx].ElemTypeIdx].ElemTypeIdx = PDT_INT);

  { new(T) pour un type predeclare ET pour un type struct nomme }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('new(int)');
  PointerAssert('new(int) : pointeur vers int',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_POINTER) And
    (TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PDT_INT));

  SI := TypeAdd(TYK_STRUCT, 'Point', 8, 4, False, -1, -1);
  SymAdd('Point', SK_TYPE, SI);
  E := ExprParseString('new(Point)');
  PointerAssert('new(Point) : pointeur vers Point',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_POINTER) And
    (TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = SI));

  { comparaison a nil }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('p', SK_VAR, TypeAdd(TYK_POINTER, '', 4, 4, False, PDT_INT, -1));
  E := ExprParseString('p == nil');
  PointerAssert('p == nil : type bool', ExprPool[E].TypeIdx = PDT_BOOL);

  { auto-dereference pour l INDEXATION : p de type *[5]int, "p[0]"      }
  { doit se comporter comme "(*p)[0]" (TypeIdx = int, pas [5]int).             }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  TIdx := TypeAdd(TYK_ARRAY, '', 20, 4, False, PDT_INT, -1);
  TypeTab[TIdx].ArrayLen := 5;
  SymAdd('p', SK_VAR, TypeAdd(TYK_POINTER, '', 4, 4, False, TIdx, -1));
  E := ExprParseString('p[0]');
  PointerAssert('p[0] via *[5]int : TypeIdx = int (auto-deref)',
    ExprPool[E].TypeIdx = PDT_INT);

  { auto-dereference pour le TRANCHAGE : "p[1:2]" sur *[5]int doit      }
  { produire un SLICE ([]int), pas rester un tableau ([5]int).                }
  E := ExprParseString('p[1:2]');
  PointerAssert('p[1:2] via *[5]int : resultat TYK_SLICE (pas TYK_ARRAY)',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE);
  PointerAssert('p[1:2] : element du slice resultant = int',
    TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx = PDT_INT);

  { tranchage direct (SANS pointeur) d un tableau fixe : meme regle,    }
  { verifie le bogue mineur corrige au passage (avant TODO 13, cette             }
  { branche recopiait le TypeIdx du tableau tel quel, TYK_ARRAY au lieu             }
  { de TYK_SLICE). }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  TIdx := TypeAdd(TYK_ARRAY, '', 20, 4, False, PDT_INT, -1);
  TypeTab[TIdx].ArrayLen := 5;
  SymAdd('arr', SK_VAR, TIdx);
  E := ExprParseString('arr[1:2]');
  PointerAssert('arr[1:2] (tableau direct) : resultat TYK_SLICE',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE);

  { auto-dereference pour le FOR-RANGE : "for i, v := range p" sur un   }
  { p de type *[3]int doit donner a v le vrai type int (pas [3]int).           }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(p *[3]int) {' + Chr(10) +
    '	for i, v := range p {' + Chr(10) +
    '		_ = i' + Chr(10) + '		_ = v' + Chr(10) + '	}' + Chr(10) + '}');
  PointerAssert('for-range sur *[3]int analyse sans erreur (auto-deref)',
    ErrorCount = 0);

  { affectation A TRAVERS un pointeur : "*p = 42" }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('p', SK_VAR, TypeAdd(TYK_POINTER, '', 4, 4, False, PDT_INT, -1));
  N := StmtParseString('*p = 42');
  PointerAssert('*p = 42 est STK_ASSIGN', StmtPool[N].Kind = STK_ASSIGN);

  { auto-dereference pour l ACCES A UN CHAMP (deja construit au TODO      }
  { 09, revalide ici pour completude du theme "pointeurs") }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Animal struct {' + Chr(10) + '	Nom string' + Chr(10) + '}' + Chr(10) +
    'func F(p *Animal) string {' + Chr(10) + '	return p.Nom' + Chr(10) + '}');
  PointerAssert('p.Nom via *Animal analyse sans erreur (auto-deref, TODO 09)',
    ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 14 - CHAINES, RUNES ET UTF-8                             }
{ ============================================================ }
{ string (sequence d octets IMMUABLE) et rune/byte (alias de int32/       }
{ uint8) existent DEJA depuis le TODO 04 - la vraie nouveaute ici est          }
{ triple : (1) LexDecodeUTF8, un decodage UTF-8 minimal (1 a 4 octets)               }
{ qui remplace la simplification documentee depuis le TODO 02 (un                       }
{ caractere non-ASCII ecrit directement dans un litteral rune ne lisait                    }
{ auparavant que son premier octet) ; (2) for-range sur une string                             }
{ (cle=PDT_INT en octets, valeur=PDT_RUNE) ; (3) les conversions de                                }
{ type explicites "T(x)" en general (motivees par string([]byte)/                                    }
{ []byte(string)/[]rune(string)/etc. du roadmap, mais implementees SANS                                  }
{ distinction pour toute paire de types - "int(x)"/"MyType(x)" suivent                                      }
{ la meme grammaire Go). Concatenation +/comparaison lexicographique/                                          }
{ len(s) en octets/chaines brutes existaient deja tels quels (TODO 02/                                            }
{ 05/06/11) - aucun changement necessaire, la SEMANTIQUE D EXECUTION                                                  }
{ (comparaison octet-a-octet reelle, decodage UTF-8 au moment du                                                        }
{ for-range reel) restant un sujet de generation de code (TODO 21+),                                                       }
{ meme discipline que tous les TODO precedents depuis le TODO 08.                                                             }

{ ------------------------------------------------------------ }
{ StringSelfTest : decodage UTF-8 direct (2 et 3 octets) dans un      }
{ litteral rune, for-range sur une string (cle=int, valeur=rune),        }
{ conversions de type "T(x)" (predeclare, slice-vers-string et              }
{ inverse, type nomme utilisateur).                                              }
{ ------------------------------------------------------------ }

Procedure StringAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StringSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StringSelfTest;
Var
  SI, E : Integer;
  Src : TString;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { litteral rune avec un caractere UTF-8 direct sur 2 octets : 'e     }
  { accent aigu' (U+00E9) code en UTF-8 comme les octets $C3 $A9. }
  Src := Chr(39) + Chr($C3) + Chr($A9) + Chr(39);
  E := ExprParseString(Src);
  StringAssert('rune UTF-8 2 octets (U+00E9) : IntVal = 233',
    ExprPool[E].IntVal = 233);

  { litteral rune avec un caractere UTF-8 direct sur 3 octets :        }
  { U+65E5 ("jour" en japonais) code en UTF-8 comme $E6 $97 $A5. }
  Src := Chr(39) + Chr($E6) + Chr($97) + Chr($A5) + Chr(39);
  E := ExprParseString(Src);
  StringAssert('rune UTF-8 3 octets (U+65E5) : IntVal = 26085',
    ExprPool[E].IntVal = 26085);

  { for-range sur une string : cle=int (offset octet), valeur=rune }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(s string) {' + Chr(10) +
    '	for i, r := range s {' + Chr(10) +
    '		_ = i' + Chr(10) + '		_ = r' + Chr(10) + '	}' + Chr(10) + '}');
  StringAssert('for-range sur string analyse sans erreur', ErrorCount = 0);

  { conversions de type "T(x)" }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('x', SK_VAR, PDT_INT);
  E := ExprParseString('float64(x)');
  StringAssert('float64(x) est EK_CONVERT', ExprPool[E].Kind = EK_CONVERT);
  StringAssert('float64(x) : TypeIdx = float64', ExprPool[E].TypeIdx = PDT_FLOAT64);

  SymAdd('bs', SK_VAR, TypeAdd(TYK_SLICE, '', 12, 4, False, PDT_UINT8, -1));
  E := ExprParseString('string(bs)');
  StringAssert('string(bs) est EK_CONVERT', ExprPool[E].Kind = EK_CONVERT);
  StringAssert('string(bs) : TypeIdx = string', ExprPool[E].TypeIdx = PDT_STRING);

  SymAdd('s', SK_VAR, PDT_STRING);
  E := ExprParseString('[]byte(s)');
  StringAssert('[]byte(s) est EK_CONVERT', ExprPool[E].Kind = EK_CONVERT);
  StringAssert('[]byte(s) : TypeIdx TYK_SLICE d octets',
    (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_SLICE) And
    (TypeResolveAlias(TypeTab[ExprPool[E].TypeIdx].ElemTypeIdx) = PDT_UINT8));

  E := ExprParseString('[]rune(s)');
  StringAssert('[]rune(s) est EK_CONVERT', ExprPool[E].Kind = EK_CONVERT);

  { conversion vers un type NOMME utilisateur : "type Celsius float64" }
  SI := TypeAdd(TYK_FLOAT, 'Celsius', 8, 4, False, -1, -1);
  SymAdd('Celsius', SK_TYPE, SI);
  E := ExprParseString('Celsius(x)');
  StringAssert('Celsius(x) est EK_CONVERT', ExprPool[E].Kind = EK_CONVERT);
  StringAssert('Celsius(x) : TypeIdx = Celsius', ExprPool[E].TypeIdx = SI);

  { un nom predeclare masque localement N EST PLUS traite comme un      }
  { type - "var int = 5" puis "int" seul reste un IDENTIFIANT ordinaire.   }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('int', SK_VAR, PDT_INT);
  E := ExprParseString('int');
  StringAssert('"int" masque localement reste EK_IDENT (pas une conversion)',
    ExprPool[E].Kind = EK_IDENT);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 15 - GOROUTINES ET CANAUX (MODELE DE CONCURRENCE SIMPLIFIE) }
{ ============================================================ }
{ DECISION A FIGER (exigee explicitement par le roadmap lui-meme) :      }
{ MODELE COOPERATIF SIMPLIFIE, PAS des vrais threads Win32 (CreateThread).      }
{ Justification, pour reference future (TODO 21-23, ou cette decision              }
{ prendra reellement effet - aucun code executable n existe encore) :                 }
{   - Un vrai ordonnanceur M:N (comme le runtime Go reel) est hors de                    }
{     portee par construction (deja exclu par le roadmap lui-meme,                         }
{     "sans support d un vrai ordonnanceur preemptif dans ce compilateur").                    }
{   - Entre les deux options RESTANTES (cooperatif vs 1 thread Win32 reel                        }
{     par goroutine), le modele cooperatif est retenu car il evite toute                            }
{     synchronisation OS reelle (sections critiques, mutex Win32) pour la                              }
{     grande majorite des cas - un seul thread d execution, les                                           }
{     goroutines cedent explicitement le controle SEULEMENT aux points de                                     }
{     blocage reels de Go (envoi/reception de canal, "select" bloquant) -                                        }
{     coherent avec la discipline de simplification DEJA appliquee partout                                          }
{     ailleurs dans ce projet (pas de vrai GC, pas de vraie itable Go                                                   }
{     complete, TODO 10, etc.).                                                                                            }
{   - Contrepartie ACCEPTEE : un vrai parallelisme MULTI-CŒUR n est pas                                                       }
{     reproduit (toutes les "goroutines" s executent en serie, jamais                                                            }
{     simultanement) - documente comme limitation, sans consequence pour                                                            }
{     des programmes Go CORRECTS qui utilisent les canaux pour la                                                                       }
{     SYNCHRONISATION (et non pour esperer un vrai gain de performance                                                                     }
{     par parallelisme, hors de portee de toute facon pour un compilateur                                                                     }
{     de cette envergure).                                                                                                                       }
{ CONSEQUENCE CONCRETE pour CE TODO (analyse/syntaxe uniquement, aucun                       }
{ codegen n existe encore) : aucune primitive de synchronisation Win32                          }
{ (section critique, mutex, WaitGroup) n est necessaire ici - la clause                            }
{ "sync minimal SEULEMENT si le modele a threads reels est retenu" du                                 }
{ roadmap est donc SANS OBJET, exactement comme le roadmap l anticipait.                                 }

{ ParseGoStmt : "go" Expression - lance une "goroutine" (analyse            }
{ identique a "defer", TODO 08 : accepte N IMPORTE QUELLE expression              }
{ sans verifier qu elle est reellement un appel - la regle Go reelle              }
{ l exige, mais la verifier ici dupliquerait un travail qui appartient                }
{ de toute facon au TODO 19, sans qu aucun code genere n existe pour lui               }
{ donner un sens concret pour l instant).                                                }
Function ParseGoStmt: Integer;
Var N: Integer;
Begin
  PPAdvance;   { go }
  N := StmtNew(STK_GO);
  StmtPool[N].Left := ParseExpr;
  ParseGoStmt := N;
End;

{ ParseChanType : "chan" (deja consomme par l appelant) suivi              }
{ optionnellement de "<-" (envoi seulement, "chan<- T") puis du type           }
{ d element - la forme "<-chan T" (reception seulement) est geree            }
{ SEPAREMENT par ParseTypeExpr (le "<-" y precede "chan" au lieu de le             }
{ suivre). Represente comme un simple pointeur (4 octets) vers une                 }
{ structure de canal runtime, meme convention que map/slice/interface                 }
{ (la representation memoire EXACTE est un sujet de generation de code,                 }
{ TODO 21+).                                                                              }
Function ParseChanType: Integer;
Var ElemT, NewIdx : Integer;
Begin
  PPMatch('<-');
  ElemT := ParseTypeExpr;
  NewIdx := TypeAdd(TYK_CHAN, '', 4, 4, False, ElemT, -1);
  ParseChanType := NewIdx;
End;

{ ParseSelectCaseClause : UNE clause "case" de select - son en-tete       }
{ DOIT etre soit un ENVOI (STK_SEND, "ch <- v"), soit une RECEPTION              }
{ (une expression EK_RECV nue "<-ch", ou affectee/declaree via "v :=            }
{ <-ch"/"v, ok := <-ch") - ParseSimpleStmt (TODO 07, deja generique)              }
{ suffit a TOUT parser correctement ; cette fonction se contente de                  }
{ VERIFIER APRES COUP que le resultat a bien l une de ces deux formes,                  }
{ rejetant tout le reste (Go n autorise RIEN d autre en tete de "case"               }
{ de select). Reutilise CaseClausePool (TODO 07) comme le switch, mais                  }
{ via son nouveau champ HeaderStmt plutot que ExprFirst/ExprCount (qui                  }
{ n ont pas de sens ici : un select n a pas de "valeurs de case", juste                  }
{ UNE operation de canal par clause).                                                       }
{ TODO 21 : BodyStart/BodyCnt souffrent du MEME bogue d entrelacement    }
{ que ParseBlock/ParseCaseClause (voir leurs propres notes) - corrige avec  }
{ le MEME remede (tampon local puis push en bloc). }
Function ParseSelectCaseClause: Integer;
Const MAX_SELECTBODY_BUF = 128;
Var
  C, BodyStart, BodyCnt, SIdx, HeaderStmt, FirstArgIdx, I : Integer;
  IsDefault, HeaderOk : Boolean;
  BodyBuf : Array[0..MAX_SELECTBODY_BUF - 1] Of Integer;
Begin
  SymEnterScope;
  IsDefault := False;
  HeaderStmt := -1;

  If PPMatch('case') Then
  Begin
    HeaderStmt := ParseSimpleStmt;
    HeaderOk := StmtPool[HeaderStmt].Kind = STK_SEND;
    If (Not HeaderOk) And (StmtPool[HeaderStmt].Kind = STK_EXPR) Then
      HeaderOk := ExprPool[StmtPool[HeaderStmt].Left].Kind = EK_RECV;
    If (Not HeaderOk) And ((StmtPool[HeaderStmt].Kind = STK_SHORTVAR) Or
       (StmtPool[HeaderStmt].Kind = STK_ASSIGN)) And
       (StmtPool[HeaderStmt].ArgCount >= 1) Then
    Begin
      FirstArgIdx := StmtPool[HeaderStmt].ArgFirst;
      HeaderOk := ExprPool[StmtArgPool2[FirstArgIdx]].Kind = EK_RECV;
    End;
    If Not HeaderOk Then
      FatalError('en-tete de "case" de "select" invalide (un envoi ou ' +
        'une reception de canal est attendu)');
  End
  Else If PPMatch('default') Then
    IsDefault := True
  Else
    FatalError('"case" ou "default" attendu dans "select"');

  If Not PPMatch(':') Then
    FatalError('":" attendu apres "case"/"default"');

  PPSkipSemis;
  BodyCnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) And
        (Not ((PPKind = TOK_IDENT) And ((PPVal = 'case') Or (PPVal = 'default')))) Do
  Begin
    SIdx := ParseStatement;
    If BodyCnt < MAX_SELECTBODY_BUF Then
    Begin
      BodyBuf[BodyCnt] := SIdx;
      Inc(BodyCnt);
    End
    Else
      WarnMsg('corps de "case" (select) trop grand pour le tampon local (MAX_SELECTBODY_BUF), TODO 21');
    PPSkipSemis;
  End;

  SymLeaveScope;

  BodyStart := StmtArgCount;
  For I := 0 To BodyCnt - 1 Do
    StmtArgPush(BodyBuf[I], -1, '');

  C := CaseClauseNew;
  CaseClausePool[C].IsDefault  := IsDefault;
  CaseClausePool[C].HeaderStmt := HeaderStmt;
  CaseClausePool[C].BodyFirst  := BodyStart;
  CaseClausePool[C].BodyCount  := BodyCnt;
  ParseSelectCaseClause := C;
End;

{ ParseSelectStmt : mot-cle "select", accolade ouvrante, une ou            }
{ plusieurs clauses case/default, accolade fermante - structurellement           }
{ un "switch" sans tag ni Init (TODO 07) dont chaque clause a une                }
{ grammaire d en-tete differente (imposee par ParseSelectCaseClause               }
{ ci-dessus) plutot qu une liste d expressions - reutilise donc                        }
{ CaseClausePool de la meme facon (ArgFirst/ArgCount = plage de                            }
{ clauses).                                                                                }
Function ParseSelectStmt: Integer;
Var N, ArgStart, Cnt : Integer;
Begin
  PPAdvance;   { select }
  If Not PPMatch('{') Then
    FatalError('accolade ouvrante attendue apres "select"');
  PPSkipSemis;

  ArgStart := CaseClauseCount;
  Cnt := 0;
  While (Not PPAtEnd) And (Not PPIsOp('}')) Do
  Begin
    ParseSelectCaseClause;
    Inc(Cnt);
  End;
  If Not PPMatch('}') Then
    FatalError('accolade fermante attendue a la fin du "select"');

  N := StmtNew(STK_SELECT);
  StmtPool[N].ArgFirst := ArgStart;
  StmtPool[N].ArgCount := Cnt;
  ParseSelectStmt := N;
End;

{ ------------------------------------------------------------ }
{ ChannelSelfTest : type canal (bidirectionnel + les deux formes    }
{ directionnelles), make(chan T[, Cap]), envoi, reception,             }
{ comma-ok reception, close(ch), instruction go, select avec               }
{ envoi/reception/comma-ok/default.                                            }
{ ------------------------------------------------------------ }

Procedure ChannelAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ChannelSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ChannelSelfTest;
Var
  TIdx, SI, E, N, C0 : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { type canal bidirectionnel }
  FuncParseTopLevel('package main' + Chr(10) + 'var Ch chan int');
  SI := SymFind('Ch');
  ChannelAssert('Ch declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  ChannelAssert('Ch : TYK_CHAN', TypeTab[TIdx].Kind = TYK_CHAN);
  ChannelAssert('Ch : element int', TypeTab[TIdx].ElemTypeIdx = PDT_INT);

  { formes directionnelles : "<-chan int" et "chan<- int" }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'var RecvOnly <-chan int' + Chr(10) + 'var SendOnly chan<- int');
  SI := SymFind('RecvOnly');
  ChannelAssert('RecvOnly : TYK_CHAN (direction non conservee)',
    TypeTab[SymTab[SI].TypeIdx].Kind = TYK_CHAN);
  SI := SymFind('SendOnly');
  ChannelAssert('SendOnly : TYK_CHAN (direction non conservee)',
    TypeTab[SymTab[SI].TypeIdx].Kind = TYK_CHAN);

  { make(chan int) et make(chan int, 10) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('make(chan int)');
  ChannelAssert('make(chan int) : TypeIdx TYK_CHAN',
    TypeTab[ExprPool[E].TypeIdx].Kind = TYK_CHAN);
  E := ExprParseString('make(chan int, 10)');
  ChannelAssert('make(chan int, 10) : 1 argument (Cap)', ExprPool[E].ArgCount = 1);

  { envoi et reception }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  SymAdd('ch', SK_VAR, TypeAdd(TYK_CHAN, '', 4, 4, False, PDT_INT, -1));
  N := StmtParseString('ch <- 5');
  ChannelAssert('ch <- 5 est STK_SEND', StmtPool[N].Kind = STK_SEND);

  E := ExprParseString('<-ch');
  ChannelAssert('<-ch est EK_RECV', ExprPool[E].Kind = EK_RECV);
  ChannelAssert('<-ch : TypeIdx = int (element du canal)',
    ExprPool[E].TypeIdx = PDT_INT);

  { comma-ok reception : v, ok := <-ch }
  N := StmtParseString('v, ok := <-ch');
  ChannelAssert('v, ok := <-ch est STK_SHORTVAR', StmtPool[N].Kind = STK_SHORTVAR);
  ChannelAssert('comma-ok reception : 2 entrees', StmtPool[N].ArgCount = 2);
  SI := SymFind('v');
  ChannelAssert('v : type int (element du canal)',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_INT));
  SI := SymFind('ok');
  ChannelAssert('ok : type bool', (SI >= 0) And (SymTab[SI].TypeIdx = PDT_BOOL));

  { close(ch) }
  E := ExprParseString('close(ch)');
  ChannelAssert('close(ch) est EK_CALL', ExprPool[E].Kind = EK_CALL);

  { instruction go }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Worker() {' + Chr(10) + '}' + Chr(10) +
    'func F() {' + Chr(10) + '	go Worker()' + Chr(10) + '}');
  ChannelAssert('go Worker() analyse sans erreur', ErrorCount = 0);

  { select avec envoi/reception/comma-ok/default }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(ch1, ch2 chan int) {' + Chr(10) +
    '	select {' + Chr(10) +
    '	case v := <-ch1:' + Chr(10) + '		_ = v' + Chr(10) +
    '	case ch2 <- 1:' + Chr(10) +
    '	case v2, ok := <-ch1:' + Chr(10) +
    '		_ = v2' + Chr(10) + '		_ = ok' + Chr(10) +
    '	default:' + Chr(10) + '	}' + Chr(10) + '}');
  ChannelAssert('select a 4 branches analyse sans erreur', ErrorCount = 0);

  N := StmtParseString('select {' + Chr(10) +
    'case v := <-ch:' + Chr(10) + '	_ = v' + Chr(10) +
    'default:' + Chr(10) + '}');
  ChannelAssert('select est STK_SELECT', StmtPool[N].Kind = STK_SELECT);
  ChannelAssert('select : 2 clauses', StmtPool[N].ArgCount = 2);
  C0 := StmtPool[N].ArgFirst;
  ChannelAssert('1ere clause : pas "default"', Not CaseClausePool[C0].IsDefault);
  ChannelAssert('1ere clause : HeaderStmt resolu', CaseClausePool[C0].HeaderStmt >= 0);
  ChannelAssert('2e clause : "default"', CaseClausePool[C0 + 1].IsDefault);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 16 - DEFER, PANIC ET RECOVER                             }
{ ============================================================ }
{ Le plus etroit des TODO de ce fichier jusqu ici en termes de code            }
{ NEUF : "defer" existe DEJA depuis le TODO 08 (STK_DEFER, accepte                 }
{ n importe quelle expression sans verifier qu elle est un appel,                    }
{ exactement la meme portee que "go" au TODO 15) ; "panic(v)"/                             }
{ "recover()" sont DEJA des identificateurs predeclares classifies                        }
{ comme fonctions integrees depuis le TODO 03 (BI_PANIC/BI_RECOVER) et                       }
{ n ont, syntaxiquement, RIEN de special par rapport a un appel                                 }
{ ordinaire ("panic(x)" est deja parse comme "len(x)" ou "close(ch)"                               }
{ l ont toujours ete) - seule l INFERENCE DE TYPE de "recover()"                                      }
{ (retourne "any", comme la valeur passee a panic) manquait reellement.                                  }
{                                                                          }
{ TOUT le reste du roadmap de ce TODO est un sujet D EXECUTION pure,          }
{ explicitement hors de portee de l analyse/du parsing tant qu aucun               }
{ backend n existe (TODO 21+/23), meme discipline que le modele de                     }
{ concurrence du TODO 15, la semantique valeur/reference du TODO 11, et                   }
{ l absence de GC du TODO 13 :                                                              }
{   - La pile de defer PAR APPEL et son deroulement LIFO (normal OU par            }
{     panique) n existent qu au moment ou une fonction s execute                          }
{     REELLEMENT - rien a construire ici sans generateur de code.                              }
{   - Le deroulement de pile par panic() (executer chaque defer traverse            }
{     jusqu a un recover(), sinon jusqu au sommet avec code de sortie                     }
{     non nul) est un mecanisme runtime a part entiere (_GORT_, TODO 23).                    }
{   - Les 5 paniques RUNTIME IMPLICITES du roadmap (indice hors bornes,                  }
{     dereference de pointeur nil, assertion de type ratee, division                        }
{     entiere par zero, envoi sur canal ferme) necessitent chacune une                         }
{     VERIFICATION generee AU POINT D UTILISATION (ex. une comparaison                             }
{     avant chaque acces indexe) - impossible a emettre sans generateur                               }
{     de code ; la SEULE de ces 5 verifications deja possible AVANT tout               }
{     backend est la division par une constante ZERO connue au moment                     }
{     de la compilation, deja detectee par ConstEvalBinOp depuis le                          }
{     TODO 05 (une expression comme "1/0" est deja un vrai echec de                            }
{     compilation, pas une panique a l execution qui n existe pas encore).                        }
{   - La validite de recover() (n a d effet que si appelee directement                  }
{     depuis une fonction differee en cours de deroulement de panique)                         }
{     est elle-meme une propriete D EXECUTION, pas une propriete                                  }
{     STATIQUE du code environnant - meme le vrai compilateur Go ne le                            }
{     rejette PAS a la compilation (un recover() hors contexte est un                             }
{     simple no-op silencieux a l execution) ; aucune verification a                              }
{     ajouter ici, ni maintenant ni au TODO 19.                                                       }

{ ------------------------------------------------------------ }
{ DeferPanicSelfTest : plusieurs defer dans une fonction (ordre            }
{ textuel de declaration, LIFO reste un sujet d execution),               }
{ panic(v), recover() et son type "any", et l idiome CANONIQUE               }
{ Go "recover et convertir en erreur" via une fermeture differee               }
{ qui modifie un RESULTAT NOMME de la fonction englobante.                       }
{ ------------------------------------------------------------ }

Procedure DeferPanicAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('DeferPanicSelfTest: ' + Label_ + ' a echoue');
End;

Procedure DeferPanicSelfTest;
Var
  E : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { recover() : type "any" }
  E := ExprParseString('recover()');
  DeferPanicAssert('recover() est EK_CALL', ExprPool[E].Kind = EK_CALL);
  DeferPanicAssert('recover() : TypeIdx = any', ExprPool[E].TypeIdx = PDT_ANY);

  { panic(v) : appel ordinaire, aucune inference speciale attendue }
  SymAdd('v', SK_VAR, PDT_STRING);
  E := ExprParseString('panic(v)');
  DeferPanicAssert('panic(v) est EK_CALL', ExprPool[E].Kind = EK_CALL);
  DeferPanicAssert('panic(v) : 1 argument', ExprPool[E].ArgCount = 1);

  { plusieurs defer + panic dans une meme fonction }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F(fail bool) {' + Chr(10) +
    '	defer Close1()' + Chr(10) +
    '	defer Close2()' + Chr(10) +
    '	if fail {' + Chr(10) + '		panic("erreur")' + Chr(10) + '	}' + Chr(10) +
    '}');
  DeferPanicAssert('plusieurs defer + panic analyses sans erreur', ErrorCount = 0);

  { idiome canonique : recover() dans une fermeture differee QUI MODIFIE  }
  { un RESULTAT NOMME de la fonction englobante ("named return" +               }
  { fermeture, TODO 08) - LE pattern Go standard de conversion d une                  }
  { panique en erreur retournee normalement par la fonction.                              }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Safe() (err error) {' + Chr(10) +
    '	defer func() {' + Chr(10) +
    '		if r := recover(); r != nil {' + Chr(10) +
    '			err = r' + Chr(10) +
    '		}' + Chr(10) +
    '	}()' + Chr(10) +
    '	panic("boom")' + Chr(10) +
    '}');
  DeferPanicAssert('idiome recover-vers-erreur analyse sans erreur '+
    '(fermeture modifiant un resultat nomme)', ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 17 - INTERFACE ERROR ET IDIOME DE GESTION D ERREURS      }
{ ============================================================ }
{ "L idiome dominant" du roadmap lui-meme (retours multiples suivis          }
{ d une verification immediate de l erreur) est explicitement decrit               }
{ comme "une simple                                                                       }
{ consequence des retours multiples (TODO 08) et des interfaces (TODO           }
{ 10), pas un mecanisme special du langage" - et en verifiant si c etait                 }
{ VRAIMENT deja le cas, un bogue REEL est apparu : "n, err := F()" (une                    }
{ fonction a DEUX resultats, destructuree sur DEUX noms) ne poussait                          }
{ auparavant qu UNE seule entree dans StmtArgPool (la boucle generique                          }
{ "For I := 0 To VCount-1" ne fait qu UN tour quand VCount=1, meme si                               }
{ TCount=2) tout en annoncant ArgCount=TCount=2 - "err" ne devenait                                    }
{ JAMAIS une variable declaree. Invisible avant ce TODO car aucun test                                    }
{ anterieur n avait exerce use fonction a plusieurs VRAIS resultats                                          }
{ destructuree par ":="/"=" (TODO 08 ne testait que "return a, b" DANS                                          }
{ une fonction, jamais la RECEPTION cote appelant). Corrige en donnant                                             }
{ a EK_CALL un Extra=TypeIdx de la signature TYK_FUNC du callee (quand                                                 }
{ resolue) et en ajoutant, dans ParseSimpleStmt, un troisieme cas                                                        }
{ (parallele au comma-ok) qui detecte "UNE expression appelee, dont la                                                    }
{ signature declaree a EXACTEMENT TCount resultats" et assigne a CHAQUE                                                       }
{ nom le VRAI type de sa position - la meme correction beneficie aussi                                                            }
{ a TOUTE fonction multi-retour, pas seulement a l idiome erreur.                                                                     }
{                                                                          }
{ Le reste de ce TODO complete l interface predeclaree "error" (deja               }
{ un TYK_ERROR distinct depuis le TODO 04, mais SANS aucune methode              }
{ enregistree avant ce point - la methode "Error" est desormais                       }
{ synthetisee dans TypeInit) et reconnait par NOM QUALIFIE les deux                       }
{ fonctions bibliotheque explicitement demandees ici (errors.New,                            }
{ fmt.Errorf) - PAS le reste de fmt/errors, reserve au TODO 20. Le               }
{ deballage errors.Is/errors.As et le verbe %w restent EXPLICITEMENT             }
{ hors de portee (roadmap lui-meme) - %w n est de toute facon qu un               }
{ detail de CONTENU d une chaine de format, jamais inspectee par ce                  }
{ compilateur (une chaine de format est juste une TString ordinaire).                     }

{ ------------------------------------------------------------ }
{ ErrorSelfTest : err.Error() via l interface predeclaree, un       }
{ type utilisateur satisfaisant structurellement "error" via sa          }
{ propre methode Error(), errors.New/fmt.Errorf, et LE bogue           }
{ corrige (retours multiples destructures, avec et sans le nom            }
{ "err" specifiquement - la correction est generale).                       }
{ ------------------------------------------------------------ }

Procedure ErrorAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('ErrorSelfTest: ' + Label_ + ' a echoue');
End;

Procedure ErrorSelfTest;
Var
  E, N, SI, TIdx, FT, RFirst2 : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { err.Error() via l interface predeclaree "error" }
  SymAdd('err', SK_VAR, PDT_ERROR);
  E := ExprParseString('err.Error()');
  ErrorAssert('err.Error() est EK_CALL', ExprPool[E].Kind = EK_CALL);
  ErrorAssert('err.Error() : TypeIdx = string', ExprPool[E].TypeIdx = PDT_STRING);

  { errors.New(msg) et fmt.Errorf(...) }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  E := ExprParseString('errors.New("echec")');
  ErrorAssert('errors.New(...) : TypeIdx = error', ExprPool[E].TypeIdx = PDT_ERROR);
  E := ExprParseString('fmt.Errorf("echec: %d", 42)');
  ErrorAssert('fmt.Errorf(...) : TypeIdx = error', ExprPool[E].TypeIdx = PDT_ERROR);

  { type utilisateur satisfaisant "error" via sa propre methode Error() }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type MyError struct {' + Chr(10) + '	Msg string' + Chr(10) + '}' + Chr(10) +
    'func (e *MyError) Error() string {' + Chr(10) +
    '	return e.Msg' + Chr(10) + '}');
  SI := SymFind('MyError');
  ErrorAssert('MyError declaree', SI >= 0);
  TIdx := SymTab[SI].TypeIdx;
  ErrorAssert('MyError.Error() resolue via MethodFind (TODO 09)',
    MethodFind(TIdx, 'Error') >= 0);

  { LE bogue corrige : retours multiples destructures via ":=" ("n, err   }
  { := F()", fonction a 2 resultats non nommes) - err DOIT devenir une            }
  { variable REELLEMENT declaree avec le VRAI type error (le bogue la               }
  { laissait totalement non declaree, seul "n" recevait une entree).                    }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FT := TypeAdd(TYK_FUNC, '', 4, 4, False, -1, -1);
  RFirst2 := FieldPoolCount;
  FieldPoolAdd('', PDT_INT, False);
  FieldPoolAdd('', PDT_ERROR, False);
  TypeTab[FT].ResultFirst := RFirst2;
  TypeTab[FT].ResultCount := 2;
  SymAdd('F', SK_FUNC, FT);

  N := StmtParseString('n, err := F()');
  ErrorAssert('n, err := F() est STK_SHORTVAR', StmtPool[N].Kind = STK_SHORTVAR);
  ErrorAssert('n, err := F() : 2 entrees (le bogue en laissait 1)',
    StmtPool[N].ArgCount = 2);
  SI := SymFind('n');
  ErrorAssert('n declaree avec le type int',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_INT));
  SI := SymFind('err');
  ErrorAssert('err declaree avec le type error (LE bogue corrige)',
    (SI >= 0) And (SymTab[SI].TypeIdx = PDT_ERROR));

  { meme correction via l affectation simple "=" (noms deja declares) }
  N := StmtParseString('n, err = F()');
  ErrorAssert('n, err = F() est STK_ASSIGN', StmtPool[N].Kind = STK_ASSIGN);
  ErrorAssert('n, err = F() : 2 entrees (le bogue en laissait 1)',
    StmtPool[N].ArgCount = 2);

  { idiome dominant complet du roadmap lui-meme, dans un contexte de       }
  { fonction REEL (declaration + appel + verification de l erreur), pas         }
  { juste des expressions isolees comme les tests precedents. }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func F() (int, error) {' + Chr(10) +
    '	return 0, nil' + Chr(10) + '}' + Chr(10) +
    'func G() {' + Chr(10) +
    '	n, err := F()' + Chr(10) +
    '	if err != nil {' + Chr(10) + '		return' + Chr(10) + '	}' + Chr(10) +
    '	_ = n' + Chr(10) + '}');
  ErrorAssert('idiome dominant complet analyse sans erreur', ErrorCount = 0);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ============================================================ }
{ TODO 18 - PACKAGES ET IMPORTS (MODELE MONO-FICHIER SIMPLIFIE) }
{ ============================================================ }
{ Le plus etroit des TODO de ce fichier en termes de NOUVELLES               }
{ constructions syntaxiques (aucune - "package"/"import" existent DEJA          }
{ depuis le TODO 05, comme SkipImportDecl le documentait deja lui-meme :             }
{ "la vraie resolution de package est le sujet du TODO 18") : ce TODO NE          }
{ FAIT QUE DURCIR trois REGLES deja identifiees mais non appliquees                    }
{ jusqu ici -                                                                              }
{   1. "package main" devient OBLIGATOIRE (avant : n importe quel nom              }
{      de package etait silencieusement accepte).                                            }
{   2. Chaque import est verifie contre une TABLE FIXE de paquets                             }
{      reellement cables (avant : SkipImportDecl avalait n importe quoi                  }
{      sans jamais regarder le contenu de la chaine importee).                                   }
{   3. "func main" devient OBLIGATOIRE - mais UNIQUEMENT sur le VRAI                                  }
{      fichier source compile par la CLI (Run), PAS a l interieur de                                    }
{      ParseFileTopLevel elle-meme, qui reste PARTAGEE par la quasi-                                        }
{      totalite des auto-tests depuis le TODO 08 (chacun declarant ses                                        }
{      propres fonctions de test, jamais nommees "main") - rendre cette                                          }
{      regle obligatoire au niveau partage aurait fait Halt() la quasi-                                             }
{      totalite des auto-tests existants de ce fichier.                                                                }
{ La regle d EXPORT (majuscule = visible hors package) est fournie                            }
{ (IsExported) mais reste SANS AUCUNE consequence pratique aujourd hui                          }
{ (roadmap lui-meme) : ce compilateur est mono-fichier/mono-paquet, rien              }
{ ne peut jamais etre "hors du package" pour de vrai ici.                                        }

{ ------------------------------------------------------------ }
{ PackageSelfTest : chemins d ACCEPTATION uniquement ("package main"      }
{ + import(s) CONNU(S) analyses sans erreur) et IsExported. Les CAS DE          }
{ REJET (mauvais nom de package, import inconnu, "func main" absent)               }
{ ne peuvent PAS etre exerces ici : FatalError appelle Halt(), ce qui                  }
{ arreterait tout le programme (auto-tests suivants ET compilation                        }
{ reelle) au lieu de se contenter d echouer CETTE assertion - ces trois                      }
{ regles sont donc verifiees seulement par LECTURE DU CODE (ci-dessus)                          }
{ plutot que par un auto-test qui les declencherait reellement.                                    }
{ ------------------------------------------------------------ }

Procedure PackageAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PackageSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PackageSelfTest;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { "package main" accepte, avec un import CONNU }
  FuncParseTopLevel('package main' + Chr(10) + 'import "fmt"' + Chr(10) +
    'func F() {' + Chr(10) + '}');
  PackageAssert('package main + import "fmt" analyses sans erreur',
    ErrorCount = 0);

  { import CONNU sous forme de bloc parenthese }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) + 'import (' + Chr(10) +
    '	"fmt"' + Chr(10) + '	"strings"' + Chr(10) + ')' + Chr(10) +
    'func F() {' + Chr(10) + '}');
  PackageAssert('bloc import avec 2 paquets connus analyse sans erreur',
    ErrorCount = 0);

  { IsExported : majuscule = exporte, minuscule = prive }
  PackageAssert('"Foo" est exporte (majuscule)', IsExported('Foo'));
  PackageAssert('"foo" n''est PAS exporte (minuscule)', Not IsExported('foo'));
  PackageAssert('chaine vide n''est PAS exportee', Not IsExported(''));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ SemanticSelfTest (TODO 19) : passe prealable de resolution        }
{ (references AVANT declaration textuelle), TypesAssignable/                }
{ TypeSatisfiesInterface (appeles DIRECTEMENT sur des TypeIdx                    }
{ construits a la main - plus precis qu un comptage de WarnMsg,                      }
{ silencieux par defaut ici puisque Opts.Warnings=False pendant TOUS             }
{ les auto-tests, ParseArgs n ayant pas encore ete appelee), et                          }
{ variable/import "declare et non utilise". Les CAS DE REJET (erreur              }
{ Go REELLE, "declared and not used") ne peuvent PAS etre exerces ICI              }
{ en mode strict (FatalError -> Halt(), meme limitation documentee que                  }
{ PackageSelfTest ci-dessus) - verifies separement sur des fichiers                        }
{ jetables via la VRAIE CLI (SAMPLES/GO/semantic.go pour le chemin                            }
{ d ACCEPTATION ; rejet confirme manuellement lors du developpement).                             }
{ Le chemin de rejet (variable/import inutilise) est verifie ICI en                                   }
{ inspectant DIRECTEMENT le drapeau "Used" (SymTab/ImportedPackages)                                       }
{ plutot qu en forcant Opts.Warnings pour observer WarnMsg s imprimer                                          }
{ (une premiere version faisait cela, mais WarnMsg ecrit REELLEMENT sur                                            }
{ la sortie standard des qu il est actif - polluant la sortie de CHAQUE                                                }
{ execution du compilateur, meme sans "-w" - corrige au moment meme du                                                    }
{ TODO 19, voir le journal de memoire pour le detail du bogue).                                                                }
{ ------------------------------------------------------------ }

Procedure SemanticAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('SemanticSelfTest: ' + Label_ + ' a echoue');
End;

Procedure SemanticSelfTest;
Var SI, T1, T2, TNamedA, TNamedB : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { reference AVANT declaration textuelle (TODO 19) : main() appelle F(),  }
  { declaree PLUS LOIN dans le fichier - illegal en Pascal (ordre textuel        }
  { obligatoire) mais LEGAL en Go entre declarations de haut niveau -             }
  { necessite PrescanTopLevelFuncs (passe prealable de signatures).                  }
  FuncParseTopLevel('package main' + Chr(10) +
    'func main() {' + Chr(10) +
    '	n, err := F("x")' + Chr(10) +
    '	_ = n' + Chr(10) + '	_ = err' + Chr(10) + '}' + Chr(10) +
    'func F(s string) (int, error) {' + Chr(10) +
    '	return 1, nil' + Chr(10) + '}');
  SemanticAssert('F (declaree APRES main) resolue via le pre-scan',
    SymFind('F') >= 0);
  SemanticAssert('F : SK_FUNC', SymTab[SymFind('F')].Kind = SK_FUNC);
  SemanticAssert('main et F toutes deux enregistrees (aucun doublon)',
    FuncDefCount = 2);
  SI := SymFind('err');
  SemanticAssert('"err" declare (via retours multiples de F, resolue en avance)',
    SI >= 0);
  SemanticAssert('"err" correctement type "error" (signature de F connue ' +
    'AVANT sa declaration textuelle)', SymTab[SI].TypeIdx = PDT_ERROR);

  { TypesAssignable : identite, best-effort sur type inconnu, rejet entre  }
  { types predeclares distincts. }
  SemanticAssert('int assignable a int (identite)',
    TypesAssignable(PDT_INT, PDT_INT));
  SemanticAssert('int NON assignable a string',
    Not TypesAssignable(PDT_INT, PDT_STRING));
  SemanticAssert('type encore inconnu (-1) toujours assignable (best-effort)',
    TypesAssignable(-1, PDT_INT) And TypesAssignable(PDT_INT, -1));

  { deux types COMPOSES ANONYMES ecrits separement ("*int" via deux appels  }
  { TypeAdd distincts, aucune canonicalisation) restent STRUCTURELLEMENT        }
  { identiques - assignables l un a l autre (TypesStructurallyEqual). }
  T1 := TypeAdd(TYK_POINTER, '', 4, 4, False, PDT_INT, -1);
  T2 := TypeAdd(TYK_POINTER, '', 4, 4, False, PDT_INT, -1);
  SemanticAssert('deux "*int" anonymes distincts (TypeIdx differents) restent ' +
    'assignables (type compose STRUCTUREL)', TypesAssignable(T1, T2));

  { deux types NOMMES distincts de MEME representation sous-jacente (ex.   }
  { "type Celsius float64" / "type Fahrenheit float64") NE sont PAS             }
  { assignables entre eux SANS conversion explicite - regle stricte de              }
  { Go que TODO 19 doit reproduire (contrairement a un simple alias). }
  TNamedA := TypeAdd(TYK_FLOAT, 'Celsius', 8, 8, False, -1, -1);
  TNamedB := TypeAdd(TYK_FLOAT, 'Fahrenheit', 8, 8, False, -1, -1);
  SemanticAssert('deux types NOMMES distincts (meme repr. sous-jacente) ' +
    'NE sont PAS assignables', Not TypesAssignable(TNamedA, TNamedB));

  { TypeSatisfiesInterface / assignation a une interface (TODO 10 direct) - }
  { un type struct SANS la methode exigee ne satisfait PAS l interface,           }
  { un type struct AVEC toutes les methodes exigees la satisfait. }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'type Shape interface {' + Chr(10) + '	Area() int' + Chr(10) + '}' + Chr(10) +
    'type Square struct {' + Chr(10) + '	Side int' + Chr(10) + '}' + Chr(10) +
    'func (s Square) Area() int {' + Chr(10) + '	return s.Side' + Chr(10) + '}' +
    Chr(10) + 'type Circle struct {' + Chr(10) + '	Radius int' + Chr(10) + '}');
  SemanticAssert('Square satisfait Shape (possede Area())',
    TypeSatisfiesInterface(SymTab[SymFind('Square')].TypeIdx,
      SymTab[SymFind('Shape')].TypeIdx));
  SemanticAssert('Circle NE satisfait PAS Shape (Area() absente)',
    Not TypeSatisfiesInterface(SymTab[SymFind('Circle')].TypeIdx,
      SymTab[SymFind('Shape')].TypeIdx));

  { variable/import declares et non utilises (TODO 19) : verifie ICI      }
  { directement le drapeau "Used" (SymTab/ImportedPackages) plutot que de       }
  { forcer Opts.Warnings=True pour observer WarnMsg - celui-ci IMPRIME             }
  { reellement sur la sortie standard des qu il est actif, ce qui                        }
  { polluerait la sortie de CHAQUE execution du compilateur (meme sans                       }
  { "-w" : WarnMsg ecrit AVANT que WarnCount ne soit lu/remis a zero) - la                      }
  { regle est neanmoins bel et bien EVALUEE ici (seul son WarnMsg final                              }
  { reste silencieux, Opts.Warnings=False par defaut pendant les auto-tests). }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'import "fmt"' + Chr(10) +
    'func main() {' + Chr(10) + '	x := 1' + Chr(10) + '	_ = x' + Chr(10) +
    '	fmt.Println("hi")' + Chr(10) + '}');
  SemanticAssert('variable "x" (utilisee via "_ = x") marquee Used',
    SymTab[SymFind('x')].Used);
  SemanticAssert('import "fmt" (reference via fmt.Println) marque Used',
    (ImportedCount = 1) And (ImportedPackages[0].Name = 'fmt') And
    ImportedPackages[0].Used);

  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'import "strings"' + Chr(10) +
    'func main() {' + Chr(10) + '	y := 1' + Chr(10) + '}');
  SemanticAssert('variable "y" (jamais lue) reste NON marquee Used',
    Not SymTab[SymFind('y')].Used);
  SemanticAssert('import "strings" (jamais reference) reste NON marque Used',
    (ImportedCount = 1) And (ImportedPackages[0].Name = 'strings') And
    (Not ImportedPackages[0].Used));

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ StdlibSelfTest (TODO 20) : bibliotheque standard minimale        }
{ (fmt/errors/strings/strconv/os/math), reconnue PAR NOM QUALIFIE            }
{ via StdlibTab/ResolveSelectorType - verifie a la fois le TYPAGE                 }
{ direct (appel simple, valeur SLK_VALUE) et, surtout, que le                          }
{ mecanisme GENERIQUE de retours multiples (TODO 08/17) fonctionne                        }
{ desormais aussi pour un appel de bibliotheque standard                                     }
{ (strconv.Atoi) exactement comme pour une fonction utilisateur -                                }
{ c est le VRAI bug latent (err jamais declaree) trouve en concevant                                 }
{ ce TODO, corrige par construction une fois StdlibTab branche dans                                     }
{ ResolveSelectorType plutot que par un correctif specifique.                                                }
{ ------------------------------------------------------------ }

Procedure StdlibAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('StdlibSelfTest: ' + Label_ + ' a echoue');
End;

Procedure StdlibSelfTest;
Var SI: Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;

  { retours multiples (TODO 08/17/19) a travers un appel de           }
  { bibliotheque standard - "err" doit etre reellement declaree, avec       }
  { le type "error", exactement comme pour la fonction utilisateur Parse         }
  { de errors.go (TODO 17). C EST le bug que ce TODO corrige. }
  FuncParseTopLevel('package main' + Chr(10) +
    'import "strconv"' + Chr(10) +
    'func main() {' + Chr(10) +
    '	n, err := strconv.Atoi("42")' + Chr(10) +
    '	_ = n' + Chr(10) + '	_ = err' + Chr(10) + '}');
  SI := SymFind('err');
  StdlibAssert('"err" (strconv.Atoi) reellement declaree', SI >= 0);
  StdlibAssert('"err" (strconv.Atoi) correctement typee "error"',
    SymTab[SI].TypeIdx = PDT_ERROR);
  SI := SymFind('n');
  StdlibAssert('"n" (strconv.Atoi) correctement typee "int"',
    SymTab[SI].TypeIdx = PDT_INT);

  { appel simple (une seule valeur utile) : fmt.Sprintf, strings.ToUpper, }
  { math.Sqrt - chacun via le MEME mecanisme generique (EK_CALL.TypeIdx     }
  { = premier resultat declare). }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'import (' + Chr(10) + '	"fmt"' + Chr(10) + '	"strings"' + Chr(10) +
    '	"math"' + Chr(10) + ')' + Chr(10) +
    'func main() {' + Chr(10) +
    '	s := fmt.Sprintf("%d", 42)' + Chr(10) +
    '	u := strings.ToUpper(s)' + Chr(10) +
    '	r := math.Sqrt(4.0)' + Chr(10) +
    '	_ = u' + Chr(10) + '	_ = r' + Chr(10) + '}');
  StdlibAssert('fmt.Sprintf(...) : type string',
    SymTab[SymFind('s')].TypeIdx = PDT_STRING);
  StdlibAssert('strings.ToUpper(...) : type string',
    SymTab[SymFind('u')].TypeIdx = PDT_STRING);
  StdlibAssert('math.Sqrt(...) : type float64',
    SymTab[SymFind('r')].TypeIdx = PDT_FLOAT64);

  { valeurs (SLK_VALUE, jamais appelees) : os.Args/os.Stdout/          }
  { math.MaxInt32 - resolues directement par ResolveSelectorType sans        }
  { passer par ParseCallArgs (aucune parenthese). }
  SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'import (' + Chr(10) + '	"os"' + Chr(10) + '	"math"' + Chr(10) + ')' +
    Chr(10) + 'func main() {' + Chr(10) +
    '	a := os.Args' + Chr(10) + '	w := os.Stdout' + Chr(10) +
    '	m := math.MaxInt32' + Chr(10) +
    '	_ = a' + Chr(10) + '	_ = w' + Chr(10) + '	_ = m' + Chr(10) + '}');
  StdlibAssert('os.Args : slice de string (TYK_SLICE, element string)',
    (TypeTab[SymTab[SymFind('a')].TypeIdx].Kind = TYK_SLICE) And
    (TypeTab[SymTab[SymFind('a')].TypeIdx].ElemTypeIdx = PDT_STRING));
  StdlibAssert('os.Stdout : type coherent (non -1)',
    SymTab[SymFind('w')].TypeIdx >= 0);
  StdlibAssert('math.MaxInt32 : type int32',
    SymTab[SymFind('m')].TypeIdx = PDT_INT32);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ TODO 21 - GENERATEUR DE CODE 80386 ET SORTIE .ASM                }
{ ------------------------------------------------------------ }
{ Contrairement a DELPHI.PAS/PERLCW32.PAS (memes projet, meme         }
{ inspiration architecturale - "miroir des GenXxx des autres            }
{ compilateurs", roadmap lui-meme) qui emettent l ASM DIRECTEMENT            }
{ pendant l analyse syntaxique (aucun AST, juste un curseur de jetons             }
{ PP) : GOCW32 possede DEJA un AST complet et reel (ExprPool/StmtPool/               }
{ TypeTab/SymTab/FuncDefPool, TODO 06-20) - ce generateur de code est                    }
{ donc un PARCOURS de cet AST (CompileExpr/CompileStmt, recursifs, un                       }
{ noeud a la fois) plutot qu un second parseur qui re-emettrait en                              }
{ parsant. La convention d appel/ecriture ASM elle-meme (segments                                  }
{ .386/.MODEL FLAT STDCALL, cadre EBP, EAX/EBX comme "registres de                                      }
{ travail" fixes pour toute expression binaire, Jcc materialisant un                                        }
{ Booleen 0/1 dans EAX plutot qu un flag brut, LabelGen sequentiel,                                             }
{ E/S console via l API Win32 GetStdHandle/WriteFile) REPREND fidelement                                            }
{ celle de DELPHI.PAS, seule l ABSENCE d AST y differe structurellement.                                                }
{                                                                                                                          }
{ PORTEE DE CE TODO (deliberement scindee, meme discipline "arret          }
{ propre documente" que chaque TODO precedent depuis le TODO 05) :             }
{ litteraux entier/booleen/rune/chaine/nil, variables locales ET               }
{ globales (chargement/stockage), operateurs binaires/unaires ENTIERS               }
{ (+ court-circuit && ||), adresse-de/dereference, if/for(3-clauses ou               }
{ infini), bloc, expression-instruction, affectation/:=  A UNE SEULE                    }
{ CIBLE, incdec, return (0 OU 1 valeur), appel DIRECT a une fonction                        }
{ utilisateur A UN SEUL RESULTAT, et fmt.Println/Print AVEC UN SEUL                            }
{ ARGUMENT DE TYPE CHAINE (assez pour hello.go). PAS couvert ici (arret                            }
{ propre, FatalError explicite) : flottants (arithmetique ET litteraux -                              }
{ necessiterait le jeu d instructions x87, une famille entiere en plus),                                  }
{ retours MULTIPLES (l ABI a "pointeur de sortie cache" du roadmap est                                        }
{ documentee mais PAS implementee ici, risque de bug trop eleve sous                                              }
{ contrainte de temps pour une premiere version), structs/methodes/                                                   }
{ interfaces/slices/maps/tableaux, fermetures, goroutines/canaux,                                                         }
{ defer/panic/recover, switch/for-range, et tout fmt./strings./etc au                                                        }
{ dela du seul fmt.Println/Print(chaine unique). Chacun de ces gaps               }
{ reste un FatalError CLAIR (pas un plantage/silence) - TODO 22/23                {finalisera}
{ le veritable backend .OBJ/.EXE et pourra alors etendre cette couverture.               }

Type
  TByte8 = Array[0..7] Of Byte;   { extension flottants : octets bruts d un Double }

Var
  CgOutF      : Text;
  CgOutOpen   : Boolean;
  CgLabelSeq  : Integer;
  CurRetLabel : TString;   { label de l epilogue PARTAGE de la fonction/  }
                             { methode EN COURS de generation - "return"       }
                             { emet un JMP vers celui-ci (meme principe que          }
                             { CurFuncSig, TODO 19 : sauvegarde/restauration            }
                             { autour d une fermeture imbriquee si un jour               }
                             { couverte).                                                    }
  CurGotoLabelPfx : TString;   { extension switch/goto : prefixe ASM UNIQUE   }
                                 { par fonction/methode EN COURS de generation      }
                                 { (positionne par CompileFuncDef/CompileMethodDef)          }
                                 { pour les etiquettes UTILISATEUR (STK_GOTO/                  }
                                 { STK_LABELED) - evite toute collision entre                     }
                                 { deux fonctions reutilisant le MEME nom                             }
                                 { d etiquette Go.                                                       }

  { Pool de chaines litterales (TODO 21) : chaque EK_STRINGLIT rencontre  }
  { pendant CgCollectStrings (parcours PREALABLE de TOUT le programme,           }
  { avant la moindre ligne .CODE) recoit une entree ICI (deduplication            }
  { PAR VALEUR - deux occurrences du meme texte partagent le meme label)             }
  { et son propre label _GOK_N ; CgStrPoolOfExpr[E] retient, pour CHAQUE                 }
  { noeud EK_STRINGLIT (index E dans ExprPool), l index dans CE pool -                       }
  { evite de dupliquer les octets ET de re-analyser le texte lors du                             }
  { VRAI passage de generation de code (CompileExpr n a plus qu a lire                              }
  { CgStrPoolOfExpr[E]).                                                                               }
  CgStrPool       : Array[0..MAX_STDLIB - 1] Of TString;
  CgStrCount      : Integer;
  CgStrPoolOfExpr : Array[0..MAX_EXPR - 1] Of Integer;

  { extension flottants (TODO 21) : meme principe EXACT que CgStrPool/    }
  { CgStrPoolOfExpr ci-dessus, mais pour chaque EK_FLOATLIT (deduplication            }
  { PAR VALEUR BINAIRE - Real, jamais une comparaison de texte, deux           }
  { litteraux qui s ecrivent differemment mais s evaluent a la MEME                    }
  { valeur IEEE754 partagent le meme label). }
  CgFloatPool       : Array[0..MAX_STDLIB - 1] Of Double;
  CgFloatCount      : Integer;
  CgFloatPoolOfExpr : Array[0..MAX_EXPR - 1] Of Integer;

Function IntToStrG(N: LongInt): TString;
Var S: TString;
Begin
  Str(N, S);
  IntToStrG := S;
End;

{ DblToBytes : extension flottants (TODO 21) - decompose un Double (IEEE   }
{ 754, 8 octets) en ses octets BRUTS (ordre PETIT-BOUTISTE, natif x86)          }
{ via un record variant (Case) - AUCUNE conversion textuelle (decimal-a-             }
{ binaire) requise, juste une relecture directe de la representation                    }
{ memoire deja produite par le compilateur FPC lui-meme pour "V". }
Procedure DblToBytes(V: Double; Var OutB: TByte8);
Type
  TDblBytes = Record
    Case Boolean Of
      True:  (D: Double);
      False: (B: TByte8);
  End;
Var Rec: TDblBytes; I: Integer;
Begin
  Rec.D := V;
  For I := 0 To 7 Do OutB[I] := Rec.B[I];
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
  CgLabelGen := ASM_PFX_LABEL + IntToStrG(CgLabelSeq);
End;

{ CgVarOperand : operande ASM texte pour LIRE/ECRIRE le symbole SI -    }
{ soit son NOM mangle (global, ASM_PFX_GVAR+Name, adresse par ETIQUETTE      }
{ dans .DATA), soit un decalage EBP (local/parametre/resultat nomme,           }
{ SymTab[SI].Offset deja calcule au moment meme de la declaration,                }
{ TODO 21 - voir SymAdd/RegisterFuncScopeSymbols) - AUCUN autre code               }
{ n a besoin de refaire ce calcul, un seul point de verite. }
Function CgVarOperand(SI: Integer): TString;
Begin
  If SymTab[SI].IsGlobal Then
    CgVarOperand := '[' + ASM_PFX_GVAR + SymTab[SI].Name + ']'
  Else If SymTab[SI].Offset >= 0 Then
    CgVarOperand := '[EBP+' + IntToStrG(SymTab[SI].Offset) + ']'
  Else
    CgVarOperand := '[EBP-' + IntToStrG(-SymTab[SI].Offset) + ']';
End;

{ EmitHeader : boilerplate Intel/MASM (.386, modele FLAT STDCALL,      }
{ imports Win32 necessaires au runtime minimal de ce TODO - E/S            }
{ console et sortie de processus uniquement ; alloc memoire/threads               }
{ restent reserves au vrai runtime du TODO 23) - meme dialecte que              }
{ DELPHI.PAS/PERLCW32.PAS (memes projet).                                            }
Procedure EmitHeader;
Begin
  EmitComment('GOCW32 - code genere (TODO 21) - NE PAS EDITER A LA MAIN');
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

{ EmitDataSeg : la section .DATA COMPLETE en une seule fois - variables  }
{ globales (parcours de SymTab, IsGlobal) puis pool de chaines            }
{ litterales (CgCollectStrings a deja tourne AVANT cet appel, voir              }
{ CompileProgram) - simplification documentee (TODO 21) : seuls les                }
{ globaux de representation ENTIERE/BOOLEENNE/POINTEUR (4 octets, la                    }
{ valeur constante REELLE si connue - TODO 05, ConstVal) sont           }
{ correctement initialises ; tout autre type de global (flottant,                          }
{ chaine, struct, etc.) recoit un simple "DD 0" (case a zero, PAS le                            }
{ VRAI initialiseur) - couverture complete de CES cas reste hors de                                 }
{ portee de ce TODO (arithmetique flottante/refs de chaines globales,                                   }
{ blocs struct, tous explicitement non couverts par ailleurs ici).                                          }
Procedure EmitDataSeg;
Var I, J, GSz, GWords: Integer; FB: TByte8;
Begin
  EmitRaw('.DATA');
  EmitRaw(ASM_PFX_RUNTIME + 'NEWLINE  DB 10');
  EmitRaw(ASM_PFX_RUNTIME + 'FSCRATCH  DD 0');   { extension flottants : voir EK_CONVERT }
  For I := 0 To SymCount - 1 Do
    If (SymTab[I].Kind = SK_VAR) And SymTab[I].IsGlobal Then
    Begin
      If (SymTab[I].TypeIdx >= 0) And (SymTab[I].TypeIdx < TypeCount) And
         (TypeTab[SymTab[I].TypeIdx].Kind In [TYK_INT, TYK_BOOL, TYK_POINTER]) Then
        EmitRaw(ASM_PFX_GVAR + SymTab[I].Name + '  DD ' +
          IntToStrG(SymTab[I].ConstVal.IntVal))
      Else
      Begin
        { extension flottants/structs : un global dont le TYPE reel occupe   }
        { PLUS de 4 octets (float64=8, ou un struct/tableau global -                 }
        { BOGUE REEL PRE-EXISTANT trouve en corrigeant les flottants,                        }
        { jamais exerce avant : "DD 0" seul (4 octets) sous-allouait TOUT             }
        { global de ce genre, corrompant silencieusement ce qui suit en                          }
        { .DATA) a besoin de PLUSIEURS lignes "DD 0" contigues - chaque                              }
        { ligne .DATA exige son PROPRE label unique (BinAssembleDataLine),                              }
        { seul le PREMIER (le nom REEL du global) est jamais reference               }
        { ailleurs, les suivants ne servent qu a occuper l espace. }
        GSz := 4;
        If (SymTab[I].TypeIdx >= 0) And (SymTab[I].TypeIdx < TypeCount) Then
          GSz := TypeTab[SymTab[I].TypeIdx].Size;
        If GSz < 4 Then GSz := 4;
        GWords := GSz Div 4;
        EmitRaw(ASM_PFX_GVAR + SymTab[I].Name + '  DD 0');
        For J := 2 To GWords Do
          EmitRaw(ASM_PFX_GVAR + SymTab[I].Name + '_w' + IntToStrG(J) + '  DD 0');
      End;
    End;
  For I := 0 To CgStrCount - 1 Do
    EmitRaw(ASM_PFX_STRING + IntToStrG(I) + '  DB "' + CgStrPool[I] + '", 0');
  For I := 0 To CgFloatCount - 1 Do
  Begin
    DblToBytes(CgFloatPool[I], FB);
    EmitRaw(ASM_PFX_FLOAT + IntToStrG(I) + '_b0  DB ' + IntToStrG(FB[0]));
    For J := 1 To 7 Do
      EmitRaw(ASM_PFX_FLOAT + IntToStrG(I) + '_b' + IntToStrG(J) + '  DB ' + IntToStrG(FB[J]));
  End;
  EmitBlankLine;
End;

Procedure EmitCodeSeg;
Begin
  EmitRaw('.CODE');
  EmitBlankLine;
End;

{ EmitRuntimeLibrary : runtime minimal ecrit directement dans le .asm    }
{ emis (aucune bibliotheque externe liee - meme principe que                }
{ DELPHI.PAS/_DPRT_*) - ICI, une SEULE routine, _GORT_PRINTLN_STR             }
{ (imprime la chaine C pointee par [EBP+8], terminee par un saut de              }
{ ligne, via l API Win32 GetStdHandle/WriteFile - PAS INT 21h) : c est               }
{ tout ce qu il faut pour que "fmt.Println(<chaine unique>)" (la SEULE                   }
{ forme couverte par ce TODO, voir CompileExpr/EK_CALL) fasse reellement                     }
{ quelque chose, une fois un vrai assembleur/lieur disponible (TODO 22/23).                      }
Procedure EmitRuntimeLibrary;
Begin
  { TODO 22 : "[ESI+ECX]" (base+index, SANS echelle) exigerait un VRAI       }
  { octet SIB de l encodeur 80386 - hors de portee volontaire (DELPHI.PAS,          }
  { meme projet, dont ce TODO reprend fidelement l architecture, n encode                }
  { lui non plus JAMAIS d adressage base+index) - recrit ici pour n avoir                    }
  { besoin QUE d un adressage base seule ("[ESI]", ESI increment a chaque                        }
  { iteration) ou absolu (etiquette), les deux SEULES formes couvertes par                            }
  { BinEmitModRM plus bas. Comportement observable INCHANGE. }
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

  { _GORT_PRINT_STR : imprime la chaine C pointee par [EBP+8] SANS         }
  { saut de ligne (fmt.Print reel) - WriteFile est STDCALL (l APPELE                }
  { nettoie SA PROPRE pile - AUCUN "ADD ESP" apres son CALL,                             }
  { contrairement a la convention cdecl-like des fonctions Go/_GORT_*                       }
  { elles-memes) ; ordre des arguments POUSSES = DROITE A GAUCHE (hFile                        }
  { en DERNIER, PUSH juste avant le CALL). }
  EmitLabel(ASM_PFX_RUNTIME + 'PRINT_STR');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('SUB ESP,4');                    { [EBP-4] : octets ecrits (sortie WriteFile, ignore) }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');    { ESI = pointeur chaine C (NUL-terminee) }
  EmitInstr('PUSH ESI');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRLEN');
  EmitInstr('ADD ESP,4');
  { BOGUE REEL trouve par EXECUTION reelle (pas par la compilation ni      }
  { par une relecture du texte .asm) : _GORT_STRLEN utilise ESI en                  }
  { INTERNE pour parcourir la chaine (voir sa propre definition,                        }
  { juste au-dessus) et ne le RESTAURE jamais avant de rendre la main -                    }
  { a son retour, ESI pointe desormais sur le TERMINATEUR NUL de la                            }
  { chaine (la fin), PAS son debut - recharge ESI ICI depuis [EBP+8]                              }
  { (le parametre original, intact sur la pile, JAMAIS touche par                                    }
  { STRLEN) avant de le reutiliser comme lpBuffer plus bas, sinon                                        }
  { WriteFile ecrit les octets qui SUIVENT la chaine (ici, du bourrage                                       }
  { a zero) au lieu de la chaine elle-meme. }
  EmitInstr('MOV ESI,DWORD PTR [EBP+8]');
  EmitInstr('MOV EBX,EAX');                  { EBX = longueur }
  EmitInstr('PUSH -11');                     { STD_OUTPUT_HANDLE }
  EmitInstr('CALL _GetStdHandle@4');
  EmitInstr('MOV EDI,EAX');                  { EDI = handle stdout }
  EmitInstr('PUSH 0');                       { lpOverlapped }
  EmitInstr('LEA EAX,[EBP-4]');
  EmitInstr('PUSH EAX');                     { lpNumberOfBytesWritten }
  EmitInstr('PUSH EBX');                     { nNumberOfBytesToWrite }
  EmitInstr('PUSH ESI');                     { lpBuffer }
  EmitInstr('PUSH EDI');                     { hFile }
  EmitInstr('CALL _WriteFile@20');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;

  { _GORT_PRINTLN_STR : _GORT_PRINT_STR PUIS le saut de ligne unique     }
  { constant _GORT_NEWLINE (fmt.Println reel - meme argument, un seul                }
  { appel supplementaire pour l unique octet de fin de ligne). }
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

  { _GORT_ALLOC (arrays/slices - reponse a la demande explicite de       }
  { l utilisateur d etendre le generateur de code au-dela de sa portee            }
  { initiale, TODO 21, malgre le FatalError documente qui bloquait                    }
  { encore arrays.go a ce stade) : alloue [EBP+8] octets sur le tas du                   }
  { PROCESSUS (GetProcessHeap, un SEUL tas partage - pas d allocateur                       }
  { dedie) via HeapAlloc, retourne le pointeur en EAX - AUCUNE liberation                       }
  { (_GORT_FREE) n existe encore : la memoire allouee ainsi n est JAMAIS                            }
  { rendue (fuite assumee, documentee - un vrai ramasse-miettes reste                                   }
  { hors de portee, voir l en-tete du fichier, section TODO 25).                                            }
  EmitLabel(ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  EmitInstr('CALL _GetProcessHeap@0');
  EmitInstr('MOV EBX,EAX');
  EmitInstr('PUSH DWORD PTR [EBP+8]');
  { extension structs/methodes : dwFlags=8 (HEAP_ZERO_MEMORY), pas 0 -    }
  { BOGUE REEL trouve en relisant ce code (jamais exerce par un test               }
  { concret jusqu ici puisque tous les tests precedents ecrivaient                     }
  { explicitement chaque emplacement AVANT de le relire) : sans ce               }
  { drapeau, HeapAlloc renvoie une memoire NON INITIALISEE (contenu                    }
  { indetermine) - or "make([]T,N)"/"new(T)" garantissent tous deux une                    }
  { VRAIE valeur zero en Go reel pour tout emplacement non explicitement                       }
  { ecrit. }
  EmitInstr('PUSH 8');
  EmitInstr('PUSH EBX');
  EmitInstr('CALL _HeapAlloc@12');
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
  EmitBlankLine;
End;

Procedure EmitProlog(LocalSize: Integer);
Begin
  EmitInstr('PUSH EBP');
  EmitInstr('MOV EBP,ESP');
  If LocalSize > 0 Then
    EmitInstr('SUB ESP,' + IntToStrG(LocalSize));
End;

Procedure EmitEpilog;
Begin
  EmitInstr('MOV ESP,EBP');
  EmitInstr('POP EBP');
  EmitInstr('RET');
End;

{ EmitCompareJcc : materialise dans EAX un VRAI Booleen 0/1 (PAS juste  }
{ un fanion brut) a partir d une comparaison EAX/EBX - meme idiome que       }
{ DELPHI.PAS (memes projet) : Jcc conditionnel plutot que SETcc (choix               }
{ deja fait par ce projet pour d autres compilateurs, repris ici pour la                 }
{ coherence). }
Procedure EmitCompareJcc(Const Jcc: TString);
Var LblT, LblE: TString;
Begin
  LblT := CgLabelGen;
  LblE := CgLabelGen;
  EmitInstr('CMP EAX,EBX');
  EmitInstr(Jcc + ' ' + LblT);
  EmitInstr('XOR EAX,EAX');
  EmitInstr('JMP ' + LblE);
  EmitLabel(LblT);
  EmitInstr('MOV EAX,1');
  EmitLabel(LblE);
End;

{ EmitBinOp : EAX := EAX <Op> EBX - convention FIXE (pas d allocateur   }
{ de registres) partagee par CompileExpr(EK_BINARY) : le membre GAUCHE       }
{ est deja en EAX, le membre DROIT en EBX, au moment de cet appel. }
Procedure EmitBinOp(Const Op: TString);
Begin
  If Op = '+' Then EmitInstr('ADD EAX,EBX')
  Else If Op = '-' Then EmitInstr('SUB EAX,EBX')
  Else If Op = '*' Then EmitInstr('IMUL EAX,EBX')
  Else If Op = '/' Then Begin EmitInstr('CDQ'); EmitInstr('IDIV EBX'); End
  Else If Op = '%' Then
  Begin
    EmitInstr('CDQ');
    EmitInstr('IDIV EBX');
    EmitInstr('MOV EAX,EDX');
  End
  Else If Op = '&' Then EmitInstr('AND EAX,EBX')
  Else If Op = '|' Then EmitInstr('OR EAX,EBX')
  Else If Op = '^' Then EmitInstr('XOR EAX,EBX')
  Else If Op = '&^' Then
  Begin
    EmitInstr('NOT EBX');
    EmitInstr('AND EAX,EBX');
  End
  Else If Op = '<<' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SHL EAX,CL');
  End
  Else If Op = '>>' Then
  Begin
    EmitInstr('MOV ECX,EBX');
    EmitInstr('SAR EAX,CL');
  End
  Else If Op = '==' Then EmitCompareJcc('JE')
  Else If Op = '!=' Then EmitCompareJcc('JNE')
  Else If Op = '<'  Then EmitCompareJcc('JL')
  Else If Op = '<=' Then EmitCompareJcc('JLE')
  Else If Op = '>'  Then EmitCompareJcc('JG')
  Else If Op = '>=' Then EmitCompareJcc('JGE')
  Else
    FatalError('TODO 21 : generateur de code, operateur binaire non ' +
      'couvert (entiers/booleens seulement pour l instant) : ' + Op);
End;

{ CgCollectStrings : parcours PREALABLE (avant la moindre ligne .CODE)   }
{ de TOUT le programme - deduplique chaque litteral chaine PAR VALEUR         }
{ dans CgStrPool, et retient pour CHAQUE noeud EK_STRINGLIT (index dans           }
{ ExprPool) l index du pool dans CgStrPoolOfExpr - permet a EmitDataSeg               }
{ d ecrire la section .DATA en une seule fois, AVANT le moindre .CODE                     }
{ (necessaire ici puisque .DATA precede .CODE dans le fichier emis, alors                    }
{ que les chaines ne sont normalement decouvertes qu EN PARCOURANT les                           }
{ corps de fonction bien plus tard). }
Procedure CgCollectStrings;
Var E, J, Found: Integer;
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
        If CgStrCount < MAX_STDLIB Then
        Begin
          CgStrPool[CgStrCount] := ExprPool[E].StrVal;
          Found := CgStrCount;
          Inc(CgStrCount);
        End
        Else
        Begin
          WarnMsg('table du generateur de code pleine (chaines litterales)');
          Found := 0;
        End;
      End;
      CgStrPoolOfExpr[E] := Found;
    End;
End;

{ CgCollectFloats : extension flottants (TODO 21) - meme principe EXACT  }
{ que CgCollectStrings ci-dessus, mais deduplique PAR VALEUR BINAIRE            }
{ (RealVal converti en Double) plutot que par texte. }
Procedure CgCollectFloats;
Var E, J, Found: Integer; V: Double;
Begin
  CgFloatCount := 0;
  For E := 0 To ExprCount - 1 Do
    If ExprPool[E].Kind = EK_FLOATLIT Then
    Begin
      V := ExprPool[E].RealVal;
      Found := -1;
      For J := 0 To CgFloatCount - 1 Do
        If CgFloatPool[J] = V Then
        Begin
          Found := J;
          Break;
        End;
      If Found < 0 Then
      Begin
        If CgFloatCount < MAX_STDLIB Then
        Begin
          CgFloatPool[CgFloatCount] := V;
          Found := CgFloatCount;
          Inc(CgFloatCount);
        End
        Else
        Begin
          WarnMsg('table du generateur de code pleine (litteraux flottants)');
          Found := 0;
        End;
      End;
      CgFloatPoolOfExpr[E] := Found;
    End;
End;

{ ExprIsFloatTyped : Vrai si E est de type float64 (ou un ALIAS de       }
{ float64, TypeResolveAlias) - critere utilise PARTOUT dans cette              }
{ extension pour decider s il faut router une sous-expression par                    }
{ CompileFloatExpr (pile FPU/ST0) plutot que par CompileExpr (EAX,                       }
{ convention ENTIERE existante, INCHANGEE). }
Function ExprIsFloatTyped(E: Integer): Boolean;
Begin
  ExprIsFloatTyped := (E >= 0) And (ExprPool[E].TypeIdx >= 0) And
    (TypeResolveAlias(ExprPool[E].TypeIdx) = PDT_FLOAT64);
End;

{ CompileFloatExpr : extension flottants (x87, TODO 21) - EQUIVALENT     }
{ de CompileExpr, mais pour une sous-expression FLOTTANTE : laisse            }
{ TOUJOURS son resultat au SOMMET de la pile FPU (ST(0)), JAMAIS dans              }
{ EAX (convention SEPAREE et PARALLELE a celle du reste de ce fichier -             }
{ AUCUN changement au contrat de CompileExpr lui-meme, cette extension                  }
{ n est invoquee que depuis un PETIT NOMBRE de points d entree qui               }
{ savent DEJA, via ExprIsFloatTyped, qu ils manipulent une valeur                          }
{ flottante). PORTEE DELIBEREMENT ETROITE (litteraux, variables LOCALES,                    }
{ arithmetique binaire +/-/*// SEULEMENT) : comparaisons, appels de                             }
{ fonction/methode a signature flottante, et parametres/retours flottants                          }
{ restent un FatalError CLAIR - AUCUN SAMPLES\GO\*.go existant n a besoin                               }
{ de plus que cela pour etre PARTIELLEMENT debloque (voir la note de                                        }
{ section, en-tete du fichier, TODO 25, pour le detail exact de ce qui                                         }
{ reste hors de portee). }
Procedure CompileFloatExpr(E: Integer);
Var SI: Integer;
Begin
  Case ExprPool[E].Kind Of
    EK_FLOATLIT:
      EmitInstr('FLD [' + ASM_PFX_FLOAT + IntToStrG(CgFloatPoolOfExpr[E]) + '_b0]');
    EK_IDENT:
      Begin
        SI := SymFind(ExprPool[E].NameVal);
        If SI < 0 Then
          FatalError('TODO 21 : generateur de code, identifiant non ' +
            'resolu (flottant) : ' + ExprPool[E].NameVal)
        Else
          EmitInstr('FLD ' + CgVarOperand(SI));
      End;
    EK_BINARY:
      Begin
        CompileFloatExpr(ExprPool[E].Left);
        CompileFloatExpr(ExprPool[E].Right);
        If ExprPool[E].Op = '+' Then EmitInstr('FADDP')
        Else If ExprPool[E].Op = '-' Then EmitInstr('FSUBP')
        Else If ExprPool[E].Op = '*' Then EmitInstr('FMULP')
        Else If ExprPool[E].Op = '/' Then EmitInstr('FDIVP')
        Else
          FatalError('TODO 21 : generateur de code, operateur flottant ' +
            'non couvert (comparaisons restent hors de portee de cette ' +
            'extension) : ' + ExprPool[E].Op);
      End;
  Else
    FatalError('TODO 21 : generateur de code, expression flottante non ' +
      'couverte sur cette forme (appels/comparaisons/conversions ' +
      'imbriquees restent hors de portee de cette extension)');
  End;
End;

Procedure CompileExpr(E: Integer); Forward;
Procedure CompileMethodCall(E, Callee, BaseTypeIdx, ArgFirst, ArgCount: Integer); Forward;
Function MethodAsmLabel(MIdx: Integer): TString; Forward;
Procedure CompileBoxValue(SrcExpr: Integer); Forward;
Procedure CompileInterfaceMethodCall(Callee, ArgFirst, ArgCount: Integer); Forward;
Procedure CompileStructCompositeIntoAddr(CE: Integer); Forward;
Procedure CompileArrayCompositeIntoAddr(CE: Integer); Forward;

{ ------------------------------------------------------------ }
{ make([]T,...)/len/cap/append (extension arrays/slices, meme demande    }
{ explicite qu ailleurs dans cette section) - toutes les QUATRE          }
{ manipulent le modele "slice = pointeur vers en-tete (Data;Len;Cap)"          }
{ documente plus loin (section "Tableaux/slices" ci-dessous) ; placees               }
{ ICI (avant CompileCallExpr) puisque celui-ci les appelle directement.                    }
{ ------------------------------------------------------------ }

{ CompileNew : "new(T)" - extension structs/methodes (TODO 21), GENERALISE       }
{ au-dela des slices (make) : alloue LocalSlotSize(T) octets sur le tas               }
{ (_GORT_ALLOC, desormais HEAP_ZERO_MEMORY - voir sa propre note) et                    }
{ laisse le pointeur (*T) resultant dans EAX - AUCUN en-tete, contrairement                  }
{ a une slice, "new" en Go reel renvoie un pointeur DIRECT vers une VALEUR              }
{ zero de type T, rien de plus. }
Procedure CompileNew(E: Integer);
Var TIdx, Sz: Integer;
Begin
  TIdx := ExprPool[E].Extra;
  If TIdx < 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, "new" sur un type inconnu');
    Exit;
  End;
  Sz := LocalSlotSize(TIdx);
  EmitInstr('PUSH ' + IntToStrG(Sz));
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
End;

{ CompileLenOrCap : len(x)/cap(x) - tableau ([N]T, valeur CONSTANTE       }
{ connue a la compilation, TypeTab[...].ArrayLen) ou slice (lecture           }
{ RUNTIME du champ Len/Cap de l en-tete, offsets +4/+8). }
Procedure CompileLenOrCap(ExprIdx: Integer; IsLen: Boolean);
Var BaseTypeIdx: Integer; LblNil, LblDone: TString;
Begin
  BaseTypeIdx := DerefIfPointer(ExprPool[ExprIdx].TypeIdx);
  If BaseTypeIdx < 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, len/cap sur un type ' +
      'inconnu (resolution best-effort insuffisante ici)');
    Exit;
  End;
  If TypeTab[BaseTypeIdx].Kind = TYK_ARRAY Then
    EmitInstr('MOV EAX,' + IntToStrG(TypeTab[BaseTypeIdx].ArrayLen))
  Else If TypeTab[BaseTypeIdx].Kind = TYK_SLICE Then
  Begin
    CompileExpr(ExprIdx);                        { EAX = pointeur d en-tete }
    If IsLen Then
      EmitInstr('MOV EAX,DWORD PTR [EAX+4]')
    Else
      EmitInstr('MOV EAX,DWORD PTR [EAX+8]');
  End
  Else If TypeTab[BaseTypeIdx].Kind = TYK_STRING Then
  Begin
    If Not IsLen Then
      FatalError('TODO 21 : generateur de code, "cap" non couvert sur ' +
        'une chaine (seul "len" l''est)')
    Else
    Begin
      { len(chaine) : reutilise _GORT_STRLEN (TODO 21, deja cable pour     }
      { fmt.Println/Print) - garde EXPLICITE contre un pointeur NUL               }
      { (valeur zero reelle d une chaine non initialisee dans ce                     }
      { compilateur, TODO 21 : une chaine EST un simple pointeur, jamais              }
      { une paire pointeur+longueur comme un slice) : appeler STRLEN sur                  }
      { NUL planterait (lecture memoire invalide), alors que "len(\"\")"                    }
      { doit honnetement valoir 0 en Go reel. }
      CompileExpr(ExprIdx);
      LblNil  := CgLabelGen;
      LblDone := CgLabelGen;
      EmitInstr('TEST EAX,EAX');
      EmitInstr('JZ ' + LblNil);
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'STRLEN');
      EmitInstr('ADD ESP,4');
      EmitInstr('JMP ' + LblDone);
      EmitLabel(LblNil);
      EmitInstr('MOV EAX,0');
      EmitLabel(LblDone);
    End;
  End
  Else
    FatalError('TODO 21 : generateur de code, len/cap non couvert sur ' +
      'ce type (ni tableau, ni slice, ni chaine - maps/canaux restent ' +
      'TODO 22/23)');
End;

{ CompileMakeSlice : make([]T, Len[, Cap]) - alloue (_GORT_ALLOC, voir    }
{ EmitRuntimeLibrary) un tampon de donnees de Cap*taille(T) octets PUIS         }
{ un en-tete de 12 octets (Data;Len;Cap) qui le reference - laisse le                }
{ pointeur d en-tete (la VALEUR slice elle-meme, convention documentee                    }
{ plus loin) dans EAX. Cap par defaut = Len si omise (grammaire Go            }
{ reelle). Maps/canaux restent hors de portee (voir CompileCallExpr). }
Procedure CompileMakeSlice(E: Integer);
Var TIdx, ElemTypeIdx, ElemSize, ArgFirst, ArgCount: Integer;
Begin
  TIdx := ExprPool[E].Extra;
  If (TIdx < 0) Or (TypeTab[TIdx].Kind <> TYK_SLICE) Then
  Begin
    FatalError('TODO 21 : generateur de code, "make" non couvert sur ce ' +
      'type (seul make([]T,...) l''est - maps/canaux restent TODO 22/23)');
    Exit;
  End;
  ElemTypeIdx := TypeTab[TIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);
  ArgFirst    := ExprPool[E].ArgFirst;
  ArgCount    := ExprPool[E].ArgCount;
  If ArgCount < 1 Then
  Begin
    FatalError('TODO 21 : generateur de code, "make([]T,...)" sans ' +
      'longueur non couvert');
    Exit;
  End;

  CompileExpr(ExprArgPool[ArgFirst]);             { EAX = Len }
  EmitInstr('PUSH EAX');                           { [ESP+0]=Len }
  If ArgCount >= 2 Then
    CompileExpr(ExprArgPool[ArgFirst + 1])        { EAX = Cap }
  Else
    EmitInstr('MOV EAX,DWORD PTR [ESP]');         { Cap = Len (defaut Go reel) }
  EmitInstr('PUSH EAX');                           { [ESP+0]=Cap, [ESP+4]=Len }

  EmitInstr('MOV EAX,DWORD PTR [ESP]');            { Cap }
  EmitInstr('MOV ECX,' + IntToStrG(ElemSize));
  EmitInstr('IMUL EAX,ECX');                        { EAX = taille du tampon de donnees }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                           { EAX = Data ; pile intacte : [ESP+0]=Cap,[ESP+4]=Len }
  EmitInstr('PUSH EAX');                            { [ESP+0]=Data,[ESP+4]=Cap,[ESP+8]=Len }

  EmitInstr('PUSH 12');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                           { EAX = en-tete }

  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP]');             { Data }
  EmitInstr('MOV DWORD PTR [EBX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP+8]');           { Len }
  EmitInstr('MOV DWORD PTR [EBX+4],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP+4]');           { Cap }
  EmitInstr('MOV DWORD PTR [EBX+8],EAX');
  EmitInstr('ADD ESP,12');
  EmitInstr('MOV EAX,EBX');
End;

{ CompileAppend : append(s, v) - UN SEUL element ajoute a la fois (la     }
{ forme variadique "append(s, v1, v2, ...)"/"append(s, other...)" reste          }
{ hors de portee, non exercee par SAMPLES\GO\arrays.go). Deux chemins :             }
{ Len<Cap (le tampon de donnees existant a encore de la place - ecrit                  }
{ directement) ou Len>=Cap (ALLOUE un nouveau tampon 2x plus grand, ou             }
{ 1 si Cap=0, copie les anciens elements MOT PAR MOT - ElemSize suppose                    }
{ TOUJOURS multiple de 4, vrai pour tout ce que ce compilateur produit                        }
{ reellement - puis met a jour l en-tete EXISTANT en place, meme pointeur                        }
{ conserve). Renvoie dans EAX ce MEME pointeur d en-tete, Len incremente. }
Procedure CompileAppend(SliceExprIdx, ValueExprIdx: Integer);
Var
  BaseTypeIdx, ElemTypeIdx, ElemSize, ElemWords : Integer;
  LblNoGrow, LblDouble, LblGotCap, LblCopyTop, LblCopyEnd, LblDone : TString;
Begin
  BaseTypeIdx := DerefIfPointer(ExprPool[SliceExprIdx].TypeIdx);
  If (BaseTypeIdx < 0) Or (TypeTab[BaseTypeIdx].Kind <> TYK_SLICE) Then
  Begin
    FatalError('TODO 21 : generateur de code, "append" non couvert sur ' +
      'ce type (seul append(slice, valeur) a UN SEUL element l''est)');
    Exit;
  End;
  ElemTypeIdx := TypeTab[BaseTypeIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);
  ElemWords   := ElemSize Div 4;
  If ElemWords < 1 Then ElemWords := 1;

  LblNoGrow  := CgLabelGen;
  LblDouble  := CgLabelGen;
  LblGotCap  := CgLabelGen;
  LblCopyTop := CgLabelGen;
  LblCopyEnd := CgLabelGen;
  LblDone    := CgLabelGen;

  CompileExpr(SliceExprIdx);                       { EAX = H (en-tete) }
  EmitInstr('PUSH EAX');                             { [ESP+0]=H }
  CompileExpr(ValueExprIdx);                        { EAX = V ; H intact en pile }
  EmitInstr('PUSH EAX');                             { [ESP+0]=V, [ESP+4]=H }

  EmitInstr('MOV EBX,DWORD PTR [ESP+4]');            { EBX = H }
  EmitInstr('MOV EAX,DWORD PTR [EBX+4]');            { EAX = Len }
  EmitInstr('MOV ECX,DWORD PTR [EBX+8]');            { ECX = Cap }
  EmitInstr('CMP EAX,ECX');
  EmitInstr('JL ' + LblNoGrow);

  { ---- croissance ---- }
  EmitInstr('MOV EAX,ECX');                          { Cap }
  EmitInstr('CMP EAX,0');
  EmitInstr('JNE ' + LblDouble);
  EmitInstr('MOV EAX,1');
  EmitInstr('JMP ' + LblGotCap);
  EmitLabel(LblDouble);
  EmitInstr('ADD EAX,EAX');
  EmitLabel(LblGotCap);
  EmitInstr('PUSH EAX');                             { [ESP+0]=NewCap,[ESP+4]=V,[ESP+8]=H }
  EmitInstr('MOV ECX,' + IntToStrG(ElemSize));
  EmitInstr('IMUL EAX,ECX');                          { EAX = taille du nouveau tampon }
  EmitInstr('PUSH EAX');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                             { EAX = NewData ; pile revenue a [ESP+0]=NewCap,[ESP+4]=V,[ESP+8]=H }
  EmitInstr('PUSH EAX');                              { [ESP+0]=NewData,[ESP+4]=NewCap,[ESP+8]=V,[ESP+12]=H }

  EmitInstr('MOV EBX,DWORD PTR [ESP+12]');            { EBX = H }
  EmitInstr('MOV ESI,DWORD PTR [EBX]');               { ESI = OldData }
  EmitInstr('MOV EDI,DWORD PTR [ESP]');                { EDI = NewData }
  EmitInstr('MOV EAX,DWORD PTR [EBX+4]');             { EAX = OldLen }
  EmitInstr('MOV ECX,' + IntToStrG(ElemWords));
  EmitInstr('IMUL EAX,ECX');                           { EAX = nombre de MOTS (4 octets) a copier }
  EmitInstr('MOV ECX,EAX');
  EmitLabel(LblCopyTop);
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + LblCopyEnd);
  EmitInstr('MOV EAX,DWORD PTR [ESI]');
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('ADD ESI,4');
  EmitInstr('ADD EDI,4');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + LblCopyTop);
  EmitLabel(LblCopyEnd);

  EmitInstr('MOV EAX,DWORD PTR [ESP]');               { NewData }
  EmitInstr('MOV DWORD PTR [EBX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP+4]');             { NewCap }
  EmitInstr('MOV DWORD PTR [EBX+8],EAX');
  EmitInstr('ADD ESP,8');                              { retire NewData/NewCap ; pile revenue a [ESP+0]=V,[ESP+4]=H }
  EmitInstr('JMP ' + LblDone);

  EmitLabel(LblNoGrow);
  EmitLabel(LblDone);

  { ---- ecriture commune (Len<Cap DIRECTEMENT, ou APRES croissance) :     }
  { pile TOUJOURS [ESP+0]=V,[ESP+4]=H ICI - ecrit V a Data[Len], Len++,             }
  { renvoie H (meme pointeur d en-tete). }
  EmitInstr('MOV EBX,DWORD PTR [ESP+4]');             { EBX = H }
  EmitInstr('MOV EAX,DWORD PTR [EBX+4]');             { EAX = Len }
  EmitInstr('MOV EDI,DWORD PTR [EBX]');               { EDI = Data }
  EmitInstr('MOV ECX,' + IntToStrG(ElemSize));
  EmitInstr('IMUL EAX,ECX');                           { EAX = Len*ElemSize }
  EmitInstr('ADD EDI,EAX');                            { EDI = Data + Len*ElemSize }
  EmitInstr('MOV EAX,DWORD PTR [ESP]');                { V }
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('MOV EAX,DWORD PTR [EBX+4]');
  EmitInstr('INC EAX');
  EmitInstr('MOV DWORD PTR [EBX+4],EAX');              { Len++ }
  EmitInstr('ADD ESP,8');                              { retire V/H }
  EmitInstr('MOV EAX,EBX');                            { resultat = H }
End;

{ CompileCallExpr : separee de CompileExpr (EK_CALL) car la DETECTION    }
{ elle-meme (bibliotheque standard minimale reconnue PAR NOM QUALIFIE,        }
{ TODO 20, vs. appel DIRECT a une fonction utilisateur, TODO 08) merite            }
{ sa propre procedure plutot que d alourdir le grand "Case" de                        }
{ CompileExpr. PORTEE (voir l en-tete de section TODO 21) : SEULEMENT              }
{ fmt.Println/Print avec EXACTEMENT UN argument, et l appel DIRECT               }
{ (jamais indirect/methode) d une fonction utilisateur a AU PLUS UN                    }
{ resultat - tout le reste est un arret propre documente (FatalError). }
Procedure CompileCallExpr(E: Integer);
Var
  Callee, ArgFirst, ArgCount, I, FDI, MBaseTypeIdx, ParamTIdx : Integer;
  PkgNam, FnNam : TString;
Begin
  Callee   := ExprPool[E].Left;
  ArgFirst := ExprPool[E].ArgFirst;
  ArgCount := ExprPool[E].ArgCount;

  { TODO 21 : "new(T)"/"make(T,...)" (ParseNewOrMake, TODO 08/11) sont       }
  { des FORMES SPECIALES sans VRAI callee - Left reste a -1 (jamais         }
  { renseigne, la "fonction" est ExprPool[E].NameVal directement, pas               }
  { une expression) - deverser ExprPool[-1] (lecture hors limites,                    }
  { verification de plage desactivee par defaut) plutot que de le                          }
  { detecter EXPLICITEMENT ici                        }
  { provoquait un VRAI plantage (acces memoire invalide, "Runtime error                     }
  { 216") au lieu d un arret propre - alloc memoire (slices/maps) reste                        }
  { de toute facon HORS DE PORTEE de ce TODO (TODO 22/23, runtime            }
  { embarque). }
  If Callee < 0 Then
  Begin
    If ExprPool[E].NameVal = 'make' Then
    Begin
      CompileMakeSlice(E);
      Exit;
    End;
    If ExprPool[E].NameVal = 'new' Then
    Begin
      CompileNew(E);
      Exit;
    End;
    FatalError('TODO 21 : generateur de code, appel integre non couvert ' +
      '(len/cap/append/copy/delete/close/recover/panic restent ' +
      'TODO 22/23) : ' + ExprPool[E].NameVal);
    Exit;
  End;

  { extension structs/methodes : verifiee AVANT la resolution "paquet     }
  { standard" ci-dessous - un selecteur "valeur.Nom(...)" est un appel de           }
  { METHODE des que "valeur" (depointerise) resout a un VRAI type struct               }
  { (les deux se distinguent uniquement PAR CE TEST, "fmt"/"math" etc.                    }
  { n ont eux jamais de TypeIdx reel, TODO 20) - Callee est ICI TOUJOURS               }
  { >= 0 (le cas "-1" de make/new vient d etre traite et a deja quitte la              }
  { procedure ci-dessus, EXIT inclus). }
  If ExprPool[Callee].Kind = EK_SELECTOR Then
  Begin
    MBaseTypeIdx := DerefIfPointer(ExprPool[ExprPool[Callee].Left].TypeIdx);
    If (MBaseTypeIdx >= 0) And (TypeTab[MBaseTypeIdx].Kind = TYK_STRUCT) Then
    Begin
      CompileMethodCall(E, Callee, MBaseTypeIdx, ArgFirst, ArgCount);
      Exit;
    End;
    { extension interfaces : "valeur.Methode(...)" ou "valeur" (SANS       }
    { depointerisation - une interface n est jamais un pointeur Go, ce               }
    { serait une erreur de type) est de type INTERFACE/ERROR - dispatch                    }
    { DYNAMIQUE, voir CompileInterfaceMethodCall. }
    If (ExprPool[ExprPool[Callee].Left].TypeIdx >= 0) And
       (TypeTab[ExprPool[ExprPool[Callee].Left].TypeIdx].Kind In [TYK_INTERFACE, TYK_ERROR]) Then
    Begin
      CompileInterfaceMethodCall(Callee, ArgFirst, ArgCount);
      Exit;
    End;
  End;

  If (ExprPool[Callee].Kind = EK_SELECTOR) And (ExprPool[Callee].Left >= 0) And
     (ExprPool[ExprPool[Callee].Left].Kind = EK_IDENT) Then
  Begin
    PkgNam := ExprPool[ExprPool[Callee].Left].NameVal;
    FnNam  := ExprPool[Callee].NameVal;
    If (PkgNam = 'fmt') And ((FnNam = 'Println') Or (FnNam = 'Print')) And
       (ArgCount = 1) Then
    Begin
      CompileExpr(ExprArgPool[ArgFirst]);
      EmitInstr('PUSH EAX');
      If FnNam = 'Println' Then
        EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR')
      Else
        EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'PRINT_STR');
      EmitInstr('ADD ESP,4');
      Exit;
    End;
    FatalError('TODO 21 : generateur de code, appel de bibliotheque ' +
      'standard non couvert (seul fmt.Println/Print avec un seul ' +
      'argument chaine l''est) : ' + PkgNam + '.' + FnNam);
    Exit;
  End;

  If ExprPool[Callee].Kind = EK_IDENT Then
  Begin
    { fonctions integrees len/cap/append (TODO 11) - verifiees AVANT la     }
    { resolution normale de fonction utilisateur (best-effort documente             }
    { deja au TODO 17 - meme simplification : ne verifie pas qu aucune                    }
    { fonction utilisateur du meme nom n existe, sans consequence reelle              }
    { avant que le TODO 19 ne fasse la distinction correctement). }
    If (ExprPool[Callee].NameVal = 'len') And (ArgCount = 1) Then
    Begin
      CompileLenOrCap(ExprArgPool[ArgFirst], True);
      Exit;
    End;
    If (ExprPool[Callee].NameVal = 'cap') And (ArgCount = 1) Then
    Begin
      CompileLenOrCap(ExprArgPool[ArgFirst], False);
      Exit;
    End;
    If (ExprPool[Callee].NameVal = 'append') And (ArgCount = 2) Then
    Begin
      CompileAppend(ExprArgPool[ArgFirst], ExprArgPool[ArgFirst + 1]);
      Exit;
    End;

    FDI := -1;
    For I := 0 To FuncDefCount - 1 Do
      If FuncDefPool[I].Name = ExprPool[Callee].NameVal Then
      Begin
        FDI := I;
        Break;
      End;
    If FDI < 0 Then
    Begin
      FatalError('TODO 21 : generateur de code, appel non couvert (ni ' +
        'fonction utilisateur connue, ni fmt.Println/Print) : ' +
        ExprPool[Callee].NameVal);
      Exit;
    End;
    If TypeTab[FuncDefPool[FDI].TypeIdx].ResultCount > 1 Then
    Begin
      FatalError('TODO 21 : generateur de code, retours MULTIPLES non ' +
        'couverts (fonction "' + FuncDefPool[FDI].Name + '") - voir TODO 22/23');
      Exit;
    End;
    For I := ArgCount - 1 DownTo 0 Do
    Begin
      { extension interfaces : boxing AUTOMATIQUE d un argument CONCRET      }
      { passe a un PARAMETRE declare interface/error/"any" - BOGUE REEL             }
      { trouve par EXECUTION (segmentation fault, jamais par la compilation                  }
      { ni une relecture du .asm) : sans ce boxing, la valeur BRUTE (ex.                         }
      { l entier 42 lui-meme) est poussee telle quelle, et le CORPS de la                             }
      { fonction la deref-reference comme si c etait DEJA un pointeur de                                 }
      { boite - acces memoire invalide. }
      ParamTIdx := -1;
      If I < TypeTab[FuncDefPool[FDI].TypeIdx].ParamCount Then
        ParamTIdx := FieldPool[TypeTab[FuncDefPool[FDI].TypeIdx].ParamFirst + I].TypeIdx;
      If (ParamTIdx >= 0) And (TypeTab[ParamTIdx].Kind In [TYK_INTERFACE, TYK_ERROR]) Then
        CompileBoxValue(ExprArgPool[ArgFirst + I])
      Else
        CompileExpr(ExprArgPool[ArgFirst + I]);
      EmitInstr('PUSH EAX');
    End;
    EmitInstr('CALL ' + ASM_PFX_FUNC + FuncDefPool[FDI].Name);
    If ArgCount > 0 Then
      EmitInstr('ADD ESP,' + IntToStrG(ArgCount * 4));
    Exit;
  End;

  FatalError('TODO 21 : generateur de code, forme d''appel non couverte ' +
    '(methodes/valeurs-fonction/fonctions integrees restent TODO 22/23)');
End;

{ ------------------------------------------------------------ }
{ Tableaux/slices (extension demandee explicitement au-dela de la      }
{ portee initiale du TODO 21, apres que arrays.go ait ete signale             }
{ comme non fonctionnel) - modele memoire CHOISI ICI, documente une              }
{ seule fois :                                                                       }
{   TYK_ARRAY ([N]T) : type VALEUR, exactement N*taille(T) octets                        }
{     CONTIGUS (deja correctement reserves par LocalSlotSize, TODO 21,                       }
{     puisque TypeTab[Idx].Size vaut deja N*taille(T) depuis le TODO 11)                         }
{     - la variable ELLE-MEME est son propre premier element, aucune                                 }
{     indirection.                                                                                       }
{   TYK_SLICE ([]T) : type REFERENCE, represente ICI comme un SIMPLE                                         }
{     POINTEUR (4 octets - PAS les 12 octets (Data;Len;Cap) que                                                  }
{     TypeTab[Idx].Size annonce depuis le TODO 11, une legere sur-                                                   }
{     reservation locale harmless) vers un EN-TETE de 12 octets ALLOUE                                                   }
{     SUR LE TAS (_GORT_ALLOC) au moment de sa creation (make/composite                                                     }
{     litteral) : [+0]=Data (pointeur vers les elements, EGALEMENT                                                              }
{     alloues sur le tas separement) ; [+4]=Len ; [+8]=Cap. Choisi                                                                   }
{     PLUTOT QUE l en-tete 12 octets INLINE (plus proche de l ABI Go                                                                     }
{     reelle) car cela permet a une VALEUR de slice de continuer a               }
{     tenir dans UN SEUL registre/mot memoire EAX - exactement la                    }
{     MEME convention que TOUTE autre valeur dans ce generateur de                       }
{     code (aucun changement necessaire a la convention d appel, au                          }
{     stockage des variables, aux affectations) - au prix d une                                 }
{     divergence semantique ASSUMEE : deux variables de slice partageant                            }
{     le MEME en-tete (ex. "s2 := s1") partagent aussi desormais Len/Cap                                }
{     APRES un append independant sur l une des deux, ce qui diverge du                                    }
{     vrai Go (qui copie l en-tete PAR VALEUR a l affectation) - sans                                           }
{     consequence pour aucun SAMPLES\GO\*.go existant, qui ne compare/                                              }
{     aliase jamais deux variables de slice de cette maniere precise.                                                   }
{ ------------------------------------------------------------ }

Procedure CompileIndexAddr(E: Integer); Forward;
Procedure CompileFieldAddr(E: Integer); Forward;

{ CompileAddrOf : calcule l ADRESSE d une expression ADRESSABLE dans     }
{ EAX - variable simple (LEA de son emplacement), EK_INDEX (delegue a           }
{ CompileIndexAddr), EK_SELECTOR (delegue a CompileFieldAddr), EK_DEREF             }
{ (la VALEUR du pointeur EST deja l adresse visee, un CompileExpr normal            }
{ suffit). }
Procedure CompileAddrOf(E: Integer);
Var SI: Integer;
Begin
  Case ExprPool[E].Kind Of
    EK_IDENT:
      Begin
        SI := SymFind(ExprPool[E].NameVal);
        If SI < 0 Then
          FatalError('TODO 21 : generateur de code, identifiant non ' +
            'resolu (adresse) : ' + ExprPool[E].NameVal)
        Else
          EmitInstr('LEA EAX,' + CgVarOperand(SI));
      End;
    EK_INDEX:
      CompileIndexAddr(E);
    EK_SELECTOR:
      CompileFieldAddr(E);
    EK_DEREF:
      CompileExpr(ExprPool[E].Left);
  Else
    FatalError('TODO 21 : generateur de code, adresse non couverte sur ' +
      'cette forme d''expression');
  End;
End;

{ CompileIndexAddr : calcule l ADRESSE de l element vise par un noeud    }
{ EK_INDEX (Left=base, Right=index) dans EAX - deux cas selon le TYPE            }
{ REEL (deja resolu, TODO 06/11, DerefIfPointer applique d abord comme                  }
{ partout ailleurs dans ce fichier depuis le TODO 13) de la base :                          }
{ TYK_ARRAY (adresse = adresse de la VARIABLE elle-meme + index*taille-                         }
{ element) ou TYK_SLICE (adresse = champ Data, offset 0 de l en-tete                                }
{ alloue sur le tas - voir la note de section ci-dessus - + index*                                      }
{ taille-element). }
Procedure CompileIndexAddr(E: Integer);
Var BaseE, IdxE, BaseTypeIdx, ElemTypeIdx, ElemSize: Integer;
Begin
  BaseE := ExprPool[E].Left;
  IdxE  := ExprPool[E].Right;
  BaseTypeIdx := DerefIfPointer(ExprPool[BaseE].TypeIdx);

  If BaseTypeIdx < 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, indexation sur un type ' +
      'inconnu (resolution best-effort insuffisante ici)');
    Exit;
  End;

  ElemTypeIdx := TypeTab[BaseTypeIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);

  If TypeTab[BaseTypeIdx].Kind = TYK_ARRAY Then
  Begin
    { "pa[i]" ou pa est *[N]T (pointeur vers tableau) : la VALEUR de pa    }
    { EST DEJA l adresse voulue (CompileExpr, PAS CompileAddrOf qui                  }
    { donnerait &pa, l adresse DU POINTEUR lui-meme) - meme regle que                     }
    { CompileFieldAddr/CompileSliceExpr/STK_FORRANGE. }
    If (ExprPool[BaseE].TypeIdx >= 0) And
       (TypeTab[ExprPool[BaseE].TypeIdx].Kind = TYK_POINTER) Then
      CompileExpr(BaseE)
    Else
      CompileAddrOf(BaseE);
  End
  Else If TypeTab[BaseTypeIdx].Kind = TYK_SLICE Then
  Begin
    CompileExpr(BaseE);                     { EAX = pointeur vers l en-tete }
    EmitInstr('MOV EAX,DWORD PTR [EAX]');   { EAX = champ Data (offset 0) }
  End
  Else
  Begin
    FatalError('TODO 21 : generateur de code, indexation non couverte ' +
      'sur ce type (ni tableau ni slice)');
    Exit;
  End;

  { EAX = adresse du premier element - ajoute index*ElemSize, en          }
  { preservant EAX pendant que l INDEX (sous-expression arbitraire) est               }
  { evalue. }
  EmitInstr('PUSH EAX');
  CompileExpr(IdxE);
  EmitInstr('MOV EBX,EAX');
  If ElemSize <> 1 Then
  Begin
    EmitInstr('MOV ECX,' + IntToStrG(ElemSize));
    EmitInstr('IMUL EBX,ECX');
  End;
  EmitInstr('POP EAX');
  EmitInstr('ADD EAX,EBX');
End;

{ CompileFieldAddr : extension structs/methodes (TODO 21) - calcule       }
{ l ADRESSE du champ vise par un noeud EK_SELECTOR (Left=base, NameVal=nom             }
{ du champ) dans EAX. Base=VALEUR (Left EST deja une adresse) si Left est            }
{ un POINTEUR ; base=CompileAddrOf(Left) sinon (valeur struct INLINE,                    }
{ meme regle que CompileIndexAddr pour un tableau). Utilise                                  }
{ FindFieldWithOffset (TODO 09/21) pour resoudre le deplacement, PROMOTION              }
{ (champs embarques PAR VALEUR) comprise. }
Procedure CompileFieldAddr(E: Integer);
Var BaseE, BaseTypeIdx, FIdx, FOfs: Integer;
Begin
  BaseE := ExprPool[E].Left;
  BaseTypeIdx := DerefIfPointer(ExprPool[BaseE].TypeIdx);

  If (BaseTypeIdx < 0) Or (TypeTab[BaseTypeIdx].Kind <> TYK_STRUCT) Then
  Begin
    FatalError('TODO 21 : generateur de code, acces a un champ non ' +
      'couvert sur ce type (ni struct, ni pointeur vers struct) : ' +
      ExprPool[E].NameVal);
    Exit;
  End;

  FIdx := FindFieldWithOffset(BaseTypeIdx, ExprPool[E].NameVal, FOfs);
  If FIdx < 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, champ non resolu ' +
      '(promotion via un champ embarque POINTEUR non couverte, ou champ ' +
      'inconnu) : ' + ExprPool[E].NameVal);
    Exit;
  End;

  If (ExprPool[BaseE].TypeIdx >= 0) And
     (TypeTab[ExprPool[BaseE].TypeIdx].Kind = TYK_POINTER) Then
    CompileExpr(BaseE)          { la valeur du pointeur EST l adresse de base }
  Else
    CompileAddrOf(BaseE);       { valeur struct inline : il faut son adresse }

  If FOfs <> 0 Then
    EmitInstr('ADD EAX,' + IntToStrG(FOfs));
End;

{ CompileMethodCall : extension structs/methodes (TODO 21) - "base.Nom   }
{ (args...)" ou base (depointerise) resout a un VRAI type struct                    }
{ (verifie par l appelant, CompileCallExpr, avant de deleguer ici) -               }
{ FindMethodWithOffset (TODO 09/21) resout la METHODE et le deplacement                  }
{ de PROMOTION eventuel (champs embarques PAR VALEUR). Deux conventions                     }
{ de receveur : POINTEUR (une seule ADRESSE poussee, comme un parametre                          }
{ normal) ou VALEUR (copie REELLE des octets de la struct, un MOT a la                              }
{ fois, PAS juste un pointeur - vraie semantique Go, voir la note de                                     }
{ ParseFuncDecl/SymAdd sur CurParamOffset pour la moitie "appele" de ce                                      }
{ meme mecanisme). }
Procedure CompileMethodCall(E, Callee, BaseTypeIdx, ArgFirst, ArgCount: Integer);
Var MIdx, FOfs, I, RecvSize, RecvWords, RecvExpr: Integer;
Begin
  MIdx := FindMethodWithOffset(BaseTypeIdx, ExprPool[Callee].NameVal, FOfs);
  If MIdx < 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, methode non resolue ' +
      '(promotion via un champ embarque POINTEUR non couverte, ou ' +
      'methode inconnue) : ' + ExprPool[Callee].NameVal);
    Exit;
  End;
  If TypeTab[MethodDefPool[MIdx].TypeIdx].ResultCount > 1 Then
  Begin
    FatalError('TODO 21 : generateur de code, retours MULTIPLES non ' +
      'couverts (methode "' + MethodDefPool[MIdx].Name + '") - voir TODO 22/23');
    Exit;
  End;

  RecvExpr := ExprPool[Callee].Left;

  { pousse les arguments REELS d abord (droite a gauche, comme un appel   }
  { de fonction ordinaire), PUIS le receveur en DERNIER (arrive donc en             }
  { PREMIER sur la pile cote appele, [EBP+8] - RegisterFuncScopeSymbols                  }
  { l y a deja enregistre au moment de l analyse, TODO 09). }
  For I := ArgCount - 1 DownTo 0 Do
  Begin
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('PUSH EAX');
  End;

  If MethodDefPool[MIdx].IsPointerRecv Then
  Begin
    If (ExprPool[RecvExpr].TypeIdx >= 0) And
       (TypeTab[ExprPool[RecvExpr].TypeIdx].Kind = TYK_POINTER) Then
      CompileExpr(RecvExpr)
    Else
      CompileAddrOf(RecvExpr);
    If FOfs <> 0 Then EmitInstr('ADD EAX,' + IntToStrG(FOfs));
    EmitInstr('PUSH EAX');
    EmitInstr('CALL ' + MethodAsmLabel(MIdx));
    EmitInstr('ADD ESP,' + IntToStrG((ArgCount + 1) * 4));
  End
  Else
  Begin
    { receveur PAR VALEUR : calcule son adresse EXACTEMENT comme le cas    }
    { pointeur ci-dessus, mais NE LA PASSE PAS directement - copie ses               }
    { mots un par un sur la pile (RecvWords mots, PAS juste 1) pour une                  }
    { VRAIE semantique de copie de valeur. }
    RecvSize  := LocalSlotSize(BaseTypeIdx);
    RecvWords := RecvSize Div 4;
    If RecvWords < 1 Then RecvWords := 1;

    If (ExprPool[RecvExpr].TypeIdx >= 0) And
       (TypeTab[ExprPool[RecvExpr].TypeIdx].Kind = TYK_POINTER) Then
      CompileExpr(RecvExpr)
    Else
      CompileAddrOf(RecvExpr);
    If FOfs <> 0 Then EmitInstr('ADD EAX,' + IntToStrG(FOfs));

    EmitInstr('MOV EDI,EAX');
    For I := RecvWords - 1 DownTo 0 Do
      EmitInstr('PUSH DWORD PTR [EDI+' + IntToStrG(I * 4) + ']');

    EmitInstr('CALL ' + MethodAsmLabel(MIdx));
    EmitInstr('ADD ESP,' + IntToStrG((ArgCount + RecvWords) * 4));
  End;
End;

{ ------------------------------------------------------------ }
{ Interfaces (extension demandee explicitement, "terminer le             }
{ compilateur") - modele CHOISI ICI, documente une seule fois : une                  }
{ VALEUR d interface (y compris "error"/"any") est TOUJOURS un POINTEUR                    }
{ (4 octets, meme convention EAX que tout le reste) vers une BOITE               }
{ allouee sur le tas (_GORT_ALLOC, meme allocateur que arrays/slices) de                 }
{ 8 octets : [+0]=TypeIdx CONCRET (l entier TypeTab reel du type BOITE,               }
{ deja depointerise - reutilise DIRECTEMENT comme etiquette d execution,                    }
{ aucun descripteur de type separe/vtable necessaire, puisque TOUS les                        }
{ types sont connus a la COMPILATION dans ce compilateur - pas de                                 }
{ chargement dynamique de type possible en Go de toute facon) ;                                      }
{ [+4]=DataPtr (adresse de la VALEUR sous-jacente - le pointeur lui-meme                                 }
{ si la source etait DEJA un pointeur, sinon l adresse d une VRAIE COPIE                                     }
{ fraichement allouee sur le tas, boxing de valeur reel comme en Go).                                            }
{ nil interne = boite pointeur 0, DEJA correct sans aucun code special                                              }
{ (meme convention "0 = valeur zero" que partout ailleurs). Dispatch de                                                }
{ methode (CompileInterfaceMethodCall) : PAS de vtable - une CHAINE de                                                    }
{ comparaisons du TypeIdx boite contre chaque methode DECLAREE sous ce                                                        }
{ nom dans MethodDefPool (le nombre de types reels etant petit et connu                                                          }
{ a la compilation, une simple chaine sequentielle est LARGEMENT                                                                    }
{ suffisante - meme discipline "correction avant vitesse" que                                                                          }
{ CompileSwitch). LIMITATIONS ASSUMEES : type assertion ("x.(T)") et                                                                        }
{ type switch ("switch v := x.(type)") restent HORS DE PORTEE (auraient                                                                        }
{ pu reutiliser la MEME boite/TypeIdx, mais non implementes ICI par                                                                              }
{ manque de temps) - un FatalError CLAIR les signale, jamais un plantage.                                                                             }
{ ------------------------------------------------------------ }

{ CompileBoxValue : "boite" SrcExpr dans une NOUVELLE boite d interface  }
{ (ou copie simplement le pointeur de boite existant si SrcExpr est                    }
{ LUI-MEME deja de type interface/error - AUCUN re-boxing dans ce cas,                     }
{ affectation interface-a-interface ordinaire). Laisse le pointeur de                          }
{ boite (resultat) dans EAX. }
Procedure CompileBoxValue(SrcExpr: Integer);
Var
  SrcTypeIdx, DerefTypeIdx, Sz : Integer;
  LblTop, LblEnd : TString;
Begin
  SrcTypeIdx := ExprPool[SrcExpr].TypeIdx;

  If (SrcTypeIdx >= 0) And
     ((TypeTab[SrcTypeIdx].Kind = TYK_INTERFACE) Or (TypeTab[SrcTypeIdx].Kind = TYK_ERROR)) Then
  Begin
    CompileExpr(SrcExpr);   { deja une boite - simple copie du pointeur }
    Exit;
  End;

  DerefTypeIdx := DerefIfPointer(SrcTypeIdx);

  If (SrcTypeIdx >= 0) And (TypeTab[SrcTypeIdx].Kind = TYK_POINTER) Then
    CompileExpr(SrcExpr)                          { EAX = DataPtr = valeur du pointeur }
  Else If (DerefTypeIdx >= 0) And
          (TypeTab[DerefTypeIdx].Kind In [TYK_STRUCT, TYK_ARRAY]) Then
  Begin
    { valeur MULTI-MOTS (struct/tableau) : VRAIE copie sur le tas, mot     }
    { par mot - EDI/ESI librement utilisables ICI (aucun appel n intervient          }
    { dans cette boucle). }
    Sz := TypeTab[DerefTypeIdx].Size;
    If Sz < 4 Then Sz := 4;
    EmitInstr('PUSH ' + IntToStrG(Sz));
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
    EmitInstr('ADD ESP,4');                        { EAX = nouvelle copie }

    If ExprPool[SrcExpr].Kind = EK_COMPOSITE Then
    Begin
      { source = litteral compose DIRECT (ex. "Square(Side:4)" avec        }
      { accolades Go notees entre parentheses ici), PAS une                    }
      { variable adressable - CompileAddrOf n a rien a lui offrir (pas de           }
      { case EK_COMPOSITE) : remplit la copie DIRECTEMENT (zero-fill puis                 }
      { chaque champ/element, meme logique que CompileStructCompositeInto/                    }
      { CompileArrayCompositeInto mais visant une adresse de tas plutot                          }
      { qu un slot local - voir CompileStructCompositeIntoAddr). }
      If TypeTab[DerefTypeIdx].Kind = TYK_STRUCT Then
        CompileStructCompositeIntoAddr(SrcExpr)
      Else
        CompileArrayCompositeIntoAddr(SrcExpr);
      { EAX = adresse de la copie (deja remplie) = DataPtr. }
    End
    Else
    Begin
      EmitInstr('MOV EDI,EAX');
      EmitInstr('PUSH EDI');                          { conserve l adresse de la copie }
      If (ExprPool[SrcExpr].TypeIdx >= 0) And
         (TypeTab[ExprPool[SrcExpr].TypeIdx].Kind = TYK_POINTER) Then
        CompileExpr(SrcExpr)
      Else
        CompileAddrOf(SrcExpr);
      EmitInstr('MOV ESI,EAX');                       { adresse SOURCE }
      EmitInstr('MOV EDI,DWORD PTR [ESP]');           { adresse de la copie (relue, EAX vient d etre ecrase) }
      EmitInstr('MOV ECX,' + IntToStrG(Sz Div 4));
      LblTop := CgLabelGen;
      LblEnd := CgLabelGen;
      EmitLabel(LblTop);
      EmitInstr('CMP ECX,0');
      EmitInstr('JLE ' + LblEnd);
      EmitInstr('MOV EAX,DWORD PTR [ESI]');
      EmitInstr('MOV DWORD PTR [EDI],EAX');
      EmitInstr('ADD ESI,4');
      EmitInstr('ADD EDI,4');
      EmitInstr('DEC ECX');
      EmitInstr('JMP ' + LblTop);
      EmitLabel(LblEnd);
      EmitInstr('POP EAX');                            { EAX = DataPtr (adresse de la copie) }
    End;
  End
  Else If ExprIsFloatTyped(SrcExpr) Then
  Begin
    { extension flottants+interfaces : float64 - alloue 8 octets (PAS 4,   }
    { un Double COMPLET) et stocke la VALEUR via la pile FPU (FSTP), PAS         }
    { CompileExpr (convention EAX ENTIERE, incompatible). }
    EmitInstr('PUSH 8');
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
    EmitInstr('ADD ESP,4');                          { EAX = nouvelle adresse (8 octets) }
    EmitInstr('MOV EBX,EAX');
    CompileFloatExpr(SrcExpr);                        { ST(0) = valeur }
    EmitInstr('FSTP [EBX]');
    EmitInstr('MOV EAX,EBX');                          { EAX = DataPtr }
  End
  Else
  Begin
    { scalaire (int/bool/etc.) : alloue 4 octets, stocke la VALEUR         }
    { directement (CompileExpr la donne deja, pas une adresse a copier). }
    CompileExpr(SrcExpr);
    EmitInstr('PUSH EAX');
    EmitInstr('PUSH 4');
    EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
    EmitInstr('ADD ESP,4');                          { EAX = nouvelle adresse }
    EmitInstr('MOV EBX,EAX');
    EmitInstr('POP EAX');
    EmitInstr('MOV DWORD PTR [EBX],EAX');
    EmitInstr('MOV EAX,EBX');                        { EAX = DataPtr }
  End;

  { EAX = DataPtr - alloue la BOITE (8 octets) et remplit ses deux mots. }
  EmitInstr('PUSH EAX');                             { DataPtr }
  EmitInstr('PUSH 8');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                            { EAX = boite }
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOV EAX,' + IntToStrG(DerefTypeIdx));
  EmitInstr('MOV DWORD PTR [EBX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP]');              { DataPtr }
  EmitInstr('MOV DWORD PTR [EBX+4],EAX');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EAX,EBX');                          { resultat = pointeur de boite }
End;

{ CompileInterfaceMethodCall : "base.Nom(args...)" ou base (Left du       }
{ selecteur) est de type INTERFACE/ERROR - dispatch DYNAMIQUE (le VRAI               }
{ type concret n est connu qu a l EXECUTION, contrairement a                                }
{ CompileMethodCall/receveur statique) via une chaine de comparaisons du               }
{ TypeIdx boite contre chaque candidat MethodDefPool portant ce nom. }
Procedure CompileInterfaceMethodCall(Callee, ArgFirst, ArgCount: Integer);
Const MAX_IFACE_CAND = 32;
Var
  MName : TString;
  I, J, RTIdx, MI, CandCount, RecvSize, RecvWords : Integer;
  CandMI  : Array[0..MAX_IFACE_CAND - 1] Of Integer;
  CandLbl : Array[0..MAX_IFACE_CAND - 1] Of TString;
  LblDone : TString;
Begin
  MName := ExprPool[Callee].NameVal;

  CandCount := 0;
  For MI := 0 To MethodDefCount - 1 Do
    If (MethodDefPool[MI].Name = MName) And (CandCount < MAX_IFACE_CAND) Then
    Begin
      CandMI[CandCount] := MI;
      CandLbl[CandCount] := CgLabelGen;
      Inc(CandCount);
    End;

  If CandCount = 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, methode inconnue a ' +
      'travers une interface : ' + MName);
    Exit;
  End;

  CompileExpr(ExprPool[Callee].Left);          { EAX = boite }
  EmitInstr('PUSH EAX');                         { [ESP+0]=boite }
  For I := ArgCount - 1 DownTo 0 Do
  Begin
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('PUSH EAX');
  End;
  { pile : [ESP+0]=arg[0], ..., [ESP+4*(ArgCount-1)]=arg[ArgCount-1],    }
  { [ESP+4*ArgCount]=boite. }

  LblDone := CgLabelGen;
  EmitInstr('MOV EBX,DWORD PTR [ESP+' + IntToStrG(4 * ArgCount) + ']');   { boite }
  EmitInstr('MOV EBX,DWORD PTR [EBX]');          { EBX = TypeIdx concret }
  For I := 0 To CandCount - 1 Do
  Begin
    RTIdx := MethodDefPool[CandMI[I]].RecvTypeIdx;
    If TypeTab[RTIdx].Kind = TYK_POINTER Then RTIdx := TypeTab[RTIdx].ElemTypeIdx;
    EmitInstr('CMP EBX,' + IntToStrG(RTIdx));
    EmitInstr('JE ' + CandLbl[I]);
  End;
  { aucune correspondance : ne devrait jamais arriver si TypeSatisfiesInterface  }
  { (analyse, TODO 10/19) a fait son travail - repli SUR (EAX:=0, jamais         }
  { un comportement indefini) plutot qu un plantage. }
  EmitInstr('MOV EAX,0');
  EmitInstr('JMP ' + LblDone);

  For I := 0 To CandCount - 1 Do
  Begin
    EmitLabel(CandLbl[I]);
    MI := CandMI[I];
    EmitInstr('MOV EAX,DWORD PTR [ESP+' + IntToStrG(4 * ArgCount) + ']');  { boite }
    EmitInstr('MOV EAX,DWORD PTR [EAX+4]');       { DataPtr }
    If MethodDefPool[MI].IsPointerRecv Then
    Begin
      EmitInstr('PUSH EAX');
      EmitInstr('CALL ' + MethodAsmLabel(MI));
      EmitInstr('ADD ESP,' + IntToStrG((ArgCount + 1 + 1) * 4));   { args+receveur+boite }
    End
    Else
    Begin
      RTIdx := MethodDefPool[MI].RecvTypeIdx;
      RecvSize := LocalSlotSize(RTIdx);
      RecvWords := RecvSize Div 4;
      If RecvWords < 1 Then RecvWords := 1;
      EmitInstr('MOV EDI,EAX');
      For J := RecvWords - 1 DownTo 0 Do
        EmitInstr('PUSH DWORD PTR [EDI+' + IntToStrG(J * 4) + ']');
      EmitInstr('CALL ' + MethodAsmLabel(MI));
      EmitInstr('ADD ESP,' + IntToStrG((ArgCount + RecvWords + 1) * 4));   { args+receveur+boite }
    End;
    EmitInstr('JMP ' + LblDone);
  End;

  EmitLabel(LblDone);
End;

{ CompileSliceExpr : extension structs/methodes (pointeurs, TODO 21) -   }
{ "base[Low:High]" (tranchage a 2 indices SEULEMENT - "base[Low:High:Max"}
{ a 3 indices reste hors de portee, non exerce par aucun SAMPLES\GO\*.go             }
{ existant) - base ARRAY ou SLICE (deref implicite si pointeur, deja                    }
{ resolu par le parseur, TODO 13). Alloue un NOUVEL en-tete pointant a               }
{ l INTERIEUR du tampon de donnees SOURCE (AUCUNE copie des elements -                    }
{ vraie semantique Go : trancher partage la memoire) : Data=DataSource+                     }
{ Low*ElemSize, Len=High-Low, Cap=CapSource-Low (CapSource=ArrayLen pour                    }
{ un tableau, qui n a pas de Cap separee). Low par defaut 0, High par                          }
{ defaut la longueur totale de la collection, si omis. }
Procedure CompileSliceExpr(E: Integer);
Var
  BaseE, BaseTypeIdx, ElemTypeIdx, ElemSize, LowE, HighE, MaxE : Integer;
Begin
  BaseE := ExprPool[E].Left;
  LowE  := ExprArgPool[ExprPool[E].ArgFirst];
  HighE := ExprArgPool[ExprPool[E].ArgFirst + 1];
  MaxE  := ExprArgPool[ExprPool[E].ArgFirst + 2];

  If MaxE >= 0 Then
  Begin
    FatalError('TODO 21 : generateur de code, tranchage a 3 indices ' +
      '("base[low:high:max]") non couvert');
    Exit;
  End;

  BaseTypeIdx := DerefIfPointer(ExprPool[BaseE].TypeIdx);
  If (BaseTypeIdx < 0) Or
     ((TypeTab[BaseTypeIdx].Kind <> TYK_ARRAY) And (TypeTab[BaseTypeIdx].Kind <> TYK_SLICE)) Then
  Begin
    FatalError('TODO 21 : generateur de code, tranchage non couvert sur ' +
      'ce type (ni tableau ni slice - chaines restent TODO 22/23)');
    Exit;
  End;
  ElemTypeIdx := TypeTab[BaseTypeIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);

  If LowE >= 0 Then CompileExpr(LowE) Else EmitInstr('MOV EAX,0');
  EmitInstr('PUSH EAX');                        { [ESP+0]=Low }

  If HighE >= 0 Then
    CompileExpr(HighE)
  Else If TypeTab[BaseTypeIdx].Kind = TYK_ARRAY Then
    EmitInstr('MOV EAX,' + IntToStrG(TypeTab[BaseTypeIdx].ArrayLen))
  Else
  Begin
    CompileExpr(BaseE);
    EmitInstr('MOV EAX,DWORD PTR [EAX+4]');     { Len de la slice source }
  End;
  EmitInstr('PUSH EAX');                        { [ESP+0]=High,[ESP+4]=Low }

  If TypeTab[BaseTypeIdx].Kind = TYK_ARRAY Then
    EmitInstr('MOV EAX,' + IntToStrG(TypeTab[BaseTypeIdx].ArrayLen))
  Else
  Begin
    CompileExpr(BaseE);
    EmitInstr('MOV EAX,DWORD PTR [EAX+8]');     { Cap de la slice source }
  End;
  EmitInstr('SUB EAX,DWORD PTR [ESP+4]');       { CapSource - Low = NewCap }
  EmitInstr('PUSH EAX');                        { [ESP+0]=NewCap,[ESP+4]=High,[ESP+8]=Low }

  { adresse du premier element SOURCE - meme regle "valeur pointeur EST   }
  { l adresse / sinon CompileAddrOf" que CompileFieldAddr, necessaire ICI              }
  { car "pa[1:2]" (pa=*[3]int) tranche a travers un pointeur. }
  If TypeTab[BaseTypeIdx].Kind = TYK_ARRAY Then
  Begin
    If (ExprPool[BaseE].TypeIdx >= 0) And
       (TypeTab[ExprPool[BaseE].TypeIdx].Kind = TYK_POINTER) Then
      CompileExpr(BaseE)
    Else
      CompileAddrOf(BaseE);
  End
  Else
  Begin
    CompileExpr(BaseE);
    EmitInstr('MOV EAX,DWORD PTR [EAX]');       { Data de la slice source }
  End;
  EmitInstr('MOV EBX,DWORD PTR [ESP+8]');       { Low }
  EmitInstr('MOV ECX,' + IntToStrG(ElemSize));
  EmitInstr('IMUL EBX,ECX');
  EmitInstr('ADD EAX,EBX');                     { EAX = NewData }
  EmitInstr('PUSH EAX');                        { [ESP+0]=NewData,[ESP+4]=NewCap,[ESP+8]=High,[ESP+12]=Low }

  EmitInstr('PUSH 12');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                       { EAX = en-tete ; pile intacte }
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP]');         { NewData }
  EmitInstr('MOV DWORD PTR [EBX],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP+8]');       { High }
  EmitInstr('SUB EAX,DWORD PTR [ESP+12]');      { High - Low = NewLen }
  EmitInstr('MOV DWORD PTR [EBX+4],EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP+4]');       { NewCap }
  EmitInstr('MOV DWORD PTR [EBX+8],EAX');
  EmitInstr('ADD ESP,16');
  EmitInstr('MOV EAX,EBX');
End;

{ CompileSliceComposite : "[]T(v0, v1, ...)" (accolades Go, notees ici     }
{ entre parentheses pour ne pas fermer ce commentaire) - SEULEMENT des         }
{ elements                                                                       }
{ POSITIONNELS (aucune cle) - alloue un tampon de donnees puis un                 }
{ en-tete, exactement comme CompileMakeSlice, mais Len=Cap=ArgCount (une              }
{ CONSTANTE de compilation, pas une expression a evaluer) et remplit             }
{ chaque emplacement avec la VALEUR de l element correspondant (au lieu             }
{ de le laisser a zero). Laisse le pointeur d en-tete dans EAX (meme               }
{ convention slice qu ailleurs). }
Procedure CompileSliceComposite(E: Integer);
Var TIdx, ElemTypeIdx, ElemSize, ArgFirst, ArgCount, I, DataSize: Integer;
Begin
  TIdx        := ExprPool[E].Extra;
  ElemTypeIdx := TypeTab[TIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);
  ArgFirst    := ExprPool[E].ArgFirst;
  ArgCount    := ExprPool[E].ArgCount;

  For I := ArgFirst To ArgFirst + ArgCount - 1 Do
    If ExprArgKey[I] <> '' Then
    Begin
      FatalError('TODO 21 : generateur de code, litteral compose de ' +
        'slice avec cle non couvert (seuls les elements POSITIONNELS ' +
        'le sont)');
      Exit;
    End;

  DataSize := ArgCount * ElemSize;
  If DataSize < 1 Then DataSize := 1;   { HeapAlloc(0) : evite un cas degenere }
  EmitInstr('PUSH ' + IntToStrG(DataSize));
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');
  EmitInstr('PUSH EAX');                              { [ESP+0]=Data }

  For I := 0 To ArgCount - 1 Do
  Begin
    CompileExpr(ExprArgPool[ArgFirst + I]);           { EAX = valeur ; Data en pile, jamais mise en cache }
    EmitInstr('MOV EBX,DWORD PTR [ESP]');
    If I > 0 Then
      EmitInstr('ADD EBX,' + IntToStrG(I * ElemSize));
    EmitInstr('MOV DWORD PTR [EBX],EAX');
  End;

  EmitInstr('PUSH 12');
  EmitInstr('CALL ' + ASM_PFX_RUNTIME + 'ALLOC');
  EmitInstr('ADD ESP,4');                              { EAX = en-tete ; pile toujours [ESP+0]=Data }
  EmitInstr('MOV EBX,EAX');
  EmitInstr('MOV EAX,DWORD PTR [ESP]');                { Data }
  EmitInstr('MOV DWORD PTR [EBX],EAX');
  EmitInstr('MOV EAX,' + IntToStrG(ArgCount));
  EmitInstr('MOV DWORD PTR [EBX+4],EAX');
  EmitInstr('MOV DWORD PTR [EBX+8],EAX');
  EmitInstr('ADD ESP,4');
  EmitInstr('MOV EAX,EBX');
End;

{ CompileArrayCompositeInto : "[N]T(v0, v1, ...)" (ou vide, accolades    }
{ Go notees ici entre parentheses pour ne pas fermer ce commentaire)           }
{ AFFECTE DIRECTEMENT au symbole local SI - un tableau est un type                }
{ VALEUR multi-mots (voir la note de section plus haut), incompatible               }
{ avec la convention "resultat unique dans EAX" : cette forme n est                     }
{ donc couverte QUE comme initialiseur DIRECT d un ":=" (StmtPool                          }
{ STK_SHORTVAR, seul appelant) - toute AUTRE position (argument,                               }
{ litteral imbrique, etc.) reste un FatalError explicite (CompileExpr,                            }
{ cas EK_COMPOSITE). Remplit d abord TOUTE la plage a zero (comme                                    }
{ STK_VARDECL - couvre le litteral vide et les elements NON fournis),                                    }
{ puis ecrase les elements EXPLICITEMENT donnes. }
Procedure CompileArrayCompositeInto(CE, SI: Integer);
Var TIdx, ElemTypeIdx, ElemSize, ArgFirst, ArgCount, I, ZN: Integer;
    LblZTop, LblZEnd: TString;
Begin
  TIdx        := ExprPool[CE].Extra;
  ElemTypeIdx := TypeTab[TIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);
  ArgFirst    := ExprPool[CE].ArgFirst;
  ArgCount    := ExprPool[CE].ArgCount;

  ZN := TypeTab[TIdx].Size;
  If ZN < 4 Then ZN := 4;
  EmitInstr('XOR EAX,EAX');
  EmitInstr('LEA EDI,' + CgVarOperand(SI));
  EmitInstr('MOV ECX,' + IntToStrG(ZN Div 4));
  LblZTop := CgLabelGen;
  LblZEnd := CgLabelGen;
  EmitLabel(LblZTop);
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + LblZEnd);
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('ADD EDI,4');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + LblZTop);
  EmitLabel(LblZEnd);

  For I := 0 To ArgCount - 1 Do
  Begin
    If ExprArgKey[ArgFirst + I] <> '' Then
    Begin
      FatalError('TODO 21 : generateur de code, litteral compose de ' +
        'tableau avec cle non couvert (seuls les elements POSITIONNELS ' +
        'le sont)');
      Exit;
    End;
    EmitInstr('LEA EAX,' + CgVarOperand(SI));
    If I > 0 Then
      EmitInstr('ADD EAX,' + IntToStrG(I * ElemSize));
    EmitInstr('PUSH EAX');
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('POP EBX');
    EmitInstr('MOV DWORD PTR [EBX],EAX');
  End;
End;

{ CompileStructCompositeInto : extension structs/methodes (TODO 21) -    }
{ "Nom(cle:val, ...)" (accolades Go notees entre parentheses, meme          }
{ convention que partout dans ce fichier) AFFECTE DIRECTEMENT au symbole            }
{ local SI - EXACTEMENT le meme raisonnement, et la meme restriction               }
{ ("valeur multi-mots, initialiseur DIRECT de ":=" SEULEMENT"), que                    }
{ CompileArrayCompositeInto. Elements POSITIONNELS (sans cle, "Nom(1,2)")               }
{ affectes aux champs DECLARES dans l ordre ; elements a CLE ("Nom(X:1)")                  }
{ resolus par FindFieldWithOffset (champs DIRECTS uniquement - Go n autorise                  }
{ pas une cle PROMUE dans un litteral compose, regle deja respectee ici                          }
{ puisque FindFieldWithOffset essaie toujours les champs directs D ABORD). }
Procedure CompileStructCompositeInto(CE, SI: Integer);
Var TIdx, ArgFirst, ArgCount, I, FIdx, FOfs, ZN: Integer;
    LblZTop, LblZEnd: TString;
Begin
  TIdx     := ExprPool[CE].Extra;
  ArgFirst := ExprPool[CE].ArgFirst;
  ArgCount := ExprPool[CE].ArgCount;

  ZN := TypeTab[TIdx].Size;
  If ZN < 4 Then ZN := 4;
  EmitInstr('XOR EAX,EAX');
  EmitInstr('LEA EDI,' + CgVarOperand(SI));
  EmitInstr('MOV ECX,' + IntToStrG(ZN Div 4));
  LblZTop := CgLabelGen;
  LblZEnd := CgLabelGen;
  EmitLabel(LblZTop);
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + LblZEnd);
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('ADD EDI,4');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + LblZTop);
  EmitLabel(LblZEnd);

  For I := 0 To ArgCount - 1 Do
  Begin
    If ExprArgKey[ArgFirst + I] = '' Then
    Begin
      FIdx := TypeTab[TIdx].FieldFirst + I;
      If (I < 0) Or (I >= TypeTab[TIdx].FieldCount) Then
      Begin
        FatalError('TODO 21 : generateur de code, litteral compose de ' +
          'struct positionnel : trop d''elements');
        Exit;
      End;
      FOfs := FieldPool[FIdx].Offset;
    End
    Else
    Begin
      FIdx := FindFieldWithOffset(TIdx, ExprArgKey[ArgFirst + I], FOfs);
      If FIdx < 0 Then
      Begin
        FatalError('TODO 21 : generateur de code, champ inconnu dans un ' +
          'litteral compose de struct : ' + ExprArgKey[ArgFirst + I]);
        Exit;
      End;
    End;

    EmitInstr('LEA EAX,' + CgVarOperand(SI));
    If FOfs <> 0 Then
      EmitInstr('ADD EAX,' + IntToStrG(FOfs));
    EmitInstr('PUSH EAX');
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('POP EBX');
    EmitInstr('MOV DWORD PTR [EBX],EAX');
  End;
End;

{ CompileStructCompositeIntoAddr/CompileArrayCompositeIntoAddr :         }
{ extension interfaces (TODO 21) - EXACTEMENT les memes deux fonctions           }
{ que CompileStructCompositeInto/CompileArrayCompositeInto ci-dessus,               }
{ mais visant une ADRESSE DE TAS DEJA CALCULEE (EAX au moment de l appel,             }
{ typiquement une allocation _GORT_ALLOC fraiche - CompileBoxValue,                    }
{ boxing d un litteral compose DIRECT, "Shape = Square(Side:4)", qui n a               }
{ pas de VARIABLE adressable a offrir a CompileAddrOf) plutot qu un slot                 }
{ LOCAL (CgVarOperand(SI)) - PUSH cette adresse immediatement pour la                        }
{ duree du remplissage (chaque element peut contenir un appel arbitraire                        }
{ qui clobber EAX/EBX/etc.), la restaure dans EAX avant de rendre la main. }
Procedure CompileStructCompositeIntoAddr(CE: Integer);
Var TIdx, ArgFirst, ArgCount, I, FIdx, FOfs, ZN: Integer;
    LblZTop, LblZEnd: TString;
Begin
  EmitInstr('PUSH EAX');   { [ESP+0] = adresse destination }

  TIdx     := ExprPool[CE].Extra;
  ArgFirst := ExprPool[CE].ArgFirst;
  ArgCount := ExprPool[CE].ArgCount;

  ZN := TypeTab[TIdx].Size;
  If ZN < 4 Then ZN := 4;
  EmitInstr('XOR EAX,EAX');
  EmitInstr('MOV EDI,DWORD PTR [ESP]');
  EmitInstr('MOV ECX,' + IntToStrG(ZN Div 4));
  LblZTop := CgLabelGen;
  LblZEnd := CgLabelGen;
  EmitLabel(LblZTop);
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + LblZEnd);
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('ADD EDI,4');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + LblZTop);
  EmitLabel(LblZEnd);

  For I := 0 To ArgCount - 1 Do
  Begin
    If ExprArgKey[ArgFirst + I] = '' Then
    Begin
      FIdx := TypeTab[TIdx].FieldFirst + I;
      If (I < 0) Or (I >= TypeTab[TIdx].FieldCount) Then
      Begin
        FatalError('TODO 21 : generateur de code, litteral compose de ' +
          'struct positionnel : trop d''elements');
        Exit;
      End;
      FOfs := FieldPool[FIdx].Offset;
    End
    Else
    Begin
      FIdx := FindFieldWithOffset(TIdx, ExprArgKey[ArgFirst + I], FOfs);
      If FIdx < 0 Then
      Begin
        FatalError('TODO 21 : generateur de code, champ inconnu dans un ' +
          'litteral compose de struct : ' + ExprArgKey[ArgFirst + I]);
        Exit;
      End;
    End;

    EmitInstr('MOV EAX,DWORD PTR [ESP]');
    If FOfs <> 0 Then
      EmitInstr('ADD EAX,' + IntToStrG(FOfs));
    EmitInstr('PUSH EAX');
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('POP EBX');
    EmitInstr('MOV DWORD PTR [EBX],EAX');
  End;

  EmitInstr('POP EAX');   { restaure EAX = adresse destination }
End;

Procedure CompileArrayCompositeIntoAddr(CE: Integer);
Var TIdx, ElemTypeIdx, ElemSize, ArgFirst, ArgCount, I, ZN: Integer;
    LblZTop, LblZEnd: TString;
Begin
  EmitInstr('PUSH EAX');   { [ESP+0] = adresse destination }

  TIdx        := ExprPool[CE].Extra;
  ElemTypeIdx := TypeTab[TIdx].ElemTypeIdx;
  ElemSize    := LocalSlotSize(ElemTypeIdx);
  ArgFirst    := ExprPool[CE].ArgFirst;
  ArgCount    := ExprPool[CE].ArgCount;

  ZN := TypeTab[TIdx].Size;
  If ZN < 4 Then ZN := 4;
  EmitInstr('XOR EAX,EAX');
  EmitInstr('MOV EDI,DWORD PTR [ESP]');
  EmitInstr('MOV ECX,' + IntToStrG(ZN Div 4));
  LblZTop := CgLabelGen;
  LblZEnd := CgLabelGen;
  EmitLabel(LblZTop);
  EmitInstr('CMP ECX,0');
  EmitInstr('JLE ' + LblZEnd);
  EmitInstr('MOV DWORD PTR [EDI],EAX');
  EmitInstr('ADD EDI,4');
  EmitInstr('DEC ECX');
  EmitInstr('JMP ' + LblZTop);
  EmitLabel(LblZEnd);

  For I := 0 To ArgCount - 1 Do
  Begin
    If ExprArgKey[ArgFirst + I] <> '' Then
    Begin
      FatalError('TODO 21 : generateur de code, litteral compose de ' +
        'tableau avec cle non couvert (seuls les elements POSITIONNELS ' +
        'le sont)');
      Exit;
    End;
    EmitInstr('MOV EAX,DWORD PTR [ESP]');
    If I > 0 Then
      EmitInstr('ADD EAX,' + IntToStrG(I * ElemSize));
    EmitInstr('PUSH EAX');
    CompileExpr(ExprArgPool[ArgFirst + I]);
    EmitInstr('POP EBX');
    EmitInstr('MOV DWORD PTR [EBX],EAX');
  End;

  EmitInstr('POP EAX');   { restaure EAX = adresse destination }
End;

{ CompileExpr : compile RECURSIVEMENT le noeud E de ExprPool - laisse    }
{ TOUJOURS son resultat dans EAX (convention FIXE, PAS d allocateur de       }
{ registres - meme discipline que DELPHI.PAS/memes projet). Toute forme            }
{ d expression hors de la portee documentee en tete de section (TODO 21)             }
{ s arrete PROPREMENT (FatalError explicite), jamais un plantage/silence.               }
Procedure CompileExpr(E: Integer);
Var SI: Integer; LblE: TString;
Begin
  If E < 0 Then Exit;
  Case ExprPool[E].Kind Of
    EK_INTLIT, EK_RUNELIT, EK_BOOLLIT:
      EmitInstr('MOV EAX,' + IntToStrG(ExprPool[E].IntVal));
    EK_NILLIT:
      EmitInstr('MOV EAX,0');
    EK_STRINGLIT:
      EmitInstr('LEA EAX,[' + ASM_PFX_STRING + IntToStrG(CgStrPoolOfExpr[E]) + ']');
    EK_IDENT:
      Begin
        SI := SymFind(ExprPool[E].NameVal);
        If SI < 0 Then
          FatalError('TODO 21 : generateur de code, identifiant non ' +
            'resolu: ' + ExprPool[E].NameVal)
        Else
          EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(SI));
      End;
    EK_ADDR:
      Begin
        If ExprPool[ExprPool[E].Left].Kind = EK_IDENT Then
        Begin
          SI := SymFind(ExprPool[ExprPool[E].Left].NameVal);
          If SI < 0 Then
            FatalError('TODO 21 : generateur de code, identifiant non ' +
              'resolu ("&"): ' + ExprPool[ExprPool[E].Left].NameVal)
          Else
            EmitInstr('LEA EAX,' + CgVarOperand(SI));
        End
        Else
          FatalError('TODO 21 : generateur de code, "&" non couvert sur ' +
            'cette forme d''expression (voir TODO 22/23)');
      End;
    EK_DEREF:
      Begin
        CompileExpr(ExprPool[E].Left);
        EmitInstr('MOV EAX,DWORD PTR [EAX]');
      End;
    EK_UNARY:
      Begin
        CompileExpr(ExprPool[E].Left);
        If ExprPool[E].Op = '-' Then EmitInstr('NEG EAX')
        Else If ExprPool[E].Op = '!' Then EmitInstr('XOR EAX,1')
        Else If ExprPool[E].Op = '^' Then EmitInstr('NOT EAX')
        Else FatalError('TODO 21 : generateur de code, operateur unaire ' +
          'non couvert: ' + ExprPool[E].Op);
      End;
    EK_BINARY:
      If (ExprPool[E].Op = '&&') Or (ExprPool[E].Op = '||') Then
      Begin
        { court-circuit REEL (le membre DROIT n est evalue QUE si          }
        { necessaire) - meme idiome que DELPHI.PAS/memes projet pour le          }
        { AND/OR booleen, PAS un simple AND/OR bit-a-bit (EmitBinOp,               }
        { reserve aux operandes non booleens comme "&"/"|"). }
        CompileExpr(ExprPool[E].Left);
        LblE := CgLabelGen;
        EmitInstr('TEST EAX,EAX');
        If ExprPool[E].Op = '&&' Then EmitInstr('JZ ' + LblE)
        Else EmitInstr('JNZ ' + LblE);
        CompileExpr(ExprPool[E].Right);
        EmitLabel(LblE);
      End
      Else
      Begin
        CompileExpr(ExprPool[E].Left);
        EmitInstr('PUSH EAX');
        CompileExpr(ExprPool[E].Right);
        EmitInstr('MOV EBX,EAX');
        EmitInstr('POP EAX');
        EmitBinOp(ExprPool[E].Op);
      End;
    EK_CALL:
      CompileCallExpr(E);
    EK_INDEX:
      Begin
        CompileIndexAddr(E);
        EmitInstr('MOV EAX,DWORD PTR [EAX]');
      End;
    EK_SELECTOR:
      Begin
        { extension structs/methodes : lecture d un CHAMP - un champ lui-  }
        { meme de type struct/tableau (multi-mots) ne peut PAS transiter               }
        { par cette voie, meme restriction que EK_COMPOSITE plus bas (aucun                    }
        { SAMPLES\GO\*.go existant ne lit un champ struct/tableau comme une                        }
        { simple valeur - seulement des champs scalaires/pointeur/slice). }
        If (ExprPool[E].TypeIdx >= 0) And
           ((TypeTab[ExprPool[E].TypeIdx].Kind = TYK_STRUCT) Or
            (TypeTab[ExprPool[E].TypeIdx].Kind = TYK_ARRAY)) Then
          FatalError('TODO 21 : generateur de code, lecture d''un champ ' +
            'struct/tableau (valeur multi-mots) non couverte hors d''une ' +
            'affectation directe')
        Else
        Begin
          CompileFieldAddr(E);
          EmitInstr('MOV EAX,DWORD PTR [EAX]');
        End;
      End;
    EK_SLICE:
      CompileSliceExpr(E);
    EK_CONVERT:
      { extension flottants (TODO 21) : conversion explicite "T(x)" -      }
      { SEULE forme couverte ICI : float->int, via l unite FPU elle-meme                }
      { (FISTP arrondit et convertit en une seule instruction) PUIS une                    }
      { relecture depuis un scratch commun (_GORT_FSCRATCH) pour rejoindre               }
      { la convention EAX habituelle - toute AUTRE conversion (int->float,                    }
      { string<->[]byte, etc.) reste un manque PRE-EXISTANT (TODO 14 n a                          }
      { jamais eu de codegen reel, extension ou non). }
      If ExprIsFloatTyped(ExprPool[E].Left) And
         (Not ExprIsFloatTyped(E)) Then
      Begin
        CompileFloatExpr(ExprPool[E].Left);
        EmitInstr('FISTP [' + ASM_PFX_RUNTIME + 'FSCRATCH]');
        EmitInstr('MOV EAX,DWORD PTR [' + ASM_PFX_RUNTIME + 'FSCRATCH]');
      End
      Else
        FatalError('TODO 21 : generateur de code, conversion de type non ' +
          'couverte (seul float->int, via l''extension flottants, l''est)');
    EK_COMPOSITE:
      If (ExprPool[E].Extra >= 0) And (TypeTab[ExprPool[E].Extra].Kind = TYK_SLICE) Then
        CompileSliceComposite(E)
      Else If (ExprPool[E].Extra >= 0) And
              ((TypeTab[ExprPool[E].Extra].Kind = TYK_ARRAY) Or
               (TypeTab[ExprPool[E].Extra].Kind = TYK_STRUCT)) Then
        FatalError('TODO 21 : generateur de code, litteral compose de ' +
          'tableau/struct non couvert HORS d''une initialisation directe ' +
          '":=" (valeur multi-mots, incompatible avec la convention EAX unique)')
      Else
        FatalError('TODO 21 : generateur de code, litteral compose non ' +
          'couvert sur ce type (maps restent TODO 22/23)');
  Else
    FatalError('TODO 21 : generateur de code, forme d''expression non ' +
      'couverte (flottants/maps/interfaces/fermetures/' +
      'canaux restent TODO 22/23)');
  End;
End;

Procedure CompileSwitch(S: Integer); Forward;
Procedure CompileTypeSwitch(S: Integer); Forward;

{ CompileStmt : compile RECURSIVEMENT le noeud S de StmtPool - portee    }
{ documentee en tete de section (TODO 21) ; tout le reste s arrete             }
{ PROPREMENT (FatalError explicite). }
Procedure CompileStmt(S: Integer);
Var
  I, SI, ZN, RgCollTypeIdx, RgElemTypeIdx, RgElemSize : Integer;
  MRCallE, MRCallee, MRFDI, MRSI, MRArgFirst, MRArgCount, HOfs : Integer;
  TAExpr, TATIdx, TAVSI, TAOkSI : Integer;
  RNam  : TString;
  LblElse, LblEnd, LblTop, LblZTop, LblZEnd : TString;
  LblTAMatch, LblTANoMatch, LblTADone : TString;
Begin
  If S < 0 Then Exit;
  Case StmtPool[S].Kind Of
    STK_EMPTY: ;
    STK_FALLTHROUGH: ;   { extension switch/goto : simple marqueur - le VRAI  }
                          { saut est deja emis par CompileSwitch lui-meme            }
                          { (champ CaseClausePool[...].Fallthrough), jamais            }
                          { par ce noeud d instruction. }
    STK_BLOCK:
      For I := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
        CompileStmt(StmtArgPool[I]);
    STK_EXPR:
      CompileExpr(StmtPool[S].Left);
    STK_VARDECL:
      { extension arrays/slices : "var Nom [Type] [= expr]" LOCAL (portee  }
      { fonction) - deux cas par symbole declare (StmtArgPool[i], voir la          }
      { note de section plus haut) : SANS "= expr" -> vraie valeur zero de               }
      { Go, la plage memoire complete (TypeTab[...].Size, TOUJOURS un                        }
      { multiple de 4, voir LocalSlotSize) est remise a zero mot par mot ;                       }
      { AVEC "= expr" -> seule une constante ENTIERE/BOOLEENNE (ConstEvalExpr,                       }
      { TODO 05) est couverte ICI (flottant/chaine restent un manque PRE-                                }
      { EXISTANT, non exerce par aucun SAMPLES\GO\*.go actuel, honnetement                                   }
      { signale plutot que simule). }
      For I := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
      Begin
        SI := StmtArgPool[I];
        If SI < 0 Then Continue;
        If SymTab[SI].HasInit Then
        Begin
          If (SymTab[SI].ConstVal.Kind = CK_INT) Or (SymTab[SI].ConstVal.Kind = CK_BOOL) Then
          Begin
            EmitInstr('MOV EAX,' + IntToStrG(SymTab[SI].ConstVal.IntVal));
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
          End
          Else
            FatalError('TODO 21 : generateur de code, "var" avec valeur ' +
              'initiale non couverte pour ce type (flottant/chaine restent ' +
              'TODO 22/23) : ' + SymTab[SI].Name);
        End
        Else
        Begin
          ZN := TypeTab[SymTab[SI].TypeIdx].Size;
          If ZN < 4 Then ZN := 4;
          EmitInstr('XOR EAX,EAX');
          EmitInstr('LEA EDI,' + CgVarOperand(SI));
          EmitInstr('MOV ECX,' + IntToStrG(ZN Div 4));
          LblZTop := CgLabelGen;
          LblZEnd := CgLabelGen;
          EmitLabel(LblZTop);
          EmitInstr('CMP ECX,0');
          EmitInstr('JLE ' + LblZEnd);
          EmitInstr('MOV DWORD PTR [EDI],EAX');
          EmitInstr('ADD EDI,4');
          EmitInstr('DEC ECX');
          EmitInstr('JMP ' + LblZTop);
          EmitLabel(LblZEnd);
        End;
      End;
    STK_ASSIGN:
      If StmtPool[S].Op <> '=' Then
        FatalError('TODO 21 : generateur de code, operateur d''affectation ' +
          'compose non couvert (seul "=" simple l''est) : ' + StmtPool[S].Op)
      Else If StmtPool[S].ArgCount <> 1 Then
        FatalError('TODO 21 : generateur de code, affectation MULTIPLE non ' +
          'couverte (une seule cible a la fois)')
      Else If ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = EK_INDEX Then
      Begin
        { cible = element de tableau/slice (arr[i] = ... / s[i] = ...) :  }
        { calcule l ADRESSE cible D ABORD, la preserve sur la pile PENDANT      }
        { que la VALEUR (sous-expression arbitraire, peut elle-meme contenir            }
        { un autre index) est evaluee, puis stocke. }
        CompileIndexAddr(StmtArgPool[StmtPool[S].ArgFirst]);
        EmitInstr('PUSH EAX');
        CompileExpr(StmtArgPool2[StmtPool[S].ArgFirst]);
        EmitInstr('POP EBX');
        EmitInstr('MOV DWORD PTR [EBX],EAX');
      End
      Else If ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = EK_SELECTOR Then
      Begin
        { extension structs/methodes : cible = champ (c.Nom = ... /          }
        { a.Nom = ...) - meme schema que EK_INDEX ci-dessus. }
        CompileFieldAddr(StmtArgPool[StmtPool[S].ArgFirst]);
        EmitInstr('PUSH EAX');
        CompileExpr(StmtArgPool2[StmtPool[S].ArgFirst]);
        EmitInstr('POP EBX');
        EmitInstr('MOV DWORD PTR [EBX],EAX');
      End
      Else If ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind = EK_DEREF Then
      Begin
        { extension structs/methodes (pointeurs) : cible = dereferencement  }
        { ("*p = ..."/"**pp = ...") - l ADRESSE cible est la VALEUR du            }
        { pointeur (CompileExpr sur le noeud POINTEUR lui-meme, PAS            }
        { CompileAddrOf) - fonctionne DEJA correctement pour un double               }
        { dereferencement ("**pp"), puisque EK_DEREF.Left d un "**pp" EST                  }
        { lui-meme un noeud EK_DEREF ("*pp"), et CompileExpr sait deja LIRE                    }
        { un EK_DEREF (charge pp, puis derefe une fois - exactement                                }
        { l adresse visee par "**pp"). }
        CompileExpr(ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].Left);
        EmitInstr('PUSH EAX');
        CompileExpr(StmtArgPool2[StmtPool[S].ArgFirst]);
        EmitInstr('POP EBX');
        EmitInstr('MOV DWORD PTR [EBX],EAX');
      End
      Else If ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].Kind <> EK_IDENT Then
        FatalError('TODO 21 : generateur de code, cible d''affectation non ' +
          'couverte (seul un identifiant simple, une indexation, un champ ' +
          'ou un dereferencement l''est)')
      Else
      Begin
        SI := SymFind(ExprPool[StmtArgPool[StmtPool[S].ArgFirst]].NameVal);
        If (SI >= 0) And ExprIsFloatTyped(StmtArgPool2[StmtPool[S].ArgFirst]) Then
        Begin
          { extension flottants : voir la note equivalente de STK_SHORTVAR. }
          CompileFloatExpr(StmtArgPool2[StmtPool[S].ArgFirst]);
          EmitInstr('FSTP ' + CgVarOperand(SI));
        End
        Else If (SI >= 0) And (SymTab[SI].TypeIdx >= 0) And
                (TypeTab[SymTab[SI].TypeIdx].Kind In [TYK_INTERFACE, TYK_ERROR]) Then
        Begin
          { extension interfaces : cible declaree de type interface/error   }
          { - "boite" la source (CompileBoxValue detecte lui-meme si la               }
          { source est deja une interface, auquel cas simple copie). }
          CompileBoxValue(StmtArgPool2[StmtPool[S].ArgFirst]);
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
        End
        Else
        Begin
          CompileExpr(StmtArgPool2[StmtPool[S].ArgFirst]);
          If SI >= 0 Then
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
        End;
      End;
    STK_SHORTVAR:
      If (StmtPool[S].ArgCount > 1) And
         (StmtArgPool2[StmtPool[S].ArgFirst] = StmtArgPool2[StmtPool[S].ArgFirst + 1]) Then
      Begin
        { extension retours multiples (TODO 21) : "r1, r2, ... := F(...)"  }
        { - UN SEUL appel reel (StmtArgPool2[i] EST LE MEME index d              }
        { expression POUR TOUS LES i, ParseSimpleStmt/TODO 08 - signal            }
        { FIABLE, distinct de la forme comma-ok "v, ok := x.(T)" qui                    }
        { pousse elle un OkIdx FRAIS/different pour son second nom, et                     }
        { distinct d une affectation multiple ORDINAIRE "a, b := 1, 2" ou                      }
        { chaque nom a sa PROPRE valeur). Convention "pointeur de sortie                            }
        { cache" (deja documentee au TODO 21, jamais implementee avant                                 }
        { cette extension) : le PREMIER resultat continue de transiter                                    }
        { par EAX comme toujours ; chaque resultat SUIVANT est ECRIT                                          }
        { DIRECTEMENT par le CALLEE (voir STK_RETURN plus bas, meme formule                                        }
        { HOfs) a l ADRESSE de la variable CIBLE elle-meme - RIEN a                                                }
        { "extraire" apres l appel, la variable cible EST deja remplie.                                                }
        MRCallE  := StmtArgPool2[StmtPool[S].ArgFirst];
        MRCallee := ExprPool[MRCallE].Left;
        If (MRCallee < 0) Or (ExprPool[MRCallee].Kind <> EK_IDENT) Then
          FatalError('TODO 21 : generateur de code, retours multiples non ' +
            'couverts sur cette forme d''appel (seul un appel DIRECT a ' +
            'une fonction utilisateur l''est)')
        Else
        Begin
          MRFDI := -1;
          For I := 0 To FuncDefCount - 1 Do
            If FuncDefPool[I].Name = ExprPool[MRCallee].NameVal Then
            Begin
              MRFDI := I;
              Break;
            End;
          If MRFDI < 0 Then
            FatalError('TODO 21 : generateur de code, appel non couvert ' +
              '(retours multiples, fonction inconnue) : ' +
              ExprPool[MRCallee].NameVal)
          Else If TypeTab[FuncDefPool[MRFDI].TypeIdx].ResultCount <> StmtPool[S].ArgCount Then
            FatalError('TODO 21 : generateur de code, retours multiples : ' +
              'nombre de cibles incoherent avec la signature de "' +
              FuncDefPool[MRFDI].Name + '"')
          Else
          Begin
            For I := StmtPool[S].ArgCount - 1 DownTo 1 Do
            Begin
              If StmtArgName[StmtPool[S].ArgFirst + I] = '_' Then
              Begin
                FatalError('TODO 21 : generateur de code, retours ' +
                  'multiples : cible "_" non couverte pour un resultat ' +
                  'AUTRE que le premier (adresse de destination requise)');
                Exit;
              End;
              MRSI := SymFind(StmtArgName[StmtPool[S].ArgFirst + I]);
              If MRSI >= 0 Then
                EmitInstr('LEA EAX,' + CgVarOperand(MRSI))
              Else
                EmitInstr('MOV EAX,0');
              EmitInstr('PUSH EAX');
            End;

            MRArgFirst := ExprPool[MRCallE].ArgFirst;
            MRArgCount := ExprPool[MRCallE].ArgCount;
            For I := MRArgCount - 1 DownTo 0 Do
            Begin
              CompileExpr(ExprArgPool[MRArgFirst + I]);
              EmitInstr('PUSH EAX');
            End;
            EmitInstr('CALL ' + ASM_PFX_FUNC + FuncDefPool[MRFDI].Name);
            EmitInstr('ADD ESP,' +
              IntToStrG((MRArgCount + StmtPool[S].ArgCount - 1) * 4));

            If StmtArgName[StmtPool[S].ArgFirst] <> '_' Then
            Begin
              MRSI := SymFind(StmtArgName[StmtPool[S].ArgFirst]);
              If MRSI >= 0 Then
                EmitInstr('MOV DWORD PTR ' + CgVarOperand(MRSI) + ',EAX');
            End;
          End;
        End;
      End
      Else If (StmtPool[S].ArgCount = 2) And
              (ExprPool[StmtArgPool2[StmtPool[S].ArgFirst]].Kind = EK_TYPEASSERT) And
              (ExprPool[StmtArgPool2[StmtPool[S].ArgFirst]].Extra <> -2) Then
      Begin
        { extension interfaces : "v, ok := x.(T)" - assertion de type       }
        { avec comma-ok (distincte du type SWITCH, marqueur Extra=-2,               }
        { deja exclu ci-dessus) - compare le TypeIdx CONCRET de la boite               }
        { (x, toujours une expression d interface/error) a T ; ok=1 si                  }
        { egalite, sinon 0 (et v recoit alors la valeur ZERO de T, jamais                   }
        { une valeur indeterminee). "v" recoit une COPIE de la boite elle-                    }
        { meme si T est LUI-MEME une interface/error (aucune extraction a               }
        { faire), sinon le contenu du DataPtr (meme regle que                    }
        { CompileBoxValue : un mot, deref supplementaire depuis DataPtr). }
        TAExpr := StmtArgPool2[StmtPool[S].ArgFirst];
        TATIdx := ExprPool[TAExpr].Extra;
        CompileExpr(ExprPool[TAExpr].Left);      { EAX = boite }
        EmitInstr('PUSH EAX');                     { conservee pour la duree du test }
        EmitInstr('MOV EBX,DWORD PTR [ESP]');
        EmitInstr('MOV EBX,DWORD PTR [EBX]');       { EBX = TypeIdx concret }
        LblTAMatch   := CgLabelGen;
        LblTANoMatch := CgLabelGen;
        LblTADone    := CgLabelGen;
        EmitInstr('CMP EBX,' + IntToStrG(TATIdx));
        EmitInstr('JE ' + LblTAMatch);
        EmitInstr('JMP ' + LblTANoMatch);

        EmitLabel(LblTAMatch);
        If TypeTab[TATIdx].Kind In [TYK_INTERFACE, TYK_ERROR] Then
          EmitInstr('MOV EAX,DWORD PTR [ESP]')
        Else
        Begin
          EmitInstr('MOV EAX,DWORD PTR [ESP]');
          EmitInstr('MOV EAX,DWORD PTR [EAX+4]');   { DataPtr }
          EmitInstr('MOV EAX,DWORD PTR [EAX]');      { valeur }
        End;
        If StmtArgName[StmtPool[S].ArgFirst] <> '_' Then
        Begin
          TAVSI := SymFind(StmtArgName[StmtPool[S].ArgFirst]);
          If TAVSI >= 0 Then
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(TAVSI) + ',EAX');
        End;
        If StmtArgName[StmtPool[S].ArgFirst + 1] <> '_' Then
        Begin
          TAOkSI := SymFind(StmtArgName[StmtPool[S].ArgFirst + 1]);
          If TAOkSI >= 0 Then
          Begin
            { "MOV [mem],imm" n est PAS une forme couverte par l assembleur   }
            { (BinEncodeMov, TODO 22 - seul "MOV [mem],reg" l est, la valeur              }
            { passe TOUJOURS par EAX d abord partout ailleurs dans ce                 }
            { fichier) - route l immediat par EAX, meme discipline. }
            EmitInstr('MOV EAX,1');
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(TAOkSI) + ',EAX');
          End;
        End;
        EmitInstr('JMP ' + LblTADone);

        EmitLabel(LblTANoMatch);
        If StmtArgName[StmtPool[S].ArgFirst] <> '_' Then
        Begin
          TAVSI := SymFind(StmtArgName[StmtPool[S].ArgFirst]);
          If TAVSI >= 0 Then
          Begin
            EmitInstr('MOV EAX,0');
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(TAVSI) + ',EAX');
          End;
        End;
        If StmtArgName[StmtPool[S].ArgFirst + 1] <> '_' Then
        Begin
          TAOkSI := SymFind(StmtArgName[StmtPool[S].ArgFirst + 1]);
          If TAOkSI >= 0 Then
          Begin
            EmitInstr('MOV EAX,0');
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(TAOkSI) + ',EAX');
          End;
        End;

        EmitLabel(LblTADone);
        EmitInstr('ADD ESP,4');
      End
      Else
        For I := StmtPool[S].ArgFirst To StmtPool[S].ArgFirst + StmtPool[S].ArgCount - 1 Do
          If StmtArgName[I] = '_' Then
            CompileExpr(StmtArgPool2[I])
          Else
          Begin
            SI := SymFind(StmtArgName[I]);
            { litteral compose de TABLEAU (valeur multi-mots, ne peut pas       }
            { transiter par EAX - voir la note de CompileArrayCompositeInto)          }
            { : ecrit DIRECTEMENT dans le slot de SI plutot que de passer par            }
            { CompileExpr+MOV. }
            If (SI >= 0) And (ExprPool[StmtArgPool2[I]].Kind = EK_COMPOSITE) And
               (ExprPool[StmtArgPool2[I]].Extra >= 0) And
               (TypeTab[ExprPool[StmtArgPool2[I]].Extra].Kind = TYK_ARRAY) Then
              CompileArrayCompositeInto(StmtArgPool2[I], SI)
            Else If (SI >= 0) And (ExprPool[StmtArgPool2[I]].Kind = EK_COMPOSITE) And
               (ExprPool[StmtArgPool2[I]].Extra >= 0) And
               (TypeTab[ExprPool[StmtArgPool2[I]].Extra].Kind = TYK_STRUCT) Then
              CompileStructCompositeInto(StmtArgPool2[I], SI)
            Else If (SI >= 0) And ExprIsFloatTyped(StmtArgPool2[I]) Then
            Begin
              { extension flottants : la VALEUR flottante (pile FPU) est   }
              { stockee DIRECTEMENT (FSTP, qui ecrit ET depile en une             }
              { seule instruction) - jamais via EAX, incompatible avec un                }
              { Double 8 octets. }
              CompileFloatExpr(StmtArgPool2[I]);
              EmitInstr('FSTP ' + CgVarOperand(SI));
            End
            Else
            Begin
              CompileExpr(StmtArgPool2[I]);
              If SI >= 0 Then
                EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
            End;
          End;
    STK_INCDEC:
      If ExprPool[StmtPool[S].Left].Kind <> EK_IDENT Then
        FatalError('TODO 21 : generateur de code, "++"/"--" non couvert ' +
          'sur cette forme d''expression')
      Else
      Begin
        SI := SymFind(ExprPool[StmtPool[S].Left].NameVal);
        If SI < 0 Then
          FatalError('TODO 21 : generateur de code, "++"/"--" cible non resolue')
        Else
        Begin
          EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(SI));
          If StmtPool[S].Op = '++' Then EmitInstr('INC EAX') Else EmitInstr('DEC EAX');
          EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
        End;
      End;
    STK_IF:
      Begin
        If StmtPool[S].Left >= 0 Then CompileStmt(StmtPool[S].Left);
        CompileExpr(StmtPool[S].Extra);
        LblElse := CgLabelGen;
        EmitInstr('TEST EAX,EAX');
        EmitInstr('JZ ' + LblElse);
        CompileStmt(StmtPool[S].Right);
        If StmtPool[S].Extra2 >= 0 Then
        Begin
          LblEnd := CgLabelGen;
          EmitInstr('JMP ' + LblEnd);
          EmitLabel(LblElse);
          CompileStmt(StmtPool[S].Extra2);
          EmitLabel(LblEnd);
        End
        Else
          EmitLabel(LblElse);
      End;
    STK_FOR:
      Begin
        If StmtPool[S].Left >= 0 Then CompileStmt(StmtPool[S].Left);
        LblTop := CgLabelGen;
        LblEnd := CgLabelGen;
        EmitLabel(LblTop);
        If StmtPool[S].Extra >= 0 Then
        Begin
          CompileExpr(StmtPool[S].Extra);
          EmitInstr('TEST EAX,EAX');
          EmitInstr('JZ ' + LblEnd);
        End;
        CompileStmt(StmtPool[S].Right);
        If StmtPool[S].Extra2 >= 0 Then CompileStmt(StmtPool[S].Extra2);
        EmitInstr('JMP ' + LblTop);
        EmitLabel(LblEnd);
      End;
    STK_FORRANGE:
      Begin
        { extension arrays/slices : "for [cle[, valeur]] [:=|=] range      }
        { Collection (Corps)" (accolades Go notees ici entre parentheses          }
        { pour ne pas fermer ce commentaire) - maps/chaines/canaux restent               }
        { hors de                                                                            }
        { portee (cle/valeur DEJA typees correctement pour ces cas par                  }
        { ParseForStmt, mais aucun codegen ne les couvre ICI). Trois            }
        { emplacements de PILE, reserves pour la DUREE ENTIERE de la                  }
        { boucle (le Corps, un bloc arbitraire, laisse TOUJOURS ESP               }
        { inchange a son retour - meme invariant que partout ailleurs                    }
        { dans ce generateur de code) : [ESP+0]=i (index courant),                        }
        { [ESP+4]=Len, [ESP+8]=DataBase (adresse du premier element). }
        RgCollTypeIdx := DerefIfPointer(ExprPool[StmtPool[S].Left].TypeIdx);
        If (RgCollTypeIdx < 0) Or
           ((TypeTab[RgCollTypeIdx].Kind <> TYK_SLICE) And
            (TypeTab[RgCollTypeIdx].Kind <> TYK_ARRAY)) Then
        Begin
          FatalError('TODO 21 : generateur de code, "for range" non ' +
            'couvert sur cette collection (seuls tableaux/slices le sont - ' +
            'chaines/maps/canaux restent TODO 22/23)');
          Exit;
        End;
        RgElemTypeIdx := TypeTab[RgCollTypeIdx].ElemTypeIdx;
        RgElemSize    := LocalSlotSize(RgElemTypeIdx);

        If TypeTab[RgCollTypeIdx].Kind = TYK_ARRAY Then
        Begin
          { "for range p" ou p est *[N]T (pointeur vers tableau) : la        }
          { VALEUR de p EST DEJA l adresse voulue (CompileExpr, PAS               }
          { CompileAddrOf qui donnerait &p, l adresse DU POINTEUR lui-meme) -            }
          { meme regle que CompileFieldAddr/CompileSliceExpr. }
          If (ExprPool[StmtPool[S].Left].TypeIdx >= 0) And
             (TypeTab[ExprPool[StmtPool[S].Left].TypeIdx].Kind = TYK_POINTER) Then
            CompileExpr(StmtPool[S].Left)
          Else
            CompileAddrOf(StmtPool[S].Left);            { EAX = DataBase }
          EmitInstr('PUSH EAX');                        { [ESP+0]=DataBase }
          EmitInstr('MOV EAX,' + IntToStrG(TypeTab[RgCollTypeIdx].ArrayLen));
          EmitInstr('PUSH EAX');                        { [ESP+0]=Len,[ESP+4]=DataBase }
        End
        Else
        Begin
          CompileExpr(StmtPool[S].Left);                { EAX = H (en-tete) }
          EmitInstr('MOV EBX,EAX');
          EmitInstr('MOV EAX,DWORD PTR [EBX]');          { Data }
          EmitInstr('PUSH EAX');                          { [ESP+0]=DataBase }
          EmitInstr('MOV EAX,DWORD PTR [EBX+4]');        { Len }
          EmitInstr('PUSH EAX');                          { [ESP+0]=Len,[ESP+4]=DataBase }
        End;
        EmitInstr('MOV EAX,0');
        EmitInstr('PUSH EAX');                            { [ESP+0]=i,[ESP+4]=Len,[ESP+8]=DataBase }

        LblTop := CgLabelGen;
        LblEnd := CgLabelGen;
        EmitLabel(LblTop);
        EmitInstr('MOV EAX,DWORD PTR [ESP]');             { i }
        EmitInstr('MOV ECX,DWORD PTR [ESP+4]');           { Len }
        EmitInstr('CMP EAX,ECX');
        EmitInstr('JGE ' + LblEnd);

        If (StmtPool[S].NameVal <> '') And (StmtPool[S].NameVal <> '_') Then
        Begin
          SI := SymFind(StmtPool[S].NameVal);
          EmitInstr('MOV EAX,DWORD PTR [ESP]');
          If SI >= 0 Then
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
        End;
        If (StmtPool[S].NameVal2 <> '') And (StmtPool[S].NameVal2 <> '_') Then
        Begin
          SI := SymFind(StmtPool[S].NameVal2);
          EmitInstr('MOV EAX,DWORD PTR [ESP]');           { i }
          EmitInstr('MOV ECX,' + IntToStrG(RgElemSize));
          EmitInstr('IMUL EAX,ECX');
          EmitInstr('MOV EBX,DWORD PTR [ESP+8]');         { DataBase }
          EmitInstr('ADD EBX,EAX');
          EmitInstr('MOV EAX,DWORD PTR [EBX]');
          If SI >= 0 Then
            EmitInstr('MOV DWORD PTR ' + CgVarOperand(SI) + ',EAX');
        End;

        CompileStmt(StmtPool[S].Right);

        EmitInstr('MOV EAX,DWORD PTR [ESP]');
        EmitInstr('INC EAX');
        EmitInstr('MOV DWORD PTR [ESP],EAX');
        EmitInstr('JMP ' + LblTop);
        EmitLabel(LblEnd);
        EmitInstr('ADD ESP,12');
      End;
    STK_RETURN:
      If StmtPool[S].ArgCount > 1 Then
      Begin
        { extension retours multiples (TODO 21) : "return v1, v2, ..." -   }
        { convention "pointeur de sortie cache" (voir aussi STK_SHORTVAR                }
        { ci-dessus, meme formule HOfs) : le PREMIER resultat (v1) transite            }
        { par EAX comme toujours ; chaque resultat SUIVANT (v2, ...) est                  }
        { ECRIT ICI a l adresse fournie par l APPELANT (poussee comme                        }
        { parametre CACHE, APRES tous les VRAIS parametres declares -                            }
        { HOfs = 8 + 4*ParamCount + 4*(i-1) pour le i-eme resultat EXTRA,                            }
        { i=1..ArgCount-1). Calcule les resultats EXTRA D ABORD (aucune                                 }
        { dependance entre eux) pour que v1 soit la DERNIERE chose                                          }
        { calculee juste avant le saut - rien ne peut alors ecraser EAX                                         }
        { apres coup. }
        If TypeTab[CurFuncSig].ResultCount <> StmtPool[S].ArgCount Then
          FatalError('TODO 21 : generateur de code, "return" : nombre de ' +
            'valeurs incoherent avec la signature de la fonction')
        Else
        Begin
          For I := 1 To StmtPool[S].ArgCount - 1 Do
          Begin
            CompileExpr(StmtArgPool[StmtPool[S].ArgFirst + I]);
            HOfs := 8 + 4 * TypeTab[CurFuncSig].ParamCount + 4 * (I - 1);
            EmitInstr('MOV EBX,DWORD PTR [EBP+' + IntToStrG(HOfs) + ']');
            EmitInstr('MOV DWORD PTR [EBX],EAX');
          End;
          CompileExpr(StmtArgPool[StmtPool[S].ArgFirst]);
          EmitInstr('JMP ' + CurRetLabel);
        End;
      End
      Else If StmtPool[S].ArgCount = 1 Then
      Begin
        CompileExpr(StmtArgPool[StmtPool[S].ArgFirst]);
        EmitInstr('JMP ' + CurRetLabel);
      End
      Else
      Begin
        { "return" nu (TODO 08) : Cnt=0 - soit une fonction sans aucun     }
        { resultat (rien a charger), soit UN resultat NOMME (charge sa           }
        { valeur ACTUELLE dans EAX avant de sauter a l epilogue - regle Go              }
        { reelle) - plusieurs resultats nommes restent HORS DE PORTEE.                     }
        If (CurFuncSig >= 0) And (TypeTab[CurFuncSig].ResultCount = 1) Then
        Begin
          RNam := FieldPool[TypeTab[CurFuncSig].ResultFirst].Name;
          SI := SymFind(RNam);
          If SI >= 0 Then
            EmitInstr('MOV EAX,DWORD PTR ' + CgVarOperand(SI));
        End
        Else If (CurFuncSig >= 0) And (TypeTab[CurFuncSig].ResultCount > 1) Then
          FatalError('TODO 21 : generateur de code, "return" nu avec ' +
            'plusieurs resultats nommes non couvert (voir TODO 22/23)');
        EmitInstr('JMP ' + CurRetLabel);
      End;
    STK_SWITCH:
      CompileSwitch(S);
    STK_TYPESWITCH:
      CompileTypeSwitch(S);
    STK_GOTO:
      { extension switch/goto (TODO 21) : etiquette PROPRE a la fonction   }
      { EN COURS de generation (CurGotoLabelPfx, positionne par                       }
      { CompileFuncDef/CompileMethodDef) - deux fonctions differentes                       }
      { peuvent reutiliser le MEME nom d etiquette Go sans collision                            }
      { ASM, puisque le prefixe INCLUT un identifiant unique par fonction. }
      EmitInstr('JMP ' + CurGotoLabelPfx + StmtPool[S].NameVal);
    STK_LABELED:
      Begin
        EmitLabel(CurGotoLabelPfx + StmtPool[S].NameVal);
        CompileStmt(StmtPool[S].Left);
      End;
  Else
    FatalError('TODO 21 : generateur de code, forme d''instruction non ' +
      'couverte (defer/go/select restent TODO 22/23)');
  End;
End;

{ CompileSwitch : extension switch/goto (TODO 21) - "switch [Init;]      }
{ [Tag] (case V1,V2: Corps ; ... ; default: Corps)" (accolades Go notees           }
{ ici entre parentheses pour ne pas fermer ce commentaire) - PAS de table            }
{ sauts (simplicite/correction avant vitesse, meme discipline que tout             }
{ le reste de ce generateur de code) : chaine classique de comparaisons                 }
{ SEQUENTIELLES, deux passes de labels (MAX_SW_CASE bornee - un switch            }
{ plus grand est un FatalError CLAIR, jamais une troncature silencieuse) :          }
{ 1) teste chaque clause NON-default dans l ordre, saute vers son CORPS               }
{ si une valeur correspond, sinon vers le TEST suivant (ou le corps du               }
{ default/la fin s il n y a pas de default) ; 2) emet chaque CORPS dans                  }
{ l ordre de declaration original, "fallthrough" sautant EXPLICITEMENT                    }
{ au corps SUIVANT (jamais un enchainement PHYSIQUE implicite - plus                        }
{ robuste, la position du "default" pouvant differer de son ordre de                            }
{ test). Portee : switch ORDINAIRE (avec ou sans tag) UNIQUEMENT - le                               }
{ type switch (StmtPool[S].Kind=STK_TYPESWITCH) necessite une VRAIE                                     }
{ information de type a l EXECUTION (descripteur de type/interface),                                       }
{ hors de portee de cette extension (voir l en-tete du fichier, TODO 25). }
Const MAX_SW_CASE = 64;
Procedure CompileSwitch(S: Integer);
Var
  CI, CJ, CCnt, HasDefault, DefIdx : Integer;
  TestLbl, BodyLbl : Array[0..MAX_SW_CASE - 1] Of TString;
  NextTgt : Array[0..MAX_SW_CASE] Of TString;
  LblEnd : TString;
  HasTag : Boolean;
Begin
  CCnt := StmtPool[S].ArgCount;
  If CCnt > MAX_SW_CASE Then
  Begin
    FatalError('TODO 21 : generateur de code, "switch" trop grand ' +
      '(MAX_SW_CASE depasse)');
    Exit;
  End;

  If StmtPool[S].Left >= 0 Then CompileStmt(StmtPool[S].Left);

  HasTag := StmtPool[S].Extra >= 0;
  If HasTag Then
  Begin
    CompileExpr(StmtPool[S].Extra);
    EmitInstr('PUSH EAX');   { tag conserve sur la pile pour comparaisons repetees }
  End;

  HasDefault := 0;
  DefIdx := -1;
  For CI := 0 To CCnt - 1 Do
  Begin
    TestLbl[CI] := CgLabelGen;
    BodyLbl[CI] := CgLabelGen;
    If CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
    Begin
      HasDefault := 1;
      DefIdx := CI;
    End;
  End;
  LblEnd := CgLabelGen;

  { NextTgt[CI] = ou sauter quand AUCUNE valeur de la clause NON-default   }
  { CI ne correspond - la PROCHAINE clause NON-default (son TestLbl),                }
  { calcule en parcourant a REBOURS (une clause "default" rencontree en                 }
  { chemin n a JAMAIS son propre TestLbl DEFINI en passe 1 plus bas - la               }
  { sauter est donc INDISPENSABLE, pas une simple optimisation) ; a               }
  { defaut de PROCHAINE clause non-default, le corps du default (s il                    }
  { existe) sinon la fin. }
  If HasDefault = 1 Then NextTgt[CCnt] := BodyLbl[DefIdx] Else NextTgt[CCnt] := LblEnd;
  For CI := CCnt - 1 DownTo 0 Do
  Begin
    NextTgt[CI] := NextTgt[CI + 1];
    If Not CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
      NextTgt[CI] := TestLbl[CI];
  End;
  { NextTgt[CI] ci-dessus donne, pour CHAQUE indice, la cible a utiliser   }
  { EN PARTANT de la clause SUIVANTE (CI+1) - decale d un cran pour                    }
  { l usage reel plus bas (chaque clause saute vers NextTgt[CI+1], PAS               }
  { NextTgt[CI] qui est SA PROPRE entree, non pertinente pour elle-meme). }

  { ---- passe 1 : tests, dans l ordre ---- }
  For CI := 0 To CCnt - 1 Do
    If Not CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
    Begin
      EmitLabel(TestLbl[CI]);
      For CJ := 0 To CaseClausePool[StmtPool[S].ArgFirst + CI].ExprCount - 1 Do
      Begin
        CompileExpr(ExprArgPool[CaseClausePool[StmtPool[S].ArgFirst + CI].ExprFirst + CJ]);
        If HasTag Then
        Begin
          EmitInstr('MOV EBX,DWORD PTR [ESP]');
          EmitInstr('CMP EAX,EBX');
          EmitInstr('JE ' + BodyLbl[CI]);
        End
        Else
        Begin
          EmitInstr('TEST EAX,EAX');
          EmitInstr('JNZ ' + BodyLbl[CI]);
        End;
      End;
      { aucune valeur de CETTE clause n a correspondu : passe a la          }
      { PROCHAINE clause NON-default (dans l ordre), ou au default (s il             }
      { existe) sinon a la fin - NextTgt[CI+1], jamais NextTgt[CI]. }
      EmitInstr('JMP ' + NextTgt[CI + 1]);
    End;

  { ---- passe 2 : corps, dans l ordre ORIGINAL de declaration ---- }
  For CI := 0 To CCnt - 1 Do
  Begin
    EmitLabel(BodyLbl[CI]);
    For CJ := 0 To CaseClausePool[StmtPool[S].ArgFirst + CI].BodyCount - 1 Do
      CompileStmt(StmtArgPool[CaseClausePool[StmtPool[S].ArgFirst + CI].BodyFirst + CJ]);
    If CaseClausePool[StmtPool[S].ArgFirst + CI].Fallthrough And (CI < CCnt - 1) Then
      EmitInstr('JMP ' + BodyLbl[CI + 1])
    Else
      EmitInstr('JMP ' + LblEnd);
  End;

  EmitLabel(LblEnd);
  If HasTag Then EmitInstr('ADD ESP,4');
End;

{ CompileTypeSwitch : extension interfaces (TODO 21) - "switch [v :=]     }
{ x.(type) (case T1: Corps ; ... ; default: Corps)" (accolades Go notees          }
{ entre parentheses ici) - EXACTEMENT le meme squelette de dispatch                }
{ sequentiel que CompileSwitch (voir sa propre note), mais compare le                    }
{ TypeIdx CONCRET de la boite (x est TOUJOURS une expression de type                          }
{ INTERFACE/ERROR, jamais un tag ordinaire) contre des valeurs BRUTES                              }
{ (TypeIdx directement, PAS des index ExprPool - deja documente dans                                   }
{ TCaseClause) - AUCUN "fallthrough" possible dans un vrai type switch                                     }
{ Go (regle du langage, pas une limitation de ce compilateur). "v" (si                                        }
{ lie) recoit une copie du pointeur de boite LUI-MEME dans TOUTES les                                             }
{ clauses (jamais NARROWED vers le type concret specifique - voir la                                                  }
{ note de ParseSwitchStmt : SymFind ne distingue pas deux portees SOEURS                                                  }
{ dans la MEME fonction, donc "v" reste UN SEUL symbole partage, du type                                                     }
{ DECLARE de x). }
Procedure CompileTypeSwitch(S: Integer);
Var
  CI, CJ, CCnt, HasDefault, DefIdx, VSI : Integer;
  TestLbl, BodyLbl : Array[0..MAX_SW_CASE - 1] Of TString;
  NextTgt : Array[0..MAX_SW_CASE] Of TString;
  LblEnd : TString;
Begin
  CCnt := StmtPool[S].ArgCount;
  If CCnt > MAX_SW_CASE Then
  Begin
    FatalError('TODO 21 : generateur de code, "type switch" trop grand ' +
      '(MAX_SW_CASE depasse)');
    Exit;
  End;

  If StmtPool[S].Left >= 0 Then CompileStmt(StmtPool[S].Left);

  CompileExpr(StmtPool[S].Extra);        { EAX = boite (valeur de x) }
  EmitInstr('PUSH EAX');                  { conservee pour la duree du dispatch }

  HasDefault := 0;
  DefIdx := -1;
  For CI := 0 To CCnt - 1 Do
  Begin
    TestLbl[CI] := CgLabelGen;
    BodyLbl[CI] := CgLabelGen;
    If CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
    Begin
      HasDefault := 1;
      DefIdx := CI;
    End;
  End;
  LblEnd := CgLabelGen;

  If HasDefault = 1 Then NextTgt[CCnt] := BodyLbl[DefIdx] Else NextTgt[CCnt] := LblEnd;
  For CI := CCnt - 1 DownTo 0 Do
  Begin
    NextTgt[CI] := NextTgt[CI + 1];
    If Not CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
      NextTgt[CI] := TestLbl[CI];
  End;

  For CI := 0 To CCnt - 1 Do
    If Not CaseClausePool[StmtPool[S].ArgFirst + CI].IsDefault Then
    Begin
      EmitLabel(TestLbl[CI]);
      EmitInstr('MOV EBX,DWORD PTR [ESP]');    { boite }
      EmitInstr('MOV EBX,DWORD PTR [EBX]');     { EBX = TypeIdx concret }
      For CJ := 0 To CaseClausePool[StmtPool[S].ArgFirst + CI].ExprCount - 1 Do
      Begin
        EmitInstr('CMP EBX,' + IntToStrG(
          ExprArgPool[CaseClausePool[StmtPool[S].ArgFirst + CI].ExprFirst + CJ]));
        EmitInstr('JE ' + BodyLbl[CI]);
      End;
      EmitInstr('JMP ' + NextTgt[CI + 1]);
    End;

  For CI := 0 To CCnt - 1 Do
  Begin
    EmitLabel(BodyLbl[CI]);
    If StmtPool[S].NameVal <> '' Then
    Begin
      VSI := SymFind(StmtPool[S].NameVal);
      If VSI >= 0 Then
      Begin
        EmitInstr('MOV EAX,DWORD PTR [ESP]');    { boite, INCHANGEE - voir la note de tete de fonction }
        EmitInstr('MOV DWORD PTR ' + CgVarOperand(VSI) + ',EAX');
      End;
    End;
    For CJ := 0 To CaseClausePool[StmtPool[S].ArgFirst + CI].BodyCount - 1 Do
      CompileStmt(StmtArgPool[CaseClausePool[StmtPool[S].ArgFirst + CI].BodyFirst + CJ]);
    EmitInstr('JMP ' + LblEnd);
  End;

  EmitLabel(LblEnd);
  EmitInstr('ADD ESP,4');
End;

{ CompileFuncDef : genere le corps COMPLET (etiquette+prolog+corps+       }
{ epilog) d une fonction NOMMEE de haut niveau (FuncDefPool) - les            }
{ methodes (MethodDefPool) restent HORS DE PORTEE de ce TODO (aucun               }
{ mecanisme de repartition/appel de methode n est genere - inutile de                 }
{ generer un corps qu aucun appel ne peut jamais atteindre). }
Procedure CompileFuncDef(FDI: Integer);
Var SavedRetLabel: TString;
Begin
  If FuncDefPool[FDI].BodyStmtIdx < 0 Then Exit;
  EmitLabel(ASM_PFX_FUNC + FuncDefPool[FDI].Name);
  EmitProlog(FuncDefPool[FDI].LocalFrameSize);
  SavedRetLabel := CurRetLabel;
  CurRetLabel   := CgLabelGen;
  CurFuncSig    := FuncDefPool[FDI].TypeIdx;
  { extension arrays/slices : borne SymFind (voir sa propre note plus     }
  { haut) aux VRAIS locaux/parametres de CETTE fonction pour la duree de           }
  { son corps SEULEMENT - jamais imbrique (une fonction de haut niveau               }
  { n en contient jamais une autre), simple affectation/remise a Faux            }
  { suffit, sans pile de sauvegarde. }
  CgRestrictSymRange := True;
  CgSymRangeFirst    := FuncDefPool[FDI].SymFirst;
  CgSymRangeLast     := FuncDefPool[FDI].SymLast;
  CurGotoLabelPfx    := ASM_PFX_LABEL + 'U_F' + IntToStrG(FDI) + '_';
  CompileStmt(FuncDefPool[FDI].BodyStmtIdx);
  CgRestrictSymRange := False;
  EmitLabel(CurRetLabel);
  EmitEpilog;
  CurRetLabel := SavedRetLabel;
  EmitBlankLine;
End;

{ MethodAsmLabel : etiquette ASM d une methode - inclut le nom du TYPE    }
{ receveur (depointerise) ET le nom de la methode, contrairement a une   }
{ fonction top-level (ASM_PFX_FUNC+Nom seul) : Go autorise la MEME        }
{ methode ("Area", par exemple) sur PLUSIEURS types differents dans le      }
{ meme programme - une collision serait sinon possible (ASM_PFX_FUNC          }
{ n a jamais eu ce probleme, un nom de fonction top-level est deja                  }
{ unique par construction, TODO 05/08). }
Function MethodAsmLabel(MIdx: Integer): TString;
Var RTIdx: Integer;
Begin
  RTIdx := MethodDefPool[MIdx].RecvTypeIdx;
  If TypeTab[RTIdx].Kind = TYK_POINTER Then RTIdx := TypeTab[RTIdx].ElemTypeIdx;
  MethodAsmLabel := ASM_PFX_METHOD + TypeTab[RTIdx].Name + '_' + MethodDefPool[MIdx].Name;
End;

{ CompileMethodDef : extension structs/methodes (TODO 21) - EXACTEMENT   }
{ le meme squelette que CompileFuncDef (une methode Go est, structurellement,    }
{ une fonction ordinaire avec un receveur en plus, deja enregistre comme               }
{ premier "parametre" a l analyse, RegisterFuncScopeSymbols/ParseFuncDecl,               }
{ TODO 09) - seule l etiquette (MethodAsmLabel, pas ASM_PFX_FUNC+Nom seul)                   }
{ et la table SOURCE (MethodDefPool, pas FuncDefPool) different. }
Procedure CompileMethodDef(MIdx: Integer);
Var SavedRetLabel: TString;
Begin
  If MethodDefPool[MIdx].BodyStmtIdx < 0 Then Exit;
  EmitLabel(MethodAsmLabel(MIdx));
  EmitProlog(MethodDefPool[MIdx].LocalFrameSize);
  SavedRetLabel := CurRetLabel;
  CurRetLabel   := CgLabelGen;
  CurFuncSig    := MethodDefPool[MIdx].TypeIdx;
  CgRestrictSymRange := True;
  CgSymRangeFirst    := MethodDefPool[MIdx].SymFirst;
  CgSymRangeLast     := MethodDefPool[MIdx].SymLast;
  CurGotoLabelPfx    := ASM_PFX_LABEL + 'U_M' + IntToStrG(MIdx) + '_';
  CompileStmt(MethodDefPool[MIdx].BodyStmtIdx);
  CgRestrictSymRange := False;
  EmitLabel(CurRetLabel);
  EmitEpilog;
  CurRetLabel := SavedRetLabel;
  EmitBlankLine;
End;

{ CompileProgram : pilote de haut niveau (TODO 21) - genere un fichier   }
{ .asm COMPLET et coherent (meme structure de segments que DELPHI.PAS,        }
{ memes projet) : entete, .DATA (globaux+chaines), .CODE (runtime puis            }
{ chaque fonction utilisateur), point d entree minimal "_GOSTART". Ce                 }
{ point d entree sera REMPLACE par le vrai runtime embarque/IAT complet                   }
{ du TODO 23 - ici, juste assez pour que le fichier soit un PROGRAMME                        }
{ complet dans le meme dialecte, avant qu un assembleur/lieur (TODO 22)                          }
{ n existe pour le transformer en binaire reel. }
Procedure CompileProgram(Const AsmFileName: TString);
Var I: Integer;
Begin
  CgLabelSeq  := 0;
  CurRetLabel := '';
  CgCollectStrings;
  CgCollectFloats;

  EmitOpen(AsmFileName);
  EmitHeader;
  EmitDataSeg;
  EmitCodeSeg;
  EmitRuntimeLibrary;
  For I := 0 To FuncDefCount - 1 Do
    CompileFuncDef(I);
  For I := 0 To MethodDefCount - 1 Do
    CompileMethodDef(I);

  EmitLabel('_GOSTART');
  EmitInstr('CALL ' + ASM_PFX_FUNC + 'main');
  EmitInstr('PUSH 0');
  EmitInstr('CALL _ExitProcess@4');
  EmitRaw('END _GOSTART');
  EmitClose;
End;

{ ------------------------------------------------------------ }
{ CodegenSelfTest (TODO 21) : meme methode que DELPHI.PAS/memes         }
{ projet (EmitSelfTest/BinSelfTest) - genere un VRAI fichier .asm a          }
{ partir d un extrait Go synthetique (via FuncParseTopLevel, comme                }
{ toute la suite d auto-tests depuis le TODO 08), le RELIT ligne par                  }
{ ligne, et verifie par SOUS-CHAINE que les instructions attendues                       }
{ apparaissent bien (structure du fichier, appel direct, operateurs                         }
{ arithmetique/comparaison, branchement conditionnel) - PAS l EXECUTION                          }
{ reelle du code genere (aucun assembleur/lieur n existe encore, TODO             }
{ 22/23) : c est exactement la meme limite documentee que celle de                   }
{ DELPHI.PAS pour son propre EmitSelfTest.                                                }
{ ------------------------------------------------------------ }

Function CgFileHasSubstring(Const FileName, Sub: TString): Boolean;
Var F: Text; Line: TString; Found: Boolean;
Begin
  Found := False;
  Assign(F, FileName);
  Reset(F);
  While Not Eof(F) Do
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

Procedure CodegenAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('CodegenSelfTest: ' + Label_ + ' a echoue');
End;

Procedure CodegenSelfTest;
Const TmpAsm = 'GOCWCODEGENSELFTEST.$$$';
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Add(a, b int) int {' + Chr(10) + '	return a + b' + Chr(10) + '}' +
    Chr(10) + 'func main() {' + Chr(10) +
    '	x := Add(1, 2)' + Chr(10) +
    '	if x > 0 {' + Chr(10) + '		x = x - 1' + Chr(10) + '	}' + Chr(10) +
    '	fmt.Println("ok")' + Chr(10) + '	_ = x' + Chr(10) + '}');

  CompileProgram(TmpAsm);

  CodegenAssert('en-tete .386/.MODEL FLAT STDCALL present',
    CgFileHasSubstring(TmpAsm, '.386') And
    CgFileHasSubstring(TmpAsm, '.MODEL FLAT, STDCALL'));
  CodegenAssert('sections .DATA et .CODE presentes',
    CgFileHasSubstring(TmpAsm, '.DATA') And CgFileHasSubstring(TmpAsm, '.CODE'));
  CodegenAssert('etiquette de la fonction "Add" presente',
    CgFileHasSubstring(TmpAsm, ASM_PFX_FUNC + 'Add:'));
  CodegenAssert('etiquette de la fonction "main" presente',
    CgFileHasSubstring(TmpAsm, ASM_PFX_FUNC + 'main:'));
  CodegenAssert('"a + b" compile en ADD EAX,EBX (convention EAX/EBX fixe)',
    CgFileHasSubstring(TmpAsm, 'ADD EAX,EBX'));
  CodegenAssert('appel direct "Add(1, 2)" compile en CALL ' + ASM_PFX_FUNC + 'Add',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_FUNC + 'Add'));
  CodegenAssert('"x > 0" compile en une comparaison Jcc materialisant un ' +
    'Booleen dans EAX', CgFileHasSubstring(TmpAsm, 'JG ' + ASM_PFX_LABEL));
  CodegenAssert('"x - 1" (dans le "if") compile en SUB EAX,EBX',
    CgFileHasSubstring(TmpAsm, 'SUB EAX,EBX'));
  CodegenAssert('fmt.Println("ok") appelle le runtime _GORT_PRINTLN_STR',
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_RUNTIME + 'PRINTLN_STR'));
  CodegenAssert('point d''entree _GOSTART present, appelle ' + ASM_PFX_FUNC +
    'main puis ExitProcess',
    CgFileHasSubstring(TmpAsm, '_GOSTART:') And
    CgFileHasSubstring(TmpAsm, 'CALL ' + ASM_PFX_FUNC + 'main') And
    CgFileHasSubstring(TmpAsm, 'CALL _ExitProcess@4'));

  { CgOutF reste ASSOCIE a TmpAsm (Assign fait par EmitOpen) meme APRES     }
  { sa fermeture (EmitClose, deja appelee par CompileProgram) - reutilise           }
  { cette MEME variable-fichier pour Erase, comme FuncParseTopLevel le               }
  { fait deja pour son propre fichier temporaire. }
  Erase(CgOutF);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ TODO 22 - BACKEND BINAIRE .OBJ COFF WIN32                        }
{ ------------------------------------------------------------ }
{ Meme architecture EXACTE que DELPHI.PAS (memes projet, deja           }
{ eprouvee - roadmap lui-meme) : le fichier .asm TEXTE (TODO 21) reste            }
{ la SEULE sortie du generateur de code lui-meme ; ICI, une passe                    }
{ COMPLETEMENT SEPAREE (BinAssembleFile) RELIT ce meme texte, ligne par                  }
{ ligne, et encode chaque instruction en octets REELS (BinEmitInstr,                        }
{ ModRM/SIB) - exactement comme le "AsmAssembleFile" de DELPHI.PAS relit                        }
{ le sien. Portee volontairement scindee sur l ADRESSAGE (pas sur le                                }
{ JEU D INSTRUCTIONS lui-meme, deja couvert au complet pour tout ce que                                 }
{ TODO 21 peut emettre) : seuls le mode registre, "[BASE+disp32]" (TOUJOURS                                 }
{ disp32, jamais disp8, meme simplification que DELPHI.PAS - evite tout                                        }
{ le cas special EBP/SIB=101) et "[etiquette]" absolu (SANS registre de                                            }
{ base) sont encodes - PAS d adressage base+INDEX (SIB avec un second                                                 }
{ registre, ex. feu "[ESI+ECX]" - DELPHI.PAS lui-meme n encode jamais                                                     }
{ cette forme non plus, voir la note de _GORT_STRLEN plus haut, retravaillee                                                 }
{ pour ne plus en avoir besoin).                                                                                                }
{ Fixups a DEUX genres seulement (REL32/ABS32), PAS trois, memes           }
{ constatations que chez DELPHI.PAS (documentees en detail sur place) :          }
{ un "IMP32" separe n apporterait rien ici - un REL32 vers un symbole             }
{ externe non resolu (import Win32) reste simplement un REL32 EN ATTENTE, qui           }
{ devient une VRAIE relocation COFF (le lieur externe s en chargera) au                        }
{ lieu d etre corrige ici ; SEULS les REL32 vers une etiquette LOCALE de                            }
{ la MEME section sont resolus directement ICI (le deplacement relatif                                 }
{ entre deux points d une MEME section est invariant, quel que soit                                        }
{ l endroit ou cette section finira par etre chargee - contrairement a                                        }
{ une adresse ABSOLUE, qui ne peut JAMAIS etre connue avant l edition de                                          }
{ liens, meme pour une cible du meme module : TOUT ABS32 devient donc                                                }
{ TOUJOURS une relocation COFF, sans exception).                                                                         }
{ ------------------------------------------------------------ }

Const
  BINSEC_TEXT = False;
  BINSEC_DATA = True;

Type
  TBinFixKind = (BFX_REL32, BFX_ABS32);

  TBinLabel = Record
    Name   : TString;
    IsData : Boolean;   { Faux = .text (BinCode) ; Vrai = .data (BinData) }
    Ofs    : LongInt;
  End;

  TBinFixup = Record
    IsData     : Boolean;   { section CONTENANT le champ 32 bits a corriger }
    Pos        : LongInt;   { position de ce champ DANS cette section }
    Kind       : TBinFixKind;
    TargetName : TString;
    Resolved   : Boolean;   { Vrai si deja corrige ICI (REL32 local) - EXCLU  }
                             { de la table de relocations COFF ; Faux ->        }
                             { devient une VRAIE relocation (WriteCOFFObj).        }
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
  BinCodeLen    := 0;
  BinDataLen    := 0;
  BinCurIsData  := BINSEC_TEXT;
  BinLabelCount := 0;
  BinFixupCount := 0;
  BinImportCount:= 0;
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
    RegNum    : Integer;    { BOK_REG : 0..7 (EAX..EDI, numerotation ModRM/SIB) }
    ImmVal    : LongInt;    { BOK_IMM }
    BaseReg   : Integer;    { BOK_MEM avec base : 0..7 ; -1 si absolu (etiquette) }
    Disp      : LongInt;    { BOK_MEM avec base : deplacement }
    LabelName : TString;    { BOK_MEM absolu (etiquette entre crochets), OU        }
                             { BOK_LABEL (cible de JMP/Jcc/CALL, ou LEA absolu)         }
    IsByte    : Boolean;    { Vrai si prefixe par "BYTE PTR" (sinon DWORD implicite) }
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

{ BinReg32 : numerotation ModRM/SIB standard 80386 - EAX=0 ECX=1 EDX=2   }
{ EBX=3 ESP=4 EBP=5 ESI=6 EDI=7 (meme convention que DELPHI.PAS, memes          }
{ projet) - -1 si ce n est pas un nom de registre 32 bits reconnu. }
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
{ ci-dessous - reprend fidelement la simplification de DELPHI.PAS               }
{ (memes projet) : TOUJOURS un deplacement complet sur 32 bits quand un             }
{ registre de base est present (jamais Mod=01/disp8), ce qui evite                    }
{ completement le cas particulier EBP/SIB=101 sans perdre de generalite                    }
{ pour ce dont ce compilateur a reellement besoin. Aucun adressage                            }
{ BASE+INDEX (SIB avec un second registre) n est gere - hors de portee                            }
{ documentee (voir l en-tete de section) ; Mem.Kind doit toujours etre                                 }
{ BOK_REG (registre direct) ou BOK_MEM (base+disp32 ou absolu+etiquette).                                  }
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
    { octet SIB, quel que soit Mod (00/01/10) - AUCUN rapport avec le cas          }
    { special EBP/RM=101 documente plus bas, qui lui ne s applique qu a               }
    { Mod=00 - jamais exerce avant l extension arrays/slices (make/append,               }
    { seuls a lire/ecrire des valeurs temporaires directement via [ESP+N]) :               }
    { plante silencieusement en aval (flux d octets desynchronise) sans ce                    }
    { cas particulier, trouve par EXECUTION reelle (segmentation fault),                          }
    { pas par la compilation ni par une relecture du texte .asm. }
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
  BinAddFixup(BFX_ABS32, Mem.LabelName);
End;

{ ------------------------------------------------------------ }
{ Encodeurs par mnemonique (TODO 22) - un PAR forme reellement       }
{ EMISE par le generateur de code (TODO 21) ou la bibliotheque             }
{ runtime (TODO 21) - toute AUTRE forme est un arret propre                  }
{ (FatalError, jamais un octet errone silencieux), exactement le                  }
{ meme principe "portee volontairement restreinte, documentee" que                  }
{ chaque section precedente de ce fichier.                                              }
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
  { destination memoire : "MOV [mem],reg" (jamais "MOV [mem],imm" dans   }
  { ce que le TODO 21 emet - la valeur passe TOUJOURS par EAX d abord). }
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

{ BinEncodeFpuMem : FLD/FSTP/FILD/FISTP - forme UNIQUE (memoire SEULEMENT,   }
{ jamais "ST(i)" comme operande - non emis par ce generateur de code) :               }
{ Opc (DD=reel 64 bits, DB=entier 32 bits) + ModRM (RegSub=champ reg,                     }
{ sous-opcode : 0=charge/FLD-FILD, 3=stocke+pop/FSTP-FISTP) + disp32 -                        }
{ EXACTEMENT la meme forme ModRM/disp32 que MOV/LEA, BinEmitModRM                                 }
{ reutilisee telle quelle (aucune nouvelle logique d adressage). }
Procedure BinEncodeFpuMem(Opc, RegSub: Integer; Const Op1Text: TString);
Var Op1: TBinOperand;
Begin
  Op1 := BinParseOperand(Op1Text);
  If Op1.Kind <> BOK_MEM Then
  Begin
    FatalError('assembleur : forme FLD/FSTP/FILD/FISTP non couverte ' +
      '(memoire SEULEMENT) : ' + Op1Text);
    Exit;
  End;
  BinEmit8(Opc);
  BinEmitModRM(RegSub, Op1);
End;

{ BinEncodeAlu : ADD/SUB/AND/OR/XOR/CMP - deux formes, "reg,reg" (dest=      }
{ champ reg de ModRM, source=r/m - ordre choisi arbitrairement, sans          }
{ consequence pour deux OPERANDES REGISTRE) et "reg,imm32" (groupe 81,             }
{ sous-opcode dans le champ reg de ModRM) - PLUS le cas 8 bits (opcode 80,                }
{ imm8) pour l UNIQUE forme "CMP BYTE PTR [...],imm" de _GORT_STRLEN. }
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

{ BinEncodeShift : SHL/SAR/SHR - SEULEMENT la forme "reg,CL" (comptage    }
{ dans CL, groupe D3) - ce compilateur n emet jamais de decalage par           }
{ une constante litterale immediate. }
Procedure BinEncodeShift(Const Mnemonic, Op1Text, Op2Text: TString);
Var Op1: TBinOperand;
Begin
  If BinTrim(Op2Text) <> 'CL' Then
  Begin
    FatalError('assembleur : forme de decalage non couverte (seul ",CL" ' +
      'est gere) : ' + Op2Text);
    Exit;
  End;
  Op1 := BinParseOperand(Op1Text);
  BinEmit8($D3);
  If Mnemonic = 'SHL' Then BinEmitModRM(4, Op1)
  Else If Mnemonic = 'SAR' Then BinEmitModRM(7, Op1)
  Else If Mnemonic = 'SHR' Then BinEmitModRM(5, Op1)
  Else FatalError('assembleur : mnemonique de decalage non couverte : ' + Mnemonic);
End;

Procedure BinEncodeJmp(Const Op1Text: TString);
Begin
  BinEmit8($E9);
  BinEmit32(0);
  BinAddFixup(BFX_REL32, BinTrim(Op1Text));
End;

{ BinEncodeJcc : forme LONGUE uniquement (0F 8x + disp32), jamais la     }
{ forme courte (7x + disp8) - meme simplification que DELPHI.PAS (memes         }
{ projet) : correcte dans TOUS les cas (une portee plus longue n est               }
{ jamais un probleme), juste pas la plus compacte possible. }
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

{ BinEncodeCall : E8+disp32 - IDENTIQUE que la cible soit une etiquette   }
{ LOCALE (fonction utilisateur, "_GOF_Add") ou un IMPORT externe decore              }
{ stdcall ("_WriteFile@20") - la DISTINCTION ne se fait qu a la resolution               }
{ (BinResolveFixups/WriteCOFFObj), PAR NOM, jamais ici. }
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

{ BinSplitOperands : coupe sur la PREMIERE virgule - sans risque ici    }
{ puisqu aucune forme emise par le TODO 21 ne place jamais de virgule           }
{ a l interieur de crochets (pas d adressage indexe/mis a l echelle,               }
{ voir l en-tete de section). }
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
  If (Mnemonic = 'SHL') Or (Mnemonic = 'SAR') Or (Mnemonic = 'SHR') Then
  Begin
    BinEncodeShift(Mnemonic, Op1, Op2);
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

  { extension flottants (x87, TODO 21) : FLD/FSTP (memoire QWORD - un      }
  { Double, 8 octets) et FILD/FISTP (memoire DWORD - un entier 32 bits,          }
  { conversion via l unite FPU elle-meme) partagent tous la MEME forme               }
  { ModRM/disp32 que MOV/LEA (BinEmitModRM, reutilisee telle quelle) -                  }
  { seuls l opcode et le champ "reg" (sous-opcode) different. FADDP/                        }
  { FSUBP/FMULP/FDIVP (ST(1) := ST(1) op ST(0), PUIS pop - la forme "deux                       }
  { valeurs deja sur la pile FPU, resultat a la place de la premiere"                              }
  { EXACTE dont EmitBinOpFloat a besoin) sont deux octets FIXES, sans                                 }
  { ModRM ni operande a analyser. }
  If Mnemonic = 'FLD' Then Begin BinEncodeFpuMem($DD, 0, Op1); Exit; End;
  If Mnemonic = 'FSTP' Then Begin BinEncodeFpuMem($DD, 3, Op1); Exit; End;
  If Mnemonic = 'FILD' Then Begin BinEncodeFpuMem($DB, 0, Op1); Exit; End;
  If Mnemonic = 'FISTP' Then Begin BinEncodeFpuMem($DB, 3, Op1); Exit; End;
  If Mnemonic = 'FADDP' Then Begin BinEmit8($DE); BinEmit8($C1); Exit; End;
  If Mnemonic = 'FSUBP' Then Begin BinEmit8($DE); BinEmit8($E9); Exit; End;
  If Mnemonic = 'FMULP' Then Begin BinEmit8($DE); BinEmit8($C9); Exit; End;
  If Mnemonic = 'FDIVP' Then Begin BinEmit8($DE); BinEmit8($F9); Exit; End;

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
      { contient jamais de guillemet - deja garanti par le lexeur Go,             }
      { TODO 02) puis emet chaque octet suivi d un NUL terminal unique               }
      { (le ", 0" final n a pas besoin d etre analyse separement : c est                  }
      { TOUJOURS exactement ce que EmitDataSeg ecrit). }
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
{ octets reels - passe COMPLETEMENT SEPAREE de l emission textuelle,                 }
{ exactement comme le "AsmAssembleFile" de DELPHI.PAS (memes projet). }
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

{ ------------------------------------------------------------ }
{ WriteCOFFObj : ecrit un vrai fichier .OBJ COFF Win32          }
{ (IMAGE_FILE_HEADER, Machine=I386) - DEUX sections seulement, .text        }
{ et .data (ni .rdata ni .bss : les litteraux chaine vont directement          }
{ dans .data, meme simplification que DELPHI.PAS/memes projet). Toute            }
{ relocation restante APRES BinResolveFixups (REL32 vers un import                  }
{ externe, ou N IMPORTE QUEL ABS32) devient une VRAIE relocation COFF               }
{ (IMAGE_REL_I386_REL32/DIR32) - au lieur externe de la resoudre.                        }
{ ------------------------------------------------------------ }

{ PE_MACHINE_I386/COFF_REL_I386_DIR32/COFF_REL_I386_REL32/                }
{ COFF_SYM_CLASS_EXTERNAL/COFF_SYM_CLASS_STATIC/PE_SCN_CNT_*/                  }
{ PE_SCN_MEM_* sont DEJA reservees depuis le TODO 01 (constantes                     }
{ PE/COFF "identiques aux autres compilateurs de ce projet") - la                        }
{ combinaison PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ                        }
{ redonne exactement $60000020, et PE_SCN_CNT_INIT_DATA Or                                        }
{ PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE redonne exactement $C0000040 -                                  }
{ inutile de redefinir ces valeurs. }

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

  { table des symboles (18 octets chacun) : .text puis .data (les DEUX      }
  { symboles de SECTION eux-memes, indices 0/1), puis un par etiquette             }
  { (indices 2..2+BinLabelCount-1 - PUBLIC par simplification, aucun               }
  { suivi STATIC/PUBLIC reel, meme choix documente que DELPHI.PAS), puis                }
  { un par import externe (section 0 = non defini ici, au lieur de le                     }
  { resoudre). Chaque nom passe TOUJOURS par la table des chaines (jamais                    }
  { la forme "inline sur 8 octets"), meme simplification que DELPHI.PAS.                        }
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
{ BinEncoderSelfTest (TODO 24) : LACUNE reelle comblee par cet audit -    }
{ BinObjSelfTest/PEExeSelfTest (TODO 22/23) ne verifient que la                  }
{ STRUCTURE d ensemble d un fichier compile (Machine/NumberOfSections/                 }
{ Subsystem/tailles) - jamais un SEUL opcode/ModRM precis. Ici,                              }
{ BinEmitInstr est appelee DIRECTEMENT (BinInit avant chaque cas pour                            }
{ repartir d un tampon .text vide) et BinCode est inspecte OCTET PAR                                 }
{ OCTET contre la valeur EXACTE attendue - le niveau de rigueur qui                                      }
{ aurait le mieux protege contre le genre d erreur d encodage (mauvais                                       }
{ opcode/ModRM) qu aucun auto-test anterieur n aurait pu detecter (les                                           }
{ deux VRAIS bogues trouves au TODO 23 etaient d un AUTRE ordre -                                                    }
{ registre non preserve/bourrage d alignement manquant - mais cette                                                     }
{ lacune PRECISE, elle, restait ouverte jusqu ici). }
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
    'jamais disp8 - meme simplification que DELPHI.PAS)',
    (BinCodeLen = 6) And (BinCode[0] = $8B) And (BinCode[1] = $85) And
    (BinCode[2] = 8) And (BinCode[3] = 0) And (BinCode[4] = 0) And (BinCode[5] = 0));

  BinInit;
  BinEmitInstr('PUSH EAX');
  BinEncAssert('PUSH EAX -> 50', (BinCodeLen = 1) And (BinCode[0] = $50));

  BinInit;
  BinEmitInstr('PUSH EBP');
  BinEncAssert('PUSH EBP -> 55', (BinCodeLen = 1) And (BinCode[0] = $55));

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
    (BinCodeLen = 3) And (BinCode[0] = $0F) And (BinCode[1] = $AF) And
    (BinCode[2] = $C3));

  BinInit;
  BinEmitInstr('CDQ');
  BinEncAssert('CDQ -> 99', (BinCodeLen = 1) And (BinCode[0] = $99));

  BinInit;
  BinEmitInstr('IDIV EBX');
  BinEncAssert('IDIV EBX -> F7 FB',
    (BinCodeLen = 2) And (BinCode[0] = $F7) And (BinCode[1] = $FB));

  BinInit;
  BinEmitInstr('RET');
  BinEncAssert('RET -> C3', (BinCodeLen = 1) And (BinCode[0] = $C3));

  { CALL/Jcc vers une etiquette encore INCONNUE (le cas normal - la     }
  { cible n a pas forcement ete definie AVANT le point d appel/de saut          }
  { dans le fichier .asm) : E8/0F-8x + placeholder 0, PLUS un correctif             }
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
  BinEmitInstr('JE SOMELABEL');
  BinEncAssert('JE etiquette -> 0F 84 + correctif REL32 en attente',
    (BinCodeLen = 6) And (BinCode[0] = $0F) And (BinCode[1] = $84) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_REL32));

  BinInit;
  BinEmitInstr('LEA EAX,[SOMELABEL]');
  BinEncAssert('LEA EAX,[etiquette] -> 8D 05 + correctif ABS32 en attente ' +
    '(etiquette absolue, sans registre de base)',
    (BinCodeLen = 6) And (BinCode[0] = $8D) And (BinCode[1] = 5) And
    (BinFixupCount = 1) And (BinFixups[0].Kind = BFX_ABS32) And
    (BinFixups[0].TargetName = 'SOMELABEL'));

  { re-initialise pour ne pas polluer Run reel }
  BinInit;
End;

{ ------------------------------------------------------------ }
{ BinObjSelfTest (TODO 22) : meme methode que "Todo24SelfTest" de       }
{ DELPHI.PAS (memes projet) - compile un extrait Go synthetique de              }
{ bout en bout (parse -> .asm TODO 21 -> BinAssembleFile/                            }
{ BinResolveFixups/WriteCOFFObj TODO 22), puis RELIT le fichier .obj                     }
{ produit en OCTETS BRUTS et verifie sa signature/structure - PAS que                       }
{ le contenu soit LOGIQUEMENT execute par quoi que ce soit (aucun                                 }
{ lieur/chargeur n existe encore, TODO 23) : exactement la meme limite                              }
{ documentee que celle de DELPHI.PAS pour son propre auto-test binaire.                                 }
{ ------------------------------------------------------------ }

Procedure BinObjAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('BinObjSelfTest: ' + Label_ + ' a echoue');
End;

Procedure BinObjSelfTest;
Const
  TmpAsm = 'GOCWBINSELFTEST.$$$';
  TmpObj = 'GOCWBINSELFTEST.OB$';
Var
  F : File;
  B4 : Array[0..3] Of Byte;
  ObjSize : LongInt;
  I, ResolvedCount : Integer;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Add(a, b int) int {' + Chr(10) + '	return a + b' + Chr(10) + '}' +
    Chr(10) + 'func main() {' + Chr(10) +
    '	x := Add(1, 2)' + Chr(10) + '	_ = x' + Chr(10) +
    '	fmt.Println("ok")' + Chr(10) + '}');

  CompileProgram(TmpAsm);
  BinAssembleFile(TmpAsm);
  BinObjAssert('au moins une etiquette reconnue (BinAssembleFile a bien ' +
    'relu le .asm)', BinLabelCount > 0);
  BinObjAssert('au moins un import externe reconnu (EXTRN)', BinImportCount > 0);
  BinObjAssert('des octets de code REELS ont ete encodes (.text non vide)',
    BinCodeLen > 0);
  BinObjAssert('des octets de donnees REELS ont ete encodes (.data non vide, ' +
    'chaine litterale + constante de fin de ligne)', BinDataLen > 0);

  BinResolveFixups;
  ResolvedCount := 0;
  For I := 0 To BinFixupCount - 1 Do
    If BinFixups[I].Resolved Then Inc(ResolvedCount);
  BinObjAssert('au moins un correctif REL32 LOCAL resolu directement ' +
    '(saut interne/appel a une fonction utilisateur, TODO 22)',
    ResolvedCount > 0);
  BinObjAssert('au moins un correctif reste EN ATTENTE (import externe ' +
    'ou ABS32 - devient une VRAIE relocation COFF)',
    ResolvedCount < BinFixupCount);

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
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ TODO 23 - BACKEND BINAIRE .EXE PE WIN32 ET RUNTIME EMBARQUE      }
{ ------------------------------------------------------------ }
{ Meme architecture EXACTE que WritePEExe de DELPHI.PAS (memes           }
{ projet, deja eprouvee) - reutilise TOUTE l infrastructure Bin*                 }
{ TEXT/DATA du TODO 22 SANS LA MODIFIER (BinCode/BinData/BinLabels/                  }
{ BinFixups/BinImports restent EXACTEMENT ce qu ils etaient) : la SEULE                  }
{ vraie difference .OBJ vs .EXE est COMMENT les correctifs REL32/ABS32                       }
{ sont resolus (BinResolveFixupsForExe, NOUVELLE, plutot que                                     }
{ BinResolveFixups du TODO 22 - un .EXE ne peut laisser AUCUNE                                       }
{ relocation "en attente pour le lieur", contrairement a un .OBJ,                                        }
{ puisqu il n y a PLUS de lieur a ce stade) - et le format du fichier                                        }
{ produit (MZ+PE+IMAGE_OPTIONAL_HEADER32+3 sections .text/.data/.idata                                          }
{ avec table d import/IAT KERNEL32.DLL reelle, PAS 2 sections+table                                                 }
{ de symboles COFF). Point d entree = "_GOSTART" (deja emis par                                                        }
{ CompileProgram, TODO 21) ; runtime embarque = EXACTEMENT celui deja                                                      }
{ ecrit par EmitRuntimeLibrary (TODO 21, _GORT_PRINT_STR/PRINTLN_STR) -                                                        }
{ aucune extension n est faite ici (alloc/panic-recover/slice/map/chan                                                            }
{ restent hors de portee, comme documente depuis le TODO 21 lui-meme) - un    }
{ .EXE genere aujourd hui ne peut executer QUE ce que CompileExpr/                }
{ CompileStmt savent deja compiler). ImageBase $00400000, SectionAlignment                                                                      }
{ 4096, FileAlignment 512, sous-systeme CUI (console) - valeurs                                                                                    }
{ IDENTIQUES a DELPHI.PAS (memes projet, aucune raison de deviner                                                                                       }
{ autrement).                                                                                                                                             }
{ ------------------------------------------------------------ }

{ PE_IMG_BASE/PE_SEC_ALIGN/PE_FILE_ALIGN/PE_MACHINE_I386/PE_OPT_MAGIC_PE32/   }
{ PE_SUBSYS_CUI/PE_SCN_CNT_*/PE_SCN_MEM_*/COFF_SYM_CLASS_*/COFF_REL_I386_*      }
{ sont DEJA reservees depuis le TODO 01 (voir plus haut, section des               }
{ constantes PE/COFF "identiques aux autres compilateurs de ce projet") -              }
{ reutilisees ICI et dans WriteCOFFObj (TODO 22, qui definissait par                        }
{ erreur ses PROPRES doublons locaux - corrige au passage pour la                              }
{ coherence) plutot que d en redefinir de nouvelles. }
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
{ precise, exactement comme DELPHI.PAS (memes projet). }
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
  { (KERNEL32.DLL, simplification documentee, meme choix que DELPHI.PAS/          }
  { memes projet) : 1 descripteur reel + 1 descripteur NUL terminal (20              }
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
  { (aucune table de relocations, TODO 23, n existe pour corriger cela                    }
  { plus tard comme le ferait un VRAI executable relogeable). }
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

  { point d entree : RVA de "_GOSTART" (CompileProgram, TODO 21) - repli   }
  { sur le tout debut de .text si, par une anomalie quelconque, cette             }
  { etiquette precise restait introuvable (ne devrait jamais arriver en             }
  { pratique : CompileProgram l emet TOUJOURS). }
  EntryLI := BinFindLabel('_GOSTART');
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
  { aucun VRAI code de stub DOS, meme simplification que DELPHI.PAS). }
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
  { en-tetes de section) totalisent HdrSize (432 octets ICI - 3                  }
  { sections), MAIS .text ne peut commencer QUE sur la PROCHAINE                       }
  { limite alignee-fichier (PE_FILE_ALIGN) - SANS ce bourrage EXPLICITE,                   }
  { chaque section serait ecrite HdrSizeAligned-HdrSize octets TROP TOT                        }
  { par rapport a ce que les PointerToRawData deja ecrits ci-dessus                               }
  { PROMETTENT, tronquant le fichier final du meme nombre d octets a la                              }
  { fin - EXACTEMENT le bogue qui rendait le tout premier .exe genere                                    }
  { par ce TODO illisible par Windows ("n est pas une application                                          }
  { valide"), trouve en decodant METHODIQUEMENT chaque champ de l en-tete                                       }
  { produit contre sa valeur attendue plutot qu en supposant le fichier                                             }
  { correct simplement parce qu il s ouvrait sans erreur de compilation. }
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
{ que "Todo24SelfTest" de DELPHI.PAS (memes projet) - compile un                 }
{ extrait Go de bout en bout (parse -> .asm -> BinAssembleFile ->                    }
{ BinResolveFixupsForExe -> WritePEExe), puis RELIT le .exe produit en                   }
{ OCTETS BRUTS et verifie sa signature/structure (MZ, PE\0\0 a                              }
{ e_lfanew=64, Machine=I386, Subsystem=CUI, taille de fichier EXACTEMENT                        }
{ un multiple de PE_FILE_ALIGN) - PAS que le fichier s EXECUTE reellement                          }
{ (verifie MANUELLEMENT lors du developpement de ce TODO, voir le journal                             }
{ de memoire - la validation AUTOMATISEE de l execution reelle de chaque                                   }
{ SAMPLES\GO\*.go reste explicitement le travail du TODO 25, exactement                                        }
{ comme le roadmap lui-meme le precise). }
{ ------------------------------------------------------------ }

Procedure PEExeAssert(Const Label_: TString; Cond: Boolean);
Begin
  If Not Cond Then
    FatalError('PEExeSelfTest: ' + Label_ + ' a echoue');
End;

Procedure PEExeSelfTest;
Const
  TmpAsm = 'GOCWPESELFTEST.$$$';
  TmpExe = 'GOCWPESELFTEST.EX$';
Var
  F : File;
  B4 : Array[0..3] Of Byte;
  ExeSize : LongInt;
Begin
  ExprInit; StmtInit; SymInit; TypeInit; FuncDefInit; MethodDefInit;
  FuncParseTopLevel('package main' + Chr(10) +
    'func Add(a, b int) int {' + Chr(10) + '	return a + b' + Chr(10) + '}' +
    Chr(10) + 'func main() {' + Chr(10) +
    '	x := Add(1, 2)' + Chr(10) + '	_ = x' + Chr(10) +
    '	fmt.Println("ok")' + Chr(10) + '}');

  CompileProgram(TmpAsm);
  BinAssembleFile(TmpAsm);
  WritePEExe(TmpExe);

  Assign(F, TmpExe);
  Reset(F, 1);
  ExeSize := FileSize(F);
  BlockRead(F, B4, 4);
  PEExeAssert('signature MZ ($4D,$5A) en tete du .exe',
    (B4[0] = $4D) And (B4[1] = $5A));

  Seek(F, 60);
  BlockRead(F, B4, 4);
  PEExeAssert('e_lfanew=64 (offset 60, DWORD)',
    (B4[0] = 64) And (B4[1] = 0) And (B4[2] = 0) And (B4[3] = 0));

  Seek(F, 64);
  BlockRead(F, B4, 4);
  PEExeAssert('signature PE\0\0 a e_lfanew=64',
    (B4[0] = Ord('P')) And (B4[1] = Ord('E')) And (B4[2] = 0) And (B4[3] = 0));

  Seek(F, 68);
  BlockRead(F, B4, 4);
  PEExeAssert('Machine=I386 ($4C,$01) et NumberOfSections=3 en tete de ' +
    'IMAGE_FILE_HEADER', (B4[0] = $4C) And (B4[1] = $01) And
    (B4[2] = 3) And (B4[3] = 0));

  { IMAGE_OPTIONAL_HEADER32 commence a l offset 88 (64+4+20) ; Subsystem  }
  { y est a son propre offset local 68 (Magic+Linker+SizeOfCode+                  }
  { SizeOfInitData+SizeOfUninitData+EntryPoint+BaseOfCode+BaseOfData+                    }
  { ImageBase+SecAlign+FileAlign+OSVer+ImgVer+SubsysVer+Win32VersionValue+                   }
  { SizeOfImage+SizeOfHeaders+CheckSum = 2+2+4+4+4+4+4+4+4+4+4+2+2+2+2+2+                        }
  { 4+4+4+4 = 68) - donc 88+68=156 en absolu. }
  Seek(F, 156);
  BlockRead(F, B4, 2);
  PEExeAssert('Subsystem=3 (CUI, console) dans IMAGE_OPTIONAL_HEADER32',
    (B4[0] = 3) And (B4[1] = 0));

  Close(F);

  PEExeAssert('fichier .exe de taille EXACTEMENT un multiple de ' +
    'PE_FILE_ALIGN (en-tetes+3 sections toutes alignees-fichier)',
    ExeSize Mod PE_FILE_ALIGN = 0);
  PEExeAssert('fichier .exe de taille plausible (en-tetes + 3 sections ' +
    'avec du contenu reel)', ExeSize >= 4 * PE_FILE_ALIGN);

  Assign(F, TmpExe);
  Erase(F);
  Assign(F, TmpAsm);
  Erase(F);

  { re-initialise les tables globales pour ne pas polluer Run reel }
  ExprInit; StmtInit; SymInit; FuncDefInit; MethodDefInit;
End;

{ ------------------------------------------------------------ }
{ TODO 24 - AUTO-TESTS (SELF-TESTS INTERNES)                       }
{ ------------------------------------------------------------ }
{ Un SelfTest par sous-systeme majeur existe deja - un a chaque TODO           }
{ depuis le TODO 02, jamais reporte a "plus tard" (chaque TODO de ce               }
{ fichier a systematiquement ajoute le sien EN MEME TEMPS que la                       }
{ fonctionnalite elle-meme, jamais apres coup) - ce TODO ne les CREE                       }
{ donc pas, il les REGROUPE (RunAllSelfTests ci-dessous, plutot                                }
{ qu inlines dans Run lui-meme - separe clairement la responsabilite                               }
{ "auto-tests" de la responsabilite "compiler le VRAI fichier .go" de                                  }
{ Run) et COMBLE la seule LACUNE reelle trouvee lors de cet audit :                                        }
{ aucun auto-test existant ne verifie l ENCODAGE 80386 lui-meme OCTET                                          }
{ PAR OCTET pour un mnemonique donne (BinObjSelfTest/PEExeSelfTest,                                                }
{ TODO 22/23, ne verifient que la STRUCTURE d ensemble d un fichier                                                    }
{ compile - Machine/NumberOfSections/Subsystem/tailles - jamais un                                                         }
{ SEUL opcode precis) - ajoute BinEncoderSelfTest pour cela.                                                                   }
{ Noms REELS (colonne gauche) vs noms aspirationnels du TODO 01                                                                    }
{ (colonne droite, ecrits avant que la moindre ligne de parseur                                                                        }
{ n existe - de simples PREVISIONS, jamais un contrat a respecter a la                                                                     }
{ lettre une fois l architecture reelle en place, meme discipline que                                                                          }
{ pour les noms Bin*/Asm* du TODO 22) : LexSelfTest=LexSelfTest,                                                                                   }
{ KeywordSelfTest=KeywordSelfTest, TypeSelfTest=TypeSelfTest,                                                                                          }
{ DeclSelfTest~ParseDeclSelfTest, ExprSelfTest~ParseExprSelfTest,                                                                                          }
{ StmtSelfTest~ParseControlFlowSelfTest, FuncSelfTest~ParseFuncSelfTest,                                                                                       }
{ StructSelfTest~StructMethodSelfTest, InterfaceSelfTest=InterfaceSelfTest,                                                                                        }
{ ArraySelfTest+MapSelfTest~SliceMapSelfTest (scinde en deux, TODO 11/12                                                                                               }
{ separes), DeferPanicSelfTest~DeferPanicRecoverSelfTest,                                                                                                                  }
{ ChannelSelfTest~GoroutineChanSelfTest, StdlibSelfTest=StdlibSelfTest,                                                                                                       }
{ CodegenSelfTest~EmitSelfTest, BinObjSelfTest+PEExeSelfTest~BinSelfTest                                                                                                          }
{ (scinde en deux, .OBJ TODO 22 vs .EXE TODO 23) - PLUS PointerSelfTest/                                                                                                             }
{ StringSelfTest/ErrorSelfTest/PackageSelfTest/SemanticSelfTest, jamais                                                                                                                  }
{ anticipes du tout par la liste aspirationnelle du TODO 01 (ecrite         }
{ avant que pointeurs/chaines/error/paquets/analyse semantique ne                 }
{ soient meme concus). }
{ ------------------------------------------------------------ }

Procedure RunAllSelfTests;
Begin
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
  PointerSelfTest;
  StringSelfTest;
  ChannelSelfTest;
  DeferPanicSelfTest;
  ErrorSelfTest;
  PackageSelfTest;
  SemanticSelfTest;
  StdlibSelfTest;
  CodegenSelfTest;
  BinObjSelfTest;
  PEExeSelfTest;
  BinEncoderSelfTest;
End;

Procedure Run;
Var
  SI : Integer;
  AsmFileName : TString;
Begin
  ErrorCount  := 0;
  WarnCount   := 0;
  TotalLines  := 0;
  OutFOpen    := False;
  LexOpened   := False;
  PrescanMode := False;
  CurFuncSig  := -1;

  RunAllSelfTests;

  { SemanticSelfTest verifie le chemin de rejet "variable/import          }
  { inutilise" en inspectant directement des drapeaux (voir sa propre         }
  { note) et n imprime donc plus rien lui-meme - ce reset defensif de                }
  { WarnCount reste neanmoins utile : il garantit que les statistiques                   }
  { finales ne comptent QUE les avertissements du VRAI fichier compile,                       }
  { auto-tests eux-memes.                                                                 }
  WarnCount := 0;

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

  { "func main" est le point d entree OBLIGATOIRE du package main (TODO   }
  { 18, regle Go reelle) - verifie UNIQUEMENT ici, sur le VRAI fichier             }
  { source en cours de compilation, PAS a l interieur de ParseFileTopLevel               }
  { elle-meme : celle-ci est aussi utilisee par FuncParseTopLevel pour                     }
  { la QUASI-TOTALITE des auto-tests depuis le TODO 08 (StructSelfTest,                       }
  { InterfaceSelfTest, etc.), qui declarent volontairement d autres noms                          }
  { de fonction ("F", "Worker", "Safe", ...) sur des extraits isoles -                                }
  { rendre cette regle obligatoire A CET ENDROIT aurait fait echouer                                      }
  { (Halt) la quasi-totalite des auto-tests existants.                                                       }
  SI := SymFind('main');
  If (SI < 0) Or (SymTab[SI].Kind <> SK_FUNC) Then
    FatalError('fonction "main" manquante (obligatoire dans le package main)');

  If Opts.Verbose Then
  Begin
    WriteLn('Symboles de portee paquet declares : ', SymCount);
    WriteLn('Fonctions de haut niveau declarees  : ', FuncDefCount);
    WriteLn('Methodes declarees                  : ', MethodDefCount);
  End;

  { TODO 21 : genere le fichier .asm - AUCUN assembleur/lieur n existe    }
  { encore (TODO 22/23) pour le transformer en .obj/.exe reel, mais              }
  { c est deja la SORTIE REELLE de ce TODO (titre de la roadmap lui-meme :         }
  { "GENERATEUR DE CODE 80386 ET SORTIE .ASM") - ecrit systematiquement,               }
  { independamment de -asm/-obj (aucun AUTRE format de sortie n existe               }
  { encore pour prendre le relais). Portee VOLONTAIREMENT etroite (voir                 }
  { l en-tete de la section codegen plus haut) : toute construction NON                     }
  { couverte s arrete PROPREMENT via FatalError, jamais un .asm silencieusement                  }
  { faux.                                                                                          }
  { NOTE (message clarifie - l ancien libelle "portee partielle" laissait   }
  { croire, a tort, que CE fichier precis avait rencontre une limite -           }
  { faux : atteindre cette ligne signifie deja que CompileProgram s est                }
  { terminee SANS AUCUN FatalError, donc que ce fichier est ENTIEREMENT              }
  { couvert par le backend, quelles que soient les limites GENERALES du                  }
  { compilateur (TODO 25) qui restent, elles, honnetement rappelees                          }
  { seulement dans le tout dernier message, pas repetees ici comme si                           }
  { elles s appliquaient a CETTE compilation. }
  AsmFileName := ReplaceExt(Opts.SrcFile, '.asm');
  CompileProgram(AsmFileName);
  WriteLn('Code assembleur genere (compilation reussie, aucune limite ',
    'rencontree pour ce fichier) : ', AsmFileName);

  { RELIT ce meme fichier .asm (passe totalement separee, BinAssembleFile,  }
  { TODO 22) pour l encoder en octets 80386 REELS - le TOUT PREMIER fichier             }
  { BINAIRE REEL produit par ce compilateur (TODO 01-20 n avaient jamais                    }
  { rien ecrit d autre que du texte .asm/rien du tout). Opts.ObjOnly (-obj,                     }
  { TODO 01) choisit ENSUITE lequel des deux backends binaires produit le                          }
  { fichier final : .OBJ COFF Win32 (TODO 22 - correctifs REL32 LOCAUX               }
  { seulement resolus, le reste devient une vraie relocation COFF pour un                 }
  { lieur EXTERNE) par defaut si demande, ou .EXE PE Win32 DIRECTEMENT                        }
  { EXECUTABLE (TODO 23 - TOUT REL32 doit disparaitre ICI, runtime                                 }
  { embarque via l IAT KERNEL32.DLL, aucun lieur externe requis) sinon -                              }
  { c est la VALEUR PAR DEFAUT (matche la description de -obj du TODO 01                                 }
  { lui-meme : "SEULEMENT un .OBJ" implique qu un .EXE est le resultat                                        }
  { normal, complet, sans cette option).                                                                        }
  BinAssembleFile(AsmFileName);
  If Opts.ObjOnly Then
  Begin
    BinResolveFixups;
    WriteCOFFObj(Opts.OutFile);
    WriteLn('Fichier objet COFF genere (correctifs externes REL32 ',
      'laisses au lieur, normal pour un .OBJ) : ', Opts.OutFile);
  End
  Else
  Begin
    BinResolveFixupsForExe;
    WritePEExe(Opts.OutFile);
    WriteLn('Fichier executable PE genere - PRET A EXECUTER : ', Opts.OutFile);
  End;

  WriteLn('GOCW32: CE FICHIER a compile ET assemble avec SUCCES, sans ',
    'aucune limite rencontree (', TokenCount, ' tokens, ', SymCount,
    ' symboles, ', FuncDefCount, ' fonctions, ', MethodDefCount, ' methodes).');
  WriteLn('(le compilateur, dans son ensemble, ne couvre pas encore 100% ',
    'du langage Go - un AUTRE fichier utilisant interfaces/maps/goroutines/',
    'canaux/defer/panic/bibliotheque standard etendue pourrait rencontrer ',
    'un arret propre documente ; voir l''en-tete du fichier source, ',
    'section TODO 25, pour la liste exacte)');

  ShowStats;
End;

BEGIN
  Run;
END.
