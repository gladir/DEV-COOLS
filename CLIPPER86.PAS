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

  TODO 02 - LEXEUR (TOKENS CLIPPER)
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

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..65535 ou -32768..32767
            Entiers hexadecimaux : 0xFF ou 0x1A
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines : 'abc' ou "abc" ou [abc] -> pointeur vers donnees DATA
            Dates litterales : CTOD("MM/DD/YY") -> entier julien interne
            Booleens : .T. / .TRUE. -> AX=1, .F. / .FALSE. -> AX=0
            NIL : valeur nulle -> AX=0 (type NIL, variable non initialisee)
            Constantes predefinies : .T., .F., NIL

  TODO 04 - OPERATEURS ET PRECEDENCE
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

  TODO 05 - TABLE DES SYMBOLES
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
  STACK_SIZE    = 1024;

  { Prefixes de nommage ASM }
  CL_VAR_PFX   = '_CLV_';    { variable locale / globale            }
  CL_FN_PFX    = '_CLP_';    { procedure / fonction                 }
  CL_STR_PFX   = '_CLK_';    { constante chaine litterale           }
  CL_RT_PFX    = '_CLRT_';   { routine runtime                      }
  CL_LBL_PFX   = '_CLL_';    { label de saut interne                }
  CL_GLB_PFX   = '_CLG_';    { variable PUBLIC globale              }
  CL_STAT_PFX  = '_CLS_';    { variable STATIC                      }
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
End;

{ ---- Affichage des statistiques ----------------------------- }

Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('  Lignes sources : ', TotalLines);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ---- Pipeline de compilation (stub) ------------------------ }

Procedure Run;
Begin
  GlobalInit;
  If Opts.Verbose Then
    ShowBanner;

  { TODO 02..25 : implementation a venir }
  WriteLn('CLIPPER86: compilation non encore implementee (TODO 02-25)');

  If Opts.Verbose Then
    ShowStats;

  Cleanup;

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
