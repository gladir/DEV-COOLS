{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur AWK vers assembleur 8086
}

(* ============================================================
  AWK86.PAS - Compilateur AWK vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, FieldSep, Warnings)
            ParseArgs : analyser argv (script.awk [sortie.asm] [-v] [-d] [-w])
            Option -F sep : separateur de champs (defaut espace/tabulation)
            Option -v var=val : initialisation de variables avant BEGIN
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .awk ou .AWK
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS AWK) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_REGEXP, TK_IDENT, TK_KEYWORD, TK_BUILTIN,
              TK_FIELD (reference $n), TK_OP, TK_PUNCT, TK_NEWLINE
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets doubles "abc"
              Sequences d echappement : \n \t \r \\ \" \a \b \f \/ \xNN
            LexScanRegexp : /pattern/ apres ~ !~ , ( = return
              Distinction slash-division vs slash-regexp par contexte lexical
            LexScanField : $0 $1 $NF $(expr) -> TK_FIELD
            Commentaires : # jusqu a fin de ligne
            Continuation de ligne : \ en fin de ligne -> concatener
            Mots-cles : BEGIN END if else while for do in
              break continue function return delete exit
              getline next nextfile print printf sprintf
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (valeur 16 bits)
            Entiers octaux : 0377 (prefixe 0)
            Entiers hexadecimaux : 0xFF (prefixe 0x)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Notation scientifique : 1.5e3 -> 1500 (trunc)
            Chaines double-quote : "abc\ndef" avec echappement
            Expressions regulieres : /pattern/ -> TK_REGEXP
              Stockees comme chaines constantes en DATA
            Chaine vide "" : equivalent de faux en contexte booleen
            Valeur non initialisee : "" (chaine vide) ou 0 selon contexte

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques   : + - * / % ^ (puissance)
            Concatenation   : espace implicite entre deux expressions (juxtaposition)
            Assignation     : = += -= *= /= %= ^=
            Comparaison     : == != < <= > >=
            Correspondance  : ~ (match) !~ (not match) avec /regexp/
            Logiques        : && || ! (court-circuit -> labels _AWL_NNNN)
            Ternaire        : cond ? a : b -> labels _AWL_TERN_N
            Unaire          : + - ! ++ -- (prefixe et suffixe)
            Appartenance    : (key in array) -> test dans tableau associatif
            Pipe de sortie  : | (cmd) dans print -> stub + avertissement
            Redirection     : > >> (dans print/printf) -> ecriture fichier
            Getline         : getline [var] [< fichier] -> lecture
            Precedence (du plus fort au plus faible) :
              1. $ (champ), () groupement
              2. ^ (puissance, associatif droite)
              3. unaire + - !  ++ --
              4. * / %
              5. + - (binaire)
              6. espace (concatenation de chaines)
              7. < <= > >= != == ~ !~
              8. in (appartenance tableau)
              9. && (ET logique)
             10. || (OU logique)
             11. ? : (ternaire)
             12. = += -= *= /= %= ^= (assignation)

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymCat : SC_VAR (variable utilisateur), SC_BUILTIN_VAR,
              SC_ARRAY (tableau associatif), SC_PARAM, SC_FUNCTION,
              SC_FIELD (champ $n)
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset,
              IsLocal, IsParam, IsArray, ArrayIdx
            SymAdd, SymFind, SymFindCat, SymMangle
            Variables predefinies (SC_BUILTIN_VAR) :
              FS, RS, OFS, ORS, NR, NF, FNR, FILENAME,
              RSTART, RLENGTH, SUBSEP, OFMT, CONVFMT, ARGC, ARGV
            CurScope : compteur de portee (global=0, fonction>0)
            SymEnterScope / SymLeaveScope : gestion des portees de fonctions
            Prefixe ASM : _AWV_ (variable), _AWF_ (fonction), _AWK_ (constante)

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_NUMBER (entier 16 bits signe), TYK_STRING (ptr),
              TYK_UNINITIALIZED (valeur par defaut "", equiv 0),
              TYK_REGEXP (ptr pattern), TYK_ARRAY (tableau associatif),
              TYK_UNKNOWN (contexte indetermine -> coercition dynamique)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : number=2o, string=2o (pointeur), array=2o (pointeur)
            Coercition automatique AWK (nombre <-> chaine) :
              Contexte numerique : chaine -> CALL _AWRT_STRTONUM -> AX
              Contexte chaine : nombre -> CALL _AWRT_NUMTOSTR -> AX=ptr
              Comparaison : si les deux sont numeriques, comparer numeriquement
                sinon comparer comme chaines (CALL _AWRT_STRCMP)
            Verite AWK : 0 et "" sont faux, tout le reste est vrai

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _AWL_NNNNN)
            Prefixes : _AWV_ (variable), _AWF_ (fonction), _AWK_ (chaine const),
              _AWRT_ (runtime), _AWL_ (label), _AWA_ (tableau associatif),
              _AWP_ (pattern data), _AWR_ (regle pattern-action)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddArray : variantes d ajout
            Variables globales AWK : entrees DK_WORD dans DATA
            Variables predefinies : _AWV_FS, _AWV_RS, _AWV_OFS, _AWV_ORS,
              _AWV_NR, _AWV_NF, _AWV_FNR, _AWV_FILENAME
            Chaines constantes : DB 'abc',0 dans DATA avec label _AWK_N
            Valeurs par defaut : FS = DB ' ',0  RS = DB 10,0 (LF)
              OFS = DB ' ',0   ORS = DB 13,10,0 (CRLF)
            Buffer d enregistrement : _AW_RECBUF DB 1024 DUP(0)
            Buffer de champs : _AW_FIELDS DW 64 DUP(0) (ptrs vers champs)
            Heap statique : _AW_HEAP DB 4096 DUP(0) + _AW_HEAPTOP DW 0

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            Variables globales : segment DATA, acces par label _AWV_nom
            Variables locales de fonction : pile BP, acces [BP-offset]
            Parametres de fonction : pile BP, acces [BP+offset]
            Affectation simple : var = expr -> ExprLoad + MOV destination, AX
            Operateurs composes : += -= *= /= %= ^= -> load / op / store
            Pre-increment/decrement : ++var / --var -> load + INC/DEC + store
            Post-increment/decrement : var++ / var-- -> load + store + INC/DEC
            Affectation de champ : $n = expr -> CALL _AWRT_SETFIELD(BX=n, AX=val)
              Reconstruction de $0 a partir des champs modifies
            Coercition implicite : si contexte numerique et val est chaine, convertir

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal nombre, literal chaine, ident, appel de fonction
            Reference de champ : $expr -> CALL _AWRT_GETFIELD(AX=index) -> AX=ptr
              $0 : enregistrement courant complet
              $1..$NF : champs individuels, acces via _AW_FIELDS[n]
              $(expr) : champ dynamique (indice calcule)
              $NF : dernier champ -> MOV BX,[_AWV_NF] / CALL _AWRT_GETFIELD
            Acces tableau : arr[key] -> CALL _AWRT_ARRGET(SI=arr, DI=key) -> AX
            Acces multi-dimensionnel : arr[i,j] -> concat i SUBSEP j -> cle unique
            Test appartenance : (key in arr) -> CALL _AWRT_ARRHAS -> AX=0|1
            Groupement parenthese : (expr)
            Appel de fonction : nom(args) -> PUSH args + CALL _AWF_nom -> AX
            Appel de fonction integree : print, printf, length, substr, ...
            Getline primaire : getline [var] -> CALL _AWRT_GETLINE -> AX

  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            Modulo % : IDIV -> resultat dans DX (reste)
            Puissance ^ : CALL _AWRT_POW(AX=base, BX=exp) -> AX
            Concatenation (espace) : detection de juxtaposition d expressions
              -> CALL _AWRT_CONCAT(SI=gauche, DI=droite) -> AX=ptr
            Comparaison numerique : CMP + Jcc pour ==, !=, <, <=, >, >=
            Comparaison chaine : CALL _AWRT_STRCMP(SI=str1, DI=str2) -> drapeaux
            Correspondance ~ : CALL _AWRT_MATCH(SI=str, DI=pat) -> AX=0|1
            Non-correspondance !~ : CALL _AWRT_MATCH + XOR AX,1
            Logique AND && : court-circuit JZ vers false-branch
            Logique OR || : court-circuit JNZ vers true-branch
            Logique NOT ! : XOR AX,1
            Ternaire ? : -> labels _AWL_TERNF_N / _AWL_TERNE_N
            Operateur in : CALL _AWRT_ARRHAS(SI=arr, DI=key) -> AX=0|1

  TODO 12 - ENTREES/SORTIES (print / printf / getline) [IMPLEMENTE]
            print expr, expr, ... :
              Separateur OFS entre arguments (defaut espace)
              Terminateur ORS en fin (defaut newline)
              Sans argument : print $0 (enregistrement courant)
              -> CALL _AWRT_PRINTVAL pour chaque argument
              -> INT 21h AH=40h BX=1 (STDOUT)
            print > "fichier" : redirection vers fichier
              -> CALL _AWRT_FOPEN(SI=nom) -> BX=handle + INT 21h AH=40h
            print >> "fichier" : ajout en fin de fichier
            print | "commande" : pipe vers commande DOS (stub + avertissement)
            printf fmt, expr, ... :
              Formats reconnus : %d %s %c %o %x %f (trunc) %e (stub) %%
              Largeur de champ : %10d %-10s %05d
              -> CALL _AWRT_PRINTF(SI=fmt, args sur pile)
            sprintf(fmt, args) : idem printf mais retourne chaine -> AX=ptr
            getline : lire l enregistrement suivant du fichier courant
              getline var : stocker dans var au lieu de $0
              getline < "fichier" : lire depuis un fichier
              cmd | getline var : lire depuis un pipe (stub)
              Retour : 1 = succes, 0 = fin de fichier, -1 = erreur

  TODO 13 - IF / ELSE [IMPLEMENTE]
            ParseIfStmt : if (cond) stmt [else stmt]
              Condition verite AWK : 0 et "" sont faux
              Emission TEST AX,AX / JZ pour valeur numerique fausse
              CALL _AWRT_TRUTHY pour chaines -> AX=0|1
            Labels : _AWL_ELSE_N, _AWL_ENDIF_N
            Blocs : if (cond) { stmts } else { stmts }
            If imbrique : if (c1) s1 else if (c2) s2 else s3
              Labels : _AWL_ELIF_N pour chaque branche

  TODO 14 - BOUCLES : while / for / for-in / do-while [IMPLEMENTE]
            ParseWhileStmt : while (cond) stmt_ou_bloc
              Labels : _AWL_WTEST_N, _AWL_WEND_N
            ParseDoWhileStmt : do stmt_ou_bloc while (cond)
              Labels : _AWL_DOBEG_N, _AWL_DOTEST_N
            ParseForStmt : for (init; cond; incr) stmt_ou_bloc
              init : affectation ou vide
              Labels : _AWL_FTEST_N, _AWL_FINCR_N, _AWL_FEND_N
            ParseForInStmt : for (var in array) stmt_ou_bloc
              Iteration sur les cles du tableau associatif
              CALL _AWRT_ARRFIRST(SI=arr) -> AX=cle_ptr (0 si fini)
              CALL _AWRT_ARRNEXT(SI=arr) -> AX=cle_ptr suivante
              Labels : _AWL_FITEST_N, _AWL_FIEND_N
            break : saut vers fin de la boucle englobante -> JMP _AWL_END_N
            continue : saut vers le test/increment -> JMP _AWL_INCR_N
            LoopPush / LoopPop : pile de labels break/continue

  TODO 15 - TABLEAUX ASSOCIATIFS [IMPLEMENTE]
            Representation memoire : table de hachage statique
              _AWA_nom : zone DATA de MAX_HASH_PAIRS paires (cle_ptr, val_ptr)
              Entete : DW count (nombre de paires actives)
            Acces arr[key] :
              Lecture : CALL _AWRT_ARRGET(SI=arr_ptr, DI=key_ptr) -> AX=val
              Ecriture : CALL _AWRT_ARRSET(SI=arr_ptr, DI=key_ptr, AX=val)
            Acces multi-dimensionnel : arr[i,j,k]
              Concatenation des indices avec SUBSEP (defaut \034)
              -> CALL _AWRT_BUILDKEY(args sur pile, CX=nb_indices) -> AX=cle_ptr
            Test (key in arr) : CALL _AWRT_ARRHAS(SI=arr, DI=key) -> AX=0|1
            delete arr[key] : CALL _AWRT_ARRDEL(SI=arr, DI=key)
            delete arr : CALL _AWRT_ARRCLEAR(SI=arr) -> vider tout le tableau
            for (var in arr) : iteration sequentielle sur les cles
            length(arr) : nombre d elements -> CALL _AWRT_ARRLEN -> AX
            Fonction de hachage : _AWRT_HASH(SI=key) -> AX=index (modulo taille)

  TODO 16 - CHAMPS ET ENREGISTREMENTS [IMPLEMENTE]
            Lecture d enregistrement : _AWRT_READLINE -> $0 dans _AW_RECBUF
              Separateur RS (defaut \n) : lire jusqu a RS
              Mise a jour de NR (numero d enregistrement global)
              Mise a jour de FNR (numero d enregistrement par fichier)
            Decoupage en champs : _AWRT_SPLITREC
              Utiliser FS pour decouper $0 en $1, $2, ..., $NF
              FS = " " (defaut) : separateur = tout espace/tabulation contigu
              FS = "c" (un caractere) : separateur exact
              FS = regexp (multi-car) : avertissement + traiter comme chaine
              Resultat : _AW_FIELDS[1..NF] = pointeurs vers chaque champ
              Mise a jour de NF
            Acces champ $n :
              $0 -> ptr vers _AW_RECBUF (enregistrement complet)
              $1..$NF -> _AW_FIELDS[n] (pointeur vers sous-chaine)
              $n ou n > NF -> chaine vide ""
            Affectation champ $n = val :
              Modifier _AW_FIELDS[n], creer si n > NF (etendre NF)
              Reconstruire $0 : concatener $1 OFS $2 OFS ... $NF
              -> CALL _AWRT_REBUILD0
            NF modifiable : NF = expr -> tronquer ou etendre les champs

  TODO 17 - FONCTIONS UTILISATEUR [IMPLEMENTE]
            ParseFuncDecl : function nom(params) { bloc }
              Parametres passes par valeur (scalaires) ou par reference (tableaux)
              Convention d appel : cdecl 16 bits, args empiles droite a gauche
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Variables locales : declarer apres les parametres dans la signature
              function f(a, b,    c, d) -> c et d sont des variables locales
              (convention AWK : espace supplementaire avant les locales)
            return expr : MOV AX, valeur + JMP vers epilogue
              Absence de return -> AX=0 (chaine vide / zero)
            Appel : nom(args) -> PUSH args + CALL _AWF_nom
            Recursion : supportee naturellement via la pile
            Tableaux en parametre : passage par reference (adresse du tableau)
              -> LEA AX, [_AWA_nom] + PUSH AX
            Fonctions declarees avant ou apres utilisation (pre-passe de scan)

  TODO 18 - EXPRESSIONS REGULIERES ET CORRESPONDANCE [IMPLEMENTE]
            Representation : /pattern/ -> chaine constante en DATA
            Operateur ~ : str ~ /pat/ -> CALL _AWRT_MATCH(SI=str, DI=pat) -> AX
            Operateur !~ : str !~ /pat/ -> CALL _AWRT_MATCH + XOR AX,1
            Pattern comme condition de regle : /pat/ equiv $0 ~ /pat/
            Pattern de plage : /pat1/,/pat2/ -> active de pat1 a pat2
              Flag d etat dans DATA : _AWR_RANGE_N DW 0
            Fonctions regex :
              match(str, /pat/) : CALL _AWRT_MATCHPOS -> RSTART et RLENGTH
              sub(/pat/, repl, target) : remplacer la 1ere occurrence
                -> CALL _AWRT_SUB(SI=target, DI=pat, BX=repl) -> modifie target
              gsub(/pat/, repl, target) : remplacer toutes les occurrences
                -> CALL _AWRT_GSUB(SI=target, DI=pat, BX=repl) -> AX=nb_rempl
              split(str, arr, /sep/) : decouper str dans arr selon sep
                -> CALL _AWRT_SPLIT(SI=str, DI=arr, BX=sep) -> AX=nb_elems
            Caractere special & dans repl : reference a la sous-chaine matchee
            Support minimal : recherche de sous-chaine fixe (pas de metacaracteres)
            Metacaracteres . ^ $ * + ? [ ] | ( ) : avertissement compile

  TODO 19 - REGLES PATTERN-ACTION (BEGIN / END / pattern { action }) [IMPLEMENTE]
            Structure d un programme AWK :
              BEGIN { actions }       -> execute une seule fois avant les donnees
              pattern { actions }     -> execute pour chaque enregistrement matchant
              END { actions }         -> execute une seule fois apres les donnees
            Compilation des regles :
              Phase BEGIN : emettre le code BEGIN dans _AWR_BEGIN PROC NEAR
              Phase principale (boucle d enregistrement) :
                _AWR_MAIN : CALL _AWRT_READLINE / JC _AWR_DONE (fin de fichier)
                            CALL _AWRT_SPLITREC (decouper en champs)
                            Pour chaque regle : tester pattern, si vrai CALL action
                            JMP _AWR_MAIN
              Phase END : emettre le code END dans _AWR_END PROC NEAR
            Types de pattern :
              /regexp/ : $0 ~ /regexp/ -> CALL _AWRT_MATCH
              expression : evaluer et tester verite
              pattern1, pattern2 : plage (activer de pattern1 a pattern2)
              BEGIN : flag special (pas de test d enregistrement)
              END : flag special (apres la boucle principale)
              Absence de pattern : action executee pour chaque enregistrement
            Plusieurs regles : tester chacune dans l ordre du source
            next : sauter au prochain enregistrement -> JMP _AWR_MAIN
            nextfile : passer au fichier suivant (stub + avertissement)
            exit [expr] : sortir avec code -> MOV AX,4C00h + code + INT 21h

  TODO 20 - FONCTIONS CHAINES INTEGREES [IMPLEMENTE]
            length(s)       -> CALL _AWRT_STRLEN(SI=s) -> AX
            length(arr)     -> CALL _AWRT_ARRLEN(SI=arr) -> AX (nombre d elements)
            length           -> length($0) si sans argument
            substr(s, d, n)  -> CALL _AWRT_SUBSTR(SI=s, BX=debut, CX=longueur) -> AX=ptr
            substr(s, d)     -> CALL _AWRT_SUBSTR avec CX=longueur restante
            index(s, t)      -> CALL _AWRT_INDEX(SI=s, DI=t) -> AX=position (1-base, 0 si absent)
            split(s, arr, sep) -> CALL _AWRT_SPLIT -> AX=nb_elems (voir TODO 18)
            sub(r, s, t)     -> substitution 1ere occurrence (voir TODO 18)
            gsub(r, s, t)    -> substitution globale (voir TODO 18)
            match(s, r)      -> position de correspondance (voir TODO 18)
            sprintf(fmt, args) -> formatage en chaine (voir TODO 12)
            tolower(s)       -> CALL _AWRT_TOLOWER(SI=s) -> AX=ptr chaine minuscule
            toupper(s)       -> CALL _AWRT_TOUPPER(SI=s) -> AX=ptr chaine majuscule

  TODO 21 - FONCTIONS MATHEMATIQUES INTEGREES [IMPLEMENTE]
            int(x)    -> troncature vers zero (entier deja en 16 bits -> pass-through)
            sqrt(x)   -> CALL _AWRT_SQRT(AX=n) -> AX (Newton-Raphson entier)
            sin(x)    -> stub AX=0 + avertissement (pas de flottant 16 bits)
            cos(x)    -> stub AX=1 + avertissement
            atan2(y,x)-> stub AX=0 + avertissement
            exp(x)    -> CALL _AWRT_EXP(AX=n) -> AX (approximation entiere)
            log(x)    -> CALL _AWRT_LOG(AX=n) -> AX (approximation entiere)
            rand()    -> CALL _AWRT_RAND -> AX (LCG 16 bits, resultat 0..32767)
            srand(x)  -> MOV [_AWRT_SEED], AX (initialiser la graine)
            srand()   -> initialiser avec l horloge systeme (INT 1Ah AH=00h)

  TODO 22 - FICHIERS MULTIPLES ET ENTREES AVANCEES [IMPLEMENTE]
            Traitement de plusieurs fichiers en arguments :
              AWK86 script.awk fichier1.txt fichier2.txt ...
              Boucle sur ARGV[1..ARGC-1], ouvrir chaque fichier
              FILENAME : mis a jour a chaque nouveau fichier
              FNR : remis a zero a chaque nouveau fichier
              NR : compteur global continu
            ARGV et ARGC :
              _AWV_ARGC DW n dans DATA
              _AWA_ARGV : tableau associatif (index -> nom de fichier)
            Lecture depuis stdin si aucun fichier specifie :
              INT 21h AH=3Fh BX=0 (STDIN)
            getline var < "fichier" :
              Ouvrir le fichier, lire un enregistrement, fermer/garder ouvert
              -> CALL _AWRT_FGETLINE(SI=nom_fichier) -> AX=ptr enregistrement
            Gestion des handles de fichiers ouverts :
              Table _AW_FHANDLES[0..7] : handles DOS actifs
              _AWRT_FOPEN(SI=nom, AL=mode) -> BX=handle
              _AWRT_FCLOSE(BX=handle)
            close("fichier") : fermer un fichier ou pipe precedemment ouvert
            Pipe d entree : "cmd" | getline var (stub + avertissement)

  TODO 23 - CONVERSION DE TYPES ET COERCITION [IMPLEMENTE]
            Regle fondamentale AWK : toute valeur est a la fois nombre et chaine
            Contexte numerique (operation arithmetique, comparaison numerique) :
              Chaine -> nombre : CALL _AWRT_STRTONUM(SI=str) -> AX
              Prefixe numerique : "123abc" -> 123, "abc" -> 0
              Chaine vide "" -> 0
            Contexte chaine (concatenation, print, index en tableau) :
              Nombre -> chaine : CALL _AWRT_NUMTOSTR(AX=n, DI=buf) -> AX=ptr
              Format OFMT pour conversion implicite (defaut "%.6g" -> entier)
            Contexte booleen (condition if, while, pattern) :
              0 -> faux, "" -> faux, tout le reste -> vrai
              CALL _AWRT_TRUTHY(AX=val, BX=type_flag) -> AX=0|1
            Comparaison mixte :
              Si les deux operandes sont numeriques -> CMP entier
              Si l un est chaine -> comparer comme chaines -> CALL _AWRT_STRCMP
              Force numerique : +var (unaire +) force la coercition numerique
            CONVFMT : format de conversion nombre -> chaine (defaut "%.6g")

  TODO 24 - RUNTIME MINIMAL [IMPLEMENTE]
            _AWRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _AWRT_PRINTLN : _AWRT_PRINT + ORS via [_AWV_ORS]
            _AWRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _AWRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _AWRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi, prefixe num.)
            _AWRT_CONCAT(SI=src1, DI=src2) : concatenation -> AX=ptr buf
            _AWRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _AWRT_SUBSTR(SI=str, BX=debut, CX=len) : sous-chaine -> AX=ptr
            _AWRT_INDEX(SI=str, DI=sub) : recherche sous-chaine -> AX=pos
            _AWRT_TOLOWER(SI=str) : conversion minuscules -> AX=ptr buf
            _AWRT_TOUPPER(SI=str) : conversion majuscules -> AX=ptr buf
            _AWRT_MATCH(SI=str, DI=pat) : correspondance sous-chaine -> AX=0|1
            _AWRT_SUB(SI=target, DI=pat, BX=repl) : substitution 1ere occ.
            _AWRT_GSUB(SI=target, DI=pat, BX=repl) : substitution globale -> AX=count
            _AWRT_SPLIT(SI=str, DI=arr, BX=sep) : decoupage -> AX=nb_elems
            _AWRT_READLINE(BX=handle) : lire enregistrement -> AX=ptr _AW_RECBUF
            _AWRT_SPLITREC : decouper $0 en champs selon FS
            _AWRT_GETFIELD(AX=n) : retourner ptr vers champ $n -> AX
            _AWRT_SETFIELD(BX=n, AX=val) : modifier champ $n + reconstruire $0
            _AWRT_REBUILD0 : reconstruire $0 a partir de $1..$NF avec OFS
            _AWRT_ARRGET(SI=arr, DI=key) : lire valeur tableau -> AX
            _AWRT_ARRSET(SI=arr, DI=key, AX=val) : ecrire valeur tableau
            _AWRT_ARRHAS(SI=arr, DI=key) : test existence cle -> AX=0|1
            _AWRT_ARRDEL(SI=arr, DI=key) : supprimer entree
            _AWRT_ARRFIRST / _AWRT_ARRNEXT : iteration sur tableau
            _AWRT_HASH(SI=key) : fonction de hachage -> AX=index
            _AWRT_POW(AX=base, BX=exp) : puissance entiere -> AX
            _AWRT_SQRT(AX=n) : racine carree entiere (Newton) -> AX
            _AWRT_RAND : LCG 16 bits -> AX (_AWRT_SEED DW 1)
            _AWRT_TRUTHY(AX=val, BX=type) : test verite AWK -> AX=0|1
            _AWRT_PRINTF(SI=fmt, args pile) : formatage et ecriture
            _AWRT_FOPEN(SI=nom, AL=mode) : ouvrir fichier -> BX=handle
            _AWRT_FCLOSE(BX=handle) : fermer fichier
            _AWRT_FGETLINE(BX=handle) : lire ligne fichier -> AX=ptr
            _AWRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _AW_HEAP DB 4096 DUP(0) + _AW_HEAPTOP DW 0
              _AWRT_ALLOC(CX=nb_bytes) -> AX=ptr dans le heap statique

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES [IMPLEMENTE]
            EmitClose : END _AWR_ENTRY dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitBegin -> EmitMainLoop -> EmitEnd ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _AWR_ENTRY
            Point d entree _AWR_ENTRY :
              MOV AX,@DATA / MOV DS,AX
              Initialiser FS, RS, OFS, ORS, NR, NF par defaut
              CALL _AWR_BEGIN (si bloc BEGIN present)
              Boucle : CALL _AWRT_READLINE / JC done
                       CALL _AWRT_SPLITREC
                       Pour chaque regle : tester pattern + CALL action
                       JMP boucle
              done: CALL _AWR_END (si bloc END present)
              MOV AX,4C00h / INT 21h
            Fichiers SAMPLES\AWK\ a creer :
              hello.awk    (BEGIN, print, variables, chaines)
              fields.awk   (champs $1 $2 $NF, NR, NF, FS)
              math.awk     (fonctions mathematiques, expressions)
              arrays.awk   (tableaux associatifs, for-in, delete)
              regex.awk    (patterns /regexp/, sub, gsub, match)
              funcuser.awk (fonctions utilisateur, recursion, return)
              multifile.awk(FILENAME, FNR, ARGC, ARGV, getline)
              format.awk   (printf, sprintf, redirection >)
            Smoke tests : AWK86.EXE -v SAMPLES\AWK\*.awk

  ============================================================ *)

