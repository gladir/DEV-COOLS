{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Clipper vers assembleur 8086
}

(* ============================================================
  CLIPPER86.PAS - Compilateur Clipper vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.prg [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .prg (programme) ou .ch (header Clipper)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS CLIPPER) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_CODEBLOCK
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaines entre guillemets simples 'abc',
              guillemets doubles "abc" ou crochets [abc]
            Commentaires : * en debut de ligne, // fin de ligne,
              /* ... */ bloc multiligne, NOTE en debut de ligne
            Mots-cles insensibles a la casse (UPPER interne) :
              IF ELSEIF ELSE ENDIF DO WHILE ENDDO FOR NEXT TO STEP
              CASE ENDCASE OTHERWISE FUNCTION PROCEDURE RETURN
              LOCAL STATIC PRIVATE PUBLIC DECLARE PARAMETERS
              BEGIN SEQUENCE RECOVER END EXIT LOOP
              NIL SELF
            Abreviations : mots-cles tronques a 4 caracteres minimum
              (ex: FUNC pour FUNCTION, PROC pour PROCEDURE, RETU pour RETURN)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 ou -32768..32767
            Entiers hexadecimaux : 0xFF ou 0x1A
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines : 'abc' ou "abc" ou [abc] -> pointeur vers donnees DATA
            Dates litterales : CTOD("MM/DD/YY") -> entier julien interne
            Booleens : .T. / .TRUE. -> AX=1, .F. / .FALSE. -> AX=0
            NIL : valeur nulle -> AX=0 (type NIL, variable non initialisee)
            Constantes predefinies : .T., .F., NIL

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / % (ou MOD)
            Puissance      : ** ou ^ (appel _CLRT_POWER)
            Concatenation  : + (chaine + chaine -> appel _CLRT_CONCAT)
            Comparaison    : == (exact), = (souple), != ou <> ou # (different)
                             < <= > >=
            Logiques       : .AND. .OR. .NOT. (ou !)
            Affectation    : := (inline), = (statement level)
            Compound       : += -= *= /= %= (raccourcis affectation)
            Chaines        : $ (sous-chaine contenue dans : "ab" $ "abc")
            Alias          : -> (acces champ : ALIAS->FIELD)
            Macro          : & (substitution macro : &variable)
            Precedence (du plus fort au plus faible) :
              1. () groupement, unaire -, .NOT. / !
              2. ** / ^
              3. * / %
              4. + - (binaire et concatenation)
              5. $ (containment)
              6. == = != <> # < <= > >=
              7. .AND.
              8. .OR.
              9. := += -= *= /=

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_LOCAL, SK_STATIC, SK_PRIVATE, SK_PUBLIC,
              SK_PARAM, SK_FIELD, SK_MEMVAR, SK_FUNC, SK_PROC, SK_ALIAS
            TSymRec : Name, MangledName, Kind, TypeTag, Offset,
              Scope, IsInit, ArraySize
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des portees (FUNCTION/PROCEDURE)
            Portees Clipper :
              PUBLIC : visible partout (prefixe _CLG_)
              PRIVATE : visible dans la routine courante et les sous-routines
              LOCAL : visible uniquement dans la routine courante (pile)
              STATIC : visible dans la routine, persiste entre appels (DATA)
            FIELD : acces champ de la base de donnees courante
            MEMVAR : variable memoire explicite (MEMVAR->nom)
            Resolution d ambiguite : FIELD->nom vs MEMVAR->nom vs nom seul

  TODO 06 - SYSTEME DE TYPES
            Clipper est dynamiquement type : chaque valeur porte un tag de type
            TTypeTag : TT_NIL, TT_NUMERIC, TT_CHARACTER, TT_DATE,
              TT_LOGICAL, TT_ARRAY, TT_CODEBLOCK, TT_OBJECT
            Representation interne : chaque variable = (tag: Byte, val: Word)
              tag en premier octet, valeur en mot suivant
              TT_NUMERIC   -> entier 16 bits signe
              TT_CHARACTER -> pointeur vers chaine terminee par 0
              TT_DATE      -> entier julien 16 bits
              TT_LOGICAL   -> 0 (.F.) ou 1 (.T.)
              TT_ARRAY     -> pointeur vers bloc tableau en heap
              TT_CODEBLOCK -> pointeur vers descripteur de code block
              TT_OBJECT    -> pointeur vers instance objet
              TT_NIL       -> valeur 0 (non initialisee)
            VALTYPE(x) : retourne le tag de type -> "C","N","D","L","A","B","O","U"
            Verification dynamique avant operations (erreur si type incompatible)

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _CLL_NNNNN)
            Prefixes : _CLV_ (variable locale/globale), _CLP_ (procedure/fonction),
              _CLK_ (chaine constante), _CLRT_ (runtime), _CLL_ (label),
              _CLG_ (variable PUBLIC globale), _CLS_ (variable STATIC),
              _CLA_ (alias DBF), _CLB_ (code block)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_TAGGED),
              IntVal, StrVal, TagVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddTagged : variantes d ajout
            Variables PUBLIC : segment DATA avec tag + valeur (_CLG_nom)
            Variables STATIC : segment DATA avec tag + valeur (_CLS_nom)
            Chaines litterales : DB 'abc',0 dans DATA avec label _CLK_N
            Dates litterales : DW valeur_julienne dans DATA
            Tableaux statiques : bloc (tag, ptr_elements) dans DATA

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables LOCAL : pile BP, acces [BP-offset] (tag + valeur = 3 octets)
            Variables STATIC : segment DATA, acces par label _CLS_nom
            Variables PRIVATE : segment DATA ou pile (visibles dans sous-routines)
            Variables PUBLIC : segment DATA, acces par label _CLG_nom
            PARAMETERS var1, var2 : parametres positionnels de DO...WITH
            Affectation := ou = : evaluer expression + stocker tag + valeur
            Affectation composee += -= *= /= : lire, operer, stocker
            Declaration LOCAL a := expr, b := expr : init a la declaration
            Declaration STATIC s := expr : init une seule fois (premier appel)
            STORE expr TO var1, var2 : affectation multiple (syntaxe dBASE)

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, date, booleen, NIL
            Acces variable : recherche symbole -> emit chargement tag+valeur
            Acces champ DBF : FIELD->nom ou alias->nom -> CALL _CLRT_GETFIELD
            Appel de fonction : nom(args) -> PUSH args + CALL _CLP_nom
            Acces tableau : arr[i] ou arr[i,j] -> CALL _CLRT_AGET
            EVAL(bCodeBlock, args) : evaluer un code block -> CALL _CLRT_EVAL
            Macro &variable : substitution de macro a l execution
              -> CALL _CLRT_MACRO(SI=nom_var) -> interpretation dynamique
            SELF : reference a l objet courant dans une methode
            Parentheses : (expr) -> groupement
            IIF(cond, exprVrai, exprFaux) : expression conditionnelle inline

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            MOD (%) : IDIV -> resultat dans DX (reste)
            Puissance ** ou ^ : CALL _CLRT_POWER(AX=base, BX=exp) -> AX
            Concatenation chaines : + -> CALL _CLRT_CONCAT(SI=gauche, DI=droite) -> AX
            Soustraction chaines : - -> concat avec trim a droite de la gauche
            Containment $ : CALL _CLRT_INSTR -> AX=0|1
            Comparaison numerique : CMP + Jcc pour =, <, <=, >, >=, <>
            Comparaison chaines : CALL _CLRT_STRCMP -> drapeaux
              = (souple) : compare sur la longueur de la chaine droite
              == (exact) : compare longueur + contenu exact
            Comparaison dates : CMP sur entiers juliens
            Logique .AND. : court-circuit JZ vers false-branch
            Logique .OR. : court-circuit JNZ vers true-branch
            Logique .NOT. / ! : XOR AX,1
            Verification de type dynamique avant chaque operation

  TODO 12 - ENTREES/SORTIES ECRAN
            ? expr [, expr ...] : afficher avec retour a la ligne
              -> CALL _CLRT_PRINTVAL pour chaque expr + CALL _CLRT_PRINTLN
            ?? expr [, expr ...] : afficher sans retour a la ligne
            @ row,col SAY expr [PICTURE cMask] :
              -> CALL _CLRT_GOTOXY(AH=row, AL=col) via INT 10h
              -> CALL _CLRT_PRINTVAL(AX=tag+val)
              PICTURE : masque de formatage ("999.99", "@!", etc.)
            @ row,col GET var [PICTURE cMask] [VALID cond] :
              -> enregistrer le GET dans la table des GETs (_CL_GETLIST)
              Chaque GET : (row, col, varptr, picture, valid_block)
            READ : activer la saisie de tous les GETs en attente
              -> CALL _CLRT_READGETS : boucle sur _CL_GETLIST
              Navigation : fleches, Tab, Enter, Esc
              Validation : evaluer le code block VALID apres saisie
            CLEAR / CLEAR SCREEN : INT 10h AH=00h mode 3 (80x25 texte)
            @ row1,col1 TO row2,col2 [DOUBLE] : dessiner un cadre
            SET COLOR TO expr : changer les attributs couleur ecran
            INKEY([nSec]) : attendre touche -> AX=code touche (INT 16h)
            LASTKEY() : retourner le code de la derniere touche pressee

  TODO 13 - IF / ELSEIF / ELSE / DO CASE
            ParseIfStmt : IF cond ... [ELSEIF cond ...] [ELSE ...] ENDIF
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _CLL_ELSIF_N, _CLL_ELSE_N, _CLL_ENDIF_N
            ParseDoCaseStmt : DO CASE
              CASE cond1 ... CASE cond2 ... [OTHERWISE ...] ENDCASE
              Emission : evaluation sequentielle de chaque condition
              TEST AX,AX / JZ vers prochain CASE
              Labels : _CLL_CASE_N, _CLL_CEND_N
            IIF(cond, exprT, exprF) : expression conditionnelle inline
              TEST AX,AX / JZ -> evaluer exprF / JMP fin
              sinon evaluer exprT
              Label : _CLL_IIF_N

  TODO 14 - BOUCLES : DO WHILE / FOR / FOR EACH / LOOP / EXIT
            ParseDoWhileStmt : DO WHILE cond ... ENDDO
              Labels : _CLL_WTEST_N, _CLL_WEND_N
            ParseForStmt : FOR var := lo TO hi [STEP n] ... NEXT
              Variable de boucle locale, increment automatique
              STEP n : increment different de 1 (positif ou negatif)
              Labels : _CLL_FTEST_N, _CLL_FINCR_N, _CLL_FEND_N
            ParseForEachStmt : FOR EACH elem IN collection ... NEXT
              Iteration sur tableau ou chaine
              Labels : _CLL_FETEST_N, _CLL_FEINCR_N, _CLL_FEEND_N
            LOOP : saut vers le debut de la boucle courante
              -> JMP _CLL_WTEST_N ou _CLL_FINCR_N
            EXIT : saut vers la fin de la boucle courante
              -> JMP _CLL_WEND_N ou _CLL_FEND_N
            LoopPush / LoopPop : pile de labels pour LOOP/EXIT imbriques

  TODO 15 - TABLEAUX
            Declaration : LOCAL arr[n] ou LOCAL arr := {e1, e2, e3}
              DECLARE arr[n] ou DECLARE arr[n1, n2] (multidimensionnel)
            Tableaux dynamiques : taille modifiable a l execution
              Bloc en heap : (len: Word, elements: array of TaggedVal)
            Acces : arr[i] -> CALL _CLRT_AGET(BX=arr_ptr, AX=index) -> tag+val
            Affectation : arr[i] := expr -> CALL _CLRT_ASET(BX=arr_ptr, AX=index, val)
            Initialisation : {e1, e2, e3} -> allouer + remplir en heap
            Tableaux imbriques : {1, {2,3}, 4} -> elements de type TT_ARRAY
            Fonctions integrees :
              LEN(arr)           -> AX = nombre d elements
              AADD(arr, val)     -> ajouter un element a la fin
              ADEL(arr, n)       -> supprimer le n-ieme element
              AINS(arr, n)       -> inserer un element vide en position n
              ASIZE(arr, n)      -> redimensionner le tableau
              ACLONE(arr)        -> copie complete -> AX=ptr nouveau tableau
              ASORT(arr [,bBlock]) -> tri (appel _CLRT_ASORT)
              ASCAN(arr, val)    -> recherche lineaire -> AX=position ou 0
              AEVAL(arr, bBlock) -> appliquer un code block a chaque element
              AFILL(arr, val)    -> remplir tous les elements avec val
              ACOPY(src, dst)    -> copier elements de src vers dst

  TODO 16 - CHAINES DE CARACTERES
            Representation : pointeur vers buffer termine par 0 dans DATA ou heap
            Concatenation + : CALL _CLRT_CONCAT(SI=src1, DI=src2) -> AX=ptr
            Soustraction - : trim droite de gauche puis concat (align droite)
            Containment $ : CALL _CLRT_INSTR(SI=sub, DI=str) -> AX=pos (0 si absent)
            Fonctions integrees :
              LEN(str)              -> AX = longueur
              SUBSTR(str, start, len) -> AX = ptr sous-chaine
              LEFT(str, n)          -> AX = ptr n premiers caracteres
              RIGHT(str, n)         -> AX = ptr n derniers caracteres
              AT(sub, str)          -> AX = position (1-base) ou 0
              RAT(sub, str)         -> AX = derniere occurrence
              TRIM(str) / RTRIM(str)-> AX = ptr sans espaces a droite
              LTRIM(str)            -> AX = ptr sans espaces a gauche
              ALLTRIM(str)          -> AX = ptr sans espaces des deux cotes
              UPPER(str)            -> AX = ptr majuscules
              LOWER(str)            -> AX = ptr minuscules
              REPLICATE(str, n)     -> AX = ptr chaine repetee n fois
              SPACE(n)              -> AX = ptr chaine de n espaces
              PADR(str, n)          -> AX = ptr cadre a droite avec espaces
              PADL(str, n)          -> AX = ptr cadre a gauche avec espaces
              PADC(str, n)          -> AX = ptr centre avec espaces
              CHR(n)                -> AX = ptr caractere ASCII
              ASC(str)              -> AX = code ASCII du premier caractere
              STR(n [,len [,dec]])  -> AX = ptr nombre en chaine
              VAL(str)              -> AX = conversion chaine en nombre
              STRTRAN(str, old, new)-> AX = ptr remplacement sous-chaine
              STUFF(str, pos, del, ins) -> AX = ptr insertion/suppression
              TRANSFORM(val, mask)  -> AX = ptr valeur formatee avec masque

  TODO 17 - PROCEDURES ET FONCTIONS
            ParseFuncDecl : FUNCTION nom([params]) ... RETURN expr
            ParseProcDecl : PROCEDURE nom([params]) ... RETURN
            Parametres : passes par valeur (copie tag+val sur la pile)
              Passage par reference : @ prefixe -> passer adresse du tag+val
            Convention d appel : arguments empiles droite a gauche
            Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
            Epilogue : MOV SP,BP / POP BP / RET
            RETURN expr : charger tag+val dans AX/DX + JMP vers epilogue
            RETURN sans valeur : retourne NIL par defaut
            DO procname [WITH arg1, arg2] : syntaxe d appel dBASE
            Appel direct : nom(arg1, arg2) : syntaxe Clipper
            Recursion : supportee via cadre de pile standard
            INIT PROCEDURE / EXIT PROCEDURE : executees au demarrage/fin
              du programme automatiquement
            Variables STATIC dans fonctions : conservent leur valeur entre appels

  TODO 18 - CODE BLOCKS ET EVAL
            Code block literal : {|params| expr}
              {|| expr}          : sans parametre
              {|x| x * 2}       : un parametre
              {|x,y| x + y}     : plusieurs parametres
            Representation en memoire :
              Descripteur en DATA/heap : (nb_params: Byte, code_ptr: Word)
              Code genere comme sous-routine anonyme _CLB_N
            EVAL(bBlock [, arg1, arg2 ...]) : evaluer le code block
              PUSH args + CALL [BX+offset_code] -> resultat tag+val
            Passage en parametre : les code blocks sont des valeurs de type TT_CODEBLOCK
            Utilisation courante :
              AEVAL(arr, {|e| QOut(e)})     : iteration
              ASORT(arr, {|a,b| a < b})     : tri avec comparateur
              DBEVAL({|| traitement()})      : iteration sur enregistrements
              SET KEY n TO {|| action()}     : assignation de touche
            Variables capturees : les code blocks capturent les variables LOCAL
              du contexte englobant (fermeture / closure simplifiee)
              -> stocker les pointeurs vers les variables capturees dans le descripteur

  TODO 19 - FICHIERS DBF (BASE DE DONNEES)
            USE nomFichier [ALIAS cAlias] [NEW] [SHARED/EXCLUSIVE] :
              Ouvrir un fichier .DBF
              -> CALL _CLRT_DBOPEN(SI=nom, AL=mode) -> handle dans work area
            Work areas : 10 zones de travail simultanees (SELECT 1..10 ou A..J)
            SELECT n / SELECT cAlias : changer la zone de travail active
            Structure DBF simplifiee :
              En-tete : version, nb_records, taille_header, taille_record
              Descripteurs de champs : nom(11), type(1), taille(1), decimales(1)
              Donnees : enregistrements fixes, 1 octet de suppression + champs
            Commandes de navigation :
              GO TOP          -> aller au premier enregistrement
              GO BOTTOM       -> aller au dernier enregistrement
              GO n            -> aller a l enregistrement n
              SKIP [n]        -> avancer/reculer de n enregistrements
              EOF()           -> AX=1 si fin de fichier
              BOF()           -> AX=1 si debut de fichier
              RECNO()         -> AX=numero d enregistrement courant
              RECCOUNT()      -> AX=nombre total d enregistrements
            Commandes de modification :
              APPEND BLANK    -> ajouter un enregistrement vide
              REPLACE champ WITH expr [, champ WITH expr ...]
              DELETE          -> marquer l enregistrement pour suppression
              RECALL          -> annuler la marque de suppression
              PACK            -> supprimer physiquement les enregistrements marques
              ZAP             -> supprimer tous les enregistrements
            CLOSE / CLOSE ALL / CLOSE DATABASES : fermer les fichiers DBF
            DELETED()         -> AX=1 si enregistrement marque pour suppression

  TODO 20 - INDEX ET RECHERCHE (NTX/NDX)
            INDEX ON expr TO nomFichier :
              Creer un fichier index (.NTX format Clipper)
              -> CALL _CLRT_IDXCREATE(SI=expr, DI=fichier)
            SET INDEX TO nomFichier [, nomFichier2 ...] :
              Ouvrir un ou plusieurs fichiers index
            SET ORDER TO n : activer le n-ieme index
            REINDEX : reconstruire tous les index ouverts
            SEEK expr : recherche dans l index actif
              -> CALL _CLRT_IDXSEEK(AX=valeur) -> positionner sur l enregistrement
              FOUND()  -> AX=1 si la recherche a trouve un enregistrement
            LOCATE FOR cond [WHILE cond] [NEXT n] [REST] [ALL] :
              Recherche sequentielle avec condition
              CONTINUE : continuer la recherche LOCATE
            SET FILTER TO [cond] : filtrer les enregistrements visibles
            SET RELATION TO expr INTO cAlias : lier deux work areas
            DBEVAL({||}block [, {||}for] [, {||}while]) : iteration conditionnelle
            SET SOFTSEEK ON/OFF : comportement de SEEK si non trouve
            SET EXACT ON/OFF : comparaison exacte ou partielle pour SEEK
            SET DELETED ON/OFF : masquer les enregistrements marques

  TODO 21 - GESTION DES ERREURS (BEGIN SEQUENCE / RECOVER)
            ParseBeginSequenceStmt :
              BEGIN SEQUENCE
                stmts
              [RECOVER [USING oError]]
                stmts_recuperation
              END [SEQUENCE]
            BREAK [expr] : sortir du bloc SEQUENCE courant
              AX = valeur d erreur optionnelle
            Mecanisme sans support OS :
              _CL_SEQHANDLER DW 0 dans DATA (ptr vers handler courant)
              BEGIN SEQUENCE : sauvegarder ancien handler, installer nouveau
                MOV [_CL_SEQHANDLER], OFFSET _CLL_RECOVER_N
              BREAK : MOV AX,errval / JMP [_CL_SEQHANDLER]
              RECOVER : label _CLL_RECOVER_N, oError = AX
              END SEQUENCE : restaurer ancien handler
            ERRORBLOCK([bNewBlock]) : get/set le bloc d erreur global
              -> remplace ou retourne _CL_ERRORBLOCK dans DATA
            Objet Error simplifie :
              args, canDefault, canRetry, canSubstitute
              description, fileName, operation, severity, subCode
            BREAK sans handler : affiche 'Unhandled error' + Halt

  TODO 22 - PREPROCESSEUR (#command, #translate, #define, #include)
            Passe de preprocessing avant la compilation :
            #include "fichier.ch" : inclure un fichier header Clipper
              Fichiers standards : STD.CH, SET.CH, DBSTRUCT.CH
            #define NOM [valeur] : definition de constante ou macro
            #ifdef NOM / #ifndef NOM / #else / #endif : compilation conditionnelle
            #undef NOM : suppression de definition
            #command PATTERN => RESULT : definition de commande utilisateur
              Le pattern utilise des marqueurs : <idMarker>, <(idMarker)>,
              <{idMarker}>, <!idMarker!>, <*idMarker*>, <idMarker,...>
              Le resultat utilise les memes marqueurs pour substitution
            #translate PATTERN => RESULT : comme #command mais pour expressions
            #xcommand / #xtranslate : variantes sensibles a la casse
            Exemples de STD.CH :
              #command ? [<list,...>] => QOut(<list>)
              #command ?? [<list,...>] => QQOut(<list>)
              #command @ <r>,<c> SAY <x> => DevPos(<r>,<c>); DevOut(<x>)
              #command USE <db> => dbUseArea(.F., NIL, <(db)>)
            Traitement des macros : expansion recursive avec limite de profondeur

  TODO 23 - FONCTIONS INTEGREES
            Fonctions numeriques :
              ABS(n), INT(n), MAX(n1,n2), MIN(n1,n2), MOD(n1,n2)
              ROUND(n, nDec)     -> AX = arrondi (entier si nDec=0)
              SQRT(n)            -> AX = racine carree entiere approchee
            Fonctions de date :
              DATE()             -> AX = date systeme (entier julien)
              CTOD(cDate)        -> AX = conversion chaine vers date
              DTOC(dDate)        -> AX = ptr conversion date vers chaine
              DTOS(dDate)        -> AX = ptr date en format "YYYYMMDD"
              DOW(dDate)         -> AX = jour de la semaine (1=dimanche)
              CDOW(dDate)        -> AX = ptr nom du jour
              DAY(dDate)         -> AX = jour du mois (1..31)
              MONTH(dDate)       -> AX = mois (1..12)
              CMONTH(dDate)      -> AX = ptr nom du mois
              YEAR(dDate)        -> AX = annee (ex: 1995)
            Fonctions de conversion :
              STR(n), VAL(c), CHR(n), ASC(c)
              TRANSFORM(val, cMask) -> AX = ptr formatage
            Fonctions de type :
              VALTYPE(x)         -> AX = ptr "C"/"N"/"D"/"L"/"A"/"B"/"O"/"U"
              TYPE("expr")       -> AX = ptr type de l expression (macro)
              EMPTY(x)           -> AX = 1 si valeur vide/zero/chaine vide
              LEN(x)             -> AX = longueur (chaine ou tableau)
            Fonctions systeme :
              INKEY([n])         -> AX = code touche (INT 16h) ou 0
              LASTKEY()          -> AX = code de la derniere touche
              ROW()              -> AX = ligne curseur courante
              COL()              -> AX = colonne curseur courante
              MAXROW()           -> AX = derniere ligne ecran (24)
              MAXCOL()           -> AX = derniere colonne ecran (79)
              OS()               -> AX = ptr nom du systeme ("DOS")
              MEMORY(0)          -> AX = memoire libre en Ko
              SECONDS()          -> AX = secondes depuis minuit (INT 1Ah)
              TIME()             -> AX = ptr heure courante "HH:MM:SS"

  TODO 24 - RUNTIME MINIMAL
            _CLRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _CLRT_PRINTLN : _CLRT_PRINT + CR+LF via _CL_CRLF DB 13,10,0
            _CLRT_PRINTVAL(tag+val) : afficher selon le type (N/C/D/L)
            _CLRT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _CLRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _CLRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _CLRT_CONCAT(SI=src1, DI=src2) : concatenation chaines -> AX=ptr
            _CLRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _CLRT_STRCMPEXACT(SI=s1, DI=s2) : comparaison exacte (==)
            _CLRT_INSTR(SI=sub, DI=str) : recherche sous-chaine -> AX=pos
            _CLRT_SUBSTR(SI=str, BX=start, CX=len) : sous-chaine -> AX=ptr
            _CLRT_UPPER(SI=str) : convertir en majuscules -> AX=ptr
            _CLRT_LOWER(SI=str) : convertir en minuscules -> AX=ptr
            _CLRT_POWER(AX=base, BX=exp) : puissance entiere -> AX
            _CLRT_GOTOXY(AH=row, AL=col) : positionner curseur (INT 10h AH=02h)
            _CLRT_READGETS : boucle de saisie des GETs en attente
            _CLRT_NEW(CX=nb_octets) : allocation heap -> AX=ptr
            _CLRT_DBOPEN(SI=nom, AL=mode) : ouvrir fichier DBF -> handle
            _CLRT_DBCLOSE(AX=handle) : fermer fichier DBF
            _CLRT_DBREAD(AX=handle, BX=recno) : lire enregistrement
            _CLRT_DBWRITE(AX=handle, BX=recno) : ecrire enregistrement
            _CLRT_GETFIELD(SI=name) : lire champ -> tag+val
            _CLRT_SETFIELD(SI=name, tag+val) : ecrire champ
            _CLRT_AGET(BX=arr, AX=idx) : lire element tableau -> tag+val
            _CLRT_ASET(BX=arr, AX=idx, tag+val) : ecrire element tableau
            _CLRT_EVAL(BX=codeblock, args) : evaluer code block -> tag+val
            _CLRT_MACRO(SI=nom_var) : substitution macro -> evaluation
            _CLRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _CL_HEAP DB 4096 DUP(0) + _CL_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _CLP_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseModule ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _CLP_Main
            Fichiers SAMPLES\CLIPPER\ a creer :
              hello.prg    (?, ??, variables, constantes, types)
              math.prg     (fonctions, procedures, recursion, RETURN)
              control.prg  (IF/ELSEIF, DO CASE, DO WHILE, FOR, FOR EACH)
              strings.prg  (manipulation de chaines, SUBSTR, AT, TRIM)
              arrays.prg   (tableaux, AADD, ASORT, ASCAN, AEVAL)
              codeblk.prg  (code blocks, EVAL, closures, AEVAL avec block)
              database.prg (USE, APPEND, REPLACE, DELETE, SKIP, SEEK)
              screen.prg   (@ SAY, @ GET, READ, @ TO, CLEAR, couleurs)
              errors.prg   (BEGIN SEQUENCE, RECOVER, BREAK, ERRORBLOCK)
              preproc.prg  (#command, #define, #include, STD.CH)
            Smoke tests : CLIPPER86.EXE -v SAMPLES\CLIPPER\*.prg

  ============================================================ *)

{ ============================================================
  CLIPPER86 - Compilateur Clipper -> assembleur 8086
  Version : 1.0  Date : 2026-03-07
  Compilation : ppc386 -O2 -Mtp CLIPPER86.PAS
  ============================================================ }

Program CLIPPER86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  CLIPPER86_VERSION = '1.0';
  CLIPPER86_DATE    = '2026-03-07';

  { Limites internes }
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}256{$ELSE}128{$ENDIF};
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  STACK_SIZE    = 1024;

  { Indices de types primitifs Clipper }
  TY_IDX_NIL    = 0;     { NIL : valeur non initialisee          }
  TY_IDX_NUM    = 1;     { NUMERIC : entier 16 bits signe        }
  TY_IDX_CHAR   = 2;     { CHARACTER : pointeur vers chaine      }
  TY_IDX_DATE   = 3;     { DATE : entier julien 16 bits          }
  TY_IDX_LOGIC  = 4;     { LOGICAL : 0 (.F.) ou 1 (.T.)         }
  TY_IDX_ARRAY  = 5;     { ARRAY : pointeur vers bloc tableau    }
  TY_IDX_BLOCK  = 6;     { CODEBLOCK : pointeur vers descripteur }
  TY_IDX_OBJECT = 7;     { OBJECT : pointeur vers instance       }

  TY_UNKNOWN    = -1;    { type inconnu / pas de valeur          }

  { Prefixes de nommage ASM }
  CL_VAR_PFX   = '_CLV_';    { variable locale / globale            }
  CL_FN_PFX    = '_CLP_';    { procedure / fonction                 }
  CL_STR_PFX   = '_CLK_';    { constante chaine litterale           }
  CL_RT_PFX    = '_CLRT_';   { routine runtime                      }
  CL_LBL_PFX   = '_CLL_';    { label de saut interne                }
  CL_GLB_PFX   = '_CLG_';    { variable PUBLIC globale              }
  CL_STAT_PFX  = '_CLS_';    { variable STATIC                      }
  CL_FLD_PFX   = '_CLF_';    { champ FIELD de base de donnees       }
  CL_ALIAS_PFX = '_CLA_';    { alias DBF                            }
  CL_BLK_PFX   = '_CLB_';    { code block                           }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { fichier source (.prg / .ch)          }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugMode : Boolean;   { -d : affichage de chaque token       }
    Warnings  : Boolean;   { -w : activer les avertissements      }
  End;

  { ---- Tokens Clipper (TODO 02) ----------------------------- }
  TTokenKind = (
    TK_EOF,        { fin de fichier                             }
    TK_INTEGER,    { litteral entier decimal ou hexadecimal     }
    TK_FLOAT,      { litteral reel (reconnu, tronque a entier)  }
    TK_STRING,     { litteral chaine 'abc' "abc" [abc]          }
    TK_IDENT,      { identificateur (non-mot-cle)               }
    TK_KEYWORD,    { mot-cle Clipper reconnu (UPPER interne)    }
    TK_OP,         { operateur + - * / := == etc.               }
    TK_PUNCT,      { ponctuation ( ) , ; etc.                   }
    TK_CODEBLOCK   { debut de code block detecte                }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     { valeur textuelle brute               }
    IntVal   : LongInt;     { valeur entiere (TK_INTEGER)          }
    FloatVal : Real;        { valeur flottante (TK_FLOAT)          }
    Line     : Integer;     { ligne source (1-base)                }
    Col      : Integer;     { colonne source (1-base)              }
  End;

  { ---- Valeur d expression (TODO 03) ----------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur                          }
    EK_IMM,    { valeur immediate dans ImmVal                   }
    EK_AX,     { valeur dans le registre AX                     }
    EK_MEM     { adresse memoire [BP+Offset] ou label DATA      }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;     { valeur immediate (EK_IMM)            }
    TypeIdx : Integer;     { indice type (TY_IDX_*)               }
    Offset  : Integer;     { offset donnee/pile ou index DataTab  }
    SymIdx  : Integer;     { indice dans SymTab (-1 = pas lvalue) }
  End;

  { ---- Segment de donnees (TODO 03) ------------------------ }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR);

  TDataRec = Record
    LblName : TString;     { label ASM de l entree                }
    Kind    : TDataKind;   { type de donnee                       }
    IntVal  : LongInt;     { valeur entiere (DK_WORD/DK_BYTE)     }
    StrVal  : TString;     { contenu chaine (DK_STR)              }
  End;

  { ---- Table des symboles (TODO 05) ------------------------- }
  TSymCat = (
    SC_LOCAL,      { variable LOCAL (pile, [BP-n])                 }
    SC_STATIC,     { variable STATIC (DATA, persiste entre appels) }
    SC_PRIVATE,    { variable PRIVATE (visible dans sous-routines) }
    SC_PUBLIC,     { variable PUBLIC (globale, prefixe _CLG_)      }
    SC_PARAM,      { parametre de FUNCTION/PROCEDURE ([BP+n])      }
    SC_FIELD,      { champ de base de donnees (FIELD->nom)         }
    SC_MEMVAR,     { variable memoire explicite (MEMVAR->nom)      }
    SC_FUNC,       { declaration FUNCTION                          }
    SC_PROC,       { declaration PROCEDURE                         }
    SC_ALIAS       { alias DBF (USE ... ALIAS nom)                 }
  );

  TSymRec = Record
    Name        : TString;   { nom Clipper (UPPER interne)          }
    MangledName : TString;   { label ASM genere                     }
    Cat         : TSymCat;   { categorie du symbole                 }
    TypeIdx     : Integer;   { indice type TY_IDX_*                 }
    ScopeLevel  : Integer;   { profondeur de portee (0 = global)    }
    Offset      : Integer;   { [BP-n] locals, [BP+n] params, DATA  }
    IsInit      : Boolean;   { variable deja initialisee            }
    ArraySize   : Integer;   { taille si tableau (0 = scalaire)     }
    DeclLine    : Integer;   { ligne de declaration (source)        }
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

  { Emetteur ASM }
  OutF     : Text;
  OutFOpen : Boolean;

  { Lexeur (TODO 02) }
  LexSrcF    : Text;       { fichier source ouvert                }
  LexLine    : String;     { ligne courante en memoire            }
  LexLineNo  : Integer;    { numero de ligne (1-based)            }
  LexColNo   : Integer;    { colonne courante (1-based)           }
  LexEOF     : Boolean;    { fin de fichier atteinte              }
  LexOpened  : Boolean;    { fichier source ouvert                }
  CurToken   : TToken;     { token courant                        }

  { Segment de donnees (TODO 03) }
  DataTab    : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount  : Integer;    { nombre d entrees dans DataTab         }
  LabelSeq   : Integer;    { compteur unique pour generation labels }

  { Table des symboles (TODO 05) }
  SymTab     : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount   : Integer;    { nombre d entrees dans SymTab           }
  ScopeStack : Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop   : Integer;    { sommet de pile des portees             }
  CurScope   : Integer;    { profondeur de portee courante          }
  TotalSyms  : Integer;    { nombre total de symboles declares      }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
{ Lexeur (TODO 02) }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextLine;         Forward;
Procedure LexSkipBlockComment; Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString(Quote : Char); Forward;
Procedure LexScanBracketStr;   Forward;
Procedure LexNextToken;        Forward;
{ Litteraux et constantes (TODO 03) }
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal); Forward;
Procedure ExprMakeNil(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Procedure EmitDataSeg; Forward;
{ Operateurs et expressions (TODO 04) }
Function  LabelGen : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Procedure ParserAdvance; Forward;
Function  IsAssignOp(Const Op : TString) : Boolean; Forward;
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ Table des symboles (TODO 05) }
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString) : Integer; Forward;
Function  SymAdd(Const Name : TString; Cat : TSymCat;
                 ATypeIdx, AOffset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymInit; Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- Messages d erreur et d avertissement ---------------- }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('CLIPPER86: FATAL: ', Msg);
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
  WriteLn('CLIPPER86: error: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs, compilation arretee');
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('CLIPPER86: warning: ', Msg);
  Inc(WarnCount);
