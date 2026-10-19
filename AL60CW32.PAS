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

  ETAT : TODO 01 a 25 implementes (squelette, pipeline en 6 phases,
         options de ligne de commande, constantes, limites et nommage,
         lexeur, types et conversions, table des symboles, code interne
         et listing .ASM, segment de donnees, expressions primaires,
         expressions arithmetiques, booleennes et conditionnelles,
         instructions et blocs, boucle for, goto et switch, tableaux,
         procedures, appel par nom, entrees/sorties et fonctions
         standard, encodeur x86-32, ecrivains PE et COFF, runtime integre,
         erreurs et rapport, modes -v et -d, validation sur les 33
         exemples : TESTS\test_al60cw32.sh).

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

  TODO 08 - SEGMENT DE DONNEES, VARIABLES STATIQUES ET OWN [IMPLEMENTE]
            Cellules de .data : zero (DD n DUP(0)), chaines (DB, 0),
              entiers, reels (DQ), tables d'adresses (switch)
            Chaines litterales dedoublonnees (_A60K_nnn)
            Variables de niveau 0 : une cellule _A60V_NOM
            Variables OWN (statiques, valeur conservee entre les appels
              d'un bloc ou d'une procedure, initialisees a zero) :
              cellules _A60O_nom_n, meme pour les tableaux OWN
            Constantes reelles en memoire (QWORD) pour FLD
            Verification : own.a60, test_own.a60, test_data.a60
            Realise : DataNew, DataAddZero (octets a zero), DataStr
              (chaine litterale dedoublonnee, _A60K_n), DataInt et
              DataReal (constantes _A60C_n dedoublonnees, reels en QWORD
              par leurs deux mots), DataTable (table d'adresses de switch),
              DataDeclareSym (cellule d'une variable globale ou own, de la
              taille de son type : integer et Boolean 4 octets, real 8) ;
              DataDump (mode -d) ; la declaration des tableaux, y compris
              own, est faite avec les tableaux (TODO 15) ; l'ecriture des
              octets en .data est faite par l'encodeur (TODO 19)

  TODO 09 - EXPRESSIONS PRIMAIRES ET VARIABLES [IMPLEMENTE]
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
            Realise : primitives du parseur (ParserAdvance, ParserUnget,
              AtKw, AtPunct, AtOp, ExpectPunct, ParseError, ParserSync) ;
              pool ExprTab (EX_INT, EX_REAL, EX_BOOL, EX_STR, EX_VAR,
              EX_INDEX, EX_LIST, EX_CALL, et les noeuds reserves aux
              TODO suivants) ; ParsePrimary : constantes, chaines,
              variables (declaration implicite avec avertissement si
              inconnue), element de tableau (ParseIndexed : indices
              convertis en integer, bornes constantes verifiees),
              appel de fonction (ParseCall : nombre d'arguments verifie),
              parentheses ; ExprCoerceCtx (conversion et repliement des
              constantes, avertissements de TypeConvNote) ; ExprDump ;
              generation : LoadImm, constantes reelles en memoire, chaine
              par OFFSET, GenFrameReg (remontee des liens statiques),
              SymCell, GenByName (parametre par nom), GenLoadVar,
              GenAddrVar, GenExpr pour les noeuds primaires ; les
              expressions a operateurs, l'affectation, les blocs et
              declarations sont faits aux TODO 10 a 12 ; PhaseParse
              n'analyse pas encore de programme complet

  TODO 10 - EXPRESSIONS ARITHMETIQUES [IMPLEMENTE]
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
            Realise : ParseArith (signe en tete applique au premier terme
              entier : -a div b vaut -(a div b)), ParseTerm (* / div),
              ParseFactor (^ ou **, associatif a gauche comme dans le
              rapport, exposant eventuellement signe) ; ExprMakeUnary et
              ExprMakeBinary : types par TypeArith, TypeDivide,
              TypeIntDiv, TypePower, repliement des constantes (entiers
              sur 64 bits avec controle du debordement 32 bits, reels),
              division par une constante nulle signalee ; mod n'existe pas
              dans le rapport (non reconnu) ; un signe n'est admis qu'en
              tete d'expression (x - -3 est refuse comme dans le rapport)
            Generation : entiers dans EAX (ADD SUB IMUL, CDQ + IDIV avec
              controle de division par zero, _A60RT_POW), reels dans ST(0)
              avec operande gauche sur la pile (FADD FMUL FSUBR FDIVR,
              _A60RT_RPOW), conversions GenConvert (FILD, _A60RT_RTOI,
              TEST / SETNE) ; une puissance entiere a exposant negatif
              inconnu a la compilation est tronquee par le runtime
              (1 ou -1 pour une base 1 ou -1, sinon 0), alors que l'exposant
              negatif constant donne un real
            Verifie : 28 expressions (precedences, associativite,
              promotions, signe, repliement) generees, assemblees avec
              ML.PAS avec un runtime de test, executees ; le code de
              retour donne le resultat attendu

  TODO 11 - EXPRESSIONS BOOLEENNES ET CONDITIONNELLES [IMPLEMENTE]
            Relationnels = != # < <= > >= (integer et real, resultat
              Boolean) ; logiques not (~), and (/\), or (\/), impl, equiv
              avec leurs priorites (not > and > or > impl > equiv)
            Production de 0 ou 1 par SETcc et sauts conditionnels optimises
              dans if et while (GenJump)
            Expression conditionnelle : if B then E1 else E2, les deux
              branches de meme type (integer et real : promotion en real)
            Expression designationnelle : if B then etiquette else
              etiquette, element de switch (realisee avec goto et switch,
              TODO 14, car elle depend des etiquettes)
            Verification : test_condexpr.a60, test_arithbool.a60, ifthen.a60
            Realise : ParseRelation (un relationnel n'est pas chainable),
              ParseSecondary (not s'applique a une relation ou un
              primaire : not a < b vaut not (a < b)), ParseBoolFactor
              (and), ParseBoolTerm (or), ParseImplication (impl),
              ParseSimpleExpr (equiv), ParseCondExpr (la branche then est
              une expression simple, la branche else une expression
              complete, donc if a then b else if c then d else e),
              ParseCondition (Boolean ou entier, avec avertissement pour
              un entier) ; ExprMakeBinary et ExprMakeUnary : relationnels
              (operandes arithmetiques, comparaison des reels par
              FCOMP + SAHF), logiques, repliement des constantes avec
              court-circuit (false and x, true or x, false impl x),
              ExprMakeCond (branches de meme type commun, real si l'une
              l'est) ; GenCompareFlags, GenJump (and / or / impl en
              court-circuit, not inverse le saut), SETcc pour la valeur,
              equiv par CMP + SETE
            Verifie : 49 expressions (relationnels entiers et reels,
              priorites, court-circuit, conditionnelles imbriquees,
              constantes repliees) generees, assemblees avec ML.PAS et
              executees ; les 30 cas du TODO 10 donnent les memes
              resultats (27 valeurs et 3 refus attendus)

  TODO 12 - INSTRUCTIONS : AFFECTATION, IF ET BLOCS [IMPLEMENTE]
            Affectation x := E avec conversion de type ; affectations
              multiples a := b := E (liste de parties gauches)
            Instruction conditionnelle if B then S1 [else S2], sans
              ambiguite du else pendant
            Instruction composee begin ... end et blocs avec declarations
              (portee locale, reservation de pile au bloc)
            Instruction vide, instruction etiquetee, point final de END.
            Verification : test_if.a60, test_blocks.a60, blocks.a60,
              ifthen.a60, test_emitter.a60
            Realise : ParseProgram (un bloc begin ... end suivi du point
              final facultatif), ParseBlock (portee propre, declarations
              et instructions melangees comme dans les exemples),
              ParseItem, ParseStatement (instruction vide, bloc, if,
              affectation, appel, etiquette), ParseDeclaration et
              ParseVarList (variables [own] integer, real, boolean : une
              cellule .data au niveau 0 ou own, sinon locale [EBP-n]),
              ParseAssignTail (liste a := b := expr, meme type exige
              comme dans le rapport, parametre par nom marque ecrit),
              ParseLabelDef (etiquette devant une instruction), ParseIf
              (saut Lelse si faux, else rattache au if le plus proche),
              GenAssign (variable simple et resultat de fonction),
              GenStmtExpr, GenMainBegin / GenMainEnd (ExitProcess(0)) ;
              extension toleree par les exemples : une expression isolee
              (a + b ; `texte` ;) est ignoree avec un avertissement
              sauf si elle appelle une procedure ; les affectations a
              un element de tableau ou a un parametre par nom, for, goto,
              les declarations de tableau, switch et procedure, les
              appels d'entree/sortie viennent avec les TODO 13 a 18
            Verifie : 4 programmes (affectations, if imbriques, blocs
              freres de meme nom, own, reels, Boolean) compiles, le
              resultat lu par le code de retour apres assemblage avec
              ML.PAS ; 7 exemples compilent sans erreur : test_arithbool,
              test_emitter, test_operators, test_primary, test_types,
              test_variables, test_data

  TODO 13 - BOUCLE FOR [IMPLEMENTE]
            for v := liste do S ; elements de la liste : expression
              simple, E1 step E2 until E3, E1 while B, en nombre quelconque
            Evaluation de la borne et du pas a chaque tour (semantique du
              rapport), pas negatif, variable de controle modifiable
            Plusieurs elements : selecteur de clause, saut vers l'element
              suivant ; sortie de boucle par goto
            Compteur de profondeur des boucles imbriquees
            Verification : forloop.a60, test_for.a60
            Realise : ParseFor (variable de boucle numerique simple,
              profondeur MAX_LOOP_NEST), ParseForClause (valeur, E1 step
              E2 until E3, E1 while B ; la borne, le pas et la condition
              sont regeneres, donc reevalues, a chaque tour comme dans le
              rapport), selecteur de clause pour les listes (cellule
              .data au niveau 0, locale sinon), TForCtx ; step constant :
              un seul test (> ou <), sinon test du signe du pas a chaque
              tour ; avertissements : pas nul, bornes inversees,
              condition while toujours fausse ; la variable de boucle
              peut etre modifiee par le corps ; l'analyse continue des
              erreurs sans bloquer la suite
            Phases : les phases de generation ne tournent plus quand des
              erreurs ont ete signalees (aucun .asm ni .exe ecrit)
            Verifie : 13 boucles (step positif, negatif, variable, reel,
              listes melangees, while, imbriquees, borne modifiee par le
              corps, boucle vide, variable de boucle modifiee) compilees,
              assemblees avec ML.PAS et executees : somme attendue pour
              chacune ; 9 erreurs de syntaxe donnent les bons messages

  TODO 14 - GOTO, ETIQUETTES ET SWITCH [IMPLEMENTE]
            Etiquettes d'instruction, goto vers une etiquette du meme bloc
              ou d'un bloc englobant (restauration de la pile)
            goto hors d'une procedure vers un bloc englobant (depilement
              par lien statique et restauration d'EBP / ESP)
            Declaration switch S := L1, L2, ... : table d'adresses dans
              .data et JMP indirect, designateur S[i] avec indice hors
              bornes sans saut (avertissement si constant)
            Switch dont les elements sont des expressions designationnelles
            Verification : switch.a60, test_switch.a60, test_goto.a60
            Realise : ParseDesignator (etiquette nommee ou numerique,
              nom[indice] d'un switch, (d), if B then d1 else d2),
              ParseGoto, ParseSwitchDecl, ParseLabelDecl (label a, b ;
              extension des exemples), ParseNumericStart (100: instruction),
              ParseLabelDef ; GenDesignator (JMP, saut indirect par la
              table avec controle de l'indice : hors bornes, aucun saut),
              GenSwitchDecl (table en .data, petit bloc de code pour un
              element qui n'est pas une etiquette) ; goto d'un niveau de
              procedure vers un niveau plus bas : EBP du niveau cible par
              les liens statiques, ESP = EBP (programme principal) ou
              [EBP-4] du niveau cible (SymEnterProc reserve cette cellule
              dans chaque procedure : le prologue du TODO 16 y range ESP)
            Renvoi avant depuis une procedure : l'etiquette peut etre
              celle d'une procedure englobante ; le saut va a une souche
              generee (apres le programme) quand l'etiquette est definie
              (NewStubRef, ResolveStubs, GenUnwindJump) ; une etiquette
              non definie dans une procedure est reportee sur la portee
              englobante (SymLeaveScope), sauf si elle a ete declaree
            Verifie : 10 programmes (renvoi avant et arriere, boucle par
              goto, switch avec indice valide et hors bornes, designateur
              conditionnel, element conditionnel de switch, sortie d'un
              for et d'un bloc, etiquettes numeriques, go to en deux
              mots, designateurs entre parentheses) assembles avec ML.PAS
              et executes ; 10 erreurs diagnostiquees ; le code de saut
              entre procedures (souches, liens statiques) est verifie sur
              le listing et sera execute avec les procedures (TODO 16)

  TODO 15 - TABLEAUX A BORNES DYNAMIQUES [IMPLEMENTE]
            Declaration [type] array A[l1:u1, l2:u2], B[...] : plusieurs
              tableaux par declaration, jusqu'a MAX_ARRAY_DIM dimensions
            Bornes evaluees a l'entree du bloc (expressions quelconques) :
              descripteur (base, dimensions, bornes, foulees) et memoire
              allouee au bloc, liberee a sa sortie
            Calcul d'adresse a plusieurs indices, controle de bornes
              (_A60RT_CHKIDX), taille nulle ou negative, limite de taille
            Tableaux de real, d'integer et de Boolean ; tableaux OWN
            Verification : arrays.a60, test_arrays.a60
            Realise : ParseArrayDecl ([own] [type] array a, b[l:u, l:u],
              c[l:u] ; sans type : real comme dans le rapport), ParseBound,
              ArrayBytes (limites 2^27 elements et 1 Go), DataDeclareSym
              (donnees et descripteur .data), GenArrayDecl (remplit le
              descripteur ; bornes variables : taille calculee puis
              _A60RT_ALLOC), GenIndexAddr (indice lineaire somme de
              (i - lo) * pas, CHKIDX sauf indice constant verifie a la
              compilation, bornes lues dans le descripteur si variables),
              GenDescToESI, GenAddrNode, GenFreeArray ; descripteur de
              DWORD : base, nombre de dimensions, puis lo, hi, pas par
              dimension ; bornes constantes : donnees en .data (niveau 0,
              own) ou dans le cadre (procedure) ; bornes variables : tas,
              liberees (_A60RT_FREE, pointeur remis a zero) a la fin du
              bloc, y compris a chaque tour d'une boucle ; un tableau own
              exige des bornes constantes ; un goto qui sort d'un bloc ne
              libere pas ses tableaux (fuite limitee) ; affectation a un
              element (adresse empilee puis valeur) ; GenExpr EX_INDEX
            Verifie : 13 programmes (1 et 2 dimensions, bornes negatives,
              real par defaut, listes de tableaux, bornes variables, bloc
              repete en boucle, own, element comme indice, Boolean,
              indice hors bornes a l'execution) assembles avec ML.PAS et
              executes ; 10 erreurs diagnostiquees ; FREE est un RET dans
              le runtime de test (le vrai est au TODO 22)

  TODO 16 - PROCEDURES ET FONCTIONS : DECLARATION ET APPEL [IMPLEMENTE]
            procedure [type] Nom(p1, p2) ; value ...; specifications ;
              corps : instruction ou bloc ; resultat par affectation au
              nom de la fonction (integer, real, Boolean)
            Convention d'appel : arguments empiles de droite a gauche,
              lien statique (toujours present, voir TODO 17), appelee
              nettoie la pile (RET n), resultat dans EAX ou ST(0), cadre
              EBP
            Passage par valeur (value) avec conversion de type
            Recursivite, procedures imbriquees (acces aux variables des
              procedures englobantes), procedures sans parametre
            Appel en instruction et en expression, verification du nombre
              et du type des arguments, procedure inconnue
            Parametres formels de type string, label, procedure et switch
            Verification : procs.a60, test_procedures.a60, test_proccall.a60
            Realise : ParseProcDecl (en-tete avec ou sans parametres,
              partie value, specifications ParseParamSpec : integer, real,
              boolean, string, label, switch, procedure, [type] array ;
              un parametre sans specification est integer avec
              avertissement ; une chaine est transmise par valeur),
              ParseDeclaration ([type] procedure), ParseCall et
              ParseCallArg (verification du nombre et du type des
              arguments ; classes AC_VALUE, AC_ARRAY, AC_CONST, AC_REF,
              AC_FORWARD ; un argument assignable est exige si la
              procedure modifie le parametre) ; GenProcBegin (cadre,
              locales mises a zero, [EBP-4] := ESP) et GenProcEnd (taille
              du cadre, resultat d'une fonction en EAX ou ST(0), RET n) ;
              GenCall (arguments de droite a gauche, lien statique, CALL) ; une
              procedure peut s'appeler elle-meme ; une procedure
              imbriquee accede aux variables des procedures englobantes
              par les liens statiques ; GenAssign vers un parametre par
              nom (adresse puis valeur) ; goto vers le programme principal
              depuis une procedure : EBP du programme principal memorise
              au demarrage dans _A60_MAINBP (pas de lien statique pour un
              niveau 1)
            Limites : les parametres par nom dont l'argument est une
              expression, un element de tableau a indice variable ou un
              appel exigent un thunk (TODO 17) ; procedure, switch et
              etiquette en parametre aussi ; une procedure doit etre
              declaree avant son appel (pas de recursion mutuelle)
            Verifie : 16 programmes (recursion, fibonacci, procedures
              imbriquees sur trois niveaux, real et Boolean en valeur de
              retour, parametres par nom en lecture et en ecriture,
              echange de deux variables, tableau en parametre, procedures
              homonymes de blocs freres, goto depuis une procedure vers
              le programme principal, une procedure englobante, par un
              switch ou une etiquette declaree, 200000 sauts sans fuite de
              pile) compiles, assembles avec ML.PAS et executes ; 10
              erreurs d'appel diagnostiquees

  TODO 17 - APPEL PAR NOM (THUNKS) [IMPLEMENTE]
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
            Realise : ParseCallArg classe chaque argument d'un parametre
              par nom : AC_CONST (constante en .data), AC_REF (variable ou
              element a indices constants, adresse directe), AC_FORWARD
              (parametre par nom de l'appelant, paire reprise), AC_THUNK
              (expression, lecture), AC_THUNK_RW (element a indice
              variable ou argument converti que la procedure modifie :
              le thunk rend aussi l'adresse) ; GenThunk (petit
              sous-programme apres le programme : PUSH EBP, EBP := EAX =
              contexte de l'appelant, evaluation, retour ; ECX = 1
              demande l'adresse) ; GenByName lit ou ecrit via la paire
              (thunk ou 0, contexte ou adresse) ; la conversion de type
              est faite dans le thunk ; un argument non assignable pour
              un parametre modifie est refuse
            Procedures formelles : un parametre specifie procedure (type
              du resultat de la specification, integer par defaut) recoit
              une paire (adresse, lien statique) ; l'appel f(a, b) passe
              ses arguments par valeur avec leur propre type, empile le
              lien puis CALL ; une procedure formelle peut etre transmise
              a une autre (AC_PROC, paire reprise) ; toute procedure
              recoit maintenant un mot de lien en [EBP+8] (0 pour une
              procedure du programme principal), ce qui rend l'appel par
              une procedure formelle independant du niveau de l'effective
            Limites : l'effective passee a une procedure formelle doit
              avoir des parametres par valeur du type des arguments (pas
              de signature a verifier) ; parametres switch et label non
              supportes (aucun exemple n'en utilise)
            Verifie : 10 programmes (dispositif de Jensen avec a[i] et
              i * i, echange de deux elements de tableau, factorielle par
              nom, parametre par nom transmis et ecrit en cascade, conversion
              integer vers real dans le thunk, argument Boolean, thunk lisant
              un tableau local et une variable locale d'une procedure,
              procedures formelles imbriquees et transmises) compiles,
              assembles avec ML.PAS et executes ; 18 programmes des
              TODOs 12 a 16 rendent les memes resultats ; 5 erreurs
              diagnostiquees

  TODO 18 - ENTREES/SORTIES ET FONCTIONS STANDARD [IMPLEMENTE]
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
              POW, RPOW, EXP, FLOOR, RTOI, RSIGN, CHKIDX, DIVZERO, ALLOC,
              FREE, SETCHAN
            Verification : test_io.a60, math.a60, hello.a60
            Realise : ParseIO (procedures sans valeur outstring, outinteger,
              outreal, outboolean, newline, print, ininteger, inreal,
              inboolean, sysact ; une procedure du programme de meme nom
              reste prioritaire) ; arguments verifies et convertis
              (texte pour outstring / print, integer / real / Boolean
              pour les autres, variable du bon type pour les lectures,
              parametre par nom marque ecrit) ; newline sans parentheses
              accepte ; sysact(...) est un appel sans effet ; canal : 1 =
              sortie standard, 2 = erreur standard (SETCHAN, avec retour
              a la sortie standard), les entrees ignorent le canal ;
              GenIO : chaine constante par WRITESTR (adresse, longueur),
              autre texte par WRITEZ, WRITEINT, WRITEREAL (ST0),
              WRITEBOOL, NEWLINE, READINT, READREAL, READBOOL
            Fonctions standard (ParseIntrinsic, GenIntrinsic) : abs (type
              de l'argument), sign et entier (integer), sqrt, sin, cos,
              arctan, ln, exp (real, x87 : FSQRT, FSIN, FCOS, FPATAN,
              FYL2X, runtime EXP) ; argument constant replie a la
              compilation ; entier d'un integer est l'identite
            Verifie : les 32 exemples SAMPLES\ALGOL60 autres que
              test_switch compilent et s'executent (assemblage ML.PAS avec
              le runtime de test) ; les sorties lues (hello, math, procs,
              blocks, forloop, own, test_callbyname, test_procedures,
              test_runtime...) correspondent aux sources ; fonctions
              standard et lectures verifiees sur 10 programmes ; 10 erreurs
              diagnostiquees
            Extensions tolerees par les exemples : etiquettes jamais
              definies (test_lex.a60) = avertissement et saut vers la fin
              du programme ; valeur affectee au nom d'une procedure sans
              type (ignoree, avec avertissement)
            Remarque : test_switch.a60 boucle indefiniment par construction
              (done: est suivi de x := 2 ; GOTO sw[x] qui revient a L2) ;
              son test doit etre borne par un delai (TODO 25)

  TODO 19 - ENCODEUR BINAIRE x86-32 [IMPLEMENTE]
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
            Realise : EncodeInstr (ModRM / SIB / deplacement 8 ou 32 bits,
              registres 8, 16 et 32 bits, formes courtes des immediats,
              x87), EncodeData (zeros, chaines avec 0 final, entiers,
              reels en deux mots, tables d'adresses avec relocations),
              EncodeCode (relaxation des sauts : tous courts au depart,
              agrandis tant qu'un deplacement deborde, les tailles ne font
              que croitre), tables BinCode, BinData, BinLbl (code, donnees,
              externe), BinFix (BF_ABS32 pour une adresse, BF_REL32 pour un
              appel externe) et BinImport (toute cible d'appel non definie) ;
              CheckFixups (symbole de donnees non defini = erreur) ;
              PhaseEncode affiche en -v les tailles .text et .data, les
              relocations et les imports, et ecrit en -d le listing
              hexadecimal <sortie>.lst (decalage, octets, instruction)
            Verifie : les 33 exemples et 53 autres programmes (tests des
              TODOs 9 a 18, dont fonctions standard, sauts entre
              procedures, appels par procedure formelle, tableaux) : 4068
              instructions de 86 listings decodees par objdump et
              comparees (mnemonique, longueur, octets, operandes) sans
              aucun ecart

  TODO 20 - ECRIVAIN PE (.EXE WINDOWS 32 BITS) [IMPLEMENTE]
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
            Realise : WritePE (en-tete MZ + souche DOS, signature PE,
              COFF File Header a 3 sections, Optional Header : magic
              $010B, ImageBase $00400000, alignements 4096 et 512,
              sous-systeme console, piles et tas de 1 Mo reserves ; sections
              .text avec une souche JMP [IAT] de 8 octets par import,
              .data, .idata avec descripteur, ILT, IAT, noms avec indice et
              nom de la DLL ; repertoires importation et IAT ; point
              d'entree _A60P_Main ; relocations ABS32 et appels aux imports
              resolus a l'ecriture) ; un symbole du runtime (_A60RT_) non
              defini arrete la compilation sans creer de fichier ; PhaseWrite
              appelle WritePE sans -obj (le .OBJ est le TODO 21)
            Verifie : objdump lit le .exe (3 sections, import
              kernel32.dll!ExitProcess, caracteristiques $010F) ; 71
              expressions (arithmetique, relationnels, booleens,
              conditionnelles) compilees en .exe par le compilateur
              lui-meme et executees par le chargeur PE de test : le code de
              retour est la valeur attendue ; test_data, test_emitter et
              test_primary donnent un .exe qui s'execute ; les programmes
              qui appellent le runtime (hello, test_types...) s'arretent
              sur 'routine du runtime absente' jusqu'au TODO 22

  TODO 21 - ECRIVAIN COFF (.OBJ, OPTION -obj) [IMPLEMENTE]
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
            Realise : CoffSym et WriteCOFF (en-tete machine $014C, deux
              sections .text et .data alignees sur 4, relocations DIR32 par
              les symboles de section 0 et 2 avec la valeur en place
              augmentee du decalage de l'etiquette, et REL32 pour les
              appels aux imports ; symboles : .text et .data avec entree
              auxiliaire, _A60P_Main externe defini, un externe non defini
              par import ou routine du runtime ; table des chaines) ;
              PhaseWrite appelle WriteCOFF avec -obj et WritePE sinon ;
              -obj -asm produit .OBJ et .ASM, jamais de .EXE
            Verifie : les 33 exemples compilent avec -obj ; objdump -h -t
              -r lit chacun d'eux (sections, symboles, relocations) ;
              aucun .exe n'est cree avec -obj ; les references au runtime
              (_A60RT_) restent des externes non definis jusqu'au TODO 22

  TODO 22 - RUNTIME ALGOL 60 POUR WIN32 [IMPLEMENTE]
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
              RSIGN, CHKIDX, DIVZERO, ALLOC, FREE (blocs dont les
              tableaux sont liberes a la sortie), SETCHAN (canal de
              sortie : 2 = erreur standard)
            Messages d'erreur d'execution (indice hors bornes, division
              par zero) et code de sortie 1
            Formats a documenter : entier decimal, reel en notation
              fixe (6 decimales au plus, zeros finaux supprimes),
              Boolean true / false, fin de ligne CR LF
            Realise : section 12 ; le runtime est un texte d'assembleur
              (RtText, 27 routines) assemble par un mini-assembleur
              (RtAssembleLine) en instructions internes, ajoutees apres le
              code du programme par RtLink (appelee avant le listing) ;
              RtMark calcule la fermeture transitive des appels _A60RT_ ;
              les cellules de donnees _A60_* (RtData) sont creees a la
              demande ; GetStdHandle, WriteFile, ReadFile, ExitProcess,
              GetProcessHeap, HeapAlloc (memoire mise a zero) et HeapFree
              deviennent des imports de kernel32.dll ; READBOOL, GETC,
              SKIPWS en plus des routines listees ; FREE conserve EAX,
              ECX et EDX ; indice hors bornes et division par zero :
              message sur le canal courant et code de sortie 1
            Verifie : les 33 exemples compiles directement en .exe puis
              executes (chargeur TESTS\AL60CW32\runpe.c, qui gagne
              HeapFree) donnent la meme sortie que la version assemblee
              avec le runtime de test, sauf test_switch (boucle infinie
              par construction, arretee par un delai) ; les 32 autres
              donnent aussi cette sortie une fois les .obj lies avec
              lld-link ; le listing .ASM est autonome (ML l'assemble sans
              rien ajouter) ; l'encodage de tout le code, runtime compris,
              est confirme par objdump (0 ecart) ; indice hors bornes et
              division par zero : message et code de retour 1 ; canal 2 =
              erreur standard

  TODO 23 - GESTION DES ERREURS ET AVERTISSEMENTS [IMPLEMENTE]
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
            Realise : ErrorAt / WarnAt / WarnMsg au format indique (les
              avertissements ne s'affichent qu'avec -w) ; erreurs lexicales
              (caractere invalide, chaine non fermee, commentaire non
              termine, entier ou exposant hors limites), syntaxiques
              (token inattendu, begin non ferme, texte apres le end final,
              parenthese ou crochet manquant, point-virgule manquant),
              semantiques (affectation ou operande incompatible, nombre
              d'arguments, procedure inconnue, etiquette attendue ou
              dupliquee, declaration en double, tableau sans indice ou
              avec trop d'indices, bornes inversees, division par zero
              constante) ; recuperation par AtSyncKw (begin, for, if,
              procedure et ;) ; avertissements : variable non declaree,
              etiquette non utilisee ou non definie, indice de switch
              hors bornes, pas nul, conversions real -> integer et
              integer <-> Boolean, et maintenant Boolean utilise comme
              nombre (operande arithmetique ou comparaison avec un
              nombre : ExprNoteBoolNum) ; NoteOutput / RemoveOutputs :
              les fichiers .asm, .exe et .obj crees sont supprimes sur
              erreur fatale ; PhaseReport affiche Compilation echouee :
              N erreur(s), M avertissement(s) ou, avec -w ou -v,
              Compilation terminee : 0 erreur, M avertissement(s) ;
              code de retour EXIT_ERROR (1) sur erreur
            Verifie : 40 programmes fautifs ou limites (lexicaux,
              syntaxiques, semantiques, avertissements) donnent le message
              attendu, le compte final et le code de retour 1 sans
              aucun fichier de sortie ; une erreur fatale apres la
              creation du .asm (sortie .exe impossible) supprime le .asm ;
              les 32 exemples executables donnent toujours la meme sortie

  TODO 24 - PROGRAMME PRINCIPAL, MODES VERBEUX ET DEBOGAGE [IMPLEMENTE]
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
            Realise : Run enchaine les six phases (lexeur, parseur et
              generateur, runtime ajoute avant le listing, encodeur,
              ecrivain, rapport) ; seules les phases lexeur, parseur et
              rapport tournent s'il y a des erreurs ; -v : banniere,
              fichiers, une ligne de statistiques par phase (lignes et
              tokens, declarations et instructions analysees,
              instructions, donnees et noms internes, tailles .text et
              .data, relocations et imports, taille du fichier) et liste
              des fichiers produits ; -d : tokens, types, decisions du
              parseur, table des symboles par portee, donnees, code
              interne complet (runtime compris) et listing hexadecimal
              <sortie>.lst ; -w, -w+ et -w- (derniere option retenue) ;
              codes de retour 0 (succes ou aide), 1 (erreur), 2 (usage)
            Verifie (matrice des fichiers produits pour hello.a60) :
              sans option -> h.exe seul ; -asm -> h.exe + h.asm ;
              -obj -> h.obj seul ; -obj -asm -> h.obj + h.asm ;
              -d -> h.exe + h.lst ; -obj -d -> h.obj + h.lst ; -v, -w et
              -w- -> h.exe seul ; -o n -> n.exe, n.asm, n.obj ; source
              sans extension (.a60 puis .alg) ; refus de -o vers un
              .asm ou vers le source, d'une extension inconnue, d'une
              option inconnue ; sans argument -> usage et code 2

  TODO 25 - VALIDATION SUR TOUS LES EXEMPLES SAMPLES\ALGOL60\* [IMPLEMENTE]
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
            Cas speciaux : test_lex.a60 (tous les symboles lexicaux,
              etiquettes non definies), test_emitter, test_symbols et
              test_types (declarations et expressions isolees) doivent
              produire un .EXE valide ; test_switch.a60 ne se termine pas
              (comparer le debut de sa sortie sous un delai)
            Mettre a jour README.md (ligne AL60CW32.PAS), ajouter
              DOC\TODO\AL60CW32.txt et BINLINUX\AL60CW32 (WIN32\
              al60cw32.exe a produire sous Windows)
            Realise : TESTS\AL60CW32\exp\*.exp (sorties attendues des 33
              exemples ; test_switch.exp ne contient que le debut de
              la sortie), TESTS\AL60CW32\runpe.c, stubs.asm et stubs.bin
              (chargeur PE minimal pour Linux x86-64, avec HeapFree),
              chkenc.py (encodage verifie par objdump) et
              TESTS\test_al60cw32.sh : pour chaque exemple, .EXE par
              defaut (ni .asm ni .obj), execution et comparaison de la
              sortie et du code de retour, -asm, -obj, -obj -asm, .obj
              lisible par objdump, .obj lie avec lld-link (alias
              kernel32 generes par le script) et execute, listing .ASM
              autonome, encodage ; puis 25 programmes fautifs (message,
              code 1, compteurs, aucun fichier), 9 avertissements avec
              -w et leur absence sans -w ou avec -w-, erreurs
              d'execution (indice, division par zero, canal 2 sur
              l'erreur standard), matrice des fichiers produits, -v, -d,
              -h, usage, source .alg ou sans extension, options et
              extensions refusees, nettoyage apres erreur fatale ;
              README.md (ligne AL60CW32.PAS), DOC\TODO\AL60CW32.txt et
              BINLINUX\AL60CW32
            Resultat : 365 verifications reussies, 0 echec, 0 ignoree ;
              WIN32\al60cw32.exe n'a pas pu etre genere ici (pas de
              compilateur croise Free Pascal vers Win32) : a produire
              avec fpc -Mtp AL60CW32.PAS sous Windows
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
  A60_MAINBP    = '_A60_MAINBP'; { cadre du programme principal        }

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
{ Fichiers de sortie crees pendant cette compilation : supprimes si une
  erreur fatale survient, pour ne laisser aucun fichier tronque. }
Var
  OutCreated  : Array[0..7] Of TString;
  OutCreatedN : Integer;

Procedure NoteOutput(Const Name : TString);
Begin
  If OutCreatedN <= 7 Then
  Begin
    OutCreated[OutCreatedN] := Name;
    Inc(OutCreatedN);
  End;
End;

Procedure RemoveOutputs;
Var
  I : Integer;
  F : File;
Begin
  For I := 0 To OutCreatedN - 1 Do
  Begin
    Assign(F, OutCreated[I]);
    Erase(F);
    If IOResult <> 0 Then ;
  End;
  OutCreatedN := 0;
End;

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('AL60CW32: erreur fatale: ', Msg);
  RemoveOutputs;
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

  { Mode de transmission d'un argument a un parametre. Un parametre par
    nom est transmis comme une paire de mots :
      mot 0 = adresse du thunk, ou 0 pour une reference directe
      mot 1 = BP de l'appelant (contexte du thunk), ou l'adresse
              de la variable quand le mot 0 vaut 0
    Le thunk est appele avec EAX = contexte ; il fixe EBP, evalue
    l'argument et retourne la valeur (thunk de lecture) ou l'adresse
    (thunk d'ecriture) dans EAX, ou ST(0) pour un real. }
  TArgClass = (
    AC_VALUE,          { parametre value : valeur convertie empilee    }
    AC_ARRAY,          { tableau : adresse du descripteur              }
    AC_CONST,          { constante : cellule en .data, par reference   }
    AC_REF,            { variable simple : adresse directe             }
    AC_FORWARD,        { parametre par nom de l'appelant : paire reprise }
    AC_THUNK,          { expression : thunk de lecture (TODO 17)       }
    AC_THUNK_RW,       { variable indicee ou convertie ecrite par la
                         procedure : thunk qui rend l'adresse (TODO 17) }
    AC_PROC            { procedure effective : paire (adresse, lien)   }
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
    LevelKnown : Boolean;     { etiquette : niveau connu (declaree ou
                                definie) ?                            }
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
  { [EBP-4] : ESP apres le prologue, restaure par un goto qui sort
    d'une procedure imbriquee (TODO 14) }
  SymAllocLocal(4);
  If SymTab[ProcIdx].Kind = SK_FUNC Then
    ScopeTab[CurProcScope].RetOfs :=
      SymAllocLocal(TypeSizeof(SymTab[ProcIdx].TypeIdx))
  Else
    ScopeTab[CurProcScope].RetOfs := SymAllocLocal(4);   { integer ignore }
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
  { toute procedure recoit un mot de lien statique en [EBP+8] (0 pour
    une procedure du programme principal) : un appel par une procedure
    formelle n'a pas a connaitre le niveau de l'effective }
  Ofs := ABI_PARAM_BASE + ABI_WORD_SIZE;
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
      SymTab[I].LevelKnown := True;
      SymTab[I].Level := CurLevel;
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
  SymTab[I].LevelKnown := True;
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
  CanHoist := ScopeTop >= 2;
  Dest := ScopeTab[S].FirstSym;
  For I := ScopeTab[S].FirstSym To SymCount - 1 Do
  Begin
    If SymTab[I].Kind = SK_LABEL Then
    Begin
      If Not SymTab[I].IsDefined Then
      Begin
        If CanHoist And (Not SymTab[I].LevelKnown) Then
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
  NoteOutput(FileName);
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

{ ---- Donnees (.data) ---- }

Function DataNew(NameIdx : Integer; K : TDataKind) : Integer;
Begin
  If DataCount >= MAX_DATAITEMS Then
    FatalError('trop de donnees statiques');
  FillChar(DataTab[DataCount], SizeOf(TDataItem), 0);
  DataTab[DataCount].Name := NameIdx;
  DataTab[DataCount].Kind := K;
  DataTab[DataCount].Str  := -1;
  DataNew := DataCount;
  Inc(DataCount);
End;

{ Cellule de Size octets mise a zero }
Procedure DataAddZero(NameIdx : Integer; Size : LongInt);
Begin
  DataTab[DataNew(NameIdx, DK_ZERO)].Size := Size;
End;

{ Chaine litterale : retourne le nom du label ; deux chaines egales
  partagent la meme cellule. }
Function DataStr(Const S : TString) : Integer;
Var
  I, N : Integer;
Begin
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And
       (AsmStrs[DataTab[I].Str] = S) Then
    Begin
      DataStr := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern(A60_STR_PFX + ItoS(ConstSeq));
  I := DataNew(N, DK_STR);
  DataTab[I].Str  := AsmStrAdd(S);
  DataTab[I].Size := Length(S);
  DataStr := N;
End;

{ Constante entiere en memoire (argument par nom, par reference) }
Function DataInt(V : LongInt) : Integer;
Var
  I, N : Integer;
Begin
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_INT) And (DataTab[I].Lo = V) Then
    Begin
      DataInt := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern('_A60C_' + ItoS(ConstSeq));
  I := DataNew(N, DK_INT);
  DataTab[I].Lo   := V;
  DataTab[I].Size := 4;
  DataInt := N;
End;

{ Constante reelle (QWORD) }
Function DataReal(V : Double) : Integer;
Var
  I, N : Integer;
  B    : TDoubleBits;
Begin
  B.D := V;
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_REAL) And (DataTab[I].Lo = B.Lo) And
       (DataTab[I].Hi = B.Hi) Then
    Begin
      DataReal := DataTab[I].Name;
      Exit;
    End;
  Inc(ConstSeq);
  N := Intern('_A60C_' + ItoS(ConstSeq));
  I := DataNew(N, DK_REAL);
  DataTab[I].Lo   := B.Lo;
  DataTab[I].Hi   := B.Hi;
  DataTab[I].Size := 8;
  DataReal := N;
End;

{ Table d'adresses (switch) : Entries = indices de noms }
Procedure DataTable(NameIdx : Integer; Const Entries : Array Of Integer;
                    Count : Integer);
Var
  I, K : Integer;
Begin
  K := DataNew(NameIdx, DK_TABLE);
  DataTab[K].First := TabEntCount;
  DataTab[K].Count := Count;
  DataTab[K].Size  := 4 * Count;
  For I := 0 To Count - 1 Do
  Begin
    If TabEntCount >= MAX_TABENT Then
      FatalError('tables de switch trop grandes');
    TabEnt[TabEntCount] := Entries[I];
    Inc(TabEntCount);
  End;
End;

{ Descripteur d'un tableau : nom de sa cellule (_A60DSC_x) }
Function DescName(S : Integer) : Integer;
Begin
  DescName := Intern('_A60DSC_' + Copy(SymTab[S].Mangled,
                     Length(A60_ARR_PFX) + 1, 120));
End;

{ Declare les cellules .data d'un symbole : variable globale (niveau 0
  ou own) de la taille de son type ; tableau global ou own : donnees
  (bornes constantes) et descripteur. Les noms _A60V_x, _A60O_x_n et
  _A60A_x viennent de SymAdd. }
Procedure DataDeclareSym(S : Integer);
Begin
  Case SymTab[S].Kind Of
    SK_VAR, SK_OWN:
      If SymTab[S].Storage = SC_GLOBAL Then
        DataAddZero(Intern(SymTab[S].Mangled),
                    TypeSizeof(SymTab[S].TypeIdx));
    SK_ARRAY:
      If SymTab[S].Storage = SC_GLOBAL Then
      Begin
        If (Not SymTab[S].ArrDynamic) And (SymTab[S].ArrBytes > 0) Then
          DataAddZero(Intern(SymTab[S].Mangled), SymTab[S].ArrBytes);
        DataAddZero(DescName(S), 4 * (2 + 3 * SymTab[S].ArrDims));
      End;
  End;
End;

{ Mode debug -d : liste des cellules de donnees }
Procedure DataDump;
Var
  I : Integer;
  K : TString;
Begin
  WriteLn('Donnees (', DataCount, ') :');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_ZERO  : K := 'zero';
      DK_STR   : K := 'chaine';
      DK_INT   : K := 'entier';
      DK_REAL  : K := 'reel';
      DK_TABLE : K := 'table';
    End;
    WriteLn('  ', NameTab[DataTab[I].Name], ' ', K, ' ',
            DataTab[I].Size, ' octets');
  End;
End;

{ ============================================================
  SECTION 8 - PARSEUR ET GENERATEUR DE CODE (TODO 09 a 18)
  ============================================================ }
{ ---- Primitives du parseur -------------------------------------- }
Var
  CurToken   : TToken;       { token courant du parseur             }
  ParkValid  : Boolean;      { un token est range (ParserUnget)     }
  ParkTok    : TToken;
  SyncLine, SyncCol : Integer;   { position du dernier arret de ParserSync }
  ProcCount   : LongInt;     { procedures declarees (statistiques)  }
  CallCount   : LongInt;     { appels de procedure ou fonction      }
  ThunkCount  : LongInt;     { thunks d'arguments par nom           }
  IntrinCount : LongInt;     { appels de fonctions standard         }
  IOCount     : LongInt;     { appels d'entree/sortie               }

Procedure ParserInit;
Begin
  ParkValid := False;
  SyncLine  := 0;
  SyncCol   := 0;
End;

Procedure ParserAdvance;
Begin
  If ParkValid Then
  Begin
    CurToken  := ParkTok;
    ParkValid := False;
  End
  Else
    LexNextToken(CurToken);
End;

{ Rend Saved (le token precedent) courant ; le token courant est
  range et reviendra au prochain ParserAdvance. Permet de regarder un
  token apres un identificateur avant de decider du type d'instruction. }
Procedure ParserUnget(Const Saved : TToken);
Begin
  ParkTok   := CurToken;
  ParkValid := True;
  CurToken  := Saved;
End;

Function TokText(Const T : TToken) : TString;
Begin
  Case T.Kind Of
    TK_EOF    : TokText := 'fin de fichier';
    TK_STRING : TokText := '"' + T.Val + '"';
    TK_INTEGER,
    TK_REAL   : TokText := T.Val;
  Else
    TokText := '''' + T.Val + '''';
  End;
End;

Procedure ParseError(Const Msg : TString);
Begin
  ErrorAt(CurToken.Line, CurToken.Col,
          Msg + ' (trouve: ' + TokText(CurToken) + ')');
End;

Function AtEOF : Boolean;
Begin
  AtEOF := (CurToken.Kind = TK_EOF);
End;

Function AtKw(Const S : TString) : Boolean;
Begin
  AtKw := (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = S);
End;

Function AtPunct(C : Char) : Boolean;
Begin
  AtPunct := (CurToken.Kind = TK_PUNCT) And (CurToken.Val = C);
End;

Function AtOp(Const S : TString) : Boolean;
Begin
  AtOp := (CurToken.Kind = TK_OP) And (CurToken.Val = S);
End;

Function AtTypeKw : Boolean;
Begin
  AtTypeKw := AtKw('integer') Or AtKw('real') Or AtKw('boolean') Or
              AtKw('string');
End;

Function AtDeclKw : Boolean;
Begin
  AtDeclKw := AtTypeKw Or AtKw('own') Or AtKw('array') Or
              AtKw('procedure') Or AtKw('switch') Or AtKw('label');
End;

{ Fin d'une instruction simple : ';' end, else ou fin de fichier }
Function AtStmtEnd : Boolean;
Begin
  AtStmtEnd := AtEOF Or AtPunct(';') Or AtKw('end') Or AtKw('else');
End;

Procedure ExpectPunct(C : Char);
Begin
  If AtPunct(C) Then
    ParserAdvance
  Else
    ParseError('''' + C + ''' attendu');
End;

{ Recuperation apres une erreur : avance jusqu au prochain ';', end,
  begin, for, if ou procedure (non consommes) pour reprendre l analyse
  (TODO 23). }
Function AtSyncKw : Boolean;
Begin
  AtSyncKw := AtKw('begin') Or AtKw('for') Or AtKw('if') Or
              AtKw('procedure');
End;

Procedure ParserSync;
Begin
  { garantie de progression : un arret repete sur le meme mot-cle est
    franchi }
  If AtSyncKw And (CurToken.Line = SyncLine) And
     (CurToken.Col = SyncCol) Then
    ParserAdvance;
  While Not (AtEOF Or AtPunct(';') Or AtKw('end') Or AtSyncKw) Do
    ParserAdvance;
  SyncLine := CurToken.Line;
  SyncCol  := CurToken.Col;
End;

{ ---- Expressions : arbre ----------------------------------------
  Les expressions sont analysees en arbre (pool ExprTab, vide avant
  chaque instruction) que le generateur parcourt. Chaque noeud porte
  son type. Ce TODO couvre les expressions primaires ; les operateurs
  (TODO 10 et 11) s'ajoutent au-dessus de ParsePrimary. ----------- }
Const
  MAX_ARRAY_ELEMS = 134217728;    { 2^27 elements }
  MAX_ARRAY_BYTES = 1073741824;   { 1 Go }
  MAX_EXPR     = {$IFDEF FPC}16384{$ELSE}512{$ENDIF};
  MAX_EXPR_STR = {$IFDEF FPC}256{$ELSE}16{$ENDIF};

Type
  TExprKind = (
    EX_INT,         { constante entiere                     }
    EX_REAL,        { constante reelle                      }
    EX_BOOL,        { true / false (IntVal = 1 ou 0)        }
    EX_STR,         { chaine litterale (StrIdx)             }
    EX_VAR,         { variable scalaire (Sym)               }
    EX_UNARY,       { Op appliquee a L                      }
    EX_BINARY,      { L Op R                                }
    EX_COND,        { if L then R else E                    }
    EX_ASSIGN,      { L := R (L : variable) ; valeur = celle de L }
    EX_INDEX,       { Sym[L...] : element de tableau (IntVal = nb d indices) }
    EX_LIST,        { liste : L = expression, R = suivant   }
    EX_LABEL,       { designateur : etiquette (Sym)         }
    EX_SWITCHREF,   { designateur : Sym[L] (element de switch) }
    EX_CALL,        { appel de Sym ; L = liste des arguments }
    EX_INTRIN,      { fonction standard (IntVal = TIntrinsic)    }
    EX_IO           { entree/sortie (IntVal = TIoOp, L = arguments) }
  );

  TIntrinsic = (
    IN_ABS, IN_SIGN, IN_ENTIER, IN_SQRT, IN_SIN, IN_COS, IN_ARCTAN,
    IN_LN, IN_EXP, IN_NONE
  );

  TIoOp = (
    IO_OUTSTRING, IO_OUTINTEGER, IO_OUTREAL, IO_OUTBOOLEAN, IO_NEWLINE,
    IO_PRINT, IO_ININTEGER, IO_INREAL, IO_INBOOLEAN, IO_SYSACT, IO_NONE
  );

  TExprNode = Record
    Kind    : TExprKind;
    Op      : String[5];
    Typ     : Integer;      { TY_IDX_* ou TY_UNKNOWN            }
    IntVal  : LongInt;
    RealVal : Double;
    StrIdx  : Integer;
    Conv    : TConv;        { EX_ASSIGN, EX_LIST : conversion a generer }
    Flag    : Boolean;      { EX_INDEX : controle de bornes a l execution }
    Sym     : Integer;
    L, R, E : Integer;      { fils, -1 si absent (E : sinon)    }
    Line    : Integer;
    Col     : Integer;
  End;

Var
  ExprTab      : Array[0..MAX_EXPR - 1] Of TExprNode;
  ExprCount    : Integer;
  ExprStrTab   : Array[0..MAX_EXPR_STR - 1] Of TString;
  ExprStrCount : Integer;

{ Vide le pool : appele avant chaque instruction }
Procedure ExprReset;
Begin
  ExprCount    := 0;
  ExprStrCount := 0;
End;

Function ExprNew(K : TExprKind; Typ : Integer; Line, Col : Integer)
         : Integer;
Begin
  If ExprCount >= MAX_EXPR Then
    FatalError('expression trop complexe (max ' + ItoS(MAX_EXPR) +
               ' noeuds)');
  FillChar(ExprTab[ExprCount], SizeOf(TExprNode), 0);
  ExprTab[ExprCount].Kind := K;
  ExprTab[ExprCount].Typ  := Typ;
  ExprTab[ExprCount].L    := -1;
  ExprTab[ExprCount].R    := -1;
  ExprTab[ExprCount].E    := -1;
  ExprTab[ExprCount].Sym  := -1;
  ExprTab[ExprCount].Line := Line;
  ExprTab[ExprCount].Col  := Col;
  ExprNew := ExprCount;
  Inc(ExprCount);
End;

Function ExprMakeInt(V : LongInt; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_INT, TY_IDX_INTEGER, Line, Col);
  ExprTab[N].IntVal := V;
  ExprMakeInt := N;
End;

Function ExprMakeReal(V : Double; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_REAL, TY_IDX_REAL, Line, Col);
  ExprTab[N].RealVal := V;
  ExprMakeReal := N;
End;

Function ExprMakeBool(V : Boolean; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_BOOL, TY_IDX_BOOLEAN, Line, Col);
  If V Then ExprTab[N].IntVal := 1;
  ExprMakeBool := N;
End;

{ Range S dans la table des chaines de l'expression ; retourne l'indice }
Function ExprAddStr(Const S : TString) : Integer;
Begin
  If ExprStrCount >= MAX_EXPR_STR Then
    FatalError('trop de chaines dans une expression');
  ExprStrTab[ExprStrCount] := S;
  ExprAddStr := ExprStrCount;
  Inc(ExprStrCount);
End;

Function ExprMakeStr(Const S : TString; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_STR, TY_IDX_STRING, Line, Col);
  ExprTab[N].StrIdx := ExprAddStr(S);
  ExprMakeStr := N;
End;

Function ExprMakeVar(Sym : Integer; Line, Col : Integer) : Integer;
Var
  N : Integer;
Begin
  N := ExprNew(EX_VAR, SymTab[Sym].TypeIdx, Line, Col);
  ExprTab[N].Sym := Sym;
  ExprMakeVar := N;
End;

Function ConvName(C : TConv) : TString;
Begin
  Case C Of
    CV_NONE        : ConvName := 'none';
    CV_INT_TO_REAL : ConvName := 'int->real';
    CV_REAL_TO_INT : ConvName := 'real->int';
    CV_INT_TO_BOOL : ConvName := 'int->bool';
    CV_ERROR       : ConvName := 'error';
  End;
End;

{ Arrondi au plus proche, demi vers le haut : entier(x + 0.5) }
Function RoundHalfUp(X : Double) : LongInt;
Var
  Y : Double;
  I : LongInt;
Begin
  Y := X + 0.5;
  I := Trunc(Y);
  If (Y < 0) And (Frac(Y) <> 0) Then Dec(I);
  RoundHalfUp := I;
End;

{ Convertit la valeur du noeud N vers le type Dest : verifie la
  compatibilite, signale les conversions implicites (TypeConvNote) et
  plie la conversion des constantes ; Conv indique la conversion a
  generer pour une valeur non constante. Retourne False apres avoir
  signale une erreur. }
Function ExprCoerceCtx(N, Dest : Integer; Var Conv : TConv;
                       Line, Col : Integer; Const Ctx : TString)
         : Boolean;
Var
  Note : TString;
Begin
  ExprCoerceCtx := False;
  Conv := TypeConversion(ExprTab[N].Typ, Dest);
  If Conv = CV_ERROR Then
  Begin
    ErrorAt(Line, Col, Ctx + ' incompatible: ' +
            TypeName(ExprTab[N].Typ) + ' vers ' + TypeName(Dest));
    Exit;
  End;
  Note := TypeConvNote(ExprTab[N].Typ, Dest);
  If Note <> '' Then WarnAt(Line, Col, Note);
  Case ExprTab[N].Kind Of
    EX_INT:
      If Dest = TY_IDX_REAL Then
      Begin
        ExprTab[N].RealVal := ExprTab[N].IntVal;
        ExprTab[N].Kind := EX_REAL;
        ExprTab[N].Typ  := TY_IDX_REAL;
        Conv := CV_NONE;
      End
      Else If Dest = TY_IDX_BOOLEAN Then
      Begin
        If ExprTab[N].IntVal <> 0 Then ExprTab[N].IntVal := 1;
        ExprTab[N].Kind := EX_BOOL;
        ExprTab[N].Typ  := TY_IDX_BOOLEAN;
        Conv := CV_NONE;
      End;
    EX_REAL:
      If Dest = TY_IDX_INTEGER Then
      Begin
        If Abs(ExprTab[N].RealVal) >= 2147483647.0 Then
        Begin
          ErrorAt(Line, Col, 'constante reelle hors de l''intervalle ' +
                  'integer');
          Exit;
        End;
        ExprTab[N].IntVal := RoundHalfUp(ExprTab[N].RealVal);
        ExprTab[N].Kind := EX_INT;
        ExprTab[N].Typ  := TY_IDX_INTEGER;
        Conv := CV_NONE;
      End;
    EX_BOOL:
      If Dest = TY_IDX_INTEGER Then
      Begin
        ExprTab[N].Kind := EX_INT;
        ExprTab[N].Typ  := TY_IDX_INTEGER;
      End
      Else If Dest = TY_IDX_REAL Then
      Begin
        ExprTab[N].RealVal := ExprTab[N].IntVal;
        ExprTab[N].Kind := EX_REAL;
        ExprTab[N].Typ  := TY_IDX_REAL;
        Conv := CV_NONE;
      End;
  End;
  ExprCoerceCtx := True;
End;

{ Affectation : voir ExprCoerceCtx }
Function ExprCoerce(N, Dest : Integer; Var Conv : TConv;
                    Line, Col : Integer) : Boolean;
Begin
  ExprCoerce := ExprCoerceCtx(N, Dest, Conv, Line, Col, 'affectation');
End;


{ ---- Expressions arithmetiques : repliement et construction ------- }
Type
  {$IFDEF FPC}
  TWide = Int64;
  {$ELSE}
  TWide = Comp;
  {$ENDIF}

Var
  FoldCount : LongInt;     { operations repliees (statistiques) }

Function ExprIsConst(N : Integer) : Boolean;
Begin
  ExprIsConst := (N >= 0) And
                 (ExprTab[N].Kind In [EX_INT, EX_REAL]);
End;

Function ExprConstReal(N : Integer) : Double;
Begin
  If ExprTab[N].Kind = EX_INT Then
    ExprConstReal := ExprTab[N].IntVal
  Else
    ExprConstReal := ExprTab[N].RealVal;
End;

{ Constante booleenne ou entiere utilisable comme condition }
Function ExprIsCondConst(N : Integer) : Boolean;
Begin
  ExprIsCondConst := (N >= 0) And
                     (ExprTab[N].Kind In [EX_INT, EX_BOOL]);
End;

Function ExprTruth(N : Integer) : Boolean;
Begin
  ExprTruth := (ExprTab[N].IntVal <> 0);
End;

{ Constante numerique ou booleenne (comparable) }
Function ExprIsNumConst(N : Integer) : Boolean;
Begin
  ExprIsNumConst := (N >= 0) And
                    (ExprTab[N].Kind In [EX_INT, EX_REAL, EX_BOOL]);
End;

Function ExprNumReal(N : Integer) : Double;
Begin
  If ExprTab[N].Kind = EX_REAL Then
    ExprNumReal := ExprTab[N].RealVal
  Else
    ExprNumReal := ExprTab[N].IntVal;
End;

{ Transforme le noeud N en constante booleenne (repliement) }
Procedure ExprSetBool(N : Integer; V : Boolean);
Begin
  ExprTab[N].Kind := EX_BOOL;
  ExprTab[N].Typ  := TY_IDX_BOOLEAN;
  ExprTab[N].L    := -1;
  ExprTab[N].R    := -1;
  If V Then ExprTab[N].IntVal := 1 Else ExprTab[N].IntVal := 0;
  Inc(FoldCount);
End;

Function OpIsRel(Const Op : TString) : Boolean;
Begin
  OpIsRel := (Op = '=') Or (Op = '#') Or (Op = '<') Or (Op = '<=') Or
             (Op = '>') Or (Op = '>=');
End;

Function OpIsLogic(Const Op : TString) : Boolean;
Begin
  OpIsLogic := (Op = 'and') Or (Op = 'or') Or (Op = 'impl') Or
               (Op = 'equiv');
End;

Function FoldRange(W : TWide) : Boolean;
Begin
  FoldRange := (W <= MaxLongInt) And (W >= -TWide(MaxLongInt) - 1);
End;

{ Operation entiere sur constantes (+ - * div ^ avec exposant >= 0) ;
  Err <> '' en cas d'erreur }
Procedure FoldIntBin(Const Op : TString; A, B : LongInt;
                     Var R : LongInt; Var Err : TString);
Var
  W, Base : TWide;
  E       : LongInt;
Begin
  Err := '';
  R := 0;
  W := 0;
  If Op = '+' Then
    W := TWide(A) + TWide(B)
  Else If Op = '-' Then
    W := TWide(A) - TWide(B)
  Else If Op = '*' Then
    W := TWide(A) * TWide(B)
  Else If Op = 'div' Then
  Begin
    If B = 0 Then
    Begin
      Err := 'division par zero';
      Exit;
    End;
    W := TWide(A) Div TWide(B);          { quotient tronque vers zero }
  End
  Else If Op = '^' Then
  Begin
    W := 1;
    Base := A;
    E := B;
    While E > 0 Do
    Begin
      If Odd(E) Then
      Begin
        W := W * Base;
        If Not FoldRange(W) Then Break;
      End;
      E := E Div 2;
      If E > 0 Then
      Begin
        Base := Base * Base;
        If (Base > MaxLongInt) Or (Base < -TWide(MaxLongInt) - 1) Then
        Begin
          W := TWide(MaxLongInt) + 1;     { debordement certain }
          Break;
        End;
      End;
    End;
  End;
  If Not FoldRange(W) Then
  Begin
    Err := 'debordement entier 32 bits dans une constante';
    Exit;
  End;
  R := W;
End;

{ Operation reelle sur constantes ; Err <> '' en cas d'erreur }
Procedure FoldRealBin(Const Op : TString; A, B : Double;
                      Var R : Double; Var Err : TString);
Var
  I, N : LongInt;
Begin
  Err := '';
  R := 0;
  If Op = '+' Then
    R := A + B
  Else If Op = '-' Then
    R := A - B
  Else If Op = '*' Then
    R := A * B
  Else If Op = '/' Then
  Begin
    If B = 0 Then
    Begin
      Err := 'division par zero';
      Exit;
    End;
    R := A / B;
  End
  Else If Op = '^' Then
  Begin
    If (Frac(B) = 0) And (Abs(B) <= 1024) Then
    Begin
      N := Trunc(Abs(B));
      R := 1;
      For I := 1 To N Do
      Begin
        R := R * A;
        If RealBad(R) Then Break;
      End;
      If (B < 0) And (Not RealBad(R)) Then
      Begin
        If R = 0 Then
          Err := 'division par zero (0 ^ exposant negatif)'
        Else
          R := 1 / R;
      End;
    End
    Else If A > 0 Then
      R := Exp(B * Ln(A))
    Else If (A = 0) And (B > 0) Then
      R := 0
    Else
      Err := 'puissance reelle invalide (base <= 0, exposant non entier)';
  End;
  If (Err = '') And RealBad(R) Then
    Err := 'debordement reel dans une constante';
End;

Procedure OpTypeError(Const Op : TString; A, B : Integer;
                      Line, Col : Integer);
Begin
  If B = TY_UNKNOWN Then
    ErrorAt(Line, Col, 'operande incompatible avec ''' + Op + ''': ' +
            TypeName(A))
  Else
    ErrorAt(Line, Col, 'operandes incompatibles avec ''' + Op + ''': ' +
            TypeName(A) + ', ' + TypeName(B));
End;

{ Un entier utilise comme operande booleen est vrai s'il est different
  de zero : avertissement (TypeConvNote) }
Procedure ExprNoteCond(N : Integer; Line, Col : Integer);
Begin
  If ExprTab[N].Typ = TY_IDX_INTEGER Then
    WarnAt(Line, Col, TypeConvNote(TY_IDX_INTEGER, TY_IDX_BOOLEAN));
End;

{ Un Boolean utilise comme operande arithmetique ou compare a un
  nombre vaut 0 ou 1 : avertissement (TypeConvNote) }
Procedure ExprNoteBoolNum(L, R : Integer; Both : Boolean;
                          Line, Col : Integer);
Begin
  If (Not Both) And (ExprTab[L].Typ = ExprTab[R].Typ) Then Exit;
  If ExprTab[L].Typ = TY_IDX_BOOLEAN Then
    WarnAt(Line, Col, TypeConvNote(TY_IDX_BOOLEAN, TY_IDX_INTEGER));
  If ExprTab[R].Typ = TY_IDX_BOOLEAN Then
    WarnAt(Line, Col, TypeConvNote(TY_IDX_BOOLEAN, TY_IDX_INTEGER));
End;

{ + ou - unaire, ou not. La constante est repliee ; +x est l'identite. }
Function ExprMakeUnary(Const Op : TString; A : Integer;
                       Line, Col : Integer) : Integer;
Var
  N, T : Integer;
Begin
  ExprMakeUnary := -1;
  If A < 0 Then Exit;
  If Op = 'not' Then
  Begin
    If Not TypeIsCondition(ExprTab[A].Typ) Then
    Begin
      OpTypeError(Op, ExprTab[A].Typ, TY_UNKNOWN, Line, Col);
      Exit;
    End;
    ExprNoteCond(A, Line, Col);
    If ExprIsCondConst(A) Then
    Begin
      ExprSetBool(A, Not ExprTruth(A));
      ExprMakeUnary := A;
      Exit;
    End;
    N := ExprNew(EX_UNARY, TY_IDX_BOOLEAN, Line, Col);
    ExprTab[N].Op := Op;
    ExprTab[N].L  := A;
    ExprMakeUnary := N;
    Exit;
  End;
  T := TypeArith(ExprTab[A].Typ, ExprTab[A].Typ);
  If T = TY_UNKNOWN Then
  Begin
    OpTypeError(Op, ExprTab[A].Typ, TY_UNKNOWN, Line, Col);
    Exit;
  End;
  If ExprIsConst(A) Then
  Begin
    If Op = '-' Then
    Begin
      If ExprTab[A].Kind = EX_INT Then
        ExprTab[A].IntVal := -ExprTab[A].IntVal
      Else
        ExprTab[A].RealVal := -ExprTab[A].RealVal;
      Inc(FoldCount);
    End;
    ExprMakeUnary := A;
    Exit;
  End;
  If (Op = '+') And (ExprTab[A].Typ = T) Then
  Begin
    ExprMakeUnary := A;
    Exit;
  End;
  N := ExprNew(EX_UNARY, T, Line, Col);
  ExprTab[N].Op := Op;
  ExprTab[N].L  := A;
  ExprMakeUnary := N;
End;

{ L Op R pour + - * / div ^ (Revised Report, 3.3) : type du resultat
  par TypeArith, TypeDivide, TypeIntDiv, TypePower ; operations sur
  deux constantes repliees ; division par une constante nulle signalee }
Function ExprMakeBinary(Const Op : TString; L, R : Integer;
                        Line, Col : Integer) : Integer;
Var
  N, T, TL, TR, Sign : Integer;
  IV                 : LongInt;
  RV                 : Double;
  Err                : TString;
  D1, D2             : Double;
  Cmp                : Integer;
  Res                : Boolean;
Begin
  ExprMakeBinary := -1;
  If (L < 0) Or (R < 0) Then Exit;
  TL := ExprTab[L].Typ;
  TR := ExprTab[R].Typ;

  { relationnels : operandes arithmetiques, resultat Boolean }
  If OpIsRel(Op) Then
  Begin
    If TypeRelational(TL, TR) = TY_UNKNOWN Then
    Begin
      OpTypeError(Op, TL, TR, Line, Col);
      Exit;
    End;
    ExprNoteBoolNum(L, R, False, Line, Col);
    If ExprIsNumConst(L) And ExprIsNumConst(R) Then
    Begin
      If (ExprTab[L].Kind = EX_REAL) Or (ExprTab[R].Kind = EX_REAL) Then
      Begin
        D1 := ExprNumReal(L);
        D2 := ExprNumReal(R);
        Cmp := 0;
        If D1 < D2 Then Cmp := -1 Else If D1 > D2 Then Cmp := 1;
      End
      Else
      Begin
        Cmp := 0;
        If ExprTab[L].IntVal < ExprTab[R].IntVal Then
          Cmp := -1
        Else If ExprTab[L].IntVal > ExprTab[R].IntVal Then
          Cmp := 1;
      End;
      If Op = '=' Then
        Res := (Cmp = 0)
      Else If Op = '#' Then
        Res := (Cmp <> 0)
      Else If Op = '<' Then
        Res := (Cmp < 0)
      Else If Op = '<=' Then
        Res := (Cmp <= 0)
      Else If Op = '>' Then
        Res := (Cmp > 0)
      Else
        Res := (Cmp >= 0);
      ExprSetBool(L, Res);
      ExprMakeBinary := L;
      Exit;
    End;
    N := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, Line, Col);
    ExprTab[N].Op := Op;
    ExprTab[N].L  := L;
    ExprTab[N].R  := R;
    ExprMakeBinary := N;
    Exit;
  End;

  { operateurs logiques : operandes booleens (ou entiers, avec
    avertissement), resultat Boolean ; constantes repliees }
  If OpIsLogic(Op) Then
  Begin
    If Not (TypeIsCondition(TL) And TypeIsCondition(TR)) Then
    Begin
      OpTypeError(Op, TL, TR, Line, Col);
      Exit;
    End;
    ExprNoteCond(L, Line, Col);
    ExprNoteCond(R, Line, Col);
    If ExprIsCondConst(L) Then
    Begin
      If ExprIsCondConst(R) Then
      Begin
        If Op = 'and' Then
          Res := ExprTruth(L) And ExprTruth(R)
        Else If Op = 'or' Then
          Res := ExprTruth(L) Or ExprTruth(R)
        Else If Op = 'impl' Then
          Res := (Not ExprTruth(L)) Or ExprTruth(R)
        Else
          Res := (ExprTruth(L) = ExprTruth(R));
        ExprSetBool(L, Res);
        ExprMakeBinary := L;
        Exit;
      End;
      { gauche constante : la droite n'est pas toujours evaluee }
      If ((Op = 'and') And (Not ExprTruth(L))) Or
         ((Op = 'or') And ExprTruth(L)) Or
         ((Op = 'impl') And (Not ExprTruth(L))) Then
      Begin
        ExprSetBool(L, Op <> 'and');
        ExprMakeBinary := L;
        Exit;
      End;
      If ((Op = 'and') Or (Op = 'or') Or (Op = 'impl')) And
         (ExprTab[R].Typ = TY_IDX_BOOLEAN) Then
      Begin
        Inc(FoldCount);               { true and x, false or x, true impl x }
        ExprMakeBinary := R;
        Exit;
      End;
    End;
    N := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, Line, Col);
    ExprTab[N].Op := Op;
    ExprTab[N].L  := L;
    ExprTab[N].R  := R;
    ExprMakeBinary := N;
    Exit;
  End;

  { type du resultat }
  If Op = '/' Then
    T := TypeDivide(TL, TR)
  Else If Op = 'div' Then
    T := TypeIntDiv(TL, TR)
  Else If Op = '^' Then
  Begin
    Sign := 0;
    If ExprIsConst(R) Then
    Begin
      If ExprConstReal(R) < 0 Then Sign := -1 Else Sign := 1;
    End;
    T := TypePower(TL, TR, Sign);
  End
  Else
    T := TypeArith(TL, TR);
  If T = TY_UNKNOWN Then
  Begin
    If (Op = 'div') And (TypeArith(TL, TR) <> TY_UNKNOWN) Then
      ErrorAt(Line, Col, '''div'' demande des operandes entiers')
    Else
      OpTypeError(Op, TL, TR, Line, Col);
    Exit;
  End;
  ExprNoteBoolNum(L, R, True, Line, Col);

  { division par une constante nulle }
  If ((Op = '/') Or (Op = 'div')) And ExprIsConst(R) And
     (ExprConstReal(R) = 0) Then
  Begin
    ErrorAt(Line, Col, 'division par zero');
    Exit;
  End;

  { repliement de deux constantes }
  If ExprIsConst(L) And ExprIsConst(R) Then
  Begin
    Err := '';
    If T = TY_IDX_INTEGER Then
    Begin
      FoldIntBin(Op, ExprTab[L].IntVal, ExprTab[R].IntVal, IV, Err);
      If Err = '' Then
      Begin
        ExprTab[L].IntVal := IV;
        ExprTab[L].Line := Line;
        ExprTab[L].Col  := Col;
      End;
    End
    Else
    Begin
      FoldRealBin(Op, ExprConstReal(L), ExprConstReal(R), RV, Err);
      If Err = '' Then
      Begin
        ExprTab[L].Kind := EX_REAL;
        ExprTab[L].Typ  := TY_IDX_REAL;
        ExprTab[L].RealVal := RV;
        ExprTab[L].Line := Line;
        ExprTab[L].Col  := Col;
      End;
    End;
    If Err <> '' Then
    Begin
      ErrorAt(Line, Col, Err);
      Exit;
    End;
    Inc(FoldCount);
    ExprMakeBinary := L;
    Exit;
  End;

  N := ExprNew(EX_BINARY, T, Line, Col);
  ExprTab[N].Op := Op;
  ExprTab[N].L  := L;
  ExprTab[N].R  := R;
  ExprMakeBinary := N;
End;

{ if C then T else E : valeur de T ou de E. Les branches ont un type
  commun : Boolean si les deux le sont, chaine si les deux le sont,
  sinon le type arithmetique (real si l'une l'est). Une condition
  constante choisit directement la branche. }
Function ExprMakeCond(C, T, E : Integer; Line, Col : Integer) : Integer;
Var
  N, Res, Sel : Integer;
Begin
  ExprMakeCond := -1;
  If (C < 0) Or (T < 0) Or (E < 0) Then Exit;
  If (ExprTab[T].Typ = TY_IDX_BOOLEAN) And
     (ExprTab[E].Typ = TY_IDX_BOOLEAN) Then
    Res := TY_IDX_BOOLEAN
  Else If (ExprTab[T].Typ = TY_IDX_STRING) And
          (ExprTab[E].Typ = TY_IDX_STRING) Then
    Res := TY_IDX_STRING
  Else
  Begin
    Res := TypeArith(ExprTab[T].Typ, ExprTab[E].Typ);
    If Res = TY_UNKNOWN Then
    Begin
      ErrorAt(Line, Col, 'branches then/else de types incompatibles: ' +
              TypeName(ExprTab[T].Typ) + ', ' + TypeName(ExprTab[E].Typ));
      Exit;
    End;
  End;

  If ExprIsCondConst(C) Then
  Begin
    If ExprTruth(C) Then Sel := T Else Sel := E;
    If ExprTab[Sel].Typ = Res Then
    Begin
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
    If (Res = TY_IDX_REAL) And (ExprTab[Sel].Kind In [EX_INT, EX_BOOL]) Then
    Begin
      ExprTab[Sel].RealVal := ExprTab[Sel].IntVal;
      ExprTab[Sel].Kind := EX_REAL;
      ExprTab[Sel].Typ  := TY_IDX_REAL;
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
    If (Res = TY_IDX_INTEGER) And (ExprTab[Sel].Kind = EX_BOOL) Then
    Begin
      ExprTab[Sel].Kind := EX_INT;
      ExprTab[Sel].Typ  := TY_IDX_INTEGER;
      Inc(FoldCount);
      ExprMakeCond := Sel;
      Exit;
    End;
  End;

  N := ExprNew(EX_COND, Res, Line, Col);
  ExprTab[N].L := C;
  ExprTab[N].R := T;
  ExprTab[N].E := E;
  ExprMakeCond := N;
End;

{ ---- Expressions primaires -------------------------------------- }

Function ParseExpr : Integer; Forward;

Function SymIsArrayLike(S : Integer) : Boolean;
Begin
  SymIsArrayLike := (SymTab[S].Kind = SK_ARRAY) Or
    ((SymTab[S].Kind In [SK_PARAM_VALUE, SK_PARAM_NAME]) And
     (SymTab[S].TypeIdx = TY_IDX_ARRAY));
End;

{ nom[i] ou nom[i, j] : le token courant est le '[' qui suit le nom.
  Chaque indice est converti en integer ; les constantes sont
  verifiees contre les bornes connues. Flag = True quand le generateur
  doit controler les bornes a l'execution (_A60RT_CHKIDX). }
Function ParseIndexed(Const Tok : TToken; S : Integer) : Integer;
Var
  Head, Tail, Item, E, N, Dims, Node : Integer;
  Bad, NeedCheck                     : Boolean;
  Conv                               : TConv;
  Line, Col                          : Integer;
Begin
  Dims := SymTab[S].ArrDims;
  Head := -1;
  Tail := -1;
  N    := 0;
  Bad  := False;
  NeedCheck := (Dims = 0) Or SymTab[S].ArrDynamic;
  ParserAdvance;                            { [ }
  Repeat
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E := ParseExpr;
    If E >= 0 Then
      If Not ExprCoerceCtx(E, TY_IDX_INTEGER, Conv, Line, Col,
                           'indice') Then E := -1;
    Inc(N);
    If E < 0 Then
      Bad := True
    Else
    Begin
      Item := ExprNew(EX_LIST, TY_IDX_INTEGER, Line, Col);
      ExprTab[Item].L    := E;
      ExprTab[Item].Conv := Conv;
      If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
      Tail := Item;
      If ExprTab[E].Kind = EX_INT Then
      Begin
        If (Dims > 0) And (N <= Dims) And (Not SymTab[S].ArrDynamic) Then
        Begin
          If (ExprTab[E].IntVal < SymTab[S].ArrLo[N]) Or
             (ExprTab[E].IntVal > SymTab[S].ArrHi[N]) Then
          Begin
            ErrorAt(Line, Col, 'indice hors bornes: ' +
                    ItoS(ExprTab[E].IntVal) + ' (' + Tok.Val + '[' +
                    ItoS(SymTab[S].ArrLo[N]) + ':' +
                    ItoS(SymTab[S].ArrHi[N]) + '])');
            Bad := True;
          End;
        End;
      End
      Else
        NeedCheck := True;
    End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  If AtPunct(']') Then
    ParserAdvance
  Else
    ParseError(''']'' attendu');
  If (Dims > 0) And (N <> Dims) Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, 'tableau ' + Tok.Val + ': ' + ItoS(N) +
            ' indice(s) au lieu de ' + ItoS(Dims));
    Bad := True;
  End;
  ParseIndexed := -1;
  If Bad Then Exit;
  Node := ExprNew(EX_INDEX, SymTab[S].ElemType, Tok.Line, Tok.Col);
  ExprTab[Node].Sym    := S;
  ExprTab[Node].L      := Head;
  ExprTab[Node].IntVal := N;
  ExprTab[Node].Flag   := NeedCheck;
  ParseIndexed := Node;
End;

{ Sous-script constants : tous les indices du tableau sont des entiers
  constants (l'adresse de l'element ne change donc jamais). }
Function IndexIsFixed(E : Integer) : Boolean;
Var
  I : Integer;
Begin
  IndexIsFixed := False;
  If ExprTab[E].Flag Then Exit;             { controle de bornes requis }
  I := ExprTab[E].L;
  While I >= 0 Do
  Begin
    If ExprTab[ExprTab[I].L].Kind <> EX_INT Then Exit;
    I := ExprTab[I].R;
  End;
  IndexIsFixed := True;
End;

{ Argument d'appel pour le parametre P. Un parametre tableau recoit le
  nom d'un tableau ; un parametre value, une expression convertie vers
  son type ; un parametre par nom, une expression (thunk au TODO 15)
  dont le type doit etre convertible vers celui du parametre. Item.Flag
  indique un argument qui est une variable ou un element de tableau du
  bon type : il pourra etre passe par reference au lieu d'un thunk. }
Function ParseCallArg(P : Integer; Const ProcName : TString;
                      Var Item : Integer) : Boolean;
Var
  Tok       : TToken;
  E, S      : Integer;
  Conv      : TConv;
  Line, Col : Integer;
  Cls       : TArgClass;
  IsLv      : Boolean;
Begin
  ParseCallArg := False;
  Item := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  Conv := CV_NONE;
  If SymTab[P].TypeIdx = TY_IDX_ARRAY Then
  Begin
    Tok := CurToken;
    If Tok.Kind <> TK_IDENT Then
    Begin
      ParseError('nom de tableau attendu pour le parametre ' +
                 SymTab[P].Name);
      Exit;
    End;
    ParserAdvance;
    S := SymFind(Tok.Val);
    If (S < 0) Or (Not SymIsArrayLike(S)) Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, 'tableau attendu pour le parametre ' +
              SymTab[P].Name + ': ' + Tok.Val);
      Exit;
    End;
    If SymTab[S].ElemType <> SymTab[P].ElemType Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, 'tableau ' + Tok.Val + ' de ' +
              TypeName(SymTab[S].ElemType) + ' au lieu de ' +
              TypeName(SymTab[P].ElemType));
      Exit;
    End;
    E := ExprNew(EX_VAR, TY_IDX_ARRAY, Tok.Line, Tok.Col);
    ExprTab[E].Sym := S;
  End
  Else If SymTab[P].TypeIdx = TY_IDX_PROCEDURE Then
  Begin
    { procedure effective (ou formelle) passee en argument }
    Tok := CurToken;
    S := -1;
    If Tok.Kind = TK_IDENT Then
    Begin
      ParserAdvance;
      S := SymFind(Tok.Val);
    End;
    If (S < 0) Or (Not ((SymTab[S].Kind In [SK_PROC, SK_FUNC]) Or
        (SymTab[S].Kind In [SK_PARAM_NAME, SK_PARAM_VALUE]) And
        (SymTab[S].TypeIdx = TY_IDX_PROCEDURE))) Then
    Begin
      If Tok.Kind <> TK_IDENT Then
        ParseError('nom de procedure attendu pour le parametre ' +
                   SymTab[P].Name)
      Else
        ErrorAt(Tok.Line, Tok.Col, 'procedure attendue pour le ' +
                'parametre ' + SymTab[P].Name + ': ' + Tok.Val);
      Exit;
    End;
    E := ExprNew(EX_VAR, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
    ExprTab[E].Sym := S;
    Item := ExprNew(EX_LIST, TY_IDX_PROCEDURE, Line, Col);
    ExprTab[Item].L      := E;
    ExprTab[Item].IntVal := Ord(AC_PROC);
    ParseCallArg := True;
    Exit;
  End
  Else If SymTab[P].TypeIdx In [TY_IDX_SWITCH, TY_IDX_LABEL] Then
  Begin
    ErrorAt(Line, Col, 'parametre ' + SymTab[P].Name + ' de ' +
            ProcName + ': switch ou etiquette en parametre non ' +
            'supporte');
    Exit;
  End
  Else
  Begin
    E := ParseExpr;
    If E < 0 Then Exit;
    If Not ExprCoerceCtx(E, SymTab[P].TypeIdx, Conv, Line, Col,
                         'argument') Then Exit;
  End;
  { mode de transmission de l'argument }
  If SymTab[P].TypeIdx = TY_IDX_ARRAY Then
    Cls := AC_ARRAY
  Else If (SymTab[P].Kind = SK_PARAM_VALUE) Or
          (SymTab[P].TypeIdx = TY_IDX_STRING) Then
    Cls := AC_VALUE
  Else
  Begin
    IsLv := ExprTab[E].Kind In [EX_VAR, EX_INDEX];
    If SymTab[P].IsWritten Then
    Begin
      If Not IsLv Then
      Begin
        ErrorAt(Line, Col, 'argument non assignable: ' + ProcName +
                ' modifie le parametre ' + SymTab[P].Name);
        Exit;
      End;
      If Conv <> CV_NONE Then
      Begin
        ErrorAt(Line, Col, 'argument de type ' +
                TypeName(ExprTab[E].Typ) + ': ' + ProcName +
                ' modifie le parametre ' + SymTab[P].Name + ' (' +
                TypeName(SymTab[P].TypeIdx) + '), meme type exige');
        Exit;
      End;
      { l'ecriture traverse l'appelant : son parametre par nom aussi }
      If (ExprTab[E].Kind = EX_VAR) And
         (SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME) Then
        SymTab[ExprTab[E].Sym].IsWritten := True;
    End;
    If ExprTab[E].Kind In [EX_INT, EX_REAL, EX_BOOL] Then
      Cls := AC_CONST
    Else If (ExprTab[E].Kind = EX_VAR) And (Conv = CV_NONE) Then
    Begin
      If SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME Then
        Cls := AC_FORWARD
      Else
        Cls := AC_REF;
    End
    Else If (ExprTab[E].Kind = EX_INDEX) And (Conv = CV_NONE) And
            IndexIsFixed(E) Then
      Cls := AC_REF
    Else If IsLv And SymTab[P].IsWritten Then
      Cls := AC_THUNK_RW
    Else
      Cls := AC_THUNK;
  End;

  Item := ExprNew(EX_LIST, ExprTab[E].Typ, Line, Col);
  ExprTab[Item].L      := E;
  ExprTab[Item].Conv   := Conv;
  ExprTab[Item].IntVal := Ord(Cls);
  ExprTab[Item].Flag   := (Cls = AC_REF);
  If Cls In [AC_THUNK, AC_THUNK_RW] Then
  Begin
    { le thunk est emis par le generateur au moment de l'appel : il
      evalue (ou localise) l'argument dans le contexte de l'appelant }
    ExprTab[Item].StrIdx :=
      ExprAddStr(UniqueMangle(MangleThunk(ProcName, SymTab[P].Name)));
    Inc(ThunkCount);
  End;
  ParseCallArg := True;
End;

{ Parametre de type procedure (procedure formelle) ? }
Function IsFormalProc(S : Integer) : Boolean;
Begin
  IsFormalProc := (SymTab[S].Kind In [SK_PARAM_NAME, SK_PARAM_VALUE]) And
                  (SymTab[S].TypeIdx = TY_IDX_PROCEDURE);
End;

{ nom(arg, arg...) ou nom (sans parentheses) : appel de la procedure
  ou fonction S. Tok = le nom, deja consomme. Le nombre d'arguments
  est verifie. Valeur : le type de retour d'une fonction, ou le type
  procedure (aucune valeur). Convention d'appel :
    - arguments empiles de droite a gauche, puis le lien statique
      pour une procedure declaree dans une autre procedure
    - CALL, la procedure nettoie la pile (RET n, n = ParamBytes)
    - resultat dans EAX (integer, Boolean) ou ST(0) (real) }
Function ParseCall(Const Tok : TToken; S : Integer) : Integer;
Var
  Head, Tail, Item, Expected, N, Node : Integer;
  Arg, Line0, Col0                     : Integer;
  Bad                                  : Boolean;
Begin
  ParseCall := -1;
  Bad := False;
  Expected := SymTab[S].ParamCount;
  If IsFormalProc(S) Then
  Begin
    { procedure formelle : arguments passes par valeur avec leur propre
      type, nombre libre }
    Head := -1;
    Tail := -1;
    N    := 0;
    If AtPunct('(') Then
    Begin
      ParserAdvance;
      If Not AtPunct(')') Then
        Repeat
          Inc(N);
          If N > MAX_PARAM Then
          Begin
            ErrorAt(CurToken.Line, CurToken.Col,
                    'trop d''arguments (max ' + ItoS(MAX_PARAM) + ')');
            Exit;
          End;
          Line0 := CurToken.Line;
          Col0  := CurToken.Col;
          Arg := ParseExpr;
          If Arg < 0 Then
            Bad := True
          Else
          Begin
            Item := ExprNew(EX_LIST, ExprTab[Arg].Typ, Line0, Col0);
            ExprTab[Item].L      := Arg;
            ExprTab[Item].IntVal := Ord(AC_VALUE);
            ExprTab[Item].Conv   := CV_NONE;
            If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
            Tail := Item;
          End;
          If AtPunct(',') Then
            ParserAdvance
          Else
            Break;
        Until False;
      ExpectPunct(')');
    End;
    If Bad Then Exit;
    Inc(CallCount);
    Node := ExprNew(EX_CALL, SymTab[S].ElemType, Tok.Line, Tok.Col);
    ExprTab[Node].Sym    := S;
    ExprTab[Node].L      := Head;
    ExprTab[Node].IntVal := N;
    ParseCall := Node;
    Exit;
  End;
  Head := -1;
  Tail := -1;
  N    := 0;
  Bad  := False;
  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If Not AtPunct(')') Then
      Repeat
        Inc(N);
        If N <= Expected Then
        Begin
          If ParseCallArg(SymTab[S].ParamSym[N], SymTab[S].Name,
                          Item) Then
          Begin
            If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
            Tail := Item;
          End
          Else
            Bad := True;
        End
        Else
        Begin
          If N = Expected + 1 Then
            ErrorAt(CurToken.Line, CurToken.Col, 'trop d''arguments ' +
                    'pour ' + SymTab[S].Name + ' (' + ItoS(Expected) +
                    ' attendu(s))');
          Bad := True;
          If ParseExpr < 0 Then ;
        End;
        If AtPunct(',') Then
          ParserAdvance
        Else
          Break;
      Until False;
    ExpectPunct(')');
  End;
  If (N < Expected) Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, 'appel de ' + Tok.Val + ': ' + ItoS(N) +
            ' argument(s) au lieu de ' + ItoS(Expected));
    Bad := True;
  End;
  If Bad Then Exit;
  Inc(CallCount);
  If SymTab[S].Kind = SK_FUNC Then
    Node := ExprNew(EX_CALL, SymTab[S].TypeIdx, Tok.Line, Tok.Col)
  Else
    Node := ExprNew(EX_CALL, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
  ExprTab[Node].Sym    := S;
  ExprTab[Node].L      := Head;
  ExprTab[Node].IntVal := N;
  ParseCall := Node;
End;


{ ---- Fonctions standard et entrees/sorties : noms ----------------- }

Function IntrinsicName(I : TIntrinsic) : TString;
Begin
  Case I Of
    IN_ABS    : IntrinsicName := 'abs';
    IN_SIGN   : IntrinsicName := 'sign';
    IN_ENTIER : IntrinsicName := 'entier';
    IN_SQRT   : IntrinsicName := 'sqrt';
    IN_SIN    : IntrinsicName := 'sin';
    IN_COS    : IntrinsicName := 'cos';
    IN_ARCTAN : IntrinsicName := 'arctan';
    IN_LN     : IntrinsicName := 'ln';
    IN_EXP    : IntrinsicName := 'exp';
  Else
    IntrinsicName := '?';
  End;
End;

{ Fonction standard designee par un nom (IN_NONE si ce n'en est pas
  une) ; une procedure du programme de meme nom reste prioritaire. }
Function FindIntrinsic(Const Name : TString) : TIntrinsic;
Var
  I : TIntrinsic;
  K : TString;
Begin
  K := StrLower(Name);
  FindIntrinsic := IN_NONE;
  For I := IN_ABS To IN_EXP Do
    If IntrinsicName(I) = K Then
    Begin
      FindIntrinsic := I;
      Exit;
    End;
End;

Function IoName(O : TIoOp) : TString;
Begin
  Case O Of
    IO_OUTSTRING  : IoName := 'outstring';
    IO_OUTINTEGER : IoName := 'outinteger';
    IO_OUTREAL    : IoName := 'outreal';
    IO_OUTBOOLEAN : IoName := 'outboolean';
    IO_NEWLINE    : IoName := 'newline';
    IO_PRINT      : IoName := 'print';
    IO_ININTEGER  : IoName := 'ininteger';
    IO_INREAL     : IoName := 'inreal';
    IO_INBOOLEAN  : IoName := 'inboolean';
    IO_SYSACT     : IoName := 'sysact';
  Else
    IoName := '?';
  End;
End;

{ Procedure d'entree/sortie designee par un nom (IO_NONE sinon) ; une
  procedure du programme de meme nom reste prioritaire. }
Function FindIo(Const Name : TString) : TIoOp;
Var
  O : TIoOp;
  K : TString;
Begin
  K := StrLower(Name);
  FindIo := IO_NONE;
  For O := IO_OUTSTRING To IO_SYSACT Do
    If IoName(O) = K Then
    Begin
      FindIo := O;
      Exit;
    End;
End;

{ Racine carree entiere (plancher) : non utilisee, sqrt est real }

{ nom(arg) : fonction standard I, Tok = le nom (rapport, 3.2.4).
  abs suit le type de son argument ; sign et entier donnent un integer
  (entier = plus grand entier <= x) ; sqrt, sin, cos, arctan, ln et exp
  donnent un real (x87). Un appel dont l'argument est une constante est
  calcule a la compilation. }
Function ParseIntrinsic(Const Tok : TToken; I : TIntrinsic) : Integer;
Var
  Arg, Res, Target : Integer;
  Node, Item       : Integer;
  Conv             : TConv;
  D1, RV           : Double;
  IV, I1           : LongInt;
  Err              : TString;
Begin
  ParseIntrinsic := -1;
  If Not AtPunct('(') Then
  Begin
    ParseError('''('' attendu apres ' + Tok.Val);
    Exit;
  End;
  ParserAdvance;
  Arg := ParseExpr;
  If AtPunct(',') Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, Tok.Val + ': 1 argument attendu');
    While Not (AtPunct(')') Or AtStmtEnd) Do ParserAdvance;
    If AtPunct(')') Then ParserAdvance;
    Exit;
  End;
  ExpectPunct(')');
  If Arg < 0 Then Exit;
  If Not TypeIsArith(ExprTab[Arg].Typ) Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, Tok.Val + ': argument numerique ' +
            'attendu (type: ' + TypeName(ExprTab[Arg].Typ) + ')');
    Exit;
  End;

  { type du resultat }
  Case I Of
    IN_ABS    : Res := TypeArith(ExprTab[Arg].Typ, ExprTab[Arg].Typ);
    IN_SIGN,
    IN_ENTIER : Res := TY_IDX_INTEGER;
  Else
    Res := TY_IDX_REAL;
  End;

  { repliement : l'argument est une constante }
  If ExprIsNumConst(Arg) Then
  Begin
    Err := '';
    IV  := 0;
    RV  := 0;
    D1  := ExprNumReal(Arg);
    I1  := ExprTab[Arg].IntVal;
    Case I Of
      IN_ABS:
        If Res = TY_IDX_REAL Then RV := Abs(D1) Else IV := Abs(I1);
      IN_SIGN:
        If D1 > 0 Then IV := 1 Else If D1 < 0 Then IV := -1 Else IV := 0;
      IN_ENTIER:
        If ExprTab[Arg].Kind = EX_REAL Then
        Begin
          If Abs(D1) >= 2147483647.0 Then
            Err := 'entier: valeur hors de l''intervalle integer'
          Else
          Begin
            RV := Int(D1);
            If D1 < RV Then RV := RV - 1;
            IV := Trunc(RV);
          End;
        End
        Else
          IV := I1;
      IN_SQRT:
        If D1 < 0 Then Err := 'sqrt: argument negatif' Else RV := Sqrt(D1);
      IN_SIN:    RV := Sin(D1);
      IN_COS:    RV := Cos(D1);
      IN_ARCTAN: RV := ArcTan(D1);
      IN_LN:
        If D1 <= 0 Then Err := 'ln: argument non positif'
        Else RV := Ln(D1);
      IN_EXP:
        If D1 > 700 Then Err := 'exp: debordement'
        Else RV := Exp(D1);
    End;
    If (Err = '') And (Res = TY_IDX_REAL) And RealBad(RV) Then
      Err := Tok.Val + ': debordement reel';
    If Err <> '' Then
    Begin
      ErrorAt(Tok.Line, Tok.Col, Err);
      Exit;
    End;
    Node := Arg;
    ExprTab[Node].Line := Tok.Line;
    ExprTab[Node].Col  := Tok.Col;
    If Res = TY_IDX_REAL Then
    Begin
      ExprTab[Node].Kind    := EX_REAL;
      ExprTab[Node].Typ     := TY_IDX_REAL;
      ExprTab[Node].RealVal := RV;
    End
    Else
    Begin
      ExprTab[Node].Kind   := EX_INT;
      ExprTab[Node].Typ    := TY_IDX_INTEGER;
      ExprTab[Node].IntVal := IV;
    End;
    Inc(FoldCount);
    ParseIntrinsic := Node;
    Exit;
  End;

  { entier d'un integer : identite }
  If (I = IN_ENTIER) And (ExprTab[Arg].Typ = TY_IDX_INTEGER) Then
  Begin
    ParseIntrinsic := Arg;
    Exit;
  End;

  { noeud d'appel : l'argument est converti vers le type de calcul
    (real pour les fonctions transcendantes) }
  If I In [IN_SIN, IN_COS, IN_ARCTAN, IN_LN, IN_EXP, IN_SQRT] Then
    Target := TY_IDX_REAL
  Else If ExprTab[Arg].Typ = TY_IDX_REAL Then
    Target := TY_IDX_REAL
  Else
    Target := TY_IDX_INTEGER;
  Conv := TypeConversion(ExprTab[Arg].Typ, Target);
  Item := ExprNew(EX_LIST, Target, Tok.Line, Tok.Col);
  ExprTab[Item].L    := Arg;
  ExprTab[Item].Conv := Conv;
  Node := ExprNew(EX_INTRIN, Res, Tok.Line, Tok.Col);
  ExprTab[Node].IntVal := Ord(I);
  ExprTab[Node].L      := Item;
  Inc(IntrinCount);
  ParseIntrinsic := Node;
End;

{ Expression primaire : constante, chaine, variable, element de tableau,
  appel de fonction ou expression entre parentheses }
Function ParsePrimary : Integer;
Var
  N, S : Integer;
  Tok  : TToken;
Begin
  ParsePrimary := -1;
  Tok := CurToken;
  Case Tok.Kind Of
    TK_INTEGER:
      Begin
        ParsePrimary := ExprMakeInt(Tok.IntVal, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_REAL:
      Begin
        ParsePrimary := ExprMakeReal(Tok.RealVal, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_STRING:
      Begin
        ParsePrimary := ExprMakeStr(Tok.Val, Tok.Line, Tok.Col);
        ParserAdvance;
      End;
    TK_KEYWORD:
      If (Tok.Val = 'true') Or (Tok.Val = 'false') Then
      Begin
        ParsePrimary := ExprMakeBool(Tok.Val = 'true', Tok.Line, Tok.Col);
        ParserAdvance;
      End
      Else
        ParseError('expression attendue');
    TK_PUNCT:
      If Tok.Val = '(' Then
      Begin
        ParserAdvance;
        N := ParseExpr;
        If AtPunct(')') Then
          ParserAdvance
        Else
          ParseError(''')'' attendu');
        ParsePrimary := N;
      End
      Else
        ParseError('expression attendue');
    TK_IDENT:
      Begin
        ParserAdvance;
        S := SymFind(Tok.Val);
        If AtPunct('[') Then
        Begin
          If S < 0 Then
            ErrorAt(Tok.Line, Tok.Col, 'tableau non declare: ' + Tok.Val)
          Else If Not SymIsArrayLike(S) Then
            ErrorAt(Tok.Line, Tok.Col, 'ce n''est pas un tableau: ' +
                    Tok.Val)
          Else
            ParsePrimary := ParseIndexed(Tok, S);
          Exit;
        End;
        { procedure typee : appel (le nom de la fonction en cours suivi
          de := est une cible, pas un appel) }
        If (S >= 0) And ((SymTab[S].Kind = SK_FUNC) Or IsFormalProc(S)) And
           Not ((S = SymCurProc) And AtOp(':=')) Then
        Begin
          ParsePrimary := ParseCall(Tok, S);
          Exit;
        End;
        If (S >= 0) And (SymTab[S].Kind = SK_PROC) And
           (S = SymCurProc) And AtOp(':=') Then
        Begin
          { extension : valeur affectee au nom d'une procedure sans type
            (test_lex.a60) : rangee dans une cellule, jamais utilisee }
          WarnAt(Tok.Line, Tok.Col, 'valeur affectee a une procedure ' +
                 'sans type: ' + Tok.Val + ' (ignoree)');
          N := ExprMakeVar(S, Tok.Line, Tok.Col);
          ExprTab[N].Typ := TY_IDX_INTEGER;
          ParsePrimary := N;
          Exit;
        End;
        If (S >= 0) And (SymTab[S].Kind = SK_PROC) Then
        Begin
          ErrorAt(Tok.Line, Tok.Col, 'procedure sans valeur dans une ' +
                  'expression: ' + Tok.Val);
          Exit;
        End;
        If AtPunct('(') Then
        Begin
          If S >= 0 Then
            ErrorAt(Tok.Line, Tok.Col, 'ce n''est pas une procedure: ' +
                    Tok.Val)
          Else If FindIntrinsic(Tok.Val) <> IN_NONE Then
            ParsePrimary := ParseIntrinsic(Tok, FindIntrinsic(Tok.Val))
          Else If FindIo(Tok.Val) <> IO_NONE Then
            ErrorAt(Tok.Line, Tok.Col, Tok.Val + ' est une procedure ' +
                    'sans valeur')
          Else
            ErrorAt(Tok.Line, Tok.Col, 'procedure ou fonction ' +
                    'inconnue: ' + Tok.Val);
          Exit;
        End;
        If S < 0 Then
        Begin
          S := SymImplicit(Tok.Val, Tok.Line, Tok.Col);
          DataDeclareSym(S);
        End;
        If SymIsArrayLike(S) Then
          ErrorAt(Tok.Line, Tok.Col, 'indice attendu pour le tableau ' +
                  Tok.Val)
        Else If SymTab[S].Kind In [SK_VAR, SK_OWN, SK_PARAM_VALUE,
                              SK_PARAM_NAME] Then
          ParsePrimary := ExprMakeVar(S, Tok.Line, Tok.Col)
        Else If (SymTab[S].Kind = SK_FUNC) And (S = SymCurProc) And
                AtOp(':=') Then
          ParsePrimary := ExprMakeVar(S, Tok.Line, Tok.Col)
        Else
          ErrorAt(Tok.Line, Tok.Col,
                  'variable attendue: ' + Tok.Val + ' (' +
                  SymKindName(SymTab[S].Kind) + ')');
      End;
  Else
    ParseError('expression attendue');
  End;
End;

{ ---- Expressions arithmetiques : analyse -------------------------
  Grammaire du Revised Report (3.3.1), avec [x] optionnel et x...
  repete :
    expression arithmetique simple = [signe] terme [(+|-) terme]...
    terme   = facteur [(multiplication, division, div) facteur]...
    facteur = primaire [^ primaire]...       (associatif a gauche)
  Un signe en tete s'applique a tout le premier terme : -a div b vaut
  -(a div b). ** est un synonyme de ^. ------------------------------ }

{ Facteur : primaire suivi de ^ primaire repetes ; l'exposant peut
  etre signe }
Function ParseFactor : Integer;
Var
  L, R, Sg   : Integer;
  Line, Col  : Integer;
  Neg        : Boolean;
Begin
  L := ParsePrimary;
  While AtOp('^') Do
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    Neg := False;
    If AtOp('-') Or AtOp('+') Then
    Begin
      Neg := AtOp('-');
      ParserAdvance;
    End;
    R := ParsePrimary;
    If Neg Then R := ExprMakeUnary('-', R, Line, Col);
    L := ExprMakeBinary('^', L, R, Line, Col);
  End;
  ParseFactor := L;
End;

Function ParseTerm : Integer;
Var
  L, R      : Integer;
  Op        : TString;
  Line, Col : Integer;
Begin
  L := ParseFactor;
  While AtOp('*') Or AtOp('/') Or AtKw('div') Do
  Begin
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseFactor;
    L := ExprMakeBinary(Op, L, R, Line, Col);
  End;
  ParseTerm := L;
End;

{ Expression arithmetique simple }
Function ParseArith : Integer;
Var
  L, R      : Integer;
  Op        : TString;
  Line, Col : Integer;
Begin
  If AtOp('+') Or AtOp('-') Then
  Begin
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    L := ExprMakeUnary(Op, ParseTerm, Line, Col);
  End
  Else
    L := ParseTerm;
  While AtOp('+') Or AtOp('-') Do
  Begin
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseTerm;
    L := ExprMakeBinary(Op, L, R, Line, Col);
  End;
  ParseArith := L;
End;

{ ---- Expressions booleennes et conditionnelles (TODO 11) ---------
  Grammaire du Revised Report (3.4.1) :
    relation          = arithmetique relationnel arithmetique
    secondaire        = [not] relation ou primaire
    facteur booleen   = secondaire [and secondaire]...
    terme booleen     = facteur [or facteur]...
    implication       = terme [impl terme]...
    booleen simple    = implication [equiv implication]...
    expression        = booleen simple, ou
                        if condition then simple else expression
  Priorites : not > and > or > impl > equiv. Les relationnels se
  notent = # != <> < <= > >=. ----------------------------------------- }

Function ParseRelation : Integer;
Var
  L, R      : Integer;
  Op        : TString;
  Line, Col : Integer;
Begin
  L := ParseArith;
  If AtOp('=') Or AtOp('#') Or AtOp('<') Or AtOp('<=') Or AtOp('>') Or
     AtOp('>=') Then
  Begin
    Op   := CurToken.Val;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseArith;
    L := ExprMakeBinary(Op, L, R, Line, Col);
    If AtOp('=') Or AtOp('#') Or AtOp('<') Or AtOp('<=') Or AtOp('>') Or
       AtOp('>=') Then
    Begin
      ErrorAt(CurToken.Line, CurToken.Col, 'comparaison chainee non ' +
              'supportee: utiliser and entre les comparaisons');
      ParserAdvance;
      R := ParseArith;
      L := -1;
    End;
  End;
  ParseRelation := L;
End;

{ not s'applique a une relation ou a un primaire }
Function ParseSecondary : Integer;
Var
  Line, Col : Integer;
Begin
  If AtKw('not') Then
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    ParseSecondary := ExprMakeUnary('not', ParseSecondary, Line, Col);
  End
  Else
    ParseSecondary := ParseRelation;
End;

Function ParseBoolFactor : Integer;
Var
  L, R      : Integer;
  Line, Col : Integer;
Begin
  L := ParseSecondary;
  While AtKw('and') Do
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseSecondary;
    L := ExprMakeBinary('and', L, R, Line, Col);
  End;
  ParseBoolFactor := L;
End;

Function ParseBoolTerm : Integer;
Var
  L, R      : Integer;
  Line, Col : Integer;
Begin
  L := ParseBoolFactor;
  While AtKw('or') Do
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseBoolFactor;
    L := ExprMakeBinary('or', L, R, Line, Col);
  End;
  ParseBoolTerm := L;
End;

Function ParseImplication : Integer;
Var
  L, R      : Integer;
  Line, Col : Integer;
Begin
  L := ParseBoolTerm;
  While AtKw('impl') Do
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseBoolTerm;
    L := ExprMakeBinary('impl', L, R, Line, Col);
  End;
  ParseImplication := L;
End;

{ Expression booleenne simple (sans if au sommet) }
Function ParseSimpleExpr : Integer;
Var
  L, R      : Integer;
  Line, Col : Integer;
Begin
  L := ParseImplication;
  While AtKw('equiv') Do
  Begin
    Line := CurToken.Line;
    Col  := CurToken.Col;
    ParserAdvance;
    R := ParseImplication;
    L := ExprMakeBinary('equiv', L, R, Line, Col);
  End;
  ParseSimpleExpr := L;
End;

{ Condition de if / while / expression conditionnelle : Boolean ou
  entier (vrai si different de zero, avec avertissement). -1 si erreur. }
Function ParseCondition : Integer;
Var
  N         : Integer;
  Line, Col : Integer;
Begin
  Line := CurToken.Line;
  Col  := CurToken.Col;
  N := ParseExpr;
  If (N >= 0) And (Not TypeIsCondition(ExprTab[N].Typ)) Then
  Begin
    ErrorAt(Line, Col, 'condition booleenne attendue (type: ' +
            TypeName(ExprTab[N].Typ) + ')');
    N := -1;
  End
  Else If N >= 0 Then
    ExprNoteCond(N, Line, Col);
  ParseCondition := N;
End;

{ if condition then expression simple else expression
  (le mot if est le token courant) }
Function ParseCondExpr : Integer;
Var
  C, T, E   : Integer;
  Line, Col : Integer;
Begin
  Line := CurToken.Line;
  Col  := CurToken.Col;
  ParserAdvance;                          { if }
  C := ParseCondition;
  If AtKw('then') Then
    ParserAdvance
  Else
    ParseError('''then'' attendu');
  T := ParseSimpleExpr;
  If AtKw('else') Then
    ParserAdvance
  Else
  Begin
    ParseError('''else'' attendu dans une expression conditionnelle');
    ParseCondExpr := -1;
    Exit;
  End;
  E := ParseExpr;
  ParseCondExpr := ExprMakeCond(C, T, E, Line, Col);
End;

{ Expression : booleenne simple ou conditionnelle }
Function ParseExpr : Integer;
Begin
  If AtKw('if') Then
    ParseExpr := ParseCondExpr
  Else
    ParseExpr := ParseSimpleExpr;
End;

{ Mode debug -d : arbre d'une expression }
Procedure ExprDump(N, Depth : Integer);
Var
  Pad  : TString;
Begin
  If N < 0 Then Exit;
  Pad := '';
  While Length(Pad) < 2 * Depth + 2 Do
    Pad := Pad + ' ';
  Write(Pad);
  Case ExprTab[N].Kind Of
    EX_INT    : WriteLn('int ', ExprTab[N].IntVal);
    EX_REAL   : WriteLn('real ', ExprTab[N].RealVal:0:6);
    EX_BOOL   : If ExprTab[N].IntVal <> 0 Then
                  WriteLn('bool true')
                Else
                  WriteLn('bool false');
    EX_STR    : WriteLn('str "', ExprStrTab[ExprTab[N].StrIdx], '"');
    EX_VAR    : WriteLn('var ', SymTab[ExprTab[N].Sym].Name, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_UNARY  : WriteLn('unary ', ExprTab[N].Op, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_BINARY : WriteLn('binary ', ExprTab[N].Op, ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_COND   : WriteLn('cond : ', TypeName(ExprTab[N].Typ));
    EX_ASSIGN : WriteLn('assign := ', ConvName(ExprTab[N].Conv), ' : ',
                        TypeName(ExprTab[N].Typ));
    EX_INDEX  : Begin
                  Write('index ', SymTab[ExprTab[N].Sym].Name, '[',
                        ExprTab[N].IntVal, '] : ',
                        TypeName(ExprTab[N].Typ));
                  If ExprTab[N].Flag Then
                    WriteLn(' (controle de bornes)')
                  Else
                    WriteLn;
                End;
    EX_LIST   : WriteLn('list');
    EX_LABEL  : WriteLn('label ', SymTab[ExprTab[N].Sym].Name);
    EX_SWITCHREF : WriteLn('switch ', SymTab[ExprTab[N].Sym].Name, '[]');
    EX_CALL   : WriteLn('call ', SymTab[ExprTab[N].Sym].Name, '(',
                        ExprTab[N].IntVal, ' argument(s)) : ',
                        TypeName(ExprTab[N].Typ));
    EX_INTRIN : WriteLn('intrinsic ',
                        IntrinsicName(TIntrinsic(ExprTab[N].IntVal)),
                        ' : ', TypeName(ExprTab[N].Typ));
    EX_IO     : WriteLn('io ', IoName(TIoOp(ExprTab[N].IntVal)));
  End;
  ExprDump(ExprTab[N].L, Depth + 1);
  ExprDump(ExprTab[N].R, Depth + 1);
End;

{ ---- Generation du code : operandes et variables ------------------ }

Procedure CallRT(Const Name : TString);
Begin
  Emit1(OP_CALL, OpLabel(Intern(A60_RT_PFX + Name)));
End;

Procedure LoadImm(R : TReg; V : LongInt);
Begin
  If V = 0 Then
    Emit(OP_XOR, OpReg(R), OpReg(R))
  Else
    Emit(OP_MOV, OpReg(R), OpImm(V));
End;

{ ST(0) -> pile machine (SUB ESP,8 ; FSTP QWORD [ESP]) }
Procedure SpillReal;
Begin
  Emit(OP_SUB, OpReg(R_ESP), OpImm(8));
  Emit1(OP_FSTP, OpMem(R_ESP, 0, 8));
End;

Function IsRealT(T : Integer) : Boolean;
Begin
  IsRealT := (T = TY_IDX_REAL);
End;

Function ValSize(T : Integer) : Byte;
Begin
  If T = TY_IDX_REAL Then ValSize := 8 Else ValSize := 4;
End;

{ Registre contenant le cadre de la procedure de niveau Level : EBP
  pour le niveau courant, sinon ECX apres remontee des liens
  statiques ([cadre+8]). }
Function GenFrameReg(Level : Integer) : TReg;
Var
  K : Integer;
Begin
  K := CurLevel - Level;
  If K <= 0 Then
  Begin
    GenFrameReg := R_EBP;
    Exit;
  End;
  Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EBP, ABI_PARAM_BASE, 4));
  Dec(K);
  While K > 0 Do
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ECX, ABI_PARAM_BASE, 4));
    Dec(K);
  End;
  GenFrameReg := R_ECX;
End;

{ Cellule d'une variable scalaire (globale, locale ou parametre par
  valeur) ; resultat d'une fonction pour SK_FUNC. }
Function SymCell(S : Integer; Extra : LongInt; Size : Byte) : TOperand;
Var
  F : TReg;
Begin
  If SymTab[S].Kind In [SK_FUNC, SK_PROC] Then
  Begin
    SymCell := OpMem(R_EBP, SymResultOfs + Extra, Size);
    Exit;
  End;
  If SymTab[S].Storage = SC_GLOBAL Then
    SymCell := OpMemSym(Intern(SymTab[S].Mangled), Extra, Size)
  Else
  Begin
    F := GenFrameReg(SymTab[S].Level);
    SymCell := OpMem(F, SymTab[S].Offset + Extra, Size);
  End;
End;

{ Acces a un parametre par nom : EAX := valeur (WantAddr = False) ou
  adresse de l'argument (WantAddr = True). Paire [mot0, mot1] : mot0 =
  thunk (0 = reference directe), mot1 = contexte ou adresse. Un
  thunk est appele avec EAX = contexte, ECX = 0 (valeur) ou 1 (adresse),
  et rend la valeur en EAX / ST(0) ou l'adresse en EAX. }
Procedure GenByName(S : Integer; WantAddr : Boolean);
Var
  F            : TReg;
  Off          : LongInt;
  Lref, Ldone  : Integer;
Begin
  F   := GenFrameReg(SymTab[S].Level);
  Off := SymTab[S].Offset;
  Lref  := NewLabel;
  Ldone := NewLabel;
  Emit(OP_MOV, OpReg(R_EDX), OpMem(F, Off, 4));
  Emit(OP_MOV, OpReg(R_EAX), OpMem(F, Off + 4, 4));
  Emit(OP_TEST, OpReg(R_EDX), OpReg(R_EDX));
  If WantAddr Then
    Emit1(OP_JE, OpLabel(Ldone))
  Else
    Emit1(OP_JE, OpLabel(Lref));
  If WantAddr Then
    Emit(OP_MOV, OpReg(R_ECX), OpImm(1))
  Else
    Emit(OP_XOR, OpReg(R_ECX), OpReg(R_ECX));
  Emit1(OP_CALL, OpReg(R_EDX));
  If Not WantAddr Then
  Begin
    Emit1(OP_JMP, OpLabel(Ldone));
    EmitLabel(Lref);
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_EAX));
    If IsRealT(SymTab[S].TypeIdx) Then
      Emit1(OP_FLD, OpMem(R_EDX, 0, 8))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EDX, 0, 4));
  End;
  EmitLabel(Ldone);
End;

{ Valeur d'une variable scalaire -> EAX ou ST(0) }
Procedure GenLoadVar(S : Integer);
Var
  T : Integer;
Begin
  T := SymTab[S].TypeIdx;
  If SymTab[S].Kind = SK_PARAM_NAME Then
    GenByName(S, False)
  Else If IsRealT(T) Then
    Emit1(OP_FLD, SymCell(S, 0, 8))
  Else
    Emit(OP_MOV, OpReg(R_EAX), SymCell(S, 0, 4));
End;

{ Adresse d'une variable scalaire -> EAX }
Procedure GenAddrVar(S : Integer);
Var
  O : TOperand;
Begin
  If SymTab[S].Kind = SK_PARAM_NAME Then
  Begin
    GenByName(S, True);
    Exit;
  End;
  O := SymCell(S, 0, 0);
  If O.Sym >= 0 Then
    Emit(OP_MOV, OpReg(R_EAX), OpOffset(O.Sym))
  Else
    Emit(OP_LEA, OpReg(R_EAX), O);
End;


Procedure GenExpr(N : Integer); Forward;
Procedure GenAssign(N : Integer; NeedValue : Boolean); Forward;

{ Conversion de la valeur courante (EAX ou ST(0)) du type From vers
  le type Dest }
Procedure GenConvert(From, Dest : Integer);
Begin
  If From = Dest Then Exit;
  If (Dest = TY_IDX_REAL) And
     ((From = TY_IDX_INTEGER) Or (From = TY_IDX_BOOLEAN)) Then
  Begin
    Emit1(OP_PUSH, OpReg(R_EAX));
    Emit1(OP_FILD, OpMem(R_ESP, 0, 4));
    Emit(OP_ADD, OpReg(R_ESP), OpImm(4));
  End
  Else If (Dest = TY_IDX_INTEGER) And (From = TY_IDX_REAL) Then
    CallRT('RTOI')
  Else If (Dest = TY_IDX_BOOLEAN) And (From = TY_IDX_INTEGER) Then
  Begin
    Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
    Emit1(OP_SETNE, OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
  End;
End;

Procedure GenExprAs(N, T : Integer);
Begin
  GenExpr(N);
  GenConvert(ExprTab[N].Typ, T);
End;

Function InvRel(Const Op : TString) : TString;
Begin
  If Op = '=' Then InvRel := '#'
  Else If Op = '#' Then InvRel := '='
  Else If Op = '<' Then InvRel := '>='
  Else If Op = '<=' Then InvRel := '>'
  Else If Op = '>' Then InvRel := '<='
  Else InvRel := '<';
End;

{ Saut selon Op ; entiers : drapeaux signes ; reels : apres
  FCOMP [ESP] (droite en ST0, gauche en memoire) et SAHF, la
  relation est inversee et lue avec les drapeaux non signes. }
Function JccFor(Const Op : TString; IsReal : Boolean) : TOp;
Begin
  If Op = '=' Then JccFor := OP_JE
  Else If Op = '#' Then JccFor := OP_JNE
  Else If IsReal Then
  Begin
    If Op = '<' Then JccFor := OP_JA
    Else If Op = '<=' Then JccFor := OP_JAE
    Else If Op = '>' Then JccFor := OP_JB
    Else JccFor := OP_JBE;
  End
  Else
  Begin
    If Op = '<' Then JccFor := OP_JL
    Else If Op = '<=' Then JccFor := OP_JLE
    Else If Op = '>' Then JccFor := OP_JG
    Else JccFor := OP_JGE;
  End;
End;

Function SetFor(Const Op : TString; IsReal : Boolean) : TOp;
Begin
  If Op = '=' Then SetFor := OP_SETE
  Else If Op = '#' Then SetFor := OP_SETNE
  Else If IsReal Then
  Begin
    If Op = '<' Then SetFor := OP_SETA
    Else If Op = '<=' Then SetFor := OP_SETAE
    Else If Op = '>' Then SetFor := OP_SETB
    Else SetFor := OP_SETBE;
  End
  Else
  Begin
    If Op = '<' Then SetFor := OP_SETL
    Else If Op = '<=' Then SetFor := OP_SETLE
    Else If Op = '>' Then SetFor := OP_SETG
    Else SetFor := OP_SETGE;
  End;
End;

{ Evalue les deux operandes d'une relation et positionne les drapeaux.
  Retourne True si la comparaison est reelle (mapping non signe). }
Function GenCompareFlags(N : Integer) : Boolean;
Var
  L, R, Dom : Integer;
Begin
  L := ExprTab[N].L;
  R := ExprTab[N].R;
  Dom := TypeArith(ExprTab[L].Typ, ExprTab[R].Typ);
  If Dom = TY_IDX_REAL Then
  Begin
    GenExprAs(L, TY_IDX_REAL);
    SpillReal;
    GenExprAs(R, TY_IDX_REAL);
    Emit1(OP_FCOMP, OpMem(R_ESP, 0, 8));
    Emit1(OP_FNSTSW, OpReg(R_AX));
    Emit(OP_ADD, OpReg(R_ESP), OpImm(8));
    Emit0(OP_SAHF);
    GenCompareFlags := True;
  End
  Else
  Begin
    GenExprAs(L, TY_IDX_INTEGER);
    If ExprTab[R].Kind = EX_INT Then
      Emit(OP_CMP, OpReg(R_EAX), OpImm(ExprTab[R].IntVal))
    Else
    Begin
      Emit1(OP_PUSH, OpReg(R_EAX));
      GenExprAs(R, TY_IDX_INTEGER);
      Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
      Emit1(OP_POP, OpReg(R_EAX));
      Emit(OP_CMP, OpReg(R_EAX), OpReg(R_ECX));
    End;
    GenCompareFlags := False;
  End;
End;

{ Saute vers Lbl si la condition N est vraie (OnTrue) ou fausse.
  Les operateurs and / or / impl sont evalues en court-circuit. }
Procedure GenJump(N, Lbl : Integer; OnTrue : Boolean);
Var
  Skip   : Integer;
  Op     : TString;
  IsReal : Boolean;
Begin
  If ExprTab[N].Kind In [EX_BOOL, EX_INT] Then
  Begin
    If (ExprTab[N].IntVal <> 0) = OnTrue Then
      Emit1(OP_JMP, OpLabel(Lbl));
    Exit;
  End;
  If (ExprTab[N].Kind = EX_UNARY) And (ExprTab[N].Op = 'not') Then
  Begin
    GenJump(ExprTab[N].L, Lbl, Not OnTrue);
    Exit;
  End;
  If ExprTab[N].Kind = EX_BINARY Then
  Begin
    Op := ExprTab[N].Op;
    If OpIsRel(Op) Then
    Begin
      IsReal := GenCompareFlags(N);
      If Not OnTrue Then Op := InvRel(Op);
      Emit1(JccFor(Op, IsReal), OpLabel(Lbl));
      Exit;
    End;
    If (Op = 'and') Or (Op = 'or') Or (Op = 'impl') Then
    Begin
      If Op = 'impl' Then
      Begin
        { a impl b = (non a) ou b }
        If OnTrue Then
        Begin
          GenJump(ExprTab[N].L, Lbl, False);
          GenJump(ExprTab[N].R, Lbl, True);
        End
        Else
        Begin
          Skip := NewLabel;
          GenJump(ExprTab[N].L, Skip, False);
          GenJump(ExprTab[N].R, Lbl, False);
          EmitLabel(Skip);
        End;
        Exit;
      End;
      If (Op = 'and') = (Not OnTrue) Then
      Begin
        { and / faux  ou  or / vrai : l'un des deux suffit }
        GenJump(ExprTab[N].L, Lbl, OnTrue);
        GenJump(ExprTab[N].R, Lbl, OnTrue);
      End
      Else
      Begin
        Skip := NewLabel;
        GenJump(ExprTab[N].L, Skip, Not OnTrue);
        GenJump(ExprTab[N].R, Lbl, OnTrue);
        EmitLabel(Skip);
      End;
      Exit;
    End;
  End;
  GenExpr(N);
  Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
  If OnTrue Then
    Emit1(OP_JNE, OpLabel(Lbl))
  Else
    Emit1(OP_JE, OpLabel(Lbl));
End;

{ EAX := EAX op ECX pour + - * div ^ (entiers) }
Procedure GenIntOp(Const Op : TString; RightIsConst : Boolean);
Var
  Ok : Integer;
Begin
  If Op = '+' Then
    Emit(OP_ADD, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '-' Then
    Emit(OP_SUB, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '*' Then
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX))
  Else If Op = '^' Then
  Begin
    Emit(OP_MOV, OpReg(R_EDX), OpReg(R_ECX));
    CallRT('POW');
  End
  Else
  Begin
    { div : division par zero controlee si le diviseur varie }
    If Not RightIsConst Then
    Begin
      Ok := NewLabel;
      Emit(OP_TEST, OpReg(R_ECX), OpReg(R_ECX));
      Emit1(OP_JNE, OpLabel(Ok));
      CallRT('DIVZERO');
      EmitLabel(Ok);
    End;
    Emit0(OP_CDQ);
    Emit1(OP_IDIV, OpReg(R_ECX));
  End;
End;

{ Operateur binaire arithmetique. Les valeurs intermediaires sont
  rangees sur la pile machine (jamais en registre a travers un appel). }
Procedure GenBinary(N : Integer);
Var
  Op        : TString;
  L, R, T   : Integer;
  IsReal    : Boolean;
  Lf, Le    : Integer;
Begin
  Op := ExprTab[N].Op;
  L  := ExprTab[N].L;
  R  := ExprTab[N].R;
  T  := ExprTab[N].Typ;

  If OpIsRel(Op) Then
  Begin
    IsReal := GenCompareFlags(N);
    Emit1(SetFor(Op, IsReal), OpReg(R_AL));
    Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    Exit;
  End;

  If OpIsLogic(Op) Then
  Begin
    If Op = 'equiv' Then
    Begin
      GenExprAs(L, TY_IDX_BOOLEAN);
      Emit1(OP_PUSH, OpReg(R_EAX));
      GenExprAs(R, TY_IDX_BOOLEAN);
      Emit1(OP_POP, OpReg(R_ECX));
      Emit(OP_CMP, OpReg(R_ECX), OpReg(R_EAX));
      Emit1(OP_SETE, OpReg(R_AL));
      Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
    End
    Else
    Begin
      Lf := NewLabel;
      Le := NewLabel;
      GenJump(N, Lf, False);
      Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
      Emit1(OP_JMP, OpLabel(Le));
      EmitLabel(Lf);
      Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
      EmitLabel(Le);
    End;
    Exit;
  End;

  If T = TY_IDX_REAL Then
  Begin
    GenExprAs(L, TY_IDX_REAL);
    SpillReal;
    GenExprAs(R, TY_IDX_REAL);
    If Op = '^' Then
    Begin
      Emit1(OP_FLD, OpMem(R_ESP, 0, 8));       { ST0 = base, ST1 = exposant }
      CallRT('RPOW');
    End
    Else If Op = '+' Then
      Emit1(OP_FADD, OpMem(R_ESP, 0, 8))
    Else If Op = '*' Then
      Emit1(OP_FMUL, OpMem(R_ESP, 0, 8))
    Else If Op = '-' Then
      Emit1(OP_FSUBR, OpMem(R_ESP, 0, 8))
    Else
      Emit1(OP_FDIVR, OpMem(R_ESP, 0, 8));     { / }
    Emit(OP_ADD, OpReg(R_ESP), OpImm(8));
    Exit;
  End;

  { entiers }
  GenExprAs(L, TY_IDX_INTEGER);
  If (ExprTab[R].Kind = EX_INT) And ((Op = '+') Or (Op = '-')) Then
  Begin
    If Op = '+' Then
      Emit(OP_ADD, OpReg(R_EAX), OpImm(ExprTab[R].IntVal))
    Else
      Emit(OP_SUB, OpReg(R_EAX), OpImm(ExprTab[R].IntVal));
    Exit;
  End;
  If ExprTab[R].Kind = EX_INT Then
  Begin
    Emit(OP_MOV, OpReg(R_ECX), OpImm(ExprTab[R].IntVal));
    GenIntOp(Op, True);
    Exit;
  End;
  Emit1(OP_PUSH, OpReg(R_EAX));
  GenExprAs(R, TY_IDX_INTEGER);
  Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
  Emit1(OP_POP, OpReg(R_EAX));
  GenIntOp(Op, False);
End;

{ ---- Tableaux : adresse d'un element, declaration, liberation ----- }
{ ESI := adresse du descripteur du tableau S : declare (global ou
  local) ou parametre tableau (pointeur recu). Descripteur (DWORD) :
  [0] base, [1] nombre de dimensions, puis par dimension lo, hi,
  pas (en elements). }
Procedure GenDescToESI(S : Integer);
Var
  F : TReg;
Begin
  If SymTab[S].Kind = SK_ARRAY Then
  Begin
    If SymTab[S].Storage = SC_GLOBAL Then
      Emit(OP_MOV, OpReg(R_ESI), OpOffset(DescName(S)))
    Else
    Begin
      F := GenFrameReg(SymTab[S].Level);
      Emit(OP_LEA, OpReg(R_ESI), OpMem(F, SymTab[S].ArrDescOfs, 0));
    End;
  End
  Else
  Begin
    F := GenFrameReg(SymTab[S].Level);
    Emit(OP_MOV, OpReg(R_ESI), OpMem(F, SymTab[S].Offset, 4));
  End;
End;


{ Pas (en elements) de la dimension K d'un tableau a bornes connues }
Function KnownStride(S, K : Integer) : LongInt;
Var
  J       : Integer;
  Stride  : LongInt;
Begin
  Stride := 1;
  For J := K + 1 To SymTab[S].ArrDims Do
    Stride := Stride * (SymTab[S].ArrHi[J] - SymTab[S].ArrLo[J] + 1);
  KnownStride := Stride;
End;

{ Adresse d'un element de tableau -> EAX. Chaque indice est controle
  par _A60RT_CHKIDX (sauf constante verifiee a la compilation) ;
  indice lineaire = somme (i_k - lo_k) * pas_k. }
Procedure GenIndexAddr(N : Integer);
Var
  S, K, Dims, Item, E : Integer;
  Known, Chk          : Boolean;
  Off                 : LongInt;
Begin
  S    := ExprTab[N].Sym;
  Dims := ExprTab[N].IntVal;
  Known := (SymTab[S].Kind = SK_ARRAY) And (Not SymTab[S].ArrDynamic) And
           (SymTab[S].ArrDims = Dims);
  Item := ExprTab[N].L;
  K := 0;
  While Item >= 0 Do
  Begin
    Inc(K);
    E := ExprTab[Item].L;
    If K > 1 Then Emit1(OP_PUSH, OpReg(R_EAX));        { cumul partiel }
    GenExprAs(E, TY_IDX_INTEGER);
    Off := 8 + 12 * (K - 1);                           { lo ; hi = +4 }
    Chk := (Not Known) Or (ExprTab[E].Kind <> EX_INT);
    GenDescToESI(S);
    If Chk Then
    Begin
      If Known Then
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpImm(SymTab[S].ArrLo[K]));
        Emit(OP_MOV, OpReg(R_EDX), OpImm(SymTab[S].ArrHi[K]));
      End
      Else
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, Off, 4));
        Emit(OP_MOV, OpReg(R_EDX), OpMem(R_ESI, Off + 4, 4));
      End;
      CallRT('CHKIDX');
    End;
    If Known Then
    Begin
      If SymTab[S].ArrLo[K] <> 0 Then
        Emit(OP_SUB, OpReg(R_EAX), OpImm(SymTab[S].ArrLo[K]));
      If KnownStride(S, K) <> 1 Then
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpImm(KnownStride(S, K)));
        Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
      End;
    End
    Else
    Begin
      Emit(OP_SUB, OpReg(R_EAX), OpMem(R_ESI, Off, 4));
      Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, Off + 8, 4));
      Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
    End;
    If K > 1 Then
    Begin
      Emit1(OP_POP, OpReg(R_ECX));
      Emit(OP_ADD, OpReg(R_EAX), OpReg(R_ECX));
    End;
    Item := ExprTab[Item].R;
  End;
  GenDescToESI(S);
  Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ESI, 0, 4));
  Emit(OP_LEA, OpReg(R_EAX),
       OpMemIdx(-1, R_ECX, R_EAX, ValSize(ExprTab[N].Typ), 0, 0));
End;

{ Adresse d'une variable ou d'un element -> EAX }
Procedure GenAddrNode(E : Integer);
Begin
  If ExprTab[E].Kind = EX_INDEX Then
    GenIndexAddr(E)
  Else
    GenAddrVar(ExprTab[E].Sym);
End;

{ Declaration d'un tableau : remplit le descripteur a l'execution et,
  pour des bornes variables, alloue les donnees sur le tas. }
Procedure GenArrayDecl(S : Integer; Const NLo, NHi : Array Of Integer);
Var
  K, Dims, Es : Integer;
  Local       : Boolean;
  Base        : LongInt;

  Function Cell(Off : LongInt) : TOperand;
  Begin
    If Local Then
      Cell := OpMem(R_EBP, SymTab[S].ArrDescOfs + Off, 4)
    Else
      Cell := OpMemSym(DescName(S), Off, 4);
  End;

Begin
  Dims  := SymTab[S].ArrDims;
  Es    := TypeSizeof(SymTab[S].ElemType);
  Local := SymTab[S].Storage = SC_LOCAL;
  Emit(OP_MOV, Cell(4), OpImm(Dims));
  If Not SymTab[S].ArrDynamic Then
  Begin
    For K := 1 To Dims Do
    Begin
      Base := 8 + 12 * (K - 1);
      Emit(OP_MOV, Cell(Base), OpImm(SymTab[S].ArrLo[K]));
      Emit(OP_MOV, Cell(Base + 4), OpImm(SymTab[S].ArrHi[K]));
      Emit(OP_MOV, Cell(Base + 8), OpImm(KnownStride(S, K)));
    End;
    If Local Then
    Begin
      Emit(OP_LEA, OpReg(R_EAX),
           OpMem(R_EBP, SymTab[S].ArrDataOfs, 0));
      Emit(OP_MOV, Cell(0), OpReg(R_EAX));
    End
    Else
      Emit(OP_MOV, Cell(0), OpOffset(Intern(SymTab[S].Mangled)));
    Exit;
  End;
  { bornes a l'execution }
  For K := 1 To Dims Do
  Begin
    Base := 8 + 12 * (K - 1);
    If NLo[K - 1] >= 0 Then
      GenExprAs(NLo[K - 1], TY_IDX_INTEGER)
    Else
      LoadImm(R_EAX, SymTab[S].ArrLo[K]);
    Emit(OP_MOV, Cell(Base), OpReg(R_EAX));
    If NHi[K - 1] >= 0 Then
      GenExprAs(NHi[K - 1], TY_IDX_INTEGER)
    Else
      LoadImm(R_EAX, SymTab[S].ArrHi[K]);
    Emit(OP_MOV, Cell(Base + 4), OpReg(R_EAX));
  End;
  Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
  For K := Dims Downto 1 Do
  Begin
    Base := 8 + 12 * (K - 1);
    Emit(OP_MOV, Cell(Base + 8), OpReg(R_EAX));         { pas }
    Emit(OP_MOV, OpReg(R_ECX), Cell(Base + 4));
    Emit(OP_SUB, OpReg(R_ECX), Cell(Base));
    Emit1(OP_INC, OpReg(R_ECX));
    Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));          { elements }
  End;
  Emit(OP_MOV, OpReg(R_ECX), OpImm(Es));
  Emit(OP_IMUL, OpReg(R_EAX), OpReg(R_ECX));
  CallRT('ALLOC');
  Emit(OP_MOV, Cell(0), OpReg(R_EAX));
End;


{ Fin de bloc : libere la memoire d'un tableau a bornes variables
  (allouee sur le tas par GenArrayDecl) et remet son pointeur a zero }
Procedure GenFreeArray(S : Integer);
Var
  Skip  : Integer;
  Local : Boolean;
  Cell  : TOperand;
Begin
  Local := SymTab[S].Storage = SC_LOCAL;
  If Local Then
    Cell := OpMem(R_EBP, SymTab[S].ArrDescOfs, 4)
  Else
    Cell := OpMemSym(DescName(S), 0, 4);
  Skip := NewLabel;
  Emit(OP_MOV, OpReg(R_EAX), Cell);
  Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
  Emit1(OP_JE, OpLabel(Skip));
  CallRT('FREE');
  Emit(OP_MOV, Cell, OpImm(0));
  EmitLabel(Skip);
End;



{ Thunk d'un argument passe par nom : petit sous-programme appele avec
  EAX = contexte (EBP de l'appelant) et ECX = 0 (valeur) ou 1 (adresse
  de l'argument, thunk d'ecriture). Il evalue l'argument dans le cadre
  de l'appelant, a chaque utilisation du parametre. }
Procedure GenThunk(Item, Param : Integer; Cls : TArgClass);
Var
  Start, Lth, Laddr, E : Integer;
Begin
  Start := CodeCount;
  Lth   := Intern(ExprStrTab[ExprTab[Item].StrIdx]);
  E     := ExprTab[Item].L;
  EmitLabel(Lth);
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_EAX));
  Laddr := -1;
  If Cls = AC_THUNK_RW Then
  Begin
    Laddr := NewLabel;
    Emit(OP_TEST, OpReg(R_ECX), OpReg(R_ECX));
    Emit1(OP_JNE, OpLabel(Laddr));
  End;
  GenExprAs(E, SymTab[Param].TypeIdx);
  Emit1(OP_POP, OpReg(R_EBP));
  Emit0(OP_RET);
  If Cls = AC_THUNK_RW Then
  Begin
    EmitLabel(Laddr);
    GenAddrNode(E);
    Emit1(OP_POP, OpReg(R_EBP));
    Emit0(OP_RET);
  End;
  MoveToDeferred(Start);
End;

{ Lien statique a empiler pour appeler la procedure S (declaree au
  niveau SymTab[S].Level) : cadre de ce niveau, ou 0 au niveau 0 ->
  valeur dans EAX }
Procedure GenStaticLink(S : Integer);
Var
  Delta : Integer;
Begin
  If SymTab[S].Level >= 1 Then
  Begin
    Delta := CurLevel - SymTab[S].Level;
    Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EBP));
    While Delta > 0 Do
    Begin
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, ABI_PARAM_BASE, 4));
      Dec(Delta);
    End;
  End
  Else
    Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
End;

{ Appel : arguments de droite a gauche, lien statique, CALL ; la
  procedure nettoie la pile (RET n). Resultat : EAX ou ST(0). Une
  procedure formelle est appelee par la paire (adresse, lien) de son
  parametre ; ses arguments sont passes par valeur. }
Procedure GenCall(N : Integer);
Var
  S, K, Item, PS, PT, E    : Integer;
  Items                    : Array[1..MAX_PARAM] Of Integer;
  Cls                      : TArgClass;
  F                        : TReg;
Begin
  S := ExprTab[N].Sym;
  Item := ExprTab[N].L;
  K := 0;
  While Item >= 0 Do
  Begin
    Inc(K);
    Items[K] := Item;
    Item := ExprTab[Item].R;
  End;
  While K >= 1 Do
  Begin
    Item := Items[K];
    E    := ExprTab[Item].L;
    Cls  := TArgClass(ExprTab[Item].IntVal);
    If IsFormalProc(S) Then
    Begin
      PS := -1;
      PT := ExprTab[E].Typ;                { par valeur, type propre }
    End
    Else
    Begin
      PS := SymTab[S].ParamSym[K];
      PT := SymTab[PS].TypeIdx;
    End;
    Case Cls Of
      AC_VALUE:
        Begin
          GenExprAs(E, PT);
          If IsRealT(PT) Then
            SpillReal
          Else
            Emit1(OP_PUSH, OpReg(R_EAX));
        End;
      AC_ARRAY:
        Begin
          GenDescToESI(ExprTab[E].Sym);
          Emit1(OP_PUSH, OpReg(R_ESI));
        End;
      AC_CONST:
        Begin
          If IsRealT(SymTab[PS].TypeIdx) Then
            Emit(OP_MOV, OpReg(R_EDX),
                 OpOffset(DataReal(ExprTab[E].RealVal)))
          Else
            Emit(OP_MOV, OpReg(R_EDX),
                 OpOffset(DataInt(ExprTab[E].IntVal)));
          Emit1(OP_PUSH, OpReg(R_EDX));
          Emit1(OP_PUSH, OpImm(0));
        End;
      AC_REF:
        Begin
          GenAddrNode(E);
          Emit1(OP_PUSH, OpReg(R_EAX));
          Emit1(OP_PUSH, OpImm(0));
        End;
      AC_FORWARD:
        Begin
          F := GenFrameReg(SymTab[ExprTab[E].Sym].Level);
          Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset + 4, 4));
          Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset, 4));
        End;
      AC_THUNK, AC_THUNK_RW:
        Begin
          GenThunk(Item, PS, Cls);
          Emit1(OP_PUSH, OpReg(R_EBP));
          { passer par un registre : ML.PAS ne dimensionne pas bien
            PUSH OFFSET etiquette_en_avant a la passe 1 }
          Emit(OP_MOV, OpReg(R_EDX), OpOffset(Intern(
               ExprStrTab[ExprTab[Item].StrIdx])));
          Emit1(OP_PUSH, OpReg(R_EDX));
        End;
      AC_PROC:
        Begin
          { paire (adresse, lien) : mot 0 = adresse, mot 1 = lien }
          E := ExprTab[Item].L;
          If IsFormalProc(ExprTab[E].Sym) Then
          Begin
            F := GenFrameReg(SymTab[ExprTab[E].Sym].Level);
            Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset + 4, 4));
            Emit1(OP_PUSH, OpMem(F, SymTab[ExprTab[E].Sym].Offset, 4));
          End
          Else
          Begin
            GenStaticLink(ExprTab[E].Sym);
            Emit1(OP_PUSH, OpReg(R_EAX));
            Emit(OP_MOV, OpReg(R_EDX),
                 OpOffset(Intern(SymTab[ExprTab[E].Sym].Mangled)));
            Emit1(OP_PUSH, OpReg(R_EDX));
          End;
        End;
    Else
      FatalError('erreur interne: classe d''argument inconnue');
    End;
    Dec(K);
  End;
  If IsFormalProc(S) Then
  Begin
    F := GenFrameReg(SymTab[S].Level);
    Emit1(OP_PUSH, OpMem(F, SymTab[S].Offset + 4, 4));     { lien }
    Emit(OP_MOV, OpReg(R_EDX), OpMem(F, SymTab[S].Offset, 4));
    Emit1(OP_CALL, OpReg(R_EDX));
    Exit;
  End;
  { lien statique : cadre de la procedure qui contient la declaration }
  GenStaticLink(S);
  Emit1(OP_PUSH, OpReg(R_EAX));
  Emit1(OP_CALL, OpLabel(Intern(SymTab[S].Mangled)));
End;

{ Fonction standard : valeur dans EAX (integer) ou ST(0) (real) }
Procedure GenIntrinsic(N : Integer);
Var
  I  : TIntrinsic;
  A1 : Integer;
  T  : Integer;
Begin
  I  := TIntrinsic(ExprTab[N].IntVal);
  A1 := ExprTab[N].L;
  T  := ExprTab[N].Typ;
  Case I Of
    IN_ABS:
      Begin
        GenExprAs(ExprTab[A1].L, ExprTab[A1].Typ);
        If T = TY_IDX_REAL Then
          Emit0(OP_FABS)
        Else
        Begin
          Emit0(OP_CDQ);
          Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EDX));
          Emit(OP_SUB, OpReg(R_EAX), OpReg(R_EDX));
        End;
      End;
    IN_SIGN:
      Begin
        GenExprAs(ExprTab[A1].L, ExprTab[A1].Typ);
        If ExprTab[A1].Typ = TY_IDX_REAL Then
          CallRT('RSIGN')
        Else
        Begin
          Emit(OP_MOV, OpReg(R_ECX), OpReg(R_EAX));
          Emit0(OP_CDQ);
          Emit1(OP_NEG, OpReg(R_ECX));
          Emit(OP_SHR, OpReg(R_ECX), OpImm(31));
          Emit(OP_MOV, OpReg(R_EAX), OpReg(R_EDX));
          Emit(OP_OR, OpReg(R_EAX), OpReg(R_ECX));
        End;
      End;
    IN_ENTIER:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
        CallRT('FLOOR');
      End;
    IN_SQRT:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
        Emit0(OP_FSQRT);
      End;
    IN_SIN, IN_COS, IN_ARCTAN, IN_LN, IN_EXP:
      Begin
        GenExprAs(ExprTab[A1].L, TY_IDX_REAL);
        Case I Of
          IN_SIN    : Emit0(OP_FSIN);
          IN_COS    : Emit0(OP_FCOS);
          IN_ARCTAN :
            Begin
              Emit0(OP_FLD1);
              Emit0(OP_FPATAN);
            End;
          IN_LN     :
            Begin
              Emit0(OP_FLDLN2);
              Emit1(OP_FXCH, OpST(1));
              Emit0(OP_FYL2X);
            End;
          IN_EXP    : CallRT('EXP');
        End;
      End;
  End;
End;

{ Evalue le noeud N : integer, Boolean ou chaine (adresse) dans EAX,
  real dans ST(0). Les autres noeuds viendront avec leurs TODO. }
Procedure GenExpr(N : Integer);
Var
  Lelse, Lend : Integer;
Begin
  Case ExprTab[N].Kind Of
    EX_INT, EX_BOOL:
      LoadImm(R_EAX, ExprTab[N].IntVal);
    EX_REAL:
      Begin
        If ExprTab[N].RealVal = 0 Then
          Emit0(OP_FLDZ)
        Else If ExprTab[N].RealVal = 1 Then
          Emit0(OP_FLD1)
        Else
          Emit1(OP_FLD, OpMemSym(DataReal(ExprTab[N].RealVal), 0, 8));
      End;
    EX_STR:
      Emit(OP_MOV, OpReg(R_EAX),
           OpOffset(DataStr(ExprStrTab[ExprTab[N].StrIdx])));
    EX_VAR:
      GenLoadVar(ExprTab[N].Sym);
    EX_CALL:
      GenCall(N);
    EX_INTRIN:
      GenIntrinsic(N);
    EX_INDEX:
      Begin
        GenIndexAddr(N);
        If IsRealT(ExprTab[N].Typ) Then
          Emit1(OP_FLD, OpMem(R_EAX, 0, 8))
        Else
          Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EAX, 0, 4));
      End;
    EX_UNARY:
      If ExprTab[N].Op = 'not' Then
      Begin
        GenExpr(ExprTab[N].L);
        Emit(OP_TEST, OpReg(R_EAX), OpReg(R_EAX));
        Emit1(OP_SETE, OpReg(R_AL));
        Emit(OP_MOVZX, OpReg(R_EAX), OpReg(R_AL));
      End
      Else
      Begin
        GenExprAs(ExprTab[N].L, ExprTab[N].Typ);
        If ExprTab[N].Op = '-' Then
        Begin
          If IsRealT(ExprTab[N].Typ) Then
            Emit0(OP_FCHS)
          Else
            Emit1(OP_NEG, OpReg(R_EAX));
        End;
      End;
    EX_BINARY:
      GenBinary(N);
    EX_COND:
      Begin
        Lelse := NewLabel;
        Lend  := NewLabel;
        GenJump(ExprTab[N].L, Lelse, False);
        GenExprAs(ExprTab[N].R, ExprTab[N].Typ);
        Emit1(OP_JMP, OpLabel(Lend));
        EmitLabel(Lelse);
        GenExprAs(ExprTab[N].E, ExprTab[N].Typ);
        EmitLabel(Lend);
      End;
    EX_ASSIGN:
      GenAssign(N, True);
  Else
    FatalError('erreur interne: noeud d''expression non genere ' +
               '(TODO 12 a 17)');
  End;
End;

{ ---- Generation du code : instructions --------------------------- }

{ nom := valeur  (NeedValue : la valeur reste dans EAX / ST(0), pour
  les affectations multiples ; sinon un real est depile) }
Procedure GenAssign(N : Integer; NeedValue : Boolean);
Var
  Tgt, Val, TT, Sym : Integer;
  Cell              : TOperand;
Begin
  Tgt := ExprTab[N].L;
  Val := ExprTab[N].R;
  TT  := ExprTab[Tgt].Typ;
  If (ExprTab[Tgt].Kind = EX_INDEX) Or
     (SymTab[ExprTab[Tgt].Sym].Kind = SK_PARAM_NAME) Then
  Begin
    { adresse de la cible d'abord (indices, parametre par nom), puis
      la valeur }
    GenAddrNode(Tgt);
    Emit1(OP_PUSH, OpReg(R_EAX));
    GenExprAs(Val, TT);
    Emit1(OP_POP, OpReg(R_ECX));
    If IsRealT(TT) Then
    Begin
      If NeedValue Then
        Emit1(OP_FST, OpMem(R_ECX, 0, 8))
      Else
        Emit1(OP_FSTP, OpMem(R_ECX, 0, 8));
    End
    Else
      Emit(OP_MOV, OpMem(R_ECX, 0, 4), OpReg(R_EAX));
    Exit;
  End;
  Sym := ExprTab[Tgt].Sym;
  GenExprAs(Val, TT);
  Cell := SymCell(Sym, 0, ValSize(TT));
  If IsRealT(TT) Then
  Begin
    If NeedValue Then Emit1(OP_FST, Cell) Else Emit1(OP_FSTP, Cell);
  End
  Else
    Emit(OP_MOV, Cell, OpReg(R_EAX));
End;

{ Vrai si l'evaluation de N a un effet (appel, affectation) }
Function ExprHasEffect(N : Integer) : Boolean;
Begin
  ExprHasEffect := False;
  If N < 0 Then Exit;
  If ExprTab[N].Kind In [EX_ASSIGN, EX_CALL, EX_IO] Then
  Begin
    ExprHasEffect := True;
    Exit;
  End;
  If ExprHasEffect(ExprTab[N].L) Or ExprHasEffect(ExprTab[N].R) Or
     ExprHasEffect(ExprTab[N].E) Then
    ExprHasEffect := True;
End;

{ Entree/sortie : sortie standard et entree standard par le runtime.
  Le numero de canal (premier argument, sauf print) est evalue
  seulement s'il a un effet ; il n'y a qu'une sortie et qu'une entree. }
Procedure GenIO(N : Integer);
Var
  Op            : TIoOp;
  Item, Ch, A   : Integer;
  E, T          : Integer;
  Cell          : TOperand;
  RdName        : TString;
  Len           : Integer;
  SetChan       : Boolean;
Begin
  Op := TIoOp(ExprTab[N].IntVal);
  Item := ExprTab[N].L;
  SetChan := False;
  If (Op <> IO_PRINT) And (Item >= 0) Then
  Begin
    Ch := ExprTab[Item].L;
    { canal 1 : sortie standard ; les autres sont confiees au runtime
      (SETCHAN : 2 = erreur standard, tout autre = sortie standard) }
    If Op In [IO_OUTSTRING, IO_OUTINTEGER, IO_OUTREAL, IO_OUTBOOLEAN,
              IO_NEWLINE] Then
    Begin
      If Not ((ExprTab[Ch].Kind = EX_INT) And (ExprTab[Ch].IntVal = 1))
      Then
      Begin
        GenExprAs(Ch, TY_IDX_INTEGER);
        CallRT('SETCHAN');
        SetChan := True;
      End;
    End
    Else If ExprHasEffect(Ch) Then
    Begin
      GenExpr(Ch);
      If IsRealT(ExprTab[Ch].Typ) Then Emit1(OP_FSTP, OpST(0));
    End;
    If Op <> IO_NEWLINE Then Item := ExprTab[Item].R;
  End;
  If Op = IO_NEWLINE Then
  Begin
    CallRT('NEWLINE');
    If SetChan Then
    Begin
      Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
      CallRT('SETCHAN');
    End;
    Exit;
  End;
  A := ExprTab[Item].L;
  Case Op Of
    IO_OUTSTRING, IO_PRINT:
      If ExprTab[A].Kind = EX_STR Then
      Begin
        Len := Length(ExprStrTab[ExprTab[A].StrIdx]);
        If Len > 0 Then
        Begin
          Emit(OP_MOV, OpReg(R_EAX),
               OpOffset(DataStr(ExprStrTab[ExprTab[A].StrIdx])));
          Emit(OP_MOV, OpReg(R_EDX), OpImm(Len));
          CallRT('WRITESTR');
        End;
      End
      Else
      Begin
        GenExpr(A);
        CallRT('WRITEZ');
      End;
    IO_OUTINTEGER:
      Begin
        GenExprAs(A, TY_IDX_INTEGER);
        CallRT('WRITEINT');
      End;
    IO_OUTREAL:
      Begin
        GenExprAs(A, TY_IDX_REAL);
        CallRT('WRITEREAL');
      End;
    IO_OUTBOOLEAN:
      Begin
        GenExprAs(A, TY_IDX_BOOLEAN);
        CallRT('WRITEBOOL');
      End;
    IO_ININTEGER, IO_INREAL, IO_INBOOLEAN:
      Begin
        E := A;
        T := ExprTab[E].Typ;
        If Op = IO_INREAL Then
          RdName := 'READREAL'
        Else If Op = IO_INBOOLEAN Then
          RdName := 'READBOOL'
        Else
          RdName := 'READINT';
        If (ExprTab[E].Kind = EX_VAR) And
           (SymTab[ExprTab[E].Sym].Kind <> SK_PARAM_NAME) Then
        Begin
          CallRT(RdName);
          Cell := SymCell(ExprTab[E].Sym, 0, ValSize(T));
          If IsRealT(T) Then
            Emit1(OP_FSTP, Cell)
          Else
            Emit(OP_MOV, Cell, OpReg(R_EAX));
        End
        Else
        Begin
          GenAddrNode(E);
          Emit1(OP_PUSH, OpReg(R_EAX));
          CallRT(RdName);
          Emit1(OP_POP, OpReg(R_ECX));
          If IsRealT(T) Then
            Emit1(OP_FSTP, OpMem(R_ECX, 0, 8))
          Else
            Emit(OP_MOV, OpMem(R_ECX, 0, 4), OpReg(R_EAX));
        End;
      End;
  End;
  If SetChan Then
  Begin
    Emit(OP_MOV, OpReg(R_EAX), OpImm(1));
    CallRT('SETCHAN');
  End;
End;

{ Instruction dont l'arbre est N : affectation, appel ou E/S }
Procedure GenStmtExpr(N : Integer);
Begin
  If N < 0 Then Exit;
  Case ExprTab[N].Kind Of
    EX_ASSIGN: GenAssign(N, False);
    EX_IO:     GenIO(N);
  Else
    Begin
      GenExpr(N);
      If IsRealT(ExprTab[N].Typ) Then Emit1(OP_FSTP, OpST(0));
    End;
  End;
End;

{ ---- Sauts : goto, designateurs et switch (TODO 14) -------------
  Un goto vers une etiquette d'un niveau de procedure plus bas
  depile les procedures intermediaires : EBP du niveau cible par les
  liens statiques, ESP restaure depuis [EBP-4] de ce niveau (ou egal
  a EBP pour le programme principal, sans locale). Une etiquette pas
  encore definie dans une procedure (renvoi avant) peut appartenir a
  une procedure englobante : le saut passe alors par une souche
  generee quand l'etiquette est definie. ---------------------------- }
Const
  MAX_PEND = {$IFDEF FPC}1024{$ELSE}32{$ENDIF};

Type
  TPendRef = Record
    Name     : TMangled;      { nom ASM de l'etiquette attendue         }
    Stub     : Integer;       { etiquette de la souche (indice de nom)  }
    RefLevel : Integer;       { niveau du code qui saute                }
  End;

Var
  PendTab   : Array[0..MAX_PEND - 1] Of TPendRef;
  PendCount : Integer;

{ Saut de RefLevel vers l'etiquette Target de niveau TargetLevel }
Procedure GenUnwindJump(RefLevel, TargetLevel : Integer;
                        Target : Integer);
Var
  K : Integer;
Begin
  K := RefLevel - TargetLevel;
  If K > 0 Then
  Begin
    If TargetLevel = 0 Then
    Begin
      { le programme principal n'a pas de lien statique : son cadre est
        memorise au demarrage ; il n'a pas de locale (ESP = EBP) }
      Emit(OP_MOV, OpReg(R_EBP), OpMemSym(Intern(A60_MAINBP), 0, 4));
      Emit(OP_MOV, OpReg(R_ESP), OpReg(R_EBP));
    End
    Else
    Begin
      Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EBP, ABI_PARAM_BASE, 4));
      Dec(K);
      While K > 0 Do
      Begin
        Emit(OP_MOV, OpReg(R_ECX), OpMem(R_ECX, ABI_PARAM_BASE, 4));
        Dec(K);
      End;
      Emit(OP_MOV, OpReg(R_ESP), OpMem(R_ECX, -4, 4));
      Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ECX));
    End;
  End;
  Emit1(OP_JMP, OpLabel(Target));
End;

{ Renvoi avant depuis une procedure : enregistre une souche a generer
  a la definition de l'etiquette S ; retourne son etiquette }
Function NewStubRef(S, RefLevel : Integer) : Integer;
Begin
  If PendCount >= MAX_PEND Then
    FatalError('trop de renvois avant dans des procedures (max ' +
               ItoS(MAX_PEND) + ')');
  PendTab[PendCount].Name     := SymTab[S].Mangled;
  PendTab[PendCount].Stub     := NewLabel;
  PendTab[PendCount].RefLevel := RefLevel;
  NewStubRef := PendTab[PendCount].Stub;
  Inc(PendCount);
End;

{ L'etiquette S vient d'etre definie au niveau courant : genere les
  souches des renvois avant en attente (apres le programme) }
Procedure ResolveStubs(S : Integer);
Var
  I, Start : Integer;
Begin
  For I := 0 To PendCount - 1 Do
    If PendTab[I].Name = SymTab[S].Mangled Then
    Begin
      Start := CodeCount;
      EmitLabel(PendTab[I].Stub);
      GenUnwindJump(PendTab[I].RefLevel, SymTab[S].Level,
                    Intern(SymTab[S].Mangled));
      MoveToDeferred(Start);
      PendTab[I].Name := '';
    End;
End;

{ Saut vers un designateur (goto) }
Procedure GenDesignator(D : Integer);
Var
  S, Cnt, Lskip, Lelse, K : Integer;
Begin
  Case ExprTab[D].Kind Of
    EX_LABEL:
      If ExprTab[D].Flag Then
        Emit1(OP_JMP, OpLabel(ExprTab[D].IntVal))     { souche }
      Else
        GenUnwindJump(CurLevel, SymTab[ExprTab[D].Sym].Level,
                      Intern(SymTab[ExprTab[D].Sym].Mangled));
    EX_SWITCHREF:
      Begin
        S   := ExprTab[D].Sym;
        Cnt := SymTab[S].SwitchCount;
        Lskip := NewLabel;
        GenExprAs(ExprTab[D].L, TY_IDX_INTEGER);
        Emit(OP_CMP, OpReg(R_EAX), OpImm(1));
        Emit1(OP_JL, OpLabel(Lskip));
        Emit(OP_CMP, OpReg(R_EAX), OpImm(Cnt));
        Emit1(OP_JG, OpLabel(Lskip));
        { le switch est declare a un niveau plus bas : on y remonte
          d'abord, la table sert alors de ce niveau }
        K := CurLevel - SymTab[S].Level;
        If K > 0 Then
        Begin
          If SymTab[S].Level = 0 Then
          Begin
            Emit(OP_MOV, OpReg(R_EBP),
                 OpMemSym(Intern(A60_MAINBP), 0, 4));
            Emit(OP_MOV, OpReg(R_ESP), OpReg(R_EBP));
          End
          Else
          Begin
            Emit(OP_MOV, OpReg(R_ECX), OpMem(R_EBP, ABI_PARAM_BASE, 4));
            Dec(K);
            While K > 0 Do
            Begin
              Emit(OP_MOV, OpReg(R_ECX),
                   OpMem(R_ECX, ABI_PARAM_BASE, 4));
              Dec(K);
            End;
            Emit(OP_MOV, OpReg(R_ESP), OpMem(R_ECX, -4, 4));
            Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ECX));
          End;
        End;
        Emit1(OP_JMP, OpMemIdx(Intern(SymTab[S].Mangled), R_NONE, R_EAX,
                               4, -4, 4));
        EmitLabel(Lskip);
      End;
    EX_COND:
      Begin
        Lelse := NewLabel;
        GenJump(ExprTab[D].L, Lelse, False);
        GenDesignator(ExprTab[D].R);
        EmitLabel(Lelse);
        GenDesignator(ExprTab[D].E);
      End;
  End;
End;

{ Declaration d'un switch : table des adresses dans .data. Les
  entrees sont executees avec le cadre du niveau du switch : une
  etiquette d'un autre niveau, ou pas encore definie dans une
  procedure, passe par une souche ; un designateur qui n'est pas une
  simple etiquette recoit un petit bloc de code qui calcule la
  destination. }
Procedure GenSwitchDecl(S : Integer; Const Ds : Array Of Integer;
                        Count : Integer);
Var
  Entries : Array[0..MAX_SWITCH - 1] Of Integer;
  Stubs   : Array[0..MAX_SWITCH - 1] Of Integer;
  I, Lskip, Start : Integer;
  AnyStub  : Boolean;
  L        : Integer;
Begin
  AnyStub := False;
  For I := 0 To Count - 1 Do
  Begin
    Stubs[I] := -1;
    If ExprTab[Ds[I]].Kind = EX_LABEL Then
    Begin
      L := ExprTab[Ds[I]].Sym;
      If ExprTab[Ds[I]].Flag Then
        Entries[I] := ExprTab[Ds[I]].IntVal           { souche en attente }
      Else If SymTab[L].Level = CurLevel Then
        Entries[I] := Intern(SymTab[L].Mangled)
      Else
      Begin
        { etiquette d'un niveau plus bas : souche immediate }
        Start := CodeCount;
        Entries[I] := NewLabel;
        EmitLabel(Entries[I]);
        GenUnwindJump(CurLevel, SymTab[L].Level,
                      Intern(SymTab[L].Mangled));
        MoveToDeferred(Start);
      End;
    End
    Else
    Begin
      Stubs[I] := NewLabel;
      Entries[I] := Stubs[I];
      AnyStub := True;
    End;
  End;
  If AnyStub Then
  Begin
    Lskip := NewLabel;
    Emit1(OP_JMP, OpLabel(Lskip));
    For I := 0 To Count - 1 Do
      If Stubs[I] >= 0 Then
      Begin
        EmitLabel(Stubs[I]);
        GenDesignator(Ds[I]);
      End;
    EmitLabel(Lskip);
  End;
  DataTable(Intern(SymTab[S].Mangled), Entries, Count);
End;

{ ---- Procedures : prologue et epilogue ---- }

Type
  TProcGen = Record
    Start     : LongInt;     { debut dans CodeTab }
    PatchSub  : LongInt;     { SUB ESP, taille }
    PatchMov  : LongInt;     { MOV ECX, taille / 4 }
  End;

{ Prologue : cadre, locales mises a zero, puis [EBP-4] := ESP (cellule
  reservee par SymEnterProc, utilisee par les goto qui sortent d'une
  procedure imbriquee) }
Procedure GenProcBegin(Var PG : TProcGen; S : Integer);
Begin
  PG.Start := CodeCount;
  EmitBlank;
  EmitComment('procedure ' + SymTab[S].Name);
  EmitLabel(Intern(SymTab[S].Mangled));
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
  PG.PatchSub := CodeCount;
  Emit(OP_SUB, OpReg(R_ESP), OpImm(0));
  Emit(OP_MOV, OpReg(R_EDI), OpReg(R_ESP));
  Emit(OP_XOR, OpReg(R_EAX), OpReg(R_EAX));
  PG.PatchMov := CodeCount;
  Emit(OP_MOV, OpReg(R_ECX), OpImm(0));
  Emit0(OP_REP_STOSD);
  Emit(OP_MOV, OpMem(R_EBP, -4, 4), OpReg(R_ESP));
End;

{ A appeler avant SymLeaveScope : la taille du cadre est connue }
Procedure GenProcEnd(Var PG : TProcGen; S : Integer);
Var
  Frame : LongInt;
Begin
  Frame := SymFrameSize;
  CodeTab[PG.PatchSub].B := OpImm(Frame);
  CodeTab[PG.PatchMov].B := OpImm(Frame Div 4);
  If SymTab[S].Kind = SK_FUNC Then
  Begin
    If IsRealT(SymTab[S].TypeIdx) Then
      Emit1(OP_FLD, OpMem(R_EBP, SymResultOfs, 8))
    Else
      Emit(OP_MOV, OpReg(R_EAX), OpMem(R_EBP, SymResultOfs, 4));
  End;
  Emit(OP_MOV, OpReg(R_ESP), OpReg(R_EBP));
  Emit1(OP_POP, OpReg(R_EBP));
  If SymTab[S].ParamBytes > 0 Then
    Emit1(OP_RET, OpImm(SymTab[S].ParamBytes))
  Else
    Emit0(OP_RET);
  MoveToDeferred(PG.Start);
End;

Procedure GenMainBegin;
Begin
  EmitComment('programme principal');
  EmitLabel(Intern(A60_MAIN_NAME));
  Emit1(OP_PUSH, OpReg(R_EBP));
  Emit(OP_MOV, OpReg(R_EBP), OpReg(R_ESP));
  DataAddZero(Intern(A60_MAINBP), 4);
  Emit(OP_MOV, OpMemSym(Intern(A60_MAINBP), 0, 4), OpReg(R_EBP));
End;

Procedure GenMainEnd;
Begin
  Emit1(OP_PUSH, OpImm(0));
  Emit1(OP_CALL, OpLabel(Intern('ExitProcess')));
End;

{ ---- Analyse des instructions ------------------------------------ }
Var
  DeclCount   : LongInt;      { variables declarees (statistiques)   }
  BlockCount  : LongInt;      { blocs begin...end analyses           }
  AssignCount : LongInt;      { affectations analysees               }
  IfCount     : LongInt;      { instructions if                      }
  LabelCount  : LongInt;      { etiquettes definies                  }
  ForCount    : LongInt;      { instructions for                     }
  GotoCount   : LongInt;      { instructions goto                    }
  DynCount    : Integer;      { tableaux a bornes variables ouverts  }
  DynStack    : Array[0..63] Of Integer;
  LoopDepth   : Integer;      { imbrication courante des for         }

Const
  MAX_DYN_ARR = 64;

Procedure ParseStatement; Forward;
Procedure ParseBlock; Forward;

{ Debut d'une expression isolee utilisee comme instruction (extension
  toleree par les exemples : a + b ; `texte` ; 42 ;). Elle est evaluee
  seulement si elle a un effet ; sinon avertissement. }
Function AtExprStart : Boolean;
Begin
  AtExprStart := (CurToken.Kind In [TK_INTEGER, TK_REAL, TK_STRING]) Or
                 AtKw('true') Or AtKw('false') Or AtKw('not') Or
                 AtOp('+') Or AtOp('-') Or AtPunct('(');
End;

Procedure ParseExprStatement;
Var
  N, Line, Col : Integer;
Begin
  Line := CurToken.Line;
  Col  := CurToken.Col;
  ExprReset;
  N := ParseExpr;
  If N < 0 Then
  Begin
    ParserSync;
    Exit;
  End;
  If Opts.DebugMode Then
  Begin
    WriteLn('Expression ligne ', Line, ' :');
    ExprDump(N, 0);
  End;
  If ExprHasEffect(N) Then
    GenStmtExpr(N)
  Else
  Begin
    WarnAt(Line, Col, 'expression sans effet ignoree');
    If ExprTab[N].Kind = EX_STR Then
      DataStr(ExprStrTab[ExprTab[N].StrIdx]);
  End;
  If Not AtStmtEnd Then
  Begin
    ParseError('operateur ou '';'' attendu');
    ParserSync;
  End;
End;

{ Procedures d'entree/sortie standard : nom(canal, valeur) ; print(texte)
  et newline(canal). Tok = le nom, deja consomme. }
Procedure ParseIO(Const Tok : TToken; Op : TIoOp);
Var
  Head, Tail, Item, E, N, Expected : Integer;
  Bad                               : Boolean;
  Line, Col                         : Integer;
  Conv                              : TConv;
  Node, K, Want                     : Integer;
  Args                              : Array[1..2] Of Integer;
Begin
  Inc(IOCount);
  Head := -1;
  Tail := -1;
  N    := 0;
  Bad  := False;
  Args[1] := -1;
  Args[2] := -1;
  Case Op Of
    IO_NEWLINE, IO_PRINT : Expected := 1;
  Else
    Expected := 2;
  End;
  If (Op = IO_NEWLINE) And (Not AtPunct('(')) Then
  Begin
    { newline sans argument : sortie standard }
    Node := ExprNew(EX_IO, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
    ExprTab[Node].IntVal := Ord(Op);
    ExprTab[Node].L      := -1;
    GenIO(Node);
    Exit;
  End;
  If (Op = IO_SYSACT) And (Not AtPunct('(')) Then Exit;
  If Not AtPunct('(') Then
  Begin
    ParseError('''('' attendu apres ' + Tok.Val);
    ParserSync;
    Exit;
  End;
  ParserAdvance;
  If Not AtPunct(')') Then
    Repeat
      Line := CurToken.Line;
      Col  := CurToken.Col;
      E := ParseExpr;
      Inc(N);
      If N <= 2 Then Args[N] := E;
      If E < 0 Then
        Bad := True
      Else
      Begin
        Item := ExprNew(EX_LIST, ExprTab[E].Typ, Line, Col);
        ExprTab[Item].L := E;
        If Head < 0 Then Head := Item Else ExprTab[Tail].R := Item;
        Tail := Item;
      End;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
  ExpectPunct(')');
  If Op = IO_SYSACT Then Exit;        { appel systeme : sans effet }
  If N <> Expected Then
  Begin
    ErrorAt(Tok.Line, Tok.Col, Tok.Val + ': ' + ItoS(Expected) +
            ' argument(s) attendu(s), ' + ItoS(N) + ' trouve(s)');
    Exit;
  End;
  If Bad Then Exit;
  { le canal est un entier }
  If Op <> IO_PRINT Then
  Begin
    If Not ExprCoerceCtx(Args[1], TY_IDX_INTEGER, Conv,
                         ExprTab[Args[1]].Line, ExprTab[Args[1]].Col,
                         'canal') Then Exit;
    K := 2;
  End
  Else
    K := 1;
  If Op = IO_NEWLINE Then
  Begin
    Node := ExprNew(EX_IO, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
    ExprTab[Node].IntVal := Ord(Op);
    ExprTab[Node].L      := Head;
    GenIO(Node);
    Exit;
  End;
  E := Args[K];
  Line := ExprTab[E].Line;
  Col  := ExprTab[E].Col;
  Case Op Of
    IO_OUTSTRING, IO_PRINT:
      If ExprTab[E].Typ <> TY_IDX_STRING Then
      Begin
        ErrorAt(Line, Col, Tok.Val + ': texte attendu (type: ' +
                TypeName(ExprTab[E].Typ) + ')');
        Exit;
      End;
    IO_OUTINTEGER:
      If Not ExprCoerceCtx(E, TY_IDX_INTEGER, Conv, Line, Col,
                           'argument') Then Exit;
    IO_OUTREAL:
      If Not ExprCoerceCtx(E, TY_IDX_REAL, Conv, Line, Col,
                           'argument') Then Exit;
    IO_OUTBOOLEAN:
      If Not ExprCoerceCtx(E, TY_IDX_BOOLEAN, Conv, Line, Col,
                           'argument') Then Exit;
    IO_ININTEGER, IO_INREAL, IO_INBOOLEAN:
      Begin
        Case Op Of
          IO_ININTEGER : Want := TY_IDX_INTEGER;
          IO_INREAL    : Want := TY_IDX_REAL;
        Else
          Want := TY_IDX_BOOLEAN;
        End;
        If Not (ExprTab[E].Kind In [EX_VAR, EX_INDEX]) Then
        Begin
          ErrorAt(Line, Col, Tok.Val + ': variable attendue');
          Exit;
        End;
        If ExprTab[E].Typ <> Want Then
        Begin
          ErrorAt(Line, Col, Tok.Val + ': variable ' + TypeName(Want) +
                  ' attendue (type: ' + TypeName(ExprTab[E].Typ) + ')');
          Exit;
        End;
        If (ExprTab[E].Kind = EX_VAR) And
           (SymTab[ExprTab[E].Sym].Kind = SK_PARAM_NAME) Then
          SymTab[ExprTab[E].Sym].IsWritten := True;
      End;
  End;
  Node := ExprNew(EX_IO, TY_IDX_PROCEDURE, Tok.Line, Tok.Col);
  ExprTab[Node].IntVal := Ord(Op);
  ExprTab[Node].L      := Head;
  If Opts.DebugMode Then
  Begin
    WriteLn('E/S ligne ', Tok.Line, ' :');
    ExprDump(Node, 1);
  End;
  GenIO(Node);
End;

{ Cible deja analysee (variable ou element de tableau) suivie de ':='
  (token courant). Liste d'affectations a := b := expr : le membre
  droit est analyse comme une expression ; si un ':=' suit et que
  c'est une cible, l'affectation continue (associative a droite).
  Toutes les variables de la liste ont le meme type (rapport, 4.2.4). }
Function ParseAssignTail(Tgt : Integer) : Integer;
Var
  Val, N    : Integer;
  Conv      : TConv;
  Line, Col : Integer;
Begin
  ParseAssignTail := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  ParserAdvance;                          { :=  }
  Val := ParseExpr;
  If (Val >= 0) And AtOp(':=') And
     (ExprTab[Val].Kind In [EX_VAR, EX_INDEX]) Then
  Begin
    If (Tgt >= 0) And (ExprTab[Val].Typ <> ExprTab[Tgt].Typ) Then
      ErrorAt(Line, Col, 'les variables d''une liste d''affectation ' +
              'doivent avoir le meme type: ' + TypeName(ExprTab[Tgt].Typ) +
              ', ' + TypeName(ExprTab[Val].Typ));
    Val := ParseAssignTail(Val);
  End;
  If (Tgt < 0) Or (Val < 0) Then Exit;
  If Not ExprCoerce(Val, ExprTab[Tgt].Typ, Conv, Line, Col) Then Exit;
  { affectation d'un parametre par nom : l'argument doit pouvoir etre
    ecrit (TODO 17) }
  If (ExprTab[Tgt].Kind = EX_VAR) And
     (SymTab[ExprTab[Tgt].Sym].Kind = SK_PARAM_NAME) Then
    SymTab[ExprTab[Tgt].Sym].IsWritten := True;
  N := ExprNew(EX_ASSIGN, ExprTab[Tgt].Typ, Line, Col);
  ExprTab[N].Op   := ':=';
  ExprTab[N].L    := Tgt;
  ExprTab[N].R    := Val;
  ExprTab[N].Conv := Conv;
  Inc(AssignCount);
  ParseAssignTail := N;
End;

{ nom : instruction   (etiquette ; le ':' est le token courant).
  Les renvois avant en attente vers cette etiquette recoivent leur
  souche. }
Procedure ParseLabelDef(Const Name : TString; Line, Col : Integer);
Var
  S : Integer;
Begin
  S := SymDefLabel(Name, Line, Col);
  EmitLabel(Intern(SymTab[S].Mangled));
  ResolveStubs(S);
  Inc(LabelCount);
  If Opts.DebugMode Then
    WriteLn('Etiquette ', Name, ' ligne ', Line);
  ParserAdvance;                          { : }
  ParseStatement;
End;

{ Instruction commencant par un entier : etiquette numerique
  (100: instruction) ou expression isolee }
Procedure ParseNumericStart;
Var
  Tok : TToken;
Begin
  Tok := CurToken;
  ParserAdvance;
  If AtPunct(':') Then
    ParseLabelDef(ItoS(Tok.IntVal), Tok.Line, Tok.Col)
  Else
  Begin
    ParserUnget(Tok);
    ParseExprStatement;
  End;
End;

{ Designateur : etiquette, element de switch, ou expression
  conditionnelle de designateurs :
    fin   100   menu[i + 1]   (d)   if c then fin else menu[2]
  Retourne un noeud EX_LABEL, EX_SWITCHREF ou EX_COND (type label),
  -1 en cas d'erreur. Un nom inconnu devient une etiquette en renvoi
  avant, resolue plus tard par SymDefLabel ; dans une procedure, un
  tel renvoi passe par une souche (Flag, IntVal = etiquette de la
  souche). }
Function ParseDesignator : Integer;
Var
  Tok       : TToken;
  C, T, E   : Integer;
  S, Idx, N : Integer;
  Conv      : TConv;
  Line, Col : Integer;
  Bad       : Boolean;
Begin
  ParseDesignator := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;

  If AtKw('if') Then
  Begin
    ParserAdvance;
    C := ParseCondition;
    If AtKw('then') Then
      ParserAdvance
    Else
    Begin
      ParseError('''then'' attendu');
      Exit;
    End;
    T := ParseDesignator;
    If AtKw('else') Then
      ParserAdvance
    Else
    Begin
      ParseError('''else'' attendu dans un designateur conditionnel');
      Exit;
    End;
    E := ParseDesignator;
    If (C < 0) Or (T < 0) Or (E < 0) Then Exit;
    N := ExprNew(EX_COND, TY_IDX_LABEL, Line, Col);
    ExprTab[N].L := C;
    ExprTab[N].R := T;
    ExprTab[N].E := E;
    ParseDesignator := N;
  End
  Else If AtPunct('(') Then
  Begin
    ParserAdvance;
    N := ParseDesignator;
    ExpectPunct(')');
    ParseDesignator := N;
  End
  Else If (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_IDENT) Then
  Begin
    Tok := CurToken;
    ParserAdvance;
    If (Tok.Kind = TK_IDENT) And AtPunct('[') Then
    Begin
      Bad := False;
      S := SymFind(Tok.Val);
      If (S < 0) Or (SymTab[S].Kind <> SK_SWITCH) Then
      Begin
        ErrorAt(Tok.Line, Tok.Col, 'switch attendu: ' + Tok.Val);
        Bad := True;
      End;
      ParserAdvance;                              { [ }
      Line := CurToken.Line;
      Col  := CurToken.Col;
      Idx := ParseExpr;
      If Idx >= 0 Then
        If Not ExprCoerce(Idx, TY_IDX_INTEGER, Conv, Line, Col) Then
          Idx := -1;
      ExpectPunct(']');
      If Bad Or (Idx < 0) Then Exit;
      If ExprTab[Idx].Kind = EX_INT Then
        If (SymTab[S].SwitchCount > 0) And
           ((ExprTab[Idx].IntVal < 1) Or
            (ExprTab[Idx].IntVal > SymTab[S].SwitchCount)) Then
          WarnAt(Line, Col, 'indice de switch hors bornes (1..' +
                 ItoS(SymTab[S].SwitchCount) + '): aucun saut');
      N := ExprNew(EX_SWITCHREF, TY_IDX_LABEL, Tok.Line, Tok.Col);
      ExprTab[N].Sym := S;
      ExprTab[N].L   := Idx;
      ParseDesignator := N;
    End
    Else
    Begin
      If Tok.Kind = TK_INTEGER Then
        Tok.Val := ItoS(Tok.IntVal)
      Else
      Begin
        S := SymFind(Tok.Val);
        If (S >= 0) And (SymTab[S].Kind = SK_SWITCH) Then
        Begin
          ErrorAt(Tok.Line, Tok.Col, 'indice attendu pour le switch ' +
                  Tok.Val);
          Exit;
        End;
        If (S >= 0) And (SymTab[S].Kind <> SK_LABEL) And
           (Not (SymTab[S].Kind In [SK_PARAM_VALUE, SK_PARAM_NAME])) Then
        Begin
          ErrorAt(Tok.Line, Tok.Col, 'etiquette attendue: ' + Tok.Val +
                  ' (' + SymKindName(SymTab[S].Kind) + ')');
          Exit;
        End;
      End;
      S := SymRefLabel(Tok.Val, Tok.Line, Tok.Col);
      N := ExprNew(EX_LABEL, TY_IDX_LABEL, Tok.Line, Tok.Col);
      ExprTab[N].Sym := S;
      If (Not SymTab[S].LevelKnown) And (CurLevel > 0) Then
      Begin
        ExprTab[N].Flag   := True;
        ExprTab[N].IntVal := NewStubRef(S, CurLevel);
      End;
      ParseDesignator := N;
    End;
  End
  Else
    ParseError('designateur attendu (etiquette ou switch[i])');
End;

{ goto designateur   (le mot goto est le token courant) }
Procedure ParseGoto;
Var
  D, Line : Integer;
Begin
  Inc(GotoCount);
  Line := CurToken.Line;
  ParserAdvance;                          { goto }
  ExprReset;
  D := ParseDesignator;
  If D < 0 Then
  Begin
    ParserSync;
    Exit;
  End;
  If Opts.DebugMode Then
  Begin
    WriteLn('Goto ligne ', Line, ' :');
    ExprDump(D, 1);
  End;
  GenDesignator(D);
End;

{ switch nom := designateur, designateur, ... }
Procedure ParseSwitchDecl;
Var
  S, N, D : Integer;
  Ds      : Array[0..MAX_SWITCH - 1] Of Integer;
  Failed  : Boolean;
Begin
  Failed := False;
  If CurToken.Kind <> TK_IDENT Then
  Begin
    ParseError('nom de switch attendu');
    ParserSync;
    Exit;
  End;
  S := SymAdd(CurToken.Val, SK_SWITCH, TY_IDX_SWITCH, False,
              CurToken.Line, CurToken.Col);
  Inc(DeclCount);
  ParserAdvance;
  If AtOp(':=') Then
    ParserAdvance
  Else
    ParseError(''':='' attendu apres le nom du switch');
  If AtPunct(';') Or AtEOF Then
  Begin
    ParseError('liste de designateurs attendue');
    Exit;
  End;
  ExprReset;
  N := 0;
  Repeat
    D := ParseDesignator;
    Inc(N);
    If D < 0 Then
    Begin
      Failed := True;
      ParserSync;
      Break;
    End;
    If N > MAX_SWITCH Then
    Begin
      ErrorAt(CurToken.Line, CurToken.Col, 'switch trop long (max ' +
              ItoS(MAX_SWITCH) + ')');
      Failed := True;
      ParserSync;
      Break;
    End;
    Ds[N - 1] := D;
    If Opts.DebugMode Then
    Begin
      WriteLn('Switch ', SymTab[S].Name, ' designateur ', N, ' :');
      ExprDump(D, 1);
    End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  SymTab[S].SwitchCount := N;
  If Not Failed Then GenSwitchDecl(S, Ds, N);
End;

{ label nom, nom, ... ;  declaration d'etiquettes (extension des
  exemples) : le niveau est connu des la declaration }
Procedure ParseLabelDecl;
Var
  S    : Integer;
  Done : Boolean;
Begin
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('identificateur attendu dans la declaration');
      ParserSync;
      Exit;
    End;
    S := SymAdd(CurToken.Val, SK_LABEL, TY_IDX_LABEL, False,
                CurToken.Line, CurToken.Col);
    SymTab[S].LevelKnown := True;
    Inc(DeclCount);
    ParserAdvance;
    Done := Not AtPunct(',');
    If Not Done Then ParserAdvance;
  Until Done;
End;

{ Instruction commencant par un identificateur : etiquette (nom :),
  affectation (nom := ou nom[...] :=) ou appel de procedure. }
Procedure ParseIdentStatement;
Var
  Tok       : TToken;
  Tgt, N, S : Integer;
Begin
  Tok := CurToken;
  ParserAdvance;
  If AtPunct(':') Then
  Begin
    ParseLabelDef(Tok.Val, Tok.Line, Tok.Col);
    Exit;
  End;
  S := SymFind(Tok.Val);
  If (S < 0) And (FindIo(Tok.Val) <> IO_NONE) And (Not AtOp(':=')) Then
  Begin
    ExprReset;
    ParseIO(Tok, FindIo(Tok.Val));
    Exit;
  End;
  If (S >= 0) And ((SymTab[S].Kind In [SK_PROC, SK_FUNC]) Or
                   IsFormalProc(S)) And
     (Not AtOp(':=')) And (Not AtPunct('[')) Then
  Begin
    { appel de procedure comme instruction }
    ExprReset;
    N := ParseCall(Tok, S);
    If N < 0 Then
      ParserSync
    Else
    Begin
      If Opts.DebugMode Then
      Begin
        WriteLn('Appel ligne ', ExprTab[N].Line, ' :');
        ExprDump(N, 1);
      End;
      GenStmtExpr(N);
    End;
    Exit;
  End;
  If (Not (AtOp(':=') Or AtPunct('['))) And
     (AtStmtEnd Or (CurToken.Kind = TK_OP) Or AtKw('div') Or AtKw('and') Or
      AtKw('or') Or AtKw('impl') Or AtKw('equiv')) Then
  Begin
    { variable ou expression commencant par un nom : sans effet }
    ParserUnget(Tok);
    ParseExprStatement;
    Exit;
  End;
  If Not (AtOp(':=') Or AtPunct('[')) Then
  Begin
    If AtPunct('(') Then
      ErrorAt(Tok.Line, Tok.Col, 'procedure inconnue: ' + Tok.Val)
    Else
      ErrorAt(Tok.Line, Tok.Col, 'instruction incorrecte apres ' +
              Tok.Val + ' (affectation, appel ou etiquette attendu)');
    ParserSync;
    Exit;
  End;
  ParserUnget(Tok);                       { nom de nouveau courant }
  ExprReset;
  Tgt := ParseExpr;
  N := -1;
  If Tgt >= 0 Then
    If AtOp(':=') And (ExprTab[Tgt].Kind In [EX_VAR, EX_INDEX]) Then
      N := ParseAssignTail(Tgt)
    Else
      ParseError(''':='' attendu apres ' + Tok.Val);
  If N < 0 Then
    ParserSync
  Else
  Begin
    If Opts.DebugMode Then
    Begin
      WriteLn('Affectation ligne ', ExprTab[N].Line, ' :');
      ExprDump(N, 0);
    End;
    GenStmtExpr(N);
  End;
End;

{ if condition then instruction [else instruction]
  Le else se rattache au if le plus proche (appel recursif). Code :
    saut vers Lelse si la condition est fausse ; then ; [JMP Lend ;
    Lelse : else ; Lend :]. }
Procedure ParseIf;
Var
  C           : Integer;
  Line        : Integer;
  Lelse, Lend : Integer;
Begin
  Inc(IfCount);
  Line := CurToken.Line;
  ParserAdvance;                          { if }
  ExprReset;
  C := ParseCondition;
  If Opts.DebugMode And (C >= 0) Then
  Begin
    WriteLn('If ligne ', Line, ' : condition');
    ExprDump(C, 1);
  End;
  Lelse := NewLabel;
  If C >= 0 Then GenJump(C, Lelse, False);
  If AtKw('then') Then
    ParserAdvance
  Else
  Begin
    ParseError('''then'' attendu apres la condition');
    ParserSync;
    Exit;
  End;
  ParseStatement;
  If AtKw('else') Then
  Begin
    If Opts.DebugMode Then WriteLn('Else (if ligne ', Line, ')');
    Lend := NewLabel;
    Emit1(OP_JMP, OpLabel(Lend));
    EmitLabel(Lelse);
    ParserAdvance;
    ParseStatement;
    EmitLabel(Lend);
  End
  Else
    EmitLabel(Lelse);
End;

Const
  MAX_FOR_CLAUSES = 16;

Type
  { Contexte d'une instruction for pendant l'analyse de sa liste.
    Disposition du code : les clauses d'abord (chacune saute vers le
    corps), puis le corps, puis le retour a la clause active, puis la
    sortie. }
  TForCtx = Record
    Valid     : Boolean;               { variable de boucle utilisable }
    Sym       : Integer;               { variable de boucle           }
    VT        : Integer;               { son type                     }
    Line, Col : Integer;
    LBody     : Integer;               { etiquette du corps           }
    LExit     : Integer;               { etiquette de sortie          }
    LEnd      : Integer;               { fin de la clause en cours    }
    Count     : Integer;               { clauses analysees            }
    Next      : Array[1..MAX_FOR_CLAUSES] Of Integer;
    HasSel    : Boolean;               { selecteur de clause alloue   }
    SelName   : Integer;               { selecteur global (niveau 0)  }
    SelOfs    : LongInt;               { ou local [EBP+SelOfs]        }
  End;

{ Cellule du selecteur de clause active (allouee a la demande) }
Function ForSelCell(Var C : TForCtx) : TOperand;
Begin
  If Not C.HasSel Then
  Begin
    C.HasSel := True;
    If CurLevel > 0 Then
    Begin
      C.SelName := -1;
      C.SelOfs  := SymAllocLocal(4);
    End
    Else
    Begin
      Inc(ConstSeq);
      C.SelName := Intern('_A60FSEL_' + ItoS(ConstSeq));
      DataAddZero(C.SelName, 4);
    End;
  End;
  If C.SelName >= 0 Then
    ForSelCell := OpMemSym(C.SelName, 0, 4)
  Else
    ForSelCell := OpMem(R_EBP, C.SelOfs, 4);
End;

{ variable de boucle := valeur }
Procedure ForAssign(Var C : TForCtx; Val : Integer);
Var
  A : Integer;
Begin
  A := ExprNew(EX_ASSIGN, C.VT, C.Line, C.Col);
  ExprTab[A].L := ExprMakeVar(C.Sym, C.Line, C.Col);
  ExprTab[A].R := Val;
  GenAssign(A, False);
End;

{ Compare la variable de boucle a Limit (Op = '>' ou '<') et saute
  vers Target quand la comparaison est vraie }
Procedure ForCompareJump(Var C : TForCtx; Const Op : TString;
                         Limit, Target : Integer);
Var
  Cmp : Integer;
Begin
  Cmp := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, C.Line, C.Col);
  ExprTab[Cmp].Op := Op;
  ExprTab[Cmp].L  := ExprMakeVar(C.Sym, C.Line, C.Col);
  ExprTab[Cmp].R  := Limit;
  GenJump(Cmp, Target, True);
End;

{ Un element de liste de for : valeur, step-until ou while. }
Procedure ParseForClause(Var C : TForCtx);
Var
  E1, E2, E3, Cd : Integer;
  Conv           : TConv;
  Line, Col      : Integer;
  Empty, Multi   : Boolean;
  Lnext, Ltest   : Integer;
  Lneg, Lcont    : Integer;
  Plus, A, Z, Sg : Integer;
  Kind           : Integer;      { 1 valeur, 2 step-until, 3 while }
  Good           : Boolean;
Begin
  ExprReset;
  Inc(C.Count);
  Line := CurToken.Line;
  Col  := CurToken.Col;
  E1 := ParseExpr;
  If E1 >= 0 Then
    If Not ExprCoerce(E1, C.VT, Conv, Line, Col) Then E1 := -1;
  E2 := -1;
  E3 := -1;
  Cd := -1;
  Kind := 1;
  Good := E1 >= 0;

  If AtKw('step') Then
  Begin
    Kind := 2;
    ParserAdvance;
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E2 := ParseExpr;
    If (E2 >= 0) And (Not TypeIsArith(ExprTab[E2].Typ)) Then
    Begin
      ErrorAt(Line, Col, 'pas numerique attendu (type: ' +
              TypeName(ExprTab[E2].Typ) + ')');
      E2 := -1;
    End;
    If AtKw('until') Then
      ParserAdvance
    Else
      ParseError('''until'' attendu apres step');
    Line := CurToken.Line;
    Col  := CurToken.Col;
    E3 := ParseExpr;
    If (E3 >= 0) And (Not TypeIsArith(ExprTab[E3].Typ)) Then
    Begin
      ErrorAt(Line, Col, 'limite numerique attendue (type: ' +
              TypeName(ExprTab[E3].Typ) + ')');
      E3 := -1;
    End;
    Good := Good And (E2 >= 0) And (E3 >= 0);
    If Good Then
    Begin
      If Opts.DebugMode Then
      Begin
        WriteLn('  clause step-until :');
        WriteLn('    init :');  ExprDump(E1, 3);
        WriteLn('    step :');  ExprDump(E2, 3);
        WriteLn('    until :'); ExprDump(E3, 3);
      End;
      If ExprIsConst(E2) And (ExprConstReal(E2) = 0) Then
        WarnAt(Line, Col, 'pas nul: boucle infinie');
      If ExprIsConst(E1) And ExprIsConst(E2) And ExprIsConst(E3) And
         (ExprConstReal(E2) <> 0) Then
      Begin
        If ExprConstReal(E2) > 0 Then
          Empty := ExprConstReal(E1) > ExprConstReal(E3)
        Else
          Empty := ExprConstReal(E1) < ExprConstReal(E3);
        If Empty Then
          WarnAt(Line, Col, 'boucle jamais executee (bornes inversees)');
      End;
    End;
  End
  Else If AtKw('while') Then
  Begin
    Kind := 3;
    ParserAdvance;
    Cd := ParseCondition;
    Good := Good And (Cd >= 0);
    If Good And Opts.DebugMode Then
    Begin
      WriteLn('  clause while :');
      WriteLn('    init :');  ExprDump(E1, 3);
      WriteLn('    while :'); ExprDump(Cd, 3);
    End;
    If (Cd >= 0) And (ExprTab[Cd].Kind = EX_BOOL) And
       (ExprTab[Cd].IntVal = 0) Then
      WarnAt(Line, Col, 'condition toujours fausse: ' +
             'boucle jamais executee');
  End
  Else If Good And Opts.DebugMode Then
  Begin
    WriteLn('  clause valeur :');
    ExprDump(E1, 2);
  End;

  { fin de la clause : cible des sauts "clause epuisee" }
  C.LEnd := NewLabel;
  If C.Count <= MAX_FOR_CLAUSES Then C.Next[C.Count] := C.LEnd
  Else ErrorAt(Line, Col, 'trop de clauses dans le for');
  If (Not Good) Or (Not C.Valid) Or (C.Count > MAX_FOR_CLAUSES) Then
    Exit;
  Multi := (C.Count > 1) Or AtPunct(',');

  Case Kind Of
    1:
      Begin
        ForAssign(C, E1);
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
    2:
      Begin
        Lnext := NewLabel;
        Ltest := NewLabel;
        C.Next[C.Count] := Lnext;
        ForAssign(C, E1);
        Emit1(OP_JMP, OpLabel(Ltest));
        EmitLabel(Lnext);
        { variable := variable + pas }
        Plus := ExprNew(EX_BINARY, TypeArith(C.VT, ExprTab[E2].Typ),
                        C.Line, C.Col);
        ExprTab[Plus].Op := '+';
        ExprTab[Plus].L  := ExprMakeVar(C.Sym, C.Line, C.Col);
        ExprTab[Plus].R  := E2;
        A := ExprNew(EX_ASSIGN, C.VT, C.Line, C.Col);
        ExprTab[A].L := ExprMakeVar(C.Sym, C.Line, C.Col);
        ExprTab[A].R := Plus;
        GenAssign(A, False);
        EmitLabel(Ltest);
        { clause epuisee quand la variable depasse la limite dans le
          sens du pas }
        If ExprIsConst(E2) Then
        Begin
          If ExprConstReal(E2) > 0 Then
            ForCompareJump(C, '>', E3, C.LEnd)
          Else
            ForCompareJump(C, '<', E3, C.LEnd);
        End
        Else
        Begin
          Lneg  := NewLabel;
          Lcont := NewLabel;
          Z  := ExprMakeInt(0, C.Line, C.Col);
          Sg := ExprNew(EX_BINARY, TY_IDX_BOOLEAN, C.Line, C.Col);
          ExprTab[Sg].Op := '>=';
          ExprTab[Sg].L  := E2;
          ExprTab[Sg].R  := Z;
          GenJump(Sg, Lneg, False);
          ForCompareJump(C, '>', E3, C.LEnd);
          Emit1(OP_JMP, OpLabel(Lcont));
          EmitLabel(Lneg);
          ForCompareJump(C, '<', E3, C.LEnd);
          EmitLabel(Lcont);
        End;
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
    3:
      Begin
        Lnext := NewLabel;
        C.Next[C.Count] := Lnext;
        EmitLabel(Lnext);
        ForAssign(C, E1);
        GenJump(Cd, C.LEnd, False);
        If Multi Then
          Emit(OP_MOV, ForSelCell(C), OpImm(C.Count));
        Emit1(OP_JMP, OpLabel(C.LBody));
      End;
  End;
End;

{ for v := e1, e2 step e3 until e4, e5 while c do instruction
  Chaque element de la liste est une valeur, un step-until ou un
  while ; ils sont executes dans l'ordre (le corps est partage). }
Procedure ParseFor;
Var
  Tgt       : Integer;
  Line, Col : Integer;
  Ctx       : TForCtx;
  K         : Integer;
Begin
  Inc(ForCount);
  FillChar(Ctx, SizeOf(Ctx), 0);
  Ctx.Sym := -1;
  Ctx.VT  := TY_UNKNOWN;
  Line := CurToken.Line;
  ParserAdvance;                          { for }
  ExprReset;
  Col := CurToken.Col;
  Tgt := ParsePrimary;
  If Tgt >= 0 Then
  Begin
    If ExprTab[Tgt].Kind <> EX_VAR Then
    Begin
      ErrorAt(Line, Col, 'variable de boucle simple attendue');
    End
    Else
    Begin
      Ctx.Sym := ExprTab[Tgt].Sym;
      Ctx.VT  := ExprTab[Tgt].Typ;
      If Not TypeIsNumeric(Ctx.VT) Then
      Begin
        ErrorAt(Line, Col, 'variable de boucle numerique attendue ' +
                '(type: ' + TypeName(Ctx.VT) + ')');
        Ctx.VT := TY_UNKNOWN;
      End
      Else
      Begin
        Ctx.Valid := True;
        If SymTab[Ctx.Sym].Kind = SK_PARAM_NAME Then
          SymTab[Ctx.Sym].IsWritten := True;      { variable de boucle }
        If Opts.DebugMode Then
          WriteLn('For ligne ', Line, ' : variable ',
                  SymTab[Ctx.Sym].Name, ' (', TypeName(Ctx.VT), ')');
      End;
    End;
  End;
  Ctx.Line := Line;
  Ctx.Col  := Col;
  If AtOp(':=') Then
    ParserAdvance
  Else
  Begin
    ParseError(''':='' attendu apres la variable de boucle');
    ParserSync;
    Exit;
  End;
  Ctx.LBody := NewLabel;
  Ctx.LExit := NewLabel;

  If LoopDepth >= MAX_LOOP_NEST Then
    ErrorAt(Line, Col, 'boucles trop imbriquees (max ' +
            ItoS(MAX_LOOP_NEST) + ')');
  Inc(LoopDepth);
  Repeat
    ParseForClause(Ctx);
    EmitLabel(Ctx.LEnd);                  { fin de la clause }
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  { toutes les clauses epuisees : sortie ; sinon le corps }
  Emit1(OP_JMP, OpLabel(Ctx.LExit));
  EmitLabel(Ctx.LBody);
  If AtKw('do') Then
    ParserAdvance
  Else
  Begin
    ParseError('''do'' attendu apres la liste du for');
    Dec(LoopDepth);
    ParserSync;
    Exit;
  End;
  ParseStatement;
  { retour a la clause active }
  If Ctx.Valid Then
  Begin
    If Ctx.Count <= 1 Then
      Emit1(OP_JMP, OpLabel(Ctx.Next[1]))
    Else
    Begin
      Emit(OP_MOV, OpReg(R_EAX), ForSelCell(Ctx));
      For K := 1 To Ctx.Count - 1 Do
      Begin
        Emit(OP_CMP, OpReg(R_EAX), OpImm(K));
        Emit1(OP_JE, OpLabel(Ctx.Next[K]));
      End;
      Emit1(OP_JMP, OpLabel(Ctx.Next[Ctx.Count]));
    End;
  End;
  EmitLabel(Ctx.LExit);
  Dec(LoopDepth);
End;

{ Borne de tableau : expression entiere. Une constante est retenue
  telle quelle ; sinon (Dyn = True) Node est l'arbre de la borne,
  evalue a l'execution par le generateur. }
Procedure ParseBound(Var V : LongInt; Var Dyn : Boolean;
                     Var Node : Integer);
Var
  N, Line, Col : Integer;
  Conv         : TConv;
Begin
  V    := 0;
  Node := -1;
  Line := CurToken.Line;
  Col  := CurToken.Col;
  N := ParseExpr;
  If N < 0 Then
  Begin
    Dyn := True;
    Exit;
  End;
  If Not ExprCoerce(N, TY_IDX_INTEGER, Conv, Line, Col) Then
  Begin
    Dyn := True;
    Exit;
  End;
  If ExprTab[N].Kind = EX_INT Then
    V := ExprTab[N].IntVal
  Else
  Begin
    Dyn  := True;
    Node := N;
  End;
End;

{ Octets d'un tableau a bornes constantes (0 et erreur si trop grand) }
Function ArrayBytes(S : Integer; Line, Col : Integer) : LongInt;
Var
  D        : Integer;
  Count, W : TWide;
Begin
  ArrayBytes := 0;
  Count := 1;
  For D := 1 To SymTab[S].ArrDims Do
  Begin
    Count := Count * (TWide(SymTab[S].ArrHi[D]) -
                      TWide(SymTab[S].ArrLo[D]) + 1);
    If Count > MAX_ARRAY_ELEMS Then
    Begin
      ErrorAt(Line, Col, 'tableau trop grand: ' + SymTab[S].Name);
      Exit;
    End;
  End;
  W := Count * TypeSizeof(SymTab[S].ElemType);
  If W > MAX_ARRAY_BYTES Then
  Begin
    ErrorAt(Line, Col, 'tableau trop grand: ' + SymTab[S].Name);
    Exit;
  End;
  ArrayBytes := W;
End;

{ [integer|real|Boolean] array a, b [lo:hi, lo:hi], c [lo:hi]
  Un tableau sans type est de type real (regle d Algol 60).
  Bornes constantes : donnees statiques (.data au niveau 0, cadre de
  la procedure sinon). Bornes variables : allocation sur le tas a
  l'execution. }
Procedure ParseArrayDecl(ElemType : Integer; IsOwn : Boolean);
Var
  Names      : Array[1..16] Of Integer;
  NLo, NHi   : Array[1..MAX_ARRAY_DIM] Of Integer;
  NName      : Integer;
  I, D       : Integer;
  Lo, Hi     : LongInt;
  DynD       : Boolean;
  Cur        : Integer;
  Line, Col  : Integer;
Begin
  Repeat
    ExprReset;
    NName := 0;
    Repeat
      If CurToken.Kind <> TK_IDENT Then
      Begin
        ParseError('nom de tableau attendu');
        ParserSync;
        Exit;
      End;
      If NName < 16 Then
      Begin
        Inc(NName);
        Names[NName] := SymAdd(CurToken.Val, SK_ARRAY, ElemType, IsOwn,
                               CurToken.Line, CurToken.Col);
        SymTab[Names[NName]].ElemType := ElemType;
        Inc(DeclCount);
      End
      Else
        ParseError('trop de noms dans une declaration de tableau');
      Line := CurToken.Line;
      Col  := CurToken.Col;
      ParserAdvance;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;

    If Not AtPunct('[') Then
    Begin
      ParseError('''['' attendu apres le nom du tableau');
      ParserSync;
      Exit;
    End;
    ParserAdvance;
    D := 0;
    For I := 1 To MAX_ARRAY_DIM Do
    Begin
      NLo[I] := -1;
      NHi[I] := -1;
    End;
    Repeat
      DynD := False;
      Inc(D);
      Lo := 0;
      Hi := 0;
      If D <= MAX_ARRAY_DIM Then
        ParseBound(Lo, DynD, NLo[D])
      Else
        ParseBound(Lo, DynD, I);
      If AtPunct(':') Then
        ParserAdvance
      Else
        ParseError(''':'' attendu entre les bornes');
      If D <= MAX_ARRAY_DIM Then
        ParseBound(Hi, DynD, NHi[D])
      Else
        ParseBound(Hi, DynD, I);
      If D <= MAX_ARRAY_DIM Then
        For I := 1 To NName Do
        Begin
          Cur := Names[I];
          SymTab[Cur].ArrDims := D;
          SymTab[Cur].ArrLo[D] := Lo;
          SymTab[Cur].ArrHi[D] := Hi;
          If DynD Then SymTab[Cur].ArrDynamic := True;
        End
      Else
        ParseError('trop de dimensions (max ' + ItoS(MAX_ARRAY_DIM) + ')');
      If (Not DynD) And (Lo > Hi) Then
        ErrorAt(CurToken.Line, CurToken.Col,
                'bornes inversees: ' + ItoS(Lo) + ':' + ItoS(Hi));
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
    ExpectPunct(']');

    { stockage des tableaux a bornes constantes }
    For I := 1 To NName Do
    Begin
      Cur := Names[I];
      If (Not SymTab[Cur].ArrDynamic) And (SymTab[Cur].ArrDims > 0) Then
      Begin
        SymTab[Cur].ArrBytes := ArrayBytes(Cur, Line, Col);
        If (CurLevel > 0) And (Not IsOwn) Then
          SymTab[Cur].ArrDataOfs := SymAllocLocal(SymTab[Cur].ArrBytes);
      End;
      If SymTab[Cur].ArrDynamic And IsOwn Then
        ErrorAt(Line, Col, 'les bornes d''un tableau own doivent etre ' +
                'constantes: ' + SymTab[Cur].Name);
      If SymTab[Cur].ArrDims > 0 Then
      Begin
        If SymTab[Cur].Storage = SC_LOCAL Then
          SymTab[Cur].ArrDescOfs :=
            SymAllocLocal(4 * (2 + 3 * SymTab[Cur].ArrDims));
        DataDeclareSym(Cur);
        GenArrayDecl(Cur, NLo, NHi);
        If SymTab[Cur].ArrDynamic And (Not IsOwn) Then
        Begin
          If DynCount >= MAX_DYN_ARR Then
            FatalError('trop de tableaux dynamiques ouverts (max ' +
                       ItoS(MAX_DYN_ARR) + ')');
          DynStack[DynCount] := Cur;
          Inc(DynCount);
        End;
      End;
      If Opts.DebugMode Then
      Begin
        Write('Tableau ', SymTab[Cur].Name, ' ', TypeName(ElemType),
              ' [', SymTab[Cur].ArrDims, ' dim.]');
        If SymTab[Cur].ArrDynamic Then
          WriteLn(' bornes a l''execution')
        Else
          WriteLn(' ', SymTab[Cur].ArrBytes, ' octets');
      End;
    End;
    If Opts.DebugMode Then
      For D := 1 To MAX_ARRAY_DIM Do
      Begin
        If NLo[D] >= 0 Then
        Begin
          WriteLn('  borne inf. dim ', D, ' :');
          ExprDump(NLo[D], 1);
        End;
        If NHi[D] >= 0 Then
        Begin
          WriteLn('  borne sup. dim ', D, ' :');
          ExprDump(NHi[D], 1);
        End;
      End;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
End;

{ Declaration de procedure : voir ParseProcDecl }
{ Specification d'un parametre : integer a, b ;  Boolean array t ;
  label, string, procedure, switch : specifications admises. }
Procedure ParseParamSpec(P : Integer);
Var
  T, Elem, S : Integer;
  HasT       : Boolean;
Begin
  T := TY_UNKNOWN;
  Elem := TY_IDX_REAL;
  HasT := False;
  If AtTypeKw Then
  Begin
    T := TypeFromKeyword(CurToken.Val);
    Elem := T;
    HasT := True;
    ParserAdvance;
  End;
  If AtKw('array') Then
  Begin
    T := TY_IDX_ARRAY;
    ParserAdvance;
  End
  Else If AtKw('procedure') Then
  Begin
    T := TY_IDX_PROCEDURE;
    { type du resultat d'une procedure formelle : celui de la
      specification, integer par defaut }
    If Not HasT Then Elem := TY_IDX_INTEGER;
    ParserAdvance;
  End
  Else If AtKw('switch') Then
  Begin
    T := TY_IDX_SWITCH;
    ParserAdvance;
  End
  Else If AtKw('label') Then
  Begin
    T := TY_IDX_LABEL;
    ParserAdvance;
  End;
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('nom de parametre attendu dans la specification');
      ParserSync;
      Exit;
    End;
    S := SymFindParam(P, CurToken.Val);
    If S < 0 Then
      ErrorAt(CurToken.Line, CurToken.Col,
              'specification d''un nom qui n''est pas un parametre: ' +
              CurToken.Val)
    Else
    Begin
      SymTab[S].TypeIdx := T;
      SymTab[S].ElemType := Elem;
      { une chaine est transmise par valeur (pointeur) }
      If T = TY_IDX_STRING Then SymTab[S].Kind := SK_PARAM_VALUE;
    End;
    ParserAdvance;
    If AtPunct(',') Then
      ParserAdvance
    Else
      Break;
  Until False;
  ExpectPunct(';');
End;

{ [type] procedure nom [(p1, p2)] ; [value p1, p2 ;] [specs] corps
  Le mot procedure est deja consomme. L entete et la table des
  symboles sont completes ; le corps est traduit puis ferme. }
Procedure ParseProcDecl(RetType : Integer; HasType : Boolean);
Var
  P, K, S : Integer;
  Kind    : TSymKind;
  PG      : TProcGen;
Begin
  If CurToken.Kind <> TK_IDENT Then
  Begin
    ParseError('nom de procedure attendu');
    ParserSync;
    Exit;
  End;
  If HasType Then
    Kind := SK_FUNC
  Else
  Begin
    Kind := SK_PROC;
    RetType := TY_IDX_PROCEDURE;
  End;
  P := SymAdd(CurToken.Val, Kind, RetType, False,
              CurToken.Line, CurToken.Col);
  Inc(DeclCount);
  Inc(ProcCount);
  ParserAdvance;
  SymEnterProc(P);

  If AtPunct('(') Then
  Begin
    ParserAdvance;
    If Not AtPunct(')') Then
      Repeat
        If CurToken.Kind <> TK_IDENT Then
        Begin
          ParseError('nom de parametre attendu');
          Break;
        End;
        SymAdd(CurToken.Val, SK_PARAM_NAME, TY_UNKNOWN, False,
               CurToken.Line, CurToken.Col);
        ParserAdvance;
        If AtPunct(',') Then
          ParserAdvance
        Else
          Break;
      Until False;
    ExpectPunct(')');
  End;
  ExpectPunct(';');

  If AtKw('value') Then
  Begin
    ParserAdvance;
    Repeat
      If CurToken.Kind <> TK_IDENT Then
      Begin
        ParseError('nom de parametre attendu apres value');
        Break;
      End;
      If Not SymMarkValue(P, CurToken.Val) Then
        ErrorAt(CurToken.Line, CurToken.Col,
                'value: ce n''est pas un parametre: ' + CurToken.Val);
      ParserAdvance;
      If AtPunct(',') Then
        ParserAdvance
      Else
        Break;
    Until False;
    ExpectPunct(';');
  End;

  While AtTypeKw Or AtKw('array') Or AtKw('switch') Or
        AtKw('procedure') Or AtKw('label') Do
    ParseParamSpec(P);

  { Parametre sans specification : integer par defaut }
  For K := 1 To SymTab[P].ParamCount Do
  Begin
    S := SymTab[P].ParamSym[K];
    If SymTab[S].TypeIdx = TY_UNKNOWN Then
    Begin
      WarnAt(SymTab[S].Line, SymTab[S].Col,
             'parametre sans specification: ' + SymTab[S].Name +
             ' (integer)');
      SymTab[S].TypeIdx := TY_IDX_INTEGER;
    End;
  End;
  SymLayoutParams(P);

  GenProcBegin(PG, P);
  ParseStatement;                { corps de la procedure }
  GenProcEnd(PG, P);
  SymLeaveScope;
End;

{ Declaration de variables : type nom, nom, ... ; own type nom, ... }
Procedure ParseVarList(K : TSymKind; T : Integer; IsOwn : Boolean);
Var
  Done : Boolean;
  S    : Integer;
Begin
  Repeat
    If CurToken.Kind <> TK_IDENT Then
    Begin
      ParseError('identificateur attendu dans la declaration');
      ParserSync;
      Exit;
    End;
    S := SymAdd(CurToken.Val, K, T, IsOwn, CurToken.Line, CurToken.Col);
    DataDeclareSym(S);
    Inc(DeclCount);
    ParserAdvance;
    Done := Not AtPunct(',');
    If Not Done Then ParserAdvance;
  Until Done;
End;

{ Declaration : [own] integer|real|boolean liste. Les tableaux, les
  switch et les procedures sont l'objet des TODO 14 a 16. }
Procedure ParseDeclaration;
Var
  IsOwn : Boolean;
  T     : Integer;
Begin
  IsOwn := AtKw('own');
  If IsOwn Then ParserAdvance;
  If AtKw('switch') And (Not IsOwn) Then
  Begin
    ParserAdvance;
    ParseSwitchDecl;
  End
  Else If AtKw('label') And (Not IsOwn) Then
  Begin
    ParserAdvance;
    ParseLabelDecl;
  End
  Else If AtKw('array') Then
  Begin
    ParserAdvance;                       { sans type : real (rapport) }
    ParseArrayDecl(TY_IDX_REAL, IsOwn);
  End
  Else If AtKw('procedure') Then
  Begin
    If IsOwn Then ParseError('own ne s''applique pas a une procedure');
    ParserAdvance;
    ParseProcDecl(TY_UNKNOWN, False);
  End
  Else If AtKw('integer') Or AtKw('real') Or AtKw('boolean') Then
  Begin
    T := TypeFromKeyword(CurToken.Val);
    ParserAdvance;
    If AtKw('array') Then
    Begin
      ParserAdvance;
      ParseArrayDecl(T, IsOwn);
    End
    Else If AtKw('procedure') Then
    Begin
      If IsOwn Then ParseError('own ne s''applique pas a une procedure');
      ParserAdvance;
      ParseProcDecl(T, True);
    End
    Else If IsOwn Then
      ParseVarList(SK_OWN, T, True)
    Else
      ParseVarList(SK_VAR, T, False);
  End
  Else
  Begin
    ParseError('declaration non disponible ou type attendu ' +
               '(variable, tableau, switch, label ou procedure)');
    ParserSync;
  End;
End;

{ Instruction : bloc, if, for, goto, affectation, appel, etiquette ;
  rien devant ';' 'end' ou 'else' (instruction vide). }
Procedure ParseStatement;
Begin
  If AtStmtEnd Then
    Exit
  Else If AtKw('begin') Then
    ParseBlock
  Else If AtKw('if') Then
    ParseIf
  Else If AtKw('for') Then
    ParseFor
  Else If AtKw('goto') Then
    ParseGoto
  Else If CurToken.Kind = TK_INTEGER Then
    ParseNumericStart
  Else If CurToken.Kind = TK_IDENT Then
    ParseIdentStatement
  Else If AtExprStart Then
    ParseExprStatement
  Else
  Begin
    ParseError('instruction attendue');
    ParserSync;
  End;
End;

{ Element d un bloc : declaration ou instruction. }
Procedure ParseItem;
Begin
  If AtDeclKw Then
    ParseDeclaration
  Else
    ParseStatement;
End;

{ begin item ; item ; ... end   (portee propre). Un bloc sans
  declaration est une instruction composee. }
Procedure ParseBlock;
Var
  Mark : Integer;
Begin
  Inc(BlockCount);
  ParserAdvance;                      { begin }
  SymEnterScope;
  Mark := DynCount;
  Repeat
    ParseItem;
    If AtPunct(';') Then
      ParserAdvance
    Else If AtKw('end') Or AtEOF Then
      Break
    Else
    Begin
      ParseError(''';'' ou ''end'' attendu');
      ParserSync;
      If AtPunct(';') Then ParserAdvance;
    End;
  Until False;
  If AtKw('end') Then
    ParserAdvance
  Else
    ParseError('''end'' attendu (begin non ferme)');
  { fin du bloc : liberation des tableaux a bornes variables }
  While DynCount > Mark Do
  Begin
    Dec(DynCount);
    GenFreeArray(DynStack[DynCount]);
  End;
  SymLeaveScope;
End;

{ Programme : un bloc begin ... end, suivi du point final facultatif }
Procedure ParseProgram;
Begin
  ParserAdvance;
  If AtEOF Then
  Begin
    ParseError('programme vide: ''begin'' attendu');
    Exit;
  End;
  If Not AtKw('begin') Then
  Begin
    ParseError('''begin'' attendu au debut du programme');
    Exit;
  End;
  ParseBlock;
  If AtPunct('.') Then ParserAdvance;
  If Not AtEOF Then
    ParseError('texte apres la fin du programme');
End;

{ Etiquettes jamais definies dans le programme : avertissement, puis
  definies a la fin du programme (un saut y termine donc le
  programme) ; test_lex.a60 en contient. }
Procedure ResolveUndefinedLabels;
Var
  I : Integer;
Begin
  For I := ScopeTab[0].FirstSym To SymCount - 1 Do
    If (SymTab[I].Kind = SK_LABEL) And (Not SymTab[I].IsDefined) Then
    Begin
      WarnAt(SymTab[I].Line, SymTab[I].Col,
             'etiquette non definie: ' + SymTab[I].Name +
             ' (saut vers la fin du programme)');
      SymTab[I].IsDefined  := True;
      SymTab[I].LevelKnown := True;
      SymTab[I].Level      := 0;
      EmitLabel(Intern(SymTab[I].Mangled));
      ResolveStubs(I);
    End;
End;

Procedure PhaseParse;
Begin
  ParserInit;
  DeclCount   := 0;
  BlockCount  := 0;
  AssignCount := 0;
  IfCount     := 0;
  ProcCount   := 0;
  CallCount   := 0;
  ThunkCount  := 0;
  IntrinCount := 0;
  IOCount     := 0;
  LabelCount  := 0;
  ForCount    := 0;
  GotoCount   := 0;
  DynCount    := 0;
  PendCount   := 0;
  LoopDepth   := 0;
  FoldCount   := 0;
  LexQuiet    := True;           { erreurs lexicales deja signalees }
  LexInit;
  CodeInit;
  SymEnterScope;                 { portee globale (identifiant 1) }
  GenMainBegin;
  ParseProgram;
  ResolveUndefinedLabels;
  GenMainEnd;
  SymLeaveScope;
  LexClose;
  If Opts.Verbose Then
    WriteLn('  ', DeclCount, ' declaration(s), ', ProcCount,
            ' procedure(s), ', BlockCount, ' bloc(s), ', CallCount,
            ' appel(s), ', ThunkCount, ' thunk(s), ', IOCount, ' e/s, ',
            IntrinCount, ' fonction(s) standard, ', AssignCount,
            ' affectation(s), ', IfCount, ' if, ',
            ForCount, ' for, ', GotoCount, ' goto, ', LabelCount,
            ' etiquette(s), ', FoldCount,
            ' constante(s) repliee(s)');
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
    DataDump;
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
Type
  TBinFixKind = (
    BF_REL32,      { deplacement relatif (cible externe) }
    BF_ABS32       { adresse absolue de Sym (+ valeur en place) }
  );

  TBinFix = Record
    Sect : Byte;           { 0 = code, 1 = donnees : ou se trouve le champ }
    Off  : LongInt;
    Kind : TBinFixKind;
    Sym  : Integer;        { nom (NameTab) de la cible }
  End;

  TBinLabel = Record
    Sect : Byte;           { 0 = non defini (externe), 1 = code, 2 = donnees }
    Off  : LongInt;
  End;

  { Resultat du codage d'une instruction }
  TEnc = Record
    Len     : Integer;
    B       : Array[0..15] Of Byte;
    NFix    : Integer;
    FixPos  : Array[1..2] Of Integer;
    FixSym  : Array[1..2] Of Integer;
    RelPos  : Integer;     { position du deplacement relatif (-1 : aucun) }
    RelSize : Integer;     { 1 ou 4 octets }
    RelSym  : Integer;     { etiquette cible }
  End;

Var
  BinCode     : Array[0..MAX_BIN_CODE - 1] Of Byte;
  BinCodeLen  : LongInt;
  BinData     : Array[0..MAX_BIN_DATA - 1] Of Byte;
  BinDataLen  : LongInt;
  BinLbl      : Array[0..MAX_NAMES - 1] Of TBinLabel;
  BinFix      : Array[0..MAX_BIN_FIX - 1] Of TBinFix;
  BinFixCount : LongInt;
  BinImport   : Array[0..255] Of Integer;     { noms importes (externes) }
  BinImportCount : Integer;
  InstrOff    : Array[0..2 * MAX_CODE] Of LongInt;
  InstrNear   : Array[0..2 * MAX_CODE - 1] Of Boolean;
  Enc         : TEnc;

Function InstrAt(I : LongInt) : TInstr;
Begin
  If I < CodeCount Then
    InstrAt := CodeTab[I]
  Else
    InstrAt := DeferTab[I - CodeCount];
End;

{ ---- Primitives de codage ---- }

Procedure PutB(V : LongInt);
Begin
  Enc.B[Enc.Len] := V And $FF;
  Inc(Enc.Len);
End;

Procedure PutD(V : LongInt);
Begin
  PutB(V);
  PutB(V Shr 8);
  PutB(V Shr 16);
  PutB(V Shr 24);
End;

Procedure PutW(V : LongInt);
Begin
  PutB(V);
  PutB(V Shr 8);
End;

{ Champ de 32 bits qui sera corrige par l'ecrivain (adresse de Sym) }
Procedure PutAbs(Sym : Integer; Addend : LongInt);
Begin
  Inc(Enc.NFix);
  Enc.FixPos[Enc.NFix] := Enc.Len;
  Enc.FixSym[Enc.NFix] := Sym;
  PutD(Addend);
End;

Function RegCode(R : TReg) : Integer;
Begin
  If R >= R_EAX Then
  Begin
    If R <= R_EDI Then
      RegCode := Ord(R) - Ord(R_EAX)
    Else If R = R_AX Then
      RegCode := 0
    Else
      RegCode := Ord(R) - Ord(R_AL);
  End
  Else
    RegCode := 0;
End;

Function RegSize(R : TReg) : Integer;
Begin
  If (R >= R_EAX) And (R <= R_EDI) Then
    RegSize := 4
  Else If R = R_AX Then
    RegSize := 2
  Else
    RegSize := 1;
End;

Function Fits8(V : LongInt) : Boolean;
Begin
  Fits8 := (V >= -128) And (V <= 127);
End;

Function ScaleBits(S : Byte) : Integer;
Begin
  Case S Of
    2 : ScaleBits := 1;
    4 : ScaleBits := 2;
    8 : ScaleBits := 3;
  Else
    ScaleBits := 0;
  End;
End;

{ ModRM (+ SIB + deplacement) pour un operande memoire }
Procedure EncMem(RegField : Integer; Const M : TOperand);
Var
  HasBase, HasIdx, HasSym : Boolean;
  Md, Bc                  : Integer;
Begin
  HasBase := M.Base <> R_NONE;
  HasIdx  := M.Index <> R_NONE;
  HasSym  := M.Sym >= 0;
  If (Not HasBase) And (Not HasIdx) Then
  Begin
    PutB((RegField Shl 3) Or 5);
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
    Exit;
  End;
  { choix du mode de deplacement }
  If HasSym Then
    Md := 2
  Else If (M.Imm = 0) And HasBase And (M.Base <> R_EBP) Then
    Md := 0
  Else If Fits8(M.Imm) Then
    Md := 1
  Else
    Md := 2;
  If Not HasBase Then
  Begin
    { [sym + index*scale + disp32] }
    PutB((RegField Shl 3) Or 4);
    PutB((ScaleBits(M.Scale) Shl 6) Or (RegCode(M.Index) Shl 3) Or 5);
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
    Exit;
  End;
  Bc := RegCode(M.Base);
  If HasIdx Then
  Begin
    PutB((Md Shl 6) Or (RegField Shl 3) Or 4);
    PutB((ScaleBits(M.Scale) Shl 6) Or (RegCode(M.Index) Shl 3) Or Bc);
  End
  Else If M.Base = R_ESP Then
  Begin
    PutB((Md Shl 6) Or (RegField Shl 3) Or 4);
    PutB($24);
  End
  Else
    PutB((Md Shl 6) Or (RegField Shl 3) Or Bc);
  If Md = 1 Then
    PutB(M.Imm)
  Else If Md = 2 Then
  Begin
    If HasSym Then PutAbs(M.Sym, M.Imm) Else PutD(M.Imm);
  End;
End;

{ ModRM pour un operande registre ou memoire (champ r/m) }
Procedure EncRM(RegField : Integer; Const O : TOperand);
Begin
  If O.Kind = OK_REG Then
    PutB($C0 Or (RegField Shl 3) Or RegCode(O.Reg))
  Else If O.Kind = OK_MEM Then
    EncMem(RegField, O)
  Else
    FatalError('encodeur: operande r/m invalide');
End;

{ Taille de l'operation : registre en priorite, sinon la memoire }
Function OpSize(Const A, B : TOperand) : Integer;
Begin
  If A.Kind = OK_REG Then
    OpSize := RegSize(A.Reg)
  Else If B.Kind = OK_REG Then
    OpSize := RegSize(B.Reg)
  Else If (A.Kind = OK_MEM) And (A.Size > 0) Then
    OpSize := A.Size
  Else If (B.Kind = OK_MEM) And (B.Size > 0) Then
    OpSize := B.Size
  Else
    OpSize := 4;
End;

Function CcOf(Op : TOp) : Integer;
Begin
  Case Op Of
    OP_SETE,  OP_JE  : CcOf := 4;
    OP_SETNE, OP_JNE : CcOf := 5;
    OP_SETL,  OP_JL  : CcOf := 12;
    OP_SETLE, OP_JLE : CcOf := 14;
    OP_SETG,  OP_JG  : CcOf := 15;
    OP_SETGE, OP_JGE : CcOf := 13;
    OP_SETA,  OP_JA  : CcOf := 7;
    OP_SETAE, OP_JAE : CcOf := 3;
    OP_SETB,  OP_JB  : CcOf := 2;
    OP_SETBE, OP_JBE : CcOf := 6;
    OP_JS            : CcOf := 8;
    OP_JNS           : CcOf := 9;
  Else
    CcOf := 0;
  End;
End;

Function AluNum(Op : TOp) : Integer;
Begin
  Case Op Of
    OP_ADD : AluNum := 0;
    OP_OR  : AluNum := 1;
    OP_AND : AluNum := 4;
    OP_SUB : AluNum := 5;
    OP_XOR : AluNum := 6;
    OP_CMP : AluNum := 7;
  Else
    AluNum := 0;
  End;
End;

Procedure EncBad(Const I : TInstr);
Begin
  FatalError('encodeur: forme d''instruction non supportee: ' +
             InstrText(I));
End;

{ ADD OR AND SUB XOR CMP }
Procedure EncAlu(Const I : TInstr);
Var
  N, Sz : Integer;
Begin
  N  := AluNum(I.Op);
  Sz := OpSize(I.A, I.B);
  If Sz = 2 Then PutB($66);
  If I.B.Kind = OK_IMM Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($80);
      EncRM(N, I.A);
      PutB(I.B.Imm);
    End
    Else If Fits8(I.B.Imm) Then
    Begin
      PutB($83);
      EncRM(N, I.A);
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($81);
      EncRM(N, I.A);
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind In [OK_REG, OK_MEM]) Then
  Begin
    { reg, r/m : opcode base + 2 (8 bits) ou + 3 }
    If Sz = 1 Then PutB(N * 8 + 2) Else PutB(N * 8 + 3);
    EncRM(RegCode(I.A.Reg), I.B);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB(N * 8) Else PutB(N * 8 + 1);
    EncMem(RegCode(I.B.Reg), I.A);
  End
  Else
    EncBad(I);
End;

Procedure EncMov(Const I : TInstr);
Var
  Sz : Integer;
Begin
  Sz := OpSize(I.A, I.B);
  If Sz = 2 Then PutB($66);
  If (I.A.Kind = OK_REG) And (I.B.Kind = OK_IMM) Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($B0 + RegCode(I.A.Reg));
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($B8 + RegCode(I.A.Reg));
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_OFFSET) Then
  Begin
    PutB($B8 + RegCode(I.A.Reg));
    PutAbs(I.B.Sym, I.B.Imm);
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB($88) Else PutB($89);
    PutB($C0 Or (RegCode(I.B.Reg) Shl 3) Or RegCode(I.A.Reg));
  End
  Else If (I.A.Kind = OK_REG) And (I.B.Kind = OK_MEM) Then
  Begin
    If Sz = 1 Then PutB($8A) Else PutB($8B);
    EncMem(RegCode(I.A.Reg), I.B);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_REG) Then
  Begin
    If Sz = 1 Then PutB($88) Else PutB($89);
    EncMem(RegCode(I.B.Reg), I.A);
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_IMM) Then
  Begin
    If Sz = 1 Then
    Begin
      PutB($C6);
      EncMem(0, I.A);
      PutB(I.B.Imm);
    End
    Else
    Begin
      PutB($C7);
      EncMem(0, I.A);
      If Sz = 2 Then PutW(I.B.Imm) Else PutD(I.B.Imm);
    End;
  End
  Else If (I.A.Kind = OK_MEM) And (I.B.Kind = OK_OFFSET) Then
  Begin
    PutB($C7);
    EncMem(0, I.A);
    PutAbs(I.B.Sym, I.B.Imm);
  End
  Else
    EncBad(I);
End;

{ Instructions a un seul operande r/m : IDIV DIV NEG NOT (F7 /n),
  INC DEC (FF /n ou 40+r / 48+r) }
Procedure EncUnary(Const I : TInstr; Digit : Integer);
Begin
  PutB($F7);
  EncRM(Digit, I.A);
End;

Procedure EncIncDec(Const I : TInstr; Digit : Integer);
Begin
  If (I.A.Kind = OK_REG) And (RegSize(I.A.Reg) = 4) Then
    PutB($40 + Digit * 8 + RegCode(I.A.Reg))
  Else
  Begin
    PutB($FF);
    EncRM(Digit, I.A);
  End;
End;

Procedure EncShift(Const I : TInstr; Digit : Integer);
Begin
  If I.B.Kind <> OK_IMM Then EncBad(I);
  If I.B.Imm = 1 Then
  Begin
    PutB($D1);
    EncRM(Digit, I.A);
  End
  Else
  Begin
    PutB($C1);
    EncRM(Digit, I.A);
    PutB(I.B.Imm);
  End;
End;

{ Instructions x87 a operande memoire ou ST(i) }
Procedure EncFpu(Const I : TInstr);
Var
  Sz, Digit, Op32, Op64, StOp : Integer;
  HasSt                      : Boolean;
Begin
  { Digit : champ /n ; Op32 / Op64 : opcodes memoire ; StOp : second
    octet (forme ST) = base + i }
  Digit := 0; Op32 := 0; Op64 := 0; StOp := -1;
  HasSt := (I.A.Kind = OK_ST);
  Case I.Op Of
    OP_FLD   :
      Begin
        If HasSt Then Begin PutB($D9); PutB($C0 + I.A.Imm); Exit; End;
        Digit := 0; Op32 := $D9; Op64 := $DD;
      End;
    OP_FST   :
      Begin
        If HasSt Then Begin PutB($DD); PutB($D0 + I.A.Imm); Exit; End;
        Digit := 2; Op32 := $D9; Op64 := $DD;
      End;
    OP_FSTP  :
      Begin
        If HasSt Then Begin PutB($DD); PutB($D8 + I.A.Imm); Exit; End;
        Digit := 3; Op32 := $D9; Op64 := $DD;
      End;
    OP_FILD  :
      Begin
        Sz := I.A.Size;
        If Sz = 2 Then PutB($DF) Else If Sz = 8 Then PutB($DF)
        Else PutB($DB);
        If Sz = 8 Then EncMem(5, I.A) Else EncMem(0, I.A);
        Exit;
      End;
    OP_FISTP :
      Begin
        Sz := I.A.Size;
        If Sz = 2 Then PutB($DF) Else If Sz = 8 Then PutB($DF)
        Else PutB($DB);
        If Sz = 8 Then EncMem(7, I.A) Else EncMem(3, I.A);
        Exit;
      End;
    OP_FADD, OP_FMUL, OP_FSUB, OP_FSUBR, OP_FDIV, OP_FDIVR,
    OP_FCOM, OP_FCOMP:
      Begin
        Case I.Op Of
          OP_FADD  : Digit := 0;
          OP_FMUL  : Digit := 1;
          OP_FCOM  : Digit := 2;
          OP_FCOMP : Digit := 3;
          OP_FSUB  : Digit := 4;
          OP_FSUBR : Digit := 5;
          OP_FDIV  : Digit := 6;
          OP_FDIVR : Digit := 7;
        End;
        If HasSt Then
        Begin
          If I.Op = OP_FCOM Then
          Begin
            PutB($D8); PutB($D0 + I.A.Imm); Exit;
          End;
          If I.Op = OP_FCOMP Then
          Begin
            PutB($D8); PutB($D8 + I.A.Imm); Exit;
          End;
          { forme ST(i), ST(0) : DC + base }
          PutB($DC);
          Case I.Op Of
            OP_FADD  : PutB($C0 + I.A.Imm);
            OP_FMUL  : PutB($C8 + I.A.Imm);
            OP_FSUBR : PutB($E0 + I.A.Imm);
            OP_FSUB  : PutB($E8 + I.A.Imm);
            OP_FDIVR : PutB($F0 + I.A.Imm);
            OP_FDIV  : PutB($F8 + I.A.Imm);
          End;
          Exit;
        End;
        Op32 := $D8; Op64 := $DC;
      End;
    OP_FNSTCW: Begin PutB($D9); EncMem(7, I.A); Exit; End;
    OP_FLDCW : Begin PutB($D9); EncMem(5, I.A); Exit; End;
    OP_FXCH  : Begin PutB($D9); PutB($C8 + I.A.Imm); Exit; End;
    OP_FADDP : Begin PutB($DE); PutB($C0 + I.A.Imm); Exit; End;
    OP_FMULP : Begin PutB($DE); PutB($C8 + I.A.Imm); Exit; End;
    OP_FSUBP : Begin PutB($DE); PutB($E8 + I.A.Imm); Exit; End;
    OP_FDIVP : Begin PutB($DE); PutB($F8 + I.A.Imm); Exit; End;
    OP_FNSTSW: Begin PutB($DF); PutB($E0); Exit; End;
  End;
  If I.A.Kind <> OK_MEM Then EncBad(I);
  If I.A.Size = 4 Then
  Begin
    PutB(Op32);
    EncMem(Digit, I.A);
  End
  Else If I.A.Size = 8 Then
  Begin
    PutB(Op64);
    EncMem(Digit, I.A);
  End
  Else
    EncBad(I);
  StOp := StOp + 0;
End;

Procedure EncodeInstr(Const I : TInstr; Near : Boolean);
Var
  Sz, Cc : Integer;
Begin
  Enc.Len := 0;
  Enc.NFix := 0;
  Enc.RelPos := -1;
  Enc.RelSize := 0;
  Enc.RelSym := -1;
  Case I.Op Of
    OP_NOP, OP_LABEL, OP_COMMENT, OP_BLANK: ;
    OP_MOV : EncMov(I);
    OP_MOVZX:
      Begin
        If (I.B.Kind = OK_REG) And (RegSize(I.B.Reg) = 1) Or
           ((I.B.Kind = OK_MEM) And (I.B.Size = 1)) Then
        Begin
          PutB($0F); PutB($B6);
        End
        Else
        Begin
          PutB($0F); PutB($B7);
        End;
        EncRM(RegCode(I.A.Reg), I.B);
      End;
    OP_LEA :
      Begin
        PutB($8D);
        EncMem(RegCode(I.A.Reg), I.B);
      End;
    OP_PUSH:
      Case I.A.Kind Of
        OK_REG    : PutB($50 + RegCode(I.A.Reg));
        OK_IMM    :
          If Fits8(I.A.Imm) Then
          Begin
            PutB($6A); PutB(I.A.Imm);
          End
          Else
          Begin
            PutB($68); PutD(I.A.Imm);
          End;
        OK_OFFSET : Begin PutB($68); PutAbs(I.A.Sym, I.A.Imm); End;
        OK_MEM    : Begin PutB($FF); EncMem(6, I.A); End;
      Else
        EncBad(I);
      End;
    OP_POP :
      If I.A.Kind = OK_REG Then
        PutB($58 + RegCode(I.A.Reg))
      Else
      Begin
        PutB($8F);
        EncRM(0, I.A);
      End;
    OP_ADD, OP_SUB, OP_AND, OP_OR, OP_XOR, OP_CMP: EncAlu(I);
    OP_IMUL:
      If I.B.Kind = OK_IMM Then
      Begin
        If Fits8(I.B.Imm) Then
        Begin
          PutB($6B); PutB($C0 Or (RegCode(I.A.Reg) Shl 3) Or
                          RegCode(I.A.Reg)); PutB(I.B.Imm);
        End
        Else
        Begin
          PutB($69); PutB($C0 Or (RegCode(I.A.Reg) Shl 3) Or
                          RegCode(I.A.Reg)); PutD(I.B.Imm);
        End;
      End
      Else
      Begin
        PutB($0F); PutB($AF);
        EncRM(RegCode(I.A.Reg), I.B);
      End;
    OP_IDIV: EncUnary(I, 7);
    OP_DIV : EncUnary(I, 6);
    OP_NEG : EncUnary(I, 3);
    OP_NOT : EncUnary(I, 2);
    OP_CDQ : PutB($99);
    OP_INC : EncIncDec(I, 0);
    OP_DEC : EncIncDec(I, 1);
    OP_TEST:
      Begin
        Sz := OpSize(I.A, I.B);
        If I.B.Kind = OK_IMM Then
        Begin
          If Sz = 1 Then PutB($F6) Else PutB($F7);
          EncRM(0, I.A);
          If Sz = 1 Then PutB(I.B.Imm) Else PutD(I.B.Imm);
        End
        Else
        Begin
          If Sz = 1 Then PutB($84) Else PutB($85);
          EncRM(RegCode(I.B.Reg), I.A);
        End;
      End;
    OP_SHL : EncShift(I, 4);
    OP_SHR : EncShift(I, 5);
    OP_SAR : EncShift(I, 7);
    OP_SETE, OP_SETNE, OP_SETL, OP_SETLE, OP_SETG, OP_SETGE, OP_SETA,
    OP_SETAE, OP_SETB, OP_SETBE:
      Begin
        PutB($0F); PutB($90 + CcOf(I.Op));
        EncRM(0, I.A);
      End;
    OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG, OP_JGE, OP_JA, OP_JAE,
    OP_JB, OP_JBE, OP_JS, OP_JNS:
      Begin
        If I.A.Kind = OK_LABEL Then
        Begin
          Enc.RelSym := I.A.Sym;
          If I.Op = OP_JMP Then
          Begin
            If Near Then
            Begin
              PutB($E9); Enc.RelPos := Enc.Len; Enc.RelSize := 4; PutD(0);
            End
            Else
            Begin
              PutB($EB); Enc.RelPos := Enc.Len; Enc.RelSize := 1; PutB(0);
            End;
          End
          Else
          Begin
            Cc := CcOf(I.Op);
            If Near Then
            Begin
              PutB($0F); PutB($80 + Cc);
              Enc.RelPos := Enc.Len; Enc.RelSize := 4; PutD(0);
            End
            Else
            Begin
              PutB($70 + Cc);
              Enc.RelPos := Enc.Len; Enc.RelSize := 1; PutB(0);
            End;
          End;
        End
        Else If I.Op = OP_JMP Then
        Begin
          PutB($FF);
          EncRM(4, I.A);
        End
        Else
          EncBad(I);
      End;
    OP_CALL:
      If I.A.Kind = OK_LABEL Then
      Begin
        PutB($E8);
        Enc.RelSym := I.A.Sym;
        Enc.RelPos := Enc.Len;
        Enc.RelSize := 4;
        PutD(0);
      End
      Else
      Begin
        PutB($FF);
        EncRM(2, I.A);
      End;
    OP_RET :
      If I.A.Kind = OK_IMM Then
      Begin
        PutB($C2); PutW(I.A.Imm);
      End
      Else
        PutB($C3);
    OP_REP_STOSD: Begin PutB($F3); PutB($AB); End;
    OP_FLD, OP_FST, OP_FSTP, OP_FILD, OP_FISTP, OP_FADD, OP_FSUB,
    OP_FSUBR, OP_FMUL, OP_FDIV, OP_FDIVR, OP_FCOM, OP_FCOMP, OP_FNSTCW,
    OP_FLDCW, OP_FXCH, OP_FADDP, OP_FSUBP, OP_FMULP, OP_FDIVP,
    OP_FNSTSW: EncFpu(I);
    OP_FCHS   : Begin PutB($D9); PutB($E0); End;
    OP_FABS   : Begin PutB($D9); PutB($E1); End;
    OP_FTST   : Begin PutB($D9); PutB($E4); End;
    OP_FLD1   : Begin PutB($D9); PutB($E8); End;
    OP_FLDL2E : Begin PutB($D9); PutB($EA); End;
    OP_FLDLN2 : Begin PutB($D9); PutB($ED); End;
    OP_FLDZ   : Begin PutB($D9); PutB($EE); End;
    OP_F2XM1  : Begin PutB($D9); PutB($F0); End;
    OP_FYL2X  : Begin PutB($D9); PutB($F1); End;
    OP_FPATAN : Begin PutB($D9); PutB($F3); End;
    OP_FRNDINT: Begin PutB($D9); PutB($FC); End;
    OP_FSCALE : Begin PutB($D9); PutB($FD); End;
    OP_FSQRT  : Begin PutB($D9); PutB($FA); End;
    OP_FSIN   : Begin PutB($D9); PutB($FE); End;
    OP_FCOS   : Begin PutB($D9); PutB($FF); End;
    OP_SAHF   : PutB($9E);
  Else
    EncBad(I);
  End;
End;

{ ---- Donnees ---- }

Procedure DataByte(V : LongInt);
Begin
  If BinDataLen >= MAX_BIN_DATA Then
    FatalError('segment de donnees trop grand');
  BinData[BinDataLen] := V And $FF;
  Inc(BinDataLen);
End;

Procedure DataDword(V : LongInt);
Begin
  DataByte(V);
  DataByte(V Shr 8);
  DataByte(V Shr 16);
  DataByte(V Shr 24);
End;

Procedure AddFix(Sect : Byte; Off : LongInt; Kind : TBinFixKind;
                 Sym : Integer);
Begin
  If BinFixCount >= MAX_BIN_FIX Then
    FatalError('trop de relocations (max ' + ItoS(MAX_BIN_FIX) + ')');
  BinFix[BinFixCount].Sect := Sect;
  BinFix[BinFixCount].Off  := Off;
  BinFix[BinFixCount].Kind := Kind;
  BinFix[BinFixCount].Sym  := Sym;
  Inc(BinFixCount);
End;

Procedure EncodeData;
Var
  I, J, N : Integer;
  S       : TString;
Begin
  For I := 0 To DataCount - 1 Do
  Begin
    While (BinDataLen And 3) <> 0 Do DataByte(0);
    BinLbl[DataTab[I].Name].Sect := 2;
    BinLbl[DataTab[I].Name].Off  := BinDataLen;
    Case DataTab[I].Kind Of
      DK_ZERO :
        For J := 1 To (DataTab[I].Size + 3) Div 4 Do DataDword(0);
      DK_STR  :
        Begin
          S := AsmStrs[DataTab[I].Str];
          For J := 1 To Length(S) Do DataByte(Ord(S[J]));
          DataByte(0);
        End;
      DK_INT  : DataDword(DataTab[I].Lo);
      DK_REAL :
        Begin
          DataDword(DataTab[I].Lo);
          DataDword(DataTab[I].Hi);
        End;
      DK_TABLE:
        For J := 0 To DataTab[I].Count - 1 Do
        Begin
          N := TabEnt[DataTab[I].First + J];
          AddFix(1, BinDataLen, BF_ABS32, N);
          DataDword(0);
        End;
    End;
  End;
  While (BinDataLen And 3) <> 0 Do DataByte(0);
End;

{ ---- Code : mise en page et emission ---- }

Function IsRelJump(Const I : TInstr) : Boolean;
Begin
  IsRelJump := (I.Op In [OP_JMP, OP_JE, OP_JNE, OP_JL, OP_JLE, OP_JG,
                         OP_JGE, OP_JA, OP_JAE, OP_JB, OP_JBE, OP_JS,
                         OP_JNS]) And (I.A.Kind = OK_LABEL);
End;

Procedure AddImport(Sym : Integer);
Var
  K : Integer;
Begin
  For K := 0 To BinImportCount - 1 Do
    If BinImport[K] = Sym Then Exit;
  If BinImportCount > 255 Then FatalError('trop d''imports');
  BinImport[BinImportCount] := Sym;
  Inc(BinImportCount);
End;

Procedure EncodeCode;
Var
  N, I, K       : LongInt;
  Off           : LongInt;
  Changed       : Boolean;
  Ins           : TInstr;
  Disp, Target  : LongInt;
  Sym           : Integer;
Begin
  N := CodeCount + DeferCount;
  For I := 0 To N - 1 Do InstrNear[I] := False;
  { sauts courts d'abord ; agrandis tant qu'un deplacement deborde }
  Repeat
    Changed := False;
    Off := 0;
    For I := 0 To N - 1 Do
    Begin
      InstrOff[I] := Off;
      Ins := InstrAt(I);
      If Ins.Op = OP_LABEL Then
      Begin
        BinLbl[Ins.A.Sym].Sect := 1;
        BinLbl[Ins.A.Sym].Off  := Off;
      End
      Else
      Begin
        EncodeInstr(Ins, InstrNear[I]);
        Off := Off + Enc.Len;
      End;
    End;
    InstrOff[N] := Off;
    For I := 0 To N - 1 Do
    Begin
      Ins := InstrAt(I);
      If IsRelJump(Ins) And (Not InstrNear[I]) Then
      Begin
        Sym := Ins.A.Sym;
        If BinLbl[Sym].Sect <> 1 Then
        Begin
          InstrNear[I] := True;            { cible externe : rel32 }
          Changed := True;
        End
        Else
        Begin
          Disp := BinLbl[Sym].Off - (InstrOff[I] + 2);
          If Not Fits8(Disp) Then
          Begin
            InstrNear[I] := True;
            Changed := True;
          End;
        End;
      End;
    End;
  Until Not Changed;

  { emission }
  BinCodeLen := 0;
  For I := 0 To N - 1 Do
  Begin
    Ins := InstrAt(I);
    EncodeInstr(Ins, InstrNear[I]);
    If BinCodeLen + Enc.Len > MAX_BIN_CODE Then
      FatalError('code binaire trop grand');
    For K := 0 To Enc.Len - 1 Do
      BinCode[BinCodeLen + K] := Enc.B[K];
    For K := 1 To Enc.NFix Do
      AddFix(0, BinCodeLen + Enc.FixPos[K], BF_ABS32, Enc.FixSym[K]);
    If Enc.RelPos >= 0 Then
    Begin
      Sym := Enc.RelSym;
      If BinLbl[Sym].Sect = 1 Then
      Begin
        Target := BinLbl[Sym].Off;
        Disp := Target - (BinCodeLen + Enc.Len);
        For K := 0 To Enc.RelSize - 1 Do
          BinCode[BinCodeLen + Enc.RelPos + K] := (Disp Shr (8 * K)) And $FF;
      End
      Else If BinLbl[Sym].Sect = 0 Then
      Begin
        If Enc.RelSize <> 4 Then
          FatalError('encodeur: saut court vers une cible externe');
        AddFix(0, BinCodeLen + Enc.RelPos, BF_REL32, Sym);
        AddImport(Sym);
      End
      Else
        FatalError('encodeur: saut vers une donnee: ' + NameTab[Sym]);
    End;
    BinCodeLen := BinCodeLen + Enc.Len;
  End;
End;

{ Verifie que chaque symbole reference par une adresse absolue est
  defini (code ou donnees) }
Procedure CheckFixups;
Var
  I : LongInt;
Begin
  For I := 0 To BinFixCount - 1 Do
    If (BinFix[I].Kind = BF_ABS32) And (BinLbl[BinFix[I].Sym].Sect = 0) Then
      FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
End;

Procedure EncodeProgram;
Var
  I : LongInt;
Begin
  For I := 0 To NameCount - 1 Do
  Begin
    BinLbl[I].Sect := 0;
    BinLbl[I].Off  := 0;
  End;
  BinDataLen := 0;
  BinFixCount := 0;
  BinImportCount := 0;
  EncodeData;
  EncodeCode;
  CheckFixups;
End;

Function Hex8(V : LongInt) : TString;
Var
  R : TString;
  I : Integer;
Begin
  R := '';
  For I := 1 To 8 Do
  Begin
    R := Copy('0123456789ABCDEF', (V And 15) + 1, 1) + R;
    V := (V Shr 4) And $0FFFFFFF;
  End;
  Hex8 := R;
End;

{ Listing hexadecimal du code (mode -d) : decalage, octets, texte }
Procedure WriteBinListing(Const FileName : TString);
Var
  F        : Text;
  I, K     : LongInt;
  Ins      : TInstr;
  S        : TString;
Begin
  Assign(F, FileName);
  Rewrite(F);
  If IOResult <> 0 Then Exit;
  NoteOutput(FileName);
  For I := 0 To CodeCount + DeferCount - 1 Do
  Begin
    Ins := InstrAt(I);
    Case Ins.Op Of
      OP_LABEL   : WriteLn(F, '        ', NameTab[Ins.A.Sym], ':');
      OP_COMMENT, OP_BLANK, OP_NOP : ;
    Else
      Begin
        { octets definitifs (deplacements resolus, adresses a zero) }
        S := '';
        For K := InstrOff[I] To InstrOff[I + 1] - 1 Do
          S := S + Copy('0123456789ABCDEF', (BinCode[K] Shr 4) + 1, 1) +
               Copy('0123456789ABCDEF', (BinCode[K] And 15) + 1, 1) + ' ';
        While Length(S) < 30 Do S := S + ' ';
        WriteLn(F, Hex8(InstrOff[I]), '  ', S, InstrText(Ins));
      End;
    End;
  End;
  Close(F);
End;

Procedure PhaseEncode;
Begin
  EncodeProgram;
  If Opts.Verbose Then
    WriteLn('  .text : ', BinCodeLen, ' octets, .data : ', BinDataLen,
            ' octets, ', BinFixCount, ' relocation(s), ', BinImportCount,
            ' import(s)');
  If Opts.DebugMode Then
    WriteBinListing(ReplaceExt(Opts.OutFile, '.lst'));
End;

{ ============================================================
  SECTION 11 - ECRIVAINS PE (.EXE) ET COFF (.OBJ) (TODO 20, 21)
  ============================================================ }
{ ---- Ecrivain PE : executable Windows 32 bits console (TODO 20) ----
  Disposition (alignement fichier 512, alignement memoire 4096) :
    en-tetes (MZ, PE, COFF, optionnel, 3 sections) a 0x000
    .text   RVA 0x1000 : code + une souche JMP [IAT] par import
    .data   : donnees (variables, constantes, tables)
    .idata  : table d'importation de kernel32.dll (ILT, IAT, noms)
  Pas de table de relocation : l'image est chargee a PE_IMG_BASE. }
Const
  PE_MAX_FILE = {$IFDEF FPC}1500000{$ELSE}20000{$ENDIF};
  PE_HDR_SIZE = $200;

Var
  PeOut : Array[0..PE_MAX_FILE - 1] Of Byte;

Function AlignUp(V, A : LongInt) : LongInt;
Begin
  AlignUp := ((V + A - 1) Div A) * A;
End;

Procedure PeB(Pos : LongInt; V : LongInt);
Begin
  If (Pos < 0) Or (Pos >= PE_MAX_FILE) Then
    FatalError('executable trop grand');
  PeOut[Pos] := V And $FF;
End;

Procedure PeW(Pos : LongInt; V : LongInt);
Begin
  PeB(Pos, V);
  PeB(Pos + 1, V Shr 8);
End;

Procedure PeD(Pos : LongInt; V : TWide);
Begin
  PeB(Pos, V And $FF);
  PeB(Pos + 1, (V Shr 8) And $FF);
  PeB(Pos + 2, (V Shr 16) And $FF);
  PeB(Pos + 3, (V Shr 24) And $FF);
End;

Function PeGetD(Pos : LongInt) : LongInt;
Begin
  PeGetD := PeOut[Pos] Or (PeOut[Pos + 1] Shl 8) Or
            (PeOut[Pos + 2] Shl 16) Or (PeOut[Pos + 3] Shl 24);
End;

Procedure PeStr(Pos : LongInt; Const S : TString);
Var
  I : Integer;
Begin
  For I := 1 To Length(S) Do PeB(Pos + I - 1, Ord(S[I]));
End;

{ En-tete de section : nom, taille virtuelle, RVA, taille et position
  dans le fichier, caracteristiques }
Procedure PeSection(Pos : LongInt; Const Name : TString; VSize, RVA,
                    RawSize, RawPtr : LongInt; Flags : TWide);
Begin
  PeStr(Pos, Name);
  PeD(Pos + 8, VSize);
  PeD(Pos + 12, RVA);
  PeD(Pos + 16, RawSize);
  PeD(Pos + 20, RawPtr);
  PeD(Pos + 36, Flags);
End;

Procedure WritePE(Const FileName : TString);
Var
  ImpName    : Array[0..255] Of TString;
  I, K       : LongInt;
  Nm         : TString;
  TextLen, StubOff, DataLen, IdataLen : LongInt;
  DescOff, IltOff, IatOff, HintOff, DllOff, P : LongInt;
  HintPos    : Array[0..255] Of LongInt;
  TextRVA, DataRVA, IdataRVA, ImageSize : LongInt;
  TextRaw, DataRaw, IdataRaw, FileSize  : LongInt;
  TextRawSz, DataRawSz, IdataRawSz      : LongInt;
  Entry      : LongInt;
  Where      : LongInt;
  Target     : TWide;
  F          : File;
  Written    : LongInt;
  MainSym    : Integer;
Begin
  { imports : toute cible non definie qui n'est pas du runtime }
  For I := 0 To BinImportCount - 1 Do
  Begin
    Nm := NameTab[BinImport[I]];
    If Copy(Nm, 1, 4) = '_A60' Then
      FatalError('symbole non defini: ' + Nm +
                 ' (routine du runtime absente)');
    ImpName[I] := Nm;
  End;
  MainSym := Intern(A60_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A60_MAIN_NAME + ' introuvable');
  Entry := BinLbl[MainSym].Off;

  { tailles des sections }
  StubOff := AlignUp(BinCodeLen, 4);
  TextLen := StubOff + 8 * BinImportCount;
  If TextLen = 0 Then TextLen := 4;
  DataLen := BinDataLen;
  If DataLen = 0 Then DataLen := 4;
  K := BinImportCount;
  DescOff := 0;
  IltOff  := 40;
  IatOff  := IltOff + 4 * (K + 1);
  HintOff := IatOff + 4 * (K + 1);
  P := HintOff;
  For I := 0 To K - 1 Do
  Begin
    HintPos[I] := P;
    P := P + AlignUp(2 + Length(ImpName[I]) + 1, 2);
  End;
  DllOff := P;
  IdataLen := DllOff + Length('kernel32.dll') + 1;

  TextRVA   := $1000;
  DataRVA   := TextRVA + AlignUp(TextLen, PE_SEC_ALIGN);
  IdataRVA  := DataRVA + AlignUp(DataLen, PE_SEC_ALIGN);
  ImageSize := IdataRVA + AlignUp(IdataLen, PE_SEC_ALIGN);
  TextRaw   := PE_HDR_SIZE;
  TextRawSz := AlignUp(TextLen, PE_FILE_ALIGN);
  DataRaw   := TextRaw + TextRawSz;
  DataRawSz := AlignUp(DataLen, PE_FILE_ALIGN);
  IdataRaw  := DataRaw + DataRawSz;
  IdataRawSz := AlignUp(IdataLen, PE_FILE_ALIGN);
  FileSize  := IdataRaw + IdataRawSz;
  If FileSize > PE_MAX_FILE Then FatalError('executable trop grand');
  FillChar(PeOut, FileSize, 0);

  { contenu des sections }
  For I := 0 To BinCodeLen - 1 Do PeOut[TextRaw + I] := BinCode[I];
  For I := 0 To BinDataLen - 1 Do PeOut[DataRaw + I] := BinData[I];
  { souches : JMP DWORD PTR [IAT + 4*i] }
  For I := 0 To K - 1 Do
  Begin
    P := TextRaw + StubOff + 8 * I;
    PeB(P, $FF);
    PeB(P + 1, $25);
    PeD(P + 2, TWide(PE_IMG_BASE) + IdataRVA + IatOff + 4 * I);
    PeB(P + 6, $CC);
    PeB(P + 7, $CC);
  End;

  { relocations : adresses absolues et appels vers les imports }
  For I := 0 To BinFixCount - 1 Do
  Begin
    If BinFix[I].Sect = 0 Then
      Where := TextRaw + BinFix[I].Off
    Else
      Where := DataRaw + BinFix[I].Off;
    If BinFix[I].Kind = BF_ABS32 Then
    Begin
      Case BinLbl[BinFix[I].Sym].Sect Of
        1 : Target := TWide(PE_IMG_BASE) + TextRVA +
                      BinLbl[BinFix[I].Sym].Off;
        2 : Target := TWide(PE_IMG_BASE) + DataRVA +
                      BinLbl[BinFix[I].Sym].Off;
      Else
        FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
      End;
      PeD(Where, Target + PeGetD(Where));
    End
    Else
    Begin
      { appel d'un import : deplacement vers sa souche }
      K := -1;
      For P := 0 To BinImportCount - 1 Do
        If BinImport[P] = BinFix[I].Sym Then K := P;
      If K < 0 Then FatalError('import inconnu');
      Target := TextRVA + StubOff + 8 * K;
      PeD(Where, Target - (TextRVA + BinFix[I].Off + 4));
    End;
  End;

  { table d'importation (kernel32.dll) }
  K := BinImportCount;
  P := IdataRaw;
  If K > 0 Then
  Begin
    PeD(P + DescOff,      IdataRVA + IltOff);        { OriginalFirstThunk }
    PeD(P + DescOff + 12, IdataRVA + DllOff);        { Name }
    PeD(P + DescOff + 16, IdataRVA + IatOff);        { FirstThunk }
    For I := 0 To K - 1 Do
    Begin
      PeD(P + IltOff + 4 * I, IdataRVA + HintPos[I]);
      PeD(P + IatOff + 4 * I, IdataRVA + HintPos[I]);
      PeW(P + HintPos[I], 0);
      PeStr(P + HintPos[I] + 2, ImpName[I]);
    End;
    PeStr(P + DllOff, 'kernel32.dll');
  End;

  { en-tete DOS + souche }
  PeW(0, $5A4D);
  PeW(2, $0090);
  PeW(4, 3);
  PeW(8, 4);
  PeW(12, $FFFF);
  PeW(16, $00B8);
  PeW(24, $0040);
  PeD($3C, $80);
  PeStr($40, #$0E#$1F#$BA#$0E#$00#$B4#$09#$CD#$21#$B8#$01#$4C#$CD#$21);
  PeStr($4E, 'This program cannot be run in DOS mode.'#13#13#10'$');
  { signature PE et en-tete COFF }
  PeD($80, PE_SIGNATURE);
  PeW($84, PE_MACHINE_I386);
  PeW($86, 3);                                      { sections }
  PeW($94, PE_OPT_SIZE);
  PeW($96, PE_FILE_EXE Or PE_FILE_32BIT Or $0001 Or $0004 Or $0008);
  { en-tete optionnel }
  PeW($98, PE_MAGIC_32);
  PeB($9A, 1);
  PeD($9C, AlignUp(TextLen, PE_FILE_ALIGN));         { SizeOfCode }
  PeD($A0, DataRawSz + IdataRawSz);                  { SizeOfInitializedData }
  PeD($A8, TextRVA + Entry);                         { AddressOfEntryPoint }
  PeD($AC, TextRVA);
  PeD($B0, DataRVA);
  PeD($B4, PE_IMG_BASE);
  PeD($B8, PE_SEC_ALIGN);
  PeD($BC, PE_FILE_ALIGN);
  PeW($C0, 4);                                       { version du systeme }
  PeW($C8, 4);                                       { sous-systeme }
  PeD($D0, ImageSize);
  PeD($D4, PE_HDR_SIZE);
  PeW($DC, PE_SUBSYS_CUI);
  PeD($E0, $100000);                                 { pile reservee }
  PeD($E4, $1000);
  PeD($E8, $100000);                                 { tas reserve }
  PeD($EC, $1000);
  PeD($F4, 16);                                      { repertoires }
  PeD($F8 + 8, IdataRVA + DescOff);                  { import }
  PeD($F8 + 12, 40);
  PeD($F8 + 12 * 8, IdataRVA + IatOff);              { IAT }
  PeD($F8 + 12 * 8 + 4, 4 * (BinImportCount + 1));
  { table des sections }
  PeSection($178,       '.text',  TextLen,  TextRVA,  TextRawSz,  TextRaw,
            PE_SCN_TEXT);
  PeSection($178 + 40,  '.data',  DataLen,  DataRVA,  DataRawSz,  DataRaw,
            PE_SCN_DATA);
  PeSection($178 + 80,  '.idata', IdataLen, IdataRVA, IdataRawSz, IdataRaw,
            PE_SCN_DATA);

  Assign(F, FileName);
  Rewrite(F, 1);
  If IOResult <> 0 Then FatalError('impossible de creer ' + FileName);
  NoteOutput(FileName);
  BlockWrite(F, PeOut, FileSize, Written);
  Close(F);
  If Written <> FileSize Then
    FatalError('erreur d''ecriture de ' + FileName);
  If Opts.Verbose Then
    WriteLn('  executable : ', FileName, ' (', FileSize, ' octets)');
End;

{ ---- Ecrivain COFF : fichier objet i386 (TODO 21) ----
  Disposition : en-tete (20) + 2 en-tetes de section (.text, .data) +
  donnees .text + relocations .text + donnees .data + relocations .data +
  table des symboles (18 octets par entree) + table des chaines.
  Symboles : 0/1 = .text + aux, 2/3 = .data + aux, 4 = _A60P_Main
  (externe, defini dans .text), 5.. = externes non definis (imports et
  routines du runtime).
  Une adresse absolue vers une etiquette definie vise le symbole de
  section ; le decalage de l'etiquette est ajoute a la valeur en place
  (addendum COFF). Un appel externe a 0 en place (REL32). }
Procedure CoffSym(Pos : LongInt; Const Name : TString; StrBase : LongInt;
                  Var StrLen : LongInt; Value : LongInt; Sect, Typ : LongInt;
                  Cls, NAux : LongInt);
Var
  I : LongInt;
Begin
  If Length(Name) <= 8 Then
    PeStr(Pos, Name)
  Else
  Begin
    PeD(Pos + 4, StrLen);
    For I := 1 To Length(Name) Do PeB(StrBase + StrLen + I - 1, Ord(Name[I]));
    PeB(StrBase + StrLen + Length(Name), 0);
    StrLen := StrLen + Length(Name) + 1;
  End;
  PeD(Pos + 8, Value);
  PeW(Pos + 12, Sect);
  PeW(Pos + 14, Typ);
  PeB(Pos + 16, Cls);
  PeB(Pos + 17, NAux);
End;

Procedure WriteCOFF(Const FileName : TString);
Var
  I, K, P, Idx, Where : LongInt;
  NTextRel, NDataRel  : LongInt;
  TextRaw, TextRelOff, DataRaw, DataRelOff, SymOff, StrOff, StrLen : LongInt;
  NSym, FileSize, Written, Sect : LongInt;
  MainSym : Integer;
  F : File;
  RelOut : LongInt;
Begin
  MainSym := Intern(A60_MAIN_NAME);
  If BinLbl[MainSym].Sect <> 1 Then
    FatalError('point d''entree ' + A60_MAIN_NAME + ' introuvable');
  NTextRel := 0;
  NDataRel := 0;
  For I := 0 To BinFixCount - 1 Do
    If BinFix[I].Sect = 0 Then Inc(NTextRel) Else Inc(NDataRel);
  If (NTextRel > 65535) Or (NDataRel > 65535) Then
    FatalError('trop de relocations pour une section COFF');

  NSym := 5 + BinImportCount;
  TextRaw    := 20 + 2 * 40;
  TextRelOff := TextRaw + AlignUp(BinCodeLen, 4);
  DataRaw    := TextRelOff + 10 * NTextRel;
  DataRelOff := DataRaw + AlignUp(BinDataLen, 4);
  SymOff     := DataRelOff + 10 * NDataRel;
  StrOff     := SymOff + 18 * NSym;
  FileSize   := StrOff + 4 + Length(A60_MAIN_NAME) + 1;
  For I := 0 To BinImportCount - 1 Do
    FileSize := FileSize + Length(NameTab[BinImport[I]]) + 1;
  If FileSize > PE_MAX_FILE Then FatalError('fichier objet trop grand');
  FillChar(PeOut, FileSize, 0);

  { en-tete de fichier }
  PeW(0, PE_MACHINE_I386);
  PeW(2, 2);
  PeD(8, SymOff);
  PeD(12, NSym);

  { sections }
  PeStr(20, '.text');
  PeD(20 + 16, BinCodeLen);
  If BinCodeLen > 0 Then PeD(20 + 20, TextRaw);
  If NTextRel > 0 Then PeD(20 + 24, TextRelOff);
  PeW(20 + 32, NTextRel);
  PeD(20 + 36, PE_SCN_TEXT Or $00300000);          { alignement 4 }
  PeStr(60, '.data');
  PeD(60 + 16, BinDataLen);
  If BinDataLen > 0 Then PeD(60 + 20, DataRaw);
  If NDataRel > 0 Then PeD(60 + 24, DataRelOff);
  PeW(60 + 32, NDataRel);
  PeD(60 + 36, PE_SCN_DATA Or $00300000);

  For I := 0 To BinCodeLen - 1 Do PeOut[TextRaw + I] := BinCode[I];
  For I := 0 To BinDataLen - 1 Do PeOut[DataRaw + I] := BinData[I];

  { relocations : .text d'abord, puis .data }
  P := TextRelOff;
  For Sect := 0 To 1 Do
  Begin
    If Sect = 1 Then P := DataRelOff;
    For I := 0 To BinFixCount - 1 Do
      If BinFix[I].Sect = Sect Then
      Begin
        If Sect = 0 Then
          Where := TextRaw + BinFix[I].Off
        Else
          Where := DataRaw + BinFix[I].Off;
        PeD(P, BinFix[I].Off);
        If BinFix[I].Kind = BF_ABS32 Then
        Begin
          Case BinLbl[BinFix[I].Sym].Sect Of
            1 : Idx := 0;
            2 : Idx := 2;
          Else
            FatalError('symbole non defini: ' + NameTab[BinFix[I].Sym]);
          End;
          PeD(Where, PeGetD(Where) + BinLbl[BinFix[I].Sym].Off);
          PeD(P + 4, Idx);
          PeW(P + 8, COFF_REL_DIR32);
        End
        Else
        Begin
          K := -1;
          For RelOut := 0 To BinImportCount - 1 Do
            If BinImport[RelOut] = BinFix[I].Sym Then K := RelOut;
          If K < 0 Then FatalError('import inconnu');
          PeD(P + 4, 5 + K);
          PeW(P + 8, COFF_REL_REL32);
        End;
        P := P + 10;
      End;
  End;

  { table des symboles }
  StrLen := 4;
  CoffSym(SymOff, '.text', StrOff, StrLen, 0, 1, 0, COFF_SYM_STATIC, 1);
  PeD(SymOff + 18, BinCodeLen);
  PeW(SymOff + 22, NTextRel);
  CoffSym(SymOff + 36, '.data', StrOff, StrLen, 0, 2, 0, COFF_SYM_STATIC, 1);
  PeD(SymOff + 54, BinDataLen);
  PeW(SymOff + 58, NDataRel);
  CoffSym(SymOff + 72, A60_MAIN_NAME, StrOff, StrLen, BinLbl[MainSym].Off,
          1, $20, COFF_SYM_EXTERNAL, 0);
  For I := 0 To BinImportCount - 1 Do
    CoffSym(SymOff + 90 + 18 * I, NameTab[BinImport[I]], StrOff, StrLen, 0,
            0, $20, COFF_SYM_EXTERNAL, 0);
  PeD(StrOff, StrLen);
  FileSize := StrOff + StrLen;

  Assign(F, FileName);
  Rewrite(F, 1);
  If IOResult <> 0 Then FatalError('impossible de creer ' + FileName);
  NoteOutput(FileName);
  BlockWrite(F, PeOut, FileSize, Written);
  Close(F);
  If Written <> FileSize Then
    FatalError('erreur d''ecriture de ' + FileName);
  If Opts.Verbose Then
    WriteLn('  objet : ', FileName, ' (', FileSize, ' octets, ', NSym,
            ' symbole(s), ', BinFixCount, ' relocation(s))');
End;

Procedure PhaseWrite;
Begin
  If Opts.EmitExe Then WritePE(Opts.OutFile);
  If Opts.EmitObj Then WriteCOFF(Opts.OutFile);
End;

{ ============================================================
  SECTION 12 - RUNTIME ALGOL 60 POUR WIN32 (TODO 22)
  ============================================================
  Le runtime est ecrit en assembleur 80386 (syntaxe du listing) et
  integre au compilateur sous forme de texte (RtText). Seules les
  routines atteignables depuis le programme compile (appels _A60RT_*,
  fermeture transitive) sont assemblees par un mini-assembleur qui les
  convertit en instructions internes, ajoutees apres le code du
  programme : elles figurent donc dans le listing .ASM, qui devient
  autonome, puis sont encodees comme le reste (.EXE et .OBJ
  independants de toute bibliotheque, hormis kernel32.dll).

  Format de RtText : '@NOM' ouvre une routine, ';texte' est un
  commentaire, 'NOM:' une etiquette, sinon une instruction.
  Les cellules de donnees _A60_* (RtData) sont creees a la demande.

  Contrat : arguments en registres, resultat en EAX ou ST(0).
    WRITESTR EAX = adresse, EDX = longueur ; WRITEZ EAX = chaine
    terminee par zero ; WRITEINT / WRITEBOOL EAX ; WRITEREAL ST(0)
    (depile) ; NEWLINE ; SETCHAN EAX = canal (2 = erreur standard,
    autre = sortie standard) ; READINT / READBOOL -> EAX, READREAL ->
    ST(0) ; POW EAX ^ EDX entiers ; RPOW ST(0) ^ ST(1) ; EXP ; FLOOR
    et RTOI ST(0) -> EAX ; RSIGN ST(0) -> -1, 0 ou 1 ; CHKIDX EAX =
    indice, ECX = borne basse, EDX = borne haute (registres conserves) ;
    DIVZERO ; ALLOC EAX = octets -> EAX = bloc mis a zero ; FREE EAX =
    bloc (registres conserves).
  Formats : un entier s'affiche en decimal ; un reel en notation fixe,
  6 decimales au plus, zeros finaux supprimes (au moins un chiffre
  apres le point), partie entiere limitee a environ 2 milliards ; un
  Boolean s'affiche true ou false ; fin de ligne = CR LF. Un indice
  hors bornes ou une division par zero ecrit un message sur le canal
  courant et termine le programme par le code de sortie 1. }
Type
  TRtLine = String[70];

Const
  RT_LINES = 543;
  RT_MAX_ROUT = 40;
  RtText : Array[0..RT_LINES - 1] Of TRtLine = (
  '@_A60RT_GETOUT',
  '_A60RT_GETOUT:',
  'CMP DWORD PTR [_A60_HOUT], 0',
  'JNE _A60R_go1',
  'PUSH -11',
  'CALL GetStdHandle',
  'MOV DWORD PTR [_A60_HOUT], EAX',
  '_A60R_go1:',
  'RET',
  '@_A60RT_WRITESTR',
  '; EAX = adresse, EDX = longueur',
  '_A60RT_WRITESTR:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 4',
  'PUSH EAX',
  'PUSH EDX',
  'CALL _A60RT_GETOUT',
  'POP EDX',
  'POP ECX',
  'PUSH 0',
  'LEA EAX, [EBP-4]',
  'PUSH EAX',
  'PUSH EDX',
  'PUSH ECX',
  'PUSH DWORD PTR [_A60_HOUT]',
  'CALL WriteFile',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A60RT_WRITEZ',
  '_A60RT_WRITEZ:',
  'MOV EDX, EAX',
  '_A60R_wz1:',
  'CMP BYTE PTR [EDX], 0',
  'JE _A60R_wz2',
  'INC EDX',
  'JMP _A60R_wz1',
  '_A60R_wz2:',
  'SUB EDX, EAX',
  'JMP _A60RT_WRITESTR',
  '@_A60RT_NEWLINE',
  '_A60RT_NEWLINE:',
  'MOV EAX, OFFSET _A60_NL',
  'MOV EDX, 2',
  'JMP _A60RT_WRITESTR',
  '@_A60RT_WRITEBOOL',
  '_A60RT_WRITEBOOL:',
  'TEST EAX, EAX',
  'JZ _A60R_wb1',
  'MOV EAX, OFFSET _A60_TRUE',
  'MOV EDX, 4',
  'JMP _A60RT_WRITESTR',
  '_A60R_wb1:',
  'MOV EAX, OFFSET _A60_FALSE',
  'MOV EDX, 5',
  'JMP _A60RT_WRITESTR',
  '@_A60RT_WRITEINT',
  '_A60RT_WRITEINT:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 16',
  'PUSH EBX',
  'PUSH ESI',
  'LEA ESI, [EBP-1]',
  'MOV EBX, EAX',
  'MOV ECX, 10',
  'TEST EAX, EAX',
  'JNS _A60R_wi1',
  'NEG EAX',
  '_A60R_wi1:',
  'XOR EDX, EDX',
  'DIV ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'TEST EAX, EAX',
  'JNZ _A60R_wi1',
  'TEST EBX, EBX',
  'JNS _A60R_wi2',
  'MOV BYTE PTR [ESI], 45',
  'DEC ESI',
  '_A60R_wi2:',
  'INC ESI',
  'MOV EDX, EBP',
  'SUB EDX, ESI',
  'MOV EAX, ESI',
  'CALL _A60RT_WRITESTR',
  'POP ESI',
  'POP EBX',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A60RT_WRITEREAL',
  '; ST(0) -> texte decimal (6 decimales au plus, zeros finaux retires)',
  '_A60RT_WRITEREAL:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 96',
  'PUSH EBX',
  'PUSH ESI',
  'PUSH EDI',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'SETB BL',
  'MOVZX EBX, BL',
  'FABS',
  'FMUL QWORD PTR [_A60_C1E6]',
  'FRNDINT',
  'FLD ST(0)',
  'FDIV QWORD PTR [_A60_C1E6]',
  'CALL _A60RT_FLOOR',
  'MOV DWORD PTR [EBP-4], EAX',
  'FILD DWORD PTR [EBP-4]',
  'FMUL QWORD PTR [_A60_C1E6]',
  'FSUBP ST(1), ST',
  'FISTP DWORD PTR [EBP-8]',
  'LEA EDI, [EBP-96]',
  'TEST EBX, EBX',
  'JZ _A60R_wr1',
  'MOV BYTE PTR [EDI], 45',
  'INC EDI',
  '_A60R_wr1:',
  'MOV EAX, DWORD PTR [EBP-4]',
  'LEA ESI, [EBP-47]',
  'MOV ECX, 10',
  '_A60R_wr2:',
  'XOR EDX, EDX',
  'DIV ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'TEST EAX, EAX',
  'JNZ _A60R_wr2',
  'INC ESI',
  'LEA EDX, [EBP-46]',
  '_A60R_wr3:',
  'CMP ESI, EDX',
  'JAE _A60R_wr4',
  'MOV AL, BYTE PTR [ESI]',
  'MOV BYTE PTR [EDI], AL',
  'INC ESI',
  'INC EDI',
  'JMP _A60R_wr3',
  '_A60R_wr4:',
  'MOV BYTE PTR [EDI], 46',
  'INC EDI',
  'MOV EAX, DWORD PTR [EBP-8]',
  'LEA ESI, [EBP-39]',
  'MOV ECX, 6',
  '_A60R_wr5:',
  'XOR EDX, EDX',
  'PUSH ECX',
  'MOV ECX, 10',
  'DIV ECX',
  'POP ECX',
  'ADD DL, 48',
  'MOV BYTE PTR [ESI], DL',
  'DEC ESI',
  'DEC ECX',
  'JNZ _A60R_wr5',
  'MOV ECX, 6',
  '_A60R_wr6:',
  'CMP ECX, 1',
  'JLE _A60R_wr7',
  'CMP BYTE PTR [EBP+ECX-45], 48',
  'JNE _A60R_wr7',
  'DEC ECX',
  'JMP _A60R_wr6',
  '_A60R_wr7:',
  'LEA ESI, [EBP-44]',
  '_A60R_wr8:',
  'MOV AL, BYTE PTR [ESI]',
  'MOV BYTE PTR [EDI], AL',
  'INC ESI',
  'INC EDI',
  'DEC ECX',
  'JNZ _A60R_wr8',
  'LEA EAX, [EBP-96]',
  'MOV EDX, EDI',
  'SUB EDX, EAX',
  'CALL _A60RT_WRITESTR',
  'POP EDI',
  'POP ESI',
  'POP EBX',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A60RT_GETC',
  '; ---- lecture ----',
  '_A60RT_GETC:',
  'MOV EAX, DWORD PTR [_A60_PEEKC]',
  'CMP EAX, -2',
  'JE _A60R_gc1',
  'MOV DWORD PTR [_A60_PEEKC], -2',
  'RET',
  '_A60R_gc1:',
  'PUSH EBP',
  'MOV EBP, ESP',
  'SUB ESP, 8',
  'CMP DWORD PTR [_A60_HIN], 0',
  'JNE _A60R_gc2',
  'PUSH -10',
  'CALL GetStdHandle',
  'MOV DWORD PTR [_A60_HIN], EAX',
  '_A60R_gc2:',
  'PUSH 0',
  'LEA EAX, [EBP-4]',
  'PUSH EAX',
  'PUSH 1',
  'LEA EAX, [EBP-8]',
  'PUSH EAX',
  'PUSH DWORD PTR [_A60_HIN]',
  'CALL ReadFile',
  'TEST EAX, EAX',
  'JZ _A60R_gc3',
  'CMP DWORD PTR [EBP-4], 0',
  'JE _A60R_gc3',
  'MOVZX EAX, BYTE PTR [EBP-8]',
  'JMP _A60R_gc4',
  '_A60R_gc3:',
  'MOV EAX, -1',
  '_A60R_gc4:',
  'MOV ESP, EBP',
  'POP EBP',
  'RET',
  '@_A60RT_UNGETC',
  '_A60RT_UNGETC:',
  'MOV DWORD PTR [_A60_PEEKC], EAX',
  'RET',
  '@_A60RT_SKIPWS',
  '; saute les blancs ; retourne le premier caractere utile dans EAX',
  '_A60RT_SKIPWS:',
  'CALL _A60RT_GETC',
  'CMP EAX, 32',
  'JE _A60RT_SKIPWS',
  'CMP EAX, 9',
  'JE _A60RT_SKIPWS',
  'CMP EAX, 13',
  'JE _A60RT_SKIPWS',
  'CMP EAX, 10',
  'JE _A60RT_SKIPWS',
  'RET',
  '@_A60RT_READINT',
  '_A60RT_READINT:',
  'PUSH EBX',
  'PUSH ESI',
  'XOR ESI, ESI',
  'XOR EBX, EBX',
  'CALL _A60RT_SKIPWS',
  'CMP EAX, 45',
  'JNE _A60R_ri1',
  'MOV EBX, 1',
  'CALL _A60RT_GETC',
  'JMP _A60R_ri2',
  '_A60R_ri1:',
  'CMP EAX, 43',
  'JNE _A60R_ri2',
  'CALL _A60RT_GETC',
  '_A60R_ri2:',
  'MOV ECX, EAX',
  'SUB ECX, 48',
  'CMP ECX, 9',
  'JBE _A60R_ri3',
  'CALL _A60RT_UNGETC',
  'JMP _A60R_ri4',
  '_A60R_ri3:',
  'IMUL ESI, ESI, 10',
  'ADD ESI, ECX',
  'CALL _A60RT_GETC',
  'JMP _A60R_ri2',
  '_A60R_ri4:',
  'MOV EAX, ESI',
  'TEST EBX, EBX',
  'JZ _A60R_ri5',
  'NEG EAX',
  '_A60R_ri5:',
  'POP ESI',
  'POP EBX',
  'RET',
  '@_A60RT_READREAL',
  '_A60RT_READREAL:',
  'PUSH EBX',
  'PUSH ESI',
  'PUSH EDI',
  'XOR EBX, EBX',
  'XOR EDI, EDI',
  'FLDZ',
  'CALL _A60RT_SKIPWS',
  'CMP EAX, 45',
  'JNE _A60R_rr1',
  'MOV EBX, 1',
  'CALL _A60RT_GETC',
  'JMP _A60R_rr2',
  '_A60R_rr1:',
  'CMP EAX, 43',
  'JNE _A60R_rr2',
  'CALL _A60RT_GETC',
  '_A60R_rr2:',
  'CMP EAX, 46',
  'JNE _A60R_rr3',
  'MOV ESI, 1',
  'CALL _A60RT_GETC',
  'JMP _A60R_rr2',
  '_A60R_rr3:',
  'MOV ECX, EAX',
  'SUB ECX, 48',
  'CMP ECX, 9',
  'JA _A60R_rr6',
  'FILD DWORD PTR [_A60_TEN]',
  'FMULP ST(1), ST',
  'MOV DWORD PTR [_A60_TMP], ECX',
  'FILD DWORD PTR [_A60_TMP]',
  'FADDP ST(1), ST',
  'TEST ESI, ESI',
  'JZ _A60R_rr4',
  'INC EDI',
  '_A60R_rr4:',
  'CALL _A60RT_GETC',
  'JMP _A60R_rr2',
  '_A60R_rr6:',
  'CALL _A60RT_UNGETC',
  '_A60R_rr7:',
  'TEST EDI, EDI',
  'JZ _A60R_rr8',
  'FILD DWORD PTR [_A60_TEN]',
  'FDIVP ST(1), ST',
  'DEC EDI',
  'JMP _A60R_rr7',
  '_A60R_rr8:',
  'TEST EBX, EBX',
  'JZ _A60R_rr9',
  'FCHS',
  '_A60R_rr9:',
  'POP EDI',
  'POP ESI',
  'POP EBX',
  'RET',
  '@_A60RT_READBOOL',
  '_A60RT_READBOOL:',
  'CALL _A60RT_SKIPWS',
  'MOV ECX, EAX',
  'OR ECX, 32',
  'XOR EDX, EDX',
  'CMP ECX, 116',
  'JNE _A60R_rb1',
  'MOV EDX, 1',
  '_A60R_rb1:',
  'PUSH EDX',
  '_A60R_rb2:',
  'CALL _A60RT_GETC',
  'CMP EAX, 97',
  'JB _A60R_rb3',
  'CMP EAX, 122',
  'JBE _A60R_rb2',
  '_A60R_rb3:',
  'CMP EAX, 65',
  'JB _A60R_rb4',
  'CMP EAX, 90',
  'JBE _A60R_rb2',
  '_A60R_rb4:',
  'CALL _A60RT_UNGETC',
  'POP EAX',
  'RET',
  '@_A60RT_POW',
  '; ---- arithmetique ----',
  '; EAX = base, EDX = exposant -> EAX',
  '_A60RT_POW:',
  'PUSH EBX',
  'MOV ECX, EDX',
  'MOV EBX, EAX',
  'MOV EAX, 1',
  'TEST ECX, ECX',
  'JS _A60R_pw5',
  '_A60R_pw1:',
  'TEST ECX, ECX',
  'JZ _A60R_pw9',
  'MOV EDX, ECX',
  'AND EDX, 1',
  'JZ _A60R_pw2',
  'IMUL EAX, EBX',
  '_A60R_pw2:',
  'IMUL EBX, EBX',
  'SHR ECX, 1',
  'JMP _A60R_pw1',
  '_A60R_pw5:',
  'CMP EBX, 1',
  'JE _A60R_pw9',
  'CMP EBX, -1',
  'JNE _A60R_pw6',
  'MOV EDX, ECX',
  'AND EDX, 1',
  'JZ _A60R_pw9',
  'MOV EAX, -1',
  'JMP _A60R_pw9',
  '_A60R_pw6:',
  'XOR EAX, EAX',
  '_A60R_pw9:',
  'POP EBX',
  'RET',
  '@_A60RT_EXP2',
  '; ST(0) = t -> 2^t',
  '_A60RT_EXP2:',
  'FLD ST(0)',
  'FRNDINT',
  'FSUB ST(1), ST',
  'FXCH ST(1)',
  'F2XM1',
  'FLD1',
  'FADDP ST(1), ST',
  'FSCALE',
  'FSTP ST(1)',
  'RET',
  '@_A60RT_EXP',
  '; ST(0) = x -> e^x',
  '_A60RT_EXP:',
  'FLDL2E',
  'FMULP ST(1), ST',
  'JMP _A60RT_EXP2',
  '@_A60RT_RPOW',
  '; ST(0) = base, ST(1) = exposant -> ST(0) = base ^ exposant',
  '_A60RT_RPOW:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'JA _A60R_rp2',
  'JB _A60R_rp1',
  'FSTP ST(0)',
  'FSTP ST(0)',
  'FLDZ',
  'RET',
  '_A60R_rp1:',
  'FABS',
  'FLD ST(1)',
  'FISTP DWORD PTR [_A60_TMP]',
  'FYL2X',
  'CALL _A60RT_EXP2',
  'MOV EAX, DWORD PTR [_A60_TMP]',
  'AND EAX, 1',
  'JZ _A60R_rp3',
  'FCHS',
  '_A60R_rp3:',
  'RET',
  '_A60R_rp2:',
  'FYL2X',
  'JMP _A60RT_EXP2',
  '@_A60RT_FLOOR',
  '; ST(0) -> EAX = plancher',
  '_A60RT_FLOOR:',
  'SUB ESP, 8',
  'FNSTCW WORD PTR [ESP]',
  'MOVZX EAX, WORD PTR [ESP]',
  'AND EAX, 0F3FFh',
  'OR EAX, 0400h',
  'MOV WORD PTR [ESP+2], AX',
  'FLDCW WORD PTR [ESP+2]',
  'FISTP DWORD PTR [ESP+4]',
  'FLDCW WORD PTR [ESP]',
  'MOV EAX, DWORD PTR [ESP+4]',
  'ADD ESP, 8',
  'RET',
  '@_A60RT_RTOI',
  '; ST(0) -> EAX = arrondi au plus proche, demi vers le haut',
  '_A60RT_RTOI:',
  'FADD QWORD PTR [_A60_HALF]',
  'JMP _A60RT_FLOOR',
  '@_A60RT_RSIGN',
  '; ST(0) -> EAX = -1, 0 ou 1',
  '_A60RT_RSIGN:',
  'FTST',
  'FNSTSW AX',
  'SAHF',
  'FSTP ST(0)',
  'JA _A60R_rs1',
  'JB _A60R_rs2',
  'XOR EAX, EAX',
  'RET',
  '_A60R_rs1:',
  'MOV EAX, 1',
  'RET',
  '_A60R_rs2:',
  'MOV EAX, -1',
  'RET',
  '@_A60RT_CHKIDX',
  '; EAX = indice, ECX = bas, EDX = haut : conserve tous les registres',
  '_A60RT_CHKIDX:',
  'CMP EAX, ECX',
  'JL _A60R_ci1',
  'CMP EAX, EDX',
  'JG _A60R_ci1',
  'RET',
  '_A60R_ci1:',
  'MOV EAX, OFFSET _A60_M_IDX',
  'MOV EDX, 28',
  'CALL _A60RT_WRITESTR',
  'PUSH 1',
  'CALL ExitProcess',
  '@_A60RT_DIVZERO',
  '_A60RT_DIVZERO:',
  'MOV EAX, OFFSET _A60_M_DIV',
  'MOV EDX, 27',
  'CALL _A60RT_WRITESTR',
  'PUSH 1',
  'CALL ExitProcess',
  '@_A60RT_ALLOC',
  '; EAX = octets -> EAX = adresse (memoire mise a zero)',
  '_A60RT_ALLOC:',
  'PUSH EAX',
  'CALL GetProcessHeap',
  'POP ECX',
  'PUSH ECX',
  'PUSH 8',
  'PUSH EAX',
  'CALL HeapAlloc',
  'RET',
  '@_A60RT_FREE',
  ';EAX = adresse du bloc ; conserve EAX, ECX et EDX',
  '_A60RT_FREE:',
  'PUSH EAX',
  'PUSH ECX',
  'PUSH EDX',
  'PUSH EAX',
  'PUSH 0',
  'CALL GetProcessHeap',
  'PUSH EAX',
  'CALL HeapFree',
  'POP EDX',
  'POP ECX',
  'POP EAX',
  'RET',
  '@_A60RT_SETCHAN',
  '_A60RT_SETCHAN:',
  'CMP EAX, 2',
  'JNE _A60R_sc1',
  'PUSH -12',
  'JMP _A60R_sc2',
  '_A60R_sc1:',
  'PUSH -11',
  '_A60R_sc2:',
  'CALL GetStdHandle',
  'MOV DWORD PTR [_A60_HOUT], EAX',
  'RET'
  );

Var
  RtStart   : Array[0..RT_MAX_ROUT] Of Integer;   { 1re ligne de routine }
  RtName    : Array[0..RT_MAX_ROUT - 1] Of TString;
  RtUsed    : Array[0..RT_MAX_ROUT - 1] Of Boolean;
  RtCount   : Integer;
  RtLine    : TString;                             { ligne assemblee }
  RtPos     : Integer;
  RtDataMade: Array[0..31] Of Integer;
  RtDataN   : Integer;

Function RtFind(Const Name : TString) : Integer;
Var
  I : Integer;
Begin
  RtFind := -1;
  For I := 0 To RtCount - 1 Do
    If RtName[I] = Name Then RtFind := I;
End;

Function RtIdChar(C : Char) : Boolean;
Begin
  RtIdChar := ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
              ((C >= '0') And (C <= '9')) Or (C = '_');
End;

{ Marque une routine et, transitivement, celles qu'elle appelle }
Procedure RtMark(Const Name : TString);
Var
  R, L, P, E : Integer;
  S, Id      : TString;
Begin
  R := RtFind(Name);
  If R < 0 Then
    FatalError('erreur interne: routine du runtime inconnue: ' + Name);
  If RtUsed[R] Then Exit;
  RtUsed[R] := True;
  For L := RtStart[R] To RtStart[R + 1] - 1 Do
  Begin
    S := RtText[L];
    If (S <> '') And (S[1] <> ';') And (S[1] <> '@') Then
    Begin
      P := Pos(A60_RT_PFX, S);
      While P > 0 Do
      Begin
        E := P;
        While (E <= Length(S)) And RtIdChar(S[E]) Do Inc(E);
        Id := Copy(S, P, E - P);
        RtMark(Id);
        S := Copy(S, E, Length(S));
        P := Pos(A60_RT_PFX, S);
      End;
    End;
  End;
End;

{ ---- cellules de donnees du runtime, creees a la demande ---- }
Procedure RtDataInt(Sym : Integer; V : LongInt);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_INT);
  DataTab[K].Lo   := V;
  DataTab[K].Size := 4;
End;

Procedure RtDataStr(Sym : Integer; Const S : TString);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_STR);
  DataTab[K].Str  := AsmStrAdd(S);
  DataTab[K].Size := Length(S);
End;

Procedure RtDataReal(Sym : Integer; Lo, Hi : LongInt);
Var
  K : Integer;
Begin
  K := DataNew(Sym, DK_REAL);
  DataTab[K].Lo   := Lo;
  DataTab[K].Hi   := Hi;
  DataTab[K].Size := 8;
End;

Procedure RtData(Sym : Integer);
Var
  I : Integer;
  N : TString;
Begin
  For I := 0 To RtDataN - 1 Do
    If RtDataMade[I] = Sym Then Exit;
  If RtDataN > 31 Then FatalError('erreur interne: trop de donnees runtime');
  RtDataMade[RtDataN] := Sym;
  Inc(RtDataN);
  N := NameTab[Sym];
  If (N = '_A60_HOUT') Or (N = '_A60_HIN') Or (N = '_A60_TMP') Then
    DataAddZero(Sym, 4)
  Else If N = '_A60_PEEKC' Then RtDataInt(Sym, -2)
  Else If N = '_A60_TEN'   Then RtDataInt(Sym, 10)
  Else If N = '_A60_NL'    Then RtDataStr(Sym, #13#10)
  Else If N = '_A60_TRUE'  Then RtDataStr(Sym, 'true')
  Else If N = '_A60_FALSE' Then RtDataStr(Sym, 'false')
  Else If N = '_A60_M_IDX' Then
    RtDataStr(Sym, 'Erreur: indice hors bornes'#13#10)
  Else If N = '_A60_M_DIV' Then
    RtDataStr(Sym, 'Erreur: division par zero'#13#10)
  Else If N = '_A60_C1E6'  Then RtDataReal(Sym, 0, $412E8480)
  Else If N = '_A60_HALF'  Then RtDataReal(Sym, 0, $3FE00000)
  Else
    FatalError('erreur interne: donnee runtime inconnue: ' + N);
End;

{ ---- mini-assembleur ---- }
Procedure RtSkip;
Begin
  While (RtPos <= Length(RtLine)) And (RtLine[RtPos] = ' ') Do Inc(RtPos);
End;

Function RtAtEnd : Boolean;
Begin
  RtSkip;
  RtAtEnd := RtPos > Length(RtLine);
End;

Function RtIdent : TString;
Var
  S : TString;
Begin
  S := '';
  While (RtPos <= Length(RtLine)) And RtIdChar(RtLine[RtPos]) Do
  Begin
    S := S + RtLine[RtPos];
    Inc(RtPos);
  End;
  RtIdent := S;
End;

{ nombre decimal ou hexadecimal (suffixe h), sans signe }
Function RtNumber : LongInt;
Var
  S    : TString;
  I, D : Integer;
  V    : LongInt;
  Hex  : Boolean;
Begin
  S := RtIdent;
  Hex := (S <> '') And ((S[Length(S)] = 'h') Or (S[Length(S)] = 'H'));
  If Hex Then Delete(S, Length(S), 1);
  V := 0;
  For I := 1 To Length(S) Do
  Begin
    If (S[I] >= '0') And (S[I] <= '9') Then
      D := Ord(S[I]) - 48
    Else
      D := Ord(UpCase(S[I])) - 55;
    If Hex Then V := V * 16 + D Else V := V * 10 + D;
  End;
  RtNumber := V;
End;

Function RtReg(Const S : TString) : TReg;
Begin
  RtReg := R_NONE;
  If S = 'EAX' Then RtReg := R_EAX
  Else If S = 'ECX' Then RtReg := R_ECX
  Else If S = 'EDX' Then RtReg := R_EDX
  Else If S = 'EBX' Then RtReg := R_EBX
  Else If S = 'ESP' Then RtReg := R_ESP
  Else If S = 'EBP' Then RtReg := R_EBP
  Else If S = 'ESI' Then RtReg := R_ESI
  Else If S = 'EDI' Then RtReg := R_EDI
  Else If S = 'AX' Then RtReg := R_AX
  Else If S = 'AL' Then RtReg := R_AL
  Else If S = 'CL' Then RtReg := R_CL
  Else If S = 'DL' Then RtReg := R_DL
  Else If S = 'BL' Then RtReg := R_BL;
End;

Function RtSym(Const Name : TString) : Integer;
Var
  K : Integer;
Begin
  K := Intern(Name);
  If Copy(Name, 1, 5) = '_A60_' Then RtData(K);
  RtSym := K;
End;

{ [Sym + Base + Index*Echelle + Depl] }
Function RtMemory(Size : Byte) : TOperand;
Var
  O    : TOperand;
  Sign : LongInt;
  Id   : TString;
  R    : TReg;
  N    : LongInt;
Begin
  O := OpNone;
  O.Kind := OK_MEM;
  O.Size := Size;
  Inc(RtPos);                                   { [ }
  Sign := 1;
  While (RtPos <= Length(RtLine)) And (RtLine[RtPos] <> ']') Do
  Begin
    RtSkip;
    If RtLine[RtPos] = '+' Then
    Begin
      Sign := 1;
      Inc(RtPos);
    End
    Else If RtLine[RtPos] = '-' Then
    Begin
      Sign := -1;
      Inc(RtPos);
    End
    Else If (RtLine[RtPos] >= '0') And (RtLine[RtPos] <= '9') Then
    Begin
      O.Imm := O.Imm + Sign * RtNumber;
      Sign := 1;
    End
    Else
    Begin
      Id := RtIdent;
      If Id = '' Then FatalError('erreur interne: runtime: ' + RtLine);
      R := RtReg(Id);
      If R <> R_NONE Then
      Begin
        If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = '*') Then
        Begin
          Inc(RtPos);
          N := RtNumber;
          O.Index := R;
          O.Scale := N;
        End
        Else If O.Base = R_NONE Then
          O.Base := R
        Else
        Begin
          O.Index := R;
          O.Scale := 1;
        End;
      End
      Else
        O.Sym := RtSym(Id);
      Sign := 1;
    End;
    RtSkip;
  End;
  Inc(RtPos);                                   { ] }
  RtMemory := O;
End;

Function RtOperand : TOperand;
Var
  Id, Id2 : TString;
  R       : TReg;
  Size    : Byte;
  Neg     : Boolean;
  V       : LongInt;
Begin
  RtSkip;
  Size := 0;
  If RtLine[RtPos] = '[' Then
  Begin
    RtOperand := RtMemory(0);
    Exit;
  End;
  If (RtLine[RtPos] = '-') Or ((RtLine[RtPos] >= '0') And
                               (RtLine[RtPos] <= '9')) Then
  Begin
    Neg := RtLine[RtPos] = '-';
    If Neg Then Inc(RtPos);
    V := RtNumber;
    If Neg Then V := -V;
    RtOperand := OpImm(V);
    Exit;
  End;
  Id := RtIdent;
  If (Id = 'BYTE') Or (Id = 'WORD') Or (Id = 'DWORD') Or (Id = 'QWORD') Then
  Begin
    If Id = 'BYTE' Then Size := 1
    Else If Id = 'WORD' Then Size := 2
    Else If Id = 'DWORD' Then Size := 4
    Else Size := 8;
    RtSkip;
    Id2 := RtIdent;                             { PTR }
    RtSkip;
    RtOperand := RtMemory(Size);
    Exit;
  End;
  If Id = 'OFFSET' Then
  Begin
    RtSkip;
    RtOperand := OpOffset(RtSym(RtIdent));
    Exit;
  End;
  If Id = 'ST' Then
  Begin
    V := 0;
    If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = '(') Then
    Begin
      Inc(RtPos);
      V := RtNumber;
      Inc(RtPos);
    End;
    RtOperand := OpST(V);
    Exit;
  End;
  R := RtReg(Id);
  If R <> R_NONE Then
    RtOperand := OpReg(R)
  Else
    RtOperand := OpLabel(Intern(Id));
End;

Procedure RtAssembleLine(Const S : TString);
Var
  Mn   : TString;
  Op   : TOp;
  Found: Boolean;
  A, B : TOperand;
Begin
  RtLine := S;
  RtPos  := 1;
  If S[1] = ';' Then
  Begin
    EmitComment(Copy(S, 2, Length(S)));
    Exit;
  End;
  If S[Length(S)] = ':' Then
  Begin
    EmitLabel(Intern(Copy(S, 1, Length(S) - 1)));
    Exit;
  End;
  Mn := RtIdent;
  If Mn = 'JZ' Then Mn := 'JE';
  If Mn = 'JNZ' Then Mn := 'JNE';
  Found := False;
  Op := OP_MOV;
  While (Not Found) And (Op <= OP_FLDCW) Do
  Begin
    If OpName(Op) = Mn Then Found := True Else Op := Succ(Op);
  End;
  If Not Found Then FatalError('erreur interne: runtime: ' + S);
  A := OpNone;
  B := OpNone;
  If Not RtAtEnd Then
  Begin
    A := RtOperand;
    RtSkip;
    If (RtPos <= Length(RtLine)) And (RtLine[RtPos] = ',') Then
    Begin
      Inc(RtPos);
      B := RtOperand;
    End;
  End;
  Emit(Op, A, B);
End;

{ Ajoute au programme les routines du runtime qu'il utilise }
Procedure RtLink;
Var
  I, L, R, Start : LongInt;
  Any            : Boolean;
  S              : TString;
Begin
  RtCount := 0;
  RtDataN := 0;
  For L := 0 To RT_LINES - 1 Do
    If RtText[L][1] = '@' Then
    Begin
      If RtCount >= RT_MAX_ROUT Then
        FatalError('erreur interne: trop de routines runtime');
      RtStart[RtCount] := L;
      RtName[RtCount]  := Copy(RtText[L], 2, 255);
      RtUsed[RtCount]  := False;
      Inc(RtCount);
    End;
  RtStart[RtCount] := RT_LINES;
  { routines appelees par le programme }
  For I := 0 To CodeCount + DeferCount - 1 Do
    If (InstrAt(I).A.Kind = OK_LABEL) And
       (InstrAt(I).Op In [OP_CALL, OP_JMP]) Then
    Begin
      S := NameTab[InstrAt(I).A.Sym];
      If Copy(S, 1, Length(A60_RT_PFX)) = A60_RT_PFX Then RtMark(S);
    End;
  Any := False;
  For R := 0 To RtCount - 1 Do
    If RtUsed[R] Then Any := True;
  If Not Any Then Exit;
  Start := CodeCount;
  EmitBlank;
  EmitComment('---- runtime AL60CW32 (routines utilisees) ----');
  For R := 0 To RtCount - 1 Do
    If RtUsed[R] Then
    Begin
      EmitBlank;
      For L := RtStart[R] + 1 To RtStart[R + 1] - 1 Do
        RtAssembleLine(RtText[L]);
    End;
  MoveToDeferred(Start);
End;

{ ============================================================
  SECTION 13 - ERREURS ET RAPPORT FINAL (TODO 23, 24)
  ============================================================ }
Procedure PhaseReport;
Begin
  If ErrorCount > 0 Then
    WriteLn('Compilation echouee : ', ErrorCount, ' erreur(s), ',
            WarnCount, ' avertissement(s)')
  Else If (WarnCount > 0) Or Opts.Verbose Then
  Begin
    If Opts.Verbose Then
    Begin
      Write('  fichier(s) produit(s) : ', Opts.OutFile);
      If Opts.EmitAsm Then Write(', ', Opts.AsmFile);
      If Opts.DebugMode Then Write(', ', ReplaceExt(Opts.OutFile, '.lst'));
      WriteLn;
    End;
    WriteLn('Compilation terminee : 0 erreur, ', WarnCount,
            ' avertissement(s)');
  End;
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
    PH_CODEGEN :
      Begin
        RtLink;
        PhaseCodegen;
      End;
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
  OutCreatedN := 0;
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
  { le parseur tourne meme apres des erreurs lexicales (les erreurs
    syntaxiques s'ajoutent) ; les phases suivantes ne tournent que sans
    erreur : aucun fichier de sortie n'est ecrit sinon }
  For P := PH_LEX To PH_REPORT Do
    If (ErrorCount = 0) Or (P = PH_PARSE) Or (P = PH_REPORT) Then
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
