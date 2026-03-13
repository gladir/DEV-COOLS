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

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
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

  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
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

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_TAGGED),
              IntVal, StrVal, TagVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddTagged : variantes d ajout
            Variables PUBLIC : segment DATA avec tag + valeur (_CLG_nom)
            Variables STATIC : segment DATA avec tag + valeur (_CLS_nom)
            Chaines litterales : DB 'abc',0 dans DATA avec label _CLK_N
            Dates litterales : DW valeur_julienne dans DATA
            Tableaux statiques : bloc (tag, ptr_elements) dans DATA

  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
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

  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
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

  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
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

  TODO 12 - ENTREES/SORTIES ECRAN [IMPLEMENTE]
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

  TODO 13 - IF / ELSEIF / ELSE / DO CASE [IMPLEMENTE]
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

  TODO 14 - BOUCLES : DO WHILE / FOR / FOR EACH / LOOP / EXIT [IMPLEMENTE]
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

  TODO 15 - TABLEAUX [IMPLEMENTE]
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

  TODO 16 - CHAINES DE CARACTERES [IMPLEMENTE]
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

  TODO 17 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
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

  TODO 18 - CODE BLOCKS ET EVAL [IMPLEMENTE]
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

  TODO 19 - FICHIERS DBF (BASE DE DONNEES) [IMPLEMENTE]
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

  TODO 20 - INDEX ET RECHERCHE (NTX/NDX) [IMPLEMENTE]
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
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  STACK_SIZE    = 1024;
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_HEAP_SIZE = 4096;  { taille du heap en octets pour tableaux }
  MAX_ARRAY_ELEM = 64;   { nombre maximum d elements par tableau  }
  MAX_STR_BUF  = 256;   { taille buffer pour operations chaines }
  MAX_WORK_AREAS = 10;   { nombre maximum de work areas DBF       }
  MAX_DBF_REC_SIZE = 512; { taille max d un enregistrement DBF    }
  MAX_DBF_FIELDS = 32;   { nombre max de champs par fichier DBF   }

  { Indices de types primitifs Clipper }
  TY_IDX_NIL    = 0;     { NIL : valeur non initialisee          }
  TY_IDX_NUM    = 1;     { NUMERIC : entier 16 bits signe        }
  TY_IDX_CHAR   = 2;     { CHARACTER : pointeur vers chaine      }
  TY_IDX_DATE   = 3;     { DATE : entier julien 16 bits          }
  TY_IDX_LOGIC  = 4;     { LOGICAL : 0 (.F.) ou 1 (.T.)         }
  TY_IDX_ARRAY  = 5;     { ARRAY : pointeur vers bloc tableau    }
  TY_IDX_BLOCK  = 6;     { CODEBLOCK : pointeur vers descripteur }
  TY_IDX_OBJECT = 7;     { OBJECT : pointeur vers instance       }
  TY_PRIM_COUNT = 8;     { nombre de types primitifs              }

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

  { ---- Segment de donnees (TODO 03 + TODO 08) ---------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_TAGGED);

  TDataRec = Record
    LblName : TString;     { label ASM de l entree                }
    Kind    : TDataKind;   { type de donnee                       }
    IntVal  : LongInt;     { valeur entiere (DK_WORD/DK_BYTE)     }
    StrVal  : TString;     { contenu chaine (DK_STR)              }
    TagVal  : Integer;     { tag de type Clipper (DK_TAGGED)      }
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

  { ---- Systeme de types (TODO 06) ----------------------------- }
  TTypeTag = (
    TT_NIL,        { valeur non initialisee                      }
    TT_NUMERIC,    { entier 16 bits signe                        }
    TT_CHARACTER,  { pointeur vers chaine terminee par 0         }
    TT_DATE,       { entier julien 16 bits                       }
    TT_LOGICAL,    { 0 (.F.) ou 1 (.T.)                         }
    TT_ARRAY,      { pointeur vers bloc tableau en heap          }
    TT_CODEBLOCK,  { pointeur vers descripteur de code block     }
    TT_OBJECT,     { pointeur vers instance objet                }
    TT_UNKNOWN     { type inconnu / polymorphe                   }
  );

  TTypeRec = Record
    Name : TString;      { nom du type (UPPER)                    }
    Tag  : TTypeTag;     { tag de type Clipper                    }
    Size : Integer;      { taille en octets (2 pour 16-bit)       }
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

  { Emetteur ASM (TODO 07) }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;    { taille cadre local courant (words)   }
  CurFnRetLbl  : TString;    { label epilogue de la function        }

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

  { Variables et affectations (TODO 09) }
  SymNextOffset   : Integer;   { prochain offset pile pour locals [BP-n] }
  ParamNextOffset : Integer;   { prochain offset pile pour params [BP+n] }

  { Table des types (TODO 06) }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;     { nombre d entrees dans TypeTab          }

  { Pile de boucles pour LOOP/EXIT (TODO 14) }
  LoopContLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopBrkLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopTop     : Integer;   { profondeur d imbrication des boucles   }

  { Heap pour tableaux dynamiques (TODO 15) }
  ArrayTempCount : Integer;   { compteur de tableaux temporaires     }

  { Procedures et fonctions (TODO 17) }
  InFuncDecl     : Boolean;   { True si on est dans une FUNCTION     }
  InProcDecl     : Boolean;   { True si on est dans une PROCEDURE    }
  CurFuncName    : TString;   { nom de la fonction/procedure courante}
  SaveFrameSize  : Integer;   { sauvegarde CurFrameSize de l appelant}
  SaveFnRetLbl   : TString;   { sauvegarde CurFnRetLbl de l appelant }
  SaveSymOffset  : Integer;   { sauvegarde SymNextOffset             }
  SaveParamOfs   : Integer;   { sauvegarde ParamNextOffset           }
  InitProcTab    : Array[0..15] Of TString;
  InitProcCount  : Integer;   { nombre de INIT PROCEDURE             }
  ExitProcTab    : Array[0..15] Of TString;
  ExitProcCount  : Integer;   { nombre de EXIT PROCEDURE             }

  { Code blocks (TODO 18) }
  CodeBlockCount : Integer;   { compteur de code blocks generes      }

  { Work areas DBF (TODO 19) }
  CurWorkArea    : Integer;   { zone de travail active (1..10)       }

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
{ Segment de donnees et statiques (TODO 08) }
Function  DataAddTagged(Const Lbl : TString;
                        ATagVal : Integer; AIntVal : LongInt;
                        Const AStrVal : TString) : Integer; Forward;
Function  DataAddPublicVar(Const Name : TString;
                           ATypeIdx : Integer;
                           AInitVal : LongInt) : Integer; Forward;
Function  DataAddStaticVar(Const Name : TString;
                           ATypeIdx : Integer;
                           AInitVal : LongInt) : Integer; Forward;
Function  DataAddDate(Const Lbl : TString;
                      JulianVal : LongInt) : Integer; Forward;
Function  DataAddArray(Const Lbl : TString;
                       ElemCount : Integer) : Integer; Forward;
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
{ Systeme de types (TODO 06) }
Function  TypeKindOf(TypeIdx : Integer) : TTypeTag; Forward;
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
Procedure EmitBlankLine; Forward;
Procedure EmitOpen; Forward;
Procedure EmitHeader; Forward;
Procedure EmitProlog; Forward;
Procedure EmitEpilog; Forward;
Procedure EmitRuntime; Forward;
Procedure EmitClose; Forward;
{ Variables et affectations (TODO 09) }
Function  ExprAddrOf(SIdx : Integer) : TString; Forward;
Procedure ExprStore(SIdx : Integer); Forward;
Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal); Forward;
Function  DeclAllocSym(Const Name : TString;
                       Cat : TSymCat) : Integer; Forward;
Procedure DeclInitUndef(SIdx : Integer); Forward;
Procedure ParseDeclStmt(Const Kw : TString); Forward;
Procedure ParseStoreStmt; Forward;
Procedure ParseExprStmt; Forward;
{ Expressions primaires (TODO 10) }
Procedure ParseIIF(Var Res : TExprVal); Forward;
Procedure ParseEVAL(Var Res : TExprVal); Forward;
Procedure ParseFieldAccess(Const AliasName : TString;
                           Var Res : TExprVal); Forward;
Procedure ParseArrayAccess(Var Res : TExprVal); Forward;
Procedure ParseMacro(Var Res : TExprVal); Forward;
Procedure ParseFuncCall(SIdx : Integer; Var Res : TExprVal); Forward;
{ Expressions binaires (TODO 11) }
Procedure EmitExprRuntime; Forward;
{ Entrees/sorties ecran (TODO 12) }
Procedure EmitIORuntime; Forward;
Procedure ParseQOutStmt(WithCRLF : Boolean); Forward;
Procedure ParseAtStmt; Forward;
Procedure ParseReadStmt; Forward;
Procedure ParseClearStmt; Forward;
Procedure ParseSetColorStmt; Forward;
{ IF/ELSEIF/ELSE/ENDIF et DO CASE (TODO 13) }
Procedure ParseIfStmt; Forward;
Procedure ParseDoCaseStmt; Forward;
{ Boucles DO WHILE / FOR / FOR EACH (TODO 14) }
Procedure LoopPush(Const ContLbl, BrkLbl : TString); Forward;
Procedure LoopPop; Forward;
Procedure ParseDoWhileStmt; Forward;
Procedure ParseForStmt; Forward;
Procedure ParseForEachStmt; Forward;

{ Tableaux (TODO 15) }
Procedure EmitArrayRuntime; Forward;
Procedure ParseArrayLiteral(Var Res : TExprVal); Forward;

{ Chaines de caracteres (TODO 16) }
Procedure EmitStringRuntime; Forward;

{ Procedures et fonctions (TODO 17) }
Procedure ParseFuncDecl; Forward;
Procedure ParseProcDecl; Forward;
Procedure ParseReturnStmt; Forward;
Procedure ParseDoCallStmt; Forward;

{ Code blocks (TODO 18) }
Procedure ParseCodeBlock(Var Res : TExprVal); Forward;
Procedure EmitCodeBlockRuntime; Forward;

{ Fichiers DBF (TODO 19) }
Procedure ParseUseStmt; Forward;
Procedure ParseSelectStmt; Forward;
Procedure ParseCloseStmt; Forward;
Procedure ParseGoStmt; Forward;
Procedure ParseSkipStmt; Forward;
Procedure ParseAppendStmt; Forward;
Procedure ParseReplaceStmt; Forward;
Procedure ParseDeleteStmt; Forward;
Procedure ParseRecallStmt; Forward;
Procedure ParsePackStmt; Forward;
Procedure ParseZapStmt; Forward;
Procedure EmitDBFRuntime; Forward;

{ Index et recherche (TODO 20) }
Procedure ParseIndexStmt; Forward;
Procedure ParseSeekStmt; Forward;
Procedure ParseLocateStmt; Forward;
Procedure ParseContinueStmt; Forward;
Procedure ParseReindexStmt; Forward;
Procedure EmitIdxRuntime; Forward;

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
  ErrorCount   := 0;
  WarnCount    := 0;
  TotalLines   := 0;
  OutFOpen     := False;
  DataCount    := 0;
  LabelSeq     := 0;
  CurFrameSize := 0;
  CurFnRetLbl  := '';
  SymNextOffset := 0;
  ParamNextOffset := 4;   { [BP+4] est le premier parametre }
  LoopTop      := 0;
  ArrayTempCount := 0;
  InFuncDecl   := False;
  InProcDecl   := False;
  CurFuncName  := '';
  SaveFrameSize := 0;
  SaveFnRetLbl := '';
  SaveSymOffset := 0;
  SaveParamOfs := 0;
  InitProcCount := 0;
  ExitProcCount := 0;
  CodeBlockCount := 0;
  TypeInit;
  SymInit;
End;

{ ---- Affichage des statistiques ----------------------------- }

Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('  Lignes sources : ', TotalLines);
  WriteLn('  Symboles       : ', TotalSyms);
  WriteLn('  Types          : ', TypeCount);
  WriteLn('  Donnees DATA   : ', DataCount);
  WriteLn('  Erreurs        : ', ErrorCount);
  WriteLn('  Avertissements : ', WarnCount);
End;

{ ---- Pipeline de compilation -------------------------------- }

Procedure Run;
Var
  Kw : TString;
  SetExpr    : TExprVal;   { temporaire pour SET ... (TODO 20) }
  SetDataIdx : Integer;    { index DataTab pour SET RELATION (TODO 20) }
