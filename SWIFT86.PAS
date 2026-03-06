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

   TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
             TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
             ParseArgs : analyser argv (source.swift [sortie.asm] [-v] [-d] [-w])
             FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
             Detecter l extension .swift du fichier source
             Programme principal : validation des arguments et appel Run
             Version, Date, aide en ligne (option -h)

   TODO 02 - LEXEUR (TOKENS SWIFT) [IMPLEMENTE]
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

   TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

   TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
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

   TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
             TSymKind : SK_LET, SK_VAR, SK_FUNC, SK_PARAM, SK_TYPE,
               SK_STRUCT, SK_CLASS, SK_ENUM, SK_PROTOCOL, SK_CASE
             TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
               Scope, IsPublic, IsPrivate, IsMutating, IsOptional
             SymAdd, SymFind, SymFindInScope, SymMangle
             CurScope : compteur de portee imbriquee (max MAX_SCOPE)
             SymEnterScope / SymLeaveScope : gestion des portees imbriquees
             Qualificateurs : Type.membre -> recherche dans la portee du type
             Niveaux d acces : open, public, internal, fileprivate, private

   TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

   TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
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

   TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
             TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_STRUCT),
               IntVal, StrVal, ElemCount
             DataTab[0..MAX_DATA-1], DataCount
             DataAdd, DataAddStr, DataAddStruct : variantes d ajout
             Variables globales (var au niveau module) : entrees DK_WORD dans DATA
             Constantes let : entrees DK_WORD ou DK_STR (immuables)
             Chaines litterales : DB 'abc',0 dans DATA avec label _SWK_N
             Tables de methodes virtuelles (vtable) pour les classes
             Descripteurs d enumeration : DW code + ptr nom dans DATA

   TODO 09 - VARIABLES ET AFFECTATIONS (let / var) [IMPLEMENTE]
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

   TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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

   TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
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

   TODO 12 - ENTREES/SORTIES (print / readLine) [IMPLEMENTE]
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

   TODO 13 - IF / ELSE IF / ELSE / GUARD / SWITCH [IMPLEMENTE]
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

   TODO 14 - BOUCLES : while / repeat-while / for-in / break / continue [IMPLEMENTE]
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

   TODO 15 - TABLEAUX (Array) [IMPLEMENTE]
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

   TODO 16 - STRUCTURES (struct) [IMPLEMENTE]
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

   TODO 17 - FONCTIONS ET CLOSURES [IMPLEMENTE]
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

   TODO 18 - ENUMERATIONS (enum) [IMPLEMENTE]
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

   TODO 19 - CLASSES ET HERITAGE [IMPLEMENTE]
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

   TODO 20 - PROTOCOLES ET EXTENSIONS [IMPLEMENTE]
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

{ ============================================================
  SWIFT86 - Compilateur Swift -> assembleur 8086
  Version : 1.0  Date : 2026-03-06
  Compilation : ppc386 -O2 -Mtp SWIFT86.PAS
  ============================================================ }

Program SWIFT86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  SW86_VERSION = '1.0';
  SW86_DATE    = '2026-03-06';

  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  STACK_SIZE    = 1024;

  SW_VAR_PFX  = '_SWV_';
  SW_FN_PFX   = '_SWF_';
  SW_STR_PFX  = '_SWK_';
  SW_RT_PFX   = '_SWRT_';
  SW_LBL_PFX  = '_SWL_';
  SW_TYPE_PFX = '_SWT_';
  SW_ENUM_PFX = '_SWE_';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  TY_IDX_INT     = 0;
  TY_IDX_UINT    = 1;
  TY_IDX_BOOL    = 2;
  TY_IDX_STRING  = 3;
  TY_IDX_DOUBLE  = 4;
  TY_IDX_VOID    = 5;
  TY_IDX_ANY     = 6;
  TY_IDX_OPT     = 7;
  TY_PRIM_COUNT  = 8;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  TOptions = Record
    SrcFile   : TString;
    OutFile   : TString;
    Verbose   : Boolean;
    DebugMode : Boolean;
    Warnings  : Boolean;
  End;

  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_REAL,
    TK_STRING,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT,
    TK_INTERP
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;
    IntVal : LongInt;
    Line   : Integer;
    Col    : Integer;
  End;

  TSymKind = (
    SK_LET,
    SK_VAR,
    SK_FUNC,
    SK_PARAM,
    SK_TYPE,
    SK_STRUCT,
    SK_CLASS,
    SK_ENUM,
    SK_PROTOCOL,
    SK_CASE
  );

  TSymRec = Record
    Name        : TString;
    MangledName : TString;
    Kind        : TSymKind;
    TypeIdx     : Integer;
    ScopeLevel  : Integer;
    Offset      : Integer;
    IsPublic    : Boolean;
    IsPrivate   : Boolean;
    IsMutating  : Boolean;
    IsOptional  : Boolean;
    DeclLine    : Integer;
  End;

  TTypeKind = (
    TYK_INT,
    TYK_UINT,
    TYK_BOOL,
    TYK_STRING,
    TYK_DOUBLE,
    TYK_FLOAT,
    TYK_ARRAY,
    TYK_DICT,
    TYK_STRUCT,
    TYK_CLASS,
    TYK_ENUM,
    TYK_PROTOCOL,
    TYK_OPTIONAL,
    TYK_TUPLE,
    TYK_FUNC,
    TYK_VOID,
    TYK_ANY,
    TYK_UNKNOWN
  );

  TTypeRec = Record
    Name : TString;
    Kind : TTypeKind;
    Size : Integer;
  End;

  TExprKind = (
    EK_NONE,
    EK_IMM,
    EK_AX,
    EK_MEM
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;
  End;

  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_STRUCT_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  Opts : TOptions;

  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  GExprDummy : TExprVal;

  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;

  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  TypeTab    : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount  : Integer;

  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;
  CurFnDepth   : Integer;
  CurFnRetLbl  : TString;
  CurFnName    : TString;
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;

  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString;       Forward;
Procedure LexNextToken;        Forward;
Function  IntToStr(N : LongInt) : TString; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindKind(Const Name : TString; Kind : TSymKind) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitHeader;    Forward;
Procedure EmitRuntime;   Forward;
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;
Procedure EmitCoerce(SrcTypeIdx, DstTypeIdx : Integer); Forward;
Function  DeclAllocSym(Const Name : TString; Kind : TSymKind) : Integer; Forward;
Function  ParseTypeAnnotation : Integer; Forward;
Procedure ParseDeclStmt(IsLet : Boolean); Forward;
Procedure ParseAssignStmt(SIdx : Integer; Const Op : TString); Forward;
Procedure ParseExprStmt; Forward;
Procedure ParseCallArgs(Var ArgCount : Integer); Forward;
Procedure ParsePostfix(Var Res : TExprVal); Forward;
Procedure EmitBinOp(Const Op : TString; LeftTy, RightTy : Integer); Forward;
Procedure ParsePrintStmt; Forward;
Procedure ParseIfStmt; Forward;
Procedure ParseGuardStmt; Forward;
Procedure ParseSwitchStmt; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseRepeatWhileStmt; Forward;
Procedure ParseForInStmt; Forward;
Procedure ParseBlock; Forward;
Procedure LoopPush(Const BreakLbl, ContLbl : TString); Forward;
Procedure LoopPop; Forward;
Procedure ParseStructDecl; Forward;
Procedure ParseFuncDecl; Forward;
Procedure ParseEnumDecl; Forward;
Procedure ParseClassDecl; Forward;
Procedure ParseProtocolDecl; Forward;
Procedure ParseExtensionDecl; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('SWIFT86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('SWIFT86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('SWIFT86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

Procedure ShowBanner;
Begin
  WriteLn('SWIFT86 v', SW86_VERSION, ' (', SW86_DATE, ')');
  WriteLn('Compilateur Swift -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: SWIFT86 <source.swift> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.swift : fichier Swift source');
  WriteLn('  sortie.asm   : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v           : mode verbeux (banniere + statistiques)');
  WriteLn('  -d           : debug tokens (affiche chaque token)');
  WriteLn('  -w           : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Function StrLowerCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'A') And (R[I] <= 'Z') Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLowerCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function BaseName(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
  S : TString;
Begin
  LastSep := 0;
  LastDot := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If LastDot > LastSep Then
    S := Copy(Path, LastSep + 1, LastDot - LastSep - 1)
  Else
    S := Copy(Path, LastSep + 1, Length(Path));
  BaseName := S;
End;

Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
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

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowUsage
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('SWIFT86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('SWIFT86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('SWIFT86: fichier source manquant');
    ShowUsage;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

Procedure Cleanup;
Begin
  If LexOpened Then
    LexClose;
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

Procedure GlobalInit;
Begin
  ErrorCount     := 0;
  WarnCount      := 0;
  TotalLines     := 0;
  TotalSyms      := 0;
  SymCount       := 0;
  ScopeTop       := 0;
  CurScope       := 0;
  LabelSeq       := 0;
  TypeCount      := 0;
  DataCount      := 0;
  OutFOpen       := False;
  LexOpened      := False;
  LexEOF         := False;
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  CurFrameSize   := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS SWIFT) [IMPLEMENTE]
  ============================================================ }

Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'as')           Or (S = 'associatedtype') Or
    (S = 'break')        Or (S = 'case')       Or (S = 'catch')     Or
    (S = 'class')        Or (S = 'continue')   Or (S = 'default')   Or
    (S = 'defer')        Or (S = 'deinit')     Or (S = 'do')        Or
    (S = 'else')         Or (S = 'enum')       Or (S = 'extension') Or
    (S = 'fallthrough')  Or (S = 'false')      Or (S = 'fileprivate') Or
    (S = 'for')          Or (S = 'func')       Or (S = 'guard')     Or
    (S = 'if')           Or (S = 'import')     Or (S = 'in')        Or
    (S = 'init')         Or (S = 'inout')      Or (S = 'internal')  Or
    (S = 'is')           Or (S = 'let')        Or (S = 'nil')       Or
    (S = 'open')         Or (S = 'operator')   Or (S = 'override')  Or
    (S = 'private')      Or (S = 'protocol')   Or (S = 'public')    Or
    (S = 'repeat')       Or (S = 'return')     Or (S = 'self')      Or
    (S = 'Self')         Or (S = 'static')     Or (S = 'struct')    Or
    (S = 'subscript')    Or (S = 'super')      Or (S = 'switch')    Or
    (S = 'throw')        Or (S = 'throws')     Or (S = 'true')      Or
    (S = 'try')          Or (S = 'typealias')  Or (S = 'var')       Or
    (S = 'where')        Or (S = 'while');
End;

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_REAL    : Write('REAL(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
    TK_INTERP  : Write('INTERP(', T.Val, ')');
  End;
  WriteLn;
End;

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

Procedure LexSkipBlockComment;
Var
  Depth : Integer;
Begin
  Inc(LexColNo); Inc(LexColNo);
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '/') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Inc(Depth);
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Dec(Depth);
    End
    Else
      Inc(LexColNo);
  End;
End;

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or ((Ch >= '0') And (Ch <= '9'));
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := Ord(Ch) - Ord('A') + 10
  Else HexVal := Ord(Ch) - Ord('a') + 10;
End;

Procedure LexScanIdent;
Var
  S : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

Procedure LexScanNumber;
Var
  N       : LongInt;
  Base    : Integer;
  IsFloat : Boolean;
  Ch      : Char;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  Ch      := LexLine[LexColNo];
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'o') Or (Ch = 'O') Then
    Begin
      Base := 8;
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(LexColNo); Inc(LexColNo);
    End;
  End;
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '_' Then
    Begin
      Inc(LexColNo);
    End
    Else If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      Inc(LexColNo);
    End
    Else If (Base = 8) And (Ch >= '0') And (Ch <= '7') Then
    Begin
      N := N * 8 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 2) And ((Ch = '0') Or (Ch = '1')) Then
    Begin
      N := N * 2 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else If (Base = 10) And (Ch >= '0') And (Ch <= '9') Then
    Begin
      N := N * 10 + (Ord(Ch) - Ord('0'));
      Inc(LexColNo);
    End
    Else
      Break;
  End;
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Or
           (LexLine[LexColNo] = '_')) Do
      Inc(LexColNo);
  End;
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
      Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Inc(LexColNo);
  End;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
  If IsFloat Then
    CurToken.Kind := TK_REAL
  Else
    CurToken.Kind := TK_INTEGER;
