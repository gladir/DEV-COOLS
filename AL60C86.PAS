{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Algol 60 vers assembleur 8086
}

(* ============================================================
  AL60C86.PAS - Compilateur Algol 60 -> Assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings)
            ParseArgs : analyser argv (source.a60 [sortie.asm] [-v] [-d] [-w])
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .a60 ou .alg (fichier source Algol 60)
            Programme principal : validation des arguments et appel Run
            Version, Date, aide en ligne (option -h)

  TODO 02 - LEXEUR (TOKENS ALGOL 60)
            TTokenKind : TK_EOF, TK_INTEGER, TK_REAL, TK_IDENT,
              TK_STRING, TK_KEYWORD, TK_OP, TK_PUNCT, TK_BOOLEAN
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : chaine entre guillemets ` ... ` ou backtick
            Commentaires : mot-cle 'comment' suivi de texte jusqu au ;
              Texte entre BEGIN et le premier ; (commentaire implicite)
            Mots-cles : BEGIN END IF THEN ELSE FOR DO STEP UNTIL
              WHILE GO TO GOTO SWITCH VALUE OWN BOOLEAN INTEGER
              REAL ARRAY PROCEDURE STRING LABEL COMMENT TRUE FALSE
            Symboles speciaux : := (affectation), ; (separateur)
              : (etiquette), , (virgule), . (fin de programme)
              ( ) [ ] (parentheses et indices)
              + - * / (arithmetique)
              < <= = >= > != (comparaison)
              ^ (puissance, notation alternative **)
              10 (notation exposant dans les reels, symbole dix)
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux : 0..65535 (unsigned) ou -32768..32767 (signed)
            Reels : 3.14, 6.022|10|23 (notation avec exposant base 10)
              Traitement simplifie : trunc vers entier 16 bits + avertissement
            Booleens : TRUE -> AX=1, FALSE -> AX=0
            Chaines : `Hello` -> donnees dans segment DATA avec DB
              Pas de type chaine natif en Algol 60 standard
              Extension : chaines pour les entrees/sorties
            Constantes nommees : pas de CONST en Algol 60, simuler avec
              des variables initialisees ou des macros internes

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques : + - * / (reels et entiers)
                            div (division entiere, reste tronque)
            Puissance     : ^ ou ** (exponentiation)
            Comparaison   : < <= = >= > != (different de)
            Logiques      : AND OR NOT (ou symboles /\ \/ ~)
              Equivalence : EQUIV (equivalence logique)
              Implication : IMPL (implication logique -> NOT a OR b)
            Affectation   : := (peut etre multiple : a := b := expr)
            Precedence (du plus fort au plus faible) :
              1. NOT, unaire +/-
              2. ^ (puissance)
              3. * / div
              4. + - (binaire)
              5. < <= = >= > !=
              6. AND
              7. OR
              8. IMPL
              9. EQUIV

  TODO 05 - TABLE DES SYMBOLES
            TSymKind : SK_VAR, SK_PARAM, SK_PROC, SK_LABEL,
              SK_SWITCH, SK_ARRAY, SK_OWN
            TSymRec : Name, MangledName, Kind, TypeIdx, Offset,
              Scope, IsOwn, IsValue, IsName
            SymAdd, SymFind, SymFindInScope, SymMangle
            CurScope : compteur de portee imbriquee (max MAX_SCOPE)
            SymEnterScope / SymLeaveScope : gestion des blocs imbriques
              Algol 60 permet des declarations locales dans chaque bloc
            Algol 60 est a portee lexicale statique (static scoping)
            Recherche en remontant les portees englobantes

  TODO 06 - SYSTEME DE TYPES
            TTypeKind : TYK_INTEGER (16 bits signe), TYK_REAL (stub entier),
              TYK_BOOLEAN (16 bits, 0 ou 1), TYK_STRING (ptr chaine),
              TYK_LABEL (adresse de code), TYK_SWITCH (tableau de labels),
              TYK_PROCEDURE (pointeur de code), TYK_ARRAY (tableau)
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : INTEGER=2, REAL=2 (tronque), BOOLEAN=2, ptr=2
            Conversion implicite INTEGER -> REAL (avertissement)
            Pas de types utilisateur en Algol 60 (pas de RECORD, pas d ENUM)
            Verification de type a la compilation pour les operateurs

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _A60L_NNNNN)
            Prefixes : _A60V_ (variable), _A60P_ (procedure), _A60K_ (chaine const),
              _A60RT_ (runtime), _A60L_ (label), _A60S_ (switch),
              _A60O_ (variable own), _A60T_ (thunk)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            EmitProlog / EmitEpilog : PUSH BP / MOV BP,SP et MOV SP,BP / POP BP
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd, DataAddStr : variantes d ajout
            Variables globales (declarations au niveau programme) :
              entrees DK_WORD dans DATA
            Chaines litterales : DB 'abc',0 dans DATA avec label _A60K_N
            Variables OWN : entrees dans DATA (persistent entre appels)
              avec label _A60O_NomProc_NomVar
            Tableaux globaux : reserve avec DW count DUP(0)

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables globales : segment DATA, acces par label _A60V_nom
            Variables locales : pile BP, acces [BP-offset]
            Parametres par valeur : copie sur pile (comme variable locale)
            Parametres par nom : passage de thunk (adresse de sous-routine)
            Affectation := : ParseExpr + MOV destination, AX
            Affectation multiple : a := b := c := expr
              Evaluer expr une fois, affecter de droite a gauche
            Affectation de tableau : arr[i] := expr -> calcul offset + MOV

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal reel, TRUE/FALSE,
              identificateur, appel de procedure/fonction
            Acces variable simple : MOV AX, [label] ou MOV AX, [BP-offset]
            Acces element de tableau : arr[i,j] -> calcul offset lineaire
            Appel de fonction : CALL _A60P_nom -> resultat dans AX
            Parentheses : ( expr ) -> evaluation de l expression
            Expression conditionnelle : IF b THEN e1 ELSE e2
              (traitee comme expression retournant une valeur dans AX)
            Acces switch : nom[expr] -> expression designationnelle (label)

  TODO 11 - EXPRESSIONS ARITHMETIQUES ET BOOLEENNES
            ParseExprPrec(MinPrec) : boucle de precedence (Pratt)
            Arithmetique entiere : ADD/SUB/IMUL/IDIV pour +, -, *, div
            Division reelle / : IDIV avec avertissement (pas de virgule flottante)
            Puissance ^ : boucle de multiplication iterative
              ou CALL _A60RT_POWER(AX=base, BX=exposant) -> AX
            Comparaison : CMP + Jcc pour <, <=, =, >=, >, !=
            Logique AND : court-circuit JZ vers false-branch
            Logique OR : court-circuit JNZ vers true-branch
            Logique NOT : XOR AX,1
            IMPL (implication) : NOT a OR b -> emission JNZ + OR
            EQUIV (equivalence) : CMP AX,BX -> AX=0|1 ou XOR+NOT

  TODO 12 - ENTREES/SORTIES (INTRINSICS)
            Algol 60 ne definit pas d E/S standard ;
            intrinsics fournis par le compilateur :
            outinteger(canal, n)   -> CALL _A60RT_OUTINT (INT 21h AH=40h)
            outreal(canal, x)      -> CALL _A60RT_OUTREAL (stub: outinteger)
            outstring(canal, s)    -> CALL _A60RT_OUTSTR (INT 21h AH=40h)
            outboolean(canal, b)   -> CALL _A60RT_OUTBOOL ("TRUE"/"FALSE")
            ininteger(canal)       -> CALL _A60RT_ININT (INT 21h AH=0Ah + atoi)
            inreal(canal)          -> CALL _A60RT_INREAL (stub: ininteger)
            inchar(canal)          -> CALL _A60RT_INCHAR (INT 21h AH=01h)
            sysact(canal, action, r) -> operations speciales (open/close fichier)
            print(args)            -> raccourci pour outstring sur canal 1
            Canal 1 = STDOUT (handle 1), Canal 2 = STDERR (handle 2)
            Nouvelle ligne : CALL _A60RT_NEWLINE (ecriture CR+LF)

  TODO 13 - INSTRUCTIONS CONDITIONNELLES (IF/THEN/ELSE)
            ParseIfStmt : IF expr THEN stmt [ELSE stmt]
              Emission TEST AX,AX / JZ pour condition fausse
              Labels : _A60L_ELSE_N, _A60L_ENDIF_N
            IF sans ELSE : saut vers _A60L_ENDIF_N si faux
            IF avec ELSE : saut vers _A60L_ELSE_N si faux,
              JMP _A60L_ENDIF_N apres branche THEN
            Attention : ambiguite du "dangling else" en Algol 60
              Resolution : ELSE se lie au IF le plus proche non encore ferme
            Expression conditionnelle : IF b THEN e1 ELSE e2
              Meme logique de saut, resultat dans AX

  TODO 14 - BOUCLE FOR (STEP/UNTIL/WHILE)
            ParseForStmt : FOR var := elements DO stmt
            Forme STEP/UNTIL : FOR i := lo STEP s UNTIL hi DO ...
              Initialiser i := lo
              Test : si s > 0 alors CMP i, hi / JG fin
                     si s < 0 alors CMP i, hi / JL fin
              Increment : ADD i, s apres chaque iteration
              Labels : _A60L_FTEST_N, _A60L_FINCR_N, _A60L_FEND_N
            Forme WHILE : FOR i := expr WHILE cond DO ...
              Affecter i := expr a chaque iteration
              Tester cond, si faux -> JMP fin
            Forme simple : FOR i := e1, e2, e3 DO ...
              Liste d elements : evaluer chaque element successivement
              Chaque element peut etre une valeur simple, STEP/UNTIL ou WHILE
            Combinaison d elements : FOR i := 1, 3 STEP 2 UNTIL 9, 20 DO ...
              Traiter chaque element de la liste dans l ordre

  TODO 15 - GOTO ET ETIQUETTES
            Declarations d etiquettes : nom: au debut d une instruction
            Table des etiquettes : LabelTab, LabelAdd, LabelFind
            GOTO label : JMP _A60L_label
            GO TO label : synonyme de GOTO (deux mots)
            GOTO expression designationnelle : GOTO switch[expr]
              Evaluer l expression, obtenir l adresse du label
              JMP indirect : JMP [BX] ou CALL/RET selon implementation
            Etiquettes locales a un bloc : portee du BEGIN/END englobant
            Restriction : GOTO ne peut pas sauter a l interieur d un bloc
              depuis l exterieur (seulement vers un bloc englobant)
            Etiquettes en tant que parametres : passage de label a une procedure

  TODO 16 - BLOCS (BEGIN/END) ET INSTRUCTIONS COMPOSEES
            ParseBlock : BEGIN declarations; instructions END
            Declarations au debut du bloc uniquement (avant les instructions)
            Ordre des declarations : types, puis variables, puis procedures
            Portee lexicale : les declarations sont locales au bloc
              SymEnterScope au BEGIN, SymLeaveScope au END
            Variables locales du bloc : allocations sur la pile (SUB SP, n)
              Liberation a la sortie du bloc (ADD SP, n ou MOV SP,BP)
            Instruction composee : BEGIN stmt; stmt; ...; stmt END
              Sans declarations, c est une simple sequence
            Bloc programme principal : le bloc le plus externe
              Genere le point d entree _A60P_Main
            Blocs imbriques : portees imbriquees multiples avec
              recherche des variables dans la chaine de portees

  TODO 17 - TABLEAUX (ARRAY) A BORNES DYNAMIQUES
            Declaration : ARRAY id[lo:hi] ou ARRAY id[lo1:hi1, lo2:hi2]
              Bornes : expressions entieres evaluees a l entree du bloc
              Multidimensionnel : indices separes par des virgules
            Types de tableaux : INTEGER ARRAY, REAL ARRAY, BOOLEAN ARRAY
            Allocation dynamique : taille = (hi-lo+1) * sizeof(element)
              Tableaux locaux : reserve sur la pile (SUB SP, taille)
              Tableaux globaux : reserve dans le segment DATA
            Acces par indice : arr[i] -> offset = (i - lo) * sizeof(elem)
              Acces multidimensionnel : linearisation row-major
              arr[i,j] -> offset = ((i-lo1)*(hi2-lo2+1) + (j-lo2)) * sizeof
            Verification de bornes : CMP index, lo / CMP index, hi
              -> erreur si hors bornes (optionnel, selon flag -r)
            Tableaux en parametres : passage par reference (adresse + descripteur)
              Descripteur : pointeur base, bornes inferieures, dimensions

  TODO 18 - DECLARATIONS DE PROCEDURES
            ParseProcDecl : [type] PROCEDURE nom(params); [VALUE params;]
              [specifications;] corps
            Specifications des parametres :
              INTEGER id, id; REAL id; BOOLEAN id;
              ARRAY id; PROCEDURE id; LABEL id; SWITCH id; STRING id
            Mot-cle VALUE : indique les parametres passes par valeur
              Les autres sont par nom par defaut (call by name)
            Procedures sans type : pas de valeur de retour (comme void)
            Procedures typees : INTEGER PROCEDURE, REAL PROCEDURE,
              BOOLEAN PROCEDURE -> resultat dans AX
              Retour de valeur : affectation au nom de la procedure
              ex : PROCEDURE f; f := expr (affecte la valeur de retour)
            Convention d appel : cdecl 16 bits
              Prologue : PUSH BP / MOV BP,SP / SUB SP, locals_size
              Epilogue : MOV SP,BP / POP BP / RET
            Procedures imbriquees : acces au cadre englobant via lien statique
              (display ou pointeur vers BP du cadre parent)

  TODO 19 - APPELS DE PROCEDURES ET PARAMETRES
            Appel de procedure : nom(arg1, arg2, ...)
            Parametres par valeur (VALUE) :
              Evaluer l argument, empiler la valeur sur la pile
              Le parametre formel est une copie locale
            Parametres par nom (defaut, call by name) :
              Passer un thunk : adresse d une sous-routine qui evalue
              l expression de l argument dans le contexte de l appelant
              Le parametre formel invoque le thunk a chaque acces
            Nombre de parametres : verification a la compilation
            Types des parametres : verification de compatibilite
            Appels recursifs : support natif via pile (pas de limite sauf memoire)
            Procedures comme parametres : passage de l adresse du code
              PROCEDURE p(f); PROCEDURE f; -> f passe comme pointeur

  TODO 20 - APPEL PAR NOM (THUNKS / CALL BY NAME)
            Concept : chaque acces au parametre formel reevalue l argument
              dans l environnement de l appelant
            Generation de thunks : pour chaque argument par nom,
              generer une sous-routine anonyme _A60T_N qui :
                1. Sauvegarde le contexte courant
                2. Restaure le contexte de l appelant (display/BP)
                3. Evalue l expression de l argument
                4. Retourne le resultat dans AX (valeur) ou BX (adresse)
                5. Restaure le contexte de l appele
            Thunk pour L-value : si le parametre est cible d affectation,
              le thunk retourne l adresse (BX) au lieu de la valeur
            Thunk pour R-value : si le parametre est lu,
              le thunk retourne la valeur (AX)
            Optimisation : si l argument est une variable simple,
              pas besoin de thunk, passage direct par reference
            Optimisation : si l argument est une constante,
              pas besoin de thunk, passage par valeur
            Jensen's device : FOR i := 1 STEP 1 UNTIL n DO s := s + V[i]
              ou V et s sont passes par nom -> acces dynamique correct
            Display : tableau de pointeurs vers les cadres de pile
              des portees englobantes pour acces aux variables non locales

  TODO 21 - DECLARATIONS SWITCH (AIGUILLAGES)
            Declaration : SWITCH sw := label1, label2, label3, ...
              Liste d expressions designationnelles (labels ou IF-THEN-ELSE labels)
            Acces : sw[expr] retourne le label a la position expr
              Indice base 1 : sw[1] = label1, sw[2] = label2, etc.
            Utilisation avec GOTO : GOTO sw[expr]
              Evaluer expr -> index dans la table -> JMP vers le label
            Implementation : table de mots dans DATA
              _A60S_sw DW OFFSET _A60L_label1, OFFSET _A60L_label2, ...
              Acces : MOV BX, index / DEC BX / SHL BX,1 / JMP [_A60S_sw + BX]
            Verification de bornes : index < 1 ou > n -> erreur ou no-op
            Expressions designationnelles conditionnelles dans la liste :
              SWITCH sw := L1, IF b THEN L2 ELSE L3, L4
              -> evaluer la condition pour determiner le label effectif

  TODO 22 - VARIABLES OWN (STATIQUES)
            Declaration : OWN INTEGER x; OWN REAL y; OWN BOOLEAN z;
              OWN ARRAY a[1:10]
            Semantique : la variable conserve sa valeur entre les appels
              de la procedure (equivalent a 'static' en C)
            Implementation : allocation dans le segment DATA au lieu de la pile
              Label : _A60O_NomProc_NomVar DW 0
            Initialisation : a zero (ou valeur par defaut) au debut du programme
              Pas de re-initialisation a chaque appel de procedure
            Variables OWN dans des blocs : la variable persiste entre
              les executions successives du bloc
            OWN ARRAY : tableau alloue dans DATA, bornes fixees au premier appel
              Les bornes ne changent pas aux appels suivants
            Distinction avec variables locales : locales sur pile,
              OWN dans DATA

  TODO 23 - EXPRESSIONS CONDITIONNELLES ET DESIGNATIONNELLES
            Expression conditionnelle : IF b THEN e1 ELSE e2
              Retourne une valeur : e1 si b est vrai, e2 sinon
              Type : le type commun de e1 et e2 (INTEGER, REAL, BOOLEAN)
              Emission : TEST AX,AX / JZ lbl_else / eval e1 / JMP lbl_end /
                lbl_else: eval e2 / lbl_end:
              Peut etre imbriquee : IF b1 THEN (IF b2 THEN e1 ELSE e2) ELSE e3
            Expression designationnelle : expression dont la valeur est un label
              Variable de type LABEL : stocke une adresse de code
              Element de switch : sw[expr] -> label
              Expression designationnelle conditionnelle :
                IF b THEN L1 ELSE L2 -> retourne un label
              Utilisation : GOTO (expression designationnelle)
            Distinction instruction vs expression :
              IF THEN ELSE peut etre instruction (sans valeur) ou expression
              Le contexte determine l interpretation

  TODO 24 - RUNTIME MINIMAL
            _A60RT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _A60RT_PRINTLN : _A60RT_PRINT + CR+LF via _A60_CRLF DB 13,10,0
            _A60RT_STRLEN(SI=str) : compte octets jusqu a 0 -> AX
            _A60RT_NUMTOSTR(AX=n, DI=buf) : entier signe -> ASCII (itoa)
            _A60RT_STRTONUM(SI=str) : ASCII -> entier -> AX (atoi)
            _A60RT_POWER(AX=base, BX=exp) : exponentiation entiere -> AX
            _A60RT_OUTINT(BX=canal, AX=n) : ecrire entier sur canal
            _A60RT_OUTSTR(BX=canal, SI=str) : ecrire chaine sur canal
            _A60RT_OUTBOOL(BX=canal, AX=b) : ecrire TRUE ou FALSE
            _A60RT_ININT(BX=canal) : lire entier depuis canal -> AX
            _A60RT_INCHAR(BX=canal) : lire caractere -> AL
            _A60RT_NEWLINE(BX=canal) : ecrire CR+LF
            _A60RT_ABS(AX=n) : valeur absolue -> AX
            _A60RT_SIGN(AX=n) : signe -> AX (-1, 0, 1)
            _A60RT_ENTIER(AX=n) : partie entiere (stub: identite sur entiers)
            _A60RT_CHKIDX(AX=idx, BX=lo, CX=hi) : verification bornes tableau
              -> erreur si hors bornes
            _A60RT_PANIC(SI=msg) : affiche message + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n emettre le runtime qu une seule fois
            Heap statique : _A60_HEAP DB 4096 DUP(0) + _A60_HEAPTOP DW 0

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _A60P_Main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseProgram ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _A60P_Main
            Fichiers SAMPLES\ALGOL60\ a creer :
              hello.a60   (outstring, variables, affectations)
              math.a60    (expressions arithmetiques, puissance, div)
              ifthen.a60  (IF/THEN/ELSE, expressions conditionnelles)
              forloop.a60 (FOR/STEP/UNTIL, FOR/WHILE, listes d elements)
              arrays.a60  (ARRAY, indices, bornes dynamiques, multi-dim)
              procs.a60   (PROCEDURE, fonctions, recursion, parametres)
              byname.a60  (call by name, Jensen's device, thunks)
              switch.a60  (SWITCH, GOTO switch[i], aiguillages)
              own.a60     (OWN variables, persistance entre appels)
              blocks.a60  (BEGIN/END, portees imbriquees, blocs)
            Smoke tests : AL60C86.EXE -v SAMPLES\ALGOL60\*.a60

  ============================================================ *)

Program AL60C86;

Begin
End.
