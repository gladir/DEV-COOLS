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

  TODO 09 - VARIABLES ET AFFECTATIONS
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

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal nombre, literal chaine, ident, appel fonction
            Nombre : convertir en chaine (ou garder en registre si optimise)
            Chaine : charger adresse du literal dans SI
            Variable : charger adresse de la valeur dans SI
            Appel de fonction : nom(args) -> CALL + resultat dans AX
            Parentheses : (expr) -> evaluation recursive
            Prefixe unaire : + (NOP), - (NEG si numerique), \ (NOT logique)
            Fonctions integrees : SUBSTR, LENGTH, etc. -> CALL _RXB_nom
            Variable composee (stem) : nom.queue -> calcul dynamique de cle

  TODO 11 - EXPRESSIONS BINAIRES ET CONCATENATION
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

  TODO 12 - ENTREES/SORTIES (SAY / PULL / LINEIN / LINEOUT / CHAROUT)
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

  TODO 13 - IF / THEN / ELSE / SELECT / WHEN / OTHERWISE
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

  TODO 14 - BOUCLES DO / END
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

  TODO 15 - CHAINES DE CARACTERES ET FONCTIONS INTEGREES (partie 1)
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

  TODO 16 - INSTRUCTION PARSE
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

  TODO 17 - PROCEDURES ET FONCTIONS INTERNES
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

  TODO 18 - FONCTIONS INTEGREES (partie 2 : mots, conversion, divers)
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

(* TODO 10 - Expressions *)
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal);    Forward;

(* TODO 09 - Variables *)
Procedure ExprFlushToAX(Const E : TExprVal); Forward;

(* Autres stubs *)
Procedure ParseStmt;           Forward;
Procedure ParserAdvance;       Forward;

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
    (* Passer les lignes vides / fin de fichier *)
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

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
End;

(* ---- EmitClose : fermer le fichier de sortie ASM ------------- *)
(* Emet la sortie DOS, le runtime, ferme _TEXT, ecrit _DATA,      *)
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
  (* Tampons de travail *)
  DataAddBuffer('_RX_STRBUF', 256);               (* buffer general      *)
  DataAddBuffer('_RX_TMPBUF', 256);               (* tampon temporaire   *)
  DataAddBuffer('_RX_NUMBUF', 12);                (* conversion numerique *)
End;

(* TODO 10/11 - Expressions *)
(* ParsePrimary reel dans TODO 04 ci-dessous *)

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
    EmitComment('concatenation || : stub, appel _RXRT_CONCAT requis');
    EmitRaw('        CALL    _RXRT_CONCAT');
    Res.TypeIdx := TY_IDX_STRING;
  End

  (* Comparaisons normales *)
  Else If Op = '=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '\=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JLE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JGE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JL      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<=' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JG      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End

  (* Comparaisons strictes *)
  Else If Op = '==' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JNE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '\==' Then
  Begin
    LblSkip := LabelGen;
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JE      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>>' Then
  Begin
    LblSkip := LabelGen;
    EmitComment('strict >> : meme code que >');
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JLE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<<' Then
  Begin
    LblSkip := LabelGen;
    EmitComment('strict << : meme code que <');
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JGE     ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '>>=' Then
  Begin
    LblSkip := LabelGen;
    EmitComment('strict >>= : meme code que >=');
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JL      ' + LblSkip);
    EmitInstr('INC', 'AX');
    EmitLabel(LblSkip);
    Res.TypeIdx := TY_IDX_BOOLEAN;
  End
  Else If Op = '<<=' Then
  Begin
    LblSkip := LabelGen;
    EmitComment('strict <<= : meme code que <=');
    EmitInstr('CMP', 'AX, BX');
    EmitInstr('MOV', 'AX, 0');
    EmitRaw('        JG      ' + LblSkip);
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

(* ---- ParsePrimary : litteraux, identificateurs, parentheses *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Idx : Integer;
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

    (* Identificateur ou constante predefinie *)
    TK_IDENT :
    Begin
      Idx := SymFind(CurToken.Val);
      If Idx >= 0 Then
      Begin
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := SymTab[Idx].TypeIdx;
        Res.Offset  := SymTab[Idx].Offset;
        Res.SymIdx  := Idx;
      End
      Else
      Begin
        (* Tenter evaluation comme constante predefinie *)
        LitEval(CurToken, Res);
        If Res.Kind = EK_NONE Then
        Begin
          (* Variable inconnue : stub TODO 09 *)
          Res.Kind    := EK_AX;
          Res.ImmVal  := 0;
          Res.TypeIdx := TY_IDX_STRING;
          Res.SymIdx  := -1;
        End;
      End;
      ParserAdvance;
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
    End;
    (* Arreter si fin ou priorite insuffisante *)
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

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
    FoldOk := (Res.Kind = EK_IMM) And (Right.Kind = EK_IMM);
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
      Else If Op = '||' Then
      Begin
        (* Concatenation constante : stub, garder LHS *)
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_STRING;
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

Procedure ParseStmt;
Begin
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