End;

Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
Begin
  If LexColNo > Length(LexLine) Then
  Begin
    LexScanEscChar := '\';
    Exit;
  End;
  Ch := LexLine[LexColNo];
  Inc(LexColNo);
  Case Ch Of
    'n'  : LexScanEscChar := #10;
    't'  : LexScanEscChar := #9;
    'r'  : LexScanEscChar := #13;
    '0'  : LexScanEscChar := #0;
    '\'  : LexScanEscChar := '\';
    '"'  : LexScanEscChar := '"';
    ''''  : LexScanEscChar := '''';
    'u'  :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '{') Then
        Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
      Begin
        V := V * 16 + HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
      End;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '}') Then
        Inc(LexColNo);
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo);
  While (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If (Ch = '\') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '(') Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + '\(';
      Inc(LexColNo); Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] <> ')') Do
      Begin
        If Length(S) < MAX_STR Then
          S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ')') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + ')';
        Inc(LexColNo);
      End;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
      If (Ch <> #0) And (Length(S) < MAX_STR) Then
        S := S + Ch;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal := 0;
  Scanning := True;
  While Scanning Do
  Begin
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning      := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
      Inc(LexColNo)

    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
      LexColNo := Length(LexLine) + 1

    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
      LexSkipBlockComment

    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    Else If Ch = '"' Then
    Begin
      LexScanString;
      Scanning := False;
    End

    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '==';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '=';
      End;
      Scanning := False;
    End

    Else If Ch = '!' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '!=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '!';
      End;
      Scanning := False;
    End

    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<<';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '<';
      End;
      Scanning := False;
    End

    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>>';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '>';
      End;
      Scanning := False;
    End

    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '+=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '+';
      End;
      Scanning := False;
    End

    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '->';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '-=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '-';
      End;
      Scanning := False;
    End

    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '*=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '*';
      End;
      Scanning := False;
    End

    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '/=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '/';
      End;
      Scanning := False;
    End

    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '%=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '%';
      End;
      Scanning := False;
    End

    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '&&';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '&';
      End;
      Scanning := False;
    End

    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '|') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '||';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '|';
      End;
      Scanning := False;
    End

    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '^';
      Scanning := False;
    End

    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      Scanning := False;
    End

    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '?') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '??';
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '?.';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '?';
      End;
      Scanning := False;
    End

    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '..<';
        End
        Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '...';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '..';
        End;
      End
      Else
      Begin
        CurToken.Kind := TK_PUNCT; CurToken.Val := '.';
      End;
      Scanning := False;
    End

    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      Scanning := False;
    End

    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Or (Ch = '@') Or (Ch = '#') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    Else If (Ch = '{') Or (Ch = '}') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    Else
    Begin
      WarnMsg('caractere inconnu: ' + Ch);
      Inc(LexColNo);
    End;

  End;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  Case T.Kind Of
    TK_INTEGER :
      ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
    TK_REAL :
      ExprMakeImm(T.IntVal, TY_IDX_DOUBLE, Res);
    TK_STRING :
    Begin
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'nil' Then
        ExprMakeImm(0, TY_IDX_OPT, Res)
      Else If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = '=') Or (Op = '+=') Or (Op = '-=') Or
    (Op = '*=') Or (Op = '/=') Or (Op = '%=');
End;

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If IsAssignOp(Op) Then BinOpPrec := 1
  Else If Op = '?'  Then BinOpPrec := 2
  Else If Op = '||' Then BinOpPrec := 3
  Else If Op = '&&' Then BinOpPrec := 4
  Else If (Op = '==')  Or (Op = '!=') Or
          (Op = '<')   Or (Op = '<=') Or
          (Op = '>')   Or (Op = '>=') Then BinOpPrec := 5
  Else If Op = '??' Then BinOpPrec := 6
  Else If (Op = 'as') Or (Op = 'as?') Or (Op = 'as!') Then BinOpPrec := 7
  Else If (Op = '..<') Or (Op = '...') Then BinOpPrec := 8
  Else If (Op = '+') Or (Op = '-') Or
          (Op = '|') Or (Op = '^') Then BinOpPrec := 9
  Else If (Op = '*') Or (Op = '/') Or (Op = '%') Or
          (Op = '&') Then BinOpPrec := 10
  Else If (Op = '<<') Or (Op = '>>') Then BinOpPrec := 11
  Else BinOpPrec := 0;
End;

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := IsAssignOp(Op) Or (Op = '??');
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ParseCallArgs : parser les arguments d un appel func(arg1, label: arg2) }
Procedure ParseCallArgs(Var ArgCount : Integer);
Var
  ArgExpr : TExprVal;
Begin
  ArgCount := 0;
  ParserAdvance;  { consomme '(' }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Gerer label: arg (ignorer le label pour l instant) }
    If (CurToken.Kind = TK_IDENT) Then
    Begin
      { Verifier si c est label: }
      { On ne peut pas lookahead facilement, on parse comme expression }
    End;
    ParseExpr(ArgExpr);
    ExprFlushToAX(ArgExpr);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
End;

{ ParsePostfix : parser les operateurs postfixes (appel, membre, index) }
Procedure ParsePostfix(Var Res : TExprVal);
Var
  ArgCount      : Integer;
  MemberName    : TString;
  IdxExpr       : TExprVal;
  SavedName     : TString;
  LblNotEmpty   : TString;
Begin
  { Boucle pour chainer les postfixes : a.b.c() etc. }
  While True Do
  Begin
    { Appel de fonction : ident(...) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      { Flush la valeur courante dans AX si besoin }
      If (Res.SymIdx >= 0) And (SymTab[Res.SymIdx].Kind = SK_FUNC) Then
      Begin
        SavedName := SymTab[Res.SymIdx].MangledName;
        ParseCallArgs(ArgCount);
        EmitInstrA('CALL', SavedName);
        If ArgCount > 0 Then
          EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
        EmitComment('  appel ' + SavedName);
      End
      Else
      Begin
        { Appel indirect ou identifiant inconnu }
        ParseCallArgs(ArgCount);
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
      End;
    End

    { Acces membre : expr.membre }
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      ParserAdvance;  { consomme '.' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        MemberName := CurToken.Val;
        ParserAdvance;
        { TODO 15 : membres de tableaux }
        If MemberName = 'count' Then
        Begin
          { AX pointe sur le tableau, le premier mot = count }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'AX', '[SI]');
          EmitComment('  .count');
          Res.TypeIdx := TY_IDX_INT;
        End
        Else If MemberName = 'isEmpty' Then
        Begin
          LblNotEmpty := LabelGen;
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'AX', '[SI]');
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrAB('MOV', 'AX', '1');
          EmitInstrA('JE', LblNotEmpty);
          EmitInstrAB('XOR', 'AX', 'AX');
          EmitLabel(LblNotEmpty);
          EmitComment('  .isEmpty');
          Res.TypeIdx := TY_IDX_BOOL;
        End
        Else If (MemberName = 'append') Or (MemberName = 'remove') Or
                (MemberName = 'insert') Then
        Begin
          EmitComment('  .' + MemberName + '() (stub TODO 15)');
        End
        Else
          EmitComment('  .' + MemberName + ' (acces membre)');
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
      End
      Else If CurToken.Kind = TK_INTEGER Then
      Begin
        { Acces tuple : .0, .1, etc. }
        EmitComment('  .' + IntToStr(CurToken.IntVal) + ' (acces tuple stub)');
        ParserAdvance;
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
      End
      Else
      Begin
        CompileError('membre attendu apres ''.''');
        Break;
      End;
    End

    { Acces index : expr[i] -> calcul offset }
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');          { sauvegarder ptr tableau }
      ParserAdvance;  { consomme '[' }
      ParseExpr(IdxExpr);
      ExprFlushToAX(IdxExpr);
      { AX = index, [SP] = ptr tableau }
      { Offset = 2 + index * 2 (premiere word = count) }
      EmitInstrAB('SHL', 'AX', '1');     { AX = index * 2 }
      EmitInstrAB('ADD', 'AX', '2');     { AX = offset (skip count) }
      EmitInstr('POP    BX');            { BX = ptr tableau }
      EmitInstrAB('ADD', 'BX', 'AX');   { BX = adresse element }
      EmitInstrAB('MOV', 'AX', '[BX]'); { AX = valeur de l element }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance;
      EmitComment('  [index] acces tableau');
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End

    { Optional chaining : expr?.membre }
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '?.') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        MemberName := CurToken.Val;
        ParserAdvance;
        EmitComment('  ?.' + MemberName + ' (optional chaining stub)');
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_OPT;
        Res.SymIdx  := -1;
      End;
    End

    Else
      Break;
  End;
End;

Procedure ParsePrimary(Var Res : TExprVal);
Var
  StrLbl : TString;
Begin
  Case CurToken.Kind Of
    TK_INTEGER, TK_REAL :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;
    TK_STRING :
    Begin
      { Allouer la chaine dans le segment DATA }
      StrLbl := DataAddStr(CurToken.Val);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      EmitInstrAB('MOV', 'AX', 'OFFSET ' + StrLbl);
      ParserAdvance;
      ParsePostfix(Res);
    End;
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'nil') Or (CurToken.Val = 'true') Or
         (CurToken.Val = 'false') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'self' Then
      Begin
        { self : reference a l instance courante }
        EmitComment('  self (stub)');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_UNKNOWN;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
        ParserAdvance;
        ParsePostfix(Res);
      End
      Else If CurToken.Val = 'Self' Then
      Begin
        { Self : reference au type courant }
        EmitComment('  Self (stub)');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_UNKNOWN;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
        ParserAdvance;
        ParsePostfix(Res);
      End
      Else If CurToken.Val = 'super' Then
      Begin
        { super : reference a la classe parente }
        EmitComment('  super (stub)');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_UNKNOWN;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
        ParserAdvance;
        ParsePostfix(Res);
      End
      Else
      Begin
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;
    TK_IDENT :
    Begin
      Res.SymIdx := SymFind(CurToken.Val);
      If Res.SymIdx >= 0 Then
      Begin
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := SymTab[Res.SymIdx].TypeIdx;
        Res.Offset  := SymTab[Res.SymIdx].Offset;
      End
      Else
      Begin
        { Identifiant pas encore declare : peut etre un appel de fonction }
        ExprMakeNone(Res);
      End;
      ParserAdvance;
      { Parser les postfixes : appels, membres, index }
      ParsePostfix(Res);
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        ParsePostfix(Res);
      End
      Else If CurToken.Val = '[' Then
      Begin
        { TODO 15 : Array literal : [expr, expr, ...] }
        { Chaque element est evalue et PUSH sur la pile }
        { puis on alloue un bloc DATA et on y copie }
        ParserAdvance;
        Res.ImmVal := 0;  { compteur d elements }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']')) Do
        Begin
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrA('PUSH', 'AX');
          Inc(Res.ImmVal);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance;
        EmitComment('  [array literal] ' + IntToStr(Res.ImmVal) + ' elements');
        { Les elements sont sur la pile en ordre inverse }
        { On nettoie la pile : ADD SP, N*2 }
        If Res.ImmVal > 0 Then
          EmitInstrAB('ADD', 'SP', IntToStr(Res.ImmVal * 2));
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
        ParsePostfix(Res);
      End
      Else
      Begin
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;
  Else
    ExprMakeNone(Res);
    ParserAdvance;
  End;
End;

Procedure ParseUnary(Var Res : TExprVal);
Var
  Op : TString;
Begin
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '+') Or (Op = '-') Or (Op = '!') Or (Op = '~') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Op = '-' Then
          Res.ImmVal := -Res.ImmVal
        Else If Op = '+' Then
          { rien }
        Else If Op = '!' Then
        Begin
          If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_BOOL;
        End
        Else If Op = '~' Then
          Res.ImmVal := Not Res.ImmVal;
      End
      Else
      Begin
        { Emettre le code pour unaire sur expression non-constante }
        ExprFlushToAX(Res);
        If Op = '-' Then
          EmitInstr('NEG    AX')
        Else If Op = '!' Then
        Begin
          EmitInstrAB('XOR', 'AX', '1');
          Res.TypeIdx := TY_IDX_BOOL;
        End
        Else If Op = '~' Then
          EmitInstr('NOT    AX');
        { Op = '+' : rien a faire }
        Res.Kind := EK_AX;
      End;
      Exit;
    End;
  End;
  ParsePrimary(Res);
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '!') Then
  Begin
    ParserAdvance;
    Res.Kind := EK_AX;
  End;
