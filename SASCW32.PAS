{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur SAS vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

{  TODO 01 - STRUCTURE GENERALE DU COMPILATEUR
            Point d entree principal : lire les arguments de la ligne
              de commande, determiner le fichier source (.sas),
              le mode de sortie (EXE par defaut, OBJ avec -obj, ASM
              uniquement si -asm est explicitement precise),
              et le nom du fichier de sortie (derive du source).
            Phases : (1) macro-preprocesseur, (2) lexer, (3) parseur,
              (4) codegen, (5) ecriture du fichier de sortie.
            Organisation : $MODE TP, pas de classes ni de generiques.
            Sections globales : constantes, types, variables,
              procedures du macro-preprocesseur, du lexeur,
              du parseur et du codegen.

  TODO 02 - MACRO-PREPROCESSEUR : %LET ET SUBSTITUTION &var
            Phase 1 independante : parcourir le source SAS avant le lexer.
            %LET nom = valeur ; : stocker dans table MacroVarTable
              (champs : Name, Value, IsGlobal).
            %GLOBAL nom : declarer la variable dans la portee globale.
            %LOCAL nom  : declarer la variable dans la portee locale
              (a l interieur d une definition %MACRO).
            Substitution de &nom et &&nom dans tout texte SAS :
              remplacer &nom par sa valeur avant la tokenisation.
            Macro-variables automatiques : &sysdate, &systime, &sysver
              (valeurs constantes figees a la compilation).
            %PUT texte : emettre texte (apres substitution &) dans le log
              de compilation (WriteLn standard).

  TODO 03 - MACRO-PREPROCESSEUR : %MACRO/%MEND, %IF/%THEN/%ELSE, %DO/%END
            %MACRO nom(p1, p2, ...) ; corps ; %MEND nom ;
              Stocker le corps brut dans MacroDefTable (champs : Name,
              Params, Body).
            Appel %nom(a1, a2) : lier les parametres formels aux
              valeurs effectives, substituer dans le corps, emettre
              le texte resultant dans le flux de compilation.
            %IF cond %THEN action ; %ELSE action ;
              Evaluer cond comme expression macro (comparaison de
              chaines apres substitution &), emettre l action choisie.
            %DO ; corps ; %END ; : emettre le corps inconditionnellement.
            %DO var = debut %TO fin ; corps ; %END ; :
              boucle macro iterative, deroulee au moment du preprocessing.
            FindMacroDef, CallMacro, EvalMacroCond.

  TODO 04 - LEXER / ANALYSEUR LEXICAL
            Lecture du source SAS (apres expansion macro) ligne par ligne.
            Commentaires de bloc : /* ... */ (multilignes possibles).
            Commentaires de ligne : * texte ; (debut de statement).
            Insensibilite a la casse : mots-cles et noms de datasets
              en majuscules en interne (UpCase systematique).
            LexNextToken : avancer dans le flux de caracteres,
              remplir CurTokType et CurTokStr globaux.
            Gestion des chaines entre apostrophes 'texte' et guillemets
              "texte" (avec substitution & dans les doubles guillemets).
            Operateurs multi-caracteres : ** (puissance), || (concat),
              >=, <=, ^=, ~= (differents de).

  TODO 05 - TYPES DE TOKENS
            TOK_EOF, TOK_EOL
            TOK_IDENT   : nom de variable, dataset, fonction, option
            TOK_STRING  : litteral entre apostrophes ou guillemets
            TOK_INTEGER : suite de chiffres (pas de virgule)
            TOK_FLOAT   : nombre avec point decimal ou exposant
            TOK_ASSIGN  : signe egal =
            TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH
            TOK_STARSTAR : ** (puissance)
            TOK_CONCAT  : || (concatenation de chaines)
            TOK_LPAREN, TOK_RPAREN, TOK_LBRACE, TOK_RBRACE
            TOK_SEMICOL : point-virgule (fin de statement)
            TOK_DOT     : . (fin de nom de format, FIRST./LAST.)
            TOK_COMMA   : separateur d arguments ou de listes
            TOK_LT, TOK_LE, TOK_GT, TOK_GE, TOK_EQ, TOK_NE
            TOK_AND, TOK_OR, TOK_NOT
            TOK_MACRO_VAR : &nom (variable macro non resolue)
            Mots-cles DATA : DATA RUN PROC QUIT SET MERGE BY
              OUTPUT DELETE STOP RETAIN INPUT INFILE FILE PUT
              ARRAY DO WHILE UNTIL TO BY END IF THEN ELSE
              SELECT WHEN OTHERWISE GOTO LEAVE CONTINUE
              FORMAT FIRST LAST UPDATE

  TODO 06 - PARSER : STRUCTURE GLOBALE DU PROGRAMME SAS
            ParseProgram : boucle principale jusqu a EOF.
              Chaque iteration reconnait soit un DATA step,
              soit un PROC step, soit un statement macro global.
            ParseDataStep : DATA nom1 nom2 ... ; corps ; RUN ;
              Capturer le ou les noms de datasets de sortie.
              ParseDataStepBody : boucle sur les statements jusqu a RUN.
            ParseProcStep : PROC nom options ; sous-commandes ; RUN | QUIT ;
              Dispatcher vers ParseProcPrint, ParseProcMeans,
              ParseProcSort, ParseProcFreq, ParseProcFormat,
              ou ParseProcGeneric (PROC inconnu = avertissement).
            ParseOptions : paires CLE=VALEUR ou drapeaux apres le nom PROC.
            ParseSubCmd : sous-commandes VAR, BY, TABLES, TITLE, FOOTNOTE,
              FORMAT, CLASS, VALUE, WEIGHT, WHERE.

  TODO 07 - AST (ARBRE SYNTAXIQUE ABSTRAIT)
            Representation par table fixe TAstNode (pas de pointeurs).
            Champs : Kind, Text, Left, Right, FirstChild, NextSibling,
              Line, SymRef, NumVal, IsChar.
            Noeuds principaux :
              NK_PROGRAM   : racine de l AST
              NK_DATASTEP  : un DATA step complet (enfants = statements)
              NK_PROCSTEP  : un PROC step complet (enfants = sous-cmds)
              NK_ASSIGN    : affectation variable = expr
              NK_EXPR      : expression quelconque
              NK_BINOP     : operateur binaire (op dans Text)
              NK_UNOP      : operateur unaire (NOT, signe moins)
              NK_LITERAL   : constante chaine ou numerique
              NK_VAR       : reference a une variable
              NK_CALL      : appel de fonction integree
              NK_ARRAY_REF : acces tableau tab{i}
              NK_IF        : noeud IF (cond, then, else)
              NK_SELECT    : SELECT avec liste de WHEN/OTHERWISE
              NK_DO        : boucle DO (type dans Text : WHILE/UNTIL/ITER)
              NK_PUT       : statement PUT
              NK_OUTPUT    : statement OUTPUT
              NK_DELETE    : statement DELETE
              NK_STOP      : statement STOP
              NK_RETAIN    : statement RETAIN
              NK_SET       : statement SET
              NK_MERGE     : statement MERGE
              NK_BY        : clause BY
              NK_INFILE    : statement INFILE
              NK_INPUT     : statement INPUT
              NK_FILE      : statement FILE
              NK_ARRAY_DEF : declaration ARRAY
              NK_GOTO      : statement GOTO / label:
              NK_LEAVE     : statement LEAVE
              NK_CONTINUE  : statement CONTINUE

  TODO 08 - TABLE DES SYMBOLES
            Variables de datasets : SymTable, champs Name/Kind/Offset/
              AsmName/IsChar (numerique ou chaine $ selon INPUT/affectation).
            Kinds : SK_VAR_NUM (variable numerique globale ou locale),
              SK_VAR_CHAR (variable chaine), SK_LABEL (etiquette GOTO),
              SK_DATASET (nom de dataset en memoire), SK_FORMAT (format).
            Datasets en memoire : table DatasetTable (champs : Name,
              VarList, RowCount) ; en V1, representation simplifiee.
            Formats utilisateur : FormatTable (champs : Name, Entries,
              NumEntries) ; chaque entree = plage [Lo,Hi] + libelle.
            FindSym, AddSym, GetOrAddVar, GetOrAddDataset.
            Macro-variables : MacroVarTable separee (TODO 02).

  TODO 09 - DATA STEP : STRUCTURE ET BOUCLE IMPLICITE
            Un DATA step SAS execute son corps en boucle implicite
              sur les observations du (ou des) dataset(s) source.
            En V1 (mode _NULL_ ou dataset cible sans SET) :
              le corps est execute une seule fois (pas de boucle).
            DATA _NULL_ : aucun dataset de sortie, corps execute une fois.
            OUTPUT : statement explicite, emettre une observation.
            DELETE : sauter l iteration courante (ne pas ecrire d obs.).
            STOP   : terminer la boucle DATA immediatement.
            RETAIN var val ; : conserver la valeur de var entre iterations
              (codegen : initialiser au debut du DATA step).
            Gestion de l observation courante comme zone de travail.

  TODO 10 - DATA STEP : AFFECTATIONS ET OPERATEURS
            Affectation simple : var = expr ;
            Operateurs arithmetiques : + - * / ** (puissance).
            Operateur de concatenation de chaines : || .
            Operateurs de comparaison : = < > <= >= ^= (ou ~=, ou !=).
            Operateurs logiques : AND OR NOT (ou & | ~).
            Priorite des operateurs (plus forte a plus faible) :
              fonctions, ** , unaire +/-, * /, + -, || ,
              comparaisons, NOT, AND, OR.
            Affectation sommante : var + expr ; (equivalent RETAIN + =).
            Expressions numeriques et chaines dans le meme parseur
              (le type est infere a la resolution ou au codegen).
            CodegenExpr : parcourir l AST d expression et emettre
              du code 80386 correspondant.

  TODO 11 - DATA STEP : IF/THEN/ELSE
            IF expr THEN statement ; [ELSE statement ;]
            IF expr THEN DO ; liste-statements ; END ; [ELSE DO ; ... END ;]
            IF expr THEN DO ; ... END ; ELSE IF expr THEN DO ; ... END ;
              ELSE DO ; ... END ; (chaine d ELSE IF).
            DELETE comme statement dans le THEN ou ELSE.
            Codegen : evaluer expr, tester EAX, JE/JNE vers branche else,
              emettre branche then, JMP fin, emettre branche else.
            Support de IF sans ELSE (branche else = NOP).

  TODO 12 - DATA STEP : SELECT/WHEN/OTHERWISE
            SELECT [(expr)] ; liste-WHEN ; [OTHERWISE ;] END ;
            WHEN (val1 [, val2 ...]) statement ; ou DO ; ... END ;
            SELECT avec expression : comparer expr aux valeurs de chaque WHEN.
            SELECT sans expression : evaluer chaque WHEN comme condition.
            OTHERWISE : branche par defaut si aucun WHEN ne correspond.
            Valeurs multiples dans un WHEN : WHEN(1,2,3) = plusieurs
              comparaisons avec JE reliees en chaine.
            Codegen : cascade de comparaisons, JMP vers fin apres chaque
              branche executee (break implicite).

  TODO 13 - DATA STEP : BOUCLES DO
            DO ; corps ; END ; : bloc simple sans boucle (groupement).
            DO WHILE (cond) ; corps ; END ; : tester cond avant le corps.
            DO UNTIL (cond) ; corps ; END ; : tester cond apres le corps.
            DO var = debut TO fin [BY pas] ; corps ; END ; :
              initialiser var, tester avant chaque iteration,
              incrementer de pas (defaut 1, peut etre negatif).
            DO var = debut TO fin WHILE (cond) ; : condition supplementaire.
            LEAVE  : sortir immediatement de la boucle la plus proche.
            CONTINUE : passer a l iteration suivante (JMP vers l increment).
            GOTO label ; et label: : saut inconditionnel dans le DATA step.
            Boucles imbriquees : pile de contextes de boucle pour LEAVE
              et CONTINUE (tableau global LoopStack).

  TODO 14 - DATA STEP : ARRAY ET DIM()
            ARRAY nom {n} [type] [v1 v2 ... | plage x1-xn | _TEMPORARY_] ;
              Declarer n variables liees a un tableau.
            Noms automatiques : si aucun nom explicite, generer nom1..nomN.
            Plage numerotee : x1-x5 = variables x1, x2, x3, x4, x5.
            _TEMPORARY_ : tableau sans variables liees, elements temporaires.
            ARRAY nom {r, c} : tableau multidimensionnel, acces lineaire
              (element (r,c) = (r-1)*ncols + c, base 1).
            DIM(nom) : retourner le nombre d elements du tableau (n).
            Acces nom{i} : calculer l adresse de l element i (base 1).
            Codegen : les elements d un ARRAY sont des variables ordinaires
              adressees par offset calcule a partir de l index.

  TODO 15 - DATA STEP : PUT (AFFICHAGE CONSOLE)
            PUT item1 item2 ... ; : emettre les items sur la sortie standard
              (WriteFile vers GetStdHandle(-11)) suivi de CR+LF.
            Item litteral : chaine entre apostrophes, emise telle quelle.
            Item variable : valeur de la variable (numerique -> chaine).
            Item mixte : 'libelle:' var ' autre' (juxtaposition sur la meme
              ligne PUT).
            FILE PRINT avant PUT : rediriger la sortie vers stdout
              (comportement par defaut en V1).
            Format inline : put var best. ou put var 8.2 (stub en V1).
            PUT sans arguments : emettre une ligne vide (CR+LF seul).
            Codegen : pour chaque item, appeler _SASRT_write_str ou
              _SASRT_write_num selon le type, puis _SASRT_newline.

  TODO 16 - DATA STEP : INFILE / FILE / INPUT / DATALINES
            INFILE 'fichier' [DLM=c] [FIRSTOBS=n] ; :
              ouvrir le fichier en lecture, delimiter par DLM (defaut espace),
              ignorer les FIRSTOBS-1 premieres lignes.
            INFILE CARDS | DATALINES ; : lire les donnees integrees dans
              le source SAS (lignes jusqu a ; ou jusqu au prochain statement).
            INPUT var1 [$] [col1-col2] var2 [$] ... ; :
              lire les champs selon le delimiteur ou les colonnes fixes.
              $ apres le nom = variable chaine, sinon numerique.
              col1-col2 : format colonne fixe (INPUT nom $ 1-10).
            FILE 'fichier' ; : ouvrir le fichier en ecriture, rediriger
              les PUT suivants vers ce fichier.
            En V1 : stub minimal, INFILE CARDS + INPUT + PUT fonctionnel.

  TODO 17 - DATA STEP : SET / MERGE / BY / UPDATE
            SET ds1 [ds2 ...] [END=flag] ; :
              lire les observations de ds1 (puis ds2 etc. en concatenation).
              END=flag : flag = 1 quand la derniere observation est lue.
            MERGE ds1 ds2 ... ; : fusionner les datasets sur la cle BY.
            BY var1 [DESCENDING] var2 ... ; : specifier la cle de tri/fusion.
              FIRST.var : vaut 1 pour la premiere observation d un groupe BY.
              LAST.var  : vaut 1 pour la derniere observation d un groupe BY.
            UPDATE master trans ; BY cle ; : mise a jour du dataset maitre
              par les transactions.
            En V1 : SET _NULL_ = pas de lecture, SET dataset = stub
              (iteration simplifiee, pas de vraie gestion multi-obs).

  TODO 18 - PROC STEP : STRUCTURE GENERALE
            ParseProcStep : PROC nom [DATA=ds] [options] ; cmds ; RUN | QUIT ;
            Options communes : DATA=dataset, OUT=dataset, NOPRINT,
              TITLE 'texte' ; , FOOTNOTE 'texte' ;
            Sous-commandes reconnues selon le PROC :
              VAR var1 var2 ... ; : liste de variables a traiter.
              BY var1 [DESCENDING] var2 ; : cle de tri ou de groupe.
              WHERE (condition) ; : filtre sur les observations.
              FORMAT var format. ; : appliquer un format.
              CLASS var ; : variable de classification (MEANS).
              TABLES var1 [*var2] ; : tables de frequences (FREQ).
              VALUE formatname plages ; : definition (FORMAT).
            PROC non reconnu : emettre un avertissement, ignorer le corps
              jusqu au prochain RUN/QUIT.

  TODO 19 - PROC PRINT
            PROC PRINT DATA=ds [NOPRINT] ; [cmds] ; RUN ;
            Afficher les observations du dataset ds sur stdout.
            VAR v1 v2 ... ; : n afficher que ces variables (defaut = toutes).
            TITLE 'texte' ; : afficher ce titre avant le tableau.
            FOOTNOTE 'texte' ; : afficher apres le tableau.
            FORMAT var format. ; : appliquer le format lors de l affichage.
            NOPRINT : ne rien afficher (stub silencieux).
            En V1 : imprimer chaque variable avec sa valeur sur une ligne
              separee, format numerique via _SASRT_num_to_str.
            Codegen : generer les appels a _SASRT_write_str et
              _SASRT_newline pour chaque ligne de sortie.

  TODO 20 - PROC MEANS
            PROC MEANS DATA=ds [stats] ; [cmds] ; RUN ;
            Stats demandees (mots-cles apres MEANS) : N MIN MAX SUM MEAN
              (defaut si aucun : N MEAN MIN MAX STD).
            VAR v1 v2 ... ; : variables numeriques a analyser.
            TITLE 'texte' ; , FOOTNOTE 'texte' ; : libelles.
            CLASS var ; : calculer les stats par groupe de la variable.
            En V1 : calculer N, MIN, MAX, SUM, MEAN pour chaque variable
              listee dans VAR, sur les observations du dataset ds.
            Codegen : boucle sur les observations, accumuler dans des
              variables runtime, puis appeler _SASRT_write_num pour
              afficher chaque statistique demandee.

  TODO 21 - PROC FREQ ET PROC SORT
            PROC FREQ DATA=ds [NOPRINT] ; [TABLES v1 [v2] ;] RUN ;
              TABLES v1 : compter les occurrences de chaque valeur de v1,
                afficher le tableau de frequences (valeur / effectif / %).
              NOPRINT : ne rien afficher.
              Sans TABLES : avertissement, aucune sortie.
            PROC SORT DATA=ds [OUT=ds2] ; BY [DESCENDING] v1 ... ; RUN ;
              Trier le dataset ds selon les cles BY.
              DESCENDING : ordre decroissant pour la cle suivante.
              OUT=ds2 : ecrire le resultat dans ds2 (sinon trier en place).
              Sans BY : emettre un avertissement, ne pas trier.
            En V1 : tri en memoire par insertion sur les variables BY,
              PROC FREQ avec comptage simple.

  TODO 22 - PROC FORMAT
            PROC FORMAT ; VALUE formatname entrees ; RUN ;
            Entrees d un VALUE :
              val_unique = 'libelle'
              lo - hi    = 'libelle' (plage numerique, bornes inclusives)
              LOW  - n   = 'libelle' (LOW = moins l infini)
              n  - HIGH  = 'libelle' (HIGH = plus l infini)
              OTHER      = 'libelle' (valeur par defaut)
            Stocker dans FormatTable (TODO 08).
            FORMAT statement dans DATA/PROC : lier un format a une variable
              pour l affichage (format var formatname. ;).
            Formats predefinis (stubs) : BEST., 8.2, $CHAR., DATE. etc.
              En V1, appliquer uniquement les formats utilisateur et BEST.
            Codegen : lors d un PUT ou PROC PRINT, consulter la FormatTable
              pour transformer la valeur numerique en libelle.

  TODO 23 - FONCTIONS INTEGREES : NUMERIQUES
            Fonctions reconnues dans ParseTerm / CodegenCall :
              ABS(x)       : valeur absolue
              INT(x)       : partie entiere (troncature vers zero)
              SIGN(x)      : -1, 0 ou 1 selon le signe de x
              MOD(x, y)    : x modulo y
              MIN(x, y)    : minimum de x et y
              MAX(x, y)    : maximum de x et y
              SUM(x1,....) : somme de tous les arguments
              ROUND(x)     : arrondi a l entier le plus proche
              CEIL(x)      : plafond (entier >= x)
              FLOOR(x)     : plancher (entier <= x)
              SQRT(x)      : racine carree (FPU ou stub entier)
              LOG(x)       : logarithme naturel (FPU ou stub)
              EXP(x)       : exponentielle (FPU ou stub)
            Codegen : appel a _SASRT_abs, _SASRT_int etc. ou calcul inline
              en 80386 (CWD/IDIV pour MOD, FLD/FSQRT pour SQRT).

  TODO 24 - FONCTIONS INTEGREES : CHAINES ET DATE
            Fonctions chaines :
              LENGTH(s)        : longueur de la chaine (sans espaces trailing)
              UPCASE(s)        : convertir en majuscules
              LOWCASE(s)       : convertir en minuscules
              TRIM(s)          : supprimer les espaces de fin
              LEFT(s)          : supprimer les espaces de debut
              RIGHT(s)         : aligner a droite (ajouter espaces en debut)
              SUBSTR(s,pos[,n]): sous-chaine a partir de pos, longueur n
              INDEX(s,sub)     : position de la premiere occurrence de sub
              COMPRESS(s[,c])  : supprimer les espaces (ou les chars c) de s
              CAT(s1,s2,...)   : concatenation sans rognage d espaces
              PUT(n)           : convertir un nombre en chaine
            Fonctions de date :
              TODAY()          : date courante (stub : valeur fixe ou 0)
              MDY(m,d,y)       : construire une date SAS a partir de m/j/a
              YEAR(d)          : extraire l annee d une date SAS
              MONTH(d)         : extraire le mois
              DAY(d)           : extraire le jour
            Codegen : appel a _SASRT_upcase, _SASRT_substr etc.
              Les dates SAS = entier (jours depuis 1/1/1960) en V1.

  TODO 25 - GENERATION PE32, RUNTIME EMBARQUE ET SORTIES OBJ/ASM
            Generation EXE (defaut) :
              Sections : BinCode (.text RX), BinData (.data RW),
                BinRData (.rdata R), BinBss (.bss RW), idata (IAT).
              WritePE : headers PE32, section headers, IAT kernel32.dll
                (GetStdHandle, WriteFile, ReadFile, ExitProcess,
                 HeapAlloc, HeapFree, GetProcessHeap).
              Entry point _SASSTART. ImageBase $00400000.
            Runtime embarque (_SASRT_*) :
              _SASRT_write_str(ptr) : WriteFile vers stdout + pas de retour.
              _SASRT_newline        : WriteFile CR+LF vers stdout.
              _SASRT_write_num(n)   : convertir entier en chaine, ecrire.
              _SASRT_num_to_str(n)  : EAX = ptr vers chaine decimale.
              _SASRT_str_concat(s1,s2) : HeapAlloc + memcpy x2 -> EAX.
              _SASRT_upcase(s), _SASRT_trim(s), _SASRT_substr(s,p,n) etc.
              _SASRT_abs(n), _SASRT_mod(n,d) : arithmetique entiere inline.
            Sortie OBJ (option -obj) :
              COFF Win32 relocatable : IMAGE_FILE_HEADER machine i386 (0x014C),
              sections .text/.data/.rdata, table des symboles COFF,
              table des relocations R_I386_DIR32 / R_I386_REL32.
            Sortie ASM (option -asm, optionnel) :
              En-tete .386 .MODEL FLAT,STDCALL OPTION CASEMAP:NONE.
              Sections .DATA, .CONST, .CODE ; EXTRN pour kernel32.
              Chaque instruction emise comme texte MASM/JWASM lisible.
            Gestion des erreurs :
              Source introuvable, syntaxe invalide, variable non declaree,
              format inexistant, dataset non cree avant SET/MERGE.
              Message : 'SASCW32: erreur ligne N: message'.
              Code de retour : 0 si succes, 1 si erreur (ExitProcess).
}

Program SASCW32;

{$IFDEF FPC}
 {$MODE TP}
{$ENDIF}

{ ============================================================ }
{ TODO 01 - STRUCTURE GENERALE DU COMPILATEUR                  }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ Constantes globales                                          }
{ ------------------------------------------------------------ }
Const
  SAS_VERSION    = '0.1';
  SAS_YEAR       = '2026';

  { Modes de sortie }
  MODE_EXE       = 0;
  MODE_OBJ       = 1;
  MODE_ASM       = 2;

  { Limites des tables }
  MAX_LINE       = 1024;     { longueur max d une ligne source }
  MAX_TOKENS     = 256;      { tokens par statement }
  MAX_AST        = 16384;    { noeuds AST }
  MAX_SYM        = 2048;     { entrees table des symboles }
  MAX_LABELS     = 2048;     { etiquettes GOTO / internes }
  MAX_FIXUPS     = 8192;     { fixups de relocation }
  MAX_CODE       = 524288;   { 512 Ko .text }
  MAX_DATA       = 65536;    { 64 Ko .data }
  MAX_RDATA      = 131072;   { 128 Ko .rdata }
  MAX_IDATA      = 16384;    { 16 Ko .idata (IAT) }
  MAX_IMPORTS    = 64;       { entrees IAT }
  MAX_VARS       = 512;      { variables SAS globales max }
  MAX_DATASETS   = 64;       { datasets en memoire }
  MAX_DS_ROWS    = 4096;     { observations par dataset }
  MAX_DS_COLS    = 128;      { variables par dataset }
  MAX_FORMATS    = 64;       { formats utilisateur }
  MAX_FMT_ENT    = 64;       { entrees par format (plages VALUE) }
  MAX_MACRO_VARS = 256;      { macro-variables %LET }
  MAX_MACRO_DEFS = 64;       { definitions %MACRO }
  MAX_MACRO_PRM  = 16;       { parametres par %MACRO }
  MAX_MACRO_BODY = 128;      { lignes de corps par %MACRO }
  MAX_MACRO_LINES = 4096;    { lignes du source SAS max }
  MAX_LOOP_NEST  = 32;       { profondeur de DO imbriques }
  MAX_ARRAYS     = 256;      { tableaux ARRAY declares }

  { Sections binaires }
  BIN_SEC_TEXT   = 0;
  BIN_SEC_DATA   = 1;
  BIN_SEC_RDATA  = 2;
  BIN_SEC_BSS    = 3;
  BIN_SEC_IDATA  = 4;

  { Types de fixup }
  BIN_FIX_ABS32  = 0;        { adresse absolue 32 bits }
  BIN_FIX_REL32  = 1;        { relative 32 bits (CALL/JMP) }
  BIN_FIX_IMP32  = 2;        { IAT import 32 bits }

  { Kinds de symboles }
  SK_NONE        =  0;
  SK_VAR_NUM     =  1;       { variable numerique }
  SK_VAR_CHAR    =  2;       { variable chaine ($ en SAS) }
  SK_LABEL       =  3;       { etiquette GOTO dans un DATA step }
  SK_DATASET     =  4;       { nom de dataset }
  SK_FORMAT      =  5;       { nom de format utilisateur }

  { Kinds de noeuds AST }
  NK_PROGRAM     =  0;
  NK_DATASTEP    =  1;
  NK_PROCSTEP    =  2;
  NK_ASSIGN      =  3;
  NK_BINOP       =  4;
  NK_UNOP        =  5;
  NK_LITERAL     =  6;
  NK_VAR         =  7;
  NK_CALL        =  8;
  NK_ARRAY_REF   =  9;
  NK_ARRAY_DEF   = 10;
  NK_IF          = 11;
  NK_SELECT      = 12;
  NK_WHEN        = 13;
  NK_DO          = 14;
  NK_PUT         = 15;
  NK_OUTPUT      = 16;
  NK_DELETE      = 17;
  NK_STOP        = 18;
  NK_RETAIN      = 19;
  NK_SET         = 20;
  NK_MERGE       = 21;
  NK_BY          = 22;
  NK_INFILE      = 23;
  NK_INPUT       = 24;
  NK_FILE        = 25;
  NK_GOTO        = 26;
  NK_LEAVE       = 27;
  NK_CONTINUE    = 28;
  NK_PROC_PRINT  = 29;
  NK_PROC_MEANS  = 30;
  NK_PROC_SORT   = 31;
  NK_PROC_FREQ   = 32;
  NK_PROC_FORMAT = 33;
  NK_PROC_GEN    = 34;
  NK_VAR_LIST    = 35;
  NK_FMT_STMT    = 36;
  NK_CARDS       = 37;  { lignes CARDS/DATALINES inline }

  { ---------------------------------------------------------- }
  { Types de tokens — TODO 04-05                               }
  { ---------------------------------------------------------- }
  TOK_EOF       =  0;   { fin de fichier }
  TOK_IDENT     =  1;   { identificateur }
  TOK_STRING    =  2;   { chaine 'x' ou "x" }
  TOK_INTEGER   =  3;   { entier }
  TOK_FLOAT     =  4;   { flottant }
  TOK_ASSIGN    =  5;   { = }
  TOK_PLUS      =  6;   { + }
  TOK_MINUS     =  7;   { - }
  TOK_STAR      =  8;   { * }
  TOK_SLASH     =  9;   { / }
  TOK_STARSTAR  = 10;   { ** }
  TOK_CONCAT    = 11;   { || ou !! }
  TOK_LPAREN    = 12;   { ( }
  TOK_RPAREN    = 13;   { ) }
  TOK_LBRACE    = 14;   { ouv. accolade }
  TOK_RBRACE    = 15;   { ferm. accolade }
  TOK_SEMICOL   = 16;   { ; }
  TOK_DOT       = 17;   { . }
  TOK_COMMA     = 18;   { , }
  TOK_LT        = 19;   { < }
  TOK_LE        = 20;   { <= }
  TOK_GT        = 21;   { > }
  TOK_GE        = 22;   { >= }
  TOK_NE        = 23;   { ^= ~= != <> }
  TOK_AND       = 24;   { & seul }
  TOK_OR        = 25;   { | seul }
  TOK_NOT       = 26;   { ^ ~ seul }
  TOK_COLON     = 27;   { : }
  TOK_MACRO_VAR = 28;   { &nom residuel apres expansion }
  TOK_EOL       = 29;   { fin de ligne (mode CARDS/DATALINES uniquement) }
  TOK_EQ        =  5;   { alias de TOK_ASSIGN, contexte comparaison }

  { Mots-cles SAS }
  KW_DATA       = 30;
  KW_RUN        = 31;
  KW_PROC       = 32;
  KW_QUIT       = 33;
  KW_SET        = 34;
  KW_MERGE      = 35;
  KW_BY         = 36;
  KW_OUTPUT     = 37;
  KW_DELETE     = 38;
  KW_STOP       = 39;
  KW_RETAIN     = 40;
  KW_INPUT      = 41;
  KW_INFILE     = 42;
  KW_FILE       = 43;
  KW_PUT        = 44;
  KW_ARRAY      = 45;
  KW_DO         = 46;
  KW_WHILE      = 47;
  KW_UNTIL      = 48;
  KW_TO         = 49;
  KW_END        = 50;
  KW_IF         = 51;
  KW_THEN       = 52;
  KW_ELSE       = 53;
  KW_SELECT     = 54;
  KW_WHEN       = 55;
  KW_OTHERWISE  = 56;
  KW_GOTO       = 57;
  KW_LEAVE      = 58;
  KW_CONTINUE   = 59;
  KW_FORMAT     = 60;
  KW_FIRST      = 61;   { FIRST. en groupe BY }
  KW_LAST       = 62;   { LAST.  en groupe BY }
  KW_UPDATE     = 63;
  KW_VAR        = 64;   { sous-commande PROC }
  KW_TABLES     = 65;   { sous-commande PROC FREQ }
  KW_TITLE      = 66;
  KW_FOOTNOTE   = 67;
  KW_CLASS      = 68;   { sous-commande PROC MEANS }
  KW_VALUE      = 69;   { sous-commande PROC FORMAT }
  KW_WHERE      = 70;
  KW_AND        = 71;   { AND logique }
  KW_OR         = 72;   { OR  logique }
  KW_NOT        = 73;   { NOT logique }
  KW_IN         = 74;   { operateur IN }
  KW_DESCENDING = 75;
  KW_OUT        = 76;   { option OUT= }
  KW_NOPRINT    = 77;
  KW_CARDS      = 78;
  KW_DATALINES  = 79;
  KW_DIM        = 80;   { DIM() dans ARRAY }
  KW_PRINT      = 81;   { PROC PRINT }
  KW_MEANS      = 82;   { PROC MEANS }
  KW_FREQ       = 83;   { PROC FREQ }
  KW_SORT       = 84;   { PROC SORT }
  KW_LOW        = 85;   { low dans PROC FORMAT VALUE }
  KW_HIGH       = 86;   { high dans PROC FORMAT VALUE }
  KW_OTHER      = 87;   { other dans PROC FORMAT VALUE }

