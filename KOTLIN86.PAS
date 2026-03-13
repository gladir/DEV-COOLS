{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Kotlin vers assembleur 8086
}

(* ============================================================
  KOTLIN86.PAS - Compilateur Kotlin vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.kt [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .kt (source Kotlin)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS KOTLIN) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_LONG, TK_FLOAT,
              TK_STRING, TK_CHAR, TK_IDENT, TK_KEYWORD,
              TK_OP, TK_PUNCT, TK_NEWLINE (insertion implicite de ;)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets doubles "abc"
              Sequences d echappement : \n \t \r \\ \" \$ \uNNNN
            LexScanChar : litteral caractere entre apostrophes 'A'
            LexScanTemplate : interpolation de chaine "$var" et "${expr}"
            Commentaires : // ligne, /* ... */ multi-lignes (imbrication autorisee)
            Mots-cles : abstract annotation as break by catch class companion
              const constructor continue crossinline data do downTo else enum
              external false final finally for fun if import in infix init
              inline inner interface internal is it lateinit noinline null
              object open operator out override package private protected
              public reified return sealed step super this throw to true
              try typealias until val var vararg when where while
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (Int) ou -32768..32767 (signe)
            Entiers hexadecimaux : 0xFF, 0XFF
            Entiers binaires : 0b1010, 0B1010
            Suffixe Long : 123L -> avertissement (traite comme Int 16 bits)
            Separateurs numeriques : 1_000_000 -> 1000000
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
              Suffixes F et D : avertissement + trunc
            Caracteres : 'A' ou '\n' ou '\uNNNN'
            Chaines : "abc" -> pointeur vers donnees DATA
              Chaine brute : triple guillemets non supportes -> avertissement
            Interpolation de chaine : "x = $x" et "y = ${y+1}"
              -> concatenation via appels _KTRT_CONCAT et _KTRT_NUMTOSTR
            null  : constante -> AX=0 (reference nulle)
            true  : constante -> AX=1
            false : constante -> AX=0

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / % (entiers 16 bits)
            Comparaison    : == != < <= > >= (egalite structurelle)
            Identite ref   : === !== (egalite referentielle, comparaison de ptrs)
            Logiques       : && || ! (court-circuit -> labels _KTL_NNNN)
            Bits           : and or xor inv shl shr ushr (fonctions infixes)
            Intervalle     : .. (creation de range, a..b)
            Contenance     : in !in (appartenance a un range ou collection)
            Verification   : is !is (test de type -> smart cast)
            Elvis          : ?: (null-coalescing, si gauche null -> droite)
            Safe call      : ?. (appel/acces si non-null, sinon null)
            Not-null assert: !! (assertion non-null, exception si null)
            Affectation    : = += -= *= /= %=
            Unaire         : + - ! ++ -- (prefixe et suffixe)
            Precedence (du plus fort au plus faible) :
              1. Suffixe : ++ -- . ?. () [] !!
              2. Prefixe : - + ++ -- !
              3. Type RHS : as as?
              4. * / %
              5. + -
              6. ..
              7. Infixe nomme (in !in is !is, fonctions infix)
              8. Elvis ?:
              9. Comparaison < > <= >= == != === !==
              10. && ||
              11. Spread *arr (dans appel de fonction)
              12. Affectation = += -= *= /= %=

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAL, SK_VAR, SK_PARAM, SK_FUN, SK_CLASS,
              SK_OBJECT, SK_ENUM, SK_INTERFACE, SK_COMPANION, SK_PROP
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsConst, IsNullable, IsLateinit, Visibility
            SymNameClean : nettoyer les caracteres non-MASM (_)
            SymMangle : SK_FUN->_KTF_, SK_CLASS->_KTC_, SK_OBJECT->_KTO_,
              SK_ENUM->_KTE_, SK_INTERFACE->_KTI_, autres->_KTV_
            SymFind : recherche MRU (du plus recent au plus ancien)
            SymFindInScope : recherche dans une portee specifique
            SymAdd : ajouter un symbole (debug trace si -d)
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
              avec sauvegarde/restauration de SymCount et debug trace
            Visibilite : public (defaut), private, protected, internal
            SymInit : nettoyer la table + predeclarer les fonctions
              stdlib Kotlin : println, print, readLine, readln,
              toString, toInt, toDouble, toFloat, toLong, toByte, toShort,
              toChar, toBoolean, hashCode, equals, compareTo,
              arrayOf, intArrayOf, listOf, mutableListOf, mapOf, setOf,
              maxOf, minOf, repeat, require, check, error,
              TODO, run, let, also, apply, with, takeIf, takeUnless
            Smart cast : marquer le type affine apres un test is
            Qualificateurs : Package.Classe.membre -> recherche chainee

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_INT (16 bits signe), TYK_SHORT (16 bits signe),
              TYK_LONG (stub 16 bits), TYK_BYTE (8 bits signe),
              TYK_BOOLEAN (8 bits), TYK_CHAR (16 bits, stocke 8 bits),
              TYK_FLOAT (stub entier), TYK_DOUBLE (stub entier),
              TYK_STRING (ptr chaine), TYK_ARRAY (ptr tableau),
              TYK_INTARRAY (ptr IntArray), TYK_CLASS (ptr objet),
              TYK_INTERFACE (ptr vtable), TYK_ENUM (ordinal),
              TYK_UNIT (void), TYK_NOTHING (type bottom),
              TYK_NULLABLE (enveloppe nullable), TYK_ANY (type racine),
              TYK_LAMBDA (ptr code)
            TypeTab, TypeInit : enregistrer les types primitifs et utilisateur
            TypeSizeof : Int=2, Short=2, Byte=1, Boolean=1, Char=2(stocke 1),
              String/Array/objet=2(ptr), Unit=0
            Nullable : T? -> meme taille + flag IsNullable
              AX=0 represente null pour les types nullable
            Smart cast : si (x is T) alors x est traite comme T dans le bloc
            Type inference : deduction du type via l expression d initialisation

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _KTL_NNNNN)
            Prefixes : _KTV_ (variable), _KTF_ (fonction), _KTK_ (chaine const),
              _KTRT_ (runtime), _KTL_ (label), _KTC_ (classe/vtable),
              _KTE_ (enum), _KTI_ (interface), _KTO_ (object singleton)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_OBJ),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray, DataAddObj : variantes d ajout
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Variables globales (val/var top-level) : entrees DK_WORD dans DATA
            Constantes const val : entrees DK_WORD ou DK_STR (immuables)
            Chaines litterales : DB 'abc',0 dans DATA avec label _KTK_N
            Singletons object : bloc DATA pour chaque object declaration
            Tables de methodes virtuelles : DW offset proc par methode
            Descripteurs d enum : DW ordinal + ptr nom pour chaque entree

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            val nom : Type = expr -> variable immuable (erreur si reassignation)
              Allocation locale : SUB SP,2 / MOV [BP-n], AX
              Allocation globale : entree _KTV_nom DW dans DATA
            var nom : Type = expr -> variable mutable
              Meme allocation, mais reassignation autorisee
            Type inference : val x = 42 -> type Int deduit automatiquement
            lateinit var : declaration sans initialisation (verification a l execution)
              -> flag, MOV AX,[BP-n] / CMP AX,0 / JZ _KTL_UNINIT_ERR
            const val : constante de compilation (top-level ou companion object)
              -> valeur inlinee directement dans le code
            Affectation simple : var = expr -> ExprLoad + MOV [BP-n], AX
            Operateurs composes : += -= *= /= %= -> load / op / store
            Destructuration : val (a, b) = pair -> acces componentN() -> stubs

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal entier, literal chaine, literal caractere,
              ident, this, super, null, true, false
            this -> BX = ptr objet courant (parametre cache)
              En contexte top-level : avertissement + XOR AX,AX
            null -> XOR AX,AX
            true -> MOV AX,1   false -> XOR AX,AX
            Appel de fonction : nom(args) -> PUSH args + CALL _KTF_nom
            Acces membre : expr.membre -> offset dans objet ou appel methode
            Safe call : expr?.membre -> CMP AX,0 / JZ null_branch
            Not-null assert : expr!! -> CMP AX,0 / JZ _KTL_NPE (exception)
            Acces index : expr[i] -> calcul offset dans tableau
            Cast : expr as Type -> verification + AX inchange
            Safe cast : expr as? Type -> AX ou 0 si echec
            Groupement parenthese : (expr)
            Interpolation chaine : "texte $var texte" -> concat multiple

  TODO 11 - EXPRESSIONS BINAIRES (PRATT) [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle Pratt complete
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            Modulo : IDIV -> resultat dans DX (reste)
            Concatenation String : + -> CALL _KTRT_CONCAT(SI=gauche, DI=droite)
            Comparaison : CMP + Jcc pour ==, !=, <, <=, >, >=
            Comparaison String : CALL _KTRT_STRCMP -> drapeaux
            Egalite referentielle === : CMP direct des pointeurs
            Logique && : court-circuit JZ vers false-branch
            Logique || : court-circuit JNZ vers true-branch
            Logique ! : XOR AX,1
            Elvis ?: : CMP AX,0 / JNZ skip / evaluer droite
            Range .. : creation d un range (bornes dans registres)
            Operateur in : verification appartenance range (CMP bornes)
            Operateur is : verification type dynamique -> AX=0|1
            Fonctions infixes : a shl b -> SHL AX,CL
              shr -> SHR, ushr -> SHR (non signe), and -> AND, or -> OR,
              xor -> XOR, inv -> NOT (unaire)

  TODO 12 - ENTREES/SORTIES (println / readLine / print) [IMPLEMENTE]
            println(args) : affiche chaque argument converti en chaine + \n
              Detection du type compile -> _KTRT_NUMTOSTR ou chaine directe
              Separateur : pas de separateur entre arguments
              -> INT 21h AH=40h BX=1 (STDOUT) + CR+LF
            print(args) : idem sans \n final
            readLine() : lecture d une ligne depuis STDIN -> AX=ptr chaine
              -> INT 21h AH=0Ah (lecture ligne bufferisee)
            readLine()!!.toInt() : lecture + conversion chaine -> entier
              -> CALL _KTRT_READLINE + CALL _KTRT_STRTONUM -> AX
            Fonctions de conversion sur types :
              toString() -> CALL _KTRT_NUMTOSTR -> AX=ptr
              toInt() -> CALL _KTRT_STRTONUM -> AX
              toChar() -> MOV AL,valeur (octet bas)
              toByte() / toShort() / toLong() : stubs -> AX tel quel

  TODO 13 - IF / ELSE / WHEN (EXPRESSIONS ET STATEMENTS) [IMPLEMENTE]
            ParseIfStmt : if (cond) bloc [else if (cond) bloc] [else bloc]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _KTL_ELIF_N, _KTL_ELSE_N, _KTL_ENDIF_N
            If comme expression : val x = if (c) a else b
              -> evalue dans AX, les deux branches deposent dans AX
            ParseWhenStmt : when (expr) {
                val1 -> stmts
                val2, val3 -> stmts
                in lo..hi -> stmts (intervalle)
                is Type -> stmts (test de type + smart cast)
                else -> stmts
              }
              Emission : CMP + JE pour chaque valeur
              Intervalle in : CMP+JB / CMP+JA pour les bornes
              is Type : CALL _KTRT_TYPECODE + CMP
              Labels : _KTL_WHEN_N, _KTL_WBRANCH_N, _KTL_WEND_N
            When sans argument : when { cond1 -> ... cond2 -> ... else -> }
              -> enchainement de if/else if
            When comme expression : val x = when { ... }

  TODO 14 - BOUCLES : while / do-while / for / repeat [IMPLEMENTE]
            ParseWhileStmt : while (cond) bloc
              Labels : _KTL_WTEST_N, _KTL_WEND_N
            ParseDoWhileStmt : do bloc while (cond)
              Labels : _KTL_DOBEG_N, _KTL_DOTEST_N
            ParseForStmt : for (item in collection) bloc
              for (i in 0..n) : boucle sur range inclusif
              for (i in 0 until n) : boucle sur range exclusif borne haute
              for (i in n downTo 0) : boucle decroissante
              for (i in 0..n step 2) : boucle avec pas
              for (ch in "abc") : iteration sur caracteres d une chaine
              for (e in array) : iteration sur elements d un tableau
              Labels : _KTL_FTEST_N, _KTL_FINCR_N, _KTL_FEND_N
            repeat(n) { bloc } : boucle n fois (fonction inline stdlib)
              -> emission comme for (i in 0 until n)
            break : saut vers fin de la boucle englobante
            continue : saut vers l increment/test de la boucle
            Labels de boucle : label@ for (...) { break@label }
            LoopPush / LoopPop : pile de labels break/continue

  TODO 15 - TABLEAUX (Array / IntArray / arrayOf) [IMPLEMENTE]
            arrayOf(e0, e1, e2) : creation d un tableau -> DATA ou pile
            intArrayOf(e0, e1, e2) : creation d un IntArray
            Array(n) { init } : creation avec lambda d initialisation
              -> boucle interne, init(index) pour chaque element
            IntArray(n) : creation d un IntArray de taille n, init a 0
            Representation memoire : [count:word] [e0:word] [e1:word] ...
              Taille fixe a la compilation (MAX_ARR_ELEM elements max)
            Acces arr[i] (i constant) : offset = 2 + i*2, MOV AX,[BX+SI]
            Acces arr[i] (i variable) : SHL AX,1 / ADD AX,2 / MOV SI,AX
            Affectation arr[i] = expr : calcul offset + MOV [BX+SI],AX
            arr.size -> MOV AX,[BX] (premier word = count)
            Methodes Array :
              arr.get(i) / arr.set(i,v) : idem acces par index
              arr.indexOf(v) -> CALL _KTRT_ARRIDXOF -> AX
              arr.contains(v) -> indexOf != -1 -> AX=0|1
              arr.forEach { action } -> boucle inline
              arr.map { transform } -> stub + avertissement
              arr.filter { predicate } -> stub + avertissement
              arr.sorted() -> CALL _KTRT_ARRSORT -> AX=ptr copie triee
              arr.sum() -> CALL _KTRT_ARRSUM -> AX
            Verification de bornes : CMP index / JB/JAE -> exception si hors bornes

  TODO 16 - CLASSES ET DATA CLASSES [IMPLEMENTE]
            ParseClassDecl : [open|abstract|data|sealed] class Nom
              [constructor(params)] [: SuperType(args)[, Interface]] { corps }
            Constructeur primaire : class Nom(val x: Int, var y: Int)
              Parametres val/var : proprietes automatiques + init dans constructeur
              Parametres sans val/var : disponibles dans init {} seulement
            Bloc init { } : code d initialisation execute apres le constructeur
            Proprietes : val/var avec getters/setters optionnels
              get() = expr / set(value) { bloc }
            Data class : genere automatiquement :
              toString() -> _KTF_Nom_toString : "Nom(x=..., y=...)"
              equals() -> comparaison champ par champ
              hashCode() -> stub AX=0
              copy() -> allocation + copie des champs
              componentN() -> acces au N-ieme champ (pour destructuration)
            Sealed class : hierarchie fermee (enum de sous-types)
              -> verification exhaustive dans when
            Allocation : CALL _KTRT_NEW(CX=sizeof) -> AX=ptr objet
            Representation objet : [vtable:word] [champ1:word] [champ2:word] ...

  TODO 17 - FONCTIONS ET LAMBDAS [IMPLEMENTE]
            ParseFunDecl : fun nom(params): RetType { bloc }
              ou fun nom(params): RetType = expr (expression body)
            Parametres : nom: Type, valeurs par defaut (nom: Type = val)
              vararg : dernier parametre variable -> stub + avertissement
            Valeur de retour : return expr -> MOV AX,val / JMP _KTL_RET_N
              Retour implicite de Unit si pas de return
            Fonctions locales : fun imbriquee dans une autre fun
              Acces au cadre englobant via lien statique (parametre cache)
            Fonctions d extension : fun Type.nom(params) { this -> BX=receveur }
              -> _KTF_Type_nom : premier parametre = receveur (this)
            Fonctions infix : infix fun Int.shl(n: Int) -> utilisation a shl b
            Fonctions inline : inline fun -> corps substitue a l appel (optimisation)
              -> emission directe du corps au site d appel
            Lambdas : { params -> corps } -> label _KTF_LAMBDA_N PROC NEAR
              Dernier parametre lambda hors parentheses : f(x) { lambda }
              it : parametre implicite si un seul parametre
              Capture de variables : allouees dans DATA (cellules partagees)
            Types fonctionnels : (Int, Int) -> Int -> ptr code
              Appel indirect : CALL AX

  TODO 18 - PORTEE, PILE ET CADRES [IMPLEMENTE]
            Convention d appel : cdecl 16 bits, args empiles gauche a droite
            Prologue fonction : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Variables val/var locales : allouees sur pile [BP-offset]
            Parametres : acces [BP+offset] (apres BP sauvegarde et adresse retour)
            Portee de bloc : { } cree une nouvelle portee
              SymEnterScope a l ouverture, ScopeBlockLeave a la fermeture
              Variables de bloc : SUB SP,2 a l entree, ADD SP,2 a la sortie
            Fermetures (lambdas capturant des variables) :
              Variables capturees allouees dans DATA (cellules partagees)
              Emission : MOV AX,[_KTV_nom_cap] / MOV [_KTV_nom_cap],AX
              Avertissement si capture profonde (>1 niveau)
            Sauvegarde registres : SI, DI preserves dans chaque fonction
            CurFrameSize : taille courante du cadre local (nb de words)

  TODO 19 - CHAINES ET METHODES STRING
            Representation : pointeur vers zone DATA terminee par 0
            Interpolation : "Hello, $name!" -> concat de segments
              "${expr}" -> evaluation expr + _KTRT_NUMTOSTR si numerique
            Concatenation + : CALL _KTRT_CONCAT(SI=gauche, DI=droite) -> AX
            Comparaison == : CALL _KTRT_STRCMP -> drapeaux ZF
            Methodes String :
              s.length -> CALL _KTRT_STRLEN(SI=AX) -> AX
              s.get(i) / s[i] -> CALL _KTRT_STRCHAR(SI,CX) -> AX=ptr char
              s.substring(a,b) -> CALL _KTRT_STRSUB(SI,BX,CX) -> AX=ptr
              s.indexOf(sub) -> CALL _KTRT_STRINDEXOF(SI,DI) -> AX
              s.contains(sub) -> indexOf != -1 -> AX=0|1
              s.startsWith(p) -> CALL _KTRT_STRSTARTW -> AX
              s.endsWith(s2) -> CALL _KTRT_STRENDW -> AX
              s.uppercase() -> CALL _KTRT_STRTOUPPER(SI) -> AX=buf
              s.lowercase() -> CALL _KTRT_STRTOLOWER(SI) -> AX=buf
              s.trim() -> CALL _KTRT_STRTRIM(SI) -> AX=buf
              s.split(sep) -> CALL _KTRT_STRSPLIT(SI,DI) -> AX=arr ptr
              s.replace(a,b) -> CALL _KTRT_STRRPLS(SI,DI,BX) -> AX=buf
              s.toInt() -> CALL _KTRT_STRTONUM(SI) -> AX
              s.reversed() -> CALL _KTRT_STRREV(SI) -> AX=buf
              s.repeat(n) -> CALL _KTRT_STRREPEAT(SI,CX) -> AX=buf
            Caracteres Char :
              ch.code -> AX = valeur ordinale (MOVZX ou XOR AH,AH / MOV AL,ch)
              ch.isLetter() / isDigit() / isWhitespace() -> CALL _KTRT_CHKCHAR

  TODO 20 - NULL SAFETY
            Types nullable : T? -> meme representation + flag IsNullable
              AX=0 represente null pour tout type nullable
            Safe call ?. : expr?.membre
              CMP AX,0 / JZ _KTL_NULL_N (branche null -> AX reste 0)
              sinon acces membre normalement
              Chainable : a?.b?.c -> verifications successives
            Elvis ?: : expr1 ?: expr2
              CMP AX,0 / JNZ _KTL_SKIP_N (garder AX si non-null)
              sinon evaluer expr2
            Not-null assert !! : expr!!
              CMP AX,0 / JZ _KTL_NPE_N
              _KTL_NPE_N : CALL _KTRT_PANIC('NullPointerException')
            Smart cast apres is : if (x is String) { x.length }
              Le compilateur marque x comme String dans la branche then
              Pas de cast explicite necessaire
            Safe cast as? : expr as? Type
              Si type incompatible -> AX=0 (null) au lieu d exception
            Verification au compilateur :
              Affectation de null a un type non-nullable -> erreur
              Appel de methode sur nullable sans ?. ou !! -> erreur
            let : x?.let { bloc avec it } -> if (x != null) { bloc }
              Emission comme if/else avec variable temporaire

  TODO 21 - HERITAGE, INTERFACES ET OBJETS
            Heritage : open class Parent / class Enfant : Parent(args)
              open : permet l heritage (par defaut les classes sont final)
              Surcharge : override fun methode() dans la sous-classe
              super.methode() -> CALL methode du parent directement
            Classes abstraites : abstract class Nom { abstract fun m() }
              Methodes abstraites : pas de corps, doivent etre surchargees
            Interfaces : interface Nom { fun m(); val p: Type }
              Implementation : class C : Interface { override fun m() ... }
              Proprietes d interface : val/var abstraites ou avec defaut
              Interfaces multiples : class C : I1, I2 { ... }
            Vtable (table de methodes virtuelles) :
              Chaque classe ouverte a une vtable dans DATA
              Heritage : copie de la vtable du parent + surcharges
              Appel virtuel : MOV BX,[AX] / CALL [BX+offset_methode]
            Object declaration (singleton) :
              object Nom { ... } -> instance unique dans DATA
              Label _KTO_Nom, init une seule fois au premier acces
            Companion object : companion object { fun create() ... }
              -> accessible via NomClasse.create() (methode statique)
            Enum class : enum class Dir { NORTH, SOUTH, EAST, WEST }
              Ordinal : NORTH=0, SOUTH=1, ... -> constantes entieres
              name : ptr vers chaine du nom dans DATA
              values() -> tableau de toutes les entrees
              valueOf(s) -> recherche par nom -> ordinal

  TODO 22 - EXTENSIONS ET FONCTIONS D ORDRE SUPERIEUR
            Fonctions d extension : fun String.hello() { println(this) }
              -> _KTF_String_hello : premier param = receveur (this dans BX)
              Appel : "abc".hello() -> PUSH ptr_chaine + CALL _KTF_String_hello
              Resolues statiquement (pas de dispatch virtuel)
            Proprietes d extension : val String.lastChar: Char get() = ...
              -> appel de fonction getter avec receveur
            Fonctions d ordre superieur : fun apply(f: (Int) -> Int, x: Int): Int
              -> parametre f est un ptr de fonction sur pile
              Appel : PUSH x / PUSH f / CALL _KTF_apply
              Dans apply : POP AX (f) / PUSH x / CALL AX
            Lambda passee en argument : apply({ it * 2 }, 5)
              -> emission de _KTF_LAMBDA_N + passage de ptr
              Trailing lambda : apply(5) { it * 2 }
            Fonctions standard d ordre superieur :
              let : obj.let { transform(it) } -> appel inline
              also : obj.also { sideEffect(it) } -> retourne obj
              run : obj.run { this.compute() } -> retourne resultat
              with : with(obj) { this.compute() } -> retourne resultat
              apply : obj.apply { this.init() } -> retourne obj
            Inline : fun inline avec lambda -> corps substitue directement
              Evite le cout d appel + allocation de fermeture

  TODO 23 - EXCEPTIONS (try / catch / finally / throw)
            ParseTryStmt : try { bloc } catch (e: ExType) { bloc } [finally { bloc }]
              Catches multiples : catch (e: Type1) { } catch (e: Type2) { }
            Mecanisme sans support OS :
              _KTX_HANDLER DW 0 dans DATA (ptr vers handler courant)
              try : sauvegarder ancien handler, installer nouveau
                MOV [_KTX_HANDLER], OFFSET _KTL_CATCH_N
              catch (e: Type) : label _KTL_CATCH_N
                AX = ptr objet exception, CMP type pour chaque catch
                Variable e : MOV [BP-n], AX
              finally : label _KTL_FINALLY_N, execute dans tous les cas
              Restauration : MOV [_KTX_HANDLER], ancien_handler
            throw expr : lever une exception
              AX = ptr objet exception
              CMP WORD PTR [_KTX_HANDLER], 0 / JZ _KTL_UNHANDLED
              MOV BX, [_KTX_HANDLER] / JMP BX
              _KTL_UNHANDLED : affiche message + MOV AX,4C01h + INT 21h
            Try comme expression : val x = try { expr } catch (e: E) { defaut }
            Types d exception predefinies :
              Exception, RuntimeException, NullPointerException,
              IllegalArgumentException, IndexOutOfBoundsException
              -> stubs : chaines constantes dans DATA
            require(cond) { msg } : si !cond -> throw IllegalArgumentException
            check(cond) { msg } : si !cond -> throw IllegalStateException

  TODO 24 - RUNTIME MINIMAL
            _KTRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _KTRT_PRINTLN : _KTRT_PRINT + CR+LF via _KT_CRLF DB 13,10,0
            _KTRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _KTRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _KTRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _KTRT_CONCAT(DI=dst, SI=src) : concatenation chaines -> AX=ptr buf
            _KTRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _KTRT_STRSUB(SI=str, BX=start, CX=len) : sous-chaine -> AX=ptr
            _KTRT_STRINDEXOF(SI=str, DI=sub) : recherche -> AX=pos|-1
            _KTRT_STRTOUPPER(SI=str) : majuscules -> AX=buf
            _KTRT_STRTOLOWER(SI=str) : minuscules -> AX=buf
            _KTRT_STRTRIM(SI=str) : supprime espaces debut/fin -> AX=buf
            _KTRT_STRREV(SI=str) : inverse la chaine -> AX=buf
            _KTRT_STRREPEAT(SI=str, CX=n) : repete n fois -> AX=buf
            _KTRT_READLINE(DI=buf) : lecture ligne STDIN -> AX=ptr
            _KTRT_ABS(AX=n) : valeur absolue -> AX
            _KTRT_MAX(AX=a, BX=b) : maximum -> AX
            _KTRT_MIN(AX=a, BX=b) : minimum -> AX
            _KTRT_NEW(CX=nb_octets) : allocation heap -> AX=ptr
            _KTRT_ARRIDXOF(SI=ptr, BX=val) : recherche dans tableau -> AX
            _KTRT_ARRSORT(SI=ptr) : tri a bulles numerique in-place
            _KTRT_ARRSUM(SI=ptr) : somme des elements -> AX
            _KTRT_TYPECODE(BX=ptr_objet) : lire typecode -> AX
            _KTRT_CHKIDX(AX=index, BX=lo, CX=hi) : verification bornes
              -> exception si hors bornes
            _KTRT_CHKNIL(AX=ptr) : verification null
              -> NullPointerException si AX=0
            _KTRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _KT_HEAP DB 4096 DUP(0) + _KT_HEAPTOP DW 0
              _KTRT_ALLOC(CX=nb_bytes) -> AX=ptr dans le heap statique
            _KTRT_STRBUF[0..511] : buffer de travail pour concatenation

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _KTF_main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseTopLevel ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _KTF_main
            Point d entree : fun main() ou fun main(args: Array<String>)
              -> label _KTF_main PROC NEAR ... _KTF_main ENDP
            Fichiers SAMPLES\KOTLIN\ a creer :
              hello.kt    (println, val/var, interpolation de chaine)
              math.kt     (fonctions, recursion, return, expressions)
              control.kt  (if/else, when, while, for, ranges)
              arrays.kt   (arrayOf, IntArray, forEach, size, indexOf)
              classes.kt  (class, data class, constructeur, proprietes)
              inherit.kt  (open class, override, interface, object)
              nullsafe.kt (nullable, ?. , ?:, !!, smart cast)
              lambda.kt   (lambdas, fonctions d ordre superieur, extension)
            Smoke tests : KOTLIN86.EXE -v SAMPLES\KOTLIN\*.kt

  ============================================================ *)

