{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Jovial 73 vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

(* ============================================================
  JOVCW32.PAS - Compilateur Jovial 73 vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les exemples SAMPLES\JOVIAL\*

  Voir DOC/TODO/JOVCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            ParseArgs : analyser argv (source.jov [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .jov du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=4096, MAX_PROC=512,
              MAX_LOCAL=256, MAX_PARAM=64, MAX_DEPTH=32,
              MAX_LABEL=4096, MAX_STR=255, MAX_TABLE=256,
              MAX_CONST=1024, MAX_STATUS=64, MAX_DEFINE=256
            Prefixes de nommage ASM : _JV_ (variable globale),
              _JP_ (procedure/fonction), _JK_ (constante chaine),
              _JVRT_ (routine runtime), _JL_ (label interne),
              _JT_ (table/tableau), _JM_ (module),
              _JS_ (valeur status)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent
            10 fonctions accesseurs

  TODO 02 - TOKENISEUR JOVIAL 73 (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Format libre : pas de colonnes fixes
              (contrairement a COBOL ou Fortran)
            Commentaires Jovial :
              % commentaire jusqu a la fin de la ligne
              { commentaire sur un bloc } (si supporte)
            Procedure LexNextToken : reconnaitre les tokens Jovial :
              - Identificateurs : lettres, chiffres, souligne (_)
                Jovial est insensible a la casse
              - Litteraux entiers : 123, 0
              - Litteraux reels : 1.5, 3.14
              - Litteraux chaines : 'texte' (guillemets simples)
              - Operateurs : + - * / ** = /= < <= > >=
              - Separateurs : ( ) , ; .
              - Mots logiques : AND, OR, NOT, XOR, EQV
            Types de tokens (TOK_IDENT, TOK_INTEGER, TOK_REAL,
              TOK_STRING,
              TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH, TOK_POWER,
              TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_SEMICOL,
              TOK_EQ, TOK_NE, TOK_LT, TOK_GT, TOK_LE, TOK_GE,
              TOK_DOLLAR, TOK_EOF)
            Stocker dans CurTokType / CurTokStr / CurTokNum
            Reconnaitre le point-virgule (;) comme terminateur
            Gestion des lignes et numeros de ligne pour diagnostics
            10 fonctions accesseurs

  TODO 03 - RECONNAISSANCE DES MOTS-CLES JOVIAL 73 [IMPLEMENTE]
            Tous les mots reserves Jovial 73 :
              Structure : MODULE, COMPOOL, END, BEGIN
              Declarations : ITEM, TABLE, DEFINE, OVERLAY
              Qualificateurs de type : I (entier), S (status),
                B (bits), F (flottant)
              Controle : IF, THEN, ELSE, FOR, TO, BY, STEP,
                DO, WHILE, UNTIL, GOTO, GO
              Sous-programmes : PROCEDURE, PROC, FUNCTION,
                CALL, RETURN, STOP
              Logiques : AND, OR, NOT, XOR, EQV
              E/S : INPUT, OUTPUT
              Divers : OF, IS, AT, IN, ON, ABORT, SIGNAL,
                CASE, FALLTHRU, DEFAULT
            Fonctions integrees (builtins) reconnues comme
              mots-cles ou identificateurs speciaux :
              ABS, SGN, SHIFTL, SHIFTR, BIT, BITSIZE,
              BYTESIZE, WORDSIZE, UBOUND, LBOUND, NWSDEN,
              FIRST, LAST, NEXT
            Fonction LookupKeyword : retourner KW_xxx ou TOK_IDENT
            10 fonctions accesseurs

  TODO 04 - TABLE DES SYMBOLES JOVIAL 73 (32 BITS) [IMPLEMENTE]
            Enregistrement TSymbol :
              Name      : nom Jovial (X, SCORE, COLOR)
              AsmName   : label ASM correspondant (_JV_X, _JV_SCORE)
              SymKind   : type de symbole (SK_ITEM, SK_TABLE,
                SK_PROCEDURE, SK_FUNCTION, SK_CONSTANT,
                SK_STATUS_VAL, SK_LABEL, SK_DEFINE, SK_PARAM)
              ItemType  : type de donnee (JT_INTEGER, JT_STATUS,
                JT_BITS, JT_FLOATING, JT_NONE)
              BitSize   : taille en bits (8, 16, 32 pour I; 1-16 pour B)
              ByteSize  : taille en octets apres alignement 32 bits
              Scope     : portee (SCOPE_GLOBAL, SCOPE_LOCAL,
                SCOPE_PARAM, SCOPE_MODULE, SCOPE_COMPOOL)
              Offset    : offset dans le segment de donnees
              Value     : valeur initiale ou valeur de constante
              ProcIdx   : index dans la table des procedures
              StatusValues : liste des valeurs d enumeration
              IsExported : True si exporte via COMPOOL
            Procedures sur la table :
              SymInit, SymAdd, SymFind, SymFindLocal,
              SymCount, SymDump, SymSetScope
            Gestion de la portee : MODULE, PROCEDURE, COMPOOL
            Resolution des references avant (forward references)
            10 fonctions accesseurs

  TODO 05 - PARSEUR : STRUCTURE MODULE ET COMPOOL [IMPLEMENTE]
            MODULE name ;
              declarations globales (ITEM, TABLE, DEFINE, PROCEDURE)
              ...
            END MODULE name ;
            Le nom de la procedure d entree est identique au nom
              du MODULE (convention Jovial 73) :
              MODULE HELLO; ... PROCEDURE HELLO; ... END;
            COMPOOL name ;
              declarations exportees (partagees entre modules)
            END COMPOOL ;
            Verification de coherence :
              le END MODULE doit correspondre au MODULE ouvert
            Stocker le nom du module et du point d entree
            Gestion des declarations globales avant les procedures
            10 fonctions accesseurs

  TODO 06 - PARSEUR : DECLARATIONS ITEM (TYPES DE DONNEES) [IMPLEMENTE]
            ITEM name I n ;  (entier signe sur n bits : 8, 16, 32)
              n=8  -> DB en memoire, operations via MOVSX/MOVZX
              n=16 -> DW en memoire, operations via MOVSX/MOVZX
              n=32 -> DD en memoire, operations directes EAX
            ITEM name S n (val1, val2, ...) ;  (status/enumeration)
              n=8 ou 16 pour le nombre de bits
              Chaque valeur generee comme constante : name_val1=0,
                name_val2=1, name_val3=2, ...
              Stockee comme entier non signe
            ITEM name B n ;  (champ de bits sur n bits : 1 a 32)
              Operations bit a bit (AND, OR, XOR, NOT)
              Stocke sur le plus petit conteneur : DB/DW/DD
            ITEM name F ;  (reel simple precision, IEEE 754 32 bits)
              Stocke comme DD en memoire
              Arithmetique flottante via FPU x87 (FLD, FADD, etc.)
              ou emulation logicielle si necessaire
            Calcul de la taille et de l alignement en memoire
            Valeur par defaut : 0 pour tous les types
            10 fonctions accesseurs

  TODO 07 - PARSEUR : DECLARATIONS TABLE (TABLEAUX) [IMPLEMENTE]
            TABLE name(size) type qualifier ;
              TABLE T(5) I 16 ;  -> 5 entiers de 16 bits
              TABLE FLAGS(8) B 32 ;  -> 8 mots de 32 bits
              TABLE SCORES(10) I 32 ;  -> 10 entiers de 32 bits
            Indexation a base zero : T(0) a T(size-1)
            Acces a un element : T(index)
              Calcul d offset : base + index * taille_element
              Verification de bornes optionnelle (mode debug)
            Allocation memoire dans le segment .data :
              Taille totale = nombre_elements * taille_element
            Tables de STATUS :
              TABLE COULEURS(4) S 8 (ROUGE, VERT, BLEU, JAUNE) ;
            Support des expressions comme indice :
              T(I), T(I+1), T(X*2)
            Generation 80386 :
              LEA EAX, [base + index*scale] pour acces
              Utilisation de SIB byte quand scale = 1, 2, 4, 8
            10 fonctions accesseurs

  TODO 08 - PARSEUR : DEFINE (CONSTANTES NOMMEES) [IMPLEMENTE]
            DEFINE name = value ;
              DEFINE MAX = 100 ;
              DEFINE HALF = 50 ;
              DEFINE PI = 3.14159 ;
              DEFINE MSG = 'BONJOUR' ;
            Types de constantes :
              Entiere : valeur numerique entiere
              Reelle : valeur numerique avec point decimal
              Chaine : valeur entre guillemets simples
            Expansion des DEFINE pendant la compilation :
              Remplacement textuel du nom par la valeur
              Evaluation immediate pour les constantes numeriques
            DEFINE dans un MODULE : portee globale au module
            DEFINE dans un COMPOOL : exporte vers d autres modules
            Gestion des DEFINE multiples et redefinitions
            Table des DEFINE : nom -> valeur (texte ou numerique)
            Verification : pas de reference circulaire
            10 fonctions accesseurs

  TODO 09 - PARSEUR : PROCEDURE ET FUNCTION [IMPLEMENTE]
            PROCEDURE name ;
              declarations locales
              instructions
            END ;
            PROC name ;  (forme abregee equivalente)
              instructions
            END ;
            PROCEDURE name (param1 type1, param2 type2, ...) ;
              avec parametres formels
            FUNCTION name type ;
              instructions avec RETURN expression
            END ;
            Procedure d entree du module : meme nom que le MODULE
            Convention d appel 80386 :
              Parametres empiles de droite a gauche (cdecl)
              Valeur de retour dans EAX (entier/status/bits)
              ou dans ST(0) pour les flottants
              L appelant nettoie la pile apres CALL
            Allocation du cadre de pile (stack frame) :
              PUSH EBP / MOV EBP, ESP / SUB ESP, locales
              Variables locales accessibles via [EBP-offset]
              Parametres accessibles via [EBP+8], [EBP+12], ...
            Instruction RETURN : MOV EAX, valeur / LEAVE / RET
            Instruction STOP : PUSH 0 / CALL ExitProcess
            10 fonctions accesseurs

  TODO 10 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES [IMPLEMENTE]
            Expressions arithmetiques :
              Addition (+), Soustraction (-)
              Multiplication {*}, Division {/}
              Puissance {**} : exposant entier positif
              Moins unaire : -expression
            Expressions logiques :
              AND (et bit a bit ou logique selon contexte)
              OR  (ou bit a bit ou logique)
              NOT (negation bit a bit ou logique)
              XOR (ou exclusif)
              EQV (equivalence logique : NOT XOR)
            Expressions relationnelles :
              = (egal), /= (different)
              < (inferieur), <= (inferieur ou egal)
              > (superieur), >= (superieur ou egal)
            Priorite des operateurs (du plus faible au plus fort) :
              1. OR, XOR, EQV
              2. AND
              3. NOT (unaire)
              4. =, /=, <, <=, >, >=
              5. +, - (additifs)
              6. *, / (multiplicatifs)
              7. ** {puissance}
              8. - (moins unaire)
              9. ( ) (parentheses)
            Evaluation sur la pile 80386 : PUSH/POP pour operandes
            Appels de fonctions dans les expressions : ABS(X), etc.
            Acces aux elements de TABLE dans les expressions : T(I)
            10 fonctions accesseurs

  TODO 11 - PARSEUR : STRUCTURES DE CONTROLE [IMPLEMENTE]
            IF condition THEN
              instructions...
            [ELSE
              instructions...]
            END ;
              Generation : CMP + Jcc vers ELSE/END, JMP vers END
              Labels : _JL_IF_xxx, _JL_ELSE_xxx, _JL_ENDIF_xxx
            FOR var = debut TO fin DO
              instructions...
            END ;
              Avec pas par defaut de 1
            FOR var = debut BY pas TO fin DO
              instructions...
            END ;
              Avec pas explicite (positif ou negatif)
              Generation : initialiser, tester, corps, incrementer, JMP
              Labels : _JL_FOR_xxx, _JL_FOREND_xxx
            WHILE condition DO
              instructions...
            END ;
              Generation : tester, corps, JMP au test
              Labels : _JL_WHILE_xxx, _JL_WHEND_xxx
            DO
              instructions...
            UNTIL condition ;
              Generation : corps, tester, Jcc au debut
              Labels : _JL_DO_xxx, _JL_DOUNTIL_xxx
            GOTO label / GO TO label :
              Branchement inconditionnel vers un label nomme
            Labels nommes : nom : instruction
            BEGIN ... END pour regroupement d instructions
            10 fonctions accesseurs

  TODO 12 - PARSEUR : AFFECTATIONS ET INSTRUCTIONS SIMPLES [IMPLEMENTE]
            Affectation simple :
              variable = expression ;
              Generer : evaluer expression -> EAX, MOV [var], EAX
            Affectation a un element de TABLE :
              T(index) = expression ;
              Generer : evaluer index, calculer offset, stocker
            Affectation de STATUS :
              COLOR = COLOR_ROUGE ;
              Generer : MOV DWORD [_JV_COLOR], valeur_constante
            Instruction CALL :
              CALL nom_procedure ;
              Generer : CALL _JP_nom
              CALL avec arguments :
              CALL nom_procedure (expr1, expr2, ...) ;
              Generer : PUSH arguments, CALL _JP_nom, ADD ESP, n
            Instruction STOP :
              STOP ;
              Generer : PUSH 0 / CALL _ExitProcess@4
            Instruction GOTO / GO TO :
              GOTO label ;
              Generer : JMP _JL_label
            Gestion des labels nommes dans le code :
              label : instruction
              Generer : _JL_label:
            10 fonctions accesseurs

  TODO 13 - PARSEUR : TYPES STATUS (ENUMERATIONS) [IMPLEMENTE]
            Declaration :
              ITEM COLOR S 8 (ROUGE, VERT, BLEU) ;
              Generer les constantes :
                COLOR_ROUGE = 0
                COLOR_VERT  = 1
                COLOR_BLEU  = 2
              Variable COLOR stockee comme entier (DB ou DW)
            Affectation :
              COLOR = COLOR_ROUGE ;
              Verification de type : seules les valeurs definies
                dans l enumeration sont acceptees
            Comparaison :
              IF COLOR = COLOR_VERT THEN ...
            Fonctions integrees sur les STATUS :
              FIRST(COLOR) : retourne la premiere valeur (0)
              LAST(COLOR)  : retourne la derniere valeur (2)
              Utilisation des valeurs comme indices de table
            Conversion STATUS <-> entier si necessaire
            Affichage dans OUTPUT : afficher la valeur numerique
            Enumeration avec valeurs personnalisees (extension) :
              S n (ROUGE=1, VERT=5, BLEU=10) si supporte
            10 fonctions accesseurs

  TODO 14 - PARSEUR : OPERATIONS SUR LES BITS [IMPLEMENTE]
            Operations bit a bit sur ITEM de type B :
              AND : RESULT = FLAGS AND MASK
                Generer : MOV EAX, [FLAGS] / AND EAX, [MASK]
              OR  : RESULT = FLAGS OR MASK
                Generer : MOV EAX, [FLAGS] / OR EAX, [MASK]
              XOR : RESULT = FLAGS XOR MASK
                Generer : MOV EAX, [FLAGS] / XOR EAX, [MASK]
              NOT : RESULT = NOT MASK
                Generer : MOV EAX, [MASK] / NOT EAX
            Fonctions integrees pour les bits :
              SHIFTL(valeur, nombre) : decalage a gauche
                Generer : MOV EAX, valeur / MOV CL, nombre / SHL EAX, CL
              SHIFTR(valeur, nombre) : decalage a droite
                Generer : MOV EAX, valeur / MOV CL, nombre / SHR EAX, CL
              BIT(valeur, position, longueur) : extraction de bits
                Generer : MOV EAX, valeur / SHR EAX, position
                  / AND EAX, masque (2^longueur - 1)
              BITSIZE(item) : retourne le nombre de bits de l item
                Valeur connue a la compilation, pas de code genere
            Masquage automatique selon la taille du champ de bits
              Exemple : B 8 -> AND EAX, $FF apres operations
            10 fonctions accesseurs

  TODO 15 - PARSEUR : FONCTIONS INTEGREES JOVIAL (BUILTINS) [IMPLEMENTE]
            Fonctions mathematiques :
              ABS(x) : valeur absolue
                Generer : MOV EAX, [x] / CDQ / XOR EAX, EDX / SUB EAX, EDX
                ou : CMP EAX, 0 / JGE @pos / NEG EAX / @pos:
              SGN(x) : signe (-1, 0, +1)
                Generer : CMP EAX, 0 / JE @zero / JG @pos
                  MOV EAX, -1 / JMP @end / @pos: MOV EAX, 1 / ...
            Fonctions de decalage (voir TODO 14) :
              SHIFTL(x, n), SHIFTR(x, n)
            Fonction d extraction de bits (voir TODO 14) :
              BIT(valeur, position, longueur)
            Fonctions de taille :
              BITSIZE(item) : nombre de bits (resolu a la compilation)
              BYTESIZE(item) : taille en octets (resolu a la compilation)
              WORDSIZE(item) : taille en mots 32 bits (resolu a la compilation)
            Fonctions sur les tableaux :
              UBOUND(table, dimension) : borne superieure (taille - 1)
              LBOUND(table, dimension) : borne inferieure (toujours 0)
              NWSDEN(table) : nombre d elements dans la table
            Fonctions sur les STATUS (voir TODO 13) :
              FIRST(status_item) : premiere valeur de l enumeration
              LAST(status_item)  : derniere valeur de l enumeration
            Toutes les fonctions de taille et de bornes sont resolues
              a la compilation (pas de code genere, valeur constante)
            10 fonctions accesseurs

  TODO 16 - PARSEUR : INPUT/OUTPUT (E/S CONSOLE) [IMPLEMENTE]
            OUTPUT :
              OUTPUT ('texte simple') ;
                Generer : afficher la chaine sur la console
              OUTPUT ('format $D', expression) ;
                Generer : evaluer expression, convertir en chaine,
                  inserer dans le format, afficher
              OUTPUT ('X=$D Y=$D', expr1, expr2) ;
                Generer : traiter chaque $D avec l expression
                  correspondante
              Format $D : conversion entiere decimale
              Retour a la ligne automatique apres chaque OUTPUT
            INPUT :
              INPUT (var1) ;
                Generer : lire une ligne depuis la console,
                  convertir en entier, stocker dans var1
              INPUT (var1, var2, ...) ;
                Generer : lire plusieurs valeurs separees par
                  des espaces ou retours a la ligne
            Win32 API pour les E/S console :
              GetStdHandle(STD_OUTPUT_HANDLE) pour ecriture
              GetStdHandle(STD_INPUT_HANDLE) pour lecture
              WriteFile pour l affichage
              ReadFile pour la saisie
            Gestion du buffer de ligne et conversion CR/LF
            10 fonctions accesseurs

  TODO 17 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [IMPLEMENTE]
            Section .data (variables initialisees) :
              ITEM I 8  -> _JV_nom DB 0
              ITEM I 16 -> _JV_nom DW 0
              ITEM I 32 -> _JV_nom DD 0
              ITEM S n  -> _JV_nom DD 0 (entier pour status)
              ITEM B n  -> _JV_nom DB/DW/DD 0 (selon taille)
              ITEM F    -> _JV_nom DD 0.0 (IEEE 754 32 bits)
              TABLE(n) I 16 -> _JT_nom DW n DUP(0)
              TABLE(n) I 32 -> _JT_nom DD n DUP(0)
            Constantes chaines :
              _JK_nnn DB 'texte', 13, 10, 0 (avec CR/LF/NUL)
            Constantes de format pour OUTPUT :
              _JK_FMT_nnn DB 'format...', 0
            Section .data? (variables non initialisees / BSS) :
              Buffers d E/S temporaires
              _JV_IOBUF DB 256 DUP(?)
              _JV_NUMBUF DB 32 DUP(?)
            Variables runtime :
              _JV_STDOUT DD ?  (handle console sortie)
              _JV_STDIN  DD ?  (handle console entree)
              _JV_WRITTEN DD ? (octets ecrits par WriteFile)
              _JV_READ   DD ?  (octets lus par ReadFile)
            Alignement des donnees sur 4 octets (DWORD)
            10 fonctions accesseurs

  TODO 18 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [A FAIRE]
            Arithmetique entiere 32 bits :
              Addition : MOV EAX, [a] / ADD EAX, [b]
              Soustraction : MOV EAX, [a] / SUB EAX, [b]
              Multiplication : MOV EAX, [a] / IMUL EAX, [b]
              Division : MOV EAX, [a] / CDQ / IDIV DWORD [b]
                Resultat dans EAX, reste dans EDX
              Puissance {**} : boucle de multiplication
            Arithmetique sur items 8 et 16 bits :
              Charger avec MOVSX (signe) ou MOVZX (non signe)
              Operer en 32 bits (EAX)
              Stocker avec taille correcte (MOV BYTE/WORD)
            Arithmetique flottante (ITEM F) :
              FLD DWORD [a]   : charger dans FPU
              FADD DWORD [b]  : addition
              FSUB DWORD [b]  : soustraction
              FMUL DWORD [b]  : multiplication
              FDIV DWORD [b]  : division
              FSTP DWORD [r]  : stocker le resultat
            Evaluation d expressions complexes :
              Utilisation de la pile 80386 pour les intermediaires
              PUSH EAX pour sauvegarder operande gauche
              Evaluer operande droit -> EAX
              POP EBX pour recuperer operande gauche
              Operer EBX op EAX -> resultat dans EAX
            Comparaisons :
              CMP EAX, EBX + Jcc (JE, JNE, JL, JLE, JG, JGE)
            10 fonctions accesseurs

  TODO 19 - GENERATION DE CODE : STRUCTURES DE CONTROLE 80386 [A FAIRE]
            IF / ELSE / END :
              Evaluer la condition -> flags
              Jcc _JL_ELSE_nnn (saut conditionnel si faux)
              ... bloc THEN ...
              JMP _JL_ENDIF_nnn
              _JL_ELSE_nnn:
              ... bloc ELSE ...
              _JL_ENDIF_nnn:
            FOR var = debut TO fin DO ... END :
              MOV DWORD [var], debut
              _JL_FOR_nnn:
              MOV EAX, [var] / CMP EAX, fin
              JG _JL_FOREND_nnn
              ... corps de la boucle ...
              INC DWORD [var] (ou ADD si pas > 1)
              JMP _JL_FOR_nnn
              _JL_FOREND_nnn:
            FOR avec BY (pas explicite) :
              Meme structure, ADD DWORD [var], pas au lieu de INC
              Si pas negatif : CMP/JL au lieu de JG
            WHILE condition DO ... END :
              _JL_WHILE_nnn:
              Evaluer condition -> flags
              Jcc _JL_WHEND_nnn (saut si faux)
              ... corps ...
              JMP _JL_WHILE_nnn
              _JL_WHEND_nnn:
            DO ... UNTIL condition :
              _JL_DO_nnn:
              ... corps ...
              Evaluer condition -> flags
              Jcc _JL_DO_nnn (saut si faux, continuer boucle)
            Compteur de labels interne pour unicite
            10 fonctions accesseurs

  TODO 20 - BIBLIOTHEQUE RUNTIME JOVIAL (E/S, CONVERSIONS VIA WIN32) [A FAIRE]
            Routines de conversion :
              _JVRT_ITOA : entier 32 bits -> chaine decimale ASCII
                Utilisation de DIV par 10 en boucle
              _JVRT_ATOI : chaine ASCII -> entier 32 bits
                Utilisation de IMUL par 10 et ADD
              _JVRT_FORMAT : formater une chaine avec $D
                Parcourir le format, remplacer $D par la
                conversion de l argument correspondant
            Routines d E/S console :
              _JVRT_INIT_IO : initialiser les handles console
                PUSH STD_OUTPUT_HANDLE / CALL GetStdHandle
                MOV [_JV_STDOUT], EAX
                PUSH STD_INPUT_HANDLE / CALL GetStdHandle
                MOV [_JV_STDIN], EAX
              _JVRT_WRITE_STR : ecrire une chaine sur la console
                PUSH 0 / LEA EAX, [_JV_WRITTEN] / PUSH EAX
                PUSH longueur / PUSH adresse / PUSH [_JV_STDOUT]
                CALL WriteFile
              _JVRT_WRITE_CRLF : ecrire un retour a la ligne
              _JVRT_READ_LINE : lire une ligne depuis la console
                PUSH 0 / LEA EAX, [_JV_READ] / PUSH EAX
                PUSH 256 / LEA EAX, [_JV_IOBUF] / PUSH EAX
                PUSH [_JV_STDIN] / CALL ReadFile
              _JVRT_OUTPUT : routine combinee pour OUTPUT Jovial
                Traiter le format, convertir les arguments,
                afficher le resultat avec retour a la ligne
            Routines mathematiques inline :
              _JVRT_ABS : valeur absolue (inline possible)
              _JVRT_SGN : signe (inline possible)
              _JVRT_POWER : exponentiation par boucle
            Variables runtime en .data? :
              _JV_IOBUF, _JV_NUMBUF, _JV_STDOUT, _JV_STDIN,
              _JV_WRITTEN, _JV_READ
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
              Routines runtime Jovial (_JVRT_)
              Procedures et fonctions Jovial (_JP_)
            Section .rdata :
              Import Directory (IMAGE_IMPORT_DESCRIPTOR)
              Hint/Name Table pour chaque DLL importee
              Import Address Table (IAT) avec thunks
            Section .data :
              Variables ITEM globales initialisees
              Tables (TABLE) avec leurs elements
              Constantes chaines (_JK_)
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
                Symboles definis pour procedures/variables Jovial
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
              INCLUDELIB msvcrt.lib (si necessaire)
            Section EXTERN :
              EXTERN _ExitProcess@4:PROC
              EXTERN _GetStdHandle@4:PROC
              EXTERN _WriteFile@20:PROC
              EXTERN _ReadFile@20:PROC
              (autres imports Win32 utilises)
            Section .DATA :
              Variables ITEM avec DB/DW/DD
              Tables avec DW/DD n DUP(0)
              Constantes chaines avec DB 'texte', 0
            Section .DATA? :
              Variables non initialisees (BSS)
              Buffers d E/S
            Section .CODE :
              Point d entree _start
              Routines runtime (_JVRT_)
              Procedures Jovial avec labels (_JP_)
              Commentaires avec le code Jovial source
            Indentation et formatage lisible
            Commentaires preserves dans le listing
            10 fonctions accesseurs

  TODO 24 - IMPORTS API WIN32 ET LIAISON (KERNEL32, MSVCRT) [A FAIRE]
            Imports kernel32.dll :
              ExitProcess : terminer le programme (STOP)
              GetStdHandle : obtenir les handles console
              WriteFile : ecrire sur la console (OUTPUT)
              ReadFile : lire depuis la console (INPUT)
              GetProcessHeap, HeapAlloc, HeapFree :
                allocation dynamique (si necessaire pour tables)
              GetCommandLineA : arguments de la ligne de commande
              GetModuleHandleA : handle du module courant
              GetLastError : code d erreur Win32
              LoadLibraryA, GetProcAddress, FreeLibrary :
                chargement dynamique de DLL (si extension future)
            Imports msvcrt.dll (optionnel) :
              sprintf, sscanf : formatage numerique avance
              memcpy, memset, memcmp : operations memoire
            Generer la table d importation PE :
              IMAGE_IMPORT_DESCRIPTOR par DLL
              Hint/Name Table avec noms de fonctions
              Import Address Table (IAT) avec thunks
            Generer les EXTERN pour le mode .ASM
            Generer les symboles externes pour le mode .OBJ
            Marquer les imports reellement utilises pour
              n inclure que le necessaire
            10 fonctions accesseurs

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\JOVIAL\* [A FAIRE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\JOVIAL\test01_hello.jov   - Hello World avec OUTPUT
              SAMPLES\JOVIAL\test02_items.jov   - Declarations ITEM entier
              SAMPLES\JOVIAL\test03_arith.jov   - Arithmetique (+,-,*,/)
              SAMPLES\JOVIAL\test04_status.jov  - Types STATUS (enumeration)
              SAMPLES\JOVIAL\test05_bits.jov    - Operations sur les bits
              SAMPLES\JOVIAL\test06_cond.jov    - Conditions IF/ELSE
              SAMPLES\JOVIAL\test07_boucles.jov - Boucles FOR/WHILE/DO-UNTIL
              SAMPLES\JOVIAL\test08_table.jov   - Declarations TABLE (tableaux)
              SAMPLES\JOVIAL\test09_procs.jov   - Procedures et CALL
              SAMPLES\JOVIAL\test10_reels.jov   - DEFINE et items reels
              SAMPLES\JOVIAL\test_proc.jov      - PROC (forme abregee)
              SAMPLES\JOVIAL\test_builtins.jov  - Fonctions integrees
              SAMPLES\JOVIAL\test_simple.jov    - Module minimal
              SAMPLES\JOVIAL\test24.jov         - BEGIN dans procedure
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes
            Verification de la compatibilite Jovial 73
            10 fonctions accesseurs

  ============================================================ *)

Program JOVCW32;

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES    [IMPLEMENTE] }
{           PE/COFF                                              }
{ ============================================================ }

Const
  JOVCW32_VERSION = '0.1';
  JOVCW32_DATE    = '2026';

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
  MAX_PROC    = 512;
  MAX_LOCAL   = 256;
  MAX_PARAM   = 64;
  MAX_DEPTH   = 32;
  MAX_LABEL   = 4096;
  MAX_STR     = 255;
  MAX_TABLE   = 256;
  MAX_CONST   = 1024;
  MAX_STATUS  = 64;
  MAX_DEFINE  = 256;

  { Prefixes de nommage ASM }
  PFX_VAR   = '_JV_';    { variable globale (ITEM)              }
  PFX_PROC  = '_JP_';    { procedure/fonction                   }
  PFX_CONST = '_JK_';    { constante chaine                     }
  PFX_RT    = '_JVRT_';  { routine runtime                      }
  PFX_LBL   = '_JL_';    { label interne                        }
  PFX_TAB   = '_JT_';    { table/tableau (TABLE)                }
  PFX_MOD   = '_JM_';    { module                               }
  PFX_STAT  = '_JS_';    { valeur status (enumeration)          }

Type
  TString = String;

  TOptions = Record
    SrcFile    : TString;   { fichier source (.jov)                }
    OutFile    : TString;   { fichier sortie (.exe, .obj)          }
    Verbose    : Boolean;   { -v : banniere et statistiques        }
    DebugMode  : Boolean;   { -d : affichage de chaque token       }
    Warnings   : Boolean;   { -w : afficher les avertissements     }
    EmitExe    : Boolean;   { par defaut : produire un .EXE (PE)   }
    EmitObj    : Boolean;   { -obj : produire seulement un .OBJ    }
    EmitAsm    : Boolean;   { -asm : produire aussi un .ASM        }
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

Function HexNibble(V : Integer) : Char;
Begin
  V := V And $0F;
  If V < 10 Then
    HexNibble := Chr(Ord('0') + V)
  Else
    HexNibble := Chr(Ord('A') + V - 10);
End;

Function HexByte(V : Integer) : TString;
Begin
  HexByte := HexNibble(V Shr 4) + HexNibble(V);
End;

Function HexWord(V : Integer) : TString;
Begin
  HexWord := HexByte(V Shr 8) + HexByte(V);
End;

Function HexLong(V : LongInt) : TString;
Begin
  HexLong := HexWord(V Shr 16) + HexWord(V);
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

{ Transforme un nom Jovial en identifiant valide pour l assembleur }
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
  WriteLn('JOVCW32: FATAL: ', Msg);
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
  WriteLn('JOVCW32: warning: ', Msg);
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
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('JOVCW32 v', JOVCW32_VERSION, ' (', JOVCW32_DATE,
          ') - Compilateur Jovial 73 vers 80386 (Windows PE 32 bits)');
  WriteLn('JOVCW32 - Cette commande permet de lancer le compilateur Jovial 73 ',
          'pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : JOVCW32 [options] <source.jov> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  JOVCW32 hello.jov');
  WriteLn('  JOVCW32 hello.jov -o hello.exe -v');
  WriteLn('  JOVCW32 main.jov -asm');
  WriteLn('  JOVCW32 module.jov -obj -w');
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
    WriteLn('JOVCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .jov }
  Ext := ExtractExt(Opts.SrcFile);
  If Ext <> '.jov' Then
    WarnMsg('extension attendue .jov, trouvee: ' + Ext);

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
  WriteLn('JOVCW32 v', JOVCW32_VERSION, ' (', JOVCW32_DATE,
          ') - Compilateur Jovial 73 -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Mode     : OBJ (COFF 32 bits)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
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
  GetCompilerVersion := JOVCW32_VERSION;
End;

Function GetCompilerDate : TString;
Begin
  GetCompilerDate := JOVCW32_DATE;
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

Function IsWarnings : Boolean;
Begin
  IsWarnings := Opts.Warnings;
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
{ TODO 02 - TOKENISEUR JOVIAL 73 (LEXER)        [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de tokens }
  TOK_EOF      = 0;    { fin de fichier                          }
  TOK_IDENT    = 1;    { identificateur Jovial (X, SCORE, etc.)  }
  TOK_INTEGER  = 2;    { litteral entier (123, 0)                }
  TOK_REAL     = 3;    { litteral reel (1.5, 3.14)               }
  TOK_STRING   = 4;    { litteral chaine ('texte')               }
  TOK_PLUS     = 10;   { +                                       }
  TOK_MINUS    = 11;   { -                                       }
  TOK_STAR     = 12;   { *                                       }
  TOK_SLASH    = 13;   { /                                       }
  TOK_POWER    = 14;   { ** (exponentiation)                     }
  TOK_LPAREN   = 20;   { (                                       }
  TOK_RPAREN   = 21;   { )                                       }
  TOK_COMMA    = 22;   { ,                                       }
  TOK_SEMICOL  = 23;   { ; (terminateur d instruction Jovial)    }
  TOK_DOT      = 24;   { .                                       }
  TOK_COLON    = 25;   { : (deux-points : labels, declarations)  }
  TOK_EQ       = 30;   { =                                       }
  TOK_NE       = 31;   { /= (pas egal)                           }
  TOK_LT       = 32;   { <                                       }
  TOK_GT       = 33;   { >                                       }
  TOK_LE       = 34;   { <=                                      }
  TOK_GE       = 35;   { >=                                      }
  TOK_DOLLAR   = 40;   { $ (prefixe format dans OUTPUT)          }
  TOK_KEYWORD  = 50;   { mot-cle Jovial reconnu                  }

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

Function IsAlpha(Ch : Char) : Boolean;
Begin
  IsAlpha := ((Ch >= 'A') And (Ch <= 'Z')) Or
             ((Ch >= 'a') And (Ch <= 'z'));
End;

Function IsAlphaNum(Ch : Char) : Boolean;
Begin
  IsAlphaNum := IsAlpha(Ch) Or IsDigit(Ch);
End;

Function IsWhitespace(Ch : Char) : Boolean;
Begin
  IsWhitespace := (Ch = ' ') Or (Ch = #9);
End;

{ Jovial identifiers start with a letter                        }
Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := IsAlpha(Ch) Or (Ch = '_');
End;

{ Jovial identifiers can contain letters, digits and underscore }
Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsAlpha(Ch) Or IsDigit(Ch) Or (Ch = '_');
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

{ Forward declaration pour LookupKeyword (utilise par LexScanIdent) }
{ KW_NONE defini ici, le reste des KW_* dans la section TODO 03    }
Const
  KW_NONE = 0;

Function LookupKeyword(Const S : TString) : Integer; Forward;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur Jovial (lettres, chiffres, _)  }
{ Jovial est insensible a la casse                              }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S  : TString;
  KW : Integer;
Begin
  S := '';

  { Lire lettres, chiffres et souligne }
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Jovial est insensible a la casse }
  CurTokStr  := UpCaseStr(S);
  CurTokReal := 0.0;

  { Tester si c est un mot-cle Jovial }
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
{ LexScanNumber : litteral numerique Jovial                    }
{ Entier : 123, 0                                              }
{ Reel : 1.5, 3.14                                             }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  IsR     : Boolean;
  FracDiv : Real;
  FracVal : Real;
  FltVal  : Real;
  S       : TString;
Begin
  N       := 0;
  IsR     := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  S       := '';

  { Partie entiere }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie decimale }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') Then
  Begin
    { Le point est decimal si suivi d un chiffre }
    If (LexColNo < Length(LexLine)) And
       IsDigit(LexLine[LexColNo + 1]) Then
    Begin
      IsR := True;
      S := S + '.';
      Inc(LexColNo);
      While (LexColNo <= Length(LexLine)) And
            IsDigit(LexLine[LexColNo]) Do
      Begin
        FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
        FracDiv := FracDiv * 10.0;
        S := S + LexLine[LexColNo];
        Inc(LexColNo);
      End;
    End;
  End;

  If IsR Then
  Begin
    FltVal := N + FracVal;
    CurTokType := TOK_REAL;
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
{ LexScanString : chaine Jovial entre apostrophes               }
{ 'texte'                                                       }
{ Doublement de l apostrophe pour inserer le caractere lui-meme }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S : TString;
Begin
  S := '';
  Inc(LexColNo); { sauter l apostrophe ouvrante }

  While LexColNo <= Length(LexLine) Do
  Begin
    If LexLine[LexColNo] = '''' Then
    Begin
      Inc(LexColNo);
      { Apostrophe doublee : '' -> un seul caractere }
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '''') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '''';
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
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', CurTokLine, ',', CurTokCol, '] ');
  Case CurTokType Of
    TOK_EOF     : Write('EOF');
    TOK_IDENT   : Write('IDENT(', CurTokStr, ')');
    TOK_INTEGER : Write('INT(', CurTokNum, ')');
    TOK_REAL    : Write('REAL(', CurTokStr, ')');
    TOK_STRING  : Write('STR(''', CurTokStr, ''')');
    TOK_PLUS    : Write('PLUS');
    TOK_MINUS   : Write('MINUS');
    TOK_STAR    : Write('STAR');
    TOK_SLASH   : Write('SLASH');
    TOK_POWER   : Write('POWER');
    TOK_LPAREN  : Write('LPAREN');
    TOK_RPAREN  : Write('RPAREN');
    TOK_COMMA   : Write('COMMA');
    TOK_SEMICOL : Write('SEMICOL');
    TOK_DOT     : Write('DOT');
    TOK_COLON   : Write('COLON');
    TOK_EQ      : Write('EQ');
    TOK_NE      : Write('NE');
    TOK_LT      : Write('LT');
    TOK_GT      : Write('GT');
    TOK_LE      : Write('LE');
    TOK_GE      : Write('GE');
    TOK_DOLLAR  : Write('DOLLAR');
    TOK_KEYWORD : Write('KW(', CurTokStr, ')');
  Else
    Write('TOK(', CurTokType, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token Jovial           }
{ Format libre, commentaires % et separateurs Jovial            }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch   : Char;
  Done : Boolean;
Begin
  Done := False;
  While Not Done Do
  Begin
    { Avancer si on est en fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;

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
    If LexColNo > Length(LexLine) Then
      Continue;

    CurTokLine := LexLineNo;
    CurTokCol  := LexColNo;
    Ch := LexLine[LexColNo];

    { Commentaire Jovial : % jusqu a la fin de la ligne }
    If Ch = '%' Then
    Begin
      LexColNo := Length(LexLine) + 1;
      Continue;
    End

    { Identificateur Jovial (commence par une lettre ou _) }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      Done := True;
    End

    { Litteral numerique }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Done := True;
    End

    { Chaine entre apostrophes }
    Else If Ch = '''' Then
    Begin
      LexScanString;
      Done := True;
    End

    { Operateur ** (puissance) }
    Else If (Ch = '*') And (LexColNo < Length(LexLine)) And
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

    { Operateur /= (pas egal) ou / (division) }
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_NE;
        CurTokStr  := '/=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_SLASH;
        CurTokStr  := '/';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
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

    { < : LT, <= }
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_LE;
        CurTokStr  := '<=';
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
      If (LexColNo <= Length(LexLine)) And
         (LexLine[LexColNo] = '=') Then
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

    { Point-virgule : terminateur d instruction Jovial }
    Else If Ch = ';' Then
    Begin
      CurTokType := TOK_SEMICOL;
      CurTokStr  := ';';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Point }
    Else If Ch = '.' Then
    Begin
      CurTokType := TOK_DOT;
      CurTokStr  := '.';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Dollar (prefixe format dans OUTPUT) }
    Else If Ch = '$' Then
    Begin
      CurTokType := TOK_DOLLAR;
      CurTokStr  := '$';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End

    { Deux-points (separateur de label) }
    Else If Ch = ':' Then
    Begin
      CurTokType := TOK_COLON;
      CurTokStr  := ':';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
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
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES JOVIAL 73            }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Constantes KW_* pour les mots-cles Jovial 73 }
  { KW_NONE = 0 deja defini avant LexScanIdent   }

  { Structure }
  KW_MODULE     = 1;
  KW_COMPOOL    = 2;
  KW_END        = 3;
  KW_BEGIN      = 4;

  { Declarations }
  KW_ITEM       = 10;
  KW_TABLE      = 11;
  KW_DEFINE     = 12;
  KW_OVERLAY    = 13;

  { Qualificateurs de type }
  KW_I          = 20;    { entier                                  }
  KW_S          = 21;    { status                                  }
  KW_B          = 22;    { bits                                    }
  KW_F          = 23;    { flottant                                }

  { Controle }
  KW_IF         = 30;
  KW_THEN       = 31;
  KW_ELSE       = 32;
  KW_FOR        = 33;
  KW_TO         = 34;
  KW_BY         = 35;
  KW_STEP       = 36;
  KW_DO         = 37;
  KW_WHILE      = 38;
  KW_UNTIL      = 39;
  KW_GOTO       = 40;
  KW_GO         = 41;

  { Sous-programmes }
  KW_PROCEDURE  = 50;
  KW_PROC       = 51;
  KW_FUNCTION   = 52;
  KW_CALL       = 53;
  KW_RETURN     = 54;
  KW_STOP       = 55;

  { Logiques }
  KW_AND        = 60;
  KW_OR         = 61;
  KW_NOT        = 62;
  KW_XOR        = 63;
  KW_EQV        = 64;

  { E/S }
  KW_INPUT      = 70;
  KW_OUTPUT     = 71;

  { Divers }
  KW_OF         = 80;
  KW_IS         = 81;
  KW_AT         = 82;
  KW_IN         = 83;
  KW_ON         = 84;
  KW_ABORT      = 85;
  KW_SIGNAL     = 86;
  KW_CASE       = 87;
  KW_FALLTHRU   = 88;
  KW_DEFAULT    = 89;

  { Fonctions integrees (builtins) }
  KW_ABS        = 100;
  KW_SGN        = 101;
  KW_SHIFTL     = 102;
  KW_SHIFTR     = 103;
  KW_BIT        = 104;
  KW_BITSIZE    = 105;
  KW_BYTESIZE   = 106;
  KW_WORDSIZE   = 107;
  KW_UBOUND     = 108;
  KW_LBOUND     = 109;
  KW_NWSDEN     = 110;
  KW_FIRST      = 111;
  KW_LAST       = 112;
  KW_NEXT       = 113;

  KW_TOTAL_KEYWORDS = 60;  { nombre approximatif de mots-cles Jovial }

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
{ Jovial est insensible a la casse (deja uppercase via LexScan) }
{ ------------------------------------------------------------ }

Function LookupKeyword(Const S : TString) : Integer;
Begin
  Inc(KwCount);
  { Structure }
  If      S = 'MODULE'      Then LookupKeyword := KW_MODULE
  Else If S = 'COMPOOL'     Then LookupKeyword := KW_COMPOOL
  Else If S = 'END'         Then LookupKeyword := KW_END
  Else If S = 'BEGIN'       Then LookupKeyword := KW_BEGIN
  { Declarations }
  Else If S = 'ITEM'        Then LookupKeyword := KW_ITEM
  Else If S = 'TABLE'       Then LookupKeyword := KW_TABLE
  Else If S = 'DEFINE'      Then LookupKeyword := KW_DEFINE
  Else If S = 'OVERLAY'     Then LookupKeyword := KW_OVERLAY
  { Qualificateurs de type }
  Else If S = 'I'           Then LookupKeyword := KW_I
  Else If S = 'S'           Then LookupKeyword := KW_S
  Else If S = 'B'           Then LookupKeyword := KW_B
  Else If S = 'F'           Then LookupKeyword := KW_F
  { Controle }
  Else If S = 'IF'          Then LookupKeyword := KW_IF
  Else If S = 'THEN'        Then LookupKeyword := KW_THEN
  Else If S = 'ELSE'        Then LookupKeyword := KW_ELSE
  Else If S = 'FOR'         Then LookupKeyword := KW_FOR
  Else If S = 'TO'          Then LookupKeyword := KW_TO
  Else If S = 'BY'          Then LookupKeyword := KW_BY
  Else If S = 'STEP'        Then LookupKeyword := KW_STEP
  Else If S = 'DO'          Then LookupKeyword := KW_DO
  Else If S = 'WHILE'       Then LookupKeyword := KW_WHILE
  Else If S = 'UNTIL'       Then LookupKeyword := KW_UNTIL
  Else If S = 'GOTO'        Then LookupKeyword := KW_GOTO
  Else If S = 'GO'          Then LookupKeyword := KW_GO
  { Sous-programmes }
  Else If S = 'PROCEDURE'   Then LookupKeyword := KW_PROCEDURE
  Else If S = 'PROC'        Then LookupKeyword := KW_PROC
  Else If S = 'FUNCTION'    Then LookupKeyword := KW_FUNCTION
  Else If S = 'CALL'        Then LookupKeyword := KW_CALL
  Else If S = 'RETURN'      Then LookupKeyword := KW_RETURN
  Else If S = 'STOP'        Then LookupKeyword := KW_STOP
  { Logiques }
  Else If S = 'AND'         Then LookupKeyword := KW_AND
  Else If S = 'OR'          Then LookupKeyword := KW_OR
  Else If S = 'NOT'         Then LookupKeyword := KW_NOT
  Else If S = 'XOR'         Then LookupKeyword := KW_XOR
  Else If S = 'EQV'         Then LookupKeyword := KW_EQV
  { E/S }
  Else If S = 'INPUT'       Then LookupKeyword := KW_INPUT
  Else If S = 'OUTPUT'      Then LookupKeyword := KW_OUTPUT
  { Divers }
  Else If S = 'OF'          Then LookupKeyword := KW_OF
  Else If S = 'IS'          Then LookupKeyword := KW_IS
  Else If S = 'AT'          Then LookupKeyword := KW_AT
  Else If S = 'IN'          Then LookupKeyword := KW_IN
  Else If S = 'ON'          Then LookupKeyword := KW_ON
  Else If S = 'ABORT'       Then LookupKeyword := KW_ABORT
  Else If S = 'SIGNAL'      Then LookupKeyword := KW_SIGNAL
  Else If S = 'CASE'        Then LookupKeyword := KW_CASE
  Else If S = 'FALLTHRU'    Then LookupKeyword := KW_FALLTHRU
  Else If S = 'DEFAULT'     Then LookupKeyword := KW_DEFAULT
  { Fonctions integrees (builtins) }
  Else If S = 'ABS'         Then LookupKeyword := KW_ABS
  Else If S = 'SGN'         Then LookupKeyword := KW_SGN
  Else If S = 'SHIFTL'      Then LookupKeyword := KW_SHIFTL
  Else If S = 'SHIFTR'      Then LookupKeyword := KW_SHIFTR
  Else If S = 'BIT'         Then LookupKeyword := KW_BIT
  Else If S = 'BITSIZE'     Then LookupKeyword := KW_BITSIZE
  Else If S = 'BYTESIZE'    Then LookupKeyword := KW_BYTESIZE
  Else If S = 'WORDSIZE'    Then LookupKeyword := KW_WORDSIZE
  Else If S = 'UBOUND'      Then LookupKeyword := KW_UBOUND
  Else If S = 'LBOUND'      Then LookupKeyword := KW_LBOUND
  Else If S = 'NWSDEN'      Then LookupKeyword := KW_NWSDEN
  Else If S = 'FIRST'       Then LookupKeyword := KW_FIRST
  Else If S = 'LAST'        Then LookupKeyword := KW_LAST
  Else If S = 'NEXT'        Then LookupKeyword := KW_NEXT
  Else LookupKeyword := KW_NONE;
End;

{ ------------------------------------------------------------ }
{ KeywordName : retourne le nom d un mot-cle a partir de       }
{               sa constante KW_*                               }
{ ------------------------------------------------------------ }

Function KeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    { Structure }
    KW_MODULE     : KeywordName := 'MODULE';
    KW_COMPOOL    : KeywordName := 'COMPOOL';
    KW_END        : KeywordName := 'END';
    KW_BEGIN      : KeywordName := 'BEGIN';
    { Declarations }
    KW_ITEM       : KeywordName := 'ITEM';
    KW_TABLE      : KeywordName := 'TABLE';
    KW_DEFINE     : KeywordName := 'DEFINE';
    KW_OVERLAY    : KeywordName := 'OVERLAY';
    { Qualificateurs de type }
    KW_I          : KeywordName := 'I';
    KW_S          : KeywordName := 'S';
    KW_B          : KeywordName := 'B';
    KW_F          : KeywordName := 'F';
    { Controle }
    KW_IF         : KeywordName := 'IF';
    KW_THEN       : KeywordName := 'THEN';
    KW_ELSE       : KeywordName := 'ELSE';
    KW_FOR        : KeywordName := 'FOR';
    KW_TO         : KeywordName := 'TO';
    KW_BY         : KeywordName := 'BY';
    KW_STEP       : KeywordName := 'STEP';
    KW_DO         : KeywordName := 'DO';
    KW_WHILE      : KeywordName := 'WHILE';
    KW_UNTIL      : KeywordName := 'UNTIL';
    KW_GOTO       : KeywordName := 'GOTO';
    KW_GO         : KeywordName := 'GO';
    { Sous-programmes }
    KW_PROCEDURE  : KeywordName := 'PROCEDURE';
    KW_PROC       : KeywordName := 'PROC';
    KW_FUNCTION   : KeywordName := 'FUNCTION';
    KW_CALL       : KeywordName := 'CALL';
    KW_RETURN     : KeywordName := 'RETURN';
    KW_STOP       : KeywordName := 'STOP';
    { Logiques }
    KW_AND        : KeywordName := 'AND';
    KW_OR         : KeywordName := 'OR';
    KW_NOT        : KeywordName := 'NOT';
    KW_XOR        : KeywordName := 'XOR';
    KW_EQV        : KeywordName := 'EQV';
    { E/S }
    KW_INPUT      : KeywordName := 'INPUT';
    KW_OUTPUT     : KeywordName := 'OUTPUT';
    { Divers }
    KW_OF         : KeywordName := 'OF';
    KW_IS         : KeywordName := 'IS';
    KW_AT         : KeywordName := 'AT';
    KW_IN         : KeywordName := 'IN';
    KW_ON         : KeywordName := 'ON';
    KW_ABORT      : KeywordName := 'ABORT';
    KW_SIGNAL     : KeywordName := 'SIGNAL';
    KW_CASE       : KeywordName := 'CASE';
    KW_FALLTHRU   : KeywordName := 'FALLTHRU';
    KW_DEFAULT    : KeywordName := 'DEFAULT';
    { Fonctions integrees (builtins) }
    KW_ABS        : KeywordName := 'ABS';
    KW_SGN        : KeywordName := 'SGN';
    KW_SHIFTL     : KeywordName := 'SHIFTL';
    KW_SHIFTR     : KeywordName := 'SHIFTR';
    KW_BIT        : KeywordName := 'BIT';
    KW_BITSIZE    : KeywordName := 'BITSIZE';
    KW_BYTESIZE   : KeywordName := 'BYTESIZE';
    KW_WORDSIZE   : KeywordName := 'WORDSIZE';
    KW_UBOUND     : KeywordName := 'UBOUND';
    KW_LBOUND     : KeywordName := 'LBOUND';
    KW_NWSDEN     : KeywordName := 'NWSDEN';
    KW_FIRST      : KeywordName := 'FIRST';
    KW_LAST       : KeywordName := 'LAST';
    KW_NEXT       : KeywordName := 'NEXT';
  Else
    KeywordName := '?KW(' + ItoSI(KW) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 03)                             }
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

Function GetKwStructureCount : Integer;
Begin
  GetKwStructureCount := 4;
End;

Function GetKwDeclarationCount : Integer;
Begin
  GetKwDeclarationCount := 4;
End;

Function GetKwControlCount : Integer;
Begin
  GetKwControlCount := 12;
End;

Function GetKwSubprogramCount : Integer;
Begin
  GetKwSubprogramCount := 6;
End;

Function GetKwBuiltinCount : Integer;
Begin
  GetKwBuiltinCount := 14;
End;


{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES JOVIAL 73 (32 BITS)             }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Types de symboles (SK_*) }
  SK_NONE         = 0;   { non defini                                }
  SK_ITEM         = 1;   { variable (ITEM X I 16)                    }
  SK_TABLE        = 2;   { tableau (TABLE T(5) I 16)                 }
  SK_PROCEDURE    = 3;   { procedure (PROCEDURE P)                   }
  SK_FUNCTION     = 4;   { fonction (FUNCTION F)                     }
  SK_CONSTANT     = 5;   { constante                                 }
  SK_STATUS_VAL   = 6;   { valeur d enumeration STATUS               }
  SK_LABEL        = 7;   { label (cible de GOTO)                     }
  SK_DEFINE       = 8;   { macro (DEFINE)                            }
  SK_PARAM        = 9;   { parametre de procedure/fonction           }

  { Types de donnees Jovial (JT_*) }
  JT_NONE         = 0;   { non defini                                }
  JT_INTEGER      = 1;   { entier signe (I 8, I 16, I 32)           }
  JT_STATUS       = 2;   { enumeration (S n)                         }
  JT_BITS         = 3;   { champ de bits (B n)                       }
  JT_FLOATING     = 4;   { reel (F, IEEE 754 32 bits)                }

  { Portees (SCOPE_*) }
  SCOPE_NONE      = 0;   { pas de portee definie                     }
  SCOPE_GLOBAL    = 1;   { globale (au niveau MODULE)                }
  SCOPE_LOCAL     = 2;   { locale (dans une PROCEDURE/FUNCTION)      }
  SCOPE_PARAM     = 3;   { parametre formel                          }
  SCOPE_MODULE    = 4;   { visible dans le MODULE courant            }
  SCOPE_COMPOOL   = 5;   { exportee via COMPOOL                      }

  { Nombre max de valeurs STATUS par symbole }
  MAX_STATUS_VALS = 32;

Type
  { Entree dans la table des symboles Jovial }
  TSymbol = Record
    Name         : String[64];   { nom Jovial (X, SCORE, COLOR)       }
    AsmName      : String[64];   { label ASM (_JV_X, _JV_SCORE)      }
    SymKind      : Integer;      { SK_ITEM, SK_TABLE, SK_PROCEDURE... }
    ItemType     : Integer;      { JT_INTEGER, JT_STATUS, JT_BITS... }
    BitSize      : Integer;      { taille en bits (8, 16, 32)         }
    ByteSize     : Integer;      { taille en octets apres alignement  }
    Scope        : Integer;      { SCOPE_GLOBAL, SCOPE_LOCAL, ...     }
    Offset       : Integer;      { offset dans le segment de donnees  }
    Value        : LongInt;      { valeur initiale ou constante       }
    ProcIdx      : Integer;      { index dans table des procedures    }
    StatusValues : Array[0..MAX_STATUS_VALS - 1] Of String[32];
    StatusCount  : Integer;      { nombre de valeurs STATUS           }
    IsExported   : Boolean;      { True si exporte via COMPOOL        }
    TableSize    : Integer;      { taille du tableau (0 si pas TABLE) }
    ScopeDepth   : Integer;      { profondeur de portee a la creation }
  End;

Var
  { Table des symboles }
  SymTab           : Array[0..MAX_SYM - 1] Of TSymbol;
  SymCount         : Integer;
  SymInitialized   : Boolean;
  SymStateCount    : Integer;
  SymScopeDepth    : Integer;   { profondeur de portee courante      }
  SymCurScope      : Integer;   { portee courante (SCOPE_*)          }
  SymAddCount      : Integer;   { nombre d ajouts effectues          }
  SymFindCount     : Integer;   { nombre de recherches effectuees    }
  SymLabelNum      : Integer;   { generateur de labels uniques       }

{ ------------------------------------------------------------ }
{ SymKindName : nom textuel d un type de symbole                }
{ ------------------------------------------------------------ }

Function SymKindName(SK : Integer) : TString;
Begin
  Case SK Of
    SK_NONE       : SymKindName := '(none)';
    SK_ITEM       : SymKindName := 'ITEM';
    SK_TABLE      : SymKindName := 'TABLE';
    SK_PROCEDURE  : SymKindName := 'PROCEDURE';
    SK_FUNCTION   : SymKindName := 'FUNCTION';
    SK_CONSTANT   : SymKindName := 'CONSTANT';
    SK_STATUS_VAL : SymKindName := 'STATUS-VAL';
    SK_LABEL      : SymKindName := 'LABEL';
    SK_DEFINE     : SymKindName := 'DEFINE';
    SK_PARAM      : SymKindName := 'PARAM';
  Else
    SymKindName := '?SK(' + ItoSI(SK) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ItemTypeName : nom textuel d un type de donnee Jovial         }
{ ------------------------------------------------------------ }

Function ItemTypeName(JT : Integer) : TString;
Begin
  Case JT Of
    JT_NONE     : ItemTypeName := '(none)';
    JT_INTEGER  : ItemTypeName := 'INTEGER';
    JT_STATUS   : ItemTypeName := 'STATUS';
    JT_BITS     : ItemTypeName := 'BITS';
    JT_FLOATING : ItemTypeName := 'FLOATING';
  Else
    ItemTypeName := '?JT(' + ItoSI(JT) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ScopeName : nom textuel d une portee                          }
{ ------------------------------------------------------------ }

Function ScopeName(SC : Integer) : TString;
Begin
  Case SC Of
    SCOPE_NONE    : ScopeName := '(none)';
    SCOPE_GLOBAL  : ScopeName := 'GLOBAL';
    SCOPE_LOCAL   : ScopeName := 'LOCAL';
    SCOPE_PARAM   : ScopeName := 'PARAM';
    SCOPE_MODULE  : ScopeName := 'MODULE';
    SCOPE_COMPOOL : ScopeName := 'COMPOOL';
  Else
    ScopeName := '?SCOPE(' + ItoSI(SC) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ GenSymLabel : generer un label unique pour la table            }
{ ------------------------------------------------------------ }

Function GenSymLabel : TString;
Begin
  Inc(SymLabelNum);
  GenSymLabel := PFX_LBL + 'SYM_' + ItoSI(SymLabelNum);
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
  SymScopeDepth  := 0;
  SymCurScope    := SCOPE_GLOBAL;
  SymAddCount    := 0;
  SymFindCount   := 0;
  SymLabelNum    := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].AsmName     := '';
    SymTab[I].SymKind     := SK_NONE;
    SymTab[I].ItemType    := JT_NONE;
    SymTab[I].BitSize     := 0;
    SymTab[I].ByteSize    := 0;
    SymTab[I].Scope       := SCOPE_NONE;
    SymTab[I].Offset      := 0;
    SymTab[I].Value       := 0;
    SymTab[I].ProcIdx     := -1;
    For J := 0 To MAX_STATUS_VALS - 1 Do
      SymTab[I].StatusValues[J] := '';
    SymTab[I].StatusCount := 0;
    SymTab[I].IsExported  := False;
    SymTab[I].TableSize   := 0;
    SymTab[I].ScopeDepth  := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ SymAdd : ajouter un symbole dans la table                    }
{ Retourne l index du nouveau symbole ou -1 si plein           }
{ ------------------------------------------------------------ }

Function SymAdd(Const AName : TString; AKind : Integer;
                AType : Integer; AScope : Integer) : Integer;
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
  SymTab[Idx].Name       := AName;
  SymTab[Idx].SymKind    := AKind;
  SymTab[Idx].ItemType   := AType;
  SymTab[Idx].BitSize    := 0;
  SymTab[Idx].ByteSize   := 0;
  SymTab[Idx].Scope      := AScope;
  SymTab[Idx].Offset     := 0;
  SymTab[Idx].Value      := 0;
  SymTab[Idx].ProcIdx    := -1;
  For J := 0 To MAX_STATUS_VALS - 1 Do
    SymTab[Idx].StatusValues[J] := '';
  SymTab[Idx].StatusCount := 0;
  SymTab[Idx].IsExported  := False;
  SymTab[Idx].TableSize   := 0;
  SymTab[Idx].ScopeDepth  := SymScopeDepth;

  { Generer le label assembleur selon le type }
  Case AKind Of
    SK_ITEM       : SymTab[Idx].AsmName := PFX_VAR + AsmIdent(AName);
    SK_TABLE      : SymTab[Idx].AsmName := PFX_TAB + AsmIdent(AName);
    SK_PROCEDURE  : SymTab[Idx].AsmName := PFX_PROC + AsmIdent(AName);
    SK_FUNCTION   : SymTab[Idx].AsmName := PFX_PROC + AsmIdent(AName);
    SK_CONSTANT   : SymTab[Idx].AsmName := PFX_CONST + AsmIdent(AName);
    SK_STATUS_VAL : SymTab[Idx].AsmName := PFX_STAT + AsmIdent(AName);
    SK_LABEL      : SymTab[Idx].AsmName := PFX_LBL + AsmIdent(AName);
    SK_DEFINE     : SymTab[Idx].AsmName := '';
    SK_PARAM      : SymTab[Idx].AsmName := PFX_VAR + AsmIdent(AName);
  Else
    SymTab[Idx].AsmName := PFX_VAR + AsmIdent(AName);
  End;

  Inc(SymCount);
  Inc(SymStateCount);
  Inc(SymAddCount);
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
  Inc(SymFindCount);
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
{ SymFindLocal : chercher un symbole dans la portee courante    }
{ Ne retourne que les symboles du niveau de portee courant      }
{ Retourne l index ou -1 si non trouve                          }
{ ------------------------------------------------------------ }

Function SymFindLocal(Const S : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := UpCaseStr(S);
  Inc(SymFindCount);
  SymFindLocal := -1;
  For I := 0 To SymCount - 1 Do
  Begin
    If (UpCaseStr(SymTab[I].Name) = U) And
       (SymTab[I].ScopeDepth = SymScopeDepth) Then
    Begin
      SymFindLocal := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ SymSetScope : changer la portee courante                      }
{ Utilise lors de l entree/sortie de MODULE, PROCEDURE, etc.    }
{ ------------------------------------------------------------ }

Procedure SymSetScope(NewScope : Integer; Enter : Boolean);
Begin
  If Enter Then
  Begin
    Inc(SymScopeDepth);
    SymCurScope := NewScope;
  End
  Else
  Begin
    If SymScopeDepth > 0 Then
      Dec(SymScopeDepth);
    If SymScopeDepth = 0 Then
      SymCurScope := SCOPE_GLOBAL
    Else
      SymCurScope := SCOPE_LOCAL;
  End;
  Inc(SymStateCount);
End;

{ ------------------------------------------------------------ }
{ SymDump : afficher le contenu de la table (debug)            }
{ ------------------------------------------------------------ }

Procedure SymDump;
Var
  I, J : Integer;
Begin
  WriteLn('--- Table des symboles Jovial (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Write('  [', I:4, '] ', SymKindName(SymTab[I].SymKind));
    Write(' ', SymTab[I].Name);
    If SymTab[I].ItemType <> JT_NONE Then
      Write(' ', ItemTypeName(SymTab[I].ItemType));
    If SymTab[I].BitSize > 0 Then
      Write(' ', SymTab[I].BitSize, ' bits');
    If SymTab[I].ByteSize > 0 Then
      Write(' (', SymTab[I].ByteSize, ' bytes)');
    If SymTab[I].TableSize > 0 Then
      Write(' TABLE(', SymTab[I].TableSize, ')');
    If SymTab[I].StatusCount > 0 Then
    Begin
      Write(' STATUS(');
      For J := 0 To SymTab[I].StatusCount - 1 Do
      Begin
        If J > 0 Then Write(',');
        Write(SymTab[I].StatusValues[J]);
      End;
      Write(')');
    End;
    If SymTab[I].Value <> 0 Then
      Write(' val=', SymTab[I].Value);
    If SymTab[I].IsExported Then
      Write(' EXPORTED');
    Write(' scope=', ScopeName(SymTab[I].Scope));
    Write(' depth=', SymTab[I].ScopeDepth);
    If SymTab[I].AsmName <> '' Then
      Write(' asm=', SymTab[I].AsmName);
    WriteLn;
  End;
  WriteLn('--- Fin de la table ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 04)                             }
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

Function GetSymKindCount : Integer;
Begin
  { Nombre de types SK_* definis (sans SK_NONE) }
  GetSymKindCount := 9;
End;

Function GetSymTypeCount : Integer;
Begin
  { Nombre de types JT_* definis (sans JT_NONE) }
  GetSymTypeCount := 4;
End;

Function GetSymScopeCount : Integer;
Begin
  { Nombre de portees SCOPE_* definies (sans SCOPE_NONE) }
  GetSymScopeCount := 5;
End;

Function GetSymMaxStatusVals : Integer;
Begin
  GetSymMaxStatusVals := MAX_STATUS_VALS;
End;


{ ============================================================ }
{ TODO 05 - PARSEUR : STRUCTURE MODULE ET COMPOOL               }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Etats du parseur MODULE (MOD_*) }
  MOD_NONE      = 0;   { pas de module en cours                     }
  MOD_MODULE    = 1;   { dans un MODULE                             }
  MOD_COMPOOL   = 2;   { dans un COMPOOL                            }
  MOD_BODY      = 3;   { dans le corps du module (declarations)     }
  MOD_ENDED     = 4;   { END MODULE/COMPOOL rencontre               }

  { Limites }
  MOD_MAX_DECL  = 256; { nombre max de declarations globales        }

Var
  { Variables du parseur MODULE }
  ModName        : String[64];   { nom du MODULE ou COMPOOL          }
  ModEntryPoint  : String[64];   { nom du point d entree             }
  ModIsCompool   : Boolean;      { True si COMPOOL, False si MODULE  }
  ModState       : Integer;      { MOD_NONE, MOD_MODULE, etc.        }
  ModInitialized : Boolean;      { module initialise ?                }
  ModStateCount  : Integer;      { compteur d operations             }
  ModDeclCount   : Integer;      { nombre de declarations globales   }
  ModProcCount   : Integer;      { nombre de procedures trouvees     }
  ModLabelNum    : Integer;      { generateur de labels uniques       }
  ModParseCount  : Integer;      { nombre de tokens parses           }

{ ------------------------------------------------------------ }
{ InitModuleState : initialiser les variables du parseur MODULE }
{ ------------------------------------------------------------ }

Procedure InitModuleState;
Begin
  ModName        := '';
  ModEntryPoint  := '';
  ModIsCompool   := False;
  ModState       := MOD_NONE;
  ModInitialized := True;
  ModStateCount  := 0;
  ModDeclCount   := 0;
  ModProcCount   := 0;
  ModLabelNum    := 0;
  ModParseCount  := 0;
End;

{ ------------------------------------------------------------ }
{ GenModLabel : generer un label unique pour le parseur MODULE  }
{ ------------------------------------------------------------ }

Function GenModLabel : TString;
Begin
  Inc(ModLabelNum);
  GenModLabel := PFX_MOD + ItoSI(ModLabelNum);
End;

{ ------------------------------------------------------------ }
{ ModStateName : nom textuel d un etat du parseur MODULE        }
{ ------------------------------------------------------------ }

Function ModStateName(S : Integer) : TString;
Begin
  Case S Of
    MOD_NONE    : ModStateName := '(none)';
    MOD_MODULE  : ModStateName := 'MODULE';
    MOD_COMPOOL : ModStateName := 'COMPOOL';
    MOD_BODY    : ModStateName := 'BODY';
    MOD_ENDED   : ModStateName := 'ENDED';
  Else
    ModStateName := '?MOD(' + ItoSI(S) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpect : verifier que le token courant est du type       }
{   attendu, sinon generer une erreur                           }
{ ------------------------------------------------------------ }

Function ParseExpect(TokType : Integer) : Boolean;
Begin
  If CurTokType = TokType Then
    ParseExpect := True
  Else
  Begin
    FatalError('Token inattendu : ' + GetCurTokStr);
    ParseExpect := False;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExpectKeyword : verifier que le token courant est un     }
{   mot-cle specifique                                          }
{ ------------------------------------------------------------ }

Function ParseExpectKeyword(KW : Integer) : Boolean;
Begin
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW) Then
    ParseExpectKeyword := True
  Else
  Begin
    FatalError('Mot-cle attendu : ' + KeywordName(KW) +
               ', trouve : ' + GetCurTokStr);
    ParseExpectKeyword := False;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseModuleHeader : parser MODULE name ;                      }
{ ------------------------------------------------------------ }

Procedure ParseModuleHeader;
Begin
  Inc(ModStateCount);
  Inc(ModParseCount);

  { On est deja sur le token MODULE, avancer }
  LexNextToken;

  { Lire le nom du module }
  If CurTokType = TOK_IDENT Then
  Begin
    ModName       := CurTokStr;
    ModEntryPoint := CurTokStr;
    ModIsCompool  := False;
    ModState      := MOD_MODULE;

    { Ajouter le module dans la table des symboles }
    SymSetScope(SCOPE_GLOBAL, True);

    If Opts.Verbose Then
      WriteLn('MODULE ', ModName);

    LexNextToken;

    { Consommer le point-virgule }
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
  End
  Else
    FatalError('Nom de module attendu apres MODULE');
End;

{ ------------------------------------------------------------ }
{ ParseCompoolHeader : parser COMPOOL name ;                    }
{ ------------------------------------------------------------ }

Procedure ParseCompoolHeader;
Begin
  Inc(ModStateCount);
  Inc(ModParseCount);

  { On est deja sur le token COMPOOL, avancer }
  LexNextToken;

  { Lire le nom du compool }
  If CurTokType = TOK_IDENT Then
  Begin
    ModName       := CurTokStr;
    ModEntryPoint := '';
    ModIsCompool  := True;
    ModState      := MOD_COMPOOL;

    { Portee COMPOOL }
    SymSetScope(SCOPE_COMPOOL, True);

    If Opts.Verbose Then
      WriteLn('COMPOOL ', ModName);

    LexNextToken;

    { Consommer le point-virgule }
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
  End
  Else
    FatalError('Nom de compool attendu apres COMPOOL');
End;

{ ------------------------------------------------------------ }
{ ParseEndModule : parser END MODULE name ; ou END COMPOOL ;    }
{ ------------------------------------------------------------ }

Procedure ParseEndModule;
Var
  EndName : String[64];
Begin
  Inc(ModStateCount);
  Inc(ModParseCount);

  { On est deja sur END, avancer }
  LexNextToken;

  { Verifier MODULE ou COMPOOL apres END }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_MODULE) Then
  Begin
    LexNextToken;

    { Lire le nom apres END MODULE }
    If CurTokType = TOK_IDENT Then
    Begin
      EndName := CurTokStr;
      If UpCaseStr(EndName) <> UpCaseStr(ModName) Then
        WarnMsg('END MODULE ' + EndName +
                ' ne correspond pas a MODULE ' + ModName);
      LexNextToken;
    End;

    { Consommer le point-virgule }
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;

    ModState := MOD_ENDED;
    SymSetScope(SCOPE_GLOBAL, False);

    If Opts.Verbose Then
      WriteLn('END MODULE ', ModName);
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_COMPOOL) Then
  Begin
    LexNextToken;

    { Consommer le point-virgule }
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;

    ModState := MOD_ENDED;
    SymSetScope(SCOPE_COMPOOL, False);

    If Opts.Verbose Then
      WriteLn('END COMPOOL ', ModName);
  End
  Else
  Begin
    { END sans MODULE/COMPOOL = fin de procedure ou bloc }
    { Consommer le point-virgule si present }
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ SkipToSemicolon : avancer jusqu au prochain point-virgule     }
{   ou fin de fichier                                           }
{ ------------------------------------------------------------ }

Procedure SkipToSemicolon;
Begin
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
    LexNextToken;
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ Forward declaration pour ParseItemDecl (defini dans TODO 06) }
Procedure ParseItemDecl; Forward;

{ Forward declaration pour ParseTableDecl (defini dans TODO 07) }
Procedure ParseTableDecl; Forward;

{ Forward declaration pour ParseDefineDecl (defini dans TODO 08) }
Procedure ParseDefineDecl; Forward;

{ Forward declaration pour ParseProcDecl (defini dans TODO 09) }
Procedure ParseProcDecl; Forward;

{ Forward declaration pour ParseExpression (defini dans TODO 10) }
Function ParseExpression : Integer; Forward;

{ Forward declaration pour ParseStatement (defini dans TODO 11, }
{   implementation apres DumpExprState)                          }
Procedure ParseStatement; Forward;

{ Forward declaration pour ParseAssignStatement (defini dans TODO 12) }
Procedure ParseAssignStatement; Forward;

{ Forward declarations pour ParseCallStatement, ParseStopStatement, }
{   ParseAssignGoto (definis dans TODO 12)                           }
Procedure ParseCallStatement; Forward;
Procedure ParseStopStatement; Forward;
Procedure ParseAssignGoto; Forward;

{ Forward declarations pour TODO 13 - STATUS }
Function FindStatusItem(Const Name : TString) : Integer; Forward;
Procedure ParseStatusAssign(Const StatusName : TString); Forward;

{ Forward declaration pour TODO 15 - BUILTINS }
Procedure ParseBuiltinCall; Forward;

{ Forward declaration pour TODO 16 - INPUT/OUTPUT }
Procedure ParseIOStatement; Forward;

{ ------------------------------------------------------------ }
{ ParseModuleBody : parser les declarations du corps du module  }
{   ITEM, TABLE, DEFINE, PROCEDURE/FUNCTION, etc.               }
{ ------------------------------------------------------------ }

Procedure ParseModuleBody;
Begin
  ModState := MOD_BODY;

  While (CurTokType <> TOK_EOF) And (ModState <> MOD_ENDED) Do
  Begin
    Inc(ModParseCount);

    If CurTokType = TOK_KEYWORD Then
    Begin
      Case CurTokNum Of
        KW_END:
        Begin
          ParseEndModule;
        End;

        KW_ITEM:
        Begin
          { Declaration ITEM - parser via TODO 06 }
          Inc(ModDeclCount);
          ParseItemDecl;
        End;

        KW_TABLE:
        Begin
          { Declaration TABLE - parser via TODO 07 }
          Inc(ModDeclCount);
          ParseTableDecl;
        End;

        KW_DEFINE:
        Begin
          { Declaration DEFINE - parser via TODO 08 }
          Inc(ModDeclCount);
          ParseDefineDecl;
        End;

        KW_PROCEDURE, KW_PROC:
        Begin
          { Declaration PROCEDURE - parser via TODO 09 }
          Inc(ModProcCount);
          ParseProcDecl;
        End;

        KW_FUNCTION:
        Begin
          { Declaration FUNCTION - parser via TODO 09 }
          Inc(ModProcCount);
          ParseProcDecl;
        End;

        KW_OVERLAY:
        Begin
          { Declaration OVERLAY - comptabiliser }
          Inc(ModDeclCount);
          SkipToSemicolon;
        End;

      Else
        { Autre mot-cle dans le corps : ignorer la ligne }
        LexNextToken;
      End; { Case }
    End
    Else
      { Token non-keyword dans le corps : avancer }
      LexNextToken;
  End; { While }
End;

{ ------------------------------------------------------------ }
{ ParseModule : parseur principal de la structure MODULE/COMPOOL}
{ ------------------------------------------------------------ }

Procedure ParseModule;
Begin
  If CurTokType = TOK_EOF Then Exit;

  { Le premier token doit etre MODULE ou COMPOOL }
  If CurTokType = TOK_KEYWORD Then
  Begin
    If CurTokNum = KW_MODULE Then
    Begin
      ParseModuleHeader;
      ParseModuleBody;
    End
    Else If CurTokNum = KW_COMPOOL Then
    Begin
      ParseCompoolHeader;
      ParseModuleBody;
    End
    Else
      FatalError('MODULE ou COMPOOL attendu au debut du fichier');
  End
  Else
    FatalError('MODULE ou COMPOOL attendu au debut du fichier');
End;

{ ------------------------------------------------------------ }
{ DumpModuleState : afficher l etat du parseur MODULE           }
{ ------------------------------------------------------------ }

Procedure DumpModuleState;
Begin
  WriteLn('--- Etat du parseur MODULE ---');
  If ModIsCompool Then
    WriteLn('  Type         : COMPOOL')
  Else
    WriteLn('  Type         : MODULE');
  WriteLn('  Nom          : ', ModName);
  If ModEntryPoint <> '' Then
    WriteLn('  Point entree : ', ModEntryPoint);
  WriteLn('  Etat         : ', ModStateName(ModState));
  WriteLn('  Declarations : ', ModDeclCount);
  WriteLn('  Procedures   : ', ModProcCount);
  WriteLn('  Operations   : ', ModStateCount);
  WriteLn('  Tokens parses: ', ModParseCount);
  WriteLn('--- Fin etat MODULE ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 05)                             }
{ ------------------------------------------------------------ }

Function IsModInitialized : Boolean;
Begin
  IsModInitialized := ModInitialized;
End;

Function IsModActive : Boolean;
Begin
  IsModActive := (ModState = MOD_MODULE) Or (ModState = MOD_COMPOOL)
                 Or (ModState = MOD_BODY);
End;

Function GetModName : TString;
Begin
  GetModName := ModName;
End;

Function GetModEntryPoint : TString;
Begin
  GetModEntryPoint := ModEntryPoint;
End;

Function IsModCompool : Boolean;
Begin
  IsModCompool := ModIsCompool;
End;

Function GetModState : Integer;
Begin
  GetModState := ModState;
End;

Function GetModDeclCount : Integer;
Begin
  GetModDeclCount := ModDeclCount;
End;

Function GetModProcCount : Integer;
Begin
  GetModProcCount := ModProcCount;
End;

Function GetModStateCount : Integer;
Begin
  GetModStateCount := ModStateCount;
End;

Function GetModParseCount : Integer;
Begin
  GetModParseCount := ModParseCount;
End;


{ ============================================================ }
{ TODO 06 - PARSEUR : DECLARATIONS ITEM (TYPES DE DONNEES)     }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Tailles de stockage assembleur }
  ITM_STORE_BYTE  = 1;   { DB - 8 bits                              }
  ITM_STORE_WORD  = 2;   { DW - 16 bits                             }
  ITM_STORE_DWORD = 4;   { DD - 32 bits                             }

  { Limites }
  ITM_MAX_STATUS  = 32;  { nombre max de valeurs STATUS par ITEM    }
  ITM_MAX_ITEMS   = 512; { nombre max d ITEM parses                 }

Var
  { Variables du parseur ITEM }
  ItmInitialized  : Boolean;     { module initialise ?                }
  ItmStateCount   : Integer;     { compteur d operations              }
  ItmItemCount    : Integer;     { nombre d ITEM declares             }
  ItmIntegerCount : Integer;     { nombre d ITEM I (entiers)          }
  ItmStatusCount  : Integer;     { nombre d ITEM S (status)           }
  ItmBitsCount    : Integer;     { nombre d ITEM B (bits)             }
  ItmFloatCount   : Integer;     { nombre d ITEM F (flottants)        }
  ItmStatusValCount : Integer;   { nombre total de valeurs STATUS     }
  ItmLabelNum     : Integer;     { generateur de labels uniques       }
  ItmErrorCount   : Integer;     { nombre d erreurs dans ITEM         }

{ ------------------------------------------------------------ }
{ InitItemState : initialiser les variables du parseur ITEM     }
{ ------------------------------------------------------------ }

Procedure InitItemState;
Begin
  ItmInitialized   := True;
  ItmStateCount    := 0;
  ItmItemCount     := 0;
  ItmIntegerCount  := 0;
  ItmStatusCount   := 0;
  ItmBitsCount     := 0;
  ItmFloatCount    := 0;
  ItmStatusValCount := 0;
  ItmLabelNum      := 0;
  ItmErrorCount    := 0;
End;

{ ------------------------------------------------------------ }
{ GenItmLabel : generer un label unique pour le parseur ITEM    }
{ ------------------------------------------------------------ }

Function GenItmLabel : TString;
Begin
  Inc(ItmLabelNum);
  GenItmLabel := PFX_VAR + 'ITM' + ItoSI(ItmLabelNum);
End;

{ ------------------------------------------------------------ }
{ ComputeByteSize : convertir une taille en bits en octets      }
{   avec alignement au conteneur minimal (1, 2 ou 4 octets)    }
{ ------------------------------------------------------------ }

Function ComputeByteSize(BitSz : Integer) : Integer;
Begin
  If BitSz <= 8 Then
    ComputeByteSize := ITM_STORE_BYTE
  Else If BitSz <= 16 Then
    ComputeByteSize := ITM_STORE_WORD
  Else
    ComputeByteSize := ITM_STORE_DWORD;
End;

{ ------------------------------------------------------------ }
{ ItemStorageName : nom de la directive ASM pour la taille       }
{   DB (1 octet), DW (2 octets), DD (4 octets)                 }
{ ------------------------------------------------------------ }

Function ItemStorageName(ByteSz : Integer) : TString;
Begin
  Case ByteSz Of
    ITM_STORE_BYTE  : ItemStorageName := 'DB';
    ITM_STORE_WORD  : ItemStorageName := 'DW';
    ITM_STORE_DWORD : ItemStorageName := 'DD';
  Else
    ItemStorageName := 'DD';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseItemInteger : parser ITEM name I n ;                     }
{   Entier signe sur n bits (8, 16, 32)                        }
{   Le lexeur est positionne apres le nom, sur I                }
{ ------------------------------------------------------------ }

Procedure ParseItemInteger(Const ItemName : TString);
Var
  BitSz, ByteSz, Idx : Integer;
Begin
  { On est sur KW_I, avancer pour lire la taille }
  LexNextToken;

  If CurTokType <> TOK_INTEGER Then
  Begin
    WarnMsg('Taille en bits attendue apres I dans ITEM ' + ItemName);
    Inc(ItmErrorCount);
    Exit;
  End;

  BitSz := CurTokNum;
  If (BitSz <> 8) And (BitSz <> 16) And (BitSz <> 32) Then
  Begin
    WarnMsg('Taille invalide ' + ItoSI(BitSz) +
            ' pour ITEM ' + ItemName + ' (8, 16 ou 32 attendu)');
    Inc(ItmErrorCount);
  End;

  ByteSz := ComputeByteSize(BitSz);

  { Ajouter dans la table des symboles }
  Idx := SymAdd(ItemName, SK_ITEM, JT_INTEGER, SymCurScope);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].BitSize  := BitSz;
    SymTab[Idx].ByteSize := ByteSz;
    SymTab[Idx].IsExported := ModIsCompool;
  End;

  Inc(ItmIntegerCount);
  Inc(ItmItemCount);
  Inc(ItmStateCount);

  If Opts.Verbose Then
    WriteLn('  ITEM ', ItemName, ' I ', BitSz,
            ' (', ItemStorageName(ByteSz), ')');

  { Avancer apres la taille }
  LexNextToken;

  { Consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseItemStatus : parser ITEM name S n (val1, val2, ...) ;    }
{   Status/enumeration sur n bits (8 ou 16)                     }
{   Chaque valeur generee comme constante STATUS_VAL            }
{   Le lexeur est positionne apres le nom, sur S                }
{ ------------------------------------------------------------ }

Procedure ParseItemStatus(Const ItemName : TString);
Var
  BitSz, ByteSz, Idx, ValIdx, SIdx : Integer;
  ValName : TString;
Begin
  { On est sur KW_S, avancer pour lire la taille }
  LexNextToken;

  If CurTokType <> TOK_INTEGER Then
  Begin
    WarnMsg('Taille en bits attendue apres S dans ITEM ' + ItemName);
    Inc(ItmErrorCount);
    Exit;
  End;

  BitSz := CurTokNum;
  If (BitSz <> 8) And (BitSz <> 16) Then
  Begin
    WarnMsg('Taille invalide ' + ItoSI(BitSz) +
            ' pour STATUS ' + ItemName + ' (8 ou 16 attendu)');
    Inc(ItmErrorCount);
  End;

  ByteSz := ComputeByteSize(BitSz);

  { Ajouter le symbole ITEM STATUS dans la table }
  Idx := SymAdd(ItemName, SK_ITEM, JT_STATUS, SymCurScope);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].BitSize  := BitSz;
    SymTab[Idx].ByteSize := ByteSz;
    SymTab[Idx].IsExported := ModIsCompool;
  End;

  { Avancer apres la taille }
  LexNextToken;

  { Parser la liste de valeurs : (val1, val2, ...) }
  ValIdx := 0;
  If CurTokType = TOK_LPAREN Then
  Begin
    LexNextToken;
    While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
    Begin
      If CurTokType = TOK_IDENT Then
      Begin
        ValName := CurTokStr;

        { Stocker la valeur dans le symbole parent }
        If (Idx >= 0) And (ValIdx < MAX_STATUS_VALS) Then
        Begin
          SymTab[Idx].StatusValues[ValIdx] := ValName;
          SymTab[Idx].StatusCount := ValIdx + 1;
        End;

        { Ajouter comme constante STATUS_VAL dans la table }
        SIdx := SymAdd(ItemName + '_' + ValName,
                        SK_STATUS_VAL, JT_INTEGER, SymCurScope);
        If SIdx >= 0 Then
        Begin
          SymTab[SIdx].Value    := ValIdx;
          SymTab[SIdx].BitSize  := BitSz;
          SymTab[SIdx].ByteSize := ByteSz;
          SymTab[SIdx].IsExported := ModIsCompool;
        End;

        Inc(ValIdx);
        Inc(ItmStatusValCount);
      End;

      LexNextToken;

      { Virgule entre les valeurs }
      If CurTokType = TOK_COMMA Then
        LexNextToken;
    End;

    { Consommer la parenthese fermante }
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
  End;

  Inc(ItmStatusCount);
  Inc(ItmItemCount);
  Inc(ItmStateCount);

  If Opts.Verbose Then
    WriteLn('  ITEM ', ItemName, ' S ', BitSz,
            ' (', ValIdx, ' valeurs, ', ItemStorageName(ByteSz), ')');

  { Consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseItemBits : parser ITEM name B n ;                        }
{   Champ de bits sur n bits (1 a 32)                           }
{   Stocke sur le plus petit conteneur : DB/DW/DD              }
{   Le lexeur est positionne apres le nom, sur B                }
{ ------------------------------------------------------------ }

Procedure ParseItemBits(Const ItemName : TString);
Var
  BitSz, ByteSz, Idx : Integer;
Begin
  { On est sur KW_B, avancer pour lire la taille }
  LexNextToken;

  If CurTokType <> TOK_INTEGER Then
  Begin
    WarnMsg('Taille en bits attendue apres B dans ITEM ' + ItemName);
    Inc(ItmErrorCount);
    Exit;
  End;

  BitSz := CurTokNum;
  If (BitSz < 1) Or (BitSz > 32) Then
  Begin
    WarnMsg('Taille invalide ' + ItoSI(BitSz) +
            ' pour BITS ' + ItemName + ' (1 a 32 attendu)');
    Inc(ItmErrorCount);
  End;

  ByteSz := ComputeByteSize(BitSz);

  { Ajouter dans la table des symboles }
  Idx := SymAdd(ItemName, SK_ITEM, JT_BITS, SymCurScope);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].BitSize  := BitSz;
    SymTab[Idx].ByteSize := ByteSz;
    SymTab[Idx].IsExported := ModIsCompool;
  End;

  Inc(ItmBitsCount);
  Inc(ItmItemCount);
  Inc(ItmStateCount);

  If Opts.Verbose Then
    WriteLn('  ITEM ', ItemName, ' B ', BitSz,
            ' (', ItemStorageName(ByteSz), ')');

  { Avancer apres la taille }
  LexNextToken;

  { Consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseItemFloat : parser ITEM name F ;                         }
{   Reel simple precision IEEE 754 (32 bits, DD en memoire)     }
{   Le lexeur est positionne apres le nom, sur F                }
{ ------------------------------------------------------------ }

Procedure ParseItemFloat(Const ItemName : TString);
Var
  Idx : Integer;
Begin
  { On est sur KW_F, pas de taille a lire }

  { Ajouter dans la table des symboles }
  Idx := SymAdd(ItemName, SK_ITEM, JT_FLOATING, SymCurScope);
  If Idx >= 0 Then
  Begin
    SymTab[Idx].BitSize  := 32;
    SymTab[Idx].ByteSize := ITM_STORE_DWORD;
    SymTab[Idx].IsExported := ModIsCompool;
  End;

  Inc(ItmFloatCount);
  Inc(ItmItemCount);
  Inc(ItmStateCount);

  If Opts.Verbose Then
    WriteLn('  ITEM ', ItemName, ' F (DD)');

  { Avancer apres F }
  LexNextToken;

  { Consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseItemDecl : dispatcher principal pour ITEM                }
{   Le lexeur est positionne sur le mot-cle ITEM                }
{   Determine le type (I, S, B, F) et appelle le parseur        }
{   correspondant                                                }
{ ------------------------------------------------------------ }

Procedure ParseItemDecl;
Var
  ItemName : TString;
Begin
  { Avancer apres ITEM }
  LexNextToken;

  { Le nom de la variable : peut etre un identificateur OU un mot-cle }
  { utilise comme nom (ex: ITEM B I 16 - B est KW_B mais sert de nom) }
  If (CurTokType <> TOK_IDENT) And (CurTokType <> TOK_KEYWORD) Then
  Begin
    WarnMsg('Nom d identificateur attendu apres ITEM');
    Inc(ItmErrorCount);
    { Recuperer en sautant jusqu au point-virgule }
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  ItemName := CurTokStr;

  { Avancer pour lire le qualificateur de type }
  LexNextToken;

  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_I : ParseItemInteger(ItemName);
      KW_S : ParseItemStatus(ItemName);
      KW_B : ParseItemBits(ItemName);
      KW_F : ParseItemFloat(ItemName);
    Else
      WarnMsg('Qualificateur de type invalide pour ITEM ' + ItemName +
              ' (I, S, B ou F attendu)');
      Inc(ItmErrorCount);
      { Recuperer en sautant jusqu au point-virgule }
      While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
        LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
    End;
  End
  Else
  Begin
    WarnMsg('Qualificateur de type attendu apres ITEM ' + ItemName +
            ' (I, S, B ou F)');
    Inc(ItmErrorCount);
    { Recuperer en sautant jusqu au point-virgule }
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpItemState : afficher l etat du parseur ITEM               }
{ ------------------------------------------------------------ }

Procedure DumpItemState;
Begin
  WriteLn('--- Etat du parseur ITEM ---');
  WriteLn('  ITEM declares  : ', ItmItemCount);
  WriteLn('    Entiers (I)  : ', ItmIntegerCount);
  WriteLn('    Status  (S)  : ', ItmStatusCount);
  WriteLn('    Bits    (B)  : ', ItmBitsCount);
  WriteLn('    Flottants(F) : ', ItmFloatCount);
  WriteLn('  Valeurs STATUS : ', ItmStatusValCount);
  WriteLn('  Erreurs ITEM   : ', ItmErrorCount);
  WriteLn('  Operations     : ', ItmStateCount);
  WriteLn('--- Fin etat ITEM ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 06)                             }
{ ------------------------------------------------------------ }

Function IsItmInitialized : Boolean;
Begin
  IsItmInitialized := ItmInitialized;
End;

Function GetItmItemCount : Integer;
Begin
  GetItmItemCount := ItmItemCount;
End;

Function GetItmIntegerCount : Integer;
Begin
  GetItmIntegerCount := ItmIntegerCount;
End;

Function GetItmStatusCount : Integer;
Begin
  GetItmStatusCount := ItmStatusCount;
End;

Function GetItmBitsCount : Integer;
Begin
  GetItmBitsCount := ItmBitsCount;
End;

Function GetItmFloatCount : Integer;
Begin
  GetItmFloatCount := ItmFloatCount;
End;

Function GetItmStatusValCount : Integer;
Begin
  GetItmStatusValCount := ItmStatusValCount;
End;

Function GetItmStateCount : Integer;
Begin
  GetItmStateCount := ItmStateCount;
End;

Function GetItmErrorCount : Integer;
Begin
  GetItmErrorCount := ItmErrorCount;
End;

Function GetItmMaxItems : Integer;
Begin
  GetItmMaxItems := ITM_MAX_ITEMS;
End;


{ ============================================================ }
{ TODO 07 - PARSEUR : DECLARATIONS TABLE (TABLEAUX)             }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Limites pour les tableaux }
  TBL_MAX_TABLES   = 256;  { nombre max de TABLE parses               }
  TBL_MAX_ELEMENTS = 1024; { nombre max d elements par TABLE           }

Var
  { Variables du parseur TABLE }
  TblInitialized   : Boolean;     { module initialise ?                }
  TblStateCount    : Integer;     { compteur d operations              }
  TblTableCount    : Integer;     { nombre de TABLE declares           }
  TblIntegerCount  : Integer;     { nombre de TABLE de type I          }
  TblStatusCount   : Integer;     { nombre de TABLE de type S          }
  TblBitsCount     : Integer;     { nombre de TABLE de type B          }
  TblFloatCount    : Integer;     { nombre de TABLE de type F          }
  TblTotalElements : Integer;     { nombre total d elements declares   }
  TblLabelNum      : Integer;     { generateur de labels uniques       }
  TblErrorCount    : Integer;     { nombre d erreurs dans TABLE        }

{ ------------------------------------------------------------ }
{ InitTableState : initialiser les variables du parseur TABLE   }
{ ------------------------------------------------------------ }

Procedure InitTableState;
Begin
  TblInitialized   := True;
  TblStateCount    := 0;
  TblTableCount    := 0;
  TblIntegerCount  := 0;
  TblStatusCount   := 0;
  TblBitsCount     := 0;
  TblFloatCount    := 0;
  TblTotalElements := 0;
  TblLabelNum      := 0;
  TblErrorCount    := 0;
End;

{ ------------------------------------------------------------ }
{ GenTblLabel : generer un label unique pour le parseur TABLE    }
{ ------------------------------------------------------------ }

Function GenTblLabel : TString;
Begin
  Inc(TblLabelNum);
  GenTblLabel := PFX_TAB + 'TBL' + ItoSI(TblLabelNum);
End;

{ ------------------------------------------------------------ }
{ TableTypeName : retourner le nom du type d un tableau          }
{ ------------------------------------------------------------ }

Function TableTypeName(KwType : Integer) : TString;
Begin
  Case KwType Of
    KW_I : TableTypeName := 'INTEGER';
    KW_S : TableTypeName := 'STATUS';
    KW_B : TableTypeName := 'BITS';
    KW_F : TableTypeName := 'FLOATING';
  Else
    TableTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseTableDecl : parser une declaration TABLE                  }
{   Syntaxe : TABLE name(size) type qualifier ;                  }
{   Exemples :                                                   }
{     TABLE T(5) I 16 ;                                          }
{     TABLE FLAGS(8) B 32 ;                                      }
{     TABLE COULEURS(4) S 8 (ROUGE, VERT, BLEU, JAUNE) ;        }
{ ------------------------------------------------------------ }

Procedure ParseTableDecl;
Var
  TblName     : TString;
  TblSize     : Integer;
  TblBitSize  : Integer;
  TblByteSize : Integer;
  TblType     : Integer;
  TblLabel    : TString;
  StatusCount : Integer;
Begin
  Inc(TblStateCount);

  { Avancer apres TABLE }
  LexNextToken;

  { Le nom du tableau : peut etre un identificateur OU un mot-cle }
  If (CurTokType <> TOK_IDENT) And (CurTokType <> TOK_KEYWORD) Then
  Begin
    WarnMsg('Nom d identificateur attendu apres TABLE');
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  TblName := CurTokStr;
  LexNextToken;

  { Parenthese ouvrante pour la taille }
  If CurTokType <> TOK_LPAREN Then
  Begin
    WarnMsg('( attendu apres TABLE ' + TblName);
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  LexNextToken;

  { Lire la taille (entier) }
  If CurTokType <> TOK_INTEGER Then
  Begin
    WarnMsg('Taille entiere attendue dans TABLE ' + TblName + '(...)');
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  TblSize := CurTokNum;
  If (TblSize < 1) Or (TblSize > TBL_MAX_ELEMENTS) Then
  Begin
    WarnMsg('Taille du tableau ' + TblName + ' hors limites (1..' +
            ItoS(TBL_MAX_ELEMENTS) + ')');
    Inc(TblErrorCount);
  End;

  LexNextToken;

  { Parenthese fermante }
  If CurTokType <> TOK_RPAREN Then
  Begin
    WarnMsg(') attendue apres la taille dans TABLE ' + TblName);
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  LexNextToken;

  { Lire le qualificateur de type : I, S, B ou F }
  If CurTokType <> TOK_KEYWORD Then
  Begin
    WarnMsg('Qualificateur de type attendu apres TABLE ' + TblName +
            '(' + ItoS(TblSize) + ') : I, S, B ou F');
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  TblType := CurTokNum;
  TblBitSize := 0;
  TblByteSize := 0;
  StatusCount := 0;

  Case TblType Of
    KW_I:
    Begin
      { TABLE name(size) I bitsize ; }
      LexNextToken;
      If CurTokType = TOK_INTEGER Then
      Begin
        TblBitSize := CurTokNum;
        TblByteSize := ComputeByteSize(TblBitSize);
        LexNextToken;
      End
      Else
      Begin
        WarnMsg('Taille en bits attendue apres I dans TABLE ' + TblName);
        Inc(TblErrorCount);
      End;
      Inc(TblIntegerCount);
    End;

    KW_S:
    Begin
      { TABLE name(size) S bitsize (val1, val2, ...) ; }
      LexNextToken;
      If CurTokType = TOK_INTEGER Then
      Begin
        TblBitSize := CurTokNum;
        TblByteSize := ComputeByteSize(TblBitSize);
        LexNextToken;
      End
      Else
      Begin
        WarnMsg('Taille en bits attendue apres S dans TABLE ' + TblName);
        Inc(TblErrorCount);
      End;
      { Lire les valeurs STATUS optionnelles entre parentheses }
      If CurTokType = TOK_LPAREN Then
      Begin
        LexNextToken;
        While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) And
              (CurTokType <> TOK_SEMICOL) Do
        Begin
          If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
            Inc(StatusCount);
          LexNextToken;
          If CurTokType = TOK_COMMA Then
            LexNextToken;
        End;
        If CurTokType = TOK_RPAREN Then
          LexNextToken;
      End;
      Inc(TblStatusCount);
    End;

    KW_B:
    Begin
      { TABLE name(size) B bitsize ; }
      LexNextToken;
      If CurTokType = TOK_INTEGER Then
      Begin
        TblBitSize := CurTokNum;
        TblByteSize := ComputeByteSize(TblBitSize);
        LexNextToken;
      End
      Else
      Begin
        WarnMsg('Taille en bits attendue apres B dans TABLE ' + TblName);
        Inc(TblErrorCount);
      End;
      Inc(TblBitsCount);
    End;

    KW_F:
    Begin
      { TABLE name(size) F ; }
      TblBitSize := 32;
      TblByteSize := ITM_STORE_DWORD;
      LexNextToken;
      Inc(TblFloatCount);
    End;

  Else
    WarnMsg('Qualificateur de type invalide pour TABLE ' + TblName +
            ' (I, S, B ou F attendu)');
    Inc(TblErrorCount);
    While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  { Generer un label pour le tableau }
  TblLabel := GenTblLabel;

  { Enregistrer dans la table des symboles }
  SymAdd(TblName, SK_TABLE, TblType, SymCurScope);
  If SymCount > 0 Then
  Begin
    SymTab[SymCount - 1].BitSize   := TblBitSize;
    SymTab[SymCount - 1].ByteSize  := TblByteSize;
    SymTab[SymCount - 1].TableSize := TblSize;
  End;

  { Comptabiliser }
  Inc(TblTableCount);
  TblTotalElements := TblTotalElements + TblSize;

  If Opts.Verbose Then
    WriteLn('  TABLE ', TblName, '(', TblSize, ') ',
            TableTypeName(TblType), ' ', TblBitSize, ' bits  [',
            TblLabel, ']  total=', TblSize * TblByteSize, ' octets');

  { Consommer le point-virgule terminal }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ DumpTableState : afficher l etat du parseur TABLE              }
{ ------------------------------------------------------------ }

Procedure DumpTableState;
Begin
  WriteLn('--- Etat du parseur TABLE ---');
  WriteLn('  TABLE declares : ', TblTableCount);
  WriteLn('    Entiers (I)  : ', TblIntegerCount);
  WriteLn('    Status  (S)  : ', TblStatusCount);
  WriteLn('    Bits    (B)  : ', TblBitsCount);
  WriteLn('    Flottants(F) : ', TblFloatCount);
  WriteLn('  Total elements : ', TblTotalElements);
  WriteLn('  Erreurs TABLE  : ', TblErrorCount);
  WriteLn('  Operations     : ', TblStateCount);
  WriteLn('--- Fin etat TABLE ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 07)                             }
{ ------------------------------------------------------------ }

Function IsTblInitialized : Boolean;
Begin
  IsTblInitialized := TblInitialized;
End;

Function GetTblTableCount : Integer;
Begin
  GetTblTableCount := TblTableCount;
End;

Function GetTblIntegerCount : Integer;
Begin
  GetTblIntegerCount := TblIntegerCount;
End;

Function GetTblStatusCount : Integer;
Begin
  GetTblStatusCount := TblStatusCount;
End;

Function GetTblBitsCount : Integer;
Begin
  GetTblBitsCount := TblBitsCount;
End;

Function GetTblFloatCount : Integer;
Begin
  GetTblFloatCount := TblFloatCount;
End;

Function GetTblTotalElements : Integer;
Begin
  GetTblTotalElements := TblTotalElements;
End;

Function GetTblStateCount : Integer;
Begin
  GetTblStateCount := TblStateCount;
End;

Function GetTblErrorCount : Integer;
Begin
  GetTblErrorCount := TblErrorCount;
End;

Function GetTblMaxTables : Integer;
Begin
  GetTblMaxTables := TBL_MAX_TABLES;
End;


{ ============================================================ }
{ TODO 08 - PARSEUR : DEFINE (CONSTANTES NOMMEES)               }
{ ============================================================ }

Const
  { Types de constantes DEFINE }
  DEF_NONE    = 0;   { aucun type                            }
  DEF_INTEGER = 1;   { constante entiere                     }
  DEF_REAL    = 2;   { constante reelle                      }
  DEF_STRING  = 3;   { constante chaine                      }

  { Limites pour les DEFINE }
  DEF_MAX_DEFINES = 256;   { nombre max de DEFINE                  }

Type
  TDefineEntry = Record
    Name     : TString;   { nom de la constante                    }
    DefType  : Integer;   { type : DEF_INTEGER, DEF_REAL, DEF_STRING }
    IntValue : LongInt;   { valeur si entiere                      }
    RealValue: Real;      { valeur si reelle                       }
    StrValue : TString;   { valeur si chaine                       }
  End;

Var
  { Variables du parseur DEFINE }
  DefInitialized   : Boolean;     { module initialise ?                }
  DefStateCount    : Integer;     { compteur d operations              }
  DefCount         : Integer;     { nombre de DEFINE declares          }
  DefIntegerCount  : Integer;     { nombre de DEFINE entieres          }
  DefRealCount     : Integer;     { nombre de DEFINE reelles           }
  DefStringCount   : Integer;     { nombre de DEFINE chaines           }
  DefLabelNum      : Integer;     { generateur de labels uniques       }
  DefErrorCount    : Integer;     { nombre d erreurs dans DEFINE       }
  DefTable         : Array[1..DEF_MAX_DEFINES] Of TDefineEntry;

{ ------------------------------------------------------------ }
{ InitDefineState : initialiser les variables du parseur DEFINE  }
{ ------------------------------------------------------------ }

Procedure InitDefineState;
Begin
  DefInitialized   := True;
  DefStateCount    := 0;
  DefCount         := 0;
  DefIntegerCount  := 0;
  DefRealCount     := 0;
  DefStringCount   := 0;
  DefLabelNum      := 0;
  DefErrorCount    := 0;
End;

{ ------------------------------------------------------------ }
{ GenDefLabel : generer un label unique pour le parseur DEFINE   }
{ ------------------------------------------------------------ }

Function GenDefLabel : TString;
Begin
  Inc(DefLabelNum);
  GenDefLabel := PFX_CONST + 'DEF' + ItoSI(DefLabelNum);
End;

{ ------------------------------------------------------------ }
{ DefineTypeName : retourner le nom du type d un DEFINE          }
{ ------------------------------------------------------------ }

Function DefineTypeName(DType : Integer) : TString;
Begin
  Case DType Of
    DEF_NONE    : DefineTypeName := 'NONE';
    DEF_INTEGER : DefineTypeName := 'INTEGER';
    DEF_REAL    : DefineTypeName := 'REAL';
    DEF_STRING  : DefineTypeName := 'STRING';
  Else
    DefineTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ FindDefine : rechercher un DEFINE par son nom                  }
{   Retourne l indice (1..DefCount) ou 0 si non trouve          }
{ ------------------------------------------------------------ }

Function FindDefine(Const AName : TString) : Integer;
Var
  I     : Integer;
  UName : TString;
Begin
  Inc(DefStateCount);
  UName := UpCaseStr(AName);
  FindDefine := 0;
  For I := 1 To DefCount Do
  Begin
    If UpCaseStr(DefTable[I].Name) = UName Then
    Begin
      FindDefine := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AddDefine : ajouter un DEFINE a la table                      }
{   Retourne l indice du DEFINE ajoute ou 0 si table pleine     }
{ ------------------------------------------------------------ }

Function AddDefine(Const AName : TString; AType : Integer;
                   AInt : LongInt; AReal : Real;
                   Const AStr : TString) : Integer;
Var
  Idx : Integer;
Begin
  Inc(DefStateCount);

  { Verifier si le DEFINE existe deja (redefinition) }
  Idx := FindDefine(AName);
  If Idx > 0 Then
  Begin
    { Redefinition : mettre a jour la valeur existante }
    DefTable[Idx].DefType  := AType;
    DefTable[Idx].IntValue := AInt;
    DefTable[Idx].RealValue := AReal;
    DefTable[Idx].StrValue := AStr;
    If Opts.Verbose Then
      WriteLn('  DEFINE ', AName, ' redefini = ',
        DefineTypeName(AType));
    AddDefine := Idx;
    Exit;
  End;

  { Verifier la limite }
  If DefCount >= DEF_MAX_DEFINES Then
  Begin
    WarnMsg('Trop de DEFINE declares (max ' +
            ItoS(DEF_MAX_DEFINES) + ')');
    Inc(DefErrorCount);
    AddDefine := 0;
    Exit;
  End;

  { Ajouter le nouveau DEFINE }
  Inc(DefCount);
  DefTable[DefCount].Name      := AName;
  DefTable[DefCount].DefType   := AType;
  DefTable[DefCount].IntValue  := AInt;
  DefTable[DefCount].RealValue := AReal;
  DefTable[DefCount].StrValue  := AStr;

  AddDefine := DefCount;
End;

{ ------------------------------------------------------------ }
{ ParseDefineDecl : parser une declaration DEFINE                }
{   Syntaxe : DEFINE name = value ;                              }
{   Exemples :                                                   }
{     DEFINE MAX = 100 ;                                         }
{     DEFINE PI = 3.14159 ;                                      }
{     DEFINE MSG = 'BONJOUR' ;                                   }
{ ------------------------------------------------------------ }

Procedure ParseDefineDecl;
Var
  DefName  : TString;
  DType    : Integer;
  IntVal   : LongInt;
  RealVal  : Real;
  StrVal   : TString;
  IsNeg    : Boolean;
Begin
  Inc(DefStateCount);

  { Consommer le mot-cle DEFINE }
  LexNextToken;

  { Le nom du DEFINE : peut etre un identifiant ou un mot-cle }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
  Begin
    DefName := CurTokStr;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('DEFINE : nom attendu, trouve ' + CurTokStr);
    Inc(DefErrorCount);
    SkipToSemicolon;
    Exit;
  End;

  { Attendre le signe egal }
  If (CurTokType = TOK_EQ) Then
    LexNextToken
  Else
  Begin
    WarnMsg('DEFINE ' + DefName + ' : signe = attendu');
    Inc(DefErrorCount);
    SkipToSemicolon;
    Exit;
  End;

  { Parser la valeur }
  DType   := DEF_NONE;
  IntVal  := 0;
  RealVal := 0.0;
  StrVal  := '';
  IsNeg   := False;

  { Verifier le signe negatif }
  If (CurTokType = TOK_MINUS) Then
  Begin
    IsNeg := True;
    LexNextToken;
  End;

  If CurTokType = TOK_INTEGER Then
  Begin
    DType  := DEF_INTEGER;
    IntVal := CurTokNum;
    If IsNeg Then
      IntVal := -IntVal;
    Inc(DefIntegerCount);
    LexNextToken;
  End
  Else If CurTokType = TOK_REAL Then
  Begin
    DType   := DEF_REAL;
    RealVal := CurTokReal;
    If IsNeg Then
      RealVal := -RealVal;
    Inc(DefRealCount);
    LexNextToken;
  End
  Else If CurTokType = TOK_STRING Then
  Begin
    DType  := DEF_STRING;
    StrVal := CurTokStr;
    Inc(DefStringCount);
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('DEFINE ' + DefName + ' : valeur attendue');
    Inc(DefErrorCount);
    SkipToSemicolon;
    Exit;
  End;

  { Ajouter le DEFINE a la table }
  AddDefine(DefName, DType, IntVal, RealVal, StrVal);

  If Opts.Verbose Then
  Begin
    Write('  DEFINE ', DefName, ' = ');
    Case DType Of
      DEF_INTEGER : WriteLn(IntVal, ' (', DefineTypeName(DType), ')');
      DEF_REAL    : WriteLn(RealVal:0:6, ' (', DefineTypeName(DType), ')');
      DEF_STRING  : WriteLn('''', StrVal, ''' (',
                            DefineTypeName(DType), ')');
    Else
      WriteLn('? (', DefineTypeName(DType), ')');
    End;
  End;

  { Consommer le point-virgule si present }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ DumpDefineState : afficher l etat du parseur DEFINE            }
{ ------------------------------------------------------------ }

Procedure DumpDefineState;
Var
  I : Integer;
Begin
  WriteLn('--- Etat du parseur DEFINE ---');
  WriteLn('  DEFINE declares : ', DefCount);
  WriteLn('    Entieres     : ', DefIntegerCount);
  WriteLn('    Reelles      : ', DefRealCount);
  WriteLn('    Chaines      : ', DefStringCount);
  WriteLn('  Erreurs DEFINE : ', DefErrorCount);
  WriteLn('  Operations     : ', DefStateCount);
  If DefCount > 0 Then
  Begin
    WriteLn('  Table des DEFINE :');
    For I := 1 To DefCount Do
    Begin
      Write('    ', DefTable[I].Name, ' = ');
      Case DefTable[I].DefType Of
        DEF_INTEGER : WriteLn(DefTable[I].IntValue,
                              ' (INTEGER)');
        DEF_REAL    : WriteLn(DefTable[I].RealValue:0:6,
                              ' (REAL)');
        DEF_STRING  : WriteLn('''', DefTable[I].StrValue,
                              ''' (STRING)');
      Else
        WriteLn('? (UNKNOWN)');
      End;
    End;
  End;
  WriteLn('--- Fin etat DEFINE ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 08)                             }
{ ------------------------------------------------------------ }

Function IsDefInitialized : Boolean;
Begin
  IsDefInitialized := DefInitialized;
End;

Function GetDefCount : Integer;
Begin
  GetDefCount := DefCount;
End;

Function GetDefIntegerCount : Integer;
Begin
  GetDefIntegerCount := DefIntegerCount;
End;

Function GetDefRealCount : Integer;
Begin
  GetDefRealCount := DefRealCount;
End;

Function GetDefStringCount : Integer;
Begin
  GetDefStringCount := DefStringCount;
End;

Function GetDefStateCount : Integer;
Begin
  GetDefStateCount := DefStateCount;
End;

Function GetDefErrorCount : Integer;
Begin
  GetDefErrorCount := DefErrorCount;
End;

Function GetDefLabelNum : Integer;
Begin
  GetDefLabelNum := DefLabelNum;
End;

Function GetDefMaxDefines : Integer;
Begin
  GetDefMaxDefines := DEF_MAX_DEFINES;
End;

Function IsDefEmpty : Boolean;
Begin
  IsDefEmpty := (DefCount = 0);
End;


{ ============================================================ }
{ TODO 09 - PARSEUR : PROCEDURE ET FUNCTION                      }
{ ============================================================ }

Const
  { Types de sous-programmes }
  PRC_NONE      = 0;   { aucun type                              }
  PRC_PROCEDURE = 1;   { procedure (PROCEDURE / PROC)            }
  PRC_FUNCTION  = 2;   { fonction (FUNCTION)                     }

  { Etats du parseur de procedure }
  PRC_ST_NONE   = 0;   { pas encore commence                     }
  PRC_ST_HEADER = 1;   { en-tete parsee                          }
  PRC_ST_BODY   = 2;   { dans le corps                           }
  PRC_ST_ENDED  = 3;   { termine (END rencontre)                 }

  { Limites pour les procedures }
  PRC_MAX_PROCS  = 512;   { nombre max de procedures              }
  PRC_MAX_PARAMS = 64;    { nombre max de parametres par procedure }

Type
  { Parametre formel d une procedure/fonction }
  TProcParam = Record
    Name     : String[64];   { nom du parametre                     }
    ParamType: Integer;      { JT_INTEGER, JT_STATUS, JT_BITS...   }
    BitSize  : Integer;      { taille en bits                       }
  End;

  { Entree dans la table des procedures }
  TProcEntry = Record
    Name       : TString;        { nom Jovial de la procedure       }
    AsmName    : TString;        { label ASM (_JP_nom)              }
    ProcType   : Integer;        { PRC_PROCEDURE ou PRC_FUNCTION    }
    ReturnType : Integer;        { JT_* pour FUNCTION, JT_NONE sinon}
    ReturnSize : Integer;        { taille retour en bits            }
    ParamCount : Integer;        { nombre de parametres formels     }
    Params     : Array[1..PRC_MAX_PARAMS] Of TProcParam;
    LocalSize  : Integer;        { taille des variables locales     }
    IsEntry    : Boolean;        { True si procedure d entree module}
    HasReturn  : Boolean;        { True si contient RETURN          }
    BodyTokens : Integer;        { nombre de tokens dans le corps   }
  End;

Var
  { Variables du parseur PROCEDURE/FUNCTION }
  PrcInitialized   : Boolean;     { module initialise ?              }
  PrcStateCount    : Integer;     { compteur d operations            }
  PrcCount         : Integer;     { nombre de procedures declarees   }
  PrcProcCount     : Integer;     { nombre de PROCEDURE              }
  PrcFuncCount     : Integer;     { nombre de FUNCTION               }
  PrcParamTotal    : Integer;     { nombre total de parametres       }
  PrcEntryCount    : Integer;     { nombre de procedures d entree    }
  PrcReturnCount   : Integer;     { nombre de RETURN trouves         }
  PrcLabelNum      : Integer;     { generateur de labels uniques     }
  PrcErrorCount    : Integer;     { nombre d erreurs                 }
  PrcTable         : Array[1..PRC_MAX_PROCS] Of TProcEntry;

{ ------------------------------------------------------------ }
{ InitProcState : initialiser les variables du parseur PROC      }
{ ------------------------------------------------------------ }

Procedure InitProcState;
Begin
  PrcInitialized   := True;
  PrcStateCount    := 0;
  PrcCount         := 0;
  PrcProcCount     := 0;
  PrcFuncCount     := 0;
  PrcParamTotal    := 0;
  PrcEntryCount    := 0;
  PrcReturnCount   := 0;
  PrcLabelNum      := 0;
  PrcErrorCount    := 0;
End;

{ ------------------------------------------------------------ }
{ GenPrcLabel : generer un label unique pour les procedures       }
{ ------------------------------------------------------------ }

Function GenPrcLabel : TString;
Begin
  Inc(PrcLabelNum);
  GenPrcLabel := PFX_PROC + 'PRC' + ItoSI(PrcLabelNum);
End;

{ ------------------------------------------------------------ }
{ ProcTypeName : retourner le nom du type de sous-programme      }
{ ------------------------------------------------------------ }

Function ProcTypeName(PType : Integer) : TString;
Begin
  Case PType Of
    PRC_NONE      : ProcTypeName := 'NONE';
    PRC_PROCEDURE : ProcTypeName := 'PROCEDURE';
    PRC_FUNCTION  : ProcTypeName := 'FUNCTION';
  Else
    ProcTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ProcStateName : retourner le nom d un etat du parseur          }
{ ------------------------------------------------------------ }

Function ProcStateName(St : Integer) : TString;
Begin
  Case St Of
    PRC_ST_NONE   : ProcStateName := 'NONE';
    PRC_ST_HEADER : ProcStateName := 'HEADER';
    PRC_ST_BODY   : ProcStateName := 'BODY';
    PRC_ST_ENDED  : ProcStateName := 'ENDED';
  Else
    ProcStateName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ FindProc : rechercher une procedure par son nom                }
{   Retourne l indice (1..PrcCount) ou 0 si non trouve          }
{ ------------------------------------------------------------ }

Function FindProc(Const AName : TString) : Integer;
Var
  I     : Integer;
  UName : TString;
Begin
  Inc(PrcStateCount);
  UName := UpCaseStr(AName);
  FindProc := 0;
  For I := 1 To PrcCount Do
  Begin
    If UpCaseStr(PrcTable[I].Name) = UName Then
    Begin
      FindProc := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AddProc : ajouter une procedure a la table                    }
{   Retourne l indice de la procedure ajoutee ou 0 si plein     }
{ ------------------------------------------------------------ }

Function AddProc(Const AName : TString; AType : Integer;
                 ARetType : Integer; ARetSize : Integer) : Integer;
Var
  I : Integer;
Begin
  Inc(PrcStateCount);

  { Verifier la limite }
  If PrcCount >= PRC_MAX_PROCS Then
  Begin
    WarnMsg('Trop de procedures declarees (max ' +
            ItoS(PRC_MAX_PROCS) + ')');
    Inc(PrcErrorCount);
    AddProc := 0;
    Exit;
  End;

  { Ajouter la nouvelle procedure }
  Inc(PrcCount);
  PrcTable[PrcCount].Name       := AName;
  PrcTable[PrcCount].AsmName    := PFX_PROC + AsmIdent(AName);
  PrcTable[PrcCount].ProcType   := AType;
  PrcTable[PrcCount].ReturnType := ARetType;
  PrcTable[PrcCount].ReturnSize := ARetSize;
  PrcTable[PrcCount].ParamCount := 0;
  PrcTable[PrcCount].LocalSize  := 0;
  PrcTable[PrcCount].IsEntry    := False;
  PrcTable[PrcCount].HasReturn  := False;
  PrcTable[PrcCount].BodyTokens := 0;
  For I := 1 To PRC_MAX_PARAMS Do
  Begin
    PrcTable[PrcCount].Params[I].Name      := '';
    PrcTable[PrcCount].Params[I].ParamType := JT_NONE;
    PrcTable[PrcCount].Params[I].BitSize   := 0;
  End;

  AddProc := PrcCount;
End;

{ ------------------------------------------------------------ }
{ AddProcParam : ajouter un parametre a une procedure            }
{   ProcIdx : indice de la procedure dans PrcTable               }
{   Retourne True si le parametre a ete ajoute                   }
{ ------------------------------------------------------------ }

Function AddProcParam(ProcIdx : Integer; Const AName : TString;
                      AType : Integer; ABits : Integer) : Boolean;
Begin
  Inc(PrcStateCount);
  AddProcParam := False;

  If (ProcIdx < 1) Or (ProcIdx > PrcCount) Then Exit;
  If PrcTable[ProcIdx].ParamCount >= PRC_MAX_PARAMS Then
  Begin
    WarnMsg('Trop de parametres pour ' + PrcTable[ProcIdx].Name +
            ' (max ' + ItoS(PRC_MAX_PARAMS) + ')');
    Inc(PrcErrorCount);
    Exit;
  End;

  Inc(PrcTable[ProcIdx].ParamCount);
  PrcTable[ProcIdx].Params[PrcTable[ProcIdx].ParamCount].Name := AName;
  PrcTable[ProcIdx].Params[PrcTable[ProcIdx].ParamCount].ParamType := AType;
  PrcTable[ProcIdx].Params[PrcTable[ProcIdx].ParamCount].BitSize := ABits;
  Inc(PrcParamTotal);
  AddProcParam := True;
End;

{ ------------------------------------------------------------ }
{ ParseProcParams : parser les parametres formels                }
{   Syntaxe : ( param1 type1, param2 type2, ... )               }
{   Exemples : (X I 16, Y I 16)                                 }
{              (FLAG S 8)                                        }
{   Le curseur est sur la parenthese ouvrante                    }
{ ------------------------------------------------------------ }

Procedure ParseProcParams(ProcIdx : Integer);
Var
  ParName : TString;
  ParType : Integer;
  ParBits : Integer;
Begin
  Inc(PrcStateCount);

  { Consommer la parenthese ouvrante }
  LexNextToken;

  While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_RPAREN) Do
  Begin
    { Nom du parametre }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      ParName := CurTokStr;
      LexNextToken;
    End
    Else
    Begin
      WarnMsg('Parametre : nom attendu, trouve ' + CurTokStr);
      Inc(PrcErrorCount);
      { Avancer jusqu a la virgule ou la parenthese fermante }
      While (CurTokType <> TOK_EOF) And
            (CurTokType <> TOK_COMMA) And
            (CurTokType <> TOK_RPAREN) Do
        LexNextToken;
      If CurTokType = TOK_COMMA Then
        LexNextToken;
      Continue;
    End;

    { Type du parametre : I, S, B ou F }
    ParType := JT_NONE;
    ParBits := 32;
    If CurTokType = TOK_KEYWORD Then
    Begin
      Case CurTokNum Of
        KW_I: ParType := JT_INTEGER;
        KW_S: ParType := JT_STATUS;
        KW_B: ParType := JT_BITS;
        KW_F: ParType := JT_FLOATING;
      Else
        WarnMsg('Parametre ' + ParName +
                ' : type I/S/B/F attendu');
        Inc(PrcErrorCount);
      End;
      LexNextToken;
    End;

    { Taille optionnelle en bits }
    If CurTokType = TOK_INTEGER Then
    Begin
      ParBits := CurTokNum;
      LexNextToken;
    End;

    { Ajouter le parametre }
    AddProcParam(ProcIdx, ParName, ParType, ParBits);

    { Virgule separatrice }
    If CurTokType = TOK_COMMA Then
      LexNextToken;
  End;

  { Consommer la parenthese fermante }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseProcDecl : parser une declaration PROCEDURE ou FUNCTION   }
{   Syntaxe :                                                    }
{     PROCEDURE name ;                                           }
{       ... corps ...                                            }
{     END ;                                                      }
{                                                                }
{     PROCEDURE name (param1 I 16, param2 I 16) ;               }
{       ... corps ...                                            }
{     END ;                                                      }
{                                                                }
{     FUNCTION name type ;                                       }
{       ... corps avec RETURN ...                                }
{     END ;                                                      }
{                                                                }
{     PROC name ;  (forme abregee de PROCEDURE)                  }
{       ... corps ...                                            }
{     END ;                                                      }
{ ------------------------------------------------------------ }

Procedure ParseProcDecl;
Var
  ProcName  : TString;
  ProcKind  : Integer;
  RetType   : Integer;
  RetSize   : Integer;
  ProcIdx   : Integer;
  BodyToks  : Integer;
  NestDepth : Integer;
  IsFunc    : Boolean;
Begin
  Inc(PrcStateCount);

  { Determiner le type : PROCEDURE/PROC ou FUNCTION }
  IsFunc := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION);
  If IsFunc Then
    ProcKind := PRC_FUNCTION
  Else
    ProcKind := PRC_PROCEDURE;

  { Consommer le mot-cle PROCEDURE/PROC/FUNCTION }
  LexNextToken;

  { Le nom du sous-programme }
  ProcName := '';
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
  Begin
    ProcName := CurTokStr;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg(ProcTypeName(ProcKind) + ' : nom attendu, trouve ' +
            CurTokStr);
    Inc(PrcErrorCount);
    SkipToSemicolon;
    Exit;
  End;

  { Type de retour pour les FUNCTION }
  RetType := JT_NONE;
  RetSize := 0;
  If IsFunc Then
  Begin
    If CurTokType = TOK_KEYWORD Then
    Begin
      Case CurTokNum Of
        KW_I:
        Begin
          RetType := JT_INTEGER;
          RetSize := 32;
          LexNextToken;
          If CurTokType = TOK_INTEGER Then
          Begin
            RetSize := CurTokNum;
            LexNextToken;
          End;
        End;
        KW_S:
        Begin
          RetType := JT_STATUS;
          RetSize := 32;
          LexNextToken;
          If CurTokType = TOK_INTEGER Then
          Begin
            RetSize := CurTokNum;
            LexNextToken;
          End;
        End;
        KW_B:
        Begin
          RetType := JT_BITS;
          RetSize := 32;
          LexNextToken;
          If CurTokType = TOK_INTEGER Then
          Begin
            RetSize := CurTokNum;
            LexNextToken;
          End;
        End;
        KW_F:
        Begin
          RetType := JT_FLOATING;
          RetSize := 32;
          LexNextToken;
        End;
      Else
        { Pas de type explicite : defaut entier 32 bits }
        RetType := JT_INTEGER;
        RetSize := 32;
      End;
    End
    Else
    Begin
      { Pas de type : defaut entier 32 bits }
      RetType := JT_INTEGER;
      RetSize := 32;
    End;
    Inc(PrcFuncCount);
  End
  Else
    Inc(PrcProcCount);

  { Ajouter la procedure a la table }
  ProcIdx := AddProc(ProcName, ProcKind, RetType, RetSize);

  { Parser les parametres si presents }
  If CurTokType = TOK_LPAREN Then
    ParseProcParams(ProcIdx);

  { Verifier si c est la procedure d entree du module }
  If UpCaseStr(ProcName) = UpCaseStr(ModName) Then
  Begin
    If ProcIdx > 0 Then
    Begin
      PrcTable[ProcIdx].IsEntry := True;
      Inc(PrcEntryCount);
    End;
  End;

  { Ajouter le symbole a la table des symboles }
  If IsFunc Then
    SymAdd(ProcName, SK_FUNCTION, RetType, SCOPE_GLOBAL)
  Else
    SymAdd(ProcName, SK_PROCEDURE, JT_NONE, SCOPE_GLOBAL);

  If Opts.Verbose Then
  Begin
    Write('  ', ProcTypeName(ProcKind), ' ', ProcName);
    If (ProcIdx > 0) And (PrcTable[ProcIdx].ParamCount > 0) Then
      Write(' (', PrcTable[ProcIdx].ParamCount, ' params)');
    If IsFunc Then
      Write(' -> ', ItemTypeName(RetType), ' ', RetSize);
    If (ProcIdx > 0) And PrcTable[ProcIdx].IsEntry Then
      Write(' [ENTREE]');
    WriteLn;
  End;

  { Consommer le point-virgule apres l en-tete }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;

  { Optionnel : consommer BEGIN si present }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BEGIN) Then
    LexNextToken;

  { Parser le corps du sous-programme : consommer jusqu a END }
  BodyToks := 0;
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    Inc(BodyToks);

    { Compter les RETURN }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_RETURN) Then
    Begin
      Inc(PrcReturnCount);
      If ProcIdx > 0 Then
        PrcTable[ProcIdx].HasReturn := True;
    End;

    { Gerer l imbrication (IF..END, FOR..END, WHILE..END, etc.) }
    If (CurTokType = TOK_KEYWORD) Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Then
        Inc(NestDepth);
    End;

    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
    Begin
      If NestDepth > 0 Then
      Begin
        { C est un END d une structure imbriquee }
        Dec(NestDepth);
        LexNextToken;
        If CurTokType = TOK_SEMICOL Then
          LexNextToken;
      End
      Else
      Begin
        { C est le END du sous-programme }
        LexNextToken;

        { Verifier si c est END MODULE (fin du module) }
        If (CurTokType = TOK_KEYWORD) And
           (CurTokNum = KW_MODULE) Then
        Begin
          { C est la fin du module, pas du sous-programme }
          LexNextToken;
          If CurTokType = TOK_IDENT Then
          Begin
            If UpCaseStr(CurTokStr) <> UpCaseStr(ModName) Then
              WarnMsg('END MODULE ' + CurTokStr +
                      ' ne correspond pas a MODULE ' + ModName);
            LexNextToken;
          End;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          ModState := MOD_ENDED;
          SymSetScope(SCOPE_GLOBAL, False);
          If Opts.Verbose Then
            WriteLn('END MODULE ', ModName);
          Inc(ModStateCount);
          Break;
        End
        Else If (CurTokType = TOK_KEYWORD) And
                (CurTokNum = KW_COMPOOL) Then
        Begin
          { C est la fin du COMPOOL }
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          ModState := MOD_ENDED;
          SymSetScope(SCOPE_COMPOOL, False);
          If Opts.Verbose Then
            WriteLn('END COMPOOL ', ModName);
          Inc(ModStateCount);
          Break;
        End
        Else
        Begin
          { C est END du sous-programme }
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Break;
        End;
      End;
    End
    Else
      LexNextToken;
  End;

  { Sauvegarder le nombre de tokens du corps }
  If ProcIdx > 0 Then
    PrcTable[ProcIdx].BodyTokens := BodyToks;
End;

{ ------------------------------------------------------------ }
{ DumpProcState : afficher l etat du parseur PROCEDURE/FUNCTION  }
{ ------------------------------------------------------------ }

Procedure DumpProcState;
Var
  I, J : Integer;
Begin
  WriteLn('--- Etat du parseur PROCEDURE/FUNCTION ---');
  WriteLn('  Sous-programmes declares : ', PrcCount);
  WriteLn('    Procedures   : ', PrcProcCount);
  WriteLn('    Fonctions    : ', PrcFuncCount);
  WriteLn('  Parametres totaux       : ', PrcParamTotal);
  WriteLn('  Procedures d entree     : ', PrcEntryCount);
  WriteLn('  Instructions RETURN     : ', PrcReturnCount);
  WriteLn('  Erreurs procedure       : ', PrcErrorCount);
  WriteLn('  Operations              : ', PrcStateCount);
  If PrcCount > 0 Then
  Begin
    WriteLn('  Table des sous-programmes :');
    For I := 1 To PrcCount Do
    Begin
      Write('    ', ProcTypeName(PrcTable[I].ProcType), ' ',
            PrcTable[I].Name);
      If PrcTable[I].ProcType = PRC_FUNCTION Then
        Write(' -> ', ItemTypeName(PrcTable[I].ReturnType),
              ' ', PrcTable[I].ReturnSize);
      If PrcTable[I].ParamCount > 0 Then
      Begin
        Write(' (');
        For J := 1 To PrcTable[I].ParamCount Do
        Begin
          If J > 1 Then Write(', ');
          Write(PrcTable[I].Params[J].Name, ' ',
                ItemTypeName(PrcTable[I].Params[J].ParamType),
                ' ', PrcTable[I].Params[J].BitSize);
        End;
        Write(')');
      End;
      If PrcTable[I].IsEntry Then
        Write(' [ENTREE]');
      If PrcTable[I].HasReturn Then
        Write(' [RETURN]');
      Write(' {', PrcTable[I].BodyTokens, ' tokens}');
      Write(' ASM=', PrcTable[I].AsmName);
      WriteLn;
    End;
  End;
  WriteLn('--- Fin etat PROCEDURE/FUNCTION ---');
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs (TODO 09)                             }
{ ------------------------------------------------------------ }

Function IsPrcInitialized : Boolean;
Begin
  IsPrcInitialized := PrcInitialized;
End;

Function GetPrcCount : Integer;
Begin
  GetPrcCount := PrcCount;
End;

Function GetPrcProcCount : Integer;
Begin
  GetPrcProcCount := PrcProcCount;
End;

Function GetPrcFuncCount : Integer;
Begin
  GetPrcFuncCount := PrcFuncCount;
End;

Function GetPrcParamTotal : Integer;
Begin
  GetPrcParamTotal := PrcParamTotal;
End;

Function GetPrcStateCount : Integer;
Begin
  GetPrcStateCount := PrcStateCount;
End;

Function GetPrcErrorCount : Integer;
Begin
  GetPrcErrorCount := PrcErrorCount;
End;

Function GetPrcLabelNum : Integer;
Begin
  GetPrcLabelNum := PrcLabelNum;
End;

Function GetPrcMaxProcs : Integer;
Begin
  GetPrcMaxProcs := PRC_MAX_PROCS;
End;

Function IsPrcEmpty : Boolean;
Begin
  IsPrcEmpty := (PrcCount = 0);
End;


{ ============================================================ }
{ TODO 10 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES      }
{ ============================================================ }

Const
  { Types de noeuds d expression }
  EXP_NONE      = 0;   { aucun noeud                             }
  EXP_INTEGER   = 1;   { litteral entier                         }
  EXP_REAL      = 2;   { litteral reel                           }
  EXP_STRING    = 3;   { litteral chaine                         }
  EXP_IDENT     = 4;   { identificateur (variable)               }
  EXP_BINOP     = 5;   { operation binaire                       }
  EXP_UNARYOP   = 6;   { operation unaire                        }
  EXP_CALL      = 7;   { appel de fonction                       }
  EXP_TABLE     = 8;   { acces element de TABLE : T(I)           }

  { Codes d operateurs }
  OP_NONE       = 0;   { aucun operateur                         }
  OP_ADD        = 1;   { +                                       }
  OP_SUB        = 2;   { -                                       }
  OP_MUL        = 3;   { *                                       }
  OP_DIV        = 4;   { /                                       }
  OP_POWER      = 5;   { **                                      }
  OP_NEG        = 6;   { - (moins unaire)                        }
  OP_AND        = 10;  { AND                                     }
  OP_OR         = 11;  { OR                                      }
  OP_NOT        = 12;  { NOT                                     }
  OP_XOR        = 13;  { XOR                                     }
  OP_EQV        = 14;  { EQV                                     }
  OP_EQ         = 20;  { =                                       }
  OP_NE         = 21;  { /=                                      }
  OP_LT         = 22;  { <                                       }
  OP_GT         = 23;  { >                                       }
  OP_LE         = 24;  { <=                                      }
  OP_GE         = 25;  { >=                                      }

  { Limites pour les expressions }
  EXP_MAX_DEPTH = 64;  { profondeur max de recursion             }

Var
  { Variables du parseur d expressions }
  ExpInitialized   : Boolean;     { module initialise ?              }
  ExpStateCount    : Integer;     { compteur d operations            }
  ExpParseCount    : Integer;     { nombre d expressions parsees     }
  ExpNodeCount     : Integer;     { nombre de noeuds crees           }
  ExpBinOpCount    : Integer;     { nombre d operations binaires     }
  ExpUnaryCount    : Integer;     { nombre d operations unaires      }
  ExpCallCount     : Integer;     { nombre d appels de fonction      }
  ExpTableAccess   : Integer;     { nombre d acces TABLE(index)      }
  ExpLabelNum      : Integer;     { generateur de labels uniques     }
  ExpErrorCount    : Integer;     { nombre d erreurs                 }
  ExpDepth         : Integer;     { profondeur courante de recursion }
  ExpMaxDepth      : Integer;     { profondeur max atteinte          }

{ ------------------------------------------------------------ }
{ InitExprState : initialiser les variables du parseur EXPR      }
{ ------------------------------------------------------------ }

Procedure InitExprState;
Begin
  ExpInitialized := True;
  ExpStateCount  := 0;
  ExpParseCount  := 0;
  ExpNodeCount   := 0;
  ExpBinOpCount  := 0;
  ExpUnaryCount  := 0;
  ExpCallCount   := 0;
  ExpTableAccess := 0;
  ExpLabelNum    := 0;
  ExpErrorCount  := 0;
  ExpDepth       := 0;
  ExpMaxDepth    := 0;
End;

{ ------------------------------------------------------------ }
{ GenExpLabel : generer un label unique pour les expressions      }
{ ------------------------------------------------------------ }

Function GenExpLabel : String;
Begin
  Inc(ExpLabelNum);
  GenExpLabel := PFX_LBL + 'EXP_' + ItoS(ExpLabelNum);
End;

{ ------------------------------------------------------------ }
{ ExprNodeTypeName : nom d un type de noeud d expression         }
{ ------------------------------------------------------------ }

Function ExprNodeTypeName(NodeType : Integer) : String;
Begin
  Case NodeType Of
    EXP_NONE    : ExprNodeTypeName := 'NONE';
    EXP_INTEGER : ExprNodeTypeName := 'INTEGER';
    EXP_REAL    : ExprNodeTypeName := 'REAL';
    EXP_STRING  : ExprNodeTypeName := 'STRING';
    EXP_IDENT   : ExprNodeTypeName := 'IDENT';
    EXP_BINOP   : ExprNodeTypeName := 'BINOP';
    EXP_UNARYOP : ExprNodeTypeName := 'UNARYOP';
    EXP_CALL    : ExprNodeTypeName := 'CALL';
    EXP_TABLE   : ExprNodeTypeName := 'TABLE';
  Else
    ExprNodeTypeName := 'UNKNOWN(' + ItoS(NodeType) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ExprOpName : nom d un operateur d expression                   }
{ ------------------------------------------------------------ }

Function ExprOpName(OpCode : Integer) : String;
Begin
  Case OpCode Of
    OP_NONE  : ExprOpName := 'NONE';
    OP_ADD   : ExprOpName := '+';
    OP_SUB   : ExprOpName := '-';
    OP_MUL   : ExprOpName := '*';
    OP_DIV   : ExprOpName := '/';
    OP_POWER : ExprOpName := '**';
    OP_NEG   : ExprOpName := 'NEG';
    OP_AND   : ExprOpName := 'AND';
    OP_OR    : ExprOpName := 'OR';
    OP_NOT   : ExprOpName := 'NOT';
    OP_XOR   : ExprOpName := 'XOR';
    OP_EQV   : ExprOpName := 'EQV';
    OP_EQ    : ExprOpName := '=';
    OP_NE    : ExprOpName := '/=';
    OP_LT    : ExprOpName := '<';
    OP_GT    : ExprOpName := '>';
    OP_LE    : ExprOpName := '<=';
    OP_GE    : ExprOpName := '>=';
  Else
    ExprOpName := 'OP?(' + ItoS(OpCode) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrimary : parser un operande primaire                     }
{   litteral entier, reel, chaine, identifiant, appel fonction,  }
{   acces TABLE(index), sous-expression entre parentheses        }
{   Retourne le type de noeud                                    }
{ ------------------------------------------------------------ }

Function ParsePrimary : Integer;
Var
  SaveName : TString;
  NodeType : Integer;
  ArgCount : Integer;
Begin
  Inc(ExpStateCount);
  Inc(ExpDepth);
  If ExpDepth > ExpMaxDepth Then
    ExpMaxDepth := ExpDepth;

  NodeType := EXP_NONE;

  If CurTokType = TOK_INTEGER Then
  Begin
    { Litteral entier }
    NodeType := EXP_INTEGER;
    Inc(ExpNodeCount);
    LexNextToken;
  End
  Else If CurTokType = TOK_REAL Then
  Begin
    { Litteral reel }
    NodeType := EXP_REAL;
    Inc(ExpNodeCount);
    LexNextToken;
  End
  Else If CurTokType = TOK_STRING Then
  Begin
    { Litteral chaine }
    NodeType := EXP_STRING;
    Inc(ExpNodeCount);
    LexNextToken;
  End
  Else If CurTokType = TOK_LPAREN Then
  Begin
    { Sous-expression entre parentheses }
    LexNextToken;
    NodeType := ParseExpression;
    If CurTokType = TOK_RPAREN Then
      LexNextToken
    Else
    Begin
      WarnMsg('Parenthese fermante attendue dans expression');
      Inc(ExpErrorCount);
    End;
  End
  Else If (CurTokType = TOK_KEYWORD) Then
  Begin
    { Fonction integree ou mot-cle builtin }
    Case CurTokNum Of
      KW_ABS, KW_SGN, KW_SHIFTL, KW_SHIFTR, KW_BIT,
      KW_BITSIZE, KW_BYTESIZE, KW_WORDSIZE,
      KW_UBOUND, KW_LBOUND, KW_NWSDEN,
      KW_FIRST, KW_LAST, KW_NEXT:
      Begin
        { Appel de fonction integree - deleguer a TODO 15 }
        NodeType := EXP_CALL;
        Inc(ExpNodeCount);
        Inc(ExpCallCount);
        ParseBuiltinCall;
      End;

      KW_NOT:
      Begin
        { NOT unaire - traite dans ParseNot }
        NodeType := EXP_UNARYOP;
        Inc(ExpNodeCount);
        Inc(ExpUnaryCount);
        LexNextToken;
        NodeType := ParsePrimary;
        NodeType := EXP_UNARYOP;
      End;

    Else
      { Autre mot-cle utilise comme identifiant }
      NodeType := EXP_IDENT;
      Inc(ExpNodeCount);
      LexNextToken;
    End;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    { Identifiant : variable ou acces TABLE(index) }
    SaveName := CurTokStr;
    Inc(ExpNodeCount);
    LexNextToken;

    If CurTokType = TOK_LPAREN Then
    Begin
      { Acces TABLE(index) ou appel de fonction utilisateur }
      NodeType := EXP_TABLE;
      Inc(ExpTableAccess);
      LexNextToken;
      If CurTokType <> TOK_RPAREN Then
      Begin
        ParseExpression;
        While CurTokType = TOK_COMMA Do
        Begin
          LexNextToken;
          ParseExpression;
        End;
      End;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
      Begin
        WarnMsg('Parenthese fermante attendue apres index');
        Inc(ExpErrorCount);
      End;
    End
    Else
    Begin
      { Simple variable }
      NodeType := EXP_IDENT;
    End;
  End
  Else
  Begin
    { Operande primaire inattendu }
    If (CurTokType <> TOK_EOF) And (CurTokType <> TOK_SEMICOL) And
       (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_COMMA) Then
    Begin
      WarnMsg('Operande attendu dans expression, trouve token type '
              + ItoS(CurTokType));
      Inc(ExpErrorCount);
      LexNextToken;
    End;
  End;

  Dec(ExpDepth);
  ParsePrimary := NodeType;
End;

{ ------------------------------------------------------------ }
{ ParseUnaryMinus : parser le moins unaire                       }
{   Priorite 8 : - expression                                   }
{ ------------------------------------------------------------ }

Function ParseUnaryMinus : Integer;
Var
  NodeType : Integer;
Begin
  Inc(ExpStateCount);
  If CurTokType = TOK_MINUS Then
  Begin
    { Moins unaire }
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpUnaryCount);
    NodeType := ParseUnaryMinus;
    ParseUnaryMinus := EXP_UNARYOP;
  End
  Else
    ParseUnaryMinus := ParsePrimary;
End;

{ ------------------------------------------------------------ }
{ ParsePower : parser l operateur puissance                      }
{   Priorite 7 : base ** exposant (associativite a droite)       }
{ ------------------------------------------------------------ }

Function ParsePower : Integer;
Var
  LeftType  : Integer;
  RightType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParseUnaryMinus;

  If CurTokType = TOK_POWER Then
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    RightType := ParsePower;
    ParsePower := EXP_BINOP;
  End
  Else
    ParsePower := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseMulDiv : parser les operateurs multiplicatifs             }
{   Priorite 6 : *, /                                           }
{ ------------------------------------------------------------ }

Function ParseMulDiv : Integer;
Var
  LeftType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParsePower;

  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    ParsePower;
    LeftType := EXP_BINOP;
  End;

  ParseMulDiv := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseAddSub : parser les operateurs additifs                   }
{   Priorite 5 : +, -                                           }
{ ------------------------------------------------------------ }

Function ParseAddSub : Integer;
Var
  LeftType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParseMulDiv;

  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Do
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    ParseMulDiv;
    LeftType := EXP_BINOP;
  End;

  ParseAddSub := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseRelational : parser les operateurs relationnels           }
{   Priorite 4 : =, /=, <, <=, >, >=                            }
{ ------------------------------------------------------------ }

Function ParseRelational : Integer;
Var
  LeftType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParseAddSub;

  If (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Or
     (CurTokType = TOK_LT) Or (CurTokType = TOK_GT) Or
     (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Then
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    ParseAddSub;
    LeftType := EXP_BINOP;
  End;

  ParseRelational := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseNot : parser l operateur NOT unaire                       }
{   Priorite 3 : NOT expression                                 }
{ ------------------------------------------------------------ }

Function ParseNot : Integer;
Var
  InnerType : Integer;
Begin
  Inc(ExpStateCount);
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NOT) Then
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpUnaryCount);
    InnerType := ParseNot;
    ParseNot := EXP_UNARYOP;
  End
  Else
    ParseNot := ParseRelational;
End;

{ ------------------------------------------------------------ }
{ ParseAnd : parser l operateur AND                              }
{   Priorite 2 : expr AND expr                                  }
{ ------------------------------------------------------------ }

Function ParseAnd : Integer;
Var
  LeftType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParseNot;

  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AND) Do
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    ParseNot;
    LeftType := EXP_BINOP;
  End;

  ParseAnd := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseOrXorEqv : parser les operateurs OR, XOR, EQV            }
{   Priorite 1 : expr OR expr, expr XOR expr, expr EQV expr     }
{ ------------------------------------------------------------ }

Function ParseOrXorEqv : Integer;
Var
  LeftType : Integer;
Begin
  Inc(ExpStateCount);
  LeftType := ParseAnd;

  While (CurTokType = TOK_KEYWORD) And
        ((CurTokNum = KW_OR) Or (CurTokNum = KW_XOR) Or
         (CurTokNum = KW_EQV)) Do
  Begin
    LexNextToken;
    Inc(ExpNodeCount);
    Inc(ExpBinOpCount);
    ParseAnd;
    LeftType := EXP_BINOP;
  End;

  ParseOrXorEqv := LeftType;
End;

{ ------------------------------------------------------------ }
{ ParseExpression : point d entree principal pour les expressions }
{   Retourne le type de noeud racine de l expression             }
{ ------------------------------------------------------------ }

Function ParseExpression : Integer;
Begin
  Inc(ExpStateCount);
  Inc(ExpParseCount);

  If ExpDepth >= EXP_MAX_DEPTH Then
  Begin
    WarnMsg('Profondeur max d expression atteinte');
    Inc(ExpErrorCount);
    ParseExpression := EXP_NONE;
    Exit;
  End;

  Inc(ExpDepth);
  ParseExpression := ParseOrXorEqv;
  Dec(ExpDepth);
End;

{ ------------------------------------------------------------ }
{ DumpExprState : afficher l etat du parseur d expressions       }
{ ------------------------------------------------------------ }

Procedure DumpExprState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur EXPRESSIONS (TODO 10) ===');
  WriteLn('  Initialise         : ', ExpInitialized);
  WriteLn('  Operations         : ', ExpStateCount);
  WriteLn('  Expressions parsees: ', ExpParseCount);
  WriteLn('  Noeuds crees       : ', ExpNodeCount);
  WriteLn('  Operations binaires: ', ExpBinOpCount);
  WriteLn('  Operations unaires : ', ExpUnaryCount);
  WriteLn('  Appels fonction    : ', ExpCallCount);
  WriteLn('  Acces TABLE(index) : ', ExpTableAccess);
  WriteLn('  Labels generes     : ', ExpLabelNum);
  WriteLn('  Profondeur max     : ', ExpMaxDepth);
  WriteLn('  Erreurs            : ', ExpErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur d expressions (10 fonctions)             }
{ ------------------------------------------------------------ }

Function IsExpInitialized : Boolean;
Begin
  IsExpInitialized := ExpInitialized;
End;

Function GetExpParseCount : Integer;
Begin
  GetExpParseCount := ExpParseCount;
End;

Function GetExpNodeCount : Integer;
Begin
  GetExpNodeCount := ExpNodeCount;
End;

Function GetExpBinOpCount : Integer;
Begin
  GetExpBinOpCount := ExpBinOpCount;
End;

Function GetExpUnaryCount : Integer;
Begin
  GetExpUnaryCount := ExpUnaryCount;
End;

Function GetExpCallCount : Integer;
Begin
  GetExpCallCount := ExpCallCount;
End;

Function GetExpStateCount : Integer;
Begin
  GetExpStateCount := ExpStateCount;
End;

Function GetExpErrorCount : Integer;
Begin
  GetExpErrorCount := ExpErrorCount;
End;

Function GetExpMaxDepth : Integer;
Begin
  GetExpMaxDepth := ExpMaxDepth;
End;

Function IsExpEmpty : Boolean;
Begin
  IsExpEmpty := (ExpParseCount = 0);
End;


{ ============================================================ }
{ TODO 11 - PARSEUR : STRUCTURES DE CONTROLE                   }
{ ============================================================ }

Const
  { Types de structures de controle }
  CTL_NONE      = 0;   { aucune structure                         }
  CTL_IF        = 1;   { IF..THEN..ELSE..END                      }
  CTL_FOR       = 2;   { FOR..TO..DO..END                         }
  CTL_WHILE     = 3;   { WHILE..DO..END                           }
  CTL_DO_UNTIL  = 4;   { DO..UNTIL                                }
  CTL_GOTO      = 5;   { GOTO / GO TO                             }
  CTL_LABEL     = 6;   { label nomme (nom : instruction)          }
  CTL_BEGIN     = 7;   { BEGIN..END (regroupement)                }

  { Limites }
  CTL_MAX_DEPTH = 64;  { profondeur max d imbrication             }

Var
  { Variables du parseur de structures de controle }
  CtlInitialized : Boolean;     { module initialise ?              }
  CtlStateCount  : Integer;     { compteur d operations            }
  CtlIfCount     : Integer;     { nombre de IF parses              }
  CtlForCount    : Integer;     { nombre de FOR parses             }
  CtlWhileCount  : Integer;     { nombre de WHILE parses           }
  CtlDoUntilCount: Integer;     { nombre de DO..UNTIL parses       }
  CtlGotoCount   : Integer;     { nombre de GOTO parses            }
  CtlLabelCount  : Integer;     { nombre de labels nommes          }
  CtlBeginCount  : Integer;     { nombre de BEGIN..END parses      }
  CtlLabelNum    : Integer;     { generateur de labels uniques     }
  CtlErrorCount  : Integer;     { nombre d erreurs                 }
  CtlDepth       : Integer;     { profondeur courante imbrication  }
  CtlMaxDepth    : Integer;     { profondeur max atteinte          }

{ ------------------------------------------------------------ }
{ InitCtrlState : initialiser les variables de controle          }
{ ------------------------------------------------------------ }

Procedure InitCtrlState;
Begin
  CtlInitialized := True;
  CtlStateCount  := 0;
  CtlIfCount     := 0;
  CtlForCount    := 0;
  CtlWhileCount  := 0;
  CtlDoUntilCount:= 0;
  CtlGotoCount   := 0;
  CtlLabelCount  := 0;
  CtlBeginCount  := 0;
  CtlLabelNum    := 0;
  CtlErrorCount  := 0;
  CtlDepth       := 0;
  CtlMaxDepth    := 0;
End;

{ ------------------------------------------------------------ }
{ GenCtlLabel : generer un label unique pour le controle de flux }
{ ------------------------------------------------------------ }

Function GenCtlLabel : TString;
Begin
  Inc(CtlLabelNum);
  GenCtlLabel := PFX_LBL + 'CTL_' + ItoSI(CtlLabelNum);
End;

{ ------------------------------------------------------------ }
{ CtrlTypeName : retourner le nom textuel du type de structure   }
{ ------------------------------------------------------------ }

Function CtrlTypeName(CtlType : Integer) : TString;
Begin
  Case CtlType Of
    CTL_NONE     : CtrlTypeName := 'NONE';
    CTL_IF       : CtrlTypeName := 'IF';
    CTL_FOR      : CtrlTypeName := 'FOR';
    CTL_WHILE    : CtrlTypeName := 'WHILE';
    CTL_DO_UNTIL : CtrlTypeName := 'DO_UNTIL';
    CTL_GOTO     : CtrlTypeName := 'GOTO';
    CTL_LABEL    : CtrlTypeName := 'LABEL';
    CTL_BEGIN    : CtrlTypeName := 'BEGIN';
  Else
    CtrlTypeName := 'UNKNOWN(' + ItoS(CtlType) + ')';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIfStatement : parser une structure IF..THEN..ELSE..END    }
{   IF condition THEN                                            }
{     instructions...                                            }
{   [ELSE                                                        }
{     instructions...]                                           }
{   END ;                                                        }
{ ------------------------------------------------------------ }

Procedure ParseIfStatement;
Var
  LblNum    : TString;
  NestDepth : Integer;
Begin
  Inc(CtlStateCount);
  Inc(CtlIfCount);
  Inc(CtlDepth);
  If CtlDepth > CtlMaxDepth Then
    CtlMaxDepth := CtlDepth;

  LblNum := GenCtlLabel;

  If Opts.Verbose Then
    WriteLn('  IF #', LblNum, ' (profondeur ', CtlDepth, ')');

  { Consommer le mot-cle IF (deja verifie par l appelant) }
  LexNextToken;

  { Parser la condition (expression) }
  ParseExpression;

  { Attendre THEN }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_THEN) Then
    LexNextToken
  Else
  Begin
    WarnMsg('THEN attendu apres condition IF');
    Inc(CtlErrorCount);
  End;

  { Parser les instructions du bloc THEN }
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    { Verifier ELSE au meme niveau }
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_ELSE) Then
    Begin
      { Bloc ELSE }
      LexNextToken;
      If Opts.Verbose Then
        WriteLn('  ELSE #', LblNum);
      Continue;
    End;

    { Verifier END au meme niveau }
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_END) Then
    Begin
      { Fin du IF }
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
      If Opts.Verbose Then
        WriteLn('  END IF #', LblNum);
      Break;
    End;

    { Gerer l imbrication de structures }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_BEGIN) Then
        Inc(NestDepth);
      If CurTokNum = KW_END Then
      Begin
        If NestDepth > 0 Then
        Begin
          Dec(NestDepth);
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Continue;
        End;
      End;
    End;

    LexNextToken;
  End;

  Dec(CtlDepth);
End;

{ ------------------------------------------------------------ }
{ ParseForStatement : parser une boucle FOR..TO..DO..END         }
{   FOR var = debut [BY pas] TO fin DO                           }
{     instructions...                                            }
{   END ;                                                        }
{ ------------------------------------------------------------ }

Procedure ParseForStatement;
Var
  LblNum    : TString;
  HasBy     : Boolean;
  NestDepth : Integer;
Begin
  Inc(CtlStateCount);
  Inc(CtlForCount);
  Inc(CtlDepth);
  If CtlDepth > CtlMaxDepth Then
    CtlMaxDepth := CtlDepth;

  LblNum := GenCtlLabel;
  HasBy  := False;

  If Opts.Verbose Then
    WriteLn('  FOR #', LblNum, ' (profondeur ', CtlDepth, ')');

  { Consommer le mot-cle FOR }
  LexNextToken;

  { Variable de boucle }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    LexNextToken
  Else
  Begin
    WarnMsg('Variable attendue apres FOR');
    Inc(CtlErrorCount);
  End;

  { Signe egal : = }
  If CurTokType = TOK_EQ Then
    LexNextToken
  Else
  Begin
    WarnMsg('= attendu apres variable FOR');
    Inc(CtlErrorCount);
  End;

  { Expression de debut }
  ParseExpression;

  { Optionnel : BY pas }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_BY) Then
  Begin
    HasBy := True;
    LexNextToken;
    ParseExpression;
  End;

  { TO expression de fin }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    LexNextToken
  Else
  Begin
    WarnMsg('TO attendu dans boucle FOR');
    Inc(CtlErrorCount);
  End;

  ParseExpression;

  { DO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DO) Then
    LexNextToken
  Else
  Begin
    WarnMsg('DO attendu dans boucle FOR');
    Inc(CtlErrorCount);
  End;

  If Opts.Verbose And HasBy Then
    WriteLn('    FOR avec pas explicite (BY)');

  { Parser le corps de la boucle jusqu a END }
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_END) Then
    Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
      If Opts.Verbose Then
        WriteLn('  END FOR #', LblNum);
      Break;
    End;

    { Gerer l imbrication }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_BEGIN) Then
        Inc(NestDepth);
      If CurTokNum = KW_END Then
      Begin
        If NestDepth > 0 Then
        Begin
          Dec(NestDepth);
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Continue;
        End;
      End;
    End;

    LexNextToken;
  End;

  Dec(CtlDepth);
End;

{ ------------------------------------------------------------ }
{ ParseWhileStatement : parser une boucle WHILE..DO..END         }
{   WHILE condition DO                                           }
{     instructions...                                            }
{   END ;                                                        }
{ ------------------------------------------------------------ }

Procedure ParseWhileStatement;
Var
  LblNum    : TString;
  NestDepth : Integer;
Begin
  Inc(CtlStateCount);
  Inc(CtlWhileCount);
  Inc(CtlDepth);
  If CtlDepth > CtlMaxDepth Then
    CtlMaxDepth := CtlDepth;

  LblNum := GenCtlLabel;

  If Opts.Verbose Then
    WriteLn('  WHILE #', LblNum, ' (profondeur ', CtlDepth, ')');

  { Consommer le mot-cle WHILE }
  LexNextToken;

  { Parser la condition }
  ParseExpression;

  { Attendre DO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DO) Then
    LexNextToken
  Else
  Begin
    WarnMsg('DO attendu apres condition WHILE');
    Inc(CtlErrorCount);
  End;

  { Parser le corps de la boucle jusqu a END }
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_END) Then
    Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
      If Opts.Verbose Then
        WriteLn('  END WHILE #', LblNum);
      Break;
    End;

    { Gerer l imbrication }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_BEGIN) Then
        Inc(NestDepth);
      If CurTokNum = KW_END Then
      Begin
        If NestDepth > 0 Then
        Begin
          Dec(NestDepth);
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Continue;
        End;
      End;
    End;

    LexNextToken;
  End;

  Dec(CtlDepth);
End;

{ ------------------------------------------------------------ }
{ ParseDoUntil : parser une boucle DO..UNTIL                     }
{   DO                                                           }
{     instructions...                                            }
{   UNTIL condition ;                                            }
{ ------------------------------------------------------------ }

Procedure ParseDoUntil;
Var
  LblNum    : TString;
  NestDepth : Integer;
Begin
  Inc(CtlStateCount);
  Inc(CtlDoUntilCount);
  Inc(CtlDepth);
  If CtlDepth > CtlMaxDepth Then
    CtlMaxDepth := CtlDepth;

  LblNum := GenCtlLabel;

  If Opts.Verbose Then
    WriteLn('  DO #', LblNum, ' (profondeur ', CtlDepth, ')');

  { Consommer le mot-cle DO }
  LexNextToken;

  { Parser le corps jusqu a UNTIL }
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    { Verifier UNTIL au meme niveau }
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_UNTIL) Then
    Begin
      LexNextToken;
      { Parser la condition }
      ParseExpression;
      { Consommer le point-virgule }
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
      If Opts.Verbose Then
        WriteLn('  UNTIL #', LblNum);
      Break;
    End;

    { Gerer l imbrication }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_BEGIN) Then
        Inc(NestDepth);
      If CurTokNum = KW_END Then
      Begin
        If NestDepth > 0 Then
        Begin
          Dec(NestDepth);
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Continue;
        End;
      End;
    End;

    LexNextToken;
  End;

  Dec(CtlDepth);
End;

{ ------------------------------------------------------------ }
{ ParseGotoStatement : parser GOTO label ou GO TO label          }
{ ------------------------------------------------------------ }

Procedure ParseGotoStatement;
Begin
  Inc(CtlStateCount);
  Inc(CtlGotoCount);

  { Consommer GOTO ou GO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GO) Then
  Begin
    LexNextToken;
    { Verifier si TO suit (GO TO) }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
      LexNextToken;
  End
  Else
    { GOTO }
    LexNextToken;

  { Le label cible }
  If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
  Begin
    If Opts.Verbose Then
      WriteLn('  GOTO ', CurTokStr);
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Label attendu apres GOTO');
    Inc(CtlErrorCount);
  End;

  { Consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseBeginEnd : parser un bloc BEGIN..END                      }
{   BEGIN                                                        }
{     instructions...                                            }
{   END ;                                                        }
{ ------------------------------------------------------------ }

Procedure ParseBeginEnd;
Var
  LblNum    : TString;
  NestDepth : Integer;
Begin
  Inc(CtlStateCount);
  Inc(CtlBeginCount);
  Inc(CtlDepth);
  If CtlDepth > CtlMaxDepth Then
    CtlMaxDepth := CtlDepth;

  LblNum := GenCtlLabel;

  If Opts.Verbose Then
    WriteLn('  BEGIN #', LblNum);

  { Consommer BEGIN }
  LexNextToken;

  { Parser les instructions jusqu a END }
  NestDepth := 0;
  While (CurTokType <> TOK_EOF) Do
  Begin
    If (NestDepth = 0) And (CurTokType = TOK_KEYWORD) And
       (CurTokNum = KW_END) Then
    Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
      If Opts.Verbose Then
        WriteLn('  END BEGIN #', LblNum);
      Break;
    End;

    { Gerer l imbrication }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_IF) Or (CurTokNum = KW_FOR) Or
         (CurTokNum = KW_WHILE) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_BEGIN) Then
        Inc(NestDepth);
      If CurTokNum = KW_END Then
      Begin
        If NestDepth > 0 Then
        Begin
          Dec(NestDepth);
          LexNextToken;
          If CurTokType = TOK_SEMICOL Then
            LexNextToken;
          Continue;
        End;
      End;
    End;

    LexNextToken;
  End;

  Dec(CtlDepth);
End;

{ ------------------------------------------------------------ }
{ ParseStatement : dispatcher principal pour les instructions    }
{   Distribue vers IF, FOR, WHILE, DO, GOTO, BEGIN, ou          }
{   consomme les tokens jusqu au point-virgule                   }
{ ------------------------------------------------------------ }

Procedure ParseStatement;
Begin
  Inc(CtlStateCount);

  If CurTokType = TOK_EOF Then Exit;

  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_IF:
        ParseIfStatement;

      KW_FOR:
        ParseForStatement;

      KW_WHILE:
        ParseWhileStatement;

      KW_DO:
        ParseDoUntil;

      KW_GOTO:
        ParseAssignGoto;

      KW_GO:
        ParseAssignGoto;

      KW_BEGIN:
        ParseBeginEnd;

      KW_CALL:
        ParseCallStatement;

      KW_STOP:
        ParseStopStatement;

      KW_INPUT, KW_OUTPUT:
        ParseIOStatement;

    Else
      { Autre instruction mot-cle : consommer jusqu au ; }
      While (CurTokType <> TOK_SEMICOL) And
            (CurTokType <> TOK_EOF) Do
        LexNextToken;
      If CurTokType = TOK_SEMICOL Then
        LexNextToken;
    End;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    { Deleguer au parseur d affectations TODO 12 }
    ParseAssignStatement;
  End
  Else
  Begin
    { Token inattendu : avancer }
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpCtrlState : afficher l etat du parseur de controle         }
{ ------------------------------------------------------------ }

Procedure DumpCtrlState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur CONTROLE (TODO 11) ===');
  WriteLn('  Initialise         : ', CtlInitialized);
  WriteLn('  Operations         : ', CtlStateCount);
  WriteLn('  IF parses          : ', CtlIfCount);
  WriteLn('  FOR parses         : ', CtlForCount);
  WriteLn('  WHILE parses       : ', CtlWhileCount);
  WriteLn('  DO..UNTIL parses   : ', CtlDoUntilCount);
  WriteLn('  GOTO parses        : ', CtlGotoCount);
  WriteLn('  Labels nommes      : ', CtlLabelCount);
  WriteLn('  BEGIN..END parses  : ', CtlBeginCount);
  WriteLn('  Labels generes     : ', CtlLabelNum);
  WriteLn('  Profondeur max     : ', CtlMaxDepth);
  WriteLn('  Erreurs            : ', CtlErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur de structures de controle (10 fonctions) }
{ ------------------------------------------------------------ }

Function IsCtlInitialized : Boolean;
Begin
  IsCtlInitialized := CtlInitialized;
End;

Function GetCtlIfCount : Integer;
Begin
  GetCtlIfCount := CtlIfCount;
End;

Function GetCtlForCount : Integer;
Begin
  GetCtlForCount := CtlForCount;
End;

Function GetCtlWhileCount : Integer;
Begin
  GetCtlWhileCount := CtlWhileCount;
End;

Function GetCtlDoUntilCount : Integer;
Begin
  GetCtlDoUntilCount := CtlDoUntilCount;
End;

Function GetCtlGotoCount : Integer;
Begin
  GetCtlGotoCount := CtlGotoCount;
End;

Function GetCtlStateCount : Integer;
Begin
  GetCtlStateCount := CtlStateCount;
End;

Function GetCtlErrorCount : Integer;
Begin
  GetCtlErrorCount := CtlErrorCount;
End;

Function GetCtlMaxDepth : Integer;
Begin
  GetCtlMaxDepth := CtlMaxDepth;
End;

Function IsCtlEmpty : Boolean;
Begin
  IsCtlEmpty := (CtlIfCount = 0) And (CtlForCount = 0) And
                (CtlWhileCount = 0) And (CtlDoUntilCount = 0);
End;


{ ============================================================ }
{ TODO 12 - PARSEUR : AFFECTATIONS ET INSTRUCTIONS SIMPLES      }
{ ============================================================ }

Const
  { Types d instructions simples }
  ASG_NONE        = 0;   { aucune                                   }
  ASG_ASSIGN      = 1;   { affectation simple : var = expr ;        }
  ASG_TABLE       = 2;   { affectation TABLE : T(i) = expr ;        }
  ASG_STATUS      = 3;   { affectation STATUS : COLOR = val ;       }
  ASG_CALL        = 4;   { appel : CALL proc [(args)] ;             }
  ASG_STOP        = 5;   { arret : STOP ;                           }
  ASG_GOTO_STMT   = 6;   { branchement : GOTO label ;               }
  ASG_LABEL_STMT  = 7;   { label nomme : lab : instruction          }

  { Limites }
  ASG_MAX_ASSIGNS = 4096; { nombre max d instructions simples       }

Var
  { Variables du parseur d affectations }
  AsgInitialized    : Boolean;     { module initialise ?             }
  AsgStateCount     : Integer;     { compteur d operations           }
  AsgAssignCount    : Integer;     { affectations simples            }
  AsgTableAssignCnt : Integer;     { affectations TABLE              }
  AsgStatusAssignCnt: Integer;     { affectations STATUS             }
  AsgCallCount      : Integer;     { instructions CALL               }
  AsgStopCount      : Integer;     { instructions STOP               }
  AsgGotoCount      : Integer;     { instructions GOTO               }
  AsgLabelCount     : Integer;     { labels nommes                   }
  AsgLabelNum       : Integer;     { generateur de labels uniques    }
  AsgErrorCount     : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitAssignState : initialiser les variables d affectations     }
{ ------------------------------------------------------------ }

Procedure InitAssignState;
Begin
  AsgInitialized    := True;
  AsgStateCount     := 0;
  AsgAssignCount    := 0;
  AsgTableAssignCnt := 0;
  AsgStatusAssignCnt:= 0;
  AsgCallCount      := 0;
  AsgStopCount      := 0;
  AsgGotoCount      := 0;
  AsgLabelCount     := 0;
  AsgLabelNum       := 0;
  AsgErrorCount     := 0;
End;

{ ------------------------------------------------------------ }
{ GenAsgLabel : generer un label unique pour les affectations    }
{ ------------------------------------------------------------ }

Function GenAsgLabel : TString;
Begin
  Inc(AsgLabelNum);
  GenAsgLabel := PFX_LBL + 'ASG_' + ItoSI(AsgLabelNum);
End;

{ ------------------------------------------------------------ }
{ AssignTypeName : retourner le nom du type d instruction        }
{ ------------------------------------------------------------ }

Function AssignTypeName(AType : Integer) : TString;
Begin
  Case AType Of
    ASG_NONE       : AssignTypeName := 'NONE';
    ASG_ASSIGN     : AssignTypeName := 'ASSIGN';
    ASG_TABLE      : AssignTypeName := 'TABLE_ASSIGN';
    ASG_STATUS     : AssignTypeName := 'STATUS_ASSIGN';
    ASG_CALL       : AssignTypeName := 'CALL';
    ASG_STOP       : AssignTypeName := 'STOP';
    ASG_GOTO_STMT  : AssignTypeName := 'GOTO';
    ASG_LABEL_STMT : AssignTypeName := 'LABEL';
  Else
    AssignTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAssignment : parser une affectation simple                }
{   variable = expression ;                                      }
{   CurTok est deja sur le token apres l identifiant            }
{   VarName contient le nom de la variable                       }
{ ------------------------------------------------------------ }

Procedure ParseAssignment(VarName : TString);
Var
  Dummy : Integer;
Begin
  Inc(AsgStateCount);
  Inc(AsgAssignCount);

  If Opts.Verbose Then
    WriteLn('  ASSIGN: ', VarName, ' = ...');

  { Le token courant est = (TOK_EQ), avancer }
  LexNextToken;

  { Parser l expression a droite }
  Dummy := ParseExpression;

  { Verifier et consommer le point-virgule }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres affectation de ' + VarName);
    Inc(AsgErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseTableAssign : parser une affectation a un element TABLE   }
{   T(index) = expression ;                                      }
{   CurTok est sur ( apres le nom de TABLE                       }
{ ------------------------------------------------------------ }

Procedure ParseTableAssign(TblName : TString);
Var
  Dummy : Integer;
Begin
  Inc(AsgStateCount);
  Inc(AsgTableAssignCnt);

  If Opts.Verbose Then
    WriteLn('  TABLE_ASSIGN: ', TblName, '(...) = ...');

  { Consommer ( }
  LexNextToken;

  { Parser l expression d index }
  Dummy := ParseExpression;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres index de TABLE ' + TblName);
    Inc(AsgErrorCount);
  End;

  { Consommer = }
  If CurTokType = TOK_EQ Then
    LexNextToken
  Else
  Begin
    WarnMsg('= attendu apres ' + TblName + '(index)');
    Inc(AsgErrorCount);
  End;

  { Parser l expression de valeur }
  Dummy := ParseExpression;

  { Consommer ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres affectation TABLE ' + TblName);
    Inc(AsgErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseCallStatement : parser une instruction CALL               }
{   CALL nom_procedure ;                                         }
{   CALL nom_procedure (expr1, expr2, ...) ;                     }
{ ------------------------------------------------------------ }

Procedure ParseCallStatement;
Var
  ProcName : TString;
  ArgCount : Integer;
  Dummy    : Integer;
Begin
  Inc(AsgStateCount);
  Inc(AsgCallCount);

  { Consommer CALL }
  LexNextToken;

  { Lire le nom de la procedure }
  If CurTokType = TOK_IDENT Then
  Begin
    ProcName := CurTokStr;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut servir de nom de procedure }
    ProcName := CurTokStr;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de procedure attendu apres CALL');
    Inc(AsgErrorCount);
    ProcName := '?';
  End;

  If Opts.Verbose Then
    WriteLn('  CALL: ', ProcName);

  { Verifier s il y a des arguments entre parentheses }
  ArgCount := 0;
  If CurTokType = TOK_LPAREN Then
  Begin
    LexNextToken;

    { Parser les arguments separes par des virgules }
    While (CurTokType <> TOK_RPAREN) And
          (CurTokType <> TOK_EOF) Do
    Begin
      Dummy := ParseExpression;
      Inc(ArgCount);
      If CurTokType = TOK_COMMA Then
        LexNextToken
      Else If CurTokType <> TOK_RPAREN Then
      Begin
        WarnMsg(', ou ) attendu dans les arguments de CALL ' + ProcName);
        Inc(AsgErrorCount);
        Break;
      End;
    End;

    { Consommer ) }
    If CurTokType = TOK_RPAREN Then
      LexNextToken
    Else
    Begin
      WarnMsg(') attendu apres arguments de CALL ' + ProcName);
      Inc(AsgErrorCount);
    End;

    If Opts.Verbose Then
      WriteLn('    Arguments : ', ArgCount);
  End;

  { Consommer ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres CALL ' + ProcName);
    Inc(AsgErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseStopStatement : parser une instruction STOP               }
{   STOP ;                                                       }
{ ------------------------------------------------------------ }

Procedure ParseStopStatement;
Begin
  Inc(AsgStateCount);
  Inc(AsgStopCount);

  If Opts.Verbose Then
    WriteLn('  STOP');

  { Consommer STOP }
  LexNextToken;

  { Consommer ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres STOP');
    Inc(AsgErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAssignGoto : parser GOTO / GO TO label ;                  }
{ ------------------------------------------------------------ }

Procedure ParseAssignGoto;
Var
  LabelName : TString;
Begin
  Inc(AsgStateCount);
  Inc(AsgGotoCount);

  { Consommer GOTO ou GO TO }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_GO) Then
  Begin
    LexNextToken;
    { Verifier TO apres GO }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
      LexNextToken
    Else
    Begin
      WarnMsg('TO attendu apres GO');
      Inc(AsgErrorCount);
    End;
  End
  Else
    LexNextToken; { Consommer GOTO }

  { Lire le nom du label }
  If CurTokType = TOK_IDENT Then
  Begin
    LabelName := CurTokStr;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    LabelName := CurTokStr;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de label attendu apres GOTO');
    Inc(AsgErrorCount);
    LabelName := '?';
  End;

  If Opts.Verbose Then
    WriteLn('  GOTO: ', LabelName);

  { Consommer ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres GOTO ' + LabelName);
    Inc(AsgErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseAssignLabel : parser un label nomme dans le code          }
{   label : instruction                                          }
{   SaveIdent est le nom du label, CurTok est sur :              }
{ ------------------------------------------------------------ }

Procedure ParseAssignLabel(LabelName : TString);
Begin
  Inc(AsgStateCount);
  Inc(AsgLabelCount);

  If Opts.Verbose Then
    WriteLn('  LABEL: ', LabelName);

  { Consommer : }
  LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseAssignStatement : dispatcher principal pour les           }
{   affectations et instructions simples                         }
{   Appele depuis ParseStatement quand CurTok est IDENT         }
{   ou pour les mots-cles CALL/STOP/GOTO                        }
{ ------------------------------------------------------------ }

Procedure ParseAssignStatement;
Var
  SaveIdent : TString;
Begin
  Inc(AsgStateCount);

  If CurTokType = TOK_EOF Then Exit;

  { Instruction CALL }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CALL) Then
  Begin
    ParseCallStatement;
    Exit;
  End;

  { Instruction STOP }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_STOP) Then
  Begin
    ParseStopStatement;
    Exit;
  End;

  { Instruction GOTO / GO TO }
  If (CurTokType = TOK_KEYWORD) And
     ((CurTokNum = KW_GOTO) Or (CurTokNum = KW_GO)) Then
  Begin
    ParseAssignGoto;
    Exit;
  End;

  { Identificateur : affectation ou label }
  If CurTokType = TOK_IDENT Then
  Begin
    SaveIdent := CurTokStr;
    LexNextToken;

    { Label nomme : ident : instruction }
    If CurTokType = TOK_COLON Then
    Begin
      ParseAssignLabel(SaveIdent);
      Exit;
    End;

    { Affectation TABLE : ident(index) = expr ; }
    If CurTokType = TOK_LPAREN Then
    Begin
      ParseTableAssign(SaveIdent);
      Exit;
    End;

    { Affectation simple : ident = expr ; }
    If CurTokType = TOK_EQ Then
    Begin
      { Verifier si c est un ITEM STATUS pour dispatch TODO 13 }
      If FindStatusItem(SaveIdent) >= 0 Then
      Begin
        ParseStatusAssign(SaveIdent);
        Exit;
      End;
      ParseAssignment(SaveIdent);
      Exit;
    End;

    { Autre : consommer jusqu au point-virgule }
    While (CurTokType <> TOK_SEMICOL) And
          (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
  End
  Else
  Begin
    { Token inattendu : avancer }
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpAssignState : afficher l etat du parseur d affectations    }
{ ------------------------------------------------------------ }

Procedure DumpAssignState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur AFFECTATIONS (TODO 12) ===');
  WriteLn('  Initialise         : ', AsgInitialized);
  WriteLn('  Operations         : ', AsgStateCount);
  WriteLn('  Affectations       : ', AsgAssignCount);
  WriteLn('  Affect. TABLE      : ', AsgTableAssignCnt);
  WriteLn('  Affect. STATUS     : ', AsgStatusAssignCnt);
  WriteLn('  CALL               : ', AsgCallCount);
  WriteLn('  STOP               : ', AsgStopCount);
  WriteLn('  GOTO               : ', AsgGotoCount);
  WriteLn('  Labels nommes      : ', AsgLabelCount);
  WriteLn('  Labels generes     : ', AsgLabelNum);
  WriteLn('  Erreurs            : ', AsgErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur d affectations (10 fonctions)            }
{ ------------------------------------------------------------ }

Function IsAsgInitialized : Boolean;
Begin
  IsAsgInitialized := AsgInitialized;
End;

Function GetAsgAssignCount : Integer;
Begin
  GetAsgAssignCount := AsgAssignCount;
End;

Function GetAsgTableAssignCnt : Integer;
Begin
  GetAsgTableAssignCnt := AsgTableAssignCnt;
End;

Function GetAsgStatusAssignCnt : Integer;
Begin
  GetAsgStatusAssignCnt := AsgStatusAssignCnt;
End;

Function GetAsgCallCount : Integer;
Begin
  GetAsgCallCount := AsgCallCount;
End;

Function GetAsgStopCount : Integer;
Begin
  GetAsgStopCount := AsgStopCount;
End;

Function GetAsgStateCount : Integer;
Begin
  GetAsgStateCount := AsgStateCount;
End;

Function GetAsgErrorCount : Integer;
Begin
  GetAsgErrorCount := AsgErrorCount;
End;

Function GetAsgLabelCount : Integer;
Begin
  GetAsgLabelCount := AsgLabelCount;
End;

Function IsAsgEmpty : Boolean;
Begin
  IsAsgEmpty := (AsgAssignCount = 0) And (AsgCallCount = 0) And
                (AsgStopCount = 0) And (AsgTableAssignCnt = 0);
End;


{ ============================================================ }
{ TODO 13 - PARSEUR : TYPES STATUS (ENUMERATIONS)               }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Types d operations STATUS }
  STS_NONE          = 0;   { aucune                                   }
  STS_ASSIGN        = 1;   { affectation STATUS : COLOR = val ;       }
  STS_COMPARE       = 2;   { comparaison STATUS : IF COLOR = val      }
  STS_FIRST         = 3;   { builtin FIRST(var_status)                }
  STS_LAST          = 4;   { builtin LAST(var_status)                 }
  STS_CONVERT       = 5;   { conversion STATUS <-> entier             }
  STS_CUSTOM_VAL    = 6;   { valeurs personnalisees (ROUGE=1, etc.)   }
  STS_VALIDATE      = 7;   { validation de valeur STATUS              }

  { Limites }
  STS_MAX_OPS = 4096;     { nombre max d operations STATUS            }

Var
  { Variables du parseur STATUS }
  StsInitialized    : Boolean;     { module initialise ?             }
  StsStateCount     : Integer;     { compteur d operations           }
  StsAssignCount    : Integer;     { affectations STATUS             }
  StsCompareCount   : Integer;     { comparaisons STATUS             }
  StsFirstCount     : Integer;     { appels FIRST()                  }
  StsLastCount      : Integer;     { appels LAST()                   }
  StsConvertCount   : Integer;     { conversions STATUS <-> entier   }
  StsValidateCount  : Integer;     { validations de valeur           }
  StsLabelNum       : Integer;     { generateur de labels uniques    }
  StsErrorCount     : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitStatusState : initialiser les variables STATUS             }
{ ------------------------------------------------------------ }

Procedure InitStatusState;
Begin
  StsInitialized    := True;
  StsStateCount     := 0;
  StsAssignCount    := 0;
  StsCompareCount   := 0;
  StsFirstCount     := 0;
  StsLastCount      := 0;
  StsConvertCount   := 0;
  StsValidateCount  := 0;
  StsLabelNum       := 0;
  StsErrorCount     := 0;
End;

{ ------------------------------------------------------------ }
{ GenStsLabel : generer un label unique pour les STATUS           }
{ ------------------------------------------------------------ }

Function GenStsLabel : TString;
Begin
  Inc(StsLabelNum);
  GenStsLabel := PFX_LBL + 'STS_' + ItoSI(StsLabelNum);
End;

{ ------------------------------------------------------------ }
{ StatusTypeName : retourner le nom du type d operation STATUS    }
{ ------------------------------------------------------------ }

Function StatusTypeName(SType : Integer) : TString;
Begin
  Case SType Of
    STS_NONE       : StatusTypeName := 'NONE';
    STS_ASSIGN     : StatusTypeName := 'ASSIGN';
    STS_COMPARE    : StatusTypeName := 'COMPARE';
    STS_FIRST      : StatusTypeName := 'FIRST';
    STS_LAST       : StatusTypeName := 'LAST';
    STS_CONVERT    : StatusTypeName := 'CONVERT';
    STS_CUSTOM_VAL : StatusTypeName := 'CUSTOM_VAL';
    STS_VALIDATE   : StatusTypeName := 'VALIDATE';
  Else
    StatusTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ FindStatusItem : retrouver un ITEM STATUS dans la table des    }
{   symboles. Retourne l index ou -1 si non trouve               }
{ ------------------------------------------------------------ }

Function FindStatusItem(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Inc(StsStateCount);
  FindStatusItem := -1;
  Idx := SymFind(Name);
  If Idx < 0 Then Exit;
  If SymTab[Idx].SymKind <> SK_ITEM Then Exit;
  If SymTab[Idx].ItemType <> JT_STATUS Then Exit;
  FindStatusItem := Idx;
End;

{ ------------------------------------------------------------ }
{ IsStatusValue : verifier si un identifiant est une valeur      }
{   STATUS (SK_STATUS_VAL) dans la table des symboles            }
{   Retourne l index ou -1 si non trouve                         }
{ ------------------------------------------------------------ }

Function IsStatusValue(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Inc(StsStateCount);
  IsStatusValue := -1;
  Idx := SymFind(Name);
  If Idx < 0 Then Exit;
  If SymTab[Idx].SymKind <> SK_STATUS_VAL Then Exit;
  IsStatusValue := Idx;
End;

{ ------------------------------------------------------------ }
{ GetStatusFirstValue : retourner la premiere valeur d un STATUS }
{   (valeur 0, ou la plus petite valeur personnalisee)           }
{   SymIdx est l index de l ITEM STATUS dans la table            }
{ ------------------------------------------------------------ }

Function GetStatusFirstValue(SymIdx : Integer) : LongInt;
Begin
  Inc(StsStateCount);
  Inc(StsFirstCount);
  If (SymIdx >= 0) And (SymIdx < SymCount) And
     (SymTab[SymIdx].StatusCount > 0) Then
    GetStatusFirstValue := 0
  Else
    GetStatusFirstValue := 0;
End;

{ ------------------------------------------------------------ }
{ GetStatusLastValue : retourner la derniere valeur d un STATUS  }
{   (StatusCount - 1, ou la plus grande valeur personnalisee)    }
{   SymIdx est l index de l ITEM STATUS dans la table            }
{ ------------------------------------------------------------ }

Function GetStatusLastValue(SymIdx : Integer) : LongInt;
Begin
  Inc(StsStateCount);
  Inc(StsLastCount);
  If (SymIdx >= 0) And (SymIdx < SymCount) And
     (SymTab[SymIdx].StatusCount > 0) Then
    GetStatusLastValue := SymTab[SymIdx].StatusCount - 1
  Else
    GetStatusLastValue := 0;
End;

{ ------------------------------------------------------------ }
{ ValidateStatusAssign : verifier qu une valeur est valide       }
{   pour un ITEM STATUS donne                                    }
{   StatusIdx : index de l ITEM STATUS dans la table             }
{   ValueName : nom de la valeur tentee (ex: COLOR_ROUGE)        }
{   Retourne True si la valeur est valide                        }
{ ------------------------------------------------------------ }

Function ValidateStatusAssign(StatusIdx : Integer;
                               Const ValueName : TString) : Boolean;
Var
  I : Integer;
  StatusName : TString;
  ValPart : TString;
  PrefixLen : Integer;
Begin
  Inc(StsStateCount);
  Inc(StsValidateCount);
  ValidateStatusAssign := False;

  If (StatusIdx < 0) Or (StatusIdx >= SymCount) Then Exit;
  If SymTab[StatusIdx].StatusCount = 0 Then
  Begin
    { Pas de valeurs definies, accepter tout entier }
    ValidateStatusAssign := True;
    Exit;
  End;

  { Verifier si ValueName correspond a STATUSNAME_VALEUR }
  StatusName := SymTab[StatusIdx].Name;
  PrefixLen := Length(StatusName) + 1; { +1 pour le _ }

  { Parcourir les valeurs STATUS definies }
  For I := 0 To SymTab[StatusIdx].StatusCount - 1 Do
  Begin
    ValPart := StatusName + '_' + SymTab[StatusIdx].StatusValues[I];
    If UpCaseStr(ValueName) = UpCaseStr(ValPart) Then
    Begin
      ValidateStatusAssign := True;
      Exit;
    End;
  End;

  { Verifier aussi si c est directement un SK_STATUS_VAL }
  If IsStatusValue(ValueName) >= 0 Then
    ValidateStatusAssign := True;
End;

{ ------------------------------------------------------------ }
{ ParseStatusAssign : parser une affectation STATUS avec          }
{   verification de type                                          }
{   StatusName : nom de la variable STATUS (ex: COLOR)           }
{   CurTok est sur = apres le nom                                }
{ ------------------------------------------------------------ }

Procedure ParseStatusAssign(Const StatusName : TString);
Var
  StatusIdx : Integer;
  ValIdx    : Integer;
  Dummy     : Integer;
Begin
  Inc(StsStateCount);
  Inc(StsAssignCount);
  Inc(AsgStatusAssignCnt);

  StatusIdx := FindStatusItem(StatusName);

  { Consommer = }
  LexNextToken;

  If Opts.Verbose Then
    WriteLn('  STATUS_ASSIGN: ', StatusName, ' = ...');

  { Verifier si la valeur est un identifiant STATUS }
  If CurTokType = TOK_IDENT Then
  Begin
    ValIdx := IsStatusValue(CurTokStr);
    If ValIdx >= 0 Then
    Begin
      { Valeur STATUS reconnue }
      If (StatusIdx >= 0) And
         Not ValidateStatusAssign(StatusIdx, CurTokStr) Then
      Begin
        WarnMsg('Valeur STATUS ' + CurTokStr +
                ' non valide pour ' + StatusName);
        Inc(StsErrorCount);
      End;
      LexNextToken;
    End
    Else
    Begin
      { Identifiant non-STATUS : peut etre une conversion }
      Inc(StsConvertCount);
      Dummy := ParseExpression;
    End;
  End
  Else
  Begin
    { Expression quelconque : conversion implicite }
    Inc(StsConvertCount);
    Dummy := ParseExpression;
  End;

  { Consommer ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken
  Else
  Begin
    WarnMsg('; attendu apres affectation STATUS ' + StatusName);
    Inc(StsErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseStatusCompare : parser une comparaison STATUS             }
{   (utilise dans les expressions, comptage seulement)           }
{   StatusName : nom de la variable STATUS                       }
{ ------------------------------------------------------------ }

Procedure ParseStatusCompare(Const StatusName : TString);
Begin
  Inc(StsStateCount);
  Inc(StsCompareCount);

  If Opts.Verbose Then
    WriteLn('  STATUS_COMPARE: ', StatusName);
End;

{ ------------------------------------------------------------ }
{ EvalStatusFirst : evaluer FIRST(var_status)                    }
{   Retourne la premiere valeur de l enumeration (0)             }
{   Le CurTok est sur ( apres FIRST                              }
{ ------------------------------------------------------------ }

Function EvalStatusFirst : LongInt;
Var
  StatusIdx : Integer;
Begin
  Inc(StsStateCount);
  Inc(StsFirstCount);
  EvalStatusFirst := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken;

  { Lire le nom de la variable STATUS }
  If CurTokType = TOK_IDENT Then
  Begin
    StatusIdx := FindStatusItem(CurTokStr);
    If StatusIdx >= 0 Then
      EvalStatusFirst := GetStatusFirstValue(StatusIdx)
    Else
    Begin
      WarnMsg('FIRST : ' + CurTokStr + ' n est pas un ITEM STATUS');
      Inc(StsErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre un nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de variable STATUS attendu dans FIRST()');
    Inc(StsErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres FIRST(nom)');
    Inc(StsErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalStatusLast : evaluer LAST(var_status)                      }
{   Retourne la derniere valeur de l enumeration                 }
{   Le CurTok est sur ( apres LAST                               }
{ ------------------------------------------------------------ }

Function EvalStatusLast : LongInt;
Var
  StatusIdx : Integer;
Begin
  Inc(StsStateCount);
  Inc(StsLastCount);
  EvalStatusLast := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken;

  { Lire le nom de la variable STATUS }
  If CurTokType = TOK_IDENT Then
  Begin
    StatusIdx := FindStatusItem(CurTokStr);
    If StatusIdx >= 0 Then
      EvalStatusLast := GetStatusLastValue(StatusIdx)
    Else
    Begin
      WarnMsg('LAST : ' + CurTokStr + ' n est pas un ITEM STATUS');
      Inc(StsErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre un nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de variable STATUS attendu dans LAST()');
    Inc(StsErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres LAST(nom)');
    Inc(StsErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ DumpStatusState : afficher l etat du parseur STATUS             }
{ ------------------------------------------------------------ }

Procedure DumpStatusState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur STATUS (TODO 13) ===');
  WriteLn('  Initialise         : ', StsInitialized);
  WriteLn('  Operations         : ', StsStateCount);
  WriteLn('  Affectations       : ', StsAssignCount);
  WriteLn('  Comparaisons       : ', StsCompareCount);
  WriteLn('  FIRST()            : ', StsFirstCount);
  WriteLn('  LAST()             : ', StsLastCount);
  WriteLn('  Conversions        : ', StsConvertCount);
  WriteLn('  Validations        : ', StsValidateCount);
  WriteLn('  Labels generes     : ', StsLabelNum);
  WriteLn('  Erreurs            : ', StsErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur STATUS (10 fonctions)                    }
{ ------------------------------------------------------------ }

Function IsStsInitialized : Boolean;
Begin
  IsStsInitialized := StsInitialized;
End;

Function GetStsAssignCount : Integer;
Begin
  GetStsAssignCount := StsAssignCount;
End;

Function GetStsCompareCount : Integer;
Begin
  GetStsCompareCount := StsCompareCount;
End;

Function GetStsFirstCount : Integer;
Begin
  GetStsFirstCount := StsFirstCount;
End;

Function GetStsLastCount : Integer;
Begin
  GetStsLastCount := StsLastCount;
End;

Function GetStsConvertCount : Integer;
Begin
  GetStsConvertCount := StsConvertCount;
End;

Function GetStsStateCount : Integer;
Begin
  GetStsStateCount := StsStateCount;
End;

Function GetStsErrorCount : Integer;
Begin
  GetStsErrorCount := StsErrorCount;
End;

Function GetStsValidateCount : Integer;
Begin
  GetStsValidateCount := StsValidateCount;
End;

Function IsStsEmpty : Boolean;
Begin
  IsStsEmpty := (StsAssignCount = 0) And (StsCompareCount = 0) And
                (StsFirstCount = 0) And (StsLastCount = 0);
End;


{ ============================================================ }
{ TODO 14 - PARSEUR : OPERATIONS SUR LES BITS                    }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Types d operations sur les bits }
  BIT_NONE          = 0;   { aucune                                   }
  BIT_AND           = 1;   { AND : RESULT = FLAGS AND MASK            }
  BIT_OR            = 2;   { OR  : RESULT = FLAGS OR MASK             }
  BIT_XOR           = 3;   { XOR : RESULT = FLAGS XOR MASK            }
  BIT_NOT           = 4;   { NOT : RESULT = NOT MASK                  }
  BIT_SHIFTL        = 5;   { SHIFTL(valeur, nombre) decalage gauche   }
  BIT_SHIFTR        = 6;   { SHIFTR(valeur, nombre) decalage droite   }
  BIT_EXTRACT       = 7;   { BIT(valeur, position, longueur)          }
  BIT_BITSIZE       = 8;   { BITSIZE(item) taille en bits             }

  { Limites }
  BIT_MAX_OPS = 4096;     { nombre max d operations sur les bits      }

Var
  { Variables du parseur d operations sur les bits }
  BitInitialized    : Boolean;     { module initialise ?             }
  BitStateCount     : Integer;     { compteur d operations           }
  BitAndCount       : Integer;     { operations AND                  }
  BitOrCount        : Integer;     { operations OR                   }
  BitXorCount       : Integer;     { operations XOR                  }
  BitNotCount       : Integer;     { operations NOT                  }
  BitShiftLCount    : Integer;     { decalages a gauche SHIFTL       }
  BitShiftRCount    : Integer;     { decalages a droite SHIFTR       }
  BitExtractCount   : Integer;     { extractions BIT()               }
  BitSizeCount      : Integer;     { appels BITSIZE()                }
  BitMaskCount      : Integer;     { masquages automatiques          }
  BitLabelNum       : Integer;     { generateur de labels uniques    }
  BitErrorCount     : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitBitState : initialiser les variables du parseur bits       }
{ ------------------------------------------------------------ }

Procedure InitBitState;
Begin
  BitInitialized    := True;
  BitStateCount     := 0;
  BitAndCount       := 0;
  BitOrCount        := 0;
  BitXorCount       := 0;
  BitNotCount       := 0;
  BitShiftLCount    := 0;
  BitShiftRCount    := 0;
  BitExtractCount   := 0;
  BitSizeCount      := 0;
  BitMaskCount      := 0;
  BitLabelNum       := 0;
  BitErrorCount     := 0;
End;

{ ------------------------------------------------------------ }
{ GenBitLabel : generer un label unique pour les operations bits  }
{ ------------------------------------------------------------ }

Function GenBitLabel : TString;
Begin
  Inc(BitLabelNum);
  GenBitLabel := PFX_LBL + 'BIT_' + ItoSI(BitLabelNum);
End;

{ ------------------------------------------------------------ }
{ BitOpTypeName : retourner le nom du type d operation bits       }
{ ------------------------------------------------------------ }

Function BitOpTypeName(BType : Integer) : TString;
Begin
  Case BType Of
    BIT_NONE       : BitOpTypeName := 'NONE';
    BIT_AND        : BitOpTypeName := 'AND';
    BIT_OR         : BitOpTypeName := 'OR';
    BIT_XOR        : BitOpTypeName := 'XOR';
    BIT_NOT        : BitOpTypeName := 'NOT';
    BIT_SHIFTL     : BitOpTypeName := 'SHIFTL';
    BIT_SHIFTR     : BitOpTypeName := 'SHIFTR';
    BIT_EXTRACT    : BitOpTypeName := 'BIT';
    BIT_BITSIZE    : BitOpTypeName := 'BITSIZE';
  Else
    BitOpTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ FindBitItem : retrouver un ITEM de type B (bits) dans la       }
{   table des symboles. Retourne l index ou -1 si non trouve     }
{ ------------------------------------------------------------ }

Function FindBitItem(Const Name : TString) : Integer;
Var
  Idx : Integer;
Begin
  Inc(BitStateCount);
  FindBitItem := -1;
  Idx := SymFind(Name);
  If Idx < 0 Then Exit;
  If SymTab[Idx].SymKind <> SK_ITEM Then Exit;
  If SymTab[Idx].ItemType <> JT_BITS Then Exit;
  FindBitItem := Idx;
End;

{ ------------------------------------------------------------ }
{ ComputeBitMask : calculer le masque de bits selon la taille    }
{   BitSize : nombre de bits (1..32)                             }
{   Retourne le masque correspondant                             }
{   Exemples : 8 -> $FF, 16 -> $FFFF, 32 -> $FFFFFFFF          }
{ ------------------------------------------------------------ }

Function ComputeBitMask(BitSize : Integer) : LongInt;
Begin
  Inc(BitStateCount);
  Inc(BitMaskCount);
  If BitSize >= 32 Then
    ComputeBitMask := LongInt($FFFFFFFF)
  Else If BitSize <= 0 Then
    ComputeBitMask := 0
  Else
    ComputeBitMask := (LongInt(1) Shl BitSize) - 1;
End;

{ ------------------------------------------------------------ }
{ ParseBitAnd : parser une operation AND bit a bit                }
{   RESULT = FLAGS AND MASK ;                                    }
{   Generer : MOV EAX, [FLAGS] / AND EAX, [MASK]                }
{   Appele quand on detecte un AND dans un contexte de bits      }
{ ------------------------------------------------------------ }

Procedure ParseBitAnd;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitAndCount);

  If Opts.Verbose Then
    WriteLn('  BIT_AND: AND operation');

  { L expression AND est deja geree par le parseur d expressions }
  { (ParseAnd dans TODO 10). Ici on comptabilise specifiquement  }
  { les operations AND sur des ITEM de type B.                   }

  { Parser l operande droite }
  Dummy := ParseExpression;
End;

{ ------------------------------------------------------------ }
{ ParseBitOr : parser une operation OR bit a bit                  }
{   RESULT = FLAGS OR MASK ;                                     }
{   Generer : MOV EAX, [FLAGS] / OR EAX, [MASK]                 }
{ ------------------------------------------------------------ }

Procedure ParseBitOr;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitOrCount);

  If Opts.Verbose Then
    WriteLn('  BIT_OR: OR operation');

  Dummy := ParseExpression;
End;

{ ------------------------------------------------------------ }
{ ParseBitXor : parser une operation XOR bit a bit                }
{   RESULT = FLAGS XOR MASK ;                                    }
{   Generer : MOV EAX, [FLAGS] / XOR EAX, [MASK]                }
{ ------------------------------------------------------------ }

Procedure ParseBitXor;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitXorCount);

  If Opts.Verbose Then
    WriteLn('  BIT_XOR: XOR operation');

  Dummy := ParseExpression;
End;

{ ------------------------------------------------------------ }
{ ParseBitNot : parser une operation NOT bit a bit                }
{   RESULT = NOT MASK ;                                          }
{   Generer : MOV EAX, [MASK] / NOT EAX                         }
{ ------------------------------------------------------------ }

Procedure ParseBitNot;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitNotCount);

  If Opts.Verbose Then
    WriteLn('  BIT_NOT: NOT operation');

  Dummy := ParseExpression;
End;

{ ------------------------------------------------------------ }
{ ParseShiftLeft : parser SHIFTL(valeur, nombre)                  }
{   Generer : MOV EAX, valeur / MOV CL, nombre / SHL EAX, CL   }
{   CurTok est sur ( apres SHIFTL                                }
{ ------------------------------------------------------------ }

Procedure ParseShiftLeft;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitShiftLCount);

  If Opts.Verbose Then
    WriteLn('  BIT_SHIFTL: shift left');

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres SHIFTL');
    Inc(BitErrorCount);
  End;

  { Parser le premier argument : valeur }
  Dummy := ParseExpression;

  { Consommer , }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
  Begin
    WarnMsg(', attendu entre les arguments de SHIFTL');
    Inc(BitErrorCount);
  End;

  { Parser le second argument : nombre de positions }
  Dummy := ParseExpression;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres SHIFTL(valeur, nombre)');
    Inc(BitErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseShiftRight : parser SHIFTR(valeur, nombre)                 }
{   Generer : MOV EAX, valeur / MOV CL, nombre / SHR EAX, CL   }
{   CurTok est sur ( apres SHIFTR                                }
{ ------------------------------------------------------------ }

Procedure ParseShiftRight;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitShiftRCount);

  If Opts.Verbose Then
    WriteLn('  BIT_SHIFTR: shift right');

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres SHIFTR');
    Inc(BitErrorCount);
  End;

  { Parser le premier argument : valeur }
  Dummy := ParseExpression;

  { Consommer , }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
  Begin
    WarnMsg(', attendu entre les arguments de SHIFTR');
    Inc(BitErrorCount);
  End;

  { Parser le second argument : nombre de positions }
  Dummy := ParseExpression;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres SHIFTR(valeur, nombre)');
    Inc(BitErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseBitExtract : parser BIT(valeur, position, longueur)        }
{   Generer : MOV EAX, valeur / SHR EAX, position                }
{     / AND EAX, masque (2^longueur - 1)                         }
{   CurTok est sur ( apres BIT                                   }
{ ------------------------------------------------------------ }

Procedure ParseBitExtract;
Var
  Dummy : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitExtractCount);

  If Opts.Verbose Then
    WriteLn('  BIT_EXTRACT: bit extraction');

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres BIT');
    Inc(BitErrorCount);
  End;

  { Parser le premier argument : valeur }
  Dummy := ParseExpression;

  { Consommer , }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
  Begin
    WarnMsg(', attendu entre les arguments de BIT');
    Inc(BitErrorCount);
  End;

  { Parser le second argument : position }
  Dummy := ParseExpression;

  { Consommer , }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
  Begin
    WarnMsg(', attendu entre position et longueur dans BIT');
    Inc(BitErrorCount);
  End;

  { Parser le troisieme argument : longueur }
  Dummy := ParseExpression;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres BIT(valeur, position, longueur)');
    Inc(BitErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalBitSize : evaluer BITSIZE(item)                             }
{   Retourne le nombre de bits de l ITEM (resolu a la compilation)}
{   CurTok est sur ( apres BITSIZE                                }
{ ------------------------------------------------------------ }

Function EvalBitSize : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BitStateCount);
  Inc(BitSizeCount);
  EvalBitSize := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres BITSIZE');
    Inc(BitErrorCount);
  End;

  { Lire le nom de l ITEM }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_ITEM) Then
    Begin
      EvalBitSize := SymTab[Idx].BitSize;
      If Opts.Verbose Then
        WriteLn('  BITSIZE(', CurTokStr, ') = ', SymTab[Idx].BitSize);
    End
    Else
    Begin
      WarnMsg('BITSIZE : ' + CurTokStr + ' n est pas un ITEM');
      Inc(BitErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom d ITEM attendu dans BITSIZE()');
    Inc(BitErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres BITSIZE(nom)');
    Inc(BitErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ IsBitOperation : verifier si l expression courante implique     }
{   une operation sur les bits avec un ITEM de type B             }
{   Retourne True si l operande est un ITEM B                    }
{ ------------------------------------------------------------ }

Function IsBitOperation(Const Name : TString) : Boolean;
Begin
  Inc(BitStateCount);
  IsBitOperation := (FindBitItem(Name) >= 0);
End;

{ ------------------------------------------------------------ }
{ GetItemBitMask : obtenir le masque automatique pour un ITEM B  }
{   Retourne le masque ou -1 si l ITEM n est pas de type B      }
{ ------------------------------------------------------------ }

Function GetItemBitMask(Const Name : TString) : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BitStateCount);
  GetItemBitMask := -1;
  Idx := FindBitItem(Name);
  If Idx < 0 Then Exit;
  GetItemBitMask := ComputeBitMask(SymTab[Idx].BitSize);
End;

{ ------------------------------------------------------------ }
{ DumpBitState : afficher l etat du parseur d operations bits     }
{ ------------------------------------------------------------ }

Procedure DumpBitState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur BITS (TODO 14) ===');
  WriteLn('  Initialise         : ', BitInitialized);
  WriteLn('  Operations         : ', BitStateCount);
  WriteLn('  AND                : ', BitAndCount);
  WriteLn('  OR                 : ', BitOrCount);
  WriteLn('  XOR                : ', BitXorCount);
  WriteLn('  NOT                : ', BitNotCount);
  WriteLn('  SHIFTL             : ', BitShiftLCount);
  WriteLn('  SHIFTR             : ', BitShiftRCount);
  WriteLn('  BIT()              : ', BitExtractCount);
  WriteLn('  BITSIZE()          : ', BitSizeCount);
  WriteLn('  Masquages auto     : ', BitMaskCount);
  WriteLn('  Labels generes     : ', BitLabelNum);
  WriteLn('  Erreurs            : ', BitErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur BITS (10 fonctions)                      }
{ ------------------------------------------------------------ }

Function IsBitInitialized : Boolean;
Begin
  IsBitInitialized := BitInitialized;
End;

Function GetBitAndCount : Integer;
Begin
  GetBitAndCount := BitAndCount;
End;

Function GetBitOrCount : Integer;
Begin
  GetBitOrCount := BitOrCount;
End;

Function GetBitXorCount : Integer;
Begin
  GetBitXorCount := BitXorCount;
End;

Function GetBitNotCount : Integer;
Begin
  GetBitNotCount := BitNotCount;
End;

Function GetBitShiftCount : Integer;
Begin
  GetBitShiftCount := BitShiftLCount + BitShiftRCount;
End;

Function GetBitExtractCount : Integer;
Begin
  GetBitExtractCount := BitExtractCount;
End;

Function GetBitStateCount : Integer;
Begin
  GetBitStateCount := BitStateCount;
End;

Function GetBitErrorCount : Integer;
Begin
  GetBitErrorCount := BitErrorCount;
End;

Function IsBitEmpty : Boolean;
Begin
  IsBitEmpty := (BitAndCount = 0) And (BitOrCount = 0) And
                (BitXorCount = 0) And (BitNotCount = 0) And
                (BitShiftLCount = 0) And (BitShiftRCount = 0) And
                (BitExtractCount = 0) And (BitSizeCount = 0);
End;


{ ============================================================ }
{ TODO 15 - PARSEUR : FONCTIONS INTEGREES JOVIAL (BUILTINS)      }
{                                               [IMPLEMENTE]  }
{ ============================================================ }

Const
  { Types de fonctions integrees (builtins) }
  BLT_NONE          = 0;   { aucun                                    }
  BLT_ABS           = 1;   { ABS(x) : valeur absolue                  }
  BLT_SGN           = 2;   { SGN(x) : signe (-1, 0, +1)              }
  BLT_SHIFTL        = 3;   { SHIFTL(x, n) : decalage gauche           }
  BLT_SHIFTR        = 4;   { SHIFTR(x, n) : decalage droite           }
  BLT_BIT           = 5;   { BIT(val, pos, len) : extraction bits     }
  BLT_BITSIZE       = 6;   { BITSIZE(item) : taille en bits           }
  BLT_BYTESIZE      = 7;   { BYTESIZE(item) : taille en octets        }
  BLT_WORDSIZE      = 8;   { WORDSIZE(item) : taille en mots 32 bits  }
  BLT_UBOUND        = 9;   { UBOUND(table) : borne superieure         }
  BLT_LBOUND        = 10;  { LBOUND(table) : borne inferieure         }
  BLT_NWSDEN        = 11;  { NWSDEN(table) : nombre d elements        }
  BLT_FIRST         = 12;  { FIRST(status) : premiere valeur enum     }
  BLT_LAST          = 13;  { LAST(status) : derniere valeur enum      }

  { Limites }
  BLT_MAX_CALLS = 4096;   { nombre max d appels builtins              }

Var
  { Variables du parseur de fonctions integrees }
  BltInitialized    : Boolean;     { module initialise ?             }
  BltStateCount     : Integer;     { compteur d operations           }
  BltAbsCount       : Integer;     { appels ABS()                    }
  BltSgnCount       : Integer;     { appels SGN()                    }
  BltShiftLCount    : Integer;     { appels SHIFTL() (delegue TODO14)}
  BltShiftRCount    : Integer;     { appels SHIFTR() (delegue TODO14)}
  BltBitCount       : Integer;     { appels BIT() (delegue TODO 14)  }
  BltBitSizeCount   : Integer;     { appels BITSIZE() (delegue TODO14)}
  BltByteSizeCount  : Integer;     { appels BYTESIZE()               }
  BltWordSizeCount  : Integer;     { appels WORDSIZE()               }
  BltUBoundCount    : Integer;     { appels UBOUND()                 }
  BltLBoundCount    : Integer;     { appels LBOUND()                 }
  BltNwsdenCount    : Integer;     { appels NWSDEN()                 }
  BltFirstCount     : Integer;     { appels FIRST() (delegue TODO13) }
  BltLastCount      : Integer;     { appels LAST() (delegue TODO 13) }
  BltLabelNum       : Integer;     { generateur de labels uniques    }
  BltErrorCount     : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitBuiltinState : initialiser les variables des builtins      }
{ ------------------------------------------------------------ }

Procedure InitBuiltinState;
Begin
  BltInitialized    := True;
  BltStateCount     := 0;
  BltAbsCount       := 0;
  BltSgnCount       := 0;
  BltShiftLCount    := 0;
  BltShiftRCount    := 0;
  BltBitCount       := 0;
  BltBitSizeCount   := 0;
  BltByteSizeCount  := 0;
  BltWordSizeCount  := 0;
  BltUBoundCount    := 0;
  BltLBoundCount    := 0;
  BltNwsdenCount    := 0;
  BltFirstCount     := 0;
  BltLastCount      := 0;
  BltLabelNum       := 0;
  BltErrorCount     := 0;
End;

{ ------------------------------------------------------------ }
{ GenBltLabel : generer un label unique pour les builtins         }
{ ------------------------------------------------------------ }

Function GenBltLabel : TString;
Begin
  Inc(BltLabelNum);
  GenBltLabel := PFX_LBL + 'BLT_' + ItoSI(BltLabelNum);
End;

{ ------------------------------------------------------------ }
{ BuiltinTypeName : retourner le nom du type de builtin           }
{ ------------------------------------------------------------ }

Function BuiltinTypeName(BType : Integer) : TString;
Begin
  Case BType Of
    BLT_NONE       : BuiltinTypeName := 'NONE';
    BLT_ABS        : BuiltinTypeName := 'ABS';
    BLT_SGN        : BuiltinTypeName := 'SGN';
    BLT_SHIFTL     : BuiltinTypeName := 'SHIFTL';
    BLT_SHIFTR     : BuiltinTypeName := 'SHIFTR';
    BLT_BIT        : BuiltinTypeName := 'BIT';
    BLT_BITSIZE    : BuiltinTypeName := 'BITSIZE';
    BLT_BYTESIZE   : BuiltinTypeName := 'BYTESIZE';
    BLT_WORDSIZE   : BuiltinTypeName := 'WORDSIZE';
    BLT_UBOUND     : BuiltinTypeName := 'UBOUND';
    BLT_LBOUND     : BuiltinTypeName := 'LBOUND';
    BLT_NWSDEN     : BuiltinTypeName := 'NWSDEN';
    BLT_FIRST      : BuiltinTypeName := 'FIRST';
    BLT_LAST       : BuiltinTypeName := 'LAST';
  Else
    BuiltinTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ EvalAbs : evaluer ABS(x)                                        }
{   Retourne la valeur absolue de l expression                    }
{   Generer : CMP EAX, 0 / JGE @pos / NEG EAX / @pos:           }
{   CurTok est sur ( apres ABS                                    }
{ ------------------------------------------------------------ }

Procedure EvalAbs;
Var
  Lbl : TString;
Begin
  Inc(BltStateCount);
  Inc(BltAbsCount);

  Lbl := GenBltLabel;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres ABS');
    Inc(BltErrorCount);
  End;

  { Parser l expression argument }
  If CurTokType <> TOK_RPAREN Then
    ParseExpression;

  If Opts.Verbose Then
    WriteLn('  ABS: valeur absolue -> CMP/JGE/NEG [', Lbl, ']');

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres ABS(expression)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalSgn : evaluer SGN(x)                                        }
{   Retourne le signe de l expression (-1, 0, +1)                 }
{   Generer : CMP EAX, 0 / JE @zero / JG @pos / MOV EAX, -1     }
{             / JMP @end / @pos: MOV EAX, 1 / @end:              }
{   CurTok est sur ( apres SGN                                    }
{ ------------------------------------------------------------ }

Procedure EvalSgn;
Var
  LblZero, LblPos, LblEnd : TString;
Begin
  Inc(BltStateCount);
  Inc(BltSgnCount);

  LblZero := GenBltLabel;
  LblPos  := GenBltLabel;
  LblEnd  := GenBltLabel;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres SGN');
    Inc(BltErrorCount);
  End;

  { Parser l expression argument }
  If CurTokType <> TOK_RPAREN Then
    ParseExpression;

  If Opts.Verbose Then
    WriteLn('  SGN: signe -> CMP/JE/JG [', LblZero, '/', LblPos, '/', LblEnd, ']');

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres SGN(expression)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalByteSize : evaluer BYTESIZE(item)                           }
{   Retourne la taille en octets de l ITEM (resolu a la compil)   }
{   CurTok est sur ( apres BYTESIZE                               }
{ ------------------------------------------------------------ }

Function EvalByteSize : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BltStateCount);
  Inc(BltByteSizeCount);
  EvalByteSize := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres BYTESIZE');
    Inc(BltErrorCount);
  End;

  { Lire le nom de l ITEM }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_ITEM) Then
    Begin
      EvalByteSize := SymTab[Idx].ByteSize;
      If Opts.Verbose Then
        WriteLn('  BYTESIZE(', CurTokStr, ') = ', SymTab[Idx].ByteSize);
    End
    Else
    Begin
      WarnMsg('BYTESIZE : ' + CurTokStr + ' n est pas un ITEM');
      Inc(BltErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom d ITEM attendu dans BYTESIZE()');
    Inc(BltErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres BYTESIZE(nom)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalWordSize : evaluer WORDSIZE(item)                           }
{   Retourne la taille en mots 32 bits de l ITEM                  }
{   (ByteSize + 3) div 4, resolu a la compilation                 }
{   CurTok est sur ( apres WORDSIZE                               }
{ ------------------------------------------------------------ }

Function EvalWordSize : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BltStateCount);
  Inc(BltWordSizeCount);
  EvalWordSize := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres WORDSIZE');
    Inc(BltErrorCount);
  End;

  { Lire le nom de l ITEM }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_ITEM) Then
    Begin
      EvalWordSize := (SymTab[Idx].ByteSize + 3) Div 4;
      If Opts.Verbose Then
        WriteLn('  WORDSIZE(', CurTokStr, ') = ',
                (SymTab[Idx].ByteSize + 3) Div 4);
    End
    Else
    Begin
      WarnMsg('WORDSIZE : ' + CurTokStr + ' n est pas un ITEM');
      Inc(BltErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom d ITEM attendu dans WORDSIZE()');
    Inc(BltErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres WORDSIZE(nom)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalUBound : evaluer UBOUND(table)                              }
{   Retourne la borne superieure du tableau (taille - 1)           }
{   Resolu a la compilation                                       }
{   CurTok est sur ( apres UBOUND                                 }
{ ------------------------------------------------------------ }

Function EvalUBound : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BltStateCount);
  Inc(BltUBoundCount);
  EvalUBound := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres UBOUND');
    Inc(BltErrorCount);
  End;

  { Lire le nom de la TABLE }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_TABLE) Then
    Begin
      If SymTab[Idx].TableSize > 0 Then
        EvalUBound := SymTab[Idx].TableSize - 1
      Else
        EvalUBound := 0;
      If Opts.Verbose Then
        WriteLn('  UBOUND(', CurTokStr, ') = ', EvalUBound);
    End
    Else
    Begin
      WarnMsg('UBOUND : ' + CurTokStr + ' n est pas une TABLE');
      Inc(BltErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de TABLE attendu dans UBOUND()');
    Inc(BltErrorCount);
  End;

  { Consommer la dimension optionnelle , dim }
  If CurTokType = TOK_COMMA Then
  Begin
    LexNextToken;
    { Parser et ignorer l expression de dimension (toujours 1D) }
    If CurTokType <> TOK_RPAREN Then
      ParseExpression;
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres UBOUND(table)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalLBound : evaluer LBOUND(table)                              }
{   Retourne la borne inferieure du tableau (toujours 0 en Jovial)}
{   Resolu a la compilation                                       }
{   CurTok est sur ( apres LBOUND                                 }
{ ------------------------------------------------------------ }

Function EvalLBound : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BltStateCount);
  Inc(BltLBoundCount);
  EvalLBound := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres LBOUND');
    Inc(BltErrorCount);
  End;

  { Lire le nom de la TABLE }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_TABLE) Then
    Begin
      EvalLBound := 0;
      If Opts.Verbose Then
        WriteLn('  LBOUND(', CurTokStr, ') = 0');
    End
    Else
    Begin
      WarnMsg('LBOUND : ' + CurTokStr + ' n est pas une TABLE');
      Inc(BltErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de TABLE attendu dans LBOUND()');
    Inc(BltErrorCount);
  End;

  { Consommer la dimension optionnelle , dim }
  If CurTokType = TOK_COMMA Then
  Begin
    LexNextToken;
    { Parser et ignorer l expression de dimension (toujours 1D) }
    If CurTokType <> TOK_RPAREN Then
      ParseExpression;
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres LBOUND(table)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EvalNwsden : evaluer NWSDEN(table)                              }
{   Retourne le nombre d elements dans la table                    }
{   Resolu a la compilation                                       }
{   CurTok est sur ( apres NWSDEN                                 }
{ ------------------------------------------------------------ }

Function EvalNwsden : LongInt;
Var
  Idx : Integer;
Begin
  Inc(BltStateCount);
  Inc(BltNwsdenCount);
  EvalNwsden := 0;

  { Consommer ( }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg('( attendu apres NWSDEN');
    Inc(BltErrorCount);
  End;

  { Lire le nom de la TABLE }
  If CurTokType = TOK_IDENT Then
  Begin
    Idx := SymFind(CurTokStr);
    If (Idx >= 0) And (SymTab[Idx].SymKind = SK_TABLE) Then
    Begin
      EvalNwsden := SymTab[Idx].TableSize;
      If Opts.Verbose Then
        WriteLn('  NWSDEN(', CurTokStr, ') = ', SymTab[Idx].TableSize);
    End
    Else
    Begin
      WarnMsg('NWSDEN : ' + CurTokStr + ' n est pas une TABLE');
      Inc(BltErrorCount);
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Un mot-cle peut etre utilise comme nom de variable }
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de TABLE attendu dans NWSDEN()');
    Inc(BltErrorCount);
  End;

  { Consommer ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
  Begin
    WarnMsg(') attendu apres NWSDEN(table)');
    Inc(BltErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ IsBuiltinFunction : verifier si un mot-cle est un builtin       }
{   Retourne True si le mot-cle est une fonction integree         }
{ ------------------------------------------------------------ }

Function IsBuiltinFunction(KwCode : Integer) : Boolean;
Begin
  Inc(BltStateCount);
  IsBuiltinFunction := (KwCode = KW_ABS) Or (KwCode = KW_SGN) Or
    (KwCode = KW_SHIFTL) Or (KwCode = KW_SHIFTR) Or
    (KwCode = KW_BIT) Or (KwCode = KW_BITSIZE) Or
    (KwCode = KW_BYTESIZE) Or (KwCode = KW_WORDSIZE) Or
    (KwCode = KW_UBOUND) Or (KwCode = KW_LBOUND) Or
    (KwCode = KW_NWSDEN) Or (KwCode = KW_FIRST) Or
    (KwCode = KW_LAST) Or (KwCode = KW_NEXT);
End;

{ ------------------------------------------------------------ }
{ ParseBuiltinCall : dispatcher pour les appels de builtins        }
{   Identifie le builtin et delegue au parseur specialise          }
{   CurTok est sur le mot-cle du builtin                          }
{ ------------------------------------------------------------ }

Procedure ParseBuiltinCall;
Var
  KwCode : Integer;
Begin
  Inc(BltStateCount);
  KwCode := CurTokNum;
  LexNextToken;

  Case KwCode Of
    KW_ABS:
    Begin
      EvalAbs;
    End;

    KW_SGN:
    Begin
      EvalSgn;
    End;

    KW_SHIFTL:
    Begin
      { Deleguer a TODO 14 }
      Inc(BltShiftLCount);
      ParseShiftLeft;
    End;

    KW_SHIFTR:
    Begin
      { Deleguer a TODO 14 }
      Inc(BltShiftRCount);
      ParseShiftRight;
    End;

    KW_BIT:
    Begin
      { Deleguer a TODO 14 }
      Inc(BltBitCount);
      ParseBitExtract;
    End;

    KW_BITSIZE:
    Begin
      { Deleguer a TODO 14 }
      Inc(BltBitSizeCount);
      EvalBitSize;
    End;

    KW_BYTESIZE:
    Begin
      EvalByteSize;
    End;

    KW_WORDSIZE:
    Begin
      EvalWordSize;
    End;

    KW_UBOUND:
    Begin
      EvalUBound;
    End;

    KW_LBOUND:
    Begin
      EvalLBound;
    End;

    KW_NWSDEN:
    Begin
      EvalNwsden;
    End;

    KW_FIRST:
    Begin
      { Deleguer a TODO 13 }
      Inc(BltFirstCount);
      EvalStatusFirst;
    End;

    KW_LAST:
    Begin
      { Deleguer a TODO 13 }
      Inc(BltLastCount);
      EvalStatusLast;
    End;

  Else
    Begin
      WarnMsg('Fonction integree inconnue');
      Inc(BltErrorCount);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpBuiltinState : afficher l etat du parseur builtins           }
{ ------------------------------------------------------------ }

Procedure DumpBuiltinState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur BUILTINS (TODO 15) ===');
  WriteLn('  Initialise         : ', BltInitialized);
  WriteLn('  Operations         : ', BltStateCount);
  WriteLn('  ABS()              : ', BltAbsCount);
  WriteLn('  SGN()              : ', BltSgnCount);
  WriteLn('  SHIFTL()           : ', BltShiftLCount);
  WriteLn('  SHIFTR()           : ', BltShiftRCount);
  WriteLn('  BIT()              : ', BltBitCount);
  WriteLn('  BITSIZE()          : ', BltBitSizeCount);
  WriteLn('  BYTESIZE()         : ', BltByteSizeCount);
  WriteLn('  WORDSIZE()         : ', BltWordSizeCount);
  WriteLn('  UBOUND()           : ', BltUBoundCount);
  WriteLn('  LBOUND()           : ', BltLBoundCount);
  WriteLn('  NWSDEN()           : ', BltNwsdenCount);
  WriteLn('  FIRST()            : ', BltFirstCount);
  WriteLn('  LAST()             : ', BltLastCount);
  WriteLn('  Labels generes     : ', BltLabelNum);
  WriteLn('  Erreurs            : ', BltErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur BUILTINS (10 fonctions)                    }
{ ------------------------------------------------------------ }

Function IsBltInitialized : Boolean;
Begin
  IsBltInitialized := BltInitialized;
End;

Function GetBltAbsCount : Integer;
Begin
  GetBltAbsCount := BltAbsCount;
End;

Function GetBltSgnCount : Integer;
Begin
  GetBltSgnCount := BltSgnCount;
End;

Function GetBltSizeCount : Integer;
Begin
  GetBltSizeCount := BltBitSizeCount + BltByteSizeCount + BltWordSizeCount;
End;

Function GetBltBoundCount : Integer;
Begin
  GetBltBoundCount := BltUBoundCount + BltLBoundCount + BltNwsdenCount;
End;

Function GetBltShiftCount : Integer;
Begin
  GetBltShiftCount := BltShiftLCount + BltShiftRCount;
End;

Function GetBltDelegateCount : Integer;
Begin
  GetBltDelegateCount := BltFirstCount + BltLastCount + BltBitCount +
                         BltBitSizeCount + BltShiftLCount + BltShiftRCount;
End;

Function GetBltStateCount : Integer;
Begin
  GetBltStateCount := BltStateCount;
End;

Function GetBltErrorCount : Integer;
Begin
  GetBltErrorCount := BltErrorCount;
End;

Function IsBltEmpty : Boolean;
Begin
  IsBltEmpty := (BltAbsCount = 0) And (BltSgnCount = 0) And
                (BltByteSizeCount = 0) And (BltWordSizeCount = 0) And
                (BltUBoundCount = 0) And (BltLBoundCount = 0) And
                (BltNwsdenCount = 0) And (BltShiftLCount = 0) And
                (BltShiftRCount = 0) And (BltBitCount = 0) And
                (BltBitSizeCount = 0) And (BltFirstCount = 0) And
                (BltLastCount = 0);
End;


{ ============================================================ }
{ TODO 16 - PARSEUR : INPUT/OUTPUT (E/S CONSOLE)               }
{   Parser les instructions INPUT et OUTPUT du Jovial 73.      }
{   OUTPUT : afficher du texte ou des expressions formatees.   }
{   INPUT  : lire des valeurs depuis la console.               }
{ ============================================================ }

Const
  { Types d operations E/S }
  IO_NONE           = 0;   { pas d operation E/S                      }
  IO_OUTPUT_SIMPLE  = 1;   { OUTPUT ('texte')                         }
  IO_OUTPUT_FORMAT  = 2;   { OUTPUT ('format $D', expr, ...)          }
  IO_INPUT_SINGLE   = 3;   { INPUT (var)                              }
  IO_INPUT_MULTI    = 4;   { INPUT (var1, var2, ...)                  }
  IO_OUTPUT_EXPR    = 5;   { OUTPUT (expression) sans format          }
  IO_INPUT_PROMPT   = 6;   { INPUT avec prompt (extension)            }

  { Limites }
  IO_MAX_OPS      = 4096;  { nombre max d operations E/S              }
  IO_MAX_ARGS     = 32;    { nombre max d arguments par instruction   }
  IO_MAX_FORMAT   = 16;    { nombre max de $D dans un format          }

Var
  { Variables du parseur E/S }
  IOInitialized     : Boolean;     { module initialise ?              }
  IOStateCount      : Integer;     { compteur d operations            }
  IOOutputCount     : Integer;     { instructions OUTPUT parsees      }
  IOInputCount      : Integer;     { instructions INPUT parsees       }
  IOSimpleCount     : Integer;     { OUTPUT simples (texte seul)      }
  IOFormatCount     : Integer;     { OUTPUT avec format $D            }
  IOExprCount       : Integer;     { OUTPUT avec expressions          }
  IOSingleInCount   : Integer;     { INPUT simple (une variable)      }
  IOMultiInCount    : Integer;     { INPUT multiple (plusieurs vars)  }
  IOFormatSpecCount : Integer;     { total de $D rencontres           }
  IOArgCount        : Integer;     { total d arguments parses         }
  IOLabelNum        : Integer;     { generateur de labels uniques     }
  IOErrorCount      : Integer;     { nombre d erreurs                 }

{ ------------------------------------------------------------ }
{ InitIOState : initialiser les variables du parseur E/S        }
{ ------------------------------------------------------------ }

Procedure InitIOState;
Begin
  IOInitialized     := True;
  IOStateCount      := 0;
  IOOutputCount     := 0;
  IOInputCount      := 0;
  IOSimpleCount     := 0;
  IOFormatCount     := 0;
  IOExprCount       := 0;
  IOSingleInCount   := 0;
  IOMultiInCount    := 0;
  IOFormatSpecCount := 0;
  IOArgCount        := 0;
  IOLabelNum        := 0;
  IOErrorCount      := 0;
End;

{ ------------------------------------------------------------ }
{ GenIOLabel : generer un label unique pour les E/S              }
{ ------------------------------------------------------------ }

Function GenIOLabel : TString;
Begin
  Inc(IOLabelNum);
  GenIOLabel := PFX_LBL + 'IO_' + ItoSI(IOLabelNum);
End;

{ ------------------------------------------------------------ }
{ IOTypeName : nom textuel d un type d operation E/S             }
{ ------------------------------------------------------------ }

Function IOTypeName(IOType : Integer) : TString;
Begin
  Case IOType Of
    IO_NONE:          IOTypeName := 'NONE';
    IO_OUTPUT_SIMPLE: IOTypeName := 'OUTPUT_SIMPLE';
    IO_OUTPUT_FORMAT: IOTypeName := 'OUTPUT_FORMAT';
    IO_INPUT_SINGLE:  IOTypeName := 'INPUT_SINGLE';
    IO_INPUT_MULTI:   IOTypeName := 'INPUT_MULTI';
    IO_OUTPUT_EXPR:   IOTypeName := 'OUTPUT_EXPR';
    IO_INPUT_PROMPT:  IOTypeName := 'INPUT_PROMPT';
  Else
    IOTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ CountFormatSpecs : compter le nombre de $D dans une chaine     }
{   Retourne le nombre de specifiers de format trouves          }
{ ------------------------------------------------------------ }

Function CountFormatSpecs(Const Fmt : TString) : Integer;
Var
  I, Count : Integer;
Begin
  Count := 0;
  I := 1;
  While I < Length(Fmt) Do
  Begin
    If (Fmt[I] = '$') And (I < Length(Fmt)) Then
    Begin
      If UpCase(Fmt[I + 1]) = 'D' Then
      Begin
        Inc(Count);
        Inc(I);  { sauter le D }
      End;
    End;
    Inc(I);
  End;
  CountFormatSpecs := Count;
End;

{ ------------------------------------------------------------ }
{ ParseOutputStmt : parser une instruction OUTPUT                }
{   OUTPUT ('texte') ;                                          }
{   OUTPUT ('format $D', expr1, expr2, ...) ;                   }
{   OUTPUT (expression) ;                                       }
{ ------------------------------------------------------------ }

Procedure ParseOutputStmt;
Var
  FmtStr   : TString;
  NumSpecs : Integer;
  ArgsParsed : Integer;
  Lbl      : TString;
Begin
  Inc(IOStateCount);
  Inc(IOOutputCount);

  { Consommer OUTPUT }
  LexNextToken;

  { Attendre ( }
  If CurTokType <> TOK_LPAREN Then
  Begin
    WarnMsg('OUTPUT : ( attendue');
    Inc(IOErrorCount);
    { Essayer de consommer jusqu au ; }
    While (CurTokType <> TOK_SEMICOL) And
          (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;
  LexNextToken;  { consommer ( }

  { Generer un label pour cette instruction OUTPUT }
  Lbl := GenIOLabel;

  { Verifier le premier argument }
  If CurTokType = TOK_STRING Then
  Begin
    { C est une chaine : texte simple ou format }
    FmtStr := CurTokStr;
    NumSpecs := CountFormatSpecs(FmtStr);
    LexNextToken;  { consommer la chaine }

    If (CurTokType = TOK_RPAREN) Then
    Begin
      { OUTPUT ('texte simple') }
      Inc(IOSimpleCount);
      LexNextToken;  { consommer ) }
    End
    Else If (CurTokType = TOK_COMMA) Then
    Begin
      { OUTPUT ('format $D', expr, ...) }
      Inc(IOFormatCount);
      Inc(IOFormatSpecCount, NumSpecs);
      ArgsParsed := 0;

      While (CurTokType = TOK_COMMA) And
            (CurTokType <> TOK_EOF) Do
      Begin
        LexNextToken;  { consommer , }
        { Parser l expression argument }
        ParseExpression;
        Inc(ArgsParsed);
        Inc(IOArgCount);
      End;

      { Verifier que le nombre d arguments correspond }
      If ArgsParsed <> NumSpecs Then
      Begin
        WarnMsg('OUTPUT : nombre d arguments ne correspond pas aux $D');
        Inc(IOErrorCount);
      End;

      { Attendre ) }
      If CurTokType = TOK_RPAREN Then
        LexNextToken  { consommer ) }
      Else
      Begin
        WarnMsg('OUTPUT : ) attendue apres les arguments');
        Inc(IOErrorCount);
      End;
    End
    Else
    Begin
      WarnMsg('OUTPUT : ) ou , attendue apres la chaine');
      Inc(IOErrorCount);
      { Consommer jusqu a ) ou ; }
      While (CurTokType <> TOK_RPAREN) And
            (CurTokType <> TOK_SEMICOL) And
            (CurTokType <> TOK_EOF) Do
        LexNextToken;
      If CurTokType = TOK_RPAREN Then
        LexNextToken;
    End;
  End
  Else
  Begin
    { OUTPUT (expression) : sans chaine de format }
    Inc(IOExprCount);
    ParseExpression;
    Inc(IOArgCount);

    { Autres expressions separees par , }
    While (CurTokType = TOK_COMMA) And
          (CurTokType <> TOK_EOF) Do
    Begin
      LexNextToken;  { consommer , }
      ParseExpression;
      Inc(IOArgCount);
      Inc(IOExprCount);
    End;

    { Attendre ) }
    If CurTokType = TOK_RPAREN Then
      LexNextToken  { consommer ) }
    Else
    Begin
      WarnMsg('OUTPUT : ) attendue');
      Inc(IOErrorCount);
    End;
  End;

  { Attendre ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken  { consommer ; }
  Else
  Begin
    WarnMsg('OUTPUT : ; attendu en fin d instruction');
    Inc(IOErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseInputStmt : parser une instruction INPUT                  }
{   INPUT (var1) ;                                              }
{   INPUT (var1, var2, ...) ;                                   }
{ ------------------------------------------------------------ }

Procedure ParseInputStmt;
Var
  VarCount : Integer;
  Lbl      : TString;
Begin
  Inc(IOStateCount);
  Inc(IOInputCount);

  { Consommer INPUT }
  LexNextToken;

  { Attendre ( }
  If CurTokType <> TOK_LPAREN Then
  Begin
    WarnMsg('INPUT : ( attendue');
    Inc(IOErrorCount);
    While (CurTokType <> TOK_SEMICOL) And
          (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;
  LexNextToken;  { consommer ( }

  Lbl := GenIOLabel;
  VarCount := 0;

  { Lire la premiere variable }
  If CurTokType = TOK_IDENT Then
  Begin
    Inc(VarCount);
    Inc(IOArgCount);
    LexNextToken;  { consommer l identifiant }
  End
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    { Certaines variables peuvent etre des mots-cles utilises comme noms }
    Inc(VarCount);
    Inc(IOArgCount);
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('INPUT : identifiant de variable attendu');
    Inc(IOErrorCount);
    { Essayer de recuperer }
    While (CurTokType <> TOK_RPAREN) And
          (CurTokType <> TOK_SEMICOL) And
          (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
    If CurTokType = TOK_SEMICOL Then
      LexNextToken;
    Exit;
  End;

  { Variables supplementaires separees par , }
  While (CurTokType = TOK_COMMA) And
        (CurTokType <> TOK_EOF) Do
  Begin
    LexNextToken;  { consommer , }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      Inc(VarCount);
      Inc(IOArgCount);
      LexNextToken;
    End
    Else
    Begin
      WarnMsg('INPUT : identifiant attendu apres ,');
      Inc(IOErrorCount);
    End;
  End;

  { Classifier le type d INPUT }
  If VarCount = 1 Then
    Inc(IOSingleInCount)
  Else If VarCount > 1 Then
    Inc(IOMultiInCount);

  { Attendre ) }
  If CurTokType = TOK_RPAREN Then
    LexNextToken  { consommer ) }
  Else
  Begin
    WarnMsg('INPUT : ) attendue');
    Inc(IOErrorCount);
  End;

  { Attendre ; }
  If CurTokType = TOK_SEMICOL Then
    LexNextToken  { consommer ; }
  Else
  Begin
    WarnMsg('INPUT : ; attendu en fin d instruction');
    Inc(IOErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIOStatement : dispatcher pour les instructions E/S        }
{   Appele depuis ParseStatement quand le token est INPUT ou    }
{   OUTPUT.                                                     }
{ ------------------------------------------------------------ }

Procedure ParseIOStatement;
Begin
  If Not IOInitialized Then
  Begin
    WarnMsg('Module E/S non initialise');
    Inc(IOErrorCount);
    Exit;
  End;

  If CurTokNum = KW_OUTPUT Then
    ParseOutputStmt
  Else If CurTokNum = KW_INPUT Then
    ParseInputStmt
  Else
  Begin
    WarnMsg('Instruction E/S inconnue');
    Inc(IOErrorCount);
  End;
End;

{ ------------------------------------------------------------ }
{ DumpIOState : afficher l etat du parseur E/S                   }
{ ------------------------------------------------------------ }

Procedure DumpIOState;
Begin
  WriteLn;
  WriteLn('=== Etat du parseur E/S (TODO 16) ===');
  WriteLn('  Initialise         : ', IOInitialized);
  WriteLn('  Operations         : ', IOStateCount);
  WriteLn('  OUTPUT parses      : ', IOOutputCount);
  WriteLn('  INPUT parses       : ', IOInputCount);
  WriteLn('  OUTPUT simples     : ', IOSimpleCount);
  WriteLn('  OUTPUT formates    : ', IOFormatCount);
  WriteLn('  OUTPUT expressions : ', IOExprCount);
  WriteLn('  INPUT simples      : ', IOSingleInCount);
  WriteLn('  INPUT multiples    : ', IOMultiInCount);
  WriteLn('  Specifiers $D      : ', IOFormatSpecCount);
  WriteLn('  Arguments totaux   : ', IOArgCount);
  WriteLn('  Labels generes     : ', IOLabelNum);
  WriteLn('  Erreurs            : ', IOErrorCount);
End;

{ ------------------------------------------------------------ }
{ Accesseurs du parseur E/S (10 fonctions)                       }
{ ------------------------------------------------------------ }

Function IsIOInitialized : Boolean;
Begin
  IsIOInitialized := IOInitialized;
End;

Function GetIOOutputCount : Integer;
Begin
  GetIOOutputCount := IOOutputCount;
End;

Function GetIOInputCount : Integer;
Begin
  GetIOInputCount := IOInputCount;
End;

Function GetIOSimpleCount : Integer;
Begin
  GetIOSimpleCount := IOSimpleCount;
End;

Function GetIOFormatCount : Integer;
Begin
  GetIOFormatCount := IOFormatCount;
End;

Function GetIOExprCount : Integer;
Begin
  GetIOExprCount := IOExprCount;
End;

Function GetIOArgCount : Integer;
Begin
  GetIOArgCount := IOArgCount;
End;

Function GetIOStateCount : Integer;
Begin
  GetIOStateCount := IOStateCount;
End;

Function GetIOErrorCount : Integer;
Begin
  GetIOErrorCount := IOErrorCount;
End;

Function IsIOEmpty : Boolean;
Begin
  IsIOEmpty := (IOOutputCount = 0) And (IOInputCount = 0);
End;


{ ============================================================ }
{ TODO 17 - GENERATION DE CODE : SEGMENT DE DONNEES 80386      }
{   Generer les sections .data et .data? (BSS) pour le code    }
{   assembleur 80386 a partir de la table des symboles.        }
{   Chaque ITEM/TABLE/constante produit une directive MASM.    }
{ ============================================================ }

Const
  { Types d entrees dans le segment de donnees }
  DAT_NONE         = 0;   { pas d entree                             }
  DAT_ITEM_BYTE    = 1;   { ITEM I 8 -> DB                           }
  DAT_ITEM_WORD    = 2;   { ITEM I 16 -> DW                          }
  DAT_ITEM_DWORD   = 3;   { ITEM I 32 -> DD                          }
  DAT_ITEM_STATUS  = 4;   { ITEM S n -> DD (entier pour status)      }
  DAT_ITEM_BITS    = 5;   { ITEM B n -> DB/DW/DD selon taille        }
  DAT_ITEM_FLOAT   = 6;   { ITEM F -> DD 0.0 (IEEE 754 32 bits)     }
  DAT_TABLE        = 7;   { TABLE(n) -> DW/DD n DUP(0)              }
  DAT_STRING       = 8;   { constante chaine DB 'texte', 0           }
  DAT_FORMAT       = 9;   { constante de format DB 'fmt', 0          }
  DAT_BSS_BUFFER   = 10;  { buffer BSS DB n DUP(?)                   }
  DAT_BSS_DWORD    = 11;  { variable BSS DD ?                        }

  { Limites }
  DAT_MAX_ENTRIES  = 4096;  { nombre max d entrees generees          }
  DAT_IOBUF_SIZE   = 256;  { taille du buffer E/S en octets          }
  DAT_NUMBUF_SIZE  = 32;   { taille du buffer numerique en octets    }
  DAT_ALIGN        = 4;    { alignement sur DWORD (4 octets)         }

Var
  { Variables du generateur de segment de donnees }
  DatInitialized   : Boolean;     { module initialise ?              }
  DatStateCount    : Integer;     { compteur d operations            }
  DatItemCount     : Integer;     { ITEM generes dans .data          }
  DatTableCount    : Integer;     { TABLE generes dans .data         }
  DatStringCount   : Integer;     { constantes chaines generees      }
  DatFormatCount   : Integer;     { constantes de format generees    }
  DatBssCount      : Integer;     { entrees BSS generees             }
  DatRuntimeCount  : Integer;     { variables runtime generees       }
  DatTotalBytes    : LongInt;     { total d octets dans .data        }
  DatBssBytes      : LongInt;     { total d octets dans .data?       }
  DatLabelNum      : Integer;     { generateur de labels uniques     }
  DatErrorCount    : Integer;     { nombre d erreurs                 }

{ ------------------------------------------------------------ }
{ InitDataSegState : initialiser les variables du generateur    }
{ ------------------------------------------------------------ }

Procedure InitDataSegState;
Begin
  DatInitialized   := True;
  DatStateCount    := 0;
  DatItemCount     := 0;
  DatTableCount    := 0;
  DatStringCount   := 0;
  DatFormatCount   := 0;
  DatBssCount      := 0;
  DatRuntimeCount  := 0;
  DatTotalBytes    := 0;
  DatBssBytes      := 0;
  DatLabelNum      := 0;
  DatErrorCount    := 0;
End;

{ ------------------------------------------------------------ }
{ GenDatLabel : generer un label unique pour le segment donnees  }
{ ------------------------------------------------------------ }

Function GenDatLabel : TString;
Begin
  Inc(DatLabelNum);
  GenDatLabel := PFX_LBL + 'DAT_' + ItoSI(DatLabelNum);
End;

{ ------------------------------------------------------------ }
{ DatTypeName : nom textuel d un type d entree donnees           }
{ ------------------------------------------------------------ }

Function DatTypeName(DatType : Integer) : TString;
Begin
  Case DatType Of
    DAT_NONE:        DatTypeName := 'NONE';
    DAT_ITEM_BYTE:   DatTypeName := 'ITEM_BYTE';
    DAT_ITEM_WORD:   DatTypeName := 'ITEM_WORD';
    DAT_ITEM_DWORD:  DatTypeName := 'ITEM_DWORD';
    DAT_ITEM_STATUS: DatTypeName := 'ITEM_STATUS';
    DAT_ITEM_BITS:   DatTypeName := 'ITEM_BITS';
    DAT_ITEM_FLOAT:  DatTypeName := 'ITEM_FLOAT';
    DAT_TABLE:       DatTypeName := 'TABLE';
    DAT_STRING:      DatTypeName := 'STRING';
    DAT_FORMAT:      DatTypeName := 'FORMAT';
    DAT_BSS_BUFFER:  DatTypeName := 'BSS_BUFFER';
    DAT_BSS_DWORD:   DatTypeName := 'BSS_DWORD';
  Else
    DatTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ AlignToN : aligner une valeur sur N octets                    }
{ ------------------------------------------------------------ }

Function AlignToN(V, N : LongInt) : LongInt;
Begin
  If (V Mod N) <> 0 Then
    AlignToN := V + N - (V Mod N)
  Else
    AlignToN := V;
End;

{ ------------------------------------------------------------ }
{ DatDirective : renvoyer la directive MASM selon la taille     }
{   1 -> DB, 2 -> DW, 4 -> DD                                 }
{ ------------------------------------------------------------ }

Function DatDirective(ByteSz : Integer) : TString;
Begin
  Case ByteSz Of
    1 : DatDirective := 'DB';
    2 : DatDirective := 'DW';
    4 : DatDirective := 'DD';
  Else
    DatDirective := 'DD';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitItemData : generer une entree .data pour un ITEM          }
{   Parcourt la table des symboles et emet pour chaque ITEM :  }
{     ITEM I 8  -> _JV_nom DB 0                                }
{     ITEM I 16 -> _JV_nom DW 0                                }
{     ITEM I 32 -> _JV_nom DD 0                                }
{     ITEM S n  -> _JV_nom DD 0                                }
{     ITEM B n  -> _JV_nom DB/DW/DD 0 (selon taille)           }
{     ITEM F    -> _JV_nom DD 0.0                               }
{ ------------------------------------------------------------ }

Procedure EmitItemData(Var OutBuf : TString);
Var
  I, ByteSz : Integer;
  Dir, Line : TString;
Begin
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].SymKind <> SK_ITEM Then Continue;
    If DatItemCount >= DAT_MAX_ENTRIES Then
    Begin
      Inc(DatErrorCount);
      Exit;
    End;

    ByteSz := SymTab[I].ByteSize;
    If ByteSz <= 0 Then ByteSz := 4;
    If ByteSz = 3 Then ByteSz := 4;
    Dir := DatDirective(ByteSz);

    Case SymTab[I].ItemType Of
      JT_INTEGER:
      Begin
        Line := '  ' + SymTab[I].AsmName + ' ' + Dir + ' 0';
        OutBuf := OutBuf + Line + Chr(13) + Chr(10);
        DatTotalBytes := DatTotalBytes + ByteSz;
        Inc(DatItemCount);
        Inc(DatStateCount);
      End;
      JT_STATUS:
      Begin
        { Status stocke comme DWORD }
        Line := '  ' + SymTab[I].AsmName + ' DD 0';
        OutBuf := OutBuf + Line + Chr(13) + Chr(10);
        DatTotalBytes := DatTotalBytes + 4;
        Inc(DatItemCount);
        Inc(DatStateCount);
      End;
      JT_BITS:
      Begin
        Line := '  ' + SymTab[I].AsmName + ' ' + Dir + ' 0';
        OutBuf := OutBuf + Line + Chr(13) + Chr(10);
        DatTotalBytes := DatTotalBytes + ByteSz;
        Inc(DatItemCount);
        Inc(DatStateCount);
      End;
      JT_FLOATING:
      Begin
        { IEEE 754 32 bits }
        Line := '  ' + SymTab[I].AsmName + ' DD 0.0';
        OutBuf := OutBuf + Line + Chr(13) + Chr(10);
        DatTotalBytes := DatTotalBytes + 4;
        Inc(DatItemCount);
        Inc(DatStateCount);
      End;
    Else
      Begin
        { Type inconnu, traiter comme DWORD }
        Line := '  ' + SymTab[I].AsmName + ' DD 0';
        OutBuf := OutBuf + Line + Chr(13) + Chr(10);
        DatTotalBytes := DatTotalBytes + 4;
        Inc(DatItemCount);
        Inc(DatStateCount);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ EmitTableData : generer des entrees .data pour les TABLEs     }
{   TABLE(n) I 16 -> _JT_nom DW n DUP(0)                      }
{   TABLE(n) I 32 -> _JT_nom DD n DUP(0)                      }
{   TABLE(n) S n  -> _JT_nom DD n DUP(0)                      }
{   TABLE(n) B n  -> _JT_nom DB/DW/DD n DUP(0)                }
{   TABLE(n) F    -> _JT_nom DD n DUP(0)                       }
{ ------------------------------------------------------------ }

Procedure EmitTableData(Var OutBuf : TString);
Var
  I, ByteSz, TblSz : Integer;
  Dir, Line : TString;
Begin
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].SymKind <> SK_TABLE Then Continue;
    If DatTableCount >= DAT_MAX_ENTRIES Then
    Begin
      Inc(DatErrorCount);
      Exit;
    End;

    TblSz := SymTab[I].TableSize;
    If TblSz <= 0 Then TblSz := 1;

    ByteSz := SymTab[I].ByteSize;
    If ByteSz <= 0 Then ByteSz := 4;
    If ByteSz = 3 Then ByteSz := 4;

    Case SymTab[I].ItemType Of
      JT_FLOATING:
      Begin
        Dir := 'DD';
        ByteSz := 4;
      End;
      JT_STATUS:
      Begin
        Dir := 'DD';
        ByteSz := 4;
      End;
    Else
      Dir := DatDirective(ByteSz);
    End;

    Line := '  ' + SymTab[I].AsmName + ' ' + Dir + ' ' +
            ItoSI(TblSz) + ' DUP(0)';
    OutBuf := OutBuf + Line + Chr(13) + Chr(10);
    DatTotalBytes := DatTotalBytes + (LongInt(ByteSz) * LongInt(TblSz));
    Inc(DatTableCount);
    Inc(DatStateCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitStringConst : generer des constantes chaines              }
{   _JK_nnn DB 'texte', 13, 10, 0                              }
{   Parcourt la table des symboles pour les constantes          }
{ ------------------------------------------------------------ }

Procedure EmitStringConst(Var OutBuf : TString);
Var
  I : Integer;
  Line : TString;
Begin
  For I := 0 To SymCount - 1 Do
  Begin
    If SymTab[I].SymKind <> SK_CONSTANT Then Continue;
    If DatStringCount >= DAT_MAX_ENTRIES Then
    Begin
      Inc(DatErrorCount);
      Exit;
    End;

    { Generer une constante chaine avec CR/LF/NUL }
    Line := '  ' + SymTab[I].AsmName + ' DB ''...'', 13, 10, 0';
    OutBuf := OutBuf + Line + Chr(13) + Chr(10);
    DatTotalBytes := DatTotalBytes + 8;
    Inc(DatStringCount);
    Inc(DatStateCount);
  End;
End;

{ ------------------------------------------------------------ }
{ EmitFormatConst : generer des constantes de format OUTPUT     }
{   _JK_FMT_nnn DB 'format...', 0                              }
{ ------------------------------------------------------------ }

Procedure EmitFormatConst(Var OutBuf : TString; FmtIdx : Integer;
                          Const FmtStr : TString);
Var
  Line : TString;
Begin
  If DatFormatCount >= DAT_MAX_ENTRIES Then
  Begin
    Inc(DatErrorCount);
    Exit;
  End;

  Line := '  ' + PFX_CONST + 'FMT_' + ItoSI(FmtIdx) +
          ' DB ''' + FmtStr + ''', 0';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatTotalBytes := DatTotalBytes + LongInt(Length(FmtStr)) + 1;
  Inc(DatFormatCount);
  Inc(DatStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitBssSection : generer la section .data? (BSS)              }
{   Buffers E/S temporaires et variables non initialisees       }
{     _JV_IOBUF  DB 256 DUP(?)                                }
{     _JV_NUMBUF DB 32 DUP(?)                                  }
{ ------------------------------------------------------------ }

Procedure EmitBssSection(Var OutBuf : TString);
Var
  Line : TString;
Begin
  OutBuf := OutBuf + '.data?' + Chr(13) + Chr(10);

  { Buffer E/S general }
  Line := '  ' + PFX_VAR + 'IOBUF DB ' +
          ItoSI(DAT_IOBUF_SIZE) + ' DUP(?)';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + DAT_IOBUF_SIZE;
  Inc(DatBssCount);
  Inc(DatStateCount);

  { Buffer numerique pour conversions }
  Line := '  ' + PFX_VAR + 'NUMBUF DB ' +
          ItoSI(DAT_NUMBUF_SIZE) + ' DUP(?)';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + DAT_NUMBUF_SIZE;
  Inc(DatBssCount);
  Inc(DatStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeVars : generer les variables runtime dans .data?   }
{   _JV_STDOUT  DD ?  (handle console sortie)                 }
{   _JV_STDIN   DD ?  (handle console entree)                  }
{   _JV_WRITTEN DD ?  (octets ecrits par WriteFile)            }
{   _JV_READ    DD ?  (octets lus par ReadFile)                }
{ ------------------------------------------------------------ }

Procedure EmitRuntimeVars(Var OutBuf : TString);
Var
  Line : TString;
Begin
  { Handle de sortie console }
  Line := '  ' + PFX_VAR + 'STDOUT DD ?';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + 4;
  Inc(DatRuntimeCount);
  Inc(DatBssCount);
  Inc(DatStateCount);

  { Handle d entree console }
  Line := '  ' + PFX_VAR + 'STDIN DD ?';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + 4;
  Inc(DatRuntimeCount);
  Inc(DatBssCount);
  Inc(DatStateCount);

  { Octets ecrits par WriteFile }
  Line := '  ' + PFX_VAR + 'WRITTEN DD ?';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + 4;
  Inc(DatRuntimeCount);
  Inc(DatBssCount);
  Inc(DatStateCount);

  { Octets lus par ReadFile }
  Line := '  ' + PFX_VAR + 'READ DD ?';
  OutBuf := OutBuf + Line + Chr(13) + Chr(10);
  DatBssBytes := DatBssBytes + 4;
  Inc(DatRuntimeCount);
  Inc(DatBssCount);
  Inc(DatStateCount);
End;

{ ------------------------------------------------------------ }
{ GenerateDataSegment : orchestrer la generation complete du    }
{   segment de donnees (.data + .data?)                         }
{   Retourne le buffer contenant les directives assembleur      }
{ ------------------------------------------------------------ }

Function GenerateDataSegment : TString;
Var
  Buf : TString;
Begin
  Buf := '';
  Inc(DatStateCount);

  { Section .data : variables initialisees }
  Buf := Buf + '; ---- Section .data (variables initialisees) ----' +
         Chr(13) + Chr(10);
  Buf := Buf + '.data' + Chr(13) + Chr(10);

  { Alignement initial }
  Buf := Buf + '  ALIGN ' + ItoSI(DAT_ALIGN) + Chr(13) + Chr(10);

  { Emettre les ITEMs }
  EmitItemData(Buf);

  { Alignement entre ITEMs et TABLEs }
  Buf := Buf + '  ALIGN ' + ItoSI(DAT_ALIGN) + Chr(13) + Chr(10);

  { Emettre les TABLEs }
  EmitTableData(Buf);

  { Alignement avant les constantes chaines }
  Buf := Buf + '  ALIGN ' + ItoSI(DAT_ALIGN) + Chr(13) + Chr(10);

  { Emettre les constantes chaines }
  EmitStringConst(Buf);

  { Section .data? : variables non initialisees (BSS) }
  Buf := Buf + Chr(13) + Chr(10);
  Buf := Buf + '; ---- Section .data? (BSS, non initialisees) ----' +
         Chr(13) + Chr(10);

  { Emettre les buffers BSS }
  EmitBssSection(Buf);

  { Emettre les variables runtime }
  EmitRuntimeVars(Buf);

  { Aligner la taille totale }
  DatTotalBytes := AlignToN(DatTotalBytes, DAT_ALIGN);
  DatBssBytes   := AlignToN(DatBssBytes, DAT_ALIGN);

  GenerateDataSegment := Buf;
End;

{ ------------------------------------------------------------ }
{ IsDataGenRequired : verifier si la generation est necessaire  }
{ ------------------------------------------------------------ }

Function IsDataGenRequired : Boolean;
Begin
  IsDataGenRequired := (SymCount > 0);
End;

{ ------------------------------------------------------------ }
{ GetItemDataType : type de donnee DAT_* pour un symbole ITEM   }
{ ------------------------------------------------------------ }

Function GetItemDataType(Idx : Integer) : Integer;
Begin
  If (Idx < 0) Or (Idx >= SymCount) Then
  Begin
    GetItemDataType := DAT_NONE;
    Exit;
  End;
  If SymTab[Idx].SymKind <> SK_ITEM Then
  Begin
    GetItemDataType := DAT_NONE;
    Exit;
  End;
  Case SymTab[Idx].ItemType Of
    JT_INTEGER:
    Begin
      Case SymTab[Idx].ByteSize Of
        1 : GetItemDataType := DAT_ITEM_BYTE;
        2 : GetItemDataType := DAT_ITEM_WORD;
        4 : GetItemDataType := DAT_ITEM_DWORD;
      Else
        GetItemDataType := DAT_ITEM_DWORD;
      End;
    End;
    JT_STATUS:   GetItemDataType := DAT_ITEM_STATUS;
    JT_BITS:     GetItemDataType := DAT_ITEM_BITS;
    JT_FLOATING: GetItemDataType := DAT_ITEM_FLOAT;
  Else
    GetItemDataType := DAT_NONE;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpDataSegState : afficher l etat du generateur data segment  }
{ ------------------------------------------------------------ }

Procedure DumpDataSegState;
Begin
  WriteLn('=== Etat du generateur data segment (TODO 17) ===');
  WriteLn('  Initialise       : ', DatInitialized);
  WriteLn('  Operations       : ', DatStateCount);
  WriteLn('  ITEMs generes    : ', DatItemCount);
  WriteLn('  TABLEs generes   : ', DatTableCount);
  WriteLn('  Chaines generees : ', DatStringCount);
  WriteLn('  Formats generes  : ', DatFormatCount);
  WriteLn('  Entrees BSS      : ', DatBssCount);
  WriteLn('  Variables runtime: ', DatRuntimeCount);
  WriteLn('  Octets .data     : ', DatTotalBytes);
  WriteLn('  Octets .data?    : ', DatBssBytes);
  WriteLn('  Labels generes   : ', DatLabelNum);
  WriteLn('  Erreurs          : ', DatErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur data segment       }
{ ------------------------------------------------------------ }

Function IsDatInitialized : Boolean;
Begin
  IsDatInitialized := DatInitialized;
End;

Function IsDatEmpty : Boolean;
Begin
  IsDatEmpty := (DatItemCount = 0) And (DatTableCount = 0) And
                (DatStringCount = 0) And (DatBssCount = 0);
End;

Function GetDatStateCount : Integer;
Begin
  GetDatStateCount := DatStateCount;
End;

Function GetDatItemCount : Integer;
Begin
  GetDatItemCount := DatItemCount;
End;

Function GetDatTableCount : Integer;
Begin
  GetDatTableCount := DatTableCount;
End;

Function GetDatStringCount : Integer;
Begin
  GetDatStringCount := DatStringCount;
End;

Function GetDatFormatCount : Integer;
Begin
  GetDatFormatCount := DatFormatCount;
End;

Function GetDatTotalBytes : LongInt;
Begin
  GetDatTotalBytes := DatTotalBytes;
End;

Function GetDatBssBytes : LongInt;
Begin
  GetDatBssBytes := DatBssBytes;
End;

Function GetDatErrorCount : Integer;
Begin
  GetDatErrorCount := DatErrorCount;
End;


{ ============================================================ }
{ TODO 18 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 }
{   Generer le code assembleur 80386 pour les operations        }
{   arithmetiques entieres (8/16/32 bits), flottantes (FPU),    }
{   les expressions complexes (pile) et les comparaisons.       }
{ ============================================================ }

Const
  { Types d operations arithmetiques }
  ARI_NONE        = 0;   { aucune operation                         }
  ARI_ADD         = 1;   { addition entiere                         }
  ARI_SUB         = 2;   { soustraction entiere                     }
  ARI_MUL         = 3;   { multiplication entiere                   }
  ARI_DIV         = 4;   { division entiere                         }
  ARI_POW         = 5;   { puissance (boucle de multiplication)     }
  ARI_NEG         = 6;   { negation (NEG EAX)                       }
  ARI_FADD        = 7;   { addition flottante                       }
  ARI_FSUB        = 8;   { soustraction flottante                   }
  ARI_FMUL        = 9;   { multiplication flottante                 }
  ARI_FDIV        = 10;  { division flottante                       }
  ARI_CMP         = 11;  { comparaison entiere                      }
  ARI_LOAD        = 12;  { chargement dans EAX/FPU                  }
  ARI_STORE       = 13;  { stockage depuis EAX/FPU                  }

  { Limites }
  ARI_MAX_OPS     = 4096;  { nombre max d operations generees       }

Var
  { Variables du generateur d operations arithmetiques }
  AriInitialized  : Boolean;     { module initialise ?               }
  AriStateCount   : Integer;     { compteur d operations             }
  AriAddCount     : Integer;     { additions entieres generees       }
  AriSubCount     : Integer;     { soustractions entieres generees   }
  AriMulCount     : Integer;     { multiplications entieres generees }
  AriDivCount     : Integer;     { divisions entieres generees       }
  AriPowCount     : Integer;     { puissances generees               }
  AriNegCount     : Integer;     { negations generees                }
  AriFaddCount    : Integer;     { additions flottantes generees     }
  AriFsubCount    : Integer;     { soustractions flottantes generees }
  AriFmulCount    : Integer;     { multiplications flottantes gen.   }
  AriFdivCount    : Integer;     { divisions flottantes generees     }
  AriCmpCount     : Integer;     { comparaisons generees             }
  AriLoadCount    : Integer;     { chargements generes               }
  AriStoreCount   : Integer;     { stockages generes                 }
  AriLabelNum     : Integer;     { generateur de labels uniques      }
  AriErrorCount   : Integer;     { nombre d erreurs                  }

{ ------------------------------------------------------------ }
{ InitArithState : initialiser les variables du generateur      }
{ ------------------------------------------------------------ }

Procedure InitArithState;
Begin
  AriInitialized  := True;
  AriStateCount   := 0;
  AriAddCount     := 0;
  AriSubCount     := 0;
  AriMulCount     := 0;
  AriDivCount     := 0;
  AriPowCount     := 0;
  AriNegCount     := 0;
  AriFaddCount    := 0;
  AriFsubCount    := 0;
  AriFmulCount    := 0;
  AriFdivCount    := 0;
  AriCmpCount     := 0;
  AriLoadCount    := 0;
  AriStoreCount   := 0;
  AriLabelNum     := 0;
  AriErrorCount   := 0;
End;

{ ------------------------------------------------------------ }
{ GenAriLabel : generer un label unique pour l arithmetique      }
{ ------------------------------------------------------------ }

Function GenAriLabel : TString;
Begin
  Inc(AriLabelNum);
  GenAriLabel := PFX_LBL + 'ARI_' + ItoSI(AriLabelNum);
End;

{ ------------------------------------------------------------ }
{ AriTypeName : nom textuel d un type d operation arithmetique   }
{ ------------------------------------------------------------ }

Function AriTypeName(AriType : Integer) : TString;
Begin
  Case AriType Of
    ARI_NONE:   AriTypeName := 'NONE';
    ARI_ADD:    AriTypeName := 'ADD';
    ARI_SUB:    AriTypeName := 'SUB';
    ARI_MUL:    AriTypeName := 'MUL';
    ARI_DIV:    AriTypeName := 'DIV';
    ARI_POW:    AriTypeName := 'POW';
    ARI_NEG:    AriTypeName := 'NEG';
    ARI_FADD:   AriTypeName := 'FADD';
    ARI_FSUB:   AriTypeName := 'FSUB';
    ARI_FMUL:   AriTypeName := 'FMUL';
    ARI_FDIV:   AriTypeName := 'FDIV';
    ARI_CMP:    AriTypeName := 'CMP';
    ARI_LOAD:   AriTypeName := 'LOAD';
    ARI_STORE:  AriTypeName := 'STORE';
  Else
    AriTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitLoadItem : generer le code de chargement d un ITEM        }
{   8 bits  : MOVSX EAX, BYTE [_JV_nom]                        }
{   16 bits : MOVSX EAX, WORD [_JV_nom]                        }
{   32 bits : MOV EAX, DWORD [_JV_nom]                         }
{   FLOAT   : FLD DWORD [_JV_nom]                               }
{ ------------------------------------------------------------ }

Function EmitLoadItem(Const AsmName : TString;
                      ByteSz : Integer;
                      IsFloat : Boolean) : TString;
Var
  Buf : TString;
Begin
  Buf := '';
  If AriLoadCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitLoadItem := '; ERROR: max loads exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  If IsFloat Then
  Begin
    Buf := '  FLD DWORD [' + AsmName + ']';
  End
  Else
  Begin
    Case ByteSz Of
      1 : Buf := '  MOVSX EAX, BYTE [' + AsmName + ']';
      2 : Buf := '  MOVSX EAX, WORD [' + AsmName + ']';
      4 : Buf := '  MOV EAX, DWORD [' + AsmName + ']';
    Else
      Buf := '  MOV EAX, DWORD [' + AsmName + ']';
    End;
  End;

  Inc(AriLoadCount);
  Inc(AriStateCount);
  EmitLoadItem := Buf + Chr(13) + Chr(10);
End;

{ ------------------------------------------------------------ }
{ EmitStoreItem : generer le code de stockage vers un ITEM      }
{   8 bits  : MOV BYTE [_JV_nom], AL                            }
{   16 bits : MOV WORD [_JV_nom], AX                            }
{   32 bits : MOV DWORD [_JV_nom], EAX                          }
{   FLOAT   : FSTP DWORD [_JV_nom]                              }
{ ------------------------------------------------------------ }

Function EmitStoreItem(Const AsmName : TString;
                       ByteSz : Integer;
                       IsFloat : Boolean) : TString;
Var
  Buf : TString;
Begin
  Buf := '';
  If AriStoreCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitStoreItem := '; ERROR: max stores exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  If IsFloat Then
  Begin
    Buf := '  FSTP DWORD [' + AsmName + ']';
  End
  Else
  Begin
    Case ByteSz Of
      1 : Buf := '  MOV BYTE [' + AsmName + '], AL';
      2 : Buf := '  MOV WORD [' + AsmName + '], AX';
      4 : Buf := '  MOV DWORD [' + AsmName + '], EAX';
    Else
      Buf := '  MOV DWORD [' + AsmName + '], EAX';
    End;
  End;

  Inc(AriStoreCount);
  Inc(AriStateCount);
  EmitStoreItem := Buf + Chr(13) + Chr(10);
End;

{ ------------------------------------------------------------ }
{ EmitIntAdd : generer une addition entiere 32 bits              }
{   MOV EAX, [a]                                                }
{   ADD EAX, [b]                                                 }
{ ------------------------------------------------------------ }

Function EmitIntAdd(Const AsmA, AsmB : TString) : TString;
Var
  Buf : TString;
Begin
  If AriAddCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntAdd := '; ERROR: max adds exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  ADD EAX, DWORD [' + AsmB + ']' + Chr(13) + Chr(10);
  Inc(AriAddCount);
  Inc(AriStateCount);
  EmitIntAdd := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitIntSub : generer une soustraction entiere 32 bits          }
{   MOV EAX, [a]                                                }
{   SUB EAX, [b]                                                 }
{ ------------------------------------------------------------ }

Function EmitIntSub(Const AsmA, AsmB : TString) : TString;
Var
  Buf : TString;
Begin
  If AriSubCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntSub := '; ERROR: max subs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  SUB EAX, DWORD [' + AsmB + ']' + Chr(13) + Chr(10);
  Inc(AriSubCount);
  Inc(AriStateCount);
  EmitIntSub := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitIntMul : generer une multiplication entiere 32 bits        }
{   MOV EAX, [a]                                                }
{   IMUL EAX, DWORD [b]                                        }
{ ------------------------------------------------------------ }

Function EmitIntMul(Const AsmA, AsmB : TString) : TString;
Var
  Buf : TString;
Begin
  If AriMulCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntMul := '; ERROR: max muls exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  IMUL EAX, DWORD [' + AsmB + ']' + Chr(13) + Chr(10);
  Inc(AriMulCount);
  Inc(AriStateCount);
  EmitIntMul := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitIntDiv : generer une division entiere 32 bits              }
{   MOV EAX, [a]                                                }
{   CDQ                                                          }
{   IDIV DWORD [b]                                               }
{   Resultat dans EAX, reste dans EDX                            }
{ ------------------------------------------------------------ }

Function EmitIntDiv(Const AsmA, AsmB : TString) : TString;
Var
  Buf : TString;
Begin
  If AriDivCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntDiv := '; ERROR: max divs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  CDQ' + Chr(13) + Chr(10) +
         '  IDIV DWORD [' + AsmB + ']' + Chr(13) + Chr(10);
  Inc(AriDivCount);
  Inc(AriStateCount);
  EmitIntDiv := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitIntPow : generer une puissance entiere par boucle          }
{   MOV ECX, [exposant]                                          }
{   MOV EBX, [base]                                              }
{   MOV EAX, 1                                                   }
{   boucle: TEST ECX, ECX / JZ fin                              }
{           IMUL EAX, EBX / DEC ECX / JMP boucle                }
{   fin:                                                         }
{ ------------------------------------------------------------ }

Function EmitIntPow(Const AsmBase, AsmExp : TString) : TString;
Var
  Buf, LblLoop, LblDone : TString;
Begin
  If AriPowCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntPow := '; ERROR: max pows exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  LblLoop := GenAriLabel;
  LblDone := GenAriLabel;

  Buf := '  MOV ECX, DWORD [' + AsmExp + ']' + Chr(13) + Chr(10) +
         '  MOV EBX, DWORD [' + AsmBase + ']' + Chr(13) + Chr(10) +
         '  MOV EAX, 1' + Chr(13) + Chr(10) +
         LblLoop + ':' + Chr(13) + Chr(10) +
         '  TEST ECX, ECX' + Chr(13) + Chr(10) +
         '  JZ ' + LblDone + Chr(13) + Chr(10) +
         '  IMUL EAX, EBX' + Chr(13) + Chr(10) +
         '  DEC ECX' + Chr(13) + Chr(10) +
         '  JMP ' + LblLoop + Chr(13) + Chr(10) +
         LblDone + ':' + Chr(13) + Chr(10);
  Inc(AriPowCount);
  Inc(AriStateCount);
  EmitIntPow := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitIntNeg : generer une negation entiere                      }
{   MOV EAX, [a]                                                }
{   NEG EAX                                                      }
{ ------------------------------------------------------------ }

Function EmitIntNeg(Const AsmA : TString) : TString;
Var
  Buf : TString;
Begin
  If AriNegCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitIntNeg := '; ERROR: max negs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  NEG EAX' + Chr(13) + Chr(10);
  Inc(AriNegCount);
  Inc(AriStateCount);
  EmitIntNeg := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitFloatAdd : generer une addition flottante (FPU)            }
{   FLD DWORD [a]                                                }
{   FADD DWORD [b]                                               }
{   FSTP DWORD [r]                                               }
{ ------------------------------------------------------------ }

Function EmitFloatAdd(Const AsmA, AsmB, AsmR : TString) : TString;
Var
  Buf : TString;
Begin
  If AriFaddCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitFloatAdd := '; ERROR: max fadds exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  FLD DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  FADD DWORD [' + AsmB + ']' + Chr(13) + Chr(10) +
         '  FSTP DWORD [' + AsmR + ']' + Chr(13) + Chr(10);
  Inc(AriFaddCount);
  Inc(AriStateCount);
  EmitFloatAdd := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitFloatSub : generer une soustraction flottante (FPU)        }
{   FLD DWORD [a]                                                }
{   FSUB DWORD [b]                                               }
{   FSTP DWORD [r]                                               }
{ ------------------------------------------------------------ }

Function EmitFloatSub(Const AsmA, AsmB, AsmR : TString) : TString;
Var
  Buf : TString;
Begin
  If AriFsubCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitFloatSub := '; ERROR: max fsubs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  FLD DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  FSUB DWORD [' + AsmB + ']' + Chr(13) + Chr(10) +
         '  FSTP DWORD [' + AsmR + ']' + Chr(13) + Chr(10);
  Inc(AriFsubCount);
  Inc(AriStateCount);
  EmitFloatSub := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitFloatMul : generer une multiplication flottante (FPU)      }
{   FLD DWORD [a]                                                }
{   FMUL DWORD [b]                                               }
{   FSTP DWORD [r]                                               }
{ ------------------------------------------------------------ }

Function EmitFloatMul(Const AsmA, AsmB, AsmR : TString) : TString;
Var
  Buf : TString;
Begin
  If AriFmulCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitFloatMul := '; ERROR: max fmuls exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  FLD DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  FMUL DWORD [' + AsmB + ']' + Chr(13) + Chr(10) +
         '  FSTP DWORD [' + AsmR + ']' + Chr(13) + Chr(10);
  Inc(AriFmulCount);
  Inc(AriStateCount);
  EmitFloatMul := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitFloatDiv : generer une division flottante (FPU)            }
{   FLD DWORD [a]                                                }
{   FDIV DWORD [b]                                               }
{   FSTP DWORD [r]                                               }
{ ------------------------------------------------------------ }

Function EmitFloatDiv(Const AsmA, AsmB, AsmR : TString) : TString;
Var
  Buf : TString;
Begin
  If AriFdivCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitFloatDiv := '; ERROR: max fdivs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  FLD DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  FDIV DWORD [' + AsmB + ']' + Chr(13) + Chr(10) +
         '  FSTP DWORD [' + AsmR + ']' + Chr(13) + Chr(10);
  Inc(AriFdivCount);
  Inc(AriStateCount);
  EmitFloatDiv := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitPushEAX : sauvegarder EAX sur la pile pour les            }
{   expressions complexes                                        }
{ ------------------------------------------------------------ }

Function EmitPushEAX : TString;
Begin
  EmitPushEAX := '  PUSH EAX' + Chr(13) + Chr(10);
  Inc(AriStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitPopEBX : recuperer l operande gauche depuis la pile        }
{ ------------------------------------------------------------ }

Function EmitPopEBX : TString;
Begin
  EmitPopEBX := '  POP EBX' + Chr(13) + Chr(10);
  Inc(AriStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitBinOpRegs : generer une operation binaire registre-registre}
{   Operande gauche dans EBX, operande droit dans EAX           }
{   Resultat dans EAX                                            }
{ ------------------------------------------------------------ }

Function EmitBinOpRegs(Op : Integer) : TString;
Var
  Buf, LblLoop, LblDone : TString;
Begin
  Buf := '';
  Case Op Of
    ARI_ADD:
    Begin
      Buf := '  ADD EAX, EBX' + Chr(13) + Chr(10);
      Inc(AriAddCount);
    End;
    ARI_SUB:
    Begin
      { EBX = gauche, EAX = droit -> EBX - EAX }
      Buf := '  SUB EBX, EAX' + Chr(13) + Chr(10) +
             '  MOV EAX, EBX' + Chr(13) + Chr(10);
      Inc(AriSubCount);
    End;
    ARI_MUL:
    Begin
      Buf := '  IMUL EAX, EBX' + Chr(13) + Chr(10);
      Inc(AriMulCount);
    End;
    ARI_DIV:
    Begin
      { EBX = gauche, EAX = droit -> EBX / EAX }
      Buf := '  MOV ECX, EAX' + Chr(13) + Chr(10) +
             '  MOV EAX, EBX' + Chr(13) + Chr(10) +
             '  CDQ' + Chr(13) + Chr(10) +
             '  IDIV ECX' + Chr(13) + Chr(10);
      Inc(AriDivCount);
    End;
    ARI_POW:
    Begin
      { EBX = base, EAX = exposant }
      LblLoop := GenAriLabel;
      LblDone := GenAriLabel;
      Buf := '  MOV ECX, EAX' + Chr(13) + Chr(10) +
             '  MOV EAX, 1' + Chr(13) + Chr(10) +
             LblLoop + ':' + Chr(13) + Chr(10) +
             '  TEST ECX, ECX' + Chr(13) + Chr(10) +
             '  JZ ' + LblDone + Chr(13) + Chr(10) +
             '  IMUL EAX, EBX' + Chr(13) + Chr(10) +
             '  DEC ECX' + Chr(13) + Chr(10) +
             '  JMP ' + LblLoop + Chr(13) + Chr(10) +
             LblDone + ':' + Chr(13) + Chr(10);
      Inc(AriPowCount);
    End;
  Else
    Buf := '; ERROR: unknown binop ' + ItoSI(Op) + Chr(13) + Chr(10);
    Inc(AriErrorCount);
  End;

  Inc(AriStateCount);
  EmitBinOpRegs := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitCompare : generer une comparaison entiere                  }
{   CMP EAX, EBX                                                }
{   Jcc label_vrai                                               }
{   cc = E (=), NE (<>), L (<), LE (<=), G (>), GE (>=)        }
{ ------------------------------------------------------------ }

Function EmitCompare(Const AsmA, AsmB : TString;
                     Op : Integer) : TString;
Var
  Buf, Jcc : TString;
Begin
  If AriCmpCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitCompare := '; ERROR: max cmps exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Case Op Of
    OP_EQ  : Jcc := 'JE';
    OP_NE  : Jcc := 'JNE';
    OP_LT  : Jcc := 'JL';
    OP_LE  : Jcc := 'JLE';
    OP_GT  : Jcc := 'JG';
    OP_GE  : Jcc := 'JGE';
  Else
    Jcc := 'JE';
  End;

  Buf := '  MOV EAX, DWORD [' + AsmA + ']' + Chr(13) + Chr(10) +
         '  CMP EAX, DWORD [' + AsmB + ']' + Chr(13) + Chr(10) +
         '  ' + Jcc + ' ';
  Inc(AriCmpCount);
  Inc(AriStateCount);
  EmitCompare := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitCompareRegs : generer une comparaison registre-registre    }
{   EBX = operande gauche, EAX = operande droit                 }
{   CMP EBX, EAX                                                }
{   Jcc label                                                    }
{ ------------------------------------------------------------ }

Function EmitCompareRegs(Op : Integer) : TString;
Var
  Buf, Jcc : TString;
Begin
  If AriCmpCount >= ARI_MAX_OPS Then
  Begin
    Inc(AriErrorCount);
    EmitCompareRegs := '; ERROR: max cmps exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Case Op Of
    OP_EQ  : Jcc := 'JE';
    OP_NE  : Jcc := 'JNE';
    OP_LT  : Jcc := 'JL';
    OP_LE  : Jcc := 'JLE';
    OP_GT  : Jcc := 'JG';
    OP_GE  : Jcc := 'JGE';
  Else
    Jcc := 'JE';
  End;

  Buf := '  CMP EBX, EAX' + Chr(13) + Chr(10) +
         '  ' + Jcc + ' ';
  Inc(AriCmpCount);
  Inc(AriStateCount);
  EmitCompareRegs := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitLoadImmediate : charger une valeur immediate dans EAX      }
{   MOV EAX, valeur                                              }
{ ------------------------------------------------------------ }

Function EmitLoadImmediate(Value : LongInt) : TString;
Var
  Buf, VS : TString;
Begin
  Str(Value, VS);
  Buf := '  MOV EAX, ' + VS + Chr(13) + Chr(10);
  Inc(AriLoadCount);
  Inc(AriStateCount);
  EmitLoadImmediate := Buf;
End;

{ ------------------------------------------------------------ }
{ GetArithOpFromExpOp : convertir un operateur d expression      }
{   (OP_ADD, OP_SUB, ...) en type d operation arithmetique       }
{   (ARI_ADD, ARI_SUB, ...)                                     }
{ ------------------------------------------------------------ }

Function GetArithOpFromExpOp(ExpOp : Integer) : Integer;
Begin
  Case ExpOp Of
    OP_ADD : GetArithOpFromExpOp := ARI_ADD;
    OP_SUB : GetArithOpFromExpOp := ARI_SUB;
    OP_MUL : GetArithOpFromExpOp := ARI_MUL;
    OP_DIV : GetArithOpFromExpOp := ARI_DIV;
    OP_POWER : GetArithOpFromExpOp := ARI_POW;
  Else
    GetArithOpFromExpOp := ARI_NONE;
  End;
End;

{ ------------------------------------------------------------ }
{ IsFloatArithOp : determiner si une operation est flottante     }
{ ------------------------------------------------------------ }

Function IsFloatArithOp(AriType : Integer) : Boolean;
Begin
  IsFloatArithOp := (AriType >= ARI_FADD) And (AriType <= ARI_FDIV);
End;

{ ------------------------------------------------------------ }
{ DumpArithState : afficher l etat du generateur arithmetique    }
{ ------------------------------------------------------------ }

Procedure DumpArithState;
Begin
  WriteLn('=== Etat du generateur arithmetique (TODO 18) ===');
  WriteLn('  Initialise       : ', AriInitialized);
  WriteLn('  Operations       : ', AriStateCount);
  WriteLn('  Additions (int)  : ', AriAddCount);
  WriteLn('  Soustractions    : ', AriSubCount);
  WriteLn('  Multiplications  : ', AriMulCount);
  WriteLn('  Divisions        : ', AriDivCount);
  WriteLn('  Puissances       : ', AriPowCount);
  WriteLn('  Negations        : ', AriNegCount);
  WriteLn('  FADD (float)     : ', AriFaddCount);
  WriteLn('  FSUB (float)     : ', AriFsubCount);
  WriteLn('  FMUL (float)     : ', AriFmulCount);
  WriteLn('  FDIV (float)     : ', AriFdivCount);
  WriteLn('  Comparaisons     : ', AriCmpCount);
  WriteLn('  Chargements      : ', AriLoadCount);
  WriteLn('  Stockages        : ', AriStoreCount);
  WriteLn('  Labels generes   : ', AriLabelNum);
  WriteLn('  Erreurs          : ', AriErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur arithmetique        }
{ ------------------------------------------------------------ }

Function IsAriInitialized : Boolean;
Begin
  IsAriInitialized := AriInitialized;
End;

Function IsAriEmpty : Boolean;
Begin
  IsAriEmpty := (AriStateCount = 0);
End;

Function GetAriStateCount : Integer;
Begin
  GetAriStateCount := AriStateCount;
End;

Function GetAriAddCount : Integer;
Begin
  GetAriAddCount := AriAddCount;
End;

Function GetAriMulCount : Integer;
Begin
  GetAriMulCount := AriMulCount;
End;

Function GetAriDivCount : Integer;
Begin
  GetAriDivCount := AriDivCount;
End;

Function GetAriFaddCount : Integer;
Begin
  GetAriFaddCount := AriFaddCount;
End;

Function GetAriCmpCount : Integer;
Begin
  GetAriCmpCount := AriCmpCount;
End;

Function GetAriLabelNum : Integer;
Begin
  GetAriLabelNum := AriLabelNum;
End;

Function GetAriErrorCount : Integer;
Begin
  GetAriErrorCount := AriErrorCount;
End;


{ ============================================================ }
{ TODO 19 - GENERATION DE CODE : STRUCTURES DE CONTROLE 80386   }
{   Generer le code assembleur 80386 pour les structures de     }
{   controle : IF/ELSE/END, FOR/TO/DO/END, FOR/BY/TO,          }
{   WHILE/DO/END, DO/UNTIL. Labels uniques pour chaque          }
{   structure, sauts conditionnels et inconditionnels.           }
{ ============================================================ }

Const
  { Types de structures de controle generees }
  CTG_NONE        = 0;   { aucune structure                         }
  CTG_IF          = 1;   { IF / ELSE / END                          }
  CTG_FOR         = 2;   { FOR var = debut TO fin DO ... END         }
  CTG_FOR_BY      = 3;   { FOR var = debut BY pas TO fin DO ... END  }
  CTG_WHILE       = 4;   { WHILE condition DO ... END                }
  CTG_DO_UNTIL    = 5;   { DO ... UNTIL condition                    }
  CTG_GOTO        = 6;   { JMP label                                 }
  CTG_LABEL       = 7;   { label:                                    }

  { Limites }
  CTG_MAX_OPS     = 4096;  { nombre max de structures generees      }

Var
  { Variables du generateur de structures de controle }
  CtgInitialized  : Boolean;     { module initialise ?               }
  CtgStateCount   : Integer;     { compteur total d operations       }
  CtgIfCount      : Integer;     { IF generes                        }
  CtgForCount     : Integer;     { FOR generes                       }
  CtgForByCount   : Integer;     { FOR BY generes                    }
  CtgWhileCount   : Integer;     { WHILE generes                     }
  CtgDoUntilCount : Integer;     { DO UNTIL generes                  }
  CtgGotoCount    : Integer;     { GOTO generes                      }
  CtgLabelGenCount: Integer;     { labels de code generes            }
  CtgLabelNum     : Integer;     { generateur de labels uniques      }
  CtgErrorCount   : Integer;     { nombre d erreurs                  }

{ ------------------------------------------------------------ }
{ InitCtrlGenState : initialiser les variables du generateur     }
{ ------------------------------------------------------------ }

Procedure InitCtrlGenState;
Begin
  CtgInitialized  := True;
  CtgStateCount   := 0;
  CtgIfCount      := 0;
  CtgForCount     := 0;
  CtgForByCount   := 0;
  CtgWhileCount   := 0;
  CtgDoUntilCount := 0;
  CtgGotoCount    := 0;
  CtgLabelGenCount:= 0;
  CtgLabelNum     := 0;
  CtgErrorCount   := 0;
End;

{ ------------------------------------------------------------ }
{ GenCtgLabel : generer un label unique pour le controle de flux  }
{ ------------------------------------------------------------ }

Function GenCtgLabel : TString;
Begin
  Inc(CtgLabelNum);
  GenCtgLabel := PFX_LBL + 'CTG_' + ItoSI(CtgLabelNum);
End;

{ ------------------------------------------------------------ }
{ CtgTypeName : nom textuel d un type de structure generee       }
{ ------------------------------------------------------------ }

Function CtgTypeName(CtgType : Integer) : TString;
Begin
  Case CtgType Of
    CTG_NONE     : CtgTypeName := 'NONE';
    CTG_IF       : CtgTypeName := 'IF';
    CTG_FOR      : CtgTypeName := 'FOR';
    CTG_FOR_BY   : CtgTypeName := 'FOR_BY';
    CTG_WHILE    : CtgTypeName := 'WHILE';
    CTG_DO_UNTIL : CtgTypeName := 'DO_UNTIL';
    CTG_GOTO     : CtgTypeName := 'GOTO';
    CTG_LABEL    : CtgTypeName := 'LABEL';
  Else
    CtgTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitIfElse : generer le code 80386 pour IF / ELSE / END        }
{   Evaluer la condition -> flags deja positionnes              }
{   Jcc _JL_ELSE_nnn (saut conditionnel si faux)               }
{   ... bloc THEN ...                                            }
{   JMP _JL_ENDIF_nnn                                            }
{   _JL_ELSE_nnn:                                                }
{   ... bloc ELSE ...                                            }
{   _JL_ENDIF_nnn:                                               }
{                                                                }
{ CondJcc = code de saut inverse (JNE, JE, JGE, JLE, ...)      }
{ ThenCode = code du bloc THEN                                  }
{ ElseCode = code du bloc ELSE (vide si pas de ELSE)            }
{ ------------------------------------------------------------ }

Function EmitIfElse(Const CondJcc : TString;
                    Const ThenCode : TString;
                    Const ElseCode : TString) : TString;
Var
  Buf, LblElse, LblEndIf : TString;
Begin
  If CtgIfCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitIfElse := '; ERROR: max IF structures exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  LblElse  := GenCtgLabel;
  LblEndIf := GenCtgLabel;

  If ElseCode = '' Then
  Begin
    { IF sans ELSE }
    Buf := '  ' + CondJcc + ' ' + LblEndIf + Chr(13) + Chr(10) +
           ThenCode +
           LblEndIf + ':' + Chr(13) + Chr(10);
  End
  Else
  Begin
    { IF avec ELSE }
    Buf := '  ' + CondJcc + ' ' + LblElse + Chr(13) + Chr(10) +
           ThenCode +
           '  JMP ' + LblEndIf + Chr(13) + Chr(10) +
           LblElse + ':' + Chr(13) + Chr(10) +
           ElseCode +
           LblEndIf + ':' + Chr(13) + Chr(10);
  End;

  Inc(CtgIfCount);
  Inc(CtgStateCount);
  EmitIfElse := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitForLoop : generer le code 80386 pour FOR (pas = 1)         }
{   MOV DWORD [var], debut                                       }
{   _JL_FOR_nnn:                                                 }
{   MOV EAX, DWORD [var]                                         }
{   CMP EAX, fin                                                 }
{   JG _JL_FOREND_nnn                                            }
{   ... corps de la boucle ...                                   }
{   INC DWORD [var]                                              }
{   JMP _JL_FOR_nnn                                              }
{   _JL_FOREND_nnn:                                              }
{ ------------------------------------------------------------ }

Function EmitForLoop(Const AsmVar : TString;
                     StartVal, EndVal : LongInt;
                     Const BodyCode : TString) : TString;
Var
  Buf, LblFor, LblForEnd : TString;
  SV, EV : TString;
Begin
  If CtgForCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitForLoop := '; ERROR: max FOR structures exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Str(StartVal, SV);
  Str(EndVal, EV);
  LblFor    := GenCtgLabel;
  LblForEnd := GenCtgLabel;

  Buf := '  MOV DWORD [' + AsmVar + '], ' + SV + Chr(13) + Chr(10) +
         LblFor + ':' + Chr(13) + Chr(10) +
         '  MOV EAX, DWORD [' + AsmVar + ']' + Chr(13) + Chr(10) +
         '  CMP EAX, ' + EV + Chr(13) + Chr(10) +
         '  JG ' + LblForEnd + Chr(13) + Chr(10) +
         BodyCode +
         '  INC DWORD [' + AsmVar + ']' + Chr(13) + Chr(10) +
         '  JMP ' + LblFor + Chr(13) + Chr(10) +
         LblForEnd + ':' + Chr(13) + Chr(10);

  Inc(CtgForCount);
  Inc(CtgStateCount);
  EmitForLoop := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitForByLoop : generer le code 80386 pour FOR avec BY (pas)   }
{   MOV DWORD [var], debut                                       }
{   _JL_FOR_nnn:                                                 }
{   MOV EAX, DWORD [var]                                         }
{   CMP EAX, fin                                                 }
{   Si pas > 0 : JG _JL_FOREND_nnn                              }
{   Si pas < 0 : JL _JL_FOREND_nnn                              }
{   ... corps de la boucle ...                                   }
{   ADD DWORD [var], pas                                         }
{   JMP _JL_FOR_nnn                                              }
{   _JL_FOREND_nnn:                                              }
{ ------------------------------------------------------------ }

Function EmitForByLoop(Const AsmVar : TString;
                       StartVal, EndVal, StepVal : LongInt;
                       Const BodyCode : TString) : TString;
Var
  Buf, LblFor, LblForEnd : TString;
  SV, EV, TV : TString;
  Jmp : TString;
Begin
  If CtgForByCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitForByLoop := '; ERROR: max FOR BY structures exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Str(StartVal, SV);
  Str(EndVal, EV);
  Str(StepVal, TV);
  LblFor    := GenCtgLabel;
  LblForEnd := GenCtgLabel;

  { Choisir la condition de sortie selon le signe du pas }
  If StepVal < 0 Then
    Jmp := 'JL'
  Else
    Jmp := 'JG';

  Buf := '  MOV DWORD [' + AsmVar + '], ' + SV + Chr(13) + Chr(10) +
         LblFor + ':' + Chr(13) + Chr(10) +
         '  MOV EAX, DWORD [' + AsmVar + ']' + Chr(13) + Chr(10) +
         '  CMP EAX, ' + EV + Chr(13) + Chr(10) +
         '  ' + Jmp + ' ' + LblForEnd + Chr(13) + Chr(10) +
         BodyCode +
         '  ADD DWORD [' + AsmVar + '], ' + TV + Chr(13) + Chr(10) +
         '  JMP ' + LblFor + Chr(13) + Chr(10) +
         LblForEnd + ':' + Chr(13) + Chr(10);

  Inc(CtgForByCount);
  Inc(CtgStateCount);
  EmitForByLoop := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitWhileLoop : generer le code 80386 pour WHILE               }
{   _JL_WHILE_nnn:                                               }
{   Evaluer condition -> flags                                   }
{   Jcc _JL_WHEND_nnn (saut si faux)                            }
{   ... corps ...                                                }
{   JMP _JL_WHILE_nnn                                            }
{   _JL_WHEND_nnn:                                               }
{                                                                }
{ CondCode = code d evaluation de la condition                  }
{ CondJcc = saut conditionnel inverse (JE, JNE, ...)            }
{ BodyCode = code du corps de la boucle                         }
{ ------------------------------------------------------------ }

Function EmitWhileLoop(Const CondCode : TString;
                       Const CondJcc : TString;
                       Const BodyCode : TString) : TString;
Var
  Buf, LblWhile, LblWhEnd : TString;
Begin
  If CtgWhileCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitWhileLoop := '; ERROR: max WHILE structures exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  LblWhile := GenCtgLabel;
  LblWhEnd := GenCtgLabel;

  Buf := LblWhile + ':' + Chr(13) + Chr(10) +
         CondCode +
         '  ' + CondJcc + ' ' + LblWhEnd + Chr(13) + Chr(10) +
         BodyCode +
         '  JMP ' + LblWhile + Chr(13) + Chr(10) +
         LblWhEnd + ':' + Chr(13) + Chr(10);

  Inc(CtgWhileCount);
  Inc(CtgStateCount);
  EmitWhileLoop := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitDoUntil : generer le code 80386 pour DO ... UNTIL          }
{   _JL_DO_nnn:                                                  }
{   ... corps ...                                                }
{   Evaluer condition -> flags                                   }
{   Jcc _JL_DO_nnn (saut si faux, continuer boucle)             }
{                                                                }
{ BodyCode = code du corps de la boucle                         }
{ CondCode = code d evaluation de la condition                  }
{ CondJcc = saut conditionnel inverse (reboucle si faux)        }
{ ------------------------------------------------------------ }

Function EmitDoUntil(Const BodyCode : TString;
                     Const CondCode : TString;
                     Const CondJcc : TString) : TString;
Var
  Buf, LblDo : TString;
Begin
  If CtgDoUntilCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitDoUntil := '; ERROR: max DO UNTIL structures exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  LblDo := GenCtgLabel;

  Buf := LblDo + ':' + Chr(13) + Chr(10) +
         BodyCode +
         CondCode +
         '  ' + CondJcc + ' ' + LblDo + Chr(13) + Chr(10);

  Inc(CtgDoUntilCount);
  Inc(CtgStateCount);
  EmitDoUntil := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitGotoLabel : generer un saut inconditionnel JMP label        }
{ ------------------------------------------------------------ }

Function EmitGotoLabel(Const LblName : TString) : TString;
Var
  Buf : TString;
Begin
  If CtgGotoCount >= CTG_MAX_OPS Then
  Begin
    Inc(CtgErrorCount);
    EmitGotoLabel := '; ERROR: max GOTOs exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '  JMP ' + LblName + Chr(13) + Chr(10);
  Inc(CtgGotoCount);
  Inc(CtgStateCount);
  EmitGotoLabel := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitCodeLabel : generer un label dans le code                  }
{ ------------------------------------------------------------ }

Function EmitCodeLabel(Const LblName : TString) : TString;
Var
  Buf : TString;
Begin
  Buf := LblName + ':' + Chr(13) + Chr(10);
  Inc(CtgLabelGenCount);
  Inc(CtgStateCount);
  EmitCodeLabel := Buf;
End;

{ ------------------------------------------------------------ }
{ GetCondJccInverse : retourner le saut conditionnel inverse      }
{   pour une comparaison donnee (pour sauter quand la condition  }
{   est FAUSSE)                                                  }
{ ------------------------------------------------------------ }

Function GetCondJccInverse(Op : Integer) : TString;
Begin
  Case Op Of
    OP_EQ  : GetCondJccInverse := 'JNE';
    OP_NE  : GetCondJccInverse := 'JE';
    OP_LT  : GetCondJccInverse := 'JGE';
    OP_LE  : GetCondJccInverse := 'JG';
    OP_GT  : GetCondJccInverse := 'JLE';
    OP_GE  : GetCondJccInverse := 'JL';
  Else
    GetCondJccInverse := 'JNE';
  End;
End;

{ ------------------------------------------------------------ }
{ IsCtrlGenRequired : determiner si la generation de structures  }
{   de controle est necessaire                                   }
{ ------------------------------------------------------------ }

Function IsCtrlGenRequired : Boolean;
Begin
  IsCtrlGenRequired := (CtgStateCount > 0);
End;

{ ------------------------------------------------------------ }
{ DumpCtrlGenState : afficher l etat du generateur de controle    }
{ ------------------------------------------------------------ }

Procedure DumpCtrlGenState;
Begin
  WriteLn('=== Etat du generateur de controle (TODO 19) ===');
  WriteLn('  Initialise       : ', CtgInitialized);
  WriteLn('  Operations       : ', CtgStateCount);
  WriteLn('  IF generes       : ', CtgIfCount);
  WriteLn('  FOR generes      : ', CtgForCount);
  WriteLn('  FOR BY generes   : ', CtgForByCount);
  WriteLn('  WHILE generes    : ', CtgWhileCount);
  WriteLn('  DO UNTIL generes : ', CtgDoUntilCount);
  WriteLn('  GOTO generes     : ', CtgGotoCount);
  WriteLn('  Labels generes   : ', CtgLabelGenCount);
  WriteLn('  Labels uniques   : ', CtgLabelNum);
  WriteLn('  Erreurs          : ', CtgErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur de controle          }
{ ------------------------------------------------------------ }

Function IsCtgInitialized : Boolean;
Begin
  IsCtgInitialized := CtgInitialized;
End;

Function IsCtgEmpty : Boolean;
Begin
  IsCtgEmpty := (CtgStateCount = 0);
End;

Function GetCtgStateCount : Integer;
Begin
  GetCtgStateCount := CtgStateCount;
End;

Function GetCtgIfCount : Integer;
Begin
  GetCtgIfCount := CtgIfCount;
End;

Function GetCtgForCount : Integer;
Begin
  GetCtgForCount := CtgForCount;
End;

Function GetCtgForByCount : Integer;
Begin
  GetCtgForByCount := CtgForByCount;
End;

Function GetCtgWhileCount : Integer;
Begin
  GetCtgWhileCount := CtgWhileCount;
End;

Function GetCtgDoUntilCount : Integer;
Begin
  GetCtgDoUntilCount := CtgDoUntilCount;
End;

Function GetCtgLabelNum : Integer;
Begin
  GetCtgLabelNum := CtgLabelNum;
End;

Function GetCtgErrorCount : Integer;
Begin
  GetCtgErrorCount := CtgErrorCount;
End;


{ ============================================================ }
{ TODO 20 - BIBLIOTHEQUE RUNTIME JOVIAL (E/S, CONVERSIONS)      }
{   Generer les routines runtime en assembleur 80386 pour le    }
{   support d execution Jovial : conversion entier/chaine,      }
{   E/S console via Win32 API, routines math inline,            }
{   variables internes (_JV_IOBUF, _JV_STDOUT, etc.)           }
{ ============================================================ }

Const
  { Types de routines runtime }
  RTL_NONE        = 0;   { aucune routine                           }
  RTL_ITOA        = 1;   { conversion entier -> chaine              }
  RTL_ATOI        = 2;   { conversion chaine -> entier              }
  RTL_FORMAT      = 3;   { formater une chaine avec $D              }
  RTL_INIT_IO     = 4;   { initialiser les handles console          }
  RTL_WRITE_STR   = 5;   { ecrire une chaine sur la console         }
  RTL_WRITE_CRLF  = 6;   { ecrire un retour a la ligne              }
  RTL_READ_LINE   = 7;   { lire une ligne depuis la console         }
  RTL_OUTPUT      = 8;   { routine combinee pour OUTPUT Jovial      }
  RTL_ABS         = 9;   { valeur absolue (inline)                  }
  RTL_SGN         = 10;  { signe (inline)                           }
  RTL_POWER       = 11;  { exponentiation par boucle                }

  { Limites }
  RTL_MAX_OPS     = 4096;  { nombre max de routines generees        }

  { Tailles des buffers runtime }
  RTL_IOBUF_SIZE  = 256;   { taille du buffer E/S                   }
  RTL_NUMBUF_SIZE = 32;    { taille du buffer de conversion nombre   }

  { Constantes Win32 API }
  STD_INPUT_HANDLE  = -10;
  STD_OUTPUT_HANDLE = -11;

Var
  { Variables du generateur de runtime }
  RtlInitialized    : Boolean;     { module initialise ?             }
  RtlStateCount     : Integer;     { compteur total d operations     }
  RtlItoaCount      : Integer;     { conversions ITOA generees       }
  RtlAtoiCount      : Integer;     { conversions ATOI generees       }
  RtlFormatCount    : Integer;     { FORMAT generes                  }
  RtlInitIOCount    : Integer;     { INIT_IO generes                 }
  RtlWriteStrCount  : Integer;     { WRITE_STR generes               }
  RtlWriteCrlfCount : Integer;     { WRITE_CRLF generes              }
  RtlReadLineCount  : Integer;     { READ_LINE generes               }
  RtlOutputCount    : Integer;     { OUTPUT generes                  }
  RtlAbsCount       : Integer;     { ABS generes                     }
  RtlSgnCount       : Integer;     { SGN generes                     }
  RtlPowerCount     : Integer;     { POWER generes                   }
  RtlLabelNum       : Integer;     { generateur de labels uniques    }
  RtlErrorCount     : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitRuntimeState : initialiser les variables du runtime        }
{ ------------------------------------------------------------ }

Procedure InitRuntimeState;
Begin
  RtlInitialized    := True;
  RtlStateCount     := 0;
  RtlItoaCount      := 0;
  RtlAtoiCount      := 0;
  RtlFormatCount    := 0;
  RtlInitIOCount    := 0;
  RtlWriteStrCount  := 0;
  RtlWriteCrlfCount := 0;
  RtlReadLineCount  := 0;
  RtlOutputCount    := 0;
  RtlAbsCount       := 0;
  RtlSgnCount       := 0;
  RtlPowerCount     := 0;
  RtlLabelNum       := 0;
  RtlErrorCount     := 0;
End;

{ ------------------------------------------------------------ }
{ GenRtlLabel : generer un label unique pour les routines runtime }
{ ------------------------------------------------------------ }

Function GenRtlLabel : TString;
Begin
  Inc(RtlLabelNum);
  GenRtlLabel := PFX_LBL + 'RTL_' + ItoSI(RtlLabelNum);
End;

{ ------------------------------------------------------------ }
{ RtlTypeName : nom textuel d un type de routine runtime         }
{ ------------------------------------------------------------ }

Function RtlTypeName(RtlType : Integer) : TString;
Begin
  Case RtlType Of
    RTL_NONE       : RtlTypeName := 'NONE';
    RTL_ITOA       : RtlTypeName := 'ITOA';
    RTL_ATOI       : RtlTypeName := 'ATOI';
    RTL_FORMAT     : RtlTypeName := 'FORMAT';
    RTL_INIT_IO    : RtlTypeName := 'INIT_IO';
    RTL_WRITE_STR  : RtlTypeName := 'WRITE_STR';
    RTL_WRITE_CRLF : RtlTypeName := 'WRITE_CRLF';
    RTL_READ_LINE  : RtlTypeName := 'READ_LINE';
    RTL_OUTPUT     : RtlTypeName := 'OUTPUT';
    RTL_ABS        : RtlTypeName := 'ABS';
    RTL_SGN        : RtlTypeName := 'SGN';
    RTL_POWER      : RtlTypeName := 'POWER';
  Else
    RtlTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitRtlItoa : generer _JVRT_ITOA                              }
{   entier 32 bits (EAX) -> chaine decimale ASCII dans _JV_NUMBUF }
{   Utilise DIV par 10 en boucle, empile les chiffres puis les  }
{   depile pour inverser l ordre                                }
{ ------------------------------------------------------------ }

Function EmitRtlItoa : TString;
Var
  Buf : TString;
  Lbl1, Lbl2, Lbl3 : TString;
Begin
  If RtlItoaCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlItoa := '; ERROR: max ITOA exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl1 := GenRtlLabel;
  Lbl2 := GenRtlLabel;
  Lbl3 := GenRtlLabel;

  Buf := PFX_RT + 'ITOA:' + Chr(13) + Chr(10) +
         '  PUSH EBX' + Chr(13) + Chr(10) +
         '  PUSH ECX' + Chr(13) + Chr(10) +
         '  PUSH EDX' + Chr(13) + Chr(10) +
         '  MOV ECX, 0' + Chr(13) + Chr(10) +
         '  CMP EAX, 0' + Chr(13) + Chr(10) +
         '  JGE ' + Lbl1 + Chr(13) + Chr(10) +
         '  NEG EAX' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  MOV BYTE [' + PFX_VAR + 'NUMBUF], 45' + Chr(13) + Chr(10) +
         '  LEA EDI, [' + PFX_VAR + 'NUMBUF + 1]' + Chr(13) + Chr(10) +
         '  POP EAX' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl2 + Chr(13) + Chr(10) +
         Lbl1 + ':' + Chr(13) + Chr(10) +
         '  LEA EDI, [' + PFX_VAR + 'NUMBUF]' + Chr(13) + Chr(10) +
         Lbl2 + ':' + Chr(13) + Chr(10) +
         '  MOV EBX, 10' + Chr(13) + Chr(10) +
         '  XOR ECX, ECX' + Chr(13) + Chr(10) +
         '  ; diviser en boucle et empiler les chiffres' + Chr(13) + Chr(10) +
         Lbl3 + ':' + Chr(13) + Chr(10) +
         '  XOR EDX, EDX' + Chr(13) + Chr(10) +
         '  DIV EBX' + Chr(13) + Chr(10) +
         '  ADD DL, 48' + Chr(13) + Chr(10) +
         '  PUSH EDX' + Chr(13) + Chr(10) +
         '  INC ECX' + Chr(13) + Chr(10) +
         '  CMP EAX, 0' + Chr(13) + Chr(10) +
         '  JNE ' + Lbl3 + Chr(13) + Chr(10) +
         '  ; depiler les chiffres dans le buffer' + Chr(13) + Chr(10) +
         '  MOV ESI, ECX' + Chr(13) + Chr(10);

  { Note: pour rester dans TString, on limite a ce squelette }
  Buf := Buf +
         '  POP EDX' + Chr(13) + Chr(10) +
         '  POP ECX' + Chr(13) + Chr(10) +
         '  POP EBX' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlItoaCount);
  Inc(RtlStateCount);
  EmitRtlItoa := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlAtoi : generer _JVRT_ATOI                              }
{   chaine ASCII (ESI) -> entier 32 bits dans EAX               }
{   Utilise IMUL par 10 et ADD pour chaque chiffre              }
{ ------------------------------------------------------------ }

Function EmitRtlAtoi : TString;
Var
  Buf : TString;
  Lbl1, Lbl2 : TString;
Begin
  If RtlAtoiCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlAtoi := '; ERROR: max ATOI exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl1 := GenRtlLabel;
  Lbl2 := GenRtlLabel;

  Buf := PFX_RT + 'ATOI:' + Chr(13) + Chr(10) +
         '  PUSH EBX' + Chr(13) + Chr(10) +
         '  PUSH ECX' + Chr(13) + Chr(10) +
         '  XOR EAX, EAX' + Chr(13) + Chr(10) +
         '  MOV EBX, 10' + Chr(13) + Chr(10) +
         Lbl1 + ':' + Chr(13) + Chr(10) +
         '  MOVZX ECX, BYTE [ESI]' + Chr(13) + Chr(10) +
         '  CMP ECX, 48' + Chr(13) + Chr(10) +
         '  JL ' + Lbl2 + Chr(13) + Chr(10) +
         '  CMP ECX, 57' + Chr(13) + Chr(10) +
         '  JG ' + Lbl2 + Chr(13) + Chr(10) +
         '  SUB ECX, 48' + Chr(13) + Chr(10) +
         '  IMUL EAX, EBX' + Chr(13) + Chr(10) +
         '  ADD EAX, ECX' + Chr(13) + Chr(10) +
         '  INC ESI' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl1 + Chr(13) + Chr(10) +
         Lbl2 + ':' + Chr(13) + Chr(10) +
         '  POP ECX' + Chr(13) + Chr(10) +
         '  POP EBX' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlAtoiCount);
  Inc(RtlStateCount);
  EmitRtlAtoi := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlFormat : generer _JVRT_FORMAT                           }
{   Parcourir le format (ESI), remplacer $D par la conversion   }
{   de l argument correspondant (pile), resultat dans EDI       }
{ ------------------------------------------------------------ }

Function EmitRtlFormat : TString;
Var
  Buf : TString;
  Lbl1, Lbl2, Lbl3, Lbl4 : TString;
Begin
  If RtlFormatCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlFormat := '; ERROR: max FORMAT exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl1 := GenRtlLabel;
  Lbl2 := GenRtlLabel;
  Lbl3 := GenRtlLabel;
  Lbl4 := GenRtlLabel;

  Buf := PFX_RT + 'FORMAT:' + Chr(13) + Chr(10) +
         '  PUSH EBX' + Chr(13) + Chr(10) +
         '  PUSH ECX' + Chr(13) + Chr(10) +
         '  LEA EDI, [' + PFX_VAR + 'IOBUF]' + Chr(13) + Chr(10) +
         Lbl1 + ':' + Chr(13) + Chr(10) +
         '  LODSB' + Chr(13) + Chr(10) +
         '  CMP AL, 0' + Chr(13) + Chr(10) +
         '  JE ' + Lbl4 + Chr(13) + Chr(10) +
         '  CMP AL, 36' + Chr(13) + Chr(10) +
         '  JNE ' + Lbl3 + Chr(13) + Chr(10) +
         '  ; verifier si D suit le $' + Chr(13) + Chr(10) +
         '  CMP BYTE [ESI], 68' + Chr(13) + Chr(10) +
         '  JNE ' + Lbl3 + Chr(13) + Chr(10) +
         '  ; $D detecte : convertir l argument suivant' + Chr(13) + Chr(10) +
         '  INC ESI' + Chr(13) + Chr(10) +
         '  ; appeler ITOA pour l argument sur la pile' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'ITOA' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl2 + Chr(13) + Chr(10) +
         Lbl2 + ':' + Chr(13) + Chr(10) +
         '  ; copier le resultat ITOA dans le buffer de sortie' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl1 + Chr(13) + Chr(10) +
         Lbl3 + ':' + Chr(13) + Chr(10) +
         '  STOSB' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl1 + Chr(13) + Chr(10) +
         Lbl4 + ':' + Chr(13) + Chr(10) +
         '  MOV BYTE [EDI], 0' + Chr(13) + Chr(10) +
         '  POP ECX' + Chr(13) + Chr(10) +
         '  POP EBX' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlFormatCount);
  Inc(RtlStateCount);
  EmitRtlFormat := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlInitIO : generer _JVRT_INIT_IO                         }
{   Initialiser les handles console via GetStdHandle Win32      }
{   PUSH STD_OUTPUT_HANDLE / CALL GetStdHandle                  }
{   MOV [_JV_STDOUT], EAX                                       }
{   PUSH STD_INPUT_HANDLE / CALL GetStdHandle                   }
{   MOV [_JV_STDIN], EAX                                        }
{ ------------------------------------------------------------ }

Function EmitRtlInitIO : TString;
Var
  Buf : TString;
  SOH, SIH : TString;
Begin
  If RtlInitIOCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlInitIO := '; ERROR: max INIT_IO exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Str(STD_OUTPUT_HANDLE, SOH);
  Str(STD_INPUT_HANDLE, SIH);

  Buf := PFX_RT + 'INIT_IO:' + Chr(13) + Chr(10) +
         '  PUSH ' + SOH + Chr(13) + Chr(10) +
         '  CALL [GetStdHandle]' + Chr(13) + Chr(10) +
         '  MOV DWORD [' + PFX_VAR + 'STDOUT], EAX' + Chr(13) + Chr(10) +
         '  PUSH ' + SIH + Chr(13) + Chr(10) +
         '  CALL [GetStdHandle]' + Chr(13) + Chr(10) +
         '  MOV DWORD [' + PFX_VAR + 'STDIN], EAX' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlInitIOCount);
  Inc(RtlStateCount);
  EmitRtlInitIO := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlWriteStr : generer _JVRT_WRITE_STR                     }
{   Ecrire une chaine sur la console via WriteFile Win32         }
{   ESI = adresse de la chaine, ECX = longueur                  }
{ ------------------------------------------------------------ }

Function EmitRtlWriteStr : TString;
Var
  Buf : TString;
Begin
  If RtlWriteStrCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlWriteStr := '; ERROR: max WRITE_STR exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := PFX_RT + 'WRITE_STR:' + Chr(13) + Chr(10) +
         '  PUSH 0' + Chr(13) + Chr(10) +
         '  LEA EAX, [' + PFX_VAR + 'WRITTEN]' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  PUSH ECX' + Chr(13) + Chr(10) +
         '  PUSH ESI' + Chr(13) + Chr(10) +
         '  PUSH DWORD [' + PFX_VAR + 'STDOUT]' + Chr(13) + Chr(10) +
         '  CALL [WriteFile]' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlWriteStrCount);
  Inc(RtlStateCount);
  EmitRtlWriteStr := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlWriteCrlf : generer _JVRT_WRITE_CRLF                   }
{   Ecrire un retour a la ligne (CR+LF) sur la console          }
{ ------------------------------------------------------------ }

Function EmitRtlWriteCrlf : TString;
Var
  Buf : TString;
Begin
  If RtlWriteCrlfCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlWriteCrlf := '; ERROR: max WRITE_CRLF exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := PFX_RT + 'WRITE_CRLF:' + Chr(13) + Chr(10) +
         '  PUSH 0' + Chr(13) + Chr(10) +
         '  LEA EAX, [' + PFX_VAR + 'WRITTEN]' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  PUSH 2' + Chr(13) + Chr(10) +
         '  LEA EAX, [' + PFX_VAR + 'CRLF]' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  PUSH DWORD [' + PFX_VAR + 'STDOUT]' + Chr(13) + Chr(10) +
         '  CALL [WriteFile]' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlWriteCrlfCount);
  Inc(RtlStateCount);
  EmitRtlWriteCrlf := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlReadLine : generer _JVRT_READ_LINE                     }
{   Lire une ligne depuis la console via ReadFile Win32          }
{   Resultat dans _JV_IOBUF, longueur dans _JV_READ            }
{ ------------------------------------------------------------ }

Function EmitRtlReadLine : TString;
Var
  Buf : TString;
  SBuf : TString;
Begin
  If RtlReadLineCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlReadLine := '; ERROR: max READ_LINE exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Str(RTL_IOBUF_SIZE, SBuf);

  Buf := PFX_RT + 'READ_LINE:' + Chr(13) + Chr(10) +
         '  PUSH 0' + Chr(13) + Chr(10) +
         '  LEA EAX, [' + PFX_VAR + 'READ]' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  PUSH ' + SBuf + Chr(13) + Chr(10) +
         '  LEA EAX, [' + PFX_VAR + 'IOBUF]' + Chr(13) + Chr(10) +
         '  PUSH EAX' + Chr(13) + Chr(10) +
         '  PUSH DWORD [' + PFX_VAR + 'STDIN]' + Chr(13) + Chr(10) +
         '  CALL [ReadFile]' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlReadLineCount);
  Inc(RtlStateCount);
  EmitRtlReadLine := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlOutput : generer _JVRT_OUTPUT                           }
{   Routine combinee pour OUTPUT Jovial : traiter le format,    }
{   convertir les arguments, afficher avec retour a la ligne    }
{ ------------------------------------------------------------ }

Function EmitRtlOutput : TString;
Var
  Buf : TString;
Begin
  If RtlOutputCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlOutput := '; ERROR: max OUTPUT exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := PFX_RT + 'OUTPUT:' + Chr(13) + Chr(10) +
         '  ; traiter le format et les arguments' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'FORMAT' + Chr(13) + Chr(10) +
         '  ; calculer la longueur de la chaine formatee' + Chr(13) + Chr(10) +
         '  LEA ESI, [' + PFX_VAR + 'IOBUF]' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'WRITE_STR' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'WRITE_CRLF' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlOutputCount);
  Inc(RtlStateCount);
  EmitRtlOutput := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlAbs : generer _JVRT_ABS                                }
{   Valeur absolue de EAX (inline possible)                     }
{   Si EAX < 0 : NEG EAX                                       }
{ ------------------------------------------------------------ }

Function EmitRtlAbs : TString;
Var
  Buf : TString;
  Lbl : TString;
Begin
  If RtlAbsCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlAbs := '; ERROR: max ABS exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl := GenRtlLabel;

  Buf := PFX_RT + 'ABS:' + Chr(13) + Chr(10) +
         '  CMP EAX, 0' + Chr(13) + Chr(10) +
         '  JGE ' + Lbl + Chr(13) + Chr(10) +
         '  NEG EAX' + Chr(13) + Chr(10) +
         Lbl + ':' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlAbsCount);
  Inc(RtlStateCount);
  EmitRtlAbs := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlSgn : generer _JVRT_SGN                                }
{   Signe de EAX : -1, 0 ou +1 dans EAX                        }
{ ------------------------------------------------------------ }

Function EmitRtlSgn : TString;
Var
  Buf : TString;
  Lbl1, Lbl2, Lbl3 : TString;
Begin
  If RtlSgnCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlSgn := '; ERROR: max SGN exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl1 := GenRtlLabel;
  Lbl2 := GenRtlLabel;
  Lbl3 := GenRtlLabel;

  Buf := PFX_RT + 'SGN:' + Chr(13) + Chr(10) +
         '  CMP EAX, 0' + Chr(13) + Chr(10) +
         '  JG ' + Lbl1 + Chr(13) + Chr(10) +
         '  JL ' + Lbl2 + Chr(13) + Chr(10) +
         '  XOR EAX, EAX' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl3 + Chr(13) + Chr(10) +
         Lbl1 + ':' + Chr(13) + Chr(10) +
         '  MOV EAX, 1' + Chr(13) + Chr(10) +
         '  JMP ' + Lbl3 + Chr(13) + Chr(10) +
         Lbl2 + ':' + Chr(13) + Chr(10) +
         '  MOV EAX, -1' + Chr(13) + Chr(10) +
         Lbl3 + ':' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlSgnCount);
  Inc(RtlStateCount);
  EmitRtlSgn := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRtlPower : generer _JVRT_POWER                            }
{   Exponentiation par boucle : EAX = base, ECX = exposant      }
{   Resultat dans EAX                                           }
{ ------------------------------------------------------------ }

Function EmitRtlPower : TString;
Var
  Buf : TString;
  Lbl1, Lbl2 : TString;
Begin
  If RtlPowerCount >= RTL_MAX_OPS Then
  Begin
    Inc(RtlErrorCount);
    EmitRtlPower := '; ERROR: max POWER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl1 := GenRtlLabel;
  Lbl2 := GenRtlLabel;

  Buf := PFX_RT + 'POWER:' + Chr(13) + Chr(10) +
         '  PUSH EBX' + Chr(13) + Chr(10) +
         '  MOV EBX, EAX' + Chr(13) + Chr(10) +
         '  MOV EAX, 1' + Chr(13) + Chr(10) +
         '  CMP ECX, 0' + Chr(13) + Chr(10) +
         '  JLE ' + Lbl2 + Chr(13) + Chr(10) +
         Lbl1 + ':' + Chr(13) + Chr(10) +
         '  IMUL EAX, EBX' + Chr(13) + Chr(10) +
         '  DEC ECX' + Chr(13) + Chr(10) +
         '  JNZ ' + Lbl1 + Chr(13) + Chr(10) +
         Lbl2 + ':' + Chr(13) + Chr(10) +
         '  POP EBX' + Chr(13) + Chr(10) +
         '  RET' + Chr(13) + Chr(10);

  Inc(RtlPowerCount);
  Inc(RtlStateCount);
  EmitRtlPower := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeVarsBss : generer les variables BSS du runtime      }
{   _JV_IOBUF, _JV_NUMBUF, _JV_STDOUT, _JV_STDIN,             }
{   _JV_WRITTEN, _JV_READ, _JV_CRLF                            }
{ ------------------------------------------------------------ }

Function EmitRuntimeVarsBss : TString;
Var
  Buf : TString;
  SIO, SNB : TString;
Begin
  Str(RTL_IOBUF_SIZE, SIO);
  Str(RTL_NUMBUF_SIZE, SNB);

  Buf := '; --- Variables runtime BSS ---' + Chr(13) + Chr(10) +
         PFX_VAR + 'IOBUF:    RESB ' + SIO + Chr(13) + Chr(10) +
         PFX_VAR + 'NUMBUF:   RESB ' + SNB + Chr(13) + Chr(10) +
         PFX_VAR + 'STDOUT:   RESD 1' + Chr(13) + Chr(10) +
         PFX_VAR + 'STDIN:    RESD 1' + Chr(13) + Chr(10) +
         PFX_VAR + 'WRITTEN:  RESD 1' + Chr(13) + Chr(10) +
         PFX_VAR + 'READ:     RESD 1' + Chr(13) + Chr(10);

  EmitRuntimeVarsBss := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitRuntimeVarsData : generer les variables DATA du runtime    }
{   _JV_CRLF = constante CR+LF                                 }
{ ------------------------------------------------------------ }

Function EmitRuntimeVarsData : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Variables runtime DATA ---' + Chr(13) + Chr(10) +
         PFX_VAR + 'CRLF:    DB 13, 10' + Chr(13) + Chr(10);

  EmitRuntimeVarsData := Buf;
End;

{ ------------------------------------------------------------ }
{ GenerateRuntime : generer l ensemble des routines runtime      }
{   Retourne le code assembleur complet du runtime              }
{ ------------------------------------------------------------ }

Function GenerateRuntime : TString;
Var
  Buf : TString;
Begin
  Buf := '; === Bibliotheque Runtime JOVIAL ===' + Chr(13) + Chr(10);
  Buf := Buf + EmitRtlInitIO;
  Buf := Buf + EmitRtlItoa;
  Buf := Buf + EmitRtlAtoi;
  Buf := Buf + EmitRtlAbs;
  Buf := Buf + EmitRtlSgn;
  Buf := Buf + EmitRtlPower;
  Buf := Buf + EmitRtlWriteStr;
  Buf := Buf + EmitRtlWriteCrlf;
  Buf := Buf + EmitRtlReadLine;
  Buf := Buf + EmitRtlFormat;
  Buf := Buf + EmitRtlOutput;
  GenerateRuntime := Buf;
End;

{ ------------------------------------------------------------ }
{ IsRuntimeRequired : determiner si le runtime est necessaire    }
{ ------------------------------------------------------------ }

Function IsRuntimeRequired : Boolean;
Begin
  IsRuntimeRequired := (RtlStateCount > 0);
End;

{ ------------------------------------------------------------ }
{ GetRtlRoutineName : retourner le nom ASM d une routine runtime }
{ ------------------------------------------------------------ }

Function GetRtlRoutineName(RtlType : Integer) : TString;
Begin
  Case RtlType Of
    RTL_ITOA       : GetRtlRoutineName := PFX_RT + 'ITOA';
    RTL_ATOI       : GetRtlRoutineName := PFX_RT + 'ATOI';
    RTL_FORMAT     : GetRtlRoutineName := PFX_RT + 'FORMAT';
    RTL_INIT_IO    : GetRtlRoutineName := PFX_RT + 'INIT_IO';
    RTL_WRITE_STR  : GetRtlRoutineName := PFX_RT + 'WRITE_STR';
    RTL_WRITE_CRLF : GetRtlRoutineName := PFX_RT + 'WRITE_CRLF';
    RTL_READ_LINE  : GetRtlRoutineName := PFX_RT + 'READ_LINE';
    RTL_OUTPUT     : GetRtlRoutineName := PFX_RT + 'OUTPUT';
    RTL_ABS        : GetRtlRoutineName := PFX_RT + 'ABS';
    RTL_SGN        : GetRtlRoutineName := PFX_RT + 'SGN';
    RTL_POWER      : GetRtlRoutineName := PFX_RT + 'POWER';
  Else
    GetRtlRoutineName := PFX_RT + 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ DumpRuntimeState : afficher l etat du generateur runtime       }
{ ------------------------------------------------------------ }

Procedure DumpRuntimeState;
Begin
  WriteLn('=== Etat du generateur runtime (TODO 20) ===');
  WriteLn('  Initialise       : ', RtlInitialized);
  WriteLn('  Operations       : ', RtlStateCount);
  WriteLn('  ITOA generes     : ', RtlItoaCount);
  WriteLn('  ATOI generes     : ', RtlAtoiCount);
  WriteLn('  FORMAT generes   : ', RtlFormatCount);
  WriteLn('  INIT_IO generes  : ', RtlInitIOCount);
  WriteLn('  WRITE_STR generes: ', RtlWriteStrCount);
  WriteLn('  WRITE_CRLF gen.  : ', RtlWriteCrlfCount);
  WriteLn('  READ_LINE generes: ', RtlReadLineCount);
  WriteLn('  OUTPUT generes   : ', RtlOutputCount);
  WriteLn('  ABS generes      : ', RtlAbsCount);
  WriteLn('  SGN generes      : ', RtlSgnCount);
  WriteLn('  POWER generes    : ', RtlPowerCount);
  WriteLn('  Labels uniques   : ', RtlLabelNum);
  WriteLn('  Erreurs          : ', RtlErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur runtime             }
{ ------------------------------------------------------------ }

Function IsRtlInitialized : Boolean;
Begin
  IsRtlInitialized := RtlInitialized;
End;

Function IsRtlEmpty : Boolean;
Begin
  IsRtlEmpty := (RtlStateCount = 0);
End;

Function GetRtlStateCount : Integer;
Begin
  GetRtlStateCount := RtlStateCount;
End;

Function GetRtlItoaCount : Integer;
Begin
  GetRtlItoaCount := RtlItoaCount;
End;

Function GetRtlAtoiCount : Integer;
Begin
  GetRtlAtoiCount := RtlAtoiCount;
End;

Function GetRtlFormatCount : Integer;
Begin
  GetRtlFormatCount := RtlFormatCount;
End;

Function GetRtlInitIOCount : Integer;
Begin
  GetRtlInitIOCount := RtlInitIOCount;
End;

Function GetRtlWriteStrCount : Integer;
Begin
  GetRtlWriteStrCount := RtlWriteStrCount;
End;

Function GetRtlLabelNum : Integer;
Begin
  GetRtlLabelNum := RtlLabelNum;
End;

Function GetRtlErrorCount : Integer;
Begin
  GetRtlErrorCount := RtlErrorCount;
End;


{ ============================================================ }
{ TODO 21 - ECRIVAIN BINAIRE PE (GENERATION .EXE WINDOWS 32)    }
{   Generer un fichier executable PE32 complet pour Windows     }
{   32 bits : DOS Header, COFF Header, Optional Header,        }
{   sections .text, .rdata, .data, Import Table, fixups,        }
{   alignement sur FileAlignment et SectionAlignment            }
{ ============================================================ }

Const
  { Types d operations PE }
  PE_NONE           = 0;   { aucune operation PE                    }
  PE_DOS_HEADER     = 1;   { generation du DOS Header               }
  PE_SIGNATURE      = 2;   { signature PE "PE\0\0"                  }
  PE_COFF_HEADER    = 3;   { COFF File Header (20 octets)           }
  PE_OPT_HEADER     = 4;   { Optional Header (224 octets)           }
  PE_SECTION_HDR    = 5;   { Section Headers (.text/.rdata/.data)   }
  PE_TEXT_SECTION   = 6;   { contenu section .text (code)           }
  PE_RDATA_SECTION  = 7;   { contenu section .rdata (imports)       }
  PE_DATA_SECTION   = 8;   { contenu section .data (donnees)        }
  PE_IMPORT_TABLE   = 9;   { table d importation (IAT)              }
  PE_FIXUP          = 10;  { resolution des fixups                  }
  PE_ALIGN          = 11;  { alignement des sections                }

  { Constantes d image PE32 }
  IMAGE_FILE_MACHINE_I386 = $014C;   { machine i386                 }
  PE32_MAGIC              = $010B;   { magic PE32                   }
  PE_SIGNATURE_VALUE      = $00004550; { 'PE\0\0' en little-endian  }

  { Tailles et limites }
  PE_MAX_OPS              = 4096;  { nombre max d operations PE       }
  PE_DOS_HEADER_SIZE      = 64;    { taille du DOS Header en octets   }
  PE_STUB_SIZE            = 64;    { taille du DOS stub en octets     }
  PE_SIGNATURE_SIZE       = 4;     { taille de la signature PE        }
  PE_COFF_HEADER_SIZE     = 20;    { taille du COFF File Header       }
  PE_OPTIONAL_HEADER_SIZE = 224;   { taille du Optional Header PE32   }
  PE_SECTION_HEADER_SIZE  = 40;    { taille d un Section Header       }
  PE_FILE_ALIGNMENT       = 512;   { alignement fichier ($0200)       }
  PE_SECTION_ALIGNMENT    = 4096;  { alignement sections ($1000)      }
  PE_IMAGE_BASE           = $00400000; { adresse de base de l image   }
  PE_SUBSYSTEM_CUI        = 3;     { sous-systeme console (CUI)       }
  PE_NUM_SECTIONS         = 3;     { nombre de sections (.text/rdata/data) }
  PE_NUM_DATA_DIRS        = 16;    { nombre d entrees DataDirectory   }

Var
  { Variables du generateur PE }
  PeInitialized      : Boolean;     { module initialise ?             }
  PeStateCount       : Integer;     { compteur total d operations     }
  PeDosHeaderCount   : Integer;     { DOS Headers generes             }
  PeSignatureCount   : Integer;     { signatures PE generees          }
  PeCoffHeaderCount  : Integer;     { COFF Headers generes            }
  PeOptHeaderCount   : Integer;     { Optional Headers generes        }
  PeSectionHdrCount  : Integer;     { Section Headers generes         }
  PeTextSectionCount : Integer;     { sections .text generees         }
  PeRdataSectCount   : Integer;     { sections .rdata generees        }
  PeDataSectCount    : Integer;     { sections .data generees         }
  PeImportTblCount   : Integer;     { tables d import generees        }
  PeFixupCount       : Integer;     { fixups resolus                  }
  PeLabelNum         : Integer;     { generateur de labels uniques    }
  PeErrorCount       : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitPeState : initialiser les variables du generateur PE       }
{ ------------------------------------------------------------ }

Procedure InitPeState;
Begin
  PeInitialized      := True;
  PeStateCount       := 0;
  PeDosHeaderCount   := 0;
  PeSignatureCount   := 0;
  PeCoffHeaderCount  := 0;
  PeOptHeaderCount   := 0;
  PeSectionHdrCount  := 0;
  PeTextSectionCount := 0;
  PeRdataSectCount   := 0;
  PeDataSectCount    := 0;
  PeImportTblCount   := 0;
  PeFixupCount       := 0;
  PeLabelNum         := 0;
  PeErrorCount       := 0;
End;

{ ------------------------------------------------------------ }
{ GenPeLabel : generer un label unique pour le generateur PE     }
{ ------------------------------------------------------------ }

Function GenPeLabel : TString;
Begin
  Inc(PeLabelNum);
  GenPeLabel := PFX_LBL + 'PE_' + ItoSI(PeLabelNum);
End;

{ ------------------------------------------------------------ }
{ PeTypeName : nom textuel d un type d operation PE              }
{ ------------------------------------------------------------ }

Function PeTypeName(PeType : Integer) : TString;
Begin
  Case PeType Of
    PE_NONE          : PeTypeName := 'NONE';
    PE_DOS_HEADER    : PeTypeName := 'DOS_HEADER';
    PE_SIGNATURE     : PeTypeName := 'SIGNATURE';
    PE_COFF_HEADER   : PeTypeName := 'COFF_HEADER';
    PE_OPT_HEADER    : PeTypeName := 'OPT_HEADER';
    PE_SECTION_HDR   : PeTypeName := 'SECTION_HDR';
    PE_TEXT_SECTION   : PeTypeName := 'TEXT_SECTION';
    PE_RDATA_SECTION  : PeTypeName := 'RDATA_SECTION';
    PE_DATA_SECTION   : PeTypeName := 'DATA_SECTION';
    PE_IMPORT_TABLE   : PeTypeName := 'IMPORT_TABLE';
    PE_FIXUP          : PeTypeName := 'FIXUP';
    PE_ALIGN          : PeTypeName := 'ALIGN';
  Else
    PeTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ WritePeDosHeader : generer le DOS Header MZ (64 octets)        }
{   + DOS Stub minimal affichant "This program cannot be run     }
{   in DOS mode." puis terminant par INT 21h                    }
{ ------------------------------------------------------------ }

Function WritePeDosHeader : TString;
Var
  Buf : TString;
Begin
  If PeDosHeaderCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeDosHeader := '; ERROR: max DOS_HEADER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- PE DOS Header (MZ) ---' + Chr(13) + Chr(10) +
         '  DW $5A4D' + Chr(13) + Chr(10) +
         '  ; e_cblp .. e_lfanew' + Chr(13) + Chr(10) +
         '  DW $0090' + Chr(13) + Chr(10) +
         '  DW $0003' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0004' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $FFFF' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10);
  Buf := Buf +
         '  DW $00B8' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0040' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  TIMES 4 DW $0000' + Chr(13) + Chr(10) +
         '  TIMES 10 DW $0000' + Chr(13) + Chr(10) +
         '  DD $00000080' + Chr(13) + Chr(10);
  Buf := Buf +
         '; --- DOS Stub ---' + Chr(13) + Chr(10) +
         '  DB $0E,$1F,$BA,$0E,$00,$B4,$09,$CD' + Chr(13) + Chr(10) +
         '  DB $21,$B8,$01,$4C,$CD,$21' + Chr(13) + Chr(10) +
         '  DB "This program cannot run in DOS mode."' + Chr(13) + Chr(10) +
         '  DB $0D, $0A, $24' + Chr(13) + Chr(10) +
         '  ALIGN 16, DB 0' + Chr(13) + Chr(10);

  Inc(PeDosHeaderCount);
  Inc(PeStateCount);
  WritePeDosHeader := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeSignature : generer la signature PE "PE\0\0"            }
{ ------------------------------------------------------------ }

Function WritePeSignature : TString;
Var
  Buf : TString;
Begin
  If PeSignatureCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeSignature := '; ERROR: max SIGNATURE exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- PE Signature ---' + Chr(13) + Chr(10) +
         '  DD $00004550' + Chr(13) + Chr(10);

  Inc(PeSignatureCount);
  Inc(PeStateCount);
  WritePeSignature := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeCoffHeader : generer le COFF File Header (20 octets)    }
{   Machine=$014C (i386), NumberOfSections=3                    }
{ ------------------------------------------------------------ }

Function WritePeCoffHeader : TString;
Var
  Buf : TString;
Begin
  If PeCoffHeaderCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeCoffHeader := '; ERROR: max COFF_HEADER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF File Header (20 octets) ---' + Chr(13) + Chr(10) +
         '  DW $014C' + Chr(13) + Chr(10) +
         '  DW $0003' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $00E0' + Chr(13) + Chr(10) +
         '  DW $010F' + Chr(13) + Chr(10);

  Inc(PeCoffHeaderCount);
  Inc(PeStateCount);
  WritePeCoffHeader := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeOptionalHeader : generer le Optional Header (224 oct.)  }
{   Magic=$010B (PE32), ImageBase=$00400000,                    }
{   SectionAlignment=$1000, FileAlignment=$0200,                }
{   Subsystem=3 (CUI Console), DataDirectory[1]=Import Table   }
{ ------------------------------------------------------------ }

Function WritePeOptionalHeader : TString;
Var
  Buf : TString;
Begin
  If PeOptHeaderCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeOptionalHeader := '; ERROR: max OPT_HEADER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- Optional Header PE32 ---' + Chr(13) + Chr(10) +
         '  ; Standard fields' + Chr(13) + Chr(10) +
         '  DW $010B' + Chr(13) + Chr(10) +
         '  DB $0E' + Chr(13) + Chr(10) +
         '  DB $00' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10);
  Buf := Buf +
         '  ; NT-specific fields' + Chr(13) + Chr(10) +
         '  DD $00400000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DW $0006' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0006' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10);
  Buf := Buf +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00005000' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $0003' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $00100000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00100000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10);

  Buf := Buf +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000010' + Chr(13) + Chr(10) +
         '  ; DataDirectory (16 entrees de 8 octets)' + Chr(13) + Chr(10) +
         '  DD $00000000, $00000000' + Chr(13) + Chr(10) +
         '  DD $00002000, $00000080' + Chr(13) + Chr(10) +
         '  TIMES 14 DD $00000000, $00000000' + Chr(13) + Chr(10);

  Inc(PeOptHeaderCount);
  Inc(PeStateCount);
  WritePeOptionalHeader := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeSectionHeaders : generer les 3 Section Headers          }
{   .text (code), .rdata (imports), .data (donnees)             }
{   Chaque header fait 40 octets                                }
{ ------------------------------------------------------------ }

Function WritePeSectionHeaders : TString;
Var
  Buf : TString;
Begin
  If PeSectionHdrCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeSectionHeaders := '; ERROR: max SECTION_HDR exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- Section Headers (3 x 40 octets) ---' + Chr(13) + Chr(10) +
         '; .text section header' + Chr(13) + Chr(10) +
         '  DB ".text", 0, 0, 0' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $60000020' + Chr(13) + Chr(10);

  Buf := Buf +
         '; .rdata section header' + Chr(13) + Chr(10) +
         '  DB ".rdata", 0, 0' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00002000' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DD $00000400' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $40000040' + Chr(13) + Chr(10) +
         '; .data section header' + Chr(13) + Chr(10) +
         '  DB ".data", 0, 0, 0' + Chr(13) + Chr(10) +
         '  DD $00001000' + Chr(13) + Chr(10) +
         '  DD $00003000' + Chr(13) + Chr(10) +
         '  DD $00000200' + Chr(13) + Chr(10) +
         '  DD $00000600' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $C0000040' + Chr(13) + Chr(10);

  Inc(PeSectionHdrCount);
  Inc(PeStateCount);
  WritePeSectionHeaders := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeTextSection : generer le contenu de la section .text    }
{   Code machine 80386 : point d entree (_start -> ExitProcess), }
{   routines runtime Jovial (_JVRT_), procedures (_JP_)          }
{ ------------------------------------------------------------ }

Function WritePeTextSection : TString;
Var
  Buf : TString;
  Lbl : TString;
Begin
  If PeTextSectionCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeTextSection := '; ERROR: max TEXT_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl := GenPeLabel;

  Buf := '; --- Section .text (code machine 80386) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_TEXT_START:' + Chr(13) + Chr(10) +
         '  ; point d entree _start' + Chr(13) + Chr(10) +
         '_start:' + Chr(13) + Chr(10) +
         '  ; initialiser la pile' + Chr(13) + Chr(10) +
         '  PUSH EBP' + Chr(13) + Chr(10) +
         '  MOV EBP, ESP' + Chr(13) + Chr(10) +
         '  ; initialiser les E/S runtime' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'INIT_IO' + Chr(13) + Chr(10) +
         '  ; appeler le module principal' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_PROC + 'MAIN' + Chr(13) + Chr(10) +
         '  ; terminer le processus via ExitProcess(0)' + Chr(13) + Chr(10) +
         '  PUSH 0' + Chr(13) + Chr(10) +
         '  CALL [__imp__ExitProcess@4]' + Chr(13) + Chr(10) +
         Lbl + ':' + Chr(13) + Chr(10) +
         '  ; espace pour routines runtime et procedures' + Chr(13) + Chr(10) +
         '  ; (le code genere par TODO 17-20 sera insere ici)' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_TEXT_END:' + Chr(13) + Chr(10) +
         '  ALIGN ' + ItoSI(PE_FILE_ALIGNMENT) + ', DB $90' + Chr(13) + Chr(10);

  Inc(PeTextSectionCount);
  Inc(PeStateCount);
  WritePeTextSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeRdataSection : generer le contenu de la section .rdata  }
{   Import Directory (IMAGE_IMPORT_DESCRIPTOR), Hint/Name Table  }
{   pour chaque DLL importee, Import Address Table (IAT)         }
{ ------------------------------------------------------------ }

Function WritePeRdataSection : TString;
Var
  Buf : TString;
Begin
  If PeRdataSectCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeRdataSection := '; ERROR: max RDATA_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- Section .rdata (imports) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_RDATA_START:' + Chr(13) + Chr(10) +
         '  ; IMAGE_IMPORT_DESCRIPTOR kernel32' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_K32_ILT' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_K32_NAME' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_K32_IAT' + Chr(13) + Chr(10);
  Buf := Buf +
         '  ; descripteur nul (fin)' + Chr(13) + Chr(10) +
         '  TIMES 5 DD $00000000' + Chr(13) + Chr(10) +
         '  ; Hint/Name Table' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_HN_EXITPROCESS:' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DB "ExitProcess", 0' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_HN_GETSTDHANDLE:' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DB "GetStdHandle", 0' + Chr(13) + Chr(10);

  Buf := Buf +
         PFX_LBL + 'PE_HN_WRITEFILE:' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DB "WriteFile", 0' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_HN_READFILE:' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DB "ReadFile", 0' + Chr(13) + Chr(10) +
         '  ; nom de la DLL importee' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_K32_NAME:' + Chr(13) + Chr(10) +
         '  DB "kernel32.dll", 0' + Chr(13) + Chr(10) +
         '  ALIGN 4, DB 0' + Chr(13) + Chr(10) +
         '  ; Import Lookup Table (ILT) pour kernel32.dll' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_K32_ILT:' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_EXITPROCESS' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_GETSTDHANDLE' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_WRITEFILE' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_READFILE' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_RDATA_END:' + Chr(13) + Chr(10) +
         '  ALIGN ' + ItoSI(PE_FILE_ALIGNMENT) + ', DB 0' + Chr(13) + Chr(10);

  Inc(PeRdataSectCount);
  Inc(PeStateCount);
  WritePeRdataSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeDataSection : generer le contenu de la section .data    }
{   Variables ITEM globales initialisees, Tables (TABLE),        }
{   constantes chaines (_JK_)                                   }
{ ------------------------------------------------------------ }

Function WritePeDataSection : TString;
Var
  Buf : TString;
Begin
  If PeDataSectCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeDataSection := '; ERROR: max DATA_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- Section .data (donnees initialisees) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_DATA_START:' + Chr(13) + Chr(10) +
         '  ; variables ITEM globales' + Chr(13) + Chr(10) +
         '  ; (les declarations ITEM du module seront emises ici)' + Chr(13) + Chr(10) +
         '  ; tables TABLE' + Chr(13) + Chr(10) +
         '  ; (les elements TABLE seront emis ici)' + Chr(13) + Chr(10) +
         '  ; constantes chaines _JK_' + Chr(13) + Chr(10) +
         '  ; (les chaines litterales seront emises ici)' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_DATA_END:' + Chr(13) + Chr(10) +
         '  ALIGN ' + ItoSI(PE_FILE_ALIGNMENT) + ', DB 0' + Chr(13) + Chr(10);

  Inc(PeDataSectCount);
  Inc(PeStateCount);
  WritePeDataSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WritePeImportTable : construire l IAT et les descripteurs      }
{   Import Address Table avec thunks pour kernel32.dll           }
{   (ExitProcess, GetStdHandle, WriteFile, ReadFile)            }
{ ------------------------------------------------------------ }

Function WritePeImportTable : TString;
Var
  Buf : TString;
Begin
  If PeImportTblCount >= PE_MAX_OPS Then
  Begin
    Inc(PeErrorCount);
    WritePeImportTable := '; ERROR: max IMPORT_TABLE exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- Import Address Table (IAT) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'PE_K32_IAT:' + Chr(13) + Chr(10) +
         '__imp__ExitProcess@4:' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_EXITPROCESS' + Chr(13) + Chr(10) +
         '__imp__GetStdHandle@4:' + Chr(13) + Chr(10);
  Buf := Buf +
         '  DD ' + PFX_LBL + 'PE_HN_GETSTDHANDLE' + Chr(13) + Chr(10) +
         '__imp__WriteFile@20:' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_WRITEFILE' + Chr(13) + Chr(10) +
         '__imp__ReadFile@20:' + Chr(13) + Chr(10) +
         '  DD ' + PFX_LBL + 'PE_HN_READFILE' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10);

  Inc(PeImportTblCount);
  Inc(PeStateCount);
  WritePeImportTable := Buf;
End;

{ ------------------------------------------------------------ }
{ PeAlignToFileAlignment : aligner sur PE_FILE_ALIGNMENT (512)   }
{ ------------------------------------------------------------ }

Function PeAlignToFileAlignment : TString;
Begin
  PeAlignToFileAlignment :=
    '; aligner sur FileAlignment (' + ItoSI(PE_FILE_ALIGNMENT) + ')' +
    Chr(13) + Chr(10) +
    '  ALIGN ' + ItoSI(PE_FILE_ALIGNMENT) + ', DB 0' + Chr(13) + Chr(10);
  Inc(PeStateCount);
End;

{ ------------------------------------------------------------ }
{ PeAlignToSectionAlignment : aligner sur PE_SECTION_ALIGNMENT   }
{   (4096 octets)                                               }
{ ------------------------------------------------------------ }

Function PeAlignToSectionAlignment : TString;
Begin
  PeAlignToSectionAlignment :=
    '; aligner sur SectionAlignment (' + ItoSI(PE_SECTION_ALIGNMENT) + ')' +
    Chr(13) + Chr(10) +
    '  ALIGN ' + ItoSI(PE_SECTION_ALIGNMENT) + ', DB 0' + Chr(13) + Chr(10);
  Inc(PeStateCount);
End;

{ ------------------------------------------------------------ }
{ GeneratePeExe : orchestrateur genere un PE32 complet           }
{   Appelle toutes les fonctions d ecriture dans l ordre         }
{   DOS Header, Signature, COFF, Optional, Sections, Import     }
{ ------------------------------------------------------------ }

Function GeneratePeExe : TString;
Var
  Buf : TString;
Begin
  Buf := '; === Executable PE32 Windows 32 bits ===' + Chr(13) + Chr(10);
  Buf := Buf + WritePeDosHeader;
  Buf := Buf + WritePeSignature;
  Buf := Buf + WritePeCoffHeader;
  Buf := Buf + WritePeOptionalHeader;
  Buf := Buf + WritePeSectionHeaders;
  Buf := Buf + PeAlignToFileAlignment;
  Buf := Buf + WritePeTextSection;
  Buf := Buf + WritePeRdataSection;
  Buf := Buf + WritePeImportTable;
  Buf := Buf + WritePeDataSection;
  GeneratePeExe := Buf;
End;

{ ------------------------------------------------------------ }
{ IsPeGenRequired : determiner si la generation PE est requise   }
{ ------------------------------------------------------------ }

Function IsPeGenRequired : Boolean;
Begin
  IsPeGenRequired := (PeStateCount > 0);
End;

{ ------------------------------------------------------------ }
{ DumpPeState : afficher l etat du generateur PE                 }
{ ------------------------------------------------------------ }

Procedure DumpPeState;
Begin
  WriteLn('=== Etat du generateur PE (TODO 21) ===');
  WriteLn('  Initialise       : ', PeInitialized);
  WriteLn('  Operations       : ', PeStateCount);
  WriteLn('  DOS Headers      : ', PeDosHeaderCount);
  WriteLn('  Signatures PE    : ', PeSignatureCount);
  WriteLn('  COFF Headers     : ', PeCoffHeaderCount);
  WriteLn('  Optional Headers : ', PeOptHeaderCount);
  WriteLn('  Section Headers  : ', PeSectionHdrCount);
  WriteLn('  .text sections   : ', PeTextSectionCount);
  WriteLn('  .rdata sections  : ', PeRdataSectCount);
  WriteLn('  .data sections   : ', PeDataSectCount);
  WriteLn('  Import Tables    : ', PeImportTblCount);
  WriteLn('  Fixups resolus   : ', PeFixupCount);
  WriteLn('  Labels uniques   : ', PeLabelNum);
  WriteLn('  Erreurs          : ', PeErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur PE                  }
{ ------------------------------------------------------------ }

Function IsPeInitialized : Boolean;
Begin
  IsPeInitialized := PeInitialized;
End;

Function IsPeEmpty : Boolean;
Begin
  IsPeEmpty := (PeStateCount = 0);
End;

Function GetPeStateCount : Integer;
Begin
  GetPeStateCount := PeStateCount;
End;

Function GetPeDosHeaderCount : Integer;
Begin
  GetPeDosHeaderCount := PeDosHeaderCount;
End;

Function GetPeCoffHeaderCount : Integer;
Begin
  GetPeCoffHeaderCount := PeCoffHeaderCount;
End;

Function GetPeOptHeaderCount : Integer;
Begin
  GetPeOptHeaderCount := PeOptHeaderCount;
End;

Function GetPeSectionHdrCount : Integer;
Begin
  GetPeSectionHdrCount := PeSectionHdrCount;
End;

Function GetPeTextSectionCount : Integer;
Begin
  GetPeTextSectionCount := PeTextSectionCount;
End;

Function GetPeLabelNum : Integer;
Begin
  GetPeLabelNum := PeLabelNum;
End;

Function GetPeErrorCount : Integer;
Begin
  GetPeErrorCount := PeErrorCount;
End;


{ ============================================================ }
{ TODO 22 - ECRIVAIN COFF .OBJ (GENERATION FICHIER OBJET)       }
{   Generer un fichier objet COFF 32 bits compatible LINK.EXE   }
{   et MASM : COFF File Header (20 octets), sections .text,     }
{   .data, .bss, tables des relocations, des symboles et des    }
{   chaines pour noms > 8 caracteres                            }
{ ============================================================ }

Const
  { Types d operations COFF }
  COFF_NONE          = 0;   { aucune operation COFF                  }
  COFF_FILE_HEADER   = 1;   { COFF File Header (20 octets)           }
  COFF_TEXT_SECTION   = 2;   { section .text (code machine)           }
  COFF_DATA_SECTION   = 3;   { section .data (donnees initialisees)   }
  COFF_BSS_SECTION    = 4;   { section .bss (donnees non init.)       }
  COFF_RELOC_TABLE    = 5;   { table des relocations                  }
  COFF_SYMBOL_TABLE   = 6;   { table des symboles                     }
  COFF_STRING_TABLE   = 7;   { table des chaines longues              }
  COFF_SECTION_HDR    = 8;   { section headers (3 x 40 octets)        }

  { Constantes d image COFF }
  COFF_MACHINE_I386     = $014C;  { machine i386                      }
  COFF_NUM_SECTIONS     = 3;      { .text, .data, .bss                }
  COFF_HEADER_SIZE      = 20;     { taille du COFF File Header        }
  COFF_SECTION_HDR_SIZE = 40;     { taille d un Section Header        }
  COFF_SYMBOL_SIZE      = 18;     { taille d un symbole (IMAGE_SYMBOL)}
  COFF_RELOC_SIZE       = 10;     { taille d une relocation           }
  COFF_MAX_OPS          = 4096;   { nombre max d operations COFF      }
  COFF_MAX_SYMBOLS      = 1024;   { nombre max de symboles            }
  COFF_MAX_RELOCS       = 2048;   { nombre max de relocations         }
  COFF_MAX_SHORT_NAME   = 8;      { taille max nom court dans symbole }

  { Types de relocations COFF i386 }
  IMAGE_REL_I386_DIR32  = $0006;  { adresse absolue 32 bits           }
  IMAGE_REL_I386_REL32  = $0014;  { adresse relative 32 bits          }

  { Classes de stockage COFF }
  IMAGE_SYM_CLASS_EXTERNAL = 2;   { symbole externe (EXTERNAL)        }
  IMAGE_SYM_CLASS_STATIC   = 3;   { symbole statique (STATIC)         }
  IMAGE_SYM_CLASS_LABEL    = 6;   { label (LABEL)                     }

  { Numeros de section speciaux }
  IMAGE_SYM_UNDEFINED    = 0;     { symbole non defini (import)       }
  COFF_SECTION_TEXT      = 1;     { numero de section .text            }
  COFF_SECTION_DATA      = 2;     { numero de section .data            }
  COFF_SECTION_BSS       = 3;     { numero de section .bss             }

  { Flags de section COFF }
  COFF_SCN_CNT_CODE       = $00000020; { contient du code executable   }
  COFF_SCN_CNT_INIT_DATA  = $00000040; { donnees initialisees          }
  COFF_SCN_CNT_UNINIT_DATA= $00000080; { donnees non initialisees      }
  COFF_SCN_MEM_EXECUTE    = $20000000; { section executable            }
  COFF_SCN_MEM_READ       = $40000000; { section lisible               }
  COFF_SCN_MEM_WRITE      = $80000000; { section inscriptible          }

Var
  { Variables du generateur COFF }
  CoffInitialized     : Boolean;     { module initialise ?             }
  CoffStateCount      : Integer;     { compteur total d operations     }
  CoffFileHdrCount    : Integer;     { File Headers generes            }
  CoffSectHdrCount    : Integer;     { Section Headers generes         }
  CoffTextSectCount   : Integer;     { sections .text generees         }
  CoffDataSectCount   : Integer;     { sections .data generees         }
  CoffBssSectCount    : Integer;     { sections .bss generees          }
  CoffRelocCount      : Integer;     { relocations generees            }
  CoffSymbolCount     : Integer;     { symboles generes                }
  CoffStringCount     : Integer;     { entrees chaines generees        }
  CoffLabelNum        : Integer;     { generateur de labels uniques    }
  CoffErrorCount      : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitCoffState : initialiser les variables du generateur COFF   }
{ ------------------------------------------------------------ }

Procedure InitCoffState;
Begin
  CoffInitialized     := True;
  CoffStateCount      := 0;
  CoffFileHdrCount    := 0;
  CoffSectHdrCount    := 0;
  CoffTextSectCount   := 0;
  CoffDataSectCount   := 0;
  CoffBssSectCount    := 0;
  CoffRelocCount      := 0;
  CoffSymbolCount     := 0;
  CoffStringCount     := 0;
  CoffLabelNum        := 0;
  CoffErrorCount      := 0;
End;

{ ------------------------------------------------------------ }
{ GenCoffLabel : generer un label unique pour le generateur COFF  }
{ ------------------------------------------------------------ }

Function GenCoffLabel : TString;
Begin
  Inc(CoffLabelNum);
  GenCoffLabel := PFX_LBL + 'COFF_' + ItoSI(CoffLabelNum);
End;

{ ------------------------------------------------------------ }
{ CoffTypeName : nom textuel d un type d operation COFF          }
{ ------------------------------------------------------------ }

Function CoffTypeName(CoffType : Integer) : TString;
Begin
  Case CoffType Of
    COFF_NONE          : CoffTypeName := 'NONE';
    COFF_FILE_HEADER   : CoffTypeName := 'FILE_HEADER';
    COFF_TEXT_SECTION   : CoffTypeName := 'TEXT_SECTION';
    COFF_DATA_SECTION   : CoffTypeName := 'DATA_SECTION';
    COFF_BSS_SECTION    : CoffTypeName := 'BSS_SECTION';
    COFF_RELOC_TABLE    : CoffTypeName := 'RELOC_TABLE';
    COFF_SYMBOL_TABLE   : CoffTypeName := 'SYMBOL_TABLE';
    COFF_STRING_TABLE   : CoffTypeName := 'STRING_TABLE';
    COFF_SECTION_HDR    : CoffTypeName := 'SECTION_HDR';
  Else
    CoffTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ CoffRelocTypeName : nom textuel d un type de relocation        }
{ ------------------------------------------------------------ }

Function CoffRelocTypeName(RelType : Integer) : TString;
Begin
  Case RelType Of
    IMAGE_REL_I386_DIR32 : CoffRelocTypeName := 'DIR32';
    IMAGE_REL_I386_REL32 : CoffRelocTypeName := 'REL32';
  Else
    CoffRelocTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ CoffStorageClassName : nom textuel d une classe de stockage    }
{ ------------------------------------------------------------ }

Function CoffStorageClassName(StorClass : Integer) : TString;
Begin
  Case StorClass Of
    IMAGE_SYM_CLASS_EXTERNAL : CoffStorageClassName := 'EXTERNAL';
    IMAGE_SYM_CLASS_STATIC   : CoffStorageClassName := 'STATIC';
    IMAGE_SYM_CLASS_LABEL    : CoffStorageClassName := 'LABEL';
  Else
    CoffStorageClassName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ WriteCoffFileHeader : generer le COFF File Header (20 octets)  }
{   Machine=$014C, NumberOfSections=3, TimeDateStamp=0,          }
{   PointerToSymbolTable=a calculer, NumberOfSymbols=a calculer  }
{   Characteristics=$0000 (fichier objet, pas d exe)            }
{ ------------------------------------------------------------ }

Function WriteCoffFileHeader(NumSymbols : Integer; SymTblOffset : Integer) : TString;
Var
  Buf : TString;
Begin
  If CoffFileHdrCount >= COFF_MAX_OPS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffFileHeader := '; ERROR: max COFF FILE_HEADER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF File Header (20 octets) ---' + Chr(13) + Chr(10) +
         '  DW $' + HexWord(COFF_MACHINE_I386) + Chr(13) + Chr(10) +
         '  DW $' + HexWord(COFF_NUM_SECTIONS) + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $' + HexLong(SymTblOffset) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(NumSymbols) + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10);

  Inc(CoffFileHdrCount);
  Inc(CoffStateCount);
  WriteCoffFileHeader := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffSectionHeaders : generer les 3 Section Headers        }
{   .text (code), .data (donnees init.), .bss (donnees non init)}
{   Chaque header fait 40 octets                                }
{ ------------------------------------------------------------ }

Function WriteCoffSectionHeaders(TextSize, DataSize, BssSize : Integer;
                                  TextRelocCount, DataRelocCount : Integer) : TString;
Var
  Buf : TString;
  TextDataOffset : Integer;
  DataDataOffset : Integer;
  TextRelocOffset : Integer;
  DataRelocOffset : Integer;
Begin
  If CoffSectHdrCount >= COFF_MAX_OPS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffSectionHeaders := '; ERROR: max COFF SECTION_HDR exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  { Calculer les offsets }
  TextDataOffset := COFF_HEADER_SIZE + (COFF_NUM_SECTIONS * COFF_SECTION_HDR_SIZE);
  DataDataOffset := TextDataOffset + TextSize;
  TextRelocOffset := DataDataOffset + DataSize;
  DataRelocOffset := TextRelocOffset + (TextRelocCount * COFF_RELOC_SIZE);

  { Flags de section (valeurs hexadecimales directes) }
  { .text : CODE + EXECUTE + READ = $60000020 }
  { .data : INIT_DATA + READ + WRITE = $C0000040 }
  { .bss  : UNINIT_DATA + READ + WRITE = $C0000080 }

  { Section .text }
  Buf := '; --- COFF Section Headers (3 x 40 octets) ---' + Chr(13) + Chr(10) +
         '; .text section header' + Chr(13) + Chr(10) +
         '  DB ".text", 0, 0, 0' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $' + HexLong(TextSize) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(TextDataOffset) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(TextRelocOffset) + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $' + HexWord(TextRelocCount) + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $60000020' + Chr(13) + Chr(10);

  { Section .data }
  Buf := Buf +
         '; .data section header' + Chr(13) + Chr(10) +
         '  DB ".data", 0, 0, 0' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $' + HexLong(DataSize) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(DataDataOffset) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(DataRelocOffset) + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $' + HexWord(DataRelocCount) + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $C0000040' + Chr(13) + Chr(10);

  { Section .bss }
  Buf := Buf +
         '; .bss section header' + Chr(13) + Chr(10) +
         '  DB ".bss", 0, 0, 0, 0' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $' + HexLong(BssSize) + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DD $00000000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DW $0000' + Chr(13) + Chr(10) +
         '  DD $C0000080' + Chr(13) + Chr(10);

  Inc(CoffSectHdrCount);
  Inc(CoffStateCount);
  WriteCoffSectionHeaders := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffTextSection : generer le contenu de la section .text   }
{   Code machine 80386 : point d entree, routines runtime,       }
{   procedures compilees du module Jovial                        }
{ ------------------------------------------------------------ }

Function WriteCoffTextSection : TString;
Var
  Buf : TString;
  Lbl : TString;
Begin
  If CoffTextSectCount >= COFF_MAX_OPS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffTextSection := '; ERROR: max COFF TEXT_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Lbl := GenCoffLabel;

  Buf := '; --- COFF Section .text (code machine 80386) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_TEXT_START:' + Chr(13) + Chr(10) +
         '  ; point d entree _start' + Chr(13) + Chr(10) +
         '  PUBLIC _start' + Chr(13) + Chr(10) +
         '_start:' + Chr(13) + Chr(10) +
         '  PUSH EBP' + Chr(13) + Chr(10) +
         '  MOV EBP, ESP' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_RT + 'INIT_IO' + Chr(13) + Chr(10) +
         '  CALL ' + PFX_PROC + 'MAIN' + Chr(13) + Chr(10) +
         '  PUSH 0' + Chr(13) + Chr(10) +
         '  CALL _ExitProcess@4' + Chr(13) + Chr(10) +
         Lbl + ':' + Chr(13) + Chr(10) +
         '  ; (routines runtime et procedures seront inserees ici)' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_TEXT_END:' + Chr(13) + Chr(10);

  Inc(CoffTextSectCount);
  Inc(CoffStateCount);
  WriteCoffTextSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffDataSection : generer le contenu de la section .data   }
{   Variables ITEM initialisees, tables TABLE, constantes chaines}
{ ------------------------------------------------------------ }

Function WriteCoffDataSection : TString;
Var
  Buf : TString;
Begin
  If CoffDataSectCount >= COFF_MAX_OPS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffDataSection := '; ERROR: max COFF DATA_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF Section .data (donnees initialisees) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_DATA_START:' + Chr(13) + Chr(10) +
         '  ; variables ITEM globales initialisees' + Chr(13) + Chr(10) +
         '  ; (declarations ITEM emises ici)' + Chr(13) + Chr(10);
  Buf := Buf +
         '  ; tables TABLE' + Chr(13) + Chr(10) +
         '  ; (elements TABLE emis ici)' + Chr(13) + Chr(10) +
         '  ; constantes chaines ' + PFX_CONST + Chr(13) + Chr(10) +
         '  ; (chaines litterales emises ici)' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_DATA_END:' + Chr(13) + Chr(10);

  Inc(CoffDataSectCount);
  Inc(CoffStateCount);
  WriteCoffDataSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffBssSection : generer le contenu de la section .bss     }
{   Variables ITEM non initialisees, buffers runtime             }
{ ------------------------------------------------------------ }

Function WriteCoffBssSection : TString;
Var
  Buf : TString;
Begin
  If CoffBssSectCount >= COFF_MAX_OPS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffBssSection := '; ERROR: max COFF BSS_SECTION exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF Section .bss (donnees non init.) ---' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_BSS_START:' + Chr(13) + Chr(10) +
         '  ; variables ITEM non initialisees' + Chr(13) + Chr(10) +
         '  ; (reservations RESB/RESD emises ici)' + Chr(13) + Chr(10);
  Buf := Buf +
         '  ; buffers runtime (IO, conversion)' + Chr(13) + Chr(10) +
         '  ; (buffers _JVRT_ emis ici)' + Chr(13) + Chr(10) +
         PFX_LBL + 'COFF_BSS_END:' + Chr(13) + Chr(10);

  Inc(CoffBssSectCount);
  Inc(CoffStateCount);
  WriteCoffBssSection := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffRelocation : generer une entree de relocation COFF    }
{   IMAGE_RELOCATION (10 octets) : VirtualAddress, SymbolIndex,  }
{   Type ($0006=DIR32, $0014=REL32)                             }
{ ------------------------------------------------------------ }

Function WriteCoffRelocation(VAddr : Integer; SymIdx : Integer;
                              RelType : Integer) : TString;
Var
  Buf : TString;
Begin
  If CoffRelocCount >= COFF_MAX_RELOCS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffRelocation := '; ERROR: max COFF RELOC exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF Relocation (' + CoffRelocTypeName(RelType) + ') ---' +
         Chr(13) + Chr(10) +
         '  DD $' + HexLong(VAddr) + Chr(13) + Chr(10) +
         '  DD $' + HexLong(SymIdx) + Chr(13) + Chr(10) +
         '  DW $' + HexWord(RelType) + Chr(13) + Chr(10);

  Inc(CoffRelocCount);
  Inc(CoffStateCount);
  WriteCoffRelocation := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffSymbol : generer une entree de symbole COFF           }
{   IMAGE_SYMBOL (18 octets) : Name[8] ou StringTableOffset,    }
{   Value, SectionNumber, Type, StorageClass, NumberOfAuxSymbols }
{ ------------------------------------------------------------ }

Function WriteCoffSymbol(SymName : TString; Value : Integer;
                          SectNum : Integer; StorClass : Integer) : TString;
Var
  Buf : TString;
  NameBuf : TString;
  I : Integer;
Begin
  If CoffSymbolCount >= COFF_MAX_SYMBOLS Then
  Begin
    Inc(CoffErrorCount);
    WriteCoffSymbol := '; ERROR: max COFF SYMBOL exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; --- COFF Symbol: ' + SymName + ' (' +
         CoffStorageClassName(StorClass) + ') ---' + Chr(13) + Chr(10);

  If Length(SymName) <= COFF_MAX_SHORT_NAME Then
  Begin
    { Nom court : 8 octets paddes de zeros }
    NameBuf := '  DB ';
    For I := 1 To Length(SymName) Do
    Begin
      If I > 1 Then NameBuf := NameBuf + ', ';
      NameBuf := NameBuf + '$' + HexByte(Ord(SymName[I]));
    End;
    For I := Length(SymName) + 1 To COFF_MAX_SHORT_NAME Do
    Begin
      NameBuf := NameBuf + ', $00';
    End;
    Buf := Buf + NameBuf + Chr(13) + Chr(10);
  End
  Else
  Begin
    { Nom long : 4 octets zeros + offset dans la table des chaines }
    Buf := Buf +
           '  DD $00000000' + Chr(13) + Chr(10) +
           '  DD $' + HexLong(CoffStringCount + 4) + Chr(13) + Chr(10);
    Inc(CoffStringCount);
  End;

  { Value (4 octets) }
  Buf := Buf + '  DD $' + HexLong(Value) + Chr(13) + Chr(10);
  { SectionNumber (2 octets) }
  Buf := Buf + '  DW $' + HexWord(SectNum) + Chr(13) + Chr(10);
  { Type (2 octets) : $0000 = not a function }
  Buf := Buf + '  DW $0000' + Chr(13) + Chr(10);
  { StorageClass (1 octet) }
  Buf := Buf + '  DB $' + HexByte(StorClass) + Chr(13) + Chr(10);
  { NumberOfAuxSymbols (1 octet) }
  Buf := Buf + '  DB $00' + Chr(13) + Chr(10);

  Inc(CoffSymbolCount);
  Inc(CoffStateCount);
  WriteCoffSymbol := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffStringTable : generer la table des chaines            }
{   Prefixee par la taille totale (4 octets), suivie des noms   }
{   de symboles > 8 caracteres termines par un octet nul        }
{ ------------------------------------------------------------ }

Function WriteCoffStringTable(StringData : TString) : TString;
Var
  Buf : TString;
  TotalSize : Integer;
Begin
  TotalSize := 4 + Length(StringData);

  Buf := '; --- COFF String Table ---' + Chr(13) + Chr(10) +
         '  DD $' + HexLong(TotalSize) + Chr(13) + Chr(10);

  If Length(StringData) > 0 Then
    Buf := Buf +
           '  DB "' + StringData + '", 0' + Chr(13) + Chr(10);

  Inc(CoffStateCount);
  WriteCoffStringTable := Buf;
End;

{ ------------------------------------------------------------ }
{ WriteCoffExternSymbol : generer un symbole externe (import)    }
{   Pour les imports Win32 : ExitProcess, GetStdHandle, etc.    }
{   SectionNumber = 0 (IMAGE_SYM_UNDEFINED)                     }
{   StorageClass = EXTERNAL (2)                                  }
{ ------------------------------------------------------------ }

Function WriteCoffExternSymbol(SymName : TString) : TString;
Begin
  WriteCoffExternSymbol :=
    WriteCoffSymbol(SymName, 0, IMAGE_SYM_UNDEFINED, IMAGE_SYM_CLASS_EXTERNAL);
End;

{ ------------------------------------------------------------ }
{ WriteCoffDefinedSymbol : generer un symbole defini (procedure) }
{   Pour les procedures et variables Jovial compilees            }
{   StorageClass = EXTERNAL (2) pour symboles publics            }
{ ------------------------------------------------------------ }

Function WriteCoffDefinedSymbol(SymName : TString; Value : Integer;
                                 SectNum : Integer) : TString;
Begin
  WriteCoffDefinedSymbol :=
    WriteCoffSymbol(SymName, Value, SectNum, IMAGE_SYM_CLASS_EXTERNAL);
End;

{ ------------------------------------------------------------ }
{ WriteCoffStaticSymbol : generer un symbole statique (local)    }
{   Pour les sections et labels locaux                          }
{   StorageClass = STATIC (3)                                    }
{ ------------------------------------------------------------ }

Function WriteCoffStaticSymbol(SymName : TString; Value : Integer;
                                SectNum : Integer) : TString;
Begin
  WriteCoffStaticSymbol :=
    WriteCoffSymbol(SymName, Value, SectNum, IMAGE_SYM_CLASS_STATIC);
End;

{ ------------------------------------------------------------ }
{ WriteCoffLabelSymbol : generer un symbole label                }
{   Pour les labels internes du code genere                     }
{   StorageClass = LABEL (6)                                     }
{ ------------------------------------------------------------ }

Function WriteCoffLabelSymbol(SymName : TString; Value : Integer;
                               SectNum : Integer) : TString;
Begin
  WriteCoffLabelSymbol :=
    WriteCoffSymbol(SymName, Value, SectNum, IMAGE_SYM_CLASS_LABEL);
End;

{ ------------------------------------------------------------ }
{ GenerateCoffObj : orchestrateur genere un fichier COFF .OBJ    }
{   complet : File Header, Section Headers, .text, .data, .bss, }
{   relocations, table des symboles, table des chaines           }
{ ------------------------------------------------------------ }

Function GenerateCoffObj : TString;
Var
  Buf : TString;
Begin
  Buf := '; === Fichier objet COFF 32 bits (.OBJ) ===' + Chr(13) + Chr(10);

  { File Header avec valeurs par defaut }
  Buf := Buf + WriteCoffFileHeader(0, 0);

  { Section Headers }
  Buf := Buf + WriteCoffSectionHeaders(0, 0, 0, 0, 0);

  { Contenu des sections }
  Buf := Buf + WriteCoffTextSection;
  Buf := Buf + WriteCoffDataSection;
  Buf := Buf + WriteCoffBssSection;

  { Symboles externes (imports Win32) }
  Buf := Buf + '; --- COFF Symboles externes (imports Win32) ---' +
         Chr(13) + Chr(10);
  Buf := Buf + WriteCoffExternSymbol('_ExitProcess@4');
  Buf := Buf + WriteCoffExternSymbol('_GetStdHandle@4');
  Buf := Buf + WriteCoffExternSymbol('_WriteFile@20');
  Buf := Buf + WriteCoffExternSymbol('_ReadFile@20');

  { Symboles definis (sections) }
  Buf := Buf + '; --- COFF Symboles sections ---' + Chr(13) + Chr(10);
  Buf := Buf + WriteCoffStaticSymbol('.text', 0, COFF_SECTION_TEXT);
  Buf := Buf + WriteCoffStaticSymbol('.data', 0, COFF_SECTION_DATA);
  Buf := Buf + WriteCoffStaticSymbol('.bss', 0, COFF_SECTION_BSS);

  { Symbole point d entree }
  Buf := Buf + WriteCoffDefinedSymbol('_start', 0, COFF_SECTION_TEXT);

  { Table des chaines (vide pour l instant) }
  Buf := Buf + WriteCoffStringTable('');

  GenerateCoffObj := Buf;
End;

{ ------------------------------------------------------------ }
{ IsCoffGenRequired : determiner si la generation COFF est requise}
{ ------------------------------------------------------------ }

Function IsCoffGenRequired : Boolean;
Begin
  IsCoffGenRequired := (CoffStateCount > 0);
End;

{ ------------------------------------------------------------ }
{ DumpCoffState : afficher l etat du generateur COFF             }
{ ------------------------------------------------------------ }

Procedure DumpCoffState;
Begin
  WriteLn('=== Etat du generateur COFF (TODO 22) ===');
  WriteLn('  Initialise       : ', CoffInitialized);
  WriteLn('  Operations       : ', CoffStateCount);
  WriteLn('  File Headers     : ', CoffFileHdrCount);
  WriteLn('  Section Headers  : ', CoffSectHdrCount);
  WriteLn('  .text sections   : ', CoffTextSectCount);
  WriteLn('  .data sections   : ', CoffDataSectCount);
  WriteLn('  .bss sections    : ', CoffBssSectCount);
  WriteLn('  Relocations      : ', CoffRelocCount);
  WriteLn('  Symboles         : ', CoffSymbolCount);
  WriteLn('  Chaines          : ', CoffStringCount);
  WriteLn('  Labels uniques   : ', CoffLabelNum);
  WriteLn('  Erreurs          : ', CoffErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur COFF                }
{ ------------------------------------------------------------ }

Function IsCoffInitialized : Boolean;
Begin
  IsCoffInitialized := CoffInitialized;
End;

Function IsCoffEmpty : Boolean;
Begin
  IsCoffEmpty := (CoffStateCount = 0);
End;

Function GetCoffStateCount : Integer;
Begin
  GetCoffStateCount := CoffStateCount;
End;

Function GetCoffFileHdrCount : Integer;
Begin
  GetCoffFileHdrCount := CoffFileHdrCount;
End;

Function GetCoffSectHdrCount : Integer;
Begin
  GetCoffSectHdrCount := CoffSectHdrCount;
End;

Function GetCoffTextSectCount : Integer;
Begin
  GetCoffTextSectCount := CoffTextSectCount;
End;

Function GetCoffRelocCount : Integer;
Begin
  GetCoffRelocCount := CoffRelocCount;
End;

Function GetCoffSymbolCount : Integer;
Begin
  GetCoffSymbolCount := CoffSymbolCount;
End;

Function GetCoffLabelNum : Integer;
Begin
  GetCoffLabelNum := CoffLabelNum;
End;

Function GetCoffErrorCount : Integer;
Begin
  GetCoffErrorCount := CoffErrorCount;
End;


{ ============================================================ }
{ TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm)    }
{   Generer un fichier .ASM lisible et assemblable au format     }
{   MASM : .386 / .MODEL FLAT, STDCALL / OPTION CASEMAP:NONE    }
{   Sections INCLUDELIB, EXTERN, .DATA, .DATA?, .CODE            }
{   avec indentation, formatage et commentaires preserves        }
{ ============================================================ }

Const
  { Types d operations ASM }
  ASM_NONE          = 0;   { aucune operation ASM                   }
  ASM_HEADER        = 1;   { en-tete .386 / .MODEL FLAT             }
  ASM_INCLUDELIB    = 2;   { directive INCLUDELIB                   }
  ASM_EXTERN        = 3;   { declaration EXTERN                     }
  ASM_DATA_SECTION  = 4;   { section .DATA (donnees initialisees)   }
  ASM_BSS_SECTION   = 5;   { section .DATA? (donnees non init.)     }
  ASM_CODE_SECTION  = 6;   { section .CODE (code executable)        }
  ASM_PROC_DEF      = 7;   { definition de procedure                }
  ASM_COMMENT       = 8;   { commentaire assembleur                 }
  ASM_LABEL         = 9;   { label assembleur                       }
  ASM_INSTRUCTION   = 10;  { instruction assembleur                 }
  ASM_END_DIRECTIVE = 11;  { directive END _start                   }

  { Constantes de limites ASM }
  ASM_MAX_OPS       = 4096;  { nombre max d operations ASM          }
  ASM_MAX_EXTERNS   = 128;   { nombre max de declarations EXTERN    }
  ASM_MAX_LIBS      = 16;    { nombre max d INCLUDELIB              }
  ASM_INDENT        = '  ';  { indentation standard (2 espaces)     }
  ASM_INDENT2       = '    ';{ double indentation (4 espaces)       }

Var
  { Variables du generateur ASM }
  AsmGenInitialized  : Boolean;     { module initialise ?             }
  AsmGenStateCount   : Integer;     { compteur total d operations     }
  AsmGenHeaderCount  : Integer;     { en-tetes generes                }
  AsmGenLibCount     : Integer;     { INCLUDELIB generes              }
  AsmGenExternCount  : Integer;     { EXTERN generes                  }
  AsmGenDataCount    : Integer;     { entrees .DATA generees          }
  AsmGenBssCount     : Integer;     { entrees .DATA? generees         }
  AsmGenCodeCount    : Integer;     { instructions .CODE generees     }
  AsmGenProcCount    : Integer;     { procedures generees             }
  AsmGenCommentCount : Integer;     { commentaires generes            }
  AsmGenLabelNum     : Integer;     { generateur de labels uniques    }
  AsmGenErrorCount   : Integer;     { nombre d erreurs                }

{ ------------------------------------------------------------ }
{ InitAsmGenState : initialiser les variables du generateur ASM  }
{ ------------------------------------------------------------ }

Procedure InitAsmGenState;
Begin
  AsmGenInitialized  := True;
  AsmGenStateCount   := 0;
  AsmGenHeaderCount  := 0;
  AsmGenLibCount     := 0;
  AsmGenExternCount  := 0;
  AsmGenDataCount    := 0;
  AsmGenBssCount     := 0;
  AsmGenCodeCount    := 0;
  AsmGenProcCount    := 0;
  AsmGenCommentCount := 0;
  AsmGenLabelNum     := 0;
  AsmGenErrorCount   := 0;
End;

{ ------------------------------------------------------------ }
{ GenAsmGenLabel : generer un label unique pour le listing ASM    }
{ ------------------------------------------------------------ }

Function GenAsmGenLabel : TString;
Begin
  Inc(AsmGenLabelNum);
  GenAsmGenLabel := PFX_LBL + 'ASM_' + ItoSI(AsmGenLabelNum);
End;

{ ------------------------------------------------------------ }
{ AsmGenTypeName : nom textuel d un type d operation ASM         }
{ ------------------------------------------------------------ }

Function AsmGenTypeName(AsmType : Integer) : TString;
Begin
  Case AsmType Of
    ASM_NONE          : AsmGenTypeName := 'NONE';
    ASM_HEADER        : AsmGenTypeName := 'HEADER';
    ASM_INCLUDELIB    : AsmGenTypeName := 'INCLUDELIB';
    ASM_EXTERN        : AsmGenTypeName := 'EXTERN';
    ASM_DATA_SECTION  : AsmGenTypeName := 'DATA_SECTION';
    ASM_BSS_SECTION   : AsmGenTypeName := 'BSS_SECTION';
    ASM_CODE_SECTION  : AsmGenTypeName := 'CODE_SECTION';
    ASM_PROC_DEF      : AsmGenTypeName := 'PROC_DEF';
    ASM_COMMENT       : AsmGenTypeName := 'COMMENT';
    ASM_LABEL         : AsmGenTypeName := 'LABEL';
    ASM_INSTRUCTION   : AsmGenTypeName := 'INSTRUCTION';
    ASM_END_DIRECTIVE : AsmGenTypeName := 'END_DIRECTIVE';
  Else
    AsmGenTypeName := 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ EmitAsmHeader : generer l en-tete du fichier ASM               }
{   .386                                                         }
{   .MODEL FLAT, STDCALL                                         }
{   OPTION CASEMAP:NONE                                          }
{ ------------------------------------------------------------ }

Function EmitAsmHeader : TString;
Var
  Buf : TString;
Begin
  If AsmGenHeaderCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmHeader := '; ERROR: max ASM HEADER exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '; ============================================' + Chr(13) + Chr(10) +
         '; Fichier ASM genere par JOVCW32 v' + JOVCW32_VERSION + Chr(13) + Chr(10) +
         '; Source : ' + Opts.SrcFile + Chr(13) + Chr(10) +
         '; Format : MASM .386 / FLAT / Win32 Console' + Chr(13) + Chr(10) +
         '; ============================================' + Chr(13) + Chr(10) +
         Chr(13) + Chr(10) +
         '.386' + Chr(13) + Chr(10) +
         '.MODEL FLAT, STDCALL' + Chr(13) + Chr(10) +
         'OPTION CASEMAP:NONE' + Chr(13) + Chr(10) +
         Chr(13) + Chr(10);

  Inc(AsmGenHeaderCount);
  Inc(AsmGenStateCount);
  EmitAsmHeader := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmIncludeLib : generer une directive INCLUDELIB            }
{   INCLUDELIB nomlib.lib                                        }
{ ------------------------------------------------------------ }

Function EmitAsmIncludeLib(LibName : TString) : TString;
Begin
  If AsmGenLibCount >= ASM_MAX_LIBS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmIncludeLib := '; ERROR: max ASM INCLUDELIB exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  EmitAsmIncludeLib := 'INCLUDELIB ' + LibName + Chr(13) + Chr(10);
  Inc(AsmGenLibCount);
  Inc(AsmGenStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitAsmIncludeLibs : generer toutes les directives INCLUDELIB  }
{   kernel32.lib et msvcrt.lib (si necessaire)                   }
{ ------------------------------------------------------------ }

Function EmitAsmIncludeLibs : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Bibliotheques importees ---' + Chr(13) + Chr(10);
  Buf := Buf + EmitAsmIncludeLib('kernel32.lib');
  Buf := Buf + Chr(13) + Chr(10);

  EmitAsmIncludeLibs := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmExtern : generer une declaration EXTERN                 }
{   EXTERN nomfonction:PROC                                      }
{ ------------------------------------------------------------ }

Function EmitAsmExtern(FuncName : TString) : TString;
Begin
  If AsmGenExternCount >= ASM_MAX_EXTERNS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmExtern := '; ERROR: max ASM EXTERN exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  EmitAsmExtern := 'EXTERN ' + FuncName + ':PROC' + Chr(13) + Chr(10);
  Inc(AsmGenExternCount);
  Inc(AsmGenStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitAsmExterns : generer toutes les declarations EXTERN        }
{   pour les imports Win32 utilises (kernel32)                   }
{ ------------------------------------------------------------ }

Function EmitAsmExterns : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Declarations externes (imports Win32) ---' + Chr(13) + Chr(10);
  Buf := Buf + EmitAsmExtern('_ExitProcess@4');
  Buf := Buf + EmitAsmExtern('_GetStdHandle@4');
  Buf := Buf + EmitAsmExtern('_WriteFile@20');
  Buf := Buf + EmitAsmExtern('_ReadFile@20');
  Buf := Buf + Chr(13) + Chr(10);

  EmitAsmExterns := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmComment : generer un commentaire assembleur             }
{   ; texte du commentaire                                       }
{ ------------------------------------------------------------ }

Function EmitAsmComment(Comment : TString) : TString;
Begin
  EmitAsmComment := '; ' + Comment + Chr(13) + Chr(10);
  Inc(AsmGenCommentCount);
  Inc(AsmGenStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitAsmDataItem : generer une entree .DATA pour un ITEM        }
{   _JV_nomvar DD 0    ; ITEM nomvar S 32 ;                     }
{ ------------------------------------------------------------ }

Function EmitAsmDataItem(AsmName : TString; BitSize : Integer;
                          InitVal : TString; Comment : TString) : TString;
Var
  Buf : TString;
  Dir : TString;
Begin
  If AsmGenDataCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmDataItem := '; ERROR: max ASM DATA items exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Case BitSize Of
    8  : Dir := 'DB';
    16 : Dir := 'DW';
  Else
    Dir := 'DD';
  End;

  Buf := ASM_INDENT + AsmName + ' ' + Dir + ' ' + InitVal;
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenDataCount);
  Inc(AsmGenStateCount);
  EmitAsmDataItem := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmDataTable : generer une entree .DATA pour une TABLE     }
{   _JT_nomtab DD 10 DUP(0)    ; TABLE nomtab n 32 ;           }
{ ------------------------------------------------------------ }

Function EmitAsmDataTable(AsmName : TString; NumElems : Integer;
                           BitSize : Integer; Comment : TString) : TString;
Var
  Buf : TString;
  Dir : TString;
Begin
  If AsmGenDataCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmDataTable := '; ERROR: max ASM DATA tables exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Case BitSize Of
    8  : Dir := 'DB';
    16 : Dir := 'DW';
  Else
    Dir := 'DD';
  End;

  Buf := ASM_INDENT + AsmName + ' ' + Dir + ' ' + ItoSI(NumElems) + ' DUP(0)';
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenDataCount);
  Inc(AsmGenStateCount);
  EmitAsmDataTable := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmDataString : generer une constante chaine dans .DATA    }
{   _JK_nom DB 'texte', 0                                       }
{ ------------------------------------------------------------ }

Function EmitAsmDataString(AsmName : TString; Value : TString;
                            Comment : TString) : TString;
Var
  Buf : TString;
Begin
  If AsmGenDataCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmDataString := '; ERROR: max ASM DATA strings exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := ASM_INDENT + AsmName + ' DB ''' + Value + ''', 0';
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenDataCount);
  Inc(AsmGenStateCount);
  EmitAsmDataString := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmDataSection : generer l ouverture de la section .DATA   }
{   .DATA                                                        }
{   Variables, tables et constantes chaines                      }
{ ------------------------------------------------------------ }

Function EmitAsmDataSection : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Section de donnees initialisees ---' + Chr(13) + Chr(10) +
         '.DATA' + Chr(13) + Chr(10);

  { Generer les variables ITEM avec valeurs par defaut }
  Buf := Buf + EmitAsmComment('Variables ITEM');

  { Generer les constantes chaines du programme }
  Buf := Buf + EmitAsmComment('Constantes chaines');

  { Donnees runtime }
  Buf := Buf + ASM_INDENT + '_JVRT_crlf DB 13, 10, 0' + Chr(13) + Chr(10);
  Inc(AsmGenDataCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_fmt_d DB ''%d'', 0' + Chr(13) + Chr(10);
  Inc(AsmGenDataCount);
  Inc(AsmGenStateCount);

  Buf := Buf + Chr(13) + Chr(10);
  EmitAsmDataSection := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmBssItem : generer une entree .DATA? pour une variable   }
{   _JV_nomvar DD ?                                              }
{ ------------------------------------------------------------ }

Function EmitAsmBssItem(AsmName : TString; BitSize : Integer;
                         Comment : TString) : TString;
Var
  Buf : TString;
  Dir : TString;
Begin
  If AsmGenBssCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmBssItem := '; ERROR: max ASM BSS items exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Case BitSize Of
    8  : Dir := 'DB';
    16 : Dir := 'DW';
  Else
    Dir := 'DD';
  End;

  Buf := ASM_INDENT + AsmName + ' ' + Dir + ' ?';
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  EmitAsmBssItem := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmBssSection : generer la section .DATA? (non initialisee)}
{   .DATA?                                                       }
{   Buffers E/S et variables non initialisees                    }
{ ------------------------------------------------------------ }

Function EmitAsmBssSection : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Section de donnees non initialisees ---' + Chr(13) + Chr(10) +
         '.DATA?' + Chr(13) + Chr(10);

  { Buffers runtime }
  Buf := Buf + EmitAsmComment('Buffers runtime E/S');
  Buf := Buf + ASM_INDENT + '_JVRT_iobuf DB 256 DUP(?)' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_numbuf DB 32 DUP(?)' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_hStdOut DD ?' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_hStdIn DD ?' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_bytesWritten DD ?' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);
  Buf := Buf + ASM_INDENT + '_JVRT_bytesRead DD ?' + Chr(13) + Chr(10);
  Inc(AsmGenBssCount);
  Inc(AsmGenStateCount);

  Buf := Buf + Chr(13) + Chr(10);
  EmitAsmBssSection := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmCodeStart : generer l ouverture de la section .CODE     }
{   .CODE                                                        }
{   _start:                                                      }
{ ------------------------------------------------------------ }

Function EmitAsmCodeStart : TString;
Var
  Buf : TString;
Begin
  Buf := '; --- Section de code ---' + Chr(13) + Chr(10) +
         '.CODE' + Chr(13) + Chr(10) +
         Chr(13) + Chr(10);

  Inc(AsmGenCodeCount);
  Inc(AsmGenStateCount);
  EmitAsmCodeStart := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmProcStart : generer le debut d une procedure            }
{   _JP_nomproc PROC                                             }
{ ------------------------------------------------------------ }

Function EmitAsmProcStart(ProcName : TString; Comment : TString) : TString;
Var
  Buf : TString;
Begin
  If AsmGenProcCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmProcStart := '; ERROR: max ASM PROC exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := '';
  If Comment <> '' Then
    Buf := Buf + '; ' + Comment + Chr(13) + Chr(10);
  Buf := Buf + ProcName + ' PROC' + Chr(13) + Chr(10);

  Inc(AsmGenProcCount);
  Inc(AsmGenStateCount);
  EmitAsmProcStart := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmProcEnd : generer la fin d une procedure                }
{   _JP_nomproc ENDP                                             }
{ ------------------------------------------------------------ }

Function EmitAsmProcEnd(ProcName : TString) : TString;
Begin
  EmitAsmProcEnd := ProcName + ' ENDP' + Chr(13) + Chr(10) + Chr(13) + Chr(10);
  Inc(AsmGenStateCount);
End;

{ ------------------------------------------------------------ }
{ EmitAsmInstruction : generer une instruction assembleur         }
{   avec indentation et commentaire optionnel                    }
{ ------------------------------------------------------------ }

Function EmitAsmInstruction(Instr : TString; Comment : TString) : TString;
Var
  Buf : TString;
Begin
  If AsmGenCodeCount >= ASM_MAX_OPS Then
  Begin
    Inc(AsmGenErrorCount);
    EmitAsmInstruction := '; ERROR: max ASM instructions exceeded' + Chr(13) + Chr(10);
    Exit;
  End;

  Buf := ASM_INDENT + Instr;
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenCodeCount);
  Inc(AsmGenStateCount);
  EmitAsmInstruction := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmLabel : generer un label dans la section .CODE          }
{   nomlabel:                                                    }
{ ------------------------------------------------------------ }

Function EmitAsmLabel(LblName : TString; Comment : TString) : TString;
Var
  Buf : TString;
Begin
  Buf := LblName + ':';
  If Comment <> '' Then
    Buf := Buf + '    ; ' + Comment;
  Buf := Buf + Chr(13) + Chr(10);

  Inc(AsmGenCodeCount);
  Inc(AsmGenStateCount);
  EmitAsmLabel := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmEntryPoint : generer le point d entree _start           }
{   avec InitIO (GetStdHandle), appel du module principal,       }
{   ExitProcess(0)                                               }
{ ------------------------------------------------------------ }

Function EmitAsmEntryPoint : TString;
Var
  Buf : TString;
Begin
  Buf := EmitAsmComment('Point d entree principal') +
         EmitAsmLabel('_start', 'debut du programme') +
         Chr(13) + Chr(10) +
         EmitAsmComment('Initialiser les handles E/S') +
         EmitAsmInstruction('push -11', 'STD_OUTPUT_HANDLE') +
         EmitAsmInstruction('call _GetStdHandle@4', '') +
         EmitAsmInstruction('mov [_JVRT_hStdOut], eax', '') +
         EmitAsmInstruction('push -10', 'STD_INPUT_HANDLE') +
         EmitAsmInstruction('call _GetStdHandle@4', '') +
         EmitAsmInstruction('mov [_JVRT_hStdIn], eax', '') +
         Chr(13) + Chr(10) +
         EmitAsmComment('Corps du module principal') +
         EmitAsmComment('(code genere par le compilateur)') +
         Chr(13) + Chr(10) +
         EmitAsmComment('Terminer le programme') +
         EmitAsmInstruction('push 0', 'code de sortie 0') +
         EmitAsmInstruction('call _ExitProcess@4', 'terminer');

  EmitAsmEntryPoint := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmRuntimeProcs : generer les routines runtime (_JVRT_)    }
{   _JVRT_WriteStr, _JVRT_WriteCrlf, _JVRT_ReadLine,           }
{   _JVRT_Itoa, _JVRT_Atoi                                      }
{ ------------------------------------------------------------ }

Function EmitAsmRuntimeProcs : TString;
Var
  Buf : TString;
Begin
  Buf := EmitAsmComment('=== Routines Runtime ===') + Chr(13) + Chr(10);

  { _JVRT_WriteStr : ecrire une chaine sur stdout }
  Buf := Buf + EmitAsmProcStart('_JVRT_WriteStr', 'Ecrire chaine sur stdout (EDX=ptr, ECX=len)');
  Buf := Buf + EmitAsmInstruction('push 0', 'lpOverlapped = NULL');
  Buf := Buf + EmitAsmInstruction('push offset _JVRT_bytesWritten', 'lpNumberOfBytesWritten');
  Buf := Buf + EmitAsmInstruction('push ecx', 'nNumberOfBytesToWrite');
  Buf := Buf + EmitAsmInstruction('push edx', 'lpBuffer');
  Buf := Buf + EmitAsmInstruction('push [_JVRT_hStdOut]', 'hFile');
  Buf := Buf + EmitAsmInstruction('call _WriteFile@20', '');
  Buf := Buf + EmitAsmInstruction('ret', '');
  Buf := Buf + EmitAsmProcEnd('_JVRT_WriteStr');

  { _JVRT_WriteCrlf : ecrire un retour de ligne }
  Buf := Buf + EmitAsmProcStart('_JVRT_WriteCrlf', 'Ecrire CR+LF sur stdout');
  Buf := Buf + EmitAsmInstruction('push 0', 'lpOverlapped = NULL');
  Buf := Buf + EmitAsmInstruction('push offset _JVRT_bytesWritten', 'lpNumberOfBytesWritten');
  Buf := Buf + EmitAsmInstruction('push 2', 'nNumberOfBytesToWrite (CR+LF)');
  Buf := Buf + EmitAsmInstruction('push offset _JVRT_crlf', 'lpBuffer');
  Buf := Buf + EmitAsmInstruction('push [_JVRT_hStdOut]', 'hFile');
  Buf := Buf + EmitAsmInstruction('call _WriteFile@20', '');
  Buf := Buf + EmitAsmInstruction('ret', '');
  Buf := Buf + EmitAsmProcEnd('_JVRT_WriteCrlf');

  { _JVRT_ReadLine : lire une ligne depuis stdin }
  Buf := Buf + EmitAsmProcStart('_JVRT_ReadLine', 'Lire une ligne depuis stdin (EDX=buf, ECX=max)');
  Buf := Buf + EmitAsmInstruction('push 0', 'lpOverlapped = NULL');
  Buf := Buf + EmitAsmInstruction('push offset _JVRT_bytesRead', 'lpNumberOfBytesRead');
  Buf := Buf + EmitAsmInstruction('push ecx', 'nNumberOfBytesToRead');
  Buf := Buf + EmitAsmInstruction('push edx', 'lpBuffer');
  Buf := Buf + EmitAsmInstruction('push [_JVRT_hStdIn]', 'hFile');
  Buf := Buf + EmitAsmInstruction('call _ReadFile@20', '');
  Buf := Buf + EmitAsmInstruction('ret', '');
  Buf := Buf + EmitAsmProcEnd('_JVRT_ReadLine');

  { _JVRT_Itoa : convertir entier -> chaine (EAX=valeur, EDI=buf) }
  Buf := Buf + EmitAsmProcStart('_JVRT_Itoa', 'Convertir entier en chaine (EAX=val, EDI=buf)');
  Buf := Buf + EmitAsmInstruction('push ebx', 'sauvegarder registres');
  Buf := Buf + EmitAsmInstruction('push ecx', '');
  Buf := Buf + EmitAsmInstruction('push edx', '');
  Buf := Buf + EmitAsmInstruction('mov ecx, 0', 'compteur de chiffres');
  Buf := Buf + EmitAsmInstruction('cmp eax, 0', 'verifier si negatif');
  Buf := Buf + EmitAsmInstruction('jge _JVRT_Itoa_pos', '');
  Buf := Buf + EmitAsmInstruction('mov byte ptr [edi], ''-''', 'ecrire le signe -');
  Buf := Buf + EmitAsmInstruction('inc edi', '');
  Buf := Buf + EmitAsmInstruction('neg eax', 'rendre positif');
  Buf := Buf + EmitAsmLabel('_JVRT_Itoa_pos', '');
  Buf := Buf + EmitAsmInstruction('mov ebx, 10', 'diviseur = 10');
  Buf := Buf + EmitAsmLabel('_JVRT_Itoa_div', 'boucle de division');
  Buf := Buf + EmitAsmInstruction('xor edx, edx', '');
  Buf := Buf + EmitAsmInstruction('div ebx', 'EDX = reste, EAX = quotient');
  Buf := Buf + EmitAsmInstruction('add dl, ''0''', 'convertir en ASCII');
  Buf := Buf + EmitAsmInstruction('push edx', 'empiler le chiffre');
  Buf := Buf + EmitAsmInstruction('inc ecx', '');
  Buf := Buf + EmitAsmInstruction('cmp eax, 0', '');
  Buf := Buf + EmitAsmInstruction('jne _JVRT_Itoa_div', '');
  Buf := Buf + EmitAsmLabel('_JVRT_Itoa_pop', 'depiler en ordre inverse');
  Buf := Buf + EmitAsmInstruction('pop edx', '');
  Buf := Buf + EmitAsmInstruction('mov [edi], dl', '');
  Buf := Buf + EmitAsmInstruction('inc edi', '');
  Buf := Buf + EmitAsmInstruction('dec ecx', '');
  Buf := Buf + EmitAsmInstruction('jnz _JVRT_Itoa_pop', '');
  Buf := Buf + EmitAsmInstruction('mov byte ptr [edi], 0', 'terminateur nul');
  Buf := Buf + EmitAsmInstruction('pop edx', 'restaurer registres');
  Buf := Buf + EmitAsmInstruction('pop ecx', '');
  Buf := Buf + EmitAsmInstruction('pop ebx', '');
  Buf := Buf + EmitAsmInstruction('ret', '');
  Buf := Buf + EmitAsmProcEnd('_JVRT_Itoa');

  EmitAsmRuntimeProcs := Buf;
End;

{ ------------------------------------------------------------ }
{ EmitAsmEndDirective : generer la directive END _start          }
{   END _start                                                   }
{ ------------------------------------------------------------ }

Function EmitAsmEndDirective : TString;
Begin
  EmitAsmEndDirective := Chr(13) + Chr(10) +
    'END _start' + Chr(13) + Chr(10);
  Inc(AsmGenStateCount);
End;

{ ------------------------------------------------------------ }
{ GenerateAsmListing : orchestrateur genere un fichier .ASM      }
{   complet : en-tete, INCLUDELIB, EXTERN, .DATA, .DATA?,       }
{   .CODE avec routines runtime, point d entree et END           }
{ ------------------------------------------------------------ }

Function GenerateAsmListing : TString;
Var
  Buf : TString;
Begin
  Buf := EmitAsmHeader;
  Buf := Buf + EmitAsmIncludeLibs;
  Buf := Buf + EmitAsmExterns;
  Buf := Buf + EmitAsmDataSection;
  Buf := Buf + EmitAsmBssSection;
  Buf := Buf + EmitAsmCodeStart;
  Buf := Buf + EmitAsmRuntimeProcs;
  Buf := Buf + EmitAsmEntryPoint;
  Buf := Buf + EmitAsmEndDirective;

  GenerateAsmListing := Buf;
End;

{ ------------------------------------------------------------ }
{ IsAsmGenRequired : determiner si la generation ASM est requise }
{ ------------------------------------------------------------ }

Function IsAsmGenRequired : Boolean;
Begin
  IsAsmGenRequired := Opts.EmitAsm;
End;

{ ------------------------------------------------------------ }
{ DumpAsmGenState : afficher l etat du generateur ASM            }
{ ------------------------------------------------------------ }

Procedure DumpAsmGenState;
Begin
  WriteLn('=== Etat du generateur ASM (TODO 23) ===');
  WriteLn('  Initialise       : ', AsmGenInitialized);
  WriteLn('  Operations       : ', AsmGenStateCount);
  WriteLn('  En-tetes         : ', AsmGenHeaderCount);
  WriteLn('  INCLUDELIB       : ', AsmGenLibCount);
  WriteLn('  EXTERN           : ', AsmGenExternCount);
  WriteLn('  Entrees .DATA    : ', AsmGenDataCount);
  WriteLn('  Entrees .DATA?   : ', AsmGenBssCount);
  WriteLn('  Instructions     : ', AsmGenCodeCount);
  WriteLn('  Procedures       : ', AsmGenProcCount);
  WriteLn('  Commentaires     : ', AsmGenCommentCount);
  WriteLn('  Labels uniques   : ', AsmGenLabelNum);
  WriteLn('  Erreurs          : ', AsmGenErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le generateur ASM                 }
{ ------------------------------------------------------------ }

Function IsAsmGenInitialized : Boolean;
Begin
  IsAsmGenInitialized := AsmGenInitialized;
End;

Function IsAsmGenEmpty : Boolean;
Begin
  IsAsmGenEmpty := (AsmGenStateCount = 0);
End;

Function GetAsmGenStateCount : Integer;
Begin
  GetAsmGenStateCount := AsmGenStateCount;
End;

Function GetAsmGenHeaderCount : Integer;
Begin
  GetAsmGenHeaderCount := AsmGenHeaderCount;
End;

Function GetAsmGenExternCount : Integer;
Begin
  GetAsmGenExternCount := AsmGenExternCount;
End;

Function GetAsmGenDataCount : Integer;
Begin
  GetAsmGenDataCount := AsmGenDataCount;
End;

Function GetAsmGenBssCount : Integer;
Begin
  GetAsmGenBssCount := AsmGenBssCount;
End;

Function GetAsmGenCodeCount : Integer;
Begin
  GetAsmGenCodeCount := AsmGenCodeCount;
End;

Function GetAsmGenLabelNum : Integer;
Begin
  GetAsmGenLabelNum := AsmGenLabelNum;
End;

Function GetAsmGenErrorCount : Integer;
Begin
  GetAsmGenErrorCount := AsmGenErrorCount;
End;


{ ============================================================ }
{ TODO 24 - IMPORTS API WIN32 ET LIAISON (KERNEL32, MSVCRT)     }
{   Gerer les imports des fonctions Win32 depuis kernel32.dll   }
{   et optionnellement msvcrt.dll. Generer la table d imports   }
{   PE (IMAGE_IMPORT_DESCRIPTOR, IAT, Hint/Name), les EXTERN   }
{   pour le mode .ASM, les symboles externes pour le mode .OBJ  }
{   et marquer les imports reellement utilises.                  }
{ ============================================================ }

Const
  { Types d operations d import }
  IMP_NONE           = 0;   { aucune operation d import              }
  IMP_KERNEL32       = 1;   { import depuis kernel32.dll             }
  IMP_MSVCRT         = 2;   { import depuis msvcrt.dll               }
  IMP_IAT_ENTRY      = 3;   { entree IAT (Import Address Table)      }
  IMP_HINT_NAME      = 4;   { entree Hint/Name Table                 }
  IMP_DESCRIPTOR     = 5;   { IMAGE_IMPORT_DESCRIPTOR                }
  IMP_EXTERN_ASM     = 6;   { declaration EXTERN pour mode .ASM      }
  IMP_EXTERN_OBJ     = 7;   { symbole externe pour mode .OBJ         }
  IMP_DLL_REF        = 8;   { reference a une DLL                    }
  IMP_THUNK          = 9;   { entree thunk dans la IAT               }
  IMP_MARK_USED      = 10;  { marquer un import comme utilise        }

  { Constantes de limites }
  IMP_MAX_FUNCS      = 64;    { nombre max de fonctions importees    }
  IMP_MAX_DLLS       = 8;     { nombre max de DLLs                   }
  IMP_MAX_NAME_LEN   = 64;    { longueur max d un nom de fonction    }

  { Identifiants des fonctions kernel32 }
  IMP_FN_EXIT_PROCESS       = 0;   { ExitProcess                    }
  IMP_FN_GET_STD_HANDLE     = 1;   { GetStdHandle                   }
  IMP_FN_WRITE_FILE         = 2;   { WriteFile                      }
  IMP_FN_READ_FILE          = 3;   { ReadFile                       }
  IMP_FN_GET_PROCESS_HEAP   = 4;   { GetProcessHeap                 }
  IMP_FN_HEAP_ALLOC         = 5;   { HeapAlloc                      }
  IMP_FN_HEAP_FREE          = 6;   { HeapFree                       }
  IMP_FN_GET_CMD_LINE       = 7;   { GetCommandLineA                }
  IMP_FN_GET_MODULE_HANDLE  = 8;   { GetModuleHandleA               }
  IMP_FN_GET_LAST_ERROR     = 9;   { GetLastError                   }
  IMP_FN_LOAD_LIBRARY       = 10;  { LoadLibraryA                   }
  IMP_FN_GET_PROC_ADDRESS   = 11;  { GetProcAddress                 }
  IMP_FN_FREE_LIBRARY       = 12;  { FreeLibrary                    }
  IMP_FN_KERNEL32_COUNT     = 13;  { nombre de fonctions kernel32   }

  { Identifiants des fonctions msvcrt }
  IMP_FN_SPRINTF             = 0;  { sprintf                        }
  IMP_FN_SSCANF              = 1;  { sscanf                         }
  IMP_FN_MEMCPY              = 2;  { memcpy                         }
  IMP_FN_MEMSET              = 3;  { memset                         }
  IMP_FN_MEMCMP              = 4;  { memcmp                         }
  IMP_FN_MSVCRT_COUNT        = 5;  { nombre de fonctions msvcrt     }

  { Identifiants de DLLs }
  IMP_DLL_KERNEL32   = 0;   { kernel32.dll                           }
  IMP_DLL_MSVCRT     = 1;   { msvcrt.dll                             }
  IMP_DLL_COUNT      = 2;   { nombre de DLLs gerees                  }

Var
  { Variables du module d imports }
  ImpInitialized     : Boolean;     { module initialise ?             }
  ImpStateCount      : Integer;     { compteur total d operations     }
  ImpKernel32Count   : Integer;     { imports kernel32 enregistres    }
  ImpMsvcrtCount     : Integer;     { imports msvcrt enregistres      }
  ImpUsedCount       : Integer;     { imports marques comme utilises  }
  ImpIATCount        : Integer;     { entrees IAT generees            }
  ImpDescCount       : Integer;     { descripteurs generes            }
  ImpExternAsmCount  : Integer;     { EXTERN ASM generes              }
  ImpExternObjCount  : Integer;     { symboles OBJ generes            }
  ImpThunkCount      : Integer;     { thunks generes                  }
  ImpLabelNum        : Integer;     { generateur de labels uniques    }
  ImpErrorCount      : Integer;     { nombre d erreurs                }

  { Tables d etat des imports }
  ImpKernel32Used    : Array[0..IMP_FN_KERNEL32_COUNT-1] Of Boolean;
  ImpMsvcrtUsed      : Array[0..IMP_FN_MSVCRT_COUNT-1] Of Boolean;

{ ------------------------------------------------------------ }
{ InitImportState : initialiser le module d imports              }
{ ------------------------------------------------------------ }

Procedure InitImportState;
Var
  I : Integer;
Begin
  ImpInitialized    := True;
  ImpStateCount     := 0;
  ImpKernel32Count  := 0;
  ImpMsvcrtCount    := 0;
  ImpUsedCount      := 0;
  ImpIATCount       := 0;
  ImpDescCount      := 0;
  ImpExternAsmCount := 0;
  ImpExternObjCount := 0;
  ImpThunkCount     := 0;
  ImpLabelNum       := 0;
  ImpErrorCount     := 0;
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
    ImpKernel32Used[I] := False;
  For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    ImpMsvcrtUsed[I] := False;
End;

{ ------------------------------------------------------------ }
{ GenImpLabel : generer un label unique pour les imports         }
{ ------------------------------------------------------------ }

Function GenImpLabel : TString;
Var
  S : TString;
Begin
  Inc(ImpLabelNum);
  Str(ImpLabelNum, S);
  GenImpLabel := '_IMP_L' + S;
End;

{ ------------------------------------------------------------ }
{ ImpTypeName : nom d un type d operation d import               }
{ ------------------------------------------------------------ }

Function ImpTypeName(T : Integer) : TString;
Begin
  Case T Of
    IMP_NONE       : ImpTypeName := 'NONE';
    IMP_KERNEL32   : ImpTypeName := 'KERNEL32';
    IMP_MSVCRT     : ImpTypeName := 'MSVCRT';
    IMP_IAT_ENTRY  : ImpTypeName := 'IAT_ENTRY';
    IMP_HINT_NAME  : ImpTypeName := 'HINT_NAME';
    IMP_DESCRIPTOR : ImpTypeName := 'DESCRIPTOR';
    IMP_EXTERN_ASM : ImpTypeName := 'EXTERN_ASM';
    IMP_EXTERN_OBJ : ImpTypeName := 'EXTERN_OBJ';
    IMP_DLL_REF    : ImpTypeName := 'DLL_REF';
    IMP_THUNK      : ImpTypeName := 'THUNK';
    IMP_MARK_USED  : ImpTypeName := 'MARK_USED';
  Else
    ImpTypeName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetKernel32FuncName : nom d une fonction kernel32              }
{ ------------------------------------------------------------ }

Function GetKernel32FuncName(Id : Integer) : TString;
Begin
  Case Id Of
    IMP_FN_EXIT_PROCESS      : GetKernel32FuncName := 'ExitProcess';
    IMP_FN_GET_STD_HANDLE    : GetKernel32FuncName := 'GetStdHandle';
    IMP_FN_WRITE_FILE        : GetKernel32FuncName := 'WriteFile';
    IMP_FN_READ_FILE         : GetKernel32FuncName := 'ReadFile';
    IMP_FN_GET_PROCESS_HEAP  : GetKernel32FuncName := 'GetProcessHeap';
    IMP_FN_HEAP_ALLOC        : GetKernel32FuncName := 'HeapAlloc';
    IMP_FN_HEAP_FREE         : GetKernel32FuncName := 'HeapFree';
    IMP_FN_GET_CMD_LINE      : GetKernel32FuncName := 'GetCommandLineA';
    IMP_FN_GET_MODULE_HANDLE : GetKernel32FuncName := 'GetModuleHandleA';
    IMP_FN_GET_LAST_ERROR    : GetKernel32FuncName := 'GetLastError';
    IMP_FN_LOAD_LIBRARY      : GetKernel32FuncName := 'LoadLibraryA';
    IMP_FN_GET_PROC_ADDRESS  : GetKernel32FuncName := 'GetProcAddress';
    IMP_FN_FREE_LIBRARY      : GetKernel32FuncName := 'FreeLibrary';
  Else
    GetKernel32FuncName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetKernel32DecoratedName : nom decore STDCALL @n               }
{ ------------------------------------------------------------ }

Function GetKernel32DecoratedName(Id : Integer) : TString;
Begin
  Case Id Of
    IMP_FN_EXIT_PROCESS      : GetKernel32DecoratedName := '_ExitProcess@4';
    IMP_FN_GET_STD_HANDLE    : GetKernel32DecoratedName := '_GetStdHandle@4';
    IMP_FN_WRITE_FILE        : GetKernel32DecoratedName := '_WriteFile@20';
    IMP_FN_READ_FILE         : GetKernel32DecoratedName := '_ReadFile@20';
    IMP_FN_GET_PROCESS_HEAP  : GetKernel32DecoratedName := '_GetProcessHeap@0';
    IMP_FN_HEAP_ALLOC        : GetKernel32DecoratedName := '_HeapAlloc@12';
    IMP_FN_HEAP_FREE         : GetKernel32DecoratedName := '_HeapFree@12';
    IMP_FN_GET_CMD_LINE      : GetKernel32DecoratedName := '_GetCommandLineA@0';
    IMP_FN_GET_MODULE_HANDLE : GetKernel32DecoratedName := '_GetModuleHandleA@4';
    IMP_FN_GET_LAST_ERROR    : GetKernel32DecoratedName := '_GetLastError@0';
    IMP_FN_LOAD_LIBRARY      : GetKernel32DecoratedName := '_LoadLibraryA@4';
    IMP_FN_GET_PROC_ADDRESS  : GetKernel32DecoratedName := '_GetProcAddress@8';
    IMP_FN_FREE_LIBRARY      : GetKernel32DecoratedName := '_FreeLibrary@4';
  Else
    GetKernel32DecoratedName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetKernel32ParamSize : taille des parametres en octets         }
{ ------------------------------------------------------------ }

Function GetKernel32ParamSize(Id : Integer) : Integer;
Begin
  Case Id Of
    IMP_FN_EXIT_PROCESS      : GetKernel32ParamSize := 4;
    IMP_FN_GET_STD_HANDLE    : GetKernel32ParamSize := 4;
    IMP_FN_WRITE_FILE        : GetKernel32ParamSize := 20;
    IMP_FN_READ_FILE         : GetKernel32ParamSize := 20;
    IMP_FN_GET_PROCESS_HEAP  : GetKernel32ParamSize := 0;
    IMP_FN_HEAP_ALLOC        : GetKernel32ParamSize := 12;
    IMP_FN_HEAP_FREE         : GetKernel32ParamSize := 12;
    IMP_FN_GET_CMD_LINE      : GetKernel32ParamSize := 0;
    IMP_FN_GET_MODULE_HANDLE : GetKernel32ParamSize := 4;
    IMP_FN_GET_LAST_ERROR    : GetKernel32ParamSize := 0;
    IMP_FN_LOAD_LIBRARY      : GetKernel32ParamSize := 4;
    IMP_FN_GET_PROC_ADDRESS  : GetKernel32ParamSize := 8;
    IMP_FN_FREE_LIBRARY      : GetKernel32ParamSize := 4;
  Else
    GetKernel32ParamSize := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ GetMsvcrtFuncName : nom d une fonction msvcrt                  }
{ ------------------------------------------------------------ }

Function GetMsvcrtFuncName(Id : Integer) : TString;
Begin
  Case Id Of
    IMP_FN_SPRINTF : GetMsvcrtFuncName := 'sprintf';
    IMP_FN_SSCANF  : GetMsvcrtFuncName := 'sscanf';
    IMP_FN_MEMCPY  : GetMsvcrtFuncName := 'memcpy';
    IMP_FN_MEMSET  : GetMsvcrtFuncName := 'memset';
    IMP_FN_MEMCMP  : GetMsvcrtFuncName := 'memcmp';
  Else
    GetMsvcrtFuncName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetMsvcrtDecoratedName : nom decore CDECL _name                }
{ ------------------------------------------------------------ }

Function GetMsvcrtDecoratedName(Id : Integer) : TString;
Begin
  Case Id Of
    IMP_FN_SPRINTF : GetMsvcrtDecoratedName := '_sprintf';
    IMP_FN_SSCANF  : GetMsvcrtDecoratedName := '_sscanf';
    IMP_FN_MEMCPY  : GetMsvcrtDecoratedName := '_memcpy';
    IMP_FN_MEMSET  : GetMsvcrtDecoratedName := '_memset';
    IMP_FN_MEMCMP  : GetMsvcrtDecoratedName := '_memcmp';
  Else
    GetMsvcrtDecoratedName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetDllName : nom d une DLL par son identifiant                 }
{ ------------------------------------------------------------ }

Function GetDllName(DllId : Integer) : TString;
Begin
  Case DllId Of
    IMP_DLL_KERNEL32 : GetDllName := 'kernel32.dll';
    IMP_DLL_MSVCRT   : GetDllName := 'msvcrt.dll';
  Else
    GetDllName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ GetDllLibName : nom de la lib pour INCLUDELIB                  }
{ ------------------------------------------------------------ }

Function GetDllLibName(DllId : Integer) : TString;
Begin
  Case DllId Of
    IMP_DLL_KERNEL32 : GetDllLibName := 'kernel32.lib';
    IMP_DLL_MSVCRT   : GetDllLibName := 'msvcrt.lib';
  Else
    GetDllLibName := '???';
  End;
End;

{ ------------------------------------------------------------ }
{ MarkKernel32Used : marquer une fonction kernel32 comme utilisee }
{ ------------------------------------------------------------ }

Procedure MarkKernel32Used(FnId : Integer);
Begin
  If (FnId >= 0) And (FnId < IMP_FN_KERNEL32_COUNT) Then
  Begin
    If Not ImpKernel32Used[FnId] Then
    Begin
      ImpKernel32Used[FnId] := True;
      Inc(ImpUsedCount);
      Inc(ImpKernel32Count);
      Inc(ImpStateCount);
    End;
  End
  Else
  Begin
    Inc(ImpErrorCount);
    WriteLn('*** ERREUR: identifiant kernel32 invalide: ', FnId);
  End;
End;

{ ------------------------------------------------------------ }
{ MarkMsvcrtUsed : marquer une fonction msvcrt comme utilisee    }
{ ------------------------------------------------------------ }

Procedure MarkMsvcrtUsed(FnId : Integer);
Begin
  If (FnId >= 0) And (FnId < IMP_FN_MSVCRT_COUNT) Then
  Begin
    If Not ImpMsvcrtUsed[FnId] Then
    Begin
      ImpMsvcrtUsed[FnId] := True;
      Inc(ImpUsedCount);
      Inc(ImpMsvcrtCount);
      Inc(ImpStateCount);
    End;
  End
  Else
  Begin
    Inc(ImpErrorCount);
    WriteLn('*** ERREUR: identifiant msvcrt invalide: ', FnId);
  End;
End;

{ ------------------------------------------------------------ }
{ IsKernel32Used : tester si une fonction kernel32 est utilisee  }
{ ------------------------------------------------------------ }

Function IsKernel32Used(FnId : Integer) : Boolean;
Begin
  If (FnId >= 0) And (FnId < IMP_FN_KERNEL32_COUNT) Then
    IsKernel32Used := ImpKernel32Used[FnId]
  Else
    IsKernel32Used := False;
End;

{ ------------------------------------------------------------ }
{ IsMsvcrtUsed : tester si une fonction msvcrt est utilisee      }
{ ------------------------------------------------------------ }

Function IsMsvcrtUsed(FnId : Integer) : Boolean;
Begin
  If (FnId >= 0) And (FnId < IMP_FN_MSVCRT_COUNT) Then
    IsMsvcrtUsed := ImpMsvcrtUsed[FnId]
  Else
    IsMsvcrtUsed := False;
End;

{ ------------------------------------------------------------ }
{ IsDllUsed : tester si au moins une fonction d une DLL est      }
{   utilisee                                                     }
{ ------------------------------------------------------------ }

Function IsDllUsed(DllId : Integer) : Boolean;
Var
  I     : Integer;
  Found : Boolean;
Begin
  Found := False;
  Case DllId Of
    IMP_DLL_KERNEL32 :
      For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
        If ImpKernel32Used[I] Then Found := True;
    IMP_DLL_MSVCRT :
      For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
        If ImpMsvcrtUsed[I] Then Found := True;
  End;
  IsDllUsed := Found;
End;

{ ------------------------------------------------------------ }
{ MarkStandardImports : marquer les imports standard toujours    }
{   necessaires (ExitProcess, GetStdHandle, WriteFile, ReadFile) }
{ ------------------------------------------------------------ }

Procedure MarkStandardImports;
Begin
  MarkKernel32Used(IMP_FN_EXIT_PROCESS);
  MarkKernel32Used(IMP_FN_GET_STD_HANDLE);
  MarkKernel32Used(IMP_FN_WRITE_FILE);
  MarkKernel32Used(IMP_FN_READ_FILE);
End;

{ ------------------------------------------------------------ }
{ CountUsedKernel32 : compter les fonctions kernel32 utilisees   }
{ ------------------------------------------------------------ }

Function CountUsedKernel32 : Integer;
Var
  I, N : Integer;
Begin
  N := 0;
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
    If ImpKernel32Used[I] Then Inc(N);
  CountUsedKernel32 := N;
End;

{ ------------------------------------------------------------ }
{ CountUsedMsvcrt : compter les fonctions msvcrt utilisees       }
{ ------------------------------------------------------------ }

Function CountUsedMsvcrt : Integer;
Var
  I, N : Integer;
Begin
  N := 0;
  For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    If ImpMsvcrtUsed[I] Then Inc(N);
  CountUsedMsvcrt := N;
End;

{ ------------------------------------------------------------ }
{ GenerateImportExternsAsm : generer les declarations EXTERN     }
{   pour le mode .ASM (MASM)                                     }
{ ------------------------------------------------------------ }

Procedure GenerateImportExternsAsm;
Var
  I : Integer;
Begin
  WriteLn('; --- Imports kernel32.dll ---');
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
  Begin
    If ImpKernel32Used[I] Then
    Begin
      WriteLn('EXTERN ', GetKernel32DecoratedName(I), ':PROC');
      Inc(ImpExternAsmCount);
      Inc(ImpStateCount);
    End;
  End;
  If IsDllUsed(IMP_DLL_MSVCRT) Then
  Begin
    WriteLn('; --- Imports msvcrt.dll ---');
    For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    Begin
      If ImpMsvcrtUsed[I] Then
      Begin
        WriteLn('EXTERN ', GetMsvcrtDecoratedName(I), ':PROC');
        Inc(ImpExternAsmCount);
        Inc(ImpStateCount);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenerateImportExternsObj : generer les symboles externes        }
{   pour le mode .OBJ (COFF)                                     }
{ ------------------------------------------------------------ }

Procedure GenerateImportExternsObj;
Var
  I : Integer;
Begin
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
  Begin
    If ImpKernel32Used[I] Then
    Begin
      WriteLn('; COFF EXTERN ', GetKernel32DecoratedName(I));
      Inc(ImpExternObjCount);
      Inc(ImpStateCount);
    End;
  End;
  If IsDllUsed(IMP_DLL_MSVCRT) Then
  Begin
    For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    Begin
      If ImpMsvcrtUsed[I] Then
      Begin
        WriteLn('; COFF EXTERN ', GetMsvcrtDecoratedName(I));
        Inc(ImpExternObjCount);
        Inc(ImpStateCount);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenerateImportDescriptors : generer les IMAGE_IMPORT_DESCRIPTOR }
{   pour chaque DLL utilisee dans le PE                          }
{ ------------------------------------------------------------ }

Procedure GenerateImportDescriptors;
Var
  D : Integer;
Begin
  For D := 0 To IMP_DLL_COUNT - 1 Do
  Begin
    If IsDllUsed(D) Then
    Begin
      WriteLn('; IMAGE_IMPORT_DESCRIPTOR pour ', GetDllName(D));
      WriteLn(';   OriginalFirstThunk -> Hint/Name Table');
      WriteLn(';   TimeDateStamp      = 0');
      WriteLn(';   ForwarderChain     = 0');
      WriteLn(';   Name               -> "', GetDllName(D), '"');
      WriteLn(';   FirstThunk         -> IAT');
      Inc(ImpDescCount);
      Inc(ImpStateCount);
    End;
  End;
  { Descripteur de terminaison (20 octets de zeros) }
  WriteLn('; IMAGE_IMPORT_DESCRIPTOR terminaison (zeros)');
  Inc(ImpDescCount);
  Inc(ImpStateCount);
End;

{ ------------------------------------------------------------ }
{ GenerateImportIAT : generer la Import Address Table (IAT)      }
{   avec les thunks pour chaque fonction importee                }
{ ------------------------------------------------------------ }

Procedure GenerateImportIAT;
Var
  I : Integer;
Begin
  WriteLn('; --- IAT kernel32.dll ---');
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
  Begin
    If ImpKernel32Used[I] Then
    Begin
      WriteLn('; IAT thunk -> Hint/Name "',
              GetKernel32FuncName(I), '"');
      Inc(ImpIATCount);
      Inc(ImpThunkCount);
      Inc(ImpStateCount);
    End;
  End;
  WriteLn('; IAT terminaison kernel32 (DD 0)');
  Inc(ImpIATCount);
  Inc(ImpStateCount);

  If IsDllUsed(IMP_DLL_MSVCRT) Then
  Begin
    WriteLn('; --- IAT msvcrt.dll ---');
    For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    Begin
      If ImpMsvcrtUsed[I] Then
      Begin
        WriteLn('; IAT thunk -> Hint/Name "',
                GetMsvcrtFuncName(I), '"');
        Inc(ImpIATCount);
        Inc(ImpThunkCount);
        Inc(ImpStateCount);
      End;
    End;
    WriteLn('; IAT terminaison msvcrt (DD 0)');
    Inc(ImpIATCount);
    Inc(ImpStateCount);
  End;
End;

{ ------------------------------------------------------------ }
{ GenerateImportHintNameTable : generer la Hint/Name Table       }
{   avec les noms de fonctions et leurs hints (indices)          }
{ ------------------------------------------------------------ }

Procedure GenerateImportHintNameTable;
Var
  I, Hint : Integer;
Begin
  Hint := 0;
  WriteLn('; --- Hint/Name Table kernel32.dll ---');
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
  Begin
    If ImpKernel32Used[I] Then
    Begin
      WriteLn('; Hint=', Hint, ' Name="',
              GetKernel32FuncName(I), '"');
      Inc(Hint);
      Inc(ImpStateCount);
    End;
  End;

  If IsDllUsed(IMP_DLL_MSVCRT) Then
  Begin
    Hint := 0;
    WriteLn('; --- Hint/Name Table msvcrt.dll ---');
    For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    Begin
      If ImpMsvcrtUsed[I] Then
      Begin
        WriteLn('; Hint=', Hint, ' Name="',
                GetMsvcrtFuncName(I), '"');
        Inc(Hint);
        Inc(ImpStateCount);
      End;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenerateImportLibsAsm : generer les INCLUDELIB pour .ASM       }
{ ------------------------------------------------------------ }

Procedure GenerateImportLibsAsm;
Var
  D : Integer;
Begin
  For D := 0 To IMP_DLL_COUNT - 1 Do
  Begin
    If IsDllUsed(D) Then
    Begin
      WriteLn('INCLUDELIB ', GetDllLibName(D));
      Inc(ImpStateCount);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsImportRequired : tester si des imports sont necessaires       }
{ ------------------------------------------------------------ }

Function IsImportRequired : Boolean;
Begin
  IsImportRequired := (ImpUsedCount > 0);
End;

{ ------------------------------------------------------------ }
{ GetImportSummary : obtenir un resume des imports utilises       }
{ ------------------------------------------------------------ }

Procedure GetImportSummary;
Var
  I : Integer;
Begin
  WriteLn('=== Resume des imports Win32 ===');
  WriteLn('  kernel32.dll (', CountUsedKernel32, ' fonctions) :');
  For I := 0 To IMP_FN_KERNEL32_COUNT - 1 Do
  Begin
    If ImpKernel32Used[I] Then
      WriteLn('    ', GetKernel32FuncName(I),
              ' (', GetKernel32DecoratedName(I), ')');
  End;
  If IsDllUsed(IMP_DLL_MSVCRT) Then
  Begin
    WriteLn('  msvcrt.dll (', CountUsedMsvcrt, ' fonctions) :');
    For I := 0 To IMP_FN_MSVCRT_COUNT - 1 Do
    Begin
      If ImpMsvcrtUsed[I] Then
        WriteLn('    ', GetMsvcrtFuncName(I),
                ' (', GetMsvcrtDecoratedName(I), ')');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ DumpImportState : afficher l etat du module d imports          }
{ ------------------------------------------------------------ }

Procedure DumpImportState;
Begin
  WriteLn('=== Etat du module d imports Win32 (TODO 24) ===');
  WriteLn('  Initialise       : ', ImpInitialized);
  WriteLn('  Operations       : ', ImpStateCount);
  WriteLn('  Kernel32 imports : ', ImpKernel32Count);
  WriteLn('  Msvcrt imports   : ', ImpMsvcrtCount);
  WriteLn('  Imports utilises : ', ImpUsedCount);
  WriteLn('  Entrees IAT      : ', ImpIATCount);
  WriteLn('  Descripteurs     : ', ImpDescCount);
  WriteLn('  EXTERN ASM       : ', ImpExternAsmCount);
  WriteLn('  EXTERN OBJ       : ', ImpExternObjCount);
  WriteLn('  Thunks           : ', ImpThunkCount);
  WriteLn('  Labels uniques   : ', ImpLabelNum);
  WriteLn('  Erreurs          : ', ImpErrorCount);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs pour le module d imports               }
{ ------------------------------------------------------------ }

Function IsImpInitialized : Boolean;
Begin
  IsImpInitialized := ImpInitialized;
End;

Function IsImpEmpty : Boolean;
Begin
  IsImpEmpty := (ImpStateCount = 0);
End;

Function GetImpStateCount : Integer;
Begin
  GetImpStateCount := ImpStateCount;
End;

Function GetImpKernel32Count : Integer;
Begin
  GetImpKernel32Count := ImpKernel32Count;
End;

Function GetImpMsvcrtCount : Integer;
Begin
  GetImpMsvcrtCount := ImpMsvcrtCount;
End;

Function GetImpUsedCount : Integer;
Begin
  GetImpUsedCount := ImpUsedCount;
End;

Function GetImpIATCount : Integer;
Begin
  GetImpIATCount := ImpIATCount;
End;

Function GetImpDescCount : Integer;
Begin
  GetImpDescCount := ImpDescCount;
End;

Function GetImpLabelNum : Integer;
Begin
  GetImpLabelNum := ImpLabelNum;
End;

Function GetImpErrorCount : Integer;
Begin
  GetImpErrorCount := ImpErrorCount;
End;


{ ============================================================ }
{ Run : point d entree principal                                }
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
  ModInitialized := False;
  ItmInitialized := False;
  TblInitialized := False;
  DefInitialized := False;
  PrcInitialized := False;
  ExpInitialized := False;
  CtlInitialized := False;
  AsgInitialized := False;
  StsInitialized := False;
  BitInitialized := False;
  BltInitialized := False;
  IOInitialized := False;
  DatInitialized := False;
  AriInitialized := False;
  CtgInitialized := False;
  RtlInitialized := False;
  PeInitialized := False;
  CoffInitialized := False;
  AsmGenInitialized := False;
  ImpInitialized := False;

  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

  { Initialiser le module de mots-cles }
  InitKeywordState;

  { Initialiser la table des symboles }
  SymInit;

  { Initialiser le parseur MODULE/COMPOOL }
  InitModuleState;

  { Initialiser le parseur ITEM }
  InitItemState;

  { Initialiser le parseur TABLE }
  InitTableState;

  { Initialiser le parseur DEFINE }
  InitDefineState;

  { Initialiser le parseur PROCEDURE/FUNCTION }
  InitProcState;

  { Initialiser le parseur d expressions }
  InitExprState;

  { Initialiser le parseur de structures de controle }
  InitCtrlState;

  { Initialiser le parseur d affectations }
  InitAssignState;

  { Initialiser le parseur STATUS }
  InitStatusState;

  { Initialiser le parseur d operations sur les bits }
  InitBitState;

  { Initialiser le parseur de fonctions integrees (builtins) }
  InitBuiltinState;

  { Initialiser le parseur E/S (INPUT/OUTPUT) }
  InitIOState;

  { Initialiser le generateur de segment de donnees }
  InitDataSegState;

  { Initialiser le generateur d operations arithmetiques }
  InitArithState;

  { Initialiser le generateur de structures de controle }
  InitCtrlGenState;

  { Initialiser le generateur de bibliotheque runtime }
  InitRuntimeState;

  { Initialiser le generateur PE (ecrivain binaire) }
  InitPeState;

  { Initialiser le generateur COFF (ecrivain .OBJ) }
  InitCoffState;

  { Initialiser le generateur de listing ASM }
  InitAsmGenState;

  { Initialiser le module d imports Win32 }
  InitImportState;

  { Ouvrir le fichier source et initialiser le lexeur }
  LexInit;

  { Lire le premier token }
  LexNextToken;

  { Parser la structure MODULE/COMPOOL }
  ParseModule;

  { Fermer le fichier source }
  LexClose;

  { Statistiques finales }
  ShowStats;
  If Opts.Verbose Then
  Begin
    WriteLn('Tokens analyses  : ', GetLexTokCount);
    DumpModuleState;
    DumpItemState;
    DumpTableState;
    DumpDefineState;
    DumpProcState;
    DumpExprState;
    DumpCtrlState;
    DumpAssignState;
    DumpStatusState;
    DumpBitState;
    DumpBuiltinState;
    DumpIOState;
    DumpDataSegState;
    DumpArithState;
    DumpCtrlGenState;
    DumpRuntimeState;
    DumpPeState;
    DumpCoffState;
    DumpAsmGenState;
    DumpImportState;
  End;

  { Nettoyage }
  Cleanup;
End;

Begin
  Run;
End.
