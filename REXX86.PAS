{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur REXX vers assembleur 8086
}

(* ============================================================
  REXX86.PAS - Compilateur REXX vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.rex [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .rex, .rexx ou .cmd (OS/2 batch)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)
            Ignorer le commentaire en premiere ligne si /* ... */

  TODO 02 - LEXEUR (TOKENS REXX) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_NUMBER, TK_STRING, TK_IDENT,
              TK_KEYWORD, TK_OP, TK_PUNCT, TK_LABEL, TK_COMMA, TK_EOL
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre apostrophes 'abc' ou guillemets "abc"
              Doublement pour echapper : 'l''eau' -> l'eau
              Chaines hexadecimales : '41 42 43'x -> ABC
              Chaines binaires : '01000001'b -> A
            Commentaires : /* ... */ imbriques (nesting autorise en REXX)
            Continuation de ligne : virgule en fin de ligne
            Labels : identificateur suivi de deux-points (monLabel:)
            Mots-cles : ADDRESS ARG BY CALL DO DROP ELSE END EXIT
              EXPOSE FOR FOREVER FUNCTION IF INTERPRET ITERATE
              LEAVE LOOP NOP NUMERIC OTHERWISE PARSE PROCEDURE
              PULL PUSH QUEUE RETURN SAY SELECT SIGNAL THEN
              TO TRACE UNTIL UPPER VALUE WHEN WHILE WITH
            Sensibilite a la casse : mots-cles insensibles,
              variables converties en majuscules par defaut
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Nombres entiers : 0..65535 pour entiers 16 bits
              Pas de suffixe de type (REXX est non type)
            Nombres decimaux : reconnus par le lexeur, tronques en entier
              (pas de virgule flottante sur 8086 en mode simplifie)
            Chaines : 'texte' ou "texte" -> pointeur vers donnees DATA
              Chaine vide : '' -> pointeur vers octet nul
              Longueur stockee en prefixe (type counted string)
            Chaines hexadecimales : '48 65 6C 6C 6F'x -> Hello
              Espaces ignores entre paires de chiffres hex
            Chaines binaires : '01001000'b -> H
              Groupes de 8 bits, espaces ignores entre groupes
            Constantes symboliques predefinies :
              RC (code retour), RESULT (valeur de retour),
              SIGL (numero de ligne du dernier SIGNAL ou CALL)

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / % (division entiere) // (reste)
                             ** (puissance, limitee a des petits exposants)
            Concatenation  : || (explicite), espace (implicite), abuttal
              Abuttal : 'abc'variable -> concatenation sans separateur
            Comparaison    : = \= > < >= <= (normales, espaces ignores)
                             == \== >> << >>= <<= (strictes, espaces significatifs)
            Logiques       : & (AND) | (OR) && (XOR) \ (NOT, prefixe)
            Affectation    : = (assignation par instruction, pas par operateur)
            Unaire         : + - (signe) \ (negation logique)
            Precedence (du plus fort au plus faible) :
              1. \ (NOT), unaire +/-, prefixe
              2. ** (puissance)
              3. * / % //
              4. + - (binaire)
              5. || (concatenation explicite), espace, abuttal
              6. = \= > < >= <= == \== >> << >>= <<=
              7. & (AND)
              8. | (OR) && (XOR)

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_LABEL, SK_PROC, SK_STEM,
              SK_EXPOSED, SK_BUILTIN
            TSymRec : Name, MangledName, Kind, Offset,
              Scope, IsExposed, IsStem, DefaultVal
            SymNameClean, SymMangle, SymAdd, SymFind, SymFindInScope
            CurScope : compteur de portee (0 = global, >0 = PROCEDURE)
            SymEnterScope / SymLeaveScope : gestion des portees
            PROCEDURE EXPOSE : marquer les variables exposees
              depuis la portee englobante
            Variables non initialisees : valeur = nom en majuscules
              (convention REXX : variable non affectee = son propre nom)
            DROP var : retablir la variable a sa valeur par defaut (son nom)
            Conversion automatique nom -> majuscules dans la table
            SymInit : enregistrement des 71 builtins REXX (ABBREV..XRANGE)

  TODO 06 - SYSTEME DE TYPES INTERNE [IMPLEMENTE]
            TTypeKind : TYK_STRING (chaine, type principal),
              TYK_INTEGER (entier 16 bits, optimisation interne),
              TYK_STEM (variable composee / tableau associatif),
              TYK_BOOLEAN (resultat logique 0/1)
            En REXX tout est chaine de caracteres :
              Les nombres sont des chaines avec representation numerique
              La conversion chaine <-> nombre est implicite et automatique
            TypeKindOf, TypeSizeof, TypeMangle, TypeIsNumeric, TypeIsPtr,
              TypeCanCoerce, TypeCoerceResult, TypeInfer, TypeLookupName
            TypeTab, TypeInit : types internes pour optimisation
            TypeInfer : determiner si une valeur est utilisable comme nombre
              -> si oui, operations arithmetiques directes sur registres
              -> sinon, operations via routines chaines du runtime
            Taille interne : STRING=ptr(2) + len(2), INTEGER=2 octets

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _RXL_NNNNN)
            Prefixes : _RXV_ (variable), _RXP_ (procedure), _RXK_ (chaine const),
              _RXRT_ (runtime), _RXL_ (label), _RXS_ (stem),
              _RXD_ (donnees data), _RXB_ (builtin)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_BUFFER),
              IntVal, StrVal, BufSize
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddBuffer : variantes d ajout
            Variables globales : chaines dans DATA avec label _RXV_nom
              Format : DB longueur, 'contenu', 0
            Chaines litterales : DB 'texte',0 dans DATA avec label _RXK_N
            Tampons de travail pour concatenation et conversion :
              _RX_TMPBUF DB 256 DUP(0) (tampon temporaire)
              _RX_NUMBUF DB 12 DUP(0) (tampon conversion numerique)
            Pile de donnees (data stack) : zone reservee dans DATA

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
            Variables simples : chaines allouees dans DATA ou sur le heap
              Acces par label _RXV_NOM (majuscules)
            Variables locales (dans PROCEDURE) : pile BP, acces [BP-offset]
            Variable non initialisee : valeur = nom en majuscules
              ex: X non affecte -> X contient la chaine "X"
            Affectation : var = expr
              Evaluer expr -> AX=ptr chaine resultat
              Copier chaine vers emplacement de var
            DROP var : reinitialiser a la valeur par defaut (le nom)
            UPPER var : convertir le contenu en majuscules
            Affectation multiple via PARSE : voir TODO 16
            VarAlloc : alloue variable globale (DB dans DATA) ou locale (pile)
            VarAddrOf : retourne chaine d adressage ASM ([_RXV_X] ou [BP-n])
            VarLoad : emet MOV AX / LEA AX pour charger ptr vers contenu
            VarStore : emet CALL _RXRT_STRCPY pour copier chaine dans var
            ParseAssign : parse var = expr, evalue et stocke
            ParseDrop : parse DROP var1 var2 ... reinitialise au nom
            ParseUpper : parse UPPER var1 var2 ... convertit en majuscules

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
            ParsePrimary : literal nombre, literal chaine, ident, appel fonction
            Nombre : convertir en chaine (ou garder en registre si optimise)
            Chaine : charger adresse du literal dans SI
            Variable : charger adresse de la valeur dans SI
            Appel de fonction : nom(args) -> CALL + resultat dans AX
            Parentheses : (expr) -> evaluation recursive
            Prefixe unaire : + (NOP), - (NEG si numerique), \ (NOT logique)
            Fonctions integrees : SUBSTR, LENGTH, etc. -> CALL _RXB_nom
            Variable composee (stem) : nom.queue -> calcul dynamique de cle

  TODO 11 - EXPRESSIONS BINAIRES ET CONCATENATION [IMPLEMENTE]
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            Division entiere % : IDIV -> quotient dans AX
            Reste // : IDIV -> reste dans DX
            Puissance ** : boucle de multiplication (exposants petits)
            Concatenation explicite || : CALL _RXRT_CONCAT(SI=g, DI=d) -> AX
            Concatenation implicite (espace) : meme traitement que ||
            Abuttal (juxtaposition) : detecter au lexeur, traiter comme ||
            Comparaison normale : CALL _RXRT_STRCMP -> drapeaux (espaces normalises)
            Comparaison stricte : CALL _RXRT_STRCMPS -> drapeaux (espaces preserves)
            Logique AND & : court-circuit JZ vers false-branch
            Logique OR | : court-circuit JNZ vers true-branch
            Logique XOR && : XOR AX, BX apres evaluation des deux cotes
            Logique NOT \ : XOR AX,1

  TODO 12 - ENTREES/SORTIES (SAY / PULL / LINEIN / LINEOUT / CHAROUT) [IMPLEMENTE]
            SAY expr : evaluer expr -> afficher sur STDOUT + CR+LF
              SAY sans argument : afficher une ligne vide
              -> CALL _RXRT_PRINT(SI=msg) + CALL _RXRT_PRINTLN
            PULL var [var2 ...] : lire une ligne depuis STDIN
              -> INT 21h AH=0Ah (lecture ligne) + UPPER + PARSE
              PULL est equivalent a PARSE UPPER PULL
            PARSE PULL var : comme PULL mais sans conversion majuscules
            ARG : equivalent a PARSE UPPER ARG (arguments du programme)
            LINEIN([nom]) : lire une ligne depuis un fichier ou STDIN
              -> INT 21h AH=3Fh (fichier) ou AH=0Ah (STDIN)
            LINEOUT([nom], texte) : ecrire une ligne vers fichier ou STDOUT
              -> INT 21h AH=40h (fichier) ou BX=1 (STDOUT)
            CHAROUT([nom], texte) : ecrire sans retour de ligne
            CHARIN([nom]) : lire un seul caractere -> AL
            CHARS([nom]) : nombre de caracteres disponibles -> AX
            LINES([nom]) : nombre de lignes restantes -> AX (0 ou 1)
            STREAM(nom, option) : gestion de flux (open/close/status)

  TODO 13 - IF / THEN / ELSE / SELECT / WHEN / OTHERWISE [IMPLEMENTE]
            ParseIfStmt : IF cond THEN instr [; ELSE instr]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _RXL_ELSE_N, _RXL_ENDIF_N
            IF avec bloc : IF cond THEN DO; stmts; END [; ELSE DO; stmts; END]
              Le bloc DO/END remplace les accolades
            NOP : instruction vide (utilise dans THEN NOP ou OTHERWISE NOP)
            ParseSelectStmt : SELECT [; WHEN cond THEN instr]+ [; OTHERWISE instr] END
              Evaluation sequentielle des WHEN
              Premier WHEN vrai -> executer son bloc, sauter au END
              OTHERWISE : bloc par defaut (optionnel)
              Erreur si aucun WHEN vrai et pas de OTHERWISE
              Labels : _RXL_WHEN_N, _RXL_SNEXT_N, _RXL_SEND_N
              Emission : pour chaque WHEN -> eval cond + JZ vers suivant

  TODO 14 - BOUCLES DO / END [IMPLEMENTE]
            ParseDoBlock : DO [; stmts ;] END (bloc simple)
            ParseDoWhile : DO WHILE cond [; stmts ;] END
              Labels : _RXL_DTEST_N, _RXL_DEND_N
            ParseDoUntil : DO UNTIL cond [; stmts ;] END
              Condition testee apres le corps (au moins une execution)
              Labels : _RXL_DBEG_N, _RXL_DTEST_N
            ParseDoCount : DO var = debut TO fin [BY pas] [; stmts ;] END
              Variable de boucle (compteur), pas = 1 par defaut
              BY pas : increment positif ou negatif
              Labels : _RXL_DINIT_N, _RXL_DTEST_N, _RXL_DINCR_N, _RXL_DEND_N
            ParseDoForever : DO FOREVER [; stmts ;] END
              Boucle infinie, sortie par LEAVE
              Labels : _RXL_DBEG_N, _RXL_DEND_N
            DO expr : repeter le bloc expr fois (DO 5; ...; END)
            LEAVE [nom] : sortir de la boucle courante ou nommee
              -> JMP _RXL_DEND_N
            ITERATE [nom] : passer a l iteration suivante
              -> JMP _RXL_DTEST_N (ou _RXL_DINCR_N pour boucle compteur)
            LoopPush / LoopPop : pile de labels pour LEAVE et ITERATE

  TODO 15 - CHAINES DE CARACTERES ET FONCTIONS INTEGREES (partie 1) [IMPLEMENTE]
            LENGTH(str) : longueur de la chaine -> AX
              -> CALL _RXB_LENGTH
            SUBSTR(str, pos [,len [,pad]]) : sous-chaine
              -> CALL _RXB_SUBSTR -> AX=ptr resultat
            LEFT(str, len [,pad]) : len caracteres a gauche
            RIGHT(str, len [,pad]) : len caracteres a droite
            CENTER(str, len [,pad]) / CENTRE : centrer dans largeur len
            COPIES(str, n) : repeter str n fois -> AX=ptr
            REVERSE(str) : inverser la chaine -> AX=ptr
            STRIP(str [,option [,char]]) : supprimer espaces
              option = L (gauche), T (droite), B (les deux, defaut)
            SPACE(str [,n [,pad]]) : normaliser espaces entre mots
            OVERLAY(new, target, pos [,len [,pad]]) : superposer
            INSERT(new, target [,pos [,len [,pad]]]) : inserer
            DELSTR(str, pos [,len]) : supprimer une portion
            POS(needle, haystack [,start]) : position de sous-chaine -> AX
            LASTPOS(needle, haystack [,start]) : derniere position -> AX

  TODO 16 - INSTRUCTION PARSE [IMPLEMENTE]
            PARSE [UPPER] source template
            Sources :
              PARSE ARG : arguments de la procedure ou du programme
              PARSE PULL : ligne lue depuis la pile de donnees ou STDIN
              PARSE VAR nom : contenu d une variable
              PARSE VALUE expr WITH : resultat d une expression
              PARSE SOURCE : informations sur le programme en cours
              PARSE VERSION : version de l interpreteur/compilateur
              PARSE LINEIN : ligne lue depuis STDIN
            Templates (modeles de decoupage) :
              Mots : var1 var2 var3 -> decouper par espaces
              Litteral : var1 'delim' var2 -> decouper au delimiteur
              Position absolue : var1 5 var2 -> colonne 5
              Position relative : var1 +3 var2 -> avancer de 3 positions
              Point : . pour ignorer un segment (variable jetable)
            UPPER : convertir en majuscules avant decoupage
            Emission ASM : appels successifs a _RXRT_PARSEWORD,
              _RXRT_PARSEDELIM, _RXRT_PARSEPOS selon le template
            Affectation des resultats dans les variables cibles

  TODO 17 - PROCEDURES ET FONCTIONS INTERNES [IMPLEMENTE]
            ParseCallStmt : CALL nom [arg1, arg2, ...]
              Arguments passes par valeur (chaines)
              Convention d appel : empiler args droite a gauche + CALL
            Labels internes : nom: (deux-points apres identificateur)
              CALL nom -> saut vers le label, retour par RETURN
              SIGNAL nom -> saut sans retour (goto)
            PROCEDURE : mot-cle apres un label pour definir une portee locale
              Toutes les variables sont locales sauf celles exposees
            PROCEDURE EXPOSE var1 var2 ... : exposer des variables
              de la portee appelante (acces direct au cadre parent)
            RETURN [expr] : retourner une valeur au CALL appelant
              MOV AX, ptr_resultat + JMP vers epilogue
            RESULT : variable speciale contenant la valeur de RETURN
            Fonctions : nom(arg1, arg2) dans une expression
              -> CALL + resultat dans AX (pointeur chaine)
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            Recursion : supportee (chaque appel a son propre cadre)

  TODO 18 - FONCTIONS INTEGREES (partie 2 : mots, conversion, divers) [IMPLEMENTE]
            Fonctions sur les mots :
              WORD(str, n) : n-ieme mot de la chaine
              WORDS(str) : nombre de mots -> AX
              SUBWORD(str, n [,len]) : sous-ensemble de mots
              WORDINDEX(str, n) : position du n-ieme mot -> AX
              WORDLENGTH(str, n) : longueur du n-ieme mot -> AX
              WORDPOS(phrase, str [,start]) : position d une phrase -> AX
              DELWORD(str, n [,len]) : supprimer des mots
            Fonctions de conversion :
              C2D(str) : caractere vers decimal -> AX
              C2X(str) : caractere vers hexadecimal -> ptr chaine
              D2C(n) : decimal vers caractere -> ptr chaine
              D2X(n) : decimal vers hexadecimal -> ptr chaine
              X2C(hex) : hexadecimal vers caractere -> ptr chaine
              X2D(hex) : hexadecimal vers decimal -> AX
              B2X(bin) : binaire vers hexadecimal -> ptr chaine
              X2B(hex) : hexadecimal vers binaire -> ptr chaine
            Fonctions diverses :
              ABS(n) : valeur absolue -> AX
              MAX(n1, n2, ...) : maximum -> AX
              MIN(n1, n2, ...) : minimum -> AX
              SIGN(n) : signe (-1, 0, 1) -> AX
              TRUNC(n [,d]) : tronquer a d decimales -> AX (entier)
              RANDOM([min] [,max] [,seed]) : nombre aleatoire -> AX
              TIME([option]) : heure courante -> ptr chaine
              DATE([option]) : date courante -> ptr chaine
              DATATYPE(str [,type]) : verifier le type de donnees -> 0|1
              SYMBOL(nom) : etat du symbole (VAR, LIT, BAD) -> ptr chaine
              VALUE(nom) : valeur d une variable par nom -> ptr chaine
              ERRORTEXT(n) : message d erreur REXX -> ptr chaine

  TODO 19 - VARIABLES COMPOSEES (TIGES / STEMS)
            Variable composee : nom.queue (stem.tail)
              Exemple : tab.1 tab.2 tab.compteur
              La queue est evaluee dynamiquement (concatenation des parties)
            Stem seul : tab. -> valeur par defaut pour tous les elements
              tab. = 0 -> tous les elements non affectes valent "0"
            Resolution dynamique de la cle :
              i = 3 ; SAY tab.i -> chercher tab.3
              Emission : evaluer chaque partie de la queue,
              concatener avec des points, chercher dans la table
            Table des stems : TSymStem[0..MAX_STEM-1]
              Chaque entree : StemName, Key (chaine), Value (chaine)
              Recherche : _RXRT_STEMGET(SI=stem, DI=key) -> AX=ptr valeur
              Ecriture : _RXRT_STEMSET(SI=stem, DI=key, BX=value)
            DROP nom. : reinitialiser toute la tige
            Queues multiples : tab.i.j -> cle = valeur(i).valeur(j)
            Limitation memoire : table de hachage simple dans le heap

  TODO 20 - ARITHMETIQUE ET NUMERIC DIGITS
            NUMERIC DIGITS [n] : nombre de chiffres significatifs
              Defaut = 9, sur 8086 limite a la precision entiere 16 bits
              Si DIGITS <= 4 : operations directes sur registres 16 bits
              Si DIGITS > 4 : avertissement, troncature a 16 bits
            NUMERIC FORM SCIENTIFIC | ENGINEERING :
              Controle de la notation (stub : toujours notation simple)
            NUMERIC FUZZ [n] : chiffres ignores dans les comparaisons
              Defaut = 0 (comparaison exacte)
            Operations arithmetiques optimisees (entier 16 bits) :
              Addition : ADD AX, BX
              Soustraction : SUB AX, BX
              Multiplication : IMUL BX (resultat dans DX:AX, tronque a AX)
              Division : CWD + IDIV BX -> quotient AX, reste DX
              Puissance : boucle de multiplication
            Conversion chaine -> nombre : CALL _RXRT_STRTONUM
            Conversion nombre -> chaine : CALL _RXRT_NUMTOSTR
            Verification DATATYPE('num', 'N') avant operation arithmetique

  TODO 21 - SIGNAL ET TRAITEMENT DE CONDITIONS
            SIGNAL [VALUE] label : saut inconditionnel (goto)
              Termine toutes les boucles et blocs en cours
              -> JMP _RXP_label
            SIGNAL ON condition [NAME handler] : activer un piege
              Conditions : ERROR, FAILURE, HALT, NOVALUE,
                NOTREADY, SYNTAX, LOSTDIGITS
              Quand la condition survient -> saut vers handler
            SIGNAL OFF condition : desactiver un piege
            Mecanisme d implementation :
              Table de handlers : _RX_TRAPS DW 7 DUP(0) dans DATA
                (une entree par type de condition)
              Activation : MOV [_RX_TRAPS+offset], OFFSET _RXP_handler
              Desactivation : MOV [_RX_TRAPS+offset], 0
              Declenchement : CMP [_RX_TRAPS+offset],0 / JZ _RXL_DEFAULT_N
                JMP [_RX_TRAPS+offset]
            NOVALUE : declenche si variable non initialisee est lue
              (necessite verification a chaque lecture de variable)
            SIGL : variable speciale = numero de ligne du SIGNAL/CALL
            RC : variable speciale = code retour de la derniere commande
            Condition par defaut (pas de handler) : afficher erreur + EXIT

  TODO 22 - PILE DE DONNEES (QUEUE / PUSH / PULL)
            Pile de donnees REXX (data stack / external queue) :
              Structure FIFO (QUEUE) et LIFO (PUSH) combinee
            QUEUE expr : ajouter en fin de pile (FIFO)
              -> CALL _RXRT_QUEUE(SI=chaine)
            PUSH expr : ajouter en debut de pile (LIFO)
              -> CALL _RXRT_PUSH(SI=chaine)
            PULL var : retirer du debut de la pile
              Si pile vide : lire depuis STDIN a la place
              -> CALL _RXRT_PULL -> AX=ptr chaine (ou lecture clavier)
            QUEUED() : nombre d elements dans la pile -> AX
              -> CALL _RXRT_QUEUED -> AX
            Implementation :
              _RX_STACK DB 2048 DUP(0) : zone memoire de la pile
              _RX_STKTOP DW 0 : pointeur sommet
              _RX_STKBOT DW 0 : pointeur base
              _RX_STKCOUNT DW 0 : nombre d elements
              Chaque element : 2 octets longueur + contenu chaine
            Pile circulaire pour optimiser l espace memoire

  TODO 23 - INSTRUCTION INTERPRET ET ADDRESS
            INTERPRET expr : evaluer dynamiquement du code REXX
              Limitation sur 8086 : non supporte en compilation native
              -> Emettre un avertissement a la compilation
              -> Alternative : ignorer ou generer une erreur a l execution
                 CALL _RXRT_PANIC('INTERPRET non supporte')
            ADDRESS [environnement] [commande] :
              Envoyer une commande a l environnement hote
              ADDRESS CMD commande -> INT 21h AH=4Bh (EXEC) ou
                equivalence via ecriture dans un fichier .BAT
              ADDRESS SYSTEM commande -> meme traitement
              Sans argument : afficher l environnement courant
            Commandes hotes (instruction sans mot-cle) :
              En REXX, une chaine seule est envoyee a l environnement
              ex: 'DIR' -> execute DIR dans le shell DOS
              -> CALL _RXRT_HOSTCMD(SI=commande) -> RC
            TRACE [option] : controle du tracage (debug)
              TRACE A (all), TRACE R (results), TRACE I (intermediates)
              TRACE O (off), TRACE N (normal)
              Implementation : variable globale _RX_TRACE DB 0
              Si trace active : afficher chaque instruction avant execution
            EXIT [expr] : terminer le programme avec code retour
              -> MOV AL, code / MOV AH,4Ch / INT 21h

  TODO 24 - RUNTIME MINIMAL
            _RXRT_PRINT(SI=msg, CX=len) : INT 21h AH=40h BX=1 (STDOUT)
            _RXRT_PRINTLN : _RXRT_PRINT + CR+LF via _RX_CRLF DB 13,10,0
            _RXRT_READLN(DI=buf, CX=maxlen) : INT 21h AH=0Ah -> chaine
            _RXRT_STRLEN(SI=str) : compter octets jusqu a 0 -> AX
            _RXRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _RXRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _RXRT_CONCAT(SI=src1, DI=src2) : concatenation -> AX=ptr buf
            _RXRT_STRCMP(SI=str1, DI=str2) : comparaison normale -> drapeaux
              (espaces de debut/fin normalises avant comparaison)
            _RXRT_STRCMPS(SI=str1, DI=str2) : comparaison stricte -> drapeaux
              (espaces significatifs, comparaison exacte)
            _RXRT_UPPER(SI=str) : convertir en majuscules sur place
            _RXRT_COPY(SI=src, DI=dst, CX=len) : copie memoire
            _RXRT_PARSEWORD(SI=str, BX=index) : extraire mot N -> AX=ptr
            _RXRT_PARSEDELIM(SI=str, DI=delim) : decouper au delimiteur
            _RXRT_PARSEPOS(SI=str, BX=pos) : decouper a la position
            _RXRT_STEMGET(SI=stem, DI=key) : lire variable composee -> AX
            _RXRT_STEMSET(SI=stem, DI=key, BX=val) : ecrire variable composee
            _RXRT_QUEUE(SI=str) : empiler en fin (FIFO)
            _RXRT_PUSH(SI=str) : empiler en debut (LIFO)
            _RXRT_PULL : depiler -> AX=ptr (ou lire STDIN si pile vide)
            _RXRT_QUEUED : nombre d elements dans la pile -> AX
            _RXRT_HOSTCMD(SI=cmd) : executer commande hote -> RC
            _RXRT_ABS(AX=n) : valeur absolue -> AX
            _RXRT_MAX(AX=a, BX=b) : maximum -> AX
            _RXRT_MIN(AX=a, BX=b) : minimum -> AX
            _RXRT_RANDOM(AX=min, BX=max) : nombre aleatoire -> AX
            _RXRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _RX_HEAP DB 4096 DUP(0) + _RX_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _RXP_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _RXP_Main
            Fichiers SAMPLES\REXX\ a creer :
              hello.rex    (SAY, variables, concatenation, chaines)
              math.rex     (operations arithmetiques, NUMERIC DIGITS)
              control.rex  (IF/THEN/ELSE, SELECT/WHEN, DO WHILE/UNTIL)
              loops.rex    (DO compteur, DO FOREVER, LEAVE, ITERATE)
              strings.rex  (SUBSTR, LENGTH, POS, COPIES, REVERSE, etc.)
              parse.rex    (PARSE VAR, PARSE ARG, templates, delimiteurs)
              funcs.rex    (CALL, RETURN, PROCEDURE EXPOSE, recursion)
              stems.rex    (variables composees tab.i, DROP, valeur defaut)
              stack.rex    (PUSH, QUEUE, PULL, QUEUED)
              signal.rex   (SIGNAL ON NOVALUE, SIGNAL label, conditions)
            Smoke tests : REXX86.EXE -v SAMPLES\REXX\*.rex

  ============================================================ *)

Program REXX86;

{ ============================================================================
  TYPES DE BASE, CONSTANTES ET VARIABLES GLOBALES DU COMPILATEUR
  ============================================================================ }

{ --------------------------------------------------------------------------
  Directives compilateur (Turbo Pascal / Free Pascal)
  -------------------------------------------------------------------------- }
{$A-}   (* Pas d alignement memoire                                         *)
{$I-}   (* Pas de verification I/O automatique (gestion manuelle)           *)
{$B-}   (* Evaluation booleenne court-circuit                               *)
{$Q-}   (* Pas de verification overflow                                     *)
{$R-}   (* Pas de verification de range                                     *)

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

{ --------------------------------------------------------------------------
  Constantes dimensionnant les tables et buffers internes
  -------------------------------------------------------------------------- }
Const
  (* --- Version --- *)
  REXX86_VERSION = '1.0';
  REXX86_DATE    = '2026-03-07';

  (* --- Limites des tables principales --- *)
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_STEM      = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_PARSE_VARS = 16;
  STACK_SIZE    = 1024;

  (* --- Prefixes de nommage ASM --- *)
  RX_VAR_PFX  = '_RXV_';    (* variable simple                      *)
  RX_PROC_PFX = '_RXP_';    (* procedure / label interne            *)
  RX_STR_PFX  = '_RXK_';    (* constante chaine litterale           *)
  RX_RT_PFX   = '_RXRT_';   (* routine runtime                      *)
  RX_LBL_PFX  = '_RXL_';    (* label de saut interne                *)
  RX_STEM_PFX = '_RXS_';    (* variable composee (stem)             *)
  RX_DATA_PFX = '_RXD_';    (* donnees data                         *)
  RX_BLT_PFX  = '_RXB_';    (* fonction integree (builtin)          *)

  (* --- Codes de sortie --- *)
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  (* --- Indices de types internes REXX --- *)
  TY_IDX_STRING  = 0;   (* chaine (type principal REXX)  *)
  TY_IDX_INTEGER = 1;   (* entier 16 bits (optimisation) *)
  TY_IDX_BOOLEAN = 2;   (* resultat logique 0/1          *)
  TY_IDX_STEM    = 3;   (* variable composee (tableau)   *)
  TY_PRIM_COUNT  = 4;
  TY_UNKNOWN     = -1;

{ --------------------------------------------------------------------------
  Types
  -------------------------------------------------------------------------- }
