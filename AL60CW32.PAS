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

  ETAT : TODO 01 a 07 implementes (squelette, pipeline en 6 phases,
         options de ligne de commande, constantes, limites et nommage,
         lexeur, types et conversions, table des symboles, code interne
         et listing .ASM) ; TODO 08 a 25 a faire.

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

  TODO 05 - TYPES DE DONNEES ET CONVERSIONS (32 BITS) [IMPLEMENTE]
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
            Realise : table des types (TypeAdd, TypeInit : integer 4
              octets, real 8, Boolean 4, string, label, switch,
              procedure, array 4) ; TypeValid, TypeName, TypeSizeof,
              TypeIsReal, TypeIsNumeric, TypeIsArith, TypeIsCondition
              (un entier utilise comme condition est vrai s'il est
              different de zero), TypeFromKeyword, TypeFromToken
            TypeConversion : CV_NONE, CV_INT_TO_REAL (integer et Boolean
              vers real), CV_REAL_TO_INT (arrondi au plus proche),
              CV_INT_TO_BOOL (<> 0), CV_ERROR (real vers Boolean, string,
              label, switch, procedure et array dans une expression) ;
              TypeConvNote donne le texte de l'avertissement des
              conversions implicites (real -> integer, integer <->
              Boolean, Boolean -> real)
            Types des operateurs : TypeArith (addition, soustraction,
              multiplication), TypeDivide (/ :
              toujours real), TypeIntDiv (div : integer, operandes
              integer ou Boolean), TypePower (^ : integer si les deux
              operandes sont integer et l'exposant n'est pas une
              constante negative, sinon real), TypeRelational (Boolean)
            Mode de passage d'un parametre : value (PM_VALUE) ou par nom
              (PM_NAME, thunk, mode par defaut du rapport)

  TODO 06 - TABLE DES SYMBOLES ET PORTEES [IMPLEMENTE]
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
            Realise : TSymKind (SK_VAR, SK_OWN, SK_ARRAY, SK_PROC,
              SK_FUNC pour une procedure typee, SK_LABEL, SK_SWITCH,
              SK_PARAM_VALUE, SK_PARAM_NAME) et TStorage (SC_GLOBAL,
              SC_LOCAL, SC_PARAM) ; SymAdd, SymFind, SymFindInScope,
              SymEnterScope, SymEnterProc, SymLeaveScope ; noms
              insensibles a la casse ; blocs freres declarant le meme
              nom : suffixe __n (UniqueMangle) ; variables du niveau 0
              dans .data, locales [EBP-n] arrondies a 4 octets, cellule
              de resultat d'une fonction, parametres [EBP+8] (ou [EBP+12]
              avec un lien statique pour les procedures imbriquees),
              parametre par nom sur 8 octets (thunk + BP de l'appelant) ;
              specifications "value" et de type des parametres
              (SymMarkValue, SymSetParamType, SymLayoutParams) ;
              etiquettes : SymRefLabel (renvoi avant), SymDefLabel,
              etiquette non definie reportee sur le bloc englobant,
              erreur si elle n'existe nulle part, avertissement si elle
              est inutilisee ; variable inconnue : SymImplicit
              (avertissement, integer global) ; copies persistantes des
              parametres a la fermeture du corps de la procedure

  TODO 07 - CODE INTERNE ET LISTING .ASM [IMPLEMENTE]
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
            Realise : TReg (EAX..EDI, AX, AL, CL, DL, BL), TOperandKind
              (registre, immediat, memoire [Sym+Base+Index*Echelle+Depl]
              avec taille, etiquette, OFFSET, ST(i)), TOp (88 operations :
              MOV MOVZX LEA PUSH POP, arithmetique, logique, decalages,
              SETcc, Jcc, CALL RET REP STOSD et x87), listes CodeTab et
              DeferTab (MoveToDeferred deplace les procedures et thunks
              apres le programme), table des noms avec hachage (Intern),
              pseudo-instructions OP_LABEL, OP_COMMENT, OP_BLANK ;
              InstrText ecrit une instruction en syntaxe MASM ; la table
              des donnees (TDataItem : zeros, chaines, entiers, reels,
              tables d'adresses) est ecrite par WriteListing, ses
              constructeurs sont l'objet du TODO 08 ; PhaseCodegen ecrit
              le listing seulement avec -asm et, avec -d, affiche le code
              interne ; en -v, nombre d'instructions et de noms

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
Const
  { Indices des types primitifs Algol 60 dans TypeTab }
  TY_UNKNOWN       = -1;   { type indetermine (apres une erreur)      }
  TY_IDX_INTEGER   = 0;    { entier 32 bits signe                      }
  TY_IDX_REAL      = 1;    { flottant 64 bits (x87)                    }
  TY_IDX_BOOLEAN   = 2;    { 0 ou 1 dans un DWORD                      }
  TY_IDX_STRING    = 3;    { pointeur vers une chaine litterale        }
  TY_IDX_LABEL     = 4;    { etiquette (adresse de code)               }
  TY_IDX_SWITCH    = 5;    { aiguillage (adresse de table)             }
  TY_IDX_PROCEDURE = 6;    { procedure sans valeur de retour           }
  TY_IDX_ARRAY     = 7;    { descripteur de tableau (pointeur)         }
  TY_PRIM_COUNT    = 8;

Type
  TTypeKind = (
    TYK_INTEGER,
    TYK_REAL,
    TYK_BOOLEAN,
    TYK_STRING,
    TYK_LABEL,
    TYK_SWITCH,
    TYK_PROCEDURE,
    TYK_ARRAY
  );

  TTypeRec = Record
    Kind : TTypeKind;
    Name : String[12];
    Size : Integer;          { taille en octets d une valeur }
  End;

  { Conversion implicite a generer pour passer d un type a un autre }
  TConv = (
    CV_NONE,           { meme representation : rien a generer          }
    CV_INT_TO_REAL,    { FILD : entier ou booleen -> real              }
    CV_REAL_TO_INT,    { FISTP : real -> integer, arrondi au plus pres }
    CV_INT_TO_BOOL,    { TEST / SETNE : integer -> Boolean (<> 0)      }
    CV_ERROR           { conversion interdite                          }
  );

  { Mode de passage d un parametre de procedure }
  TParamMode = (
    PM_VALUE,          { value : copie de la valeur sur la pile        }
    PM_NAME            { par defaut : thunk reevalue a chaque acces    }
  );

Var
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

Function TypeAdd(K : TTypeKind; Const Name : TString;
                 Size : Integer) : Integer;
Begin
  If TypeCount >= MAX_TYPE Then
    FatalError('table des types pleine');
  TypeTab[TypeCount].Kind := K;
  TypeTab[TypeCount].Name := Name;
  TypeTab[TypeCount].Size := Size;
  TypeAdd := TypeCount;
  Inc(TypeCount);
End;

{ Enregistre les types primitifs, dans l ordre des TY_IDX_* }
Procedure TypeInit;
Begin
  TypeCount := 0;
  TypeAdd(TYK_INTEGER,   'integer',   ABI_WORD_SIZE);
  TypeAdd(TYK_REAL,      'real',      ABI_REAL_SIZE);
  TypeAdd(TYK_BOOLEAN,   'Boolean',   ABI_WORD_SIZE);
  TypeAdd(TYK_STRING,    'string',    ABI_WORD_SIZE);
  TypeAdd(TYK_LABEL,     'label',     ABI_WORD_SIZE);
  TypeAdd(TYK_SWITCH,    'switch',    ABI_WORD_SIZE);
  TypeAdd(TYK_PROCEDURE, 'procedure', ABI_WORD_SIZE);
  TypeAdd(TYK_ARRAY,     'array',     ABI_WORD_SIZE);
End;

Function TypeValid(T : Integer) : Boolean;
Begin
  TypeValid := (T >= 0) And (T < TypeCount);
End;

Function TypeName(T : Integer) : TString;
Begin
  If TypeValid(T) Then
    TypeName := TypeTab[T].Name
  Else
    TypeName := '?';
End;

{ Taille en octets : integer=4, real=8, Boolean=4, pointeurs=4 }
Function TypeSizeof(T : Integer) : Integer;
Begin
  If TypeValid(T) Then
    TypeSizeof := TypeTab[T].Size
  Else
    TypeSizeof := ABI_WORD_SIZE;
End;

Function TypeIsReal(T : Integer) : Boolean;
Begin
  TypeIsReal := (T = TY_IDX_REAL);
End;

Function TypeIsNumeric(T : Integer) : Boolean;
Begin
  TypeIsNumeric := (T = TY_IDX_INTEGER) Or (T = TY_IDX_REAL);
End;

{ Types admis dans une expression arithmetique ou relationnelle :
  le Boolean est stocke comme 0 ou 1 et se comporte comme un entier. }
Function TypeIsArith(T : Integer) : Boolean;
Begin
  TypeIsArith := (T = TY_IDX_INTEGER) Or (T = TY_IDX_REAL) Or
                 (T = TY_IDX_BOOLEAN);
End;

{ Condition de if / while / expression conditionnelle : un entier
  est vrai s il est different de zero. }
Function TypeIsCondition(T : Integer) : Boolean;
Begin
  TypeIsCondition := (T = TY_IDX_BOOLEAN) Or (T = TY_IDX_INTEGER);
End;

{ Type d un mot-cle de declaration : integer, real, boolean, string }
Function TypeFromKeyword(Const Kw : TString) : Integer;
Begin
  If Kw = 'integer' Then
    TypeFromKeyword := TY_IDX_INTEGER
  Else If Kw = 'real' Then
    TypeFromKeyword := TY_IDX_REAL
  Else If Kw = 'boolean' Then
    TypeFromKeyword := TY_IDX_BOOLEAN
  Else If Kw = 'string' Then
    TypeFromKeyword := TY_IDX_STRING
  Else
    TypeFromKeyword := TY_UNKNOWN;
End;

{ Type d un litteral : 42, 3.14, `abc`, true, false }
Function TypeFromToken(Const T : TToken) : Integer;
Begin
  Case T.Kind Of
    TK_INTEGER : TypeFromToken := TY_IDX_INTEGER;
    TK_REAL    : TypeFromToken := TY_IDX_REAL;
    TK_STRING  : TypeFromToken := TY_IDX_STRING;
    TK_KEYWORD :
      If (T.Val = 'true') Or (T.Val = 'false') Then
        TypeFromToken := TY_IDX_BOOLEAN
      Else
        TypeFromToken := TY_UNKNOWN;
  Else
    TypeFromToken := TY_UNKNOWN;
  End;
End;

{ Conversion implicite pour affecter un From a un Dest :
    integer -> real  : CV_INT_TO_REAL (FILD)
    real -> integer  : CV_REAL_TO_INT (arrondi au plus proche)
    integer -> Boolean : CV_INT_TO_BOOL (<> 0)
    Boolean -> integer : CV_NONE (0 ou 1)
    Boolean -> real  : CV_INT_TO_REAL
    real -> Boolean, string, label, switch, procedure, array : erreur }
Function TypeConversion(From, Dest : Integer) : TConv;
Begin
  TypeConversion := CV_ERROR;
  If (Not TypeValid(From)) Or (Not TypeValid(Dest)) Then
    TypeConversion := CV_NONE
  Else If From = Dest Then
    TypeConversion := CV_NONE
  Else If Dest = TY_IDX_INTEGER Then
  Begin
    If From = TY_IDX_REAL Then
      TypeConversion := CV_REAL_TO_INT
    Else If From = TY_IDX_BOOLEAN Then
      TypeConversion := CV_NONE;
  End
  Else If Dest = TY_IDX_REAL Then
  Begin
    If (From = TY_IDX_INTEGER) Or (From = TY_IDX_BOOLEAN) Then
      TypeConversion := CV_INT_TO_REAL;
  End
  Else If Dest = TY_IDX_BOOLEAN Then
  Begin
    If From = TY_IDX_INTEGER Then
      TypeConversion := CV_INT_TO_BOOL;
  End;
End;

Function TypeAssignable(From, Dest : Integer) : Boolean;
Begin
  TypeAssignable := (TypeConversion(From, Dest) <> CV_ERROR);
End;

{ Texte de l avertissement d une conversion implicite ('' si la
  conversion est sans reserve ou interdite) }
Function TypeConvNote(From, Dest : Integer) : TString;
Begin
  TypeConvNote := '';
  If TypeConversion(From, Dest) = CV_ERROR Then Exit;
  If (From = TY_IDX_REAL) And (Dest = TY_IDX_INTEGER) Then
    TypeConvNote := 'real converti en integer: arrondi au plus proche'
  Else If (From = TY_IDX_INTEGER) And (Dest = TY_IDX_BOOLEAN) Then
    TypeConvNote := 'integer converti en Boolean (<> 0)'
  Else If (From = TY_IDX_BOOLEAN) And (Dest = TY_IDX_INTEGER) Then
    TypeConvNote := 'Boolean converti en integer (0 ou 1)'
  Else If (From = TY_IDX_BOOLEAN) And (Dest = TY_IDX_REAL) Then
    TypeConvNote := 'Boolean converti en real (0 ou 1)';
End;

{ Type resultat de A op B pour + - * : real des qu un operande est
  real, sinon integer. TY_UNKNOWN si un operande n est pas arithmetique. }
Function TypeArith(A, B : Integer) : Integer;
Begin
  If (Not TypeValid(A)) Or (Not TypeValid(B)) Then
    TypeArith := TY_UNKNOWN
  Else If (Not TypeIsArith(A)) Or (Not TypeIsArith(B)) Then
    TypeArith := TY_UNKNOWN
  Else If (A = TY_IDX_REAL) Or (B = TY_IDX_REAL) Then
    TypeArith := TY_IDX_REAL
  Else
    TypeArith := TY_IDX_INTEGER;
End;

{ A / B : toujours real (Revised Report, 3.3.4.2) }
Function TypeDivide(A, B : Integer) : Integer;
Begin
  If (TypeArith(A, B) = TY_UNKNOWN) Then
    TypeDivide := TY_UNKNOWN
  Else
    TypeDivide := TY_IDX_REAL;
End;

{ A div B : quotient entier, operandes integer (un Boolean vaut 0 ou 1) }
Function TypeIntDiv(A, B : Integer) : Integer;
Begin
  If (Not TypeIsArith(A)) Or (Not TypeIsArith(B)) Or
     (A = TY_IDX_REAL) Or (B = TY_IDX_REAL) Then
    TypeIntDiv := TY_UNKNOWN
  Else
    TypeIntDiv := TY_IDX_INTEGER;
End;

{ A ^ B (Revised Report, 3.3.4.3) : integer si A et B sont integer et si
  l exposant n est pas une constante negative (ExpSign < 0), sinon
  real. ExpSign : -1 constante negative, 0 inconnu ou nul, 1 positif. }
Function TypePower(A, B : Integer; ExpSign : Integer) : Integer;
Begin
  If (Not TypeIsArith(A)) Or (Not TypeIsArith(B)) Then
    TypePower := TY_UNKNOWN
  Else If (A = TY_IDX_REAL) Or (B = TY_IDX_REAL) Or (ExpSign < 0) Then
    TypePower := TY_IDX_REAL
  Else
    TypePower := TY_IDX_INTEGER;
End;

{ Relationnels = # < <= > >= : operandes arithmetiques, resultat Boolean }
Function TypeRelational(A, B : Integer) : Integer;
Begin
  If TypeArith(A, B) = TY_UNKNOWN Then
    TypeRelational := TY_UNKNOWN
  Else
    TypeRelational := TY_IDX_BOOLEAN;
End;

{ Mode debug -d : liste des types enregistres }
Procedure TypeDump;
Var
  I : Integer;
Begin
  WriteLn('Types (', TypeCount, ') :');
  For I := 0 To TypeCount - 1 Do
    WriteLn('  ', I:2, '  ', Copy(TypeTab[I].Name + '          ', 1, 10),
            TypeTab[I].Size:3, ' octets');
End;

{ ============================================================
  TABLE DES SYMBOLES ET PORTEES (TODO 06)

  Allocation des variables :
    - niveau 0 (programme principal, y compris ses blocs imbriques) :
      donnees statiques dans .data, noms ASM uniques ; les procedures
      du niveau 0 y accedent directement, sans lien statique
    - variables d une procedure : locales [EBP-n]
    - parametres : [EBP+n], le premier en [EBP+8] ; les procedures
      declarees dans une autre procedure recoivent en plus un lien
      statique (BP de la procedure englobante) en [EBP+8], les
      parametres commencent alors en [EBP+12]
    - parametre par valeur : taille du type ; parametre par nom :
      8 octets (adresse du thunk + BP de l appelant)
  ============================================================ }
Const
  SYM_NAME_MAX    = 63;
  PARAM_NAME_SIZE = 8;
  MAX_IMPLICIT    = {$IFDEF FPC}256{$ELSE}16{$ENDIF};
  SYM_TOTAL       = MAX_SYM + MAX_IMPLICIT;
  MAX_PARAM_SYMS  = {$IFDEF FPC}2048{$ELSE}64{$ENDIF};

Type
  TName    = String[SYM_NAME_MAX];
  TMangled = String[127];

  TSymKind = (
    SK_VAR,           { variable scalaire                          }
    SK_OWN,           { variable scalaire own (persistante)        }
    SK_ARRAY,         { tableau                                    }
    SK_PROC,          { procedure sans valeur de retour            }
    SK_FUNC,          { procedure typee (fonction)                 }
    SK_LABEL,         { etiquette de goto                         }
    SK_SWITCH,        { aiguillage                                 }
    SK_PARAM_VALUE,   { parametre value                            }
    SK_PARAM_NAME     { parametre par nom (defaut)                 }
  );

  TStorage = (
    SC_NONE,          { pas de stockage de donnees                 }
    SC_GLOBAL,        { .data : label Mangled                      }
    SC_LOCAL,         { pile : [EBP + Offset], Offset < 0          }
    SC_PARAM          { pile : [EBP + Offset], Offset > 0          }
  );

  TSymRec = Record
    Name       : TName;       { identificateur tel qu ecrit          }
    Key        : TName;       { identificateur en majuscules         }
    Mangled    : TMangled;    { nom ASM (SC_GLOBAL, procedures)      }
    Kind       : TSymKind;
    TypeIdx    : Integer;     { type, ou type de retour / d element  }
    Storage    : TStorage;
    Offset     : LongInt;     { decalage par rapport a EBP           }
    ScopeId    : Integer;     { identifiant unique de la portee      }
    Level      : Integer;     { niveau d imbrication des procedures  }
    IsOwn      : Boolean;
    IsWritten  : Boolean;     { parametre par nom : affecte dans le corps }
    IsDefined  : Boolean;     { etiquette : definie ?                }
    IsUsed     : Boolean;     { etiquette : referencee ?             }
    Line       : Integer;
    Col        : Integer;
    ArrDims    : Integer;     { tableau : nombre de dimensions       }
    ArrLo      : Array[1..MAX_ARRAY_DIM] Of LongInt;
    ArrHi      : Array[1..MAX_ARRAY_DIM] Of LongInt;
    ArrDynamic : Boolean;     { tableau : bornes calculees a l exec. }
    ElemType   : Integer;     { tableau : type des elements          }
    ArrBytes   : LongInt;     { tableau : octets de donnees (bornes cst) }
    ArrDataOfs : LongInt;     { tableau local : decalage des donnees  }
    ArrDescOfs : LongInt;     { tableau local : decalage du descripteur }
    ParamCount : Integer;     { procedure : nombre de parametres     }
    ParamSym   : Array[1..MAX_PARAM] Of Integer;
    ParamBytes : Integer;     { procedure : taille des parametres    }
    ParamIdx   : Integer;     { parametre : rang (1..n)              }
    SwitchCount: Integer;     { switch : nombre de designateurs      }
  End;

  TScopeRec = Record
    FirstSym   : Integer;     { premier symbole de la portee         }
    Id         : Integer;     { identifiant unique                   }
    IsProc     : Boolean;     { portee d une procedure ?             }
    ProcSym    : Integer;     { symbole de la procedure (ou -1)      }
    SavedLocal : LongInt;     { LocalOfs a l entree                  }
    SavedProc  : Integer;     { CurProcScope a l entree              }
    FrameSize  : LongInt;     { procedure : octets de locales max.   }
    RetOfs     : LongInt;     { fonction : cellule du resultat       }
  End;

  TUseRec = Record
    Base  : TMangled;
    Count : Integer;
  End;

Var
  { SymTab : [0..MAX_SYM-1] pile des symboles visibles, puis les
    symboles implicites, puis (a partir de SYM_TOTAL) les copies des
    parametres des procedures dont le corps est ferme : un appel
    ulterieur en a besoin (nom, mode, type, decalage). }
  SymTab       : Array[0..SYM_TOTAL + MAX_PARAM_SYMS - 1] Of TSymRec;
  ParamSymCount: Integer;
  SymCount     : Integer;     { symboles de la pile (0..SymCount-1)  }
  ImpCount     : Integer;     { symboles implicites (MAX_SYM..)      }
  ScopeTab     : Array[0..MAX_SCOPE - 1] Of TScopeRec;
  ScopeTop     : Integer;     { nombre de portees ouvertes           }
  ScopeSeq     : Integer;     { compteur d identifiants de portee    }
  CurLevel     : Integer;     { niveau de procedure courant (0=main) }
  CurProcScope : Integer;     { portee de la procedure courante      }
  LocalOfs     : LongInt;     { octets de locales alloues            }
  UseTab       : Array[0..SYM_TOTAL - 1] Of TUseRec;
  UseCount     : Integer;

{ Nom ASM unique : le premier usage garde Base, les suivants recoivent
  un suffixe __n (blocs freres declarant le meme identificateur). }
Function UniqueMangle(Const Base : TMangled) : TMangled;
Var
  I : Integer;
Begin
  For I := 0 To UseCount - 1 Do
    If UseTab[I].Base = Base Then
    Begin
      Inc(UseTab[I].Count);
      UniqueMangle := Base + '__' + ItoS(UseTab[I].Count);
      Exit;
    End;
  If UseCount >= SYM_TOTAL Then
    FatalError('table des noms ASM pleine');
  UseTab[UseCount].Base  := Base;
  UseTab[UseCount].Count := 1;
  Inc(UseCount);
  UniqueMangle := Base;
End;

Function SymKindName(K : TSymKind) : TString;
Begin
  Case K Of
    SK_VAR         : SymKindName := 'var';
    SK_OWN         : SymKindName := 'own';
    SK_ARRAY       : SymKindName := 'array';
    SK_PROC        : SymKindName := 'proc';
    SK_FUNC        : SymKindName := 'func';
    SK_LABEL       : SymKindName := 'label';
    SK_SWITCH      : SymKindName := 'switch';
    SK_PARAM_VALUE : SymKindName := 'param-value';
    SK_PARAM_NAME  : SymKindName := 'param-name';
  End;
End;

Function StorageName(S : TStorage) : TString;
Begin
  Case S Of
    SC_NONE   : StorageName := '-';
    SC_GLOBAL : StorageName := 'global';
    SC_LOCAL  : StorageName := 'local';
    SC_PARAM  : StorageName := 'param';
  End;
End;

Procedure SymInit;
Begin
  SymCount     := 0;
  ImpCount     := 0;
  ScopeTop     := 0;
  ScopeSeq     := 0;
  CurLevel     := 0;
  CurProcScope := -1;
  LocalOfs     := 0;
  UseCount     := 0;
  ParamSymCount := 0;
End;

{ ---- Recherche ------------------------------------------------- }

Function SymMakeKey(Const Name : TString) : TName;
Begin
  SymMakeKey := Copy(UpCaseStr(Name), 1, SYM_NAME_MAX);
End;

{ Symbole visible le plus interne ; la pile masque les portees
  englobantes, puis les symboles implicites. -1 si introuvable. }
Function SymFind(Const Name : TString) : Integer;
Var
  I   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  SymFind := -1;
  For I := SymCount - 1 Downto 0 Do
    If SymTab[I].Key = Key Then
    Begin
      SymFind := I;
      Exit;
    End;
  For I := MAX_SYM To MAX_SYM + ImpCount - 1 Do
    If SymTab[I].Key = Key Then
    Begin
      SymFind := I;
      Exit;
    End;
End;

{ Symbole declare dans la portee courante seulement. -1 si absent. }
Function SymFindInScope(Const Name : TString) : Integer;
Var
  I, First : Integer;
  Key      : TName;
Begin
  SymFindInScope := -1;
  If ScopeTop = 0 Then Exit;
  Key   := SymMakeKey(Name);
  First := ScopeTab[ScopeTop - 1].FirstSym;
  For I := SymCount - 1 Downto First Do
    If SymTab[I].Key = Key Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
End;

{ ---- Portees et allocation de la pile --------------------------- }

Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('blocs trop imbriques (max ' + ItoS(MAX_SCOPE) + ')');
  Inc(ScopeSeq);
  ScopeTab[ScopeTop].FirstSym   := SymCount;
  ScopeTab[ScopeTop].Id         := ScopeSeq;
  ScopeTab[ScopeTop].IsProc     := False;
  ScopeTab[ScopeTop].ProcSym    := -1;
  ScopeTab[ScopeTop].SavedLocal := LocalOfs;
  ScopeTab[ScopeTop].SavedProc  := CurProcScope;
  ScopeTab[ScopeTop].FrameSize  := 0;
  ScopeTab[ScopeTop].RetOfs     := 0;
  Inc(ScopeTop);
End;

{ Reserve Size octets (arrondis a 4) dans les locales de la procedure
  courante et retourne le decalage negatif par rapport a EBP. }
Function SymAllocLocal(Size : Integer) : LongInt;
Begin
  If CurProcScope < 0 Then
    FatalError('erreur interne: locale hors procedure');
  LocalOfs := LocalOfs + ((Size + 3) And (Not 3));
  If LocalOfs > ScopeTab[CurProcScope].FrameSize Then
    ScopeTab[CurProcScope].FrameSize := LocalOfs;
  SymAllocLocal := -LocalOfs;
End;

{ Ouvre la portee du corps d une procedure deja ajoutee a la table.
  Les parametres sont ensuite ajoutes par SymAdd. }
Procedure SymEnterProc(ProcIdx : Integer);
Begin
  SymEnterScope;
  ScopeTab[ScopeTop - 1].IsProc  := True;
  ScopeTab[ScopeTop - 1].ProcSym := ProcIdx;
  Inc(CurLevel);
  CurProcScope := ScopeTop - 1;
  LocalOfs := 0;
  If SymTab[ProcIdx].Kind = SK_FUNC Then
    ScopeTab[CurProcScope].RetOfs :=
      SymAllocLocal(TypeSizeof(SymTab[ProcIdx].TypeIdx));
End;

{ Procedure dont le corps est en cours de compilation (ou -1) }
Function SymCurProc : Integer;
Begin
  If CurProcScope < 0 Then
    SymCurProc := -1
  Else
    SymCurProc := ScopeTab[CurProcScope].ProcSym;
End;

{ Octets de locales du corps courant (pour SUB ESP, n au prologue) }
Function SymFrameSize : LongInt;
Begin
  If CurProcScope < 0 Then
    SymFrameSize := 0
  Else
    SymFrameSize := ScopeTab[CurProcScope].FrameSize;
End;

{ Decalage [EBP+n] de la cellule du resultat d une fonction }
Function SymResultOfs : LongInt;
Begin
  If CurProcScope < 0 Then
    SymResultOfs := 0
  Else
    SymResultOfs := ScopeTab[CurProcScope].RetOfs;
End;

{ ---- Ajout de symboles ------------------------------------------ }

Function SymAdd(Const Name : TString; K : TSymKind; TypeIdx : Integer;
                IsOwn : Boolean; Line, Col : Integer) : Integer;
Var
  I, P : Integer;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: aucune portee ouverte');
  If Length(Name) > SYM_NAME_MAX Then
    ErrorAt(Line, Col, 'identificateur trop long (max ' +
            ItoS(SYM_NAME_MAX) + '): ' + Name);

  I := SymFindInScope(Name);
  If I >= 0 Then
  Begin
    ErrorAt(Line, Col, 'declaration en double: ' + Name);
    SymAdd := I;
    Exit;
  End;
  If (ScopeTop = 1) And (K <> SK_LABEL) Then
    For I := MAX_SYM To MAX_SYM + ImpCount - 1 Do
      If SymTab[I].Key = SymMakeKey(Name) Then
      Begin
        ErrorAt(Line, Col, 'declaree apres un usage implicite: ' + Name);
        SymAdd := I;
        Exit;
      End;
  If SymCount >= MAX_SYM Then
    FatalError('table des symboles pleine (max ' + ItoS(MAX_SYM) + ')');

  I := SymCount;
  Inc(SymCount);
  FillChar(SymTab[I], SizeOf(TSymRec), 0);
  SymTab[I].Name      := Copy(Name, 1, SYM_NAME_MAX);
  SymTab[I].Key       := SymMakeKey(Name);
  SymTab[I].Kind      := K;
  SymTab[I].TypeIdx   := TypeIdx;
  SymTab[I].Storage   := SC_NONE;
  SymTab[I].ScopeId   := ScopeTab[ScopeTop - 1].Id;
  SymTab[I].Level     := CurLevel;
  SymTab[I].IsOwn     := IsOwn Or (K = SK_OWN);
  SymTab[I].Line      := Line;
  SymTab[I].Col       := Col;

  Case K Of
    SK_VAR, SK_OWN, SK_ARRAY:
      If (CurLevel = 0) Or SymTab[I].IsOwn Then
      Begin
        SymTab[I].Storage := SC_GLOBAL;
        If SymTab[I].IsOwn And (K <> SK_ARRAY) Then
          SymTab[I].Mangled := UniqueMangle(MangleOwn(Name))
        Else If K = SK_ARRAY Then
          SymTab[I].Mangled := UniqueMangle(MangleArr(Name))
        Else
          SymTab[I].Mangled := UniqueMangle(MangleVar(Name));
      End
      Else
      Begin
        SymTab[I].Storage := SC_LOCAL;
        If K = SK_ARRAY Then
          SymTab[I].Offset := SymAllocLocal(ABI_WORD_SIZE)
        Else
          SymTab[I].Offset := SymAllocLocal(TypeSizeof(TypeIdx));
      End;
    SK_PROC, SK_FUNC:
      SymTab[I].Mangled := UniqueMangle(MangleProc(Name));
    SK_LABEL:
      SymTab[I].Mangled := UniqueMangle(MangleUserLabel(Name));
    SK_SWITCH:
      SymTab[I].Mangled := UniqueMangle(MangleSwitch(Name));
    SK_PARAM_VALUE, SK_PARAM_NAME:
      Begin
        P := SymCurProc;
        If P < 0 Then
          FatalError('erreur interne: parametre hors procedure');
        If SymTab[P].ParamCount >= MAX_PARAM Then
          ErrorAt(Line, Col, 'trop de parametres (max ' +
                  ItoS(MAX_PARAM) + ')')
        Else
        Begin
          Inc(SymTab[P].ParamCount);
          SymTab[P].ParamSym[SymTab[P].ParamCount] := I;
          SymTab[I].ParamIdx := SymTab[P].ParamCount;
        End;
        SymTab[I].Storage := SC_PARAM;
      End;
  End;
  SymAdd := I;
End;

{ Variable utilisee sans declaration : avertissement, puis integer
  global implicite visible de partout (x := 42). }
Function SymImplicit(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I : Integer;
Begin
  If ImpCount >= MAX_IMPLICIT Then
    FatalError('trop de variables implicites (max ' +
               ItoS(MAX_IMPLICIT) + ')');
  WarnAt(Line, Col, 'variable non declaree: ' + Name +
         ' (declaree integer)');
  I := MAX_SYM + ImpCount;
  Inc(ImpCount);
  FillChar(SymTab[I], SizeOf(TSymRec), 0);
  SymTab[I].Name    := Copy(Name, 1, SYM_NAME_MAX);
  SymTab[I].Key     := SymMakeKey(Name);
  SymTab[I].Kind    := SK_VAR;
  SymTab[I].TypeIdx := TY_IDX_INTEGER;
  SymTab[I].Storage := SC_GLOBAL;
  SymTab[I].ScopeId := 1;
  SymTab[I].Level   := 0;
  SymTab[I].Line    := Line;
  SymTab[I].Col     := Col;
  SymTab[I].Mangled := UniqueMangle(MangleVar(Name));
  SymImplicit := I;
End;

{ ---- Parametres de procedure ------------------------------------ }

Function SymFindParam(ProcIdx : Integer; Const Name : TString) : Integer;
Var
  K   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  SymFindParam := -1;
  For K := 1 To SymTab[ProcIdx].ParamCount Do
    If SymTab[SymTab[ProcIdx].ParamSym[K]].Key = Key Then
    Begin
      SymFindParam := SymTab[ProcIdx].ParamSym[K];
      Exit;
    End;
End;

{ "value a, b ;" : passe le parametre par valeur }
Function SymMarkValue(ProcIdx : Integer; Const Name : TString) : Boolean;
Var
  S : Integer;
Begin
  S := SymFindParam(ProcIdx, Name);
  If S >= 0 Then
    SymTab[S].Kind := SK_PARAM_VALUE;
  SymMarkValue := (S >= 0);
End;

{ "integer a ;" : specification de type d un parametre }
Function SymSetParamType(ProcIdx : Integer; Const Name : TString;
                         T : Integer) : Boolean;
Var
  S : Integer;
Begin
  S := SymFindParam(ProcIdx, Name);
  If S >= 0 Then
    SymTab[S].TypeIdx := T;
  SymSetParamType := (S >= 0);
End;

Function SymParamSize(S : Integer) : Integer;
Begin
  If SymTab[S].TypeIdx = TY_IDX_ARRAY Then
    SymParamSize := ABI_WORD_SIZE          { adresse du descripteur }
  Else If SymTab[S].Kind = SK_PARAM_NAME Then
    SymParamSize := PARAM_NAME_SIZE        { thunk + BP appelant    }
  Else
    SymParamSize := (TypeSizeof(SymTab[S].TypeIdx) + 3) And (Not 3);
End;

{ A appeler apres les specifications : calcule les decalages [EBP+n]
  (le premier parametre en EBP+8, apres EBP et l adresse de retour,
  decale de 4 si un lien statique est recu) et ParamBytes. }
Procedure SymLayoutParams(ProcIdx : Integer);
Var
  K, S : Integer;
  Ofs  : LongInt;
Begin
  Ofs := ABI_PARAM_BASE;
  If SymTab[ProcIdx].Level >= 1 Then
    Ofs := Ofs + ABI_WORD_SIZE;           { lien statique }
  For K := 1 To SymTab[ProcIdx].ParamCount Do
  Begin
    S := SymTab[ProcIdx].ParamSym[K];
    SymTab[S].Offset := Ofs;
    Ofs := Ofs + SymParamSize(S);
  End;
  SymTab[ProcIdx].ParamBytes := Ofs - ABI_PARAM_BASE;
End;

{ ---- Etiquettes ------------------------------------------------- }

{ Reference "goto nom" : retrouve l etiquette visible, ou cree une
  etiquette pas encore definie dans la portee courante (renvoi avant). }
Function SymRefLabel(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I   : Integer;
  Key : TName;
Begin
  Key := SymMakeKey(Name);
  For I := SymCount - 1 Downto 0 Do
    If (SymTab[I].Key = Key) And (SymTab[I].Kind = SK_LABEL) Then
    Begin
      SymTab[I].IsUsed := True;
      SymRefLabel := I;
      Exit;
    End;
  I := SymAdd(Name, SK_LABEL, TY_IDX_LABEL, False, Line, Col);
  SymTab[I].IsUsed := True;
  SymRefLabel := I;
End;

{ Definition "nom :" devant une instruction }
Function SymDefLabel(Const Name : TString; Line, Col : Integer) : Integer;
Var
  I : Integer;
Begin
  I := SymFindInScope(Name);
  If I >= 0 Then
  Begin
    If (SymTab[I].Kind = SK_LABEL) And (Not SymTab[I].IsDefined) Then
    Begin
      SymTab[I].IsDefined := True;     { fin d un renvoi avant }
      SymTab[I].Line := Line;
      SymTab[I].Col  := Col;
    End
    Else
      ErrorAt(Line, Col, 'etiquette dupliquee: ' + Name);
    SymDefLabel := I;
    Exit;
  End;
  I := SymAdd(Name, SK_LABEL, TY_IDX_LABEL, False, Line, Col);
  SymTab[I].IsDefined := True;
  SymDefLabel := I;
End;

{ ---- Impression et fermeture ------------------------------------ }

Procedure SymDumpScope(Scope : Integer);
Var
  I : Integer;
Begin
  WriteLn('Portee ', ScopeTab[Scope].Id, ' (niveau ', CurLevel,
          '), locales ', ScopeTab[Scope].FrameSize, ' octets :');
  For I := ScopeTab[Scope].FirstSym To SymCount - 1 Do
    WriteLn('  ', SymTab[I].Name, ' ', SymKindName(SymTab[I].Kind), ' ',
            TypeName(SymTab[I].TypeIdx), ' ', StorageName(SymTab[I].Storage),
            ' ', SymTab[I].Offset, ' ', SymTab[I].Mangled);
End;

{ Ferme la portee courante : verifie les etiquettes, libere les
  symboles et restaure l etat de la pile. }
Procedure SymLeaveScope;
Var
  I, S, Dest, P : Integer;
  CanHoist      : Boolean;
Begin
  If ScopeTop = 0 Then
    FatalError('erreur interne: fermeture sans portee ouverte');
  S := ScopeTop - 1;
  If Opts.DebugMode Then SymDumpScope(S);
  { Un renvoi avant vers une etiquette pas encore definie dans un
    bloc interne passe dans la portee englobante (meme procedure) ;
    sinon l'etiquette doit etre definie ici. }
  { parametres d'une procedure : copies conservees pour les appels }
  If ScopeTab[S].IsProc Then
  Begin
    P := ScopeTab[S].ProcSym;
    For I := 1 To SymTab[P].ParamCount Do
    Begin
      If ParamSymCount >= MAX_PARAM_SYMS Then
        FatalError('trop de parametres de procedures (max ' +
                   ItoS(MAX_PARAM_SYMS) + ')');
      SymTab[SYM_TOTAL + ParamSymCount] :=
        SymTab[SymTab[P].ParamSym[I]];
      SymTab[P].ParamSym[I] := SYM_TOTAL + ParamSymCount;
      Inc(ParamSymCount);
    End;
  End;
  CanHoist := (Not ScopeTab[S].IsProc) And (ScopeTop >= 2);
  Dest := ScopeTab[S].FirstSym;
  For I := ScopeTab[S].FirstSym To SymCount - 1 Do
  Begin
    If SymTab[I].Kind = SK_LABEL Then
    Begin
      If Not SymTab[I].IsDefined Then
      Begin
        If CanHoist Then
        Begin
          SymTab[Dest] := SymTab[I];
          SymTab[Dest].ScopeId := ScopeTab[S - 1].Id;
          Inc(Dest);
        End
        Else
          ErrorAt(SymTab[I].Line, SymTab[I].Col,
                  'etiquette non definie: ' + SymTab[I].Name +
                  ' (ou definie dans un bloc interne)');
      End
      Else If Not SymTab[I].IsUsed Then
        WarnAt(SymTab[I].Line, SymTab[I].Col,
               'etiquette non utilisee: ' + SymTab[I].Name);
    End;
  End;
  SymCount := Dest;
  LocalOfs := ScopeTab[S].SavedLocal;
  If ScopeTab[S].IsProc Then
    Dec(CurLevel);
  CurProcScope := ScopeTab[S].SavedProc;
  Dec(ScopeTop);
End;

{ ============================================================
  CODE INTERNE ET LISTING ASM (TODO 07)

  Le generateur produit une liste d'instructions 80386 structurees
  (CodeTab), consommee par le listing .ASM optionnel (WriteListing)
  puis par l'encodeur binaire (TODO 19). Les procedures et les thunks
  sont ecrits dans une seconde liste (DeferTab) placee apres le
  programme principal.

  Conventions de generation :
    - integer, Boolean, pointeurs : EAX ; real : ST(0) ; les valeurs
      intermediaires sont rangees sur la pile machine (jamais en
      registre a travers un appel)
    - ECX, EDX, ESI, EDI : temporaires ; EBP : cadre ; ESP : pile
    - appels de procedure : voir TODO 16 ; routines du
      runtime : arguments dans les registres (TODO 22)
  ============================================================ }
Const
  MAX_CODE      = {$IFDEF FPC}262144{$ELSE}2048{$ENDIF};
  MAX_NAMES     = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};
  MAX_ASMSTR    = {$IFDEF FPC}4096{$ELSE}64{$ENDIF};
  MAX_DATAITEMS = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  MAX_TABENT    = {$IFDEF FPC}8192{$ELSE}256{$ENDIF};
  NAME_HASH     = {$IFDEF FPC}32768{$ELSE}1024{$ENDIF};

Type
  TReg = (
    R_NONE,
    R_EAX, R_ECX, R_EDX, R_EBX, R_ESP, R_EBP, R_ESI, R_EDI,   { 0..7 }
    R_AX, R_AL, R_CL, R_DL, R_BL                              { 16/8 bits }
  );

  TOperandKind = (
    OK_NONE,
    OK_REG,       { Reg                                                  }
    OK_IMM,       { Imm                                                  }
    OK_MEM,       { [Sym + Base + Index*Scale + Imm], Size octets        }
    OK_LABEL,     { cible de saut ou d'appel : Sym                       }
    OK_OFFSET,    { OFFSET Sym + Imm                                     }
    OK_ST         { ST(Imm)                                              }
  );

  TOperand = Record
    Kind  : TOperandKind;
    Reg   : TReg;
    Base  : TReg;
    Index : TReg;
    Scale : Byte;          { 1, 2, 4 ou 8 }
    Size  : Byte;          { memoire : 1, 2, 4, 8 octets (0 = non precise) }
    Imm   : LongInt;
    Sym   : Integer;       { indice dans NameTab, -1 si aucun }
  End;

  TOp = (
    OP_NOP,
    OP_LABEL,           { A.Sym = nom }
    OP_COMMENT,         { A.Imm = indice dans AsmStrs }
    OP_BLANK,
    OP_MOV, OP_MOVZX, OP_LEA, OP_PUSH, OP_POP,
    OP_ADD, OP_SUB, OP_IMUL, OP_IDIV, OP_CDQ, OP_NEG, OP_NOT,
    OP_AND, OP_OR, OP_XOR, OP_CMP, OP_TEST, OP_INC, OP_DEC,
    OP_SHR, OP_SAR,
    OP_SETE, OP_SETNE, OP_SETL, OP_SETLE, OP_SETG, OP_SETGE,
    OP_SETA, OP_SETAE, OP_SETB, OP_SETBE,
    OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG, OP_JGE,
    OP_JA, OP_JAE, OP_JB, OP_JBE, OP_JS,
    OP_CALL, OP_RET, OP_REP_STOSD,
    OP_FLD, OP_FST, OP_FSTP, OP_FILD,
    OP_FADD, OP_FSUB, OP_FSUBR, OP_FMUL, OP_FDIV, OP_FDIVR,
    OP_FCHS, OP_FABS, OP_FSQRT, OP_FSIN, OP_FCOS, OP_FPATAN,
    OP_FYL2X, OP_FLDLN2, OP_FLD1, OP_FLDZ, OP_FXCH,
    OP_FCOM, OP_FCOMP, OP_FNSTSW, OP_SAHF,
    OP_DIV, OP_JNS, OP_SHL, OP_FTST, OP_FRNDINT, OP_F2XM1, OP_FSCALE,
    OP_FLDL2E, OP_FADDP, OP_FSUBP, OP_FMULP, OP_FDIVP, OP_FISTP,
    OP_FNSTCW, OP_FLDCW
  );

  TInstr = Record
    Op   : TOp;
    A, B : TOperand;
  End;

  TDataKind = (
    DK_ZERO,     { Size octets a zero }
    DK_STR,      { chaine : AsmStrs[Str], sans zero final }
    DK_INT,      { un DWORD : Lo }
    DK_REAL,     { un QWORD : Lo, Hi }
    DK_TABLE     { DWORD d'adresses : TabEnt[First .. First+Count-1] }
  );

  TDataItem = Record
    Name         : Integer;
    Kind         : TDataKind;
    Size         : LongInt;
    Lo, Hi       : LongInt;
    Str          : Integer;
    First, Count : Integer;
  End;

  TDoubleBits = Record
    Case Boolean Of
      False : (D : Double);
      True  : (Lo, Hi : LongInt);
  End;

Var
  CodeTab    : Array[0..MAX_CODE - 1] Of TInstr;
  CodeCount  : LongInt;       { Integer = 16 bits en mode TP }
  DeferTab   : Array[0..MAX_CODE - 1] Of TInstr;
  DeferCount : LongInt;
  NameTab    : Array[0..MAX_NAMES - 1] Of TMangled;
  NameCount  : Integer;
  NameHash   : Array[0..NAME_HASH - 1] Of Integer;
  AsmStrs    : Array[0..MAX_ASMSTR - 1] Of TString;
  AsmStrCount: Integer;
  DataTab    : Array[0..MAX_DATAITEMS - 1] Of TDataItem;
  DataCount  : Integer;
  TabEnt     : Array[0..MAX_TABENT - 1] Of Integer;
  TabEntCount: Integer;
  LabelSeq   : LongInt;       { compteur des etiquettes internes     }
  ConstSeq   : LongInt;       { compteur des constantes en .data     }

{ Nom interne unique (table de hachage) : retourne son indice }
Function Intern(Const S : TMangled) : Integer;
Var
  H, I : LongInt;
Begin
  H := 5381;
  For I := 1 To Length(S) Do
    H := ((H * 33) + Ord(S[I])) And $7FFFFFF;
  H := H Mod NAME_HASH;
  While NameHash[H] >= 0 Do
  Begin
    If NameTab[NameHash[H]] = S Then
    Begin
      Intern := NameHash[H];
      Exit;
    End;
    H := (H + 1) Mod NAME_HASH;
  End;
  If NameCount >= MAX_NAMES Then
    FatalError('table des noms ASM pleine');
  NameTab[NameCount] := S;
  NameHash[H] := NameCount;
  Intern := NameCount;
  Inc(NameCount);
End;

Procedure CodeInit;
Var
  I : Integer;
Begin
  CodeCount   := 0;
  DeferCount  := 0;
  NameCount   := 0;
  AsmStrCount := 0;
  DataCount   := 0;
  TabEntCount := 0;
  LabelSeq    := 0;
  ConstSeq    := 0;
  For I := 0 To NAME_HASH - 1 Do
    NameHash[I] := -1;
End;

{ ---- Operandes ---- }

Function OpNone : TOperand;
Var
  O : TOperand;
Begin
  FillChar(O, SizeOf(O), 0);
  O.Sym := -1;
  OpNone := O;
End;

Function OpReg(R : TReg) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_REG;
  O.Reg  := R;
  OpReg := O;
End;

Function OpImm(V : LongInt) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_IMM;
  O.Imm  := V;
  OpImm := O;
End;

{ [Base + Disp] }
Function OpMem(Base : TReg; Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Base := Base;
  O.Imm  := Disp;
  O.Size := Size;
  OpMem := O;
End;

{ [Sym + Disp] : cellule en .data }
Function OpMemSym(Sym : Integer; Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Sym  := Sym;
  O.Imm  := Disp;
  O.Size := Size;
  OpMemSym := O;
End;

{ [Sym + Base + Index*Scale + Disp] }
Function OpMemIdx(Sym : Integer; Base, Index : TReg; Scale : Byte;
                  Disp : LongInt; Size : Byte) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind  := OK_MEM;
  O.Sym   := Sym;
  O.Base  := Base;
  O.Index := Index;
  O.Scale := Scale;
  O.Imm   := Disp;
  O.Size  := Size;
  OpMemIdx := O;
End;

Function OpLabel(Sym : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_LABEL;
  O.Sym  := Sym;
  OpLabel := O;
End;

Function OpOffset(Sym : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_OFFSET;
  O.Sym  := Sym;
  OpOffset := O;
End;

Function OpST(I : Integer) : TOperand;
Var
  O : TOperand;
Begin
  O := OpNone;
  O.Kind := OK_ST;
  O.Imm  := I;
  OpST := O;
End;

{ ---- Emission ---- }

Procedure Emit(Op : TOp; Const A, B : TOperand);
Begin
  If CodeCount >= MAX_CODE Then
    FatalError('programme trop long (code interne plein)');
  CodeTab[CodeCount].Op := Op;
  CodeTab[CodeCount].A  := A;
  CodeTab[CodeCount].B  := B;
  Inc(CodeCount);
End;

Procedure Emit0(Op : TOp);
Begin
  Emit(Op, OpNone, OpNone);
End;

Procedure Emit1(Op : TOp; Const A : TOperand);
Begin
  Emit(Op, A, OpNone);
End;

Procedure EmitLabel(Name : Integer);
Begin
  Emit(OP_LABEL, OpLabel(Name), OpNone);
End;

Function AsmStrAdd(Const S : TString) : Integer;
Begin
  If AsmStrCount >= MAX_ASMSTR Then
    FatalError('table des chaines ASM pleine');
  AsmStrs[AsmStrCount] := S;
  AsmStrAdd := AsmStrCount;
  Inc(AsmStrCount);
End;

Procedure EmitComment(Const S : TString);
Begin
  Emit(OP_COMMENT, OpImm(AsmStrAdd(S)), OpNone);
End;

Procedure EmitBlank;
Begin
  Emit0(OP_BLANK);
End;

{ Etiquette interne _A60L_NNNNN }
Function NewLabel : Integer;
Begin
  Inc(LabelSeq);
  NewLabel := Intern(MangleLabel(LabelSeq));
End;

{ Deplace CodeTab[Start .. CodeCount-1] a la fin de DeferTab : les
  procedures et les thunks sortent ainsi du flot du programme. }
Procedure MoveToDeferred(Start : LongInt);
Var
  I : LongInt;
Begin
  For I := Start To CodeCount - 1 Do
  Begin
    If DeferCount >= MAX_CODE Then
      FatalError('programme trop long (code differe plein)');
    DeferTab[DeferCount] := CodeTab[I];
    Inc(DeferCount);
  End;
  CodeCount := Start;
End;

{ ---- Listing texte (MASM / ML.PAS) ---- }

Function RegName(R : TReg) : TString;
Begin
  Case R Of
    R_EAX : RegName := 'EAX';
    R_ECX : RegName := 'ECX';
    R_EDX : RegName := 'EDX';
    R_EBX : RegName := 'EBX';
    R_ESP : RegName := 'ESP';
    R_EBP : RegName := 'EBP';
    R_ESI : RegName := 'ESI';
    R_EDI : RegName := 'EDI';
    R_AL  : RegName := 'AL';
    R_CL  : RegName := 'CL';
    R_DL  : RegName := 'DL';
    R_BL  : RegName := 'BL';
    R_AX  : RegName := 'AX';
  Else
    RegName := '?';
  End;
End;

Function OpName(Op : TOp) : TString;
Begin
  Case Op Of
    OP_MOV: OpName := 'MOV';       OP_MOVZX: OpName := 'MOVZX';
    OP_LEA: OpName := 'LEA';       OP_PUSH: OpName := 'PUSH';
    OP_POP: OpName := 'POP';       OP_ADD: OpName := 'ADD';
    OP_SUB: OpName := 'SUB';       OP_IMUL: OpName := 'IMUL';
    OP_IDIV: OpName := 'IDIV';     OP_CDQ: OpName := 'CDQ';
    OP_NEG: OpName := 'NEG';       OP_NOT: OpName := 'NOT';
    OP_AND: OpName := 'AND';       OP_OR: OpName := 'OR';
    OP_XOR: OpName := 'XOR';       OP_CMP: OpName := 'CMP';
    OP_TEST: OpName := 'TEST';     OP_INC: OpName := 'INC';
    OP_DEC: OpName := 'DEC';       OP_SHR: OpName := 'SHR';
    OP_SAR: OpName := 'SAR';
    OP_SETE: OpName := 'SETE';     OP_SETNE: OpName := 'SETNE';
    OP_SETL: OpName := 'SETL';     OP_SETLE: OpName := 'SETLE';
    OP_SETG: OpName := 'SETG';     OP_SETGE: OpName := 'SETGE';
    OP_SETA: OpName := 'SETA';     OP_SETAE: OpName := 'SETAE';
    OP_SETB: OpName := 'SETB';     OP_SETBE: OpName := 'SETBE';
    OP_JMP: OpName := 'JMP';       OP_JE: OpName := 'JE';
    OP_JNE: OpName := 'JNE';       OP_JL: OpName := 'JL';
    OP_JLE: OpName := 'JLE';       OP_JG: OpName := 'JG';
    OP_JGE: OpName := 'JGE';       OP_JA: OpName := 'JA';
    OP_JAE: OpName := 'JAE';       OP_JB: OpName := 'JB';
    OP_JBE: OpName := 'JBE';       OP_JS: OpName := 'JS';
    OP_CALL: OpName := 'CALL';     OP_RET: OpName := 'RET';
    OP_REP_STOSD: OpName := 'REP STOSD';
    OP_FLD: OpName := 'FLD';       OP_FST: OpName := 'FST';
    OP_FSTP: OpName := 'FSTP';     OP_FILD: OpName := 'FILD';
    OP_FADD: OpName := 'FADD';     OP_FSUB: OpName := 'FSUB';
    OP_FSUBR: OpName := 'FSUBR';   OP_FMUL: OpName := 'FMUL';
    OP_FDIV: OpName := 'FDIV';     OP_FDIVR: OpName := 'FDIVR';
    OP_FCHS: OpName := 'FCHS';     OP_FABS: OpName := 'FABS';
    OP_FSQRT: OpName := 'FSQRT';   OP_FSIN: OpName := 'FSIN';
    OP_FCOS: OpName := 'FCOS';     OP_FPATAN: OpName := 'FPATAN';
    OP_FYL2X: OpName := 'FYL2X';   OP_FLDLN2: OpName := 'FLDLN2';
    OP_FLD1: OpName := 'FLD1';     OP_FLDZ: OpName := 'FLDZ';
    OP_FXCH: OpName := 'FXCH';     OP_FCOM: OpName := 'FCOM';
    OP_FCOMP: OpName := 'FCOMP';   OP_FNSTSW: OpName := 'FNSTSW';
    OP_SAHF: OpName := 'SAHF';
    OP_DIV: OpName := 'DIV';       OP_JNS: OpName := 'JNS';
    OP_SHL: OpName := 'SHL';       OP_FTST: OpName := 'FTST';
    OP_FRNDINT: OpName := 'FRNDINT';  OP_F2XM1: OpName := 'F2XM1';
    OP_FSCALE: OpName := 'FSCALE';    OP_FLDL2E: OpName := 'FLDL2E';
    OP_FADDP: OpName := 'FADDP';   OP_FSUBP: OpName := 'FSUBP';
    OP_FMULP: OpName := 'FMULP';   OP_FDIVP: OpName := 'FDIVP';
    OP_FISTP: OpName := 'FISTP';   OP_FNSTCW: OpName := 'FNSTCW';
    OP_FLDCW: OpName := 'FLDCW';
  Else
    OpName := '?';
  End;
End;

Function SizePtr(Size : Byte) : TString;
Begin
  Case Size Of
    1 : SizePtr := 'BYTE PTR ';
    2 : SizePtr := 'WORD PTR ';
    4 : SizePtr := 'DWORD PTR ';
    8 : SizePtr := 'QWORD PTR ';
  Else
    SizePtr := '';
  End;
End;

Function SignedStr(V : LongInt) : TString;
Begin
  If V >= 0 Then
    SignedStr := '+' + ItoS(V)
  Else
    SignedStr := ItoS(V);
End;

Function OperandText(Const O : TOperand; Op : TOp) : TString;
Var
  S : TString;
Begin
  S := '';
  Case O.Kind Of
    OK_REG    : S := RegName(O.Reg);
    OK_IMM    : S := ItoS(O.Imm);
    OK_LABEL  : S := NameTab[O.Sym];
    OK_ST     : S := 'ST(' + ItoS(O.Imm) + ')';
    OK_OFFSET :
      Begin
        S := 'OFFSET ' + NameTab[O.Sym];
        If O.Imm <> 0 Then S := S + SignedStr(O.Imm);
      End;
    OK_MEM    :
      Begin
        If Op <> OP_LEA Then S := SizePtr(O.Size);
        S := S + '[';
        If O.Sym >= 0 Then S := S + NameTab[O.Sym];
        If O.Base <> R_NONE Then
        Begin
          If O.Sym >= 0 Then S := S + '+';
          S := S + RegName(O.Base);
        End;
        If O.Index <> R_NONE Then
        Begin
          If (O.Sym >= 0) Or (O.Base <> R_NONE) Then S := S + '+';
          S := S + RegName(O.Index) + '*' + ItoS(O.Scale);
        End;
        If O.Imm <> 0 Then S := S + SignedStr(O.Imm);
        S := S + ']';
      End;
  End;
  OperandText := S;
End;

Function InstrText(Const I : TInstr) : TString;
Var
  S : TString;
Begin
  S := '        ' + OpName(I.Op);
  If I.A.Kind <> OK_NONE Then
  Begin
    While Length(S) < 16 Do S := S + ' ';
    If S[Length(S)] <> ' ' Then S := S + ' ';
    S := S + OperandText(I.A, I.Op);
    If I.B.Kind <> OK_NONE Then
      S := S + ', ' + OperandText(I.B, I.Op);
  End;
  InstrText := S;
End;

{ Texte d'une chaine en DB : 'abc', 13, 10 }
Function DbText(Const S : TString) : TString;
Var
  R      : TString;
  I      : Integer;
  InQ    : Boolean;
Begin
  R   := '';
  InQ := False;
  For I := 1 To Length(S) Do
  Begin
    If (S[I] >= ' ') And (S[I] <= '~') And (S[I] <> '''') Then
    Begin
      If Not InQ Then
      Begin
        If R <> '' Then R := R + ', ';
        R := R + '''';
        InQ := True;
      End;
      R := R + S[I];
    End
    Else
    Begin
      If InQ Then
      Begin
        R := R + '''';
        InQ := False;
      End;
      If R <> '' Then R := R + ', ';
      R := R + ItoS(Ord(S[I]));
    End;
  End;
  If InQ Then R := R + '''';
  If R = '' Then R := '0';
  DbText := R;
End;

Function HexDword(V : LongInt) : TString;
Const
  Digits : String[16] = '0123456789ABCDEF';
Var
  R : TString;
  I : Integer;
  W : LongInt;
Begin
  R := '';
  W := V;
  For I := 1 To 8 Do
  Begin
    R := Digits[(W And 15) + 1] + R;
    W := (W Shr 4) And $0FFFFFFF;
  End;
  HexDword := '0' + R + 'h';
End;

Procedure WriteInstrList(Var F : Text; Const Tab : Array Of TInstr;
                         Count : LongInt);
Var
  I : LongInt;
Begin
  For I := 0 To Count - 1 Do
    Case Tab[I].Op Of
      OP_NOP     : ;
      OP_LABEL   : WriteLn(F, NameTab[Tab[I].A.Sym], ':');
      OP_COMMENT : WriteLn(F, '        ; ', AsmStrs[Tab[I].A.Imm]);
      OP_BLANK   : WriteLn(F);
    Else
      WriteLn(F, InstrText(Tab[I]));
    End;
End;

{ Ecrit le listing .ASM (ML.PAS / MASM 32 bits) }
Procedure WriteListing(Const FileName : TString);
Var
  F    : Text;
  I, J : Integer;
  Name : TString;
Begin
  Assign(F, FileName);
  Rewrite(F);
  If IOResult <> 0 Then
    FatalError('impossible de creer ' + FileName);
  WriteLn(F, '; ', FileName, ' - genere par AL60CW32 ',
          AL60CW32_VERSION, ' a partir de ', Opts.SrcFile);
  WriteLn(F);
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT');
  WriteLn(F);
  WriteLn(F, 'INCLUDELIB kernel32.lib');
  WriteLn(F, 'EXTERN GetStdHandle:PROC');
  WriteLn(F, 'EXTERN WriteFile:PROC');
  WriteLn(F, 'EXTERN ReadFile:PROC');
  WriteLn(F, 'EXTERN ExitProcess:PROC');
  WriteLn(F, 'EXTERN GetProcessHeap:PROC');
  WriteLn(F, 'EXTERN HeapAlloc:PROC');
  WriteLn(F, 'EXTERN HeapFree:PROC');
  WriteLn(F);
  WriteLn(F, '.DATA');
  For I := 0 To DataCount - 1 Do
  Begin
    Name := NameTab[DataTab[I].Name];
    While Length(Name) < 16 Do Name := Name + ' ';
    Case DataTab[I].Kind Of
      DK_ZERO  :
        WriteLn(F, Name, ' DD ', (DataTab[I].Size + 3) Div 4, ' DUP(0)');
      DK_STR   :
        WriteLn(F, Name, ' DB ', DbText(AsmStrs[DataTab[I].Str]), ', 0');
      DK_INT   :
        WriteLn(F, Name, ' DD ', DataTab[I].Lo);
      DK_REAL  :
        WriteLn(F, Name, ' DD ', HexDword(DataTab[I].Lo), ', ',
                HexDword(DataTab[I].Hi));
      DK_TABLE :
        Begin
          Write(F, Name, ' DD ');
          For J := 0 To DataTab[I].Count - 1 Do
          Begin
            If J > 0 Then Write(F, ', ');
            Write(F, NameTab[TabEnt[DataTab[I].First + J]]);
          End;
          WriteLn(F);
        End;
    End;
  End;
  WriteLn(F);
  WriteLn(F, '.CODE');
  WriteInstrList(F, CodeTab, CodeCount);
  WriteLn(F);
  WriteInstrList(F, DeferTab, DeferCount);
  WriteLn(F);
  WriteLn(F, 'END ', A60_MAIN_NAME);
  Close(F);
  If IOResult <> 0 Then
    FatalError('erreur d''ecriture de ' + FileName);
End;

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
  If Opts.Verbose Then
    WriteLn('  ', CodeCount + DeferCount, ' instruction(s), ',
            DataCount, ' donnee(s) statique(s), ', NameCount,
            ' nom(s) interne(s)');
  If Opts.DebugMode Then
  Begin
    WriteLn('Code interne (', CodeCount + DeferCount, ' entrees) :');
    WriteInstrList(Output, CodeTab, CodeCount);
    WriteInstrList(Output, DeferTab, DeferCount);
  End;
  If Opts.EmitAsm Then
  Begin
    WriteListing(Opts.AsmFile);
    If Opts.Verbose Then WriteLn('  listing : ', Opts.AsmFile);
  End;
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
  TypeInit;
  SymInit;
  CodeInit;
  If Opts.DebugMode Then TypeDump;
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
