{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur SAS (Statistical Analysis System) vers assembleur 8086
}

(* ============================================================
  SAS86.PAS - Compilateur SAS vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.sas [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .sas du fichier source
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS SAS) [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_KEYWORD, TK_OP, TK_PUNCT, TK_SEMICOLON,
              TK_AMPERSAND, TK_PERCENT, TK_FORMAT
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets simples 'abc'
              ou guillemets doubles "abc" (resolution des macro-variables &var)
            Commentaires : * ... ; en debut de ligne
              /* ... */ commentaires multi-lignes (non imbricables)
            Mots-cles : DATA RUN SET MERGE BY INPUT PUT INFILE FILE
              IF THEN ELSE DO END WHILE UNTIL OUTPUT RETURN DELETE
              RETAIN DROP KEEP RENAME LENGTH FORMAT INFORMAT LABEL
              ARRAY PROC QUIT TITLE FOOTNOTE OPTIONS WHERE CARDS
              DATALINES STOP ABORT GOTO LINK SELECT WHEN OTHERWISE
              ATTRIB CALL
            Insensibilite a la casse : convertir tout en majuscules
            Le point-virgule ; est le delimiteur d instruction en SAS
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
            Entiers decimaux : 0..65535 (non signe) ou -32768..32767 (signe)
            Reels : reconnus par le lexeur, traites comme entiers (trunc)
              Notation scientifique : 1.5E3 -> 1500 (trunc)
            Chaines simples : 'texte' -> pointeur vers donnees DATA
            Chaines doubles : "texte avec &macro" -> resolution macro avant stockage
            Constantes speciales manquantes :
              . (point) : valeur manquante numerique -> AX=8000h (sentinelle)
              ' ' (espace) : valeur manquante caractere -> AL=20h
            Dates litterales : '01JAN2026'd -> nombre de jours depuis 01JAN1960
              avertissement si hors intervalle 16 bits
            Heures litterales : '12:30't -> nombre de secondes depuis minuit (trunc)
            Constantes hexadecimales : '0A'x -> valeur hexadecimale -> AX
            Constantes nommees : %LET nom = valeur dans macro-langage

  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
            Arithmetiques  : + - * / ** (puissance -> CALL _SASRT_POW)
            Comparaison    : = ^= (ou NE) < <= > >= (ou EQ NE LT LE GT GE)
              IN (val1, val2, ...) : appartenance a une liste
            Logiques       : AND OR NOT (ou & | ^ en notation symbolique)
              Court-circuit : AND -> JZ, OR -> JNZ
            Concatenation  : || (concatenation de chaines)
              !! (synonyme de || dans certains environnements SAS)
            Unaire         : + - (signe) NOT (negation logique)
            MIN/MAX        : <> (minimum) >< (maximum) entre deux valeurs
            Precedence (du plus fort au plus faible) :
              1. ** (puissance)
              2. + - (unaire) NOT
              3. * /
              4. + - (binaire) || (concatenation)
              5. < <= = ^= >= > IN
              6. AND
              7. OR

  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
            TSymKind : SK_VAR, SK_ARRAY, SK_FORMAT, SK_INFORMAT,
              SK_LABEL, SK_MACRO, SK_MACROVAR, SK_DATASET, SK_PROC
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, Length, IsRetained, IsDropped, IsKept
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee (DATA step, PROC step, macro)
            SymEnterScope / SymLeaveScope : gestion des portees
            Variables automatiques : _N_ (compteur observation), _ERROR_,
              _INFILE_, _LAST_ -> creees automatiquement dans chaque DATA step
            PDV (Program Data Vector) : liste ordonnee des variables actives
            Regle de retention : variables remises a manquant a chaque iteration
              sauf si RETAIN est specifie

  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
            TTypeKind : TYK_NUMERIC (8 octets en SAS, 2 octets ici -> entier 16 bits),
              TYK_CHARACTER (chaine a longueur fixe, max 200 octets),
              TYK_DATE (entier jours depuis 01JAN1960),
              TYK_TIME (entier secondes depuis minuit),
              TYK_DATETIME (entier secondes depuis 01JAN1960 00:00:00)
            TypeTab, TypeInit : enregistrer types primitifs
            TypeSizeof : NUMERIC=2 (entier 16 bits), CHARACTER=longueur declaree
            LENGTH nom $ longueur : definir la longueur d une variable caractere
            $ dans INPUT : marque une variable comme caractere (type CHARACTER)
            Conversion implicite : num -> char via PUT(), char -> num via INPUT()
            Valeur manquante : . pour numerique, ' ' pour caractere

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _SASL_NNNNN)
            Prefixes : _SASV_ (variable), _SASP_ (procedure/etape),
              _SASK_ (chaine constante), _SASRT_ (runtime), _SASL_ (label),
              _SASD_ (dataset), _SASM_ (macro), _SASF_ (format)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY/DK_RECORD),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr, DataAddObs : variantes d ajout
            Variables globales du DATA step : entrees dans DATA segment
            Chaines litterales : DB 'abc',0 dans DATA avec label _SASK_N
            PDV (Program Data Vector) : zone memoire pour une observation
              _SAS_PDV DB MAX_OBS_SIZE DUP(0)
            Datasets en memoire : table d observations empilees
              _SASD_nom DB nb_obs * obs_size DUP(0)
            Compteurs internes : _SAS_N DW 0 (compteur _N_)
              _SAS_ERROR DW 0 (indicateur _ERROR_)

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables numeriques : 2 octets (entier 16 bits signe)
              Acces dans le PDV par offset : [_SAS_PDV + offset]
            Variables caracteres : n octets (longueur fixe, padding espaces)
              Acces dans le PDV par offset + longueur
            Affectation : variable = expression ;
              ExprLoad -> MOV [_SAS_PDV + offset], AX (numerique)
              ou CALL _SASRT_STRCPY pour caractere
            Instruction RETAIN : marquer la variable pour ne pas reinitialiser
              entre les iterations du DATA step
            Instruction DROP : exclure la variable du dataset de sortie
            Instruction KEEP : inclure uniquement les variables listees
            Instruction RENAME : old_name = new_name dans le dataset de sortie
            Instruction LENGTH : definir la longueur d une variable caractere
            Instruction LABEL : associer un libelle descriptif a une variable

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, identificateur
            Acces variable : recherche dans PDV -> MOV AX, [_SAS_PDV + offset]
            Appel de fonction : nom(args) -> CALL _SASP_nom
            Variables automatiques : _N_, _ERROR_ -> acces direct labels DATA
            Constante manquante : . -> MOV AX, 8000h (sentinelle)
            Parentheses : ( expr ) pour groupement
            Operateur IN : expr IN (val1, val2, ...) -> serie de CMP + JE
            Acces tableau : array{indice} -> calcul offset dans PDV
              (les tableaux SAS utilisent des accolades)
            Fonctions numeriques internes :
              ABS, INT, ROUND, CEIL, FLOOR, MOD, SQRT, LOG, EXP
              (SQRT, LOG, EXP : avertissement + stub entier)
            Fonctions caracteres internes :
              SUBSTR, TRIM, LEFT, RIGHT, UPCASE, LOWCASE, INDEX, LENGTH

  TODO 11 - EXPRESSIONS BINAIRES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, /
            Puissance : ** -> CALL _SASRT_POW(AX=base, BX=exposant) -> AX
            Concatenation : || -> CALL _SASRT_CONCAT(SI=gauche, DI=droite) -> AX
            Comparaison : CMP + Jcc pour =, ^=, <, <=, >, >=
              Synonymes mnemoniques : EQ NE LT LE GT GE
            Comparaison de chaines : CALL _SASRT_STRCMP -> drapeaux
            Logique AND : court-circuit JZ vers false-branch
            Logique OR : court-circuit JNZ vers true-branch
            Logique NOT : XOR AX,1
            Operateurs MIN/MAX : <> (min) et >< (max) entre deux valeurs
              -> CMP + CMOV (ou JG/JL + MOV)
            Propagation des valeurs manquantes :
              Si un operande = 8000h, le resultat = 8000h (manquant)

  TODO 12 - ENTREES/SORTIES (PUT / INPUT / INFILE / FILE)
            Instruction INPUT : lire des donnees depuis une source
              INPUT var1 var2 $var3 : lecture en liste (espaces comme separateurs)
              INPUT var1 1-5 var2 6-10 : lecture en colonnes (positions fixes)
              INPUT var1 @col var2 @col : pointeur de colonne (@)
              INPUT var1 : $8. : lecture formatee (informat $8.)
              Source par defaut : CARDS/DATALINES en ligne dans le programme
            Instruction INFILE : specifier un fichier externe comme source
              INFILE 'chemin.dat' : ouvrir avec INT 21h AH=3Dh
              Options : DLM=',' (delimiteur), FIRSTOBS=2 (sauter lignes)
            Instruction PUT : ecrire des donnees vers une destination
              PUT var1 var2 : ecriture en liste -> INT 21h AH=40h (STDOUT)
              PUT var1 1-5 var2 6-10 : ecriture en colonnes
              PUT 'texte' : ecriture de texte litteral
            Instruction FILE : specifier un fichier externe comme destination
              FILE 'sortie.dat' : ouvrir avec INT 21h AH=3Ch
              FILE PRINT : destination imprimante (STDOUT avec sauts de page)

  TODO 13 - IF / THEN / ELSE / SELECT
            ParseIfStmt : IF condition THEN action ;
              IF condition THEN action ; ELSE action ;
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _SASL_ELSE_N, _SASL_ENDIF_N
            IF/THEN avec bloc DO : IF cond THEN DO; stmts; END;
              Permet plusieurs instructions dans la branche
            ParseSelectStmt : SELECT (expr) ;
              WHEN (val1, val2) action ;
              WHEN (val3) DO; stmts; END;
              OTHERWISE action ;
              END;
              Emission : CMP + JE pour chaque valeur WHEN
              Labels : _SASL_WHEN_N, _SASL_OWHEN_N, _SASL_SELEND_N
            SELECT sans expression : SELECT ;
              WHEN (cond1) action ;
              WHEN (cond2) action ;
              Chaque WHEN est une condition booleenne independante

  TODO 14 - BOUCLES : DO / DO WHILE / DO UNTIL
            ParseDoSimple : DO; stmts; END;
              Bloc d instructions simple (pas de boucle)
            ParseDoIterative : DO var = debut TO fin [BY pas] ;
              stmts; END;
              Variable de boucle, increment automatique
              BY pas : increment different de 1 (positif ou negatif)
              Labels : _SASL_DTEST_N, _SASL_DINCR_N, _SASL_DEND_N
            ParseDoWhile : DO WHILE (condition) ; stmts; END;
              Test de condition en debut de boucle
              Labels : _SASL_DWTEST_N, _SASL_DWEND_N
            ParseDoUntil : DO UNTIL (condition) ; stmts; END;
              Test de condition en fin de boucle (execute au moins une fois)
              Labels : _SASL_DUBEG_N, _SASL_DUTEST_N
            Combinaison : DO var = 1 TO 10 WHILE (cond) ; stmts; END;
              Boucle iterative avec condition de sortie supplementaire
            Instructions LEAVE et CONTINUE :
              LEAVE : sortir de la boucle DO -> JMP _SASL_DEND_N
              CONTINUE : passer a l iteration suivante -> JMP _SASL_DINCR_N
            Instruction GOTO label : saut inconditionnel vers une etiquette

  TODO 15 - TABLEAUX SAS (ARRAY)
            Declaration : ARRAY nom {dim} [$ [longueur]] [elements] ;
              ARRAY scores {5} score1-score5 ;
              ARRAY noms {3} $ 20 nom1 nom2 nom3 ;
            Acces par indice : nom{i} -> calcul offset dans le PDV
              Indice base 1 par defaut (convention SAS)
              Acces : [_SAS_PDV + base_offset + (i-1) * elem_size]
            DIM(array) : nombre d elements -> AX (constante a la compilation)
            Tableaux multidimensionnels : ARRAY tab {lignes, colonnes} ;
              Acces : tab{i,j} -> offset = (i-1)*nb_col + (j-1) * elem_size
            Tableaux temporaires : ARRAY _tmp {5} _TEMPORARY_ ;
              Variables non ecrites dans le dataset de sortie
            Listes numerotees : score1-score5 -> 5 variables contiguees
            Boucle typique : DO i = 1 TO DIM(scores); scores{i} = 0; END;

  TODO 16 - ETAPE DATA (DATA STEP)
            ParseDataStep : DATA nom_dataset ; stmts; RUN;
              Cree ou remplace un dataset en memoire
            Boucle implicite : le DATA step itere automatiquement
              sur chaque observation de l entree (SET/MERGE/INPUT)
              Jusqu a fin de fichier ou STOP explicite
            Instruction SET : lire les observations d un dataset existant
              SET dataset1 ; -> copie chaque observation dans le PDV
              SET dataset1 dataset2 ; -> concatenation verticale
            Instruction OUTPUT : ecrire l observation courante dans le dataset
              OUTPUT; -> copie le PDV dans le dataset de sortie
              OUTPUT implicite en fin de DATA step si aucun OUTPUT explicite
            Instruction DELETE : ne pas ecrire l observation courante
            Instruction STOP : arreter l execution du DATA step
            Instruction ABORT : arreter avec code d erreur
            Reinitialisation du PDV : variables remises a manquant (.)
              a chaque iteration sauf celles marquees RETAIN
            Variables automatiques : _N_ incremente a chaque iteration
              _ERROR_ = 1 si erreur de conversion ou donnees invalides

  TODO 17 - ETAPE PROC (PROC STEP) ET INFRASTRUCTURE
            ParseProcStep : PROC nom_proc [DATA=dataset] [options] ; stmts; RUN;
              ou QUIT; pour terminer certaines procedures
            Options communes :
              DATA=dataset : specifier le dataset d entree
              OUT=dataset : specifier le dataset de sortie
              WHERE=(condition) : filtrer les observations
              NOPRINT : supprimer l affichage des resultats
            Instructions communes dans les PROC :
              VAR variables ; -> specifier les variables a analyser
              BY variables ; -> traitement par groupe
              CLASS variables ; -> variables de classification
              TITLE 'texte' ; -> titre du rapport
              FOOTNOTE 'texte' ; -> note de bas de page
            Mecanisme d appel : table de procedures connues
              Chaque PROC connue a un handler dedie
            Procedures non reconnues : avertissement + ignorer jusqu a RUN/QUIT

  TODO 18 - PROC PRINT ET PROC MEANS
            PROC PRINT : affichage tabulaire des observations
              PROC PRINT DATA=dataset ; RUN;
              VAR var1 var2 ; -> colonnes a afficher (defaut : toutes)
              WHERE (condition) ; -> filtrer les observations
              Emission : boucle sur les observations du dataset
                En-tete : noms des variables (CALL _SASRT_PRINT)
                Ligne : valeurs formatees de chaque variable
                Utilisation INT 21h AH=40h pour ecriture STDOUT
            PROC MEANS : statistiques descriptives
              PROC MEANS DATA=dataset [N MEAN STD MIN MAX SUM] ; RUN;
              VAR var1 var2 ; -> variables a analyser
              Statistiques calculees (entier 16 bits, approximation) :
                N     : compteur d observations non manquantes
                SUM   : somme -> accumulation ADD
                MEAN  : moyenne -> SUM / N (division entiere)
                MIN   : minimum -> CMP + JL
                MAX   : maximum -> CMP + JG
                STD   : ecart-type -> approximation entiere (stub)
              Emission : calcul en une passe sur le dataset + affichage

  TODO 19 - PROC FREQ ET PROC SORT
            PROC FREQ : tableaux de frequences
              PROC FREQ DATA=dataset ; TABLES var1 var2 ; RUN;
              TABLES var1 : frequences simples (comptage par valeur)
              TABLES var1 * var2 : tableau croise (stub, avertissement)
              Emission : parcourir le dataset, compter les occurrences
                Table de hachage simple : valeur -> compteur
                Affichage : valeur, frequence, pourcentage (approx entier)
            PROC SORT : tri du dataset
              PROC SORT DATA=dataset [OUT=sortie] ; BY var1 [DESCENDING var2] ; RUN;
              Algorithme : tri a bulles sur les observations en memoire
                (simple pour implementation 8086)
              BY var1 : cle de tri ascendante par defaut
              DESCENDING var2 : cle de tri descendante
              Emission : boucle de tri + echanges d observations (REP MOVSW)

  TODO 20 - PROC FORMAT ET FORMATS
            PROC FORMAT : definir des formats personnalises
              PROC FORMAT ; VALUE nom_fmt
                valeur = 'libelle'
                low - 50 = 'Bas'
                51 - 100 = 'Haut'
                OTHER = 'Inconnu' ;
              RUN;
            Application des formats : FORMAT var1 nom_fmt. ;
              Lors du PUT ou PROC PRINT, la valeur est convertie en libelle
            Formats numeriques predefinis (stubs) :
              BEST. : affichage entier par defaut
              COMMA. : separateur de milliers (stub)
              DOLLAR. : prefixe $ (stub)
              DATE9. : format date JJmmmAAAA (ex: 01JAN2026)
            Informats : lecture formatee dans INPUT
              $CHAR. : lecture caractere brute
              $. : lecture caractere avec troncature
              COMMA. : lecture avec separateur de milliers

  TODO 21 - MACRO-LANGAGE SAS
            Macro-variables : %LET nom = valeur ;
              Stockage dans une table dediee MacroVarTab
              Resolution : &nom -> substitution textuelle avant compilation
              &&nom : double resolution (& -> &nom -> valeur)
              &nom. : le point delimite la fin du nom de la macro-variable
            Macros : %MACRO nom(param1, param2) ; stmts; %MEND ;
              Stockage du corps de la macro dans MacroTab
              Appel : %nom(arg1, arg2) -> substitution des parametres
            Fonctions macro : %EVAL(expr), %SYSEVALF(expr),
              %SUBSTR(chaine, pos, len), %UPCASE(chaine),
              %LENGTH(chaine), %SCAN(chaine, n, delim),
              %SYSFUNC(fonction(args))
            Logique macro : %IF %THEN %ELSE, %DO %END, %DO %WHILE, %DO %UNTIL
              Evaluee a la pre-compilation (avant le DATA/PROC step)
            Variables macro automatiques : &SYSDATE (date courante),
              &SYSTIME (heure courante), &SYSVER (version SAS)
              -> valeurs constantes codees en dur dans le compilateur

  TODO 22 - FONCTIONS INTEGREES
            Fonctions numeriques :
              ABS(x) : valeur absolue -> CALL _SASRT_ABS
              INT(x) : partie entiere (identite sur entier 16 bits)
              ROUND(x, unite) : arrondi -> CALL _SASRT_ROUND
              MOD(x, y) : modulo -> IDIV, resultat dans DX
              MIN(a, b, ...) : minimum de n valeurs -> boucle CMP
              MAX(a, b, ...) : maximum de n valeurs -> boucle CMP
              SUM(a, b, ...) : somme ignorant les manquants
              SIGN(x) : signe (-1, 0, 1) -> CMP + conditionnel
              SQRT(x), LOG(x), EXP(x) : avertissement + stub entier
            Fonctions caracteres :
              SUBSTR(str, pos, len) : sous-chaine -> CALL _SASRT_SUBSTR
              TRIM(str) : supprimer espaces de fin -> CALL _SASRT_TRIM
              LEFT(str) : aligner a gauche -> CALL _SASRT_LEFT
              RIGHT(str) : aligner a droite -> CALL _SASRT_RIGHT
              UPCASE(str) : majuscules -> CALL _SASRT_UPCASE
              LOWCASE(str) : minuscules -> CALL _SASRT_LOWCASE
              INDEX(str, sub) : position de sous-chaine -> CALL _SASRT_INDEX
              LENGTH(str) : longueur effective -> CALL _SASRT_STRLEN
              COMPRESS(str, chars) : supprimer caracteres -> CALL _SASRT_COMPRESS
              CAT(a, b), CATS(a, b), CATX(sep, a, b) : concatenation
              PUT(num, fmt.) : conversion num -> char avec format
              INPUT(str, infmt.) : conversion char -> num avec informat
            Fonctions de date :
              TODAY() : date courante -> valeur constante codee en dur
              MDY(m, d, y) : construire une date SAS
              YEAR(date), MONTH(date), DAY(date) : extraire composantes

  TODO 23 - FUSION ET MANIPULATION DE DATASETS (MERGE / SET / BY)
            Instruction SET : lecture sequentielle
              SET ds1 ; -> lire observation par observation
              SET ds1 ds2 ; -> concatenation verticale (empiler)
              SET ds1 POINT=n ; -> acces direct a l observation n
              SET ds1 NOBS=total ; -> nombre total d observations -> variable
              Fin de fichier : variable automatique END= detectee
            Instruction MERGE : fusion horizontale par cle
              MERGE ds1 ds2 ; BY cle ; -> fusion par correspondance de cle
              Variables communes : la derniere valeur lue prevaut
              MERGE un-a-un si pas de BY (correspondance par position)
              Observations non appariees : manquantes pour les variables absentes
            Instruction BY : specifier les cles de tri pour MERGE ou traitement
              BY var1 var2 ; -> tri requis prealable (PROC SORT)
              Variables automatiques : FIRST.var (debut de groupe), LAST.var (fin)
                FIRST.var = 1 si premiere observation du groupe -> AX=1
                LAST.var = 1 si derniere observation du groupe -> AX=1
            Instruction UPDATE : mise a jour d un dataset maitre par un dataset
              de transactions (similaire a MERGE, valeurs non manquantes ecrasent)
            Instruction MODIFY : modification en place d un dataset existant

  TODO 24 - RUNTIME MINIMAL
            _SASRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _SASRT_PRINTLN : _SASRT_PRINT + CR+LF via _SAS_CRLF DB 13,10,0
            _SASRT_STRLEN(SI=str) : compte octets non-espace depuis la fin -> AX
            _SASRT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _SASRT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _SASRT_CONCAT(SI=src1, DI=src2) : concatenation chaines -> AX=ptr buf
            _SASRT_STRCMP(SI=str1, DI=str2) : comparaison -> drapeaux ZF/CF
            _SASRT_SUBSTR(SI=str, BX=pos, CX=len) : sous-chaine -> AX=ptr
            _SASRT_TRIM(SI=str) : supprimer espaces de fin -> AX=ptr
            _SASRT_LEFT(SI=str) : supprimer espaces de debut -> AX=ptr
            _SASRT_UPCASE(SI=str) : convertir en majuscules -> AX=ptr
            _SASRT_LOWCASE(SI=str) : convertir en minuscules -> AX=ptr
            _SASRT_INDEX(SI=str, DI=sub) : recherche sous-chaine -> AX=pos
            _SASRT_ABS(AX=n) : valeur absolue -> AX
            _SASRT_POW(AX=base, BX=exp) : puissance entiere -> AX
            _SASRT_ROUND(AX=n, BX=unite) : arrondi entier -> AX
            _SASRT_COMPRESS(SI=str, DI=chars) : supprimer caracteres -> AX=ptr
            _SASRT_READLINE(DI=buf, CX=maxlen) : lire une ligne -> AX=len
            _SASRT_MISSING(AX=val) : tester si manquant (8000h) -> ZF=1 si oui
            _SASRT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _SAS_HEAP DB 4096 DUP(0) + _SAS_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _SASP_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _SASP_Main
            Fichiers SAMPLES\SAS\ a creer :
              hello.sas     (DATA _NULL_, PUT, chaines, variables)
              datastep.sas  (DATA step, INPUT, DATALINES, observations)
              control.sas   (IF/THEN/ELSE, SELECT/WHEN, DO loops)
              arrays.sas    (ARRAY, boucle DO sur tableaux, DIM)
              merge.sas     (SET, MERGE, BY, FIRST./LAST.)
              procprint.sas (PROC PRINT, VAR, WHERE, FORMAT)
              procmeans.sas (PROC MEANS, N MEAN MIN MAX SUM)
              macros.sas    (macro-variables, %MACRO/%MEND, %IF/%THEN)
            Smoke tests : SAS86.EXE -v SAMPLES\SAS\*.sas

  ============================================================ *)