End;

{ ---- Banniere ---------------------------------------------- }

Procedure ShowBanner;
Begin
  WriteLn('CLIPPER86 v', CLIPPER86_VERSION, ' (', CLIPPER86_DATE, ')');
  WriteLn('Compilateur Clipper -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: CLIPPER86 <source.prg> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.prg : fichier Clipper source (.prg ou .ch)');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
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

Function IntToStr(N : LongInt) : TString;
Var
  S : TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

{ ---- Utilitaires de chemin ---------------------------------- }

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
      ShowUsage
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('CLIPPER86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('CLIPPER86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('CLIPPER86: fichier source manquant');
    ShowUsage;
  End;

  { Verifier l extension .prg ou .ch }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.prg') And (Ext <> '.ch') Then
    WarnMsg('extension attendue .prg ou .ch, trouvee: ' + Ext);

  { Fichier de sortie par defaut : meme nom avec .asm }
  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

{ ---- Nettoyage -------------------------------------------- }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ---- Initialisation generale des variables globales -------- }

Procedure GlobalInit;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  DataCount  := 0;
  LabelSeq   := 0;
  SymInit;
End;

{ ---- Affichage des statistiques ----------------------------- }

Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('  Lignes sources : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ---- Pipeline de compilation -------------------------------- }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then
    ShowBanner;

  LexInit;

  { Lire le premier token }
  LexNextToken;

  { Boucle de tokenisation (TODO 02) }
  While CurToken.Kind <> TK_EOF Do
  Begin
    PrintToken(CurToken);
    LexNextToken;
  End;

  LexClose;

  If Opts.Verbose Then
    ShowStats;

  Cleanup;

  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  TODO 02 - LEXEUR (TOKENS CLIPPER) [IMPLEMENTE]
  ============================================================ }