{ ============================================================
  AWK86 - Compilateur AWK -> assembleur 8086
  Version : 1.0  Date : 2026-03-06
  Compilation : ppc386 -O2 -Mtp AWK86.PAS
  ============================================================ }

Program AWK86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  AWK86_VERSION = '1.0';
  AWK86_DATE    = '2026-03-06';

  { Limites des tableaux internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_RULES     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_FIELDS    = 64;       { nombre max de champs $1..$NF     }
  MAX_HASH_PAIRS = 64;      { paires max par tableau associatif }
  MAX_INIT_VARS  = 16;      { nombre max de -v var=val          }
  STACK_SIZE     = 1024;

  { Prefixes de nommage ASM }
  AW_VAR_PFX  = '_AWV_';    { variable utilisateur              }
  AW_FN_PFX   = '_AWF_';    { fonction utilisateur              }
  AW_STR_PFX  = '_AWK_';    { constante chaine                  }
  AW_RT_PFX   = '_AWRT_';   { routine runtime                   }
  AW_LBL_PFX  = '_AWL_';    { label de saut interne             }
  AW_ARR_PFX  = '_AWA_';    { tableau associatif                }
  AW_PAT_PFX  = '_AWP_';    { pattern data                      }
  AW_RULE_PFX = '_AWR_';    { regle pattern-action              }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ------------------------------ }
  TInitVar = Record
    VarName  : TString;     { nom de la variable                }
    VarValue : TString;     { valeur (chaine)                   }
  End;

  TOptions = Record
    SrcFile   : TString;    { script source (.awk)              }
    OutFile   : TString;    { fichier assembleur de sortie      }
    Verbose   : Boolean;    { -v : banniere et statistiques     }
    DebugMode : Boolean;    { -d : affichage de chaque token    }
    Warnings  : Boolean;    { -w : avertissements actifs        }
    FieldSep  : TString;    { -F sep : separateur de champs     }
    InitVars  : Array[0..MAX_INIT_VARS - 1] Of TInitVar;
    InitCount : Integer;    { nombre de -v var=val              }
  End;

  { ---- Tokens du lexeur ------------------------------------ }
  TTokenKind = (
    TK_EOF,        { fin de fichier                            }
    TK_INTEGER,    { litteral entier 42 0xFF 0377              }
    TK_FLOAT,      { litteral flottant 3.14 1.5e3              }
    TK_STRING,     { litteral chaine "abc"                     }
    TK_REGEXP,     { expression reguliere /pattern/            }
    TK_IDENT,      { identificateur utilisateur                }
    TK_KEYWORD,    { mot-cle AWK (if while for ...)            }
    TK_BUILTIN,    { fonction builtin AWK (length substr ...)  }
    TK_FIELD,      { reference de champ $0 $1 $NF              }
    TK_OP,         { operateur + - * / = == != ~ !~ ...        }
    TK_PUNCT,      { ponctuation ; , ( ) [ ] accolades        }
    TK_NEWLINE     { fin de ligne logique (separateur d instr) }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute            }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)       }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)       }
    Line     : Integer;     { numero de ligne source            }
    Col      : Integer;     { numero de colonne source          }
  End;

  { ---- Systeme de types (TODO 06) --------------------------- }
  TTypeKind = (
    TYK_NUMBER,        { entier 16 bits signe                   }
    TYK_STRING,        { pointeur vers chaine terminee par 0    }
    TYK_UNINITIALIZED, { valeur par defaut : "" ou 0            }
    TYK_REGEXP,        { pointeur vers pattern data             }
    TYK_ARRAY,         { tableau associatif (pointeur)          }
    TYK_UNKNOWN        { type indetermine (coercition dynamique)}
  );

  TTypeRec = Record
    Name : TString;
    Kind : TTypeKind;
    Size : Integer;    { taille en octets : number=2, string=2  }
  End;

  { ---- Valeur d expression (TODO 03) ----------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                          }
    EK_IMM,    { valeur immediate dans ImmVal                   }
    EK_AX,     { valeur dans le registre AX                     }
    EK_MEM     { adresse memoire [BP+Offset] ou [_AWV_x]       }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;   { indice dans TypeTab                  }
    Offset  : Integer;   { offset donnee/pile                   }
    SymIdx  : Integer;   { indice dans SymTab (-1 = pas lvalue) }
  End;

  { ---- Segment de donnees (TODO 08) ------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;  { DK_ARRAY_BLK : nb paires            }
  End;

  { ---- Categories de symboles (TODO 05) -------------------- }
  TSymCat = (
    SC_VAR,          { variable utilisateur                     }
    SC_BUILTIN_VAR,  { variable predefinie (FS, NR, NF ...)    }
    SC_ARRAY,        { tableau associatif                       }
    SC_PARAM,        { parametre de fonction                    }
    SC_FUNCTION,     { fonction utilisateur                     }
    SC_FIELD         { champ $n                                 }
  );

  TSymRec = Record
    Name        : TString;   { identifiant AWK                 }
    MangledName : TString;   { _AWV_nom / _AWF_nom / _AWA_nom  }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab              }
    ScopeLevel  : Integer;
    Offset      : Integer;   { offset BP pour locales/params    }
    IsLocal     : Boolean;   { vrai si variable locale          }
    IsParam     : Boolean;   { vrai si parametre de fonction    }
    IsArray     : Boolean;   { vrai si tableau associatif       }
    ArrayIdx    : Integer;   { indice DataTab du tableau        }
    DeclLine    : Integer;   { ligne de declaration             }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options de compilation }
  Opts       : TOptions;

  { Compteurs d erreurs }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Lexeur }
  LexSrcF    : Text;
  LexLine    : String;
  LexLineNo  : Integer;
  LexColNo   : Integer;
  LexEOF     : Boolean;
  LexOpened  : Boolean;
  CurToken   : TToken;
  LexLastKind: TTokenKind;  { dernier token emis (pour regexp) }

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount  : Integer;
  ScopeStack: Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop  : Integer;
  CurScope  : Integer;

  { Segment de donnees }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Generateur de labels }
  LabelGenSeq : LongInt;

  { Emetteur de code (TODO 07) }
  OutF      : Text;
  OutFOpen  : Boolean;
  RuntimeEmitted : Boolean;

  { Frame de fonction courante (TODO 09/17) }
  CurFrameSize : Integer;   { nombre de mots locaux dans le cadre  }
  CurFnRetLbl  : TString;   { label de retour de la fonction       }

  { Pile de boucles pour break/continue (TODO 14) }
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopDepth    : Integer;

  { Table des regles pattern-action (TODO 19) }
  RuleCount    : Integer;
  RuleLabels   : Array[0..MAX_RULES - 1] Of TString;
  RulePatterns : Array[0..MAX_RULES - 1] Of TString;
  HasBegin     : Boolean;
  HasEnd       : Boolean;
  BeginLbl     : TString;
  EndLbl       : TString;

  { Compteur de pattern de plage (TODO 18) }
  RangeCount   : Integer;

