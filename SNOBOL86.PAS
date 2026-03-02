{ ============================================================================
  SNOBOL86.PAS  -  Compilateur SNOBOL 4 -> Assembleur 8086 (MASM/TASM)
  Langage hote : Turbo Pascal / Free Pascal
  Cible        : .MODEL SMALL, MS-DOS, INT 21h
  Auteur       : (a completer)
  ============================================================================

  APERCU DU LANGAGE SNOBOL 4
  ---------------------------
  SNOBOL 4 (StriNg Oriented and symBOlic Language) est un langage de
  manipulation de chaines invente aux Bell Labs (1967).
  Une instruction SNOBOL a la forme generale :

      LABEL   SUJET   PATRON = REMPLACEMENT   :GOTO

  - LABEL      : etiquette optionnelle (colonne 1)
  - SUJET      : variable dont le contenu est inspecte/modifie
  - PATRON     : expression de filtrage (pattern matching)
  - REMPLACEMENT : chaine substituee dans le sujet apres matching reussi
  - GOTO       : branchement conditionnel :S(lbl) :F(lbl) ou :(lbl)

  Types de donnees : STRING, INTEGER, REAL, PATTERN, TABLE, ARRAY.
  Gestion memoire  : garbage collection automatique (heap dynamique).
  Caractere fin    : ligne contenant "-END-".

  LISTE DES 25 TODOS
  ------------------

  TODO 01 - EN-TETE, CONSTANTES ET OPTIONS DU COMPILATEUR
    Definir les constantes globales (MAX_SYM, MAX_LABEL, MAX_PAT,
    MAX_STR, MAX_SUB, MAX_LIT, MAX_BUILTIN, niveaux de debug, etc.).
    Definir les options de compilation ($MODE, $LIST, $ERRORS).
    Preparer le squelette {$A-}{$I-} et les directives FPC.

  TODO 02 - TYPES FONDAMENTAUX ET STRUCTURES DE DONNEES
    Definir les enumerations : TokType (TOK_IDENT, TOK_INTEGER,
    TOK_REAL, TOK_STRING, TOK_EOF, TOK_LPAREN, TOK_RPAREN, TOK_COMMA,
    TOK_EQ, TOK_COLON, TOK_AT, TOK_BANG, TOK_AMP, TOK_PIPE, ...).
    Definir les kinds de valeur runtime : VK_STR, VK_INT, VK_REAL,
    VK_PAT, VK_TABLE, VK_ARRAY, VK_UNDEF.
    Definir les kinds de pattern : PK_LIT, PK_ANY, PK_NOTANY, PK_SPAN,
    PK_BREAK, PK_LEN, PK_POS, PK_RPOS, PK_TAB, PK_RTAB, PK_REM,
    PK_ARB, PK_ARBNO, PK_ALT, PK_CONCAT, PK_ASSIGN, PK_IMMED.

  TODO 03 - TABLES : SYMBOLES, LABELS, PATTERNS, FONCTIONS
    SymTable  : nom, kind (SYM_VAR/SYM_CONST/SYM_BUILTIN/SYM_FUNC),
                type runtime, asm_label, init_str, init_num.
    LabelTable: nom Ada -> label ASM (_SB_lbl), present flag.
    PatTable  : id, kind, operande1 (string ou index), operande2,
                pat_left, pat_right (arbre de patterns).
    FuncTable : nom, ndef (nb args), nloc (nb locals), label ASM,
                params[], locals[].

  TODO 04 - DESCRIPTEUR DE CHAINE RUNTIME (STRING DESCRIPTOR)
    Un descripteur est un DWORD en memoire : [ptr:WORD | len:WORD].
    Definir les macros/helpers ASM emis :
      _RT_STR_PTR  : MOV BX, [DI]   ; BX <- pointeur donnees
      _RT_STR_LEN  : MOV CX, [DI+2] ; CX <- longueur
    Definir la zone DATA pour le heap dynamique (_HEAP_BASE, _HEAP_PTR,
    _HEAP_END) et la taille par defaut (8 Ko).

  TODO 05 - LEXEUR : LECTURE SOURCE ET TOKENISATION
    Gerer les lignes SNOBOL (continuite par '+'/'-' en col 1,
    commentaire par '*' en col 1, fin par ligne vide ou "-END-").
    Extraire : label (col 1-7), sujet (tok ident), patron, remplacement,
    goto (:S(...) :F(...) :(...)  :S(lbl)F(lbl)).
    Reconnaitre : litteaux chaine delimitee par apostrophe ou guillemet,
    entiers, reels, identifiants, operateurs de pattern.

  TODO 06 - TABLE DES MOTS-CLES ET IDENTIFICATEURS PREDEFINIS
    Fonctions integrees : SIZE, SUBSTR, DUPL, REPLACE, TRIM, LPAD, RPAD,
    REVERSE, UPPER, LOWER, CONVERT, DATATYPE, IDENT, DIFFER,
    INTEGER (predicat), REAL, NUMERIC, CHAR, ORD, DATE, TIME.
    Predicats de comparaison : LT, LE, GT, GE, EQ, NE.
    Variables systeme : &ALPHABET, &ANCHOR, &DUMP, &FAIL, &FENCE,
    &FNCODE, &FULLSCAN, &INPUT, &OUTPUT, &STCOUNT, &STFAIL,
    &STLIMIT, &SUBJECT, &SUCCESS, &TRIM.
    Registrer tous ces noms dans SymTable au demarrage.

  TODO 07 - GESTION DES ERREURS ET DES AVERTISSEMENTS
    Procedures : Error(msg), Warning(msg), ErrorTok(msg), FatalError(msg).
    Compteurs err_count, warn_count.
    Affichage numero de ligne source, texte fautif.
    Procedure BilanCompilation : resume final.

  TODO 08 - GENERATION D'EN-TETE ASM ET SEGMENT .DATA
    GenHeader   : commentaire, .MODEL SMALL, .STACK 256.
    GenDataSeg  : emettre _HEAP_BASE, _HEAP_PTR, _HEAP_END,
                  _SB_CRLF, _SB_EMPTY (chaine vide), _SB_NEWLINE,
                  toutes les chaines litterales (pool de constantes),
                  tous les descripteurs de variables globales.
    GenPredefinedData : constantes &ALPHABET (256 chars), &SUCCESS="",
                  &FAIL (sentinel speciale), &FNCODE DW 0.

  TODO 09 - GENERATION DU SEGMENT .CODE ET POINT D'ENTREE
    GenCodeHeader : .CODE, etiquette START:, init DS/ES,
                    appel _SB_INIT_HEAP, appel _SB_INIT_IO,
                    JMP vers premiere instruction du programme.
    GenFooter     : etiquette _SB_END_PROG: , INT 21h AH=4Ch,
                    directive END START.
    Gestion du label special "-END-" : branchement vers _SB_END_PROG.

  TODO 10 - RUNTIME : GESTION DE LA MEMOIRE (HEAP)
    Emettre _SB_ALLOC(cx=nb_bytes) -> BX=ptr ou FAIL si OOM.
    Emettre _SB_NEWSTR(cx=len) -> DI=descripteur alloue.
    Emettre _SB_COPYSTR(SI=src_desc, DI=dst_desc).
    Emettre _SB_CONCATSTR(DI=d1, SI=d2) -> DX=nouveau descripteur.
    Note : pas de GC en v1 - heap monotone, OOM = erreur fatale.

  TODO 11 - RUNTIME : OPERATIONS SUR LES CHAINES
    _RT_STRLEN   : longueur d'un descripteur -> CX.
    _RT_STRNCPY  : copier CX caracteres de [SI] vers [DI].
    _RT_STRCMP   : comparer deux descripteurs -> ZF/CF.
    _RT_SUBSTR   : extraire sous-chaine (pos 1-base, longueur).
    _RT_DUPL     : dupliquer une chaine N fois.
    _RT_REPLACE  : remplacer occurrences (table de traduction).
    _RT_TRIM     : supprimer blancs en fin de chaine.
    _RT_LPAD, _RT_RPAD : cadrage avec caractere remplissage.
    _RT_REVERSE  : inverser une chaine.
    _RT_UPPER, _RT_LOWER : conversion casse.

  TODO 12 - RUNTIME : CONVERSIONS ET ARITHMETIQUE
    _RT_STR2INT  : convertir descripteur ASCII -> AX (entier signe).
    _RT_INT2STR  : AX -> nouveau descripteur chaine.
    _RT_STR2REAL : convertir descripteur -> flottant 16.16 (DX:AX).
    _RT_REAL2STR : flottant -> descripteur chaine.
    _RT_IADD, _RT_ISUB, _RT_IMUL, _RT_IDIV : arithmetique entiere.
    _RT_RADD, _RT_RSUB, _RT_RMUL, _RT_RDIV : arithmetique reelle 16.16.
    _RT_ICOMPARE : LT/LE/GT/GE/EQ/NE sur entiers -> CF/ZF.
    _RT_RCOMPARE : idem sur reels.

  TODO 13 - RUNTIME : TABLES (ASSOCIATIVES)
    Representation : vecteur de paires (cle_desc, val_desc) alloue
    sur le heap, avec facteur de chargement et rehashing lineaire.
    _RT_TABLE_NEW(cx=taille_initiale) -> BX=ptr table.
    _RT_TABLE_GET(BX=table, DI=cle_desc) -> DX=val_desc / FAIL.
    _RT_TABLE_SET(BX=table, DI=cle_desc, SI=val_desc).
    _RT_TABLE_DEL(BX=table, DI=cle_desc).

  TODO 14 - RUNTIME : TABLEAUX (ARRAYS)
    Representation : header (dimensions, bornes) + vecteur de descripteurs.
    _RT_ARRAY_NEW(nb_dims, bornes[]) -> BX=ptr array.
    _RT_ARRAY_GET(BX=array, index_list) -> DX=val_desc.
    _RT_ARRAY_SET(BX=array, index_list, DI=val_desc).
    Support tableau 1D uniquement en v1, extension N-D en v2.

  TODO 15 - PARSER : STRUCTURE D'UNE INSTRUCTION SNOBOL
    Lire une ligne source decomposee en :
      ParseLabel    -> enregistre etiquette si presente.
      ParseSubject  -> variable ou acces tableau/table.
      ParsePattern  -> expression de patron (peut etre vide).
      ParseEq       -> si '=' present, ParseReplacement.
      ParseGoto     -> :S(..) :F(..) ou :(..) en fin.
    Structure TInstruction : label, subject, has_pat, pat_idx,
                has_repl, repl_expr, goto_s, goto_f.

  TODO 16 - PARSER ET CODEGEN : AFFECTATION SIMPLE (SANS PATRON)
    Instruction de la forme :  X = expression
    Evaluer l'expression droite (chaine, entier, appel de fonction,
    concatenation par espace).
    Emettre : calcul de la valeur -> descripteur en DI,
              _SB_STORE_VAR(var_asm_label, DI).
    Gerer l'affectation a une variable indexee : X<i> = val.

  TODO 17 - CODEGEN : PATTERN MATCHING DE BASE
    Pour chaque kind de patron :
      PK_LIT    : _RT_MATCH_LIT(sujet, pos, lit_desc) -> S/F + new_pos.
      PK_ANY    : _RT_MATCH_ANY(sujet, pos, set_desc).
      PK_NOTANY : _RT_MATCH_NOTANY(sujet, pos, set_desc).
      PK_SPAN   : _RT_MATCH_SPAN(sujet, pos, set_desc).
      PK_BREAK  : _RT_MATCH_BREAK(sujet, pos, set_desc).
      PK_LEN    : _RT_MATCH_LEN(sujet, pos, n).
      PK_POS    : _RT_MATCH_POS(sujet, pos, n) -> succes si pos=n.
      PK_RPOS   : _RT_MATCH_RPOS(sujet, pos, n).
      PK_TAB    : _RT_MATCH_TAB(sujet, pos, n) -> avancer jusqu'a n.
      PK_RTAB   : _RT_MATCH_RTAB(sujet, pos, n).
      PK_REM    : _RT_MATCH_REM -> toujours succes, consume le reste.
      PK_ARB    : non-deterministe, tentatives successives (backtrack).
      PK_ARBNO  : repetition d'un sous-patron (a planifier).

  TODO 18 - CODEGEN : OPERATEURS DE PATRON (ALT, CONCAT, ASSIGN)
    PK_CONCAT  : evaluer patron gauche, puis droit si succes.
    PK_ALT     : evaluer patron gauche ; si echec, essayer droit.
    PK_ASSIGN  : affecter la sous-chaine matchee a une variable
                 PATRON $ VAR (assign immediate) ou PATRON . VAR
                 (assign apres matching complet).
    PK_IMMED   : assignation immediate via $.
    Gestion du curseur de position (register SI ou variable locale).
    Mode ANCHOR (&ANCHOR = 1) : desactiver le deplacement automatique.

  TODO 19 - CODEGEN : GOTO ET BRANCHEMENTS SUCCES/ECHEC
    Generer les branchements :
      :S(label) -> JMP si matching reussi.
      :F(label) -> JMP si matching echoue.
      :(label)  -> JMP inconditionnel.
      Absence de goto -> instruction suivante.
    Label special RETURN, FRETURN, NRETURN pour les fonctions.
    Label special END -> fin de programme.
    Resolution en deux passes : forward refs collectees, resolues apres.

  TODO 20 - CODEGEN : FONCTIONS PREDEFINIES (APPELS)
    Pour chaque builtin : emettre PUSH args, CALL _RT_xxx, recup resultat.
    SIZE(s)        -> CX = longueur du descripteur s.
    SUBSTR(s,i,n)  -> DI = nouveau descripteur sous-chaine.
    DUPL(s,n)      -> DI = s repete n fois.
    REPLACE(s,t,u) -> DI = s avec remplacement table t par u.
    TRIM(s)        -> DI = s sans blancs finaux.
    CHAR(n)        -> DI = chaine d'un caractere.
    ORD(s)         -> AX = code ASCII premier caractere.
    CONVERT(v,t)   -> DI = valeur convertie en type t.
    DATATYPE(v)    -> DI = nom du type ('STRING', 'INTEGER'...).
    DATE, TIME     -> DI = chaine date/heure (INT 21h AH=2Ah/2Ch).

  TODO 21 - PARSER ET CODEGEN : DEFINITION DE FONCTIONS (DEFINE)
    DEFINE('nom(p1,p2,...)', 'entry_label')
    Enregistrer dans FuncTable : nb params, nb locals, label.
    A l'entree d'une fonction :
      prologue : PUSH BP / MOV BP,SP / alloc locals.
      lier les descripteurs des arguments (BP+offset).
    A la sortie (RETURN / FRETURN / NRETURN) :
      RETURN  -> retourner le descripteur resultat, succes.
      FRETURN -> retourner, signaler echec.
      NRETURN -> retourner NULL (pas de valeur).
    Appel de fonction utilisateur : PUSH args, CALL _SB_FUNC_xxx.

  TODO 22 - CODEGEN : PREDICATS ET OPERATEURS DE COMPARAISON
    LT(x,y) / LE / GT / GE / EQ / NE : comparaison numerique.
    IDENT(x,y) / DIFFER(x,y) : comparaison de chaines.
    INTEGER(x) / REAL(x) / NUMERIC(x) : predicats de type.
    Chaque predicat returnne sa valeur si vrai, FAIL sinon.
    Emettre : CALL _RT_LT / _RT_LE ... suivi de JNZ _$F(gotoF).

  TODO 23 - GESTION DES VARIABLES SYSTEME (&xxx)
    &ANCHOR  DW 0   : mode ancrage (0 = libre, 1 = ancre a pos 0).
    &TRIM    DW 0   : trim auto de l'entree.
    &STLIMIT DW 50000 : limite iterations.
    &STCOUNT DW 0   : compteur iterations (incremente a chaque instr).
    &OUTPUT  : ecriture automatique sur sortie standard si affecte.
    &INPUT   : lecture automatique sur entree standard.
    Emettre en .DATA : _SB_VAR_ANCHOR, _SB_VAR_TRIM, etc.
    Intercepter les affectations a ces variables pour appel runtime.

  TODO 24 - GESTION DE L'ENTREE/SORTIE (INPUT / OUTPUT)
    Lecture : _RT_READLINE -> DI=descripteur chaine ligne lue (INT 21h
              AH=0Ah), echec si EOF.
    Ecriture : _RT_WRITELINE(DI) -> afficher la chaine + CRLF.
    &INPUT  : variable lecture-seule, declenchant _RT_READLINE a chaque
              evaluation.
    &OUTPUT : variable ecriture-seule, declenchant _RT_WRITELINE a chaque
              affectation.
    INPUT   : fichier d'entree (stub : stdin uniquement en v1).
    OUTPUT  : fichier de sortie (stub : stdout uniquement en v1).

  TODO 25 - PROCEDURE COMPILE ET ORCHESTRATION DEUX PASSES
    Passe 1 : lire et parser toutes les instructions, construire
              SymTable / LabelTable / FuncTable, collecter les literals,
              generer le code intermediaire dans un fichier temporaire.
    Passe 2 : GenHeader -> GenDataSeg (tous les descripteurs et
              constantes) -> GenCodeHeader -> copier code temporaire ->
              GenBuiltinRuntime -> GenStringRuntime -> GenHeapRuntime ->
              GenTableRuntime -> GenFooter.
    Resolution des forward refs de labels entre les deux passes.
    Procedure BilanCompilation : afficher stats (symboles, labels,
              patterns, fonctions, erreurs, avertissements).
    Valider ParamStr(1)=source.SBL, deduire nom .ASM de sortie.

  ============================================================================ }

Program SNOBOL86;

{ A implementer selon les 25 TODOs ci-dessus. }

Begin
End.
