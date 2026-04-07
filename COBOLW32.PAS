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

  TODO 06 - PARSEUR : IDENTIFICATION DIVISION ET ENVIRONMENT DIVISION [A FAIRE]
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

  TODO 07 - PARSEUR : DATA DIVISION (FILE SECTION, WORKING-STORAGE) [A FAIRE]
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

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET CONDITIONS [A FAIRE]
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

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [A FAIRE]
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

  TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, EVALUATE) [A FAIRE]
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

  TODO 11 - PARSEUR : PERFORM ET BOUCLES [A FAIRE]
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

  TODO 12 - PARSEUR : MOVE, INITIALIZE ET TRANSFERT DE DONNEES [A FAIRE]
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

  TODO 13 - PARSEUR : OPERATIONS SUR CHAINES (STRING, UNSTRING, INSPECT) [A FAIRE]
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

  TODO 14 - PARSEUR : E/S FICHIERS (OPEN, READ, WRITE, CLOSE) [A FAIRE]
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

  TODO 15 - PARSEUR : ACCEPT ET DISPLAY (E/S CONSOLE) [A FAIRE]
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

  { Nombre total de mots-cles definis }
  KW_TOTAL_KEYWORDS    = 155;  { nombre approximatif de mots-cles }

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


{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur COBOL (lettres, chiffres, -)   }
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
