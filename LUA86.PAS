{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Lua vers assembleur 8086
}

(* ============================================================
  LUA86.PAS - Compilateur Lua vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (script.lua [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .lua du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)
            Shebang : ignorer la premiere ligne #!/usr/bin/env lua si presente

  TODO 02 - LEXEUR (TOKENS LUA) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets simples ou doubles
              Sequences d echappement : \n \t \r \\ \" \' \a \b \f \v \0 \xNN
            LexScanLongString : [[...]] et [=[...]=] (chaines longues multi-lignes)
              Niveau d egalite : [===[...]===] (imbrication par niveau)
            Commentaires : -- jusqu a fin de ligne
              --[[...]] et --[=[...]=] (commentaires longs multi-lignes)
            Mots-cles : and break do else elseif end false for
              function goto if in local nil not or repeat
              return then true until while
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (tronques a 16 bits)
            Entiers hexadecimaux : 0xFF, 0XFF
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
              Notation scientifique : 1.5e3 -> 1500 (trunc)
              Hexadecimaux flottants : 0x1.Fp10 -> avertissement + trunc
            Chaines simples : 'abc' ou "abc" -> pointeur vers donnees DATA
            Chaines longues : [[texte multi-ligne]] -> pointeur DATA
            nil    : constante -> AX=0 (valeur nulle)
            true   : constante -> AX=1
            false  : constante -> AX=0
            Concatenation de chaines : .. operateur -> CALL _LUART_CONCAT

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / // (div entiere) % (modulo)
            Puissance      : ^ (associatif a droite -> CALL _LUART_POW)
            Concatenation  : .. (chaines -> CALL _LUART_CONCAT)
            Comparaison    : == ~= < <= > >=
            Logiques       : and or not (court-circuit, retournent une valeur)
            Longueur       : # (unaire, longueur de chaine ou table)
            Unaire         : - (negation) not (negation logique) # (longueur)
            Affectation    : = (assignation simple ou multiple)
            Precedence (du plus faible au plus fort) :
              1. or
              2. and
              3. < > <= >= ~= ==
              4. |  (Lua 5.3+ bitwise, stub + avertissement)
              5. ~  (Lua 5.3+ bitwise xor, stub)
              6. &  (Lua 5.3+ bitwise and, stub)
              7. << >> (Lua 5.3+ decalages, stub)
              8. .. (concatenation, associatif a droite)
              9. + -
              10. * / // %
              11. not # - (unaires)
              12. ^ (puissance, associatif a droite)

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_LOCAL, SK_GLOBAL, SK_PARAM, SK_UPVALUE,
              SK_FUNCTION, SK_LABEL
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsLocal, IsUpvalue
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees imbriquees
            Variables locales : portee du bloc courant (local x = expr)
            Variables globales : implicites (toute variable non local)
              Table _G : representation interne des globales
            Upvalues : variables capturees par les closures englobantes
            Labels goto : enregistrement dans la table pour saut avant/arriere

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_NIL, TYK_BOOLEAN, TYK_NUMBER (entier 16 bits),
              TYK_STRING (ptr chaine terminee par 0), TYK_TABLE (ptr),
              TYK_FUNCTION (ptr code), TYK_USERDATA (stub ptr),
              TYK_UNKNOWN (typage dynamique -> inference limitee)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : number=2o, ptr=2o (string/table/function/userdata)
            Typage dynamique : Lua est non type statiquement
              Inference a la compilation quand le type est evident
              Avertissement si le type ne peut etre determine
            Tag de type a l execution : chaque valeur porte un tag dans les tables
            type(x) : retourne la chaine du type -> CALL _LUART_TYPE -> AX=ptr
            Coercition automatique nombre/chaine (tonumber/tostring implicite)

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _LUAL_NNNNN)
            Prefixes : _LUAV_ (variable globale), _LUAL_ (label),
              _LUAF_ (function), _LUAK_ (chaine const),
              _LUART_ (runtime), _LUAT_ (table donnees),
              _LUAX_ (handler d erreur), _LUAU_ (upvalue)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_TABLE),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddTable : variantes d ajout
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Chaines litterales -> entree DK_STR (terminateur 0)
            Variables globales : entrees DK_WORD dans DataTab
            Chaines longues [[...]] : DB bloc multi-ligne dans DATA
            _LUA_NIL_S : DB 'nil',0 -- _LUA_TRUE_S : DB 'true',0
            _LUA_FALSE_S : DB 'false',0
            _LUART_STRBUF[0..511] : buffer de travail pour concatenation

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables locales : local x = expr -> pile BP, acces [BP-offset]
              local x (sans init) -> valeur nil (AX=0)
              local x, y, z = a, b, c : affectation multiple
            Variables globales : x = expr -> segment DATA, acces par label _LUAV_x
              Premiere utilisation cree implicitement la globale
            Affectation simple : var = expr -> ExprLoad + MOV destination, AX
            Affectation multiple : a, b = expr1, expr2
              Evaluation de toutes les expressions a droite d abord
              Puis affectation de gauche a droite
              Valeurs excedentaires ignorees, manquantes -> nil
            Affectation de table : t[k] = expr -> CALL _LUART_TSET
            Affectation composee : pas native en Lua (pas de += -= etc.)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal nombre, literal chaine, ident, appel, nil,
              true -> MOV AX,1   false -> XOR AX,AX
              nil -> XOR AX,AX
            Acces table point : t.champ -> sucre pour t["champ"]
              CALL _LUART_TGET(BX=ptr_table, DI=ptr_cle) -> AX
            Acces table crochet : t[expr] -> CALL _LUART_TGET
            Constructeur de table : {e1, e2, k1=v1, [expr]=v2}
              -> DataAdd DK_TABLE ou construction inline sur pile
            Groupement parenthese : (expr)
            Appel de fonction : nom(args) ou expr(args) -> CALL ou CALL AX
            Appel methode : obj:methode(args) -> sucre pour obj.methode(obj, args)
            Varargs : ... dans le corps d une fonction variadique
            ExprMakeImm, ExprMakeNil : constructeurs TExprVal

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
            ParseExprPrec(MinPrec) : boucle Pratt avec precedences Lua
            Arithmetique entiere : ADD/SUB pour +, -, IMUL pour *
            Division : / -> IDIV (quotient dans AX)
            Division entiere : // -> IDIV (quotient dans AX, arrondi vers -inf)
            Modulo : % -> IDIV, resultat dans DX (reste)
            Puissance : ^ -> CALL _LUART_POW(AX=base, BX=exp) -> AX
            Concatenation .. : CALL _LUART_CONCAT(SI=gauche, DI=droite) -> AX=ptr
            Comparaison : CMP + Jcc pour ==, <, <=, >, >=
              ~= (different) : CMP + JNE
            Comparaison de chaines : CALL _LUART_STRCMP -> drapeaux
            Logique and : court-circuit, retourne 1er operande si faux, sinon 2eme
              JZ vers short-circuit (and retourne la valeur, pas juste 0/1)
            Logique or : court-circuit, retourne 1er operande si vrai, sinon 2eme
              JNZ vers short-circuit
            Logique not : TEST AX,AX / SETZ AL / MOVZX AX,AL (0->1, autre->0)
            Longueur # : CALL _LUART_LEN(AX=val) -> AX=longueur
            Negation unaire - : NEG AX

  TODO 12 - ENTREES/SORTIES (print, io)
            print(args) : affiche chaque argument converti en chaine + \t entre args
              Detection du type a la compilation -> _LUART_NUMTOSTR ou chaine directe
              Separateur tabulation entre arguments ; \n final
              -> INT 21h AH=40h BX=1 (STDOUT)
            io.write(args) : ecriture sans \n ni separateurs
              -> INT 21h AH=40h BX=1 (STDOUT)
            io.read("*l")   -> INT 21h AH=0Ah (lecture ligne) -> AX=ptr
            io.read("*n")   -> lecture chaine + CALL _LUART_STRTONUM -> AX
            io.read("*a")   -> stub + avertissement (lecture fichier entier)
            tostring(x) : conversion en chaine
              nombre -> CALL _LUART_NUMTOSTR -> AX=ptr
              nil -> ptr vers "nil"
              boolean -> ptr vers "true"/"false"
            tonumber(s) : conversion en nombre
              CALL _LUART_STRTONUM(SI=str) -> AX
            io.open, io.close : stubs + avertissement (gestion fichier avancee)

  TODO 13 - IF / ELSEIF / ELSE
            ParseIfStmt : if cond then stmts {elseif cond then stmts} [else stmts] end
              Verite Lua : nil et false sont faux, tout le reste est vrai
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _LUAL_ELIF_N, _LUAL_ELSE_N, _LUAL_ENDIF_N
            Condition : toute expression est evaluee en booleenne
              nil -> faux (AX=0)
              false -> faux (AX=0)
              0 -> vrai (attention : 0 est vrai en Lua!)
              Chaine vide -> vrai (attention : '' est vrai en Lua!)
              Emission : CMP AX,0 + JZ pour nil/false uniquement
                Si type connu number : toujours vrai (sauf nil)
                Si type inconnu : CALL _LUART_TRUTHY -> AX=0|1

  TODO 14 - BOUCLES : while / repeat / for / goto
            ParseWhileStmt : while cond do stmts end
              Labels : _LUAL_WTEST_N, _LUAL_WEND_N
            ParseRepeatStmt : repeat stmts until cond
              Labels : _LUAL_RBEG_N, _LUAL_RTEST_N
              Particularite : les locales du bloc sont visibles dans until cond
            ParseForNumStmt : for i = start, stop [, step] do stmts end
              Variable de boucle locale automatique (non modifiable par le corps)
              Increment par defaut = 1 si step omis
              Labels : _LUAL_FTEST_N, _LUAL_FINCR_N, _LUAL_FEND_N
            ParseForInStmt : for k, v in pairs(t) do stmts end
              pairs(t) : iteration sur toutes les cles d une table
              ipairs(t) : iteration sur les indices entiers 1..#t
              Emission : boucle avec CALL _LUART_TNEXT / _LUART_TINEXT
              next(t, k) : fonction d iteration de base -> cle,valeur suivantes
            ParseGotoStmt : goto label
              Labels declares par ::label:: dans le bloc courant
              Saut avant ou arriere -> JMP _LUAL_GOTO_label
              Restriction : ne peut sauter dans un bloc interne
            break : sortie de la boucle englobante -> JMP _LUAL_END_N
            LoopPush / LoopPop : pile de labels break

  TODO 15 - TABLES (construction et acces)
            Constructeur de table :
              Liste : {10, 20, 30} -> indices 1, 2, 3 (base 1 Lua)
              Record : {x=1, y=2} -> cles chaines
              Mixte : {10, 20, x=1, [expr]=val}
            Representation memoire :
              Partie tableau : [count:word] [e1:word] [e2:word] ...
                Indices entiers 1..n, acces O(1) par offset
              Partie hash : [n_pairs:word] [kptr:word] [vptr:word] ...
                Cles chaines ou non-entieres, acces par _LUART_TGET
              Combinaison : flag indiquant la taille de la partie tableau
            Acces t[i] (i entier constant) : offset = (i-1)*2 + 2 (base 1)
            Acces t[i] (i variable) : DEC AX / SHL AX,1 / ADD AX,2 -> MOV AX,[BX+SI]
            Acces t.champ (champ constant) : CALL _LUART_TGET(BX=tbl, DI=kptr)
            Affectation t[k] = v : CALL _LUART_TSET(BX=tbl, DI=k, AX=v)
            Longueur # : MOV AX,[BX] (premier word = count partie tableau)
            table.insert(t, v)    -> CALL _LUART_TINSERT
            table.remove(t, pos)  -> CALL _LUART_TREMOVE -> AX=val retiree
            table.concat(t, sep)  -> CALL _LUART_TCONCAT(BX=tbl, DI=sep) -> AX=ptr
            table.sort(t [,comp]) -> CALL _LUART_TSORT (tri a bulles)
            table.unpack(t)       -> pousse les elements sur la pile (retour multiple)

  TODO 16 - METATABLES ET METAMETHODES
            setmetatable(t, mt) : associe une metatable mt a la table t
              Representation : chaque table porte un champ [meta:word] (ptr ou 0)
              CALL _LUART_SETMETA(BX=tbl, AX=mt)
            getmetatable(t) -> AX=ptr metatable ou AX=0 (nil)
            Metamethodes arithmetiques :
              __add, __sub, __mul, __div, __mod, __pow, __unm (unaire -)
              Si operande a une metatable avec __add :
                CALL _LUART_METAMETHOD(BX=obj, DI=kptr_add) -> AX=ptr_fn
                Si AX != 0 -> PUSH args + CALL AX, sinon operation par defaut
            Metamethodes de comparaison : __eq, __lt, __le
            __concat : surcharge de l operateur ..
            __len : surcharge de l operateur #
            __index : acces a une cle absente -> appel metatable
              Si __index est une table : recherche dans cette table
              Si __index est une fonction : appel avec (table, cle) -> AX=valeur
            __newindex : affectation a une cle absente -> appel metatable
            __call : appel d une table comme fonction -> appel avec (table, args)
            __tostring : conversion en chaine (utilise par tostring et print)
            Limitation : un seul niveau de delegation (pas de chaine de metatables)

  TODO 17 - FONCTIONS ET CLOSURES
            ParseFuncDecl : function nom(params) stmts end
              Globale par defaut : function f() -> _LUAF_f PROC NEAR
              Locale : local function f() -> portee du bloc
            ParseFuncExpr : function(params) stmts end (fonction anonyme)
              Emission comme fonction : label _LUAF_ANON_N
              Stockee comme pointeur de code dans une variable
            Parametres :
              Parametres nommes : function f(a, b, c)
              Parametres excedentaires ignores, manquants -> nil
              Varargs : function f(a, ...) -> ... collecte le reste
                Acces a ... dans le corps -> valeurs sur la pile
              select('#', ...) : nombre d arguments variadiques -> AX
              select(n, ...) : n-ieme argument -> AX
            Valeur de retour : return expr1, expr2, ...
              Retour multiple : empile les valeurs, AX = premiere
              return sans valeur -> AX=0 (nil)
            Appel : nom(args) -> PUSH args de droite a gauche + CALL _LUAF_nom
              Expression : f(args) -> CALL AX (pointeur de fonction)
              Methode : obj:method(args) -> obj.method(obj, args)
            Appel terminal (tail call) : return f(args) -> optimisation JMP
            Convention d appel : cdecl 16 bits, arguments empiles droite a gauche
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET

  TODO 18 - PORTEE, PILE ET CADRES
            Convention d appel : cdecl 16 bits, args de droite a gauche sur pile
            Prologue fonction : PUSH BP / MOV BP,SP
            Epilogue : MOV SP,BP / POP BP / RET (appelant nettoie pile)
            Variables locales : allouees sur la pile au prologue (SUB SP, n*2)
            Variables globales : acces par label _LUAV_nom dans DATA
            Fermeture de portee de bloc : ADD SP, n*2 a la fin du bloc
            Upvalues (closures) :
              Analyse de capture en pre-passe : reperer les identifiants libres
              Variable capturee : cellule DK_WORD dans DATA (_LUAU_nom)
              Lecture upvalue : MOV AX, [_LUAU_nom]
              Ecriture upvalue : MOV [_LUAU_nom], AX
              Avertissement si closure profonde (>2 niveaux)
            CurFrameSize : taille courante du cadre local (nb de words)
            Sauvegarde registres : SI, DI preserves dans chaque fonction
            _ENV : environnement global (stub, toutes les globales sont dans DATA)

  TODO 19 - CHAINES ET BIBLIOTHEQUE string
            Chaines immutables : chaque operation retourne une nouvelle chaine
            string.len(s) ou #s : CALL _LUART_STRLEN(SI=AX) -> AX
            string.sub(s, i [,j]) : CALL _LUART_STRSUB(SI, BX, CX) -> AX=ptr
            string.byte(s [,i [,j]]) : retourne le code octet -> AX
            string.char(n1, n2, ...) : CALL _LUART_CHR -> AX=ptr chaine
            string.rep(s, n) : CALL _LUART_STRREPEAT(SI, CX=n) -> AX=ptr
            string.reverse(s) : CALL _LUART_STRREV(SI=str) -> AX=ptr
            string.upper(s) : CALL _LUART_STRTOUPPER(SI=str) -> AX=ptr
            string.lower(s) : CALL _LUART_STRTOLOWER(SI=str) -> AX=ptr
            string.find(s, pattern) : CALL _LUART_STRFIND(SI, DI) -> AX=pos ou 0
              Recherche litterale basique (pas de patterns regex complets)
              Patterns Lua (%d %a %l %u %s %p %w) : avertissement + litterale
            string.gsub(s, pat, repl) : CALL _LUART_STRGSUB -> AX=ptr
              Remplacement de la premiere occurrence litterale
            string.format(fmt, ...) : CALL _LUART_STRFMT -> AX=ptr
              %d -> _LUART_NUMTOSTR, %s -> chaine directe, %% -> '%'
              %x, %o, %c : stubs simplifies
            string.gmatch : stub + avertissement (iterateur complexe)

  TODO 20 - BIBLIOTHEQUE STANDARD (math, table, os)
            Bibliotheque math :
              math.abs(n)    -> CALL _LUART_ABS -> AX
              math.max(a,b)  -> CMP + branchement -> AX
              math.min(a,b)  -> CMP + branchement -> AX
              math.floor(n)  -> pass-through (deja entier)
              math.ceil(n)   -> pass-through
              math.sqrt(n)   -> CALL _LUART_SQRT (Newton-Raphson entier) -> AX
              math.random([m [,n]]) -> CALL _LUART_RAND (LCG 16 bits) -> AX
              math.randomseed(n) -> MOV [_LUART_SEED], AX
              math.pi        -> DW 3 (troncature, avertissement)
              math.huge      -> DW 32767 (approximation, avertissement)
              math.maxinteger -> DW 32767
              math.mininteger -> DW -32768
              math.tointeger(n) -> pass-through (deja entier)
              math.type(n)   -> retourne "integer" (toujours)
            Bibliotheque table :
              (voir TODO 15 pour table.insert, table.remove, etc.)
              table.move(a, f, e, t [,a2]) : stub + avertissement
              table.pack(...) : stub -> avertissement
            Bibliotheque os :
              os.clock()  -> INT 21h AH=2Ch -> approximation en secondes -> AX
              os.time()   -> stub AX=0 + avertissement
              os.date()   -> stub AX=ptr "00/00/0000" + avertissement
              os.exit([code]) -> MOV AX,4C00h + code + INT 21h
              os.execute(cmd) -> stub + avertissement

  TODO 21 - RETOURS MULTIPLES ET VARARGS
            Retour multiple : return a, b, c
              Convention : premiere valeur dans AX, suivantes empilees
              Nombre de valeurs retournees dans CX
              Appelant : recupere AX + POP les valeurs supplementaires
            Ajustement de valeurs :
              x, y = f() : si f retourne 1 valeur -> y = nil
              x, y = f(), g() : appel f() tronque a 1 valeur, g() complete
              {f()} : tous les retours de f inseres dans la table
              f(g()) : tous les retours de g passes comme args a f
            Varargs ... :
              Acces en tant qu expression multiple
              select('#', ...) : CALL _LUART_VARGCOUNT -> AX
              select(n, ...) : CALL _LUART_VARGGET(CX=n) -> AX
              ... dans un constructeur de table : insertion de tous les args
              ... comme arguments d appel : passage de tous les args restants
            Limitation : max MAX_RETVALS valeurs de retour (defaut 8)

  TODO 22 - GESTION D ERREURS (pcall, error, xpcall)
            error(msg [,level]) : lever une erreur
              AX = ptr message d erreur (chaine)
              Mecanisme : saut vers le handler pcall courant
              Si aucun handler : affiche msg + INT 21h AH=4Ch AL=1
            pcall(f, arg1, ...) : appel protege
              Installe un handler d erreur avant l appel
              _LUAX_HANDLER DW 0 dans DATA (ptr handler courant)
              MOV [_LUAX_HANDLER], OFFSET _LUAL_PCATCH_N
              CALL _LUAF_f avec les arguments
              Si succes : AX=1 (true) + valeurs de retour de f
              Si erreur : saut vers _LUAL_PCATCH_N, AX=0 (false) + message
              Restauration du handler precedent apres l appel
            xpcall(f, msgh, arg1, ...) : appel protege avec handler de message
              msgh : fonction appelee sur le message d erreur avant retour
              CALL msgh(AX=msg_erreur) -> AX=msg_transforme
            assert(v [,msg]) : si v est nil ou false -> error(msg)
              Sinon retourne v et tous les arguments supplementaires

  TODO 23 - COROUTINES (basiques)
            coroutine.create(f) : cree une coroutine a partir de f
              Representation : structure { status:word, pc:word, sp:word, bp:word }
              Alloue une pile separee dans le heap pour la coroutine
              Retourne AX = ptr vers la structure coroutine
            coroutine.resume(co, args) : reprend l execution
              Sauvegarde le contexte courant (SP, BP, adresse retour)
              Restaure le contexte de la coroutine (SP, BP, PC)
              Passe les arguments / valeurs de yield sur la pile
              Retourne : true + valeurs de yield, ou false + message d erreur
            coroutine.yield(vals) : suspend l execution
              Sauvegarde le contexte de la coroutine
              Restaure le contexte de l appelant de resume
              Retourne les valeurs a resume
            coroutine.status(co) : retourne "running"/"suspended"/"dead"/"normal"
              -> AX=ptr chaine selon le champ status
            coroutine.wrap(f) : cree un iterateur a partir d une coroutine
              Retourne une fonction qui appelle resume a chaque appel
            Limitation : pile de coroutine fixe (COROUTINE_STACK_SIZE = 512 octets)
            Avertissement si coroutines imbriquees ou recursion profonde

  TODO 24 - RUNTIME MINIMAL
            _LUART_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _LUART_PRINTLN : _LUART_PRINT + CR+LF via _LUA_CRLF DB 13,10,0
            _LUART_STRLEN(SI=str) : compte octets jusqu a 0 -> AX et CX
            _LUART_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _LUART_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _LUART_CONCAT(DI=dst, SI=src) : concatenation de chaines -> AX=ptr
            _LUART_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _LUART_STRSUB(SI=str, BX=start, CX=len) : sous-chaine -> AX=ptr
            _LUART_STRREPEAT(DI=dst, SI=src, CX=n) : repete n fois -> AX=ptr
            _LUART_STRFIND(SI=str, DI=pat) : recherche -> AX=pos (1-based) ou 0
            _LUART_STRFMT(SI=fmt, ...) : formatage simplifie -> AX=ptr
            _LUART_ABS(AX=n) : valeur absolue -> AX
            _LUART_POW(AX=base, BX=exp) : puissance entiere -> AX
            _LUART_SQRT(AX=n) : racine carree entiere (Newton) -> AX
            _LUART_RAND : LCG 16 bits -> AX (graine _LUART_SEED DW 1)
            _LUART_TYPE(AX=val, BX=tag) : retourne ptr chaine du type -> AX
            _LUART_TRUTHY(AX=val, BX=tag) : verite Lua -> AX=0|1
              nil et false -> 0, tout le reste -> 1 (y compris 0 et '')
            _LUART_TGET(BX=tbl, DI=key) : lecture table -> AX=valeur
            _LUART_TSET(BX=tbl, DI=key, AX=val) : ecriture table
            _LUART_TNEXT(BX=tbl, DI=key) : prochain cle/valeur (pairs)
            _LUART_TINEXT(BX=tbl, CX=idx) : prochain index/valeur (ipairs)
            _LUART_TINSERT / _LUART_TREMOVE : insertion/suppression dans table
            _LUART_TSORT(BX=tbl) : tri a bulles numerique in-place
            _LUART_TCONCAT(BX=tbl, DI=sep) : join elements -> AX=ptr
            _LUART_SETMETA / _LUART_GETMETA : gestion metatables
            _LUART_METAMETHOD(BX=obj, DI=kptr) : cherche metamethode -> AX=ptr
            _LUART_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _LUA_HEAP DB 4096 DUP(0) + _LUA_HEAPTOP DW 0
              _LUART_ALLOC(CX=nb_bytes) -> AX=ptr dans le heap statique

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _LUAF_main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseBlock boucle ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _LUAF_main
            Fichiers SAMPLES\LUA\ a creer :
              hello.lua   (print, variables locales/globales, concatenation ..)
              math.lua    (fonctions, recursion, return, math.abs/sqrt)
              control.lua (if/elseif, while, repeat/until, for numerique/generique)
              tables.lua  (constructeurs, acces, table.insert/sort/concat)
              strings.lua (string.sub, string.find, string.format, #)
              closures.lua (fonctions anonymes, closures, upvalues)
              meta.lua    (metatables, __index, __add, __tostring)
              errors.lua  (pcall, error, xpcall, assert)
            Smoke tests : LUA86.EXE -v SAMPLES\LUA\*.lua

  ============================================================ *)