Begin
  GlobalInit;
  If Opts.Verbose Then
    ShowBanner;

  EmitOpen;
  EmitHeader;
  LexInit;

  { Lire le premier token }
  LexNextToken;

  { Boucle principale de compilation }
  While CurToken.Kind <> TK_EOF Do
  Begin
    If Opts.DebugMode Then
      PrintToken(CurToken);

    { Dispatch selon le type de token }
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      Kw := CurToken.Val;
      { Declarations de variables (TODO 09) }
      If (Kw = 'LOCAL') Or (Kw = 'LOCA') Or
         (Kw = 'STATIC') Or (Kw = 'STAT') Or
         (Kw = 'PRIVATE') Or (Kw = 'PRIV') Or
         (Kw = 'PUBLIC') Or (Kw = 'PUBL') Or
         (Kw = 'DECLARE') Or (Kw = 'DECL') Or
         (Kw = 'PARAMETERS') Or (Kw = 'PARA') Then
      Begin
        { Normaliser les abreviations }
        If (Kw = 'LOCA') Then Kw := 'LOCAL';
        If (Kw = 'STAT') Then Kw := 'STATIC';
        If (Kw = 'PRIV') Then Kw := 'PRIVATE';
        If (Kw = 'PUBL') Then Kw := 'PUBLIC';
        If (Kw = 'DECL') Then Kw := 'DECLARE';
        If (Kw = 'PARA') Then Kw := 'PARAMETERS';
        ParserAdvance; { consommer le mot-cle }
        ParseDeclStmt(Kw);
      End
      { STORE expr TO var1, var2 ... (TODO 09) }
      Else If Kw = 'STORE' Then
      Begin
        ParserAdvance; { consommer STORE }
        ParseStoreStmt;
      End
      { ? : affichage avec retour a la ligne (TODO 12) }
      Else If Kw = '?' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(True);
      End
      { ?? : affichage sans retour a la ligne (TODO 12) }
      Else If Kw = '??' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(False);
      End
      { READ (TODO 12) }
      Else If Kw = 'READ' Then
      Begin
        ParserAdvance;
        ParseReadStmt;
      End
      { CLEAR [SCREEN] (TODO 12) }
      Else If (Kw = 'CLEAR') Then
      Begin
        ParserAdvance;
        ParseClearStmt;
      End
      { SET (TODO 12 / TODO 20) }
      Else If Kw = 'SET' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'INDEX') Then
        Begin
          ParserAdvance;
          { SET INDEX TO ... }
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
            ParserAdvance;
          ParseIndexStmt;
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ORDER') Then
        Begin
          ParserAdvance;
          { SET ORDER TO n }
          EmitComment('SET ORDER TO (TODO 20)');
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
            ParserAdvance;
          ParseExpr(SetExpr);
          ExprFlushToAX(SetExpr);
          EmitInstrA('CALL', CL_RT_PFX + 'IDXSETORDER');
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FILTER') Then
        Begin
          ParserAdvance;
          EmitComment('SET FILTER TO (TODO 20)');
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
            ParserAdvance;
          { Expression de filtre ou vide pour reset }
          If (CurToken.Kind <> TK_EOF) And
             Not ((CurToken.Kind = TK_KEYWORD) And
                  ((CurToken.Val = '?') Or (CurToken.Val = 'IF') Or
                   (CurToken.Val = 'DO') Or (CurToken.Val = 'RETURN'))) Then
          Begin
            ParseExpr(SetExpr);
            ExprFlushToAX(SetExpr);
          End
          Else
            EmitInstrAB('XOR', 'AX', 'AX');
          EmitInstrA('CALL', CL_RT_PFX + 'IDXSETFILTER');
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'RELATION') Then
        Begin
          ParserAdvance;
          EmitComment('SET RELATION TO (TODO 20)');
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
            ParserAdvance;
          ParseExpr(SetExpr);
          ExprFlushToAX(SetExpr);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'INTO') Then
            ParserAdvance;
          If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
          Begin
            SetDataIdx := DataAddStr(CurToken.Val);
            EmitInstrAB('LEA', 'SI', '[' + DataTab[SetDataIdx].LblName + ']');
            ParserAdvance;
          End;
          EmitInstr('POP    AX');
          EmitInstrA('CALL', CL_RT_PFX + 'IDXSETRELATION');
        End
        Else If (CurToken.Kind = TK_KEYWORD) And
                ((CurToken.Val = 'SOFTSEEK') Or (CurToken.Val = 'EXACT') Or
                 (CurToken.Val = 'DELETED')) Then
        Begin
          EmitComment('SET ' + CurToken.Val + ' (TODO 20)');
          ParserAdvance;
          { ON/OFF }
          If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
            ParserAdvance;
        End
        Else
          ParseSetColorStmt;
      End
      { IF (TODO 13) }
      Else If Kw = 'IF' Then
      Begin
        ParserAdvance;
        ParseIfStmt;
      End
      { DO [CASE/WHILE/procname] (TODO 13/14/17) }
      Else If Kw = 'DO' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'CASE') Then
        Begin
          ParserAdvance;
          ParseDoCaseStmt;
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WHILE') Then
        Begin
          ParserAdvance;
          ParseDoWhileStmt;
        End
        Else If (CurToken.Kind = TK_IDENT) Then
        Begin
          { DO procname [WITH arg1, arg2] (TODO 17) }
          ParseDoCallStmt;
        End;
      End
      { FOR / FOR EACH (TODO 14) }
      Else If Kw = 'FOR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'EACH') Then
        Begin
          ParserAdvance;
          ParseForEachStmt;
        End
        Else
          ParseForStmt;
      End
      { LOOP (TODO 14) }
      Else If Kw = 'LOOP' Then
      Begin
        ParserAdvance;
        If LoopTop > 0 Then
        Begin
          EmitComment('LOOP');
          EmitInstrA('JMP', LoopContLbl[LoopTop - 1]);
        End
        Else
          CompileError('LOOP en dehors d une boucle');
      End
      { EXIT (TODO 14) / EXIT PROCEDURE (TODO 17) }
      Else If Kw = 'EXIT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And
           ((CurToken.Val = 'PROCEDURE') Or (CurToken.Val = 'PROC')) Then
        Begin
          { EXIT PROCEDURE declaration (TODO 17) }
          ParserAdvance;
          If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
          Begin
            If ExitProcCount < 16 Then
            Begin
              ExitProcTab[ExitProcCount] := CL_FN_PFX + SymNameClean(CurToken.Val);
              Inc(ExitProcCount);
            End;
            ParseProcDecl;
          End
          Else
            CompileError('EXIT PROCEDURE : nom attendu');
        End
        Else If LoopTop > 0 Then
        Begin
          EmitComment('EXIT');
          EmitInstrA('JMP', LoopBrkLbl[LoopTop - 1]);
        End
        Else
          CompileError('EXIT en dehors d une boucle');
      End
      { FUNCTION declaration (TODO 17) }
      Else If (Kw = 'FUNCTION') Or (Kw = 'FUNC') Then
      Begin
        ParserAdvance;
        ParseFuncDecl;
      End
      { PROCEDURE declaration (TODO 17) }
      Else If (Kw = 'PROCEDURE') Or (Kw = 'PROC') Then
      Begin
        ParserAdvance;
        ParseProcDecl;
      End
      { RETURN statement (TODO 17) }
      Else If (Kw = 'RETURN') Or (Kw = 'RETU') Then
      Begin
        ParserAdvance;
        ParseReturnStmt;
      End
      { INIT PROCEDURE (TODO 17) }
      Else If Kw = 'INIT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And
           ((CurToken.Val = 'PROCEDURE') Or (CurToken.Val = 'PROC')) Then
        Begin
          ParserAdvance;
          { Lire le nom de la procedure INIT }
          If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
          Begin
            If InitProcCount < 16 Then
            Begin
              InitProcTab[InitProcCount] := CL_FN_PFX + SymNameClean(CurToken.Val);
              Inc(InitProcCount);
            End;
            ParseProcDecl;
          End
          Else
            CompileError('INIT PROCEDURE : nom attendu');
        End;
      End
      { USE : ouvrir un fichier DBF (TODO 19) }
      Else If Kw = 'USE' Then
      Begin
        ParserAdvance;
        ParseUseStmt;
      End
      { SELECT : changer la zone de travail active (TODO 19) }
      Else If Kw = 'SELECT' Then
      Begin
        ParserAdvance;
        ParseSelectStmt;
      End
      { CLOSE : fermer les fichiers DBF (TODO 19) }
      Else If Kw = 'CLOSE' Then
      Begin
        ParserAdvance;
        ParseCloseStmt;
      End
      { GO / GOTO : navigation dans le fichier DBF (TODO 19) }
      Else If (Kw = 'GO') Or (Kw = 'GOTO') Then
      Begin
        ParserAdvance;
        ParseGoStmt;
      End
      { SKIP : avancer/reculer dans le fichier DBF (TODO 19) }
      Else If Kw = 'SKIP' Then
      Begin
        ParserAdvance;
        ParseSkipStmt;
      End
      { APPEND : ajouter un enregistrement (TODO 19) }
      Else If (Kw = 'APPEND') Or (Kw = 'APPE') Then
      Begin
        ParserAdvance;
        ParseAppendStmt;
      End
      { REPLACE : modifier un champ (TODO 19) }
      Else If (Kw = 'REPLACE') Or (Kw = 'REPL') Then
      Begin
        ParserAdvance;
        ParseReplaceStmt;
      End
      { DELETE : marquer pour suppression (TODO 19) }
      Else If (Kw = 'DELETE') Or (Kw = 'DELE') Then
      Begin
        ParserAdvance;
        ParseDeleteStmt;
      End
      { RECALL : annuler la marque de suppression (TODO 19) }
      Else If Kw = 'RECALL' Then
      Begin
        ParserAdvance;
        ParseRecallStmt;
      End
      { PACK : supprimer physiquement les enregistrements marques (TODO 19) }
      Else If Kw = 'PACK' Then
      Begin
        ParserAdvance;
        ParsePackStmt;
      End
      { ZAP : supprimer tous les enregistrements (TODO 19) }
      Else If Kw = 'ZAP' Then
      Begin
        ParserAdvance;
        ParseZapStmt;
      End
      { INDEX : creer un index (TODO 20) }
      Else If Kw = 'INDEX' Then
      Begin
        ParserAdvance;
        ParseIndexStmt;
      End
      { SEEK : recherche dans l index actif (TODO 20) }
      Else If Kw = 'SEEK' Then
      Begin
        ParserAdvance;
        ParseSeekStmt;
      End
      { LOCATE : recherche sequentielle (TODO 20) }
      Else If Kw = 'LOCATE' Then
      Begin
        ParserAdvance;
        ParseLocateStmt;
      End
      { CONTINUE : continuer la recherche LOCATE (TODO 20) }
      Else If (Kw = 'CONTINUE') Or (Kw = 'CONT') Then
      Begin
        ParserAdvance;
        ParseContinueStmt;
      End
      { REINDEX : reconstruire les index (TODO 20) }
      Else If Kw = 'REINDEX' Then
      Begin
        ParserAdvance;
        ParseReindexStmt;
      End
      Else
      Begin
        { Autres mots-cles : stub pour TODOs futurs }
        ParserAdvance;
      End;
    End
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      { Instruction expression : affectation ou appel }
      ParseExprStmt;
    End
    Else If CurToken.Kind = TK_PUNCT Then
    Begin
      ParserAdvance;
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
    Begin
      { Macro &variable en position d instruction (TODO 10) }
      ParseExprStmt;
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
    Begin
      { @ row,col SAY/GET/TO (TODO 12) }
      ParserAdvance;
      ParseAtStmt;
    End
    Else
    Begin
      { Autre token : avancer }
      ParserAdvance;
    End;
  End;

  LexClose;
  EmitClose;

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
     (U = 'WITH')       Or (U = 'CLASS')      Or (U = 'STORE')    Or
     (U = 'READ')       Or (U = 'CLEAR')      Or (U = 'SET')      Or
     (U = 'SAY')        Or (U = 'GET')        Or (U = 'PICTURE')  Or
     (U = 'VALID')      Or (U = 'SCREEN')     Or (U = 'COLOR')    Or
     (U = 'DOUBLE')     Or (U = 'INIT')       Or
     (U = 'USE')        Or (U = 'SELECT')     Or (U = 'CLOSE')    Or
     (U = 'GO')         Or (U = 'GOTO')       Or (U = 'SKIP')     Or
     (U = 'APPEND')     Or (U = 'REPLACE')    Or (U = 'DELETE')   Or
     (U = 'RECALL')     Or (U = 'PACK')       Or (U = 'ZAP')     Or
     (U = 'ALIAS')      Or (U = 'SHARED')     Or (U = 'EXCLUSIVE') Or
     (U = 'NEW')        Or (U = 'BLANK')      Or (U = 'TOP')     Or
     (U = 'BOTTOM')     Or (U = 'ALL')        Or (U = 'DATABASES') Or
     (U = 'INDEX')      Or (U = 'SEEK')       Or (U = 'LOCATE')  Or
     (U = 'CONTINUE')   Or (U = 'REINDEX')    Or
     (U = 'ORDER')      Or (U = 'FILTER')     Or (U = 'RELATION') Or
     (U = 'INTO')       Or (U = 'ON')         Or (U = 'REST')    Or
     (U = 'SOFTSEEK')   Or (U = 'EXACT')   Or (U = 'DBEVAL') Then
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
    If Copy('CLEAR',      1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('PICTURE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('SCREEN',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('APPEND',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('REPLACE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('DELETE',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('SHARED',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('EXCLUSIVE',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('BOTTOM',     1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('DATABASES',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('CONTINUE',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('REINDEX',   1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('LOCATE',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('SOFTSEEK',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('RELATION',  1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
    If Copy('FILTER',    1, Length(U)) = U Then Begin IsKeyword := True; Exit; End;
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
     (U = 'IN')      Or (U = 'WITH')   Or (U = 'CLASS')   Or
     (U = 'STORE')   Or (U = 'READ')   Or (U = 'CLEAR')   Or
     (U = 'SET')     Or (U = 'SAY')    Or (U = 'GET')     Or
     (U = 'PICTURE') Or (U = 'VALID')  Or (U = 'SCREEN')  Or
     (U = 'COLOR')   Or (U = 'DOUBLE') Or (U = 'INIT')    Or
     (U = 'USE')     Or (U = 'SELECT') Or (U = 'CLOSE')   Or
     (U = 'GO')      Or (U = 'GOTO')   Or (U = 'SKIP')    Or
     (U = 'APPEND')  Or (U = 'REPLACE') Or (U = 'DELETE')  Or
     (U = 'RECALL')  Or (U = 'PACK')   Or (U = 'ZAP')     Or
     (U = 'ALIAS')   Or (U = 'SHARED') Or (U = 'EXCLUSIVE') Or
     (U = 'NEW')     Or (U = 'BLANK')  Or (U = 'TOP')     Or
     (U = 'BOTTOM')  Or (U = 'ALL')    Or (U = 'DATABASES') Or
     (U = 'INDEX')   Or (U = 'SEEK')   Or (U = 'LOCATE')   Or
     (U = 'CONTINUE') Or (U = 'REINDEX') Or
     (U = 'ORDER')   Or (U = 'FILTER') Or (U = 'RELATION') Or
     (U = 'INTO')    Or (U = 'ON')     Or (U = 'REST')     Or
     (U = 'SOFTSEEK') Or (U = 'EXACT') Or (U = 'DBEVAL') Then
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
  If (Length(U) >= 4) And (Copy('CLEAR',      1, Length(U)) = U) Then Begin ExpandKeyword := 'CLEAR';      Exit; End;
  If (Length(U) >= 4) And (Copy('PICTURE',    1, Length(U)) = U) Then Begin ExpandKeyword := 'PICTURE';    Exit; End;
  If (Length(U) >= 4) And (Copy('SCREEN',     1, Length(U)) = U) Then Begin ExpandKeyword := 'SCREEN';     Exit; End;
  If (Length(U) >= 4) And (Copy('APPEND',     1, Length(U)) = U) Then Begin ExpandKeyword := 'APPEND';     Exit; End;
  If (Length(U) >= 4) And (Copy('REPLACE',    1, Length(U)) = U) Then Begin ExpandKeyword := 'REPLACE';    Exit; End;
  If (Length(U) >= 4) And (Copy('DELETE',     1, Length(U)) = U) Then Begin ExpandKeyword := 'DELETE';     Exit; End;
  If (Length(U) >= 4) And (Copy('SHARED',     1, Length(U)) = U) Then Begin ExpandKeyword := 'SHARED';     Exit; End;
  If (Length(U) >= 4) And (Copy('EXCLUSIVE',  1, Length(U)) = U) Then Begin ExpandKeyword := 'EXCLUSIVE';  Exit; End;
  If (Length(U) >= 4) And (Copy('BOTTOM',     1, Length(U)) = U) Then Begin ExpandKeyword := 'BOTTOM';     Exit; End;
  If (Length(U) >= 4) And (Copy('DATABASES',  1, Length(U)) = U) Then Begin ExpandKeyword := 'DATABASES';  Exit; End;
  If (Length(U) >= 4) And (Copy('CONTINUE',   1, Length(U)) = U) Then Begin ExpandKeyword := 'CONTINUE';   Exit; End;
  If (Length(U) >= 4) And (Copy('REINDEX',    1, Length(U)) = U) Then Begin ExpandKeyword := 'REINDEX';    Exit; End;
  If (Length(U) >= 4) And (Copy('LOCATE',     1, Length(U)) = U) Then Begin ExpandKeyword := 'LOCATE';     Exit; End;
  If (Length(U) >= 4) And (Copy('SOFTSEEK',   1, Length(U)) = U) Then Begin ExpandKeyword := 'SOFTSEEK';   Exit; End;
  If (Length(U) >= 4) And (Copy('RELATION',   1, Length(U)) = U) Then Begin ExpandKeyword := 'RELATION';   Exit; End;
  If (Length(U) >= 4) And (Copy('FILTER',     1, Length(U)) = U) Then Begin ExpandKeyword := 'FILTER';     Exit; End;

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
  DataTab[Idx].TagVal  := TY_IDX_NIL;
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
   octets (DK_BYTE), entrees taggees (DK_TAGGED),
   et constantes predefinies Clipper.                            *)

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
  { Buffer de concatenation (TODO 11) }
  WriteLn(OutF, '_CL_CATBUF  DB  256 DUP(0)');
  { I/O buffers and data (TODO 12) }
  WriteLn(OutF, '_CL_CRLF    DB  13,10,0');
  WriteLn(OutF, '_CL_INPBUF  DB  128 DUP(0)');
  WriteLn(OutF, '_CL_FMTBUF  DB  64 DUP(0)');
  WriteLn(OutF, '_CL_LASTKEY DW  0');
  WriteLn(OutF, '_CL_GETCOUNT DW  0');
  WriteLn(OutF, '_CL_GETLIST DB  640 DUP(0)');  { 16 GETs x 40 bytes each }
  WriteLn(OutF, '_CL_COLOR   DB  07h');  { default: white on black }
  { Heap pour tableaux (TODO 15) }
  WriteLn(OutF, '_CL_HEAPPTR DW  _CL_HEAP');
  WriteLn(OutF, '_CL_HEAP    DB  ', IntToStr(MAX_HEAP_SIZE), ' DUP(0)');
  WriteLn(OutF, '_CL_ARRPTR  DW  0');
  WriteLn(OutF, '_CL_ARRIDX  DW  0');
  { Buffers pour chaines (TODO 16) }
  WriteLn(OutF, '_CL_STRBUF  DB  ', IntToStr(MAX_STR_BUF), ' DUP(0)');
  WriteLn(OutF, '_CL_STRBUF2 DB  ', IntToStr(MAX_STR_BUF), ' DUP(0)');
  WriteLn(OutF, '_CL_CHRBUF  DB  2 DUP(0)');
  { Work areas DBF (TODO 19) }
  WriteLn(OutF, '; -- work area table: 10 entries x 64 bytes each --');
  WriteLn(OutF, '; layout per entry: handle(2) + recno(2) + reccnt(2) + recsize(2)');
  WriteLn(OutF, ';   + hdrsize(2) + flags(2) + alias(12) + fldcount(2) + reserved(38)');
  WriteLn(OutF, '_CL_WATAB   DB  640 DUP(0)');    { 10 * 64 bytes }
  WriteLn(OutF, '_CL_CURWA   DW  0');              { current work area (0-based index) }
  WriteLn(OutF, '_CL_DBFBUF  DB  ', IntToStr(MAX_DBF_REC_SIZE), ' DUP(0)');
  WriteLn(OutF, '_CL_DBFNAME DB  80 DUP(0)');      { buffer pour nom fichier }
  WriteLn(OutF, '_CL_DBFHDR  DB  32 DUP(0)');      { buffer en-tete DBF }
  WriteLn(OutF, '_CL_DBFFLD  DB  32 DUP(0)');      { buffer descripteur champ }
  WriteLn(OutF, '_CL_DBFEXT  DB  ''.DBF'',0');     { extension par defaut }
  { Index et recherche (TODO 20) }
  WriteLn(OutF, '_CL_IDXCNT  DW  0');              { nombre d index ouverts }
  WriteLn(OutF, '_CL_IDXORD  DW  0');              { index actif (0-based) }
  WriteLn(OutF, '_CL_FOUND   DW  0');              { flag FOUND() }
  WriteLn(OutF, '_CL_IDXHND  DW  8 DUP(0)');      { handles fichiers index (max 8) }
  WriteLn(OutF, '_CL_NTXEXT  DB  ''.NTX'',0');     { extension index NTX }
  WriteLn(OutF, '_CL_IDXNAME DB  80 DUP(0)');      { buffer nom fichier index }
  WriteLn(OutF, '_CL_IDXKEY  DB  256 DUP(0)');     { buffer expression cle }
  WriteLn(OutF, '_CL_IDXBUF  DB  256 DUP(0)');     { buffer lecture index }
  { Entrees DataTab }
  For I := 0 To DataCount - 1 Do
  Begin
    WriteLn(OutF, DataTab[I].LblName, ':');
    Case DataTab[I].Kind Of
      DK_WORD :
      Begin
        If DataTab[I].StrVal <> '' Then
          WriteLn(OutF, '        DW      ', DataTab[I].StrVal)
        Else
        Begin
          Str(DataTab[I].IntVal, NS);
          WriteLn(OutF, '        DW      ', NS);
        End;
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
      DK_TAGGED :
      Begin
        { Tag de type (1 octet) suivi de la valeur (1 mot 16 bits) }
        Str(DataTab[I].TagVal, NS);
        WriteLn(OutF, '        DB      ', NS, '       ; tag type');
        Str(DataTab[I].IntVal, NS);
        WriteLn(OutF, '        DW      ', NS, '       ; valeur');
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

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- ParseIIF : IIF(cond, exprTrue, exprFalse) --------------- }
(* Expression conditionnelle inline Clipper.
   Genere : eval cond / TEST AX,AX / JZ lblFalse /
            eval exprTrue / JMP lblEnd /
            lblFalse: eval exprFalse / lblEnd:              *)

Procedure ParseIIF(Var Res : TExprVal);
Var
  LblFalse, LblEnd : TString;
Begin
  EmitComment('IIF(cond, exprT, exprF)');
  { Consommer '(' apres IIF }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance
  Else
  Begin
    CompileError('IIF : attendu ''(''');
    ExprMakeNone(Res);
    Exit;
  End;
  LblFalse := LabelGen;
  LblEnd   := LabelGen;
  { Evaluer la condition }
  ParseExpr(Res);
  ExprFlushToAX(Res);
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblFalse);
  { Consommer la virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    ParserAdvance;
  { Evaluer exprTrue }
  ParseExpr(Res);
  ExprFlushToAX(Res);
  EmitInstrA('JMP', LblEnd);
  { Consommer la virgule }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    ParserAdvance;
  { Evaluer exprFalse }
  EmitLabel(LblFalse);
  ParseExpr(Res);
  ExprFlushToAX(Res);
  EmitLabel(LblEnd);
  { Consommer ')' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.SymIdx  := -1;
End;

{ ---- ParseEVAL : EVAL(bCodeBlock [, arg1, arg2 ...]) --------- }
(* Evalue un code block Clipper.
   Genere : PUSH args (droite a gauche) / PUSH codeblock /
            CALL _CLRT_EVAL / ADD SP, n                      *)

Procedure ParseEVAL(Var Res : TExprVal);
Var
  ArgCount : Integer;
  Arg      : TExprVal;
Begin
  EmitComment('EVAL(codeblock, args...)');
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    CompileError('EVAL : attendu ''(''');
    ExprMakeNone(Res);
    Exit;
  End;
  ParserAdvance; { consomme '(' }
  ArgCount := 0;
  { Premier argument : le code block }
  ParseExpr(Arg);
  ExprFlushToAX(Arg);
  EmitInstr('PUSH   AX');
  Inc(ArgCount);
  { Arguments supplementaires }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance; { consomme ',' }
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstr('PUSH   AX');
    Inc(ArgCount);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstrA('CALL', CL_RT_PFX + 'EVAL');
  If ArgCount > 0 Then
    EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.SymIdx  := -1;
End;

{ ---- ParseFieldAccess : FIELD->nom ou alias->nom ------------- }
(* Genere : LEA SI, _CLK_n (nom du champ en DATA)
            CALL _CLRT_GETFIELD -> resultat en AX             *)

Procedure ParseFieldAccess(Const AliasName : TString; Var Res : TExprVal);
Var
  FieldName : TString;
  DIdx      : Integer;
Begin
  EmitComment('field access ' + AliasName + '->' + '...');
  ParserAdvance; { consomme '->' }
  If CurToken.Kind = TK_IDENT Then
  Begin
    FieldName := CurToken.Val;
    ParserAdvance;
    EmitComment('FIELD->' + FieldName);
    { Stocker le nom du champ dans DATA pour le passer au runtime }
    DIdx := DataAddStr(FieldName);
    EmitInstrAB('MOV', 'SI', 'OFFSET ' + DataTab[DIdx].LblName);
    EmitInstrA('CALL', CL_RT_PFX + 'GETFIELD');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_UNKNOWN;
    Res.SymIdx  := -1;
  End
  Else
  Begin
    CompileError('attendu un nom de champ apres ->');
    ExprMakeNone(Res);
  End;
End;

{ ---- ParseArrayAccess : arr[i] ou arr[i,j] ------------------- }
(* Genere : PUSH AX (arr ptr) / eval index / MOV BX,AX (=idx)
            POP AX (=arr) / -> resultat CALL _CLRT_AGET
   Pour indices multiples [i,j] : acces sequentiel.            *)

Procedure ParseArrayAccess(Var Res : TExprVal);
Var
  IdxExpr : TExprVal;
Begin
  EmitComment('array access arr[...]');
  { AX contient deja le pointeur du tableau }
  ExprFlushToAX(Res);
  ParserAdvance; { consomme '[' }
  { Sauvegarder le pointeur tableau }
  EmitInstr('PUSH   AX');
  { Evaluer l index }
  ParseExpr(IdxExpr);
  ExprFlushToAX(IdxExpr);
  { AX = index, pile = arr ptr -> POP BX pour AGET(BX=arr, AX=idx) }
  EmitInstr('POP    BX');
  { Sauvegarder arr ptr et index pour affectation potentielle (TODO 15) }
  EmitInstrAB('MOV', '[_CL_ARRPTR]', 'BX');
  EmitInstrAB('MOV', '[_CL_ARRIDX]', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'AGET');
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_UNKNOWN;
  Res.SymIdx  := -2;   { marqueur : acces tableau pour affectation }
  { Indices supplementaires [i,j] : acces en cascade }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
  Begin
    ParserAdvance; { consomme ',' }
    EmitInstr('PUSH   AX');
    ParseExpr(IdxExpr);
    ExprFlushToAX(IdxExpr);
    EmitInstr('POP    BX');
    EmitInstrA('CALL', CL_RT_PFX + 'AGET');
  End;
  { Consommer ']' }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance;
End;

{ ---- ParseMacro : &variable ---------------------------------- }
(* Macro substitution Clipper : &nom ou &(expr)
   Genere : LEA SI, [var_addr] / CALL _CLRT_MACRO -> AX       *)

Procedure ParseMacro(Var Res : TExprVal);
Var
  SIdx : Integer;
  MExpr : TExprVal;
Begin
  EmitComment('macro &substitution');
  ParserAdvance; { consomme '&' }
  If CurToken.Kind = TK_IDENT Then
  Begin
    { &varName : substituer le contenu de la variable }
    SIdx := SymFind(CurToken.Val);
    If SIdx < 0 Then
    Begin
      If Opts.Warnings Then
        WarnMsg('variable implicite PRIVATE pour macro : ' + CurToken.Val);
      SIdx := DeclAllocSym(CurToken.Val, SC_PRIVATE);
    End;
    EmitComment('macro &' + CurToken.Val);
    ExprLoad(SIdx, Res);
    ExprFlushToAX(Res);
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'MACRO');
    ParserAdvance;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_UNKNOWN;
    Res.SymIdx  := -1;
  End
  Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    { &(expr) : evaluer l expression puis substituer }
    ParserAdvance; { consomme '(' }
    ParseExpr(MExpr);
    ExprFlushToAX(MExpr);
    EmitInstrAB('MOV', 'SI', 'AX');
    EmitInstrA('CALL', CL_RT_PFX + 'MACRO');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_UNKNOWN;
    Res.SymIdx  := -1;
  End
  Else
  Begin
    CompileError('attendu un identificateur ou ''('' apres &');
    ExprMakeNone(Res);
  End;
End;

{ ---- ParseFuncCall : appel de fonction nom(args) ------------- }
(* Consomme les arguments entre parentheses, les pousse sur la
   pile, puis emet CALL _CLP_nom et nettoie la pile.           *)

Procedure ParseFuncCall(SIdx : Integer; Var Res : TExprVal);
Var
  ArgCount : Integer;
  Arg      : TExprVal;
Begin
  EmitComment('call ' + SymTab[SIdx].MangledName);
  ParserAdvance; { consomme '(' }
  ArgCount := 0;
  While (CurToken.Kind <> TK_EOF) And
        Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
  Begin
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstr('PUSH   AX');
    Inc(ArgCount);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;
  EmitInstrA('CALL', SymTab[SIdx].MangledName);
  If ArgCount > 0 Then
    EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
  Res.Kind    := EK_AX;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.SymIdx  := -1;
End;

{ ---- ParsePrimary : atome du parseur Pratt ------------------- }
(* Gere : litteraux entiers, flottants, chaines, booleens
   (.T./.F.), NIL, SELF, identificateurs, fonctions, tableaux,
   acces FIELD->nom, IIF(), EVAL(), macro &var, parentheses.  *)

Procedure ParsePrimary(Var Res : TExprVal);
Var
  SIdx    : Integer;
  IdName  : TString;
  ArgCount : Integer;
  Arg      : TExprVal;
Begin
  SIdx := -1;
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
        { SELF : reference a l objet courant (stub OOP) }
        EmitComment('SELF (stub OOP)');
        ExprMakeImm(0, TY_IDX_OBJECT, Res);
        ParserAdvance;
      End
      Else If CurToken.Val = '?' Then
      Begin
        { ? et ?? sont des commandes d affichage gerees dans Run ;
          si on arrive ici en position d expression, retourner void }
        ExprMakeNone(Res);
      End
      Else
      Begin
        { Mot-cle non-litteral (RETURN, IF, etc.) : pas une expression }
        ExprMakeNone(Res);
      End;
    End;
    TK_IDENT :
    Begin
      IdName := CurToken.Val;
      { --- IIF : expression conditionnelle inline --- }
      If IdName = 'IIF' Then
      Begin
        ParserAdvance; { consomme IIF }
        ParseIIF(Res);
      End
      { --- EVAL : evaluer un code block --- }
      Else If IdName = 'EVAL' Then
      Begin
        ParserAdvance; { consomme EVAL }
        ParseEVAL(Res);
      End
      { --- FIELD : acces champ explicite --- }
      Else If IdName = 'FIELD' Then
      Begin
        ParserAdvance; { consomme FIELD }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
          ParseFieldAccess('FIELD', Res)
        Else
        Begin
          { FIELD sans -> : chercher comme identifiant normal }
          SIdx := SymFind('FIELD');
          If SIdx >= 0 Then
            ExprLoad(SIdx, Res)
          Else
          Begin
            SIdx := DeclAllocSym('FIELD', SC_PRIVATE);
            ExprLoad(SIdx, Res);
          End;
        End;
      End
      { --- INKEY : attendre touche (TODO 12) --- }
      Else If IdName = 'INKEY' Then
      Begin
        ParserAdvance; { consomme INKEY }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
            ParseExpr(Arg);  { skip optional nSec argument }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'INKEY');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- LASTKEY : derniere touche pressee (TODO 12) --- }
      Else If IdName = 'LASTKEY' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrAB('MOV', 'AX', '[_CL_LASTKEY]');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- ROW : position ligne curseur (TODO 12) --- }
      Else If IdName = 'ROW' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'GETROW');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- COL : position colonne curseur (TODO 12) --- }
      Else If IdName = 'COL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'GETCOL');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- MAXROW : derniere ligne ecran (TODO 12) --- }
      Else If IdName = 'MAXROW' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        ExprMakeImm(24, TY_IDX_NUM, Res);
      End
      { --- MAXCOL : derniere colonne ecran (TODO 12) --- }
      Else If IdName = 'MAXCOL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        ExprMakeImm(79, TY_IDX_NUM, Res);
      End
      { --- LEN : longueur tableau ou chaine (TODO 15) --- }
      Else If IdName = 'LEN' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'ALEN');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- AADD : ajouter element (TODO 15) --- }
      Else If IdName = 'AADD' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { val }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'AADD');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ADEL : supprimer element (TODO 15) --- }
      Else If IdName = 'ADEL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { index }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'ADEL');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- AINS : inserer element (TODO 15) --- }
      Else If IdName = 'AINS' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { index }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'AINS');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ASIZE : redimensionner (TODO 15) --- }
      Else If IdName = 'ASIZE' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { new size }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'ASIZE');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ACLONE : copier tableau (TODO 15) --- }
      Else If IdName = 'ACLONE' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'ACLONE');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ASORT : trier (TODO 15) --- }
      Else If IdName = 'ASORT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'ASORT');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ASCAN : recherche (TODO 15) --- }
      Else If IdName = 'ASCAN' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { val }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'ASCAN');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- AFILL : remplir (TODO 15) --- }
      Else If IdName = 'AFILL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { arr }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { val }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'AFILL');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- ACOPY : copier elements (TODO 15) --- }
      Else If IdName = 'ACOPY' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { src }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { dst }
          ExprFlushToAX(Arg);
          EmitInstr('POP    BX');
          EmitInstrA('CALL', CL_RT_PFX + 'ACOPY');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End

      { === Chaines de caracteres (TODO 16) === }

      { --- UPPER : majuscules --- }
      Else If IdName = 'UPPER' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SUPPER');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- LOWER : minuscules --- }
      Else If IdName = 'LOWER' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SLOWER');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- TRIM / RTRIM : supprimer espaces droite --- }
      Else If (IdName = 'TRIM') Or (IdName = 'RTRIM') Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'STRIM');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- LTRIM : supprimer espaces gauche --- }
      Else If IdName = 'LTRIM' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SLTRIM');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- ALLTRIM : supprimer espaces gauche et droite --- }
      Else If IdName = 'ALLTRIM' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SALLTRIM');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- ASC : code ASCII du premier caractere --- }
      Else If IdName = 'ASC' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'SI', 'AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SASC');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- CHR : caractere depuis code ASCII --- }
      Else If IdName = 'CHR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SCHR');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- SPACE : chaine de n espaces --- }
      Else If IdName = 'SPACE' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'SSPACE');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- STR : nombre vers chaine --- }
      Else If IdName = 'STR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
        EmitInstrA('CALL', CL_RT_PFX + 'NUMTOSTR');
        EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- VAL : chaine vers nombre --- }
      Else If IdName = 'VAL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrA('CALL', CL_RT_PFX + 'SVAL');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- LEFT : n premiers caracteres --- }
      Else If IdName = 'LEFT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SLEFT');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- RIGHT : n derniers caracteres --- }
      Else If IdName = 'RIGHT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SRIGHT');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- REPLICATE : repeter chaine n fois --- }
      Else If IdName = 'REPLICATE' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SREPLICATE');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- PADR : completer a droite avec espaces --- }
      Else If IdName = 'PADR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SPADR');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- PADL : completer a gauche avec espaces --- }
      Else If IdName = 'PADL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SPADL');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- PADC : completer centre avec espaces --- }
      Else If IdName = 'PADC' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { n }
          ExprFlushToAX(Arg);
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SPADC');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- AT : position sous-chaine (1-base) --- }
      Else If IdName = 'AT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { sub }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SATPOS');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- RAT : derniere position sous-chaine --- }
      Else If IdName = 'RAT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { sub }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SRATPOS');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- SUBSTR : sous-chaine(str, start, len) --- }
      Else If IdName = 'SUBSTR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { start }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { len }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'CX', 'AX');
          EmitInstr('POP    BX');
          EmitInstr('POP    AX');
          EmitInstrA('CALL', CL_RT_PFX + 'SSUBSTR');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- STRTRAN : remplacer sous-chaine --- }
      Else If IdName = 'STRTRAN' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { old }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { new }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstr('POP    DI');
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'SSTRTRAN');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- STUFF : inserer/remplacer dans chaine --- }
      Else If IdName = 'STUFF' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { str }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { pos }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { del }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { ins }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DX', 'AX');
          EmitInstr('POP    CX');
          EmitInstr('POP    BX');
          EmitInstr('POP    AX');
          EmitInstrA('CALL', CL_RT_PFX + 'SSTUFF');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- TRANSFORM : formater valeur avec masque --- }
      Else If IdName = 'TRANSFORM' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { val }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          ParseExpr(Arg);  { mask }
          ExprFlushToAX(Arg);
          EmitInstrAB('MOV', 'DI', 'AX');
          EmitInstr('POP    SI');
          EmitInstrA('CALL', CL_RT_PFX + 'STRANSFORM');
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End

      { --- EOF : fin de fichier DBF (TODO 19) --- }
      Else If IdName = 'EOF' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBEOF');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx := -1;
      End
      { --- BOF : debut de fichier DBF (TODO 19) --- }
      Else If IdName = 'BOF' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBBOF');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx := -1;
      End
      { --- RECNO : numero d enregistrement courant (TODO 19) --- }
      Else If IdName = 'RECNO' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBRECNO');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- RECCOUNT / LASTREC : nombre total d enregistrements (TODO 19) --- }
      Else If (IdName = 'RECCOUNT') Or (IdName = 'LASTREC') Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBRECCOUNT');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- DELETED : enregistrement marque pour suppression (TODO 19) --- }
      Else If IdName = 'DELETED' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBDELETED');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx := -1;
      End
      { --- FCOUNT : nombre de champs (TODO 19) --- }
      Else If IdName = 'FCOUNT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBFCOUNT');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- FIELDNAME / FIELD : nom du champ n (TODO 19) --- }
      Else If (IdName = 'FIELDNAME') Or (IdName = 'FIELDNAM') Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { field number }
          ExprFlushToAX(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBFIELDNAME');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- ALIAS : nom de l alias de la zone courante (TODO 19) --- }
      Else If IdName = 'ALIAS' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
            ParseExpr(Arg);  { optional work area number }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBALIAS');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- DBSTRUCT : retourner structure sous forme de tableau (TODO 19) --- }
      Else If IdName = 'DBSTRUCT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBSTRUCT');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_ARRAY;
        Res.SymIdx := -1;
      End
      { --- SELECT : retourner numero de zone de travail (TODO 19) --- }
      Else If (IdName = 'SELECT') Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
            ParseExpr(Arg);  { optional alias expr }
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrAB('MOV', 'AX', '[_CL_CURWA]');
        EmitInstr('INC    AX');   { 1-based }
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End
      { --- USED : zone de travail en utilisation (TODO 19) --- }
      Else If IdName = 'USED' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'DBUSED');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx := -1;
      End
      { --- FOUND : resultat de la derniere recherche SEEK/LOCATE (TODO 20) --- }
      Else If IdName = 'FOUND' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'IDXFOUND');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_LOGIC;
        Res.SymIdx := -1;
      End
      { --- DBEVAL : iteration conditionnelle sur enregistrements (TODO 20) --- }
      Else If IdName = 'DBEVAL' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          ParseExpr(Arg);  { block principal }
          ExprFlushToAX(Arg);
          EmitInstr('PUSH   AX');
          ArgCount := 0;
          While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
          Begin
            ParserAdvance;
            ParseExpr(Arg);
            ExprFlushToAX(Arg);
            EmitInstr('PUSH   AX');
            Inc(ArgCount);
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
          EmitInstrA('CALL', CL_RT_PFX + 'IDXDBEVAL');
          EmitInstrAB('ADD', 'SP', IntToStr((ArgCount + 1) * 2));
        End;
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NIL;
        Res.SymIdx := -1;
      End
      { --- ORDNAME : nom de l index actif (TODO 20) --- }
      Else If IdName = 'ORDNAME' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
            ParseExpr(Arg);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'IDXORDNAME');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_CHAR;
        Res.SymIdx := -1;
      End
      { --- ORDCOUNT : nombre d index ouverts (TODO 20) --- }
      Else If IdName = 'ORDCOUNT' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ParserAdvance;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
            ParserAdvance;
        End;
        EmitInstrA('CALL', CL_RT_PFX + 'IDXORDCOUNT');
        Res.Kind := EK_AX;
        Res.TypeIdx := TY_IDX_NUM;
        Res.SymIdx := -1;
      End

      Else
      Begin
        { Identificateur normal : rechercher dans la table des symboles }
        SIdx := SymFind(CurToken.Val);
        If SIdx >= 0 Then
        Begin
          ExprLoad(SIdx, Res);
          ParserAdvance;
        End
        Else
        Begin
          { Symbole inconnu : creer une variable PRIVATE implicite }
          If Opts.Warnings Then
            WarnMsg('variable implicite PRIVATE : ' + CurToken.Val);
          SIdx := DeclAllocSym(CurToken.Val, SC_PRIVATE);
          ExprLoad(SIdx, Res);
          ParserAdvance;
        End;
        { --- Acces champ alias->nom --- }
        If (CurToken.Kind = TK_OP) And (CurToken.Val = '->') Then
        Begin
          ParseFieldAccess(IdName, Res);
        End
        { --- Appel de fonction : ident(...) --- }
        Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          If (SIdx >= 0) And
             ((SymTab[SIdx].Cat = SC_FUNC) Or
              (SymTab[SIdx].Cat = SC_PROC)) Then
          Begin
            ParseFuncCall(SIdx, Res);
          End
          Else
          Begin
            { Appel generique (fonction inconnue) }
            EmitComment('call generic ' + IdName);
            ParserAdvance; { consomme '(' }
            ArgCount := 0;
            While (CurToken.Kind <> TK_EOF) And
                  Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
            Begin
              ParseExpr(Arg);
              ExprFlushToAX(Arg);
              EmitInstr('PUSH   AX');
              Inc(ArgCount);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
              ParserAdvance;
            EmitInstrA('CALL', CL_FN_PFX + IdName);
            If ArgCount > 0 Then
              EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
            Res.Kind    := EK_AX;
            Res.TypeIdx := TY_UNKNOWN;
            Res.SymIdx  := -1;
          End;
        End;
        { --- Acces tableau : ident[i] --- }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
          ParseArrayAccess(Res);
      End;
    End;
    TK_OP :
    Begin
      { --- Macro &variable ou &(expr) --- }
      If CurToken.Val = '&' Then
      Begin
        ParseMacro(Res);
      End
      Else
      Begin
        { Autre operateur : laisser ParseUnary gerer }
        ExprMakeNone(Res);
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
      Else If CurToken.Val = '{' Then
      Begin
        (* Distinguer code block de array literal *)
        (* Si le token suivant est pipe, c est un code block *)
        ParserAdvance; (* consomme accolade ouvrante *)
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '|') Then
          ParseCodeBlock(Res)
        Else
        Begin
          (* Array literal : accolade deja consommee *)
          EmitComment('array literal');
          (* Sauvegarder le pointeur heap courant *)
          EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
          EmitInstr('PUSH   DI');           (* sauv debut du tableau *)
          (* Reserver la place pour le compteur (2 octets) *)
          EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');
          ArgCount := 0;
          If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Then
          Begin
            Repeat
              ParseExpr(Arg);
              ExprFlushToAX(Arg);
              EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
              EmitInstrAB('MOV', '[DI]', 'AX');
              EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');
              Inc(ArgCount);
              If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
                ParserAdvance
              Else
                Break;
            Until (CurToken.Kind = TK_EOF) Or
                  ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'));
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
            ParserAdvance;
          EmitInstr('POP    DI');
          EmitInstrAB('MOV', 'WORD PTR [DI]', IntToStr(ArgCount));
          EmitInstrAB('MOV', 'AX', 'DI');
          Res.Kind    := EK_AX;
          Res.TypeIdx := TY_IDX_ARRAY;
          Res.SymIdx  := -1;
        End;
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
   - Containment $ via appel runtime _CLRT_INSTR
   - Concatenation chaine + via appel runtime _CLRT_CONCAT
   - Soustraction chaine - via _CLRT_STRTRIMR + _CLRT_CONCAT
   - Comparaison chaines = via _CLRT_STRCMP, == via _CLRT_STRCMPEXACT
   - Affectation := += -= *= /= %= geree apres la boucle        *)

Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op        : TString;
  Prec      : Integer;
  Right     : TExprVal;
  LeftIsImm : Boolean;
  LeftImm   : LongInt;
  LeftType  : Integer;
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
    LeftIsImm  := (Res.Kind = EK_IMM);
    LeftImm    := Res.ImmVal;
    LeftType   := TypeInfer(Res);
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

      { --- Operateur + : numerique ADD ou chaine CONCAT --- }
      If Op = '+' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Concatenation chaines : _CLRT_CONCAT(SI=gauche, DI=droite) }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'CONCAT');
          Res.TypeIdx := TY_IDX_CHAR;
        End
        Else
          EmitInstrAB('ADD', 'AX', 'BX');
      End

      { --- Operateur - : numerique SUB ou chaine STRTRIMR+CONCAT --- }
      Else If Op = '-' Then
      Begin
        If (LeftType = TY_IDX_CHAR) And
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Soustraction chaines : trim droite de gauche puis concat }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRTRIMR');
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'CONCAT');
          Res.TypeIdx := TY_IDX_CHAR;
        End
        Else
          EmitInstrAB('SUB', 'AX', 'BX');
      End

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
        { Containment $ : _CLRT_INSTR(SI=sub, DI=str) -> AX=0|1 }
        EmitInstrAB('MOV', 'SI', 'AX');
        EmitInstrAB('MOV', 'DI', 'BX');
        EmitInstrA('CALL', CL_RT_PFX + 'INSTR');
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison == (exact) --- }
      Else If Op = '==' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Comparaison exacte chaines : _CLRT_STRCMPEXACT }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMPEXACT');
        End
        Else
        Begin
          { Comparaison numerique == }
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', 'BX');
          EmitInstrA('JE', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison = (souple) --- }
      Else If Op = '=' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Comparaison souple chaines : _CLRT_STRCMP -> 0 si egal }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          { Convertir : AX=0 (egal) -> AX=1, sinon -> AX=0 }
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JE', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison != <> # --- }
      Else If (Op = '!=') Or (Op = '<>') Or (Op = '#') Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Comparaison chaines != : _CLRT_STRCMP -> AX!=0 si different }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          { Convertir : AX!=0 -> AX=1, AX==0 -> AX=0 }
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JNE', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison < --- }
      Else If Op = '<' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          { Comparaison chaines < : _CLRT_STRCMP -> AX<0 si inferieur }
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JL', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison <= --- }
      Else If Op = '<=' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JLE', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison > --- }
      Else If Op = '>' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JG', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
        Res.TypeIdx := TY_IDX_LOGIC;
      End

      { --- Comparaison >= --- }
      Else If Op = '>=' Then
      Begin
        If (LeftType = TY_IDX_CHAR) Or
           (TypeInfer(Right) = TY_IDX_CHAR) Then
        Begin
          EmitInstrAB('MOV', 'SI', 'AX');
          EmitInstrAB('MOV', 'DI', 'BX');
          EmitInstrA('CALL', CL_RT_PFX + 'STRCMP');
          LblSkip := LabelGen;
          LblEnd  := LabelGen;
          EmitInstrAB('CMP', 'AX', '0');
          EmitInstrA('JGE', LblSkip);
          EmitInstrAB('MOV', 'AX', '0');
          EmitInstrA('JMP', LblEnd);
          EmitLabel(LblSkip);
          EmitInstrAB('MOV', 'AX', '1');
          EmitLabel(LblEnd);
        End
        Else
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
        End;
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
    ExprFlushToAX(Right);
    If Op = ':=' Then
    Begin
      If Res.SymIdx = -2 Then
      Begin
        { Affectation element tableau : arr[i] := val (TODO 15) }
        EmitComment('arr[i] := val (ASET)');
        EmitInstrAB('MOV', 'BX', '[_CL_ARRPTR]');
        EmitInstrAB('MOV', 'CX', '[_CL_ARRIDX]');
        EmitInstrA('CALL', CL_RT_PFX + 'ASET');
      End
      Else
      Begin
        { Affectation simple : stocker AX dans le lvalue }
        ExprStore(Res.SymIdx);
      End;
      Res.Kind    := EK_AX;
      Res.TypeIdx := Right.TypeIdx;
      Res.SymIdx  := -1;
    End
    Else
    Begin
      { Affectation composee += -= *= /= %= }
      { Charger la valeur courante dans BX }
      EmitInstrAB('MOV', 'BX', 'AX');
      If Res.SymIdx >= 0 Then
        EmitInstrAB('MOV', 'AX', ExprAddrOf(Res.SymIdx))
      Else
        EmitInstrAB('XOR', 'AX', 'AX');
      { Appliquer l operation }
      If Op = '+=' Then
        EmitInstrAB('ADD', 'AX', 'BX')
      Else If Op = '-=' Then
        EmitInstrAB('SUB', 'AX', 'BX')
      Else If Op = '*=' Then
      Begin
        EmitInstrAB('IMUL', 'AX', 'BX');
      End
      Else If Op = '/=' Then
      Begin
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
      End
      Else If Op = '%=' Then
      Begin
        EmitInstr('CWD');
        EmitInstrA('IDIV', 'BX');
        EmitInstrAB('MOV', 'AX', 'DX');
      End;
      { Stocker le resultat }
      ExprStore(Res.SymIdx);
      Res.Kind    := EK_AX;
      Res.TypeIdx := Right.TypeIdx;
      Res.SymIdx  := -1;
    End;
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
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