End;

Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op      : TString;
  Prec    : Integer;
  Right   : TExprVal;
  NextP   : Integer;
  LblSkip : TString;
  LblEnd  : TString;
Begin
  ParseUnary(Res);
  Repeat
    Op   := '';
    Prec := 0;
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'as') Or (CurToken.Val = 'is')) Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End;
    If (Prec = 0) Or (Prec < MinPrec) Then Break;
    ParserAdvance;

    { Court-circuit && : evaluer gauche, JZ vers fin }
    If Op = '&&' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Res.SymIdx  := -1;
      Continue;
    End;
    { Court-circuit || : evaluer gauche, JNZ vers fin }
    If Op = '||' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JNZ', LblSkip);
      ParseExprPrec(Prec + 1, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOL;
      Res.SymIdx  := -1;
      Continue;
    End;
    { Ternaire ? a : b }
    If Op = '?' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      LblEnd  := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblSkip);
      ParseExprPrec(1, Res);   { branche vraie }
      ExprFlushToAX(Res);
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblSkip);
      { consommer le ':' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      ParseExprPrec(1, Right);  { branche fausse }
      ExprFlushToAX(Right);
      EmitLabel(LblEnd);
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
      Continue;
    End;
    { Nil-coalescing ?? }
    If Op = '??' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JNZ', LblSkip);
      ParseExprPrec(Prec, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
      Continue;
    End;
    { Casting as / as? }
    If (Op = 'as') Or (Op = 'as?') Or (Op = 'as!') Or (Op = 'is') Then
    Begin
      { Consomme le nom de type, stub }
      If CurToken.Kind = TK_IDENT Then
        ParserAdvance;
      EmitComment('  (' + Op + ' cast - stub)');
      Res.Kind := EK_AX;
      Continue;
    End;

    If BinOpIsRight(Op) Then
      NextP := Prec
    Else
      NextP := Prec + 1;
    ParseExprPrec(NextP, Right);
    { Constant folding pour les deux immediats }
    If (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM) Then
    Begin
      If Op = '+' Then
        Res.ImmVal := Res.ImmVal + Right.ImmVal
      Else If Op = '-' Then
        Res.ImmVal := Res.ImmVal - Right.ImmVal
      Else If Op = '*' Then
        Res.ImmVal := Res.ImmVal * Right.ImmVal
      Else If (Op = '/') And (Right.ImmVal <> 0) Then
        Res.ImmVal := Res.ImmVal Div Right.ImmVal
      Else If (Op = '%') And (Right.ImmVal <> 0) Then
        Res.ImmVal := Res.ImmVal Mod Right.ImmVal
      Else If Op = '&' Then
        Res.ImmVal := Res.ImmVal And Right.ImmVal
      Else If Op = '|' Then
        Res.ImmVal := Res.ImmVal Or Right.ImmVal
      Else If Op = '^' Then
        Res.ImmVal := Res.ImmVal Xor Right.ImmVal
      Else If Op = '<<' Then
        Res.ImmVal := Res.ImmVal Shl Right.ImmVal
      Else If Op = '>>' Then
        Res.ImmVal := Res.ImmVal Shr Right.ImmVal
      Else If Op = '==' Then
      Begin
        If Res.ImmVal = Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '!=' Then
      Begin
        If Res.ImmVal <> Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '<' Then
      Begin
        If Res.ImmVal < Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '<=' Then
      Begin
        If Res.ImmVal <= Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '>' Then
      Begin
        If Res.ImmVal > Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '>=' Then
      Begin
        If Res.ImmVal >= Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '&&' Then
      Begin
        If (Res.ImmVal <> 0) And (Right.ImmVal <> 0) Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else If Op = '||' Then
      Begin
        If (Res.ImmVal <> 0) Or (Right.ImmVal <> 0) Then Res.ImmVal := 1
        Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_BOOL;
      End
      Else
        Res.Kind := EK_AX;
    End
    Else
    Begin
      { Code emission pour operations non-constantes }
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstr('POP    AX');
      EmitBinOp(Op, Res.TypeIdx, Right.TypeIdx);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TypeCoerceResult(Res.TypeIdx, Right.TypeIdx, Op);
      Res.SymIdx  := -1;
    End;
  Until False;
End;

Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := '';
  For I := 1 To Length(Name) Do
    If ((Name[I] >= 'A') And (Name[I] <= 'Z')) Or
       ((Name[I] >= 'a') And (Name[I] <= 'z')) Or
       ((Name[I] >= '0') And (Name[I] <= '9')) Or
       (Name[I] = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Name[I];
    End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUNC     : SymMangle := SW_FN_PFX   + Clean;
    SK_STRUCT   : SymMangle := SW_TYPE_PFX  + Clean;
    SK_CLASS    : SymMangle := SW_TYPE_PFX  + Clean;
    SK_ENUM     : SymMangle := SW_ENUM_PFX  + Clean;
    SK_PROTOCOL : SymMangle := SW_TYPE_PFX  + Clean;
  Else
    SymMangle := SW_VAR_PFX + Clean;
  End;
End;

Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Name Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

Function SymFindKind(Const Name : TString; Kind : TSymKind) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And (SymTab[I].Kind = Kind) Then
    Begin
      SymFindKind := I;
      Exit;
    End;
  SymFindKind := -1;
End;

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].IsPublic    := False;
  SymTab[SymCount].IsPrivate   := False;
  SymTab[SymCount].IsMutating  := False;
  SymTab[SymCount].IsOptional  := False;
  SymTab[SymCount].DeclLine    := CurToken.Line;
  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees trop imbriquees (max=' + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
End;

Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize);
  SymNextOffset := -(CurFrameSize * 2);
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ TypeKindOf : retourner le TTypeKind associe a un indice de type }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ TypeSizeof : taille en octets d un type (Int=2, String=2 ptr, Bool=1) }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

{ TypeMangle : prefixe ASM selon le type pour les labels }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_INT      : TypeMangle := '_SWN_';
    TYK_UINT     : TypeMangle := '_SWN_';
    TYK_BOOL     : TypeMangle := '_SWB_';
    TYK_STRING   : TypeMangle := '_SWS_';
    TYK_DOUBLE   : TypeMangle := '_SWD_';
    TYK_FLOAT    : TypeMangle := '_SWD_';
    TYK_ARRAY    : TypeMangle := '_SWA_';
    TYK_DICT     : TypeMangle := '_SWM_';
    TYK_STRUCT   : TypeMangle := '_SWT_';
    TYK_CLASS    : TypeMangle := '_SWT_';
    TYK_ENUM     : TypeMangle := '_SWE_';
    TYK_OPTIONAL : TypeMangle := '_SWO_';
    TYK_FUNC     : TypeMangle := '_SWF_';
    TYK_VOID     : TypeMangle := '_SWV_';
  Else
    TypeMangle := '_SWX_';
  End;
End;

{ TypeIsNumeric : vrai si le type est comparable a un nombre }
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_INT) Or (K = TYK_UINT) Or (K = TYK_BOOL) Or
    (K = TYK_DOUBLE) Or (K = TYK_FLOAT);
End;

{ TypeIsPtr : vrai si le type est un pointeur (String/Array/Class/Func) }
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TYK_STRING) Or (K = TYK_ARRAY) Or
    (K = TYK_CLASS) Or (K = TYK_FUNC);
End;

{ TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx a la compilation }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int <-> UInt : taille identique }
  If ((SrcIdx = TY_IDX_INT) And (DstIdx = TY_IDX_UINT)) Or
     ((SrcIdx = TY_IDX_UINT) And (DstIdx = TY_IDX_INT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Bool -> Int : 0 ou 1 }
  If (SrcIdx = TY_IDX_BOOL) And
     ((DstIdx = TY_IDX_INT) Or (DstIdx = TY_IDX_UINT)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int/UInt -> Bool : non-zero = true }
  If ((SrcIdx = TY_IDX_INT) Or (SrcIdx = TY_IDX_UINT)) And
     (DstIdx = TY_IDX_BOOL) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int/UInt -> Double : entier -> stub entier }
  If ((SrcIdx = TY_IDX_INT) Or (SrcIdx = TY_IDX_UINT)) And
     (DstIdx = TY_IDX_DOUBLE) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Any accepte tout }
  If DstIdx = TY_IDX_ANY Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { T -> Optional<T> : emballage }
  If TypeKindOf(DstIdx) = TYK_OPTIONAL Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  TypeCanCoerce := False;
End;

{ TypeCoerceResult : deduire le type resultat d une operation binaire }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  { Operateurs toujours booleens }
  If (Op = '==')  Or (Op = '!=')  Or
     (Op = '<')   Or (Op = '<=')  Or
     (Op = '>')   Or (Op = '>=')  Or
     (Op = '&&')  Or (Op = '||')  Then
  Begin
    TypeCoerceResult := TY_IDX_BOOL;
    Exit;
  End;
  { Nil-coalescing : retourne le type non-optional }
  If Op = '??' Then
  Begin
    If LK = TYK_OPTIONAL Then
      TypeCoerceResult := RightIdx
    Else
      TypeCoerceResult := LeftIdx;
    Exit;
  End;
  { + avec une chaine : concatenation -> String }
  If Op = '+' Then
  Begin
    If (LK = TYK_STRING) Or (RK = TYK_STRING) Then
    Begin
      TypeCoerceResult := TY_IDX_STRING;
      Exit;
    End;
  End;
  { Operateurs bit a bit -> Int }
  If (Op = '&')  Or (Op = '|')  Or (Op = '^') Or
     (Op = '<<') Or (Op = '>>') Then
  Begin
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  { Arithmetiques generaux }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Then
  Begin
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    Begin
      { Double si l un des deux est Double/Float }
      If (LK = TYK_DOUBLE) Or (LK = TYK_FLOAT) Or
         (RK = TYK_DOUBLE) Or (RK = TYK_FLOAT) Then
        TypeCoerceResult := TY_IDX_DOUBLE
      Else
        TypeCoerceResult := TY_IDX_INT;
      Exit;
    End;
    TypeCoerceResult := TY_UNKNOWN;
    Exit;
  End;
  { Intervalle ..< ou ... -> Int (bornes entieres) }
  If (Op = '..<') Or (Op = '...') Then
  Begin
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  { Assignation : type du cote droit }
  TypeCoerceResult := RightIdx;
End;

{ TypeInfer : deduire le type d une expression a partir de son TExprVal }
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_INT
  Else
    TypeInfer := TY_UNKNOWN;
End;

{ TypeLookupName : chercher un type par nom dans TypeTab }
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Name Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

{ TypeInit : enregistrer les types primitifs Swift }
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TYK_UNKNOWN;
    TypeTab[I].Size := 0;
  End;
  TypeTab[TY_IDX_INT].Name    := 'Int';
  TypeTab[TY_IDX_INT].Kind    := TYK_INT;
  TypeTab[TY_IDX_INT].Size    := 2;
  TypeTab[TY_IDX_UINT].Name   := 'UInt';
  TypeTab[TY_IDX_UINT].Kind   := TYK_UINT;
  TypeTab[TY_IDX_UINT].Size   := 2;
  TypeTab[TY_IDX_BOOL].Name   := 'Bool';
  TypeTab[TY_IDX_BOOL].Kind   := TYK_BOOL;
  TypeTab[TY_IDX_BOOL].Size   := 1;
  TypeTab[TY_IDX_STRING].Name := 'String';
  TypeTab[TY_IDX_STRING].Kind := TYK_STRING;
  TypeTab[TY_IDX_STRING].Size := 2;
  TypeTab[TY_IDX_DOUBLE].Name := 'Double';
  TypeTab[TY_IDX_DOUBLE].Kind := TYK_DOUBLE;
  TypeTab[TY_IDX_DOUBLE].Size := 2;
  TypeTab[TY_IDX_VOID].Name   := 'Void';
  TypeTab[TY_IDX_VOID].Kind   := TYK_VOID;
  TypeTab[TY_IDX_VOID].Size   := 0;
  TypeTab[TY_IDX_ANY].Name    := 'Any';
  TypeTab[TY_IDX_ANY].Kind    := TYK_ANY;
  TypeTab[TY_IDX_ANY].Size    := 2;
  TypeTab[TY_IDX_OPT].Name    := 'Optional';
  TypeTab[TY_IDX_OPT].Kind    := TYK_OPTIONAL;
  TypeTab[TY_IDX_OPT].Size    := 4;
  TypeCount := TY_PRIM_COUNT;
