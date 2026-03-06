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

Procedure ParsePrimary(Var Res : TExprVal);
Begin
  Case CurToken.Kind Of
    TK_INTEGER, TK_REAL, TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'nil') Or (CurToken.Val = 'true') Or
         (CurToken.Val = 'false') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
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
        ExprMakeNone(Res);
      ParserAdvance;
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End
      Else If CurToken.Val = '[' Then
      Begin
        ParserAdvance;
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']')) Do
        Begin
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance;
        ExprMakeNone(Res);
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
        Res.Kind := EK_AX;
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
  Op    : TString;
  Prec  : Integer;
  Right : TExprVal;
  NextP : Integer;
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
    If BinOpIsRight(Op) Then
      NextP := Prec
    Else
      NextP := Prec + 1;
    ParseExprPrec(NextP, Right);
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
      Res.Kind := EK_AX;
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
  STUBS PREALABLES (TODO 06..25 - a implementer)
  ============================================================ }

Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_INT) Or (K = TYK_UINT) Or (K = TYK_BOOL) Or
    (K = TYK_DOUBLE) Or (K = TYK_FLOAT);
End;

Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TYK_STRING) Or (K = TYK_ARRAY) Or
    (K = TYK_CLASS) Or (K = TYK_FUNC);
End;

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

Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := SW_LBL_PFX + S;
End;

Procedure EmitRaw(Const S : TString);
Begin
  WriteLn(OutF, S);
End;

Procedure EmitBlankLine;
Begin
  WriteLn(OutF);
End;

Procedure EmitComment(Const S : TString);
Begin
  WriteLn(OutF, '; ', S);
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  WriteLn(OutF, Lbl, ':');
End;

Procedure EmitInstr(Const Mnem : TString);
Begin
  WriteLn(OutF, '        ', Mnem);
End;

Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

Procedure EmitProlog;
Begin
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If CurFrameSize > 0 Then
    EmitInstrAB('SUB', 'SP', IntToStr(CurFrameSize * 2));
End;

Procedure EmitEpilog;
Begin
  If CurFnRetLbl <> '' Then
    EmitLabel(CurFnRetLbl);
  If CurFrameSize > 0 Then
    EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

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

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

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

Procedure ExprStore(SIdx : Integer);
Var
  Addr : TString;
Begin
  If SIdx < 0 Then Exit;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, 'AX');
End;

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

Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := SW_STR_PFX + IntToStr(LabelGenSeq);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

Procedure EmitDataSeg;
Var
  I : Integer;
  S : TString;
  J : Integer;
  Quote : Char;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitRaw('_SWRT_STRBUF DB 512 DUP(0)');
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

Procedure EmitRuntime;
Begin
  { Stub : TODO 24 }
End;

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

Procedure ParserAdvance;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

Procedure ParseStmt;
Begin
  { Stub : TODO 09+ implementeront les instructions }
  If CurToken.Kind = TK_EOF Then Exit;
  ParserAdvance;
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