Type
  TString = String[MAX_STR];

  (* ---- Options de compilation ----------------------------- *)
  TOptions = Record
    SrcFile   : TString;   (* fichier source (.rex / .rexx / .cmd) *)
    OutFile   : TString;   (* fichier assembleur de sortie (.asm)  *)
    Verbose   : Boolean;   (* -v : banniere et statistiques        *)
    DebugMode : Boolean;   (* -d : affichage de chaque token       *)
    Warnings  : Boolean;   (* -w : activer les avertissements      *)
  End;

  (* ---- Tokens REXX (TODO 02) ----------------------------- *)
  TTokenKind = (
    TK_EOF,       (* fin de fichier                          *)
    TK_NUMBER,    (* literal numerique 42  3.14              *)
    TK_STRING,    (* literal chaine 'abc' ou "abc"           *)
    TK_IDENT,     (* identificateur (non mot-cle)            *)
    TK_KEYWORD,   (* mot-cle REXX reconnu                    *)
    TK_OP,        (* operateur + - * / = || etc.             *)
    TK_PUNCT,     (* ponctuation ; , ( ) :                   *)
    TK_LABEL,     (* label : identificateur suivi de :       *)
    TK_COMMA,     (* virgule (aussi continuation de ligne)   *)
    TK_EOL        (* fin de ligne logique                    *)
  );

  TToken = Record
    Kind   : TTokenKind;
    Val    : TString;     (* valeur textuelle brute               *)
    IntVal : LongInt;     (* valeur entiere (TK_NUMBER)           *)
    Line   : Integer;     (* ligne source (1-base)                *)
    Col    : Integer;     (* colonne source (1-base)              *)
  End;

  (* ---- Categories de symboles (TODO 05) ------------------- *)
  TSymKind = (
    SK_VAR,        (* variable simple                    *)
    SK_LABEL,      (* label (cible CALL / SIGNAL)        *)
    SK_PROC,       (* procedure interne (label+PROCEDURE)*)
    SK_STEM,       (* variable composee (tige)           *)
    SK_EXPOSED,    (* variable exposee (PROCEDURE EXPOSE)*)
    SK_BUILTIN     (* fonction integree                  *)
  );

  TSymRec = Record
    Name        : TString;   (* identifiant (majuscules)           *)
    MangledName : TString;   (* _RXV_NOM / _RXP_NOM               *)
    Kind        : TSymKind;
    TypeIdx     : Integer;   (* indice dans TypeTab                *)
    ScopeLevel  : Integer;
    Offset      : Integer;   (* [BP-n] pour locaux                 *)
    IsExposed   : Boolean;   (* variable exposee par PROCEDURE     *)
    IsStem      : Boolean;   (* variable composee                  *)
    DeclLine    : Integer;
  End;

  (* ---- Types internes (TODO 06) --------------------------- *)
  TTypeKind = (
    TYK_STRING,    (* chaine de caracteres (type principal)  *)
    TYK_INTEGER,   (* entier 16 bits (optimisation interne)  *)
    TYK_BOOLEAN,   (* resultat logique 0 ou 1                *)
    TYK_STEM       (* variable composee / tableau associatif *)
  );

  TTypeRec = Record
    Name : TString;
    Kind : TTypeKind;
    Size : Integer;   (* octets : STRING=2(ptr), INTEGER=2 *)
  End;

  (* ---- Valeurs d expression (TODO 11) --------------------- *)
  TExprKind = (
    EK_NONE,   (* void / pas de valeur            *)
    EK_IMM,    (* immediate dans ImmVal            *)
    EK_AX,     (* valeur dans AX                   *)
    EK_MEM     (* adresse [BP+Offset] ou [_RXV_x]  *)
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   (* indice dans SymTab (-1 = pas de lvalue) *)
  End;

  (* ---- Segment de donnees (TODO 08) ----------------------- *)
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_BUFFER);

  TDataRec = Record
    LblName : TString;
    Kind    : TDataKind;
    IntVal  : LongInt;
    StrVal  : TString;
    BufSize : Integer;  (* DK_BUFFER : taille en octets *)
  End;

{ --------------------------------------------------------------------------
  Variables globales
  -------------------------------------------------------------------------- }
Var
  (* Options *)
  Opts : TOptions;

  (* Compteurs generaux *)
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  (* Valeur fictive pour ignorer un retour TExprVal *)
  GExprDummy : TExprVal;

  (* Lexeur (TODO 02) *)
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  LexNeedEOL : Boolean;
  CurToken  : TToken;

  (* Table des symboles (TODO 05) *)
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;
  CurScope   : Integer;
  LabelSeq   : Integer;

  (* Table des types (TODO 06) *)
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  (* Emetteur ASM (TODO 07) *)
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    (* taille cadre local courant (words)   *)
  CurFnDepth   : Integer;    (* 0 = global, >0 = dans une procedure  *)
  CurFnRetLbl  : TString;    (* label epilogue de la procedure       *)
  CurFnName    : TString;    (* nom de la procedure courante         *)
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LabelGenSeq  : Integer;    (* compteur unique pour LabelGen        *)

  (* Segment de donnees (TODO 08) *)
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  (* Etat general *)
  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }

(* TODO 02 - Lexeur *)
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextToken;        Forward;
Procedure LexNextLine;         Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString(Quote : Char); Forward;

(* TODO 05 - Table des symboles *)
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Procedure SymInit;             Forward;
Procedure SymEnterScope;       Forward;
Procedure SymLeaveScope;       Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;

(* TODO 06 - Systeme de types *)
Procedure TypeInit;            Forward;
Function  TypeKindOf(TypeIdx : Integer) : TTypeKind; Forward;
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeIsNumeric(TypeIdx : Integer) : Boolean; Forward;
Function  TypeIsPtr(TypeIdx : Integer) : Boolean; Forward;
Function  TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  TypeCoerceResult(LeftIdx, RightIdx : Integer;
                           Const Op : TString) : Integer; Forward;
Function  TypeInfer(Const E : TExprVal) : Integer; Forward;
Function  TypeLookupName(Const Name : TString) : Integer; Forward;

(* TODO 07 - Emetteur ASM *)
Function  LabelGen : TString;   Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine;       Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure EmitOpen;            Forward;
Procedure EmitClose;           Forward;
Procedure EmitHeader;          Forward;
Procedure EmitProlog;          Forward;
Procedure EmitEpilog;          Forward;
Procedure EmitDataSeg;         Forward;
Procedure EmitRuntime;         Forward;

(* TODO 08 - Segment de donnees *)
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : TString; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Function  DataAddBuffer(Const Lbl : TString; ASize : Integer) : Integer; Forward;
Procedure DataInit; Forward;