{ ============================================================
  INFRASTRUCTURE ET OPTIONS
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AWK86: ERREUR FATALE - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Erreur de compilation -------------------------------- }
Procedure CompileError(Const Msg : TString);
Begin
  WriteLn('AWK86: error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- Avertissement ---------------------------------------- }
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AWK86: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;
Begin
  WriteLn('AWK86 - Compilateur AWK vers assembleur 8086 (MASM/TASM)');
  WriteLn;
  WriteLn('Syntaxe : AWK86 [options] <source.awk> [sortie.asm]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -F sep   separateur de champs (defaut espace/tabulation)');
  WriteLn('  -v var=val  initialisation de variable avant BEGIN');
  WriteLn('  -d       mode debug (affichage des tokens)');
  WriteLn('  -w       activer les avertissements');
  WriteLn('  -h       afficher cette aide');
  WriteLn('  --help   afficher cette aide');
  WriteLn('  --verbose  mode verbeux (banniere et statistiques)');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  AWK86 hello.awk');
  WriteLn('  AWK86 -F: script.awk sortie.asm');
  WriteLn('  AWK86 -v N=10 script.awk');
  Halt(EXIT_OK);
End;

{ ---- Initialisation des options --------------------------- }
Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.FieldSep  := ' ';
  Opts.InitCount := 0;
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName;
Var
  Base : TString;
  Ext  : TString;
  I    : Integer;
Begin
  Base := Opts.SrcFile;
  Ext := '';
  For I := Length(Base) DownTo 1 Do
  Begin
    If Base[I] = '.' Then
    Begin
      Ext  := Copy(Base, I, Length(Base) - I + 1);
      Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  If (Ext = '.awk') Or (Ext = '.AWK') Then
    Opts.OutFile := Base + '.asm'
  Else
    Opts.OutFile := Opts.SrcFile + '.asm';
End;

{ ---- Analyse des arguments de la ligne de commande -------- }
Procedure ParseArgs;
Var
  I     : Integer;
  Arg   : TString;
  EqPos : Integer;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Then
      ShowHelp
    Else If (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-F' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -F requiert un argument');
      Opts.FieldSep := ParamStr(I);
    End
    Else If (Length(Arg) > 2) And (Arg[1] = '-') And (Arg[2] = 'F') Then
    Begin
      { -Fsep : separateur colle a l option }
      Opts.FieldSep := Copy(Arg, 3, Length(Arg) - 2);
    End
    Else If Arg = '-v' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('option -v requiert un argument var=val');
      Arg := ParamStr(I);
      { Chercher le signe = }
      EqPos := 0;
      For EqPos := 1 To Length(Arg) Do
        If Arg[EqPos] = '=' Then Break;
      If (EqPos < 2) Or (EqPos > Length(Arg)) Or (Arg[EqPos] <> '=') Then
        FatalError('-v : format attendu var=val');
      If Opts.InitCount >= MAX_INIT_VARS Then
        FatalError('trop de variables -v');
      Opts.InitVars[Opts.InitCount].VarName :=
        Copy(Arg, 1, EqPos - 1);
      Opts.InitVars[Opts.InitCount].VarValue :=
        Copy(Arg, EqPos + 1, Length(Arg) - EqPos);
      Inc(Opts.InitCount);
    End
    Else If Arg[1] = '-' Then
    Begin
      WriteLn('AWK86: option inconnue : ', Arg);
      Halt(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('AWK86: argument inattendu : ', Arg);
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AWK86: aucun fichier source specifie.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then
    BuildOutName;
End;

{ ---- Banniere verbose ------------------------------------- }
Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('================================================');
  WriteLn(' AWK86 v', AWK86_VERSION, ' (', AWK86_DATE, ')');
  WriteLn('================================================');
  WriteLn(' Source  : ', Opts.SrcFile);
  WriteLn(' Sortie  : ', Opts.OutFile);
  If Opts.FieldSep <> ' ' Then
    WriteLn(' FS      : ', Opts.FieldSep);
  If Opts.InitCount > 0 Then
    WriteLn(' InitVars: ', Opts.InitCount);
  WriteLn('------------------------------------------------');
End;

{ ---- Statistiques finales --------------------------------- }
Procedure ShowStats;
Begin
  WriteLn('------------------------------------------------');
  WriteLn(' Lignes   : ', TotalLines);
  WriteLn(' Erreurs  : ', ErrorCount);
  WriteLn(' Avert.   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn(' Resultat : OK -> ', Opts.OutFile)
  Else
    WriteLn(' Resultat : ECHEC (', ErrorCount, ' erreur(s))');
  WriteLn('================================================');
End;

{ ============================================================
  LEXEUR (TOKENS AWK)
  ============================================================ }

{ ---- Utilitaires de caracteres ---------------------------- }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or (C = '_');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(C) Or IsDigit(C);
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function IsOctDigit(C : Char) : Boolean;
Begin
  IsOctDigit := (C >= '0') And (C <= '7');
End;

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

{ ---- Primitives de bas niveau ----------------------------- }
Function LexCurChar : Char;
Begin
  If (LexEOF) Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If (LexEOF) Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- Erreur lexicale (non fatale) ------------------------- }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('AWK86:', LexLineNo, ':', LexColNo, ': error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

{ ---- Constructeur de token -------------------------------- }
Procedure MakeToken(Var T : TToken; K : TTokenKind;
                    Const V : TString; L, C : Integer);
Begin
  T.Kind     := K;
  T.Val      := V;
  T.IntVal   := 0;
  T.FloatVal := 0.0;
  T.Line     := L;
  T.Col      := C;
End;

{ ---- Commentaires AWK : # jusqu a fin de ligne ------------ }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- LexSkipWS : espaces, commentaires et continuation ---- }
Procedure LexSkipWS;
Var
  C : Char;
Begin
  Repeat
    { Passer les lignes vides }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Then
      LexAdvance
    Else If C = '#' Then
      LexSkipLineComment
    Else If (C = '\') And (LexColNo = Length(LexLine)) Then
    Begin
      { Continuation de ligne : \ en fin de ligne }
      LexNextLine;
    End
    Else
      Exit;
  Until False;
End;

{ ---- Table des mots-cles AWK ------------------------------ }
Const
  AWK_KW_COUNT = 21;
  AWK_KW : Array[0..AWK_KW_COUNT - 1] Of String[10] = (
    'BEGIN',     'END',       'if',        'else',
    'while',     'for',       'do',        'in',
    'break',     'continue',  'function',  'return',
    'delete',    'exit',      'getline',   'next',
    'nextfile',  'print',     'printf',    'sprintf',
    'BEGINFILE'
  );

Function IsAwkKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsAwkKeyword := False;
  For I := 0 To AWK_KW_COUNT - 1 Do
    If S = AWK_KW[I] Then
    Begin IsAwkKeyword := True; Exit; End;
End;

{ ---- Table des fonctions builtin AWK ---------------------- }
Const
  AWK_BI_COUNT = 24;
  AWK_BI : Array[0..AWK_BI_COUNT - 1] Of String[10] = (
    'length',    'substr',    'index',     'split',
    'sub',       'gsub',      'match',     'sprintf',
    'tolower',   'toupper',   'sin',       'cos',
    'atan2',     'exp',       'log',       'sqrt',
    'int',       'rand',      'srand',     'system',
    'close',     'fflush',    'mktime',    'strftime'
  );

Function IsAwkBuiltin(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsAwkBuiltin := False;
  For I := 0 To AWK_BI_COUNT - 1 Do
    If S = AWK_BI[I] Then
    Begin IsAwkBuiltin := True; Exit; End;
End;

{ ---- LexScanIdent : identificateur, mot-cle ou builtin ---- }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  If IsAwkKeyword(S) Then
    MakeToken(T, TK_KEYWORD, S, SL, SC)
  Else If IsAwkBuiltin(S) Then
    MakeToken(T, TK_BUILTIN, S, SL, SC)
  Else
    MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ---- LexScanNumber : entier (dec/oct/hex) ou flottant ----- }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;
  Div10 : Real;
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;
  { Prefixe 0x (hexa) ou 0 (octal) }
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    If (LexPeek = 'x') Or (LexPeek = 'X') Then
    Begin
      S := '0x'; LexAdvance; LexAdvance; Base := 16;
    End
    Else If IsOctDigit(LexPeek) Then
    Begin
      Val := 0; S := '0'; LexAdvance; Base := 8;
    End
    Else
    Begin
      Val := 0; S := '0'; LexAdvance;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  { Chiffres du nombre }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    Case Base Of
      8  : If IsOctDigit(C) Then
           Begin Val := Val*8+(Ord(C)-Ord('0'));
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      10 : If IsDigit(C) Then
           Begin Val := Val*10+(Ord(C)-Ord('0'));
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin Val := Val*16+HexVal(C);
                 If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
    End;
  End;
  { Detection flottant (base 10 seulement) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And (LexPeek <> #0) And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          IsDigit(LexCurChar) Do
    Begin
      Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
      Div10 := Div10 * 10.0;
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    { Exposant e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  { Flottant sans partie decimale mais avec exposant }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
  Begin
    Fv := Val * 1.0;
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
    If (LexColNo <= Length(LexLine)) And
       ((LexCurChar = '+') Or (LexCurChar = '-')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          IsDigit(LexCurChar) Do
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ---- LexScanEscape : sequence d echappement --------------- }
Function LexScanEscape : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  Code := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : LexScanEscape := #10;
    't' : LexScanEscape := #9;
    'r' : LexScanEscape := #13;
    'a' : LexScanEscape := #7;
    'b' : LexScanEscape := #8;
    'f' : LexScanEscape := #12;
    '\' : LexScanEscape := '\';
    '"' : LexScanEscape := '"';
    '/' : LexScanEscape := '/';
    'x' : Begin
            Code := 0;
            For I := 1 To 2 Do
            Begin
              If (LexColNo > Length(LexLine)) Or
                 (Not IsHexDigit(LexCurChar)) Then
              Begin LexError('\x: 2 chiffres hexa attendus'); Break; End;
              Code := Code * 16 + HexVal(LexCurChar);
              LexAdvance;
            End;
            LexScanEscape := Chr(Code And $FF);
          End;
  Else
    LexScanEscape := C;
  End;
End;

{ ---- LexScanString : chaine double-quote "abc\n" ---------- }
Procedure LexScanString(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('chaine non fermee en fin de ligne');
      Done := True;
    End Else
    Begin
      C := LexCurChar;
      If C = '"' Then
      Begin
        LexAdvance; Done := True;
      End Else If C = '\' Then
      Begin
        LexAdvance;
        C := LexScanEscape;
        If Length(S) < MAX_STR Then S := S + C;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanRegexp : /pattern/ ----------------------------- }
Procedure LexScanRegexp(Var T : TToken; SL, SC : Integer);
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  LexAdvance; { sauter '/' ouvrant }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexCurChar;
    If Ch = '/' Then
    Begin
      LexAdvance; { sauter '/' fermant }
      Break;
    End
    Else If Ch = '\' Then
    Begin
      If Length(S) < MAX_STR Then S := S + '\';
      LexAdvance;
      If LexColNo <= Length(LexLine) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + Ch;
      LexAdvance;
    End;
  End;
  MakeToken(T, TK_REGEXP, S, SL, SC);
End;

{ ---- LexExpectRegex : le contexte autorise-t-il /regexp/ ? - }
{ En AWK, / est regexp apres : ~ !~ , ( = ; { debut de ligne  }
{ / est division apres : ) ] identifiant nombre champ          }
Function LexExpectRegex : Boolean;
Begin
  Case LexLastKind Of
    TK_INTEGER, TK_FLOAT, TK_STRING, TK_IDENT,
    TK_BUILTIN, TK_FIELD :
      LexExpectRegex := False;
  Else
    { Apres ) et ] c est une division }
    If (LexLastKind = TK_PUNCT) And
       ((CurToken.Val = ')') Or (CurToken.Val = ']')) Then
      LexExpectRegex := False
    Else
      LexExpectRegex := True;
  End;
End;

{ ---- LexScanField : $0 $1 $NF $(expr) -> TK_FIELD --------- }
Procedure LexScanField(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  LexAdvance; { sauter '$' }
  S := '';
  { $0..$9 ou $NF etc. }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  If S = '' Then
    S := '0';  { $ seul = $0 }
  MakeToken(T, TK_FIELD, S, SL, SC);
End;

{ ---- LexScanOp : operateurs AWK (simples et composes) ----- }
Procedure LexScanOp(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
  C : Char;
  P : Char;
Begin
  C := LexCurChar;
  P := LexPeek;
  S := C;
  LexAdvance;
  Case C Of
    '+': If P = '+' Then Begin S := '++'; LexAdvance; End
         Else If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '-' Then Begin S := '--'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    '!': If P = '~' Then Begin S := '!~'; LexAdvance; End
         Else If P = '=' Then Begin S := '!='; LexAdvance; End;
    '=': If P = '=' Then Begin S := '=='; LexAdvance; End;
    '<': If P = '=' Then Begin S := '<='; LexAdvance; End
         Else If P = '<' Then Begin S := '<<'; LexAdvance; End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then Begin S := '>>'; LexAdvance; End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End;
    '|': If P = '|' Then Begin S := '||'; LexAdvance; End;
    '~': ; { tilde seul = match }
    '?': ; { ternaire }
    ':': ; { ternaire / label }
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ---- LexScanPunct : caractere de ponctuation --------------- }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ---- LexNextToken : produire le prochain token ------------- }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
  WasNewLine : Boolean;
Begin
  WasNewLine := False;
  { Passer espaces et commentaires, mais pas les fins de ligne }
  While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
  Begin
    WasNewLine := True;
    LexNextLine;
  End;
  If LexEOF Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  { Espaces et tabulations sur la ligne courante }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Inc(LexColNo);
  { Si on a change de ligne, emettre un NEWLINE pour separer les stmts }
  If WasNewLine And (LexLastKind <> TK_NEWLINE) Then
  Begin
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  { Commentaire # -> passer toute la ligne }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
  Begin
    LexSkipLineComment;
    { Fin de ligne = TK_NEWLINE }
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  { Continuation de ligne : \ en fin de ligne }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '\') And
     (LexColNo = Length(LexLine)) Then
  Begin
    LexNextLine;
    LexNextToken(T);
    Exit;
  End;
  { Fin de ligne logique }
  If LexColNo > Length(LexLine) Then
  Begin
    MakeToken(T, TK_NEWLINE, '', LexLineNo, LexColNo);
    LexLastKind := TK_NEWLINE;
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;
  { Chaine double-quote "..." }
  If C = '"' Then
  Begin
    LexScanString(T, SL, SC);
    LexLastKind := TK_STRING;
    Exit;
  End;
  { Reference de champ $n }
  If C = '$' Then
  Begin
    LexScanField(T, SL, SC);
    LexLastKind := TK_FIELD;
    Exit;
  End;
  { Identificateur ou mot-cle }
  If IsAlpha(C) Then
  Begin
    LexScanIdent(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Nombre }
  If IsDigit(C) Then
  Begin
    LexScanNumber(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Nombre .5 (point suivi de chiffre) }
  If (C = '.') And (LexPeek <> #0) And IsDigit(LexPeek) Then
  Begin
    LexScanNumber(T, SL, SC);
    LexLastKind := T.Kind;
    Exit;
  End;
  { Slash : regexp ou division selon contexte }
  If C = '/' Then
  Begin
    If LexExpectRegex Then
    Begin
      LexScanRegexp(T, SL, SC);
      LexLastKind := TK_REGEXP;
    End Else
    Begin
      LexScanOp(T, SL, SC);
      LexLastKind := TK_OP;
    End;
    Exit;
  End;
  { Operateurs }
  Case C Of
    '+','-','*','%','^',
    '!','=','<','>','&','|','~','?',':':
    Begin
      LexScanOp(T, SL, SC);
      LexLastKind := TK_OP;
      Exit;
    End;
  End;
  { Ponctuation : ; , ( ) [ ] accolades }
  Case C Of
    ';',',','(',')','[',']','{','}':
    Begin
      LexScanPunct(T, SL, SC);
      LexLastKind := TK_PUNCT;
      Exit;
    End;
  End;
  { Caractere inconnu }
  LexError('caractere inconnu: ' + C);
  LexAdvance;
  LexNextToken(T);
End;

{ ---- LexInit : ouvrir le fichier source -------------------- }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened  := True;
  LexEOF     := False;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexLine    := '';
  LexLastKind := TK_NEWLINE;
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
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

{ ---- PrintToken : affichage debug mode -d ------------------ }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[10];
  NS : TString;
Begin
  Case T.Kind Of
    TK_EOF     : KS := 'EOF    ';
    TK_INTEGER : KS := 'INTEGER';
    TK_FLOAT   : KS := 'FLOAT  ';
    TK_STRING  : KS := 'STRING ';
    TK_REGEXP  : KS := 'REGEXP ';
    TK_IDENT   : KS := 'IDENT  ';
    TK_KEYWORD : KS := 'KEYWORD';
    TK_BUILTIN : KS := 'BUILTIN';
    TK_FIELD   : KS := 'FIELD  ';
    TK_OP      : KS := 'OP     ';
    TK_PUNCT   : KS := 'PUNCT  ';
    TK_NEWLINE : KS := 'NEWLINE';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin
    Str(T.IntVal, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_FLOAT Then
  Begin
    Str(T.FloatVal : 0 : 6, NS);
    Write(' =', NS);
  End;
  WriteLn;
End;

{ ---- ParserAdvance : lire le prochain token du lexeur ------ }
Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

{ ============================================================
  LITTERAUX ET CONSTANTES (TODO 03)
  ============================================================ }

{ ---- IntToStr : conversion entier -> chaine ---------------- }
Function IntToStr(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  IntToStr := S;
End;

{ ---- Constantes d index de types primitifs ----------------- }
Const
  TY_IDX_NUMBER  = 0;   { entier 16 bits signe                 }
  TY_IDX_STRING  = 1;   { pointeur vers chaine                 }
  TY_IDX_REGEXP  = 2;   { pointeur vers pattern                }
  TY_IDX_ARRAY   = 3;   { tableau associatif                   }
  TY_IDX_UNINIT  = 4;   { non initialise (""  / 0)             }
  TY_UNKNOWN     = -1;  { type indetermine                     }

{ ---- TypeInit : enregistrer les types primitifs ------------ }
Procedure TypeInit;
Begin
  TypeCount := 0;
  { TY_IDX_NUMBER = 0 }
  TypeTab[0].Name := 'number';
  TypeTab[0].Kind := TYK_NUMBER;
  TypeTab[0].Size := 2;
  { TY_IDX_STRING = 1 }
  TypeTab[1].Name := 'string';
  TypeTab[1].Kind := TYK_STRING;
  TypeTab[1].Size := 2;
  { TY_IDX_REGEXP = 2 }
  TypeTab[2].Name := 'regexp';
  TypeTab[2].Kind := TYK_REGEXP;
  TypeTab[2].Size := 2;
  { TY_IDX_ARRAY = 3 }
  TypeTab[3].Name := 'array';
  TypeTab[3].Kind := TYK_ARRAY;
  TypeTab[3].Size := 2;
  { TY_IDX_UNINIT = 4 }
  TypeTab[4].Name := 'uninit';
  TypeTab[4].Kind := TYK_UNINITIALIZED;
  TypeTab[4].Size := 2;
  TypeCount := 5;
End;

{ ---- TypeSizeof : taille en octets d un type par index ------ }
Function TypeSizeof(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= TypeCount) Then
    TypeSizeof := 2    { taille par defaut : word }
  Else
    TypeSizeof := TypeTab[Idx].Size;
End;

{ ---- TypeKindOf : retourne le TTypeKind d un type ----------- }
Function TypeKindOf(Idx : Integer) : TTypeKind;
Begin
  If (Idx >= 0) And (Idx < TypeCount) Then
    TypeKindOf := TypeTab[Idx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

{ ---- TypeIsNumeric : vrai si le type est numerique ---------- }
{ En AWK, number et uninit (converti implicitement en 0) sont   }
{ numeriques.                                                    }
Function TypeIsNumeric(Idx : Integer) : Boolean;
Var K : TTypeKind;
Begin
  K := TypeKindOf(Idx);
  TypeIsNumeric := (K = TYK_NUMBER) Or (K = TYK_UNINITIALIZED);
End;

{ ---- TypeIsPtr : vrai si le type est un pointeur ------------ }
{ string, regexp et array sont des pointeurs en 16 bits.        }
Function TypeIsPtr(Idx : Integer) : Boolean;
Var K : TTypeKind;
Begin
  K := TypeKindOf(Idx);
  TypeIsPtr := (K = TYK_STRING) Or (K = TYK_REGEXP) Or (K = TYK_ARRAY);
End;

{ ---- TypeCanCoerce : vrai si la coercition src -> dst est possible }
{ En AWK toute coercition scalaire est possible (nombre <-> chaine). }
{ Les tableaux ne se convertissent pas en scalaires.                 }
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  TypeCanCoerce := True;
  If SrcIdx = DstIdx Then Exit;
  If (SrcIdx < 0) Or (DstIdx < 0) Then Exit;
  If (TypeKindOf(SrcIdx) = TYK_ARRAY) And
     (TypeKindOf(DstIdx) <> TYK_ARRAY) Then
    TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type resultant d une operation ------ }
{ Concatenation -> string, comparaison/logique -> number,       }
{ arithmetique : si les deux sont numeriques -> number,         }
{ si l un est chaine -> string, sinon -> number.                }
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Begin
  { Concatenation toujours chaine }
  If Op = 'CONCAT' Then
  Begin TypeCoerceResult := TY_IDX_STRING; Exit; End;
  { Comparaison : resultat numerique (0 ou 1) }
  If (Op = '==') Or (Op = '!=') Or (Op = '<') Or
     (Op = '<=') Or (Op = '>') Or (Op = '>=') Or
     (Op = '~') Or (Op = '!~') Then
  Begin TypeCoerceResult := TY_IDX_NUMBER; Exit; End;
  { Logiques }
  If (Op = '&&') Or (Op = '||') Or (Op = '!') Then
  Begin TypeCoerceResult := TY_IDX_NUMBER; Exit; End;
  { Arithmetique }
  If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    TypeCoerceResult := TY_IDX_NUMBER
  Else If (TypeKindOf(LeftIdx) = TYK_STRING) Or
          (TypeKindOf(RightIdx) = TYK_STRING) Then
    TypeCoerceResult := TY_IDX_STRING
  Else
    TypeCoerceResult := TY_IDX_NUMBER;
End;

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
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- DataAdd : ajouter une entree dans le segment DATA ----- }
{ Retourne l index dans DataTab ou -1 si plein.                }
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
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

{ ---- DataAddStr : creer un label _AWK_N et stocker chaine -- }
{ Retourne l index dans DataTab.                               }
Function DataAddStr(Const S : TString) : Integer;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := AW_STR_PFX + IntToStr(LabelGenSeq);
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- DataAddWord : ajouter variable/constante DW ----------- }
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

{ ---- LitEvalInt : evaluer un token TK_INTEGER --------------- }
{ IntVal est deja calcule par LexScanNumber.                   }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMBER, Res);
End;

{ ---- LitEvalFloat : evaluer un token TK_FLOAT (trunc) ------ }
{ AWK traite les flottants ; en 16 bits on tronque a l entier. }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  ExprMakeImm(IV, TY_IDX_NUMBER, Res);
End;

{ ---- LitEval : dispatcher pour les litteraux ---------------- }
{ Tokens : TK_INTEGER, TK_FLOAT, TK_STRING, TK_REGEXP         }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
    TK_REGEXP  :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_REGEXP;
      Res.Offset  := DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
  End;
End;

{ ============================================================
  OPERATEURS ET PRECEDENCE (TODO 04)
  ============================================================ }

{ ---- IsAssignOp : teste si Op est un operateur d assignation }
Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = '=')  Or (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or
    (Op = '/=') Or (Op = '%=') Or (Op = '^=');
End;

{ ---- BinOpPrec : table de precedences AWK (Pratt) ---------- }
{ Retourne 0 si l operateur n est pas binaire.                 }
{ Niveaux (croissant = plus serre) :                           }
{   = += -= *= /= %= ^=  -> 1  (assignation)                  }
{   ? :                   -> 2  (ternaire)                     }
{   ||                    -> 3  (OU logique)                   }
{   &&                    -> 4  (ET logique)                   }
{   in                    -> 5  (appartenance tableau)          }
{   ~ !~                  -> 6  (correspondance regexp)        }
{   == != < <= > >=       -> 7  (comparaison)                  }
{   (concat)              -> 8  (concatenation implicite)      }
{   + - (binaire)         -> 9                                 }
{   * / %                 -> 10                                }
{   ^ (puissance)         -> 11 (droit-associatif)             }
{   ! ++ -- + - (unaire)  -> traites par ParseUnary            }
{   $ (champ)             -> traite par ParsePrimary           }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If IsAssignOp(Op) Then
    BinOpPrec := 1
  Else If (Op = '?') Or (Op = ':') Then
    BinOpPrec := 2
  Else If Op = '||' Then
    BinOpPrec := 3
  Else If Op = '&&' Then
    BinOpPrec := 4
  Else If Op = 'in' Then
    BinOpPrec := 5
  Else If (Op = '~') Or (Op = '!~') Then
    BinOpPrec := 6
  Else If (Op = '==') Or (Op = '!=') Or
          (Op = '<')  Or (Op = '<=') Or
          (Op = '>')  Or (Op = '>=') Or
          (Op = '>>') Then
    BinOpPrec := 7
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 9
  Else If (Op = '*') Or (Op = '/') Or (Op = '%') Then
    BinOpPrec := 10
  Else If Op = '^' Then
    BinOpPrec := 11
  Else If Op = '|' Then
    BinOpPrec := 0  { pipe dans print, pas operateur binaire normal }
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : vrai si operateur droit-associatif ----- }
{ En AWK : ^ (puissance) et les assignations sont droit-assoc. }
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '^') Or IsAssignOp(Op);
End;

{ ============================================================
  TABLE DES SYMBOLES (TODO 05)
  ============================================================ }

{ ---- SymNameClean : nettoyer un nom pour nommage ASM ------- }
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := '';
  For I := 1 To Length(Name) Do
  Begin
    If IsAlNum(Name[I]) Then
    Begin
      If Length(S) < MAX_STR Then S := S + Name[I];
    End Else
    Begin
      If Length(S) < MAX_STR Then S := S + '_';
    End;
  End;
  SymNameClean := S;
End;

{ ---- SymMangle : generer un label ASM depuis un symbole ---- }
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx : TString;
Begin
  Case Cat Of
    SC_VAR         : Pfx := AW_VAR_PFX;
    SC_BUILTIN_VAR : Pfx := AW_VAR_PFX;
    SC_ARRAY       : Pfx := AW_ARR_PFX;
    SC_PARAM       : Pfx := AW_VAR_PFX;
    SC_FUNCTION    : Pfx := AW_FN_PFX;
    SC_FIELD       : Pfx := AW_VAR_PFX;
  Else
    Pfx := AW_VAR_PFX;
  End;
  SymMangle := Pfx + SymNameClean(Name);
End;

{ ---- SymAdd : ajouter un symbole dans la table ------------- }
{ Retourne l index du symbole (0-base) ou -1 en cas d erreur.  }
Function SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AOffset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := AName;
  SymTab[Idx].MangledName := SymMangle(AName, ACat);
  SymTab[Idx].Cat         := ACat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].IsLocal     := (CurScope > 0);
  SymTab[Idx].IsParam     := (ACat = SC_PARAM);
  SymTab[Idx].IsArray     := (ACat = SC_ARRAY);
  SymTab[Idx].ArrayIdx    := -1;
  SymTab[Idx].DeclLine    := LexLineNo;
  Inc(SymCount);
  SymAdd := Idx;
End;

{ ---- SymFind : chercher dans toutes les portees ------------ }
{ Retourne l index du symbole le plus recent, ou -1.           }
Function SymFind(Const AName : TString) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = AName Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindCat : chercher par nom ET categorie ------------ }
Function SymFindCat(Const AName : TString; ACat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = AName) And (SymTab[I].Cat = ACat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
  SymFindCat := -1;
End;

{ ---- SymEnterScope : entrer dans une portee de fonction ---- }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    FatalError('imbrication de portees trop profonde');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

{ ---- SymLeaveScope : quitter la portee courante ------------ }
{ Retire tous les symboles ajoutes dans cette portee.          }
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount  := ScopeStack[ScopeTop];
  Dec(CurScope);
End;

{ ---- SymInit : initialiser la table et les variables predefinies }
Procedure SymInit;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  DataCount := 0;
  LabelGenSeq := 0;
  { Variables predefinies AWK (SC_BUILTIN_VAR) }
  SymAdd('FS',       SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('RS',       SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('OFS',      SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('ORS',      SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('NR',       SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('NF',       SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('FNR',      SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('FILENAME', SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('RSTART',   SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('RLENGTH',  SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('SUBSEP',   SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('OFMT',     SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('CONVFMT',  SC_BUILTIN_VAR, TY_IDX_STRING, 0);
  SymAdd('ARGC',     SC_BUILTIN_VAR, TY_IDX_NUMBER, 0);
  SymAdd('ARGV',     SC_BUILTIN_VAR, TY_IDX_ARRAY,  0);
End;

{ ============================================================
  EMETTEUR DE CODE ASM (TODO 07)
  ============================================================ }

{ ---- EmitOpen : ouvrir le fichier assembleur de sortie ------ }
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('AWK86: Erreur - impossible de creer ', Opts.OutFile);
    Inc(ErrorCount);
    OutFOpen := False;
    Exit;
  End;
  OutFOpen := True;
End;

{ ---- EmitRaw : ecrire une ligne brute dans la sortie -------- }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then WriteLn(OutF, S);
End;

{ ---- EmitBlankLine : ecrire une ligne vide ------------------- }
Procedure EmitBlankLine;
Begin
  If OutFOpen Then WriteLn(OutF);
End;

{ ---- EmitInstr : ecrire une instruction avec tabulations ---- }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If Not OutFOpen Then Exit;
  If Ops <> '' Then WriteLn(OutF, #9, Mnem, #9, Ops)
  Else WriteLn(OutF, #9, Mnem);
End;

{ ---- EmitLabel : ecrire un label avec deux-points ----------- }
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then WriteLn(OutF, Lbl, ':');
End;

{ ---- EmitComment : ecrire un commentaire assembleur --------- }
Procedure EmitComment(Const Msg : TString);
Begin
  If OutFOpen Then WriteLn(OutF, '; ', Msg);
End;

{ ---- NewLabel : generer un label unique _AWL_prefix_N ------- }
Function NewLabel(Const Prefix : TString) : TString;
Var
  NS : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, NS);
  NewLabel := AW_LBL_PFX + Prefix + '_' + NS;
End;

{ ---- EmitHeader : en-tete MASM .MODEL SMALL ----------------- }
Procedure EmitHeader;
Var
  NS : TString;
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF, '; Generated by AWK86 v', AWK86_VERSION,
                ' (', AWK86_DATE, ')');
  WriteLn(OutF, '; Source : ', Opts.SrcFile);
  WriteLn(OutF, '; Cible  : 8086 DOS (.MODEL SMALL)');
  Str(STACK_SIZE, NS);
  WriteLn(OutF, '; Pile   : ', NS, ' octets');
  WriteLn(OutF);
  WriteLn(OutF, '        .MODEL  SMALL');
  WriteLn(OutF, '        .STACK  ', NS);
  WriteLn(OutF);
  WriteLn(OutF, '_TEXT   SEGMENT PUBLIC ', #39, 'CODE', #39);
  WriteLn(OutF, '        ASSUME  CS:_TEXT');
  WriteLn(OutF);
End;

{ ---- EmitProlog : prologue de fonction (PUSH BP / MOV BP,SP) - }
Procedure EmitProlog(Const FnLbl : TString);
Begin
  EmitLabel(FnLbl);
  EmitInstr('PUSH', 'BP');
  EmitInstr('MOV', 'BP, SP');
End;

{ ---- EmitEpilog : epilogue de fonction (MOV SP,BP / POP BP) -- }
Procedure EmitEpilog(Const RetLbl : TString);
Begin
  EmitLabel(RetLbl);
  EmitInstr('MOV', 'SP, BP');
  EmitInstr('POP', 'BP');
  EmitInstr('RET', '');
End;

{ ---- EmitCoerce : emettre le code de coercition AWK ---------- }
{ Contexte numerique : chaine -> CALL _AWRT_STRTONUM -> AX      }
{ Contexte chaine : nombre -> CALL _AWRT_NUMTOSTR -> AX=ptr     }
Procedure EmitCoerce(SrcTypeIdx, DstTypeIdx : Integer);
Var
  SK, DK : TTypeKind;
Begin
  If SrcTypeIdx = DstTypeIdx Then Exit;
  SK := TypeKindOf(SrcTypeIdx);
  DK := TypeKindOf(DstTypeIdx);
  { Chaine -> nombre }
  If (SK = TYK_STRING) And (DK = TYK_NUMBER) Then
  Begin
    EmitInstr('CALL', AW_RT_PFX + 'STRTONUM');
    Exit;
  End;
  { Nombre -> chaine }
  If (SK = TYK_NUMBER) And (DK = TYK_STRING) Then
  Begin
    EmitInstr('CALL', AW_RT_PFX + 'NUMTOSTR');
    Exit;
  End;
  { Non initialise -> nombre : AX = 0 }
  If (SK = TYK_UNINITIALIZED) And (DK = TYK_NUMBER) Then
  Begin
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
End;

{ ============================================================
  SEGMENT DE DONNEES ET STATIQUES (TODO 08)
  ============================================================ }

{ ---- DataAddArray : ajouter un bloc de tableau associatif ---- }
{ Retourne l index dans DataTab ou -1 si plein.                 }
Function DataAddArray(Const Lbl : TString; NbPairs : Integer) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAddArray := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := Lbl;
  DataTab[DataCount].Kind      := DK_ARRAY_BLK;
  DataTab[DataCount].IntVal    := 0;
  DataTab[DataCount].StrVal    := '';
  DataTab[DataCount].ElemCount := NbPairs;
  DataAddArray := DataCount;
  Inc(DataCount);
End;

{ ---- EmitDataSeg : emettre le segment _DATA complet --------- }
{ Ecrit les variables, constantes, buffers et heap dans DATA.   }
Procedure EmitDataSeg;
Var
  I, J : Integer;
  B    : Byte;
  NS   : String[6];
Begin
  If Not OutFOpen Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT PUBLIC ', #39, 'DATA', #39);
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  WriteLn(OutF);
  EmitComment('--- Variables predefinies AWK ---');
  WriteLn(OutF, AW_VAR_PFX, 'FS:');
  WriteLn(OutF, '        DB      32,0');
  WriteLn(OutF, AW_VAR_PFX, 'RS:');
  WriteLn(OutF, '        DB      10,0');
  WriteLn(OutF, AW_VAR_PFX, 'OFS:');
  WriteLn(OutF, '        DB      32,0');
  WriteLn(OutF, AW_VAR_PFX, 'ORS:');
  WriteLn(OutF, '        DB      13,10,0');
  WriteLn(OutF, AW_VAR_PFX, 'NR:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'NF:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'FNR:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'FILENAME:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'RSTART:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'RLENGTH:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF, AW_VAR_PFX, 'SUBSEP:');
  WriteLn(OutF, '        DB      28,0');
  WriteLn(OutF, AW_VAR_PFX, 'OFMT:');
  WriteLn(OutF, '        DB      37,46,54,103,0'); { %.6g }
  WriteLn(OutF, AW_VAR_PFX, 'CONVFMT:');
  WriteLn(OutF, '        DB      37,46,54,103,0'); { %.6g }
  WriteLn(OutF, AW_VAR_PFX, 'ARGC:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF);
  EmitComment('--- Constantes chaine et donnees utilisateur ---');
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
      DK_ARRAY_BLK :
      Begin
        WriteLn(OutF, '        DW      0'); { count }
        Str(DataTab[I].ElemCount * 4, NS);  { paires cle+val = 4 bytes }
        WriteLn(OutF, '        DB      ', NS, ' DUP(0)');
      End;
    End;
  End;
  WriteLn(OutF);
  EmitComment('--- Buffer d enregistrement et champs ---');
  WriteLn(OutF, '_AW_RECBUF:');
  WriteLn(OutF, '        DB      1024 DUP(0)');
  WriteLn(OutF, '_AW_FIELDS:');
  Str(MAX_FIELDS * 2, NS);
  WriteLn(OutF, '        DB      ', NS, ' DUP(0)');
  WriteLn(OutF);
  EmitComment('--- Heap statique ---');
  WriteLn(OutF, '_AW_HEAP:');
  WriteLn(OutF, '        DB      4096 DUP(0)');
  WriteLn(OutF, '_AW_HEAPTOP:');
  WriteLn(OutF, '        DW      0');
  WriteLn(OutF);
  EmitComment('--- Buffer de conversion numerique ---');
  WriteLn(OutF, '_AW_NUMBUF:');
  WriteLn(OutF, '        DB      12 DUP(0)');
  WriteLn(OutF, '_AW_WORKBUF:');
  WriteLn(OutF, '        DB      256 DUP(0)');
  WriteLn(OutF);
  EmitComment('--- Handles fichiers ouverts (TODO 22) ---');
  WriteLn(OutF, '_AW_FHANDLES:');
  WriteLn(OutF, '        DW      8 DUP(0FFFFh)');
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   ENDS');
End;

{ ============================================================
  RUNTIME MINIMAL (TODO 24)
  ============================================================ }

{ ---- EmitRuntime : emettre les routines runtime _AWRT_* ------ }
{ N emettre qu une seule fois grace au flag RuntimeEmitted.      }
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('=== RUNTIME AWK MINIMAL (TODO 24) ===');
  EmitBlankLine;

  { --- _AWRT_PRINT : ecrire CX octets depuis SI sur handle BX --- }
  EmitLabel(AW_RT_PFX + 'PRINT');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('MOV', 'DX, SI');
  EmitInstr('INT', '21h');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PRINTLN : print + ORS --- }
  EmitLabel(AW_RT_PFX + 'PRINTLN');
  EmitInstr('CALL', AW_RT_PFX + 'PRINT');
  EmitInstr('PUSH', 'SI');
  EmitInstr('LEA', 'SI, ' + AW_VAR_PFX + 'ORS');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('LEA', 'DX, ' + AW_VAR_PFX + 'ORS');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('MOV', 'BX, 1');
  EmitInstr('INT', '21h');
  EmitInstr('POP', 'SI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_STRLEN : compter octets jusqu a 0 -> AX --- }
  EmitLabel(AW_RT_PFX + 'STRLEN');
  EmitInstr('PUSH', 'SI');
  EmitInstr('XOR', 'AX, AX');
  EmitLabel(AW_RT_PFX + 'STRLEN_L');
  EmitInstr('CMP', 'BYTE PTR [SI], 0');
  EmitInstr('JE', AW_RT_PFX + 'STRLEN_D');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'AX');
  EmitInstr('JMP', AW_RT_PFX + 'STRLEN_L');
  EmitLabel(AW_RT_PFX + 'STRLEN_D');
  EmitInstr('POP', 'SI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_NUMTOSTR : AX=n -> ASCII dans _AW_NUMBUF -> AX=ptr --- }
  EmitLabel(AW_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('LEA', 'DI, _AW_NUMBUF');
  EmitInstr('ADD', 'DI, 11');
  EmitInstr('MOV', 'BYTE PTR [DI], 0');
  EmitInstr('DEC', 'DI');
  EmitInstr('MOV', 'BX, 10');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNS', AW_RT_PFX + 'N2S_POS');
  EmitInstr('NEG', 'AX');
  EmitLabel(AW_RT_PFX + 'N2S_POS');
  EmitInstr('XOR', 'DX, DX');
  EmitInstr('DIV', 'BX');
  EmitInstr('ADD', 'DL, 30h');
  EmitInstr('MOV', '[DI], DL');
  EmitInstr('DEC', 'DI');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNZ', AW_RT_PFX + 'N2S_POS');
  EmitInstr('INC', 'DI');
  EmitInstr('MOV', 'AX, DI');
  EmitInstr('POP', 'DX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_STRTONUM : SI=str -> AX (atoi, prefixe num.) --- }
  EmitLabel(AW_RT_PFX + 'STRTONUM');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('XOR', 'CX, CX');
  EmitInstr('MOV', 'BL, [SI]');
  EmitInstr('CMP', 'BL, 2Dh');
  EmitInstr('JNE', AW_RT_PFX + 'S2N_LP');
  EmitInstr('INC', 'CX');
  EmitInstr('INC', 'SI');
  EmitLabel(AW_RT_PFX + 'S2N_LP');
  EmitInstr('MOV', 'BL, [SI]');
  EmitInstr('CMP', 'BL, 30h');
  EmitInstr('JB', AW_RT_PFX + 'S2N_DN');
  EmitInstr('CMP', 'BL, 39h');
  EmitInstr('JA', AW_RT_PFX + 'S2N_DN');
  EmitInstr('SUB', 'BL, 30h');
  EmitInstr('MOV', 'BH, 0');
  EmitInstr('PUSH', 'BX');
  EmitInstr('MOV', 'BX, 10');
  EmitInstr('MUL', 'BX');
  EmitInstr('POP', 'BX');
  EmitInstr('ADD', 'AX, BX');
  EmitInstr('INC', 'SI');
  EmitInstr('JMP', AW_RT_PFX + 'S2N_LP');
  EmitLabel(AW_RT_PFX + 'S2N_DN');
  EmitInstr('TEST', 'CX, CX');
  EmitInstr('JZ', AW_RT_PFX + 'S2N_OK');
  EmitInstr('NEG', 'AX');
  EmitLabel(AW_RT_PFX + 'S2N_OK');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_CONCAT : SI=src1, DI=src2 -> AX=ptr _AW_WORKBUF --- }
  EmitLabel(AW_RT_PFX + 'CONCAT');
  EmitInstr('PUSH', 'SI');
  EmitInstr('PUSH', 'DI');
  EmitInstr('LEA', 'DI, _AW_WORKBUF');
  EmitInstr('MOV', 'AX, DI');
  EmitInstr('PUSH', 'AX');
  EmitLabel(AW_RT_PFX + 'CC_L1');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('MOV', '[DI], AL');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'CC_S2');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'CC_L1');
  EmitLabel(AW_RT_PFX + 'CC_S2');
  EmitInstr('POP', 'AX');
  EmitInstr('POP', 'SI');
  EmitInstr('PUSH', 'AX');
  EmitLabel(AW_RT_PFX + 'CC_L2');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('MOV', '[DI], AL');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'CC_DN');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'CC_L2');
  EmitLabel(AW_RT_PFX + 'CC_DN');
  EmitInstr('POP', 'AX');
  EmitInstr('POP', 'DI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_STRCMP : SI=str1, DI=str2 -> drapeaux ZF/CF --- }
  EmitLabel(AW_RT_PFX + 'STRCMP');
  EmitLabel(AW_RT_PFX + 'SCMP_LP');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('MOV', 'AH, [DI]');
  EmitInstr('CMP', 'AL, AH');
  EmitInstr('JNE', AW_RT_PFX + 'SCMP_DN');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'SCMP_DN');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'SCMP_LP');
  EmitLabel(AW_RT_PFX + 'SCMP_DN');
  EmitInstr('SUB', 'AL, AH');
  EmitInstr('CBW', '');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SUBSTR : SI=str, BX=debut, CX=len -> AX=ptr --- }
  EmitLabel(AW_RT_PFX + 'SUBSTR');
  EmitInstr('PUSH', 'DI');
  EmitInstr('DEC', 'BX');
  EmitInstr('ADD', 'SI, BX');
  EmitInstr('LEA', 'DI, _AW_WORKBUF');
  EmitInstr('MOV', 'AX, DI');
  EmitLabel(AW_RT_PFX + 'SUBS_LP');
  EmitInstr('CMP', 'CX, 0');
  EmitInstr('JE', AW_RT_PFX + 'SUBS_DN');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'SUBS_DN');
  EmitInstr('MOV', '[DI], AL');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('DEC', 'CX');
  EmitInstr('JMP', AW_RT_PFX + 'SUBS_LP');
  EmitLabel(AW_RT_PFX + 'SUBS_DN');
  EmitInstr('MOV', 'BYTE PTR [DI], 0');
  EmitInstr('LEA', 'AX, _AW_WORKBUF');
  EmitInstr('POP', 'DI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_INDEX : SI=str, DI=sub -> AX=position (1-based, 0=not found) --- }
  EmitLabel(AW_RT_PFX + 'INDEX');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('MOV', 'BX, SI');
  EmitInstr('MOV', 'CX, 1');
  EmitLabel(AW_RT_PFX + 'IDX_LP');
  EmitInstr('CMP', 'BYTE PTR [BX], 0');
  EmitInstr('JE', AW_RT_PFX + 'IDX_NF');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'DI');
  EmitLabel(AW_RT_PFX + 'IDX_CM');
  EmitInstr('MOV', 'AL, [DI]');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'IDX_FD');
  EmitInstr('CMP', 'AL, [BX]');
  EmitInstr('JNE', AW_RT_PFX + 'IDX_NX');
  EmitInstr('INC', 'BX');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'IDX_CM');
  EmitLabel(AW_RT_PFX + 'IDX_FD');
  EmitInstr('POP', 'DI');
  EmitInstr('POP', 'BX');
  EmitInstr('MOV', 'AX, CX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'IDX_NX');
  EmitInstr('POP', 'DI');
  EmitInstr('POP', 'BX');
  EmitInstr('INC', 'BX');
  EmitInstr('INC', 'CX');
  EmitInstr('JMP', AW_RT_PFX + 'IDX_LP');
  EmitLabel(AW_RT_PFX + 'IDX_NF');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_TOLOWER : SI=str -> AX=ptr _AW_WORKBUF --- }
  EmitLabel(AW_RT_PFX + 'TOLOWER');
  EmitInstr('PUSH', 'DI');
  EmitInstr('LEA', 'DI, _AW_WORKBUF');
  EmitInstr('MOV', 'AX, DI');
  EmitLabel(AW_RT_PFX + 'TLW_LP');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('CMP', 'AL, 41h');
  EmitInstr('JB', AW_RT_PFX + 'TLW_SK');
  EmitInstr('CMP', 'AL, 5Ah');
  EmitInstr('JA', AW_RT_PFX + 'TLW_SK');
  EmitInstr('ADD', 'AL, 20h');
  EmitLabel(AW_RT_PFX + 'TLW_SK');
  EmitInstr('MOV', '[DI], AL');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'TLW_DN');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'TLW_LP');
  EmitLabel(AW_RT_PFX + 'TLW_DN');
  EmitInstr('LEA', 'AX, _AW_WORKBUF');
  EmitInstr('POP', 'DI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_TOUPPER : SI=str -> AX=ptr _AW_WORKBUF --- }
  EmitLabel(AW_RT_PFX + 'TOUPPER');
  EmitInstr('PUSH', 'DI');
  EmitInstr('LEA', 'DI, _AW_WORKBUF');
  EmitInstr('MOV', 'AX, DI');
  EmitLabel(AW_RT_PFX + 'TUP_LP');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('CMP', 'AL, 61h');
  EmitInstr('JB', AW_RT_PFX + 'TUP_SK');
  EmitInstr('CMP', 'AL, 7Ah');
  EmitInstr('JA', AW_RT_PFX + 'TUP_SK');
  EmitInstr('SUB', 'AL, 20h');
  EmitLabel(AW_RT_PFX + 'TUP_SK');
  EmitInstr('MOV', '[DI], AL');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'TUP_DN');
  EmitInstr('INC', 'SI');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'TUP_LP');
  EmitLabel(AW_RT_PFX + 'TUP_DN');
  EmitInstr('LEA', 'AX, _AW_WORKBUF');
  EmitInstr('POP', 'DI');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_MATCH : SI=str, DI=pat -> AX=0|1 (sous-chaine) --- }
  EmitLabel(AW_RT_PFX + 'MATCH');
  EmitInstr('PUSH', 'BX');
  EmitInstr('MOV', 'BX, SI');
  EmitLabel(AW_RT_PFX + 'MAT_LP');
  EmitInstr('CMP', 'BYTE PTR [BX], 0');
  EmitInstr('JE', AW_RT_PFX + 'MAT_NF');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'DI');
  EmitLabel(AW_RT_PFX + 'MAT_CM');
  EmitInstr('CMP', 'BYTE PTR [DI], 0');
  EmitInstr('JE', AW_RT_PFX + 'MAT_OK');
  EmitInstr('MOV', 'AL, [BX]');
  EmitInstr('CMP', 'AL, [DI]');
  EmitInstr('JNE', AW_RT_PFX + 'MAT_NX');
  EmitInstr('INC', 'BX');
  EmitInstr('INC', 'DI');
  EmitInstr('JMP', AW_RT_PFX + 'MAT_CM');
  EmitLabel(AW_RT_PFX + 'MAT_OK');
  EmitInstr('POP', 'DI');
  EmitInstr('POP', 'BX');
  EmitInstr('MOV', 'AX, 1');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'MAT_NX');
  EmitInstr('POP', 'DI');
  EmitInstr('POP', 'BX');
  EmitInstr('INC', 'BX');
  EmitInstr('JMP', AW_RT_PFX + 'MAT_LP');
  EmitLabel(AW_RT_PFX + 'MAT_NF');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_MATCHPOS : SI=str, DI=pat -> AX=RSTART --- }
  EmitLabel(AW_RT_PFX + 'MATCHPOS');
  EmitInstr('CALL', AW_RT_PFX + 'INDEX');
  EmitInstr('MOV', '[' + AW_VAR_PFX + 'RSTART], AX');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RT_PFX + 'MP_DN');
  EmitInstr('PUSH', 'AX');
  EmitInstr('MOV', 'SI, DI');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', '[' + AW_VAR_PFX + 'RLENGTH], AX');
  EmitInstr('POP', 'AX');
  EmitLabel(AW_RT_PFX + 'MP_DN');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SUB : SI=target, DI=pat, BX=repl -> AX=0|1 --- }
  EmitLabel(AW_RT_PFX + 'SUB');
  EmitComment('sub() stub : premiere occurrence');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_GSUB : SI=target, DI=pat, BX=repl -> AX=count --- }
  EmitLabel(AW_RT_PFX + 'GSUB');
  EmitComment('gsub() stub : substitution globale');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SPLIT : SI=str, DI=arr, BX=sep -> AX=nb_elems --- }
  EmitLabel(AW_RT_PFX + 'SPLIT');
  EmitComment('split() stub');
  EmitInstr('MOV', 'AX, 1');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_READLINE : lire un enregistrement -> AX=ptr --- }
  EmitLabel(AW_RT_PFX + 'READLINE');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('LEA', 'DX, _AW_RECBUF');
  EmitInstr('MOV', 'BX, 0');
  EmitInstr('MOV', 'CX, 1');
  EmitInstr('MOV', 'DI, DX');
  EmitLabel(AW_RT_PFX + 'RL_LP');
  EmitInstr('MOV', 'AH, 3Fh');
  EmitInstr('INT', '21h');
  EmitInstr('JC', AW_RT_PFX + 'RL_EOF');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RT_PFX + 'RL_EOF');
  EmitInstr('MOV', 'AL, [DI]');
  EmitInstr('CMP', 'AL, 10');
  EmitInstr('JE', AW_RT_PFX + 'RL_OK');
  EmitInstr('CMP', 'AL, 13');
  EmitInstr('JE', AW_RT_PFX + 'RL_CR');
  EmitInstr('INC', 'DI');
  EmitInstr('MOV', 'DX, DI');
  EmitInstr('JMP', AW_RT_PFX + 'RL_LP');
  EmitLabel(AW_RT_PFX + 'RL_CR');
  EmitInstr('MOV', 'DX, DI');
  EmitInstr('JMP', AW_RT_PFX + 'RL_LP');
  EmitLabel(AW_RT_PFX + 'RL_OK');
  EmitInstr('MOV', 'BYTE PTR [DI], 0');
  EmitInstr('LEA', 'AX, _AW_RECBUF');
  EmitInstr('POP', 'DX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'RL_EOF');
  EmitInstr('MOV', 'BYTE PTR [DI], 0');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('POP', 'DX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_GETLINE : raccourci pour readline --- }
  EmitLabel(AW_RT_PFX + 'GETLINE');
  EmitInstr('CALL', AW_RT_PFX + 'READLINE');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SPLITREC : decouper $0 en champs selon FS --- }
  EmitLabel(AW_RT_PFX + 'SPLITREC');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DI');
  EmitInstr('LEA', 'SI, _AW_RECBUF');
  EmitInstr('LEA', 'DI, _AW_FIELDS');
  EmitInstr('MOV', '[DI], SI');
  EmitInstr('ADD', 'DI, 2');
  EmitInstr('MOV', 'CX, 1');
  EmitInstr('LEA', 'BX, ' + AW_VAR_PFX + 'FS');
  EmitInstr('MOV', 'BL, [BX]');
  EmitLabel(AW_RT_PFX + 'SR_LP');
  EmitInstr('MOV', 'AL, [SI]');
  EmitInstr('TEST', 'AL, AL');
  EmitInstr('JZ', AW_RT_PFX + 'SR_DN');
  EmitInstr('CMP', 'AL, BL');
  EmitInstr('JNE', AW_RT_PFX + 'SR_NX');
  EmitInstr('MOV', 'BYTE PTR [SI], 0');
  EmitInstr('INC', 'SI');
  EmitInstr('MOV', '[DI], SI');
  EmitInstr('ADD', 'DI, 2');
  EmitInstr('INC', 'CX');
  EmitInstr('JMP', AW_RT_PFX + 'SR_LP');
  EmitLabel(AW_RT_PFX + 'SR_NX');
  EmitInstr('INC', 'SI');
  EmitInstr('JMP', AW_RT_PFX + 'SR_LP');
  EmitLabel(AW_RT_PFX + 'SR_DN');
  EmitInstr('MOV', '[' + AW_VAR_PFX + 'NF], CX');
  EmitInstr('POP', 'DI');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_GETFIELD : AX=n -> AX=ptr vers champ $n --- }
  EmitLabel(AW_RT_PFX + 'GETFIELD');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RT_PFX + 'GF_Z');
  EmitInstr('DEC', 'AX');
  EmitInstr('SHL', 'AX, 1');
  EmitInstr('LEA', 'SI, _AW_FIELDS');
  EmitInstr('ADD', 'SI, AX');
  EmitInstr('MOV', 'AX, [SI]');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'GF_Z');
  EmitInstr('LEA', 'AX, _AW_RECBUF');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SETFIELD : BX=n, AX=val -> met a jour champ --- }
  EmitLabel(AW_RT_PFX + 'SETFIELD');
  EmitComment('setfield stub');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_REBUILD0 : reconstruire $0 a partir des champs --- }
  EmitLabel(AW_RT_PFX + 'REBUILD0');
  EmitComment('rebuild0 stub');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PRINTVAL : ecrire AX comme valeur sur stdout --- }
  EmitLabel(AW_RT_PFX + 'PRINTVAL');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('MOV', 'BX, 1');
  EmitInstr('MOV', 'DX, SI');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PRINTOFS : ecrire OFS sur stdout --- }
  EmitLabel(AW_RT_PFX + 'PRINTOFS');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'SI');
  EmitInstr('LEA', 'SI, ' + AW_VAR_PFX + 'OFS');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('LEA', 'DX, ' + AW_VAR_PFX + 'OFS');
  EmitInstr('MOV', 'BX, 1');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitInstr('POP', 'SI');
  EmitInstr('POP', 'CX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PRINTORS : ecrire ORS sur stdout --- }
  EmitLabel(AW_RT_PFX + 'PRINTORS');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'SI');
  EmitInstr('LEA', 'SI, ' + AW_VAR_PFX + 'ORS');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('LEA', 'DX, ' + AW_VAR_PFX + 'ORS');
  EmitInstr('MOV', 'BX, 1');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitInstr('POP', 'SI');
  EmitInstr('POP', 'CX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_ARRGET/SET/HAS/DEL/FIRST/NEXT : stubs tableaux --- }
  EmitLabel(AW_RT_PFX + 'ARRGET');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRSET');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRHAS');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRDEL');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRCLEAR');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRFIRST');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRNEXT');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'ARRLEN');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_HASH : SI=key -> AX=index --- }
  EmitLabel(AW_RT_PFX + 'HASH');
  EmitInstr('XOR', 'AX, AX');
  EmitLabel(AW_RT_PFX + 'HSH_LP');
  EmitInstr('MOV', 'BL, [SI]');
  EmitInstr('TEST', 'BL, BL');
  EmitInstr('JZ', AW_RT_PFX + 'HSH_DN');
  EmitInstr('MOV', 'BH, 0');
  EmitInstr('ADD', 'AX, BX');
  EmitInstr('INC', 'SI');
  EmitInstr('JMP', AW_RT_PFX + 'HSH_LP');
  EmitLabel(AW_RT_PFX + 'HSH_DN');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_POW : AX=base, BX=exp -> AX --- }
  EmitLabel(AW_RT_PFX + 'POW');
  EmitInstr('PUSH', 'CX');
  EmitInstr('MOV', 'CX, BX');
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('MOV', 'AX, 1');
  EmitLabel(AW_RT_PFX + 'POW_LP');
  EmitInstr('TEST', 'CX, CX');
  EmitInstr('JZ', AW_RT_PFX + 'POW_DN');
  EmitInstr('IMUL', 'BX');
  EmitInstr('DEC', 'CX');
  EmitInstr('JMP', AW_RT_PFX + 'POW_LP');
  EmitLabel(AW_RT_PFX + 'POW_DN');
  EmitInstr('POP', 'CX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SQRT : AX=n -> AX (Newton-Raphson entier) --- }
  EmitLabel(AW_RT_PFX + 'SQRT');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('PUSH', 'DX');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RT_PFX + 'SQR_DN');
  EmitInstr('SHR', 'AX, 1');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNZ', AW_RT_PFX + 'SQR_LP');
  EmitInstr('MOV', 'AX, 1');
  EmitLabel(AW_RT_PFX + 'SQR_LP');
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('MOV', 'AX, CX');
  EmitInstr('XOR', 'DX, DX');
  EmitInstr('DIV', 'BX');
  EmitInstr('ADD', 'AX, BX');
  EmitInstr('SHR', 'AX, 1');
  EmitInstr('CMP', 'AX, BX');
  EmitInstr('JB', AW_RT_PFX + 'SQR_LP');
  EmitInstr('MOV', 'AX, BX');
  EmitLabel(AW_RT_PFX + 'SQR_DN');
  EmitInstr('POP', 'DX');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_RAND : LCG 16 bits -> AX (0..32767) --- }
  EmitLabel(AW_RT_PFX + 'RAND');
  EmitInstr('MOV', 'AX, [' + AW_RT_PFX + 'SEED]');
  EmitInstr('MOV', 'BX, 25173');
  EmitInstr('MUL', 'BX');
  EmitInstr('ADD', 'AX, 13849');
  EmitInstr('MOV', '[' + AW_RT_PFX + 'SEED], AX');
  EmitInstr('AND', 'AX, 7FFFh');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_EXP : AX=n -> AX (approximation entiere e^n) --- }
  EmitLabel(AW_RT_PFX + 'EXP');
  EmitInstr('PUSH', 'BX');
  EmitInstr('PUSH', 'CX');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('MOV', 'AX, 1');
  EmitInstr('MOV', 'BX, 3');
  EmitLabel(AW_RT_PFX + 'EXP_LP');
  EmitInstr('TEST', 'CX, CX');
  EmitInstr('JZ', AW_RT_PFX + 'EXP_DN');
  EmitInstr('IMUL', 'BX');
  EmitInstr('DEC', 'CX');
  EmitInstr('JMP', AW_RT_PFX + 'EXP_LP');
  EmitLabel(AW_RT_PFX + 'EXP_DN');
  EmitInstr('POP', 'CX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_LOG : AX=n -> AX (approximation entiere ln(n)) --- }
  EmitLabel(AW_RT_PFX + 'LOG');
  EmitInstr('PUSH', 'BX');
  EmitInstr('XOR', 'BX, BX');
  EmitLabel(AW_RT_PFX + 'LOG_LP');
  EmitInstr('CMP', 'AX, 3');
  EmitInstr('JB', AW_RT_PFX + 'LOG_DN');
  EmitInstr('PUSH', 'DX');
  EmitInstr('XOR', 'DX, DX');
  EmitInstr('MOV', 'CX, 3');
  EmitInstr('DIV', 'CX');
  EmitInstr('POP', 'DX');
  EmitInstr('INC', 'BX');
  EmitInstr('JMP', AW_RT_PFX + 'LOG_LP');
  EmitLabel(AW_RT_PFX + 'LOG_DN');
  EmitInstr('MOV', 'AX, BX');
  EmitInstr('POP', 'BX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_TRUTHY : AX=val, BX=type -> AX=0|1 (TODO 23) --- }
  EmitLabel(AW_RT_PFX + 'TRUTHY');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RT_PFX + 'TRU_F');
  EmitInstr('MOV', 'AX, 1');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'TRU_F');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PRINTF : SI=fmt, args sur pile -> ecriture stdout --- }
  EmitLabel(AW_RT_PFX + 'PRINTF');
  EmitComment('printf : stub simplifie - ecrit le format tel quel');
  EmitInstr('MOV', 'SI, [SP+4]');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('MOV', 'BX, 1');
  EmitInstr('MOV', 'DX, SI');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_SPRINTF : stub -> AX=ptr chaine vide --- }
  EmitLabel(AW_RT_PFX + 'SPRINTF');
  EmitInstr('LEA', 'AX, _AW_WORKBUF');
  EmitInstr('MOV', 'BYTE PTR [_AW_WORKBUF], 0');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_FOPEN : SI=nom, AL=mode -> BX=handle (TODO 22) --- }
  EmitLabel(AW_RT_PFX + 'FOPEN');
  EmitInstr('MOV', 'DX, SI');
  EmitInstr('MOV', 'AH, 3Dh');
  EmitInstr('MOV', 'AL, 0');
  EmitInstr('INT', '21h');
  EmitInstr('JNC', AW_RT_PFX + 'FO_OK');
  EmitInstr('MOV', 'BX, 0FFFFh');
  EmitInstr('RET', '');
  EmitLabel(AW_RT_PFX + 'FO_OK');
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_FCLOSE : SI=nom -> fermer fichier (TODO 22) --- }
  EmitLabel(AW_RT_PFX + 'FCLOSE');
  EmitComment('fclose : stub');
  EmitInstr('XOR', 'AX, AX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_FGETLINE : BX=handle -> AX=ptr (TODO 22) --- }
  EmitLabel(AW_RT_PFX + 'FGETLINE');
  EmitInstr('CALL', AW_RT_PFX + 'READLINE');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_ALLOC : CX=nb_bytes -> AX=ptr dans heap statique --- }
  EmitLabel(AW_RT_PFX + 'ALLOC');
  EmitInstr('MOV', 'AX, [_AW_HEAPTOP]');
  EmitInstr('LEA', 'BX, _AW_HEAP');
  EmitInstr('ADD', 'AX, BX');
  EmitInstr('ADD', '[_AW_HEAPTOP], CX');
  EmitInstr('RET', '');
  EmitBlankLine;

  { --- _AWRT_PANIC : SI=msg -> affiche et termine --- }
  EmitLabel(AW_RT_PFX + 'PANIC');
  EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
  EmitInstr('MOV', 'CX, AX');
  EmitInstr('MOV', 'BX, 2');
  EmitInstr('MOV', 'DX, SI');
  EmitInstr('MOV', 'AH, 40h');
  EmitInstr('INT', '21h');
  EmitInstr('MOV', 'AX, 4C01h');
  EmitInstr('INT', '21h');
  EmitBlankLine;

  { --- _AWRT_SEED : graine du generateur pseudo-aleatoire --- }
  EmitLabel(AW_RT_PFX + 'SEED');
  EmitRaw('        DW      1');
  EmitBlankLine;