{ ------------------------------------------------------------ }
{ Types                                                        }
{ ------------------------------------------------------------ }
Type
  { Entree de la table des symboles }
  TSym = Record
    Name    : String;
    Kind    : Integer;
    Offset  : LongInt;       { offset dans .data ou .bss }
    AsmName : String;        { nom ASM/PE stable }
    VarIdx  : Integer;       { index dans VarNames }
    LblAddr : LongInt;       { adresse code compilee (SK_LABEL) }
    IsChar  : Boolean;       { variable chaine (True) ou numerique }
    DsIdx   : Integer;       { index dataset (SK_DATASET) }
    FmtIdx  : Integer;       { index format (SK_FORMAT) }
    DeclLine: Integer;       { ligne de declaration }
    Assigned: Boolean;       { variable deja affectee }
    Warned  : Boolean;       { avertissement deja emis }
  End;

  { Entree d un format VALUE (plage numerique ou valeur unique) }
  TFmtEntry = Record
    LoIsLow : Boolean;       { borne basse = LOW (-infini) }
    HiIsHigh: Boolean;       { borne haute = HIGH (+infini) }
    IsOther : Boolean;       { clause OTHER }
    IsSingle: Boolean;       { valeur unique (pas une plage) }
    Lo      : LongInt;       { borne basse numerique }
    Hi      : LongInt;       { borne haute numerique }
    Lbl     : String;        { libelle associe }
  End;

  { Format utilisateur (PROC FORMAT VALUE) }
  TFormat = Record
    Name    : String;
    Entries : Array[0..MAX_FMT_ENT-1] Of TFmtEntry;
    Count   : Integer;
  End;

  { Variable d un dataset }
  TDsVar = Record
    Name   : String;
    IsChar : Boolean;
  End;

  { Dataset en memoire (simplifie V1) }
  TDataset = Record
    Name   : String;
    Vars   : Array[0..MAX_DS_COLS-1] Of TDsVar;
    VarCnt : Integer;
    RowCnt : Integer;
  End;

  { Macro-variable (%LET / %GLOBAL / %LOCAL) }
  TMacroVar = Record
    Name    : String;
    Value   : String;
    IsGlobal: Boolean;
  End;

  { Definition %MACRO }
  TMacroDef = Record
    Name    : String;
    Params  : Array[0..MAX_MACRO_PRM-1] Of String;
    ParamCnt: Integer;
    Body    : Array[0..MAX_MACRO_BODY-1] Of String;
    BodyCnt : Integer;
  End;

  { Arguments d un appel de macro }
  TCallArgs = Array[0..MAX_MACRO_PRM-1] Of String;

  { Noeud AST }
  TAstNode = Record
    Kind       : Integer;    { NK_xxx }
    Text       : String;     { operateur, nom, valeur litterale }
    Left       : Integer;    { fils gauche ou -1 }
    Right      : Integer;    { fils droit ou -1 }
    FirstChild : Integer;    { tete de liste d enfants ou -1 }
    NextSibling: Integer;    { frere suivant ou -1 }
    Line       : Integer;    { ligne source }
    SymRef     : Integer;    { index SymTable ou -1 }
    NumVal     : LongInt;    { valeur numerique pour NK_LITERAL }
    IsChar     : Boolean;    { noeud de type chaine }
  End;

  { Fixup de relocation }
  TFixup = Record
    Offset  : LongInt;
    Section : Integer;
    Name    : String;
    Kind    : Integer;       { BIN_FIX_xxx }
  End;

  { Label defini }
  TLabel = Record
    Name    : String;
    Section : Integer;
    Offset  : LongInt;
  End;

  { Import Win32 }
  TImport = Record
    DllName : String;
    FuncName: String;
    IATOff  : LongInt;
    LabelNm : String;        { nom interne __imp__xxx }
  End;

  { Contexte de boucle DO (pour LEAVE et CONTINUE) }
  TLoopCtx = Record
    LblStart : String;       { etiquette debut iteration }
    LblNext  : String;       { etiquette increment / test (CONTINUE) }
    LblEnd   : String;       { etiquette apres la boucle (LEAVE) }
  End;

  { Entree de la table des tableaux ARRAY (TODO 14) }
  TArrayRec = Record
    Name      : String;      { nom du tableau (majuscules) }
    BaseLabel : String;      { label du premier element en .data }
    TotalSize : Integer;     { nombre d elements }
    IsTemp    : Boolean;     { _TEMPORARY_ : sans variables liees }
  End;

{ ------------------------------------------------------------ }
{ Variables globales                                           }
{ ------------------------------------------------------------ }
Var
  { Fichiers et mode de sortie }
  SrcFile      : String;
  OutFile      : String;
  OutMode      : Integer;    { MODE_EXE, MODE_OBJ ou MODE_ASM }
  HasError     : Boolean;
  ErrorCount   : Integer;
  WarnCount    : Integer;

  { Table des symboles }
  SymTable     : Array[0..MAX_SYM-1]       Of TSym;
  SymCount     : Integer;

  { AST }
  AstTable     : Array[0..MAX_AST-1]       Of TAstNode;
  AstCount     : Integer;
  AstRoot      : Integer;

  { Datasets en memoire }
  DsTable      : Array[0..MAX_DATASETS-1]  Of TDataset;
  DsCount      : Integer;

  { Formats utilisateur }
  FmtTable     : Array[0..MAX_FORMATS-1]   Of TFormat;
  FmtCount     : Integer;

  { Macro-variables et definitions }
  MacroVarTbl  : Array[0..MAX_MACRO_VARS-1]  Of TMacroVar;
  MacroVarCnt  : Integer;
  MacroDefTbl  : Array[0..MAX_MACRO_DEFS-1]  Of TMacroDef;
  MacroDefCnt  : Integer;

  { Tampon de lignes source pour le macro-preprocesseur }
  MacroSrcLines : Array[0..MAX_MACRO_LINES-1] Of String;
  MacroSrcCnt   : Integer;
  MacroSrcPos   : Integer;

  { Noms de variables SAS (indexation par VarIdx) }
  VarNames     : Array[0..MAX_VARS-1]      Of String;
  VarCount     : Integer;

  { Sections binaires }
  BinCode      : Array[0..MAX_CODE-1]      Of Byte;
  BinCodeSize  : LongInt;
  BinData      : Array[0..MAX_DATA-1]      Of Byte;
  BinDataSize  : LongInt;
  BinRData     : Array[0..MAX_RDATA-1]     Of Byte;
  BinRDataSize : LongInt;
  BinBssSize   : LongInt;
  BinIData     : Array[0..MAX_IDATA-1]     Of Byte;
  BinIDataSize : LongInt;
  BinCurSec    : Integer;

  { Labels et fixups }
  LabelTable   : Array[0..MAX_LABELS-1]    Of TLabel;
  LabelCount   : Integer;
  FixupTable   : Array[0..MAX_FIXUPS-1]    Of TFixup;
  FixupCount   : Integer;

  { Imports IAT }
  ImportTable  : Array[0..MAX_IMPORTS-1]   Of TImport;
  ImportCount  : Integer;
  BinPLKCount  : Integer;    { compteur de labels internes uniques }

  { Pile de contextes de boucles DO (LEAVE / CONTINUE) }
  LoopStack    : Array[0..MAX_LOOP_NEST-1] Of TLoopCtx;
  LoopTop      : Integer;

  { Table des tableaux ARRAY (TODO 14) }
  ArrayTable   : Array[0..MAX_ARRAYS-1]  Of TArrayRec;
  ArrayCount   : Integer;

  { Ligne source courante (diagnostics) }
  CurLineNum   : Integer;

  { Lexeur — TODO 04-05 }
  LexSrcF        : Text;
  LexEOF         : Boolean;
  LexLine        : String;
  LexLineLen     : Integer;
  LexPos         : Integer;
  LexInComment   : Boolean;   { dans un commentaire /* ... */ }
  LexAtStmtStart : Boolean;   { vrai apres ; ou debut fichier }
  LexEmitEOL     : Boolean;   { emettre TOK_EOL a chaque fin de ligne }
  CurTokType     : Integer;
  CurTokStr      : String;
  CurDsRoot      : Integer;   { noeud AST du DATA step courant   }
  CurDsIdx       : Integer;   { index DsTable du dataset courant }

{ ============================================================ }
{ Utilitaires generaux                                         }
{ ============================================================ }

Function IntToStr(N: LongInt): String;
Var S: String; Neg: Boolean;
Begin
  If N = 0 Then Begin IntToStr := '0'; Exit; End;
  Neg := (N < 0); If Neg Then N := -N;
  S := '';
  While N > 0 Do Begin
    S := Chr(Ord('0') + Integer(N Mod 10)) + S;
    N := N Div 10;
  End;
  If Neg Then S := '-' + S;
  IntToStr := S;
End;

Function StrToInt(Const S: String): LongInt;
Var I: Integer; V: LongInt; Neg: Boolean;
Begin
  V := 0; I := 1; Neg := False;
  If (Length(S) > 0) And (S[1] = '-') Then Begin Neg := True; I := 2; End;
  While I <= Length(S) Do Begin
    If (S[I] >= '0') And (S[I] <= '9') Then
      V := V * 10 + (Ord(S[I]) - Ord('0'));
    Inc(I);
  End;
  If Neg Then StrToInt := -V Else StrToInt := V;
End;