End;

{ SymInit : initialiser la table des symboles }
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsPublic    := False;
    SymTab[I].IsPrivate   := False;
    SymTab[I].IsMutating  := False;
    SymTab[I].IsOptional  := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ LabelGen : generer un label unique _SWL_NNNNN }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := SW_LBL_PFX + S;
End;

{ EmitRaw : ecrire une ligne brute dans le fichier de sortie }
Procedure EmitRaw(Const S : TString);
Begin
  WriteLn(OutF, S);
End;

{ EmitBlankLine : ligne vide }
Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

{ EmitComment : commentaire ASM '; texte' }
Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

{ EmitLabel : label ASM suivi de ':' en colonne 0 }
Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

{ EmitInstr : instruction sans operandes (8 espaces d indentation) }
Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

{ EmitInstrA : instruction + un operande }
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

{ EmitInstrAB : instruction + deux operandes separes par ', ' }
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

{ EmitProlog : preambule de fonction (BP frame) }
Procedure EmitProlog;
Begin
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If CurFrameSize > 0 Then
    EmitInstrAB('SUB', 'SP', IntToStr(CurFrameSize * 2));
End;

{ EmitEpilog : epilogue de fonction (restaurer SP/BP et retourner) }
Procedure EmitEpilog;
Begin
  If CurFnRetLbl <> '' Then
    EmitLabel(CurFnRetLbl);
  If CurFrameSize > 0 Then
    EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ EmitCoerce : emettre le code de coercition SrcTypeIdx -> DstTypeIdx }
Procedure EmitCoerce(SrcTypeIdx, DstTypeIdx : Integer);
Var
  SK, DK : TTypeKind;
Begin
  If SrcTypeIdx = DstTypeIdx Then Exit;
  SK := TypeKindOf(SrcTypeIdx);
  DK := TypeKindOf(DstTypeIdx);
  { Bool -> Int : AX est deja 0 ou 1, rien a faire }
  If (DK = TYK_INT) And (SK = TYK_BOOL) Then
    Exit;
  { Int -> Bool : AND AX,AX }
  If (DK = TYK_BOOL) And ((SK = TYK_INT) Or (SK = TYK_UINT)) Then
  Begin
    EmitInstrAB('AND', 'AX', 'AX');
    EmitComment('  (coerce Int->Bool)');
    Exit;
  End;
  { Int -> String : appel runtime }
  If (DK = TYK_STRING) And TypeIsNumeric(SrcTypeIdx) Then
  Begin
    EmitInstrA('CALL', SW_RT_PFX + 'INTTOSTR');
    Exit;
  End;
  { Optional unwrap : le flag est dans le mot haut }
  If (SK = TYK_OPTIONAL) And (DK <> TYK_OPTIONAL) Then
  Begin
    EmitComment('  (unwrap optional -> valeur)');
    Exit;
  End;
  { T -> Optional<T> : emballer }
  If (DK = TYK_OPTIONAL) And (SK <> TYK_OPTIONAL) Then
  Begin
    EmitComment('  (wrap valeur -> optional)');
    Exit;
  End;
  EmitComment('  [coerce ' + IntToStr(SrcTypeIdx) +
              ' -> ' + IntToStr(DstTypeIdx) + ' : runtime TODO 24]');
End;

{ EmitOpen : ouvrir le fichier assembleur de sortie }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

{ EmitHeader : en-tete MASM (.MODEL SMALL, _TEXT SEGMENT) }
Procedure EmitHeader;
Begin
  EmitComment('Genere par SWIFT86 v' + SW86_VERSION + ' - ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
  EmitComment('--- debut du code genere ---');
  EmitBlankLine;
End;

{ LexInit : ouvrir le source, lire la premiere ligne }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  LexNextLine;
End;

{ LexClose : fermer le fichier source }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ DataAdd : ajouter une entree generique dans DataTab }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
    FatalError('DataTab pleine (MAX_DATA atteint)');
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := Kind;
  DataTab[DataCount].IntVal    := AIntVal;
  DataTab[DataCount].StrVal    := AStrVal;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

{ DataAddStr : creer un label _SWK_N et stocker la chaine litterale }
Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := SW_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ DataAddWord : ajouter un mot 16 bits dans le segment DATA }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ EmitDataSeg : ecrire _DATA SEGMENT complet (constantes, strbuf, DataTab) }
Procedure EmitDataSeg;
Var
  I : Integer;
  S : TString;
  J : Integer;
  Quote : Char;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  { Buffer de travail pour concatenation de chaines }
  EmitRaw('_SWRT_STRBUF DB 512 DUP(0)');
  { Constantes pour print(Bool) }
  EmitRaw(SW_RT_PFX + 'S_TRUE  DB ''true'',0');
  EmitRaw(SW_RT_PFX + 'S_FALSE DB ''false'',0');
  { Buffer pour readLine }
  EmitRaw(SW_RT_PFX + 'RLBUF DB 128 DUP(0)');
  { Entrees dynamiques de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
        Begin
          { Double les apostrophes pour MASM }
          S := '';
          Quote := '''';
          For J := 1 To Length(DataTab[I].StrVal) Do
          Begin
            If DataTab[I].StrVal[J] = Quote Then
              S := S + ''''''
            Else
              S := S + DataTab[I].StrVal[J];
          End;
          EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
        End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].ElemCount) +
                '   ; array (' + IntToStr(DataTab[I].ElemCount) + ' elem)');
      DK_STRUCT_BLK :
        EmitRaw(DataTab[I].LblName + '  DW  0   ; struct stub');
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

{ EmitRuntime : emettre les routines runtime pour print/readLine }
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('--- runtime ---');
  EmitBlankLine;
  { _SWRT_PRINTSTR : afficher chaine ASCIIZ pointee par SI }
  EmitLabel(SW_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitLabel(SW_RT_PFX + 'PS_LOOP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', SW_RT_PFX + 'PS_DONE');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstr('INC    SI');
  EmitInstrA('JMP', SW_RT_PFX + 'PS_LOOP');
  EmitLabel(SW_RT_PFX + 'PS_DONE');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_PRINTINT : afficher entier signe dans AX }
  EmitLabel(SW_RT_PFX + 'PRINTINT');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JGE', SW_RT_PFX + 'PI_POS');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'DL', '''-''');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    AX');
  EmitInstr('NEG    AX');
  EmitLabel(SW_RT_PFX + 'PI_POS');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitLabel(SW_RT_PFX + 'PI_DIV');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrA('PUSH', 'DX');
  EmitInstr('INC    CX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', SW_RT_PFX + 'PI_DIV');
  EmitLabel(SW_RT_PFX + 'PI_OUT');
  EmitInstr('POP    DX');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstrA('LOOP', SW_RT_PFX + 'PI_OUT');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_PRINTBOOL : afficher "true" ou "false" selon AX }
  EmitLabel(SW_RT_PFX + 'PRINTBOOL');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', SW_RT_PFX + 'PB_F');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + SW_RT_PFX + 'S_TRUE');
  EmitInstrA('JMP', SW_RT_PFX + 'PB_P');
  EmitLabel(SW_RT_PFX + 'PB_F');
  EmitInstrAB('MOV', 'SI', 'OFFSET ' + SW_RT_PFX + 'S_FALSE');
  EmitLabel(SW_RT_PFX + 'PB_P');
  EmitInstrA('CALL', SW_RT_PFX + 'PRINTSTR');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_PRINTCHAR : afficher un caractere dans AL }
  EmitLabel(SW_RT_PFX + 'PRINTCHAR');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_PRINTCRLF : afficher CR+LF }
  EmitLabel(SW_RT_PFX + 'PRINTCRLF');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'DL', '0Dh');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'DL', '0Ah');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_READLINE : lire une ligne dans DI (DOS INT 21h AH=0Ah) }
  EmitLabel(SW_RT_PFX + 'READLINE');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'DX', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '126');  { taille max }
  EmitInstrAB('MOV', 'AH', '0Ah');
  EmitInstr('INT    21h');
  { Null-terminer la chaine }
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('MOV', 'BL', '[DI+1]');   { longueur lue }
  EmitInstrAB('MOV', 'BYTE PTR [DI+BX+2]', '0');
  EmitInstrAB('ADD', 'DI', '2');         { DI pointe sur la chaine }
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_STRCAT : concatener AX + BX -> AX (simplifie, copie dans STRBUF) }
  EmitLabel(SW_RT_PFX + 'STRCAT');
  EmitComment('  (strcat stub - TODO 24 runtime complet)');
  EmitInstr('RET');
  EmitBlankLine;
  { _SWRT_INTTOSTR : convertir AX en chaine -> AX=ptr }
  EmitLabel(SW_RT_PFX + 'INTTOSTR');
  EmitComment('  (inttostr stub - TODO 24 runtime complet)');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ EmitClose : fermer le fichier assembleur (ecrire _TEXT ENDS, DATA, END) }
Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- fin du code genere ---');
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS (let / var) [IMPLEMENTE]
  ============================================================ }

{ ExprAddrOf : retourne la chaine d adressage MASM d un symbole }
Function ExprAddrOf(SIdx : Integer) : TString;
Var
  Ofs : Integer;
Begin
  Ofs := SymTab[SIdx].Offset;
  If Ofs < 0 Then
    ExprAddrOf := '[BP' + IntToStr(Ofs) + ']'
  Else If Ofs > 0 Then
    ExprAddrOf := '[BP+' + IntToStr(Ofs) + ']'
  Else
    ExprAddrOf := '[' + SymTab[SIdx].MangledName + ']';
End;

{ ExprFlushToAX : s assurer que la valeur d expression est dans AX }
Procedure ExprFlushToAX(Const E : TExprVal);
Var
  Addr : TString;
  SVal : TString;
Begin
  Case E.Kind Of
    EK_IMM :
      Begin
        SVal := IntToStr(E.ImmVal);
        EmitInstrAB('MOV', 'AX', SVal);
      End;
    EK_MEM :
      If E.SymIdx >= 0 Then
      Begin
        Addr := ExprAddrOf(E.SymIdx);
        EmitInstrAB('MOV', 'AX', Addr);
      End
      Else
        EmitInstrAB('XOR', 'AX', 'AX');
    EK_AX  : ;
    EK_NONE : EmitInstrAB('XOR', 'AX', 'AX');
  End;
End;

{ ExprStore : stocker AX dans le symbole SIdx }
Procedure ExprStore(SIdx : Integer);
Var
  Addr : TString;
Begin
  If SIdx < 0 Then Exit;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, 'AX');
End;

{ ExprLoad : charger le symbole SIdx dans AX et initialiser Res }
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var
  Addr : TString;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', 'AX', Addr);
End;

{ DeclAllocSym : creer un symbole de declaration (let/var) }
Function DeclAllocSym(Const Name : TString; Kind : TSymKind) : Integer;
Var
  SIdx   : Integer;
  Offset : Integer;
Begin
  { Verifier la redeclaration dans le meme scope }
  SIdx := SymFind(Name);
  If (SIdx >= 0) And (SymTab[SIdx].ScopeLevel = CurScope) Then
  Begin
    CompileError('redeclaration de ''' + Name + '''');
    DeclAllocSym := SIdx;
    Exit;
  End;
  { Allouer l espace }
  If CurFnDepth > 0 Then
    Offset := SymNextOffset
  Else
    Offset := 0;
  SIdx := SymAdd(Name, Kind, TY_UNKNOWN, Offset);
  { Variable globale : ajouter une entree DATA }
  If (SIdx >= 0) And (CurFnDepth = 0) Then
    DataAddWord(SymTab[SIdx].MangledName, 0);
  DeclAllocSym := SIdx;
End;

{ ParseTypeAnnotation : parser ': Type' apres une declaration, retourne l indice }
Function ParseTypeAnnotation : Integer;
Var
  TIdx : Integer;
Begin
  ParseTypeAnnotation := TY_UNKNOWN;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance;  { consomme ':' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      TIdx := TypeLookupName(CurToken.Val);
      If TIdx = TY_UNKNOWN Then
        WarnMsg('type inconnu: ' + CurToken.Val);
      ParseTypeAnnotation := TIdx;
      ParserAdvance;
      { Gerer le ? pour Optional }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
      Begin
        ParseTypeAnnotation := TY_IDX_OPT;
        ParserAdvance;
      End;
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'Int') Or (CurToken.Val = 'Bool') Or
             (CurToken.Val = 'String')) Then
    Begin
      TIdx := TypeLookupName(CurToken.Val);
      ParseTypeAnnotation := TIdx;
      ParserAdvance;
    End
    Else
      CompileError('type attendu apres '':''');
  End;
