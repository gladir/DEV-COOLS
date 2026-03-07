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

  TODO 02 - LEXEUR (TOKENS KOTLIN)
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

  TODO 03 - LITTERAUX ET CONSTANTES
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

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
            TSymKind : SK_VAL, SK_VAR, SK_PARAM, SK_FUN, SK_CLASS,
              SK_OBJECT, SK_ENUM, SK_INTERFACE, SK_COMPANION, SK_PROP
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsConst, IsNullable, IsLateinit, Visibility
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
            Visibilite : public (defaut), private, protected, internal
            Smart cast : marquer le type affine apres un test is
            Qualificateurs : Package.Classe.membre -> recherche chainee

  TODO 06 - SYSTEME DE TYPES
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

  TODO 07 - EMETTEUR DE CODE ASM
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
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

  TODO 09 - VARIABLES ET AFFECTATIONS
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

  TODO 10 - EXPRESSIONS PRIMAIRES
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

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
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

  TODO 12 - ENTREES/SORTIES (println / readLine / print)
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

  TODO 13 - IF / ELSE / WHEN (EXPRESSIONS ET STATEMENTS)
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

  TODO 14 - BOUCLES : while / do-while / for / repeat
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

  TODO 15 - TABLEAUX (Array / IntArray / arrayOf)
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

  TODO 16 - CLASSES ET DATA CLASSES
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

  TODO 17 - FONCTIONS ET LAMBDAS
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

  TODO 18 - PORTEE, PILE ET CADRES
            Convention d appel : cdecl 16 bits, args empiles gauche a droite
            Prologue fonction : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Variables val/var locales : allouees sur pile [BP-offset]
            Parametres : acces [BP+offset] (apres BP sauvegarde et adresse retour)
            Portee de bloc : { } cree une nouvelle portee
              SymEnterScope a l ouverture, SymLeaveScope a la fermeture
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
  STACK_SIZE    = 1024;

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
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
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
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
{ TODO 08 - Donnees }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
{ TODO 09 - Variables }
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseDeclStmt(Const Kw : TString); Forward;
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
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  STUBS TODO 02-25
  (chaque stub sera remplace au fur et a mesure)
  ============================================================ }

{ --- TODO 02 : Lexeur --------------------------------------- }
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

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

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

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_INTEGER : Write('INT(', T.IntVal, ')');
    TK_LONG    : Write('LONG(', T.IntVal, ')');
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR(', T.Val, ')');
    TK_CHAR    : Write('CHAR(', T.Val, ')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
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
  Inc(LexColNo, 2); { sauter '/' et '*' }
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

Procedure LexScanIdent;
Var
  Start : Integer;
Begin
  Start := LexColNo;
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
    Inc(LexColNo);
  CurToken.Val := Copy(LexLine, Start, LexColNo - Start);
  If IsKeyword(CurToken.Val) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

Procedure LexScanNumber;
Var
  VCode : Integer;
Begin
  { stub - TODO 02 }
  CurToken.Kind   := TK_INTEGER;
  CurToken.Val    := '';
  CurToken.IntVal := 0;
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9')) Do
  Begin
    CurToken.Val := CurToken.Val + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  Val(CurToken.Val, CurToken.IntVal, VCode);
End;

Function LexScanEscChar : Char;
Begin
  { stub - TODO 02 }
  LexScanEscChar := '?';
  Inc(LexColNo);
End;

Procedure LexScanString;
Begin
  { stub - TODO 02 }
  CurToken.Kind := TK_STRING;
  CurToken.Val  := '';
  Inc(LexColNo); { sauter le guillemet ouvrant }
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] <> '"') Do
  Begin
    CurToken.Val := CurToken.Val + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  If LexColNo <= Length(LexLine) Then
    Inc(LexColNo); { sauter le guillemet fermant }
End;

Procedure LexScanChar;
Begin
  { stub - TODO 02 }
  CurToken.Kind := TK_CHAR;
  CurToken.Val  := '';
  Inc(LexColNo); { sauter l apostrophe ouvrante }
  If LexColNo <= Length(LexLine) Then
  Begin
    CurToken.Val := LexLine[LexColNo];
    Inc(LexColNo);
  End;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '''') Then
    Inc(LexColNo); { sauter l apostrophe fermante }
End;

Procedure LexNextToken;
Var
  Ch : Char;
Begin
  { Sauter espaces et commentaires }
  While Not LexEOF Do
  Begin
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] <= ' ') Do
      Inc(LexColNo);
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    { Commentaire // }
    If (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo] = '/') And (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexNextLine;
      Continue;
    End;
    { Commentaire imbrique }
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

  { Identificateurs et mots-cles }
  If IsIdentStart(Ch) Then
  Begin
    LexScanIdent;
    PrintToken(CurToken);
    Exit;
  End;

  { Nombres }
  If (Ch >= '0') And (Ch <= '9') Then
  Begin
    LexScanNumber;
    PrintToken(CurToken);
    Exit;
  End;

  { Chaines }
  If Ch = '"' Then
  Begin
    LexScanString;
    PrintToken(CurToken);
    Exit;
  End;

  { Caracteres }
  If Ch = '''' Then
  Begin
    LexScanChar;
    PrintToken(CurToken);
    Exit;
  End;

  { Ponctuation et operateurs (stub minimal) }
  CurToken.Val := Ch;
  Inc(LexColNo);
  If Ch In ['(', ')', '[', ']', ',', ';', '@'] Then
    CurToken.Kind := TK_PUNCT
  Else
    CurToken.Kind := TK_OP;

  PrintToken(CurToken);
End;