Function FileExt(Const S: String): String;
Var I: Integer;
Begin
  FileExt := '';
  For I := Length(S) DownTo 1 Do
    If S[I] = '.' Then Begin FileExt := Copy(S, I, 255); Exit; End
    Else If (S[I] = '\') Or (S[I] = '/') Then Exit;
End;

Function FileBase(Const S: String): String;
Var I: Integer;
Begin
  FileBase := S;
  For I := Length(S) DownTo 1 Do
    If S[I] = '.' Then Begin FileBase := Copy(S, 1, I-1); Exit; End
    Else If (S[I] = '\') Or (S[I] = '/') Then Exit;
End;

Function ChangeExt(Const Path, NewExt: String): String;
Begin
  ChangeExt := FileBase(Path) + NewExt;
End;

Function FileExists(Const Name: String): Boolean;
Var F: File;
Begin
  Assign(F, Name);
  {$I-} Reset(F, 1); {$I+}
  If IOResult = 0 Then Begin Close(F); FileExists := True; End
  Else FileExists := False;
End;

Function UpperStr(Const S: String): String;
Var I: Integer; R: String;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If (R[I] >= 'a') And (R[I] <= 'z') Then
      R[I] := Chr(Ord(R[I]) - 32);
  UpperStr := R;
End;

Procedure CompileError(Const Msg: String);
Begin
  WriteLn('SASCW32: erreur ligne ', CurLineNum, ': ', Msg);
  HasError := True;
  Inc(ErrorCount);
End;

Procedure CompileWarn(Const Msg: String);
Begin
  WriteLn('SASCW32: avertissement ligne ', CurLineNum, ': ', Msg);
  Inc(WarnCount);
End;

{ ============================================================ }
{ Declarations anticipees (Forward) des sections TODO 02..25  }
{ ============================================================ }

{ TODO 02 : Macro-preprocesseur - %LET et substitution &var }
Function  MacroVarLookup(Const Name: String): Integer;         Forward;
Procedure MacroVarSet(Const Name, Value: String;
                      IsGlobal: Boolean);                       Forward;
Function  MacroSubstitute(Const S: String): String;            Forward;

{ TODO 03 : Macro-preprocesseur - %MACRO/%MEND, %IF, %DO }
Function  MacroDefLookup(Const Name: String): Integer;                   Forward;
Function  MacroExpand(Const SrcPath: String): String;                    Forward;
Procedure MacroDispatchLine(Const Line: String; Var OutF: Text);         Forward;
Function  MacroRunBlock(Var OutF: Text; SkipMode: Boolean): String;      Forward;
Procedure MacroProcIf(Const Line: String; Var OutF: Text);               Forward;
Procedure MacroProcDo(Const Line: String; Var OutF: Text);               Forward;

{ TODO 04 : Lexer }
Procedure LexInit(Const Src: String);                          Forward;
Procedure LexNextToken;                                        Forward;

{ TODO 06 : Parser principal }
Procedure ParseProgram;                                        Forward;

{ TODO 06 : Parser — procedures de detail }
Function  AstNew(Kind: Integer; Const Txt: String;
                 Line: Integer): Integer;                      Forward;
Procedure AstAddChild(Parent, Child: Integer);                 Forward;
Procedure SkipToSemicolon;                                     Forward;
Procedure ParseDataStmt;                                       Forward;
Procedure ParseDataStepBody(DsRoot: Integer);                  Forward;
Procedure ParseDataStep;                                       Forward;
Procedure ParseOptions(Var DsName: String;
                       Var OutDs: String;
                       Var NoPrint: Boolean);                  Forward;
Procedure ParseSubCmd(ProcRoot: Integer);                      Forward;
Procedure ParseProcPrint(Const DsName: String;
                         NoPrint: Boolean;
                         ProcRoot: Integer);                   Forward;
Procedure ParseProcMeans(Const DsName: String;
                         ProcRoot: Integer);                   Forward;
Procedure ParseProcSort(Const DsName: String;
                        Const OutDs: String;
                        ProcRoot: Integer);                    Forward;
Procedure ParseProcFreq(Const DsName: String;
                        NoPrint: Boolean;
                        ProcRoot: Integer);                    Forward;
Procedure ParseProcFormat(ProcRoot: Integer);                  Forward;
Procedure ParseProcGeneric(Const ProcName: String;
                           Const DsName: String;
                           ProcRoot: Integer);                 Forward;
Procedure ParseProcStep;                                       Forward;

{ TODO 07 : AST — constructeurs specialises et diagnostic }
Function  AstNewBinOp(Const Op: String;
                      L, R, Line: Integer): Integer;           Forward;
Function  AstNewUnOp(Const Op: String;
                     Child, Line: Integer): Integer;           Forward;
Function  AstNewLitNum(V: LongInt; Line: Integer): Integer;    Forward;
Function  AstNewLitStr(Const S: String;
                       Line: Integer): Integer;                Forward;
Function  AstNewVar(Const Name: String;
                    Line: Integer): Integer;                   Forward;
Function  AstNewCall(Const FuncName: String;
                     Line: Integer): Integer;                  Forward;
Function  AstNewAssign(VarNode, ExprNode,
                       Line: Integer): Integer;                Forward;
Function  AstNewIf(CondN, ThenN, ElseN,
                   Line: Integer): Integer;                    Forward;
Function  AstNewDo(Const DoType: String;
                   Line: Integer): Integer;                    Forward;
Function  AstNewSelect(ExprNode, Line: Integer): Integer;      Forward;
Function  AstNewWhen(ValNode, StmtNode,
                     Line: Integer): Integer;                  Forward;
Function  AstNewArrayRef(Const Name: String;
                         IdxNode, Line: Integer): Integer;     Forward;
Procedure AstSetLeft(Node, Child: Integer);                    Forward;
Procedure AstSetRight(Node, Child: Integer);                   Forward;
Procedure AstDump(N, Indent: Integer);                         Forward;

{ TODO 08 : Table des symboles }
Function  FindSym(Const Name: String; Kind: Integer): Integer; Forward;
Function  AddSym(Const Name: String; Kind: Integer): Integer;  Forward;
Function  GetOrAddVar(Const Name: String;
                      IsChar: Boolean): Integer;               Forward;
Function  GetOrAddDataset(Const Name: String): Integer;        Forward;
Function  FindDsVar(DsIdx: Integer;
                    Const Name: String): Integer;              Forward;
Function  GetOrAddDsVar(DsIdx: Integer;
                        Const Name: String;
                        IsChar: Boolean): Integer;             Forward;
Function  FindFormat(Const Name: String): Integer;             Forward;
Function  GetOrAddFormat(Const Name: String): Integer;         Forward;
Function  FindLabel(Const Name: String): Integer;              Forward;
Function  AddLabel(Const Name: String): Integer;               Forward;
Function  SymGenAsmName(Idx: Integer): String;                 Forward;
Procedure SymSetOffset(Idx: Integer; Off: LongInt);            Forward;
Procedure SymMarkAssigned(Idx: Integer);                       Forward;
Procedure SymWarnUnassigned(Idx: Integer;
                            Const Context: String);            Forward;

{ TODO 09 : DATA step — parseurs de statements }
Procedure ParseStmtOutput;                                     Forward;
Procedure ParseStmtDelete;                                     Forward;
Procedure ParseStmtStop;                                       Forward;
Procedure ParseStmtRetain;                                     Forward;
Procedure ParseStmtAssign;                                     Forward;
Procedure ParseStmtPut;                                        Forward;
Procedure ParseStmtIf;                                         Forward;
Procedure ParseStmtSelect;                                     Forward;
Procedure ParseStmtDo;                                         Forward;
Procedure ParseStmtArray;                                      Forward;
Procedure ParseStmtInfile;                                     Forward;
Procedure ParseStmtInput;                                      Forward;
Procedure ParseStmtFile;                                       Forward;
Procedure ParseStmtCards;                                      Forward;
Procedure ParseStmtSet;                                        Forward;
Procedure ParseStmtMerge;                                      Forward;
Procedure ParseStmtBy;                                         Forward;
Procedure ParseStmtFmtDecl;                                    Forward;
Procedure ParseStmtGoto;                                       Forward;

{ TODO 11 : IF/THEN/ELSE }
Function  ParseIfBody(BodyLine: Integer): Integer;           Forward;

{ TODO 10 : Parseur d expressions }
Function  ParseExprOr(Line: Integer): Integer;               Forward;
Function  ParseExprAnd(Line: Integer): Integer;              Forward;
Function  ParseExprNot(Line: Integer): Integer;              Forward;
Function  ParseExprCmp(Line: Integer): Integer;              Forward;
Function  ParseExprConcat(Line: Integer): Integer;           Forward;
Function  ParseExprAdd(Line: Integer): Integer;              Forward;
Function  ParseExprMul(Line: Integer): Integer;              Forward;
Function  ParseExprUnary(Line: Integer): Integer;            Forward;
Function  ParseExprPow(Line: Integer): Integer;              Forward;
Function  ParseExprPrimary(Line: Integer): Integer;          Forward;

{ TODO 25 : Codegen et sorties }
Procedure CodegenProgram;                                      Forward;
Procedure WritePE(Const FileName: String);                     Forward;
Procedure WriteCOFF(Const FileName: String);                   Forward;
Procedure WriteASM(Const FileName: String);                    Forward;
Function  BinCurOffset: LongInt;                               Forward;
Procedure BinEmit8(B: Byte);                                   Forward;
Procedure BinEmit32(V: LongInt);                               Forward;
Procedure BinDefineLabel(Const Name: String);                  Forward;
Function  BinAddImport(Const DllName, FuncName: String): Integer; Forward;
Procedure BinRegisterKernel32Imports;                          Forward;
Procedure BinMovRegImm32(R: Integer; V: LongInt);              Forward;
Procedure BinMovRegLabel(R: Integer; Const Name: String);      Forward;
Procedure BinPushReg(R: Integer);                              Forward;
Procedure BinPopReg(R: Integer);                               Forward;
Procedure BinRet;                                              Forward;
Procedure BinPushImm32(V: LongInt);                            Forward;
Procedure BinPushLabel(Const Name: String);                    Forward;
Procedure BinAddEspImm8(N: Integer);                           Forward;
Procedure BinCallLabel(Const Name: String);                    Forward;
Procedure BinCallImport(Const FuncName: String);               Forward;
Procedure BinJmpLabel(Const Name: String);                     Forward;
Procedure BinJccLabel(CC: Integer; Const Name: String);        Forward;
Procedure EmitRuntimeIO;                                       Forward;
{ TODO 19 : Helpers .data/.rdata et codegen PROC PRINT }
Procedure BinEmitDataByte(B: Byte);                            Forward;
Procedure BinEmitRDataByte(B: Byte);                           Forward;
Procedure BinDefineDataLabel(Const Name: String);              Forward;
Procedure BinDefineRDataLabel(Const Name: String);             Forward;
Procedure BinPushMem32(Const LblName: String);                 Forward;
Function  EmitRDataStr(Const S: String): String;               Forward;
Procedure AllocVars;                                           Forward;
Procedure CodegenProcPrint(ProcNode: Integer);                 Forward;
{ TODO 20 : Codegen PROC MEANS }
Procedure CodegenProcMeans(ProcNode: Integer);                 Forward;
{ TODO 21 : Codegen PROC FREQ et PROC SORT }
Procedure CodegenProcFreq(ProcNode: Integer);                  Forward;
Procedure CodegenProcSort(ProcNode: Integer);                  Forward;
{ TODO 22 : Helpers codegen et PROC FORMAT }
Procedure BinMovEaxMem(Const LblName: String);                 Forward;
Procedure BinCmpEaxImm32(V: LongInt);                          Forward;
Procedure CodegenFormatOutput(SIdx, FmtIdx: Integer);          Forward;
Procedure CodegenProcFormat(ProcNode: Integer);                 Forward;
{ TODO 23 : Fonctions integrees numeriques }
Procedure EmitRuntimeNumFunc;                                   Forward;
Procedure CodegenCall(Node: Integer);                           Forward;
{ TODO 24 : Fonctions integrees chaines et date }
Procedure EmitRuntimeStrFunc;                                   Forward;
Procedure EmitRuntimeDateFunc;                                  Forward;
{ TODO 14/15 : DATA step codegen — expressions, boucles, PUT }
Procedure BinStoreEaxMem(Const LblName: String);               Forward;
Procedure BinAddEaxLabelAddr(Const LblName: String);           Forward;
Procedure BinIncMem(Const LblName: String);                    Forward;
Function  FindArrayIdx(Const Name: String): Integer;           Forward;
Procedure RegisterArray(ArrNode: Integer);                     Forward;
Procedure CodegenArrayAddr(Const ArrName: String;
                           IdxNode: Integer);                  Forward;
Procedure CodegenExprEAX(Node: Integer);                       Forward;
Procedure CodegenStmt(Node: Integer);                          Forward;
Procedure CodegenDataStep(DsNode: Integer);                    Forward;

{ ============================================================ }
{ Initialisation des tables                                    }
{ ============================================================ }
Procedure InitTables;
Var I: Integer;
Begin
  SymCount     := 0;
  AstCount     := 0;
  AstRoot      := -1;
  VarCount     := 0;
  DsCount      := 0;
  FmtCount     := 0;
  MacroVarCnt  := 0;
  MacroDefCnt  := 0;
  MacroSrcCnt  := 0;
  MacroSrcPos  := 0;
  BinCodeSize  := 0;
  BinDataSize  := 0;
  BinRDataSize := 0;
  BinBssSize   := 0;
  BinIDataSize := 0;
  BinCurSec    := BIN_SEC_TEXT;
  LabelCount   := 0;
  FixupCount   := 0;
  ImportCount  := 0;
  BinPLKCount  := 0;
  LoopTop      := 0;
  ArrayCount   := 0;
  CurLineNum     := 0;
  LexEOF         := False;
  LexLine        := '';
  LexLineLen     := 0;
  LexPos         := 1;
  LexInComment   := False;
  LexAtStmtStart := True;
  LexEmitEOL     := False;
  CurTokType     := TOK_EOF;
  CurTokStr      := '';
  CurDsRoot      := -1;
  CurDsIdx       := -1;
  HasError     := False;
  ErrorCount   := 0;
  WarnCount    := 0;
  For I := 0 To MAX_VARS-1    Do VarNames[I] := '';
End;

{ ============================================================ }
{ Stubs des sections TODO 02..24 (corps implementes au fur    }
{ et a mesure de chaque TODO)                                  }
{ ============================================================ }

Function MacroVarLookup(Const Name: String): Integer;
Var I: Integer;
Begin
  MacroVarLookup := -1;
  For I := 0 To MacroVarCnt-1 Do
    If MacroVarTbl[I].Name = UpperStr(Name) Then
      Begin MacroVarLookup := I; Exit; End;
End;

Procedure MacroVarSet(Const Name, Value: String; IsGlobal: Boolean);
Var I: Integer;
Begin
  I := MacroVarLookup(Name);
  If I < 0 Then Begin
    If MacroVarCnt >= MAX_MACRO_VARS Then Begin
      CompileError('trop de macro-variables'); Exit;
    End;
    I := MacroVarCnt;
    MacroVarTbl[I].Name := UpperStr(Name);
    Inc(MacroVarCnt);
  End;
  MacroVarTbl[I].Value    := Value;
  MacroVarTbl[I].IsGlobal := IsGlobal;
End;

{ ============================================================ }
{ TODO 02 - MACRO-PREPROCESSEUR : %LET ET SUBSTITUTION &var   }
{ ============================================================ }

Function MacroTrim(Const S: String): String;
Var I, J: Integer;
Begin
  I := 1; J := Length(S);
  While (I <= J) And (S[I] <= ' ') Do Inc(I);
  While (J >= I) And (S[J] <= ' ') Do Dec(J);
  If I > J Then MacroTrim := '' Else MacroTrim := Copy(S, I, J-I+1);
End;

Function MacroStripSemi(Const S: String): String;
Var T: String;
Begin
  T := MacroTrim(S);
  If (Length(T) > 0) And (T[Length(T)] = ';') Then
    T := MacroTrim(Copy(T, 1, Length(T)-1));
  MacroStripSemi := T;
End;

Function MacroIsIdentChar(C: Char): Boolean;
Begin
  MacroIsIdentChar :=
    ((C >= 'A') And (C <= 'Z')) Or
    ((C >= 'a') And (C <= 'z')) Or
    ((C >= '0') And (C <= '9')) Or
    (C = '_');
End;

{ Retourner le mot-cle macro au debut d une ligne (sans %, en majuscules) }
Function MacroGetKW(Const Line: String): String;
Var I, J: Integer;
Begin
  MacroGetKW := '';
  I := 1;
  While (I <= Length(Line)) And (Line[I] <= ' ') Do Inc(I);
  If (I > Length(Line)) Or (Line[I] <> '%') Then Exit;
  Inc(I);
  J := I;
  While (J <= Length(Line)) And
        (((Line[J] >= 'A') And (Line[J] <= 'Z')) Or
         ((Line[J] >= 'a') And (Line[J] <= 'z'))) Do Inc(J);
  MacroGetKW := UpperStr(Copy(Line, I, J-I));
End;

{ Contenu apres le mot-cle macro (%KW <ici>), espace de tete retire }
Function MacroGetAfter(Const Line: String): String;
Var I: Integer;
Begin
  MacroGetAfter := '';
  I := 1;
  While (I <= Length(Line)) And (Line[I] <= ' ') Do Inc(I);
  If (I > Length(Line)) Or (Line[I] <> '%') Then Exit;
  Inc(I);
  While (I <= Length(Line)) And
        (((Line[I] >= 'A') And (Line[I] <= 'Z')) Or
         ((Line[I] >= 'a') And (Line[I] <= 'z'))) Do Inc(I);
  While (I <= Length(Line)) And (Line[I] <= ' ') Do Inc(I);
  MacroGetAfter := Copy(Line, I, 255);
End;

Function MacroSubstitute(Const S: String): String;
Var
  Res  : String;
  I, J : Integer;
  Name : String;
  Idx  : Integer;
Begin
  Res := '';
  I := 1;
  While I <= Length(S) Do Begin
    If S[I] = '&' Then Begin
      If (I < Length(S)) And (S[I+1] = '&') Then Begin
        { && -> & litteral, arret de la substitution a cette position }
        Res := Res + '&';
        Inc(I, 2);
      End Else Begin
        { Collecter le nom de la macro-variable }
        J := I + 1;
        While (J <= Length(S)) And MacroIsIdentChar(S[J]) Do Inc(J);
        If J > I + 1 Then Begin
          Name := UpperStr(Copy(S, I+1, J-I-1));
          Idx  := MacroVarLookup(Name);
          If Idx >= 0 Then
            Res := Res + MacroVarTbl[Idx].Value
          Else Begin
            Res := Res + '&' + Name;
            WriteLn('SASCW32: avertissement ligne ', CurLineNum,
                    ': macro-variable non definie : &', Name);
          End;
          I := J;
        End Else Begin
          { & isole sans identifiant : conserver tel quel }
          Res := Res + '&';
          Inc(I);
        End;
      End;
    End Else Begin
      Res := Res + S[I];
      Inc(I);
    End;
  End;
  MacroSubstitute := Res;
End;

Procedure MacroInitAutoVars;
Begin
  MacroVarSet('SYSDATE', '12JUN26', True);
  MacroVarSet('SYSTIME', '00:00',   True);
  MacroVarSet('SYSVER',  '9.4',     True);
End;

{ %let nom = valeur ; }
Procedure MacroProcLet(Const After: String; IsGlobal: Boolean);
Var
  EqPos : Integer;
  Name  : String;
  Value : String;
  I     : Integer;
Begin
  EqPos := 0;
  For I := 1 To Length(After) Do
    If After[I] = '=' Then Begin EqPos := I; Break; End;
  If EqPos = 0 Then Begin
    CompileWarn('%let sans "=" : ' + After); Exit;
  End;
  Name  := MacroStripSemi(Copy(After, 1, EqPos-1));
  Value := MacroStripSemi(Copy(After, EqPos+1, 255));
  Value := MacroSubstitute(Value);
  If Name <> '' Then
    MacroVarSet(Name, Value, IsGlobal);
End;

{ %put texte ; -> log de compilation uniquement }
Procedure MacroProcPut(Const After: String);
Begin
  WriteLn(MacroSubstitute(MacroStripSemi(After)));
End;

{ %global nom1 nom2 ... ; ou %local nom1 nom2 ... ; }
Procedure MacroProcScope(Const After: String; IsGlobal: Boolean);
Var
  T    : String;
  I, J : Integer;
  Name : String;
Begin
  T := MacroStripSemi(After);
  I := 1;
  While I <= Length(T) Do Begin
    While (I <= Length(T)) And (T[I] <= ' ') Do Inc(I);
    J := I;
    While (J <= Length(T)) And MacroIsIdentChar(T[J]) Do Inc(J);
    If J > I Then Begin
      Name := UpperStr(Copy(T, I, J-I));
      MacroVarSet(Name, '', IsGlobal);
    End;
    I := J + 1;
  End;
End;

{ ============================================================ }
{ TODO 03 - MACRO-PREPROCESSEUR : %MACRO/%MEND, %IF, %DO     }
{ ============================================================ }

{ Recherche insensible a la casse de Pattern dans S ; retourne position ou 0 }
Function MacroPosStr(Const Pattern, S: String): Integer;
Var I, J: Integer; PU, SU: String; Match: Boolean;
Begin
  MacroPosStr := 0;
  PU := UpperStr(Pattern); SU := UpperStr(S);
  If Length(PU) = 0 Then Begin MacroPosStr := 1; Exit; End;
  For I := 1 To Length(SU) - Length(PU) + 1 Do Begin
    Match := True;
    For J := 1 To Length(PU) Do
      If SU[I+J-1] <> PU[J] Then Begin Match := False; Break; End;
    If Match Then Begin MacroPosStr := I; Exit; End;
  End;
End;

{ Trouver la position de %THEN dans S ; retourne 0 si absent }
Function MacroFindThen(Const S: String): Integer;
Var I: Integer; U: String;
Begin
  MacroFindThen := 0;
  U := UpperStr(S);
  For I := 1 To Length(U) - 4 Do
    If (U[I] = '%') And (Copy(U, I+1, 4) = 'THEN') And
       ((I+5 > Length(U)) Or (U[I+5] <= ' ') Or (U[I+5] = ';')) Then
      Begin MacroFindThen := I; Exit; End;
End;

{ Evaluer une condition macro "VAL1 OP VAL2" -> Boolean }
Function EvalMacroCond(Const Cond: String): Boolean;
Var
  T         : String;
  I         : Integer;
  Op        : String;
  OpPos, OpLen : Integer;
  L, R      : String;
  LN, RN    : LongInt;
  NumOK     : Boolean;
Begin
  EvalMacroCond := False;
  T := MacroTrim(Cond);
  Op := ''; OpPos := 0; OpLen := 2;
  { Operateurs 2 caracteres en priorite }
  For I := 1 To Length(T) - 1 Do Begin
    If (T[I] = '>') And (T[I+1] = '=') Then Begin Op:='>='; OpPos:=I; Break; End;
    If (T[I] = '<') And (T[I+1] = '=') Then Begin Op:='<='; OpPos:=I; Break; End;
    If (T[I] = '^') And (T[I+1] = '=') Then Begin Op:='^='; OpPos:=I; Break; End;
    If (T[I] = '~') And (T[I+1] = '=') Then Begin Op:='^='; OpPos:=I; Break; End;
  End;
  OpLen := 2;
  { Operateurs 1 caractere si pas encore trouve }
  If Op = '' Then Begin
    OpLen := 1;
    For I := 1 To Length(T) Do Begin
      If T[I] = '=' Then Begin Op:='=';  OpPos:=I; Break; End;
      If T[I] = '>' Then Begin Op:='>';  OpPos:=I; Break; End;
      If T[I] = '<' Then Begin Op:='<';  OpPos:=I; Break; End;
    End;
  End;
  { Operateurs textuels }
  If Op = '' Then Begin
    I := MacroPosStr(' EQ ', T); If I>0 Then Begin Op:='=';  OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    I := MacroPosStr(' NE ', T); If I>0 Then Begin Op:='^='; OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    I := MacroPosStr(' GE ', T); If I>0 Then Begin Op:='>='; OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    I := MacroPosStr(' GT ', T); If I>0 Then Begin Op:='>';  OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    I := MacroPosStr(' LE ', T); If I>0 Then Begin Op:='<='; OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    I := MacroPosStr(' LT ', T); If I>0 Then Begin Op:='<';  OpPos:=I+1; OpLen:=2; End;
  End;
  If Op = '' Then Begin
    { Pas d operateur : vrai si non-vide et non-zero }
    EvalMacroCond := (T <> '') And (T <> '0'); Exit;
  End;
  L := MacroTrim(Copy(T, 1, OpPos-1));
  R := MacroTrim(Copy(T, OpPos+OpLen, 255));
  { Comparaison numerique si les deux cotes sont numeriques }
  NumOK := True;
  For I := 1 To Length(L) Do
    If Not (((L[I]>='0') And (L[I]<='9')) Or (L[I]='-')) Then
      Begin NumOK := False; Break; End;
  If NumOK Then
    For I := 1 To Length(R) Do
      If Not (((R[I]>='0') And (R[I]<='9')) Or (R[I]='-')) Then
        Begin NumOK := False; Break; End;
  If NumOK And (Length(L) > 0) And (Length(R) > 0) Then Begin
    LN := StrToInt(L); RN := StrToInt(R);
    If Op='='  Then EvalMacroCond := (LN=RN)
    Else If Op='^=' Then EvalMacroCond := (LN<>RN)
    Else If Op='>'  Then EvalMacroCond := (LN>RN)
    Else If Op='<'  Then EvalMacroCond := (LN<RN)
    Else If Op='>=' Then EvalMacroCond := (LN>=RN)
    Else If Op='<=' Then EvalMacroCond := (LN<=RN);
  End Else Begin
    If Op='='  Then EvalMacroCond := (L=R)
    Else If Op='^=' Then EvalMacroCond := (L<>R)
    Else If Op='>'  Then EvalMacroCond := (L>R)
    Else If Op='<'  Then EvalMacroCond := (L<R)
    Else If Op='>=' Then EvalMacroCond := (L>=R)
    Else If Op='<=' Then EvalMacroCond := (L<=R);
  End;
End;

{ Substituer &PARAMNAME par ParamVal dans S (uniquement ce parametre) }
Function MacroSubstParam(Const S, ParamName, ParamVal: String): String;
Var Res: String; I, J: Integer; Name: String;
Begin
  Res := ''; I := 1;
  While I <= Length(S) Do Begin
    If S[I] = '&' Then Begin
      If (I < Length(S)) And (S[I+1] = '&') Then Begin
        Res := Res + '&'; Inc(I, 2);
      End Else Begin
        J := I + 1;
        While (J <= Length(S)) And MacroIsIdentChar(S[J]) Do Inc(J);
        If J > I + 1 Then Begin
          Name := UpperStr(Copy(S, I+1, J-I-1));
          If Name = UpperStr(ParamName) Then Res := Res + ParamVal
          Else Res := Res + '&' + Name;
          I := J;
        End Else Begin Res := Res + '&'; Inc(I); End;
      End;
    End Else Begin Res := Res + S[I]; Inc(I); End;
  End;
  MacroSubstParam := Res;
End;

{ Capturer les lignes du corps d un %macro dans MacroDefTbl[DefIdx].Body }
Procedure MacroCaptureBody(DefIdx: Integer);
Var Line, KW: String; Depth: Integer;
Begin
  Depth := 1;
  MacroDefTbl[DefIdx].BodyCnt := 0;
  While MacroSrcPos < MacroSrcCnt Do Begin
    Line := MacroSrcLines[MacroSrcPos]; Inc(MacroSrcPos);
    KW := MacroGetKW(Line);
    If KW = 'MACRO' Then Inc(Depth);
    If KW = 'MEND' Then Begin
      Dec(Depth);
      If Depth = 0 Then Exit;
    End;
    If MacroDefTbl[DefIdx].BodyCnt < MAX_MACRO_BODY Then Begin
      MacroDefTbl[DefIdx].Body[MacroDefTbl[DefIdx].BodyCnt] := Line;
      Inc(MacroDefTbl[DefIdx].BodyCnt);
    End;
  End;
End;

{ Parser et enregistrer %macro nom(p1,...) }
Procedure MacroCaptureDef(Const After: String);
Var
  T        : String;
  LP, RP   : Integer;
  Name     : String;
  DefIdx   : Integer;
  I, J     : Integer;
  ParStr   : String;
  ParName  : String;
Begin
  T := MacroStripSemi(After);
  LP := 0;
  For I := 1 To Length(T) Do
    If T[I] = '(' Then Begin LP := I; Break; End;
  If LP > 0 Then Begin
    Name := MacroTrim(Copy(T, 1, LP-1));
    RP := LP;
    For I := LP+1 To Length(T) Do
      If T[I] = ')' Then Begin RP := I; Break; End;
    ParStr := Copy(T, LP+1, RP-LP-1);
  End Else Begin
    Name := T; ParStr := '';
  End;
  Name := UpperStr(Name);
  DefIdx := MacroDefLookup(Name);
  If DefIdx < 0 Then Begin
    If MacroDefCnt >= MAX_MACRO_DEFS Then
      Begin CompileWarn('trop de definitions %macro'); Exit; End;
    DefIdx := MacroDefCnt;
    MacroDefTbl[DefIdx].Name := Name;
    Inc(MacroDefCnt);
  End;
  MacroDefTbl[DefIdx].ParamCnt := 0;
  { Parser les parametres separes par virgules }
  I := 1;
  While I <= Length(ParStr) Do Begin
    While (I <= Length(ParStr)) And (ParStr[I] <= ' ') Do Inc(I);
    J := I;
    While (J <= Length(ParStr)) And (ParStr[J] <> ',') Do Inc(J);
    ParName := MacroTrim(Copy(ParStr, I, J-I));
    If (ParName <> '') And (MacroDefTbl[DefIdx].ParamCnt < MAX_MACRO_PRM) Then Begin
      MacroDefTbl[DefIdx].Params[MacroDefTbl[DefIdx].ParamCnt] := UpperStr(ParName);
      Inc(MacroDefTbl[DefIdx].ParamCnt);
    End;
    I := J + 1;
  End;
  MacroCaptureBody(DefIdx);
End;

{ Parser les arguments d un appel %nom(a1, a2, ...) }
Procedure MacroParseCallArgs(Const Line: String;
                              Var Args: TCallArgs; Var ArgCnt: Integer);
Var I, J, LP, RP, Depth: Integer; T: String;
Begin
  ArgCnt := 0; LP := 0;
  For I := 1 To Length(Line) Do
    If Line[I] = '(' Then Begin LP := I; Break; End;
  If LP = 0 Then Exit;
  RP := Length(Line);
  For I := Length(Line) DownTo LP+1 Do
    If Line[I] = ')' Then Begin RP := I; Break; End;
  T := Copy(Line, LP+1, RP-LP-1);
  I := 1; J := 1; Depth := 0;
  While I <= Length(T) Do Begin
    If T[I] = '(' Then Inc(Depth)
    Else If T[I] = ')' Then Dec(Depth)
    Else If (T[I] = ',') And (Depth = 0) Then Begin
      If ArgCnt < MAX_MACRO_PRM Then Begin
        Args[ArgCnt] := MacroTrim(Copy(T, J, I-J)); Inc(ArgCnt);
      End;
      J := I + 1;
    End;
    Inc(I);
  End;
  If (J <= Length(T)) And (ArgCnt < MAX_MACRO_PRM) Then Begin
    Args[ArgCnt] := MacroTrim(Copy(T, J, Length(T)-J+1)); Inc(ArgCnt);
  End;
End;

{ Inserer les lignes du corps de macro dans MacroSrcLines avec substitution des params }
Procedure MacroExecCall(DefIdx: Integer; Const CallArgs: TCallArgs; ArgCnt: Integer);
Var I, J: Integer; BodyLine: String;
Begin
  If MacroSrcCnt + MacroDefTbl[DefIdx].BodyCnt >= MAX_MACRO_LINES Then Begin
    CompileWarn('depassement tampon lors de l expansion de macro'); Exit;
  End;
  { Decaler les lignes restantes vers le bas }
  For I := MacroSrcCnt - 1 DownTo MacroSrcPos Do
    MacroSrcLines[I + MacroDefTbl[DefIdx].BodyCnt] := MacroSrcLines[I];
  Inc(MacroSrcCnt, MacroDefTbl[DefIdx].BodyCnt);
  { Inserer les lignes du corps avec substitution des parametres }
  For I := 0 To MacroDefTbl[DefIdx].BodyCnt - 1 Do Begin
    BodyLine := MacroDefTbl[DefIdx].Body[I];
    For J := 0 To ArgCnt - 1 Do
      BodyLine := MacroSubstParam(BodyLine,
                    MacroDefTbl[DefIdx].Params[J], CallArgs[J]);
    MacroSrcLines[MacroSrcPos + I] := BodyLine;
  End;
End;

{ Executer ou sauter un bloc %do ... %end (SkipMode = ne pas emettre) }
{ Retourne le mot-cle qui a provoque l arret : 'END', 'MEND', 'ELSE' ou '' }
Function MacroRunBlock(Var OutF: Text; SkipMode: Boolean): String;
Var Line, KW: String; Depth: Integer;
Begin
  MacroRunBlock := '';
  If SkipMode Then Begin
    Depth := 1;
    While MacroSrcPos < MacroSrcCnt Do Begin
      Line := MacroSrcLines[MacroSrcPos]; Inc(MacroSrcPos);
      KW := MacroGetKW(Line);
      If KW = 'DO' Then Inc(Depth)
      Else If (KW = 'END') Or (KW = 'MEND') Then Begin
        Dec(Depth);
        If Depth = 0 Then Begin MacroRunBlock := KW; Exit; End;
      End Else If (KW = 'ELSE') And (Depth = 1) Then Begin
        Dec(MacroSrcPos); { restituer pour le caller }
        MacroRunBlock := 'ELSE'; Exit;
      End;
    End;
  End Else Begin
    While MacroSrcPos < MacroSrcCnt Do Begin
      Line := MacroSrcLines[MacroSrcPos]; Inc(MacroSrcPos);
      Inc(CurLineNum);
      KW := MacroGetKW(Line);
      If (KW = 'END') Or (KW = 'MEND') Then Begin
        MacroRunBlock := KW; Exit;
      End Else If KW = 'ELSE' Then Begin
        Dec(MacroSrcPos); { restituer pour le caller }
        MacroRunBlock := 'ELSE'; Exit;
      End Else
        MacroDispatchLine(Line, OutF);
    End;
  End;
End;

{ Traiter %do ; ... %end ; (simple bloc ou iteratif stub) }
Procedure MacroProcDo(Const Line: String; Var OutF: Text);
Begin
  MacroRunBlock(OutF, False);
End;

{ Traiter %if COND %then ACTION [%else ACTION] }
Procedure MacroProcIf(Const Line: String; Var OutF: Text);
Var
  AfterIf  : String;
  ThenPos  : Integer;
  CondStr  : String;
  ThenStr  : String;
  CondVal  : Boolean;
  NextLine : String;
  NextKW   : String;
  ElseStr  : String;
  ElseKW   : String;

  Procedure HandleElse(ThenWasTrue: Boolean);
  Begin
    If MacroSrcPos >= MacroSrcCnt Then Exit;
    NextLine := MacroSrcLines[MacroSrcPos];
    NextKW   := MacroGetKW(NextLine);
    If NextKW <> 'ELSE' Then Exit;
    Inc(MacroSrcPos); Inc(CurLineNum);
    ElseStr := MacroGetAfter(NextLine);
    ElseKW  := MacroGetKW(ElseStr);
    If ElseKW = 'DO' Then
      MacroRunBlock(OutF, ThenWasTrue)
    Else Begin
      If Not ThenWasTrue Then MacroDispatchLine(ElseStr, OutF);
    End;
  End;

Begin
  AfterIf := MacroSubstitute(MacroGetAfter(Line));
  ThenPos := MacroFindThen(AfterIf);
  If ThenPos = 0 Then Begin
    WriteLn(OutF, MacroSubstitute(Line)); Exit;
  End;
  CondStr := MacroTrim(Copy(AfterIf, 1, ThenPos-1));
  ThenStr := MacroTrim(Copy(AfterIf, ThenPos+5, 255));
  CondVal := EvalMacroCond(CondStr);
  If MacroGetKW(ThenStr) = 'DO' Then Begin
    MacroRunBlock(OutF, Not CondVal);
    HandleElse(CondVal);
  End Else Begin
    If CondVal Then MacroDispatchLine(ThenStr, OutF);
    HandleElse(CondVal);
  End;
End;

{ Dispatcher une ligne : executer la directive macro ou emettre en SAS }
Procedure MacroDispatchLine(Const Line: String; Var OutF: Text);
Var
  KW       : String;
  After    : String;
  DefIdx   : Integer;
  CallArgs : TCallArgs;
  ArgCnt   : Integer;
Begin
  KW := MacroGetKW(Line);
  After := MacroGetAfter(Line);
  If      KW = 'LET'    Then MacroProcLet(After, False)
  Else If KW = 'GLOBAL' Then MacroProcScope(After, True)
  Else If KW = 'LOCAL'  Then MacroProcScope(After, False)
  Else If KW = 'PUT'    Then MacroProcPut(After)
  Else If KW = 'MACRO'  Then MacroCaptureDef(After)
  Else If KW = 'MEND'   Then { ignore : fermeture geree par MacroCaptureBody }
  Else If KW = 'IF'     Then MacroProcIf(Line, OutF)
  Else If KW = 'DO'     Then MacroProcDo(Line, OutF)
  Else If KW = 'END'    Then { ignore : fermeture geree par MacroRunBlock }
  Else If KW = 'ELSE'   Then { ignore : geree par MacroProcIf }
  Else If KW <> '' Then Begin
    DefIdx := MacroDefLookup(KW);
    If DefIdx >= 0 Then Begin
      MacroParseCallArgs(Line, CallArgs, ArgCnt);
      MacroExecCall(DefIdx, CallArgs, ArgCnt);
    End Else
      WriteLn(OutF, MacroSubstitute(Line));
  End Else
    WriteLn(OutF, MacroSubstitute(Line));
End;

Function MacroDefLookup(Const Name: String): Integer;
Var I: Integer;
Begin
  MacroDefLookup := -1;
  For I := 0 To MacroDefCnt-1 Do
    If MacroDefTbl[I].Name = UpperStr(Name) Then
      Begin MacroDefLookup := I; Exit; End;
End;

Function MacroExpand(Const SrcPath: String): String;
Var
  SrcF    : Text;
  OutF    : Text;
  TmpPath : String;
  Line    : String;
Begin
  TmpPath := ChangeExt(SrcPath, '.sas~');
  MacroInitAutoVars;

  { Phase 1 : lire toutes les lignes en memoire }
  Assign(SrcF, SrcPath);
  {$I-} Reset(SrcF); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('SASCW32: impossible d ouvrir : ', SrcPath); Halt(1);
  End;
  MacroSrcCnt := 0;
  While Not EOF(SrcF) Do Begin
    ReadLn(SrcF, Line);
    If MacroSrcCnt < MAX_MACRO_LINES Then Begin
      MacroSrcLines[MacroSrcCnt] := Line; Inc(MacroSrcCnt);
    End Else Begin
      WriteLn('SASCW32: source trop grand (max ', MAX_MACRO_LINES, ' lignes)');
      Break;
    End;
  End;
  Close(SrcF);

  { Phase 2 : ouvrir la sortie }
  Assign(OutF, TmpPath);
  {$I-} Rewrite(OutF); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('SASCW32: impossible de creer : ', TmpPath); Halt(1);
  End;

  { Phase 3 : dispatcher chaque ligne }
  MacroSrcPos := 0; CurLineNum := 0;
  While MacroSrcPos < MacroSrcCnt Do Begin
    Line := MacroSrcLines[MacroSrcPos]; Inc(MacroSrcPos); Inc(CurLineNum);
    MacroDispatchLine(Line, OutF);
  End;

  Close(OutF);
  MacroExpand := TmpPath;
End;

{ ============================================================ }
{ Lexeur — TODO 04-05                                          }
{ ============================================================ }

{ Retourne le token-type du mot-cle S (en majuscules), ou      }
{ TOK_IDENT si S n'est pas un mot-cle.                         }
Function LexKeyword(Const S: String): Integer;
Begin
  If      S = 'DATA'        Then LexKeyword := KW_DATA
  Else If S = 'RUN'         Then LexKeyword := KW_RUN
  Else If S = 'PROC'        Then LexKeyword := KW_PROC
  Else If S = 'QUIT'        Then LexKeyword := KW_QUIT
  Else If S = 'SET'         Then LexKeyword := KW_SET
  Else If S = 'MERGE'       Then LexKeyword := KW_MERGE
  Else If S = 'BY'          Then LexKeyword := KW_BY
  Else If S = 'OUTPUT'      Then LexKeyword := KW_OUTPUT
  Else If S = 'DELETE'      Then LexKeyword := KW_DELETE
  Else If S = 'STOP'        Then LexKeyword := KW_STOP
  Else If S = 'RETAIN'      Then LexKeyword := KW_RETAIN
  Else If S = 'INPUT'       Then LexKeyword := KW_INPUT
  Else If S = 'INFILE'      Then LexKeyword := KW_INFILE
  Else If S = 'FILE'        Then LexKeyword := KW_FILE
  Else If S = 'PUT'         Then LexKeyword := KW_PUT
  Else If S = 'ARRAY'       Then LexKeyword := KW_ARRAY
  Else If S = 'DO'          Then LexKeyword := KW_DO
  Else If S = 'WHILE'       Then LexKeyword := KW_WHILE
  Else If S = 'UNTIL'       Then LexKeyword := KW_UNTIL
  Else If S = 'TO'          Then LexKeyword := KW_TO
  Else If S = 'END'         Then LexKeyword := KW_END
  Else If S = 'IF'          Then LexKeyword := KW_IF
  Else If S = 'THEN'        Then LexKeyword := KW_THEN
  Else If S = 'ELSE'        Then LexKeyword := KW_ELSE
  Else If S = 'SELECT'      Then LexKeyword := KW_SELECT
  Else If S = 'WHEN'        Then LexKeyword := KW_WHEN
  Else If S = 'OTHERWISE'   Then LexKeyword := KW_OTHERWISE
  Else If S = 'GOTO'        Then LexKeyword := KW_GOTO
  Else If S = 'LEAVE'       Then LexKeyword := KW_LEAVE
  Else If S = 'CONTINUE'    Then LexKeyword := KW_CONTINUE
  Else If S = 'FORMAT'      Then LexKeyword := KW_FORMAT
  Else If S = 'UPDATE'      Then LexKeyword := KW_UPDATE
  Else If S = 'VAR'         Then LexKeyword := KW_VAR
  Else If S = 'TABLES'      Then LexKeyword := KW_TABLES
  Else If S = 'TITLE'       Then LexKeyword := KW_TITLE
  Else If S = 'FOOTNOTE'    Then LexKeyword := KW_FOOTNOTE
  Else If S = 'CLASS'       Then LexKeyword := KW_CLASS
  Else If S = 'VALUE'       Then LexKeyword := KW_VALUE
  Else If S = 'WHERE'       Then LexKeyword := KW_WHERE
  Else If S = 'AND'         Then LexKeyword := KW_AND
  Else If S = 'OR'          Then LexKeyword := KW_OR
  Else If S = 'NOT'         Then LexKeyword := KW_NOT
  Else If S = 'IN'          Then LexKeyword := KW_IN
  Else If S = 'DESCENDING'  Then LexKeyword := KW_DESCENDING
  Else If S = 'OUT'         Then LexKeyword := KW_OUT
  Else If S = 'NOPRINT'     Then LexKeyword := KW_NOPRINT
  Else If S = 'CARDS'       Then LexKeyword := KW_CARDS
  Else If S = 'DATALINES'   Then LexKeyword := KW_DATALINES
  Else If S = 'DIM'         Then LexKeyword := KW_DIM
  Else If S = 'PRINT'       Then LexKeyword := KW_PRINT
  Else If S = 'MEANS'       Then LexKeyword := KW_MEANS
  Else If S = 'FREQ'        Then LexKeyword := KW_FREQ
  Else If S = 'SORT'        Then LexKeyword := KW_SORT
  Else If S = 'LOW'         Then LexKeyword := KW_LOW
  Else If S = 'HIGH'        Then LexKeyword := KW_HIGH
  Else If S = 'OTHER'       Then LexKeyword := KW_OTHER
  Else                           LexKeyword := TOK_IDENT;
End;

{ Ouvre le fichier source expanse (apres macro-expansion) et   }
{ initialise l'etat du lexeur.                                 }
Procedure LexInit(Const Src: String);
Begin
  Assign(LexSrcF, Src);
  {$I-} Reset(LexSrcF); {$I+}
  If IOResult <> 0 Then Begin
    WriteLn('SASCW32: impossible d''ouvrir le source expanse : ', Src);
    Halt(1);
  End;
  LexEOF         := False;
  LexLine        := '';
  LexLineLen     := 0;
  LexPos         := 1;
  LexInComment   := False;
  LexAtStmtStart := True;
  LexEmitEOL     := False;
  CurTokType     := TOK_EOF;
  CurTokStr      := '';
End;

{ Avance au prochain token; remplit CurTokType et CurTokStr.   }
{ Saute les espaces, commentaires /* */ et commentaires * ; .  }
Procedure LexNextToken;
Var
  Ch, Ch2 : Char;
  T       : String;
Begin
  CurTokType := TOK_EOF;
  CurTokStr  := '';

  { ---- Boucle de saut : espaces + commentaires ---- }
  Repeat
    { Recharger une ligne si on est a la fin }
    While (Not LexEOF) And (LexPos > LexLineLen) Do Begin
      If EOF(LexSrcF) Then Begin
        LexEOF := True; Break;
      End;
      ReadLn(LexSrcF, LexLine);
      Inc(CurLineNum);
      LexLineLen := Length(LexLine);
      LexPos     := 1;
      { TODO 05 : fin de ligne en mode CARDS/DATALINES }
      If LexEmitEOL Then Begin
        CurTokType := TOK_EOL; CurTokStr := ''; Exit;
      End;
    End;
    If LexEOF And (LexPos > LexLineLen) Then Begin
      CurTokType := TOK_EOF; Exit;
    End;

    Ch := LexLine[LexPos];

    { Espaces et caracteres de controle }
    If Ch <= ' ' Then Begin Inc(LexPos); Continue; End;

    { Fin de commentaire de bloc *\/ }
    If LexInComment Then Begin
      If (Ch = '*') And (LexPos < LexLineLen) And
         (LexLine[LexPos + 1] = '/') Then Begin
        LexInComment := False;
        Inc(LexPos, 2);
      End Else
        Inc(LexPos);
      Continue;
    End;

    { Debut de commentaire de bloc \/* }
    If (Ch = '/') And (LexPos < LexLineLen) And
       (LexLine[LexPos + 1] = '*') Then Begin
      LexInComment := True;
      Inc(LexPos, 2);
      Continue;
    End;

    { Commentaire de ligne : * en debut de statement }
    If (Ch = '*') And LexAtStmtStart Then Begin
      While (LexPos <= LexLineLen) And (LexLine[LexPos] <> ';') Do
        Inc(LexPos);
      If LexPos <= LexLineLen Then Begin
        Inc(LexPos);          { sauter le ; }
        LexAtStmtStart := True;
      End;
      Continue;
    End;

    Break;  { caractere reel }
  Until False;

  If LexEOF And (LexPos > LexLineLen) Then Begin
    CurTokType := TOK_EOF; Exit;
  End;

  Ch := LexLine[LexPos];

  { ---- Identifiants et mots-cles ---- }
  If ((Ch >= 'A') And (Ch <= 'Z')) Or
     ((Ch >= 'a') And (Ch <= 'z')) Or (Ch = '_') Then Begin
    T := '';
    While (LexPos <= LexLineLen) And
          (((LexLine[LexPos] >= 'A') And (LexLine[LexPos] <= 'Z')) Or
           ((LexLine[LexPos] >= 'a') And (LexLine[LexPos] <= 'z')) Or
           ((LexLine[LexPos] >= '0') And (LexLine[LexPos] <= '9')) Or
           (LexLine[LexPos] = '_')) Do Begin
      T := T + LexLine[LexPos];
      Inc(LexPos);
    End;
    CurTokStr := UpperStr(T);
    { FIRST. et LAST. : le point fait partie du token }
    If (LexPos <= LexLineLen) And (LexLine[LexPos] = '.') And
       ((CurTokStr = 'FIRST') Or (CurTokStr = 'LAST')) Then Begin
      CurTokStr := CurTokStr + '.';
      Inc(LexPos);
      If CurTokStr = 'FIRST.' Then CurTokType := KW_FIRST
      Else                         CurTokType := KW_LAST;
    End Else
      CurTokType := LexKeyword(CurTokStr);
    LexAtStmtStart := False;
    Exit;
  End;

  { ---- Entiers et flottants ---- }
  If (Ch >= '0') And (Ch <= '9') Then Begin
    T := '';
    While (LexPos <= LexLineLen) And
          ((LexLine[LexPos] >= '0') And (LexLine[LexPos] <= '9')) Do Begin
      T := T + LexLine[LexPos]; Inc(LexPos);
    End;
    { Partie decimale : un chiffre doit suivre le point }
    If (LexPos < LexLineLen) And (LexLine[LexPos] = '.') And
       (LexLine[LexPos + 1] >= '0') And (LexLine[LexPos + 1] <= '9') Then Begin
      T := T + '.'; Inc(LexPos);
      While (LexPos <= LexLineLen) And
            ((LexLine[LexPos] >= '0') And (LexLine[LexPos] <= '9')) Do Begin
        T := T + LexLine[LexPos]; Inc(LexPos);
      End;
      CurTokType := TOK_FLOAT;
    End Else
      CurTokType := TOK_INTEGER;
    CurTokStr      := T;
    LexAtStmtStart := False;
    Exit;
  End;

  { ---- Chaines entre apostrophes ---- }
  If Ch = '''' Then Begin
    Inc(LexPos); T := '';
    While LexPos <= LexLineLen Do Begin
      If LexLine[LexPos] = '''' Then Begin
        Inc(LexPos);
        If (LexPos <= LexLineLen) And (LexLine[LexPos] = '''') Then Begin
          T := T + ''''; Inc(LexPos);    { '' -> apostrophe litterale }
        End Else
          Break;
      End Else Begin
        T := T + LexLine[LexPos]; Inc(LexPos);
      End;
    End;
    CurTokType := TOK_STRING; CurTokStr := T;
    LexAtStmtStart := False; Exit;
  End;

  { ---- Chaines entre guillemets ---- }
  If Ch = '"' Then Begin
    Inc(LexPos); T := '';
    While LexPos <= LexLineLen Do Begin
      If LexLine[LexPos] = '"' Then Begin
        Inc(LexPos);
        If (LexPos <= LexLineLen) And (LexLine[LexPos] = '"') Then Begin
          T := T + '"'; Inc(LexPos);    { "" -> guillemet litteral }
        End Else
          Break;
      End Else Begin
        T := T + LexLine[LexPos]; Inc(LexPos);
      End;
    End;
    CurTokType := TOK_STRING; CurTokStr := T;
    LexAtStmtStart := False; Exit;
  End;

  { ---- Macro-variable residuelle &nom ---- }
  If Ch = '&' Then Begin
    Inc(LexPos); T := '';
    While (LexPos <= LexLineLen) And MacroIsIdentChar(LexLine[LexPos]) Do Begin
      T := T + LexLine[LexPos]; Inc(LexPos);
    End;
    If T <> '' Then Begin
      CurTokType := TOK_MACRO_VAR;
      CurTokStr  := '&' + UpperStr(T);
    End Else Begin
      CurTokType := TOK_AND; CurTokStr := '&';
    End;
    LexAtStmtStart := False; Exit;
  End;

  { ---- Operateurs et ponctuations ---- }
  Inc(LexPos);
  Case Ch Of
    ';': Begin
           CurTokType := TOK_SEMICOL; CurTokStr := ';';
           LexAtStmtStart := True; Exit;
         End;
    ',': Begin CurTokType := TOK_COMMA;   CurTokStr := ','; End;
    '(': Begin CurTokType := TOK_LPAREN;  CurTokStr := '('; End;
    ')': Begin CurTokType := TOK_RPAREN;  CurTokStr := ')'; End;
    '{': Begin CurTokType := TOK_LBRACE;  CurTokStr := '{'; End;
    '}': Begin CurTokType := TOK_RBRACE;  CurTokStr := '}'; End;
    '.': Begin CurTokType := TOK_DOT;     CurTokStr := '.'; End;
    ':': Begin CurTokType := TOK_COLON;   CurTokStr := ':'; End;
    '+': Begin CurTokType := TOK_PLUS;    CurTokStr := '+'; End;
    '-': Begin CurTokType := TOK_MINUS;   CurTokStr := '-'; End;
    '/': Begin CurTokType := TOK_SLASH;   CurTokStr := '/'; End;
    '=': Begin CurTokType := TOK_ASSIGN;  CurTokStr := '='; End;
    '*': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '*') Then Begin
             Inc(LexPos);
             CurTokType := TOK_STARSTAR; CurTokStr := '**';
           End Else Begin
             CurTokType := TOK_STAR; CurTokStr := '*';
           End;
         End;
    '|': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '|') Then Begin
             Inc(LexPos);
             CurTokType := TOK_CONCAT; CurTokStr := '||';
           End Else Begin
             CurTokType := TOK_OR; CurTokStr := '|';
           End;
         End;
    '!': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '!') Then Begin
             Inc(LexPos);
             CurTokType := TOK_CONCAT; CurTokStr := '!!';
           End Else If (LexPos <= LexLineLen) And (LexLine[LexPos] = '=') Then Begin
             Inc(LexPos);
             CurTokType := TOK_NE; CurTokStr := '!=';
           End Else Begin
             CurTokType := TOK_NOT; CurTokStr := '!';
           End;
         End;
    '<': Begin
           If LexPos <= LexLineLen Then Begin
             Ch2 := LexLine[LexPos];
             If Ch2 = '=' Then Begin
               Inc(LexPos); CurTokType := TOK_LE; CurTokStr := '<=';
             End Else If Ch2 = '>' Then Begin
               Inc(LexPos); CurTokType := TOK_NE; CurTokStr := '<>';
             End Else Begin
               CurTokType := TOK_LT; CurTokStr := '<';
             End;
           End Else Begin
             CurTokType := TOK_LT; CurTokStr := '<';
           End;
         End;
    '>': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '=') Then Begin
             Inc(LexPos); CurTokType := TOK_GE; CurTokStr := '>=';
           End Else Begin
             CurTokType := TOK_GT; CurTokStr := '>';
           End;
         End;
    '^': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '=') Then Begin
             Inc(LexPos); CurTokType := TOK_NE; CurTokStr := '^=';
           End Else Begin
             CurTokType := TOK_NOT; CurTokStr := '^';
           End;
         End;
    '~': Begin
           If (LexPos <= LexLineLen) And (LexLine[LexPos] = '=') Then Begin
             Inc(LexPos); CurTokType := TOK_NE; CurTokStr := '~=';
           End Else Begin
             CurTokType := TOK_NOT; CurTokStr := '~';
           End;
         End;
    Else Begin
      CurTokType := TOK_IDENT; CurTokStr := Ch;
    End;
  End;
  LexAtStmtStart := False;
End;

{ ============================================================ }
{ TODO 06 — Parser : structure globale du programme SAS        }
{ ============================================================ }

{ Alloue un noeud AST et retourne son index.                   }
Function AstNew(Kind: Integer; Const Txt: String; Line: Integer): Integer;
Var I: Integer;
Begin
  If AstCount >= MAX_AST Then Begin
    CompileError('trop de noeuds AST'); AstNew := -1; Exit;
  End;
  I := AstCount; Inc(AstCount);
  AstTable[I].Kind        := Kind;
  AstTable[I].Text        := Txt;
  AstTable[I].Left        := -1;
  AstTable[I].Right       := -1;
  AstTable[I].FirstChild  := -1;
  AstTable[I].NextSibling := -1;
  AstTable[I].Line        := Line;
  AstTable[I].SymRef      := -1;
  AstTable[I].NumVal      := 0;
  AstTable[I].IsChar      := False;
  AstNew := I;
End;

{ Attache Child comme dernier enfant de Parent dans l AST.     }
Procedure AstAddChild(Parent, Child: Integer);
Var C: Integer;
Begin
  If (Parent < 0) Or (Child < 0) Then Exit;
  If AstTable[Parent].FirstChild < 0 Then
    AstTable[Parent].FirstChild := Child
  Else Begin
    C := AstTable[Parent].FirstChild;
    While AstTable[C].NextSibling >= 0 Do
      C := AstTable[C].NextSibling;
    AstTable[C].NextSibling := Child;
  End;
End;

{ Avance le lexeur jusqu au ; inclus (ou EOF).                 }
Procedure SkipToSemicolon;
Begin
  While (CurTokType <> TOK_EOF) And (CurTokType <> TOK_SEMICOL) Do
    LexNextToken;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ Dispatch des statements du corps d'un DATA step.             }
Procedure ParseDataStmt;
Begin
  Case CurTokType Of
    KW_OUTPUT:   ParseStmtOutput;
    KW_DELETE:   ParseStmtDelete;
    KW_STOP:     ParseStmtStop;
    KW_RETAIN:   ParseStmtRetain;
    KW_PUT:      ParseStmtPut;      { TODO 15 }
    KW_IF:       ParseStmtIf;       { TODO 11 }
    KW_SELECT:   ParseStmtSelect;   { TODO 12 }
    KW_DO:       ParseStmtDo;       { TODO 13 }
    KW_ARRAY:    ParseStmtArray;    { TODO 14 }
    KW_INFILE:   ParseStmtInfile;   { TODO 16 }
    KW_INPUT:    ParseStmtInput;    { TODO 16 }
    KW_FILE:     ParseStmtFile;     { TODO 16 }
    KW_CARDS,
    KW_DATALINES: ParseStmtCards;  { TODO 16 }
    KW_SET:      ParseStmtSet;      { TODO 17 }
    KW_MERGE:    ParseStmtMerge;    { TODO 17 }
    KW_BY:       ParseStmtBy;       { TODO 17 }
    KW_FORMAT:   ParseStmtFmtDecl;  { TODO 22 }
    KW_GOTO:     ParseStmtGoto;     { TODO 13 }
    KW_LEAVE: Begin
      AstAddChild(CurDsRoot, AstNew(NK_LEAVE, 'LEAVE', CurLineNum));
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;
    KW_CONTINUE: Begin
      AstAddChild(CurDsRoot, AstNew(NK_CONTINUE, 'CONTINUE', CurLineNum));
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;
    TOK_IDENT:   ParseStmtAssign;   { TODO 10 }
  Else
    SkipToSemicolon;
  End;
End;

{ Boucle sur les statements du corps du DATA step.             }
{ Positionne CurDsRoot pour que ParseStmt* y attachent         }
{ leurs noeuds ; sauvegarde et restaure pour les appels        }
{ imbriques futurs.                                            }
Procedure ParseDataStepBody(DsRoot: Integer);
Var SaveDsRoot: Integer;
Begin
  SaveDsRoot := CurDsRoot;
  CurDsRoot  := DsRoot;
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    ParseDataStmt;
  Until False;
  CurDsRoot := SaveDsRoot;
End;

{ Analyse un DATA step complet : DATA nom... ; corps ; RUN ;   }
{ DATA _NULL_ : aucun dataset de sortie, corps execute 1 fois. }
Procedure ParseDataStep;
Var
  DsRoot, DsNode : Integer;
  SaveDsIdx      : Integer;
  IsNull         : Boolean;
Begin
  DsRoot := AstNew(NK_DATASTEP, 'DATA', CurLineNum);
  AstAddChild(AstRoot, DsRoot);
  SaveDsIdx := CurDsIdx;
  CurDsIdx  := -1;
  IsNull    := False;
  LexNextToken; { avancer apres DATA }
  { Noms de datasets de sortie }
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      If UpperStr(CurTokStr) = '_NULL_' Then
        IsNull := True
      Else
        CurDsIdx := GetOrAddDataset(CurTokStr);
      DsNode := AstNew(NK_VAR, CurTokStr, CurLineNum);
      AstAddChild(DsRoot, DsNode);
    End;
    LexNextToken;
  End;
  If IsNull Then AstTable[DsRoot].Text := 'DATA_NULL';
  If CurTokType = TOK_SEMICOL Then LexNextToken;
  ParseDataStepBody(DsRoot);
  CurDsIdx := SaveDsIdx;
End;

{ Lit les options KEY=VAL et drapeaux apres le nom du PROC     }
{ (DATA=ds OUT=ds NOPRINT ...). Consomme le ; de fin.          }
Procedure ParseOptions(Var DsName: String; Var OutDs: String;
                       Var NoPrint: Boolean);
Begin
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    Case CurTokType Of
      KW_DATA: Begin
        LexNextToken;
        If CurTokType = TOK_ASSIGN Then Begin
          LexNextToken;
          If CurTokType <> TOK_SEMICOL Then Begin
            DsName := CurTokStr; LexNextToken;
          End;
        End;
      End;
      KW_OUT: Begin
        LexNextToken;
        If CurTokType = TOK_ASSIGN Then Begin
          LexNextToken;
          If CurTokType <> TOK_SEMICOL Then Begin
            OutDs := CurTokStr; LexNextToken;
          End;
        End;
      End;
      KW_NOPRINT: Begin NoPrint := True; LexNextToken; End;
    Else
      LexNextToken;
    End;
  End;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ Analyse une sous-commande PROC (VAR, BY, TABLES, etc.)       }
{ et ajoute le noeud correspondant sous ProcRoot.              }
Procedure ParseSubCmd(ProcRoot: Integer);
Var
  Node, VarNode : Integer;
  SaveKind      : Integer;
  FmtName       : String;
  FmtIdx        : Integer;
  E             : Integer;
  Lo, Hi        : LongInt;
  Lbl           : String;
  IsOther       : Boolean;
  LoIsLow       : Boolean;
  HiIsHigh      : Boolean;
  IsSingle      : Boolean;
Begin
  SaveKind := CurTokType;
  Case SaveKind Of

    KW_VAR, KW_TABLES, KW_CLASS: Begin
      Case SaveKind Of
        KW_VAR:    Node := AstNew(NK_VAR_LIST, 'VAR',    CurLineNum);
        KW_TABLES: Node := AstNew(NK_VAR_LIST, 'TABLES', CurLineNum);
      Else         Node := AstNew(NK_VAR_LIST, 'CLASS',  CurLineNum);
      End;
      AstAddChild(ProcRoot, Node);
      LexNextToken;
      While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
        If CurTokType = TOK_IDENT Then Begin
          VarNode := AstNew(NK_VAR, CurTokStr, CurLineNum);
          AstAddChild(Node, VarNode);
        End;
        LexNextToken;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;

    KW_BY: Begin
      Node := AstNew(NK_BY, 'BY', CurLineNum);
      AstAddChild(ProcRoot, Node);
      LexNextToken;
      While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
        If CurTokType = KW_DESCENDING Then Begin
          LexNextToken; Continue;
        End;
        If CurTokType = TOK_IDENT Then Begin
          VarNode := AstNew(NK_VAR, CurTokStr, CurLineNum);
          AstAddChild(Node, VarNode);
        End;
        LexNextToken;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;

    KW_TITLE, KW_FOOTNOTE: Begin
      If SaveKind = KW_TITLE Then Node := AstNew(NK_LITERAL, 'TITLE',    CurLineNum)
      Else                       Node := AstNew(NK_LITERAL, 'FOOTNOTE', CurLineNum);
      AstAddChild(ProcRoot, Node);
      LexNextToken;
      If CurTokType = TOK_STRING Then Begin
        AstTable[Node].Text := CurTokStr; LexNextToken;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;

    KW_FORMAT: Begin
      Node := AstNew(NK_FMT_STMT, 'FORMAT', CurLineNum);
      AstAddChild(ProcRoot, Node);
      LexNextToken;
      While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
        If CurTokType = TOK_IDENT Then Begin
          VarNode := AstNew(NK_VAR, CurTokStr, CurLineNum);
          AstAddChild(Node, VarNode);
        End;
        LexNextToken;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;

    KW_VALUE: Begin
      { PROC FORMAT VALUE formatname entrees ;                   }
      { Entrees : [low|num] [- [high|num]] = 'libelle'          }
      {         | other = 'libelle'                             }
      { Stockage dans FmtTable.                                 }
      Node := AstNew(NK_FMT_STMT, 'VALUE', CurLineNum);
      AstAddChild(ProcRoot, Node);
      LexNextToken;
      { Nom du format (sans point) }
      FmtName := '';
      If CurTokType = TOK_IDENT Then Begin
        FmtName := UpperStr(CurTokStr);
        AstTable[Node].Text := FmtName;
        LexNextToken;
      End;
      FmtIdx := -1;
      If FmtName <> '' Then FmtIdx := GetOrAddFormat(FmtName);
      { Boucle sur les entrees jusqu au ; }
      While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
        IsOther := False; LoIsLow := False; HiIsHigh := False;
        IsSingle := True; Lo := 0; Hi := 0; Lbl := '';
        If CurTokType = KW_OTHER Then Begin
          IsOther := True;
          LexNextToken;
        End Else If CurTokType = KW_LOW Then Begin
          LoIsLow := True; IsSingle := False;
          LexNextToken;
        End Else If CurTokType = TOK_INTEGER Then Begin
          Lo := StrToInt(CurTokStr); LexNextToken;
        End Else If CurTokType = TOK_MINUS Then Begin
          { Nombre negatif }
          LexNextToken;
          If CurTokType = TOK_INTEGER Then Begin
            Lo := -StrToInt(CurTokStr); LexNextToken;
          End;
        End Else Begin
          LexNextToken; { token inattendu, skip }
          Continue;
        End;
        { Optionnel : - borne_haute }
        If (Not IsOther) And (CurTokType = TOK_MINUS) Then Begin
          IsSingle := False; LexNextToken;
          If CurTokType = KW_HIGH Then Begin
            HiIsHigh := True; LexNextToken;
          End Else If CurTokType = TOK_INTEGER Then Begin
            Hi := StrToInt(CurTokStr); LexNextToken;
          End Else If CurTokType = TOK_MINUS Then Begin
            LexNextToken;
            If CurTokType = TOK_INTEGER Then Begin
              Hi := -StrToInt(CurTokStr); LexNextToken;
            End;
          End;
        End Else If Not IsOther Then Begin
          Hi := Lo; { valeur unique }
        End;
        { = 'libelle' }
        If CurTokType = TOK_ASSIGN Then Begin
          LexNextToken;
          If CurTokType = TOK_STRING Then Begin
            Lbl := CurTokStr; LexNextToken;
          End;
        End;
        { Enregistrer dans FmtTable }
        If (FmtIdx >= 0) And (FmtTable[FmtIdx].Count < MAX_FMT_ENT) Then Begin
          E := FmtTable[FmtIdx].Count;
          FmtTable[FmtIdx].Entries[E].IsOther  := IsOther;
          FmtTable[FmtIdx].Entries[E].LoIsLow  := LoIsLow;
          FmtTable[FmtIdx].Entries[E].HiIsHigh := HiIsHigh;
          FmtTable[FmtIdx].Entries[E].IsSingle := IsSingle;
          FmtTable[FmtIdx].Entries[E].Lo       := Lo;
          FmtTable[FmtIdx].Entries[E].Hi       := Hi;
          FmtTable[FmtIdx].Entries[E].Lbl      := Lbl;
          Inc(FmtTable[FmtIdx].Count);
        End;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
    End;

    KW_WHERE: Begin
      Node := AstNew(NK_LITERAL, 'WHERE', CurLineNum);
      AstAddChild(ProcRoot, Node);
      SkipToSemicolon;
    End;

  Else
    SkipToSemicolon;
  End;
End;

{ PROC PRINT DATA=ds ; [VAR ...;] [BY ...;] RUN ;              }
Procedure ParseProcPrint(Const DsName: String; NoPrint: Boolean;
                         ProcRoot: Integer);
Begin
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    Case CurTokType Of
      KW_VAR, KW_BY, KW_FORMAT, KW_WHERE,
      KW_TITLE, KW_FOOTNOTE: ParseSubCmd(ProcRoot);
    Else SkipToSemicolon;
    End;
  Until False;
End;

{ PROC MEANS DATA=ds [stats] ; [VAR ...;] [CLASS ...;] RUN ;   }
Procedure ParseProcMeans(Const DsName: String; ProcRoot: Integer);
Begin
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    Case CurTokType Of
      KW_VAR, KW_BY, KW_CLASS, KW_FORMAT, KW_WHERE,
      KW_TITLE, KW_FOOTNOTE: ParseSubCmd(ProcRoot);
    Else SkipToSemicolon;
    End;
  Until False;
End;

{ PROC SORT DATA=ds [OUT=ds2] ; BY [DESCENDING] var... ; RUN ; }
Procedure ParseProcSort(Const DsName: String; Const OutDs: String;
                        ProcRoot: Integer);
Begin
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    If CurTokType = KW_BY Then ParseSubCmd(ProcRoot)
    Else SkipToSemicolon;
  Until False;
End;

{ PROC FREQ DATA=ds [NOPRINT] ; [TABLES ...;] RUN ;            }
Procedure ParseProcFreq(Const DsName: String; NoPrint: Boolean;
                        ProcRoot: Integer);
Begin
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    Case CurTokType Of
      KW_TABLES, KW_BY,
      KW_TITLE, KW_FOOTNOTE: ParseSubCmd(ProcRoot);
    Else SkipToSemicolon;
    End;
  Until False;
End;

{ PROC FORMAT ; VALUE name entrees ; ... RUN ;                  }
Procedure ParseProcFormat(ProcRoot: Integer);
Begin
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    If CurTokType = KW_VALUE Then ParseSubCmd(ProcRoot)
    Else SkipToSemicolon;
  Until False;
End;

{ PROC inconnu : emettre un avertissement et ignorer le corps. }
Procedure ParseProcGeneric(Const ProcName: String; Const DsName: String;
                           ProcRoot: Integer);
Begin
  If ProcRoot >= 0 Then; { evite le note "parametre non utilise" }
  CompileWarn('PROC ' + ProcName + ' non reconnu (DATA=' + DsName + '), corps ignore');
  Repeat
    If CurTokType = TOK_EOF Then Break;
    If (CurTokType = KW_RUN) Or (CurTokType = KW_QUIT) Then Begin
      LexNextToken;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      Break;
    End;
    SkipToSemicolon;
  Until False;
End;

{ Analyse un PROC step et dispatche vers le parseur specifique. }
Procedure ParseProcStep;
Var
  ProcName : String;
  ProcKind : Integer;
  DsName   : String;
  OutDs    : String;
  NoPrint  : Boolean;
  ProcRoot : Integer;
  NodeKind : Integer;
Begin
  { CurTokType = KW_PROC }
  LexNextToken; { avancer sur le nom du PROC }
  ProcName := CurTokStr;
  ProcKind := CurTokType;
  Case ProcKind Of
    KW_PRINT:  NodeKind := NK_PROC_PRINT;
    KW_MEANS:  NodeKind := NK_PROC_MEANS;
    KW_SORT:   NodeKind := NK_PROC_SORT;
    KW_FREQ:   NodeKind := NK_PROC_FREQ;
    KW_FORMAT: NodeKind := NK_PROC_FORMAT;
  Else
    NodeKind := NK_PROC_GEN;
  End;
  ProcRoot := AstNew(NodeKind, ProcName, CurLineNum);
  AstAddChild(AstRoot, ProcRoot);
  LexNextToken; { avancer apres le nom du PROC }
  DsName := ''; OutDs := ''; NoPrint := False;
  ParseOptions(DsName, OutDs, NoPrint);
  { Stocker le nom du dataset et le flag NOPRINT dans le noeud }
  AstTable[ProcRoot].Text   := UpperStr(DsName);
  AstTable[ProcRoot].NumVal := Ord(NoPrint);
  Case ProcKind Of
    KW_PRINT:  ParseProcPrint(DsName, NoPrint, ProcRoot);
    KW_MEANS:  ParseProcMeans(DsName, ProcRoot);
    KW_SORT:   ParseProcSort(DsName, OutDs, ProcRoot);
    KW_FREQ:   ParseProcFreq(DsName, NoPrint, ProcRoot);
    KW_FORMAT: ParseProcFormat(ProcRoot);
  Else
    ParseProcGeneric(ProcName, DsName, ProcRoot);
  End;
End;

{ Boucle principale du parseur : DATA steps et PROC steps.     }
Procedure ParseProgram;
Begin
  AstRoot := AstNew(NK_PROGRAM, 'PROGRAM', 0);
  LexNextToken; { premier token }
  Repeat
    If CurTokType = TOK_EOF Then Break;
    Case CurTokType Of
      KW_DATA:     ParseDataStep;
      KW_PROC:     ParseProcStep;
      TOK_SEMICOL: LexNextToken; { ; isole, ignorer }
    Else
      CompileWarn('statement inattendu au niveau programme : ' + CurTokStr);
      SkipToSemicolon;
    End;
  Until False;
End;

{ ============================================================ }
{ TODO 07 — AST : constructeurs specialises et diagnostic      }
{ ============================================================ }

{ NK_BINOP : operateur binaire.                                }
{ L = operande gauche, R = operande droit (indices AST).       }
Function AstNewBinOp(Const Op: String; L, R, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_BINOP, Op, Line);
  If I >= 0 Then Begin AstTable[I].Left := L; AstTable[I].Right := R; End;
  AstNewBinOp := I;
End;

{ NK_UNOP : operateur unaire (NOT, signe moins).               }
{ Child = operande unique (Left).                              }
Function AstNewUnOp(Const Op: String; Child, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_UNOP, Op, Line);
  If I >= 0 Then AstTable[I].Left := Child;
  AstNewUnOp := I;
End;

{ NK_LITERAL numerique : NumVal = valeur, IsChar = False.      }
Function AstNewLitNum(V: LongInt; Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_LITERAL, IntToStr(V), Line);
  If I >= 0 Then Begin AstTable[I].NumVal := V; AstTable[I].IsChar := False; End;
  AstNewLitNum := I;
End;

{ NK_LITERAL chaine : Text = contenu, IsChar = True.           }
Function AstNewLitStr(Const S: String; Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_LITERAL, S, Line);
  If I >= 0 Then AstTable[I].IsChar := True;
  AstNewLitStr := I;
End;

{ NK_VAR : Text = nom en majuscules, SymRef resolu plus tard.  }
Function AstNewVar(Const Name: String; Line: Integer): Integer;
Begin
  AstNewVar := AstNew(NK_VAR, UpperStr(Name), Line);
End;

{ NK_CALL : Text = nom de fonction, enfants = arguments.       }
Function AstNewCall(Const FuncName: String; Line: Integer): Integer;
Begin
  AstNewCall := AstNew(NK_CALL, UpperStr(FuncName), Line);
End;

{ NK_ASSIGN : Left = NK_VAR cible, Right = expression source.  }
Function AstNewAssign(VarNode, ExprNode, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_ASSIGN, '=', Line);
  If I >= 0 Then Begin AstTable[I].Left := VarNode; AstTable[I].Right := ExprNode; End;
  AstNewAssign := I;
End;

{ NK_IF : Left = condition, Right = branche then.              }
{ FirstChild = branche else (ou -1 si absente).                }
Function AstNewIf(CondN, ThenN, ElseN, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_IF, 'IF', Line);
  If I >= 0 Then Begin
    AstTable[I].Left       := CondN;
    AstTable[I].Right      := ThenN;
    AstTable[I].FirstChild := ElseN;
  End;
  AstNewIf := I;
End;

{ NK_DO : Text = 'PLAIN' | 'WHILE' | 'UNTIL' | 'ITER'.        }
{ Left = expression de controle (sauf PLAIN).                  }
{ FirstChild = liste des statements du corps.                  }
Function AstNewDo(Const DoType: String; Line: Integer): Integer;
Begin
  AstNewDo := AstNew(NK_DO, DoType, Line);
End;

{ NK_SELECT : Left = expression optionnelle (ou -1).           }
{ FirstChild = liste de NK_WHEN.                               }
Function AstNewSelect(ExprNode, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_SELECT, 'SELECT', Line);
  If I >= 0 Then AstTable[I].Left := ExprNode;
  AstNewSelect := I;
End;

{ NK_WHEN : Text = 'WHEN' | 'OTHERWISE'.                       }
{ Left = valeur(s) de comparaison, Right = statement associe.  }
Function AstNewWhen(ValNode, StmtNode, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_WHEN, 'WHEN', Line);
  If I >= 0 Then Begin AstTable[I].Left := ValNode; AstTable[I].Right := StmtNode; End;
  AstNewWhen := I;
End;

{ NK_ARRAY_REF : Text = nom du tableau, Left = index.          }
Function AstNewArrayRef(Const Name: String; IdxNode, Line: Integer): Integer;
Var I: Integer;
Begin
  I := AstNew(NK_ARRAY_REF, UpperStr(Name), Line);
  If I >= 0 Then AstTable[I].Left := IdxNode;
  AstNewArrayRef := I;
End;

{ Relier deux noeuds (utile quand l expression est construite  }
{ en deux passes ou apres le fait).                            }
Procedure AstSetLeft(Node, Child: Integer);
Begin
  If Node >= 0 Then AstTable[Node].Left := Child;
End;

Procedure AstSetRight(Node, Child: Integer);
Begin
  If Node >= 0 Then AstTable[Node].Right := Child;
End;

{ Affiche l AST recursivement sur stdout (diagnostic).         }
Procedure AstDump(N, Indent: Integer);
Var
  C, I  : Integer;
  Pad   : String;
  KName : String;
Begin
  If N < 0 Then Exit;
  Pad := '';
  For I := 1 To Indent Do Pad := Pad + '  ';
  Case AstTable[N].Kind Of
    NK_PROGRAM    : KName := 'PROGRAM';
    NK_DATASTEP   : KName := 'DATASTEP';
    NK_PROCSTEP   : KName := 'PROCSTEP';
    NK_ASSIGN     : KName := 'ASSIGN';
    NK_BINOP      : KName := 'BINOP';
    NK_UNOP       : KName := 'UNOP';
    NK_LITERAL    : KName := 'LITERAL';
    NK_VAR        : KName := 'VAR';
    NK_CALL       : KName := 'CALL';
    NK_ARRAY_REF  : KName := 'ARRAY_REF';
    NK_ARRAY_DEF  : KName := 'ARRAY_DEF';
    NK_IF         : KName := 'IF';
    NK_SELECT     : KName := 'SELECT';
    NK_WHEN       : KName := 'WHEN';
    NK_DO         : KName := 'DO';
    NK_PUT        : KName := 'PUT';
    NK_OUTPUT     : KName := 'OUTPUT';
    NK_DELETE     : KName := 'DELETE';
    NK_STOP       : KName := 'STOP';
    NK_RETAIN     : KName := 'RETAIN';
    NK_SET        : KName := 'SET';
    NK_MERGE      : KName := 'MERGE';
    NK_BY         : KName := 'BY';
    NK_INFILE     : KName := 'INFILE';
    NK_INPUT      : KName := 'INPUT';
    NK_FILE       : KName := 'FILE';
    NK_GOTO       : KName := 'GOTO';
    NK_LEAVE      : KName := 'LEAVE';
    NK_CONTINUE   : KName := 'CONTINUE';
    NK_PROC_PRINT : KName := 'PROC_PRINT';
    NK_PROC_MEANS : KName := 'PROC_MEANS';
    NK_PROC_SORT  : KName := 'PROC_SORT';
    NK_PROC_FREQ  : KName := 'PROC_FREQ';
    NK_PROC_FORMAT: KName := 'PROC_FORMAT';
    NK_PROC_GEN   : KName := 'PROC_GEN';
    NK_VAR_LIST   : KName := 'VAR_LIST';
    NK_FMT_STMT   : KName := 'FMT_STMT';
    NK_CARDS      : KName := 'CARDS';
  Else KName := 'NK_' + IntToStr(AstTable[N].Kind);
  End;
  Write(Pad, KName);
  If AstTable[N].Text <> '' Then Write(' "', AstTable[N].Text, '"');
  If AstTable[N].IsChar      Then Write(' [S]');
  If AstTable[N].NumVal <> 0 Then Write(' =', AstTable[N].NumVal);
  WriteLn(' @L', AstTable[N].Line);
  If AstTable[N].Left >= 0 Then Begin
    WriteLn(Pad, '  [L]:'); AstDump(AstTable[N].Left, Indent + 2);
  End;
  If AstTable[N].Right >= 0 Then Begin
    WriteLn(Pad, '  [R]:'); AstDump(AstTable[N].Right, Indent + 2);
  End;
  C := AstTable[N].FirstChild;
  If C >= 0 Then Begin
    WriteLn(Pad, '  [Ch]:');
    While C >= 0 Do Begin
      AstDump(C, Indent + 2);
      C := AstTable[C].NextSibling;
    End;
  End;
End;

{ ============================================================ }
{ TODO 08 — Table des symboles                                 }
{ ============================================================ }

Function FindSym(Const Name: String; Kind: Integer): Integer;
Var I: Integer;
Begin
  FindSym := -1;
  For I := 0 To SymCount-1 Do
    If (SymTable[I].Name = UpperStr(Name)) And
       ((Kind = SK_NONE) Or (SymTable[I].Kind = Kind)) Then
      Begin FindSym := I; Exit; End;
End;

Function AddSym(Const Name: String; Kind: Integer): Integer;
Begin
  If SymCount >= MAX_SYM Then Begin
    CompileError('table des symboles pleine'); AddSym := -1; Exit;
  End;
  SymTable[SymCount].Name     := UpperStr(Name);
  SymTable[SymCount].Kind     := Kind;
  SymTable[SymCount].Offset   := 0;
  SymTable[SymCount].AsmName  := '';
  SymTable[SymCount].VarIdx   := -1;
  SymTable[SymCount].LblAddr  := -1;
  SymTable[SymCount].IsChar   := False;
  SymTable[SymCount].DsIdx    := -1;
  SymTable[SymCount].FmtIdx   := -1;
  SymTable[SymCount].DeclLine := CurLineNum;
  SymTable[SymCount].Assigned := False;
  SymTable[SymCount].Warned   := False;
  AddSym := SymCount;
  Inc(SymCount);
End;

Function GetOrAddVar(Const Name: String; IsChar: Boolean): Integer;
Var I: Integer;
Begin
  { Rechercher uniquement parmi les variables (pas datasets/labels/formats) }
  I := FindSym(Name, SK_VAR_NUM);
  If I < 0 Then I := FindSym(Name, SK_VAR_CHAR);
  If I >= 0 Then Begin GetOrAddVar := I; Exit; End;
  If IsChar Then I := AddSym(Name, SK_VAR_CHAR)
            Else I := AddSym(Name, SK_VAR_NUM);
  If I >= 0 Then Begin
    SymTable[I].IsChar := IsChar;
    If VarCount < MAX_VARS Then Begin
      SymTable[I].VarIdx := VarCount;
      VarNames[VarCount] := UpperStr(Name);
      Inc(VarCount);
    End;
  End;
  GetOrAddVar := I;
End;

Function GetOrAddDataset(Const Name: String): Integer;
Var I, SI: Integer;
Begin
  For I := 0 To DsCount-1 Do
    If DsTable[I].Name = UpperStr(Name) Then
      Begin GetOrAddDataset := I; Exit; End;
  If DsCount >= MAX_DATASETS Then Begin
    CompileError('trop de datasets'); GetOrAddDataset := -1; Exit;
  End;
  DsTable[DsCount].Name   := UpperStr(Name);
  DsTable[DsCount].VarCnt := 0;
  DsTable[DsCount].RowCnt := 0;
  { Enregistrer dans SymTable pour que FindSym puisse le trouver }
  SI := FindSym(Name, SK_DATASET);
  If SI < 0 Then Begin
    SI := AddSym(Name, SK_DATASET);
    If SI >= 0 Then SymTable[SI].DsIdx := DsCount;
  End;
  GetOrAddDataset := DsCount;
  Inc(DsCount);
End;

{ Cherche une variable dans la liste de colonnes d un dataset.  }
Function FindDsVar(DsIdx: Integer; Const Name: String): Integer;
Var I: Integer; NU: String;
Begin
  FindDsVar := -1;
  If (DsIdx < 0) Or (DsIdx >= DsCount) Then Exit;
  NU := UpperStr(Name);
  For I := 0 To DsTable[DsIdx].VarCnt - 1 Do
    If DsTable[DsIdx].Vars[I].Name = NU Then
      Begin FindDsVar := I; Exit; End;
End;

{ Trouve ou cree une colonne dans le schema d un dataset.       }
Function GetOrAddDsVar(DsIdx: Integer; Const Name: String;
                       IsChar: Boolean): Integer;
Var I: Integer;
Begin
  I := FindDsVar(DsIdx, Name);
  If I >= 0 Then Begin GetOrAddDsVar := I; Exit; End;
  If (DsIdx < 0) Or (DsIdx >= DsCount) Or
     (DsTable[DsIdx].VarCnt >= MAX_DS_COLS) Then Begin
    CompileError('trop de variables dans le dataset ' +
                 DsTable[DsIdx].Name);
    GetOrAddDsVar := -1; Exit;
  End;
  I := DsTable[DsIdx].VarCnt;
  DsTable[DsIdx].Vars[I].Name   := UpperStr(Name);
  DsTable[DsIdx].Vars[I].IsChar := IsChar;
  Inc(DsTable[DsIdx].VarCnt);
  GetOrAddDsVar := I;
End;

{ Cherche un format utilisateur dans FmtTable (sans le . final). }
Function FindFormat(Const Name: String): Integer;
Var I: Integer; NU: String;
Begin
  FindFormat := -1;
  NU := UpperStr(Name);
  If (Length(NU) > 0) And (NU[Length(NU)] = '.') Then
    NU := Copy(NU, 1, Length(NU) - 1);
  For I := 0 To FmtCount - 1 Do
    If FmtTable[I].Name = NU Then
      Begin FindFormat := I; Exit; End;
End;

{ Cree ou retrouve un format utilisateur (PROC FORMAT VALUE ...). }
Function GetOrAddFormat(Const Name: String): Integer;
Var I, SI: Integer; NU: String;
Begin
  I := FindFormat(Name);
  If I >= 0 Then Begin GetOrAddFormat := I; Exit; End;
  If FmtCount >= MAX_FORMATS Then Begin
    CompileError('trop de formats utilisateur'); GetOrAddFormat := -1; Exit;
  End;
  NU := UpperStr(Name);
  If (Length(NU) > 0) And (NU[Length(NU)] = '.') Then
    NU := Copy(NU, 1, Length(NU) - 1);
  FmtTable[FmtCount].Name  := NU;
  FmtTable[FmtCount].Count := 0;
  { Enregistrer dans SymTable }
  SI := FindSym(NU, SK_FORMAT);
  If SI < 0 Then Begin
    SI := AddSym(NU, SK_FORMAT);
    If SI >= 0 Then SymTable[SI].FmtIdx := FmtCount;
  End;
  GetOrAddFormat := FmtCount;
  Inc(FmtCount);
End;

{ Cherche une etiquette GOTO dans SymTable.                     }
Function FindLabel(Const Name: String): Integer;
Begin
  FindLabel := FindSym(Name, SK_LABEL);
End;

{ Cree une etiquette GOTO dans SymTable.                        }
Function AddLabel(Const Name: String): Integer;
Begin
  AddLabel := AddSym(Name, SK_LABEL);
End;

{ Retourne le nom assembleur stable d un symbole.               }
{ Cache le resultat dans AsmName pour eviter de le recalculer.  }
Function SymGenAsmName(Idx: Integer): String;
Begin
  If Idx < 0 Then Begin SymGenAsmName := ''; Exit; End;
  If SymTable[Idx].AsmName <> '' Then Begin
    SymGenAsmName := SymTable[Idx].AsmName; Exit;
  End;
  Case SymTable[Idx].Kind Of
    SK_VAR_NUM  : SymTable[Idx].AsmName := '_SAN_' + SymTable[Idx].Name;
    SK_VAR_CHAR : SymTable[Idx].AsmName := '_SAC_' + SymTable[Idx].Name;
    SK_LABEL    : SymTable[Idx].AsmName := '_SAL_' + SymTable[Idx].Name;
    SK_DATASET  : SymTable[Idx].AsmName := '_SAD_' + SymTable[Idx].Name;
    SK_FORMAT   : SymTable[Idx].AsmName := '_SAF_' + SymTable[Idx].Name;
  Else            SymTable[Idx].AsmName := '_SAS_' + SymTable[Idx].Name;
  End;
  SymGenAsmName := SymTable[Idx].AsmName;
End;

{ Definit l offset .data d une variable (appele par le codegen). }
Procedure SymSetOffset(Idx: Integer; Off: LongInt);
Begin
  If Idx >= 0 Then SymTable[Idx].Offset := Off;
End;

{ Marque une variable comme ayant ete affectee au moins une fois.}
Procedure SymMarkAssigned(Idx: Integer);
Begin
  If Idx >= 0 Then SymTable[Idx].Assigned := True;
End;

{ Emet un avertissement si la variable n a jamais ete affectee. }
Procedure SymWarnUnassigned(Idx: Integer; Const Context: String);
Begin
  If (Idx < 0) Then Exit;
  If (Not SymTable[Idx].Assigned) And (Not SymTable[Idx].Warned) Then Begin
    SymTable[Idx].Warned := True;
    CompileWarn('variable jamais initialisee : ' +
                SymTable[Idx].Name + ' (' + Context + ')');
  End;
End;

{ ============================================================ }
{ TODO 09 — DATA STEP : STRUCTURE ET BOUCLE IMPLICITE          }
{ ============================================================ }

{ OUTPUT ; — emet l observation courante dans le dataset de    }
{ sortie (en V1 : note dans l AST, codegen TODO 25).           }
Procedure ParseStmtOutput;
Var Node: Integer;
Begin
  Node := AstNew(NK_OUTPUT, 'OUTPUT', CurLineNum);
  AstAddChild(CurDsRoot, Node);
  LexNextToken; { avancer apres OUTPUT }
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ DELETE ; — abandonne l observation courante (ne pas ecrire). }
Procedure ParseStmtDelete;
Var Node: Integer;
Begin
  Node := AstNew(NK_DELETE, 'DELETE', CurLineNum);
  AstAddChild(CurDsRoot, Node);
  LexNextToken; { avancer apres DELETE }
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ STOP ; — interrompt immediatement la boucle DATA step.       }
Procedure ParseStmtStop;
Var Node: Integer;
Begin
  Node := AstNew(NK_STOP, 'STOP', CurLineNum);
  AstAddChild(CurDsRoot, Node);
  LexNextToken; { avancer apres STOP }
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ RETAIN var [val] ... ;                                        }
{ Conserve la valeur de chaque variable entre les iterations.  }
{ Valeur initiale optionnelle : numerique, chaine ou signe -.  }
Procedure ParseStmtRetain;
Var
  Node, VarNode : Integer;
  Neg           : Boolean;
Begin
  Node := AstNew(NK_RETAIN, 'RETAIN', CurLineNum);
  AstAddChild(CurDsRoot, Node);
  LexNextToken; { avancer apres RETAIN }
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      VarNode := AstNewVar(CurTokStr, CurLineNum);
      GetOrAddVar(CurTokStr, False);
      AstAddChild(Node, VarNode);
      LexNextToken;
      { Valeur initiale optionnelle }
      Neg := False;
      If CurTokType = TOK_MINUS Then Begin
        Neg := True; LexNextToken;
      End;
      If CurTokType = TOK_INTEGER Then Begin
        If Neg Then
          AstTable[VarNode].NumVal := -StrToInt(CurTokStr)
        Else
          AstTable[VarNode].NumVal := StrToInt(CurTokStr);
        LexNextToken;
      End Else If CurTokType = TOK_FLOAT Then Begin
        { Valeur reelle : on stocke juste le flag IsChar=False }
        LexNextToken;
      End Else If CurTokType = TOK_STRING Then Begin
        AstTable[VarNode].Text   := CurTokStr;
        AstTable[VarNode].IsChar := True;
        GetOrAddVar(AstTable[VarNode].Text, True);
        LexNextToken;
      End Else If Neg Then Begin
        { signe moins orphelin : le remettre dans le flux n est }
        { pas possible ; on ignore simplement }
      End;
    End Else
      LexNextToken; { ignorer tokens inconnus }
  End;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
End;

{ --- Stubs pour TODO 10-17 / 22 / 13 --- }

{ Affectation simple (var = expr;), sommante (var + expr;),    }
{ element de tableau : arr[i] = expr ;  ou etiquette (nom:).   }
Procedure ParseStmtAssign;
Var
  VarName    : String;
  VarNode    : Integer;
  VarNode2   : Integer;
  IdxNode    : Integer;
  ExprNode   : Integer;
  AssignNode : Integer;
  AddNode    : Integer;
  SIdx       : Integer;
  Line       : Integer;
Begin
  Line    := CurLineNum;
  VarName := UpperStr(CurTokStr);
  LexNextToken; { consommer le nom }
  If CurTokType = TOK_COLON Then Begin
    { Etiquette : name: }
    AddLabel(VarName);
    LexNextToken;
    Exit;
  End;
  If CurTokType = TOK_LBRACE Then Begin
    { Element de tableau : arr[i] = expr ;                       }
    LexNextToken;
    IdxNode := ParseExprOr(Line);
    If CurTokType = TOK_RBRACE Then LexNextToken;
    GetOrAddVar(VarName, False);
    If CurTokType = TOK_ASSIGN Then Begin
      LexNextToken; { consommer = }
      ExprNode   := ParseExprOr(Line);
      VarNode    := AstNewArrayRef(VarName, IdxNode, Line);
      AssignNode := AstNewAssign(VarNode, ExprNode, Line);
      AstAddChild(CurDsRoot, AssignNode);
    End;
    If CurTokType = TOK_SEMICOL Then LexNextToken;
    Exit;
  End;
  If CurTokType = TOK_ASSIGN Then Begin
    { var = expr ; }
    SIdx       := GetOrAddVar(VarName, False);
    LexNextToken; { consommer = }
    ExprNode   := ParseExprOr(Line);
    VarNode    := AstNewVar(VarName, Line);
    AssignNode := AstNewAssign(VarNode, ExprNode, Line);
    SymMarkAssigned(SIdx);
    AstAddChild(CurDsRoot, AssignNode);
    If CurTokType = TOK_SEMICOL Then LexNextToken;
    Exit;
  End;
  If CurTokType = TOK_PLUS Then Begin
    { var + expr ; — sommation avec RETAIN implicite }
    SIdx       := GetOrAddVar(VarName, False);
    LexNextToken; { consommer + }
    ExprNode   := ParseExprOr(Line);
    VarNode    := AstNewVar(VarName, Line);
    VarNode2   := AstNewVar(VarName, Line);
    AddNode    := AstNewBinOp('+', VarNode2, ExprNode, Line);
    AssignNode := AstNewAssign(VarNode, AddNode, Line);
    AstTable[AssignNode].Text := 'SUM';
    SymMarkAssigned(SIdx);
    AstAddChild(CurDsRoot, AssignNode);
    If CurTokType = TOK_SEMICOL Then LexNextToken;
    Exit;
  End;
  SkipToSemicolon;
End;

{ PUT — TODO 15 }
{ PUT item1 item2 ... ;                                        }
{ Chaque item est un noeud enfant de NK_PUT.                   }
{ Format inline (best. 8.2) : le point est ignore en V1.       }
Procedure ParseStmtPut;
Var
  PutNode  : Integer;
  ItemNode : Integer;
  Line     : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip PUT }
  PutNode := AstNew(NK_PUT, 'PUT', Line);
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_DOT Then Begin
      { Point isole : indicateur valeur manquante, ignorer }
      LexNextToken;
    End Else Begin
      ItemNode := ParseExprOr(Line);
      AstAddChild(PutNode, ItemNode);
      { Ignorer un format inline qui suit : ident. ou n.m }
      If CurTokType = TOK_DOT Then LexNextToken;
    End;
  End;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, PutNode);
End;

{ ParseIfBody — parse le corps apres THEN ou ELSE.             }
{ Si le token courant est DO : consomme DO ; corps... END ;    }
{ Sinon : un seul statement.                                   }
{ Dans les deux cas, les statements sont enfants d un NK_DO    }
{ temporaire cree ici, qui devient le noeud corps retourne.    }
Function ParseIfBody(BodyLine: Integer): Integer;
Var
  DoNode     : Integer;
  SaveDsRoot : Integer;
Begin
  SaveDsRoot := CurDsRoot;
  DoNode     := AstNewDo('PLAIN', BodyLine);
  CurDsRoot  := DoNode;
  If CurTokType = KW_DO Then Begin
    { Bloc explicite : DO ; stmts... END ; }
    LexNextToken; { sauter DO }
    If CurTokType = TOK_SEMICOL Then LexNextToken; { sauter ; }
    While (CurTokType <> KW_END)  And (CurTokType <> TOK_EOF) And
          (CurTokType <> KW_RUN)  And (CurTokType <> KW_QUIT) Do
      ParseDataStmt;
    If CurTokType = KW_END  Then LexNextToken; { sauter END }
    If CurTokType = TOK_SEMICOL Then LexNextToken; { sauter ; }
  End Else Begin
    { Statement unique (peut etre un IF imbrique) }
    ParseDataStmt;
  End;
  CurDsRoot    := SaveDsRoot;
  ParseIfBody  := DoNode;
End;

{ IF expr THEN corps [ELSE corps]                              }
{ ELSE IF est traite de maniere recursive (nearest-ELSE rule). }
Procedure ParseStmtIf;
Var
  IfNode     : Integer;
  CondNode   : Integer;
  ThenNode   : Integer;
  ElseNode   : Integer;
  SaveDsRoot : Integer;
  Line       : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { sauter IF }
  CondNode := ParseExprOr(Line);
  If CurTokType = KW_THEN Then LexNextToken; { sauter THEN }
  ThenNode := ParseIfBody(Line);
  ElseNode := -1;
  If CurTokType = KW_ELSE Then Begin
    LexNextToken; { sauter ELSE }
    If CurTokType = KW_IF Then Begin
      { ELSE IF — le IF suivant est emballe dans un NK_DO collecteur }
      ElseNode   := AstNewDo('PLAIN', CurLineNum);
      SaveDsRoot := CurDsRoot;
      CurDsRoot  := ElseNode;
      ParseStmtIf; { recursif : gere le ELSE IF et ses ELSE eventuels }
      CurDsRoot  := SaveDsRoot;
    End Else Begin
      ElseNode := ParseIfBody(CurLineNum);
    End;
  End;
  IfNode := AstNewIf(CondNode, ThenNode, ElseNode, Line);
  AstAddChild(CurDsRoot, IfNode);
End;

{ SELECT [(expr)] ; WHEN (val [,val...]) corps ; ... [OTHERWISE corps ;] END ; }
{ SELECT avec expression : comparer expr a chaque valeur de WHEN.             }
{ SELECT sans expression : chaque WHEN contient une condition booleenne.      }
{ WHEN(v1,v2,v3) : les valeurs supplementaires sont enfants du noeud NK_WHEN. }
Procedure ParseStmtSelect;
Var
  SelectNode : Integer;
  WhenNode   : Integer;
  ValNode    : Integer;
  BodyNode   : Integer;
  ExprNode   : Integer;
  ExtraVals  : Array[0..15] Of Integer;
  ExtraCount : Integer;
  I          : Integer;
  Line       : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { sauter SELECT }
  ExprNode := -1;
  { Expression optionnelle : SELECT (expr) ; }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken; { consommer ( }
    ExprNode := ParseExprOr(Line);
    If CurTokType = TOK_RPAREN Then LexNextToken; { consommer ) }
  End;
  If CurTokType = TOK_SEMICOL Then LexNextToken; { consommer ; }
  SelectNode := AstNewSelect(ExprNode, Line);
  { Boucle WHEN / OTHERWISE jusqu a END }
  While (CurTokType <> KW_END)  And (CurTokType <> TOK_EOF) And
        (CurTokType <> KW_RUN)  And (CurTokType <> KW_QUIT) Do Begin
    Line := CurLineNum;
    If CurTokType = KW_WHEN Then Begin
      LexNextToken; { sauter WHEN }
      ValNode    := -1;
      ExtraCount := 0;
      If CurTokType = TOK_LPAREN Then Begin
        LexNextToken; { consommer ( }
        ValNode := ParseExprOr(Line);
        While CurTokType = TOK_COMMA Do Begin
          LexNextToken; { consommer , }
          If ExtraCount < 16 Then Begin
            ExtraVals[ExtraCount] := ParseExprOr(Line);
            Inc(ExtraCount);
          End;
        End;
        If CurTokType = TOK_RPAREN Then LexNextToken; { consommer ) }
      End;
      BodyNode := ParseIfBody(Line);
      WhenNode := AstNewWhen(ValNode, BodyNode, Line);
      For I := 0 To ExtraCount - 1 Do
        AstAddChild(WhenNode, ExtraVals[I]);
      AstAddChild(SelectNode, WhenNode);
    End Else If CurTokType = KW_OTHERWISE Then Begin
      LexNextToken; { sauter OTHERWISE }
      BodyNode := ParseIfBody(Line);
      WhenNode := AstNew(NK_WHEN, 'OTHERWISE', Line);
      AstTable[WhenNode].Right := BodyNode;
      AstAddChild(SelectNode, WhenNode);
    End Else Begin
      SkipToSemicolon; { token inattendu dans le corps SELECT }
    End;
  End;
  If CurTokType = KW_END  Then LexNextToken; { sauter END }
  If CurTokType = TOK_SEMICOL Then LexNextToken; { sauter ; }
  AstAddChild(CurDsRoot, SelectNode);
End;

{ DO ; / DO WHILE(c) ; / DO UNTIL(c) ; / DO v=s TO e [BY p]    }
{ [WHILE(c)] ; — cinq formes, toutes closes par END ;          }
{ Encodage AST NK_DO :                                         }
{   Text = 'PLAIN'|'WHILE'|'UNTIL'|'ITER'|'ITERWHILE'         }
{   WHILE/UNTIL : Left = condition                             }
{   ITER/ITERWHILE : Left=start Right=end SymRef=sym NumVal=pas}
{     (pas=1 si absent, -1 si negatif literal)                 }
{     ITERWHILE : premier enfant = condition WHILE             }
{   Corps = enfants (apres eventuelle cond WHILE/UNTIL).       }
Procedure ParseStmtDo;
Var
  DoNode     : Integer;
  CondNode   : Integer;
  StartNode  : Integer;
  EndNode    : Integer;
  StepExpr   : Integer;
  InnerNode  : Integer;
  VarSym     : Integer;
  SaveDsRoot : Integer;
  Line       : Integer;
  VarName    : String;
  StepLit    : LongInt;
  HasWhile   : Boolean;
Begin
  Line := CurLineNum;
  LexNextToken; { sauter DO }

  If CurTokType = KW_WHILE Then Begin
    { DO WHILE (cond) ; }
    LexNextToken;
    If CurTokType = TOK_LPAREN Then LexNextToken;
    CondNode := ParseExprOr(Line);
    If CurTokType = TOK_RPAREN Then LexNextToken;
    If CurTokType = TOK_SEMICOL Then LexNextToken;
    DoNode := AstNewDo('WHILE', Line);
    AstSetLeft(DoNode, CondNode);

  End Else If CurTokType = KW_UNTIL Then Begin
    { DO UNTIL (cond) ; }
    LexNextToken;
    If CurTokType = TOK_LPAREN Then LexNextToken;
    CondNode := ParseExprOr(Line);
    If CurTokType = TOK_RPAREN Then LexNextToken;
    If CurTokType = TOK_SEMICOL Then LexNextToken;
    DoNode := AstNewDo('UNTIL', Line);
    AstSetLeft(DoNode, CondNode);

  End Else If CurTokType = TOK_SEMICOL Then Begin
    { DO ; — bloc simple }
    LexNextToken;
    DoNode := AstNewDo('PLAIN', Line);

  End Else If CurTokType = TOK_IDENT Then Begin
    { DO var = start TO end [BY pas] [WHILE (cond)] ; }
    VarName := UpperStr(CurTokStr);
    LexNextToken;
    If CurTokType <> TOK_ASSIGN Then Begin
      SkipToSemicolon;
      DoNode := AstNewDo('PLAIN', Line);
    End Else Begin
      LexNextToken; { sauter = }
      StartNode := ParseExprOr(Line);
      VarSym    := GetOrAddVar(VarName, False);
      SymMarkAssigned(VarSym);
      If CurTokType = KW_TO Then LexNextToken;
      EndNode  := ParseExprOr(Line);
      { Pas : BY expression (defaut 1) }
      StepLit  := 1;
      StepExpr := -1;
      If CurTokType = KW_BY Then Begin
        LexNextToken;
        StepExpr := ParseExprOr(Line);
        If (AstTable[StepExpr].Kind = NK_LITERAL) And
           (Not AstTable[StepExpr].IsChar) Then
          StepLit := AstTable[StepExpr].NumVal
        Else If (AstTable[StepExpr].Kind = NK_UNOP) And
                (AstTable[StepExpr].Text = '-') Then Begin
          InnerNode := AstTable[StepExpr].Left;
          If (InnerNode >= 0) And
             (AstTable[InnerNode].Kind = NK_LITERAL) And
             (Not AstTable[InnerNode].IsChar) Then
            StepLit := -AstTable[InnerNode].NumVal
          Else
            StepLit := -1;
        End Else
          StepLit := 1; { expression complexe : V1 approxime a 1 }
      End;
      { Condition WHILE optionnelle }
      HasWhile := False;
      CondNode := -1;
      If CurTokType = KW_WHILE Then Begin
        HasWhile := True;
        LexNextToken;
        If CurTokType = TOK_LPAREN Then LexNextToken;
        CondNode := ParseExprOr(Line);
        If CurTokType = TOK_RPAREN Then LexNextToken;
      End;
      If CurTokType = TOK_SEMICOL Then LexNextToken;
      If HasWhile Then
        DoNode := AstNewDo('ITERWHILE', Line)
      Else
        DoNode := AstNewDo('ITER', Line);
      AstTable[DoNode].Left   := StartNode;
      AstTable[DoNode].Right  := EndNode;
      AstTable[DoNode].SymRef := VarSym;
      AstTable[DoNode].NumVal := StepLit;
      If CondNode >= 0 Then
        AstAddChild(DoNode, CondNode); { WHILE cond : premier enfant }
    End;
  End Else Begin
    SkipToSemicolon;
    DoNode := AstNewDo('PLAIN', Line);
  End;

  { Corps : statements jusqu a END ; }
  SaveDsRoot := CurDsRoot;
  CurDsRoot  := DoNode;
  While (CurTokType <> KW_END)  And (CurTokType <> TOK_EOF) And
        (CurTokType <> KW_RUN)  And (CurTokType <> KW_QUIT) Do
    ParseDataStmt;
  CurDsRoot := SaveDsRoot;
  If CurTokType = KW_END  Then LexNextToken;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, DoNode);
End;

{ ARRAY — TODO 14 }
{ ARRAY nom [n] [type] [elem... | plage x1-xN | _TEMPORARY_] ; }
Procedure ParseStmtArray;
Var
  ArrNode   : Integer;
  VarNode   : Integer;
  Dim1Node  : Integer;
  Dim2Node  : Integer;
  ArrName   : String;
  ElemName  : String;
  Elem2     : String;
  PrefixStr : String;
  Pref2     : String;
  NumFrom   : LongInt;
  NumTo     : LongInt;
  K         : LongInt;
  IsChar    : Boolean;
  IsTemp    : Boolean;
  HasElems  : Boolean;
  Line      : Integer;
  TotalSize : LongInt;
  SIdx      : Integer;
  SplitPos  : Integer;
  I         : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip ARRAY }

  { Lire le nom du tableau }
  ArrName := '';
  If CurTokType = TOK_IDENT Then Begin
    ArrName := UpperStr(CurTokStr);
    LexNextToken;
  End;

  { Creer le noeud NK_ARRAY_DEF }
  ArrNode := AstNew(NK_ARRAY_DEF, ArrName, Line);

  { Parser les dimensions : [dim1] ou [dim1, dim2] }
  Dim1Node  := -1;
  Dim2Node  := -1;
  TotalSize := 1;
  If CurTokType = TOK_LBRACE Then Begin
    LexNextToken; { consommer accolade ouvrante }
    Dim1Node := ParseExprOr(Line);
    If (AstTable[Dim1Node].Kind = NK_LITERAL) And (Not AstTable[Dim1Node].IsChar) Then
      TotalSize := AstTable[Dim1Node].NumVal;
    If CurTokType = TOK_COMMA Then Begin
      LexNextToken; { consommer , }
      Dim2Node := ParseExprOr(Line);
      If (AstTable[Dim2Node].Kind = NK_LITERAL) And (Not AstTable[Dim2Node].IsChar) Then
        TotalSize := TotalSize * AstTable[Dim2Node].NumVal;
    End;
    If CurTokType = TOK_RBRACE Then LexNextToken;
  End;
  AstTable[ArrNode].Left   := Dim1Node;
  AstTable[ArrNode].Right  := Dim2Node;
  AstTable[ArrNode].NumVal := TotalSize;

  { Optionnel $ = tableau de chaines de caracteres }
  IsChar := False;
  If (CurTokType = TOK_IDENT) And (CurTokStr = '$') Then Begin
    IsChar := True;
    LexNextToken;
  End;
  AstTable[ArrNode].IsChar := IsChar;

  { Parser la liste d elements, _TEMPORARY_, ou plage prefixN-prefixM }
  IsTemp   := False;
  HasElems := False;
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      ElemName := UpperStr(CurTokStr);
      LexNextToken;
      If ElemName = '_TEMPORARY_' Then Begin
        IsTemp := True;
      End Else If CurTokType = TOK_MINUS Then Begin
        { Tentative de detection de plage numerotee : prefixN - prefixM }
        SplitPos := Length(ElemName) + 1;
        For I := Length(ElemName) DownTo 1 Do
          If (ElemName[I] >= '0') And (ElemName[I] <= '9') Then
            SplitPos := I
          Else
            Break;
        If (SplitPos > 1) And (SplitPos <= Length(ElemName)) Then Begin
          { ElemName a bien un suffixe numerique }
          PrefixStr := Copy(ElemName, 1, SplitPos - 1);
          NumFrom   := StrToInt(Copy(ElemName, SplitPos, 255));
          LexNextToken; { consommer - }
          If CurTokType = TOK_IDENT Then Begin
            Elem2 := UpperStr(CurTokStr);
            LexNextToken;
            SplitPos := Length(Elem2) + 1;
            For I := Length(Elem2) DownTo 1 Do
              If (Elem2[I] >= '0') And (Elem2[I] <= '9') Then
                SplitPos := I
              Else
                Break;
            If (SplitPos > 1) And (SplitPos <= Length(Elem2)) Then Begin
              Pref2  := Copy(Elem2, 1, SplitPos - 1);
              NumTo  := StrToInt(Copy(Elem2, SplitPos, 255));
              If Pref2 = PrefixStr Then Begin
                { Plage valide : generer prefixK pour K de NumFrom a NumTo }
                HasElems := True;
                For K := NumFrom To NumTo Do Begin
                  ElemName := PrefixStr + IntToStr(K);
                  SIdx     := GetOrAddVar(ElemName, IsChar);
                  SymMarkAssigned(SIdx);
                  VarNode  := AstNewVar(ElemName, Line);
                  AstAddChild(ArrNode, VarNode);
                End;
              End Else Begin
                { Prefixes differents : ajouter les deux noms tels quels }
                HasElems := True;
                SIdx    := GetOrAddVar(ElemName, IsChar);
                SymMarkAssigned(SIdx);
                VarNode := AstNewVar(ElemName, Line);
                AstAddChild(ArrNode, VarNode);
                SIdx    := GetOrAddVar(Elem2, IsChar);
                SymMarkAssigned(SIdx);
                VarNode := AstNewVar(Elem2, Line);
                AstAddChild(ArrNode, VarNode);
              End;
            End Else Begin
              { Elem2 sans suffixe numerique : deux noms simples }
              HasElems := True;
              SIdx    := GetOrAddVar(ElemName, IsChar);
              SymMarkAssigned(SIdx);
              VarNode := AstNewVar(ElemName, Line);
              AstAddChild(ArrNode, VarNode);
              SIdx    := GetOrAddVar(Elem2, IsChar);
              SymMarkAssigned(SIdx);
              VarNode := AstNewVar(Elem2, Line);
              AstAddChild(ArrNode, VarNode);
            End;
          End Else Begin
            { Apres -, pas d identificateur : ajouter le premier nom seul }
            HasElems := True;
            SIdx    := GetOrAddVar(ElemName, IsChar);
            SymMarkAssigned(SIdx);
            VarNode := AstNewVar(ElemName, Line);
            AstAddChild(ArrNode, VarNode);
          End;
        End Else Begin
          { ElemName sans suffixe numerique : nom simple, laisser - en place }
          HasElems := True;
          SIdx    := GetOrAddVar(ElemName, IsChar);
          SymMarkAssigned(SIdx);
          VarNode := AstNewVar(ElemName, Line);
          AstAddChild(ArrNode, VarNode);
        End;
      End Else Begin
        { Nom explicite ordinaire }
        HasElems := True;
        SIdx    := GetOrAddVar(ElemName, IsChar);
        SymMarkAssigned(SIdx);
        VarNode := AstNewVar(ElemName, Line);
        AstAddChild(ArrNode, VarNode);
      End;
    End Else
      LexNextToken; { ignorer token inattendu }
  End;

  { Si aucun element explicite et pas temporaire : noms automatiques nom1..nomN }
  If (Not HasElems) And (Not IsTemp) Then Begin
    For K := 1 To TotalSize Do Begin
      ElemName := ArrName + IntToStr(K);
      SIdx     := GetOrAddVar(ElemName, IsChar);
      SymMarkAssigned(SIdx);
      VarNode  := AstNewVar(ElemName, Line);
      AstAddChild(ArrNode, VarNode);
    End;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, ArrNode);
End;

{ INFILE — TODO 16 }
{ INFILE 'fichier' [DLM='x'] [FIRSTOBS=n] ; ou INFILE CARDS ;  }
{ Node.Text    = nom de fichier ou 'CARDS'/'DATALINES'          }
{ Node.NumVal  = FIRSTOBS (defaut 1)                            }
{ Node.Left    = NK_LITERAL(delimiteur) ou -1 si espace        }
Procedure ParseStmtInfile;
Var
  Node    : Integer;
  OptName : String;
  Line    : Integer;
  Src     : String;
Begin
  Line := CurLineNum;
  LexNextToken; { skip INFILE }

  { Source : chaine 'fichier', CARDS, DATALINES, ou ident }
  Src := 'CARDS';
  If CurTokType = TOK_STRING Then Begin
    Src := CurTokStr; LexNextToken;
  End Else If (CurTokType = KW_CARDS) Or (CurTokType = KW_DATALINES) Then Begin
    Src := UpperStr(CurTokStr); LexNextToken;
  End Else If CurTokType = TOK_IDENT Then Begin
    Src := UpperStr(CurTokStr); LexNextToken;
  End;

  Node := AstNew(NK_INFILE, Src, Line);
  AstTable[Node].NumVal := 1; { FIRSTOBS par defaut }

  { Options DLM= et FIRSTOBS= }
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      OptName := UpperStr(CurTokStr);
      LexNextToken;
      If CurTokType = TOK_ASSIGN Then Begin
        LexNextToken; { skip = }
        If OptName = 'DLM' Then Begin
          If CurTokType = TOK_STRING Then Begin
            AstTable[Node].Left := AstNewLitStr(CurTokStr, Line);
            LexNextToken;
          End Else LexNextToken;
        End Else If OptName = 'FIRSTOBS' Then Begin
          If CurTokType = TOK_INTEGER Then Begin
            AstTable[Node].NumVal := StrToInt(CurTokStr);
            LexNextToken;
          End Else LexNextToken;
        End Else
          LexNextToken; { valeur d option inconnue }
      End;
    End Else
      LexNextToken;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ INPUT — TODO 16 }
{ INPUT var1 [$] [col1-col2] var2 [$] [col1-col2] ... ;        }
{ Chaque variable = NK_VAR enfant de NK_INPUT.                  }
{ Node.IsChar  = True si $ suit le nom                          }
{ Node.NumVal  = (col_debut SHL 16) OR col_fin, ou 0 si delim  }
Procedure ParseStmtInput;
Var
  Node     : Integer;
  VarNode  : Integer;
  VarName  : String;
  IsChar   : Boolean;
  ColStart : LongInt;
  ColEnd   : LongInt;
  Line     : Integer;
  SIdx     : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip INPUT }
  Node := AstNew(NK_INPUT, 'INPUT', Line);

  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      VarName := UpperStr(CurTokStr);
      LexNextToken;

      { Optionnel $ = variable chaine }
      IsChar := False;
      If (CurTokType = TOK_IDENT) And (CurTokStr = '$') Then Begin
        IsChar := True; LexNextToken;
      End;

      { Optionnel col1-col2 }
      ColStart := 0; ColEnd := 0;
      If CurTokType = TOK_INTEGER Then Begin
        ColStart := StrToInt(CurTokStr); LexNextToken;
        If CurTokType = TOK_MINUS Then Begin
          LexNextToken;
          If CurTokType = TOK_INTEGER Then Begin
            ColEnd := StrToInt(CurTokStr); LexNextToken;
          End;
        End;
      End;

      SIdx    := GetOrAddVar(VarName, IsChar);
      SymMarkAssigned(SIdx);
      VarNode := AstNew(NK_VAR, VarName, Line);
      AstTable[VarNode].IsChar := IsChar;
      AstTable[VarNode].SymRef := SIdx;
      If ColStart > 0 Then
        AstTable[VarNode].NumVal := (ColStart SHL 16) Or ColEnd
      Else
        AstTable[VarNode].NumVal := 0;
      AstAddChild(Node, VarNode);
    End Else
      LexNextToken; { token inattendu }
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ FILE — TODO 16 }
{ FILE 'fichier' ; ou FILE PRINT ;                              }
{ Node.Text = nom de fichier ou 'PRINT'                        }
Procedure ParseStmtFile;
Var
  Node : Integer;
  Dest : String;
  Line : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip FILE }

  Dest := '';
  If CurTokType = TOK_STRING Then Begin
    Dest := CurTokStr; LexNextToken;
  End Else If CurTokType = KW_PRINT Then Begin
    Dest := 'PRINT'; LexNextToken;
  End Else If CurTokType = TOK_IDENT Then Begin
    Dest := UpperStr(CurTokStr); LexNextToken;
  End;

  Node := AstNew(NK_FILE, Dest, Line);

  { Ignorer les options restantes }
  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do
    LexNextToken;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ CARDS / DATALINES — TODO 16                                  }
{ cards ; suivi des lignes jusqu a une ligne contenant ;        }
{ Chaque ligne = NK_LITERAL chaine enfant de NK_CARDS.          }
Procedure ParseStmtCards;
Var
  Node     : Integer;
  DataLine : String;
  LitNode  : Integer;
  Line     : Integer;
  P        : Integer;
  TrimL    : String;
Begin
  Line := CurLineNum;
  LexNextToken;  { sauter CARDS / DATALINES → CurTokType = TOK_SEMICOL }
  { Ne pas appeler LexNextToken pour le ; : cela lirait la 1re ligne de donnees }
  { Vider le buffer courant pour que ReadLn lise la suite depuis LexSrcF }
  LexPos := LexLineLen + 1;

  Node := AstNew(NK_CARDS, 'CARDS', Line);

  { Lire les lignes de donnees directement depuis le fichier source }
  While Not EOF(LexSrcF) Do Begin
    ReadLn(LexSrcF, DataLine);
    Inc(CurLineNum);
    { Calcul trim pour detecter la ligne terminatrice ; }
    TrimL := DataLine;
    P := 1;
    While (P <= Length(TrimL)) And (TrimL[P] <= ' ') Do Inc(P);
    TrimL := Copy(TrimL, P, Length(TrimL) - P + 1);
    P := Length(TrimL);
    While (P >= 1) And (TrimL[P] <= ' ') Do Dec(P);
    TrimL := Copy(TrimL, 1, P);
    If (TrimL = ';') Or (TrimL = ';;') Then Break;
    If Length(TrimL) = 0 Then Continue;  { ignorer lignes vides }
    LitNode := AstNewLitStr(DataLine, CurLineNum);
    AstAddChild(Node, LitNode);
  End;

  { Reinitialiser le buffer lexeur pour continuer apres les donnees }
  LexLine    := '';
  LexLineLen := 0;
  LexPos     := 1;

  AstAddChild(CurDsRoot, Node);
  LexNextToken;  { charger le prochain token (ex : RUN) }
End;

{ SET — TODO 17 }
{ SET ds1 [ds2 ...] [END=flag] [NOBS=n] [POINT=p] ;            }
{ Enfants NK_VAR = datasets sources.                           }
{ Node.Left = NK_VAR du flag END= (ou -1).                     }
Procedure ParseStmtSet;
Var
  Node     : Integer;
  Line     : Integer;
  SaveName : String;
  FlagName : String;
Begin
  Line := CurLineNum;
  LexNextToken; { skip SET }
  Node := AstNew(NK_SET, 'SET', Line);

  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If (CurTokType = TOK_IDENT) Or (CurTokType = KW_END) Then Begin
      SaveName := UpperStr(CurTokStr);
      LexNextToken;
      If CurTokType = TOK_ASSIGN Then Begin
        { Option NOM = valeur }
        LexNextToken; { skip = }
        If SaveName = 'END' Then Begin
          If CurTokType = TOK_IDENT Then Begin
            FlagName := UpperStr(CurTokStr);
            GetOrAddVar(FlagName, False);
            AstTable[Node].Left := AstNewVar(FlagName, Line);
            LexNextToken;
          End Else LexNextToken;
        End Else
          LexNextToken; { ignorer valeur de NOBS=, POINT= etc. }
      End Else Begin
        { Nom de dataset source }
        AstAddChild(Node, AstNew(NK_VAR, SaveName, Line));
      End;
    End Else
      LexNextToken;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ MERGE — TODO 17 }
{ MERGE ds1 ds2 [ds3 ...] ;                                    }
{ Enfants NK_VAR = datasets a fusionner.                       }
Procedure ParseStmtMerge;
Var
  Node : Integer;
  Line : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip MERGE }
  Node := AstNew(NK_MERGE, 'MERGE', Line);

  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      AstAddChild(Node, AstNew(NK_VAR, UpperStr(CurTokStr), Line));
      LexNextToken;
      { Ignorer options parenthesees comme (IN=a) }
      If CurTokType = TOK_LPAREN Then Begin
        While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_SEMICOL) And
              (CurTokType <> TOK_EOF) Do LexNextToken;
        If CurTokType = TOK_RPAREN Then LexNextToken;
      End;
    End Else
      LexNextToken;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ BY dans DATA step — TODO 17 }
{ BY [DESCENDING] var1 [DESCENDING] var2 ... ;                 }
{ Enfants NK_VAR = variables de cle BY.                        }
Procedure ParseStmtBy;
Var
  Node    : Integer;
  VarNode : Integer;
  Line    : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip BY }
  Node := AstNew(NK_BY, 'BY', Line);

  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = KW_DESCENDING Then Begin
      LexNextToken; { skip, ordre descendant note pour le prochain var }
    End Else If CurTokType = TOK_IDENT Then Begin
      VarNode := AstNew(NK_VAR, UpperStr(CurTokStr), Line);
      AstAddChild(Node, VarNode);
      LexNextToken;
    End Else
      LexNextToken;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ FORMAT (declaration dans DATA step) — TODO 22 }
{ FORMAT var1 [var2 ...] fmt1. [var3 fmt2.] ... ;              }
{ Lie un format a chaque variable dans la symbol table.        }
{ Un nom suivi de . est un format ; sinon c est une variable.  }
Procedure ParseStmtFmtDecl;
Var
  Node     : Integer;
  VarNode  : Integer;
  TokName  : String;
  FmtName  : String;
  FmtIdx   : Integer;
  SIdx     : Integer;
  Line     : Integer;
  PendBuf  : Array[0..31] Of String;
  PendN    : Integer;
  I        : Integer;
Begin
  Line := CurLineNum;
  LexNextToken; { skip KW_FORMAT }
  Node  := AstNew(NK_FMT_STMT, 'FORMAT', Line);
  PendN := 0;
  FillChar(PendBuf, SizeOf(PendBuf), 0);

  While (CurTokType <> TOK_SEMICOL) And (CurTokType <> TOK_EOF) Do Begin
    If CurTokType = TOK_IDENT Then Begin
      TokName := UpperStr(CurTokStr);
      LexNextToken;
      If CurTokType = TOK_DOT Then Begin
        { Nom de format : appliquer aux variables en attente }
        LexNextToken; { consommer . }
        FmtName := TokName;
        FmtIdx  := GetOrAddFormat(FmtName);
        For I := 0 To PendN - 1 Do Begin
          SIdx := GetOrAddVar(PendBuf[I], False);
          If SIdx >= 0 Then SymTable[SIdx].FmtIdx := FmtIdx;
          VarNode := AstNew(NK_VAR, PendBuf[I], Line);
          AstAddChild(Node, VarNode);
        End;
        PendN := 0;
      End Else Begin
        { Nom de variable : accumuler }
        If PendN < 32 Then Begin
          PendBuf[PendN] := TokName;
          Inc(PendN);
        End;
      End;
    End Else
      LexNextToken;
  End;

  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, Node);
End;

{ GOTO label ; — saut inconditionnel.                          }
{ La definition d etiquette (label:) est geree par             }
{ ParseStmtAssign (TOK_IDENT suivi de TOK_COLON).             }
Procedure ParseStmtGoto;
Var
  LblName : String;
  Line    : Integer;
Begin
  Line    := CurLineNum;
  LblName := '';
  LexNextToken; { sauter GOTO }
  If CurTokType = TOK_IDENT Then Begin
    LblName := UpperStr(CurTokStr);
    LexNextToken;
  End;
  If CurTokType = TOK_SEMICOL Then LexNextToken;
  AstAddChild(CurDsRoot, AstNew(NK_GOTO, LblName, Line));
End;

{ ============================================================ }
{ TODO 10 — DATA STEP : AFFECTATIONS ET OPERATEURS             }
{ Parseur d expressions descendant recursif.                   }
{ Precedence (de la plus forte a la plus faible) :             }
{   primaire  > **  > unaire -/+  > */  > +-                   }
{   > ||  > comparaisons  > NOT  > AND  > OR                   }
{ ============================================================ }

{ ParseExprPrimary : atome de l expression.                    }
{ Reconnait : literal entier/reel/chaine, variable, appel de   }
{ fonction name(...), tableau name[i], parentheses.            }
{ Mot-cle suivi de ( : traite comme appel de fonction.         }
{ Token inattendu : retourne LitNum(0) sans avancer.           }
Function ParseExprPrimary(Line: Integer): Integer;
Var
  T    : Integer;
  Name : String;
  Idx  : Integer;
Begin
  Case CurTokType Of
    TOK_INTEGER: Begin
      T := AstNewLitNum(StrToInt(CurTokStr), Line);
      LexNextToken;
      ParseExprPrimary := T;
    End;
    TOK_FLOAT: Begin
      { Reel : Text = chaine brute, NumVal = 0 ; codegen TODO 25 }
      T := AstNew(NK_LITERAL, CurTokStr, Line);
      LexNextToken;
      ParseExprPrimary := T;
    End;
    TOK_STRING: Begin
      T := AstNewLitStr(CurTokStr, Line);
      LexNextToken;
      ParseExprPrimary := T;
    End;
    TOK_MACRO_VAR: Begin
      T := AstNewVar(CurTokStr, Line);
      GetOrAddVar(CurTokStr, False);
      LexNextToken;
      ParseExprPrimary := T;
    End;
    TOK_IDENT: Begin
      Name := UpperStr(CurTokStr);
      LexNextToken;
      If CurTokType = TOK_LPAREN Then Begin
        { Appel de fonction : name(arg1 [, arg2 ...]) }
        T := AstNewCall(Name, Line);
        LexNextToken; { consommer ( }
        While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do Begin
          Idx := ParseExprOr(Line);
          AstAddChild(T, Idx);
          If CurTokType = TOK_COMMA Then LexNextToken;
        End;
        If CurTokType = TOK_RPAREN Then LexNextToken; { consommer ) }
        ParseExprPrimary := T;
      End Else If CurTokType = TOK_LBRACE Then Begin
        { Acces tableau : name[i]                                 }
        LexNextToken;
        Idx := ParseExprOr(Line);
        If CurTokType = TOK_RBRACE Then LexNextToken;
        T := AstNewArrayRef(Name, Idx, Line);
        GetOrAddVar(Name, False);
        ParseExprPrimary := T;
      End Else Begin
        { Reference de variable simple }
        T := AstNewVar(Name, Line);
        GetOrAddVar(Name, False);
        ParseExprPrimary := T;
      End;
    End;
    TOK_LPAREN: Begin
      LexNextToken; { consommer ( }
      T := ParseExprOr(Line);
      If CurTokType = TOK_RPAREN Then LexNextToken; { consommer ) }
      ParseExprPrimary := T;
    End;
    KW_DATA..KW_OTHER: Begin
      { Mot-cle utilise comme nom de fonction (ex: PUT(n), DIM(a)) }
      Name := UpperStr(CurTokStr);
      LexNextToken;
      If CurTokType = TOK_LPAREN Then Begin
        T := AstNewCall(Name, Line);
        LexNextToken; { consommer ( }
        While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do Begin
          Idx := ParseExprOr(Line);
          AstAddChild(T, Idx);
          If CurTokType = TOK_COMMA Then LexNextToken;
        End;
        If CurTokType = TOK_RPAREN Then LexNextToken;
        ParseExprPrimary := T;
      End Else If (CurTokType = TOK_IDENT) And
                  ((Name = 'FIRST.') Or (Name = 'LAST.')) Then Begin
        { FIRST.var ou LAST.var : variable de groupe BY }
        Name := Name + UpperStr(CurTokStr);
        LexNextToken;
        T := AstNewVar(Name, Line);
        GetOrAddVar(Name, False);
        ParseExprPrimary := T;
      End Else Begin
        { Mot-cle sans () : deja avance, retourner 0 }
        ParseExprPrimary := AstNewLitNum(0, Line);
      End;
    End;
  Else
    { Token inattendu : ne pas avancer, retourner 0 }
    ParseExprPrimary := AstNewLitNum(0, Line);
  End;
End;

{ ** — droite-associatif : a**b**c = a**(b**c).               }
Function ParseExprPow(Line: Integer): Integer;
Var L, R: Integer;
Begin
  L := ParseExprPrimary(Line);
  If CurTokType = TOK_STARSTAR Then Begin
    LexNextToken;
    R := ParseExprUnary(Line); { droite-associatif }
    L := AstNewBinOp('**', L, R, Line);
  End;
  ParseExprPow := L;
End;

{ Unaire - ou + (pas d adressage de precedence supplementaire). }
Function ParseExprUnary(Line: Integer): Integer;
Var Child: Integer;
Begin
  If CurTokType = TOK_MINUS Then Begin
    LexNextToken;
    Child := ParseExprPow(Line);
    ParseExprUnary := AstNewUnOp('-', Child, Line);
  End Else If CurTokType = TOK_PLUS Then Begin
    LexNextToken;
    ParseExprUnary := ParseExprPow(Line);
  End Else
    ParseExprUnary := ParseExprPow(Line);
End;

{ * et / — associatif gauche.                                  }
Function ParseExprMul(Line: Integer): Integer;
Var L, R: Integer; Op: String;
Begin
  L := ParseExprUnary(Line);
  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do Begin
    Op := CurTokStr;
    LexNextToken;
    R := ParseExprUnary(Line);
    L := AstNewBinOp(Op, L, R, Line);
  End;
  ParseExprMul := L;
End;

{ + et - — associatif gauche.                                  }
Function ParseExprAdd(Line: Integer): Integer;
Var L, R: Integer; Op: String;
Begin
  L := ParseExprMul(Line);
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Do Begin
    Op := CurTokStr;
    LexNextToken;
    R := ParseExprMul(Line);
    L := AstNewBinOp(Op, L, R, Line);
  End;
  ParseExprAdd := L;
End;

{ || et !! — concatenation de chaines.                         }
Function ParseExprConcat(Line: Integer): Integer;
Var L, R: Integer;
Begin
  L := ParseExprAdd(Line);
  While CurTokType = TOK_CONCAT Do Begin
    LexNextToken;
    R := ParseExprAdd(Line);
    L := AstNewBinOp('||', L, R, Line);
  End;
  ParseExprConcat := L;
End;

{ = < > <= >= <> ^= ~= != — comparaisons (pas d enchainage).  }
Function ParseExprCmp(Line: Integer): Integer;
Var L, R: Integer; Op: String;
Begin
  L := ParseExprConcat(Line);
  While (CurTokType = TOK_EQ) Or (CurTokType = TOK_LT) Or
        (CurTokType = TOK_GT) Or (CurTokType = TOK_LE) Or
        (CurTokType = TOK_GE) Or (CurTokType = TOK_NE) Do Begin
    Op := CurTokStr;
    LexNextToken;
    R := ParseExprConcat(Line);
    L := AstNewBinOp(Op, L, R, Line);
  End;
  ParseExprCmp := L;
End;

{ NOT / ! / ^ / ~ — negation logique, droite-associatif.       }
Function ParseExprNot(Line: Integer): Integer;
Var Child: Integer;
Begin
  If (CurTokType = TOK_NOT) Or (CurTokType = KW_NOT) Then Begin
    LexNextToken;
    Child := ParseExprNot(Line); { recursif : NOT NOT x = x }
    ParseExprNot := AstNewUnOp('NOT', Child, Line);
  End Else
    ParseExprNot := ParseExprCmp(Line);
End;

{ AND / & — ET logique, associatif gauche.                     }
Function ParseExprAnd(Line: Integer): Integer;
Var L, R: Integer;
Begin
  L := ParseExprNot(Line);
  While (CurTokType = TOK_AND) Or (CurTokType = KW_AND) Do Begin
    LexNextToken;
    R := ParseExprNot(Line);
    L := AstNewBinOp('AND', L, R, Line);
  End;
  ParseExprAnd := L;
End;

{ OR / | — OU logique, associatif gauche.                      }
{ Point d entree principal du parseur d expressions.           }
Function ParseExprOr(Line: Integer): Integer;
Var L, R: Integer;
Begin
  L := ParseExprAnd(Line);
  While (CurTokType = TOK_OR) Or (CurTokType = KW_OR) Do Begin
    LexNextToken;
    R := ParseExprAnd(Line);
    L := AstNewBinOp('OR', L, R, Line);
  End;
  ParseExprOr := L;
End;

{ ============================================================ }
{ TODO 14/15 — DATA step : codegen expressions, boucles, PUT  }
{ ============================================================ }

{ MOV [addr32], EAX — stocke EAX en memoire (ABS32 fixup).    }
Procedure BinStoreEaxMem(Const LblName: String);
Begin
  BinEmit8($A3);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := LblName;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

{ ADD EAX, VA(label) — additionne l adresse absolue du label.  }
Procedure BinAddEaxLabelAddr(Const LblName: String);
Begin
  BinEmit8($05);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := LblName;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

{ INC dword [addr32] — incremente la variable en memoire.      }
Procedure BinIncMem(Const LblName: String);
Begin
  BinEmit8($FF); BinEmit8($05);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := LblName;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

{ Cherche un tableau par nom dans ArrayTable. Retourne -1 si absent. }
Function FindArrayIdx(Const Name: String): Integer;
Var I: Integer;
Begin
  FindArrayIdx := -1;
  For I := 0 To ArrayCount - 1 Do
    If ArrayTable[I].Name = Name Then Begin
      FindArrayIdx := I; Exit;
    End;
End;

{ Enregistre un NK_ARRAY_DEF dans ArrayTable.                  }
{ _TEMPORARY_ (aucun enfant) : alloue N dwords en .data.       }
{ Nomme ou auto-genere (enfants = elements) : base = premier.  }
Procedure RegisterArray(ArrNode: Integer);
Var
  AName : String;
  BLbl  : String;
  ASize : Integer;
  Child : Integer;
  SIdx  : Integer;
  K     : Integer;
Begin
  If ArrayCount >= MAX_ARRAYS Then Exit;
  AName := AstTable[ArrNode].Text;
  ASize := AstTable[ArrNode].NumVal;
  If ASize <= 0 Then ASize := 1;
  If FindArrayIdx(AName) >= 0 Then Exit;
  Child := AstTable[ArrNode].FirstChild;
  If Child >= 0 Then Begin
    { Non-temporaire : premier element deja alloue par AllocVars }
    SIdx := FindSym(AstTable[Child].Text, SK_NONE);
    If SIdx >= 0 Then BLbl := SymTable[SIdx].AsmName
    Else BLbl := '_sas_v_' + AstTable[Child].Text;
    ArrayTable[ArrayCount].IsTemp := False;
  End Else Begin
    { _TEMPORARY_ : allouer dans .data apres les variables }
    BLbl := '_satmp_' + AName;
    BinDefineDataLabel(BLbl);
    For K := 1 To ASize Do Begin
      BinEmitDataByte(0); BinEmitDataByte(0);
      BinEmitDataByte(0); BinEmitDataByte(0);
    End;
    ArrayTable[ArrayCount].IsTemp := True;
  End;
  ArrayTable[ArrayCount].Name      := AName;
  ArrayTable[ArrayCount].BaseLabel := BLbl;
  ArrayTable[ArrayCount].TotalSize := ASize;
  Inc(ArrayCount);
End;

{ EAX = adresse de l element : base_VA + (index-1)*4.         }
Procedure CodegenArrayAddr(Const ArrName: String; IdxNode: Integer);
Var AIdx: Integer;
Begin
  AIdx := FindArrayIdx(ArrName);
  If AIdx < 0 Then Begin
    CompileWarn('ARRAY inconnu : ' + ArrName);
    BinEmit8($31); BinEmit8($C0); Exit;
  End;
  CodegenExprEAX(IdxNode);
  BinEmit8($48);                         { DEC EAX (0-base)    }
  BinEmit8($C1); BinEmit8($E0); BinEmit8($02); { SHL EAX,2    }
  BinAddEaxLabelAddr(ArrayTable[AIdx].BaseLabel); { +base_VA   }
End;

{ Evalue l expression Node, resultat dans EAX.                 }
{ Registres utilises : EAX, ECX. EDX utilise par IDIV.         }
Procedure CodegenExprEAX(Node: Integer);
Var
  SIdx    : Integer;
  AIdx    : Integer;
  V       : LongInt;
  LblStr  : String;
  Child   : Integer;
  ArgList : Array[0..15] Of Integer;
  ArgCnt  : Integer;
  I       : Integer;
Begin
  If Node < 0 Then Begin
    BinEmit8($31); BinEmit8($C0); Exit;
  End;
  Case AstTable[Node].Kind Of
    NK_LITERAL: Begin
      If AstTable[Node].IsChar Then Begin
        LblStr := EmitRDataStr(AstTable[Node].Text);
        BinPushLabel(LblStr); BinEmit8($58); { PUSH addr; POP EAX }
      End Else Begin
        V := AstTable[Node].NumVal;
        BinEmit8($B8); BinEmit32(V);
      End;
    End;
    NK_VAR: Begin
      SIdx := FindSym(AstTable[Node].Text, SK_NONE);
      If SIdx >= 0 Then BinMovEaxMem(SymTable[SIdx].AsmName)
      Else Begin BinEmit8($31); BinEmit8($C0); End;
    End;
    NK_ARRAY_REF: Begin
      CodegenArrayAddr(AstTable[Node].Text, AstTable[Node].Left);
      BinEmit8($8B); BinEmit8($00);      { MOV EAX,[EAX]       }
    End;
    NK_BINOP: Begin
      CodegenExprEAX(AstTable[Node].Left);
      BinEmit8($50);                     { PUSH EAX (gauche)   }
      CodegenExprEAX(AstTable[Node].Right);
      BinEmit8($59);                     { POP ECX  (gauche)   }
      If AstTable[Node].Text = '+' Then
        Begin BinEmit8($01); BinEmit8($C8); End  { ADD EAX,ECX }
      Else If AstTable[Node].Text = '-' Then Begin
        BinEmit8($29); BinEmit8($C1);   { SUB ECX,EAX }
        BinEmit8($89); BinEmit8($C8);   { MOV EAX,ECX }
      End Else If AstTable[Node].Text = '*' Then
        Begin BinEmit8($0F); BinEmit8($AF); BinEmit8($C1); End { IMUL EAX,ECX }
      Else If AstTable[Node].Text = '/' Then Begin
        BinEmit8($91);                  { XCHG EAX,ECX : EAX=G }
        BinEmit8($99);                  { CDQ                  }
        BinEmit8($F7); BinEmit8($F9);   { IDIV ECX             }
      End Else If AstTable[Node].Text = '**' Then Begin
        { Puissance : appel runtime stdcall pow(base,exp) }
        BinEmit8($50);                  { PUSH EAX (exposant)  }
        BinEmit8($51);                  { PUSH ECX (base)      }
        BinCallLabel('_SASRT_pow');
      End Else If (AstTable[Node].Text = '=')  Or
                  (AstTable[Node].Text = '<')  Or
                  (AstTable[Node].Text = '>')  Or
                  (AstTable[Node].Text = '<=') Or
                  (AstTable[Node].Text = '>=') Or
                  (AstTable[Node].Text = '<>') Then Begin
        { Comparaison signee : ECX=gauche, EAX=droite }
        { CMP ECX, EAX (39 C1) → ECX - EAX }
        BinEmit8($39); BinEmit8($C1);
        If AstTable[Node].Text = '='  Then Begin
          BinEmit8($0F); BinEmit8($94); BinEmit8($C0); { SETE AL  }
        End Else If AstTable[Node].Text = '<>' Then Begin
          BinEmit8($0F); BinEmit8($95); BinEmit8($C0); { SETNE AL }
        End Else If AstTable[Node].Text = '<'  Then Begin
          BinEmit8($0F); BinEmit8($9C); BinEmit8($C0); { SETL AL  }
        End Else If AstTable[Node].Text = '<=' Then Begin
          BinEmit8($0F); BinEmit8($9E); BinEmit8($C0); { SETLE AL }
        End Else If AstTable[Node].Text = '>'  Then Begin
          BinEmit8($0F); BinEmit8($9F); BinEmit8($C0); { SETG AL  }
        End Else Begin
          BinEmit8($0F); BinEmit8($9D); BinEmit8($C0); { SETGE AL }
        End;
        BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);   { MOVZX EAX,AL }
      End Else If AstTable[Node].Text = 'AND' Then Begin
        { ECX=gauche, EAX=droite : (ECX<>0) AND (EAX<>0) }
        BinEmit8($85); BinEmit8($C9);                   { TEST ECX,ECX }
        BinEmit8($0F); BinEmit8($95); BinEmit8($C1);   { SETNE CL     }
        BinEmit8($85); BinEmit8($C0);                   { TEST EAX,EAX }
        BinEmit8($0F); BinEmit8($95); BinEmit8($C0);   { SETNE AL     }
        BinEmit8($20); BinEmit8($C8);                   { AND AL,CL    }
        BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);   { MOVZX EAX,AL }
      End Else If AstTable[Node].Text = 'OR' Then Begin
        { ECX=gauche, EAX=droite : (ECX<>0) OR (EAX<>0) }
        BinEmit8($09); BinEmit8($C8);                   { OR EAX,ECX   }
        BinEmit8($0F); BinEmit8($95); BinEmit8($C0);   { SETNE AL     }
        BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);   { MOVZX EAX,AL }
      End Else
        Begin BinEmit8($31); BinEmit8($C0); End;
    End;
    NK_UNOP: Begin
      If AstTable[Node].Text = '-' Then Begin
        CodegenExprEAX(AstTable[Node].Left);
        BinEmit8($F7); BinEmit8($D8);   { NEG EAX             }
      End Else If AstTable[Node].Text = 'NOT' Then Begin
        CodegenExprEAX(AstTable[Node].Left);
        BinEmit8($85); BinEmit8($C0);   { TEST EAX,EAX        }
        BinEmit8($0F); BinEmit8($94); BinEmit8($C0); { SETE AL }
        BinEmit8($0F); BinEmit8($B6); BinEmit8($C0); { MOVZX  }
      End Else
        CodegenExprEAX(AstTable[Node].Left);
    End;
    NK_CALL: Begin
      If AstTable[Node].Text = 'DIM' Then Begin
        Child := AstTable[Node].FirstChild;
        AIdx  := -1;
        If Child >= 0 Then AIdx := FindArrayIdx(AstTable[Child].Text);
        If AIdx >= 0 Then V := ArrayTable[AIdx].TotalSize Else V := 0;
        BinEmit8($B8); BinEmit32(V);    { MOV EAX, dim        }
      End Else Begin
        { Empiler les args gauche-a-droite, puis appeler }
        ArgCnt := 0;
        Child  := AstTable[Node].FirstChild;
        While (Child >= 0) And (ArgCnt < 16) Do Begin
          ArgList[ArgCnt] := Child; Inc(ArgCnt);
          Child := AstTable[Child].NextSibling;
        End;
        For I := ArgCnt - 1 DownTo 0 Do Begin
          CodegenExprEAX(ArgList[I]);
          BinEmit8($50);
        End;
        CodegenCall(Node);
      End;
    End;
  Else
    BinEmit8($31); BinEmit8($C0);
  End;
End;

{ Emet le code pour un statement du DATA step.                 }
Procedure CodegenStmt(Node: Integer);
Var
  Tag        : String;
  LblTop     : String;
  LblEnd     : String;
  LblElse    : String;
  LblNext    : String;
  LblStr     : String;
  SIdx       : Integer;
  StartN     : Integer;
  EndN       : Integer;
  StepV      : LongInt;
  Child      : Integer;
  ArrName    : String;
  IdxNode    : Integer;
  RhsNode    : Integer;
  LeftN      : Integer;
  SelectExpr : Integer;
  WhenN      : Integer;
  WIdx       : Integer;
Begin
  If Node < 0 Then Exit;
  Case AstTable[Node].Kind Of

    NK_ARRAY_DEF: ;  { Deja enregistre en pass 1 — aucun code }

    NK_ASSIGN: Begin
      RhsNode := AstTable[Node].Right;
      LeftN   := AstTable[Node].Left;
      If LeftN < 0 Then Exit;
      If AstTable[LeftN].Kind = NK_VAR Then Begin
        SIdx := FindSym(AstTable[LeftN].Text, SK_NONE);
        CodegenExprEAX(RhsNode);
        If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
      End Else If AstTable[LeftN].Kind = NK_ARRAY_REF Then Begin
        ArrName := AstTable[LeftN].Text;
        IdxNode := AstTable[LeftN].Left;
        CodegenExprEAX(RhsNode);
        BinEmit8($50);                  { PUSH EAX (valeur)   }
        CodegenArrayAddr(ArrName, IdxNode);
        BinEmit8($89); BinEmit8($C1);  { MOV ECX, EAX (addr) }
        BinEmit8($58);                  { POP EAX  (valeur)   }
        BinEmit8($89); BinEmit8($01);  { MOV [ECX], EAX      }
      End;
    End;

    NK_DO: Begin
      Inc(BinPLKCount);
      Tag    := IntToStr(BinPLKCount);
      LblTop := '_dot' + Tag;
      LblEnd := '_doe' + Tag;
      If AstTable[Node].Text = 'ITER' Then Begin
        StartN := AstTable[Node].Left;
        EndN   := AstTable[Node].Right;
        StepV  := AstTable[Node].NumVal;
        SIdx   := AstTable[Node].SymRef;
        { Init }
        CodegenExprEAX(StartN);
        If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        { Sommet de boucle : tester i <= end }
        BinDefineLabel(LblTop);
        CodegenExprEAX(EndN);
        BinEmit8($89); BinEmit8($C1); { MOV ECX, EAX (end) }
        If SIdx >= 0 Then BinMovEaxMem(SymTable[SIdx].AsmName);
        BinEmit8($3B); BinEmit8($C1); { CMP EAX, ECX }
        If StepV >= 0 Then BinJccLabel(15, LblEnd)  { JG : i>end }
        Else               BinJccLabel(12, LblEnd);  { JL : i<end }
        { Corps }
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        { Increment }
        If (StepV = 1) And (SIdx >= 0) Then
          BinIncMem(SymTable[SIdx].AsmName)
        Else If SIdx >= 0 Then Begin
          BinMovEaxMem(SymTable[SIdx].AsmName);
          BinEmit8($05); BinEmit32(StepV);
          BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
        BinJmpLabel(LblTop);
        BinDefineLabel(LblEnd);
      End Else If AstTable[Node].Text = 'WHILE' Then Begin
        BinDefineLabel(LblTop);
        CodegenExprEAX(AstTable[Node].Left);
        BinEmit8($85); BinEmit8($C0);   { TEST EAX,EAX }
        BinJccLabel(4, LblEnd);         { JZ lbl_end }
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        BinJmpLabel(LblTop);
        BinDefineLabel(LblEnd);
      End Else If AstTable[Node].Text = 'UNTIL' Then Begin
        BinDefineLabel(LblTop);
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        CodegenExprEAX(AstTable[Node].Left);
        BinEmit8($85); BinEmit8($C0);
        BinJccLabel(4, LblTop);         { JZ lbl_top (tant que cond faux) }
        BinDefineLabel(LblEnd);
      End Else Begin
        { PLAIN, ITERWHILE, et autres : emettre le corps }
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        BinDefineLabel(LblEnd);
      End;
    End;

    NK_PUT: Begin
      Child := AstTable[Node].FirstChild;
      While Child >= 0 Do Begin
        If AstTable[Child].Kind = NK_LITERAL Then Begin
          If AstTable[Child].IsChar Then Begin
            LblStr := EmitRDataStr(AstTable[Child].Text);
            BinPushLabel(LblStr);
            BinCallLabel('_SASRT_write_str');
          End Else Begin
            BinEmit8($B8); BinEmit32(AstTable[Child].NumVal);
            BinEmit8($50);
            BinCallLabel('_SASRT_write_num');
          End;
        End Else If AstTable[Child].Kind = NK_VAR Then Begin
          SIdx := FindSym(AstTable[Child].Text, SK_NONE);
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            BinPushMem32(SymTable[SIdx].AsmName);
            BinCallLabel('_SASRT_write_str');
          End Else Begin
            CodegenExprEAX(Child);
            BinEmit8($50);
            BinCallLabel('_SASRT_write_num');
          End;
        End Else Begin
          CodegenExprEAX(Child);
          BinEmit8($50);
          BinCallLabel('_SASRT_write_num');
        End;
        Child := AstTable[Child].NextSibling;
      End;
      BinCallLabel('_SASRT_newline');
    End;

    NK_IF: Begin
      Inc(BinPLKCount);
      Tag     := IntToStr(BinPLKCount);
      LblElse := '_ife' + Tag;
      LblEnd  := '_iff' + Tag;
      CodegenExprEAX(AstTable[Node].Left);
      BinEmit8($85); BinEmit8($C0);
      If AstTable[Node].FirstChild >= 0 Then Begin
        BinJccLabel(4, LblElse);
        CodegenStmt(AstTable[Node].Right);
        BinJmpLabel(LblEnd);
        BinDefineLabel(LblElse);
        CodegenStmt(AstTable[Node].FirstChild);
        BinDefineLabel(LblEnd);
      End Else Begin
        BinJccLabel(4, LblEnd);
        CodegenStmt(AstTable[Node].Right);
        BinDefineLabel(LblEnd);
      End;
    End;

    NK_SELECT: Begin
      Inc(BinPLKCount);
      Tag        := IntToStr(BinPLKCount);
      LblEnd     := '_sle' + Tag;
      SelectExpr := AstTable[Node].Left;
      WIdx       := 0;
      WhenN      := AstTable[Node].FirstChild;
      While WhenN >= 0 Do Begin
        Inc(WIdx);
        LblNext := '_slw' + Tag + 'w' + IntToStr(WIdx);
        If AstTable[WhenN].Text = 'OTHERWISE' Then Begin
          CodegenStmt(AstTable[WhenN].Right);
          BinJmpLabel(LblEnd);
          { OTHERWISE : pas de label suivant }
        End Else Begin
          If SelectExpr >= 0 Then Begin
            { SELECT (expr) : comparer expr avec valeur WHEN }
            CodegenExprEAX(SelectExpr);
            BinEmit8($89); BinEmit8($C1); { MOV ECX, EAX (select) }
            CodegenExprEAX(AstTable[WhenN].Left); { EAX = val WHEN }
            BinEmit8($39); BinEmit8($C1); { CMP ECX, EAX           }
            BinJccLabel(5, LblNext);      { JNE → prochain WHEN    }
          End Else Begin
            { SELECT sans expr : WHEN(cond) est booleenne }
            CodegenExprEAX(AstTable[WhenN].Left);
            BinEmit8($85); BinEmit8($C0); { TEST EAX, EAX          }
            BinJccLabel(4, LblNext);      { JZ → prochain WHEN     }
          End;
          CodegenStmt(AstTable[WhenN].Right);
          BinJmpLabel(LblEnd);
          BinDefineLabel(LblNext);
        End;
        WhenN := AstTable[WhenN].NextSibling;
      End;
      BinDefineLabel(LblEnd);
    End;

  End; { Case }
End;

{ Emet le code pour un DATA step complet.                      }
{ Pass 1 : enregistre les ARRAY_DEF, repere INFILE/INPUT/CARDS.}
{ Si INFILE CARDS + INPUT + NK_CARDS : boucle sur chaque carte }
{ en assignant les champs au compile-time, puis emet le corps. }
{ Sinon : pass 2 normal.                                       }
Procedure CodegenDataStep(DsNode: Integer);
Var
  Child    : Integer;
  InfileN  : Integer;
  InputN   : Integer;
  CardsN   : Integer;
  CardLine : Integer;
  VarN     : Integer;
  RawLine  : String;
  Pos      : Integer;
  TokStr   : String;
  V        : LongInt;
  Sign     : LongInt;
  SIdx     : Integer;
  LblStr   : String;
Begin
  { Pass 1 : enregistrer les tableaux et localiser les noeuds CARDS }
  InfileN := -1;
  InputN  := -1;
  CardsN  := -1;
  Child := AstTable[DsNode].FirstChild;
  While Child >= 0 Do Begin
    Case AstTable[Child].Kind Of
      NK_ARRAY_DEF : RegisterArray(Child);
      NK_INFILE    : InfileN := Child;
      NK_INPUT     : InputN  := Child;
      NK_CARDS     : CardsN  := Child;
    End;
    Child := AstTable[Child].NextSibling;
  End;

  { INFILE CARDS + INPUT + donnees CARDS presents : une iteration par carte }
  If (InfileN >= 0) And (AstTable[InfileN].Text = 'CARDS') And
     (InputN >= 0) And (CardsN >= 0) Then Begin
    CardLine := AstTable[CardsN].FirstChild;
    While CardLine >= 0 Do Begin
      RawLine := AstTable[CardLine].Text;
      Pos     := 1;
      VarN    := AstTable[InputN].FirstChild;
      While VarN >= 0 Do Begin
        { Sauter les espaces }
        While (Pos <= Length(RawLine)) And (RawLine[Pos] <= ' ') Do Inc(Pos);
        If Pos > Length(RawLine) Then Break;
        SIdx := FindSym(AstTable[VarN].Text, SK_NONE);
        If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
          { Variable chaine : extraire le token jusqu a l espace }
          TokStr := '';
          While (Pos <= Length(RawLine)) And (RawLine[Pos] > ' ') Do Begin
            TokStr := TokStr + RawLine[Pos]; Inc(Pos);
          End;
          LblStr := EmitRDataStr(TokStr);
          BinPushLabel(LblStr); BinEmit8($58);   { POP EAX = addr }
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else Begin
          { Variable numerique : extraire entier signe }
          Sign := 1;
          If (Pos <= Length(RawLine)) And (RawLine[Pos] = '-') Then Begin
            Sign := -1; Inc(Pos);
          End;
          V := 0;
          While (Pos <= Length(RawLine)) And (RawLine[Pos] >= '0') And
                (RawLine[Pos] <= '9') Do Begin
            V := V * 10 + Ord(RawLine[Pos]) - Ord('0');
            Inc(Pos);
          End;
          V := V * Sign;
          BinEmit8($B8); BinEmit32(V);   { MOV EAX, imm32 }
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
          { Sauter la fin du token non-espace }
          While (Pos <= Length(RawLine)) And (RawLine[Pos] > ' ') Do Inc(Pos);
        End;
        VarN := AstTable[VarN].NextSibling;
      End;
      { Emettre le corps du DATA step (ignorer INFILE/INPUT/FILE/CARDS) }
      Child := AstTable[DsNode].FirstChild;
      While Child >= 0 Do Begin
        Case AstTable[Child].Kind Of
          NK_INFILE, NK_INPUT, NK_FILE, NK_CARDS, NK_ARRAY_DEF: ; { no-op }
        Else
          CodegenStmt(Child);
        End;
        Child := AstTable[Child].NextSibling;
      End;
      CardLine := AstTable[CardLine].NextSibling;
    End;
  End Else Begin
    { Pass 2 normal : emettre le code de chaque statement }
    Child := AstTable[DsNode].FirstChild;
    While Child >= 0 Do Begin
      CodegenStmt(Child);
      Child := AstTable[Child].NextSibling;
    End;
  End;
End;

{ ============================================================ }
{ TODO 25 — Generation de code (stubs pour WritePE/COFF/ASM)   }
{ ============================================================ }

{ TODO 19/25 — CodegenProgram : alloc vars + dispatch PROC steps }
Procedure CodegenProgram;
Var
  Step : Integer;
Begin
  AllocVars;
  BinDefineLabel('_SASSTART');          { point d entree PE }
  If AstRoot >= 0 Then Begin
    Step := AstTable[AstRoot].FirstChild;
    While Step >= 0 Do Begin
      Case AstTable[Step].Kind Of
        NK_DATASTEP    : CodegenDataStep(Step);
        NK_PROC_PRINT  : CodegenProcPrint(Step);
        NK_PROC_MEANS  : CodegenProcMeans(Step);
        NK_PROC_FREQ   : CodegenProcFreq(Step);
        NK_PROC_SORT   : CodegenProcSort(Step);
        NK_PROC_FORMAT : CodegenProcFormat(Step);
      End;
      Step := AstTable[Step].NextSibling;
    End;
  End;
  BinPushImm32(0);                      { push 0 (exit code) }
  BinCallImport('_ExitProcess@4');      { call ExitProcess }
End;

{ ============================================================ }
{ TODO 25 — WritePE : genere un PE32 executable Win32         }
{ ImageBase $00400000, CUI, 4 sections : .text .rdata .data   }
{ .idata (IAT kernel32.dll). Fixups resolus avant ecriture.   }
{ ============================================================ }
Procedure WritePE(Const FileName: String);
Const
  IMAGE_BASE = LongInt($00400000);
  SEC_ALIGN  = LongInt($1000);
  FILE_ALIGN = LongInt($200);
  HDR_FILE   = LongInt($200);
Var
  F          : File;
  I, K       : Integer;
  TextVsz, RdataVsz, DataVsz, IdataVsz   : LongInt;
  TextRva,  RdataRva, DataRva,  IdataRva  : LongInt;
  TextFsz,  RdataFsz, DataFsz,  IdataFsz  : LongInt;
  TextFOff, RdataFOff, DataFOff, IdataFOff : LongInt;
  SizeImage  : LongInt;
  EntryRva   : LongInt;
  IdataIntOff, IdataIatOff, IdataDllOff, IdataHnBase : LongInt;
  IdataHnOff : Array[0..MAX_IMPORTS-1] Of LongInt;
  HnCur      : LongInt;
  BnLen, HnEntSz : Integer;
  BaseName   : String;
  ImpDirRva, ImpDirSz, IatDirRva, IatDirSz : LongInt;
  FixVal     : LongInt;
  LblSec     : Integer;
  Tmp4       : LongInt;
  Tmp2       : Word;
  Tmp1       : Byte;

  { ── Utilitaires internes ─────────────────────────────────── }

  Function AlignUp(V, A: LongInt): LongInt;
  Begin AlignUp := ((V + A - 1) Div A) * A; End;

  Function StripDeco(Const S: String): String;
  Var R: String; J: Integer;
  Begin
    R := S;
    If (Length(R) > 0) And (R[1] = '_') Then
      R := Copy(R, 2, Length(R) - 1);
    J := 1;
    While (J <= Length(R)) And (R[J] <> '@') Do Inc(J);
    If J <= Length(R) Then R := Copy(R, 1, J - 1);
    StripDeco := R;
  End;

  Procedure WB(B: Byte);
  Begin Tmp1 := B; BlockWrite(F, Tmp1, 1); End;

  Procedure WW(W: Word);
  Begin Tmp2 := W; BlockWrite(F, Tmp2, 2); End;

  Procedure WD(V: LongInt);
  Begin Tmp4 := V; BlockWrite(F, Tmp4, 4); End;

  Procedure WZero(N: LongInt);
  Var Z: Byte; Rem: LongInt;
  Begin Z := 0; Rem := N; While Rem > 0 Do Begin BlockWrite(F, Z, 1); Dec(Rem); End; End;

  Procedure WSect8(Const S: String);
  Var J: Integer;
  Begin
    For J := 1 To Length(S) Do WB(Byte(S[J]));
    For J := Length(S) + 1 To 8 Do WB(0);
  End;

  Procedure WStr0(Const S: String);
  Var J: Integer;
  Begin For J := 1 To Length(S) Do WB(Byte(S[J])); WB(0); End;

  Procedure WSectHdr(Const Name: String; Vsz, Rva, Fsz, Foff, Chars: LongInt);
  Begin
    WSect8(Name);
    WD(Vsz); WD(Rva); WD(Fsz); WD(Foff);
    WD(0); WD(0); WW(0); WW(0);
    WD(Chars);
  End;

  Procedure Patch32(Off: LongInt; V: LongInt);
  Begin
    BinCode[Off]   := Byte(V And $FF);
    BinCode[Off+1] := Byte((V Shr  8) And $FF);
    BinCode[Off+2] := Byte((V Shr 16) And $FF);
    BinCode[Off+3] := Byte((V Shr 24) And $FF);
  End;

  Function LabelVA(Const Name: String): LongInt;
  Var J: Integer;
  Begin
    For J := 0 To LabelCount - 1 Do
      If LabelTable[J].Name = Name Then Begin
        Case LabelTable[J].Section Of
          BIN_SEC_TEXT  : LabelVA := IMAGE_BASE + TextRva  + LabelTable[J].Offset;
          BIN_SEC_DATA  : LabelVA := IMAGE_BASE + DataRva  + LabelTable[J].Offset;
          BIN_SEC_RDATA : LabelVA := IMAGE_BASE + RdataRva + LabelTable[J].Offset;
          BIN_SEC_IDATA : LabelVA := IMAGE_BASE + IdataRva + LabelTable[J].Offset;
        Else
          LabelVA := 0;
        End;
        Exit;
      End;
    CompileError('label non resolu: ' + Name);
    LabelVA := 0;
  End;

  Function ImportVA(Const Name: String): LongInt;
  Var J: Integer;
  Begin
    For J := 0 To ImportCount - 1 Do
      If ImportTable[J].LabelNm = Name Then Begin
        ImportVA := IMAGE_BASE + IdataRva + ImportTable[J].IATOff;
        Exit;
      End;
    CompileError('import non resolu: ' + Name);
    ImportVA := 0;
  End;

Begin
  { ── 1. Layout .idata ────────────────────────────────────── }
  { [0]   IMPORT_DESCRIPTOR kernel32 (20 o)                   }
  { [20]  null IMPORT_DESCRIPTOR (20 o)                       }
  { [40]  INT (ImportCount+1)*4                               }
  { [INT+] IAT (ImportCount+1)*4                              }
  { [IAT+] DLL name "KERNEL32.DLL\0" + 1 pad = 14 o         }
  { [DLL+] Hint/Name entries                                  }
  IdataIntOff := 40;
  IdataIatOff := IdataIntOff + LongInt(ImportCount + 1) * 4;
  IdataDllOff := IdataIatOff + LongInt(ImportCount + 1) * 4;
  IdataHnBase := IdataDllOff + 14;
  HnCur := 0;
  For I := 0 To ImportCount - 1 Do Begin
    ImportTable[I].IATOff := IdataIatOff + LongInt(I) * 4;
    BaseName := StripDeco(ImportTable[I].FuncName);
    BnLen    := Length(BaseName);
    HnEntSz  := BnLen + 3;
    If (HnEntSz And 1) <> 0 Then Inc(HnEntSz);
    IdataHnOff[I] := HnCur;
    HnCur := HnCur + HnEntSz;
  End;
  IdataVsz := IdataHnBase + HnCur;
  If IdataVsz = 0 Then IdataVsz := 1;

  { ── 2. Tailles et VAs des sections ─────────────────────── }
  TextVsz  := BinCodeSize;  If TextVsz  = 0 Then TextVsz  := 1;
  RdataVsz := BinRDataSize; If RdataVsz = 0 Then RdataVsz := 1;
  DataVsz  := BinDataSize;  If DataVsz  = 0 Then DataVsz  := 1;

  TextRva  := $1000;
  RdataRva := TextRva  + AlignUp(TextVsz,  SEC_ALIGN);
  DataRva  := RdataRva + AlignUp(RdataVsz, SEC_ALIGN);
  IdataRva := DataRva  + AlignUp(DataVsz,  SEC_ALIGN);

  TextFsz  := AlignUp(TextVsz,  FILE_ALIGN);
  RdataFsz := AlignUp(RdataVsz, FILE_ALIGN);
  DataFsz  := AlignUp(DataVsz,  FILE_ALIGN);
  IdataFsz := AlignUp(IdataVsz, FILE_ALIGN);

  TextFOff  := HDR_FILE;
  RdataFOff := TextFOff  + TextFsz;
  DataFOff  := RdataFOff + RdataFsz;
  IdataFOff := DataFOff  + DataFsz;

  SizeImage := IdataRva + AlignUp(IdataVsz, SEC_ALIGN);

  { ── 3. Entry point (_SASSTART) ──────────────────────────── }
  EntryRva := TextRva;
  For I := 0 To LabelCount - 1 Do
    If LabelTable[I].Name = '_SASSTART' Then Begin
      EntryRva := TextRva + LabelTable[I].Offset; Break;
    End;

  { ── 4. DataDirectory entries ────────────────────────────── }
  ImpDirRva := IdataRva;
  ImpDirSz  := 40;
  IatDirRva := IdataRva + IdataIatOff;
  IatDirSz  := LongInt(ImportCount) * 4;

  { ── 5. Application des fixups dans BinCode ─────────────── }
  For I := 0 To FixupCount - 1 Do Begin
    Case FixupTable[I].Kind Of
      BIN_FIX_ABS32 : Patch32(FixupTable[I].Offset,
                         LabelVA(FixupTable[I].Name));
      BIN_FIX_REL32 : Patch32(FixupTable[I].Offset,
                         LabelVA(FixupTable[I].Name) -
                         (IMAGE_BASE + TextRva + FixupTable[I].Offset + 4));
      BIN_FIX_IMP32 : Patch32(FixupTable[I].Offset,
                         ImportVA(FixupTable[I].Name));
    End;
  End;

  { ── 6. Ouverture du fichier ─────────────────────────────── }
  Assign(F, FileName);
  {$I-} Rewrite(F, 1); {$I+}
  If IOResult <> 0 Then Begin
    CompileError('impossible de creer: ' + FileName); Exit;
  End;

  { ── 7. En-tete DOS (64 o) ───────────────────────────────── }
  WB($4D); WB($5A);              { 'MZ' }
  WZero(58);                     { octets 2..59 = zeros }
  WD(64);                        { e_lfanew = 64 }

  { ── 8. Signature PE (4 o) ───────────────────────────────── }
  WB($50); WB($45); WB(0); WB(0);

  { ── 9. IMAGE_FILE_HEADER (20 o) ─────────────────────────── }
  WW($014C);                     { Machine = i386 }
  WW(4);                         { NumberOfSections }
  WD(0);                         { TimeDateStamp }
  WD(0);                         { PointerToSymbolTable }
  WD(0);                         { NumberOfSymbols }
  WW($00E0);                     { SizeOfOptionalHeader = 224 }
  WW($0103);                     { Characteristics }

  { ── 10. IMAGE_OPTIONAL_HEADER32 (224 o) ─────────────────── }
  WW($010B);                     { Magic PE32 }
  WB(0); WB(0);                  { LinkerVersion }
  WD(TextFsz);                   { SizeOfCode }
  WD(RdataFsz + DataFsz + IdataFsz);  { SizeOfInitializedData }
  WD(0);                         { SizeOfUninitializedData }
  WD(EntryRva);                  { AddressOfEntryPoint }
  WD(TextRva);                   { BaseOfCode }
  WD(DataRva);                   { BaseOfData }
  WD(IMAGE_BASE);                { ImageBase }
  WD(SEC_ALIGN);                 { SectionAlignment }
  WD(FILE_ALIGN);                { FileAlignment }
  WW(4); WW(0);                  { MajorOS / MinorOS }
  WW(0); WW(0);                  { MajorImage / MinorImage }
  WW(4); WW(0);                  { MajorSubsys / MinorSubsys }
  WD(0);                         { Win32VersionValue }
  WD(SizeImage);                 { SizeOfImage }
  WD(HDR_FILE);                  { SizeOfHeaders }
  WD(0);                         { CheckSum }
  WW(3);                         { Subsystem = CUI }
  WW(0);                         { DllCharacteristics }
  WD($00100000);                 { SizeOfStackReserve }
  WD($00001000);                 { SizeOfStackCommit }
  WD($00100000);                 { SizeOfHeapReserve }
  WD($00001000);                 { SizeOfHeapCommit }
  WD(0);                         { LoaderFlags }
  WD(16);                        { NumberOfRvaAndSizes }
  WD(0);         WD(0);          { [0] Export }
  WD(ImpDirRva); WD(ImpDirSz);  { [1] Import }
  WD(0);         WD(0);          { [2] Resource }
  WD(0);         WD(0);          { [3] Exception }
  WD(0);         WD(0);          { [4] Security }
  WD(0);         WD(0);          { [5] BaseReloc }
  WD(0);         WD(0);          { [6] Debug }
  WD(0);         WD(0);          { [7] Architecture }
  WD(0);         WD(0);          { [8] GlobalPtr }
  WD(0);         WD(0);          { [9] TLS }
  WD(0);         WD(0);          { [10] LoadConfig }
  WD(0);         WD(0);          { [11] BoundImport }
  WD(IatDirRva); WD(IatDirSz);  { [12] IAT }
  WD(0);         WD(0);          { [13] DelayImport }
  WD(0);         WD(0);          { [14] COM }
  WD(0);         WD(0);          { [15] Reserved }

  { ── 11. Section headers 4 x 40 = 160 o ─────────────────── }
  WSectHdr('.text',  TextVsz,  TextRva,  TextFsz,  TextFOff,  $60000020);
  WSectHdr('.rdata', RdataVsz, RdataRva, RdataFsz, RdataFOff, $40000040);
  WSectHdr('.data',  DataVsz,  DataRva,  DataFsz,  DataFOff,  $C0000040);
  WSectHdr('.idata', IdataVsz, IdataRva, IdataFsz, IdataFOff, $C0000040);

  { ── 12. Pad en-tete a HDR_FILE ─────────────────────────── }
  { 64+4+20+224+160 = 472 ; pad 40 o → 512 }
  WZero(40);

  { ── 13. Section .text ───────────────────────────────────── }
  If BinCodeSize > 0 Then BlockWrite(F, BinCode, BinCodeSize);
  WZero(TextFsz - BinCodeSize);

  { ── 14. Section .rdata ──────────────────────────────────── }
  If BinRDataSize > 0 Then BlockWrite(F, BinRData, BinRDataSize);
  WZero(RdataFsz - BinRDataSize);

  { ── 15. Section .data ───────────────────────────────────── }
  If BinDataSize > 0 Then BlockWrite(F, BinData, BinDataSize);
  WZero(DataFsz - BinDataSize);

  { ── 16. Section .idata ──────────────────────────────────── }
  { IMPORT_DESCRIPTOR pour KERNEL32.DLL }
  WD(IdataRva + IdataIntOff);    { OriginalFirstThunk }
  WD(0);                         { TimeDateStamp }
  WD(0);                         { ForwarderChain }
  WD(IdataRva + IdataDllOff);    { Name }
  WD(IdataRva + IdataIatOff);    { FirstThunk (IAT) }
  { Terminateur null }
  WZero(20);
  { INT : ImportCount entrees + null }
  For I := 0 To ImportCount - 1 Do
    WD(IdataRva + IdataHnBase + IdataHnOff[I]);
  WD(0);
  { IAT : meme valeurs (loader remplace par adresses reelles) }
  For I := 0 To ImportCount - 1 Do
    WD(IdataRva + IdataHnBase + IdataHnOff[I]);
  WD(0);
  { Nom de la DLL (14 o) }
  WStr0('KERNEL32.DLL');
  WB(0);
  { Hint/Name entries }
  For I := 0 To ImportCount - 1 Do Begin
    BaseName := StripDeco(ImportTable[I].FuncName);
    BnLen    := Length(BaseName);
    WW(0);           { Hint = 0 }
    WStr0(BaseName);
    HnEntSz := BnLen + 3;
    If (HnEntSz And 1) <> 0 Then WB(0);
  End;
  WZero(IdataFsz - IdataVsz);

  Close(F);
End;

{ ============================================================ }
{ TODO 25 — WriteCOFF : sortie COFF (stub V1)                  }
{ ============================================================ }
Procedure WriteCOFF(Const FileName: String);
Var F: Text;
Begin
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Begin
    CompileError('impossible de creer: ' + FileName); Exit;
  End;
  WriteLn(F, '; SASCW32 COFF stub - TODO 25 V2');
  Close(F);
End;

{ ============================================================ }
{ TODO 25 — WriteASM : sortie MASM (stub V1)                   }
{ ============================================================ }
Procedure WriteASM(Const FileName: String);
Var F: Text;
Begin
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Begin
    CompileError('impossible de creer: ' + FileName); Exit;
  End;
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT, STDCALL');
  WriteLn(F, 'OPTION CASEMAP:NONE');
  WriteLn(F, '; SASCW32 ASM stub - TODO 25 V2');
  Close(F);
End;

Function BinCurOffset: LongInt;
Begin BinCurOffset := BinCodeSize; End;

Procedure BinEmit8(B: Byte);
Begin
  If BinCodeSize < MAX_CODE Then Begin
    BinCode[BinCodeSize] := B; Inc(BinCodeSize);
  End;
End;

Procedure BinEmit32(V: LongInt);
Begin
  BinEmit8(Byte(V And $FF));
  BinEmit8(Byte((V Shr 8)  And $FF));
  BinEmit8(Byte((V Shr 16) And $FF));
  BinEmit8(Byte((V Shr 24) And $FF));
End;

Procedure BinDefineLabel(Const Name: String);
Begin
  If LabelCount >= MAX_LABELS Then Begin
    CompileError('trop de labels'); Exit;
  End;
  LabelTable[LabelCount].Name    := Name;
  LabelTable[LabelCount].Section := BinCurSec;
  LabelTable[LabelCount].Offset  := BinCurOffset;
  Inc(LabelCount);
End;

Function BinAddImport(Const DllName, FuncName: String): Integer;
Var I: Integer;
Begin
  For I := 0 To ImportCount-1 Do
    If ImportTable[I].FuncName = FuncName Then
      Begin BinAddImport := I; Exit; End;
  If ImportCount >= MAX_IMPORTS Then Begin
    CompileError('trop d imports'); BinAddImport := -1; Exit;
  End;
  ImportTable[ImportCount].DllName  := DllName;
  ImportTable[ImportCount].FuncName := FuncName;
  ImportTable[ImportCount].IATOff   := 0;
  ImportTable[ImportCount].LabelNm  := '__imp__' + FuncName;
  BinAddImport := ImportCount;
  Inc(ImportCount);
End;

Procedure BinRegisterKernel32Imports;
Begin
  BinAddImport('kernel32.dll', '_GetStdHandle@4');
  BinAddImport('kernel32.dll', '_WriteFile@20');
  BinAddImport('kernel32.dll', '_ReadFile@20');
  BinAddImport('kernel32.dll', '_ExitProcess@4');
  BinAddImport('kernel32.dll', '_HeapAlloc@12');
  BinAddImport('kernel32.dll', '_HeapFree@12');
  BinAddImport('kernel32.dll', '_GetProcessHeap@0');
End;

Procedure BinMovRegImm32(R: Integer; V: LongInt);
Begin BinEmit8($B8 + R); BinEmit32(V); End;

Procedure BinMovRegLabel(R: Integer; Const Name: String);
Begin
  BinEmit8($B8 + R);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

Procedure BinPushReg(R: Integer);  Begin BinEmit8($50 + R); End;
Procedure BinPopReg(R: Integer);   Begin BinEmit8($58 + R); End;
Procedure BinRet;                  Begin BinEmit8($C3); End;

Procedure BinPushImm32(V: LongInt);
Begin BinEmit8($68); BinEmit32(V); End;

{ PUSH imm32 avec fixup ABS32 vers un label (pour passer une adresse). }
Procedure BinPushLabel(Const Name: String);
Begin
  BinEmit8($68);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

Procedure BinAddEspImm8(N: Integer);
Begin BinEmit8($83); BinEmit8($C4); BinEmit8(Byte(N)); End;

Procedure BinCallLabel(Const Name: String);
Begin
  BinEmit8($E8);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := BIN_FIX_REL32;
    Inc(FixupCount);
  End;
  BinEmit32(-4);
End;

Procedure BinCallImport(Const FuncName: String);
Begin
  BinEmit8($FF); BinEmit8($15);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := '__imp__' + FuncName;
    FixupTable[FixupCount].Kind    := BIN_FIX_IMP32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

Procedure BinJmpLabel(Const Name: String);
Begin
  BinEmit8($E9);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := BIN_FIX_REL32;
    Inc(FixupCount);
  End;
  BinEmit32(-4);
End;

Procedure BinJccLabel(CC: Integer; Const Name: String);
Begin
  BinEmit8($0F); BinEmit8($80 + CC);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := Name;
    FixupTable[FixupCount].Kind    := BIN_FIX_REL32;
    Inc(FixupCount);
  End;
  BinEmit32(-4);
End;

{ ============================================================ }
{ TODO 19 — Helpers pour sections .data et .rdata              }
{ ============================================================ }

Procedure BinEmitDataByte(B: Byte);
Begin
  If BinDataSize < MAX_DATA Then Begin
    BinData[BinDataSize] := B; Inc(BinDataSize);
  End;
End;

Procedure BinEmitRDataByte(B: Byte);
Begin
  If BinRDataSize < MAX_RDATA Then Begin
    BinRData[BinRDataSize] := B; Inc(BinRDataSize);
  End;
End;

Procedure BinDefineDataLabel(Const Name: String);
Begin
  If LabelCount >= MAX_LABELS Then Exit;
  LabelTable[LabelCount].Name    := Name;
  LabelTable[LabelCount].Section := BIN_SEC_DATA;
  LabelTable[LabelCount].Offset  := BinDataSize;
  Inc(LabelCount);
End;

Procedure BinDefineRDataLabel(Const Name: String);
Begin
  If LabelCount >= MAX_LABELS Then Exit;
  LabelTable[LabelCount].Name    := Name;
  LabelTable[LabelCount].Section := BIN_SEC_RDATA;
  LabelTable[LabelCount].Offset  := BinRDataSize;
  Inc(LabelCount);
End;

{ PUSH dword ptr [addr32] : charge et empile la valeur memoire. }
Procedure BinPushMem32(Const LblName: String);
Begin
  BinEmit8($FF); BinEmit8($35);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := LblName;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

{ MOV EAX, dword ptr [addr32] : charge la valeur dans EAX.    }
Procedure BinMovEaxMem(Const LblName: String);
Begin
  BinEmit8($8B); BinEmit8($05);
  If FixupCount < MAX_FIXUPS Then Begin
    FixupTable[FixupCount].Offset  := BinCurOffset;
    FixupTable[FixupCount].Section := BIN_SEC_TEXT;
    FixupTable[FixupCount].Name    := LblName;
    FixupTable[FixupCount].Kind    := BIN_FIX_ABS32;
    Inc(FixupCount);
  End;
  BinEmit32(0);
End;

{ CMP EAX, imm32 : compare EAX a une constante immediate.     }
Procedure BinCmpEaxImm32(V: LongInt);
Begin
  BinEmit8($3D); BinEmit32(V);
End;

{ ============================================================ }
{ Runtime I/O embarque — TODO 15                               }
{ _SASRT_write_str(ptr)  : ecrire chaine zero-terminee stdout  }
{ _SASRT_write_num(n)    : convertir entier->chaine, ecrire    }
{ _SASRT_newline         : ecrire CR+LF sur stdout             }
{ _SASRT_crlf            : donnee inline 0D 0A                 }
{ Convention : stdcall (callee nettoie les params).            }
{ ============================================================ }
Procedure EmitRuntimeIO;
Begin
  { ── _SASRT_write_str(ptr:dword) ─────────────────────────── }
  { Ecrit la chaine zero-terminee pointee par [esp+4] sur stdout }
  { 53 octets : stdcall, ret 4                                  }
  BinDefineLabel('_SASRT_write_str');
  BinEmit8($55);             { push ebp                        }
  BinEmit8($89); BinEmit8($E5);  { mov ebp, esp               }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04); { sub esp, 4   }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08); { mov esi,[ebp+8] }
  BinEmit8($31); BinEmit8($C9); { xor ecx, ecx                }
  { lenloop: cmp byte [esi+ecx], 0 }
  BinEmit8($80); BinEmit8($3C); BinEmit8($0E); BinEmit8($00);
  BinEmit8($74); BinEmit8($03); { je lendone (+3)              }
  BinEmit8($41);             { inc ecx                         }
  BinEmit8($EB); BinEmit8($F7); { jmp lenloop (-9)             }
  { lendone: }
  BinEmit8($85); BinEmit8($C9); { test ecx, ecx                }
  BinEmit8($74); BinEmit8($17); { jz skip (+23)                }
  BinEmit8($6A); BinEmit8($F5); { push -11 (STD_OUTPUT_HANDLE) }
  BinCallImport('_GetStdHandle@4');
  BinEmit8($8D); BinEmit8($55); BinEmit8($FC); { lea edx,[ebp-4] }
  BinEmit8($6A); BinEmit8($00); { push 0 (lpOverlapped)        }
  BinEmit8($52);             { push edx (&dwBytesWritten)       }
  BinEmit8($51);             { push ecx (nBytesToWrite)         }
  BinEmit8($56);             { push esi (lpBuffer)              }
  BinEmit8($50);             { push eax (hFile)                 }
  BinCallImport('_WriteFile@20');
  { skip: }
  BinEmit8($89); BinEmit8($EC); { mov esp, ebp                 }
  BinEmit8($5D);             { pop ebp                         }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00); { ret 4         }

  { ── _SASRT_write_num(n:dword) ───────────────────────────── }
  { Convertit l entier signe [esp+4] en decimal et l ecrit.    }
  { 81 octets : stdcall, ret 4 ; appelle _SASRT_write_str.     }
  BinDefineLabel('_SASRT_write_num');
  BinEmit8($55);             { push ebp                        }
  BinEmit8($89); BinEmit8($E5);  { mov ebp, esp               }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10); { sub esp, 16  }
  { mov byte [ebp-1], 0 }
  BinEmit8($C6); BinEmit8($45); BinEmit8($FF); BinEmit8($00);
  BinEmit8($8D); BinEmit8($7D); BinEmit8($FE); { lea edi,[ebp-2] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8] }
  BinEmit8($31); BinEmit8($DB); { xor ebx, ebx                }
  BinEmit8($85); BinEmit8($C0); { test eax, eax               }
  BinEmit8($79); BinEmit8($07); { jns positive (+7)           }
  BinEmit8($F7); BinEmit8($D8); { neg eax                     }
  BinEmit8($BB); BinEmit32(1);  { mov ebx, 1                  }
  { positive: }
  BinEmit8($85); BinEmit8($C0); { test eax, eax               }
  BinEmit8($75); BinEmit8($06); { jnz digits (+6)             }
  BinEmit8($C6); BinEmit8($07); BinEmit8($30); { mov byte [edi],'0' }
  BinEmit8($4F);             { dec edi                         }
  BinEmit8($EB); BinEmit8($15); { jmp sign_check (+21)         }
  { digits: mov ecx, 10 }
  BinEmit8($B9); BinEmit32(10);
  { digloop: }
  BinEmit8($85); BinEmit8($C0); { test eax, eax               }
  BinEmit8($74); BinEmit8($0C); { jz sign_check (+12)         }
  BinEmit8($31); BinEmit8($D2); { xor edx, edx                }
  BinEmit8($F7); BinEmit8($F1); { div ecx                     }
  BinEmit8($80); BinEmit8($C2); BinEmit8($30); { add dl,'0'   }
  BinEmit8($88); BinEmit8($17); { mov [edi], dl               }
  BinEmit8($4F);             { dec edi                         }
  BinEmit8($EB); BinEmit8($F0); { jmp digloop (-16)            }
  { sign_check: }
  BinEmit8($85); BinEmit8($DB); { test ebx, ebx               }
  BinEmit8($74); BinEmit8($04); { jz write_it (+4)            }
  BinEmit8($C6); BinEmit8($07); BinEmit8($2D); { mov byte [edi],'-' }
  BinEmit8($4F);             { dec edi                         }
  { write_it: }
  BinEmit8($47);             { inc edi                         }
  BinEmit8($57);             { push edi                        }
  BinCallLabel('_SASRT_write_str');
  BinEmit8($89); BinEmit8($EC); { mov esp, ebp                 }
  BinEmit8($5D);             { pop ebp                         }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00); { ret 4         }

  { ── _SASRT_newline ──────────────────────────────────────── }
  { Ecrit CR+LF sur stdout. Aucun parametre. 38 octets.        }
  BinDefineLabel('_SASRT_newline');
  BinEmit8($55);             { push ebp                        }
  BinEmit8($89); BinEmit8($E5);  { mov ebp, esp               }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04); { sub esp, 4   }
  BinEmit8($6A); BinEmit8($F5); { push -11 (STD_OUTPUT_HANDLE) }
  BinCallImport('_GetStdHandle@4');
  BinEmit8($8D); BinEmit8($4D); BinEmit8($FC); { lea ecx,[ebp-4] }
  BinEmit8($6A); BinEmit8($00); { push 0 (lpOverlapped)        }
  BinEmit8($51);             { push ecx (&dwBytesWritten)       }
  BinEmit8($6A); BinEmit8($02); { push 2 (nBytesToWrite)       }
  BinPushLabel('_SASRT_crlf');  { push addr de CRLF (ABS32)    }
  BinEmit8($50);             { push eax (hFile)                 }
  BinCallImport('_WriteFile@20');
  BinEmit8($89); BinEmit8($EC); { mov esp, ebp                 }
  BinEmit8($5D);             { pop ebp                         }
  BinEmit8($C3);             { ret                             }

  { ── _SASRT_crlf : donnee inline CR+LF ───────────────────── }
  BinDefineLabel('_SASRT_crlf');
  BinEmit8($0D); BinEmit8($0A);
