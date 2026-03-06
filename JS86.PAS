(* ============================================================
  JS86.PAS - Compilateur JavaScript vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Strict, Warnings)
            ParseArgs : analyser argv (script.js [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Shebang : ignorer la premiere ligne #!/usr/bin/env node si presente
            UseStrict : detecter 'use strict'; en entete -> mode strict compile
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS JAVASCRIPT) [IMPLEMENTE]
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

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
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

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  JS86_VERSION = '1.0';
  JS86_DATE    = '2026-03-05';

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
  MAX_OBJ_PROP  = 16;   { proprietes max par objet literal inline }
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  JS_VAR_PFX  = '_JSV_';    { variable scalaire / objet / tableau }
  JS_FN_PFX   = '_JSF_';    { fonction / methode                  }
  JS_STR_PFX  = '_JSK_';    { constante chaine litterale          }
  JS_RT_PFX   = '_JSRT_';   { routine runtime                     }
  JS_LBL_PFX  = '_JSL_';    { label de saut interne               }
  JS_OBJ_PFX  = '_JSO_';    { objet literal DATA                  }
  JS_ARR_PFX  = '_JSA_';    { tableau literal DATA                }
  JS_CLS_PFX  = '_JSC_';    { classe / prototype                  }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs JavaScript }
  TY_IDX_NUMBER   = 0;  { entier 16 bits signe  }
  TY_IDX_STRING   = 1;  { pointeur chaine DATA  }
  TY_IDX_BOOLEAN  = 2;  { 0 ou 1 dans AX        }
  TY_IDX_OBJECT   = 3;  { pointeur struct DATA   }
  TY_IDX_ARRAY    = 4;  { pointeur bloc DATA     }
  TY_IDX_FUNCTION = 5;  { pointeur de code       }
  TY_IDX_NULL     = 6;  { AX=0                   }
  TY_IDX_UNDEF    = 7;  { AX=0 (undefined)       }
  TY_PRIM_COUNT   = 8;
  TY_UNKNOWN      = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.js)                  }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Strict    : Boolean;   { -s ou 'use strict' detecte           }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens JavaScript (TODO 02) ----------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_INTEGER,   { literal entier 42 0xFF 0b101 0o17      }
    TK_FLOAT,     { literal flottant 3.14 1.5e3            }
    TK_STRING,    { literal chaine simple ou double quote  }
    TK_TEMPLATE,  { template literal backtick-dollar-brace }
    TK_REGEXP,    { expression reguliere /pat/flags        }
    TK_IDENT,     { identificateur (non-mot-cle)           }
    TK_KEYWORD,   { mot-cle JS reconnu                     }
    TK_OP,        { operateur + - * / === !==  etc.        }
    TK_PUNCT      { ponctuation ; , ( ) [ ] accolades        }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute          }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)     }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)     }
    Line     : Integer;     { ligne source (1-base)           }
    Col      : Integer;     { colonne source (1-base)         }
  End;

  { ---- Categories de symboles (TODO 05) ------------------ }
  TSymCat = (
    SC_VAR,        { var (hoist)                      }
    SC_LET,        { let (block-scope)                }
    SC_CONST_JS,   { const (block-scope, immutable)   }
    SC_PARAM,      { parametre formel de fonction      }
    SC_FUNCTION,   { declaration function             }
    SC_CLASS,      { declaration class                }
    SC_LABEL       { label de boucle etiquetee        }
  );

  TSymRec = Record
    Name        : TString;   { identifiant JS                  }
    MangledName : TString;   { _JSV_nom / _JSF_nom             }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux              }
    IsHoisted   : Boolean;   { var : hisse au sommet fn        }
    IsConst     : Boolean;   { const : erreur si reassigne     }
    IsParam     : Boolean;   { parametre de fonction           }
    IsCapture   : Boolean;   { variable capturee par closure   }
    DeclLine    : Integer;
  End;

  { ---- Types internes (TODO 06) -------------------------- }
  TTypeKind = (
    TKJ_NUMBER,
    TKJ_STRING,
    TKJ_BOOLEAN,
    TKJ_OBJECT,
    TKJ_ARRAY,
    TKJ_FUNCTION,
    TKJ_NULL,
    TKJ_UNDEFINED,
    TKJ_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : number=2, ptr=2 }
  End;

  { ---- Valeurs d'expression (TODO 11) -------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur            }
    EK_IMM,    { immediate dans ImmVal           }
    EK_AX,     { valeur dans AX                  }
    EK_MEM     { adresse [BP+Offset] ou [_JSV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  { ---- Segment de donnees (TODO 08) ---------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_OBJ_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_ARRAY_BLK : nb elements, DK_OBJ_BLK : nb props }
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
  LexSrcF        : Text;
  LexLine        : String;
  LexLineNo      : Integer;
  LexColNo       : Integer;
  LexEOF         : Boolean;
  LexOpened      : Boolean;
  CurToken       : TToken;
  LexExpectRegex : Boolean;  { True apres = ( [ ! & | ? : , ; return }
  LexASIFlag     : Boolean;  { True si ASI doit etre insere avant }
  LexPrevKind    : TTokenKind; { type du token precedent pour ASI }
  LexPrevVal     : TString;    { valeur du token precedent pour ASI }

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
  CurClassName : TString;    { nom de la classe courante (TODO 21)  }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees (TODO 08) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;
  GKwConsumed    : Boolean;  { mot-cle deja consomme avant ParseStmt }
  GCallArgCount  : Integer;  { nb args du dernier ParseCallArgs      }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexNextLine;         Forward;
Procedure LexCheckASI;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString(Quote : Char); Forward;
Procedure LexScanTemplate;     Forward;
Procedure LexScanRegexp;       Forward;
Procedure LexNextToken;        Forward;
{ TODO 03 }
Function  LexRegexpFlagOk(Ch : Char) : Boolean; Forward;
Procedure LexCheckTagTemplate; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeNull(Var Res : TExprVal); Forward;
Procedure ExprMakeUndef(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure EmitOpen;            Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d'erreur et d'avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('JS86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    { Supprimer le fichier de sortie partiel }
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

Procedure CompileError(Const Msg : TString);
Begin
  Write('JS86:');
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
  Write('JS86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('JS86 v', JS86_VERSION, ' (', JS86_DATE, ')');
  WriteLn('Compilateur JavaScript -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: JS86 <source.js> [sortie.asm] [-v] [-d] [-w] [-s]');
  WriteLn;
  WriteLn('  source.js  : fichier JavaScript source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn('  -s         : mode strict (equivalent ''use strict'')');
  WriteLn;
  Halt(EXIT_USAGE);
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

Function StrReplace(Const S, Old, New : TString) : TString;
Var
  P   : Integer;
  Res : TString;
Begin
  Res := S;
  P := Pos(Old, Res);
  While P > 0 Do
  Begin
    Delete(Res, P, Length(Old));
    Insert(New, Res, P);
    P := Pos(Old, Res);
  End;
  StrReplace := Res;
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

{ Extrait le nom de base d'un chemin (sans extension) }
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

{ Replace extension d'un chemin }
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

{ ---- Initialisation des options ----------------------------- }

Procedure InitOptions;
Begin
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugMode := False;
  Opts.Strict   := False;
  Opts.Warnings := False;
End;

{ ---- Analyse des arguments de la ligne de commande --------- }

Procedure ParseArgs;
Var
  I     : Integer;
  Arg   : TString;
  ALow  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage;

  For I := 1 To ParamCount Do
  Begin
    Arg  := ParamStr(I);
    ALow := StrLowerCase(Arg);

    If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-s' Then
      Opts.Strict := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('JS86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('JS86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('JS86: fichier source manquant');
    ShowUsage;
  End;

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
  LexExpectRegex := False;
  LexASIFlag     := False;
  LexPrevKind    := TK_EOF;
  LexPrevVal     := '';
  CurFnDepth     := 0;
  CurFnRetLbl    := '';
  CurFnName      := '';
  CurClassName   := '';
  LoopTop        := 0;
  RuntimeEmitted := False;
  GKwConsumed    := False;
  GCallArgCount  := 0;
  CurFrameSize   := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS JAVASCRIPT)
  [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle JavaScript ------ }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'var')       Or (S = 'let')       Or (S = 'const')      Or
    (S = 'function')  Or (S = 'return')    Or (S = 'if')         Or
    (S = 'else')      Or (S = 'while')     Or (S = 'do')         Or
    (S = 'for')       Or (S = 'of')        Or (S = 'in')         Or
    (S = 'break')     Or (S = 'continue')  Or (S = 'switch')     Or
    (S = 'case')      Or (S = 'default')   Or (S = 'new')        Or
    (S = 'delete')    Or (S = 'typeof')    Or (S = 'instanceof') Or
    (S = 'void')      Or (S = 'throw')     Or (S = 'try')        Or
    (S = 'catch')     Or (S = 'finally')   Or (S = 'class')      Or
    (S = 'extends')   Or (S = 'super')     Or (S = 'import')     Or
    (S = 'export')    Or (S = 'this')      Or (S = 'null')       Or
    (S = 'undefined') Or (S = 'true')      Or (S = 'false')      Or
    (S = 'async')     Or (S = 'await')     Or (S = 'yield')      Or
    (S = 'debugger')  Or (S = 'with')      Or (S = 'static')     Or
    (S = 'get')       Or (S = 'set');
End;

{ ---- PrintToken : affichage debug d'un token --------------- }
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF      : Write('EOF');
    TK_INTEGER  : Write('INT(', T.IntVal, ')');
    TK_FLOAT    : Write('FLOAT(', T.Val, ')');
    TK_STRING   : Write('STR(', T.Val, ')');
    TK_TEMPLATE : Write('TMPL(', T.Val, ')');
    TK_REGEXP   : Write('RE(', StrReplace(T.Val, Chr(1), '|'), ')');
    TK_IDENT    : Write('IDENT(', T.Val, ')');
    TK_KEYWORD  : Write('KW(', T.Val, ')');
    TK_OP       : Write('OP(', T.Val, ')');
    TK_PUNCT    : Write('PUNCT(', T.Val, ')');
  End;
  WriteLn;
End;

{ ---- LexNextLine : lire la prochaine ligne source ----------- }
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

{ ---- LexCheckASI : faut-il inserer un ';' apres ce saut ? -- }
Procedure LexCheckASI;
Begin
  LexASIFlag := False;
  Case LexPrevKind Of
    TK_INTEGER, TK_FLOAT, TK_STRING, TK_TEMPLATE, TK_REGEXP, TK_IDENT :
      LexASIFlag := True;
    TK_KEYWORD :
      If (LexPrevVal = 'return')    Or (LexPrevVal = 'break')     Or
         (LexPrevVal = 'continue')  Or (LexPrevVal = 'throw')     Or
         (LexPrevVal = 'this')      Or (LexPrevVal = 'null')      Or
         (LexPrevVal = 'undefined') Or (LexPrevVal = 'true')      Or
         (LexPrevVal = 'false')     Or (LexPrevVal = 'super') Then
        LexASIFlag := True;
    TK_OP :
      If (LexPrevVal = '++') Or (LexPrevVal = '--') Then
        LexASIFlag := True;
    TK_PUNCT :
      If (LexPrevVal = ')') Or (LexPrevVal = ']') Then
        LexASIFlag := True;
  End;
End;

{ ---- LexSkipBlockComment : sauter le commentaire /* ... */ -- }
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter '/' et '*' }
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      Done := True;
    End
    Else
      Inc(LexColNo);
  End;
End;

{ ---- Fonctions de test sur les caracteres ------------------- }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_') Or (Ch = '$');
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

{ ---- LexScanIdent : scanner un identificateur ou mot-cle --- }
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

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
Procedure LexScanNumber;
Var
  N        : LongInt;
  Base     : Integer;
  IsFloat  : Boolean;
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
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];
  { Detecter prefixe 0x 0o 0b }
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
  { Scanner la partie entiere }
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
  { Partie decimale .ddd }
  If (Base = 10) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); { sauter '.' }
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
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
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Inc(LexColNo);
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;
  { Calculer la valeur finale (tronquee a entier 16 bits) }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else            FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
  End;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
  If IsFloat Then
    CurToken.Kind := TK_FLOAT
  Else
    CurToken.Kind := TK_INTEGER;
End;

{ ---- LexScanEscChar : traiter une sequence d'echappement --- }
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
    'n'        : LexScanEscChar := #10;
    't'        : LexScanEscChar := #9;
    'r'        : LexScanEscChar := #13;
    '0'        : LexScanEscChar := #0;
    'b'        : LexScanEscChar := #8;
    'f'        : LexScanEscChar := #12;
    'v'        : LexScanEscChar := #11;
    '\'        : LexScanEscChar := '\';
    ''''       : LexScanEscChar := '''';
    '"'        : LexScanEscChar := '"';
    '`'        : LexScanEscChar := '`';
    'x', 'X'  :
    Begin
      V := 0;
      If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
      Begin
        V := HexVal(LexLine[LexColNo]);
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Then
        Begin
          V := V * 16 + HexVal(LexLine[LexColNo]);
          Inc(LexColNo);
        End;
      End;
      LexScanEscChar := Chr(V And $FF);
    End;
    'u', 'U'  :
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

{ ---- LexScanString : chaine simple ou double quote --------- }
Procedure LexScanString(Quote : Char);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter guillemet ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = Quote Then
    Begin
      Inc(LexColNo);
      Break;
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

{ ---- LexScanTemplate : template literal backtick ----------- }
Procedure LexScanTemplate;
Var
  S      : TString;
  Ch     : Char;
  Braces : Integer;
Begin
  S := '';
  Inc(LexColNo); { sauter backtick ouvrant }
  Braces := 0;
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      If (Ch = '`') And (Braces = 0) Then
      Begin
        Inc(LexColNo);
        Break;
      End
      Else If (Ch = '$') And (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '{') Then
      Begin
        If Length(S) < MAX_STR Then S := S + '$';
        If Length(S) < MAX_STR Then S := S + '{';
        Inc(LexColNo); Inc(LexColNo);
        Inc(Braces);
      End
      Else If (Ch = '}') And (Braces > 0) Then
      Begin
        If Length(S) < MAX_STR Then S := S + '}';
        Inc(LexColNo);
        Dec(Braces);
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
  CurToken.Kind   := TK_TEMPLATE;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanRegexp : expression reguliere /pat/flags ------- }
Procedure LexScanRegexp;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter '/' ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '/' Then
    Begin
      Inc(LexColNo);
      Break;
    End
    Else If Ch = '\' Then
    Begin
      If Length(S) < MAX_STR Then S := S + '\';
      Inc(LexColNo);
      If LexColNo <= Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  { separateur Chr(1) entre pattern et flags }
  If Length(S) < MAX_STR Then S := S + Chr(1);
  { Flags : g i m s reconnus, autres -> avertissement }
  While (LexColNo <= Length(LexLine)) And IsIdentStart(LexLine[LexColNo]) Do
  Begin
    Ch := LexLine[LexColNo];
    If Length(S) < MAX_STR Then S := S + Ch;
    If Not LexRegexpFlagOk(Ch) Then
      WarnMsg('flag regexp inconnu: ' + Ch);
    Inc(LexColNo);
  End;
  CurToken.Kind   := TK_REGEXP;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexMake2 : retourner un operateur 2 chars et avancer -- }
{ (utilitaire interne, non Forward-declare car utilisee inline) }

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch, Ch2, Ch3 : Char;
  Scanning     : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;

  { ASI en attente du saut de ligne precedent }
  If LexASIFlag Then
  Begin
    LexASIFlag    := False;
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := ';';
    CurToken.Line := LexLineNo;
    CurToken.Col  := 0;
    LexPrevKind   := TK_PUNCT;
    LexPrevVal    := ';';
    Exit;
  End;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer jusqu'a la prochaine ligne si on est en fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
    Begin
      LexCheckASI;
      LexNextLine;
      If LexASIFlag Then
      Begin
        LexASIFlag    := False;
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := ';';
        CurToken.Line := LexLineNo;
        CurToken.Col  := 0;
        LexPrevKind   := TK_PUNCT;
        LexPrevVal    := ';';
        Scanning      := False;
        Break;
      End;
    End;
    If Not Scanning Then Break;

    { Fin de fichier }
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      LexPrevKind   := TK_EOF;
      LexPrevVal    := '';
      Scanning      := False;
      Break;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire // jusqu'a fin de ligne }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexCheckASI;
      LexColNo := Length(LexLine) + 1;
    End

    { Commentaire bloc /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      LexPrevKind    := CurToken.Kind;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := (CurToken.Kind = TK_KEYWORD) And
                        ((CurToken.Val = 'return')     Or
                         (CurToken.Val = 'typeof')     Or
                         (CurToken.Val = 'delete')     Or
                         (CurToken.Val = 'void')       Or
                         (CurToken.Val = 'throw')      Or
                         (CurToken.Val = 'new')        Or
                         (CurToken.Val = 'in')         Or
                         (CurToken.Val = 'of')         Or
                         (CurToken.Val = 'instanceof'));
      Scanning := False;
    End

    { Nombre decimal }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      LexPrevKind    := CurToken.Kind;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Nombre .5 (point suivi de chiffre) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      CurToken.Kind   := TK_FLOAT;
      CurToken.IntVal := 0;
      CurToken.Val    := '0';
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And
            (LexLine[LexColNo] <= '9') Do
        Inc(LexColNo);
      LexPrevKind    := TK_FLOAT;
      LexPrevVal     := '0';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Spread ... }
    Else If (Ch = '.') And (LexColNo + 2 <= Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') And
            (LexLine[LexColNo + 2] = '.') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '...';
      Inc(LexColNo); Inc(LexColNo); Inc(LexColNo);
      LexPrevKind    := TK_OP;
      LexPrevVal     := '...';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Acces propriete . }
    Else If Ch = '.' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '.';
      Inc(LexColNo);
      LexPrevKind    := TK_PUNCT;
      LexPrevVal     := '.';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Chaine simple-quote }
    Else If Ch = '''' Then
    Begin
      LexScanString('''');
      LexPrevKind    := TK_STRING;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Chaine double-quote }
    Else If Ch = '"' Then
    Begin
      LexScanString('"');
      LexPrevKind    := TK_STRING;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { Template literal backtick }
    Else If Ch = '`' Then
    Begin
      { Detection tag template : ident immediatement suivi du backtick }
      If LexPrevKind = TK_IDENT Then
        WarnMsg('tag template non supporte, traite comme template literal');
      LexScanTemplate;
      LexPrevKind    := TK_TEMPLATE;
      LexPrevVal     := '';
      LexExpectRegex := False;
      Scanning       := False;
    End

    { = == === => }
    Else If Ch = '=' Then
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
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '=>';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '=';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { ! != !== }
    Else If Ch = '!' Then
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
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '!';
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { < <= << <<= }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '<<=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '<<';
        End;
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
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { > >= >> >>= >>> >>>= }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
        Begin
          Inc(LexColNo);
          If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
          Begin
            Inc(LexColNo);
            CurToken.Kind := TK_OP; CurToken.Val := '>>>=';
          End
          Else
          Begin
            CurToken.Kind := TK_OP; CurToken.Val := '>>>';
          End;
        End
        Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '>>=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '>>';
        End;
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
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      LexExpectRegex := True;
      Scanning := False;
    End

    { + ++ += }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '++';
        LexExpectRegex := False;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '+=';
        LexExpectRegex := True;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '+';
        LexExpectRegex := True;
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { - -- -= }
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '--';
        LexExpectRegex := False;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '-=';
        LexExpectRegex := True;
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '-';
        LexExpectRegex := True;
      End;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { * ** *= **= }
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '*') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '**=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '**';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '*=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '*';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { / /= regexp }
    Else If Ch = '/' Then
    Begin
      If LexExpectRegex Then
      Begin
        LexScanRegexp;
        LexPrevKind    := TK_REGEXP;
        LexPrevVal     := '';
        LexExpectRegex := False;
      End
      Else
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
        LexPrevKind    := TK_OP;
        LexPrevVal     := CurToken.Val;
        LexExpectRegex := True;
      End;
      Scanning := False;
    End

    { % %= }
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
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { & && &= &&= }
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '&&=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '&&';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '&=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '&';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { | || |= ||= }
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '|') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '||=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '||';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '|=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '|';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { ^ ^= }
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '^=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP; CurToken.Val := '^';
      End;
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { ~ }
    Else If Ch = '~' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_OP; CurToken.Val := '~';
      LexExpectRegex := True;
      LexPrevKind := TK_OP; LexPrevVal := '~';
      Scanning := False;
    End

    { ? ?? ??= ?. }
    Else If Ch = '?' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '?') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP; CurToken.Val := '??=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP; CurToken.Val := '??';
        End;
        LexExpectRegex := True;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP; CurToken.Val := '?.';
        LexExpectRegex := False;
      End
      Else
      Begin
        CurToken.Kind := TK_PUNCT; CurToken.Val := '?';
        LexExpectRegex := True;
      End;
      LexPrevKind := CurToken.Kind; LexPrevVal := CurToken.Val;
      Scanning := False;
    End

    { : }
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind := TK_PUNCT; CurToken.Val := ':';
      LexExpectRegex := True;
      LexPrevKind := TK_PUNCT; LexPrevVal := ':';
      Scanning := False;
    End

    { Ponctuation simple }
    Else If (Ch = ';') Or (Ch = ',') Or (Ch = '(') Or (Ch = ')') Or
            (Ch = '[') Or (Ch = ']') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      LexPrevKind    := TK_PUNCT;
      LexPrevVal     := CurToken.Val;
      LexExpectRegex := (Ch = '(') Or (Ch = '[') Or
                        (Ch = ';') Or (Ch = ',');
      Scanning := False;
    End

    { Accolades ouvrantes et fermantes }
    Else If Ch = '{' Then
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '{';
      Inc(LexColNo);
      LexPrevKind := TK_PUNCT; LexPrevVal := '{';
      LexExpectRegex := True;
      Scanning := False;
    End
    Else If Ch = '}' Then
    Begin
      CurToken.Kind := TK_PUNCT; CurToken.Val := '}';
      Inc(LexColNo);
      LexPrevKind := TK_PUNCT; LexPrevVal := '}';
      LexExpectRegex := False;
      Scanning := False;
    End

    { Caractere inconnu : ignorer avec avertissement }
    Else
    Begin
      WarnMsg('caractere inconnu: ' + Ch);
      Inc(LexColNo);
    End;

  End; { While Scanning }
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ LexRegexpFlagOk : valider un flag de regexp JS (g i m s) }
Function LexRegexpFlagOk(Ch : Char) : Boolean;
Begin
  LexRegexpFlagOk := (Ch = 'g') Or (Ch = 'i') Or (Ch = 'm') Or (Ch = 's');
End;

{ LexCheckTagTemplate : avertir si backtick suit un identifiant (tag template) }
Procedure LexCheckTagTemplate;
Begin
  { Appele depuis LexNextToken avant LexScanTemplate }
  { La detection est deja faite dans LexNextToken via LexPrevKind }
  WarnMsg('tag template non supporte, traite comme template literal');
End;

{ ExprMakeImm : construire une valeur immediate }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ExprMakeNone : expression sans valeur (void) }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ExprMakeNull : valeur null (AX=0, type null) }
Procedure ExprMakeNull(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NULL;
  Res.Offset  := 0;
End;

{ ExprMakeUndef : valeur undefined (AX=0, type undefined) }
Procedure ExprMakeUndef(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_UNDEF;
  Res.Offset  := 0;
End;

{ ExprMakeBool : valeur booleenne (0 ou 1) }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
End;

{ LitEval : evaluer un token litteral en TExprVal }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  Case T.Kind Of
    TK_INTEGER :
      ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);
    TK_FLOAT :
      ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);  { IntVal = Trunc(float) }
    TK_STRING :
    Begin
      Res.Kind    := EK_AX;    { l'adresse data sera resolue plus tard }
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
    End;
    TK_TEMPLATE :
    Begin
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := 0;
    End;
    TK_REGEXP :
    Begin
      Res.Kind    := EK_AX;    { pointeur vers objet RegExp DATA }
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_OBJECT;
      Res.Offset  := 0;
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'null' Then
        ExprMakeNull(Res)
      Else If T.Val = 'undefined' Then
        ExprMakeUndef(Res)
      Else If T.Val = 'true' Then
        ExprMakeBool(1, Res)
      Else If T.Val = 'false' Then
        ExprMakeBool(0, Res)
      Else
        ExprMakeNone(Res);
    End;
    TK_IDENT :
    Begin
      { NaN et Infinity sont techniquement des identifiants globaux }
      If T.Val = 'NaN' Then
      Begin
        WarnMsg('NaN non representable en 16 bits, traite comme 0');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      Else If T.Val = 'Infinity' Then
      Begin
        WarnMsg('Infinity non representable en 16 bits, traite comme 0');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      Else
        ExprMakeNone(Res);
    End;
  Else
    ExprMakeNone(Res);
  End;
End;

{ ============================================================
  STUBS PREALABLES (seront implantes dans les TODOs suivants)
  ============================================================ }

Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TKJ_UNKNOWN;
    TypeTab[I].Size := 0;
  End;
  { Types primitifs JavaScript }
  TypeTab[TY_IDX_NUMBER].Name   := 'number';
  TypeTab[TY_IDX_NUMBER].Kind   := TKJ_NUMBER;
  TypeTab[TY_IDX_NUMBER].Size   := 2;
  TypeTab[TY_IDX_STRING].Name   := 'string';
  TypeTab[TY_IDX_STRING].Kind   := TKJ_STRING;
  TypeTab[TY_IDX_STRING].Size   := 2;
  TypeTab[TY_IDX_BOOLEAN].Name  := 'boolean';
  TypeTab[TY_IDX_BOOLEAN].Kind  := TKJ_BOOLEAN;
  TypeTab[TY_IDX_BOOLEAN].Size  := 2;
  TypeTab[TY_IDX_OBJECT].Name   := 'object';
  TypeTab[TY_IDX_OBJECT].Kind   := TKJ_OBJECT;
  TypeTab[TY_IDX_OBJECT].Size   := 2;
  TypeTab[TY_IDX_ARRAY].Name    := 'array';
  TypeTab[TY_IDX_ARRAY].Kind    := TKJ_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size    := 2;
  TypeTab[TY_IDX_FUNCTION].Name := 'function';
  TypeTab[TY_IDX_FUNCTION].Kind := TKJ_FUNCTION;
  TypeTab[TY_IDX_FUNCTION].Size := 2;
  TypeTab[TY_IDX_NULL].Name     := 'object';   { typeof null = 'object' en JS }
  TypeTab[TY_IDX_NULL].Kind     := TKJ_NULL;
  TypeTab[TY_IDX_NULL].Size     := 2;
  TypeTab[TY_IDX_UNDEF].Name    := 'undefined';
  TypeTab[TY_IDX_UNDEF].Kind    := TKJ_UNDEFINED;
  TypeTab[TY_IDX_UNDEF].Size    := 2;
  TypeCount := TY_PRIM_COUNT;
End;

Procedure SymInit;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
End;

{ ---- LexInit : ouvrir le source, lire premiere ligne, shebang }
Procedure LexInit;
Var
  F : Text;
Begin
  Assign(F, Opts.SrcFile);
  Reset(F);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexSrcF        := F;
  LexOpened      := True;
  LexLineNo      := 0;
  LexColNo       := 1;
  LexEOF         := False;
  LexLine        := '';
  LexPrevKind    := TK_EOF;
  LexPrevVal     := '';
  LexExpectRegex := True;
  LexASIFlag     := False;
  { Lire la premiere ligne }
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
    LexColNo := Length(LexLine) + 1;
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
  { Stub : TODO 07 implementera l'emission du header complet }
  WriteLn(OutF, '; Genere par JS86 v', JS86_VERSION, ' - ', Opts.SrcFile);
End;

Procedure EmitDataSeg;
Begin
  { Stub : TODO 08 }
End;

Procedure EmitRuntime;
Begin
  { Stub : TODO 24 }
End;

Procedure EmitClose;
Begin
  { Stub : TODO 25 }
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

Procedure ParseStmt;
Begin
  { Stub : TODO 13+ }
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

  { Detecter 'use strict'; en tete de fichier }
  If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'use') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_IDENT) And (CurToken.Val = 'strict') Then
    Begin
      Opts.Strict := True;
      ParserAdvance; { consomme 'strict' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance; { consomme ';' }
    End;
  End;

  { Boucle principale de compilation (stubs TODO 13+) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    ParseStmt;
    { ParseStmt ne fait rien encore - avancer pour eviter boucle infinie }
    If CurToken.Kind <> TK_EOF Then
      ParserAdvance;
  End;

  LexClose;
  EmitRuntime;
  EmitDataSeg;
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