{ ============================================================
  SAS86 - Compilateur SAS -> assembleur 8086
  Version : 1.0  Date : 2026-03-07
  Compilation : ppc386 -O2 -Mtp SAS86.PAS
  ============================================================ }

Program SAS86;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES
  ============================================================ }
Const
  SAS86_VERSION = '1.0';
  SAS86_DATE    = '2026-03-07';

  (* Limites internes *)
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_OBS_SIZE  = 512;    (* taille max d une observation en octets *)
  MAX_DATASETS  = 32;     (* nombre max de datasets en memoire      *)
  STACK_SIZE    = 1024;
  MISSING_VAL   = -32768; (* sentinelle valeur manquante = 8000h    *)

  (* Prefixes de nommage ASM *)
  SAS_VAR_PFX  = '_SASV_';   (* variable dans le PDV              *)
  SAS_PROC_PFX = '_SASP_';   (* procedure / etape                 *)
  SAS_STR_PFX  = '_SASK_';   (* constante chaine litterale        *)
  SAS_RT_PFX   = '_SASRT_';  (* routine runtime                   *)
  SAS_LBL_PFX  = '_SASL_';   (* label de saut interne             *)
  SAS_DS_PFX   = '_SASD_';   (* dataset en memoire                *)
  SAS_MAC_PFX  = '_SASM_';   (* macro                             *)
  SAS_FMT_PFX  = '_SASF_';   (* format utilisateur                *)

  (* Codes de sortie *)
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  (* Indices de types primitifs SAS *)
  TY_IDX_NUMERIC   = 0;  (* entier 16 bits signe          *)
  TY_IDX_CHARACTER = 1;  (* chaine longueur fixe          *)
  TY_IDX_DATE      = 2;  (* jours depuis 01JAN1960        *)
  TY_IDX_TIME      = 3;  (* secondes depuis minuit         *)
  TY_IDX_DATETIME  = 4;  (* secondes depuis 01JAN1960      *)
  TY_PRIM_COUNT    = 5;
  TY_UNKNOWN       = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  (* ---- Options de compilation ----------------------------- *)
  TOptions = Record
    SrcFile   : TString;   (* fichier source (.sas)               *)
    OutFile   : TString;   (* fichier assembleur de sortie (.asm)  *)
    Verbose   : Boolean;   (* -v : banniere et statistiques        *)
    DebugMode : Boolean;   (* -d : affichage de chaque token       *)
    Warnings  : Boolean;   (* -w : activer les avertissements      *)
  End;

  (* ---- Tokens SAS (TODO 02) ------------------------------ *)
  TTokenKind = (
    TK_EOF,        (* fin de fichier                         *)
    TK_INTEGER,    (* literal entier 42                      *)
    TK_FLOAT,      (* literal reel 3.14                      *)
    TK_STRING,     (* literal chaine 'abc' ou "abc"          *)
    TK_IDENT,      (* identificateur                         *)
    TK_KEYWORD,    (* mot-cle SAS reconnu                    *)
    TK_OP,         (* operateur + - * / ** = ^= < > etc.     *)
    TK_PUNCT,      (* ponctuation ( ) , .                    *)
    TK_SEMICOLON,  (* delimiteur d instruction ;             *)
    TK_AMPERSAND,  (* & (macro-variable)                     *)
    TK_PERCENT,    (* % (macro instruction)                  *)
    TK_FORMAT      (* format w.d ou $w. ou nom_format.       *)
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;     (* valeur textuelle brute             *)
    IntVal   : LongInt;     (* valeur entiere (TK_INTEGER)        *)
    FloatVal : Real;        (* valeur flottante (TK_FLOAT)        *)
    Line     : Integer;     (* ligne source (1-base)              *)
    Col      : Integer;     (* colonne source (1-base)            *)
  End;

  (* ---- Categories de symboles (TODO 05) ------------------- *)
  TSymCat = (
    SC_VAR,       (* variable numerique ou caractere          *)
    SC_ARRAY,     (* tableau SAS                              *)
    SC_FORMAT,    (* format utilisateur                       *)
    SC_INFORMAT,  (* informat utilisateur                     *)
    SC_LABEL,     (* etiquette de saut (GOTO)                 *)
    SC_MACRO,     (* macro %MACRO/%MEND                       *)
    SC_MACROVAR,  (* macro-variable %LET                      *)
    SC_DATASET,   (* dataset en memoire                       *)
    SC_PROC       (* procedure SAS                            *)
  );

  TSymRec = Record
    Name        : TString;   (* identifiant SAS (majuscules)       *)
    MangledName : TString;   (* _SASV_nom / _SASP_nom              *)
    Cat         : TSymCat;
    TypeIdx     : Integer;   (* indice dans TypeTab                *)
    ScopeLevel  : Integer;
    Offset      : Integer;   (* offset dans le PDV                 *)
    VarLen      : Integer;   (* longueur pour CHARACTER             *)
    IsRetained  : Boolean;   (* RETAIN : ne pas reinitialiser      *)
    IsDropped   : Boolean;   (* DROP : exclure du dataset           *)
    IsKept      : Boolean;   (* KEEP : inclure dans le dataset      *)
    DeclLine    : Integer;
  End;

  (* ---- Types internes (TODO 06) --------------------------- *)
  TTypeKind = (
    TYK_NUMERIC,    (* entier 16 bits signe                  *)
    TYK_CHARACTER,  (* chaine longueur fixe                  *)
    TYK_DATE,       (* jours depuis 01JAN1960                *)
    TYK_TIME,       (* secondes depuis minuit                 *)
    TYK_DATETIME,   (* secondes depuis 01JAN1960              *)
    TYK_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   (* octets : numeric=2, character=longueur *)
  End;

  (* ---- Valeurs d expression (TODO 10-11) ------------------ *)
  TExprKind = (
    EK_NONE,   (* void / pas de valeur                       *)
    EK_IMM,    (* immediate dans ImmVal                      *)
    EK_AX,     (* valeur dans AX                             *)
    EK_MEM     (* adresse dans le PDV ou label               *)
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
    SymIdx  : Integer;   (* indice dans SymTab (-1 = pas de lvalue) *)
  End;

  (* ---- Segment de donnees (TODO 08) ----------------------- *)
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK, DK_RECORD_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
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
  LexSrcF      : Text;
  LexLine      : String;
  LexLineNo    : Integer;
  LexColNo     : Integer;
  LexEOF       : Boolean;
  LexOpened    : Boolean;
  CurToken     : TToken;
  LexAtStmtBeg : Boolean;  (* True apres ; ou debut de fichier *)

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
  CurFrameSize : Integer;
  LabelGenSeq  : Integer;

  (* Boucles (TODO 14) *)
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  (* Segment de donnees (TODO 08) *)
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  (* Etat general *)
  RuntimeEmitted : Boolean;

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;             Forward;
Procedure LexClose;            Forward;
Procedure LexNextToken;        Forward;
Procedure PrintToken(Const T : TToken); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
Procedure ParseStmt;           Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine;       Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitInstr(Const Mnem : TString); Forward;
Procedure EmitInstrA(Const Mnem, A1 : TString); Forward;
Procedure EmitInstrAB(Const Mnem, A1, A2 : TString); Forward;
Function  LabelGen : TString;  Forward;
Procedure EmitOpen;            Forward;
Procedure EmitClose;           Forward;
Procedure EmitHeader;          Forward;
Procedure EmitDataSeg;         Forward;
Procedure EmitRuntime;         Forward;
Procedure EmitProlog;          Forward;
Procedure EmitEpilog;          Forward;
Procedure TypeInit;            Forward;
Procedure SymInit;             Forward;
Procedure ParserAdvance;       Forward;
(* TODO 02 - Forward declarations lexeur *)
Function  IsKeyword(Const S : TString) : Boolean; Forward;
Procedure LexNextLine;         Forward;
Procedure LexSkipBlockComment; Forward;
Procedure LexSkipStarComment;  Forward;
Function  IsIdentStart(Ch : Char) : Boolean; Forward;
Function  IsIdentCont(Ch : Char) : Boolean; Forward;
Function  IsHexDigit(Ch : Char) : Boolean; Forward;
Function  HexVal(Ch : Char) : Integer; Forward;
Procedure LexScanIdent;        Forward;
Procedure LexScanNumber;       Forward;
Procedure LexScanString(Quote : Char); Forward;
(* TODO 03 - Forward declarations litteraux et constantes *)
Function  DataAdd(Const Lbl : TString; Kind : TDataKind;
                  AIntVal : LongInt; Const AStrVal : TString) : Integer; Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeMissing(Var Res : TExprVal); Forward;
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
Function  IsMissingDot : Boolean; Forward;
(* TODO 04 - Forward declarations operateurs et precedence *)
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  BinOpIsRight(Const Op : TString) : Boolean; Forward;
Procedure ExprFlushToAX(Var E : TExprVal); Forward;
Procedure EmitBinOp(Const Op : TString; LeftTy, RightTy : Integer); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Procedure ParseUnary(Var Res : TExprVal); Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
(* TODO 05 - Forward declarations table des symboles *)
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Cat : TSymCat) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                Level : Integer) : Integer; Forward;
Function  SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AOffset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
(* TODO 06 - Forward declarations systeme de types *)
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

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS [IMPLEMENTE]
  ============================================================ }