{ ---- TypeKindOf : retourner le TTypeTag d un indice de type -- }
(* Retourne TT_UNKNOWN si l indice est hors bornes.             *)

Function TypeKindOf(TypeIdx : Integer) : TTypeTag;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Tag
  Else
    TypeKindOf := TT_UNKNOWN;
End;

{ ---- TypeSizeof : taille en octets d un type ----------------- }
(* En 16 bits, toutes les valeurs tiennent dans 2 octets (un mot).
   Le tag de type occupe 1 octet supplementaire quand stocke
   avec la valeur (3 octets = tag + word).                       *)

Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;
End;

{ ---- TypeMangle : prefixe ASM selon le type pour labels ------ }
(* Prefixes Clipper :
     TT_NIL       -> _CLTN_  (nil)
     TT_NUMERIC   -> _CLTN_  (numeric)
     TT_CHARACTER -> _CLTC_  (character)
     TT_DATE      -> _CLTD_  (date)
     TT_LOGICAL   -> _CLTL_  (logical)
     TT_ARRAY     -> _CLTA_  (array)
     TT_CODEBLOCK -> _CLTB_  (codeblock)
     TT_OBJECT    -> _CLTO_  (object)
     TT_UNKNOWN   -> _CLTX_  (unknown)                          *)

Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TT_NIL       : TypeMangle := '_CLTN_';
    TT_NUMERIC   : TypeMangle := '_CLTN_';
    TT_CHARACTER : TypeMangle := '_CLTC_';
    TT_DATE      : TypeMangle := '_CLTD_';
    TT_LOGICAL   : TypeMangle := '_CLTL_';
    TT_ARRAY     : TypeMangle := '_CLTA_';
    TT_CODEBLOCK : TypeMangle := '_CLTB_';
    TT_OBJECT    : TypeMangle := '_CLTO_';
  Else
    TypeMangle := '_CLTX_';
  End;
End;

{ ---- TypeIsNumeric : vrai si le type est numerique ----------- }
(* Numeric, Date (julien) et Logical (0/1) sont numeriques.
   NIL est aussi traite comme numerique (valeur 0).              *)

Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  T : TTypeTag;
Begin
  T := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (T = TT_NUMERIC) Or (T = TT_DATE) Or
    (T = TT_LOGICAL) Or (T = TT_NIL);
End;

{ ---- TypeIsPtr : vrai si le type est un pointeur ------------- }
(* Character (chaine), Array, Codeblock et Object sont des
   pointeurs vers des blocs en memoire.                          *)

Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Var
  T : TTypeTag;
Begin
  T := TypeKindOf(TypeIdx);
  TypeIsPtr :=
    (T = TT_CHARACTER) Or (T = TT_ARRAY) Or
    (T = TT_CODEBLOCK) Or (T = TT_OBJECT);
End;

{ ---- TypeIsTruthy : evaluation booleenne d un type ----------- }
(* Clipper truthiness :
     NIL       -> toujours faux (pas de valeur)
     LOGICAL   -> potentiellement vrai (depend de la valeur)
     NUMERIC   -> potentiellement vrai (0=faux, autre=vrai)
     CHARACTER -> potentiellement vrai (chaine non vide)
     DATE      -> potentiellement vrai (date non nulle)
     ARRAY     -> toujours vrai (reference non nulle)
     CODEBLOCK -> toujours vrai
     OBJECT    -> toujours vrai
   Retourne True si la valeur du type peut etre vraie,
   False si elle est toujours fausse (NIL/UNKNOWN).              *)

Function TypeIsTruthy(TypeIdx : Integer) : Boolean;
Var
  T : TTypeTag;
Begin
  T := TypeKindOf(TypeIdx);
  Case T Of
    TT_NIL       : TypeIsTruthy := False;
    TT_LOGICAL   : TypeIsTruthy := True;  { a verifier au runtime }
    TT_NUMERIC   : TypeIsTruthy := True;  { a verifier au runtime }
    TT_CHARACTER : TypeIsTruthy := True;
    TT_DATE      : TypeIsTruthy := True;  { a verifier au runtime }
    TT_ARRAY     : TypeIsTruthy := True;
    TT_CODEBLOCK : TypeIsTruthy := True;
    TT_OBJECT    : TypeIsTruthy := True;
  Else
    TypeIsTruthy := False;
  End;
End;

{ ---- TypeCanCoerce : peut-on convertir SrcIdx vers DstIdx ? -- }
(* Clipper est dynamiquement type : la plupart des coercions
   sont verifiees au runtime. Au compile-time on autorise :
     - meme type -> toujours OK
     - anything -> UNKNOWN -> OK (perd l info de type)
     - NIL -> tout type -> OK (variable non initialisee)
     - LOGICAL -> NUMERIC (0/1 est deja un entier)
     - NUMERIC -> LOGICAL (0=.F., non-zero=.T.)
     - DATE -> NUMERIC (julien est un entier)
     - NUMERIC -> DATE (entier -> julien)
     - CHARACTER -> CHARACTER (toujours OK, meme type)
   Pour les conversions dynamiques (STR, VAL, CTOD, etc.)
   on deleguera au runtime via les builtins.                     *)

Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  { Meme type : toujours OK }
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { anything -> UNKNOWN : OK }
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { UNKNOWN -> anything : OK (polymorphe) }
  If SrcIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { NIL -> tout type : OK (variable non init) }
  If SrcIdx = TY_IDX_NIL Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { LOGICAL -> NUMERIC : 0/1 est deja un entier }
  If (SrcIdx = TY_IDX_LOGIC) And (DstIdx = TY_IDX_NUM) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { NUMERIC -> LOGICAL : 0=.F., non-zero=.T. }
  If (SrcIdx = TY_IDX_NUM) And (DstIdx = TY_IDX_LOGIC) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { DATE <-> NUMERIC : julien est un entier }
  If ((SrcIdx = TY_IDX_DATE) And (DstIdx = TY_IDX_NUM)) Or
     ((SrcIdx = TY_IDX_NUM) And (DstIdx = TY_IDX_DATE)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  { Pas de coercion statique possible }
  TypeCanCoerce := False;
End;

{ ---- TypeCoerceResult : type de resultat d une op binaire ---- }
(* Deduit le type de resultat en fonction des operandes et de
   l operateur. En Clipper :
     - Comparaisons -> LOGICAL
     - .AND. / .OR. -> LOGICAL
     - Arithmetique entre numeriques -> NUMERIC
     - + entre chaines -> CHARACTER (concatenation)
     - - entre chaines -> CHARACTER (concat+trim droite)
     - + entre dates et numeriques -> DATE
     - - entre deux dates -> NUMERIC (difference en jours)
     - $ -> LOGICAL (containment)
     - ** / ^ -> NUMERIC (puissance)
     - Affectation := -> type du cote droit                      *)

Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LT, RT : TTypeTag;
Begin
  LT := TypeKindOf(LeftIdx);
  RT := TypeKindOf(RightIdx);

  { Operateurs de comparaison -> LOGICAL }
  If (Op = '==') Or (Op = '=') Or
     (Op = '!=') Or (Op = '<>') Or (Op = '#') Or
     (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Then
  Begin
    TypeCoerceResult := TY_IDX_LOGIC;
    Exit;
  End;

  { Operateurs logiques -> LOGICAL }
  If (Op = '.AND.') Or (Op = '.OR.') Then
  Begin
    TypeCoerceResult := TY_IDX_LOGIC;
    Exit;
  End;

  { Containment $ -> LOGICAL }
  If Op = '$' Then
  Begin
    TypeCoerceResult := TY_IDX_LOGIC;
    Exit;
  End;

  { Concatenation chaines : + ou - avec deux chaines -> CHARACTER }
  If (Op = '+') Or (Op = '-') Then
  Begin
    If (LT = TT_CHARACTER) And (RT = TT_CHARACTER) Then
    Begin
      TypeCoerceResult := TY_IDX_CHAR;
      Exit;
    End;
  End;

  { Date + Numeric ou Numeric + Date -> DATE }
  If Op = '+' Then
  Begin
    If ((LT = TT_DATE) And (RT = TT_NUMERIC)) Or
       ((LT = TT_NUMERIC) And (RT = TT_DATE)) Then
    Begin
      TypeCoerceResult := TY_IDX_DATE;
      Exit;
    End;
  End;

  { Date - Numeric -> DATE (reculer) }
  If Op = '-' Then
  Begin
    If (LT = TT_DATE) And (RT = TT_NUMERIC) Then
    Begin
      TypeCoerceResult := TY_IDX_DATE;
      Exit;
    End;
    { Date - Date -> NUMERIC (difference en jours) }
    If (LT = TT_DATE) And (RT = TT_DATE) Then
    Begin
      TypeCoerceResult := TY_IDX_NUM;
      Exit;
    End;
  End;

  { Puissance ** ou ^ -> NUMERIC }
  If (Op = '**') Or (Op = '^') Then
  Begin
    TypeCoerceResult := TY_IDX_NUM;
    Exit;
  End;

  { Arithmetique generale : + - * / % entre numeriques -> NUMERIC }
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '%') Then
  Begin
    If TypeIsNumeric(LeftIdx) And TypeIsNumeric(RightIdx) Then
    Begin
      TypeCoerceResult := TY_IDX_NUM;
      Exit;
    End;
  End;

  { Affectation := += -= *= /= %= -> type du cote droit }
  If (Op = ':=') Or (Op = '+=') Or (Op = '-=') Or
     (Op = '*=') Or (Op = '/=') Or (Op = '%=') Then
  Begin
    TypeCoerceResult := RightIdx;
    Exit;
  End;

  { Par defaut : polymorphe }
  TypeCoerceResult := TY_UNKNOWN;
End;

{ ---- TypeInfer : deduire le type d une expression ------------ }
(* A partir d une TExprVal, infere le type :
     EK_IMM -> NUMERIC (immediate = entier)
     Sinon  -> utilise TypeIdx de l expression
     Si TypeIdx non defini -> UNKNOWN                            *)

Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_NUM
  Else If E.TypeIdx >= 0 Then
    TypeInfer := E.TypeIdx
  Else
    TypeInfer := TY_UNKNOWN;
End;

{ ---- TypeLookupName : chercher un type par son nom ----------- }
(* Recherche insensible a la casse (UPPER) dans TypeTab.
   Retourne l indice du type ou TY_UNKNOWN si non trouve.        *)

Function TypeLookupName(Const Name : TString) : Integer;
Var
  I : Integer;
  UName : TString;
Begin
  UName := StrUpper(Name);
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = UName Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

{ ---- TypeInit : initialiser la table des types --------------- }
(* Cree les 8 types primitifs Clipper :
     0: NIL       (U) - valeur non initialisee, taille 2
     1: NUMERIC   (N) - entier 16 bits signe, taille 2
     2: CHARACTER (C) - pointeur vers chaine, taille 2
     3: DATE      (D) - entier julien 16 bits, taille 2
     4: LOGICAL   (L) - 0 ou 1, taille 2
     5: ARRAY     (A) - pointeur vers bloc tableau, taille 2
     6: CODEBLOCK (B) - pointeur vers descripteur, taille 2
     7: OBJECT    (O) - pointeur vers instance, taille 2
   Tous ont une taille de 2 octets (un mot 16 bits).
   Le tag de type (1 octet) est stocke separement.               *)

Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name := '';
    TypeTab[I].Tag  := TT_UNKNOWN;
    TypeTab[I].Size := 0;
  End;

  { NIL }
  TypeTab[TY_IDX_NIL].Name := 'NIL';
  TypeTab[TY_IDX_NIL].Tag  := TT_NIL;
  TypeTab[TY_IDX_NIL].Size := 2;

  { NUMERIC }
  TypeTab[TY_IDX_NUM].Name := 'NUMERIC';
  TypeTab[TY_IDX_NUM].Tag  := TT_NUMERIC;
  TypeTab[TY_IDX_NUM].Size := 2;

  { CHARACTER }
  TypeTab[TY_IDX_CHAR].Name := 'CHARACTER';
  TypeTab[TY_IDX_CHAR].Tag  := TT_CHARACTER;
  TypeTab[TY_IDX_CHAR].Size := 2;

  { DATE }
  TypeTab[TY_IDX_DATE].Name := 'DATE';
  TypeTab[TY_IDX_DATE].Tag  := TT_DATE;
  TypeTab[TY_IDX_DATE].Size := 2;

  { LOGICAL }
  TypeTab[TY_IDX_LOGIC].Name := 'LOGICAL';
  TypeTab[TY_IDX_LOGIC].Tag  := TT_LOGICAL;
  TypeTab[TY_IDX_LOGIC].Size := 2;

  { ARRAY }
  TypeTab[TY_IDX_ARRAY].Name := 'ARRAY';
  TypeTab[TY_IDX_ARRAY].Tag  := TT_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size := 2;

  { CODEBLOCK }
  TypeTab[TY_IDX_BLOCK].Name := 'CODEBLOCK';
  TypeTab[TY_IDX_BLOCK].Tag  := TT_CODEBLOCK;
  TypeTab[TY_IDX_BLOCK].Size := 2;

  { OBJECT }
  TypeTab[TY_IDX_OBJECT].Name := 'OBJECT';
  TypeTab[TY_IDX_OBJECT].Tag  := TT_OBJECT;
  TypeTab[TY_IDX_OBJECT].Size := 2;

  TypeCount := TY_PRIM_COUNT;
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES [IMPLEMENTE]
  ============================================================ }

{ ---- DataAddTagged : ajouter une entree taggee tag+valeur --- }
(* Cree une entree DK_TAGGED dans DataTab : 1 octet tag de type
   Clipper [TY_IDX] suivi d un mot 16 bits valeur.
   Utilise pour les variables PUBLIC, STATIC, et parametres
   stockes dans le segment DATA.
   Retourne l index dans DataTab ou -1 si plein.                *)

Function DataAddTagged(Const Lbl : TString;
                       ATagVal : Integer; AIntVal : LongInt;
                       Const AStrVal : TString) : Integer;
Var
  Idx : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    CompileError('segment DATA plein (max=' + IntToStr(MAX_DATA) + ')');
    DataAddTagged := -1;
    Exit;
  End;
  Idx := DataCount;
  DataTab[Idx].LblName := Lbl;
  DataTab[Idx].Kind    := DK_TAGGED;
  DataTab[Idx].IntVal  := AIntVal;
  DataTab[Idx].StrVal  := AStrVal;
  DataTab[Idx].TagVal  := ATagVal;
  Inc(DataCount);
  DataAddTagged := Idx;
End;

{ ---- DataAddPublicVar : variable PUBLIC dans DATA ------------ }
(* Cree une variable PUBLIC globale dans le segment DATA.
   Le label est prefixe _CLG_ (ex: _CLG_COUNTER).
   Format en memoire : DB tag [TY_IDX] + DW valeur.
   Enregistre aussi dans la table des symboles (SC_PUBLIC).
   Retourne l index dans DataTab ou -1 si erreur.               *)

Function DataAddPublicVar(Const Name : TString;
                          ATypeIdx : Integer;
                          AInitVal : LongInt) : Integer;
Var
  Lbl : TString;
  Idx : Integer;
  SI  : Integer;
Begin
  Lbl := CL_GLB_PFX + SymNameClean(Name);
  Idx := DataAddTagged(Lbl, ATypeIdx, AInitVal, '');
  If Idx >= 0 Then
  Begin
    SI := SymAdd(Name, SC_PUBLIC, ATypeIdx, Idx);
    If SI < 0 Then
    Begin
      CompileError('impossible d ajouter PUBLIC ' + Name + ' dans SymTab');
      DataAddPublicVar := -1;
      Exit;
    End;
  End;
  DataAddPublicVar := Idx;
End;

{ ---- DataAddStaticVar : variable STATIC dans DATA ------------ }
(* Cree une variable STATIC dans le segment DATA.
   Le label est prefixe _CLS_ (ex: _CLS_TOTAL).
   Persiste entre les appels de fonction : initialisee une seule
   fois au premier appel, conserve sa valeur ensuite.
   Format en memoire : DB tag [TY_IDX] + DW valeur.
   Enregistre aussi dans la table des symboles (SC_STATIC).
   Retourne l index dans DataTab ou -1 si erreur.               *)

Function DataAddStaticVar(Const Name : TString;
                          ATypeIdx : Integer;
                          AInitVal : LongInt) : Integer;
Var
  Lbl : TString;
  Idx : Integer;
  SI  : Integer;
Begin
  Lbl := CL_STAT_PFX + SymNameClean(Name);
  Idx := DataAddTagged(Lbl, ATypeIdx, AInitVal, '');
  If Idx >= 0 Then
  Begin
    SI := SymAdd(Name, SC_STATIC, ATypeIdx, Idx);
    If SI < 0 Then
    Begin
      CompileError('impossible d ajouter STATIC ' + Name + ' dans SymTab');
      DataAddStaticVar := -1;
      Exit;
    End;
  End;
  DataAddStaticVar := Idx;
End;

{ ---- DataAddDate : ajouter une date litterale dans DATA ------ }
(* Stocke une date Clipper sous forme de valeur julienne 16 bits.
   Le tag est TY_IDX_DATE, la valeur est le jour julien.
   Retourne l index dans DataTab ou -1 si erreur.               *)

Function DataAddDate(Const Lbl : TString;
                     JulianVal : LongInt) : Integer;
Begin
  DataAddDate := DataAddTagged(Lbl, TY_IDX_DATE, JulianVal, '');
End;

{ ---- DataAddArray : ajouter un tableau statique dans DATA ---- }
(* Cree un descripteur de tableau statique dans DATA.
   Le tag est TY_IDX_ARRAY, la valeur stockee est le nombre
   d elements. Les elements eux-memes seront des entrees
   DK_TAGGED consecutives ajoutees apres l entete.
   Retourne l index dans DataTab ou -1 si erreur.               *)

Function DataAddArray(Const Lbl : TString;
                      ElemCount : Integer) : Integer;
Begin
  If ElemCount < 0 Then
  Begin
    CompileError('taille de tableau invalide : ' + IntToStr(ElemCount));
    DataAddArray := -1;
    Exit;
  End;
  DataAddArray := DataAddTagged(Lbl, TY_IDX_ARRAY, LongInt(ElemCount), '');
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ExprAddrOf : adresse MASM d un symbole ------------------- }
(* Retourne l expression d adresse MASM pour le symbole SIdx :
     SC_LOCAL   -> WORD PTR [BP-offset]
     SC_PARAM   -> WORD PTR [BP+offset]
     SC_STATIC  -> WORD PTR [label+1]  (tag is at [label], value at [label+1])
     SC_PUBLIC  -> WORD PTR [label+1]
     SC_PRIVATE -> WORD PTR [BP-offset] si offset<>0, sinon DATA label
     SC_FUNC/SC_PROC -> '' (pas d adresse memoire)
   Pour les variables taggees en DATA, +1 saute le tag octet.   *)

Function ExprAddrOf(SIdx : Integer) : TString;
Var
  NS : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    ExprAddrOf := '0';
    Exit;
  End;
  Case SymTab[SIdx].Cat Of
    SC_LOCAL :
    Begin
      Str(SymTab[SIdx].Offset, NS);
      ExprAddrOf := 'WORD PTR [BP-' + NS + ']';
    End;
    SC_PARAM :
    Begin
      Str(SymTab[SIdx].Offset, NS);
      ExprAddrOf := 'WORD PTR [BP+' + NS + ']';
    End;
    SC_STATIC, SC_PUBLIC :
    Begin
      { DK_TAGGED : DB tag, DW valeur -> valeur est a label+1 }
      ExprAddrOf := 'WORD PTR [' + SymTab[SIdx].MangledName + '+1]';
    End;
    SC_PRIVATE :
    Begin
      If SymTab[SIdx].Offset > 0 Then
      Begin
        Str(SymTab[SIdx].Offset, NS);
        ExprAddrOf := 'WORD PTR [BP-' + NS + ']';
      End
      Else
        ExprAddrOf := 'WORD PTR [' + SymTab[SIdx].MangledName + '+1]';
    End;
  Else
    ExprAddrOf := '0';
  End;
End;

{ ---- ExprStore : stocker AX dans un symbole ------------------- }
(* Ecrit la valeur de AX dans la variable designee par SIdx.
   Ignore silencieusement si SIdx invalide (pas de lvalue).
   Pour les variables taggees (PUBLIC/STATIC) on met aussi a jour
   le tag de type si connu.                                       *)

Procedure ExprStore(SIdx : Integer);
Var
  Addr : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Addr := ExprAddrOf(SIdx);
  If Addr = '0' Then Exit;
  EmitInstrAB('MOV', Addr, 'AX');
  SymTab[SIdx].IsInit := True;
End;

{ ---- ExprLoad : charger un symbole dans AX et TExprVal -------- }
(* Genere MOV AX, [addr] et remplit Res.
   Pour FUNC/PROC : met juste l offset de CALL, pas de load.     *)

Procedure ExprLoad(SIdx : Integer; Var Res : TExprVal);
Var
  Addr : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then
  Begin
    ExprMakeNone(Res);
    Exit;
  End;
  { FUNC/PROC : pas de chargement de valeur }
  If (SymTab[SIdx].Cat = SC_FUNC) Or (SymTab[SIdx].Cat = SC_PROC) Then
  Begin
    Res.Kind    := EK_NONE;
    Res.ImmVal  := 0;
    Res.TypeIdx := SymTab[SIdx].TypeIdx;
    Res.Offset  := 0;
    Res.SymIdx  := SIdx;
    Exit;
  End;
  Addr := ExprAddrOf(SIdx);
  If Addr <> '0' Then
    EmitInstrAB('MOV', 'AX', Addr)
  Else
    EmitInstrAB('XOR', 'AX', 'AX');
  Res.Kind    := EK_AX;
  Res.ImmVal  := 0;
  Res.TypeIdx := SymTab[SIdx].TypeIdx;
  Res.Offset  := SymTab[SIdx].Offset;
  Res.SymIdx  := SIdx;
End;

{ ---- DeclAllocSym : allouer un symbole pour declaration ------- }
(* Cree un nouveau symbole dans SymTab pour LOCAL/STATIC/PRIVATE/
   PUBLIC/PARAM. Gere l offset pile pour les LOCALs et PARAMs.
   Pour STATIC/PUBLIC, cree l entree DATA taggee.
   Retourne l indice du symbole ou -1 si erreur.                 *)

Function DeclAllocSym(Const Name : TString;
                      Cat : TSymCat) : Integer;
Var
  Existing : Integer;
  SI       : Integer;
  Ofs      : Integer;
  Lbl      : TString;
Begin
  { Verifier redeclaration dans le meme scope }
  Existing := SymFindInScope(Name);
  If (Existing >= 0) And (SymTab[Existing].Cat = Cat) Then
  Begin
    If Opts.Warnings Then
      WarnMsg('redeclaration de ' + Name + ' dans le meme scope');
    DeclAllocSym := Existing;
    Exit;
  End;

  Case Cat Of
    SC_LOCAL :
    Begin
      { Allouer sur la pile : [BP-n] }
      { En Clipper chaque variable = 3 octets (tag + word) }
      { Mais en pratique on utilise juste le word sur la pile }
      Inc(SymNextOffset, 2);
      Ofs := SymNextOffset;
      SI := SymAdd(Name, SC_LOCAL, TY_IDX_NIL, Ofs);
      Inc(CurFrameSize);
      DeclAllocSym := SI;
    End;
    SC_PARAM :
    Begin
      { Parametres sont a [BP+4], [BP+6], etc. }
      { (BP+0=ancien BP, BP+2=adresse retour) }
      Ofs := ParamNextOffset;
      SI := SymAdd(Name, SC_PARAM, TY_IDX_NIL, Ofs);
      Inc(ParamNextOffset, 2);
      DeclAllocSym := SI;
    End;
    SC_STATIC :
    Begin
      { Variable STATIC : cree dans DATA via DataAddStaticVar }
      Lbl := CL_STAT_PFX + SymNameClean(Name);
      DataAddTagged(Lbl, TY_IDX_NIL, 0, '');
      SI := SymAdd(Name, SC_STATIC, TY_IDX_NIL, DataCount - 1);
      DeclAllocSym := SI;
    End;
    SC_PUBLIC :
    Begin
      { Variable PUBLIC : cree dans DATA via DataAddPublicVar }
      { DataAddPublicVar ajoute aussi dans SymTab }
      Existing := SymFind(Name);
      If (Existing >= 0) And (SymTab[Existing].Cat = SC_PUBLIC) Then
      Begin
        DeclAllocSym := Existing;
        Exit;
      End;
      Lbl := CL_GLB_PFX + SymNameClean(Name);
      DataAddTagged(Lbl, TY_IDX_NIL, 0, '');
      SI := SymAdd(Name, SC_PUBLIC, TY_IDX_NIL, DataCount - 1);
      DeclAllocSym := SI;
    End;
    SC_PRIVATE :
    Begin
      { Variable PRIVATE : comme LOCAL sur la pile }
      Inc(SymNextOffset, 2);
      Ofs := SymNextOffset;
      SI := SymAdd(Name, SC_PRIVATE, TY_IDX_NIL, Ofs);
      Inc(CurFrameSize);
      DeclAllocSym := SI;
    End;
  Else
    SI := SymAdd(Name, Cat, TY_IDX_NIL, 0);
    DeclAllocSym := SI;
  End;
End;

{ ---- DeclInitUndef : initialiser une variable non definie ----- }
(* Emet MOV [addr], 0 pour initialiser a NIL/0.                  *)

Procedure DeclInitUndef(SIdx : Integer);
Var
  Addr : TString;
Begin
  If (SIdx < 0) Or (SIdx >= SymCount) Then Exit;
  Addr := ExprAddrOf(SIdx);
  If Addr = '0' Then Exit;
  EmitInstrAB('MOV', Addr, '0');
End;