End;

{ ============================================================ }
{ TODO 19 — Allocation des variables et codegen PROC PRINT     }
{ ============================================================ }

{ Emet S en zero-termine dans .rdata, retourne le label.       }
Function EmitRDataStr(Const S: String): String;
Var
  LblName : String;
  I       : Integer;
Begin
  LblName := '_sas_rs_' + IntToStr(BinRDataSize);
  BinDefineRDataLabel(LblName);
  For I := 1 To Length(S) Do
    BinEmitRDataByte(Byte(S[I]));
  BinEmitRDataByte(0);
  EmitRDataStr := LblName;
End;

{ Alloue un espace .data pour chaque variable SAS et          }
{ affecte son AsmName et son Offset dans SymTable.            }
Procedure AllocVars;
Const
  CHARVAR_SIZE = 256;
Var
  I : Integer;
  J : Integer;
  LN : String;
Begin
  For I := 0 To SymCount - 1 Do Begin
    If (SymTable[I].Kind = SK_VAR_NUM) Or
       (SymTable[I].Kind = SK_VAR_CHAR) Then Begin
      LN := '_sas_v_' + SymTable[I].Name;
      SymTable[I].AsmName := LN;
      BinDefineDataLabel(LN);
      SymTable[I].Offset := BinDataSize;
      If SymTable[I].IsChar Then Begin
        For J := 1 To CHARVAR_SIZE Do BinEmitDataByte(0);
      End Else Begin
        BinEmitDataByte(0); BinEmitDataByte(0);
        BinEmitDataByte(0); BinEmitDataByte(0);
      End;
    End;
  End;