End;

{ ---- EmitClose : fermer le fichier de sortie (TODO 25) ------- }
Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    EmitRuntime;
    EmitBlankLine;
    WriteLn(OutF, '_TEXT   ENDS');
    EmitDataSeg;
    WriteLn(OutF);
    WriteLn(OutF, '        END     ', AW_RULE_PFX, 'ENTRY');
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  VARIABLES ET AFFECTATIONS (TODO 09)
  ============================================================ }

{ ---- VarLoadToAX : charger une variable dans AX ------------- }
{ Idx = index dans SymTab.                                      }
Procedure VarLoadToAX(Idx : Integer);
Var
  OfsStr : TString;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then
  Begin
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  If SymTab[Idx].IsLocal Or SymTab[Idx].IsParam Then
  Begin
    If SymTab[Idx].Offset < 0 Then
    Begin
      Str(-SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', 'AX, [BP-' + OfsStr + ']');
    End
    Else
    Begin
      Str(SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', 'AX, [BP+' + OfsStr + ']');
    End;
  End
  Else
    EmitInstr('MOV', 'AX, [' + SymTab[Idx].MangledName + ']');
End;

{ ---- VarStore : stocker AX dans une variable ----------------- }
{ Idx = index dans SymTab.                                      }
Procedure VarStore(Idx : Integer);
Var
  OfsStr : TString;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then Exit;
  If SymTab[Idx].IsLocal Or SymTab[Idx].IsParam Then
  Begin
    If SymTab[Idx].Offset < 0 Then
    Begin
      Str(-SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', '[BP-' + OfsStr + '], AX');
    End
    Else
    Begin
      Str(SymTab[Idx].Offset, OfsStr);
      EmitInstr('MOV', '[BP+' + OfsStr + '], AX');
    End;
  End
  Else
    EmitInstr('MOV', '[' + SymTab[Idx].MangledName + '], AX');
End;

{ ---- GenAssignOp : generer le code pour op= (+=, -= etc) ---- }
Procedure GenAssignOp(Idx : Integer; Const Op : TString);
Begin
  { AX contient la valeur droite, charger gauche dans BX }
  EmitInstr('MOV', 'BX, AX');    { sauver rhs dans BX }
  VarLoadToAX(Idx);              { charger lhs dans AX }
  If Op = '+=' Then
    EmitInstr('ADD', 'AX, BX')
  Else If Op = '-=' Then
    EmitInstr('SUB', 'AX, BX')
  Else If Op = '*=' Then
    EmitInstr('IMUL', 'BX')
  Else If Op = '/=' Then
  Begin
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
  End
  Else If Op = '%=' Then
  Begin
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    EmitInstr('MOV', 'AX, DX');
  End
  Else If Op = '^=' Then
  Begin
    EmitInstr('PUSH', 'BX');
    EmitInstr('PUSH', 'AX');
    EmitInstr('CALL', AW_RT_PFX + 'POW');
    EmitInstr('ADD', 'SP, 4');
  End;
  VarStore(Idx);
End;

{ ---- GenPreInc : pre-increment ++var ------------------------- }
Procedure GenPreInc(Idx : Integer);
Begin
  VarLoadToAX(Idx);
  EmitInstr('INC', 'AX');
  VarStore(Idx);
End;

{ ---- GenPreDec : pre-decrement --var ------------------------- }
Procedure GenPreDec(Idx : Integer);
Begin
  VarLoadToAX(Idx);
  EmitInstr('DEC', 'AX');
  VarStore(Idx);
End;

{ ---- GenPostInc : post-increment var++ ----------------------- }
{ La valeur avant increment est laissee dans AX.                }
Procedure GenPostInc(Idx : Integer);
Begin
  VarLoadToAX(Idx);
  EmitInstr('PUSH', 'AX');       { sauver ancienne valeur       }
  EmitInstr('INC', 'AX');
  VarStore(Idx);
  EmitInstr('POP', 'AX');        { restaurer ancienne valeur    }
End;

{ ---- GenPostDec : post-decrement var-- ----------------------- }
Procedure GenPostDec(Idx : Integer);
Begin
  VarLoadToAX(Idx);
  EmitInstr('PUSH', 'AX');
  EmitInstr('DEC', 'AX');
  VarStore(Idx);
  EmitInstr('POP', 'AX');
End;

{ ---- GenFieldLoad : charger un champ $n dans AX ------------- }
{ AX contient l index du champ (0..NF).                        }
Procedure GenFieldLoad;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'GETFIELD');
End;

{ ---- GenFieldStore : stocker AX dans le champ $n ------------ }
{ BX contient l index du champ, AX contient la valeur.         }
Procedure GenFieldStore;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'SETFIELD');
End;

{ ============================================================
  EXPRESSIONS PRIMAIRES (TODO 10)
  ============================================================ }

{ ---- ExprMakeAX : valeur dans le registre AX ----------------- }
Procedure ExprMakeAX(ATypeIdx : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprLoadToAX : charger une expression dans AX ----------- }
{ Emet le code necessaire pour que la valeur soit dans AX.      }
Procedure ExprLoadToAX(Var E : TExprVal);
Var
  NS : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstr('XOR', 'AX, AX')
      Else
      Begin
        Str(E.ImmVal, NS);
        EmitInstr('MOV', 'AX, ' + NS);
      End;
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      If E.SymIdx >= 0 Then
        VarLoadToAX(E.SymIdx)
      Else If (E.Offset >= 0) And (E.Offset < DataCount) Then
        EmitInstr('LEA', 'AX, ' + DataTab[E.Offset].LblName)
      Else
        EmitInstr('XOR', 'AX, AX');
      E.Kind := EK_AX;
    End;
    EK_AX : ; { deja dans AX }
    EK_NONE :
      EmitInstr('XOR', 'AX, AX');
  End;
End;

{ ---- Forward declarations pour recursion mutuelle ------------ }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;
Procedure ParseStmtOrBlock; Forward;
Procedure ParseFuncDecl; Forward;
Procedure GenMatchCall; Forward;
Procedure GenMatchPos; Forward;
Procedure GenSubCall; Forward;
Procedure GenGsubCall; Forward;
Procedure GenSplitCall; Forward;

{ ---- ParsePrimary : analyser une expression primaire AWK ----- }
{ Gere : literal nombre, literal chaine, regexp, identifiant,   }
{   reference de champ $n, acces tableau, (expr), appel de       }
{   fonction, getline primaire.                                  }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Idx    : Integer;
  VName  : TString;
  NS     : TString;
Begin
  ExprMakeNone(Res);
  Case CurToken.Kind Of
    { --- Literal entier --- }
    TK_INTEGER :
    Begin
      LitEvalInt(CurToken, Res);
      ParserAdvance;
    End;

    { --- Literal flottant (tronque en entier) --- }
    TK_FLOAT :
    Begin
      LitEvalFloat(CurToken, Res);
      ParserAdvance;
    End;

    { --- Literal chaine "..." --- }
    TK_STRING :
    Begin
      Idx := DataAddStr(CurToken.Val);
      Res.Kind    := EK_MEM;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := Idx;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;

    { --- Expression reguliere /pattern/ --- }
    TK_REGEXP :
    Begin
      Idx := DataAddStr(CurToken.Val);
      Res.Kind    := EK_MEM;
      Res.TypeIdx := TY_IDX_REGEXP;
      Res.Offset  := Idx;
      Res.SymIdx  := -1;
      ParserAdvance;
    End;

    { --- Reference de champ $n --- }
    TK_FIELD :
    Begin
      VName := CurToken.Val;
      ParserAdvance;
      { $0..$9 : champ numerique simple }
      If (Length(VName) = 1) And (VName[1] >= '0') And (VName[1] <= '9') Then
      Begin
        Str(Ord(VName[1]) - Ord('0'), NS);
        EmitInstr('MOV', 'AX, ' + NS);
      End
      { $NF : dernier champ }
      Else If VName = 'NF' Then
        EmitInstr('MOV', 'AX, [' + AW_VAR_PFX + 'NF]')
      Else
      Begin
        { champ a indice variable : chercher la variable }
        Idx := SymFind(VName);
        If Idx >= 0 Then
          VarLoadToAX(Idx)
        Else
          EmitInstr('XOR', 'AX, AX');
      End;
      GenFieldLoad;
      ExprMakeAX(TY_IDX_STRING, Res);
    End;

    { --- Identificateur : variable, tableau ou fonction --- }
    TK_IDENT :
    Begin
      VName := CurToken.Val;
      ParserAdvance;
      { Acces tableau arr[key] }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
      Begin
        ParserAdvance; { '[' }
        Idx := SymFind(VName);
        If Idx < 0 Then
          Idx := SymAdd(VName, SC_ARRAY, TY_IDX_ARRAY, 0);
        EmitComment('arr[key] : ' + VName);
        EmitInstr('LEA', 'SI, ' + SymTab[Idx].MangledName);
        { Evaluer l expression de cle }
        ParseExprPrec(1, Res);
        ExprLoadToAX(Res);
        EmitInstr('MOV', 'DI, AX');
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
          ParserAdvance;
        EmitInstr('CALL', AW_RT_PFX + 'ARRGET');
        ExprMakeAX(TY_IDX_STRING, Res);
      End
      { Appel de fonction nom(args) }
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance; { '(' }
        EmitComment('call ' + VName);
        { Evaluer les arguments et les empiler }
        NS := '0'; { compteur d arguments }
        Idx := 0;
        If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
        Begin
          Repeat
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('PUSH', 'AX');
            Inc(Idx);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance
            Else
              Break;
          Until CurToken.Kind = TK_EOF;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        EmitInstr('CALL', AW_FN_PFX + SymNameClean(VName));
        If Idx > 0 Then
        Begin
          Str(Idx * 2, NS);
          EmitInstr('ADD', 'SP, ' + NS);
        End;
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      { Variable simple }
      Else
      Begin
        Idx := SymFind(VName);
        If Idx < 0 Then
          Idx := SymAdd(VName, SC_VAR, TY_IDX_UNINIT, 0);
        Res.Kind    := EK_MEM;
        Res.TypeIdx := SymTab[Idx].TypeIdx;
        Res.Offset  := SymTab[Idx].Offset;
        Res.SymIdx  := Idx;
      End;
    End;

    { --- Fonction builtin AWK (TODO 20) --- }
    TK_BUILTIN :
    Begin
      VName := CurToken.Val;
      ParserAdvance;
      EmitComment('builtin ' + VName);
      { length sans parenthese -> length($0) }
      If (VName = 'length') And
         Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
      Begin
        EmitInstr('XOR', 'AX, AX');
        GenFieldLoad;
        EmitInstr('MOV', 'SI, AX');
        EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance;
        { --- length(s) ou length(arr) --- }
        If VName = 'length' Then
        Begin
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          Begin
            { length() -> length($0) }
            EmitInstr('XOR', 'AX, AX');
            GenFieldLoad;
            EmitInstr('MOV', 'SI, AX');
            EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
          End
          Else
          Begin
            { Verifier si c est un tableau }
            If (CurToken.Kind = TK_IDENT) Then
            Begin
              Idx := SymFind(CurToken.Val);
              If (Idx >= 0) And (SymTab[Idx].Cat = SC_ARRAY) Then
              Begin
                EmitInstr('LEA', 'SI, ' + SymTab[Idx].MangledName);
                ParserAdvance;
                EmitInstr('CALL', AW_RT_PFX + 'ARRLEN');
              End
              Else
              Begin
                ParseExprPrec(1, Res);
                ExprLoadToAX(Res);
                EmitInstr('MOV', 'SI, AX');
                EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
              End;
            End
            Else
            Begin
              ParseExprPrec(1, Res);
              ExprLoadToAX(Res);
              EmitInstr('MOV', 'SI, AX');
              EmitInstr('CALL', AW_RT_PFX + 'STRLEN');
            End;
          End;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- substr(s, debut [, longueur]) --- }
        Else If VName = 'substr' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');         { s }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'BX, AX');      { debut }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            ParserAdvance;
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('MOV', 'CX, AX');    { longueur }
          End
          Else
            EmitInstr('MOV', 'CX, 0FFFFh'); { longueur max }
          EmitInstr('POP', 'SI');           { s }
          EmitInstr('CALL', AW_RT_PFX + 'SUBSTR');
          ExprMakeAX(TY_IDX_STRING, Res);
        End
        { --- index(s, t) --- }
        Else If VName = 'index' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');         { s }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'DI, AX');      { t }
          EmitInstr('POP', 'SI');           { s }
          EmitInstr('CALL', AW_RT_PFX + 'INDEX');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- split(s, arr, sep) --- }
        Else If VName = 'split' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');          { s }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          { arr }
          If CurToken.Kind = TK_IDENT Then
          Begin
            Idx := SymFind(CurToken.Val);
            If Idx < 0 Then
              Idx := SymAdd(CurToken.Val, SC_ARRAY, TY_IDX_ARRAY, 0);
            EmitInstr('LEA', 'DI, ' + SymTab[Idx].MangledName);
            ParserAdvance;
          End
          Else
            EmitInstr('XOR', 'DI, DI');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            ParserAdvance;
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('MOV', 'BX, AX');    { sep }
          End
          Else
            EmitInstr('LEA', 'BX, [' + AW_VAR_PFX + 'FS]');
          EmitInstr('POP', 'SI');           { s }
          GenSplitCall;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- sub(r, s [, t]) --- }
        Else If VName = 'sub' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');          { r (pattern) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'BX, AX');       { s (replacement) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            ParserAdvance;
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('MOV', 'SI, AX');     { t (target) }
          End
          Else
          Begin
            EmitInstr('XOR', 'AX, AX');
            GenFieldLoad;
            EmitInstr('MOV', 'SI, AX');     { $0 par defaut }
          End;
          EmitInstr('POP', 'DI');           { r }
          GenSubCall;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- gsub(r, s [, t]) --- }
        Else If VName = 'gsub' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');          { r (pattern) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'BX, AX');       { s (replacement) }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
          Begin
            ParserAdvance;
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('MOV', 'SI, AX');     { t (target) }
          End
          Else
          Begin
            EmitInstr('XOR', 'AX, AX');
            GenFieldLoad;
            EmitInstr('MOV', 'SI, AX');     { $0 par defaut }
          End;
          EmitInstr('POP', 'DI');           { r }
          GenGsubCall;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- match(s, r) --- }
        Else If VName = 'match' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('PUSH', 'AX');          { s }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'DI, AX');       { r }
          EmitInstr('POP', 'SI');            { s }
          GenMatchPos;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- tolower(s) --- }
        Else If VName = 'tolower' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'SI, AX');
          EmitInstr('CALL', AW_RT_PFX + 'TOLOWER');
          ExprMakeAX(TY_IDX_STRING, Res);
        End
        { --- toupper(s) --- }
        Else If VName = 'toupper' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'SI, AX');
          EmitInstr('CALL', AW_RT_PFX + 'TOUPPER');
          ExprMakeAX(TY_IDX_STRING, Res);
        End
        { --- sprintf(fmt, args...) --- }
        Else If VName = 'sprintf' Then
        Begin
          Idx := 0;
          Repeat
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('PUSH', 'AX');
            Inc(Idx);
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
              ParserAdvance
            Else
              Break;
          Until CurToken.Kind = TK_EOF;
          Str(Idx, NS);
          EmitInstr('MOV', 'CX, ' + NS);
          EmitInstr('CALL', AW_RT_PFX + 'SPRINTF');
          If Idx > 0 Then
          Begin
            Str(Idx * 2, NS);
            EmitInstr('ADD', 'SP, ' + NS);
          End;
          ExprMakeAX(TY_IDX_STRING, Res);
        End
        { --- int(x) : troncature vers zero (TODO 21) --- }
        Else If VName = 'int' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          { Entier 16 bits -> deja tronque, pass-through }
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- sqrt(x) : racine carree entiere (TODO 21) --- }
        Else If VName = 'sqrt' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('CALL', AW_RT_PFX + 'SQRT');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- sin(x) : stub retourne 0 (TODO 21) --- }
        Else If VName = 'sin' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitComment('sin() stub : pas de flottant 16 bits');
          EmitInstr('XOR', 'AX, AX');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- cos(x) : stub retourne 1 (TODO 21) --- }
        Else If VName = 'cos' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitComment('cos() stub : pas de flottant 16 bits');
          EmitInstr('MOV', 'AX, 1');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- atan2(y, x) : stub retourne 0 (TODO 21) --- }
        Else If VName = 'atan2' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitComment('atan2() stub : pas de flottant 16 bits');
          EmitInstr('XOR', 'AX, AX');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- exp(x) : exponentielle entiere (TODO 21) --- }
        Else If VName = 'exp' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('CALL', AW_RT_PFX + 'EXP');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- log(x) : logarithme entier (TODO 21) --- }
        Else If VName = 'log' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('CALL', AW_RT_PFX + 'LOG');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- rand() : nombre pseudo-aleatoire (TODO 21) --- }
        Else If VName = 'rand' Then
        Begin
          { rand() sans argument }
          EmitInstr('CALL', AW_RT_PFX + 'RAND');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- srand([x]) : initialiser la graine (TODO 21) --- }
        Else If VName = 'srand' Then
        Begin
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          Begin
            { srand() sans argument : utiliser horloge systeme }
            EmitInstr('MOV', 'AH, 00h');
            EmitInstr('INT', '1Ah');
            EmitInstr('MOV', '[' + AW_RT_PFX + 'SEED], DX');
          End
          Else
          Begin
            { srand(x) : utiliser la valeur fournie }
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
            EmitInstr('MOV', '[' + AW_RT_PFX + 'SEED], AX');
          End;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- system(cmd) : executer commande systeme (TODO 22) --- }
        Else If VName = 'system' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitComment('system() : stub DOS (pas supporte directement)');
          EmitInstr('XOR', 'AX, AX');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- close(fichier) : fermer un fichier (TODO 22) --- }
        Else If VName = 'close' Then
        Begin
          ParseExprPrec(1, Res);
          ExprLoadToAX(Res);
          EmitInstr('MOV', 'SI, AX');
          EmitInstr('CALL', AW_RT_PFX + 'FCLOSE');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- fflush([fichier]) : vider les tampons (TODO 22) --- }
        Else If VName = 'fflush' Then
        Begin
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
          Begin
            ParseExprPrec(1, Res);
            ExprLoadToAX(Res);
          End;
          EmitComment('fflush() : stub (pas de buffer en mode DOS)');
          EmitInstr('XOR', 'AX, AX');
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        { --- Autre builtin generique --- }
        Else
        Begin
          { Evaluer les arguments et les empiler }
          Idx := 0;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
          Begin
            Repeat
              ParseExprPrec(1, Res);
              ExprLoadToAX(Res);
              EmitInstr('PUSH', 'AX');
              Inc(Idx);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance
              Else
                Break;
            Until CurToken.Kind = TK_EOF;
          End;
          EmitInstr('CALL', AW_RT_PFX + SymNameClean(VName));
          If Idx > 0 Then
          Begin
            Str(Idx * 2, NS);
            EmitInstr('ADD', 'SP, ' + NS);
          End;
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End;
        { Fermer la parenthese }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
      End
      Else
      Begin
        { Builtin sans parenthese, traiter comme appel simple }
        EmitInstr('CALL', AW_RT_PFX + SymNameClean(VName));
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End;
    End;

    { --- Mot-cle special (getline) --- }
    TK_KEYWORD :
    Begin
      If CurToken.Val = 'getline' Then
      Begin
        ParserAdvance;
        EmitInstr('CALL', AW_RT_PFX + 'GETLINE');
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      Else
      Begin
        CompileError('expression inattendue: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;

    { --- Groupement parenthese (expr) --- }
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance; { '(' }
        ParseExprPrec(1, Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance
        Else
          CompileError(') attendu');
      End
      Else
      Begin
        CompileError('expression primaire attendue, got: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;

    { --- Operateur unaire en position primaire --- }
    TK_OP :
    Begin
      If CurToken.Val = '-' Then
      Begin
        ParserAdvance;
        ParsePrimary(Res);
        ExprLoadToAX(Res);
        EmitInstr('NEG', 'AX');
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      Else If CurToken.Val = '+' Then
      Begin
        ParserAdvance;
        ParsePrimary(Res);
        { unaire + force la coercition numerique }
        ExprLoadToAX(Res);
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      Else If CurToken.Val = '!' Then
      Begin
        ParserAdvance;
        ParsePrimary(Res);
        ExprLoadToAX(Res);
        EmitInstr('TEST', 'AX, AX');
        EmitInstr('MOV', 'AX, 0');
        Idx := 0; { reuse Idx for label trick }
        VName := NewLabel('NOT');
        EmitInstr('JNZ', VName);
        EmitInstr('MOV', 'AX, 1');
        EmitLabel(VName);
        ExprMakeAX(TY_IDX_NUMBER, Res);
      End
      Else If CurToken.Val = '++' Then
      Begin
        ParserAdvance;
        If CurToken.Kind = TK_IDENT Then
        Begin
          Idx := SymFind(CurToken.Val);
          If Idx < 0 Then
            Idx := SymAdd(CurToken.Val, SC_VAR, TY_IDX_NUMBER, 0);
          ParserAdvance;
          GenPreInc(Idx);
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        Else
        Begin
          CompileError('variable attendue apres ++');
          ParserAdvance;
        End;
      End
      Else If CurToken.Val = '--' Then
      Begin
        ParserAdvance;
        If CurToken.Kind = TK_IDENT Then
        Begin
          Idx := SymFind(CurToken.Val);
          If Idx < 0 Then
            Idx := SymAdd(CurToken.Val, SC_VAR, TY_IDX_NUMBER, 0);
          ParserAdvance;
          GenPreDec(Idx);
          ExprMakeAX(TY_IDX_NUMBER, Res);
        End
        Else
        Begin
          CompileError('variable attendue apres --');
          ParserAdvance;
        End;
      End
      Else
      Begin
        CompileError('operateur unaire inattendu: ' + CurToken.Val);
        ParserAdvance;
      End;
    End;

    { --- Fin de ligne / fin de fichier --- }
    TK_NEWLINE, TK_EOF : ; { rien }

  Else
    CompileError('token inattendu: ' + CurToken.Val);
    ParserAdvance;
  End;
End;

{ ============================================================
  EXPRESSIONS BINAIRES (TODO 11)
  ============================================================ }

{ ---- SkipNewlines : sauter les fins de ligne logiques -------- }
Procedure SkipNewlines;
Begin
  While CurToken.Kind = TK_NEWLINE Do
    ParserAdvance;
End;

{ ---- IsConcatContext : detection de juxtaposition implicite -- }
{ Vrai si le token courant peut debuter un operande droit de    }
{ concatenation (pas un operateur binaire ni un terminateur).   }
Function IsConcatContext : Boolean;
Begin
  IsConcatContext := False;
  Case CurToken.Kind Of
    TK_INTEGER, TK_FLOAT, TK_STRING, TK_REGEXP,
    TK_IDENT, TK_BUILTIN, TK_FIELD :
      IsConcatContext := True;
    TK_PUNCT :
      If CurToken.Val = '(' Then IsConcatContext := True;
    TK_OP :
      If (CurToken.Val = '-') Or (CurToken.Val = '+') Or
         (CurToken.Val = '!') Or (CurToken.Val = '++') Or
         (CurToken.Val = '--') Then
        IsConcatContext := True;
  End;
End;

{ ---- ParseExprPrec : parseur de Pratt pour expressions ------- }
{ MinPrec = niveau de precedence minimal a capturer.            }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Rhs      : TExprVal;
  Idx      : Integer;
  LblF     : TString;
  LblE     : TString;
  LblT     : TString;
  ResType  : Integer;
Begin
  ParsePrimary(Res);
  { Post-increment / post-decrement }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '++') Then
  Begin
    If Res.SymIdx >= 0 Then
    Begin
      ExprLoadToAX(Res);
      GenPostInc(Res.SymIdx);
      ExprMakeAX(TY_IDX_NUMBER, Res);
    End;
    ParserAdvance;
  End
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '--') Then
  Begin
    If Res.SymIdx >= 0 Then
    Begin
      ExprLoadToAX(Res);
      GenPostDec(Res.SymIdx);
      ExprMakeAX(TY_IDX_NUMBER, Res);
    End;
    ParserAdvance;
  End;
  { Boucle binaire Pratt }
  While True Do
  Begin
    { Operateur binaire explicite ou mot-cle in }
    If (CurToken.Kind = TK_OP) Then
      Op := CurToken.Val
    Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
      Op := 'in'
    Else
      Op := '';
    Prec := BinOpPrec(Op);
    { Concatenation implicite (juxtaposition) si pas d op binaire }
    If ((Op = '') Or (Prec = 0)) And (MinPrec <= 8) And IsConcatContext Then
    Begin
      ExprLoadToAX(Res);
      EmitInstr('PUSH', 'AX');        { sauver gauche }
      EmitInstr('MOV', 'SI, AX');
      ParseExprPrec(9, Rhs);           { niveau 9 = plus serre }
      ExprLoadToAX(Rhs);
      EmitInstr('MOV', 'DI, AX');
      EmitInstr('POP', 'SI');
      EmitInstr('CALL', AW_RT_PFX + 'CONCAT');
      ExprMakeAX(TY_IDX_STRING, Res);
      Continue;
    End;
    If (Prec = 0) Or (Prec < MinPrec) Then Break;
    ParserAdvance;
    { Affectation : droit-associatif, RHS d abord }
    If IsAssignOp(Op) Then
    Begin
      Idx := Res.SymIdx;
      ParseExprPrec(Prec, Rhs);
      ExprLoadToAX(Rhs);
      If Op = '=' Then
      Begin
        If Idx >= 0 Then
          VarStore(Idx);
      End
      Else
      Begin
        If Idx >= 0 Then
          GenAssignOp(Idx, Op);
      End;
      ExprMakeAX(TY_IDX_NUMBER, Res);
      Continue;
    End;
    { Ternaire ? : }
    If Op = '?' Then
    Begin
      ExprLoadToAX(Res);
      LblF := NewLabel('TERNF');
      LblE := NewLabel('TERNE');
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblF);
      ParseExprPrec(3, Res);  { niveau 3 pour ne pas capturer : }
      ExprLoadToAX(Res);
      EmitInstr('JMP', LblE);
      EmitLabel(LblF);
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':') Then
        ParserAdvance
      Else
        CompileError(': attendu dans ternaire');
      ParseExprPrec(3, Rhs);
      ExprLoadToAX(Rhs);
      EmitLabel(LblE);
      ExprMakeAX(TY_IDX_NUMBER, Res);
      Continue;
    End;
    { Logique && : court-circuit }
    If Op = '&&' Then
    Begin
      ExprLoadToAX(Res);
      LblF := NewLabel('ANDF');
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblF);
      If BinOpIsRight(Op) Then NextPrec := Prec
      Else NextPrec := Prec + 1;
      ParseExprPrec(NextPrec, Rhs);
      ExprLoadToAX(Rhs);
      EmitLabel(LblF);
      ExprMakeAX(TY_IDX_NUMBER, Res);
      Continue;
    End;
    { Logique || : court-circuit }
    If Op = '||' Then
    Begin
      ExprLoadToAX(Res);
      LblT := NewLabel('ORT');
      LblE := NewLabel('ORE');
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ', LblT);
      If BinOpIsRight(Op) Then NextPrec := Prec
      Else NextPrec := Prec + 1;
      ParseExprPrec(NextPrec, Rhs);
      ExprLoadToAX(Rhs);
      EmitInstr('JMP', LblE);
      EmitLabel(LblT);
      EmitInstr('MOV', 'AX, 1');
      EmitLabel(LblE);
      ExprMakeAX(TY_IDX_NUMBER, Res);
      Continue;
    End;
    { Operateur in : test d appartenance }
    If Op = 'in' Then
    Begin
      ExprLoadToAX(Res);
      EmitInstr('MOV', 'DI, AX');    { cle }
      If CurToken.Kind = TK_IDENT Then
      Begin
        Idx := SymFind(CurToken.Val);
        If Idx < 0 Then
          Idx := SymAdd(CurToken.Val, SC_ARRAY, TY_IDX_ARRAY, 0);
        EmitInstr('LEA', 'SI, ' + SymTab[Idx].MangledName);
        ParserAdvance;
      End
      Else
      Begin
        CompileError('nom de tableau attendu apres in');
        EmitInstr('XOR', 'SI, SI');
      End;
      EmitInstr('CALL', AW_RT_PFX + 'ARRHAS');
      ExprMakeAX(TY_IDX_NUMBER, Res);
      Continue;
    End;
    { Tous les autres operateurs binaires }
    ExprLoadToAX(Res);
    EmitInstr('PUSH', 'AX');
    If BinOpIsRight(Op) Then NextPrec := Prec
    Else NextPrec := Prec + 1;
    ParseExprPrec(NextPrec, Rhs);
    ExprLoadToAX(Rhs);
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('POP', 'AX');
    ResType := TypeCoerceResult(Res.TypeIdx, Rhs.TypeIdx, Op);
    { Arithmetique }
    If Op = '+' Then
      EmitInstr('ADD', 'AX, BX')
    Else If Op = '-' Then
      EmitInstr('SUB', 'AX, BX')
    Else If Op = '*' Then
      EmitInstr('IMUL', 'BX')
    Else If Op = '/' Then
    Begin
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
    End
    Else If Op = '%' Then
    Begin
      EmitInstr('CWD', '');
      EmitInstr('IDIV', 'BX');
      EmitInstr('MOV', 'AX, DX');
    End
    Else If Op = '^' Then
    Begin
      EmitInstr('PUSH', 'BX');
      EmitInstr('PUSH', 'AX');
      EmitInstr('CALL', AW_RT_PFX + 'POW');
      EmitInstr('ADD', 'SP, 4');
    End
    { Comparaison }
    Else If (Op = '==') Or (Op = '!=') Or (Op = '<') Or
            (Op = '<=') Or (Op = '>') Or (Op = '>=') Then
    Begin
      LblT := NewLabel('CMP');
      LblE := NewLabel('CMPE');
      EmitInstr('CMP', 'AX, BX');
      If Op = '==' Then EmitInstr('JE', LblT)
      Else If Op = '!=' Then EmitInstr('JNE', LblT)
      Else If Op = '<' Then EmitInstr('JL', LblT)
      Else If Op = '<=' Then EmitInstr('JLE', LblT)
      Else If Op = '>' Then EmitInstr('JG', LblT)
      Else If Op = '>=' Then EmitInstr('JGE', LblT);
      EmitInstr('XOR', 'AX, AX');
      EmitInstr('JMP', LblE);
      EmitLabel(LblT);
      EmitInstr('MOV', 'AX, 1');
      EmitLabel(LblE);
      ResType := TY_IDX_NUMBER;
    End
    { Correspondance regexp }
    Else If Op = '~' Then
    Begin
      EmitInstr('MOV', 'SI, AX');
      EmitInstr('MOV', 'DI, BX');
      EmitInstr('CALL', AW_RT_PFX + 'MATCH');
      ResType := TY_IDX_NUMBER;
    End
    Else If Op = '!~' Then
    Begin
      EmitInstr('MOV', 'SI, AX');
      EmitInstr('MOV', 'DI, BX');
      EmitInstr('CALL', AW_RT_PFX + 'MATCH');
      EmitInstr('XOR', 'AX, 1');
      ResType := TY_IDX_NUMBER;
    End;
    ExprMakeAX(ResType, Res);
  End;