(* ---- Messages d erreur et d avertissement ----------------- *)

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('SAS86: FATAL: ', Msg);
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
  Write('SAS86:');
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
  Write('SAS86:');
  If CurToken.Line > 0 Then
    Write(Opts.SrcFile, ':', CurToken.Line, ': ');
  WriteLn('warning: ', Msg);
  Inc(WarnCount);
End;

(* ---- Banniere ---------------------------------------------- *)

Procedure ShowBanner;
Begin
  WriteLn('SAS86 v', SAS86_VERSION, ' (', SAS86_DATE, ')');
  WriteLn('Compilateur SAS -> assembleur 8086 (MASM .MODEL SMALL)');
  WriteLn('Turbo Pascal / Free Pascal (-Mtp)');
  WriteLn;
End;

Procedure ShowUsage;
Begin
  WriteLn('Usage: SAS86 <source.sas> [sortie.asm] [-v] [-d] [-w]');
  WriteLn;
  WriteLn('  source.sas : fichier SAS source');
  WriteLn('  sortie.asm : fichier assembleur de sortie (defaut: source.asm)');
  WriteLn('  -v         : mode verbeux (banniere + statistiques)');
  WriteLn('  -d         : debug tokens (affiche chaque token)');
  WriteLn('  -w         : activer les avertissements');
  WriteLn;
  Halt(EXIT_USAGE);