End;

{ Genere le code 80386 pour PROC PRINT.                       }
{ ProcNode : NK_PROC_PRINT, Text=DsName, NumVal=NoPrint.      }
{ Enfants : NK_VAR_LIST (variables VAR), NK_LITERAL (titres). }
Procedure CodegenProcPrint(ProcNode: Integer);
Var
  Child     : Integer;
  VListNode : Integer;
  VarNode   : Integer;
  DsName    : String;
  VarName   : String;
  LblStr    : String;
  SIdx      : Integer;
  DsIdx     : Integer;
  I         : Integer;
Begin
  If AstTable[ProcNode].NumVal <> 0 Then Exit; { NOPRINT }
  DsName := UpperStr(AstTable[ProcNode].Text);

  { Identifier le noeud VAR_LIST parmi les enfants }
  VListNode := -1;
  Child := AstTable[ProcNode].FirstChild;
  While Child >= 0 Do Begin
    If AstTable[Child].Kind = NK_VAR_LIST Then Begin
      VListNode := Child; Break;
    End;
    Child := AstTable[Child].NextSibling;
  End;

  If VListNode >= 0 Then Begin
    { Imprimer les variables listees dans VAR }
    VarNode := AstTable[VListNode].FirstChild;
    While VarNode >= 0 Do Begin
      VarName := UpperStr(AstTable[VarNode].Text);
      SIdx := FindSym(VarName, SK_NONE);
      If (SIdx >= 0) And
         ((SymTable[SIdx].Kind = SK_VAR_NUM) Or
          (SymTable[SIdx].Kind = SK_VAR_CHAR)) Then Begin
        LblStr := EmitRDataStr(VarName + '=');
        BinPushLabel(LblStr);
        BinCallLabel('_SASRT_write_str');
        If SymTable[SIdx].IsChar Then Begin
          BinPushLabel(SymTable[SIdx].AsmName);
          BinCallLabel('_SASRT_write_str');
        End Else Begin
          CodegenFormatOutput(SIdx, SymTable[SIdx].FmtIdx);
        End;
        BinCallLabel('_SASRT_newline');
      End;
      VarNode := AstTable[VarNode].NextSibling;
    End;
  End Else Begin
    { Pas de VAR : imprimer toutes les variables du dataset }
    DsIdx := -1;
    For I := 0 To DsCount - 1 Do Begin
      If DsTable[I].Name = DsName Then Begin
        DsIdx := I; Break;
      End;
    End;
    If DsIdx >= 0 Then Begin
      For I := 0 To DsTable[DsIdx].VarCnt - 1 Do Begin
        VarName := DsTable[DsIdx].Vars[I].Name;
        SIdx := FindSym(VarName, SK_NONE);
        If (SIdx >= 0) And
           ((SymTable[SIdx].Kind = SK_VAR_NUM) Or
            (SymTable[SIdx].Kind = SK_VAR_CHAR)) Then Begin
          LblStr := EmitRDataStr(VarName + '=');
          BinPushLabel(LblStr);
          BinCallLabel('_SASRT_write_str');
          If SymTable[SIdx].IsChar Then Begin
            BinPushLabel(SymTable[SIdx].AsmName);
            BinCallLabel('_SASRT_write_str');
          End Else Begin
            CodegenFormatOutput(SIdx, SymTable[SIdx].FmtIdx);
          End;
          BinCallLabel('_SASRT_newline');
        End;
      End;
    End;
  End;