End;

{ ---- ParseExpr : raccourci pour ParseExprPrec(1, Res) -------- }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  ENTREES/SORTIES (TODO 12)
  ============================================================ }

{ ---- ParsePrintStmt : print expr, expr, ... [> file] --------- }
Procedure ParsePrintStmt;
Var
  Res    : TExprVal;
  ArgCnt : Integer;
  Redir  : Boolean;
Begin
  EmitComment('print statement');
  ArgCnt := 0;
  Redir  := False;
  { print sans argument -> print $0 }
  If (CurToken.Kind = TK_NEWLINE) Or (CurToken.Kind = TK_EOF) Or
     (CurToken.Kind = TK_PUNCT) And
     ((CurToken.Val = ';') Or (CurToken.Val = '}')) Then
  Begin
    EmitInstr('MOV', 'AX, 0');
    EmitInstr('CALL', AW_RT_PFX + 'GETFIELD');
    EmitInstr('CALL', AW_RT_PFX + 'PRINTVAL');
    EmitInstr('CALL', AW_RT_PFX + 'PRINTORS');
    Exit;
  End;
  { print expr, expr, ... }
  Repeat
    ParseExprPrec(1, Res);
    ExprLoadToAX(Res);
    EmitInstr('CALL', AW_RT_PFX + 'PRINTVAL');
    Inc(ArgCnt);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      EmitInstr('CALL', AW_RT_PFX + 'PRINTOFS');
      ParserAdvance;
    End
    Else
      Break;
  Until CurToken.Kind = TK_EOF;
  { Redirection > ou >> }
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '>') Or (CurToken.Val = '>>')) Then
  Begin
    Redir := True;
    ParserAdvance;
    ParseExprPrec(1, Res);
    ExprLoadToAX(Res);
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('CALL', AW_RT_PFX + 'FOPEN');
    { BX = handle }
    EmitInstr('CALL', AW_RT_PFX + 'FCLOSE');
  End;
  If Not Redir Then
    EmitInstr('CALL', AW_RT_PFX + 'PRINTORS');