End;

Procedure ShowHelp;
Begin
  WriteLn('SAS86 - Compilateur SAS vers assembleur 8086 (MASM/TASM)');
  WriteLn;
  WriteLn('Syntaxe : SAS86 [options] <source.sas> [sortie.asm]');
  WriteLn;
  WriteLn('Options :');
  WriteLn('  -v         mode verbeux (banniere et statistiques)');
  WriteLn('  -d         mode debug (affichage des tokens)');
  WriteLn('  -w         activer les avertissements');
  WriteLn('  -h         afficher cette aide');
  WriteLn('  --help     afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  SAS86 hello.sas');
  WriteLn('  SAS86 hello.sas hello.asm -v');
  WriteLn('  SAS86 -d -w programme.sas');
  WriteLn;
  Halt(EXIT_OK);
End;

(* ---- Utilitaires chaines ----------------------------------- *)

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

(* Extrait le nom de base d un chemin (sans extension) *)
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

(* Remplace l extension d un chemin *)
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

(* ---- Initialisation des options ---------------------------- *)

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
End;

(* ---- Analyse des arguments de la ligne de commande --------- *)

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
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('SAS86: option inconnue: ', Arg);
      ShowUsage;
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('SAS86: argument inattendu: ', Arg);
      ShowUsage;
    End;
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('SAS86: fichier source manquant');
    ShowUsage;
  End;

  If Opts.OutFile = '' Then
    Opts.OutFile := ReplaceExt(Opts.SrcFile, '.asm');
End;

(* ---- Nettoyage --------------------------------------------- *)

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

(* ---- Initialisation generale des variables globales --------- *)

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
  LexAtStmtBeg   := True;
  CurFrameSize   := 0;
  LoopTop        := 0;
  RuntimeEmitted := False;
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
  TODO 02 - LEXEUR (TOKENS SAS) [IMPLEMENTE]
  ============================================================ }

(* ---- IsKeyword : teste si S est un mot-cle SAS ------------ *)
(* S doit etre en MAJUSCULES                                    *)
Function IsKeyword(Const S : TString) : Boolean;
Begin
  IsKeyword :=
    (S = 'DATA')      Or (S = 'RUN')       Or (S = 'SET')       Or
    (S = 'MERGE')     Or (S = 'BY')        Or (S = 'INPUT')     Or
    (S = 'PUT')       Or (S = 'INFILE')    Or (S = 'FILE')      Or
    (S = 'IF')        Or (S = 'THEN')      Or (S = 'ELSE')      Or
    (S = 'DO')        Or (S = 'END')       Or (S = 'WHILE')     Or
    (S = 'UNTIL')     Or (S = 'OUTPUT')    Or (S = 'RETURN')    Or
    (S = 'DELETE')    Or (S = 'RETAIN')    Or (S = 'DROP')      Or
    (S = 'KEEP')      Or (S = 'RENAME')    Or (S = 'LENGTH')    Or
    (S = 'FORMAT')    Or (S = 'INFORMAT')  Or (S = 'LABEL')     Or
    (S = 'ARRAY')     Or (S = 'PROC')      Or (S = 'QUIT')      Or
    (S = 'TITLE')     Or (S = 'FOOTNOTE')  Or (S = 'OPTIONS')   Or
    (S = 'WHERE')     Or (S = 'CARDS')     Or (S = 'DATALINES') Or
    (S = 'STOP')      Or (S = 'ABORT')     Or (S = 'GOTO')      Or
    (S = 'LINK')      Or (S = 'SELECT')    Or (S = 'WHEN')      Or
    (S = 'OTHERWISE') Or (S = 'ATTRIB')    Or (S = 'CALL')      Or
    (S = 'VAR')       Or (S = 'CLASS')     Or (S = 'TABLES')    Or
    (S = 'IN')        Or (S = 'NOT')       Or (S = 'AND')       Or
    (S = 'OR')        Or (S = 'EQ')        Or (S = 'NE')        Or
    (S = 'LT')        Or (S = 'LE')        Or (S = 'GT')        Or
    (S = 'GE')        Or (S = 'LEAVE')     Or (S = 'CONTINUE')  Or
    (S = '_NULL_')    Or (S = '_TEMPORARY_');
End;