{ --- TODO 03 : Litteraux ----------------------------------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
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
  Res.TypeIdx := TY_IDX_UNIT;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  ExprMakeImm(AVal, TY_IDX_BOOLEAN, Res);
End;

Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  { stub - TODO 03 }
  ExprMakeImm(T.IntVal, TY_IDX_INT, Res);
End;

{ --- TODO 04 : Operateurs ---------------------------------- }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  { stub - TODO 04 }
  BinOpPrec := 0;
End;

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  { stub - TODO 04 }
  BinOpIsRight := False;
End;

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  { stub - TODO 04 }
  IsAssignOp := (Op = '=') Or (Op = '+=') Or (Op = '-=') Or
                (Op = '*=') Or (Op = '/=') Or (Op = '%=');
End;

Procedure ParsePrimary(Var Res : TExprVal);
Begin
  { stub - TODO 10 }
  ExprMakeNone(Res);
End;

Procedure ParseUnary(Var Res : TExprVal);
Begin
  { stub - TODO 10 }
  ParsePrimary(Res);
End;

Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Begin
  { stub - TODO 11 }
  ParseUnary(Res);
End;

Procedure ParseExpr(Var Res : TExprVal);
Begin
  { stub - TODO 11 }
  ParseExprPrec(0, Res);
End;

{ --- TODO 05 : Symboles ------------------------------------ }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Begin
  Case Kind Of
    SK_FUN      : SymMangle := KT_FN_PFX + Name;
    SK_CLASS    : SymMangle := KT_CLS_PFX + Name;
    SK_OBJECT   : SymMangle := KT_OBJ_PFX + Name;
    SK_ENUM     : SymMangle := KT_ENM_PFX + Name;
    SK_INTERFACE: SymMangle := KT_ITF_PFX + Name;
  Else
    SymMangle := KT_VAR_PFX + Name;
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

Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    FatalError('table des symboles pleine');
    SymAdd := -1;
    Exit;
  End;
  SymTab[SymCount].Name        := Name;
  SymTab[SymCount].MangledName := SymMangle(Name, Kind);
  SymTab[SymCount].Kind        := Kind;
  SymTab[SymCount].TypeIdx     := TypeIdx;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].Offset      := Offset;
  SymTab[SymCount].IsConst     := False;
  SymTab[SymCount].IsNullable  := False;
  SymTab[SymCount].IsLateinit  := False;
  SymTab[SymCount].Visibility  := 0;
  SymTab[SymCount].DeclLine    := CurToken.Line;
  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('profondeur de portee max atteinte')
  Else
  Begin
    ScopeStack[ScopeTop] := SymCount;
    Inc(ScopeTop);
    Inc(CurScope);
  End;
End;

Procedure SymLeaveScope;
Begin
  If ScopeTop > 0 Then
  Begin
    Dec(ScopeTop);
    SymCount := ScopeStack[ScopeTop];
    Dec(CurScope);
  End;
End;

Function SymNextOffset : Integer;
Begin
  Inc(CurFrameSize);
  SymNextOffset := CurFrameSize * 2;
End;

{ --- TODO 07 : Emetteur ASM -------------------------------- }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := KT_LBL_PFX + S;
End;

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

Procedure EmitInstr(Const Mnem : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem);
End;

Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, ' ', A1);
End;

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, ' ', A1, ', ', A2);
End;

Procedure EmitProlog;
Begin
  EmitInstr('PUSH BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP BP');
  EmitInstr('RET');
End;

{ --- TODO 06 : Types --------------------------------------- }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_INT;
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

Procedure SymInit;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
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
  EmitRaw('_TEXT   SEGMENT PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  EmitComment('-- Point d''entree : fun main() --');
  EmitLabel(KT_FN_PFX + 'main');
  EmitProlog;
  EmitBlankLine;
End;

Procedure EmitDataSeg;
Var
  I : Integer;
Begin
  EmitBlankLine;
  EmitRaw('_DATA   SEGMENT PUBLIC ''DATA''');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW ' + IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB ' + IntToStr(DataTab[I].IntVal));
      DK_STR :
        EmitRaw(DataTab[I].LblName + '  DB ''' + DataTab[I].StrVal + ''',0');
    Else
      EmitRaw(DataTab[I].LblName + '  DW 0');
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('-- Fin de programme --');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT 21h');
  EmitBlankLine;
  EmitEpilog;
  EmitRaw(KT_FN_PFX + 'main ENDP');
  EmitBlankLine;
  If RuntimeEmitted Then
    { runtime deja emis }
  Else
    EmitRuntime;
  EmitRaw('_TEXT   ENDS');
  EmitDataSeg;
  EmitRaw('        END ' + KT_FN_PFX + 'main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ --- TODO 08 : Donnees ------------------------------------- }
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

Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('=========================================================');
  EmitComment('RUNTIME MINIMAL KOTLIN86');
  EmitComment('=========================================================');
  { stub - les routines runtime seront ajoutees dans TODO 24 }
End;

{ --- TODO 09 : Variables ----------------------------------- }
Procedure ExprFlushToAX(Const E : TExprVal);
Begin
  { stub - TODO 09 }
End;

Procedure ExprStore(SIdx : Integer);
Begin
  { stub - TODO 09 }
End;

Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Begin
  { stub - TODO 09 }
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_INT;
  Res.Offset  := 0;
  Res.SymIdx  := SIdx;
End;

Procedure ParseDeclStmt(Const Kw : TString);
Begin
  { stub - TODO 09 }
End;

{ --- Stubs generaux ---------------------------------------- }
Procedure ParserAdvance;
Begin
  LexNextToken;
End;

Procedure ParseStmt;
Begin
  { stub - sera implemente dans les TODOs suivants }
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
