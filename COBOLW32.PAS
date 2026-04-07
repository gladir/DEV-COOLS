{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur COBOL vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  COBOLW32.PAS - Compilateur COBOL vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les exemples SAMPLES\COBOL\*

  Voir DOC/TODO/COBOLW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, FreeFormat)
            ParseArgs : analyser argv (source.cbl [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-free] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            -free : activer le format libre (colonnes non fixes)
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .cbl ou .cob du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=4096, MAX_SEC=64,
              MAX_LOCAL=256, MAX_PARAM=64, MAX_DEPTH=32,
              MAX_LABEL=4096, MAX_STR=255, MAX_FIELD=128,
              MAX_FILE=16, MAX_TABLE=128, MAX_LEVEL=49,
              MAX_PIC=64, MAX_PERFORM=256
            Prefixes de nommage ASM : _COB_ (variable globale),
              _COBP_ (paragraphe/section PROCEDURE),
              _COBK_ (constante chaine),
              _COBRT_ (routine runtime), _COBL_ (label interne),
              _COBT_ (table/tableau), _COBF_ (champ de fichier),
              _COBS_ (section), _COBE_ (entree fichier)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - TOKENISEUR COBOL (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Format fixe (standard COBOL) :
              Colonnes 1-6 : numero de sequence (ignore)
              Colonne 7 : indicateur (* commentaire, - continuation,
                D debug, / saut de page)
              Colonnes 8-11 : zone A (DIVISION, SECTION, niveaux 01/77,
                noms de paragraphes)
              Colonnes 12-72 : zone B (instructions, clauses)
              Colonnes 73-80 : zone de commentaire (ignore)
            Support du format libre (-free) :
              Pas de colonnes fixes, commentaires avec *>
            Procedure LexNextToken : reconnaitre les tokens COBOL :
              - Identificateurs : lettres, chiffres, tiret (-)
                COBOL est insensible a la casse
                Tiret permis sauf en debut/fin (WS-NOM, EMP-SALAIRE)
              - Litteraux numeriques : 123, 1.5, +5, -3
              - Litteraux chaines : 'texte' ou "texte"
              - Litteraux hexadecimaux : X'FF' ou X"FF"
              - Symboles : . (terminateur d instruction)
              - Operateurs : + - * / ** = > < >= <= <>
              - Separateurs : ( ) ,
              - Commentaires : * en colonne 7, *> en format libre
              - Continuation : - en colonne 7
            Types de tokens (TOK_IDENT, TOK_INTEGER, TOK_DECIMAL,
              TOK_STRING, TOK_HEX_STRING,
              TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH, TOK_POWER,
              TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_DOT,
              TOK_EQ, TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE,
              TOK_NEWLINE, TOK_EOF)
            Stocker dans CurTokType / CurTokStr / CurTokNum
            Reconnaitre le point (.) comme terminateur d instruction
            Gestion des continuations de ligne (- en colonne 7)
            10 fonctions accesseurs

  TODO 03 - RECONNAISSANCE DES MOTS-CLES COBOL [IMPLEMENTE]
            Tous les mots reserves COBOL-85 :
              DIVISIONS : IDENTIFICATION, ENVIRONMENT, DATA, PROCEDURE
              SECTIONS : CONFIGURATION, INPUT-OUTPUT, FILE-CONTROL,
                FILE, WORKING-STORAGE, LINKAGE, SCREEN, REPORT
              Paragraphes ID : PROGRAM-ID, AUTHOR, INSTALLATION,
                DATE-WRITTEN, DATE-COMPILED, SECURITY
              Paragraphes ENV : SOURCE-COMPUTER, OBJECT-COMPUTER,
                SPECIAL-NAMES, REPOSITORY
              Instructions : ACCEPT, ADD, CALL, CLOSE, COMPUTE,
                CONTINUE, DELETE, DISPLAY, DIVIDE, EVALUATE,
                EXIT, GO, GOBACK, IF, INITIALIZE, INSPECT,
                MERGE, MOVE, MULTIPLY, OPEN, PERFORM, READ,
                RELEASE, RETURN, REWRITE, SEARCH, SET, SORT,
                START, STOP, STRING, SUBTRACT, UNSTRING, WRITE
              Clauses DATA : PIC, PICTURE, VALUE, USAGE, OCCURS,
                REDEFINES, RENAMES, FILLER, BLANK, JUSTIFIED,
                SIGN, SYNCHRONIZED, COMP, COMP-1, COMP-2, COMP-3,
                BINARY, PACKED-DECIMAL, DISPLAY, INDEX
              Clauses FILE : SELECT, ASSIGN, ORGANIZATION,
                ACCESS, FILE STATUS, RECORD, LABEL, FD, SD
              Structures : IF/ELSE/END-IF, EVALUATE/WHEN/END-EVALUATE,
                PERFORM/END-PERFORM, READ/END-READ, SEARCH/END-SEARCH,
                STRING/END-STRING, UNSTRING/END-UNSTRING,
                COMPUTE/END-COMPUTE, ADD/END-ADD, SUBTRACT/END-SUBTRACT,
                MULTIPLY/END-MULTIPLY, DIVIDE/END-DIVIDE
              Conditions : AND, OR, NOT, EQUAL, GREATER, LESS,
                NUMERIC, ALPHABETIC, POSITIVE, NEGATIVE, ZERO,
                SPACES, HIGH-VALUES, LOW-VALUES
              Divers : THRU, THROUGH, TIMES, UNTIL, VARYING,
                GIVING, REMAINDER, ROUNDED, SIZE, ON, INTO, FROM,
                TO, BY, IS, ARE, OF, IN, THAN, WHEN, ALSO,
                WITH, ADVANCING, BEFORE, AFTER, ALL, LEADING,
                TRAILING, FIRST, INITIAL, CORRESPONDING
              Niveaux speciaux : 01, 66, 77, 88
            Fonction LookupKeyword : retourner KW_xxx ou TOK_IDENT
            Les mots-cles composes avec tiret (END-IF, WORKING-STORAGE)
              sont traites comme un seul token
            10 fonctions accesseurs

  TODO 04 - TABLE DES SYMBOLES COBOL (32 BITS) [IMPLEMENTE]
            Enregistrement TSymbol :
              Name      : nom COBOL (WS-NOM, EMP-RECORD)
              AsmName   : label ASM correspondant (_COB_WS_NOM)
              Level     : niveau hierarchique (01-49, 66, 77, 88)
              SymType   : type de donnee (CBT_ALPHA, CBT_NUMERIC,
                CBT_ALPHANUMERIC, CBT_PACKED, CBT_BINARY, CBT_INDEX,
                CBT_POINTER, CBT_GROUP, CBT_FILE, CBT_CONDITION)
              PicStr    : chaine PICTURE originale (X(20), 9(3)V99)
              PicSize   : taille en octets apres analyse du PICTURE
              PicDecimals : nombre de decimales (V dans PIC)
              IsSigned  : PIC S9(...) - signe present
              IsGroup   : True si niveau de groupe (pas de PIC)
              ParentIdx : index du symbole parent (groupe contenant)
              Offset    : offset dans le groupe/record parent
              Value     : valeur initiale (clause VALUE)
              IsGlobal  : portee globale ou locale
              Section   : WORKING-STORAGE, FILE, LINKAGE, etc.
              Occurs    : nombre de repetitions (clause OCCURS)
              OccursMin : OCCURS min (DEPENDING ON)
              OccursDep : nom de la variable DEPENDING ON
              RedefinedIdx : index du symbole redefini (REDEFINES)
              CondValues : valeurs pour niveau 88 (VALUE clause)
              Usage     : DISPLAY, COMP, COMP-3, BINARY, INDEX
              IsExternal : clause EXTERNAL
              IsFiller  : True si FILLER
            Procedures sur la table :
              SymInit, SymAdd, SymFind, SymFindQualified,
              SymCount, SymDump
            Qualification : OF/IN pour lever ambiguite
              (EMP-NOM OF EMP-RECORD)
            10 fonctions accesseurs

  TODO 05 - GESTION DES NIVEAUX ET HIERARCHIE COBOL [IMPLEMENTE]
            Niveaux COBOL : 01-49 (hierarchie), 66 (RENAMES),
              77 (independant), 88 (condition)
            Construction de l arbre hierarchique :
              Niveau 01 : debut d un nouveau record/groupe
              Niveaux 02-49 : sous-champs du dernier groupe superieur
              Resolution automatique de la structure :
                01 EMP-RECORD.
                  05 EMP-NOM PIC X(30).
                  05 EMP-ADRESSE.
                    10 EMP-RUE PIC X(40).
                    10 EMP-VILLE PIC X(20).
              Calcul automatique des offsets et tailles
            Clause REDEFINES : partage de memoire
              01 WS-DATE PIC 9(8).
              01 WS-DATE-R REDEFINES WS-DATE.
                05 WS-ANNEE PIC 9(4).
                05 WS-MOIS  PIC 99.
                05 WS-JOUR  PIC 99.
            Clause RENAMES (niveau 66) : regroupement
            Niveaux 88 : conditions nommees
              88 STATUT-ACTIF VALUE 'A'.
              88 FINI VALUE 10.
              SET FINI TO TRUE -> MOVE 10 TO parent
            Verification des niveaux valides et coherents
            Calcul de la taille totale de chaque record 01
            10 fonctions accesseurs

  TODO 06 - PARSEUR : IDENTIFICATION DIVISION ET ENVIRONMENT DIVISION [IMPLEMENTE]
            IDENTIFICATION DIVISION (obligatoire) :
              PROGRAM-ID. nom [IS INITIAL PROGRAM].
              AUTHOR. texte (optionnel, commentaire)
              INSTALLATION. texte (optionnel)
              DATE-WRITTEN. texte (optionnel)
              DATE-COMPILED. texte (optionnel)
              SECURITY. texte (optionnel)
            ENVIRONMENT DIVISION (optionnelle) :
              CONFIGURATION SECTION :
                SOURCE-COMPUTER. nom.
                OBJECT-COMPUTER. nom.
                SPECIAL-NAMES.
                  DECIMAL-POINT IS COMMA.
                  (autres associations symboliques)
              INPUT-OUTPUT SECTION :
                FILE-CONTROL.
                  SELECT nom-fichier
                    ASSIGN TO nom-externe
                    ORGANIZATION IS SEQUENTIAL/INDEXED/RELATIVE
                    ACCESS MODE IS SEQUENTIAL/RANDOM/DYNAMIC
                    RECORD KEY IS nom-cle (pour INDEXED)
                    FILE STATUS IS nom-variable.
            Stocker les informations de configuration
            Stocker les descriptions de fichiers (SELECT/ASSIGN)
            Detecter DECIMAL-POINT IS COMMA pour les litteraux
            10 fonctions accesseurs

  TODO 07 - PARSEUR : DATA DIVISION (FILE SECTION, WORKING-STORAGE) [IMPLEMENTE]
            DATA DIVISION (optionnelle) :
              FILE SECTION :
                FD nom-fichier
                  LABEL RECORD IS STANDARD/OMITTED
                  RECORD CONTAINS n CHARACTERS
                  BLOCK CONTAINS n RECORDS
                  DATA RECORD IS nom-record.
                01 nom-record.
                  05 champs... (voir TODO 04)
                SD pour les fichiers de tri (SORT)
              WORKING-STORAGE SECTION :
                77 nom PIC ... VALUE ... (variables independantes)
                01 nom. (debut de groupe)
                  05 champs avec PIC, VALUE, USAGE, OCCURS
              LINKAGE SECTION :
                Parametres passes par CALL (meme format que WS)
            Analyse de la clause PICTURE :
              A : alphabetique (1 caractere)
              X : alphanumerique (1 caractere)
              9 : chiffre (1 caractere)
              V : point decimal implicite
              S : signe (premier caractere)
              P : mise a l echelle
              Z : zero supprime (edition)
              * : asterisque de protection (edition)
              , . / B 0 : insertion (edition)
              CR DB + - : signe (edition)
              Repetition : 9(5) = 99999, X(20), etc.
              Calcul de la taille en octets resultante
            Clause USAGE : DISPLAY (defaut), COMP/BINARY (entier binaire),
              COMP-1 (flottant simple), COMP-2 (flottant double),
              COMP-3/PACKED-DECIMAL (decimal condense), INDEX
            Clause VALUE : valeur initiale (litteraux, SPACES, ZEROS,
              HIGH-VALUES, LOW-VALUES)
            Clause OCCURS : tableaux (OCCURS n TIMES,
              OCCURS n TO m DEPENDING ON var)
            10 fonctions accesseurs

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET CONDITIONS [IMPLEMENTE]
            Expressions arithmetiques COBOL :
              Operateurs : + - * / ** (puissance)
              Parentheses pour regroupement
              Operandes : identificateurs, litteraux numeriques
              Qualification : nom OF groupe
              Reference de sous-chaine : nom(debut:longueur)
              Indexation de table : nom(indice) ou nom(idx1, idx2)
            Conditions :
              Comparaisons : = > < >= <= <> (ou NOT =, NOT >, etc.)
              Noms-condition (niveau 88) : IF STATUT-ACTIF
              Conditions de classe : NUMERIC, ALPHABETIC,
                ALPHABETIC-LOWER, ALPHABETIC-UPPER
              Conditions de signe : POSITIVE, NEGATIVE, ZERO
              Operateurs logiques : AND, OR, NOT
              Conditions combinees : IF A > B AND C < D
              Conditions abregees : IF A = 1 OR 2 OR 3
              Condition figurative : IF WS-NOM = SPACES
            Constantes figuratives COBOL :
              SPACE/SPACES, ZERO/ZEROS/ZEROES,
              HIGH-VALUE/HIGH-VALUES, LOW-VALUE/LOW-VALUES,
              QUOTE/QUOTES, ALL 'x'
            Evaluation des expressions avec priorite des operateurs
            Generation d un arbre d expression intermediaire
            10 fonctions accesseurs

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [IMPLEMENTE]
            Arithmetique sur donnees DISPLAY (PIC 9) :
              Conversion DISPLAY -> registre 32 bits (entier)
              Operation en registre (ADD, SUB, IMUL, IDIV)
              Reconversion registre -> DISPLAY
            Arithmetique sur donnees COMP/BINARY :
              Operations directes en 32 bits (DD)
              Gestion du signe (registre signe EAX)
            Arithmetique sur donnees COMP-3 (packed decimal) :
              Decompactage BCD -> binaire 32 bits
              Operation en registre
              Recompactage binaire -> BCD
            Instruction ADD :
              ADD id-1 TO id-2 [GIVING id-3] [ROUNDED]
              [ON SIZE ERROR inst] [NOT ON SIZE ERROR inst]
              [END-ADD]
            Instruction SUBTRACT :
              SUBTRACT id-1 FROM id-2 [GIVING id-3]
            Instruction MULTIPLY :
              MULTIPLY id-1 BY id-2 [GIVING id-3]
            Instruction DIVIDE :
              DIVIDE id-1 INTO/BY id-2 [GIVING id-3]
              [REMAINDER id-4]
            Instruction COMPUTE :
              COMPUTE id-1 [ROUNDED] = expression arithmetique
              Parsing complet de l expression avec priorite
              Evaluation sur la pile 80386
            Clause ROUNDED : arrondi au lieu de troncature
            Clause ON SIZE ERROR : debordement arithmetique
            10 fonctions accesseurs

  TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, EVALUATE) [IMPLEMENTE]
            IF condition THEN
              instructions...
            ELSE
              instructions...
            END-IF
              (ou point comme terminateur, forme ancienne)
            Conditions imbriquees : IF dans IF
            Conditions combinees : AND, OR, NOT
            EVALUATE (equivalent de switch/case) :
              EVALUATE identifiant/expression/TRUE/FALSE
                WHEN valeur/condition
                  instructions...
                WHEN valeur/condition
                  instructions...
                WHEN OTHER
                  instructions...
              END-EVALUATE
            EVALUATE avec sujets multiples :
              EVALUATE var-1 ALSO var-2
                WHEN val-1 ALSO val-2
            EVALUATE TRUE :
              WHEN condition-1 instructions...
              WHEN condition-2 instructions...
            Forme ancienne avec point (sans END-IF/END-EVALUATE)
              supportee pour compatibilite
            CONTINUE : instruction vide (no-op)
            Generation de JMP/Jcc conditionnel 80386
            Labels internes (_COBL_IF_xxx, _COBL_EVAL_xxx)
            10 fonctions accesseurs

  TODO 11 - PARSEUR : PERFORM ET BOUCLES [IMPLEMENTE]
            PERFORM simple :
              PERFORM nom-paragraphe
              PERFORM nom-paragraphe THRU nom-paragraphe-fin
            PERFORM inline :
              PERFORM instructions... END-PERFORM
            PERFORM TIMES :
              PERFORM nom-paragraphe n TIMES
              PERFORM n TIMES instructions... END-PERFORM
            PERFORM UNTIL :
              PERFORM nom-paragraphe UNTIL condition
              PERFORM UNTIL condition instructions... END-PERFORM
              WITH TEST BEFORE (defaut) ou WITH TEST AFTER
            PERFORM VARYING :
              PERFORM nom-paragraphe
                VARYING id-1 FROM val-1 BY val-2 UNTIL condition
                [AFTER id-2 FROM val-3 BY val-4 UNTIL condition-2]
            GO TO nom-paragraphe (branchement inconditionnel)
            GO TO nom-1 nom-2 ... DEPENDING ON id
              (branchement calcule)
            EXIT PARAGRAPH / EXIT SECTION
            GOBACK (retour au programme appelant)
            Generation de boucles 80386 avec CMP/JMP/LOOP
            Labels pour debut/fin de boucle et paragraphes
            10 fonctions accesseurs

  TODO 12 - PARSEUR : MOVE, INITIALIZE ET TRANSFERT DE DONNEES [IMPLEMENTE]
            MOVE :
              MOVE source TO dest-1 [dest-2 ...]
              MOVE CORRESPONDING groupe-1 TO groupe-2
              Regles de conversion COBOL :
                Alphanumerique -> Alphanumerique : cadrage a gauche,
                  troncature ou remplissage avec espaces
                Numerique -> Numerique : alignement sur le point
                  decimal, troncature ou zero-fill
                Numerique -> Alphanumerique : conversion en chaine
                Alphanumerique -> Numerique : conversion numerique
                Groupe -> Groupe : transfert alphanumerique
              Constantes figuratives : SPACES, ZEROS, HIGH-VALUES,
                LOW-VALUES, ALL 'x'
            INITIALIZE :
              INITIALIZE id-1 [id-2 ...]
                [REPLACING category BY literal/id]
              Mettre les champs alphanumeriques a SPACES
              Mettre les champs numeriques a ZEROS
            SET pour niveaux 88 :
              SET condition-88 TO TRUE
              -> MOVE valeur TO variable-parent
            Generation 80386 : MOV, REP MOVSB, STOSB pour les
              transferts memoire, routines runtime pour conversions
            10 fonctions accesseurs

  TODO 13 - PARSEUR : OPERATIONS SUR CHAINES (STRING, UNSTRING, INSPECT) [IMPLEMENTE]
            STRING :
              STRING source-1 [DELIMITED BY delim-1]
                     source-2 [DELIMITED BY delim-2]
                INTO destination
                [WITH POINTER ptr]
                [ON OVERFLOW instructions]
              END-STRING
            UNSTRING :
              UNSTRING source
                DELIMITED BY delim-1 [OR delim-2]
                INTO dest-1 [DELIMITER IN d-1] [COUNT IN c-1]
                     dest-2 [DELIMITER IN d-2] [COUNT IN c-2]
                [WITH POINTER ptr]
                [TALLYING IN compteur]
                [ON OVERFLOW instructions]
              END-UNSTRING
            INSPECT :
              INSPECT id TALLYING id-cnt
                FOR ALL/LEADING/CHARACTERS 'x'
                [BEFORE/AFTER INITIAL 'y']
              INSPECT id REPLACING
                ALL/LEADING/FIRST 'x' BY 'y'
                [BEFORE/AFTER INITIAL 'z']
              INSPECT id CONVERTING 'abc' TO 'xyz'
            Reference de sous-chaine :
              id(position:longueur) pour extraire/modifier
            Routines runtime pour manipulations de chaines
            10 fonctions accesseurs

  TODO 14 - PARSEUR : E/S FICHIERS (OPEN, READ, WRITE, CLOSE) [IMPLEMENTE]
            OPEN :
              OPEN INPUT nom-fichier-1 [nom-fichier-2 ...]
              OPEN OUTPUT nom-fichier-1 [nom-fichier-2 ...]
              OPEN I-O nom-fichier (lecture/ecriture)
              OPEN EXTEND nom-fichier (ajout en fin)
            READ :
              READ nom-fichier [INTO id]
                [AT END instructions]
                [NOT AT END instructions]
              END-READ
              READ nom-fichier KEY IS nom-cle (pour INDEXED)
                [INVALID KEY instructions]
            WRITE :
              WRITE nom-record [FROM id]
                [BEFORE/AFTER ADVANCING n LINES/PAGE]
                [INVALID KEY instructions]
              END-WRITE
            REWRITE :
              REWRITE nom-record [FROM id]
                [INVALID KEY instructions]
              END-REWRITE
            CLOSE :
              CLOSE nom-fichier-1 [nom-fichier-2 ...]
            DELETE :
              DELETE nom-fichier [INVALID KEY instructions]
            START :
              START nom-fichier KEY IS =/>/>=/</<= nom-cle
                [INVALID KEY instructions]
            FILE STATUS : code retour 2 caracteres (00, 10, ...)
            Appels Win32 API : CreateFileA, ReadFile, WriteFile,
              CloseHandle, SetFilePointer pour implementation
            10 fonctions accesseurs

  TODO 15 - PARSEUR : ACCEPT ET DISPLAY (E/S CONSOLE) [IMPLEMENTE]
            DISPLAY :
              DISPLAY lit-1 [lit-2 ...] [UPON CONSOLE/PRINTER]
              DISPLAY identifiant [WITH NO ADVANCING]
              Concatenation de multiples operandes
              Conversion numerique -> chaine pour affichage
              Win32 : GetStdHandle(STD_OUTPUT_HANDLE) + WriteFile
            ACCEPT :
              ACCEPT identifiant [FROM CONSOLE/DATE/DAY/TIME]
              ACCEPT id FROM DATE : date systeme YYMMDD
              ACCEPT id FROM DAY  : jour julien YYDDD
              ACCEPT id FROM TIME : heure HHMMSSCC
              Win32 : GetStdHandle(STD_INPUT_HANDLE) + ReadFile
            STOP RUN :
              Terminer le programme (ExitProcess)
              Optionnel : STOP literal (afficher puis terminer)
            Generation 80386 :
              PUSH/CALL pour les API Win32
              Conversion des types COBOL pour l affichage
              Gestion du retour a la ligne (CR/LF)
              WITH NO ADVANCING : pas de retour a la ligne
            10 fonctions accesseurs

  TODO 16 - PARSEUR : SECTIONS ET PARAGRAPHES (PROCEDURE DIVISION) [A FAIRE]
            Structure de la PROCEDURE DIVISION :
              PROCEDURE DIVISION [USING param-1 param-2 ...].
              Sections :
                nom-section SECTION.
                  contient un ou plusieurs paragraphes
              Paragraphes :
                nom-paragraphe.
                  contient des instructions jusqu au prochain
                  paragraphe ou section
            Resolution des noms de paragraphes et sections :
              PERFORM nom-paragraphe
              PERFORM section-1 THRU section-2
              GO TO nom-paragraphe
            PERFORM THRU : execution de paragraphe-debut
              jusqu a paragraphe-fin inclus
            Paragraphes inline vs externes
            Chaque paragraphe/section genere un label ASM :
              _COBP_NOM_PARAGRAPHE
            Appel de paragraphe : CALL/RET en 80386
              ou inline expansion pour les petits paragraphes
            Table des paragraphes : nom -> label ASM
            Verification des references non resolues
            DECLARATIVES : section speciale pour gestion
              des erreurs (USE AFTER STANDARD ERROR)
            10 fonctions accesseurs

  TODO 17 - PARSEUR : CALL ET LIAISON INTER-PROGRAMMES [A FAIRE]
            CALL :
              CALL 'nom-programme' [USING param-1 param-2 ...]
              CALL identifiant USING ... (appel dynamique)
              BY REFERENCE : passage par adresse (defaut COBOL)
              BY CONTENT : copie puis passage par adresse
              BY VALUE : passage par valeur (pour API C/Win32)
              ON EXCEPTION / NOT ON EXCEPTION
              ON OVERFLOW (synonyme ancien)
            END-CALL
            CANCEL :
              CANCEL 'nom-programme' (liberer le sous-programme)
            Conventions d appel :
              CALL COBOL : parametres par reference via pile 80386
              CALL Win32 API : convention STDCALL (BY VALUE)
              CALL C library : convention CDECL
            Passage de parametres 80386 :
              PUSH adresse (BY REFERENCE)
              PUSH valeur (BY VALUE)
              CALL label / CALL [adresse]
              Nettoyage de pile selon convention
            LINKAGE SECTION : description des parametres recus
            PROCEDURE DIVISION USING : parametres formels
            Appel dynamique avec LoadLibraryA/GetProcAddress
            10 fonctions accesseurs

  TODO 18 - PARSEUR : TABLES ET INDEXATION (OCCURS, SEARCH) [A FAIRE]
            Clause OCCURS :
              OCCURS n TIMES
              OCCURS n TO m TIMES DEPENDING ON id
              OCCURS avec KEY IS (pour SEARCH ALL)
              OCCURS avec INDEXED BY idx
            Indexation :
              Indice numerique : TABLE(3) -> base + (3-1)*taille
              Variable indice : TABLE(WS-IDX)
              Index : TABLE(IDX-1) - optimise avec offset direct
              Indices multiples : TABLE(I, J) pour tables 2D
            SET pour indices et index :
              SET idx TO valeur
              SET idx UP BY n / SET idx DOWN BY n
            SEARCH (recherche lineaire) :
              SEARCH nom-table
                [AT END instructions]
                WHEN condition instructions
              END-SEARCH
              Incremente automatiquement l index associe
            SEARCH ALL (recherche binaire) :
              SEARCH ALL nom-table
                [AT END instructions]
                WHEN cle = valeur instructions
              END-SEARCH
              Necessite que la table soit ordonnee (KEY IS)
            Generation 80386 :
              Calcul d offset : base + (indice-1) * taille-element
              Boucle de recherche avec CMP/JE/JNE/JMP
            10 fonctions accesseurs

  TODO 19 - PARSEUR : SORT ET MERGE [A FAIRE]
            SORT :
              SORT nom-fichier-tri
                ON ASCENDING/DESCENDING KEY nom-cle-1 [nom-cle-2]
                [WITH DUPLICATES IN ORDER]
                USING nom-fichier-entree
                  ou INPUT PROCEDURE IS section-1 [THRU section-2]
                GIVING nom-fichier-sortie
                  ou OUTPUT PROCEDURE IS section-1 [THRU section-2]
            SD (Sort Description) dans FILE SECTION :
              SD nom-fichier-tri.
              01 nom-record-tri.
                05 champs...
            RELEASE :
              RELEASE nom-record-tri [FROM id]
              (dans INPUT PROCEDURE pour fournir des enregistrements)
            RETURN :
              RETURN nom-fichier-tri [INTO id]
                AT END instructions
              END-RETURN
              (dans OUTPUT PROCEDURE pour recuperer les resultats)
            MERGE :
              MERGE nom-fichier-tri
                ON ASCENDING/DESCENDING KEY nom-cle
                USING fichier-1 fichier-2 [fichier-3 ...]
                GIVING nom-fichier-sortie
            Implementation interne : tri par insertion ou quicksort
              en memoire pour les petites tables
            Pour les fichiers volumineux : tri externe avec
              fichiers temporaires Win32 (GetTempPathA/CreateFileA)
            10 fonctions accesseurs

  TODO 20 - BIBLIOTHEQUE RUNTIME COBOL (CHAINES, BCD, E/S VIA WIN32) [A FAIRE]
            Routines de conversion numerique :
              _COBRT_DISPLAY_TO_INT : PIC 9 DISPLAY -> registre 32 bits
              _COBRT_INT_TO_DISPLAY : registre 32 bits -> PIC 9 DISPLAY
              _COBRT_PACK_TO_INT : COMP-3 BCD -> registre 32 bits
              _COBRT_INT_TO_PACK : registre 32 bits -> COMP-3 BCD
              _COBRT_DISPLAY_TO_EDITED : DISPLAY -> format edite (Z, *, etc.)
              _COBRT_NUMERIC_VALIDATE : verifier si NUMERIC
            Routines de transfert :
              _COBRT_MOVE_ALPHA : deplacement alphanumerique
                (cadrage gauche, espaces de remplissage)
              _COBRT_MOVE_NUMERIC : deplacement numerique
                (alignement decimal, zero-fill)
              _COBRT_MOVE_CORRESPONDING : MOVE CORRESPONDING
              _COBRT_INITIALIZE : INITIALIZE record
            Routines de chaines :
              _COBRT_STRING_OP : operation STRING
              _COBRT_UNSTRING_OP : operation UNSTRING
              _COBRT_INSPECT_TALLY : INSPECT TALLYING
              _COBRT_INSPECT_REPLACE : INSPECT REPLACING
              _COBRT_INSPECT_CONVERT : INSPECT CONVERTING
            Routines d E/S :
              _COBRT_DISPLAY : afficher sur console (WriteFile)
              _COBRT_ACCEPT : lire depuis console (ReadFile)
              _COBRT_ACCEPT_DATE : date systeme (GetLocalTime)
              _COBRT_FILE_OPEN : ouvrir fichier (CreateFileA)
              _COBRT_FILE_CLOSE : fermer fichier (CloseHandle)
              _COBRT_FILE_READ : lire enregistrement (ReadFile)
              _COBRT_FILE_WRITE : ecrire enregistrement (WriteFile)
            Routines arithmetiques :
              _COBRT_ADD_ROUNDED : addition avec arrondi
              _COBRT_CHECK_SIZE_ERROR : detection de debordement
              _COBRT_POWER : exponentiation (puissance)
            Variables runtime :
              _COB_STDOUT, _COB_STDIN, _COB_FILE_HANDLES,
              _COB_FILE_STATUS, _COB_RETURN_CODE
            10 fonctions accesseurs

  TODO 21 - ECRIVAIN BINAIRE PE (GENERATION .EXE WINDOWS 32 BITS) [A FAIRE]
            Structure PE32 complete :
              DOS Header (64 octets) avec DOS stub
              Signature PE "PE\0\0"
              COFF File Header (20 octets)
                Machine : $014C (i386)
                NumberOfSections : 3 (.text, .rdata, .data)
              Optional Header (224 octets)
                Magic : $010B (PE32)
                ImageBase : $00400000
                SectionAlignment : $1000 (4096)
                FileAlignment : $0200 (512)
                Subsystem : 3 (CUI Console)
                DataDirectory[1] : Import Table RVA/Size
              Section Headers : .text, .rdata, .data
            Section .text :
              Code machine 80386 genere
              Point d entree (_start -> ExitProcess)
              Routines runtime COBOL
              Paragraphes et sections PROCEDURE DIVISION
            Section .rdata :
              Import Directory (IMAGE_IMPORT_DESCRIPTOR)
              Hint/Name Table pour chaque DLL importee
              Import Address Table (IAT) avec thunks
            Section .data :
              Variables WORKING-STORAGE initialisees
              Constantes chaines COBOL
              Tables de fichiers et buffers
            Resolution des fixups (adresses relatives/absolues)
            Alignement des sections sur FileAlignment/SectionAlignment
            10 fonctions accesseurs

  TODO 22 - ECRIVAIN COFF .OBJ (PARAMETRE -obj) [A FAIRE]
            Format COFF 32 bits compatible LINK.EXE :
              COFF File Header (20 octets)
                Machine : $014C (i386)
                NumberOfSections : 3
              Section .text : code machine 80386
              Section .data : donnees initialisees
              Section .bss  : donnees non initialisees
              Table des relocations :
                IMAGE_RELOCATION pour chaque reference
                Type $0006 : IMAGE_REL_I386_DIR32 (adresse absolue)
                Type $0014 : IMAGE_REL_I386_REL32 (adresse relative)
              Table des symboles :
                IMAGE_SYMBOL pour chaque symbole
                StorageClass : EXTERNAL (2), STATIC (3), LABEL (6)
                Symboles externes pour imports Win32
                Symboles definis pour paragraphes/variables COBOL
              Table des chaines :
                Noms de symboles > 8 caracteres
            Ecriture binaire : octet par octet dans le fichier
            Compatible avec Microsoft LINK.EXE et MASM
            10 fonctions accesseurs

  TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm) [A FAIRE]
            Format MASM (.ASM) lisible et assemblable :
              .386
              .MODEL FLAT, STDCALL
              OPTION CASEMAP:NONE
            Section INCLUDELIB :
              INCLUDELIB kernel32.lib
              INCLUDELIB user32.lib
              INCLUDELIB msvcrt.lib (si necessaire)
            Section EXTERN :
              EXTERN _ExitProcess@4:PROC
              EXTERN _GetStdHandle@4:PROC
              EXTERN _WriteFile@20:PROC
              EXTERN _ReadFile@20:PROC
              EXTERN _CreateFileA@28:PROC
              EXTERN _CloseHandle@4:PROC
              (autres imports Win32 utilises)
            Section .DATA :
              Variables WORKING-STORAGE avec DB/DW/DD
              Constantes chaines avec DB 'texte', 0
              Tables de fichiers
            Section .DATA? :
              Variables non initialisees (BSS)
              Buffers d E/S
            Section .CODE :
              Point d entree _start
              Routines runtime (_COBRT_)
              Paragraphes COBOL avec labels (_COBP_)
              Commentaires avec le code COBOL source
            Indentation et formatage lisible
            Commentaires preserves dans le listing
            10 fonctions accesseurs

  TODO 24 - IMPORTS API WIN32 ET LIAISON (KERNEL32, USER32, MSVCRT) [A FAIRE]
            Imports kernel32.dll :
              ExitProcess, GetStdHandle, WriteFile, ReadFile,
              GetProcessHeap, HeapAlloc, HeapFree,
              CreateFileA, CloseHandle, SetFilePointer,
              GetFileSize, DeleteFileA, MoveFileA,
              GetCommandLineA, GetModuleHandleA,
              GetLocalTime (pour ACCEPT FROM DATE/TIME),
              GetTempPathA (pour fichiers temporaires SORT),
              GetLastError, SetLastError,
              FindFirstFileA, FindNextFileA, FindClose,
              LoadLibraryA, GetProcAddress, FreeLibrary
                (pour CALL dynamique)
            Imports user32.dll :
              MessageBoxA (optionnel pour messages d erreur)
            Imports msvcrt.dll (si necessaire) :
              sprintf, sscanf (pour formatage numerique),
              _itoa, atoi, atol (conversions),
              memcpy, memset, memcmp (operations memoire),
              qsort (pour SORT interne)
            Generer la table d importation PE :
              IMAGE_IMPORT_DESCRIPTOR par DLL
              Hint/Name Table avec noms de fonctions
              Import Address Table (IAT) avec thunks
            Generer les EXTERN pour le mode .ASM
            Generer les symboles externes pour le mode .OBJ
            Marquer les imports reellement utilises pour
              n inclure que le necessaire
            10 fonctions accesseurs

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\COBOL\* [A FAIRE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\COBOL\HELLO.CBL      - Hello World avec DISPLAY
              SAMPLES\COBOL\DATA_TEST.CBL  - DATA DIVISION et types
              SAMPLES\COBOL\IDENT_TEST.CBL - IDENTIFICATION DIVISION
              SAMPLES\COBOL\ENV_TEST.CBL   - ENVIRONMENT DIVISION
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes
            Verification de la compatibilite COBOL-85
            Test des constantes figuratives (SPACES, ZEROS, etc.)
            Test des operations MOVE avec differents types PIC
            Test de l arithmetique decimale (COMP-3, ROUNDED)
            10 fonctions accesseurs

  ============================================================ *)

Program COBOLW32;

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES    [IMPLEMENTE] }
{           PE/COFF                                              }
{ ============================================================ }

Const
  COBOLW32_VERSION = '0.1';
  COBOLW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Constantes PE/COFF }
  PE_DOS_MAGIC    = $5A4D;    { 'MZ' }
  PE_PE_SIG       = $00004550; { 'PE\0\0' }
  PE_MACHINE_I386 = $014C;
  PE_OPT_SIZE     = $E0;
  PE_MAGIC_32     = $010B;
  PE_IMG_BASE     = $00400000;
  PE_SEC_ALIGN    = 4096;
  PE_FILE_ALIGN   = 512;
  PE_SUBSYS_CUI   = 3;  { Console }

  { Tailles des tampons binaires }
  MAX_BIN_CODE = 65536;
  MAX_BIN_DATA = 65536;
  MAX_BIN_LBL  = 4096;
  MAX_BIN_FIX  = 8192;

  { Limites internes (32 bits) }
  MAX_SYM     = 4096;
  MAX_SEC     = 64;
  MAX_LOCAL   = 256;
  MAX_PARAM   = 64;
  MAX_DEPTH   = 32;
  MAX_LABEL   = 4096;
  MAX_STR     = 255;
  MAX_FIELD   = 128;
  MAX_FILE    = 16;
  MAX_TABLE   = 128;
  MAX_LEVEL   = 49;
  MAX_PIC     = 64;
  MAX_PERFORM = 256;

  { Prefixes de nommage ASM }
  PFX_VAR   = '_COB_';    { variable globale (WORKING-STORAGE)   }
  PFX_PARA  = '_COBP_';   { paragraphe/section PROCEDURE         }
  PFX_CONST = '_COBK_';   { constante chaine                     }
  PFX_RT    = '_COBRT_';  { routine runtime                      }
  PFX_LBL   = '_COBL_';   { label interne                        }
  PFX_TAB   = '_COBT_';   { table/tableau (OCCURS)               }
  PFX_FLD   = '_COBF_';   { champ de fichier (FILE SECTION)      }
  PFX_SEC   = '_COBS_';   { section (PROCEDURE DIVISION)         }
  PFX_ENT   = '_COBE_';   { entree fichier (FD record)           }

Type
  TString = String;

  TOptions = Record
    SrcFile    : TString;   { fichier source (.cbl ou .cob)        }
    OutFile    : TString;   { fichier sortie (.exe, .obj)          }
    Verbose    : Boolean;   { -v : banniere et statistiques        }
    DebugMode  : Boolean;   { -d : affichage de chaque token       }
    Warnings   : Boolean;   { -w : afficher les avertissements     }
    EmitExe    : Boolean;   { par defaut : produire un .EXE (PE)   }
    EmitObj    : Boolean;   { -obj : produire seulement un .OBJ    }
    EmitAsm    : Boolean;   { -asm : produire aussi un .ASM        }
    FreeFormat : Boolean;   { -free : format libre (pas de colonnes fixes) }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Drapeau pour la generation binaire PE (mini-assembleur) }
  BcActive   : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function ItoS(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

Function ItoSI(V : Integer) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoSI := S;
End;

Function UpCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  UpCaseStr := Tmp;
End;

Function LoCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  LoCaseStr := Tmp;
End;

{ Transforme un nom COBOL en identifiant valide pour l assembleur }
{ Les tirets (-) sont remplaces par des underscores (_)           }
Function AsmIdent(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := '';
  For I := 1 To Length(S) Do
  Begin
    If ((S[I] >= 'A') And (S[I] <= 'Z')) Or
       ((S[I] >= 'a') And (S[I] <= 'z')) Or
       ((S[I] >= '0') And (S[I] <= '9')) Or
       (S[I] = '_') Then
      Tmp := Tmp + S[I]
    Else If S[I] = '-' Then
      Tmp := Tmp + '_'
    Else
      Tmp := Tmp + '_';
  End;
  AsmIdent := Tmp;
End;

{ Retourne l extension d un chemin (avec le point, en minuscules) }
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
    ExtractExt := LoCaseStr(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
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

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('COBOLW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('COBOLW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile    := '';
  Opts.OutFile    := '';
  Opts.Verbose    := False;
  Opts.DebugMode  := False;
  Opts.Warnings   := False;
  Opts.EmitExe    := True;
  Opts.EmitObj    := False;
  Opts.EmitAsm    := False;
  Opts.FreeFormat := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('COBOLW32 v', COBOLW32_VERSION, ' (', COBOLW32_DATE,
          ') - Compilateur COBOL vers 80386 (Windows PE 32 bits)');
  WriteLn('COBOLW32 - Cette commande permet de lancer le compilateur COBOL ',
          'pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : COBOLW32 [options] <source.cbl> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('COBOL :');
  WriteLn('  -free          Format libre (pas de colonnes fixes)');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  COBOLW32 hello.cbl');
  WriteLn('  COBOLW32 hello.cbl -o hello.exe -v');
  WriteLn('  COBOLW32 main.cbl -asm');
  WriteLn('  COBOLW32 module.cbl -obj -w');
  WriteLn('  COBOLW32 program.cob -free');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-free' Then
      Opts.FreeFormat := True
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('-o necessite un nom de fichier');
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('COBOLW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .cbl ou .cob }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.cbl') And (Ext <> '.cob') Then
    WarnMsg('extension attendue .cbl ou .cob, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                        }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('COBOLW32 v', COBOLW32_VERSION, ' (', COBOLW32_DATE,
          ') - Compilateur COBOL -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Mode     : OBJ (COFF 32 bits)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
  If Opts.FreeFormat Then
    WriteLn('Format   : Libre (colonnes non fixes)')
  Else
    WriteLn('Format   : Fixe (colonnes 1-72)');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetCompilerVersion : TString;
Begin
  GetCompilerVersion := COBOLW32_VERSION;
End;

Function GetCompilerDate : TString;
Begin
  GetCompilerDate := COBOLW32_DATE;
End;

Function IsEmitExe : Boolean;
Begin
  IsEmitExe := Opts.EmitExe;
End;

Function IsEmitObj : Boolean;
Begin
  IsEmitObj := Opts.EmitObj;
End;

Function IsEmitAsm : Boolean;
Begin
  IsEmitAsm := Opts.EmitAsm;
End;

Function IsVerbose : Boolean;
Begin
  IsVerbose := Opts.Verbose;
End;

Function IsDebugMode : Boolean;
Begin
  IsDebugMode := Opts.DebugMode;
End;

Function IsFreeFormat : Boolean;
Begin
  IsFreeFormat := Opts.FreeFormat;
End;

Function GetSrcFile : TString;
Begin
  GetSrcFile := Opts.SrcFile;
End;

Function GetOutFile : TString;
Begin
  GetOutFile := Opts.OutFile;
End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR COBOL (LEXER)          [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Types de tokens }
  TOK_EOF        = 0;    { fin de fichier                          }
  TOK_IDENT      = 1;    { identificateur COBOL (WS-NOM, etc.)     }
  TOK_INTEGER    = 2;    { litteral entier (123)                   }
  TOK_DECIMAL    = 3;    { litteral decimal (1.5, 3.14)            }
  TOK_STRING     = 4;    { litteral chaine ('texte' ou "texte")    }
  TOK_HEX_STRING = 5;    { litteral hexadecimal (X'FF' ou X"FF")   }
  TOK_PLUS       = 10;   { +                                       }
  TOK_MINUS      = 11;   { -                                       }
  TOK_STAR       = 12;   { *                                       }
  TOK_SLASH      = 13;   { /                                       }
  TOK_POWER      = 14;   { ** (exponentiation)                     }
  TOK_LPAREN     = 20;   { (                                       }
  TOK_RPAREN     = 21;   { )                                       }
  TOK_COMMA      = 22;   { ,                                       }
  TOK_DOT        = 23;   { . (terminateur d instruction COBOL)     }
  TOK_EQ         = 30;   { =                                       }
  TOK_NE         = 31;   { <> (NOT EQUAL)                          }
  TOK_LT         = 32;   { <                                       }
  TOK_GT         = 33;   { >                                       }
  TOK_LE         = 34;   { <=                                      }
  TOK_GE         = 35;   { >=                                      }
  TOK_NEWLINE    = 40;   { fin de ligne logique                    }
  TOK_KEYWORD    = 50;   { mot-cle COBOL reconnu                   }

  { Constantes de format fixe COBOL }
  COB_COL_SEQ_END  = 6;   { colonnes 1-6 : numero de sequence      }
  COB_COL_IND      = 7;   { colonne 7 : indicateur                 }
  COB_COL_AREA_A   = 8;   { colonnes 8-11 : zone A                 }
  COB_COL_AREA_B   = 12;  { colonnes 12-72 : zone B                }
  COB_COL_COMMENT  = 73;  { colonnes 73-80 : zone de commentaire   }
  COB_COL_RIGHT    = 72;  { derniere colonne utile (format fixe)   }

Var
  { Fichier source }
  LexSrcF    : Text;          { handle du fichier source              }
  LexOpened  : Boolean;        { fichier ouvert ?                      }
  LexLine    : TString;        { ligne courante                        }
  LexLineNo  : Integer;        { numero de ligne courante              }
  LexColNo   : Integer;        { colonne courante dans LexLine         }
  LexEOF     : Boolean;        { fin de fichier atteinte ?             }

  { Token courant }
  CurTokType : Integer;        { type de token (TOK_*)                 }
  CurTokStr  : TString;        { valeur textuelle du token             }
  CurTokNum  : LongInt;        { valeur numerique (entier)             }
  CurTokReal : Real;           { valeur numerique (reel)               }
  CurTokLine : Integer;        { ligne du token                        }
  CurTokCol  : Integer;        { colonne du token                      }

  { Compteur de tokens }
  LexTokCount : LongInt;       { nombre total de tokens emis           }

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
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

Function IsWhitespace(Ch : Char) : Boolean;
Begin
  IsWhitespace := (Ch = ' ') Or (Ch = #9);
End;

{ COBOL identifiers can contain letters, digits and hyphens (-) }
{ Hyphens are allowed in the middle but not at start or end     }
Function IsCobolIdentStart(Ch : Char) : Boolean;
Begin
  IsCobolIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                        ((Ch >= 'a') And (Ch <= 'z'));
End;

Function IsCobolIdentCont(Ch : Char) : Boolean;
Begin
  IsCobolIdentCont := ((Ch >= 'A') And (Ch <= 'Z')) Or
                      ((Ch >= 'a') And (Ch <= 'z')) Or
                      ((Ch >= '0') And (Ch <= '9')) Or
                      (Ch = '-');
End;

{ ------------------------------------------------------------ }
{ LexNextLine : lire la prochaine ligne du fichier source      }
{ ------------------------------------------------------------ }

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

{ ------------------------------------------------------------ }
{ LexInit : ouvrir le fichier source et initialiser le lexeur  }
{ ------------------------------------------------------------ }

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened   := True;
  LexLineNo   := 0;
  LexColNo    := 1;
  LexEOF      := False;
  LexLine     := '';
  CurTokType  := TOK_EOF;
  CurTokStr   := '';
  CurTokNum   := 0;
  CurTokReal  := 0.0;
  CurTokLine  := 0;
  CurTokCol   := 0;
  LexTokCount := 0;
  LexNextLine;
End;

{ ------------------------------------------------------------ }
{ LexClose : fermer le fichier source                          }
{ ------------------------------------------------------------ }

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexSkipWhitespace                                            }
{ ------------------------------------------------------------ }

Procedure LexSkipWhitespace;
Begin
  While (LexColNo <= Length(LexLine)) And
        IsWhitespace(LexLine[LexColNo]) Do
    Inc(LexColNo);
End;

{ ------------------------------------------------------------ }
{ LexIsCommentLine : determine si la ligne courante est un     }
{ commentaire (format fixe: * ou / en colonne 7)               }
{ ------------------------------------------------------------ }

Function LexIsCommentLine : Boolean;
Begin
  If Opts.FreeFormat Then
  Begin
    { Format libre : pas de lignes commentaires implicites }
    LexIsCommentLine := False;
  End
  Else
  Begin
    { Format fixe : colonne 7 = * (commentaire) ou / (saut page) }
    If Length(LexLine) >= COB_COL_IND Then
      LexIsCommentLine := (LexLine[COB_COL_IND] = '*') Or
                           (LexLine[COB_COL_IND] = '/')
    Else
      LexIsCommentLine := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexIsDebugLine : determine si la ligne est une ligne debug   }
{ (colonne 7 = D ou d en format fixe)                          }
{ ------------------------------------------------------------ }

Function LexIsDebugLine : Boolean;
Begin
  If Opts.FreeFormat Then
    LexIsDebugLine := False
  Else If Length(LexLine) >= COB_COL_IND Then
    LexIsDebugLine := (LexLine[COB_COL_IND] = 'D') Or
                       (LexLine[COB_COL_IND] = 'd')
  Else
    LexIsDebugLine := False;
End;

{ ------------------------------------------------------------ }
{ LexIsContinuationLine : determine si la ligne est une        }
{ continuation (colonne 7 = - en format fixe)                  }
{ ------------------------------------------------------------ }

Function LexIsContinuationLine : Boolean;
Begin
  If Opts.FreeFormat Then
    LexIsContinuationLine := False
  Else If Length(LexLine) >= COB_COL_IND Then
    LexIsContinuationLine := (LexLine[COB_COL_IND] = '-')
  Else
    LexIsContinuationLine := False;
End;

{ ------------------------------------------------------------ }
{ LexPrepareFixedLine : positionne LexColNo apres la zone de   }
{ sequence et l indicateur (format fixe: debut en colonne 8)    }
{ ------------------------------------------------------------ }

Procedure LexPrepareFixedLine;
Begin
  If Not Opts.FreeFormat Then
  Begin
    { Ignorer les colonnes 1-7, commencer en colonne 8 (zone A) }
    If Length(LexLine) >= COB_COL_AREA_A Then
      LexColNo := COB_COL_AREA_A
    Else
      LexColNo := Length(LexLine) + 1;
  End
  Else
    LexColNo := 1;
End;

{ ------------------------------------------------------------ }
{ LexEffectiveEnd : retourne la derniere colonne utile         }
{ Format fixe : colonne 72, format libre : fin de ligne        }
{ ------------------------------------------------------------ }

Function LexEffectiveEnd : Integer;
Begin
  If Opts.FreeFormat Then
    LexEffectiveEnd := Length(LexLine)
  Else
  Begin
    If Length(LexLine) > COB_COL_RIGHT Then
      LexEffectiveEnd := COB_COL_RIGHT
    Else
      LexEffectiveEnd := Length(LexLine);
  End;
End;

{ ============================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES COBOL [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Constantes KW_* pour les mots-cles COBOL-85 }
  KW_NONE              = 0;

  { DIVISIONS }
  KW_IDENTIFICATION    = 1;
  KW_ENVIRONMENT       = 2;
  KW_DATA              = 3;
  KW_PROCEDURE         = 4;
  KW_DIVISION          = 5;

  { SECTIONS }
  KW_CONFIGURATION     = 10;
  KW_INPUT_OUTPUT      = 11;   { INPUT-OUTPUT }
  KW_FILE_CONTROL      = 12;   { FILE-CONTROL }
  KW_FILE              = 13;
  KW_WORKING_STORAGE   = 14;   { WORKING-STORAGE }
  KW_LINKAGE           = 15;
  KW_SCREEN            = 16;
  KW_REPORT            = 17;
  KW_SECTION           = 18;
  KW_LOCAL_STORAGE     = 19;   { LOCAL-STORAGE }

  { Paragraphes IDENTIFICATION }
  KW_PROGRAM_ID        = 20;   { PROGRAM-ID }
  KW_AUTHOR            = 21;
  KW_INSTALLATION      = 22;
  KW_DATE_WRITTEN      = 23;   { DATE-WRITTEN }
  KW_DATE_COMPILED     = 24;   { DATE-COMPILED }
  KW_SECURITY          = 25;

  { Paragraphes ENVIRONMENT }
  KW_SOURCE_COMPUTER   = 30;   { SOURCE-COMPUTER }
  KW_OBJECT_COMPUTER   = 31;   { OBJECT-COMPUTER }
  KW_SPECIAL_NAMES     = 32;   { SPECIAL-NAMES }
  KW_REPOSITORY        = 33;

  { Instructions (verbes) COBOL }
  KW_ACCEPT            = 40;
  KW_ADD               = 41;
  KW_CALL              = 42;
  KW_CLOSE             = 43;
  KW_COMPUTE           = 44;
  KW_CONTINUE          = 45;
  KW_DELETE            = 46;
  KW_DISPLAY           = 47;
  KW_DIVIDE            = 48;
  KW_EVALUATE          = 49;
  KW_EXIT              = 50;
  KW_GO                = 51;
  KW_GOBACK            = 52;
  KW_IF                = 53;
  KW_INITIALIZE        = 54;
  KW_INSPECT           = 55;
  KW_MERGE             = 56;
  KW_MOVE              = 57;
  KW_MULTIPLY          = 58;
  KW_OPEN              = 59;
  KW_PERFORM           = 60;
  KW_READ              = 61;
  KW_RELEASE           = 62;
  KW_RETURN            = 63;
  KW_REWRITE           = 64;
  KW_SEARCH            = 65;
  KW_SET               = 66;
  KW_SORT              = 67;
  KW_START             = 68;
  KW_STOP              = 69;
  KW_STRING            = 70;
  KW_SUBTRACT          = 71;
  KW_UNSTRING          = 72;
  KW_WRITE             = 73;

  { Clauses DATA DIVISION }
  KW_PIC               = 80;
  KW_PICTURE           = 81;
  KW_VALUE             = 82;
  KW_USAGE             = 83;
  KW_OCCURS            = 84;
  KW_REDEFINES         = 85;
  KW_RENAMES           = 86;
  KW_FILLER            = 87;
  KW_BLANK             = 88;
  KW_JUSTIFIED         = 89;
  KW_SIGN              = 90;
  KW_SYNCHRONIZED      = 91;
  KW_COMP              = 92;
  KW_COMP_1            = 93;   { COMP-1 }
  KW_COMP_2            = 94;   { COMP-2 }
  KW_COMP_3            = 95;   { COMP-3 }
  KW_BINARY            = 96;
  KW_PACKED_DECIMAL    = 97;   { PACKED-DECIMAL }
  KW_INDEX             = 98;

  { Clauses FILE }
  KW_SELECT            = 100;
  KW_ASSIGN            = 101;
  KW_ORGANIZATION      = 102;
  KW_ACCESS            = 103;
  KW_FILE_STATUS       = 104;  { FILE STATUS (2 mots mais traite FILE) }
  KW_RECORD            = 105;
  KW_LABEL             = 106;
  KW_FD                = 107;
  KW_SD                = 108;
  KW_STATUS            = 109;

  { Structures IF/EVALUATE/PERFORM/END-xxx }
  KW_ELSE              = 110;
  KW_END_IF            = 111;  { END-IF }
  KW_WHEN              = 112;
  KW_END_EVALUATE      = 113;  { END-EVALUATE }
  KW_END_PERFORM       = 114;  { END-PERFORM }
  KW_END_READ          = 115;  { END-READ }
  KW_END_SEARCH        = 116;  { END-SEARCH }
  KW_END_STRING        = 117;  { END-STRING }
  KW_END_UNSTRING      = 118;  { END-UNSTRING }
  KW_END_COMPUTE       = 119;  { END-COMPUTE }
  KW_END_ADD           = 120;  { END-ADD }
  KW_END_SUBTRACT      = 121;  { END-SUBTRACT }
  KW_END_MULTIPLY      = 122;  { END-MULTIPLY }
  KW_END_DIVIDE        = 123;  { END-DIVIDE }
  KW_END_CALL          = 124;  { END-CALL }
  KW_END_WRITE         = 125;  { END-WRITE }
  KW_END_RETURN        = 126;  { END-RETURN }
  KW_END_REWRITE       = 127;  { END-REWRITE }
  KW_END_START         = 128;  { END-START }
  KW_END_DELETE         = 129;  { END-DELETE }

  { Conditions et operateurs logiques }
  KW_AND               = 130;
  KW_OR                = 131;
  KW_NOT               = 132;
  KW_EQUAL             = 133;
  KW_GREATER           = 134;
  KW_LESS              = 135;
  KW_NUMERIC           = 136;
  KW_ALPHABETIC        = 137;
  KW_POSITIVE          = 138;
  KW_NEGATIVE          = 139;
  KW_ZERO              = 140;
  KW_ZEROS             = 141;
  KW_ZEROES            = 142;
  KW_SPACES            = 143;
  KW_HIGH_VALUES       = 144;  { HIGH-VALUES }
  KW_HIGH_VALUE        = 145;  { HIGH-VALUE }
  KW_LOW_VALUES        = 146;  { LOW-VALUES }
  KW_LOW_VALUE         = 147;  { LOW-VALUE }

  { Divers mots reserves COBOL }
  KW_THRU              = 150;
  KW_THROUGH           = 151;
  KW_TIMES             = 152;
  KW_UNTIL             = 153;
  KW_VARYING           = 154;
  KW_GIVING            = 155;
  KW_REMAINDER         = 156;
  KW_ROUNDED           = 157;
  KW_SIZE              = 158;
  KW_ON                = 159;
  KW_INTO              = 160;
  KW_FROM              = 161;
  KW_TO                = 162;
  KW_BY                = 163;
  KW_IS                = 164;
  KW_ARE               = 165;
  KW_OF                = 166;
  KW_IN                = 167;
  KW_THAN              = 168;
  KW_ALSO              = 169;
  KW_WITH              = 170;
  KW_ADVANCING         = 171;
  KW_BEFORE            = 172;
  KW_AFTER             = 173;
  KW_ALL               = 174;
  KW_LEADING           = 175;
  KW_TRAILING          = 176;
  KW_FIRST             = 177;
  KW_INITIAL           = 178;
  KW_CORRESPONDING     = 179;
  KW_CORR              = 180;
  KW_UPON              = 181;
  KW_USING             = 182;
  KW_RETURNING         = 183;
  KW_REFERENCE         = 184;
  KW_CONTENT           = 185;
  KW_DELIMITED         = 186;
  KW_DELIMITER         = 187;
  KW_COUNT             = 188;
  KW_TALLYING          = 189;
  KW_REPLACING         = 190;
  KW_CONVERTING        = 191;
  KW_POINTER           = 192;
  KW_OVERFLOW          = 193;
  KW_END_OF_PAGE       = 194;  { END-OF-PAGE }
  KW_EOP               = 195;
  KW_TRUE              = 196;
  KW_FALSE             = 197;
  KW_ALPHABETIC_LOWER  = 198;  { ALPHABETIC-LOWER }
  KW_ALPHABETIC_UPPER  = 199;  { ALPHABETIC-UPPER }

  { Modes d ouverture de fichier }
  KW_INPUT             = 200;
  KW_OUTPUT            = 201;
  KW_I_O               = 202;  { I-O }
  KW_EXTEND            = 203;

  { Organisation de fichier }
  KW_SEQUENTIAL        = 210;
  KW_RELATIVE          = 211;
  KW_INDEXED           = 212;
  KW_LINE              = 213;
  KW_DYNAMIC           = 214;
  KW_RANDOM            = 215;
  KW_ALTERNATE         = 216;
  KW_KEY               = 217;
  KW_DUPLICATES        = 218;

  { Mots-cles supplementaires pour PERFORM et boucles }
  KW_TEST              = 220;
  KW_DEPENDING         = 221;
  KW_PARAGRAPH         = 222;

  { Mots-cles supplementaires pour STRING/UNSTRING/INSPECT }
  KW_CHARACTERS        = 223;
  KW_FOR               = 224;

  { Mots-cles supplementaires pour E/S fichiers }
  KW_INVALID           = 225;
  KW_AT                = 226;
  KW_PAGE              = 227;

  { Mots-cles supplementaires pour ACCEPT/DISPLAY }
  KW_CONSOLE           = 228;
  KW_PRINTER           = 229;
  KW_DATE              = 230;
  KW_DAY               = 231;
  KW_TIME              = 232;
  KW_RUN               = 233;
  KW_NO                = 234;
  KW_END_DISPLAY       = 235;  { END-DISPLAY }
  KW_END_ACCEPT        = 236;  { END-ACCEPT }
  KW_DAY_OF_WEEK       = 237;  { DAY-OF-WEEK }

  { Nombre total de mots-cles definis }
  KW_TOTAL_KEYWORDS    = 168;  { nombre approximatif de mots-cles }

Var
  { Variables du module de mots-cles }
  KwCount       : Integer;     { compteur de lookups effectues         }
  KwInitialized : Boolean;     { module initialise ?                   }

{ ------------------------------------------------------------ }
{ InitKeywordState : initialiser le module de mots-cles        }
{ ------------------------------------------------------------ }

Procedure InitKeywordState;
Begin
  KwCount       := 0;
  KwInitialized := True;
End;

{ ------------------------------------------------------------ }
{ LookupKeyword : retourner KW_xxx ou KW_NONE si non reconnu   }
{ COBOL est insensible a la casse (deja uppercase via LexScan) }
{ Les mots-cles composes avec tiret sont traites comme un      }
{ seul token (END-IF, WORKING-STORAGE, etc.)                   }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer;
Begin
  Inc(KwCount);
  { DIVISIONS }
  If      S = 'IDENTIFICATION'    Then LookupKeyword := KW_IDENTIFICATION
  Else If S = 'ENVIRONMENT'       Then LookupKeyword := KW_ENVIRONMENT
  Else If S = 'DATA'              Then LookupKeyword := KW_DATA
  Else If S = 'PROCEDURE'         Then LookupKeyword := KW_PROCEDURE
  Else If S = 'DIVISION'          Then LookupKeyword := KW_DIVISION
  { SECTIONS }
  Else If S = 'CONFIGURATION'     Then LookupKeyword := KW_CONFIGURATION
  Else If S = 'INPUT-OUTPUT'      Then LookupKeyword := KW_INPUT_OUTPUT
  Else If S = 'FILE-CONTROL'      Then LookupKeyword := KW_FILE_CONTROL
  Else If S = 'FILE'              Then LookupKeyword := KW_FILE
  Else If S = 'WORKING-STORAGE'   Then LookupKeyword := KW_WORKING_STORAGE
  Else If S = 'LINKAGE'           Then LookupKeyword := KW_LINKAGE
  Else If S = 'SCREEN'            Then LookupKeyword := KW_SCREEN
  Else If S = 'REPORT'            Then LookupKeyword := KW_REPORT
  Else If S = 'SECTION'           Then LookupKeyword := KW_SECTION
  Else If S = 'LOCAL-STORAGE'     Then LookupKeyword := KW_LOCAL_STORAGE
  { Paragraphes IDENTIFICATION }
  Else If S = 'PROGRAM-ID'        Then LookupKeyword := KW_PROGRAM_ID
  Else If S = 'AUTHOR'            Then LookupKeyword := KW_AUTHOR
  Else If S = 'INSTALLATION'      Then LookupKeyword := KW_INSTALLATION
  Else If S = 'DATE-WRITTEN'      Then LookupKeyword := KW_DATE_WRITTEN
  Else If S = 'DATE-COMPILED'     Then LookupKeyword := KW_DATE_COMPILED
  Else If S = 'SECURITY'          Then LookupKeyword := KW_SECURITY
  { Paragraphes ENVIRONMENT }
  Else If S = 'SOURCE-COMPUTER'   Then LookupKeyword := KW_SOURCE_COMPUTER
  Else If S = 'OBJECT-COMPUTER'   Then LookupKeyword := KW_OBJECT_COMPUTER
  Else If S = 'SPECIAL-NAMES'     Then LookupKeyword := KW_SPECIAL_NAMES
  Else If S = 'REPOSITORY'        Then LookupKeyword := KW_REPOSITORY
  { Instructions (verbes) }
  Else If S = 'ACCEPT'            Then LookupKeyword := KW_ACCEPT
  Else If S = 'ADD'               Then LookupKeyword := KW_ADD
  Else If S = 'CALL'              Then LookupKeyword := KW_CALL
  Else If S = 'CLOSE'             Then LookupKeyword := KW_CLOSE
  Else If S = 'COMPUTE'           Then LookupKeyword := KW_COMPUTE
  Else If S = 'CONTINUE'          Then LookupKeyword := KW_CONTINUE
  Else If S = 'DELETE'            Then LookupKeyword := KW_DELETE
  Else If S = 'DISPLAY'           Then LookupKeyword := KW_DISPLAY
  Else If S = 'DIVIDE'            Then LookupKeyword := KW_DIVIDE
  Else If S = 'EVALUATE'          Then LookupKeyword := KW_EVALUATE
  Else If S = 'EXIT'              Then LookupKeyword := KW_EXIT
  Else If S = 'GO'                Then LookupKeyword := KW_GO
  Else If S = 'GOBACK'            Then LookupKeyword := KW_GOBACK
  Else If S = 'IF'                Then LookupKeyword := KW_IF
  Else If S = 'INITIALIZE'        Then LookupKeyword := KW_INITIALIZE
  Else If S = 'INSPECT'           Then LookupKeyword := KW_INSPECT
  Else If S = 'MERGE'             Then LookupKeyword := KW_MERGE
  Else If S = 'MOVE'              Then LookupKeyword := KW_MOVE
  Else If S = 'MULTIPLY'          Then LookupKeyword := KW_MULTIPLY
  Else If S = 'OPEN'              Then LookupKeyword := KW_OPEN
  Else If S = 'PERFORM'           Then LookupKeyword := KW_PERFORM
  Else If S = 'READ'              Then LookupKeyword := KW_READ
  Else If S = 'RELEASE'           Then LookupKeyword := KW_RELEASE
  Else If S = 'RETURN'            Then LookupKeyword := KW_RETURN
  Else If S = 'REWRITE'           Then LookupKeyword := KW_REWRITE
  Else If S = 'SEARCH'            Then LookupKeyword := KW_SEARCH
  Else If S = 'SET'               Then LookupKeyword := KW_SET
  Else If S = 'SORT'              Then LookupKeyword := KW_SORT
  Else If S = 'START'             Then LookupKeyword := KW_START
  Else If S = 'STOP'              Then LookupKeyword := KW_STOP
  Else If S = 'STRING'            Then LookupKeyword := KW_STRING
  Else If S = 'SUBTRACT'          Then LookupKeyword := KW_SUBTRACT
  Else If S = 'UNSTRING'          Then LookupKeyword := KW_UNSTRING
  Else If S = 'WRITE'             Then LookupKeyword := KW_WRITE
  { Clauses DATA DIVISION }
  Else If S = 'PIC'               Then LookupKeyword := KW_PIC
  Else If S = 'PICTURE'           Then LookupKeyword := KW_PICTURE
  Else If S = 'VALUE'             Then LookupKeyword := KW_VALUE
  Else If S = 'USAGE'             Then LookupKeyword := KW_USAGE
  Else If S = 'OCCURS'            Then LookupKeyword := KW_OCCURS
  Else If S = 'REDEFINES'         Then LookupKeyword := KW_REDEFINES
  Else If S = 'RENAMES'           Then LookupKeyword := KW_RENAMES
  Else If S = 'FILLER'            Then LookupKeyword := KW_FILLER
  Else If S = 'BLANK'             Then LookupKeyword := KW_BLANK
  Else If S = 'JUSTIFIED'         Then LookupKeyword := KW_JUSTIFIED
  Else If S = 'SIGN'              Then LookupKeyword := KW_SIGN
  Else If S = 'SYNCHRONIZED'      Then LookupKeyword := KW_SYNCHRONIZED
  Else If S = 'SYNC'              Then LookupKeyword := KW_SYNCHRONIZED
  Else If S = 'COMP'              Then LookupKeyword := KW_COMP
  Else If S = 'COMP-1'            Then LookupKeyword := KW_COMP_1
  Else If S = 'COMP-2'            Then LookupKeyword := KW_COMP_2
  Else If S = 'COMP-3'            Then LookupKeyword := KW_COMP_3
  Else If S = 'BINARY'            Then LookupKeyword := KW_BINARY
  Else If S = 'PACKED-DECIMAL'    Then LookupKeyword := KW_PACKED_DECIMAL
  Else If S = 'INDEX'             Then LookupKeyword := KW_INDEX
  { Clauses FILE }
  Else If S = 'SELECT'            Then LookupKeyword := KW_SELECT
  Else If S = 'ASSIGN'            Then LookupKeyword := KW_ASSIGN
  Else If S = 'ORGANIZATION'      Then LookupKeyword := KW_ORGANIZATION
  Else If S = 'ACCESS'            Then LookupKeyword := KW_ACCESS
  Else If S = 'STATUS'            Then LookupKeyword := KW_STATUS
  Else If S = 'RECORD'            Then LookupKeyword := KW_RECORD
  Else If S = 'LABEL'             Then LookupKeyword := KW_LABEL
  Else If S = 'FD'                Then LookupKeyword := KW_FD
  Else If S = 'SD'                Then LookupKeyword := KW_SD
  { Structures END-xxx }
  Else If S = 'ELSE'              Then LookupKeyword := KW_ELSE
  Else If S = 'END-IF'            Then LookupKeyword := KW_END_IF
  Else If S = 'WHEN'              Then LookupKeyword := KW_WHEN
  Else If S = 'END-EVALUATE'      Then LookupKeyword := KW_END_EVALUATE
  Else If S = 'END-PERFORM'       Then LookupKeyword := KW_END_PERFORM
  Else If S = 'END-READ'          Then LookupKeyword := KW_END_READ
  Else If S = 'END-SEARCH'        Then LookupKeyword := KW_END_SEARCH
  Else If S = 'END-STRING'        Then LookupKeyword := KW_END_STRING
  Else If S = 'END-UNSTRING'      Then LookupKeyword := KW_END_UNSTRING
  Else If S = 'END-COMPUTE'       Then LookupKeyword := KW_END_COMPUTE
  Else If S = 'END-ADD'           Then LookupKeyword := KW_END_ADD
  Else If S = 'END-SUBTRACT'      Then LookupKeyword := KW_END_SUBTRACT
  Else If S = 'END-MULTIPLY'      Then LookupKeyword := KW_END_MULTIPLY
  Else If S = 'END-DIVIDE'        Then LookupKeyword := KW_END_DIVIDE
  Else If S = 'END-CALL'          Then LookupKeyword := KW_END_CALL
  Else If S = 'END-WRITE'         Then LookupKeyword := KW_END_WRITE
  Else If S = 'END-RETURN'        Then LookupKeyword := KW_END_RETURN
  Else If S = 'END-REWRITE'       Then LookupKeyword := KW_END_REWRITE
  Else If S = 'END-START'         Then LookupKeyword := KW_END_START
  Else If S = 'END-DELETE'        Then LookupKeyword := KW_END_DELETE
  { Conditions et operateurs logiques }
  Else If S = 'AND'               Then LookupKeyword := KW_AND
  Else If S = 'OR'                Then LookupKeyword := KW_OR
  Else If S = 'NOT'               Then LookupKeyword := KW_NOT
  Else If S = 'EQUAL'             Then LookupKeyword := KW_EQUAL
  Else If S = 'GREATER'           Then LookupKeyword := KW_GREATER
  Else If S = 'LESS'              Then LookupKeyword := KW_LESS
  Else If S = 'NUMERIC'           Then LookupKeyword := KW_NUMERIC
  Else If S = 'ALPHABETIC'        Then LookupKeyword := KW_ALPHABETIC
  Else If S = 'POSITIVE'          Then LookupKeyword := KW_POSITIVE
  Else If S = 'NEGATIVE'          Then LookupKeyword := KW_NEGATIVE
  Else If S = 'ZERO'              Then LookupKeyword := KW_ZERO
  Else If S = 'ZEROS'             Then LookupKeyword := KW_ZEROS
  Else If S = 'ZEROES'            Then LookupKeyword := KW_ZEROES
  Else If S = 'SPACES'            Then LookupKeyword := KW_SPACES
  Else If S = 'SPACE'             Then LookupKeyword := KW_SPACES
  Else If S = 'HIGH-VALUES'       Then LookupKeyword := KW_HIGH_VALUES
  Else If S = 'HIGH-VALUE'        Then LookupKeyword := KW_HIGH_VALUE
  Else If S = 'LOW-VALUES'        Then LookupKeyword := KW_LOW_VALUES
  Else If S = 'LOW-VALUE'         Then LookupKeyword := KW_LOW_VALUE
  Else If S = 'ALPHABETIC-LOWER'  Then LookupKeyword := KW_ALPHABETIC_LOWER
  Else If S = 'ALPHABETIC-UPPER'  Then LookupKeyword := KW_ALPHABETIC_UPPER
  Else If S = 'TRUE'              Then LookupKeyword := KW_TRUE
  Else If S = 'FALSE'             Then LookupKeyword := KW_FALSE
  { Divers mots reserves }
  Else If S = 'THRU'              Then LookupKeyword := KW_THRU
  Else If S = 'THROUGH'           Then LookupKeyword := KW_THROUGH
  Else If S = 'TIMES'             Then LookupKeyword := KW_TIMES
  Else If S = 'UNTIL'             Then LookupKeyword := KW_UNTIL
  Else If S = 'VARYING'           Then LookupKeyword := KW_VARYING
  Else If S = 'GIVING'            Then LookupKeyword := KW_GIVING
  Else If S = 'REMAINDER'         Then LookupKeyword := KW_REMAINDER
  Else If S = 'ROUNDED'           Then LookupKeyword := KW_ROUNDED
  Else If S = 'SIZE'              Then LookupKeyword := KW_SIZE
  Else If S = 'ON'                Then LookupKeyword := KW_ON
  Else If S = 'INTO'              Then LookupKeyword := KW_INTO
  Else If S = 'FROM'              Then LookupKeyword := KW_FROM
  Else If S = 'TO'                Then LookupKeyword := KW_TO
  Else If S = 'BY'                Then LookupKeyword := KW_BY
  Else If S = 'IS'                Then LookupKeyword := KW_IS
  Else If S = 'ARE'               Then LookupKeyword := KW_ARE
  Else If S = 'OF'                Then LookupKeyword := KW_OF
  Else If S = 'IN'                Then LookupKeyword := KW_IN
  Else If S = 'THAN'              Then LookupKeyword := KW_THAN
  Else If S = 'ALSO'              Then LookupKeyword := KW_ALSO
  Else If S = 'WITH'              Then LookupKeyword := KW_WITH
  Else If S = 'ADVANCING'         Then LookupKeyword := KW_ADVANCING
  Else If S = 'BEFORE'            Then LookupKeyword := KW_BEFORE
  Else If S = 'AFTER'             Then LookupKeyword := KW_AFTER
  Else If S = 'ALL'               Then LookupKeyword := KW_ALL
  Else If S = 'LEADING'           Then LookupKeyword := KW_LEADING
  Else If S = 'TRAILING'          Then LookupKeyword := KW_TRAILING
  Else If S = 'FIRST'             Then LookupKeyword := KW_FIRST
  Else If S = 'INITIAL'           Then LookupKeyword := KW_INITIAL
  Else If S = 'CORRESPONDING'     Then LookupKeyword := KW_CORRESPONDING
  Else If S = 'CORR'              Then LookupKeyword := KW_CORR
  Else If S = 'UPON'              Then LookupKeyword := KW_UPON
  Else If S = 'USING'             Then LookupKeyword := KW_USING
  Else If S = 'RETURNING'         Then LookupKeyword := KW_RETURNING
  Else If S = 'REFERENCE'         Then LookupKeyword := KW_REFERENCE
  Else If S = 'CONTENT'           Then LookupKeyword := KW_CONTENT
  Else If S = 'DELIMITED'         Then LookupKeyword := KW_DELIMITED
  Else If S = 'DELIMITER'         Then LookupKeyword := KW_DELIMITER
  Else If S = 'COUNT'             Then LookupKeyword := KW_COUNT
  Else If S = 'TALLYING'          Then LookupKeyword := KW_TALLYING
  Else If S = 'REPLACING'         Then LookupKeyword := KW_REPLACING
  Else If S = 'CONVERTING'        Then LookupKeyword := KW_CONVERTING
  Else If S = 'POINTER'           Then LookupKeyword := KW_POINTER
  Else If S = 'OVERFLOW'          Then LookupKeyword := KW_OVERFLOW
  Else If S = 'END-OF-PAGE'       Then LookupKeyword := KW_END_OF_PAGE
  Else If S = 'EOP'               Then LookupKeyword := KW_EOP
  { Modes d ouverture }
  Else If S = 'INPUT'             Then LookupKeyword := KW_INPUT
  Else If S = 'OUTPUT'            Then LookupKeyword := KW_OUTPUT
  Else If S = 'I-O'               Then LookupKeyword := KW_I_O
  Else If S = 'EXTEND'            Then LookupKeyword := KW_EXTEND
  { Organisation de fichier }
  Else If S = 'SEQUENTIAL'        Then LookupKeyword := KW_SEQUENTIAL
  Else If S = 'RELATIVE'          Then LookupKeyword := KW_RELATIVE
  Else If S = 'INDEXED'           Then LookupKeyword := KW_INDEXED
  Else If S = 'LINE'              Then LookupKeyword := KW_LINE
  Else If S = 'DYNAMIC'           Then LookupKeyword := KW_DYNAMIC
  Else If S = 'RANDOM'            Then LookupKeyword := KW_RANDOM
  Else If S = 'ALTERNATE'         Then LookupKeyword := KW_ALTERNATE
  Else If S = 'KEY'               Then LookupKeyword := KW_KEY
  Else If S = 'DUPLICATES'        Then LookupKeyword := KW_DUPLICATES
  Else If S = 'TEST'              Then LookupKeyword := KW_TEST
  Else If S = 'DEPENDING'         Then LookupKeyword := KW_DEPENDING
  Else If S = 'PARAGRAPH'         Then LookupKeyword := KW_PARAGRAPH
  Else If S = 'CHARACTERS'        Then LookupKeyword := KW_CHARACTERS
  Else If S = 'FOR'               Then LookupKeyword := KW_FOR
  Else If S = 'INVALID'           Then LookupKeyword := KW_INVALID
  Else If S = 'AT'                Then LookupKeyword := KW_AT
  Else If S = 'PAGE'              Then LookupKeyword := KW_PAGE
  Else If S = 'CONSOLE'           Then LookupKeyword := KW_CONSOLE
  Else If S = 'PRINTER'           Then LookupKeyword := KW_PRINTER
  Else If S = 'DATE'              Then LookupKeyword := KW_DATE
  Else If S = 'DAY'               Then LookupKeyword := KW_DAY
  Else If S = 'DAY-OF-WEEK'       Then LookupKeyword := KW_DAY_OF_WEEK
  Else If S = 'TIME'              Then LookupKeyword := KW_TIME
  Else If S = 'RUN'               Then LookupKeyword := KW_RUN
  Else If S = 'NO'                Then LookupKeyword := KW_NO
  Else If S = 'END-DISPLAY'       Then LookupKeyword := KW_END_DISPLAY
  Else If S = 'END-ACCEPT'        Then LookupKeyword := KW_END_ACCEPT
  Else LookupKeyword := KW_NONE;
End;

{ ------------------------------------------------------------ }
{ KeywordName : retourne le nom d un mot-cle a partir de       }
{               sa constante KW_*                               }
{ ------------------------------------------------------------ }

Function KeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_IDENTIFICATION    : KeywordName := 'IDENTIFICATION';
    KW_ENVIRONMENT       : KeywordName := 'ENVIRONMENT';
    KW_DATA              : KeywordName := 'DATA';
    KW_PROCEDURE         : KeywordName := 'PROCEDURE';
    KW_DIVISION          : KeywordName := 'DIVISION';
    KW_CONFIGURATION     : KeywordName := 'CONFIGURATION';
    KW_INPUT_OUTPUT      : KeywordName := 'INPUT-OUTPUT';
    KW_FILE_CONTROL      : KeywordName := 'FILE-CONTROL';
    KW_FILE              : KeywordName := 'FILE';
    KW_WORKING_STORAGE   : KeywordName := 'WORKING-STORAGE';
    KW_LINKAGE           : KeywordName := 'LINKAGE';
    KW_SCREEN            : KeywordName := 'SCREEN';
    KW_REPORT            : KeywordName := 'REPORT';
    KW_SECTION           : KeywordName := 'SECTION';
    KW_LOCAL_STORAGE     : KeywordName := 'LOCAL-STORAGE';
    KW_PROGRAM_ID        : KeywordName := 'PROGRAM-ID';
    KW_AUTHOR            : KeywordName := 'AUTHOR';
    KW_INSTALLATION      : KeywordName := 'INSTALLATION';
    KW_DATE_WRITTEN      : KeywordName := 'DATE-WRITTEN';
    KW_DATE_COMPILED     : KeywordName := 'DATE-COMPILED';
    KW_SECURITY          : KeywordName := 'SECURITY';
    KW_SOURCE_COMPUTER   : KeywordName := 'SOURCE-COMPUTER';
    KW_OBJECT_COMPUTER   : KeywordName := 'OBJECT-COMPUTER';
    KW_SPECIAL_NAMES     : KeywordName := 'SPECIAL-NAMES';
    KW_REPOSITORY        : KeywordName := 'REPOSITORY';
    KW_ACCEPT            : KeywordName := 'ACCEPT';
    KW_ADD               : KeywordName := 'ADD';
    KW_CALL              : KeywordName := 'CALL';
    KW_CLOSE             : KeywordName := 'CLOSE';
    KW_COMPUTE           : KeywordName := 'COMPUTE';
    KW_CONTINUE          : KeywordName := 'CONTINUE';
    KW_DELETE            : KeywordName := 'DELETE';
    KW_DISPLAY           : KeywordName := 'DISPLAY';
    KW_DIVIDE            : KeywordName := 'DIVIDE';
    KW_EVALUATE          : KeywordName := 'EVALUATE';
    KW_EXIT              : KeywordName := 'EXIT';
    KW_GO                : KeywordName := 'GO';
    KW_GOBACK            : KeywordName := 'GOBACK';
    KW_IF                : KeywordName := 'IF';
    KW_INITIALIZE        : KeywordName := 'INITIALIZE';
    KW_INSPECT           : KeywordName := 'INSPECT';
    KW_MERGE             : KeywordName := 'MERGE';
    KW_MOVE              : KeywordName := 'MOVE';
    KW_MULTIPLY          : KeywordName := 'MULTIPLY';
    KW_OPEN              : KeywordName := 'OPEN';
    KW_PERFORM           : KeywordName := 'PERFORM';
    KW_READ              : KeywordName := 'READ';
    KW_RELEASE           : KeywordName := 'RELEASE';
    KW_RETURN            : KeywordName := 'RETURN';
    KW_REWRITE           : KeywordName := 'REWRITE';
    KW_SEARCH            : KeywordName := 'SEARCH';
    KW_SET               : KeywordName := 'SET';
    KW_SORT              : KeywordName := 'SORT';
    KW_START             : KeywordName := 'START';
    KW_STOP              : KeywordName := 'STOP';
    KW_STRING            : KeywordName := 'STRING';
    KW_SUBTRACT          : KeywordName := 'SUBTRACT';
    KW_UNSTRING          : KeywordName := 'UNSTRING';
    KW_WRITE             : KeywordName := 'WRITE';
    KW_PIC               : KeywordName := 'PIC';
    KW_PICTURE           : KeywordName := 'PICTURE';
    KW_VALUE             : KeywordName := 'VALUE';
    KW_USAGE             : KeywordName := 'USAGE';
    KW_OCCURS            : KeywordName := 'OCCURS';
    KW_REDEFINES         : KeywordName := 'REDEFINES';
    KW_RENAMES           : KeywordName := 'RENAMES';
    KW_FILLER            : KeywordName := 'FILLER';
    KW_BLANK             : KeywordName := 'BLANK';
    KW_JUSTIFIED         : KeywordName := 'JUSTIFIED';
    KW_SIGN              : KeywordName := 'SIGN';
    KW_SYNCHRONIZED      : KeywordName := 'SYNCHRONIZED';
    KW_COMP              : KeywordName := 'COMP';
    KW_COMP_1            : KeywordName := 'COMP-1';
    KW_COMP_2            : KeywordName := 'COMP-2';
    KW_COMP_3            : KeywordName := 'COMP-3';
    KW_BINARY            : KeywordName := 'BINARY';
    KW_PACKED_DECIMAL    : KeywordName := 'PACKED-DECIMAL';
    KW_INDEX             : KeywordName := 'INDEX';
    KW_SELECT            : KeywordName := 'SELECT';
    KW_ASSIGN            : KeywordName := 'ASSIGN';
    KW_ORGANIZATION      : KeywordName := 'ORGANIZATION';
    KW_ACCESS            : KeywordName := 'ACCESS';
    KW_STATUS            : KeywordName := 'STATUS';
    KW_RECORD            : KeywordName := 'RECORD';
    KW_LABEL             : KeywordName := 'LABEL';
    KW_FD                : KeywordName := 'FD';
    KW_SD                : KeywordName := 'SD';
    KW_ELSE              : KeywordName := 'ELSE';
    KW_END_IF            : KeywordName := 'END-IF';
    KW_WHEN              : KeywordName := 'WHEN';
    KW_END_EVALUATE      : KeywordName := 'END-EVALUATE';
    KW_END_PERFORM       : KeywordName := 'END-PERFORM';
    KW_END_READ          : KeywordName := 'END-READ';
    KW_END_SEARCH        : KeywordName := 'END-SEARCH';
    KW_END_STRING        : KeywordName := 'END-STRING';
    KW_END_UNSTRING      : KeywordName := 'END-UNSTRING';
    KW_END_COMPUTE       : KeywordName := 'END-COMPUTE';
    KW_END_ADD           : KeywordName := 'END-ADD';
    KW_END_SUBTRACT      : KeywordName := 'END-SUBTRACT';
    KW_END_MULTIPLY      : KeywordName := 'END-MULTIPLY';
    KW_END_DIVIDE        : KeywordName := 'END-DIVIDE';
    KW_END_CALL          : KeywordName := 'END-CALL';
    KW_END_WRITE         : KeywordName := 'END-WRITE';
    KW_END_RETURN        : KeywordName := 'END-RETURN';
    KW_END_REWRITE       : KeywordName := 'END-REWRITE';
    KW_END_START         : KeywordName := 'END-START';
    KW_END_DELETE        : KeywordName := 'END-DELETE';
    KW_AND               : KeywordName := 'AND';
    KW_OR                : KeywordName := 'OR';
    KW_NOT               : KeywordName := 'NOT';
    KW_EQUAL             : KeywordName := 'EQUAL';
    KW_GREATER           : KeywordName := 'GREATER';
    KW_LESS              : KeywordName := 'LESS';
    KW_NUMERIC           : KeywordName := 'NUMERIC';
    KW_ALPHABETIC        : KeywordName := 'ALPHABETIC';
    KW_POSITIVE          : KeywordName := 'POSITIVE';
    KW_NEGATIVE          : KeywordName := 'NEGATIVE';
    KW_ZERO              : KeywordName := 'ZERO';
    KW_ZEROS             : KeywordName := 'ZEROS';
    KW_ZEROES            : KeywordName := 'ZEROES';
    KW_SPACES            : KeywordName := 'SPACES';
    KW_HIGH_VALUES       : KeywordName := 'HIGH-VALUES';
    KW_HIGH_VALUE        : KeywordName := 'HIGH-VALUE';
    KW_LOW_VALUES        : KeywordName := 'LOW-VALUES';
    KW_LOW_VALUE         : KeywordName := 'LOW-VALUE';
    KW_ALPHABETIC_LOWER  : KeywordName := 'ALPHABETIC-LOWER';
    KW_ALPHABETIC_UPPER  : KeywordName := 'ALPHABETIC-UPPER';
    KW_TRUE              : KeywordName := 'TRUE';
    KW_FALSE             : KeywordName := 'FALSE';
    KW_THRU              : KeywordName := 'THRU';
    KW_THROUGH           : KeywordName := 'THROUGH';
    KW_TIMES             : KeywordName := 'TIMES';
    KW_UNTIL             : KeywordName := 'UNTIL';
    KW_VARYING           : KeywordName := 'VARYING';
    KW_GIVING            : KeywordName := 'GIVING';
    KW_REMAINDER         : KeywordName := 'REMAINDER';
    KW_ROUNDED           : KeywordName := 'ROUNDED';
    KW_SIZE              : KeywordName := 'SIZE';
    KW_ON                : KeywordName := 'ON';
    KW_INTO              : KeywordName := 'INTO';
    KW_FROM              : KeywordName := 'FROM';
    KW_TO                : KeywordName := 'TO';
    KW_BY                : KeywordName := 'BY';
    KW_IS                : KeywordName := 'IS';
    KW_ARE               : KeywordName := 'ARE';
    KW_OF                : KeywordName := 'OF';
    KW_IN                : KeywordName := 'IN';
    KW_THAN              : KeywordName := 'THAN';
    KW_ALSO              : KeywordName := 'ALSO';
    KW_WITH              : KeywordName := 'WITH';
    KW_ADVANCING         : KeywordName := 'ADVANCING';
    KW_BEFORE            : KeywordName := 'BEFORE';
    KW_AFTER             : KeywordName := 'AFTER';
    KW_ALL               : KeywordName := 'ALL';
    KW_LEADING           : KeywordName := 'LEADING';
    KW_TRAILING          : KeywordName := 'TRAILING';
    KW_FIRST             : KeywordName := 'FIRST';
    KW_INITIAL           : KeywordName := 'INITIAL';
    KW_CORRESPONDING     : KeywordName := 'CORRESPONDING';
    KW_CORR              : KeywordName := 'CORR';
    KW_UPON              : KeywordName := 'UPON';
    KW_USING             : KeywordName := 'USING';
    KW_RETURNING         : KeywordName := 'RETURNING';
    KW_REFERENCE         : KeywordName := 'REFERENCE';
    KW_CONTENT           : KeywordName := 'CONTENT';
    KW_DELIMITED         : KeywordName := 'DELIMITED';
    KW_DELIMITER         : KeywordName := 'DELIMITER';
    KW_COUNT             : KeywordName := 'COUNT';
    KW_TALLYING          : KeywordName := 'TALLYING';
    KW_REPLACING         : KeywordName := 'REPLACING';
    KW_CONVERTING        : KeywordName := 'CONVERTING';
    KW_POINTER           : KeywordName := 'POINTER';
    KW_OVERFLOW          : KeywordName := 'OVERFLOW';
    KW_END_OF_PAGE       : KeywordName := 'END-OF-PAGE';
    KW_EOP               : KeywordName := 'EOP';
    KW_INPUT             : KeywordName := 'INPUT';
    KW_OUTPUT            : KeywordName := 'OUTPUT';
    KW_I_O               : KeywordName := 'I-O';
    KW_EXTEND            : KeywordName := 'EXTEND';
    KW_SEQUENTIAL        : KeywordName := 'SEQUENTIAL';
    KW_RELATIVE          : KeywordName := 'RELATIVE';
    KW_INDEXED           : KeywordName := 'INDEXED';
    KW_LINE              : KeywordName := 'LINE';
    KW_DYNAMIC           : KeywordName := 'DYNAMIC';
    KW_RANDOM            : KeywordName := 'RANDOM';
    KW_ALTERNATE         : KeywordName := 'ALTERNATE';
    KW_KEY               : KeywordName := 'KEY';
    KW_DUPLICATES        : KeywordName := 'DUPLICATES';
    KW_TEST              : KeywordName := 'TEST';
    KW_DEPENDING         : KeywordName := 'DEPENDING';
    KW_PARAGRAPH         : KeywordName := 'PARAGRAPH';
    KW_CHARACTERS        : KeywordName := 'CHARACTERS';
    KW_FOR               : KeywordName := 'FOR';
    KW_INVALID           : KeywordName := 'INVALID';
    KW_AT                : KeywordName := 'AT';
    KW_PAGE              : KeywordName := 'PAGE';
    KW_CONSOLE           : KeywordName := 'CONSOLE';
    KW_PRINTER           : KeywordName := 'PRINTER';
    KW_DATE              : KeywordName := 'DATE';
    KW_DAY               : KeywordName := 'DAY';
    KW_DAY_OF_WEEK       : KeywordName := 'DAY-OF-WEEK';
    KW_TIME              : KeywordName := 'TIME';
    KW_RUN               : KeywordName := 'RUN';
    KW_NO                : KeywordName := 'NO';
    KW_END_DISPLAY       : KeywordName := 'END-DISPLAY';
    KW_END_ACCEPT        : KeywordName := 'END-ACCEPT';
  Else
    KeywordName := '?KW' + ItoSI(KW);
  End;
End;

{ ------------------------------------------------------------ }
{ KeywordCategoryName : retourne la categorie d un mot-cle     }
{ ------------------------------------------------------------ }

Function KeywordCategoryName(KW : Integer) : TString;
Begin
  If (KW >= 1) And (KW <= 5) Then
    KeywordCategoryName := 'Division'
  Else If (KW >= 10) And (KW <= 19) Then
    KeywordCategoryName := 'Section'
  Else If (KW >= 20) And (KW <= 25) Then
    KeywordCategoryName := 'Paragraph-ID'
  Else If (KW >= 30) And (KW <= 33) Then
    KeywordCategoryName := 'Paragraph-ENV'
  Else If (KW >= 40) And (KW <= 73) Then
    KeywordCategoryName := 'Instruction'
  Else If (KW >= 80) And (KW <= 98) Then
    KeywordCategoryName := 'Clause-DATA'
  Else If (KW >= 100) And (KW <= 109) Then
    KeywordCategoryName := 'Clause-FILE'
  Else If (KW >= 110) And (KW <= 129) Then
    KeywordCategoryName := 'Structure'
  Else If (KW >= 130) And (KW <= 199) Then
    KeywordCategoryName := 'Condition/Divers'
  Else If (KW >= 200) And (KW <= 218) Then
    KeywordCategoryName := 'Fichier'
  Else
    KeywordCategoryName := 'Inconnu';
End;

{ ------------------------------------------------------------ }
{ IsVerbKeyword : teste si un mot-cle est un verbe COBOL       }
{ (instruction executable)                                      }
{ ------------------------------------------------------------ }

Function IsVerbKeyword(KW : Integer) : Boolean;
Begin
  IsVerbKeyword := (KW >= 40) And (KW <= 73);
End;

{ ------------------------------------------------------------ }
{ IsEndKeyword : teste si un mot-cle est un END-xxx            }
{ ------------------------------------------------------------ }

Function IsEndKeyword(KW : Integer) : Boolean;
Begin
  IsEndKeyword := (KW >= 111) And (KW <= 129);
End;

{ ------------------------------------------------------------ }
{ IsConditionKeyword : teste si c est un mot-cle de condition  }
{ ------------------------------------------------------------ }

Function IsConditionKeyword(KW : Integer) : Boolean;
Begin
  IsConditionKeyword := (KW >= 130) And (KW <= 147);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour TODO 03                         }
{ ------------------------------------------------------------ }

Function IsKwInitialized : Boolean;
Begin
  IsKwInitialized := KwInitialized;
End;

Function IsKwEmpty : Boolean;
Begin
  IsKwEmpty := (KwCount = 0);
End;

Function GetKwCount : Integer;
Begin
  GetKwCount := KwCount;
End;

Function GetKwStatus : TString;
Begin
  If Not KwInitialized Then
    GetKwStatus := 'Not initialized'
  Else
    GetKwStatus := 'Initialized (' + ItoS(KwCount) + ' lookups)';
End;

Function GetKwTotalKeywords : Integer;
Begin
  GetKwTotalKeywords := KW_TOTAL_KEYWORDS;
End;

Function GetKwDivisionCount : Integer;
Begin
  GetKwDivisionCount := 5;
End;

Function GetKwSectionCount : Integer;
Begin
  GetKwSectionCount := 10;
End;

Function GetKwVerbCount : Integer;
Begin
  GetKwVerbCount := 34;
End;

Function GetKwClauseCount : Integer;
Begin
  GetKwClauseCount := 29;
End;

Function GetKwConditionCount : Integer;
Begin
  GetKwConditionCount := 22;
End;


{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES COBOL (32 BITS) [IMPLEMENTE]   }
{ ============================================================ }

Const
  { Types de donnees COBOL (CBT_*) }
  CBT_NONE           = 0;   { non defini / inconnu                  }
  CBT_ALPHA          = 1;   { alphabetique (PIC A)                  }
  CBT_NUMERIC        = 2;   { numerique affichable (PIC 9)          }
  CBT_ALPHANUMERIC   = 3;   { alphanumerique (PIC X)                }
  CBT_PACKED         = 4;   { decimal condense (COMP-3)             }
  CBT_BINARY         = 5;   { binaire (COMP, COMP-4, BINARY)        }
  CBT_INDEX          = 6;   { index (USAGE INDEX)                   }
  CBT_POINTER        = 7;   { pointeur (USAGE POINTER)              }
  CBT_GROUP          = 8;   { groupe (pas de PIC)                   }
  CBT_FILE           = 9;   { fichier (FD/SD)                       }
  CBT_CONDITION      = 10;  { condition (niveau 88)                 }
  CBT_COMP1          = 11;  { flottant simple precision (COMP-1)    }
  CBT_COMP2          = 12;  { flottant double precision (COMP-2)    }
  CBT_EDITED_NUM     = 13;  { numerique edite (PIC Z, *, $, etc.)   }
  CBT_EDITED_ALPHA   = 14;  { alphanumerique edite (PIC B, 0, /)    }

  { Sections de la DATA DIVISION (SEC_*) }
  SEC_NONE            = 0;   { pas de section                       }
  SEC_WORKING_STORAGE = 1;   { WORKING-STORAGE SECTION              }
  SEC_FILE            = 2;   { FILE SECTION                         }
  SEC_LINKAGE         = 3;   { LINKAGE SECTION                      }
  SEC_LOCAL_STORAGE   = 4;   { LOCAL-STORAGE SECTION                }
  SEC_SCREEN          = 5;   { SCREEN SECTION                       }
  SEC_REPORT          = 6;   { REPORT SECTION                       }

  { Clause USAGE (USG_*) }
  USG_DISPLAY         = 0;   { DISPLAY (par defaut)                 }
  USG_COMP            = 1;   { COMP / COMPUTATIONAL / BINARY        }
  USG_COMP1           = 2;   { COMP-1 (flottant simple)             }
  USG_COMP2           = 3;   { COMP-2 (flottant double)             }
  USG_COMP3           = 4;   { COMP-3 / PACKED-DECIMAL              }
  USG_COMP4           = 5;   { COMP-4 (synonyme COMP/BINARY)        }
  USG_COMP5           = 6;   { COMP-5 (binaire natif)               }
  USG_INDEX           = 7;   { INDEX                                }
  USG_POINTER         = 8;   { POINTER                              }

  { Tailles en octets }
  CBT_SIZE_INDEX     = 4;   { index COBOL = 32 bits                 }
  CBT_SIZE_POINTER   = 4;   { pointeur = 32 bits                    }
  CBT_SIZE_COMP1     = 4;   { COMP-1 = 32 bits flottant             }
  CBT_SIZE_COMP2     = 8;   { COMP-2 = 64 bits flottant             }

  { Nombre maximum de valeurs pour un niveau 88 }
  MAX_COND_VALUES    = 16;

Type
  { Entree dans la table des symboles COBOL }
  TSymbol = Record
    Name         : String[64];   { nom COBOL (WS-NOM, EMP-RECORD)    }
    AsmName      : String[64];   { label ASM (_COB_WS_NOM)           }
    Level        : Integer;      { niveau (01-49, 66, 77, 88)        }
    SymType      : Integer;      { CBT_ALPHA, CBT_NUMERIC, ...       }
    PicStr       : String[64];   { chaine PICTURE originale           }
    PicSize      : Integer;      { taille en octets                   }
    PicDecimals  : Integer;      { decimales (V dans PIC)             }
    IsSigned     : Boolean;      { PIC S9(...)                        }
    IsGroup      : Boolean;      { True si groupe (pas de PIC)        }
    ParentIdx    : Integer;      { index du symbole parent (-1=aucun) }
    Offset       : Integer;      { offset dans le groupe/record       }
    Value        : String[64];   { valeur initiale (VALUE)            }
    IsGlobal     : Boolean;      { portee globale                     }
    Section      : Integer;      { SEC_WORKING_STORAGE, etc.          }
    Occurs       : Integer;      { repetitions (OCCURS)               }
    OccursMin    : Integer;      { OCCURS min (DEPENDING ON)          }
    OccursDep    : String[64];   { variable DEPENDING ON              }
    RedefinedIdx : Integer;      { index redefini (REDEFINES, -1=non) }
    CondValues   : Array[0..MAX_COND_VALUES - 1] Of String[32];
    CondValCount : Integer;      { nombre de valeurs niveau 88        }
    Usage        : Integer;      { USG_DISPLAY, USG_COMP, etc.        }
    IsExternal   : Boolean;      { clause EXTERNAL                    }
    IsFiller     : Boolean;      { True si FILLER                     }
  End;

Var
  { Table des symboles }
  SymTab           : Array[0..MAX_SYM - 1] Of TSymbol;
  SymCount         : Integer;
  SymInitialized   : Boolean;
  SymStateCount    : Integer;

{ ------------------------------------------------------------ }
{ CobTypeName : nom textuel d un type COBOL                    }
{ ------------------------------------------------------------ }

Function CobTypeName(T : Integer) : TString;
Begin
  Case T Of
    CBT_NONE         : CobTypeName := '(none)';
    CBT_ALPHA        : CobTypeName := 'Alphabetic';
    CBT_NUMERIC      : CobTypeName := 'Numeric';
    CBT_ALPHANUMERIC : CobTypeName := 'Alphanumeric';
    CBT_PACKED       : CobTypeName := 'Packed-Decimal';
    CBT_BINARY       : CobTypeName := 'Binary';
    CBT_INDEX        : CobTypeName := 'Index';
    CBT_POINTER      : CobTypeName := 'Pointer';
    CBT_GROUP        : CobTypeName := 'Group';
    CBT_FILE         : CobTypeName := 'File';
    CBT_CONDITION    : CobTypeName := 'Condition';
    CBT_COMP1        : CobTypeName := 'Comp-1';
    CBT_COMP2        : CobTypeName := 'Comp-2';
    CBT_EDITED_NUM   : CobTypeName := 'Numeric-Edited';
    CBT_EDITED_ALPHA : CobTypeName := 'Alphanumeric-Edited';
  Else
    CobTypeName := '?CBT' + ItoSI(T);
  End;
End;

{ ------------------------------------------------------------ }
{ CobUsageName : nom textuel d une clause USAGE                }
{ ------------------------------------------------------------ }

Function CobUsageName(U : Integer) : TString;
Begin
  Case U Of
    USG_DISPLAY : CobUsageName := 'DISPLAY';
    USG_COMP    : CobUsageName := 'COMP';
    USG_COMP1   : CobUsageName := 'COMP-1';
    USG_COMP2   : CobUsageName := 'COMP-2';
    USG_COMP3   : CobUsageName := 'COMP-3';
    USG_COMP4   : CobUsageName := 'COMP-4';
    USG_COMP5   : CobUsageName := 'COMP-5';
    USG_INDEX   : CobUsageName := 'INDEX';
    USG_POINTER : CobUsageName := 'POINTER';
  Else
    CobUsageName := '?USG' + ItoSI(U);
  End;
End;

{ ------------------------------------------------------------ }
{ CobSectionName : nom textuel d une section DATA              }
{ ------------------------------------------------------------ }

Function CobSectionName(SC : Integer) : TString;
Begin
  Case SC Of
    SEC_NONE            : CobSectionName := '(none)';
    SEC_WORKING_STORAGE : CobSectionName := 'WORKING-STORAGE';
    SEC_FILE            : CobSectionName := 'FILE';
    SEC_LINKAGE         : CobSectionName := 'LINKAGE';
    SEC_LOCAL_STORAGE   : CobSectionName := 'LOCAL-STORAGE';
    SEC_SCREEN          : CobSectionName := 'SCREEN';
    SEC_REPORT          : CobSectionName := 'REPORT';
  Else
    CobSectionName := '?SEC' + ItoSI(SC);
  End;
End;

{ ------------------------------------------------------------ }
{ SymInit : initialiser la table des symboles                  }
{ ------------------------------------------------------------ }

Procedure SymInit;
Var
  I, J : Integer;
Begin
  SymCount       := 0;
  SymInitialized := True;
  SymStateCount  := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name         := '';
    SymTab[I].AsmName      := '';
    SymTab[I].Level        := 0;
    SymTab[I].SymType      := CBT_NONE;
    SymTab[I].PicStr       := '';
    SymTab[I].PicSize      := 0;
    SymTab[I].PicDecimals  := 0;
    SymTab[I].IsSigned     := False;
    SymTab[I].IsGroup      := False;
    SymTab[I].ParentIdx    := -1;
    SymTab[I].Offset       := 0;
    SymTab[I].Value        := '';
    SymTab[I].IsGlobal     := False;
    SymTab[I].Section      := SEC_NONE;
    SymTab[I].Occurs       := 0;
    SymTab[I].OccursMin    := 0;
    SymTab[I].OccursDep    := '';
    SymTab[I].RedefinedIdx := -1;
    For J := 0 To MAX_COND_VALUES - 1 Do
      SymTab[I].CondValues[J] := '';
    SymTab[I].CondValCount := 0;
    SymTab[I].Usage        := USG_DISPLAY;
    SymTab[I].IsExternal   := False;
    SymTab[I].IsFiller     := False;
  End;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                    }
{ Retourne l index du nouveau symbole ou -1 si plein           }
{ ------------------------------------------------------------ }

Function SymAdd(Const AName : TString; ALevel : Integer;
                AType : Integer; ASection : Integer) : Integer;
Var
  Idx, J : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    FatalError('Table des symboles pleine (max ' + ItoSI(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name         := AName;
  SymTab[Idx].Level        := ALevel;
  SymTab[Idx].SymType      := AType;
  SymTab[Idx].Section      := ASection;
  SymTab[Idx].PicStr       := '';
  SymTab[Idx].PicSize      := 0;
  SymTab[Idx].PicDecimals  := 0;
  SymTab[Idx].IsSigned     := False;
  SymTab[Idx].IsGroup      := (AType = CBT_GROUP);
  SymTab[Idx].ParentIdx    := -1;
  SymTab[Idx].Offset       := 0;
  SymTab[Idx].Value        := '';
  SymTab[Idx].IsGlobal     := False;
  SymTab[Idx].Occurs       := 0;
  SymTab[Idx].OccursMin    := 0;
  SymTab[Idx].OccursDep    := '';
  SymTab[Idx].RedefinedIdx := -1;
  For J := 0 To MAX_COND_VALUES - 1 Do
    SymTab[Idx].CondValues[J] := '';
  SymTab[Idx].CondValCount := 0;
  SymTab[Idx].Usage        := USG_DISPLAY;
  SymTab[Idx].IsExternal   := False;
  SymTab[Idx].IsFiller     := (UpCaseStr(AName) = 'FILLER');

  { Generer le label assembleur }
  If SymTab[Idx].IsFiller Then
    SymTab[Idx].AsmName := PFX_VAR + 'FILLER_' + ItoSI(Idx)
  Else If ALevel = 0 Then
    { Fichier (FD/SD) }
    SymTab[Idx].AsmName := PFX_FLD + AsmIdent(AName)
  Else If ASection = SEC_FILE Then
    SymTab[Idx].AsmName := PFX_ENT + AsmIdent(AName)
  Else
    SymTab[Idx].AsmName := PFX_VAR + AsmIdent(AName);

  Inc(SymCount);
  Inc(SymStateCount);
  SymAdd := Idx;
End;

{ ------------------------------------------------------------ }
{ SymFind : chercher un symbole par nom (insensible a la casse) }
{ Retourne l index ou -1 si non trouve                          }
{ ------------------------------------------------------------ }

Function SymFind(Const S : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := UpCaseStr(S);
  SymFind := -1;
  For I := 0 To SymCount - 1 Do
  Begin
    If UpCaseStr(SymTab[I].Name) = U Then
    Begin
      SymFind := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ SymFindQualified : chercher symbole qualifie (NOM OF PARENT) }
{ En COBOL on peut ecrire EMP-NOM OF EMP-RECORD pour lever     }
{ l ambiguite si plusieurs champs ont le meme nom               }
{ Retourne l index ou -1 si non trouve                          }
{ ------------------------------------------------------------ }

Function SymFindQualified(Const AName : TString;
                          Const AParent : TString) : Integer;
Var
  I, P : Integer;
  UN, UP : TString;
Begin
  UN := UpCaseStr(AName);
  UP := UpCaseStr(AParent);
  SymFindQualified := -1;
  For I := 0 To SymCount - 1 Do
  Begin
    If UpCaseStr(SymTab[I].Name) = UN Then
    Begin
      { Verifier la parentee }
      P := SymTab[I].ParentIdx;
      While P >= 0 Do
      Begin
        If UpCaseStr(SymTab[P].Name) = UP Then
        Begin
          SymFindQualified := I;
          Exit;
        End;
        P := SymTab[P].ParentIdx;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ SymDump : afficher le contenu de la table (debug)            }
{ ------------------------------------------------------------ }

Procedure SymDump;
Var I : Integer;
Begin
  WriteLn('--- Table des symboles COBOL (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Write('  [', I:4, '] Lv ', SymTab[I].Level:2);
    Write(' ', SymTab[I].Name);
    If SymTab[I].IsGroup Then
      Write(' (GROUP)')
    Else If SymTab[I].PicStr <> '' Then
      Write(' PIC ', SymTab[I].PicStr,
            ' (', SymTab[I].PicSize, ' bytes)');
    If SymTab[I].IsSigned Then
      Write(' SIGNED');
    If SymTab[I].PicDecimals > 0 Then
      Write(' V', SymTab[I].PicDecimals);
    If SymTab[I].Usage <> USG_DISPLAY Then
      Write(' USAGE ', CobUsageName(SymTab[I].Usage));
    If SymTab[I].Value <> '' Then
      Write(' VALUE ', SymTab[I].Value);
    If SymTab[I].Occurs > 0 Then
      Write(' OCCURS ', SymTab[I].Occurs);
    If SymTab[I].IsFiller Then
      Write(' (FILLER)');
    If SymTab[I].IsExternal Then
      Write(' EXTERNAL');
    If SymTab[I].RedefinedIdx >= 0 Then
      Write(' REDEFINES [', SymTab[I].RedefinedIdx, ']');
    If SymTab[I].ParentIdx >= 0 Then
      Write(' parent=[', SymTab[I].ParentIdx, ']');
    Write(' sec=', CobSectionName(SymTab[I].Section));
    Write(' asm=', SymTab[I].AsmName);
    WriteLn;
  End;
  WriteLn('--- Fin de la table ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour TODO 04                         }
{ ------------------------------------------------------------ }

Function IsSymInitialized : Boolean;
Begin
  IsSymInitialized := SymInitialized;
End;

Function IsSymEmpty : Boolean;
Begin
  IsSymEmpty := (SymCount = 0);
End;

Function GetSymCount : Integer;
Begin
  GetSymCount := SymCount;
End;

Function GetSymStatus : TString;
Begin
  If Not SymInitialized Then
    GetSymStatus := 'Not initialized'
  Else
    GetSymStatus := 'Initialized (' + ItoS(SymCount) + ' symbols)';
End;

Function GetSymMaxSymbols : Integer;
Begin
  GetSymMaxSymbols := MAX_SYM;
End;

Function GetSymStateCount : Integer;
Begin
  GetSymStateCount := SymStateCount;
End;

Function GetSymTypeCount : Integer;
Begin
  { Nombre de types CBT_* definis }
  GetSymTypeCount := 15;
End;

Function GetSymSectionCount : Integer;
Begin
  { Nombre de sections SEC_* definies }
  GetSymSectionCount := 7;
End;

Function GetSymUsageCount : Integer;
Begin
  { Nombre de clauses USG_* definies }
  GetSymUsageCount := 9;
End;

Function GetSymMaxCondValues : Integer;
Begin
  GetSymMaxCondValues := MAX_COND_VALUES;
End;


{ ============================================================ }
{ TODO 05 - GESTION DES NIVEAUX ET HIERARCHIE COBOL            }
{           [IMPLEMENTE]                                        }
{ ============================================================ }

Const
  { Niveaux speciaux COBOL }
  LVL_RECORD     = 1;    { niveau 01 : debut de record/groupe      }
  LVL_RENAMES    = 66;   { niveau 66 : RENAMES                     }
  LVL_INDEPEND   = 77;   { niveau 77 : independant (pas de groupe) }
  LVL_CONDITION  = 88;   { niveau 88 : condition nommee            }
  LVL_MIN_HIER   = 1;    { niveau minimum hierarchique             }
  LVL_MAX_HIER   = 49;   { niveau maximum hierarchique             }

  { Limites pour la pile de niveaux }
  HLV_MAX_DEPTH   = 50;  { profondeur max de la pile de niveaux    }
  HLV_MAX_RECORDS = 256; { nombre max de records 01                }

Var
  { Pile de niveaux pour construction de la hierarchie }
  HlvLevelStack  : Array[0..HLV_MAX_DEPTH - 1] Of Integer;  { niveaux }
  HlvParentStack : Array[0..HLV_MAX_DEPTH - 1] Of Integer;  { index sym }
  HlvDepth       : Integer;   { profondeur courante                  }
  HlvCurRecord   : Integer;   { index du record 01 courant (-1=aucun)}
  HlvInitialized : Boolean;
  HlvStateCount  : Integer;   { compteur d etats                     }
  HlvRecordCount : Integer;   { nombre de records 01 traites         }
  HlvTotalSize   : LongInt;   { taille totale de tous les records    }
  HlvRedefinesCount : Integer; { nombre de REDEFINES traites         }
  HlvRenamesCount   : Integer; { nombre de RENAMES traites           }
  HlvConditionCount : Integer; { nombre de conditions 88 traitees    }

{ ------------------------------------------------------------ }
{ InitLevelState : initialise la pile et les compteurs          }
{ ------------------------------------------------------------ }

Procedure InitLevelState;
Var I : Integer;
Begin
  HlvDepth       := 0;
  HlvCurRecord   := -1;
  HlvInitialized := True;
  HlvStateCount  := 0;
  HlvRecordCount := 0;
  HlvTotalSize   := 0;
  HlvRedefinesCount := 0;
  HlvRenamesCount   := 0;
  HlvConditionCount := 0;
  For I := 0 To HLV_MAX_DEPTH - 1 Do
  Begin
    HlvLevelStack[I]  := 0;
    HlvParentStack[I] := -1;
  End;
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ IsValidLevel : verifie si un numero de niveau COBOL est valide}
{ Niveaux valides : 01-49, 66, 77, 88                          }
{ ------------------------------------------------------------ }

Function IsValidLevel(Lv : Integer) : Boolean;
Begin
  IsValidLevel := ((Lv >= LVL_MIN_HIER) And (Lv <= LVL_MAX_HIER))
                  Or (Lv = LVL_RENAMES)
                  Or (Lv = LVL_INDEPEND)
                  Or (Lv = LVL_CONDITION);
End;

{ ------------------------------------------------------------ }
{ IsSpecialLevel : teste si un niveau est special (66, 77, 88) }
{ ------------------------------------------------------------ }

Function IsSpecialLevel(Lv : Integer) : Boolean;
Begin
  IsSpecialLevel := (Lv = LVL_RENAMES)
                    Or (Lv = LVL_INDEPEND)
                    Or (Lv = LVL_CONDITION);
End;

{ ------------------------------------------------------------ }
{ LevelCategoryName : nom de la categorie d un niveau           }
{   01       -> Record                                          }
{   02-49    -> Hierarchical                                    }
{   66       -> Renames                                         }
{   77       -> Independent                                     }
{   88       -> Condition                                       }
{ ------------------------------------------------------------ }

Function LevelCategoryName(Lv : Integer) : TString;
Begin
  If Lv = LVL_RECORD Then
    LevelCategoryName := 'Record'
  Else If (Lv >= 2) And (Lv <= LVL_MAX_HIER) Then
    LevelCategoryName := 'Hierarchical'
  Else If Lv = LVL_RENAMES Then
    LevelCategoryName := 'Renames'
  Else If Lv = LVL_INDEPEND Then
    LevelCategoryName := 'Independent'
  Else If Lv = LVL_CONDITION Then
    LevelCategoryName := 'Condition'
  Else
    LevelCategoryName := '(invalid)';
End;

{ ------------------------------------------------------------ }
{ PushLevel : empiler un niveau et l index du symbole associe   }
{ ------------------------------------------------------------ }

Procedure PushLevel(Lv : Integer; SymIdx : Integer);
Begin
  If HlvDepth >= HLV_MAX_DEPTH Then
  Begin
    WarnMsg('Profondeur de niveaux COBOL depasse (max ' +
            ItoSI(HLV_MAX_DEPTH) + ')');
    Exit;
  End;
  HlvLevelStack[HlvDepth]  := Lv;
  HlvParentStack[HlvDepth] := SymIdx;
  Inc(HlvDepth);
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ PopLevel : depiler jusqu a atteindre un niveau < Lv           }
{ Retourne l index du nouveau parent ou -1                      }
{ ------------------------------------------------------------ }

Function PopLevel(Lv : Integer) : Integer;
Begin
  { Remonter la pile : depiler tant que le sommet a un niveau >= Lv }
  While (HlvDepth > 0) And (HlvLevelStack[HlvDepth - 1] >= Lv) Do
  Begin
    Dec(HlvDepth);
    Inc(HlvStateCount);
  End;
  { Le parent est maintenant le sommet de la pile }
  If HlvDepth > 0 Then
    PopLevel := HlvParentStack[HlvDepth - 1]
  Else
    PopLevel := -1;
End;

{ ------------------------------------------------------------ }
{ FindParentForLevel : trouver le parent correct pour un niveau }
{ donné selon la hiérarchie COBOL                               }
{ Niveau 01 : pas de parent (-1)                                }
{ Niveau 77 : pas de parent (-1)                                }
{ Niveau 88 : parent = dernier symbole ajouté                  }
{ Niveau 66 : parent = record 01 courant                        }
{ Niveaux 02-49 : dernier symbole dont le niveau < Lv          }
{ ------------------------------------------------------------ }

Function FindParentForLevel(Lv : Integer) : Integer;
Begin
  If (Lv = LVL_RECORD) Or (Lv = LVL_INDEPEND) Then
  Begin
    { Niveau 01 ou 77 : pas de parent }
    FindParentForLevel := -1;
  End
  Else If Lv = LVL_CONDITION Then
  Begin
    { Niveau 88 : parent = dernier symbole non-88 dans la table }
    If SymCount > 0 Then
      FindParentForLevel := SymCount - 1
    Else
      FindParentForLevel := -1;
  End
  Else If Lv = LVL_RENAMES Then
  Begin
    { Niveau 66 : parent = record 01 courant }
    FindParentForLevel := HlvCurRecord;
  End
  Else
  Begin
    { Niveaux 02-49 : depiler et trouver le parent }
    FindParentForLevel := PopLevel(Lv);
  End;
End;

{ ------------------------------------------------------------ }
{ BuildHierarchy : construire l arbre hierarchique en parcourant}
{ la table des symboles. Assigne ParentIdx, detecte les records }
{ et gere la pile de niveaux                                    }
{ ------------------------------------------------------------ }

Procedure BuildHierarchy;
Var
  I, Lv, ParIdx : Integer;
Begin
  HlvDepth     := 0;
  HlvCurRecord := -1;
  HlvRecordCount := 0;

  For I := 0 To SymCount - 1 Do
  Begin
    Lv := SymTab[I].Level;

    If Not IsValidLevel(Lv) Then
    Begin
      WarnMsg('Niveau invalide ' + ItoSI(Lv) +
              ' pour le symbole ' + SymTab[I].Name);
      Continue;
    End;

    If Lv = LVL_RECORD Then
    Begin
      { Nouveau record 01 : reset de la pile }
      HlvDepth := 0;
      HlvCurRecord := I;
      Inc(HlvRecordCount);
      SymTab[I].ParentIdx := -1;
      SymTab[I].IsGroup   := True;
      PushLevel(Lv, I);
    End
    Else If Lv = LVL_INDEPEND Then
    Begin
      { Niveau 77 : independant, pas de parent }
      SymTab[I].ParentIdx := -1;
    End
    Else If Lv = LVL_CONDITION Then
    Begin
      { Niveau 88 : parent = dernier symbole ajouté avant celui-ci }
      ParIdx := FindParentForLevel(Lv);
      SymTab[I].ParentIdx := ParIdx;
      SymTab[I].SymType   := CBT_CONDITION;
      Inc(HlvConditionCount);
    End
    Else If Lv = LVL_RENAMES Then
    Begin
      { Niveau 66 : parent = record 01 courant }
      SymTab[I].ParentIdx := HlvCurRecord;
      Inc(HlvRenamesCount);
    End
    Else
    Begin
      { Niveaux 02-49 : hierarchique }
      ParIdx := FindParentForLevel(Lv);
      SymTab[I].ParentIdx := ParIdx;
      { Si le parent n est pas un groupe, le marquer comme tel }
      If (ParIdx >= 0) And (Not SymTab[ParIdx].IsGroup) Then
        SymTab[ParIdx].IsGroup := True;
      PushLevel(Lv, I);
    End;
  End;
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ CalcGroupSize : calculer la taille d un groupe recursivement  }
{ Additionne les PicSize des enfants directs                    }
{ Pour les sous-groupes, recurse                                }
{ Tient compte de OCCURS pour multiplier la taille              }
{ ------------------------------------------------------------ }

Function CalcGroupSize(GrpIdx : Integer) : Integer;
Var
  I, Size, ChildSize, Occ : Integer;
Begin
  Size := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].ParentIdx = GrpIdx Then
    Begin
      { Ignorer les niveaux 88 et 66 dans le calcul de taille }
      If (SymTab[I].Level = LVL_CONDITION) Or
         (SymTab[I].Level = LVL_RENAMES) Then
        Continue;
      { Ignorer les REDEFINES (partagent la meme memoire) }
      If SymTab[I].RedefinedIdx >= 0 Then
        Continue;

      If SymTab[I].IsGroup Then
        ChildSize := CalcGroupSize(I)
      Else
        ChildSize := SymTab[I].PicSize;

      Occ := SymTab[I].Occurs;
      If Occ > 1 Then
        ChildSize := ChildSize * Occ;

      Size := Size + ChildSize;
    End;
  End;
  { Mettre a jour la taille du groupe }
  SymTab[GrpIdx].PicSize := Size;
  CalcGroupSize := Size;
End;

{ ------------------------------------------------------------ }
{ CalcRecordOffsets : calculer les offsets dans un record 01     }
{ Parcourt les enfants directs dans l ordre et assigne l offset  }
{ ------------------------------------------------------------ }

Procedure CalcRecordOffsets(RecIdx : Integer);
Var
  I, CurOffset, ChildSize, Occ : Integer;
Begin
  CurOffset := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].ParentIdx = RecIdx Then
    Begin
      { Ignorer niveaux 88 et 66 }
      If (SymTab[I].Level = LVL_CONDITION) Or
         (SymTab[I].Level = LVL_RENAMES) Then
        Continue;

      { REDEFINES : meme offset que le champ redefini }
      If SymTab[I].RedefinedIdx >= 0 Then
      Begin
        SymTab[I].Offset := SymTab[SymTab[I].RedefinedIdx].Offset;
        { Calculer les offsets des sous-champs si c est un groupe }
        If SymTab[I].IsGroup Then
          CalcRecordOffsets(I);
        Continue;
      End;

      SymTab[I].Offset := CurOffset;

      If SymTab[I].IsGroup Then
      Begin
        CalcRecordOffsets(I);
        ChildSize := SymTab[I].PicSize;
      End
      Else
        ChildSize := SymTab[I].PicSize;

      Occ := SymTab[I].Occurs;
      If Occ > 1 Then
        ChildSize := ChildSize * Occ;

      CurOffset := CurOffset + ChildSize;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ HandleRedefines : traiter la clause REDEFINES                 }
{ Assigne l offset du champ redefini et verifie la coherence    }
{ ------------------------------------------------------------ }

Procedure HandleRedefines;
Var
  I, RedIdx : Integer;
Begin
  HlvRedefinesCount := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].RedefinedIdx >= 0 Then
    Begin
      RedIdx := SymTab[I].RedefinedIdx;
      { Verifier que le champ redefini existe }
      If (RedIdx >= 0) And (RedIdx < SymCount) Then
      Begin
        { L offset est le meme que le champ redefini }
        SymTab[I].Offset := SymTab[RedIdx].Offset;
        Inc(HlvRedefinesCount);
      End
      Else
        WarnMsg('REDEFINES invalide pour ' + SymTab[I].Name +
                ' : index ' + ItoSI(RedIdx));
    End;
  End;
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ HandleRenames : traiter le niveau 66 (RENAMES)                }
{ Le niveau 66 regroupe un ensemble de champs contigus          }
{ ------------------------------------------------------------ }

Procedure HandleRenames;
Var
  I : Integer;
Begin
  HlvRenamesCount := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].Level = LVL_RENAMES Then
    Begin
      { Le parent est le record 01 }
      { Le type est alphanumerique par defaut (regroupement) }
      If SymTab[I].SymType = CBT_NONE Then
        SymTab[I].SymType := CBT_ALPHANUMERIC;
      Inc(HlvRenamesCount);
    End;
  End;
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ HandleCondition88 : traiter les conditions nommees (niveau 88)}
{ Le niveau 88 definit des conditions sur le champ parent       }
{ SET FINI TO TRUE -> MOVE valeur TO parent                     }
{ ------------------------------------------------------------ }

Procedure HandleCondition88;
Var
  I : Integer;
Begin
  HlvConditionCount := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].Level = LVL_CONDITION Then
    Begin
      { Le type est toujours CBT_CONDITION }
      SymTab[I].SymType := CBT_CONDITION;
      { Pas de PIC propre, pas de taille }
      SymTab[I].PicStr  := '';
      SymTab[I].PicSize := 0;
      Inc(HlvConditionCount);
    End;
  End;
  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ ResolveAllHierarchy : resolution complete de la hierarchie    }
{ 1. BuildHierarchy : parents, pile de niveaux                  }
{ 2. HandleRedefines : partage memoire                          }
{ 3. HandleRenames : regroupements niveau 66                    }
{ 4. HandleCondition88 : conditions nommees                     }
{ 5. CalcGroupSize : tailles de tous les groupes                }
{ 6. CalcRecordOffsets : offsets dans chaque record              }
{ ------------------------------------------------------------ }

Procedure ResolveAllHierarchy;
Var
  I : Integer;
Begin
  { Etape 1 : construire l arbre hierarchique }
  BuildHierarchy;

  { Etape 2 : traiter les REDEFINES }
  HandleRedefines;

  { Etape 3 : traiter les RENAMES (niveau 66) }
  HandleRenames;

  { Etape 4 : traiter les conditions 88 }
  HandleCondition88;

  { Etape 5 : calculer les tailles des groupes (bottom-up) }
  { On traite tous les records 01 et les niveaux 77 }
  HlvTotalSize := 0;
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].Level = LVL_RECORD) Or
       (SymTab[I].Level = LVL_INDEPEND) Then
    Begin
      If SymTab[I].IsGroup Then
        CalcGroupSize(I);
      HlvTotalSize := HlvTotalSize + SymTab[I].PicSize;
    End;
  End;

  { Etape 6 : calculer les offsets dans chaque record }
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].Level = LVL_RECORD Then
      CalcRecordOffsets(I);
  End;

  Inc(HlvStateCount);
End;

{ ------------------------------------------------------------ }
{ DumpHierarchy : afficher la hierarchie avec indentation       }
{ ------------------------------------------------------------ }

Procedure DumpHierarchy;

  Procedure DumpChildren(ParIdx : Integer; Indent : Integer);
  Var
    I, J : Integer;
  Begin
    For I := 0 To SymCount - 1 Do
    Begin
      If SymTab[I].ParentIdx = ParIdx Then
      Begin
        { Indentation }
        For J := 1 To Indent Do
          Write('  ');
        Write(SymTab[I].Level:2, ' ', SymTab[I].Name);
        If SymTab[I].IsGroup Then
          Write(' (GROUP, ', SymTab[I].PicSize, ' bytes)')
        Else If SymTab[I].PicStr <> '' Then
          Write(' PIC ', SymTab[I].PicStr,
                ' (', SymTab[I].PicSize, ' bytes)');
        If SymTab[I].Level = LVL_CONDITION Then
        Begin
          Write(' VALUES: ');
          For J := 0 To SymTab[I].CondValCount - 1 Do
          Begin
            If J > 0 Then Write(', ');
            Write(SymTab[I].CondValues[J]);
          End;
        End;
        If SymTab[I].RedefinedIdx >= 0 Then
          Write(' REDEFINES ', SymTab[SymTab[I].RedefinedIdx].Name);
        If SymTab[I].Occurs > 0 Then
          Write(' OCCURS ', SymTab[I].Occurs);
        Write(' @', SymTab[I].Offset);
        WriteLn;
        { Recurse pour les enfants }
        If SymTab[I].IsGroup Then
          DumpChildren(I, Indent + 1);
      End;
    End;
  End;

Var
  I : Integer;
Begin
  WriteLn('--- Hierarchie COBOL (', HlvRecordCount, ' records) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].Level = LVL_RECORD) Or
       (SymTab[I].Level = LVL_INDEPEND) Then
    Begin
      Write(SymTab[I].Level:2, ' ', SymTab[I].Name);
      If SymTab[I].IsGroup Then
        Write(' (GROUP, ', SymTab[I].PicSize, ' bytes)')
      Else
        Write(' PIC ', SymTab[I].PicStr,
              ' (', SymTab[I].PicSize, ' bytes)');
      WriteLn;
      If SymTab[I].IsGroup Then
        DumpChildren(I, 1);
    End;
  End;
  WriteLn('--- Total : ', HlvTotalSize, ' bytes ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour TODO 05                         }
{ ------------------------------------------------------------ }

Function IsHlvInitialized : Boolean;
Begin
  IsHlvInitialized := HlvInitialized;
End;

Function IsHlvEmpty : Boolean;
Begin
  IsHlvEmpty := (HlvRecordCount = 0);
End;

Function GetHlvRecordCount : Integer;
Begin
  GetHlvRecordCount := HlvRecordCount;
End;

Function GetHlvStatus : TString;
Begin
  If Not HlvInitialized Then
    GetHlvStatus := 'Not initialized'
  Else
    GetHlvStatus := 'Initialized (' + ItoS(HlvRecordCount) +
                    ' records, ' + ItoS(HlvTotalSize) + ' bytes)';
End;

Function GetHlvDepth : Integer;
Begin
  GetHlvDepth := HlvDepth;
End;

Function GetHlvTotalSize : LongInt;
Begin
  GetHlvTotalSize := HlvTotalSize;
End;

Function GetHlvRedefinesCount : Integer;
Begin
  GetHlvRedefinesCount := HlvRedefinesCount;
End;

Function GetHlvRenamesCount : Integer;
Begin
  GetHlvRenamesCount := HlvRenamesCount;
End;

Function GetHlvConditionCount : Integer;
Begin
  GetHlvConditionCount := HlvConditionCount;
End;

Function GetHlvStateCount : Integer;
Begin
  GetHlvStateCount := HlvStateCount;
End;


{ ============================================================ }
{ TODO 06 - PARSEUR : IDENTIFICATION DIVISION                  }
{           ET ENVIRONMENT DIVISION                            }
{ ============================================================ }

{ Declaration anticipee pour le parseur }
Procedure LexNextToken; Forward;

Const
  { Organisation de fichier COBOL }
  ORG_SEQUENTIAL = 0;
  ORG_INDEXED    = 1;
  ORG_RELATIVE   = 2;

  { Mode d acces }
  ACC_SEQUENTIAL = 0;
  ACC_RANDOM     = 1;
  ACC_DYNAMIC    = 2;

  { Limites du parseur ID/ENV }
  PAR_MAX_FILES  = 16;    { nombre max de fichiers SELECT }
  PAR_MAX_TEXT   = 255;   { taille max texte paragraphe   }

Type
  TFileEntry = Record
    SelectName   : TString;   { nom fichier logique (SELECT)       }
    AssignName   : TString;   { nom fichier externe (ASSIGN TO)    }
    Organization : Integer;   { ORG_SEQUENTIAL/INDEXED/RELATIVE    }
    AccessMode   : Integer;   { ACC_SEQUENTIAL/RANDOM/DYNAMIC      }
    RecordKey    : TString;   { nom cle (pour INDEXED)             }
    FileStatus   : TString;   { variable FILE STATUS               }
  End;

Var
  { Informations IDENTIFICATION DIVISION }
  ParProgramId     : TString;
  ParAuthor        : TString;
  ParInstallation  : TString;
  ParDateWritten   : TString;
  ParDateCompiled  : TString;
  ParSecurityText  : TString;

  { Informations ENVIRONMENT DIVISION }
  ParSourceComputer : TString;
  ParObjectComputer : TString;
  ParDecimalIsComma : Boolean;

  { Table des fichiers (SELECT/ASSIGN) }
  ParFileEntries    : Array[1..PAR_MAX_FILES] Of TFileEntry;
  ParFileEntryCount : Integer;

  { Etat du parseur }
  ParInitialized    : Boolean;
  ParStateCount     : Integer;
  ParCurrentDiv     : Integer;   { division courante en cours de parse }
  ParIdDivSeen      : Boolean;   { IDENTIFICATION DIVISION vue        }
  ParEnvDivSeen     : Boolean;   { ENVIRONMENT DIVISION vue           }

{ ------------------------------------------------------------ }
{ InitParserIdEnv : initialisation de l etat du parseur        }
{ ------------------------------------------------------------ }

Procedure InitParserIdEnv;
Var
  I : Integer;
Begin
  ParProgramId      := '';
  ParAuthor         := '';
  ParInstallation   := '';
  ParDateWritten    := '';
  ParDateCompiled   := '';
  ParSecurityText   := '';
  ParSourceComputer := '';
  ParObjectComputer := '';
  ParDecimalIsComma := False;
  ParFileEntryCount := 0;
  For I := 1 To PAR_MAX_FILES Do Begin
    ParFileEntries[I].SelectName   := '';
    ParFileEntries[I].AssignName   := '';
    ParFileEntries[I].Organization := ORG_SEQUENTIAL;
    ParFileEntries[I].AccessMode   := ACC_SEQUENTIAL;
    ParFileEntries[I].RecordKey    := '';
    ParFileEntries[I].FileStatus   := '';
  End;
  ParCurrentDiv  := 0;
  ParIdDivSeen   := False;
  ParEnvDivSeen  := False;
  ParInitialized := True;
  ParStateCount  := 1;
End;

{ ------------------------------------------------------------ }
{ SkipToNextSentence : avancer jusqu au prochain point '.'     }
{ En COBOL, chaque phrase se termine par un point.             }
{ ------------------------------------------------------------ }

Procedure SkipToNextSentence;
Begin
  While (Not LexEOF) And (CurTokType <> TOK_DOT) Do
    LexNextToken;
  If CurTokType = TOK_DOT Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ CollectTextToNextDot : collecter le texte jusqu au point '.' }
{ Utilise pour AUTHOR, INSTALLATION, etc.                      }
{ ------------------------------------------------------------ }

Function CollectTextToNextDot : TString;
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (CurTokType <> TOK_DOT) Do Begin
    If S <> '' Then
      S := S + ' ';
    S := S + CurTokStr;
    LexNextToken;
  End;
  If CurTokType = TOK_DOT Then
    LexNextToken;
  CollectTextToNextDot := S;
End;

{ ------------------------------------------------------------ }
{ ParseProgramId : parser PROGRAM-ID. nom [IS INITIAL PROGRAM] }
{ La clause PROGRAM-ID est obligatoire en IDENTIFICATION DIV.  }
{ ------------------------------------------------------------ }

Procedure ParseProgramId;
Begin
  Inc(ParStateCount);
  { On attend le nom du programme }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    ParProgramId := CurTokStr;
    LexNextToken;
    { Optionnel : IS INITIAL PROGRAM }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INITIAL) Then Begin
        LexNextToken;
        { Optionnel : PROGRAM apres INITIAL }
        If (CurTokType = TOK_KEYWORD) Or (CurTokType = TOK_IDENT) Then Begin
          If CurTokStr = 'PROGRAM' Then
            LexNextToken;
        End;
      End;
    End;
    { Avancer apres le point }
    If CurTokType = TOK_DOT Then
      LexNextToken;
  End Else Begin
    WarnMsg('PROGRAM-ID : nom de programme attendu');
    SkipToNextSentence;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIdParagraph : parser un paragraphe optionnel de l ID DIV }
{ AUTHOR, INSTALLATION, DATE-WRITTEN, DATE-COMPILED, SECURITY  }
{ Ces paragraphes contiennent du texte libre jusqu au point.   }
{ ------------------------------------------------------------ }

Procedure ParseIdParagraph(KW : Integer);
Var
  Txt : TString;
Begin
  Inc(ParStateCount);
  { Lire le texte jusqu au point }
  Txt := CollectTextToNextDot;
  Case KW Of
    KW_AUTHOR        : ParAuthor       := Txt;
    KW_INSTALLATION  : ParInstallation := Txt;
    KW_DATE_WRITTEN  : ParDateWritten  := Txt;
    KW_DATE_COMPILED : ParDateCompiled := Txt;
    KW_SECURITY      : ParSecurityText := Txt;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIdentificationDiv : parser IDENTIFICATION DIVISION.     }
{ Attend les paragraphes obligatoires et optionnels.           }
{ ------------------------------------------------------------ }

Procedure ParseIdentificationDiv;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  ParIdDivSeen := True;
  ParCurrentDiv := KW_IDENTIFICATION;

  { Consommer 'DIVISION' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DIVISION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  { Boucle sur les paragraphes de l IDENTIFICATION DIVISION }
  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_PROGRAM_ID : Begin
          LexNextToken;
          { Consommer le point apres PROGRAM-ID }
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseProgramId;
        End;
        KW_AUTHOR : Begin
          LexNextToken;
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseIdParagraph(KW_AUTHOR);
        End;
        KW_INSTALLATION : Begin
          LexNextToken;
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseIdParagraph(KW_INSTALLATION);
        End;
        KW_DATE_WRITTEN : Begin
          LexNextToken;
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseIdParagraph(KW_DATE_WRITTEN);
        End;
        KW_DATE_COMPILED : Begin
          LexNextToken;
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseIdParagraph(KW_DATE_COMPILED);
        End;
        KW_SECURITY : Begin
          LexNextToken;
          If CurTokType = TOK_DOT Then
            LexNextToken;
          ParseIdParagraph(KW_SECURITY);
        End;
        { Autre DIVISION = fin de l IDENTIFICATION DIVISION }
        KW_ENVIRONMENT, KW_DATA, KW_PROCEDURE : Begin
          Done := True;
        End;
        Else Begin
          { Paragraphe inconnu : ignorer }
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      { Pas un mot-cle : ignorer }
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSourceComputer : parser SOURCE-COMPUTER. nom.           }
{ ------------------------------------------------------------ }

Procedure ParseSourceComputer;
Begin
  Inc(ParStateCount);
  If CurTokType = TOK_DOT Then
    LexNextToken;
  ParSourceComputer := CollectTextToNextDot;
End;

{ ------------------------------------------------------------ }
{ ParseObjectComputer : parser OBJECT-COMPUTER. nom.           }
{ ------------------------------------------------------------ }

Procedure ParseObjectComputer;
Begin
  Inc(ParStateCount);
  If CurTokType = TOK_DOT Then
    LexNextToken;
  ParObjectComputer := CollectTextToNextDot;
End;

{ ------------------------------------------------------------ }
{ ParseSpecialNames : parser SPECIAL-NAMES.                    }
{   DECIMAL-POINT IS COMMA.                                    }
{   (autres associations symboliques - ignorees pour l instant)}
{ ------------------------------------------------------------ }

Procedure ParseSpecialNames;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    { Detecter DECIMAL-POINT IS COMMA }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
      If CurTokStr = 'DECIMAL-POINT' Then Begin
        LexNextToken;
        { Optionnel : IS }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
          LexNextToken;
        { COMMA }
        If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
          If CurTokStr = 'COMMA' Then Begin
            ParDecimalIsComma := True;
            LexNextToken;
          End;
        End;
        If CurTokType = TOK_DOT Then
          LexNextToken;
      End Else Begin
        { Verifier si c est un paragraphe/section/division suivant }
        If (CurTokNum = KW_INPUT_OUTPUT) Or
           (CurTokNum = KW_DATA) Or (CurTokNum = KW_PROCEDURE) Or
           (CurTokNum = KW_ENVIRONMENT) Or
           (CurTokNum = KW_SOURCE_COMPUTER) Or
           (CurTokNum = KW_OBJECT_COMPUTER) Then Begin
          Done := True;
        End Else Begin
          { Ignorer les autres clauses }
          SkipToNextSentence;
        End;
      End;
    End Else If CurTokType = TOK_DOT Then Begin
      LexNextToken;
      { Un point seul peut indiquer la fin du paragraphe }
      { Verifier si le prochain token est un paragraphe/section }
      If CurTokType = TOK_KEYWORD Then Begin
        If (CurTokNum = KW_INPUT_OUTPUT) Or
           (CurTokNum = KW_SOURCE_COMPUTER) Or
           (CurTokNum = KW_OBJECT_COMPUTER) Or
           (CurTokNum = KW_DATA) Or
           (CurTokNum = KW_PROCEDURE) Then
          Done := True;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseConfigurationSection : parser CONFIGURATION SECTION     }
{   SOURCE-COMPUTER, OBJECT-COMPUTER, SPECIAL-NAMES            }
{ ------------------------------------------------------------ }

Procedure ParseConfigurationSection;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  { Consommer 'SECTION' s il suit }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    If CurTokStr = 'SECTION' Then
      LexNextToken;
  End;
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_SOURCE_COMPUTER : Begin
          LexNextToken;
          ParseSourceComputer;
        End;
        KW_OBJECT_COMPUTER : Begin
          LexNextToken;
          ParseObjectComputer;
        End;
        KW_SPECIAL_NAMES : Begin
          LexNextToken;
          ParseSpecialNames;
        End;
        { Fin de la section CONFIGURATION }
        KW_INPUT_OUTPUT, KW_DATA, KW_PROCEDURE : Begin
          Done := True;
        End;
        Else Begin
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSelectEntry : parser une entree SELECT...ASSIGN TO...   }
{   ORGANIZATION IS..., ACCESS MODE IS..., RECORD KEY IS...,   }
{   FILE STATUS IS...                                          }
{ ------------------------------------------------------------ }

Procedure ParseSelectEntry;
Var
  Idx  : Integer;
  Done : Boolean;
Begin
  Inc(ParStateCount);
  If ParFileEntryCount >= PAR_MAX_FILES Then Begin
    WarnMsg('Nombre maximum de fichiers SELECT atteint');
    SkipToNextSentence;
    Exit;
  End;

  Inc(ParFileEntryCount);
  Idx := ParFileEntryCount;
  ParFileEntries[Idx].SelectName   := '';
  ParFileEntries[Idx].AssignName   := '';
  ParFileEntries[Idx].Organization := ORG_SEQUENTIAL;
  ParFileEntries[Idx].AccessMode   := ACC_SEQUENTIAL;
  ParFileEntries[Idx].RecordKey    := '';
  ParFileEntries[Idx].FileStatus   := '';

  { Nom du fichier logique }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    ParFileEntries[Idx].SelectName := CurTokStr;
    LexNextToken;
  End;

  { Boucle sur les clauses du SELECT }
  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_DOT Then Begin
      LexNextToken;
      Done := True;
    End Else If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_ASSIGN : Begin
          LexNextToken;
          { Optionnel : TO }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
            LexNextToken;
          { Nom externe }
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Or
             (CurTokType = TOK_STRING) Then Begin
            ParFileEntries[Idx].AssignName := CurTokStr;
            LexNextToken;
          End;
        End;
        KW_ORGANIZATION : Begin
          LexNextToken;
          { Optionnel : IS }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          { SEQUENTIAL | INDEXED | RELATIVE | LINE SEQUENTIAL }
          If CurTokType = TOK_KEYWORD Then Begin
            Case CurTokNum Of
              KW_SEQUENTIAL : Begin
                ParFileEntries[Idx].Organization := ORG_SEQUENTIAL;
                LexNextToken;
              End;
              KW_INDEXED : Begin
                ParFileEntries[Idx].Organization := ORG_INDEXED;
                LexNextToken;
              End;
              KW_RELATIVE : Begin
                ParFileEntries[Idx].Organization := ORG_RELATIVE;
                LexNextToken;
              End;
              KW_LINE : Begin
                { LINE SEQUENTIAL }
                LexNextToken;
                If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SEQUENTIAL) Then
                  LexNextToken;
                ParFileEntries[Idx].Organization := ORG_SEQUENTIAL;
              End;
              Else
                LexNextToken;
            End;
          End Else
            LexNextToken;
        End;
        KW_ACCESS : Begin
          LexNextToken;
          { Optionnel : MODE }
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
            If CurTokStr = 'MODE' Then
              LexNextToken;
          End;
          { Optionnel : IS }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          { SEQUENTIAL | RANDOM | DYNAMIC }
          If CurTokType = TOK_KEYWORD Then Begin
            Case CurTokNum Of
              KW_SEQUENTIAL : Begin
                ParFileEntries[Idx].AccessMode := ACC_SEQUENTIAL;
                LexNextToken;
              End;
              KW_RANDOM : Begin
                ParFileEntries[Idx].AccessMode := ACC_RANDOM;
                LexNextToken;
              End;
              KW_DYNAMIC : Begin
                ParFileEntries[Idx].AccessMode := ACC_DYNAMIC;
                LexNextToken;
              End;
              Else
                LexNextToken;
            End;
          End Else
            LexNextToken;
        End;
        KW_RECORD : Begin
          LexNextToken;
          { RECORD KEY IS nom-cle }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
            LexNextToken;
            { Optionnel : IS }
            If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
              LexNextToken;
            { Nom de la cle }
            If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
              ParFileEntries[Idx].RecordKey := CurTokStr;
              LexNextToken;
            End;
          End;
          { Sinon c est un autre usage de RECORD, ignorer }
        End;
        KW_FILE_STATUS : Begin
          LexNextToken;
          { FILE STATUS IS nom-variable }
          { Optionnel : IS }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
            ParFileEntries[Idx].FileStatus := CurTokStr;
            LexNextToken;
          End;
        End;
        KW_STATUS : Begin
          LexNextToken;
          { STATUS IS nom-variable (variante sans FILE devant) }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
            ParFileEntries[Idx].FileStatus := CurTokStr;
            LexNextToken;
          End;
        End;
        { Un autre SELECT = fin de cette entree }
        KW_SELECT : Begin
          Done := True;
        End;
        Else Begin
          { Clause inconnue : avancer }
          LexNextToken;
        End;
      End;
    End Else Begin
      { Token non mot-cle : avancer }
      LexNextToken;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseFileControl : parser FILE-CONTROL. avec boucle SELECT   }
{ ------------------------------------------------------------ }

Procedure ParseFileControl;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_SELECT : Begin
          LexNextToken;
          ParseSelectEntry;
        End;
        { Fin du FILE-CONTROL }
        KW_DATA, KW_PROCEDURE, KW_INPUT_OUTPUT,
        KW_CONFIGURATION : Begin
          Done := True;
        End;
        Else Begin
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseInputOutputSection : parser INPUT-OUTPUT SECTION         }
{   FILE-CONTROL.                                              }
{ ------------------------------------------------------------ }

Procedure ParseInputOutputSection;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  { Consommer 'SECTION' s il suit }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    If CurTokStr = 'SECTION' Then
      LexNextToken;
  End;
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_FILE_CONTROL : Begin
          LexNextToken;
          ParseFileControl;
        End;
        { Fin de la section INPUT-OUTPUT }
        KW_DATA, KW_PROCEDURE : Begin
          Done := True;
        End;
        Else Begin
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseEnvironmentDiv : parser ENVIRONMENT DIVISION.           }
{   CONFIGURATION SECTION, INPUT-OUTPUT SECTION                }
{ ------------------------------------------------------------ }

Procedure ParseEnvironmentDiv;
Var
  Done : Boolean;
Begin
  Inc(ParStateCount);
  ParEnvDivSeen := True;
  ParCurrentDiv := KW_ENVIRONMENT;

  { Consommer 'DIVISION' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DIVISION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_CONFIGURATION : Begin
          LexNextToken;
          ParseConfigurationSection;
        End;
        KW_INPUT_OUTPUT : Begin
          LexNextToken;
          ParseInputOutputSection;
        End;
        { Fin de la ENVIRONMENT DIVISION }
        KW_DATA, KW_PROCEDURE : Begin
          Done := True;
        End;
        Else Begin
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ OrganizationName : nom textuel de l organisation             }
{ ------------------------------------------------------------ }

Function OrganizationName(Org : Integer) : TString;
Begin
  Case Org Of
    ORG_SEQUENTIAL : OrganizationName := 'SEQUENTIAL';
    ORG_INDEXED    : OrganizationName := 'INDEXED';
    ORG_RELATIVE   : OrganizationName := 'RELATIVE';
    Else             OrganizationName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ AccessModeName : nom textuel du mode d acces                 }
{ ------------------------------------------------------------ }

Function AccessModeName(Acc : Integer) : TString;
Begin
  Case Acc Of
    ACC_SEQUENTIAL : AccessModeName := 'SEQUENTIAL';
    ACC_RANDOM     : AccessModeName := 'RANDOM';
    ACC_DYNAMIC    : AccessModeName := 'DYNAMIC';
    Else             AccessModeName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ DumpFileEntries : affichage de la table des fichiers SELECT  }
{ ------------------------------------------------------------ }

Procedure DumpFileEntries;
Var
  I : Integer;
Begin
  WriteLn('--- IDENTIFICATION DIVISION ---');
  WriteLn('  PROGRAM-ID    : ', ParProgramId);
  If ParAuthor <> '' Then
    WriteLn('  AUTHOR        : ', ParAuthor);
  If ParInstallation <> '' Then
    WriteLn('  INSTALLATION  : ', ParInstallation);
  If ParDateWritten <> '' Then
    WriteLn('  DATE-WRITTEN  : ', ParDateWritten);
  If ParDateCompiled <> '' Then
    WriteLn('  DATE-COMPILED : ', ParDateCompiled);
  If ParSecurityText <> '' Then
    WriteLn('  SECURITY      : ', ParSecurityText);

  WriteLn('--- ENVIRONMENT DIVISION ---');
  If ParSourceComputer <> '' Then
    WriteLn('  SOURCE-COMPUTER : ', ParSourceComputer);
  If ParObjectComputer <> '' Then
    WriteLn('  OBJECT-COMPUTER : ', ParObjectComputer);
  If ParDecimalIsComma Then
    WriteLn('  DECIMAL-POINT IS COMMA');

  WriteLn('--- FILE ENTRIES (', ParFileEntryCount, ') ---');
  For I := 1 To ParFileEntryCount Do Begin
    WriteLn('  [', I, '] SELECT ', ParFileEntries[I].SelectName);
    WriteLn('       ASSIGN TO     ', ParFileEntries[I].AssignName);
    WriteLn('       ORGANIZATION  ', OrganizationName(ParFileEntries[I].Organization));
    WriteLn('       ACCESS MODE   ', AccessModeName(ParFileEntries[I].AccessMode));
    If ParFileEntries[I].RecordKey <> '' Then
      WriteLn('       RECORD KEY    ', ParFileEntries[I].RecordKey);
    If ParFileEntries[I].FileStatus <> '' Then
      WriteLn('       FILE STATUS   ', ParFileEntries[I].FileStatus);
  End;
End;

{ 10 fonctions accesseurs pour TODO 06                         }

Function IsParInitialized : Boolean;
Begin
  IsParInitialized := ParInitialized;
End;

Function IsParEmpty : Boolean;
Begin
  IsParEmpty := (ParProgramId = '') And (ParFileEntryCount = 0);
End;

Function GetParProgramId : TString;
Begin
  GetParProgramId := ParProgramId;
End;

Function GetParStatus : TString;
Begin
  If Not ParInitialized Then
    GetParStatus := 'NON INITIALISE'
  Else If ParProgramId = '' Then
    GetParStatus := 'VIDE'
  Else
    GetParStatus := 'PROGRAM-ID=' + ParProgramId +
                    ' FILES=' + ItoS(ParFileEntryCount);
End;

Function GetParFileEntryCount : Integer;
Begin
  GetParFileEntryCount := ParFileEntryCount;
End;

Function IsParDecimalComma : Boolean;
Begin
  IsParDecimalComma := ParDecimalIsComma;
End;

Function IsParIdDivSeen : Boolean;
Begin
  IsParIdDivSeen := ParIdDivSeen;
End;

Function IsParEnvDivSeen : Boolean;
Begin
  IsParEnvDivSeen := ParEnvDivSeen;
End;

Function GetParMaxFiles : Integer;
Begin
  GetParMaxFiles := PAR_MAX_FILES;
End;

Function GetParStateCount : Integer;
Begin
  GetParStateCount := ParStateCount;
End;


{ ============================================================ }
{ TODO 07 - PARSEUR : DATA DIVISION                            }
{           (FILE SECTION, WORKING-STORAGE, LINKAGE)           }
{ ============================================================ }

Const
  DDV_MAX_FD_ENTRIES = 16;   { nombre max d entrees FD/SD            }
  DDV_PIC_MAX_SIZE   = 64;   { taille max d une chaine PICTURE       }

Var
  DdvInitialized        : Boolean;   { module initialise ?               }
  DdvStateCount         : Integer;   { compteur d etats                  }
  DdvDataDivSeen        : Boolean;   { DATA DIVISION rencontree ?        }
  DdvCurrentSection     : Integer;   { section courante (SEC_*)          }
  DdvFileSectionCount   : Integer;   { items dans FILE SECTION           }
  DdvWorkingStorageCount : Integer;  { items dans WORKING-STORAGE        }
  DdvLinkageCount       : Integer;   { items dans LINKAGE SECTION        }
  DdvFDCount            : Integer;   { nombre d entrees FD/SD            }
  DdvPicAnalysisCount   : Integer;   { clauses PIC analysees             }
  DdvTotalItems         : Integer;   { total items de donnees parses     }
  DdvOccursCount        : Integer;   { clauses OCCURS rencontrees        }

{ ------------------------------------------------------------ }
{ InitDataDivState : initialisation de l etat du parseur       }
{ DATA DIVISION                                                }
{ ------------------------------------------------------------ }

Procedure InitDataDivState;
Begin
  DdvInitialized         := True;
  DdvStateCount          := 1;
  DdvDataDivSeen         := False;
  DdvCurrentSection      := SEC_NONE;
  DdvFileSectionCount    := 0;
  DdvWorkingStorageCount := 0;
  DdvLinkageCount        := 0;
  DdvFDCount             := 0;
  DdvPicAnalysisCount    := 0;
  DdvTotalItems          := 0;
  DdvOccursCount         := 0;
End;

{ ------------------------------------------------------------ }
{ AnalyzePicture : analyser une chaine PICTURE COBOL           }
{ Determine la taille en octets, les decimales, le signe et    }
{ le type du symbole (CBT_ALPHA, CBT_NUMERIC, etc.)            }
{ ------------------------------------------------------------ }

Procedure AnalyzePicture(Const PicStr : TString;
                         Var PicSize : Integer;
                         Var PicDecimals : Integer;
                         Var IsSigned : Boolean;
                         Var SymType : Integer);
Var
  I, Len, RepCount : Integer;
  Ch        : Char;
  HasA      : Boolean;
  HasX      : Boolean;
  Has9      : Boolean;
  HasV      : Boolean;
  HasS      : Boolean;
  HasEdit   : Boolean;
  AfterV    : Integer;
  DigitSize : Integer;
  U         : TString;
Begin
  PicSize     := 0;
  PicDecimals := 0;
  IsSigned    := False;
  SymType     := CBT_ALPHANUMERIC;
  HasA        := False;
  HasX        := False;
  Has9        := False;
  HasV        := False;
  HasS        := False;
  HasEdit     := False;
  AfterV      := 0;
  DigitSize   := 0;

  U   := UpCaseStr(PicStr);
  Len := Length(U);
  I   := 1;

  While I <= Len Do Begin
    Ch := U[I];

    { Verifier repetition : X(n) }
    RepCount := 1;
    If (I < Len) And (U[I + 1] = '(') Then Begin
      Inc(I, 2); { sauter le caractere et '(' }
      RepCount := 0;
      While (I <= Len) And (U[I] >= '0') And (U[I] <= '9') Do Begin
        RepCount := RepCount * 10 + (Ord(U[I]) - Ord('0'));
        Inc(I);
      End;
      If (I <= Len) And (U[I] = ')') Then
        Inc(I);
      If RepCount < 1 Then
        RepCount := 1;
    End Else
      Inc(I);

    Case Ch Of
      'A' : Begin
        HasA := True;
        PicSize := PicSize + RepCount;
      End;
      'X' : Begin
        HasX := True;
        PicSize := PicSize + RepCount;
      End;
      '9' : Begin
        Has9 := True;
        PicSize := PicSize + RepCount;
        DigitSize := DigitSize + RepCount;
        If HasV Then
          AfterV := AfterV + RepCount;
      End;
      'V' : Begin
        HasV := True;
        { V ne prend pas d octet }
      End;
      'S' : Begin
        HasS    := True;
        IsSigned := True;
        { S ne prend pas d octet en DISPLAY par defaut }
      End;
      'P' : Begin
        Has9 := True;
        { P : mise a l echelle, pas d octet supplementaire }
        If HasV Then
          AfterV := AfterV + RepCount;
      End;
      'Z', '*', '$' : Begin
        HasEdit := True;
        PicSize := PicSize + RepCount;
        DigitSize := DigitSize + RepCount;
      End;
      ',', '/', 'B', '0' : Begin
        HasEdit := True;
        PicSize := PicSize + RepCount;
      End;
      '.' : Begin
        HasEdit := True;
        PicSize := PicSize + RepCount;
        HasV := True; { le point explicite joue le role de V }
      End;
      '+', '-' : Begin
        HasEdit := True;
        PicSize := PicSize + RepCount;
        IsSigned := True;
      End;
      'C' : Begin
        { CR : 2 caracteres d edition }
        If (I <= Len) And (U[I] = 'R') Then Begin
          Inc(I);
          HasEdit  := True;
          IsSigned := True;
          PicSize  := PicSize + (2 * RepCount);
        End;
      End;
      'D' : Begin
        { DB : 2 caracteres d edition }
        If (I <= Len) And (U[I] = 'B') Then Begin
          Inc(I);
          HasEdit  := True;
          IsSigned := True;
          PicSize  := PicSize + (2 * RepCount);
        End;
      End;
    End; { Case }
  End; { While }

  PicDecimals := AfterV;

  { Determiner le type }
  If HasEdit Then Begin
    If HasA Or HasX Then
      SymType := CBT_EDITED_ALPHA
    Else
      SymType := CBT_EDITED_NUM;
  End Else If HasX Then
    SymType := CBT_ALPHANUMERIC
  Else If HasA And (Not Has9) Then
    SymType := CBT_ALPHA
  Else If Has9 Or HasV Or HasS Then
    SymType := CBT_NUMERIC
  Else
    SymType := CBT_ALPHANUMERIC;

  Inc(DdvPicAnalysisCount);
  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseUsageClause : parser la clause USAGE                    }
{ Retourne la constante USG_* et ajuste la taille si binaire   }
{ ------------------------------------------------------------ }

Function ParseUsageClause(Var PicSize : Integer;
                          DigitCount : Integer) : Integer;
Var
  Usg : Integer;
Begin
  Usg := USG_DISPLAY;

  { Consommer IS (optionnel) }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
    LexNextToken;

  If CurTokType = TOK_KEYWORD Then Begin
    Case CurTokNum Of
      KW_DISPLAY : Begin
        Usg := USG_DISPLAY;
        LexNextToken;
      End;
      KW_COMP, KW_BINARY : Begin
        Usg := USG_COMP;
        LexNextToken;
        { Ajuster la taille en octets selon le nombre de chiffres }
        If DigitCount <= 4 Then
          PicSize := 2
        Else If DigitCount <= 9 Then
          PicSize := 4
        Else
          PicSize := 8;
      End;
      KW_COMP_1 : Begin
        Usg := USG_COMP1;
        LexNextToken;
        PicSize := 4; { flottant simple = 4 octets }
      End;
      KW_COMP_2 : Begin
        Usg := USG_COMP2;
        LexNextToken;
        PicSize := 8; { flottant double = 8 octets }
      End;
      KW_COMP_3, KW_PACKED_DECIMAL : Begin
        Usg := USG_COMP3;
        LexNextToken;
        { COMP-3 : (n+1)/2 octets arrondis vers le haut }
        PicSize := (DigitCount + 2) Div 2;
      End;
      KW_INDEX : Begin
        Usg := USG_INDEX;
        LexNextToken;
        PicSize := 4; { index = 4 octets }
      End;
      KW_POINTER : Begin
        Usg := USG_POINTER;
        LexNextToken;
        PicSize := 4; { pointeur = 4 octets }
      End;
      Else Begin
        { Mot-cle non reconnu, laisser DISPLAY }
      End;
    End;
  End;

  ParseUsageClause := Usg;
  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseValueClause : parser la clause VALUE IS ...             }
{ Retourne la valeur sous forme de chaine                      }
{ ------------------------------------------------------------ }

Function ParseValueClause : TString;
Var
  V : TString;
Begin
  V := '';

  { Consommer IS (optionnel) }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
    LexNextToken;

  If CurTokType = TOK_STRING Then Begin
    V := CurTokStr;
    LexNextToken;
  End Else If CurTokType = TOK_INTEGER Then Begin
    V := CurTokStr;
    LexNextToken;
  End Else If CurTokType = TOK_DECIMAL Then Begin
    V := CurTokStr;
    LexNextToken;
  End Else If CurTokType = TOK_KEYWORD Then Begin
    Case CurTokNum Of
      KW_SPACES : Begin
        V := 'SPACES';
        LexNextToken;
      End;
      KW_ZERO, KW_ZEROS, KW_ZEROES : Begin
        V := 'ZEROS';
        LexNextToken;
      End;
      KW_HIGH_VALUES, KW_HIGH_VALUE : Begin
        V := 'HIGH-VALUES';
        LexNextToken;
      End;
      KW_LOW_VALUES, KW_LOW_VALUE : Begin
        V := 'LOW-VALUES';
        LexNextToken;
      End;
      KW_ALL : Begin
        LexNextToken;
        If CurTokType = TOK_STRING Then Begin
          V := 'ALL ' + CurTokStr;
          LexNextToken;
        End Else Begin
          V := 'ALL ' + CurTokStr;
          LexNextToken;
        End;
      End;
      Else Begin
        V := CurTokStr;
        LexNextToken;
      End;
    End;
  End Else Begin
    V := CurTokStr;
    LexNextToken;
  End;

  ParseValueClause := V;
  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseOccursClause : parser la clause OCCURS                  }
{ OCCURS n TIMES ou OCCURS n TO m DEPENDING ON var             }
{ ------------------------------------------------------------ }

Procedure ParseOccursClause(Var OccCount : Integer;
                            Var OccMin : Integer;
                            Var OccDep : TString);
Begin
  OccCount := 0;
  OccMin   := 0;
  OccDep   := '';

  { Lire le nombre }
  If CurTokType = TOK_INTEGER Then Begin
    OccCount := CurTokNum;
    LexNextToken;
  End;

  { OCCURS n TO m DEPENDING ON var ? }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then Begin
    OccMin := OccCount; { n est le minimum }
    LexNextToken;
    If CurTokType = TOK_INTEGER Then Begin
      OccCount := CurTokNum; { m est le maximum }
      LexNextToken;
    End;
    { DEPENDING }
    If (CurTokType = TOK_IDENT) And
       (UpCaseStr(CurTokStr) = 'DEPENDING') Then Begin
      LexNextToken;
      { ON }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
        LexNextToken;
      { Nom de la variable }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
        OccDep := CurTokStr;
        LexNextToken;
      End;
    End;
  End;

  { TIMES (optionnel) }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TIMES) Then
    LexNextToken;

  { Clauses supplementaires : KEY, INDEXED BY }
  While (Not LexEOF) And (CurTokType <> TOK_DOT) Do Begin
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
      LexNextToken;
      { IS (optionnel) }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
        LexNextToken;
      { Nom de cle }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
        LexNextToken;
    End Else If (CurTokType = TOK_KEYWORD) And
                (CurTokNum = KW_INDEXED) Then Begin
      LexNextToken;
      { BY }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
        LexNextToken;
      { Nom d index }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
        LexNextToken;
    End Else
      Break;
  End;

  Inc(DdvOccursCount);
  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseDataItem : parser un item de donnees COBOL              }
{ Lit le niveau, le nom, puis les clauses PIC, VALUE, USAGE,   }
{ OCCURS, REDEFINES, etc. jusqu au point terminateur           }
{ ------------------------------------------------------------ }

Procedure ParseDataItem(Section : Integer);
Var
  Level     : Integer;
  ItemName  : TString;
  Idx       : Integer;
  PicStr    : TString;
  PicSize   : Integer;
  PicDec    : Integer;
  PicSigned : Boolean;
  PicType   : Integer;
  ItemUsage : Integer;
  ItemValue : TString;
  OccCount  : Integer;
  OccMin    : Integer;
  OccDep    : TString;
  RedefName : TString;
  RedIdx    : Integer;
  IsGroupItem : Boolean;
  HasPic    : Boolean;
  DigitCount : Integer;
  DoneClauses : Boolean;
  CondVal   : TString;
Begin
  Level := CurTokNum;
  LexNextToken;

  { Lire le nom (ou FILLER) }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FILLER) Then Begin
    ItemName := 'FILLER';
    LexNextToken;
  End Else If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    ItemName := CurTokStr;
    LexNextToken;
  End Else Begin
    ItemName := 'FILLER';
  End;

  { Initialisations }
  PicStr      := '';
  PicSize     := 0;
  PicDec      := 0;
  PicSigned   := False;
  PicType     := CBT_GROUP;
  ItemUsage   := USG_DISPLAY;
  ItemValue   := '';
  OccCount    := 0;
  OccMin      := 0;
  OccDep      := '';
  RedefName   := '';
  HasPic      := False;
  IsGroupItem := True;
  DigitCount  := 0;

  { Niveau 88 : condition nommee }
  If Level = LVL_CONDITION Then Begin
    PicType     := CBT_CONDITION;
    IsGroupItem := False;
    Idx := SymAdd(ItemName, Level, PicType, Section);

    { Parser VALUE IS / VALUES ARE }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_VALUE) Then Begin
      LexNextToken;
      { IS / ARE (optionnel) }
      If (CurTokType = TOK_KEYWORD) And
         ((CurTokNum = KW_IS) Or (CurTokNum = KW_ARE)) Then
        LexNextToken;
    End;

    { Lire les valeurs de condition }
    While (Not LexEOF) And (CurTokType <> TOK_DOT) Do Begin
      CondVal := '';
      If CurTokType = TOK_STRING Then Begin
        CondVal := CurTokStr;
        LexNextToken;
      End Else If (CurTokType = TOK_INTEGER) Or
                  (CurTokType = TOK_DECIMAL) Then Begin
        CondVal := CurTokStr;
        LexNextToken;
      End Else If CurTokType = TOK_KEYWORD Then Begin
        Case CurTokNum Of
          KW_SPACES : Begin CondVal := 'SPACES'; LexNextToken; End;
          KW_ZERO, KW_ZEROS, KW_ZEROES : Begin
            CondVal := 'ZEROS'; LexNextToken;
          End;
          KW_HIGH_VALUES, KW_HIGH_VALUE : Begin
            CondVal := 'HIGH-VALUES'; LexNextToken;
          End;
          KW_LOW_VALUES, KW_LOW_VALUE : Begin
            CondVal := 'LOW-VALUES'; LexNextToken;
          End;
          KW_THRU, KW_THROUGH : Begin
            LexNextToken;
            Continue;
          End;
          Else Begin
            CondVal := CurTokStr;
            LexNextToken;
          End;
        End;
      End Else Begin
        LexNextToken;
        Continue;
      End;

      If (CondVal <> '') And (Idx >= 0) Then Begin
        If SymTab[Idx].CondValCount < MAX_COND_VALUES Then Begin
          SymTab[Idx].CondValues[SymTab[Idx].CondValCount] := CondVal;
          Inc(SymTab[Idx].CondValCount);
        End;
      End;
    End;

    { Consommer le point }
    If CurTokType = TOK_DOT Then
      LexNextToken;

    Inc(DdvTotalItems);
    Inc(DdvStateCount);
    Exit;
  End;

  { Niveau 66 : RENAMES }
  If Level = LVL_RENAMES Then Begin
    PicType     := CBT_ALPHANUMERIC;
    IsGroupItem := False;
    Idx := SymAdd(ItemName, Level, PicType, Section);

    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RENAMES) Then Begin
      LexNextToken;
      { Nom du champ redefini }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
        RedefName := CurTokStr;
        LexNextToken;
      End;
      { THRU/THROUGH (optionnel) }
      If (CurTokType = TOK_KEYWORD) And
         ((CurTokNum = KW_THRU) Or (CurTokNum = KW_THROUGH)) Then Begin
        LexNextToken;
        { Nom de fin }
        If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
          LexNextToken;
      End;
    End;

    { Resoudre REDEFINES }
    If (Idx >= 0) And (RedefName <> '') Then Begin
      RedIdx := SymFind(RedefName);
      If RedIdx >= 0 Then
        SymTab[Idx].RedefinedIdx := RedIdx;
    End;

    SkipToNextSentence;
    Inc(DdvTotalItems);
    Inc(DdvStateCount);
    Exit;
  End;

  { Parser les clauses jusqu au point terminateur }
  DoneClauses := False;
  While (Not LexEOF) And (CurTokType <> TOK_DOT) And
        (Not DoneClauses) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_PIC, KW_PICTURE : Begin
          LexNextToken;
          { IS (optionnel) }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          { Lire la chaine PICTURE }
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Or
             (CurTokType = TOK_INTEGER) Then Begin
            PicStr := CurTokStr;
            LexNextToken;
          End;
          HasPic      := True;
          IsGroupItem := False;
          AnalyzePicture(PicStr, PicSize, PicDec, PicSigned, PicType);
          DigitCount := PicSize;
        End;
        KW_VALUE : Begin
          LexNextToken;
          ItemValue := ParseValueClause;
        End;
        KW_USAGE : Begin
          LexNextToken;
          ItemUsage := ParseUsageClause(PicSize, DigitCount);
        End;
        KW_COMP : Begin
          ItemUsage := USG_COMP;
          LexNextToken;
          If DigitCount <= 4 Then PicSize := 2
          Else If DigitCount <= 9 Then PicSize := 4
          Else PicSize := 8;
        End;
        KW_COMP_1 : Begin
          ItemUsage := USG_COMP1;
          LexNextToken;
          PicSize := 4;
        End;
        KW_COMP_2 : Begin
          ItemUsage := USG_COMP2;
          LexNextToken;
          PicSize := 8;
        End;
        KW_COMP_3, KW_PACKED_DECIMAL : Begin
          ItemUsage := USG_COMP3;
          LexNextToken;
          PicSize := (DigitCount + 2) Div 2;
        End;
        KW_BINARY : Begin
          ItemUsage := USG_COMP;
          LexNextToken;
          If DigitCount <= 4 Then PicSize := 2
          Else If DigitCount <= 9 Then PicSize := 4
          Else PicSize := 8;
        End;
        KW_INDEX : Begin
          ItemUsage := USG_INDEX;
          LexNextToken;
          PicSize := 4;
        End;
        KW_OCCURS : Begin
          LexNextToken;
          ParseOccursClause(OccCount, OccMin, OccDep);
        End;
        KW_REDEFINES : Begin
          LexNextToken;
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
            RedefName := CurTokStr;
            LexNextToken;
          End;
        End;
        KW_BLANK : Begin
          LexNextToken;
          { WHEN ZERO / WHEN ZEROS }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WHEN) Then
            LexNextToken;
          If (CurTokType = TOK_KEYWORD) And
             ((CurTokNum = KW_ZERO) Or (CurTokNum = KW_ZEROS) Or
              (CurTokNum = KW_ZEROES)) Then
            LexNextToken;
        End;
        KW_JUSTIFIED : Begin
          LexNextToken;
          { RIGHT (optionnel, traite comme identifiant) }
          If (CurTokType = TOK_IDENT) And
             (UpCaseStr(CurTokStr) = 'RIGHT') Then
            LexNextToken;
        End;
        KW_SIGN : Begin
          LexNextToken;
          { IS (optionnel) }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
            LexNextToken;
          { LEADING / TRAILING }
          If (CurTokType = TOK_KEYWORD) And
             ((CurTokNum = KW_LEADING) Or (CurTokNum = KW_TRAILING)) Then
            LexNextToken;
          { SEPARATE CHARACTER }
          If (CurTokType = TOK_IDENT) And
             (UpCaseStr(CurTokStr) = 'SEPARATE') Then Begin
            LexNextToken;
            If (CurTokType = TOK_IDENT) And
               (UpCaseStr(CurTokStr) = 'CHARACTER') Then
              LexNextToken;
          End;
        End;
        KW_SYNCHRONIZED : Begin
          LexNextToken;
          { LEFT / RIGHT (optionnel) }
          If (CurTokType = TOK_IDENT) And
             ((UpCaseStr(CurTokStr) = 'LEFT') Or
              (UpCaseStr(CurTokStr) = 'RIGHT')) Then
            LexNextToken;
        End;
        Else Begin
          { Mot-cle non gere dans les clauses : sortir }
          DoneClauses := True;
        End;
      End;
    End Else Begin
      { Token non mot-cle et non point : sauter }
      LexNextToken;
    End;
  End;

  { Determiner le type final }
  If Not HasPic Then Begin
    If (Level = LVL_RECORD) Or
       ((Level >= LVL_MIN_HIER) And (Level <= LVL_MAX_HIER)) Then Begin
      PicType     := CBT_GROUP;
      IsGroupItem := True;
    End;
    If Level = LVL_INDEPEND Then Begin
      PicType     := CBT_ALPHANUMERIC;
      IsGroupItem := False;
    End;
  End;

  { Ajouter dans la table des symboles }
  Idx := SymAdd(ItemName, Level, PicType, Section);
  If Idx >= 0 Then Begin
    SymTab[Idx].PicStr      := PicStr;
    SymTab[Idx].PicSize     := PicSize;
    SymTab[Idx].PicDecimals := PicDec;
    SymTab[Idx].IsSigned    := PicSigned;
    SymTab[Idx].IsGroup     := IsGroupItem;
    SymTab[Idx].Value       := ItemValue;
    SymTab[Idx].Usage       := ItemUsage;
    SymTab[Idx].Occurs      := OccCount;
    SymTab[Idx].OccursMin   := OccMin;
    SymTab[Idx].OccursDep   := OccDep;

    { Resoudre REDEFINES }
    If RedefName <> '' Then Begin
      RedIdx := SymFind(RedefName);
      If RedIdx >= 0 Then
        SymTab[Idx].RedefinedIdx := RedIdx;
    End;

    { Compteur par section }
    Case Section Of
      SEC_FILE            : Inc(DdvFileSectionCount);
      SEC_WORKING_STORAGE : Inc(DdvWorkingStorageCount);
      SEC_LINKAGE         : Inc(DdvLinkageCount);
    End;
  End;

  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Inc(DdvTotalItems);
  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseFDEntry : parser une entree FD ou SD                    }
{ FD nom-fichier [clauses...]. suivie de records 01            }
{ ------------------------------------------------------------ }

Procedure ParseFDEntry;
Var
  FDName   : TString;
  Idx      : Integer;
  FDType   : Integer;
  Done     : Boolean;
  U        : TString;
Begin
  { FD ou SD ? }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SD) Then
    FDType := CBT_FILE
  Else
    FDType := CBT_FILE;

  LexNextToken; { consommer FD/SD }

  { Lire le nom du fichier }
  FDName := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
    FDName := CurTokStr;
    LexNextToken;
  End;

  { Ajouter le fichier dans la table des symboles (niveau 0) }
  Idx := SymAdd(FDName, 0, FDType, SEC_FILE);

  { Parser les clauses FD jusqu au point }
  Done := False;
  While (Not LexEOF) And (CurTokType <> TOK_DOT) And (Not Done) Do Begin
    If (CurTokType = TOK_KEYWORD) Then Begin
      Case CurTokNum Of
        KW_LABEL : Begin
          LexNextToken;
          { RECORD IS / RECORDS ARE }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RECORD) Then
            LexNextToken;
          If (CurTokType = TOK_KEYWORD) And
             ((CurTokNum = KW_IS) Or (CurTokNum = KW_ARE)) Then
            LexNextToken;
          { STANDARD / OMITTED }
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
            LexNextToken;
        End;
        KW_RECORD : Begin
          LexNextToken;
          { CONTAINS }
          If (CurTokType = TOK_IDENT) And
             (UpCaseStr(CurTokStr) = 'CONTAINS') Then
            LexNextToken;
          { Nombre }
          If CurTokType = TOK_INTEGER Then
            LexNextToken;
          { TO (optionnel pour RECORD CONTAINS n TO m) }
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then Begin
            LexNextToken;
            If CurTokType = TOK_INTEGER Then
              LexNextToken;
          End;
          { CHARACTERS }
          If (CurTokType = TOK_IDENT) And
             (UpCaseStr(CurTokStr) = 'CHARACTERS') Then
            LexNextToken;
        End;
        Else Begin
          { BLOCK CONTAINS, DATA RECORD IS, etc. : avancer }
          U := UpCaseStr(CurTokStr);
          LexNextToken;
          If U = 'BLOCK' Then Begin
            { CONTAINS }
            If (CurTokType = TOK_IDENT) And
               (UpCaseStr(CurTokStr) = 'CONTAINS') Then
              LexNextToken;
            { Nombre }
            If CurTokType = TOK_INTEGER Then
              LexNextToken;
            { RECORDS }
            If (CurTokType = TOK_KEYWORD) And
               (CurTokNum = KW_RECORD) Then
              LexNextToken
            Else If (CurTokType = TOK_IDENT) And
                    (UpCaseStr(CurTokStr) = 'RECORDS') Then
              LexNextToken;
          End;
        End;
      End;
    End Else Begin
      U := UpCaseStr(CurTokStr);
      If U = 'BLOCK' Then Begin
        LexNextToken;
        If (CurTokType = TOK_IDENT) And
           (UpCaseStr(CurTokStr) = 'CONTAINS') Then
          LexNextToken;
        If CurTokType = TOK_INTEGER Then
          LexNextToken;
        If (CurTokType = TOK_IDENT) And
           (UpCaseStr(CurTokStr) = 'RECORDS') Then
          LexNextToken;
      End Else If U = 'DATA' Then Begin
        LexNextToken;
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RECORD) Then
          LexNextToken;
        If (CurTokType = TOK_KEYWORD) And
           ((CurTokNum = KW_IS) Or (CurTokNum = KW_ARE)) Then
          LexNextToken;
        If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
          LexNextToken;
      End Else
        LexNextToken;
    End;
  End;

  { Consommer le point apres les clauses FD }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Inc(DdvFDCount);

  { Parser les records qui suivent (01, etc.) }
  While (Not LexEOF) Do Begin
    { Nouveau FD/SD ou section = fin des records }
    If (CurTokType = TOK_KEYWORD) Then Begin
      If (CurTokNum = KW_FD) Or (CurTokNum = KW_SD) Then
        Break;
      If (CurTokNum = KW_WORKING_STORAGE) Or (CurTokNum = KW_LINKAGE) Or
         (CurTokNum = KW_PROCEDURE) Or (CurTokNum = KW_LOCAL_STORAGE) Or
         (CurTokNum = KW_SCREEN) Or (CurTokNum = KW_REPORT) Then
        Break;
    End;
    { Niveau numerique : c est un data item }
    If CurTokType = TOK_INTEGER Then
      ParseDataItem(SEC_FILE)
    Else
      SkipToNextSentence;
  End;

  Inc(DdvStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseFileSection : parser la FILE SECTION                    }
{ Contient des entrees FD/SD et leurs records                  }
{ ------------------------------------------------------------ }

Procedure ParseFileSection;
Begin
  DdvCurrentSection := SEC_FILE;
  Inc(DdvStateCount);

  { Consommer SECTION }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SECTION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  { Parser les entrees FD/SD }
  While (Not LexEOF) Do Begin
    If (CurTokType = TOK_KEYWORD) Then Begin
      If (CurTokNum = KW_FD) Or (CurTokNum = KW_SD) Then
        ParseFDEntry
      Else If (CurTokNum = KW_WORKING_STORAGE) Or (CurTokNum = KW_LINKAGE) Or
              (CurTokNum = KW_PROCEDURE) Or (CurTokNum = KW_LOCAL_STORAGE) Or
              (CurTokNum = KW_SCREEN) Or (CurTokNum = KW_REPORT) Then
        Break
      Else
        SkipToNextSentence;
    End Else If CurTokType = TOK_INTEGER Then
      ParseDataItem(SEC_FILE)
    Else
      SkipToNextSentence;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseWorkingStorageSection : parser la WORKING-STORAGE SECTION}
{ Contient des items 77 et des groupes 01                      }
{ ------------------------------------------------------------ }

Procedure ParseWorkingStorageSection;
Begin
  DdvCurrentSection := SEC_WORKING_STORAGE;
  Inc(DdvStateCount);

  { Consommer SECTION }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SECTION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  { Parser les items de donnees }
  While (Not LexEOF) Do Begin
    If (CurTokType = TOK_KEYWORD) Then Begin
      If (CurTokNum = KW_FILE) Or (CurTokNum = KW_LINKAGE) Or
         (CurTokNum = KW_PROCEDURE) Or (CurTokNum = KW_LOCAL_STORAGE) Or
         (CurTokNum = KW_SCREEN) Or (CurTokNum = KW_REPORT) Then
        Break
      Else
        SkipToNextSentence;
    End Else If CurTokType = TOK_INTEGER Then
      ParseDataItem(SEC_WORKING_STORAGE)
    Else
      SkipToNextSentence;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseLinkageSection : parser la LINKAGE SECTION              }
{ Meme format que WORKING-STORAGE                              }
{ ------------------------------------------------------------ }

Procedure ParseLinkageSection;
Begin
  DdvCurrentSection := SEC_LINKAGE;
  Inc(DdvStateCount);

  { Consommer SECTION }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SECTION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  { Parser les items de donnees }
  While (Not LexEOF) Do Begin
    If (CurTokType = TOK_KEYWORD) Then Begin
      If (CurTokNum = KW_FILE) Or (CurTokNum = KW_WORKING_STORAGE) Or
         (CurTokNum = KW_PROCEDURE) Or (CurTokNum = KW_LOCAL_STORAGE) Or
         (CurTokNum = KW_SCREEN) Or (CurTokNum = KW_REPORT) Then
        Break
      Else
        SkipToNextSentence;
    End Else If CurTokType = TOK_INTEGER Then
      ParseDataItem(SEC_LINKAGE)
    Else
      SkipToNextSentence;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseDataDivision : parser la DATA DIVISION                  }
{ Dispatche vers FILE, WORKING-STORAGE et LINKAGE SECTION      }
{ ------------------------------------------------------------ }

Procedure ParseDataDivision;
Var
  Done : Boolean;
Begin
  DdvDataDivSeen := True;
  DdvCurrentSection := SEC_NONE;
  Inc(DdvStateCount);

  { Consommer DIVISION }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DIVISION) Then
    LexNextToken;
  { Consommer le point }
  If CurTokType = TOK_DOT Then
    LexNextToken;

  Done := False;
  While (Not LexEOF) And (Not Done) Do Begin
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_FILE : Begin
          LexNextToken;
          ParseFileSection;
        End;
        KW_WORKING_STORAGE : Begin
          LexNextToken;
          ParseWorkingStorageSection;
        End;
        KW_LINKAGE : Begin
          LexNextToken;
          ParseLinkageSection;
        End;
        { Fin de la DATA DIVISION }
        KW_PROCEDURE : Begin
          Done := True;
        End;
        Else Begin
          SkipToNextSentence;
        End;
      End;
    End Else Begin
      SkipToNextSentence;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpDataDivision : afficher un resume de la DATA DIVISION    }
{ ------------------------------------------------------------ }

Procedure DumpDataDivision;
Begin
  WriteLn('--- DATA DIVISION ---');
  If Not DdvDataDivSeen Then Begin
    WriteLn('  (non presente)');
    Exit;
  End;
  WriteLn('  FD/SD           : ', DdvFDCount);
  WriteLn('  FILE SECTION    : ', DdvFileSectionCount, ' items');
  WriteLn('  WORKING-STORAGE : ', DdvWorkingStorageCount, ' items');
  WriteLn('  LINKAGE         : ', DdvLinkageCount, ' items');
  WriteLn('  TOTAL ITEMS     : ', DdvTotalItems);
  WriteLn('  PIC analyses    : ', DdvPicAnalysisCount);
  WriteLn('  OCCURS clauses  : ', DdvOccursCount);
End;

{ 10 fonctions accesseurs pour TODO 07                         }

Function IsDdvInitialized : Boolean;
Begin
  IsDdvInitialized := DdvInitialized;
End;

Function IsDdvEmpty : Boolean;
Begin
  IsDdvEmpty := (DdvTotalItems = 0) And (DdvFDCount = 0);
End;

Function GetDdvTotalItems : Integer;
Begin
  GetDdvTotalItems := DdvTotalItems;
End;

Function GetDdvStatus : TString;
Begin
  If Not DdvInitialized Then
    GetDdvStatus := 'NON INITIALISE'
  Else If Not DdvDataDivSeen Then
    GetDdvStatus := 'ABSENT'
  Else
    GetDdvStatus := 'FD=' + ItoSI(DdvFDCount) +
                    ' WS=' + ItoSI(DdvWorkingStorageCount) +
                    ' LK=' + ItoSI(DdvLinkageCount) +
                    ' TOTAL=' + ItoSI(DdvTotalItems);
End;

Function GetDdvFDCount : Integer;
Begin
  GetDdvFDCount := DdvFDCount;
End;

Function GetDdvFileSectionCount : Integer;
Begin
  GetDdvFileSectionCount := DdvFileSectionCount;
End;

Function GetDdvWorkingStorageCount : Integer;
Begin
  GetDdvWorkingStorageCount := DdvWorkingStorageCount;
End;

Function GetDdvLinkageCount : Integer;
Begin
  GetDdvLinkageCount := DdvLinkageCount;
End;

Function GetDdvPicAnalysisCount : Integer;
Begin
  GetDdvPicAnalysisCount := DdvPicAnalysisCount;
End;

Function GetDdvStateCount : Integer;
Begin
  GetDdvStateCount := DdvStateCount;
End;


{ ============================================================ }
{ TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET CONDITIONS  }
{           (arbres d expressions, conditions composees)       }
{ ============================================================ }

Const
  { Types de noeuds d expression arithmetique }
  EXP_NONE          = 0;    { noeud vide                              }
  EXP_INTEGER_LIT   = 1;    { litteral entier (123)                   }
  EXP_DECIMAL_LIT   = 2;    { litteral decimal (3.14)                 }
  EXP_IDENTIFIER    = 3;    { identificateur COBOL (WS-TOTAL)         }
  EXP_QUALIFIED     = 4;    { nom OF groupe (WS-NOM OF WS-REC)        }
  EXP_SUBSCRIPT     = 5;    { indexation (NOM(idx))                   }
  EXP_SUBSTRING     = 6;    { reference de sous-chaine (NOM(d:l))     }
  EXP_FIGURATIVE    = 7;    { constante figurative (SPACES, ZEROS)    }
  EXP_STRING_LIT    = 8;    { litteral chaine ('texte')               }
  EXP_ADD           = 10;   { addition (+)                            }
  EXP_SUB           = 11;   { soustraction (-)                        }
  EXP_MUL           = 12;   { multiplication (*)                      }
  EXP_DIV           = 13;   { division (/)                            }
  EXP_POWER         = 14;   { exponentiation (**)                     }
  EXP_NEGATE        = 15;   { negation unaire (-)                     }

  { Types de conditions }
  CND_NONE          = 0;    { condition vide                          }
  CND_RELATION      = 1;    { comparaison (A = B, A > B, etc.)        }
  CND_CLASS         = 2;    { condition de classe (NUMERIC, etc.)      }
  CND_SIGN          = 3;    { condition de signe (POSITIVE, etc.)      }
  CND_CONDITION_NAME = 4;   { nom-condition niveau 88                 }
  CND_AND           = 5;    { condition AND                           }
  CND_OR            = 6;    { condition OR                            }
  CND_NOT           = 7;    { condition NOT                           }
  CND_TRUE          = 8;    { condition TRUE                          }
  CND_FALSE         = 9;    { condition FALSE                         }

  { Operateurs relationnels }
  REL_EQ            = 0;    { EQUAL TO / =                            }
  REL_NE            = 1;    { NOT EQUAL / <>                          }
  REL_LT            = 2;    { LESS THAN / <                           }
  REL_GT            = 3;    { GREATER THAN / >                        }
  REL_LE            = 4;    { NOT GREATER / <=                        }
  REL_GE            = 5;    { NOT LESS / >=                           }

  { Conditions de classe }
  CLS_NUMERIC       = 0;    { IS NUMERIC                              }
  CLS_ALPHABETIC    = 1;    { IS ALPHABETIC                           }
  CLS_ALPHA_LOWER   = 2;    { IS ALPHABETIC-LOWER                     }
  CLS_ALPHA_UPPER   = 3;    { IS ALPHABETIC-UPPER                     }

  { Conditions de signe }
  SGN_POSITIVE      = 0;    { IS POSITIVE                             }
  SGN_NEGATIVE      = 1;    { IS NEGATIVE                             }
  SGN_ZERO          = 2;    { IS ZERO                                 }

  { Priorite des operateurs (plus eleve = plus prioritaire) }
  PRI_OR            = 1;    { OR                                      }
  PRI_AND           = 2;    { AND                                     }
  PRI_NOT           = 3;    { NOT                                     }
  PRI_RELATION      = 4;    { = > < >= <= <>                          }
  PRI_ADD           = 5;    { + -                                     }
  PRI_MUL           = 6;    { * /                                     }
  PRI_POWER         = 7;    { **                                      }
  PRI_UNARY         = 8;    { negation unaire                         }

  { Limites }
  EXP_MAX_NODES     = 256;  { nombre max de noeuds par expression     }
  EXP_MAX_DEPTH     = 32;   { profondeur max d imbrication            }
  EXP_MAX_SUBSCRIPTS = 3;   { nombre max d indices de table           }

Type
  { Noeud d expression arithmetique }
  TExprNode = Record
    NodeType    : Integer;   { EXP_xxx                                }
    IntVal      : LongInt;   { valeur pour EXP_INTEGER_LIT            }
    RealVal     : Real;      { valeur pour EXP_DECIMAL_LIT            }
    StrVal      : TString;   { nom ident, chaine, ou figurative       }
    QualGroup   : TString;   { groupe pour EXP_QUALIFIED (OF grp)     }
    LeftIdx     : Integer;   { index noeud gauche (-1 si aucun)       }
    RightIdx    : Integer;   { index noeud droit (-1 si aucun)        }
    SubCount    : Integer;   { nb indices pour EXP_SUBSCRIPT          }
    SubStart    : Integer;   { debut sous-chaine pour EXP_SUBSTRING   }
    SubLen      : Integer;   { longueur sous-chaine pour EXP_SUBSTRING }
  End;

  { Noeud de condition }
  TCobCondNode = Record
    CondType    : Integer;   { CND_xxx                                }
    RelOp       : Integer;   { REL_xxx pour CND_RELATION              }
    ClassType   : Integer;   { CLS_xxx pour CND_CLASS                 }
    SignType    : Integer;   { SGN_xxx pour CND_SIGN                  }
    LeftExpr    : Integer;   { index expr gauche dans ExprNodes        }
    RightExpr   : Integer;   { index expr droite dans ExprNodes        }
    CondName    : TString;   { nom pour CND_CONDITION_NAME            }
    LeftCond    : Integer;   { index sous-condition gauche             }
    RightCond   : Integer;   { index sous-condition droite             }
    IsNegated   : Boolean;   { NOT applique a cette condition          }
  End;

Var
  ExprNodes          : Array[0..EXP_MAX_NODES-1] Of TExprNode;
  ExprNodeCount      : Integer;   { nombre de noeuds d expression utilises }
  CondNodes          : Array[0..EXP_MAX_NODES-1] Of TCobCondNode;
  CondNodeCount      : Integer;   { nombre de noeuds de condition utilises }
  EcInitialized      : Boolean;   { module initialise ?                    }
  EcStateCount       : Integer;   { compteur d etats                       }
  EcExprParsed       : Integer;   { nombre d expressions parsees           }
  EcCondParsed       : Integer;   { nombre de conditions parsees           }
  EcMaxDepthReached  : Integer;   { profondeur max atteinte                }
  EcFigurativeCount  : Integer;   { constantes figuratives rencontrees     }
  EcSubscriptCount   : Integer;   { references indexees rencontrees        }
  EcSubstringCount   : Integer;   { references de sous-chaines             }
  EcQualifiedCount   : Integer;   { references qualifiees (OF)             }
  EcAbbreviatedCount : Integer;   { conditions abregees                    }

{ ------------------------------------------------------------ }
{ InitExprCondState : initialisation de l etat du parseur      }
{ d expressions arithmetiques et de conditions COBOL           }
{ ------------------------------------------------------------ }

Procedure InitExprCondState;
Begin
  ExprNodeCount      := 0;
  CondNodeCount      := 0;
  EcInitialized      := True;
  EcStateCount       := 1;
  EcExprParsed       := 0;
  EcCondParsed       := 0;
  EcMaxDepthReached  := 0;
  EcFigurativeCount  := 0;
  EcSubscriptCount   := 0;
  EcSubstringCount   := 0;
  EcQualifiedCount   := 0;
  EcAbbreviatedCount := 0;
End;

{ ------------------------------------------------------------ }
{ AllocExprNode : allouer un nouveau noeud d expression        }
{ Retourne l index du noeud alloue, ou -1 si table pleine      }
{ ------------------------------------------------------------ }

Function AllocExprNode : Integer;
Begin
  If ExprNodeCount >= EXP_MAX_NODES Then Begin
    WarnMsg('Expression tree full (max ' + ItoS(EXP_MAX_NODES) + ')');
    AllocExprNode := -1;
    Exit;
  End;
  ExprNodes[ExprNodeCount].NodeType  := EXP_NONE;
  ExprNodes[ExprNodeCount].IntVal    := 0;
  ExprNodes[ExprNodeCount].RealVal   := 0.0;
  ExprNodes[ExprNodeCount].StrVal    := '';
  ExprNodes[ExprNodeCount].QualGroup := '';
  ExprNodes[ExprNodeCount].LeftIdx   := -1;
  ExprNodes[ExprNodeCount].RightIdx  := -1;
  ExprNodes[ExprNodeCount].SubCount  := 0;
  ExprNodes[ExprNodeCount].SubStart  := 0;
  ExprNodes[ExprNodeCount].SubLen    := 0;
  AllocExprNode := ExprNodeCount;
  Inc(ExprNodeCount);
End;

{ ------------------------------------------------------------ }
{ AllocCondNode : allouer un nouveau noeud de condition         }
{ Retourne l index du noeud alloue, ou -1 si table pleine      }
{ ------------------------------------------------------------ }

Function AllocCondNode : Integer;
Begin
  If CondNodeCount >= EXP_MAX_NODES Then Begin
    WarnMsg('Condition tree full (max ' + ItoS(EXP_MAX_NODES) + ')');
    AllocCondNode := -1;
    Exit;
  End;
  CondNodes[CondNodeCount].CondType   := CND_NONE;
  CondNodes[CondNodeCount].RelOp      := REL_EQ;
  CondNodes[CondNodeCount].ClassType  := CLS_NUMERIC;
  CondNodes[CondNodeCount].SignType   := SGN_POSITIVE;
  CondNodes[CondNodeCount].LeftExpr   := -1;
  CondNodes[CondNodeCount].RightExpr  := -1;
  CondNodes[CondNodeCount].CondName   := '';
  CondNodes[CondNodeCount].LeftCond   := -1;
  CondNodes[CondNodeCount].RightCond  := -1;
  CondNodes[CondNodeCount].IsNegated  := False;
  AllocCondNode := CondNodeCount;
  Inc(CondNodeCount);
End;

{ ------------------------------------------------------------ }
{ IsFigurativeConstant : verifie si le token courant est une   }
{ constante figurative COBOL                                   }
{ ------------------------------------------------------------ }

Function IsFigurativeConstant : Boolean;
Begin
  If CurTokType <> TOK_KEYWORD Then Begin
    IsFigurativeConstant := False;
    Exit;
  End;
  Case CurTokNum Of
    KW_SPACES, KW_ZERO, KW_ZEROS, KW_ZEROES,
    KW_HIGH_VALUES, KW_HIGH_VALUE,
    KW_LOW_VALUES, KW_LOW_VALUE :
      IsFigurativeConstant := True;
  Else
    IsFigurativeConstant := False;
  End;
End;

{ ------------------------------------------------------------ }
{ FigurativeConstantName : retourne le nom normalise de la     }
{ constante figurative courante                                }
{ ------------------------------------------------------------ }

Function FigurativeConstantName : TString;
Begin
  Case CurTokNum Of
    KW_SPACES               : FigurativeConstantName := 'SPACES';
    KW_ZERO, KW_ZEROS,
    KW_ZEROES               : FigurativeConstantName := 'ZEROS';
    KW_HIGH_VALUES,
    KW_HIGH_VALUE            : FigurativeConstantName := 'HIGH-VALUES';
    KW_LOW_VALUES,
    KW_LOW_VALUE             : FigurativeConstantName := 'LOW-VALUES';
  Else
    FigurativeConstantName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ExprNodeTypeName : retourne le nom du type de noeud          }
{ d expression                                                 }
{ ------------------------------------------------------------ }

Function ExprNodeTypeName(NT : Integer) : TString;
Begin
  Case NT Of
    EXP_NONE        : ExprNodeTypeName := 'NONE';
    EXP_INTEGER_LIT : ExprNodeTypeName := 'INTEGER';
    EXP_DECIMAL_LIT : ExprNodeTypeName := 'DECIMAL';
    EXP_IDENTIFIER  : ExprNodeTypeName := 'IDENT';
    EXP_QUALIFIED   : ExprNodeTypeName := 'QUALIFIED';
    EXP_SUBSCRIPT   : ExprNodeTypeName := 'SUBSCRIPT';
    EXP_SUBSTRING   : ExprNodeTypeName := 'SUBSTRING';
    EXP_FIGURATIVE  : ExprNodeTypeName := 'FIGURATIVE';
    EXP_STRING_LIT  : ExprNodeTypeName := 'STRING';
    EXP_ADD         : ExprNodeTypeName := 'ADD';
    EXP_SUB         : ExprNodeTypeName := 'SUB';
    EXP_MUL         : ExprNodeTypeName := 'MUL';
    EXP_DIV         : ExprNodeTypeName := 'DIV';
    EXP_POWER       : ExprNodeTypeName := 'POWER';
    EXP_NEGATE      : ExprNodeTypeName := 'NEGATE';
  Else
    ExprNodeTypeName := 'UNKNOWN(' + ItoS(NT) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ CondTypeName : retourne le nom du type de condition           }
{ ------------------------------------------------------------ }

Function CondTypeName(CT : Integer) : TString;
Begin
  Case CT Of
    CND_NONE           : CondTypeName := 'NONE';
    CND_RELATION       : CondTypeName := 'RELATION';
    CND_CLASS          : CondTypeName := 'CLASS';
    CND_SIGN           : CondTypeName := 'SIGN';
    CND_CONDITION_NAME : CondTypeName := 'CONDITION-NAME';
    CND_AND            : CondTypeName := 'AND';
    CND_OR             : CondTypeName := 'OR';
    CND_NOT            : CondTypeName := 'NOT';
    CND_TRUE           : CondTypeName := 'TRUE';
    CND_FALSE          : CondTypeName := 'FALSE';
  Else
    CondTypeName := 'UNKNOWN(' + ItoS(CT) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ RelOpName : retourne le nom de l operateur relationnel        }
{ ------------------------------------------------------------ }

Function RelOpName(R : Integer) : TString;
Begin
  Case R Of
    REL_EQ : RelOpName := '=';
    REL_NE : RelOpName := '<>';
    REL_LT : RelOpName := '<';
    REL_GT : RelOpName := '>';
    REL_LE : RelOpName := '<=';
    REL_GE : RelOpName := '>=';
  Else
    RelOpName := '?';
  End;
End;

{ ------------------------------------------------------------ }
{ ClassCondName : retourne le nom de la condition de classe     }
{ ------------------------------------------------------------ }

Function ClassCondName(C : Integer) : TString;
Begin
  Case C Of
    CLS_NUMERIC     : ClassCondName := 'NUMERIC';
    CLS_ALPHABETIC  : ClassCondName := 'ALPHABETIC';
    CLS_ALPHA_LOWER : ClassCondName := 'ALPHABETIC-LOWER';
    CLS_ALPHA_UPPER : ClassCondName := 'ALPHABETIC-UPPER';
  Else
    ClassCondName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ SignCondName : retourne le nom de la condition de signe       }
{ ------------------------------------------------------------ }

Function SignCondName(S : Integer) : TString;
Begin
  Case S Of
    SGN_POSITIVE : SignCondName := 'POSITIVE';
    SGN_NEGATIVE : SignCondName := 'NEGATIVE';
    SGN_ZERO     : SignCondName := 'ZERO';
  Else
    SignCondName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : analyser un operande primaire                 }
{ Retourne l index du noeud d expression cree                  }
{ Gere : litteraux, identificateurs, qualification (OF),       }
{ indexation (subscript), reference de sous-chaine,            }
{ constantes figuratives, parentheses                          }
{ ------------------------------------------------------------ }

Function ParseExpression : Integer; Forward;

Function ParsePrimary : Integer;
Var
  Idx       : Integer;
  IdentName : TString;
  Depth     : Integer;
Begin
  ParsePrimary := -1;
  Depth := 0;

  { Parenthese ouvrante -> sous-expression }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    Idx := ParseExpression;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
    ParsePrimary := Idx;
    Exit;
  End;

  { Negation unaire (- devant un operande) }
  If CurTokType = TOK_MINUS Then Begin
    LexNextToken;
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_NEGATE;
    ExprNodes[Idx].LeftIdx := ParsePrimary;
    ParsePrimary := Idx;
    Exit;
  End;

  { + unaire (ignore) }
  If CurTokType = TOK_PLUS Then
    LexNextToken;

  { Litteral entier }
  If CurTokType = TOK_INTEGER Then Begin
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_INTEGER_LIT;
    ExprNodes[Idx].IntVal   := CurTokNum;
    ExprNodes[Idx].StrVal   := CurTokStr;
    LexNextToken;
    ParsePrimary := Idx;
    Exit;
  End;

  { Litteral decimal }
  If CurTokType = TOK_DECIMAL Then Begin
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_DECIMAL_LIT;
    ExprNodes[Idx].RealVal  := CurTokReal;
    ExprNodes[Idx].StrVal   := CurTokStr;
    LexNextToken;
    ParsePrimary := Idx;
    Exit;
  End;

  { Litteral chaine }
  If CurTokType = TOK_STRING Then Begin
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_STRING_LIT;
    ExprNodes[Idx].StrVal   := CurTokStr;
    LexNextToken;
    ParsePrimary := Idx;
    Exit;
  End;

  { Constante figurative }
  If IsFigurativeConstant Then Begin
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_FIGURATIVE;
    ExprNodes[Idx].StrVal   := FigurativeConstantName;
    Inc(EcFigurativeCount);
    LexNextToken;
    ParsePrimary := Idx;
    Exit;
  End;

  { Identificateur COBOL (peut etre suivi de OF/IN, subscript, substring) }
  If (CurTokType = TOK_IDENT) Or
     ((CurTokType = TOK_KEYWORD) And
      Not IsFigurativeConstant And
      (CurTokNum <> KW_AND) And (CurTokNum <> KW_OR) And
      (CurTokNum <> KW_NOT)) Then Begin
    IdentName := CurTokStr;
    LexNextToken;

    { Qualification : nom OF groupe (ou nom IN groupe) }
    If (CurTokType = TOK_KEYWORD) And
       ((CurTokNum = KW_OF) Or (CurTokNum = KW_IN)) Then Begin
      LexNextToken;
      Idx := AllocExprNode;
      If Idx < 0 Then Exit;
      ExprNodes[Idx].NodeType  := EXP_QUALIFIED;
      ExprNodes[Idx].StrVal    := IdentName;
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
        ExprNodes[Idx].QualGroup := CurTokStr;
        LexNextToken;
      End;
      Inc(EcQualifiedCount);
      ParsePrimary := Idx;
      Exit;
    End;

    { Subscript ou substring : nom(args) }
    If CurTokType = TOK_LPAREN Then Begin
      LexNextToken;
      { Verifier si c est une reference de sous-chaine : nom(debut:longueur) }
      { On parse le premier argument }
      Idx := AllocExprNode;
      If Idx < 0 Then Exit;

      { Lire premier argument comme expression }
      Depth := 0;
      If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_IDENT) Or
         (CurTokType = TOK_KEYWORD) Then Begin
        { Verifier la forme d:l (sous-chaine) en regardant apres un entier }
        { On stocke d abord comme subscript, puis on corrige si ':' suit }
        ExprNodes[Idx].NodeType := EXP_SUBSCRIPT;
        ExprNodes[Idx].StrVal   := IdentName;
        ExprNodes[Idx].SubCount := 0;

        { Parser les indices separes par des virgules }
        While (Not LexEOF) And (CurTokType <> TOK_RPAREN) And
              (Depth < EXP_MAX_SUBSCRIPTS) Do Begin
          { Ignorer le contenu de l indice pour l instant }
          If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_IDENT) Or
             (CurTokType = TOK_KEYWORD) Or (CurTokType = TOK_DECIMAL) Then Begin
            { Verifier si un ':' suit (forme sous-chaine) }
            { En COBOL, la sous-chaine est nom(debut:longueur) }
            { Le ':' n est pas un token standard, on regarde la ligne brute }
            Inc(ExprNodes[Idx].SubCount);
            LexNextToken;
          End
          Else If CurTokType = TOK_PLUS Then
            LexNextToken
          Else If CurTokType = TOK_MINUS Then
            LexNextToken
          Else If CurTokType = TOK_STAR Then
            LexNextToken
          Else
            LexNextToken;

          If CurTokType = TOK_COMMA Then
            LexNextToken;

          Inc(Depth);
        End;

        If CurTokType = TOK_RPAREN Then
          LexNextToken;

        Inc(EcSubscriptCount);
        ParsePrimary := Idx;
        Exit;
      End
      Else Begin
        { Parenthese vide ou inattendue }
        ExprNodes[Idx].NodeType := EXP_IDENTIFIER;
        ExprNodes[Idx].StrVal   := IdentName;
        If CurTokType = TOK_RPAREN Then
          LexNextToken;
        ParsePrimary := Idx;
        Exit;
      End;
    End;

    { Identificateur simple }
    Idx := AllocExprNode;
    If Idx < 0 Then Exit;
    ExprNodes[Idx].NodeType := EXP_IDENTIFIER;
    ExprNodes[Idx].StrVal   := IdentName;
    ParsePrimary := Idx;
    Exit;
  End;

  { Rien reconnu : retourner -1 }
End;

{ ------------------------------------------------------------ }
{ ParseFactor : analyser un facteur (avec exponentiation)      }
{ facteur = primaire [ ** facteur ]                            }
{ L exponentiation est associative a droite                    }
{ ------------------------------------------------------------ }

Function ParseFactor : Integer;
Var
  Left, Right, OpIdx : Integer;
Begin
  Left := ParsePrimary;

  { Operateur ** (exponentiation) }
  If CurTokType = TOK_POWER Then Begin
    LexNextToken;
    Right := ParseFactor; { associativite droite : recursion }
    OpIdx := AllocExprNode;
    If OpIdx >= 0 Then Begin
      ExprNodes[OpIdx].NodeType := EXP_POWER;
      ExprNodes[OpIdx].LeftIdx  := Left;
      ExprNodes[OpIdx].RightIdx := Right;
      Left := OpIdx;
    End;
  End;

  ParseFactor := Left;
End;

{ ------------------------------------------------------------ }
{ ParseTerm : analyser un terme (multiplication, division)     }
{ terme = facteur (op facteur)                                 }
{ ------------------------------------------------------------ }

Function ParseTerm : Integer;
Var
  Left, Right, OpIdx : Integer;
  OpType : Integer;
Begin
  Left := ParseFactor;

  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do Begin
    If CurTokType = TOK_STAR Then
      OpType := EXP_MUL
    Else
      OpType := EXP_DIV;
    LexNextToken;
    Right := ParseFactor;
    OpIdx := AllocExprNode;
    If OpIdx >= 0 Then Begin
      ExprNodes[OpIdx].NodeType := OpType;
      ExprNodes[OpIdx].LeftIdx  := Left;
      ExprNodes[OpIdx].RightIdx := Right;
      Left := OpIdx;
    End;
  End;

  ParseTerm := Left;
End;

{ ------------------------------------------------------------ }
{ ParseSimpleExpr : analyser une expression simple (+ - )      }
{ expr_simple = terme (op terme)                               }
{ ------------------------------------------------------------ }

Function ParseSimpleExpr : Integer;
Var
  Left, Right, OpIdx : Integer;
  OpType : Integer;
Begin
  Left := ParseTerm;

  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Do Begin
    If CurTokType = TOK_PLUS Then
      OpType := EXP_ADD
    Else
      OpType := EXP_SUB;
    LexNextToken;
    Right := ParseTerm;
    OpIdx := AllocExprNode;
    If OpIdx >= 0 Then Begin
      ExprNodes[OpIdx].NodeType := OpType;
      ExprNodes[OpIdx].LeftIdx  := Left;
      ExprNodes[OpIdx].RightIdx := Right;
      Left := OpIdx;
    End;
  End;

  ParseSimpleExpr := Left;
End;

{ ------------------------------------------------------------ }
{ ParseExpression : analyser une expression arithmetique       }
{ complete avec priorite des operateurs                        }
{ expression = expression_simple                               }
{ ------------------------------------------------------------ }

Function ParseExpression : Integer;
Var
  Depth : Integer;
Begin
  Inc(EcExprParsed);
  Depth := EcExprParsed;
  If Depth > EcMaxDepthReached Then
    EcMaxDepthReached := Depth;

  ParseExpression := ParseSimpleExpr;

  Dec(EcExprParsed);
  Inc(EcExprParsed);
End;

{ ------------------------------------------------------------ }
{ ParseRelationalOp : analyser un operateur relationnel COBOL  }
{ Retourne le code REL_xxx, ou -1 si pas d operateur           }
{ Gere les formes :                                            }
{   = < > <= >= <> (symboles)                                  }
{   EQUAL [TO], GREATER [THAN], LESS [THAN]                    }
{   NOT EQUAL, NOT GREATER, NOT LESS                           }
{ ------------------------------------------------------------ }

Function ParseRelationalOp : Integer;
Var
  Negated : Boolean;
Begin
  ParseRelationalOp := -1;
  Negated := False;

  { Verifier NOT prefixe }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    Negated := True;
    LexNextToken;
  End;

  { Symboles }
  If CurTokType = TOK_EQ Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_NE
    Else ParseRelationalOp := REL_EQ;
    Exit;
  End;

  If CurTokType = TOK_NE Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_EQ
    Else ParseRelationalOp := REL_NE;
    Exit;
  End;

  If CurTokType = TOK_LT Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_GE
    Else ParseRelationalOp := REL_LT;
    Exit;
  End;

  If CurTokType = TOK_GT Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_LE
    Else ParseRelationalOp := REL_GT;
    Exit;
  End;

  If CurTokType = TOK_LE Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_GT
    Else ParseRelationalOp := REL_LE;
    Exit;
  End;

  If CurTokType = TOK_GE Then Begin
    LexNextToken;
    If Negated Then ParseRelationalOp := REL_LT
    Else ParseRelationalOp := REL_GE;
    Exit;
  End;

  { Mots-cles relationnels }
  If CurTokType = TOK_KEYWORD Then Begin
    Case CurTokNum Of
      KW_EQUAL : Begin
        LexNextToken;
        { Optionnel : TO }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
          LexNextToken;
        If Negated Then ParseRelationalOp := REL_NE
        Else ParseRelationalOp := REL_EQ;
      End;
      KW_GREATER : Begin
        LexNextToken;
        { Optionnel : THAN }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_THAN) Then
          LexNextToken;
        { Optionnel : OR EQUAL [TO] }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OR) Then Begin
          LexNextToken;
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_EQUAL) Then Begin
            LexNextToken;
            If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
              LexNextToken;
          End;
          If Negated Then ParseRelationalOp := REL_LT
          Else ParseRelationalOp := REL_GE;
        End
        Else Begin
          If Negated Then ParseRelationalOp := REL_LE
          Else ParseRelationalOp := REL_GT;
        End;
      End;
      KW_LESS : Begin
        LexNextToken;
        { Optionnel : THAN }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_THAN) Then
          LexNextToken;
        { Optionnel : OR EQUAL [TO] }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OR) Then Begin
          LexNextToken;
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_EQUAL) Then Begin
            LexNextToken;
            If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
              LexNextToken;
          End;
          If Negated Then ParseRelationalOp := REL_GT
          Else ParseRelationalOp := REL_LE;
        End
        Else Begin
          If Negated Then ParseRelationalOp := REL_GE
          Else ParseRelationalOp := REL_LT;
        End;
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSimpleCondition : analyser une condition simple COBOL   }
{ Retourne l index du noeud de condition cree                  }
{ Gere : comparaisons, conditions de classe, de signe,        }
{ noms-condition (niveau 88), conditions abregees              }
{ ------------------------------------------------------------ }

Function ParseCondition : Integer; Forward;

Function ParseSimpleCondition : Integer;
Var
  LeftExpr  : Integer;
  RightExpr : Integer;
  RelOp     : Integer;
  CIdx      : Integer;
  IsNeg     : Boolean;
Begin
  ParseSimpleCondition := -1;
  IsNeg := False;

  { NOT prefixe }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    IsNeg := True;
    LexNextToken;
  End;

  { Parenthese ouvrante -> sous-condition }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    CIdx := ParseCondition;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
    If IsNeg And (CIdx >= 0) Then
      CondNodes[CIdx].IsNegated := Not CondNodes[CIdx].IsNegated;
    ParseSimpleCondition := CIdx;
    Exit;
  End;

  { TRUE / FALSE }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRUE) Then Begin
    CIdx := AllocCondNode;
    If CIdx >= 0 Then Begin
      CondNodes[CIdx].CondType := CND_TRUE;
      CondNodes[CIdx].IsNegated := IsNeg;
    End;
    LexNextToken;
    ParseSimpleCondition := CIdx;
    Exit;
  End;

  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FALSE) Then Begin
    CIdx := AllocCondNode;
    If CIdx >= 0 Then Begin
      CondNodes[CIdx].CondType := CND_FALSE;
      CondNodes[CIdx].IsNegated := IsNeg;
    End;
    LexNextToken;
    ParseSimpleCondition := CIdx;
    Exit;
  End;

  { Parser l expression gauche }
  LeftExpr := ParseExpression;

  { Optionnel : IS }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
    LexNextToken;

  { Optionnel : NOT apres IS }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    IsNeg := Not IsNeg;
    LexNextToken;
  End;

  { Condition de classe : NUMERIC, ALPHABETIC, etc. }
  If CurTokType = TOK_KEYWORD Then Begin
    Case CurTokNum Of
      KW_NUMERIC : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType  := CND_CLASS;
          CondNodes[CIdx].ClassType := CLS_NUMERIC;
          CondNodes[CIdx].LeftExpr  := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      KW_ALPHABETIC : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType  := CND_CLASS;
          CondNodes[CIdx].ClassType := CLS_ALPHABETIC;
          CondNodes[CIdx].LeftExpr  := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      KW_ALPHABETIC_LOWER : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType  := CND_CLASS;
          CondNodes[CIdx].ClassType := CLS_ALPHA_LOWER;
          CondNodes[CIdx].LeftExpr  := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      KW_ALPHABETIC_UPPER : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType  := CND_CLASS;
          CondNodes[CIdx].ClassType := CLS_ALPHA_UPPER;
          CondNodes[CIdx].LeftExpr  := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      { Condition de signe : POSITIVE, NEGATIVE, ZERO }
      KW_POSITIVE : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType := CND_SIGN;
          CondNodes[CIdx].SignType := SGN_POSITIVE;
          CondNodes[CIdx].LeftExpr := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      KW_NEGATIVE : Begin
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType := CND_SIGN;
          CondNodes[CIdx].SignType := SGN_NEGATIVE;
          CondNodes[CIdx].LeftExpr := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
      KW_ZERO, KW_ZEROS, KW_ZEROES : Begin
        { Si on a eu un operateur relationnel avant, c est une comparaison }
        { Sinon c est une condition de signe }
        CIdx := AllocCondNode;
        If CIdx >= 0 Then Begin
          CondNodes[CIdx].CondType := CND_SIGN;
          CondNodes[CIdx].SignType := SGN_ZERO;
          CondNodes[CIdx].LeftExpr := LeftExpr;
          CondNodes[CIdx].IsNegated := IsNeg;
        End;
        LexNextToken;
        ParseSimpleCondition := CIdx;
        Exit;
      End;
    End;
  End;

  { Operateur relationnel }
  RelOp := ParseRelationalOp;
  If RelOp >= 0 Then Begin
    RightExpr := ParseExpression;
    CIdx := AllocCondNode;
    If CIdx >= 0 Then Begin
      CondNodes[CIdx].CondType  := CND_RELATION;
      CondNodes[CIdx].RelOp     := RelOp;
      CondNodes[CIdx].LeftExpr  := LeftExpr;
      CondNodes[CIdx].RightExpr := RightExpr;
      CondNodes[CIdx].IsNegated := IsNeg;
    End;

    { Conditions abregees : A = 1 OR 2 OR 3 }
    While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OR) Do Begin
      { Verifier si c est une condition abregee (pas un OR logique) }
      { En COBOL, A = 1 OR 2 signifie A = 1 OR A = 2 }
      { On regarde si le token apres OR est un litteral ou un ident }
      LexNextToken;
      { Si on trouve un operateur relationnel, c est un OR logique }
      If (CurTokType = TOK_KEYWORD) And
         ((CurTokNum = KW_NOT) Or (CurTokNum = KW_EQUAL) Or
          (CurTokNum = KW_GREATER) Or (CurTokNum = KW_LESS)) Then Begin
        { C est probablement un OR logique -> on arrete l abreviation }
        { On remet le OR pour le traitement dans ParseCondition }
        { Note : on ne peut pas remettre le token, on continue }
        { en tant que nouvelle condition }
        RightExpr := ParseExpression;
        { Creer une nouvelle condition relation }
        If CIdx >= 0 Then Begin
          { Creer un OR logique }
          { On parse la suite comme une nouvelle condition simple }
          { avec le meme RelOp et LeftExpr }
        End;
        Break;
      End
      Else If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_DECIMAL) Or
              (CurTokType = TOK_STRING) Or (CurTokType = TOK_IDENT) Or
              IsFigurativeConstant Then Begin
        { Condition abregee : meme operateur, meme operande gauche }
        RightExpr := ParseExpression;
        If CIdx >= 0 Then Begin
          { Creer un nouveau noeud de condition OR avec la meme relation }
          { CIdx reste le noeud racine, on construit un arbre OR }
          { leftcond = ancien CIdx, rightcond = nouvelle relation }
          { Sauvegarder l ancien CIdx }
          { Nouveau noeud relation }
          { Nouveau noeud OR }
        End;
        Inc(EcAbbreviatedCount);
      End
      Else
        Break;
    End;

    ParseSimpleCondition := CIdx;
    Exit;
  End;

  { Si aucun operateur relationnel ni condition de classe/signe }
  { C est peut-etre un nom-condition (niveau 88) }
  If LeftExpr >= 0 Then Begin
    CIdx := AllocCondNode;
    If CIdx >= 0 Then Begin
      CondNodes[CIdx].CondType := CND_CONDITION_NAME;
      CondNodes[CIdx].LeftExpr := LeftExpr;
      If ExprNodes[LeftExpr].NodeType = EXP_IDENTIFIER Then
        CondNodes[CIdx].CondName := ExprNodes[LeftExpr].StrVal
      Else If ExprNodes[LeftExpr].NodeType = EXP_QUALIFIED Then
        CondNodes[CIdx].CondName := ExprNodes[LeftExpr].StrVal;
      CondNodes[CIdx].IsNegated := IsNeg;
    End;
    ParseSimpleCondition := CIdx;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseCondition : analyser une condition COBOL complete       }
{ avec operateurs logiques AND, OR, NOT                        }
{ condition = simple_condition (op simple_condition)            }
{ ------------------------------------------------------------ }

Function ParseCondition : Integer;
Var
  Left, Right, CIdx : Integer;
  LogOp : Integer;
Begin
  Inc(EcCondParsed);
  Left := ParseSimpleCondition;

  While (CurTokType = TOK_KEYWORD) And
        ((CurTokNum = KW_AND) Or (CurTokNum = KW_OR)) Do Begin
    If CurTokNum = KW_AND Then
      LogOp := CND_AND
    Else
      LogOp := CND_OR;
    LexNextToken;

    Right := ParseSimpleCondition;
    CIdx := AllocCondNode;
    If CIdx >= 0 Then Begin
      CondNodes[CIdx].CondType  := LogOp;
      CondNodes[CIdx].LeftCond  := Left;
      CondNodes[CIdx].RightCond := Right;
    End;
    Left := CIdx;
  End;

  ParseCondition := Left;
End;

{ ------------------------------------------------------------ }
{ DumpExprTree : afficher un arbre d expression (recursif)     }
{ ------------------------------------------------------------ }

Procedure DumpExprTree(Idx : Integer; Indent : Integer);
Var
  I   : Integer;
  Prf : TString;
Begin
  If (Idx < 0) Or (Idx >= ExprNodeCount) Then Exit;

  Prf := '';
  For I := 1 To Indent Do
    Prf := Prf + '  ';

  Write(Prf, ExprNodeTypeName(ExprNodes[Idx].NodeType));

  Case ExprNodes[Idx].NodeType Of
    EXP_INTEGER_LIT : WriteLn(' ', ExprNodes[Idx].IntVal);
    EXP_DECIMAL_LIT : WriteLn(' ', ExprNodes[Idx].StrVal);
    EXP_IDENTIFIER  : WriteLn(' ', ExprNodes[Idx].StrVal);
    EXP_QUALIFIED   : WriteLn(' ', ExprNodes[Idx].StrVal,
                              ' OF ', ExprNodes[Idx].QualGroup);
    EXP_SUBSCRIPT   : WriteLn(' ', ExprNodes[Idx].StrVal,
                              '(', ExprNodes[Idx].SubCount, ' indices)');
    EXP_SUBSTRING   : WriteLn(' ', ExprNodes[Idx].StrVal,
                              '(', ExprNodes[Idx].SubStart,
                              ':', ExprNodes[Idx].SubLen, ')');
    EXP_FIGURATIVE  : WriteLn(' ', ExprNodes[Idx].StrVal);
    EXP_STRING_LIT  : WriteLn(' "', ExprNodes[Idx].StrVal, '"');
  Else
    WriteLn;
  End;

  If ExprNodes[Idx].LeftIdx >= 0 Then
    DumpExprTree(ExprNodes[Idx].LeftIdx, Indent + 1);
  If ExprNodes[Idx].RightIdx >= 0 Then
    DumpExprTree(ExprNodes[Idx].RightIdx, Indent + 1);
End;

{ ------------------------------------------------------------ }
{ DumpCondition : afficher un arbre de condition (recursif)    }
{ ------------------------------------------------------------ }

Procedure DumpCondition(Idx : Integer; Indent : Integer);
Var
  I   : Integer;
  Prf : TString;
Begin
  If (Idx < 0) Or (Idx >= CondNodeCount) Then Exit;

  Prf := '';
  For I := 1 To Indent Do
    Prf := Prf + '  ';

  If CondNodes[Idx].IsNegated Then
    Write(Prf, 'NOT ');

  Case CondNodes[Idx].CondType Of
    CND_RELATION : Begin
      WriteLn(Prf, 'RELATION ', RelOpName(CondNodes[Idx].RelOp));
      If CondNodes[Idx].LeftExpr >= 0 Then
        DumpExprTree(CondNodes[Idx].LeftExpr, Indent + 1);
      If CondNodes[Idx].RightExpr >= 0 Then
        DumpExprTree(CondNodes[Idx].RightExpr, Indent + 1);
    End;
    CND_CLASS : Begin
      WriteLn(Prf, 'CLASS ', ClassCondName(CondNodes[Idx].ClassType));
      If CondNodes[Idx].LeftExpr >= 0 Then
        DumpExprTree(CondNodes[Idx].LeftExpr, Indent + 1);
    End;
    CND_SIGN : Begin
      WriteLn(Prf, 'SIGN ', SignCondName(CondNodes[Idx].SignType));
      If CondNodes[Idx].LeftExpr >= 0 Then
        DumpExprTree(CondNodes[Idx].LeftExpr, Indent + 1);
    End;
    CND_CONDITION_NAME :
      WriteLn(Prf, 'CONDITION-NAME ', CondNodes[Idx].CondName);
    CND_AND : Begin
      WriteLn(Prf, 'AND');
      DumpCondition(CondNodes[Idx].LeftCond, Indent + 1);
      DumpCondition(CondNodes[Idx].RightCond, Indent + 1);
    End;
    CND_OR : Begin
      WriteLn(Prf, 'OR');
      DumpCondition(CondNodes[Idx].LeftCond, Indent + 1);
      DumpCondition(CondNodes[Idx].RightCond, Indent + 1);
    End;
    CND_NOT : Begin
      WriteLn(Prf, 'NOT');
      DumpCondition(CondNodes[Idx].LeftCond, Indent + 1);
    End;
    CND_TRUE  : WriteLn(Prf, 'TRUE');
    CND_FALSE : WriteLn(Prf, 'FALSE');
  Else
    WriteLn(Prf, 'UNKNOWN');
  End;
End;

{ ------------------------------------------------------------ }
{ DumpExprCondState : afficher un resume de l etat du parseur  }
{ d expressions et de conditions                               }
{ ------------------------------------------------------------ }

Procedure DumpExprCondState;
Begin
  WriteLn('--- EXPRESSIONS & CONDITIONS ---');
  WriteLn('  Expressions parsees   : ', EcExprParsed);
  WriteLn('  Conditions parsees    : ', EcCondParsed);
  WriteLn('  Noeuds expression     : ', ExprNodeCount);
  WriteLn('  Noeuds condition      : ', CondNodeCount);
  WriteLn('  Constantes figuratives: ', EcFigurativeCount);
  WriteLn('  References indexees   : ', EcSubscriptCount);
  WriteLn('  Sous-chaines          : ', EcSubstringCount);
  WriteLn('  References qualifiees : ', EcQualifiedCount);
  WriteLn('  Conditions abregees   : ', EcAbbreviatedCount);
End;

{ 10 fonctions accesseurs pour TODO 08                         }

Function IsEcInitialized : Boolean;
Begin
  IsEcInitialized := EcInitialized;
End;

Function IsEcEmpty : Boolean;
Begin
  IsEcEmpty := (ExprNodeCount = 0) And (CondNodeCount = 0);
End;

Function GetEcExprParsed : Integer;
Begin
  GetEcExprParsed := EcExprParsed;
End;

Function GetEcStatus : TString;
Begin
  If Not EcInitialized Then
    GetEcStatus := 'NON INITIALISE'
  Else
    GetEcStatus := 'EXPR=' + ItoSI(ExprNodeCount) +
                   ' COND=' + ItoSI(CondNodeCount) +
                   ' FIG=' + ItoSI(EcFigurativeCount) +
                   ' SUB=' + ItoSI(EcSubscriptCount);
End;

Function GetEcCondParsed : Integer;
Begin
  GetEcCondParsed := EcCondParsed;
End;

Function GetEcExprNodeCount : Integer;
Begin
  GetEcExprNodeCount := ExprNodeCount;
End;

Function GetEcCondNodeCount : Integer;
Begin
  GetEcCondNodeCount := CondNodeCount;
End;

Function GetEcFigurativeCount : Integer;
Begin
  GetEcFigurativeCount := EcFigurativeCount;
End;

Function GetEcMaxNodes : Integer;
Begin
  GetEcMaxNodes := EXP_MAX_NODES;
End;

Function GetEcStateCount : Integer;
Begin
  GetEcStateCount := EcStateCount;
End;


{ ============================================================ }
{ TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386}
{           (DISPLAY, COMP/BINARY, COMP-3, instructions COBOL) }
{ ============================================================ }

Const
  { Types d operateurs arithmetiques internes }
  AOP_NONE          = 0;    { pas d operation                          }
  AOP_ADD           = 1;    { addition                                 }
  AOP_SUB           = 2;    { soustraction                             }
  AOP_MUL           = 3;    { multiplication                           }
  AOP_DIV           = 4;    { division                                 }
  AOP_POWER         = 5;    { puissance                                }
  AOP_NEGATE        = 6;    { negation unaire                          }

  { Types de donnees pour la generation }
  ADT_DISPLAY       = 0;    { PIC 9 : DISPLAY (ASCII decimal)          }
  ADT_COMP          = 1;    { COMP/BINARY : entier binaire 32 bits     }
  ADT_PACKED        = 2;    { COMP-3 : decimal condense (BCD)          }
  ADT_COMP1         = 3;    { COMP-1 : flottant simple precision       }
  ADT_COMP2         = 4;    { COMP-2 : flottant double precision       }

  { Instructions arithmetiques COBOL }
  AIS_ADD           = 0;    { ADD ... TO ...                           }
  AIS_SUBTRACT      = 1;    { SUBTRACT ... FROM ...                    }
  AIS_MULTIPLY      = 2;    { MULTIPLY ... BY ...                      }
  AIS_DIVIDE        = 3;    { DIVIDE ... INTO/BY ...                   }
  AIS_COMPUTE       = 4;    { COMPUTE ... = expression                 }

  { Limites }
  AGN_MAX_ARGS      = 8;    { max d operandes dans ADD/SUBTRACT        }
  AGN_MAX_LABELS    = 256;  { max labels generes pour sauts            }
  AGN_MAX_STACK     = 64;   { profondeur max pile d evaluation         }

  { Nombre de types de donnees, d operations et d instructions }
  AGN_NUM_DATA_TYPES  = 5;
  AGN_NUM_OPS         = 7;
  AGN_NUM_INSTRUCTIONS = 5;

Var
  { Etat du module }
  AgnInitialized   : Boolean;
  AgnStateCount    : Integer;

  { Compteur de labels generes }
  AgnLabelNum      : Integer;

  { Compteurs d instructions }
  AgnAddCount      : Integer;
  AgnSubtractCount : Integer;
  AgnMultiplyCount : Integer;
  AgnDivideCount   : Integer;
  AgnComputeCount  : Integer;

  { Compteurs de clauses }
  AgnRoundedCount  : Integer;
  AgnSizeErrCount  : Integer;

  { Compteurs de types de donnees traites }
  AgnDisplayOps    : Integer;
  AgnCompOps       : Integer;
  AgnPackedOps     : Integer;

  { Total des operations generees }
  AgnTotalGenerated : Integer;

{ ------------------------------------------------------------ }
{ InitArithGenState : initialisation du module de generation    }
{   arithmetique 80386 pour les operations COBOL               }
{ ------------------------------------------------------------ }

Procedure InitArithGenState;
Begin
  AgnInitialized   := True;
  AgnStateCount    := AgnStateCount + 1;
  AgnLabelNum      := 0;
  AgnAddCount      := 0;
  AgnSubtractCount := 0;
  AgnMultiplyCount := 0;
  AgnDivideCount   := 0;
  AgnComputeCount  := 0;
  AgnRoundedCount  := 0;
  AgnSizeErrCount  := 0;
  AgnDisplayOps    := 0;
  AgnCompOps       := 0;
  AgnPackedOps     := 0;
  AgnTotalGenerated := 0;
End;

{ ------------------------------------------------------------ }
{ GenArithLabel : generer un label unique pour les sauts        }
{   dans le code arithmetique genere                           }
{ ------------------------------------------------------------ }

Function GenArithLabel : TString;
Begin
  AgnLabelNum := AgnLabelNum + 1;
  GenArithLabel := '_COBAG_L' + ItoS(AgnLabelNum);
End;

{ ------------------------------------------------------------ }
{ AgnDataTypeName : nom textuel d un type de donnee            }
{ ------------------------------------------------------------ }

Function AgnDataTypeName(DT : Integer) : TString;
Begin
  Case DT Of
    ADT_DISPLAY : AgnDataTypeName := 'DISPLAY';
    ADT_COMP    : AgnDataTypeName := 'COMP/BINARY';
    ADT_PACKED  : AgnDataTypeName := 'COMP-3/PACKED';
    ADT_COMP1   : AgnDataTypeName := 'COMP-1';
    ADT_COMP2   : AgnDataTypeName := 'COMP-2';
  Else
    AgnDataTypeName := 'UNKNOWN(' + ItoS(DT) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ArithOpName : nom textuel d une operation arithmetique        }
{ ------------------------------------------------------------ }

Function ArithOpName(Op : Integer) : TString;
Begin
  Case Op Of
    AOP_NONE   : ArithOpName := 'NONE';
    AOP_ADD    : ArithOpName := 'ADD';
    AOP_SUB    : ArithOpName := 'SUB';
    AOP_MUL    : ArithOpName := 'MUL';
    AOP_DIV    : ArithOpName := 'DIV';
    AOP_POWER  : ArithOpName := 'POWER';
    AOP_NEGATE : ArithOpName := 'NEGATE';
  Else
    ArithOpName := 'OP(' + ItoS(Op) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ArithInstrName : nom textuel d une instruction COBOL arithm  }
{ ------------------------------------------------------------ }

Function ArithInstrName(Instr : Integer) : TString;
Begin
  Case Instr Of
    AIS_ADD      : ArithInstrName := 'ADD';
    AIS_SUBTRACT : ArithInstrName := 'SUBTRACT';
    AIS_MULTIPLY : ArithInstrName := 'MULTIPLY';
    AIS_DIVIDE   : ArithInstrName := 'DIVIDE';
    AIS_COMPUTE  : ArithInstrName := 'COMPUTE';
  Else
    ArithInstrName := 'INSTR(' + ItoS(Instr) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ GenLoadDisplay : generer le code pour charger une variable    }
{   DISPLAY (PIC 9) dans le registre EAX                       }
{   Chaque caractere ASCII '0'-'9' est converti en chiffre,    }
{   puis accumule : EAX = EAX * 10 + digit                    }
{   VarName = label ASM de la variable DISPLAY                  }
{   VarSize = taille en octets (nombre de chiffres)            }
{   HasSign = True si PIC S9 (signe en tete)                   }
{ ------------------------------------------------------------ }

Procedure GenLoadDisplay(VarName : TString; VarSize : Integer;
                         HasSign : Boolean);
Var
  LblLoop : TString;
Begin
  AgnDisplayOps := AgnDisplayOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  LblLoop := GenArithLabel;
  WriteLn('    ; Charger DISPLAY ' + VarName + ' (' +
          ItoS(VarSize) + ' chiffres) dans EAX');
  WriteLn('    XOR  EAX, EAX');
  If HasSign Then Begin
    WriteLn('    MOV  BL, [' + VarName + ']');
    WriteLn('    LEA  ESI, [' + VarName + '+1]');
    WriteLn('    MOV  ECX, ' + ItoS(VarSize - 1));
  End Else Begin
    WriteLn('    LEA  ESI, [' + VarName + ']');
    WriteLn('    MOV  ECX, ' + ItoS(VarSize));
  End;
  WriteLn(LblLoop + '_CVT:');
  WriteLn('    IMUL EAX, EAX, 10');
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    MOV  DL, [ESI]');
  WriteLn('    SUB  DL, 30h');
  WriteLn('    ADD  EAX, EDX');
  WriteLn('    INC  ESI');
  WriteLn('    DEC  ECX');
  WriteLn('    JNZ  ' + LblLoop + '_CVT');
  If HasSign Then Begin
    WriteLn('    CMP  BL, 2Dh');
    WriteLn('    JNE  ' + LblLoop + '_POS');
    WriteLn('    NEG  EAX');
    WriteLn(LblLoop + '_POS:');
  End;
End;

{ ------------------------------------------------------------ }
{ GenStoreDisplay : generer le code pour stocker EAX dans une  }
{   variable DISPLAY (PIC 9)                                   }
{   EAX est divise successivement par 10, les restes donnent   }
{   les chiffres ASCII de droite a gauche                      }
{ ------------------------------------------------------------ }

Procedure GenStoreDisplay(VarName : TString; VarSize : Integer;
                          HasSign : Boolean);
Var
  LblLoop : TString;
Begin
  AgnDisplayOps := AgnDisplayOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  LblLoop := GenArithLabel;
  WriteLn('    ; Stocker EAX dans DISPLAY ' + VarName);
  If HasSign Then Begin
    WriteLn('    MOV  BL, 2Bh');
    WriteLn('    TEST EAX, EAX');
    WriteLn('    JNS  ' + LblLoop + '_NS');
    WriteLn('    MOV  BL, 2Dh');
    WriteLn('    NEG  EAX');
    WriteLn(LblLoop + '_NS:');
    WriteLn('    MOV  [' + VarName + '], BL');
    WriteLn('    LEA  EDI, [' + VarName + '+' +
            ItoS(VarSize - 1) + ']');
    WriteLn('    MOV  ECX, ' + ItoS(VarSize - 1));
  End Else Begin
    WriteLn('    LEA  EDI, [' + VarName + '+' +
            ItoS(VarSize - 1) + ']');
    WriteLn('    MOV  ECX, ' + ItoS(VarSize));
  End;
  WriteLn(LblLoop + '_STR:');
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    MOV  EBX, 10');
  WriteLn('    DIV  EBX');
  WriteLn('    ADD  DL, 30h');
  WriteLn('    MOV  [EDI], DL');
  WriteLn('    DEC  EDI');
  WriteLn('    DEC  ECX');
  WriteLn('    JNZ  ' + LblLoop + '_STR');
End;

{ ------------------------------------------------------------ }
{ GenLoadComp : charger une variable COMP/BINARY dans EAX      }
{   Les donnees COMP sont deja en binaire (1, 2 ou 4 octets)  }
{ ------------------------------------------------------------ }

Procedure GenLoadComp(VarName : TString; VarSize : Integer);
Begin
  AgnCompOps := AgnCompOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  WriteLn('    ; Charger COMP ' + VarName + ' dans EAX');
  Case VarSize Of
    1 : Begin
          WriteLn('    XOR  EAX, EAX');
          WriteLn('    MOV  AL, [' + VarName + ']');
        End;
    2 : Begin
          WriteLn('    XOR  EAX, EAX');
          WriteLn('    MOV  AX, [' + VarName + ']');
        End;
    4 : WriteLn('    MOV  EAX, [' + VarName + ']');
  Else
    WriteLn('    MOV  EAX, [' + VarName + ']');
  End;
End;

{ ------------------------------------------------------------ }
{ GenStoreComp : stocker EAX dans une variable COMP/BINARY     }
{ ------------------------------------------------------------ }

Procedure GenStoreComp(VarName : TString; VarSize : Integer);
Begin
  AgnCompOps := AgnCompOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  WriteLn('    ; Stocker EAX dans COMP ' + VarName);
  Case VarSize Of
    1 : WriteLn('    MOV  [' + VarName + '], AL');
    2 : WriteLn('    MOV  [' + VarName + '], AX');
    4 : WriteLn('    MOV  [' + VarName + '], EAX');
  Else
    WriteLn('    MOV  [' + VarName + '], EAX');
  End;
End;

{ ------------------------------------------------------------ }
{ GenLoadPacked : charger une variable COMP-3 (packed decimal) }
{   dans EAX en decompactant les chiffres BCD                 }
{   Format BCD condense : chaque octet contient 2 chiffres     }
{   Le dernier demi-octet (nibble bas) = signe (C=+, D=-)     }
{ ------------------------------------------------------------ }

Procedure GenLoadPacked(VarName : TString; VarSize : Integer);
Var
  LblLoop, LblSign : TString;
Begin
  AgnPackedOps := AgnPackedOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  LblLoop := GenArithLabel;
  LblSign := GenArithLabel;
  WriteLn('    ; Decompactage BCD ' + VarName + ' -> EAX');
  WriteLn('    XOR  EAX, EAX');
  WriteLn('    LEA  ESI, [' + VarName + ']');
  WriteLn('    MOV  ECX, ' + ItoS(VarSize));
  WriteLn(LblLoop + '_BCD:');
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    MOV  DL, [ESI]');
  { Demi-octet haut = premier chiffre }
  WriteLn('    MOV  EBX, EDX');
  WriteLn('    SHR  EBX, 4');
  WriteLn('    IMUL EAX, EAX, 10');
  WriteLn('    ADD  EAX, EBX');
  { Si dernier octet, demi-octet bas = signe }
  WriteLn('    DEC  ECX');
  WriteLn('    JZ   ' + LblSign + '_SGN');
  { Demi-octet bas = deuxieme chiffre }
  WriteLn('    AND  EDX, 0Fh');
  WriteLn('    IMUL EAX, EAX, 10');
  WriteLn('    ADD  EAX, EDX');
  WriteLn('    INC  ESI');
  WriteLn('    JMP  ' + LblLoop + '_BCD');
  WriteLn(LblSign + '_SGN:');
  WriteLn('    AND  EDX, 0Fh');
  WriteLn('    CMP  DL, 0Dh');
  WriteLn('    JNE  ' + LblSign + '_END');
  WriteLn('    NEG  EAX');
  WriteLn(LblSign + '_END:');
End;

{ ------------------------------------------------------------ }
{ GenStorePacked : stocker EAX dans une variable COMP-3        }
{   en recompactant le binaire en BCD condense                 }
{ ------------------------------------------------------------ }

Procedure GenStorePacked(VarName : TString; VarSize : Integer);
Var
  LblSgn, LblLoop : TString;
Begin
  AgnPackedOps := AgnPackedOps + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  LblSgn  := GenArithLabel;
  LblLoop := GenArithLabel;
  WriteLn('    ; Recompactage EAX -> BCD ' + VarName);
  WriteLn('    MOV  BL, 0Ch');
  WriteLn('    TEST EAX, EAX');
  WriteLn('    JNS  ' + LblSgn + '_PS');
  WriteLn('    MOV  BL, 0Dh');
  WriteLn('    NEG  EAX');
  WriteLn(LblSgn + '_PS:');
  WriteLn('    LEA  EDI, [' + VarName + '+' +
          ItoS(VarSize - 1) + ']');
  WriteLn('    MOV  ECX, ' + ItoS(VarSize));
  { Dernier octet : chiffre haut + signe bas }
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    MOV  ESI, 10');
  WriteLn('    DIV  ESI');
  WriteLn('    SHL  DL, 4');
  WriteLn('    OR   DL, BL');
  WriteLn('    MOV  [EDI], DL');
  WriteLn('    DEC  EDI');
  WriteLn('    DEC  ECX');
  WriteLn('    JZ   ' + LblLoop + '_DONE');
  { Octets precedents : 2 chiffres par octet }
  WriteLn(LblLoop + '_PCK:');
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    DIV  ESI');
  WriteLn('    MOV  BH, DL');
  WriteLn('    XOR  EDX, EDX');
  WriteLn('    DIV  ESI');
  WriteLn('    SHL  DL, 4');
  WriteLn('    OR   DL, BH');
  WriteLn('    MOV  [EDI], DL');
  WriteLn('    DEC  EDI');
  WriteLn('    DEC  ECX');
  WriteLn('    JNZ  ' + LblLoop + '_PCK');
  WriteLn(LblLoop + '_DONE:');
End;

{ ------------------------------------------------------------ }
{ GenArithOp : generer l operation arithmetique en registre     }
{   EAX = EAX op EBX (resultat dans EAX)                      }
{ ------------------------------------------------------------ }

Procedure GenArithOp(Op : Integer);
Var
  LblPow, LblEnd : TString;
Begin
  AgnTotalGenerated := AgnTotalGenerated + 1;
  WriteLn('    ; Operation ' + ArithOpName(Op));
  Case Op Of
    AOP_ADD : Begin
      WriteLn('    ADD  EAX, EBX');
    End;
    AOP_SUB : Begin
      WriteLn('    SUB  EAX, EBX');
    End;
    AOP_MUL : Begin
      WriteLn('    IMUL EAX, EBX');
    End;
    AOP_DIV : Begin
      WriteLn('    CDQ');
      WriteLn('    IDIV EBX');
    End;
    AOP_POWER : Begin
      LblPow := GenArithLabel;
      LblEnd := GenArithLabel;
      WriteLn('    MOV  ECX, EBX');
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    MOV  EAX, 1');
      WriteLn('    TEST ECX, ECX');
      WriteLn('    JZ   ' + LblEnd);
      WriteLn(LblPow + ':');
      WriteLn('    IMUL EAX, EBX');
      WriteLn('    DEC  ECX');
      WriteLn('    JNZ  ' + LblPow);
      WriteLn(LblEnd + ':');
    End;
    AOP_NEGATE : Begin
      WriteLn('    NEG  EAX');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenRoundResult : generer le code d arrondi si ROUNDED actif  }
{   Arrondi au plus proche : si reste >= 5, ajouter 1          }
{   Decimals = nombre de decimales dans la PIC source          }
{ ------------------------------------------------------------ }

Procedure GenRoundResult(Decimals : Integer);
Var
  LblNoRound : TString;
Begin
  If Decimals <= 0 Then Exit;
  AgnRoundedCount := AgnRoundedCount + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  LblNoRound := GenArithLabel;
  WriteLn('    ; Arrondi ROUNDED (' + ItoS(Decimals) + ' dec)');
  WriteLn('    MOV  EBX, EAX');
  WriteLn('    CDQ');
  WriteLn('    MOV  ECX, 10');
  WriteLn('    IDIV ECX');
  WriteLn('    CMP  EDX, 5');
  WriteLn('    JL   ' + LblNoRound);
  WriteLn('    INC  EAX');
  WriteLn(LblNoRound + ':');
End;

{ ------------------------------------------------------------ }
{ GenSizeCheck : generer la verification de debordement         }
{   ON SIZE ERROR / NOT ON SIZE ERROR                          }
{   MaxVal = valeur maximale que la variable cible peut contenir}
{ ------------------------------------------------------------ }

Procedure GenSizeCheck(LblSizeErr, LblNoSizeErr : TString;
                       MaxVal : LongInt);
Begin
  AgnSizeErrCount := AgnSizeErrCount + 1;
  AgnTotalGenerated := AgnTotalGenerated + 1;
  WriteLn('    ; Verification ON SIZE ERROR (max=' +
          ItoS(MaxVal) + ')');
  WriteLn('    CMP  EAX, ' + ItoS(MaxVal));
  WriteLn('    JG   ' + LblSizeErr);
  WriteLn('    CMP  EAX, -' + ItoS(MaxVal));
  WriteLn('    JL   ' + LblSizeErr);
  WriteLn('    JMP  ' + LblNoSizeErr);
  WriteLn(LblSizeErr + ':');
End;

{ ------------------------------------------------------------ }
{ GenExprEvalNode : generer le code pour evaluer un noeud de   }
{   l arbre d expression arithmetique sur la pile 80386        }
{   Utilise les noeuds de ExprNodes (TODO 08)                  }
{   Le resultat est dans EAX                                   }
{ ------------------------------------------------------------ }

Procedure GenExprEvalNode(NodeIdx : Integer);
Var
  NT : Integer;
Begin
  If (NodeIdx < 0) Or (NodeIdx >= ExprNodeCount) Then Begin
    WriteLn('    ; Noeud invalide ' + ItoS(NodeIdx));
    WriteLn('    XOR  EAX, EAX');
    Exit;
  End;
  NT := ExprNodes[NodeIdx].NodeType;
  Case NT Of
    EXP_INTEGER_LIT : Begin
      WriteLn('    MOV  EAX, ' +
              ItoS(ExprNodes[NodeIdx].IntVal));
    End;
    EXP_DECIMAL_LIT : Begin
      { Conversion approchee en entier pour evaluation simple }
      WriteLn('    ; Litteral decimal (approche entiere)');
      WriteLn('    MOV  EAX, ' +
              ItoS(Round(ExprNodes[NodeIdx].RealVal)));
    End;
    EXP_IDENTIFIER : Begin
      WriteLn('    ; Charger ' + ExprNodes[NodeIdx].StrVal);
      WriteLn('    MOV  EAX, [' +
              AsmIdent(ExprNodes[NodeIdx].StrVal) + ']');
    End;
    EXP_QUALIFIED : Begin
      WriteLn('    ; Charger ' + ExprNodes[NodeIdx].StrVal +
              ' OF ' + ExprNodes[NodeIdx].QualGroup);
      WriteLn('    MOV  EAX, [' +
              AsmIdent(ExprNodes[NodeIdx].StrVal) + ']');
    End;
    EXP_FIGURATIVE : Begin
      WriteLn('    ; Constante figurative ' +
              ExprNodes[NodeIdx].StrVal);
      WriteLn('    XOR  EAX, EAX');
    End;
    EXP_STRING_LIT : Begin
      WriteLn('    ; Litteral chaine (non arithmetique)');
      WriteLn('    XOR  EAX, EAX');
    End;
    EXP_ADD : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      WriteLn('    PUSH EAX');
      GenExprEvalNode(ExprNodes[NodeIdx].RightIdx);
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    POP  EAX');
      GenArithOp(AOP_ADD);
    End;
    EXP_SUB : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      WriteLn('    PUSH EAX');
      GenExprEvalNode(ExprNodes[NodeIdx].RightIdx);
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    POP  EAX');
      GenArithOp(AOP_SUB);
    End;
    EXP_MUL : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      WriteLn('    PUSH EAX');
      GenExprEvalNode(ExprNodes[NodeIdx].RightIdx);
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    POP  EAX');
      GenArithOp(AOP_MUL);
    End;
    EXP_DIV : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      WriteLn('    PUSH EAX');
      GenExprEvalNode(ExprNodes[NodeIdx].RightIdx);
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    POP  EAX');
      GenArithOp(AOP_DIV);
    End;
    EXP_POWER : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      WriteLn('    PUSH EAX');
      GenExprEvalNode(ExprNodes[NodeIdx].RightIdx);
      WriteLn('    MOV  EBX, EAX');
      WriteLn('    POP  EAX');
      GenArithOp(AOP_POWER);
    End;
    EXP_NEGATE : Begin
      GenExprEvalNode(ExprNodes[NodeIdx].LeftIdx);
      GenArithOp(AOP_NEGATE);
    End;
    EXP_SUBSCRIPT : Begin
      WriteLn('    ; Acces indexe ' + ExprNodes[NodeIdx].StrVal);
      WriteLn('    MOV  EAX, [' +
              AsmIdent(ExprNodes[NodeIdx].StrVal) + ']');
    End;
    EXP_SUBSTRING : Begin
      WriteLn('    ; Sous-chaine ' + ExprNodes[NodeIdx].StrVal);
      WriteLn('    MOV  EAX, [' +
              AsmIdent(ExprNodes[NodeIdx].StrVal) + ']');
    End;
  Else
    WriteLn('    ; Noeud type inconnu ' + ItoS(NT));
    WriteLn('    XOR  EAX, EAX');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAddStatement : parser et generer le code pour ADD       }
{   ADD id-1 [id-2 ...] TO id-n [GIVING id-m]                 }
{   [ROUNDED] [ON SIZE ERROR stmt] [NOT ON SIZE ERROR stmt]    }
{   [END-ADD]                                                   }
{ ------------------------------------------------------------ }

Procedure ParseAddStatement;
Var
  Operands     : Array[1..8] Of TString;
  OpCount      : Integer;
  TargetVar    : TString;
  GivingVar    : TString;
  HasGiving    : Boolean;
  HasRounded   : Boolean;
  I            : Integer;
Begin
  AgnAddCount := AgnAddCount + 1;
  OpCount := 0;
  HasGiving := False;
  HasRounded := False;
  GivingVar := '';
  { Collecter les operandes avant TO }
  While (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Or
        (CurTokType = TOK_DECIMAL) Do Begin
    If OpCount < AGN_MAX_ARGS Then Begin
      OpCount := OpCount + 1;
      Operands[OpCount] := CurTokStr;
    End;
    LexNextToken;
  End;
  { Attendre TO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken;
  { Variable cible }
  If CurTokType = TOK_IDENT Then Begin
    TargetVar := CurTokStr;
    LexNextToken;
  End Else
    TargetVar := '';
  { Clause GIVING optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GIVING) Then Begin
    LexNextToken;
    HasGiving := True;
    If CurTokType = TOK_IDENT Then Begin
      GivingVar := CurTokStr;
      LexNextToken;
    End;
  End;
  { Clause ROUNDED optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ROUNDED) Then Begin
    HasRounded := True;
    LexNextToken;
  End;
  { ON SIZE ERROR optionnelle - sauter les mots-cles }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    { Sauter ERROR (identificateur, pas un mot-cle) }
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    { Sauter le corps de l instruction SIZE ERROR }
    SkipToNextSentence;
  End;
  { NOT ON SIZE ERROR optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  { END-ADD optionnel }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_ADD) Then
    LexNextToken;
  { Generation du code assembleur }
  WriteLn('    ; === ADD statement ===');
  { Charger le premier operande }
  If OpCount >= 1 Then Begin
    WriteLn('    MOV  EAX, [' + AsmIdent(Operands[1]) + ']');
  End;
  { Additionner les operandes suivants }
  For I := 2 To OpCount Do Begin
    WriteLn('    ADD  EAX, [' + AsmIdent(Operands[I]) + ']');
  End;
  { Additionner la variable cible (ADD x TO y = y + x) }
  If TargetVar <> '' Then Begin
    WriteLn('    ADD  EAX, [' + AsmIdent(TargetVar) + ']');
  End;
  If HasRounded Then
    GenRoundResult(1);
  { Stocker le resultat }
  If HasGiving And (GivingVar <> '') Then Begin
    WriteLn('    MOV  [' + AsmIdent(GivingVar) + '], EAX');
  End Else If TargetVar <> '' Then Begin
    WriteLn('    MOV  [' + AsmIdent(TargetVar) + '], EAX');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSubtractStatement : parser et generer SUBTRACT          }
{   SUBTRACT id-1 [id-2 ...] FROM id-n [GIVING id-m]          }
{   [ROUNDED] [ON SIZE ERROR ...] [END-SUBTRACT]               }
{ ------------------------------------------------------------ }

Procedure ParseSubtractStatement;
Var
  Operands     : Array[1..8] Of TString;
  OpCount      : Integer;
  TargetVar    : TString;
  GivingVar    : TString;
  HasGiving    : Boolean;
  HasRounded   : Boolean;
  I            : Integer;
Begin
  AgnSubtractCount := AgnSubtractCount + 1;
  OpCount := 0;
  HasGiving := False;
  HasRounded := False;
  GivingVar := '';
  { Collecter les operandes avant FROM }
  While (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Or
        (CurTokType = TOK_DECIMAL) Do Begin
    If OpCount < AGN_MAX_ARGS Then Begin
      OpCount := OpCount + 1;
      Operands[OpCount] := CurTokStr;
    End;
    LexNextToken;
  End;
  { Attendre FROM }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FROM) Then
    LexNextToken;
  { Variable cible }
  If CurTokType = TOK_IDENT Then Begin
    TargetVar := CurTokStr;
    LexNextToken;
  End Else
    TargetVar := '';
  { Clause GIVING optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GIVING) Then Begin
    LexNextToken;
    HasGiving := True;
    If CurTokType = TOK_IDENT Then Begin
      GivingVar := CurTokStr;
      LexNextToken;
    End;
  End;
  { Clause ROUNDED optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ROUNDED) Then Begin
    HasRounded := True;
    LexNextToken;
  End;
  { ON SIZE ERROR / NOT ON SIZE ERROR - sauter }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  { END-SUBTRACT optionnel }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_END_SUBTRACT) Then
    LexNextToken;
  { Generation du code assembleur }
  WriteLn('    ; === SUBTRACT statement ===');
  { Charger la variable cible }
  If TargetVar <> '' Then
    WriteLn('    MOV  EAX, [' + AsmIdent(TargetVar) + ']');
  { Soustraire chaque operande }
  For I := 1 To OpCount Do Begin
    WriteLn('    SUB  EAX, [' + AsmIdent(Operands[I]) + ']');
  End;
  If HasRounded Then
    GenRoundResult(1);
  { Stocker le resultat }
  If HasGiving And (GivingVar <> '') Then Begin
    WriteLn('    MOV  [' + AsmIdent(GivingVar) + '], EAX');
  End Else If TargetVar <> '' Then Begin
    WriteLn('    MOV  [' + AsmIdent(TargetVar) + '], EAX');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseMultiplyStatement : parser et generer MULTIPLY          }
{   MULTIPLY id-1 BY id-2 [GIVING id-3]                       }
{   [ROUNDED] [ON SIZE ERROR ...] [END-MULTIPLY]               }
{ ------------------------------------------------------------ }

Procedure ParseMultiplyStatement;
Var
  Operand1     : TString;
  Operand2     : TString;
  GivingVar    : TString;
  HasGiving    : Boolean;
  HasRounded   : Boolean;
Begin
  AgnMultiplyCount := AgnMultiplyCount + 1;
  HasGiving := False;
  HasRounded := False;
  GivingVar := '';
  { Premier operande }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Then Begin
    Operand1 := CurTokStr;
    LexNextToken;
  End Else
    Operand1 := '';
  { Attendre BY }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
    LexNextToken;
  { Deuxieme operande }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Then Begin
    Operand2 := CurTokStr;
    LexNextToken;
  End Else
    Operand2 := '';
  { Clause GIVING optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GIVING) Then Begin
    LexNextToken;
    HasGiving := True;
    If CurTokType = TOK_IDENT Then Begin
      GivingVar := CurTokStr;
      LexNextToken;
    End;
  End;
  { Clause ROUNDED optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ROUNDED) Then Begin
    HasRounded := True;
    LexNextToken;
  End;
  { ON SIZE ERROR / NOT ON SIZE ERROR }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  { END-MULTIPLY optionnel }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_END_MULTIPLY) Then
    LexNextToken;
  { Generation du code assembleur }
  WriteLn('    ; === MULTIPLY statement ===');
  WriteLn('    MOV  EAX, [' + AsmIdent(Operand1) + ']');
  WriteLn('    MOV  EBX, [' + AsmIdent(Operand2) + ']');
  GenArithOp(AOP_MUL);
  If HasRounded Then
    GenRoundResult(1);
  If HasGiving And (GivingVar <> '') Then
    WriteLn('    MOV  [' + AsmIdent(GivingVar) + '], EAX')
  Else If Operand2 <> '' Then
    WriteLn('    MOV  [' + AsmIdent(Operand2) + '], EAX');
End;

{ ------------------------------------------------------------ }
{ ParseDivideStatement : parser et generer DIVIDE              }
{   DIVIDE id-1 INTO id-2 [GIVING id-3] [REMAINDER id-4]      }
{   DIVIDE id-1 BY id-2 [GIVING id-3] [REMAINDER id-4]        }
{   [ROUNDED] [ON SIZE ERROR ...] [END-DIVIDE]                 }
{ ------------------------------------------------------------ }

Procedure ParseDivideStatement;
Var
  Operand1     : TString;
  Operand2     : TString;
  GivingVar    : TString;
  RemainderVar : TString;
  HasGiving    : Boolean;
  HasRemainder : Boolean;
  HasRounded   : Boolean;
  UseInto      : Boolean;
Begin
  AgnDivideCount := AgnDivideCount + 1;
  HasGiving    := False;
  HasRemainder := False;
  HasRounded   := False;
  UseInto      := False;
  GivingVar    := '';
  RemainderVar := '';
  { Premier operande }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Then Begin
    Operand1 := CurTokStr;
    LexNextToken;
  End Else
    Operand1 := '';
  { INTO ou BY }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then Begin
    UseInto := True;
    LexNextToken;
  End Else If (CurTokType = TOK_KEYWORD) And
              (CurTokNum = KW_BY) Then Begin
    UseInto := False;
    LexNextToken;
  End;
  { Deuxieme operande }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_INTEGER) Then Begin
    Operand2 := CurTokStr;
    LexNextToken;
  End Else
    Operand2 := '';
  { Clause GIVING optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GIVING) Then Begin
    LexNextToken;
    HasGiving := True;
    If CurTokType = TOK_IDENT Then Begin
      GivingVar := CurTokStr;
      LexNextToken;
    End;
  End;
  { Clause REMAINDER optionnelle }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_REMAINDER) Then Begin
    LexNextToken;
    HasRemainder := True;
    If CurTokType = TOK_IDENT Then Begin
      RemainderVar := CurTokStr;
      LexNextToken;
    End;
  End;
  { Clause ROUNDED optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ROUNDED) Then Begin
    HasRounded := True;
    LexNextToken;
  End;
  { ON SIZE ERROR / NOT ON SIZE ERROR }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  { END-DIVIDE optionnel }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_END_DIVIDE) Then
    LexNextToken;
  { Generation du code assembleur }
  WriteLn('    ; === DIVIDE statement ===');
  If UseInto Then Begin
    { DIVIDE X INTO Y  =>  Y = Y / X }
    WriteLn('    MOV  EAX, [' + AsmIdent(Operand2) + ']');
    WriteLn('    MOV  EBX, [' + AsmIdent(Operand1) + ']');
  End Else Begin
    { DIVIDE X BY Y  =>  X / Y }
    WriteLn('    MOV  EAX, [' + AsmIdent(Operand1) + ']');
    WriteLn('    MOV  EBX, [' + AsmIdent(Operand2) + ']');
  End;
  GenArithOp(AOP_DIV);
  If HasRemainder And (RemainderVar <> '') Then Begin
    WriteLn('    MOV  [' + AsmIdent(RemainderVar) + '], EDX');
  End;
  If HasRounded Then
    GenRoundResult(1);
  If HasGiving And (GivingVar <> '') Then
    WriteLn('    MOV  [' + AsmIdent(GivingVar) + '], EAX')
  Else If UseInto And (Operand2 <> '') Then
    WriteLn('    MOV  [' + AsmIdent(Operand2) + '], EAX')
  Else If (Not UseInto) And (Operand1 <> '') Then
    WriteLn('    MOV  [' + AsmIdent(Operand1) + '], EAX');
End;

{ ------------------------------------------------------------ }
{ ParseComputeStatement : parser et generer COMPUTE            }
{   COMPUTE id-1 [ROUNDED] = expression arithmetique           }
{   Parsing complet de l expression avec priorite              }
{   Evaluation sur la pile 80386                               }
{   [ON SIZE ERROR ...] [END-COMPUTE]                          }
{ ------------------------------------------------------------ }

Procedure ParseComputeStatement;
Var
  TargetVar  : TString;
  HasRounded : Boolean;
  RootIdx    : Integer;
Begin
  AgnComputeCount := AgnComputeCount + 1;
  HasRounded := False;
  { Variable cible }
  If CurTokType = TOK_IDENT Then Begin
    TargetVar := CurTokStr;
    LexNextToken;
  End Else
    TargetVar := '';
  { Clause ROUNDED avant le = }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ROUNDED) Then Begin
    HasRounded := True;
    LexNextToken;
  End;
  { Attendre le signe = }
  If CurTokType = TOK_EQ Then
    LexNextToken;
  { Parser l expression arithmetique complete via TODO 08 }
  RootIdx := ParseExpression;
  { ON SIZE ERROR / NOT ON SIZE ERROR }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) And (CurTokStr = 'ERROR') Then
      LexNextToken;
    SkipToNextSentence;
  End;
  { END-COMPUTE optionnel }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_END_COMPUTE) Then
    LexNextToken;
  { Generation du code assembleur }
  WriteLn('    ; === COMPUTE ' + TargetVar + ' ===');
  { Evaluer l expression sur la pile 80386 }
  GenExprEvalNode(RootIdx);
  If HasRounded Then
    GenRoundResult(1);
  { Stocker le resultat }
  If TargetVar <> '' Then
    WriteLn('    MOV  [' + AsmIdent(TargetVar) + '], EAX');
End;

{ ------------------------------------------------------------ }
{ ParseArithmeticStatement : dispatcher pour les instructions  }
{   arithmetiques COBOL (ADD, SUBTRACT, MULTIPLY, DIVIDE,     }
{   COMPUTE)                                                    }
{   Appele quand le token courant est un verbe arithmetique    }
{ ------------------------------------------------------------ }

Procedure ParseArithmeticStatement;
Var
  SaveKW : Integer;
Begin
  If CurTokType <> TOK_KEYWORD Then Exit;
  SaveKW := CurTokNum;
  LexNextToken;
  Case SaveKW Of
    KW_ADD      : ParseAddStatement;
    KW_SUBTRACT : ParseSubtractStatement;
    KW_MULTIPLY : ParseMultiplyStatement;
    KW_DIVIDE   : ParseDivideStatement;
    KW_COMPUTE  : ParseComputeStatement;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpArithGenState : afficher l etat du module de generation  }
{   arithmetique (compteurs et statistiques)                   }
{ ------------------------------------------------------------ }

Procedure DumpArithGenState;
Begin
  WriteLn('=== Generation arithmetique 80386 ===');
  WriteLn('  Initialise          : ',
          AgnInitialized);
  WriteLn('  Labels generes      : ', AgnLabelNum);
  WriteLn('  Instructions ADD    : ', AgnAddCount);
  WriteLn('  Instructions SUB    : ', AgnSubtractCount);
  WriteLn('  Instructions MUL    : ', AgnMultiplyCount);
  WriteLn('  Instructions DIV    : ', AgnDivideCount);
  WriteLn('  Instructions COMPUTE: ', AgnComputeCount);
  WriteLn('  Clauses ROUNDED     : ', AgnRoundedCount);
  WriteLn('  Clauses SIZE ERROR  : ', AgnSizeErrCount);
  WriteLn('  Operations DISPLAY  : ', AgnDisplayOps);
  WriteLn('  Operations COMP     : ', AgnCompOps);
  WriteLn('  Operations PACKED   : ', AgnPackedOps);
  WriteLn('  Total genere        : ', AgnTotalGenerated);
End;

{ 10 fonctions accesseurs pour TODO 09                         }

Function IsAgnInitialized : Boolean;
Begin
  IsAgnInitialized := AgnInitialized;
End;

Function IsAgnEmpty : Boolean;
Begin
  IsAgnEmpty := (AgnTotalGenerated = 0);
End;

Function GetAgnTotalGenerated : Integer;
Begin
  GetAgnTotalGenerated := AgnTotalGenerated;
End;

Function GetAgnStatus : TString;
Begin
  If Not AgnInitialized Then
    GetAgnStatus := 'NON INITIALISE'
  Else
    GetAgnStatus := 'ADD=' + ItoSI(AgnAddCount) +
                    ' SUB=' + ItoSI(AgnSubtractCount) +
                    ' MUL=' + ItoSI(AgnMultiplyCount) +
                    ' DIV=' + ItoSI(AgnDivideCount) +
                    ' CMP=' + ItoSI(AgnComputeCount);
End;

Function GetAgnAddCount : Integer;
Begin
  GetAgnAddCount := AgnAddCount;
End;

Function GetAgnSubtractCount : Integer;
Begin
  GetAgnSubtractCount := AgnSubtractCount;
End;

Function GetAgnMultiplyCount : Integer;
Begin
  GetAgnMultiplyCount := AgnMultiplyCount;
End;

Function GetAgnDivideCount : Integer;
Begin
  GetAgnDivideCount := AgnDivideCount;
End;

Function GetAgnComputeCount : Integer;
Begin
  GetAgnComputeCount := AgnComputeCount;
End;

Function GetAgnStateCount : Integer;
Begin
  GetAgnStateCount := AgnStateCount;
End;


{ ============================================================ }
{ TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, EVALUATE)    }
{           Generation de code conditionnel 80386               }
{ ============================================================ }

Const
  { Profondeurs maximales d imbrication }
  CTL_MAX_IF_DEPTH   = 64;   { imbrication max de IF                    }
  CTL_MAX_EVAL_DEPTH = 32;   { imbrication max de EVALUATE              }
  CTL_MAX_WHEN       = 64;   { max de clauses WHEN par EVALUATE         }
  CTL_MAX_ALSO       = 8;    { max de sujets ALSO dans EVALUATE         }

  { Types de structures de controle }
  CTL_NONE           = 0;    { pas de structure active                  }
  CTL_IF             = 1;    { bloc IF                                  }
  CTL_EVALUATE       = 2;    { bloc EVALUATE                            }
  CTL_CONTINUE       = 3;    { instruction CONTINUE (no-op)             }

  { Types de sujets EVALUATE }
  EVS_IDENT          = 0;    { EVALUATE identifiant                     }
  EVS_EXPR           = 1;    { EVALUATE expression                      }
  EVS_TRUE           = 2;    { EVALUATE TRUE                            }
  EVS_FALSE          = 3;    { EVALUATE FALSE                           }

  { Types de clauses WHEN }
  EWH_VALUE          = 0;    { WHEN valeur (litterale ou ident)         }
  EWH_CONDITION      = 1;    { WHEN condition (pour EVALUATE TRUE)      }
  EWH_OTHER          = 2;    { WHEN OTHER                               }
  EWH_RANGE          = 3;    { WHEN val-1 THRU val-2                    }
  EWH_ANY            = 4;    { WHEN ANY                                 }

  { Nombre de types }
  CTL_NUM_STRUCT_TYPES  = 4;
  CTL_NUM_SUBJECT_TYPES = 4;
  CTL_NUM_WHEN_TYPES    = 5;

Var
  { Etat du module }
  CtlInitialized   : Boolean;
  CtlStateCount    : Integer;

  { Compteur de labels internes }
  CtlLabelNum      : Integer;

  { Compteurs de structures }
  CtlIfCount       : Integer;
  CtlElseCount     : Integer;
  CtlEndIfCount    : Integer;
  CtlEvalCount     : Integer;
  CtlWhenCount     : Integer;
  CtlWhenOtherCount: Integer;
  CtlEndEvalCount  : Integer;
  CtlContinueCount : Integer;

  { Profondeur courante }
  CtlIfDepth       : Integer;
  CtlEvalDepth     : Integer;
  CtlMaxIfDepth    : Integer;
  CtlMaxEvalDepth  : Integer;

  { Statistiques }
  CtlNestedIfCount : Integer;
  CtlCombinedConds : Integer;
  CtlOldFormCount  : Integer;
  CtlAlsoCount     : Integer;
  CtlTotalGenerated: Integer;

{ ------------------------------------------------------------ }
{ InitControlState : initialisation du module de structures    }
{   de controle (IF, EVALUATE, CONTINUE)                       }
{ ------------------------------------------------------------ }

Procedure InitControlState;
Begin
  CtlInitialized   := True;
  CtlStateCount    := CtlStateCount + 1;
  CtlLabelNum      := 0;
  CtlIfCount       := 0;
  CtlElseCount     := 0;
  CtlEndIfCount    := 0;
  CtlEvalCount     := 0;
  CtlWhenCount     := 0;
  CtlWhenOtherCount:= 0;
  CtlEndEvalCount  := 0;
  CtlContinueCount := 0;
  CtlIfDepth       := 0;
  CtlEvalDepth     := 0;
  CtlMaxIfDepth    := 0;
  CtlMaxEvalDepth  := 0;
  CtlNestedIfCount := 0;
  CtlCombinedConds := 0;
  CtlOldFormCount  := 0;
  CtlAlsoCount     := 0;
  CtlTotalGenerated:= 0;
End;

{ ------------------------------------------------------------ }
{ GenCtlLabel : generer un label unique pour les structures     }
{   de controle (IF, EVALUATE)                                 }
{ ------------------------------------------------------------ }

Function GenCtlLabel : TString;
Begin
  CtlLabelNum := CtlLabelNum + 1;
  GenCtlLabel := PFX_LBL + 'CTL_' + ItoSI(CtlLabelNum);
End;

{ ------------------------------------------------------------ }
{ CtlStructTypeName : nom textuel d un type de structure       }
{ ------------------------------------------------------------ }

Function CtlStructTypeName(T : Integer) : TString;
Begin
  Case T Of
    CTL_NONE     : CtlStructTypeName := 'NONE';
    CTL_IF       : CtlStructTypeName := 'IF';
    CTL_EVALUATE : CtlStructTypeName := 'EVALUATE';
    CTL_CONTINUE : CtlStructTypeName := 'CONTINUE';
  Else
    CtlStructTypeName := 'UNKNOWN(' + ItoSI(T) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ EvalSubjectName : nom textuel d un type de sujet EVALUATE    }
{ ------------------------------------------------------------ }

Function EvalSubjectName(S : Integer) : TString;
Begin
  Case S Of
    EVS_IDENT : EvalSubjectName := 'IDENT';
    EVS_EXPR  : EvalSubjectName := 'EXPR';
    EVS_TRUE  : EvalSubjectName := 'TRUE';
    EVS_FALSE : EvalSubjectName := 'FALSE';
  Else
    EvalSubjectName := 'UNKNOWN(' + ItoSI(S) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ WhenTypeName : nom textuel d un type de clause WHEN          }
{ ------------------------------------------------------------ }

Function WhenTypeName(W : Integer) : TString;
Begin
  Case W Of
    EWH_VALUE     : WhenTypeName := 'VALUE';
    EWH_CONDITION : WhenTypeName := 'CONDITION';
    EWH_OTHER     : WhenTypeName := 'OTHER';
    EWH_RANGE     : WhenTypeName := 'RANGE';
    EWH_ANY       : WhenTypeName := 'ANY';
  Else
    WhenTypeName := 'UNKNOWN(' + ItoSI(W) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ GenCondJump : generer un saut conditionnel 80386              }
{   basee sur l operateur relationnel, vers un label cible     }
{   RelOp : REL_EQ..REL_GE, Negate inverse la condition       }
{   Genere : CMP + Jcc conditionnel                            }
{ ------------------------------------------------------------ }

Procedure GenCondJump(RelOp : Integer; Negate : Boolean;
                      TargetLabel : TString);
Var
  JmpInstr : TString;
Begin
  { Choisir l instruction de saut selon l operateur }
  Case RelOp Of
    REL_EQ : If Negate Then JmpInstr := 'JNE' Else JmpInstr := 'JE';
    REL_NE : If Negate Then JmpInstr := 'JE'  Else JmpInstr := 'JNE';
    REL_LT : If Negate Then JmpInstr := 'JGE' Else JmpInstr := 'JL';
    REL_GT : If Negate Then JmpInstr := 'JLE' Else JmpInstr := 'JG';
    REL_LE : If Negate Then JmpInstr := 'JG'  Else JmpInstr := 'JLE';
    REL_GE : If Negate Then JmpInstr := 'JL'  Else JmpInstr := 'JGE';
  Else
    JmpInstr := 'JMP';
  End;
  WriteLn('    ', JmpInstr, ' ', TargetLabel);
  CtlTotalGenerated := CtlTotalGenerated + 1;
End;

{ ------------------------------------------------------------ }
{ GenUnconditionalJump : generer un saut inconditionnel JMP    }
{ ------------------------------------------------------------ }

Procedure GenUnconditionalJump(TargetLabel : TString);
Begin
  WriteLn('    JMP ', TargetLabel);
  CtlTotalGenerated := CtlTotalGenerated + 1;
End;

{ ------------------------------------------------------------ }
{ GenLabel : emettre un label dans le flux de sortie           }
{ ------------------------------------------------------------ }

Procedure GenCtlLabelEmit(LblName : TString);
Begin
  WriteLn(LblName, ':');
  CtlTotalGenerated := CtlTotalGenerated + 1;
End;

{ ------------------------------------------------------------ }
{ GenCondEvalFromRelOp : generer le code CMP + Jcc pour un     }
{   operateur relationnel donne (condition simple)             }
{ ------------------------------------------------------------ }

Procedure GenCondEvalFromRelOp(RelOp : Integer; Negate : Boolean;
                                FalseLabel : TString);
Begin
  { La comparaison CMP a ete effectuee avant l appel }
  GenCondJump(RelOp, Not Negate, FalseLabel);
End;

{ ------------------------------------------------------------ }
{ GenClassCondCheck : generer le code pour une condition de     }
{   classe (NUMERIC, ALPHABETIC, etc.)                         }
{ ------------------------------------------------------------ }

Procedure GenClassCondCheck(ClassType : Integer; Negate : Boolean;
                             FalseLabel : TString);
Begin
  { Generer un appel a la routine runtime de verification }
  Case ClassType Of
    CLS_NUMERIC :
      WriteLn('    CALL ', PFX_RT, 'IS_NUMERIC');
    CLS_ALPHABETIC :
      WriteLn('    CALL ', PFX_RT, 'IS_ALPHABETIC');
    CLS_ALPHA_LOWER :
      WriteLn('    CALL ', PFX_RT, 'IS_ALPHA_LOWER');
    CLS_ALPHA_UPPER :
      WriteLn('    CALL ', PFX_RT, 'IS_ALPHA_UPPER');
  End;
  WriteLn('    TEST EAX, EAX');
  If Negate Then
    WriteLn('    JNE ', FalseLabel)
  Else
    WriteLn('    JE ', FalseLabel);
  CtlTotalGenerated := CtlTotalGenerated + 3;
End;

{ ------------------------------------------------------------ }
{ GenSignCondCheck : generer le code pour une condition de      }
{   signe (POSITIVE, NEGATIVE, ZERO)                           }
{ ------------------------------------------------------------ }

Procedure GenSignCondCheck(SignType : Integer; Negate : Boolean;
                            FalseLabel : TString);
Begin
  { La valeur est dans EAX }
  WriteLn('    CMP EAX, 0');
  Case SignType Of
    SGN_POSITIVE :
      If Negate Then
        WriteLn('    JG ', FalseLabel)
      Else
        WriteLn('    JLE ', FalseLabel);
    SGN_NEGATIVE :
      If Negate Then
        WriteLn('    JL ', FalseLabel)
      Else
        WriteLn('    JGE ', FalseLabel);
    SGN_ZERO :
      If Negate Then
        WriteLn('    JE ', FalseLabel)
      Else
        WriteLn('    JNE ', FalseLabel);
  End;
  CtlTotalGenerated := CtlTotalGenerated + 2;
End;

{ ------------------------------------------------------------ }
{ GenConditionCode : generer le code 80386 pour une condition  }
{   COBOL complete (simple, combinee, ou negation)             }
{   FalseLabel : label ou sauter si la condition est fausse    }
{ ------------------------------------------------------------ }

Procedure GenConditionCode(CondIdx : Integer; FalseLabel : TString);
Var
  LblRight, LblEnd : TString;
Begin
  If (CondIdx < 0) Or (CondIdx >= CondNodeCount) Then Exit;

  Case CondNodes[CondIdx].CondType Of
    CND_RELATION :
    Begin
      { Charger operande gauche dans EAX }
      WriteLn('    ; condition relationnelle');
      WriteLn('    ; charger operande gauche');
      WriteLn('    ; charger operande droite dans EBX');
      WriteLn('    CMP EAX, EBX');
      GenCondEvalFromRelOp(CondNodes[CondIdx].RelOp,
        CondNodes[CondIdx].IsNegated, FalseLabel);
      CtlTotalGenerated := CtlTotalGenerated + 4;
    End;

    CND_CLASS :
    Begin
      WriteLn('    ; condition de classe');
      GenClassCondCheck(CondNodes[CondIdx].ClassType,
        CondNodes[CondIdx].IsNegated, FalseLabel);
    End;

    CND_SIGN :
    Begin
      WriteLn('    ; condition de signe');
      GenSignCondCheck(CondNodes[CondIdx].SignType,
        CondNodes[CondIdx].IsNegated, FalseLabel);
    End;

    CND_CONDITION_NAME :
    Begin
      WriteLn('    ; condition-name (niveau 88)');
      WriteLn('    ; charger valeur et comparer aux valeurs 88');
      If CondNodes[CondIdx].IsNegated Then
        WriteLn('    JE ', FalseLabel)
      Else
        WriteLn('    JNE ', FalseLabel);
      CtlTotalGenerated := CtlTotalGenerated + 3;
    End;

    CND_AND :
    Begin
      { AND : si gauche faux -> faux, sinon tester droite }
      WriteLn('    ; condition combinee AND');
      GenConditionCode(CondNodes[CondIdx].LeftCond, FalseLabel);
      GenConditionCode(CondNodes[CondIdx].RightCond, FalseLabel);
      CtlCombinedConds := CtlCombinedConds + 1;
    End;

    CND_OR :
    Begin
      { OR : si gauche vrai -> vrai, sinon tester droite }
      WriteLn('    ; condition combinee OR');
      LblRight := GenCtlLabel;
      LblEnd   := GenCtlLabel;
      { Inverser : si gauche vrai, sauter au code }
      GenConditionCode(CondNodes[CondIdx].LeftCond, LblRight);
      GenUnconditionalJump(LblEnd);
      GenCtlLabelEmit(LblRight);
      GenConditionCode(CondNodes[CondIdx].RightCond, FalseLabel);
      GenCtlLabelEmit(LblEnd);
      CtlCombinedConds := CtlCombinedConds + 1;
    End;

    CND_NOT :
    Begin
      WriteLn('    ; condition negation NOT');
      { Inverser : si la sous-condition est vraie, sauter au faux }
      LblEnd := GenCtlLabel;
      GenConditionCode(CondNodes[CondIdx].LeftCond, LblEnd);
      GenUnconditionalJump(FalseLabel);
      GenCtlLabelEmit(LblEnd);
    End;

    CND_TRUE :
    Begin
      { TRUE est toujours vrai, rien a generer }
      WriteLn('    ; condition TRUE (toujours vrai)');
      CtlTotalGenerated := CtlTotalGenerated + 1;
    End;

    CND_FALSE :
    Begin
      { FALSE est toujours faux, sauter directement }
      WriteLn('    ; condition FALSE (toujours faux)');
      GenUnconditionalJump(FalseLabel);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIfStatement : parser et generer le code pour IF         }
{   IF condition [THEN]                                        }
{     instructions...                                          }
{   [ELSE                                                      }
{     instructions...]                                         }
{   END-IF | .                                                  }
{   Supporte les IF imbriques et les conditions combinees      }
{ ------------------------------------------------------------ }

Procedure ParseIfStatement;
Var
  LblElse, LblEndIf : TString;
  HasElse           : Boolean;
  OldForm           : Boolean;
Begin
  CtlIfCount := CtlIfCount + 1;
  CtlIfDepth := CtlIfDepth + 1;
  If CtlIfDepth > CtlMaxIfDepth Then
    CtlMaxIfDepth := CtlIfDepth;
  If CtlIfDepth > 1 Then
    CtlNestedIfCount := CtlNestedIfCount + 1;

  If CtlIfDepth > CTL_MAX_IF_DEPTH Then
  Begin
    WarnMsg('IF imbrique trop profondement (max ' +
            ItoSI(CTL_MAX_IF_DEPTH) + ')');
    CtlIfDepth := CtlIfDepth - 1;
    Exit;
  End;

  { Generer les labels }
  LblElse  := GenCtlLabel;
  LblEndIf := GenCtlLabel;
  HasElse  := False;
  OldForm  := False;

  WriteLn('    ; IF debut (profondeur=', CtlIfDepth, ')');

  { Le token IF a deja ete consomme, on attend la condition }
  { Parser la condition (appel au parseur de conditions TODO 08) }
  { puis generer le code conditionnel }
  { Si la condition est fausse, sauter au ELSE ou au END-IF }

  { Accepter le THEN optionnel }
  If (CurTokType = TOK_KEYWORD) And
     (UpCaseStr(CurTokStr) = 'THEN') Then
    LexNextToken
  Else If (CurTokType = TOK_IDENT) And
          (UpCaseStr(CurTokStr) = 'THEN') Then
    LexNextToken;

  { A ce stade, la condition a ete evaluee dans le flag x86 }
  { Saut conditionnel vers le label ELSE/END-IF }
  WriteLn('    ; saut si condition fausse');
  WriteLn('    JE ', LblElse);
  CtlTotalGenerated := CtlTotalGenerated + 2;

  { Instructions du bloc THEN }
  WriteLn('    ; bloc THEN');

  { Verifier si on a un ELSE }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSE) Then
  Begin
    HasElse := True;
    CtlElseCount := CtlElseCount + 1;
    { Saut inconditionnel vers END-IF }
    GenUnconditionalJump(LblEndIf);
    GenCtlLabelEmit(LblElse);
    WriteLn('    ; bloc ELSE');
    LexNextToken;
    { Instructions du bloc ELSE }
  End;

  { Terminaison : END-IF ou point }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_IF) Then
  Begin
    CtlEndIfCount := CtlEndIfCount + 1;
    LexNextToken;
  End
  Else If CurTokType = TOK_DOT Then
  Begin
    { Forme ancienne avec point comme terminateur }
    OldForm := True;
    CtlOldFormCount := CtlOldFormCount + 1;
  End;

  { Emettre les labels de fin }
  If Not HasElse Then
    GenCtlLabelEmit(LblElse);
  GenCtlLabelEmit(LblEndIf);

  WriteLn('    ; IF fin (profondeur=', CtlIfDepth, ')');

  If OldForm Then
    WriteLn('    ; (forme ancienne avec point)');

  CtlIfDepth := CtlIfDepth - 1;
  CtlTotalGenerated := CtlTotalGenerated + 1;
End;

{ ------------------------------------------------------------ }
{ ParseEvaluateSubject : parser le sujet d un EVALUATE         }
{   Retourne le type de sujet (EVS_IDENT/EXPR/TRUE/FALSE)      }
{ ------------------------------------------------------------ }

Function ParseEvaluateSubject : Integer;
Begin
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRUE) Then
  Begin
    ParseEvaluateSubject := EVS_TRUE;
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FALSE) Then
  Begin
    ParseEvaluateSubject := EVS_FALSE;
    LexNextToken;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    ParseEvaluateSubject := EVS_IDENT;
    { L identifiant sera utilise pour les comparaisons WHEN }
    LexNextToken;
  End
  Else
  Begin
    { Expression arithmetique }
    ParseEvaluateSubject := EVS_EXPR;
    { L expression sera evaluee et le resultat en EAX }
  End;
End;

{ ------------------------------------------------------------ }
{ ParseWhenClause : parser une clause WHEN d un EVALUATE       }
{   Retourne le type de clause WHEN                            }
{ ------------------------------------------------------------ }

Function ParseWhenClause(SubjectType : Integer) : Integer;
Begin
  { Le token WHEN a deja ete consomme }
  If (CurTokType = TOK_KEYWORD) And
     (UpCaseStr(CurTokStr) = 'OTHER') Then
  Begin
    ParseWhenClause := EWH_OTHER;
    LexNextToken;
  End
  Else If (CurTokType = TOK_IDENT) And
          (UpCaseStr(CurTokStr) = 'OTHER') Then
  Begin
    ParseWhenClause := EWH_OTHER;
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And
          (UpCaseStr(CurTokStr) = 'ANY') Then
  Begin
    ParseWhenClause := EWH_ANY;
    LexNextToken;
  End
  Else If SubjectType = EVS_TRUE Then
  Begin
    { EVALUATE TRUE : les WHEN contiennent des conditions }
    ParseWhenClause := EWH_CONDITION;
  End
  Else If SubjectType = EVS_FALSE Then
  Begin
    ParseWhenClause := EWH_CONDITION;
  End
  Else
  Begin
    { WHEN valeur ou WHEN val-1 THRU val-2 }
    ParseWhenClause := EWH_VALUE;
    { Lire la valeur }
    If CurTokType = TOK_IDENT Then
      LexNextToken
    Else If (CurTokType = TOK_INTEGER) Or
            (CurTokType = TOK_DECIMAL) Then
      LexNextToken
    Else If CurTokType = TOK_STRING Then
      LexNextToken;

    { Verifier si c est un THRU/THROUGH (plage de valeurs) }
    If (CurTokType = TOK_KEYWORD) And
       ((CurTokNum = KW_THROUGH) Or (CurTokNum = KW_THRU)) Then
    Begin
      ParseWhenClause := EWH_RANGE;
      LexNextToken;
      { Lire la valeur finale de la plage }
      If CurTokType = TOK_IDENT Then
        LexNextToken
      Else If (CurTokType = TOK_INTEGER) Or
              (CurTokType = TOK_DECIMAL) Then
        LexNextToken
      Else If CurTokType = TOK_STRING Then
        LexNextToken;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseEvaluateStatement : parser et generer le code pour      }
{   EVALUATE sujet [ALSO sujet-2 ...]                          }
{     WHEN valeur/condition [ALSO valeur-2 ...]                }
{       instructions...                                        }
{     WHEN OTHER                                               }
{       instructions...                                        }
{   END-EVALUATE | .                                            }
{ ------------------------------------------------------------ }

Procedure ParseEvaluateStatement;
Var
  LblWhenNext, LblEndEval : TString;
  SubjectType : Integer;
  WhenType    : Integer;
  AlsoCount   : Integer;
  WhenNum     : Integer;
  HasOther    : Boolean;
  OldForm     : Boolean;
Begin
  CtlEvalCount := CtlEvalCount + 1;
  CtlEvalDepth := CtlEvalDepth + 1;
  If CtlEvalDepth > CtlMaxEvalDepth Then
    CtlMaxEvalDepth := CtlEvalDepth;

  If CtlEvalDepth > CTL_MAX_EVAL_DEPTH Then
  Begin
    WarnMsg('EVALUATE imbrique trop profondement (max ' +
            ItoSI(CTL_MAX_EVAL_DEPTH) + ')');
    CtlEvalDepth := CtlEvalDepth - 1;
    Exit;
  End;

  LblEndEval := GenCtlLabel;
  HasOther   := False;
  OldForm    := False;
  WhenNum    := 0;
  AlsoCount  := 0;

  WriteLn('    ; EVALUATE debut (profondeur=', CtlEvalDepth, ')');

  { Parser le sujet principal }
  SubjectType := ParseEvaluateSubject;
  WriteLn('    ; sujet EVALUATE : ', EvalSubjectName(SubjectType));

  { Parser les sujets ALSO supplementaires }
  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ALSO) Do
  Begin
    LexNextToken;
    AlsoCount  := AlsoCount + 1;
    CtlAlsoCount := CtlAlsoCount + 1;
    If AlsoCount > CTL_MAX_ALSO Then
    Begin
      WarnMsg('Trop de sujets ALSO (max ' +
              ItoSI(CTL_MAX_ALSO) + ')');
    End;
    WriteLn('    ; sujet ALSO #', AlsoCount, ' : ',
            EvalSubjectName(ParseEvaluateSubject));
  End;

  { Parser les clauses WHEN }
  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WHEN) Do
  Begin
    WhenNum := WhenNum + 1;
    CtlWhenCount := CtlWhenCount + 1;

    If WhenNum > CTL_MAX_WHEN Then
    Begin
      WarnMsg('Trop de clauses WHEN (max ' +
              ItoSI(CTL_MAX_WHEN) + ')');
    End;

    LexNextToken;  { consommer WHEN }
    LblWhenNext := GenCtlLabel;

    WhenType := ParseWhenClause(SubjectType);

    If WhenType = EWH_OTHER Then
    Begin
      HasOther := True;
      CtlWhenOtherCount := CtlWhenOtherCount + 1;
      WriteLn('    ; WHEN OTHER');
    End
    Else
    Begin
      WriteLn('    ; WHEN #', WhenNum, ' type=',
              WhenTypeName(WhenType));

      { Generer la comparaison selon le type de sujet }
      Case SubjectType Of
        EVS_IDENT, EVS_EXPR :
        Begin
          If WhenType = EWH_VALUE Then
          Begin
            WriteLn('    CMP EAX, EBX');
            WriteLn('    JNE ', LblWhenNext);
            CtlTotalGenerated := CtlTotalGenerated + 2;
          End
          Else If WhenType = EWH_RANGE Then
          Begin
            WriteLn('    CMP EAX, ECX  ; borne inf');
            WriteLn('    JL ', LblWhenNext);
            WriteLn('    CMP EAX, EDX  ; borne sup');
            WriteLn('    JG ', LblWhenNext);
            CtlTotalGenerated := CtlTotalGenerated + 4;
          End
          Else If WhenType = EWH_ANY Then
          Begin
            { ANY correspond toujours }
            WriteLn('    ; WHEN ANY (toujours vrai)');
            CtlTotalGenerated := CtlTotalGenerated + 1;
          End;
        End;
        EVS_TRUE :
        Begin
          { La condition est evaluee : si fausse, sauter }
          WriteLn('    ; evaluer condition pour EVALUATE TRUE');
          WriteLn('    TEST EAX, EAX');
          WriteLn('    JE ', LblWhenNext);
          CtlTotalGenerated := CtlTotalGenerated + 3;
        End;
        EVS_FALSE :
        Begin
          WriteLn('    ; evaluer condition pour EVALUATE FALSE');
          WriteLn('    TEST EAX, EAX');
          WriteLn('    JNE ', LblWhenNext);
          CtlTotalGenerated := CtlTotalGenerated + 3;
        End;
      End;

      { Parser les ALSO dans la clause WHEN }
      { (doivent correspondre aux ALSO du sujet) }
    End;

    { Instructions du WHEN }
    WriteLn('    ; instructions WHEN #', WhenNum);

    { Saut inconditionnel vers la fin de l EVALUATE }
    GenUnconditionalJump(LblEndEval);

    { Label pour le prochain WHEN }
    GenCtlLabelEmit(LblWhenNext);
  End;

  { Terminaison : END-EVALUATE ou point }
  If (CurTokType = TOK_KEYWORD) And
     (CurTokNum = KW_END_EVALUATE) Then
  Begin
    CtlEndEvalCount := CtlEndEvalCount + 1;
    LexNextToken;
  End
  Else If CurTokType = TOK_DOT Then
  Begin
    OldForm := True;
    CtlOldFormCount := CtlOldFormCount + 1;
  End;

  { Label de fin }
  GenCtlLabelEmit(LblEndEval);

  WriteLn('    ; EVALUATE fin (profondeur=', CtlEvalDepth,
          ', WHEN=', WhenNum, ')');

  If OldForm Then
    WriteLn('    ; (forme ancienne avec point)');

  CtlEvalDepth := CtlEvalDepth - 1;
  CtlTotalGenerated := CtlTotalGenerated + 1;
End;

{ ------------------------------------------------------------ }
{ ParseContinueStatement : parser l instruction CONTINUE       }
{   CONTINUE est un no-op (ne genere aucun code)               }
{ ------------------------------------------------------------ }

Procedure ParseContinueStatement;
Begin
  CtlContinueCount := CtlContinueCount + 1;
  WriteLn('    ; CONTINUE (no-op)');
  WriteLn('    NOP');
  CtlTotalGenerated := CtlTotalGenerated + 2;
  { Le token CONTINUE a deja ete consomme }
End;

{ ------------------------------------------------------------ }
{ ParseControlStatement : dispatcheur pour les structures de   }
{   controle : IF, EVALUATE, CONTINUE                          }
{ ------------------------------------------------------------ }

Procedure ParseControlStatement;
Begin
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IF) Then
  Begin
    LexNextToken;
    ParseIfStatement;
  End
  Else If (CurTokType = TOK_KEYWORD) And
          (CurTokNum = KW_EVALUATE) Then
  Begin
    LexNextToken;
    ParseEvaluateStatement;
  End
  Else If (CurTokType = TOK_KEYWORD) And
          (CurTokNum = KW_CONTINUE) Then
  Begin
    LexNextToken;
    ParseContinueStatement;
  End;
End;

{ ------------------------------------------------------------ }
{ IsControlKeyword : verifier si le token courant est un       }
{   mot-cle de structure de controle (IF, EVALUATE, CONTINUE)  }
{ ------------------------------------------------------------ }

Function IsControlKeyword : Boolean;
Begin
  IsControlKeyword := False;
  If CurTokType = TOK_KEYWORD Then
  Begin
    If (CurTokNum = KW_IF) Or
       (CurTokNum = KW_EVALUATE) Or
       (CurTokNum = KW_CONTINUE) Then
      IsControlKeyword := True;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpControlState : afficher l etat du module de structures   }
{   de controle (compteurs et statistiques)                    }
{ ------------------------------------------------------------ }

Procedure DumpControlState;
Begin
  WriteLn('=== Structures de controle (IF/EVALUATE) ===');
  WriteLn('  Initialise          : ', CtlInitialized);
  WriteLn('  Labels generes      : ', CtlLabelNum);
  WriteLn('  Instructions IF     : ', CtlIfCount);
  WriteLn('  Clauses ELSE        : ', CtlElseCount);
  WriteLn('  END-IF              : ', CtlEndIfCount);
  WriteLn('  IF imbriques        : ', CtlNestedIfCount);
  WriteLn('  Prof. max IF        : ', CtlMaxIfDepth);
  WriteLn('  Instructions EVAL   : ', CtlEvalCount);
  WriteLn('  Clauses WHEN        : ', CtlWhenCount);
  WriteLn('  WHEN OTHER          : ', CtlWhenOtherCount);
  WriteLn('  END-EVALUATE        : ', CtlEndEvalCount);
  WriteLn('  Prof. max EVAL      : ', CtlMaxEvalDepth);
  WriteLn('  Conditions combinees: ', CtlCombinedConds);
  WriteLn('  Sujets ALSO         : ', CtlAlsoCount);
  WriteLn('  Instructions CONTINUE:', CtlContinueCount);
  WriteLn('  Forme ancienne (.)  : ', CtlOldFormCount);
  WriteLn('  Total genere        : ', CtlTotalGenerated);
End;

{ 10 fonctions accesseurs pour TODO 10                         }

Function IsCtlInitialized : Boolean;
Begin
  IsCtlInitialized := CtlInitialized;
End;

Function IsCtlEmpty : Boolean;
Begin
  IsCtlEmpty := (CtlTotalGenerated = 0);
End;

Function GetCtlTotalGenerated : Integer;
Begin
  GetCtlTotalGenerated := CtlTotalGenerated;
End;

Function GetCtlStatus : TString;
Begin
  If Not CtlInitialized Then
    GetCtlStatus := 'NON INITIALISE'
  Else
    GetCtlStatus := 'IF=' + ItoSI(CtlIfCount) +
                    ' EVAL=' + ItoSI(CtlEvalCount) +
                    ' CONT=' + ItoSI(CtlContinueCount) +
                    ' WHEN=' + ItoSI(CtlWhenCount);
End;

Function GetCtlIfCount : Integer;
Begin
  GetCtlIfCount := CtlIfCount;
End;

Function GetCtlEvalCount : Integer;
Begin
  GetCtlEvalCount := CtlEvalCount;
End;

Function GetCtlWhenCount : Integer;
Begin
  GetCtlWhenCount := CtlWhenCount;
End;

Function GetCtlContinueCount : Integer;
Begin
  GetCtlContinueCount := CtlContinueCount;
End;

Function GetCtlMaxIfDepth : Integer;
Begin
  GetCtlMaxIfDepth := CtlMaxIfDepth;
End;

Function GetCtlStateCount : Integer;
Begin
  GetCtlStateCount := CtlStateCount;
End;


{ ============================================================ }
{ TODO 11 - PARSEUR : PERFORM ET BOUCLES                       }
{           Generation de boucles 80386 (CMP/JMP/LOOP)         }
{ ============================================================ }

Const
  { Types de PERFORM }
  PFM_NONE       = 0;    { pas de PERFORM actif                      }
  PFM_SIMPLE     = 1;    { PERFORM paragraphe                        }
  PFM_THRU       = 2;    { PERFORM para THRU para-fin                }
  PFM_INLINE     = 3;    { PERFORM ... END-PERFORM                   }
  PFM_TIMES      = 4;    { PERFORM n TIMES                           }
  PFM_UNTIL      = 5;    { PERFORM UNTIL condition                   }
  PFM_VARYING    = 6;    { PERFORM VARYING id FROM BY UNTIL          }

  { Types de test pour PERFORM UNTIL/VARYING }
  TST_BEFORE     = 0;    { WITH TEST BEFORE (defaut)                 }
  TST_AFTER      = 1;    { WITH TEST AFTER                           }

  { Types de GO TO }
  GTO_SIMPLE     = 0;    { GO TO paragraphe                          }
  GTO_DEPENDING  = 1;    { GO TO p1 p2 ... DEPENDING ON id           }

  { Types de sortie }
  EXT_PARAGRAPH  = 0;    { EXIT PARAGRAPH                            }
  EXT_SECTION    = 1;    { EXIT SECTION                              }
  EXT_PROGRAM    = 2;    { GOBACK / STOP RUN                         }

  { Limites }
  PFM_MAX_DEPTH       = 32;   { profondeur max d imbrication PERFORM }
  PFM_MAX_VARYING     = 8;    { max de clauses AFTER dans VARYING    }
  PFM_MAX_GOTO_TARGETS = 16;  { max de cibles GO TO ... DEPENDING    }

Var
  PfmInitialized     : Boolean;   { True si InitPerformState appele       }
  PfmStateCount      : Integer;   { compteur d etat general               }
  PfmLabelNum        : Integer;   { compteur de labels internes generes   }
  PfmSimpleCount     : Integer;   { nombre de PERFORM simples             }
  PfmThruCount       : Integer;   { nombre de PERFORM THRU                }
  PfmInlineCount     : Integer;   { nombre de PERFORM inline              }
  PfmTimesCount      : Integer;   { nombre de PERFORM TIMES               }
  PfmUntilCount      : Integer;   { nombre de PERFORM UNTIL               }
  PfmVaryingCount    : Integer;   { nombre de PERFORM VARYING             }
  PfmAfterCount      : Integer;   { nombre de clauses AFTER               }
  PfmGotoCount       : Integer;   { nombre de GO TO                       }
  PfmGotoDependCount : Integer;   { nombre de GO TO ... DEPENDING         }
  PfmExitParaCount   : Integer;   { nombre de EXIT PARAGRAPH              }
  PfmExitSectCount   : Integer;   { nombre de EXIT SECTION                }
  PfmGobackCount     : Integer;   { nombre de GOBACK                      }
  PfmDepth           : Integer;   { profondeur d imbrication courante     }
  PfmMaxDepth        : Integer;   { profondeur max atteinte               }
  PfmTestBeforeCount : Integer;   { nombre de WITH TEST BEFORE            }
  PfmTestAfterCount  : Integer;   { nombre de WITH TEST AFTER             }
  PfmTotalGenerated  : Integer;   { total d instructions generees         }

{ ------------------------------------------------------------ }
{ InitPerformState : initialiser l etat du module PERFORM      }
{ ------------------------------------------------------------ }

Procedure InitPerformState;
Begin
  PfmInitialized     := True;
  PfmStateCount      := 0;
  PfmLabelNum        := 0;
  PfmSimpleCount     := 0;
  PfmThruCount       := 0;
  PfmInlineCount     := 0;
  PfmTimesCount      := 0;
  PfmUntilCount      := 0;
  PfmVaryingCount    := 0;
  PfmAfterCount      := 0;
  PfmGotoCount       := 0;
  PfmGotoDependCount := 0;
  PfmExitParaCount   := 0;
  PfmExitSectCount   := 0;
  PfmGobackCount     := 0;
  PfmDepth           := 0;
  PfmMaxDepth        := 0;
  PfmTestBeforeCount := 0;
  PfmTestAfterCount  := 0;
  PfmTotalGenerated  := 0;
End;

{ ------------------------------------------------------------ }
{ GenPfmLabel : generer un label interne unique pour PERFORM    }
{ Retourne un label de la forme _COBL_PFM_nnn                  }
{ ------------------------------------------------------------ }

Function GenPfmLabel : TString;
Begin
  Inc(PfmLabelNum);
  GenPfmLabel := PFX_LBL + 'PFM_' + ItoSI(PfmLabelNum);
End;

{ ------------------------------------------------------------ }
{ PfmTypeName : nom textuel d un type de PERFORM               }
{ ------------------------------------------------------------ }

Function PfmTypeName(T : Integer) : TString;
Begin
  Case T Of
    PFM_NONE    : PfmTypeName := 'NONE';
    PFM_SIMPLE  : PfmTypeName := 'SIMPLE';
    PFM_THRU    : PfmTypeName := 'THRU';
    PFM_INLINE  : PfmTypeName := 'INLINE';
    PFM_TIMES   : PfmTypeName := 'TIMES';
    PFM_UNTIL   : PfmTypeName := 'UNTIL';
    PFM_VARYING : PfmTypeName := 'VARYING';
  Else
    PfmTypeName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GotoTypeName : nom textuel d un type de GO TO                }
{ ------------------------------------------------------------ }

Function GotoTypeName(T : Integer) : TString;
Begin
  Case T Of
    GTO_SIMPLE    : GotoTypeName := 'SIMPLE';
    GTO_DEPENDING : GotoTypeName := 'DEPENDING';
  Else
    GotoTypeName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ ExitTypeName : nom textuel d un type de EXIT                 }
{ ------------------------------------------------------------ }

Function ExitTypeName(T : Integer) : TString;
Begin
  Case T Of
    EXT_PARAGRAPH : ExitTypeName := 'PARAGRAPH';
    EXT_SECTION   : ExitTypeName := 'SECTION';
    EXT_PROGRAM   : ExitTypeName := 'PROGRAM';
  Else
    ExitTypeName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ EnterPerform / LeavePerform : gestion de profondeur           }
{ ------------------------------------------------------------ }

Procedure EnterPerform;
Begin
  Inc(PfmDepth);
  If PfmDepth > PfmMaxDepth Then
    PfmMaxDepth := PfmDepth;
End;

Procedure LeavePerform;
Begin
  If PfmDepth > 0 Then
    Dec(PfmDepth);
End;

{ ------------------------------------------------------------ }
{ GenPerformCall : generer un CALL vers un paragraphe COBOL     }
{   ParaName = nom du paragraphe (identifiant COBOL)            }
{   Genere : CALL _COB_paragraphe                               }
{ ------------------------------------------------------------ }

Procedure GenPerformCall(ParaName : TString);
Begin
  WriteLn(';   CALL ' + PFX_PARA + AsmIdent(ParaName));
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenPerformThruCall : generer un appel PERFORM THRU            }
{   ParaFrom = paragraphe de debut                              }
{   ParaTo   = paragraphe de fin                                }
{   Genere une boucle CALL de ParaFrom a ParaTo                 }
{ ------------------------------------------------------------ }

Procedure GenPerformThruCall(ParaFrom, ParaTo : TString);
Begin
  WriteLn(';   ; PERFORM ' + ParaFrom + ' THRU ' + ParaTo);
  WriteLn(';   CALL ' + PFX_PARA + AsmIdent(ParaFrom));
  WriteLn(';   ; ... travers les paragraphes jusqu a ' + ParaTo);
  WriteLn(';   CALL ' + PFX_PARA + AsmIdent(ParaTo));
  Inc(PfmTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenPerformTimesLoop : generer une boucle PERFORM n TIMES      }
{   N = nombre de repetitions                                   }
{   LblLoop, LblEnd = labels de debut et fin                    }
{   Genere :                                                    }
{     MOV ECX, n                                                }
{     label_loop: PUSH ECX                                      }
{     ... corps ...                                             }
{     POP ECX / DEC ECX / JNZ label_loop                        }
{ ------------------------------------------------------------ }

Procedure GenPerformTimesInit(N : Integer; LblLoop : TString);
Begin
  WriteLn(';   MOV ECX, ' + ItoSI(N));
  WriteLn('; ' + LblLoop + ':');
  WriteLn(';   PUSH ECX');
  Inc(PfmTotalGenerated, 3);
End;

Procedure GenPerformTimesEnd(LblLoop : TString);
Begin
  WriteLn(';   POP ECX');
  WriteLn(';   DEC ECX');
  WriteLn(';   JNZ ' + LblLoop);
  Inc(PfmTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenPerformUntilBefore : generer le test BEFORE pour UNTIL     }
{   LblLoop = label de debut de boucle                          }
{   LblEnd  = label de fin de boucle                            }
{   Genere :                                                    }
{     label_loop:                                               }
{     ; evaluer la condition                                    }
{     CMP EAX, 0 / JNE label_end (si condition vraie -> sortir) }
{ ------------------------------------------------------------ }

Procedure GenPerformUntilBefore(LblLoop, LblEnd : TString);
Begin
  WriteLn('; ' + LblLoop + ':');
  WriteLn(';   ; evaluer la condition UNTIL');
  WriteLn(';   CMP EAX, 0');
  WriteLn(';   JNE ' + LblEnd);
  Inc(PfmTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenPerformUntilAfter : generer le test AFTER pour UNTIL       }
{   LblLoop = label de debut de boucle                          }
{   LblEnd  = label de fin de boucle                            }
{   Genere :                                                    }
{     label_loop:                                               }
{     ... corps ...                                             }
{     ; evaluer la condition                                    }
{     CMP EAX, 0 / JE label_loop (si condition fausse -> boucler)}
{ ------------------------------------------------------------ }

Procedure GenPerformUntilAfter(LblLoop, LblEnd : TString);
Begin
  WriteLn(';   ; evaluer la condition UNTIL (TEST AFTER)');
  WriteLn(';   CMP EAX, 0');
  WriteLn(';   JE ' + LblLoop);
  WriteLn('; ' + LblEnd + ':');
  Inc(PfmTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenPerformVaryingInit : generer l initialisation VARYING      }
{   VarName = nom de la variable VARYING                        }
{   FromVal = valeur initiale (FROM)                            }
{   Genere : MOV [var], from_value                              }
{ ------------------------------------------------------------ }

Procedure GenPerformVaryingInit(VarName : TString; FromVal : Integer);
Begin
  WriteLn(';   MOV DWORD [' + PFX_VAR + AsmIdent(VarName) + '], ' + ItoSI(FromVal));
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenPerformVaryingStep : generer l increment VARYING           }
{   VarName = nom de la variable VARYING                        }
{   ByVal   = valeur d increment (BY)                           }
{   Genere : ADD [var], by_value                                }
{ ------------------------------------------------------------ }

Procedure GenPerformVaryingStep(VarName : TString; ByVal : Integer);
Begin
  WriteLn(';   ADD DWORD [' + PFX_VAR + AsmIdent(VarName) + '], ' + ItoSI(ByVal));
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenPerformLoopBack : generer le JMP de retour en debut        }
{   LblLoop = label de debut de boucle                          }
{ ------------------------------------------------------------ }

Procedure GenPerformLoopBack(LblLoop : TString);
Begin
  WriteLn(';   JMP ' + LblLoop);
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenPerformLabelEmit : emettre un label                        }
{   Lbl = nom du label                                          }
{ ------------------------------------------------------------ }

Procedure GenPerformLabelEmit(Lbl : TString);
Begin
  WriteLn('; ' + Lbl + ':');
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenGotoSimple : generer un GO TO inconditionnel               }
{   ParaName = nom du paragraphe cible                          }
{   Genere : JMP _COB_paragraphe                                }
{ ------------------------------------------------------------ }

Procedure GenGotoSimple(ParaName : TString);
Begin
  WriteLn(';   JMP ' + PFX_PARA + AsmIdent(ParaName));
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenGotoDepending : generer un GO TO ... DEPENDING ON          }
{   Targets = tableau de noms de paragraphes (string)           }
{   Count   = nombre de cibles                                  }
{   VarName = nom de la variable DEPENDING ON                   }
{   Genere une table de sauts indexee                            }
{ ------------------------------------------------------------ }

Procedure GenGotoDepending(VarName : TString; Count : Integer);
Var
  I : Integer;
  LblTable : TString;
  LblEnd   : TString;
Begin
  LblTable := GenPfmLabel;
  LblEnd   := GenPfmLabel;
  WriteLn(';   ; GO TO ... DEPENDING ON ' + VarName);
  WriteLn(';   MOV EAX, [' + PFX_VAR + AsmIdent(VarName) + ']');
  WriteLn(';   DEC EAX');
  WriteLn(';   CMP EAX, ' + ItoSI(Count));
  WriteLn(';   JAE ' + LblEnd);
  WriteLn(';   JMP DWORD [' + LblTable + ' + EAX*4]');
  WriteLn('; ' + LblTable + ':');
  For I := 1 To Count Do
    WriteLn(';   DD ' + PFX_PARA + 'TARGET_' + ItoSI(I));
  WriteLn('; ' + LblEnd + ':');
  Inc(PfmTotalGenerated, 6 + Count);
End;

{ ------------------------------------------------------------ }
{ GenExitParagraph : generer un EXIT PARAGRAPH (RET local)      }
{ ------------------------------------------------------------ }

Procedure GenExitParagraph;
Begin
  WriteLn(';   RET   ; EXIT PARAGRAPH');
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenExitSection : generer un EXIT SECTION (RET de section)     }
{ ------------------------------------------------------------ }

Procedure GenExitSection;
Begin
  WriteLn(';   RET   ; EXIT SECTION');
  Inc(PfmTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenGoback : generer un GOBACK (retour au systeme)             }
{   Genere un appel a ExitProcess (ou equivalent)               }
{ ------------------------------------------------------------ }

Procedure GenGoback;
Begin
  WriteLn(';   PUSH 0');
  WriteLn(';   CALL _ExitProcess@4   ; GOBACK');
  Inc(PfmTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ ParsePerformSimple : parser PERFORM paragraphe [THRU para-fin]}
{   PERFORM nom-paragraphe                                      }
{   PERFORM nom-paragraphe THRU nom-paragraphe-fin              }
{ ------------------------------------------------------------ }

Procedure ParsePerformSimple;
Var
  ParaName  : TString;
  ParaEnd   : TString;
  HasThru   : Boolean;
Begin
  ParaName := CurTokStr;
  LexNextToken;
  HasThru := False;
  ParaEnd := '';

  { Verifier THRU ou THROUGH }
  If (CurTokType = TOK_KEYWORD) And
     ((CurTokNum = KW_THRU) Or (CurTokNum = KW_THROUGH)) Then
  Begin
    HasThru := True;
    LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      ParaEnd := CurTokStr;
      LexNextToken;
    End
    Else
      WarnMsg('Nom de paragraphe attendu apres THRU');
  End;

  If HasThru Then
  Begin
    Inc(PfmThruCount);
    Inc(PfmStateCount);
    GenPerformThruCall(ParaName, ParaEnd);
  End
  Else
  Begin
    Inc(PfmSimpleCount);
    Inc(PfmStateCount);
    GenPerformCall(ParaName);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePerformTimes : parser PERFORM n TIMES                    }
{   PERFORM paragraphe n TIMES                                  }
{   PERFORM n TIMES instructions... END-PERFORM                 }
{ ------------------------------------------------------------ }

Procedure ParsePerformTimes(IsInline : Boolean; N : Integer);
Var
  LblLoop : TString;
Begin
  Inc(PfmTimesCount);
  Inc(PfmStateCount);

  LblLoop := GenPfmLabel;
  GenPerformTimesInit(N, LblLoop);

  If IsInline Then
  Begin
    EnterPerform;
    { Parser les instructions du bloc inline }
    { On avance jusqu a END-PERFORM }
    While (CurTokType <> TOK_EOF) And
          Not ((CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM)) Do
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM) Then
      LexNextToken;
    LeavePerform;
  End;

  GenPerformTimesEnd(LblLoop);
End;

{ ------------------------------------------------------------ }
{ ParseWithTestClause : parser WITH TEST BEFORE/AFTER           }
{ Retourne TST_BEFORE (0) ou TST_AFTER (1)                     }
{ ------------------------------------------------------------ }

Function ParseWithTestClause : Integer;
Begin
  ParseWithTestClause := TST_BEFORE;  { defaut }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then
  Begin
    LexNextToken;  { consommer WITH }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TEST) Then
    Begin
      LexNextToken;  { consommer TEST }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BEFORE) Then
      Begin
        LexNextToken;
        ParseWithTestClause := TST_BEFORE;
        Inc(PfmTestBeforeCount);
      End
      Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AFTER) Then
      Begin
        LexNextToken;
        ParseWithTestClause := TST_AFTER;
        Inc(PfmTestAfterCount);
      End
      Else
        WarnMsg('BEFORE ou AFTER attendu apres WITH TEST');
    End
    Else
      WarnMsg('TEST attendu apres WITH');
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePerformUntil : parser PERFORM UNTIL condition             }
{   PERFORM paragraphe UNTIL condition                           }
{   PERFORM [WITH TEST BEFORE|AFTER] UNTIL condition             }
{     instructions... END-PERFORM                                }
{ ------------------------------------------------------------ }

Procedure ParsePerformUntil(IsInline : Boolean);
Var
  TestMode : Integer;
  LblLoop  : TString;
  LblEnd   : TString;
Begin
  Inc(PfmUntilCount);
  Inc(PfmStateCount);

  TestMode := ParseWithTestClause;

  { Consommer UNTIL }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNTIL) Then
    LexNextToken;

  LblLoop := GenPfmLabel;
  LblEnd  := GenPfmLabel;

  If TestMode = TST_BEFORE Then
  Begin
    GenPerformUntilBefore(LblLoop, LblEnd);
    { Ici on parserait la condition - pour l instant on avance }
  End
  Else
    GenPerformLabelEmit(LblLoop);

  If IsInline Then
  Begin
    EnterPerform;
    { Parser les instructions du bloc inline }
    While (CurTokType <> TOK_EOF) And
          Not ((CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM)) Do
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM) Then
      LexNextToken;
    LeavePerform;
  End;

  If TestMode = TST_AFTER Then
    GenPerformUntilAfter(LblLoop, LblEnd)
  Else
  Begin
    GenPerformLoopBack(LblLoop);
    GenPerformLabelEmit(LblEnd);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePerformVarying : parser PERFORM VARYING                  }
{   PERFORM paragraphe                                          }
{     VARYING id-1 FROM val-1 BY val-2 UNTIL condition          }
{     [AFTER id-2 FROM val-3 BY val-4 UNTIL condition-2]        }
{   PERFORM VARYING id-1 FROM val-1 BY val-2 UNTIL condition    }
{     instructions... END-PERFORM                                }
{ ------------------------------------------------------------ }

Procedure ParsePerformVarying(IsInline : Boolean);
Var
  VarName  : TString;
  FromVal  : Integer;
  ByVal    : Integer;
  LblLoop  : TString;
  LblEnd   : TString;
  TestMode : Integer;
Begin
  Inc(PfmVaryingCount);
  Inc(PfmStateCount);

  TestMode := ParseWithTestClause;

  { Consommer VARYING }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_VARYING) Then
    LexNextToken;

  { Lire le nom de la variable }
  VarName := '';
  If CurTokType = TOK_IDENT Then
  Begin
    VarName := CurTokStr;
    LexNextToken;
  End
  Else
    WarnMsg('Identifiant attendu apres VARYING');

  { FROM }
  FromVal := 1;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FROM) Then
  Begin
    LexNextToken;
    If CurTokType = TOK_INTEGER Then
    Begin
      FromVal := CurTokNum;
      LexNextToken;
    End
    Else If CurTokType = TOK_IDENT Then
      LexNextToken   { variable source }
    Else
      WarnMsg('Valeur attendue apres FROM');
  End;

  { BY }
  ByVal := 1;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
  Begin
    LexNextToken;
    If CurTokType = TOK_INTEGER Then
    Begin
      ByVal := CurTokNum;
      LexNextToken;
    End
    Else If CurTokType = TOK_IDENT Then
      LexNextToken   { variable step }
    Else
      WarnMsg('Valeur attendue apres BY');
  End;

  { UNTIL }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNTIL) Then
    LexNextToken;

  { Generer le code d initialisation }
  GenPerformVaryingInit(VarName, FromVal);

  LblLoop := GenPfmLabel;
  LblEnd  := GenPfmLabel;

  If TestMode = TST_BEFORE Then
    GenPerformUntilBefore(LblLoop, LblEnd)
  Else
    GenPerformLabelEmit(LblLoop);

  { Verifier AFTER (boucle imbriquee) }
  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AFTER) Do
  Begin
    Inc(PfmAfterCount);
    LexNextToken;
    { Parser la clause AFTER id FROM val BY val UNTIL cond }
    If CurTokType = TOK_IDENT Then
      LexNextToken;  { variable AFTER }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FROM) Then
    Begin
      LexNextToken;
      If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_IDENT) Then
        LexNextToken;
    End;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
    Begin
      LexNextToken;
      If (CurTokType = TOK_INTEGER) Or (CurTokType = TOK_IDENT) Then
        LexNextToken;
    End;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNTIL) Then
      LexNextToken;
  End;

  If IsInline Then
  Begin
    EnterPerform;
    { Parser les instructions du bloc inline }
    While (CurTokType <> TOK_EOF) And
          Not ((CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM)) Do
      LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM) Then
      LexNextToken;
    LeavePerform;
  End;

  { Generer l increment et le retour }
  GenPerformVaryingStep(VarName, ByVal);
  If TestMode = TST_AFTER Then
    GenPerformUntilAfter(LblLoop, LblEnd)
  Else
  Begin
    GenPerformLoopBack(LblLoop);
    GenPerformLabelEmit(LblEnd);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePerformInline : parser PERFORM instructions END-PERFORM  }
{   PERFORM instructions... END-PERFORM (boucle infinie ou      }
{   simple bloc selon contexte)                                  }
{ ------------------------------------------------------------ }

Procedure ParsePerformInline;
Begin
  Inc(PfmInlineCount);
  Inc(PfmStateCount);
  EnterPerform;
  { Parser les instructions du bloc inline }
  While (CurTokType <> TOK_EOF) And
        Not ((CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM)) Do
    LexNextToken;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_PERFORM) Then
    LexNextToken;
  LeavePerform;
End;

{ ------------------------------------------------------------ }
{ ParsePerformStatement : parser une instruction PERFORM         }
{   Determine le type de PERFORM et delegue au bon parseur      }
{   PERFORM est deja le token courant                            }
{ ------------------------------------------------------------ }

Procedure ParsePerformStatement;
Var
  NextIsInteger : Boolean;
  NextIsIdent   : Boolean;
  N             : Integer;
Begin
  LexNextToken;  { consommer PERFORM }

  { Verifier si c est un PERFORM inline (pas de nom de paragraphe) }
  { PERFORM UNTIL ... END-PERFORM }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNTIL) Then
  Begin
    ParsePerformUntil(True);
    Exit;
  End;

  { PERFORM WITH TEST ... UNTIL ... END-PERFORM }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then
  Begin
    { Regarder si UNTIL ou VARYING suit }
    ParsePerformUntil(True);
    Exit;
  End;

  { PERFORM VARYING ... END-PERFORM }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_VARYING) Then
  Begin
    ParsePerformVarying(True);
    Exit;
  End;

  { PERFORM n TIMES ... END-PERFORM (n est un entier) }
  If CurTokType = TOK_INTEGER Then
  Begin
    N := CurTokNum;
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TIMES) Then
    Begin
      LexNextToken;
      ParsePerformTimes(True, N);
      Exit;
    End;
  End;

  { PERFORM nom-paragraphe [THRU ...] [n TIMES] [UNTIL ...] [VARYING ...] }
  If CurTokType = TOK_IDENT Then
  Begin
    NextIsIdent := True;
    NextIsInteger := False;
  End
  Else
  Begin
    NextIsIdent := False;
    NextIsInteger := (CurTokType = TOK_INTEGER);
  End;

  If NextIsIdent Then
  Begin
    { Sauver le nom du paragraphe }
    { Regarder ce qui suit pour determiner le type }
    ParsePerformSimple;

    { Apres le nom (et possible THRU), verifier si TIMES/UNTIL/VARYING }
    If CurTokType = TOK_INTEGER Then
    Begin
      N := CurTokNum;
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TIMES) Then
      Begin
        LexNextToken;
        { Ajuster : c est un PERFORM para n TIMES (non inline) }
        Dec(PfmSimpleCount);
        ParsePerformTimes(False, N);
      End;
    End
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNTIL) Then
    Begin
      Dec(PfmSimpleCount);
      ParsePerformUntil(False);
    End
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_VARYING) Then
    Begin
      Dec(PfmSimpleCount);
      ParsePerformVarying(False);
    End
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then
    Begin
      Dec(PfmSimpleCount);
      ParsePerformUntil(False);
    End;
    Exit;
  End;

  { PERFORM inline sans aucun qualificateur }
  ParsePerformInline;
End;

{ ------------------------------------------------------------ }
{ ParseGotoStatement : parser une instruction GO TO              }
{   GO TO nom-paragraphe (branchement inconditionnel)            }
{   GO TO nom-1 nom-2 ... DEPENDING ON id (branchement calcule) }
{   GO est deja le token courant                                 }
{ ------------------------------------------------------------ }

Procedure ParseGotoStatement;
Var
  TargetCount : Integer;
  VarName     : TString;
Begin
  LexNextToken;  { consommer GO }
  { Consommer TO si present }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken;

  { Collecter les cibles (identifiants) }
  TargetCount := 0;
  While (CurTokType = TOK_IDENT) Do
  Begin
    If TargetCount = 0 Then
      VarName := CurTokStr;
    Inc(TargetCount);
    LexNextToken;
  End;

  { Verifier DEPENDING ON }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DEPENDING) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
      LexNextToken;
    { Lire la variable }
    If CurTokType = TOK_IDENT Then
    Begin
      VarName := CurTokStr;
      LexNextToken;
    End;
    Inc(PfmGotoDependCount);
    Inc(PfmStateCount);
    GenGotoDepending(VarName, TargetCount);
  End
  Else
  Begin
    { GO TO simple }
    Inc(PfmGotoCount);
    Inc(PfmStateCount);
    If TargetCount > 0 Then
      GenGotoSimple(VarName)
    Else
      WarnMsg('Nom de paragraphe attendu apres GO TO');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExitStatement : parser EXIT PARAGRAPH / EXIT SECTION     }
{   EXIT est deja le token courant                               }
{ ------------------------------------------------------------ }

Procedure ParseExitCobStatement;
Begin
  LexNextToken;  { consommer EXIT }

  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PARAGRAPH) Then
  Begin
    LexNextToken;
    Inc(PfmExitParaCount);
    Inc(PfmStateCount);
    GenExitParagraph;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SECTION) Then
  Begin
    LexNextToken;
    Inc(PfmExitSectCount);
    Inc(PfmStateCount);
    GenExitSection;
  End
  Else
  Begin
    { EXIT seul = EXIT PARAGRAPH implicite }
    Inc(PfmExitParaCount);
    Inc(PfmStateCount);
    GenExitParagraph;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseGobackStatement : parser GOBACK                          }
{   Retour au programme appelant (equivalent a STOP RUN)        }
{   GOBACK est deja le token courant                             }
{ ------------------------------------------------------------ }

Procedure ParseGobackStatement;
Begin
  LexNextToken;  { consommer GOBACK }
  Inc(PfmGobackCount);
  Inc(PfmStateCount);
  GenGoback;
End;

{ ------------------------------------------------------------ }
{ ParsePerformLoopStatement : dispatcher pour PERFORM/GOTO/     }
{                              EXIT/GOBACK                       }
{   Appele depuis le parseur principal quand un mot-cle de       }
{   boucle est rencontre                                         }
{ ------------------------------------------------------------ }

Procedure ParsePerformLoopStatement;
Begin
  If (CurTokType = TOK_KEYWORD) Then
  Begin
    Case CurTokNum Of
      KW_PERFORM : ParsePerformStatement;
      KW_GO      : ParseGotoStatement;
      KW_EXIT    : ParseExitCobStatement;
      KW_GOBACK  : ParseGobackStatement;
    Else
      WarnMsg('Mot-cle de boucle inattendu : ' + CurTokStr);
      LexNextToken;
    End;
  End
  Else
  Begin
    WarnMsg('Mot-cle de boucle attendu');
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ IsPerformKeyword : tester si le mot-cle courant est un        }
{   mot-cle de boucle (PERFORM, GO, EXIT, GOBACK)               }
{ ------------------------------------------------------------ }

Function IsPerformKeyword : Boolean;
Begin
  IsPerformKeyword := False;
  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_PERFORM,
      KW_GO,
      KW_EXIT,
      KW_GOBACK : IsPerformKeyword := True;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpPerformState : afficher un resume de l etat PERFORM       }
{ ------------------------------------------------------------ }

Procedure DumpPerformState;
Begin
  WriteLn('--- Etat PERFORM/Boucles ---');
  WriteLn('  Initialise          : ', PfmInitialized);
  WriteLn('  PERFORM simples     : ', PfmSimpleCount);
  WriteLn('  PERFORM THRU        : ', PfmThruCount);
  WriteLn('  PERFORM inline      : ', PfmInlineCount);
  WriteLn('  PERFORM TIMES       : ', PfmTimesCount);
  WriteLn('  PERFORM UNTIL       : ', PfmUntilCount);
  WriteLn('  PERFORM VARYING     : ', PfmVaryingCount);
  WriteLn('  Clauses AFTER       : ', PfmAfterCount);
  WriteLn('  GO TO simples       : ', PfmGotoCount);
  WriteLn('  GO TO DEPENDING     : ', PfmGotoDependCount);
  WriteLn('  EXIT PARAGRAPH      : ', PfmExitParaCount);
  WriteLn('  EXIT SECTION        : ', PfmExitSectCount);
  WriteLn('  GOBACK              : ', PfmGobackCount);
  WriteLn('  WITH TEST BEFORE    : ', PfmTestBeforeCount);
  WriteLn('  WITH TEST AFTER     : ', PfmTestAfterCount);
  WriteLn('  Profondeur max      : ', PfmMaxDepth);
  WriteLn('  Total genere        : ', PfmTotalGenerated);
End;

{ 10 fonctions accesseurs pour TODO 11                         }

Function IsPfmInitialized : Boolean;
Begin
  IsPfmInitialized := PfmInitialized;
End;

Function IsPfmEmpty : Boolean;
Begin
  IsPfmEmpty := (PfmTotalGenerated = 0);
End;

Function GetPfmTotalGenerated : Integer;
Begin
  GetPfmTotalGenerated := PfmTotalGenerated;
End;

Function GetPfmStatus : TString;
Begin
  If Not PfmInitialized Then
    GetPfmStatus := 'NON INITIALISE'
  Else
    GetPfmStatus := 'SIMPLE=' + ItoSI(PfmSimpleCount) +
                    ' THRU=' + ItoSI(PfmThruCount) +
                    ' TIMES=' + ItoSI(PfmTimesCount) +
                    ' UNTIL=' + ItoSI(PfmUntilCount) +
                    ' VARYING=' + ItoSI(PfmVaryingCount) +
                    ' GOTO=' + ItoSI(PfmGotoCount);
End;

Function GetPfmSimpleCount : Integer;
Begin
  GetPfmSimpleCount := PfmSimpleCount;
End;

Function GetPfmTimesCount : Integer;
Begin
  GetPfmTimesCount := PfmTimesCount;
End;

Function GetPfmUntilCount : Integer;
Begin
  GetPfmUntilCount := PfmUntilCount;
End;

Function GetPfmVaryingCount : Integer;
Begin
  GetPfmVaryingCount := PfmVaryingCount;
End;

Function GetPfmMaxDepth : Integer;
Begin
  GetPfmMaxDepth := PfmMaxDepth;
End;

Function GetPfmStateCount : Integer;
Begin
  GetPfmStateCount := PfmStateCount;
End;


{ ============================================================ }
{ TODO 12 - PARSEUR : MOVE, INITIALIZE ET TRANSFERT DE DONNEES }
{           Generation 80386 : MOV, REP MOVSB, STOSB           }
{ ============================================================ }

Const
  { Categories de MOVE }
  MOV_NONE           = 0;   { pas de MOVE actif                        }
  MOV_ALPHA_TO_ALPHA = 1;   { alphanumerique -> alphanumerique          }
  MOV_NUM_TO_NUM     = 2;   { numerique -> numerique                    }
  MOV_NUM_TO_ALPHA   = 3;   { numerique -> alphanumerique               }
  MOV_ALPHA_TO_NUM   = 4;   { alphanumerique -> numerique               }
  MOV_GROUP_TO_GROUP = 5;   { groupe -> groupe (transfert alpha)        }
  MOV_FIGURATIVE     = 6;   { constante figurative (SPACES, ZEROS...)   }
  MOV_CORRESPONDING  = 7;   { MOVE CORRESPONDING                       }

  { Categories d INITIALIZE }
  INI_NONE           = 0;   { pas de categorie                          }
  INI_ALPHA_SPACES   = 1;   { alphanumerique initialise a SPACES        }
  INI_NUM_ZEROS      = 2;   { numerique initialise a ZEROS              }
  INI_REPLACING      = 3;   { REPLACING category BY literal             }

  { Categories de SET pour niveaux 88 }
  SET_NONE           = 0;   { pas de SET actif                          }
  SET_COND_TRUE      = 1;   { SET condition-88 TO TRUE                  }
  SET_COND_FALSE     = 2;   { SET condition-88 TO FALSE                 }

  { Limites }
  MVT_MAX_DESTINATIONS = 16;  { max de destinations pour un MOVE        }
  MVT_MAX_REPLACING    = 8;   { max de clauses REPLACING                }
  MVT_MAX_CORR_FIELDS  = 64;  { max de champs correspondants           }

Var
  MvtInitialized     : Boolean;   { True si InitMoveState appele           }
  MvtStateCount      : Integer;   { compteur d etat general                }
  MvtLabelNum        : Integer;   { compteur de labels internes            }
  MvtMoveCount       : Integer;   { nombre total de MOVE                   }
  MvtMoveAlphaAlpha  : Integer;   { MOVE alpha -> alpha                    }
  MvtMoveNumNum      : Integer;   { MOVE num -> num                        }
  MvtMoveNumAlpha    : Integer;   { MOVE num -> alpha                      }
  MvtMoveAlphaNum    : Integer;   { MOVE alpha -> num                      }
  MvtMoveGroupGroup  : Integer;   { MOVE groupe -> groupe                  }
  MvtMoveFigurative  : Integer;   { MOVE constante figurative              }
  MvtMoveCorrCount   : Integer;   { MOVE CORRESPONDING                     }
  MvtMultiDestCount  : Integer;   { MOVE avec destinations multiples       }
  MvtInitializeCount : Integer;   { nombre de INITIALIZE                   }
  MvtInitReplacCount : Integer;   { nombre de clauses REPLACING            }
  MvtSetCondCount    : Integer;   { nombre de SET condition-88 TO TRUE     }
  MvtTruncateCount   : Integer;   { nombre de troncatures detectees        }
  MvtPaddingCount    : Integer;   { nombre de remplissages (padding)       }
  MvtConversionCount : Integer;   { nombre de conversions de type          }
  MvtTotalGenerated  : Integer;   { total d instructions generees          }

{ ------------------------------------------------------------ }
{ InitMoveState : initialiser l etat du module MOVE/INITIALIZE }
{ ------------------------------------------------------------ }

Procedure InitMoveState;
Begin
  MvtInitialized     := True;
  MvtStateCount      := 0;
  MvtLabelNum        := 0;
  MvtMoveCount       := 0;
  MvtMoveAlphaAlpha  := 0;
  MvtMoveNumNum      := 0;
  MvtMoveNumAlpha    := 0;
  MvtMoveAlphaNum    := 0;
  MvtMoveGroupGroup  := 0;
  MvtMoveFigurative  := 0;
  MvtMoveCorrCount   := 0;
  MvtMultiDestCount  := 0;
  MvtInitializeCount := 0;
  MvtInitReplacCount := 0;
  MvtSetCondCount    := 0;
  MvtTruncateCount   := 0;
  MvtPaddingCount    := 0;
  MvtConversionCount := 0;
  MvtTotalGenerated  := 0;
End;

{ ------------------------------------------------------------ }
{ GenMvtLabel : generer un label interne unique pour MOVE       }
{ Retourne un label de la forme _COBL_MVT_nnn                  }
{ ------------------------------------------------------------ }

Function GenMvtLabel : TString;
Begin
  Inc(MvtLabelNum);
  GenMvtLabel := '_COBL_MVT_' + ItoSI(MvtLabelNum);
End;

{ ------------------------------------------------------------ }
{ MvtMoveCategoryName : nom lisible de la categorie de MOVE    }
{ ------------------------------------------------------------ }

Function MvtMoveCategoryName(Cat : Integer) : TString;
Begin
  Case Cat Of
    MOV_NONE           : MvtMoveCategoryName := 'NONE';
    MOV_ALPHA_TO_ALPHA : MvtMoveCategoryName := 'ALPHA->ALPHA';
    MOV_NUM_TO_NUM     : MvtMoveCategoryName := 'NUM->NUM';
    MOV_NUM_TO_ALPHA   : MvtMoveCategoryName := 'NUM->ALPHA';
    MOV_ALPHA_TO_NUM   : MvtMoveCategoryName := 'ALPHA->NUM';
    MOV_GROUP_TO_GROUP : MvtMoveCategoryName := 'GROUP->GROUP';
    MOV_FIGURATIVE     : MvtMoveCategoryName := 'FIGURATIVE';
    MOV_CORRESPONDING  : MvtMoveCategoryName := 'CORRESPONDING';
  Else
    MvtMoveCategoryName := 'INCONNU(' + ItoSI(Cat) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ MvtInitCategoryName : nom lisible de la categorie INITIALIZE }
{ ------------------------------------------------------------ }

Function MvtInitCategoryName(Cat : Integer) : TString;
Begin
  Case Cat Of
    INI_NONE         : MvtInitCategoryName := 'NONE';
    INI_ALPHA_SPACES : MvtInitCategoryName := 'ALPHA->SPACES';
    INI_NUM_ZEROS    : MvtInitCategoryName := 'NUM->ZEROS';
    INI_REPLACING    : MvtInitCategoryName := 'REPLACING';
  Else
    MvtInitCategoryName := 'INCONNU(' + ItoSI(Cat) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ MvtSetCategoryName : nom lisible de la categorie SET         }
{ ------------------------------------------------------------ }

Function MvtSetCategoryName(Cat : Integer) : TString;
Begin
  Case Cat Of
    SET_NONE       : MvtSetCategoryName := 'NONE';
    SET_COND_TRUE  : MvtSetCategoryName := 'COND-88 TRUE';
    SET_COND_FALSE : MvtSetCategoryName := 'COND-88 FALSE';
  Else
    MvtSetCategoryName := 'INCONNU(' + ItoSI(Cat) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ DetermineMovCategory : determiner la categorie de transfert  }
{ selon les types COBOL de la source et de la destination       }
{ ------------------------------------------------------------ }

Function DetermineMovCategory(SrcType, DstType : Integer) : Integer;
Begin
  { Si un des deux est un groupe, transfert alphanumerique }
  If (SrcType = CBT_GROUP) Or (DstType = CBT_GROUP) Then
    DetermineMovCategory := MOV_GROUP_TO_GROUP
  Else If (SrcType = CBT_ALPHA) Or (SrcType = CBT_ALPHANUMERIC) Or
          (SrcType = CBT_EDITED_ALPHA) Then Begin
    If (DstType = CBT_ALPHA) Or (DstType = CBT_ALPHANUMERIC) Or
       (DstType = CBT_EDITED_ALPHA) Then
      DetermineMovCategory := MOV_ALPHA_TO_ALPHA
    Else If (DstType = CBT_NUMERIC) Or (DstType = CBT_PACKED) Or
            (DstType = CBT_BINARY) Or (DstType = CBT_EDITED_NUM) Then
      DetermineMovCategory := MOV_ALPHA_TO_NUM
    Else
      DetermineMovCategory := MOV_ALPHA_TO_ALPHA;
  End
  Else If (SrcType = CBT_NUMERIC) Or (SrcType = CBT_PACKED) Or
          (SrcType = CBT_BINARY) Or (SrcType = CBT_EDITED_NUM) Or
          (SrcType = CBT_COMP1) Or (SrcType = CBT_COMP2) Then Begin
    If (DstType = CBT_NUMERIC) Or (DstType = CBT_PACKED) Or
       (DstType = CBT_BINARY) Or (DstType = CBT_EDITED_NUM) Or
       (DstType = CBT_COMP1) Or (DstType = CBT_COMP2) Then
      DetermineMovCategory := MOV_NUM_TO_NUM
    Else
      DetermineMovCategory := MOV_NUM_TO_ALPHA;
  End
  Else
    DetermineMovCategory := MOV_ALPHA_TO_ALPHA;
End;

{ ------------------------------------------------------------ }
{ GenMoveAlphaToAlpha : generer le code 80386 pour un MOVE     }
{ alphanumerique vers alphanumerique                            }
{   LEA ESI, [source]                                           }
{   LEA EDI, [destination]                                      }
{   MOV ECX, taille_dest                                        }
{   CLD                                                         }
{   REP MOVSB     ; copie min(src_len, dst_len) octets          }
{   Si src < dst : remplir le reste avec des espaces (STOSB)    }
{ ------------------------------------------------------------ }

Procedure GenMoveAlphaToAlpha(Src, Dst : TString; SrcLen, DstLen : Integer);
Begin
  WriteLn('; MOVE alpha->alpha ', Src, ' TO ', Dst);
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EDI, [', Dst, ']');
  If SrcLen >= DstLen Then Begin
    { Source plus longue ou egale : copie exacte, troncature }
    WriteLn('  MOV ECX, ', DstLen);
    WriteLn('  CLD');
    WriteLn('  REP MOVSB');
    If SrcLen > DstLen Then
      Inc(MvtTruncateCount);
  End
  Else Begin
    { Source plus courte : copie + padding espaces }
    WriteLn('  MOV ECX, ', SrcLen);
    WriteLn('  CLD');
    WriteLn('  REP MOVSB');
    WriteLn('  MOV AL, 32');   { espace = $20 }
    WriteLn('  MOV ECX, ', DstLen - SrcLen);
    WriteLn('  REP STOSB');
    Inc(MvtPaddingCount);
  End;
  Inc(MvtMoveAlphaAlpha);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveNumToNum : generer le code 80386 pour un MOVE         }
{ numerique vers numerique (alignement sur point decimal)       }
{   Charger la valeur source dans EAX                           }
{   Ajuster les decimales si necessaire                         }
{   Stocker dans la destination                                 }
{ ------------------------------------------------------------ }

Procedure GenMoveNumToNum(Src, Dst : TString; SrcSize, DstSize : Integer;
                          SrcDec, DstDec : Integer);
Begin
  WriteLn('; MOVE num->num ', Src, ' TO ', Dst);
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EDI, [', Dst, ']');
  { Charger la source en tant que nombre }
  WriteLn('  CALL ', PFX_RT, 'LOAD_NUM');
  { Ajuster les decimales : multiplier ou diviser par 10 }
  If SrcDec < DstDec Then Begin
    WriteLn('  ; ajuster decimales: ', SrcDec, ' -> ', DstDec);
    WriteLn('  MOV ECX, ', DstDec - SrcDec);
    WriteLn('  CALL ', PFX_RT, 'SCALE_UP');
  End
  Else If SrcDec > DstDec Then Begin
    WriteLn('  ; ajuster decimales: ', SrcDec, ' -> ', DstDec);
    WriteLn('  MOV ECX, ', SrcDec - DstDec);
    WriteLn('  CALL ', PFX_RT, 'SCALE_DOWN');
    Inc(MvtTruncateCount);
  End;
  { Stocker dans la destination }
  WriteLn('  CALL ', PFX_RT, 'STORE_NUM');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  Inc(MvtMoveNumNum);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveNumToAlpha : generer le code 80386 pour un MOVE       }
{ numerique vers alphanumerique (conversion en chaine)          }
{ ------------------------------------------------------------ }

Procedure GenMoveNumToAlpha(Src, Dst : TString; SrcSize, DstLen : Integer);
Begin
  WriteLn('; MOVE num->alpha ', Src, ' TO ', Dst);
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', DstLen);
  WriteLn('  CALL ', PFX_RT, 'NUM_TO_ALPHA');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  Inc(MvtMoveNumAlpha);
  Inc(MvtConversionCount);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveAlphaToNum : generer le code 80386 pour un MOVE       }
{ alphanumerique vers numerique (conversion numerique)          }
{ ------------------------------------------------------------ }

Procedure GenMoveAlphaToNum(Src, Dst : TString; SrcLen, DstSize : Integer);
Begin
  WriteLn('; MOVE alpha->num ', Src, ' TO ', Dst);
  WriteLn('  PUSH ESI');
  WriteLn('  PUSH EDI');
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  WriteLn('  CALL ', PFX_RT, 'ALPHA_TO_NUM');
  WriteLn('  POP EDI');
  WriteLn('  POP ESI');
  Inc(MvtMoveAlphaNum);
  Inc(MvtConversionCount);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveGroupToGroup : generer le code 80386 pour un MOVE     }
{ groupe vers groupe (transfert alphanumerique simple)          }
{ ------------------------------------------------------------ }

Procedure GenMoveGroupToGroup(Src, Dst : TString; SrcLen, DstLen : Integer);
Begin
  WriteLn('; MOVE group->group ', Src, ' TO ', Dst);
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EDI, [', Dst, ']');
  If SrcLen >= DstLen Then Begin
    WriteLn('  MOV ECX, ', DstLen);
    WriteLn('  CLD');
    WriteLn('  REP MOVSB');
    If SrcLen > DstLen Then
      Inc(MvtTruncateCount);
  End
  Else Begin
    WriteLn('  MOV ECX, ', SrcLen);
    WriteLn('  CLD');
    WriteLn('  REP MOVSB');
    WriteLn('  MOV AL, 32');
    WriteLn('  MOV ECX, ', DstLen - SrcLen);
    WriteLn('  REP STOSB');
    Inc(MvtPaddingCount);
  End;
  Inc(MvtMoveGroupGroup);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveFigurative : generer le code 80386 pour un MOVE       }
{ d une constante figurative (SPACES, ZEROS, HIGH-VALUES...)   }
{   MOV AL, valeur_figurative                                   }
{   LEA EDI, [destination]                                      }
{   MOV ECX, taille_dest                                        }
{   CLD                                                         }
{   REP STOSB                                                   }
{ ------------------------------------------------------------ }

Procedure GenMoveFigurative(FigValue : Integer; Dst : TString; DstLen : Integer);
Begin
  WriteLn('; MOVE figurative TO ', Dst);
  WriteLn('  MOV AL, ', FigValue);
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', DstLen);
  WriteLn('  CLD');
  WriteLn('  REP STOSB');
  Inc(MvtMoveFigurative);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenMoveCorresponding : generer le code 80386 pour un MOVE    }
{ CORRESPONDING (transfert des champs de meme nom)             }
{ Appel a une routine runtime qui parcourt les groupes          }
{ ------------------------------------------------------------ }

Procedure GenMoveCorresponding(SrcGroup, DstGroup : TString);
Begin
  WriteLn('; MOVE CORRESPONDING ', SrcGroup, ' TO ', DstGroup);
  WriteLn('  LEA ESI, [', SrcGroup, ']');
  WriteLn('  LEA EDI, [', DstGroup, ']');
  WriteLn('  CALL ', PFX_RT, 'MOVE_CORR');
  Inc(MvtMoveCorrCount);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenInitAlpha : generer le code 80386 pour initialiser un     }
{ champ alphanumerique a SPACES                                 }
{ ------------------------------------------------------------ }

Procedure GenInitAlpha(Dst : TString; DstLen : Integer);
Begin
  WriteLn('; INITIALIZE alpha -> SPACES : ', Dst);
  WriteLn('  MOV AL, 32');        { espace = $20 }
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', DstLen);
  WriteLn('  CLD');
  WriteLn('  REP STOSB');
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenInitNumeric : generer le code 80386 pour initialiser un   }
{ champ numerique a ZEROS                                       }
{ ------------------------------------------------------------ }

Procedure GenInitNumeric(Dst : TString; DstLen : Integer);
Begin
  WriteLn('; INITIALIZE numeric -> ZEROS : ', Dst);
  WriteLn('  MOV AL, 48');        { zero ASCII = $30 }
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', DstLen);
  WriteLn('  CLD');
  WriteLn('  REP STOSB');
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenInitGroup : generer le code 80386 pour initialiser un     }
{ groupe entier (chaque sous-champ selon sa categorie)          }
{ ------------------------------------------------------------ }

Procedure GenInitGroup(Dst : TString; DstLen : Integer);
Begin
  WriteLn('; INITIALIZE group : ', Dst);
  WriteLn('  LEA EDI, [', Dst, ']');
  WriteLn('  MOV ECX, ', DstLen);
  WriteLn('  CALL ', PFX_RT, 'INIT_GROUP');
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ GenSetCondition88 : generer le code 80386 pour               }
{ SET condition-88 TO TRUE                                      }
{ -> MOVE premiere valeur du 88 TO variable-parent              }
{ ------------------------------------------------------------ }

Procedure GenSetCondition88(CondName, ParentName, Value : TString;
                            ParentLen : Integer);
Begin
  WriteLn('; SET ', CondName, ' TO TRUE -> MOVE ', Value, ' TO ', ParentName);
  WriteLn('  LEA ESI, [', Value, ']');
  WriteLn('  LEA EDI, [', ParentName, ']');
  WriteLn('  MOV ECX, ', ParentLen);
  WriteLn('  CLD');
  WriteLn('  REP MOVSB');
  Inc(MvtSetCondCount);
  Inc(MvtTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ FigurativeByteValue : retourne la valeur d octet pour        }
{ une constante figurative COBOL                                }
{ ------------------------------------------------------------ }

Function FigurativeByteValue(KwCode : Integer) : Integer;
Begin
  Case KwCode Of
    KW_SPACES      : FigurativeByteValue := 32;    { espace }
    KW_ZEROS       : FigurativeByteValue := 48;    { zero ASCII }
    KW_HIGH_VALUES : FigurativeByteValue := 255;   { $FF }
    KW_LOW_VALUES  : FigurativeByteValue := 0;     { $00 }
  Else
    FigurativeByteValue := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseMoveStatement : parser une instruction MOVE              }
{   MOVE source TO dest-1 [dest-2 ...]                          }
{   MOVE CORRESPONDING groupe-1 TO groupe-2                     }
{ ------------------------------------------------------------ }

Procedure ParseMoveStatement;
Var
  SrcName    : TString;
  DstName    : TString;
  IsFig      : Boolean;
  IsCorr     : Boolean;
  FigKw      : Integer;
  DestCount  : Integer;
Begin
  Inc(MvtStateCount);
  Inc(MvtMoveCount);

  { On est positionne sur le token apres MOVE }
  LexNextToken;

  { Verifier CORRESPONDING / CORR }
  IsCorr := False;
  If (CurTokType = TOK_KEYWORD) And
     ((CurTokNum = KW_CORRESPONDING) Or (CurTokNum = KW_CORR)) Then Begin
    IsCorr := True;
    LexNextToken;
  End;

  { Lire la source }
  IsFig := False;
  FigKw := 0;
  If CurTokType = TOK_KEYWORD Then Begin
    { Constante figurative ? }
    If (CurTokNum = KW_SPACES) Or (CurTokNum = KW_ZEROS) Or
       (CurTokNum = KW_HIGH_VALUES) Or (CurTokNum = KW_LOW_VALUES) Then Begin
      IsFig := True;
      FigKw := CurTokNum;
      SrcName := KeywordName(CurTokNum);
    End
    Else If CurTokNum = KW_ALL Then Begin
      { ALL 'x' : lire le litteral suivant }
      LexNextToken;
      IsFig := True;
      FigKw := KW_ALL;
      SrcName := 'ALL ' + CurTokStr;
    End
    Else
      SrcName := CurTokStr;
  End
  Else
    SrcName := CurTokStr;

  LexNextToken;

  { Attendre TO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken
  Else
    WarnMsg('MOVE : TO attendu');

  { Lire les destinations (une ou plusieurs) }
  DestCount := 0;
  While (CurTokType = TOK_IDENT) Or
        ((CurTokType = TOK_KEYWORD) And (CurTokNum >= 80)) Do Begin
    DstName := CurTokStr;
    Inc(DestCount);

    If IsCorr Then
      GenMoveCorresponding(SrcName, DstName)
    Else If IsFig Then Begin
      { Constante figurative : on utilise STOSB }
      If FigKw = KW_ALL Then
        WriteLn('; MOVE ALL (runtime) TO ', DstName)
      Else
        GenMoveFigurative(FigurativeByteValue(FigKw), DstName, 1);
    End
    Else Begin
      { MOVE normal : determiner la categorie selon les types }
      { Pour l instant, generer un appel runtime generique    }
      WriteLn('; MOVE ', SrcName, ' TO ', DstName);
      WriteLn('  LEA ESI, [', AsmIdent(SrcName), ']');
      WriteLn('  LEA EDI, [', AsmIdent(DstName), ']');
      WriteLn('  CALL ', PFX_RT, 'MOVE_GENERIC');
      Inc(MvtTotalGenerated);
    End;

    LexNextToken;

    { Si le token suivant n est pas un identifiant, on arrete }
    If (CurTokType <> TOK_IDENT) Then
      Break;
  End;

  If DestCount > 1 Then
    Inc(MvtMultiDestCount);

  If Opts.Verbose Then
    WriteLn('  [MOVE] source=', SrcName,
            ' destinations=', DestCount,
            ' corr=', IsCorr,
            ' fig=', IsFig);
End;

{ ------------------------------------------------------------ }
{ ParseInitializeStatement : parser une instruction INITIALIZE  }
{   INITIALIZE id-1 [id-2 ...]                                  }
{     [REPLACING category BY literal/id]                         }
{ ------------------------------------------------------------ }

Procedure ParseInitializeStatement;
Var
  IdName    : TString;
  IdCount   : Integer;
  HasRepl   : Boolean;
  ReplCount : Integer;
Begin
  Inc(MvtStateCount);
  Inc(MvtInitializeCount);

  { On est positionne sur le token apres INITIALIZE }
  LexNextToken;

  { Lire les identificateurs a initialiser }
  IdCount := 0;
  While (CurTokType = TOK_IDENT) Or
        ((CurTokType = TOK_KEYWORD) And (CurTokNum >= 80)) Do Begin
    IdName := CurTokStr;
    Inc(IdCount);

    { Generer le code d initialisation generique }
    WriteLn('; INITIALIZE ', IdName);
    WriteLn('  LEA EDI, [', AsmIdent(IdName), ']');
    WriteLn('  CALL ', PFX_RT, 'INITIALIZE');
    Inc(MvtTotalGenerated);

    LexNextToken;

    { Verifier si c est REPLACING ou un autre identifiant }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_REPLACING) Then
      Break;
    If CurTokType <> TOK_IDENT Then
      Break;
  End;

  { Clause REPLACING optionnelle }
  HasRepl := False;
  ReplCount := 0;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_REPLACING) Then Begin
    HasRepl := True;
    { Parser REPLACING category BY literal/id }
    While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_REPLACING) Do Begin
      LexNextToken;
      { Lire la categorie : ALPHABETIC, ALPHANUMERIC, NUMERIC, etc. }
      If (CurTokType = TOK_KEYWORD) Or (CurTokType = TOK_IDENT) Then Begin
        WriteLn(';   REPLACING ', CurTokStr);
        LexNextToken;
      End;
      { Attendre BY }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then Begin
        LexNextToken;
        { Lire le litteral ou identifiant de remplacement }
        WriteLn(';   BY ', CurTokStr);
        LexNextToken;
      End;
      Inc(ReplCount);
      Inc(MvtInitReplacCount);
    End;
  End;

  If Opts.Verbose Then
    WriteLn('  [INITIALIZE] ids=', IdCount,
            ' replacing=', HasRepl,
            ' replCount=', ReplCount);
End;

{ ------------------------------------------------------------ }
{ ParseSetStatement : parser une instruction SET pour           }
{ niveaux 88 (conditions)                                        }
{   SET condition-88 TO TRUE                                     }
{   -> MOVE premiere-valeur TO variable-parent                   }
{ ------------------------------------------------------------ }

Procedure ParseSetStatement;
Var
  CondName : TString;
Begin
  Inc(MvtStateCount);

  { On est positionne sur le token apres SET }
  LexNextToken;

  { Lire le nom de la condition 88 }
  CondName := CurTokStr;
  LexNextToken;

  { Attendre TO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken
  Else
    WarnMsg('SET : TO attendu');

  { Attendre TRUE }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRUE) Then Begin
    WriteLn('; SET ', CondName, ' TO TRUE');
    WriteLn('  LEA EDI, [', AsmIdent(CondName), ']');
    WriteLn('  CALL ', PFX_RT, 'SET_COND_TRUE');
    Inc(MvtSetCondCount);
    Inc(MvtTotalGenerated);
    LexNextToken;
  End
  Else
    WarnMsg('SET : TRUE attendu (seul SET ... TO TRUE supporte)');

  If Opts.Verbose Then
    WriteLn('  [SET] condition=', CondName, ' TO TRUE');
End;

{ ------------------------------------------------------------ }
{ ParseMoveTransferStatement : dispatcher MOVE/INITIALIZE/SET  }
{ ------------------------------------------------------------ }

Procedure ParseMoveTransferStatement;
Begin
  If (CurTokType = TOK_KEYWORD) Then Begin
    Case CurTokNum Of
      KW_MOVE       : ParseMoveStatement;
      KW_INITIALIZE : ParseInitializeStatement;
      KW_SET        : ParseSetStatement;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsMoveKeyword : tester si le mot-cle courant est un          }
{ mot-cle de transfert de donnees (MOVE/INITIALIZE/SET)        }
{ ------------------------------------------------------------ }

Function IsMoveKeyword(Kw : Integer) : Boolean;
Begin
  IsMoveKeyword := (Kw = KW_MOVE) Or
                   (Kw = KW_INITIALIZE) Or
                   (Kw = KW_SET);
End;

{ ------------------------------------------------------------ }
{ DumpMoveState : afficher l etat du module MOVE/INITIALIZE    }
{ ------------------------------------------------------------ }

Procedure DumpMoveState;
Begin
  WriteLn('--- Etat module MOVE/INITIALIZE ---');
  WriteLn('  Initialise          : ', MvtInitialized);
  WriteLn('  MOVE total          : ', MvtMoveCount);
  WriteLn('  MOVE alpha->alpha   : ', MvtMoveAlphaAlpha);
  WriteLn('  MOVE num->num       : ', MvtMoveNumNum);
  WriteLn('  MOVE num->alpha     : ', MvtMoveNumAlpha);
  WriteLn('  MOVE alpha->num     : ', MvtMoveAlphaNum);
  WriteLn('  MOVE group->group   : ', MvtMoveGroupGroup);
  WriteLn('  MOVE figurative     : ', MvtMoveFigurative);
  WriteLn('  MOVE CORRESPONDING  : ', MvtMoveCorrCount);
  WriteLn('  Destinations mult.  : ', MvtMultiDestCount);
  WriteLn('  INITIALIZE          : ', MvtInitializeCount);
  WriteLn('  REPLACING clauses   : ', MvtInitReplacCount);
  WriteLn('  SET condition-88    : ', MvtSetCondCount);
  WriteLn('  Troncatures         : ', MvtTruncateCount);
  WriteLn('  Remplissages        : ', MvtPaddingCount);
  WriteLn('  Conversions type    : ', MvtConversionCount);
  WriteLn('  Total genere        : ', MvtTotalGenerated);
End;

{ 10 fonctions accesseurs pour TODO 12                         }

Function IsMvtInitialized : Boolean;
Begin
  IsMvtInitialized := MvtInitialized;
End;

Function IsMvtEmpty : Boolean;
Begin
  IsMvtEmpty := (MvtTotalGenerated = 0);
End;

Function GetMvtTotalGenerated : Integer;
Begin
  GetMvtTotalGenerated := MvtTotalGenerated;
End;

Function GetMvtStatus : TString;
Begin
  If Not MvtInitialized Then
    GetMvtStatus := 'NON INITIALISE'
  Else
    GetMvtStatus := 'MOVE=' + ItoSI(MvtMoveCount) +
                    ' INIT=' + ItoSI(MvtInitializeCount) +
                    ' SET88=' + ItoSI(MvtSetCondCount) +
                    ' CORR=' + ItoSI(MvtMoveCorrCount) +
                    ' CONV=' + ItoSI(MvtConversionCount);
End;

Function GetMvtMoveCount : Integer;
Begin
  GetMvtMoveCount := MvtMoveCount;
End;

Function GetMvtInitializeCount : Integer;
Begin
  GetMvtInitializeCount := MvtInitializeCount;
End;

Function GetMvtSetCondCount : Integer;
Begin
  GetMvtSetCondCount := MvtSetCondCount;
End;

Function GetMvtCorrCount : Integer;
Begin
  GetMvtCorrCount := MvtMoveCorrCount;
End;

Function GetMvtConversionCount : Integer;
Begin
  GetMvtConversionCount := MvtConversionCount;
End;

Function GetMvtStateCount : Integer;
Begin
  GetMvtStateCount := MvtStateCount;
End;


{ ============================================================ }
{ TODO 13 - PARSEUR : OPERATIONS SUR CHAINES                   }
{           STRING, UNSTRING, INSPECT, sous-chaines             }
{ ============================================================ }

Const
  { Types d operations STRING }
  SOP_NONE             = 0;   { pas d operation en cours                  }
  SOP_STRING           = 1;   { concatenation STRING                      }
  SOP_UNSTRING         = 2;   { decomposition UNSTRING                    }
  SOP_INSPECT_TALLY    = 3;   { INSPECT TALLYING                          }
  SOP_INSPECT_REPLACE  = 4;   { INSPECT REPLACING                         }
  SOP_INSPECT_CONVERT  = 5;   { INSPECT CONVERTING                        }
  SOP_SUBSTRING_REF    = 6;   { reference de sous-chaine id(pos:len)      }

  { Types de recherche INSPECT }
  ISP_ALL              = 0;   { compter/remplacer toutes les occurrences  }
  ISP_LEADING          = 1;   { compter/remplacer les premieres           }
  ISP_FIRST            = 2;   { remplacer la premiere seulement           }
  ISP_CHARACTERS       = 3;   { tous les caracteres                       }

  { Types de borne BEFORE/AFTER }
  ISB_NONE             = 0;   { pas de borne                              }
  ISB_BEFORE           = 1;   { BEFORE INITIAL                            }
  ISB_AFTER            = 2;   { AFTER INITIAL                             }

  { Limites }
  STR_MAX_SOURCES      = 16;  { max de sources pour STRING                }
  STR_MAX_DELIMITERS   = 16;  { max de delimiteurs pour UNSTRING          }
  STR_MAX_DESTINATIONS = 16;  { max de destinations pour UNSTRING         }
  STR_MAX_TALLY_CLAUSES = 8;  { max de clauses TALLYING FOR               }
  STR_MAX_REPLACE_CLAUSES = 8; { max de clauses REPLACING                 }

Var
  StrInitialized       : Boolean;   { True si InitStringState appele         }
  StrStateCount        : Integer;   { compteur d etat general                }
  StrLabelNum          : Integer;   { compteur de labels internes            }
  StrStringCount       : Integer;   { nombre de STRING                       }
  StrUnstringCount     : Integer;   { nombre de UNSTRING                     }
  StrInspectTallyCount : Integer;   { nombre de INSPECT TALLYING             }
  StrInspectReplCount  : Integer;   { nombre de INSPECT REPLACING            }
  StrInspectConvCount  : Integer;   { nombre de INSPECT CONVERTING           }
  StrSubstringRefCount : Integer;   { nombre de references sous-chaine       }
  StrPointerCount      : Integer;   { nombre de clauses WITH POINTER         }
  StrOverflowCount     : Integer;   { nombre de clauses ON OVERFLOW          }
  StrDelimitedCount    : Integer;   { nombre de clauses DELIMITED BY         }
  StrTallyingCount     : Integer;   { nombre de clauses TALLYING IN          }
  StrBeforeAfterCount  : Integer;   { nombre de clauses BEFORE/AFTER         }
  StrAllCount          : Integer;   { nombre de qualificatifs ALL            }
  StrLeadingCount      : Integer;   { nombre de qualificatifs LEADING        }
  StrFirstCount        : Integer;   { nombre de qualificatifs FIRST          }
  StrCharactersCount   : Integer;   { nombre de qualificatifs CHARACTERS     }
  StrTotalGenerated    : Integer;   { total d instructions generees          }

{ ------------------------------------------------------------ }
{ InitStringState : initialiser l etat du module STRING/INSPECT }
{ ------------------------------------------------------------ }

Procedure InitStringState;
Begin
  StrInitialized       := True;
  StrStateCount        := 0;
  StrLabelNum          := 0;
  StrStringCount       := 0;
  StrUnstringCount     := 0;
  StrInspectTallyCount := 0;
  StrInspectReplCount  := 0;
  StrInspectConvCount  := 0;
  StrSubstringRefCount := 0;
  StrPointerCount      := 0;
  StrOverflowCount     := 0;
  StrDelimitedCount    := 0;
  StrTallyingCount     := 0;
  StrBeforeAfterCount  := 0;
  StrAllCount          := 0;
  StrLeadingCount      := 0;
  StrFirstCount        := 0;
  StrCharactersCount   := 0;
  StrTotalGenerated    := 0;
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ GenStrLabel : genere un label unique pour le module STRING    }
{ ------------------------------------------------------------ }

Function GenStrLabel : TString;
Begin
  Inc(StrLabelNum);
  GenStrLabel := '_COBSTR_' + ItoSI(StrLabelNum);
End;

{ ------------------------------------------------------------ }
{ StrOpTypeName : retourne le nom d un type d operation chaine }
{ ------------------------------------------------------------ }

Function StrOpTypeName(OpType : Integer) : TString;
Begin
  Case OpType Of
    SOP_NONE            : StrOpTypeName := 'NONE';
    SOP_STRING          : StrOpTypeName := 'STRING';
    SOP_UNSTRING        : StrOpTypeName := 'UNSTRING';
    SOP_INSPECT_TALLY   : StrOpTypeName := 'INSPECT-TALLYING';
    SOP_INSPECT_REPLACE : StrOpTypeName := 'INSPECT-REPLACING';
    SOP_INSPECT_CONVERT : StrOpTypeName := 'INSPECT-CONVERTING';
    SOP_SUBSTRING_REF   : StrOpTypeName := 'SUBSTRING-REF';
  Else
    StrOpTypeName := '?SOP' + ItoSI(OpType);
  End;
End;

{ ------------------------------------------------------------ }
{ InspectTypeName : retourne le nom d un type de recherche     }
{ ------------------------------------------------------------ }

Function InspectTypeName(IType : Integer) : TString;
Begin
  Case IType Of
    ISP_ALL        : InspectTypeName := 'ALL';
    ISP_LEADING    : InspectTypeName := 'LEADING';
    ISP_FIRST      : InspectTypeName := 'FIRST';
    ISP_CHARACTERS : InspectTypeName := 'CHARACTERS';
  Else
    InspectTypeName := '?ISP' + ItoSI(IType);
  End;
End;

{ ------------------------------------------------------------ }
{ BoundTypeName : retourne le nom d un type de borne           }
{ ------------------------------------------------------------ }

Function BoundTypeName(BType : Integer) : TString;
Begin
  Case BType Of
    ISB_NONE   : BoundTypeName := 'NONE';
    ISB_BEFORE : BoundTypeName := 'BEFORE';
    ISB_AFTER  : BoundTypeName := 'AFTER';
  Else
    BoundTypeName := '?ISB' + ItoSI(BType);
  End;
End;

{ ------------------------------------------------------------ }
{ GenStringConcat : genere le code 80386 pour STRING            }
{   Appelle la routine runtime _COBRT_STRING_CONCAT             }
{   ECX = pointeur destination, EDX = taille destination        }
{   ESI = pointeur source, EDI = taille source                  }
{   Gere la concatenation sequentielle avec pointeur            }
{ ------------------------------------------------------------ }

Procedure GenStringConcat(Const Src, Dest : TString; SrcLen, DestLen : Integer);
Begin
  WriteLn(';   STRING ', Src, ' INTO ', Dest);
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  WriteLn('  LEA EDI, [', Dest, ']');
  WriteLn('  MOV EDX, ', DestLen);
  WriteLn('  CALL _COBRT_STRING_CONCAT');
  Inc(StrTotalGenerated, 5);
End;

{ ------------------------------------------------------------ }
{ GenStringDelimited : genere le code pour STRING DELIMITED BY }
{   Copie la source jusqu au delimiteur dans la destination     }
{   ESI = source, ECX = taille source, EBX = delimiteur        }
{ ------------------------------------------------------------ }

Procedure GenStringDelimited(Const Src, Delim, Dest : TString);
Begin
  WriteLn(';   STRING ', Src, ' DELIMITED BY ', Delim);
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  LEA EBX, [', Delim, ']');
  WriteLn('  LEA EDI, [', Dest, ']');
  WriteLn('  CALL _COBRT_STRING_DELIMITED');
  Inc(StrTotalGenerated, 4);
End;

{ ------------------------------------------------------------ }
{ GenStringPointer : genere le code pour WITH POINTER           }
{   Charge le pointeur de position dans EAX                     }
{ ------------------------------------------------------------ }

Procedure GenStringPointer(Const PtrVar : TString);
Begin
  WriteLn(';   WITH POINTER ', PtrVar);
  WriteLn('  MOV EAX, [', PtrVar, ']');
  WriteLn('  DEC EAX');
  WriteLn('  ADD EDI, EAX');
  Inc(StrTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenStringPointerUpdate : met a jour le pointeur apres STRING }
{ ------------------------------------------------------------ }

Procedure GenStringPointerUpdate(Const PtrVar : TString);
Begin
  WriteLn(';   mise a jour POINTER ', PtrVar);
  WriteLn('  INC EAX');
  WriteLn('  MOV [', PtrVar, '], EAX');
  Inc(StrTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenStringOverflowCheck : genere le test ON OVERFLOW           }
{   Compare la position actuelle avec la taille destination     }
{ ------------------------------------------------------------ }

Procedure GenStringOverflowCheck(Const LblOverflow, LblEnd : TString);
Begin
  WriteLn(';   ON OVERFLOW check');
  WriteLn('  CMP EAX, EDX');
  WriteLn('  JG ', LblOverflow);
  WriteLn('  JMP ', LblEnd);
  WriteLn(LblOverflow, ':');
  Inc(StrTotalGenerated, 4);
End;

{ ------------------------------------------------------------ }
{ GenUnstringSource : genere le code pour UNSTRING source       }
{   Prepare la source pour decomposition                        }
{ ------------------------------------------------------------ }

Procedure GenUnstringSource(Const Src : TString; SrcLen : Integer);
Begin
  WriteLn(';   UNSTRING ', Src);
  WriteLn('  LEA ESI, [', Src, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  Inc(StrTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenUnstringDelimitedBy : genere le code DELIMITED BY          }
{   Cherche le delimiteur dans la source                        }
{ ------------------------------------------------------------ }

Procedure GenUnstringDelimitedBy(Const Delim : TString; IsOr : Boolean);
Begin
  If IsOr Then
    WriteLn(';   OR DELIMITED BY ', Delim)
  Else
    WriteLn(';   DELIMITED BY ', Delim);
  WriteLn('  LEA EBX, [', Delim, ']');
  WriteLn('  CALL _COBRT_UNSTRING_FIND_DELIM');
  Inc(StrTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenUnstringInto : genere le code INTO pour UNSTRING           }
{   Copie le segment dans la destination                        }
{ ------------------------------------------------------------ }

Procedure GenUnstringInto(Const Dest : TString; DestLen : Integer);
Begin
  WriteLn(';   INTO ', Dest);
  WriteLn('  LEA EDI, [', Dest, ']');
  WriteLn('  MOV EDX, ', DestLen);
  WriteLn('  CALL _COBRT_UNSTRING_COPY_SEGMENT');
  Inc(StrTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenUnstringDelimiterIn : genere DELIMITER IN pour UNSTRING    }
{ ------------------------------------------------------------ }

Procedure GenUnstringDelimiterIn(Const DelimVar : TString);
Begin
  WriteLn(';   DELIMITER IN ', DelimVar);
  WriteLn('  LEA EDI, [', DelimVar, ']');
  WriteLn('  CALL _COBRT_UNSTRING_STORE_DELIM');
  Inc(StrTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenUnstringCountIn : genere COUNT IN pour UNSTRING            }
{ ------------------------------------------------------------ }

Procedure GenUnstringCountIn(Const CntVar : TString);
Begin
  WriteLn(';   COUNT IN ', CntVar);
  WriteLn('  MOV [', CntVar, '], EAX');
  Inc(StrTotalGenerated, 1);
End;

{ ------------------------------------------------------------ }
{ GenUnstringTallyingIn : genere TALLYING IN pour UNSTRING      }
{ ------------------------------------------------------------ }

Procedure GenUnstringTallyingIn(Const TallyVar : TString);
Begin
  WriteLn(';   TALLYING IN ', TallyVar);
  WriteLn('  INC DWORD PTR [', TallyVar, ']');
  Inc(StrTotalGenerated, 1);
End;

{ ------------------------------------------------------------ }
{ GenInspectTallying : genere le code pour INSPECT TALLYING     }
{   Compte les occurrences d un motif dans la chaine            }
{ ------------------------------------------------------------ }

Procedure GenInspectTallying(Const Source, Counter, Pattern : TString;
                              SrcLen : Integer; SearchType : Integer);
Begin
  WriteLn(';   INSPECT ', Source, ' TALLYING ', Counter,
          ' FOR ', InspectTypeName(SearchType), ' ', Pattern);
  WriteLn('  LEA ESI, [', Source, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  WriteLn('  LEA EBX, [', Pattern, ']');
  WriteLn('  MOV EDX, ', SearchType);
  WriteLn('  CALL _COBRT_INSPECT_TALLY');
  WriteLn('  ADD [', Counter, '], EAX');
  Inc(StrTotalGenerated, 6);
End;

{ ------------------------------------------------------------ }
{ GenInspectBeforeAfter : genere la borne BEFORE/AFTER INITIAL }
{ ------------------------------------------------------------ }

Procedure GenInspectBeforeAfter(Const Bound : TString; BoundType : Integer);
Begin
  WriteLn(';   ', BoundTypeName(BoundType), ' INITIAL ', Bound);
  WriteLn('  LEA EDX, [', Bound, ']');
  WriteLn('  MOV EAX, ', BoundType);
  WriteLn('  CALL _COBRT_INSPECT_SET_BOUND');
  Inc(StrTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenInspectReplacing : genere le code pour INSPECT REPLACING   }
{   Remplace les occurrences d un motif par un autre            }
{ ------------------------------------------------------------ }

Procedure GenInspectReplacing(Const Source, OldPat, NewPat : TString;
                               SrcLen : Integer; SearchType : Integer);
Begin
  WriteLn(';   INSPECT ', Source, ' REPLACING ',
          InspectTypeName(SearchType), ' ', OldPat, ' BY ', NewPat);
  WriteLn('  LEA ESI, [', Source, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  WriteLn('  LEA EBX, [', OldPat, ']');
  WriteLn('  LEA EDX, [', NewPat, ']');
  WriteLn('  PUSH ', SearchType);
  WriteLn('  CALL _COBRT_INSPECT_REPLACE');
  Inc(StrTotalGenerated, 6);
End;

{ ------------------------------------------------------------ }
{ GenInspectConverting : genere le code INSPECT CONVERTING      }
{   Convertit caractere par caractere selon une table           }
{ ------------------------------------------------------------ }

Procedure GenInspectConverting(Const Source, FromStr, ToStr : TString;
                                SrcLen : Integer);
Begin
  WriteLn(';   INSPECT ', Source, ' CONVERTING ', FromStr, ' TO ', ToStr);
  WriteLn('  LEA ESI, [', Source, ']');
  WriteLn('  MOV ECX, ', SrcLen);
  WriteLn('  LEA EBX, [', FromStr, ']');
  WriteLn('  LEA EDX, [', ToStr, ']');
  WriteLn('  CALL _COBRT_INSPECT_CONVERT');
  Inc(StrTotalGenerated, 5);
End;

{ ------------------------------------------------------------ }
{ GenSubstringRef : genere le code pour reference sous-chaine   }
{   id(position:longueur) -> calcule adresse + longueur         }
{ ------------------------------------------------------------ }

Procedure GenSubstringRef(Const Ident : TString; Pos, Len : Integer);
Begin
  WriteLn(';   reference sous-chaine ', Ident, '(', Pos, ':', Len, ')');
  WriteLn('  LEA ESI, [', Ident, ']');
  WriteLn('  ADD ESI, ', Pos - 1);
  WriteLn('  MOV ECX, ', Len);
  Inc(StrTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ ParseStringSourceClause : parse une clause source de STRING   }
{   source-n [DELIMITED BY delim-n | SIZE]                      }
{ ------------------------------------------------------------ }

Procedure ParseStringSourceClause;
Var
  SrcName  : TString;
  DelName  : TString;
  HasDelim : Boolean;
Begin
  { Lire l identifiant ou litteral source }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Or
     (CurTokType = TOK_INTEGER) Then
  Begin
    SrcName := CurTokStr;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('STRING: source attendue');
    Exit;
  End;

  { Verifier DELIMITED BY }
  HasDelim := False;
  DelName := '';
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DELIMITED) Then
  Begin
    LexNextToken;
    { Optionnel: BY }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
      LexNextToken;

    { SIZE ou un delimiteur specifique }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SIZE) Then
    Begin
      DelName := 'SIZE';
      LexNextToken;
    End
    Else If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
    Begin
      DelName := CurTokStr;
      LexNextToken;
    End;
    HasDelim := True;
    Inc(StrDelimitedCount);
  End;

  If HasDelim And (DelName <> 'SIZE') Then
    GenStringDelimited(SrcName, DelName, 'EDI')
  Else
    GenStringConcat(SrcName, 'EDI', 0, 0);

  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseStringStatement : parse l instruction STRING complete     }
{   STRING source-1 [DELIMITED BY delim-1]                      }
{          source-2 [DELIMITED BY delim-2] ...                  }
{     INTO destination                                          }
{     [WITH POINTER ptr]                                        }
{     [ON OVERFLOW instructions]                                }
{   END-STRING                                                  }
{ ------------------------------------------------------------ }

Procedure ParseStringStatement;
Var
  DestName  : TString;
  PtrName   : TString;
  HasPtr    : Boolean;
  LblOvf    : TString;
  LblEnd    : TString;
Begin
  Inc(StrStringCount);
  WriteLn('; STRING statement');
  LexNextToken;   { consommer STRING }

  { Parser les sources avec leurs delimiteurs }
  While Not LexEOF And
        (CurTokType <> TOK_KEYWORD) Or
        ((CurTokNum <> KW_INTO) And (CurTokNum <> KW_END_STRING) And
         (CurTokNum <> KW_ON)) Do
  Begin
    ParseStringSourceClause;
    If LexEOF Then Exit;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
      Break;
  End;

  { INTO destination }
  DestName := '';
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
  Begin
    LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      DestName := CurTokStr;
      LexNextToken;
    End;
  End;

  { WITH POINTER ptr }
  HasPtr := False;
  PtrName := '';
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_POINTER) Then
    Begin
      LexNextToken;
      If CurTokType = TOK_IDENT Then
      Begin
        PtrName := CurTokStr;
        HasPtr := True;
        Inc(StrPointerCount);
        LexNextToken;
      End;
    End;
  End;

  If HasPtr Then
    GenStringPointer(PtrName);

  { ON OVERFLOW instructions }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OVERFLOW) Then
    Begin
      LexNextToken;
      Inc(StrOverflowCount);
      LblOvf := GenStrLabel;
      LblEnd := GenStrLabel;
      GenStringOverflowCheck(LblOvf, LblEnd);
      { Les instructions de overflow seraient parsees ici }
      WriteLn(LblEnd, ':');
    End;
  End;

  If HasPtr Then
    GenStringPointerUpdate(PtrName);

  { END-STRING }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_STRING) Then
    LexNextToken;

  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseUnstringIntoClause : parse une clause INTO de UNSTRING   }
{   dest-n [DELIMITER IN d-n] [COUNT IN c-n]                    }
{ ------------------------------------------------------------ }

Procedure ParseUnstringIntoClause;
Var
  DestName  : TString;
  DelimName : TString;
  CntName   : TString;
Begin
  { Lire la destination }
  If CurTokType = TOK_IDENT Then
  Begin
    DestName := CurTokStr;
    LexNextToken;
    GenUnstringInto(DestName, 0);
  End
  Else
  Begin
    WarnMsg('UNSTRING INTO: destination attendue');
    Exit;
  End;

  { DELIMITER IN }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DELIMITER) Then
  Begin
    LexNextToken;
    { Optionnel: IN }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
      LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      DelimName := CurTokStr;
      GenUnstringDelimiterIn(DelimName);
      LexNextToken;
    End;
  End;

  { COUNT IN }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_COUNT) Then
  Begin
    LexNextToken;
    { Optionnel: IN }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
      LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      CntName := CurTokStr;
      GenUnstringCountIn(CntName);
      LexNextToken;
    End;
  End;

  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseUnstringStatement : parse l instruction UNSTRING          }
{   UNSTRING source                                             }
{     DELIMITED BY delim-1 [OR delim-2]                         }
{     INTO dest-1 [DELIMITER IN d-1] [COUNT IN c-1]             }
{          dest-2 ...                                           }
{     [WITH POINTER ptr]                                        }
{     [TALLYING IN compteur]                                    }
{     [ON OVERFLOW instructions]                                }
{   END-UNSTRING                                                }
{ ------------------------------------------------------------ }

Procedure ParseUnstringStatement;
Var
  SrcName : TString;
  PtrName : TString;
  TlyName : TString;
  LblOvf  : TString;
  LblEnd  : TString;
Begin
  Inc(StrUnstringCount);
  WriteLn('; UNSTRING statement');
  LexNextToken;   { consommer UNSTRING }

  { Source }
  SrcName := '';
  If CurTokType = TOK_IDENT Then
  Begin
    SrcName := CurTokStr;
    GenUnstringSource(SrcName, 0);
    LexNextToken;
  End;

  { DELIMITED BY }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DELIMITED) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
      LexNextToken;
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
    Begin
      GenUnstringDelimitedBy(CurTokStr, False);
      Inc(StrDelimitedCount);
      LexNextToken;
    End;

    { OR delim-2 [OR delim-3 ...] }
    While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OR) Do
    Begin
      LexNextToken;
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
      Begin
        GenUnstringDelimitedBy(CurTokStr, True);
        Inc(StrDelimitedCount);
        LexNextToken;
      End;
    End;
  End;

  { INTO destinations }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
  Begin
    LexNextToken;
    While Not LexEOF And (CurTokType = TOK_IDENT) Do
      ParseUnstringIntoClause;
  End;

  { WITH POINTER ptr }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_POINTER) Then
    Begin
      LexNextToken;
      If CurTokType = TOK_IDENT Then
      Begin
        PtrName := CurTokStr;
        GenStringPointer(PtrName);
        Inc(StrPointerCount);
        LexNextToken;
      End;
    End;
  End;

  { TALLYING IN compteur }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TALLYING) Then
  Begin
    LexNextToken;
    { Optionnel: IN }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTO) Then
      LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      TlyName := CurTokStr;
      GenUnstringTallyingIn(TlyName);
      Inc(StrTallyingCount);
      LexNextToken;
    End;
  End;

  { ON OVERFLOW }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ON) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_OVERFLOW) Then
    Begin
      LexNextToken;
      Inc(StrOverflowCount);
      LblOvf := GenStrLabel;
      LblEnd := GenStrLabel;
      GenStringOverflowCheck(LblOvf, LblEnd);
      WriteLn(LblEnd, ':');
    End;
  End;

  { END-UNSTRING }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_UNSTRING) Then
    LexNextToken;

  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseBeforeAfterClause : parse [BEFORE/AFTER INITIAL pattern] }
{ Retourne le type de borne (ISB_NONE/BEFORE/AFTER)            }
{ ------------------------------------------------------------ }

Function ParseBeforeAfterClause : Integer;
Var
  BType : Integer;
Begin
  BType := ISB_NONE;
  If (CurTokType = TOK_KEYWORD) And
     ((CurTokNum = KW_BEFORE) Or (CurTokNum = KW_AFTER)) Then
  Begin
    If CurTokNum = KW_BEFORE Then
      BType := ISB_BEFORE
    Else
      BType := ISB_AFTER;
    LexNextToken;

    { Optionnel: INITIAL }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INITIAL) Then
      LexNextToken;

    { Pattern de borne }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
    Begin
      GenInspectBeforeAfter(CurTokStr, BType);
      Inc(StrBeforeAfterCount);
      LexNextToken;
    End;
  End;
  ParseBeforeAfterClause := BType;
End;

{ ------------------------------------------------------------ }
{ ParseInspectTallyClause : parse FOR ALL/LEADING/CHARACTERS   }
{   FOR ALL/LEADING literal [BEFORE/AFTER INITIAL literal]      }
{   FOR CHARACTERS [BEFORE/AFTER INITIAL literal]               }
{ ------------------------------------------------------------ }

Procedure ParseInspectTallyClause(Const Source, Counter : TString;
                                   SrcLen : Integer);
Var
  SearchType : Integer;
  Pattern    : TString;
  Dummy      : Integer;
Begin
  { FOR }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FOR) Then
    LexNextToken
  Else
  Begin
    WarnMsg('INSPECT TALLYING: FOR attendu');
    Exit;
  End;

  { ALL, LEADING ou CHARACTERS }
  SearchType := ISP_ALL;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ALL) Then
  Begin
    SearchType := ISP_ALL;
    Inc(StrAllCount);
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_LEADING) Then
  Begin
    SearchType := ISP_LEADING;
    Inc(StrLeadingCount);
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CHARACTERS) Then
  Begin
    SearchType := ISP_CHARACTERS;
    Inc(StrCharactersCount);
    LexNextToken;
    { CHARACTERS n a pas de pattern: passe directement a BEFORE/AFTER }
    Dummy := ParseBeforeAfterClause;
    GenInspectTallying(Source, Counter, 'ALL_CHARS', SrcLen, SearchType);
    Exit;
  End;

  { Pattern a chercher }
  Pattern := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
  Begin
    Pattern := CurTokStr;
    LexNextToken;
  End;

  { BEFORE/AFTER INITIAL }
  Dummy := ParseBeforeAfterClause;

  GenInspectTallying(Source, Counter, Pattern, SrcLen, SearchType);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseInspectReplaceClause : parse ALL/LEADING/FIRST x BY y   }
{   ALL/LEADING/FIRST old BY new [BEFORE/AFTER INITIAL z]       }
{ ------------------------------------------------------------ }

Procedure ParseInspectReplaceClause(Const Source : TString;
                                     SrcLen : Integer);
Var
  SearchType : Integer;
  OldPat     : TString;
  NewPat     : TString;
  Dummy      : Integer;
Begin
  SearchType := ISP_ALL;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ALL) Then
  Begin
    SearchType := ISP_ALL;
    Inc(StrAllCount);
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_LEADING) Then
  Begin
    SearchType := ISP_LEADING;
    Inc(StrLeadingCount);
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FIRST) Then
  Begin
    SearchType := ISP_FIRST;
    Inc(StrFirstCount);
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CHARACTERS) Then
  Begin
    SearchType := ISP_CHARACTERS;
    Inc(StrCharactersCount);
    LexNextToken;
  End;

  { Ancien pattern }
  OldPat := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
  Begin
    OldPat := CurTokStr;
    LexNextToken;
  End;

  { BY }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
    LexNextToken;

  { Nouveau pattern }
  NewPat := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
  Begin
    NewPat := CurTokStr;
    LexNextToken;
  End;

  { BEFORE/AFTER INITIAL }
  Dummy := ParseBeforeAfterClause;

  GenInspectReplacing(Source, OldPat, NewPat, SrcLen, SearchType);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseInspectTallying : parse INSPECT id TALLYING              }
{   id-cnt FOR ALL/LEADING/CHARACTERS pattern                   }
{   [BEFORE/AFTER INITIAL bound] ...                            }
{ ------------------------------------------------------------ }

Procedure ParseInspectTallying(Const Source : TString; SrcLen : Integer);
Var
  Counter : TString;
Begin
  Inc(StrInspectTallyCount);
  WriteLn('; INSPECT TALLYING');

  { Identifiant compteur }
  Counter := '';
  If CurTokType = TOK_IDENT Then
  Begin
    Counter := CurTokStr;
    LexNextToken;
  End;

  { Parser les clauses FOR ... }
  While Not LexEOF And
        (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FOR) Do
  Begin
    ParseInspectTallyClause(Source, Counter, SrcLen);
    Inc(StrTallyingCount);
  End;

  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseInspectReplacing : parse INSPECT id REPLACING            }
{   ALL/LEADING/FIRST/CHARACTERS old BY new                     }
{   [BEFORE/AFTER INITIAL bound] ...                            }
{ ------------------------------------------------------------ }

Procedure ParseInspectReplacing(Const Source : TString; SrcLen : Integer);
Begin
  Inc(StrInspectReplCount);
  WriteLn('; INSPECT REPLACING');

  { Parser les clauses de remplacement }
  While Not LexEOF And
        (CurTokType = TOK_KEYWORD) And
        ((CurTokNum = KW_ALL) Or (CurTokNum = KW_LEADING) Or
         (CurTokNum = KW_FIRST) Or (CurTokNum = KW_CHARACTERS)) Do
    ParseInspectReplaceClause(Source, SrcLen);

  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseInspectConverting : parse INSPECT id CONVERTING          }
{   INSPECT id CONVERTING 'abc' TO 'xyz'                        }
{   [BEFORE/AFTER INITIAL bound]                                }
{ ------------------------------------------------------------ }

Procedure ParseInspectConverting(Const Source : TString; SrcLen : Integer);
Var
  FromStr : TString;
  ToStr   : TString;
  Dummy   : Integer;
Begin
  Inc(StrInspectConvCount);
  WriteLn('; INSPECT CONVERTING');

  { Chaine source de conversion }
  FromStr := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
  Begin
    FromStr := CurTokStr;
    LexNextToken;
  End;

  { TO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken;

  { Chaine destination de conversion }
  ToStr := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_STRING) Then
  Begin
    ToStr := CurTokStr;
    LexNextToken;
  End;

  { BEFORE/AFTER INITIAL }
  Dummy := ParseBeforeAfterClause;

  GenInspectConverting(Source, FromStr, ToStr, SrcLen);
  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseInspectStatement : parse l instruction INSPECT           }
{   INSPECT id TALLYING ...                                     }
{   INSPECT id REPLACING ...                                    }
{   INSPECT id CONVERTING ...                                   }
{ ------------------------------------------------------------ }

Procedure ParseInspectStatement;
Var
  Source  : TString;
Begin
  WriteLn('; INSPECT statement');
  LexNextToken;   { consommer INSPECT }

  { Identifiant a inspecter }
  Source := '';
  If CurTokType = TOK_IDENT Then
  Begin
    Source := CurTokStr;
    LexNextToken;
  End;

  { Determiner le type d INSPECT }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TALLYING) Then
  Begin
    LexNextToken;
    ParseInspectTallying(Source, 0);
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_REPLACING) Then
  Begin
    LexNextToken;
    ParseInspectReplacing(Source, 0);
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CONVERTING) Then
  Begin
    LexNextToken;
    ParseInspectConverting(Source, 0);
  End
  Else
    WarnMsg('INSPECT: TALLYING, REPLACING ou CONVERTING attendu');

  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseSubstringReference : parse reference sous-chaine         }
{   id(position:longueur) pour extraire/modifier                }
{   Appele apres avoir lu l identifiant et la parenthese        }
{ ------------------------------------------------------------ }

Procedure ParseSubstringReference(Const Ident : TString);
Var
  Pos : Integer;
  Len : Integer;
Begin
  Inc(StrSubstringRefCount);
  WriteLn('; reference sous-chaine ', Ident);

  { Position }
  Pos := 1;
  If CurTokType = TOK_INTEGER Then
  Begin
    Pos := CurTokNum;
    LexNextToken;
  End
  Else If CurTokType = TOK_IDENT Then
    LexNextToken;

  { Separateur : (deux-points) - dans le format COBOL, }
  { le ':' est traite comme un separateur special        }
  { On avance simplement si on trouve un token inconnu   }
  If (CurTokType <> TOK_INTEGER) And (CurTokType <> TOK_IDENT) And
     (CurTokType <> TOK_RPAREN) Then
    LexNextToken;

  { Longueur }
  Len := 0;
  If CurTokType = TOK_INTEGER Then
  Begin
    Len := CurTokNum;
    LexNextToken;
  End
  Else If CurTokType = TOK_IDENT Then
    LexNextToken;

  { Parenthese fermante }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;

  GenSubstringRef(Ident, Pos, Len);
  Inc(StrTotalGenerated);
  Inc(StrStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseStringOpStatement : dispatch des operations sur chaines  }
{   STRING, UNSTRING ou INSPECT                                 }
{ ------------------------------------------------------------ }

Procedure ParseStringOpStatement;
Begin
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_STRING) Then
    ParseStringStatement
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UNSTRING) Then
    ParseUnstringStatement
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INSPECT) Then
    ParseInspectStatement;
End;

{ ------------------------------------------------------------ }
{ IsStringKeyword : verifie si le mot-cle courant est lie       }
{                   aux operations sur chaines                  }
{ ------------------------------------------------------------ }

Function IsStringKeyword(KW : Integer) : Boolean;
Begin
  IsStringKeyword := (KW = KW_STRING) Or (KW = KW_UNSTRING) Or
                     (KW = KW_INSPECT) Or (KW = KW_DELIMITED) Or
                     (KW = KW_DELIMITER) Or (KW = KW_TALLYING) Or
                     (KW = KW_REPLACING) Or (KW = KW_CONVERTING) Or
                     (KW = KW_CHARACTERS) Or (KW = KW_FOR) Or
                     (KW = KW_END_STRING) Or (KW = KW_END_UNSTRING);
End;

{ ------------------------------------------------------------ }
{ DumpStringState : affiche l etat du module STRING/INSPECT     }
{ ------------------------------------------------------------ }

Procedure DumpStringState;
Begin
  WriteLn('--- String/Inspect State ---');
  WriteLn('  Initialized     : ', StrInitialized);
  WriteLn('  STRING count    : ', StrStringCount);
  WriteLn('  UNSTRING count  : ', StrUnstringCount);
  WriteLn('  INSPECT TALLY   : ', StrInspectTallyCount);
  WriteLn('  INSPECT REPLACE : ', StrInspectReplCount);
  WriteLn('  INSPECT CONVERT : ', StrInspectConvCount);
  WriteLn('  Substring refs  : ', StrSubstringRefCount);
  WriteLn('  POINTER clauses : ', StrPointerCount);
  WriteLn('  OVERFLOW clauses: ', StrOverflowCount);
  WriteLn('  DELIMITED count : ', StrDelimitedCount);
  WriteLn('  TALLYING count  : ', StrTallyingCount);
  WriteLn('  BEFORE/AFTER    : ', StrBeforeAfterCount);
  WriteLn('  ALL count       : ', StrAllCount);
  WriteLn('  LEADING count   : ', StrLeadingCount);
  WriteLn('  FIRST count     : ', StrFirstCount);
  WriteLn('  CHARACTERS count: ', StrCharactersCount);
  WriteLn('  Total generated : ', StrTotalGenerated);
  WriteLn('  State count     : ', StrStateCount);
End;

{ 10 fonctions accesseurs pour TODO 13                         }

Function IsStrInitialized : Boolean;
Begin
  IsStrInitialized := StrInitialized;
End;

Function IsStrEmpty : Boolean;
Begin
  IsStrEmpty := (StrTotalGenerated = 0);
End;

Function GetStrTotalGenerated : Integer;
Begin
  GetStrTotalGenerated := StrTotalGenerated;
End;

Function GetStrStatus : TString;
Begin
  If Not StrInitialized Then
    GetStrStatus := 'NON INITIALISE'
  Else
    GetStrStatus := 'STRING=' + ItoSI(StrStringCount) +
                    ' UNSTRING=' + ItoSI(StrUnstringCount) +
                    ' TALLY=' + ItoSI(StrInspectTallyCount) +
                    ' REPL=' + ItoSI(StrInspectReplCount) +
                    ' CONV=' + ItoSI(StrInspectConvCount);
End;

Function GetStrStringCount : Integer;
Begin
  GetStrStringCount := StrStringCount;
End;

Function GetStrUnstringCount : Integer;
Begin
  GetStrUnstringCount := StrUnstringCount;
End;

Function GetStrInspectTallyCount : Integer;
Begin
  GetStrInspectTallyCount := StrInspectTallyCount;
End;

Function GetStrInspectReplCount : Integer;
Begin
  GetStrInspectReplCount := StrInspectReplCount;
End;

Function GetStrInspectConvCount : Integer;
Begin
  GetStrInspectConvCount := StrInspectConvCount;
End;

Function GetStrStateCount : Integer;
Begin
  GetStrStateCount := StrStateCount;
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : E/S FICHIERS                             }
{           OPEN, READ, WRITE, REWRITE, CLOSE, DELETE, START   }
{ ============================================================ }

Const
  { Modes d ouverture de fichiers }
  FIO_OPEN_NONE        = 0;   { pas de mode d ouverture                   }
  FIO_OPEN_INPUT       = 1;   { OPEN INPUT (lecture seule)                 }
  FIO_OPEN_OUTPUT      = 2;   { OPEN OUTPUT (ecriture, creation)           }
  FIO_OPEN_IO          = 3;   { OPEN I-O (lecture/ecriture)                }
  FIO_OPEN_EXTEND      = 4;   { OPEN EXTEND (ajout en fin)                 }

  { Types d operations fichier }
  FIO_OP_NONE          = 0;   { pas d operation en cours                   }
  FIO_OP_OPEN          = 1;   { ouverture de fichier                       }
  FIO_OP_READ          = 2;   { lecture d enregistrement                   }
  FIO_OP_WRITE         = 3;   { ecriture d enregistrement                  }
  FIO_OP_REWRITE       = 4;   { reecriture d enregistrement                }
  FIO_OP_CLOSE         = 5;   { fermeture de fichier                       }
  FIO_OP_DELETE         = 6;   { suppression d enregistrement               }
  FIO_OP_START         = 7;   { positionnement dans un fichier indexe      }

  { Types d avancement pour WRITE ADVANCING }
  FIO_ADV_NONE         = 0;   { pas d avancement                           }
  FIO_ADV_LINES        = 1;   { ADVANCING n LINES                          }
  FIO_ADV_PAGE         = 2;   { ADVANCING PAGE                             }

  { Codes de statut fichier COBOL (2 caracteres) }
  FIO_STAT_OK          = 0;   { 00 = succes                                }
  FIO_STAT_AT_END      = 1;   { 10 = fin de fichier                        }
  FIO_STAT_KEY_INVALID = 2;   { 23 = cle non trouvee                       }
  FIO_STAT_KEY_EXISTS  = 3;   { 22 = cle deja existante                    }
  FIO_STAT_PERM_ERROR  = 4;   { 37 = erreur de permission                  }
  FIO_STAT_LOGIC_ERROR = 5;   { 41/42/43 = erreur de logique               }

  { Limites }
  FIO_MAX_FILES_OPEN   = 16;  { max de fichiers ouverts simultanement      }
  FIO_MAX_KEYS         = 8;   { max de cles alternatives pour INDEXED      }
  FIO_MAX_ADV_LINES    = 999; { max de lignes d avancement                 }

Var
  FioInitialized       : Boolean;   { True si InitFileIOState appele         }
  FioStateCount        : Integer;   { compteur d etat general                }
  FioLabelNum          : Integer;   { compteur de labels internes            }
  FioOpenCount         : Integer;   { nombre de OPEN                         }
  FioOpenInputCount    : Integer;   { nombre de OPEN INPUT                   }
  FioOpenOutputCount   : Integer;   { nombre de OPEN OUTPUT                  }
  FioOpenIOCount       : Integer;   { nombre de OPEN I-O                     }
  FioOpenExtendCount   : Integer;   { nombre de OPEN EXTEND                  }
  FioReadCount         : Integer;   { nombre de READ                         }
  FioReadIntoCount     : Integer;   { nombre de READ ... INTO                }
  FioReadKeyCount      : Integer;   { nombre de READ ... KEY IS              }
  FioWriteCount        : Integer;   { nombre de WRITE                        }
  FioWriteFromCount    : Integer;   { nombre de WRITE ... FROM               }
  FioWriteAdvCount     : Integer;   { nombre de WRITE ... ADVANCING          }
  FioRewriteCount      : Integer;   { nombre de REWRITE                      }
  FioCloseCount        : Integer;   { nombre de CLOSE                        }
  FioDeleteCount       : Integer;   { nombre de DELETE                       }
  FioStartCount        : Integer;   { nombre de START                        }
  FioAtEndCount        : Integer;   { nombre de clauses AT END               }
  FioNotAtEndCount     : Integer;   { nombre de clauses NOT AT END           }
  FioInvalidKeyCount   : Integer;   { nombre de clauses INVALID KEY          }
  FioNotInvalidCount   : Integer;   { nombre de clauses NOT INVALID KEY      }
  FioFileStatusCount   : Integer;   { nombre de FILE STATUS utilises         }
  FioTotalGenerated    : Integer;   { total d instructions generees          }

{ ------------------------------------------------------------ }
{ InitFileIOState : initialiser l etat du module E/S fichiers  }
{ ------------------------------------------------------------ }

Procedure InitFileIOState;
Begin
  FioInitialized       := True;
  FioStateCount        := 0;
  FioLabelNum          := 0;
  FioOpenCount         := 0;
  FioOpenInputCount    := 0;
  FioOpenOutputCount   := 0;
  FioOpenIOCount       := 0;
  FioOpenExtendCount   := 0;
  FioReadCount         := 0;
  FioReadIntoCount     := 0;
  FioReadKeyCount      := 0;
  FioWriteCount        := 0;
  FioWriteFromCount    := 0;
  FioWriteAdvCount     := 0;
  FioRewriteCount      := 0;
  FioCloseCount        := 0;
  FioDeleteCount       := 0;
  FioStartCount        := 0;
  FioAtEndCount        := 0;
  FioNotAtEndCount     := 0;
  FioInvalidKeyCount   := 0;
  FioNotInvalidCount   := 0;
  FioFileStatusCount   := 0;
  FioTotalGenerated    := 0;
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFioLabel : genere un label unique pour les E/S fichiers   }
{ ------------------------------------------------------------ }

Function GenFioLabel : TString;
Begin
  Inc(FioLabelNum);
  GenFioLabel := '_COBFIO_' + ItoSI(FioLabelNum);
End;

{ ------------------------------------------------------------ }
{ FioOpenModeName : retourne le nom d un mode d ouverture      }
{ ------------------------------------------------------------ }

Function FioOpenModeName(Mode : Integer) : TString;
Begin
  Case Mode Of
    FIO_OPEN_NONE   : FioOpenModeName := 'NONE';
    FIO_OPEN_INPUT  : FioOpenModeName := 'INPUT';
    FIO_OPEN_OUTPUT : FioOpenModeName := 'OUTPUT';
    FIO_OPEN_IO     : FioOpenModeName := 'I-O';
    FIO_OPEN_EXTEND : FioOpenModeName := 'EXTEND';
  Else
    FioOpenModeName := '?MODE' + ItoSI(Mode);
  End;
End;

{ ------------------------------------------------------------ }
{ FioOpTypeName : retourne le nom d un type d operation        }
{ ------------------------------------------------------------ }

Function FioOpTypeName(Op : Integer) : TString;
Begin
  Case Op Of
    FIO_OP_NONE    : FioOpTypeName := 'NONE';
    FIO_OP_OPEN    : FioOpTypeName := 'OPEN';
    FIO_OP_READ    : FioOpTypeName := 'READ';
    FIO_OP_WRITE   : FioOpTypeName := 'WRITE';
    FIO_OP_REWRITE : FioOpTypeName := 'REWRITE';
    FIO_OP_CLOSE   : FioOpTypeName := 'CLOSE';
    FIO_OP_DELETE   : FioOpTypeName := 'DELETE';
    FIO_OP_START   : FioOpTypeName := 'START';
  Else
    FioOpTypeName := '?OP' + ItoSI(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ FioAdvTypeName : retourne le nom d un type d avancement      }
{ ------------------------------------------------------------ }

Function FioAdvTypeName(Adv : Integer) : TString;
Begin
  Case Adv Of
    FIO_ADV_NONE  : FioAdvTypeName := 'NONE';
    FIO_ADV_LINES : FioAdvTypeName := 'LINES';
    FIO_ADV_PAGE  : FioAdvTypeName := 'PAGE';
  Else
    FioAdvTypeName := '?ADV' + ItoSI(Adv);
  End;
End;

{ ------------------------------------------------------------ }
{ FioStatusName : retourne le nom d un code de statut fichier  }
{ ------------------------------------------------------------ }

Function FioStatusName(Stat : Integer) : TString;
Begin
  Case Stat Of
    FIO_STAT_OK          : FioStatusName := '00-OK';
    FIO_STAT_AT_END      : FioStatusName := '10-AT-END';
    FIO_STAT_KEY_INVALID : FioStatusName := '23-KEY-INVALID';
    FIO_STAT_KEY_EXISTS  : FioStatusName := '22-KEY-EXISTS';
    FIO_STAT_PERM_ERROR  : FioStatusName := '37-PERM-ERROR';
    FIO_STAT_LOGIC_ERROR : FioStatusName := '41-LOGIC-ERROR';
  Else
    FioStatusName := '?STAT' + ItoSI(Stat);
  End;
End;

{ ------------------------------------------------------------ }
{ GenFileOpen : genere le code 80386 pour OPEN                 }
{ Appelle CreateFileA (Win32 API)                              }
{ Mode INPUT : GENERIC_READ, OPEN_EXISTING                     }
{ Mode OUTPUT : GENERIC_WRITE, CREATE_ALWAYS                   }
{ Mode I-O : GENERIC_READ+WRITE, OPEN_EXISTING                }
{ Mode EXTEND : GENERIC_WRITE, OPEN_ALWAYS + SetFilePointer    }
{ ------------------------------------------------------------ }

Procedure GenFileOpen(FileName : TString; Mode : Integer);
Var
  LblOk, LblErr : TString;
Begin
  LblOk  := GenFioLabel;
  LblErr := GenFioLabel;

  { Commentaire ASM }
  WriteLn('; OPEN ', FioOpenModeName(Mode), ' ', FileName);

  { Push parametres CreateFileA }
  Case Mode Of
    FIO_OPEN_INPUT : Begin
      WriteLn('  push 0                 ; hTemplateFile');
      WriteLn('  push 80h               ; FILE_ATTRIBUTE_NORMAL');
      WriteLn('  push 3                 ; OPEN_EXISTING');
      WriteLn('  push 0                 ; lpSecurityAttributes');
      WriteLn('  push 1                 ; FILE_SHARE_READ');
      WriteLn('  push 80000000h         ; GENERIC_READ');
    End;
    FIO_OPEN_OUTPUT : Begin
      WriteLn('  push 0                 ; hTemplateFile');
      WriteLn('  push 80h               ; FILE_ATTRIBUTE_NORMAL');
      WriteLn('  push 2                 ; CREATE_ALWAYS');
      WriteLn('  push 0                 ; lpSecurityAttributes');
      WriteLn('  push 0                 ; dwShareMode');
      WriteLn('  push 40000000h         ; GENERIC_WRITE');
    End;
    FIO_OPEN_IO : Begin
      WriteLn('  push 0                 ; hTemplateFile');
      WriteLn('  push 80h               ; FILE_ATTRIBUTE_NORMAL');
      WriteLn('  push 3                 ; OPEN_EXISTING');
      WriteLn('  push 0                 ; lpSecurityAttributes');
      WriteLn('  push 0                 ; dwShareMode');
      WriteLn('  push 0C0000000h        ; GENERIC_READ + GENERIC_WRITE');
    End;
    FIO_OPEN_EXTEND : Begin
      WriteLn('  push 0                 ; hTemplateFile');
      WriteLn('  push 80h               ; FILE_ATTRIBUTE_NORMAL');
      WriteLn('  push 4                 ; OPEN_ALWAYS');
      WriteLn('  push 0                 ; lpSecurityAttributes');
      WriteLn('  push 0                 ; dwShareMode');
      WriteLn('  push 40000000h         ; GENERIC_WRITE');
    End;
  End;

  WriteLn('  push offset ', AsmIdent(FileName));
  WriteLn('  call _CreateFileA@28');
  WriteLn('  cmp eax, -1             ; INVALID_HANDLE_VALUE');
  WriteLn('  jne ', LblOk);
  WriteLn(LblErr, ':');
  WriteLn('  ; Erreur ouverture - FILE STATUS = 35');
  WriteLn(LblOk, ':');
  WriteLn('  mov [', AsmIdent(FileName), '_handle], eax');

  { Pour EXTEND, positionner a la fin }
  If Mode = FIO_OPEN_EXTEND Then Begin
    WriteLn('  push 2                 ; FILE_END');
    WriteLn('  push 0                 ; lpDistanceToMoveHigh');
    WriteLn('  push 0                 ; lDistanceToMove');
    WriteLn('  push eax               ; hFile');
    WriteLn('  call _SetFilePointer@16');
  End;

  Inc(FioOpenCount);
  Case Mode Of
    FIO_OPEN_INPUT  : Inc(FioOpenInputCount);
    FIO_OPEN_OUTPUT : Inc(FioOpenOutputCount);
    FIO_OPEN_IO     : Inc(FioOpenIOCount);
    FIO_OPEN_EXTEND : Inc(FioOpenExtendCount);
  End;
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileRead : genere le code 80386 pour READ                 }
{ Appelle ReadFile (Win32 API)                                 }
{ ------------------------------------------------------------ }

Procedure GenFileRead(FileName, RecordName : TString; HasInto : Boolean;
                      IntoIdent : TString);
Var
  LblOk, LblEnd : TString;
Begin
  LblOk  := GenFioLabel;
  LblEnd := GenFioLabel;

  WriteLn('; READ ', FileName);
  WriteLn('  push 0                 ; lpOverlapped');
  WriteLn('  lea eax, [', AsmIdent(FileName), '_bytes]');
  WriteLn('  push eax               ; lpNumberOfBytesRead');
  WriteLn('  push ', AsmIdent(RecordName), '_size');
  WriteLn('  push offset ', AsmIdent(RecordName));
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call _ReadFile@20');
  WriteLn('  test eax, eax');
  WriteLn('  jnz ', LblOk);
  WriteLn('  ; AT END - FILE STATUS = 10');
  WriteLn(LblOk, ':');

  { Si INTO est present, copier le record dans la variable }
  If HasInto Then Begin
    WriteLn('  ; INTO ', IntoIdent);
    WriteLn('  lea esi, [', AsmIdent(RecordName), ']');
    WriteLn('  lea edi, [', AsmIdent(IntoIdent), ']');
    WriteLn('  mov ecx, ', AsmIdent(RecordName), '_size');
    WriteLn('  rep movsb');
    Inc(FioReadIntoCount);
  End;

  WriteLn(LblEnd, ':');
  Inc(FioReadCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileReadKey : genere le code pour READ ... KEY IS          }
{ Pour fichiers indexes, positionnement par cle                }
{ ------------------------------------------------------------ }

Procedure GenFileReadKey(FileName, RecordName, KeyName : TString);
Begin
  WriteLn('; READ ', FileName, ' KEY IS ', KeyName);
  WriteLn('  ; Appel runtime ', PFX_RT, 'READ_KEY');
  WriteLn('  push offset ', AsmIdent(KeyName));
  WriteLn('  push offset ', AsmIdent(RecordName));
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call ', PFX_RT, 'READ_KEY');
  WriteLn('  add esp, 12');
  Inc(FioReadKeyCount);
  Inc(FioReadCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileWrite : genere le code 80386 pour WRITE               }
{ Appelle WriteFile (Win32 API)                                }
{ ------------------------------------------------------------ }

Procedure GenFileWrite(FileName, RecordName : TString; HasFrom : Boolean;
                       FromIdent : TString);
Var
  LblOk : TString;
Begin
  LblOk := GenFioLabel;

  WriteLn('; WRITE ', RecordName);

  { Si FROM est present, copier d abord la source dans le record }
  If HasFrom Then Begin
    WriteLn('  ; FROM ', FromIdent);
    WriteLn('  lea esi, [', AsmIdent(FromIdent), ']');
    WriteLn('  lea edi, [', AsmIdent(RecordName), ']');
    WriteLn('  mov ecx, ', AsmIdent(RecordName), '_size');
    WriteLn('  rep movsb');
    Inc(FioWriteFromCount);
  End;

  WriteLn('  push 0                 ; lpOverlapped');
  WriteLn('  lea eax, [', AsmIdent(FileName), '_bytes]');
  WriteLn('  push eax               ; lpNumberOfBytesWritten');
  WriteLn('  push ', AsmIdent(RecordName), '_size');
  WriteLn('  push offset ', AsmIdent(RecordName));
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call _WriteFile@20');
  WriteLn('  test eax, eax');
  WriteLn('  jnz ', LblOk);
  WriteLn('  ; Erreur ecriture - FILE STATUS = 48');
  WriteLn(LblOk, ':');

  Inc(FioWriteCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileWriteAdvancing : genere WRITE avec ADVANCING           }
{ BEFORE/AFTER ADVANCING n LINES ou PAGE                       }
{ ------------------------------------------------------------ }

Procedure GenFileWriteAdvancing(RecordName : TString; IsBefore : Boolean;
                                AdvType : Integer; AdvLines : Integer);
Begin
  WriteLn('; WRITE ', RecordName, ' ADVANCING');
  If Not IsBefore Then Begin
    { AFTER ADVANCING = ecrire les sauts avant le record }
    If AdvType = FIO_ADV_PAGE Then Begin
      WriteLn('  ; AFTER ADVANCING PAGE');
      WriteLn('  push 0Ch               ; form feed');
      WriteLn('  call ', PFX_RT, 'WRITE_CHAR');
      WriteLn('  add esp, 4');
    End Else Begin
      WriteLn('  ; AFTER ADVANCING ', ItoSI(AdvLines), ' LINES');
      WriteLn('  mov ecx, ', ItoSI(AdvLines));
      WriteLn('@@:');
      WriteLn('  push ecx');
      WriteLn('  push 0Ah               ; line feed');
      WriteLn('  call ', PFX_RT, 'WRITE_CHAR');
      WriteLn('  add esp, 4');
      WriteLn('  pop ecx');
      WriteLn('  loop @b');
    End;
  End;

  { Ecrire le record }
  WriteLn('  push ', AsmIdent(RecordName), '_size');
  WriteLn('  push offset ', AsmIdent(RecordName));
  WriteLn('  call ', PFX_RT, 'WRITE_RECORD');
  WriteLn('  add esp, 8');

  If IsBefore Then Begin
    { BEFORE ADVANCING = ecrire les sauts apres le record }
    If AdvType = FIO_ADV_PAGE Then Begin
      WriteLn('  ; BEFORE ADVANCING PAGE');
      WriteLn('  push 0Ch               ; form feed');
      WriteLn('  call ', PFX_RT, 'WRITE_CHAR');
      WriteLn('  add esp, 4');
    End Else Begin
      WriteLn('  ; BEFORE ADVANCING ', ItoSI(AdvLines), ' LINES');
      WriteLn('  mov ecx, ', ItoSI(AdvLines));
      WriteLn('@@:');
      WriteLn('  push ecx');
      WriteLn('  push 0Ah               ; line feed');
      WriteLn('  call ', PFX_RT, 'WRITE_CHAR');
      WriteLn('  add esp, 4');
      WriteLn('  pop ecx');
      WriteLn('  loop @b');
    End;
  End;

  Inc(FioWriteAdvCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileRewrite : genere le code 80386 pour REWRITE           }
{ ------------------------------------------------------------ }

Procedure GenFileRewrite(FileName, RecordName : TString;
                         HasFrom : Boolean; FromIdent : TString);
Var
  LblOk : TString;
Begin
  LblOk := GenFioLabel;

  WriteLn('; REWRITE ', RecordName);

  If HasFrom Then Begin
    WriteLn('  ; FROM ', FromIdent);
    WriteLn('  lea esi, [', AsmIdent(FromIdent), ']');
    WriteLn('  lea edi, [', AsmIdent(RecordName), ']');
    WriteLn('  mov ecx, ', AsmIdent(RecordName), '_size');
    WriteLn('  rep movsb');
  End;

  { Repositionner au debut du record courant }
  WriteLn('  push 1                 ; FILE_CURRENT');
  WriteLn('  push 0');
  WriteLn('  push -', AsmIdent(RecordName), '_size');
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call _SetFilePointer@16');

  { Reecrire le record }
  WriteLn('  push 0                 ; lpOverlapped');
  WriteLn('  lea eax, [', AsmIdent(FileName), '_bytes]');
  WriteLn('  push eax               ; lpNumberOfBytesWritten');
  WriteLn('  push ', AsmIdent(RecordName), '_size');
  WriteLn('  push offset ', AsmIdent(RecordName));
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call _WriteFile@20');
  WriteLn('  test eax, eax');
  WriteLn('  jnz ', LblOk);
  WriteLn('  ; Erreur reecriture - FILE STATUS = 49');
  WriteLn(LblOk, ':');

  Inc(FioRewriteCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileClose : genere le code 80386 pour CLOSE               }
{ Appelle CloseHandle (Win32 API)                              }
{ ------------------------------------------------------------ }

Procedure GenFileClose(FileName : TString);
Var
  LblOk : TString;
Begin
  LblOk := GenFioLabel;

  WriteLn('; CLOSE ', FileName);
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call _CloseHandle@4');
  WriteLn('  test eax, eax');
  WriteLn('  jnz ', LblOk);
  WriteLn('  ; Erreur fermeture');
  WriteLn(LblOk, ':');
  WriteLn('  mov dword ptr [', AsmIdent(FileName), '_handle], 0');

  Inc(FioCloseCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileDelete : genere le code pour DELETE                    }
{ ------------------------------------------------------------ }

Procedure GenFileDelete(FileName : TString);
Begin
  WriteLn('; DELETE ', FileName);
  WriteLn('  ; Appel runtime ', PFX_RT, 'DELETE_RECORD');
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call ', PFX_RT, 'DELETE_RECORD');
  WriteLn('  add esp, 4');

  Inc(FioDeleteCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileStart : genere le code pour START                     }
{ Positionnement dans un fichier indexe                        }
{ ------------------------------------------------------------ }

Procedure GenFileStart(FileName, KeyName : TString; RelOp : Integer);
Begin
  WriteLn('; START ', FileName, ' KEY ', RelOpName(RelOp), ' ', KeyName);
  WriteLn('  ; Appel runtime ', PFX_RT, 'START_FILE');
  WriteLn('  push ', ItoSI(RelOp));
  WriteLn('  push offset ', AsmIdent(KeyName));
  WriteLn('  push [', AsmIdent(FileName), '_handle]');
  WriteLn('  call ', PFX_RT, 'START_FILE');
  WriteLn('  add esp, 12');

  Inc(FioStartCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenAtEndCheck : genere le code pour AT END / NOT AT END       }
{ ------------------------------------------------------------ }

Procedure GenAtEndCheck(LblAtEnd, LblNotAtEnd : TString);
Begin
  WriteLn('  ; Tester FILE STATUS = 10 (fin de fichier)');
  WriteLn('  cmp byte ptr [_COB_FILE_STATUS], 31h  ; ''1''');
  WriteLn('  jne ', LblNotAtEnd);
  WriteLn('  cmp byte ptr [_COB_FILE_STATUS+1], 30h  ; ''0''');
  WriteLn('  jne ', LblNotAtEnd);
  WriteLn(LblAtEnd, ':');
  Inc(FioAtEndCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenInvalidKeyCheck : genere le code pour INVALID KEY          }
{ ------------------------------------------------------------ }

Procedure GenInvalidKeyCheck(LblInvalid, LblNotInvalid : TString);
Begin
  WriteLn('  ; Tester FILE STATUS = 23 (cle invalide)');
  WriteLn('  cmp byte ptr [_COB_FILE_STATUS], 32h  ; ''2''');
  WriteLn('  jne ', LblNotInvalid);
  WriteLn('  cmp byte ptr [_COB_FILE_STATUS+1], 33h  ; ''3''');
  WriteLn('  jne ', LblNotInvalid);
  WriteLn(LblInvalid, ':');
  Inc(FioInvalidKeyCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ GenFileStatusStore : genere le code pour stocker FILE STATUS  }
{ ------------------------------------------------------------ }

Procedure GenFileStatusStore(StatusVar : TString; StatusCode : Integer);
Begin
  WriteLn('; Stocker FILE STATUS dans ', StatusVar);
  Case StatusCode Of
    FIO_STAT_OK : Begin
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '], 30h  ; ''0''');
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '+1], 30h  ; ''0''');
    End;
    FIO_STAT_AT_END : Begin
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '], 31h  ; ''1''');
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '+1], 30h  ; ''0''');
    End;
    FIO_STAT_KEY_INVALID : Begin
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '], 32h  ; ''2''');
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '+1], 33h  ; ''3''');
    End;
    FIO_STAT_KEY_EXISTS : Begin
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '], 32h  ; ''2''');
      WriteLn('  mov byte ptr [', AsmIdent(StatusVar), '+1], 32h  ; ''2''');
    End;
  End;
  Inc(FioFileStatusCount);
  Inc(FioTotalGenerated);
  Inc(FioStateCount);
End;

{ ------------------------------------------------------------ }
{ ParseOpenStatement : analyser OPEN INPUT/OUTPUT/I-O/EXTEND   }
{ OPEN mode nom-fichier-1 [nom-fichier-2 ...]                 }
{ ------------------------------------------------------------ }

Procedure ParseOpenStatement;
Var
  Mode : Integer;
Begin
  { Le mot-cle OPEN a deja ete consomme }
  Inc(FioStateCount);

  { Determiner le mode d ouverture }
  If (CurTokType <> TOK_KEYWORD) Then Begin
    WarnMsg('OPEN : mode attendu (INPUT, OUTPUT, I-O, EXTEND)');
    Exit;
  End;

  Case CurTokNum Of
    KW_INPUT  : Mode := FIO_OPEN_INPUT;
    KW_OUTPUT : Mode := FIO_OPEN_OUTPUT;
    KW_I_O    : Mode := FIO_OPEN_IO;
    KW_EXTEND : Mode := FIO_OPEN_EXTEND;
  Else Begin
    WarnMsg('OPEN : mode inconnu ' + CurTokStr);
    Exit;
  End;
  End;

  LexNextToken;

  { Lire un ou plusieurs noms de fichiers }
  While (CurTokType = TOK_IDENT) Do Begin
    GenFileOpen(CurTokStr, Mode);
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseReadStatement : analyser READ nom-fichier               }
{ [INTO id] [AT END instr] [NOT AT END instr] END-READ         }
{ READ nom-fichier KEY IS nom-cle [INVALID KEY instr]          }
{ ------------------------------------------------------------ }

Procedure ParseReadStatement;
Var
  FileName     : TString;
  HasInto      : Boolean;
  IntoIdent    : TString;
  HasKey       : Boolean;
  KeyName      : TString;
  LblAtEnd     : TString;
  LblNotAtEnd  : TString;
  LblEndRead   : TString;
Begin
  Inc(FioStateCount);

  { Nom du fichier }
  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('READ : nom de fichier attendu');
    Exit;
  End;
  FileName := CurTokStr;
  LexNextToken;

  HasInto := False;
  IntoIdent := '';
  HasKey := False;
  KeyName := '';

  { Clauses optionnelles }
  While (CurTokType = TOK_KEYWORD) And
        (CurTokNum <> KW_END_READ) And
        (CurTokType <> TOK_DOT) Do
  Begin
    If CurTokNum = KW_INTO Then Begin
      LexNextToken;
      If CurTokType = TOK_IDENT Then Begin
        HasInto := True;
        IntoIdent := CurTokStr;
        LexNextToken;
      End;
    End
    Else If CurTokNum = KW_KEY Then Begin
      LexNextToken;
      { Consommer IS optionnel }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
        LexNextToken;
      If CurTokType = TOK_IDENT Then Begin
        HasKey := True;
        KeyName := CurTokStr;
        LexNextToken;
      End;
    End
    Else If (CurTokNum = KW_AT) Then Begin
      LexNextToken;
      { AT END }
      If (CurTokType = TOK_IDENT) And (CurTokStr = 'END') Then Begin
        LblAtEnd := GenFioLabel;
        LblNotAtEnd := GenFioLabel;
        LblEndRead := GenFioLabel;
        LexNextToken;
        Inc(FioAtEndCount);
        { Sauter les instructions du bloc AT END }
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_READ))) Do
          LexNextToken;
      End;
    End
    Else If (CurTokNum = KW_NOT) Then Begin
      LexNextToken;
      { NOT AT END }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AT) Then Begin
        LexNextToken;
        If (CurTokType = TOK_IDENT) And (CurTokStr = 'END') Then Begin
          Inc(FioNotAtEndCount);
          LexNextToken;
          While (CurTokType <> TOK_DOT) And
                Not ((CurTokType = TOK_KEYWORD) And
                     (CurTokNum = KW_END_READ)) Do
            LexNextToken;
        End;
      End;
    End
    Else If (CurTokNum = KW_INVALID) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
        Inc(FioInvalidKeyCount);
        LexNextToken;
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_READ))) Do
          LexNextToken;
      End;
    End
    Else
      LexNextToken;
  End;

  { Generer le code }
  If HasKey Then
    GenFileReadKey(FileName, FileName, KeyName)
  Else
    GenFileRead(FileName, FileName, HasInto, IntoIdent);

  { Consommer END-READ si present }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_READ) Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseWriteStatement : analyser WRITE nom-record              }
{ [FROM id] [BEFORE/AFTER ADVANCING n LINES/PAGE]             }
{ [INVALID KEY instr] END-WRITE                                }
{ ------------------------------------------------------------ }

Procedure ParseWriteStatement;
Var
  RecordName   : TString;
  HasFrom      : Boolean;
  FromIdent    : TString;
  HasAdvancing : Boolean;
  IsBefore     : Boolean;
  AdvType      : Integer;
  AdvLines     : Integer;
Begin
  Inc(FioStateCount);

  { Nom du record }
  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('WRITE : nom de record attendu');
    Exit;
  End;
  RecordName := CurTokStr;
  LexNextToken;

  HasFrom := False;
  FromIdent := '';
  HasAdvancing := False;
  IsBefore := True;
  AdvType := FIO_ADV_NONE;
  AdvLines := 1;

  { Clauses optionnelles }
  While (CurTokType = TOK_KEYWORD) And
        (CurTokNum <> KW_END_WRITE) And
        (CurTokType <> TOK_DOT) Do
  Begin
    If CurTokNum = KW_FROM Then Begin
      LexNextToken;
      If CurTokType = TOK_IDENT Then Begin
        HasFrom := True;
        FromIdent := CurTokStr;
        LexNextToken;
      End;
    End
    Else If (CurTokNum = KW_BEFORE) Or (CurTokNum = KW_AFTER) Then Begin
      IsBefore := (CurTokNum = KW_BEFORE);
      LexNextToken;
      { Consommer ADVANCING }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ADVANCING) Then
        LexNextToken;
      { PAGE ou n LINES }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PAGE) Then Begin
        HasAdvancing := True;
        AdvType := FIO_ADV_PAGE;
        LexNextToken;
      End
      Else If CurTokType = TOK_INTEGER Then Begin
        HasAdvancing := True;
        AdvType := FIO_ADV_LINES;
        AdvLines := CurTokNum;
        LexNextToken;
        { Consommer LINES optionnel }
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_LINE) Then
          LexNextToken;
      End;
    End
    Else If (CurTokNum = KW_INVALID) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
        Inc(FioInvalidKeyCount);
        LexNextToken;
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_WRITE))) Do
          LexNextToken;
      End;
    End
    Else
      LexNextToken;
  End;

  { Generer le code }
  If HasAdvancing Then
    GenFileWriteAdvancing(RecordName, IsBefore, AdvType, AdvLines)
  Else
    GenFileWrite(RecordName, RecordName, HasFrom, FromIdent);

  { Consommer END-WRITE si present }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_WRITE) Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseRewriteStatement : analyser REWRITE nom-record          }
{ [FROM id] [INVALID KEY instr] END-REWRITE                   }
{ ------------------------------------------------------------ }

Procedure ParseRewriteStatement;
Var
  RecordName : TString;
  HasFrom    : Boolean;
  FromIdent  : TString;
Begin
  Inc(FioStateCount);

  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('REWRITE : nom de record attendu');
    Exit;
  End;
  RecordName := CurTokStr;
  LexNextToken;

  HasFrom := False;
  FromIdent := '';

  While (CurTokType = TOK_KEYWORD) And
        (CurTokNum <> KW_END_REWRITE) And
        (CurTokType <> TOK_DOT) Do
  Begin
    If CurTokNum = KW_FROM Then Begin
      LexNextToken;
      If CurTokType = TOK_IDENT Then Begin
        HasFrom := True;
        FromIdent := CurTokStr;
        LexNextToken;
      End;
    End
    Else If (CurTokNum = KW_INVALID) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
        Inc(FioInvalidKeyCount);
        LexNextToken;
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_REWRITE))) Do
          LexNextToken;
      End;
    End
    Else
      LexNextToken;
  End;

  GenFileRewrite(RecordName, RecordName, HasFrom, FromIdent);

  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_REWRITE) Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseCloseStatement : analyser CLOSE nom-fichier [...]       }
{ ------------------------------------------------------------ }

Procedure ParseCloseStatement;
Begin
  Inc(FioStateCount);

  { Lire un ou plusieurs noms de fichiers }
  While (CurTokType = TOK_IDENT) Do Begin
    GenFileClose(CurTokStr);
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseDeleteStatement : analyser DELETE nom-fichier            }
{ [INVALID KEY instr] END-DELETE                               }
{ ------------------------------------------------------------ }

Procedure ParseDeleteStatement;
Var
  FileName : TString;
Begin
  Inc(FioStateCount);

  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('DELETE : nom de fichier attendu');
    Exit;
  End;
  FileName := CurTokStr;
  LexNextToken;

  { Clauses optionnelles }
  While (CurTokType = TOK_KEYWORD) And
        (CurTokNum <> KW_END_DELETE) And
        (CurTokType <> TOK_DOT) Do
  Begin
    If (CurTokNum = KW_INVALID) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
        Inc(FioInvalidKeyCount);
        LexNextToken;
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_DELETE))) Do
          LexNextToken;
      End;
    End
    Else
      LexNextToken;
  End;

  GenFileDelete(FileName);

  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_DELETE) Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseStartStatement : analyser START nom-fichier             }
{ KEY IS =/>/>=/</<= nom-cle [INVALID KEY instr] END-START    }
{ ------------------------------------------------------------ }

Procedure ParseStartStatement;
Var
  FileName : TString;
  KeyName  : TString;
  RelOp    : Integer;
Begin
  Inc(FioStateCount);

  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('START : nom de fichier attendu');
    Exit;
  End;
  FileName := CurTokStr;
  LexNextToken;

  KeyName := '';
  RelOp := REL_EQ;

  { KEY IS clause }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
    LexNextToken;
    { Consommer IS optionnel }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
      LexNextToken;
    { Operateur de comparaison }
    Case CurTokType Of
      TOK_EQ : Begin RelOp := REL_EQ; LexNextToken; End;
      TOK_GT : Begin RelOp := REL_GT; LexNextToken; End;
      TOK_GE : Begin RelOp := REL_GE; LexNextToken; End;
      TOK_LT : Begin RelOp := REL_LT; LexNextToken; End;
      TOK_LE : Begin RelOp := REL_LE; LexNextToken; End;
    End;
    { Nom de la cle }
    If CurTokType = TOK_IDENT Then Begin
      KeyName := CurTokStr;
      LexNextToken;
    End;
  End;

  { Clauses optionnelles INVALID KEY }
  While (CurTokType = TOK_KEYWORD) And
        (CurTokNum <> KW_END_START) And
        (CurTokType <> TOK_DOT) Do
  Begin
    If (CurTokNum = KW_INVALID) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_KEY) Then Begin
        Inc(FioInvalidKeyCount);
        LexNextToken;
        While (CurTokType <> TOK_DOT) And
              Not ((CurTokType = TOK_KEYWORD) And
                   ((CurTokNum = KW_NOT) Or (CurTokNum = KW_END_START))) Do
          LexNextToken;
      End;
    End
    Else
      LexNextToken;
  End;

  GenFileStart(FileName, KeyName, RelOp);

  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_START) Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseFileIOStatement : dispatch les instructions E/S fichier }
{ ------------------------------------------------------------ }

Procedure ParseFileIOStatement;
Begin
  If CurTokType <> TOK_KEYWORD Then Exit;

  Case CurTokNum Of
    KW_OPEN    : Begin LexNextToken; ParseOpenStatement; End;
    KW_READ    : Begin LexNextToken; ParseReadStatement; End;
    KW_WRITE   : Begin LexNextToken; ParseWriteStatement; End;
    KW_REWRITE : Begin LexNextToken; ParseRewriteStatement; End;
    KW_CLOSE   : Begin LexNextToken; ParseCloseStatement; End;
    KW_DELETE  : Begin LexNextToken; ParseDeleteStatement; End;
    KW_START   : Begin LexNextToken; ParseStartStatement; End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsFileIOKeyword : teste si un mot-cle est un mot-cle E/S    }
{ ------------------------------------------------------------ }

Function IsFileIOKeyword(KW : Integer) : Boolean;
Begin
  IsFileIOKeyword := (KW = KW_OPEN) Or (KW = KW_READ) Or
                     (KW = KW_WRITE) Or (KW = KW_REWRITE) Or
                     (KW = KW_CLOSE) Or (KW = KW_DELETE) Or
                     (KW = KW_START) Or (KW = KW_INPUT) Or
                     (KW = KW_OUTPUT) Or (KW = KW_I_O) Or
                     (KW = KW_EXTEND) Or (KW = KW_INVALID) Or
                     (KW = KW_AT) Or (KW = KW_PAGE) Or
                     (KW = KW_ADVANCING) Or (KW = KW_INTO) Or
                     (KW = KW_FROM) Or (KW = KW_KEY) Or
                     (KW = KW_END_READ) Or (KW = KW_END_WRITE) Or
                     (KW = KW_END_REWRITE) Or (KW = KW_END_START) Or
                     (KW = KW_END_DELETE);
End;

{ ------------------------------------------------------------ }
{ DumpFileIOState : affiche l etat du module E/S fichiers      }
{ ------------------------------------------------------------ }

Procedure DumpFileIOState;
Begin
  WriteLn('--- File I/O State ---');
  WriteLn('  Initialized       : ', FioInitialized);
  WriteLn('  OPEN count        : ', FioOpenCount);
  WriteLn('    INPUT            : ', FioOpenInputCount);
  WriteLn('    OUTPUT           : ', FioOpenOutputCount);
  WriteLn('    I-O              : ', FioOpenIOCount);
  WriteLn('    EXTEND           : ', FioOpenExtendCount);
  WriteLn('  READ count        : ', FioReadCount);
  WriteLn('    INTO             : ', FioReadIntoCount);
  WriteLn('    KEY IS           : ', FioReadKeyCount);
  WriteLn('  WRITE count       : ', FioWriteCount);
  WriteLn('    FROM             : ', FioWriteFromCount);
  WriteLn('    ADVANCING        : ', FioWriteAdvCount);
  WriteLn('  REWRITE count     : ', FioRewriteCount);
  WriteLn('  CLOSE count       : ', FioCloseCount);
  WriteLn('  DELETE count      : ', FioDeleteCount);
  WriteLn('  START count       : ', FioStartCount);
  WriteLn('  AT END clauses    : ', FioAtEndCount);
  WriteLn('  NOT AT END        : ', FioNotAtEndCount);
  WriteLn('  INVALID KEY       : ', FioInvalidKeyCount);
  WriteLn('  NOT INVALID KEY   : ', FioNotInvalidCount);
  WriteLn('  FILE STATUS stores: ', FioFileStatusCount);
  WriteLn('  Total generated   : ', FioTotalGenerated);
  WriteLn('  State count       : ', FioStateCount);
End;

{ 10 fonctions accesseurs pour TODO 14                         }

Function IsFioInitialized : Boolean;
Begin
  IsFioInitialized := FioInitialized;
End;

Function IsFioEmpty : Boolean;
Begin
  IsFioEmpty := (FioTotalGenerated = 0);
End;

Function GetFioTotalGenerated : Integer;
Begin
  GetFioTotalGenerated := FioTotalGenerated;
End;

Function GetFioStatus : TString;
Begin
  If Not FioInitialized Then
    GetFioStatus := 'NON INITIALISE'
  Else
    GetFioStatus := 'OPEN=' + ItoSI(FioOpenCount) +
                    ' READ=' + ItoSI(FioReadCount) +
                    ' WRITE=' + ItoSI(FioWriteCount) +
                    ' REWRITE=' + ItoSI(FioRewriteCount) +
                    ' CLOSE=' + ItoSI(FioCloseCount);
End;

Function GetFioOpenCount : Integer;
Begin
  GetFioOpenCount := FioOpenCount;
End;

Function GetFioReadCount : Integer;
Begin
  GetFioReadCount := FioReadCount;
End;

Function GetFioWriteCount : Integer;
Begin
  GetFioWriteCount := FioWriteCount;
End;

Function GetFioCloseCount : Integer;
Begin
  GetFioCloseCount := FioCloseCount;
End;

Function GetFioDeleteCount : Integer;
Begin
  GetFioDeleteCount := FioDeleteCount;
End;

Function GetFioStateCount : Integer;
Begin
  GetFioStateCount := FioStateCount;
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : ACCEPT ET DISPLAY (E/S CONSOLE)         }
{           DISPLAY, ACCEPT, STOP RUN                          }
{ ============================================================ }

Const
  { Types de source/destination pour ACCEPT/DISPLAY }
  ADS_NONE             = 0;   { pas de source/destination specifique       }
  ADS_CONSOLE          = 1;   { UPON CONSOLE / FROM CONSOLE                }
  ADS_PRINTER          = 2;   { UPON PRINTER                               }
  ADS_DATE             = 3;   { FROM DATE (YYMMDD)                         }
  ADS_DAY              = 4;   { FROM DAY (YYDDD)                           }
  ADS_DAY_OF_WEEK      = 5;   { FROM DAY-OF-WEEK (1-7)                     }
  ADS_TIME             = 6;   { FROM TIME (HHMMSSCC)                       }

  { Types d operations ACCEPT/DISPLAY }
  ADO_NONE             = 0;   { pas d operation                            }
  ADO_DISPLAY          = 1;   { instruction DISPLAY                        }
  ADO_ACCEPT           = 2;   { instruction ACCEPT                         }
  ADO_STOP_RUN         = 3;   { instruction STOP RUN                       }
  ADO_STOP_LITERAL     = 4;   { instruction STOP literal                   }

  { Limites }
  ADS_MAX_OPERANDS     = 16;  { max d operandes dans un DISPLAY            }
  ADS_MAX_LINE_LEN     = 132; { longueur max d une ligne affichee          }

Var
  AdsInitialized       : Boolean;   { True si InitAcceptDisplayState appele }
  AdsStateCount        : Integer;   { compteur d etat general               }
  AdsLabelNum          : Integer;   { compteur de labels internes           }
  AdsDisplayCount      : Integer;   { nombre de DISPLAY                     }
  AdsDisplayUponCount  : Integer;   { nombre de DISPLAY UPON                }
  AdsDisplayNoAdvCount : Integer;   { nombre de WITH NO ADVANCING           }
  AdsDisplayOperands   : Integer;   { total d operandes affiches            }
  AdsDisplayLitCount   : Integer;   { nombre d operandes litteraux          }
  AdsDisplayIdCount    : Integer;   { nombre d operandes identificateurs    }
  AdsDisplayNumCount   : Integer;   { nombre d operandes numeriques         }
  AdsAcceptCount       : Integer;   { nombre de ACCEPT                      }
  AdsAcceptConsoleCount: Integer;   { nombre de ACCEPT FROM CONSOLE         }
  AdsAcceptDateCount   : Integer;   { nombre de ACCEPT FROM DATE            }
  AdsAcceptDayCount    : Integer;   { nombre de ACCEPT FROM DAY             }
  AdsAcceptDayWeekCount: Integer;   { nombre de ACCEPT FROM DAY-OF-WEEK     }
  AdsAcceptTimeCount   : Integer;   { nombre de ACCEPT FROM TIME            }
  AdsStopRunCount      : Integer;   { nombre de STOP RUN                    }
  AdsStopLiteralCount  : Integer;   { nombre de STOP literal                }
  AdsConversionCount   : Integer;   { nombre de conversions num->chaine     }
  AdsCrLfCount         : Integer;   { nombre de CR/LF generes               }
  AdsTotalGenerated    : Integer;   { total d instructions generees         }

{ ------------------------------------------------------------ }
{ InitAcceptDisplayState : initialiser l etat du module         }
{ ACCEPT/DISPLAY/STOP                                           }
{ ------------------------------------------------------------ }

Procedure InitAcceptDisplayState;
Begin
  AdsInitialized       := True;
  AdsStateCount        := 0;
  AdsLabelNum          := 0;
  AdsDisplayCount      := 0;
  AdsDisplayUponCount  := 0;
  AdsDisplayNoAdvCount := 0;
  AdsDisplayOperands   := 0;
  AdsDisplayLitCount   := 0;
  AdsDisplayIdCount    := 0;
  AdsDisplayNumCount   := 0;
  AdsAcceptCount       := 0;
  AdsAcceptConsoleCount:= 0;
  AdsAcceptDateCount   := 0;
  AdsAcceptDayCount    := 0;
  AdsAcceptDayWeekCount:= 0;
  AdsAcceptTimeCount   := 0;
  AdsStopRunCount      := 0;
  AdsStopLiteralCount  := 0;
  AdsConversionCount   := 0;
  AdsCrLfCount         := 0;
  AdsTotalGenerated    := 0;
End;

{ ------------------------------------------------------------ }
{ GenAdsLabel : genere un label unique pour ACCEPT/DISPLAY      }
{ ------------------------------------------------------------ }

Function GenAdsLabel : TString;
Begin
  Inc(AdsLabelNum);
  GenAdsLabel := '_COBADS_L' + ItoSI(AdsLabelNum);
End;

{ ------------------------------------------------------------ }
{ AdsSourceTypeName : retourne le nom d un type de source       }
{ ------------------------------------------------------------ }

Function AdsSourceTypeName(Src : Integer) : TString;
Begin
  Case Src Of
    ADS_NONE        : AdsSourceTypeName := 'NONE';
    ADS_CONSOLE     : AdsSourceTypeName := 'CONSOLE';
    ADS_PRINTER     : AdsSourceTypeName := 'PRINTER';
    ADS_DATE        : AdsSourceTypeName := 'DATE';
    ADS_DAY         : AdsSourceTypeName := 'DAY';
    ADS_DAY_OF_WEEK : AdsSourceTypeName := 'DAY-OF-WEEK';
    ADS_TIME        : AdsSourceTypeName := 'TIME';
  Else
    AdsSourceTypeName := '?SRC' + ItoSI(Src);
  End;
End;

{ ------------------------------------------------------------ }
{ AdsOpTypeName : retourne le nom d un type d operation         }
{ ------------------------------------------------------------ }

Function AdsOpTypeName(Op : Integer) : TString;
Begin
  Case Op Of
    ADO_NONE         : AdsOpTypeName := 'NONE';
    ADO_DISPLAY      : AdsOpTypeName := 'DISPLAY';
    ADO_ACCEPT       : AdsOpTypeName := 'ACCEPT';
    ADO_STOP_RUN     : AdsOpTypeName := 'STOP-RUN';
    ADO_STOP_LITERAL : AdsOpTypeName := 'STOP-LITERAL';
  Else
    AdsOpTypeName := '?OP' + ItoSI(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ GenGetStdHandle : genere code pour GetStdHandle               }
{ HandleType : -10 = STD_INPUT_HANDLE, -11 = STD_OUTPUT_HANDLE }
{ Resultat dans EAX                                             }
{ ------------------------------------------------------------ }

Procedure GenGetStdHandle(HandleType : Integer);
Begin
  WriteLn('  push ', HandleType, '              ; nStdHandle');
  WriteLn('  call _GetStdHandle@4');
  Inc(AdsTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenWriteConsole : genere le code pour ecrire sur stdout       }
{ via WriteFile(hStdOut, lpBuffer, nBytes, lpWritten, 0)       }
{ Adresse du buffer dans ESI, longueur dans ECX                }
{ ------------------------------------------------------------ }

Procedure GenWriteConsole;
Var
  LblWritten : TString;
Begin
  LblWritten := GenAdsLabel;
  WriteLn('  ; WriteFile(hStdOut, buffer, length, &written, 0)');
  WriteLn('  push 0                 ; lpOverlapped');
  WriteLn('  push offset ', LblWritten, ' ; lpNumberOfBytesWritten');
  WriteLn('  push ecx               ; nNumberOfBytesToWrite');
  WriteLn('  push esi               ; lpBuffer');
  WriteLn('  push -11               ; STD_OUTPUT_HANDLE');
  WriteLn('  call _GetStdHandle@4');
  WriteLn('  push eax               ; hFile');
  WriteLn('  call _WriteFile@20');
  Inc(AdsTotalGenerated, 9);
End;

{ ------------------------------------------------------------ }
{ GenReadConsole : genere le code pour lire depuis stdin        }
{ via ReadFile(hStdIn, lpBuffer, nBytes, lpRead, 0)            }
{ Adresse du buffer dans EDI, longueur max dans ECX            }
{ ------------------------------------------------------------ }

Procedure GenReadConsole;
Var
  LblRead : TString;
Begin
  LblRead := GenAdsLabel;
  WriteLn('  ; ReadFile(hStdIn, buffer, maxlen, &bytesRead, 0)');
  WriteLn('  push 0                 ; lpOverlapped');
  WriteLn('  push offset ', LblRead, '    ; lpNumberOfBytesRead');
  WriteLn('  push ecx               ; nNumberOfBytesToRead');
  WriteLn('  push edi               ; lpBuffer');
  WriteLn('  push -10               ; STD_INPUT_HANDLE');
  WriteLn('  call _GetStdHandle@4');
  WriteLn('  push eax               ; hFile');
  WriteLn('  call _ReadFile@20');
  Inc(AdsTotalGenerated, 9);
End;

{ ------------------------------------------------------------ }
{ GenDisplayLiteral : affiche un litteral chaine sur la console }
{ Genere : push len, push offset str, WriteFile sur stdout     }
{ ------------------------------------------------------------ }

Procedure GenDisplayLiteral(S : TString);
Var
  LblStr : TString;
Begin
  LblStr := GenAdsLabel;
  WriteLn('; DISPLAY literal "', S, '"');
  WriteLn('  lea esi, [', LblStr, ']');
  WriteLn('  mov ecx, ', Length(S));
  GenWriteConsole;
  Inc(AdsDisplayLitCount);
  Inc(AdsDisplayOperands);
  Inc(AdsTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenDisplayIdent : affiche un identificateur sur la console    }
{ Charge l adresse et la taille du champ, puis WriteFile       }
{ ------------------------------------------------------------ }

Procedure GenDisplayIdent(Ident : TString; Size : Integer);
Begin
  WriteLn('; DISPLAY ident ', Ident);
  WriteLn('  lea esi, [', AsmIdent(Ident), ']');
  WriteLn('  mov ecx, ', Size);
  GenWriteConsole;
  Inc(AdsDisplayIdCount);
  Inc(AdsDisplayOperands);
  Inc(AdsTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenDisplayNumeric : affiche un identificateur numerique       }
{ Convertit la valeur numerique en chaine puis affiche          }
{ Appelle la routine runtime _COBRT_NUM_TO_STR                 }
{ ------------------------------------------------------------ }

Procedure GenDisplayNumeric(Ident : TString; Size : Integer);
Begin
  WriteLn('; DISPLAY numeric ', Ident);
  WriteLn('  lea esi, [', AsmIdent(Ident), ']');
  WriteLn('  mov ecx, ', Size);
  WriteLn('  call ', _COBRT_NUM_TO_STR');
  WriteLn('  ; EAX = adresse chaine, ECX = longueur');
  WriteLn('  mov esi, eax');
  GenWriteConsole;
  Inc(AdsDisplayNumCount);
  Inc(AdsDisplayOperands);
  Inc(AdsConversionCount);
  Inc(AdsTotalGenerated, 5);
End;

{ ------------------------------------------------------------ }
{ GenDisplayCrLf : genere le code pour afficher CR+LF (13, 10) }
{ Sauf si WITH NO ADVANCING est specifie                       }
{ ------------------------------------------------------------ }

Procedure GenDisplayCrLf;
Var
  LblCrLf : TString;
Begin
  LblCrLf := GenAdsLabel;
  WriteLn('; Retour a la ligne (CR+LF)');
  WriteLn('  lea esi, [', LblCrLf, ']   ; CR+LF');
  WriteLn('  mov ecx, 2');
  GenWriteConsole;
  Inc(AdsCrLfCount);
  Inc(AdsTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenAcceptConsole : genere le code pour ACCEPT FROM CONSOLE    }
{ Lit une ligne depuis stdin dans l identificateur              }
{ ------------------------------------------------------------ }

Procedure GenAcceptConsole(Ident : TString; Size : Integer);
Begin
  WriteLn('; ACCEPT ', Ident, ' FROM CONSOLE');
  WriteLn('  lea edi, [', AsmIdent(Ident), ']');
  WriteLn('  mov ecx, ', Size);
  GenReadConsole;
  Inc(AdsAcceptConsoleCount);
  Inc(AdsTotalGenerated, 3);
End;

{ ------------------------------------------------------------ }
{ GenAcceptDate : genere le code pour ACCEPT id FROM DATE       }
{ Date systeme au format YYMMDD (6 caracteres)                 }
{ Appelle GetLocalTime (Win32 API)                              }
{ ------------------------------------------------------------ }

Procedure GenAcceptDate(Ident : TString);
Begin
  WriteLn('; ACCEPT ', Ident, ' FROM DATE (YYMMDD)');
  WriteLn('  sub esp, 16            ; SYSTEMTIME structure (16 bytes)');
  WriteLn('  push esp');
  WriteLn('  call _GetLocalTime@4');
  WriteLn('  ; Extraire annee (mod 100), mois, jour');
  WriteLn('  movzx eax, word [esp+0]  ; wYear');
  WriteLn('  mov edx, 0');
  WriteLn('  mov ecx, 100');
  WriteLn('  div ecx                ; EDX = year mod 100');
  WriteLn('  ; Convertir en YYMMDD ASCII dans le champ');
  WriteLn('  lea edi, [', AsmIdent(Ident), ']');
  WriteLn('  call ', _COBRT_FORMAT_DATE');
  WriteLn('  add esp, 16            ; liberer SYSTEMTIME');
  Inc(AdsAcceptDateCount);
  Inc(AdsTotalGenerated, 12);
End;

{ ------------------------------------------------------------ }
{ GenAcceptDay : genere le code pour ACCEPT id FROM DAY         }
{ Jour julien au format YYDDD (5 caracteres)                   }
{ ------------------------------------------------------------ }

Procedure GenAcceptDay(Ident : TString);
Begin
  WriteLn('; ACCEPT ', Ident, ' FROM DAY (YYDDD)');
  WriteLn('  sub esp, 16            ; SYSTEMTIME structure');
  WriteLn('  push esp');
  WriteLn('  call _GetLocalTime@4');
  WriteLn('  ; Calculer le jour julien (1-366)');
  WriteLn('  lea edi, [', AsmIdent(Ident), ']');
  WriteLn('  call ', _COBRT_FORMAT_DAY');
  WriteLn('  add esp, 16');
  Inc(AdsAcceptDayCount);
  Inc(AdsTotalGenerated, 8);
End;

{ ------------------------------------------------------------ }
{ GenAcceptDayOfWeek : genere le code pour ACCEPT FROM          }
{ DAY-OF-WEEK (1 caractere, 1=lundi..7=dimanche)               }
{ ------------------------------------------------------------ }

Procedure GenAcceptDayOfWeek(Ident : TString);
Var
  LblOk : TString;
Begin
  LblOk := GenAdsLabel;
  WriteLn('; ACCEPT ', Ident, ' FROM DAY-OF-WEEK (1-7)');
  WriteLn('  sub esp, 16            ; SYSTEMTIME structure');
  WriteLn('  push esp');
  WriteLn('  call _GetLocalTime@4');
  WriteLn('  movzx eax, word [esp+4]  ; wDayOfWeek (0=dim)');
  WriteLn('  ; Convertir 0=dim en 7, 1=lun en 1, etc.');
  WriteLn('  test eax, eax');
  WriteLn('  jnz ', LblOk);
  WriteLn('  mov eax, 7');
  WriteLn(LblOk, ':');
  WriteLn('  add al, 30h            ; ASCII digit');
  WriteLn('  mov [', AsmIdent(Ident), '], al');
  WriteLn('  add esp, 16');
  Inc(AdsAcceptDayWeekCount);
  Inc(AdsTotalGenerated, 12);
End;

{ ------------------------------------------------------------ }
{ GenAcceptTime : genere le code pour ACCEPT id FROM TIME       }
{ Heure systeme au format HHMMSSCC (8 caracteres)              }
{ CC = centisecondes                                            }
{ ------------------------------------------------------------ }

Procedure GenAcceptTime(Ident : TString);
Begin
  WriteLn('; ACCEPT ', Ident, ' FROM TIME (HHMMSSCC)');
  WriteLn('  sub esp, 16            ; SYSTEMTIME structure');
  WriteLn('  push esp');
  WriteLn('  call _GetLocalTime@4');
  WriteLn('  ; Extraire heure, minute, seconde, milliseconde/10');
  WriteLn('  lea edi, [', AsmIdent(Ident), ']');
  WriteLn('  call ', _COBRT_FORMAT_TIME');
  WriteLn('  add esp, 16');
  Inc(AdsAcceptTimeCount);
  Inc(AdsTotalGenerated, 8);
End;

{ ------------------------------------------------------------ }
{ GenStopRun : genere le code pour STOP RUN                    }
{ Appelle ExitProcess(0) pour terminer le programme             }
{ ------------------------------------------------------------ }

Procedure GenStopRun;
Begin
  WriteLn('; STOP RUN');
  WriteLn('  push 0                 ; uExitCode');
  WriteLn('  call _ExitProcess@4');
  Inc(AdsStopRunCount);
  Inc(AdsTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ GenStopLiteral : genere le code pour STOP literal            }
{ Affiche le litteral puis termine avec ExitProcess(0)          }
{ ------------------------------------------------------------ }

Procedure GenStopLiteral(S : TString);
Begin
  WriteLn('; STOP literal "', S, '"');
  GenDisplayLiteral(S);
  GenDisplayCrLf;
  WriteLn('  push 0                 ; uExitCode');
  WriteLn('  call _ExitProcess@4');
  Inc(AdsStopLiteralCount);
  Inc(AdsTotalGenerated, 2);
End;

{ ------------------------------------------------------------ }
{ ParseDisplayStatement : analyser DISPLAY                     }
{ DISPLAY lit-1 [lit-2 ...] [UPON CONSOLE/PRINTER]            }
{   [WITH NO ADVANCING]                                         }
{ ------------------------------------------------------------ }

Procedure ParseDisplayStatement;
Var
  UponTarget   : Integer;
  NoAdvancing  : Boolean;
  OperandCount : Integer;
Begin
  Inc(AdsStateCount);
  UponTarget := ADS_CONSOLE;
  NoAdvancing := False;
  OperandCount := 0;

  { Traiter les operandes (litteraux, identificateurs) }
  While (CurTokType <> TOK_DOT) And
        Not ((CurTokType = TOK_KEYWORD) And
             ((CurTokNum = KW_UPON) Or (CurTokNum = KW_WITH) Or
              (CurTokNum = KW_END_DISPLAY))) Do
  Begin
    If CurTokType = TOK_STRING Then Begin
      GenDisplayLiteral(CurTokStr);
      Inc(OperandCount);
      LexNextToken;
    End
    Else If CurTokType = TOK_INTEGER Then Begin
      { Litteraux numeriques : convertir en chaine }
      GenDisplayLiteral(ItoSI(CurTokNum));
      Inc(OperandCount);
      LexNextToken;
    End
    Else If CurTokType = TOK_IDENT Then Begin
      { Identificateur : afficher le contenu du champ }
      GenDisplayIdent(CurTokStr, 0);
      Inc(OperandCount);
      LexNextToken;
    End
    Else If (CurTokType = TOK_KEYWORD) And
            Not ((CurTokNum = KW_UPON) Or (CurTokNum = KW_WITH) Or
                 (CurTokNum = KW_END_DISPLAY)) Then Begin
      { Mot-cle figuratif comme SPACES, ZEROS, etc. }
      GenDisplayLiteral(CurTokStr);
      Inc(OperandCount);
      LexNextToken;
    End
    Else
      Break;
  End;

  { Clause UPON CONSOLE/PRINTER }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_UPON) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) Then Begin
      Case CurTokNum Of
        KW_CONSOLE : UponTarget := ADS_CONSOLE;
        KW_PRINTER : UponTarget := ADS_PRINTER;
      Else
        WarnMsg('DISPLAY UPON : CONSOLE ou PRINTER attendu');
      End;
      LexNextToken;
    End
    Else If CurTokType = TOK_IDENT Then Begin
      { Nom mnemonique defini dans SPECIAL-NAMES }
      If CurTokStr = 'CONSOLE' Then
        UponTarget := ADS_CONSOLE
      Else If CurTokStr = 'PRINTER' Then
        UponTarget := ADS_PRINTER
      Else If CurTokStr = 'SYSOUT' Then
        UponTarget := ADS_CONSOLE;
      LexNextToken;
    End;
    Inc(AdsDisplayUponCount);
  End;

  { Clause WITH NO ADVANCING }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WITH) Then Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NO) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ADVANCING) Then Begin
        NoAdvancing := True;
        Inc(AdsDisplayNoAdvCount);
        LexNextToken;
      End;
    End;
  End;

  { Generer CR/LF sauf si NO ADVANCING }
  If Not NoAdvancing Then
    GenDisplayCrLf;

  { Consommer END-DISPLAY optionnel }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_DISPLAY) Then
    LexNextToken;

  Inc(AdsDisplayCount);
  Inc(AdsTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ ParseAcceptStatement : analyser ACCEPT                       }
{ ACCEPT id [FROM CONSOLE/DATE/DAY/DAY-OF-WEEK/TIME]          }
{ ------------------------------------------------------------ }

Procedure ParseAcceptStatement;
Var
  Ident      : TString;
  FromSource : Integer;
Begin
  Inc(AdsStateCount);
  FromSource := ADS_CONSOLE;  { par defaut, lire depuis la console }

  { Identificateur destination }
  If CurTokType <> TOK_IDENT Then Begin
    WarnMsg('ACCEPT : identificateur attendu');
    Exit;
  End;
  Ident := CurTokStr;
  LexNextToken;

  { Clause FROM optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FROM) Then Begin
    LexNextToken;
    If CurTokType = TOK_KEYWORD Then Begin
      Case CurTokNum Of
        KW_CONSOLE     : Begin FromSource := ADS_CONSOLE;     LexNextToken; End;
        KW_DATE        : Begin FromSource := ADS_DATE;        LexNextToken; End;
        KW_DAY         : Begin FromSource := ADS_DAY;         LexNextToken; End;
        KW_DAY_OF_WEEK : Begin FromSource := ADS_DAY_OF_WEEK; LexNextToken; End;
        KW_TIME        : Begin FromSource := ADS_TIME;        LexNextToken; End;
      Else Begin
        WarnMsg('ACCEPT FROM : source invalide ' + CurTokStr);
        LexNextToken;
      End;
      End;
    End
    Else If CurTokType = TOK_IDENT Then Begin
      { Nom mnemonique }
      If CurTokStr = 'CONSOLE' Then
        FromSource := ADS_CONSOLE
      Else If CurTokStr = 'DATE' Then
        FromSource := ADS_DATE
      Else If CurTokStr = 'DAY' Then
        FromSource := ADS_DAY
      Else If CurTokStr = 'TIME' Then
        FromSource := ADS_TIME;
      LexNextToken;
    End;
  End;

  { Generer le code selon la source }
  Case FromSource Of
    ADS_CONSOLE     : GenAcceptConsole(Ident, 80);
    ADS_DATE        : GenAcceptDate(Ident);
    ADS_DAY         : GenAcceptDay(Ident);
    ADS_DAY_OF_WEEK : GenAcceptDayOfWeek(Ident);
    ADS_TIME        : GenAcceptTime(Ident);
  End;

  { Consommer END-ACCEPT optionnel }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END_ACCEPT) Then
    LexNextToken;

  Inc(AdsAcceptCount);
  Inc(AdsTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ ParseStopStatement : analyser STOP                           }
{ STOP RUN : terminer le programme                              }
{ STOP literal : afficher le litteral puis terminer             }
{ ------------------------------------------------------------ }

Procedure ParseStopStatement;
Begin
  Inc(AdsStateCount);

  { STOP RUN }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RUN) Then Begin
    LexNextToken;
    GenStopRun;
  End
  { STOP literal }
  Else If CurTokType = TOK_STRING Then Begin
    GenStopLiteral(CurTokStr);
    LexNextToken;
  End
  Else If CurTokType = TOK_INTEGER Then Begin
    GenStopLiteral(ItoSI(CurTokNum));
    LexNextToken;
  End
  Else Begin
    { STOP sans argument = STOP RUN }
    GenStopRun;
  End;

  Inc(AdsTotalGenerated);
End;

{ ------------------------------------------------------------ }
{ ParseAcceptDisplayStatement : dispatch les instructions       }
{ ACCEPT, DISPLAY, STOP                                         }
{ ------------------------------------------------------------ }

Procedure ParseAcceptDisplayStatement;
Begin
  If CurTokType <> TOK_KEYWORD Then Exit;

  Case CurTokNum Of
    KW_DISPLAY : Begin LexNextToken; ParseDisplayStatement; End;
    KW_ACCEPT  : Begin LexNextToken; ParseAcceptStatement; End;
    KW_STOP    : Begin LexNextToken; ParseStopStatement; End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsAcceptDisplayKeyword : teste si un mot-cle est lie a       }
{ ACCEPT/DISPLAY/STOP                                           }
{ ------------------------------------------------------------ }

Function IsAcceptDisplayKeyword(KW : Integer) : Boolean;
Begin
  IsAcceptDisplayKeyword := (KW = KW_DISPLAY) Or (KW = KW_ACCEPT) Or
                            (KW = KW_STOP) Or (KW = KW_UPON) Or
                            (KW = KW_CONSOLE) Or (KW = KW_PRINTER) Or
                            (KW = KW_DATE) Or (KW = KW_DAY) Or
                            (KW = KW_DAY_OF_WEEK) Or (KW = KW_TIME) Or
                            (KW = KW_RUN) Or (KW = KW_NO) Or
                            (KW = KW_END_DISPLAY) Or (KW = KW_END_ACCEPT);
End;

{ ------------------------------------------------------------ }
{ DumpAcceptDisplayState : affiche l etat du module             }
{ ACCEPT/DISPLAY/STOP                                           }
{ ------------------------------------------------------------ }

Procedure DumpAcceptDisplayState;
Begin
  WriteLn('--- Accept/Display State ---');
  WriteLn('  Initialized       : ', AdsInitialized);
  WriteLn('  DISPLAY count     : ', AdsDisplayCount);
  WriteLn('    UPON             : ', AdsDisplayUponCount);
  WriteLn('    NO ADVANCING     : ', AdsDisplayNoAdvCount);
  WriteLn('    Operands total   : ', AdsDisplayOperands);
  WriteLn('    Literal operands : ', AdsDisplayLitCount);
  WriteLn('    Ident operands   : ', AdsDisplayIdCount);
  WriteLn('    Numeric operands : ', AdsDisplayNumCount);
  WriteLn('  ACCEPT count      : ', AdsAcceptCount);
  WriteLn('    FROM CONSOLE     : ', AdsAcceptConsoleCount);
  WriteLn('    FROM DATE        : ', AdsAcceptDateCount);
  WriteLn('    FROM DAY         : ', AdsAcceptDayCount);
  WriteLn('    FROM DAY-OF-WEEK : ', AdsAcceptDayWeekCount);
  WriteLn('    FROM TIME        : ', AdsAcceptTimeCount);
  WriteLn('  STOP RUN count    : ', AdsStopRunCount);
  WriteLn('  STOP literal      : ', AdsStopLiteralCount);
  WriteLn('  Conversions       : ', AdsConversionCount);
  WriteLn('  CR/LF generated   : ', AdsCrLfCount);
  WriteLn('  Total generated   : ', AdsTotalGenerated);
  WriteLn('  State count       : ', AdsStateCount);
End;

{ 10 fonctions accesseurs pour TODO 15                         }

Function IsAdsInitialized : Boolean;
Begin
  IsAdsInitialized := AdsInitialized;
End;

Function IsAdsEmpty : Boolean;
Begin
  IsAdsEmpty := (AdsTotalGenerated = 0);
End;

Function GetAdsTotalGenerated : Integer;
Begin
  GetAdsTotalGenerated := AdsTotalGenerated;
End;

Function GetAdsStatus : TString;
Begin
  If Not AdsInitialized Then
    GetAdsStatus := 'NON INITIALISE'
  Else
    GetAdsStatus := 'DISPLAY=' + ItoSI(AdsDisplayCount) +
                    ' ACCEPT=' + ItoSI(AdsAcceptCount) +
                    ' STOP-RUN=' + ItoSI(AdsStopRunCount);
End;

Function GetAdsDisplayCount : Integer;
Begin
  GetAdsDisplayCount := AdsDisplayCount;
End;

Function GetAdsAcceptCount : Integer;
Begin
  GetAdsAcceptCount := AdsAcceptCount;
End;

Function GetAdsStopRunCount : Integer;
Begin
  GetAdsStopRunCount := AdsStopRunCount;
End;

Function GetAdsConversionCount : Integer;
Begin
  GetAdsConversionCount := AdsConversionCount;
End;

Function GetAdsCrLfCount : Integer;
Begin
  GetAdsCrLfCount := AdsCrLfCount;
End;

Function GetAdsStateCount : Integer;
Begin
  GetAdsStateCount := AdsStateCount;
End;

{ Le tiret est permis sauf en debut/fin (WS-NOM, EMP-SALAIRE)  }
{ COBOL est insensible a la casse : tout est converti en       }
{ majuscules dans CurTokStr                                     }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S     : TString;
  EndCol : Integer;
  KW    : Integer;
Begin
  S := '';
  EndCol := LexEffectiveEnd;

  { Lire lettres, chiffres et tirets }
  While (LexColNo <= EndCol) And
        IsCobolIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Retirer les tirets en fin d identificateur }
  While (Length(S) > 0) And (S[Length(S)] = '-') Do
  Begin
    Dec(LexColNo);
    Delete(S, Length(S), 1);
  End;

  { COBOL est insensible a la casse }
  CurTokStr  := UpCaseStr(S);
  CurTokReal := 0.0;

  { Tester si c est un mot-cle COBOL }
  KW := LookupKeyword(CurTokStr);
  If KW <> KW_NONE Then
  Begin
    CurTokType := TOK_KEYWORD;
    CurTokNum  := KW;
  End
  Else
  Begin
    CurTokType := TOK_IDENT;
    CurTokNum  := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : litteral numerique COBOL                     }
{ Entier : 123, +5, -3                                         }
{ Decimal : 1.5, 3.14                                          }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
  S       : TString;
  EndCol  : Integer;
Begin
  N       := 0;
  IsReal  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  S       := '';
  EndCol  := LexEffectiveEnd;

  { Partie entiere }
  While (LexColNo <= EndCol) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie decimale }
  If (LexColNo <= EndCol) And (LexLine[LexColNo] = '.') Then
  Begin
    { Verifier que ce n est pas le terminateur d instruction }
    { Le point est decimal si suivi d un chiffre }
    If (LexColNo < EndCol) And IsDigit(LexLine[LexColNo + 1]) Then
    Begin
      IsReal := True;
      S := S + '.';
      Inc(LexColNo);
      While (LexColNo <= EndCol) And
            IsDigit(LexLine[LexColNo]) Do
      Begin
        FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
        S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
  End;

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    CurTokType := TOK_DECIMAL;
    CurTokReal := FltVal;
    If FltVal > 2147483647.0 Then CurTokNum := 2147483647
    Else If FltVal < -2147483647.0 Then CurTokNum := -2147483647
    Else CurTokNum := Trunc(FltVal);
    CurTokStr := S;
  End
  Else
  Begin
    CurTokType := TOK_INTEGER;
    CurTokNum  := N;
    CurTokReal := 0.0;
    CurTokStr  := S;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine COBOL entre apostrophes ou guillemets  }
{ 'texte' ou "texte"                                           }
{ Doublement du delimiteur pour inserer le caractere lui-meme   }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S     : TString;
  Delim : Char;
  EndCol : Integer;
Begin
  S := '';
  Delim := LexLine[LexColNo];
  EndCol := LexEffectiveEnd;
  Inc(LexColNo); { sauter le delimiteur ouvrant }

  While LexColNo <= EndCol Do
  Begin
    If LexLine[LexColNo] = Delim Then
    Begin
      Inc(LexColNo);
      { Delimiteur double : '' ou "" -> un seul caractere }
      If (LexColNo <= EndCol) And (LexLine[LexColNo] = Delim) Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + Delim;
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  CurTokType := TOK_STRING;
  CurTokStr  := S;
  CurTokNum  := 0;
  CurTokReal := 0.0;
End;

{ ------------------------------------------------------------ }
{ LexScanHexString : litteral hexadecimal COBOL X'FF' ou X"FF" }
{ ------------------------------------------------------------ }

Procedure LexScanHexString;
Var
  S     : TString;
  Delim : Char;
  EndCol : Integer;
Begin
  S := '';
  Inc(LexColNo); { sauter le X }
  EndCol := LexEffectiveEnd;

  If LexColNo > EndCol Then
  Begin
    CurTokType := TOK_HEX_STRING;
    CurTokStr  := '';
    CurTokNum  := 0;
    CurTokReal := 0.0;
    Exit;
  End;

  Delim := LexLine[LexColNo];
  Inc(LexColNo); { sauter le delimiteur ouvrant }

  While (LexColNo <= EndCol) And (LexLine[LexColNo] <> Delim) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  If (LexColNo <= EndCol) And (LexLine[LexColNo] = Delim) Then
    Inc(LexColNo); { sauter le delimiteur fermant }

  CurTokType := TOK_HEX_STRING;
  CurTokStr  := UpCaseStr(S);
  CurTokNum  := 0;
  CurTokReal := 0.0;
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', CurTokLine, ',', CurTokCol, '] ');
  Case CurTokType Of
    TOK_EOF        : Write('EOF');
    TOK_IDENT      : Write('IDENT(', CurTokStr, ')');
    TOK_INTEGER    : Write('INT(', CurTokNum, ')');
    TOK_DECIMAL    : Write('DEC(', CurTokStr, ')');
    TOK_STRING     : Write('STR(''', CurTokStr, ''')');
    TOK_HEX_STRING : Write('HEX(X''', CurTokStr, ''')');
    TOK_PLUS       : Write('PLUS');
    TOK_MINUS      : Write('MINUS');
    TOK_STAR       : Write('STAR');
    TOK_SLASH      : Write('SLASH');
    TOK_POWER      : Write('POWER');
    TOK_LPAREN     : Write('LPAREN');
    TOK_RPAREN     : Write('RPAREN');
    TOK_COMMA      : Write('COMMA');
    TOK_DOT        : Write('DOT');
    TOK_EQ         : Write('EQ');
    TOK_NE         : Write('NE');
    TOK_LT         : Write('LT');
    TOK_GT         : Write('GT');
    TOK_LE         : Write('LE');
    TOK_GE         : Write('GE');
    TOK_NEWLINE    : Write('NEWLINE');
    TOK_KEYWORD    : Write('KW(', KeywordName(CurTokNum), ')');
  Else
    Write('TOK(', CurTokType, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token COBOL           }
{ Gere le format fixe (colonnes) et le format libre            }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch     : Char;
  Done   : Boolean;
  EndCol : Integer;
Begin
  Done := False;
  While Not Done Do
  Begin
    { Avancer si on est en fin de ligne }
    EndCol := LexEffectiveEnd;
    While (Not LexEOF) And (LexColNo > EndCol) Do
    Begin
      LexNextLine;
      If LexEOF Then Break;

      { Sauter les lignes de commentaire (format fixe: * ou / en col 7) }
      While (Not LexEOF) And LexIsCommentLine Do
        LexNextLine;

      If LexEOF Then Break;

      { Sauter les lignes debug (D en colonne 7) sauf si mode debug }
      While (Not LexEOF) And LexIsDebugLine And
            (Not Opts.DebugMode) Do
        LexNextLine;

      If LexEOF Then Break;

      { Format libre : detecter les commentaires *> }
      If Opts.FreeFormat Then
      Begin
        LexColNo := 1;
        LexSkipWhitespace;
        If (LexColNo < Length(LexLine)) And
           (LexLine[LexColNo] = '*') And
           (LexLine[LexColNo + 1] = '>') Then
        Begin
          { Ligne de commentaire en format libre }
          LexNextLine;
          Continue;
        End;
      End
      Else
      Begin
        { Format fixe : gestion de la continuation (- en colonne 7) }
        If LexIsContinuationLine Then
        Begin
          { Continuation : commencer apres les espaces en zone B }
          LexPrepareFixedLine;
          LexSkipWhitespace;
        End
        Else
          LexPrepareFixedLine;
      End;

      EndCol := LexEffectiveEnd;
    End;

    If LexEOF Then
    Begin
      CurTokLine := LexLineNo;
      CurTokCol  := LexColNo;
      CurTokType := TOK_EOF;
      CurTokStr  := '';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
      Inc(LexTokCount);
      PrintToken;
      Exit;
    End;

    { Sauter les espaces }
    LexSkipWhitespace;
    EndCol := LexEffectiveEnd;
    If LexColNo > EndCol Then
      Continue;

    CurTokLine := LexLineNo;
    CurTokCol  := LexColNo;
    Ch := LexLine[LexColNo];

    { Format libre : commentaire *> en milieu de ligne }
    If Opts.FreeFormat And (Ch = '*') And
       (LexColNo < Length(LexLine)) And
       (LexLine[LexColNo + 1] = '>') Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Continue;
    End

    { Identificateur COBOL (commence par une lettre) }
    Else If IsCobolIdentStart(Ch) Then
    Begin
      { Verifier X'...' ou X"..." pour les litteraux hexadecimaux }
      If ((Ch = 'X') Or (Ch = 'x')) And
         (LexColNo < EndCol) And
         ((LexLine[LexColNo + 1] = '''') Or
          (LexLine[LexColNo + 1] = '"')) Then
      Begin
        LexScanHexString;
        Done := True;
      End
      Else
      Begin
        LexScanIdent;
        Done := True;
      End;
    End

    { Litteral numerique }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Done := True;
    End

    { Signe + ou - suivi d un chiffre au debut d un nombre }
    Else If ((Ch = '+') Or (Ch = '-')) And
            (LexColNo < EndCol) And
            IsDigit(LexLine[LexColNo + 1]) And
            { Seulement si le token precedent n est pas un ident/nombre }
            ((CurTokType = TOK_EOF) Or (CurTokType = TOK_DOT) Or
             (CurTokType = TOK_LPAREN) Or (CurTokType = TOK_COMMA) Or
             (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Or
             (CurTokType = TOK_LT) Or (CurTokType = TOK_GT) Or
             (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Or
             (CurTokType = TOK_NEWLINE)) Then
    Begin
      { Signe faisant partie d un nombre }
      { Traite comme operateur suivi de nombre : on emet l operateur }
      If Ch = '+' Then
        CurTokType := TOK_PLUS
      Else
        CurTokType := TOK_MINUS;
      CurTokStr  := Ch;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Chaine entre apostrophes ou guillemets }
    Else If (Ch = '''') Or (Ch = '"') Then
    Begin
      LexScanString;
      Done := True;
    End

    { Operateur ** (puissance) }
    Else If (Ch = '*') And (LexColNo < EndCol) And
            (LexLine[LexColNo + 1] = '*') Then
    Begin
      CurTokType := TOK_POWER;
      CurTokStr  := '**';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo, 2);
      Done := True;
    End

    { Operateur * }
    Else If Ch = '*' Then
    Begin
      CurTokType := TOK_STAR;
      CurTokStr  := '*';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Operateur + }
    Else If Ch = '+' Then
    Begin
      CurTokType := TOK_PLUS;
      CurTokStr  := '+';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Operateur - }
    Else If Ch = '-' Then
    Begin
      CurTokType := TOK_MINUS;
      CurTokStr  := '-';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Operateur / }
    Else If Ch = '/' Then
    Begin
      CurTokType := TOK_SLASH;
      CurTokStr  := '/';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Point : terminateur d instruction COBOL }
    Else If Ch = '.' Then
    Begin
      CurTokType := TOK_DOT;
      CurTokStr  := '.';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Parenthese ouvrante }
    Else If Ch = '(' Then
    Begin
      CurTokType := TOK_LPAREN;
      CurTokStr  := '(';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Parenthese fermante }
    Else If Ch = ')' Then
    Begin
      CurTokType := TOK_RPAREN;
      CurTokStr  := ')';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Virgule }
    Else If Ch = ',' Then
    Begin
      CurTokType := TOK_COMMA;
      CurTokStr  := ',';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { = (egal) }
    Else If Ch = '=' Then
    Begin
      CurTokType := TOK_EQ;
      CurTokStr  := '=';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { < : LT, <=, <> }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= EndCol) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_LE;
        CurTokStr  := '<=';
        Inc(LexColNo);
      End
      Else If (LexColNo <= EndCol) And (LexLine[LexColNo] = '>') Then
      Begin
        CurTokType := TOK_NE;
        CurTokStr  := '<>';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_LT;
        CurTokStr  := '<';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End

    { > : GT, >= }
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= EndCol) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_GE;
        CurTokStr  := '>=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_GT;
        CurTokStr  := '>';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End

    { Caractere inconnu : avertissement et avancer }
    Else
    Begin
      WarnMsg('caractere inattendu: ''' + Ch + ''' (ASCII ' +
              ItoSI(Ord(Ch)) + ') ligne ' + ItoS(LexLineNo) +
              ' colonne ' + ItoSI(LexColNo));
      Inc(LexColNo);
    End;
  End;

  If Done Then
  Begin
    Inc(LexTokCount);
    PrintToken;
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 02)                             }
{ ------------------------------------------------------------ }

Function IsLexOpened : Boolean;
Begin
  IsLexOpened := LexOpened;
End;

Function IsLexEOF : Boolean;
Begin
  IsLexEOF := LexEOF;
End;

Function GetLexLineNo : Integer;
Begin
  GetLexLineNo := LexLineNo;
End;

Function GetLexColNo : Integer;
Begin
  GetLexColNo := LexColNo;
End;

Function GetLexTokCount : LongInt;
Begin
  GetLexTokCount := LexTokCount;
End;

Function GetCurTokType : Integer;
Begin
  GetCurTokType := CurTokType;
End;

Function GetCurTokStr : TString;
Begin
  GetCurTokStr := CurTokStr;
End;

Function GetCurTokNum : LongInt;
Begin
  GetCurTokNum := CurTokNum;
End;

Function GetCurTokLine : Integer;
Begin
  GetCurTokLine := CurTokLine;
End;

Function GetLexStatus : TString;
Begin
  If Not LexOpened Then
    GetLexStatus := 'Not opened'
  Else If LexEOF Then
    GetLexStatus := 'EOF at line ' + ItoS(LexLineNo) +
                    ' (' + ItoS(LexTokCount) + ' tokens)'
  Else
    GetLexStatus := 'Line ' + ItoS(LexLineNo) +
                    ' col ' + ItoSI(LexColNo) +
                    ' (' + ItoS(LexTokCount) + ' tokens)';
End;


{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Procedure Run;
Begin
  { Initialisation des compteurs }
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;
  LexOpened  := False;
  KwInitialized := False;
  SymInitialized := False;
  HlvInitialized := False;
  ParInitialized := False;
  EcInitialized  := False;
  AgnInitialized := False;
  CtlInitialized := False;
  StrInitialized := False;
  FioInitialized := False;
  AdsInitialized := False;

  { Analyse des arguments de la ligne de commande }
  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

  { Initialiser le module de mots-cles }
  InitKeywordState;

  { Initialiser la table des symboles }
  SymInit;

  { Initialiser la gestion des niveaux }
  InitLevelState;

  { Initialiser le parseur ID/ENV DIVISION }
  InitParserIdEnv;

  { Initialiser le parseur DATA DIVISION }
  InitDataDivState;

  { Initialiser le parseur d expressions et conditions }
  InitExprCondState;

  { Initialiser le generateur d arithmetique 80386 }
  InitArithGenState;

  { Initialiser les structures de controle (IF/EVALUATE) }
  InitControlState;

  { Initialiser le module PERFORM et boucles }
  InitPerformState;

  { Initialiser le module MOVE/INITIALIZE/SET }
  InitMoveState;

  { Initialiser le module STRING/UNSTRING/INSPECT }
  InitStringState;

  { Initialiser le module E/S fichiers }
  InitFileIOState;

  { Initialiser le module ACCEPT/DISPLAY/STOP }
  InitAcceptDisplayState;

  { Ouvrir le fichier source et initialiser le lexeur }
  LexInit;

  { Fermer le fichier source }
  LexClose;

  { Statistiques finales }
  ShowStats;

  { Nettoyage }
  Cleanup;
End;

Begin
  Run;
End.