(* ---- PrintToken : affichage debug d un token --------------- *)
Procedure PrintToken(Const T : TToken);
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', T.Line, ',', T.Col, '] ');
  Case T.Kind Of
    TK_EOF       : Write('EOF');
    TK_INTEGER   : Write('INT(', T.IntVal, ')');
    TK_FLOAT     : Write('FLOAT(', T.Val, ')');
    TK_STRING    : Write('STR(''', T.Val, ''')');
    TK_IDENT     : Write('IDENT(', T.Val, ')');
    TK_KEYWORD   : Write('KW(', T.Val, ')');
    TK_OP        : Write('OP(', T.Val, ')');
    TK_PUNCT     : Write('PUNCT(', T.Val, ')');
    TK_SEMICOLON : Write('SEMI');
    TK_AMPERSAND : Write('AMP(', T.Val, ')');
    TK_PERCENT   : Write('PCT(', T.Val, ')');
    TK_FORMAT    : Write('FMT(', T.Val, ')');
  End;
  WriteLn;
End;

(* ---- LexNextLine : lire la prochaine ligne source ---------- *)
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

(* ---- LexSkipBlockComment : sauter /* ... */ ---------------- *)
Procedure LexSkipBlockComment;
Var
  Done : Boolean;
Begin
  Inc(LexColNo); Inc(LexColNo); (* sauter / et * *)
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
  If Not Done Then
    CompileError('commentaire /* non ferme');
End;

(* ---- LexSkipStarComment : sauter * ... ; ------------------- *)
(* En SAS, le commentaire * va jusqu au prochain ;              *)
Procedure LexSkipStarComment;
Begin
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
      LexNextLine
    Else If LexLine[LexColNo] = ';' Then
    Begin
      Inc(LexColNo); (* consomme le ; *)
      Exit;
    End
    Else
      Inc(LexColNo);
  End;
End;

(* ---- Fonctions de test sur les caracteres ------------------- *)
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
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

(* ---- LexScanIdent : scanner un identificateur ou mot-cle --- *)
(* SAS est insensible a la casse : on convertit en majuscules   *)
Procedure LexScanIdent;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And IsIdentCont(LexLine[LexColNo]) Do
  Begin
    Ch := LexLine[LexColNo];
    (* Convertir en majuscule *)
    If (Ch >= 'a') And (Ch <= 'z') Then
      Ch := Chr(Ord(Ch) - 32);
    If Length(S) < MAX_STR Then
      S := S + Ch;
    Inc(LexColNo);
  End;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
  (* Verifier si c est un mot-cle SAS *)
  If IsKeyword(S) Then
    CurToken.Kind := TK_KEYWORD
  Else
    CurToken.Kind := TK_IDENT;
End;

(* ---- LexScanNumber : scanner un litteral numerique --------- *)
(* SAS : decimaux et reels (avec notation scientifique)          *)
Procedure LexScanNumber;
Var
  N       : LongInt;
  IsFloat : Boolean;
  NegExp  : Boolean;
  Ch      : Char;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
Begin
  N       := 0;
  IsFloat := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  (* Partie entiere *)
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] >= '0') And (LexLine[LexColNo] <= '9') Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    Inc(LexColNo);
  End;
  (* Partie decimale .ddd *)
  If (LexColNo <= Length(LexLine)) And
     (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     (LexLine[LexColNo + 1] >= '0') And (LexLine[LexColNo + 1] <= '9') Then
  Begin
    IsFloat := True;
    Inc(LexColNo); (* sauter le . *)
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
  (* Exposant E/e [+-]ddd *)
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    Ch := ' ';
    If LexColNo < Length(LexLine) Then
      Ch := LexLine[LexColNo + 1];
    (* Verifier qu il y a un chiffre ou un signe apres le E *)
    If ((Ch >= '0') And (Ch <= '9')) Or (Ch = '+') Or (Ch = '-') Then
    Begin
      IsFloat := True;
      Inc(LexColNo); (* sauter E *)
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
  End;
  (* Calculer la valeur finale *)
  If IsFloat Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else            FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurToken.FloatVal := FltVal;
    If FltVal > 32767.0 Then N := 32767
    Else If FltVal < -32768.0 Then N := -32768
    Else N := Trunc(FltVal);
    CurToken.Kind := TK_FLOAT;
  End
  Else
    CurToken.Kind := TK_INTEGER;
  CurToken.IntVal := N;
  Str(N, CurToken.Val);
End;

(* ---- LexScanString : scanner une chaine entre quotes ------- *)
(* SAS double le quote pour l echapper : 'it''s' -> it's         *)
Procedure LexScanString(Quote : Char);
Var
  S       : TString;
  Suffix  : Char;
  HexStr  : TString;
  I       : Integer;
  V       : LongInt;
Begin
  S := '';
  Inc(LexColNo); (* sauter le quote ouvrant *)
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      (* Chaine multi-ligne : passer a la ligne suivante *)
      If Length(S) < MAX_STR Then
        S := S + #13;
      LexNextLine;
    End
    Else If LexLine[LexColNo] = Quote Then
    Begin
      Inc(LexColNo);
      (* Doublage du quote = echappement *)
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = Quote) Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + Quote;
        Inc(LexColNo);
      End
      Else
        Break; (* fin de la chaine *)
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;
  (* Verifier les suffixes SAS : 'd (date), 't (time), 'x (hex) *)
  If (LexColNo <= Length(LexLine)) Then
  Begin
    Suffix := LexLine[LexColNo];
    If (Suffix >= 'a') And (Suffix <= 'z') Then
      Suffix := Chr(Ord(Suffix) - 32);
    If Suffix = 'X' Then
    Begin
      (* Constante hexadecimale : '0A'x -> valeur hex *)
      Inc(LexColNo);
      V := 0;
      HexStr := S;
      For I := 1 To Length(HexStr) Do
      Begin
        If IsHexDigit(HexStr[I]) Then
          V := V * 16 + HexVal(HexStr[I]);
      End;
      CurToken.Kind   := TK_INTEGER;
      CurToken.IntVal := V;
      Str(V, CurToken.Val);
      Exit;
    End
    Else If Suffix = 'D' Then
    Begin
      (* Date litteral : '01JAN2026'd -> avertissement *)
      Inc(LexColNo);
      WarnMsg('date litteral ''' + S + '''d non supporte, utilise 0');
      CurToken.Kind   := TK_INTEGER;
      CurToken.IntVal := 0;
      CurToken.Val    := '0';
      Exit;
    End
    Else If Suffix = 'T' Then
    Begin
      (* Time litteral : '12:30't -> avertissement *)
      Inc(LexColNo);
      WarnMsg('time litteral ''' + S + '''t non supporte, utilise 0');
      CurToken.Kind   := TK_INTEGER;
      CurToken.IntVal := 0;
      CurToken.Val    := '0';
      Exit;
    End;
  End;
  CurToken.Kind   := TK_STRING;
  CurToken.Val    := S;
  CurToken.IntVal := 0;
End;

(* ---- LexInit : initialiser le lexeur ----------------------- *)
Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir ' + Opts.SrcFile);
  LexOpened    := True;
  LexLineNo   := 0;
  LexColNo     := 1;
  LexLine      := '';
  LexEOF       := False;
  LexAtStmtBeg := True;
  LexNextLine; (* lire la premiere ligne *)
End;

(* ---- LexClose : fermer le fichier source ------------------- *)
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

(* ---- LexNextToken : scanner principal ---------------------- *)
Procedure LexNextToken;
Var
  Ch, Ch2 : Char;
  Scanning : Boolean;
Begin
  CurToken.IntVal   := 0;
  CurToken.FloatVal := 0.0;

  Scanning := True;
  While Scanning Do
  Begin
    (* Passer a la ligne suivante si fin de ligne *)
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

    (* Fin de fichier *)
    If LexEOF Then
    Begin
      CurToken.Kind := TK_EOF;
      CurToken.Val  := '';
      CurToken.Line := LexLineNo;
      CurToken.Col  := LexColNo;
      Scanning      := False;
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

    (* Commentaire bloc /* ... */ *)
    Else If (Ch = '/') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      LexSkipBlockComment;
    End

    (* Commentaire etoile * ... ; en debut d instruction *)
    Else If (Ch = '*') And LexAtStmtBeg Then
    Begin
      LexSkipStarComment;
      LexAtStmtBeg := True; (* le ; a ete consomme, on est en debut *)
    End

    (* Point-virgule : delimiteur d instruction *)
    Else If Ch = ';' Then
    Begin
      CurToken.Kind := TK_SEMICOLON;
      CurToken.Val  := ';';
      Inc(LexColNo);
      LexAtStmtBeg := True;
      Scanning := False;
    End

    (* Ampersand : macro-variable &name *)
    Else If Ch = '&' Then
    Begin
      Inc(LexColNo);
      CurToken.Val := '&';
      (* Scanner le nom de la macro-variable *)
      While (LexColNo <= Length(LexLine)) And
            IsIdentCont(LexLine[LexColNo]) Do
      Begin
        Ch2 := LexLine[LexColNo];
        If (Ch2 >= 'a') And (Ch2 <= 'z') Then
          Ch2 := Chr(Ord(Ch2) - 32);
        If Length(CurToken.Val) < MAX_STR Then
          CurToken.Val := CurToken.Val + Ch2;
        Inc(LexColNo);
      End;
      (* Le point optionnel termine le nom de macro-variable *)
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
        Inc(LexColNo);
      CurToken.Kind := TK_AMPERSAND;
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Percent : macro-instruction %name *)
    Else If Ch = '%' Then
    Begin
      Inc(LexColNo);
      CurToken.Val := '%';
      (* Scanner le nom de la macro-instruction *)
      While (LexColNo <= Length(LexLine)) And
            IsIdentCont(LexLine[LexColNo]) Do
      Begin
        Ch2 := LexLine[LexColNo];
        If (Ch2 >= 'a') And (Ch2 <= 'z') Then
          Ch2 := Chr(Ord(Ch2) - 32);
        If Length(CurToken.Val) < MAX_STR Then
          CurToken.Val := CurToken.Val + Ch2;
        Inc(LexColNo);
      End;
      CurToken.Kind := TK_PERCENT;
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Identificateur ou mot-cle *)
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Nombre *)
    Else If (Ch >= '0') And (Ch <= '9') Then
    Begin
      LexScanNumber;
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Nombre commencant par un point : .5 *)
    Else If (Ch = '.') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] >= '0') And
            (LexLine[LexColNo + 1] <= '9') Then
    Begin
      (* Traiter comme 0.ddd *)
      LexScanNumber;
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Chaine simple-quote *)
    Else If Ch = '''' Then
    Begin
      LexScanString('''');
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Chaine double-quote *)
    Else If Ch = '"' Then
    Begin
      LexScanString('"');
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Operateur ** (puissance) *)
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '**';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Operateurs * / + - *)
    Else If (Ch = '*') Or (Ch = '/') Or (Ch = '+') Or (Ch = '-') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Operateur || (concatenation) *)
    Else If (Ch = '|') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '|') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '||';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Operateur !! (synonyme de ||) *)
    Else If (Ch = '!') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '!') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '!!';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* = : egalite *)
    Else If Ch = '=' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '=';
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* ^= : different *)
    Else If (Ch = '^') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '^=';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* ~= : different (alternative) *)
    Else If (Ch = '~') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '^=';  (* normaliser *)
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* ^, ~ : operateur NOT logique symbolique *)
    Else If (Ch = '^') Or (Ch = '~') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := 'NOT';
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* <> : operateur MIN en SAS *)
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '>') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<>';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* <= : inferieur ou egal *)
    Else If (Ch = '<') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<=';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* < : inferieur *)
    Else If Ch = '<' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '<';
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* >< : operateur MAX en SAS *)
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '<') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '><';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* >= : superieur ou egal *)
    Else If (Ch = '>') And (LexColNo < Length(LexLine)) And
            (LexLine[LexColNo + 1] = '=') Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>=';
      Inc(LexColNo); Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* > : superieur *)
    Else If Ch = '>' Then
    Begin
      CurToken.Kind := TK_OP;
      CurToken.Val  := '>';
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Point seul : valeur manquante numerique ou ponctuation *)
    Else If Ch = '.' Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := '.';
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Ponctuation : ( ) , @ # $ *)
    Else If (Ch = '(') Or (Ch = ')') Or (Ch = ',') Or
            (Ch = '@') Or (Ch = '#') Or (Ch = '$') Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Accolades pour les indices de tableaux SAS *)
    Else If (Ord(Ch) = 123) Or (Ord(Ch) = 125) Then
    Begin
      CurToken.Kind := TK_PUNCT;
      CurToken.Val  := Ch;
      Inc(LexColNo);
      LexAtStmtBeg := False;
      Scanning := False;
    End

    (* Caractere inconnu *)
    Else
    Begin
      CompileError('caractere inattendu : ' + Ch);
      Inc(LexColNo);
    End;

  End; (* While Scanning *)
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES [IMPLEMENTE]
  ============================================================ }

(* ---- DataAdd : ajouter une entree dans le segment DATA ----- *)
(* Retourne l index dans DataTab ou -1 si plein.                *)
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

(* ---- DataAddStr : creer un label _SASK_N et stocker chaine -- *)
(* Retourne l index dans DataTab.                                *)
Function DataAddStr(Const S : TString) : Integer;
Var
  Lbl : TString;
Begin
  Inc(LabelGenSeq);
  Lbl := SAS_STR_PFX + IntToStr(LabelGenSeq);
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

(* ---- DataAddWord : ajouter variable/constante DW ------------ *)
Function DataAddWord(Const Lbl : TString; AIntVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(Lbl, DK_WORD, AIntVal, '');
End;

(* ---- ExprMakeImm : construire une valeur immediate ---------- *)
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeNone : valeur invalide (void/erreur) ----------- *)
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- ExprMakeMissing : valeur manquante SAS (. = 8000h) ---- *)
(* En SAS, une valeur manquante numerique est representee par    *)
(* la sentinelle MISSING_VAL = -32768 = 8000h.                  *)
Procedure ExprMakeMissing(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := MISSING_VAL;
  Res.TypeIdx := TY_IDX_NUMERIC;
  Res.Offset  := 0;
  Res.SymIdx  := -1;
End;

(* ---- LitEvalInt : evaluer un token TK_INTEGER --------------- *)
(* IntVal est deja calcule par LexScanNumber.                    *)
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_NUMERIC, Res);
End;

(* ---- LitEvalFloat : evaluer un token TK_FLOAT (trunc) ------ *)
(* SAS utilise des reels en interne (8 octets) ; en 16 bits on   *)
(* tronque a l entier. Avertissement si perte de precision.      *)
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  If IV > 32767 Then IV := 32767;
  If IV < -32768 Then IV := -32768;
  WarnMsg('reel ' + T.Val + ' tronque a entier ' + IntToStr(IV));
  ExprMakeImm(IV, TY_IDX_NUMERIC, Res);
End;

(* ---- IsMissingDot : teste si le token courant est un . ------ *)
(* seul (valeur manquante numerique) et non partie d un nombre   *)
(* ou d un format. Retourne True si CurToken = TK_PUNCT '.'     *)
Function IsMissingDot : Boolean;
Begin
  IsMissingDot := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.');
End;

(* ---- LitEval : dispatcher principal pour les litteraux ------ *)
(* Types de tokens acceptes : TK_INTEGER, TK_FLOAT, TK_STRING,  *)
(* TK_PUNCT '.' (valeur manquante).                              *)
(* Pour TK_STRING : le lexeur a deja traite les suffixes         *)
(* 'd (date), 't (time), 'x (hex) dans LexScanString.           *)
(* Les constantes hexadecimales 'xx'x produisent TK_INTEGER      *)
(* via LexScanString. Les dates 'd et heures 't produisent       *)
(* TK_INTEGER avec la valeur convertie par le lexeur.            *)
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  (* valeur par defaut *)
  Case T.Kind Of
    TK_INTEGER :
      LitEvalInt(T, Res);
    TK_FLOAT :
      LitEvalFloat(T, Res);
    TK_STRING :
    Begin
      Res.Kind    := EK_MEM;
      Res.ImmVal  := 0;
      Res.TypeIdx := TY_IDX_CHARACTER;
      Res.Offset  := DataAddStr(T.Val);
      Res.SymIdx  := -1;
    End;
    TK_PUNCT :
    Begin
      (* . (point seul) = valeur manquante numerique *)
      If T.Val = '.' Then
        ExprMakeMissing(Res);
    End;
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE [IMPLEMENTE]
  ============================================================ }

(* ---- BinOpPrec : precedence des operateurs binaires SAS ---- *)
(* Niveaux (du plus fort au plus faible) :                       *)
(*   7. ** (puissance)                                           *)
(*   6. * /                                                      *)
(*   5. + - (binaire) || !! (concatenation)                      *)
(*   4. <> >< (MIN/MAX)                                          *)
(*   3. < <= = ^= >= > EQ NE LT LE GT GE IN                     *)
(*   2. AND &                                                    *)
(*   1. OR |                                                     *)
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  If Op = '**' Then
    BinOpPrec := 7
  Else If (Op = '*') Or (Op = '/') Then
    BinOpPrec := 6
  Else If (Op = '+') Or (Op = '-') Or
          (Op = '||') Or (Op = '!!') Then
    BinOpPrec := 5
  Else If (Op = '<>') Or (Op = '><') Then
    BinOpPrec := 4
  Else If (Op = '<') Or (Op = '<=') Or (Op = '=') Or
          (Op = '^=') Or (Op = '>=') Or (Op = '>') Or
          (Op = 'EQ') Or (Op = 'NE') Or (Op = 'LT') Or
          (Op = 'LE') Or (Op = 'GT') Or (Op = 'GE') Or
          (Op = 'IN') Then
    BinOpPrec := 3
  Else If (Op = 'AND') Or (Op = '&') Then
    BinOpPrec := 2
  Else If (Op = 'OR') Or (Op = '|') Then
    BinOpPrec := 1
  Else
    BinOpPrec := 0;
End;

(* ---- BinOpIsRight : operateur droit-associatif ? ------------ *)
(* Seul ** est droit-associatif en SAS.                          *)
Function BinOpIsRight(Const Op : TString) : Boolean;
Begin
  BinOpIsRight := (Op = '**');
End;

(* ---- ExprFlushToAX : materialiser une expression dans AX ---- *)
(* Si deja AX, ne rien faire. Si immediate, MOV AX, imm.         *)
(* Si memoire, stub pour l instant (sera gere au TODO 05/09).    *)
Procedure ExprFlushToAX(Var E : TExprVal);
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      If E.ImmVal = 0 Then
        EmitInstrAB('XOR', 'AX', 'AX')
      Else
        EmitInstrAB('MOV', 'AX', IntToStr(E.ImmVal));
      E.Kind := EK_AX;
    End;
    EK_AX :
      ;  (* deja dans AX *)
    EK_MEM :
    Begin
      (* Chaine litterale : OFFSET label dans DataTab *)
      If (E.TypeIdx = TY_IDX_CHARACTER) And
         (E.Offset >= 0) And (E.Offset < DataCount) Then
        EmitInstrAB('MOV', 'AX', 'OFFSET ' + DataTab[E.Offset].LblName)
      (* Variable : sera gere au TODO 05/09 avec SymTab *)
      Else If E.SymIdx >= 0 Then
        EmitInstrAB('MOV', 'AX', '[' + SymTab[E.SymIdx].MangledName + ']')
      Else
        EmitInstrAB('XOR', 'AX', 'AX');
      E.Kind := EK_AX;
    End;
    EK_NONE :
      EmitInstrAB('XOR', 'AX', 'AX');
  End;
End;

(* ---- EmitBinOp : emettre l instruction ASM pour AX op BX ---- *)
(* AX = operande gauche, BX = operande droite.                   *)
(* Resultat dans AX.                                              *)
Procedure EmitBinOp(Const Op : TString; LeftTy, RightTy : Integer);
Var
  LblTrue, LblEnd : TString;
Begin
  (* Arithmetique *)
  If Op = '+' Then
  Begin
    If (LeftTy = TY_IDX_CHARACTER) Or (RightTy = TY_IDX_CHARACTER) Then
      EmitInstrA('CALL', SAS_RT_PFX + 'STRCAT')
    Else
      EmitInstrAB('ADD', 'AX', 'BX');
  End
  Else If Op = '-' Then
    EmitInstrAB('SUB', 'AX', 'BX')
  Else If Op = '*' Then
    EmitInstrA('IMUL', 'BX')
  Else If Op = '/' Then
  Begin
    EmitInstr('CWD');
    EmitInstrA('IDIV', 'BX');
  End
  Else If Op = '**' Then
    EmitInstrA('CALL', SAS_RT_PFX + 'POW')
  (* Concatenation *)
  Else If (Op = '||') Or (Op = '!!') Then
    EmitInstrA('CALL', SAS_RT_PFX + 'STRCAT')
  (* MIN/MAX *)
  Else If Op = '<>' Then
    EmitInstrA('CALL', SAS_RT_PFX + 'MIN')
  Else If Op = '><' Then
    EmitInstrA('CALL', SAS_RT_PFX + 'MAX')
  (* Comparaison *)
  Else If (Op = '=') Or (Op = 'EQ') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JE', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If (Op = '^=') Or (Op = 'NE') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JNE', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If (Op = '<') Or (Op = 'LT') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JL', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If (Op = '<=') Or (Op = 'LE') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JLE', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If (Op = '>') Or (Op = 'GT') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JG', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If (Op = '>=') Or (Op = 'GE') Then
  Begin
    LblTrue := LabelGen;
    LblEnd  := LabelGen;
    EmitInstrAB('CMP', 'AX', 'BX');
    EmitInstrA('JGE', LblTrue);
    EmitInstrAB('XOR', 'AX', 'AX');
    EmitInstrA('JMP', LblEnd);
    EmitLabel(LblTrue);
    EmitInstrAB('MOV', 'AX', '1');
    EmitLabel(LblEnd);
  End
  Else If Op = 'IN' Then
    (* IN : stub runtime - test d appartenance a une liste *)
    EmitInstrA('CALL', SAS_RT_PFX + 'INLIST')
  (* Logiques : AND/OR traites par court-circuit dans ParseExprPrec *)
  (* mais on garde un fallback ici pour les cas non court-circuites *)
  Else If (Op = 'AND') Or (Op = '&') Then
    EmitInstrAB('AND', 'AX', 'BX')
  Else If (Op = 'OR') Or (Op = '|') Then
    EmitInstrAB('OR', 'AX', 'BX')
  Else
    EmitComment('EmitBinOp: operateur inconnu: ' + Op);
End;

(* ---- ParsePrimary : atome du parseur Pratt ------------------- *)
(* Gere : litteraux (entiers, reels, chaines), . (valeur manquante) *)
(* identificateurs (variables), groupement parenthese (expr),      *)
(* appels de fonction (stub pour TODO 16).                         *)
Procedure ParsePrimary(Var Res : TExprVal);
Var
  T : TToken;
Begin
  ExprMakeNone(Res);

  Case CurToken.Kind Of
    (* Litteraux numeriques et chaines *)
    TK_INTEGER, TK_FLOAT, TK_STRING :
    Begin
      T := CurToken;
      ParserAdvance;
      LitEval(T, Res);
    End;

    (* . (valeur manquante) *)
    TK_PUNCT :
    Begin
      If CurToken.Val = '.' Then
      Begin
        ParserAdvance;
        ExprMakeMissing(Res);
      End
      Else If CurToken.Val = '(' Then
      Begin
        (* Groupement parenthese *)
        ParserAdvance;
        ParseExprPrec(1, Res);
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance
        Else
          CompileError(''')'' manquant');
      End
      Else
      Begin
        CompileError('expression attendue, token inattendu : ' + CurToken.Val);
        ParserAdvance;
      End;
    End;

    (* Identificateur : variable ou appel de fonction *)
    TK_IDENT, TK_KEYWORD :
    Begin
      (* Pour l instant, stub : les variables seront gerees au TODO 05/09 *)
      (* On consomme l identificateur et on retourne une valeur stub *)
      T := CurToken;
      ParserAdvance;
      (* Verifier si c est un appel de fonction (suivi de parenthese) *)
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
      Begin
        (* Stub appel de fonction : sera gere au TODO 16 *)
        WarnMsg('appel de fonction ' + T.Val + '() : stub (TODO 16)');
        ParserAdvance;  (* consommer ( *)
        (* Lire et ignorer les arguments jusqu a ) *)
        While (CurToken.Kind <> TK_EOF) And
              Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Do
          ParserAdvance;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        ExprMakeImm(0, TY_IDX_NUMERIC, Res);
        Res.Kind := EK_AX;
      End
      Else
      Begin
        (* Variable simple : stub pour l instant *)
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_NUMERIC;
        Res.Offset  := 0;
        Res.SymIdx  := -1;
      End;
    End;

    (* Macro-variable &var *)
    TK_AMPERSAND :
    Begin
      WarnMsg('macro-variable : stub (TODO 21)');
      ParserAdvance;
      ExprMakeImm(0, TY_IDX_NUMERIC, Res);
    End;

  Else
    CompileError('expression attendue, token inattendu : ' + CurToken.Val);
    ParserAdvance;
  End;
End;

(* ---- ParseUnary : operateurs unaires SAS -------------------- *)
(* Gere : + (identite), - (negation), NOT / ^ / ~ (negation log) *)
Procedure ParseUnary(Var Res : TExprVal);
Var
  Op      : TString;
  LblSkip : TString;
Begin
  (* + - unaire *)
  If (CurToken.Kind = TK_OP) And
     ((CurToken.Val = '+') Or (CurToken.Val = '-')) Then
  Begin
    Op := CurToken.Val;
    ParserAdvance;
    ParseUnary(Res);  (* recursion pour -(-x) etc. *)
    If Op = '-' Then
    Begin
      If Res.Kind = EK_IMM Then
        Res.ImmVal := -Res.ImmVal
      Else
      Begin
        ExprFlushToAX(Res);
        EmitInstrA('NEG', 'AX');
        Res.Kind := EK_AX;
      End;
    End;
    (* Op = '+' : pas d action *)
    Exit;
  End;

  (* NOT / ^ / ~ : negation logique *)
  If ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'NOT')) Or
     ((CurToken.Kind = TK_OP) And (CurToken.Val = 'NOT')) Then
  Begin
    ParserAdvance;
    ParseUnary(Res);
    If Res.Kind = EK_IMM Then
    Begin
      If Res.ImmVal = 0 Then
        Res.ImmVal := 1
      Else
        Res.ImmVal := 0;
    End
    Else
    Begin
      ExprFlushToAX(Res);
      (* NOT logique : AX<>0 -> 0, AX=0 -> 1 *)
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrAB('MOV', 'AX', '0');
      LblSkip := LabelGen;
      EmitInstrA('JNZ', LblSkip);
      EmitInstrAB('MOV', 'AX', '1');
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_NUMERIC;
    End;
    Exit;
  End;

  (* Pas d operateur unaire : appeler ParsePrimary *)
  ParsePrimary(Res);