(* TODO 03 - Litteraux et constantes *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;

(* TODO 04 - Operateurs et precedence *)
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure EmitBinOp(Const Op : TString;
                    Var Res : TExprVal; Const Rhs : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;

(* TODO 10 - Expressions primaires *)
Function  IsBuiltinFunc(Const Name : TString) : Boolean; Forward;
Function  ParseCallArgs : Integer; Forward;
Procedure ParseFuncCall(Const FuncName : TString; Var Res : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal);    Forward;

(* TODO 09 - Variables *)
Procedure ExprFlushToAX(Const E : TExprVal); Forward;
Function  VarAlloc(Const Name : TString) : Integer; Forward;
Function  VarAddrOf(Idx : Integer) : TString; Forward;
Procedure VarLoad(Idx : Integer); Forward;
Procedure VarStore(Idx : Integer); Forward;
Procedure ParseAssign(Const VarName : TString); Forward;
Procedure ParseDrop; Forward;
Procedure ParseUpper; Forward;

(* Autres stubs *)
Procedure ParseStmt;           Forward;
Procedure ParserAdvance;       Forward;

(* TODO 12 - Entrees/Sorties *)
Procedure ParseSayStmt;        Forward;
Procedure ParsePullStmt;       Forward;
Procedure EmitIORuntime;       Forward;

(* TODO 13 - IF/THEN/ELSE/SELECT *)
Procedure ParseIfStmt;         Forward;
Procedure ParseSelectStmt;     Forward;
Procedure ParseDoBlock;        Forward;

(* TODO 14 - BOUCLES DO/END *)
Procedure LoopPush(Const BreakLbl, ContLbl : TString); Forward;
Procedure LoopPop;             Forward;
Procedure ParseDoBodyUntilEnd; Forward;
Procedure ParseDoWhile;        Forward;
Procedure ParseDoUntil;        Forward;
Procedure ParseDoForever;      Forward;
Procedure ParseDoCount(Const VarName : TString); Forward;
Procedure ParseDoExpr;         Forward;

(* TODO 15 - CHAINES ET FONCTIONS INTEGREES partie 1 *)
Procedure EmitBifRuntime;      Forward;

(* TODO 16 - INSTRUCTION PARSE *)
Procedure EmitParseRuntime;    Forward;
Procedure ParseParseStmt;      Forward;

(* TODO 17 - PROCEDURES ET FONCTIONS INTERNES *)
Procedure ParseCallStmt;       Forward;
Procedure ParseSignalStmt;     Forward;
Procedure ParseProcKeyword;    Forward;

(* TODO 18 - FONCTIONS INTEGREES partie 2 *)
Procedure EmitBif2Runtime;     Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

(* ---- Erreur fatale --------------------------------------- *)
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('REXX86: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
    Assign(OutF, Opts.OutFile);
    Erase(OutF);
  End;
  Halt(EXIT_ERROR);
End;

(* ---- Erreur de compilation ------------------------------- *)
Procedure CompileError(Const Msg : TString);
Begin
  Write('REXX86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

(* ---- Avertissement --------------------------------------- *)
Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  Write('REXX86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

(* ---- Banniere -------------------------------------------- *)
Procedure ShowBanner;
Begin
  WriteLn('REXX86 v', REXX86_VERSION, ' (', REXX86_DATE, ')');
  WriteLn('Compilateur REXX -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

(* ---- Aide en ligne --------------------------------------- *)
Procedure ShowUsage;
Begin
  WriteLn('Usage: REXX86 <source.rex> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.rex  : fichier REXX source (.rex, .rexx ou .cmd)');
  WriteLn('  sortie.asm  : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v          : mode verbeux (banniere + statistiques)');
  WriteLn('  -d          : debug tokens (affiche chaque token)');
  WriteLn('  -w          : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

(* ---- Utilitaires chaines --------------------------------- *)

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

(* ---- Manipulation de chemins ------------------------------ *)

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

(* ---- Gestion des options --------------------------------- *)

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
      WriteLn('REXX86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('REXX86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('REXX86: fichier source manquant');
    ShowUsage;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

(* ---- Nettoyage ------------------------------------------- *)

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

(* ---- Initialisation globale ------------------------------ *)

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
  LexNeedEOL     := False;
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
  TODO 02 - LEXEUR (TOKENS REXX) [IMPLEMENTE]
  ============================================================ }

(* ---- IsKeyword : teste si S est un mot-cle REXX ---------- *)
(* Les mots-cles sont compares en majuscules (REXX insensible) *)
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'ADDRESS')   Or (S = 'ARG')       Or (S = 'BY')         Or
    (S = 'CALL')      Or (S = 'DO')        Or (S = 'DROP')       Or
    (S = 'ELSE')      Or (S = 'END')       Or (S = 'EXIT')       Or
    (S = 'EXPOSE')    Or (S = 'FOR')       Or (S = 'FOREVER')    Or
    (S = 'FUNCTION')  Or (S = 'IF')        Or (S = 'INTERPRET')  Or
    (S = 'ITERATE')   Or (S = 'LEAVE')     Or (S = 'LOOP')       Or
    (S = 'NOP')       Or (S = 'NUMERIC')   Or (S = 'OTHERWISE')  Or
    (S = 'PARSE')     Or (S = 'PROCEDURE') Or (S = 'PULL')       Or
    (S = 'PUSH')      Or (S = 'QUEUE')     Or (S = 'RETURN')     Or
    (S = 'SAY')       Or (S = 'SELECT')    Or (S = 'SIGNAL')     Or
    (S = 'THEN')      Or (S = 'TO')        Or (S = 'TRACE')      Or
    (S = 'UNTIL')     Or (S = 'UPPER')     Or (S = 'VALUE')      Or
    (S = 'WHEN')      Or (S = 'WHILE')     Or (S = 'WITH');
End;

(* ---- PrintToken : affichage debug d un token -------------- *)
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF     : Write('EOF');
    TK_NUMBER  : Write('NUM(', T.Val, '=', T.IntVal, ')');
    TK_STRING  : Write('STR(''', T.Val, ''')');
    TK_IDENT   : Write('IDENT(', T.Val, ')');
    TK_KEYWORD : Write('KW(', T.Val, ')');
    TK_OP      : Write('OP(', T.Val, ')');
    TK_PUNCT   : Write('PUNCT(', T.Val, ')');
    TK_LABEL   : Write('LABEL(', T.Val, ')');
    TK_COMMA   : Write('COMMA');
    TK_EOL     : Write('EOL');
  End;
  WriteLn;
End;

(* ---- LexNextLine : lire la prochaine ligne source --------- *)
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

(* ---- LexSkipBlockComment : commentaires imbriques /* */ --- *)
(* REXX autorise les commentaires imbriques : nesting level    *)
Procedure LexSkipBlockComment;
Var
  Depth : Integer;
Begin
  Inc(LexColNo); Inc(LexColNo); (* sauter /* *)
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If (LexLine[LexColNo] = '/') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      Inc(Depth);
      Inc(LexColNo); Inc(LexColNo);
    End
    Else If (LexLine[LexColNo] = '*') And
            (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      Dec(Depth);
      Inc(LexColNo); Inc(LexColNo);
    End
    Else
      Inc(LexColNo);
  End;
  If Depth > 0 Then
    CompileError('commentaire /* non ferme en fin de fichier');
End;

(* ---- Fonctions de test sur les caracteres ------------------ *)
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_') Or (Ch = '!') Or (Ch = '?');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9')) Or
                 (Ch = '.');
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

(* ---- LexScanIdent : identificateur ou mot-cle ------------- *)
(* En REXX, les variables sont converties en majuscules        *)
(* Un identificateur suivi de ':' est reconnu comme label      *)
Procedure LexScanIdent;
Var
  S : TString;
  U : TString;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  U := StrUpperCase(S);
  (* Detecter label : ident suivi de ':' *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = ':') Then
  Begin
    Inc(LexColNo); (* consommer ':' *)
    CurToken.Kind   := TK_LABEL;
    CurToken.Val    := U;
    CurToken.IntVal := 0;
    Exit;
  End;
  CurToken.IntVal := 0;
  If IsKeyword(U) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := U;
  End
  Else
  Begin
    CurToken.Kind := TK_IDENT;
    CurToken.Val  := U;
  End;
End;

(* ---- LexScanNumber : literal numerique -------------------- *)
(* REXX : nombres decimaux simples, pas de 0x ou 0b prefixes  *)
(* Les nombres decimaux sont tronques en entier                *)
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsFloat : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
  ExpVal  : Integer;
  NegExp  : Boolean;
Begin
  N       := 0;
  IsFloat := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  (* Partie entiere *)
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;
  (* Partie decimale .ddd *)
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); (* sauter '.' *)
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
  (* Exposant e/E [+-]ddd *)
  If (LexColNo <= Length(LexLine)) And
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
  (* Calculer la valeur finale tronquee a entier *)
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
  CurToken.Kind := TK_NUMBER;
End;

(* ---- LexScanString : chaines REXX ------------------------ *)
(* REXX supporte :                                              *)
(*   'abc' ou "abc" (doublement pour echapper : 'l''eau')       *)
(*   'hex hex'x -> chaine hexadecimale                          *)
(*   'bits'b -> chaine binaire                                  *)
Procedure LexScanString(Quote : Char);
Var
  S     : TString;
  Ch    : Char;
  Tmp   : TString;
  HByte : Integer;
  BitCt : Integer;
  HCt   : Integer;
  I     : Integer;
Begin
  S := '';
  Inc(LexColNo); (* sauter le guillemet ouvrant *)
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = Quote Then
    Begin
      Inc(LexColNo);
      (* Doublement : 'l''eau' -> l'eau *)
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = Quote) Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + Quote;
        Inc(LexColNo);
      End
      Else
        Break; (* fin de chaine *)
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  (* Verifier suffixe x (hexadecimal) *)
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'x') Or (LexLine[LexColNo] = 'X')) Then
  Begin
    Inc(LexColNo);
    Tmp := '';
    HByte := 0;
    HCt := 0;
    For I := 1 To Length(S) Do
    Begin
      Ch := S[I];
      If Ch = ' ' Then Continue;
      If Not IsHexDigit(Ch) Then
      Begin
        CompileError('chiffre hexadecimal attendu dans chaine hex');
        Break;
      End;
      HByte := HByte * 16 + HexVal(Ch);
      Inc(HCt);
      If HCt = 2 Then
      Begin
        If Length(Tmp) < MAX_STR Then
          Tmp := Tmp + Chr(HByte And $FF);
        HByte := 0;
        HCt := 0;
      End;
    End;
    If HCt = 1 Then
    Begin
      (* Un seul chiffre hex restant : traiter comme demi-octet bas *)
      If Length(Tmp) < MAX_STR Then
        Tmp := Tmp + Chr(HByte And $FF);
    End;
    S := Tmp;
  End
  (* Verifier suffixe b (binaire) *)
  Else If (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'b') Or (LexLine[LexColNo] = 'B')) Then
  Begin
    Inc(LexColNo);
    Tmp := '';
    HByte := 0;
    BitCt := 0;
    For I := 1 To Length(S) Do
    Begin
      Ch := S[I];
      If Ch = ' ' Then Continue;
      If (Ch <> '0') And (Ch <> '1') Then
      Begin
        CompileError('chiffre binaire attendu dans chaine binaire');
        Break;
      End;
      HByte := HByte * 2 + (Ord(Ch) - Ord('0'));
      Inc(BitCt);
      If BitCt = 8 Then
      Begin
        If Length(Tmp) < MAX_STR Then
          Tmp := Tmp + Chr(HByte And $FF);
        HByte := 0;
        BitCt := 0;
      End;
    End;
    If BitCt > 0 Then
    Begin
      (* Reste de bits : decaler a gauche pour remplir l octet *)
      While BitCt < 8 Do
      Begin
        HByte := HByte * 2;
        Inc(BitCt);
      End;
      If Length(Tmp) < MAX_STR Then
        Tmp := Tmp + Chr(HByte And $FF);
    End;
    S := Tmp;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- LexNextToken : produire le prochain token ------------ *)
Procedure LexNextToken;
Var
  Ch       : Char;
  Scanning : Boolean;
Begin
  Scanning := True;
  While Scanning Do
  Begin
    (* Si une fin de ligne physique est en attente, emettre TK_EOL *)
    If LexNeedEOL Then
    Begin
      LexNeedEOL := False;
      CurToken.Kind   := TK_EOL;
      CurToken.Val    := '';
      CurToken.IntVal := 0;
      CurToken.Line   := LexLineNo;
      CurToken.Col    := 0;
      Scanning := False;
      PrintToken(CurToken);
      Exit;
    End;

    (* Passer a la ligne suivante si en fin de ligne physique *)
    If (Not LexEOF) And (LexColNo > Length(LexLine)) Then
    Begin
      LexNeedEOL := True;
      LexNextLine;
      While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
        LexNextLine;
      Continue;  (* remonter au debut de la boucle pour emettre TK_EOL *)
    End;

    If LexEOF Then
    Begin
      CurToken.Kind   := TK_EOF;
      CurToken.Val    := '';
      CurToken.IntVal := 0;
      CurToken.Line   := LexLineNo;
      CurToken.Col    := LexColNo;
      Scanning := False;
      Exit;
    End;

    CurToken.Line := LexLineNo;
    CurToken.Col  := LexColNo;
    Ch := LexLine[LexColNo];

    (* Espaces blancs *)
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    (* Commentaire bloc imbrique /* ... */ *)
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
      LexNeedEOL := False; (* commentaire ne cree pas de fin de ligne *)
    End

    (* Fin de ligne : point-virgule implicite ou explicite *)
    Else If Ch = ';' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_EOL;
      CurToken.Val    := ';';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Virgule - aussi continuation de ligne *)
    Else If Ch = ',' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_COMMA;
      CurToken.Val    := ',';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Parentheses et ponctuation *)
    Else If (Ch = '(') Or (Ch = ')') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_PUNCT;
      CurToken.Val    := Ch;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Chaine entre apostrophes *)
    Else If Ch = '''' Then
    Begin
      LexScanString('''');
      Scanning := False;
    End

    (* Chaine entre guillemets *)
    Else If Ch = '"' Then
    Begin
      LexScanString('"');
      Scanning := False;
    End

    (* Nombre *)
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      Scanning := False;
    End

    (* Identificateur, mot-cle ou label *)
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Scanning := False;
    End

    (* Operateur : concatenation explicite || *)
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '||';
      CurToken.IntVal := 0;
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    (* Operateur logique OR : | *)
    Else If Ch = '|' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '|';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Operateur logique XOR : && *)
    Else If (Ch = '&') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '&') Then
    Begin
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '&&';
      CurToken.IntVal := 0;
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    (* Operateur logique AND : & *)
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '&';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Operateurs de comparaison et affectation *)
    Else If Ch = '=' Then
    Begin
      Inc(LexColNo);
      (* Comparaison stricte == *)
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := '==';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '=';
      End;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* NOT (\) et \= \== *)
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP;
          CurToken.Val  := '\==';
        End
        Else
        Begin
          CurToken.Kind := TK_OP;
          CurToken.Val  := '\=';
        End;
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '\';
      End;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Operateurs > >= >> >>= *)
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP;
          CurToken.Val  := '>>=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP;
          CurToken.Val  := '>>';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := '>=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '>';
      End;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Operateurs < <= << <<= *)
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '<') Then
      Begin
        Inc(LexColNo);
        If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
        Begin
          Inc(LexColNo);
          CurToken.Kind := TK_OP;
          CurToken.Val  := '<<=';
        End
        Else
        Begin
          CurToken.Kind := TK_OP;
          CurToken.Val  := '<<';
        End;
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        Inc(LexColNo);
        CurToken.Kind := TK_OP;
        CurToken.Val  := '<=';
      End
      Else
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '<';
      End;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Operateurs arithmetiques : + - *)
    Else If (Ch = '+') Or (Ch = '-') Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := Ch;
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Puissance ** *)
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '**';
      CurToken.IntVal := 0;
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    (* Multiplication * *)
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '*';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Reste // *)
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '//';
      CurToken.IntVal := 0;
      Inc(LexColNo); Inc(LexColNo);
      Scanning := False;
    End

    (* Division / *)
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '/';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Division entiere % *)
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_OP;
      CurToken.Val    := '%';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Deux-points : (ponctuation, mais pas un label ici) *)
    Else If Ch = ':' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_PUNCT;
      CurToken.Val    := ':';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Point : placeholder dans PARSE template (TODO 16) *)
    Else If Ch = '.' Then
    Begin
      Inc(LexColNo);
      CurToken.Kind   := TK_PUNCT;
      CurToken.Val    := '.';
      CurToken.IntVal := 0;
      Scanning := False;
    End

    (* Caractere inconnu *)
    Else
    Begin
      CompileError('caractere inattendu: ' + Ch);
      Inc(LexColNo);
    End;
  End; (* While Scanning *)

  PrintToken(CurToken);
End;

(* ---- LexInit : initialiser le lexeur ---------------------- *)
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir ' + Opts.SrcFile);
  LexOpened := True;
  LexLineNo := 0;
  LexColNo  := 1;
  LexEOF    := False;
  LexLine   := '';
  (* Lire la premiere ligne *)
  LexNextLine;
  (* Lire le premier token *)
  LexNextToken;
End;

(* ---- LexClose : fermer le fichier source ------------------ *)
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

(* ---- ExprMakeImm : construire une valeur immediate -------- *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeNone : valeur invalide (void / erreur) ------- *)
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- LitEvalInt : evaluer un token TK_NUMBER (entier) ----- *)
(* IntVal est deja calcule par LexScanNumber.                   *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_INTEGER, Res);
End;

(* ---- LitEvalFloat : evaluer un nombre decimal (tronque) --- *)
(* REXX n a pas de distinction entier/flottant pour le code ;   *)
(* les decimaux sont tronques en entier 16 bits par le lexeur.  *)
(* On emet un avertissement si la valeur originale contenait    *)
(* un point decimal ou un exposant.                             *)
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  WarnMsg('nombre decimal ''' + T.Val + ''' tronque en entier');
  ExprMakeImm(T.IntVal, TY_IDX_INTEGER, Res);
End;

(* ---- LitEval : dispatcher principal pour les litteraux ---- *)
(* Tokens acceptes :                                            *)
(*   TK_NUMBER  -> entier 16 bits (EK_IMM)                     *)
(*   TK_STRING  -> stocker en DATA, retourner index (EK_MEM)   *)
(*   TK_IDENT   -> constantes predefinies RC, RESULT, SIGL     *)
(*     (variables speciales non encore affectees = leur nom)    *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Var
  U   : TString;
  Idx : Integer;
Begin
  ExprMakeNone(Res);
  Case T.Kind Of
    (* --- Nombres : entier ou decimal tronque --- *)
    TK_NUMBER :
      LitEvalInt(T, Res);

    (* --- Chaines : stocker en DATA, retourner index DataTab --- *)
    TK_STRING :
    Begin
      DataAddStr(T.Val);
      Idx := DataCount - 1;
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_STRING;
      Res.Offset  := Idx;
      Res.SymIdx  := -1;
    End;

    (* --- Identificateur : verifier constantes predefinies --- *)
    TK_IDENT :
    Begin
      U := T.Val; (* deja en majuscules par le lexeur *)
      If U = 'RC' Then
      Begin
        (* RC = code retour : _RX_RC (DW) *)
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else If U = 'RESULT' Then
      Begin
        (* RESULT = valeur de retour : _RX_RESULT (chaine) *)
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_STRING;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End
      Else If U = 'SIGL' Then
      Begin
        (* SIGL = numero de ligne : _RX_SIGL (DW) *)
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_INTEGER;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End;
      (* Si non reconnu, ExprMakeNone reste valide (sera traite *)
      (* par le parseur comme variable/fonction dans TODO 09/10) *)
    End;
  End; (* Case *)
End;

(* ============================================================
   TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
   ============================================================ *)

(* ---- SymNameClean : nettoyer les caracteres non-MASM ------- *)
(* Remplace tout caractere non alpha-numerique par '_'.         *)
(* Retourne '_anon' si le resultat est vide.                    *)
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

(* ---- SymMangle : calculer le nom ASM mangled --------------- *)
(* Prefixes REXX :                                               *)
(*   SK_VAR     -> _RXV_   (variable simple)                    *)
(*   SK_LABEL   -> _RXP_   (label / cible SIGNAL/CALL)         *)
(*   SK_PROC    -> _RXP_   (procedure interne)                  *)
(*   SK_STEM    -> _RXS_   (variable composee)                  *)
(*   SK_EXPOSED -> _RXV_   (meme prefixe que variable)          *)
(*   SK_BUILTIN -> _RXB_   (fonction integree)                  *)
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_VAR     : SymMangle := RX_VAR_PFX  + Clean;
    SK_LABEL   : SymMangle := RX_PROC_PFX + Clean;
    SK_PROC    : SymMangle := RX_PROC_PFX + Clean;
    SK_STEM    : SymMangle := RX_STEM_PFX + Clean;
    SK_EXPOSED : SymMangle := RX_VAR_PFX  + Clean;
    SK_BUILTIN : SymMangle := RX_BLT_PFX  + Clean;
  Else
    SymMangle := RX_VAR_PFX + Clean;
  End;
End;

(* ---- SymFind : chercher un symbole par nom (MRU d abord) --- *)
(* Recherche insensible a la casse : les noms sont stockes en   *)
(* majuscules dans la table (convention REXX).                   *)
(* Retourne l index (0-base) ou -1 si non trouve.               *)
Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = U Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

(* ---- SymFindInScope : chercher dans une portee specifique -- *)
(* Retourne l index ou -1.                                      *)
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = U) And (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

(* ---- SymAdd : ajouter un symbole dans la table ------------- *)
(* Le nom est converti en majuscules (convention REXX).         *)
(* Retourne l index du symbole (0-base) ou -1 si erreur.        *)
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Var
  U   : TString;
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;

  U := StrUpperCase(Name);
  Idx := SymCount;

  SymTab[Idx].Name        := U;
  SymTab[Idx].MangledName := SymMangle(U, Kind);
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].TypeIdx     := TypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsExposed   := (Kind = SK_EXPOSED);
  SymTab[Idx].IsStem      := (Kind = SK_STEM);
  SymTab[Idx].DeclLine    := LexLineNo;

  If Opts.DebugMode Then
    WriteLn('  SYM[', Idx, '] ', U,
            ' kind=', Ord(Kind),
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  Inc(SymCount);
  Inc(TotalSyms);
  SymAdd := Idx;
End;

(* ---- SymEnterScope : ouvrir une nouvelle portee ------------ *)
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('portees imbriquees trop profondes (max=' +
                 IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER -> ', CurScope);
End;

(* ---- SymLeaveScope : fermer la portee courante ------------- *)
Procedure SymLeaveScope;
Begin
  If ScopeTop > 0 Then
  Begin
    Dec(ScopeTop);
    SymCount := ScopeStack[ScopeTop];
    Dec(CurScope);
    If Opts.DebugMode Then
      WriteLn('  SCOPE_LEAVE -> ', CurScope);
  End;
End;

(* ---- SymInit : initialiser la table et enregistrer les builtins *)
(* En REXX, toutes les fonctions integrees (BIF) sont connues     *)
(* globalement. On les enregistre comme SK_BUILTIN, portee 0.     *)
Procedure SymInit;

  Procedure RegBuiltin(Const BName : TString);
  Begin
    SymAdd(BName, SK_BUILTIN, TY_IDX_STRING, 0);
  End;

Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;

  (* --- Fonctions integrees REXX (BIF) --- *)
  (* Chaines *)
  RegBuiltin('ABBREV');
  RegBuiltin('CENTER');
  RegBuiltin('CENTRE');
  RegBuiltin('CHANGESTR');
  RegBuiltin('COMPARE');
  RegBuiltin('COPIES');
  RegBuiltin('COUNTSTR');
  RegBuiltin('DELSTR');
  RegBuiltin('DELWORD');
  RegBuiltin('INSERT');
  RegBuiltin('LASTPOS');
  RegBuiltin('LEFT');
  RegBuiltin('LENGTH');
  RegBuiltin('OVERLAY');
  RegBuiltin('POS');
  RegBuiltin('REVERSE');
  RegBuiltin('RIGHT');
  RegBuiltin('SPACE');
  RegBuiltin('STRIP');
  RegBuiltin('SUBSTR');
  RegBuiltin('SUBWORD');
  RegBuiltin('TRANSLATE');
  RegBuiltin('VERIFY');
  RegBuiltin('WORD');
  RegBuiltin('WORDINDEX');
  RegBuiltin('WORDLENGTH');
  RegBuiltin('WORDPOS');
  RegBuiltin('WORDS');
  RegBuiltin('XRANGE');

  (* Conversion *)
  RegBuiltin('C2D');
  RegBuiltin('C2X');
  RegBuiltin('D2C');
  RegBuiltin('D2X');
  RegBuiltin('X2C');
  RegBuiltin('X2D');
  RegBuiltin('B2X');
  RegBuiltin('X2B');

  (* Arithmetique *)
  RegBuiltin('ABS');
  RegBuiltin('FORMAT');
  RegBuiltin('MAX');
  RegBuiltin('MIN');
  RegBuiltin('SIGN');
  RegBuiltin('TRUNC');

  (* Informations *)
  RegBuiltin('ADDRESS');
  RegBuiltin('ARG');
  RegBuiltin('DATATYPE');
  RegBuiltin('DATE');
  RegBuiltin('DIGITS');
  RegBuiltin('ERRORTEXT');
  RegBuiltin('FORM');
  RegBuiltin('FUZZ');
  RegBuiltin('QUEUED');
  RegBuiltin('RANDOM');
  RegBuiltin('SOURCELINE');
  RegBuiltin('SYMBOL');
  RegBuiltin('TIME');
  RegBuiltin('TRACE');
  RegBuiltin('VALUE');

  (* Entrees-sorties *)
  RegBuiltin('CHARIN');
  RegBuiltin('CHAROUT');
  RegBuiltin('CHARS');
  RegBuiltin('LINEIN');
  RegBuiltin('LINEOUT');
  RegBuiltin('LINES');
  RegBuiltin('STREAM');

  (* Logique binaire *)
  RegBuiltin('BITAND');
  RegBuiltin('BITOR');
  RegBuiltin('BITXOR');

  (* Divers *)
  RegBuiltin('CONDITION');
  RegBuiltin('QUALIFY');
  RegBuiltin('USERID');

  If Opts.DebugMode Then
    WriteLn('  SYM_INIT: ', SymCount, ' builtins enregistres');
End;

(* ============================================================
   TODO 06 - SYSTEME DE TYPES INTERNE [IMPLEMENTE]
   ============================================================ *)

(* ---- TypeKindOf : retourner le TTypeKind associe a un indice ---- *)
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_STRING;   { par defaut : chaine (tout est chaine en REXX) }
End;

(* ---- TypeSizeof : taille en octets d un type -------------------- *)
(* En 16 bits : tous les types REXX occupent 2 octets (word).        *)
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

(* ---- TypeMangle : prefixe ASM selon le type pour les labels ----- *)
(*   STRING  -> _RXN_  (pointeur near vers chaine)                   *)
(*   INTEGER -> _RXI_  (mot 16 bits dans AX/registre)                *)
(*   BOOLEAN -> _RXB_  (0 ou 1 dans AL, etendu AX)                  *)
(*   STEM    -> _RXS_  (pointeur near vers table stem)               *)
(*   defaut  -> _RXX_                                                *)
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_STRING  : TypeMangle := '_RXN_';
    TYK_INTEGER : TypeMangle := '_RXI_';
    TYK_BOOLEAN : TypeMangle := '_RXB_';
    TYK_STEM    : TypeMangle := '_RXS_';
  Else
    TypeMangle := '_RXX_';
  End;
End;

(* ---- TypeIsNumeric : vrai si le type est utilisable comme nombre -- *)
(* En REXX, STRING et INTEGER et BOOLEAN sont tous numeriques :       *)
(*   STRING est toujours potentiellement un nombre (conversion auto),  *)
(*   INTEGER est nativement numerique,                                  *)
(*   BOOLEAN est 0 ou 1 (donc numerique aussi).                        *)
(* Seul STEM (tableau associatif) n est pas directement numerique.     *)
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_STRING) Or (K = TYK_INTEGER) Or (K = TYK_BOOLEAN);
End;

(* ---- TypeIsPtr : vrai si le type est un pointeur near ----------- *)
(* STRING et STEM sont des pointeurs vers la zone chaines / heap.     *)
(* INTEGER et BOOLEAN sont des scalaires dans AX.                     *)
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsPtr := (K = TYK_STRING) Or (K = TYK_STEM);
End;

(* ---- TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx ? ----- *)
(* En REXX, tout est chaine : toute coercition scalaire est possible  *)
(* car les nombres sont des chaines avec representation numerique.     *)
(* Seules les conversions impliquant STEM sont refusees.               *)
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
  { UNKNOWN -> n importe quoi : OK (on perd l info de type) }
  If SrcIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  { STEM ne se convertit pas en scalaire et inversement }
  If (SK = TYK_STEM) Or (DK = TYK_STEM) Then
  Begin
    TypeCanCoerce := (SK = DK);
    Exit;
  End;
  { Toutes les autres coercitions scalaires sont possibles en REXX }
  { STRING <-> INTEGER : conversion numerique implicite            }
  { STRING <-> BOOLEAN : '0'/'1' <-> 0/1                          }
  { INTEGER <-> BOOLEAN : 0 = False, non-0 = True                 }
  TypeCanCoerce := True;
End;

(* ---- TypeCoerceResult : deduire le type resultat d une operation -- *)
(* Regles REXX :                                                       *)
(*   - operateurs logiques (& | &&) -> BOOLEAN                        *)
(*   - operateurs de comparaison (= \= < > etc.) -> BOOLEAN           *)
(*   - operateurs arithmetiques (+ - * / % //) -> INTEGER              *)
(*     (si les deux operandes sont INTEGER, sinon STRING pour runtime)  *)
(*   - concatenation (|| espace) -> STRING                             *)
(*   - puissance ( ** ) -> INTEGER                                     *)
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);

  { Operateurs de comparaison -> BOOLEAN }
  If (Op = '=')  Or (Op = '\=') Or (Op = '<>') Or
     (Op = '><') Or (Op = '<')  Or (Op = '>') Or
     (Op = '<=') Or (Op = '>=') Or (Op = '<<') Or
     (Op = '>>') Or (Op = '\<') Or (Op = '\>') Or
     (Op = '==') Or (Op = '\==') Or
     (Op = '<<=') Or (Op = '>>=') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;

  { Operateurs logiques -> BOOLEAN }
  If (Op = '&') Or (Op = '|') Or (Op = '&&') Then
  Begin
    TypeCoerceResult := TY_IDX_BOOLEAN;
    Exit;
  End;

  { Concatenation -> STRING }
  If (Op = '||') Then
  Begin
    TypeCoerceResult := TY_IDX_STRING;
    Exit;
  End;

  { Operateurs arithmetiques : si les deux cotes sont INTEGER, }
  { le resultat est INTEGER (optimisation registres), sinon     }
  { STRING (passage via runtime string-to-number).              }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Or (Op = '//') Or
     (Op = '**') Then
  Begin
    If ((LK = TYK_INTEGER) Or (LK = TYK_BOOLEAN)) And
       ((RK = TYK_INTEGER) Or (RK = TYK_BOOLEAN)) Then
      TypeCoerceResult := TY_IDX_INTEGER
    Else
      TypeCoerceResult := TY_IDX_STRING;
    Exit;
  End;

  { Par defaut : STRING (type principal REXX) }
  TypeCoerceResult := TY_IDX_STRING;
End;

(* ---- TypeInfer : deduire le type d une expression depuis TExprVal -- *)
(* Si le TypeIdx est deja connu, on le retourne.                        *)
(* Si la valeur est une immediate, on suppose INTEGER.                  *)
(* Sinon, STRING par defaut (REXX = tout est chaine).                   *)
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_INTEGER
  Else
    TypeInfer := TY_IDX_STRING;
End;

(* ---- TypeLookupName : chercher un type par nom dans TypeTab -------- *)
(* Comparaison insensible a la casse (convention REXX).                 *)
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := 0 To TypeCount - 1 Do
    If StrUpperCase(TypeTab[I].Name) = U Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

(* ---- TypeInit : enregistrer les types primitifs REXX --------------- *)
(* Indices fixes : TY_IDX_STRING=0, TY_IDX_INTEGER=1,                  *)
(*                 TY_IDX_BOOLEAN=2, TY_IDX_STEM=3                     *)
(* En REXX tout est chaine : STRING est le type principal.              *)
(*   STRING  = 2 octets (pointeur near vers espace chaines)             *)
(*   INTEGER = 2 octets (mot dans AX, optimisation arithmetique)        *)
(*   BOOLEAN = 2 octets (0 ou 1 dans AX)                               *)
(*   STEM    = 2 octets (pointeur near vers table associative)          *)
Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Kind := TYK_STRING;
    TypeTab[I].Size := 0;
  End;
  (* STRING : type principal REXX *)
  TypeTab[TY_IDX_STRING].Name  := 'STRING';
  TypeTab[TY_IDX_STRING].Kind  := TYK_STRING;
  TypeTab[TY_IDX_STRING].Size  := 2;
  (* INTEGER : optimisation interne pour arithmetique *)
  TypeTab[TY_IDX_INTEGER].Name := 'INTEGER';
  TypeTab[TY_IDX_INTEGER].Kind := TYK_INTEGER;
  TypeTab[TY_IDX_INTEGER].Size := 2;
  (* BOOLEAN : resultat logique 0/1 *)
  TypeTab[TY_IDX_BOOLEAN].Name := 'BOOLEAN';
  TypeTab[TY_IDX_BOOLEAN].Kind := TYK_BOOLEAN;
  TypeTab[TY_IDX_BOOLEAN].Size := 2;
  (* STEM : variable composee / tableau associatif *)
  TypeTab[TY_IDX_STEM].Name    := 'STEM';
  TypeTab[TY_IDX_STEM].Kind    := TYK_STEM;
  TypeTab[TY_IDX_STEM].Size    := 2;
  TypeCount := TY_PRIM_COUNT;

  If Opts.DebugMode Then
    WriteLn('  TYPE_INIT: ', TypeCount, ' types primitifs enregistres');
End;

(* ============================================================
   TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
   ============================================================ *)

(* ---- LabelGen : generer un label unique _RXL_N ------------- *)
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := RX_LBL_PFX + S;
End;

(* ---- EmitRaw : ecrire une ligne brute dans le fichier ASM -- *)
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

(* ---- EmitBlankLine : ligne vide ----------------------------- *)
Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

(* ---- EmitComment : commentaire ASM '; texte' --------------- *)
Procedure EmitComment(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', S);
End;

(* ---- EmitLabel : label ASM suivi de ':' en colonne 0 ------- *)
Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
End;

(* ---- EmitInstr : instruction + operandes (8 espaces) ------- *)
(* Si Ops est vide, seul le mnemonique est emis.                *)
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  If OutFOpen Then
  Begin
    If Ops = '' Then
      WriteLn(OutF, '        ', Mnem)
    Else
      WriteLn(OutF, '        ', Mnem, '     ', Ops);
  End;
End;

(* ---- EmitInstrA : instruction + un operande ----------------- *)
Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, '   ', A1);
End;

(* ---- EmitInstrAB : instruction + deux operandes A, B -------- *)
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, '   ', A1, ', ', A2);
End;

(* ---- EmitOpen : ouvrir le fichier de sortie ASM ------------- *)
Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  {$I-}
  Rewrite(OutF);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('impossible de creer ' + Opts.OutFile);
    Exit; { FatalError appelle Halt, mais par securite }
  End;
  OutFOpen := True;
End;

(* ---- EmitHeader : en-tete MASM (.MODEL SMALL, _TEXT) -------- *)
(* Emet la directive .MODEL SMALL, .STACK, ouvre le segment       *)
(* _TEXT et initialise DS dans le point d entree _RXP_Main.       *)
Procedure EmitHeader;
Begin
  EmitComment('REXX86 v' + REXX86_VERSION + ' - ' + Opts.SrcFile);
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT SEGMENT PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:NOTHING');
  EmitBlankLine;
  EmitComment('--- Point d''entree (main) ---');
  EmitLabel('_RXP_Main');
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

(* ---- EmitProlog : prologue de procedure (PUSH BP/MOV BP,SP) -- *)
Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If CurFrameSize > 0 Then
    EmitInstrAB('SUB', 'SP', IntToStr(CurFrameSize));
End;

(* ---- EmitEpilog : epilogue de procedure (POP BP/RET) --------- *)
Procedure EmitEpilog;
Begin
  If CurFrameSize > 0 Then
    EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
End;

(* ---- EmitDataSeg : emettre le segment _DATA dans le .ASM ----- *)
(* Ecrit _DATA SEGMENT ... _DATA ENDS avec toutes les donnees     *)
(* de DataTab (predefinies par DataInit + utilisateur).             *)
(* Les caracteres de controle dans DK_STR sont emis en valeur     *)
(* numerique (DB n) au lieu de notation chaine MASM.               *)
Procedure EmitDataSeg;
Var
  I, J : Integer;
  B    : Byte;
  NS   : String[6];
  InStr : Boolean;
Begin
  EmitBlankLine;
  EmitRaw('_DATA SEGMENT PUBLIC ''DATA''');
  EmitRaw('        ASSUME DS:_DATA');
  EmitBlankLine;
  EmitComment('Donnees REXX (predefinies + utilisateur)');
  (* Toutes les donnees depuis DataTab *)
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD:
        EmitRaw(DataTab[I].LblName + ' DW ' + IntToStr(DataTab[I].IntVal));
      DK_BYTE:
        EmitRaw(DataTab[I].LblName + ' DB ' + IntToStr(DataTab[I].IntVal));
      DK_STR:
        Begin
          (* Gestion des caracteres de controle et apostrophes *)
          If OutFOpen Then
          Begin
            Write(OutF, DataTab[I].LblName, ' DB ');
            If Length(DataTab[I].StrVal) = 0 Then
              WriteLn(OutF, '0')  (* chaine vide -> juste le NUL terminal *)
            Else
            Begin
              InStr := False;
              For J := 1 To Length(DataTab[I].StrVal) Do
              Begin
                B := Ord(DataTab[I].StrVal[J]);
                If (B < 32) Or (B > 126) Or (B = 39) Then  (* 39 = apostrophe *)
                Begin
                  (* caractere non imprimable ou apostrophe -> numerique *)
                  If InStr Then
                  Begin
                    Write(OutF, '''');
                    InStr := False;
                  End;
                  If J > 1 Then Write(OutF, ',');
                  Str(B, NS);
                  Write(OutF, NS);
                End
                Else
                Begin
                  (* caractere imprimable -> notation chaine *)
                  If Not InStr Then
                  Begin
                    If J > 1 Then Write(OutF, ',');
                    Write(OutF, '''');
                    InStr := True;
                  End;
                  Write(OutF, DataTab[I].StrVal[J]);
                End;
              End;
              If InStr Then
                Write(OutF, '''');
              WriteLn(OutF, ',0');
            End;
          End;
        End;
      DK_BUFFER:
        EmitRaw(DataTab[I].LblName + ' DB ' +
                IntToStr(DataTab[I].BufSize) + ' DUP(0)');
    End;
  End;
  EmitRaw('_DATA ENDS');
End;

(* ---- EmitRuntime : routines runtime minimales REXX ----------- *)
(* Emet le runtime minimal necessaire pour SAY et la gestion des  *)
(* erreurs. Sera etendu dans TODO 24.                              *)
Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('--- Runtime minimal REXX ---');
  EmitBlankLine;

  (* _RXRT_PRINT : affiche chaine ASCIIZ pointee par SI sur STDOUT *)
  EmitLabel('_RXRT_PRINT');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel('_RXRT_PRINT_L');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', '_RXRT_PRINT_W');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', '_RXRT_PRINT_L');
  EmitLabel('_RXRT_PRINT_W');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstrAB('MOV', 'BX', '1');
  EmitInstrAB('MOV', 'DX', 'SI');
  EmitRaw('        INT     21h');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_PRINTLN : affiche chaine SI + CR+LF *)
  EmitLabel('_RXRT_PRINTLN');
  EmitInstrA('CALL', '_RXRT_PRINT');
  EmitInstrAB('MOV', 'SI', 'OFFSET _RX_CRLF');
  EmitInstrA('CALL', '_RXRT_PRINT');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_PANIC : affiche msg + exit code 1 *)
  EmitLabel('_RXRT_PANIC');
  EmitInstrA('CALL', '_RXRT_PRINTLN');
  EmitInstrAB('MOV', 'AX', '4C01h');
  EmitRaw('        INT     21h');
  EmitBlankLine;

  (* _RXP_Exit : sortie propre du programme (exit code 0) *)
  EmitLabel('_RXP_Exit');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitRaw('        INT     21h');
  EmitBlankLine;

  (* _RXRT_STRCPY : copier chaine ASCIIZ de SI vers DI *)
  (* Entree : SI = source, DI = destination              *)
  (* Sortie : rien (DI pointe apres le 0 final)          *)
  EmitLabel('_RXRT_STRCPY');
  EmitInstrA('PUSH', 'AX');
  EmitLabel('_RXRT_STRCPY_L');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', '_RXRT_STRCPY_L');
  EmitInstrA('POP', 'AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_UPPER : convertir chaine ASCIIZ pointee par SI en majuscules *)
  (* Entree : SI = chaine a convertir (modifiee sur place)               *)
  EmitLabel('_RXRT_UPPER');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'SI');
  EmitLabel('_RXRT_UPPER_L');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', '_RXRT_UPPER_D');
  EmitInstrAB('CMP', 'AL', '''a''');
  EmitInstrA('JB', '_RXRT_UPPER_N');
  EmitInstrAB('CMP', 'AL', '''z''');
  EmitInstrA('JA', '_RXRT_UPPER_N');
  EmitInstrAB('SUB', 'AL', '20h');
  EmitInstrAB('MOV', 'BYTE PTR [SI]', 'AL');
  EmitLabel('_RXRT_UPPER_N');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_UPPER_L');
  EmitLabel('_RXRT_UPPER_D');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  TODO 11 - Runtime pour expressions binaires et concatenation *)
  (* ============================================================ *)

  (* _RXRT_STRLEN : longueur d'une chaine ASCIIZ               *)
  (* Entree : SI = chaine ASCIIZ                                *)
  (* Sortie : CX = longueur (octets avant le 0 terminal)       *)
  EmitLabel('_RXRT_STRLEN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel('_RXRT_STRLEN_L');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXRT_STRLEN_D');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', '_RXRT_STRLEN_L');
  EmitLabel('_RXRT_STRLEN_D');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_NUMTOSTR : convertir entier signe en chaine ASCIIZ  *)
  (* Entree : AX = entier signe                                *)
  (* Sortie : SI = adresse du resultat dans _RX_NUMBUF          *)
  EmitLabel('_RXRT_NUMTOSTR');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _RX_NUMBUF');
  EmitInstrAB('ADD', 'DI', '11');   (* fin du buffer *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0'); (* terminateur *)
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrAB('XOR', 'CX', 'CX');  (* flag signe *)
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNS', '_RXRT_N2S_P');
  EmitInstrA('NEG', 'AX');
  EmitInstrAB('MOV', 'CX', '1');
  EmitLabel('_RXRT_N2S_P');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXRT_N2S_L');
  (* cas special : 0 *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''0''');
  EmitInstrA('DEC', 'DI');
  EmitInstrA('JMP', '_RXRT_N2S_S');
  EmitLabel('_RXRT_N2S_L');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');       (* AX=quotient, DX=reste *)
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXRT_N2S_L');
  EmitLabel('_RXRT_N2S_S');
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', '_RXRT_N2S_D');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''-''');
  EmitInstrA('DEC', 'DI');
  EmitLabel('_RXRT_N2S_D');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'SI', 'DI');  (* SI = debut de la chaine *)
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'AX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_STRTONUM : convertir chaine ASCIIZ en entier signe  *)
  (* Entree : SI = chaine ASCIIZ                               *)
  (* Sortie : AX = valeur entiere                              *)
  EmitLabel('_RXRT_STRTONUM');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX'); (* flag signe *)
  (* sauter les espaces en tete *)
  EmitLabel('_RXRT_S2N_SP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXRT_S2N_SG');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_S2N_SP');
  EmitLabel('_RXRT_S2N_SG');
  (* verifier signe *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''-''');
  EmitInstrA('JNE', '_RXRT_S2N_PL');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_S2N_LP');
  EmitLabel('_RXRT_S2N_PL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '''+''');
  EmitInstrA('JNE', '_RXRT_S2N_LP');
  EmitInstrA('INC', 'SI');
  EmitLabel('_RXRT_S2N_LP');
  EmitInstrAB('MOV', 'BL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'BL', '''0''');
  EmitInstrA('JB', '_RXRT_S2N_DN');
  EmitInstrAB('CMP', 'BL', '''9''');
  EmitInstrA('JA', '_RXRT_S2N_DN');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('MOV', 'DX', 'AX');   (* save AX *)
  EmitInstrAB('SHL', 'AX', '1');    (* AX*2 *)
  EmitInstrAB('SHL', 'AX', '1');    (* AX*4 *)
  EmitInstrAB('ADD', 'AX', 'DX');   (* AX*5 *)
  EmitInstrAB('SHL', 'AX', '1');    (* AX*10 *)
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_S2N_LP');
  EmitLabel('_RXRT_S2N_DN');
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', '_RXRT_S2N_R');
  EmitInstrA('NEG', 'AX');
  EmitLabel('_RXRT_S2N_R');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_CONCAT : concatener deux chaines ASCIIZ             *)
  (* Entree : SI = chaine gauche, DI = chaine droite           *)
  (* Sortie : AX = adresse du resultat dans _RX_CATBUF         *)
  (* Copie SI puis DI dans _RX_CATBUF, terminateur 0           *)
  EmitLabel('_RXRT_CONCAT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'BX', 'OFFSET _RX_CATBUF');
  (* copier chaine gauche *)
  EmitLabel('_RXRT_CAT_L1');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', '_RXRT_CAT_L2');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', '_RXRT_CAT_L1');
  EmitLabel('_RXRT_CAT_L2');
  (* copier chaine droite *)
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitLabel('_RXRT_CAT_L3');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [BX]', 'AL');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', '_RXRT_CAT_DN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', '_RXRT_CAT_L3');
  EmitLabel('_RXRT_CAT_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_CATBUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_STRCMP : comparaison normale de chaines REXX        *)
  (* En REXX, la comparaison normale ignore les espaces en     *)
  (* tete et en queue (leading/trailing) et compare en tenant  *)
  (* compte de la casse. Simplifie ici : comparaison ASCIIZ    *)
  (* avec trim des espaces.                                     *)
  (* Entree : SI = chaine gauche, DI = chaine droite           *)
  (* Sortie : drapeaux (ZF=1 si egal, CF selon ordre)          *)
  (*          AX = -1 si SI<DI, 0 si SI=DI, 1 si SI>DI        *)
  EmitLabel('_RXRT_STRCMP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  (* sauter espaces en tete de SI *)
  EmitLabel('_RXRT_CMP_SL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXRT_CMP_SR');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_CMP_SL');
  EmitLabel('_RXRT_CMP_SR');
  (* sauter espaces en tete de DI *)
  EmitInstrAB('CMP', 'BYTE PTR [DI]', ''' ''');
  EmitInstrA('JNE', '_RXRT_CMP_LP');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_CMP_SR');
  EmitLabel('_RXRT_CMP_LP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'AH', 'BYTE PTR [DI]');
  (* si les deux sont 0, egalite *)
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', '_RXRT_CMP_NZ');
  EmitInstrAB('OR', 'AH', 'AH');
  EmitInstrA('JNZ', '_RXRT_CMP_RS');
  (* les deux sont 0 -> egal *)
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('JMP', '_RXRT_CMP_DN');
  EmitLabel('_RXRT_CMP_NZ');
  (* si AL=espace et AH=0, traiter comme egal (trim trail) *)
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JNE', '_RXRT_CMP_C1');
  EmitInstrAB('OR', 'AH', 'AH');
  EmitInstrA('JNZ', '_RXRT_CMP_C1');
  (* verifier si reste de SI est tout espaces *)
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_CMP_LP');
  EmitLabel('_RXRT_CMP_C1');
  (* si AH=espace et AL=0, traiter comme egal (trim trail) *)
  EmitInstrAB('CMP', 'AH', ''' ''');
  EmitInstrA('JNE', '_RXRT_CMP_C2');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', '_RXRT_CMP_C2');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_CMP_LP');
  EmitLabel('_RXRT_CMP_C2');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JB', '_RXRT_CMP_LT');
  EmitInstrA('JA', '_RXRT_CMP_GT');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_CMP_LP');
  EmitLabel('_RXRT_CMP_RS');
  (* AL=0 mais AH<>0 : verifier si reste DI tout espaces *)
  EmitInstrAB('CMP', 'AH', ''' ''');
  EmitInstrA('JNE', '_RXRT_CMP_LT');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_CMP_LP');
  EmitLabel('_RXRT_CMP_LT');
  EmitInstrAB('MOV', 'AX', '0FFFFh');  (* -1 *)
  EmitInstrA('JMP', '_RXRT_CMP_DN');
  EmitLabel('_RXRT_CMP_GT');
  EmitInstrAB('MOV', 'AX', '1');
  EmitLabel('_RXRT_CMP_DN');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_STRCMPS : comparaison stricte de chaines REXX      *)
  (* La comparaison stricte preserve les espaces (pas de trim) *)
  (* Compare octet par octet sans normalisation.               *)
  (* Entree : SI = chaine gauche, DI = chaine droite           *)
  (* Sortie : AX = -1 / 0 / 1 selon ordre                     *)
  EmitLabel('_RXRT_STRCMPS');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitLabel('_RXRT_SCMP_LP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'AH', 'BYTE PTR [DI]');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JB', '_RXRT_SCMP_LT');
  EmitInstrA('JA', '_RXRT_SCMP_GT');
  (* AL = AH *)
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JZ', '_RXRT_SCMP_EQ');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_SCMP_LP');
  EmitLabel('_RXRT_SCMP_EQ');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrA('JMP', '_RXRT_SCMP_DN');
  EmitLabel('_RXRT_SCMP_LT');
  EmitInstrAB('MOV', 'AX', '0FFFFh');
  EmitInstrA('JMP', '_RXRT_SCMP_DN');
  EmitLabel('_RXRT_SCMP_GT');
  EmitInstrAB('MOV', 'AX', '1');
  EmitLabel('_RXRT_SCMP_DN');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  TODO 12 - Runtime pour entrees/sorties                      *)
  (* ============================================================ *)
  EmitIORuntime;

  (* ============================================================ *)
  (*  TODO 15 - Runtime fonctions integrees (chaines partie 1)    *)
  (* ============================================================ *)
  EmitBifRuntime;

  (* ============================================================ *)
  (*  TODO 18 - Runtime fonctions integrees (partie 2)            *)
  (* ============================================================ *)
  EmitBif2Runtime;

  (* ============================================================ *)
  (*  TODO 16 - Runtime PARSE (decoupage de chaines)              *)
  (* ============================================================ *)
  EmitParseRuntime;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES (SAY / PULL) [IMPLEMENTE]
  ============================================================ }

(* ---- EmitIORuntime : routines runtime pour les E/S REXX ------- *)
(* Emet les routines supplementaires pour SAY, PULL, etc.          *)
Procedure EmitIORuntime;
Begin
  EmitComment('--- Runtime E/S REXX (TODO 12) ---');
  EmitBlankLine;

  (* _RXRT_INPUT : lire une ligne depuis STDIN via INT 21h AH=0Ah *)
  (* Sortie : AX = pointeur vers la chaine ASCIIZ dans _RX_INPUTBF *)
  EmitLabel('_RXRT_INPUT');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrA('PUSH', 'SI');
  (* Initialiser le buffer DOS : octet 0 = max chars *)
  EmitInstrAB('MOV', 'BYTE PTR [_RX_INPUTBF]', '253');
  EmitInstrAB('MOV', 'BYTE PTR [_RX_INPUTBF+1]', '0');
  (* Appel DOS AH=0Ah : lecture tampon *)
  EmitInstrAB('MOV', 'AH', '0Ah');
  EmitInstrAB('LEA', 'DX', '_RX_INPUTBF');
  EmitRaw('        INT     21h');
  (* Null-terminer : _RX_INPUTBF[2 + longueur] = 0 *)
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('MOV', 'BL', 'BYTE PTR [_RX_INPUTBF+1]');
  EmitInstrAB('MOV', 'BYTE PTR [_RX_INPUTBF+BX+2]', '0');
  (* Copier la chaine utile de [_RX_INPUTBF+2] vers _RX_STRBUF *)
  EmitInstrAB('LEA', 'SI', '_RX_INPUTBF');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('LEA', 'DI', '_RX_STRBUF');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  (* Afficher un CR+LF apres la saisie *)
  EmitInstrAB('MOV', 'SI', 'OFFSET _RX_CRLF');
  EmitInstrA('CALL', '_RXRT_PRINT');
  (* Retourner le pointeur vers la copie *)
  EmitInstrAB('LEA', 'AX', '_RX_STRBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitRaw('        RET');
  EmitBlankLine;

  (* _RXRT_PRINTINT : afficher l entier signe dans AX sur STDOUT *)
  (* Convertit via NUMTOSTR puis appelle PRINT                    *)
  EmitLabel('_RXRT_PRINTINT');
  EmitInstrA('CALL', '_RXRT_NUMTOSTR');  (* AX -> SI = chaine *)
  EmitInstrA('CALL', '_RXRT_PRINT');     (* SI -> STDOUT *)
  EmitRaw('        RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 15 - CHAINES DE CARACTERES ET FONCTIONS INTEGREES
            (partie 1) [IMPLEMENTE]
  ============================================================ }

(* ---- EmitBifRuntime : routines runtime fonctions integrees ---- *)
(* Emet les routines assembleur 8086 pour les fonctions integrees   *)
(* de manipulation de chaines REXX (partie 1).                      *)
(* Convention d appel (C) : arguments sur la pile, resultat AX.     *)
(* Apres PUSH BP ; MOV BP,SP :                                     *)
(*   1 arg  : arg1=[BP+4]                                          *)
(*   2 args : arg1=[BP+6], arg2=[BP+4]                             *)
(*   3 args : arg1=[BP+8], arg2=[BP+6], arg3=[BP+4]               *)
(* Les arguments chaine sont des pointeurs ASCIIZ.                  *)
(* Les arguments numeriques (pos, len, n) sont des entiers 16 bits. *)
(* Le resultat chaine est dans _RX_BIFBUF, retourne via AX.        *)
Procedure EmitBifRuntime;
Begin
  EmitComment('--- Runtime BIF chaines (TODO 15) ---');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_LENGTH(str) : longueur de la chaine                    *)
  (*  1 arg : str=[BP+4]                                          *)
  (*  Retour : AX = longueur (entier)                             *)
  (* ============================================================ *)
  EmitLabel('_RXB_LENGTH');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_SUBSTR(str, pos, len)                                  *)
  (*  3 args : str=[BP+8], pos=[BP+6], len=[BP+4]                *)
  (*  len=0 signifie le reste de la chaine                        *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_SUBSTR');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = strlen, DX = pos, BX = len *)
  EmitInstrAB('MOV', 'DX', '[BP+6]');
  EmitInstrAB('MOV', 'BX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  (* Valider pos >= 1 *)
  EmitInstrAB('CMP', 'DX', '1');
  EmitInstrA('JGE', '_RXB_SUBS_POK');
  EmitInstrAB('MOV', 'DX', '1');
  EmitLabel('_RXB_SUBS_POK');
  (* Si pos > strlen, chaine vide *)
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JBE', '_RXB_SUBS_PIR');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('JMP', '_RXB_SUBS_DN');
  EmitLabel('_RXB_SUBS_PIR');
  (* Calculer la longueur effective *)
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JG', '_RXB_SUBS_HL');
  (* len=0 : reste de la chaine *)
  EmitInstrAB('MOV', 'BX', 'CX');
  EmitInstrAB('SUB', 'BX', 'DX');
  EmitInstrA('INC', 'BX');
  EmitLabel('_RXB_SUBS_HL');
  (* Borner : si pos+len-1 > strlen, reduire len *)
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('JBE', '_RXB_SUBS_CP');
  EmitInstrAB('MOV', 'BX', 'CX');
  EmitInstrAB('SUB', 'BX', 'DX');
  EmitInstrA('INC', 'BX');
  EmitLabel('_RXB_SUBS_CP');
  (* Avancer SI a str + pos - 1 *)
  EmitInstrAB('ADD', 'SI', 'DX');
  EmitInstrA('DEC', 'SI');
  (* Copier BX octets *)
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_SUBS_CL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_SUBS_NL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_SUBS_NL');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_SUBS_CL');
  EmitLabel('_RXB_SUBS_NL');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitLabel('_RXB_SUBS_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_LEFT(str, len, pad)                                    *)
  (*  3 args : str=[BP+8], len=[BP+6], pad=[BP+4] (ASCII code)   *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_LEFT');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrAB('MOV', 'CX', '[BP+6]');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitLabel('_RXB_LEFT_CP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_LEFT_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_LEFT_PD');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_LEFT_CP');
  EmitLabel('_RXB_LEFT_PD');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_LEFT_DN');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_LEFT_PD');
  EmitLabel('_RXB_LEFT_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_RIGHT(str, len, pad)                                   *)
  (*  3 args : str=[BP+8], len=[BP+6], pad=[BP+4] (ASCII code)   *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_RIGHT');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = strlen, BX = target len, DL = pad *)
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JAE', '_RXB_RIGHT_NP');
  (* Padding necessaire : BX - CX caracteres de remplissage *)
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('SUB', 'AX', 'CX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitLabel('_RXB_RIGHT_PL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_RIGHT_CC');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_RIGHT_PL');
  EmitLabel('_RXB_RIGHT_CC');
  EmitInstrA('POP', 'CX');
  (* Copier tous les CX octets de str *)
  EmitLabel('_RXB_RIGHT_CL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_RIGHT_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_RIGHT_CL');
  EmitLabel('_RXB_RIGHT_NP');
  (* strlen >= targetLen : copier les derniers BX octets *)
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('SUB', 'AX', 'BX');
  EmitInstrAB('ADD', 'SI', 'AX');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_RIGHT_CF');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_RIGHT_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_RIGHT_CF');
  EmitLabel('_RXB_RIGHT_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_CENTER(str, len, pad)                                  *)
  (*  3 args : str=[BP+8], len=[BP+6], pad=[BP+4] (ASCII code)   *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_CENTER');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = strlen *)
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  (* Si strlen >= width : tronquer au centre *)
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JAE', '_RXB_CTR_TR');
  (* leftPad = (width - strlen) / 2 *)
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrAB('SUB', 'AX', 'CX');
  EmitInstrAB('SHR', 'AX', '1');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrA('POP', 'AX');
  EmitInstrA('PUSH', 'AX');
  EmitInstrAB('MOV', 'CX', 'AX');
  (* Ecrire leftPad *)
  EmitLabel('_RXB_CTR_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_CTR_CS');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_CTR_LP');
  EmitLabel('_RXB_CTR_CS');
  (* Copier strlen octets de str *)
  EmitInstrA('POP', 'AX');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('PUSH', 'AX');
  EmitInstrA('PUSH', 'CX');
  EmitLabel('_RXB_CTR_CC');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_CTR_RP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_CTR_RP');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_CTR_CC');
  EmitLabel('_RXB_CTR_RP');
  (* rightPad = width - leftPad - strlen *)
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'AX');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrAB('SUB', 'BX', 'AX');
  EmitInstrAB('SUB', 'BX', 'CX');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_CTR_RL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', '_RXB_CTR_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_CTR_RL');
  EmitInstrA('JMP', '_RXB_CTR_DN');
  EmitLabel('_RXB_CTR_TR');
  (* strlen >= width : copier les width premiers octets *)
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_CTR_TL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_CTR_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_CTR_TL');
  EmitLabel('_RXB_CTR_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_COPIES(str, n) : repeter str n fois                    *)
  (*  2 args : str=[BP+6], n=[BP+4]                               *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_COPIES');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('MOV', 'BX', '[BP+4]');
  EmitLabel('_RXB_COP_OL');
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JLE', '_RXB_COP_DN');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitLabel('_RXB_COP_IL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_COP_NX');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_COP_IL');
  EmitLabel('_RXB_COP_NX');
  EmitInstrA('DEC', 'BX');
  EmitInstrA('JMP', '_RXB_COP_OL');
  EmitLabel('_RXB_COP_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_REVERSE(str) : inverser la chaine                      *)
  (*  1 arg : str=[BP+4]                                          *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_REVERSE');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = strlen *)
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('MOV', 'BYTE PTR [DI+CX]', '0');
  (* Positionner SI a la fin : SI + CX - 1 *)
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitInstrA('DEC', 'SI');
  EmitLabel('_RXB_REV_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_REV_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('DEC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_REV_LP');
  EmitLabel('_RXB_REV_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_STRIP(str, option, char)                               *)
  (*  3 args : str=[BP+8], option=[BP+6], char=[BP+4] (ASCII)    *)
  (*  option: 66='B'(both), 76='L'(leading), 84='T'(trailing)    *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_STRIP');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = strlen, BX = option, DX = strip char *)
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  (* Strip leading si option = 'L' ou 'B' *)
  EmitInstrAB('CMP', 'BL', '84');
  EmitInstrA('JE', '_RXB_STR_NL');
  EmitLabel('_RXB_STR_LL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_STR_NL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', 'DL');
  EmitInstrA('JNE', '_RXB_STR_NL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_STR_LL');
  EmitLabel('_RXB_STR_NL');
  (* Copier dans _RX_BIFBUF *)
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'SI');
  EmitLabel('_RXB_STR_CY');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_STR_CD');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_STR_CY');
  EmitLabel('_RXB_STR_CD');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'CX');
  (* Strip trailing si option = 'T' ou 'B' *)
  EmitInstrAB('CMP', 'BL', '76');
  EmitInstrA('JE', '_RXB_STR_DN');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('ADD', 'DI', 'CX');
  EmitInstrA('DEC', 'DI');
  EmitLabel('_RXB_STR_TL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_STR_TD');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('JNE', '_RXB_STR_TD');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('DEC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_STR_TL');
  EmitLabel('_RXB_STR_TD');
  EmitLabel('_RXB_STR_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_SPACE(str, n, pad)                                     *)
  (*  3 args : str=[BP+8], n=[BP+6], pad=[BP+4] (ASCII code)     *)
  (*  Normalise les espaces : n espaces entre chaque mot          *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_SPACE');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  (* Sauter les espaces initiaux *)
  EmitLabel('_RXB_SPC_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JNE', '_RXB_SPC_WD');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB_SPC_SK');
  EmitLabel('_RXB_SPC_WD');
  (* Copier un mot (non-espace) *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB_SPC_DN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JE', '_RXB_SPC_SP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_SPC_WD');
  EmitLabel('_RXB_SPC_SP');
  (* Sauter tous les espaces *)
  EmitLabel('_RXB_SPC_S2');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JNE', '_RXB_SPC_IP');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB_SPC_S2');
  EmitLabel('_RXB_SPC_IP');
  (* Si fin de chaine, ne pas ajouter de padding *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB_SPC_DN');
  (* Inserer n caracteres pad *)
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_SPC_PL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_SPC_PD');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_SPC_PL');
  EmitLabel('_RXB_SPC_PD');
  EmitInstrA('POP', 'CX');
  EmitInstrA('JMP', '_RXB_SPC_WD');
  EmitLabel('_RXB_SPC_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_OVERLAY(new, target, pos)                              *)
  (*  3 args : new=[BP+8], target=[BP+6], pos=[BP+4]             *)
  (*  Superpose new sur target a la position pos (1-based)        *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_OVERLAY');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  (* Copier target dans _RX_BIFBUF *)
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  (* Superposer new a pos *)
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('MOV', 'AX', '[BP+4]');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('ADD', 'DI', 'AX');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitLabel('_RXB_OVL_LP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_OVL_DN');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_OVL_LP');
  EmitLabel('_RXB_OVL_DN');
  (* Si on a depasse la fin de target, terminer *)
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JNE', '_RXB_OVL_OK');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitLabel('_RXB_OVL_OK');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_INSERT(new, target, pos)                               *)
  (*  3 args : new=[BP+8], target=[BP+6], pos=[BP+4]             *)
  (*  pos=0 signifie inserer au debut                             *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_INSERT');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('MOV', 'BX', '[BP+4]');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  (* Copier les pos premiers octets de target *)
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_INS_P1');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_INS_NW');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_INS_NW');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_INS_P1');
  EmitLabel('_RXB_INS_NW');
  (* Copier new *)
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitLabel('_RXB_INS_NL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_INS_ND');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_INS_NL');
  EmitLabel('_RXB_INS_ND');
  EmitInstrA('POP', 'SI');
  (* Copier le reste de target *)
  EmitLabel('_RXB_INS_RL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_INS_DN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_INS_RL');
  EmitLabel('_RXB_INS_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_DELSTR(str, pos, len)                                  *)
  (*  3 args : str=[BP+8], pos=[BP+6], len=[BP+4]                *)
  (*  len=0 signifie supprimer jusqu a la fin                     *)
  (*  Retour : AX = OFFSET _RX_BIFBUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_DELSTR');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrAB('LEA', 'DI', '_RX_BIFBUF');
  EmitInstrAB('MOV', 'BX', '[BP+6]');
  EmitInstrA('DEC', 'BX');
  (* Copier les BX premiers octets *)
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_DEL_P1');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_DEL_SK');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_DEL_DN');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_DEL_P1');
  EmitLabel('_RXB_DEL_SK');
  (* Sauter len octets *)
  EmitInstrAB('MOV', 'CX', '[BP+4]');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_DEL_DN');
  EmitLabel('_RXB_DEL_SL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_DEL_RS');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB_DEL_DN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_DEL_SL');
  EmitLabel('_RXB_DEL_RS');
  (* Copier le reste *)
  EmitLabel('_RXB_DEL_RL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB_DEL_DN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB_DEL_RL');
  EmitLabel('_RXB_DEL_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIFBUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_POS(needle, haystack, start)                           *)
  (*  3 args : needle=[BP+8], haystack=[BP+6], start=[BP+4]      *)
  (*  start est 1-based (defaut 1)                                *)
  (*  Retour : AX = position 1-based, 0 si non trouve             *)
  (* ============================================================ *)
  EmitLabel('_RXB_POS');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  (* Longueur du needle *)
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  EmitInstrAB('MOV', 'BX', 'CX');
  (* BX = needle length. Si 0, retourner 0 *)
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', '_RXB_POS_NF');
  (* Longueur du haystack *)
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = haystack length *)
  EmitInstrAB('MOV', 'DX', '[BP+4]');
  EmitInstrA('DEC', 'DX');
  (* DX = start offset (0-based). Avancer dans haystack *)
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('ADD', 'SI', 'DX');
  EmitInstrAB('SUB', 'CX', 'DX');
  EmitInstrA('INC', 'DX');
  (* DX = position courante (1-based) *)
  EmitLabel('_RXB_POS_LP');
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JB', '_RXB_POS_NF');
  (* Comparer BX octets de SI avec needle *)
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'DI', '[BP+8]');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_POS_CM');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_POS_FD');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', '_RXB_POS_NM');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_POS_CM');
  EmitLabel('_RXB_POS_FD');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('JMP', '_RXB_POS_DN');
  EmitLabel('_RXB_POS_NM');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_POS_LP');
  EmitLabel('_RXB_POS_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB_POS_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_LASTPOS(needle, haystack, start)                       *)
  (*  3 args : needle=[BP+8], haystack=[BP+6], start=[BP+4]      *)
  (*  start=0 signifie chercher depuis la fin (defaut)            *)
  (*  Retour : AX = derniere position 1-based, 0 si non trouve    *)
  (* ============================================================ *)
  EmitLabel('_RXB_LASTPOS');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  (* Longueur du needle *)
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  EmitInstrAB('MOV', 'BX', 'CX');
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', '_RXB_LPO_NF');
  (* Longueur du haystack *)
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  (* CX = haystack length *)
  EmitInstrAB('XOR', 'AX', 'AX');
  (* AX = meilleure position trouvee (0 = aucune) *)
  EmitInstrAB('MOV', 'DX', '1');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitLabel('_RXB_LPO_LP');
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JB', '_RXB_LPO_DN');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('MOV', 'DI', '[BP+8]');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB_LPO_CM');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB_LPO_FD');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', '_RXB_LPO_NM');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_LPO_CM');
  EmitLabel('_RXB_LPO_FD');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_LPO_LP');
  EmitLabel('_RXB_LPO_NM');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB_LPO_LP');
  EmitLabel('_RXB_LPO_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB_LPO_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;
End;

(* ---- EmitBif2Runtime : fonctions integrees partie 2 ------------ *)
(* Emet les routines assembleur 8086 pour les fonctions integrees    *)
(* de mots, conversion et fonctions diverses (TODO 18).              *)
Procedure EmitBif2Runtime;
Begin
  EmitComment('--- Runtime BIF partie 2 (TODO 18) ---');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_WORDS(str) : nombre de mots dans la chaine              *)
  (*  1 arg : str=[BP+4]                                           *)
  (*  Retour : AX = nombre de mots                                 *)
  (* ============================================================ *)
  EmitLabel('_RXB_WORDS');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('XOR', 'AX', 'AX');       (* AX = word count *)
  EmitInstrAB('XOR', 'DX', 'DX');       (* DX = in-word flag *)
  EmitLabel('_RXB2_WS_LP');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_WS_DN');
  EmitInstrAB('CMP', 'BL', ''' ''');
  EmitInstrA('JE', '_RXB2_WS_SP');
  (* non-space char *)
  EmitInstrAB('CMP', 'DX', '0');
  EmitInstrA('JNE', '_RXB2_WS_NX');
  EmitInstrA('INC', 'AX');              (* new word *)
  EmitInstrAB('MOV', 'DX', '1');
  EmitInstrA('JMP', '_RXB2_WS_NX');
  EmitLabel('_RXB2_WS_SP');
  EmitInstrAB('XOR', 'DX', 'DX');       (* left word *)
  EmitLabel('_RXB2_WS_NX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WS_LP');
  EmitLabel('_RXB2_WS_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_WORD(str, n) : extraire le n-ieme mot                   *)
  (*  2 args : str=[BP+6], n=[BP+4]                                *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_WORD');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('MOV', 'CX', '[BP+4]');   (* CX = target word # *)
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('XOR', 'DX', 'DX');       (* DX = current word # *)
  (* skip to n-th word *)
  EmitLabel('_RXB2_W_SKP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_W_EMP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_W_FW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_W_SKP');
  EmitLabel('_RXB2_W_FW');
  EmitInstrA('INC', 'DX');               (* found a word *)
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JE', '_RXB2_W_CPY');
  (* skip rest of this word *)
  EmitLabel('_RXB2_W_SRW');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_W_EMP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_W_SKP');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_W_SRW');
  (* copy the word *)
  EmitLabel('_RXB2_W_CPY');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_W_END');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXB2_W_END');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_W_CPY');
  EmitLabel('_RXB2_W_EMP');
  EmitLabel('_RXB2_W_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_WORDINDEX(str, n) : position 1-based du n-ieme mot      *)
  (*  2 args : str=[BP+6], n=[BP+4]                                *)
  (*  Retour : AX = position (1-based), 0 si non trouve            *)
  (* ============================================================ *)
  EmitLabel('_RXB_WORDINDEX');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('MOV', 'CX', '[BP+4]');
  EmitInstrAB('XOR', 'DX', 'DX');       (* word counter *)
  EmitInstrAB('XOR', 'BX', 'BX');       (* position counter *)
  EmitLabel('_RXB2_WI_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WI_NF');
  EmitInstrA('INC', 'BX');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_WI_FW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WI_LP');
  EmitLabel('_RXB2_WI_FW');
  EmitInstrA('INC', 'DX');
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JE', '_RXB2_WI_OK');
  (* skip rest of word *)
  EmitLabel('_RXB2_WI_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WI_NF');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_WI_LP');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', '_RXB2_WI_SK');
  EmitLabel('_RXB2_WI_OK');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstrA('JMP', '_RXB2_WI_DN');
  EmitLabel('_RXB2_WI_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_WI_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_WORDLENGTH(str, n) : longueur du n-ieme mot             *)
  (*  2 args : str=[BP+6], n=[BP+4]                                *)
  (*  Retour : AX = longueur, 0 si non trouve                     *)
  (* ============================================================ *)
  EmitLabel('_RXB_WORDLENGTH');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('MOV', 'CX', '[BP+4]');
  EmitInstrAB('XOR', 'DX', 'DX');
  (* find n-th word *)
  EmitLabel('_RXB2_WL_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WL_NF');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_WL_FW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WL_LP');
  EmitLabel('_RXB2_WL_FW');
  EmitInstrA('INC', 'DX');
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JE', '_RXB2_WL_CT');
  (* skip this word *)
  EmitLabel('_RXB2_WL_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WL_NF');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_WL_LP');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WL_SK');
  (* count length of current word *)
  EmitLabel('_RXB2_WL_CT');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_WL_CL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WL_DN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_WL_DN');
  EmitInstrA('INC', 'AX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WL_CL');
  EmitLabel('_RXB2_WL_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_WL_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_WORDPOS(phrase, str, start) : position du mot            *)
  (*  3 args : phrase=[BP+8], str=[BP+6], start=[BP+4]             *)
  (*  Simplifie : cherche le 1er mot de phrase dans str             *)
  (*  Retour : AX = numero de mot (1-based), 0 si non trouve       *)
  (* ============================================================ *)
  EmitLabel('_RXB_WORDPOS');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  (* Extract first word of phrase into BIF2BUF *)
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitLabel('_RXB2_WP_SS');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_WP_S1');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WP_SS');
  EmitLabel('_RXB2_WP_S1');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitLabel('_RXB2_WP_CW');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_WP_CE');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXB2_WP_CE');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_WP_CW');
  EmitLabel('_RXB2_WP_CE');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  (* Now scan words of str *)
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('XOR', 'DX', 'DX');       (* word counter *)
  EmitLabel('_RXB2_WP_NW');
  (* skip spaces *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WP_NF');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_WP_GW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WP_NW');
  EmitLabel('_RXB2_WP_GW');
  EmitInstrA('INC', 'DX');
  (* Compare this word with BIF2BUF *)
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitLabel('_RXB2_WP_CM');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JNE', '_RXB2_WP_C2');
  (* end of phrase word: check str word also ended *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_WP_FD');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WP_FD');
  EmitInstrA('JMP', '_RXB2_WP_NM');
  EmitLabel('_RXB2_WP_C2');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'AL', 'BL');
  EmitInstrA('JNE', '_RXB2_WP_NM');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_WP_CM');
  EmitLabel('_RXB2_WP_NM');
  EmitInstrA('POP', 'SI');
  (* skip rest of word *)
  EmitLabel('_RXB2_WP_SR');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_WP_NF');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_WP_NW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_WP_SR');
  EmitLabel('_RXB2_WP_FD');
  EmitInstrA('POP', 'SI');             (* balance the push *)
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrA('JMP', '_RXB2_WP_DN');
  EmitLabel('_RXB2_WP_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_WP_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_SUBWORD(str, n, len) : extraire mots n a n+len-1        *)
  (*  3 args : str=[BP+8], n=[BP+6], len=[BP+4]                   *)
  (*  len=0 -> tous les mots restants                              *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_SUBWORD');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrAB('MOV', 'CX', '[BP+6]');   (* n = target word *)
  EmitInstrAB('MOV', 'BX', '[BP+4]');   (* len *)
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('XOR', 'DX', 'DX');       (* word counter *)
  (* skip to word n *)
  EmitLabel('_RXB2_SW_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_SW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_SW_FW');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_SW_SK');
  EmitLabel('_RXB2_SW_FW');
  EmitInstrA('INC', 'DX');
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JGE', '_RXB2_SW_CP');
  (* skip this word *)
  EmitLabel('_RXB2_SW_S2');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_SW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_SW_SK');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_SW_S2');
  (* copy words: BX words or rest if BX=0 *)
  EmitLabel('_RXB2_SW_CP');
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', '_RXB2_SW_AL');
  (* copy BX words *)
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitLabel('_RXB2_SW_CW');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB2_SW_ED');
  (* skip leading spaces between words *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_SW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_SW_CC');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', ''' ''');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_SW_CW');
  EmitLabel('_RXB2_SW_CC');
  (* copy one word *)
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_SW_D2');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXB2_SW_D2');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_SW_CC');
  EmitLabel('_RXB2_SW_D2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB2_SW_CW');
  (* copy all remaining *)
  EmitLabel('_RXB2_SW_AL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_SW_ED');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_SW_AL');
  EmitLabel('_RXB2_SW_ED');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_DELWORD(str, n, len) : supprimer mots n a n+len-1       *)
  (*  3 args : str=[BP+8], n=[BP+6], len=[BP+4]                   *)
  (*  len=0 -> supprimer tous les mots a partir de n               *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_DELWORD');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+8]');
  EmitInstrAB('MOV', 'CX', '[BP+6]');   (* n *)
  EmitInstrAB('MOV', 'BX', '[BP+4]');   (* len *)
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('XOR', 'DX', 'DX');       (* word counter *)
  (* copy words before n *)
  EmitLabel('_RXB2_DW_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_DW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_DW_FW');
  (* space: copy if before word n *)
  EmitInstrAB('MOV', 'AL', ''' ''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_DW_LP');
  EmitLabel('_RXB2_DW_FW');
  EmitInstrA('INC', 'DX');
  EmitInstrAB('CMP', 'DX', 'CX');
  EmitInstrA('JGE', '_RXB2_DW_DL');
  (* copy this word *)
  EmitLabel('_RXB2_DW_CW');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_DW_ED');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXB2_DW_LP');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_DW_CW');
  (* delete phase: skip len words *)
  EmitLabel('_RXB2_DW_DL');
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', '_RXB2_DW_RA');     (* len=0 -> delete all rest *)
  EmitInstrAB('MOV', 'CX', 'BX');       (* CX = words to delete *)
  EmitLabel('_RXB2_DW_DS');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXB2_DW_CR');
  (* skip spaces *)
  EmitLabel('_RXB2_DW_D2');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_DW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JNE', '_RXB2_DW_D3');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_DW_D2');
  EmitLabel('_RXB2_DW_D3');
  (* skip one word *)
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', '_RXB2_DW_ED');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', ''' ''');
  EmitInstrA('JE', '_RXB2_DW_D4');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_DW_D3');
  EmitLabel('_RXB2_DW_D4');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXB2_DW_DS');
  (* copy remaining after deleted section *)
  EmitLabel('_RXB2_DW_CR');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_DW_ED');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXB2_DW_CR');
  EmitLabel('_RXB2_DW_RA');
  (* len=0: delete all remaining, done *)
  EmitLabel('_RXB2_DW_ED');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_C2D(str) : premier caractere -> valeur ASCII            *)
  (*  1 arg : str=[BP+4]                                           *)
  (*  Retour : AX = code ASCII                                     *)
  (* ============================================================ *)
  EmitLabel('_RXB_C2D');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_C2X(str) : premier caractere -> 2 chiffres hex          *)
  (*  1 arg : str=[BP+4]                                           *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_C2X');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  (* high nibble *)
  EmitInstrAB('MOV', 'BL', 'AL');
  EmitInstrAB('SHR', 'BL', '1');
  EmitInstrAB('SHR', 'BL', '1');
  EmitInstrAB('SHR', 'BL', '1');
  EmitInstrAB('SHR', 'BL', '1');
  EmitInstrAB('AND', 'BL', '0Fh');
  EmitInstrAB('CMP', 'BL', '10');
  EmitInstrA('JB', '_RXB2_C2X_D1');
  EmitInstrAB('ADD', 'BL', '''A''');
  EmitInstrAB('SUB', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_C2X_S1');
  EmitLabel('_RXB2_C2X_D1');
  EmitInstrAB('ADD', 'BL', '''0''');
  EmitLabel('_RXB2_C2X_S1');
  EmitInstrAB('MOV', '[DI]', 'BL');
  EmitInstrA('INC', 'DI');
  (* low nibble *)
  EmitInstrAB('MOV', 'BL', 'AL');
  EmitInstrAB('AND', 'BL', '0Fh');
  EmitInstrAB('CMP', 'BL', '10');
  EmitInstrA('JB', '_RXB2_C2X_D2');
  EmitInstrAB('ADD', 'BL', '''A''');
  EmitInstrAB('SUB', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_C2X_S2');
  EmitLabel('_RXB2_C2X_D2');
  EmitInstrAB('ADD', 'BL', '''0''');
  EmitLabel('_RXB2_C2X_S2');
  EmitInstrAB('MOV', '[DI]', 'BL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_D2C(n) : entier -> caractere (1 char string)            *)
  (*  1 arg : n=[BP+4]                                             *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_D2C');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', 'AX', '[BP+4]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_D2X(n) : entier -> chaine hexadecimale                  *)
  (*  1 arg : n=[BP+4]                                             *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_D2X');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'AX', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('ADD', 'DI', '8');         (* write from end *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('MOV', 'BX', '16');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXB2_D2X_LP');
  (* special case: 0 *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''0''');
  EmitInstrA('JMP', '_RXB2_D2X_R');
  EmitLabel('_RXB2_D2X_LP');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('CMP', 'DL', '10');
  EmitInstrA('JB', '_RXB2_D2X_DG');
  EmitInstrAB('ADD', 'DL', '''A''');
  EmitInstrAB('SUB', 'DL', '10');
  EmitInstrA('JMP', '_RXB2_D2X_ST');
  EmitLabel('_RXB2_D2X_DG');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitLabel('_RXB2_D2X_ST');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXB2_D2X_LP');
  EmitInstrA('INC', 'DI');
  EmitLabel('_RXB2_D2X_R');
  (* DI points to start of hex string, copy to front of BIF2BUF *)
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('CMP', 'SI', 'DI');
  EmitInstrA('JE', '_RXB2_D2X_DN');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  EmitLabel('_RXB2_D2X_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_X2C(hex) : 2 chiffres hex -> 1 caractere                *)
  (*  1 arg : hex=[BP+4]                                           *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_X2C');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('XOR', 'AX', 'AX');
  (* high nibble *)
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_X2C_DN');
  EmitInstrAB('CMP', 'BL', '''a''');
  EmitInstrA('JB', '_RXB2_X2C_UA');
  EmitInstrAB('SUB', 'BL', '32');        (* to upper *)
  EmitLabel('_RXB2_X2C_UA');
  EmitInstrAB('CMP', 'BL', '''A''');
  EmitInstrA('JB', '_RXB2_X2C_D1');
  EmitInstrAB('SUB', 'BL', '''A''');
  EmitInstrAB('ADD', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_X2C_H1');
  EmitLabel('_RXB2_X2C_D1');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitLabel('_RXB2_X2C_H1');
  EmitInstrAB('SHL', 'BL', '1');
  EmitInstrAB('SHL', 'BL', '1');
  EmitInstrAB('SHL', 'BL', '1');
  EmitInstrAB('SHL', 'BL', '1');
  EmitInstrAB('MOV', 'AL', 'BL');
  (* low nibble *)
  EmitInstrA('INC', 'SI');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_X2C_DN');
  EmitInstrAB('CMP', 'BL', '''a''');
  EmitInstrA('JB', '_RXB2_X2C_UB');
  EmitInstrAB('SUB', 'BL', '32');
  EmitLabel('_RXB2_X2C_UB');
  EmitInstrAB('CMP', 'BL', '''A''');
  EmitInstrA('JB', '_RXB2_X2C_D2');
  EmitInstrAB('SUB', 'BL', '''A''');
  EmitInstrAB('ADD', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_X2C_H2');
  EmitLabel('_RXB2_X2C_D2');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitLabel('_RXB2_X2C_H2');
  EmitInstrAB('OR', 'AL', 'BL');
  EmitLabel('_RXB2_X2C_DN');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_X2D(hex) : chaine hex -> entier                         *)
  (*  1 arg : hex=[BP+4]                                           *)
  (*  Retour : AX = valeur entiere                                 *)
  (* ============================================================ *)
  EmitLabel('_RXB_X2D');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_X2D_LP');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_X2D_DN');
  EmitInstrAB('CMP', 'BL', '''a''');
  EmitInstrA('JB', '_RXB2_X2D_UA');
  EmitInstrAB('SUB', 'BL', '32');
  EmitLabel('_RXB2_X2D_UA');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('CMP', 'BL', '''A''');
  EmitInstrA('JB', '_RXB2_X2D_DG');
  EmitInstrAB('SUB', 'BL', '''A''');
  EmitInstrAB('ADD', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_X2D_AD');
  EmitLabel('_RXB2_X2D_DG');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitLabel('_RXB2_X2D_AD');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('OR', 'AX', 'BX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_X2D_LP');
  EmitLabel('_RXB2_X2D_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_B2X(bin) : chaine binaire -> chaine hex                  *)
  (*  1 arg : bin=[BP+4]                                           *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_B2X');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  (* First: convert binary string to number in AX *)
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel('_RXB2_B2X_LP');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_B2X_CV');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('CMP', 'BL', '''1''');
  EmitInstrA('JNE', '_RXB2_B2X_NX');
  EmitInstrA('INC', 'AX');
  EmitLabel('_RXB2_B2X_NX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_B2X_LP');
  EmitLabel('_RXB2_B2X_CV');
  (* Now AX has the value, convert to hex like D2X *)
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('ADD', 'DI', '8');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('MOV', 'BX', '16');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXB2_B2X_DL');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''0''');
  EmitInstrA('JMP', '_RXB2_B2X_R');
  EmitLabel('_RXB2_B2X_DL');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');
  EmitInstrAB('CMP', 'DL', '10');
  EmitInstrA('JB', '_RXB2_B2X_D');
  EmitInstrAB('ADD', 'DL', '''A''');
  EmitInstrAB('SUB', 'DL', '10');
  EmitInstrA('JMP', '_RXB2_B2X_S');
  EmitLabel('_RXB2_B2X_D');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitLabel('_RXB2_B2X_S');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', '_RXB2_B2X_DL');
  EmitInstrA('INC', 'DI');
  EmitLabel('_RXB2_B2X_R');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('CMP', 'SI', 'DI');
  EmitInstrA('JE', '_RXB2_B2X_DN');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  EmitLabel('_RXB2_B2X_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_X2B(hex) : chaine hex -> chaine binaire                  *)
  (*  1 arg : hex=[BP+4]                                           *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_X2B');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitLabel('_RXB2_X2B_LP');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('CMP', 'BL', '0');
  EmitInstrA('JE', '_RXB2_X2B_DN');
  (* convert hex char to 4 bits *)
  EmitInstrAB('CMP', 'BL', '''a''');
  EmitInstrA('JB', '_RXB2_X2B_UA');
  EmitInstrAB('SUB', 'BL', '32');
  EmitLabel('_RXB2_X2B_UA');
  EmitInstrAB('CMP', 'BL', '''A''');
  EmitInstrA('JB', '_RXB2_X2B_DG');
  EmitInstrAB('SUB', 'BL', '''A''');
  EmitInstrAB('ADD', 'BL', '10');
  EmitInstrA('JMP', '_RXB2_X2B_CV');
  EmitLabel('_RXB2_X2B_DG');
  EmitInstrAB('SUB', 'BL', '''0''');
  EmitLabel('_RXB2_X2B_CV');
  (* BL = 0..15, emit 4 bits *)
  EmitInstrAB('MOV', 'CX', '4');
  EmitLabel('_RXB2_X2B_BT');
  EmitInstrAB('TEST', 'BL', '8');
  EmitInstrA('JZ', '_RXB2_X2B_B0');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''1''');
  EmitInstrA('JMP', '_RXB2_X2B_BN');
  EmitLabel('_RXB2_X2B_B0');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''0''');
  EmitLabel('_RXB2_X2B_BN');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('SHL', 'BL', '1');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', '_RXB2_X2B_BT');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_X2B_LP');
  EmitLabel('_RXB2_X2B_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_ABS(n) : valeur absolue                                 *)
  (*  1 arg : n=[BP+4] (pointeur chaine)                           *)
  (*  Retour : AX = |n| (entier)                                   *)
  (* ============================================================ *)
  EmitLabel('_RXB_ABS');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNS', '_RXB2_ABS_DN');
  EmitInstrA('NEG', 'AX');
  EmitLabel('_RXB2_ABS_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_SIGN(n) : signe (-1, 0, +1)                            *)
  (*  1 arg : n=[BP+4] (pointeur chaine)                           *)
  (*  Retour : AX = -1, 0 ou 1                                    *)
  (* ============================================================ *)
  EmitLabel('_RXB_SIGN');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JE', '_RXB2_SGN_DN');
  EmitInstrA('JG', '_RXB2_SGN_P');
  EmitInstrAB('MOV', 'AX', '-1');
  EmitInstrA('JMP', '_RXB2_SGN_DN');
  EmitLabel('_RXB2_SGN_P');
  EmitInstrAB('MOV', 'AX', '1');
  EmitLabel('_RXB2_SGN_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_MAX(a, b) : maximum de deux entiers                     *)
  (*  2 args : a=[BP+6], b=[BP+4] (pointeurs chaine)              *)
  (*  Retour : AX = max(a, b)                                     *)
  (* ============================================================ *)
  EmitLabel('_RXB_MAX');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('CMP', 'BX', 'AX');
  EmitInstrA('JLE', '_RXB2_MAX_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitLabel('_RXB2_MAX_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_MIN(a, b) : minimum de deux entiers                     *)
  (*  2 args : a=[BP+6], b=[BP+4] (pointeurs chaine)              *)
  (*  Retour : AX = min(a, b)                                     *)
  (* ============================================================ *)
  EmitLabel('_RXB_MIN');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrAB('CMP', 'BX', 'AX');
  EmitInstrA('JGE', '_RXB2_MIN_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitLabel('_RXB2_MIN_DN');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_TRUNC(n, d) : tronquer (pour d=0 : partie entiere)     *)
  (*  2 args : n=[BP+6] (ptr chaine), d=[BP+4] (entier)           *)
  (*  Retour : AX = partie entiere                                 *)
  (* ============================================================ *)
  EmitLabel('_RXB_TRUNC');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_FORMAT(n) : formater un nombre (simplifie : = TRUNC)    *)
  (*  1 arg : n=[BP+4] (ptr chaine)                                *)
  (*  Retour : AX = entier                                         *)
  (* ============================================================ *)
  EmitLabel('_RXB_FORMAT');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+4]');
  EmitInstrA('CALL', '_RXRT_STRTONUM');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_RANDOM(min, max, seed) : nombre pseudo-aleatoire         *)
  (*  3 args : min=[BP+8], max=[BP+6], seed=[BP+4]                *)
  (*  Retour : AX = nombre entre min et max                        *)
  (* ============================================================ *)
  EmitLabel('_RXB_RANDOM');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DX');
  (* Get timer tick for pseudo-random : INT 1Ah AH=00h *)
  EmitInstrAB('MOV', 'AH', '0');
  EmitRaw('        INT     1Ah');       (* CX:DX = timer ticks *)
  EmitInstrAB('MOV', 'AX', 'DX');       (* use low word *)
  (* AX = pseudo-random, compute AX mod (max-min+1) + min *)
  EmitInstrAB('MOV', 'BX', '[BP+6]');   (* max *)
  EmitInstrAB('SUB', 'BX', '[BP+8]');   (* max - min *)
  EmitInstrA('INC', 'BX');              (* range = max - min + 1 *)
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');              (* DX = AX mod range *)
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrAB('ADD', 'AX', '[BP+8]');   (* AX = remainder + min *)
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_TIME(opt) : heure courante "HH:MM:SS"                   *)
  (*  1 arg : opt=[BP+4] (ignore)                                  *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_TIME');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', 'AH', '2Ch');
  EmitRaw('        INT     21h');       (* CH=hour CL=min DH=sec *)
  (* Write HH *)
  EmitInstrAB('MOV', 'AL', 'CH');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BL', '10');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrA('DIV', 'BL');              (* AL=tens, AH=ones *)
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'AH', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AH');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', ''':''');
  EmitInstrA('INC', 'DI');
  (* Write MM *)
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrAB('MOV', 'AL', 'CL');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrA('PUSH', 'DX');
  EmitInstrAB('MOV', 'BL', '10');
  EmitInstrA('DIV', 'BL');
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'AH', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AH');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', ''':''');
  EmitInstrA('INC', 'DI');
  (* Write SS *)
  EmitInstrA('POP', 'DX');
  EmitInstrAB('MOV', 'AL', 'DH');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'BL', '10');
  EmitInstrA('DIV', 'BL');
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'AH', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AH');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_DATE(opt) : date courante "DD/MM/YYYY"                   *)
  (*  1 arg : opt=[BP+4] (ignore)                                  *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_DATE');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', 'AH', '2Ah');
  EmitRaw('        INT     21h');       (* CX=year DH=month DL=day *)
  EmitInstrA('PUSH', 'CX');             (* save year *)
  (* Write DD *)
  EmitInstrAB('MOV', 'AL', 'DL');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'BL', '10');
  EmitInstrA('DIV', 'BL');
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'AH', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AH');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''/''');
  EmitInstrA('INC', 'DI');
  (* Write MM *)
  EmitInstrAB('MOV', 'AL', 'DH');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'BL', '10');
  EmitInstrA('DIV', 'BL');
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'AH', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AH');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''/''');
  EmitInstrA('INC', 'DI');
  (* Write YYYY : CX = year (e.g. 1993) *)
  EmitInstrA('POP', 'AX');              (* AX = year *)
  EmitInstrAB('MOV', 'BX', '1000');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrA('DIV', 'BX');              (* AX=thousands *)
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'AX', 'DX');       (* remainder 0..999 *)
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrAB('MOV', 'BX', '100');
  EmitInstrA('DIV', 'BX');              (* AX=hundreds, DX=remainder *)
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'AX', 'DX');       (* remainder 0..99 *)
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrA('DIV', 'BX');              (* AX=tens, DX=ones *)
  EmitInstrAB('ADD', 'AL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('ADD', 'DL', '''0''');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_DATATYPE(str, type) : verifier le type de donnees        *)
  (*  2 args : str=[BP+6], type=[BP+4]                             *)
  (*  Simplifie : retourne "NUM" si numerique, "CHAR" sinon        *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_DATATYPE');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', '[BP+6]');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  (* Scan string: check if all chars are digit/sign/dot/space *)
  EmitLabel('_RXB2_DT_LP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXB2_DT_NUM');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXB2_DT_NX');
  EmitInstrAB('CMP', 'AL', '''+''');
  EmitInstrA('JE', '_RXB2_DT_NX');
  EmitInstrAB('CMP', 'AL', '''-''');
  EmitInstrA('JE', '_RXB2_DT_NX');
  EmitInstrAB('CMP', 'AL', '''.''');
  EmitInstrA('JE', '_RXB2_DT_NX');
  EmitInstrAB('CMP', 'AL', '''0''');
  EmitInstrA('JB', '_RXB2_DT_CHR');
  EmitInstrAB('CMP', 'AL', '''9''');
  EmitInstrA('JA', '_RXB2_DT_CHR');
  EmitLabel('_RXB2_DT_NX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXB2_DT_LP');
  EmitLabel('_RXB2_DT_NUM');
  (* Write "NUM" *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''N''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '''U''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+2]', '''M''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+3]', '0');
  EmitInstrA('JMP', '_RXB2_DT_DN');
  EmitLabel('_RXB2_DT_CHR');
  (* Write "CHAR" *)
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''C''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '''H''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+2]', '''A''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+3]', '''R''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+4]', '0');
  EmitLabel('_RXB2_DT_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_SYMBOL(name) : type de symbole (simplifie : "LIT")      *)
  (*  1 arg : name=[BP+4]                                          *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF                            *)
  (* ============================================================ *)
  EmitLabel('_RXB_SYMBOL');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '''L''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+1]', '''I''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+2]', '''T''');
  EmitInstrAB('MOV', 'BYTE PTR [DI+3]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_VALUE(name) : valeur (simplifie : retourne l argument)  *)
  (*  1 arg : name=[BP+4]                                          *)
  (*  Retour : AX = [BP+4]                                        *)
  (* ============================================================ *)
  EmitLabel('_RXB_VALUE');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrAB('MOV', 'AX', '[BP+4]');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXB_ERRORTEXT(n) : texte erreur (simplifie : vide)          *)
  (*  1 arg : n=[BP+4]                                             *)
  (*  Retour : AX = OFFSET _RX_BIF2BUF (chaine vide)              *)
  (* ============================================================ *)
  EmitLabel('_RXB_ERRORTEXT');
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('LEA', 'DI', '_RX_BIF2BUF');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_BIF2BUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'BP');
  EmitRaw('        RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 16 - INSTRUCTION PARSE [IMPLEMENTE]
  ============================================================ }

(* ---- EmitParseRuntime : routines runtime pour PARSE ------------ *)
(* Emet les routines assembleur 8086 pour l instruction PARSE :      *)
(*   _RXRT_PARSEINIT : initialiser la position de decoupage          *)
(*   _RXRT_PARSEWORD : extraire le prochain mot (whitespace delim)   *)
(*   _RXRT_PARSEREST : obtenir le reste de la chaine                 *)
(*   _RXRT_PARSEDELIM : decouper sur un delimiteur litteral          *)
(*   _RXRT_PARSEABS  : se positionner a une colonne absolue          *)
(* Convention : utilise les globaux _RX_PARSESRC / _RX_PARSEPOS.     *)
(* Resultat toujours dans _RX_PARSEBUF, AX = ptr.                   *)
Procedure EmitParseRuntime;
Begin
  EmitComment('--- Runtime PARSE (TODO 16) ---');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXRT_PARSEINIT : initialiser le decoupage                   *)
  (*  Entree : SI = pointeur source ASCIIZ                         *)
  (*  Copie la source vers _RX_TMPBUF et initialise la position.   *)
  (* ============================================================ *)
  EmitLabel('_RXRT_PARSEINIT');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSESRC]', 'OFFSET _RX_TMPBUF');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', '0');
  EmitInstrAB('LEA', 'DI', '_RX_TMPBUF');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  EmitInstrA('POP', 'DI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXRT_PARSEWORD : extraire le prochain mot                   *)
  (*  Saute les espaces, copie le mot dans _RX_PARSEBUF.           *)
  (*  Met a jour _RX_PARSEPOS. AX = ptr _RX_PARSEBUF.             *)
  (* ============================================================ *)
  EmitLabel('_RXRT_PARSEWORD');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  (* Calculer adresse courante dans la source *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('ADD', 'SI', 'WORD PTR [_RX_PARSEPOS]');
  EmitInstrAB('LEA', 'DI', '_RX_PARSEBUF');
  (* Sauter les espaces de tete *)
  EmitLabel('_RXRT_PW_SKIP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PW_END');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JNE', '_RXRT_PW_COPY');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_PW_SKIP');
  (* Copier les caracteres du mot (non-espace, non-nul) *)
  EmitLabel('_RXRT_PW_COPY');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PW_END');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JE', '_RXRT_PW_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_PW_COPY');
  (* Fin : terminer chaine et mettre a jour la position *)
  EmitLabel('_RXRT_PW_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  (* Calculer le nouvel offset *)
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('SUB', 'AX', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', 'AX');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_PARSEBUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXRT_PARSEREST : obtenir le reste de la chaine               *)
  (*  Saute les espaces de tete, copie tout le reste.               *)
  (*  AX = ptr _RX_PARSEBUF.                                       *)
  (* ============================================================ *)
  EmitLabel('_RXRT_PARSEREST');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('ADD', 'SI', 'WORD PTR [_RX_PARSEPOS]');
  EmitInstrAB('LEA', 'DI', '_RX_PARSEBUF');
  (* Sauter les espaces de tete *)
  EmitLabel('_RXRT_PR_SKIP');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PR_END');
  EmitInstrAB('CMP', 'AL', ''' ''');
  EmitInstrA('JNE', '_RXRT_PR_COPY');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_PR_SKIP');
  (* Copier tout le reste *)
  EmitLabel('_RXRT_PR_COPY');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PR_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', '_RXRT_PR_COPY');
  EmitLabel('_RXRT_PR_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  (* Mettre a jour la position a la fin *)
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('SUB', 'AX', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', 'AX');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_PARSEBUF');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXRT_PARSEDELIM : decouper sur un delimiteur litteral        *)
  (*  Entree : DI = pointeur vers chaine delimiteur ASCIIZ         *)
  (*  Copie tout de la position courante jusqu au delimiteur dans   *)
  (*  _RX_PARSEBUF. Avance la position apres le delimiteur.         *)
  (*  Si le delimiteur n est pas trouve, copie tout le reste.       *)
  (*  AX = ptr _RX_PARSEBUF.                                       *)
  (* ============================================================ *)
  EmitLabel('_RXRT_PARSEDELIM');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'BX');
  EmitInstrA('PUSH', 'CX');
  EmitInstrA('PUSH', 'DX');
  (* SI = source + pos courante *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('ADD', 'SI', 'WORD PTR [_RX_PARSEPOS]');
  (* BX = debut de la zone a copier *)
  EmitInstrAB('MOV', 'BX', 'SI');
  (* Calculer la longueur du delimiteur dans CX *)
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrA('CALL', '_RXRT_STRLEN');
  EmitInstrA('POP', 'SI');
  EmitInstrAB('MOV', 'DX', 'CX');
  (* DX = longueur du delimiteur *)
  (* Chercher le delimiteur dans la source *)
  EmitLabel('_RXRT_PD_SCAN');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PD_NFND');
  (* Comparer DX octets *)
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'CX', 'DX');
  EmitLabel('_RXRT_PD_CMPL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXRT_PD_FOUN');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', 'BYTE PTR [DI]');
  EmitInstrA('JNE', '_RXRT_PD_NMAT');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXRT_PD_CMPL');
  (* Match trouve *)
  EmitLabel('_RXRT_PD_FOUN');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  (* Copier de BX a SI-1 dans _RX_PARSEBUF *)
  EmitInstrA('PUSH', 'DI');
  EmitInstrAB('MOV', 'CX', 'SI');
  EmitInstrAB('SUB', 'CX', 'BX');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('LEA', 'DI', '_RX_PARSEBUF');
  EmitLabel('_RXRT_PD_CPF');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', '_RXRT_PD_CPD');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', '_RXRT_PD_CPF');
  EmitLabel('_RXRT_PD_CPD');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  (* Avancer la position apres le delimiteur *)
  EmitInstrAB('ADD', 'SI', 'DX');
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('SUB', 'AX', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', 'AX');
  EmitInstrA('JMP', '_RXRT_PD_DONE');
  (* Pas de match : avancer d un caractere *)
  EmitLabel('_RXRT_PD_NMAT');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', '_RXRT_PD_SCAN');
  (* Delimiteur non trouve : copier tout le reste *)
  EmitLabel('_RXRT_PD_NFND');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'SI');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('LEA', 'DI', '_RX_PARSEBUF');
  EmitInstrA('CALL', '_RXRT_STRCPY');
  EmitInstrA('POP', 'SI');
  EmitInstrA('POP', 'DI');
  (* Position = fin de chaine *)
  EmitInstrAB('MOV', 'AX', 'SI');
  EmitInstrAB('SUB', 'AX', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', 'AX');
  EmitLabel('_RXRT_PD_DONE');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_PARSEBUF');
  EmitInstrA('POP', 'DX');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'BX');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;

  (* ============================================================ *)
  (*  _RXRT_PARSEABS : positionner a une colonne absolue           *)
  (*  Entree : BX = colonne absolue (1-based)                      *)
  (*  Copie de la position courante a colonne BX-1 dans PARSEBUF.  *)
  (*  Si BX > position courante : copie la portion ; sinon vide.   *)
  (*  Met a jour PARSEPOS = BX-1.                                  *)
  (*  AX = ptr _RX_PARSEBUF.                                       *)
  (* ============================================================ *)
  EmitLabel('_RXRT_PARSEABS');
  EmitInstrA('PUSH', 'SI');
  EmitInstrA('PUSH', 'DI');
  EmitInstrA('PUSH', 'CX');
  EmitInstrAB('LEA', 'DI', '_RX_PARSEBUF');
  (* Calculer adresse de debut *)
  EmitInstrAB('MOV', 'SI', 'WORD PTR [_RX_PARSESRC]');
  EmitInstrAB('ADD', 'SI', 'WORD PTR [_RX_PARSEPOS]');
  (* Calculer nombre de caracteres a copier *)
  EmitInstrA('DEC', 'BX');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitInstrAB('SUB', 'CX', 'WORD PTR [_RX_PARSEPOS]');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', '_RXRT_PA_END');
  (* Copier CX caracteres *)
  EmitLabel('_RXRT_PA_COPY');
  EmitInstrAB('MOV', 'AL', 'BYTE PTR [SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', '_RXRT_PA_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JG', '_RXRT_PA_COPY');
  EmitInstrA('JMP', '_RXRT_PA_END');
  (* Position en arriere ou zero : chaine vide *)
  EmitLabel('_RXRT_PA_END');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'WORD PTR [_RX_PARSEPOS]', 'BX');
  EmitInstrAB('MOV', 'AX', 'OFFSET _RX_PARSEBUF');
  EmitInstrA('POP', 'CX');
  EmitInstrA('POP', 'DI');
  EmitInstrA('POP', 'SI');
  EmitRaw('        RET');
  EmitBlankLine;
End;
(* puis la directive END avec le point d entree _RXP_Main.         *)
Procedure EmitClose;
Begin
  If OutFOpen Then
  Begin
    EmitBlankLine;
    EmitComment('--- sortie DOS ---');
    EmitInstrAB('MOV', 'AX', '4C00h');
    EmitRaw('        INT     21h');
    EmitBlankLine;
    EmitRuntime;
    EmitRaw('_TEXT ENDS');
    EmitBlankLine;
    EmitDataSeg;
    EmitBlankLine;
    EmitRaw('END _RXP_Main');
    Close(OutF);
    OutFOpen := False;
  End;
End;

(* ============================================================
   TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
   ============================================================ *)
Function DataAdd(Const Lbl : TString; Kind : TDataKind;
                 AIntVal : LongInt; Const AStrVal : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    FatalError('table de donnees pleine');
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName := Lbl;
  DataTab[DataCount].Kind    := Kind;
  DataTab[DataCount].IntVal  := AIntVal;
  DataTab[DataCount].StrVal  := AStrVal;
  DataTab[DataCount].BufSize := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

Function DataAddStr(Const S : TString) : TString;
Var
  Lbl : TString;
  Seq : TString;
  I   : Integer;
Begin
  (* Deduplication : chercher une chaine existante *)
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := DataTab[I].LblName;
      Exit;
    End;
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := RX_STR_PFX + Seq;
  DataAdd(Lbl, DK_STR, 0, S);
  DataAddStr := Lbl;
End;

(* ---- DataAddWord : ajouter un mot (DW) dans le segment DATA *)
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- DataAddBuffer : ajouter un tampon (DB n DUP(0)) ------- *)
Function DataAddBuffer(Const Lbl : TString; ASize : Integer) : Integer;
Var
  Idx : Integer;
Begin
  Idx := DataAdd(Lbl, DK_BUFFER, 0, '');
  If Idx >= 0 Then
    DataTab[Idx].BufSize := ASize;
  DataAddBuffer := Idx;
End;

(* ---- DataInit : pre-remplir DataTab avec les donnees REXX --- *)
(* Ajoute les constantes et tampons predefinies necessaires au    *)
(* runtime REXX : RC, RESULT, SIGL, CRLF, buffers de travail.    *)
Procedure DataInit;
Begin
  DataCount := 0;
  (* Variables speciales REXX *)
  DataAddWord('_RX_RC', 0);                      (* Return Code         *)
  DataAdd('_RX_RESULT', DK_STR, 0, 'RESULT');    (* RESULT default      *)
  DataAddWord('_RX_SIGL', 0);                     (* SIGL (source line)  *)
  (* Constantes chaines *)
  DataAdd('_RX_CRLF', DK_STR, 0, #13#10);        (* CR+LF               *)
  DataAdd('_RX_NULL_STR', DK_STR, 0, '');         (* chaine vide         *)
  DataAdd('_RX_TRUE_S', DK_STR, 0, '1');          (* chaine "1" (true)   *)
  DataAdd('_RX_FALSE_S', DK_STR, 0, '0');         (* chaine "0" (false)  *)
  DataAdd('_RX_SPC_S', DK_STR, 0, ' ');           (* chaine espace (concat implicite) *)
  (* Tampons de travail *)
  DataAddBuffer('_RX_STRBUF', 256);               (* buffer general      *)
  DataAddBuffer('_RX_TMPBUF', 256);               (* tampon temporaire   *)
  DataAddBuffer('_RX_NUMBUF', 12);                (* conversion numerique *)
  DataAddBuffer('_RX_CATBUF', 256);               (* buffer concatenation *)
  (* TODO 12 - Buffer d entree STDIN *)
  DataAddBuffer('_RX_INPUTBF', 256);              (* buffer entree DOS AH=0Ah *)
  (* TODO 15 - Buffer fonctions integrees *)
  DataAddBuffer('_RX_BIFBUF', 256);               (* buffer fonctions integrees *)
  (* TODO 16 - Buffers pour PARSE *)
  DataAddBuffer('_RX_PARSEBUF', 256);             (* buffer resultat PARSE     *)
  DataAddWord('_RX_PARSEPOS', 0);                  (* position courante PARSE   *)
  DataAddWord('_RX_PARSESRC', 0);                  (* pointeur source PARSE     *)
  (* TODO 17 - Buffer pour RESULT des procedures *)
  DataAddBuffer('_RX_RESBUF', 256);               (* buffer RESULT procedure   *)
  (* TODO 18 - Buffer fonctions integrees partie 2 *)
  DataAddBuffer('_RX_BIF2BUF', 256);              (* buffer BIF partie 2       *)
End;

(* ============================================================
   TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
   ============================================================ *)

(* ---- VarAlloc : allouer une variable REXX --------------------- *)
(* En REXX, toute variable est une chaine. Les variables globales   *)
(* sont allouees comme buffer de 256 octets dans le segment DATA.   *)
(* La valeur par defaut d une variable non initialisee est son nom  *)
(* en majuscules (convention REXX). Les variables locales (dans     *)
(* une PROCEDURE) utilisent la pile [BP-offset].                    *)
(* Retourne l index dans SymTab.                                    *)
Function VarAlloc(Const Name : TString) : Integer;
Var
  U     : TString;
  Idx   : Integer;
  Lbl   : TString;
  DefLbl: TString;
Begin
  U := StrUpperCase(Name);

  (* Chercher si la variable existe deja *)
  Idx := SymFind(U);
  If (Idx >= 0) And (SymTab[Idx].Kind = SK_VAR) Then
  Begin
    VarAlloc := Idx;
    Exit;
  End;

  If CurFnDepth > 0 Then
  Begin
    (* Variable locale : allouer sur la pile [BP-n] *)
    Inc(CurFrameSize, 2);
    Idx := SymAdd(U, SK_VAR, TY_IDX_STRING, -CurFrameSize);
    VarAlloc := Idx;
  End
  Else
  Begin
    (* Variable globale : creer un buffer de 256 octets dans DATA *)
    (* et une constante contenant le nom par defaut                 *)
    Lbl := RX_VAR_PFX + SymNameClean(U);
    DataAddBuffer(Lbl, 256);
    (* Stocker la valeur par defaut (le nom en majuscules) *)
    DefLbl := Lbl + '_D';
    DataAdd(DefLbl, DK_STR, 0, U);
    Idx := SymAdd(U, SK_VAR, TY_IDX_STRING, 0);
    VarAlloc := Idx;
  End;
End;

(* ---- VarAddrOf : retourner l expression d adresse ASM -------- *)
(* Pour une variable globale : OFFSET _RXV_NOM                     *)
(* Pour une variable locale : WORD PTR [BP-offset]                  *)
Function VarAddrOf(Idx : Integer) : TString;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then
  Begin
    VarAddrOf := 'OFFSET _RX_NULL_STR';
    Exit;
  End;
  If SymTab[Idx].Offset < 0 Then
    (* Variable locale sur la pile *)
    VarAddrOf := 'WORD PTR [BP' + IntToStr(SymTab[Idx].Offset) + ']'
  Else
    (* Variable globale dans DATA *)
    VarAddrOf := 'OFFSET ' + SymTab[Idx].MangledName;
End;

(* ---- VarLoad : emettre le code pour charger le ptr var dans AX *)
(* Pour les variables REXX, on charge l adresse du buffer chaine   *)
(* dans AX (pointeur near).                                        *)
Procedure VarLoad(Idx : Integer);
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then
  Begin
    EmitInstr('MOV', 'AX, OFFSET _RX_NULL_STR');
    Exit;
  End;
  If SymTab[Idx].Offset < 0 Then
    (* Variable locale : charger le pointeur depuis la pile *)
    EmitInstr('MOV', 'AX, WORD PTR [BP' +
              IntToStr(SymTab[Idx].Offset) + ']')
  Else
    (* Variable globale : LEA vers le buffer dans DATA *)
    EmitInstr('LEA', 'AX, ' + SymTab[Idx].MangledName);
End;

(* ---- VarStore : emettre le code pour stocker AX dans variable *)
(* AX contient un pointeur vers la chaine source. On copie cette  *)
(* chaine dans le buffer de la variable cible via _RXRT_STRCPY.   *)
Procedure VarStore(Idx : Integer);
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then Exit;

  (* Sauver AX (source) dans SI *)
  EmitInstr('MOV', 'SI, AX');

  If SymTab[Idx].Offset < 0 Then
  Begin
    (* Variable locale : la pile contient un pointeur *)
    EmitInstr('LEA', 'DI, [BP' +
              IntToStr(SymTab[Idx].Offset) + ']');
  End
  Else
  Begin
    (* Variable globale : DI = adresse du buffer *)
    EmitInstr('LEA', 'DI, ' + SymTab[Idx].MangledName);
  End;

  (* Appeler la copie de chaine : SI=source, DI=dest *)
  EmitInstr('CALL', '_RXRT_STRCPY');
End;

(* ---- ParseAssign : parser et executer var = expr --------------- *)
(* En REXX, l affectation est : symbole = expression                *)
(* On evalue l expression, puis on stocke le resultat dans la       *)
(* variable (avec auto-allocation si necessaire).                    *)
Procedure ParseAssign(Const VarName : TString);
Var
  Res : TExprVal;
  Idx : Integer;
Begin
  (* Allouer la variable si elle n existe pas *)
  Idx := VarAlloc(VarName);

  EmitComment('assign: ' + VarName + ' = ...');

  (* = deja consomme par l appelant *)
  (* Evaluer l expression *)
  ParseExpr(Res);
  ExprFlushToAX(Res);

  (* Stocker dans la variable *)
  VarStore(Idx);
End;

(* ---- ParseDrop : parser DROP var1 var2 ... -------------------- *)
(* Reinitialise chaque variable a sa valeur par defaut (son nom en *)
(* majuscules). Syntaxe : DROP var1 var2 ... [;]                    *)
Procedure ParseDrop;
Var
  VarName : TString;
  Idx     : Integer;
  DefLbl  : TString;
Begin
  EmitComment('DROP');

  (* Consommer les variables apres DROP *)
  While (CurToken.Kind = TK_IDENT) Do
  Begin
    VarName := StrUpperCase(CurToken.Val);
    Idx := SymFind(VarName);
    If Idx < 0 Then
      Idx := VarAlloc(VarName);

    (* Copier la valeur par defaut (le nom) dans la variable *)
    If (Idx >= 0) And (SymTab[Idx].Offset >= 0) Then
    Begin
      DefLbl := SymTab[Idx].MangledName + '_D';
      EmitInstr('LEA', 'SI, ' + DefLbl);
      EmitInstr('LEA', 'DI, ' + SymTab[Idx].MangledName);
      EmitInstr('CALL', '_RXRT_STRCPY');
    End
    Else If Idx >= 0 Then
    Begin
      (* Variable locale : remettre pointeur vers nom par defaut *)
      (* On cree la constante nom dans DATA si pas deja fait *)
      DefLbl := DataAddStr(VarName);
      EmitInstr('MOV', 'SI, OFFSET ' + DefLbl);
      EmitInstr('LEA', 'DI, [BP' +
                IntToStr(SymTab[Idx].Offset) + ']');
      EmitInstr('CALL', '_RXRT_STRCPY');
    End;

    ParserAdvance;
  End;
End;

(* ---- ParseUpper : parser UPPER var1 var2 ... ------------------ *)
(* Convertit le contenu de chaque variable en majuscules.           *)
(* Syntaxe : UPPER var1 var2 ... [;]                                *)
Procedure ParseUpper;
Var
  VarName : TString;
  Idx     : Integer;
Begin
  EmitComment('UPPER');

  While (CurToken.Kind = TK_IDENT) Do
  Begin
    VarName := StrUpperCase(CurToken.Val);
    Idx := SymFind(VarName);
    If Idx < 0 Then
      Idx := VarAlloc(VarName);

    If Idx >= 0 Then
    Begin
      VarLoad(Idx);
      EmitInstr('MOV', 'SI, AX');
      EmitInstr('CALL', '_RXRT_UPPER');
    End;

    ParserAdvance;
  End;
End;

(* TODO 10/11 - Expressions *)

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

(* ---- IsBuiltinFunc : verifier si un nom est une BIF connue ----- *)
(* Recherche dans SymTab un symbole de type SK_BUILTIN.              *)
Function IsBuiltinFunc(Const Name : TString) : Boolean;
Var
  U   : TString;
  I   : Integer;
Begin
  U := StrUpperCase(Name);
  IsBuiltinFunc := False;
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].Kind = SK_BUILTIN) And (SymTab[I].Name = U) Then
    Begin
      IsBuiltinFunc := True;
      Exit;
    End;
  End;
End;

(* ---- ParseCallArgs : parser les arguments entre parentheses ----- *)
(* La parenthese ouvrante '(' a deja ete consommee.                   *)
(* Chaque argument est evalue et PUSH-e sur la pile.                  *)
(* Retourne le nombre d arguments.                                    *)
Function ParseCallArgs : Integer;
Var
  ArgCount : Integer;
  Arg      : TExprVal;
Begin
  ArgCount := 0;

  (* Cas sans argument : nom() *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
  Begin
    ParserAdvance;
    ParseCallArgs := 0;
    Exit;
  End;

  (* Premier argument *)
  ParseExpr(Arg);
  ExprFlushToAX(Arg);
  EmitInstr('PUSH', 'AX');
  Inc(ArgCount);

  (* Arguments suivants separes par des virgules *)
  While (CurToken.Kind = TK_COMMA) Do
  Begin
    ParserAdvance;
    (* Argument vide (virgule consecutive) : pousser chaine vide *)
    If (CurToken.Kind = TK_COMMA) Or
       ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    Begin
      EmitInstr('MOV', 'AX, OFFSET _RX_NULL_STR');
      EmitInstr('PUSH', 'AX');
      Inc(ArgCount);
    End
    Else
    Begin
      ParseExpr(Arg);
      ExprFlushToAX(Arg);
      EmitInstr('PUSH', 'AX');
      Inc(ArgCount);
    End;
  End;

  (* Consommer la parenthese fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
    CompileError('parenthese fermante ")" attendue apres arguments');

  ParseCallArgs := ArgCount;
End;

(* ---- ParseFuncCall : parser un appel de fonction integree ------- *)
(* La parenthese ouvrante '(' a deja ete consommee.                   *)
(* Dispatcher vers les routines _RXB_ pour les fonctions connues,     *)
(* ou vers _RXP_ pour les fonctions utilisateur.                      *)
Procedure ParseFuncCall(Const FuncName : TString; Var Res : TExprVal);
Var
  UName    : TString;
  ArgCount : Integer;
  StackAdj : Integer;
Begin
  UName := StrUpperCase(FuncName);
  EmitComment('call: ' + UName + '(...)');

  ArgCount := ParseCallArgs;
  StackAdj := ArgCount * 2;

  (* --- Fonctions de chaines de caracteres --- *)
  If UName = 'LENGTH' Then
  Begin
    EmitInstr('CALL', '_RXB_LENGTH');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'SUBSTR' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_SUBSTR');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'LEFT' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_LEFT');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'RIGHT' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_RIGHT');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'POS' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '1');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_POS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'LASTPOS' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_LASTPOS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'COPIES' Then
  Begin
    EmitInstr('CALL', '_RXB_COPIES');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'REVERSE' Then
  Begin
    EmitInstr('CALL', '_RXB_REVERSE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'STRIP' Then
  Begin
    If ArgCount < 2 Then
    Begin
      EmitInstrAB('MOV', 'AX', '66');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_STRIP');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If (UName = 'CENTER') Or (UName = 'CENTRE') Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_CENTER');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'SPACE' Then
  Begin
    If ArgCount < 2 Then
    Begin
      EmitInstrAB('MOV', 'AX', '1');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '32');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_SPACE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'OVERLAY' Then
  Begin
    EmitInstr('CALL', '_RXB_OVERLAY');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'INSERT' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_INSERT');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'DELSTR' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_DELSTR');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'TRANSLATE' Then
  Begin
    EmitInstr('CALL', '_RXB_TRANSLATE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'VERIFY' Then
  Begin
    EmitInstr('CALL', '_RXB_VERIFY');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'ABBREV' Then
  Begin
    EmitInstr('CALL', '_RXB_ABBREV');
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If UName = 'COMPARE' Then
  Begin
    EmitInstr('CALL', '_RXB_COMPARE');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'CHANGESTR' Then
  Begin
    EmitInstr('CALL', '_RXB_CHANGESTR');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'COUNTSTR' Then
  Begin
    EmitInstr('CALL', '_RXB_COUNTSTR');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'XRANGE' Then
  Begin
    EmitInstr('CALL', '_RXB_XRANGE');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Fonctions de mots --- *)
  Else If UName = 'WORD' Then
  Begin
    EmitInstr('CALL', '_RXB_WORD');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'WORDS' Then
  Begin
    EmitInstr('CALL', '_RXB_WORDS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'WORDINDEX' Then
  Begin
    EmitInstr('CALL', '_RXB_WORDINDEX');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'WORDLENGTH' Then
  Begin
    EmitInstr('CALL', '_RXB_WORDLENGTH');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'WORDPOS' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '1');  (* start=1 par defaut *)
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_WORDPOS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'SUBWORD' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_SUBWORD');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'DELWORD' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_DELWORD');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Fonctions arithmetiques --- *)
  Else If UName = 'ABS' Then
  Begin
    EmitInstr('CALL', '_RXB_ABS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'SIGN' Then
  Begin
    EmitInstr('CALL', '_RXB_SIGN');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'MAX' Then
  Begin
    EmitInstr('CALL', '_RXB_MAX');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'MIN' Then
  Begin
    EmitInstr('CALL', '_RXB_MIN');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'TRUNC' Then
  Begin
    If ArgCount < 2 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_TRUNC');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'FORMAT' Then
  Begin
    EmitInstr('CALL', '_RXB_FORMAT');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'RANDOM' Then
  Begin
    If ArgCount < 3 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    If ArgCount < 2 Then
    Begin
      EmitInstrAB('MOV', 'AX', '999'); (* max=999 par defaut *)
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    If ArgCount < 1 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_RANDOM');
    Res.TypeIdx := TY_IDX_INTEGER;
  End

  (* --- Fonctions de conversion --- *)
  Else If UName = 'C2D' Then
  Begin
    EmitInstr('CALL', '_RXB_C2D');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'C2X' Then
  Begin
    EmitInstr('CALL', '_RXB_C2X');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'D2C' Then
  Begin
    EmitInstr('CALL', '_RXB_D2C');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'D2X' Then
  Begin
    EmitInstr('CALL', '_RXB_D2X');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'X2C' Then
  Begin
    EmitInstr('CALL', '_RXB_X2C');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'X2D' Then
  Begin
    EmitInstr('CALL', '_RXB_X2D');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'B2X' Then
  Begin
    EmitInstr('CALL', '_RXB_B2X');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'X2B' Then
  Begin
    EmitInstr('CALL', '_RXB_X2B');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Fonctions d information --- *)
  Else If UName = 'DATATYPE' Then
  Begin
    If ArgCount < 2 Then
    Begin
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('PUSH', 'AX');
      Inc(StackAdj, 2);
    End;
    EmitInstr('CALL', '_RXB_DATATYPE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'SYMBOL' Then
  Begin
    EmitInstr('CALL', '_RXB_SYMBOL');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'VALUE' Then
  Begin
    EmitInstr('CALL', '_RXB_VALUE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'ARG' Then
  Begin
    EmitInstr('CALL', '_RXB_ARG');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'DIGITS' Then
  Begin
    EmitInstr('CALL', '_RXB_DIGITS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'FORM' Then
  Begin
    EmitInstr('CALL', '_RXB_FORM');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'FUZZ' Then
  Begin
    EmitInstr('CALL', '_RXB_FUZZ');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'SOURCELINE' Then
  Begin
    EmitInstr('CALL', '_RXB_SOURCELINE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'ERRORTEXT' Then
  Begin
    EmitInstr('CALL', '_RXB_ERRORTEXT');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'CONDITION' Then
  Begin
    EmitInstr('CALL', '_RXB_CONDITION');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'DATE' Then
  Begin
    EmitInstr('CALL', '_RXB_DATE');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'TIME' Then
  Begin
    EmitInstr('CALL', '_RXB_TIME');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'QUEUED' Then
  Begin
    EmitInstr('CALL', '_RXB_QUEUED');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'ADDRESS' Then
  Begin
    EmitInstr('CALL', '_RXB_ADDRESS');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'TRACE' Then
  Begin
    EmitInstr('CALL', '_RXB_TRACE');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Fonctions E/S --- *)
  Else If UName = 'LINEIN' Then
  Begin
    EmitInstr('CALL', '_RXB_LINEIN');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'LINEOUT' Then
  Begin
    EmitInstr('CALL', '_RXB_LINEOUT');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'LINES' Then
  Begin
    EmitInstr('CALL', '_RXB_LINES');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'CHARIN' Then
  Begin
    EmitInstr('CALL', '_RXB_CHARIN');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'CHAROUT' Then
  Begin
    EmitInstr('CALL', '_RXB_CHAROUT');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'CHARS' Then
  Begin
    EmitInstr('CALL', '_RXB_CHARS');
    Res.TypeIdx := TY_IDX_INTEGER;
  End
  Else If UName = 'STREAM' Then
  Begin
    EmitInstr('CALL', '_RXB_STREAM');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Logique binaire --- *)
  Else If UName = 'BITAND' Then
  Begin
    EmitInstr('CALL', '_RXB_BITAND');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'BITOR' Then
  Begin
    EmitInstr('CALL', '_RXB_BITOR');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'BITXOR' Then
  Begin
    EmitInstr('CALL', '_RXB_BITXOR');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Divers --- *)
  Else If UName = 'QUALIFY' Then
  Begin
    EmitInstr('CALL', '_RXB_QUALIFY');
    Res.TypeIdx := TY_IDX_STRING;
  End
  Else If UName = 'USERID' Then
  Begin
    EmitInstr('CALL', '_RXB_USERID');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* --- Fonction utilisateur : CALL _RXP_nom --- *)
  Else
  Begin
    EmitInstr('CALL', RX_PROC_PFX + SymNameClean(UName));
    Res.TypeIdx := TY_IDX_STRING;
  End;

  (* Nettoyer la pile des arguments (convention C: appelant) *)
  If StackAdj > 0 Then
    EmitInstr('ADD', 'SP, ' + IntToStr(StackAdj));

  (* Resultat dans AX *)
  Res.Kind   := EK_AX;
  Res.ImmVal := 0;
  Res.Offset := -1;
  Res.SymIdx := -1;

  (* TODO 17 : stocker le resultat dans _RX_RESBUF et RESULT *)
  If Not IsBuiltinFunc(UName) Then
  Begin
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('LEA', 'DI, _RX_RESBUF');
    EmitInstr('CALL', '_RXRT_STRCPY');
    EmitInstr('LEA', 'AX, _RX_RESBUF');
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

(* ---- BinOpPrec : table de precedence des operateurs REXX -- *)
(* Retourne 0 si l operateur n est pas binaire reconnu.        *)
(* Niveaux (plus grand = moins serre / priorite plus basse) :  *)
(*   2 = ** (puissance, priorite la plus haute)                *)
(*   3 = * / % //                                              *)
(*   4 = + - (binaire)                                         *)
(*   5 = || (concatenation explicite)                           *)
(*   6 = = \= > < >= <= == \== >> << >>= <<=  (comparaison)   *)
(*   7 = & (AND)                                               *)
(*   8 = | (OR) && (XOR) (priorite la plus basse)              *)
(* Note : en REXX, = sert a l'affectation SEULEMENT en debut  *)
(* d'instruction (instruction "assignment"). Dans une expression *)
(* = est la comparaison d'egalite.                              *)
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  (* Niveau 2 : puissance *)
  If Op = '**' Then BinOpPrec := 2

  (* Niveau 3 : multiplication, divisions *)
  Else If (Op = '*')  Or (Op = '/')  Or
          (Op = '%')  Or (Op = '//') Then BinOpPrec := 3

  (* Niveau 4 : addition, soustraction *)
  Else If (Op = '+')  Or (Op = '-')  Then BinOpPrec := 4

  (* Niveau 5 : concatenation explicite *)
  Else If Op = '||' Then BinOpPrec := 5

  (* Niveau 6 : comparaisons normales et strictes *)
  Else If (Op = '=')   Or (Op = '\=')  Or
          (Op = '>')   Or (Op = '<')   Or
          (Op = '>=')  Or (Op = '<=')  Or
          (Op = '==')  Or (Op = '\==') Or
          (Op = '>>')  Or (Op = '<<')  Or
          (Op = '>>=') Or (Op = '<<=') Then BinOpPrec := 6

  (* Niveau 7 : AND logique *)
  Else If Op = '&' Then BinOpPrec := 7

  (* Niveau 8 : OR logique, XOR logique *)
  Else If (Op = '|') Or (Op = '&&') Then BinOpPrec := 8

  Else BinOpPrec := 0;
End;

(* ---- BinOpIsRight : associativite droite (** seulement) ---- *)
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**');
End;

(* ---- ExprFlushToAX : charger une valeur dans AX ------------ *)
(* Emet le code necessaire pour que la valeur soit dans AX.     *)
Procedure ExprFlushToAX(Const E : TExprVal);
Begin
  Case E.Kind Of
    EK_IMM :
      EmitInstr('MOV', 'AX, ' + IntToStr(E.ImmVal));
    EK_MEM :
    Begin
      If E.SymIdx >= 0 Then
        EmitInstr('MOV', 'AX, ' + SymTab[E.SymIdx].MangledName)
      Else If E.Offset >= 0 Then
        EmitInstr('LEA', 'AX, ' + DataTab[E.Offset].LblName)
      Else
        EmitInstr('MOV', 'AX, 0');
    End;
    EK_AX :
      ; (* deja dans AX *)
    EK_NONE :
      EmitInstr('XOR', 'AX, AX');
  End;
End;

(* ---- EmitBinOp : emettre le code ASM pour un operateur binaire *)
(* LHS dans AX, RHS dans BX, resultat dans AX.                   *)
Procedure EmitBinOp(Const Op : TString;
                    Var Res : TExprVal; Const Rhs : TExprVal);
Var
  LblSkip, LblDone, LblLoop, LblNeg, LblSkip2 : TString;
Begin
  (* Charger LHS dans AX, sauver sur pile, charger RHS dans AX, *)
  (* puis MOV BX,AX et POP AX pour avoir LHS=AX, RHS=BX        *)
  ExprFlushToAX(Res);
  EmitInstr('PUSH', 'AX');
  ExprFlushToAX(Rhs);
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('POP', 'AX');

  (* Arithmetiques *)
  If Op = '+' Then
    EmitInstr('ADD', 'AX, BX')
  Else If Op = '-' Then
    EmitInstr('SUB', 'AX, BX')
  Else If Op = '*' Then
    EmitInstr('IMUL', 'BX')
  Else If Op = '/' Then
  Begin
    LblSkip := LabelGen;
    LblDone := LabelGen;
    EmitInstr('CMP', 'BX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    EmitRaw('        JMP     ' + LblDone);
    EmitLabel(LblSkip);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblDone);
  End
  Else If Op = '%' Then
  Begin
    (* Division entiere : identique a / en REXX *)
    LblSkip := LabelGen;
    LblDone := LabelGen;
    EmitInstr('CMP', 'BX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    EmitRaw('        JMP     ' + LblDone);
    EmitLabel(LblSkip);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblDone);
  End
  Else If Op = '//' Then
  Begin
    (* Reste de la division *)
    LblSkip := LabelGen;
    LblDone := LabelGen;
    EmitInstr('CMP', 'BX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('CWD', '');
    EmitInstr('IDIV', 'BX');
    EmitInstr('MOV', 'AX, DX');
    EmitRaw('        JMP     ' + LblDone);
    EmitLabel(LblSkip);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblDone);
  End
  Else If Op = '**' Then
  Begin
    (* Puissance : boucle simple pour petits exposants *)
    LblLoop := LabelGen;
    LblNeg  := LabelGen;
    LblDone := LabelGen;
    EmitInstr('MOV', 'CX, BX');      (* CX = exposant *)
    EmitInstr('CMP', 'CX, 0');
    EmitRaw('        JL      ' + LblNeg);
    EmitInstr('MOV', 'BX, AX');      (* BX = base *)
    EmitInstr('MOV', 'AX, 1');       (* accumulateur *)
    EmitLabel(LblLoop);
    EmitInstr('CMP', 'CX, 0');
    EmitRaw('        JE      ' + LblDone);
    EmitInstr('IMUL', 'BX');
    EmitInstr('DEC', 'CX');
    EmitRaw('        JMP     ' + LblLoop);
    EmitLabel(LblNeg);
    EmitInstr('XOR', 'AX, AX');      (* exposant negatif -> 0 *)
    EmitLabel(LblDone);
  End

  (* Concatenation explicite *)
  Else If Op = '||' Then
  Begin
    (* AX=gauche, BX=droite -> SI=gauche, DI=droite -> CALL _RXRT_CONCAT *)
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_CONCAT');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* Concatenation implicite (espace) : gauche + ' ' + droite *)
  Else If Op = ' ' Then
  Begin
    (* AX=gauche, BX=droite *)
    (* D'abord concatener AX + " " *)
    EmitInstr('PUSH', 'BX');
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, OFFSET _RX_SPC_S');
    EmitRaw('        CALL    _RXRT_CONCAT');
    (* Puis concatener le resultat + droite *)
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('POP', 'DI');
    (* Copier le resultat intermediaire dans _RX_TMPBUF *)
    EmitInstr('PUSH', 'DI');
    EmitInstr('MOV', 'DI, OFFSET _RX_TMPBUF');
    EmitRaw('        CALL    _RXRT_STRCPY');
    EmitInstr('MOV', 'SI, OFFSET _RX_TMPBUF');
    EmitInstr('POP', 'DI');
    EmitRaw('        CALL    _RXRT_CONCAT');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* Comparaisons normales : utiliser _RXRT_STRCMP *)
  (* _RXRT_STRCMP(SI=gauche, DI=droite) -> AX = -1/0/1 *)
  Else If Op = '=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '\=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('CMP', 'AX, 1');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('CMP', 'AX, 0FFFFh');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('CMP', 'AX, 0FFFFh');  (* AX = -1 means < *)
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');  (* result = 1 (true: >= ) *)
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMP');
    EmitInstr('CMP', 'AX, 1');  (* AX = 1 means > *)
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');  (* result = 1 (true: <= ) *)
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End

  (* Comparaisons strictes : utiliser _RXRT_STRCMPS *)
  (* _RXRT_STRCMPS(SI=gauche, DI=droite) -> AX = -1/0/1 *)
  Else If Op = '==' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '\==' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('OR', 'AX, AX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>>' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('CMP', 'AX, 1');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<<' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('CMP', 'AX, 0FFFFh');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>>=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('CMP', 'AX, 0FFFFh');  (* AX = -1 means < *)
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<<=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('MOV', 'DI, BX');
    EmitRaw('        CALL    _RXRT_STRCMPS');
    EmitInstr('CMP', 'AX, 1');  (* AX = 1 means > *)
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End

  (* Logiques *)
  Else If Op = '&' Then
  Begin
    (* AND logique : (AX<>0) AND (BX<>0) -> 0 ou 1 *)
    LblSkip := LabelGen;
    EmitInstr('OR', 'AX, AX');
    EmitRaw('        JZ      ' + LblSkip);
    EmitInstr('OR', 'BX, BX');
    EmitRaw('        JZ      ' + LblSkip);
    EmitInstr('MOV', 'AX, 1');
    LblDone := LabelGen;
    EmitRaw('        JMP     ' + LblDone);
    EmitLabel(LblSkip);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblDone);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '|' Then
  Begin
    (* OR logique : (AX<>0) OR (BX<>0) -> 0 ou 1 *)
    LblSkip := LabelGen;
    LblDone := LabelGen;
    EmitInstr('OR', 'AX, AX');
    EmitRaw('        JNZ     ' + LblSkip);
    EmitInstr('OR', 'BX, BX');
    EmitRaw('        JNZ     ' + LblSkip);
    EmitInstr('XOR', 'AX, AX');
    EmitRaw('        JMP     ' + LblDone);
    EmitLabel(LblSkip);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblDone);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '&&' Then
  Begin
    (* XOR logique : (AX<>0) XOR (BX<>0) -> 0 ou 1 *)
    EmitInstr('OR', 'AX, AX');
    LblSkip := LabelGen;
    EmitRaw('        JZ      ' + LblSkip);
    EmitInstr('MOV', 'AX, 1');
    EmitLabel(LblSkip);
    EmitInstr('OR', 'BX, BX');
    LblSkip2 := LabelGen;
    EmitRaw('        JZ      ' + LblSkip2);
    EmitInstr('MOV', 'BX, 1');
    EmitLabel(LblSkip2);
    EmitInstr('XOR', 'AX, BX');
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End

  Else
    WarnMsg('operateur binaire "' + Op + '" non gere par EmitBinOp');

  Res.Kind   := EK_AX;
  Res.SymIdx := -1;
End;

(* ---- ParsePrimary : litteraux, identificateurs, appels fonctions *)
(* Gere : nombres, chaines, identificateurs (variables / builtins), *)
(* appels de fonctions ident(...), parentheses (expr).              *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Idx      : Integer;
  SaveName : TString;
Begin
  ExprMakeNone(Res);

  Case CurToken.Kind Of
    (* Literal numerique *)
    TK_NUMBER :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    (* Literal chaine *)
    TK_STRING :
    Begin
      LitEval(CurToken, Res);
      ParserAdvance;
    End;

    (* Identificateur ou constante predefinie ou appel de fonction *)
    TK_IDENT :
    Begin
      SaveName := CurToken.Val;
      ParserAdvance;

      (* Verifier si c est un appel de fonction : ident( *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance; (* consommer '(' *)
        ParseFuncCall(SaveName, Res);
      End
      Else
      Begin
        (* Pas un appel : chercher comme variable ou constante *)
        Idx := SymFind(SaveName);
        If (Idx >= 0) And (SymTab[Idx].Kind = SK_VAR) Then
        Begin
          (* Variable existante *)
          VarLoad(Idx);
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := SymTab[Idx].TypeIdx;
          Res.Offset  := SymTab[Idx].Offset;
          Res.SymIdx  := Idx;
        End
        Else If (Idx >= 0) And (SymTab[Idx].Kind = SK_BUILTIN) Then
        Begin
          (* Nom de builtin utilise comme variable -> valeur par defaut *)
          (* En REXX, un nom de BIF sans parentheses est traite comme  *)
          (* variable ; sa valeur par defaut est son nom en majuscules *)
          Idx := VarAlloc(SaveName);
          If Idx >= 0 Then
          Begin
            VarLoad(Idx);
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_STRING;
            Res.Offset  := SymTab[Idx].Offset;
            Res.SymIdx  := Idx;
          End
          Else
          Begin
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_STRING;
            Res.SymIdx  := -1;
          End;
        End
        Else
        Begin
          (* Variable inconnue : auto-allouer (convention REXX) *)
          Idx := VarAlloc(SaveName);
          If Idx >= 0 Then
          Begin
            VarLoad(Idx);
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_STRING;
            Res.Offset  := SymTab[Idx].Offset;
            Res.SymIdx  := Idx;
          End
          Else
          Begin
            Res.Kind    := EK_AX;
            Res.ImmVal  := 0;
            Res.TypeIdx := TY_IDX_STRING;
            Res.SymIdx  := -1;
          End;
        End;
      End;
    End;

    (* Parentheses : groupement *)
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance;
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance
        Else
          CompileError('parenthese fermante ")" attendue');
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

(* ---- ParseUnary : operateurs unaires prefixes +, -, \ ----- *)
(* Avec pliage de constantes si l operande est immediat.        *)
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op      : TString;
  LblSkip : TString;
Begin
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '+') Or (Op = '-') Or (Op = '\') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);  (* recursion pour chainer les unaires *)
      (* Pliage de constantes *)
      If Res.Kind = EK_IMM Then
      Begin
        If Op = '-' Then
          Res.ImmVal := -Res.ImmVal
        Else If Op = '+' Then
          (* rien : coerce en nombre *)
        Else If Op = '\' Then
        Begin
          If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
          Res.TypeIdx := TY_IDX_BOOLEAN;
        End;
      End
      Else
      Begin
        (* Non constant : emettre le code *)
        ExprFlushToAX(Res);
        If Op = '-' Then
          EmitInstr('NEG', 'AX')
        Else If Op = '\' Then
        Begin
          EmitInstr('OR', 'AX, AX');
          EmitInstr('MOV', 'AX, 0');
          Res.TypeIdx := TY_IDX_BOOLEAN;
          (* Si AX etait 0 -> mettre 1 ; sinon laisser 0 *)
          LblSkip := LabelGen;
          EmitRaw('        JNZ     ' + LblSkip);
          EmitInstr('INC', 'AX');
          EmitLabel(LblSkip);
        End;
        Res.Kind   := EK_AX;
        Res.SymIdx := -1;
      End;
      Exit;
    End;
  End;
  (* Pas d unaire prefixe : appeler ParsePrimary *)
  ParsePrimary(Res);
End;

(* ---- ParseExprPrec : boucle de montee de precedence (Pratt) *)
(* MinPrec = seuil minimum de precedence (1 pour tout prendre). *)
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
  FoldOk   : Boolean;
  LblSkip  : TString;
  LblDone  : TString;
  PowBase  : LongInt;
  PowExp   : LongInt;
  PowAcc   : LongInt;
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
    (* Concatenation implicite (espace) : si le token suivant est un *)
    (* literal, identifiant, ou '(' sans operateur binaire devant,   *)
    (* traiter comme concatenation avec espace (niveau 5).           *)
    Else If (CurToken.Kind = TK_NUMBER) Or
            (CurToken.Kind = TK_STRING)  Or
            (CurToken.Kind = TK_IDENT)   Or
            ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
    Begin
      Op   := ' ';    (* concatenation implicite *)
      Prec := 5;      (* meme precedence que || *)
    End;
    (* Arreter si fin ou priorite insuffisante *)
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    (* Pour la concatenation implicite (Op=' '), ne pas avancer   *)
    (* le lexeur car il n'y a pas de token operateur a consommer. *)
    If Op <> ' ' Then
      ParserAdvance;

    (* Court-circuit AND : si LHS=0, ne pas evaluer RHS *)
    If Op = '&' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      LblDone := LabelGen;
      EmitInstr('OR', 'AX, AX');
      EmitRaw('        JZ      ' + LblSkip);
      If BinOpIsRight(Op) Then NextPrec := Prec
      Else NextPrec := Prec + 1;
      ParseExprPrec(NextPrec, Right);
      ExprFlushToAX(Right);
      EmitInstr('OR', 'AX, AX');
      EmitRaw('        JZ      ' + LblSkip);
      EmitInstr('MOV', 'AX, 1');
      EmitRaw('        JMP     ' + LblDone);
      EmitLabel(LblSkip);
      EmitInstr('XOR', 'AX, AX');
      EmitLabel(LblDone);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Court-circuit OR : si LHS<>0, ne pas evaluer RHS *)
    If Op = '|' Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      LblDone := LabelGen;
      EmitInstr('OR', 'AX, AX');
      EmitRaw('        JNZ     ' + LblSkip);
      If BinOpIsRight(Op) Then NextPrec := Prec
      Else NextPrec := Prec + 1;
      ParseExprPrec(NextPrec, Right);
      ExprFlushToAX(Right);
      EmitInstr('OR', 'AX, AX');
      EmitRaw('        JNZ     ' + LblSkip);
      EmitInstr('XOR', 'AX, AX');
      EmitRaw('        JMP     ' + LblDone);
      EmitLabel(LblSkip);
      EmitInstr('MOV', 'AX, 1');
      EmitLabel(LblDone);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_BOOLEAN;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Recurser cote droit avec la bonne precedence *)
    If BinOpIsRight(Op) Then NextPrec := Prec
    Else NextPrec := Prec + 1;
    ParseExprPrec(NextPrec, Right);

    (* Pliage de constantes si les deux membres sont immediats *)
    (* Sauf pour la concatenation qui necessite des operations string *)
    FoldOk := (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM)
              And (Op <> '||') And (Op <> ' ');
    If FoldOk Then
    Begin
      If Op = '+' Then
        ExprMakeImm(Res.ImmVal + Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '-' Then
        ExprMakeImm(Res.ImmVal - Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If Op = '*' Then
        ExprMakeImm(Res.ImmVal * Right.ImmVal, TY_IDX_INTEGER, Res)
      Else If (Op = '/') Or (Op = '%') Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(Res.ImmVal Div Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('division par zero');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = '//' Then
      Begin
        If Right.ImmVal <> 0 Then
          ExprMakeImm(Res.ImmVal Mod Right.ImmVal, TY_IDX_INTEGER, Res)
        Else
        Begin
          WarnMsg('reste de division par zero');
          ExprMakeImm(0, TY_IDX_INTEGER, Res);
        End;
      End
      Else If Op = '**' Then
      Begin
        (* Pliage puissance pour petits exposants positifs *)
        If Right.ImmVal < 0 Then
          ExprMakeImm(0, TY_IDX_INTEGER, Res)
        Else
        Begin
          PowBase := Res.ImmVal;
          PowExp  := Right.ImmVal;
          PowAcc  := 1;
          While PowExp > 0 Do
          Begin
            PowAcc := PowAcc * PowBase;
            Dec(PowExp);
          End;
          ExprMakeImm(PowAcc, TY_IDX_INTEGER, Res);
        End;
      End
      (* Comparaisons *)
      Else If Op = '=' Then
        ExprMakeImm(Ord(Res.ImmVal = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '\=' Then
        ExprMakeImm(Ord(Res.ImmVal <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '==' Then
        ExprMakeImm(Ord(Res.ImmVal = Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '\==' Then
        ExprMakeImm(Ord(Res.ImmVal <> Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>'  Then
        ExprMakeImm(Ord(Res.ImmVal > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<'  Then
        ExprMakeImm(Ord(Res.ImmVal < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>=' Then
        ExprMakeImm(Ord(Res.ImmVal >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<=' Then
        ExprMakeImm(Ord(Res.ImmVal <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>>' Then
        ExprMakeImm(Ord(Res.ImmVal > Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<<' Then
        ExprMakeImm(Ord(Res.ImmVal < Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '>>=' Then
        ExprMakeImm(Ord(Res.ImmVal >= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      Else If Op = '<<=' Then
        ExprMakeImm(Ord(Res.ImmVal <= Right.ImmVal), TY_IDX_BOOLEAN, Res)
      (* Logiques *)
      Else If Op = '&' Then
      Begin
        If (Res.ImmVal <> 0) And (Right.ImmVal <> 0) Then
          ExprMakeImm(1, TY_IDX_BOOLEAN, Res)
        Else
          ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else If Op = '|' Then
      Begin
        If (Res.ImmVal <> 0) Or (Right.ImmVal <> 0) Then
          ExprMakeImm(1, TY_IDX_BOOLEAN, Res)
        Else
          ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else If Op = '&&' Then
      Begin
        (* XOR logique *)
        If ((Res.ImmVal <> 0) And (Right.ImmVal = 0)) Or
           ((Res.ImmVal = 0) And (Right.ImmVal <> 0)) Then
          ExprMakeImm(1, TY_IDX_BOOLEAN, Res)
        Else
          ExprMakeImm(0, TY_IDX_BOOLEAN, Res);
      End
      Else
      Begin
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
      End;
    End
    Else
    Begin
      (* Non constant : emettre le code binaire *)
      EmitBinOp(Op, Res, Right);
    End;
  Until False;
End;

(* ---- ParseExpr : point d'entree principal pour les expressions *)
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

(* Stubs parseur *)
Procedure ParserAdvance;
Begin
  LexNextToken;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES : instructions SAY, PULL, PARSE
  [IMPLEMENTE]
  ============================================================ }

(* ---- ParseSayStmt : parser SAY [expr] ----------------------- *)
(* SAY seul : afficher une ligne vide (CR+LF)                     *)
(* SAY expr : evaluer expr, afficher le resultat + CR+LF          *)
Procedure ParseSayStmt;
Var
  Res : TExprVal;
Begin
  EmitComment('SAY');

  (* SAY sans argument : ligne vide *)
  If (CurToken.Kind = TK_EOL) Or (CurToken.Kind = TK_EOF) Then
  Begin
    EmitInstrAB('MOV', 'SI', 'OFFSET _RX_CRLF');
    EmitInstrA('CALL', '_RXRT_PRINT');
    Exit;
  End;

  (* SAY expr : evaluer l expression *)
  ParseExpr(Res);
  ExprFlushToAX(Res);

  (* Si le type est INTEGER ou BOOLEAN : convertir en chaine d abord *)
  If (Res.TypeIdx = TY_IDX_INTEGER) Or
     (Res.TypeIdx = TY_IDX_BOOLEAN) Then
  Begin
    (* AX contient la valeur numerique -> convertir en chaine *)
    EmitInstrA('CALL', '_RXRT_NUMTOSTR');  (* AX -> SI = chaine *)
    EmitInstrA('CALL', '_RXRT_PRINTLN');
  End
  Else
  Begin
    (* AX contient un pointeur vers une chaine ASCIIZ *)
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', '_RXRT_PRINTLN');
  End;
End;

(* ---- ParsePullStmt : parser PULL var1 [var2 ...] ------------- *)
(* Lit une ligne depuis STDIN, convertit en majuscules, stocke     *)
(* dans la variable. Equivalent a PARSE UPPER PULL.                *)
Procedure ParsePullStmt;
Var
  VarName : TString;
  Idx     : Integer;
Begin
  EmitComment('PULL');

  (* Lire une ligne depuis STDIN *)
  EmitInstrA('CALL', '_RXRT_INPUT');  (* AX = ptr vers chaine *)

  (* Convertir en majuscules (PULL = PARSE UPPER PULL) *)
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', '_RXRT_UPPER');

  (* Stocker dans la premiere variable *)
  If CurToken.Kind = TK_IDENT Then
  Begin
    VarName := StrUpperCase(CurToken.Val);
    Idx := VarAlloc(VarName);
    (* AX contient encore le pointeur depuis _RXRT_INPUT *)
    (* qui a ete converti en majuscules par _RXRT_UPPER *)
    EmitInstrAB('LEA', 'AX', '_RX_STRBUF');
    VarStore(Idx);
    ParserAdvance;

    (* Variables supplementaires : pour l instant on ignore *)
    (* (PARSE complet serait TODO 24 - PARSE avance)       *)
    While (CurToken.Kind = TK_IDENT) Do
    Begin
      VarName := StrUpperCase(CurToken.Val);
      Idx := VarAlloc(VarName);
      (* Les variables supplementaires recoivent chaine vide *)
      EmitInstrAB('MOV', 'AX', 'OFFSET _RX_NULL_STR');
      VarStore(Idx);
      ParserAdvance;
    End;
  End;
End;

(* ---- ParseParseStmt : parser PARSE [UPPER] source template ---- *)
(* Gere les sources PULL, ARG, VAR, VALUE, SOURCE, VERSION, LINEIN *)
(* et les templates de decoupage : mots, delimiteur, position.     *)
Procedure ParseParseStmt;
Const
  PT_WORD  = 0;  (* extraction par mots (defaut) *)
  PT_DELIM = 1;  (* decoupage sur delimiteur     *)
  PT_ABS   = 2;  (* position absolue             *)
  PT_REL   = 3;  (* position relative            *)
Var
  DoUpper   : Boolean;
  U         : TString;
  VarName   : TString;
  SrcExpr   : TExprVal;
  SrcLbl    : TString;
  Idx       : Integer;
  I         : Integer;
  VarCount  : Integer;
  VarNames  : Array[0..MAX_PARSE_VARS - 1] Of TString;
  TriggType : Array[0..MAX_PARSE_VARS - 1] Of Integer;
  TriggVal  : Array[0..MAX_PARSE_VARS - 1] Of TString;
  TriggInt  : Array[0..MAX_PARSE_VARS - 1] Of Integer;
  CurTrigI  : Integer;
  DelimLbl  : TString;
Begin
  EmitComment('PARSE');
  DoUpper := False;

  (* Verifier UPPER *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrUpperCase(CurToken.Val) = 'UPPER') Then
  Begin
    DoUpper := True;
    ParserAdvance;
  End;

  If (CurToken.Kind <> TK_KEYWORD) And (CurToken.Kind <> TK_IDENT) Then
  Begin
    WarnMsg('PARSE : mot-cle source attendu (PULL, ARG, VAR, VALUE, etc.)');
    While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    Exit;
  End;

  U := StrUpperCase(CurToken.Val);

  (* ---- PARSE PULL ---- *)
  If U = 'PULL' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE PULL');
    EmitInstrA('CALL', '_RXRT_INPUT');
    EmitInstrAB('MOV', 'SI', 'AX');
    If DoUpper Then
      EmitInstrA('CALL', '_RXRT_UPPER');
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  (* ---- PARSE LINEIN ---- *)
  Else If U = 'LINEIN' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE LINEIN');
    EmitInstrA('CALL', '_RXRT_INPUT');
    EmitInstrAB('MOV', 'SI', 'AX');
    If DoUpper Then
      EmitInstrA('CALL', '_RXRT_UPPER');
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  (* ---- PARSE ARG ---- *)
  Else If U = 'ARG' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE ARG');
    (* En DOS .COM les arguments ne sont pas accessibles facilement *)
    (* On utilise une chaine vide par defaut *)
    EmitInstrAB('MOV', 'SI', 'OFFSET _RX_NULL_STR');
    If DoUpper Then
      EmitInstrA('CALL', '_RXRT_UPPER');
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  (* ---- PARSE VAR nom ---- *)
  Else If U = 'VAR' Then
  Begin
    ParserAdvance;
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('PARSE VAR : nom de variable attendu');
      While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
      Exit;
    End;
    VarName := StrUpperCase(CurToken.Val);
    ParserAdvance;
    EmitComment('PARSE VAR ' + VarName);
    Idx := VarAlloc(VarName);
    VarLoad(Idx);
    EmitInstrAB('MOV', 'SI', 'AX');
    If DoUpper Then
      EmitInstrA('CALL', '_RXRT_UPPER');
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  (* ---- PARSE VALUE expr WITH ---- *)
  Else If U = 'VALUE' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE VALUE ... WITH');
    ParseExpr(SrcExpr);
    ExprFlushToAX(SrcExpr);
    EmitInstrAB('MOV', 'SI', 'AX');
    If DoUpper Then
      EmitInstrA('CALL', '_RXRT_UPPER');
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
    (* Consommer WITH si present *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrUpperCase(CurToken.Val) = 'WITH') Then
      ParserAdvance;
  End
  (* ---- PARSE SOURCE ---- *)
  Else If U = 'SOURCE' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE SOURCE');
    SrcLbl := DataAddStr('DOS COMMAND REXX86');
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + SrcLbl);
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  (* ---- PARSE VERSION ---- *)
  Else If U = 'VERSION' Then
  Begin
    ParserAdvance;
    EmitComment('PARSE VERSION');
    SrcLbl := DataAddStr('REXX86 1.0');
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + SrcLbl);
    EmitInstrA('CALL', '_RXRT_PARSEINIT');
  End
  Else
  Begin
    WarnMsg('PARSE ' + U + ' : source non reconnue');
    ParserAdvance;
    While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    Exit;
  End;

  (* ---- Parser le template ---- *)
  (* Le template est une sequence de :                              *)
  (*   identifiant (variable cible) ou '.' (throwaway)             *)
  (*   chaine litterale (delimiteur entre variables)                *)
  (*   nombre (position absolue entre variables)                    *)
  (*   +nombre ou -nombre (position relative entre variables)       *)
  (* Un trigger (delimiteur/position) entre deux variables indique  *)
  (* comment extraire la portion : il est stocke comme FollowTrig  *)
  (* de la variable qui le precede.                                 *)
  VarCount := 0;
  For I := 0 To MAX_PARSE_VARS - 1 Do
  Begin
    VarNames[I]  := '';
    TriggType[I] := PT_WORD;
    TriggVal[I]  := '';
    TriggInt[I]  := 0;
  End;

  While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) And
        (VarCount < MAX_PARSE_VARS) Do
  Begin
    (* Variable cible ou '.' *)
    If (CurToken.Kind = TK_IDENT) Or
       ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.')) Then
    Begin
      If CurToken.Val = '.' Then
        VarNames[VarCount] := '.'
      Else
        VarNames[VarCount] := StrUpperCase(CurToken.Val);
      TriggType[VarCount] := PT_WORD;  (* defaut : extraction par mot *)
      TriggVal[VarCount]  := '';
      TriggInt[VarCount]  := 0;
      Inc(VarCount);
      ParserAdvance;
    End
    (* Delimiteur litteral : chaine entre quotes *)
    (* Stocke comme FollowTrig de la variable precedente *)
    Else If CurToken.Kind = TK_STRING Then
    Begin
      If VarCount > 0 Then
      Begin
        TriggType[VarCount - 1] := PT_DELIM;
        TriggVal[VarCount - 1]  := CurToken.Val;
      End;
      ParserAdvance;
    End
    (* Position absolue : nombre *)
    Else If CurToken.Kind = TK_NUMBER Then
    Begin
      If VarCount > 0 Then
      Begin
        TriggType[VarCount - 1] := PT_ABS;
        TriggInt[VarCount - 1]  := CurToken.IntVal;
      End;
      ParserAdvance;
    End
    (* Position relative : +nombre ou -nombre *)
    Else If (CurToken.Kind = TK_OP) And
            ((CurToken.Val = '+') Or (CurToken.Val = '-')) Then
    Begin
      CurTrigI := 1;
      If CurToken.Val = '-' Then
        CurTrigI := -1;
      ParserAdvance;
      If CurToken.Kind = TK_NUMBER Then
      Begin
        CurTrigI := CurTrigI * CurToken.IntVal;
        ParserAdvance;
      End;
      If VarCount > 0 Then
      Begin
        TriggType[VarCount - 1] := PT_REL;
        TriggInt[VarCount - 1]  := CurTrigI;
      End;
    End
    Else
    Begin
      (* Token inattendu dans le template : on arrete *)
      Break;
    End;
  End;

  (* ---- Emettre le code de decoupage ---- *)
  If VarCount = 0 Then
  Begin
    (* Pas de variables : rien a faire *)
    Exit;
  End;

  For I := 0 To VarCount - 1 Do
  Begin
    If I = VarCount - 1 Then
    Begin
      (* Derniere variable : prendre le reste de la chaine *)
      EmitInstrA('CALL', '_RXRT_PARSEREST');
    End
    Else
    Begin
      (* Variable intermediaire : methode selon FollowTrig *)
      If TriggType[I] = PT_DELIM Then
      Begin
        (* Extraire tout jusqu au delimiteur *)
        DelimLbl := DataAddStr(TriggVal[I]);
        EmitInstrAB('MOV', 'DI', 'OFFSET ' + DelimLbl);
        EmitInstrA('CALL', '_RXRT_PARSEDELIM');
      End
      Else If TriggType[I] = PT_ABS Then
      Begin
        (* Extraire jusqu a la position absolue *)
        EmitInstrAB('MOV', 'BX', IntToStr(TriggInt[I]));
        EmitInstrA('CALL', '_RXRT_PARSEABS');
      End
      Else If TriggType[I] = PT_REL Then
      Begin
        (* Position relative : extraire portion et avancer position *)
        (* +n = avancer de n caracteres depuis la position courante  *)
        EmitInstrAB('MOV', 'AX', 'WORD PTR [_RX_PARSEPOS]');
        EmitInstrAB('ADD', 'AX', IntToStr(TriggInt[I]));
        EmitInstrA('INC', 'AX');
        EmitInstrAB('MOV', 'BX', 'AX');
        EmitInstrA('CALL', '_RXRT_PARSEABS');
      End
      Else
        (* Extraction par mot (defaut) *)
        EmitInstrA('CALL', '_RXRT_PARSEWORD');
    End;

    (* Stocker le resultat (AX = ptr vers _RX_PARSEBUF) *)
    If VarNames[I] <> '.' Then
    Begin
      Idx := VarAlloc(VarNames[I]);
      VarStore(Idx);
    End;
  End;
End;

{ ============================================================
  TODO 13 - IF / THEN / ELSE / SELECT / WHEN / OTHERWISE
  [IMPLEMENTE]
  ============================================================ }

(* ---- ParseDoBlock : parser un bloc DO ; stmts ; END ---------- *)
(* Dispatcher : apres avoir consomme DO, on regarde le prochain    *)
(* token pour determiner la variante :                              *)
(*   DO WHILE cond -> ParseDoWhile                                  *)
(*   DO UNTIL cond -> ParseDoUntil                                  *)
(*   DO FOREVER    -> ParseDoForever                                *)
(*   DO var = ...  -> ParseDoCount                                  *)
(*   DO expr       -> ParseDoExpr (repeter N fois)                  *)
(*   DO ; stmts ; END -> bloc simple (pas de boucle)                *)
Procedure ParseDoBlock;
Var
  U        : TString;
  SaveName : TString;
Begin
  (* Sauter les fins de ligne apres DO *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  If CurToken.Kind = TK_EOF Then Exit;

  (* Verifier les mots-cles specifiques *)
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    U := StrUpperCase(CurToken.Val);

    (* DO WHILE cond *)
    If U = 'WHILE' Then
    Begin
      ParserAdvance;  (* consommer WHILE *)
      ParseDoWhile;
      Exit;
    End;

    (* DO UNTIL cond *)
    If U = 'UNTIL' Then
    Begin
      ParserAdvance;  (* consommer UNTIL *)
      ParseDoUntil;
      Exit;
    End;

    (* DO FOREVER *)
    If U = 'FOREVER' Then
    Begin
      ParserAdvance;  (* consommer FOREVER *)
      ParseDoForever;
      Exit;
    End;

    (* DO END = bloc vide *)
    If U = 'END' Then
    Begin
      ParserAdvance;  (* consommer END *)
      EmitComment('DO block (vide)');
      Exit;
    End;
  End;

  (* DO ident = debut TO fin [BY pas] : boucle compteur *)
  If CurToken.Kind = TK_IDENT Then
  Begin
    SaveName := CurToken.Val;
    ParserAdvance;

    (* Verifier si c est une affectation ident = ... *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      ParserAdvance;  (* consommer = *)
      ParseDoCount(SaveName);
      Exit;
    End;

    (* Pas un compteur : c est peut-etre DO expr *)
    (* On a deja consomme l ident, il faudrait revenir en arriere *)
    (* On ne peut pas, donc on traite comme un bloc simple *)
    (* Le token courant n est pas END, on parse comme bloc *)
    EmitComment('DO block');
    (* On a consomme un token de trop - on doit parser le reste *)
    (* Comme on ne peut pas faire de look-back, on traite       *)
    (* l identifiant comme debut du corps du bloc                *)
    While (CurToken.Kind <> TK_EOF) Do
    Begin
      While CurToken.Kind = TK_EOL Do
        ParserAdvance;
      If CurToken.Kind = TK_EOF Then Break;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrUpperCase(CurToken.Val) = 'END') Then
      Begin
        ParserAdvance;
        Exit;
      End;
      ParseStmt;
    End;
    Exit;
  End;

  (* DO expr : repeter N fois *)
  If (CurToken.Kind = TK_NUMBER) Or
     (CurToken.Kind = TK_STRING) Or
     (CurToken.Kind = TK_PUNCT) Then
  Begin
    ParseDoExpr;
    Exit;
  End;

  (* Bloc simple DO ; stmts ; END *)
  EmitComment('DO block');
  ParseDoBodyUntilEnd;
End;

(* ---- ParseIfStmt : parser IF cond THEN instr [ELSE instr] ---- *)
(* IF condition THEN instruction [; ELSE instruction]              *)
(* Si THEN est suivi de DO, c est un bloc DO/END.                  *)
Procedure ParseIfStmt;
Var
  Res      : TExprVal;
  LblElse  : TString;
  LblEndif : TString;
Begin
  EmitComment('IF');

  (* Evaluer la condition *)
  ParseExpr(Res);
  ExprFlushToAX(Res);

  LblElse  := LabelGen;
  LblEndif := LabelGen;

  (* TEST AX,AX / JZ lbl_else *)
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitRaw('        JZ      ' + LblElse);

  (* Consommer THEN (obligatoire) *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;
  If (CurToken.Kind = TK_KEYWORD) And
     (StrUpperCase(CurToken.Val) = 'THEN') Then
    ParserAdvance
  Else
    WarnMsg('THEN attendu apres condition IF');

  (* Sauter les fins de ligne apres THEN *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Branche THEN : instruction ou bloc DO/END *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrUpperCase(CurToken.Val) = 'DO') Then
  Begin
    ParserAdvance;  (* consommer DO *)
    ParseDoBlock;
  End
  Else If (CurToken.Kind = TK_KEYWORD) And
          (StrUpperCase(CurToken.Val) = 'NOP') Then
  Begin
    EmitComment('NOP');
    ParserAdvance;
  End
  Else
    ParseStmt;

  (* Sauter les fins de ligne *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Verifier ELSE *)
  If (CurToken.Kind = TK_KEYWORD) And
     (StrUpperCase(CurToken.Val) = 'ELSE') Then
  Begin
    ParserAdvance;  (* consommer ELSE *)
    EmitRaw('        JMP     ' + LblEndif);
    EmitLabel(LblElse);

    (* Sauter les fins de ligne apres ELSE *)
    While CurToken.Kind = TK_EOL Do
      ParserAdvance;

    (* Branche ELSE : instruction ou bloc DO/END *)
    If (CurToken.Kind = TK_KEYWORD) And
       (StrUpperCase(CurToken.Val) = 'DO') Then
    Begin
      ParserAdvance;
      ParseDoBlock;
    End
    Else If (CurToken.Kind = TK_KEYWORD) And
            (StrUpperCase(CurToken.Val) = 'NOP') Then
    Begin
      EmitComment('NOP');
      ParserAdvance;
    End
    Else
      ParseStmt;

    EmitLabel(LblEndif);
  End
  Else
  Begin
    (* Pas de ELSE : lbl_else = point de sortie *)
    EmitLabel(LblElse);
  End;
End;

(* ---- ParseSelectStmt : parser SELECT / WHEN / OTHERWISE / END *)
(* SELECT                                                          *)
(*   WHEN cond1 THEN instr1                                       *)
(*   WHEN cond2 THEN instr2                                       *)
(*   OTHERWISE instr_defaut                                        *)
(* END                                                             *)
Procedure ParseSelectStmt;
Var
  Res      : TExprVal;
  U        : TString;
  LblNext  : TString;
  LblEnd   : TString;
Begin
  EmitComment('SELECT');
  LblEnd   := LabelGen;

  (* Boucle sur les clauses WHEN / OTHERWISE *)
  While CurToken.Kind <> TK_EOF Do
  Begin
    (* Sauter les fins de ligne *)
    While CurToken.Kind = TK_EOL Do
      ParserAdvance;
    If CurToken.Kind = TK_EOF Then Break;

    If CurToken.Kind <> TK_KEYWORD Then Break;
    U := StrUpperCase(CurToken.Val);

    (* END du SELECT *)
    If U = 'END' Then
    Begin
      ParserAdvance;
      Break;
    End;

    (* WHEN cond THEN instr *)
    If U = 'WHEN' Then
    Begin
      ParserAdvance;  (* consommer WHEN *)
      EmitComment('WHEN');

      (* Evaluer la condition *)
      ParseExpr(Res);
      ExprFlushToAX(Res);

      LblNext := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitRaw('        JZ      ' + LblNext);

      (* Consommer THEN *)
      While CurToken.Kind = TK_EOL Do
        ParserAdvance;
      If (CurToken.Kind = TK_KEYWORD) And
         (StrUpperCase(CurToken.Val) = 'THEN') Then
        ParserAdvance
      Else
        WarnMsg('THEN attendu apres condition WHEN');

      (* Sauter les fins de ligne apres THEN *)
      While CurToken.Kind = TK_EOL Do
        ParserAdvance;

      (* Instruction ou bloc DO/END *)
      If (CurToken.Kind = TK_KEYWORD) And
         (StrUpperCase(CurToken.Val) = 'DO') Then
      Begin
        ParserAdvance;
        ParseDoBlock;
      End
      Else If (CurToken.Kind = TK_KEYWORD) And
              (StrUpperCase(CurToken.Val) = 'NOP') Then
      Begin
        EmitComment('NOP');
        ParserAdvance;
      End
      Else
        ParseStmt;

      (* Sauter au END du SELECT *)
      EmitRaw('        JMP     ' + LblEnd);
      EmitLabel(LblNext);
    End

    (* OTHERWISE instr *)
    Else If U = 'OTHERWISE' Then
    Begin
      ParserAdvance;  (* consommer OTHERWISE *)
      EmitComment('OTHERWISE');

      (* Sauter les fins de ligne *)
      While CurToken.Kind = TK_EOL Do
        ParserAdvance;

      (* Instructions jusqu au END *)
      While CurToken.Kind <> TK_EOF Do
      Begin
        While CurToken.Kind = TK_EOL Do
          ParserAdvance;
        If CurToken.Kind = TK_EOF Then Break;
        If (CurToken.Kind = TK_KEYWORD) And
           (StrUpperCase(CurToken.Val) = 'END') Then
        Begin
          ParserAdvance;
          Break;
        End;
        ParseStmt;
      End;
      Break;  (* Sortir de la boucle WHEN *)
    End

    Else
    Begin
      (* Token inattendu dans SELECT *)
      WarnMsg('WHEN ou OTHERWISE attendu dans SELECT');
      ParserAdvance;
    End;
  End;

  EmitLabel(LblEnd);
End;

{ ============================================================
  TODO 14 - BOUCLES DO / END [IMPLEMENTE]
  ============================================================ }

(* ---- LoopPush : empiler les labels LEAVE/ITERATE ------------- *)
(* BreakLbl = label pour LEAVE, ContLbl = label pour ITERATE       *)
Procedure LoopPush(Const BreakLbl, ContLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('boucles imbriquees trop profondes');
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BreakLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  Inc(LoopTop);
End;

(* ---- LoopPop : depiler les labels LEAVE/ITERATE -------------- *)
Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

(* ---- ParseDoBodyUntilEnd : parser instructions jusqu a END ----- *)
(* Corps commun a toutes les boucles DO. Parse des instructions      *)
(* jusqu a rencontrer END ou EOF.                                     *)
Procedure ParseDoBodyUntilEnd;
Var
  U : TString;
Begin
  While CurToken.Kind <> TK_EOF Do
  Begin
    (* Sauter les fins de ligne *)
    While CurToken.Kind = TK_EOL Do
      ParserAdvance;
    If CurToken.Kind = TK_EOF Then Break;

    (* Verifier END *)
    If (CurToken.Kind = TK_KEYWORD) Then
    Begin
      U := StrUpperCase(CurToken.Val);
      If U = 'END' Then
      Begin
        ParserAdvance;  (* consommer END *)
        Exit;
      End;
    End;

    (* Parser l instruction suivante *)
    ParseStmt;
  End;
End;

(* ---- ParseDoWhile : DO WHILE cond ; stmts ; END -------------- *)
(* Structure :                                                       *)
(*   _RXL_test:                                                      *)
(*     <eval cond>                                                   *)
(*     TEST AX,AX                                                    *)
(*     JZ   _RXL_end                                                 *)
(*     <stmts>                                                       *)
(*     JMP  _RXL_test                                                *)
(*   _RXL_end:                                                       *)
Procedure ParseDoWhile;
Var
  Res     : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('DO WHILE');

  LblTest := LabelGen;
  LblEnd  := LabelGen;

  (* Empiler pour LEAVE/ITERATE *)
  LoopPush(LblEnd, LblTest);

  (* Label de test *)
  EmitLabel(LblTest);

  (* Evaluer la condition *)
  ParseExpr(Res);
  ExprFlushToAX(Res);

  (* Si faux -> sortie *)
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitRaw('        JZ      ' + LblEnd);

  (* Sauter EOL apres condition *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Corps de la boucle *)
  ParseDoBodyUntilEnd;

  (* Retour au test *)
  EmitRaw('        JMP     ' + LblTest);

  (* Label de sortie *)
  EmitLabel(LblEnd);

  LoopPop;
End;

(* ---- ParseDoUntil : DO UNTIL cond ; stmts ; END -------------- *)
(* Structure :                                                       *)
(*   _RXL_beg:                                                       *)
(*     <stmts>                                                       *)
(*     <eval cond>                                                   *)
(*     TEST AX,AX                                                    *)
(*     JZ   _RXL_beg                                                 *)
(*   _RXL_end:                                                       *)
(* La condition est testee APRES le corps (au moins 1 execution).    *)
(* Strategie : on parse et emet la condition AVANT le corps, on      *)
(* utilise un JMP pour sauter le test au premier tour, puis on       *)
(* re-tombe dans le test a chaque iteration suivante.                *)
(*   JMP _RXL_body                                                   *)
(*   _RXL_test:                                                      *)
(*     <eval cond>                                                   *)
(*     TEST AX,AX                                                    *)
(*     JNZ  _RXL_end         (si UNTIL vrai -> sortir)               *)
(*   _RXL_body:                                                      *)
(*     <stmts>                                                       *)
(*     JMP _RXL_test                                                 *)
(*   _RXL_end:                                                       *)
Procedure ParseDoUntil;
Var
  Res     : TExprVal;
  LblTest : TString;
  LblBody : TString;
  LblEnd  : TString;
Begin
  EmitComment('DO UNTIL');

  LblTest := LabelGen;
  LblBody := LabelGen;
  LblEnd  := LabelGen;

  (* Empiler pour LEAVE/ITERATE *)
  LoopPush(LblEnd, LblTest);

  (* Sauter le test au premier tour (execute au moins une fois) *)
  EmitRaw('        JMP     ' + LblBody);

  (* Label de test de la condition UNTIL *)
  EmitLabel(LblTest);

  (* Evaluer la condition UNTIL *)
  ParseExpr(Res);
  ExprFlushToAX(Res);

  (* Si condition UNTIL vraie -> sortir *)
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitRaw('        JNZ     ' + LblEnd);

  (* Label du corps *)
  EmitLabel(LblBody);

  (* Sauter les EOL *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Corps de la boucle *)
  ParseDoBodyUntilEnd;

  (* Retour au test *)
  EmitRaw('        JMP     ' + LblTest);

  EmitLabel(LblEnd);

  LoopPop;
End;

(* ---- ParseDoForever : DO FOREVER ; stmts ; END --------------- *)
(* Boucle infinie, sortie uniquement par LEAVE.                    *)
(*   _RXL_beg:                                                     *)
(*     <stmts>                                                     *)
(*     JMP _RXL_beg                                                *)
(*   _RXL_end:                                                     *)
Procedure ParseDoForever;
Var
  LblBeg : TString;
  LblEnd : TString;
Begin
  EmitComment('DO FOREVER');

  LblBeg := LabelGen;
  LblEnd := LabelGen;

  (* Empiler pour LEAVE/ITERATE *)
  LoopPush(LblEnd, LblBeg);

  EmitLabel(LblBeg);

  (* Sauter EOL apres FOREVER *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Corps de la boucle *)
  ParseDoBodyUntilEnd;

  (* Retour au debut *)
  EmitRaw('        JMP     ' + LblBeg);

  EmitLabel(LblEnd);

  LoopPop;
End;

(* ---- ParseDoCount : DO var = debut TO fin [BY pas] ----------- *)
(* Boucle compteur classique.                                       *)
(*   <var> = <debut>                                                *)
(*   _RXL_test:                                                     *)
(*     CMP <var>, <fin>                                             *)
(*     JG  _RXL_end          (ou JL si pas negatif)                 *)
(*     <stmts>                                                      *)
(*   _RXL_incr:                                                     *)
(*     ADD <var>, <pas>                                             *)
(*     JMP _RXL_test                                                *)
(*   _RXL_end:                                                      *)
(* VarName est le nom de la variable de boucle, deja parse.         *)
Procedure ParseDoCount(Const VarName : TString);
Var
  VarIdx     : Integer;
  Res        : TExprVal;
  LblTest    : TString;
  LblIncr    : TString;
  LblEnd     : TString;
  HasBy      : Boolean;
  LblFinVar  : TString;
  LblStepVar : TString;
Begin
  EmitComment('DO ' + VarName + ' = ... TO ... [BY ...]');

  (* Allouer la variable de boucle *)
  VarIdx := VarAlloc(VarName);

  (* Evaluer l expression de debut *)
  ParseExpr(Res);
  ExprFlushToAX(Res);
  (* Convertir en nombre et stocker dans la variable *)
  EmitInstr('CALL', '_RXRT_NUMTOSTR');
  VarStore(VarIdx);

  (* Consommer TO *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;
  If (CurToken.Kind = TK_KEYWORD) And (StrUpperCase(CurToken.Val) = 'TO') Then
    ParserAdvance
  Else
    CompileError('TO attendu dans DO compteur');

  (* Evaluer l expression de fin *)
  ParseExpr(Res);
  ExprFlushToAX(Res);
  (* Sauver la limite dans une variable temporaire DATA *)
  LblFinVar := LabelGen + '_FIN';
  DataAddBuffer(LblFinVar, 256);
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('LEA', 'DI, ' + LblFinVar);
  EmitInstr('CALL', '_RXRT_STRCPY');

  (* Verifier BY *)
  HasBy := False;
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;
  If (CurToken.Kind = TK_KEYWORD) And (StrUpperCase(CurToken.Val) = 'BY') Then
  Begin
    ParserAdvance;
    HasBy := True;
    (* Evaluer l expression de pas *)
    ParseExpr(Res);
    ExprFlushToAX(Res);
    (* Sauver le pas dans une variable temporaire DATA *)
    LblStepVar := LabelGen + '_STEP';
    DataAddBuffer(LblStepVar, 256);
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('LEA', 'DI, ' + LblStepVar);
    EmitInstr('CALL', '_RXRT_STRCPY');
  End;

  (* Generer les labels *)
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;

  (* Empiler pour LEAVE/ITERATE *)
  LoopPush(LblEnd, LblIncr);

  (* Label de test *)
  EmitLabel(LblTest);

  (* Charger la variable de boucle et la convertir en nombre *)
  VarLoad(VarIdx);
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('CALL', '_RXRT_STRTONUM');
  EmitInstr('PUSH', 'AX');

  (* Charger la limite et convertir *)
  EmitInstr('LEA', 'SI, ' + LblFinVar);
  EmitInstr('CALL', '_RXRT_STRTONUM');
  EmitInstr('MOV', 'BX, AX');
  EmitInstr('POP', 'AX');

  (* Comparer : AX = var, BX = fin *)
  EmitInstrAB('CMP', 'AX', 'BX');
  (* Si pas positif : JG end. Si pas negatif : JL end *)
  If HasBy Then
  Begin
    (* Pas dynamique : on assume positif par defaut *)
    (* Pour un pas negatif, le test est inverse       *)
    EmitRaw('        JG      ' + LblEnd);
  End
  Else
    EmitRaw('        JG      ' + LblEnd);

  (* Sauter EOL *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Corps de la boucle *)
  ParseDoBodyUntilEnd;

  (* Label d increment *)
  EmitLabel(LblIncr);

  (* Incrementer la variable de boucle *)
  VarLoad(VarIdx);
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('CALL', '_RXRT_STRTONUM');
  If HasBy Then
  Begin
    (* Charger le pas *)
    EmitInstr('PUSH', 'AX');
    EmitInstr('LEA', 'SI, ' + LblStepVar);
    EmitInstr('CALL', '_RXRT_STRTONUM');
    EmitInstr('MOV', 'BX, AX');
    EmitInstr('POP', 'AX');
    EmitInstrAB('ADD', 'AX', 'BX');
  End
  Else
    EmitInstr('INC', 'AX');

  (* Reconvertir en chaine et stocker *)
  EmitInstr('CALL', '_RXRT_NUMTOSTR');
  VarStore(VarIdx);

  (* Retour au test *)
  EmitRaw('        JMP     ' + LblTest);

  EmitLabel(LblEnd);

  LoopPop;
End;

(* ---- ParseDoExpr : DO expr ; stmts ; END --------------------- *)
(* Repeter le bloc expr fois.                                       *)
(*   <eval expr -> CX>                                              *)
(*   _RXL_test:                                                     *)
(*     CMP CX, 0                                                    *)
(*     JLE _RXL_end                                                 *)
(*     PUSH CX                                                      *)
(*     <stmts>                                                      *)
(*     POP CX                                                       *)
(*     DEC CX                                                       *)
(*     JMP _RXL_test                                                *)
(*   _RXL_end:                                                      *)
Procedure ParseDoExpr;
Var
  Res     : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
  CountLbl: TString;
Begin
  EmitComment('DO expr (repeat N times)');

  (* Evaluer l expression de comptage *)
  ParseExpr(Res);
  ExprFlushToAX(Res);
  (* Convertir en nombre si c est une chaine *)
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('CALL', '_RXRT_STRTONUM');

  (* Stocker le compteur dans une variable temporaire DATA *)
  CountLbl := LabelGen + '_CNT';
  DataAddWord(CountLbl, 0);
  EmitInstr('MOV', 'WORD PTR ' + CountLbl + ', AX');

  LblTest := LabelGen;
  LblEnd  := LabelGen;

  LoopPush(LblEnd, LblTest);

  EmitLabel(LblTest);

  (* Tester le compteur *)
  EmitInstr('MOV', 'AX, WORD PTR ' + CountLbl);
  EmitInstrAB('CMP', 'AX', '0');
  EmitRaw('        JLE     ' + LblEnd);

  (* Sauter EOL *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Corps de la boucle *)
  ParseDoBodyUntilEnd;

  (* Decrementer le compteur *)
  EmitInstr('DEC', 'WORD PTR ' + CountLbl);
  EmitRaw('        JMP     ' + LblTest);

  EmitLabel(LblEnd);

  LoopPop;
End;

{ ============================================================
  TODO 17 - PROCEDURES ET FONCTIONS INTERNES [IMPLEMENTE]
  ============================================================ }

(* ---- ParseCallStmt : parser CALL nom [arg1, arg2, ...] ------- *)
(* CALL invoque une procedure interne definie par un label.         *)
(* Arguments : evalues et empiles de droite a gauche (convention C) *)
(* La valeur de retour (AX) est stockee dans _RX_RESBUF et la      *)
(* variable speciale RESULT pointe dessus.                          *)
Procedure ParseCallStmt;
Var
  ProcName : TString;
  UName    : TString;
  ArgCount : Integer;
  Res      : TExprVal;
  StackAdj : Integer;
  I        : Integer;
Begin
  (* Sauter les EOL *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  (* Lire le nom de la procedure *)
  If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
  Begin
    CompileError('nom de procedure attendu apres CALL');
    Exit;
  End;
  ProcName := CurToken.Val;
  UName := StrUpperCase(ProcName);
  ParserAdvance;

  EmitComment('CALL ' + UName);

  (* Compter et empiler les arguments *)
  ArgCount := 0;
  While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
  Begin
    If ArgCount >= MAX_PARAM Then
    Begin
      CompileError('trop d''arguments pour CALL');
      Exit;
    End;
    ParseExpr(Res);
    ExprFlushToAX(Res);
    EmitInstrA('PUSH', 'AX');
    Inc(ArgCount);
    (* Consommer virgule optionnelle *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;

  StackAdj := ArgCount * 2;

  (* Verifier si c est une fonction integree connue *)
  If IsBuiltinFunc(UName) Then
  Begin
    (* Dispatcher vers la fonction integree via ParseFuncCall *)
    (* On a deja empile les args, il suffit d appeler la routine *)
    EmitInstr('CALL', RX_BLT_PFX + SymNameClean(UName));
  End
  Else
  Begin
    (* Appel de procedure utilisateur *)
    EmitInstr('CALL', RX_PROC_PFX + SymNameClean(UName));
  End;

  (* Nettoyer la pile des arguments *)
  If StackAdj > 0 Then
    EmitInstr('ADD', 'SP, ' + IntToStr(StackAdj));

  (* Stocker la valeur de retour (AX) dans _RX_RESBUF *)
  EmitInstr('MOV', 'SI, AX');
  EmitInstr('LEA', 'DI, _RX_RESBUF');
  EmitInstr('CALL', '_RXRT_STRCPY');

  (* Mettre a jour la variable RESULT pour pointer sur _RX_RESBUF *)
  I := VarAlloc('RESULT');
  EmitInstr('LEA', 'AX, _RX_RESBUF');
  VarStore(I);
End;

(* ---- ParseSignalStmt : parser SIGNAL nom ---------------------- *)
(* SIGNAL effectue un saut inconditionnel vers un label.            *)
(* Pas de retour : equivalent a un GOTO.                            *)
Procedure ParseSignalStmt;
Var
  LblName : TString;
  UName   : TString;
Begin
  (* Sauter les EOL *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
  Begin
    CompileError('nom de label attendu apres SIGNAL');
    Exit;
  End;

  LblName := CurToken.Val;
  UName := StrUpperCase(LblName);
  ParserAdvance;

  EmitComment('SIGNAL ' + UName);

  (* Mettre a jour SIGL avec le numero de ligne courant *)
  EmitInstr('MOV', 'WORD PTR _RX_SIGL, ' + IntToStr(CurToken.Line));

  (* Saut inconditionnel vers le label *)
  EmitRaw('        JMP     ' + RX_PROC_PFX + SymNameClean(UName));
End;

(* ---- ParseProcKeyword : parser PROCEDURE [EXPOSE var1 var2 ...] *)
(* PROCEDURE definit une portee locale pour les variables.           *)
(* EXPOSE liste les variables du scope parent accessibles ici.       *)
(* Doit etre le premier mot apres un label : label: PROCEDURE        *)
Procedure ParseProcKeyword;
Var
  VarName : TString;
  Idx     : Integer;
Begin
  EmitComment('PROCEDURE');

  (* Entrer dans un nouveau scope *)
  Inc(CurFnDepth);
  CurFnRetLbl := LabelGen;
  CurFnName   := '';  (* sera mis a jour par l appelant *)
  CurFrameSize := 0;

  SymEnterScope;

  (* Verifier s il y a EXPOSE *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  If (CurToken.Kind = TK_KEYWORD) And
     (StrUpperCase(CurToken.Val) = 'EXPOSE') Then
  Begin
    ParserAdvance;
    EmitComment('EXPOSE');

    (* Lire la liste de variables exposees (identifiants jusqu a fin de ligne) *)
    While (CurToken.Kind = TK_IDENT) And
          (CurToken.Kind <> TK_EOL) And
          (CurToken.Kind <> TK_EOF) Do
    Begin
      VarName := StrUpperCase(CurToken.Val);
      ParserAdvance;

      (* Chercher la variable dans le scope parent (global) *)
      Idx := SymFind(VarName);
      If Idx < 0 Then
      Begin
        (* La variable n existe pas encore au niveau global, la creer *)
        Idx := VarAlloc(VarName);
      End;

      (* Marquer la variable comme exposee pour l acces direct *)
      If Idx >= 0 Then
        SymTab[Idx].IsExposed := True;
    End;
  End;

  (* Emettre le prologue de la procedure *)
  EmitProlog;
End;

(* Gere les mots-cles, les affectations et les expressions comme  *)
(* instructions.                                                   *)
Procedure ParseStmt;
Var
  U        : TString;
  SaveName : TString;
  Res      : TExprVal;
Begin
  (* Sauter les fins de ligne / points-virgules *)
  While CurToken.Kind = TK_EOL Do
    ParserAdvance;

  If CurToken.Kind = TK_EOF Then Exit;

  (* --- Labels : point d entree pour CALL/SIGNAL (TODO 17) --- *)
  If CurToken.Kind = TK_LABEL Then
  Begin
    SaveName := StrUpperCase(CurToken.Val);
    EmitLabel(RX_PROC_PFX + SymNameClean(SaveName));
    ParserAdvance;

    (* Verifier si le label est suivi de PROCEDURE *)
    While CurToken.Kind = TK_EOL Do
      ParserAdvance;

    If (CurToken.Kind = TK_KEYWORD) And
       (StrUpperCase(CurToken.Val) = 'PROCEDURE') Then
    Begin
      (* PROCEDURE : gere le scope, le prologue et CurFnDepth *)
      ParserAdvance;
      CurFnName := SaveName;
      ParseProcKeyword;
    End
    Else
    Begin
      (* Label simple sans PROCEDURE : marquer comme callable *)
      Inc(CurFnDepth);
      CurFnRetLbl := LabelGen;
      CurFnName   := SaveName;
    End;
    Exit;
  End;

  (* --- Mots-cles REXX --- *)
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    U := StrUpperCase(CurToken.Val);

    (* SAY [expr] *)
    If U = 'SAY' Then
    Begin
      ParserAdvance;
      ParseSayStmt;
      Exit;
    End;

    (* CALL nom [arg1, arg2, ...] (TODO 17) *)
    If U = 'CALL' Then
    Begin
      ParserAdvance;
      ParseCallStmt;
      Exit;
    End;

    (* SIGNAL nom (TODO 17) *)
    If U = 'SIGNAL' Then
    Begin
      ParserAdvance;
      ParseSignalStmt;
      Exit;
    End;

    (* PULL var1 [var2 ...] *)
    If U = 'PULL' Then
    Begin
      ParserAdvance;
      ParsePullStmt;
      Exit;
    End;

    (* PARSE [UPPER] PULL|ARG|VAR|VALUE|SOURCE|VERSION|LINEIN *)
    If U = 'PARSE' Then
    Begin
      ParserAdvance;
      ParseParseStmt;
      Exit;
    End;

    (* IF cond THEN instr [ELSE instr] *)
    If U = 'IF' Then
    Begin
      ParserAdvance;
      ParseIfStmt;
      Exit;
    End;

    (* SELECT / WHEN / OTHERWISE / END *)
    If U = 'SELECT' Then
    Begin
      ParserAdvance;
      ParseSelectStmt;
      Exit;
    End;

    (* DO ... END (bloc, boucle, compteur via ParseDoBlock) *)
    If U = 'DO' Then
    Begin
      ParserAdvance;
      ParseDoBlock;
      Exit;
    End;

    (* LEAVE [nom] : sortir de la boucle courante *)
    If U = 'LEAVE' Then
    Begin
      ParserAdvance;
      EmitComment('LEAVE');
      If LoopTop > 0 Then
        EmitRaw('        JMP     ' + LoopBreakLbl[LoopTop - 1])
      Else
        CompileError('LEAVE en dehors d''une boucle DO');
      Exit;
    End;

    (* ITERATE [nom] : passer a l iteration suivante *)
    If U = 'ITERATE' Then
    Begin
      ParserAdvance;
      EmitComment('ITERATE');
      If LoopTop > 0 Then
        EmitRaw('        JMP     ' + LoopContLbl[LoopTop - 1])
      Else
        CompileError('ITERATE en dehors d''une boucle DO');
      Exit;
    End;

    (* NOP *)
    If U = 'NOP' Then
    Begin
      EmitComment('NOP');
      ParserAdvance;
      Exit;
    End;

    (* EXIT [expr] *)
    If U = 'EXIT' Then
    Begin
      ParserAdvance;
      EmitComment('EXIT');
      If (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Then
      Begin
        ParseExpr(Res);
        ExprFlushToAX(Res);
        EmitInstrAB('MOV', 'AH', '4Ch');
        EmitRaw('        INT     21h');
      End
      Else
      Begin
        EmitInstrAB('MOV', 'AX', '4C00h');
        EmitRaw('        INT     21h');
      End;
      Exit;
    End;

    (* DROP var1 var2 ... *)
    If U = 'DROP' Then
    Begin
      ParserAdvance;
      ParseDrop;
      Exit;
    End;

    (* UPPER var1 var2 ... *)
    If U = 'UPPER' Then
    Begin
      ParserAdvance;
      ParseUpper;
      Exit;
    End;

    (* RETURN [expr] *)
    If U = 'RETURN' Then
    Begin
      ParserAdvance;
      EmitComment('RETURN');
      If (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Then
      Begin
        ParseExpr(Res);
        ExprFlushToAX(Res);
      End
      Else
      Begin
        (* RETURN sans valeur : retourner chaine vide *)
        EmitInstr('LEA', 'AX, _RX_NULL_STR');
      End;

      (* Si dans une procedure/label appele : emettre epilogue et RET *)
      If CurFnDepth > 0 Then
      Begin
        EmitLabel(CurFnRetLbl);
        If CurScope > 0 Then
        Begin
          (* PROCEDURE : epilogue complet (POP BP + RET) *)
          EmitEpilog;
          SymLeaveScope;
        End
        Else
        Begin
          (* Label simple sans PROCEDURE : juste RET *)
          EmitRaw('        RET');
        End;
        Dec(CurFnDepth);
        CurFrameSize := 0;
        CurFnRetLbl  := '';
        CurFnName    := '';
      End
      Else
      Begin
        (* RETURN au niveau global : equivalent a EXIT *)
        EmitRaw('        JMP     _RXP_Exit');
      End;
      Exit;
    End;

    (* PROCEDURE [EXPOSE ...] : peut apparaitre sans label (rare) *)
    If U = 'PROCEDURE' Then
    Begin
      ParserAdvance;
      ParseProcKeyword;
      Exit;
    End;

    (* Mots-cles non encore geres : sauter *)
    WarnMsg('mot-cle "' + U + '" non encore gere (TODO futur)');
    ParserAdvance;
    While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    Exit;
  End;

  (* --- Identificateur : affectation ou expression --- *)
  If CurToken.Kind = TK_IDENT Then
  Begin
    SaveName := CurToken.Val;
    ParserAdvance;

    (* Verifier si c est une affectation : ident = expr *)
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      ParserAdvance;  (* consommer = *)
      ParseAssign(SaveName);
      Exit;
    End;

    (* Pas une affectation : reculer n est pas possible, *)
    (* traiter comme expression standalone.               *)
    (* On doit simuler : on a deja avance le premier ident *)
    (* Verifier si c est un appel de fonction : ident( *)
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance; (* consommer '(' *)
      ParseFuncCall(SaveName, Res);
      (* Ignorer le resultat : appel comme instruction *)
      Exit;
    End;

    (* C est un identifiant seul sur la ligne, ou suivi d autres tokens *)
    (* En REXX strict, c est une erreur ou une commande externe *)
    (* On ignore silencieusement pour l instant *)
    While (CurToken.Kind <> TK_EOL) And (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    Exit;
  End;

  (* --- Autre token (nombre, chaine, etc.) : avancer --- *)
  ParserAdvance;
End;

{ ============================================================
  Run : pipeline complet de compilation
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then ShowBanner;

  TypeInit;
  SymInit;
  DataInit;
  EmitOpen;
  If ErrorCount > 0 Then Exit;

  EmitHeader;
  LexInit;

  (* Boucle principale de compilation *)
  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;

  (* Epilogue : saut vers sortie propre *)
  EmitRaw('        JMP     _RXP_Exit');
  EmitBlankLine;

  EmitRuntime;
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
    WriteLn('  Avertissements : ', WarnCount);
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }

Begin
  If (ParamCount >= 1) And
     ((ParamStr(1) = '-h') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '/?') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowUsage;
  End;
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  InitOptions;
  ParseArgs;
  Run;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