End;

{ ============================================================ }
{ TODO 20 — Codegen PROC MEANS                                 }
{ ProcNode : NK_PROC_MEANS, Text=DsName.                       }
{ V1 : N=1, MEAN=MIN=MAX=SUM = valeur courante de la variable. }
{ Seules les variables numeriques sont traitees.               }
{ ============================================================ }
Procedure CodegenProcMeans(ProcNode: Integer);
Var
  Child      : Integer;
  VListNode  : Integer;
  VarNode    : Integer;
  DsName     : String;
  VarName    : String;
  LblStr     : String;
  SIdx       : Integer;
  DsIdx      : Integer;
  I          : Integer;
  VarBuf     : Array[0..MAX_DS_COLS-1] Of String;
  VarN       : Integer;

  Procedure EmitStats(SIdx: Integer; Const VarName: String);
  { Emet : varname:\n N=1\n MEAN=v\n MIN=v\n MAX=v\n SUM=v\n }
  Begin
    LblStr := EmitRDataStr(VarName + ':');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinCallLabel('_SASRT_newline');
    LblStr := EmitRDataStr('N=');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinPushImm32(1);      BinCallLabel('_SASRT_write_num');
    BinCallLabel('_SASRT_newline');
    LblStr := EmitRDataStr('MEAN=');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinPushMem32(SymTable[SIdx].AsmName); BinCallLabel('_SASRT_write_num');
    BinCallLabel('_SASRT_newline');
    LblStr := EmitRDataStr('MIN=');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinPushMem32(SymTable[SIdx].AsmName); BinCallLabel('_SASRT_write_num');
    BinCallLabel('_SASRT_newline');
    LblStr := EmitRDataStr('MAX=');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinPushMem32(SymTable[SIdx].AsmName); BinCallLabel('_SASRT_write_num');
    BinCallLabel('_SASRT_newline');
    LblStr := EmitRDataStr('SUM=');
    BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
    BinPushMem32(SymTable[SIdx].AsmName); BinCallLabel('_SASRT_write_num');
    BinCallLabel('_SASRT_newline');
  End;