End;

(* ---- ParseExprPrec : boucle Pratt complete ------------------- *)
(* MinPrec = niveau de precedence minimal a capturer.             *)
(* Gere le court-circuit pour AND et OR.                          *)
(* AX = gauche, BX = droite pour emission binaire.                *)
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op       : TString;
  Prec     : Integer;
  NextPrec : Integer;
  Right    : TExprVal;
  LblSkip  : TString;
Begin
  ParseUnary(Res);

  Repeat
    Op   := '';
    Prec := 0;

    (* Detecter operateur binaire *)
    If CurToken.Kind = TK_OP Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End
    (* Mots-cles operateurs : AND OR NOT EQ NE LT LE GT GE IN *)
    Else If (CurToken.Kind = TK_KEYWORD) And
            ((CurToken.Val = 'AND') Or (CurToken.Val = 'OR') Or
             (CurToken.Val = 'EQ')  Or (CurToken.Val = 'NE') Or
             (CurToken.Val = 'LT')  Or (CurToken.Val = 'LE') Or
             (CurToken.Val = 'GT')  Or (CurToken.Val = 'GE') Or
             (CurToken.Val = 'IN')) Then
    Begin
      Op   := CurToken.Val;
      Prec := BinOpPrec(Op);
    End;

    (* Fin de la boucle si pas d operateur ou precedence insuffisante *)
    If (Prec = 0) Or (Prec < MinPrec) Then Break;

    (* Consommer l operateur *)
    ParserAdvance;

    (* Calculer la precedence pour le cote droit *)
    If BinOpIsRight(Op) Then
      NextPrec := Prec      (* droit-associatif : meme precedence *)
    Else
      NextPrec := Prec + 1; (* gauche-associatif : precedence + 1 *)

    (* Court-circuit AND : si gauche=0, sauter le cote droit *)
    If (Op = 'AND') Or (Op = '&') Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JZ', LblSkip);
      ParseExprPrec(NextPrec, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_NUMERIC;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Court-circuit OR : si gauche<>0, sauter le cote droit *)
    If (Op = 'OR') Or (Op = '|') Then
    Begin
      ExprFlushToAX(Res);
      LblSkip := LabelGen;
      EmitInstrAB('TEST', 'AX', 'AX');
      EmitInstrA('JNZ', LblSkip);
      ParseExprPrec(NextPrec, Right);
      ExprFlushToAX(Right);
      EmitLabel(LblSkip);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_NUMERIC;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Pliage de constantes pour operateurs arithmetiques simples *)
    If (Res.Kind = EK_IMM) Then
    Begin
      ParseExprPrec(NextPrec, Right);
      If Right.Kind = EK_IMM Then
      Begin
        (* Pliage de constantes *)
        If Op = '+' Then
          Res.ImmVal := Res.ImmVal + Right.ImmVal
        Else If Op = '-' Then
          Res.ImmVal := Res.ImmVal - Right.ImmVal
        Else If Op = '*' Then
          Res.ImmVal := Res.ImmVal * Right.ImmVal
        Else If (Op = '/') And (Right.ImmVal <> 0) Then
          Res.ImmVal := Res.ImmVal Div Right.ImmVal
        Else If (Op = '=') Or (Op = 'EQ') Then
        Begin If Res.ImmVal = Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If (Op = '^=') Or (Op = 'NE') Then
        Begin If Res.ImmVal <> Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If (Op = '<') Or (Op = 'LT') Then
        Begin If Res.ImmVal < Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If (Op = '<=') Or (Op = 'LE') Then
        Begin If Res.ImmVal <= Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If (Op = '>') Or (Op = 'GT') Then
        Begin If Res.ImmVal > Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If (Op = '>=') Or (Op = 'GE') Then
        Begin If Res.ImmVal >= Right.ImmVal Then Res.ImmVal := 1 Else Res.ImmVal := 0; End
        Else If Op = '<>' Then
        Begin If Res.ImmVal < Right.ImmVal Then (* min *) Else Res.ImmVal := Right.ImmVal; End
        Else If Op = '><' Then
        Begin If Res.ImmVal > Right.ImmVal Then (* max *) Else Res.ImmVal := Right.ImmVal; End
        Else
        Begin
          (* Non-pliable : emettre le code *)
          ExprFlushToAX(Res);
          EmitInstrA('PUSH', 'AX');
          ExprFlushToAX(Right);
          EmitInstrAB('MOV', 'BX', 'AX');
          EmitInstrA('POP', 'AX');
          EmitBinOp(Op, Res.TypeIdx, Right.TypeIdx);
          Res.Kind    := EK_AX;
          Res.SymIdx  := -1;
        End;
        Continue;
      End;
      (* Droite non-constante : emettre le code *)
      ExprFlushToAX(Res);
      EmitInstrA('PUSH', 'AX');
      ExprFlushToAX(Right);
      EmitInstrAB('MOV', 'BX', 'AX');
      EmitInstrA('POP', 'AX');
      EmitBinOp(Op, Res.TypeIdx, Right.TypeIdx);
      Res.Kind    := EK_AX;
      Res.SymIdx  := -1;
      Continue;
    End;

    (* Cas general : emettre le code pour les deux cotes *)
    ExprFlushToAX(Res);
    EmitInstrA('PUSH', 'AX');
    ParseExprPrec(NextPrec, Right);
    ExprFlushToAX(Right);
    EmitInstrAB('MOV', 'BX', 'AX');
    EmitInstrA('POP', 'AX');
    EmitBinOp(Op, Res.TypeIdx, Right.TypeIdx);
    Res.Kind    := EK_AX;
    Res.SymIdx  := -1;
  Until False;