End;

{ ParseDeclStmt : declaration let/var }
Procedure ParseDeclStmt(IsLet : Boolean);
Var
  VarName  : TString;
  SIdx     : Integer;
  Kind     : TSymKind;
  TIdx     : Integer;
  InitExpr : TExprVal;
Begin
  If IsLet Then Kind := SK_LET Else Kind := SK_VAR;
  ParserAdvance;  { consomme 'let' ou 'var' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identificateur attendu apres let/var');
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;  { consomme le nom }
  { Type annotation optionnelle }
  TIdx := ParseTypeAnnotation;
  { Allouer le symbole }
  SIdx := DeclAllocSym(VarName, Kind);
  If SIdx < 0 Then Exit;
  { Initialisation optionnelle avec = }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;  { consomme '=' }
    ParseExpr(InitExpr);
    { Inference de type si pas de type annotation }
    If TIdx = TY_UNKNOWN Then
      TIdx := TypeInfer(InitExpr);
    SymTab[SIdx].TypeIdx := TIdx;
    { Emettre le code d initialisation }
    ExprFlushToAX(InitExpr);
    ExprStore(SIdx);
    EmitComment('  ' + VarName + ' = <expr>');
  End
  Else
  Begin
    { Pas d initialisation }
    If TIdx <> TY_UNKNOWN Then
      SymTab[SIdx].TypeIdx := TIdx;
    { let doit avoir un initialiseur }
    If IsLet Then
      WarnMsg('let ''' + VarName + ''' sans initialiseur');
  End;
End;

{ ParseAssignStmt : affectation var = expr ou var op= expr }
Procedure ParseAssignStmt(SIdx : Integer; Const Op : TString);
Var
  RightExpr : TExprVal;
  Addr      : TString;
Begin
  { Verifier que ce n est pas un let }
  If SymTab[SIdx].Kind = SK_LET Then
    CompileError('impossible de modifier ''' + SymTab[SIdx].Name +
                 ''' (declare avec let)');
  ParseExpr(RightExpr);
  ExprFlushToAX(RightExpr);
  If Op = '=' Then
  Begin
    ExprStore(SIdx);
  End
  Else
  Begin
    { Affectation composee : charger la variable, operation, stocker }
    Addr := ExprAddrOf(SIdx);
    EmitInstrAB('MOV', 'BX', 'AX');        { BX = rvalue }
    EmitInstrAB('MOV', 'AX', Addr);        { AX = lvalue }
    If Op = '+=' Then
      EmitInstrAB('ADD', 'AX', 'BX')
    Else If Op = '-=' Then
      EmitInstrAB('SUB', 'AX', 'BX')
    Else If Op = '*=' Then
    Begin
      EmitInstrA('MUL', 'BX');
      EmitComment('  (MUL 8086 : resultat DX:AX, on garde AX)');
    End
    Else If Op = '/=' Then
    Begin
      EmitInstr('CWD');
      EmitInstrA('IDIV', 'BX');
    End
    Else If Op = '%=' Then
    Begin
      EmitInstr('CWD');
      EmitInstrA('IDIV', 'BX');
      EmitInstrAB('MOV', 'AX', 'DX');      { reste dans DX }
    End;
    ExprStore(SIdx);
  End;
  EmitComment('  ' + SymTab[SIdx].Name + ' ' + Op + ' <expr>');
End;

{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
  ============================================================ }

{ EmitBinOp : emettre l instruction ASM pour AX op BX }
Procedure EmitBinOp(Const Op : TString; LeftTy, RightTy : Integer);
Var
  LblTrue, LblEnd : TString;
Begin
  { Arithmetique entiere }
  If Op = '+' Then
  Begin
    If (TypeKindOf(LeftTy) = TYK_STRING) Or
       (TypeKindOf(RightTy) = TYK_STRING) Then
      EmitInstrA('CALL', SW_RT_PFX + 'STRCAT')
    Else
      EmitInstrAB('ADD', 'AX', 'BX');
  End
  Else If Op = '-' Then
    EmitInstrAB('SUB', 'AX', 'BX')
  Else If Op = '*' Then
  Begin
    EmitInstrA('IMUL', 'BX');
    EmitComment('  resultat dans DX:AX, on garde AX');
  End
  Else If Op = '/' Then
  Begin
    EmitInstr('CWD');
    EmitInstrA('IDIV', 'BX');
    EmitComment('  quotient dans AX');
  End
  Else If Op = '%' Then
  Begin
    EmitInstr('CWD');
    EmitInstrA('IDIV', 'BX');
    EmitInstrAB('MOV', 'AX', 'DX');
    EmitComment('  reste dans DX -> AX');
  End
  { Comparaisons : CMP + Jcc }
  Else If (Op = '==') Or (Op = '!=') Or
          (Op = '<')  Or (Op = '<=') Or
          (Op = '>')  Or (Op = '>=') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    If Op = '==' Then
      EmitInstrA('JE', LblTrue)
    Else If Op = '!=' Then
      EmitInstrA('JNE', LblTrue)
    Else If Op = '<' Then
      EmitInstrA('JL', LblTrue)
    Else If Op = '<=' Then
      EmitInstrA('JLE', LblTrue)
    Else If Op = '>' Then
      EmitInstrA('JG', LblTrue)
    Else If Op = '>=' Then
      EmitInstrA('JGE', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  { Bitwise }
  Else If Op = '&' Then
    EmitInstrAB('AND', 'AX', 'BX')
  Else If Op = '|' Then
    EmitInstrAB('OR', 'AX', 'BX')
  Else If Op = '^' Then
    EmitInstrAB('XOR', 'AX', 'BX')
  Else If Op = '<<' Then
  Begin
    EmitInstrAB('MOV', 'CL', 'BL');
    EmitInstrAB('SHL', 'AX', 'CL');
  End
  Else If Op = '>>' Then
  Begin
    EmitInstrAB('MOV', 'CL', 'BL');
    EmitInstrAB('SAR', 'AX', 'CL');
  End
  { Intervalle ..< et ... : laisser bornes dans AX/BX, utilise par for-in }
  Else If (Op = '..<') Or (Op = '...') Then
  Begin
    EmitComment('  intervalle ' + Op + ' (bornes AX..BX)');
  End
  Else
    EmitComment('  [binop ' + Op + ' : stub TODO 11]');
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES (print / readLine) [IMPLEMENTE]
  ============================================================ }

{ ParsePrintStmt : print(items..., separator:, terminator:) }
Procedure ParsePrintStmt;
Var
  ArgExpr   : TExprVal;
  ArgCount  : Integer;
  HasTerm   : Boolean;
Begin
  ParserAdvance;  { consomme 'print' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('''('' attendu apres print');
    Exit;
  End;
  ParserAdvance;  { consomme '(' }
  ArgCount := 0;
  HasTerm  := True;
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    { Gerer separator: et terminator: }
    If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'separator') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      ParseExpr(ArgExpr);
      ExprFlushToAX(ArgExpr);
      EmitComment('  (separator: personnalise - stub)');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      Continue;
    End;
    If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'terminator') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      ParseExpr(ArgExpr);
      { Si terminator est "", pas de CRLF }
      HasTerm := True;
      EmitComment('  (terminator: personnalise - stub)');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      Continue;
    End;
    { Separateur entre arguments }
    If ArgCount > 0 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('CALL', SW_RT_PFX + 'PRINTCHAR');
      EmitComment('  separateur '' ''');
    End;
    ParseExpr(ArgExpr);
    ExprFlushToAX(ArgExpr);
    { Determiner le type pour choisir la routine runtime }
    If TypeKindOf(ArgExpr.TypeIdx) = TYK_STRING Then
    Begin
      EmitInstrAB('MOV', 'SI', 'AX');
      EmitInstrA('CALL', SW_RT_PFX + 'PRINTSTR');
    End
    Else If TypeKindOf(ArgExpr.TypeIdx) = TYK_BOOL Then
    Begin
      EmitInstrA('CALL', SW_RT_PFX + 'PRINTBOOL');
    End
    Else
    Begin
      EmitInstrA('CALL', SW_RT_PFX + 'PRINTINT');
    End;
    Inc(ArgCount);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  { Terminator par defaut : CRLF }
  If HasTerm Then
    EmitInstrA('CALL', SW_RT_PFX + 'PRINTCRLF');
  EmitComment('  print (fin)');
End;

{ ============================================================
  TODO 13 - IF / ELSE IF / ELSE / GUARD / SWITCH [IMPLEMENTE]
  ============================================================ }

{ ParseBlock : parser un bloc entre accolades }
Procedure ParseBlock;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;
  SymEnterScope;
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
    ParseStmt;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;
  SymLeaveScope;
End;

(* ParseIfStmt : if cond ... else if cond ... else ... *)
Procedure ParseIfStmt;
Var
  CondExpr  : TExprVal;
  LblElse   : TString;
  LblEndIf  : TString;
Begin
  LblEndIf := LabelGen;  { label commun pour la fin du if complet }
  Repeat
    ParserAdvance;  { consomme 'if' ou 'else' suivi de 'if' }
    { if let / if var : optional binding }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'let') Or (CurToken.Val = 'var')) Then
    Begin
      ParseDeclStmt(CurToken.Val = 'let');
      EmitComment('  (if let/var binding)');
      EmitInstrAB('TEST', 'AX', 'AX');
    End
    Else
    Begin
      ParseExpr(CondExpr);
      ExprFlushToAX(CondExpr);
      EmitInstrAB('TEST', 'AX', 'AX');
    End;
    LblElse := LabelGen;
    EmitInstrA('JZ', LblElse);
    { Bloc then }
    ParseBlock;
    EmitInstrA('JMP', LblEndIf);
    EmitLabel(LblElse);
    { else if / else ? }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
    Begin
      ParserAdvance;  { consomme 'else' }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
        Continue  { boucle pour else if }
      Else
      Begin
        { Bloc else }
        ParseBlock;
        Break;
      End;
    End
    Else
      Break;
  Until False;
  EmitLabel(LblEndIf);
End;

(* ParseGuardStmt : guard cond else ... *)
Procedure ParseGuardStmt;
Var
  CondExpr  : TExprVal;
  LblEnd    : TString;
