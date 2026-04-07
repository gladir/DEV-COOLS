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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES COBOL [A FAIRE]
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

  TODO 04 - TABLE DES SYMBOLES COBOL (32 BITS) [A FAIRE]
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

  TODO 05 - GESTION DES NIVEAUX ET HIERARCHIE COBOL [A FAIRE]
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
  CurTokType := TOK_IDENT;
  CurTokNum  := 0;
  CurTokReal := 0.0;
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

  { Analyse des arguments de la ligne de commande }
  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

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
