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

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
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

  TODO 06 - SYSTEME DE TYPES
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

  TODO 07 - EMETTEUR DE CODE ASM
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
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
End;

{ ============================================================
  STUBS POUR TODOS 04-25 (emetteur / donnees)
  ============================================================ }

Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
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
{ Appele depuis EmitClose / Run. Ecrit _DATA SEGMENT ... ENDS.  }
{ Emet aussi les chaines predefinies nil/true/false.             }
Procedure EmitDataSeg;
Var
  I  : Integer;
  J  : Integer;
  B  : Byte;
  NS : String[6];
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT WORD PUBLIC ', Chr(39), 'DATA', Chr(39));
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  { Chaines predefinies pour type() et tostring() }
  WriteLn(OutF, LUA_NIL_LBL, ':');
  WriteLn(OutF, '        DB      ', Chr(39), 'nil', Chr(39), ',0');
  WriteLn(OutF, LUA_TRUE_LBL, ':');
  WriteLn(OutF, '        DB      ', Chr(39), 'true', Chr(39), ',0');
  WriteLn(OutF, LUA_FALSE_LBL, ':');
  WriteLn(OutF, '        DB      ', Chr(39), 'false', Chr(39), ',0');
  { Emettre les entrees de DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    WriteLn(OutF, DataTab[I].LblName, ':');
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, '        DW      ', NS);
      End;
      DK_BYTE :
      Begin
        Str(DataTab[I].IntVal And $FF, NS);
        WriteLn(OutF, '        DB      ', NS);
      End;
      DK_STR  :
      Begin
        Write(OutF, '        DB      ');
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          B := Ord(DataTab[I].StrVal[J]);
          Str(B, NS);
          If J > 1 Then Write(OutF, ',');
          Write(OutF, NS);
        End;
        WriteLn(OutF, ',0');
      End;
      DK_TABLE_BLK :
      Begin
        { TODO 15 : construction de tables }
        WriteLn(OutF, '        DW      0  ; table stub');
      End;
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
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

{ ---- ParserAdvance : lire le prochain token et afficher ----- }
Procedure ParserAdvance;
Begin
  LexNextToken;
  PrintToken(CurToken);
End;

{ ---- Run : pipeline de compilation (stub pour TODO 03-25) --- }

Procedure Run;
Begin
  LexInit;
  ParserAdvance;  { lire le premier token }

  { Pour l instant (stubs TODO 03-25), on boucle juste sur les tokens }
  While CurToken.Kind <> TK_EOF Do
    ParserAdvance;

  LexClose;
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