{ ---- Fonctions auxiliaires de classification de caracteres -- }

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
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

{ ---- IsKeyword : mots-cles Clipper ------------------------- }
(* Clipper utilise des mots-cles insensibles a la casse.
   Les abreviations a 4 caracteres minimum sont supportees :
   FUNC -> FUNCTION, PROC -> PROCEDURE, RETU -> RETURN,
   PARA -> PARAMETERS, PRIV -> PRIVATE, PUBL -> PUBLIC,
   LOCA -> LOCAL, STAT -> STATIC, DECL -> DECLARE,
   OTHE -> OTHERWISE, ELSEI -> ELSEIF, SEQU -> SEQUENCE,
   RECO -> RECOVER *)

Function IsKeyword(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  IsKeyword := False;

  { Mots-cles complets }
  If (U = 'IF')         Or (U = 'ELSEIF')     Or (U = 'ELSE')       Or
     (U = 'ENDIF')      Or (U = 'DO')         Or (U = 'WHILE')      Or
     (U = 'ENDDO')      Or (U = 'FOR')        Or (U = 'NEXT')       Or
     (U = 'TO')         Or (U = 'STEP')       Or (U = 'CASE')       Or
     (U = 'ENDCASE')    Or (U = 'OTHERWISE')  Or (U = 'FUNCTION')   Or
     (U = 'PROCEDURE')  Or (U = 'RETURN')     Or (U = 'LOCAL')      Or
     (U = 'STATIC')     Or (U = 'PRIVATE')    Or (U = 'PUBLIC')     Or
     (U = 'DECLARE')    Or (U = 'PARAMETERS') Or (U = 'BEGIN')      Or
     (U = 'SEQUENCE')   Or (U = 'RECOVER')    Or (U = 'END')        Or
     (U = 'EXIT')       Or (U = 'LOOP')       Or (U = 'NIL')        Or
     (U = 'SELF')       Or (U = 'EACH')       Or (U = 'IN')         Or
     (U = 'WITH')       Or (U = 'CLASS') Then
  Begin
    IsKeyword := True;
    Exit;
  End;

  { Abreviations : minimum 4 caracteres }
  If Length(U) >= 4 Then
  Begin
    If Copy('FUNCTION',   1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('PROCEDURE',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('RETURN',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('PARAMETERS', 1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('PRIVATE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('PUBLIC',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('LOCAL',      1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('STATIC',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('DECLARE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('OTHERWISE',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('ELSEIF',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('SEQUENCE',   1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('RECOVER',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('ENDCASE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('ENDIF',      1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('ENDDO',      1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('WHILE',      1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
  End;
End;

{ ---- Expansion des abreviations ----------------------------- }
(* Retourne le mot-cle complet si S est une abreviation,
   sinon retourne S tel quel en majuscules *)

Function ExpandKeyword(Const S : TString) : TString;
Var
  U : TString;
Begin
  U := StrUpperCase(S);

  { Correspondances exactes : retourner tel quel }
  If (U = 'IF')      Or (U = 'ELSE')   Or (U = 'DO')      Or
     (U = 'FOR')     Or (U = 'NEXT')   Or (U = 'TO')      Or
     (U = 'STEP')    Or (U = 'CASE')   Or (U = 'BEGIN')   Or
     (U = 'END')     Or (U = 'EXIT')   Or (U = 'LOOP')    Or
     (U = 'NIL')     Or (U = 'SELF')   Or (U = 'EACH')    Or
     (U = 'IN')      Or (U = 'WITH')   Or (U = 'CLASS') Then
  Begin
    ExpandKeyword := U;
    Exit;
  End;

  { Verifier les abreviations et retourner la forme complete }
  If (Length(U) >= 4) And (Copy('FUNCTION',   1, Length(U)) = U) Then Begin ExpandKeyword := 'FUNCTION';   Exit; End;
  If (Length(U) >= 4) And (Copy('PROCEDURE',  1, Length(U)) = U) Then Begin ExpandKeyword := 'PROCEDURE';  Exit; End;
  If (Length(U) >= 4) And (Copy('RETURN',     1, Length(U)) = U) Then Begin ExpandKeyword := 'RETURN';     Exit; End;
  If (Length(U) >= 4) And (Copy('PARAMETERS', 1, Length(U)) = U) Then Begin ExpandKeyword := 'PARAMETERS'; Exit; End;
  If (Length(U) >= 4) And (Copy('PRIVATE',    1, Length(U)) = U) Then Begin ExpandKeyword := 'PRIVATE';    Exit; End;
  If (Length(U) >= 4) And (Copy('PUBLIC',     1, Length(U)) = U) Then Begin ExpandKeyword := 'PUBLIC';     Exit; End;
  If (Length(U) >= 4) And (Copy('LOCAL',      1, Length(U)) = U) Then Begin ExpandKeyword := 'LOCAL';      Exit; End;
  If (Length(U) >= 4) And (Copy('STATIC',     1, Length(U)) = U) Then Begin ExpandKeyword := 'STATIC';     Exit; End;
  If (Length(U) >= 4) And (Copy('DECLARE',    1, Length(U)) = U) Then Begin ExpandKeyword := 'DECLARE';    Exit; End;
  If (Length(U) >= 4) And (Copy('OTHERWISE',  1, Length(U)) = U) Then Begin ExpandKeyword := 'OTHERWISE';  Exit; End;
  If (Length(U) >= 5) And (Copy('ELSEIF',     1, Length(U)) = U) Then Begin ExpandKeyword := 'ELSEIF';     Exit; End;
  If (Length(U) >= 4) And (Copy('SEQUENCE',   1, Length(U)) = U) Then Begin ExpandKeyword := 'SEQUENCE';   Exit; End;
  If (Length(U) >= 4) And (Copy('RECOVER',    1, Length(U)) = U) Then Begin ExpandKeyword := 'RECOVER';    Exit; End;
  If (Length(U) >= 4) And (Copy('ENDCASE',    1, Length(U)) = U) Then Begin ExpandKeyword := 'ENDCASE';    Exit; End;
  If (Length(U) >= 4) And (Copy('ENDIF',      1, Length(U)) = U) Then Begin ExpandKeyword := 'ENDIF';      Exit; End;
  If (Length(U) >= 4) And (Copy('ENDDO',      1, Length(U)) = U) Then Begin ExpandKeyword := 'ENDDO';      Exit; End;
  If (Length(U) >= 4) And (Copy('WHILE',      1, Length(U)) = U) Then Begin ExpandKeyword := 'WHILE';      Exit; End;

  { Mots-cles complets qui n ont pas d abreviation }
  ExpandKeyword := U;
End;

{ ---- PrintToken : affichage d un token pour debug ----------- }

Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF       : Write('EOF');
    TK_INTEGER   : Write('INT(', T.IntVal, ')');
    TK_FLOAT     : Write('FLOAT(', T.Val, ')');
    TK_STRING    : Write('STR("', T.Val, '")');
    TK_IDENT     : Write('IDENT(', T.Val, ')');
    TK_KEYWORD   : Write('KW(', T.Val, ')');
    TK_OP        : Write('OP(', T.Val, ')');
    TK_PUNCT     : Write('PUNCT(', T.Val, ')');
    TK_CODEBLOCK : Write('CODEBLOCK');
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

{ ---- LexInit : ouvrir le fichier source et initialiser ------ }

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened      := True;
  LexLineNo      := 0;
  LexColNo       := 1;
  LexEOF         := False;
  LexLine        := '';
  CurToken.Kind    := TK_EOF;
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { Lire la premiere ligne }
  LexNextLine;
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

{ ---- LexSkipBlockComment : sauter /* ... */ ----------------- }

Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); { sauter / et * }
  Done := False;
  While (Not LexEOF) And (Not Done) Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
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

{ ---- LexScanIdent : scanner un identificateur ou mot-cle ---- }
(* Clipper est insensible a la casse : on stocke en UPPER
   pour la reconnaissance des mots-cles.
   Les abreviations sont expansees vers la forme complete. *)

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
  If IsKeyword(U) Then
  Begin
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := ExpandKeyword(U);
  End
  Else
  Begin
    CurToken.Kind := TK_IDENT;
    CurToken.Val  := U;
  End;
  CurToken.IntVal := 0;
End;

{ ---- LexScanNumber : scanner un litteral numerique ---------- }
(* Supporte : entiers decimaux, hexadecimaux (0xFF),
   flottants (reconnus mais tronques a entier) *)

Procedure LexScanNumber;
Var
  N       : LongInt;
  Base    : Integer;
  IsFloat : Boolean;
  FracDiv : Real;
  FracVal : Real;
  Ch      : Char;
  FltVal  : Real;
Begin
  N       := 0;
  Base    := 10;
  IsFloat := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  Ch      := LexLine[LexColNo];

  { Detecter prefixe 0x }
  If (Ch = '0') And (LexColNo < Length(LexLine)) Then
  Begin
    Ch := LexLine[LexColNo + 1];
    If (Ch = 'x') Or (Ch = 'X') Then
    Begin
      Base := 16;
      Inc(LexColNo); Inc(LexColNo);
    End;
  End;

  { Scanner la partie entiere }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If (Base = 16) And IsHexDigit(Ch) Then
    Begin
      N := N * 16 + HexVal(Ch);
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

  { Calculer la valeur finale (tronquee a entier 16 bits) }
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
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

{ ---- LexScanString : scanner une chaine entre guillemets ---- }
(* Supporte les chaines entre guillemets simples et doubles.
   Pas de sequences d echappement en Clipper standard. *)

Procedure LexScanString(Quote : Char);
Var
  S     : TString;
  Ch    : Char;
  Found : Boolean;
Begin
  S := '';
  Found := False;
  Inc(LexColNo); { sauter guillemet ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = Quote Then
    Begin
      Inc(LexColNo);
      Found := True;
      Break;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  If Not Found Then
    WarnMsg('chaine non terminee');
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexScanBracketStr : scanner une chaine entre crochets -- }
(* Clipper supporte [texte] comme delimiteur de chaines *)

Procedure LexScanBracketStr;
Var
  S     : TString;
  Ch    : Char;
  Found : Boolean;
Begin
  S := '';
  Found := False;
  Inc(LexColNo); { sauter [ ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = ']' Then
    Begin
      Inc(LexColNo);
      Found := True;
      Break;
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  If Not Found Then
    WarnMsg('chaine entre crochets non terminee');
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

{ ---- LexNextToken : scanner principal ----------------------- }
(* Commentaires Clipper :
   - * en debut de ligne (premier caractere non-blanc)
   - // jusqu a fin de ligne
   - /* ... */ bloc multiligne
   - NOTE en debut de ligne (premier mot = NOTE)
   Operateurs speciaux : .AND. .OR. .NOT. .T. .F. .TRUE. .FALSE.
   Alias : -> (acces champ)
   Affectation : := (inline), =
   Comparaison : == (exact), != <> # (different)
   Compound : += -= *= /= %= **
*)

Procedure LexNextToken;
Var
  Ch, Ch2  : Char;
  Scanning : Boolean;
  SL, SC   : Integer;
  S        : TString;
  DotWord  : TString;
  I        : Integer;
  IsLineStart : Boolean;
Begin
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    { Passer les lignes vides }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Exit;
    End;

    Ch := LexLine[LexColNo];

    { Espaces et tabulations }
    If (Ch = ' ') Or (Ch = #9) Or (Ch = #13) Or (Ch = #12) Then
    Begin
      Inc(LexColNo);
    End

    { Commentaire * en debut de ligne (premier caractere non-blanc) }
    Else If (Ch = '*') Then
    Begin
      IsLineStart := True;
      For I := 1 To LexColNo - 1 Do
        If (LexLine[I] <> ' ') And (LexLine[I] <> #9) Then
          IsLineStart := False;
      If IsLineStart Then
        LexColNo := Length(LexLine) + 1
      Else
      Begin
        { Ce n est pas un commentaire, sortir de la boucle }
        Scanning := False;
      End;
    End

    { Commentaire // }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '/') Then
    Begin
      LexColNo := Length(LexLine) + 1;
    End

    { Commentaire /* ... */ }
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
    End

    Else
    Begin
      { Verifier si NOTE en debut de ligne (commentaire) }
      IsLineStart := True;
      For I := 1 To LexColNo - 1 Do
        If (LexLine[I] <> ' ') And (LexLine[I] <> #9) Then
          IsLineStart := False;
      If IsLineStart And (LexColNo + 3 <= Length(LexLine)) Then
      Begin
        S := StrUpperCase(Copy(LexLine, LexColNo, 4));
        If (S = 'NOTE') And
           ((LexColNo + 4 > Length(LexLine)) Or
            (Not IsIdentCont(LexLine[LexColNo + 4]))) Then
        Begin
          LexColNo := Length(LexLine) + 1;
          Continue;
        End;
      End;

      Scanning := False;
    End;
  End;

  SL := LexLineNo;
  SC := LexColNo;
  CurToken.Line := SL;
  CurToken.Col  := SC;
  Ch := LexLine[LexColNo];

  { ---- Identificateurs et mots-cles ---- }
  If IsIdentStart(Ch) Then
  Begin
    LexScanIdent;
    CurToken.Line := SL;
    CurToken.Col  := SC;
    Exit;
  End;

  { ---- Litteraux numeriques ---- }
  If (Ch >= '0') And (Ch <= '9') Then
  Begin
    LexScanNumber;
    CurToken.Line := SL;
    CurToken.Col  := SC;
    Exit;
  End;

  { ---- Chaines entre guillemets simples ---- }
  If Ch = '''' Then
  Begin
    LexScanString('''');
    CurToken.Line := SL;
    CurToken.Col  := SC;
    Exit;
  End;

  { ---- Chaines entre guillemets doubles ---- }
  If Ch = '"' Then
  Begin
    LexScanString('"');
    CurToken.Line := SL;
    CurToken.Col  := SC;
    Exit;
  End;

  { ---- Chaines entre crochets [texte] ou array subscript ---- }
  { En Clipper, [ est un delimiteur de chaine sauf apres un
    identificateur, ), ou ] ou un nombre - dans ce cas c est un subscript }
  If Ch = '[' Then
  Begin
    { Regarder le token precedent pour decider }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
       (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_FLOAT) Or
       ((CurToken.Kind = TK_PUNCT) And
        ((CurToken.Val = ')') Or (CurToken.Val = ']'))) Then
    Begin
      { Array subscript }
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '[';
      Inc(LexColNo);
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Exit;
    End
    Else
    Begin
      { Chaine entre crochets }
      LexScanBracketStr;
      CurToken.Line := SL;
      CurToken.Col  := SC;
      Exit;
    End;
  End;

  If Ch = ']' Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := ']';
    Inc(LexColNo);
    CurToken.Line := SL;
    CurToken.Col  := SC;
    Exit;
  End;

  { ---- Operateurs .AND. .OR. .NOT. .T. .F. .TRUE. .FALSE. ---- }
  If Ch = '.' Then
  Begin
    { Scanner le mot entre points }
    DotWord := '';
    I := LexColNo + 1;
    While (I <= Length(LexLine)) And (LexLine[I] <> '.') And
          (IsIdentCont(LexLine[I])) Do
    Begin
      DotWord := DotWord + LexLine[I];
      Inc(I);
    End;
    DotWord := StrUpperCase(DotWord);
    If (I <= Length(LexLine)) And (LexLine[I] = '.') Then
    Begin
      { .AND. .OR. .NOT. }
      If DotWord = 'AND' Then
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '.AND.';
        LexColNo := I + 1;
        Exit;
      End;
      If DotWord = 'OR' Then
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '.OR.';
        LexColNo := I + 1;
        Exit;
      End;
      If DotWord = 'NOT' Then
      Begin
        CurToken.Kind := TK_OP;
        CurToken.Val  := '.NOT.';
        LexColNo := I + 1;
        Exit;
      End;
      { .T. .TRUE. -> booleen vrai }
      If (DotWord = 'T') Or (DotWord = 'TRUE') Then
      Begin
        CurToken.Kind   := TK_KEYWORD;
        CurToken.Val    := '.T.';
        CurToken.IntVal := 1;
        LexColNo := I + 1;
        Exit;
      End;
      { .F. .FALSE. -> booleen faux }
      If (DotWord = 'F') Or (DotWord = 'FALSE') Then
      Begin
        CurToken.Kind   := TK_KEYWORD;
        CurToken.Val    := '.F.';
        CurToken.IntVal := 0;
        LexColNo := I + 1;
        Exit;
      End;
    End;
    { Simple point : operateur }
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := '.';
    Inc(LexColNo);
    Exit;
  End;

  { ---- Operateurs multi-caracteres ---- }
  Ch2 := #0;
  If LexColNo < Length(LexLine) Then
    Ch2 := LexLine[LexColNo + 1];

  { := affectation inline }
  If (Ch = ':') And (Ch2 = '=') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := ':=';
    Inc(LexColNo, 2);
    Exit;
  End;

  { == comparaison exacte }
  If (Ch = '=') And (Ch2 = '=') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '==';
    Inc(LexColNo, 2);
    Exit;
  End;

  { != different }
  If (Ch = '!') And (Ch2 = '=') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '!=';
    Inc(LexColNo, 2);
    Exit;
  End;

  { <> different }
  If (Ch = '<') And (Ch2 = '>') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '<>';
    Inc(LexColNo, 2);
    Exit;
  End;

  { <= }
  If (Ch = '<') And (Ch2 = '=') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '<=';
    Inc(LexColNo, 2);
    Exit;
  End;

  { >= }
  If (Ch = '>') And (Ch2 = '=') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '>=';
    Inc(LexColNo, 2);
    Exit;
  End;

  { -> alias }
  If (Ch = '-') And (Ch2 = '>') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '->';
    Inc(LexColNo, 2);
    Exit;
  End;

  { ** puissance }
  If (Ch = '*') And (Ch2 = '*') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '**';
    Inc(LexColNo, 2);
    Exit;
  End;

  { += -= *= /= %= compound }
  If (Ch2 = '=') And ((Ch = '+') Or (Ch = '-') Or (Ch = '*') Or
                       (Ch = '/') Or (Ch = '%')) Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := Ch + '=';
    Inc(LexColNo, 2);
    Exit;
  End;

  { ++ -- (pre/post increment/decrement) }
  If (Ch = '+') And (Ch2 = '+') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '++';
    Inc(LexColNo, 2);
    Exit;
  End;
  If (Ch = '-') And (Ch2 = '-') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := '--';
    Inc(LexColNo, 2);
    Exit;
  End;

  { ---- Operateurs simples ---- }
  If (Ch = '+') Or (Ch = '-') Or (Ch = '*') Or (Ch = '/') Or
     (Ch = '%') Or (Ch = '^') Or (Ch = '=') Or (Ch = '<') Or
     (Ch = '>') Or (Ch = '#') Or (Ch = '!') Or (Ch = '$') Or
     (Ch = '&') Or (Ch = '@') Then
  Begin
    CurToken.Kind := TK_OP;
    CurToken.Val  := Ch;
    Inc(LexColNo);
    Exit;
  End;

  { ---- Ponctuation ---- }
  If (Ch = '(') Or (Ch = ')') Or (Ch = ',') Or (Ch = ';') Or
     (Ch = ':') Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := Ch;
    Inc(LexColNo);
    Exit;
  End;

  { ---- ? et ?? : commandes d affichage Clipper ---- }
  If Ch = '?' Then
  Begin
    If (LexColNo < Length(LexLine)) And (LexLine[LexColNo + 1] = '?') Then
    Begin
      CurToken.Kind := TK_KEYWORD;
      CurToken.Val  := '??';
      Inc(LexColNo, 2);
      Exit;
    End;
    CurToken.Kind := TK_KEYWORD;
    CurToken.Val  := '?';
    Inc(LexColNo);
    Exit;
  End;

  { ---- Code block literal ---- }
  { En Clipper, un code block commence par une accolade ouvrante
    suivie d un pipe : |params| expr.
    On detecte l accolade ouvrante et on la marque comme
    debut potentiel de code block. }
  If Ch = '{' Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := '{';
    Inc(LexColNo);
    Exit;
  End;

  If Ch = '}' Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := '}';
    Inc(LexColNo);
    Exit;
  End;

  If Ch = '|' Then
  Begin
    CurToken.Kind := TK_PUNCT;
    CurToken.Val  := '|';
    Inc(LexColNo);
    Exit;
  End;

  { ---- Caractere inconnu ---- }
  CompileError('caractere inattendu: ' + Ch);
  Inc(LexColNo);
  LexNextToken; { relancer le scanner }
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAdd : ajouter une entree dans le segment DATA ----- }
(* Retourne l index dans DataTab ou -1 si plein.                *)

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
  DataTab[Idx].LblName := Lbl;
  DataTab[Idx].Kind    := Kind;
  DataTab[Idx].IntVal  := AIntVal;
  DataTab[Idx].StrVal  := AStrVal;
  Inc(DataCount);
  DataAdd := Idx;
End;

{ ---- DataAddStr : ajouter une chaine litterale avec dedup --- }
(* Reutilise les doublons : meme contenu -> meme label.
   Retourne l index dans DataTab, utilise comme Offset EK_MEM. *)

Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
  NS  : TString;
Begin
  { Rechercher un doublon existant }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  { Creer une nouvelle entree }
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  Lbl := CL_STR_PFX + NS;
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- DataAddWord : ajouter un mot 16 bits dans DATA -------- }

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

{ ---- ExprMakeNone : valeur invalide (void/erreur) ----------- }

Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeBool : construire un booleen Clipper ----------- }
(* .T. -> AX=1 (TY_IDX_LOGIC), .F. -> AX=0 (TY_IDX_LOGIC)    *)

Procedure ExprMakeBool(AVal : Integer; Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  If AVal <> 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
  Res.TypeIdx := TY_IDX_LOGIC;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- ExprMakeNil : construire une valeur NIL Clipper -------- }
(* NIL -> AX=0, type TY_IDX_NIL                                *)

Procedure ExprMakeNil(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_NIL;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

{ ---- LitEvalInt : convertir un token TK_INTEGER en valeur --- }
(* IntVal est deja calcule par LexScanNumber (decimal ou 0x).   *)

Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUM, Res);
End;

{ ---- LitEvalFloat : convertir TK_FLOAT -> int (trunc) ------ }
(* Clipper cible 8086 : pas de FPU, les flottants sont tronques *)

Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUM, Res);
End;

{ ---- LitEval : dispatcher principal pour les litteraux ------ }
(* Types de tokens acceptes :
   - TK_INTEGER -> entier decimal ou hexadecimal
   - TK_FLOAT   -> reel tronque a entier
   - TK_STRING  -> chaine dans le segment DATA
   - TK_KEYWORD -> .T. / .F. (booleens), NIL (valeur nulle)    *)

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
      Res.TypeIdx := TY_IDX_CHAR;
      Res.Offset  := DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
    TK_KEYWORD :
    Begin
      If (T.Val = '.T.') Then
        ExprMakeBool(1, Res)
      Else If (T.Val = '.F.') Then
        ExprMakeBool(0, Res)
      Else If (T.Val = 'NIL') Then
        ExprMakeNil(Res)
      Else
      Begin
        CompileError('mot-cle non utilisable comme litteral : ' + T.Val);
      End;
    End;
  Else
    CompileError('token non litterale : ' + T.Val);
  End;
End;

{ ---- EmitDataSeg : emettre le segment _DATA dans le .ASM ---- }
(* Appele en fin de compilation pour ecrire les constantes.
   Contient : chaines litterales (DK_STR), mots (DK_WORD),
   octets (DK_BYTE), et constantes predefinies Clipper.         *)

Procedure EmitDataSeg;
Var
  I  : Integer;
  J  : Integer;
  B  : Byte;
  NS : String[6];
Begin
  If Not OutFOpen Then Exit;
  If DataCount = 0 Then Exit;
  WriteLn(OutF);
  WriteLn(OutF, '_DATA   SEGMENT PUBLIC ''DATA''');
  WriteLn(OutF, '        ASSUME  DS:_DATA');
  { Constantes Clipper predefinies (utilisees par le runtime TODO 06+) }
  WriteLn(OutF, '_CL_NIL_S   DB  ''NIL'',0');
  WriteLn(OutF, '_CL_TRUE_S  DB  ''.T.'',0');
  WriteLn(OutF, '_CL_FALSE_S DB  ''.F.'',0');
  { Entrees DataTab }
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
    End;
  End;
  WriteLn(OutF, '_DATA   ENDS');
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

{ ---- LabelGen : generateur de labels uniques ---------------- }
(* Produit des labels de la forme _CLL_1, _CLL_2, ...
   Utilise le compteur global LabelSeq.                         *)

Function LabelGen : TString;
Var NS : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, NS);
  LabelGen := CL_LBL_PFX + NS;
End;

{ ---- Emetteur ASM minimaliste -------------------------------- }
(* Fonctions utilitaires pour ecrire dans le fichier .ASM.
   Formatage MASM standard : 8 espaces d indentation.           *)

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
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
    WriteLn(OutF, '        ', Mnem, '  ', A1);
End;

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '        ', Mnem, '  ', A1, ', ', A2);
End;

{ ---- ParserAdvance : lire le prochain token ------------------ }

Procedure ParserAdvance;
Begin
  LexNextToken;
End;

{ ---- IsAssignOp : tester si l operateur est une affectation --- }
(* Clipper : := (inline assign), += -= *= /= %= (compound)      *)

Function IsAssignOp(Const Op : TString) : Boolean;
Begin
  IsAssignOp :=
    (Op = ':=') Or (Op = '+=') Or (Op = '-=') Or
    (Op = '*=') Or (Op = '/=') Or (Op = '%=');
End;

{ ---- BinOpPrec : table de precedences Clipper (Pratt) -------- }
(* Niveaux (croissant = plus serre) :
     1 = := += -= *= /= %=   (affectation, plus faible)
     2 = .OR.
     3 = .AND.
     4 = == = != <> # < <= > >=   (comparaison)
     5 = $ (containment : sous-chaine)
     6 = + - (binaire et concatenation)
     7 = * / %
     8 = ** ^  (puissance)
   Retourne 0 si pas un operateur binaire reconnu.              *)

Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If IsAssignOp(Op) Then
    BinOpPrec := 1
  Else If Op = '.OR.' Then
    BinOpPrec := 2
  Else If Op = '.AND.' Then
    BinOpPrec := 3
  Else If (Op = '==') Or (Op = '=') Or (Op = '!=') Or
          (Op = '<>') Or (Op = '#') Or (Op = '<')  Or
          (Op = '<=') Or (Op = '>') Or (Op = '>=') Then
    BinOpPrec := 4
  Else If Op = '$' Then
    BinOpPrec := 5
  Else If (Op = '+') Or (Op = '-') Then
    BinOpPrec := 6
  Else If (Op = '*') Or (Op = '/') Or (Op = '%') Then
    BinOpPrec := 7
  Else If (Op = '**') Or (Op = '^') Then
    BinOpPrec := 8
  Else
    BinOpPrec := 0;
End;

{ ---- BinOpIsRight : associativite droite --------------------- }
(* En Clipper : puissance (**/ ^) et affectation sont droite-assoc *)

Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**') Or (Op = '^') Or IsAssignOp(Op);
End;

{ ---- ExprFlushToAX : materialiser la valeur dans AX ---------- }
(* Si la valeur est deja AX : rien a faire.
   Si immediate : MOV AX, imm.
   Si memoire : MOV AX, [label] (stub pour les variables TODO 05+).
   Si NONE : XOR AX, AX (valeur nulle par defaut).              *)

Procedure ExprFlushToAX(Var E : TExprVal);
Var NS : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, NS);
      EmitInstrAB('MOV', 'AX', NS);
      E.Kind := EK_AX;
    End;
    EK_MEM :
    Begin
      If (E.Offset >= 0) And (E.Offset < DataCount) Then
        EmitInstrAB('MOV', 'AX', 'OFFSET ' + DataTab[E.Offset].LblName)
      Else
        EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
    EK_NONE :
    Begin
      EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
    EK_AX : ; { deja dans AX }
  End;
End;

{ ---- ParsePrimary : atome du parseur Pratt ------------------- }
(* Gere : litteraux entiers, flottants, chaines, booleens
   (.T./.F.), NIL, identificateurs (stub), parentheses.
   Les variables/fonctions seront gerees par TODO 05+.           *)

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
      If (CurToken.Val = '.T.') Or (CurToken.Val = '.F.') Or
         (CurToken.Val = 'NIL') Then
      Begin
        LitEval(CurToken, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = 'SELF' Then
      Begin
        { SELF : stub, sera gere au TODO OOP }
        ExprMakeImm(0, TY_IDX_OBJECT, Res);
        ParserAdvance;
      End
      Else
      Begin
        { Mot-cle non-litteral (RETURN, IF, etc.) : pas une expression }
        ExprMakeNone(Res);
      End;
    End;
    TK_IDENT :
    Begin
      { Identificateur : stub pour TODO 05 (table des symboles) }
      { Pour l instant, les idents non reconnus deviennent EK_NONE }
      ExprMakeNone(Res);
      Res.TypeIdx := TY_UNKNOWN;
      ParserAdvance;
      { Appel de fonction : ident(...) - consommer les arguments }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        ParserAdvance; { consomme '(' }
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
        Begin
          ParseExpr(Res);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
      End;
    End;
    TK_PUNCT :
    Begin
      If CurToken.Val = '(' Then
      Begin
        ParserAdvance; { consomme '(' }
        ParseExpr(Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
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

{ ---- ParseUnary : operateurs unaires prefixe ----------------- }
(* Clipper unaires : - (negation), .NOT. ou ! (negation logique),
   + (identite, rien a faire).
   Pliage de constantes pour les cas immediats.                  *)

Procedure ParseUnary(Var Res : TExprVal);
Var
  Op       : TString;
  LblNotDn : TString;
Begin
  { Unaire - et + sur TK_OP }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '-') Or (Op = '+') Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Op = '-' Then
      Begin
        If Res.Kind = EK_IMM Then
          Res.ImmVal := -Res.ImmVal
        Else
        Begin
          ExprFlushToAX(Res);
          EmitInstr('NEG    AX');
          Res.Kind := EK_AX;
        End;
      End;
      { Op = '+' : rien a faire (identite) }
      Exit;
    End;
    { ! (negation logique en Clipper) }
    If Op = '!' Then
    Begin
      ParserAdvance;
      ParseUnary(Res);
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else
      Begin
        ExprFlushToAX(Res);
        LblNotDn := LabelGen;
        EmitInstrAB('CMP', 'AX', '0');
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JNZ', LblNotDn);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblNotDn);
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
      End;
      Exit;
    End;
  End;
  { .NOT. (mot-cle logique) }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '.NOT.') Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal = 0 Then Res.ImmVal := 1 Else Res.ImmVal := 0;
      Res.TypeIdx := TY_IDX_LOGIC;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      LblNotDn := LabelGen;
      EmitInstrAB('CMP', 'AX', '0');
      EmitInstrAB('MOV', 'AX', '0');
      EmitInstrA('JNZ', LblNotDn);
      EmitInstrAB('MOV', 'AX', '1');
      EmitLabel(LblNotDn);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_LOGIC;
    End;
    Exit;
  End;
  { Pas d operateur unaire : descendre vers ParsePrimary }
  ParsePrimary(Res);
End;

{ ---- ParseExprPrec : parseur de Pratt pour Clipper ----------- }
(* Boucle de montee de precedence avec :
   - Pliage de constantes pour +, -, *, /, %, comparaisons
   - Court-circuit .AND./.OR. via labels
   - Puissance ** / ^ via appel runtime _CLRT_POWER
   - Containment $ via appel runtime _CLRT_CONTAINS
   - Concatenation chaine + via appel runtime _CLRT_CONCAT
   - Affectation := += -= *= /= %= geree apres la boucle        *)

Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  LblSkip   : TString;
  LblEnd    : TString;
  ImmStr    : TString;
Begin
  ParseUnary(Res);
  Repeat
    Op   := '';
    Prec := 0;
    { Detecter operateur binaire (TK_OP) }
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End;
    { Arreter si fin, pas d operateur, ou priorite insuffisante }
    If (Prec = 0) Or (Prec < MinPrec) Then Break;
    { Affectation traitee apres la boucle }
    If IsAssignOp(Op) Then Break;

    ParserAdvance; { consommer l operateur }

    { --- Court-circuit .AND. --- }
    If Op = '.AND.' Then
    Begin
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal = 0 Then
        Begin
          { Gauche faux : resultat = .F., ne pas evaluer droite }
          ParseExprPrec(Prec + 1, Right);
          ExprMakeBool(0, Res);
        End
        Else
        Begin
          ParseExprPrec(Prec + 1, Right);
          If Right.Kind = EK_IMM Then
          Begin
            If Right.ImmVal <> 0 Then ExprMakeBool(1, Res)
            Else ExprMakeBool(0, Res);
          End
          Else
          Begin
            ExprFlushToAX(Right);
            Res.Kind    := EK_AX;
            Res.TypeIdx := TY_IDX_LOGIC;
          End;
        End;
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
        Res.TypeIdx := TY_IDX_LOGIC;
      End;
      Continue;
    End;

    { --- Court-circuit .OR. --- }
    If Op = '.OR.' Then
    Begin
      If Res.Kind = EK_IMM Then
      Begin
        If Res.ImmVal <> 0 Then
        Begin
          { Gauche vrai : resultat = .T., ne pas evaluer droite }
          ParseExprPrec(Prec + 1, Right);
          ExprMakeBool(1, Res);
        End
        Else
        Begin
          ParseExprPrec(Prec + 1, Right);
          If Right.Kind = EK_IMM Then
          Begin
            If Right.ImmVal <> 0 Then ExprMakeBool(1, Res)
            Else ExprMakeBool(0, Res);
          End
          Else
          Begin
            ExprFlushToAX(Right);
            Res.Kind    := EK_AX;
            Res.TypeIdx := TY_IDX_LOGIC;
          End;
        End;
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
        Res.TypeIdx := TY_IDX_LOGIC;
      End;
      Continue;
    End;

    { --- Sauvegarder operande gauche --- }
    LeftIsImm := (Res.Kind = EK_IMM);
    LeftImm   := Res.ImmVal;
    If Not LeftIsImm Then
    Begin
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
    End;

    { --- Recurser cote droit --- }
    If BinOpIsRight(Op) Then
      ParseExprPrec(Prec, Right)
    Else
      ParseExprPrec(Prec + 1, Right);

    { --- Pliage de constantes --- }
    If LeftIsImm And (Right.Kind = EK_IMM) Then
    Begin
      { Arithmetique }
      If Op = '+' Then
        ExprMakeImm(LeftImm + Right.ImmVal, TY_IDX_NUM, Res)
      Else If Op = '-' Then
        ExprMakeImm(LeftImm - Right.ImmVal, TY_IDX_NUM, Res)
      Else If Op = '*' Then
        ExprMakeImm(LeftImm * Right.ImmVal, TY_IDX_NUM, Res)
      Else If (Op = '/') And (Right.ImmVal <> 0) Then
        ExprMakeImm(LeftImm Div Right.ImmVal, TY_IDX_NUM, Res)
      Else If (Op = '%') And (Right.ImmVal <> 0) Then
        ExprMakeImm(LeftImm Mod Right.ImmVal, TY_IDX_NUM, Res)
      { Comparaison }
      Else If (Op = '==') Or (Op = '=') Then
        ExprMakeBool(Ord(LeftImm = Right.ImmVal), Res)
      Else If (Op = '!=') Or (Op = '<>') Or (Op = '#') Then
        ExprMakeBool(Ord(LeftImm <> Right.ImmVal), Res)
      Else If Op = '<' Then
        ExprMakeBool(Ord(LeftImm < Right.ImmVal), Res)
      Else If Op = '<=' Then
        ExprMakeBool(Ord(LeftImm <= Right.ImmVal), Res)
      Else If Op = '>' Then
        ExprMakeBool(Ord(LeftImm > Right.ImmVal), Res)
      Else If Op = '>=' Then
        ExprMakeBool(Ord(LeftImm >= Right.ImmVal), Res)
      { Puissance }
      Else If (Op = '**') Or (Op = '^') Then
      Begin
        { Puissance constante simple }
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx  := -1;
      End
      { Containment $ }
      Else If Op = '$' Then
      Begin
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx  := -1;
      End
      Else
      Begin
        Res.Kind    := EK_AX;
        Res.TypeIdx := TY_UNKNOWN;
        Res.SymIdx  := -1;
      End;
    End
    Else
    Begin
      { --- Emission de code pour operations non-constantes --- }
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      If Not LeftIsImm Then
        EmitInstr('POP    AX')
      Else
      Begin
        Str(LeftImm, ImmStr);
        EmitInstrAB('MOV', 'AX', ImmStr);
      End;
      { Emettre l operation }
      If Op = '+' Then
        EmitInstrAB('ADD', 'AX', 'BX')
      Else If Op = '-' Then
        EmitInstrAB('SUB', 'AX', 'BX')
      Else If Op = '*' Then
        EmitInstrA('IMUL', 'BX')
      Else If (Op = '/') Then
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
      Else If (Op = '**') Or (Op = '^') Then
      Begin
        { Puissance : appel runtime _CLRT_POWER(AX=base, BX=exp) }
        EmitInstrA('PUSH', 'BX');
        EmitInstrA('PUSH', 'AX');
        EmitInstrA('CALL', CL_RT_PFX + 'POWER');
        EmitInstrAB('ADD', 'SP', '4');
      End
      Else If Op = '$' Then
      Begin
        { Containment $ : appel runtime _CLRT_CONTAINS(AX=sub, BX=str) }
        EmitInstrA('PUSH', 'BX');
        EmitInstrA('PUSH', 'AX');
        EmitInstrA('CALL', CL_RT_PFX + 'CONTAINS');
        EmitInstrAB('ADD', 'SP', '4');
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If (Op = '==') Or (Op = '=') Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JE', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If (Op = '!=') Or (Op = '<>') Or (Op = '#') Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JNE', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If Op = '<' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JL', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If Op = '<=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JLE', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If Op = '>' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JG', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else If Op = '>=' Then
      Begin
        LblSkip := LabelGen;
        LblEnd  := LabelGen;
        EmitInstrAB('CMP', 'AX', 'BX');
        EmitInstrA('JGE', LblSkip);
        EmitInstrAB('MOV', 'AX', '0');
        EmitInstrA('JMP', LblEnd);
        EmitLabel(LblSkip);
        EmitInstrAB('MOV', 'AX', '1');
        EmitLabel(LblEnd);
        Res.TypeIdx := TY_IDX_LOGIC;
      End
      Else
      Begin
        { Operateur inconnu : stub }
        If Opts.Warnings Then
          WarnMsg('operateur binaire "' + Op + '" : stub');
      End;
      Res.Kind   := EK_AX;
      Res.SymIdx := -1;
    End;
  Until False;

  { --- Operateurs d affectation (:= += -= *= /= %=) --- }
  If (CurToken.Kind = TK_OP) And IsAssignOp(CurToken.Val) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    ParseExprPrec(1, Right); { droite-associatif }
    { L affectation sera completee au TODO 05 (SymTab) }
    { Pour l instant : evaluer la droite, resultat dans AX }
    ExprFlushToAX(Right);
    Res.Kind    := EK_AX;
    Res.TypeIdx := Right.TypeIdx;
    Res.SymIdx  := -1;
    If (Op <> ':=') And Opts.Warnings Then
      WarnMsg('affectation composee "' + Op + '" : stub, sera gere au TODO 05');
  End;
End;

{ ---- ParseExpr : point d entree principal pour les expressions }
(* Appelle ParseExprPrec avec MinPrec=1 pour capturer tous les
   niveaux de precedence, y compris l affectation.               *)

Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

{ ---- StrUpper : convertir une chaine en majuscules ----------- }
(* Clipper est case-insensitive : les noms sont stockes en UPPER. *)

Function StrUpper(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  StrUpper := R;
End;

{ ---- SymNameClean : nettoyer un nom pour label ASM ----------- }
(* Remplace les caracteres non alphanumeriques par '_'.
   En Clipper les noms sont case-insensitive (UPPER interne).    *)

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

{ ---- SymMangle : construire l etiquette ASM d un symbole ----- }
(* Associe un prefixe ASM selon la categorie :
     SC_LOCAL   : _CLV_ + nom  (variable locale, acces [BP-n])
     SC_STATIC  : _CLS_ + nom  (STATIC, persiste en DATA)
     SC_PRIVATE : _CLV_ + nom  (PRIVATE, comme locale)
     SC_PUBLIC  : _CLG_ + nom  (PUBLIC, globale)
     SC_PARAM   : ''           (parametre, acces [BP+n])
     SC_FIELD   : _CLF_ + nom  (champ FIELD de base de donnees)
     SC_MEMVAR  : _CLV_ + nom  (variable memoire explicite)
     SC_FUNC    : _CLP_ + nom  (FUNCTION)
     SC_PROC    : _CLP_ + nom  (PROCEDURE)
     SC_ALIAS   : _CLA_ + nom  (alias DBF)                      *)

Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Cat Of
    SC_LOCAL   : SymMangle := CL_VAR_PFX  + Clean;
    SC_STATIC  : SymMangle := CL_STAT_PFX + Clean;
    SC_PRIVATE : SymMangle := CL_VAR_PFX  + Clean;
    SC_PUBLIC  : SymMangle := CL_GLB_PFX  + Clean;
    SC_PARAM   : SymMangle := '';
    SC_FIELD   : SymMangle := CL_FLD_PFX   + Clean;
    SC_MEMVAR  : SymMangle := CL_VAR_PFX  + Clean;
    SC_FUNC    : SymMangle := CL_FN_PFX   + Clean;
    SC_PROC    : SymMangle := CL_FN_PFX   + Clean;
    SC_ALIAS   : SymMangle := CL_ALIAS_PFX + Clean;
  Else
    SymMangle := CL_LBL_PFX + Clean;
  End;
End;

{ ---- SymFind : rechercher un symbole (interne -> global) ----- }
(* Parcourt la table du plus recent au plus ancien (MRU-first).
   Retourne l indice ou -1 si non trouve.
   Clipper est case-insensitive : on compare les noms UPPER.     *)

Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
  UName : TString;
Begin
  UName := StrUpper(Name);
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = UName Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

{ ---- SymFindInScope : rechercher dans la portee courante ----- }
(* Recherche uniquement parmi les symboles ajoutes dans le scope
   courant (depuis le dernier SymEnterScope).                    *)

Function SymFindInScope(Const Name : TString) : Integer;
Var
  I     : Integer;
  Start : Integer;
  UName : TString;
Begin
  UName := StrUpper(Name);
  If ScopeTop > 0 Then
    Start := ScopeStack[ScopeTop - 1]
  Else
    Start := 0;
  For I := SymCount - 1 DownTo Start Do
    If SymTab[I].Name = UName Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

{ ---- SymAdd : ajouter un symbole dans la table --------------- }
(* Ajoute une entree, applique le mangling, retourne l indice.
   Le nom est stocke en UPPER (convention Clipper).
   Trace de debug si option -d activee.                          *)

Function SymAdd(Const Name : TString; Cat : TSymCat;
                ATypeIdx, AOffset : Integer) : Integer;
Var
  Idx   : Integer;
  UName : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  { Convertir en UPPER (Clipper est case-insensitive) }
  UName := StrUpper(Name);

  Idx := SymCount;
  SymTab[Idx].Name        := UName;
  SymTab[Idx].MangledName := SymMangle(UName, Cat);
  SymTab[Idx].Cat         := Cat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].IsInit      := False;
  SymTab[Idx].ArraySize   := 0;
  SymTab[Idx].DeclLine    := CurToken.Line;

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', UName,
            ' cat=', Ord(Cat),
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  Inc(SymCount);
  Inc(TotalSyms);
  SymAdd := Idx;
End;

{ ---- SymEnterScope : entrer dans une nouvelle portee --------- }
(* Empile le nombre courant de symboles pour pouvoir restaurer
   lors du SymLeaveScope.  Utilise par FUNCTION/PROCEDURE/DO.    *)

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
End;

{ ---- SymLeaveScope : quitter la portee courante -------------- }
(* Restaure SymCount a la valeur sauvegardee, retirant tous les
   symboles locaux de cette portee.                              *)

Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
End;

{ ---- SymInit : initialiser la table et predeclarer les builtins }
(* Remet la table a zero puis ajoute les symboles predeclares
   de Clipper : fonctions standard, variables predefinies.
   Portees Clipper :
     PUBLIC  : visible partout (prefixe _CLG_)
     PRIVATE : visible dans la routine courante et sous-routines
     LOCAL   : visible uniquement dans la routine courante (pile)
     STATIC  : visible dans la routine, persiste entre appels (DATA)
     FIELD   : acces champ de la base de donnees courante
     MEMVAR  : variable memoire explicite (MEMVAR->nom)           *)

Procedure SymInit;
Begin
  SymCount  := 0;
  ScopeTop  := 0;
  CurScope  := 0;
  TotalSyms := 0;

  { --- Fonctions standard Clipper --- }
  { Sortie ecran }
  SymAdd('QOUT',     SC_FUNC, TY_IDX_NIL, 0);   { ? }
  SymAdd('QQOUT',    SC_FUNC, TY_IDX_NIL, 0);   { ?? }
  SymAdd('OUTSTD',   SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('OUTERR',   SC_FUNC, TY_IDX_NIL, 0);

  { Conversion et types }
  SymAdd('VALTYPE',  SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('TYPE',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('STR',      SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('VAL',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('CTOD',     SC_FUNC, TY_IDX_DATE, 0);
  SymAdd('DTOC',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('DTOS',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('CHR',      SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('ASC',      SC_FUNC, TY_IDX_NUM, 0);

  { Chaines }
  SymAdd('LEN',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('SUBSTR',   SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('LEFT',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('RIGHT',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('AT',       SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('TRIM',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('RTRIM',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('LTRIM',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('ALLTRIM',  SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('UPPER',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('LOWER',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('STRTRAN',  SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('REPLICATE',SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('SPACE',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('PADR',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('PADL',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('PADC',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('STUFF',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('EMPTY',    SC_FUNC, TY_IDX_LOGIC, 0);

  { Mathematiques }
  SymAdd('ABS',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('INT',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('ROUND',    SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('MAX',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('MIN',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('MOD',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('SQRT',     SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('LOG',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('EXP',      SC_FUNC, TY_IDX_NUM, 0);

  { Tableaux }
  SymAdd('ARRAY',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('AADD',     SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ASIZE',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ADEL',     SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('AINS',     SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ASORT',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ASCAN',    SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('AEVAL',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ACOPY',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('AFILL',    SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ACLONE',   SC_FUNC, TY_IDX_ARRAY, 0);
  SymAdd('ATAIL',    SC_FUNC, TY_IDX_NIL, 0);

  { Code blocks }
  SymAdd('EVAL',     SC_FUNC, TY_IDX_NIL, 0);

  { Base de donnees }
  SymAdd('DBEVAL',   SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('RECNO',    SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('RECCOUNT', SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('BOF',      SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('EOF',      SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('FOUND',    SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('DELETED',  SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('LASTREC',  SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('FIELDNAME',SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('FCOUNT',   SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('SELECT',   SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('ALIAS',    SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('USED',     SC_FUNC, TY_IDX_LOGIC, 0);

  { Date et heure }
  SymAdd('DATE',     SC_FUNC, TY_IDX_DATE, 0);
  SymAdd('TIME',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('DAY',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('MONTH',    SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('YEAR',     SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('DOW',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('CDOW',     SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('CMONTH',   SC_FUNC, TY_IDX_CHAR, 0);

  { Divers }
  SymAdd('INKEY',    SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('ROW',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('COL',      SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('SETPOS',   SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('DEVPOS',   SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('SCROLL',   SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('TONE',     SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('ERRORBLOCK',SC_FUNC, TY_IDX_BLOCK, 0);
  SymAdd('BREAK',    SC_FUNC, TY_IDX_NIL, 0);
  SymAdd('QUIT',     SC_PROC, TY_IDX_NIL, 0);
  SymAdd('ISPRINTER',SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('DOSERROR', SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('NETERR',   SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('FILE',     SC_FUNC, TY_IDX_LOGIC, 0);
  SymAdd('CURDIR',   SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('MEMORY',   SC_FUNC, TY_IDX_NUM, 0);
  SymAdd('OS',       SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('VERSION',  SC_FUNC, TY_IDX_CHAR, 0);
  SymAdd('CLIPPER',  SC_FUNC, TY_IDX_CHAR, 0);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
End.