{ ============================================================
  LUA86 - Compilateur Lua -> assembleur 8086
  Version : 1.0  Date : 2026-03-07
  Compilation : ppc386 -O2 -Mtp LUA86.PAS
  ============================================================ }

Program LUA86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  LUA86_VERSION = '1.0';
  LUA86_DATE    = '2026-03-07';

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
  MAX_RETVALS   = 8;    { nombre max de valeurs de retour multiples }
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  LUA_VAR_PFX  = '_LUAV_';   { variable globale                    }
  LUA_FN_PFX   = '_LUAF_';   { fonction                            }
  LUA_STR_PFX  = '_LUAK_';   { constante chaine litterale          }
  LUA_RT_PFX   = '_LUART_';  { routine runtime                     }
  LUA_LBL_PFX  = '_LUAL_';   { label de saut interne               }
  LUA_TBL_PFX  = '_LUAT_';   { table donnees                       }
  LUA_UP_PFX   = '_LUAU_';   { upvalue                             }
  LUA_ERR_PFX  = '_LUAX_';   { handler d erreur                    }
  LUA_NIL_LBL  = '_LUA_NIL_S';   { etiquette DATA chaine 'nil'     }
  LUA_TRUE_LBL = '_LUA_TRUE_S';  { etiquette DATA chaine 'true'    }
  LUA_FALSE_LBL= '_LUA_FALSE_S'; { etiquette DATA chaine 'false'   }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Indices de types primitifs Lua }
  TY_IDX_NIL      = 0;  { nil                           }
  TY_IDX_BOOLEAN  = 1;  { true/false                    }
  TY_IDX_NUMBER   = 2;  { entier 16 bits signe          }
  TY_IDX_STRING   = 3;  { pointeur chaine DATA          }
  TY_IDX_TABLE    = 4;  { pointeur structure table       }
  TY_IDX_FUNCTION = 5;  { pointeur de code               }
  TY_IDX_USERDATA = 6;  { stub pointeur                  }
  TY_PRIM_COUNT   = 7;
  TY_UNKNOWN      = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.lua)                 }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Lua (TODO 02) ------------------------------- }
  TTokenKind = (
    TK_EOF,       { fin de fichier                          }
    TK_INTEGER,   { literal entier 42 0xFF                  }
    TK_FLOAT,     { literal flottant 3.14 1.5e3             }
    TK_STRING,    { literal chaine simple ou double quote   }
    TK_IDENT,     { identificateur (non-mot-cle)            }
    TK_KEYWORD,   { mot-cle Lua reconnu                     }
    TK_OP,        { operateur + - * / .. == ~= etc.         }
    TK_PUNCT      { ponctuation ; , ( ) etc.                }
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
    SK_LOCAL,      { variable locale (local x)         }
    SK_GLOBAL,     { variable globale (implicite)      }
    SK_PARAM,      { parametre formel de fonction      }
    SK_UPVALUE,    { variable capturee par closure     }
    SK_FUNCTION,   { declaration de fonction           }
    SK_LABEL       { label goto (::label::)            }
  );

  TSymRec = Record
    Name        : TString;   { identifiant Lua                 }
    MangledName : TString;   { _LUAV_nom / _LUAF_nom           }
    Kind        : TSymKind;
    TypeIdx     : Integer;   { indice dans TypeTab              }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux               }
    IsLocal     : Boolean;   { True si declare avec local       }
    IsUpvalue   : Boolean;   { True si capture par une closure  }
    DeclLine    : Integer;
  End;

  { ---- Types internes (TODO 06) --------------------------- }
  TTypeKind = (
    TYK_NIL,
    TYK_BOOLEAN,
    TYK_NUMBER,
    TYK_STRING,
    TYK_TABLE,
    TYK_FUNCTION,
    TYK_USERDATA,
    TYK_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { octets : number=2, ptr=2 }
  End;

  { ---- Valeurs d expression (TODO 11) --------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur             }
    EK_IMM,    { immediate dans ImmVal             }
    EK_AX,     { valeur dans AX                    }
    EK_MEM     { adresse [BP+Offset] ou [_LUAV_x]  }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas de lvalue) }
  End;

  { ---- Segment de donnees (TODO 08) ----------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_TABLE_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_TABLE_BLK : nb elements }
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
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

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
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;    { compteur unique pour LabelGen        }

  { Segment de donnees (TODO 08) }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexClose;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
{ Lexeur (TODO 02) }
Procedure LexInit;             Forward;
Procedure LexNextLine;         Forward;
Procedure LexNextToken;        Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Function  LexScanEscChar : Char; Forward;
Procedure LexScanString(Quote : Char); Forward;
Function  LexLongBracketLevel : Integer; Forward;
Procedure LexScanLongString(Level : Integer); Forward;
Procedure LexSkipLongComment(Level : Integer); Forward;
Procedure PrintToken(Const T : TToken); Forward;
{ Litteraux et constantes (TODO 03) }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeNil(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
{ Operateurs et precedence (TODO 04) }
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Procedure EmitBinOp(Const Op : TString;
                    Var L : TExprVal; Const R : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
Procedure ParserAdvance; Forward;
{ Table des symboles (TODO 05) }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                ATypeIdx : Integer; AOffset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;
{ Systeme de types (TODO 06) }
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsTruthy(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;
Procedure TypeInit; Forward;
{ Emetteur ASM (TODO 07) }
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
Procedure EmitOpen; Forward;
Procedure EmitHeader; Forward;
Procedure EmitRuntime; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('LUA86: FATAL: ', Msg);
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
  Write('LUA86:');
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
  Write('LUA86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('LUA86 v', LUA86_VERSION, ' (', LUA86_DATE, ')');
  WriteLn('Compilateur Lua -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: LUA86 <source.lua> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.lua : fichier Lua source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  WriteLn('LUA86 v', LUA86_VERSION, ' - Compilateur Lua -> 8086 ASM');
  WriteLn;
  ShowUsage;
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

{ Extrait le nom de base d un chemin (sans extension) }
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

{ Remplace l extension d un chemin }
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

{ Extrait l extension d un chemin }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastSep, LastDot : Integer;
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

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('LUA86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('LUA86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('LUA86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .lua }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.lua') Then
    WarnMsg('extension attendue .lua, obtenu ' + Ext);

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
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  TypeInit;  { TODO 06 : initialiser table des types primitifs Lua }
  SymInit;  { TODO 05 : initialiser table des symboles + builtins Lua }
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ LabelGen : generer un label unique _LUAL_NNNNN }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := LUA_LBL_PFX + S;
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

{ EmitOpen : ouvrir le fichier de sortie ASM }
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

{ EmitHeader : emettre le preambule ASM (.MODEL SMALL, etc.) }
Procedure EmitHeader;
Begin
  EmitComment('Genere par LUA86 v' + LUA86_VERSION + ' - ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  { Point d entree _LUAF_main }
  EmitLabel(LUA_FN_PFX + 'main');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
  EmitComment('--- debut du code genere ---');
  EmitBlankLine;
End;

{ EmitRuntime : emettre les routines runtime (stub pour TODO 24) }
Procedure EmitRuntime;
Begin
  { Stub : sera implemente dans TODO 24 }
End;

{ EmitClose : terminer le fichier ASM (DOS exit, runtime, DATA, END) }
Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  EmitBlankLine;
  EmitComment('--- fin du code genere ---');
  EmitBlankLine;
  { Sortie DOS : MOV AX,4C00h / INT 21h }
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT    21h');
  EmitBlankLine;
  { Routines runtime (TODO 24) }
  EmitRuntime;
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  { Segment de donnees }
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('        END    ' + LUA_FN_PFX + 'main');
  { Fermer le fichier de sortie }
  Close(OutF);
  OutFOpen := False;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAdd : ajouter une entree dans le segment DATA ----- }
{ Retourne l index dans DataTab ou -1 si plein.                }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAdd := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName   := Lbl;
  DataTab[Idx].Kind      := Kind;
  DataTab[Idx].IntVal    := AIntVal;
  DataTab[Idx].StrVal    := AStrVal;
  DataTab[Idx].ElemCount := 0;
  Inc(DataCount);
  DataAdd := Idx;
End;

{ ---- DataAddStr : creer une entree DK_STR pour une chaine -- }
{ Reutilise les doublons (meme contenu -> meme label).         }
{ Retourne le label (_LUAK_N) de l entree creee ou existante.  }
Function DataAddStr(Const S : TString) : TString;
Var
  I   : Integer;
  Lbl : TString;
  NS  : TString;
Begin
  { Deduplication : chercher une chaine identique deja presente }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := DataTab[I].LblName;
      Exit;
    End;
  { Nouvelle entree }
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  Lbl := LUA_STR_PFX + NS;
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DATA -------- }
{ Retourne l index dans DataTab ou -1 si plein.                }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- ExprMakeImm : construire une valeur immediate ---------- }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNone : expression sans valeur (void/erreur) ---- }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : valeur booleenne Lua (true=1, false=0) -- }
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_BOOLEAN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNil : valeur nil (AX=0, type nil) -------------- }
Procedure ExprMakeNil(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NIL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur --- }
{ IntVal est deja calcule par LexScanNumber (dec/hex).          }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);
End;