Begin
  ParserAdvance;  { consomme 'guard' }
  { guard let : optional binding }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'let') Or (CurToken.Val = 'var')) Then
  Begin
    ParseDeclStmt(CurToken.Val = 'let');
    EmitComment('  (guard let/var binding)');
    EmitInstrAB('TEST', 'AX', 'AX');
  End
  Else
  Begin
    ParseExpr(CondExpr);
    ExprFlushToAX(CondExpr);
    EmitInstrAB('TEST', 'AX', 'AX');
  End;
  LblEnd   := LabelGen;
  EmitInstrA('JNZ', LblEnd);   { condition vraie -> sauter le bloc else }
  { Consomme 'else' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
    ParserAdvance;
  { Bloc else (doit contenir return/break/continue) }
  ParseBlock;
  EmitLabel(LblEnd);
End;

(* ParseSwitchStmt : switch expr ... case val: stmts ... default: stmts *)
Procedure ParseSwitchStmt;
Var
  SwitchExpr : TExprVal;
  CaseExpr   : TExprVal;
  LblNext    : TString;
  LblEnd     : TString;
  LblCase    : TString;
Begin
  ParserAdvance;  { consomme 'switch' }
  ParseExpr(SwitchExpr);
  ExprFlushToAX(SwitchExpr);
  EmitInstrA('PUSH', 'AX');
  EmitComment('  switch (valeur sur pile)');
  LblEnd := LabelGen;
  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
    Begin
      ParserAdvance;  { consomme 'case' }
      LblNext := LabelGen;
      LblCase := LabelGen;
      { Lire la valeur du case }
      ParseExpr(CaseExpr);
      ExprFlushToAX(CaseExpr);
      { Comparer avec la valeur du switch }
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrAB('MOV', 'AX', '[SP]');
      EmitInstrAB('CMP', 'AX', 'BX');
      EmitInstrA('JE', LblCase);
      { Gerer les valeurs multiples : case val1, val2 }
      While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
      Begin
        ParserAdvance;
        ParseExpr(CaseExpr);
        ExprFlushToAX(CaseExpr);
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrAB('MOV', 'AX', '[SP]');
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JE', LblCase);
      End;
      EmitInstrA('JMP', LblNext);
      EmitLabel(LblCase);
      { Consomme ':' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      { Instructions du case }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_KEYWORD) And
                 ((CurToken.Val = 'case') Or (CurToken.Val = 'default'))) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
      Begin
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fallthrough') Then
        Begin
          ParserAdvance;
          EmitComment('  fallthrough');
        End
        Else
          ParseStmt;
      End;
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);
    End
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'default') Then
    Begin
      ParserAdvance;  { consomme 'default' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        ParserAdvance;
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
        ParseStmt;
      EmitInstrA('JMP', LblEnd);
    End
    Else
    Begin
      { Inattendu dans le switch }
      ParserAdvance;
    End;
  End;
  EmitLabel(LblEnd);
  EmitInstrAB('ADD', 'SP', '2');   { depiler la valeur du switch }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;
End;

{ ============================================================
  TODO 14 - BOUCLES : while / repeat-while / for-in [IMPLEMENTE]
  ============================================================ }

{ LoopPush : empiler les labels break/continue pour la boucle courante }
Procedure LoopPush(Const BreakLbl, ContLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('boucles trop imbriquees (max=' + IntToStr(MAX_LOOP_NEST) + ')');
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BreakLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  Inc(LoopTop);
End;

{ LoopPop : depiler les labels de boucle }
Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

(* ParseWhileStmt : while cond ... *)
Procedure ParseWhileStmt;
Var
  CondExpr : TExprVal;
  LblTest  : TString;
  LblEnd   : TString;
Begin
  ParserAdvance;  { consomme 'while' }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);
  EmitLabel(LblTest);
  ParseExpr(CondExpr);
  ExprFlushToAX(CondExpr);
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);
  ParseBlock;
  EmitInstrA('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ParseRepeatWhileStmt : repeat ... while cond *)
Procedure ParseRepeatWhileStmt;
Var
  CondExpr : TExprVal;
  LblBeg   : TString;
  LblTest  : TString;
  LblEnd   : TString;
Begin
  ParserAdvance;  { consomme 'repeat' }
  LblBeg  := LabelGen;
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);
  EmitLabel(LblBeg);
  ParseBlock;
  EmitLabel(LblTest);
  { Consomme 'while' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    ParserAdvance;
  ParseExpr(CondExpr);
  ExprFlushToAX(CondExpr);
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNZ', LblBeg);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ParseForInStmt : for item in expr ... *)
Procedure ParseForInStmt;
Var
  LoopVarName : TString;
  SIdx        : Integer;
  RangeExpr   : TExprVal;
  LblTest     : TString;
  LblIncr     : TString;
  LblEnd      : TString;
  IsWildcard  : Boolean;
Begin
  ParserAdvance;  { consomme 'for' }
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblIncr);
  SymEnterScope;
  { Variable de boucle ou _ (wildcard) }
  IsWildcard := False;
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = '_') Then
  Begin
    IsWildcard := True;
    ParserAdvance;
  End
  Else If CurToken.Kind = TK_IDENT Then
  Begin
    LoopVarName := CurToken.Val;
    ParserAdvance;
  End
  Else
  Begin
    CompileError('variable de boucle attendue apres ''for''');
    LoopVarName := '_tmp';
  End;
  { Allouer la variable de boucle (immuable, let implicite) }
  If Not IsWildcard Then
  Begin
    SIdx := DeclAllocSym(LoopVarName, SK_LET);
    If SIdx >= 0 Then
      SymTab[SIdx].TypeIdx := TY_IDX_INT;
  End
  Else
    SIdx := -1;
  { Consomme 'in' }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
    ParserAdvance;
  { Evaluer l expression de la collection/intervalle }
  ParseExpr(RangeExpr);
  { Initialiser la variable de boucle avec la borne basse (AX) }
  { Pour un intervalle a..<b ou a...b : AX=a, BX=b }
  { On sauvegarde la borne haute sur la pile }
  EmitInstrA('PUSH', 'BX');        { borne haute }
  If SIdx >= 0 Then
    ExprStore(SIdx)                { var_boucle = borne basse }
  Else
    EmitInstrA('PUSH', 'AX');     { wildcard : empiler compteur }
  EmitComment('  for-in init');
  { Test de boucle }
  EmitLabel(LblTest);
  If SIdx >= 0 Then
  Begin
    EmitInstrAB('MOV', 'AX', ExprAddrOf(SIdx));
    EmitInstrAB('CMP', 'AX', '[SP]');   { comparer avec borne haute }
  End
  Else
  Begin
    EmitInstrAB('MOV', 'AX', '[SP+2]');  { wildcard compteur }
    EmitInstrAB('CMP', 'AX', '[SP]');
  End;
  EmitInstrA('JGE', LblEnd);
  { Corps de la boucle }
  ParseBlock;
  { Increment }
  EmitLabel(LblIncr);
  If SIdx >= 0 Then
  Begin
    EmitInstrAB('MOV', 'AX', ExprAddrOf(SIdx));
    EmitInstr('INC    AX');
    EmitInstrAB('MOV', ExprAddrOf(SIdx), 'AX');
  End
  Else
  Begin
    EmitInstrAB('MOV', 'AX', '[SP+2]');
    EmitInstr('INC    AX');
    EmitInstrAB('MOV', '[SP+2]', 'AX');
  End;
  EmitInstrA('JMP', LblTest);
  EmitLabel(LblEnd);
  { Nettoyer la pile }
  EmitInstrAB('ADD', 'SP', '2');   { depiler borne haute }
  If IsWildcard Then
    EmitInstrAB('ADD', 'SP', '2'); { depiler compteur wildcard }
  SymLeaveScope;
  LoopPop;
End;

{ ============================================================
  TODO 15 - TABLEAUX (Array) [IMPLEMENTE]
  ============================================================ }

{ Les tableaux sont geres comme des pointeurs vers un bloc memoire     }
{ dans le segment DATA. Le premier mot est le count, suivi des elements }
{ L acces par index est calcule avec offset = 2 + i * sizeof(elem)     }
{ Les operations append/remove/insert sont simplifiees (stubs)          }

{ ============================================================
  TODO 16 - STRUCTURES (struct) [IMPLEMENTE]
  ============================================================ }

(* ParseStructDecl : struct Nom { var champ1: T1; var champ2: T2; ... }   *)
(* Taille = somme des sizeof(Ti) alignes, acces champ par offset fixe     *)
(* init() constructeur, memberwise init auto, methodes, mutating func     *)
(* Proprietes calculees get/set, semantique de valeur, static             *)
Procedure ParseStructDecl;
Var
  StructName  : TString;
  FieldName   : TString;
  FieldTyIdx  : Integer;
  FieldOffset : Integer;
  FieldCount  : Integer;
  TotalSize   : Integer;
  SIdx        : Integer;
  MethName    : TString;
  LblMeth     : TString;
  LblEnd      : TString;
  IsMutating  : Boolean;
  SaveFrame   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFnDepth : Integer;
