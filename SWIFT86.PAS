{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Swift vers assembleur 8086
}

(* ============================================================
   SWIFT86.PAS - Compilateur Swift vers assembleur 8086
   Turbo Pascal / Free Pascal (-Mtp)
   Cible : MASM .MODEL SMALL, DOS 16 bits

   FEUILLE DE ROUTE - 25 TODOS
   ============================================================

   TODO 01 - INFRASTRUCTURE ET OPTIONS
             TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
             ParseArgs : analyser argv (source.swift [sortie.asm] [-v] [-d] [-w])
             FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
             Detecter l extension .swift du fichier source
             Programme principal : validation des arguments et appel Run
             Version, Date, aide en ligne (option -h)

   TODO 02 - LEXEUR (TOKENS SWIFT)
             TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_STRING,
               TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_INTERP
             LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
             LexScanString : chaine entre guillemets doubles "abc"
               Sequences d echappement : \n \t \r \\ \" \0 \u{NNNN}
             LexScanInterpolation : \(expr) dans une chaine
             Commentaires : // ligne et /* ... */ bloc (imbriques)
             Mots-cles : as associatedtype break case catch class
               continue default defer deinit do else enum extension
               fallthrough false fileprivate for func guard if import
               in init inout internal is let nil open operator
               override private protocol public repeat return self
               Self static struct subscript super switch throw throws
               true try typealias var where while
             Mots-cles contextuels : associativity convenience didSet
               dynamic final get indirect infix lazy left mutating
               nonmutating optional postfix precedence prefix
               Protocol required right set Type unowned weak willSet
             Mode debug -d : affichage de chaque token avec PrintToken

   TODO 03 - LITTERAUX ET CONSTANTES
             Entiers decimaux : 0..65535 (UInt16) ou -32768..32767 (Int16)
             Entiers hexadecimaux : 0xFF, octaux : 0o77, binaires : 0b1010
             Separateur numerique : 1_000_000 (ignorer les underscores)
             Reels : reconnus par le lexeur, traites comme entiers (trunc)
             Chaines : "abc" -> pointeur vers donnees DATA
               Interpolation \(expr) : evaluee et concatenee
               Chaines multi-lignes : """ ... """ (avertissement, traitees comme simple)
             Caracteres : pas de type Character separe, traites comme String de longueur 1
             nil : constante pointeur nul -> AX=0
             true : constante booleenne -> AX=1
             false : constante booleenne -> AX=0

   TODO 04 - OPERATEURS ET PRECEDENCE
             Arithmetiques  : + - * / % (entiers)
             Comparaison    : == != < <= > >=
             Logiques       : && || ! (court-circuit)
             Affectation    : = (assignation)
             Affectation composee : += -= *= /= %=
             Intervalle     : ..< (demi-ouvert) ... (ferme)
             Ternaire       : cond ? exprVrai : exprFaux
             Nil-coalescing : ?? (valeur par defaut si nil)
             Optional chaining : ?. (acces conditionnel)
             Forced unwrap  : ! (suffixe, dereferencement force)
             Casting        : as, as?, as! (conversion de type)
             Unaire         : + - (signe) ! (negation logique) ~ (bitwise NOT)
             Bitwise        : & | ^ ~ << >> (operations bit a bit)
             Precedence (du plus fort au plus faible) :
               1. ! ~ unaire +/-
               2. << >>
               3. * / % &
               4. + - | ^
               5. ..< ...
               6. as as? as!
               7. ?? (nil-coalescing)
               8. == != < <= > >=
               9. && (AND logique)
              10. || (OR logique)
              11. cond ? a : b (ternaire)
              12. = += -= *= /= %= (affectation)

   TODO 05 - TABLE DES SYMBOLES
             TSymKind : SK_LET, SK_VAR, SK_FUNC, SK_PARAM, SK_TYPE,
               SK_STRUCT, SK_CLASS, SK_ENUM, SK_PROTOCOL, SK_CASE
             TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
               Scope, IsPublic, IsPrivate, IsMutating, IsOptional
             SymAdd, SymFind, SymFindInScope, SymMangle
             CurScope : compteur de portee imbriquee (max MAX_SCOPE)
             SymEnterScope / SymLeaveScope : gestion des portees imbriquees
             Qualificateurs : Type.membre -> recherche dans la portee du type
             Niveaux d acces : open, public, internal, fileprivate, private

   TODO 06 - SYSTEME DE TYPES
             TTypeKind : TYK_INT (16 bits signe), TYK_UINT (16 bits non signe),
               TYK_BOOL (8 bits), TYK_STRING (ptr chaine),
               TYK_DOUBLE (stub entier), TYK_FLOAT (stub entier),
               TYK_ARRAY, TYK_DICTIONARY (stub),
               TYK_STRUCT, TYK_CLASS, TYK_ENUM, TYK_PROTOCOL,
               TYK_OPTIONAL, TYK_TUPLE, TYK_FUNC, TYK_VOID, TYK_ANY
             TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
             TypeSizeof : Int=2, UInt=2, Bool=1, String=2 (ptr), ptr=2
             Type inference : deduire le type d une variable a partir de l expression
             Optional<T> : type enveloppe nullable (flag + valeur)
             Tuples : (Int, String) -> acces par .0, .1, etc.
             Type alias : typealias NomAlias = TypeExistant

   TODO 07 - EMETTEUR DE CODE ASM
             TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
             EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
             EmitComment, EmitBlankLine
             LabelGen global (compteur unique _SWL_NNNNN)
             Prefixes : _SWV_ (variable), _SWF_ (fonction), _SWK_ (chaine const),
               _SWRT_ (runtime), _SWL_ (label), _SWT_ (type/vtable),
               _SWS_ (struct data), _SWE_ (enum data)
             EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
             EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
             EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

   TODO 08 - SEGMENT DE DONNEES ET STATIQUES
             TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
               IntVal, StrVal, ElemCount
             DataTab[0..MAX_DATA-1], DataCount
             DataAdd, DataAddStr, DataAddStruct : variantes d ajout
             Variables globales (var au niveau module) : entrees DK_WORD dans DATA
             Constantes let : entrees DK_WORD ou DK_STR (immuables)
             Chaines litterales : DB 'abc',0 dans DATA avec label _SWK_N
             Tables de methodes virtuelles (vtable) pour les classes
             Descripteurs d enumeration : DW code + ptr nom dans DATA

   TODO 09 - VARIABLES ET AFFECTATIONS (let / var)
             let (constante) : valeur immuable, erreur si tentative de modification
             var (variable)  : valeur mutable, modification autorisee
             Variables globales : segment DATA, acces par label _SWV_nom
             Variables locales : pile BP, acces [BP-offset]
             Type annotation : var x: Int = 42 ou let s: String = "abc"
             Type inference  : var x = 42 -> type deduit Int
             Affectation = : ExprLoad + MOV destination, AX
             Affectation composee += -= *= /= %= : charge, operation, store
             Tuples : let (a, b) = (1, 2) -> decomposition sur la pile
             Optionnels : var x: Int? = nil -> flag + valeur (2 mots)

   TODO 10 - EXPRESSIONS PRIMAIRES
             ParsePrimary : literal entier, literal chaine, ident, appel de func
             Acces membre : expr.membre -> offset dans struct/class
             Acces index : expr[i] -> offset dans Array
             Appel de fonction : func(arg1, label: arg2) -> CALL
             Interpolation de chaine : "val=\(x)" -> concatenation runtime
             self : reference a l instance courante (struct/class)
             Self : reference au type courant
             super : reference a la classe parente
             Parentheses : (expr) pour forcer la precedence
             Tuples : (expr1, expr2) -> empiler les valeurs
             Optionnel : expr! (forced unwrap) -> verification + valeur
             Optionnel : expr? (optional chaining) -> test nil + acces
             Nil-coalescing : expr ?? defaut -> valeur ou defaut si nil

   TODO 11 - EXPRESSIONS BINAIRES
             ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
             Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
             Modulo : IDIV -> resultat dans DX (reste) pour %
             Comparaison : CMP + Jcc pour ==, !=, <, <=, >, >=
             Comparaison String : CALL _SWRT_STRCMP -> drapeaux
             Logique && : court-circuit JZ vers false-branch
             Logique || : court-circuit JNZ vers true-branch
             Logique !  : XOR AX,1
             Bitwise : AND/OR/XOR/NOT/SHL/SHR pour & | ^ ~ << >>
             Intervalle ..< : generer (lo, hi-1) pour boucles for-in
             Intervalle ... : generer (lo, hi) pour boucles for-in
             Ternaire : cond ? a : b -> TEST AX / JZ / charge a / JMP / charge b
             Nil-coalescing ?? : TEST AX / JNZ skip / charge defaut
             Casting as : conversion de type (verification statique)
             Casting as? : conversion conditionnelle -> Optional

   TODO 12 - ENTREES/SORTIES (print / readLine)
             print(items..., separator, terminator) :
               print("Hello")      -> CALL _SWRT_PRINTSTR
               print(42)           -> CALL _SWRT_PRINTINT
               print(a, b, c)      -> appels successifs avec separateur " "
               separator: par defaut " " entre les elements
               terminator: par defaut "\n" (CR+LF sous DOS)
             readLine() -> String? :
               INT 21h AH=0Ah (lecture ligne) -> chaine dans buffer
               Retourne Optional<String> (toujours .some sous DOS)
             Emission bas niveau :
               _SWRT_PRINTSTR(SI=msg) : INT 21h AH=40h BX=1 (STDOUT)
               _SWRT_PRINTINT(AX=n)   : CALL _SWRT_NUMTOSTR + ecriture
               _SWRT_PRINTCRLF        : ecriture CR+LF
               _SWRT_READLINE(DI=buf) : INT 21h AH=0Ah -> chaine

   TODO 13 - IF / ELSE IF / ELSE / GUARD / SWITCH
             ParseIfStmt : if cond { stmts } else if cond { stmts } else { stmts }
               Emission TEST AX,AX / JZ pour condition fausse
               Labels : _SWL_ELIF_N, _SWL_ELSE_N, _SWL_ENDIF_N
             ParseGuardStmt : guard cond else { stmts (return/break/continue) }
               Equivalent a if + sortie obligatoire dans le bloc else
               guard let x = optExpr else { return } -> unwrap + test nil
             ParseSwitchStmt : switch expr {
               case val1: stmts
               case val2, val3: stmts
               case let x where cond: stmts (pattern matching)
               case lo...hi: stmts (intervalle)
               default: stmts }
               Emission : CMP + JE pour chaque valeur
               Pas de fallthrough implicite (sauf mot-cle fallthrough)
               Labels : _SWL_CASE_N, _SWL_CDEF_N, _SWL_CSEND_N
             if let / if var : optional binding -> test nil + unwrap

   TODO 14 - BOUCLES : while / repeat-while / for-in / break / continue
             ParseWhileStmt : while cond { stmts }
               Labels : _SWL_WTEST_N, _SWL_WEND_N
             ParseRepeatWhileStmt : repeat { stmts } while cond
               Labels : _SWL_RBEG_N, _SWL_RTEST_N
             ParseForInStmt : for item in collection { stmts }
               for i in 0..<10 : boucle avec intervalle demi-ouvert
               for i in 0...9  : boucle avec intervalle ferme
               for _ in 0..<n  : boucle sans variable (wildcard)
               for (idx, val) in array.enumerated() : (stub simplifie)
               Variable de boucle immuable (let implicite)
               Labels : _SWL_FTEST_N, _SWL_FINCR_N, _SWL_FEND_N
             break : saut vers fin de la boucle englobante
               -> JMP _SWL_WEND_N / _SWL_FEND_N
             continue : saut vers le test/increment de la boucle
               -> JMP _SWL_WTEST_N / _SWL_FINCR_N
             Labeled statements : label: while/for -> break label / continue label
             LoopPush / LoopPop : pile de labels pour break/continue

   TODO 15 - TABLEAUX (Array)
             var arr: [Int] = [1, 2, 3] : tableau litteral
               Taille connue a la compilation -> donnees dans DATA ou pile
             var arr = [Int]() : tableau vide (ptr + count = 0)
             arr.count : nombre d elements -> AX (champ stocke)
             arr.isEmpty : count == 0 -> AX=0|1
             arr[i] : acces par index -> calcul offset (i * sizeof(T))
               Verification de bornes : CMP + JAE -> erreur si hors limites
             arr.append(val) : ajout en fin (stub simplifie, taille fixe max)
             arr.remove(at: i) : suppression (decalage des elements suivants)
             arr.insert(val, at: i) : insertion (decalage des elements)
             for item in arr : iteration -> boucle index 0..<count
             Affectation de tableau : copie element par element ou REP MOVSW
             Tableau multidimensionnel : [[Int]] -> tableau de pointeurs

   TODO 16 - STRUCTURES (struct)
             struct Nom { var champ1: T1; var champ2: T2; ... }
               Taille = somme des sizeof(Ti) alignes
               Acces champ : offset fixe depuis debut de la struct
             init() : constructeur (initialiseur) personnalise
               Memberwise init genere automatiquement si absent
             Methodes : func nom(params) -> T { ... }
               self implicite : premier parametre cache (ptr vers struct)
             mutating func : methode pouvant modifier self
               Passage de self par adresse (var) au lieu de valeur (let)
             Proprietes calculees : var prop: T { get { } set { } }
               get -> appel de fonction retournant valeur
               set -> appel de fonction avec newValue comme parametre
             Semantique de valeur : copie complete lors de l affectation
               Affectation struct = copie champ par champ ou REP MOVSW
             static : membres et methodes de type (pas d instance)

   TODO 17 - FONCTIONS ET CLOSURES
             ParseFuncDecl : func nom(label param: T, ...) -> RetT { stmts }
             Labels d arguments : func greet(person name: String)
               Label externe (person) pour l appelant, interne (name) dans le corps
               _ pour omettre le label externe : func f(_ x: Int)
             Parametres par defaut : func f(x: Int = 0)
             Parametres inout : func swap(_ a: inout Int, _ b: inout Int)
               Passage par adresse (LEA + PUSH ptr)
               Appel : swap(&x, &y)
             Valeur de retour : -> T (MOV AX, valeur + JMP epilogue)
             Retour multiple via tuple : -> (Int, Int)
             Convention d appel : cdecl 16 bits, arguments empiles droite a gauche
             Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
             Epilogue : MOV SP,BP / POP BP / RET
             Fonctions imbriquees : func interne dans func externe
               Acces au cadre englobant via lien statique (ptr vers BP parent)
             Closures (simplifiees) : { (params) -> T in stmts }
               Traitees comme fonctions anonymes avec label genere _SWF_CLOS_N
               Capture de variables : copie des valeurs au moment de la creation

   TODO 18 - ENUMERATIONS (enum)
             enum Nom { case val1, val2, val3 }
               Chaque case = constante entiere (0, 1, 2, ...)
               Comparaison : CMP AX, valeur_case
             enum avec raw values : enum Nom: Int { case a = 1, b = 5 }
               .rawValue : acces a la valeur brute -> AX
               init?(rawValue:) : construction depuis valeur brute -> Optional
             enum avec valeurs associees : enum Nom { case val(Int, String) }
               Stockage : tag (1 mot) + donnees associees (taille max des cases)
               Pattern matching dans switch : case .val(let x, let s)
               Extraction des valeurs associees depuis la pile/memoire
             if case / guard case : pattern matching en dehors de switch
             Methodes sur enum : func sur le type enum (self = valeur courante)
             CaseIterable : protocol pour iterer sur tous les cas (stub)

   TODO 19 - CLASSES ET HERITAGE
             class Nom [: Parent] { var/let/func ... }
               Allocation sur heap : CALL _SWRT_ALLOC(CX=taille) -> AX=ptr
               Reference semantics : assignation copie le pointeur, pas les donnees
             init() / deinit : constructeur et destructeur
               init : allouer + initialiser champs
               deinit : stub (pas de GC reel sur DOS)
             Heritage : class Enfant: Parent { ... }
               Champs du parent suivis des champs de l enfant
               super.init() : appel du constructeur parent
               super.methode() : appel de methode parent
             Vtable (table de methodes virtuelles) :
               Chaque classe a une vtable dans DATA
               Entrees : DW offset de chaque methode
               Heritage : copie de la vtable parent + surcharges
             Appel de methode : obj.method(args)
               MOV BX,[AX] (ptr vtable) / CALL [BX+offset_methode]
               self (premier parametre cache) : PUSH AX avant appel
             override : remplacement d une methode dans la vtable enfant
             Comptage de references (simplifie) :
               _SWRT_RETAIN(AX=ptr) : incrementer compteur
               _SWRT_RELEASE(AX=ptr) : decrementer, liberer si 0
               (Stub : pas de liberation reelle sur DOS 16 bits)
             is : test de type dynamique -> AX=0|1
             as? / as! : conversion de type conditionnelle/forcee

   TODO 20 - PROTOCOLES ET EXTENSIONS
             protocol Nom { func methode(params) -> T; var prop: T { get } }
               Declaration d interface sans implementation
               Pas de stockage propre, seulement des exigences
             Conformite : struct/class Nom: Proto1, Proto2 { ... }
               Verification a la compilation : toutes les exigences remplies
             Extension : extension Nom { func nouvelleMethode() { ... } }
               Ajout de methodes a un type existant
               Pas d ajout de proprietes stockees
             Extension avec conformite : extension Nom: Proto { ... }
               Ajout de conformite a un protocole via extension
             Protocol comme type : var x: Proto -> pointeur + witness table (stub)
               Witness table : table de pointeurs vers les implementations
             Protocoles standard (stubs) :
               CustomStringConvertible : var description: String
               Equatable : == et !=
               Comparable : < <= > >=
               CaseIterable : allCases

   TODO 21 - OPTIONNELS (Optional)
             var x: Int? : Optional<Int> -> flag (1 mot) + valeur (1 mot)
               .none / nil : flag = 0, valeur indefinie
               .some(val)  : flag = 1, valeur = val
             Forced unwrap : x! -> tester flag, erreur fatale si nil
               TEST [BP-flag],1 / JZ _SWL_NILFATAL / MOV AX,[BP-val]
             Optional binding : if let val = x { ... }
               Tester flag + affecter valeur a val si .some
             Guard let : guard let val = x else { return }
               Comme if let mais sortie obligatoire dans else
             Nil-coalescing : x ?? defaut
               Tester flag, utiliser defaut si .none
             Optional chaining : x?.methode()
               Tester flag, sauter l appel si .none, retourner nil
             Implicitly unwrapped : var x: Int! (traite comme x! a chaque usage)
             map / flatMap sur Optional : (stubs simplifies)

   TODO 22 - GESTION D ERREURS (do / try / catch / throw)
             Fonctions throwing : func f() throws -> T
               Convention : retour en AX = valeur, flag d erreur en DX
               DX=0 : succes, DX=code_erreur : erreur levee
             throw expr : lever une erreur
               MOV DX, code_erreur / JMP vers epilogue
             do { try f() } catch pattern { stmts }
               try : appeler la fonction, tester DX apres retour
               catch : si DX != 0, brancher vers le handler
               catch let error : capturer l erreur dans une variable
               catch specific pattern : CMP DX, code + JE handler
             try? : convertir en Optional (nil si erreur)
               Appeler func, si DX!=0 -> AX=0 (flag .none), sinon .some
             try! : crash si erreur (comme forced unwrap)
               Appeler func, si DX!=0 -> CALL _SWRT_PANIC
             defer { stmts } : bloc execute a la sortie de la portee
               Empiler les blocs defer, emettre avant chaque return/throw
               Labels : _SWL_DEFER_N
             Declaration d erreur : enum MyError: Error { case reason }
               Chaque case = code entier distinct

   TODO 23 - GENERIQUES
             func nom<T>(param: T) -> T { ... }
               Instanciation : generation de code pour chaque type concret utilise
               Limitation : types concrets Int, UInt, Bool, String seulement
             struct Nom<T> { var valeur: T; ... }
               Instanciation par type concret : Nom<Int>, Nom<String>
             Contraintes : func f<T: Proto>(x: T)
               Verification que T conforme au protocole Proto
             where clause : func f<T>(x: T) where T: Equatable
               Clause supplementaire de contrainte
             Mecanisme de compilation :
               Substitution du parametre generique par le type concret
               Generation de code specifique pour chaque instanciation
               Prefixe des labels : _SWG_NomType_ pour eviter les collisions
             Limitation : un seul parametre generique par declaration (simplifie)
             Protocoles generiques avec associatedtype (stub minimal)

   TODO 24 - RUNTIME MINIMAL
             _SWRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
             _SWRT_PRINTLN : _SWRT_PRINT + CR+LF via _SW_CRLF DB 13,10,0
             _SWRT_PRINTSTR(SI=str) : afficher chaine terminee par 0
             _SWRT_PRINTINT(AX=n) : CALL _SWRT_NUMTOSTR + ecriture
             _SWRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
             _SWRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
             _SWRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
             _SWRT_CONCAT(SI=src1, DI=src2) : concatenation String -> AX=ptr buf
             _SWRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
             _SWRT_STREQ(SI=str1, DI=str2) : egalite -> AX=0|1
             _SWRT_ALLOC(CX=nb_octets) : allocation heap -> AX=ptr
             _SWRT_RETAIN(AX=ptr) : incrementer compteur de references
             _SWRT_RELEASE(AX=ptr) : decrementer compteur, liberer si 0
             _SWRT_READLINE(DI=buf) : lire ligne clavier -> chaine
             _SWRT_ABS(AX=n) : valeur absolue -> AX
             _SWRT_MAX(AX=a, BX=b) : maximum -> AX
             _SWRT_MIN(AX=a, BX=b) : minimum -> AX
             _SWRT_NILFATAL : affiche 'Fatal error: nil unwrap' + Halt
             _SWRT_IDXFATAL : affiche 'Fatal error: index out of range' + Halt
             _SWRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
             RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
             Heap statique : _SW_HEAP DB 4096 DUP(0) + _SW_HEAPTOP DW 0

   TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
             EmitClose : END _SWF_main dans _TEXT ENDS / DATA ENDS
             Run : pipeline complet LexInit -> ParseTopLevel ->
               EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _SWF_main
             Fichiers SAMPLES\SWIFT\ a creer :
               hello.swift    (print, variables let/var, String, interpolation)
               math.swift     (fonctions, parametres, inout, return, recursion)
               control.swift  (if/else, guard, switch/case, pattern matching)
               loops.swift    (while, repeat-while, for-in, break, continue)
               arrays.swift   (Array, count, append, remove, iteration)
               structs.swift  (struct, init, methodes, mutating, proprietes)
               classes.swift  (class, heritage, override, is, as?, vtable)
               enums.swift    (enum, raw values, valeurs associees, pattern)
               optionals.swift (Optional, if let, guard let, ??, chaining)
               errors.swift   (do/try/catch, throw, defer, try?, try!)
               protos.swift   (protocol, extension, conformite, where)
               generics.swift (func generique, struct generique, contraintes)
             Smoke tests : SWIFT86.EXE -v SAMPLES\SWIFT\*.swift

   ============================================================ *)

Program SWIFT86;

Begin
End.