Begin
  DsName    := UpperStr(AstTable[ProcNode].Text);
  VListNode := -1;
  VarN      := 0;

  Child := AstTable[ProcNode].FirstChild;
  While Child >= 0 Do Begin
    If AstTable[Child].Kind = NK_VAR_LIST Then Begin
      VListNode := Child; Break;
    End;
    Child := AstTable[Child].NextSibling;
  End;

  If VListNode >= 0 Then Begin
    { Collecter les noms du noeud VAR }
    VarNode := AstTable[VListNode].FirstChild;
    While (VarNode >= 0) And (VarN < MAX_DS_COLS) Do Begin
      VarBuf[VarN] := UpperStr(AstTable[VarNode].Text);
      Inc(VarN);
      VarNode := AstTable[VarNode].NextSibling;
    End;
  End Else Begin
    { Pas de VAR : prendre les variables numeriques du dataset }
    DsIdx := -1;
    For I := 0 To DsCount - 1 Do
      If DsTable[I].Name = DsName Then Begin DsIdx := I; Break; End;
    If DsIdx >= 0 Then
      For I := 0 To DsTable[DsIdx].VarCnt - 1 Do
        If (Not DsTable[DsIdx].Vars[I].IsChar) And (VarN < MAX_DS_COLS) Then Begin
          VarBuf[VarN] := DsTable[DsIdx].Vars[I].Name;
          Inc(VarN);
        End;
  End;

  { Emettre les stats pour chaque variable collectee }
  For I := 0 To VarN - 1 Do Begin
    VarName := VarBuf[I];
    SIdx := FindSym(VarName, SK_NONE);
    If (SIdx >= 0) And (SymTable[SIdx].Kind = SK_VAR_NUM) Then
      EmitStats(SIdx, VarName);
  End;