{ ---- LitEvalFloat : convertir un token TK_FLOAT en valeur -- }
{ Lua 8086 : les flottants sont tronques en entier 16 bits.     }
{ IntVal contient deja Trunc(FloatVal) depuis le lexeur.        }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ------ }
{ Types de tokens acceptes : TK_INTEGER, TK_FLOAT, TK_STRING,  }
{ TK_KEYWORD (nil/true/false).                                  }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.SymIdx  := -1;
      Res.Offset  := 0;
      { Stocker la chaine dans le segment DATA. Le label est cree/     }
      { reutilise par DataAddStr. Le code generation (TODO 10+) pourra }
      { retrouver le label via une recherche dans DataTab par contenu. }
      DataAddStr(T.Val);
    End;
    TK_KEYWORD :
    Begin
      If T.Val = 'nil' Then
        ExprMakeNil(Res)
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

{ ---- EmitDataSeg : emettre le segment _DATA dans le .ASM ---- }
{ Appele depuis EmitClose. Ecrit _DATA SEGMENT ... ENDS.        }
{ Emet aussi les chaines predefinies nil/true/false et buffers.  }
Procedure EmitDataSeg;
Var
  I     : Integer;
  J     : Integer;
  B     : Byte;
  NS    : String[6];
  InStr : Boolean;
  First : Boolean;
