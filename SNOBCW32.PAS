{ ============================================================ }
{ SNOBCW32.PAS - Compilateur SNOBOL4 -> 80386 PE Win32        }
{ Free Pascal {$MODE TP}                                       }
{ Usage : SNOBCW32 source.sbl [options]                       }
{   (defaut)  -> source.exe  (PE32 autonome)                  }
{   -obj      -> source.obj  (COFF relocatable)               }
{   -asm      -> source.asm  (texte MASM/JWasm, optionnel)    }
{ ============================================================ }
{
  TODO 01 - STRUCTURE GENERALE DU COMPILATEUR
            Point d entree principal : lire les arguments de la ligne
              de commande, determiner le fichier source (.sbl),
              le mode de sortie (EXE par defaut, OBJ, ASM),
              et le nom du fichier de sortie (derive du source).
            Sections globales : constantes, types, variables,
              procedures du lexeur, du parseur et du codegen.
            Organisation : {$MODE TP}, pas de classes ni de generiques.

  TODO 02 - LEXER / ANALYSEUR LEXICAL
            Lecture ligne par ligne du source SNOBOL4.
            Chaque ligne suit la forme :
              [LABEL]  [SUJET PATTERN] [= expression] [:goto]
            Colonne 1 non-blanc = debut de label.
            Commentaires : ligne dont le premier caractere non-blanc est *.
            Marqueur de fin : -END- (ou END) en colonne 1 ou indenté.
            LexLine : decoupe une ligne en tokens pour le parseur.
            LexNextToken, CurTokType, CurTokStr globaux.

  TODO 03 - TYPES DE TOKENS
            TOK_EOF, TOK_EOL, TOK_COMMENT
            TOK_LABEL   : identificateur en colonne 1
            TOK_IDENT   : identificateur (variable ou fonction)
            TOK_STRING  : litteral entre apostrophes 'texte'
            TOK_INTEGER : suite de chiffres
            TOK_ASSIGN  : signe egal =
            TOK_COLON   : debut de controle de flux :
            TOK_LPAREN, TOK_RPAREN
            TOK_COMMA   : separateur d arguments de fonction
            TOK_END     : marqueur -END-
            TOK_AMPERS  : & (pour &OUTPUT &INPUT &TRIM etc.)
            Mots-cles : DEFINE RETURN

  TODO 04 - PARSER / ANALYSEUR SYNTAXIQUE
            ParseProgram : boucle principale ligne par ligne jusqu a -END-.
            ParseLine    : label optionnel + corps de statement + goto optionnel.
            ParseStatement :
              - Affectation simple : VAR = expr
              - Affectation &OUTPUT = expr
              - Pattern matching   : expr1 expr2  (sans =)
              - DEFINE(proto)
              - RETURN
              - Ligne vide ou commentaire
            ParseExpr    : sequence de termes concatenes par juxtaposition.
            ParseTerm    : litteral | variable | appel de fonction | &KEYWORD.
            ParseGoto    : :(L) :S(L) :F(L) et combinaisons :S(L1) :F(L2).

  TODO 05 - AST (ARBRE SYNTAXIQUE ABSTRAIT)
            Representation par table fixe TAstNode (pas de pointeurs).
            Champs : Kind, Tok, Text, Left, Right, FirstChild, NextSibling,
              Line, SymRef.
            Noeuds principaux :
              NK_PROGRAM, NK_STMT, NK_ASSIGN, NK_OUTPUT, NK_INPUT
              NK_PATTERN  : subject + pattern (matching)
              NK_CONCAT   : concatenation de termes
              NK_LITERAL  : chaine ou entier constant
              NK_VAR      : variable utilisateur
              NK_CALL     : appel de fonction integree ou utilisateur
              NK_DEFINE   : declaration de fonction
              NK_RETURN   : retour de fonction
              NK_GOTO_U / NK_GOTO_S / NK_GOTO_F : sauts

  TODO 06 - TABLE DES SYMBOLES
            Variables : table SymTable, champs Name/Kind/Offset/AsmName.
            Kinds : SK_VAR (variable globale chaine), SK_LABEL (etiquette),
              SK_FUNC (fonction utilisateur), SK_PARAM (parametre de fonction).
            Labels : enregistres en passe 1 avec leur adresse de codegen.
            Fonctions utilisateur : nom, label d entree, liste de parametres.
            Variables systeme : &OUTPUT (SK_SYS_OUT), &INPUT (SK_SYS_IN),
              &TRIM (SK_SYS_TRIM), &ANCHOR (SK_SYS_ANCHOR).
            FindSym, AddSym, GetOrAddVar.

  TODO 07 - PASSES DU COMPILATEUR
            Passe 1 (CollectLabels) : parcours du source, enregistrement
              de tous les labels et des DEFINE dans la table des symboles.
              Necessite de connaitre les labels avant la generation de code
              pour resoudre les forward references des gotos.
            Passe 2 (CodegenProgram) : generation de code instruction par
              instruction, resolution des fixups labels au fur et a mesure.
            Fixups : liste de (offset_dans_BinCode, nom_label) a resoudre
              apres la passe 2, comme dans PERLCW32.

  TODO 08 - GENERATION PE32 BINAIRE (.EXE)
            Sections : BinCode (.text RX), BinData (.data RW),
              BinRData (.rdata R), BinBss (.bss RW), idata (IAT).
            Tableaux d octets : BinCode[0..MAX_CODE], BinData[], BinRData[].
            BinEmit8, BinEmit32, BinEmitRef32 (fixup ABS32 ou REL32).
            BinDefineLabel, BinResolveFixups.
            WritePE : produire le fichier .exe complet avec headers PE32,
              section headers, sections et IAT, calcul dynamique des RVAs.
            Entry point _SNSTART. ImageBase $00400000.

  TODO 09 - RUNTIME EMBARQUE : VARIABLES ET MEMOIRE
            Variables SNOBOL globales = pointeurs vers chaines heap.
            Table _SNV_TABLE : tableau de MAX_VARS pointeurs (initialises 0).
            Chaque variable declaree recoit un index compile en dur.
            _SNRT_var_set(idx, ptr) : stocke ptr dans _SNV_TABLE[idx].
            _SNRT_var_get(idx) -> EAX : charge ptr ou ptr vers chaine vide.
            Allocation via HeapAlloc(GetProcessHeap, HEAP_ZERO_MEMORY, n).
            Chaine vide globale : _SN_EMPTY = octet 0 en .rdata.

  TODO 10 - RUNTIME EMBARQUE : OPERATIONS SUR CHAINES
            _SNRT_str_concat(s1, s2) cdecl -> EAX = nouvelle chaine.
              strlen(s1) + strlen(s2) + 1, HeapAlloc, memcpy x2.
            _SNRT_str_len(s) cdecl -> EAX = longueur entiere.
            _SNRT_int_to_str(n) cdecl -> EAX = ptr chaine.
              Conversion entier -> chaine decimale (sans libc).
            _SNRT_str_to_int(s) cdecl -> EAX = valeur entiere.
              Parsing decimal simple, 0 si non numerique.
            _SNRT_str_eq(s1, s2) cdecl -> EAX = 1 si egaux, 0 sinon.

  TODO 11 - RUNTIME EMBARQUE : ENTREES / SORTIES
            _SNRT_output(str_ptr) cdecl :
              GetStdHandle(-11) si pas encore fait, WriteFile(stdout, s, len),
              WriteFile(stdout, '\r\n', 2).
            _SNRT_input() -> EAX = ptr chaine :
              ReadFile(GetStdHandle(-10), buf, MAX_LINE), stopper au \n,
              copier dans heap, retourner ptr.
            &OUTPUT = expr : codegen evalue expr -> EAX, appelle _SNRT_output.
            &INPUT          : codegen appelle _SNRT_input -> EAX.

  TODO 12 - RUNTIME EMBARQUE : PATTERN MATCHING
            Pattern SNOBOL4 v1 : correspondance de sous-chaine simple.
            _SNRT_pat_match(subject, pattern) cdecl -> EAX = 1/0.
              Recherche lineaire : pour chaque position i dans subject,
              comparer les strlen(pattern) premiers caracteres.
            Si EAX=1 : succes -> branche :S ; sinon echec -> branche :F.
            Extension future : ancres (^, $), classes de caracteres,
              operateurs SNOBOL (ARB, REM, SPAN, BREAK, ANY, NOTANY).

  TODO 13 - RUNTIME EMBARQUE : PREDICATS NUMERIQUES
            LT(a,b), LE(a,b), GT(a,b), GE(a,b), EQ(a,b), NE(a,b).
            Chaque predicat : convertir s1 et s2 en entiers via str_to_int,
              comparer, retourner EAX=1 (succes) ou EAX=0 (echec).
            _SNRT_pred_lt/le/gt/ge/eq/ne(s1, s2) cdecl -> EAX 1/0.
            En cas de succes, l appel de predicat ne modifie pas la variable
              cible (pas de valeur de retour utile) ; seul le flag compte.

  TODO 14 - RUNTIME EMBARQUE : PREDICATS DE CHAINES
            IDENT(s1, s2) : egalite exacte de chaines -> EAX=1/0.
              Appel interne a _SNRT_str_eq.
            DIFFER(s1, s2) : inegalite de chaines -> EAX = NOT IDENT.
            SIZE(s) -> EAX = ptr vers chaine representant la longueur.
              Appeler _SNRT_str_len puis _SNRT_int_to_str.
            Utilisation de SIZE dans une expression : valeur inseree comme
              chaine dans la concatenation.

  TODO 15 - CONTROLE DE FLUX : GOTO ET LABELS
            :(LABEL)  : JMP _SNL_LABEL (saut inconditionnel).
            :S(LABEL) : TEST EAX,EAX ; JNZ _SNL_LABEL (si succes).
            :F(LABEL) : TEST EAX,EAX ; JZ  _SNL_LABEL (si echec).
            Combinaisons : :S(L1) :F(L2) sur la meme instruction.
            Si pas de :F, echec = continuer a la ligne suivante.
            Si pas de :S, succes = continuer a la ligne suivante.
            BinJccLabel(CC, name), BinJmpLabel(name) avec fixups REL32.
            Labels emis comme BinDefineLabel('_SNL_' + LabelName).

  TODO 16 - FONCTIONS UTILISATEUR (DEFINE ET RETURN)
            DEFINE('NOM(P1,P2,...)') : enregistre NOM dans SymTable avec
              sa liste de parametres ; l entree de la fonction = label NOM.
            Appel NOM(a1,a2) : evaluer les args, stocker dans variables
              locales de la fonction (via frame EBP), JMP _SNL_NOM.
            Variables locales = parametres formels : alloues sur la pile
              comme dans PERLCW32 (SCOPE_LEXICAL, offset EBP negatif).
            RETURN : retour au site d appel via RET, valeur dans variable
              de meme nom que la fonction (convention SNOBOL4).
            Valeur retournee : variable NOM = valeur assignee avant RETURN.

  TODO 17 - CODEGEN : AFFECTATION ET CONCATENATION
            VAR = expr : BinCodegenExpr(expr) -> EAX = ptr chaine ;
              MOV [_SNV_TABLE + idx*4], EAX (ou via _SNRT_var_set).
            Concatenation : sequence de termes, appeler _SNRT_str_concat
              de gauche a droite ; resultat intermediaire en EAX.
            Terme litteral : stocker la chaine dans .rdata, MOV EAX, VA.
            Terme variable : MOV EAX, [_SNV_TABLE + idx*4] (ou var_get).
            Terme appel de fonction : generer l appel, EAX = resultat.

  TODO 18 - CODEGEN : PATTERN MATCHING ET BRANCHEMENT
            Instruction `SUBJECT PATTERN :S(L1) :F(L2)` :
              1. BinCodegenExpr(SUBJECT) -> EAX ; PUSH EAX (arg2).
              2. BinCodegenExpr(PATTERN) -> EAX ; PUSH EAX (arg1).
              3. CALL _SNRT_pat_match ; ADD ESP,8.
              4. TEST EAX,EAX.
              5. Si :S defini : JNZ _SNL_L1.
              6. Si :F defini : JZ  _SNL_L2.
              7. Sinon       : continuer.
            Le meme schema s applique aux predicats LT/EQ/IDENT etc.

  TODO 19 - CODEGEN : FONCTIONS INTEGREES
            Reconnaitre en parsant le nom de fonction : IDENT DIFFER SIZE
              LT LE GT GE EQ NE.
            Generer l appel au _SNRT_pred_* ou _SNRT_* correspondant.
            Gerer le cas SIZE dans une expression de concatenation :
              appel _SNRT_str_len + _SNRT_int_to_str, EAX = ptr chaine.
            Generer l appel aux fonctions utilisateur : evaluer les args,
              les passer en stack frame (CDECL interne), JMP vers label.

  TODO 20 - TABLE IAT ET IMPORTS WIN32
            kernel32.dll (minimum) :
              GetStdHandle, WriteFile, ReadFile, ExitProcess,
              HeapAlloc, HeapFree, GetProcessHeap.
            Structure IAT identique a PERLCW32 : section .idata,
              IMAGE_IMPORT_DESCRIPTOR, thunks d importation.
            BinCallImport('_GetStdHandle@4', 0) etc.
            BinEmitImport : emettre les entrees IAT dans BinIData[].
            BinWriteImports : finaliser la section .idata avant WritePE.

  TODO 21 - SORTIE .OBJ (COFF WIN32)
            Mode -obj : produire un fichier .obj COFF relocatable.
            IMAGE_FILE_HEADER : machine i386 (0x014C), sections, symtable.
            Sections : .text (code), .data (vars), .rdata (litteraux).
            Table des symboles COFF : entry point, labels exportes, imports.
            Table des relocations par section : R_I386_DIR32 pour abs32,
              R_I386_REL32 pour rel32.
            Table des chaines (string table) pour noms > 8 caracteres.
            Permettre le linkage avec link.exe ou jwlink.

  TODO 22 - SORTIE .ASM (MASM/JWASM) - OPTIONNEL
            Active uniquement avec le parametre -asm explicite.
            En-tete : .386 .MODEL FLAT,STDCALL OPTION CASEMAP:NONE
            Sections : .DATA, .CONST (.RDATA), .CODE
            EXTRN pour les imports kernel32.
            Emettre chaque instruction comme texte lisible avec commentaires.
            Labels : _SNL_XXX PROC / _SNL_XXX: selon le type.
            Ecriture dans un fichier texte ASCII via Assign/Rewrite/WriteLn.

  TODO 23 - GESTION DES ERREURS ET DIAGNOSTICS
            Erreurs fatales : fichier source introuvable, syntaxe invalide,
              label reference mais non defini, DEFINE mal forme.
            Avertissements : variable lue avant d etre assignee,
              label defini mais jamais reference, RETURN hors fonction.
            Format des messages : 'SNOBCW32: erreur ligne N: message'.
            Stopper la compilation a la premiere erreur fatale.
            Code de retour : 0 si succes, 1 si erreur (ExitProcess).

  TODO 24 - TESTS ET VALIDATION - SAMPLES SNOBOL
            hello.sbl        : &OUTPUT = 'BONJOUR MONDE'
            test01_hello     : meme avec indentation standard
            test02_vars      : variables, concatenation multi-termes
            test03_boucle    : boucle avec IDENT + :S/:F
            test03b_boucle   : boucle avec pattern matching + :(label)
            test04_pattern   : pattern matching de sous-chaine, :S :F
            test05_types     : LT, IDENT, SIZE, branches S/F enchainées
            test05b_types    : IDENT, pattern, branches S/F complexes
            test06_define    : DEFINE + appel + RETURN + valeur retournee
            test07_arith     : LT GT EQ NE + SIZE + EQ(SIZE(x),n)
            Chaque test documente sa sortie attendue en commentaire.

  TODO 25 - EXTENSIONS FUTURES (HORS SCOPE V1)
            Arithmetique directe : + - * / dans les expressions
              (actuellement simulee par predicats et SIZE).
            Operateurs de pattern avances : ARB REM SPAN BREAK ANY NOTANY.
            Tableaux SNOBOL (T = TABLE()).
            &ANCHOR : forcer le pattern matching en debut de chaine.
            &TRIM : supprimer les espaces en fin de chaine sur &OUTPUT.
            &STNO : numero de statement courant.
            Mode -obj compatible avec MASM/JWASM pour lien mixte.
            Optimisation : variables frequemment utilisees en registres.
}

Program SNOBCW32;
{ Compilateur SNOBOL4 -> 80386 PE Win32 - a implementer selon les TODOs }
BEGIN
END.