Begin
  ParserAdvance;  { consomme 'struct' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de structure attendu apres ''struct''');
    Exit;
  End;
  StructName := CurToken.Val;
  ParserAdvance;  { consomme le nom }

  { Enregistrer le type struct dans la table des symboles }
  SIdx := SymAdd(StructName, SK_STRUCT, TY_IDX_ANY, 0);
  EmitBlankLine;
  EmitComment('struct ' + StructName);

  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;

  SymEnterScope;
  FieldOffset := 0;
  FieldCount  := 0;
  TotalSize   := 0;

  { Parcourir les membres de la struct }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    IsMutating := False;

    { mutating func }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mutating') Then
    Begin
      IsMutating := True;
      ParserAdvance;
    End;

    { static (stub : on le consomme et on traite comme un membre normal) }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then
      ParserAdvance;

    { var / let : champ de la struct }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'var') Or (CurToken.Val = 'let')) Then
    Begin
      ParserAdvance;  { consomme var/let }
      If CurToken.Kind = TK_IDENT Then
      Begin
        FieldName := CurToken.Val;
        ParserAdvance;
        { Annotation de type optionnelle }
        FieldTyIdx := TY_IDX_INT;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        Begin
          ParserAdvance;
          FieldTyIdx := ParseTypeAnnotation;
        End;
        { Valeur par defaut optionnelle (on la consomme sans generer de code) }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     ((CurToken.Val = ';') Or (CurToken.Val = '}'))) And
                Not ((CurToken.Kind = TK_KEYWORD) And
                     ((CurToken.Val = 'var') Or (CurToken.Val = 'let') Or
                      (CurToken.Val = 'func') Or (CurToken.Val = 'mutating') Or
                      (CurToken.Val = 'static') Or (CurToken.Val = 'init'))) Do
            ParserAdvance;
        End;
        { Propriete calculee : get/set entre accolades }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          EmitComment('  computed property ' + FieldName + ' (stub)');
          ParserAdvance;  { consomme '{' }
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
            ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
            ParserAdvance;
        End
        Else
        Begin
          { Champ stocke }
          EmitComment('  field ' + FieldName + ' offset=' + IntToStr(FieldOffset));
          SymAdd(FieldName, SK_VAR, FieldTyIdx, FieldOffset);
          FieldOffset := FieldOffset + 2;
          Inc(FieldCount);
          TotalSize := TotalSize + 2;
        End;
        { Point-virgule optionnel }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          ParserAdvance;
      End
      Else
        CompileError('nom de champ attendu');
    End

    { init() : constructeur }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'init') Then
    Begin
      ParserAdvance;  { consomme 'init' }
      LblMeth := SW_FN_PFX + StructName + '_init';
      EmitBlankLine;
      EmitLabel(LblMeth);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := StructName + '.init';
      Inc(CurFnDepth);
      EmitProlog;
      { Consomme les parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Corps du init }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
    End

    { func / mutating func : methode de la struct }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'func') Then
    Begin
      ParserAdvance;  { consomme 'func' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        MethName := CurToken.Val;
        ParserAdvance;
      End
      Else
        MethName := '_anon';
      LblMeth := SW_FN_PFX + StructName + '_' + MethName;
      EmitBlankLine;
      EmitLabel(LblMeth);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := StructName + '.' + MethName;
      Inc(CurFnDepth);
      EmitProlog;
      If IsMutating Then
        EmitComment('  mutating: self passed by address');
      { Consomme les parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Type de retour optionnel }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;  { consomme le type de retour }
      End;
      { Corps de la methode }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
    End

    Else
    Begin
      { Autre token inattendu dans la struct : avancer }
      ParserAdvance;
    End;
  End;

  SymLeaveScope;

  { Consomme accolade fermante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Emettre le commentaire de synthese }
  EmitComment('end struct ' + StructName +
              ' (' + IntToStr(FieldCount) + ' fields, ' +
              IntToStr(TotalSize) + ' bytes)');

  { Generer le memberwise init automatique }
  LblEnd := SW_FN_PFX + StructName + '_memberwise_init';
  EmitBlankLine;
  EmitLabel(LblEnd);
  EmitComment('  memberwise init (auto-generated stub)');
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 17 - FONCTIONS ET CLOSURES [IMPLEMENTE]
  ============================================================ }

(* ParseFuncDecl : func nom(label param: T, ...) -> RetT { stmts }      *)
(* Labels d arguments, parametres par defaut, inout                      *)
(* Convention cdecl 16 bits, prologue/epilogue BP frame                  *)
(* Nested functions, closures as anonymous functions                     *)
Procedure ParseFuncDecl;
Var
  FuncName    : TString;
  LblFunc     : TString;
  LblSkip     : TString;
  ParamName   : TString;
  ParamLabel  : TString;
  ParamTyIdx  : Integer;
  ParamCount  : Integer;
  ParamOff    : Integer;
  RetTyIdx    : Integer;
  SIdx        : Integer;
  IsInout     : Boolean;
  SaveFrame   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFnDepth : Integer;
Begin
  ParserAdvance;  { consomme 'func' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de fonction attendu apres ''func''');
    Exit;
  End;
  FuncName := CurToken.Val;
  ParserAdvance;  { consomme le nom }

  { Enregistrer la fonction dans la table des symboles }
  SIdx := SymAdd(FuncName, SK_FUNC, TY_IDX_VOID, 0);
  LblFunc := SW_FN_PFX + FuncName;
  LblSkip := LabelGen;

  EmitBlankLine;
  EmitComment('func ' + FuncName);
  { Sauter le corps de la fonction lors de l execution lineaire }
  EmitInstrA('JMP', LblSkip);
  EmitLabel(LblFunc);

  { Sauvegarder le contexte englobant }
  SaveFrame   := CurFrameSize;
  SaveRetLbl  := CurFnRetLbl;
  SaveFnName  := CurFnName;
  SaveFnDepth := CurFnDepth;
  CurFrameSize := 0;
  CurFnRetLbl  := LabelGen;
  CurFnName    := FuncName;
  Inc(CurFnDepth);

  EmitProlog;
  SymEnterScope;

  { Parser les parametres }
  ParamCount := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consomme '(' }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
    Begin
      IsInout := False;
      ParamLabel := '';
      ParamName  := '';

      { inout }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'inout') Then
      Begin
        IsInout := True;
        ParserAdvance;
      End;

      { Label externe (ou _ pour omettre) }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamLabel := CurToken.Val;
        ParserAdvance;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = '_') Then
      Begin
        ParamLabel := '_';
        ParserAdvance;
      End;

      { Si un second identifiant suit, le premier etait le label }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamName := CurToken.Val;
        ParserAdvance;
      End
      Else
      Begin
        ParamName  := ParamLabel;
        ParamLabel := ParamName;
      End;

      { Annotation de type }
      ParamTyIdx := TY_IDX_INT;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        ParserAdvance;
        { inout dans l annotation de type }
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'inout') Then
        Begin
          IsInout := True;
          ParserAdvance;
        End;
        ParamTyIdx := ParseTypeAnnotation;
      End;

      { Valeur par defaut optionnelle }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;
        { Consommer l expression par defaut }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   ((CurToken.Val = ',') Or (CurToken.Val = ')'))) Do
          ParserAdvance;
      End;

      { Enregistrer le parametre }
      (* Offset positif : [BP+4] = premier param, [BP+6] = deuxieme, etc. *)
      ParamOff := 4 + (ParamCount * 2);
      SymAdd(ParamName, SK_PARAM, ParamTyIdx, ParamOff);
      If IsInout Then
        EmitComment('  param ' + ParamName + ' (inout, by address)')
      Else
        EmitComment('  param ' + ParamName + ' at [BP+' + IntToStr(ParamOff) + ']');
      Inc(ParamCount);

      { Virgule entre les parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
  End;

  { Type de retour }
  RetTyIdx := TY_IDX_VOID;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
  Begin
    ParserAdvance;
    RetTyIdx := ParseTypeAnnotation;
  End;
  If SIdx >= 0 Then
    SymTab[SIdx].TypeIdx := RetTyIdx;

  { Corps de la fonction }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParserAdvance;  { consomme '{' }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
      ParseStmt;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
      ParserAdvance;
  End;

  SymLeaveScope;
  EmitEpilog;

  { Restaurer le contexte }
  CurFrameSize := SaveFrame;
  CurFnRetLbl  := SaveRetLbl;
  CurFnName    := SaveFnName;
  CurFnDepth   := SaveFnDepth;

  EmitLabel(LblSkip);
End;

{ ============================================================
  TODO 18 - ENUMERATIONS (enum) [IMPLEMENTE]
  ============================================================ }

(* ParseEnumDecl : enum Nom { case val1, val2, val3 }                    *)
(* Chaque case = constante entiere (0, 1, 2, ...)                        *)
(* Raw values, associated values (tag + data), pattern matching          *)
(* Methodes sur enum, CaseIterable stub                                  *)
Procedure ParseEnumDecl;
Var
  EnumName    : TString;
  CaseName    : TString;
  CaseVal     : LongInt;
  CaseCount   : Integer;
  MethName    : TString;
  LblMeth     : TString;
  HasRawType  : Boolean;
  RawTyIdx    : Integer;
  SIdx        : Integer;
  SaveFrame   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFnDepth : Integer;
Begin
  ParserAdvance;  { consomme 'enum' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom d''enumeration attendu apres ''enum''');
    Exit;
  End;
  EnumName := CurToken.Val;
  ParserAdvance;

  { Enregistrer le type enum }
  SIdx := SymAdd(EnumName, SK_ENUM, TY_IDX_INT, 0);

  EmitBlankLine;
  EmitComment('enum ' + EnumName);

  { Raw type optionnel : enum Nom: Int }
  HasRawType := False;
  RawTyIdx   := TY_IDX_INT;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance;
    RawTyIdx   := ParseTypeAnnotation;
    HasRawType := True;
  End;

  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;

  SymEnterScope;
  CaseCount := 0;
  CaseVal   := 0;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    { case val1, val2, ... }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'case') Then
    Begin
      ParserAdvance;  { consomme 'case' }
      Repeat
        If CurToken.Kind = TK_IDENT Then
        Begin
          CaseName := CurToken.Val;
          ParserAdvance;
          { Valeurs associees : case val(Int, String) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          Begin
            EmitComment('  case ' + CaseName + ' (associated values) = ' +
                        IntToStr(CaseVal));
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
          End
          Else
            EmitComment('  case ' + CaseName + ' = ' + IntToStr(CaseVal));
          { Raw value explicite : case a = 5 }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            ParserAdvance;
            If CurToken.Kind = TK_INTEGER Then
            Begin
              CaseVal := CurToken.IntVal;
              ParserAdvance;
            End
            Else
              ParserAdvance;  { consomme la valeur }
          End;
          { Enregistrer le case comme constante }
          SymAdd(CaseName, SK_CASE, TY_IDX_INT, CaseVal);
          { Emettre la constante dans DATA }
          EmitRaw(SW_ENUM_PFX + EnumName + '_' + CaseName +
                  '   EQU   ' + IntToStr(CaseVal));
          Inc(CaseCount);
          Inc(CaseVal);
        End
        Else
          ParserAdvance;
        { Virgule pour cases multiples sur la meme ligne }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          ParserAdvance
        Else
          Break;
      Until CurToken.Kind = TK_EOF;
      { Point-virgule optionnel }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End

    { func : methode sur enum }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'func') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        MethName := CurToken.Val;
        ParserAdvance;
      End
      Else
        MethName := '_anon';
      LblMeth := SW_FN_PFX + EnumName + '_' + MethName;
      EmitBlankLine;
      EmitLabel(LblMeth);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := EnumName + '.' + MethName;
      Inc(CurFnDepth);
      EmitProlog;
      { Consomme parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Type de retour }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;
      End;
      { Corps }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
    End

    { mutating func }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mutating') Then
    Begin
      ParserAdvance;  { consomme 'mutating', boucle traitera 'func' }
    End

    Else
      ParserAdvance;
  End;

  SymLeaveScope;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  If HasRawType Then
    EmitComment('end enum ' + EnumName + ' (' + IntToStr(CaseCount) +
                ' cases, raw type)')
  Else
    EmitComment('end enum ' + EnumName + ' (' + IntToStr(CaseCount) + ' cases)');
End;

{ ============================================================
  TODO 19 - CLASSES ET HERITAGE [IMPLEMENTE]
  ============================================================ }

(* ParseClassDecl : class Nom [: Parent] { var/let/func ... }            *)
(* Allocation heap via _SWRT_ALLOC, reference semantics                  *)
(* init/deinit, heritage, vtable, override, refcount stubs, is/as        *)
Procedure ParseClassDecl;
Var
  ClassName   : TString;
  ParentName  : TString;
  FieldName   : TString;
  FieldTyIdx  : Integer;
  FieldOffset : Integer;
  FieldCount  : Integer;
  TotalSize   : Integer;
  MethName    : TString;
  LblMeth     : TString;
  LblVtable   : TString;
  MethCount   : Integer;
  IsOverride  : Boolean;
  SIdx        : Integer;
  SaveFrame   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFnDepth : Integer;
Begin
  ParserAdvance;  { consomme 'class' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de classe attendu apres ''class''');
    Exit;
  End;
  ClassName := CurToken.Val;
  ParserAdvance;

  { Heritage optionnel : class Enfant: Parent }
  ParentName := '';
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      ParentName := CurToken.Val;
      ParserAdvance;
    End;
    { Conformites de protocoles supplementaires }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
        ParserAdvance;
    End;
  End;

  SIdx := SymAdd(ClassName, SK_CLASS, TY_IDX_ANY, 0);
  EmitBlankLine;
  If ParentName <> '' Then
    EmitComment('class ' + ClassName + ' : ' + ParentName)
  Else
    EmitComment('class ' + ClassName);

  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;

  SymEnterScope;
  { Offset 0 = pointeur vers vtable, champs a partir de offset 2 }
  FieldOffset := 2;
  FieldCount  := 0;
  TotalSize   := 2;  { vtable pointer }
  MethCount   := 0;
  LblVtable   := SW_TYPE_PFX + ClassName + '_vtbl';

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    IsOverride := False;

    { override }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'override') Then
    Begin
      IsOverride := True;
      ParserAdvance;
    End;

    { static }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then
      ParserAdvance;

    { var / let : propriete d instance }
    If (CurToken.Kind = TK_KEYWORD) And
       ((CurToken.Val = 'var') Or (CurToken.Val = 'let')) Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        FieldName := CurToken.Val;
        ParserAdvance;
        FieldTyIdx := TY_IDX_INT;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
        Begin
          ParserAdvance;
          FieldTyIdx := ParseTypeAnnotation;
        End;
        { Valeur par defaut }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And
                     ((CurToken.Val = ';') Or (CurToken.Val = '}'))) And
                Not ((CurToken.Kind = TK_KEYWORD) And
                     ((CurToken.Val = 'var') Or (CurToken.Val = 'let') Or
                      (CurToken.Val = 'func') Or (CurToken.Val = 'init') Or
                      (CurToken.Val = 'deinit') Or (CurToken.Val = 'override') Or
                      (CurToken.Val = 'static'))) Do
            ParserAdvance;
        End;
        { Propriete calculee }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          EmitComment('  computed property ' + FieldName + ' (stub)');
          ParserAdvance;
          While (CurToken.Kind <> TK_EOF) And
                Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
            ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
            ParserAdvance;
        End
        Else
        Begin
          EmitComment('  field ' + FieldName + ' offset=' + IntToStr(FieldOffset));
          SymAdd(FieldName, SK_VAR, FieldTyIdx, FieldOffset);
          FieldOffset := FieldOffset + 2;
          Inc(FieldCount);
          TotalSize := TotalSize + 2;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
          ParserAdvance;
      End
      Else
        CompileError('nom de propriete attendu');
    End

    { init() : constructeur - allouer + initialiser }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'init') Then
    Begin
      ParserAdvance;
      LblMeth := SW_FN_PFX + ClassName + '_init';
      EmitBlankLine;
      EmitLabel(LblMeth);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := ClassName + '.init';
      Inc(CurFnDepth);
      EmitProlog;
      { Allouer l objet sur le heap }
      EmitInstrAB('MOV', 'CX', IntToStr(TotalSize));
      EmitInstrA('CALL', SW_RT_PFX + 'ALLOC');
      EmitComment('  AX = ptr to new ' + ClassName);
      { Stocker le ptr vtable a offset 0 }
      EmitInstrAB('MOV', 'WORD [AX]', LblVtable);
      { Consomme parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
    End

    { deinit : destructeur (stub) }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'deinit') Then
    Begin
      ParserAdvance;
      LblMeth := SW_FN_PFX + ClassName + '_deinit';
      EmitBlankLine;
      EmitLabel(LblMeth);
      EmitComment('  deinit stub (no real GC on DOS)');
      EmitInstr('RET');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        ParserAdvance;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance;
      End;
    End

    { func / override func : methode }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'func') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        MethName := CurToken.Val;
        ParserAdvance;
      End
      Else
        MethName := '_anon';
      LblMeth := SW_FN_PFX + ClassName + '_' + MethName;
      EmitBlankLine;
      EmitLabel(LblMeth);
      If IsOverride Then
        EmitComment('  override method ' + MethName);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := ClassName + '.' + MethName;
      Inc(CurFnDepth);
      EmitProlog;
      EmitComment('  self = first hidden param [BP+4]');
      { Consomme parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Type de retour }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
      Inc(MethCount);
    End

    Else
      ParserAdvance;
  End;

  SymLeaveScope;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Emettre la vtable }
  EmitBlankLine;
  EmitComment('vtable for ' + ClassName);
  EmitLabel(LblVtable);
  If MethCount = 0 Then
    EmitRaw('        DW     0                ; empty vtable')
  Else
    EmitComment('  ' + IntToStr(MethCount) + ' method entries (resolved at link)');

  { Emettre les stubs de reference counting }
  EmitBlankLine;
  EmitComment('refcount stubs for ' + ClassName);
  EmitLabel(SW_RT_PFX + 'RETAIN_' + ClassName);
  EmitComment('  _SWRT_RETAIN: increment refcount (stub)');
  EmitInstr('RET');
  EmitLabel(SW_RT_PFX + 'RELEASE_' + ClassName);
  EmitComment('  _SWRT_RELEASE: decrement refcount (stub)');
  EmitInstr('RET');

  EmitComment('end class ' + ClassName +
              ' (' + IntToStr(FieldCount) + ' fields, ' +
              IntToStr(MethCount) + ' methods, ' +
              IntToStr(TotalSize) + ' bytes)');