End;

{ ---- ParsePrintfStmt : printf fmt, expr, ... ----------------- }
Procedure ParsePrintfStmt;
Var
  Res    : TExprVal;
  ArgCnt : Integer;
  NS     : TString;
Begin
  EmitComment('printf statement');
  ArgCnt := 0;
  Repeat
    ParseExprPrec(1, Res);
    ExprLoadToAX(Res);
    EmitInstr('PUSH', 'AX');
    Inc(ArgCnt);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until CurToken.Kind = TK_EOF;
  Str(ArgCnt, NS);
  EmitInstr('MOV', 'CX, ' + NS);
  EmitInstr('CALL', AW_RT_PFX + 'PRINTF');
  If ArgCnt > 0 Then
  Begin
    Str(ArgCnt * 2, NS);
    EmitInstr('ADD', 'SP, ' + NS);
  End;
End;

{ ---- ParseGetline : getline [var] [< file] ------------------- }
Procedure ParseGetline;
Var
  Res : TExprVal;
  Idx : Integer;
Begin
  EmitComment('getline');
  { getline var }
  If CurToken.Kind = TK_IDENT Then
  Begin
    Idx := SymFind(CurToken.Val);
    If Idx < 0 Then
      Idx := SymAdd(CurToken.Val, SC_VAR, TY_IDX_STRING, 0);
    ParserAdvance;
    EmitInstr('CALL', AW_RT_PFX + 'GETLINE');
    VarStore(Idx);
  End
  { getline < "fichier" }
  Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '<') Then
  Begin
    ParserAdvance;
    ParseExprPrec(1, Res);
    ExprLoadToAX(Res);
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('CALL', AW_RT_PFX + 'FGETLINE');
  End
  Else
    EmitInstr('CALL', AW_RT_PFX + 'GETLINE');