{ ---- ParseDeclStmt : parser une declaration LOCAL/STATIC/etc. - }
(* Syntaxe Clipper :
     LOCAL  var1 [:= expr] [, var2 [:= expr]] ...
     STATIC var1 [:= expr] [, var2 [:= expr]] ...
     PRIVATE var1 [, var2] ...
     PUBLIC var1 [, var2] ...
     PARAMETERS var1, var2, ...
   Le mot-cle a deja ete consomme par le caller.
   Pour chaque declarateur :
     - allouer le symbole via DeclAllocSym
     - si := expr, parser l expression, flush AX, stocker
     - sinon initialiser a 0 (NIL)                                 *)

Procedure ParseDeclStmt(Const Kw : TString);
Var
  Cat      : TSymCat;
  VarName  : TString;
  SI       : Integer;
  InitExpr : TExprVal;
Begin
  { Determiner la categorie selon le mot-cle }
  If Kw = 'LOCAL' Then
    Cat := SC_LOCAL
  Else If Kw = 'STATIC' Then
    Cat := SC_STATIC
  Else If (Kw = 'PRIVATE') Or (Kw = 'PRIV') Then
    Cat := SC_PRIVATE
  Else If (Kw = 'PUBLIC') Or (Kw = 'PUBL') Then
    Cat := SC_PUBLIC
  Else If (Kw = 'PARAMETERS') Or (Kw = 'PARA') Then
    Cat := SC_PARAM
  Else If Kw = 'DECLARE' Then
    Cat := SC_LOCAL
  Else
  Begin
    CompileError('mot-cle de declaration inconnu : ' + Kw);
    Exit;
  End;

  EmitComment(Kw + ' declaration');

  { Boucle sur les declarateurs separes par virgule }
  Repeat
    { Attendre un identificateur }
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError(Kw + ' : identificateur attendu, trouve "' +
                   CurToken.Val + '"');
      Exit;
    End;
    VarName := CurToken.Val;
    ParserAdvance;

    { Allouer le symbole }
    SI := DeclAllocSym(VarName, Cat);

    { Initialisation optionnelle := expr }
    If (CurToken.Kind = TK_OP) And
       ((CurToken.Val = ':=') Or (CurToken.Val = '=')) Then
    Begin
      ParserAdvance; { consommer := ou = }
      ParseExpr(InitExpr);
      ExprFlushToAX(InitExpr);
      ExprStore(SI);
      If SI >= 0 Then
        SymTab[SI].TypeIdx := InitExpr.TypeIdx;
    End
    Else
    Begin
      { Pas d initialisation : mettre a 0 (NIL) }
      DeclInitUndef(SI);
    End;

    { Virgule -> prochain declarateur }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until CurToken.Kind = TK_EOF;
End;

{ ---- ParseStoreStmt : parser STORE expr TO var1, var2, ... ---- }
(* Syntaxe dBASE/Clipper :
     STORE expr TO var1 [, var2 ...]
   Evalue l expression, puis stocke dans chaque variable.
   Le mot-cle STORE a deja ete consomme par le caller.            *)

Procedure ParseStoreStmt;
Var
  StoreExpr : TExprVal;
  SI        : Integer;
  VarName   : TString;
Begin
  EmitComment('STORE ... TO ...');
  ParseExpr(StoreExpr);
  ExprFlushToAX(StoreExpr);

  { Attendre le mot-cle TO }
  If Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO')) Then
  Begin
    CompileError('STORE : mot-cle TO attendu');
    Exit;
  End;
  ParserAdvance; { consommer TO }

  { Sauvegarder AX car on va stocker dans plusieurs vars }
  EmitInstr('PUSH   AX');

  { Boucle sur les variables cibles }
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      CompileError('STORE TO : identificateur attendu');
      Break;
    End;
    VarName := CurToken.Val;
    ParserAdvance;

    SI := SymFind(VarName);
    If SI < 0 Then
    Begin
      { Variable non declaree : creer PRIVATE implicite }
      SI := DeclAllocSym(VarName, SC_PRIVATE);
    End;

    { Restaurer AX et stocker }
    EmitInstrAB('MOV', 'AX', 'WORD PTR [SP]');
    ExprStore(SI);
    If SI >= 0 Then
      SymTab[SI].TypeIdx := StoreExpr.TypeIdx;

    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until CurToken.Kind = TK_EOF;

  { Nettoyer la pile }
  EmitInstrAB('ADD', 'SP', '2');
End;

{ ---- ParseExprStmt : parser une instruction expression -------- }
(* Analyse une expression comme instruction (appel de fonction,
   affectation, etc.). Le resultat est ignore.                    *)

Procedure ParseExprStmt;
Var
  Res : TExprVal;
Begin
  ParseExpr(Res);
  { Materialiser si necessaire (pour les effets de bord) }
  If Res.Kind = EK_IMM Then
    { Constante seule : pas d effet de bord }
  Else If Res.Kind = EK_NONE Then
    { Pas de valeur }
  Else
    { Resultat ignore }
    ;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM [IMPLEMENTE]
  ============================================================ }

{ ---- EmitBlankLine : ligne vide ------------------------------ }

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

{ ---- EmitOpen : ouvrir le fichier de sortie ASM -------------- }

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

{ ---- EmitHeader : en-tete MASM (.MODEL SMALL, _TEXT SEGMENT) - }

Procedure EmitHeader;
Begin
  EmitComment('Genere par CLIPPER86 v' + CLIPPER86_VERSION +
              ' - ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
  { Point d entree : _CLP_Main }
  EmitLabel('_CLP_Main');
  { Initialiser DS sur le segment de donnees }
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  { Appeler les INIT PROCEDUREs (TODO 17) - le bloc sera emis a la fin }
  EmitInstrA('CALL', '_CLL_INITBLOCK');
  EmitBlankLine;
  EmitComment('--- debut du code genere ---');
  EmitBlankLine;
End;

{ ---- EmitProlog : preambule de fonction (cadre BP) ----------- }

Procedure EmitProlog;
Begin
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  If CurFrameSize > 0 Then
    EmitInstrAB('SUB', 'SP', IntToStr(CurFrameSize * 2));
End;

{ ---- EmitEpilog : epilogue de fonction (restaurer SP/BP) ----- }

Procedure EmitEpilog;
Begin
  If CurFnRetLbl <> '' Then
    EmitLabel(CurFnRetLbl);
  If CurFrameSize > 0 Then
    EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 11 - EXPRESSIONS BINAIRES [IMPLEMENTE]
  ============================================================ }

{ ---- EmitExprRuntime : routines x86 pour expressions binaires }
(* Emet les routines assembleur utilisees par ParseExprPrec :
   _CLRT_POWER     : puissance entiere (AX=base, BX=exp) -> AX
   _CLRT_CONCAT    : concatenation chaines (SI=src1, DI=src2) -> AX=ptr
   _CLRT_STRCMP     : comparaison souple (SI=s1, DI=s2) -> AX=-1/0/1
   _CLRT_STRCMPEXACT: comparaison exacte (SI=s1, DI=s2) -> AX=0|1
   _CLRT_INSTR     : recherche sous-chaine (SI=sub, DI=str) -> AX=0|1
   _CLRT_STRTRIMR  : trim espaces a droite (SI=str) -> AX=ptr
   _CL_CATBUF      : buffer de concatenation (256 octets) dans DATA    *)

Procedure EmitExprRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Routines runtime expressions binaires (TODO 11) ===');
  EmitBlankLine;

  { --- _CLRT_POWER : puissance entiere --- }
  (* base = 1er param [BP+4], exposant = 2e param [BP+6]
     Resultat dans AX. Exposant negatif -> AX=0.                    *)
  EmitLabel(CL_RT_PFX + 'POWER');
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrAB('MOV', 'AX', '[BP+4]');   { base }
  EmitInstrAB('MOV', 'CX', '[BP+6]');   { exposant }
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JG', CL_RT_PFX + 'POW_LP');
  EmitInstrAB('MOV', 'AX', '1');        { base^0 = 1 }
  EmitInstrA('JMP', CL_RT_PFX + 'POW_DN');
  EmitLabel(CL_RT_PFX + 'POW_LP');
  EmitInstrAB('MOV', 'BX', 'AX');       { BX = accumulateur }
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'POW_DN');
  EmitLabel(CL_RT_PFX + 'POW_L2');
  EmitInstrA('IMUL', 'BX');             { AX = AX * BX }
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'POW_L2');
  EmitLabel(CL_RT_PFX + 'POW_DN');
  EmitInstr('POP    BP');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_CONCAT : concatenation de chaines --- }
  (* SI=source1, DI=source2
     Copie src1 puis src2 dans _CL_CATBUF, retourne AX=OFFSET _CL_CATBUF *)
  EmitLabel(CL_RT_PFX + 'CONCAT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'BX', 'DI');       { BX = src2 sauvegarde }
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_CATBUF');
  EmitInstrAB('MOV', 'CX', '0');
  { Copier src1 }
  EmitLabel(CL_RT_PFX + 'CAT_L1');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'CAT_S2');
  EmitInstr('STOSB');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('CMP', 'CX', '254');
  EmitInstrA('JAE', CL_RT_PFX + 'CAT_EN');
  EmitInstrA('JMP', CL_RT_PFX + 'CAT_L1');
  { Copier src2 }
  EmitLabel(CL_RT_PFX + 'CAT_S2');
  EmitInstrAB('MOV', 'SI', 'BX');       { SI = source2 }
  EmitLabel(CL_RT_PFX + 'CAT_L2');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'CAT_EN');
  EmitInstr('STOSB');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('CMP', 'CX', '254');
  EmitInstrA('JAE', CL_RT_PFX + 'CAT_EN');
  EmitInstrA('JMP', CL_RT_PFX + 'CAT_L2');
  EmitLabel(CL_RT_PFX + 'CAT_EN');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('STOSB');            { terminateur nul }
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_CATBUF');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_STRCMP : comparaison souple de chaines --- }
  (* SI=str1, DI=str2
     Compare octet par octet, s arrete a la longueur de str2
     Retourne AX = -1 (inferieur), 0 (egal), 1 (superieur)
     Semantique Clipper : = compare sur la longueur de droite      *)
  EmitLabel(CL_RT_PFX + 'STRCMP');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'SCMP_LP');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SCMP_EQ');  { fin de str2 -> egal }
  EmitInstrAB('MOV', 'AH', '[SI]');
  EmitInstrAB('CMP', 'AH', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SCMP_LT');  { str1 plus courte -> inferieur }
  EmitInstrAB('CMP', 'AH', 'AL');
  EmitInstrA('JB', CL_RT_PFX + 'SCMP_LT');
  EmitInstrA('JA', CL_RT_PFX + 'SCMP_GT');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SCMP_LP');
  EmitLabel(CL_RT_PFX + 'SCMP_EQ');
  EmitInstrAB('MOV', 'AX', '0');    { egal }
  EmitInstrA('JMP', CL_RT_PFX + 'SCMP_DN');
  EmitLabel(CL_RT_PFX + 'SCMP_LT');
  EmitInstrAB('MOV', 'AX', '-1');   { inferieur }
  EmitInstrA('JMP', CL_RT_PFX + 'SCMP_DN');
  EmitLabel(CL_RT_PFX + 'SCMP_GT');
  EmitInstrAB('MOV', 'AX', '1');    { superieur }
  EmitLabel(CL_RT_PFX + 'SCMP_DN');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_STRCMPEXACT : comparaison exacte == --- }
  (* SI=str1, DI=str2
     Compare longueur + contenu exact.
     Retourne AX=1 si identique, AX=0 sinon.                      *)
  EmitLabel(CL_RT_PFX + 'STRCMPEXACT');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'SXCMP_LP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', 'AH', '[DI]');
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', CL_RT_PFX + 'SXCMP_NE');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SXCMP_EQ');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SXCMP_LP');
  EmitLabel(CL_RT_PFX + 'SXCMP_EQ');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('JMP', CL_RT_PFX + 'SXCMP_DN');
  EmitLabel(CL_RT_PFX + 'SXCMP_NE');
  EmitInstrAB('MOV', 'AX', '0');
  EmitLabel(CL_RT_PFX + 'SXCMP_DN');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_INSTR : recherche sous-chaine --- }
  (* SI=sous-chaine, DI=chaine
     Retourne AX=1 si trouvee, AX=0 sinon.
     Parcourt DI a la recherche de SI.                             *)
  EmitLabel(CL_RT_PFX + 'INSTR');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'BX', 'SI');       { BX = debut sous-chaine }
  EmitLabel(CL_RT_PFX + 'INS_OLP');
  EmitInstrAB('MOV', 'AL', '[DI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'INS_NF');  { fin chaine -> pas trouve }
  EmitInstrAB('MOV', 'SI', 'BX');       { reset sous-chaine }
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'INS_ILP');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'INS_FD');  { fin sous-chaine -> trouve }
  EmitInstrAB('MOV', 'AH', '[DI]');
  EmitInstrAB('CMP', 'AH', '0');
  EmitInstrA('JE', CL_RT_PFX + 'INS_NI');  { fin chaine -> pas ici }
  EmitInstrAB('CMP', 'AL', 'AH');
  EmitInstrA('JNE', CL_RT_PFX + 'INS_NI');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'INS_ILP');
  EmitLabel(CL_RT_PFX + 'INS_FD');
  EmitInstr('POP    DI');               { jeter DI sauvegarde }
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('JMP', CL_RT_PFX + 'INS_DN');
  EmitLabel(CL_RT_PFX + 'INS_NI');
  EmitInstr('POP    DI');               { restaurer DI }
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'INS_OLP');
  EmitLabel(CL_RT_PFX + 'INS_NF');
  EmitInstrAB('MOV', 'AX', '0');
  EmitLabel(CL_RT_PFX + 'INS_DN');
  EmitInstr('POP    BX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_STRTRIMR : trim espaces a droite --- }
  (* SI=chaine source, copie dans _CL_CATBUF sans espaces a droite
     Retourne AX = OFFSET _CL_CATBUF                               *)
  EmitLabel(CL_RT_PFX + 'STRTRIMR');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_CATBUF');
  EmitInstrAB('MOV', 'CX', '0');
  { Copier la chaine }
  EmitLabel(CL_RT_PFX + 'STR_L1');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'STR_TR');
  EmitInstr('STOSB');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('CMP', 'CX', '254');
  EmitInstrA('JAE', CL_RT_PFX + 'STR_TR');
  EmitInstrA('JMP', CL_RT_PFX + 'STR_L1');
  { Trim espaces a droite }
  EmitLabel(CL_RT_PFX + 'STR_TR');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'STR_DN');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '32');  { 32 = espace }
  EmitInstrA('JNE', CL_RT_PFX + 'STR_DN');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'STR_TR');
  EmitLabel(CL_RT_PFX + 'STR_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_CATBUF');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 12 - ENTREES/SORTIES ECRAN [IMPLEMENTE]
  ============================================================ }

{ ---- ParseQOutStmt : ? expr, ... et ?? expr, ... ------------- }
(* ? affiche les expressions separees par des espaces + retour a la ligne.
   ?? affiche sans retour a la ligne.                              *)

Procedure ParseQOutStmt(WithCRLF : Boolean);
Var
  Arg    : TExprVal;
  First  : Boolean;
Begin
  EmitComment('? / ?? display');
  First := True;
  { Parse comma-separated expressions }
  While (CurToken.Kind <> TK_EOF) Do
  Begin
    { Stop at end of statement }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then Break;
    { Stop at next keyword that is a statement }
    If (CurToken.Kind = TK_KEYWORD) Then
    Begin
      If (CurToken.Val = '?') Or (CurToken.Val = '??') Or
         (CurToken.Val = 'IF') Or (CurToken.Val = 'DO') Or
         (CurToken.Val = 'FOR') Or (CurToken.Val = 'RETURN') Or
         (CurToken.Val = 'FUNCTION') Or (CurToken.Val = 'PROCEDURE') Or
         (CurToken.Val = 'LOCAL') Or (CurToken.Val = 'PRIVATE') Or
         (CurToken.Val = 'PUBLIC') Or (CurToken.Val = 'STORE') Or
         (CurToken.Val = 'READ') Or (CurToken.Val = 'CLEAR') Or
         (CurToken.Val = 'SET') Or (CurToken.Val = 'ENDIF') Or
         (CurToken.Val = 'ENDDO') Or (CurToken.Val = 'NEXT') Or
         (CurToken.Val = 'ELSE') Or (CurToken.Val = 'ELSEIF') Then
        Break;
    End;

    { Separator: if not first, print a space }
    If Not First Then
    Begin
      EmitInstrAB('MOV', 'AL', '32');  { space char }
      EmitInstrA('CALL', CL_RT_PFX + 'PRINTCHAR');
    End;

    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTVAL');
    First := False;

    { Comma separator }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  End;

  If WithCRLF Then
    EmitInstrA('CALL', CL_RT_PFX + 'PRINTLN');
End;

{ ---- ParseAtStmt : @ row,col SAY/GET/TO ---------------------- }

Procedure ParseAtStmt;
Var
  RowExpr, ColExpr, ValExpr : TExprVal;
  SIdx : Integer;
Begin
  { @ already consumed }
  { Parse row expression }
  ParseExpr(RowExpr);
  ExprFlushToAX(RowExpr);
  EmitInstr('PUSH   AX');  { save row }

  { Expect comma }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    ParserAdvance
  Else
    CompileError('attendu '','' apres @ row');

  { Parse col expression }
  ParseExpr(ColExpr);
  ExprFlushToAX(ColExpr);
  EmitInstrAB('MOV', 'DL', 'AL');  { DL = col }
  EmitInstr('POP    AX');
  EmitInstrAB('MOV', 'DH', 'AL');  { DH = row }
  EmitInstrA('CALL', CL_RT_PFX + 'GOTOXY');

  { Determine: SAY, GET, or TO }
  If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If StrUpperCase(CurToken.Val) = 'SAY' Then
    Begin
      ParserAdvance;  { consume SAY }
      EmitComment('@ SAY');
      ParseExpr(ValExpr);
      ExprFlushToAX(ValExpr);
      EmitInstrA('CALL', CL_RT_PFX + 'PRINTVAL');
      { Optional PICTURE clause - skip it }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        If StrUpperCase(CurToken.Val) = 'PICTURE' Then
        Begin
          ParserAdvance;  { consume PICTURE }
          ParseExpr(ValExpr);  { consume mask expr, ignore for now }
          EmitComment('PICTURE (ignored - stub)');
        End;
      End;
    End
    Else If StrUpperCase(CurToken.Val) = 'GET' Then
    Begin
      ParserAdvance;  { consume GET }
      EmitComment('@ GET (stub)');
      { Parse the variable }
      If CurToken.Kind = TK_IDENT Then
      Begin
        SIdx := SymFind(CurToken.Val);
        If SIdx < 0 Then
          SIdx := DeclAllocSym(CurToken.Val, SC_PRIVATE);
        ParserAdvance;
        { Register the GET: push addr into GETLIST }
        EmitComment('register GET ' + SymTab[SIdx].Name);
        EmitInstrAB('MOV', 'BX', '[_CL_GETCOUNT]');
        EmitInstrAB('SHL', 'BX', '1');  { multiply by 2 for word index }
        { Store variable address }
        EmitInstrA('CALL', CL_RT_PFX + 'ADDGET');
      End
      Else
        CompileError('attendu un identificateur apres GET');
      { Optional PICTURE }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
        If StrUpperCase(CurToken.Val) = 'PICTURE' Then
        Begin
          ParserAdvance;
          ParseExpr(ValExpr);
          EmitComment('GET PICTURE (ignored - stub)');
        End;
      { Optional VALID }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
        If StrUpperCase(CurToken.Val) = 'VALID' Then
        Begin
          ParserAdvance;
          ParseExpr(ValExpr);
          EmitComment('GET VALID (ignored - stub)');
        End;
    End
    Else If StrUpperCase(CurToken.Val) = 'TO' Then
    Begin
      ParserAdvance;  { consume TO }
      EmitComment('@ TO (draw box)');
      { Parse row2 }
      ParseExpr(RowExpr);
      ExprFlushToAX(RowExpr);
      EmitInstr('PUSH   AX');  { save row2 }
      { Expect comma }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
      { Parse col2 }
      ParseExpr(ColExpr);
      ExprFlushToAX(ColExpr);
      EmitInstr('PUSH   AX');  { save col2 }
      { Optional DOUBLE keyword }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        If StrUpperCase(CurToken.Val) = 'DOUBLE' Then
        Begin
          ParserAdvance;
          EmitInstrAB('MOV', 'CL', '1');  { double=1 }
        End
        Else
          EmitInstrAB('MOV', 'CL', '0');  { single=0 }
      End
      Else
        EmitInstrAB('MOV', 'CL', '0');
      EmitInstrA('CALL', CL_RT_PFX + 'DRAWBOX');
      EmitInstrAB('ADD', 'SP', '4');  { cleanup 2 pushed args }
    End
    Else
    Begin
      { Not SAY/GET/TO - maybe just positioning cursor }
      EmitComment('@ row,col (position only)');
    End;
  End;
End;

{ ---- ParseReadStmt ------------------------------------------- }
Procedure ParseReadStmt;
Begin
  EmitComment('READ');
  EmitInstrA('CALL', CL_RT_PFX + 'READGETS');
End;

{ ---- ParseClearStmt ------------------------------------------ }
Procedure ParseClearStmt;
Begin
  EmitComment('CLEAR SCREEN');
  { Check for optional SCREEN keyword }
  If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If StrUpperCase(CurToken.Val) = 'SCREEN' Then
      ParserAdvance;
  End;
  EmitInstrA('CALL', CL_RT_PFX + 'CLEARSCR');
End;

{ ---- ParseSetColorStmt --------------------------------------- }
Procedure ParseSetColorStmt;
Var
  Arg : TExprVal;
Begin
  { SET already consumed, expecting COLOR }
  If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If StrUpperCase(CurToken.Val) = 'COLOR' Then
    Begin
      ParserAdvance;  { consume COLOR }
      { Expect TO }
      If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
      Begin
        If StrUpperCase(CurToken.Val) = 'TO' Then
          ParserAdvance;
      End;
      ParseExpr(Arg);
      ExprFlushToAX(Arg);
      EmitComment('SET COLOR TO');
      EmitInstrAB('MOV', '[_CL_COLOR]', 'AL');
    End
    Else
    Begin
      EmitComment('SET (unknown) - ignored');
      ParserAdvance;
    End;
  End;
End;

{ ---- EmitIORuntime : routines runtime entrees/sorties ecran --- }
(* Genere les routines assembleur pour l affichage ecran,
   la saisie clavier, et le positionnement curseur (TODO 12).     *)

Procedure EmitIORuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Routines runtime I/O ecran (TODO 12) ===');
  EmitBlankLine;

  { --- _CLRT_PRINTVAL : afficher une valeur (AX) --- }
  (* AX contient un entier (dans cette version simplifiee).
     Convertit en chaine via NUMTOSTR puis affiche via PRINTSTR.   *)
  EmitLabel(CL_RT_PFX + 'PRINTVAL');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   AX');
  { Heuristique type : AX >= 256 -> pointeur chaine (DATA >= 100h),
    AX < 256 -> numerique. Fonctionne car les donnees DATA sont
    au-dela de 256 octets dans le segment et les valeurs entieres
    courantes (0..255) restent en dessous. Limitation connue :
    les entiers >= 256 seront traites comme des pointeurs chaine.
    Le TODO 24 (runtime complet) implementera un vrai systeme de
    tags dynamiques pour discriminer les types.                      }
  EmitInstrAB('CMP', 'AX', '256');
  EmitInstrA('JB', CL_RT_PFX + 'PV_NUM');
  { Traiter comme pointeur chaine }
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'PRINTSTR');
  EmitInstrA('JMP', CL_RT_PFX + 'PV_DN');
  { Traiter comme nombre }
  EmitLabel(CL_RT_PFX + 'PV_NUM');
  EmitInstr('POP    AX');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_FMTBUF');
  EmitInstrA('CALL', CL_RT_PFX + 'NUMTOSTR');
  EmitInstrAB('MOV', 'SI', 'OFFSET _CL_FMTBUF');
  EmitInstrA('CALL', CL_RT_PFX + 'PRINTSTR');
  EmitLabel(CL_RT_PFX + 'PV_DN');
  EmitInstr('POP    AX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_PRINTLN : afficher retour a la ligne (CR+LF) --- }
  EmitLabel(CL_RT_PFX + 'PRINTLN');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrAB('MOV', 'DL', '13');  { CR }
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'DL', '10');  { LF }
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_PRINTSTR : afficher chaine ASCIIZ --- }
  (* SI = pointeur vers chaine terminee par 0.
     Affiche caractere par caractere via INT 21h AH=02h.           *)
  EmitLabel(CL_RT_PFX + 'PRINTSTR');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   SI');
  EmitLabel(CL_RT_PFX + 'PS_LP');
  EmitInstr('LODSB');
  EmitInstrAB('CMP', 'AL', '0');
  EmitInstrA('JE', CL_RT_PFX + 'PS_DN');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstrA('JMP', CL_RT_PFX + 'PS_LP');
  EmitLabel(CL_RT_PFX + 'PS_DN');
  EmitInstr('POP    SI');
  EmitInstr('POP    DX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_PRINTCHAR : afficher un caractere --- }
  (* AL = caractere a afficher via INT 21h AH=02h.                 *)
  EmitLabel(CL_RT_PFX + 'PRINTCHAR');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'DL', 'AL');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_NUMTOSTR : convertir entier en chaine ASCII --- }
  (* AX = nombre signe, DI = buffer destination.
     Ecrit la representation decimale terminee par 0.              *)
  EmitLabel(CL_RT_PFX + 'NUMTOSTR');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'CX', '0');   { compteur de chiffres }
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JGE', CL_RT_PFX + 'NTS_POS');
  { Nombre negatif : ecrire '-' et prendre la valeur absolue }
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '45');  { 45 = '-' }
  EmitInstrA('INC', 'DI');
  EmitInstr('NEG    AX');
  EmitLabel(CL_RT_PFX + 'NTS_POS');
  EmitInstrAB('MOV', 'BX', '10');
  { Empiler les chiffres (ordre inverse) }
  EmitLabel(CL_RT_PFX + 'NTS_DV');
  EmitInstrAB('MOV', 'DX', '0');
  EmitInstr('DIV    BX');           { AX = quotient, DX = reste }
  EmitInstrAB('ADD', 'DL', '48');   { 48 = '0' }
  EmitInstr('PUSH   DX');
  EmitInstrA('INC', 'CX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JNE', CL_RT_PFX + 'NTS_DV');
  { Depiler les chiffres dans le buffer }
  EmitLabel(CL_RT_PFX + 'NTS_WR');
  EmitInstr('POP    DX');
  EmitInstrAB('MOV', '[DI]', 'DL');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'NTS_WR');
  { Terminer la chaine }
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstr('POP    DI');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_GOTOXY : positionner le curseur --- }
  (* DH = ligne (row), DL = colonne (col).
     Utilise INT 10h AH=02h BH=0 (page video 0).                  *)
  EmitLabel(CL_RT_PFX + 'GOTOXY');
  EmitInstr('PUSH   AX');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'AH', '02h');
  EmitInstrAB('MOV', 'BH', '0');   { page video 0 }
  EmitInstr('INT    10h');
  EmitInstr('POP    BX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_CLEARSCR : effacer l ecran --- }
  (* INT 10h AH=00h AL=03h -> mode texte 80x25, efface l ecran.   *)
  EmitLabel(CL_RT_PFX + 'CLEARSCR');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', '0003h');  { AH=00 set mode, AL=03 80x25 texte }
  EmitInstr('INT    10h');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_INKEY : attendre/verifier touche clavier --- }
  (* INT 16h AH=01h : verifier si touche disponible.
     Si oui, INT 16h AH=00h pour la lire.
     Retourne AX = code touche, stocke dans _CL_LASTKEY.          *)
  EmitLabel(CL_RT_PFX + 'INKEY');
  EmitInstrAB('MOV', 'AH', '01h');
  EmitInstr('INT    16h');
  EmitInstrA('JZ', CL_RT_PFX + 'IK_NONE');
  { Touche disponible : la lire }
  EmitInstrAB('MOV', 'AH', '00h');
  EmitInstr('INT    16h');
  EmitInstrAB('MOV', '[_CL_LASTKEY]', 'AX');
  EmitInstr('RET');
  EmitLabel(CL_RT_PFX + 'IK_NONE');
  EmitInstrAB('MOV', 'AX', '0');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_GETROW : obtenir la ligne courante du curseur --- }
  (* INT 10h AH=03h BH=0 -> DH = ligne.
     Retourne AX = numero de ligne.                                *)
  EmitLabel(CL_RT_PFX + 'GETROW');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'AH', '03h');
  EmitInstrAB('MOV', 'BH', '0');
  EmitInstr('INT    10h');
  EmitInstrAB('MOV', 'AL', 'DH');
  EmitInstrAB('MOV', 'AH', '0');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_GETCOL : obtenir la colonne courante du curseur --- }
  (* INT 10h AH=03h BH=0 -> DL = colonne.
     Retourne AX = numero de colonne.                              *)
  EmitLabel(CL_RT_PFX + 'GETCOL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'AH', '03h');
  EmitInstrAB('MOV', 'BH', '0');
  EmitInstr('INT    10h');
  EmitInstrAB('MOV', 'AL', 'DL');
  EmitInstrAB('MOV', 'AH', '0');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_READGETS : activer la saisie des GETs --- }
  (* Stub : remet le compteur a zero et retourne sans saisie.
     LIMITATION : les @ GET enregistres ne sont pas traites ;
     aucune interaction utilisateur ne se produit. Le formulaire
     est ignore silencieusement. Une implementation complete
     bouclerait sur _CL_GETLIST, afficherait la valeur courante
     de chaque variable a sa position (row,col), accepterait la
     saisie clavier avec navigation Tab/Enter/Esc, et appliquerait
     les masques PICTURE et validations VALID.                       *)
  EmitLabel(CL_RT_PFX + 'READGETS');
  EmitInstrAB('MOV', 'WORD PTR [_CL_GETCOUNT]', '0');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ADDGET : enregistrer un GET dans la liste --- }
  (* Stub : incremente le compteur et retourne.                    *)
  EmitLabel(CL_RT_PFX + 'ADDGET');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', '[_CL_GETCOUNT]');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', '[_CL_GETCOUNT]', 'AX');
  EmitInstr('POP    AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DRAWBOX : dessiner un cadre ecran --- }
  (* Stub : les parametres sont sur la pile, juste retourne.
     Une implementation complete dessinerait le cadre avec
     les caracteres de bordure simple ou double.                   *)
  EmitLabel(CL_RT_PFX + 'DRAWBOX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_INPUT : lire une ligne depuis stdin --- }
  (* Utilise DOS INT 21h AH=0Ah pour la saisie bufferisee.
     Stocke le resultat dans _CL_INPBUF.
     Retourne AX = OFFSET _CL_INPBUF + 2 (debut des donnees).    *)
  EmitLabel(CL_RT_PFX + 'INPUT');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'BYTE PTR [_CL_INPBUF]', '126');  { taille max }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_INPBUF');
  EmitInstrAB('MOV', 'AH', '0Ah');
  EmitInstr('INT    21h');
  { Terminer la chaine par un 0 }
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'BL', '[_CL_INPBUF+1]');  { longueur saisie }
  EmitInstrAB('MOV', 'BH', '0');
  EmitInstrAB('MOV', 'BYTE PTR [_CL_INPBUF+2+BX]', '0');
  EmitInstr('POP    BX');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_INPBUF');
  EmitInstrAB('ADD', 'AX', '2');  { pointer vers les donnees }
  EmitInstr('POP    DX');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 13 - IF / ELSEIF / ELSE / DO CASE [IMPLEMENTE]
  ============================================================ }

