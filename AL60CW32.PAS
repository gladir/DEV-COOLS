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

  ETAT : TODO 01 implemente (squelette en sections et pipeline en 6
         phases) ; TODO 02 a 25 a faire.

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

  TODO 02 - OPTIONS DE LIGNE DE COMMANDE ET FICHIERS DE SORTIE [A FAIRE]
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

  TODO 03 - CONSTANTES, LIMITES ET CONVENTIONS DE NOMMAGE [A FAIRE]
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
            Utilitaires : ItoS, UpCaseStr, AsmIdent (nom ASM valide),
              extension et nom de fichier

  TODO 04 - LEXEUR ALGOL 60 [A FAIRE]
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

{ ============================================================
  SECTION 2 - TYPES (TODO 01, 04, 05, 06)
  ============================================================ }
Type
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
  ErrorCount : Integer;   { erreurs de compilation signalees  }
  WarnCount  : Integer;   { avertissements signales           }

{ ============================================================
  SECTION 4 - UTILITAIRES (TODO 03)
  ============================================================ }
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

{ ============================================================
  SECTION 5 - OPTIONS DE LIGNE DE COMMANDE (TODO 02)
  ============================================================ }

{ ============================================================
  SECTION 6 - LEXEUR (TODO 04)
  ============================================================ }
Procedure PhaseLex;
Begin
  { A faire : TODO 04 }
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
  WriteLn('AL60CW32 ', AL60CW32_VERSION, ' - Compilateur Algol 60 ',
          'vers 80386 / Windows 32 bits');
  Run;
END.