End;

{ ============================================================
  IF / ELSE (TODO 13)
  ============================================================ }

{ ---- ParseIfStmt : if (cond) stmt [else stmt] ---------------- }
Procedure ParseIfStmt;
Var
  Res     : TExprVal;
  LblElse : TString;
  LblEnd  : TString;
Begin
  EmitComment('if');
  { Attendre ( }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('( attendu apres if');
  { Condition }
  ParseExprPrec(1, Res);
  ExprLoadToAX(Res);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(') attendu apres condition if');
  LblElse := NewLabel('ELSE');
  LblEnd  := NewLabel('ENDIF');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblElse);
  { Branche then }
  SkipNewlines;
  ParseStmtOrBlock;
  { Branche else }
  SkipNewlines;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblElse);
    ParserAdvance;
    SkipNewlines;
    ParseStmtOrBlock;
    EmitLabel(LblEnd);
  End
  Else
    EmitLabel(LblElse);
End;

{ ============================================================
  BOUCLES (TODO 14)
  ============================================================ }

{ ---- LoopPush : empiler les labels break/continue ------------ }
Procedure LoopPush(Const BrkLbl, ContLbl : TString);
Begin
  If LoopDepth >= MAX_LOOP_NEST Then
  Begin
    CompileError('imbrication de boucles trop profonde');
    Exit;
  End;
  LoopBreakLbl[LoopDepth] := BrkLbl;
  LoopContLbl[LoopDepth]  := ContLbl;
  Inc(LoopDepth);
End;

{ ---- LoopPop : depiler les labels break/continue ------------- }
Procedure LoopPop;
Begin
  If LoopDepth > 0 Then
    Dec(LoopDepth);
End;

{ ---- ParseWhileStmt : while (cond) stmt_ou_bloc -------------- }
Procedure ParseWhileStmt;
Var
  Res     : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('while');
  LblTest := NewLabel('WTEST');
  LblEnd  := NewLabel('WEND');
  LoopPush(LblEnd, LblTest);
  EmitLabel(LblTest);
  { Condition }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('( attendu apres while');
  ParseExprPrec(1, Res);
  ExprLoadToAX(Res);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError(') attendu apres condition while');
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblEnd);
  { Corps }
  SkipNewlines;
  ParseStmtOrBlock;
  EmitInstr('JMP', LblTest);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ---- ParseDoWhileStmt : do stmt while (cond) ----------------- }
Procedure ParseDoWhileStmt;
Var
  Res      : TExprVal;
  LblBegin : TString;
  LblTest  : TString;
Begin
  EmitComment('do-while');
  LblBegin := NewLabel('DOBEG');
  LblTest  := NewLabel('DOTEST');
  LoopPush(LblTest, LblTest);
  EmitLabel(LblBegin);
  { Corps }
  SkipNewlines;
  ParseStmtOrBlock;
  SkipNewlines;
  { while (cond) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'while') Then
    ParserAdvance
  Else
    CompileError('while attendu apres do { ... }');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  EmitLabel(LblTest);
  ParseExprPrec(1, Res);
  ExprLoadToAX(Res);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JNZ', LblBegin);
  LoopPop;
End;

{ ---- ParseForStmt : for (...) ou for (var in arr) ------------ }
Procedure ParseForStmt;
Var
  Res      : TExprVal;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  LblBody  : TString;
  LblFI    : TString;
  LblFIE   : TString;
  VName    : TString;
  Idx      : Integer;
  ArrIdx   : Integer;
  IsForIn  : Boolean;
Begin
  EmitComment('for');
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance
  Else
    CompileError('( attendu apres for');
  { Detecter for (var in array) }
  IsForIn := False;
  If (CurToken.Kind = TK_IDENT) Then
  Begin
    VName := CurToken.Val;
    { Regarder si le prochain token (apres l ident) est 'in' }
    { Sauver la position pour reculer si ce n est pas for-in }
    ParserAdvance;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'in') Then
    Begin
      IsForIn := True;
      ParserAdvance; { consommer 'in' }
    End;
  End;
  If IsForIn Then
  Begin
    { for (var in array) }
    EmitComment('for-in ' + VName);
    Idx := SymFind(VName);
    If Idx < 0 Then
      Idx := SymAdd(VName, SC_VAR, TY_IDX_STRING, 0);
    If CurToken.Kind = TK_IDENT Then
    Begin
      ArrIdx := SymFind(CurToken.Val);
      If ArrIdx < 0 Then
        ArrIdx := SymAdd(CurToken.Val, SC_ARRAY, TY_IDX_ARRAY, 0);
      EmitInstr('LEA', 'SI, ' + SymTab[ArrIdx].MangledName);
      ParserAdvance;
    End
    Else
    Begin
      CompileError('nom de tableau attendu dans for-in');
      EmitInstr('XOR', 'SI, SI');
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    LblFI  := NewLabel('FITEST');
    LblFIE := NewLabel('FIEND');
    LoopPush(LblFIE, LblFI);
    EmitInstr('CALL', AW_RT_PFX + 'ARRFIRST');
    EmitLabel(LblFI);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblFIE);
    VarStore(Idx);
    { Corps }
    SkipNewlines;
    ParseStmtOrBlock;
    EmitInstr('CALL', AW_RT_PFX + 'ARRNEXT');
    EmitInstr('JMP', LblFI);
    EmitLabel(LblFIE);
    LoopPop;
  End
  Else
  Begin
    { for (init; cond; incr) corps }
    { L ident deja consomme est le debut de init (peut-etre assignation) }
    { On va traiter le cas ou c est une variable = expr }
    LblTest := NewLabel('FTEST');
    LblIncr := NewLabel('FINCR');
    LblEnd  := NewLabel('FEND');
    LoopPush(LblEnd, LblIncr);
    { init : on a deja consomme VName, verifier s il y a = }
    If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
    Begin
      Idx := SymFind(VName);
      If Idx < 0 Then
        Idx := SymAdd(VName, SC_VAR, TY_IDX_NUMBER, 0);
      ParserAdvance; { = }
      ParseExprPrec(1, Res);
      ExprLoadToAX(Res);
      VarStore(Idx);
    End
    Else
    Begin
      { init peut etre n importe quelle expression }
      { VName est deja consomme, essayer de traiter comme expr }
      Idx := SymFind(VName);
      If Idx >= 0 Then
        VarLoadToAX(Idx);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    { cond }
    EmitLabel(LblTest);
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
    Begin
      ParseExprPrec(1, Res);
      ExprLoadToAX(Res);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblEnd);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    { Sauver la position d increment pour l emettre apres le corps }
    { On ne peut pas facilement sauver, donc on emet un JMP par-dessus }
    { l increment et on l emet a la place du label }
    LblBody := NewLabel('FBODY');
    EmitInstr('JMP', LblBody);
    EmitLabel(LblIncr);
    { incr }
    If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      ParseExprPrec(1, Res);
      ExprLoadToAX(Res);
    End;
    EmitInstr('JMP', LblTest);
    EmitLabel(LblBody);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    { Corps }
    SkipNewlines;
    ParseStmtOrBlock;
    EmitInstr('JMP', LblIncr);
    EmitLabel(LblEnd);
    LoopPop;
  End;
End;

{ ============================================================
  TABLEAUX ASSOCIATIFS (TODO 15)
  ============================================================ }

{ ---- ParseDeleteStmt : delete arr[key] ou delete arr --------- }
Procedure ParseDeleteStmt;
Var
  Idx : Integer;
  Res : TExprVal;
Begin
  EmitComment('delete');
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de tableau attendu apres delete');
    Exit;
  End;
  Idx := SymFind(CurToken.Val);
  If Idx < 0 Then
    Idx := SymAdd(CurToken.Val, SC_ARRAY, TY_IDX_ARRAY, 0);
  EmitInstr('LEA', 'SI, ' + SymTab[Idx].MangledName);
  ParserAdvance;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
  Begin
    { delete arr[key] }
    ParserAdvance;
    ParseExprPrec(1, Res);
    ExprLoadToAX(Res);
    EmitInstr('MOV', 'DI, AX');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
      ParserAdvance;
    EmitInstr('CALL', AW_RT_PFX + 'ARRDEL');
  End
  Else
  Begin
    { delete arr (vider tout le tableau) }
    EmitInstr('CALL', AW_RT_PFX + 'ARRCLEAR');
  End;
