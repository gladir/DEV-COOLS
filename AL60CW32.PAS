{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 60 vers assembleur 80386, 32 bits, pour
    Windows 32 bits
}

(* ============================================================
  AL60CW32.PAS - Compilateur Algol 60 vers assembleur 80386
    pour Windows 32 bits
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32 (console)

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un listing .ASM lisible
    (la production du .ASM est optionnelle et jamais implicite).
  Supporte toutes les exemples SAMPLES\ALGOL60\*.a60

  Reference : DOC\ALGOL60_SPEC_LANG.txt
  Compilateur 16 bits de reference : AL60C86.PAS (DOC\TODO\AL60C86.txt)
  Compilateur 32 bits de meme famille : AL58CW32.PAS (encodeur x86-32,
    ecrivains PE et COFF, runtime Win32 integre, gestion des erreurs et
    script de test a reprendre ou a adapter : DOC\TODO\AL58CW32.txt)
  Modele PE/COFF 32 bits de reference : JOVCW32.PAS, BCPLCW32.PAS

  ETAT : TODO 01 a 04 implementes (squelette, pipeline en 6 phases,
         options de ligne de commande, constantes, limites et nommage,
         lexeur) ; TODO 05 a 25 a faire.

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - ARCHITECTURE ET PIPELINE DU COMPILATEUR [IMPLEMENTE]
            Definir le pipeline complet :
              source .a60 -> lexeur -> parseur (generation en une passe)
              -> code interne (ASM 80386) -> .ASM (optionnel)
              -> encodeur binaire x86-32 -> .OBJ (COFF) ou .EXE (PE)
            Choix retenu : encodeur binaire interne (comme JOVCW32), le
              .ASM n'etant qu'un listing parallele, pas une etape requise
            Differences avec AL60C86 : registres 32 bits (EAX..EBP),
              modele FLAT, entier 32 bits, vrai type real (x87) au lieu
              du stub entier, appels API Win32 au lieu de INT 21h,
              aucune limite de segment 64 Ko
            Decouper le source en sections commentees : constantes, types,
              options, lexeur, types Algol, symboles, code interne,
              parseur/generateur, encodeur, ecrivains OBJ/EXE, runtime,
              erreurs, programme principal
            Garder la compatibilite Turbo Pascal 7 / Free Pascal 3.2
              ({$MODE TP}, {$H-}, {$I-}), lignes de 80 colonnes maximum
            Attention : Integer vaut 16 bits en mode TP, utiliser LongInt
              pour les indices de tables et les tailles
            Realise : directives {$MODE TP}, {$H-}, {$I-} ; 14 sections
              numerotees (constantes, types, variables, utilitaires,
              options, lexeur, types et symboles, parseur / generateur,
              code interne, encodeur, ecrivains, runtime, erreurs et
              rapport, pipeline) ; type TPhase (PH_LEX, PH_PARSE,
              PH_CODEGEN, PH_ENCODE, PH_WRITE, PH_REPORT) ; Run execute
              les six phases dans l'ordre (les phases vides seront
              remplies par les TODOs suivants) ; code de retour EXIT_OK
              ou EXIT_ERROR selon le nombre d'erreurs

  TODO 02 - OPTIONS DE LIGNE DE COMMANDE ET FICHIERS DE SORTIE [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm)
            Syntaxe : AL60CW32 source.a60 [-o sortie] [-obj] [-asm]
              [-v] [-d] [-w] [-h]
            Par defaut : produire source.exe (PE Windows 32 bits)
            -obj : produire uniquement source.obj (aucun .EXE)
            -asm : produire en plus source.asm (listing MASM 80386)
            -o nom : nom du fichier de sortie principal
            Extensions d'entree acceptees : .a60 et .alg
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Aide en ligne (-h), version et date, message d'usage si
              aucun argument
            Realise : -w / -w+ active et -w- desactive les avertissements
              (desactives par defaut) ; options insensibles a la casse ;
              source sans extension : .a60 puis .alg ; sortie sans
              extension : .exe (ou .obj avec -obj) ajoute ; le .asm
              porte le nom de la sortie ; refus d'ecraser le source, de
              designer un .asm avec -o, d'une extension inconnue, d'un
              source introuvable ; code de retour 2 pour une erreur
              d'usage, 1 pour une erreur fatale ; en mode -v, banniere et
              fichiers de sortie annonces (seuls les fichiers demandes
              seront crees)

  TODO 03 - CONSTANTES, LIMITES ET CONVENTIONS DE NOMMAGE [IMPLEMENTE]
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_SIGNATURE,
              PE_MACHINE_I386 ($014C), PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console), indicateurs
              de sections (code, donnees, lecture/ecriture)
            Constantes COFF : COFF_SYM_EXTERNAL, COFF_SYM_STATIC,
              IMAGE_REL_I386_DIR32 et IMAGE_REL_I386_REL32
            Limites internes 32 bits (pas de reduction "Turbo Pascal 16
              bits") : symboles, labels, portees, parametres, tableaux,
              dimensions, tailles de code et de donnees, relocations
            Prefixes de nommage ASM : _A60V_ (variable), _A60P_
              (procedure), _A60K_ (chaine), _A60RT_ (runtime), _A60L_
              (label interne), _A60S_ (switch), _A60O_ (own), _A60A_
              (tableau), _A60T_ (thunk)
            Utilitaires : ItoS, ItoSZ, UpCaseStr, AsmIdent (nom ASM valide),
              extension et nom de fichier
            Realise : constantes de la convention d'appel (prefixe ABI),
              PE et COFF (prefixes PE et COFF), tampons du code binaire
              (prefixe MAX_BIN), limites du compilateur (MAX_SYM,
              MAX_LABEL, MAX_SCOPE, MAX_PROC, MAX_PARAM, MAX_ARRAY_DIM =
              8, MAX_SWITCH, MAX_LOOP_NEST, MAX_ERRORS = 30, MAX_STR)
              avec une valeur reduite sous Turbo Pascal ; noms ASM =
              prefixe + identificateur en majuscules (autre caractere
              -> _) : MangleVar, MangleProc, MangleOwn, MangleArr,
              MangleSwitch, MangleRT, MangleUserLabel, MangleThunk,
              MangleLabel (5 chiffres), MangleStr ; point d'entree
              _A60P_Main ; casse des identificateurs confirmee au TODO 04

  TODO 04 - LEXEUR ALGOL 60 [IMPLEMENTE]
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_IDENT,
              TK_KEYWORD, TK_OP, TK_PUNCT, TK_STRING
            Format libre, suivi de ligne et colonne pour les erreurs
            Insensible a la casse pour les mots-cles (BEGIN, Begin...)
            Mots-cles : begin end if then else for do step until while
              goto go to comment own integer real boolean string array
              switch procedure value label true false and or not impl
              equiv div
            Operateurs : + - * / ^ ** div = != # < <= > >= := et les
              symboles logiques /\ (and), \/ (or), ~ (not)
            Ponctuation : ; , : ( ) [ ] et le point final de END.
            Commentaire "comment ... ;" ignore jusqu'au prochain point-
              virgule, y compris sur plusieurs lignes ; texte qui suit un
              end jusqu'a ; end else (commentaire de fin)
            Chaines entre apostrophes inverses `...` (forme des
              exemples) et entre guillemets "..." ; sequences d'echappement
              minimales ; chaine non fermee detectee
            Nombres : entiers, reels avec point (3.14), exposant (10),
              notation 1.5e3 ; detection des depassements
            'go' suivi de 'to' fusionnes en un seul token goto
            Mode debug -d : afficher chaque token
            Realise : lecture par blocs de 4096 octets avec un caractere
              d'avance ; ^Z = fin de fichier, NUL = caractere invalide ;
              mots-cles insensibles a la casse (valeur normalisee en
              minuscules), identificateurs insensibles a la casse
              (decision confirmee, orthographe d'origine conservee pour
              les messages) ; /\ \/ ~ deviennent les mots-cles and, or,
              not ; != et <> deviennent # ; ** devient ^ ; une chaine
              ouverte par ` se ferme par ` ou ' (forme du rapport), une
              chaine ouverte par " se ferme par " ; erreurs lexicales
              signalees une seule fois (caractere invalide, chaine non
              fermee ou trop longue, commentaire non termine, entier,
              exposant et reel hors limites) ; mode -v : lignes et tokens ;
              le texte qui suit end (jusqu'a ; end else ou le point final)
              est ignore
            Verifie : les 33 exemples SAMPLES\ALGOL60 sont decoupes sans
              erreur ; test_lex.a60 contient tous les symboles

  TODO 05 - TYPES DE DONNEES ET CONVERSIONS (32 BITS) [A FAIRE]
            integer : 32 bits signe (DWORD), au lieu des 16 bits d'AL60C86
            real : flottant 64 bits via x87 (FLD/FSTP QWORD), decision
              retenue : pas de stub entier, 3.14 de hello est un vrai reel
            Boolean : 0 ou 1 (DWORD) ; true et false
            string : pointeur vers donnees .data (litteraux et parametres)
            label, switch, procedure, array : types d'entites du programme
            TypeConversion : integer -> real (FILD), real -> integer
              (arrondi, FISTP), integer <-> Boolean avec avertissement
            Regles des operateurs (Revised Report, 3.3.4) :
              + - * : integer si les deux operandes le sont, sinon real
              / : toujours real ; div : integer ; ^ : integer pour un
              exposant integer positif, sinon real
            Mode debug -d : liste des types

  TODO 06 - TABLE DES SYMBOLES ET PORTEES [A FAIRE]
            Symboles : SK_VAR, SK_OWN, SK_ARRAY, SK_PROC, SK_PARAM,
              SK_LABEL, SK_SWITCH (nom, type, portee, niveau, offset)
            Portees imbriquees (bloc begin...end, corps de procedure) :
              ouverture, fermeture, recherche du plus interne au plus
              externe, detection des doublons dans une meme portee
            Allocation : globales en .data (niveau 0), locales [EBP-n],
              parametres [EBP+n], lien statique cache pour atteindre les
              variables des procedures englobantes
            Etiquettes : definition, utilisation, etiquette non definie
              reportee sur le bloc englobant, avertissement si inutilisee
            Copie persistante des parametres d'une procedure apres la
              fermeture de sa portee (necessaire aux appels)
            Declaration implicite (avertissement) d'une variable inconnue
            Mode debug -d : liste des symboles de chaque portee

  TODO 07 - CODE INTERNE ET LISTING .ASM [A FAIRE]
            Instructions 80386 structurees (TInstr : operation, deux
              operandes registre / immediat / memoire / etiquette /
              OFFSET / ST(i)) dans deux listes : programme principal et
              procedures differees (placees apres le programme)
            Emission : Emit, EmitLabel, EmitComment, NewLabel (_A60L_nnn),
              operandes OpReg, OpImm, OpMem, OpMemSym, OpMemIdx, OpLabel
            Listing .ASM optionnel (WriteListing), syntaxe MASM acceptee
              par ML.PAS : .386, .MODEL FLAT, INCLUDELIB kernel32.lib,
              EXTERN des fonctions Win32, .DATA, .CODE, END <entree>
            Conventions : integer / Boolean / pointeurs dans EAX, real
              dans ST(0), valeurs intermediaires sur la pile machine,
              jamais en registre a travers un appel
            Le listing ne doit jamais etre ecrit sans -asm

  TODO 08 - SEGMENT DE DONNEES, VARIABLES STATIQUES ET OWN [A FAIRE]
            Cellules de .data : zero (DD n DUP(0)), chaines (DB, 0),
              entiers, reels (DQ), tables d'adresses (switch)
            Chaines litterales dedoublonnees (_A60K_nnn)
            Variables de niveau 0 : une cellule _A60V_NOM
            Variables OWN (statiques, valeur conservee entre les appels
              d'un bloc ou d'une procedure, initialisees a zero) :
              cellules _A60O_nom_n, meme pour les tableaux OWN
            Constantes reelles en memoire (QWORD) pour FLD
            Verification : own.a60, test_own.a60, test_data.a60

  TODO 09 - EXPRESSIONS PRIMAIRES ET VARIABLES [A FAIRE]
            Arbre d'expression (pool reinitialise a chaque instruction) :
              constantes, chaines, variables, elements de tableau,
              appels de fonction, expressions entre parentheses
            Acces aux variables : globales, locales, parametres, variables
              des blocs englobants par le lien statique
            Acces aux elements : Sym[i, j, ...] avec calcul d'adresse et
              controle de bornes a l'execution
            Chargement dans EAX (integer, Boolean) ou ST(0) (real)
            Verification : test_primary.a60, test_variables.a60,
              test_literals.a60, test_symbols.a60

  TODO 10 - EXPRESSIONS ARITHMETIQUES [A FAIRE]
            Priorites (Revised Report) : puissance ^ > * / div > + -
              avec + et - unaires, associativite a gauche
            Repliement des constantes a la compilation ; division par
              zero constante signalee
            integer : ADD, SUB, IMUL, CDQ + IDIV, NEG ; div ; mod absent
              du rapport (fonction ou extension a documenter)
            real : FADD, FSUB, FMUL, FDIV, FCHS ; promotion automatique
              d'un operande integer
            Puissance : _A60RT_POW (entiers) et x87 (reels) selon les
              types des operandes
            Verification : math.a60, test_arithbool.a60, test_operators.a60

  TODO 11 - EXPRESSIONS BOOLEENNES ET CONDITIONNELLES [A FAIRE]
            Relationnels = != # < <= > >= (integer et real, resultat
              Boolean) ; logiques not (~), and (/\), or (\/), impl, equiv
              avec leurs priorites (not > and > or > impl > equiv)
            Production de 0 ou 1 par SETcc et sauts conditionnels optimises
              dans if et while (GenJump)
            Expression conditionnelle : if B then E1 else E2, les deux
              branches de meme type (integer et real : promotion en real)
            Expression designationnelle : if B then etiquette else
              etiquette, element de switch
            Verification : test_condexpr.a60, test_arithbool.a60, ifthen.a60

  TODO 12 - INSTRUCTIONS : AFFECTATION, IF ET BLOCS [A FAIRE]
            Affectation x := E avec conversion de type ; affectations
              multiples a := b := E (liste de parties gauches)
            Instruction conditionnelle if B then S1 [else S2], sans
              ambiguite du else pendant
            Instruction composee begin ... end et blocs avec declarations
              (portee locale, reservation de pile au bloc)
            Instruction vide, instruction etiquetee, point final de END.
            Verification : test_if.a60, test_blocks.a60, blocks.a60,
              ifthen.a60, test_emitter.a60

  TODO 13 - BOUCLE FOR [A FAIRE]
            for v := liste do S ; elements de la liste : expression
              simple, E1 step E2 until E3, E1 while B, en nombre quelconque
            Evaluation de la borne et du pas a chaque tour (semantique du
              rapport), pas negatif, variable de controle modifiable
            Plusieurs elements : selecteur de clause, saut vers l'element
              suivant ; sortie de boucle par goto
            Compteur de profondeur des boucles imbriquees
            Verification : forloop.a60, test_for.a60

  TODO 14 - GOTO, ETIQUETTES ET SWITCH [A FAIRE]
            Etiquettes d'instruction, goto vers une etiquette du meme bloc
              ou d'un bloc englobant (restauration de la pile)
            goto hors d'une procedure vers un bloc englobant (depilement
              par lien statique et restauration d'EBP / ESP)
            Declaration switch S := L1, L2, ... : table d'adresses dans
              .data et JMP indirect, designateur S[i] avec indice hors
              bornes sans saut (avertissement si constant)
            Switch dont les elements sont des expressions designationnelles
            Verification : switch.a60, test_switch.a60, test_goto.a60

  TODO 15 - TABLEAUX A BORNES DYNAMIQUES [A FAIRE]
            Declaration [type] array A[l1:u1, l2:u2], B[...] : plusieurs
              tableaux par declaration, jusqu'a MAX_ARRAY_DIM dimensions
            Bornes evaluees a l'entree du bloc (expressions quelconques) :
              descripteur (base, dimensions, bornes, foulees) et memoire
              allouee au bloc, liberee a sa sortie
            Calcul d'adresse a plusieurs indices, controle de bornes
              (_A60RT_CHKIDX), taille nulle ou negative, limite de taille
            Tableaux de real, d'integer et de Boolean ; tableaux OWN
            Verification : arrays.a60, test_arrays.a60

  TODO 16 - PROCEDURES ET FONCTIONS : DECLARATION ET APPEL [A FAIRE]
            procedure [type] Nom(p1, p2) ; value ...; specifications ;
              corps : instruction ou bloc ; resultat par affectation au
              nom de la fonction (integer, real, Boolean)
            Convention d'appel : arguments empiles de droite a gauche,
              lien statique, appelee nettoie la pile (RET n), resultat
              dans EAX ou ST(0), cadre EBP
            Passage par valeur (value) avec conversion de type
            Recursivite, procedures imbriquees (acces aux variables des
              procedures englobantes), procedures sans parametre
            Appel en instruction et en expression, verification du nombre
              et du type des arguments, procedure inconnue
            Parametres formels de type string, label, procedure et switch
            Verification : procs.a60, test_procedures.a60, test_proccall.a60

  TODO 17 - APPEL PAR NOM (THUNKS) [A FAIRE]
            Passage par nom par defaut des parametres non declares value
            Thunk : petit code genere pour chaque argument reel qui
              evalue l'expression dans le contexte de l'appelant (variable,
              element de tableau a indice variable, expression)
            Pair (thunk, contexte) passe a la procedure ; appel du thunk
              a chaque utilisation du parametre formel (lecture) et a
              chaque affectation (ecriture dans la variable ou l'element)
            Dispositif de Jensen : somme(i, 1, 5, a[i]) et somme(i, 1, 5,
              i * i) avec variable de controle passee par nom
            Echange de deux elements de tableau par nom (swap(a[i], a[j]))
            Verification : byname.a60, test_callbyname.a60

  TODO 18 - ENTREES/SORTIES ET FONCTIONS STANDARD [A FAIRE]
            Sorties avec numero de canal (1 = sortie standard) :
              outstring(c, chaine), outinteger(c, n), outreal(c, x),
              outboolean(c, b), newline(c), print(chaine) (raccourci de
              outstring(1, chaine))
            Entrees : ininteger(c, n), inreal(c, x), inchar si utile
              (a documenter, lecture sur l'entree standard)
            Fonctions standard du rapport : abs, sign, sqrt, sin, cos,
              arctan, ln, exp, entier ; arguments integer ou real, repliement
              des constantes, resultat integer pour abs et sign d'un integer
            Appels vers les routines du runtime avec arguments en registres
            Contrat avec le runtime (TODO 22) : WRITESTR, WRITEZ,
              WRITEINT, WRITEREAL, WRITEBOOL, NEWLINE, READINT, READREAL,
              POW, EXP, FLOOR, RTOI, RSIGN, ISQRT, CHKIDX, DIVZERO, ALLOC
            Verification : test_io.a60, math.a60, hello.a60

  TODO 19 - ENCODEUR BINAIRE x86-32 [A FAIRE]
            Encoder chaque instruction du code interne en octets :
              MOV, MOVZX, LEA, PUSH, POP, ADD, SUB, IMUL, IDIV, DIV, CDQ,
              NEG, NOT, AND, OR, XOR, CMP, TEST, INC, DEC, SHL, SHR, SAR,
              SETcc, Jcc, JMP, CALL, RET, REP STOSD, SAHF et les
              instructions x87 (FLD, FST, FSTP, FILD, FISTP, FADD..FDIVR,
              FADDP..FDIVP, FCOM, FCOMP, FXCH, FNSTSW, FNSTCW, FLDCW,
              FCHS, FABS, FSQRT, FSIN, FCOS, FPATAN, FYL2X, F2XM1, FSCALE,
              FRNDINT, FLD1, FLDZ, FLDLN2, FLDL2E, FTST)
            Operandes 8, 16 et 32 bits, ModRM / SIB / deplacement 8 ou 32
              bits (cas [EBP], [ESP], [sym], [sym + index*echelle])
            Tampons de code et de donnees ; table des etiquettes (code,
              donnees, externe) ; relocations BF_ABS32 et BF_REL32
            Sauts courts ou longs choisis par relaxation (tous courts au
              depart, agrandis tant qu'un deplacement deborde)
            Donnees : zeros, chaines avec 0 final, entiers, reels, tables
              d'adresses avec relocations ; imports = cibles d'appel non
              definies
            Mode -d : <sortie>.lst, listing hexadecimal (decalage, octets,
              instruction)
            Verification : decoder chaque instruction avec objdump et la
              comparer (mnemonique, longueur, operandes) sur tous les
              exemples

  TODO 20 - ECRIVAIN PE (.EXE WINDOWS 32 BITS) [A FAIRE]
            En-tete MZ + souche DOS, signature PE, COFF File Header
              (machine 386, 3 sections), Optional Header (magic $010B,
              ImageBase $00400000, alignements 4096 / 512, sous-systeme
              console, piles et tas reserves)
            Sections .text (code + une souche JMP [IAT] par import),
              .data, .idata (import de kernel32.dll : descripteurs, ILT,
              IAT, noms avec indice, nom de la DLL)
            Repertoires : importation (1) et IAT (12) ; point d'entree =
              programme principal
            Relocations resolues a l'ecriture : adresses absolues
              (code -> donnees, tables de switch) et appels aux imports
            Un symbole non defini du runtime est une erreur ; tout autre
              nom est importe de kernel32.dll
            Fichier .EXE par defaut (option -o pour le nom)
            Verification : objdump -x / -p, execution d'un programme
              assemble a la main (Wine, ou chargeur PE minimal de
              TESTS\AL58CW32\runpe.c)

  TODO 21 - ECRIVAIN COFF (.OBJ, OPTION -obj) [A FAIRE]
            COFF File Header (machine 386), sections .text et .data avec
              relocations (IMAGE_REL_I386_DIR32, REL32)
            Table des symboles : sections (avec entree auxiliaire), point
              d'entree externe defini, externes non definis (imports
              Win32), table des chaines pour les noms longs
            Adresse absolue vers une etiquette definie : symbole de
              section, decalage ajoute a la valeur en place
            Option -obj : ne pas produire de .EXE ; -obj -asm : produire
              .OBJ et .ASM
            Verification : objdump -h -t -r sur tous les exemples ; un
              .OBJ lie avec lld-link (ou LINK.PAS) doit donner le meme
              comportement que l'.EXE direct

  TODO 22 - RUNTIME ALGOL 60 POUR WIN32 [A FAIRE]
            Runtime ecrit en assembleur 80386, integre au compilateur
              sous forme de texte et assemble par un mini-assembleur,
              sans bibliotheque C ; seules les fonctions de kernel32.dll
              sont importees (GetStdHandle, WriteFile, ReadFile,
              ExitProcess, GetProcessHeap, HeapAlloc, HeapFree)
            Emission des seules routines utilisees (fermeture
              transitive des appels aux routines _A60RT_) ; le runtime
              figure dans le listing .ASM qui devient autonome
            Routines : WRITESTR, WRITEZ, WRITEINT, WRITEREAL, WRITEBOOL,
              NEWLINE, READINT, READREAL, POW, RPOW, EXP, FLOOR, RTOI,
              RSIGN, ISQRT, CHKIDX, DIVZERO, ALLOC, FREE (blocs dont les
              tableaux sont liberes a la sortie)
            Messages d'erreur d'execution (indice hors bornes, division
              par zero) et code de sortie 1
            Formats a documenter : entier decimal, reel en notation
              fixe (6 decimales au plus, zeros finaux supprimes),
              Boolean true / false, fin de ligne CR LF

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [A FAIRE]
            Erreurs lexicales : caractere invalide, chaine non fermee,
              commentaire non termine, nombre hors limites
            Erreurs syntaxiques : token inattendu, begin/end non apparie,
              parenthese ou crochet non ferme, point-virgule manquant
            Erreurs semantiques : type incompatible, appel avec mauvais
              nombre d'arguments, etiquette inconnue, doublon de
              declaration dans une meme portee, switch ou tableau mal
              utilise, division par zero constante
            Avertissements : variable non declaree (declaration implicite),
              etiquette non utilisee, indice de switch hors bornes,
              conversions implicites real -> integer et integer <-> Boolean
            Recuperation : synchronisation sur ; ou mot-cle (begin, end,
              for, if, procedure) avec garantie de progression, pour
              reporter plusieurs erreurs
            Format "fichier(ligne,col) : erreur/avertissement : message"
            Compteurs finaux, code de retour EXIT_ERROR si erreurs,
              aucun fichier de sortie corrompu en cas d'erreur (les
              fichiers crees sont supprimes sur erreur fatale)
            Exemples : test_lex.a60 et programmes fautifs du script de test

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [A FAIRE]
            Run : lexeur -> parseur/generateur -> runtime -> encodeur ->
              ecrivain (PE ou COFF) -> .ASM optionnel -> statistiques
            Mode -v : phases, tailles .text/.data, nombre de symboles
            Mode -d : dump des tokens, de la table des symboles, du code
              interne et listing hexadecimal
            Mode -w / -w+ : activer les avertissements ; -w- : les desactiver
            Suppression de sortie partielle si erreur
            Verifier que l'absence de -asm ne cree jamais de .ASM, que
              -obj ne cree jamais de .EXE, et que sans option on obtient
              uniquement le .EXE

  TODO 25 - VALIDATION SUR TOUS LES EXEMPLES SAMPLES\ALGOL60\* [A FAIRE]
            Compiler les 33 fichiers : arrays, blocks, byname, forloop,
              hello, ifthen, math, own, procs, switch, test_arithbool,
              test_arrays, test_blocks, test_callbyname, test_condexpr,
              test_data, test_emitter, test_for, test_goto, test_if,
              test_io, test_lex, test_literals, test_operators, test_own,
              test_primary, test_proccall, test_procedures, test_runtime,
              test_switch, test_symbols, test_types, test_variables
            Creer les sorties attendues (.exp) puis un script
              TESTS\test_al60cw32.sh (modele : test_al58cw32.sh,
              test_adacw32.sh) executant chaque .EXE via Wine ou le
              chargeur PE minimal et comparant la sortie
            Tester les trois modes : .EXE (defaut), .OBJ (-obj) et
              .ASM (-asm), verifier que -asm est optionnel
            Controler l'encodage avec objdump et les erreurs avec des
              programmes fautifs (message, code de retour, aucun fichier)
            Cas speciaux : test_lex.a60 (tous les symboles lexicaux),
              test_emitter, test_symbols et test_types (declarations et
              expressions isolees) doivent produire un .EXE valide
            Mettre a jour README.md (ligne AL60CW32.PAS), ajouter
              DOC\TODO\AL60CW32.txt et BINLINUX\AL60CW32 (WIN32\
              al60cw32.exe a produire sous Windows)
  ============================================================ *)

Program AL60CW32;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-} { Desactiver les IO-check pour gerer nous-memes les erreurs }