Begin
  If Not OutFOpen Then Exit;
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  { Chaines predefinies pour type() et tostring() }
  EmitRaw(LUA_NIL_LBL + '   DB ''nil'',0');
  EmitRaw(LUA_TRUE_LBL + '  DB ''true'',0');
  EmitRaw(LUA_FALSE_LBL + ' DB ''false'',0');
  { CRLF et buffer de travail }
  EmitRaw('_LUA_CRLF      DB 13,10,0');
  EmitRaw('_LUA_STRBUF    DB 256 DUP(0)');
  { Emettre les entrees de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        Str(DataTab[I].IntVal, NS);
        EmitRaw(DataTab[I].LblName + '  DW  ' + NS);
      End;
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        EmitRaw(DataTab[I].LblName + '  DB  ' + NS);
      End;
      DK_STR  :
      Begin
        { Emettre la chaine avec gestion des caracteres de controle }
        Write(OutF, DataTab[I].LblName, '  DB  ');
        InStr := False;
        First := True;
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          If (B >= 32) And (B < 127) And (DataTab[I].StrVal[J] <> '''') Then
          Begin
            { Caractere imprimable (pas apostrophe) }
            If Not InStr Then
            Begin
              If Not First Then Write(OutF, ',');
              Write(OutF, '''');
              InStr := True;
            End;
            Write(OutF, DataTab[I].StrVal[J]);
          End
          Else
          Begin
            { Caractere non imprimable ou apostrophe : valeur numerique }
            If InStr Then
            Begin
              Write(OutF, '''');
              InStr := False;
            End;
            If Not First Then Write(OutF, ',');
            Str(B, NS);
            Write(OutF, NS);
          End;
          First := False;
        End;
        If InStr Then Write(OutF, '''');
        WriteLn(OutF, ',0');
      End;
      DK_TABLE_BLK :
      Begin
        { TODO 15 : construction de tables }
        EmitRaw(DataTab[I].LblName + '  DW  0   ; table stub');
      End;
    End;
  End;
  EmitRaw('_DATA   ENDS');
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS LUA) [IMPLEMENTE]
  ============================================================ }

{ ---- IsKeyword : teste si S est un mot-cle Lua ------------- }
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'and')      Or (S = 'break')    Or (S = 'do')       Or
    (S = 'else')     Or (S = 'elseif')   Or (S = 'end')      Or
    (S = 'false')    Or (S = 'for')      Or (S = 'function') Or
    (S = 'goto')     Or (S = 'if')       Or (S = 'in')       Or
    (S = 'local')    Or (S = 'nil')      Or (S = 'not')      Or
    (S = 'or')       Or (S = 'repeat')   Or (S = 'return')   Or
    (S = 'then')     Or (S = 'true')     Or (S = 'until')    Or
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
    TK_FLOAT   : Write('FLOAT(', T.Val, ')');
    TK_STRING  : Write('STR("', T.Val, '")');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
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

{ ---- Fonctions de test sur les caracteres ------------------- }
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
{ Lua : decimaux, hexadecimaux (0x/0X), flottants, exposant    }
Procedure LexScanNumber;
Var
  N        : LongInt;
  IsFloat  : Boolean;
  NegExp   : Boolean;
  IsHex    : Boolean;
  Ch       : Char;
  FracDiv  : Real;
  FracVal  : Real;
  ExpVal   : Integer;
  FltVal   : Real;
