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
            Fichiers de test couverts (voir SAMPLES\GO\*) :
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
            Runtime embarque (_GORT_*) : start, exit, print
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
