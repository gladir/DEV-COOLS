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

  TODO 06 - SYSTEME DE TYPES
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

  TODO 07 - EMETTEUR DE CODE ASM
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
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

  TODO 09 - VARIABLES ET AFFECTATIONS
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

  TODO 10 - EXPRESSIONS PRIMAIRES
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

  TODO 11 - EXPRESSIONS BINAIRES
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

  TODO 12 - ENTREES/SORTIES (print / printf / getline)
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

  TODO 13 - IF / ELSE
            ParseIfStmt : if (cond) stmt [else stmt]
              Condition verite AWK : 0 et "" sont faux
              Emission TEST AX,AX / JZ pour valeur numerique fausse
              CALL _AWRT_TRUTHY pour chaines -> AX=0|1
            Labels : _AWL_ELSE_N, _AWL_ENDIF_N
            Blocs : if (cond) { stmts } else { stmts }
            If imbrique : if (c1) s1 else if (c2) s2 else s3
              Labels : _AWL_ELIF_N pour chaque branche

  TODO 14 - BOUCLES : while / for / for-in / do-while
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

  TODO 15 - TABLEAUX ASSOCIATIFS
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

  TODO 16 - CHAMPS ET ENREGISTREMENTS
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

  TODO 17 - FONCTIONS UTILISATEUR
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

  TODO 18 - EXPRESSIONS REGULIERES ET CORRESPONDANCE
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

  TODO 19 - REGLES PATTERN-ACTION (BEGIN / END / pattern { action })
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

  TODO 20 - FONCTIONS CHAINES INTEGREES
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

  TODO 21 - FONCTIONS MATHEMATIQUES INTEGREES
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

  TODO 22 - FICHIERS MULTIPLES ET ENTREES AVANCEES
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

  TODO 23 - CONVERSION DE TYPES ET COERCITION
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

  TODO 24 - RUNTIME MINIMAL
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

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
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

  { ---- Systeme de types (TODO 06 stub) --------------------- }
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

  { ---- Segment de donnees (TODO 08 stub) ------------------- }
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

  { Emetteur de code (stub pour TODOs futurs) }
  OutF      : Text;
  OutFOpen  : Boolean;

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
Begin
  { Passer espaces et commentaires, mais pas les fins de ligne }
  While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
    LexNextLine;
  If LexEOF Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  { Espaces et tabulations sur la ligne courante }
  While (LexColNo <= Length(LexLine)) And
        ((LexLine[LexColNo] = ' ') Or (LexLine[LexColNo] = #9)) Do
    Inc(LexColNo);
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

{ ---- Run : boucle principale de compilation ----------------- }
Procedure Run;
Begin
  TypeInit;
  SymInit;
  LexInit;
  ParserAdvance;
  While CurToken.Kind <> TK_EOF Do
    ParserAdvance;
  LexClose;
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