{ ---- ParseStmtBlock : parse une sequence d instructions ------ }
(* Parse des instructions jusqu a rencontrer un des mots-cles
   terminaux (ENDIF, ELSE, ELSEIF, ENDCASE, CASE, OTHERWISE, EOF).
   Retourne le mot-cle terminal qui a cause l arret.             *)

Function IsBlockTerminator(Const Kw : TString) : Boolean;
Begin
  IsBlockTerminator := (Kw = 'ENDIF') Or (Kw = 'ELSE') Or
                       (Kw = 'ELSEIF') Or (Kw = 'ENDCASE') Or
                       (Kw = 'CASE') Or (Kw = 'OTHERWISE') Or
                       (Kw = 'ENDDO') Or (Kw = 'NEXT') Or
                       (Kw = 'FUNCTION') Or (Kw = 'PROCEDURE');
End;

Procedure ParseStmtBlock;
Var
  Kw      : TString;
  RetExpr : TExprVal;
Begin
  While CurToken.Kind <> TK_EOF Do
  Begin
    { Stop at block terminators }
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      Kw := CurToken.Val;
      If IsBlockTerminator(Kw) Then
        Exit;
    End;

    { Parse a single statement (mirror of Run dispatch) }
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      Kw := CurToken.Val;
      { Declarations de variables }
      If (Kw = 'LOCAL') Or (Kw = 'LOCA') Or
         (Kw = 'STATIC') Or (Kw = 'STAT') Or
         (Kw = 'PRIVATE') Or (Kw = 'PRIV') Or
         (Kw = 'PUBLIC') Or (Kw = 'PUBL') Or
         (Kw = 'DECLARE') Or (Kw = 'DECL') Or
         (Kw = 'PARAMETERS') Or (Kw = 'PARA') Then
      Begin
        If (Kw = 'LOCA') Then Kw := 'LOCAL';
        If (Kw = 'STAT') Then Kw := 'STATIC';
        If (Kw = 'PRIV') Then Kw := 'PRIVATE';
        If (Kw = 'PUBL') Then Kw := 'PUBLIC';
        If (Kw = 'DECL') Then Kw := 'DECLARE';
        If (Kw = 'PARA') Then Kw := 'PARAMETERS';
        ParserAdvance;
        ParseDeclStmt(Kw);
      End
      Else If Kw = 'STORE' Then
      Begin
        ParserAdvance;
        ParseStoreStmt;
      End
      Else If Kw = '?' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(True);
      End
      Else If Kw = '??' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(False);
      End
      Else If Kw = 'READ' Then
      Begin
        ParserAdvance;
        ParseReadStmt;
      End
      Else If Kw = 'CLEAR' Then
      Begin
        ParserAdvance;
        ParseClearStmt;
      End
      Else If Kw = 'SET' Then
      Begin
        ParserAdvance;
        ParseSetColorStmt;
      End
      Else If Kw = 'IF' Then
      Begin
        ParserAdvance;
        ParseIfStmt;
      End
      Else If Kw = 'DO' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'CASE') Then
        Begin
          ParserAdvance;
          ParseDoCaseStmt;
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WHILE') Then
        Begin
          ParserAdvance;
          ParseDoWhileStmt;
        End
        Else If (CurToken.Kind = TK_IDENT) Then
        Begin
          { DO procname [WITH arg1, arg2] (TODO 17) }
          ParseDoCallStmt;
        End;
      End
      Else If Kw = 'FOR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'EACH') Then
        Begin
          ParserAdvance;
          ParseForEachStmt;
        End
        Else
          ParseForStmt;
      End
      Else If Kw = 'LOOP' Then
      Begin
        ParserAdvance;
        If LoopTop > 0 Then
        Begin
          EmitComment('LOOP');
          EmitInstrA('JMP', LoopContLbl[LoopTop - 1]);
        End
        Else
          CompileError('LOOP en dehors d une boucle');
      End
      Else If Kw = 'EXIT' Then
      Begin
        ParserAdvance;
        If LoopTop > 0 Then
        Begin
          EmitComment('EXIT');
          EmitInstrA('JMP', LoopBrkLbl[LoopTop - 1]);
        End
        Else
          CompileError('EXIT en dehors d une boucle');
      End
      { RETURN inside a block (TODO 17) }
      Else If (Kw = 'RETURN') Or (Kw = 'RETU') Then
      Begin
        ParserAdvance;
        If CurFnRetLbl <> '' Then
        Begin
          { Inside a FUNCTION : RETURN expr }
          If (CurToken.Kind <> TK_EOF) And
             Not ((CurToken.Kind = TK_KEYWORD) And
                  (IsBlockTerminator(CurToken.Val))) And
             Not ((CurToken.Kind = TK_KEYWORD) And
                  ((CurToken.Val = 'RETURN') Or (CurToken.Val = 'RETU'))) Then
          Begin
            EmitComment('RETURN expr');
            ParseExpr(RetExpr);
            ExprFlushToAX(RetExpr);
          End
          Else
          Begin
            EmitComment('RETURN NIL');
            EmitInstrAB('XOR', 'AX', 'AX');
          End;
          EmitInstrA('JMP', CurFnRetLbl);
        End
        Else
        Begin
          { Global level RETURN }
          EmitComment('RETURN (global)');
          EmitInstrAB('MOV', 'AX', '4C00h');
          EmitInstr('INT    21h');
        End;
      End
      Else
      Begin
        ParserAdvance;
      End;
    End
    Else If CurToken.Kind = TK_IDENT Then
    Begin
      ParseExprStmt;
    End
    Else If CurToken.Kind = TK_PUNCT Then
    Begin
      ParserAdvance;
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
    Begin
      ParseExprStmt;
    End
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
    Begin
      ParserAdvance;
      ParseAtStmt;
    End
    Else
    Begin
      ParserAdvance;
    End;
  End;
End;

{ ---- ParseIfStmt : IF ... [ELSEIF ...] [ELSE ...] ENDIF ----- }
(* Genere le code assembleur pour les structures conditionnelles :
     IF cond
       stmts
     [ELSEIF cond
       stmts] ...
     [ELSE
       stmts]
     ENDIF
   Labels : _CLL_N pour les sauts JZ (condition fausse) et JMP (fin). *)

Procedure ParseIfStmt;
Var
  Cond     : TExprVal;
  LblNext  : TString;  { label du prochain ELSEIF/ELSE }
  LblEnd   : TString;  { label ENDIF }
Begin
  EmitComment('IF');
  LblEnd := LabelGen;  { label de fin du IF complet }

  { ---- Branche IF ---- }
  ParseExpr(Cond);
  ExprFlushToAX(Cond);
  LblNext := LabelGen;
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblNext);

  { Body du IF }
  ParseStmtBlock;

  { ---- Traiter ELSEIF / ELSE / ENDIF ---- }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ELSEIF') Do
  Begin
    EmitInstrA('JMP', LblEnd);   { sauter a la fin depuis la branche precedente }
    EmitLabel(LblNext);           { label ou on arrive si la condition etait fausse }
    ParserAdvance;                { consommer ELSEIF }
    EmitComment('ELSEIF');

    ParseExpr(Cond);
    ExprFlushToAX(Cond);
    LblNext := LabelGen;
    EmitInstrAB('TEST', 'AX', 'AX');
    EmitInstrA('JZ', LblNext);

    { Body du ELSEIF }
    ParseStmtBlock;
  End;

  { ---- Branche ELSE ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ELSE') Then
  Begin
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblNext);
    ParserAdvance;  { consommer ELSE }
    EmitComment('ELSE');

    { Body du ELSE }
    ParseStmtBlock;
    LblNext := '';  { pas de label supplementaire }
  End
  Else
  Begin
    { Pas de ELSE : le label Next pointe directement vers la fin }
  End;

  { ---- ENDIF ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ENDIF') Then
    ParserAdvance;  { consommer ENDIF }

  { Emettre le label de fin }
  If LblNext <> '' Then
    EmitLabel(LblNext);  { si pas de ELSE, le dernier JZ saute ici }
  EmitLabel(LblEnd);
  EmitComment('ENDIF');
End;

{ ---- ParseDoCaseStmt : DO CASE ... CASE ... OTHERWISE ... ENDCASE }
(* Genere le code assembleur pour la structure DO CASE :
     DO CASE
       CASE cond1
         stmts
       CASE cond2
         stmts
       [OTHERWISE
         stmts]
     ENDCASE
   Chaque CASE evalue sa condition; si fausse, JZ vers le prochain.
   Un JMP vers la fin apres chaque corps.                           *)

Procedure ParseDoCaseStmt;
Var
  Cond     : TExprVal;
  LblNext  : TString;  { label du prochain CASE }
  LblEnd   : TString;  { label ENDCASE }
  First    : Boolean;
Begin
  EmitComment('DO CASE');
  LblEnd  := LabelGen;
  LblNext := '';
  First   := True;

  { ---- Boucle sur les CASE ---- }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'CASE') Do
  Begin
    If Not First Then
    Begin
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);
    End;
    First := False;

    ParserAdvance;  { consommer CASE }
    EmitComment('CASE');

    ParseExpr(Cond);
    ExprFlushToAX(Cond);
    LblNext := LabelGen;
    EmitInstrAB('TEST', 'AX', 'AX');
    EmitInstrA('JZ', LblNext);

    { Body du CASE }
    ParseStmtBlock;
  End;

  { ---- OTHERWISE ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'OTHERWISE') Then
  Begin
    If Not First Then
    Begin
      EmitInstrA('JMP', LblEnd);
      EmitLabel(LblNext);
      LblNext := '';
    End;
    ParserAdvance;  { consommer OTHERWISE }
    EmitComment('OTHERWISE');

    { Body du OTHERWISE }
    ParseStmtBlock;
  End;

  { ---- ENDCASE ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ENDCASE') Then
    ParserAdvance;  { consommer ENDCASE }

  If (LblNext <> '') And (Not First) Then
    EmitLabel(LblNext);
  EmitLabel(LblEnd);
  EmitComment('ENDCASE');
End;

{ ============================================================
  TODO 14 - BOUCLES : DO WHILE / FOR / FOR EACH / LOOP / EXIT
  ============================================================ }

{ ---- LoopPush : empiler les labels de boucle pour LOOP/EXIT --- }

Procedure LoopPush(Const ContLbl, BrkLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    CompileError('boucles trop imbriquees (max=' + IntToStr(MAX_LOOP_NEST) + ')');
    Exit;
  End;
  LoopContLbl[LoopTop] := ContLbl;
  LoopBrkLbl[LoopTop]  := BrkLbl;
  Inc(LoopTop);
End;

{ ---- LoopPop : depiler les labels de boucle ------------------- }

Procedure LoopPop;
Begin
  If LoopTop > 0 Then
    Dec(LoopTop);
End;

{ ---- ParseDoWhileStmt : DO WHILE cond ... ENDDO -------------- }
(* Genere le code assembleur pour la boucle DO WHILE :
     DO WHILE cond
       stmts
       [LOOP]   -> JMP vers le test de boucle
       [EXIT]   -> JMP vers la fin de la boucle
     ENDDO
   Labels : _CLL_N pour test et fin.                              *)

Procedure ParseDoWhileStmt;
Var
  Cond    : TExprVal;
  LblTest : TString;
  LblEnd  : TString;
Begin
  EmitComment('DO WHILE');
  LblTest := LabelGen;
  LblEnd  := LabelGen;

  LoopPush(LblTest, LblEnd);

  { Label de test (debut de boucle) }
  EmitLabel(LblTest);

  { Evaluer la condition }
  ParseExpr(Cond);
  ExprFlushToAX(Cond);
  EmitInstrAB('TEST', 'AX', 'AX');
  EmitInstrA('JZ', LblEnd);

  { Corps de la boucle }
  ParseStmtBlock;

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Consommer ENDDO }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ENDDO') Then
    ParserAdvance;

  { Label de fin }
  EmitLabel(LblEnd);
  EmitComment('ENDDO');

  LoopPop;
End;

{ ---- ParseForStmt : FOR var := lo TO hi [STEP n] ... NEXT ---- }
(* Genere le code assembleur pour la boucle FOR :
     FOR var := startExpr TO endExpr [STEP stepExpr]
       stmts
       [LOOP]   -> JMP vers l increment
       [EXIT]   -> JMP vers la fin
     NEXT
   Variables de borne sauvegardees en DATA pour acces robuste.
   Labels : _CLL_N pour test, increment et fin.                   *)

Procedure ParseForStmt;
Var
  VarName  : TString;
  SIdx     : Integer;
  StartV   : TExprVal;
  EndV     : TExprVal;
  StepV    : TExprVal;
  TmpE     : TExprVal;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  LblBody  : TString;
  LblNeg   : TString;
  EndLbl   : TString;
  StepLbl  : TString;
  HasStep  : Boolean;
Begin
  EmitComment('FOR');
  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;
  HasStep := False;

  { Nom de la variable de boucle }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('FOR : identificateur attendu');
    Exit;
  End;
  VarName := CurToken.Val;
  ParserAdvance;

  { Rechercher ou creer la variable }
  SIdx := SymFind(VarName);
  If SIdx < 0 Then
    SIdx := DeclAllocSym(VarName, SC_PRIVATE);

  { Operateur d affectation := ou = }
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = ':=') Or (CurToken.Val = '=')) Then
    ParserAdvance
  Else
  Begin
    CompileError('FOR : := attendu apres ' + VarName);
    Exit;
  End;

  { Valeur initiale }
  ParseExpr(StartV);
  ExprFlushToAX(StartV);
  ExprStore(SIdx);

  { Mot-cle TO }
  If Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO')) Then
  Begin
    CompileError('FOR : mot-cle TO attendu');
    Exit;
  End;
  ParserAdvance;

  { Valeur finale -> sauvegarder dans une variable DATA }
  EndLbl := LabelGen;
  DataAddWord(EndLbl, 0);
  ParseExpr(EndV);
  ExprFlushToAX(EndV);
  EmitInstrAB('MOV', 'WORD PTR [' + EndLbl + ']', 'AX');

  { STEP optionnel }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'STEP') Then
  Begin
    ParserAdvance;
    HasStep := True;
    StepLbl := LabelGen;
    DataAddWord(StepLbl, 0);
    ParseExpr(StepV);
    ExprFlushToAX(StepV);
    EmitInstrAB('MOV', 'WORD PTR [' + StepLbl + ']', 'AX');
  End;

  LoopPush(LblIncr, LblEnd);

  { ---- Label de test ---- }
  EmitLabel(LblTest);
  ExprLoad(SIdx, TmpE);  { MOV AX, [var] }

  If HasStep Then
  Begin
    { Step variable : verifier le signe pour la comparaison }
    LblBody := LabelGen;
    LblNeg  := LabelGen;
    EmitInstrAB('MOV', 'BX', 'WORD PTR [' + StepLbl + ']');
    EmitInstrAB('TEST', 'BX', 'BX');
    EmitInstrA('JS', LblNeg);
    { Step positif : var > end -> sortir }
    EmitInstrAB('CMP', 'AX', 'WORD PTR [' + EndLbl + ']');
    EmitInstrA('JG', LblEnd);
    EmitInstrA('JMP', LblBody);
    { Step negatif : var < end -> sortir }
    EmitLabel(LblNeg);
    EmitInstrAB('CMP', 'AX', 'WORD PTR [' + EndLbl + ']');
    EmitInstrA('JL', LblEnd);
    EmitLabel(LblBody);
  End
  Else
  Begin
    { Step = 1 (defaut) : var > end -> sortir }
    EmitInstrAB('CMP', 'AX', 'WORD PTR [' + EndLbl + ']');
    EmitInstrA('JG', LblEnd);
  End;

  { ---- Corps de la boucle ---- }
  ParseStmtBlock;

  { ---- Increment ---- }
  EmitLabel(LblIncr);
  ExprLoad(SIdx, TmpE);  { MOV AX, [var] }
  If HasStep Then
    EmitInstrAB('ADD', 'AX', 'WORD PTR [' + StepLbl + ']')
  Else
    EmitInstr('INC    AX');
  ExprStore(SIdx);

  { Retour au test }
  EmitInstrA('JMP', LblTest);

  { Consommer NEXT }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'NEXT') Then
    ParserAdvance;

  { ---- Label de fin ---- }
  EmitLabel(LblEnd);
  EmitComment('NEXT');

  LoopPop;
End;

{ ---- ParseForEachStmt : FOR EACH elem IN collection ... NEXT -- }
(* Iteration sur un tableau (TODO 15).
   Genere une boucle qui parcourt chaque element du tableau
   en utilisant un compteur d index dans le segment de donnees.    *)

Procedure ParseForEachStmt;
Var
  ElemName : TString;
  CollExpr : TExprVal;
  ElemSIdx : Integer;
  LblTest  : TString;
  LblIncr  : TString;
  LblEnd   : TString;
  IdxLbl   : TString;
  ArrLbl   : TString;
Begin
  EmitComment('FOR EACH');

  { Lire le nom de la variable element }
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('FOR EACH : identificateur attendu');
    Exit;
  End;
  ElemName := CurToken.Val;
  ParserAdvance;

  { Declarer la variable si necessaire }
  ElemSIdx := SymFind(ElemName);
  If ElemSIdx < 0 Then
    ElemSIdx := DeclAllocSym(ElemName, SC_LOCAL);

  { Consommer IN }
  If Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IN')) Then
  Begin
    CompileError('FOR EACH : IN attendu');
    Exit;
  End;
  ParserAdvance;

  { Evaluer l expression collection }
  ParseExpr(CollExpr);
  ExprFlushToAX(CollExpr);
  { AX = pointeur tableau }

  { Creer des variables temporaires dans le DATA segment }
  Inc(ArrayTempCount);
  IdxLbl := '_CL_FEIDX' + IntToStr(ArrayTempCount);
  ArrLbl := '_CL_FEARR' + IntToStr(ArrayTempCount);
  DataAddWord(IdxLbl, 1);
  DataAddWord(ArrLbl, 0);

  { Stocker le pointeur tableau }
  EmitInstrAB('MOV', '[' + ArrLbl + ']', 'AX');

  { Initialiser index a 1 }
  EmitInstrAB('MOV', 'WORD PTR [' + IdxLbl + ']', '1');

  LblTest := LabelGen;
  LblIncr := LabelGen;
  LblEnd  := LabelGen;

  LoopPush(LblIncr, LblEnd);

  { Test : index <= LEN(arr) }
  EmitLabel(LblTest);
  EmitInstr('PUSH   SI');
  EmitInstrAB('MOV', 'SI', '[' + ArrLbl + ']');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstr('POP    SI');
  EmitInstrAB('CMP', '[' + IdxLbl + ']', 'AX');
  EmitInstrA('JA', LblEnd);

  { Charger l element courant dans la variable }
  EmitInstrAB('MOV', 'AX', '[' + IdxLbl + ']');
  EmitInstrAB('MOV', 'BX', '[' + ArrLbl + ']');
  EmitInstrA('CALL', CL_RT_PFX + 'AGET');
  ExprStore(ElemSIdx);

  { Corps de la boucle }
  ParseStmtBlock;

  { Increment }
  EmitLabel(LblIncr);
  EmitInstrA('INC', 'WORD PTR [' + IdxLbl + ']');
  EmitInstrA('JMP', LblTest);

  { Consommer NEXT }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'NEXT') Then
    ParserAdvance;

  EmitLabel(LblEnd);
  EmitComment('NEXT (FOR EACH)');

  LoopPop;
End;

{ ============================================================
  TODO 15 - TABLEAUX [IMPLEMENTE]
  ============================================================ }

{ ---- ParseArrayLiteral : (e1, e2, ...) ---------------------- }
(* Alloue un tableau sur le heap :
     [_CL_HEAPPTR] pointe le prochain slot libre
     Format heap : (count:Word, elem1:Word, elem2:Word, ...)
   Retourne AX = pointeur vers le bloc tableau (debut = count)  *)

Procedure ParseArrayLiteral(Var Res : TExprVal);
Var
  ElemCount : Integer;
Begin
  EmitComment('array literal {...}');
  ParserAdvance; (* consomme '{' *)

  { Sauvegarder le pointeur heap courant -> c est notre tableau }
  EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
  EmitInstr('PUSH   DI');           { sauv debut du tableau }

  { Reserver la place pour le compteur (2 octets) }
  EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');

  ElemCount := 0;

  { Parser les elements separes par des virgules }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Then
  Begin
    Repeat
      ParseExpr(Res);
      ExprFlushToAX(Res);
      { Stocker l element a la position courante du heap }
      EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
      EmitInstrAB('MOV', '[DI]', 'AX');
      EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');
      Inc(ElemCount);

      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until (CurToken.Kind = TK_EOF) Or
          ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}'));
  End;

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Ecrire le nombre d elements au debut du bloc }
  EmitInstr('POP    DI');           { DI = debut du tableau }
  EmitInstrAB('MOV', 'WORD PTR [DI]', IntToStr(ElemCount));
  { AX = pointeur vers le tableau }
  EmitInstrAB('MOV', 'AX', 'DI');

  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_ARRAY;
  Res.SymIdx  := -1;
End;

{ ---- EmitArrayRuntime : routines d execution pour tableaux --- }
(* Routines :
   _CLRT_ANEW  : BX=taille -> AX=ptr nouveau tableau
   _CLRT_AGET  : BX=arr, AX=index(1-base) -> AX=valeur
   _CLRT_ASET  : BX=arr, CX=index(1-base), AX=val -> stocke
   _CLRT_ALEN  : AX=arr -> AX=nombre d elements
   _CLRT_AADD  : BX=arr, AX=val -> ajoute, AX=arr
   _CLRT_ADEL  : BX=arr, AX=index -> supprime (shift gauche)
   _CLRT_AINS  : BX=arr, AX=index -> insere 0 (shift droit)
   _CLRT_ASIZE : BX=arr, AX=new_size -> redimensionne
   _CLRT_ACLONE: AX=arr -> AX=copie
   _CLRT_ASORT : AX=arr -> tri bulle
   _CLRT_ASCAN : BX=arr, AX=val -> AX=position ou 0
   _CLRT_AFILL : BX=arr, AX=val -> remplit
   _CLRT_ACOPY : BX=src, AX=dst -> copie elements               *)