End;

(* ---- ParseExpr : point d entree pour parser une expression --- *)
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES [IMPLEMENTE]
  ============================================================ }

(* ---- SymNameClean : nettoyer un nom pour nommage ASM -------- *)
(* Remplace les caracteres non alphanumeriques par '_'.           *)
(* SAS est insensible a la casse : le nom est deja en majuscules. *)
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := '';
  For I := 1 To Length(Name) Do
  Begin
    If IsIdentCont(Name[I]) Then
    Begin
      If Length(S) < MAX_STR Then S := S + Name[I];
    End
    Else
    Begin
      If Length(S) < MAX_STR Then S := S + '_';
    End;
  End;
  If S = '' Then S := '_anon';
  SymNameClean := S;
End;

(* ---- SymMangle : generer un label ASM depuis un symbole ----- *)
(* Le prefixe depend de la categorie du symbole.                  *)
(*   SC_VAR      -> _SASV_  (variable dans le PDV)                *)
(*   SC_ARRAY    -> _SASV_  (tableau = variable aussi)            *)
(*   SC_FORMAT   -> _SASF_  (format utilisateur)                  *)
(*   SC_INFORMAT -> _SASF_  (informat)                            *)
(*   SC_LABEL    -> _SASL_  (label de saut)                       *)
(*   SC_MACRO    -> _SASM_  (macro)                               *)
(*   SC_MACROVAR -> _SASM_  (macro-variable)                      *)
(*   SC_DATASET  -> _SASD_  (dataset)                             *)
(*   SC_PROC     -> _SASP_  (procedure SAS)                       *)
Function SymMangle(Const Name : TString; Cat : TSymCat) : TString;
Var
  Pfx   : TString;
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Cat Of
    SC_VAR      : Pfx := SAS_VAR_PFX;
    SC_ARRAY    : Pfx := SAS_VAR_PFX;
    SC_FORMAT   : Pfx := SAS_FMT_PFX;
    SC_INFORMAT : Pfx := SAS_FMT_PFX;
    SC_LABEL    : Pfx := SAS_LBL_PFX;
    SC_MACRO    : Pfx := SAS_MAC_PFX;
    SC_MACROVAR : Pfx := SAS_MAC_PFX;
    SC_DATASET  : Pfx := SAS_DS_PFX;
    SC_PROC     : Pfx := SAS_PROC_PFX;
  Else
    Pfx := SAS_VAR_PFX;
  End;
  SymMangle := Pfx + Clean;
End;

(* ---- SymFind : chercher un symbole par nom ------------------- *)
(* Parcourt la table du plus recent au plus ancien.                *)
(* SAS est insensible a la casse : la comparaison est en           *)
(* majuscules (les noms sont stockes en majuscules).               *)
(* Retourne l indice (0-base) ou -1 si non trouve.                 *)
Function SymFind(Const Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If SymTab[I].Name = Up Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;

(* ---- SymFindInScope : chercher un symbole dans un scope ----- *)
(* Retourne l indice (0-base) ou -1 si non trouve.                *)
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Up) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;

(* ---- SymAdd : ajouter un symbole dans la table -------------- *)
(* Retourne l indice du symbole (0-base) ou -1 si table pleine.   *)
(* Le nom est converti en majuscules (SAS insensible a la casse). *)
Function SymAdd(Const AName : TString; ACat : TSymCat;
                ATypeIdx : Integer; AOffset : Integer) : Integer;
Var
  Idx : Integer;
  Up  : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' + IntToStr(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Up  := StrUpperCase(AName);
  Idx := SymCount;
  SymTab[Idx].Name        := Up;
  SymTab[Idx].MangledName := SymMangle(Up, ACat);
  SymTab[Idx].Cat         := ACat;
  SymTab[Idx].TypeIdx     := ATypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := AOffset;
  SymTab[Idx].VarLen      := 0;
  SymTab[Idx].IsRetained  := False;
  SymTab[Idx].IsDropped   := False;
  SymTab[Idx].IsKept      := False;
  SymTab[Idx].DeclLine    := CurToken.Line;
  Inc(SymCount);
  Inc(TotalSyms);

  If Opts.DebugMode Then
    WriteLn('  SYM_ADD[', Idx, ']: ', Up,
            ' cat=', Ord(ACat),
            ' scope=', CurScope,
            ' -> ', SymTab[Idx].MangledName);

  SymAdd := Idx;
End;

(* ---- SymEnterScope : entrer dans une nouvelle portee --------- *)
(* Sauvegarde le SymCount courant sur la pile de portees.          *)
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
  Begin
    CompileError('profondeur de portee maximale atteinte (max='
                 + IntToStr(MAX_SCOPE) + ')');
    Exit;
  End;
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_ENTER: level=', CurScope);
End;

(* ---- SymLeaveScope : quitter la portee courante -------------- *)
(* Retire tous les symboles ajoutes dans cette portee.             *)
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then Exit;
  Dec(ScopeTop);
  SymCount := ScopeStack[ScopeTop];
  Dec(CurScope);
  If Opts.DebugMode Then
    WriteLn('  SCOPE_LEAVE: level=', CurScope);
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES [IMPLEMENTE]
  ============================================================ }

(* ---- TypeKindOf : retourner le TTypeKind d un indice de type -- *)
Function TypeKindOf(TypeIdx : Integer) : TTypeKind;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindOf := TypeTab[TypeIdx].Kind
  Else
    TypeKindOf := TYK_UNKNOWN;
End;

(* ---- TypeSizeof : taille en octets d un type par son indice --- *)
(* NUMERIC=2 (entier 16 bits), CHARACTER=longueur (defaut 8),     *)
(* DATE/TIME/DATETIME=2 (entier 16 bits).                         *)
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  (* taille par defaut : word *)
End;

(* ---- TypeMangle : prefixe ASM selon le type pour les labels --- *)
(* Utilise pour generer des labels distincts par type :            *)
(*   _SASN_ = numerique, _SASC_ = caractere, _SASD_ = date,      *)
(*   _SAST_ = time, _SASDT_ = datetime, _SASX_ = inconnu         *)
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeKindOf(TypeIdx) Of
    TYK_NUMERIC   : TypeMangle := '_SASN_';
    TYK_CHARACTER : TypeMangle := '_SASC_';
    TYK_DATE      : TypeMangle := '_SASD_';
    TYK_TIME      : TypeMangle := '_SAST_';
    TYK_DATETIME  : TypeMangle := '_SASDT_';
  Else
    TypeMangle := '_SASX_';
  End;
End;

(* ---- TypeIsNumeric : vrai si le type est un type numerique ---- *)
(* En SAS : NUMERIC, DATE, TIME, DATETIME sont tous numeriques.   *)
(* Les dates/times sont stockes comme des entiers.                 *)
Function TypeIsNumeric(TypeIdx : Integer) : Boolean;
Var
  K : TTypeKind;
Begin
  K := TypeKindOf(TypeIdx);
  TypeIsNumeric :=
    (K = TYK_NUMERIC) Or (K = TYK_DATE) Or
    (K = TYK_TIME)    Or (K = TYK_DATETIME);
End;

(* ---- TypeIsPtr : vrai si le type est un pointeur -------------- *)
(* En SAS, seul CHARACTER est un pointeur (adresse vers chaine).   *)
Function TypeIsPtr(TypeIdx : Integer) : Boolean;
Begin
  TypeIsPtr := (TypeKindOf(TypeIdx) = TYK_CHARACTER);
End;

(* ---- TypeCanCoerce : la coercition src -> dst est-elle possible *)
(* En SAS, la conversion implicite est tolerante :                 *)
(*   num -> char via PUT() (runtime), char -> num via INPUT()      *)
(*   Meme type -> toujours OK.                                     *)
(*   Vers UNKNOWN -> toujours OK (perte d information de type).    *)
(*   date/time/datetime <-> numeric -> OK (memes octets).          *)
(*   numeric <-> character -> conversion implicite avec warning.   *)
Function TypeCanCoerce(SrcIdx, DstIdx : Integer) : Boolean;
Var
  SK, DK : TTypeKind;
Begin
  (* Meme type : trivial *)
  If SrcIdx = DstIdx Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* Vers UNKNOWN : toujours OK *)
  If DstIdx = TY_UNKNOWN Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  SK := TypeKindOf(SrcIdx);
  DK := TypeKindOf(DstIdx);
  (* Tous les numeriques (num/date/time/datetime) entre eux : OK *)
  If TypeIsNumeric(SrcIdx) And TypeIsNumeric(DstIdx) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* Numerique <-> Caractere : conversion implicite SAS (PUT/INPUT) *)
  If (TypeIsNumeric(SrcIdx) And (DK = TYK_CHARACTER)) Or
     ((SK = TYK_CHARACTER) And TypeIsNumeric(DstIdx)) Then
  Begin
    TypeCanCoerce := True;
    Exit;
  End;
  (* Autres cas : pas de coercition *)
  TypeCanCoerce := False;
