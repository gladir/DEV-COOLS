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

  TODO 14 - PARSEUR : OPERATIONS SUR LES BITS [A FAIRE]
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

  TODO 15 - PARSEUR : FONCTIONS INTEGREES JOVIAL (BUILTINS) [A FAIRE]
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

  TODO 16 - PARSEUR : INPUT/OUTPUT (E/S CONSOLE) [A FAIRE]
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

  TODO 17 - GENERATION DE CODE : SEGMENT DE DONNEES 80386 [A FAIRE]
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
      KW_UBOUND, KW_LBOUND, KW_FIRST, KW_LAST, KW_NEXT:
      Begin
        { Appel de fonction integree }
        NodeType := EXP_CALL;
        Inc(ExpNodeCount);
        Inc(ExpCallCount);
        LexNextToken;
        { Parser les arguments entre parentheses }
        If CurTokType = TOK_LPAREN Then
        Begin
          LexNextToken;
          ArgCount := 0;
          If CurTokType <> TOK_RPAREN Then
          Begin
            ParseExpression;
            Inc(ArgCount);
            While CurTokType = TOK_COMMA Do
            Begin
              LexNextToken;
              ParseExpression;
              Inc(ArgCount);
            End;
          End;
          If CurTokType = TOK_RPAREN Then
            LexNextToken
          Else
          Begin
            WarnMsg('Parenthese fermante attendue apres arguments');
            Inc(ExpErrorCount);
          End;
        End;
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
  End;

  { Nettoyage }
  Cleanup;
End;

Begin
  Run;
End.