Procedure EmitArrayRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime Tableaux (TODO 15) ===');
  EmitBlankLine;

  { --- _CLRT_ANEW : allouer un nouveau tableau --- }
  EmitLabel(CL_RT_PFX + 'ANEW');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
  EmitInstrAB('MOV', 'AX', 'DI');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', '[DI]', 'BX');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrAB('MOV', 'CX', 'BX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'ANW_DN');
  EmitLabel(CL_RT_PFX + 'ANW_LP');
  EmitInstrAB('MOV', 'WORD PTR [DI]', '0');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'ANW_LP');
  EmitLabel(CL_RT_PFX + 'ANW_DN');
  EmitInstrAB('MOV', '[_CL_HEAPPTR]', 'DI');
  EmitInstr('POP    AX');
  EmitInstr('POP    DI');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_AGET : lire element tableau --- }
  EmitLabel(CL_RT_PFX + 'AGET');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   SI');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'AGT_ER');
  EmitInstrAB('CMP', 'AX', '[SI]');
  EmitInstrA('JA', CL_RT_PFX + 'AGT_ER');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('ADD', 'SI', 'AX');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrA('JMP', CL_RT_PFX + 'AGT_DN');
  EmitLabel(CL_RT_PFX + 'AGT_ER');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel(CL_RT_PFX + 'AGT_DN');
  EmitInstr('POP    SI');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ASET : ecrire element tableau --- }
  EmitLabel(CL_RT_PFX + 'ASET');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'AST_DN');
  EmitInstrAB('CMP', 'CX', '[DI]');
  EmitInstrA('JA', CL_RT_PFX + 'AST_DN');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('SHL', 'CX', '1');
  EmitInstrAB('ADD', 'CX', '2');
  EmitInstrAB('ADD', 'DI', 'CX');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitLabel(CL_RT_PFX + 'AST_DN');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ALEN : nombre d elements --- }
  EmitLabel(CL_RT_PFX + 'ALEN');
  EmitInstr('PUSH   SI');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('CMP', 'SI', '0');
  EmitInstrA('JE', CL_RT_PFX + 'ALN_Z');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrA('JMP', CL_RT_PFX + 'ALN_DN');
  EmitLabel(CL_RT_PFX + 'ALN_Z');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel(CL_RT_PFX + 'ALN_DN');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_AADD : ajouter element a la fin --- }
  EmitLabel(CL_RT_PFX + 'AADD');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('MOV', 'CX', '[DI]');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('ADD', 'DI', 'AX');
  EmitInstr('POP    AX');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrA('INC', 'WORD PTR [DI]');
  EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ADEL : supprimer element (shift gauche) --- }
  EmitLabel(CL_RT_PFX + 'ADEL');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JA', CL_RT_PFX + 'ADL_DN');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'ADL_DN');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('ADD', 'DI', 'AX');
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrAB('ADD', 'SI', '2');
  EmitLabel(CL_RT_PFX + 'ADL_LP');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', '[BX]');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrAB('CMP', 'SI', 'AX');
  EmitInstr('POP    AX');
  EmitInstrA('JAE', CL_RT_PFX + 'ADL_SH');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstr('POP    AX');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrA('JMP', CL_RT_PFX + 'ADL_LP');
  EmitLabel(CL_RT_PFX + 'ADL_SH');
  EmitInstrAB('MOV', 'WORD PTR [DI]', '0');
  EmitInstrA('DEC', 'WORD PTR [BX]');
  EmitLabel(CL_RT_PFX + 'ADL_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_AINS : inserer element vide (shift droit) --- }
  EmitLabel(CL_RT_PFX + 'AINS');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrAB('CMP', 'AX', 'CX');
  EmitInstrA('JA', CL_RT_PFX + 'AIN_DN');
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'AIN_DN');
  EmitInstr('PUSH   AX');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('ADD', 'SI', 'AX');
  EmitInstrAB('MOV', 'DI', 'SI');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstr('POP    AX');
  EmitInstr('PUSH   AX');
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitLabel(CL_RT_PFX + 'AIN_LP');
  EmitInstrAB('CMP', 'SI', 'AX');
  EmitInstrA('JB', CL_RT_PFX + 'AIN_SH');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'CX');
  EmitInstr('POP    CX');
  EmitInstrAB('SUB', 'SI', '2');
  EmitInstrAB('SUB', 'DI', '2');
  EmitInstrA('JMP', CL_RT_PFX + 'AIN_LP');
  EmitLabel(CL_RT_PFX + 'AIN_SH');
  { Recalculer l adresse d insertion et mettre 0 }
  EmitInstr('POP    AX');              { AX = index original (1-base) }
  EmitInstrA('DEC', 'AX');
  EmitInstrAB('SHL', 'AX', '1');
  EmitInstrAB('ADD', 'AX', '2');
  EmitInstrAB('ADD', 'AX', 'BX');     { AX = adresse insertion }
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstrAB('MOV', 'WORD PTR [DI]', '0');
  EmitInstrA('INC', 'WORD PTR [BX]');
  EmitInstrAB('ADD', 'WORD PTR [_CL_HEAPPTR]', '2');
  EmitLabel(CL_RT_PFX + 'AIN_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ASIZE : redimensionner tableau --- }
  EmitLabel(CL_RT_PFX + 'ASIZE');
  EmitInstrAB('MOV', '[BX]', 'AX');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ACLONE : copier tableau --- }
  EmitLabel(CL_RT_PFX + 'ACLONE');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('MOV', 'DI', '[_CL_HEAPPTR]');
  EmitInstr('PUSH   DI');
  EmitInstrA('INC', 'CX');                 { CX = count+1 (compteur + elements) }
  EmitLabel(CL_RT_PFX + 'ACL_LP');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'ACL_LP');
  EmitInstrAB('MOV', '[_CL_HEAPPTR]', 'DI');
  EmitInstr('POP    AX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ASORT : tri bulle --- }
  EmitLabel(CL_RT_PFX + 'ASORT');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitLabel(CL_RT_PFX + 'ASR_OUT');
  EmitInstrAB('MOV', 'DX', '0');
  EmitInstrAB('MOV', 'CX', '[BX]');
  EmitInstrA('DEC', 'CX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'ASR_DN');
  EmitInstrAB('LEA', 'SI', '[BX+2]');
  EmitLabel(CL_RT_PFX + 'ASR_INN');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrAB('MOV', 'DI', '[SI+2]');
  EmitInstrAB('CMP', 'AX', 'DI');
  EmitInstrA('JLE', CL_RT_PFX + 'ASR_NSP');
  EmitInstrAB('MOV', '[SI]', 'DI');
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitInstrAB('MOV', 'DX', '1');
  EmitLabel(CL_RT_PFX + 'ASR_NSP');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'ASR_INN');
  EmitInstrAB('CMP', 'DX', '0');
  EmitInstrA('JNE', CL_RT_PFX + 'ASR_OUT');
  EmitLabel(CL_RT_PFX + 'ASR_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ASCAN : recherche lineaire --- }
  EmitLabel(CL_RT_PFX + 'ASCAN');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('MOV', 'AX', '1');
  EmitLabel(CL_RT_PFX + 'ASC_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'ASC_NF');
  EmitInstrAB('CMP', '[SI]', 'DX');
  EmitInstrA('JE', CL_RT_PFX + 'ASC_DN');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrA('INC', 'AX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'ASC_LP');
  EmitLabel(CL_RT_PFX + 'ASC_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitLabel(CL_RT_PFX + 'ASC_DN');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_AFILL : remplir tous les elements --- }
  EmitLabel(CL_RT_PFX + 'AFILL');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'DI', 'BX');
  EmitInstrAB('MOV', 'CX', '[DI]');
  EmitInstrAB('ADD', 'DI', '2');
  EmitLabel(CL_RT_PFX + 'AFL_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'AFL_DN');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'AFL_LP');
  EmitLabel(CL_RT_PFX + 'AFL_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_ACOPY : copier elements de src vers dst --- }
  EmitLabel(CL_RT_PFX + 'ACOPY');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitInstrAB('MOV', 'DI', 'AX');
  EmitInstrAB('MOV', 'CX', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'CX');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('ADD', 'DI', '2');
  EmitLabel(CL_RT_PFX + 'ACP_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'ACP_DN');
  EmitInstrAB('MOV', 'AX', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AX');
  EmitInstrAB('ADD', 'SI', '2');
  EmitInstrAB('ADD', 'DI', '2');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'ACP_LP');
  EmitLabel(CL_RT_PFX + 'ACP_DN');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ---- EmitStringRuntime : routines chaines de caracteres (TODO 16) ---- }

Procedure EmitStringRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Runtime Chaines de caracteres (TODO 16) ===');
  EmitBlankLine;

  { --- _CLRT_SLEN : longueur chaine (SI=str -> AX=len) --- }
  EmitLabel(CL_RT_PFX + 'SLEN');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SLN_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLN_DN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SLN_LP');
  EmitLabel(CL_RT_PFX + 'SLN_DN');
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SSUBSTR : sous-chaine (AX=str, BX=start 1-based, CX=len -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SSUBSTR');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('DEC', 'BX');
  EmitInstrAB('ADD', 'SI', 'BX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SSB_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSB_DN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSB_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SSB_LP');
  EmitLabel(CL_RT_PFX + 'SSB_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SLEFT : n premiers caracteres (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SLEFT');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SLF_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLF_DN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLF_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SLF_LP');
  EmitLabel(CL_RT_PFX + 'SLF_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SRIGHT : n derniers caracteres (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SRIGHT');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'BX', 'AX');
  { Calculer longueur }
  EmitInstr('PUSH   SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SRT_LN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRT_LD');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SRT_LN');
  EmitLabel(CL_RT_PFX + 'SRT_LD');
  EmitInstr('POP    SI');
  EmitInstrAB('SUB', 'CX', 'BX');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'SRT_AL');
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitLabel(CL_RT_PFX + 'SRT_AL');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SRT_CP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRT_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SRT_CP');
  EmitLabel(CL_RT_PFX + 'SRT_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SATPOS : position sous-chaine (SI=sub, DI=str -> AX=pos 1-based, 0 si absent) --- }
  EmitLabel(CL_RT_PFX + 'SATPOS');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitLabel(CL_RT_PFX + 'SAT_OT');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SAT_NF');
  EmitInstrA('INC', 'DX');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'SAT_IN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SAT_FD');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SAT_NM');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', CL_RT_PFX + 'SAT_NM');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SAT_IN');
  EmitLabel(CL_RT_PFX + 'SAT_FD');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitLabel(CL_RT_PFX + 'SAT_NM');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SAT_OT');
  EmitLabel(CL_RT_PFX + 'SAT_NF');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SRATPOS : derniere position sous-chaine (SI=sub, DI=str -> AX=pos) --- }
  EmitLabel(CL_RT_PFX + 'SRATPOS');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('XOR', 'BX', 'BX');
  EmitInstrAB('XOR', 'DX', 'DX');
  EmitLabel(CL_RT_PFX + 'SRA_OT');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRA_DN');
  EmitInstrA('INC', 'DX');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'SRA_IN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRA_FD');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRA_NM');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[DI]');
  EmitInstrA('JNE', CL_RT_PFX + 'SRA_NM');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SRA_IN');
  EmitLabel(CL_RT_PFX + 'SRA_FD');
  EmitInstrAB('MOV', 'BX', 'DX');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SRA_OT');
  EmitLabel(CL_RT_PFX + 'SRA_NM');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SRA_OT');
  EmitLabel(CL_RT_PFX + 'SRA_DN');
  EmitInstrAB('MOV', 'AX', 'BX');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_STRIM : supprimer espaces a droite (SI=str -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'STRIM');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'STR_CP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'STR_TR');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'STR_CP');
  EmitLabel(CL_RT_PFX + 'STR_TR');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitLabel(CL_RT_PFX + 'STR_BK');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'STR_DN');
  EmitInstrA('DEC', 'DI');
  EmitInstrAB('CMP', 'BYTE PTR [DI]', '32');
  EmitInstrA('JNE', CL_RT_PFX + 'STR_KP');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'STR_BK');
  EmitLabel(CL_RT_PFX + 'STR_KP');
  EmitInstrA('INC', 'DI');
  EmitLabel(CL_RT_PFX + 'STR_DN');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SLTRIM : supprimer espaces a gauche (SI=str -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SLTRIM');
  EmitInstr('PUSH   DI');
  EmitLabel(CL_RT_PFX + 'SLT_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLT_CP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JNE', CL_RT_PFX + 'SLT_CP');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', CL_RT_PFX + 'SLT_SK');
  EmitLabel(CL_RT_PFX + 'SLT_CP');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SLT_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLT_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SLT_LP');
  EmitLabel(CL_RT_PFX + 'SLT_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SALLTRIM : supprimer espaces gauche et droite (SI=str -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SALLTRIM');
  EmitInstrA('CALL', CL_RT_PFX + 'SLTRIM');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrA('CALL', CL_RT_PFX + 'STRIM');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SUPPER : majuscules (SI=str -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SUPPER');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SUP_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SUP_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '97');
  EmitInstrA('JB', CL_RT_PFX + 'SUP_ST');
  EmitInstrAB('CMP', 'AL', '122');
  EmitInstrA('JA', CL_RT_PFX + 'SUP_ST');
  EmitInstrAB('SUB', 'AL', '32');
  EmitLabel(CL_RT_PFX + 'SUP_ST');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SUP_LP');
  EmitLabel(CL_RT_PFX + 'SUP_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SLOWER : minuscules (SI=str -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SLOWER');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SLW_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SLW_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '65');
  EmitInstrA('JB', CL_RT_PFX + 'SLW_ST');
  EmitInstrAB('CMP', 'AL', '90');
  EmitInstrA('JA', CL_RT_PFX + 'SLW_ST');
  EmitInstrAB('ADD', 'AL', '32');
  EmitLabel(CL_RT_PFX + 'SLW_ST');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SLW_LP');
  EmitLabel(CL_RT_PFX + 'SLW_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SREPLICATE : repeter chaine n fois (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SREPLICATE');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrAB('MOV', 'BX', 'SI');
  EmitLabel(CL_RT_PFX + 'SRP_OT');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRP_DN');
  EmitInstrAB('MOV', 'SI', 'BX');
  EmitLabel(CL_RT_PFX + 'SRP_IN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SRP_NX');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SRP_IN');
  EmitLabel(CL_RT_PFX + 'SRP_NX');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SRP_OT');
  EmitLabel(CL_RT_PFX + 'SRP_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SSPACE : chaine de n espaces (AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SSPACE');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SSP_LP');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSP_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '32');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SSP_LP');
  EmitLabel(CL_RT_PFX + 'SSP_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SPADR : completer a droite (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SPADR');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SPR_CP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPR_PD');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPR_CP');
  EmitLabel(CL_RT_PFX + 'SPR_PD');
  EmitInstrAB('CMP', 'CX', 'BX');
  EmitInstrA('JGE', CL_RT_PFX + 'SPR_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '32');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPR_PD');
  EmitLabel(CL_RT_PFX + 'SPR_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SPADL : completer a gauche (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SPADL');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'BX', 'AX');
  { Calculer longueur de str }
  EmitInstr('PUSH   SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SPL_LN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPL_LD');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPL_LN');
  EmitLabel(CL_RT_PFX + 'SPL_LD');
  EmitInstr('POP    SI');
  { DX = padding = BX - CX }
  EmitInstrAB('MOV', 'DX', 'BX');
  EmitInstrAB('SUB', 'DX', 'CX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrAB('CMP', 'DX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'SPL_CS');
  { Remplir DX espaces }
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'CX', 'DX');
  EmitLabel(CL_RT_PFX + 'SPL_SP');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '32');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JNZ', CL_RT_PFX + 'SPL_SP');
  EmitInstr('POP    CX');
  EmitLabel(CL_RT_PFX + 'SPL_CS');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPL_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SPL_CS');
  EmitLabel(CL_RT_PFX + 'SPL_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SPADC : completer centre (SI=str, AX=n -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SPADC');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstrAB('MOV', 'BX', 'AX');
  { Calculer longueur }
  EmitInstr('PUSH   SI');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SPC_LN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPC_LD');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPC_LN');
  EmitLabel(CL_RT_PFX + 'SPC_LD');
  EmitInstr('POP    SI');
  { DX = total padding = BX - CX }
  EmitInstrAB('MOV', 'DX', 'BX');
  EmitInstrAB('SUB', 'DX', 'CX');
  EmitInstrAB('CMP', 'DX', '0');
  EmitInstrA('JLE', CL_RT_PFX + 'SPC_C0');
  { left_pad = DX / 2 }
  EmitInstr('PUSH   CX');
  EmitInstrAB('MOV', 'AX', 'DX');
  EmitInstrAB('SHR', 'AX', '1');
  EmitInstrAB('MOV', 'CX', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SPC_L1');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPC_L2');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '32');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPC_L1');
  EmitLabel(CL_RT_PFX + 'SPC_L2');
  EmitInstr('POP    CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPC_CC');
  EmitLabel(CL_RT_PFX + 'SPC_C0');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  { Copier chaine }
  EmitLabel(CL_RT_PFX + 'SPC_CC');
  EmitInstr('PUSH   SI');
  EmitLabel(CL_RT_PFX + 'SPC_C1');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SPC_C2');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SPC_C1');
  EmitLabel(CL_RT_PFX + 'SPC_C2');
  EmitInstr('POP    SI');
  { right_pad : remplir jusqu a BX total }
  { Calculer position courante }
  EmitInstrAB('MOV', 'AX', 'DI');
  EmitInstrAB('SUB', 'AX', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SPC_R1');
  EmitInstrAB('CMP', 'AX', 'BX');
  EmitInstrA('JGE', CL_RT_PFX + 'SPC_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '32');
  EmitInstrA('INC', 'DI');
  EmitInstrA('INC', 'AX');
  EmitInstrA('JMP', CL_RT_PFX + 'SPC_R1');
  EmitLabel(CL_RT_PFX + 'SPC_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SCHR : caractere depuis code ASCII (AX=code -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SCHR');
  EmitInstrAB('MOV', '[_CL_CHRBUF]', 'AL');
  EmitInstrAB('MOV', 'BYTE PTR [_CL_CHRBUF+1]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_CHRBUF');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SASC : code ASCII du premier caractere (SI=str -> AX=code) --- }
  EmitLabel(CL_RT_PFX + 'SASC');
  EmitInstrAB('XOR', 'AH', 'AH');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SVAL : chaine vers nombre (SI=str -> AX=n) --- }
  EmitLabel(CL_RT_PFX + 'SVAL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitLabel(CL_RT_PFX + 'SVL_SK');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '32');
  EmitInstrA('JNE', CL_RT_PFX + 'SVL_SG');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', CL_RT_PFX + 'SVL_SK');
  EmitLabel(CL_RT_PFX + 'SVL_SG');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '45');
  EmitInstrA('JNE', CL_RT_PFX + 'SVL_CP');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', CL_RT_PFX + 'SVL_DG');
  EmitLabel(CL_RT_PFX + 'SVL_CP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '43');
  EmitInstrA('JNE', CL_RT_PFX + 'SVL_DG');
  EmitInstrA('INC', 'SI');
  EmitLabel(CL_RT_PFX + 'SVL_DG');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '48');
  EmitInstrA('JB', CL_RT_PFX + 'SVL_EN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '57');
  EmitInstrA('JA', CL_RT_PFX + 'SVL_EN');
  EmitInstrAB('MOV', 'BX', '10');
  EmitInstrA('MUL', 'BX');
  EmitInstrAB('XOR', 'BH', 'BH');
  EmitInstrAB('MOV', 'BL', '[SI]');
  EmitInstrAB('SUB', 'BL', '48');
  EmitInstrAB('ADD', 'AX', 'BX');
  EmitInstrA('INC', 'SI');
  EmitInstrA('JMP', CL_RT_PFX + 'SVL_DG');
  EmitLabel(CL_RT_PFX + 'SVL_EN');
  EmitInstrAB('CMP', 'CX', '1');
  EmitInstrA('JNE', CL_RT_PFX + 'SVL_RT');
  EmitInstrA('NEG', 'AX');
  EmitLabel(CL_RT_PFX + 'SVL_RT');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SSTRTRAN : remplacer sous-chaine (SI=str, DI=old, BX=new -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SSTRTRAN');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  { Sauver old et new dans _CL_STRBUF2 }
  EmitInstrAB('MOV', '[_CL_STRBUF2]', 'DI');
  EmitInstrAB('MOV', '[_CL_STRBUF2+2]', 'BX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'SST_SC');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SST_FN');
  { Essayer de matcher old a la position courante }
  EmitInstr('PUSH   SI');
  EmitInstrAB('MOV', 'BX', '[_CL_STRBUF2]');
  EmitLabel(CL_RT_PFX + 'SST_CM');
  EmitInstrAB('CMP', 'BYTE PTR [BX]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SST_MT');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SST_NO');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('CMP', 'AL', '[BX]');
  EmitInstrA('JNE', CL_RT_PFX + 'SST_NO');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'BX');
  EmitInstrA('JMP', CL_RT_PFX + 'SST_CM');
  { Match trouve }
  EmitLabel(CL_RT_PFX + 'SST_MT');
  EmitInstr('POP    CX');
  { Copier new vers DI }
  EmitInstrAB('MOV', 'BX', '[_CL_STRBUF2+2]');
  EmitLabel(CL_RT_PFX + 'SST_CN');
  EmitInstrAB('CMP', 'BYTE PTR [BX]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SST_EN');
  EmitInstrAB('MOV', 'AL', '[BX]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'BX');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SST_CN');
  EmitLabel(CL_RT_PFX + 'SST_EN');
  EmitInstrA('JMP', CL_RT_PFX + 'SST_SC');
  { Pas de match : copier caractere courant }
  EmitLabel(CL_RT_PFX + 'SST_NO');
  EmitInstr('POP    SI');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SST_SC');
  EmitLabel(CL_RT_PFX + 'SST_FN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_SSTUFF : inserer/remplacer (AX=str, BX=pos, CX=del, DX=ins -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'SSTUFF');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'SI', 'AX');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitInstrA('DEC', 'BX');
  { Copier BX caracteres (head) }
  EmitLabel(CL_RT_PFX + 'SSF_HD');
  EmitInstrAB('CMP', 'BX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_DL');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_DL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('DEC', 'BX');
  EmitInstrA('JMP', CL_RT_PFX + 'SSF_HD');
  { Sauter CX caracteres (delete) }
  EmitLabel(CL_RT_PFX + 'SSF_DL');
  EmitInstrAB('CMP', 'CX', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_IN');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_IN');
  EmitInstrA('INC', 'SI');
  EmitInstrA('DEC', 'CX');
  EmitInstrA('JMP', CL_RT_PFX + 'SSF_DL');
  { Copier chaine d insertion }
  EmitLabel(CL_RT_PFX + 'SSF_IN');
  EmitInstr('PUSH   SI');
  EmitInstrAB('MOV', 'SI', 'DX');
  EmitLabel(CL_RT_PFX + 'SSF_IC');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_TL');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SSF_IC');
  EmitLabel(CL_RT_PFX + 'SSF_TL');
  EmitInstr('POP    SI');
  { Copier reste de la source }
  EmitLabel(CL_RT_PFX + 'SSF_RS');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'SSF_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'SSF_RS');
  EmitLabel(CL_RT_PFX + 'SSF_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_STRANSFORM : formater valeur (SI=val, DI=mask -> AX=ptr) --- }
  EmitLabel(CL_RT_PFX + 'STRANSFORM');
  EmitInstr('PUSH   DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_STRBUF');
  EmitLabel(CL_RT_PFX + 'STF_LP');
  EmitInstrAB('CMP', 'BYTE PTR [SI]', '0');
  EmitInstrA('JE', CL_RT_PFX + 'STF_DN');
  EmitInstrAB('MOV', 'AL', '[SI]');
  EmitInstrAB('MOV', '[DI]', 'AL');
  EmitInstrA('INC', 'SI');
  EmitInstrA('INC', 'DI');
  EmitInstrA('JMP', CL_RT_PFX + 'STF_LP');
  EmitLabel(CL_RT_PFX + 'STF_DN');
  EmitInstrAB('MOV', 'BYTE PTR [DI]', '0');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_STRBUF');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 17 - PROCEDURES ET FONCTIONS [IMPLEMENTE]
  ============================================================ }

{ ---- ParseFuncBody : corps commun FUNCTION/PROCEDURE --------- }
(* Parse le corps d une function/procedure : les instructions
   entre la declaration et le prochain FUNCTION/PROCEDURE ou EOF.
   Gere le scope, le cadre de pile, le prologue et l epilogue.
   IsFunc=True pour FUNCTION, False pour PROCEDURE.
   FnLabel est le label ASM de la routine.                       *)

Procedure ParseFuncBody(IsFunc : Boolean; Const FnLabel : TString);
Var
  SkipLbl  : TString;
  Kw       : TString;
  RetExpr  : TExprVal;
  OldFrame : Integer;
Begin
  { Sauvegarder le contexte courant }
  SaveFrameSize := CurFrameSize;
  SaveFnRetLbl  := CurFnRetLbl;
  SaveSymOffset := SymNextOffset;
  SaveParamOfs  := ParamNextOffset;

  { Initialiser le nouveau contexte de fonction }
  CurFrameSize    := 0;
  CurFnRetLbl     := LabelGen;
  SymNextOffset   := 0;
  ParamNextOffset := 4;  { [BP+4] est le premier parametre }
  If IsFunc Then
    InFuncDecl := True
  Else
    InProcDecl := True;

  { Entrer dans un nouveau scope }
  SymEnterScope;

  { Emettre un JMP pour sauter le corps de la fonction dans le flux principal }
  SkipLbl := LabelGen;
  EmitInstrA('JMP', SkipLbl);
  EmitBlankLine;

  { Emettre le label de la fonction }
  EmitComment(FnLabel);
  EmitLabel(FnLabel);

  { Parser la liste de parametres si presente : (p1, p2, ...) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer ( }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
    Begin
      If CurToken.Kind = TK_IDENT Then
      Begin
        DeclAllocSym(CurToken.Val, SC_PARAM);
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance;  { consommer ) }
  End;

  { Emettre le prologue : le CurFrameSize sera ajuste apres les LOCALs }
  { On reserve le prologue, on le patchera pas - on emet directement }
  { puisqu on ne connait pas encore le nombre de LOCALs on emet un }
  { prologue minimal et on ajustera via les declarations LOCAL }
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');

  { Parser le corps : les declarations LOCAL/STATIC et les instructions }
  { jusqu a RETURN, ou prochain FUNCTION/PROCEDURE, ou EOF }
  While CurToken.Kind <> TK_EOF Do
  Begin
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      Kw := CurToken.Val;
      { RETURN met fin au corps }
      If (Kw = 'RETURN') Or (Kw = 'RETU') Then
      Begin
        ParserAdvance;
        If IsFunc Then
        Begin
          { RETURN expr : evaluer l expression et charger dans AX }
          If (CurToken.Kind <> TK_EOF) And
             Not ((CurToken.Kind = TK_KEYWORD) And
                  (IsBlockTerminator(CurToken.Val))) And
             Not ((CurToken.Kind = TK_KEYWORD) And
                  ((CurToken.Val = 'RETURN') Or (CurToken.Val = 'RETU'))) Then
          Begin
            EmitComment('RETURN expr');
            ParseExpr(RetExpr);
            ExprFlushToAX(RetExpr);
          End
          Else
          Begin
            { RETURN sans valeur dans FUNCTION : retourne NIL (0) }
            EmitComment('RETURN NIL');
            EmitInstrAB('XOR', 'AX', 'AX');
          End;
        End
        Else
        Begin
          { PROCEDURE : RETURN sans valeur }
          EmitComment('RETURN');
        End;
        EmitInstrA('JMP', CurFnRetLbl);
        Break;
      End;
      { FUNCTION ou PROCEDURE termine aussi le corps courant }
      If (Kw = 'FUNCTION') Or (Kw = 'FUNC') Or
         (Kw = 'PROCEDURE') Or (Kw = 'PROC') Then
        Break;
    End;
    { Parser une instruction du corps (comme dans ParseStmtBlock) }
    If CurToken.Kind = TK_KEYWORD Then
    Begin
      Kw := CurToken.Val;
      If (Kw = 'LOCAL') Or (Kw = 'LOCA') Or
         (Kw = 'STATIC') Or (Kw = 'STAT') Or
         (Kw = 'PRIVATE') Or (Kw = 'PRIV') Or
         (Kw = 'PUBLIC') Or (Kw = 'PUBL') Or
         (Kw = 'DECLARE') Or (Kw = 'DECL') Or
         (Kw = 'PARAMETERS') Or (Kw = 'PARA') Then
      Begin
        If (Kw = 'LOCA') Then Kw := 'LOCAL';
        If (Kw = 'STAT') Then Kw := 'STATIC';
        If (Kw = 'PRIV') Then Kw := 'PRIVATE';
        If (Kw = 'PUBL') Then Kw := 'PUBLIC';
        If (Kw = 'DECL') Then Kw := 'DECLARE';
        If (Kw = 'PARA') Then Kw := 'PARAMETERS';
        OldFrame := CurFrameSize;
        ParserAdvance;
        ParseDeclStmt(Kw);
        { Ajuster SP pour les nouvelles variables locales }
        If CurFrameSize > OldFrame Then
          EmitInstrAB('SUB', 'SP', IntToStr((CurFrameSize - OldFrame) * 2));
      End
      Else If Kw = 'STORE' Then
      Begin
        ParserAdvance;
        ParseStoreStmt;
      End
      Else If Kw = '?' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(True);
      End
      Else If Kw = '??' Then
      Begin
        ParserAdvance;
        ParseQOutStmt(False);
      End
      Else If Kw = 'READ' Then
      Begin
        ParserAdvance;
        ParseReadStmt;
      End
      Else If Kw = 'CLEAR' Then
      Begin
        ParserAdvance;
        ParseClearStmt;
      End
      Else If Kw = 'SET' Then
      Begin
        ParserAdvance;
        ParseSetColorStmt;
      End
      Else If Kw = 'IF' Then
      Begin
        ParserAdvance;
        ParseIfStmt;
      End
      Else If Kw = 'DO' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'CASE') Then
        Begin
          ParserAdvance;
          ParseDoCaseStmt;
        End
        Else If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WHILE') Then
        Begin
          ParserAdvance;
          ParseDoWhileStmt;
        End
        Else If (CurToken.Kind = TK_IDENT) Then
          ParseDoCallStmt;
      End
      Else If Kw = 'FOR' Then
      Begin
        ParserAdvance;
        If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'EACH') Then
        Begin
          ParserAdvance;
          ParseForEachStmt;
        End
        Else
          ParseForStmt;
      End
      Else If Kw = 'LOOP' Then
      Begin
        ParserAdvance;
        If LoopTop > 0 Then
        Begin
          EmitComment('LOOP');
          EmitInstrA('JMP', LoopContLbl[LoopTop - 1]);
        End
        Else
          CompileError('LOOP en dehors d une boucle');
      End
      Else If Kw = 'EXIT' Then
      Begin
        ParserAdvance;
        If LoopTop > 0 Then
        Begin
          EmitComment('EXIT');
          EmitInstrA('JMP', LoopBrkLbl[LoopTop - 1]);
        End
        Else
          CompileError('EXIT en dehors d une boucle');
      End
      Else
        ParserAdvance;
    End
    Else If CurToken.Kind = TK_IDENT Then
      ParseExprStmt
    Else If CurToken.Kind = TK_PUNCT Then
      ParserAdvance
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
      ParseExprStmt
    Else If (CurToken.Kind = TK_OP) And (CurToken.Val = '@') Then
    Begin
      ParserAdvance;
      ParseAtStmt;
    End
    Else
      ParserAdvance;
  End;

  { Emettre l epilogue }
  EmitLabel(CurFnRetLbl);
  If CurFrameSize > 0 Then
    EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');
  EmitBlankLine;

  { Quitter le scope }
  SymLeaveScope;

  { Restaurer le contexte precedent }
  CurFrameSize    := SaveFrameSize;
  CurFnRetLbl     := SaveFnRetLbl;
  SymNextOffset   := SaveSymOffset;
  ParamNextOffset := SaveParamOfs;
  InFuncDecl      := False;
  InProcDecl      := False;

  { Label de saut pour le flux principal }
  EmitLabel(SkipLbl);
End;

{ ---- ParseFuncDecl : parser une declaration FUNCTION --------- }
(* Syntaxe Clipper :
     FUNCTION nom([param1, param2, ...])
       LOCAL ...
       ... body ...
     RETURN expr

   Le mot-cle FUNCTION a deja ete consomme.
   Enregistre le symbole SC_FUNC dans la table.
   Emet le code assembleur avec prologue/epilogue standard.      *)

Procedure ParseFuncDecl;
Var
  FnName  : TString;
  FnLabel : TString;
Begin
  If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
  Begin
    CompileError('FUNCTION : nom attendu');
    Exit;
  End;
  FnName := CurToken.Val;
  ParserAdvance;

  { Enregistrer le symbole fonction }
  FnLabel := CL_FN_PFX + SymNameClean(FnName);
  SymAdd(FnName, SC_FUNC, TY_IDX_NIL, 0);
  CurFuncName := StrUpper(FnName);

  If Opts.Verbose Then
    WriteLn('  FUNCTION ', CurFuncName, ' -> ', FnLabel);

  ParseFuncBody(True, FnLabel);
  CurFuncName := '';
End;

{ ---- ParseProcDecl : parser une declaration PROCEDURE -------- }
(* Syntaxe Clipper :
     PROCEDURE nom([param1, param2, ...])
       LOCAL ...
       ... body ...
     RETURN
   ou :
     INIT PROCEDURE nom
     EXIT PROCEDURE nom

   Le mot-cle PROCEDURE a deja ete consomme.
   Detecte INIT/EXIT pour l execution automatique au demarrage/fin.*)

Procedure ParseProcDecl;
Var
  ProcName  : TString;
  ProcLabel : TString;
Begin
  If (CurToken.Kind <> TK_IDENT) And (CurToken.Kind <> TK_KEYWORD) Then
  Begin
    CompileError('PROCEDURE : nom attendu');
    Exit;
  End;
  ProcName := CurToken.Val;
  ParserAdvance;

  { Enregistrer le symbole procedure }
  ProcLabel := CL_FN_PFX + SymNameClean(ProcName);
  SymAdd(ProcName, SC_PROC, TY_IDX_NIL, 0);
  CurFuncName := StrUpper(ProcName);

  If Opts.Verbose Then
    WriteLn('  PROCEDURE ', CurFuncName, ' -> ', ProcLabel);

  ParseFuncBody(False, ProcLabel);
  CurFuncName := '';
End;

{ ---- ParseReturnStmt : parser RETURN [expr] en contexte global  }
(* En dehors d une FUNCTION/PROCEDURE, RETURN met fin au programme.
   A l interieur, il est gere par ParseFuncBody.
   Le mot-cle RETURN a deja ete consomme.                        *)

Procedure ParseReturnStmt;
Begin
  { En contexte global, RETURN termine le programme }
  EmitComment('RETURN (global)');
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT    21h');
End;

