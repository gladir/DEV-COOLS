(* ============================================================
  JS86.PAS - Compilateur JavaScript vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Strict, Warnings)
            ParseArgs : analyser argv (script.js [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Shebang : ignorer la premiere ligne #!/usr/bin/env node si presente
            UseStrict : detecter 'use strict'; en entete -> mode strict compile
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS JAVASCRIPT)
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_TEMPLATE, TK_REGEXP, TK_IDENT, TK_KEYWORD,
              TK_OP, TK_PUNCT, TK_NEWLINE (ASI - Automatic Semicolon Insertion)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : single-quote et double-quote (\n \t \r \0 \xNN \uNNNN)
            LexScanTemplate : backtick `...${expr}...` -> sequence TK_TEMPLATE
              interpolation de ${expr} : scanner jusqu a } imbriqué
            LexScanRegexp : /pattern/flags apres = ( [ ! & | ? : , ; { return
              Distinction slash-division vs slash-regexp par contexte lexical
            Commentaires : // jusqu a fin de ligne, /* ... */ multi-lignes
            ASI (Automatic Semicolon Insertion) : insertion implicite de ;
              avant } ou apres la derniere ligne si token precedent valide
            IsKeyword : var let const function return if else
              while do for of in break continue switch case default
              new delete typeof instanceof void throw try catch finally
              class extends super import export this null undefined true false
              async await (stubs) yield (stub)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux, hexadecimaux (0x), octaux (0o), binaires (0b)
            Separateurs numeriques : 1_000_000 -> 1000000 (ES2021)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Notation scientifique : 1.5e3 -> 1500 (trunc)
            Chaines simple-quote : \\ \' \n \t \r \0 \xNN -> octet
            Chaines double-quote : idem avec \"
            Template literals : `texte ${expr} texte` -> concat runtime
              Tags de template : nwl`...` -> avertissement + traite comme `...`
            Regex litteraux : /pattern/flags -> TK_REGEXP
              flags reconnus : g i m s (autres : avertissement)
            null    : constante -> AX=0 (pointeur nul)
            undefined : constante -> AX=0 (comme null dans l impl simplifiee)
            true    : constante -> AX=1
            false   : constante -> AX=0
            NaN / Infinity : avertissement + AX=0 (non representables en 16 bits)

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques   : + - * / % ** (pow, appel _JSRT_POW)
            Concatenation   : + si l un des operandes est chaine (coercition)
            Comparaison     : == != < <= > >= (coercition de type)
            Egalite stricte : === !== (pas de coercition, comparaison directe)
            Logiques        : && || ! (court-circuit -> labels _JSL_NNNN)
            Nullish         : ?? (null/undefined-or, similaire // de Perl)
            Logiques bits   : & | ^ ~ << >> >>> (unsigned right shift -> warn)
            Ternaire        : cond ? a : b -> labels _JSL_TERN_N
            Virgule         : (a, b, c) -> evalue chaque, retourne dernier
            Optionnel       : ?. (optional chaining) -> stub + avertissement
            Assignation     : = += -= *= /= %= **= &= |= ^= <<= >>= &&= ||= ??=
            Prefixe unaire  : + (coerce nombre) - ! ~ ++ -- typeof void delete
            Suffixe unaire  : ++ -- (post-increment/decrement)
            typeof val      : retourne chaine du type -> _JSRT_TYPEOF -> AX=ptr
            void expr       : evalue expr + AX=0 (undefined)
            delete obj.key  : stub AX=1 (non pris en charge)
            in              : AX=1 si cle presente (stub pour objets)
            instanceof      : stub AX=0 + avertissement
            BinOpPrec : table de precedences Pratt adaptee a JavaScript (ECMAScript)

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR (var), SC_LET, SC_CONST_JS, SC_PARAM,
              SC_FUNCTION, SC_CLASS, SC_LABEL
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              IsHoisted (var), IsConst, IsParam
            SymAdd, SymFind, SymFindCat, SymMangle
            Hoisting : var declarations hissees en sommet de fonction
              Scan pre-passe de la fonction pour collecter les var
              let/const : portee de bloc (block-scoped) -> SymEnterScope/SymLeaveScope
            CurScope : compteur de portee imbriquee (max SCOPE_MAX)
            TempReg : allocation de registres temporaires (AX BX CX DX)
              convention : AX = valeur de retour d expression
            use strict : interdire var non declare + TK_IDENT non resolu -> erreur
            LabelTab : table des labels de boucle pour break/continue etiquetes

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TKJ_NUMBER (entier 16 bits signe), TKJ_STRING (ptr),
              TKJ_BOOLEAN (0/1 dans AX), TKJ_OBJECT (ptr struct DATA),
              TKJ_ARRAY (ptr bloc DATA avec entete count), TKJ_FUNCTION (ptr code),
              TKJ_NULL, TKJ_UNDEFINED, TKJ_UNKNOWN (polymorphe -> warn)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : number=2o, ptr=2o (string/object/array/function)
            Coercition de type a la compilation (quand types connus) :
              number + string -> concat (appel _JSRT_NUMTOSTR + _JSRT_CONCAT)
              boolean en contexte numerique -> AX tel quel (0 ou 1)
              null/undefined en contexte numerique -> AX=0
            TypeMangle : prefixe du type pour les labels ASM (_JSN_ _JSS_ _JSA_ ...)
            JS_UNDEF_PTR : etiquette DATA speciale pointant vers chaine "undefined"

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _JSL_NNNNN)
            Prefixes : _JSV_ (variable), _JSF_ (function), _JSK_ (chaine const),
              _JSRT_ (runtime), _JSL_ (label), _JSO_ (objet literal DATA),
              _JSA_ (tableau literal DATA), _JSC_ (classe prototype)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitCoerce : emission de code de coercition selon types connus

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_OBJ),
              IntVal, StrVal, ElemCount, PropCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddObj, DataAddArr : variantes d ajout
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Chaines litterales -> entree DK_STR (terminateur 0)
            var/let/const globaux : entrees DK_WORD dans DataTab
            const : entrees DK_WORD ou DK_STR (immuables a la compilation)
            Objets litteraux globaux : bloc contigu cle1 val1 cle2 val2 0 dans DATA
            Tableaux litteraux globaux : DW count, DW e0, DW e1, ... dans DATA
            _JS_UNDEF : DB 'undefined',0 -- _JS_NULL_S : DB 'null',0
            _JS_TRUE_S : DB 'true',0    -- _JS_FALSE_S : DB 'false',0
            _JSRT_STRBUF[0..511] : buffer de travail pour concatenation / coercition

  TODO 09 - VARIABLES ET AFFECTATIONS
            var $var : hoiste en sommet de fonction, alloue sur pile (SUB SP,2)
              Premiere affectation = initialisation ; sinon MOV [BP-n], AX
            let $var : alloue sur pile a la portee de bloc courante
            const $var : alloue sur pile, marque IsConst (erreur si reassignation)
            Affectation simple : var = expr -> ExprLoad + MOV [BP-n], AX
            Operateurs composes : += -= *= etc. -> load / op / store
            Destructuration de tableau : let [a, b] = arr -> acces par index
              Elements manquants -> AX=0 (undefined) ; spread ... -> stub
            Destructuration d objet : let {x, y} = obj -> acces par cle compilee
              Alias : let {x: alias} = obj -> store sous alias
            Affectation en chaine : a = b = expr -> associatif droite
            Affectation avec optionnel : a ??= expr -> si a null/undef alors expr

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal nombre, literal chaine, template, ident,
              this -> avertissement + XOR AX,AX (contexte global = 0)
              null -> XOR AX,AX
              undefined -> XOR AX,AX
              true -> MOV AX,1   false -> XOR AX,AX
              new Ctor(args) -> CALL _JSRT_NEW + CALL _JSF_Ctor -> AX=ptr
              typeof expr -> CALL _JSRT_TYPEOF -> AX=ptr chaine type
              void expr -> evalue expr, XOR AX,AX
              delete expr -> stub AX=1
            Tableau litteral : [e0, e1, e2] -> DataAdd DK_ARRAY ou inline pile
            Objet litteral : {k:v, ...} -> DataAdd DK_OBJ ou inline pile
            Spread : ...arr dans tableau/objet -> stub + avertissement
            Groupement parenthese : (expr) et operateur virgule (a, b)
            Appel de fonction : nom(args) ou expr(args) -> CALL ou CALL AX
            ExprMakeImm, ExprMakeNull, ExprMakeUndef : constructeurs TExprVal

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
            ParseExprPrec(MinPrec) : boucle Pratt complete
            ExprEmitBinOp : ADD/SUB/IMUL/IDIV/REM, CMP+SETcc, AND/OR/XOR
            Concatenation + : detection type chaine -> CALL _JSRT_CONCAT
            Puissance ** : CALL _JSRT_POW(AX=base, BX=exp) -> AX
            Egalite stricte === : CMP + SETE (meme type requis, warn si inconnu)
            Inegalite stricte !== : CMP + SETNE
            Operateur ?? : TEST AX,AX + JNZ skip (null/undefined-or)
            Court-circuit && : JZ vers false-branch, || : JNZ vers true-branch
            Ternaire ? : -> labels _JSL_TERNF_N / _JSL_TERNE_N
            Operateur in : stub -> MOV AX,0 + avertissement
            instanceof : stub -> MOV AX,0 + avertissement
            Virgule : evalue gauche (resultat ignore), retourne droite
            Optionnel ?. : stub -> copy AX + avertissement

  TODO 12 - CONSOLE / PROCESS / SORTIES
            console.log(args)   : affiche chaque arg converti en chaine + \n
              Detection du type compile -> _JSRT_NUMTOSTR ou chaine directe
              Separateur ' ' entre arguments ; \n final
              -> INT 21h AH=40h BX=1 (STDOUT)
            console.error(args) : idem -> BX=2 (STDERR)
            console.warn(args)  : idem -> BX=2 avec prefixe 'Warning: '
            process.exit(code)  : -> MOV AX,4C00h + code + INT 21h
            process.stdout.write(s) : -> INT 21h AH=40h BX=1 sans \n final
            process.stderr.write(s) : -> INT 21h AH=40h BX=2
            alert(s)            : stub -> console.log (environnement DOS)
            prompt(s)           : stub -> XOR AX,AX + avertissement
            Format simplifie de console.log :
              %d -> _JSRT_NUMTOSTR  %s -> chaine directe  %o -> stub

  TODO 13 - IF / ELSE IF / ELSE + SWITCH / CASE / DEFAULT
            ParseIfStmt : if (cond) stmt_ou_bloc [else if ...] [else bloc]
              Condition verite JS : 0, '', null, undefined, NaN, false = faux
              Emission TEST AX,AX / JZ pour falsy values numeriques
              CALL _JSRT_STRTRUTHY pour chaines (AX=ptr) -> AX=0|1
            Labels : _JSL_ELIF_N, _JSL_ELSE_N, _JSL_ENDIF_N
            ParseSwitchStmt : switch (expr) { case v: stmts break; ... default: }
              Calcul de l expression switch -> PUSH AX
              Chaque case : POP BX / CMP BX,valeur / JE _JSL_CASE_N
              break -> JMP _JSL_SWEND_N
              Fallthrough : absence de break -> continuer execution
              default : label apres tous les cases, JMP depuis echecs
            Modificateurs de statement : expr if cond (non supporte en JS -> erreur)

  TODO 14 - BOUCLES : while / do-while / for / for-of / for-in
            ParseWhileStmt : while (cond) stmt_ou_bloc
              Labels : _JSL_WTEST_N, _JSL_WEND_N
            ParseDoWhileStmt : do stmt_ou_bloc while (cond) ;
              Labels : _JSL_DOBEG_N, _JSL_DOTEST_N
            ParseForStmt : for (init ; cond ; incr) stmt_ou_bloc
              init : var/let/const decl ou expr ou vide
              Labels : _JSL_FTEST_N, _JSL_FINCR_N, _JSL_FEND_N
            ParseForOfStmt : for (let v of arr) stmt_ou_bloc
              Tableaux uniquement : boucle index 0..count-1, charge elem
              Chaines : iteration sur octets -> AX = char code
              Autres iterables : avertissement + skip
            ParseForInStmt : for (let k in obj) stmt_ou_bloc
              Objets litteraux : iteration sur les cles compilees (constantes)
              Avertissement si objet dynamique (non supporte)
            LoopPush / LoopPop : pile de labels break/continue
            break [label] -> JMP _JSL_END_N ; continue [label] -> JMP _JSL_INCR_N
            Labels de boucle nommes : OUTER: for (...) { ... break OUTER; }

  TODO 15 - TABLEAUX (Array)
            Declaration : let arr = [e0, e1, e2] ; let arr = new Array(n)
            Representation memoire : [count:word] [e0:word] [e1:word] ...
              Taille fixe a la compilation (MAX_ARR_ELEM = 64 par defaut)
            Acces arr[i] (i constant) : offset = 2 + i*2, MOV AX,[BX+SI]
            Acces arr[i] (i variable) : SHL AX,1 / ADD AX,2 / MOV SI,AX / MOV AX,[BX+SI]
            Acces arr[-1] : index negatif -> count+index (si connu a compile)
            Affectation arr[i] = expr : calcul offset + MOV [BX+SI],AX
            Methodes Array inline :
              arr.push(v)    -> CALL _JSRT_ARRPUSH(SI=ptr, AX=val)
              arr.pop()      -> CALL _JSRT_ARRPOP(SI=ptr) -> AX=val
              arr.shift()    -> CALL _JSRT_ARRSHIFT(SI=ptr) -> AX=val
              arr.unshift(v) -> CALL _JSRT_ARRUNSHIFT(SI=ptr, AX=val)
              arr.length     -> MOV AX,[SI] (premier word = count)
              arr.indexOf(v) -> CALL _JSRT_ARRIDXOF(SI=ptr, BX=val) -> AX
              arr.join(sep)  -> CALL _JSRT_ARRJOIN(SI=ptr, DI=sep) -> AX=ptr
              arr.reverse()  -> CALL _JSRT_ARRREV(SI=ptr)
              arr.slice(a,b) -> stub AX=ptr arr original + avertissement
              arr.sort()     -> CALL _JSRT_ARRSORT(SI=ptr) tri numerique ASC
              arr.forEach(f) -> boucle inline CALL _JSF_f pour chaque element
              arr.map/filter -> stub AX=ptr original + avertissement
            Spread dans tableau : [...a, ...b] -> stub + avertissement

  TODO 16 - OBJETS LITTERAUX ET ACCES PROPRIETES
            Objet litteral : {k1: v1, k2: v2} -> bloc DATA cle/valeur paire
              Cles constantes (chaines) : emises en DATA, offset precompile
              Cles dynamiques ([expr]: val) : avertissement + ignore
            Representation memoire objet fixe :
              [n_props:word] [kptr0:word] [vptr0:word] [kptr1:word] [vptr1:word] ...
            Acces obj.prop (prop constante) : CALL _JSRT_OBJGET(BX=ptr, DI=kptr)
            Acces obj[expr] (cle variable) : CALL _JSRT_OBJGET(BX=ptr, SI=expr)
            Affectation obj.prop = val : CALL _JSRT_OBJSET(BX=ptr, DI=kptr, AX=val)
            Methodes Object :
              Object.keys(obj)   -> CALL _JSRT_OBJKEYS(BX=ptr) -> AX=arr ptr
              Object.assign(d,s) -> CALL _JSRT_OBJASSIGN(BX=d, SI=s)
              Object.create(p)   -> CALL _JSRT_OBJCREATE(BX=proto) -> AX=ptr
            Prototype chain (simplifiee) : chaque objet porte [proto:word]
              Recherche propriete : obj courant puis prototype -> _JSRT_OBJGET
            Spread dans objet : {...a, ...b} -> stub + avertissement
            Methodes de l objet (shorthand) : { fn() {} } -> _JSRT_OBJSET + ptr fn

  TODO 17 - FONCTIONS (function / arrow / return)
            ParseFuncDecl : function nom(params) { bloc }
              Hoisting : declarations hissees en debut du scope courant
              CurFnName, CurFnRetLbl : nom et label de retour courants
            ParseArrowFunc : (params) => expr ou (params) => { bloc }
              Forme courte : (x) => x+1 -> retour automatique de l expression
              Fermeture : capture des variables du scope parent par adresse
              Emission comme function anonyme : label _JSF_ANON_N
            ParseFuncExpr : let f = function(params) { bloc } -> ptr code
            Parametres :
              Valeurs par defaut : function f(x=42) -> TEST de AX sur pile
              Rest params : function f(...args) -> stub + avertissement
            Valeur de retour : return expr; -> MOV dans AX, JMP _JSL_RET_N
              Absence de return -> AX=0 (undefined implicite)
            Appel : nom(args) -> PUSH args de droite a gauche + CALL _JSF_nom
              Expression : f(args) -> CALL AX (pointeur de fonction)
              Methode : obj.method(args) -> charge ptr + CALL AX (this ignore)
            ParseCallArgs : empilement des arguments sur la pile (cdecl 16 bits)
            Fonctions d ordre superieur (callback) : CALL AX apres push args
            Arguments object : non implemente -> warn si 'arguments' utilise
            Generateurs / async-await : stubs + avertissements

  TODO 18 - PORTEE, PILE ET CADRES
            Convention d appel : cdecl 16 bits, args de gauche a droite sur pile
            Prologue fonction : PUSH BP / MOV BP,SP
            Epilogue : MOV SP,BP / POP BP / RET (cdecl : appelant nettoie pile)
            Variables var : hoistees, allouees au prologue (SUB SP, total*2)
            Variables let/const : allouees a la portee de bloc (SUB SP,2 a l entree)
            Fermeture de portee de bloc : ADD SP,n*2
            Closures (approximation) : variables capturees allouees sur le heap
              Simulation : cellule DK_WORD dans DATA pour chaque var capturee
              Avertissement si closure profonde (>1 niveau) non supportee
            this : toujours XOR AX,AX en contexte global (DOS n a pas de this)
            Sauvegarde registres : SI, DI preserves dans chaque fonction
            CurFrameSize : taille courante du cadre local (nb de words)
            MaxCallDepth : avertissement si recursion > CALL_DEPTH_WARN niveaux

  TODO 19 - EXPRESSIONS REGULIERES (RegExp basique)
            LexScanRegexp : /pattern/flags apres operateur de test
            TK_REGEXP : Val = pattern + Chr(1) + flags
            Methodes RegExp :
              re.test(str)  -> CALL _JSRT_REMATCH(SI=str, DI=pat) -> AX=0|1
              re.exec(str)  -> CALL _JSRT_REEXEC(SI=str, DI=pat) -> AX=arr|null
              str.match(re) -> CALL _JSRT_REMATCH -> AX=0|1 (simplifie)
              str.search(re)-> CALL _JSRT_REINDEX -> AX=pos|-1
              str.replace(re,repl) -> CALL _JSRT_RESUB(SI,DI,BX) -> AX=ptr
              str.split(re) -> stub AX=arr_vide + avertissement
            Instance RegExp : new RegExp(pat, flags)
              -> pat et flags comme chaines litterales -> TK_REGEXP synthetique
            Flags reconnus : g (global repeat -> boucle), i (case-insensitive -> warn)
              m s u : avertissement + ignore
            Support minimal : pattern fixe (chaine litterale sans metacaracteres)
            Metacaracteres . ^ $ * + ? [ ] { } \ | ( ) : avertissement compile
            Captures (/(\w+)/) : non supportees -> avertissement
            _JSCAP_1 .. _JSCAP_9 : DW 0 dans DATA (stubs)

  TODO 20 - METHODES NATIVES (String / Number / Array / Math)
            Methodes String (appelees sur AX=ptr chaine) :
              s.length       -> CALL _JSRT_STRLEN(SI=AX) -> AX
              s.indexOf(sub) -> CALL _JSRT_STRINDEXOF(SI=AX,DI=sub) -> AX
              s.lastIndexOf  -> CALL _JSRT_STRLASTIDX -> AX
              s.includes(sub)-> CALL _JSRT_STRINDEXOF -> AX != -1 -> bool
              s.startsWith   -> CALL _JSRT_STRSTARTW -> AX
              s.endsWith     -> CALL _JSRT_STRENDW -> AX
              s.slice(a,b)   -> CALL _JSRT_STRSLICE(SI,BX,CX) -> AX=ptr buf
              s.substring    -> idem _JSRT_STRSLICE (indices absolus)
              s.toUpperCase  -> CALL _JSRT_STRTOUPPER(SI=AX) -> AX=buf
              s.toLowerCase  -> CALL _JSRT_STRTOLOWER(SI=AX) -> AX=buf
              s.trim()       -> CALL _JSRT_STRTRIM -> AX=buf
              s.split(sep)   -> CALL _JSRT_STRSPLIT(SI,DI) -> AX=arr ptr
              s.replace(a,b) -> CALL _JSRT_STRRPLS(SI,DI,BX) -> AX=buf
              s.charAt(i)    -> CALL _JSRT_STRCHAR(SI,CX) -> AX=ptr char
              s.charCodeAt(i)-> CALL _JSRT_STRORD(SI,CX) -> AX=code
              s.repeat(n)    -> CALL _JSRT_STRREPEAT(DI=buf,SI,CX) -> AX=buf
              s.padStart(n,c)-> CALL _JSRT_STRPADS -> AX=buf
              String.fromCharCode(n) -> CALL _JSRT_CHR -> AX=ptr
            Methodes Number :
              Number(s)       -> CALL _JSRT_STRTONUM(SI=AX) -> AX
              parseInt(s,r)   -> CALL _JSRT_STRTOINT(SI,CX=radix) -> AX
              parseFloat(s)   -> CALL _JSRT_STRTOINT (trunc) -> AX
              Number.isInteger(n) -> MOV AX,1 (tous les nombres sont entiers)
              isNaN(v)        -> XOR AX,AX (jamais NaN en 16 bits entier)
              isFinite(v)     -> MOV AX,1
            Objet Math :
              Math.abs(n)    -> CALL _JSRT_ABS -> AX
              Math.max(a,b)  -> CMP + CMOVG (ou branchement) -> AX
              Math.min(a,b)  -> CMP + CMOVL -> AX
              Math.floor(n)  -> pass-through (entier)
              Math.ceil(n)   -> pass-through
              Math.round(n)  -> pass-through
              Math.pow(a,b)  -> CALL _JSRT_POW -> AX
              Math.sqrt(n)   -> CALL _JSRT_SQRT (Newton-Raphson entier) -> AX
              Math.random()  -> CALL _JSRT_RAND (LCG 16 bits) -> AX
              Math.PI        -> DW 3 (troncature, avec avertissement)
              Math.trunc/sign-> CALL _JSRT_TRUNC / _JSRT_SIGN -> AX
            JSON.stringify(v)-> CALL _JSRT_JSONSTR -> AX=ptr (simplifie)
            JSON.parse(s)    -> stub AX=0 + avertissement

  TODO 21 - CLASSES ET HERITAGE (basique)
            ParseClassDecl : class Nom [extends Parent] { corps }
              CurClassName : nom de classe courante pendant la compilation
              Emission : label _JSC_Nom + zone prototype dans DATA
            Corps de classe :
              constructor(params) { bloc } -> _JSF_Nom_ctor PROC NEAR
              method(params) { bloc } -> _JSF_Nom_method PROC NEAR
              Methodes statiques : static m() -> _JSF_Nom_S_m PROC NEAR
              Getters / Setters : get prop() / set prop(v) -> stubs
              Champs publics : x = val -> init dans constructeur
              Champs prives : #x = val -> masquage par prefixe (stub)
            new Nom(args) :
              CALL _JSRT_OBJCREATE(BX=ptr proto Nom) -> AX=ptr
              PUSH AX (this sur pile) + CALL _JSF_Nom_ctor
              Retour : AX=ptr objet cree
            this dans methode : BX = ptr objet (passe en premier arg cache)
            extends Parent :
              Proto de Nom pointe vers proto de Parent
              super() dans constructeur -> CALL _JSF_Parent_ctor
              super.method() -> CALL _JSF_Parent_method
            Chaine de prototypes : 2 niveaux MAX (Object a la racine)
            instanceof : CMP proto ptrs -> AX=0|1

  TODO 22 - CLOSURES ET REFERENCES
            Analyse de capture en pre-passe :
              Walker AST simplifie : reperer les identifiants libres dans une fn
              Pour chaque var capturee : allouer une cellule DK_WORD dans DATA
              Marquer IsCapture dans TSymRec
            Emission :
              Variable capturee en lecture : MOV AX, [_JSV_nom_cap]
              Variable capturee en ecriture : MOV [_JSV_nom_cap], AX
              Fermeture multiple : partage de la meme cellule DATA
            Environnement de fermeture (approximation) :
              Structure { cap0:word, cap1:word, ... } dans DATA par fn
              Chaque appel de la fermeture lit/ecrit la structure partagee
            Fonctions imbriquees : avertissement si plus de 2 niveaux
            Fonctions retournees : ptr code dans AX, fermeture via DATA
            this capture (arrow function) : this = 0 (contexte global DOS)
            Operateur de reference :
              &ident -> adresse d une fonction -> ptr code dans DATA/TEXT
              Appel indirect -> CALL AX
            Variables par reference (simulation) :
              Passage par adresse : LEA AX,[BP-n] -> MOV [dernier param], AX
              Lecture deref : MOV BX,AX / MOV AX,[BX]

  TODO 23 - EXCEPTIONS : try / catch / finally / throw
            ParseTryStmt : try { bloc } [catch (e) { bloc }] [finally { bloc }]
              Emission sans OS support :
              Vecteur d exception : _JSX_HANDLER DW 0 dans DATA
                (pointeur vers le gestionnaire catch courant)
              try block : MOV [_JSX_HANDLER], OFFSET _JSL_CATCH_N
                Execution du bloc ; si terminaison normale JMP _JSL_TRY_OK_N
              catch (e) : label _JSL_CATCH_N :
                AX = pointeur vers l objet erreur (chaine ou objet Error)
                Affectation a la variable e : MOV [BP-n], AX
                Execution du bloc catch
              finally : label _JSL_FINALLY_N :
                Toujours execute (normal + exception)
                Emission apres try-ok et apres catch
              Restauration du handler : MOV [_JSX_HANDLER], ancien_handler
            throw expr :
              AX = ptr objet erreur (chaine ou new Error(...))
              CMP WORD PTR [_JSX_HANDLER], 0 / JZ _JSL_UNHANDLED
              MOV BX, [_JSX_HANDLER] / JMP BX
              _JSL_UNHANDLED : affiche 'Uncaught: ' + msg + \n puis INT 21h 4C01h
            new Error(msg) :
              CALL _JSRT_MKERROR(SI=msg) -> AX=ptr struct {type:ptr, msg:ptr}
            Types d erreur supplémentaires :
              TypeError / RangeError / SyntaxError -> stub = new Error
            Erreurs natives :
              Division par zero -> JZ avant IDIV + throw _JS_ERR_DIV0
              Index hors bornes -> CALL _JSRT_CHKIDX + throw si besoin

  TODO 24 - RUNTIME MINIMAL
            _JSRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _JSRT_PRINTLN : _JSRT_PRINT + CR+LF via _JS_CRLF DB 13,10,0
            _JSRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX et CX
            _JSRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _JSRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _JSRT_CONCAT(DI=dst, SI=src) : strcat (src apres dst)
            _JSRT_STRREPEAT(DI=dst, SI=src, CX=n) : repete n fois
            _JSRT_TYPEOF(AX=val, BX=typeidx) : -> AX=ptr chaine type
            _JSRT_TRUTHY(AX=val, BX=typeidx) : -> AX=0|1 (falsy/truthy)
            _JSRT_STRTRUTHY(SI=ptr) : chaine -> AX=1 sauf '' et '0'
            _JSRT_REMATCH(SI=str, DI=pat) : strstr basique -> AX=0|1
            _JSRT_RESUB(SI=str, DI=pat, BX=repl) : substitution 1ere occ
            _JSRT_ABS(AX=n) : valeur absolue -> AX
            _JSRT_POW(AX=base, BX=exp) : puissance entiere -> AX
            _JSRT_SQRT(AX=n) : racine carree entiere (Newton) -> AX
            _JSRT_RAND : LCG 16 bits -> AX (graine _JSRT_SEED DW 1)
            _JSRT_OBJCREATE(BX=proto) : alloue objet vide -> AX=ptr
            _JSRT_OBJGET(BX=obj, DI=kptr) : cherche propriete -> AX=val
            _JSRT_OBJSET(BX=obj, DI=kptr, AX=val) : ecriture propriete
            _JSRT_ARRPUSH / ARRPOP / ARRSHIFT / ARRUNSHIFT : operations tableau
            _JSRT_ARRSORT(SI=ptr) : tri a bulles numerique in-place
            _JSRT_JSONSTR(AX=val, BX=typeidx) : serialisation simple -> ptr
            _JSRT_MKERROR(SI=msg) : alloue struct Error -> AX=ptr
            _JSRT_PANIC(SI=msg) : affiche + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _JS_HEAP DB 4096 DUP(0) + _JS_HEAPTOP DW 0
              _JSRT_ALLOC(CX=nb_bytes) -> AX=ptr dans le heap statique

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _JSF_main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseStmt loop ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _JSF_main
            Fichiers SAMPLES\JS\ a creer :
              hello.js    (console.log, var/let/const, +, template literals)
              math.js     (fonctions, recursion, return, Math.abs/pow)
              control.js  (if/else if, switch/case, while, for, for-of)
              arrays.js   (tableaux, push/pop, forEach, sort, indexOf)
              objects.js  (objets litteraux, acces proprietes, Object.keys)
              classes.js  (class, constructor, extends, super, new)
            Smoke tests : JS86.EXE -v SAMPLES\JS\*.js

  ============================================================ *)

{ ============================================================
  JS86 - Compilateur JavaScript -> assembleur 8086
  Version : 1.0  Date : 2026-03-05
  Compilation : ppc386 -O2 -Mtp JS86.PAS
  ============================================================ }

Program JS86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Begin
  { TODO 01 : point d entree a implementer }
End.