{$IFDEF FPC}
Uses Math;
{$ENDIF}

{ ============================================================
  SECTION 1 - CONSTANTES (TODO 01, 03)
  ============================================================ }
Const
  AL60CW32_VERSION = '0.1';
  AL60CW32_DATE    = '2026';

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Differences avec AL60C86 (cible 8086, 16 bits, DOS) :
      - registres 32 bits (EAX, EBX, ECX, EDX, ESI, EDI, EBP, ESP)
      - modele FLAT : pas de segments, pas de limite de 64 Ko
      - integer sur 32 bits signes, real sur 64 bits (x87)
      - sorties par API Win32 (kernel32) au lieu de INT 21h
      - sortie finale : .EXE (PE) ou .OBJ (COFF), .ASM optionnel }
  ABI_WORD_SIZE = 4;   { taille d un registre / d un integer en octets }
  ABI_REAL_SIZE = 8;   { real : flottant 64 bits (x87)                   }
  ABI_RET_REG   = 'EAX';
  ABI_FRAME_REG = 'EBP';
  ABI_STACK_REG = 'ESP';
  ABI_PARAM_BASE = 8;  { [EBP+8] = premier parametre (apres EBP, retour) }

  { ---- Format PE (.EXE Windows 32 bits) ---- }
  PE_DOS_MAGIC     = $5A4D;       { 'MZ'                               }
  PE_SIGNATURE     = $00004550;   { 'PE',0,0                           }
  PE_MACHINE_I386  = $014C;
  PE_OPT_SIZE      = 224;         { taille de l Optional Header 32 bits }
  PE_MAGIC_32      = $010B;
  PE_IMG_BASE      = $00400000;
  PE_SEC_ALIGN     = 4096;
  PE_FILE_ALIGN    = 512;
  PE_SUBSYS_CUI    = 3;           { sous-systeme console               }
  PE_FILE_EXE      = $0002;       { IMAGE_FILE_EXECUTABLE_IMAGE        }
  PE_FILE_32BIT    = $0100;       { IMAGE_FILE_32BIT_MACHINE           }
  PE_SCN_TEXT      = $60000020;   { code, execute, read                }
  PE_SCN_RDATA     = $40000040;   { donnees initialisees, read         }
  PE_SCN_DATA      = $C0000040;   { donnees initialisees, read, write  }

  { ---- Format COFF (.OBJ) ---- }
  COFF_SYM_EXTERNAL = 2;
  COFF_SYM_STATIC   = 3;
  COFF_REL_DIR32    = $0006;      { IMAGE_REL_I386_DIR32               }
  COFF_REL_REL32    = $0014;      { IMAGE_REL_I386_REL32               }

  { ---- Tampons du code binaire (TODO 19 a 21) ---- }
  MAX_BIN_CODE  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_DATA  = {$IFDEF FPC}262144{$ELSE}16384{$ENDIF};
  MAX_BIN_LBL   = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};
  MAX_BIN_FIX   = {$IFDEF FPC}131072{$ELSE}512{$ENDIF};

  { ---- Limites internes du compilateur (32 bits) ---- }
  MAX_SYM       = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_PROC      = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}2048{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_ARRAY_DIM = 8;      { dimensions maximales d un tableau          }
  MAX_SWITCH    = 256;    { designateurs maximaux d un switch          }
  MAX_LOOP_NEST = 32;     { imbrication maximale des boucles for       }
  MAX_ERRORS    = 30;     { arret apres ce nombre d erreurs            }
  MAX_STR       = 255;    { longueur maximale d une chaine litterale   }

  { ---- Prefixes de nommage ASM ---- }
  A60_VAR_PFX   = '_A60V_';     { variable scalaire                    }
  A60_PROC_PFX  = '_A60P_';     { procedure / fonction                 }
  A60_STR_PFX   = '_A60K_';     { constante chaine litterale           }
  A60_RT_PFX    = '_A60RT_';    { routine runtime                      }
  A60_LBL_PFX   = '_A60L_';     { label de saut interne                }
  A60_USR_PFX   = '_A60L_USR_'; { etiquette Algol (goto)               }
  A60_SW_PFX    = '_A60S_';     { table switch                         }
  A60_OWN_PFX   = '_A60O_';     { variable own                         }
  A60_ARR_PFX   = '_A60A_';     { tableau                              }
  A60_THUNK_PFX = '_A60T_';     { thunk de parametre par nom           }
  A60_MAIN_NAME = '_A60P_Main'; { point d entree du programme          }

{ ============================================================
  SECTION 2 - TYPES (TODO 01, 04, 05, 06)
  ============================================================ }
Type
  TString = String[255];

  { Tokens du lexeur (TODO 04) }
  TTokenKind = (
    TK_EOF,
    TK_INTEGER,
    TK_REAL,
    TK_IDENT,
    TK_KEYWORD,
    TK_OP,
    TK_PUNCT,
    TK_STRING
  );

  TToken = Record
    Kind    : TTokenKind;
    Val     : TString;     { texte ; mot-cle et operateur normalises }
    IntVal  : LongInt;     { valeur d un TK_INTEGER                  }
    RealVal : Double;      { valeur d un TK_REAL (et TK_INTEGER)     }
    Line    : Integer;
    Col     : Integer;
  End;

  { Options de la ligne de commande (TODO 02) }
  TOptions = Record
    SrcFile   : TString;    { fichier source .a60 / .alg              }
    OutFile   : TString;    { sortie principale (.exe ou .obj)        }
    AsmFile   : TString;    { listing .asm (si EmitAsm)               }
    Verbose   : Boolean;    { -v : banniere + statistiques            }
    DebugMode : Boolean;    { -d : dump des tokens                    }
    Warnings  : Boolean;    { -w : activer les avertissements         }
    EmitExe   : Boolean;    { produire un .EXE PE (defaut)            }
    EmitObj   : Boolean;    { -obj : produire seulement un .OBJ       }
    EmitAsm   : Boolean;    { -asm : produire aussi un .ASM           }
  End;

  { Etapes du pipeline :
      source .a60 -> lexeur -> parseur / table des symboles
      -> generation du code interne (listing .ASM optionnel)
      -> encodeur binaire x86-32 -> ecrivain COFF (.OBJ) ou PE (.EXE) }
  TPhase = (
    PH_LEX,       { TODO 04 : lexeur                                  }
    PH_PARSE,     { TODO 05-18 : types, symboles, parseur/generateur  }
    PH_CODEGEN,   { TODO 07-08 : code interne + listing .ASM optionnel}
    PH_ENCODE,    { TODO 19 : encodeur binaire x86-32                 }
    PH_WRITE,     { TODO 20-21 : ecrivain PE (.EXE) ou COFF (.OBJ)    }
    PH_REPORT     { TODO 23-24 : statistiques et code de retour       }
  );

{ ============================================================
  SECTION 3 - VARIABLES GLOBALES (TODO 01, 02, 23)
  ============================================================ }
Var
  Opts       : TOptions;
  ErrorCount : Integer;   { erreurs de compilation signalees  }
  WarnCount  : Integer;   { avertissements signales           }

{ ============================================================
  SECTION 4 - UTILITAIRES (TODO 03)
  ============================================================ }
Function ItoS(V : LongInt) : TString;
Var
  S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

{ Nombre sur Width chiffres au moins, complete par des zeros }
Function ItoSZ(V : LongInt; Width : Integer) : TString;
Var
  S : TString;
Begin
  S := ItoS(V);
  While Length(S) < Width Do
    S := '0' + S;
  ItoSZ := S;
End;

{ Vrai si un reel est infini ou invalide (debordement) }
Function RealBad(D : Double) : Boolean;
Begin
  {$IFDEF FPC}
  RealBad := IsNaN(D) Or IsInfinite(D);
  {$ELSE}
  RealBad := False;
  {$ENDIF}
End;

Function UpCaseStr(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['a'..'z'] Then
      R[I] := Chr(Ord(R[I]) - 32);
  UpCaseStr := R;
End;

{ Identificateur Algol -> fragment de nom ASM valide : lettres,
  chiffres et souligne conserves, tout autre caractere devient _.
  La casse est normalisee en majuscules (identificateurs insensibles
  a la casse, TODO 04). }
Function AsmIdent(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := UpCaseStr(S);
  For I := 1 To Length(R) Do
    If Not (R[I] In ['A'..'Z', '0'..'9', '_']) Then
      R[I] := '_';
  AsmIdent := R;
End;

{ ---- Noms des symboles ASM : prefixe + identificateur ---- }
Function MangleVar(Const Name : TString) : TString;
Begin
  MangleVar := A60_VAR_PFX + AsmIdent(Name);
End;

Function MangleProc(Const Name : TString) : TString;
Begin
  MangleProc := A60_PROC_PFX + AsmIdent(Name);
End;

Function MangleOwn(Const Name : TString) : TString;
Begin
  MangleOwn := A60_OWN_PFX + AsmIdent(Name);
End;

Function MangleArr(Const Name : TString) : TString;
Begin
  MangleArr := A60_ARR_PFX + AsmIdent(Name);
End;

Function MangleSwitch(Const Name : TString) : TString;
Begin
  MangleSwitch := A60_SW_PFX + AsmIdent(Name);
End;

Function MangleRT(Const Name : TString) : TString;
Begin
  MangleRT := A60_RT_PFX + AsmIdent(Name);
End;

Function MangleUserLabel(Const Name : TString) : TString;
Begin
  MangleUserLabel := A60_USR_PFX + AsmIdent(Name);
End;

Function MangleThunk(Const Proc, Param : TString) : TString;
Begin
  MangleThunk := A60_THUNK_PFX + AsmIdent(Proc) + '_' + AsmIdent(Param);
End;

{ Labels internes et chaines : numerotation }
Function MangleLabel(N : LongInt) : TString;
Begin
  MangleLabel := A60_LBL_PFX + ItoSZ(N, 5);
End;

Function MangleStr(N : LongInt) : TString;
Begin
  MangleStr := A60_STR_PFX + ItoS(N);
End;

Function PhaseName(P : TPhase) : String;
Begin
  Case P Of
    PH_LEX     : PhaseName := 'lexeur';
    PH_PARSE   : PhaseName := 'parseur';
    PH_CODEGEN : PhaseName := 'generation du code';
    PH_ENCODE  : PhaseName := 'encodeur x86-32';
    PH_WRITE   : PhaseName := 'ecrivain PE/COFF';
    PH_REPORT  : PhaseName := 'rapport';
  End;
End;

Function StrLower(Const S : TString) : TString;
Var
  I : Integer;
  R : TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['A'..'Z'] Then
      R[I] := Chr(Ord(R[I]) + 32);
  StrLower := R;
End;

{ Position du point de l extension (0 si aucune extension) }
Function ExtPos(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  ExtPos := 0;
  I := Length(Name);
  While I > 0 Do
  Begin
    If Name[I] = '.' Then
    Begin
      ExtPos := I;
      Exit;
    End;
    If Name[I] In ['\', '/', ':'] Then Exit;
    Dec(I);
  End;
End;

Function GetExt(Const Name : TString) : TString;
Var
  P : Integer;
Begin
  P := ExtPos(Name);
  If P = 0 Then
    GetExt := ''
  Else
    GetExt := StrLower(Copy(Name, P, 255));
End;

Function ReplaceExt(Const Name, Ext : TString) : TString;
Var
  P : Integer;
Begin
  P := ExtPos(Name);
  If P = 0 Then
    ReplaceExt := Name + Ext
  Else
    ReplaceExt := Copy(Name, 1, P - 1) + Ext;
End;

Function FileExists(Const Name : TString) : Boolean;
Var
  F : File;
Begin
  Assign(F, Name);
  Reset(F, 1);
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

{ ============================================================
  SECTION 5 - OPTIONS DE LIGNE DE COMMANDE (TODO 02)
  ============================================================ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL60CW32: erreur fatale: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('AL60CW32: avertissement: ', Msg);
  Inc(WarnCount);
End;

{ Erreur / avertissement localise dans le source :
  fichier(ligne,colonne) : erreur : message }
Procedure ErrorAt(Line, Col : Integer; Const Msg : TString);
Begin
  WriteLn(Opts.SrcFile, '(', Line, ',', Col, ') : erreur : ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('trop d''erreurs (' + ItoS(MAX_ERRORS) +
               '), compilation arretee');
End;

Procedure WarnAt(Line, Col : Integer; Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn(Opts.SrcFile, '(', Line, ',', Col, ') : avertissement : ', Msg);
  Inc(WarnCount);
End;

Procedure ShowBanner;
Begin
  WriteLn('AL60CW32 ', AL60CW32_VERSION, ' (', AL60CW32_DATE, ') - ',
          'Compilateur Algol 60 vers 80386 / Windows 32 bits');
End;

Procedure ShowUsage(Code : Integer);
Begin
  ShowBanner;
  WriteLn;
  WriteLn('Syntaxe: AL60CW32 <source.a60> [-o sortie] [-obj] [-asm]',
          ' [-v] [-d] [-w] [-h]');
  WriteLn;
  WriteLn('  source.a60 : fichier Algol 60 source (.a60 ou .alg)');
  WriteLn('  -o nom     : nom du fichier de sortie principal');
  WriteLn('  -obj       : produire seulement un .OBJ (COFF), pas de .EXE');
  WriteLn('  -asm       : produire aussi un listing .ASM (optionnel)');
  WriteLn('  -v         : mode verbeux (phases, tailles, statistiques)');
  WriteLn('  -d         : debug (tokens, symboles, code interne)');
  WriteLn('  -w, -w-    : activer / desactiver les avertissements');
  WriteLn('  -h, --help : cette aide');
  WriteLn;
  WriteLn('Par defaut, produit seulement source.exe (PE Windows 32 bits).');
  WriteLn('Sans -asm aucun .asm n''est cree ; avec -obj aucun .exe.');
  Halt(Code);
End;

Procedure InitOptions;
Begin
  Opts.SrcFile   := '';
  Opts.OutFile   := '';
  Opts.AsmFile   := '';
  Opts.Verbose   := False;
  Opts.DebugMode := False;
  Opts.Warnings  := False;
  Opts.EmitExe   := True;
  Opts.EmitObj   := False;
  Opts.EmitAsm   := False;
End;

Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
  Opt : TString;
  Ext : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowUsage(EXIT_USAGE);

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    Opt := StrLower(Arg);

    If (Opt = '-h') Or (Opt = '--help') Or (Opt = '/?') Then
      ShowUsage(EXIT_OK)
    Else If Opt = '-v' Then
      Opts.Verbose := True
    Else If Opt = '-d' Then
      Opts.DebugMode := True
    Else If (Opt = '-w') Or (Opt = '-w+') Then
      Opts.Warnings := True
    Else If Opt = '-w-' Then
      Opts.Warnings := False
    Else If Opt = '-obj' Then
      Opts.EmitObj := True
    Else If Opt = '-asm' Then
      Opts.EmitAsm := True
    Else If Opt = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
      Begin
        WriteLn('AL60CW32: -o demande un nom de fichier');
        ShowUsage(EXIT_USAGE);
      End;
      Opts.OutFile := ParamStr(I);
    End
    Else If (Arg <> '') And (Arg[1] = '-') Then
    Begin
      WriteLn('AL60CW32: option inconnue: ', Arg);
      ShowUsage(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else
    Begin
      WriteLn('AL60CW32: argument inattendu: ', Arg);
      ShowUsage(EXIT_USAGE);
    End;
    Inc(I);
  End;

  If Opts.SrcFile = '' Then
  Begin
    WriteLn('AL60CW32: fichier source manquant');
    ShowUsage(EXIT_USAGE);
  End;

  { Extension du source : .a60 ou .alg (.a60 ajoute si absente) }
  If ExtPos(Opts.SrcFile) = 0 Then
  Begin
    If FileExists(Opts.SrcFile + '.a60') Then
      Opts.SrcFile := Opts.SrcFile + '.a60'
    Else
      Opts.SrcFile := Opts.SrcFile + '.alg';
  End;
  Ext := GetExt(Opts.SrcFile);
  If (Ext <> '.a60') And (Ext <> '.alg') Then
    FatalError('extension non supportee (attendu .a60 ou .alg): ' +
               Opts.SrcFile);
  If Not FileExists(Opts.SrcFile) Then
    FatalError('fichier source introuvable: ' + Opts.SrcFile);

  { Sortie principale : .EXE par defaut, .OBJ seul avec -obj }
  If Opts.EmitObj Then
    Opts.EmitExe := False;
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitExe Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj');
  End
  Else If ExtPos(Opts.OutFile) = 0 Then
  Begin
    If Opts.EmitExe Then
      Opts.OutFile := Opts.OutFile + '.exe'
    Else
      Opts.OutFile := Opts.OutFile + '.obj';
  End;

  { Listing assembleur optionnel : meme nom de base que la sortie }
  Opts.AsmFile := ReplaceExt(Opts.OutFile, '.asm');

  If StrLower(Opts.OutFile) = StrLower(Opts.SrcFile) Then
    FatalError('la sortie ecraserait le source: ' + Opts.OutFile);
  If GetExt(Opts.OutFile) = '.asm' Then
    FatalError('-o ne peut pas designer un .asm; utiliser -asm');
End;

{ ============================================================
  SECTION 6 - LEXEUR (TODO 04)
  ============================================================ }
Const
  KEYWORD_COUNT = 30;
  KeywordTab : Array[1..KEYWORD_COUNT] Of String[9] = (
    'begin', 'end', 'if', 'then', 'else', 'for', 'do', 'step', 'until',
    'while', 'goto', 'procedure', 'value', 'integer', 'real', 'boolean',
    'string', 'array', 'switch', 'own', 'label', 'true', 'false', 'and',
    'or', 'not', 'impl', 'equiv', 'div', 'comment'
  );
  LEX_BUFSIZE = 4096;
  LEX_EOF     = #0;   { sentinelle de fin de fichier }

Var
  LexF       : File;
  LexOpened  : Boolean;
  LexBuf     : Array[0..LEX_BUFSIZE - 1] Of Byte;
  LexBufLen  : LongInt;
  LexBufPos  : LongInt;
  LexHitEOF  : Boolean;
  LexCur     : Char;       { caractere courant                    }
  LexNxt     : Char;       { caractere suivant (lookahead de 1)   }
  LexLine    : Integer;    { ligne du caractere courant           }
  LexCol     : Integer;    { colonne du caractere courant         }
  LexPending : Boolean;    { un token est en attente (go to)      }
  LexPendTok : TToken;
  LexAfterEnd: Boolean;    { le token precedent etait end         }
  TokenCount : LongInt;    { tokens lus (statistiques)            }
  LexQuiet   : Boolean;    { vrai : ne pas rapporter les erreurs  }

{ Erreur lexicale ; la 2e passe (parseur) ne les repete pas }
Procedure LexError(Line, Col : Integer; Const Msg : TString);
Begin
  If Not LexQuiet Then ErrorAt(Line, Col, Msg);
End;

{ Lit un octet du fichier source ; #0 a la fin du fichier.
  Un octet 0 reel ou ^Z fait partie de la fin / est invalide. }
Function LexRawChar : Char;
Var
  B : Byte;
Begin
  LexRawChar := LEX_EOF;
  If LexHitEOF Then Exit;
  If LexBufPos >= LexBufLen Then
  Begin
    BlockRead(LexF, LexBuf, LEX_BUFSIZE, LexBufLen);
    LexBufPos := 0;
    If LexBufLen <= 0 Then
    Begin
      LexBufLen := 0;
      LexHitEOF := True;
      Exit;
    End;
  End;
  B := LexBuf[LexBufPos];
  Inc(LexBufPos);
  If B = 26 Then
    LexHitEOF := True          { ^Z : fin de fichier DOS }
  Else If B = 0 Then
    LexRawChar := #1           { NUL : caractere invalide }
  Else
    LexRawChar := Chr(B);
End;

Procedure LexNextChar;
Begin
  If LexCur = #10 Then
  Begin
    Inc(LexLine);
    LexCol := 1;
  End
  Else
    Inc(LexCol);
  LexCur := LexNxt;
  LexNxt := LexRawChar;
End;

Function LexPeekChar : Char;
Begin
  LexPeekChar := LexNxt;
End;

Procedure LexInit;
Begin
  Assign(LexF, Opts.SrcFile);
  Reset(LexF, 1);
  If IOResult <> 0 Then
    FatalError('impossible d''ouvrir le source: ' + Opts.SrcFile);
  LexOpened   := True;
  LexBufLen   := 0;
  LexBufPos   := 0;
  LexHitEOF   := False;
  LexPending  := False;
  LexAfterEnd := False;
  TokenCount  := 0;
  LexLine     := 1;
  LexCol      := 0;
  LexCur      := LEX_EOF;
  LexNxt      := LexRawChar;
  LexNextChar;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexF);
    LexOpened := False;
  End;
End;

Function IsLetter(C : Char) : Boolean;
Begin
  IsLetter := C In ['A'..'Z', 'a'..'z', '_'];
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := C In ['0'..'9'];
End;

Function IsKeyword(Const Low : TString) : Boolean;
Var
  I : Integer;
Begin
  IsKeyword := False;
  For I := 1 To KEYWORD_COUNT Do
    If KeywordTab[I] = Low Then
    Begin
      IsKeyword := True;
      Exit;
    End;
End;

Function TokenKindName(K : TTokenKind) : TString;
Begin
  Case K Of
    TK_EOF     : TokenKindName := 'EOF';
    TK_INTEGER : TokenKindName := 'INTEGER';
    TK_REAL    : TokenKindName := 'REAL';
    TK_IDENT   : TokenKindName := 'IDENT';
    TK_KEYWORD : TokenKindName := 'KEYWORD';
    TK_OP      : TokenKindName := 'OP';
    TK_PUNCT   : TokenKindName := 'PUNCT';
    TK_STRING  : TokenKindName := 'STRING';
  End;
End;

{ Identificateur ou mot-cle : lettre suivie de lettres/chiffres }
Procedure LexScanIdent(Var T : TToken);
Var
  Low : TString;
Begin
  T.Val := '';
  While IsLetter(LexCur) Or IsDigit(LexCur) Do
  Begin
    If Length(T.Val) < 255 Then
      T.Val := T.Val + LexCur;
    LexNextChar;
  End;
  Low := StrLower(T.Val);
  If IsKeyword(Low) Then
  Begin
    T.Kind := TK_KEYWORD;
    T.Val  := Low;
  End
  Else
    T.Kind := TK_IDENT;
End;

{ Nombre : entier (123), reel (3.14, .5), exposant (1.5E3, 2e-2) }
Procedure LexScanNumber(Var T : TToken);
Var
  IntOvf  : Boolean;
  IsReal  : Boolean;
  Mant    : Double;
  E10     : Integer;
  ExpV    : Integer;
  ExpNeg  : Boolean;
  Digit   : Integer;
  I, N    : Integer;
  P       : Double;
Begin
  T.Val := '';
  T.IntVal := 0;
  IntOvf := False;
  IsReal := False;
  Mant := 0;
  E10 := 0;

  { partie entiere }
  While IsDigit(LexCur) Do
  Begin
    Digit := Ord(LexCur) - Ord('0');
    If T.IntVal > (MaxLongInt - Digit) Div 10 Then
      IntOvf := True
    Else
      T.IntVal := T.IntVal * 10 + Digit;
    Mant := Mant * 10 + Digit;
    If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
    LexNextChar;
  End;

  { partie fractionnaire : le point doit etre suivi d un chiffre }
  If (LexCur = '.') And IsDigit(LexPeekChar) Then
  Begin
    IsReal := True;
    If Length(T.Val) < 255 Then T.Val := T.Val + '.';
    LexNextChar;
    While IsDigit(LexCur) Do
    Begin
      Mant := Mant * 10 + (Ord(LexCur) - Ord('0'));
      Dec(E10);
      If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
  End;

  { exposant : E ou e suivi de [+|-] chiffres }
  If (LexCur In ['E', 'e']) And
     (IsDigit(LexPeekChar) Or (LexPeekChar In ['+', '-'])) Then
  Begin
    IsReal := True;
    If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
    LexNextChar;
    ExpNeg := False;
    If LexCur In ['+', '-'] Then
    Begin
      ExpNeg := (LexCur = '-');
      If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
      LexNextChar;
    End;
    If Not IsDigit(LexCur) Then
      LexError(LexLine, LexCol, 'exposant invalide: chiffre attendu')
    Else
    Begin
      ExpV := 0;
      While IsDigit(LexCur) Do
      Begin
        If ExpV < 10000 Then
          ExpV := ExpV * 10 + (Ord(LexCur) - Ord('0'));
        If Length(T.Val) < 255 Then T.Val := T.Val + LexCur;
        LexNextChar;
      End;
      If ExpNeg Then ExpV := -ExpV;
      E10 := E10 + ExpV;
    End;
  End;

  If IsReal Then
  Begin
    T.Kind := TK_REAL;
    If (E10 > 308) Or (E10 < -308) Then
    Begin
      LexError(T.Line, T.Col, 'exposant hors limites: ' + T.Val);
      T.RealVal := 0;
    End
    Else
    Begin
      P := 1;
      N := Abs(E10);
      For I := 1 To N Do
        P := P * 10;
      If E10 < 0 Then
        T.RealVal := Mant / P
      Else
        T.RealVal := Mant * P;
      If RealBad(T.RealVal) Then
      Begin
        LexError(T.Line, T.Col, 'reel hors limites: ' + T.Val);
        T.RealVal := 0;
      End;
    End;
  End
  Else
  Begin
    T.Kind := TK_INTEGER;
    If IntOvf Then
    Begin
      LexError(T.Line, T.Col, 'entier hors limites: ' + T.Val);
      T.IntVal := MaxLongInt;
    End;
    T.RealVal := T.IntVal;
  End;
End;

{ Chaine sur une seule ligne, sans echappement : `...` ou `...'
  (apostrophe inverse ouvrante) ou "..." }
Procedure LexScanString(Var T : TToken);
Var
  TooLong : Boolean;
  Quote   : Char;
  Closed  : Boolean;
Begin
  TooLong := False;
  Closed  := False;
  Quote   := LexCur;
  T.Kind := TK_STRING;
  T.Val  := '';
  LexNextChar;                           { delimiteur ouvrant }
  While (LexCur <> #10) And (LexCur <> LEX_EOF) And Not Closed Do
  Begin
    If (LexCur = Quote) Or ((Quote = '`') And (LexCur = '''')) Then
      Closed := True
    Else
    Begin
      If Length(T.Val) < MAX_STR Then
        T.Val := T.Val + LexCur
      Else If Not TooLong Then
      Begin
        LexError(T.Line, T.Col, 'chaine trop longue (max ' +
                ItoS(MAX_STR) + ' caracteres)');
        TooLong := True;                 { une seule erreur par chaine }
      End;
      LexNextChar;
    End;
  End;
  If Closed Then
    LexNextChar
  Else
    LexError(T.Line, T.Col, 'chaine non fermee');
End;

{ Commentaire : "comment" deja lu, ignore tout jusqu au ; inclus. }
Procedure LexSkipComment(StartLine, StartCol : Integer);
Begin
  While (LexCur <> ';') And (LexCur <> LEX_EOF) Do
    LexNextChar;
  If LexCur = ';' Then
    LexNextChar
  Else
    LexError(StartLine, StartCol,
            'commentaire non termine (point-virgule attendu)');
End;

{ Texte qui suit end : ignore jusqu a ; ou au point final (non
  consommes), a la fin du fichier, ou jusqu au mot end / else, dont le
  token est alors retourne dans T (retourne True). }
Function LexSkipEndComment(Var T : TToken) : Boolean;
Var
  Low  : TString;
  L, C : Integer;
Begin
  LexSkipEndComment := False;
  While True Do
  Begin
    If (LexCur = LEX_EOF) Or (LexCur = ';') Then Exit;
    If (LexCur = '.') And Not IsDigit(LexPeekChar) Then Exit;
    If IsLetter(LexCur) Then
    Begin
      L := LexLine;
      C := LexCol;
      Low := '';
      While IsLetter(LexCur) Or IsDigit(LexCur) Do
      Begin
        If Length(Low) < 255 Then Low := Low + LexCur;
        LexNextChar;
      End;
      Low := StrLower(Low);
      If (Low = 'end') Or (Low = 'else') Then
      Begin
        T.Kind := TK_KEYWORD;
        T.Val  := Low;
        T.Line := L;
        T.Col  := C;
        T.IntVal := 0;
        T.RealVal := 0;
        LexSkipEndComment := True;
        Exit;
      End;
    End
    Else
      LexNextChar;
  End;
End;

{ Un token brut, sans fusion de "go to" }
Procedure LexScanToken(Var T : TToken);
Var
  Done : Boolean;
  C    : Char;
Begin
  If LexAfterEnd Then
  Begin
    LexAfterEnd := False;
    If LexSkipEndComment(T) Then
    Begin
      LexAfterEnd := (T.Val = 'end');
      Exit;
    End;
  End;
  Done := False;
  Repeat
    While LexCur In [' ', #9, #10, #12, #13] Do
      LexNextChar;
    T.Line := LexLine;
    T.Col  := LexCol;
    T.Val  := '';
    T.IntVal := 0;
    T.RealVal := 0;
    C := LexCur;
    Done := True;
    If C = LEX_EOF Then
      T.Kind := TK_EOF
    Else If IsLetter(C) Then
    Begin
      LexScanIdent(T);
      If (T.Kind = TK_KEYWORD) And (T.Val = 'comment') Then
      Begin
        LexSkipComment(T.Line, T.Col);
        Done := False;
      End
      Else If (T.Kind = TK_KEYWORD) And (T.Val = 'end') Then
        LexAfterEnd := True;
    End
    Else If IsDigit(C) Or ((C = '.') And IsDigit(LexPeekChar)) Then
      LexScanNumber(T)
    Else If (C = '"') Or (C = '`') Then
      LexScanString(T)
    Else
    Begin
      T.Kind := TK_OP;
      T.Val  := C;
      Case C Of
        '+', '-', '^', '=', '#':
          LexNextChar;
        '/':
          Begin
            LexNextChar;
            If LexCur = '\' Then
            Begin
              T.Kind := TK_KEYWORD;      { /\ equivaut a and }
              T.Val  := 'and';
              LexNextChar;
            End;
          End;
        '\':
          Begin
            LexNextChar;
            If LexCur = '/' Then
            Begin
              T.Kind := TK_KEYWORD;      { \/ equivaut a or }
              T.Val  := 'or';
              LexNextChar;
            End
            Else
            Begin
              LexError(T.Line, T.Col, 'caractere invalide: \');
              Done := False;
            End;
          End;
        '~':
          Begin
            T.Kind := TK_KEYWORD;        { ~ equivaut a not }
            T.Val  := 'not';
            LexNextChar;
          End;
        '*':
          Begin
            LexNextChar;
            If LexCur = '*' Then
            Begin
              T.Val := '^';              { ** equivaut a ^ }
              LexNextChar;
            End;
          End;
        '<', '>':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := T.Val + '=';
              LexNextChar;
            End
            Else If (C = '<') And (LexCur = '>') Then
            Begin
              T.Val := '#';              { <> equivaut a # }
              LexNextChar;
            End;
          End;
        '!':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := '#';              { != equivaut a # }
              LexNextChar;
            End
            Else
            Begin
              LexError(T.Line, T.Col, 'caractere invalide: !');
              Done := False;
            End;
          End;
        ':':
          Begin
            LexNextChar;
            If LexCur = '=' Then
            Begin
              T.Val := ':=';
              LexNextChar;
            End
            Else
              T.Kind := TK_PUNCT;
          End;
        ';', ',', '(', ')', '[', ']', '.':
          Begin
            T.Kind := TK_PUNCT;
            LexNextChar;
          End;
      Else
        Begin
          If (C < ' ') Or (C > '~') Then
            LexError(T.Line, T.Col,
                    'caractere invalide: code ' + ItoS(Ord(C)))
          Else
            LexError(T.Line, T.Col, 'caractere invalide: ' + C);
          LexNextChar;
          Done := False;
        End;
      End;
    End;
  Until Done;
End;

{ Token suivant. "go" suivi de "to" devient le mot-cle unique goto. }
Procedure LexNextToken(Var T : TToken);
Var
  T2 : TToken;
Begin
  If LexPending Then
  Begin
    T := LexPendTok;
    LexPending := False;
  End
  Else
    LexScanToken(T);
  If (T.Kind = TK_IDENT) And (UpCaseStr(T.Val) = 'GO') Then
  Begin
    LexScanToken(T2);
    If (T2.Kind = TK_IDENT) And (UpCaseStr(T2.Val) = 'TO') Then
    Begin
      T.Kind := TK_KEYWORD;
      T.Val  := 'goto';
    End
    Else
    Begin
      LexPendTok := T2;
      LexPending := True;
    End;
  End;
  Inc(TokenCount);
End;

{ Mode debug -d : une ligne par token }
Procedure PrintToken(Const T : TToken);
Begin
  Write(T.Line:5, ':', T.Col:3, ' ', TokenKindName(T.Kind):8);
  Case T.Kind Of
    TK_INTEGER : WriteLn(' ', T.IntVal);
    TK_REAL    : WriteLn(' ', T.RealVal:0:6, '  (', T.Val, ')');
    TK_STRING  : WriteLn(' "', T.Val, '"');
    TK_EOF     : WriteLn;
  Else
    WriteLn(' ', T.Val);
  End;
End;

Procedure PhaseLex;
Var
  T : TToken;
Begin
  LexInit;
  Repeat
    LexNextToken(T);
    If Opts.DebugMode Then PrintToken(T);
  Until T.Kind = TK_EOF;
  If Opts.Verbose Then
  Begin
    If LexCol = 1 Then Dec(LexLine);   { dernier octet = fin de ligne }
    WriteLn('  ', Opts.SrcFile, ': ', LexLine, ' ligne(s), ',
            TokenCount - 1, ' token(s)');
  End;
  LexClose;
End;

{ ============================================================
  SECTION 7 - TYPES ALGOL ET TABLE DES SYMBOLES (TODO 05, 06)
  ============================================================ }

{ ============================================================
  SECTION 8 - PARSEUR ET GENERATEUR DE CODE (TODO 09 a 18)
  ============================================================ }
Procedure PhaseParse;
Begin
  { A faire : TODO 09 a 18 }
End;

{ ============================================================
  SECTION 9 - CODE INTERNE ET LISTING ASM OPTIONNEL (TODO 07, 08)
  ============================================================ }
Procedure PhaseCodegen;
Begin
  { A faire : TODO 07 et 08 }
End;

{ ============================================================
  SECTION 10 - ENCODEUR BINAIRE x86-32 (TODO 19)
  ============================================================ }
Procedure PhaseEncode;
Begin
  { A faire : TODO 19 }
End;

{ ============================================================
  SECTION 11 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 20, 21)
  ============================================================ }
Procedure PhaseWrite;
Begin
  { A faire : TODO 20 et 21 }
End;

{ ============================================================
  SECTION 12 - RUNTIME ALGOL 60 POUR WIN32 (TODO 22)
  ============================================================ }

{ ============================================================
  SECTION 13 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  { A faire : TODO 23 et 24 }
End;

{ ============================================================
  SECTION 14 - PIPELINE PRINCIPAL (TODO 01, 24)
  ============================================================ }
Procedure RunPhase(P : TPhase);
Begin
  If Opts.Verbose Then
    WriteLn('AL60CW32: ', PhaseName(P));
  Case P Of
    PH_LEX     : PhaseLex;
    PH_PARSE   : PhaseParse;
    PH_CODEGEN : PhaseCodegen;
    PH_ENCODE  : PhaseEncode;
    PH_WRITE   : PhaseWrite;
    PH_REPORT  : PhaseReport;
  End;
End;

Procedure Run;
Var
  P : TPhase;
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  LexQuiet   := False;
  If Opts.Verbose Then
  Begin
    ShowBanner;
    WriteLn('  source : ', Opts.SrcFile);
    If Opts.EmitExe Then
      WriteLn('  .EXE   : ', Opts.OutFile);
    If Opts.EmitObj Then
      WriteLn('  .OBJ   : ', Opts.OutFile);
    If Opts.EmitAsm Then
      WriteLn('  .ASM   : ', Opts.AsmFile);
  End;
  For P := PH_LEX To PH_REPORT Do
    RunPhase(P);
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
BEGIN
  ParseArgs;
  Run;
END.