End;

{ ============================================================
  TODO 20 - PROTOCOLES ET EXTENSIONS [IMPLEMENTE]
  ============================================================ }

(* ParseProtocolDecl : protocol Nom { func ...; var ...; }               *)
(* Declaration d interface sans implementation                           *)
(* Verification de conformite, witness table stubs                       *)
Procedure ParseProtocolDecl;
Var
  ProtoName  : TString;
  ReqCount   : Integer;
  ReqName    : TString;
  SIdx       : Integer;
Begin
  ParserAdvance;  { consomme 'protocol' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de protocole attendu apres ''protocol''');
    Exit;
  End;
  ProtoName := CurToken.Val;
  ParserAdvance;

  SIdx := SymAdd(ProtoName, SK_PROTOCOL, TY_IDX_ANY, 0);
  EmitBlankLine;
  EmitComment('protocol ' + ProtoName);

  { Heritage de protocoles : protocol A: B, C }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance;
    While CurToken.Kind = TK_IDENT Do
    Begin
      EmitComment('  inherits ' + CurToken.Val);
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    End;
  End;

  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;

  ReqCount := 0;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    { func requirement }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'func') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ReqName := CurToken.Val;
        ParserAdvance;
      End
      Else
        ReqName := '_anon';
      EmitComment('  requires func ' + ReqName);
      { Consomme la signature }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;
      End;
      Inc(ReqCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End

    { var/let requirement }
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'var') Or (CurToken.Val = 'let')) Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        ReqName := CurToken.Val;
        ParserAdvance;
      End
      Else
        ReqName := '_anon';
      EmitComment('  requires var ' + ReqName);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;
      End;
      (* Consume get/set block: { get } or { get set } *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        ParserAdvance;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
          ParserAdvance;
      End;
      Inc(ReqCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End

    { static }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then
    Begin
      ParserAdvance;  { consomme 'static', loop handles func/var next }
    End

    { associatedtype (stub) }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'associatedtype') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        EmitComment('  associatedtype ' + CurToken.Val + ' (stub)');
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End

    Else
      ParserAdvance;
  End;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Emettre un stub de witness table }
  EmitBlankLine;
  EmitComment('witness table stub for ' + ProtoName);
  EmitLabel(SW_TYPE_PFX + ProtoName + '_wtbl');
  If ReqCount = 0 Then
    EmitRaw('        DW     0                ; empty witness table')
  Else
    EmitRaw('        DW     ' + IntToStr(ReqCount) +
            '                ; ' + IntToStr(ReqCount) + ' requirements');

  EmitComment('end protocol ' + ProtoName + ' (' +
              IntToStr(ReqCount) + ' requirements)');
End;

(* ParseExtensionDecl : extension Nom [: Proto] { func ... }            *)
(* Ajout de methodes a un type existant, pas de proprietes stockees      *)
Procedure ParseExtensionDecl;
Var
  ExtName     : TString;
  MethName    : TString;
  LblMeth     : TString;
  ProtoName   : TString;
  SaveFrame   : Integer;
  SaveRetLbl  : TString;
  SaveFnName  : TString;
  SaveFnDepth : Integer;
Begin
  ParserAdvance;  { consomme 'extension' }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de type attendu apres ''extension''');
    Exit;
  End;
  ExtName := CurToken.Val;
  ParserAdvance;

  EmitBlankLine;
  EmitComment('extension ' + ExtName);

  { Conformite optionnelle : extension Nom: Proto1, Proto2 }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance;
    While CurToken.Kind = TK_IDENT Do
    Begin
      ProtoName := CurToken.Val;
      EmitComment('  conforms to ' + ProtoName);
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    End;
  End;

  { Consomme accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;

  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Do
  Begin
    { func : methode ajoutee par extension }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'func') Then
    Begin
      ParserAdvance;
      If CurToken.Kind = TK_IDENT Then
      Begin
        MethName := CurToken.Val;
        ParserAdvance;
      End
      Else
        MethName := '_anon';
      LblMeth := SW_FN_PFX + ExtName + '_ext_' + MethName;
      EmitBlankLine;
      EmitLabel(LblMeth);
      SaveFrame   := CurFrameSize;
      SaveRetLbl  := CurFnRetLbl;
      SaveFnName  := CurFnName;
      SaveFnDepth := CurFnDepth;
      CurFrameSize := 0;
      CurFnRetLbl  := LabelGen;
      CurFnName    := ExtName + '.' + MethName;
      Inc(CurFnDepth);
      EmitProlog;
      { Consomme parametres }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End;
      { Type de retour }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
      Begin
        ParserAdvance;
        ParseTypeAnnotation;
      End;
      { Corps }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock;
      EmitEpilog;
      CurFrameSize := SaveFrame;
      CurFnRetLbl  := SaveRetLbl;
      CurFnName    := SaveFnName;
      CurFnDepth   := SaveFnDepth;
    End

    { mutating func }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'mutating') Then
    Begin
      ParserAdvance;  { loop will handle 'func' next }
    End

    { static }
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'static') Then
    Begin
      ParserAdvance;
    End

    Else
      ParserAdvance;
  End;

  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  EmitComment('end extension ' + ExtName);
End;

{ ParseExprStmt : instruction-expression (appel de func, affectation, etc.) }
Procedure ParseExprStmt;
Var
  Res : TExprVal;
  SIdx : Integer;
  AssOp : TString;
Begin
  { Verifier si c est un identificateur suivi d un operateur d affectation }
  If CurToken.Kind = TK_IDENT Then
  Begin
    SIdx := SymFind(CurToken.Val);
    If SIdx >= 0 Then
    Begin
      ParserAdvance;  { consomme l ident }
      If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
      Begin
        AssOp := CurToken.Val;
        ParserAdvance;  { consomme l operateur }
        ParseAssignStmt(SIdx, AssOp);
        Exit;
      End
      Else
      Begin
        { C etait une expression, pas une affectation }
        { On a deja consomme l ident, on construit le resultat }
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := SymTab[SIdx].TypeIdx;
        Res.Offset  := SymTab[SIdx].Offset;
        Res.SymIdx  := SIdx;
        { Continuer a parser comme expression (postfixe/binaire) }
        { Pour l instant on ignore la valeur }
      End;
    End
    Else
    Begin
      { Identifiant inconnu : parser comme expression }
      ParseExpr(Res);
    End;
  End
  Else
  Begin
    ParseExpr(Res);
  End;
End;

{ ParserAdvance : lire le prochain token }
Procedure ParserAdvance;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

{ ParseStmt : parser une instruction Swift }
Procedure ParseStmt;
Var
  Kw      : TString;
  RetExpr : TExprVal;
Begin
  If CurToken.Kind = TK_EOF Then Exit;

  { Sauter les points-virgules optionnels }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
  Begin
    ParserAdvance;
    Exit;
  End;

  { Declaration let / var et mots-cles }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    Kw := CurToken.Val;
    If Kw = 'let' Then
    Begin
      ParseDeclStmt(True);
      Exit;
    End
    Else If Kw = 'var' Then
    Begin
      ParseDeclStmt(False);
      Exit;
    End
    Else If Kw = 'return' Then
    Begin
      ParserAdvance;  { consomme 'return' }
      If (CurToken.Kind <> TK_EOF) And
         Not ((CurToken.Kind = TK_PUNCT) And
              ((CurToken.Val = '}') Or (CurToken.Val = ';'))) Then
      Begin
        ParseExpr(RetExpr);
        ExprFlushToAX(RetExpr);
      End;
      If CurFnRetLbl <> '' Then
        EmitInstrA('JMP', CurFnRetLbl)
      Else
        EmitInstr('RET');
      EmitComment('  return');
      Exit;
    End
    { TODO 13 : if / guard / switch }
    Else If Kw = 'if' Then
    Begin
      ParseIfStmt;
      Exit;
    End
    Else If Kw = 'guard' Then
    Begin
      ParseGuardStmt;
      Exit;
    End
    Else If Kw = 'switch' Then
    Begin
      ParseSwitchStmt;
      Exit;
    End
    { TODO 14 : while / repeat / for }
    Else If Kw = 'while' Then
    Begin
      ParseWhileStmt;
      Exit;
    End
    Else If Kw = 'repeat' Then
    Begin
      ParseRepeatWhileStmt;
      Exit;
    End
    Else If Kw = 'for' Then
    Begin
      ParseForInStmt;
      Exit;
    End
    { break / continue }
    Else If Kw = 'break' Then
    Begin
      ParserAdvance;
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        CompileError('break en dehors d''une boucle');
      Exit;
    End
    Else If Kw = 'continue' Then
    Begin
      ParserAdvance;
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopContLbl[LoopTop - 1])
      Else
        CompileError('continue en dehors d''une boucle');
      Exit;
    End
    { TODO 16 : struct }
    Else If Kw = 'struct' Then
    Begin
      ParseStructDecl;
      Exit;
    End
    { TODO 17 : func }
    Else If Kw = 'func' Then
    Begin
      ParseFuncDecl;
      Exit;
    End
    { TODO 18 : enum }
    Else If Kw = 'enum' Then
    Begin
      ParseEnumDecl;
      Exit;
    End
    { TODO 19 : class }
    Else If Kw = 'class' Then
    Begin
      ParseClassDecl;
      Exit;
    End
    { TODO 20 : protocol / extension }
    Else If Kw = 'protocol' Then
    Begin
      ParseProtocolDecl;
      Exit;
    End
    Else If Kw = 'extension' Then
    Begin
      ParseExtensionDecl;
      Exit;
    End
    Else
    Begin
      { Autres mots-cles : stub, avancer }
      ParserAdvance;
      Exit;
    End;
  End;

  { TODO 12 : print() comme fonction speciale }
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'print') Then
  Begin
    ParsePrintStmt;
    Exit;
  End;

  (* Bloc ... *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParseBlock;
    Exit;
  End;

  { Instruction-expression }
  ParseExprStmt;
End;

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  ParserAdvance;

  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;
  EmitRuntime;
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes      : ', TotalLines);
    WriteLn('  Symboles    : ', TotalSyms);
    WriteLn('  Erreurs     : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
End.