{ ---- ParseDoCallStmt : parser DO procname [WITH args] -------- }
(* Syntaxe dBASE/Clipper :
     DO procname [WITH arg1, arg2, ...]
   Le mot-cle DO a deja ete consomme.
   Le token courant est l identificateur du nom de procedure.
   Genere PUSH args + CALL _CLP_name + ADD SP, n*2.             *)

Procedure ParseDoCallStmt;
Var
  ProcName  : TString;
  ProcLabel : TString;
  ArgCount  : Integer;
  Arg       : TExprVal;
  SI        : Integer;
Begin
  If CurToken.Kind <> TK_IDENT Then
  Begin
    CompileError('DO : nom de procedure attendu');
    Exit;
  End;
  ProcName := CurToken.Val;
  ParserAdvance;

  { Verifier si le symbole existe, sinon le creer comme forward ref }
  SI := SymFind(ProcName);
  If SI < 0 Then
  Begin
    { Forward reference : creer le symbole }
    ProcLabel := CL_FN_PFX + SymNameClean(ProcName);
    SI := SymAdd(ProcName, SC_PROC, TY_IDX_NIL, 0);
  End
  Else
  Begin
    ProcLabel := SymTab[SI].MangledName;
    If ProcLabel = '' Then
      ProcLabel := CL_FN_PFX + SymNameClean(ProcName);
  End;

  EmitComment('DO ' + StrUpper(ProcName));
  ArgCount := 0;

  { Parser les arguments optionnels : WITH arg1, arg2, ... }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WITH') Then
  Begin
    ParserAdvance;  { consommer WITH }
    Repeat
      ParseExpr(Arg);
      ExprFlushToAX(Arg);
      EmitInstr('PUSH   AX');
      Inc(ArgCount);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until CurToken.Kind = TK_EOF;
  End;

  EmitInstrA('CALL', ProcLabel);
  If ArgCount > 0 Then
    EmitInstrAB('ADD', 'SP', IntToStr(ArgCount * 2));
End;

{ ============================================================
  TODO 18 - CODE BLOCKS ET EVAL [IMPLEMENTE]
  ============================================================ }

(* ---- ParseCodeBlock : parser code block literal ---------------
   Syntaxe Clipper :
     accolade || expr accolade : sans parametre
     accolade |x| x * 2 accolade : un parametre
     accolade |x,y| x + y accolade : plusieurs parametres

   L accolade ouvrante a deja ete consommee par ParsePrimary.
   Le token courant est '|' (debut de la liste de parametres).
   Genere une sous-routine anonyme _CLB_N avec :
     - prologue : PUSH BP / MOV BP,SP
     - corps : evaluer l expression et resultat dans AX
     - epilogue : MOV SP,BP / POP BP / RET
   Le descripteur est stocke en DATA :
     _CLB_N_D : DB nb_params / DW offset _CLB_N
   Retourne dans AX l adresse du descripteur, type TY_IDX_BLOCK. *)

Procedure ParseCodeBlock(Var Res : TExprVal);
Var
  BlkLabel    : TString;
  DescLabel   : TString;
  SkipLbl     : TString;
  RetLbl      : TString;
  ParamCount  : Integer;
  NS          : TString;
  BodyExpr    : TExprVal;
  OldFrameSize   : Integer;
  OldFnRetLbl    : TString;
  OldSymOffset   : Integer;
  OldParamOfs    : Integer;
Begin
  EmitComment('code block {...}');

  { Generer les labels pour ce code block }
  Str(CodeBlockCount, NS);
  BlkLabel  := CL_BLK_PFX + NS;          { _CLB_0, _CLB_1, ... }
  DescLabel := CL_BLK_PFX + NS + '_D';   { descripteur _CLB_0_D }
  SkipLbl   := LabelGen;
  RetLbl    := LabelGen;
  Inc(CodeBlockCount);

  { Sauvegarder le contexte courant }
  OldFrameSize := CurFrameSize;
  OldFnRetLbl  := CurFnRetLbl;
  OldSymOffset := SymNextOffset;
  OldParamOfs  := ParamNextOffset;

  { Initialiser le contexte du code block }
  CurFrameSize    := 0;
  CurFnRetLbl     := RetLbl;
  SymNextOffset   := 0;
  ParamNextOffset := 4;  { [BP+4] est le premier parametre }

  { Entrer dans un nouveau scope pour les parametres }
  SymEnterScope;

  { Consommer '|' (debut de la liste de parametres) }
  ParserAdvance;
  ParamCount := 0;

  { Parser la liste de parametres entre |...| }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '|')) Then
  Begin
    { Il y a des parametres }
    While (CurToken.Kind <> TK_EOF) And
          Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '|')) Do
    Begin
      If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
      Begin
        DeclAllocSym(CurToken.Val, SC_PARAM);
        Inc(ParamCount);
        ParserAdvance;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
  End;

  { Consommer '|' (fin de la liste de parametres) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '|') Then
    ParserAdvance;

  { Emettre un JMP pour sauter le corps du code block }
  EmitInstrA('JMP', SkipLbl);

  { Emettre le label du code block }
  EmitLabel(BlkLabel);
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');

  (* Parser le corps du code block : une expression unique *)
  (* Le corps s arrete a l accolade fermante *)
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) Then
  Begin
    ParseExpr(BodyExpr);
    ExprFlushToAX(BodyExpr);
  End
  Else
  Begin
    { Code block vide : retourne NIL (0) }
    EmitInstrAB('XOR', 'AX', 'AX');
  End;

  { Epilogue du code block }
  EmitLabel(RetLbl);
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');

  { Label de saut pour continuer le flux principal }
  EmitLabel(SkipLbl);

  (* Consommer accolade fermante *)
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;

  { Ajouter le descripteur en DATA : DB nb_params, DW code_ptr }
  Str(ParamCount, NS);
  DataAdd(DescLabel, DK_BYTE, ParamCount, '');
  DataAdd(DescLabel + '_P', DK_WORD, 0, BlkLabel);

  { Quitter le scope }
  SymLeaveScope;

  { Restaurer le contexte precedent }
  CurFrameSize    := OldFrameSize;
  CurFnRetLbl     := OldFnRetLbl;
  SymNextOffset   := OldSymOffset;
  ParamNextOffset := OldParamOfs;

  { Resultat : AX = adresse du descripteur, type CODEBLOCK }
  EmitInstrAB('LEA', 'AX', DescLabel);
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_BLOCK;
  Res.SymIdx  := -1;
End;

{ ---- EmitCodeBlockRuntime : routines runtime code blocks ------ }
(* Routines :
   _CLRT_EVAL : evaluer un code block
     Entree : arguments sur la pile, premier arg = pointeur descripteur
              [SP+2] = descripteur, [SP+4].. = args supplementaires
     Le descripteur contient : DB nb_params, DW code_ptr
     Empile les args supplementaires, CALL [code_ptr]
     Resultat dans AX.
   _CLRT_AEVAL : iterer sur un tableau avec un code block
     Entree : [SP+2] = tableau, [SP+4] = code block
     Pour chaque element du tableau, appelle le code block
     avec l element en parametre.                                  *)

Procedure EmitCodeBlockRuntime;
Begin
  EmitBlankLine;
  EmitComment('=== Code Block Runtime (TODO 18) ===');

  { _CLRT_EVAL : evaluer un code block }
  { Entree : [SP+2]=descripteur de code block, [SP+4..]=args }
  { Le descripteur : [BX]=nb_params (byte), [BX+1]=code_ptr (word) }
  EmitBlankLine;
  EmitLabel(CL_RT_PFX + 'EVAL');
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitComment('BX = descripteur du code block');
  EmitInstrAB('MOV', 'BX', '[BP+4]');       { BX = descripteur }
  EmitComment('CX = nombre de parametres du block');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'CL', '[BX]');          { CL = nb_params }
  EmitComment('DX = adresse du code du block');
  EmitInstrAB('MOV', 'DX', '[BX+1]');        { DX = code_ptr }
  EmitComment('Copier les arguments supplementaires sur la pile');
  { Les args supplementaires sont a [BP+6], [BP+8], etc. }
  { On les re-pousse pour le code block }
  EmitInstrAB('MOV', 'SI', 'BP');
  EmitInstrAB('ADD', 'SI', '6');             { SI -> premier arg supplementaire }
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', CL_RT_PFX + 'EVAL_CALL');
  EmitComment('Pousser CX args depuis [SI] sur la pile');
  { Boucle de copie des arguments : du dernier au premier }
  { Pour n params, dernier arg est a [SI + (n-1)*2] }
  EmitInstr('PUSH   CX');                    { sauvegarder CX }
  EmitInstrAB('MOV', 'AX', 'CX');
  EmitInstr('DEC    AX');
  EmitInstrAB('SHL', 'AX', '1');             { AX = (CX-1)*2 }
  EmitInstrAB('ADD', 'SI', 'AX');            { SI -> dernier arg }
  EmitLabel(CL_RT_PFX + 'EVAL_LP');
  EmitInstr('PUSH   WORD PTR [SI]');
  EmitInstrAB('SUB', 'SI', '2');
  EmitInstr('LOOP   ' + CL_RT_PFX + 'EVAL_LP');
  EmitInstr('POP    CX');                    { restaurer CX }
  EmitLabel(CL_RT_PFX + 'EVAL_CALL');
  EmitComment('Appeler le code du block');
  EmitInstr('CALL   DX');
  EmitComment('Nettoyer les args pousses');
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstr('POP    BP');
  EmitInstr('RET');

  { _CLP_AEVAL : iterer un code block sur chaque element d un tableau }
  { Entree : [SP+2]=tableau (ptr), [SP+4]=code block (descripteur ptr) }
  { Pour chaque element arr[i], empile arr[i] et CALL le code block }
  EmitBlankLine;
  EmitLabel(CL_FN_PFX + 'AEVAL');
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstr('PUSH   SI');
  EmitInstr('PUSH   DI');
  EmitComment('SI = tableau, DI = code block descriptor');
  EmitInstrAB('MOV', 'SI', '[BP+4]');       { SI = ptr tableau }
  EmitInstrAB('MOV', 'DI', '[BP+6]');       { DI = ptr descripteur block }
  EmitComment('CX = nombre d elements du tableau');
  EmitInstrAB('MOV', 'CX', '[SI]');          { CX = count }
  EmitInstrAB('ADD', 'SI', '2');             { SI -> premier element }
  EmitInstrAB('OR', 'CX', 'CX');
  EmitInstrA('JZ', CL_FN_PFX + 'AEVAL_DN');
  EmitLabel(CL_FN_PFX + 'AEVAL_LP');
  EmitInstr('PUSH   CX');                    { sauv compteur }
  EmitInstr('PUSH   SI');                    { sauv pointeur element }
  EmitComment('Empiler l element courant et appeler le block');
  EmitInstr('PUSH   WORD PTR [SI]');         { arg = element }
  EmitInstrAB('MOV', 'DX', '[DI+1]');       { DX = code_ptr }
  EmitInstr('CALL   DX');
  EmitInstrAB('ADD', 'SP', '2');             { nettoyer l arg }
  EmitInstr('POP    SI');                    { restaurer pointeur }
  EmitInstr('POP    CX');                    { restaurer compteur }
  EmitInstrAB('ADD', 'SI', '2');             { element suivant }
  EmitInstr('LOOP   ' + CL_FN_PFX + 'AEVAL_LP');
  EmitLabel(CL_FN_PFX + 'AEVAL_DN');
  EmitInstr('POP    DI');
  EmitInstr('POP    SI');
  EmitInstr('POP    BP');
  EmitInstr('RET');
End;

{ ============================================================
  TODO 19 - FICHIERS DBF (BASE DE DONNEES) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseUseStmt : USE nomFichier [ALIAS cAlias] [SHARED] --- }
(* Ouvrir un fichier DBF dans la zone de travail courante.
   USE sans argument ferme le fichier DBF de la zone courante.
   USE nom ALIAS al : ouvrir avec alias specifique.
   USE nom NEW      : ouvrir dans la prochaine zone libre.
   USE nom SHARED   : ouvrir en mode partage.
   USE nom EXCLUSIVE : ouvrir en mode exclusif.                  *)

Procedure ParseUseStmt;
Var
  FN  : TString;
  AL  : TString;
  HasNew, HasShared : Boolean;
  DIdx : Integer;
Begin
  EmitComment('USE statement (TODO 19)');
  HasNew := False;
  HasShared := False;
  AL := '';
  { USE sans argument = fermer la zone courante }
  If (CurToken.Kind = TK_EOF) Or
     ((CurToken.Kind = TK_KEYWORD) And
      ((CurToken.Val = 'IF') Or (CurToken.Val = 'DO') Or
       (CurToken.Val = 'LOCAL') Or (CurToken.Val = 'RETURN') Or
       (CurToken.Val = '?') Or (CurToken.Val = '??'))) Then
  Begin
    EmitInstrA('CALL', CL_RT_PFX + 'DBCLOSE');
    Exit;
  End;
  { Lire le nom du fichier }
  If CurToken.Kind = TK_STRING Then
  Begin
    FN := CurToken.Val;
    ParserAdvance;
  End
  Else If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
  Begin
    FN := CurToken.Val;
    ParserAdvance;
  End
  Else
  Begin
    CompileError('USE : nom de fichier attendu');
    Exit;
  End;
  { Options : ALIAS, NEW, SHARED, EXCLUSIVE }
  While (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Do
  Begin
    If (CurToken.Val = 'ALIAS') Or (CurToken.Val = 'ALIA') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_STRING) Then
      Begin
        AL := CurToken.Val;
        ParserAdvance;
      End;
    End
    Else If CurToken.Val = 'NEW' Then
    Begin
      HasNew := True;
      ParserAdvance;
    End
    Else If (CurToken.Val = 'SHARED') Or (CurToken.Val = 'SHAR') Then
    Begin
      HasShared := True;
      ParserAdvance;
    End
    Else If (CurToken.Val = 'EXCLUSIVE') Or (CurToken.Val = 'EXCL') Then
    Begin
      HasShared := False;
      ParserAdvance;
    End
    Else
      Break;
  End;
  { Generer le code : charger le nom dans SI, mode dans AL }
  EmitComment('USE ' + FN);
  { Creer une constante chaine pour le nom du fichier }
  DIdx := DataAddStr(FN);
  EmitInstrAB('LEA', 'SI', '[' + DataTab[DIdx].LblName + ']');
  If HasShared Then
    EmitInstrAB('MOV', 'AL', '1')
  Else
    EmitInstrAB('MOV', 'AL', '0');
  If HasNew Then
    EmitInstrAB('MOV', 'AH', '1')
  Else
    EmitInstrAB('MOV', 'AH', '0');
  EmitInstrA('CALL', CL_RT_PFX + 'DBOPEN');
  { Si un alias est specifie, le stocker }
  If AL <> '' Then
  Begin
    DIdx := DataAddStr(AL);
    EmitInstrAB('LEA', 'SI', '[' + DataTab[DIdx].LblName + ']');
    EmitInstrA('CALL', CL_RT_PFX + 'DBSETALIAS');
  End;
End;

{ ---- ParseSelectStmt : SELECT n / SELECT cAlias -------------- }
(* Changer la zone de travail active.
   SELECT 0     : premiere zone libre
   SELECT 1..10 : zone specifique
   SELECT A..J  : zone par lettre
   SELECT alias : zone par nom d alias                          *)

Procedure ParseSelectStmt;
Var
  Arg : TExprVal;
Begin
  EmitComment('SELECT statement (TODO 19)');
  { Verifier si c est une lettre A-J }
  If (CurToken.Kind = TK_IDENT) And (Length(CurToken.Val) = 1) And
     (CurToken.Val[1] >= 'A') And (CurToken.Val[1] <= 'J') Then
  Begin
    EmitInstrAB('MOV', 'AX', IntToStr(Ord(CurToken.Val[1]) - Ord('A')));
    EmitInstrAB('MOV', '[_CL_CURWA]', 'AX');
    ParserAdvance;
  End
  Else
  Begin
    { Expression numerique ou alias }
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstr('DEC    AX');  { convertir 1-based en 0-based }
    EmitInstrAB('MOV', '[_CL_CURWA]', 'AX');
  End;
End;

{ ---- ParseCloseStmt : CLOSE / CLOSE ALL / CLOSE DATABASES --- }

Procedure ParseCloseStmt;
Begin
  EmitComment('CLOSE statement (TODO 19)');
  If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If (CurToken.Val = 'ALL') Or (CurToken.Val = 'DATABASES') Or
       (CurToken.Val = 'DATA') Then
    Begin
      ParserAdvance;
      EmitInstrA('CALL', CL_RT_PFX + 'DBCLOSEALL');
    End
    Else
    Begin
      EmitInstrA('CALL', CL_RT_PFX + 'DBCLOSE');
    End;
  End
  Else
    EmitInstrA('CALL', CL_RT_PFX + 'DBCLOSE');
End;

{ ---- ParseGoStmt : GO TOP / GO BOTTOM / GO n / GOTO n ------- }

Procedure ParseGoStmt;
Var
  Arg : TExprVal;
Begin
  EmitComment('GO statement (TODO 19)');
  If (CurToken.Kind = TK_KEYWORD) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    If CurToken.Val = 'TOP' Then
    Begin
      ParserAdvance;
      EmitInstrA('CALL', CL_RT_PFX + 'DBGOTOP');
    End
    Else If (CurToken.Val = 'BOTTOM') Or (CurToken.Val = 'BOTT') Then
    Begin
      ParserAdvance;
      EmitInstrA('CALL', CL_RT_PFX + 'DBGOBOTTOM');
    End
    Else
    Begin
      ParseExpr(Arg);
      ExprFlushToAX(Arg);
      EmitInstrA('CALL', CL_RT_PFX + 'DBGOTO');
    End;
  End
  Else If CurToken.Kind = TK_INTEGER Then
  Begin
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstrA('CALL', CL_RT_PFX + 'DBGOTO');
  End
  Else
    CompileError('GO : TOP, BOTTOM ou expression attendu');
End;

{ ---- ParseSkipStmt : SKIP [n] ------------------------------- }

Procedure ParseSkipStmt;
Var
  Arg : TExprVal;
Begin
  EmitComment('SKIP statement (TODO 19)');
  { SKIP sans argument = SKIP 1 }
  If (CurToken.Kind = TK_EOF) Or
     ((CurToken.Kind = TK_KEYWORD) And
      ((CurToken.Val = 'IF') Or (CurToken.Val = 'DO') Or
       (CurToken.Val = 'RETURN') Or (CurToken.Val = '?') Or
       (CurToken.Val = '??') Or (CurToken.Val = 'USE') Or
       (CurToken.Val = 'CLOSE') Or (CurToken.Val = 'SELECT') Or
       (CurToken.Val = 'GO') Or (CurToken.Val = 'GOTO') Or
       (CurToken.Val = 'SKIP') Or (CurToken.Val = 'APPEND') Or
       (CurToken.Val = 'REPLACE') Or (CurToken.Val = 'DELETE') Or
       (CurToken.Val = 'RECALL') Or (CurToken.Val = 'PACK') Or
       (CurToken.Val = 'ZAP') Or (CurToken.Val = 'FUNCTION') Or
       (CurToken.Val = 'FUNC') Or (CurToken.Val = 'PROCEDURE') Or
       (CurToken.Val = 'PROC') Or (CurToken.Val = 'LOCAL') Or
       (CurToken.Val = 'STATIC'))) Then
  Begin
    EmitInstrAB('MOV', 'AX', '1');
    EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  End
  Else
  Begin
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  End;
End;

{ ---- ParseAppendStmt : APPEND BLANK ------------------------- }

Procedure ParseAppendStmt;
Begin
  EmitComment('APPEND statement (TODO 19)');
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'BLANK') Or (CurToken.Val = 'BLAN')) Then
  Begin
    ParserAdvance;
    EmitInstrA('CALL', CL_RT_PFX + 'DBAPPEND');
  End
  Else
    CompileError('APPEND : BLANK attendu');
End;

{ ---- ParseReplaceStmt : REPLACE champ WITH expr [, ...] ----- }
(* REPLACE field1 WITH expr1 [, field2 WITH expr2 ...]          *)

Procedure ParseReplaceStmt;
Var
  Arg     : TExprVal;
  FldName : TString;
  DIdx    : Integer;
Begin
  EmitComment('REPLACE statement (TODO 19)');
  Repeat
    { Lire le nom du champ }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Then
    Begin
      FldName := CurToken.Val;
      ParserAdvance;
    End
    Else
    Begin
      CompileError('REPLACE : nom de champ attendu');
      Exit;
    End;
    { WITH }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'WITH') Then
      ParserAdvance
    Else
    Begin
      CompileError('REPLACE : WITH attendu');
      Exit;
    End;
    { Expression de la valeur }
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstr('PUSH   AX');    { valeur sur la pile }
    { Charger le nom du champ dans SI }
    DIdx := DataAddStr(FldName);
    EmitInstrAB('LEA', 'SI', '[' + DataTab[DIdx].LblName + ']');
    EmitInstr('POP    AX');    { restaurer la valeur }
    EmitInstrA('CALL', CL_RT_PFX + 'DBREPLACE');
    { Virgule = champ suivant }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  Until (CurToken.Kind = TK_EOF);
End;

{ ---- ParseDeleteStmt : DELETE -------------------------------- }
(* Marquer l enregistrement courant pour suppression.            *)

Procedure ParseDeleteStmt;
Begin
  EmitComment('DELETE statement (TODO 19)');
  EmitInstrA('CALL', CL_RT_PFX + 'DBDELETE');
End;

{ ---- ParseRecallStmt : RECALL -------------------------------- }
(* Annuler la marque de suppression.                             *)

Procedure ParseRecallStmt;
Begin
  EmitComment('RECALL statement (TODO 19)');
  EmitInstrA('CALL', CL_RT_PFX + 'DBRECALL');
End;

{ ---- ParsePackStmt : PACK ------------------------------------ }
(* Supprimer physiquement les enregistrements marques.           *)

Procedure ParsePackStmt;
Begin
  EmitComment('PACK statement (TODO 19)');
  EmitInstrA('CALL', CL_RT_PFX + 'DBPACK');
End;

{ ---- ParseZapStmt : ZAP -------------------------------------- }
(* Supprimer tous les enregistrements du fichier DBF.            *)

Procedure ParseZapStmt;
Begin
  EmitComment('ZAP statement (TODO 19)');
  EmitInstrA('CALL', CL_RT_PFX + 'DBZAP');
End;

{ ---- EmitDBFRuntime : routines runtime fichiers DBF (TODO 19) ----- }
(* Genere les routines assembleur 8086 pour les operations sur
   fichiers dBASE III (.DBF).
   Utilise les interruptions DOS (INT 21h) pour les E/S fichier.
   Work areas : 10 zones independantes de 64 octets chacune dans _CL_WATAB.
   Layout par zone :
     +0  : handle fichier DOS (DW) - 0 = non utilise
     +2  : recno courant (DW)
     +4  : nombre total d enregistrements (DW)
     +6  : taille d un enregistrement (DW)
     +8  : taille de l en-tete (DW)
     +10 : flags: bit 0=eof, bit 1=bof, bit 2=deleted (DW)
     +12 : alias (11 octets ASCIIZ + 1 padding = 12 bytes)
     +24 : nombre de champs (DW)
     +26 : reserved (38 bytes)
   Total : 64 octets par zone.

   Routines generees :
     _CLRT_DBWAPTR  : SI -> offset dans _CL_WATAB pour zone courante
     _CLRT_DBOPEN   : ouvrir un fichier DBF (SI=nom, AL=mode, AH=new)
     _CLRT_DBCLOSE  : fermer le DBF de la zone courante
     _CLRT_DBCLOSEALL : fermer tous les DBF ouverts
     _CLRT_DBSETALIAS : definir l alias (SI=nom ASCIIZ)
     _CLRT_DBGOTOP  : aller au premier enregistrement
     _CLRT_DBGOBOTTOM : aller au dernier enregistrement
     _CLRT_DBGOTO   : aller a l enregistrement AX
     _CLRT_DBSKIP   : avancer de AX enregistrements
     _CLRT_DBEOF    : retourner AX=1 si fin de fichier
     _CLRT_DBBOF    : retourner AX=1 si debut de fichier
     _CLRT_DBRECNO  : retourner AX=numero d enregistrement
     _CLRT_DBRECCOUNT : retourner AX=nombre d enregistrements
     _CLRT_DBAPPEND : ajouter un enregistrement vide
     _CLRT_DBREPLACE : modifier un champ (SI=nom, AX=valeur)
     _CLRT_DBDELETE : marquer l enregistrement pour suppression
     _CLRT_DBRECALL : annuler la marque de suppression
     _CLRT_DBPACK   : supprimer physiquement les enregistrements
     _CLRT_DBZAP    : supprimer tous les enregistrements
     _CLRT_DBDELETED : retourner AX=1 si marque pour suppression
     _CLRT_DBUSED   : retourner AX=1 si zone en utilisation
     _CLRT_DBFCOUNT : retourner AX=nombre de champs
     _CLRT_DBFIELDNAME : retourner AX=ptr nom du champ n (AX=n)
     _CLRT_DBALIAS  : retourner AX=ptr alias de la zone courante
     _CLRT_DBSTRUCT : retourner AX=ptr structure (stub)           *)