End;

{ ============================================================
  CHAMPS ET ENREGISTREMENTS (TODO 16)
  ============================================================ }

{ ---- GenReadLine : lire le prochain enregistrement ----------- }
{ Appelle _AWRT_READLINE, met a jour NR et FNR, puis decoupe.  }
Procedure GenReadLine;
Begin
  EmitComment('readline + splitrec');
  EmitInstr('CALL', AW_RT_PFX + 'READLINE');
  EmitInstr('INC', 'WORD PTR [' + AW_VAR_PFX + 'NR]');
  EmitInstr('INC', 'WORD PTR [' + AW_VAR_PFX + 'FNR]');
  EmitInstr('CALL', AW_RT_PFX + 'SPLITREC');
End;

{ ---- GenSplitRec : decouper $0 en champs -------------------- }
{ Utilise FS pour decouper _AW_RECBUF en _AW_FIELDS et NF.     }
Procedure GenSplitRec;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'SPLITREC');
End;

{ ---- GenFieldAssign : affecter un champ $n = val ------------- }
{ AX = valeur, BX = index du champ.                            }
{ Apres affectation, reconstruit $0.                            }
Procedure GenFieldAssign;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'SETFIELD');
  EmitInstr('CALL', AW_RT_PFX + 'REBUILD0');
End;

{ ---- GenResetFNR : remettre FNR a zero pour nouveau fichier -- }
Procedure GenResetFNR;
Begin
  EmitInstr('MOV', 'WORD PTR [' + AW_VAR_PFX + 'FNR], 0');
End;

{ ============================================================
  FONCTIONS UTILISATEUR (TODO 17)
  ============================================================ }

{ ---- ParseFuncDecl : function nom(params) bloc --------------- }
{ Compile une declaration de fonction utilisateur AWK.          }
{ Convention cdecl 16 bits : args empiles droite a gauche.      }
{ Params apres l espace extra sont des variables locales.       }
Procedure ParseFuncDecl;
Var
  FnName   : TString;
  FnLbl    : TString;
  RetLbl   : TString;
  SkipLbl  : TString;
  ParamCnt : Integer;
  LocalCnt : Integer;
  PName    : TString;
  Idx      : Integer;
  SaveFrame: Integer;
  SaveRet  : TString;
  NS       : TString;
Begin
  EmitComment('function declaration');
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('nom de fonction attendu apres function');
    Exit;
  End;
  FnName := CurToken.Val;
  FnLbl  := AW_FN_PFX + SymNameClean(FnName);
  RetLbl := NewLabel('FRET');
  ParserAdvance;
  { Enregistrer la fonction dans la table des symboles }
  Idx := SymFind(FnName);
  If Idx < 0 Then
    Idx := SymAdd(FnName, SC_FUNCTION, TY_IDX_NUMBER, 0);
  SymTab[Idx].MangledName := FnLbl;
  { Sauvegarder le contexte }
  SaveFrame := CurFrameSize;
  SaveRet   := CurFnRetLbl;
  CurFnRetLbl := RetLbl;
  ParamCnt := 0;
  LocalCnt := 0;
  { Parser les parametres }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  SymEnterScope;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')'))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    If CurToken.Kind = TK_IDENT Then
    Begin
      PName := CurToken.Val;
      Inc(ParamCnt);
      { Offset positif par rapport a BP : [BP+4] = 1er param, [BP+6] = 2eme }
      Idx := SymAdd(PName, SC_PARAM, TY_IDX_UNINIT, ParamCnt * 2 + 2);
      SymTab[Idx].IsParam := True;
      SymTab[Idx].IsLocal := True;
      ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  CurFrameSize := 0;
  { Emettre un JMP par-dessus le corps de la fonction }
  SkipLbl := NewLabel('FSKIP');
  EmitInstr('JMP', SkipLbl);
  { Prologue }
  EmitProlog(FnLbl);
  If LocalCnt > 0 Then
  Begin
    Str(LocalCnt * 2, NS);
    EmitInstr('SUB', 'SP, ' + NS);
  End;
  { Corps de la fonction }
  SkipNewlines;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParseBlock
  Else
    CompileError('accolade ouvrante attendue dans function');
  { Valeur par defaut : 0 }
  EmitInstr('XOR', 'AX, AX');
  { Epilogue }
  EmitEpilog(RetLbl);
  EmitLabel(SkipLbl);
  SymLeaveScope;
  { Restaurer le contexte }
  CurFrameSize := SaveFrame;
  CurFnRetLbl  := SaveRet;
End;

{ ============================================================
  EXPRESSIONS REGULIERES ET CORRESPONDANCE (TODO 18)
  ============================================================ }

{ ---- GenMatchCall : emettre un appel _AWRT_MATCH ------------- }
{ SI = chaine, DI = pattern. Retourne AX = 0 ou 1.            }
Procedure GenMatchCall;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'MATCH');
End;

{ ---- GenMatchPos : emettre un appel _AWRT_MATCHPOS ----------- }
{ SI = chaine, DI = pattern. Met a jour RSTART et RLENGTH.    }
{ Retourne AX = RSTART (0 si pas de correspondance).          }
Procedure GenMatchPos;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'MATCHPOS');
End;

{ ---- GenSubCall : emettre un appel _AWRT_SUB ----------------- }
{ SI = target, DI = pattern, BX = replacement.                 }
Procedure GenSubCall;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'SUB');
End;

{ ---- GenGsubCall : emettre un appel _AWRT_GSUB --------------- }
{ SI = target, DI = pattern, BX = replacement. AX = nb_rempl. }
Procedure GenGsubCall;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'GSUB');
End;

{ ---- GenSplitCall : emettre un appel _AWRT_SPLIT ------------- }
{ SI = chaine, DI = tableau, BX = separateur. AX = nb_elems.  }
Procedure GenSplitCall;
Begin
  EmitInstr('CALL', AW_RT_PFX + 'SPLIT');
End;

{ ---- GenRangePattern : emettre le test d un pattern de plage - }
{ /pat1/,/pat2/ : utilise un flag d etat _AWR_RANGE_N.         }
{ Retourne AX = 1 si dans la plage, 0 sinon.                  }
Procedure GenRangePattern(Const FlagLbl, Pat1Lbl, Pat2Lbl : TString);
Var
  LblActive : TString;
  LblEnd    : TString;
  LblTest2  : TString;
Begin
  LblActive := NewLabel('RNG_ACT');
  LblEnd    := NewLabel('RNG_END');
  LblTest2  := NewLabel('RNG_T2');
  EmitComment('range pattern');
  EmitInstr('CMP', 'WORD PTR [' + FlagLbl + '], 0');
  EmitInstr('JNZ', LblActive);
  { Pas encore active : tester pat1 }
  EmitInstr('LEA', 'SI, _AW_RECBUF');
  EmitInstr('LEA', 'DI, ' + Pat1Lbl);
  GenMatchCall;
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblEnd);
  EmitInstr('MOV', 'WORD PTR [' + FlagLbl + '], 1');
  EmitInstr('MOV', 'AX, 1');
  EmitInstr('JMP', LblEnd);
  { Active : tester pat2 pour desactiver }
  EmitLabel(LblActive);
  EmitInstr('LEA', 'SI, _AW_RECBUF');
  EmitInstr('LEA', 'DI, ' + Pat2Lbl);
  GenMatchCall;
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', LblTest2);
  EmitInstr('MOV', 'WORD PTR [' + FlagLbl + '], 0');
  EmitLabel(LblTest2);
  EmitInstr('MOV', 'AX, 1');
  EmitLabel(LblEnd);
End;

{ ============================================================
  REGLES PATTERN-ACTION (TODO 19)
  ============================================================ }

{ ---- EmitEntryPoint : emettre le point d entree _AWR_ENTRY --- }
Procedure EmitEntryPoint;
Begin
  EmitLabel(AW_RULE_PFX + 'ENTRY');
  EmitComment('programme AWK : point d entree');
  EmitInstr('MOV', 'AX, _DATA');
  EmitInstr('MOV', 'DS, AX');
End;

{ ---- EmitBeginCall : appeler la section BEGIN si presente ---- }
Procedure EmitBeginCall;
Begin
  If HasBegin Then
    EmitInstr('CALL', AW_RULE_PFX + 'BEGIN');
End;

{ ---- EmitMainLoop : emettre la boucle principale ------------- }
{ Lit chaque enregistrement, decoupe, teste les patterns.       }
Procedure EmitMainLoop;
Var
  I       : Integer;
  LblSkip : TString;
Begin
  EmitLabel(AW_RULE_PFX + 'MAIN');
  GenReadLine;
  EmitInstr('TEST', 'AX, AX');
  EmitInstr('JZ', AW_RULE_PFX + 'DONE');
  { Tester chaque regle }
  For I := 0 To RuleCount - 1 Do
  Begin
    If RulePatterns[I] = '' Then
    Begin
      { Pas de pattern : toujours executer }
      EmitInstr('CALL', RuleLabels[I]);
    End
    Else If RulePatterns[I] = '*EXPR*' Then
    Begin
      { Pattern expression : deja emis inline }
      EmitInstr('CALL', RuleLabels[I]);
    End
    Else
    Begin
      { Pattern regexp : tester $0 ~ /pat/ }
      LblSkip := NewLabel('RSKIP');
      EmitInstr('LEA', 'SI, _AW_RECBUF');
      EmitInstr('LEA', 'DI, ' + RulePatterns[I]);
      GenMatchCall;
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ', LblSkip);
      EmitInstr('CALL', RuleLabels[I]);
      EmitLabel(LblSkip);
    End;
  End;
  EmitInstr('JMP', AW_RULE_PFX + 'MAIN');
  EmitLabel(AW_RULE_PFX + 'DONE');
End;

{ ---- EmitEndCall : appeler la section END si presente -------- }
Procedure EmitEndCall;
Begin
  If HasEnd Then
    EmitInstr('CALL', AW_RULE_PFX + 'END');
End;

{ ---- EmitExit : sortie propre du programme ------------------- }
Procedure EmitProgramExit;
Begin
  EmitInstr('MOV', 'AX, 4C00h');
  EmitInstr('INT', '21h');
End;

{ ---- ParseBlock : bloc d instructions entre accolades -------- }
Procedure ParseBlock;
Begin
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParserAdvance;
  SkipNewlines;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseStatement;
    SkipNewlines;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    SkipNewlines;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;
End;

{ ---- ParseStmtOrBlock : statement unique ou bloc accolades --- }
Procedure ParseStmtOrBlock;
Begin
  SkipNewlines;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    ParseBlock
  Else
    ParseStatement;
End;

{ ---- ParseStatement : analyser un statement AWK -------------- }
Procedure ParseStatement;
Var
  Res : TExprVal;
Begin
  SkipNewlines;
  If CurToken.Kind = TK_EOF Then Exit;
  { Terminateur }
  If (CurToken.Kind = TK_PUNCT) And
     ((CurToken.Val = ';') Or (CurToken.Val = '}')) Then
    Exit;
  { Mots-cles de controle }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If CurToken.Val = 'if' Then
    Begin
      ParserAdvance;
      ParseIfStmt;
      Exit;
    End;
    If CurToken.Val = 'while' Then
    Begin
      ParserAdvance;
      ParseWhileStmt;
      Exit;
    End;
    If CurToken.Val = 'do' Then
    Begin
      ParserAdvance;
      ParseDoWhileStmt;
      Exit;
    End;
    If CurToken.Val = 'for' Then
    Begin
      ParserAdvance;
      ParseForStmt;
      Exit;
    End;
    If CurToken.Val = 'print' Then
    Begin
      ParserAdvance;
      ParsePrintStmt;
      Exit;
    End;
    If CurToken.Val = 'printf' Then
    Begin
      ParserAdvance;
      ParsePrintfStmt;
      Exit;
    End;
    If CurToken.Val = 'getline' Then
    Begin
      ParserAdvance;
      ParseGetline;
      Exit;
    End;
    If CurToken.Val = 'delete' Then
    Begin
      ParserAdvance;
      ParseDeleteStmt;
      Exit;
    End;
    If CurToken.Val = 'break' Then
    Begin
      ParserAdvance;
      If LoopDepth > 0 Then
        EmitInstr('JMP', LoopBreakLbl[LoopDepth - 1])
      Else
        CompileError('break en dehors d''une boucle');
      Exit;
    End;
    If CurToken.Val = 'continue' Then
    Begin
      ParserAdvance;
      If LoopDepth > 0 Then
        EmitInstr('JMP', LoopContLbl[LoopDepth - 1])
      Else
        CompileError('continue en dehors d''une boucle');
      Exit;
    End;
    If CurToken.Val = 'exit' Then
    Begin
      ParserAdvance;
      If Not ((CurToken.Kind = TK_NEWLINE) Or (CurToken.Kind = TK_EOF) Or
              ((CurToken.Kind = TK_PUNCT) And
               ((CurToken.Val = ';') Or (CurToken.Val = '}')))) Then
      Begin
        ParseExprPrec(1, Res);
        ExprLoadToAX(Res);
        EmitInstr('MOV', 'AH, 4Ch');
        EmitInstr('INT', '21h');
      End
      Else
      Begin
        EmitInstr('MOV', 'AX, 4C00h');
        EmitInstr('INT', '21h');
      End;
      Exit;
    End;
    If CurToken.Val = 'next' Then
    Begin
      ParserAdvance;
      EmitComment('next -> JMP to main loop');
      EmitInstr('JMP', AW_RULE_PFX + 'MAIN');
      Exit;
    End;
    If CurToken.Val = 'return' Then
    Begin
      ParserAdvance;
      If Not ((CurToken.Kind = TK_NEWLINE) Or (CurToken.Kind = TK_EOF) Or
              ((CurToken.Kind = TK_PUNCT) And
               ((CurToken.Val = ';') Or (CurToken.Val = '}')))) Then
      Begin
        ParseExprPrec(1, Res);
        ExprLoadToAX(Res);
      End
      Else
        EmitInstr('XOR', 'AX, AX');
      If CurFnRetLbl <> '' Then
        EmitInstr('JMP', CurFnRetLbl);
      Exit;
    End;
    If (CurToken.Val = 'BEGIN') Or (CurToken.Val = 'END') Then
    Begin
      ParserAdvance;
      Exit;
    End;
    If CurToken.Val = 'function' Then
    Begin
      ParserAdvance;
      ParseFuncDecl;
      Exit;
    End;
  End;
  (* Bloc accolades *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
  Begin
    ParseBlock;
    Exit;
  End;
  { Expression (affectation, appel de fonction, etc.) }
  ParseExprPrec(1, Res);
End;

{ ---- Run : boucle principale de compilation (TODO 19) -------- }
{ Compile un programme AWK avec structure:                       }
{   function declarations                                       }
{   BEGIN (* actions *)                                          }
{   pattern (* actions *)                                        }
{   END (* actions *)                                            }
Procedure Run;
Var
  PrevLine : Integer;
  PrevCol  : Integer;
  RuleLbl  : TString;
  SkipLbl  : TString;
  PatIdx   : Integer;
Begin
  TypeInit;
  SymInit;
  LoopDepth  := 0;
  RuleCount  := 0;
  RangeCount := 0;
  HasBegin   := False;
  HasEnd     := False;
  RuntimeEmitted := False;
  EmitOpen;
  EmitHeader;
  LexInit;
  ParserAdvance;
  SkipNewlines;
  { Point d entree du programme }
  EmitEntryPoint;
  { Parcourir le source : declarations et regles }
  While CurToken.Kind <> TK_EOF Do
  Begin
    PrevLine := CurToken.Line;
    PrevCol  := CurToken.Col;
    SkipNewlines;
    If CurToken.Kind = TK_EOF Then Break;
    { function declaration }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'function') Then
    Begin
      ParserAdvance;
      ParseFuncDecl;
      SkipNewlines;
      Continue;
    End;
    { BEGIN block }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
    Begin
      ParserAdvance;
      SkipNewlines;
      HasBegin := True;
      BeginLbl := AW_RULE_PFX + 'BEGIN';
      RuleLbl  := NewLabel('BSKIP');
      EmitInstr('JMP', RuleLbl);
      EmitLabel(BeginLbl);
      EmitInstr('PUSH', 'BP');
      EmitInstr('MOV', 'BP, SP');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock
      Else
        ParseStatement;
      EmitInstr('MOV', 'SP, BP');
      EmitInstr('POP', 'BP');
      EmitInstr('RET', '');
      EmitLabel(RuleLbl);
      SkipNewlines;
      Continue;
    End;
    { END block }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
    Begin
      ParserAdvance;
      SkipNewlines;
      HasEnd := True;
      EndLbl := AW_RULE_PFX + 'END';
      RuleLbl := NewLabel('ESKIP');
      EmitInstr('JMP', RuleLbl);
      EmitLabel(EndLbl);
      EmitInstr('PUSH', 'BP');
      EmitInstr('MOV', 'BP, SP');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        ParseBlock
      Else
        ParseStatement;
      EmitInstr('MOV', 'SP, BP');
      EmitInstr('POP', 'BP');
      EmitInstr('RET', '');
      EmitLabel(RuleLbl);
      SkipNewlines;
      Continue;
    End;
    { Pattern-action rule }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      { Pas de pattern -> action pour chaque enregistrement }
      If RuleCount < MAX_RULES Then
      Begin
        RuleLbl := NewLabel('RULE');
        RuleLabels[RuleCount]   := RuleLbl;
        RulePatterns[RuleCount] := '';
        Inc(RuleCount);
        SkipLbl := NewLabel('RSKP');
        EmitInstr('JMP', SkipLbl);
        EmitLabel(RuleLabels[RuleCount - 1]);
        EmitInstr('PUSH', 'BP');
        EmitInstr('MOV', 'BP, SP');
        ParseBlock;
        EmitInstr('MOV', 'SP, BP');
        EmitInstr('POP', 'BP');
        EmitInstr('RET', '');
        EmitLabel(SkipLbl);
      End
      Else
      Begin
        CompileError('trop de regles (max=' + IntToStr(MAX_RULES) + ')');
        ParseBlock;
      End;
      SkipNewlines;
      Continue;
    End;
    { /regexp/ (* action *) : pattern regexp }
    If CurToken.Kind = TK_REGEXP Then
    Begin
      PatIdx := DataAddStr(CurToken.Val);
      ParserAdvance;
      SkipNewlines;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
      Begin
        If RuleCount < MAX_RULES Then
        Begin
          RuleLbl := NewLabel('RULE');
          RuleLabels[RuleCount]   := RuleLbl;
          RulePatterns[RuleCount] := DataTab[PatIdx].LblName;
          Inc(RuleCount);
          SkipLbl := NewLabel('RSKP');
          EmitInstr('JMP', SkipLbl);
          EmitLabel(RuleLabels[RuleCount - 1]);
          EmitInstr('PUSH', 'BP');
          EmitInstr('MOV', 'BP, SP');
          ParseBlock;
          EmitInstr('MOV', 'SP, BP');
          EmitInstr('POP', 'BP');
          EmitInstr('RET', '');
          EmitLabel(SkipLbl);
        End
        Else
        Begin
          CompileError('trop de regles (max=' + IntToStr(MAX_RULES) + ')');
          ParseBlock;
        End;
      End;
      SkipNewlines;
      Continue;
    End;
    { Sinon : statement normal (expressions, etc.) }
    ParseStatement;
    SkipNewlines;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
    SkipNewlines;
    { Protection contre boucle infinie }
    If (CurToken.Kind <> TK_EOF) And
       (CurToken.Line = PrevLine) And (CurToken.Col = PrevCol) Then
      ParserAdvance;
  End;
  { Emettre la structure globale du programme }
  EmitBlankLine;
  EmitComment('=== Structure du programme AWK ===');
  { Appel BEGIN }
  EmitBeginCall;
  { Boucle principale si des regles existent }
  If RuleCount > 0 Then
    EmitMainLoop;
  { Appel END }
  EmitEndCall;
  { Sortie programme }
  EmitProgramExit;
  LexClose;
  EmitClose;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  ShowHelp;
  Halt(0);
 End;
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  InitOptions;
  ParseArgs;
  ShowBanner;
  Run;
  If Opts.Verbose Then ShowStats;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
END.