Begin
  N       := 0;
  IsFloat := False;
  IsHex   := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  Ch      := LexLine[LexColNo];
  { Detecter prefixe 0x / 0X }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      IsHex := True;
      Inc(LexColNo); Inc(LexColNo);
    End;
  End;
  { Scanner la partie entiere }
  If IsHex Then
  Begin
    While (LexColNo <= Length(LexLine)) And IsHexDigit(LexLine[LexColNo]) Do
    Begin
      N := N * 16 + HexVal(LexLine[LexColNo]);
      Inc(LexColNo);
    End;
  End
  Else
  Begin
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
    Begin
      N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      Inc(LexColNo);
    End;
  End;
  { Partie decimale .ddd }
  If (Not IsHex) And (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo);
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
  If (Not IsHex) And (LexColNo <= Length(LexLine)) And
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
  { Hex flottant : 0x1.Fp10 -> avertissement + trunc }
  If IsHex And (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'p') Or (LexLine[LexColNo] = 'P')) Then
  Begin
    IsFloat := True;
    WarnMsg('hex float non supporte, tronque a entier');
    Inc(LexColNo);
    If (LexColNo <= Length(LexLine)) And
       ((LexLine[LexColNo] = '+') Or (LexLine[LexColNo] = '-')) Then
      Inc(LexColNo);
    While (LexColNo <= Length(LexLine)) And
          (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Inc(LexColNo);
  End;
  { Calculer la valeur finale (tronquee a entier 16 bits) }
  If IsFloat And (Not IsHex) Then
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

{ ---- LexScanEscChar : traiter une sequence d echappement --- }
{ Lua : \a \b \f \n \r \t \v \\ \' \" \xNN \ddd (decimal)     }
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
    'a'        : LexScanEscChar := #7;
    'b'        : LexScanEscChar := #8;
    'f'        : LexScanEscChar := #12;
    'n'        : LexScanEscChar := #10;
    'r'        : LexScanEscChar := #13;
    't'        : LexScanEscChar := #9;
    'v'        : LexScanEscChar := #11;
    '\'        : LexScanEscChar := '\';
    ''''       : LexScanEscChar := '''';
    '"'        : LexScanEscChar := '"';
    #10, #13   : LexScanEscChar := #10;
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
  Else
    { Lua : \ddd (1-3 chiffres decimaux, inclut \0, \065, etc.) }
    If (Ch >= '0') And (Ch <= '9') Then
    Begin
      V := Ord(Ch) - Ord('0');
      I := 1;
      While (I < 3) And (LexColNo <= Length(LexLine)) And
            (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
      Begin
        V := V * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
        Inc(LexColNo);
        Inc(I);
      End;
      LexScanEscChar := Chr(V And $FF);
    End
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
      { Note: \0 produit #0 ; on ne l ajoute pas car les chaines  }
      { Pascal terminee par longueur ne supportent pas bien le nul }
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

{ ---- LexLongBracketLevel : detecter [=*[ et retourner le    }
{ niveau (nombre de =). Retourne -1 si ce n est pas un long   }
{ bracket. LexColNo pointe sur le premier [.                   }
Function LexLongBracketLevel : Integer;
Var
  SaveCol : Integer;
  Level   : Integer;
Begin
  LexLongBracketLevel := -1;
  If (LexColNo > Length(LexLine)) Or (LexLine[LexColNo] <> '[') Then
    Exit;
  SaveCol := LexColNo;
  Inc(LexColNo);  { sauter premier [ }
  Level := 0;
  While (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Do
  Begin
    Inc(Level);
    Inc(LexColNo);
  End;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '[') Then
  Begin
    Inc(LexColNo);  { sauter deuxieme [ }
    LexLongBracketLevel := Level;
  End
  Else
  Begin
    { Ce n est pas un long bracket, restaurer la position }
    LexColNo := SaveCol;
  End;
End;

{ ---- LexScanLongString : scanner [[...]] ou [=[...]=] etc. - }
{ Level = nombre de = dans le delimiteur d ouverture.           }
{ LexColNo pointe apres le [=*[ ouvrant.                       }
Procedure LexScanLongString(Level : Integer);
Var
  S       : TString;
  Ch      : Char;
  MatchLv : Integer;
  Done    : Boolean;
  First   : Boolean;
Begin
  S := '';
  Done := False;
  First := True;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      { Saut de ligne dans la chaine longue }
      If (Not First) And (Length(S) < MAX_STR) Then
        S := S + #10;
      LexNextLine;
      First := False;
    End
    Else
    Begin
      Ch := LexLine[LexColNo];
      If Ch = ']' Then
      Begin
        { Verifier si c est le delimiteur fermant ]=*] }
        Inc(LexColNo);
        MatchLv := 0;
        While (LexColNo <= Length(LexLine)) And
              (LexLine[LexColNo] = '=') Do
        Begin
          Inc(MatchLv);
          Inc(LexColNo);
        End;
        If (MatchLv = Level) And (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = ']') Then
        Begin
          Inc(LexColNo); { sauter ] fermant }
          Done := True;
        End
        Else
        Begin
          { Pas le bon niveau, ajouter les chars au texte }
          If Length(S) < MAX_STR Then S := S + ']';
          While MatchLv > 0 Do
          Begin
            If Length(S) < MAX_STR Then S := S + '=';
            Dec(MatchLv);
          End;
        End;
      End
      Else
      Begin
        { Ignorer le premier saut de ligne apres l ouverture }
        If First And ((Ch = #10) Or (Ch = #13)) Then
        Begin
          Inc(LexColNo);
          First := False;
        End
        Else
        Begin
          If Length(S) < MAX_STR Then S := S + Ch;
          Inc(LexColNo);
          First := False;
        End;
      End;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexSkipLongComment : sauter --[=*[...]=*] ------------- }
{ Level = nombre de = dans le delimiteur d ouverture.           }
Procedure LexSkipLongComment(Level : Integer);
Var
  Ch      : Char;
  MatchLv : Integer;
  Done    : Boolean;
Begin
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else
    Begin
      Ch := LexLine[LexColNo];
      If Ch = ']' Then
      Begin
        Inc(LexColNo);
        MatchLv := 0;
        While (LexColNo <= Length(LexLine)) And
              (LexLine[LexColNo] = '=') Do
        Begin
          Inc(MatchLv);
          Inc(LexColNo);
        End;
        If (MatchLv = Level) And (LexColNo <= Length(LexLine)) And
           (LexLine[LexColNo] = ']') Then
        Begin
          Inc(LexColNo);
          Done := True;
        End;
      End
      Else
        Inc(LexColNo);
    End;
  End;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
Procedure LexNextToken;
Var
  Ch      : Char;
  Scanning : Boolean;
  SaveCol  : Integer;
  BLevel   : Integer;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Avancer jusqu a la prochaine ligne si fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    { Fin de fichier }
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

    { Espaces blancs }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire -- (ligne ou long) }
    Else If (Ch = '-') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '-') Then
    Begin
      Inc(LexColNo); Inc(LexColNo); { sauter -- }
      { Verifier si c est un commentaire long --[=*[ }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '[') Then
      Begin
        SaveCol := LexColNo;
        BLevel := LexLongBracketLevel;
        If BLevel >= 0 Then
        Begin
          { Commentaire long multi-lignes }
          LexSkipLongComment(BLevel);
        End
        Else
        Begin
          { Pas un long bracket, commentaire simple ligne }
          LexColNo := SaveCol;
          LexColNo := Length(LexLine) + 1;
        End;
      End
      Else
      Begin
        { Commentaire simple jusqu a fin de ligne }
        LexColNo := Length(LexLine) + 1;
      End;
    End

    { Identificateur ou mot-cle }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    { Nombre }
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Nombre .5 (point suivi de chiffre) }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    { Chaine simple-quote }
    Else If Ch = '''' Then
    Begin
      LexScanString('''');
      Scanning := False;
    End

    { Chaine double-quote }
    Else If Ch = '"' Then
    Begin
      LexScanString('"');
      Scanning := False;
    End

    { Chaine longue [[...]] ou [=[...]=] }
    Else If (Ch = '[') And (LexColNo < Length(LexLine)) And
            ((LexLine[LexColNo + 1] = '[') Or
             (LexLine[LexColNo + 1] = '=')) Then
    Begin
      SaveCol := LexColNo;
      BLevel := LexLongBracketLevel;
      If BLevel >= 0 Then
      Begin
        LexScanLongString(BLevel);
        Scanning := False;
      End
      Else
      Begin
        { Pas un long bracket, c est un [ normal (ponctuation) }
        LexColNo := SaveCol;
        CurToken.Kind := TK_PUNCT;
        CurToken.Val  := '[';
        Inc(LexColNo);
        Scanning := False;
      End;
    End

    { Concatenation .. ou varargs ... }
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '.') Then
    Begin
      Inc(LexColNo); Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := '...';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '..';
      End;
      Scanning := False;
    End

    { Point simple (acces membre) }
    Else If Ch = '.' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '.';
      Inc(LexColNo);
      Scanning := False;
    End

    { == }
    Else If (Ch = '=') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '==';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { = (affectation) }
    Else If Ch = '=' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '=';
      Inc(LexColNo);
      Scanning := False;
    End

    { ~= (different) }
    Else If (Ch = '~') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '~=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { ~ (bitwise NOT Lua 5.3+, stub) }
    Else If Ch = '~' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '~';
      Inc(LexColNo);
      Scanning := False;
    End

    { <= }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { << (bitwise shift left Lua 5.3+) }
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<<';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { < }
    Else If Ch = '<' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<';
      Inc(LexColNo);
      Scanning := False;
    End

    { >= }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { >> (bitwise shift right Lua 5.3+) }
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>>';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { > }
    Else If Ch = '>' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>';
      Inc(LexColNo);
      Scanning := False;
    End

    { // (division entiere Lua 5.3+) }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '//';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { Operateurs simples : + - * / % ^ # & | }
    Else If (Ch = '+') Or (Ch = '*') Or (Ch = '/') Or
            (Ch = '%') Or (Ch = '^') Or (Ch = '#') Or
            (Ch = '&') Or (Ch = '|') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { - (moins, pas commentaire car deja traite) }
    Else If Ch = '-' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '-';
      Inc(LexColNo);
      Scanning := False;
    End

    { :: (labels goto) }
    Else If (Ch = ':') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = ':') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '::';
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    { : (methode) }
    Else If Ch = ':' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := ':';
      Inc(LexColNo);
      Scanning := False;
    End

    { Ponctuation : ( ) [ ] ; , }
    Else If (Ch = '(') Or (Ch = ')') Or (Ch = '[') Or (Ch = ']') Or
            (Ch = ';') Or (Ch = ',') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      Scanning := False;
    End

    { Accolades : Chr(123)='(' et Chr(125)=')' car les accolades    }
    { literales interferent avec les commentaires Pascal              }
    Else If Ch = Chr(123) Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Chr(123);
      Inc(LexColNo);
      Scanning := False;
    End
    Else If Ch = Chr(125) Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Chr(125);
      Inc(LexColNo);
      Scanning := False;
    End

    { Caractere inconnu }
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;
  End;
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ------ }
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  { Lire la premiere ligne }
  LexNextLine;
  { Detecter shebang #!/... et le sauter }
  If (Not LexEOF) And (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
    LexColNo := Length(LexLine) + 1;
End;

{ ---- LexClose : fermer le fichier source -------------------- }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- BinOpPrec : table de precedences Lua (Pratt) ----------- }
{ Retourne 0 si l operateur n est pas binaire.                  }
{ Niveaux (croissant = plus serre) :                            }
{   or               -> 1  (OU logique, court-circuit)          }
{   and              -> 2  (ET logique, court-circuit)          }
{   < > <= >= ~= ==  -> 3  (comparaison)                       }
{   |                -> 4  (Lua 5.3+ bitwise OR, stub)         }
{   ~                -> 5  (Lua 5.3+ bitwise XOR, stub)        }
{   &                -> 6  (Lua 5.3+ bitwise AND, stub)        }
{   << >>            -> 7  (Lua 5.3+ decalages, stub)          }
{   ..               -> 8  (concatenation, droit-associatif)   }
{   + -              -> 9  (addition / soustraction)            }
{   * / // %         -> 10 (multiplication / division / modulo)  }
{   ^ (puissance)    -> 12 (droit-associatif)                  }
{   not # - (unaire) -> traites par ParseUnary (niveau 11)     }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If (Op = 'or') Then
    BinOpPrec := 1
  Else If (Op = 'and') Then
    BinOpPrec := 2
  Else If (Op = '<') Or (Op = '>') Or (Op = '<=') Or (Op = '>=') Or
          (Op = '~=') Or (Op = '==') Then
    BinOpPrec := 3
  Else If Op = '|' Then
    BinOpPrec := 4
  Else If Op = '~' Then
    BinOpPrec := 5
  Else If Op = '&' Then
    BinOpPrec := 6
  Else If (Op = '<<') Or (Op = '>>') Then
    BinOpPrec := 7
  Else If Op = '..' Then
    BinOpPrec := 8
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 9
  Else If (Op = '*') Or (Op = '/') Or (Op = '//') Or (Op = '%') Then
    BinOpPrec := 10
  Else If Op = '^' Then
    BinOpPrec := 12
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : associativite droite --------------------- }
{ En Lua : ^ (puissance) et .. (concatenation) sont a droite.   }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '^') Or (Op = '..');
End;

{ ---- ExprFlushToAX : forcer une TExprVal dans le registre AX  }
{ Stub pour TODO 07 (emetteur). Marque le resultat comme EK_AX. }
Procedure ExprFlushToAX(Const E : TExprVal);
Begin
  { TODO 07 : emettre le code reel }
  { EK_IMM  : MOV AX, ImmVal                   }
  { EK_MEM  : MOV AX, [BP+Offset] ou [label]   }
  { EK_AX   : deja dans AX                      }
  { EK_NONE : XOR AX, AX                        }
End;

{ ---- EmitBinOp : emettre le code pour un operateur binaire --- }
{ Stub pour TODO 07. L = AX, R = BX -> resultat dans AX.        }
{ Pour les operateurs arithmetiques :                            }
{   + -> ADD AX,BX   - -> SUB AX,BX   * -> IMUL BX             }
{   / -> CWD IDIV BX (quotient AX)   % -> CWD IDIV BX MOV AX,DX }
{   // -> CWD IDIV BX (div entiere)                              }
{   ^ -> CALL _LUART_POW   .. -> CALL _LUART_CONCAT             }
{ Pour les comparaisons : CMP AX,BX + Jcc                       }
{ Pour les bitwise (5.3+) : AND/OR/XOR/SAL/SAR                  }
Procedure EmitBinOp(Const Op : TString;
                    Var L : TExprVal; Const R : TExprVal);
Begin
  { Stub : marquer le resultat dans AX }
  L.Kind := EK_AX;
End;

{ ---- ParsePrimary : atome du parseur Pratt ------------------- }
{ Gere : literals (int, float, string), nil, true, false,       }
{ identifiant (stub), parentheses, constructeur de table (stub)  }
Procedure ParsePrimary(Var Res : TExprVal);
Begin
  Case CurToken.Kind Of
    TK_INTEGER, TK_FLOAT, TK_STRING :
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
      Else If CurToken.Val = 'function' Then
      Begin
        { Fonction anonyme : stub, sera TODO 13 }
        ExprMakeNone(Res);
        ParserAdvance;
        { Sauter les tokens jusqu a end }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'end') Then
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
      { TODO 09 : resoudre la variable dans SymTab }
      { Pour l instant, stub EK_AX type inconnu }
      Res.Kind    := EK_AX;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_UNKNOWN;
      Res.Offset  := 0;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;   { consomme '(' }
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance  { consomme ')' }
        Else
          CompileError('")" attendue');
      End
      Else If CurToken.Val = Chr(123) Then
      Begin
        { Constructeur de table : stub, sera TODO 15 }
        If Opts.Warnings Then
          WarnMsg('constructeur de table : stub, sera TODO 15');
        ParserAdvance;   { consomme Chr(123) = open brace }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And
                   (CurToken.Val = Chr(125))) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = Chr(125)) Then
          ParserAdvance;   { consomme Chr(125) = close brace }
        ExprMakeNone(Res);
        Res.TypeIdx := TY_IDX_TABLE;
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

{ ---- ParseUnary : operateurs unaires prefixes Lua ----------- }
{ Lua a trois operateurs unaires :                               }
{   - (negation arithmetique)                                    }
{   not (negation logique : retourne true/false)                 }
{   # (longueur : chaine ou table -> CALL _LUART_LEN)           }
{   ~ (Lua 5.3+ bitwise NOT, stub)                              }
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op : TString;
Begin
  { Unaire prefixe : - }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '-') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);  { recursion pour chainage de unaires }
    If Res.Kind = EK_IMM Then
      Res.ImmVal := -Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      { TODO 07 : NEG AX }
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_NUMBER;
    End;
    Exit;
  End;
  { Unaire prefixe : # (longueur) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '#') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      { Longueur d un litteral de chaine : constante pliable }
      { Mais #nil ou #42 est une erreur Lua, on accepte stub }
      If Res.TypeIdx = TY_IDX_STRING Then
        { Pas fiable ici, stub -> AX }
        Res.Kind := EK_AX
      Else
      Begin
        { Pour un nombre, # n a pas de sens : warning }
        If Opts.Warnings Then
          WarnMsg('# applique a un non-string/table');
        Res.Kind := EK_AX;
      End;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      { TODO 07 : CALL _LUART_LEN }
      Res.Kind := EK_AX;
    End;
    Res.TypeIdx := TY_IDX_NUMBER;
    Exit;
  End;
  { Unaire prefixe : not (mot-cle) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      { Lua : not false -> true, not nil -> true, tout le reste -> false }
      If (Res.TypeIdx = TY_IDX_NIL) Or
         ((Res.TypeIdx = TY_IDX_BOOLEAN) And (Res.ImmVal = 0)) Then
        ExprMakeBool(1, Res)
      Else
        ExprMakeBool(0, Res);
    End
    Else
    Begin
      ExprFlushToAX(Res);
      { TODO 07 : OR AX,AX / SETZ AL / MOVZX AX,AL ou equiv. }
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
    End;
    Exit;
  End;
  { Unaire prefixe : ~ (Lua 5.3+ bitwise NOT, stub) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '~') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Opts.Warnings Then
      WarnMsg('~ (bitwise NOT Lua 5.3+) : stub 16 bits');
    If Res.Kind = EK_IMM Then
      Res.ImmVal := Not Res.ImmVal
    Else
    Begin
      ExprFlushToAX(Res);
      { TODO 07 : NOT AX }
      Res.Kind := EK_AX;
    End;
    Res.TypeIdx := TY_IDX_NUMBER;
    Exit;
  End;
  { Pas d operateur unaire : appeler ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur de Pratt pour expressions Lua --- }
{ MinPrec = niveau de precedence minimal a capturer.             }
{ Boucle de montee de precedence avec pliage de constantes,      }
{ court-circuit pour and/or, et associativite droite pour ^/.. . }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  Right    : TExprVal;
  FoldOk   : Boolean;
  ShiftAmt : Integer;
  LblSkip  : TString;
  LblEnd   : TString;
  NS       : TString;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    { Detecter operateur binaire sur TK_OP }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    { Detecter and/or sur TK_KEYWORD }
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'and') Or (CurToken.Val = 'or')) Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End;

    { Arreter si pas un operateur binaire ou priorite insuffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    ParserAdvance;  { consomme l operateur }

    { Avertissements Lua 5.3+ bitwise stubs }
    If (Op = '|') Or (Op = '&') Or (Op = '<<') Or (Op = '>>') Then
    Begin
      If Opts.Warnings Then
        WarnMsg(Op + ' (bitwise Lua 5.3+) : stub 16 bits');
    End;
    { ~ en position binaire = xor Lua 5.3+ }
    If Op = '~' Then
    Begin
      If Opts.Warnings Then
        WarnMsg('~ (bitwise XOR Lua 5.3+) : stub 16 bits');
    End;

    { ---- Court-circuit pour and / or ---- }
    { Lua : and retourne le premier faux, or retourne le premier vrai }
    If Op = 'and' Then
    Begin
      If (Res.Kind = EK_IMM) Then
      Begin
        { Pliage : si gauche est nil ou false -> retourner gauche }
        If (Res.TypeIdx = TY_IDX_NIL) Or
           ((Res.TypeIdx = TY_IDX_BOOLEAN) And (Res.ImmVal = 0)) Then
        Begin
          { Gauche est falsy -> ignorer droite (mais la parser) }
          ParseExprPrec(Prec + 1, Right);
          { Res reste inchange (falsy) }
        End
        Else
        Begin
          { Gauche est truthy -> retourner droite }
          ParseExprPrec(Prec + 1, Right);
          Res := Right;
        End;
      End
      Else
      Begin
        { Non constant : generer code avec court-circuit }
        ExprFlushToAX(Res);
        { TODO 07 : OR AX,AX / JZ LblSkip / ... / LblSkip: }
        ParseExprPrec(Prec + 1, Right);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
      End;
      Continue;
    End;

    If Op = 'or' Then
    Begin
      If (Res.Kind = EK_IMM) Then
      Begin
        { Pliage : si gauche est truthy -> retourner gauche }
        If Not ((Res.TypeIdx = TY_IDX_NIL) Or
                ((Res.TypeIdx = TY_IDX_BOOLEAN) And (Res.ImmVal = 0))) Then
        Begin
          { Gauche est truthy -> ignorer droite (mais la parser) }
          ParseExprPrec(Prec + 1, Right);
          { Res reste inchange (truthy) }
        End
        Else
        Begin
          { Gauche est falsy -> retourner droite }
          ParseExprPrec(Prec + 1, Right);
          Res := Right;
        End;
      End
      Else
      Begin
        { Non constant : generer code avec court-circuit }
        ExprFlushToAX(Res);
        { TODO 07 : OR AX,AX / JNZ LblSkip / ... / LblSkip: }
        ParseExprPrec(Prec + 1, Right);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
      End;
      Continue;
    End;

    { ---- Concatenation .. ---- }
    If Op = '..' Then
    Begin
      { Associatif a droite : recurser avec meme precedence }
      ParseExprPrec(Prec, Right);
      If (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM) And
         (Res.TypeIdx = TY_IDX_STRING) And (Right.TypeIdx = TY_IDX_STRING) Then
      Begin
        { Pliage impossible car on n a que les indices DATA, pas les chaines }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
      End
      Else
      Begin
        { TODO 07 : CALL _LUART_CONCAT }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
      End;
      Continue;
    End;

    { ---- Puissance ^ (droit-associatif) ---- }
    If Op = '^' Then
    Begin
      ParseExprPrec(Prec, Right);
      If (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM) Then
      Begin
        { Pliage simple : petites puissances entieres }
        If Right.ImmVal = 0 Then
          ExprMakeImm(1, TY_IDX_NUMBER, Res)
        Else If Right.ImmVal = 1 Then
          { Res reste inchange }
        Else If Right.ImmVal = 2 Then
          ExprMakeImm(Res.ImmVal * Res.ImmVal, TY_IDX_NUMBER, Res)
        Else
        Begin
          { TODO 07 : CALL _LUART_POW }
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_IDX_NUMBER;
        End;
      End
      Else
      Begin
        { TODO 07 : CALL _LUART_POW }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_NUMBER;
      End;
      Continue;
    End;

    { ---- Operateurs binaires generiques ---- }
    { Recurser cote droit avec precedence ajustee }
    If BinOpIsRight(Op) Then
      ParseExprPrec(Prec, Right)
    Else
      ParseExprPrec(Prec + 1, Right);

    { Pliage de constantes si les deux membres sont immediats }
    FoldOk := (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM);
    If FoldOk Then
    Begin
      { Arithmetique }
      If Op = '+' Then
        ExprMakeImm(Res.ImmVal + Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '-' Then
        ExprMakeImm(Res.ImmVal - Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '*' Then
        ExprMakeImm(Res.ImmVal * Right.ImmVal, TY_IDX_NUMBER, Res)
      { Lua : / est une division flottante, mais en 8086 16 bits }
      { on n a pas de FPU -> traite comme division entiere (Div) }
      Else If (Op = '/') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_NUMBER, Res)
      { // est la division entiere plancher (floor division) en Lua }
      Else If (Op = '//') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If (Op = '%') And (Right.ImmVal <> 0) Then
        ExprMakeImm(Res.ImmVal Mod Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If (Op = '/') And (Right.ImmVal = 0) Then
      Begin
        CompileError('division par zero');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      Else If ((Op = '//') Or (Op = '%')) And (Right.ImmVal = 0) Then
      Begin
        CompileError('division par zero');
        ExprMakeImm(0, TY_IDX_NUMBER, Res);
      End
      { Comparaisons }
      Else If Op = '==' Then
        ExprMakeBool(Ord(Res.ImmVal = Right.ImmVal), Res)
      Else If Op = '~=' Then
        ExprMakeBool(Ord(Res.ImmVal <> Right.ImmVal), Res)
      Else If Op = '<' Then
        ExprMakeBool(Ord(Res.ImmVal < Right.ImmVal), Res)
      Else If Op = '<=' Then
        ExprMakeBool(Ord(Res.ImmVal <= Right.ImmVal), Res)
      Else If Op = '>' Then
        ExprMakeBool(Ord(Res.ImmVal > Right.ImmVal), Res)
      Else If Op = '>=' Then
        ExprMakeBool(Ord(Res.ImmVal >= Right.ImmVal), Res)
      { Bitwise Lua 5.3+ }
      Else If Op = '&' Then
        ExprMakeImm(Res.ImmVal And Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '|' Then
        ExprMakeImm(Res.ImmVal Or Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '~' Then
        ExprMakeImm(Res.ImmVal Xor Right.ImmVal, TY_IDX_NUMBER, Res)
      Else If Op = '<<' Then
      Begin
        { Masque a 15 pour registre 16 bits (0..15 positions valides) }
        ShiftAmt := Integer(Right.ImmVal And 15);
        ExprMakeImm(Res.ImmVal Shl ShiftAmt, TY_IDX_NUMBER, Res);
      End
      Else If Op = '>>' Then
      Begin
        ShiftAmt := Integer(Right.ImmVal And 15);
        ExprMakeImm(Res.ImmVal Shr ShiftAmt, TY_IDX_NUMBER, Res);
      End
      Else
      Begin
        { Operateur non pliable : resultat dans AX }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_NUMBER;
      End;
    End
    Else
    Begin
      { Non constant : resultat dans AX (code emis par TODO 07) }
      EmitBinOp(Op, Res, Right);
      Res.Kind := EK_AX;
      { Determiner le type resultat }
      If (Op = '==') Or (Op = '~=') Or (Op = '<') Or (Op = '<=') Or
         (Op = '>') Or (Op = '>=') Then
        Res.TypeIdx := TY_IDX_BOOLEAN
      Else
        Res.TypeIdx := TY_IDX_NUMBER;
    End;
  Until False;
End;

{ ---- ParseExpr : point d entree principal pour les expressions }
{ En Lua, pas d operateur virgule : c est juste ParseExprPrec(1). }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ---- ParserAdvance : lire le prochain token et afficher ----- }
Procedure ParserAdvance;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour MASM ---------------- }
{ Remplace les caracteres non alphanumeriques par '_'.           }
{ Lua autorise lettres, chiffres et underscore (pas de $).       }
Function SymNameClean(Const Name : TString) : TString;
Var
  I : Integer;
  R : TString;
  C : Char;
Begin
  R := '';
  For I := 1 To Length(Name) Do
  Begin
    C := Name[I];
    If ((C >= 'A') And (C <= 'Z')) Or
       ((C >= 'a') And (C <= 'z')) Or
       ((C >= '0') And (C <= '9')) Or
       (C = '_') Then
    Begin
      If Length(R) < MAX_STR Then
        R := R + C;
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

{ ---- SymMangle : calculer le nom ASM mangled selon le kind ---- }
{ Prefixes :                                                       }
{   SK_LOCAL    -> _LUAV_ (variable locale, acces par [BP-n])      }
{   SK_GLOBAL   -> _LUAV_ (variable globale, acces par label DATA) }
{   SK_PARAM    -> _LUAV_ (parametre formel, acces par [BP+n])     }
{   SK_UPVALUE  -> _LUAU_ (variable capturee par closure)          }
{   SK_FUNCTION -> _LUAF_ (fonction)                               }
{   SK_LABEL    -> _LUAL_ (label goto)                             }
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_FUNCTION : SymMangle := LUA_FN_PFX  + Clean;
    SK_LABEL    : SymMangle := LUA_LBL_PFX + Clean;
    SK_UPVALUE  : SymMangle := LUA_UP_PFX  + Clean;
  Else
    SymMangle := LUA_VAR_PFX + Clean;
  End;
End;

{ ---- SymFind : chercher un symbole par nom (MRU, interne->externe) }
{ Retourne l indice dans SymTab ou -1 si introuvable.                 }
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

{ ---- SymFindInScope : chercher un symbole dans une portee donnee }
{ Retourne l indice ou -1.                                          }
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

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
{ Retourne l indice du symbole (0-base) ou -1 en cas d erreur.   }
Function SymAdd(Const Name : TString; Kind : TSymKind;
                ATypeIdx : Integer; AOffset : Integer) : Integer;
Var
  NS : TString;
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
  SymTab[SymCount].TypeIdx     := ATypeIdx;
  SymTab[SymCount].ScopeLevel  := CurScope;
  SymTab[SymCount].Offset      := AOffset;
  SymTab[SymCount].IsLocal     := (Kind = SK_LOCAL) Or (Kind = SK_PARAM);
  SymTab[SymCount].IsUpvalue   := (Kind = SK_UPVALUE);
  SymTab[SymCount].DeclLine    := CurToken.Line;
  If Opts.DebugMode Then
  Begin
    Str(SymCount, NS);
    WriteLn('  SYM[', NS, '] ', Name, ' -> ', SymTab[SymCount].MangledName,
            ' scope=', CurScope);
  End;
  SymAdd := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee de bloc -- }
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
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante --------------- }
{ Les symboles locaux du bloc sont retires de la table.           }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ---- SymInit : initialisation de la table des symboles --------- }
{ Predeclare les fonctions et modules de la bibliotheque standard   }
{ Lua au niveau du scope global (0).                                }
Procedure SymInit;
Var
  I   : Integer;
  Idx : Integer;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  LabelSeq := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].MangledName := '';
    SymTab[I].Kind        := SK_GLOBAL;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsLocal     := False;
    SymTab[I].IsUpvalue   := False;
    SymTab[I].DeclLine    := 0;
  End;

  { ---- Fonctions globales predefinies (Lua standard library) ---- }
  { E/S de base }
  Idx := SymAdd('print',          SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('io',             SK_GLOBAL,   TY_IDX_TABLE,    0);
  { Conversion de types }
  Idx := SymAdd('type',           SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('tostring',       SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('tonumber',       SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Controle }
  Idx := SymAdd('assert',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('error',          SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('pcall',          SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('xpcall',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Iterateurs }
  Idx := SymAdd('pairs',          SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('ipairs',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('next',           SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Divers }
  Idx := SymAdd('select',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('unpack',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('rawget',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('rawset',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('rawlen',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('rawequal',       SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('setmetatable',   SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('getmetatable',   SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Chargement de modules }
  Idx := SymAdd('require',        SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('dofile',         SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('loadfile',       SK_FUNCTION, TY_IDX_FUNCTION, 0);
  Idx := SymAdd('load',           SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Gestion memoire }
  Idx := SymAdd('collectgarbage', SK_FUNCTION, TY_IDX_FUNCTION, 0);
  { Coroutines }
  Idx := SymAdd('coroutine',      SK_GLOBAL,   TY_IDX_TABLE,    0);

  { ---- Modules de bibliotheque standard (tables) ---- }
  Idx := SymAdd('string',         SK_GLOBAL,   TY_IDX_TABLE,    0);
  Idx := SymAdd('table',          SK_GLOBAL,   TY_IDX_TABLE,    0);
  Idx := SymAdd('math',           SK_GLOBAL,   TY_IDX_TABLE,    0);
  Idx := SymAdd('os',             SK_GLOBAL,   TY_IDX_TABLE,    0);

  { ---- Variables globales predefinies ---- }
  Idx := SymAdd('_G',             SK_GLOBAL,   TY_IDX_TABLE,    0);
  Idx := SymAdd('_VERSION',       SK_GLOBAL,   TY_IDX_STRING,   0);
  Idx := SymAdd('arg',            SK_GLOBAL,   TY_IDX_TABLE,    0);
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindOf : retourner le TTypeKind associe a un indice ----- }
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d un type (16 bits = 2) ------- }
{ En Lua 16-bit : number = 2 octets, tous les pointeurs = 2 octets.  }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  { defaut : mot 16-bit }
End;

{ ---- TypeMangle : prefixe ASM selon le type pour les labels ------- }
{ Utilise pour generer des labels specifiques au type.                 }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_NIL      : TypeMangle := '_LUANL_'; { nil    }
    TYK_BOOLEAN  : TypeMangle := '_LUAB_';  { bool   }
    TYK_NUMBER   : TypeMangle := '_LUAN_';  { number }
    TYK_STRING   : TypeMangle := '_LUAS_';  { string }
    TYK_TABLE    : TypeMangle := '_LUAT_';  { table  }
    TYK_FUNCTION : TypeMangle := '_LUAF_';  { func   }
    TYK_USERDATA : TypeMangle := '_LUAU_';  { udata  }
  Else
    TypeMangle := '_LUAX_'; { inconnu / polymorphe }
  End;
End;

{ ---- TypeIsNumeric : vrai si le type est interpretable comme nombre  }
{ En Lua, seuls number et boolean (false=0, true=1) sont numeriques.   }
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric := (K = TYK_NUMBER) Or (K = TYK_BOOLEAN);
End;

{ ---- TypeIsPtr : vrai si le type est un pointeur (reference) ------- }
{ string = ptr vers chaine terminee par 0                               }
{ table  = ptr vers structure table                                     }
{ function = ptr vers code                                              }
{ userdata = ptr opaque                                                 }
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (K = TYK_STRING)   Or (K = TYK_TABLE) Or
    (K = TYK_FUNCTION) Or (K = TYK_USERDATA);
End;

{ ---- TypeIsTruthy : semantique de verite Lua ----------------------- }
{ En Lua, seuls nil et false sont faux (falsy).                         }
{ Tout le reste est vrai (truthy) : 0, "", table vide = truthy !        }
{ Note : pour TYK_BOOLEAN, on retourne False car la verite depend       }
{   de la valeur a l execution (false=falsy, true=truthy).              }
{   Pour TYK_UNKNOWN, meme chose : verification a l execution.         }
Function TypeIsTruthy(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  Case K Of
    TYK_NIL     : TypeIsTruthy := False;  { nil est toujours faux }
    TYK_BOOLEAN : TypeIsTruthy := False;  { faux si false, vrai si true -> runtime }
    TYK_UNKNOWN : TypeIsTruthy := False;  { inconnu -> doit verifier a l execution }
  Else
    TypeIsTruthy := True;  { number, string, table, function, userdata = vrai }
  End;
End;

{ ---- TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx ? -------- }
{ Lua a une coercition automatique entre nombres et chaines :            }
{   - string -> number : tostring peut etre interprete comme nombre     }
{   - number -> string : tostring() implicite pour concatenation        }
{ nil/boolean ne sont PAS coercibles vers number en Lua (contrairement  }
{   a JavaScript).                                                       }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
Begin
  { Meme type : toujours OK }
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { anything -> UNKNOWN : on perd l info de type }
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { UNKNOWN -> anything : typage dynamique, on accepte }
  If SrcIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  { Coercition automatique Lua : string <-> number }
  If (SK = TYK_STRING) And (DK = TYK_NUMBER) Then
  Begin
    TypeCanCoerce := True;  { tonumber implicite }
    Exit;
  End;
  If (SK = TYK_NUMBER) And (DK = TYK_STRING) Then
  Begin
    TypeCanCoerce := True;  { tostring implicite }
    Exit;
  End;
  { boolean -> number : false=0, true=1 (pas standard Lua mais utile) }
  If (SK = TYK_BOOLEAN) And (DK = TYK_NUMBER) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Pas de coercition automatique pour les autres types }
  TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type de resultat d une operation binaire ---- }
{ Determine le type resultant selon les types des operandes et           }
{ l operateur utilise.                                                    }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);

  { Operateurs de comparaison : resultat toujours boolean }
  If (Op = '==') Or (Op = '~=') Or
     (Op = '<')  Or (Op = '<=') Or
     (Op = '>')  Or (Op = '>=') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;

  { Operateurs logiques 'and' / 'or' : retournent une des operandes }
  { En Lua, 'and' retourne le premier faux ou le dernier vrai         }
  {          'or' retourne le premier vrai ou le dernier faux          }
  If Op = 'and' Then
  Begin
    { Si le gauche peut etre falsy -> type du gauche, sinon type du droit }
    If (LK = TYK_NIL) Or (LK = TYK_BOOLEAN) Or (LK = TYK_UNKNOWN) Then
      TypeCoerceResult := TY_UNKNOWN  { dynamique }
    Else
      TypeCoerceResult := RightIdx;
    Exit;
  End;
  If Op = 'or' Then
  Begin
    If (LK = TYK_NIL) Or (LK = TYK_BOOLEAN) Or (LK = TYK_UNKNOWN) Then
      TypeCoerceResult := TY_UNKNOWN  { dynamique }
    Else
      TypeCoerceResult := LeftIdx;
    Exit;
  End;

  { Concatenation '..' : resultat toujours string }
  If Op = '..' Then
  Begin
    TypeCoerceResult := TY_IDX_STRING;
    Exit;
  End;

  { Operateurs arithmetiques : + - * / % ^ // }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Or (Op = '^') Or
     (Op = '//') Then
  Begin
    { Si les deux sont numeriques ou coercibles -> number }
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    Begin
      TypeCoerceResult := TY_IDX_NUMBER;
      Exit;
    End;
    { Coercition string->number automatique en Lua }
    If ((LK = TYK_NUMBER) Or (LK = TYK_STRING)) And
       ((RK = TYK_NUMBER) Or (RK = TYK_STRING)) Then
    Begin
      TypeCoerceResult := TY_IDX_NUMBER;
      Exit;
    End;
    { Sinon : polymorphe }
    TypeCoerceResult := TY_UNKNOWN;
    Exit;
  End;

  { Operateurs bit a bit Lua 5.3+ : & | ~ << >> }
  If (Op = '&')  Or (Op = '|')  Or (Op = '~') Or
     (Op = '<<') Or (Op = '>>') Then
  Begin
    TypeCoerceResult := TY_IDX_NUMBER;
    Exit;
  End;

  { Assignation et defaut : type du cote droit }
  TypeCoerceResult := RightIdx;
End;

{ ---- TypeInfer : inferer le type d une expression ------------------- }
{ Retourne l indice de type le plus probable pour une TExprVal donnee.   }
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      { Une valeur immediate est un nombre entier }
      TypeInfer := TY_IDX_NUMBER;
      Exit;
    End;
    EK_AX, EK_MEM :
    Begin
      { Si le TypeIdx est deja connu, le retourner }
      If E.TypeIdx <> TY_UNKNOWN Then
      Begin
        TypeInfer := E.TypeIdx;
        Exit;
      End;
    End;
  End;
  { Par defaut en Lua : typage dynamique -> UNKNOWN }
  TypeInfer := TY_UNKNOWN;
End;

{ ---- TypeLookupName : chercher un type par nom ---------------------- }
{ Retourne l indice dans TypeTab ou TY_UNKNOWN si introuvable.           }
{ Lua est sensible a la casse.                                           }
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

{ ---- TypeInit : initialisation de la table des types ---------------- }
{ Enregistre les 7 types primitifs Lua dans TypeTab.                     }
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
  { nil : valeur speciale, occupe 2 octets en memoire (tag de type) }
  TypeTab[TY_IDX_NIL].Name      := 'nil';
  TypeTab[TY_IDX_NIL].Kind      := TYK_NIL;
  TypeTab[TY_IDX_NIL].Size      := 2;
  { boolean : true/false, 2 octets (0 ou 1) }
  TypeTab[TY_IDX_BOOLEAN].Name  := 'boolean';
  TypeTab[TY_IDX_BOOLEAN].Kind  := TYK_BOOLEAN;
  TypeTab[TY_IDX_BOOLEAN].Size  := 2;
  { number : entier 16 bits signe }
  TypeTab[TY_IDX_NUMBER].Name   := 'number';
  TypeTab[TY_IDX_NUMBER].Kind   := TYK_NUMBER;
  TypeTab[TY_IDX_NUMBER].Size   := 2;
  { string : pointeur vers chaine terminee par 0 }
  TypeTab[TY_IDX_STRING].Name   := 'string';
  TypeTab[TY_IDX_STRING].Kind   := TYK_STRING;
  TypeTab[TY_IDX_STRING].Size   := 2;
  { table : pointeur vers structure table (array / hash) }
  TypeTab[TY_IDX_TABLE].Name    := 'table';
  TypeTab[TY_IDX_TABLE].Kind    := TYK_TABLE;
  TypeTab[TY_IDX_TABLE].Size    := 2;
  { function : pointeur vers code }
  TypeTab[TY_IDX_FUNCTION].Name := 'function';
  TypeTab[TY_IDX_FUNCTION].Kind := TYK_FUNCTION;
  TypeTab[TY_IDX_FUNCTION].Size := 2;
  { userdata : pointeur opaque (stub pour extensions C) }
  TypeTab[TY_IDX_USERDATA].Name := 'userdata';
  TypeTab[TY_IDX_USERDATA].Kind := TYK_USERDATA;
  TypeTab[TY_IDX_USERDATA].Size := 2;

  TypeCount := TY_PRIM_COUNT;
End;

{ ---- Run : pipeline de compilation ----------------------------- }

Procedure Run;
Var
  E : TExprVal;
Begin
  EmitOpen;     { ouvrir le fichier de sortie }
  EmitHeader;   { emettre le preambule ASM }
  LexInit;
  ParserAdvance;  { lire le premier token }

  { Boucle principale : parser les expressions / instructions }
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Parser une expression et la consommer }
    ParseExpr(E);
    { Consommer le ';' optionnel (separateur d instructions en Lua) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;

  LexClose;
  EmitClose;   { EmitDataSeg est appele depuis EmitClose }
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  GlobalInit;
  ParseArgs;
  If Opts.Verbose Then ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then
  Begin
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