End;

{ ============================================================ }
{ TODO 22 — Sortie formatee via FmtTable                       }
{ Genere le code inline CMP/JE/JMP pour appliquer un format   }
{ utilisateur lors de l affichage d une variable numerique.    }
{ Si FmtIdx < 0 ou format vide : sortie numerique simple.      }
{ ============================================================ }
Procedure CodegenFormatOutput(SIdx, FmtIdx: Integer);
Var
  NE       : Integer;
  I        : Integer;
  OtherIdx : Integer;
  BaseTag  : String;
  EntLbl   : String;
  SkipLbl  : String;
  FallLbl  : String;
  DoneLbl  : String;
  LblStr   : String;
  FE       : TFmtEntry;
Begin
  If (FmtIdx < 0) Or (FmtIdx >= FmtCount) Then Begin
    BinPushMem32(SymTable[SIdx].AsmName);
    BinCallLabel('_SASRT_write_num');
    Exit;
  End;

  NE := FmtTable[FmtIdx].Count;
  If NE = 0 Then Begin
    BinPushMem32(SymTable[SIdx].AsmName);
    BinCallLabel('_SASRT_write_num');
    Exit;
  End;

  BaseTag  := '_fg_' + IntToStr(BinCodeSize);
  FallLbl  := BaseTag + '_fb';
  DoneLbl  := BaseTag + '_dn';
  OtherIdx := -1;

  For I := 0 To NE - 1 Do
    If FmtTable[FmtIdx].Entries[I].IsOther Then OtherIdx := I;

  { Charger la valeur dans EAX pour les comparaisons }
  BinMovEaxMem(SymTable[SIdx].AsmName);

  { Pour chaque entree non-OTHER : emettre la comparaison }
  For I := 0 To NE - 1 Do Begin
    FE      := FmtTable[FmtIdx].Entries[I];
    EntLbl  := BaseTag + '_e' + IntToStr(I);
    SkipLbl := BaseTag + '_sk' + IntToStr(I);
    If FE.IsOther Then Continue;
    If FE.IsSingle Then Begin
      BinCmpEaxImm32(FE.Lo);
      BinJccLabel(4, EntLbl);     { JE : valeur unique }
    End Else Begin
      If Not FE.LoIsLow Then Begin
        BinCmpEaxImm32(FE.Lo);
        BinJccLabel(12, SkipLbl); { JL : en dessous de Lo }
      End;
      If Not FE.HiIsHigh Then Begin
        BinCmpEaxImm32(FE.Hi);
        BinJccLabel(15, SkipLbl); { JG : au dessus de Hi }
      End;
      BinJmpLabel(EntLbl);        { dans [Lo..Hi] }
      BinDefineLabel(SkipLbl);
    End;
  End;

  { Aucune entree n a correspondu : aller vers OTHER ou fallback }
  If OtherIdx >= 0 Then
    BinJmpLabel(BaseTag + '_e' + IntToStr(OtherIdx))
  Else
    BinJmpLabel(FallLbl);

  { Blocs de sortie : un label + write_str + jmp done par entree }
  For I := 0 To NE - 1 Do Begin
    FE     := FmtTable[FmtIdx].Entries[I];
    EntLbl := BaseTag + '_e' + IntToStr(I);
    BinDefineLabel(EntLbl);
    LblStr := EmitRDataStr(FE.Lbl);
    BinPushLabel(LblStr);
    BinCallLabel('_SASRT_write_str');
    BinJmpLabel(DoneLbl);
  End;

  { Fallback : sortie numerique brute }
  BinDefineLabel(FallLbl);
  BinPushMem32(SymTable[SIdx].AsmName);
  BinCallLabel('_SASRT_write_num');

  BinDefineLabel(DoneLbl);
End;

{ PROC FORMAT : formats deja enregistres dans FmtTable lors    }
{ du parsing (ParseSubCmd KW_VALUE). Aucun code a emettre.     }
Procedure CodegenProcFormat(ProcNode: Integer);
Begin
  { no-op : FmtTable peuplee a l analyse syntaxique }
End;

{ ============================================================ }
{ TODO 21 — Codegen PROC FREQ                                  }
{ ProcNode : NK_PROC_FREQ, Text=DsName, NumVal=NoPrint.        }
{ V1 : 1 observation → chaque valeur apparait 1 fois (100%).   }
{ Cherche l enfant NK_VAR_LIST 'TABLES' ; ignore si absent.    }
{ ============================================================ }
Procedure CodegenProcFreq(ProcNode: Integer);
Var
  Child   : Integer;
  TabNode : Integer;
  VarNode : Integer;
  VarName : String;
  LblStr  : String;
  SIdx    : Integer;
Begin
  If AstTable[ProcNode].NumVal <> 0 Then Exit; { NOPRINT }

  TabNode := -1;
  Child := AstTable[ProcNode].FirstChild;
  While Child >= 0 Do Begin
    If (AstTable[Child].Kind = NK_VAR_LIST) And
       (AstTable[Child].Text = 'TABLES') Then Begin
      TabNode := Child; Break;
    End;
    Child := AstTable[Child].NextSibling;
  End;

  If TabNode < 0 Then Exit; { pas de TABLES = rien a afficher }

  VarNode := AstTable[TabNode].FirstChild;
  While VarNode >= 0 Do Begin
    VarName := UpperStr(AstTable[VarNode].Text);
    SIdx := FindSym(VarName, SK_NONE);
    If (SIdx >= 0) And (SymTable[SIdx].Kind = SK_VAR_NUM) Then Begin
      { Entete : nom de la variable }
      LblStr := EmitRDataStr(VarName + ':');
      BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
      BinCallLabel('_SASRT_newline');
      { Ligne de frequence : <valeur> N=1 Pct=100 }
      BinPushMem32(SymTable[SIdx].AsmName);
      BinCallLabel('_SASRT_write_num');
      LblStr := EmitRDataStr(' N=1 Pct=100');
      BinPushLabel(LblStr); BinCallLabel('_SASRT_write_str');
      BinCallLabel('_SASRT_newline');
    End;
    VarNode := AstTable[VarNode].NextSibling;
  End;
End;

{ ============================================================ }
{ TODO 21 — Codegen PROC SORT                                  }
{ V1 : tri en insertion non implemente (dataset multi-lignes   }
{ requis). Emet un avertissement si la clause BY est absente.  }
{ ============================================================ }
Procedure CodegenProcSort(ProcNode: Integer);
Var
  Child : Integer;
  HasBy : Boolean;
Begin
  HasBy := False;
  Child := AstTable[ProcNode].FirstChild;
  While Child >= 0 Do Begin
    If AstTable[Child].Kind = NK_BY Then Begin HasBy := True; Break; End;
    Child := AstTable[Child].NextSibling;
  End;
  If Not HasBy Then
    CompileWarn('PROC SORT sans BY : aucun tri effectue');
  { V1 : pas de codegen — tri multi-lignes non implemente }
End;

{ ============================================================ }
{ TODO 23 — Runtime : fonctions numeriques integrees           }
{ ABS INT SIGN MOD MIN MAX SUM ROUND CEIL FLOOR SQRT LOG EXP  }
{ Convention stdcall : args sur pile (droite→gauche), EAX=res }
{ ============================================================ }
Procedure EmitRuntimeNumFunc;
Begin
  { --- _SASRT_abs(x): LongInt --- retourne |x| }
  BinDefineLabel('_SASRT_abs');
  BinEmit8($55);                               { push ebp }
  BinEmit8($89); BinEmit8($E5);               { mov ebp, esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);{ mov eax, [ebp+8] }
  BinEmit8($85); BinEmit8($C0);               { test eax, eax }
  BinEmit8($7D); BinEmit8($02);               { jns +2 → pop ebp }
  BinEmit8($F7); BinEmit8($D8);               { neg eax }
  BinEmit8($5D);                               { pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);{ ret 4 }

  { --- _SASRT_int(x): LongInt --- identite pour entiers }
  BinDefineLabel('_SASRT_int');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_round(x): LongInt --- identite pour entiers }
  BinDefineLabel('_SASRT_round');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_ceil(x): LongInt --- identite pour entiers }
  BinDefineLabel('_SASRT_ceil');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_floor(x): LongInt --- identite pour entiers }
  BinDefineLabel('_SASRT_floor');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_sign(x): LongInt --- retourne -1/0/+1 }
  { Layout: test→jz(zero)→jns(pos)→mov -1→jmp done→mov 1→jmp done→xor 0→done }
  { Deplacement jz  : next=10, cible=26 → disp=$10                             }
  { Deplacement jns : next=12, cible=19 → disp=$07                             }
  { Deplacement jmp (apres -1): next=19, cible=28 → disp=$09                   }
  { Deplacement jmp (apres +1): next=26, cible=28 → disp=$02                   }
  BinDefineLabel('_SASRT_sign');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($85); BinEmit8($C0);               { test eax, eax }
  BinEmit8($74); BinEmit8($10);               { jz  +16 → xor eax,eax }
  BinEmit8($79); BinEmit8($07);               { jns +7  → mov eax,1 }
  BinEmit8($B8); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); { mov eax,-1 }
  BinEmit8($EB); BinEmit8($09);               { jmp +9  → pop ebp }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinEmit8($EB); BinEmit8($02);               { jmp +2  → pop ebp }
  BinEmit8($31); BinEmit8($C0);               { xor eax,eax }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_mod(a,b): LongInt --- reste de a/b, protege div/0 }
  { Layout: mov eax→mov ecx→test ecx→jz(done)→cdq→idiv→mov eax,edx→done }
  { Deplacement jz : next=13, cible=18 → disp=$05                         }
  BinDefineLabel('_SASRT_mod');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8]  dividende }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C); { mov ecx,[ebp+12] diviseur  }
  BinEmit8($85); BinEmit8($C9);                { test ecx,ecx }
  BinEmit8($74); BinEmit8($05);                { jz +5 → pop ebp (retourne a) }
  BinEmit8($99);                               { cdq }
  BinEmit8($F7); BinEmit8($F9);               { idiv ecx }
  BinEmit8($89); BinEmit8($D0);               { mov eax,edx (reste) }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);{ ret 8 }

  { --- _SASRT_min(a,b): LongInt --- retourne min(a,b) }
  { Deplacement jle : next=13, cible=15 → disp=$02 }
  BinDefineLabel('_SASRT_min');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);
  BinEmit8($3B); BinEmit8($C1);               { cmp eax,ecx }
  BinEmit8($7E); BinEmit8($02);               { jle +2 → pop ebp (a<=b, garde eax) }
  BinEmit8($89); BinEmit8($C8);               { mov eax,ecx }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_max(a,b): LongInt --- retourne max(a,b) }
  { Deplacement jge : next=13, cible=15 → disp=$02 }
  BinDefineLabel('_SASRT_max');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);
  BinEmit8($3B); BinEmit8($C1);
  BinEmit8($7D); BinEmit8($02);               { jge +2 → pop ebp (a>=b, garde eax) }
  BinEmit8($89); BinEmit8($C8);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_sqrt(x): LongInt --- trunc(sqrt(x)) via FPU }
  { FILD dword: DB /5 → ModRM(mod=01,reg=5,rm=5)=$6D      }
  { FISTP dword: DB /7 → ModRM(mod=01,reg=7,rm=5)=$7D     }
  BinDefineLabel('_SASRT_sqrt');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04); { sub esp,4  (local dword) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8] }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC); { mov [ebp-4],eax }
  BinEmit8($DB); BinEmit8($6D); BinEmit8($FC); { fild dword [ebp-4] }
  BinEmit8($D9); BinEmit8($FA);               { fsqrt }
  BinEmit8($DB); BinEmit8($7D); BinEmit8($FC); { fistp dword [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC); { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);               { mov esp,ebp }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_log(x): LongInt --- stub retourne 0 (TODO 25 : FPU FYL2X) }
  BinDefineLabel('_SASRT_log');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);               { xor eax,eax }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_exp(x): LongInt --- stub retourne 0 (TODO 25 : FPU F2XM1) }
  BinDefineLabel('_SASRT_exp');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_sum --- stub retourne 0 (variadic, impl. dans TODO 25) }
  BinDefineLabel('_SASRT_sum');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_pow(base,exp) --- puissance entiere (28 octets) }
  { [ebp+8]=base  [ebp+12]=exp ; ret 8 }
  BinDefineLabel('_SASRT_pow');
  BinEmit8($55);                                  { push ebp        }
  BinEmit8($89); BinEmit8($E5);                  { mov ebp, esp    }
  BinEmit8($B8); BinEmit32(1);                   { mov eax, 1      }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);   { mov ecx,[ebp+8] }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);   { mov edx,[ebp+12]}
  { loop: }
  BinEmit8($85); BinEmit8($D2);                  { test edx, edx   }
  BinEmit8($7E); BinEmit8($06);                  { jle done (+6)   }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);   { imul eax, ecx  }
  BinEmit8($4A);                                  { dec edx         }
  BinEmit8($EB); BinEmit8($F6);                  { jmp loop (-10)  }
  { done: }
  BinEmit8($5D);                                  { pop ebp         }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);   { ret 8           }
End;

{ ============================================================ }
{ TODO 23 — Dispatch appel de fonction integree (NK_CALL)      }
{ Appele par CodegenExpr (TODO 25) apres evaluation des args.  }
{ Args deja empiles droite→gauche avant cet appel.             }
{ Resultat retourne dans EAX.                                   }
{ ============================================================ }
Procedure CodegenCall(Node: Integer);
Var
  FName : String;
Begin
  FName := AstTable[Node].Text;

  { Fonctions a 1 argument : arg push par CodegenExpr avant cet appel }
  If FName = 'ABS'   Then Begin BinCallLabel('_SASRT_abs');   Exit; End;
  If FName = 'INT'   Then Begin BinCallLabel('_SASRT_int');   Exit; End;
  If FName = 'SIGN'  Then Begin BinCallLabel('_SASRT_sign');  Exit; End;
  If FName = 'ROUND' Then Begin BinCallLabel('_SASRT_round'); Exit; End;
  If FName = 'CEIL'  Then Begin BinCallLabel('_SASRT_ceil');  Exit; End;
  If FName = 'FLOOR' Then Begin BinCallLabel('_SASRT_floor'); Exit; End;
  If FName = 'SQRT'  Then Begin BinCallLabel('_SASRT_sqrt');  Exit; End;
  If FName = 'LOG'   Then Begin BinCallLabel('_SASRT_log');   Exit; End;
  If FName = 'EXP'   Then Begin BinCallLabel('_SASRT_exp');   Exit; End;

  { Fonctions a 2 arguments }
  If FName = 'MOD'   Then Begin BinCallLabel('_SASRT_mod'); Exit; End;
  If FName = 'MIN'   Then Begin BinCallLabel('_SASRT_min'); Exit; End;
  If FName = 'MAX'   Then Begin BinCallLabel('_SASRT_max'); Exit; End;

  { SUM variadic — stub, TODO 25 gerera l accumulation }
  If FName = 'SUM' Then Begin BinCallLabel('_SASRT_sum'); Exit; End;

  { Fonctions chaines }
  If FName = 'LENGTH'   Then Begin BinCallLabel('_SASRT_length');   Exit; End;
  If FName = 'UPCASE'   Then Begin BinCallLabel('_SASRT_upcase');   Exit; End;
  If FName = 'LOWCASE'  Then Begin BinCallLabel('_SASRT_lowcase');  Exit; End;
  If FName = 'TRIM'     Then Begin BinCallLabel('_SASRT_trim');     Exit; End;
  If FName = 'LEFT'     Then Begin BinCallLabel('_SASRT_left');     Exit; End;
  If FName = 'RIGHT'    Then Begin BinCallLabel('_SASRT_right');    Exit; End;
  If FName = 'SUBSTR'   Then Begin BinCallLabel('_SASRT_substr');   Exit; End;
  If FName = 'INDEX'    Then Begin BinCallLabel('_SASRT_index');    Exit; End;
  If FName = 'COMPRESS' Then Begin BinCallLabel('_SASRT_compress'); Exit; End;
  If FName = 'CAT'      Then Begin BinCallLabel('_SASRT_cat');      Exit; End;
  If FName = 'PUT'      Then Begin BinCallLabel('_SASRT_put');      Exit; End;
  { Fonctions de date }
  If FName = 'TODAY'    Then Begin BinCallLabel('_SASRT_today');    Exit; End;
  If FName = 'MDY'      Then Begin BinCallLabel('_SASRT_mdy');      Exit; End;
  If FName = 'YEAR'     Then Begin BinCallLabel('_SASRT_year');     Exit; End;
  If FName = 'MONTH'    Then Begin BinCallLabel('_SASRT_month');    Exit; End;
  If FName = 'DAY'      Then Begin BinCallLabel('_SASRT_day');      Exit; End;
  If FName = 'POW'      Then Begin BinCallLabel('_SASRT_pow');      Exit; End;

  CompileWarn('CodegenCall : fonction inconnue : ' + FName);
End;

{ ============================================================ }
{ TODO 24 — Runtime : fonctions chaines integrees              }
{ Convention stdcall ; les ptrs designent des buffers 256 o.  }
{ ============================================================ }
Procedure EmitRuntimeStrFunc;
Begin
  { --- _SASRT_length(s: ptr): LongInt --- longueur sans espaces finaux }
  { Algo : scan avant, met a jour eax quand char non-espace             }
  { Registres : esi=base(sauve), eax=result, ecx=index, dl=char        }
  { Layout (34 o) : deplacement jz done=0x0B, je skip=0x03, jmp=-18   }
  BinDefineLabel('_SASRT_length');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($56);                               { push esi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08); { mov esi,[ebp+8] }
  BinEmit8($31); BinEmit8($C0);               { xor eax,eax }
  BinEmit8($31); BinEmit8($C9);               { xor ecx,ecx }
  { scan_loop: offset=11 }
  BinEmit8($8A); BinEmit8($14); BinEmit8($0E);{ mov dl,[esi+ecx] }
  BinEmit8($84); BinEmit8($D2);               { test dl,dl }
  BinEmit8($74); BinEmit8($0B);               { jz done   +11 → offset 29 }
  BinEmit8($80); BinEmit8($FA); BinEmit8($20);{ cmp dl,' ' }
  BinEmit8($74); BinEmit8($03);               { je skip   +3  → offset 26 }
  BinEmit8($8D); BinEmit8($41); BinEmit8($01);{ lea eax,[ecx+1] }
  { skip: offset=26 }
  BinEmit8($41);                               { inc ecx }
  BinEmit8($EB); BinEmit8($EE);               { jmp scan_loop  -18 → offset 11 }
  { done: offset=29 }
  BinEmit8($5E);                               { pop esi }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_upcase(s: ptr): ptr --- majuscules en place, retourne s }
  { Registres : esi=ptr(sauve), al=char                                 }
  { Layout (36 o) : jz done=0x0F, jb skip=0x08, ja skip=0x04, jmp=-21 }
  BinDefineLabel('_SASRT_upcase');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($56);
  BinEmit8($8B); BinEmit8($75); BinEmit8($08); { mov esi,[ebp+8] }
  { loop_start: offset=7 }
  BinEmit8($8A); BinEmit8($06);               { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);               { test al,al }
  BinEmit8($74); BinEmit8($0F);               { jz done   → offset 28 }
  BinEmit8($3C); BinEmit8($61);               { cmp al,'a' }
  BinEmit8($72); BinEmit8($08);               { jb skip   → offset 25 }
  BinEmit8($3C); BinEmit8($7A);               { cmp al,'z' }
  BinEmit8($77); BinEmit8($04);               { ja skip   → offset 25 }
  BinEmit8($2C); BinEmit8($20);               { sub al,0x20 }
  BinEmit8($88); BinEmit8($06);               { mov [esi],al }
  { skip: offset=25 }
  BinEmit8($46);                               { inc esi }
  BinEmit8($EB); BinEmit8($EB);               { jmp loop_start  -21 → offset 7 }
  { done: offset=28 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8] }
  BinEmit8($5E);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_lowcase(s: ptr): ptr --- minuscules en place, retourne s }
  { Identique a upcase : 'A'-'Z' → +0x20                               }
  BinDefineLabel('_SASRT_lowcase');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($56);
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);
  { loop_start: offset=7 }
  BinEmit8($8A); BinEmit8($06);
  BinEmit8($84); BinEmit8($C0);
  BinEmit8($74); BinEmit8($0F);               { jz done → offset 28 }
  BinEmit8($3C); BinEmit8($41);               { cmp al,'A' }
  BinEmit8($72); BinEmit8($08);               { jb skip → offset 25 }
  BinEmit8($3C); BinEmit8($5A);               { cmp al,'Z' }
  BinEmit8($77); BinEmit8($04);               { ja skip → offset 25 }
  BinEmit8($04); BinEmit8($20);               { add al,0x20 }
  BinEmit8($88); BinEmit8($06);
  { skip: offset=25 }
  BinEmit8($46);
  BinEmit8($EB); BinEmit8($EB);               { jmp loop_start -21 → offset 7 }
  { done: offset=28 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5E);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_trim(s: ptr): ptr --- supprime espaces finaux, retourne s }
  { Passe 1 : strlen via [esi+ecx] ; passe 2 : recule tant que ' '.    }
  { Layout (44 o) : je strip=+3, jmp1=-9, jz done=+10, jne restore=+2, }
  {                 jmp2=-13, puis inc ecx/mov 0/ret.                   }
  BinDefineLabel('_SASRT_trim');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($56);
  BinEmit8($8B); BinEmit8($75); BinEmit8($08); { mov esi,[ebp+8] }
  BinEmit8($31); BinEmit8($C9);               { xor ecx,ecx }
  { find_end: offset=9 }
  BinEmit8($80); BinEmit8($3C); BinEmit8($0E); BinEmit8($00); { cmp byte [esi+ecx],0 }
  BinEmit8($74); BinEmit8($03);               { je strip  +3 → offset 18 }
  BinEmit8($41);                               { inc ecx }
  BinEmit8($EB); BinEmit8($F7);               { jmp find_end  -9 → offset 9 }
  { strip / strip_loop: offset=18 }
  BinEmit8($85); BinEmit8($C9);               { test ecx,ecx }
  BinEmit8($74); BinEmit8($0A);               { jz done  +10 → offset 32 }
  BinEmit8($49);                               { dec ecx }
  BinEmit8($80); BinEmit8($3C); BinEmit8($0E); BinEmit8($20); { cmp byte [esi+ecx],' ' }
  BinEmit8($75); BinEmit8($02);               { jne restore  +2 → offset 31 }
  BinEmit8($EB); BinEmit8($F3);               { jmp strip_loop  -13 → offset 18 }
  { restore: offset=31 }
  BinEmit8($41);                               { inc ecx }
  { done: offset=32 }
  BinEmit8($C6); BinEmit8($04); BinEmit8($0E); BinEmit8($00); { mov byte [esi+ecx],0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8] }
  BinEmit8($5E);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_left(s: ptr): ptr --- stub : retourne s sans modification }
  BinDefineLabel('_SASRT_left');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_right(s: ptr): ptr --- stub : retourne s }
  BinDefineLabel('_SASRT_right');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_substr(s, pos, n): ptr --- stub : retourne s (3 args) }
  BinDefineLabel('_SASRT_substr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00); { ret 12 }

  { --- _SASRT_index(s, sub): LongInt --- stub : retourne 0 (2 args) }
  BinDefineLabel('_SASRT_index');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { ret 8 }

  { --- _SASRT_compress(s, c): ptr --- stub : retourne s (2 args) }
  BinDefineLabel('_SASRT_compress');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_cat(s1, s2): ptr --- stub : retourne s1 (2 args) }
  BinDefineLabel('_SASRT_cat');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_put(n: LongInt): ptr --- stub retourne 0 (TODO 25 : num2str) }
  BinDefineLabel('_SASRT_put');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
End;

{ ============================================================ }
{ TODO 24 — Runtime : fonctions de date integrees              }
{ Dates SAS = entier (jours depuis 01/01/1960).                }
{ V1 : stubs retournant 0, TODAY() retourne 0.                 }
{ ============================================================ }
Procedure EmitRuntimeDateFunc;
Begin
  { --- _SASRT_today(): LongInt --- stub retourne 0 (sans arg) }
  BinDefineLabel('_SASRT_today');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);               { xor eax,eax }
  BinEmit8($5D); BinEmit8($C3);               { pop ebp ; ret (0 arg) }

  { --- _SASRT_mdy(m,d,y): LongInt --- stub retourne 0 (3 args) }
  BinDefineLabel('_SASRT_mdy');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_year(d): LongInt --- stub retourne 0 (1 arg) }
  BinDefineLabel('_SASRT_year');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_month(d): LongInt --- stub retourne 0 (1 arg) }
  BinDefineLabel('_SASRT_month');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_day(d): LongInt --- stub retourne 0 (1 arg) }
  BinDefineLabel('_SASRT_day');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }
Var
  I        : Integer;
  Arg      : String;
  ExpandedSrc : String;

BEGIN
 If(ParamStr(1)='/?')or(ParamStr(1)='--help')or(ParamStr(1)='-h')or
   (ParamStr(1)='/h')or(ParamStr(1)='/H')Then Begin
  WriteLn('SASCW32 - Cette commande permet de lancer le compilateur SAS ',
          'pour l''assembleur du microprocesseur 80386 pour le systeme ',
          'd''exploitation Windows 32 bits (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe : SASCW32 source.sas [-obj|-asm] [sortie]');
  WriteLn('  (defaut) -> source.exe   PE32 autonome');
  WriteLn('  -obj     -> source.obj   COFF relocatable');
  WriteLn('  -asm     -> source.asm   texte MASM/JWasm');
  Halt;
 End;
  SrcFile  := '';
  OutFile  := '';
  OutMode  := MODE_EXE;
  HasError := False;
  ErrorCount := 0;
  WarnCount  := 0;

  { --- Lecture des arguments de la ligne de commande --- }
  For I := 1 To ParamCount Do Begin
    Arg := ParamStr(I);
    If Arg = '-obj' Then OutMode := MODE_OBJ
    Else If Arg = '-asm' Then OutMode := MODE_ASM
    Else If (Length(Arg) > 0) And (Arg[1] <> '-') Then Begin
      If SrcFile = '' Then SrcFile := Arg
      Else If OutFile = '' Then OutFile := Arg;
    End;
  End;

  If SrcFile = '' Then Begin
    WriteLn('Usage: SASCW32 source.sas [-obj|-asm] [sortie]');
    WriteLn('  (defaut : produit sortie.exe)');
    Halt(1);
  End;

  If Not FileExists(SrcFile) Then Begin
    WriteLn('SASCW32: fichier source introuvable : ', SrcFile);
    Halt(1);
  End;

  { --- Determiner le nom du fichier de sortie --- }
  If OutFile = '' Then Begin
    Case OutMode Of
      MODE_EXE : OutFile := ChangeExt(SrcFile, '.exe');
      MODE_OBJ : OutFile := ChangeExt(SrcFile, '.obj');
      MODE_ASM : OutFile := ChangeExt(SrcFile, '.asm');
    End;
  End;

  { --- Initialisation des tables --- }
  InitTables;

  { --- Phase 1 : Macro-preprocesseur --- }
  ExpandedSrc := MacroExpand(SrcFile);

  { --- Phase 2-3 : Lexer + Parseur --- }
  LexInit(ExpandedSrc);
  ParseProgram;

  If HasError Then Begin
    WriteLn('SASCW32: compilation echouee (', ErrorCount,
            ' erreur(s), ', WarnCount, ' avertissement(s))');
    Halt(1);
  End;

  { --- Phase 4 : Generation de code --- }
  BinRegisterKernel32Imports;
  EmitRuntimeIO;
  EmitRuntimeNumFunc;
  EmitRuntimeStrFunc;
  EmitRuntimeDateFunc;
  CodegenProgram;

  If HasError Then Begin
    WriteLn('SASCW32: erreur lors de la generation de code');
    Halt(1);
  End;

  { --- Phase 5 : Ecriture du fichier de sortie --- }
  Case OutMode Of
    MODE_EXE : WritePE(OutFile);
    MODE_OBJ : WriteCOFF(OutFile);
    MODE_ASM : WriteASM(OutFile);
  End;

  If HasError Then Begin
    WriteLn('SASCW32: echec de l ecriture de : ', OutFile);
    Halt(1);
  End;

  If WarnCount > 0 Then
    WriteLn('SASCW32: ', WarnCount, ' avertissement(s)');
  WriteLn('SASCW32: ', OutFile, ' genere avec succes.');
END.