{ ============================================================
  KOTLIN86 - Compilateur Kotlin -> assembleur 8086
  Version : 1.0  Date : 2026-03-07
  Compilation : ppc386 -O2 -Mtp KOTLIN86.PAS
  ============================================================ }

Program KOTLIN86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  KT86_VERSION = '1.0';
  KT86_DATE    = '2026-03-07';

  { Limites internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ARR_ELEM  = 64;   { elements max par tableau literal inline }
  MAX_CLASS_FIELDS = 16; { champs max par classe                  }
  MAX_CLASSES      = 32; { classes max dans le programme           }
  MAX_FUN_PARAMS   = 8;  { parametres max par fonction utilisateur }
  STACK_SIZE    = 1024;

  { Caracteres speciaux (evite les accolades dans le source TP) }
  CH_LBRACE = Chr(123);  (* open brace  *)
  CH_RBRACE = Chr(125);  (* close brace *)

  { Prefixes de nommage ASM }
  KT_VAR_PFX  = '_KTV_';    { variable val/var                    }
  KT_FN_PFX   = '_KTF_';    { fonction / methode                  }
  KT_STR_PFX  = '_KTK_';    { constante chaine litterale          }
  KT_RT_PFX   = '_KTRT_';   { routine runtime                     }
  KT_LBL_PFX  = '_KTL_';    { label de saut interne               }
  KT_CLS_PFX  = '_KTC_';    { classe / vtable                     }
  KT_ENM_PFX  = '_KTE_';    { enum class                          }
  KT_ITF_PFX  = '_KTI_';    { interface                           }
  KT_OBJ_PFX  = '_KTO_';    { object singleton                    }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Kotlin }
  TY_IDX_INT      = 0;   { entier 16 bits signe         }
  TY_IDX_SHORT    = 1;   { 16 bits signe (= Int)        }
  TY_IDX_LONG     = 2;   { stub 16 bits                 }
  TY_IDX_BYTE     = 3;   { 8 bits signe                 }
  TY_IDX_BOOLEAN  = 4;   { 0 ou 1 dans AX              }
  TY_IDX_CHAR     = 5;   { 8 bits (stocke comme octet) }
  TY_IDX_FLOAT    = 6;   { stub entier tronque          }
  TY_IDX_DOUBLE   = 7;   { stub entier tronque          }
  TY_IDX_STRING   = 8;   { pointeur chaine DATA         }
  TY_IDX_ARRAY    = 9;   { pointeur bloc DATA           }
  TY_IDX_INTARRAY = 10;  { pointeur IntArray            }
  TY_IDX_UNIT     = 11;  { void (pas de valeur)         }
  TY_IDX_NOTHING  = 12;  { type bottom                  }
  TY_IDX_ANY      = 13;  { type racine                  }
  TY_IDX_LAMBDA   = 14;  { pointeur de code             }
  TY_PRIM_COUNT   = 15;
  TY_UNKNOWN      = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.kt)                 }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Kotlin (TODO 02) ---------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                         }
    TK_INTEGER,   { literal entier 42 0xFF 0b101           }
    TK_LONG,      { literal long 42L (traite comme entier) }
    TK_FLOAT,     { literal flottant 3.14 1.5e3            }
    TK_STRING,    { literal chaine "abc"                   }
    TK_CHAR,      { literal caractere 'A'                  }
    TK_IDENT,     { identificateur (non-mot-cle)           }
    TK_KEYWORD,   { mot-cle Kotlin reconnu                 }
    TK_OP,        { operateur + - * / === ?.  etc.         }
    TK_PUNCT      { ponctuation ; , ( ) [ ]                }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles (TODO 05) ------------------- }
  TSymKind = (
    SK_VAL,        { val (immutable)                  }
    SK_VAR,        { var (mutable)                    }
    SK_PARAM,      { parametre formel de fonction     }
    SK_FUN,        { declaration fun                  }
    SK_CLASS,      { declaration class                }
    SK_OBJECT,     { declaration object (singleton)   }
    SK_ENUM,       { declaration enum class           }
    SK_INTERFACE,  { declaration interface            }
    SK_COMPANION,  { companion object                 }
    SK_PROP        { propriete de classe              }
  );

  TSymRec = Record
    Name        : TString;   { identifiant Kotlin              }
    MangledName : TString;   { _KTV_nom / _KTF_nom             }
    Kind        : TSymKind;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsConst     : Boolean;   { const val : erreur si reassigne }
    IsNullable  : Boolean;   { type nullable T?                }
    IsLateinit  : Boolean;   { lateinit var                    }
    Visibility  : Byte;      { 0=public 1=private 2=protected 3=internal }
    DeclLine    : Integer;
  End;

  { ---- Types internes (TODO 06) --------------------------- }
  TTypeKind = (
    TYK_INT,
    TYK_SHORT,
    TYK_LONG,
    TYK_BYTE,
    TYK_BOOLEAN,
    TYK_CHAR,
    TYK_FLOAT,
    TYK_DOUBLE,
    TYK_STRING,
    TYK_ARRAY,
    TYK_INTARRAY,
    TYK_CLASS,
    TYK_INTERFACE,
    TYK_ENUM,
    TYK_UNIT,
    TYK_NOTHING,
    TYK_NULLABLE,
    TYK_ANY,
    TYK_LAMBDA
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : Int=2, Byte=1, ptr=2 }
  End;

  { ---- Valeurs d expression (TODO 11) --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou [_KTV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas de lvalue) }
  End;

  { ---- Segment de donnees (TODO 08) ----------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_OBJ_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

  { ---- Descripteurs de classes (TODO 16) -------------------- }
  TClassField = Record
    Name    : TString;   { nom du champ Kotlin                 }
    TypeIdx : Integer;   { type du champ                        }
    IsVal   : Boolean;   { true=val (immutable), false=var      }
    Offset  : Integer;   { offset en octets depuis debut objet  }
  End;

  TClassInfo = Record
    Name       : TString;   { nom de la classe                  }
    AsmLabel   : TString;   { prefixe ASM : _KTC_NomClasse      }
    IsData     : Boolean;   { true si data class                 }
    FieldCount : Integer;   { nombre de champs                   }
    Fields     : Array[0..MAX_CLASS_FIELDS-1] Of TClassField;
    ObjSize    : Integer;   { taille objet en octets             }
    TypeIdx    : Integer;   { indice dans TypeTab                }
    SymIdx     : Integer;   { indice dans SymTab                 }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur (TODO 02) }
  LexSrcF     : Text;
  LexLine     : String;
  LexLineNo   : Integer;
  LexColNo    : Integer;
  LexEOF      : Boolean;
  LexOpened   : Boolean;
  CurToken    : TToken;

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  { Table des types (TODO 06) }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM (TODO 07) }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    { taille cadre local courant (words)   }
  CurFnDepth   : Integer;    { 0 = global, >0 = dans une function  }
  CurFnRetLbl  : TString;    { label epilogue de la function        }
  CurFnName    : TString;    { nom de la function courante          }
  CurClassName : TString;    { nom de la classe courante            }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;    { compteur unique pour LabelGen        }

  { Segment de donnees (TODO 08) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  GCallArgCount  : Integer;  { nb args du dernier ParseCallArgs     }
  ArrayTempCount : Integer;  { compteur pour labels _KTA_N           }

  { Classes (TODO 16) }
  ClassTab     : Array[0..MAX_CLASSES-1] Of TClassInfo;
  ClassCount   : Integer;
  ObjTempCount : Integer;  { compteur pour labels _KTO_N            }

  { Fonctions et lambdas (TODO 17) }
  FunDeclCount : Integer;  { nombre de fun declarations             }
  LambdaCount  : Integer;  { compteur pour labels _KTF_LAMBDA_N     }
  SaveFrameSize : Integer; { sauvegarde CurFrameSize pendant fun    }
  SaveFnRetLbl  : TString; { sauvegarde CurFnRetLbl pendant fun     }
  SaveFnName    : TString; { sauvegarde CurFnName pendant fun       }

  { Portee, pile et cadres (TODO 18) }
  ScopeFrameStack : Array[0..MAX_SCOPE - 1] Of Integer;
                           { sauvegarde CurFrameSize par portee      }
  CaptureCount    : Integer; { compteur de cellules capturees        }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ TODO 02 - Lexeur }
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
Procedure LexScanChar;         Forward;
Procedure LexNextToken;        Forward;
{ TODO 03 - Litteraux }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
{ TODO 04 - Operateurs }
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ TODO 05 - Symboles }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                 Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
{ TODO 07 - Emetteur }
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
{ TODO 06 - Types }
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
{ TODO 08 - Donnees }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddArray(Const Lbl : TString; ACount : Integer) : Integer; Forward;
Function  DataAddObj(Const Lbl : TString; ASize : Integer) : Integer; Forward;
Procedure DataInit;      Forward;
Procedure EmitRuntime;     Forward;
Procedure EmitExprRuntime; Forward;
Procedure EmitIORuntime;   Forward;
Procedure EmitArrayRuntime; Forward;
Procedure EmitHeader;    Forward;
{ TODO 09 - Variables }
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DeclAllocSym(Const Name : TString; Kind : TSymKind) : Integer; Forward;
Procedure ParseDeclStmt(Const Kw : TString); Forward;
{ TODO 10 - Expressions primaires }
Function  ParseCallArgs : Integer; Forward;
{ TODO 13 - If / When }
Procedure ParseBlock;    Forward;
Procedure ParseIfStmt;   Forward;
Procedure ParseWhenStmt; Forward;
{ TODO 14 - Boucles }
Procedure ParseWhileStmt;   Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt;     Forward;
{ TODO 16 - Classes }
Procedure ParseClassDecl;   Forward;
Procedure EmitClassRuntime; Forward;
Function  ClassFind(Const Name : TString) : Integer; Forward;
Function  ClassFieldFind(ClsIdx : Integer;
                         Const FName : TString) : Integer; Forward;
Function  ClassFindByTypeIdx(TIdx : Integer) : Integer; Forward;
{ TODO 17 - Fonctions et lambdas }
Procedure ParseFunDecl;     Forward;
Procedure ParseReturnStmt;  Forward;
{ TODO 18 - Portee, pile et cadres }
Procedure ScopeBlockEnter;  Forward;
Procedure ScopeBlockLeave;  Forward;
Procedure EmitScopeRuntime; Forward;
{ General }
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('KOTLIN86: FATAL: ', Msg);
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
  Write('KOTLIN86:');
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
  Write('KOTLIN86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('KOTLIN86 v', KT86_VERSION, ' (', KT86_DATE, ')');
  WriteLn('Compilateur Kotlin -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: KOTLIN86 <source.kt> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.kt  : fichier Kotlin source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -h         : afficher cette aide');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  WriteLn('KOTLIN86 v', KT86_VERSION, ' - Compilateur Kotlin -> assembleur 8086');
  WriteLn;
  WriteLn('Usage: KOTLIN86 <source.kt> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.kt  : fichier Kotlin source (.kt)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -v   mode verbeux (banniere + statistiques en fin de compilation)');
  WriteLn('  -d   debug tokens (affiche chaque token lu par le lexeur)');
  WriteLn('  -w   activer les avertissements');
  WriteLn('  -h   afficher cette aide');
  WriteLn;
  WriteLn('Sous-ensemble Kotlin supporte:');
  WriteLn('  val/var, fun, if/else/when, while/do-while/for, class/data class,');
  WriteLn('  object, interface, enum class, lambdas, null safety (?. ?: !!),');
  WriteLn('  println/print/readLine, String templates, ranges (..)');
  WriteLn;
  WriteLn('Sortie: code assembleur MASM 8086 .MODEL SMALL (DOS 16 bits)');
  Halt(EXIT_OK);
End;

{ ---- Utilitaires chaines ------------------------------------ }

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

Function StrUpperCase(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpperCase := R;
End;

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToIntDef(Const S : TString; Def : LongInt) : LongInt;
Var
  V : LongInt;
  C : Integer;
Begin
  Val(S, V, C);
  If C = 0 Then StrToIntDef := V
  Else          StrToIntDef := Def;
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

Function ExtractExt(Const Path : TString) : TString;
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
    ExtractExt := StrLowerCase(Copy(Path, LastDot, Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
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
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('KOTLIN86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('KOTLIN86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('KOTLIN86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .kt }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.kt' Then
    WriteLn('KOTLIN86: avertissement: extension attendue .kt (recu: ', Ext, ')');

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

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

{ ---- Initialisation generale des variables globales -------- }

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
  CurClassName   := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  GCallArgCount  := 0;
  ArrayTempCount := 0;
  ClassCount     := 0;
  ObjTempCount   := 0;
  FunDeclCount   := 0;
  LambdaCount    := 0;
  SaveFrameSize  := 0;
  SaveFnRetLbl   := '';
  SaveFnName     := '';
  CurFrameSize   := 0;
  CaptureCount   := 0;
  LabelGenSeq    := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS KOTLIN) [IMPLEMENTE]
  ============================================================ }

{ ---- LexInit : ouvrir le fichier source -------------------- }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  LexEOF     := False;
  LexNextLine;
End;

{ ---- LexClose : fermer le fichier source ------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- IsKeyword : teste si S est un mot-cle Kotlin ---------- }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'abstract')   Or (S = 'annotation') Or (S = 'as')         Or
    (S = 'break')      Or (S = 'by')         Or (S = 'catch')      Or
    (S = 'class')      Or (S = 'companion')  Or (S = 'const')      Or
    (S = 'constructor') Or (S = 'continue')  Or (S = 'crossinline') Or
    (S = 'data')       Or (S = 'do')         Or (S = 'downTo')     Or
    (S = 'else')       Or (S = 'enum')       Or (S = 'external')   Or
    (S = 'false')      Or (S = 'final')      Or (S = 'finally')    Or
    (S = 'for')        Or (S = 'fun')        Or (S = 'if')         Or
    (S = 'import')     Or (S = 'in')         Or (S = 'infix')      Or
    (S = 'init')       Or (S = 'inline')     Or (S = 'inner')      Or
    (S = 'interface')  Or (S = 'internal')   Or (S = 'is')         Or
    (S = 'it')         Or (S = 'lateinit')   Or (S = 'noinline')   Or
    (S = 'null')       Or (S = 'object')     Or (S = 'open')       Or
    (S = 'operator')   Or (S = 'out')        Or (S = 'override')   Or
    (S = 'package')    Or (S = 'private')    Or (S = 'protected')  Or
    (S = 'public')     Or (S = 'reified')    Or (S = 'return')     Or
    (S = 'sealed')     Or (S = 'step')       Or (S = 'super')      Or
    (S = 'this')       Or (S = 'throw')      Or (S = 'to')         Or
    (S = 'true')       Or (S = 'try')        Or (S = 'typealias')  Or
    (S = 'until')      Or (S = 'val')        Or (S = 'var')        Or
    (S = 'vararg')     Or (S = 'when')       Or (S = 'where')      Or
    (S = 'while');
End;

{ ---- PrintToken : affichage debug d un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_LONG    : Write('LONG(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_CHAR    : Write('CHAR(''', T.Val, ''')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ---------- }
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

{ ---- LexSkipBlockComment : /* ... */ imbrique -------------- }
Procedure LexSkipBlockComment;
Var
  Depth : Integer;
Begin
  Inc(LexColNo, 2);
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(Depth);
      Inc(LexColNo, 2);
    End
    Else If (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo] = '*') And (LexLine[LexColNo + 1] = '/') Then
    Begin
      Dec(Depth);
      Inc(LexColNo, 2);
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- Fonctions auxiliaires de classification de caracteres -- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_');
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
  Else If (Ch >= 'A') And (Ch <= 'F') Then HexVal := 10 + Ord(Ch) - Ord('A')
  Else If (Ch >= 'a') And (Ch <= 'f') Then HexVal := 10 + Ord(Ch) - Ord('a')
  Else HexVal := 0;
End;

{ ---- LexScanIdent : identificateur ou mot-cle -------------- }
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

{ ---- LexScanNumber : decimal / hex / binaire / flottant ---- }
(*
  Formats Kotlin :
    Decimal  : 42, 1_000_000
    Hex      : 0xFF, 0XFF, 0x1A_2B
    Binaire  : 0b1010, 0B1010, 0b1010_0011
    Long     : 42L -> avertissement (traite comme Int 16 bits)
    Float    : 3.14, 3.14f, 3.14F, 1.5e3, 1.5e-2
    Double   : 3.14, 3.14d (par defaut flottant = double en Kotlin)
  Separateurs _ ignores.
  Flottants tronques en entier 16 bits.
*)
Procedure LexScanNumber;
Var
  N        : LongInt;
  Base     : Integer;
  IsFloat  : Boolean;
  IsLong   : Boolean;
  NegExp   : Boolean;
  Ch       : Char;
  FracDiv  : Real;
  FracVal  : Real;
  ExpVal   : Integer;
  FltVal   : Real;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  IsLong  := False;
  NegExp  := False;
  FracVal := 0.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];

  { Prefixe 0x (hex) ou 0b (binaire) }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo, 2);
    End
    Else If (Ch = 'b') Or (Ch = 'B') Then
    Begin
      Base := 2;
      Inc(LexColNo, 2);
    End
    Else
    Begin
      N := 0;
      Inc(LexColNo);
    End;
  End
  Else If (Ch >= '1') And (Ch <= '9') Then
  Begin
    N := Ord(Ch) - Ord('0');
    Inc(LexColNo);
  End
  Else
  Begin
    N := 0;
    Inc(LexColNo);
  End;

  { Boucle sur les chiffres (avec _ ignore) }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '_' Then
    Begin
      Inc(LexColNo);
      Continue;
    End;
    If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
      Inc(LexColNo);
    End
    Else If (Base = 2) And (Ch >= '0') And (Ch <= '1') Then
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

  { Partie decimale .ddd (base 10 seulement) }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Or
           (LexLine[LexColNo] = '_')) Do
    Begin
      If LexLine[LexColNo] <> '_' Then
      Begin
        FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
      End;
      Inc(LexColNo);
    End;
  End;

  { Exposant e/E [+-]ddd }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'e') Or (LexLine[LexColNo] = 'E')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    NegExp := False;
    ExpVal := 0;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;

  { Suffixe L (Long) }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'L') Or (LexLine[LexColNo] = 'l')) Then
  Begin
    IsLong := True;
    Inc(LexColNo);
    WarnMsg('suffixe Long ignore (traite comme Int 16 bits)');
  End;

  { Suffixe F (Float) ou D (Double) }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'f') Or (LexLine[LexColNo] = 'F') Or
      (LexLine[LexColNo] = 'd') Or (LexLine[LexColNo] = 'D')) Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
    WarnMsg('suffixe flottant ignore (tronque en entier 16 bits)');
  End;

  { Calculer la valeur finale (tronquee en entier 16 bits) }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
  End;

  CurToken.IntVal := N;
  Str(N, CurToken.Val);
  If IsLong Then
    CurToken.Kind := TK_LONG
  Else If IsFloat Then
    CurToken.Kind := TK_FLOAT
  Else
    CurToken.Kind := TK_INTEGER;