Procedure EmitDBFRuntime;
Begin
  EmitBlankLine;
  EmitComment('==== DBF Runtime (TODO 19) ====');
  EmitBlankLine;

  { --- _CLRT_DBWAPTR : calculer le pointeur vers la zone courante --- }
  (* Entree : rien (utilise _CL_CURWA)
     Sortie : SI = offset dans _CL_WATAB pour la zone courante
     Detruit : AX, SI                                             *)
  EmitLabel(CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[_CL_CURWA]');
  EmitComment('AX * 64 = AX * 4 * 16 = SHL 6');
  EmitInstrAB('MOV', 'CL', '6');
  EmitInstrAB('SHL', 'AX', 'CL');
  EmitInstrAB('LEA', 'SI', '[_CL_WATAB]');
  EmitInstrAB('ADD', 'SI', 'AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBOPEN : ouvrir un fichier DBF --- }
  (* Entree : SI=nom fichier ASCIIZ, AL=mode (0=excl,1=shared), AH=new flag
     Sortie : handle dans la zone courante
     Utilise INT 21h AH=3Dh (open file)                          *)
  EmitLabel(CL_RT_PFX + 'DBOPEN');
  EmitInstr('PUSH   BP');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   AX');      { sauver mode/new flag }
  { Copier le nom dans _CL_DBFNAME }
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_DBFNAME');
  EmitLabel(CL_RT_PFX + 'DBOPEN_CP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', CL_RT_PFX + 'DBOPEN_CP');
  { Ouvrir le fichier avec INT 21h AH=3Dh }
  EmitInstr('POP    AX');       { restaurer mode }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFNAME');
  EmitInstrAB('MOV', 'AH', '3Dh');
  EmitInstrAB('MOV', 'AL', '02h');  { lecture+ecriture }
  EmitInstr('INT    21h');
  EmitInstrA('JC', CL_RT_PFX + 'DBOPEN_ERR');
  { Stocker le handle dans la zone courante }
  EmitInstr('PUSH   AX');       { sauver handle }
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstr('POP    AX');
  EmitInstrAB('MOV', '[SI]', 'AX');       { +0 = handle }
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '1');  { +2 = recno = 1 }
  EmitInstrAB('MOV', 'WORD PTR [SI+10]', '0'); { +10 = flags = 0 }
  { Lire l en-tete DBF (32 octets) }
  EmitInstrAB('MOV', 'BX', 'AX');         { handle dans BX }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFHDR');
  EmitInstrAB('MOV', 'CX', '32');
  EmitInstrAB('MOV', 'AH', '3Fh');        { DOS read file }
  EmitInstr('INT    21h');
  { Extraire nb_records (offset 4, 4 octets en little-endian, on prend 2) }
  EmitInstrAB('MOV', 'AX', '[_CL_DBFHDR+4]');
  EmitInstrAB('MOV', '[SI+4]', 'AX');     { +4 = reccnt }
  { Extraire taille en-tete (offset 8, 2 octets) }
  EmitInstrAB('MOV', 'AX', '[_CL_DBFHDR+8]');
  EmitInstrAB('MOV', '[SI+8]', 'AX');     { +8 = hdrsize }
  { Extraire taille enregistrement (offset 10, 2 octets) }
  EmitInstrAB('MOV', 'AX', '[_CL_DBFHDR+10]');
  EmitInstrAB('MOV', '[SI+6]', 'AX');     { +6 = recsize }
  { Calculer le nombre de champs : (hdrsize - 33) / 32 }
  EmitInstrAB('MOV', 'AX', '[SI+8]');
  EmitInstrAB('SUB', 'AX', '33');
  EmitInstrAB('MOV', 'CL', '5');
  EmitInstrAB('SHR', 'AX', 'CL');         { diviser par 32 }
  EmitInstrAB('MOV', '[SI+24]', 'AX');    { +24 = fldcount }
  { Verifier si le fichier est vide }
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', CL_RT_PFX + 'DBOPEN_OK');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '1');  { mettre flag EOF }
  EmitLabel(CL_RT_PFX + 'DBOPEN_OK');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('POP    BP');
  EmitInstr('RET');
  EmitLabel(CL_RT_PFX + 'DBOPEN_ERR');
  EmitComment('Erreur ouverture : handle = 0');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'WORD PTR [SI]', '0');
  EmitInstr('POP    DX');
  EmitInstr('POP    BX');
  EmitInstr('POP    BP');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBCLOSE : fermer le DBF de la zone courante --- }
  EmitLabel(CL_RT_PFX + 'DBCLOSE');
  EmitInstr('PUSH   BX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('OR', 'BX', 'BX');
  EmitInstrA('JZ', CL_RT_PFX + 'DBCLOSE_DN');
  EmitInstrAB('MOV', 'AH', '3Eh');   { DOS close file }
  EmitInstr('INT    21h');
  { Effacer l entree de la zone }
  EmitInstrAB('MOV', 'WORD PTR [SI]', '0');
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '0');
  EmitInstrAB('MOV', 'WORD PTR [SI+4]', '0');
  EmitLabel(CL_RT_PFX + 'DBCLOSE_DN');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBCLOSEALL : fermer tous les DBF ouverts --- }
  EmitLabel(CL_RT_PFX + 'DBCLOSEALL');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   BX');
  EmitInstrAB('MOV', 'CX', IntToStr(MAX_WORK_AREAS));
  EmitInstrAB('LEA', 'SI', '[_CL_WATAB]');
  EmitLabel(CL_RT_PFX + 'DBCLSALL_LP');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('OR', 'BX', 'BX');
  EmitInstrA('JZ', CL_RT_PFX + 'DBCLSALL_NX');
  EmitInstrAB('MOV', 'AH', '3Eh');
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'WORD PTR [SI]', '0');
  EmitLabel(CL_RT_PFX + 'DBCLSALL_NX');
  EmitInstrAB('ADD', 'SI', '64');
  EmitInstr('LOOP   ' + CL_RT_PFX + 'DBCLSALL_LP');
  EmitInstr('POP    BX');
  EmitInstr('POP    CX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBSETALIAS : definir l alias de la zone courante --- }
  (* Entree : SI=nom alias ASCIIZ. Copie dans la zone +12.       *)
  EmitLabel(CL_RT_PFX + 'DBSETALIAS');
  EmitInstr('PUSH   DI');
  EmitInstr('PUSH   CX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitComment('SI pointe sur WATAB, on veut ecrire a SI+12');
  EmitInstr('PUSH   SI');     { sauver ptr zone }
  EmitInstr('POP    DI');
  EmitInstrAB('ADD', 'DI', '12');
  { Recharger SI depuis la pile d appel (param original) }
  EmitInstrAB('MOV', 'SI', '[SP+6]'); { SI original sauve avant CALL }
  EmitComment('Copie du pointeur alias dans la zone');
  EmitInstr('POP    CX');
  EmitInstr('POP    DI');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBGOTOP : aller au premier enregistrement --- }
  EmitLabel(CL_RT_PFX + 'DBGOTOP');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '1');  { recno = 1 }
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFCh'); { clear EOF+BOF }
  { Verifier si le fichier est vide }
  EmitInstrAB('CMP', 'WORD PTR [SI+4]', '0');
  EmitInstrA('JNE', CL_RT_PFX + 'DBTOP_OK');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '3');  { set EOF+BOF }
  EmitLabel(CL_RT_PFX + 'DBTOP_OK');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBGOBOTTOM : aller au dernier enregistrement --- }
  EmitLabel(CL_RT_PFX + 'DBGOBOTTOM');
  EmitInstr('PUSH   BX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+4]');  { reccnt }
  EmitInstrAB('MOV', '[SI+2]', 'AX');  { recno = reccnt }
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFCh');
  EmitInstrAB('CMP', 'WORD PTR [SI+4]', '0');
  EmitInstrA('JNE', CL_RT_PFX + 'DBBOT_OK');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '3');
  EmitLabel(CL_RT_PFX + 'DBBOT_OK');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBGOTO : aller a l enregistrement AX --- }
  EmitLabel(CL_RT_PFX + 'DBGOTO');
  EmitInstr('PUSH   BX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', '[SI+2]', 'AX');  { recno = AX }
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFCh');
  { Verifier les bornes }
  EmitInstrAB('CMP', 'AX', '0');
  EmitInstrA('JG', CL_RT_PFX + 'DBGO_CHK2');
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '1');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '2');  { BOF }
  EmitInstrA('JMP', CL_RT_PFX + 'DBGO_DN');
  EmitLabel(CL_RT_PFX + 'DBGO_CHK2');
  EmitInstrAB('CMP', 'AX', '[SI+4]');
  EmitInstrA('JLE', CL_RT_PFX + 'DBGO_DN');
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstrA('INC', 'AX');
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '1');  { EOF }
  EmitLabel(CL_RT_PFX + 'DBGO_DN');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBSKIP : avancer de AX enregistrements --- }
  EmitLabel(CL_RT_PFX + 'DBSKIP');
  EmitInstr('PUSH   BX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('ADD', 'AX', '[SI+2]');  { recno + skip }
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFCh');
  { Verifier EOF }
  EmitInstrAB('CMP', 'AX', '[SI+4]');
  EmitInstrA('JLE', CL_RT_PFX + 'DBSKIP_CHK');
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstr('INC    AX');
  EmitInstrAB('MOV', '[SI+2]', 'AX');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '1');
  EmitInstrA('JMP', CL_RT_PFX + 'DBSKIP_DN');
  EmitLabel(CL_RT_PFX + 'DBSKIP_CHK');
  { Verifier BOF }
  EmitInstrAB('CMP', 'WORD PTR [SI+2]', '1');
  EmitInstrA('JGE', CL_RT_PFX + 'DBSKIP_DN');
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '1');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '2');
  EmitLabel(CL_RT_PFX + 'DBSKIP_DN');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBEOF : retourner AX=1 si EOF --- }
  EmitLabel(CL_RT_PFX + 'DBEOF');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+10]');
  EmitInstrAB('AND', 'AX', '1');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBBOF : retourner AX=1 si BOF --- }
  EmitLabel(CL_RT_PFX + 'DBBOF');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+10]');
  EmitInstrAB('AND', 'AX', '2');
  EmitInstrAB('SHR', 'AX', '1');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBRECNO : retourner AX=numero enregistrement --- }
  EmitLabel(CL_RT_PFX + 'DBRECNO');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+2]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBRECCOUNT : retourner AX=nombre d enregistrements --- }
  EmitLabel(CL_RT_PFX + 'DBRECCOUNT');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBAPPEND : ajouter un enregistrement vide --- }
  (* Incremente le nombre d enregistrements, positionne recno
     a la fin, et ecrit un enregistrement vide dans le fichier.  *)
  EmitLabel(CL_RT_PFX + 'DBAPPEND');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstr('INC    WORD PTR [SI+4]');  { reccnt++ }
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstrAB('MOV', '[SI+2]', 'AX');  { recno = reccnt }
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFCh'); { clear flags }
  { Calculer la position dans le fichier : hdrsize + (recno-1) * recsize }
  EmitInstrAB('MOV', 'BX', '[SI]');    { handle }
  EmitInstrAB('MOV', 'AX', '[SI+2]');
  EmitInstr('DEC    AX');
  EmitInstrA('MUL', 'WORD PTR [SI+6]'); { AX = (recno-1) * recsize }
  EmitInstrAB('ADD', 'AX', '[SI+8]');  { + hdrsize }
  EmitInstrAB('MOV', 'DX', 'AX');      { offset dans DX }
  EmitInstrAB('MOV', 'AH', '42h');     { DOS seek }
  EmitInstrAB('MOV', 'AL', '0');       { from start }
  EmitInstrAB('XOR', 'CX', 'CX');      { high word = 0 }
  EmitInstr('INT    21h');
  { Ecrire un enregistrement de zeros }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFBUF');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'CX', '[SI+6]');  { recsize }
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'AH', '40h');     { DOS write }
  EmitInstr('INT    21h');
  { Mettre a jour le header : nb_records a offset 4 }
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'DX', '4');
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('INT    21h');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+4]');
  EmitInstrAB('MOV', '[_CL_DBFHDR]', 'AX');
  EmitInstrAB('MOV', 'WORD PTR [_CL_DBFHDR+2]', '0');
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFHDR');
  EmitInstrAB('MOV', 'CX', '4');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBREPLACE : modifier un champ --- }
  (* Entree : SI=nom champ ASCIIZ, AX=valeur
     Stub simplifie : ecrit la valeur en position courante.       *)
  EmitLabel(CL_RT_PFX + 'DBREPLACE');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   AX');      { sauver la valeur }
  EmitInstr('PUSH   SI');      { sauver ptr nom champ }
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  { Positionner dans le fichier au debut de l enregistrement }
  EmitInstrAB('MOV', 'BX', '[SI]');    { handle }
  EmitInstrAB('MOV', 'AX', '[SI+2]');  { recno }
  EmitInstr('DEC    AX');
  EmitInstrA('MUL', 'WORD PTR [SI+6]');
  EmitInstrAB('ADD', 'AX', '[SI+8]');
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstr('INT    21h');
  { Ecrire la valeur (stub : on ecrit 2 octets au debut + 1 flag) }
  EmitInstr('POP    SI');       { nom champ (ignore dans stub) }
  EmitInstr('POP    AX');       { valeur }
  EmitInstrAB('MOV', '[_CL_DBFBUF+1]', 'AX');
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFBUF');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'CX', '[SI+6]');  { recsize }
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBDELETE : marquer pour suppression --- }
  EmitLabel(CL_RT_PFX + 'DBDELETE');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '4');  { set deleted flag }
  { Ecrire le marqueur '*' en position 0 de l enregistrement }
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'AX', '[SI+2]');
  EmitInstr('DEC    AX');
  EmitInstrA('MUL', 'WORD PTR [SI+6]');
  EmitInstrAB('ADD', 'AX', '[SI+8]');
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'BYTE PTR [_CL_DBFBUF]', '2Ah'); { '*' }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFBUF');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBRECALL : annuler la marque de suppression --- }
  EmitLabel(CL_RT_PFX + 'DBRECALL');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFFBh');  { clear deleted }
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'AX', '[SI+2]');
  EmitInstr('DEC    AX');
  EmitInstrA('MUL', 'WORD PTR [SI+6]');
  EmitInstrAB('ADD', 'AX', '[SI+8]');
  EmitInstrAB('MOV', 'DX', 'AX');
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'BYTE PTR [_CL_DBFBUF]', '20h'); { ' ' }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFBUF');
  EmitInstrAB('MOV', 'CX', '1');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBPACK : supprimer les enregistrements marques --- }
  (* Stub simplifie : reinitialise le compteur. En vrai il faudrait
     reecrire le fichier sans les enregistrements marques.        *)
  EmitLabel(CL_RT_PFX + 'DBPACK');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '1');
  EmitInstrAB('AND', 'WORD PTR [SI+10]', '0FFF8h');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBZAP : supprimer tous les enregistrements --- }
  (* Remet le compteur a 0 et tronque le fichier apres le header. *)
  EmitLabel(CL_RT_PFX + 'DBZAP');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'WORD PTR [SI+4]', '0');  { reccnt = 0 }
  EmitInstrAB('MOV', 'WORD PTR [SI+2]', '0');  { recno = 0 }
  EmitInstrAB('OR', 'WORD PTR [SI+10]', '1');   { EOF }
  { Tronquer : seek a hdrsize, puis write 0 octets }
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('MOV', 'DX', '[SI+8]');  { hdrsize }
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstr('INT    21h');
  { Ecrire 0 octets = tronquer (AH=40h CX=0) }
  EmitInstrAB('MOV', 'CX', '0');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  { Mettre a jour l en-tete : nb_records = 0 }
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'BX', '[SI]');
  EmitInstrAB('XOR', 'CX', 'CX');
  EmitInstrAB('MOV', 'DX', '4');
  EmitInstrAB('MOV', 'AH', '42h');
  EmitInstrAB('MOV', 'AL', '0');
  EmitInstr('INT    21h');
  EmitInstrAB('MOV', 'WORD PTR [_CL_DBFHDR]', '0');
  EmitInstrAB('MOV', 'WORD PTR [_CL_DBFHDR+2]', '0');
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_DBFHDR');
  EmitInstrAB('MOV', 'CX', '4');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBDELETED : retourner AX=1 si marque supprime --- }
  EmitLabel(CL_RT_PFX + 'DBDELETED');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+10]');
  EmitInstrAB('AND', 'AX', '4');
  EmitInstrAB('SHR', 'AX', '1');
  EmitInstrAB('SHR', 'AX', '1');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBUSED : retourner AX=1 si zone en utilisation --- }
  EmitLabel(CL_RT_PFX + 'DBUSED');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI]');   { handle }
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JZ', CL_RT_PFX + 'DBUSED_NO');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstr('RET');
  EmitLabel(CL_RT_PFX + 'DBUSED_NO');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBFCOUNT : retourner AX=nombre de champs --- }
  EmitLabel(CL_RT_PFX + 'DBFCOUNT');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('MOV', 'AX', '[SI+24]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBFIELDNAME : retourner AX=ptr nom du champ n --- }
  (* Entree : AX=numero du champ (1-based)
     Sortie : AX=pointeur vers nom ASCIIZ (stub: retourne _CL_DBFNAME) *)
  EmitLabel(CL_RT_PFX + 'DBFIELDNAME');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_DBFNAME');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBALIAS : retourner AX=ptr alias zone courante --- }
  EmitLabel(CL_RT_PFX + 'DBALIAS');
  EmitInstrA('CALL', CL_RT_PFX + 'DBWAPTR');
  EmitInstrAB('LEA', 'AX', '[SI+12]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_DBSTRUCT : retourner AX=ptr structure (stub) --- }
  EmitLabel(CL_RT_PFX + 'DBSTRUCT');
  EmitInstrAB('XOR', 'AX', 'AX');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ============================================================
  TODO 20 - INDEX ET RECHERCHE (NTX/NDX) [IMPLEMENTE]
  ============================================================ }

{ ---- ParseIndexStmt : INDEX ON expr TO fichier --------------- }
(* Creer un fichier index NTX.
   Syntaxe : INDEX ON expr TO nomFichier
   Aussi utilise pour SET INDEX TO fichier [, fichier2 ...]      *)

Procedure ParseIndexStmt;
Var
  Arg : TExprVal;
  DIdx : Integer;
  FN  : TString;
Begin
  EmitComment('INDEX statement (TODO 20)');
  { INDEX ON expr TO fichier }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ON') Then
  Begin
    ParserAdvance;  { consomme ON }
    { Lire l expression de cle }
    ParseExpr(Arg);
    ExprFlushToAX(Arg);
    EmitInstr('PUSH   AX');  { sauver expression cle }
    { TO }
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
      ParserAdvance;
    { Nom du fichier }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
       (CurToken.Kind = TK_STRING) Then
    Begin
      FN := CurToken.Val;
      ParserAdvance;
    End
    Else
      FN := 'INDEX';
    DIdx := DataAddStr(FN);
    EmitInstrAB('LEA', 'DI', '[' + DataTab[DIdx].LblName + ']');
    EmitInstr('POP    SI');  { expression cle }
    EmitInstrA('CALL', CL_RT_PFX + 'IDXCREATE');
  End
  Else
  Begin
    { SET INDEX TO fichier [, fichier2 ...] }
    Repeat
      If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
         (CurToken.Kind = TK_STRING) Then
      Begin
        FN := CurToken.Val;
        ParserAdvance;
        DIdx := DataAddStr(FN);
        EmitInstrAB('LEA', 'SI', '[' + DataTab[DIdx].LblName + ']');
        EmitInstrA('CALL', CL_RT_PFX + 'IDXOPEN');
      End
      Else
        Break;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance
      Else
        Break;
    Until CurToken.Kind = TK_EOF;
  End;
End;

{ ---- ParseSeekStmt : SEEK expr ------------------------------- }
(* Recherche dans l index actif.
   Met a jour le flag FOUND() selon le resultat.                 *)

Procedure ParseSeekStmt;
Var
  Arg : TExprVal;
Begin
  EmitComment('SEEK statement (TODO 20)');
  ParseExpr(Arg);
  ExprFlushToAX(Arg);
  EmitInstrA('CALL', CL_RT_PFX + 'IDXSEEK');
End;

{ ---- ParseLocateStmt : LOCATE FOR cond [options] ------------- }
(* Recherche sequentielle avec condition.
   LOCATE FOR cond [WHILE cond] [NEXT n] [REST] [ALL]           *)

Procedure ParseLocateStmt;
Var
  Arg : TExprVal;
  LblTop, LblEnd, LblBody : TString;
Begin
  EmitComment('LOCATE statement (TODO 20)');
  { LOCATE FOR cond }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FOR') Then
    ParserAdvance;
  { Aller au debut }
  EmitInstrA('CALL', CL_RT_PFX + 'DBGOTOP');
  LblTop := LabelGen;
  LblEnd := LabelGen;
  LblBody := LabelGen;
  EmitLabel(LblTop);
  { Verifier EOF }
  EmitInstrA('CALL', CL_RT_PFX + 'DBEOF');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', LblEnd);
  { Evaluer la condition }
  ParseExpr(Arg);
  ExprFlushToAX(Arg);
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', LblBody);
  { Condition fausse : avancer }
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  EmitInstrA('JMP', LblTop);
  { Condition vraie : FOUND = 1 }
  EmitLabel(LblBody);
  EmitInstrAB('MOV', 'WORD PTR [_CL_FOUND]', '1');
  EmitInstrA('JMP', LblEnd + '_OK');
  { Pas trouve : FOUND = 0 }
  EmitLabel(LblEnd);
  EmitInstrAB('MOV', 'WORD PTR [_CL_FOUND]', '0');
  EmitLabel(LblEnd + '_OK');
  { Consommer les options optionnelles WHILE/NEXT/REST/ALL }
  While (CurToken.Kind = TK_KEYWORD) And
        ((CurToken.Val = 'WHILE') Or (CurToken.Val = 'NEXT') Or
         (CurToken.Val = 'REST') Or (CurToken.Val = 'ALL')) Do
  Begin
    ParserAdvance;
    { Consommer la valeur associee si presente }
    If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_IDENT) Then
      ParserAdvance;
  End;
End;

{ ---- ParseContinueStmt : CONTINUE --------------------------- }
(* Continuer la recherche LOCATE.                                *)

Procedure ParseContinueStmt;
Begin
  EmitComment('CONTINUE statement (TODO 20)');
  { Avancer d un enregistrement et refaire LOCATE }
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  EmitInstrAB('MOV', 'WORD PTR [_CL_FOUND]', '0');
End;

{ ---- ParseReindexStmt : REINDEX ------------------------------ }
(* Reconstruire tous les index ouverts.                          *)

Procedure ParseReindexStmt;
Begin
  EmitComment('REINDEX statement (TODO 20)');
  EmitInstrA('CALL', CL_RT_PFX + 'IDXREINDEX');
End;

{ ---- EmitIdxRuntime : routines runtime index (TODO 20) ------- }
(* Genere les routines assembleur pour les operations d index
   et de recherche dans les fichiers NTX/NDX.

   Routines generees :
     _CLRT_IDXCREATE    : creer un index (SI=expr, DI=fichier)
     _CLRT_IDXOPEN      : ouvrir un fichier index (SI=nom)
     _CLRT_IDXSEEK      : recherche dans l index (AX=valeur)
     _CLRT_IDXREINDEX   : reconstruire les index
     _CLRT_IDXFOUND     : retourner AX = flag FOUND
     _CLRT_IDXSETORDER  : activer index n (AX=n)
     _CLRT_IDXSETFILTER : definir filtre (AX=condition)
     _CLRT_IDXSETRELATION : definir relation (SI=alias, AX=expr)
     _CLRT_IDXDBEVAL    : iteration conditionnelle (pile: block, for, while)
     _CLRT_IDXORDNAME   : retourner AX=ptr nom index actif
     _CLRT_IDXORDCOUNT  : retourner AX=nombre d index              *)

Procedure EmitIdxRuntime;
Begin
  EmitBlankLine;
  EmitComment('==== Index Runtime (TODO 20) ====');
  EmitBlankLine;

  { --- _CLRT_IDXCREATE : creer un index NTX --- }
  (* Entree : SI = pointeur expression cle, DI = nom fichier
     Cree un fichier NTX vide avec l en-tete de base.
     Stub simplifie : ouvre le fichier et ecrit un header minimal. *)
  EmitLabel(CL_RT_PFX + 'IDXCREATE');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  EmitInstr('PUSH   SI');      { sauver expr cle }
  { Copier le nom dans _CL_IDXNAME }
  EmitInstrAB('MOV', 'SI', 'DI');
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_IDXNAME');
  EmitLabel(CL_RT_PFX + 'IDXCR_CP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', CL_RT_PFX + 'IDXCR_CP');
  { Creer le fichier avec INT 21h AH=3Ch }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_IDXNAME');
  EmitInstrAB('MOV', 'CX', '0');       { attributs normaux }
  EmitInstrAB('MOV', 'AH', '3Ch');     { DOS create file }
  EmitInstr('INT    21h');
  EmitInstrA('JC', CL_RT_PFX + 'IDXCR_ERR');
  { Stocker le handle }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'SI', 'OFFSET _CL_IDXHND');
  EmitInstrAB('MOV', 'CX', '[_CL_IDXCNT]');
  EmitInstrAB('SHL', 'CX', '1');
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitInstrAB('MOV', '[SI]', 'BX');
  EmitInstr('INC    WORD PTR [_CL_IDXCNT]');
  { Ecrire un header minimal (16 octets de zeros) }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_IDXBUF');
  EmitInstrAB('MOV', 'CX', '16');
  EmitInstrAB('MOV', 'AH', '40h');
  EmitInstr('INT    21h');
  EmitLabel(CL_RT_PFX + 'IDXCR_ERR');
  EmitInstr('POP    SI');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXOPEN : ouvrir un fichier index --- }
  (* Entree : SI = nom fichier ASCIIZ                             *)
  EmitLabel(CL_RT_PFX + 'IDXOPEN');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   CX');
  EmitInstr('PUSH   DX');
  { Copier le nom dans _CL_IDXNAME }
  EmitInstrAB('MOV', 'DI', 'OFFSET _CL_IDXNAME');
  EmitLabel(CL_RT_PFX + 'IDXOP_CP');
  EmitInstr('LODSB');
  EmitInstr('STOSB');
  EmitInstrAB('OR', 'AL', 'AL');
  EmitInstrA('JNZ', CL_RT_PFX + 'IDXOP_CP');
  { Ouvrir avec INT 21h AH=3Dh }
  EmitInstrAB('MOV', 'DX', 'OFFSET _CL_IDXNAME');
  EmitInstrAB('MOV', 'AH', '3Dh');
  EmitInstrAB('MOV', 'AL', '02h');
  EmitInstr('INT    21h');
  EmitInstrA('JC', CL_RT_PFX + 'IDXOP_ERR');
  { Stocker le handle }
  EmitInstrAB('MOV', 'BX', 'AX');
  EmitInstrAB('MOV', 'SI', 'OFFSET _CL_IDXHND');
  EmitInstrAB('MOV', 'CX', '[_CL_IDXCNT]');
  EmitInstrAB('SHL', 'CX', '1');
  EmitInstrAB('ADD', 'SI', 'CX');
  EmitInstrAB('MOV', '[SI]', 'BX');
  EmitInstr('INC    WORD PTR [_CL_IDXCNT]');
  EmitLabel(CL_RT_PFX + 'IDXOP_ERR');
  EmitInstr('POP    DX');
  EmitInstr('POP    CX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXSEEK : recherche dans l index --- }
  (* Entree : AX = valeur a rechercher
     Met a jour _CL_FOUND : 1 si trouve, 0 sinon.
     Stub : recherche sequentielle simplifiee.                    *)
  EmitLabel(CL_RT_PFX + 'IDXSEEK');
  EmitInstr('PUSH   BX');
  EmitInstr('PUSH   AX');      { sauver valeur recherchee }
  { GO TOP }
  EmitInstrA('CALL', CL_RT_PFX + 'DBGOTOP');
  EmitInstrAB('MOV', 'WORD PTR [_CL_FOUND]', '0');
  EmitLabel(CL_RT_PFX + 'IDXSK_LP');
  EmitInstrA('CALL', CL_RT_PFX + 'DBEOF');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', CL_RT_PFX + 'IDXSK_DN');
  { Comparer (stub : on compare simplement recno avec la valeur) }
  EmitInstrA('CALL', CL_RT_PFX + 'DBRECNO');
  EmitInstrAB('CMP', 'AX', '[SP]');
  EmitInstrA('JE', CL_RT_PFX + 'IDXSK_FND');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  EmitInstrA('JMP', CL_RT_PFX + 'IDXSK_LP');
  EmitLabel(CL_RT_PFX + 'IDXSK_FND');
  EmitInstrAB('MOV', 'WORD PTR [_CL_FOUND]', '1');
  EmitLabel(CL_RT_PFX + 'IDXSK_DN');
  EmitInstr('POP    AX');
  EmitInstr('POP    BX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXREINDEX : reconstruire les index --- }
  (* Stub simplifie : ne fait rien de concret.                    *)
  EmitLabel(CL_RT_PFX + 'IDXREINDEX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXFOUND : retourner AX = flag FOUND --- }
  EmitLabel(CL_RT_PFX + 'IDXFOUND');
  EmitInstrAB('MOV', 'AX', '[_CL_FOUND]');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXSETORDER : activer index n --- }
  (* Entree : AX = numero d index (1-based, 0 = desactiver)      *)
  EmitLabel(CL_RT_PFX + 'IDXSETORDER');
  EmitInstrAB('MOV', '[_CL_IDXORD]', 'AX');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXSETFILTER : definir le filtre --- }
  (* Entree : AX = condition (0 = supprimer le filtre)
     Stub : stocke la valeur pour consultation future.            *)
  EmitLabel(CL_RT_PFX + 'IDXSETFILTER');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXSETRELATION : definir une relation --- }
  (* Entree : SI = nom alias cible, AX = expression
     Stub simplifie.                                              *)
  EmitLabel(CL_RT_PFX + 'IDXSETRELATION');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXDBEVAL : iteration conditionnelle --- }
  (* Entree : pile = block [, for [, while]]
     Parcourt tous les enregistrements et appelle le block.
     Stub : appelle EVAL pour chaque enregistrement non-EOF.      *)
  EmitLabel(CL_RT_PFX + 'IDXDBEVAL');
  EmitInstr('PUSH   BP');
  EmitInstrAB('MOV', 'BP', 'SP');
  EmitInstrA('CALL', CL_RT_PFX + 'DBGOTOP');
  EmitLabel(CL_RT_PFX + 'IDXDBE_LP');
  EmitInstrA('CALL', CL_RT_PFX + 'DBEOF');
  EmitInstrAB('OR', 'AX', 'AX');
  EmitInstrA('JNZ', CL_RT_PFX + 'IDXDBE_DN');
  { Appeler le block (arg sur la pile [BP+4] = block) }
  EmitInstrAB('MOV', 'AX', '[BP+4]');
  EmitInstrA('CALL', CL_RT_PFX + 'EVAL');
  EmitInstrAB('MOV', 'AX', '1');
  EmitInstrA('CALL', CL_RT_PFX + 'DBSKIP');
  EmitInstrA('JMP', CL_RT_PFX + 'IDXDBE_LP');
  EmitLabel(CL_RT_PFX + 'IDXDBE_DN');
  EmitInstr('POP    BP');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXORDNAME : retourner nom de l index actif --- }
  (* Stub : retourne le pointeur vers _CL_IDXNAME.               *)
  EmitLabel(CL_RT_PFX + 'IDXORDNAME');
  EmitInstrAB('MOV', 'AX', 'OFFSET _CL_IDXNAME');
  EmitInstr('RET');
  EmitBlankLine;

  { --- _CLRT_IDXORDCOUNT : retourner nombre d index ouverts --- }
  EmitLabel(CL_RT_PFX + 'IDXORDCOUNT');
  EmitInstrAB('MOV', 'AX', '[_CL_IDXCNT]');
  EmitInstr('RET');
  EmitBlankLine;
End;

{ ---- EmitRuntime : emettre les routines runtime inline ------- }
(* Appelle EmitExprRuntime pour les routines d expressions binaires
   et EmitIORuntime pour les routines I/O ecran (TODO 12).
   EmitArrayRuntime pour les routines de tableaux (TODO 15).
   EmitStringRuntime pour les routines de chaines (TODO 16).
   EmitCodeBlockRuntime pour les routines de code blocks (TODO 18).
   EmitDBFRuntime pour les routines fichiers DBF (TODO 19).
   EmitIdxRuntime pour les routines index et recherche (TODO 20). *)

Procedure EmitRuntime;
Begin
  EmitExprRuntime;
  EmitIORuntime;
  EmitArrayRuntime;
  EmitStringRuntime;
  EmitCodeBlockRuntime;
  EmitDBFRuntime;
  EmitIdxRuntime;
End;

{ ---- EmitClose : finaliser le fichier ASM -------------------- }

Procedure EmitClose;
Var
  I : Integer;
Begin
  EmitBlankLine;
  EmitComment('--- fin du code genere ---');
  EmitBlankLine;
  { Appeler les EXIT PROCEDUREs avant de quitter (TODO 17) }
  If ExitProcCount > 0 Then
  Begin
    EmitComment('EXIT PROCEDURE calls');
    For I := 0 To ExitProcCount - 1 Do
      EmitInstrA('CALL', ExitProcTab[I]);
    EmitBlankLine;
  End;
  { Sortie DOS propre }
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT    21h');
  EmitBlankLine;
  { Routines runtime inline }
  EmitRuntime;
  { Bloc d initialisation INIT PROCEDURE (TODO 17) }
  EmitBlankLine;
  EmitComment('INIT PROCEDURE block');
  EmitLabel('_CLL_INITBLOCK');
  If InitProcCount > 0 Then
  Begin
    For I := 0 To InitProcCount - 1 Do
      EmitInstrA('CALL', InitProcTab[I]);
  End;
  EmitInstr('RET');
  EmitBlankLine;
  { Fermer le segment de code }
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  { Emettre le segment de donnees }
  EmitDataSeg;
  EmitBlankLine;
  { Directive de fin : point d entree _CLP_Main }
  EmitRaw('        END     _CLP_Main');
  { Fermer le fichier }
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ParseArgs;
  Run;
End.