End;

(* ---- TypeCoerceResult : type du resultat d une operation ------- *)
(* Deduit le type du resultat en fonction de l operateur et des     *)
(* types des operandes.                                             *)
(*   Comparaison (= ^= < > etc.) -> NUMERIC (0 ou 1)               *)
(*   AND, OR                     -> NUMERIC (booleen)               *)
(*   Arithmetiques : + - * / puissance -> NUMERIC                   *)
(*   Concatenation (|| !!)       -> CHARACTER                       *)
(*   MIN/MAX (<> ><)             -> NUMERIC                         *)
Function TypeCoerceResult(LeftIdx, RightIdx : Integer;
                          Const Op : TString) : Integer;
Var
  LK, RK : TTypeKind;
Begin
  LK := TypeKindOf(LeftIdx);
  RK := TypeKindOf(RightIdx);
  (* Operateurs de comparaison -> NUMERIC (0 ou 1) *)
  If (Op = '=') Or (Op = '^=') Or (Op = '~=') Or
     (Op = '<') Or (Op = '<=') Or
     (Op = '>') Or (Op = '>=') Or
     (Op = 'EQ') Or (Op = 'NE') Or
     (Op = 'LT') Or (Op = 'LE') Or
     (Op = 'GT') Or (Op = 'GE') Or
     (Op = 'IN') Then
  Begin
    TypeCoerceResult := TY_IDX_NUMERIC;
    Exit;
  End;
  (* Operateurs logiques -> NUMERIC (0 ou 1) *)
  If (Op = 'AND') Or (Op = 'OR') Then
  Begin
    TypeCoerceResult := TY_IDX_NUMERIC;
    Exit;
  End;
  (* Concatenation -> CHARACTER *)
  If (Op = '||') Or (Op = '!!') Then
  Begin
    TypeCoerceResult := TY_IDX_CHARACTER;
    Exit;
  End;
  (* MIN/MAX -> NUMERIC *)
  If (Op = '<>') Or (Op = '><') Then
  Begin
    TypeCoerceResult := TY_IDX_NUMERIC;
    Exit;
  End;
  (* Operateurs arithmetiques -> NUMERIC *)
  If (Op = '+') Or (Op = '-') Or (Op = '*') Or
     (Op = '/') Or (Op = '**') Then
  Begin
    (* Si un cote est CHARACTER, SAS convertit implicitement en num *)
    TypeCoerceResult := TY_IDX_NUMERIC;
    Exit;
  End;
  (* Assignation : type du cote droit *)
  TypeCoerceResult := RightIdx;
End;

(* ---- TypeInfer : deduire le type d une expression ------------- *)
(* Si le TypeIdx de l expression est connu, le retourner.          *)
(* Sinon, deviner : EK_IMM -> NUMERIC, EK_MEM -> selon contexte.  *)
Function TypeInfer(Const E : TExprVal) : Integer;
Begin
  If E.TypeIdx <> TY_UNKNOWN Then
    TypeInfer := E.TypeIdx
  Else If E.Kind = EK_IMM Then
    TypeInfer := TY_IDX_NUMERIC
  Else
    TypeInfer := TY_UNKNOWN;
End;

(* ---- TypeLookupName : chercher un type par nom ---------------- *)
(* SAS est insensible a la casse : comparaison en majuscules.      *)
(* Retourne l indice dans TypeTab ou TY_UNKNOWN si non trouve.     *)
Function TypeLookupName(Const Name : TString) : Integer;
Var
  I  : Integer;
  Up : TString;
Begin
  Up := StrUpperCase(Name);
  For I := 0 To TypeCount - 1 Do
    If TypeTab[I].Name = Up Then
    Begin
      TypeLookupName := I;
      Exit;
    End;
  TypeLookupName := TY_UNKNOWN;
End;

{ ============================================================
  STUBS POUR TODO 08..25 (a implementer)
  ============================================================ }

Procedure ParseStmt;
Begin
  (* stub : consomme un token pour eviter boucle infinie *)
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

Procedure ParserAdvance;
Begin
  LexNextToken;
  If Opts.DebugMode Then
    PrintToken(CurToken);
End;

Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelGenSeq);
  Str(LabelGenSeq, S);
  LabelGen := SAS_LBL_PFX + S;
End;

Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

Procedure EmitBlankLine;
Begin
  If OutFOpen Then
    WriteLn(OutF);
End;

Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;

Procedure EmitInstr(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

Procedure EmitInstrA(Const Mnem, A1 : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A1);
End;

Procedure EmitInstrAB(Const Mnem, A1, A2 : TString);
Begin
  EmitRaw('        ' + Mnem + ' ' + A1 + ', ' + A2);
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + Opts.OutFile);
  OutFOpen := True;
End;

Procedure EmitHeader;
Begin
  EmitComment('SAS86 v' + SAS86_VERSION + ' - ' + Opts.SrcFile);
  EmitRaw('.MODEL SMALL');
  EmitRaw('.STACK ' + IntToStr(STACK_SIZE));
  EmitBlankLine;
  EmitRaw('_TEXT SEGMENT PUBLIC ''CODE''');
  EmitRaw('        ASSUME CS:_TEXT, DS:_DATA, SS:STACK');
  EmitBlankLine;
  (* Point d entree principal *)
  EmitLabel(SAS_PROC_PFX + 'Main');
  EmitProlog;
  (* Initialiser DS *)
  EmitInstrAB('MOV', 'AX', '_DATA');
  EmitInstrAB('MOV', 'DS', 'AX');
  EmitBlankLine;
End;

Procedure EmitProlog;
Begin
  EmitInstrA('PUSH', 'BP');
  EmitInstrAB('MOV', 'BP', 'SP');
End;

Procedure EmitEpilog;
Begin
  EmitInstrAB('MOV', 'SP', 'BP');
  EmitInstrA('POP', 'BP');
End;

Procedure EmitDataSeg;
Var
  I, J : Integer;
  S    : TString;
Begin
  EmitRaw('_DATA SEGMENT PUBLIC ''DATA''');
  EmitBlankLine;
  (* Constante sentinelle valeur manquante *)
  EmitComment('Valeur manquante SAS (.)');
  EmitRaw('_SAS_MISSING  DW  8000h');
  EmitBlankLine;
  (* Emettre les entrees DataTab *)
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD :
        EmitRaw(DataTab[I].LblName + '  DW  ' +
                IntToStr(DataTab[I].IntVal));
      DK_BYTE :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].IntVal));
      DK_STR :
      Begin
        (* Doubler les apostrophes pour syntaxe MASM *)
        S := '';
        For J := 1 To Length(DataTab[I].StrVal) Do
        Begin
          If DataTab[I].StrVal[J] = '''' Then
            S := S + ''''''
          Else
            S := S + DataTab[I].StrVal[J];
        End;
        EmitRaw(DataTab[I].LblName + '  DB  ''' + S + ''',0');
      End;
      DK_ARRAY_BLK :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
      DK_RECORD_BLK :
        EmitRaw(DataTab[I].LblName + '  DB  ' +
                IntToStr(DataTab[I].ElemCount) + ' DUP(0)');
    End;
  End;
  EmitBlankLine;
  EmitRaw('_DATA ENDS');
End;

Procedure EmitRuntime;
Begin
  If RuntimeEmitted Then Exit;
  RuntimeEmitted := True;
  EmitBlankLine;
  EmitComment('--- Runtime minimal SAS86 ---');
  (* TODO 24 : emettre les routines runtime ici *)
  EmitBlankLine;
End;

Procedure EmitClose;
Begin
  EmitBlankLine;
  EmitComment('--- Fin du code ---');
  EmitEpilog;
  (* Terminaison DOS *)
  EmitInstrAB('MOV', 'AX', '4C00h');
  EmitInstr('INT 21h');
  EmitBlankLine;
  EmitRuntime;
  EmitRaw('_TEXT ENDS');
  EmitBlankLine;
  EmitDataSeg;
  EmitBlankLine;
  EmitRaw('END ' + SAS_PROC_PFX + 'Main');
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

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
  (* Types primitifs SAS *)
  TypeTab[TY_IDX_NUMERIC].Name   := 'NUMERIC';
  TypeTab[TY_IDX_NUMERIC].Kind   := TYK_NUMERIC;
  TypeTab[TY_IDX_NUMERIC].Size   := 2;
  TypeTab[TY_IDX_CHARACTER].Name := 'CHARACTER';
  TypeTab[TY_IDX_CHARACTER].Kind := TYK_CHARACTER;
  TypeTab[TY_IDX_CHARACTER].Size := 8;  (* longueur par defaut en SAS *)
  TypeTab[TY_IDX_DATE].Name      := 'DATE';
  TypeTab[TY_IDX_DATE].Kind      := TYK_DATE;
  TypeTab[TY_IDX_DATE].Size      := 2;
  TypeTab[TY_IDX_TIME].Name      := 'TIME';
  TypeTab[TY_IDX_TIME].Kind      := TYK_TIME;
  TypeTab[TY_IDX_TIME].Size      := 2;
  TypeTab[TY_IDX_DATETIME].Name  := 'DATETIME';
  TypeTab[TY_IDX_DATETIME].Kind  := TYK_DATETIME;
  TypeTab[TY_IDX_DATETIME].Size  := 2;
  TypeCount := TY_PRIM_COUNT;
End;

Procedure SymInit;
Begin
  SymCount := 0;
  ScopeTop := 0;
  CurScope := 0;
  (* Variables automatiques SAS : creees dans chaque DATA step *)
  (* _N_      : compteur d observation (1, 2, 3, ...)          *)
  (* _ERROR_  : indicateur d erreur (0 = pas d erreur)         *)
  (* _INFILE_ : nom du fichier en cours de lecture              *)
  (* _LAST_   : derniere observation lue                        *)
  SymAdd('_N_',      SC_VAR, TY_IDX_NUMERIC, 0);
  SymAdd('_ERROR_',  SC_VAR, TY_IDX_NUMERIC, 0);
  SymAdd('_INFILE_', SC_VAR, TY_IDX_CHARACTER, 0);
  SymAdd('_LAST_',   SC_VAR, TY_IDX_NUMERIC, 0);
End;

{ ============================================================
  PROCEDURE RUN : PIPELINE COMPLET
  ============================================================ }

Procedure Run;
Begin
  GlobalInit;
  TypeInit;
  SymInit;
  EmitOpen;
  If ErrorCount > 0 Then
  Begin
    Cleanup;
    Halt(EXIT_ERROR);
  End;

  EmitHeader;
  LexInit;

  (* Lire le premier token *)
  ParserAdvance;

  (* Boucle principale de compilation *)
  While CurToken.Kind <> TK_EOF Do
    ParseStmt;

  LexClose;
  EmitClose;

  If Opts.Verbose Then
  Begin
    WriteLn('Compilation terminee : ', Opts.SrcFile, ' -> ', Opts.OutFile);
    WriteLn('  Lignes         : ', TotalLines);
    WriteLn('  Symboles       : ', TotalSyms);
    WriteLn('  Erreurs        : ', ErrorCount);
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
  If (ParamCount >= 1) And
     ((ParamStr(1) = '-h') Or (ParamStr(1) = '--help') Or
      (ParamStr(1) = '/?') Or (ParamStr(1) = '/h') Or
      (ParamStr(1) = '/H')) Then
  Begin
    ShowHelp;
    Halt(0);
  End;
  ParseArgs;
  If Opts.Verbose Then ShowBanner;
  Run;
End.