End;

{ ---- LexScanEscChar : sequence d echappement Kotlin -------- }
(*
  Sequences reconnues : \n \t \r \b \\ \" \' \$ \uNNNN
*)
Function LexScanEscChar : Char;
Var
  Ch : Char;
  V  : Integer;
  I  : Integer;
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
    'b'  : LexScanEscChar := #8;
    '\'  : LexScanEscChar := '\';
    '"'  : LexScanEscChar := '"';
    '''' : LexScanEscChar := '''';
    '$'  : LexScanEscChar := '$';
    'u'  :
    Begin
      V := 0;
      For I := 1 To 4 Do
      Begin
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End;
      LexScanEscChar := Chr(V And $FF);
    End;
  Else
    LexScanEscChar := Ch;
  End;
End;

{ ---- LexScanString : chaine entre guillemets doubles ------- }
(*
  Kotlin : "abc\ndef"
  Interpolation : "$var" et "$<expr>" sont conserves dans la chaine brute
  pour etre traites par le parser (TODO 03).
  Triple guillemets : """...""" non supporte -> avertissement + traitement
  comme chaine normale.
*)
Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter le premier " }
  { Detecter triple guillemet """...""" }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '"') And
     (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] = '"') Then
  Begin
    Inc(LexColNo, 2); { sauter les deux " supplementaires }
    WarnMsg('triple-quoted string (raw) : traitement simplifie');
    { Lire jusqu au prochain """ }
    While Not LexEOF Do
    Begin
      If LexColNo > Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
        Continue;
      End;
      Ch := LexLine[LexColNo];
      If (Ch = '"') And (LexColNo + 1 <= Length(LexLine)) And
         (LexLine[LexColNo + 1] = '"') And
         (LexColNo + 2 <= Length(LexLine)) And
         (LexLine[LexColNo + 2] = '"') Then
      Begin
        Inc(LexColNo, 3);
        Break;
      End;
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End
  Else
  Begin
    { Chaine simple "..." }
    While (LexColNo <= Length(LexLine)) Do
    Begin
      Ch := LexLine[LexColNo];
      If Ch = '"' Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If Ch = '\' Then
      Begin
        Inc(LexColNo);
        Ch := LexScanEscChar;
        If Length(S) < MAX_STR Then S := S + Ch;
      End
      Else
      Begin
        If Length(S) < MAX_STR Then S := S + Ch;
        Inc(LexColNo);
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanChar : litteral caractere 'A' ou '\n' --------- }
Procedure LexScanChar;
Var
  Ch : Char;
Begin
  Inc(LexColNo); { sauter l apostrophe ouvrante }
  Ch := #0;
  If LexColNo <= Length(LexLine) Then
  Begin
    If LexLine[LexColNo] = '\' Then
    Begin
      Inc(LexColNo);
      Ch := LexScanEscChar;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  { Sauter l apostrophe fermante }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Inc(LexColNo);
  CurToken.Kind   := TK_CHAR;
  CurToken.Val    := Ch;
  CurToken.IntVal := Ord(Ch);
End;

{ ---- LexNextToken : scanner principal ---------------------- }
(*
  Gere les espaces, commentaires // et /* (imbrique),
  puis identifie le prochain token : ident/keyword, nombre,
  chaine, caractere, operateur multi-caracteres, ponctuation.

  Operateurs multi-caracteres Kotlin :
    ===  !==  ==  !=  <=  >=  &&  ||  ++  --  ..  ?.  ?:  !!
    +=  -=  *=  /=  %=  ->  ::  as?  !in  !is
*)
Procedure LexNextToken;
Var
  Ch : Char;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  { Sauter espaces et commentaires }
  While Not LexEOF Do
  Begin
    { Sauter les blancs sur la ligne courante }
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] <= ' ') Do
      Inc(LexColNo);
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    { Commentaire de ligne // }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexNextLine;
      Continue;
    End;
    { Commentaire de bloc imbrique /* ... */ }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
      Continue;
    End;
    Break;
  End;

  If LexEOF Then
  Begin
    CurToken.Kind := TK_EOF;
    CurToken.Val  := '';
    Exit;
  End;

  CurToken.Line := LexLineNo;
  CurToken.Col  := LexColNo;
  Ch := LexLine[LexColNo];

  { ---- Identificateurs et mots-cles ---- }
  If IsIdentStart(Ch) Then
  Begin
    LexScanIdent;
    PrintToken(CurToken);
    Exit;
  End;

  { ---- Nombres ---- }
  If (Ch >= '0') And (Ch <= '9') Then
  Begin
    LexScanNumber;
    PrintToken(CurToken);
    Exit;
  End;

  { ---- Chaines ---- }
  If Ch = '"' Then
  Begin
    LexScanString;
    PrintToken(CurToken);
    Exit;
  End;

  { ---- Caracteres ---- }
  If Ch = '''' Then
  Begin
    LexScanChar;
    PrintToken(CurToken);
    Exit;
  End;

  { ---- Operateurs multi-caracteres ---- }

  { = == === }
  If Ch = '=' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '===';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '==';
      End;
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '=';
    End;
    PrintToken(CurToken); Exit;
  End;

  { ! != !== !! }
  If Ch = '!' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '!==';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '!=';
      End;
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '!') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '!!';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '!';
    End;
    PrintToken(CurToken); Exit;
  End;

  { < <= }
  If Ch = '<' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '<=';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '<';
    End;
    PrintToken(CurToken); Exit;
  End;

  { > >= }
  If Ch = '>' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '>=';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '>';
    End;
    PrintToken(CurToken); Exit;
  End;

  { + ++ += }
  If Ch = '+' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '++';
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '+=';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '+';
    End;
    PrintToken(CurToken); Exit;
  End;

  { - -- -= -> }
  If Ch = '-' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '--';
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '-=';
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '->';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '-';
    End;
    PrintToken(CurToken); Exit;
  End;

  { * *= }
  If Ch = '*' Then
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
    PrintToken(CurToken); Exit;
  End;

  { / /= (commentaires deja traites plus haut) }
  If Ch = '/' Then
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
    PrintToken(CurToken); Exit;
  End;

  { % %= }
  If Ch = '%' Then
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
    PrintToken(CurToken); Exit;
  End;

  { & && }
  If Ch = '&' Then
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
    PrintToken(CurToken); Exit;
  End;

  { | || }
  If Ch = '|' Then
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
    PrintToken(CurToken); Exit;
  End;

  { ? ?. ?: }
  If Ch = '?' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '?.';
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '?:';
    End
    Else
    Begin
      CurToken.Kind := TK_OP; CurToken.Val := '?';
    End;
    PrintToken(CurToken); Exit;
  End;

  { . .. }
  If Ch = '.' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '..';
    End
    Else
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '.';
    End;
    PrintToken(CurToken); Exit;
  End;

  { : :: }
  If Ch = ':' Then
  Begin
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '::';
    End
    Else
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
    End;
    PrintToken(CurToken); Exit;
  End;

  { # (annotation) }
  If Ch = '#' Then
  Begin
    Inc(LexColNo);
    CurToken.Kind := TK_OP; CurToken.Val := '#';
    PrintToken(CurToken); Exit;
  End;

  { @ (annotation) }
  If Ch = '@' Then
  Begin
    Inc(LexColNo);
    CurToken.Kind := TK_PUNCT; CurToken.Val := '@';
    PrintToken(CurToken); Exit;
  End;

  { ---- Ponctuation simple ---- }
  { ( ) [ ] , ; -> TK_PUNCT }
  { accolades Chr(123) = open, Chr(125) = close }
  If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
     (Ch = ',') Or (Ch = ';') Or (Ch = Chr(123)) Or (Ch = Chr(125)) Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := Ch;
    Inc(LexColNo);
    PrintToken(CurToken); Exit;
  End;

  { ---- Caractere inconnu -> operateur simple ---- }
  CurToken.Kind := TK_OP;
  CurToken.Val  := Ch;
  Inc(LexColNo);
  PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- ExprMakeImm : construire une valeur immediate --------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : valeur invalide (void/erreur) ---------- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_UNIT;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : valeur booleenne Kotlin (0 ou 1) ------- }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un TK_INTEGER en valeur -------- }
(* IntVal est deja calcule par LexScanNumber pour dec/hex/bin. *)
(* Separateurs _ deja ignores par le lexeur.                   *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ ---- LitEvalFloat : convertir un TK_FLOAT en entier -------- }
(* Flottant tronque en entier 16 bits (pas de FPU 8086).       *)
(* Les suffixes F/D sont deja traites par le lexeur.           *)
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ----- }
(* Types de tokens acceptes : TK_INTEGER, TK_LONG, TK_FLOAT,  *)
(* TK_STRING, TK_CHAR, TK_KEYWORD (true/false/null).          *)
(* TK_STRING : cree une entree dans le segment DATA via        *)
(* DataAddStr et retourne un EK_MEM pointant vers le label.    *)
(* TK_CHAR : retourne Ord(caractere) comme immediat.           *)
(* TK_LONG : traite comme TK_INTEGER (16 bits).                *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);
    TK_LONG :
      LitEvalInt(T, Res);    { Long -> traite comme Int 16 bits }
    TK_FLOAT :
      LitEvalFloat(T, Res);  { flottant tronque en entier       }
    TK_STRING :
    Begin
      { L'adresse DATA est resolue dans ParsePrimary (TODO 10) }
      { via DataAddStr et LEA AX, [_KTK_n]                     }
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
    End;
    TK_CHAR :
    Begin
      { Caractere : 'A' -> Ord('A') = 65 }
      If Length(T.Val) > 0 Then
        ExprMakeImm(Ord(T.Val[1]), TY_IDX_CHAR, Res)
      Else
        ExprMakeImm(0, TY_IDX_CHAR, Res);
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else If T.Val = 'null' Then
        ExprMakeImm(0, TY_IDX_ANY, Res)  { null -> 0 (reference nulle) }
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

(* ---- IsAssignOp : detecter un operateur d affectation ------ *)
(* Kotlin : = += -= *= /= %=                                    *)
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp := (Op = '=') Or (Op = '+=') Or (Op = '-=') Or
                (Op = '*=') Or (Op = '/=') Or (Op = '%=');
End;

(* ---- BinOpPrec : table de precedences Kotlin (Pratt) ------- *)
(* Retourne 0 si l operateur n est pas binaire connu.            *)
(* Niveaux (croissant = plus serre, 0 = aucun) :                *)
(*   1 = affectation : = += -= *= /= %=                         *)
(*   2 = disjonction : ||                                        *)
(*   3 = conjonction : &&                                        *)
(*   4 = egalite     : == != === !==                             *)
(*   5 = comparaison : < <= > >=                                 *)
(*   6 = range       : ..                                        *)
(*   7 = infixe Kotlin : in !in is !is (fonctions infixes)       *)
(*   8 = elvis       : ?:                                        *)
(*   9 = additif     : + -                                       *)
(*  10 = multiplicatif : * / %                                   *)
(*  11 = cast        : as as?                                    *)
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If IsAssignOp(Op)  Then BinOpPrec := 1
  Else If Op = '||'  Then BinOpPrec := 2
  Else If Op = '&&'  Then BinOpPrec := 3
  Else If (Op = '==')  Or (Op = '!=') Or
          (Op = '===') Or (Op = '!==') Then BinOpPrec := 4
  Else If (Op = '<')  Or (Op = '<=') Or
          (Op = '>')  Or (Op = '>=') Then BinOpPrec := 5
  Else If Op = '..'   Then BinOpPrec := 6
  Else If (Op = 'in')  Or (Op = '!in') Or
          (Op = 'is')  Or (Op = '!is') Then BinOpPrec := 7
  Else If Op = '?:'   Then BinOpPrec := 8
  Else If (Op = 'shl') Or (Op = 'shr') Or (Op = 'ushr') Or
          (Op = 'and') Or (Op = 'or') Or (Op = 'xor') Then BinOpPrec := 8
  Else If (Op = '+')  Or (Op = '-') Then BinOpPrec := 9
  Else If (Op = '*')  Or (Op = '/') Or (Op = '%') Then BinOpPrec := 10
  Else If (Op = 'as') Or (Op = 'as?') Then BinOpPrec := 11
  Else BinOpPrec := 0;
End;

(* ---- BinOpIsRight : operateurs droite-associatifs ---------- *)
(* En Kotlin : affectation et elvis (?:) sont droite-assoc.     *)
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := IsAssignOp(Op) Or (Op = '?:');
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

(* ---- ParseCallArgs : empiler les arguments d un appel ------ *)
(* Lit les expressions separees par ',' jusqu au ')' fermant.    *)
(* Les arguments sont empiles gauche a droite (PUSH AX).         *)
(* Retourne le nombre d arguments.                               *)
Function ParseCallArgs : Integer;
Var
  N   : Integer;
  Arg : TExprVal;
Begin
  N := 0;
  ParserAdvance; { consomme '(' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
  Begin
    ParserAdvance; { consomme ')' : 0 arguments }
    ParseCallArgs := 0;
    Exit;
  End;
  Repeat
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstrA('PUSH', 'AX');
    Inc(N);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance  { consomme ',' }
    Else
      Break;
  Until False;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;  { consomme ')' }
  ParseCallArgs := N;
End;

(* ---- ParsePrimary : atome du parseur Pratt ----------------- *)
(* Gere : litteraux (int, long, float, string, char),           *)
(* mots-cles (true, false, null, this, super),                   *)
(* identifiants, appels de fonctions, parentheses, acces index,  *)
(* acces membre, safe call, not-null assert.                     *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  IdName   : TString;
  SIdx     : Integer;
  I        : Integer;
  Lbl      : TString;
  NArgs    : Integer;
  SVal     : TString;
  MembName : TString;
  ArrLbl   : TString;
  LblNull  : TString;
  LblEnd   : TString;
  ClsIdx   : Integer;
  ClsFI    : Integer;
  ObjLbl   : TString;
Begin
  Case CurToken.Kind Of
    TK_INTEGER, TK_LONG, TK_FLOAT, TK_CHAR :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;
    TK_STRING :
    Begin
      (* Chaine litterale : creer entree dans DATA + LEA AX *)
      Lbl := DataAddStr(CurToken.Val);
      ParserAdvance;
      EmitInstrAB('LEA', 'AX', Lbl);
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
    Begin
      If (CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'null') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'this' Then
      Begin
        (* this : pointeur objet courant, passe via BX en contexte classe *)
        ParserAdvance;
        If CurClassName = '' Then
        Begin
          WarnMsg('"this" utilise hors d''une classe');
          EmitInstrAB('XOR', 'AX', 'AX');
        End
        Else
          EmitInstrAB('MOV', 'AX', 'BX');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_ANY;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else If CurToken.Val = 'super' Then
      Begin
        (* super : stub, traite comme this *)
        ParserAdvance;
        EmitInstrAB('MOV', 'AX', 'BX');
        Res.Kind    := EK_AX;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_ANY;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else
      Begin
        (* Mot-cle non-litteral : pas une expression primaire *)
        ExprMakeNone(Res);
        ParserAdvance;
      End;
    End;
    TK_IDENT :
    Begin
      IdName := CurToken.Val;
      ParserAdvance;
      (* Appel de fonction : nom(args) *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        { TODO 12 - Gestion speciale des fonctions I/O builtin }
        If (IdName = 'println') Or (IdName = 'print') Then
        Begin
          ParserAdvance; { consomme '(' }
          NArgs := 0;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
          Begin
            Repeat
              ParseExpr(Res);
              ExprFlushToAX(Res);
              { Detecter le type pour choisir la routine }
              If (Res.TypeIdx = TY_IDX_STRING) Or
                 (Res.TypeIdx = TY_IDX_CHAR) Then
              Begin
                EmitInstrAB('MOV', 'SI', 'AX');
                EmitInstr('CALL _KTRT_PRINTSTR');
              End
              Else If Res.TypeIdx = TY_IDX_BOOLEAN Then
              Begin
                EmitComment('boolean -> "true"/"false"');
                LblEnd := LabelGen;
                LblNull := LabelGen;
                EmitInstrAB('TEST', 'AX', 'AX');
                EmitInstrA('JZ', LblNull);
                EmitInstrAB('MOV', 'SI', 'OFFSET _KT_TRUE_S');
                EmitInstrA('JMP', LblEnd);
                EmitLabel(LblNull);
                EmitInstrAB('MOV', 'SI', 'OFFSET _KT_FALSE_S');
                EmitLabel(LblEnd);
                EmitInstr('CALL _KTRT_PRINTSTR');
              End
              Else If ClassFindByTypeIdx(Res.TypeIdx) >= 0 Then
              Begin
                { TODO 16 - println d un objet classe }
                ClsIdx := ClassFindByTypeIdx(Res.TypeIdx);
                If ClassTab[ClsIdx].IsData Then
                Begin
                  EmitInstrAB('MOV', 'BX', 'AX');
                  EmitInstr('CALL ' + KT_FN_PFX + ClassTab[ClsIdx].Name +
                            '_toString');
                End
                Else
                Begin
                  EmitComment('println objet (non-data) -> adresse');
                  EmitInstr('CALL _KTRT_PRINT');
                End;
              End
              Else
              Begin
                { Entier ou autre type numerique }
                EmitInstr('CALL _KTRT_PRINT');
              End;
              Inc(NArgs);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance
              Else
                Break;
            Until False;
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance; { consomme ')' }
          { println ajoute un saut de ligne final }
          If IdName = 'println' Then
            EmitInstr('CALL _KTRT_NEWLINE');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_UNIT;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        Else If (IdName = 'readLine') Or (IdName = 'readln') Then
        Begin
          ParserAdvance; { consomme '(' }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance; { consomme ')' }
          EmitInstr('CALL _KTRT_READLINE');
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_STRING;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        { TODO 15 - arrayOf(e0, e1, ...) / intArrayOf(e0, e1, ...) }
        Else If (IdName = 'arrayOf') Or (IdName = 'intArrayOf') Then
        Begin
          ParserAdvance; { consomme '(' }
          ArrLbl := '_KTA_' + IntToStr(ArrayTempCount);
          Inc(ArrayTempCount);
          NArgs := 0;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
          Begin
            Repeat
              ParseExpr(Res);
              ExprFlushToAX(Res);
              EmitInstrA('PUSH', 'AX');
              Inc(NArgs);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance
              Else
                Break;
            Until False;
          End;
          DataAddArray(ArrLbl, NArgs);
          { Stocker les elements dans l ordre (depiler en sens inverse) }
          I := NArgs - 1;
          While I >= 0 Do
          Begin
            EmitInstrA('POP', 'AX');
            SVal := ArrLbl + '_D+' + IntToStr(I * 2);
            EmitInstrAB('MOV', 'WORD PTR [' + SVal + ']', 'AX');
            Dec(I);
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance; { consomme ')' }
          EmitInstrAB('MOV', 'AX', 'OFFSET ' + ArrLbl);
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          If IdName = 'intArrayOf' Then
            Res.TypeIdx := TY_IDX_INTARRAY
          Else
            Res.TypeIdx := TY_IDX_ARRAY;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        { TODO 15 - IntArray(n) : tableau de n entiers init a 0 }
        Else If IdName = 'IntArray' Then
        Begin
          ParserAdvance; { consomme '(' }
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrA('PUSH', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance; { consomme ')' }
          { Ignorer le lambda d initialisation optionnel }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val[1] = CH_LBRACE) Then
          Begin
            NArgs := 1;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And
                       (CurToken.Val[1] = CH_RBRACE)) Do
              ParserAdvance;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val[1] = CH_RBRACE) Then
              ParserAdvance;
          End;
          ArrLbl := '_KTA_' + IntToStr(ArrayTempCount);
          Inc(ArrayTempCount);
          { Taille fixe MAX_ARR_ELEM : le count reel est ecrit a l execution }
          DataAddArray(ArrLbl, MAX_ARR_ELEM);
          EmitInstrA('POP', 'CX');
          EmitComment('IntArray(n) : stocker count');
          EmitInstrAB('MOV', 'WORD PTR [' + ArrLbl + ']', 'CX');
          EmitInstrAB('MOV', 'AX', 'OFFSET ' + ArrLbl);
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_INTARRAY;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
        End
        Else
        Begin
          { TODO 16 - Appel constructeur de classe : Nom(args) }
          ClsIdx := ClassFind(IdName);
          If ClsIdx >= 0 Then
          Begin
            { Allouer un bloc objet statique dans DATA }
            ObjLbl := KT_OBJ_PFX + IntToStr(ObjTempCount);
            Inc(ObjTempCount);
            DataAddObj(ObjLbl, ClassTab[ClsIdx].ObjSize);
            EmitComment('new ' + IdName + '()');
            EmitInstrAB('MOV', 'WORD PTR [' + ObjLbl + ']', '0'); { vtable = 0 : pas de dispatch virtuel, reserve pour usage futur }
            ParserAdvance; { consomme '(' }
            { Parser et stocker les arguments dans les champs }
            For ClsFI := 0 To ClassTab[ClsIdx].FieldCount - 1 Do
            Begin
              If ClsFI > 0 Then
              Begin
                If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                  ParserAdvance; { consomme ',' }
              End;
              If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
              Begin
                ParseExpr(Res);
                ExprFlushToAX(Res);
                EmitInstrAB('MOV', 'WORD PTR [' + ObjLbl + '+' +
                  IntToStr(ClassTab[ClsIdx].Fields[ClsFI].Offset) + ']', 'AX');
              End;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstrAB('MOV', 'AX', 'OFFSET ' + ObjLbl);
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := ClassTab[ClsIdx].TypeIdx;
            Res.Offset  := 0;
            Res.SymIdx  := -1;
          End
          Else
          Begin
          { Appel de fonction generique }
          NArgs := ParseCallArgs;
          GCallArgCount := NArgs;
          SIdx := SymFind(IdName);
          If (SIdx >= 0) And (SymTab[SIdx].Kind = SK_FUN) Then
            EmitInstrA('CALL', SymTab[SIdx].MangledName)
          Else
            EmitInstrA('CALL', KT_FN_PFX + SymNameClean(IdName));
          (* Nettoyer la pile si arguments *)
          If NArgs > 0 Then
          Begin
            SVal := IntToStr(NArgs * 2);
            EmitInstrAB('ADD', 'SP', SVal);
          End;
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          If SIdx >= 0 Then
            Res.TypeIdx := SymTab[SIdx].TypeIdx
          Else
            Res.TypeIdx := TY_IDX_ANY;
          Res.Offset  := 0;
          Res.SymIdx  := -1;
          End;
        End;
      End
      Else
      Begin
        (* Variable simple *)
        SIdx := SymFind(IdName);
        If SIdx >= 0 Then
        Begin
          ExprLoad(SIdx, Res);
        End
        Else
        Begin
          (* Identifiant non declare : avertissement, retourne 0 *)
          WarnMsg('identifiant non declare : "' + IdName + '"');
          ExprMakeImm(0, TY_IDX_INT, Res);
        End;
      End;
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;  (* consomme '(' *)
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;  (* consomme ')' *)
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

  (* --- Suffixes postfixe : . ?. !! [] --- *)
  While True Do
  Begin
    (* Acces membre : expr.membre ou appel methode expr.membre(args) *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Begin
      ExprFlushToAX(Res);
      ParserAdvance; { consomme '.' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        MembName := CurToken.Val;
        ParserAdvance;
        (* Appel methode : expr.membre(args) *)
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          { TODO 12 - Methodes de conversion builtin }
          If MembName = 'toString' Then
          Begin
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstr('CALL _KTRT_NUMTOSTR');
            EmitInstrAB('MOV', 'AX', 'SI');
            Res.TypeIdx := TY_IDX_STRING;
          End
          Else If MembName = 'toInt' Then
          Begin
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            If Res.TypeIdx = TY_IDX_STRING Then
            Begin
              EmitInstrAB('MOV', 'SI', 'AX');
              EmitInstr('CALL _KTRT_STRTONUM');
            End;
            Res.TypeIdx := TY_IDX_INT;
          End
          Else If MembName = 'toChar' Then
          Begin
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstrAB('AND', 'AX', '00FFh');
            Res.TypeIdx := TY_IDX_CHAR;
          End
          Else If (MembName = 'toByte') Or (MembName = 'toShort') Or
                  (MembName = 'toLong') Then
          Begin
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            { Stub : AX reste tel quel }
            Res.TypeIdx := TY_IDX_INT;
          End
          { TODO 15 - Methodes tableau : get, set, indexOf, contains, sum, sorted }
          Else If (MembName = 'get') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrA('PUSH', 'AX'); { sauver base tableau }
            ParserAdvance; { consomme '(' }
            ParseExpr(Res);
            ExprFlushToAX(Res);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstrAB('SHL', 'AX', '1');
            EmitInstrAB('ADD', 'AX', '2');
            EmitInstrA('POP', 'BX');
            EmitInstrAB('ADD', 'BX', 'AX');
            EmitInstrAB('MOV', 'AX', '[BX]');
            Res.TypeIdx := TY_IDX_INT;
          End
          Else If (MembName = 'set') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrA('PUSH', 'AX'); { sauver base tableau }
            ParserAdvance; { consomme '(' }
            ParseExpr(Res);
            ExprFlushToAX(Res);
            EmitInstrA('PUSH', 'AX'); { sauver index }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance;
            ParseExpr(Res);
            ExprFlushToAX(Res); { AX = valeur }
            EmitInstrA('POP', 'BX'); { BX = index }
            EmitInstrAB('SHL', 'BX', '1');
            EmitInstrAB('ADD', 'BX', '2');
            EmitInstrA('POP', 'DX'); { DX = base tableau }
            EmitInstrAB('ADD', 'BX', 'DX');
            EmitInstrAB('MOV', '[BX]', 'AX');
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            Res.TypeIdx := TY_IDX_UNIT;
          End
          Else If (MembName = 'indexOf') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrA('PUSH', 'AX'); { sauver base tableau }
            ParserAdvance; { consomme '(' }
            ParseExpr(Res);
            ExprFlushToAX(Res); { AX = valeur a chercher }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstrA('POP', 'BX'); { BX = base tableau }
            EmitInstr('CALL _KTRT_ARRIDXOF');
            Res.TypeIdx := TY_IDX_INT;
          End
          Else If (MembName = 'contains') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrA('PUSH', 'AX'); { sauver base tableau }
            ParserAdvance; { consomme '(' }
            ParseExpr(Res);
            ExprFlushToAX(Res); { AX = valeur }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstrA('POP', 'BX'); { BX = base tableau }
            EmitInstr('CALL _KTRT_ARRIDXOF');
            LblEnd := LabelGen;
            LblNull := LabelGen;
            EmitInstrAB('CMP', 'AX', '-1');
            EmitInstrA('JE', LblNull);
            EmitInstrAB('MOV', 'AX', '1');
            EmitInstrA('JMP', LblEnd);
            EmitLabel(LblNull);
            EmitInstrAB('XOR', 'AX', 'AX');
            EmitLabel(LblEnd);
            Res.TypeIdx := TY_IDX_BOOLEAN;
          End
          Else If (MembName = 'sum') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrAB('MOV', 'BX', 'AX');
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstr('CALL _KTRT_ARRSUM');
            Res.TypeIdx := TY_IDX_INT;
          End
          Else If (MembName = 'sorted') And
                  ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitInstrAB('MOV', 'BX', 'AX');
            ParserAdvance; { consomme '(' }
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance; { consomme ')' }
            EmitInstr('CALL _KTRT_ARRSORT');
            Res.TypeIdx := TY_IDX_ARRAY;
          End
          Else
          Begin
            { TODO 16 - Appel methode toString() sur data class }
            ClsIdx := ClassFindByTypeIdx(Res.TypeIdx);
            If (MembName = 'toString') And (ClsIdx >= 0) And
               ClassTab[ClsIdx].IsData Then
            Begin
              ParserAdvance; { consomme '(' }
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance; { consomme ')' }
              EmitInstrAB('MOV', 'BX', 'AX');
              EmitInstr('CALL ' + KT_FN_PFX + ClassTab[ClsIdx].Name + '_toString');
              Res.TypeIdx := TY_IDX_STRING;
            End
            Else If (MembName = 'hashCode') And (ClsIdx >= 0) Then
            Begin
              ParserAdvance; { consomme '(' }
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance; { consomme ')' }
              EmitInstrAB('XOR', 'AX', 'AX'); { stub : retourne 0 - une impl reelle calculerait un hash base sur les champs }
              Res.TypeIdx := TY_IDX_INT;
            End
            Else If (MembName = 'copy') And (ClsIdx >= 0) And
                    ClassTab[ClsIdx].IsData Then
            Begin
              { copy() : alloue un nouveau bloc et copie les champs }
              ObjLbl := KT_OBJ_PFX + IntToStr(ObjTempCount);
              Inc(ObjTempCount);
              DataAddObj(ObjLbl, ClassTab[ClsIdx].ObjSize);
              EmitInstrAB('MOV', 'BX', 'AX');
              For ClsFI := 0 To ClassTab[ClsIdx].FieldCount - 1 Do
              Begin
                EmitInstrAB('MOV', 'AX', '[BX+' +
                  IntToStr(ClassTab[ClsIdx].Fields[ClsFI].Offset) + ']');
                EmitInstrAB('MOV', 'WORD PTR [' + ObjLbl + '+' +
                  IntToStr(ClassTab[ClsIdx].Fields[ClsFI].Offset) + ']', 'AX');
              End;
              ParserAdvance; { consomme '(' }
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
                ParserAdvance; { consomme ')' }
              EmitInstrAB('MOV', 'AX', 'OFFSET ' + ObjLbl);
              Res.TypeIdx := ClassTab[ClsIdx].TypeIdx;
            End
            Else
            Begin
            EmitInstrA('PUSH', 'AX'); { receveur en premier arg }
            NArgs := ParseCallArgs;
            GCallArgCount := NArgs + 1;
            EmitInstrA('CALL', KT_FN_PFX + MembName);
            SVal := IntToStr((NArgs + 1) * 2);
            EmitInstrAB('ADD', 'SP', SVal);
            Res.TypeIdx := TY_IDX_ANY;
            End;
          End;
        End
        Else
        Begin
          { TODO 15 - Propriete arr.size }
          If (MembName = 'size') And
             ((Res.TypeIdx = TY_IDX_ARRAY) Or (Res.TypeIdx = TY_IDX_INTARRAY)) Then
          Begin
            EmitComment('arr.size -> count word');
            EmitInstrAB('MOV', 'BX', 'AX');
            EmitInstrAB('MOV', 'AX', '[BX]');
            Res.TypeIdx := TY_IDX_INT;
          End
          Else
          Begin
            { TODO 16 - Acces champ de classe : obj.field }
            ClsIdx := ClassFindByTypeIdx(Res.TypeIdx);
            If ClsIdx >= 0 Then
            Begin
              ClsFI := ClassFieldFind(ClsIdx, MembName);
              If ClsFI >= 0 Then
              Begin
                EmitComment('acces champ .' + MembName + ' offset ' +
                  IntToStr(ClassTab[ClsIdx].Fields[ClsFI].Offset));
                EmitInstrAB('MOV', 'BX', 'AX');
                EmitInstrAB('MOV', 'AX', '[BX+' +
                  IntToStr(ClassTab[ClsIdx].Fields[ClsFI].Offset) + ']');
                Res.TypeIdx := ClassTab[ClsIdx].Fields[ClsFI].TypeIdx;
              End
              Else
              Begin
                EmitComment('champ inconnu .' + MembName);
                EmitInstrAB('MOV', 'BX', 'AX');
                EmitInstrAB('MOV', 'AX', '[BX]');
                Res.TypeIdx := TY_IDX_ANY;
              End;
            End
            Else
            Begin
            (* Acces champ : stub, charge via offset pointeur *)
            EmitComment('acces membre .' + MembName);
            EmitInstrAB('MOV', 'BX', 'AX');
            EmitInstrAB('MOV', 'AX', '[BX]');
            Res.TypeIdx := TY_IDX_ANY;
            End;
          End;
        End;
      End
      Else
        CompileError('identifiant attendu apres "."');
      Res.Kind    := EK_AX;
      Res.SymIdx  := -1;
    End
    (* Safe call : expr?.membre *)
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '?.') Then
    Begin
      ExprFlushToAX(Res);
      LblNull := LabelGen;
      LblEnd  := LabelGen;
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JZ', LblNull);
      ParserAdvance; { consomme '?.' }
      If CurToken.Kind = TK_IDENT Then
      Begin
        MembName := CurToken.Val;
        ParserAdvance;
        (* Appel methode safe : expr?.membre(args) *)
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          EmitInstrA('PUSH', 'AX');
          NArgs := ParseCallArgs;
          GCallArgCount := NArgs + 1;
          EmitInstrA('CALL', KT_FN_PFX + MembName);
          SVal := IntToStr((NArgs + 1) * 2);
          EmitInstrAB('ADD', 'SP', SVal);
        End
        Else
        Begin
          EmitComment('safe access ?.' + MembName);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrAB('MOV', 'AX', '[BX]');
        End;
        EmitInstrA('JMP', LblEnd);
      End
      Else
      Begin
        CompileError('identifiant attendu apres "?."');
        EmitInstrA('JMP', LblEnd);
      End;
      EmitLabel(LblNull);
      EmitInstrAB('XOR', 'AX', 'AX'); { null -> AX = 0 }
      EmitLabel(LblEnd);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_ANY;
      Res.SymIdx  := -1;
    End
    (* Not-null assert : expr!! *)
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '!!') Then
    Begin
      ExprFlushToAX(Res);
      ParserAdvance;
      LblEnd := LabelGen;
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrA('JNZ', LblEnd);
      EmitInstrA('CALL', KT_RT_PFX + 'PANIC');
      EmitLabel(LblEnd);
      Res.Kind    := EK_AX;
      Res.SymIdx  := -1;
    End
    (* Acces index : expr[i] *)
    Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX'); { sauver base du tableau }
      ParserAdvance; { consomme '[' }
      ParseExpr(Res);
      ExprFlushToAX(Res);
      EmitInstrAB('SHL', 'AX', '1');  { index * 2 (taille mot 16 bits) }
      EmitInstrAB('ADD', 'AX', '2');  { +2 pour sauter le count word }
      EmitInstrA('POP', 'BX');         { BX = base tableau }
      EmitInstrAB('ADD', 'BX', 'AX');
      EmitInstrAB('MOV', 'AX', '[BX]');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
        ParserAdvance; { consomme ']' }
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_INT;
      Res.SymIdx  := -1;
    End
    Else
      Break;
  End;
End;

(* ---- ParseUnary : operateurs unaires prefixe + postfixe --- *)
(* Prefixe : + - ! ++ --                                        *)
(* Postfixe : !! (not-null assertion, stub)                     *)
(* ++ et -- postfixe geres. !! gere dans ParsePrimary postfixe. *)
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op : TString;
Begin
  (* Unaire prefixe sur TK_OP *)
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '+') Or (Op = '-') Or (Op = '!') Or
       (Op = '++') Or (Op = '--') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      (* Pliage de constantes *)
      If Res.Kind = EK_IMM Then
      Begin
        If Op = '-' Then
          Res.ImmVal := -Res.ImmVal
        Else If Op = '+' Then
          (* rien : coerce en nombre *)
        Else If Op = '!' Then
        Begin
          If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_BOOLEAN;
        End
        Else If Op = '++' Then
          Inc(Res.ImmVal)
        Else If Op = '--' Then
          Dec(Res.ImmVal)
        Else
          Res.Kind := EK_AX;
      End
      Else
      Begin
        (* Non constant : emettre code pour unaire *)
        ExprFlushToAX(Res);
        If Op = '-' Then
          EmitInstr('NEG    AX')
        Else If Op = '!' Then
          EmitInstrAB('XOR', 'AX', '1')
        Else If Op = '++' Then
          EmitInstr('INC    AX')
        Else If Op = '--' Then
          EmitInstr('DEC    AX');
        (* Op = '+' : rien a faire *)
        Res.Kind := EK_AX;
      End;
      Exit;
    End;
  End;
  (* Operateur unaire inv (bitwise NOT) comme identifiant *)
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'inv') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
      ExprMakeImm(Not Res.ImmVal, TY_IDX_INT, Res)
    Else
    Begin
      ExprFlushToAX(Res);
      EmitInstr('NOT    AX');
      Res.Kind := EK_AX;
    End;
    Exit;
  End;
  (* Pas d operateur unaire : appeler ParsePrimary *)
  ParsePrimary(Res);
  (* Postfixe !! (not-null assertion) *)
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '!!') Then
  Begin
    ParserAdvance;
    (* !! verifie non-null a l execution : stub, garde la valeur *)
    Res.Kind := EK_AX;
  End;
  (* Postfixe ++ -- *)
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '++') Or (CurToken.Val = '--')) Then
  Begin
    ParserAdvance;
    Res.Kind := EK_AX;
  End;
End;

(* ---- ParseExprPrec : boucle Pratt pour operateurs binaires - *)
(* Boucle de montee de precedence. Les operateurs sont detectes *)
(* soit comme TK_OP, soit comme TK_KEYWORD (in, !in, is, !is,  *)
(* as, as?). Pliage de constantes si les deux cotes sont IMM.   *)
(* Court-circuit && et || : JZ/JNZ -> labels _KTL_NNNN.         *)
(* Elvis ?: : compare gauche a 0, JNE -> garde gauche.          *)
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op      : TString;
  Prec    : Integer;
  Right   : TExprVal;
  FoldOk  : Boolean;
  LblSkip : TString;
  LblEnd  : TString;
Begin
  ParseUnary(Res);
  Repeat
    Op   := '';
    Prec := 0;
    (* Detecter operateur binaire sur TK_OP *)
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    (* Detecter operateurs binaires mots-cles : in !in is !is as as? *)
    Else If CurToken.Kind = TK_KEYWORD Then
    Begin
      If (CurToken.Val = 'in') Or (CurToken.Val = 'is') Or
         (CurToken.Val = 'as') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End;
    End
    (* Detecter operateurs infixes Kotlin : shl, shr, ushr, and, or, xor *)
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      If (CurToken.Val = 'shl') Or (CurToken.Val = 'shr') Or
         (CurToken.Val = 'ushr') Or (CurToken.Val = 'and') Or
         (CurToken.Val = 'or') Or (CurToken.Val = 'xor') Then
      Begin
        Op   := CurToken.Val;
        Prec := BinOpPrec(Op);
      End;
    End
    (* Detecter !in et !is : le lexeur produit '!' suivi de 'in'/'is' *)
    (* Mais certains lexeurs les combinent en un seul token TK_OP     *)
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '!in') Then
    Begin
      Op := '!in'; Prec := BinOpPrec(Op);
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '!is') Then
    Begin
      Op := '!is'; Prec := BinOpPrec(Op);
    End;
    (* Arreter si fin, priorite insuffisante, ou assignation *)
    If (Prec = 0) Or (Prec < MinPrec) Or IsAssignOp(Op) Then Break;
    ParserAdvance;

    (* ---- Court-circuit && ---- *)
    If Op = '&&' Then
    Begin
      If (Res.Kind = EK_IMM) Then
      Begin
        (* Pliage : si gauche == 0, resultat = 0, sinon evaluer droite *)
        If Res.ImmVal = 0 Then
        Begin
          ParseExprPrec(Prec + 1, Right);
          (* Res reste 0 *)
        End
        Else
          ParseExprPrec(Prec + 1, Res);
      End
      Else
      Begin
        ExprFlushToAX(Res);
        LblSkip := LabelGen;
        EmitInstrAB('TEST', 'AX', 'AX');
        EmitInstrA('JZ', LblSkip);
        ParseExprPrec(Prec + 1, Right);
        ExprFlushToAX(Right);
        EmitLabel(LblSkip);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End;
      Continue;
    End;

    (* ---- Court-circuit || ---- *)
    If Op = '||' Then
    Begin
      If (Res.Kind = EK_IMM) Then
      Begin
        If Res.ImmVal <> 0 Then
        Begin
          ParseExprPrec(Prec + 1, Right);
          (* Res reste truthy *)
        End
        Else
          ParseExprPrec(Prec + 1, Res);
      End
      Else
      Begin
        ExprFlushToAX(Res);
        LblSkip := LabelGen;
        EmitInstrAB('TEST', 'AX', 'AX');
        EmitInstrA('JNZ', LblSkip);
        ParseExprPrec(Prec + 1, Right);
        ExprFlushToAX(Right);
        EmitLabel(LblSkip);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_BOOLEAN;
      End;
      Continue;
    End;

    (* ---- Elvis ?: ---- *)
    If Op = '?:' Then
    Begin
      If (Res.Kind = EK_IMM) Then
      Begin
        If Res.ImmVal <> 0 Then
        Begin
          ParseExprPrec(Prec, Right); (* droite-assoc *)
          (* Res garde la valeur non-null *)
        End
        Else
          ParseExprPrec(Prec, Res);
      End
      Else
      Begin
        ExprFlushToAX(Res);
        LblSkip := LabelGen;
        EmitInstrAB('CMP', 'AX', '0');
        EmitInstrA('JNE', LblSkip);
        ParseExprPrec(Prec, Right); (* droite-assoc *)
        ExprFlushToAX(Right);
        EmitLabel(LblSkip);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_ANY;
      End;
      Continue;
    End;

    (* ---- Type cast as / as? ---- *)
    If (Op = 'as') Or (Op = 'as?') Then
    Begin
      (* Stub : le type cible est un identifiant, on le consomme *)
      If CurToken.Kind = TK_IDENT Then
        ParserAdvance;
      If Op = 'as?' Then
      Begin
        If Opts.Warnings Then
          WarnMsg('as? (safe cast) : stub, retourne la valeur inchangee');
      End;
      Res.Kind := EK_AX;
      Continue;
    End;

    (* ---- is / !is (test de type) ---- *)
    If (Op = 'is') Or (Op = '!is') Then
    Begin
      (* Stub : le type cible est un identifiant *)
      If CurToken.Kind = TK_IDENT Then
        ParserAdvance;
      If Opts.Warnings Then
        WarnMsg(Op + ' (test de type) : stub, retourne true');
      ExprMakeBool(Ord(Op = 'is'), Res);
      Continue;
    End;

    (* ---- in / !in (appartenance) ---- *)
    If (Op = 'in') Or (Op = '!in') Then
    Begin
      ParseExprPrec(Prec + 1, Right);
      If Opts.Warnings Then
        WarnMsg(Op + ' (appartenance) : stub, retourne false');
      ExprMakeBool(0, Res);
      Continue;
    End;

    (* ---- Range .. ---- *)
    If Op = '..' Then
    Begin
      ParseExprPrec(Prec + 1, Right);
      If Opts.Warnings Then
        WarnMsg('.. (range) : stub, retourne la borne gauche');
      (* Stub : Range sera une structure dans TODO 10+ *)
      Res.Kind := EK_AX;
      Continue;
    End;

    (* ---- Operateurs standards : sauvegarder gauche, recurser droit --- *)
    If Res.Kind <> EK_IMM Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;

    If BinOpIsRight(Op) Then
      ParseExprPrec(Prec, Right)
    Else
      ParseExprPrec(Prec + 1, Right);

    (* ---- Pliage de constantes ---- *)
    FoldOk := (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM);
    If FoldOk Then
    Begin
      If Op = '+' Then
        ExprMakeImm(Res.ImmVal + Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '-' Then
        ExprMakeImm(Res.ImmVal - Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '*' Then
        ExprMakeImm(Res.ImmVal * Right.ImmVal, TY_IDX_INT, Res)
      Else If (Op = '/') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_INT, Res)
      Else If (Op = '%') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Mod Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = '==' Then
        ExprMakeBool(Ord(Res.ImmVal = Right.ImmVal), Res)
      Else If Op = '!=' Then
        ExprMakeBool(Ord(Res.ImmVal <> Right.ImmVal), Res)
      Else If Op = '===' Then
        ExprMakeBool(
          Ord((Res.ImmVal = Right.ImmVal) And
              (Res.TypeIdx = Right.TypeIdx)), Res)
      Else If Op = '!==' Then
        ExprMakeBool(
          Ord(Not ((Res.ImmVal = Right.ImmVal) And
                   (Res.TypeIdx = Right.TypeIdx))), Res)
      Else If Op = '<' Then
        ExprMakeBool(Ord(Res.ImmVal < Right.ImmVal), Res)
      Else If Op = '<=' Then
        ExprMakeBool(Ord(Res.ImmVal <= Right.ImmVal), Res)
      Else If Op = '>' Then
        ExprMakeBool(Ord(Res.ImmVal > Right.ImmVal), Res)
      Else If Op = '>=' Then
        ExprMakeBool(Ord(Res.ImmVal >= Right.ImmVal), Res)
      Else If Op = 'shl' Then
        ExprMakeImm(Res.ImmVal Shl Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = 'shr' Then
      Begin
        (* Decalage arithmetique a droite : preserve le signe *)
        If Res.ImmVal < 0 Then
          ExprMakeImm(Not (Not Res.ImmVal Shr Right.ImmVal), TY_IDX_INT, Res)
        Else
          ExprMakeImm(Res.ImmVal Shr Right.ImmVal, TY_IDX_INT, Res);
      End
      Else If Op = 'ushr' Then
        ExprMakeImm(Res.ImmVal Shr Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = 'and' Then
        ExprMakeImm(Res.ImmVal And Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = 'or' Then
        ExprMakeImm(Res.ImmVal Or Right.ImmVal, TY_IDX_INT, Res)
      Else If Op = 'xor' Then
        ExprMakeImm(Res.ImmVal Xor Right.ImmVal, TY_IDX_INT, Res)
      Else
      Begin
        (* Op inconnu ou non pliable : resultat dans AX *)
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_INT;
      End;
    End
    Else
    Begin
      (* TODO 11 : emission binaire pour expressions non constantes *)
      (* Charger droite dans AX, deplacer vers BX, restaurer gauche *)
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      If Res.Kind = EK_IMM Then
        EmitInstrAB('MOV', 'AX', IntToStr(Res.ImmVal))
      Else
        EmitInstrA('POP', 'AX');
      (* AX = gauche, BX = droite *)
      (* --- String concatenation : + avec chaine --- *)
      If (Op = '+') And
         (Res.TypeIdx = TY_IDX_STRING) And
         (Right.TypeIdx = TY_IDX_STRING) Then
      Begin
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'DI', 'BX');
        EmitInstrA('CALL', '_KTRT_CONCAT');
      End
      (* --- String comparison : ==, !=, <, <=, >, >= avec chaines --- *)
      Else If ((Op = '==') Or (Op = '!=') Or (Op = '<') Or
               (Op = '<=') Or (Op = '>') Or (Op = '>=')) And
              (Res.TypeIdx = TY_IDX_STRING) And
              (Right.TypeIdx = TY_IDX_STRING) Then
      Begin
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'DI', 'BX');
        EmitInstrA('CALL', '_KTRT_STRCMP');
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', '0');
        If Op = '==' Then EmitInstrA('JE', LblSkip)
        Else If Op = '!=' Then EmitInstrA('JNE', LblSkip)
        Else If Op = '<' Then EmitInstrA('JL', LblSkip)
        Else If Op = '<=' Then EmitInstrA('JLE', LblSkip)
        Else If Op = '>' Then EmitInstrA('JG', LblSkip)
        Else EmitInstrA('JGE', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      (* --- Integer + --- *)
      Else If Op = '+' Then
        EmitInstrAB('ADD', 'AX', 'BX')
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')
      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')
      Else If Op = '/' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblEnd);
      End
      Else If Op = '%' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblEnd);
      End
      Else If (Op = '==') Or (Op = '===') Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JE', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If (Op = '!=') Or (Op = '!==') Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JNE', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JL', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JLE', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JG', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JGE', LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
      End
      Else If Op = 'shl' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHL', 'AX', 'CL');
      End
      Else If Op = 'shr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SAR', 'AX', 'CL');
      End
      Else If Op = 'ushr' Then
      Begin
        EmitInstrAB('MOV', 'CL', 'BL');
        EmitInstrAB('SHR', 'AX', 'CL');
      End
      Else If Op = 'and' Then
        EmitInstrAB('AND', 'AX', 'BX')
      Else If Op = 'or' Then
        EmitInstrAB('OR', 'AX', 'BX')
      Else If Op = 'xor' Then
        EmitInstrAB('XOR', 'AX', 'BX');
      Res.Kind := EK_AX;
      If (Op = '==') Or (Op = '!=') Or (Op = '===') Or (Op = '!==') Or
         (Op = '<') Or (Op = '<=') Or (Op = '>') Or (Op = '>=') Then
        Res.TypeIdx := TY_IDX_BOOLEAN
      Else If (Op = '+') And
              (Res.TypeIdx = TY_IDX_STRING) And
              (Right.TypeIdx = TY_IDX_STRING) Then
        Res.TypeIdx := TY_IDX_STRING
      Else
        Res.TypeIdx := TY_IDX_INT;
    End;
  Until False;
  (* ---- Assignation : = += -= *= /= %= ---- *)
  If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    ParseExprPrec(1, Right); (* droite-associatif *)
    Res.Kind := EK_AX;
    If Op = '=' Then
      Res.TypeIdx := Right.TypeIdx
    Else
      Res.TypeIdx := TY_IDX_INT;
    (* Verification de lvalue *)
    If Res.SymIdx < 0 Then
    Begin
      CompileError('cible d''affectation invalide');
      Exit;
    End;
    (* Emission du store pour la lvalue *)
    If SymTab[Res.SymIdx].IsConst Then
      CompileError('affectation a une constante val: "' +
                   SymTab[Res.SymIdx].Name + '"');
    If Op = '=' Then
    Begin
      ExprFlushToAX(Right);
      ExprStore(Res.SymIdx);
      SymTab[Res.SymIdx].TypeIdx := Right.TypeIdx;
    End
    Else
    Begin
      (* Operateur compose : AX=old, BX=new, op, stocker *)
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      ExprLoad(Res.SymIdx, Res);
      ExprFlushToAX(Res);
      If Op = '+=' Then
        EmitInstrAB('ADD', 'AX', 'BX')
      Else If Op = '-=' Then
        EmitInstrAB('SUB', 'AX', 'BX')
      Else If Op = '*=' Then
        EmitInstrA('IMUL', 'BX')
      Else If Op = '/=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblEnd);
      End
      Else If Op = '%=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'BX', '0');
        EmitInstrA('JE', LblSkip);
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('XOR', 'AX', 'AX');
        EmitLabel(LblEnd);
      End
      Else
        WarnMsg('operateur compose "' + Op + '" : stub');
      ExprStore(Res.SymIdx);
    End;
  End;
End;

(* ---- ParseExpr : point d entree principal des expressions -- *)
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

(* ---- SymNameClean : nettoyer un nom pour label ASM MASM ---- *)
(* Remplace les caracteres non alphanumeriques par '_'.          *)
(* $ est courant dans les identifiants Kotlin decompiles.        *)
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
  Ch : Char;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    Ch := Name[I];
    If ((Ch >= 'A') And (Ch <= 'Z')) Or
       ((Ch >= 'a') And (Ch <= 'z')) Or
       ((Ch >= '0') And (Ch <= '9')) Or
       (Ch = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + Ch;
    End
    Else
    Begin
      If Length(R) < MAX_STR Then
        R := R + '_';
    End;
  End;
  If R = '' Then R := '_anon';
  SymNameClean := R;
End;

(* ---- SymMangle : generer un label ASM depuis un symbole ---- *)
(* Prefixes : SK_FUN->_KTF_, SK_CLASS->_KTC_, SK_OBJECT->_KTO_, *)
(*   SK_ENUM->_KTE_, SK_INTERFACE->_KTI_, autres->_KTV_          *)
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUN      : SymMangle := KT_FN_PFX  + Clean;
    SK_CLASS    : SymMangle := KT_CLS_PFX + Clean;
    SK_OBJECT   : SymMangle := KT_OBJ_PFX + Clean;
    SK_ENUM     : SymMangle := KT_ENM_PFX + Clean;
    SK_INTERFACE: SymMangle := KT_ITF_PFX + Clean;
  Else
    SymMangle := KT_VAR_PFX + Clean;
  End;
End;

(* ---- SymFind : chercher un symbole par nom (MRU) ----------- *)
(* Recherche du plus recent au plus ancien pour respecter le      *)
(* shadowing lexical des portees imbriquees.                      *)
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

(* ---- SymFindInScope : chercher dans une portee specifique -- *)
(* Retourne l indice du symbole ou -1 si non trouve.             *)
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

(* ---- SymAdd : ajouter un symbole dans la table ------------- *)
(* Retourne l indice du symbole (0-base) ou -1 en cas d erreur.  *)
(* Affiche une trace de debug si l option -d est active.          *)
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    FatalError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := Name;
  SymTab[Idx].MangledName := SymMangle(Name, Kind);
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].TypeIdx     := TypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsConst     := False;
  SymTab[Idx].IsNullable  := False;
  SymTab[Idx].IsLateinit  := False;
  SymTab[Idx].Visibility  := 0;   { 0=public par defaut }
  SymTab[Idx].DeclLine    := CurToken.Line;
  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Name,
            ' kind=', Ord(Kind),
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);
  SymAdd := Idx;
  Inc(SymCount);
  Inc(TotalSyms);
End;

(* ---- SymEnterScope : entrer dans une nouvelle portee ------- *)
(* Sauvegarde SymCount dans ScopeStack pour pouvoir restaurer    *)
(* lors de SymLeaveScope (retrait des symboles locaux).           *)
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    FatalError('profondeur de portee max atteinte (max='
               + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

(* ---- SymLeaveScope : quitter la portee courante ------------ *)
(* Retire tous les symboles ajoutes dans cette portee.            *)
Procedure SymLeaveScope;
Begin
  If ScopeTop > 0 Then
  Begin
    Dec(ScopeTop);
    SymCount := ScopeStack[ScopeTop];
    Dec(CurScope);
    If Opts.DebugMode Then
      WriteLn('  SCOPE_LEAVE: level=', CurScope);
  End;
End;

(* ---- SymNextOffset : calculer le prochain offset [BP-n] ---- *)
Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize);
  SymNextOffset := CurFrameSize * 2;
End;

(* ---- SymInit : initialiser la table des symboles ----------- *)
(* Nettoie la table et predeclare les fonctions standard Kotlin   *)
(* qui seront implementees comme appels runtime _KTRT_.           *)
Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  { Nettoyer toute la table }
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_VAL;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsConst     := False;
    SymTab[I].IsNullable  := False;
    SymTab[I].IsLateinit  := False;
    SymTab[I].Visibility  := 0;
    SymTab[I].DeclLine    := 0;
  End;
  { Fonctions d entree/sortie standard }
  SymAdd('println',     SK_FUN, TY_IDX_UNIT,    0);
  SymAdd('print',       SK_FUN, TY_IDX_UNIT,    0);
  SymAdd('readLine',    SK_FUN, TY_IDX_STRING,  0);
  SymAdd('readln',      SK_FUN, TY_IDX_STRING,  0);
  { Fonctions de conversion }
  SymAdd('toString',    SK_FUN, TY_IDX_STRING,  0);
  SymAdd('toInt',       SK_FUN, TY_IDX_INT,     0);
  SymAdd('toDouble',    SK_FUN, TY_IDX_DOUBLE,  0);
  SymAdd('toFloat',     SK_FUN, TY_IDX_FLOAT,   0);
  SymAdd('toLong',      SK_FUN, TY_IDX_LONG,    0);
  SymAdd('toByte',      SK_FUN, TY_IDX_BYTE,    0);
  SymAdd('toShort',     SK_FUN, TY_IDX_SHORT,   0);
  SymAdd('toChar',      SK_FUN, TY_IDX_CHAR,    0);
  SymAdd('toBoolean',   SK_FUN, TY_IDX_BOOLEAN, 0);
  { Fonctions Any : hashCode, equals, compareTo }
  SymAdd('hashCode',    SK_FUN, TY_IDX_INT,     0);
  SymAdd('equals',      SK_FUN, TY_IDX_BOOLEAN, 0);
  SymAdd('compareTo',   SK_FUN, TY_IDX_INT,     0);
  { Constructeurs de collections }
  SymAdd('arrayOf',     SK_FUN, TY_IDX_ARRAY,   0);
  SymAdd('intArrayOf',  SK_FUN, TY_IDX_INTARRAY,0);
  SymAdd('listOf',      SK_FUN, TY_IDX_ARRAY,   0);
  SymAdd('mutableListOf', SK_FUN, TY_IDX_ARRAY, 0);
  SymAdd('mapOf',       SK_FUN, TY_IDX_ANY,     0);
  SymAdd('setOf',       SK_FUN, TY_IDX_ANY,     0);
  { Fonctions utilitaires }
  SymAdd('maxOf',       SK_FUN, TY_IDX_INT,     0);
  SymAdd('minOf',       SK_FUN, TY_IDX_INT,     0);
  SymAdd('repeat',      SK_FUN, TY_IDX_UNIT,    0);
  SymAdd('require',     SK_FUN, TY_IDX_UNIT,    0);
  SymAdd('check',       SK_FUN, TY_IDX_UNIT,    0);
  SymAdd('error',       SK_FUN, TY_IDX_NOTHING, 0);
  SymAdd('TODO',        SK_FUN, TY_IDX_NOTHING, 0);
  { Fonctions de portee (scope functions) }
  SymAdd('run',         SK_FUN, TY_IDX_ANY,     0);
  SymAdd('let',         SK_FUN, TY_IDX_ANY,     0);
  SymAdd('also',        SK_FUN, TY_IDX_ANY,     0);
  SymAdd('apply',       SK_FUN, TY_IDX_ANY,     0);
  SymAdd('with',        SK_FUN, TY_IDX_ANY,     0);
  SymAdd('takeIf',      SK_FUN, TY_IDX_ANY,     0);
  SymAdd('takeUnless',  SK_FUN, TY_IDX_ANY,     0);
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

(* ---- LabelGen : generer un label unique _KTL_NNNNN --------- *)
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := KT_LBL_PFX + S;
End;

(* ---- EmitRaw : ecrire une ligne brute dans le fichier ------- *)
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

(* ---- EmitBlankLine : ecrire une ligne vide ------------------- *)
Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

(* ---- EmitComment : ecrire un commentaire ASM ----------------- *)
Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

(* ---- EmitLabel : ecrire un label suivi de ':' --------------- *)
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

(* ---- EmitInstr : instruction sans operande (8 espaces) ------ *)
Procedure EmitInstr(Const Mnem : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem);
End;

(* ---- EmitInstrA : instruction + un operande ----------------- *)
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, ' ', A1);
End;

(* ---- EmitInstrAB : instruction + deux operandes ------------- *)
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, ' ', A1, ', ', A2);
End;

(* ---- EmitProlog : preambule de fonction (cadre BP) ---------- *)
(* TODO 18 : PUSH BP / MOV BP,SP / PUSH SI / PUSH DI             *)
Procedure EmitProlog;
Begin
  EmitInstr('PUSH BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstr('PUSH SI');
  EmitInstr('PUSH DI');
End;

(* ---- EmitEpilog : epilogue de fonction ---------------------- *)
(* TODO 18 : POP DI / POP SI / MOV SP,BP / POP BP / RET          *)
Procedure EmitEpilog;
Begin
  EmitInstr('POP DI');
  EmitInstr('POP SI');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP BP');
  EmitInstr('RET');
End;

(* ---- EmitOpen : ouvrir le fichier de sortie ASM ------------- *)
Procedure EmitOpen;
Begin
  {$I-}
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('impossible de creer: ' + Opts.OutFile);
  OutFOpen := True;
End;

(* ---- EmitHeader : en-tete ASM (.MODEL SMALL, _TEXT) --------- *)
Procedure EmitHeader;
Begin
  EmitComment('=========================================================');
  EmitComment('Genere par KOTLIN86 v' + KT86_VERSION + ' (' + KT86_DATE + ')');
  EmitComment('Source  : ' + Opts.SrcFile);
  EmitComment('Cible   : MASM 8086, modele SMALL');
  EmitComment('=========================================================');
  EmitBlankLine;
  EmitRaw('        .8086');
  EmitRaw('        DOSSEG');
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  EmitComment('-- Point d''entree : fun main() --');
  EmitLabel(KT_FN_PFX + 'main');
  EmitProlog;
  EmitComment('-- Initialiser DS sur le segment de donnees --');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

(* ---- EmitDataSeg : emettre le segment de donnees ----------- *)
Procedure EmitDataSeg;
Var
  I, J  : Integer;
  S     : TString;
  C     : Char;
  InStr : Boolean;
Begin
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  EmitBlankLine;
  { Emettre toutes les donnees depuis DataTab (predefinies + utilisateur) }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW ' + IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        Begin
          If DataTab[I].ElemCount > 0 Then
            EmitRaw(DataTab[I].LblName + '  DB ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)')
          Else
            EmitRaw(DataTab[I].LblName + '  DB ' + IntToStr(DataTab[I].IntVal));
        End;
      DK_STR :
        Begin
          S := DataTab[I].StrVal;
          If Length(S) = 0 Then
            EmitRaw(DataTab[I].LblName + '  DB 0')
          Else If OutFOpen Then
          Begin
            { Gerer les caracteres de controle et apostrophes }
            InStr := False;
            Write(OutF, DataTab[I].LblName, '  DB ');
            For J := 1 To Length(S) Do
            Begin
              C := S[J];
              If (Ord(C) < 32) Or (Ord(C) > 126) Or (C = '''') Then
              Begin
                If InStr Then
                Begin
                  Write(OutF, '''');
                  InStr := False;
                End;
                If J > 1 Then Write(OutF, ', ');
                Write(OutF, IntToStr(Ord(C)));
              End
              Else
              Begin
                If Not InStr Then
                Begin
                  If J > 1 Then Write(OutF, ', ');
                  Write(OutF, '''');
                  InStr := True;
                End;
                Write(OutF, C);
              End;
            End;
            If InStr Then Write(OutF, '''');
            WriteLn(OutF, ', 0');
          End;
        End;
      DK_ARRAY_BLK :
        Begin
          EmitRaw(DataTab[I].LblName + '  DW ' +
                  IntToStr(DataTab[I].ElemCount));
          EmitRaw(DataTab[I].LblName + '_D  DW ' +
                  IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
        End;
      DK_OBJ_BLK :
        Begin
          If DataTab[I].ElemCount > 0 Then
            EmitRaw(DataTab[I].LblName + '  DB ' +
                    IntToStr(DataTab[I].ElemCount) + ' DUP(0)   ; object block')
          Else
            EmitRaw(DataTab[I].LblName + '  DW 0   ; object slot');
        End;
    Else
      EmitRaw(DataTab[I].LblName + '  DW 0');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

(* ---- EmitRuntime : emettre les routines runtime ------------- *)
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('=========================================================');
  EmitComment('RUNTIME MINIMAL KOTLIN86');
  EmitComment('=========================================================');
  EmitExprRuntime;
  EmitIORuntime;
  EmitArrayRuntime;
  EmitClassRuntime;
  EmitScopeRuntime;
End;

(* ---- EmitExprRuntime : routines runtime pour expressions ------ *)
(* _KTRT_CONCAT : concatenation de deux chaines ASCIIZ.            *)
(*   Entree : SI = chaine source 1 (ASCIIZ)                        *)
(*            DI = chaine source 2 (ASCIIZ)                        *)
(*   Sortie : AX = pointeur vers _KT_STRBUF (resultat)             *)
(* _KTRT_STRCMP : comparaison lexicographique de deux chaines.      *)
(*   Entree : SI = chaine 1, DI = chaine 2                         *)
(*   Sortie : AX = -1 (si SI<DI), 0 (si SI=DI), 1 (si SI>DI)     *)
Procedure EmitExprRuntime;
Begin
  EmitBlankLine;
  EmitComment('--- _KTRT_CONCAT : concatenation de chaines ---');
  EmitComment('SI = str1 (ASCIIZ), DI = str2 (ASCIIZ) -> AX = ptr buf');
  EmitLabel('_KTRT_CONCAT');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'BX', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _KT_STRBUF');
  EmitComment('Copier str1 dans le buffer');
  EmitLabel('_KTRT_CC1');
  EmitInstr('LODSB');
  EmitInstrAB('TEST', 'AL', 'AL');
  EmitInstrA('JZ', '_KTRT_CC2');
  EmitInstr('STOSB');
  EmitInstrA('JMP', '_KTRT_CC1');
  EmitLabel('_KTRT_CC2');
  EmitComment('Copier str2 dans le buffer');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitLabel('_KTRT_CC3');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstrAB('TEST', 'AL', 'AL');
  EmitInstrA('JNZ', '_KTRT_CC3');
  EmitInstrAB('MOV', 'AX', 'OFFSET _KT_STRBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  EmitBlankLine;
  EmitComment('--- _KTRT_STRCMP : comparaison de chaines ---');
  EmitComment('SI = str1, DI = str2 -> AX = -1/0/+1');
  EmitLabel('_KTRT_STRCMP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitLabel('_KTRT_SC1');
  EmitInstr('LODSB');
  EmitInstrAB('MOV', 'AH', '[DI]');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', '_KTRT_SC2');
  EmitInstrAB('TEST', 'AL', 'AL');
  EmitInstrA('JNZ', '_KTRT_SC1');
  EmitComment('Les chaines sont egales');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel('_KTRT_SC2');
  EmitInstrA('JA', '_KTRT_SC3');
  EmitComment('str1 < str2');
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
  EmitLabel('_KTRT_SC3');
  EmitComment('str1 > str2');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 15 - TABLEAUX [IMPLEMENTE]
  ============================================================ }

(* ---- EmitArrayRuntime : routines runtime pour tableaux ------ *)
(* _KTRT_ARRIDXOF : recherche d un element dans un tableau       *)
(*   Entree : BX = base tableau (count word), AX = valeur         *)
(*   Sortie : AX = index (0-based) ou -1 si non trouve            *)
(* _KTRT_ARRSUM : somme des elements d un tableau                 *)
(*   Entree : BX = base tableau                                   *)
(*   Sortie : AX = somme                                          *)
(* _KTRT_ARRSORT : tri en place (bubble sort) d un tableau        *)
(*   Entree : BX = base tableau                                   *)
(*   Sortie : AX = BX (meme tableau, trie en place)               *)
Procedure EmitArrayRuntime;
Begin
  EmitBlankLine;
  EmitComment('=========================================================');
  EmitComment('TODO 15 - RUNTIME TABLEAUX KOTLIN86');
  EmitComment('=========================================================');

  { --- _KTRT_ARRIDXOF : indexOf --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_ARRIDXOF : BX=arr, AX=val -> AX=index/-1 ---');
  EmitLabel('_KTRT_ARRIDXOF');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrAB('XOR', 'SI', 'SI');
  EmitLabel('_KTRT_AIF1');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', '_KTRT_AIF2');
  EmitInstrAB('CMP', 'AX', '[BX]');
  EmitInstrA('JE', '_KTRT_AIF3');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_KTRT_AIF1');
  EmitLabel('_KTRT_AIF2');
  EmitComment('non trouve');
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
  EmitLabel('_KTRT_AIF3');
  EmitComment('trouve a index SI');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { --- _KTRT_ARRSUM : somme --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_ARRSUM : BX=arr -> AX=somme ---');
  EmitLabel('_KTRT_ARRSUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_KTRT_ASM1');
  EmitInstrAB('TEST', 'CX', 'CX');
  EmitInstrA('JZ', '_KTRT_ASM2');
  EmitInstrAB('ADD', 'AX', '[BX]');
  EmitInstrAB('ADD', 'BX', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_KTRT_ASM1');
  EmitLabel('_KTRT_ASM2');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { --- _KTRT_ARRSORT : tri en place (bubble sort) --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_ARRSORT : BX=arr -> AX=BX (trie) ---');
  EmitLabel('_KTRT_ARRSORT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrAB('CMP', 'CX', '2');
  EmitInstrA('JB', '_KTRT_ASR4');
  EmitInstrA('DEC', 'CX');
  EmitLabel('_KTRT_ASR1');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('MOV', 'DI', 'CX');
  EmitLabel('_KTRT_ASR2');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrAB('MOV', 'DX', '[SI+2]');
  EmitInstrAB('CMP', 'AX', 'DX');
  EmitInstrA('JLE', '_KTRT_ASR3');
  EmitInstrAB('MOV', '[SI]', 'DX');
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitLabel('_KTRT_ASR3');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrA('DEC', 'DI');
  EmitInstrA('JNZ', '_KTRT_ASR2');
  EmitInstrA('POP', 'CX');
  EmitInstr('LOOP _KTRT_ASR1');
  EmitLabel('_KTRT_ASR4');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 16 - CLASSES ET DATA CLASSES [IMPLEMENTE]
  ============================================================ }

(* ---- Fonctions utilitaires pour les classes ----------------- *)

Function ClassFind(Const Name : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To ClassCount - 1 Do
    If ClassTab[I].Name = Name Then
    Begin
      ClassFind := I;
      Exit;
    End;
  ClassFind := -1;
End;

Function ClassFieldFind(ClsIdx : Integer; Const FName : TString) : Integer;
Var I : Integer;
Begin
  For I := 0 To ClassTab[ClsIdx].FieldCount - 1 Do
    If ClassTab[ClsIdx].Fields[I].Name = FName Then
    Begin
      ClassFieldFind := I;
      Exit;
    End;
  ClassFieldFind := -1;
End;

Function ClassFindByTypeIdx(TIdx : Integer) : Integer;
Var I : Integer;
Begin
  For I := 0 To ClassCount - 1 Do
    If ClassTab[I].TypeIdx = TIdx Then
    Begin
      ClassFindByTypeIdx := I;
      Exit;
    End;
  ClassFindByTypeIdx := -1;
End;

(* ---- EmitClassRuntime : routines runtime pour les classes ---- *)
(* _KTRT_OBJNEW : initialiser un bloc objet a zero.              *)
(*   Entree : BX = pointeur objet, CX = taille en octets         *)
Procedure EmitClassRuntime;
Begin
  EmitBlankLine;
  EmitComment('---------------------------------------------------------');
  EmitComment('Runtime : classes et objets');
  EmitComment('---------------------------------------------------------');
  EmitBlankLine;
  EmitLabel('_KTRT_OBJNEW');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('REP STOSB');
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');
  EmitBlankLine;
End;

(* ---- ParseClassDecl : [data] class Nom(val/var p: T, ...) --- *)
(* Genere :                                                       *)
(*   - Entree dans ClassTab                                       *)
(*   - Type dans TypeTab (TYK_CLASS)                               *)
(*   - Symbole dans SymTab (SK_CLASS)                              *)
(*   - Pour data class : procedure _KTF_Nom_toString               *)
Procedure ParseClassDecl;
Var
  IsData     : Boolean;
  ClsName    : TString;
  ClsLabel   : TString;
  ClsIdx     : Integer;
  TIdx       : Integer;
  FldName    : TString;
  FldIsVal   : Boolean;
  FldTIdx    : Integer;
  FldCount   : Integer;
  ObjSz      : Integer;
  I          : Integer;
  LblSkip    : TString;
  LblLoop    : TString;
  LblDone    : TString;
  SIdx       : Integer;
  FieldOfs   : TString;
  SaveClass  : TString;
Begin
  IsData := False;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'data') Then
  Begin
    IsData := True;
    ParserAdvance; { consomme 'data' }
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'class') Then
    ParserAdvance { consomme 'class' }
  Else
  Begin
    CompileError('mot-cle "class" attendu');
    Exit;
  End;
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de classe attendu');
    Exit;
  End;
  ClsName := CurToken.Val;
  ClsLabel := KT_CLS_PFX + ClsName;
  ParserAdvance; { consomme le nom }
  FldCount := 0;
  ObjSz := 2;  { premier word = vtable (reserve pour dispatch virtuel futur, mis a 0) }
  { Parser les parametres du constructeur primaire }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance; { consomme '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      FldIsVal := True;
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'val') Then
      Begin
        FldIsVal := True;
        ParserAdvance;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'var') Then
      Begin
        FldIsVal := False;
        ParserAdvance;
      End;
      If CurToken.Kind <> TK_IDENT Then
      Begin
        CompileError('nom de parametre attendu');
        Exit;
      End;
      FldName := CurToken.Val;
      ParserAdvance; { consomme le nom }
      FldTIdx := TY_IDX_INT;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        ParserAdvance; { consomme ':' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          FldTIdx := TypeLookupName(CurToken.Val);
          If FldTIdx < 0 Then FldTIdx := TY_IDX_INT;
          ParserAdvance;
        End;
      End;
      If FldCount < MAX_CLASS_FIELDS Then
      Begin
        ClassTab[ClassCount].Fields[FldCount].Name    := FldName;
        ClassTab[ClassCount].Fields[FldCount].TypeIdx := FldTIdx;
        ClassTab[ClassCount].Fields[FldCount].IsVal   := FldIsVal;
        ClassTab[ClassCount].Fields[FldCount].Offset  := ObjSz;
        Inc(FldCount);
        Inc(ObjSz, 2);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance; { consomme ',' }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance; { consomme ')' }
  End;
  { Enregistrer le type dans TypeTab }
  If TypeCount < MAX_TYPE Then
  Begin
    TypeTab[TypeCount].Name := ClsName;
    TypeTab[TypeCount].Kind := TYK_CLASS;
    TypeTab[TypeCount].Size := ObjSz;
    TIdx := TypeCount;
    Inc(TypeCount);
  End
  Else
    TIdx := TY_IDX_ANY;
  { Enregistrer la classe dans ClassTab }
  ClsIdx := ClassCount;
  ClassTab[ClsIdx].Name       := ClsName;
  ClassTab[ClsIdx].AsmLabel   := ClsLabel;
  ClassTab[ClsIdx].IsData     := IsData;
  ClassTab[ClsIdx].FieldCount := FldCount;
  ClassTab[ClsIdx].ObjSize    := ObjSz;
  ClassTab[ClsIdx].TypeIdx    := TIdx;
  { Enregistrer le symbole }
  SIdx := SymAdd(ClsName, SK_CLASS, TIdx, 0);
  ClassTab[ClsIdx].SymIdx := SIdx;
  Inc(ClassCount);
  { Ignorer heritage : SuperType(args), Interface }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance; { consomme ':' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_LBRACE)) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) And
          (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_KEYWORD) And
               ((CurToken.Val = 'val') Or (CurToken.Val = 'var') Or
                (CurToken.Val = 'class') Or (CurToken.Val = 'fun'))) Do
      ParserAdvance;
  End;
  { Pour data class : emettre _KTF_ClsName_toString }
  If IsData And (FldCount > 0) Then
  Begin
    LblSkip := LabelGen;
    EmitInstrA('JMP', LblSkip);
    EmitBlankLine;
    EmitComment('data class ' + ClsName + ' toString()');
    EmitLabel(KT_FN_PFX + ClsName + '_toString');
    { BX = pointeur objet, emet la chaine dans STDOUT }
    EmitInstrA('PUSH', 'BX');
    EmitInstrA('PUSH', 'SI');
    { Imprimer "ClsName(" }
    DataAdd(KT_STR_PFX + ClsName + '_O', DK_STR, 0, ClsName + '(');
    EmitInstrAB('LEA', 'SI', KT_STR_PFX + ClsName + '_O');
    EmitInstr('CALL _KTRT_PRINTSTR');
    For I := 0 To FldCount - 1 Do
    Begin
      If I > 0 Then
      Begin
        DataAdd(KT_STR_PFX + ClsName + '_C' + IntToStr(I), DK_STR, 0, ', ');
        EmitInstrAB('LEA', 'SI', KT_STR_PFX + ClsName + '_C' + IntToStr(I));
        EmitInstr('CALL _KTRT_PRINTSTR');
      End;
      { Imprimer "fieldName=" }
      DataAdd(KT_STR_PFX + ClsName + '_F' + IntToStr(I), DK_STR, 0,
              ClassTab[ClsIdx].Fields[I].Name + '=');
      EmitInstrAB('LEA', 'SI', KT_STR_PFX + ClsName + '_F' + IntToStr(I));
      EmitInstr('CALL _KTRT_PRINTSTR');
      { Charger et imprimer la valeur du champ }
      EmitInstrA('POP', 'BX');
      EmitInstrA('PUSH', 'BX');
      FieldOfs := IntToStr(ClassTab[ClsIdx].Fields[I].Offset);
      If ClassTab[ClsIdx].Fields[I].TypeIdx = TY_IDX_STRING Then
      Begin
        EmitInstrAB('MOV', 'SI', '[BX+' + FieldOfs + ']');
        EmitInstr('CALL _KTRT_PRINTSTR');
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX', '[BX+' + FieldOfs + ']');
        EmitInstr('CALL _KTRT_PRINT');
      End;
    End;
    { Imprimer ")" }
    DataAdd(KT_STR_PFX + ClsName + '_P', DK_STR, 0, ')');
    EmitInstrAB('LEA', 'SI', KT_STR_PFX + ClsName + '_P');
    EmitInstr('CALL _KTRT_PRINTSTR');
    EmitInstrA('POP', 'SI');
    EmitInstrA('POP', 'BX');
    EmitInstr('RET');
    EmitLabel(LblSkip);
    EmitBlankLine;
  End;
  (* Parser le corps de la classe si present *)
  SaveClass := CurClassName;
  CurClassName := ClsName;
  If (CurToken.Kind = TK_PUNCT) And
     ((CurToken.Val = CH_LBRACE) Or (CurToken.Val = '{')) Then
  Begin
    ParserAdvance; (* consomme accolade ouvrante *)
    (* Parser le contenu du corps : val/var dans la classe sont ignores *)
    While Not ((CurToken.Kind = TK_PUNCT) And
               ((CurToken.Val = CH_RBRACE) Or (CurToken.Val = '}'))) And
          (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And
       ((CurToken.Val = CH_RBRACE) Or (CurToken.Val = '}')) Then
      ParserAdvance; (* consomme accolade fermante *)
  End;
  CurClassName := SaveClass;
End;

{ ============================================================
  TODO 17 - FONCTIONS ET LAMBDAS [IMPLEMENTE]
  ============================================================ }

(* ---- ParseFunDecl : fun nom(params): RetType { bloc } ------ *)
(* ou fun nom(params): RetType = expr (expression body)          *)
(* ou fun Type.nom(params): RetType { bloc } (extension)         *)
(* Genere :                                                       *)
(*   JMP _KTL_SKIP_N          (sauter par-dessus le corps)       *)
(*   _KTF_nom PROC NEAR                                          *)
(*     PUSH BP / MOV BP,SP / SUB SP, locals_size                  *)
(*     ... corps ...                                              *)
(*   _KTL_RET_N:                                                  *)
(*     MOV SP,BP / POP BP / RET                                   *)
(*   _KTL_SKIP_N:                                                 *)
Procedure ParseFunDecl;
Var
  FnName    : TString;
  FnLabel   : TString;
  SkipLbl   : TString;
  RetLbl    : TString;
  RetTIdx   : Integer;
  SIdx      : Integer;
  ParamName : TString;
  ParamTIdx : Integer;
  ParamIdx  : Integer;
  ParamCnt  : Integer;
  ParamOfs  : Integer;
  IsExprBody : Boolean;
  Res       : TExprVal;
  I         : Integer;
  ExtType   : TString;
  IsExt     : Boolean;
Begin
  ParserAdvance; { consomme 'fun' }
  Inc(FunDeclCount);
  IsExt := False;
  ExtType := '';

  { Lire le nom de la fonction }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de fonction attendu apres "fun"');
    Exit;
  End;
  FnName := CurToken.Val;
  ParserAdvance; { consomme le nom }

  { Verifier fonction d extension : Type.nom }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
  Begin
    IsExt := True;
    ExtType := FnName;
    ParserAdvance; { consomme '.' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      FnName := ExtType + '_' + CurToken.Val;
      ParserAdvance; { consomme le nom reel }
    End
    Else
    Begin
      CompileError('nom de methode attendu apres "' + ExtType + '."');
      Exit;
    End;
  End;

  FnLabel := KT_FN_PFX + SymNameClean(FnName);
  SkipLbl := LabelGen;
  RetLbl  := LabelGen;

  { Registrer le symbole SK_FUN avant le corps (pour recursion) }
  SIdx := SymFind(FnName);
  If SIdx < 0 Then
    SIdx := SymAdd(FnName, SK_FUN, TY_IDX_INT, 0);
  SymTab[SIdx].MangledName := FnLabel;

  { Sauvegarder le contexte englobant }
  SaveFrameSize := CurFrameSize;
  SaveFnRetLbl  := CurFnRetLbl;
  SaveFnName    := CurFnName;
  CurFnRetLbl   := RetLbl;
  CurFnName     := FnName;
  CurFrameSize  := 0;
  Inc(CurFnDepth);

  { JMP skip : sauter par-dessus le corps de la fonction }
  EmitInstrA('JMP', SkipLbl);
  EmitBlankLine;
  EmitComment('--- fun ' + FnName + ' ---');
  EmitLabel(FnLabel);
  EmitProlog;

  SymEnterScope;

  { Parser les parametres }
  ParamCnt := 0;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance; { consomme '(' }
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      If ParamCnt >= MAX_FUN_PARAMS Then
      Begin
        WarnMsg('trop de parametres (max=' + IntToStr(MAX_FUN_PARAMS) + ')');
        Break;
      End;
      { Lire nom du parametre }
      If CurToken.Kind = TK_IDENT Then
      Begin
        ParamName := CurToken.Val;
        ParserAdvance; { consomme le nom }
      End
      Else
      Begin
        ParamName := 'p' + IntToStr(ParamCnt);
        ParserAdvance;
      End;
      { Parser le type annotation optionnel }
      ParamTIdx := TY_IDX_INT;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
      Begin
        ParserAdvance; { consomme ':' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          ParamTIdx := TypeLookupName(CurToken.Val);
          If ParamTIdx < 0 Then
            ParamTIdx := TY_IDX_INT;
          ParserAdvance;
          { Nullable ? }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
            ParserAdvance;
        End
        Else If CurToken.Kind = TK_KEYWORD Then
        Begin
          ParamTIdx := TypeLookupName(CurToken.Val);
          If ParamTIdx < 0 Then
            ParamTIdx := TY_IDX_INT;
          ParserAdvance;
        End;
      End;
      { Valeur par defaut optionnelle : skip }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance; { consomme '=' }
        { Sauter la valeur par defaut }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   ((CurToken.Val = ',') Or (CurToken.Val = ')'))) Do
          ParserAdvance;
      End;
      { Enregistrer le parametre : [BP+4+ParamCnt*2] }
      { BP+0=ancien BP, BP+2=adresse retour, BP+4=dernier arg empile }
      ParamOfs := 4 + ParamCnt * 2;
      ParamIdx := SymAdd(ParamName, SK_PARAM, ParamTIdx, ParamOfs);

      Inc(ParamCnt);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance; { consomme ',' }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance; { consomme ')' }
  End;

  { Parser le type de retour optionnel }
  RetTIdx := TY_IDX_UNIT;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance; { consomme ':' }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      RetTIdx := TypeLookupName(CurToken.Val);
      If RetTIdx < 0 Then
        RetTIdx := TY_IDX_INT;
      ParserAdvance;
      { Nullable ? }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
        ParserAdvance;
    End;
  End;
  SymTab[SIdx].TypeIdx := RetTIdx;

  { TODO 18 : espace pile pour les locaux alloue dynamiquement }
  { On reserve initialement 0 ; chaque DeclAllocSym emet SUB SP,2 }

  (* Verifier si c est une expression body (=) ou un bloc *)
  IsExprBody := False;
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    IsExprBody := True;
    ParserAdvance; { consomme '=' }
  End;

  { Parser le corps de la fonction }
  If IsExprBody Then
  Begin
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitInstrA('JMP', RetLbl);
  End
  Else
  Begin
    (* Bloc de code *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_LBRACE) Then
    Begin
      ParserAdvance; { consomme accolade ouvrante }
      While (CurToken.Kind <> TK_EOF) And
            Not ((CurToken.Kind = TK_PUNCT) And
                 (CurToken.Val = CH_RBRACE)) Do
        ParseStmt;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_RBRACE) Then
        ParserAdvance; { consomme accolade fermante }
    End;
  End;

  { Epilogue de fonction }
  EmitLabel(RetLbl);
  EmitEpilog;
  EmitBlankLine;

  SymLeaveScope;

  { Restaurer le contexte englobant }
  Dec(CurFnDepth);
  CurFrameSize := SaveFrameSize;
  CurFnRetLbl  := SaveFnRetLbl;
  CurFnName    := SaveFnName;

  { Label skip pour sauter le corps }
  EmitLabel(SkipLbl);
End;

(* ---- ParseReturnStmt : return [expr] ----------------------- *)
(* Genere : MOV AX, val / JMP _KTL_RET_N                        *)
Procedure ParseReturnStmt;
Var
  Res : TExprVal;
Begin
  ParserAdvance; { consomme 'return' }
  If CurFnDepth = 0 Then
  Begin
    { return au niveau global : exit du programme }
    EmitInstrAB('MOV', 'AX', '4C00h');
    EmitInstr('INT 21h');
    Exit;
  End;
  { Si le token suivant est sur la meme ligne et n est pas }
  { une fermeture de bloc, on parse l expression }
  If (CurToken.Kind <> TK_EOF) And
     (CurToken.Kind <> TK_PUNCT) Or
     ((CurToken.Kind = TK_PUNCT) And
      (CurToken.Val <> CH_RBRACE) And (CurToken.Val <> '}')) Then
  Begin
    { Essayer de parser une expression de retour }
    If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_LONG) Or
       (CurToken.Kind = TK_FLOAT) Or (CurToken.Kind = TK_STRING) Or
       (CurToken.Kind = TK_CHAR) Or (CurToken.Kind = TK_IDENT) Or
       ((CurToken.Kind = TK_KEYWORD) And
        ((CurToken.Val = 'true') Or (CurToken.Val = 'false') Or
         (CurToken.Val = 'null') Or (CurToken.Val = 'this'))) Or
       ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Or
       ((CurToken.Kind = TK_OP) And
        ((CurToken.Val = '-') Or (CurToken.Val = '!') Or (CurToken.Val = '+'))) Then
    Begin
      ParseExpr(Res);
      ExprFlushToAX(Res);
    End;
  End;
  EmitInstrA('JMP', CurFnRetLbl);
End;

{ ============================================================
  TODO 18 - PORTEE, PILE ET CADRES [IMPLEMENTE]
  ============================================================ }

(* ---- ScopeBlockEnter : entrer dans une portee de bloc { } --- *)
(* Sauvegarde CurFrameSize dans ScopeFrameStack et appelle        *)
(* SymEnterScope. Les variables declarees dans le bloc seront     *)
(* allouees sur la pile avec SUB SP,2 dans DeclAllocSym.          *)
Procedure ScopeBlockEnter;
Begin
  If ScopeTop < MAX_SCOPE Then
    ScopeFrameStack[ScopeTop] := CurFrameSize;
  SymEnterScope;
End;

(* ---- ScopeBlockLeave : quitter une portee de bloc { } ------- *)
(* Restaure les symboles et libere l espace pile alloue via        *)
(* ADD SP,n pour les variables locales du bloc.                    *)
Procedure ScopeBlockLeave;
Var
  SavedFrame : Integer;
  DeltaWords : Integer;
Begin
  If ScopeTop > 0 Then
    SavedFrame := ScopeFrameStack[ScopeTop - 1]
  Else
    SavedFrame := CurFrameSize;
  DeltaWords := CurFrameSize - SavedFrame;
  SymLeaveScope;
  If DeltaWords > 0 Then
  Begin
    EmitInstrAB('ADD', 'SP', IntToStr(DeltaWords * 2));
    CurFrameSize := SavedFrame;
  End;
End;

(* ---- EmitScopeRuntime : routines runtime pour les portees ---- *)
(* Actuellement pas de routines runtime specifiques necessaires :  *)
(* la gestion des portees est entierement compile-time.            *)
(* Les cellules de capture pour closures sont allouees dans DATA.  *)
Procedure EmitScopeRuntime;
Begin
  EmitComment('; --- scope runtime (TODO 18) ---');
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES [IMPLEMENTE]
  ============================================================ }

(* ---- EmitIORuntime : routines runtime pour entrees/sorties -- *)
(* _KTRT_STRLEN   : longueur d une chaine ASCIIZ                *)
(*   Entree : SI = ptr chaine ASCIIZ                             *)
(*   Sortie : CX = longueur (sans le zero final)                 *)
(* _KTRT_NUMTOSTR : conversion entier signe 16 bits -> chaine   *)
(*   Entree : AX = valeur entiere                                *)
(*   Sortie : SI = ptr chaine ASCIIZ, CX = longueur              *)
(* _KTRT_STRTONUM : conversion chaine ASCIIZ -> entier 16 bits  *)
(*   Entree : SI = ptr chaine ASCIIZ                             *)
(*   Sortie : AX = valeur entiere                                *)
(* _KTRT_PRINTSTR : afficher une chaine ASCIIZ sur STDOUT       *)
(*   Entree : SI = ptr chaine ASCIIZ                             *)
(* _KTRT_PRINT    : afficher un entier sur STDOUT                *)
(*   Entree : AX = valeur entiere                                *)
(* _KTRT_NEWLINE  : afficher CR+LF sur STDOUT                   *)
(* _KTRT_READLINE : lire une ligne depuis STDIN                  *)
(*   Sortie : AX = ptr chaine ASCIIZ (dans _KT_INPUTBF)         *)
Procedure EmitIORuntime;
Begin
  EmitBlankLine;
  EmitComment('=========================================================');
  EmitComment('TODO 12 - RUNTIME E/S KOTLIN86');
  EmitComment('=========================================================');

  { --- _KTRT_STRLEN : longueur chaine ASCIIZ --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_STRLEN : SI = str ASCIIZ -> CX = longueur ---');
  EmitLabel('_KTRT_STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel('_KTRT_SL1');
  EmitInstr('LODSB');
  EmitInstrAB('TEST', 'AL', 'AL');
  EmitInstrA('JZ', '_KTRT_SL2');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', '_KTRT_SL1');
  EmitLabel('_KTRT_SL2');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { --- _KTRT_NUMTOSTR : AX = entier -> SI = ptr, CX = len --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_NUMTOSTR : AX = entier signe -> SI = ptr, CX = len ---');
  EmitLabel('_KTRT_NUMTOSTR');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'DX');
  EmitComment('Ecrire les chiffres depuis la fin du buffer');
  EmitInstrAB('MOV', 'DI', 'OFFSET _KT_NUMBUF');
  EmitInstrAB('ADD', 'DI', '11');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');   { terminateur nul }
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitComment('Sauver le signe');
  EmitInstrAB('MOV', 'SI', 'AX');         { sauver signe dans SI }
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNS', '_KTRT_NS0');
  EmitInstr('NEG AX');
  EmitLabel('_KTRT_NS0');
  EmitComment('Boucle extraction chiffres (AX = valeur positive)');
  EmitLabel('_KTRT_NS1');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstr('DIV BX');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('DEC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNZ', '_KTRT_NS1');
  EmitComment('Ajouter le signe - si necessaire');
  EmitInstrAB('TEST', 'SI', 'SI');
  EmitInstrA('JNS', '_KTRT_NS2');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '45');    { 45 = '-' en ASCII }
  EmitInstrA('DEC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitLabel('_KTRT_NS2');
  EmitComment('SI = debut de la chaine (DI+1)');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DI');
  EmitInstr('RET');

  { --- _KTRT_STRTONUM : SI = str ASCIIZ -> AX = entier --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_STRTONUM : SI = str ASCIIZ -> AX = entier ---');
  EmitLabel('_KTRT_STRTONUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitComment('Verifier signe negatif');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '45');    { 45 = '-' en ASCII }
  EmitInstrA('JNE', '_KTRT_SN1');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CL');
  EmitLabel('_KTRT_SN1');
  EmitInstrAB('MOV', 'DL', '[SI]');
  EmitInstrA('INC', 'SI');
  EmitInstrAB('TEST', 'DL', 'DL');
  EmitInstrA('JZ', '_KTRT_SN2');
  EmitInstrAB('SUB', 'DL', '''0''');
  EmitInstrAB('CMP', 'DL', '9');
  EmitInstrA('JA', '_KTRT_SN2');
  EmitInstr('MUL BX');
  EmitInstrAB('XOR', 'DH', 'DH');
  EmitInstrAB('ADD', 'AX', 'DX');
  EmitInstrA('JMP', '_KTRT_SN1');
  EmitLabel('_KTRT_SN2');
  EmitComment('Appliquer le signe si negatif');
  EmitInstrAB('TEST', 'CL', 'CL');
  EmitInstrA('JZ', '_KTRT_SN3');
  EmitInstr('NEG AX');
  EmitLabel('_KTRT_SN3');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstr('RET');

  { --- _KTRT_PRINTSTR : SI = str ASCIIZ -> STDOUT --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_PRINTSTR : SI = str ASCIIZ -> STDOUT ---');
  EmitLabel('_KTRT_PRINTSTR');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstr('CALL _KTRT_STRLEN');
  EmitInstrAB('MOV', 'DX', 'SI');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstr('INT 21h');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');
  EmitInstr('RET');

  { --- _KTRT_PRINT : AX = entier -> STDOUT --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_PRINT : AX = entier -> STDOUT ---');
  EmitLabel('_KTRT_PRINT');
  EmitInstr('CALL _KTRT_NUMTOSTR');
  EmitInstr('CALL _KTRT_PRINTSTR');
  EmitInstr('RET');

  { --- _KTRT_NEWLINE : afficher CR+LF sur STDOUT --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_NEWLINE : CR+LF sur STDOUT ---');
  EmitLabel('_KTRT_NEWLINE');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'OFFSET _KT_CRLF');
  EmitInstr('CALL _KTRT_PRINTSTR');
  EmitInstrA('POP', 'SI');
  EmitInstr('RET');

  { --- _KTRT_READLINE : lire une ligne STDIN -> AX = ptr --- }
  EmitBlankLine;
  EmitComment('--- _KTRT_READLINE : lire ligne STDIN -> AX = ptr ---');
  EmitLabel('_KTRT_READLINE');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrAB('MOV', 'AH', '0Ah');
  EmitInstrAB('MOV', 'DX', 'OFFSET _KT_INPUTMX');
  EmitInstr('INT 21h');
  EmitComment('Convertir le buffer DOS en ASCIIZ');
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('MOV', 'BL', '[_KT_INPUTLN]');
  EmitInstrAB('MOV', 'BYTE PTR [_KT_INPUTBF+BX]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _KT_INPUTBF');
  EmitComment('Afficher un retour a la ligne apres la saisie');
  EmitInstr('CALL _KTRT_NEWLINE');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'DX');
  EmitInstr('RET');
End;
Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('-- Fin de programme : DOS exit --');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT 21h');
  EmitBlankLine;
  EmitEpilog;
  EmitBlankLine;
  If Not RuntimeEmitted Then
    EmitRuntime;
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END ' + KT_FN_PFX + 'main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

(* ---- TypeSizeof : taille en octets d un type ---------------- *)
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

(* ---- TypeKindOf : retourner le TTypeKind d un type ---------- *)
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_INT;
End;

(* ---- TypeMangle : prefixe ASM selon le type Kotlin ---------- *)
(* Utilisee pour nommer les etiquettes DATA specifiques au type.  *)
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_INT      : TypeMangle := '_KTN_';
    TYK_SHORT    : TypeMangle := '_KTN_';
    TYK_LONG     : TypeMangle := '_KTN_';
    TYK_BYTE     : TypeMangle := '_KTB_';
    TYK_BOOLEAN  : TypeMangle := '_KTB_';
    TYK_CHAR     : TypeMangle := '_KTC_';
    TYK_FLOAT    : TypeMangle := '_KTD_';
    TYK_DOUBLE   : TypeMangle := '_KTD_';
    TYK_STRING   : TypeMangle := '_KTS_';
    TYK_ARRAY    : TypeMangle := '_KTA_';
    TYK_INTARRAY : TypeMangle := '_KTA_';
    TYK_CLASS    : TypeMangle := '_KTO_';
    TYK_INTERFACE: TypeMangle := '_KTI_';
    TYK_ENUM     : TypeMangle := '_KTE_';
    TYK_UNIT     : TypeMangle := '_KTU_';
    TYK_NOTHING  : TypeMangle := '_KTU_';
    TYK_ANY      : TypeMangle := '_KTX_';
    TYK_LAMBDA   : TypeMangle := '_KTL_';
    TYK_NULLABLE : TypeMangle := '_KTQ_';
  Else
    TypeMangle := '_KTX_';
  End;
End;

(* ---- TypeIsNumeric : vrai si le type se place dans AX ------- *)
(* Int, Short, Long (stub 16-bit), Byte, Float/Double (stub        *)
(* entier tronque), Char, Boolean, Enum sont tous representes       *)
(* comme des entiers 16 bits dans AX sur la cible 8086.             *)
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_INT)     Or (K = TYK_SHORT)   Or
    (K = TYK_LONG)    Or (K = TYK_BYTE)    Or
    (K = TYK_FLOAT)   Or (K = TYK_DOUBLE)  Or
    (K = TYK_CHAR)    Or (K = TYK_BOOLEAN) Or
    (K = TYK_ENUM);
End;

(* ---- TypeIsPtr : vrai si le type est un pointeur 16 bits ---- *)
(* String, Array, IntArray, Class, Interface, Lambda, Any         *)
(* sont stockes comme des pointeurs 16 bits (segment DATA).       *)
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TYK_STRING)   Or (K = TYK_ARRAY)    Or
    (K = TYK_INTARRAY) Or (K = TYK_CLASS)     Or
    (K = TYK_INTERFACE)Or (K = TYK_LAMBDA)    Or
    (K = TYK_ANY);
End;

(* ---- TypeCanCoerce : coercition src -> dst possible ? ------- *)
(* Kotlin est strict sur les coercitions : pas de coercition       *)
(* implicite entre types numeriques. On autorise cependant :       *)
(*   - meme type                                                   *)
(*   - dst=UNKNOWN -> toujours OK                                  *)
(*   - src=NOTHING -> convertible en tout (type bottom)            *)
(*   - dst=ANY -> toujours OK (type racine)                        *)
(*   - dst=NULLABLE -> si src compatible avec le type sous-jacent  *)
(*   - promotions entier explicites Int<->Short/Long/Byte          *)
(*   - Boolean/Byte -> Int (widening)                              *)
(*   - Float <-> Double                                            *)
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
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
  If SrcIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  { Nothing -> tout type (type bottom) }
  If SK = TYK_NOTHING Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { tout -> Any (type racine) }
  If DK = TYK_ANY Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { tout -> Nullable (enveloppe) }
  If DK = TYK_NULLABLE Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Promotions numeriques entieres Kotlin (widening) :             }
  {   Byte -> Short -> Int -> Long                                  }
  {   Char -> Int                                                   }
  If (DK = TYK_INT) And
     ((SK = TYK_BYTE) Or (SK = TYK_SHORT) Or
      (SK = TYK_CHAR) Or (SK = TYK_BOOLEAN)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If (DK = TYK_SHORT) And (SK = TYK_BYTE) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If (DK = TYK_LONG) And
     ((SK = TYK_INT) Or (SK = TYK_SHORT) Or (SK = TYK_BYTE)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Float <-> Double : meme representation stub }
  If ((DK = TYK_DOUBLE) And (SK = TYK_FLOAT)) Or
     ((DK = TYK_FLOAT) And (SK = TYK_DOUBLE)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Int/Short/Long/Byte -> Float/Double : widening numerique }
  If ((DK = TYK_FLOAT) Or (DK = TYK_DOUBLE)) And
     ((SK = TYK_INT) Or (SK = TYK_SHORT) Or
      (SK = TYK_LONG) Or (SK = TYK_BYTE)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  TypeCanCoerce := False;
End;

(* ---- TypeCoerceResult : type resultat d une operation binaire *)
(* Logique Kotlin :                                                *)
(*   comparaisons/logique -> Boolean                               *)
(*   ?: (elvis) -> type du cote non-null                           *)
(*   + avec String -> String (concatenation)                       *)
(*   arithmetique entre entiers -> Int (ou Long si un Long)        *)
(*   arithmetique avec Float/Double -> Float/Double                *)
(*   assignation -> type du cote droit                             *)
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  { Operateurs toujours booleens }
  If (Op = '==')  Or (Op = '!=')  Or
     (Op = '===') Or (Op = '!==') Or
     (Op = '<')   Or (Op = '<=')  Or
     (Op = '>')   Or (Op = '>=')  Or
     (Op = '&&')  Or (Op = '||')  Or
     (Op = 'in')  Or (Op = '!in') Or
     (Op = 'is')  Or (Op = '!is') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;
  { Elvis ?: retourne le type du cote non-nullable }
  If Op = '?:' Then
  Begin
    TypeCoerceResult := RightIdx;
    Exit;
  End;
  { Range .. retourne Int (stub) }
  If Op = '..' Then
  Begin
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  { + avec une String : concatenation -> String }
  If Op = '+' Then
  Begin
    If (LK = TYK_STRING) Or (RK = TYK_STRING) Then
    Begin
      TypeCoerceResult := TY_IDX_STRING;
      Exit;
    End;
  End;
  { as / as? : cast -> type de droite }
  If (Op = 'as') Or (Op = 'as?') Then
  Begin
    TypeCoerceResult := RightIdx;
    Exit;
  End;
  { Arithmetique : +, -, *, /, % }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Then
  Begin
    { Si un des deux est Double/Float -> Double }
    If (LK = TYK_DOUBLE) Or (RK = TYK_DOUBLE) Then
    Begin
      TypeCoerceResult := TY_IDX_DOUBLE;
      Exit;
    End;
    If (LK = TYK_FLOAT) Or (RK = TYK_FLOAT) Then
    Begin
      TypeCoerceResult := TY_IDX_FLOAT;
      Exit;
    End;
    { Si un des deux est Long -> Long }
    If (LK = TYK_LONG) Or (RK = TYK_LONG) Then
    Begin
      TypeCoerceResult := TY_IDX_LONG;
      Exit;
    End;
    { Sinon -> Int }
    TypeCoerceResult := TY_IDX_INT;
    Exit;
  End;
  { Assignation : le type du cote droit }
  TypeCoerceResult := RightIdx;
End;

(* ---- TypeInfer : deduire le type d une expression ----------- *)
(* Si le TypeIdx est deja connu, on le retourne directement.       *)
(* Sinon pour une immediate on suppose Int, pour le reste UNKNOWN. *)
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_INT
  Else
    TypeInfer := TY_UNKNOWN;
End;

(* ---- TypeLookupName : chercher un type par nom -------------- *)
(* Comparaison exacte (Kotlin est case-sensitive).                 *)
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

Procedure TypeInit;
  Procedure AddType(Const N : TString; K : TTypeKind; Sz : Integer);
  Begin
    If TypeCount >= MAX_TYPE Then Exit;
    TypeTab[TypeCount].Name := N;
    TypeTab[TypeCount].Kind := K;
    TypeTab[TypeCount].Size := Sz;
    Inc(TypeCount);
  End;
Begin
  TypeCount := 0;
  AddType('Int',      TYK_INT,      2);  { TY_IDX_INT      = 0  }
  AddType('Short',    TYK_SHORT,    2);  { TY_IDX_SHORT    = 1  }
  AddType('Long',     TYK_LONG,     2);  { TY_IDX_LONG     = 2  }
  AddType('Byte',     TYK_BYTE,     1);  { TY_IDX_BYTE     = 3  }
  AddType('Boolean',  TYK_BOOLEAN,  1);  { TY_IDX_BOOLEAN  = 4  }
  AddType('Char',     TYK_CHAR,     1);  { TY_IDX_CHAR     = 5  }
  AddType('Float',    TYK_FLOAT,    2);  { TY_IDX_FLOAT    = 6  }
  AddType('Double',   TYK_DOUBLE,   2);  { TY_IDX_DOUBLE   = 7  }
  AddType('String',   TYK_STRING,   2);  { TY_IDX_STRING   = 8  }
  AddType('Array',    TYK_ARRAY,    2);  { TY_IDX_ARRAY    = 9  }
  AddType('IntArray', TYK_INTARRAY, 2);  { TY_IDX_INTARRAY = 10 }
  AddType('Unit',     TYK_UNIT,     0);  { TY_IDX_UNIT     = 11 }
  AddType('Nothing',  TYK_NOTHING,  0);  { TY_IDX_NOTHING  = 12 }
  AddType('Any',      TYK_ANY,      2);  { TY_IDX_ANY      = 13 }
  AddType('Lambda',   TYK_LAMBDA,   2);  { TY_IDX_LAMBDA   = 14 }
End;

{ --- TODO 08 : Donnees [IMPLEMENTE] ------------------------- }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('table de donnees pleine');
    DataAdd := -1;
    Exit;
  End;
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
  I   : Integer;
Begin
  { Dedup : chercher chaine existante }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := DataTab[I].LblName;
      Exit;
    End;
  Lbl := KT_STR_PFX + IntToStr(DataCount);
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- DataAddArray : ajouter un bloc DK_ARRAY_BLK ----------- *)
Function DataAddArray(Const Lbl : TString; ACount : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_ARRAY_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := ACount;
  DataAddArray := Idx;
End;

(* ---- DataAddObj : ajouter un bloc DK_OBJ_BLK --------------- *)
Function DataAddObj(Const Lbl : TString; ASize : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_OBJ_BLK, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].ElemCount := ASize;
  DataAddObj := Idx;
End;

(* ---- DataInit : pre-remplir le segment DATA ----------------- *)
Procedure DataInit;
Begin
  DataCount := 0;
  { Chaines predefinies Kotlin }
  DataAdd('_KT_CRLF',      DK_STR, 0, #13#10);
  DataAdd('_KT_NULL_STR',  DK_STR, 0, '');
  DataAdd('_KT_TRUE_S',    DK_STR, 0, 'true');
  DataAdd('_KT_FALSE_S',   DK_STR, 0, 'false');
  { Tampon de travail }
  DataAdd('_KT_STRBUF',    DK_BYTE, 0, '');
  DataTab[DataCount - 1].ElemCount := 256;
  { TODO 12 - Donnees E/S }
  DataAdd('_KT_NUMBUF',    DK_BYTE, 0, '');
  DataTab[DataCount - 1].ElemCount := 12;
  DataAdd('_KT_SPACE',     DK_STR, 0, ' ');
  DataAdd('_KT_INPUTMX',   DK_BYTE, 126, '');
  DataAdd('_KT_INPUTLN',   DK_BYTE, 0, '');
  DataAdd('_KT_INPUTBF',   DK_BYTE, 0, '');
  DataTab[DataCount - 1].ElemCount := 128;
End;

{ --- TODO 09 : Variables et Affectations [IMPLEMENTE] --------- }

(* ---- ExprAddrOf : retourne l adresse MASM d un symbole ------ *)
(* Locaux : [BP-n], parametres : [BP+n], globaux : [_KTV_nom]     *)
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

(* ---- ExprFlushToAX : s assurer que la valeur est dans AX ---- *)
Procedure ExprFlushToAX(Const E : TExprVal);
Var
  Addr : TString;
  SVal : TString;
  K    : TTypeKind;
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
        K := TypeKindOf(E.TypeIdx);
        { Arrays, classes et parametres : MOV car la variable contient deja la valeur }
        If (K = TYK_ARRAY) Or (K = TYK_INTARRAY) Or (K = TYK_CLASS) Or
           ((E.SymIdx >= 0) And (SymTab[E.SymIdx].Kind = SK_PARAM)) Then
          EmitInstrAB('MOV', 'AX', Addr)
        Else If TypeIsPtr(E.TypeIdx) Then
          EmitInstrAB('LEA', 'AX', Addr)
        Else
          EmitInstrAB('MOV', 'AX', Addr);
      End
      Else
        EmitInstrAB('XOR', 'AX', 'AX');
    EK_AX   : ; { deja dans AX }
    EK_NONE : EmitInstrAB('XOR', 'AX', 'AX');
  End;
End;

(* ---- ExprStore : stocker AX dans le symbole SIdx ------------ *)
Procedure ExprStore(SIdx : Integer);
Var
  Addr : TString;
Begin
  If SIdx < 0 Then Exit;
  If SymTab[SIdx].IsConst Then
  Begin
    CompileError('val "' + SymTab[SIdx].Name + '" ne peut pas etre reassignee');
    Exit;
  End;
  Addr := ExprAddrOf(SIdx);
  EmitInstrAB('MOV', Addr, 'AX');
End;

(* ---- ExprLoad : charger le symbole SIdx dans AX ------------- *)
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var
  Addr : TString;
  K    : TTypeKind;
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
  Addr := ExprAddrOf(SIdx);
  K := TypeKindOf(Res.TypeIdx);
  { Arrays, classes et parametres : MOV car la variable contient deja la valeur }
  If (K = TYK_ARRAY) Or (K = TYK_INTARRAY) Or (K = TYK_CLASS) Or
     (SymTab[SIdx].Kind = SK_PARAM) Then
    EmitInstrAB('MOV', 'AX', Addr)
  Else If TypeIsPtr(Res.TypeIdx) Then
    EmitInstrAB('LEA', 'AX', Addr)
  Else
    EmitInstrAB('MOV', 'AX', Addr);
End;

(* ---- DeclAllocSym : creer un symbole pour val/var ----------- *)
(* Global (CurFnDepth=0) : Offset=0 + entree DK_WORD dans DATA   *)
(* Local  (CurFnDepth>0) : Offset=-SymNextOffset (pile)           *)
Function DeclAllocSym(Const Name : TString; Kind : TSymKind) : Integer;
Var
  SIdx   : Integer;
  Offset : Integer;
Begin
  { Verifier la redeclaration dans le meme scope }
  SIdx := SymFindInScope(Name, CurScope);
  If SIdx >= 0 Then
  Begin
    CompileError('redeclaration de "' + Name + '" dans la meme portee');
    DeclAllocSym := SIdx;
    Exit;
  End;
  { Calculer l offset selon le contexte }
  If CurFnDepth = 0 Then
    Offset := 0
  Else
  Begin
    Offset := -SymNextOffset;
    { TODO 18 : emettre SUB SP,2 pour allouer l espace pile }
    EmitInstrAB('SUB', 'SP', '2');
  End;
  SIdx := SymAdd(Name, Kind, TY_UNKNOWN, Offset);
  { Variable globale : entree dans le segment de donnees }
  If CurFnDepth = 0 Then
    DataAddWord(SymTab[SIdx].MangledName, 0);
  DeclAllocSym := SIdx;
End;

(* ---- ParseTypeAnnotation : parser : Type optionnel ---------- *)
(* Retourne l indice dans TypeTab ou TY_UNKNOWN si absent.        *)
Function ParseTypeAnnotation : Integer;
Var
  TName : TString;
  TIdx  : Integer;
Begin
  ParseTypeAnnotation := TY_UNKNOWN;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ':') Then
  Begin
    ParserAdvance; { consomme ':' }
    If CurToken.Kind = TK_IDENT Then
    Begin
      TName := CurToken.Val;
      TIdx := TypeLookupName(TName);
      If TIdx >= 0 Then
        ParseTypeAnnotation := TIdx
      Else
        WarnMsg('type inconnu : ' + TName);
      ParserAdvance;
      { Nullable ? }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
        ParserAdvance;
    End
    Else If CurToken.Kind = TK_KEYWORD Then
    Begin
      TName := CurToken.Val;
      TIdx := TypeLookupName(TName);
      If TIdx >= 0 Then
        ParseTypeAnnotation := TIdx;
      ParserAdvance;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') Then
        ParserAdvance;
    End
    Else
      CompileError('nom de type attendu apres ":"');
  End;
End;

(* ---- ParseDeclStmt : val/var nom [: Type] [= expr] ---------- *)
(* Kw = 'val' ou 'var'. Gere const val et lateinit var.           *)
Procedure ParseDeclStmt(Const Kw : TString);
Var
  Kind    : TSymKind;
  IsConst : Boolean;
  IsLateinit : Boolean;
  Name    : TString;
  SIdx    : Integer;
  TyIdx   : Integer;
  Res     : TExprVal;
  Addr    : TString;
Begin
  IsConst    := False;
  IsLateinit := False;
  { Determiner le TSymKind }
  If Kw = 'val' Then
  Begin
    Kind := SK_VAL;
    IsConst := True;
  End
  Else
    Kind := SK_VAR;

  { Verifier modificateur 'lateinit' devant (deja consomme avant appel) }
  { Note : en Kotlin, 'lateinit var x: Type' - le modificateur est      }
  {   gere en amont dans ParseStmt si besoin                            }

  { L identifiant }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('identifiant attendu apres "' + Kw + '"');
    Exit;
  End;
  Name := CurToken.Val;
  ParserAdvance;

  { Annotation de type optionnelle : : Type }
  TyIdx := ParseTypeAnnotation;

  { Allouer le symbole }
  SIdx := DeclAllocSym(Name, Kind);
  If TyIdx <> TY_UNKNOWN Then
    SymTab[SIdx].TypeIdx := TyIdx;
  SymTab[SIdx].IsConst    := IsConst;
  SymTab[SIdx].IsLateinit := IsLateinit;

  { Initialisation : = expr }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance; { consomme '=' }
    ParseExpr(Res);
    ExprFlushToAX(Res);
    Addr := ExprAddrOf(SIdx);
    EmitInstrAB('MOV', Addr, 'AX');
    { Inference de type si non annote }
    If SymTab[SIdx].TypeIdx = TY_UNKNOWN Then
      SymTab[SIdx].TypeIdx := Res.TypeIdx;
  End
  Else
  Begin
    { Pas d initialisation }
    If IsConst Then
      CompileError('val "' + Name + '" doit etre initialisee');
    { Initialiser a 0 }
    Addr := ExprAddrOf(SIdx);
    EmitInstrAB('MOV', Addr, '0');
    If SymTab[SIdx].TypeIdx = TY_UNKNOWN Then
      SymTab[SIdx].TypeIdx := TY_IDX_INT;
  End;
End;

{ ============================================================
  TODO 13 - IF / ELSE / WHEN [IMPLEMENTE]
  ============================================================ }

(* ---- ParseBlock : bloc { stmts } ou instruction unique ----- *)
(* Gere les accolades : si le token courant est '{' on parse     *)
(* une suite de statements jusqu a '}', sinon on parse une       *)
(* seule instruction.                                            *)
Procedure ParseBlock;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_LBRACE) Then
  Begin
    ParserAdvance; (* consomme open-brace *)
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_RBRACE)) Do
      ParseStmt;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = CH_RBRACE) Then
      ParserAdvance  (* consomme close-brace *)
    Else
      CompileError('"}" attendue pour fermer le bloc');
  End
  Else
    ParseStmt;
End;

(* ---- ParseIfStmt : if (cond) bloc [else if/else] ----------- *)
(* Syntaxe Kotlin : if (cond) bloc [else if (cond) bloc] [else bloc] *)
(* Emission : TEST AX,AX / JZ label_else / ... / JMP label_end  *)
Procedure ParseIfStmt;
Var
  Res     : TExprVal;
  LblElse : TString;
  LblEnd  : TString;
Begin
  EmitComment('if');
  LblEnd := LabelGen;
  ParserAdvance; { consomme 'if' }
  { Parenthese ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance { consomme '(' }
  Else
    CompileError('"(" attendue apres "if"');
  { Condition }
  ParseExpr(Res);
  ExprFlushToAX(Res);
  { Parenthese fermante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance { consomme ')' }
  Else
    CompileError('")" attendue apres la condition');
  { TEST AX,AX / JZ else_label }
  LblElse := LabelGen;
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblElse);
  { Bloc then }
  ScopeBlockEnter;
  ParseBlock;
  ScopeBlockLeave;
  { Verifier else }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblElse);
    ParserAdvance; { consomme 'else' }
    { else if -> appel recursif }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'if') Then
    Begin
      ParseIfStmt;
    End
    Else
    Begin
      { else bloc }
      ScopeBlockEnter;
      ParseBlock;
      ScopeBlockLeave;
    End;
    EmitLabel(LblEnd);
  End
  Else
  Begin
    { Pas de else : le label else est le label de fin }
    EmitLabel(LblElse);
    EmitLabel(LblEnd);
  End;
End;

(* ---- ParseWhenStmt : when [(expr)] { branches } ------------ *)
(* Syntaxe :                                                      *)
(*   when (expr) { val -> stmts; val1, val2 -> stmts; in a..b -> *)
(*   stmts; else -> stmts }                                      *)
(*   when { cond -> stmts; else -> stmts }  (sans argument)      *)
(* Emission : MOV DX,<selector>  pour chaque branche CMP DX,val  *)
(*   JE branch / JMP next                                        *)
Procedure ParseWhenStmt;
Var
  Res      : TExprVal;
  HasSubj  : Boolean;
  LblEnd   : TString;
  LblNext  : TString;
  LblBody  : TString;
  ResB     : TExprVal;
Begin
  EmitComment('when');
  ParserAdvance; { consomme 'when' }
  LblEnd := LabelGen;
  HasSubj := False;
  (* when (expr) ou when sans sujet *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance; { consomme '(' }
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitInstrAB('MOV', 'DX', 'AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance
    Else
      CompileError('")" attendue apres when(expr)');
    HasSubj := True;
  End;
  { Accolade ouvrante }
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = CH_LBRACE) Then
    ParserAdvance (* consomme open-brace *)
  Else
    CompileError('accolade attendue apres when');
  { Boucle de branches }
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And
             (CurToken.Val = CH_RBRACE)) Do
  Begin
    LblNext := LabelGen;
    { else -> ... }
    If (CurToken.Kind = TK_KEYWORD) And
       (CurToken.Val = 'else') Then
    Begin
      ParserAdvance; { consomme 'else' }
      If (CurToken.Kind = TK_OP) And
         (CurToken.Val = '->') Then
        ParserAdvance
      Else
        CompileError('"->" attendu apres "else"');
      ScopeBlockEnter;
      ParseBlock;
      ScopeBlockLeave;
      EmitInstrA('JMP', LblEnd);
    End
    Else If HasSubj Then
    Begin
      { Branche avec sujet : val [, val2] -> stmt }
      LblBody := LabelGen;
      ParseExpr(ResB);
      ExprFlushToAX(ResB);
      EmitInstrAB('CMP', 'DX', 'AX');
      EmitInstrA('JE', LblBody);
      { Valeurs multiples separees par ',' }
      While (CurToken.Kind = TK_PUNCT) And
            (CurToken.Val = ',') Do
      Begin
        ParserAdvance; { consomme ',' }
        ParseExpr(ResB);
        ExprFlushToAX(ResB);
        EmitInstrAB('CMP', 'DX', 'AX');
        EmitInstrA('JE', LblBody);
      End;
      EmitInstrA('JMP', LblNext);
      EmitLabel(LblBody);
      { -> }
      If (CurToken.Kind = TK_OP) And
         (CurToken.Val = '->') Then
        ParserAdvance
      Else
        CompileError('"->" attendu apres valeur when');
      ScopeBlockEnter;
      ParseBlock;
      ScopeBlockLeave;
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);
    End
    Else
    Begin
      { when sans sujet : cond -> stmt }
      ParseExpr(ResB);
      ExprFlushToAX(ResB);
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblNext);
      If (CurToken.Kind = TK_OP) And
         (CurToken.Val = '->') Then
        ParserAdvance
      Else
        CompileError('"->" attendu apres condition');
      ScopeBlockEnter;
      ParseBlock;
      ScopeBlockLeave;
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);
    End;
  End;
  { Accolade fermante }
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = CH_RBRACE) Then
    ParserAdvance (* consomme close-brace *)
  Else
    CompileError('accolade fermante attendue when');
  EmitLabel(LblEnd);
End;

{ ============================================================
  TODO 14 - BOUCLES [IMPLEMENTE]
  ============================================================ }

(* ---- LoopPush : empiler labels break/continue --------------- *)
Procedure LoopPush(BrkLbl, ContLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
    CompileError('boucles trop imbriquees')
  Else
  Begin
    LoopBreakLbl[LoopTop] := BrkLbl;
    LoopContLbl[LoopTop]  := ContLbl;
    Inc(LoopTop);
  End;
End;

(* ---- LoopPop : depiler labels break/continue ---------------- *)
Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

(* ---- ParseWhileStmt : while (cond) bloc -------------------- *)
Procedure ParseWhileStmt;
Var
  Res     : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');
  ParserAdvance; { consomme 'while' }
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);
  EmitLabel(LblTest);
  { ( cond ) }
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('"(" attendue apres "while"');
  ParseExpr(Res);
  ExprFlushToAX(Res);
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendue apres condition');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);
  { Bloc }
  ScopeBlockEnter;
  ParseBlock;
  ScopeBlockLeave;
  EmitInstrA('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ---- ParseDoWhileStmt : do bloc while (cond) --------------- *)
Procedure ParseDoWhileStmt;
Var
  Res     : TExprVal;
  LblBeg  : TString;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('do-while');
  ParserAdvance; { consomme 'do' }
  LblBeg  := LabelGen;
  LblTest := LabelGen;
  LblEnd  := LabelGen;
  LoopPush(LblEnd, LblTest);
  EmitLabel(LblBeg);
  { Bloc }
  ScopeBlockEnter;
  ParseBlock;
  ScopeBlockLeave;
  EmitLabel(LblTest);
  { while (cond) }
  If (CurToken.Kind = TK_KEYWORD) And
     (CurToken.Val = 'while') Then
    ParserAdvance
  Else
    CompileError('"while" attendu apres do-bloc');
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('"(" attendue apres "while"');
  ParseExpr(Res);
  ExprFlushToAX(Res);
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendue apres condition');
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JNZ', LblBeg);
  EmitLabel(LblEnd);
  LoopPop;
End;

(* ---- ParseForStmt : for (item in range) bloc ---------------- *)
(* Syntaxe : for (i in lo..hi) bloc                               *)
(*           for (i in lo until hi) bloc                          *)
(*           for (i in hi downTo lo) bloc                         *)
(*           for (i in lo..hi step s) bloc                        *)
Procedure ParseForStmt;
Var
  VarName  : TString;
  SIdx     : Integer;
  Addr     : TString;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  ResLo    : TExprVal;
  ResHi    : TExprVal;
  ResStep  : TExprVal;
  IsDown   : Boolean;
  IsUntil  : Boolean;
  HasStep  : Boolean;
  EndLbl   : TString;
  StepLbl  : TString;
Begin
  EmitComment('for');
  ParserAdvance; { consomme 'for' }
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;
  IsDown   := False;
  IsUntil  := False;
  HasStep  := False;
  { ( }
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('"(" attendue apres "for"');
  { Nom de variable }
  If CurToken.Kind <> TK_IDENT Then
    CompileError('identifiant attendu dans for');
  VarName := CurToken.Val;
  ParserAdvance;
  { in }
  If (CurToken.Kind = TK_KEYWORD) And
     (CurToken.Val = 'in') Then
    ParserAdvance
  Else
    CompileError('"in" attendu dans for');
  { Scope pour la variable de boucle }
  ScopeBlockEnter;
  SIdx := DeclAllocSym(VarName, SK_VAR);
  SymTab[SIdx].TypeIdx := TY_IDX_INT;
  Addr := ExprAddrOf(SIdx);
  { Allouer DATA pour borne et step }
  EndLbl := LabelGen;
  DataAdd(EndLbl, DK_WORD, 0, '');
  StepLbl := LabelGen;
  DataAdd(StepLbl, DK_WORD, 1, '');
  { Borne de depart (precedence > range) }
  ParseExprPrec(7, ResLo);
  ExprFlushToAX(ResLo);
  EmitInstrAB('MOV', Addr, 'AX');
  { Detecter '..' / 'until' / 'downTo' }
  If (CurToken.Kind = TK_OP) And
     (CurToken.Val = '..') Then
  Begin
    ParserAdvance; { consomme '..' }
    ParseExprPrec(7, ResHi);
    ExprFlushToAX(ResHi);
    EmitInstrAB('MOV', '[' + EndLbl + ']', 'AX');
  End
  Else If (CurToken.Kind = TK_KEYWORD) And
          (CurToken.Val = 'until') Then
  Begin
    IsUntil := True;
    ParserAdvance; { consomme 'until' }
    ParseExprPrec(7, ResHi);
    ExprFlushToAX(ResHi);
    EmitInstrAB('MOV', '[' + EndLbl + ']', 'AX');
  End
  Else If (CurToken.Kind = TK_KEYWORD) And
          (CurToken.Val = 'downTo') Then
  Begin
    IsDown := True;
    ParserAdvance; { consomme 'downTo' }
    ParseExprPrec(7, ResHi);
    ExprFlushToAX(ResHi);
    EmitInstrAB('MOV', '[' + EndLbl + ']', 'AX');
  End
  Else
    CompileError('".." ou "until" ou "downTo"');
  { Detecter 'step' }
  If (CurToken.Kind = TK_KEYWORD) And
     (CurToken.Val = 'step') Then
  Begin
    HasStep := True;
    ParserAdvance; { consomme 'step' }
    ParseExpr(ResStep);
    ExprFlushToAX(ResStep);
    EmitInstrAB('MOV', '[' + StepLbl + ']', 'AX');
  End;
  { ) }
  If (CurToken.Kind = TK_PUNCT) And
     (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('")" attendue apres for(...)');
  { Labels et pile de boucle }
  LoopPush(LblEnd, LblIncr);
  { Test de boucle }
  EmitLabel(LblTest);
  EmitInstrAB('MOV', 'AX', Addr);
  EmitInstrAB('MOV', 'BX', '[' + EndLbl + ']');
  If IsDown Then
  Begin
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JL', LblEnd);
  End
  Else If IsUntil Then
  Begin
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JGE', LblEnd);
  End
  Else
  Begin
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JG', LblEnd);
  End;
  { Corps de la boucle }
  ParseBlock;
  { Increment }
  EmitLabel(LblIncr);
  EmitInstrAB('MOV', 'AX', Addr);
  If HasStep Then
  Begin
    EmitInstrAB('MOV', 'CX', '[' + StepLbl + ']');
    If IsDown Then
      EmitInstrAB('SUB', 'AX', 'CX')
    Else
      EmitInstrAB('ADD', 'AX', 'CX');
  End
  Else
  Begin
    If IsDown Then
      EmitInstrA('DEC', 'AX')
    Else
      EmitInstrA('INC', 'AX');
  End;
  EmitInstrAB('MOV', Addr, 'AX');
  EmitInstrA('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
  ScopeBlockLeave;
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
End;

Procedure ParseStmt;
Var
  Kw      : TString;
  Res     : TExprVal;
  IdName  : TString;
  SIdx    : Integer;
  Addr    : TString;
  ClsI    : Integer;
  FldI    : Integer;
Begin
  { Declarations val / var }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    Kw := CurToken.Val;
    If (Kw = 'val') Or (Kw = 'var') Then
    Begin
      ParserAdvance; { consomme val/var }
      ParseDeclStmt(Kw);
      Exit;
    End;
    { TODO 13 - if / when }
    If Kw = 'if' Then
    Begin
      ParseIfStmt;
      Exit;
    End;
    If Kw = 'when' Then
    Begin
      ParseWhenStmt;
      Exit;
    End;
    { TODO 14 - boucles }
    If Kw = 'while' Then
    Begin
      ParseWhileStmt;
      Exit;
    End;
    If Kw = 'do' Then
    Begin
      ParseDoWhileStmt;
      Exit;
    End;
    If Kw = 'for' Then
    Begin
      ParseForStmt;
      Exit;
    End;
    If Kw = 'break' Then
    Begin
      ParserAdvance; { consomme 'break' }
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopBreakLbl[LoopTop-1])
      Else
        CompileError('break hors d''une boucle');
      Exit;
    End;
    If Kw = 'continue' Then
    Begin
      ParserAdvance; { consomme 'continue' }
      If LoopTop > 0 Then
        EmitInstrA('JMP', LoopContLbl[LoopTop-1])
      Else
        CompileError('continue hors boucle');
      Exit;
    End;
    { TODO 16 - class et data class }
    If (Kw = 'class') Or (Kw = 'data') Then
    Begin
      ParseClassDecl;
      Exit;
    End;
    If (Kw = 'open') Or (Kw = 'abstract') Or (Kw = 'sealed') Then
    Begin
      ParserAdvance; { consomme le modificateur }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'class') Then
        ParseClassDecl
      Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fun') Then
        ParseFunDecl
      Else
        ParserAdvance;
      Exit;
    End;
    { TODO 17 - fun declaration }
    If Kw = 'fun' Then
    Begin
      ParseFunDecl;
      Exit;
    End;
    If Kw = 'return' Then
    Begin
      ParseReturnStmt;
      Exit;
    End;
    { Modificateurs de fonction : inline, infix, private, internal }
    If (Kw = 'inline') Or (Kw = 'infix') Or
       (Kw = 'private') Or (Kw = 'internal') Or
       (Kw = 'protected') Or (Kw = 'public') Or
       (Kw = 'override') Then
    Begin
      ParserAdvance; { consomme le modificateur }
      If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'fun') Then
        ParseFunDecl;
      Exit;
    End;
  End;
  { TODO 12 - Expression-statement : appel de fonction ou affectation }
  If CurToken.Kind = TK_IDENT Then
  Begin
    IdName := CurToken.Val;
    SIdx := SymFind(IdName);
    { Affectation : ident = expr (variable deja declaree, non-fonction) }
    If (SIdx >= 0) And (SymTab[SIdx].Kind <> SK_FUN) Then
    Begin
      ParserAdvance; { consomme l identifiant }
      { TODO 15 - Affectation tableau : arr[i] = expr }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        ExprLoad(SIdx, Res);
        ExprFlushToAX(Res);
        EmitInstrA('PUSH', 'AX'); { sauver base tableau }
        ParserAdvance; { consomme '[' }
        ParseExpr(Res);
        ExprFlushToAX(Res); { AX = index }
        EmitInstrAB('SHL', 'AX', '1');
        EmitInstrAB('ADD', 'AX', '2');
        EmitInstrA('POP', 'BX');
        EmitInstrAB('ADD', 'BX', 'AX');
        EmitInstrA('PUSH', 'BX'); { sauver adresse element }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance; { consomme ']' }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
        Begin
          ParserAdvance; { consomme '=' }
          ParseExpr(Res);
          ExprFlushToAX(Res);
          EmitInstrA('POP', 'BX');
          EmitInstrAB('MOV', '[BX]', 'AX');
        End
        Else
        Begin
          EmitInstrA('POP', 'BX');
          EmitInstrAB('MOV', 'AX', '[BX]');
        End;
        Exit;
      End;
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance; { consomme '=' }
        ParseExpr(Res);
        ExprFlushToAX(Res);
        Addr := ExprAddrOf(SIdx);
        EmitInstrAB('MOV', Addr, 'AX');
        If SymTab[SIdx].TypeIdx = TY_UNKNOWN Then
          SymTab[SIdx].TypeIdx := Res.TypeIdx;
        Exit;
      End;
      { TODO 16 - Affectation champ : obj.field = expr }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
      Begin
        ExprLoad(SIdx, Res);
        ExprFlushToAX(Res);
        ParserAdvance; { consomme '.' }
        If CurToken.Kind = TK_IDENT Then
        Begin
          IdName := CurToken.Val;
          ParserAdvance; { consomme le nom du champ }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
          Begin
            ParserAdvance; { consomme '=' }
            EmitInstrA('PUSH', 'AX'); { sauver pointeur objet }
            ParseExpr(Res);
            ExprFlushToAX(Res);
            EmitInstrA('POP', 'BX');
            ClsI := ClassFindByTypeIdx(SymTab[SIdx].TypeIdx);
            If ClsI >= 0 Then
            Begin
              FldI := ClassFieldFind(ClsI, IdName);
              If FldI >= 0 Then
                EmitInstrAB('MOV', '[BX+' +
                  IntToStr(ClassTab[ClsI].Fields[FldI].Offset) + ']', 'AX')
              Else
                EmitInstrAB('MOV', '[BX]', 'AX');
            End
            Else
              EmitInstrAB('MOV', '[BX]', 'AX');
            Exit;
          End;
        End;
        { Pas une affectation de champ : rembobiner }
        Exit;
      End;
      { Pas une affectation : rembobiner en evaluant comme expression }
      { L identifiant a deja ete consomme, charger la variable }
      ExprLoad(SIdx, Res);
      { Continuer avec les suffixes et operateurs dans ParseExprPrec }
      ExprFlushToAX(Res);
      Exit;
    End;
    { Expression-statement (appel de fonction, etc.) }
    ParseExpr(Res);
    ExprFlushToAX(Res);
    Exit;
  End;
  { Autres tokens : avancer }
  If CurToken.Kind <> TK_EOF Then
    ParserAdvance;
End;

{ ---- Pipeline de compilation -------------------------------- }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  DataInit;
  EmitOpen;
  EmitHeader;
  LexInit;

  { Lire le premier token }
  ParserAdvance;

  { Boucle principale de compilation }
  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
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
BEGIN
  If (ParamStr(1) = '/?') Or (ParamStr(1) = '--help') Or
     (ParamStr(1) = '-h') Or (ParamStr(1) = '/h') Or
     (ParamStr(1) = '/H') Then
  Begin
    ShowHelp;
    Halt(0);
  End;
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  ParseArgs;
  Run;
END.
