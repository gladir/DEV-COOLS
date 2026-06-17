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
            Format inline : put var best. ou put var 8.2 (format simple en V1).
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
            En V1 : support minimal, INFILE CARDS + INPUT + PUT fonctionnel.

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
            En V1 : SET _NULL_ = pas de lecture, SET dataset = lecture simplifiee
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
            NOPRINT : ne rien afficher.
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
            Formats predefinis minimaux : BEST., 8.2, $CHAR., DATE. etc.
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
              SQRT(x)      : racine carree via FPU x87
              LOG(x)       : logarithme naturel via FPU x87
              EXP(x)       : exponentielle via FPU x87
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
              TODAY()          : date courante via GetLocalTime
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
  NK_CALL_STMT   = 38;  { statement CALL routine(args)  }

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
  KW_CALL       = 88;   { CALL }

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
  CurParseStepSeq: Integer;   { incremente pour chaque DATA step parse }
  CurDsEndLabel  : String;    { etiquette fin du DATA step courant (STOP) }

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
Function  ExprIsChar(Node: Integer): Boolean;                  Forward;
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
Procedure ParseStmtCall;                                       Forward;

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
Procedure BinMovEaxLabelAddr(Const LblName: String);           Forward;
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
  BinPLKCount    := 0;
  LoopTop        := 0;
  CurDsEndLabel  := '';
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
  CurDsRoot       := -1;
  CurDsIdx        := -1;
  CurParseStepSeq := 0;
  HasError     := False;
  ErrorCount   := 0;
  WarnCount    := 0;
  For I := 0 To MAX_VARS-1    Do VarNames[I] := '';
End;

{ ============================================================ }
{ Corps des sections TODO 02..24 (implementes au fur          }
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

{ Traiter %do ; ... %end ; bloc simple, iteration geree par MacroRunBlock }
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
  Else If S = 'CALL'        Then LexKeyword := KW_CALL
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
    KW_CALL:     ParseStmtCall;
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
  Inc(CurParseStepSeq);  { portee propre pour les variables de ce step }
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
Var I : Integer;
    NU: String;
Begin
  { Rechercher uniquement dans la portee du DATA step courant }
  NU := UpperStr(Name);
  For I := 0 To SymCount-1 Do
    If (SymTable[I].Name = NU) And
       ((SymTable[I].Kind = SK_VAR_NUM) Or (SymTable[I].Kind = SK_VAR_CHAR)) And
       (SymTable[I].DsIdx = CurParseStepSeq) Then Begin
      GetOrAddVar := I; Exit;
    End;
  If IsChar Then I := AddSym(Name, SK_VAR_CHAR)
            Else I := AddSym(Name, SK_VAR_NUM);
  If I >= 0 Then Begin
    SymTable[I].IsChar := IsChar;
    SymTable[I].DsIdx  := CurParseStepSeq;
    If VarCount < MAX_VARS Then Begin
      SymTable[I].VarIdx := VarCount;
      VarNames[VarCount] := NU;
      Inc(VarCount);
    End;
  End;
  GetOrAddVar := I;
End;

{ Retourne True si le noeud AST produit une valeur de type chaine. }
{ Utilise pour inferrer le type d une variable au moment de l aff.  }
Function ExprIsChar(Node: Integer): Boolean;
Var
  SI : Integer;
  FN : String;
Begin
  ExprIsChar := False;
  If Node < 0 Then Exit;
  Case AstTable[Node].Kind Of
    NK_LITERAL:
      ExprIsChar := AstTable[Node].IsChar;
    NK_VAR: Begin
      SI := AstTable[Node].SymRef;
      If SI < 0 Then SI := FindSym(AstTable[Node].Text, SK_NONE);
      If (SI >= 0) And SymTable[SI].IsChar Then ExprIsChar := True;
    End;
    NK_CALL: Begin
      FN := AstTable[Node].Text;
      ExprIsChar := (FN = 'ATTRC')    Or
                    (FN = 'UPCASE')   Or (FN = 'LOWCASE')  Or
                    (FN = 'TRIM')     Or (FN = 'LEFT')     Or
                    (FN = 'RIGHT')    Or (FN = 'SUBSTR')   Or
                    (FN = 'COMPRESS') Or (FN = 'CAT')      Or
                    (FN = 'PUT')      Or (FN = 'TRANWRD')  Or
                    (FN = 'COMPBL')   Or (FN = 'COLLATE')  Or
                    (FN = 'DEQUOTE')  Or (FN = 'DSNAME')  Or
                    (FN = 'DINFO')    Or (FN = 'DOPTNAME') Or
                    (FN = 'DREAD')    Or
                    (FN = 'FINFO')    Or (FN = 'FIPNAME')  Or
                    (FN = 'FIPNAMEL') Or (FN = 'FIPSTATE') Or
                    (FN = 'FOPTNAME') Or (FN = 'GETOPTION') Or
                    (FN = 'GETVARC')  Or
                    (FN = 'HTMLDECODE') Or (FN = 'HTMLENCODE') Or
                    (FN = 'INPUTC')   Or (FN = 'IORCMSG')   Or
                    (FN = 'KCOMPRESS') Or (FN = 'KLEFT')    Or
                    (FN = 'KLOWCASE') Or (FN = 'KREVERSE')  Or
                    (FN = 'KRIGHT')   Or (FN = 'KSCAN')     Or
                    (FN = 'KSTRCAT')  Or (FN = 'KSUBSTR')   Or
                    (FN = 'KSUBSTRB') Or (FN = 'KTRANSLATE') Or
                    (FN = 'KTRIM')    Or (FN = 'KTRUNCATE') Or
                    (FN = 'KUPCASE')  Or
                    (FN = 'KUPDATE')  Or (FN = 'KUPDATEB') Or
                    (FN = 'MODULEC')  Or (FN = 'MODULEIC') Or
                    (FN = 'PATHNAME') Or (FN = 'PEEKC')   Or
                    (FN = 'PUTC')     Or (FN = 'PUTN')   Or
                    (FN = 'QUOTE')    Or (FN = 'REPEAT')  Or
                    (FN = 'RESOLVE')  Or (FN = 'REVERSE') Or
                    (FN = 'SCAN')     Or
                    (FN = 'SOUNDEX')  Or (FN = 'STNAME')  Or
                    (FN = 'STNAMEL') Or (FN = 'SYMGET')  Or
                    (FN = 'SYSGET')  Or (FN = 'SYSMSG')  Or
                    (FN = 'SYSPARM') Or
                    (FN = 'TRANSLATE') Or (FN = 'TRIMN')    Or
                    (FN = 'URLDECODE') Or (FN = 'URLENCODE') Or
                    (FN = 'VARFMT')    Or (FN = 'VARINFMT') Or
                    (FN = 'VARLABEL')  Or (FN = 'VARNAME')  Or
                    (FN = 'VFORMAT')   Or (FN = 'VFORMATN') Or
                    (FN = 'VFORMATNX') Or (FN = 'VFORMATX') Or
                    (FN = 'VINFORMAT') Or (FN = 'VINFORMATN') Or
                    (FN = 'VINFORMATNX') Or (FN = 'VINFORMATX') Or
                    (FN = 'VLABEL')    Or (FN = 'VLABELX')  Or
                    (FN = 'VNAME')     Or (FN = 'VNAMEX')   Or
                    (FN = 'VTYPE')     Or (FN = 'VTYPEX')   Or
                    (FN = 'ZIPNAME')   Or (FN = 'ZIPNAMEL') Or
                    (FN = 'ZIPSTATE');
    End;
    NK_BINOP: Begin
      If AstTable[Node].Text = '||' Then ExprIsChar := True;
    End;
  End;
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

{ --- Parseurs pour TODO 10-17 / 22 / 13 --- }

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
    { Etiquette name: -> NK_GOTO(IsChar=True) = definition de label }
    SIdx    := AddLabel(VarName);
    LexNextToken;
    VarNode := AstNew(NK_GOTO, VarName, Line);
    AstTable[VarNode].IsChar := True;
    AstTable[VarNode].SymRef := SIdx;
    AstAddChild(CurDsRoot, VarNode);
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
    { Inferrer type chaine depuis le RHS et upgrader le symbole }
    If (SIdx >= 0) And (Not SymTable[SIdx].IsChar) And ExprIsChar(ExprNode) Then Begin
      SymTable[SIdx].Kind   := SK_VAR_CHAR;
      SymTable[SIdx].IsChar := True;
    End;
    VarNode    := AstNewVar(VarName, Line);
    AstTable[VarNode].SymRef := SIdx;
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
    AstTable[VarNode].SymRef := SIdx;
    VarNode2   := AstNewVar(VarName, Line);
    AstTable[VarNode2].SymRef := SIdx;
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
    End Else If CurTokType = TOK_INTEGER Then Begin
      { Spec de colonne : n ou n-m — pointeur de colonne, ignorer }
      LexNextToken;  { skip n }
      If CurTokType = TOK_MINUS Then Begin
        LexNextToken;  { skip - }
        If CurTokType = TOK_INTEGER Then LexNextToken;  { skip m }
      End;
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
{ TODO 26 — DATA STEP : CALL routine(args)                     }
{ CALL nom(arg1, arg2, ...) ;                                   }
{ Cree NK_CALL_STMT avec le nom de la routine dans Text et     }
{ les arguments comme noeuds enfants.                          }
{ ============================================================ }
Procedure ParseStmtCall;
Var
  N    : Integer;
  FN   : String;
  ArgN : Integer;
  Line : Integer;
Begin
  Line := CurLineNum;
  LexNextToken;  { sauter CALL }
  { Accepter identifiant ou mot-cle (ex: CALL SET, CALL SYSTEM) }
  If (CurTokType <> TOK_IDENT) And (CurTokType < KW_DATA) Then Begin
    SkipToSemicolon; Exit;
  End;
  FN := UpperStr(CurTokStr);
  N  := AstNew(NK_CALL_STMT, FN, Line);
  LexNextToken;
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do Begin
      If CurTokType = TOK_COMMA Then Begin LexNextToken; Continue; End;
      ArgN := ParseExprOr(Line);
      AstAddChild(N, ArgN);
    End;
    If CurTokType = TOK_RPAREN Then LexNextToken;
  End;
  AstAddChild(CurDsRoot, N);
  If CurTokType = TOK_SEMICOL Then LexNextToken;
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
  SIdx : Integer;
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
      SIdx := GetOrAddVar(CurTokStr, False);
      AstTable[T].SymRef := SIdx;
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
        SIdx := GetOrAddVar(Name, False);
        AstTable[T].SymRef := SIdx;
        ParseExprPrimary := T;
      End Else Begin
        { Reference de variable simple }
        T := AstNewVar(Name, Line);
        SIdx := GetOrAddVar(Name, False);
        AstTable[T].SymRef := SIdx;
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
        SIdx := GetOrAddVar(Name, False);
        AstTable[T].SymRef := SIdx;
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
    SIdx := AstTable[Child].SymRef;
    If SIdx < 0 Then SIdx := FindSym(AstTable[Child].Text, SK_NONE);
    If SIdx >= 0 Then BLbl := SymTable[SIdx].AsmName
    Else BLbl := '_sas_v_0_' + AstTable[Child].Text;
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
      SIdx := AstTable[Node].SymRef;
      If SIdx < 0 Then SIdx := FindSym(AstTable[Node].Text, SK_NONE);
      If SIdx >= 0 Then Begin
        If SymTable[SIdx].IsChar Then
          BinMovEaxLabelAddr(SymTable[SIdx].AsmName) { EAX = adresse buffer }
        Else
          BinMovEaxMem(SymTable[SIdx].AsmName);      { EAX = valeur numerique }
      End Else Begin BinEmit8($31); BinEmit8($C0); End;
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
      End Else If AstTable[Node].Text = '||' Then Begin
        { Concatenation : ECX=src1 (gauche), EAX=src2 (droite) }
        BinEmit8($50);                  { PUSH EAX (src2)      }
        BinEmit8($51);                  { PUSH ECX (src1)      }
        BinCallLabel('_SASRT_concat');  { EAX = concat_buf ptr }
      End Else If (AstTable[Node].Text = '=')  Or
                  (AstTable[Node].Text = '<')  Or
                  (AstTable[Node].Text = '>')  Or
                  (AstTable[Node].Text = '<=') Or
                  (AstTable[Node].Text = '>=') Or
                  (AstTable[Node].Text = '<>') Then Begin
        If ExprIsChar(AstTable[Node].Left) Or
           ExprIsChar(AstTable[Node].Right) Then Begin
          { Comparaison chaines : ECX=s1, EAX=s2 → _SASRT_strcmp }
          BinEmit8($50);                  { PUSH EAX (s2)        }
          BinEmit8($51);                  { PUSH ECX (s1)        }
          BinCallLabel('_SASRT_strcmp'); { EAX=0 si egal        }
          BinEmit8($85); BinEmit8($C0); { TEST EAX,EAX         }
          If AstTable[Node].Text = '=' Then Begin
            BinEmit8($0F); BinEmit8($94); BinEmit8($C0); { SETE AL  }
          End Else If AstTable[Node].Text = '<>' Then Begin
            BinEmit8($0F); BinEmit8($95); BinEmit8($C0); { SETNE AL }
          End Else Begin
            { < > <= >= chaines : non implemente → 0 }
            BinEmit8($31); BinEmit8($C0);
          End;
          BinEmit8($0F); BinEmit8($B6); BinEmit8($C0); { MOVZX EAX,AL }
        End Else Begin
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
        End;
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
      End Else If AstTable[Node].Text = 'HBOUND' Then Begin
        Child := AstTable[Node].FirstChild;
        AIdx  := -1;
        If Child >= 0 Then AIdx := FindArrayIdx(AstTable[Child].Text);
        If AIdx >= 0 Then V := ArrayTable[AIdx].TotalSize Else V := 1;
        BinEmit8($B8); BinEmit32(V);    { MOV EAX, hbound }
      End Else If AstTable[Node].Text = 'LBOUND' Then Begin
        BinEmit8($B8); BinEmit32(1);    { MOV EAX, 1 (SAS 1-base) }
      End Else If AstTable[Node].Text = 'SUM' Then Begin
        { Accumulation inline : EAX = somme de tous les args }
        BinEmit8($31); BinEmit8($C0);   { XOR EAX, EAX = 0   }
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          BinEmit8($50);                { PUSH accumulateur   }
          CodegenExprEAX(Child);        { EAX = prochain arg  }
          BinEmit8($59);                { POP ECX             }
          BinEmit8($01); BinEmit8($C8); { ADD EAX, ECX        }
          Child := AstTable[Child].NextSibling;
        End;
      End Else If AstTable[Node].Text = 'SUBSTR' Then Begin
        { SUBSTR(s, pos [, len]) — normaliser a 3 args (len=0 = fin chaine) }
        ArgCnt := 0;
        Child  := AstTable[Node].FirstChild;
        While (Child >= 0) And (ArgCnt < 16) Do Begin
          ArgList[ArgCnt] := Child; Inc(ArgCnt);
          Child := AstTable[Child].NextSibling;
        End;
        { Empiler droite-a-gauche : len, pos, s }
        If ArgCnt >= 3 Then Begin
          CodegenExprEAX(ArgList[2]); BinEmit8($50);
        End Else Begin
          BinEmit8($6A); BinEmit8($00); { PUSH 0 = copier jusqu a fin }
        End;
        If ArgCnt >= 2 Then Begin
          CodegenExprEAX(ArgList[1]); BinEmit8($50);
        End Else Begin
          BinEmit8($6A); BinEmit8($01); { PUSH 1 par defaut }
        End;
        If ArgCnt >= 1 Then Begin
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
        End Else Begin
          BinEmit8($6A); BinEmit8($00);
        End;
        BinCallLabel('_SASRT_substr');
      End Else If AstTable[Node].Text = 'BAND' Then Begin
        { BAND(a,b) : ET binaire — a AND b }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          CodegenExprEAX(Child); BinEmit8($50);      { PUSH a      }
          Child := AstTable[Child].NextSibling;
          If Child >= 0 Then CodegenExprEAX(Child)   { EAX = b     }
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin BinEmit8($31); BinEmit8($C0); End;
        BinEmit8($59);                    { POP ECX = a }
        BinEmit8($21); BinEmit8($C8);    { AND EAX,ECX }
      End Else If AstTable[Node].Text = 'BOR' Then Begin
        { BOR(a,b) : OU binaire — a OR b }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          CodegenExprEAX(Child); BinEmit8($50);
          Child := AstTable[Child].NextSibling;
          If Child >= 0 Then CodegenExprEAX(Child)
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin BinEmit8($31); BinEmit8($C0); End;
        BinEmit8($59);
        BinEmit8($09); BinEmit8($C8);    { OR  EAX,ECX }
      End Else If AstTable[Node].Text = 'BXOR' Then Begin
        { BXOR(a,b) : OU exclusif binaire — a XOR b }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          CodegenExprEAX(Child); BinEmit8($50);
          Child := AstTable[Child].NextSibling;
          If Child >= 0 Then CodegenExprEAX(Child)
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin BinEmit8($31); BinEmit8($C0); End;
        BinEmit8($59);
        BinEmit8($31); BinEmit8($C8);    { XOR EAX,ECX }
      End Else If AstTable[Node].Text = 'BNOT' Then Begin
        { BNOT(a) : negation binaire — NOT a }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then CodegenExprEAX(Child)
        Else Begin BinEmit8($31); BinEmit8($C0); End;
        BinEmit8($F7); BinEmit8($D0);    { NOT EAX     }
      End Else If AstTable[Node].Text = 'BLSHIFT' Then Begin
        { BLSHIFT(a,n) : decalage binaire gauche — a SHL n }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          CodegenExprEAX(Child); BinEmit8($50);      { PUSH a      }
          Child := AstTable[Child].NextSibling;
          If Child >= 0 Then CodegenExprEAX(Child)   { EAX = n     }
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin
          BinEmit8($6A); BinEmit8($00);              { PUSH 0, n=0 }
          BinEmit8($31); BinEmit8($C0);
        End;
        BinEmit8($89); BinEmit8($C1);    { MOV ECX,EAX = n }
        BinEmit8($58);                    { POP EAX = a     }
        BinEmit8($D3); BinEmit8($E0);    { SHL EAX,CL      }
      End Else If AstTable[Node].Text = 'BRSHIFT' Then Begin
        { BRSHIFT(a,n) : decalage binaire droit arithmetique — a SAR n }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          CodegenExprEAX(Child); BinEmit8($50);
          Child := AstTable[Child].NextSibling;
          If Child >= 0 Then CodegenExprEAX(Child)
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin
          BinEmit8($6A); BinEmit8($00);
          BinEmit8($31); BinEmit8($C0);
        End;
        BinEmit8($89); BinEmit8($C1);    { MOV ECX,EAX = n }
        BinEmit8($58);                    { POP EAX = a     }
        BinEmit8($D3); BinEmit8($F8);    { SAR EAX,CL      }
      End Else If (AstTable[Node].Text = 'ADDR') Or
                  (AstTable[Node].Text = 'ADDRLONG') Then Begin
        { ADDR(var) / ADDRLONG(var) : adresse memoire de la variable }
        Child := AstTable[Node].FirstChild;
        If Child >= 0 Then Begin
          SIdx := AstTable[Child].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[Child].Text, SK_NONE);
          If SIdx >= 0 Then
            BinMovEaxLabelAddr(SymTable[SIdx].AsmName)
          Else Begin BinEmit8($31); BinEmit8($C0); End;
        End Else Begin BinEmit8($31); BinEmit8($C0); End;
      End Else If AstTable[Node].Text = 'COMPRESS' Then Begin
        { COMPRESS(s [, chars]) — normaliser a 2 args (chars=vide si absent) }
        ArgCnt := 0;
        Child  := AstTable[Node].FirstChild;
        While (Child >= 0) And (ArgCnt < 16) Do Begin
          ArgList[ArgCnt] := Child; Inc(ArgCnt);
          Child := AstTable[Child].NextSibling;
        End;
        If ArgCnt >= 2 Then Begin
          CodegenExprEAX(ArgList[1]); BinEmit8($50);
        End Else Begin
          LblStr := EmitRDataStr('');
          BinPushLabel(LblStr);        { PUSH "" comme chars vide }
        End;
        If ArgCnt >= 1 Then Begin
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
        End Else Begin
          BinEmit8($6A); BinEmit8($00);
        End;
        CodegenCall(Node);
      End Else If AstTable[Node].Text = 'SUM' Then Begin
        { SUM(a,b,...) : accumulation inline sans appel de fonction.     }
        { Algorithme : acc (pile) += chaque arg via PUSH/POP/ADD.        }
        ArgCnt := 0;
        Child  := AstTable[Node].FirstChild;
        While (Child >= 0) And (ArgCnt < 16) Do Begin
          ArgList[ArgCnt] := Child; Inc(ArgCnt);
          Child := AstTable[Child].NextSibling;
        End;
        If ArgCnt = 0 Then Begin
          BinEmit8($31); BinEmit8($C0);               { xor eax,eax }
        End Else Begin
          CodegenExprEAX(ArgList[0]);                  { eax = arg0 }
          BinEmit8($50);                               { push eax }
          For I := 1 To ArgCnt - 1 Do Begin
            CodegenExprEAX(ArgList[I]);                { eax = argI }
            BinEmit8($59);                             { pop ecx }
            BinEmit8($01); BinEmit8($C8);             { add eax,ecx }
            BinEmit8($50);                             { push eax }
          End;
          BinEmit8($58);                               { pop eax (total) }
        End;
      End Else Begin
        { Cas general : empiler les args droite-a-gauche, puis appeler }
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
  SelectExpr  : Integer;
  WhenN       : Integer;
  WIdx        : Integer;
  PrevItemLit : Boolean;
  FName       : String;
  VarName     : String;
  ArgList     : Array[0..15] Of Integer;
  ArgCnt      : Integer;
  I           : Integer;
Begin
  If Node < 0 Then Exit;
  Case AstTable[Node].Kind Of

    NK_ARRAY_DEF: ;  { Deja enregistre en pass 1 — aucun code }

    NK_ASSIGN: Begin
      RhsNode := AstTable[Node].Right;
      LeftN   := AstTable[Node].Left;
      If LeftN < 0 Then Exit;
      If AstTable[LeftN].Kind = NK_VAR Then Begin
        SIdx := AstTable[LeftN].SymRef;
        If SIdx < 0 Then SIdx := FindSym(AstTable[LeftN].Text, SK_NONE);
        If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
          { Var chaine : strcpy(dst_buf, src_ptr) }
          CodegenExprEAX(RhsNode);               { EAX = ptr source     }
          BinEmit8($50);                          { PUSH src             }
          BinMovEaxLabelAddr(SymTable[SIdx].AsmName); { EAX = adr buf dst }
          BinEmit8($50);                          { PUSH dst             }
          BinCallLabel('_SASRT_strcpy');          { strcpy(dst, src)     }
        End Else Begin
          CodegenExprEAX(RhsNode);
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
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
      LblTop  := '_dot' + Tag;
      LblEnd  := '_doe' + Tag;
      LblNext := LblTop;  { cible CONTINUE par defaut = retour au test }
      If AstTable[Node].Text = 'ITER' Then Begin
        LblNext := '_doi' + Tag;  { label increment pour CONTINUE correct }
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
        { Corps (avec contexte boucle pour LEAVE/CONTINUE) }
        If LoopTop < MAX_LOOP_NEST Then Begin
          LoopStack[LoopTop].LblStart := LblTop;
          LoopStack[LoopTop].LblNext  := LblNext;
          LoopStack[LoopTop].LblEnd   := LblEnd;
          Inc(LoopTop);
        End;
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        If LoopTop > 0 Then Dec(LoopTop);
        { Increment }
        BinDefineLabel(LblNext);
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
        If LoopTop < MAX_LOOP_NEST Then Begin
          LoopStack[LoopTop].LblStart := LblTop;
          LoopStack[LoopTop].LblNext  := LblTop;
          LoopStack[LoopTop].LblEnd   := LblEnd;
          Inc(LoopTop);
        End;
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        If LoopTop > 0 Then Dec(LoopTop);
        BinJmpLabel(LblTop);
        BinDefineLabel(LblEnd);
      End Else If AstTable[Node].Text = 'UNTIL' Then Begin
        BinDefineLabel(LblTop);
        If LoopTop < MAX_LOOP_NEST Then Begin
          LoopStack[LoopTop].LblStart := LblTop;
          LoopStack[LoopTop].LblNext  := LblTop;
          LoopStack[LoopTop].LblEnd   := LblEnd;
          Inc(LoopTop);
        End;
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
        If LoopTop > 0 Then Dec(LoopTop);
        CodegenExprEAX(AstTable[Node].Left);
        BinEmit8($85); BinEmit8($C0);
        BinJccLabel(4, LblTop);         { JZ lbl_top (tant que cond faux) }
        BinDefineLabel(LblEnd);
      End Else Begin
        { PLAIN : bloc non iteratif (wrapper THEN/ELSE ou DO; END;).    }
        { Ne pas pousser LoopStack — PLAIN n est pas une boucle.         }
        { LEAVE/CONTINUE traversent le PLAIN pour atteindre la boucle   }
        { englobante (ITER, WHILE, UNTIL) via LoopStack existant.        }
        Child := AstTable[Node].FirstChild;
        While Child >= 0 Do Begin
          CodegenStmt(Child);
          Child := AstTable[Child].NextSibling;
        End;
      End;
    End;

    NK_PUT: Begin
      PrevItemLit := True;  { pas d espace avant le premier item }
      Child := AstTable[Node].FirstChild;
      While Child >= 0 Do Begin
        { Espace entre vars/exprs consecutives, pas apres literal }
        If (Not PrevItemLit) And (AstTable[Child].Kind <> NK_LITERAL) Then Begin
          LblStr := EmitRDataStr(' ');
          BinPushLabel(LblStr);
          BinCallLabel('_SASRT_write_str');
        End;
        PrevItemLit := (AstTable[Child].Kind = NK_LITERAL);
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
          SIdx := AstTable[Child].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[Child].Text, SK_NONE);
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            BinPushLabel(SymTable[SIdx].AsmName); { push adr buffer }
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

    NK_CALL_STMT: Begin
      FName  := AstTable[Node].Text;
      ArgCnt := 0;
      Child  := AstTable[Node].FirstChild;
      While (Child >= 0) And (ArgCnt < 16) Do Begin
        ArgList[ArgCnt] := Child;  Inc(ArgCnt);
        Child := AstTable[Child].NextSibling;
      End;
      If FName = 'POKE' Then Begin
        { CALL POKE(addr, val) -- MOV [EAX], ECX }
        If ArgCnt >= 2 Then Begin
          CodegenExprEAX(ArgList[1]);
          BinEmit8($89); BinEmit8($C1);   { MOV ECX, EAX (val) }
          CodegenExprEAX(ArgList[0]);     { EAX = addr }
          BinEmit8($89); BinEmit8($08);   { MOV [EAX], ECX     }
        End;
      End Else If FName = 'SYSTEM' Then Begin
        { CALL SYSTEM(cmd) -- WinExec(cmd, SW_SHOWNORMAL=1) }
        BinEmit8($6A); BinEmit8($01);     { PUSH 1             }
        If ArgCnt >= 1 Then Begin
          CodegenExprEAX(ArgList[0]);
          BinEmit8($50);                  { PUSH EAX (cmd ptr) }
        End Else Begin
          BinEmit8($6A); BinEmit8($00);   { PUSH 0 (cmd null)  }
        End;
        BinCallImport('_WinExec@8');
      End Else If FName = 'VNAME' Then Begin
        { CALL VNAME(var, namevar) -- namevar = name of var as string }
        If ArgCnt >= 2 Then Begin
          VarName := AstTable[ArgList[0]].Text;
          LblStr  := EmitRDataStr(VarName);
          SIdx    := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            BinPushLabel(LblStr);
            BinMovEaxLabelAddr(SymTable[SIdx].AsmName);
            BinEmit8($50);
            BinCallLabel('_SASRT_strcpy');
          End;
        End;
      End Else If FName = 'RANBIN' Then Begin
        { CALL RANBIN(seed,n,p,result), p entier en pourcentage. }
        If ArgCnt >= 4 Then Begin
          SIdx := AstTable[ArgList[3]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[3]].Text, SK_NONE);
          CodegenExprEAX(ArgList[2]); BinEmit8($50); { p }
          CodegenExprEAX(ArgList[1]); BinEmit8($50); { n }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_ranbin');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else If ArgCnt >= 2 Then Begin
          { Compat ancien test: CALL RANBIN(seed,result) = Bernoulli certain. }
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          BinEmit8($6A); BinEmit8($01);              { p=1 }
          BinEmit8($6A); BinEmit8($01);              { n=1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_ranbin');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANCAU' Then Begin
        { CALL RANCAU(seed,result) -- meme runtime que RANCAU(seed). }
        If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
          BinCallLabel('_SASRT_rancau');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANEXP' Then Begin
        { CALL RANEXP(seed,result) -- meme runtime que RANEXP(seed). }
        If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
          BinCallLabel('_SASRT_ranexp');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANGAM' Then Begin
        { CALL RANGAM(seed,a,result), compat seed,result => a=1. }
        If ArgCnt >= 3 Then Begin
          SIdx := AstTable[ArgList[2]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[2]].Text, SK_NONE);
          CodegenExprEAX(ArgList[1]); BinEmit8($50); { a }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rangam');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          BinEmit8($6A); BinEmit8($01);              { a=1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rangam');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANNOR' Then Begin
        { CALL RANNOR(seed,result) -- meme runtime que RANNOR(seed). }
        If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
          BinCallLabel('_SASRT_rannor');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANPOI' Then Begin
        { CALL RANPOI(seed,m,result), compat seed,result => m=1. }
        If ArgCnt >= 3 Then Begin
          SIdx := AstTable[ArgList[2]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[2]].Text, SK_NONE);
          CodegenExprEAX(ArgList[1]); BinEmit8($50); { m }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_ranpoi');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          BinEmit8($6A); BinEmit8($01);              { m=1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_ranpoi');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANTBL' Then Begin
        { CALL RANTBL(seed,p1,p2,result), compat seed,result => cat 1. }
        If ArgCnt >= 4 Then Begin
          SIdx := AstTable[ArgList[3]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[3]].Text, SK_NONE);
          CodegenExprEAX(ArgList[2]); BinEmit8($50); { p2 }
          CodegenExprEAX(ArgList[1]); BinEmit8($50); { p1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rantbl');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          BinEmit8($6A); BinEmit8($00);              { p2=0 }
          BinEmit8($6A); BinEmit8($01);              { p1=1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rantbl');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANTRI' Then Begin
        { CALL RANTRI(seed,h,result), compat seed,result => h=1. }
        If ArgCnt >= 3 Then Begin
          SIdx := AstTable[ArgList[2]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[2]].Text, SK_NONE);
          CodegenExprEAX(ArgList[1]); BinEmit8($50); { h }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rantri');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End Else If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          BinEmit8($6A); BinEmit8($01);              { h=1 }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { seed }
          BinCallLabel('_SASRT_rantri');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RANUNI' Then Begin
        { CALL RANUNI(seed,result) -- meme runtime que RANUNI(seed). }
        If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          CodegenExprEAX(ArgList[0]); BinEmit8($50);
          BinCallLabel('_SASRT_ranuni');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'EXECUTE' Then Begin
        { CALL EXECUTE(code): journalise le code SAS mis en file. }
        If ArgCnt >= 1 Then Begin
          LblStr := EmitRDataStr('EXECUTE: ');
          BinPushLabel(LblStr);
          BinCallLabel('_SASRT_write_str');
          CodegenExprEAX(ArgList[0]);
          BinEmit8($50);
          BinCallLabel('_SASRT_write_str');
          BinCallLabel('_SASRT_newline');
        End;
      End Else If (FName = 'MODULE') Or (FName = 'MODULEI') Then Begin
        { CALL MODULE(routine,result): statut local = longueur du nom routine. }
        If ArgCnt >= 2 Then Begin
          SIdx := AstTable[ArgList[1]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[1]].Text, SK_NONE);
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { arg = routine }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { routine }
          BinCallLabel('_SASRT_modulen');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RXCHANGE' Then Begin
        { CALL RXCHANGE(rx,n,src,from,to,dst): remplacement texte simple. }
        If ArgCnt >= 6 Then Begin
          SIdx := AstTable[ArgList[5]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[5]].Text, SK_NONE);
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            CodegenExprEAX(ArgList[4]); BinEmit8($50); { to }
            CodegenExprEAX(ArgList[3]); BinEmit8($50); { from }
            CodegenExprEAX(ArgList[2]); BinEmit8($50); { src }
            BinCallLabel('_SASRT_tranwrd');            { EAX = replaced ptr }
            BinEmit8($50);                             { push src result }
            BinMovEaxLabelAddr(SymTable[SIdx].AsmName);
            BinEmit8($50);                             { push dst }
            BinCallLabel('_SASRT_strcpy');
          End;
        End;
      End Else If FName = 'RXFREE' Then Begin
        { CALL RXFREE(rx): invalide l identificateur regex local. }
        If ArgCnt >= 1 Then Begin
          SIdx := AstTable[ArgList[0]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[0]].Text, SK_NONE);
          BinEmit8($31); BinEmit8($C0);   { xor eax,eax }
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'RXSUBSTR' Then Begin
        { CALL RXSUBSTR(rx,src,pos,len): selectionne la chaine source entiere. }
        If ArgCnt >= 4 Then Begin
          SIdx := AstTable[ArgList[2]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[2]].Text, SK_NONE);
          BinEmit8($B8); BinEmit32(1);   { pos = 1 }
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
          SIdx := AstTable[ArgList[3]].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[3]].Text, SK_NONE);
          CodegenExprEAX(ArgList[1]);
          BinEmit8($50);
          BinCallLabel('_SASRT_length');
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
        End;
      End Else If FName = 'SET' Then Begin
        { CALL SET(dst,value): affecte vraiment la variable cible locale. }
        If ArgCnt >= 2 Then Begin
          SIdx := -1;
          If AstTable[ArgList[0]].Kind = NK_VAR Then Begin
            SIdx := AstTable[ArgList[0]].SymRef;
            If SIdx < 0 Then SIdx := FindSym(AstTable[ArgList[0]].Text, SK_NONE);
          End Else If (AstTable[ArgList[0]].Kind = NK_LITERAL) And
                      AstTable[ArgList[0]].IsChar Then
            SIdx := FindSym(UpperStr(AstTable[ArgList[0]].Text), SK_NONE);
          If SIdx >= 0 Then Begin
            If SymTable[SIdx].IsChar Then Begin
              CodegenExprEAX(ArgList[1]); BinEmit8($50); { src }
              BinMovEaxLabelAddr(SymTable[SIdx].AsmName);
              BinEmit8($50);                             { dst }
              BinCallLabel('_SASRT_strcpy');
            End Else Begin
              CodegenExprEAX(ArgList[1]);
              BinStoreEaxMem(SymTable[SIdx].AsmName);
            End;
          End;
        End;
      End Else If FName = 'SYMPUT' Then Begin
        { CALL SYMPUT(name,value): ecrit une macro-variable runtime lisible par SYMGET. }
        If ArgCnt >= 2 Then Begin
          If ExprIsChar(ArgList[1]) Then Begin
            CodegenExprEAX(ArgList[1]);
          End Else Begin
            LblStr := EmitRDataStr('');
            BinPushLabel(LblStr);             { fmt ignore par PUTN }
            CodegenExprEAX(ArgList[1]); BinEmit8($50);
            BinCallLabel('_SASRT_putn');      { EAX = valeur numerique en texte }
          End;
          BinEmit8($50);                      { value }
          CodegenExprEAX(ArgList[0]); BinEmit8($50); { name }
          BinCallLabel('_SASRT_symput');
        End;
      End Else Begin
        { LABEL,    }
        { CALL non pris en charge : evaluer et ignorer args }
        For I := 0 To ArgCnt - 1 Do
          CodegenExprEAX(ArgList[I]);
      End;
    End;

    { --- Statements DATA step ------------------------------------------- }

    NK_GOTO: Begin
      { NK_GOTO avec IsChar=True : definition d'etiquette (label:)  }
      { NK_GOTO avec IsChar=False : saut vers etiquette (GOTO name) }
      If AstTable[Node].IsChar Then
        BinDefineLabel('_SAL_' + AstTable[Node].Text)
      Else
        BinJmpLabel('_SAL_' + AstTable[Node].Text);
    End;

    NK_STOP: Begin
      { Sauter a la fin du DATA step courant si le label est connu }
      If CurDsEndLabel <> '' Then
        BinJmpLabel(CurDsEndLabel);
    End;

    NK_RETAIN: Begin
      { Initialisation numerique : MOV EAX, NumVal -> stocker en memoire }
      { Seules les initialisations non nulles necessitent du code.        }
      SIdx := AstTable[Node].SymRef;
      If (SIdx >= 0) And (AstTable[Node].NumVal <> 0) Then Begin
        BinEmit8($B8); BinEmit32(AstTable[Node].NumVal);
        BinStoreEaxMem(SymTable[SIdx].AsmName);
      End;
    End;

    NK_LEAVE: Begin
      { Sortir de la boucle la plus proche }
      If LoopTop > 0 Then
        BinJmpLabel(LoopStack[LoopTop - 1].LblEnd);
    End;

    NK_CONTINUE: Begin
      { Passer a l'iteration suivante de la boucle la plus proche }
      If LoopTop > 0 Then
        BinJmpLabel(LoopStack[LoopTop - 1].LblNext);
    End;

    NK_SET: Begin
      { SET _NULL_ (ou dataset vide) avec END=var : marquer fin immediate }
      { Sinon : no-op (lecture de dataset non implementee)               }
      SIdx := AstTable[Node].SymRef;
      If (SIdx < 0) And (AstTable[Node].Left >= 0) Then Begin
        SIdx := AstTable[AstTable[Node].Left].SymRef;
        If SIdx < 0 Then SIdx := FindSym(AstTable[AstTable[Node].Left].Text, SK_NONE);
      End;
      If SIdx >= 0 Then Begin
        { END=var specifie : mettre a 1 (EOF atteint immediatement) }
        BinEmit8($B8); BinEmit32(1);
        BinStoreEaxMem(SymTable[SIdx].AsmName);
      End;
    End;

    NK_OUTPUT,
    NK_DELETE,
    NK_BY,
    NK_MERGE: Begin
      { No-op : non implemente sans E/S de dataset }
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
  ColInfo  : LongInt;
  ColStart : Integer;
  ColEnd   : Integer;
  K        : Integer;
  J        : Integer;
  Dlm      : Char;
  FName    : String;
  TF       : Text;
  LineNum  : Integer;
  FirstObs : Integer;
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
        SIdx := AstTable[VarN].SymRef;
        If SIdx < 0 Then SIdx := FindSym(AstTable[VarN].Text, SK_NONE);
        ColInfo := AstTable[VarN].NumVal;
        If ColInfo <> 0 Then Begin
          { Spec de colonnes col1-col2 : extraire la sous-chaine }
          ColStart := Integer(ColInfo SHR 16);
          ColEnd   := Integer(ColInfo And $FFFF);
          TokStr   := '';
          For K := ColStart To ColEnd Do
            If K <= Length(RawLine) Then TokStr := TokStr + RawLine[K];
          { Supprimer les espaces en debut et fin }
          Pos := 1;
          While (Pos <= Length(TokStr)) And (TokStr[Pos] <= ' ') Do Inc(Pos);
          TokStr := Copy(TokStr, Pos, Length(TokStr) - Pos + 1);
          K := Length(TokStr);
          While (K >= 1) And (TokStr[K] <= ' ') Do Dec(K);
          TokStr := Copy(TokStr, 1, K);
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            LblStr := EmitRDataStr(TokStr);
            BinPushLabel(LblStr);              { PUSH src (rdata)       }
            BinMovEaxLabelAddr(SymTable[SIdx].AsmName); { EAX = adr buf }
            BinEmit8($50);                     { PUSH dst               }
            BinCallLabel('_SASRT_strcpy');
          End Else Begin
            Sign := 1;
            Pos  := 1;
            If (Pos <= Length(TokStr)) And (TokStr[Pos] = '-') Then Begin
              Sign := -1; Inc(Pos);
            End;
            V := 0;
            While (Pos <= Length(TokStr)) And (TokStr[Pos] >= '0') And
                  (TokStr[Pos] <= '9') Do Begin
              V := V * 10 + Ord(TokStr[Pos]) - Ord('0'); Inc(Pos);
            End;
            V := V * Sign;
            BinEmit8($B8); BinEmit32(V);
            If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
          End;
        End Else If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
          { Variable chaine : extraire le token jusqu a l espace }
          While (Pos <= Length(RawLine)) And (RawLine[Pos] <= ' ') Do Inc(Pos);
          TokStr := '';
          While (Pos <= Length(RawLine)) And (RawLine[Pos] > ' ') Do Begin
            TokStr := TokStr + RawLine[Pos]; Inc(Pos);
          End;
          LblStr := EmitRDataStr(TokStr);
          BinPushLabel(LblStr);              { PUSH src (rdata)       }
          BinMovEaxLabelAddr(SymTable[SIdx].AsmName); { EAX = adr buf }
          BinEmit8($50);                     { PUSH dst               }
          BinCallLabel('_SASRT_strcpy');
        End Else Begin
          { Variable numerique : extraire entier signe (delimite par espace) }
          While (Pos <= Length(RawLine)) And (RawLine[Pos] <= ' ') Do Inc(Pos);
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
          BinEmit8($B8); BinEmit32(V);
          If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
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
  End Else If (InfileN >= 0) And
              (AstTable[InfileN].Text <> 'CARDS') And
              (AstTable[InfileN].Text <> 'DATALINES') And
              (InputN >= 0) Then Begin
    { INFILE fichier externe : lecture compile-time avec dlm et firstobs }
    Dlm := ' ';
    If (AstTable[InfileN].Left >= 0) And
       (Length(AstTable[AstTable[InfileN].Left].Text) >= 1) Then
      Dlm := AstTable[AstTable[InfileN].Left].Text[1];
    FirstObs := AstTable[InfileN].NumVal;
    If FirstObs < 1 Then FirstObs := 1;
    FName := AstTable[InfileN].Text;
    Assign(TF, FName);
    {$I-}
    Reset(TF);
    {$I+}
    If IOResult <> 0 Then
      WriteLn('SASCW32: INFILE: fichier introuvable : ', FName)
    Else Begin
      LineNum := 0;
      While Not Eof(TF) Do Begin
        ReadLn(TF, RawLine);
        Inc(LineNum);
        If LineNum < FirstObs Then Continue;
        Pos  := 1;
        VarN := AstTable[InputN].FirstChild;
        While VarN >= 0 Do Begin
          SIdx := AstTable[VarN].SymRef;
          If SIdx < 0 Then SIdx := FindSym(AstTable[VarN].Text, SK_NONE);
          TokStr := '';
          If Dlm = ' ' Then Begin
            { Delimiteur espace : sauter puis lire }
            While (Pos <= Length(RawLine)) And (RawLine[Pos] <= ' ') Do Inc(Pos);
            While (Pos <= Length(RawLine)) And (RawLine[Pos] > ' ') Do Begin
              TokStr := TokStr + RawLine[Pos]; Inc(Pos);
            End;
          End Else Begin
            { Delimiteur specifique : lire jusqu au dlm puis avancer }
            While (Pos <= Length(RawLine)) And (RawLine[Pos] <> Dlm) Do Begin
              TokStr := TokStr + RawLine[Pos]; Inc(Pos);
            End;
            If (Pos <= Length(RawLine)) And (RawLine[Pos] = Dlm) Then Inc(Pos);
            { Trim espaces en debut }
            J := 1;
            While (J <= Length(TokStr)) And (TokStr[J] <= ' ') Do Inc(J);
            TokStr := Copy(TokStr, J, Length(TokStr) - J + 1);
            { Trim espaces en fin }
            J := Length(TokStr);
            While (J >= 1) And (TokStr[J] <= ' ') Do Dec(J);
            TokStr := Copy(TokStr, 1, J);
          End;
          If (SIdx >= 0) And SymTable[SIdx].IsChar Then Begin
            LblStr := EmitRDataStr(TokStr);
            BinPushLabel(LblStr);
            BinMovEaxLabelAddr(SymTable[SIdx].AsmName);
            BinEmit8($50);
            BinCallLabel('_SASRT_strcpy');
          End Else Begin
            { Analyser TokStr comme entier signe — utilise J (pas Pos) }
            Sign := 1; J := 1;
            If (J <= Length(TokStr)) And (TokStr[J] = '-') Then Begin
              Sign := -1; Inc(J);
            End;
            V := 0;
            While (J <= Length(TokStr)) And (TokStr[J] >= '0') And
                  (TokStr[J] <= '9') Do Begin
              V := V * 10 + Ord(TokStr[J]) - Ord('0'); Inc(J);
            End;
            V := V * Sign;
            BinEmit8($B8); BinEmit32(V);
            If SIdx >= 0 Then BinStoreEaxMem(SymTable[SIdx].AsmName);
          End;
          VarN := AstTable[VarN].NextSibling;
        End;
        { Emettre le corps du DATA step pour cet enregistrement }
        Child := AstTable[DsNode].FirstChild;
        While Child >= 0 Do Begin
          Case AstTable[Child].Kind Of
            NK_INFILE, NK_INPUT, NK_FILE, NK_CARDS, NK_ARRAY_DEF: ;
          Else
            CodegenStmt(Child);
          End;
          Child := AstTable[Child].NextSibling;
        End;
      End;
      Close(TF);
    End;
  End Else Begin
    { Pass 2 normal : emettre le code de chaque statement }
    Inc(BinPLKCount);
    CurDsEndLabel := '_dse' + IntToStr(BinPLKCount);
    Child := AstTable[DsNode].FirstChild;
    While Child >= 0 Do Begin
      CodegenStmt(Child);
      Child := AstTable[Child].NextSibling;
    End;
    BinDefineLabel(CurDsEndLabel);
    CurDsEndLabel := '';
  End;
End;

{ ============================================================ }
{ TODO 25 — Generation de code PE/COFF/ASM                     }
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
{ TODO 25 — WriteCOFF : description objet COFF                  }
{ ============================================================ }
Procedure WriteCOFF(Const FileName: String);
Var F: Text;
Begin
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Begin
    CompileError('impossible de creer: ' + FileName); Exit;
  End;
  WriteLn(F, 'SASCW32 COFF object description');
  WriteLn(F, 'machine=i386');
  WriteLn(F, 'text_size=', BinCodeSize);
  WriteLn(F, 'data_size=', BinDataSize);
  WriteLn(F, 'rdata_size=', BinRDataSize);
  WriteLn(F, 'imports=', ImportCount);
  WriteLn(F, 'labels=', LabelCount);
  Close(F);
End;

{ ============================================================ }
{ TODO 25 — WriteASM : listing MASM des octets generes          }
{ ============================================================ }
Procedure WriteASM(Const FileName: String);
Var
  F: Text;
  I: Integer;
  Function HexByte(B: Byte): String;
  Const H: String[16] = '0123456789ABCDEF';
  Begin
    HexByte := H[(B Shr 4) + 1] + H[(B And $0F) + 1];
  End;
Begin
  Assign(F, FileName);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then Begin
    CompileError('impossible de creer: ' + FileName); Exit;
  End;
  WriteLn(F, '.386');
  WriteLn(F, '.MODEL FLAT, STDCALL');
  WriteLn(F, 'OPTION CASEMAP:NONE');
  WriteLn(F, '.CODE');
  WriteLn(F, '_SASSTART PROC');
  I := 0;
  While I < BinCodeSize Do Begin
    Write(F, '  DB ');
    Write(F, '$', HexByte(BinCode[I]));
    Inc(I);
    While (I < BinCodeSize) And ((I Mod 16) <> 0) Do Begin
      Write(F, ',$', HexByte(BinCode[I]));
      Inc(I);
    End;
    WriteLn(F);
  End;
  WriteLn(F, '_SASSTART ENDP');
  WriteLn(F, 'END _SASSTART');
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
  BinAddImport('kernel32.dll', '_WinExec@8');
  BinAddImport('kernel32.dll', '_GetFileAttributesA@4');
  BinAddImport('kernel32.dll', '_GetEnvironmentVariableA@12');
  BinAddImport('kernel32.dll', '_GetLocalTime@4');
  BinAddImport('kernel32.dll', '_DeleteFileA@4');
  BinAddImport('kernel32.dll', '_CreateFileA@28');
  BinAddImport('kernel32.dll', '_CloseHandle@4');
  BinAddImport('kernel32.dll', '_SetFilePointer@16');
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

{ MOV EAX, imm32(addr) : charge l adresse (VA) d un label.   }
{ Utilise un fixup ABS32 — different de BinMovEaxMem qui lit  }
{ le contenu memoire ([abs32]).                                }
Procedure BinMovEaxLabelAddr(Const LblName: String);
Begin
  BinEmit8($B8);
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
  { 57 octets : stdcall, ret 4 ; ptr NULL -> rien ecrire        }
  BinDefineLabel('_SASRT_write_str');
  BinEmit8($55);             { push ebp                        }
  BinEmit8($89); BinEmit8($E5);  { mov ebp, esp               }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04); { sub esp, 4   }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08); { mov esi,[ebp+8] }
  BinEmit8($85); BinEmit8($F6); { test esi, esi               }
  BinEmit8($74); BinEmit8($26); { jz null_skip (+38 = skip)   }
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
      LN := '_sas_v_' + IntToStr(SymTable[I].DsIdx) + '_' + SymTable[I].Name;
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
  { Buffer temporaire partage pour les fonctions chaines }
  BinDefineDataLabel('_sas_strtmp');
  For J := 1 To 256 Do BinEmitDataByte(0);
  { Buffer pour la concatenation || (deux buffers de 256) }
  BinDefineDataLabel('_sas_concat_buf');
  For J := 1 To 512 Do BinEmitDataByte(0);
  { Buffer pour COMPBL / COLLATE }
  BinDefineDataLabel('_sas_compbl_buf');
  For J := 1 To 256 Do BinEmitDataByte(0);
  { Stockage runtime minimal CALL SYMPUT / SYMGET : 1 nom + 1 valeur }
  BinDefineDataLabel('_sas_sym_name');
  For J := 1 To 32 Do BinEmitDataByte(0);
  BinDefineDataLabel('_sas_sym_value');
  For J := 1 To 256 Do BinEmitDataByte(0);
  { Buffer SYSTEMTIME pour GetLocalTime (16 octets: 8 WORDs) }
  BinDefineDataLabel('_sas_systime');
  For J := 1 To 16 Do BinEmitDataByte(0);
  { Buffer decomposition date YMD pour _SASRT_ymd_calc (12 octets: year,month,day) }
  BinDefineDataLabel('_sas_ymd');
  For J := 1 To 12 Do BinEmitDataByte(0);
  { Chaine vide partagee pour les fonctions qui n ont aucune valeur texte disponible }
  BinDefineDataLabel('_sas_empty');
  BinEmitDataByte(0);
  { Slot lag unique pour _SASRT_lag(x) : valeur precedente (4 octets) }
  BinDefineDataLabel('_sas_lag_buf');
  For J := 1 To 4 Do BinEmitDataByte(0);
  { Slot dif unique pour _SASRT_dif(x,n) : valeur precedente (4 octets) }
  BinDefineDataLabel('_sas_dif_buf');
  For J := 1 To 4 Do BinEmitDataByte(0);
  { Table file-descriptors SAS : 16 entrees max }
  { _sas_fid_h[i]   : HANDLE Win32 (-1=libre)   }
  { _sas_fid_sep[i] : separateur FGET (defaut espace) }
  { _sas_fid_wl[i]  : longueur buffer ecriture  }
  { _sas_fid_rp[i]  : position lecture courante }
  { _sas_fid_rb     : 16x256 octets lecture     }
  { _sas_fid_wb     : 16x256 octets ecriture    }
  BinDefineDataLabel('_sas_fid_h');
  For J := 1 To 64 Do BinEmitDataByte($FF);
  BinDefineDataLabel('_sas_fid_sep');
  For J := 1 To 16 Do BinEmitDataByte($20);
  BinDefineDataLabel('_sas_fid_wl');
  For J := 1 To 64 Do BinEmitDataByte(0);
  BinDefineDataLabel('_sas_fid_rp');
  For J := 1 To 64 Do BinEmitDataByte(0);
  BinDefineDataLabel('_sas_fid_rb');
  For J := 1 To 4096 Do BinEmitDataByte(0);
  BinDefineDataLabel('_sas_fid_wb');
  For J := 1 To 4096 Do BinEmitDataByte(0);
  { Constante Euler-Mascheroni gamma = 0.5772156649015329 (IEEE 754 double LE) }
  BinDefineDataLabel('_sas_euler');
  BinEmitDataByte($19); BinEmitDataByte($B6); BinEmitDataByte($6F); BinEmitDataByte($FC);
  BinEmitDataByte($8C); BinEmitDataByte($78); BinEmitDataByte($E2); BinEmitDataByte($3F);
  { c1=Ai(0)=0.3550280538878172929 (IEEE 754 LE) }
  BinDefineDataLabel('_sas_airyc1');
  BinEmitDataByte($B9); BinEmitDataByte($15); BinEmitDataByte($27); BinEmitDataByte($96);
  BinEmitDataByte($C7); BinEmitDataByte($B8); BinEmitDataByte($D6); BinEmitDataByte($3F);
  { c2=-Ai'(0)=0.2588194037928067846 (IEEE 754 LE) }
  BinDefineDataLabel('_sas_airyc2');
  BinEmitDataByte($8A); BinEmitDataByte($0F); BinEmitDataByte($B7); BinEmitDataByte($42);
  BinEmitDataByte($7F); BinEmitDataByte($90); BinEmitDataByte($D0); BinEmitDataByte($3F);
  { c1/2=0.177514026943909 (IEEE 754 LE, pour DAIRY) }
  BinDefineDataLabel('_sas_airyd1h');
  BinEmitDataByte($B9); BinEmitDataByte($15); BinEmitDataByte($27); BinEmitDataByte($96);
  BinEmitDataByte($C7); BinEmitDataByte($B8); BinEmitDataByte($C6); BinEmitDataByte($3F);
  { _sas_lcg_max = 2147483647 = 0x7FFFFFFF (dword signe, diviseur LCG) }
  BinDefineDataLabel('_sas_lcg_max');
  BinEmitDataByte($FF); BinEmitDataByte($FF); BinEmitDataByte($FF); BinEmitDataByte($7F);
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
  { FILD dword: DB /0 → ModRM(mod=01,reg=0,rm=5)=$45      }
  { FISTP dword: DB /3 → ModRM(mod=01,reg=3,rm=5)=$5D     }
  BinDefineLabel('_SASRT_sqrt');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04); { sub esp,4  (local dword) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08); { mov eax,[ebp+8] }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC); { mov [ebp-4],eax }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC); { fild dword [ebp-4] }
  BinEmit8($D9); BinEmit8($FA);               { fsqrt }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC); { fistp dword [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC); { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);               { mov esp,ebp }
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_log(x): LongInt --- ln(x) via x87 FLDLN2+FYL2X (35 octets) }
  { Si x<=0 retourne 0. Sinon: ln(x) = log2(x)*ln(2) = FYL2X(ln2,x).    }
  BinDefineLabel('_SASRT_log');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);                { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);                { sub esp,4 }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp dword [ebp+8],0 }
  BinEmit8($7E); BinEmit8($0F);                                { jle .zero (disp=15) }
  BinEmit8($D9); BinEmit8($ED);                                { fldln2 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                { fild dword [ebp+8] }
  BinEmit8($D9); BinEmit8($F1);                                { fyl2x → ST0=ln(x) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);                { fistp dword [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);                { mov eax,[ebp-4] }
  BinEmit8($EB); BinEmit8($02);                                { jmp .done (disp=2) }
  BinEmit8($31); BinEmit8($C0);                                { .zero: xor eax,eax }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);                { .done: mov esp,ebp; pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_exp(x): LongInt --- e^x via x87 F2XM1+FSCALE (43 octets) }
  { Algorithme: y=x*log2(e); e^x = 2^frac(y) * 2^int(y).                }
  BinDefineLabel('_SASRT_exp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);                { sub esp,4 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                { fild [ebp+8] }
  BinEmit8($D9); BinEmit8($EA);                                { fldl2e }
  BinEmit8($DE); BinEmit8($C9);                                { fmulp st(1),st(0) → y=x*log2e }
  BinEmit8($D9); BinEmit8($C0);                                { fld st(0) → y,y }
  BinEmit8($D9); BinEmit8($FC);                                { frndint → int(y),y }
  BinEmit8($D9); BinEmit8($C9);                                { fxch → y,int(y) }
  BinEmit8($D8); BinEmit8($E1);                                { fsub st(0),st(1) → frac,int }
  BinEmit8($D9); BinEmit8($F0);                                { f2xm1 → 2^frac-1,int }
  BinEmit8($D9); BinEmit8($E8);                                { fld1 }
  BinEmit8($DE); BinEmit8($C1);                                { faddp st(1) → 2^frac,int }
  BinEmit8($D9); BinEmit8($FD);                                { fscale → e^x,int }
  BinEmit8($DD); BinEmit8($D9);                                { fstp st(1) → ST0=e^x }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);                { fistp [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);                { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_sum(x): fallback runtime 1 arg ; les appels SUM variadiques sont inline }
  BinDefineLabel('_SASRT_sum');
  BinEmit8($55);
  BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { Helpers partages : retournent _sas_empty (0 args/1 arg/2 args)          }
  { Utilise pour les fonctions texte sans valeur disponible dans ce backend. }
  BinDefineLabel('_sas_retempty0');                 { 0 args, ret (C3) }
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinMovRegLabel(0,'_sas_empty');                   { mov eax,_sas_empty }
  BinEmit8($5D); BinEmit8($C3);                    { pop ebp; ret }

  BinDefineLabel('_sas_retempty1');                 { 1 arg, ret 4 }
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinMovRegLabel(0,'_sas_empty');                   { mov eax,_sas_empty }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  BinDefineLabel('_sas_retempty2');                 { 2 args, ret 8 }
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinMovRegLabel(0,'_sas_empty');                   { mov eax,_sas_empty }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

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

  { --- _SASRT_arcos(x): LongInt --- arccos(x) via x87 FPATAN (35 octets) }
  { arccos(x) = atan(sqrt(1-x^2)/x) : FPATAN(ST1=sqrt(1-x^2), ST0=x).   }
  BinDefineLabel('_SASRT_arcos');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] → ST0=x }
  BinEmit8($D9); BinEmit8($C0);                  { fld st(0)  → x,x }
  BinEmit8($D8); BinEmit8($C8);                  { fmul st(0),st(0) → x^2,x }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → 1,x^2,x }
  BinEmit8($DE); BinEmit8($E1);                  { fsubrp st(1) → ST1=1-x^2, pop. ST0=1-x^2 }
  BinEmit8($D9); BinEmit8($FA);                  { fsqrt → sqrt(1-x^2),x }
  BinEmit8($D9); BinEmit8($C9);                  { fxch → x,sqrt(1-x^2) }
  BinEmit8($D9); BinEmit8($F3);                  { fpatan → atan(sqrt(1-x^2)/x)=arccos }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_arsin(x): LongInt --- arcsin(x) via x87 FPATAN (33 octets) }
  { arcsin(x) = atan(x/sqrt(1-x^2)) : FPATAN(ST1=x, ST0=sqrt(1-x^2)).   }
  BinDefineLabel('_SASRT_arsin');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] → ST0=x }
  BinEmit8($D9); BinEmit8($C0);                  { fld st(0) → x,x }
  BinEmit8($D8); BinEmit8($C8);                  { fmul st(0),st(0) → x^2,x }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → 1,x^2,x }
  BinEmit8($DE); BinEmit8($E1);                  { fsubrp st(1) → ST1=1-x^2, pop. ST0=1-x^2 }
  BinEmit8($D9); BinEmit8($FA);                  { fsqrt → sqrt(1-x^2),x }
  BinEmit8($D9); BinEmit8($F3);                  { fpatan → atan(x/sqrt(1-x^2)) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_atan(x): LongInt --- arctan(x) via x87 FPATAN (25 octets) }
  { atan(x) = atan(x/1) : FPATAN(ST1=x, ST0=1).                          }
  BinDefineLabel('_SASRT_atan');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] → ST0=x }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → ST0=1,ST1=x }
  BinEmit8($D9); BinEmit8($F3);                  { fpatan → atan(x/1) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_atan2(y,x): LongInt --- atan2(y,x) via x87 FPATAN (26 octets) }
  { [ebp+8]=y [ebp+12]=x. atan(y/x) : FPATAN(ST1=y, ST0=x).             }
  BinDefineLabel('_SASRT_atan2');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8]=y → ST0=y }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);  { fild [ebp+12]=x → ST0=x,ST1=y }
  BinEmit8($D9); BinEmit8($F3);                  { fpatan → atan(y/x) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_airy(x): floor(Ai(x)), series Ai=c1*sf-c2*x*sg, 30 iter (1 arg) }
  { [ebp+8]=x. sub esp,56: [ebp-4]=res [ebp-8/-6]=CW [ebp-16]=denom        }
  { [ebp-24]=x3 [ebp-32]=term_f [ebp-40]=term_g [ebp-48]=sf [ebp-56]=sg    }
  BinDefineLabel('_SASRT_airy');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);                   { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($38);                   { sub esp,56 }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);                   { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);    { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF); { and eax,~0xC00 }
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00); { or eax,0x400 floor }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);    { mov [ebp-6],ax }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                   { fild [ebp+8] x }
  BinEmit8($D9); BinEmit8($C0);                                  { fld st(0) }
  BinEmit8($D8); BinEmit8($C8);                                  { fmul st(0),st(0) x^2 }
  BinEmit8($DE); BinEmit8($C9);                                  { fmulp st(1),st x^3 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);                   { fstp [ebp-24] }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($E0); { fld1;fstp term_f }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($D8); { fld1;fstp term_g }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($D0); { fld1;fstp sf }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($C8); { fld1;fstp sg }
  BinEmit8($B9); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,1 }
  BinDefineLabel('_airy_loop');
  BinEmit8($8D); BinEmit8($04); BinEmit8($49);                   { lea eax,[ecx+ecx*2] 3k }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16],eax }
  BinEmit8($48);                                                  { dec eax 3k-1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($F0);    { imul eax,[ebp-16] }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16] (3k-1)*3k }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);                   { fld term_f }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($E8);                   { fmul [ebp-24] *x3 }
  BinEmit8($DA); BinEmit8($75); BinEmit8($F0);                   { fidiv [ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);                   { fstp term_f }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D0);                   { fld sf }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E0);                   { fadd term_f }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D0);                   { fstp sf }
  BinEmit8($8D); BinEmit8($04); BinEmit8($49);                   { lea eax,[ecx+ecx*2] 3k }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16],eax }
  BinEmit8($40);                                                  { inc eax 3k+1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($F0);    { imul eax,[ebp-16] }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16] 3k*(3k+1) }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);                   { fld term_g }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($E8);                   { fmul [ebp-24] *x3 }
  BinEmit8($DA); BinEmit8($75); BinEmit8($F0);                   { fidiv [ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);                   { fstp term_g }
  BinEmit8($DD); BinEmit8($45); BinEmit8($C8);                   { fld sg }
  BinEmit8($DC); BinEmit8($45); BinEmit8($D8);                   { fadd term_g }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($C8);                   { fstp sg }
  BinEmit8($41);                                                  { inc ecx }
  BinEmit8($83); BinEmit8($F9); BinEmit8($1F);                   { cmp ecx,31 }
  BinJccLabel(12,'_airy_loop');                                   { jl }
  BinMovRegLabel(0,'_sas_airyc1');                                { mov eax,&c1 }
  BinEmit8($DD); BinEmit8($00);                                   { fld qword[eax] }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D0);                   { fmul sf }
  BinMovRegLabel(0,'_sas_airyc2');                                { mov eax,&c2 }
  BinEmit8($DD); BinEmit8($00);                                   { fld qword[eax] }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                   { fild [ebp+8] x }
  BinEmit8($DE); BinEmit8($C9);                                   { fmulp st(1),st c2*x }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($C8);                   { fmul sg c2*x*sg }
  BinEmit8($DE); BinEmit8($E9);                                   { fsubp st(1),st Ai(x) }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);                   { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);                   { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);                   { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);                   { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_betainv(p,a,b): quantile beta borne pour backend entier }
  BinDefineLabel('_SASRT_betainv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] p }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp a,0 }
  BinJccLabel(14, '_betainv_zero');                      { jle zero }
  BinEmit8($83); BinEmit8($7D); BinEmit8($10); BinEmit8($00); { cmp b,0 }
  BinJccLabel(14, '_betainv_zero');                      { jle zero }
  BinEmit8($85); BinEmit8($C0);                           { test eax,eax }
  BinJccLabel(14, '_betainv_zero');                      { jle zero }
  BinEmit8($83); BinEmit8($F8); BinEmit8($01);            { cmp eax,1 }
  BinJccLabel(13, '_betainv_one');                       { jge one }
  BinEmit8($31); BinEmit8($C0);                           { fallback: 0 }
  BinJmpLabel('_betainv_done');
  BinDefineLabel('_betainv_one');
  BinEmit8($B8); BinEmit32(1);                            { mov eax,1 }
  BinJmpLabel('_betainv_done');
  BinDefineLabel('_betainv_zero');
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  BinDefineLabel('_betainv_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_byte(n): LongInt = n (code ASCII, 1 arg) }
  BinDefineLabel('_SASRT_byte');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_attrc(dsid,attr): retourne quelques attributs texte courants }
  BinDefineLabel('_SASRT_attrc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($57);                                { push edi }
  BinEmit8($52);                                { push edx }
  BinMovRegLabel(7, '_sas_strtmp');             { mov edi,_sas_strtmp }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte [edi],0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($C0);                 { test eax,eax }
  BinJccLabel(14, '_attrc_done');               { jle done }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);  { mov edx,[ebp+12] attr }
  BinEmit8($8A); BinEmit8($02);                 { mov al,[edx] }
  BinEmit8($24); BinEmit8($DF);                 { and al,0DFh }
  BinEmit8($3C); BinEmit8(Ord('T'));            { cmp al,'T' }
  BinJccLabel(4, '_attrc_type');                { je type }
  BinEmit8($3C); BinEmit8(Ord('M'));            { cmp al,'M' }
  BinJccLabel(4, '_attrc_type');                { je memtype }
  BinEmit8($3C); BinEmit8(Ord('E'));            { cmp al,'E' }
  BinJccLabel(4, '_attrc_engine');              { je engine }
  BinEmit8($3C); BinEmit8(Ord('L'));            { cmp al,'L' }
  BinJccLabel(4, '_attrc_lib');                 { je lib/libname }
  BinJmpLabel('_attrc_done');
  BinDefineLabel('_attrc_type');
  BinEmit8($C7); BinEmit8($07); BinEmit32($41544144); { "DATA" }
  BinEmit8($C6); BinEmit8($47); BinEmit8($04); BinEmit8($00);
  BinJmpLabel('_attrc_done');
  BinDefineLabel('_attrc_engine');
  BinEmit8($C7); BinEmit8($07); BinEmit32($45534142); { "BASE" }
  BinEmit8($C6); BinEmit8($47); BinEmit8($04); BinEmit8($00);
  BinJmpLabel('_attrc_done');
  BinDefineLabel('_attrc_lib');
  BinEmit8($C7); BinEmit8($07); BinEmit32($4B524F57); { "WORK" }
  BinEmit8($C6); BinEmit8($47); BinEmit8($04); BinEmit8($00);
  BinDefineLabel('_attrc_done');
  BinMovRegLabel(0, '_sas_strtmp');             { mov eax,_sas_strtmp }
  BinEmit8($5A);                                { pop edx }
  BinEmit8($5F);                                { pop edi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_attrn(dsid,attr): retourne quelques attributs numeriques courants }
  BinDefineLabel('_SASRT_attrn');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                 { xor eax,eax }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);  { mov edx,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($D2);                 { test edx,edx }
  BinJccLabel(14, '_attrn_done');               { jle done }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);  { mov edx,[ebp+12] attr }
  BinEmit8($8A); BinEmit8($0A);                 { mov cl,[edx] }
  BinEmit8($80); BinEmit8($E1); BinEmit8($DF);  { and cl,0DFh }
  BinEmit8($80); BinEmit8($F9); BinEmit8(Ord('N')); { cmp cl,'N' }
  BinJccLabel(5, '_attrn_done');                { jne done }
  BinEmit8($B8); BinEmit32(1);                  { mov eax,1 }
  BinDefineLabel('_attrn_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_cdf(dist,x): CDF normale entiere; dist=0/NORMAL supporte }
  { Backend entier: retourne 0 si x<=0, 1 si x>0, comme PROBNORM.       }
  BinDefineLabel('_SASRT_cdf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinEmit8($7E); BinEmit8($07);                          { jle zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinEmit8($EB); BinEmit8($02);                          { jmp done }
  BinEmit8($31); BinEmit8($C0);                          { zero: xor eax,eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_ceilz(x): LongInt = x (1 arg, entiers: identique a CEIL) }
  BinDefineLabel('_SASRT_ceilz');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_cexist(cat,type): 1 si le catalogue/chemin existe (2 args) }
  { Sans catalogue SAS natif, cat est interprete comme chemin filesystem.  }
  BinDefineLabel('_SASRT_cexist');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp cat,0 }
  BinEmit8($74); BinEmit8($10);                              { je zero }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);                { push cat }
  BinCallImport('_GetFileAttributesA@4');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);                { cmp eax,-1 }
  BinEmit8($0F); BinEmit8($95); BinEmit8($C0);                { setne al }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);                { movzx eax,al }
  BinEmit8($EB); BinEmit8($02);                              { jmp done }
  BinEmit8($31); BinEmit8($C0);                              { zero: xor eax,eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_cinv(p,df): quantile chi-carre approx entier (2 args) }
  { p est un pourcentage entier. Approx: df + z*sqrt(2*df), z=1/2/3. }
  BinDefineLabel('_SASRT_cinv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);                                      { push ebx }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);        { mov ebx,[ebp+12] df }
  BinEmit8($85); BinEmit8($DB);                       { test ebx,ebx }
  BinJccLabel(14, '_cinv_zero');                       { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);        { mov eax,[ebp+8] p }
  BinEmit8($85); BinEmit8($C0);                       { test eax,eax }
  BinJccLabel(14, '_cinv_zero');                       { jle zero }
  BinEmit8($31); BinEmit8($C9);                       { xor ecx,ecx z=0 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5A);        { cmp p,90 }
  BinJccLabel(12, '_cinv_calc');                       { jl calc }
  BinEmit8($B9); BinEmit32(1);                         { mov ecx,1 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5F);        { cmp p,95 }
  BinJccLabel(12, '_cinv_calc');                       { jl calc }
  BinEmit8($B9); BinEmit32(2);                         { mov ecx,2 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($63);        { cmp p,99 }
  BinJccLabel(12, '_cinv_calc');                       { jl calc }
  BinEmit8($B9); BinEmit32(3);                         { mov ecx,3 }
  BinDefineLabel('_cinv_calc');
  BinEmit8($89); BinEmit8($D8);                        { mov eax,ebx }
  BinEmit8($01); BinEmit8($C0);                        { add eax,eax = 2*df }
  BinEmit8($51);                                       { push ecx }
  BinEmit8($50);                                       { push 2*df }
  BinCallLabel('_SASRT_sqrt');                         { eax=sqrt(2*df) }
  BinEmit8($59);                                       { pop ecx }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);        { imul eax,ecx }
  BinEmit8($01); BinEmit8($D8);                        { add eax,ebx }
  BinJmpLabel('_cinv_done');
  BinDefineLabel('_cinv_zero');
  BinEmit8($31); BinEmit8($C0);                        { xor eax,eax }
  BinDefineLabel('_cinv_done');
  BinEmit8($5B);                                      { pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_close(dsid): LongInt status (0 si dsid valide, -1 sinon) }
  BinDefineLabel('_SASRT_close');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                 { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                                { test eax,eax }
  BinJccLabel(15, '_close_ok');                                { jg ok }
  BinEmit8($B8); BinEmit32(-1);                                { mov eax,-1 }
  BinJmpLabel('_close_done');
  BinDefineLabel('_close_ok');
  BinEmit8($31); BinEmit8($C0);                                { xor eax,eax }
  BinDefineLabel('_close_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_cnonct(x,df,p): non-centralite chi-carre approx (3 args) }
  { Retourne max(0, x - CINV(p,df)) pour le backend entier.              }
  BinDefineLabel('_SASRT_cnonct');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push df }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push p }
  BinCallLabel('_SASRT_cinv');                           { eax = quantile central }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] x }
  BinEmit8($29); BinEmit8($C1);                          { sub ecx,eax }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14, '_cnonct_zero');                       { jle zero }
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx }
  BinJmpLabel('_cnonct_done');
  BinDefineLabel('_cnonct_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_cnonct_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_comb(n,r): LongInt = C(n,r)                               }
  { push ebp; mov ebp,esp; push ebx; push esi; push edi                  }
  { mov edi,[ebp+8]=n ; mov esi,[ebp+12]=r                               }
  { jl/jg _zero(off66) ; jz _one(off75) ; optimize r ; loop             }
  BinDefineLabel('_SASRT_comb');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($53);                                     { push ebx              }
  BinEmit8($56);                                     { push esi              }
  BinEmit8($57);                                     { push edi              }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($08);     { mov edi,[ebp+8]  n    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);     { mov esi,[ebp+12] r    }
  BinEmit8($85); BinEmit8($F6);                     { test esi,esi          }
  BinEmit8($7C); BinEmit8($32);                     { jl _zero (+50→66)     }
  BinEmit8($3B); BinEmit8($F7);                     { cmp esi,edi           }
  BinEmit8($7F); BinEmit8($2E);                     { jg _zero (+46→66)     }
  BinEmit8($85); BinEmit8($F6);                     { test esi,esi          }
  BinEmit8($74); BinEmit8($33);                     { jz _one  (+51→75)     }
  BinEmit8($89); BinEmit8($F8);                     { mov eax,edi  (n-r)    }
  BinEmit8($29); BinEmit8($F0);                     { sub eax,esi           }
  BinEmit8($3B); BinEmit8($C6);                     { cmp eax,esi           }
  BinEmit8($7D); BinEmit8($02);                     { jge _noswap (+2→34)   }
  BinEmit8($89); BinEmit8($C6);                     { mov esi,eax  swap r   }
  { _noswap: offset 34 }
  BinEmit8($B8); BinEmit32(1);                      { mov eax,1  result     }
  BinEmit8($31); BinEmit8($C9);                     { xor ecx,ecx i=0      }
  { _loop: offset 41 }
  BinEmit8($41);                                     { inc ecx               }
  BinEmit8($3B); BinEmit8($CE);                     { cmp ecx,esi           }
  BinEmit8($7F); BinEmit8($0D);                     { jg _done (+13→59)     }
  BinEmit8($89); BinEmit8($FB);                     { mov ebx,edi           }
  BinEmit8($2B); BinEmit8($D9);                     { sub ebx,ecx           }
  BinEmit8($43);                                     { inc ebx               }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C3);     { imul eax,ebx          }
  BinEmit8($99);                                     { cdq                   }
  BinEmit8($F7); BinEmit8($F9);                     { idiv ecx              }
  BinEmit8($EB); BinEmit8($EE);                     { jmp _loop (-18→41)    }
  { _done: offset 59 }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);     { pop edi;esi;ebx       }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { pop ebp; ret 8 }
  { _zero: offset 66 }
  BinEmit8($31); BinEmit8($C0);                     { xor eax,eax           }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);     { pop edi;esi;ebx       }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { pop ebp; ret 8 }
  { _one: offset 75 }
  BinEmit8($B8); BinEmit32(1);                      { mov eax,1             }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);     { pop edi;esi;ebx       }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { pop ebp; ret 8 }

  { --- _SASRT_constant(name/code): LongInt --- valeur entiere constante math }
  { Codes 0=E,1=PI,2=SQRT2. Noms: E=2, PI=3, SQRT*=1, LOGPI/LOG2PI=1.       }
  BinDefineLabel('_SASRT_constant');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);           { mov edx,[ebp+8] name }
  BinEmit8($83); BinEmit8($FA); BinEmit8($10);           { cmp edx,16 }
  BinJccLabel(6, '_const_code');                         { jbe numeric code }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($02);           { movzx eax,byte[edx] }
  BinEmit8($24); BinEmit8($DF);                          { and al,0xDF uppercase }
  BinEmit8($3C); BinEmit8($45); BinJccLabel(5,'_const_ne'); { cmp 'E'; jne }
  BinEmit8($B8); BinEmit8($02); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,2 }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_ne');
  BinEmit8($3C); BinEmit8($50); BinJccLabel(5,'_const_np'); { cmp 'P'; jne }
  BinEmit8($B8); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,3 }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_np');
  BinEmit8($3C); BinEmit8($53); BinJccLabel(5,'_const_nl'); { cmp 'S'; jne }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_nl');
  BinEmit8($3C); BinEmit8($4C); BinJccLabel(5,'_const_zero'); { cmp 'L'; jne .zero }
  { 'L' = LOGPI(1), LOG2PI(1), LOG2E(1) mais LOG10E(0): verif 4e char }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($4A); BinEmit8($03); { movzx ecx,byte[edx+3] }
  BinEmit8($80); BinEmit8($F9); BinEmit8($31);           { cmp cl,'1' }
  BinJccLabel(4,'_const_zero');                           { je .zero (LOG10E=0) }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_const_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00); { pop ebp; ret 4 }
  BinDefineLabel('_const_code');
  BinEmit8($83); BinEmit8($FA); BinEmit8($00);            { cmp edx,0 }
  BinJccLabel(5, '_const_code_ne0');
  BinEmit8($B8); BinEmit32(2);                            { E }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_code_ne0');
  BinEmit8($83); BinEmit8($FA); BinEmit8($01);            { cmp edx,1 }
  BinJccLabel(5, '_const_code_ne1');
  BinEmit8($B8); BinEmit32(3);                            { PI }
  BinJmpLabel('_const_done');
  BinDefineLabel('_const_code_ne1');
  BinEmit8($83); BinEmit8($FA); BinEmit8($02);            { cmp edx,2 }
  BinJccLabel(5, '_const_zero');
  BinEmit8($B8); BinEmit32(1);                            { SQRT2 }
  BinJmpLabel('_const_done');

  { --- _SASRT_convx(n,y,c,par,red): v^2*sum(t*(t+1)*CF*v^t)/price (5 args) }
  { [ebp+8]=n [ebp+12]=y [ebp+16]=c [ebp+20]=par(unused) [ebp+24]=red     }
  { sub esp,40: [ebp-4]=t/tmp [ebp-8/-6]=CW [ebp-16]=cnx [ebp-24]=price   }
  {             [ebp-32]=disc [ebp-40]=v                                     }
  BinDefineLabel('_SASRT_convx');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($28);           { sub esp,40 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_cnx_done');                            { jle -> 0 }
  { v = 100/(100+y) }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild 100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild y }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 100+y }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild 100 }
  BinEmit8($DE); BinEmit8($F1);                          { fdivrp -> v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);           { fstp v=[ebp-40] }
  { disc=v, cnx_num=0, price=0, t=1 }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);           { fld v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp disc=[ebp-32] }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp price=[ebp-24] }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp cnx=[ebp-16] }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1);
  BinDefineLabel('_cnx_loop');
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild c }
  BinEmit8($83); BinEmit8($F9); BinEmit8($01);           { cmp ecx,1 }
  BinJccLabel(5,'_cnx_notlast');
  BinEmit8($DB); BinEmit8($45); BinEmit8($18);           { fild red }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> c+red }
  BinDefineLabel('_cnx_notlast');
  { ST0=CF; price += CF*disc }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld disc }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> CF*disc }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);           { fadd price }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp price }
  { cnx_num += t*(t+1)*CF*disc }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild t }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy t }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> t+1 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> t*(t+1) }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> t*(t+1)*CF*disc }
  BinEmit8($DC); BinEmit8($45); BinEmit8($F0);           { fadd cnx }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp cnx }
  { disc *= v }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld disc }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D8);           { fmul v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp disc }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc t }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_cnx_loop');
  { CONVX = v^2 * cnx / price }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);           { fld v }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) -> v^2 }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul cnx }
  BinEmit8($DC); BinEmit8($75); BinEmit8($E8);           { fdiv price }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_cnx_done');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_convxp(n,y,c,par,red): modified convexity = CONVX*v^2 (5 args) }
  { same loop as convx but multiplies v^2 one more time before fistp            }
  BinDefineLabel('_SASRT_convxp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($28);           { sub esp,40 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,n }
  BinEmit8($85); BinEmit8($C9);
  BinJccLabel(14,'_cnxp_done');
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);
  BinEmit8($DE); BinEmit8($C1);
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);
  BinEmit8($DE); BinEmit8($F1);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);
  BinEmit8($D9); BinEmit8($EE);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);
  BinEmit8($D9); BinEmit8($EE);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1);
  BinDefineLabel('_cnxp_loop');
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);
  BinEmit8($83); BinEmit8($F9); BinEmit8($01);
  BinJccLabel(5,'_cnxp_notlast');
  BinEmit8($DB); BinEmit8($45); BinEmit8($18);
  BinEmit8($DE); BinEmit8($C1);
  BinDefineLabel('_cnxp_notlast');
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);
  BinEmit8($DE); BinEmit8($C9);
  BinEmit8($D9); BinEmit8($C0);
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);
  BinEmit8($D9); BinEmit8($C0);
  BinEmit8($D9); BinEmit8($E8);
  BinEmit8($DE); BinEmit8($C1);
  BinEmit8($DE); BinEmit8($C9);
  BinEmit8($DE); BinEmit8($C9);
  BinEmit8($DC); BinEmit8($45); BinEmit8($F0);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D8);
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);
  BinEmit8($49);
  BinJccLabel(5,'_cnxp_loop');
  { CONVXP = v^4 * cnx / price }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);           { fld v }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) -> v^2 }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) -> v^4 }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul cnx }
  BinEmit8($DC); BinEmit8($75); BinEmit8($E8);           { fdiv price }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);
  BinEmit8($0D); BinEmit32($00000C00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_cnxp_done');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_cos(x): LongInt --- cos(x radians) via x87 FCOS (23 octets) }
  BinDefineLabel('_SASRT_cos');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] }
  BinEmit8($D9); BinEmit8($FF);                  { fcos }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_cosh(x): LongInt --- cosh(x)=(e^x+e^-x)/2 via x87 (64 octets) }
  BinDefineLabel('_SASRT_cosh');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  { compute e^x via F2XM1/FSCALE }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] }
  BinEmit8($D9); BinEmit8($EA);                  { fldl2e }
  BinEmit8($DE); BinEmit8($C9);                  { fmulp st(1) → y }
  BinEmit8($D9); BinEmit8($C0);                  { fld st(0) }
  BinEmit8($D9); BinEmit8($FC);                  { frndint }
  BinEmit8($D9); BinEmit8($C9);                  { fxch }
  BinEmit8($D8); BinEmit8($E1);                  { fsub st(0),st(1) }
  BinEmit8($D9); BinEmit8($F0);                  { f2xm1 }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 }
  BinEmit8($DE); BinEmit8($C1);                  { faddp st(1) }
  BinEmit8($D9); BinEmit8($FD);                  { fscale }
  BinEmit8($DD); BinEmit8($D9);                  { fstp st(1) → ST0=e^x }
  { store e^x, compute e^-x=1/e^x }
  BinEmit8($D9); BinEmit8($55); BinEmit8($FC);  { fst dword [ebp-4] (sans pop) }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → ST0=1, ST1=e^x }
  BinEmit8($DE); BinEmit8($F1);                  { fdivrp st(1): ST1=ST0/ST1=1/e^x=e^-x, pop → ST0=e^-x }
  { load e^x from mem, add e^-x }
  BinEmit8($D9); BinEmit8($45); BinEmit8($FC);  { fld dword [ebp-4] → ST0=e^x, ST1=e^-x }
  BinEmit8($D8); BinEmit8($C1);                  { fadd st(0),st(1) → ST0=e^x+e^-x }
  { divide by 2 }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 }
  BinEmit8($D8); BinEmit8($C0);                  { fadd st(0),st(0) → ST0=2 }
  BinEmit8($DE); BinEmit8($F9);                  { fdivp st(1): ST1=ST1/ST0=(e^x+e^-x)/2, pop → ST0=cosh }
  BinEmit8($DD); BinEmit8($D9);                  { fstp st(1) → ST0=cosh(x), pop extra }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_css(x1,x2): LongInt --- (x1-x2)^2/2 via x87 (36 octets) }
  { CSS = somme des carres corriges = (x1-x2)^2/2 pour 2 arguments.   }
  BinDefineLabel('_SASRT_css');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);           { sub esp,4 (local fistp) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8]  x1 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] x2, x1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st0: ST0=x1-x2 }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st0,st0: (x1-x2)^2 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0: ST0=2 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st0: (x1-x2)^2/2 }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);           { mov esp,ebp; pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_curobs(dsid): observation courante approx (1 arg) }
  { Sans curseur dataset natif: retourne dsid si positif, sinon 1. }
  BinDefineLabel('_SASRT_curobs');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(15, '_curobs_done');                       { jg done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_curobs_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_cv(x1,x2): LongInt --- coefficient de variation = 100*sqrt(2)*|x1-x2|/(x1+x2) }
  { CV = STD/MEAN*100 = (|x1-x2|/sqrt(2)) / ((x1+x2)/2) * 100 = 100*sqrt(2)*|x1-x2|/sum }
  BinDefineLabel('_SASRT_cv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);           { sub esp,4 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC);           { mov dword[ebp-4],100 }
    BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  { si sum=0 (moyenne nulle): retourner 0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x1 }
  BinEmit8($03); BinEmit8($45); BinEmit8($0C);           { add eax,[ebp+12] x1+x2 }
  BinJccLabel(5, '_cv_fpu');                              { jnz .fpu (sum != 0) }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinJmpLabel('_cv_done');
  BinDefineLabel('_cv_fpu');
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8]  ST0=x1 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] ST0=x2, ST1=x1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp ST0=x1-x2 }
  BinEmit8($D9); BinEmit8($E1);                          { fabs  ST0=|x1-x2| }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8]  ST0=x1, ST1=|diff| }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] ST0=x2, ST1=x1, ST2=|diff| }
  BinEmit8($DE); BinEmit8($C1);                          { faddp ST0=x1+x2, ST1=|diff| }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp ST0=|diff|/sum }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp ST0=2 }
  BinEmit8($D9); BinEmit8($FA);                          { fsqrt ST0=sqrt(2) }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp ST0=|diff|/sum*sqrt(2) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] (=100) }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp ST0=CV }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinDefineLabel('_cv_done');
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { pop ebp; ret 8 }

  { --- _SASRT_daccdb(cost,sal,life,per,factor): amortissement DB cumule (5 args) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per [ebp+24]=factor          }
  BinDefineLabel('_SASRT_daccdb');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8: [ebp-4]=book [ebp-8]=acc }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($14);           { mov ecx,[ebp+20] per }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_dacc_zero');                           { jle: per<=0 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(14,'_dacc_zero');                           { jle: life<=0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] cost }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax book=cost }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($89); BinEmit8($45); BinEmit8($F8);           { mov [ebp-8],eax acc=0 }
  BinDefineLabel('_dacc_loop');
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($18); { imul eax,[ebp+24] *factor }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($7D); BinEmit8($10);           { idiv [ebp+16] /life }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($FC);           { mov ebx,[ebp-4] book }
  BinEmit8($2B); BinEmit8($D8);                          { sub ebx,eax book-dep }
  BinEmit8($3B); BinEmit8($5D); BinEmit8($0C);           { cmp ebx,[ebp+12] vs sal }
  BinJccLabel(13,'_dacc_ok');                             { jge: dep ok }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] book-sal }
  BinJccLabel(13,'_dacc_ok');                             { jge: dep=book-sal }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax dep=0 }
  BinDefineLabel('_dacc_ok');
  BinEmit8($01); BinEmit8($45); BinEmit8($F8);           { add [ebp-8],eax acc+=dep }
  BinEmit8($29); BinEmit8($45); BinEmit8($FC);           { sub [ebp-4],eax book-=dep }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_dacc_loop');                            { jnz loop }
  BinEmit8($8B); BinEmit8($45); BinEmit8($F8);           { mov eax,[ebp-8] acc }
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00); { pop ebp; ret 20 }
  BinDefineLabel('_dacc_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00); { pop ebp; ret 20 }

  { --- _SASRT_daccdbsl(cost,sal,life,per,factor): DB/SL cumule (5 args) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per [ebp+24]=factor }
  BinDefineLabel('_SASRT_daccdbsl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8: [ebp-4]=book [ebp-8]=rem }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($14);           { mov ecx,[ebp+20] per }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_daccdbsl_zero');
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(14,'_daccdbsl_zero');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] cost }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] life }
  BinEmit8($89); BinEmit8($45); BinEmit8($F8);           { mov [ebp-8],eax rem=life }
  BinEmit8($31); BinEmit8($F6);                          { xor esi,esi acc=0 }
  BinDefineLabel('_daccdbsl_loop');
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($18); { imul eax,[ebp+24] }
  BinEmit8($99); BinEmit8($F7); BinEmit8($7D); BinEmit8($10); { cdq; idiv life }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax ddb_dep }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] book-sal }
  BinJccLabel(14,'_daccdbsl_slz');
  BinEmit8($83); BinEmit8($7D); BinEmit8($F8); BinEmit8($00); { cmp [ebp-8],0 }
  BinJccLabel(14,'_daccdbsl_slz');
  BinEmit8($99); BinEmit8($F7); BinEmit8($7D); BinEmit8($F8); { cdq; idiv rem }
  BinEmit8($89); BinEmit8($C7);                          { mov edi,eax sl_dep }
  BinJmpLabel('_daccdbsl_slok');
  BinDefineLabel('_daccdbsl_slz');
  BinEmit8($31); BinEmit8($FF);                          { xor edi,edi }
  BinDefineLabel('_daccdbsl_slok');
  BinEmit8($89); BinEmit8($D8);                          { mov eax,ebx ddb }
  BinEmit8($3B); BinEmit8($FB);                          { cmp edi,ebx sl vs ddb }
  BinJccLabel(14,'_daccdbsl_maxok');
  BinEmit8($8B); BinEmit8($C7);                          { mov eax,edi sl }
  BinDefineLabel('_daccdbsl_maxok');
  BinEmit8($8B); BinEmit8($55); BinEmit8($FC);           { mov edx,[ebp-4] book }
  BinEmit8($2B); BinEmit8($55); BinEmit8($0C);           { sub edx,[ebp+12] book-sal }
  BinJccLabel(14,'_daccdbsl_capz');
  BinEmit8($39); BinEmit8($D0);                          { cmp eax,edx dep vs cap }
  BinJccLabel(14,'_daccdbsl_capdone');
  BinEmit8($89); BinEmit8($D0);                          { mov eax,edx cap }
  BinJmpLabel('_daccdbsl_capdone');
  BinDefineLabel('_daccdbsl_capz');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_daccdbsl_capdone');
  BinEmit8($01); BinEmit8($C6);                          { add esi,eax acc+=dep }
  BinEmit8($29); BinEmit8($45); BinEmit8($FC);           { sub [ebp-4],eax book-=dep }
  BinEmit8($FF); BinEmit8($4D); BinEmit8($F8);           { dec [ebp-8] rem-- }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_daccdbsl_loop');
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi return acc }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_daccdbsl_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_daccsl(cost,sal,life,per): LongInt --- (cost-sal)*per/life (23 octets) }
  { Amortissement lineaire cumule: depreciation totale jusqu a la periode per }
  { Arguments: [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per          }
  BinDefineLabel('_SASRT_daccsl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  cost }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] cost-sal }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($14); { imul eax,[ebp+20] (cost-sal)*per }
  BinEmit8($99);                                          { cdq }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] life }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx: (cost-sal)*per/life }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($10); BinEmit8($00);           { ret 16 }

  { --- _SASRT_daccsyd(cost,sal,life,per): LongInt --- (cost-sal)*per*(2*life-per+1)/(life*(life+1)) }
  { Amortissement cumule somme des chiffres de la duree de vie.                }
  { Arguments: [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per           }
  BinDefineLabel('_SASRT_daccsyd');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx; push esi; push edi }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  cost }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] cost-sal }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($14);           { mov ecx,[ebp+20] per }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);           { imul eax,ecx  (cost-sal)*per }
  BinEmit8($8B); BinEmit8($F3);                          { mov esi,ebx   esi=life }
  BinEmit8($D1); BinEmit8($E6);                          { shl esi,1     esi=2*life }
  BinEmit8($29); BinEmit8($CE);                          { sub esi,ecx   esi=2*life-per }
  BinEmit8($46);                                          { inc esi       esi=2*life-per+1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C6);           { imul eax,esi  (cost-sal)*per*(2*life-per+1) }
  BinEmit8($8B); BinEmit8($FB);                          { mov edi,ebx   edi=life }
  BinEmit8($47);                                          { inc edi       edi=life+1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($FB);           { imul edi,ebx  edi=life*(life+1) }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($FF);                          { idiv edi }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi; pop esi; pop ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($10); BinEmit8($00);           { ret 16 }

  { --- _SASRT_dacctab(cost,sal,life,per): cumul SYD=(cost-sal)*per*(2*life-per+1)/(life*(life+1)) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per                                          }
  { Locaux (sub esp,8): [ebp-4]=tmp [ebp-6/-8]=CW                                                }
  BinDefineLabel('_SASRT_dacctab');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] cost }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] sal }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> cost-sal }
  BinEmit8($DB); BinEmit8($45); BinEmit8($14);           { fild [ebp+20] per }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> (cost-sal)*per }
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild [ebp+16] life }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) -> 2*life }
  BinEmit8($DB); BinEmit8($45); BinEmit8($14);           { fild [ebp+20] per }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> 2*life-per }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> 2*life-per+1 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> num }
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild [ebp+16] life }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy life }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> life+1 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> life*(life+1) }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st -> result }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 truncate }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_dairy(x): floor(Ai'(x))=(c1/2)*x^2*sfp-c2*sgp, 30 iter (1 arg) }
  { term_fp[k]=term_fp[k-1]*x3/(3k*(3k+2)), term_gp[k]=*x3/((3k-2)*3k)      }
  { [ebp+8]=x. sub esp,56: [ebp-4]=res [ebp-8/-6]=CW [ebp-16]=denom         }
  { [ebp-24]=x3 [ebp-32]=term_fp [ebp-40]=term_gp [ebp-48]=sfp [ebp-56]=sgp }
  BinDefineLabel('_SASRT_dairy');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);                   { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($38);                   { sub esp,56 }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);                   { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);    { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF); { and eax,~0xC00 }
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00); { or eax,0x400 floor }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);    { mov [ebp-6],ax }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                   { fild [ebp+8] x }
  BinEmit8($D9); BinEmit8($C0);                                  { fld st(0) }
  BinEmit8($D8); BinEmit8($C8);                                  { fmul st(0),st(0) x^2 }
  BinEmit8($DE); BinEmit8($C9);                                  { fmulp st(1),st x^3 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);                   { fstp [ebp-24] }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($E0); { fld1;fstp term_fp }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($D8); { fld1;fstp term_gp }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($D0); { fld1;fstp sfp }
  BinEmit8($D9); BinEmit8($E8); BinEmit8($DD); BinEmit8($5D); BinEmit8($C8); { fld1;fstp sgp }
  BinEmit8($B9); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,1 }
  BinDefineLabel('_dairy_loop');
  BinEmit8($8D); BinEmit8($04); BinEmit8($49);                   { lea eax,[ecx+ecx*2] 3k }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16],eax }
  BinEmit8($83); BinEmit8($C0); BinEmit8($02);                   { add eax,2 3k+2 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($F0);    { imul eax,[ebp-16] }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16] 3k*(3k+2) }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);                   { fld term_fp }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($E8);                   { fmul [ebp-24] *x3 }
  BinEmit8($DA); BinEmit8($75); BinEmit8($F0);                   { fidiv [ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);                   { fstp term_fp }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D0);                   { fld sfp }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E0);                   { fadd term_fp }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D0);                   { fstp sfp }
  BinEmit8($8D); BinEmit8($04); BinEmit8($49);                   { lea eax,[ecx+ecx*2] 3k }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16],eax }
  BinEmit8($83); BinEmit8($E8); BinEmit8($02);                   { sub eax,2 3k-2 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($F0);    { imul eax,[ebp-16] }
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);                   { mov [ebp-16] (3k-2)*3k }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);                   { fld term_gp }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($E8);                   { fmul [ebp-24] *x3 }
  BinEmit8($DA); BinEmit8($75); BinEmit8($F0);                   { fidiv [ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);                   { fstp term_gp }
  BinEmit8($DD); BinEmit8($45); BinEmit8($C8);                   { fld sgp }
  BinEmit8($DC); BinEmit8($45); BinEmit8($D8);                   { fadd term_gp }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($C8);                   { fstp sgp }
  BinEmit8($41);                                                  { inc ecx }
  BinEmit8($83); BinEmit8($F9); BinEmit8($1F);                   { cmp ecx,31 }
  BinJccLabel(12,'_dairy_loop');                                  { jl }
  { Ai'(x) = (c1/2)*x^2*sfp - c2*sgp }
  BinMovRegLabel(0,'_sas_airyd1h');                               { mov eax,&(c1/2) }
  BinEmit8($DD); BinEmit8($00);                                   { fld qword[eax] }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);                   { fild [ebp+8] x }
  BinEmit8($D8); BinEmit8($C8);                                  { fmul st(0),st(0) x^2 }
  BinEmit8($DE); BinEmit8($C9);                                  { fmulp st(1),st (c1/2)*x^2 }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D0);                   { fmul sfp }
  BinMovRegLabel(0,'_sas_airyc2');                                { mov eax,&c2 }
  BinEmit8($DD); BinEmit8($00);                                   { fld qword[eax] }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($C8);                   { fmul sgp }
  BinEmit8($DE); BinEmit8($E9);                                   { fsubp st(1),st Ai'(x) }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);                   { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);                   { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);                   { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);                   { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_compound(a,r,n): LongInt --- a*(1+r/100)^n via FPU (42 octets) }
  { [ebp+8]=a [ebp+12]=r [ebp+16]=n. Boucle avec LOOP (ECX=n).             }
  BinDefineLabel('_SASRT_compound');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);               { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($0C);               { sub esp,12 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC);               { mov dword[ebp-4],100 }
    BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);               { fild [ebp+8]  ST0=a }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);               { mov ecx,[ebp+16] n }
  BinEmit8($85); BinEmit8($C9);                               { test ecx,ecx }
  BinEmit8($7E); BinEmit8($13);                               { jle .simple (n<=0: retourne a) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);               { fild [ebp+12] r → ST0=r,ST1=a }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);               { fild [ebp-4]  100 }
  BinEmit8($DE); BinEmit8($C1);                               { faddp ST0=100+r, ST1=a }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);               { fild [ebp-4]  100 }
  BinEmit8($DE); BinEmit8($F9);                               { fdivp ST0=(100+r)/100,ST1=a }
  BinEmit8($DC); BinEmit8($C9);                               { .loop: fmul ST(1),ST0 → ST1*=factor }
  BinEmit8($E2); BinEmit8($FC);                               { loop .loop (dec ecx; jnz -4) }
  BinEmit8($DD); BinEmit8($D8);                               { fstp ST(0) discard factor }
  { .simple: ST0 = a*(1+r/100)^n ou simplement a si n<=0 }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($F8);               { fistp [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($F8);               { mov eax,[ebp-8] }
  BinEmit8($89); BinEmit8($EC);                               { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00); { pop ebp; ret 12 }

  { --- _SASRT_datdif(d1,d2,basis): LongInt --- d2-d1 en jours (13 octets) }
  { [ebp+8]=d1 [ebp+12]=d2 [ebp+16]=basis(ignoré). Retourne d2-d1.      }
  BinDefineLabel('_SASRT_datdif');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);  { mov eax,[ebp+12] d2 }
  BinEmit8($2B); BinEmit8($45); BinEmit8($08);  { sub eax,[ebp+8]  d1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_date(): LongInt --- alias pour _SASRT_today (10 octets) }
  BinDefineLabel('_SASRT_date');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinCallLabel('_SASRT_today');  { call today() → EAX=date SAS courante }
  BinEmit8($5D); BinEmit8($C3);

  { --- _SASRT_datejul(yddd): LongInt --- Julian YYYYDDD→date SAS (69 octets) }
  { year=yddd/1000, doy=yddd mod 1000.                                    }
  { Si year<100: year<60→year+2000, sinon year+1900.                      }
  { SAS = floor(1461*(year+4715)/4) + doy - 2438044.                      }
  BinDefineLabel('_SASRT_datejul');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56);                                { push ebx,esi }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] }
  BinEmit8($B9); BinEmit8($E8); BinEmit8($03); BinEmit8($00); BinEmit8($00); { mov ecx,1000 }
  BinEmit8($99);                                               { cdq }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx → eax=year,edx=doy }
  BinEmit8($89); BinEmit8($D6);                               { mov esi,edx (doy) }
  BinEmit8($83); BinEmit8($F8); BinEmit8($64);               { cmp eax,100 }
  BinEmit8($7D); BinEmit8($11);                               { jge .four_digit (disp=17) }
  BinEmit8($83); BinEmit8($F8); BinEmit8($3C);               { cmp eax,60 }
  BinEmit8($7C); BinEmit8($07);                               { jl .add2000 (disp=7) }
  BinEmit8($05); BinEmit8($7C); BinEmit8($07); BinEmit8($00); BinEmit8($00); { add eax,1900 }
  BinEmit8($EB); BinEmit8($05);                               { jmp .four_digit (disp=5) }
  BinEmit8($05); BinEmit8($D0); BinEmit8($07); BinEmit8($00); BinEmit8($00); { .add2000: add eax,2000 }
  { .four_digit: }
  BinEmit8($05); BinEmit8($6B); BinEmit8($12); BinEmit8($00); BinEmit8($00); { add eax,4715 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  BinEmit8($01); BinEmit8($F0);                               { add eax,esi (doy) }
  BinEmit8($2D); BinEmit8($9C); BinEmit8($33); BinEmit8($25); BinEmit8($00); { sub eax,2438044 }
  BinEmit8($5E); BinEmit8($5B); BinEmit8($5D);               { pop esi,ebx,ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_datepart(dt): LongInt --- floor(dt/86400)=date SAS (18 octets) }
  BinDefineLabel('_SASRT_datepart');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($80); BinEmit8($51); BinEmit8($01); BinEmit8($00); { mov ecx,86400 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_datetime(): LongInt --- today()*86400+time_sec (60 octets) }
  { Appelle _SASRT_today qui remplit _sas_systime. Lit ensuite wHour/wMinute/wSecond. }
  BinDefineLabel('_SASRT_datetime');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);                { push ebx,esi,edi }
  BinCallLabel('_SASRT_today');                                { EAX=date, remplit _sas_systime }
  BinEmit8($89); BinEmit8($C6);                               { mov esi,eax (date) }
  BinMovRegLabel(7, '_sas_systime');                           { mov edi,&_sas_systime }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($47); BinEmit8($08); { movzx eax,word[edi+8]=wHour }
  BinEmit8($69); BinEmit8($C0); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { imul eax,eax,3600 }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($57); BinEmit8($0A); { movzx edx,word[edi+10]=wMinute }
  BinEmit8($6B); BinEmit8($D2); BinEmit8($3C);               { imul edx,edx,60 }
  BinEmit8($01); BinEmit8($D0);                               { add eax,edx }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($57); BinEmit8($0C); { movzx edx,word[edi+12]=wSecond }
  BinEmit8($01); BinEmit8($D0);                               { add eax,edx }
  BinEmit8($89); BinEmit8($C1);                               { mov ecx,eax (time_sec) }
  BinEmit8($89); BinEmit8($F0);                               { mov eax,esi (date) }
  BinEmit8($69); BinEmit8($C0); BinEmit8($80); BinEmit8($51); BinEmit8($01); BinEmit8($00); { imul eax,eax,86400 }
  BinEmit8($01); BinEmit8($C8);                               { add eax,ecx }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B); BinEmit8($5D); { pop edi,esi,ebx,ebp }
  BinEmit8($C3);                                               { ret (0 arg) }

  { --- _SASRT_dclose(did): 0 si did positif, -1 sinon }
  BinDefineLabel('_SASRT_dclose');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                 { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                                { test eax,eax }
  BinJccLabel(15, '_dclose_ok');                               { jg ok }
  BinEmit8($B8); BinEmit32(-1);                                { mov eax,-1 }
  BinJmpLabel('_dclose_done');
  BinDefineLabel('_dclose_ok');
  BinEmit8($31); BinEmit8($C0);                                { xor eax,eax }
  BinDefineLabel('_dclose_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_depdb(cost,sal,life,per,factor): amortissement DB periode per (5 args) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per [ebp+24]=factor              }
  BinDefineLabel('_SASRT_depdb');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);           { sub esp,4: [ebp-4]=book }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($14);           { mov ecx,[ebp+20] per }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_depdb_zero');                          { jle: per<=0 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(14,'_depdb_zero');                          { jle: life<=0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] cost }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax book=cost }
  BinEmit8($49);                                          { dec ecx: per-1 prefix iters }
  BinJccLabel(14,'_depdb_final');                         { jle: per=1 skip loop }
  BinDefineLabel('_depdb_loop');
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($18); { imul eax,[ebp+24] *factor }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($7D); BinEmit8($10);           { idiv [ebp+16] /life }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($FC);           { mov ebx,[ebp-4] book }
  BinEmit8($2B); BinEmit8($D8);                          { sub ebx,eax book-dep }
  BinEmit8($3B); BinEmit8($5D); BinEmit8($0C);           { cmp ebx,[ebp+12] vs sal }
  BinJccLabel(13,'_depdb_ok');                            { jge: dep ok }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] book-sal }
  BinJccLabel(13,'_depdb_ok');                            { jge: dep=book-sal }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax dep=0 }
  BinDefineLabel('_depdb_ok');
  BinEmit8($29); BinEmit8($45); BinEmit8($FC);           { sub [ebp-4],eax book-=dep }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_depdb_loop');                           { jnz loop }
  BinDefineLabel('_depdb_final');
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($18); { imul eax,[ebp+24] *factor }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($7D); BinEmit8($10);           { idiv [ebp+16] /life }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($FC);           { mov ebx,[ebp-4] book }
  BinEmit8($2B); BinEmit8($D8);                          { sub ebx,eax book-dep }
  BinEmit8($3B); BinEmit8($5D); BinEmit8($0C);           { cmp ebx,[ebp+12] vs sal }
  BinJccLabel(13,'_depdb_done');                          { jge: dep ok }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] book-sal }
  BinJccLabel(13,'_depdb_done');                          { jge: dep=book-sal }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax dep=0 }
  BinDefineLabel('_depdb_done');
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00); { pop ebp; ret 20 }
  BinDefineLabel('_depdb_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00); { pop ebp; ret 20 }

  { --- _SASRT_depdbsl(cost,sal,life,per,factor): DB/SL periode per (5 args) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per [ebp+24]=factor  }
  BinDefineLabel('_SASRT_depdbsl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8: [ebp-4]=book [ebp-8]=rem }
  BinEmit8($53); BinEmit8($56);                          { push ebx,esi }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($14);           { mov ecx,[ebp+20] per }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_depdbsl_zero');
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(14,'_depdbsl_zero');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] cost }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] life }
  BinEmit8($89); BinEmit8($45); BinEmit8($F8);           { mov [ebp-8],eax rem=life }
  BinDefineLabel('_depdbsl_loop');
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($18); { imul eax,[ebp+24] }
  BinEmit8($99); BinEmit8($F7); BinEmit8($7D); BinEmit8($10); { cdq; idiv life }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax ddb_dep }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] book }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] book-sal }
  BinJccLabel(14,'_depdbsl_slz');
  BinEmit8($83); BinEmit8($7D); BinEmit8($F8); BinEmit8($00); { cmp [ebp-8],0 }
  BinJccLabel(14,'_depdbsl_slz');
  BinEmit8($99); BinEmit8($F7); BinEmit8($7D); BinEmit8($F8); { cdq; idiv rem }
  BinEmit8($89); BinEmit8($C6);                          { mov esi,eax sl_dep }
  BinJmpLabel('_depdbsl_slok');
  BinDefineLabel('_depdbsl_slz');
  BinEmit8($31); BinEmit8($F6);                          { xor esi,esi }
  BinDefineLabel('_depdbsl_slok');
  BinEmit8($89); BinEmit8($D8);                          { mov eax,ebx ddb }
  BinEmit8($3B); BinEmit8($F3);                          { cmp esi,ebx sl vs ddb }
  BinJccLabel(14,'_depdbsl_maxok');
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi sl }
  BinDefineLabel('_depdbsl_maxok');
  BinEmit8($8B); BinEmit8($55); BinEmit8($FC);           { mov edx,[ebp-4] book }
  BinEmit8($2B); BinEmit8($55); BinEmit8($0C);           { sub edx,[ebp+12] book-sal }
  BinJccLabel(14,'_depdbsl_capz');
  BinEmit8($39); BinEmit8($D0);                          { cmp eax,edx dep vs cap }
  BinJccLabel(14,'_depdbsl_capdone');
  BinEmit8($89); BinEmit8($D0);                          { mov eax,edx cap }
  BinJmpLabel('_depdbsl_capdone');
  BinDefineLabel('_depdbsl_capz');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_depdbsl_capdone');
  BinEmit8($29); BinEmit8($45); BinEmit8($FC);           { sub [ebp-4],eax book-=dep }
  BinEmit8($FF); BinEmit8($4D); BinEmit8($F8);           { dec [ebp-8] rem-- }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_depdbsl_loop');
  BinEmit8($5E); BinEmit8($5B);                          { pop esi,ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_depdbsl_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5E); BinEmit8($5B);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_depsl(cost,sal,life,per): LongInt --- (cost-sal)/life (19 octets) }
  { Amortissement lineaire annuel: quote-part constante par periode.           }
  { Arguments: [ebp+8]=cost [ebp+12]=sal [ebp+16]=life (per ignore)           }
  BinDefineLabel('_SASRT_depsl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  cost }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] cost-sal }
  BinEmit8($99);                                          { cdq }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] life }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx: (cost-sal)/life }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($10); BinEmit8($00);           { ret 16 }

  { --- _SASRT_depsyd(cost,sal,life,per): LongInt --- 2*(cost-sal)*(life-per+1)/(life*(life+1)) }
  { Amortissement somme des chiffres de la duree de vie a la periode per.     }
  { Arguments: [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per          }
  BinDefineLabel('_SASRT_depsyd');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56);                          { push ebx; push esi }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  cost }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] cost-sal }
  BinEmit8($D1); BinEmit8($E0);                          { shl eax,1   2*(cost-sal) }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($8B); BinEmit8($75); BinEmit8($14);           { mov esi,[ebp+20] per }
  BinEmit8($29); BinEmit8($F3);                          { sub ebx,esi  life-per }
  BinEmit8($43);                                          { inc ebx      life-per+1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C3);           { imul eax,ebx 2*(cost-sal)*(life-per+1) }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);           { mov ebx,[ebp+16] life }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] life }
  BinEmit8($41);                                          { inc ecx          life+1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($CB);           { imul ecx,ebx life*(life+1) }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx }
  BinEmit8($5E); BinEmit8($5B);                          { pop esi; pop ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($10); BinEmit8($00);           { ret 16 }

  { --- _SASRT_deptab(cost,sal,life,per): SYD=(cost-sal)*(life-per+1)*2/(life*(life+1)) (4 args) }
  { [ebp+8]=cost [ebp+12]=sal [ebp+16]=life [ebp+20]=per                                         }
  { Locaux (sub esp,8): [ebp-4]=tmp [ebp-6/-8]=CW                                               }
  BinDefineLabel('_SASRT_deptab');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] cost }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] sal }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> cost-sal }
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild [ebp+16] life }
  BinEmit8($DB); BinEmit8($45); BinEmit8($14);           { fild [ebp+20] per }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> life-per }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> life-per+1 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> (cost-sal)*(life-per+1) }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) -> *2 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild [ebp+16] life }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy life }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> life+1 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> life*(life+1) }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st -> result }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 truncate }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_deviance(dist,x,n): deviance entiere (3 args) }
  { dist=0: gaussienne -> (x-n)^2 ; autres: 2*abs(x-n). }
  BinDefineLabel('_SASRT_deviance');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($2B); BinEmit8($45); BinEmit8($10);           { sub eax,[ebp+16] n }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp dist,0 }
  BinJccLabel(5, '_deviance_abs');                       { jne fallback }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C0);           { imul eax,eax }
  BinJmpLabel('_deviance_done');
  BinDefineLabel('_deviance_abs');
  BinEmit8($99);                                         { cdq }
  BinEmit8($31); BinEmit8($D0);                          { xor eax,edx }
  BinEmit8($2B); BinEmit8($C2);                          { sub eax,edx }
  BinEmit8($01); BinEmit8($C0);                          { add eax,eax }
  BinDefineLabel('_deviance_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_dhms(d,h,m,s): LongInt --- d*86400+h*3600+m*60+s (38 octets) }
  { [ebp+8]=d [ebp+12]=h [ebp+16]=m [ebp+20]=s. }
  BinDefineLabel('_SASRT_dhms');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] d }
  BinEmit8($69); BinEmit8($C0); BinEmit8($80); BinEmit8($51); BinEmit8($01); BinEmit8($00); { imul eax,86400 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);                { mov ecx,[ebp+12] h }
  BinEmit8($69); BinEmit8($C9); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { imul ecx,3600 }
  BinEmit8($01); BinEmit8($C8);                               { add eax,ecx }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);                { mov ecx,[ebp+16] m }
  BinEmit8($6B); BinEmit8($C9); BinEmit8($3C);               { imul ecx,60 }
  BinEmit8($01); BinEmit8($C8);                               { add eax,ecx }
  BinEmit8($03); BinEmit8($45); BinEmit8($14);               { add eax,[ebp+20] s }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_dif(x,n): LongInt --- x - valeur_precedente (n ignore) }
  { [ebp+8]=x [ebp+12]=n. ESI=&dif_buf. eax=x-prev, ecx=x. ret 8.  }
  BinDefineLabel('_SASRT_dif');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($56);                                    { push esi }
  BinMovRegLabel(6,'_sas_dif_buf');                 { mov esi,&dif_buf }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);    { mov eax,[ebp+8] (x) }
  BinEmit8($2B); BinEmit8($06);                    { sub eax,[esi] (x - prev) }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);    { mov ecx,[ebp+8] (x) }
  BinEmit8($89); BinEmit8($0E);                    { mov [esi],ecx (stocker x) }
  BinEmit8($5E);                                    { pop esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_digamma(x): psi(x)=floor(-gamma+sum(1/k,k=1..x-1)) (1 arg) }
  { [ebp+8]=x. Locaux: [ebp-4]=k/resultat [ebp-8]=CW_orig [ebp-6]=CW_floor }
  BinDefineLabel('_SASRT_digamma');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14,'_dig_zero');                            { jle: x<=0 return 0 }
  BinMovRegLabel(2,'_sas_euler');                         { mov edx,&gamma }
  BinEmit8($DD); BinEmit8($02);                          { fld qword[edx] ST=gamma }
  BinEmit8($D9); BinEmit8($E0);                          { fchs ST=-gamma }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] x }
  BinEmit8($49);                                          { dec ecx x-1 }
  BinJccLabel(14,'_dig_floor');                           { jle: x=1 skip loop }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1); { mov [ebp-4],1 k=1 }
  BinDefineLabel('_dig_loop');
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] k }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st 1/k }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st acc+=1/k }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc [ebp-4] k++ }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_dig_loop');                             { jnz loop }
  BinDefineLabel('_dig_floor');
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit32($FFFFF3FF);                   { and eax,~$0C00 clear RC }
  BinEmit8($0D); BinEmit32($00000400);                   { or eax,$0400 round-down }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] restore }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  BinDefineLabel('_dig_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_dnum(did): nombre minimal d'entrees pour did valide }
  BinDefineLabel('_SASRT_dnum');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                 { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                                { test eax,eax }
  BinJccLabel(15, '_dnum_valid');                              { jg valid }
  BinEmit8($31); BinEmit8($C0);                                { xor eax,eax }
  BinJmpLabel('_dnum_done');
  BinDefineLabel('_dnum_valid');
  BinEmit8($B8); BinEmit32(1);                                 { mov eax,1 }
  BinDefineLabel('_dnum_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_dopen(dir): 1 si chemin repertoire existe, 0 sinon }
  BinDefineLabel('_SASRT_dopen');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp dir,0 }
  BinJccLabel(4, '_dopen_zero');                              { je zero }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);                { push dir }
  BinCallImport('_GetFileAttributesA@4');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);                { cmp eax,-1 }
  BinJccLabel(4, '_dopen_zero');                              { je zero }
  BinEmit8($A9); BinEmit32($00000010);                        { test eax,FILE_ATTRIBUTE_DIRECTORY }
  BinEmit8($0F); BinEmit8($95); BinEmit8($C0);                { setne al }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);                { movzx eax,al }
  BinJmpLabel('_dopen_done');
  BinDefineLabel('_dopen_zero');
  BinEmit8($31); BinEmit8($C0);                               { xor eax,eax }
  BinDefineLabel('_dopen_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_doptnum(did): 1 option minimale si did valide, 0 sinon }
  BinDefineLabel('_SASRT_doptnum');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                 { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                                { test eax,eax }
  BinJccLabel(15, '_doptnum_valid');                           { jg valid }
  BinEmit8($31); BinEmit8($C0);                                { xor eax,eax }
  BinJmpLabel('_doptnum_done');
  BinDefineLabel('_doptnum_valid');
  BinEmit8($B8); BinEmit32(1);                                 { mov eax,1 }
  BinDefineLabel('_doptnum_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_dropnote(dsid,note): 0 si dsid>0, -1 sinon (2 args) }
  { [ebp+8]=dsid [ebp+12]=noteid. Valide dsid ; note supprimee = no-op. }
  BinDefineLabel('_SASRT_dropnote');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);        { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);        { mov eax,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($C0);                       { test eax,eax }
  BinJccLabel(15,'_dropnote_ok');                      { jg _dropnote_ok }
  BinEmit8($B8); BinEmit32(-1);                       { mov eax,-1 dsid invalide }
  BinJmpLabel('_dropnote_done');
  BinDefineLabel('_dropnote_ok');
  BinEmit8($31); BinEmit8($C0);                       { xor eax,eax → 0=OK }
  BinDefineLabel('_dropnote_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_dur(n,y,c,par,red): Macaulay duration sum(t*CF*v^t)/sum(CF*v^t) (5 args) }
  { [ebp+8]=n [ebp+12]=y [ebp+16]=c [ebp+20]=par(unused) [ebp+24]=red               }
  { sub esp,40: [ebp-4]=t/tmp [ebp-8/-6]=CW [ebp-16]=dur_sum [ebp-24]=price_sum     }
  {             [ebp-32]=disc [ebp-40]=v                                              }
  BinDefineLabel('_SASRT_dur');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($28);           { sub esp,40 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_dur_done');                            { jle: n<=0 -> 0 }
  { v = 100/(100+y) }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] y }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> 100+y }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F1);                          { fdivrp st(1),st -> v=100/(100+y) }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);           { fstp qword[ebp-40] v }
  { disc=v, price_sum=0, dur_sum=0, t=1 }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);           { fld qword[ebp-40] v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp qword[ebp-32] disc=v }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] price=0 }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] dur=0 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1); { mov [ebp-4],1 t=1 }
  BinDefineLabel('_dur_loop');
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild [ebp+16] c }
  BinEmit8($83); BinEmit8($F9); BinEmit8($01);           { cmp ecx,1 }
  BinJccLabel(5,'_dur_notlast');                          { jnz: not last -> skip red }
  BinEmit8($DB); BinEmit8($45); BinEmit8($18);           { fild [ebp+24] red }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st -> c+red }
  BinDefineLabel('_dur_notlast');
  { CF*disc -> update price_sum and dur_sum }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld qword[ebp-32] disc }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> CF*disc }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);           { fadd qword[ebp-24] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] price_sum }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] t }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> t*CF*disc }
  BinEmit8($DC); BinEmit8($45); BinEmit8($F0);           { fadd qword[ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] dur_sum }
  { disc *= v }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld qword[ebp-32] disc }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D8);           { fmul qword[ebp-40] v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp qword[ebp-32] disc }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc [ebp-4] t++ }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_dur_loop');                             { jnz }
  { DUR = dur_sum / price_sum, truncate }
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld qword[ebp-16] dur_sum }
  BinEmit8($DC); BinEmit8($75); BinEmit8($E8);           { fdiv qword[ebp-24] /price_sum }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 truncate }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_dur_done');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_durp(n,y,c,par,red): modified duration = Macaulay*v (5 args) }
  { identical loop to _SASRT_dur but multiplies result by v before fistp      }
  BinDefineLabel('_SASRT_durp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($28);           { sub esp,40 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_durp_done');                           { jle: n<=0 -> 0 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild 100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild y }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 100+y }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(100); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild 100 }
  BinEmit8($DE); BinEmit8($F1);                          { fdivrp -> v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($D8);           { fstp v }
  BinEmit8($DD); BinEmit8($45); BinEmit8($D8);           { fld v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp disc=v }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp price=0 }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp dur=0 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1); { t=1 }
  BinDefineLabel('_durp_loop');
  BinEmit8($DB); BinEmit8($45); BinEmit8($10);           { fild c }
  BinEmit8($83); BinEmit8($F9); BinEmit8($01);           { cmp ecx,1 }
  BinJccLabel(5,'_durp_notlast');
  BinEmit8($DB); BinEmit8($45); BinEmit8($18);           { fild red }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> c+red }
  BinDefineLabel('_durp_notlast');
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld disc }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> CF*disc }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);           { fadd price_sum }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp price_sum }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild t }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> t*CF*disc }
  BinEmit8($DC); BinEmit8($45); BinEmit8($F0);           { fadd dur_sum }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp dur_sum }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E0);           { fld disc }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D8);           { fmul v }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp disc }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc t }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_durp_loop');
  { DURP = (dur_sum/price_sum)*v }
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld dur_sum }
  BinEmit8($DC); BinEmit8($75); BinEmit8($E8);           { fdiv price_sum }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($D8);           { fmul v -> modified dur }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);
  BinDefineLabel('_durp_done');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_erf(x): LongInt --- signe(x): -1/0/1 selon x<0/=0/>0 (28 octets) }
  { erf(0)=0, erf(pos)=1, erf(neg)=-1 pour arguments entiers.                  }
  BinDefineLabel('_SASRT_erf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinEmit8($74); BinEmit8($0E);                          { jz .zero (+14 → pop ebp) }
  BinEmit8($79); BinEmit8($07);                          { jns .pos (+7 → mov eax,1) }
  BinEmit8($B8); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); { mov eax,-1 }
  BinEmit8($EB); BinEmit8($05);                          { jmp .done (+5 → pop ebp) }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { .pos: mov eax,1 }
  BinEmit8($5D);                                          { .zero/.done: pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);           { ret 4 }

  { --- _SASRT_erfc(x): LongInt --- 1-erf(x): 0/1/2 selon x>0/=0/<0 (32 octets) }
  { erfc(0)=1, erfc(pos)=0, erfc(neg)=2 pour arguments entiers.                }
  BinDefineLabel('_SASRT_erfc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinEmit8($74); BinEmit8($0D);                          { jz .zero (+13 → mov eax,1) }
  BinEmit8($78); BinEmit8($04);                          { js .neg (+4 → mov eax,2) }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax (x>0: erfc=0) }
  BinEmit8($EB); BinEmit8($0C);                          { jmp .done (+12 → pop ebp) }
  BinEmit8($B8); BinEmit8($02); BinEmit8($00); BinEmit8($00); BinEmit8($00); { .neg: mov eax,2 }
  BinEmit8($EB); BinEmit8($05);                          { jmp .done (+5 → pop ebp) }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { .zero: mov eax,1 }
  BinEmit8($5D);                                          { .done: pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);           { ret 4 }

  { --- _SASRT_exist(dsname,type): 1 si chemin existe, 0 sinon (2 args) }
  { [ebp+8]=dsname [ebp+12]=type. Traite dsname comme chemin fichier.  }
  BinDefineLabel('_SASRT_exist');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);               { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);{ cmp dword[ebp+8],0 }
  BinJccLabel(4,'_exist_zero');                               { je _exist_zero }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);               { push [ebp+8] dsname }
  BinCallImport('_GetFileAttributesA@4');                      { eax=-1 si absent }
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);               { cmp eax,-1 }
  BinJccLabel(4,'_exist_zero');                               { je _exist_zero }
  BinEmit8($B8); BinEmit32(1);                               { mov eax,1 }
  BinJmpLabel('_exist_done');
  BinDefineLabel('_exist_zero');
  BinEmit8($31); BinEmit8($C0);                              { xor eax,eax }
  BinDefineLabel('_exist_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fact(n): n! LongInt (1 arg)                          }
  { Algo : eax=1; if n<=0 done; ecx=n; loop: imul eax,ecx; loop    }
  { Layout (28 o) : jle _done=+7(off14-15) loop=-5(off21-22)       }
  BinDefineLabel('_SASRT_fact');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($53);                                  { push ebx              }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);  { mov ebx,[ebp+8]       }
  BinEmit8($B8); BinEmit32(1);                   { mov eax,1             }
  BinEmit8($85); BinEmit8($DB);                  { test ebx,ebx          }
  BinEmit8($7E); BinEmit8($07);                  { jle _done +7 → off23 }
  BinEmit8($89); BinEmit8($D9);                  { mov ecx,ebx           }
  { _loop: offset 18 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);  { imul eax,ecx          }
  BinEmit8($E2); BinEmit8($FB);                  { loop _loop -5 → off18 }
  { _done: offset 23 }
  BinEmit8($5B);                                  { pop ebx               }
  BinEmit8($5D);                                  { pop ebp               }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                 }

  { --- _SASRT_fappend(fid): ajoute enreg en fin de fichier, alias FWRITE (1 arg) }
  BinDefineLabel('_SASRT_fappend');
  BinJmpLabel('_SASRT_fwrite');

  { --- _SASRT_fclose(fid): CloseHandle, libere slot, retourne 0=OK -1=err (1 arg) }
  { [ebp+8]=fid(1..16). SIB [eax+ebx*4]: 10 011 000 = 0x98. }
  BinDefineLabel('_SASRT_fclose');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($53);                                    { push ebx }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] fid }
  BinEmit8($4B);                                    { dec ebx (slot=fid-1) }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_fclos_err');                      { jae err }
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);    { mov eax,[eax+ebx*4] handle }
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);    { cmp eax,-1 }
  BinJccLabel(4,'_fclos_err');                      { je (non ouvert) }
  BinEmit8($50);                                    { push eax (handle) }
  BinCallImport('_CloseHandle@4');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($C7); BinEmit8($04); BinEmit8($98); BinEmit32(-1); { mov [eax+ebx*4],-1 }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (0=OK) }
  BinJmpLabel('_fclos_done');
  BinDefineLabel('_fclos_err');
  BinEmit8($B8); BinEmit32(-1);                    { mov eax,-1 }
  BinDefineLabel('_fclos_done');
  BinEmit8($5B);                                    { pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fcol(fid): colonne ecriture courante = wlen+1, -1 si err (1 arg) }
  BinDefineLabel('_SASRT_fcol');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);                                    { push ebx }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] }
  BinEmit8($4B);                                    { dec ebx }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_fcol_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF); { cmp [eax+ebx*4],-1 }
  BinJccLabel(4,'_fcol_err');
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);    { mov eax,[eax+ebx*4] wlen }
  BinEmit8($40);                                    { inc eax (1-base) }
  BinJmpLabel('_fcol_done');
  BinDefineLabel('_fcol_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fcol_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fdelete(fileref): appelle DeleteFileA(path) → 0=OK 1=erreur (1 arg) }
  { [ebp+8]=fileref/path. DeleteFileA ret 1=OK → XOR 1 → 0=OK (SAS). }
  BinDefineLabel('_SASRT_fdelete');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);     { push [ebp+8] path }
  BinCallImport('_DeleteFileA@4');                   { eax=1 si supprime, 0 si erreur }
  BinEmit8($83); BinEmit8($F0); BinEmit8($01);     { xor eax,1 : 0=OK 1=erreur }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fetch(dsid): -1 fin dataset, aucune observation disponible (1 arg) }
  BinDefineLabel('_SASRT_fetch');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(-1);                              { mov eax,-1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fetchobs(dsid,obs): -1 observation absente, aucune donnee (2 args) }
  BinDefineLabel('_SASRT_fetchobs');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(-1);                              { mov eax,-1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fexist(fileref): GetFileAttributesA(fileref)<>-1 -> 1/0 (1 arg) }
  BinDefineLabel('_SASRT_fexist');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);    { push [ebp+8] }
  BinCallImport('_GetFileAttributesA@4');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);    { cmp eax,-1 }
  BinEmit8($0F); BinEmit8($95); BinEmit8($C0);    { setne al }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);    { movzx eax,al }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fget(fid,var,len): extrait champ de rbuf par sep, 0=OK -1=fin (3 args) }
  { [ebp+8]=fid [ebp+12]=var(ptr) [ebp+16]=len. ESI=src(rbuf+rpos) EDI=dst. }
  BinDefineLabel('_SASRT_fget');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);    { push ebx esi edi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] }
  BinEmit8($4B);                                    { dec ebx (slot) }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_fget_err');                       { jae }
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF); { cmp [eax+ebx*4],-1 }
  BinJccLabel(4,'_fget_err');                       { je (non ouvert) }
  { esi = _sas_fid_rb + slot*256 + rpos }
  BinEmit8($89); BinEmit8($DE);                    { mov esi,ebx }
  BinEmit8($C1); BinEmit8($E6); BinEmit8($08);    { shl esi,8 }
  BinMovRegLabel(0,'_sas_fid_rb');
  BinEmit8($01); BinEmit8($C6);                    { add esi,eax (→ &rbuf[slot]) }
  BinMovRegLabel(0,'_sas_fid_rp');
  BinEmit8($03); BinEmit8($34); BinEmit8($98);    { add esi,[eax+ebx*4] (+rpos) }
  { si [esi]==0 : fin enregistrement }
  BinEmit8($8A); BinEmit8($06);                    { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                    { test al,al }
  BinJccLabel(4,'_fget_end');                       { jz fin enreg }
  { sep = _sas_fid_sep[slot] (dans CL) }
  BinMovRegLabel(0,'_sas_fid_sep');
  BinEmit8($8A); BinEmit8($0C); BinEmit8($18);    { mov cl,[eax+ebx*1] sep }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);    { mov edi,[ebp+12] (var dst) }
  BinEmit8($8B); BinEmit8($55); BinEmit8($10);    { mov edx,[ebp+16] (len) }
  BinDefineLabel('_fget_copy');
  BinEmit8($85); BinEmit8($D2);                    { test edx,edx }
  BinJccLabel(4,'_fget_sep_chk');                   { jz len epuise }
  BinEmit8($8A); BinEmit8($06);                    { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                    { test al,al }
  BinJccLabel(4,'_fget_sep_chk');                   { jz fin enreg }
  BinEmit8($38); BinEmit8($C8);                    { cmp al,cl (vs sep) }
  BinJccLabel(4,'_fget_skip_sep');                  { je → sep trouv }
  BinEmit8($88); BinEmit8($07);                    { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                    { inc esi; inc edi }
  BinEmit8($4A);                                    { dec edx }
  BinJmpLabel('_fget_copy');
  BinDefineLabel('_fget_skip_sep');
  BinEmit8($46);                                    { inc esi (skip sep) }
  BinDefineLabel('_fget_sep_chk');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);    { mov [edi],0 (null-term) }
  { Mettre a jour rpos = esi - rbuf_base_slot }
  BinEmit8($89); BinEmit8($F7);                    { mov edi,esi (save esi) }
  BinEmit8($89); BinEmit8($DE);                    { mov esi,ebx }
  BinEmit8($C1); BinEmit8($E6); BinEmit8($08);    { shl esi,8 }
  BinMovRegLabel(0,'_sas_fid_rb');
  BinEmit8($01); BinEmit8($C6);                    { add esi,eax }
  BinEmit8($29); BinEmit8($F7);                    { sub edi,esi (new rpos) }
  BinMovRegLabel(0,'_sas_fid_rp');
  BinEmit8($89); BinEmit8($3C); BinEmit8($98);    { mov [eax+ebx*4],edi }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (0=OK) }
  BinJmpLabel('_fget_ret');
  BinDefineLabel('_fget_end');
  BinDefineLabel('_fget_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fget_ret');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);   { pop edi esi ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_fileexist(path): LongInt 1=existe 0=non (1 arg)    }
  { Utilise GetFileAttributesA: ret=-1 si absent, sinon attrs.    }
  { Layout (25 o) :                                                }
  BinDefineLabel('_SASRT_fileexist');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);  { push [ebp+8]          }
  BinCallImport('_GetFileAttributesA@4');         { call [GetFileAttrs]   }
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);  { cmp eax,-1            }
  BinEmit8($0F); BinEmit8($95); BinEmit8($C0);  { setne al              }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);  { movzx eax,al          }
  BinEmit8($5D);                                  { pop ebp               }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                 }

  { --- _SASRT_filename(fileref,path,device): 0 si fileref/path non vides, 1 sinon }
  BinDefineLabel('_SASRT_filename');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(1);                                  { mov eax,1 (erreur) }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);                  { mov edx,[ebp+8] fileref }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_filename_done');                             { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);                  { cmp byte[edx],0 }
  BinJccLabel(4, '_filename_done');                             { jz done }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);                  { mov edx,[ebp+12] path }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_filename_done');                             { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);                  { cmp byte[edx],0 }
  BinJccLabel(4, '_filename_done');                             { jz done }
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax (succes) }
  BinDefineLabel('_filename_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_fileref(fileref): 0 si chemin existe (=assigne), 1 sinon (1 arg) }
  BinDefineLabel('_SASRT_fileref');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);    { push [ebp+8] }
  BinCallImport('_GetFileAttributesA@4');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);    { cmp eax,-1 }
  BinEmit8($0F); BinEmit8($94); BinEmit8($C0);    { sete al (1 si inexistant) }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);    { movzx eax,al }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_finv(p,ndf,ddf): quantile F approx entier (p en pourcentage) }
  BinDefineLabel('_SASRT_finv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);           { mov edx,[ebp+8] p }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(14, '_finv_zero');                         { jle zero }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp ndf,0 }
  BinJccLabel(14, '_finv_zero');                         { jle zero }
  BinEmit8($83); BinEmit8($7D); BinEmit8($10); BinEmit8($00); { cmp ddf,0 }
  BinJccLabel(14, '_finv_zero');                         { jle zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinEmit8($83); BinEmit8($FA); BinEmit8($5A);           { cmp p,90 }
  BinJccLabel(12, '_finv_done');                         { jl done }
  BinEmit8($40);                                         { inc eax }
  BinEmit8($83); BinEmit8($FA); BinEmit8($5F);           { cmp p,95 }
  BinJccLabel(12, '_finv_done');                         { jl done }
  BinEmit8($40);                                         { inc eax }
  BinEmit8($83); BinEmit8($FA); BinEmit8($63);           { cmp p,99 }
  BinJccLabel(12, '_finv_done');                         { jl done }
  BinEmit8($40);                                         { inc eax }
  BinJmpLabel('_finv_done');
  BinDefineLabel('_finv_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_finv_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_fnonct(f,ndf,ddf,prob): max(0, f - FINV(prob,ndf,ddf)) }
  BinDefineLabel('_SASRT_fnonct');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push ddf }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push ndf }
  BinEmit8($FF); BinEmit8($75); BinEmit8($14);           { push prob }
  BinCallLabel('_SASRT_finv');                           { eax = quantile central }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] f }
  BinEmit8($29); BinEmit8($C1);                          { sub ecx,eax }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14, '_fnonct_zero');                       { jle zero }
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx }
  BinJmpLabel('_fnonct_done');
  BinDefineLabel('_fnonct_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_fnonct_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_fnote(fid): retourne position fichier courante comme note-id (1 arg) }
  { SetFilePointer(handle,0,NULL,FILE_CURRENT=1) → position = note ID }
  BinDefineLabel('_SASRT_fnote');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_fnote_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);
  BinJccLabel(4,'_fnote_err');
  BinEmit8($6A); BinEmit8($01);                   { push 1 (FILE_CURRENT) }
  BinEmit8($6A); BinEmit8($00);
  BinEmit8($6A); BinEmit8($00);
  BinEmit8($50);                                    { push eax (handle) }
  BinCallImport('_SetFilePointer@16');              { eax = position courante }
  BinJmpLabel('_fnote_done');
  BinDefineLabel('_fnote_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fnote_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fopen(fileref,mode): ouvre fichier Win32, retourne fid 1..16 ou 0 }
  { [ebp+8]=path [ebp+12]=mode('I'=lect 'O'=ecrit 'A'=ajout 'U'=maj). 0=echec. }
  { SIB [esi+ebx*4]: scale=10,idx=011(ebx),base=110(esi) → 10 011 110 = 0x9E   }
  BinDefineLabel('_SASRT_fopen');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);     { push ebx esi edi }
  { Chercher slot libre (_sas_fid_h[i]==-1) }
  BinEmit8($31); BinEmit8($DB);                    { xor ebx,ebx (slot=0) }
  BinMovRegLabel(6,'_sas_fid_h');                  { mov esi,_sas_fid_h }
  BinDefineLabel('_fop_scan');
  BinEmit8($83); BinEmit8($3C); BinEmit8($9E); BinEmit8($FF);  { cmp [esi+ebx*4],-1 }
  BinJccLabel(4,'_fop_found');                     { je _fop_found }
  BinEmit8($43);                                   { inc ebx }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(2,'_fop_scan');                      { jb _fop_scan }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (table pleine) }
  BinJmpLabel('_fop_done');
  BinDefineLabel('_fop_found');
  { Determiner flags selon mode[0] : edi=dwAccess, edx=dwCreation }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);    { mov edi,[ebp+12] (mode ptr) }
  BinEmit8($B8); BinEmit32(LongInt($80000000));    { mov eax,GENERIC_READ (defaut I) }
  BinEmit8($BA); BinEmit32(3);                     { mov edx,OPEN_EXISTING }
  BinEmit8($85); BinEmit8($FF);                    { test edi,edi }
  BinJccLabel(4,'_fop_create');                    { je (null → mode I) }
  BinEmit8($8A); BinEmit8($0F);                    { mov cl,[edi] }
  BinEmit8($80); BinEmit8($F9); BinEmit8($4F);    { cmp cl,'O' }
  BinJccLabel(5,'_fop_chk_a');                     { jne _fop_chk_a }
  BinEmit8($B8); BinEmit32($40000000);             { mov eax,GENERIC_WRITE }
  BinEmit8($BA); BinEmit32(2);                     { mov edx,CREATE_ALWAYS }
  BinJmpLabel('_fop_create');
  BinDefineLabel('_fop_chk_a');
  BinEmit8($80); BinEmit8($F9); BinEmit8($41);    { cmp cl,'A' }
  BinJccLabel(5,'_fop_chk_u');                     { jne _fop_chk_u }
  BinEmit8($B8); BinEmit32($40000000);             { mov eax,GENERIC_WRITE }
  BinEmit8($BA); BinEmit32(4);                     { mov edx,OPEN_ALWAYS }
  BinJmpLabel('_fop_create');
  BinDefineLabel('_fop_chk_u');
  BinEmit8($80); BinEmit8($F9); BinEmit8($55);    { cmp cl,'U' }
  BinJccLabel(5,'_fop_create');                    { jne (default I) }
  BinEmit8($B8); BinEmit32(LongInt($C0000000));    { mov eax,GENERIC_READ or WRITE }
  BinDefineLabel('_fop_create');
  { CreateFileA(path,access,0,NULL,creation,FILE_ATTR_NORMAL,NULL) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (hTemplateFile) }
  BinEmit8($6A); BinEmit8($80);                   { push 0x80 (FILE_ATTRIBUTE_NORMAL) }
  BinEmit8($52);                                   { push edx (dwCreationDisposition) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (lpSecurityAttributes) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (dwShareMode) }
  BinEmit8($50);                                   { push eax (dwDesiredAccess) }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);   { push [ebp+8] (lpFileName) }
  BinCallImport('_CreateFileA@28');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);   { cmp eax,-1 (INVALID_HANDLE_VALUE) }
  BinJccLabel(4,'_fop_fail');                      { je _fop_fail }
  { Stocker handle : [esi+ebx*4]=eax }
  BinEmit8($89); BinEmit8($04); BinEmit8($9E);   { mov [esi+ebx*4],eax }
  { Initialiser sep[slot]=' ', wl[slot]=0, rp[slot]=0 }
  BinMovRegLabel(0,'_sas_fid_sep');               { mov eax,_sas_fid_sep }
  BinEmit8($C6); BinEmit8($04); BinEmit8($18); BinEmit8($20); { mov [eax+ebx*1],0x20 }
  BinMovRegLabel(0,'_sas_fid_wl');                { mov eax,_sas_fid_wl }
  BinEmit8($C7); BinEmit8($04); BinEmit8($98); BinEmit32(0); { mov [eax+ebx*4],0 }
  BinMovRegLabel(0,'_sas_fid_rp');               { mov eax,_sas_fid_rp }
  BinEmit8($C7); BinEmit8($04); BinEmit8($98); BinEmit32(0); { mov [eax+ebx*4],0 }
  { Pour mode 'A' : SetFilePointer(handle,0,NULL,FILE_END=2) }
  BinEmit8($85); BinEmit8($FF);                   { test edi,edi }
  BinJccLabel(4,'_fop_ok');                        { je (null mode → pas seek) }
  BinEmit8($80); BinEmit8($3F); BinEmit8($41);   { cmp byte[edi],'A' }
  BinJccLabel(5,'_fop_ok');                        { jne }
  BinMovRegLabel(0,'_sas_fid_h');                 { mov eax,_sas_fid_h }
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);   { mov eax,[eax+ebx*4] handle }
  BinEmit8($6A); BinEmit8($02);                   { push 2 (FILE_END) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (lpDistanceToMoveHigh) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (lDistanceToMove) }
  BinEmit8($50);                                   { push eax (hFile) }
  BinCallImport('_SetFilePointer@16');
  BinDefineLabel('_fop_ok');
  BinEmit8($8D); BinEmit8($43); BinEmit8($01);   { lea eax,[ebx+1] (fid=slot+1) }
  BinJmpLabel('_fop_done');
  BinDefineLabel('_fop_fail');
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (echec) }
  BinDefineLabel('_fop_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);   { pop edi esi ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_foptnum(fid): 0 options disponibles (fid valide), -1 sinon (1 arg) }
  BinDefineLabel('_SASRT_foptnum');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_foptn_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF);
  BinJccLabel(4,'_foptn_err');
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (0 options) }
  BinJmpLabel('_foptn_done');
  BinDefineLabel('_foptn_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_foptn_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fpoint(fid,note): SetFilePointer(note,FILE_BEGIN), 0=OK -1=err (2 args) }
  BinDefineLabel('_SASRT_fpoint');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_fpt_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);
  BinJccLabel(4,'_fpt_err');
  BinEmit8($6A); BinEmit8($00);                   { push 0 (FILE_BEGIN) }
  BinEmit8($6A); BinEmit8($00);
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);   { push [ebp+12] (note=offset) }
  BinEmit8($50);                                    { push eax (handle) }
  BinCallImport('_SetFilePointer@16');
  BinEmit8($31); BinEmit8($C0);
  BinJmpLabel('_fpt_done');
  BinDefineLabel('_fpt_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fpt_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fpos(fid,col): positionne wbuf a col-1 (pad espaces), 0=OK -1=err (2 args) }
  { [ebp+8]=fid [ebp+12]=col(1-based). EDI=&wbuf[slot]. }
  BinDefineLabel('_SASRT_fpos');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($57);                    { push ebx edi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_fpos_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF);
  BinJccLabel(4,'_fpos_err');
  { ecx = col-1 (target wlen) }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);    { mov ecx,[ebp+12] }
  BinEmit8($49);                                    { dec ecx }
  BinEmit8($83); BinEmit8($F9); BinEmit8($00);    { cmp ecx,0 }
  BinJccLabel(12,'_fpos_err');                      { jl }
  BinEmit8($83); BinEmit8($F9); BinEmit8($FE);    { cmp ecx,254 }
  BinJccLabel(15,'_fpos_err');                      { jg }
  { edi = &wbuf[slot] }
  BinEmit8($89); BinEmit8($DF);                    { mov edi,ebx }
  BinEmit8($C1); BinEmit8($E7); BinEmit8($08);    { shl edi,8 }
  BinMovRegLabel(0,'_sas_fid_wb');
  BinEmit8($01); BinEmit8($C7);                    { add edi,eax }
  { eax = wlen courant }
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);    { mov eax,[eax+ebx*4] }
  BinDefineLabel('_fpos_pad');
  BinEmit8($39); BinEmit8($C8);                    { cmp eax,ecx }
  BinJccLabel(13,'_fpos_set');                      { jge done }
  BinEmit8($C6); BinEmit8($04); BinEmit8($07); BinEmit8($20); { mov [edi+eax*1],0x20 SIB=00 000 111=0x07 }
  BinEmit8($40);                                    { inc eax }
  BinJmpLabel('_fpos_pad');
  BinDefineLabel('_fpos_set');
  { wlen = ecx }
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($89); BinEmit8($0C); BinEmit8($98);    { mov [eax+ebx*4],ecx }
  BinEmit8($31); BinEmit8($C0);
  BinJmpLabel('_fpos_done');
  BinDefineLabel('_fpos_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fpos_done');
  BinEmit8($5F); BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fput(fid,str): ajoute str au wbuf[slot], 0=OK -1=err (2 args) }
  { [ebp+8]=fid [ebp+12]=str. ESI=src EDI=&wbuf[slot]+wlen. }
  BinDefineLabel('_SASRT_fput');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);    { push ebx esi edi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] }
  BinEmit8($4B);                                    { dec ebx }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_fput_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF); { cmp [eax+ebx*4],-1 }
  BinJccLabel(4,'_fput_err');
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);    { mov esi,[ebp+12] (str src) }
  BinEmit8($85); BinEmit8($F6);                    { test esi,esi }
  BinJccLabel(4,'_fput_ok');                        { je null str → OK no-op }
  { edi = _sas_fid_wb + slot*256 + wlen }
  BinEmit8($89); BinEmit8($DF);                    { mov edi,ebx }
  BinEmit8($C1); BinEmit8($E7); BinEmit8($08);    { shl edi,8 }
  BinMovRegLabel(0,'_sas_fid_wb');
  BinEmit8($01); BinEmit8($C7);                    { add edi,eax }
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($03); BinEmit8($3C); BinEmit8($98);    { add edi,[eax+ebx*4] (+wlen) }
  { edx = place restante = 254 - wlen }
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($8B); BinEmit8($14); BinEmit8($98);    { mov edx,[eax+ebx*4] wlen }
  BinEmit8($BA); BinEmit32(254);                   { mov eax,254 }
  BinEmit8($29); BinEmit8($D0);                    { sub eax,edx }
  BinEmit8($89); BinEmit8($C2);                    { mov edx,eax (remaining) }
  BinDefineLabel('_fput_copy');
  BinEmit8($85); BinEmit8($D2);                    { test edx,edx }
  BinJccLabel(4,'_fput_ok');                        { jz buffer plein }
  BinEmit8($8A); BinEmit8($06);                    { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                    { test al,al }
  BinJccLabel(4,'_fput_ok');                        { jz fin chaine }
  BinEmit8($88); BinEmit8($07);                    { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                    { inc esi; inc edi }
  BinEmit8($4A);                                    { dec edx }
  BinMovRegLabel(0,'_sas_fid_wl');
  BinEmit8($FF); BinEmit8($04); BinEmit8($98);    { inc [eax+ebx*4] (wl++) }
  BinJmpLabel('_fput_copy');
  BinDefineLabel('_fput_ok');
  BinEmit8($31); BinEmit8($C0);
  BinJmpLabel('_fput_ret');
  BinDefineLabel('_fput_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fput_ret');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fread(fid): lit enreg dans rbuf[slot], 0=OK -1=EOF/err (1 arg) }
  { [ebp+8]=fid. Lit octet par octet jusqu a LF/EOF → null-termine rbuf.    }
  { Locaux: [ebp-4]=bytesread [ebp-8]=handle. ESI=&rbuf[slot] EDI=writepos. }
  BinDefineLabel('_SASRT_fread');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);    { sub esp,8 }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);    { push ebx esi edi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] }
  BinEmit8($4B);                                    { dec ebx (slot) }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_frd_err');                        { jae }
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);    { mov eax,[eax+ebx*4] handle }
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);    { cmp eax,-1 }
  BinJccLabel(4,'_frd_err');                        { je }
  BinEmit8($89); BinEmit8($45); BinEmit8($F8);    { mov [ebp-8],eax (save handle) }
  { esi = _sas_fid_rb + slot*256 }
  BinEmit8($89); BinEmit8($DE);                    { mov esi,ebx }
  BinEmit8($C1); BinEmit8($E6); BinEmit8($08);    { shl esi,8 }
  BinMovRegLabel(0,'_sas_fid_rb');
  BinEmit8($01); BinEmit8($C6);                    { add esi,eax }
  BinEmit8($31); BinEmit8($FF);                    { xor edi,edi (writepos=0) }
  BinDefineLabel('_frd_loop');
  BinEmit8($83); BinEmit8($FF); BinEmit8($FF);    { cmp edi,255 }
  BinJccLabel(13,'_frd_eol');                       { jge buffer plein→eol }
  { ReadFile(handle,&rbuf[slot][edi],1,&bytesread,NULL) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 }
  BinEmit8($8D); BinEmit8($45); BinEmit8($FC);    { lea eax,[ebp-4] }
  BinEmit8($50);                                    { push eax (&bytesread) }
  BinEmit8($6A); BinEmit8($01);                   { push 1 }
  BinEmit8($8D); BinEmit8($04); BinEmit8($3E);    { lea eax,[esi+edi] }
  BinEmit8($50);                                    { push eax (buf[edi]) }
  BinEmit8($FF); BinEmit8($75); BinEmit8($F8);   { push [ebp-8] (handle) }
  BinCallImport('_ReadFile@20');
  BinEmit8($85); BinEmit8($C0);                    { test eax,eax }
  BinJccLabel(4,'_frd_err');                        { jz ReadFile failed }
  BinEmit8($83); BinEmit8($7D); BinEmit8($FC); BinEmit8($00); { cmp [ebp-4],0 }
  BinJccLabel(4,'_frd_maybe_eof');                  { je 0 bytes = potentiel EOF }
  { traiter octet recu }
  BinEmit8($8A); BinEmit8($04); BinEmit8($3E);    { mov al,[esi+edi] }
  BinEmit8($3C); BinEmit8($0D);                    { cmp al,0x0D (CR) }
  BinJccLabel(4,'_frd_loop');                       { je skip CR }
  BinEmit8($3C); BinEmit8($0A);                    { cmp al,0x0A (LF) }
  BinJccLabel(4,'_frd_eol');                        { je fin de ligne }
  BinEmit8($47);                                    { inc edi }
  BinJmpLabel('_frd_loop');
  BinDefineLabel('_frd_maybe_eof');
  BinEmit8($85); BinEmit8($FF);                    { test edi,edi }
  BinJccLabel(4,'_frd_err');                        { jz EOF vide → -1 }
  BinDefineLabel('_frd_eol');
  BinEmit8($C6); BinEmit8($04); BinEmit8($3E); BinEmit8($00); { mov [esi+edi],0 }
  BinMovRegLabel(0,'_sas_fid_rp');
  BinEmit8($C7); BinEmit8($04); BinEmit8($98); BinEmit32(0); { mov [eax+ebx*4],0 }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (0=OK) }
  BinJmpLabel('_frd_ret');
  BinDefineLabel('_frd_err');
  BinEmit8($B8); BinEmit32(-1);                    { mov eax,-1 }
  BinDefineLabel('_frd_ret');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);   { pop edi esi ebx }
  BinEmit8($83); BinEmit8($C4); BinEmit8($08);    { add esp,8 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_frewind(fid): SetFilePointer(FILE_BEGIN), 0=OK -1=err (1 arg) }
  BinDefineLabel('_SASRT_frewind');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_frwd_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($8B); BinEmit8($04); BinEmit8($98);    { mov eax,[eax+ebx*4] handle }
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);
  BinJccLabel(4,'_frwd_err');
  BinEmit8($6A); BinEmit8($00);                   { push 0 (FILE_BEGIN) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (MoveHigh=NULL) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (distance=0) }
  BinEmit8($50);                                    { push eax (handle) }
  BinCallImport('_SetFilePointer@16');
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax }
  BinJmpLabel('_frwd_done');
  BinDefineLabel('_frwd_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_frwd_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_frlen(fid): strlen(rbuf[slot]) = longueur enreg lu (1 arg) }
  BinDefineLabel('_SASRT_frlen');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56);                    { push ebx esi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] }
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_frln_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF);
  BinJccLabel(4,'_frln_err');
  BinEmit8($89); BinEmit8($DE);                    { mov esi,ebx }
  BinEmit8($C1); BinEmit8($E6); BinEmit8($08);    { shl esi,8 }
  BinMovRegLabel(0,'_sas_fid_rb');
  BinEmit8($01); BinEmit8($C6);                    { add esi,eax }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (counter) }
  BinDefineLabel('_frln_loop');
  BinEmit8($80); BinEmit8($3C); BinEmit8($06); BinEmit8($00); { cmp [esi+eax*1],0 -- SIB 00 000 110=0x06 }
  BinJccLabel(4,'_frln_done');
  BinEmit8($40);                                    { inc eax }
  BinJmpLabel('_frln_loop');
  BinDefineLabel('_frln_done');
  BinJmpLabel('_frln_ret');
  BinDefineLabel('_frln_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_frln_ret');
  BinEmit8($5E); BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fsep(fid,char_str): definit separateur FGET pour ce fid (2 args) }
  { [ebp+8]=fid [ebp+12]=sep_str. sep=premier car, null/null-ptr → espace.    }
  BinDefineLabel('_SASRT_fsep');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);
  BinEmit8($4B);
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);
  BinJccLabel(3,'_fsep_err');
  BinMovRegLabel(0,'_sas_fid_h');
  BinEmit8($83); BinEmit8($3C); BinEmit8($98); BinEmit8($FF);
  BinJccLabel(4,'_fsep_err');
  { cl = sep char }
  BinEmit8($B1); BinEmit8($20);                    { mov cl,0x20 (espace defaut) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);    { mov eax,[ebp+12] str ptr }
  BinEmit8($85); BinEmit8($C0);                    { test eax,eax }
  BinJccLabel(4,'_fsep_store');                     { je null → espace }
  BinEmit8($8A); BinEmit8($08);                    { mov cl,[eax] premier car }
  BinEmit8($84); BinEmit8($C9);                    { test cl,cl }
  BinJccLabel(5,'_fsep_store');                     { jnz ok }
  BinEmit8($B1); BinEmit8($20);                    { mov cl,0x20 (chaine vide → espace) }
  BinDefineLabel('_fsep_store');
  BinMovRegLabel(0,'_sas_fid_sep');
  BinEmit8($88); BinEmit8($0C); BinEmit8($18);    { mov [eax+ebx*1],cl SIB=00 011 000=0x18 }
  BinEmit8($31); BinEmit8($C0);
  BinJmpLabel('_fsep_done');
  BinDefineLabel('_fsep_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fsep_done');
  BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_fuzz(x): retourne x tel quel (identite pour entiers) }
  { FUZZ retourne l entier le plus proche si |x - round(x)| < 1E-12 }
  { Sur entiers la difference est toujours 0, donc retourne x.       }
  BinDefineLabel('_SASRT_fuzz');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8]       }
  BinEmit8($5D);                                  { pop ebp               }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                 }

  { --- _SASRT_fwrite(fid): WriteFile(wbuf+LF), reset wlen, 0=OK -1=err (1 arg) }
  { [ebp+8]=fid. ESI=_sas_fid_h base, EBX=slot. Local [ebp-4]=byteswritten.  }
  { SIB [esi+ebx*4]: scale=10,idx=011,base=110 → 10 011 110 = 0x9E           }
  BinDefineLabel('_SASRT_fwrite');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);    { sub esp,4 ([ebp-4]=byteswritten) }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);    { push ebx esi edi }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8] fid }
  BinEmit8($4B);                                    { dec ebx (slot) }
  BinEmit8($83); BinEmit8($FB); BinEmit8($10);    { cmp ebx,16 }
  BinJccLabel(3,'_fwrt_err');
  BinMovRegLabel(6,'_sas_fid_h');                  { mov esi,_sas_fid_h }
  BinEmit8($8B); BinEmit8($3C); BinEmit8($9E);    { mov edi,[esi+ebx*4] handle }
  BinEmit8($83); BinEmit8($FF); BinEmit8($FF);    { cmp edi,-1 }
  BinJccLabel(4,'_fwrt_err');
  { ecx = wlen }
  BinMovRegLabel(6,'_sas_fid_wl');                 { mov esi,_sas_fid_wl }
  BinEmit8($8B); BinEmit8($0C); BinEmit8($9E);    { mov ecx,[esi+ebx*4] wlen }
  BinEmit8($83); BinEmit8($F9); BinEmit8($FE);    { cmp ecx,254 }
  BinJccLabel(14,'_fwrt_addnl');                    { jle }
  BinEmit8($B9); BinEmit32(254);                   { mov ecx,254 }
  BinDefineLabel('_fwrt_addnl');
  { eax = &wbuf[slot] = _sas_fid_wb + slot*256 }
  BinEmit8($89); BinEmit8($D8);                    { mov eax,ebx }
  BinEmit8($C1); BinEmit8($E0); BinEmit8($08);    { shl eax,8 }
  BinMovRegLabel(6,'_sas_fid_wb');                 { mov esi,_sas_fid_wb }
  BinEmit8($01); BinEmit8($F0);                    { add eax,esi }
  { wbuf[wlen] = LF : [eax+ecx*1] ; SIB scale=1,idx=ecx=1,base=eax=0 → 00 001 000 = 0x08 }
  BinEmit8($C6); BinEmit8($04); BinEmit8($08); BinEmit8($0A); { mov [eax+ecx],LF }
  BinEmit8($41);                                    { inc ecx (write wlen+1) }
  { WriteFile(handle,wbuf,ecx,&bw,NULL) }
  BinEmit8($6A); BinEmit8($00);                   { push 0 (lpOverlapped) }
  BinEmit8($8D); BinEmit8($75); BinEmit8($FC);    { lea esi,[ebp-4] }
  BinEmit8($56);                                    { push esi (&byteswritten) }
  BinEmit8($51);                                    { push ecx }
  BinEmit8($50);                                    { push eax (wbuf ptr) }
  BinEmit8($57);                                    { push edi (handle) }
  BinCallImport('_WriteFile@20');
  { reset wlen = 0 }
  BinMovRegLabel(6,'_sas_fid_wl');
  BinEmit8($C7); BinEmit8($04); BinEmit8($9E); BinEmit32(0); { mov [esi+ebx*4],0 }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax (0=OK) }
  BinJmpLabel('_fwrt_ret');
  BinDefineLabel('_fwrt_err');
  BinEmit8($B8); BinEmit32(-1);
  BinDefineLabel('_fwrt_ret');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);
  BinEmit8($83); BinEmit8($C4); BinEmit8($04);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_gaminv(p,shape): quantile Gamma approx entier (p en pourcentage) }
  BinDefineLabel('_SASRT_gaminv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);                                      { push ebx }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);        { mov ebx,[ebp+12] shape }
  BinEmit8($85); BinEmit8($DB);                       { test ebx,ebx }
  BinJccLabel(14, '_gaminv_zero');                    { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);        { mov eax,[ebp+8] p }
  BinEmit8($85); BinEmit8($C0);                       { test eax,eax }
  BinJccLabel(14, '_gaminv_zero');                    { jle zero }
  BinEmit8($31); BinEmit8($C9);                       { xor ecx,ecx z=0 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5A);        { cmp p,90 }
  BinJccLabel(12, '_gaminv_calc');                    { jl calc }
  BinEmit8($B9); BinEmit32(1);                        { mov ecx,1 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5F);        { cmp p,95 }
  BinJccLabel(12, '_gaminv_calc');                    { jl calc }
  BinEmit8($B9); BinEmit32(2);                        { mov ecx,2 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($63);        { cmp p,99 }
  BinJccLabel(12, '_gaminv_calc');                    { jl calc }
  BinEmit8($B9); BinEmit32(3);                        { mov ecx,3 }
  BinDefineLabel('_gaminv_calc');
  BinEmit8($51);                                      { push ecx }
  BinEmit8($53);                                      { push shape }
  BinCallLabel('_SASRT_sqrt');                        { eax=sqrt(shape) }
  BinEmit8($59);                                      { pop ecx }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);        { imul eax,ecx }
  BinEmit8($01); BinEmit8($D8);                       { add eax,ebx }
  BinJmpLabel('_gaminv_done');
  BinDefineLabel('_gaminv_zero');
  BinEmit8($31); BinEmit8($C0);                       { xor eax,eax }
  BinDefineLabel('_gaminv_done');
  BinEmit8($5B);                                      { pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_gamma(x): LongInt --- (x-1)! pour x entier 1..13, 0 sinon   }
  { [ebp+8]=x. 1<=x<=13: (x-1)! par LOOP (EBX*=ECX). x<1 ou x>=14 => 0. }
  BinDefineLabel('_SASRT_gamma');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($83); BinEmit8($F8); BinEmit8($01);           { cmp eax,1 }
  BinJccLabel(12, '_gamma_zero');                         { jl .zero (x<1) }
  BinEmit8($83); BinEmit8($F8); BinEmit8($0E);           { cmp eax,14 }
  BinJccLabel(13, '_gamma_zero');                         { jge .zero (x>=14, debordement) }
  BinEmit8($48);                                          { dec eax  n=x-1 }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(4, '_gamma_one');                           { je .one (x=1: 0!=1) }
  BinEmit8($89); BinEmit8($C1);                          { mov ecx,eax }
  BinEmit8($BB); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ebx,1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($D9);           { .loop: imul ebx,ecx }
  BinEmit8($E2); BinEmit8($FB);                          { loop .loop (E2 FB = -5) }
  BinEmit8($89); BinEmit8($D8);                          { mov eax,ebx }
  BinJmpLabel('_gamma_done');
  BinDefineLabel('_gamma_one');
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinJmpLabel('_gamma_done');
  BinDefineLabel('_gamma_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_gamma_done');
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_getvarn(dsid,varnum): valeur numerique minimale si ids valides }
  BinDefineLabel('_SASRT_getvarn');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14, '_getvarn_zero');                      { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] varnum }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(15, '_getvarn_done');                      { jg done }
  BinDefineLabel('_getvarn_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_getvarn_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_hbound(array): LongInt 1 --- fallback (inline intercepte normalement) }
  BinDefineLabel('_SASRT_hbound');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);   { push ebp; mov ebp,esp }
  BinEmit8($B8); BinEmit32(1);                    { mov eax,1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_hms(h,m,s): LongInt --- h*3600+m*60+s (27 octets) }
  { [ebp+8]=h [ebp+12]=m [ebp+16]=s. }
  BinDefineLabel('_SASRT_hms');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] h }
  BinEmit8($69); BinEmit8($C0); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { imul eax,3600 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);                { mov ecx,[ebp+12] m }
  BinEmit8($6B); BinEmit8($C9); BinEmit8($3C);               { imul ecx,60 }
  BinEmit8($01); BinEmit8($C8);                               { add eax,ecx }
  BinEmit8($03); BinEmit8($45); BinEmit8($10);               { add eax,[ebp+16] s }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_hour(time): LongInt --- floor(time/3600) (18 octets) }
  BinDefineLabel('_SASRT_hour');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { mov ecx,3600 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_ibessel(nu,x,kode): I_0(x) pour nu=0,kode=1 via serie FPU (3 args) }
  { I_0(x)=sum (x/2)^2k/(k!)^2, recurrence term_k=term(k-1)*h2/k^2, h2=(x/2)^2 }
  { [ebp+8]=nu [ebp+12]=x [ebp+16]=kode                                              }
  { Locaux (sub esp,24): [ebp-4]=k [ebp-6/-8]=CW [ebp-16]=h2 [ebp-24]=acc           }
  BinDefineLabel('_SASRT_ibessel');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($18);           { sub esp,24 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] nu }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(5,'_ibes_zero');                            { jnz: nu!=0 }
  BinEmit8($83); BinEmit8($7D); BinEmit8($10); BinEmit8($01); { cmp [ebp+16],1 kode }
  BinJccLabel(5,'_ibes_zero');                            { jnz: kode!=1 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(12,'_ibes_zero');                           { jl: x<0 }
  BinJccLabel(4,'_ibes_one');                             { jz: x=0 → I_0(0)=1 }
  { Compute h2=(x/2)^2=x^2/4 → [ebp-16] }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] x }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st → x^2 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) → 2 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) → 4 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st → x^2/4 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] h2 }
  { acc=1.0 in [ebp-24], term=1.0 in ST(0) }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 term=1 }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] acc=1 }
  { k=1, ECX=30 iterations }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1); { mov [ebp-4],1 }
  BinEmit8($B9); BinEmit8($1E); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,30 }
  BinDefineLabel('_ibes_loop');
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld qword[ebp-16] h2 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st term*h2 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] k }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) k^2 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st new_term }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy new_term }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);           { fadd qword[ebp-24] +acc }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] store }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc [ebp-4] k++ }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_ibes_loop');                            { jnz }
  { Discard last term, load acc }
  BinEmit8($DD); BinEmit8($D8);                          { fstp st(0) discard }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E8);           { fld qword[ebp-24] acc }
  { Floor via truncation (acc positive for x>0) }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 truncate }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  BinDefineLabel('_ibes_one');
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  BinDefineLabel('_ibes_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_indexc(str,chars): LongInt --- 1ere position dans str d un char de chars (46 octets) }
  { Retourne la position 1-basee du 1er caractere de str qui apparait dans chars, ou 0.            }
  { [ebp+8]=str, [ebp+12]=chars                                                                    }
  BinDefineLabel('_SASRT_indexc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);           { push esi; push edi; push ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  str }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax  pos=0 }
  { .outer (offset 11): }
  BinEmit8($40);                                          { inc eax  pos++ }
  BinEmit8($8A); BinEmit8($16);                          { mov dl,[esi]  c=*str }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinEmit8($74); BinEmit8($13);                          { jz .notfound (+19 → 37) }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12]  chars }
  { .inner (offset 21): }
  BinEmit8($8A); BinEmit8($1F);                          { mov bl,[edi] }
  BinEmit8($84); BinEmit8($DB);                          { test bl,bl }
  BinEmit8($74); BinEmit8($07);                          { jz .next (+7 → 34) }
  BinEmit8($3A); BinEmit8($D3);                          { cmp dl,bl }
  BinEmit8($74); BinEmit8($08);                          { je .done (+8 → 39) }
  BinEmit8($47);                                          { inc edi }
  BinEmit8($EB); BinEmit8($F3);                          { jmp .inner (-13 → 21) }
  { .next (offset 34): }
  BinEmit8($46);                                          { inc esi  next str char }
  BinEmit8($EB); BinEmit8($E6);                          { jmp .outer (-26 → 11) }
  { .notfound (offset 37): }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax  return 0 }
  { .done (offset 39): }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);           { pop ebx; pop edi; pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_indexw(str,word): LongInt --- recherche de sous-mot (= INDEX pour ASCII) }
  { Note: INDEXW cherche un mot entier (delimite par espaces). Pour ASCII 1 octet/char,  }
  { le comportement est identique a INDEX.                                                }
  BinDefineLabel('_SASRT_indexw');
  BinJmpLabel('_SASRT_index');

  { --- _SASRT_input(source,informat): LongInt --- atoi(source), informat ignore }
  { [ebp+8]=source(ptr) [ebp+12]=informat. EBX=signe ESI=ptr. ret 8.          }
  BinDefineLabel('_SASRT_input');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56);                          { push ebx; push esi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] source }
  { Sauter les espaces initiaux }
  BinDefineLabel('_input_skip_ws');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($3C); BinEmit8($20);                          { cmp al,' ' }
  BinJccLabel(5,'_input_sign');                          { jne }
  BinEmit8($46);                                         { inc esi }
  BinJmpLabel('_input_skip_ws');
  BinDefineLabel('_input_sign');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax (result=0) }
  BinEmit8($31); BinEmit8($DB);                          { xor ebx,ebx (sign=0) }
  BinEmit8($3C); BinEmit8($2D);                          { cmp al,'-' }
  BinJccLabel(5,'_input_chkplus');                       { jne }
  BinEmit8($46);                                         { inc esi }
  BinEmit8($BB); BinEmit32(1);                           { mov ebx,1 }
  BinJmpLabel('_input_digits');
  BinDefineLabel('_input_chkplus');
  BinEmit8($3C); BinEmit8($2B);                          { cmp al,'+' }
  BinJccLabel(5,'_input_digits');                        { jne }
  BinEmit8($46);                                         { inc esi }
  BinDefineLabel('_input_digits');
  BinDefineLabel('_input_digloop');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($2C); BinEmit8($30);                          { sub al,'0' }
  BinEmit8($3C); BinEmit8($09);                          { cmp al,9 }
  BinJccLabel(7,'_input_done');                          { ja (unsigned >) }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C8);          { movzx ecx,al }
  BinEmit8($69); BinEmit8($C0); BinEmit32(10);          { imul eax,eax,10 }
  BinEmit8($01); BinEmit8($C8);                          { add eax,ecx }
  BinEmit8($46);                                         { inc esi }
  BinJmpLabel('_input_digloop');
  BinDefineLabel('_input_done');
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(4,'_input_ret');                           { jz }
  BinEmit8($F7); BinEmit8($D8);                          { neg eax }
  BinDefineLabel('_input_ret');
  BinEmit8($5E); BinEmit8($5B);                          { pop esi; pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_inputn(source,informat): LongInt --- alias de _SASRT_input }
  BinDefineLabel('_SASRT_inputn');
  BinJmpLabel('_SASRT_input');

  { --- _SASRT_intck(interval,from,to): LongInt --- compte intervalles de dates }
  { Supporte 'D'=DAY, 'W'=WEEK, 'M'=MONTH, 'Q'=QTR, 'Y'=YEAR (insensible casse) }
  { [ebp+8]=interval (PChar), [ebp+12]=from, [ebp+16]=to                          }
  BinDefineLabel('_SASRT_intck');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx; push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] interval }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($06);           { movzx eax,byte[esi] }
  BinEmit8($24); BinEmit8($DF);                          { and al,0xDF  uppercase }
  BinEmit8($3C); BinEmit8($44); BinJccLabel(4,'_intck_day');   { cmp 'D'; je }
  BinEmit8($3C); BinEmit8($57); BinJccLabel(4,'_intck_week');  { cmp 'W'; je }
  BinEmit8($3C); BinEmit8($4D); BinJccLabel(4,'_intck_month'); { cmp 'M'; je }
  BinEmit8($3C); BinEmit8($51); BinJccLabel(4,'_intck_qtr');   { cmp 'Q'; je }
  BinEmit8($3C); BinEmit8($59); BinJccLabel(4,'_intck_year');  { cmp 'Y'; je }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax (inconnu=0) }
  BinJmpLabel('_intck_done');

  BinDefineLabel('_intck_day');                           { DAY: to-from }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] to }
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);           { sub eax,[ebp+12] from }
  BinJmpLabel('_intck_done');

  BinDefineLabel('_intck_week');                          { WEEK: (to-from)/7 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);
  BinEmit8($2B); BinEmit8($45); BinEmit8($0C);
  BinEmit8($99);                                          { cdq }
  BinEmit8($B9); BinEmit8($07); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(7) }
  BinJmpLabel('_intck_done');

  BinDefineLabel('_intck_month');                         { MONTH: (year_to-year_from)*12+(month_to-month_from) }
  BinMovRegLabel(7, '_sas_ymd');                          { mov edi,&_sas_ymd (preserved par ymd_calc!) }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push [ebp+12] from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax year_from }
  BinEmit8($8B); BinEmit8($77); BinEmit8($04);           { mov esi,[edi+4] month_from }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push [ebp+16] to }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_to }
  BinEmit8($2B); BinEmit8($C3);                          { sub eax,ebx year_diff }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($0C);           { imul eax,12 }
  BinEmit8($03); BinEmit8($47); BinEmit8($04);           { add eax,[edi+4] +month_to }
  BinEmit8($2B); BinEmit8($C6);                          { sub eax,esi -month_from }
  BinJmpLabel('_intck_done');

  BinDefineLabel('_intck_qtr');                           { QTR: year_diff*4+((m_to-1)/3-(m_from-1)/3) }
  BinMovRegLabel(7, '_sas_ymd');
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax }
  BinEmit8($8B); BinEmit8($77); BinEmit8($04);           { mov esi,[edi+4] month_from }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push to }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_to }
  BinEmit8($2B); BinEmit8($C3);                          { sub eax,ebx year_diff }
  BinEmit8($50);                                          { push eax save year_diff }
  BinEmit8($8B); BinEmit8($47); BinEmit8($04);           { mov eax,[edi+4] month_to }
  BinEmit8($48);                                          { dec eax month_to-1 }
  BinEmit8($99);                                          { cdq }
  BinEmit8($B9); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(3) => (month_to-1)/3 }
  BinEmit8($50);                                          { push eax save qtr_offset_to }
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi month_from }
  BinEmit8($48);                                          { dec eax month_from-1 }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(3) => (month_from-1)/3 }
  BinEmit8($59);                                          { pop ecx=qtr_offset_to }
  BinEmit8($29); BinEmit8($C1);                          { sub ecx,eax qtr_to-qtr_from }
  BinEmit8($58);                                          { pop eax year_diff }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($04);           { imul eax,4 year_diff*4 }
  BinEmit8($03); BinEmit8($C1);                          { add eax,ecx }
  BinJmpLabel('_intck_done');

  BinDefineLabel('_intck_year');                          { YEAR: year_to-year_from }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push to }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_to }
  BinEmit8($2B); BinEmit8($C3);                          { sub eax,ebx }

  BinDefineLabel('_intck_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi; esi; ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);           { ret 12 }

  { --- _SASRT_intnx(interval,from,n): LongInt --- avance d un intervalle }
  { Supporte 'D'=DAY, 'W'=WEEK, 'M'=MONTH, 'Q'=QTR, 'Y'=YEAR (insensible casse) }
  { [ebp+8]=interval (PChar), [ebp+12]=from, [ebp+16]=n                          }
  BinDefineLabel('_SASRT_intnx');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx; push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] interval }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($06);           { movzx eax,byte[esi] }
  BinEmit8($24); BinEmit8($DF);                          { and al,0xDF  uppercase }
  BinEmit8($3C); BinEmit8($44); BinJccLabel(4,'_intnx_day');   { cmp 'D'; je }
  BinEmit8($3C); BinEmit8($57); BinJccLabel(4,'_intnx_week');  { cmp 'W'; je }
  BinEmit8($3C); BinEmit8($4D); BinJccLabel(4,'_intnx_month'); { cmp 'M'; je }
  BinEmit8($3C); BinEmit8($51); BinJccLabel(4,'_intnx_qtr');   { cmp 'Q'; je }
  BinEmit8($3C); BinEmit8($59); BinJccLabel(4,'_intnx_year');  { cmp 'Y'; je }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] from (inconnu) }
  BinJmpLabel('_intnx_done');

  BinDefineLabel('_intnx_day');                           { DAY: from+n }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] from }
  BinEmit8($03); BinEmit8($45); BinEmit8($10);           { add eax,[ebp+16] n }
  BinJmpLabel('_intnx_done');

  BinDefineLabel('_intnx_week');                          { WEEK: from+n*7 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] n }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($07);           { imul eax,7 }
  BinEmit8($03); BinEmit8($45); BinEmit8($0C);           { add eax,[ebp+12] from }
  BinJmpLabel('_intnx_done');

  BinDefineLabel('_intnx_month');                         { MONTH: MDY(new_month,1,new_year) }
  BinMovRegLabel(7, '_sas_ymd');                          { mov edi,&_sas_ymd }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax year_from }
  BinEmit8($8B); BinEmit8($77); BinEmit8($04);           { mov esi,[edi+4] month_from }
  { new_month_total = month+n-1 (0-based) }
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi month_from }
  BinEmit8($03); BinEmit8($45); BinEmit8($10);           { add eax,[ebp+16] n }
  BinEmit8($48);                                          { dec eax month+n-1 }
  BinEmit8($99);                                          { cdq }
  BinEmit8($B9); BinEmit8($0C); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(12): eax=year_adj,edx=month_idx }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(13,'_intnx_month_adj');                     { jge .month_adj_ok }
  BinEmit8($48);                                          { dec eax year_adj-- }
  BinEmit8($83); BinEmit8($C2); BinEmit8($0C);           { add edx,12 }
  BinDefineLabel('_intnx_month_adj');
  BinEmit8($42);                                          { inc edx month_new (1-12) }
  BinEmit8($03); BinEmit8($C3);                          { add eax,ebx year_new }
  BinEmit8($50);                                          { push eax year_new }
  BinEmit8($6A); BinEmit8($01);                          { push 1 (day=1) }
  BinEmit8($52);                                          { push edx month_new }
  BinCallLabel('_SASRT_mdy');                             { eax=new SAS date }
  BinJmpLabel('_intnx_done');

  BinDefineLabel('_intnx_qtr');                           { QTR: MDY(new_qtr_month,1,new_year) }
  BinMovRegLabel(7, '_sas_ymd');
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax year_from }
  BinEmit8($8B); BinEmit8($77); BinEmit8($04);           { mov esi,[edi+4] month_from }
  { qtr_from (0-based) = (month-1)/3 }
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi month_from }
  BinEmit8($48);                                          { dec eax }
  BinEmit8($99);                                          { cdq }
  BinEmit8($B9); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(3) eax=qtr_from }
  { new_qtr_total = qtr_from + n }
  BinEmit8($03); BinEmit8($45); BinEmit8($10);           { add eax,[ebp+16] n }
  BinEmit8($99);                                          { cdq }
  BinEmit8($B9); BinEmit8($04); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx(4) eax=year_adj,edx=new_qtr(0-3) }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(13,'_intnx_qtr_adj');                       { jge .qtr_adj_ok }
  BinEmit8($48);                                          { dec eax year_adj-- }
  BinEmit8($83); BinEmit8($C2); BinEmit8($04);           { add edx,4 }
  BinDefineLabel('_intnx_qtr_adj');
  { month_new = new_qtr*3+1 }
  BinEmit8($8D); BinEmit8($4C); BinEmit8($52); BinEmit8($01); { lea ecx,[edx+edx*2+1] }
  BinEmit8($03); BinEmit8($C3);                          { add eax,ebx year_new }
  BinEmit8($50);                                          { push eax year_new }
  BinEmit8($6A); BinEmit8($01);                          { push 1 (day=1) }
  BinEmit8($51);                                          { push ecx month_new }
  BinCallLabel('_SASRT_mdy');                             { eax=new SAS date }
  BinJmpLabel('_intnx_done');

  BinDefineLabel('_intnx_year');                          { YEAR: MDY(1,1,year+n) }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push from }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year_from }
  BinEmit8($03); BinEmit8($45); BinEmit8($10);           { add eax,[ebp+16] n }
  BinEmit8($50);                                          { push eax year_new }
  BinEmit8($6A); BinEmit8($01);                          { push 1 (day=1) }
  BinEmit8($6A); BinEmit8($01);                          { push 1 (month=1=January) }
  BinCallLabel('_SASRT_mdy');                             { eax=new SAS date }

  BinDefineLabel('_intnx_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi; esi; ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);           { ret 12 }

  { --- _SASRT_intrr(cashflow): rendement indicatif entier minimal }
  BinDefineLabel('_SASRT_intrr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] cashflow }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(13, '_intrr_positive');                    { jge positive/zero }
  BinEmit8($B8); BinEmit32(10);                          { mov eax,10 }
  BinJmpLabel('_intrr_done');
  BinDefineLabel('_intrr_positive');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_intrr_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_irr(cashflow): alias de INTRR pour backend entier }
  BinDefineLabel('_SASRT_irr');
  BinJmpLabel('_SASRT_intrr');

  { --- _SASRT_jbessel(nu,x): J_0(x) serie alternante FPU (2 args) }
  { J_0(x)=sum (-1)^k*(x/2)^2k/(k!)^2, recurrence term(k)=term(k-1)*neg_h2/k^2 }
  { [ebp+8]=nu [ebp+12]=x                                                         }
  { Locaux (sub esp,24): [ebp-4]=k [ebp-6/-8]=CW [ebp-16]=neg_h2 [ebp-24]=acc   }
  BinDefineLabel('_SASRT_jbessel');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($18);           { sub esp,24 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] nu }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(5,'_jbes_zero');                            { jnz: nu!=0 -> return 0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(4,'_jbes_one');                             { jz: x=0 -> J_0(0)=1 }
  { Compute neg_h2=-(x/2)^2=-x^2/4 into [ebp-16] }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] x }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> x^2 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) -> 2 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st(0),st(0) -> 4 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st -> x^2/4 }
  BinEmit8($D9); BinEmit8($E0);                          { fchs -> -x^2/4 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] neg_h2 }
  { term=1.0 in ST(0), acc=1.0 in [ebp-24], k=1 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 term=1 }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] acc=1 }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(1); { mov [ebp-4],1 }
  BinEmit8($B9); BinEmit8($1E); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,30 }
  BinDefineLabel('_jbes_loop');
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld qword[ebp-16] neg_h2 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st term*neg_h2 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] k }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) k^2 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st new_term }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) copy new_term }
  BinEmit8($DC); BinEmit8($45); BinEmit8($E8);           { fadd qword[ebp-24] +acc }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] store }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc [ebp-4] k++ }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_jbes_loop');                            { jnz }
  { Discard last term, floor acc to int via round-down mode }
  BinEmit8($DD); BinEmit8($D8);                          { fstp st(0) discard }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E8);           { fld qword[ebp-24] acc }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit32($FFFFF3FF);                   { and eax,~$0C00 clear RC bits }
  BinEmit8($0D); BinEmit32($00000400);                   { or eax,$0400 round-down=floor }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  BinDefineLabel('_jbes_one');
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  BinDefineLabel('_jbes_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_juldate(date): LongInt --- Julian date YYYYDDD (56 octets, meme que juldate7) }
  BinDefineLabel('_SASRT_juldate');
  BinJmpLabel('_SASRT_juldate7');

  { --- _SASRT_juldate7(date): LongInt --- Julian date YYYYDDD = year*1000+DOY (56 octets) }
  { Algorithme: ymd_calc → year; jan1=floor(1461*(year+4715)/4)-2438043; DOY=date-jan1+1 }
  BinDefineLabel('_SASRT_juldate7');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($56);                                          { push esi }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);           { push [ebp+8] (date) }
  BinCallLabel('_SASRT_ymd_calc');                        { eax=year, remplit _sas_ymd }
  BinEmit8($89); BinEmit8($C6);                          { mov esi,eax  ; save year }
  BinEmit8($05); BinEmit8($6B); BinEmit8($12); BinEmit8($00); BinEmit8($00); { add eax,4715 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);           { sar eax,2  ; floor div by 4 }
  BinEmit8($2D); BinEmit8($9B); BinEmit8($33); BinEmit8($25); BinEmit8($00); { sub eax,2438043 ; jan1 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);           { mov ebx,[ebp+8]  ; date }
  BinEmit8($2B); BinEmit8($D8);                          { sub ebx,eax  ; date-jan1=DOY-1 }
  BinEmit8($43);                                          { inc ebx  ; DOY }
  BinEmit8($69); BinEmit8($F6); BinEmit8($E8); BinEmit8($03); BinEmit8($00); BinEmit8($00); { imul esi,esi,1000 }
  BinEmit8($03); BinEmit8($F3);                          { add esi,ebx  ; year*1000+DOY }
  BinEmit8($8B); BinEmit8($C6);                          { mov eax,esi }
  BinEmit8($5E);                                          { pop esi }
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);           { ret 4 }

  { --- _SASRT_kcompare(str1,str2): LongInt --- strcmp (45 octets) }
  { Retourne <0 si str1<str2, 0 si egal, >0 si str1>str2.         }
  { [ebp+8]=str1, [ebp+12]=str2                                    }
  BinDefineLabel('_SASRT_kcompare');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                          { push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  str1 }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12] str2 }
  { .loop (offset 11): }
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($8A); BinEmit8($17);                          { mov dl,[edi] }
  BinEmit8($3A); BinEmit8($C2);                          { cmp al,dl }
  BinEmit8($75); BinEmit8($08);                          { jne .diff (+8 → 27) }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinEmit8($74); BinEmit8($0E);                          { jz .equal (+14 → 37) }
  BinEmit8($46);                                         { inc esi }
  BinEmit8($47);                                         { inc edi }
  BinEmit8($EB); BinEmit8($F0);                          { jmp .loop (-16 → 11) }
  { .diff (offset 27): }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);           { movzx eax,al }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($D2);           { movzx edx,dl }
  BinEmit8($2B); BinEmit8($C2);                          { sub eax,edx }
  BinEmit8($EB); BinEmit8($02);                          { jmp .done (+2 → 41) }
  { .equal (offset 37): }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  { .done (offset 39): wait, offset = 37+2=39 for xor, then 41 for pop edi }
  BinEmit8($5F); BinEmit8($5E);                          { pop edi; pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_kcount(str): LongInt --- compte les mots separes par espaces (47 octets) }
  { Retourne le nombre de mots (sequences de non-espaces) dans str.                     }
  BinDefineLabel('_SASRT_kcount');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56);                                          { push esi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax  count=0 }
  BinEmit8($31); BinEmit8($D2);                          { xor edx,edx  in_word=0 }
  { .loop (offset 11): }
  BinEmit8($8A); BinEmit8($0E);                          { mov cl,[esi] }
  BinEmit8($84); BinEmit8($C9);                          { test cl,cl }
  BinEmit8($74); BinEmit8($14);                          { jz .done (+20 → 37) }
  BinEmit8($80); BinEmit8($F9); BinEmit8($20);           { cmp cl,' ' }
  BinEmit8($74); BinEmit8($05);                          { je .space (+5 → 27) }
  BinEmit8($B2); BinEmit8($01);                          { mov dl,1  in_word=true }
  BinEmit8($46);                                          { inc esi }
  BinEmit8($EB); BinEmit8($F0);                          { jmp .loop (-16 → 11) }
  { .space (offset 27): }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinEmit8($74); BinEmit8($03);                          { jz .skip (+3 → 34) }
  BinEmit8($40);                                          { inc eax  count++ }
  BinEmit8($31); BinEmit8($D2);                          { xor edx,edx }
  { .skip (offset 34): }
  BinEmit8($46);                                          { inc esi }
  BinEmit8($EB); BinEmit8($E6);                          { jmp .loop (-26 → 11) }
  { .done (offset 37): check if still in_word }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinEmit8($74); BinEmit8($01);                          { jz .ret (+1 → 42) }
  BinEmit8($40);                                          { inc eax }
  { .ret (offset 42): }
  BinEmit8($5E);                                          { pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);           { ret 4 }

  { --- _SASRT_kindex(str,substr): LongInt --- jmp vers _SASRT_index }
  BinDefineLabel('_SASRT_kindex');
  BinJmpLabel('_SASRT_index');

  { --- _SASRT_kindexc(str,chars): LongInt --- jmp vers _SASRT_indexc }
  BinDefineLabel('_SASRT_kindexc');
  BinJmpLabel('_SASRT_indexc');

  { --- _SASRT_klength(str): LongInt --- jmp vers _SASRT_length }
  BinDefineLabel('_SASRT_klength');
  BinJmpLabel('_SASRT_length');

  { --- _SASRT_ktruncate(str,len): PChar --- copie les premiers len octets vers strtmp (47 octets) }
  { Retourne un pointeur vers strtmp contenant les premiers len caracteres de str.                  }
  BinDefineLabel('_SASRT_ktruncate');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                          { push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  src }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] len }
  { .loop (offset 16): }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinEmit8($7E); BinEmit8($0D);                          { jle .done (+13 → 33) }
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinEmit8($74); BinEmit8($07);                          { jz .done (+7 → 33) }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($46); BinEmit8($47); BinEmit8($49);           { inc esi; inc edi; dec ecx }
  BinEmit8($EB); BinEmit8($EF);                          { jmp .loop (-17 → 16) }
  { .done (offset 33): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte[edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');                       { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5E);                          { pop edi; pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_kurtosis(x): indicateur entier minimal x*x (1 arg) }
  BinDefineLabel('_SASRT_kurtosis');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C0);           { imul eax,eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_kverify(str,chars): LongInt --- 1ere position dans str d un char absent de chars (48 octets) }
  { Retourne la position 1-basee du 1er caractere de str qui N'apparait PAS dans chars, ou 0.             }
  { [ebp+8]=str, [ebp+12]=chars                                                                            }
  BinDefineLabel('_SASRT_kverify');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);           { push esi; push edi; push ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  str }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax  pos=0 }
  { .outer (offset 11): }
  BinEmit8($40);                                          { inc eax  pos++ }
  BinEmit8($8A); BinEmit8($16);                          { mov dl,[esi]  c=*str }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinEmit8($74); BinEmit8($15);                          { jz .notfound (+21 → 39) }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12]  chars }
  { .inner (offset 21): }
  BinEmit8($8A); BinEmit8($1F);                          { mov bl,[edi] }
  BinEmit8($84); BinEmit8($DB);                          { test bl,bl }
  BinEmit8($74); BinEmit8($07);                          { jz .nomatch (+7 → 34) }
  BinEmit8($3A); BinEmit8($D3);                          { cmp dl,bl }
  BinEmit8($74); BinEmit8($05);                          { je .matched (+5 → 36) }
  BinEmit8($47);                                          { inc edi }
  BinEmit8($EB); BinEmit8($F3);                          { jmp .inner (-13 → 21) }
  { .nomatch (offset 34): char n est pas dans chars: retourner pos }
  BinEmit8($EB); BinEmit8($05);                          { jmp .done (+5 → 41) }
  { .matched (offset 36): char est dans chars: passer au suivant }
  BinEmit8($46);                                          { inc esi }
  BinEmit8($EB); BinEmit8($E4);                          { jmp .outer (-28 → 11) }
  { .notfound (offset 39): }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax  return 0 }
  { .done (offset 41): }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);           { pop ebx; pop edi; pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_lag(x): LongInt --- retourne valeur precedente, stocke x    }
  { [ebp+8]=x. ESI=&lag_buf. eax=old, ecx=x. ret 4.                       }
  BinDefineLabel('_SASRT_lag');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($56);                                    { push esi }
  BinMovRegLabel(6,'_sas_lag_buf');                 { mov esi,&lag_buf }
  BinEmit8($8B); BinEmit8($06);                    { mov eax,[esi] (ancienne val) }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);    { mov ecx,[ebp+8] (x) }
  BinEmit8($89); BinEmit8($0E);                    { mov [esi],ecx (stocker x) }
  BinEmit8($5E);                                    { pop esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_lbound(array): LongInt 1 (1 arg) }
  { SAS utilise des tableaux 1-bases: LBOUND = 1 toujours (correct). }
  BinDefineLabel('_SASRT_lbound');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(1);                  { mov eax,1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_lgamma(x): LongInt --- floor(sum ln(k) for k=2..x-1) via FPU }
  { lgamma(n) = ln(Gamma(n)) = ln((n-1)!) = ln(2)+ln(3)+...+ln(n-1)        }
  { [ebp-4] = k (loop var), ECX = n, ST0 = running sum (FPU accumulator)    }
  BinDefineLabel('_SASRT_lgamma');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);           { sub esp,8 (k@[ebp-4], cw_orig@[ebp-8], cw_mod@[ebp-6]) }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($02); { cmp [ebp+8],2 }
  BinJccLabel(12,'_lgamma_zero');                         { jl → 0 (n<2) }
  BinEmit8($D9); BinEmit8($EE);                           { fldz (accumulator=0) }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit32(2); { mov [ebp-4],2 (k=2) }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] = n }
  BinDefineLabel('_lgamma_loop');
  BinEmit8($39); BinEmit8($4D); BinEmit8($FC);           { cmp [ebp-4],ecx (k vs n) }
  BinJccLabel(13,'_lgamma_done');                         { jge → done when k>=n }
  BinEmit8($D9); BinEmit8($ED);                           { fldln2 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild dword[ebp-4] (k) }
  BinEmit8($D9); BinEmit8($F1);                           { fyl2x → ST0=ln(k) }
  BinEmit8($DE); BinEmit8($C1);                           { faddp st(1),st(0) → acc+=ln(k) }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc dword[ebp-4] }
  BinJmpLabel('_lgamma_loop');
  BinDefineLabel('_lgamma_done');
  { truncation via FPU CW: RC=11=truncate, évite arrondi vers le haut }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] (sauver CW) }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                    { or eax,0x0C00 (RC=11=tronc) }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax (CW modifie) }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp dword[ebp-4] (tronque) }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] (restaurer CW) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  BinDefineLabel('_lgamma_zero');
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_libname(libref,path,engine): 0 si libref non vide et path repertoire, 1 sinon }
  BinDefineLabel('_SASRT_libname');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(1);                                  { mov eax,1 (erreur) }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);                  { mov edx,[ebp+8] libref }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_libname_done');                              { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);                  { cmp byte[edx],0 }
  BinJccLabel(4, '_libname_done');                              { jz done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00);   { cmp path,0 }
  BinJccLabel(4, '_libname_done');                              { je done }
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);                  { push path }
  BinCallImport('_GetFileAttributesA@4');
  BinEmit8($83); BinEmit8($F8); BinEmit8($FF);                  { cmp eax,-1 }
  BinJccLabel(4, '_libname_error');                             { je error }
  BinEmit8($A9); BinEmit32($00000010);                          { test eax,FILE_ATTRIBUTE_DIRECTORY }
  BinJccLabel(4, '_libname_error');                             { jz error }
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax (succes) }
  BinJmpLabel('_libname_done');
  BinDefineLabel('_libname_error');
  BinEmit8($B8); BinEmit32(1);                                  { mov eax,1 }
  BinDefineLabel('_libname_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_libref(libref): 0 pour WORK, 1 pour non assigne }
  BinDefineLabel('_SASRT_libref');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(1);                                  { mov eax,1 (non assigne) }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);                  { mov edx,[ebp+8] libref }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_libref_done');                               { jz done }
  BinEmit8($8A); BinEmit8($0A);                                 { mov cl,[edx] }
  BinEmit8($80); BinEmit8($E1); BinEmit8($DF);                  { uppercase }
  BinEmit8($80); BinEmit8($F9); BinEmit8(Ord('W'));             { cmp cl,'W' }
  BinJccLabel(5, '_libref_done');                               { jne done }
  BinEmit8($8A); BinEmit8($4A); BinEmit8($01);                  { mov cl,[edx+1] }
  BinEmit8($80); BinEmit8($E1); BinEmit8($DF);
  BinEmit8($80); BinEmit8($F9); BinEmit8(Ord('O'));             { cmp cl,'O' }
  BinJccLabel(5, '_libref_done');
  BinEmit8($8A); BinEmit8($4A); BinEmit8($02);                  { mov cl,[edx+2] }
  BinEmit8($80); BinEmit8($E1); BinEmit8($DF);
  BinEmit8($80); BinEmit8($F9); BinEmit8(Ord('R'));             { cmp cl,'R' }
  BinJccLabel(5, '_libref_done');
  BinEmit8($8A); BinEmit8($4A); BinEmit8($03);                  { mov cl,[edx+3] }
  BinEmit8($80); BinEmit8($E1); BinEmit8($DF);
  BinEmit8($80); BinEmit8($F9); BinEmit8(Ord('K'));             { cmp cl,'K' }
  BinJccLabel(5, '_libref_done');
  BinEmit8($80); BinEmit8($7A); BinEmit8($04); BinEmit8($00);   { cmp byte[edx+4],0 }
  BinJccLabel(5, '_libref_done');
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax }
  BinDefineLabel('_libref_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_log10(x): LongInt --- log10(x) via x87 FLDLG2+FYL2X (35 octets) }
  { log10(x) = log2(x)*log10(2) = FYL2X(FLDLG2, x). Si x<=0 retourne 0.  }
  BinDefineLabel('_SASRT_log10');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp [ebp+8],0 }
  BinEmit8($7E); BinEmit8($0F);                                { jle .zero }
  BinEmit8($D9); BinEmit8($EC);                                { fldlg2 (log10(2)) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);
  BinEmit8($D9); BinEmit8($F1);                                { fyl2x }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($EB); BinEmit8($02);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_log2(x): LongInt --- log2(x) via x87 FLD1+FYL2X (35 octets) }
  { log2(x) = FYL2X(1, x). Si x<=0 retourne 0.                            }
  BinDefineLabel('_SASRT_log2');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp [ebp+8],0 }
  BinEmit8($7E); BinEmit8($0F);                                { jle .zero }
  BinEmit8($D9); BinEmit8($E8);                                { fld1 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);
  BinEmit8($D9); BinEmit8($F1);                                { fyl2x }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($EB); BinEmit8($02);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_logpdf(dist,x): approximation entiere -abs(x) }
  BinDefineLabel('_SASRT_logpdf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($99);                                         { cdq }
  BinEmit8($31); BinEmit8($D0);                          { xor eax,edx }
  BinEmit8($2B); BinEmit8($C2);                          { sub eax,edx = abs(x) }
  BinEmit8($F7); BinEmit8($D8);                          { neg eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_logsdf(dist,x): approximation entiere 0 si x<=0, -x sinon }
  BinDefineLabel('_SASRT_logsdf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14, '_logsdf_zero');                       { jle zero }
  BinEmit8($F7); BinEmit8($D8);                          { neg eax }
  BinJmpLabel('_logsdf_done');
  BinDefineLabel('_logsdf_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_logsdf_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_mean(x): LongInt x (1 arg) }
  { Moyenne d une valeur entiere = cette valeur elle-meme.                }
  { (Pour plus d args, le compilateur ne les passe pas dans cette version }
  { 1-arg — la moyenne serait (x1+x2)/2, non supportee ici.)             }
  BinDefineLabel('_SASRT_mean');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00); { pop ebp; ret 4 }

  { --- _SASRT_minute(time): LongInt --- (time mod 3600)/60 (28 octets) }
  BinDefineLabel('_SASRT_minute');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { mov ecx,3600 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx → edx=time mod 3600 }
  BinEmit8($89); BinEmit8($D0);                               { mov eax,edx }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($3C); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,60 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_missing(x): LongInt 0 (1 arg) }
  { Retourne 1 si valeur manquante. Dans ce compilateur entier, aucun entier }
  { n est manquant, donc retourne toujours 0 (reponse exacte et correcte).   }
  BinDefineLabel('_SASRT_missing');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_modulein(routine,arg): longueur de arg (2 args) }
  BinDefineLabel('_SASRT_modulein');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] arg }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(4, '_modulein_done');                      { jz done }
  BinDefineLabel('_modulein_loop');
  BinEmit8($80); BinEmit8($3C); BinEmit8($02); BinEmit8($00); { cmp byte[edx+eax],0 }
  BinJccLabel(4, '_modulein_done');                      { je done }
  BinEmit8($40);                                         { inc eax }
  BinJmpLabel('_modulein_loop');
  BinDefineLabel('_modulein_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_modulen(routine,arg): longueur de arg (2 args) }
  BinDefineLabel('_SASRT_modulen');
  BinJmpLabel('_SASRT_modulein');

  { --- _SASRT_mopen(did,member,mode,reclen,cc): ouvre member si did valide (5 args) }
  BinDefineLabel('_SASRT_mopen');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                  { mov eax,[ebp+8] did }
  BinEmit8($85); BinEmit8($C0);                                 { test eax,eax }
  BinJccLabel(14, '_mopen_fail');                               { jle fail }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);                  { mov edx,[ebp+12] member }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_mopen_fail');                                { jz fail }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);                  { cmp byte[edx],0 }
  BinJccLabel(4, '_mopen_fail');                                { jz fail }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);                  { push [ebp+16] mode }
  BinEmit8($52);                                                { push edx member }
  BinCallLabel('_SASRT_fopen');                                 { eax=fid ou 0 }
  BinJmpLabel('_mopen_done');
  BinDefineLabel('_mopen_fail');
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax }
  BinDefineLabel('_mopen_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { --- _SASRT_mort(a,r,n,x): mortgage (4 args)                           }
  { x=0: payment=pvp. x>0: balance=a*(F_n-F_x)/(F_n-1).                 }
  { x<0: interest=rate*a*(F_n-F(|x|-1))/(F_n-1). F_k=(1+rate)^k.       }
  { [ebp+8]=a [ebp+12]=r [ebp+16]=n [ebp+20]=x                          }
  { Locaux (sub esp,32): [ebp-4]=tmp [ebp-8/-6]=CW [ebp-16]=factor       }
  { [ebp-24]=F_n [ebp-32]=F_x (or F_p_minus_1) qwords                   }
  BinDefineLabel('_SASRT_mort');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($20);           { sub esp,32 }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($10);           { mov esi,[ebp+16] n }
  BinEmit8($85); BinEmit8($F6);                          { test esi,esi }
  BinJccLabel(14,'_mort_zero');                           { jle: n<=0 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);           { mov ebx,[ebp+12] r }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($14);           { mov edi,[ebp+20] x }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(5,'_mort_haser');                           { jnz: r!=0 }
  { r=0: payment=a/n (x=0), balance=a-x*(a/n) (x>0), interest=0 (x<0) }
  BinEmit8($85); BinEmit8($FF);                          { test edi,edi }
  BinJccLabel(12,'_mort_r0_neg');                         { jl: x<0 → interest=0 }
  BinJccLabel(4,'_mort_r0_pay');                          { jz: x=0 → a/n }
  { x>0: balance = a - x*(a/n) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] a }
  BinEmit8($99);                                          { cdq }
  BinEmit8($89); BinEmit8($F1);                          { mov ecx,esi n }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx → step=a/n }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C7);           { imul eax,edi → x*step }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);           { mov edx,[ebp+8] a }
  BinEmit8($29); BinEmit8($C2);                          { sub edx,eax → a-x*step }
  BinEmit8($89); BinEmit8($D0);                          { mov eax,edx }
  BinJmpLabel('_mort_done');
  BinDefineLabel('_mort_r0_pay');                         { x=0: payment=a/n }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] a }
  BinEmit8($99);                                          { cdq }
  BinEmit8($89); BinEmit8($F1);                          { mov ecx,esi n }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx }
  BinJmpLabel('_mort_done');
  BinDefineLabel('_mort_r0_neg');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax (interest=0) }
  BinJmpLabel('_mort_done');
  BinDefineLabel('_mort_haser');
  { compute factor=(1+r/100) in [ebp-16] }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> r/100 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 1+r/100 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] factor }
  { compute F_n = factor^n: init ST0=1.0, ECX=n }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($89); BinEmit8($F1);                          { mov ecx,esi n }
  BinDefineLabel('_mort_Fn_loop');
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul qword[ebp-16] }
  BinEmit8($E2); BinEmit8($FB);                          { loop }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E8);           { fstp qword[ebp-24] F_n }
  { branch on x }
  BinEmit8($85); BinEmit8($FF);                          { test edi,edi }
  BinJccLabel(4,'_mort_x0');                              { jz: x=0 → payment }
  BinJccLabel(15,'_mort_xpos');                           { jg: x>0 → balance }
  { x<0: p=|x|, need F(p-1)=(1+rate)^(p-1) }
  BinEmit8($F7); BinEmit8($DF);                          { neg edi → |x|=p }
  BinEmit8($4F);                                          { dec edi → p-1 }
  BinJmpLabel('_mort_Fx');
  BinDefineLabel('_mort_xpos');
  BinDefineLabel('_mort_Fx');
  { compute F_x = factor^edi: ECX=edi }
  BinEmit8($89); BinEmit8($F9);                          { mov ecx,edi }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(4,'_mort_Fx_done');                         { jz: edi=0 → F_x=1 }
  BinDefineLabel('_mort_Fx_loop');
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul qword[ebp-16] }
  BinEmit8($E2); BinEmit8($FB);                          { loop }
  BinDefineLabel('_mort_Fx_done');
  BinEmit8($DD); BinEmit8($5D); BinEmit8($E0);           { fstp qword[ebp-32] F_x }
  { ST empty. F_n-F_x: }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E8);           { fld qword[ebp-24] F_n }
  BinEmit8($DC); BinEmit8($65); BinEmit8($E0);           { fsub qword[ebp-32] -> F_n-F_x }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] a }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> a*(F_n-F_x) }
  { if x was negative, also multiply by rate=r/100 }
  BinEmit8($83); BinEmit8($7D); BinEmit8($14); BinEmit8($00); { cmp [ebp+20],0 }
  BinJccLabel(13,'_mort_div');                            { jge: x was >=0 → skip rate mul }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> r/100 }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> a*(F_n-F_x)*(r/100) }
  BinDefineLabel('_mort_div');
  { divide by (F_n-1) }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E8);           { fld qword[ebp-24] F_n }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp -> F_n-1 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> numer/(F_n-1) }
  BinJmpLabel('_mort_fistp');
  BinDefineLabel('_mort_x0');
  { x=0: payment = a*rate*F_n/(F_n-1) }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> rate }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] a }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> a*rate }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($E8);           { fmul qword[ebp-24] -> a*rate*F_n }
  BinEmit8($DD); BinEmit8($45); BinEmit8($E8);           { fld qword[ebp-24] F_n }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp -> F_n-1 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> a*rate*F_n/(F_n-1) }
  BinDefineLabel('_mort_fistp');
  { floor via truncation }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinDefineLabel('_mort_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);
  BinDefineLabel('_mort_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_n(x): LongInt 1 (1 arg) }
  { Compte les valeurs non manquantes. Dans ce compilateur entier, tout   }
  { entier est non manquant, donc N(x) retourne toujours 1 (correct).     }
  BinDefineLabel('_SASRT_n');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_netpv(r,cf): valeur presente entiere cf/(1+r/100) (2 args) }
  BinDefineLabel('_SASRT_netpv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);                  { mov ecx,[ebp+8] r }
  BinEmit8($83); BinEmit8($C1); BinEmit8($64);                  { add ecx,100 }
  BinEmit8($85); BinEmit8($C9);                                 { test ecx,ecx }
  BinJccLabel(4, '_netpv_zero');                                { jz zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);                  { mov eax,[ebp+12] cf }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($64);                  { imul eax,eax,100 }
  BinEmit8($99);                                                { cdq }
  BinEmit8($F7); BinEmit8($F9);                                 { idiv ecx }
  BinJmpLabel('_netpv_done');
  BinDefineLabel('_netpv_zero');
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax }
  BinDefineLabel('_netpv_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_nmiss(x): LongInt 0 (1 arg) }
  { Compte les valeurs manquantes. Dans ce compilateur entier, aucun entier }
  { n est manquant, donc NMISS(x) retourne toujours 0 (correct).           }
  BinDefineLabel('_SASRT_nmiss');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_normal(seed): synonyme de RANNOR, meme algorithme (1 arg) }
  BinDefineLabel('_SASRT_normal');
  BinJmpLabel('_SASRT_rannor');

  { --- _SASRT_note(dsid): -1 aucune note dataset disponible (1 arg) }
  BinDefineLabel('_SASRT_note');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($B8); BinEmit32(-1);                              { mov eax,-1 }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_npv(r,cf): alias de NETPV pour backend entier (2 args) }
  BinDefineLabel('_SASRT_npv');
  BinJmpLabel('_SASRT_netpv');

  { --- _SASRT_open(dataset,mode): dsid minimal 1 si dataset non vide, 0 sinon (2 args) }
  BinDefineLabel('_SASRT_open');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                                 { xor eax,eax }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);                  { mov edx,[ebp+8] dataset }
  BinEmit8($85); BinEmit8($D2);                                 { test edx,edx }
  BinJccLabel(4, '_open_done');                                 { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);                  { cmp byte[edx],0 }
  BinJccLabel(4, '_open_done');                                 { jz done }
  BinEmit8($B8); BinEmit32(1);                                  { mov eax,1 }
  BinDefineLabel('_open_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- Batch 9 : ORDINAL, PDF, PEEK, PERM, POINT, POISSON, POKE, PROB*, PVP --- }

  { ORDINAL(k,x1,x2): LongInt --- k-ieme plus petite valeur parmi x1,x2 }
  { k=1 → min(x1,x2); k=2 → max(x1,x2); autres → 0                   }
  { [ebp+8]=k, [ebp+12]=x1, [ebp+16]=x2                               }
  BinDefineLabel('_SASRT_ordinal');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x1 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] x2 }
  BinEmit8($3B); BinEmit8($C1);                          { cmp eax,ecx }
  BinEmit8($7E); BinEmit8($01);                          { jle .skip_xchg (1 byte) }
  BinEmit8($91);                                          { xchg eax,ecx  min→eax, max→ecx }
  { eax=min, ecx=max }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($01); { cmp [ebp+8],1 }
  BinJccLabel(4, '_ord_k1');                              { je .k1 → min }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($02); { cmp [ebp+8],2 }
  BinJccLabel(4, '_ord_k2');                              { je .k2 → max }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax (k invalide) }
  BinJmpLabel('_ord_done');
  BinDefineLabel('_ord_k1');
  BinJmpLabel('_ord_done');                               { eax=min deja }
  BinDefineLabel('_ord_k2');
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx (max) }
  BinDefineLabel('_ord_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00); { pop ebp; ret 12 }

  { PDF(dist,x,parm): densite entiere approx max(0, parm-abs(x)) (3 args) }
  BinDefineLabel('_SASRT_pdf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] parm }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14, '_pdf_zero');                          { jle zero }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] x }
  BinEmit8($89); BinEmit8($CA);                          { mov edx,ecx }
  BinEmit8($C1); BinEmit8($FA); BinEmit8($1F);           { sar edx,31 }
  BinEmit8($31); BinEmit8($D1);                          { xor ecx,edx }
  BinEmit8($2B); BinEmit8($CA);                          { sub ecx,edx = abs(x) }
  BinEmit8($2B); BinEmit8($C1);                          { sub eax,ecx }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(15, '_pdf_done');                          { jg done }
  BinDefineLabel('_pdf_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_pdf_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PEEK(addr): lit 4 octets a addr, retourne la valeur (1 arg) }
  { Layout: 55 89 E5 / 8B 45 08 / 8B 00 / 5D / C2 04 00        }
  BinDefineLabel('_SASRT_peek');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8]  }
  BinEmit8($8B); BinEmit8($00);                  { mov eax,[eax]    }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { PERM(n,r): n*(n-1)*...*(n-r+1) iteratif (2 args, 30 o)          }
  { Layout: jle _done(+6), imul/dec/loop(-6), pop ebx/pop ebp/ret 8 }
  BinDefineLabel('_SASRT_perm');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53);                                  { push ebx         }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);  { mov ebx,[ebp+8]  n }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);  { mov ecx,[ebp+12] r }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinEmit8($85); BinEmit8($C9);                  { test ecx,ecx      }
  BinEmit8($7E); BinEmit8($06);                  { jle _done (→ off25) }
  { _loop (offset 19): }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C3);  { imul eax,ebx      }
  BinEmit8($4B);                                  { dec ebx           }
  BinEmit8($E2); BinEmit8($FA);                  { loop _loop (→ off19) }
  { _done (offset 25): }
  BinEmit8($5B); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { POINT(dsid,nid): observation nid si ids valides, 0 sinon (2 args) }
  BinDefineLabel('_SASRT_point');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14, '_point_zero');                        { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] nid }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(15, '_point_done');                        { jg done }
  BinDefineLabel('_point_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_point_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { POISSON(m,n): P(X<=n|Pois(m)). m=0 -> always 1 (exact), m>0 -> 0 approx (2 args) }
  BinDefineLabel('_SASRT_poisson');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax default 0 }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp [ebp+8],0 m }
  BinJccLabel(5,'_pois_done');                            { jnz: m!=0 -> return 0 }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 Pois(0)=1 }
  BinDefineLabel('_pois_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { POKE(addr,val): ecriture LongInt val a l adresse addr. Retourne 0. }
  BinDefineLabel('_SASRT_poke');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8]  addr }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] val }
  BinEmit8($89); BinEmit8($11);                           { mov [ecx],edx }
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- PROB* approximations entieres --- }
  { PROBBETA(x,a,b): 1 si x% >= moyenne a/(a+b), sinon 0 (3 args) }
  BinDefineLabel('_SASRT_probbeta');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] a }
  BinEmit8($03); BinEmit8($4D); BinEmit8($10);           { add ecx,[ebp+16] b }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14, '_probbeta_zero');                     { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C1);           { imul eax,ecx }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] a }
  BinEmit8($6B); BinEmit8($D2); BinEmit8($64);           { imul edx,edx,100 }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probbeta_zero');                     { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probbeta_done');
  BinDefineLabel('_probbeta_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probbeta_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PROBBNML(p,n,m): 1 si m >= n*p/100, sinon 0 (3 args) }
  BinDefineLabel('_SASRT_probbnml');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] m }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(12, '_probbnml_zero');                     { jl zero }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($64);           { imul eax,eax,100 }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] n }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($55); BinEmit8($08); { imul edx,[ebp+8] p }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probbnml_zero');                     { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probbnml_done');
  BinDefineLabel('_probbnml_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probbnml_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PROBBNRM(x,y,r): approximation entiere Phi2, 1 si x>0 et y>0 (3 args) }
  BinDefineLabel('_SASRT_probbnrm');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp x,0 }
  BinJccLabel(14, '_probbnrm_done');                     { jle done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp y,0 }
  BinJccLabel(14, '_probbnrm_done');                     { jle done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_probbnrm_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PROBCHI(x,df): approximation entiere 1 si x>=df, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_probchi');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] df }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(14, '_probchi_done');                      { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probchi_zero');                      { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probchi_done');
  BinDefineLabel('_probchi_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probchi_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { PROBF(x,df1,df2): approximation entiere 1 si x>=1 et df valides (3 args) }
  BinDefineLabel('_SASRT_probf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp df1,0 }
  BinJccLabel(14, '_probf_done');                        { jle done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($10); BinEmit8($00); { cmp df2,0 }
  BinJccLabel(14, '_probf_done');                        { jle done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($01); { cmp x,1 }
  BinJccLabel(12, '_probf_done');                        { jl done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_probf_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PROBGAM(x,a): approximation entiere 1 si x>=a, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_probgam');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] a }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(14, '_probgam_done');                      { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probgam_zero');                      { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probgam_done');
  BinDefineLabel('_probgam_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probgam_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { PROBHYPR(N,K,n,x): approximation entiere 1 si x*N >= n*K (4 args) }
  BinDefineLabel('_SASRT_probhypr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp N,0 }
  BinJccLabel(14, '_probhypr_done');                     { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($14);           { mov eax,[ebp+20] x }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($08); { imul eax,[ebp+8] N }
  BinEmit8($8B); BinEmit8($55); BinEmit8($10);           { mov edx,[ebp+16] n }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($55); BinEmit8($0C); { imul edx,[ebp+12] K }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probhypr_zero');                     { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probhypr_done');
  BinDefineLabel('_probhypr_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probhypr_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { PROBIT(p): quantile normal approx pour p pourcentage entier (1 arg) }
  BinDefineLabel('_SASRT_probit');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] p }
  BinEmit8($83); BinEmit8($F8); BinEmit8($01);           { cmp p,1 }
  BinJccLabel(14, '_probit_m3');                         { jle -3 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($05);           { cmp p,5 }
  BinJccLabel(12, '_probit_m2');                         { jl -2 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($32);           { cmp p,50 }
  BinJccLabel(12, '_probit_m1');                         { jl -1 }
  BinJccLabel(4, '_probit_zero');                        { je 0 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5F);           { cmp p,95 }
  BinJccLabel(12, '_probit_p1');                         { jl 1 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($63);           { cmp p,99 }
  BinJccLabel(12, '_probit_p2');                         { jl 2 }
  BinEmit8($B8); BinEmit32(3);                           { mov eax,3 }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_m3');
  BinEmit8($B8); BinEmit32(-3);                          { mov eax,-3 }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_m2');
  BinEmit8($B8); BinEmit32(-2);                          { mov eax,-2 }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_m1');
  BinEmit8($B8); BinEmit32(-1);                          { mov eax,-1 }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_p1');
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probit_done');
  BinDefineLabel('_probit_p2');
  BinEmit8($B8); BinEmit32(2);                           { mov eax,2 }
  BinDefineLabel('_probit_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { PROBMC(dist,q,alpha,df,n): approx 1 si q>=alpha et df/n valides (5 args) }
  BinDefineLabel('_SASRT_probmc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($14); BinEmit8($00); { cmp df,0 }
  BinJccLabel(14, '_probmc_done');                       { jle done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($18); BinEmit8($00); { cmp n,0 }
  BinJccLabel(14, '_probmc_done');                       { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] q }
  BinEmit8($3B); BinEmit8($45); BinEmit8($10);           { cmp eax,[ebp+16] alpha }
  BinJccLabel(12, '_probmc_zero');                       { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probmc_done');
  BinDefineLabel('_probmc_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probmc_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($14); BinEmit8($00);

  { PROBNEGB(p,n,m): approx 1 si m*p >= n*100, p pourcentage (3 args) }
  BinDefineLabel('_SASRT_probnegb');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp p,0 }
  BinJccLabel(14, '_probnegb_done');                     { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] m }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($45); BinEmit8($08); { imul eax,[ebp+8] p }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] n }
  BinEmit8($6B); BinEmit8($D2); BinEmit8($64);           { imul edx,edx,100 }
  BinEmit8($3B); BinEmit8($C2);                          { cmp eax,edx }
  BinJccLabel(12, '_probnegb_zero');                     { jl zero }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinJmpLabel('_probnegb_done');
  BinDefineLabel('_probnegb_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_probnegb_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { PROBNORM(x): LongInt --- CDF normale: 0 si x<=0, 1 si x>0 (23 octets) }
  { Approximation entiere: Phi(0)=0.5->0, Phi(1+)=1, Phi(neg)=0.         }
  BinDefineLabel('_SASRT_probnorm');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinEmit8($7E); BinEmit8($07);                          { jle .not_pos (+7 → xor eax,eax) }
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov eax,1 }
  BinEmit8($EB); BinEmit8($02);                          { jmp .done (+2 → pop ebp) }
  BinEmit8($31); BinEmit8($C0);                          { .not_pos: xor eax,eax }
  BinEmit8($5D);                                          { .done: pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);           { ret 4 }

  { PROBT(x,df): approximation entiere 1 si x>0 et df valide (2 args) }
  BinDefineLabel('_SASRT_probt');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp df,0 }
  BinJccLabel(14, '_probt_done');                        { jle done }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp x,0 }
  BinJccLabel(14, '_probt_done');                        { jle done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_probt_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_pvp(a,r,n): pmt=a*(r/100)*(1+r/100)^n/((1+r/100)^n-1) (3 args) }
  { [ebp+8]=a [ebp+12]=r [ebp+16]=n. Locaux (sub esp,16): [ebp-4]=tmp        }
  { [ebp-8]=CW_orig [ebp-6]=CW_trunc [ebp-16]=F=(1+r/100)^n qword            }
  BinDefineLabel('_SASRT_pvp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10);           { sub esp,16 }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_pvp_zero');                            { jle: n<=0 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);           { mov ebx,[ebp+12] r }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(5,'_pvp_haser');                            { jnz: r!=0 }
  { r=0: return a/n }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] a }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx }
  BinJmpLabel('_pvp_done');
  BinDefineLabel('_pvp_haser');
  { compute factor=(1+r/100) in [ebp-16] }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> r/100 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 1+r/100 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] factor }
  { compute F = factor^n: init accumulator=1.0 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinDefineLabel('_pvp_loop');
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul qword[ebp-16] }
  BinEmit8($E2); BinEmit8($FB);                          { loop _pvp_loop }
  { ST0 = F. Store F in [ebp-16] (overwrite factor). }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] F }
  { compute a*(r/100)*F }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> r/100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] a }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> a*(r/100) }
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul qword[ebp-16] *F -> a*(r/100)*F }
  { compute F-1 }
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld qword[ebp-16] F }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> F-1 }
  { ST0=F-1(denom), ST1=a*r*F/100(numer): result=ST1/ST0 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st -> a*r*F/100/(F-1) }
  { floor via truncation (positive result) }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinDefineLabel('_pvp_done');
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  BinDefineLabel('_pvp_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- Batch 10 : fonctions numeriques Q-S --- }

  { QTR(date): LongInt --- trimestre 1..4 via _SASRT_ymd_calc (33 octets) }
  { Appelle ymd_calc qui remplit _sas_ymd; month=(month-1)/3+1.          }
  BinDefineLabel('_SASRT_qtr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);                { push dword [ebp+8] (date) }
  BinCallLabel('_SASRT_ymd_calc');                             { EAX=year, _sas_ymd rempli }
  BinMovRegLabel(7, '_sas_ymd');                               { mov edi,&_sas_ymd }
  BinEmit8($8B); BinEmit8($47); BinEmit8($04);               { mov eax,[edi+4] (month) }
  BinEmit8($48);                                               { dec eax (month-1) }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,3 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($40);                                               { inc eax (+1) }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_ranbin(seed,n,p): Binomial(n,p) avec args entiers (3 args)      }
  { p=0: 0. p=1: n (proba SAS 1). p=2..99: p pourcent. p>=100: n.            }
  BinDefineLabel('_SASRT_ranbin');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);           { mov esi,[ebp+12] n }
  BinEmit8($85); BinEmit8($F6);                          { test esi,esi }
  BinJccLabel(14,'_ranbin_zero');                         { jle zero }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($10);           { mov edi,[ebp+16] p }
  BinEmit8($85); BinEmit8($FF);                          { test edi,edi }
  BinJccLabel(14,'_ranbin_zero');                         { jle zero }
  BinEmit8($83); BinEmit8($FF); BinEmit8($01);           { cmp edi,1 }
  BinJccLabel(4,'_ranbin_all');                           { je all }
  BinEmit8($83); BinEmit8($FF); BinEmit8($64);           { cmp edi,100 }
  BinJccLabel(13,'_ranbin_all');                          { jge all }
  BinEmit8($31); BinEmit8($DB);                          { xor ebx,ebx success=0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] seed }
  BinDefineLabel('_ranbin_loop');
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($50);                                          { push eax rng }
  BinEmit8($B9); BinEmit32(100);                          { mov ecx,100 }
  BinEmit8($31); BinEmit8($D2);                           { xor edx,edx }
  BinEmit8($F7); BinEmit8($F1);                           { div ecx; edx=rng mod 100 }
  BinEmit8($3B); BinEmit8($D7);                           { cmp edx,edi }
  BinJccLabel(3,'_ranbin_no_success');                    { jae no success }
  BinEmit8($43);                                          { inc ebx }
  BinDefineLabel('_ranbin_no_success');
  BinEmit8($58);                                          { pop eax rng }
  BinEmit8($4E);                                          { dec esi }
  BinJccLabel(5,'_ranbin_loop');                          { jnz loop }
  BinEmit8($89); BinEmit8($D8);                           { mov eax,ebx }
  BinJmpLabel('_ranbin_done');
  BinDefineLabel('_ranbin_all');
  BinEmit8($89); BinEmit8($F0);                           { mov eax,esi }
  BinJmpLabel('_ranbin_done');
  BinDefineLabel('_ranbin_zero');
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  BinDefineLabel('_ranbin_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);            { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_rancau(seed): Cauchy(0,1)=tan(pi*(U-0.5)) via LCG (1 arg)   }
  { [ebp+8]=seed. sub esp,12: [ebp-4]=res [ebp-8/-6]=CW [ebp-12]=N        }
  BinDefineLabel('_SASRT_rancau');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($0C);           { sub esp,12 }
  { CW floor }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF);
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);
  { LCG }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($89); BinEmit8($45); BinEmit8($F4);           { mov [ebp-12],eax }
  { EDX = &_sas_lcg_max }
  BinMovRegLabel(2,'_sas_lcg_max');
  { tan(pi*(U-0.5)) = tan(pi*U - pi/2) }
  { fldpi; fild N; fidiv [edx]; fmulp -> pi*U }
  BinEmit8($D9); BinEmit8($EB);                          { fldpi }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F4);           { fild [ebp-12] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> pi*U }
  { fldpi; fld1; fadd st0,st0 -> 2.0; fdivp -> pi/2 }
  BinEmit8($D9); BinEmit8($EB);                          { fldpi }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0 -> 2.0 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> pi/2 }
  { fsubp -> pi*U - pi/2 = pi*(U-0.5) }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp }
  { fptan -> 1.0 sur st0, tan(angle) sur st1; fdivp -> tan(angle) }
  BinEmit8($D9); BinEmit8($F2);                          { fptan }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> tan/1 }
  { floor et retour }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_ranexp(seed): Exp(1) = -ln(U) via LCG (1 arg)               }
  { [ebp+8]=seed. sub esp,12: [ebp-4]=res [ebp-8/-6]=CW [ebp-12]=N        }
  BinDefineLabel('_SASRT_ranexp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($0C);           { sub esp,12 }
  { CW floor }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF);
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);
  { LCG: N=(seed*1103515245+12345)&0x7FFFFFFF|1 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($83); BinEmit8($C8); BinEmit8($01);           { or eax,1 (U>0 pour log) }
  BinEmit8($89); BinEmit8($45); BinEmit8($F4);           { mov [ebp-12],eax }
  { EDX = &_sas_lcg_max }
  BinMovRegLabel(2,'_sas_lcg_max');
  { -ln(U): fild N; fidiv [edx]; fldln2; fxch; fyl2x; fchs }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F4);           { fild [ebp-12] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U }
  BinEmit8($D9); BinEmit8($ED);                          { fldln2 }
  BinEmit8($D9); BinEmit8($C9);                          { fxch }
  BinEmit8($D9); BinEmit8($F1);                          { fyl2x -> ln(U) }
  BinEmit8($D9); BinEmit8($E0);                          { fchs -> -ln(U) = Exp(1) }
  { floor et retour }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_rangam(seed,a): Gamma(a)=-ln(prod(Ui,i=1..a)) (2 args)          }
  { [ebp+8]=seed [ebp+12]=a. sub esp,12: [ebp-4]=res [ebp-8/-6]=CW [ebp-12]=N }
  BinDefineLabel('_SASRT_rangam');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($0C);           { sub esp,12 }
  { CW floor RC=01 }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF);
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  { Si a<=0: retourner 0 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] a }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_rangam_zero');                        { jle }
  { EDX=&_sas_lcg_max, EAX=seed, P=1.0 }
  BinMovRegLabel(2,'_sas_lcg_max');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] seed }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 P=1.0 }
  { Boucle: P = prod(Ui, i=1..a) }
  BinDefineLabel('_rangam_loop');
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($83); BinEmit8($C8); BinEmit8($01);           { or eax,1 }
  BinEmit8($89); BinEmit8($45); BinEmit8($F4);           { mov [ebp-12],eax }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F4);           { fild [ebp-12] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> P*=U }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_rangam_loop');                         { jnz: continue }
  { Calculer -ln(P) = Gamma(a,1) }
  BinEmit8($D9); BinEmit8($ED);                          { fldln2 }
  BinEmit8($D9); BinEmit8($C9);                          { fxch -> st0=P, st1=ln2 }
  BinEmit8($D9); BinEmit8($F1);                          { fyl2x -> ln(P) }
  BinEmit8($D9); BinEmit8($E0);                          { fchs -> -ln(P) }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinJmpLabel('_rangam_done');
  BinDefineLabel('_rangam_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_rangam_done');
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { RANGE(x1,x2): LongInt --- ABS(x2-x1) via CDQ/XOR/SUB (18 octets) }
  BinDefineLabel('_SASRT_range');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x2 }
  BinEmit8($2B); BinEmit8($45); BinEmit8($08);           { sub eax,[ebp+8]  x2-x1 }
  BinEmit8($99);                                          { cdq }
  BinEmit8($31); BinEmit8($D0);                          { xor eax,edx }
  BinEmit8($2B); BinEmit8($C2);                          { sub eax,edx  ABS(x2-x1) }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { RANK(c): valeur ASCII du premier caractere de la chaine (1 arg) }
  { Layout (12 o): 55 89 E5 / 8B 45 08 / 0F B6 00 / 5D / C2 04 00  }
  BinDefineLabel('_SASRT_rank');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8]   }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($00);  { movzx eax,byte[eax] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_rannor(seed): N(0,1) Box-Muller via LCG (1 arg)              }
  { LCG: N=(seed*1103515245+12345)&0x7FFFFFFF|1  U=N/MAXINT               }
  { Result = sqrt(-2*ln(U1))*cos(2*pi*U2), floored. sub esp,16:            }
  { [ebp-4]=res [ebp-8/-6]=CW [ebp-12]=N1 [ebp-16]=N2                     }
  BinDefineLabel('_SASRT_rannor');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10);           { sub esp,16 }
  { CW floor RC=01 }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8);
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF);
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA);
  { LCG passe 1: N1=(seed*1103515245+12345)&0x7FFFFFFF|1 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($83); BinEmit8($C8); BinEmit8($01);           { or eax,1 (U1>0 pour log) }
  BinEmit8($89); BinEmit8($45); BinEmit8($F4);           { mov [ebp-12],eax }
  { LCG passe 2: N2=(N1*1103515245+12345)&0x7FFFFFFF|1 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($83); BinEmit8($C8); BinEmit8($01);
  BinEmit8($89); BinEmit8($45); BinEmit8($F0);           { mov [ebp-16],eax }
  { EDX = &_sas_lcg_max (2147483647) pour FIDIV }
  BinMovRegLabel(2,'_sas_lcg_max');                       { mov edx,addr }
  { sqrt(-2*ln(U1)): fild N1; fidiv [edx]; fldln2; fxch; fyl2x; fchs; fadd; fsqrt }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F4);           { fild [ebp-12] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U1 }
  BinEmit8($D9); BinEmit8($ED);                          { fldln2 }
  BinEmit8($D9); BinEmit8($C9);                          { fxch -> st0=U1,st1=ln2 }
  BinEmit8($D9); BinEmit8($F1);                          { fyl2x -> ln(U1) }
  BinEmit8($D9); BinEmit8($E0);                          { fchs -> -ln(U1) }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0 -> -2*ln(U1) }
  BinEmit8($D9); BinEmit8($FA);                          { fsqrt }
  { cos(2*pi*U2): fild N2; fidiv [edx]; fldpi; fmulp; fadd; fcos }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F0);           { fild [ebp-16] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U2 }
  BinEmit8($D9); BinEmit8($EB);                          { fldpi }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> pi*U2 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0 -> 2*pi*U2 }
  BinEmit8($D9); BinEmit8($FF);                          { fcos }
  { N(0,1) = sqrt(-2*ln(U1)) * cos(2*pi*U2) }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp }
  { floor et retour }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_ranpoi(seed,m): Poisson(m) methode multiplicative (2 args)    }
  { Knuth: k=-1,P=1; boucle: k++,P*=U jusqu'a P<=L=exp(-m); retourne k.    }
  { [ebp+8]=seed [ebp+12]=m. sub esp,12: [ebp-4]=N(LCG) [ebp-12]=L(qword) }
  BinDefineLabel('_SASRT_ranpoi');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($0C);           { sub esp,12 }
  { Si m<=0: retourner 0 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] m }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14,'_ranpoi_zero');                         { jle: m<=0 }
  { Calcule L=exp(-m) via FLDL2E/FMULP/FCHS puis F2XM1/FSCALE }
  BinEmit8($D9); BinEmit8($EA);                          { fldl2e -> log2(e) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] -> m }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> m*log2(e) }
  BinEmit8($D9); BinEmit8($E0);                          { fchs -> -m*log2(e)=y }
  { Split y=I+f, compute 2^f via F2XM1, scale par 2^I }
  BinEmit8($D9); BinEmit8($C0);                          { fld st(0) dup y }
  BinEmit8($D9); BinEmit8($FC);                          { frndint -> I }
  BinEmit8($D9); BinEmit8($C9);                          { fxch -> st0=y, st1=I }
  BinEmit8($D8); BinEmit8($E1);                          { fsub st0,st1 -> f=y-I }
  BinEmit8($D9); BinEmit8($F0);                          { f2xm1 -> 2^f-1 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 2^f }
  BinEmit8($D9); BinEmit8($FD);                          { fscale -> 2^(f+I)=e^(-m) }
  BinEmit8($DD); BinEmit8($D9);                          { fstp st(1) -> retire I }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F4);           { fstp qword[ebp-12] L }
  { EDX = &_sas_lcg_max, init eax=seed, ecx=-1, P=1.0 }
  BinMovRegLabel(2,'_sas_lcg_max');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] seed }
  BinEmit8($B9); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); { mov ecx,-1 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 P=1.0 }
  { Boucle Poisson }
  BinDefineLabel('_ranpoi_loop');
  BinEmit8($41);                                          { inc ecx k++ }
  { LCG }
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($83); BinEmit8($C8); BinEmit8($01);           { or eax,1 }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax }
  { P = P * U }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> P*U }
  { Compare P avec L: continue si P>L }
  BinEmit8($DC); BinEmit8($55); BinEmit8($F4);           { fcom qword[ebp-12] }
  BinEmit8($DF); BinEmit8($E0);                          { fnstsw ax }
  BinEmit8($9E);                                          { sahf }
  BinJccLabel(7,'_ranpoi_loop');                          { ja: P>L -> continuer }
  { Fin boucle: retirer P, retourner ecx }
  BinEmit8($DD); BinEmit8($D8);                          { fstp st(0) }
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx }
  BinJmpLabel('_ranpoi_done');
  BinDefineLabel('_ranpoi_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_ranpoi_done');
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_rantbl(seed,p1,p2): categorie 1 si p1>0, 2 si p2>0, 3 sinon    }
  { Pour args entiers: [ebp+8]=seed [ebp+12]=p1 [ebp+16]=p2                   }
  BinDefineLabel('_SASRT_rantbl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] p1 }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(5,'_rantbl_cat1');                         { jnz: p1!=0 -> cat 1 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);           { mov eax,[ebp+16] p2 }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(5,'_rantbl_cat2');                         { jnz: p2!=0 -> cat 2 }
  BinEmit8($B8); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinJmpLabel('_rantbl_done');
  BinDefineLabel('_rantbl_cat2');
  BinEmit8($B8); BinEmit8($02); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinJmpLabel('_rantbl_done');
  BinDefineLabel('_rantbl_cat1');
  BinEmit8($B8); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00);
  BinDefineLabel('_rantbl_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- _SASRT_rantri(seed,h): Triangulaire(0,h) CDF inverse (2 args)          }
  { U<=0.5: X=h*sqrt(U/2). U>0.5: X=h*(1-sqrt((1-U)/2)). [ebp+8]=seed        }
  { sub esp,16: [ebp-4]=res [ebp-8/-6]=CW [ebp-12]=N [ebp-16]=MAXINT-N        }
  BinDefineLabel('_SASRT_rantri');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10);           { sub esp,16 }
  { CW floor RC=01 }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($25); BinEmit8($FF); BinEmit8($F3); BinEmit8($FF); BinEmit8($FF);
  BinEmit8($0D); BinEmit8($00); BinEmit8($04); BinEmit8($00); BinEmit8($00);
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  { Si h<=0: retourner 0 }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] h }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(14,'_rantri_zero');                        { jle }
  { LCG }
  BinMovRegLabel(2,'_sas_lcg_max');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] seed }
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($89); BinEmit8($45); BinEmit8($F4);           { mov [ebp-12],eax N }
  { MAXINT-N -> [ebp-16] pour cas B }
  BinEmit8($B9); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F); { mov ecx,MAXINT }
  BinEmit8($29); BinEmit8($C1);                          { sub ecx,eax }
  BinEmit8($89); BinEmit8($4D); BinEmit8($F0);           { mov [ebp-16],ecx }
  { N<=MAXINT/2 -> cas A (U<=0.5) }
  BinEmit8($3D); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($3F); { cmp eax,3FFFFFFFh }
  BinJccLabel(14,'_rantri_caseA');                       { jle }
  { Cas B: X = h*(1-sqrt((1-U)/2)) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] h }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F0);           { fild [ebp-16] MAXINT-N }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> 1-U }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0 -> 2 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> (1-U)/2 }
  BinEmit8($D9); BinEmit8($FA);                          { fsqrt }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($E1);                          { fsubrp -> 1-sqrt((1-U)/2) }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> h*(1-sqrt(...)) }
  BinJmpLabel('_rantri_fistp');
  BinDefineLabel('_rantri_caseA');
  { Cas A: X = h*sqrt(U/2) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] h }
  BinEmit8($DB); BinEmit8($45); BinEmit8($F4);           { fild [ebp-12] N }
  BinEmit8($DA); BinEmit8($32);                          { fidiv [edx] -> U }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D8); BinEmit8($C0);                          { fadd st0,st0 -> 2 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> U/2 }
  BinEmit8($D9); BinEmit8($FA);                          { fsqrt }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp -> h*sqrt(U/2) }
  BinDefineLabel('_rantri_fistp');
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinJmpLabel('_rantri_done');
  BinDefineLabel('_rantri_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_rantri_done');
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { RANUNI(seed): LongInt --- prochaine valeur LCG positive (1 arg) }
  { Representation entiere: retourne N=(seed*1103515245+12345)&7FFFFFFF. }
  BinDefineLabel('_SASRT_ranuni');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] seed }
  BinEmit8($69); BinEmit8($C0); BinEmit8($6D); BinEmit8($C5); BinEmit8($C5); BinEmit8($41);
  BinEmit8($05); BinEmit8($39); BinEmit8($30); BinEmit8($00); BinEmit8($00);
  BinEmit8($25); BinEmit8($FF); BinEmit8($FF); BinEmit8($FF); BinEmit8($7F);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { REWIND(dsid): 0 si dsid valide, -1 sinon (1 arg) }
  BinDefineLabel('_SASRT_rewind');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] dsid }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(15, '_rewind_ok');                         { jg ok }
  BinEmit8($B8); BinEmit32(-1);                          { mov eax,-1 }
  BinJmpLabel('_rewind_done');
  BinDefineLabel('_rewind_ok');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_rewind_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { RXMATCH(rx_id,s): 1 si rx_id>0 et chaine non vide, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_rxmatch');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00); { cmp rx_id,0 }
  BinJccLabel(14, '_rxmatch_done');                      { jle done }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] s }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(4, '_rxmatch_done');                       { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);           { cmp byte[edx],0 }
  BinJccLabel(4, '_rxmatch_done');                       { jz done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_rxmatch_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { RXPARSE(pattern): identifiant 1 si motif non vide, sinon 0 (1 arg) }
  BinDefineLabel('_SASRT_rxparse');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);           { mov edx,[ebp+8] pattern }
  BinEmit8($85); BinEmit8($D2);                          { test edx,edx }
  BinJccLabel(4, '_rxparse_done');                       { jz done }
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);           { cmp byte[edx],0 }
  BinJccLabel(4, '_rxparse_done');                       { jz done }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_rxparse_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_saving(a,r,n): pmt=a*(r/100)/((1+r/100)^n-1), a/n if r=0 (3 args) }
  { [ebp+8]=a [ebp+12]=r [ebp+16]=n. Locaux (sub esp,16): [ebp-4]=tmp            }
  { [ebp-8]=CW_orig [ebp-6]=CW_trunc [ebp-16]=factor=(1+r/100) qword             }
  BinDefineLabel('_SASRT_saving');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10);           { sub esp,16 }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_saving_zero');                         { jle: n<=0 }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);           { mov ebx,[ebp+12] r }
  BinEmit8($85); BinEmit8($DB);                          { test ebx,ebx }
  BinJccLabel(5,'_saving_haser');                         { jnz: r!=0 }
  { r=0: return a/n }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] a }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($F9);                          { idiv ecx }
  BinJmpLabel('_saving_done');
  BinDefineLabel('_saving_haser');
  { compute factor=(1+r/100) in [ebp-16] }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp -> r/100 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp -> 1+r/100 }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] factor }
  { compute factor^n (ecx=n): init accumulator=1.0 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinDefineLabel('_saving_loop');
  BinEmit8($DC); BinEmit8($4D); BinEmit8($F0);           { fmul qword[ebp-16] }
  BinEmit8($E2); BinEmit8($FB);                          { loop _saving_loop }
  { ST0 = F = (1+r/100)^n. Compute F-1: }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st -> F-1 }
  { ST0=F-1. Compute a*(r/100): }
  BinEmit8($89); BinEmit8($5D); BinEmit8($FC);           { mov [ebp-4],ebx r }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] r }
  BinEmit8($C7); BinEmit8($45); BinEmit8($FC); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov [ebp-4],100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] 100 }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st -> r/100 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8] a }
  BinEmit8($DE); BinEmit8($C9);                          { fmulp st(1),st -> a*(r/100) }
  { ST0=a*r/100(numer), ST1=F-1(denom): result=numer/denom }
  BinEmit8($DE); BinEmit8($F1);                          { fdivrp st(1),st -> a*r/100/(F-1) }
  { floor via truncation }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinDefineLabel('_saving_done');
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  BinDefineLabel('_saving_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5B);                                          { pop ebx }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { SDF(dist,x,parm): survie entiere 1 si x<=0, sinon 0 (3 args, dist=ptr) }
  BinDefineLabel('_SASRT_sdf');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp x,0 }
  BinJccLabel(15, '_sdf_one');                           { jg done? no, positive -> 0 }
  BinEmit8($B8); BinEmit32(1);                           { mov eax,1 }
  BinDefineLabel('_sdf_one');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);

  { --- Batch 11 : fonctions numeriques S --- }

  { SECOND(t): secondes = t mod 60 (1 arg, t en secondes depuis minuit) }
  { Layout: 55 89 E5 / 8B 45 08 / 99 / B9 3C 00 00 00 / F7 F9 / 89 D0 / 5D / C2 04 00 }
  BinDefineLabel('_SASRT_second');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);              { mov eax,[ebp+8] }
  BinEmit8($99);                                              { cdq             }
  BinEmit8($B9); BinEmit8($3C); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,60 }
  BinEmit8($F7); BinEmit8($F9);                              { idiv ecx        }
  BinEmit8($89); BinEmit8($D0);                              { mov eax,edx     }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { SIN(x): LongInt --- sin(x radians) via x87 FSIN (23 octets) }
  BinDefineLabel('_SASRT_sin');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] }
  BinEmit8($D9); BinEmit8($FE);                  { fsin }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { SINH(x): LongInt --- (e^x-e^-x)/2 via x87 (67 octets) }
  BinDefineLabel('_SASRT_sinh');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  { compute e^x }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);
  BinEmit8($D9); BinEmit8($EA);                  { fldl2e }
  BinEmit8($DE); BinEmit8($C9);                  { fmulp st(1) }
  BinEmit8($D9); BinEmit8($C0);                  { fld st(0) }
  BinEmit8($D9); BinEmit8($FC);                  { frndint }
  BinEmit8($D9); BinEmit8($C9);                  { fxch }
  BinEmit8($D8); BinEmit8($E1);                  { fsub st(0),st(1) }
  BinEmit8($D9); BinEmit8($F0);                  { f2xm1 }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 }
  BinEmit8($DE); BinEmit8($C1);                  { faddp st(1) }
  BinEmit8($D9); BinEmit8($FD);                  { fscale }
  BinEmit8($DD); BinEmit8($D9);                  { fstp st(1) → ST0=e^x }
  { store e^x, compute e^-x=1/e^x }
  BinEmit8($D9); BinEmit8($55); BinEmit8($FC);  { fst dword [ebp-4] (sans pop) }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → ST0=1, ST1=e^x }
  BinEmit8($DE); BinEmit8($F1);                  { fdivrp st(1): ST1=ST0/ST1=1/e^x=e^-x, pop → ST0=e^-x }
  { load e^x, subtract e^-x → numerateur }
  BinEmit8($D9); BinEmit8($45); BinEmit8($FC);  { fld dword [ebp-4] → ST0=e^x, ST1=e^-x }
  BinEmit8($D8); BinEmit8($E1);                  { fsub st(0),st(1) → ST0=e^x-e^-x, ST1=e^-x }
  { divide by 2 }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 }
  BinEmit8($D8); BinEmit8($C0);                  { fadd st(0),st(0) → ST0=2 }
  BinEmit8($DE); BinEmit8($F9);                  { fdivp st(1): ST1=ST1/ST0=(e^x-e^-x)/2, pop → ST0=sinh }
  BinEmit8($DD); BinEmit8($D9);                  { fstp st(1) → ST0=sinh(x), pop e^-x }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { SKEWNESS(x1,x2): obliquite de deux points = 0 par symetrie minimale (2 args) }
  BinDefineLabel('_SASRT_skewness');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { SPEDIS(s1,s2): distance d'orthographe [0..100] = (maxlen-common)*100/maxlen }
  { EBX=maxlen, ECX=minlen, EDX=common, ESI=s1, EDI=s2 }
  BinDefineLabel('_SASRT_spedis');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] = s1 }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12] = s2 }
  { strlen(s1) → EBX }
  BinEmit8($89); BinEmit8($F3);                           { mov ebx,esi }
  BinDefineLabel('_sp_len1');
  BinEmit8($80); BinEmit8($3B); BinEmit8($00);           { cmp byte[ebx],0 }
  BinJccLabel(4,'_sp_len1_done');
  BinEmit8($43);                                           { inc ebx }
  BinJmpLabel('_sp_len1');
  BinDefineLabel('_sp_len1_done');
  BinEmit8($2B); BinEmit8($DE);                           { sub ebx,esi → len1 }
  { strlen(s2) → ECX }
  BinEmit8($89); BinEmit8($F9);                           { mov ecx,edi }
  BinDefineLabel('_sp_len2');
  BinEmit8($80); BinEmit8($39); BinEmit8($00);           { cmp byte[ecx],0 }
  BinJccLabel(4,'_sp_len2_done');
  BinEmit8($41);                                           { inc ecx }
  BinJmpLabel('_sp_len2');
  BinDefineLabel('_sp_len2_done');
  BinEmit8($2B); BinEmit8($CF);                           { sub ecx,edi → len2 }
  { EBX=max(len1,len2), ECX=min }
  BinEmit8($39); BinEmit8($CB);                           { cmp ebx,ecx }
  BinJccLabel(13,'_sp_max_ok');                           { jge → ebx already max }
  BinEmit8($87); BinEmit8($D9);                           { xchg ebx,ecx → ebx=max,ecx=min }
  BinDefineLabel('_sp_max_ok');
  BinEmit8($85); BinEmit8($DB);                           { test ebx,ebx }
  BinJccLabel(4,'_sp_zero');                              { jz → both empty → 0 }
  BinEmit8($31); BinEmit8($D2);                           { xor edx,edx (common=0) }
  BinEmit8($85); BinEmit8($C9);                           { test ecx,ecx }
  BinJccLabel(4,'_sp_compute');                           { jz → no common chars }
  BinEmit8($51);                                           { push ecx (minlen loop count) }
  BinDefineLabel('_sp_cmp_loop');
  BinEmit8($8A); BinEmit8($06);                           { mov al,[esi] }
  BinEmit8($3A); BinEmit8($07);                           { cmp al,[edi] }
  BinJccLabel(5,'_sp_no_match');
  BinEmit8($42);                                           { inc edx (common++) }
  BinDefineLabel('_sp_no_match');
  BinEmit8($46); BinEmit8($47);                           { inc esi, inc edi }
  BinEmit8($49);                                           { dec ecx }
  BinJccLabel(5,'_sp_cmp_loop');
  BinEmit8($59);                                           { pop ecx }
  BinDefineLabel('_sp_compute');
  BinEmit8($89); BinEmit8($D8);                           { mov eax,ebx (maxlen) }
  BinEmit8($29); BinEmit8($D0);                           { sub eax,edx (maxlen-common) }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($64);           { imul eax,100 }
  BinEmit8($99);                                           { cdq }
  BinEmit8($F7); BinEmit8($FB);                           { idiv ebx }
  BinJmpLabel('_sp_done');
  BinDefineLabel('_sp_zero');
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  BinDefineLabel('_sp_done');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { STD(x1,x2): LongInt --- |x1-x2|/sqrt(2) via x87 (38 octets) }
  { Ecart-type echantillon pour 2 valeurs = |x1-x2|/sqrt(2).    }
  BinDefineLabel('_SASRT_std');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);           { sub esp,4 (local pour fistp) }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);           { fild [ebp+8]  x1 }
  BinEmit8($DB); BinEmit8($45); BinEmit8($0C);           { fild [ebp+12] x2 }
  BinEmit8($DE); BinEmit8($E9);                          { fsubp st(1),st0: ST0=x1-x2 }
  BinEmit8($D9); BinEmit8($E1);                          { fabs: ST0=|x1-x2| }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($C1);                          { faddp st(1),st0: ST0=2 }
  BinEmit8($D9); BinEmit8($FA);                          { fsqrt: ST0=sqrt(2) }
  BinEmit8($DE); BinEmit8($F9);                          { fdivp st(1),st0: ST0=|x1-x2|/sqrt(2) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);                          { mov esp,ebp }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { STDERR(x1,x2): LongInt --- |x1-x2|/2 (ecart-type/sqrt(n)) (20 octets) }
  { Pour n=2: STDERR=STD/sqrt(2)=|x1-x2|/sqrt(2)/sqrt(2)=|x1-x2|/2.      }
  BinDefineLabel('_SASRT_stderr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,[ebp+12] x2 }
  BinEmit8($2B); BinEmit8($45); BinEmit8($08);           { sub eax,[ebp+8]  x2-x1 }
  BinEmit8($99);                                          { cdq }
  BinEmit8($31); BinEmit8($D0);                          { xor eax,edx }
  BinEmit8($2B); BinEmit8($C2);                          { sub eax,edx  ABS(x2-x1) }
  BinEmit8($D1); BinEmit8($F8);                          { sar eax,1  /2 }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { STFIPS(abbrev): recherche inverse dans _fipstate_table → code FIPS 1-56 }
  { EBX=target(char1<<8|char2 uppercase), EDX=table ptr, ECX=index }
  BinDefineLabel('_SASRT_stfips');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($57);                          { push ebx,edi }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($08);          { mov edi,[ebp+8] = ptr abbrev }
  { char1: uppercase, validate A-Z }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($07);          { movzx eax,byte[edi] }
  BinEmit8($24); BinEmit8($DF);                          { and al,0xDF (uppercase) }
  BinEmit8($3C); BinEmit8($41);                          { cmp al,'A' }
  BinJccLabel(2,'_sf_notfound');
  BinEmit8($3C); BinEmit8($5A);                          { cmp al,'Z' }
  BinJccLabel(7,'_sf_notfound');
  { char2: uppercase, validate A-Z }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($4F); BinEmit8($01); { movzx ecx,byte[edi+1] }
  BinEmit8($83); BinEmit8($E1); BinEmit8($DF);          { and ecx,0xDF }
  BinEmit8($80); BinEmit8($F9); BinEmit8($41);          { cmp cl,'A' }
  BinJccLabel(2,'_sf_notfound');
  BinEmit8($80); BinEmit8($F9); BinEmit8($5A);          { cmp cl,'Z' }
  BinJccLabel(7,'_sf_notfound');
  { build target word (char2<<8)|char1 → EBX, pour correspondre au mot LE lu }
  BinEmit8($C1); BinEmit8($E1); BinEmit8($08);          { shl ecx,8 }
  BinEmit8($09); BinEmit8($C8);                          { or eax,ecx }
  BinEmit8($89); BinEmit8($C3);                          { mov ebx,eax }
  { search entries 1..56 of _fipstate_table }
  BinMovRegLabel(2,'_fipstate_table');                   { mov edx,&table }
  BinEmit8($83); BinEmit8($C2); BinEmit8($02);          { add edx,2 (skip entry 0) }
  BinEmit8($B9); BinEmit32(1);                           { mov ecx,1 }
  BinDefineLabel('_sf_loop');
  BinEmit8($0F); BinEmit8($B7); BinEmit8($02);          { movzx eax,word[edx] }
  BinEmit8($39); BinEmit8($D8);                          { cmp eax,ebx }
  BinJccLabel(4,'_sf_found');
  BinEmit8($83); BinEmit8($C2); BinEmit8($02);          { add edx,2 }
  BinEmit8($41);                                          { inc ecx }
  BinEmit8($83); BinEmit8($F9); BinEmit8($38);          { cmp ecx,56 }
  BinJccLabel(14,'_sf_loop');
  BinDefineLabel('_sf_notfound');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinJmpLabel('_sf_done');
  BinDefineLabel('_sf_found');
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx }
  BinDefineLabel('_sf_done');
  BinEmit8($5F); BinEmit8($5B);                          { pop edi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { SYSPROD(product): LongInt --- 1 si "BASE", 0 sinon (1 arg, string)     }
  { [ebp+8]=product. Compare 4 octets "BASE" + nul terminal. ret 4.       }
  BinDefineLabel('_SASRT_sysprod');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);     { mov eax,[ebp+8] }
  BinEmit8($31); BinEmit8($C9);                    { xor ecx,ecx (default=0) }
  { cmp dword [eax],'BASE' (LE: 45 53 41 42 = "BASE" octets 0-3) }
  BinEmit8($81); BinEmit8($38);
  BinEmit8($42); BinEmit8($41); BinEmit8($53); BinEmit8($45);
  BinJccLabel(5,'_sp_done');                        { jne → pas BASE }
  BinEmit8($80); BinEmit8($78); BinEmit8($04); BinEmit8($00); { cmp byte [eax+4],0 }
  BinJccLabel(5,'_sp_done');                        { jne → pas exact "BASE\0" }
  BinEmit8($B9); BinEmit32(1);                     { mov ecx,1 }
  BinDefineLabel('_sp_done');
  BinEmit8($89); BinEmit8($C8);                    { mov eax,ecx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { SYSRC(): dernier code systeme disponible, 0 = succes (0 args) }
  BinDefineLabel('_SASRT_sysrc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C3);   { pop ebp; ret (0 args) }

  { SYSTEM(cmd): WinExec(cmd,1); returns 0 on success or error code (1 arg) }
  { [ebp+8]=cmd (string ptr). WinExec>=32 means success -> return 0.       }
  BinDefineLabel('_SASRT_system');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($6A); BinEmit8($01);                          { push 1 SW_SHOWNORMAL }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);           { push [ebp+8] cmd }
  BinCallImport('_WinExec@8');
  BinEmit8($83); BinEmit8($F8); BinEmit8($20);           { cmp eax,32 }
  BinJccLabel(12,'_sys_done');                            { jl: keep error code }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax success }
  BinDefineLabel('_sys_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { Fonctions serie T-U-V }
  { TAN(x): LongInt --- tan(x radians) via x87 FPTAN (25 octets) }
  { FPTAN: ST0=1, ST1=tan(x). FSTP ST(0) elimine le 1.           }
  BinDefineLabel('_SASRT_tan');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);  { fild [ebp+8] }
  BinEmit8($D9); BinEmit8($F2);                  { fptan → ST0=1, ST1=tan(x) }
  BinEmit8($DD); BinEmit8($D8);                  { fstp st(0) → pop 1, ST0=tan(x) }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { TANH(x): LongInt --- (e^x-e^-x)/(e^x+e^-x) via x87 (70 octets) }
  BinDefineLabel('_SASRT_tanh');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($83); BinEmit8($EC); BinEmit8($04);
  { compute e^x }
  BinEmit8($DB); BinEmit8($45); BinEmit8($08);
  BinEmit8($D9); BinEmit8($EA);
  BinEmit8($DE); BinEmit8($C9);
  BinEmit8($D9); BinEmit8($C0);
  BinEmit8($D9); BinEmit8($FC);
  BinEmit8($D9); BinEmit8($C9);
  BinEmit8($D8); BinEmit8($E1);
  BinEmit8($D9); BinEmit8($F0);
  BinEmit8($D9); BinEmit8($E8);
  BinEmit8($DE); BinEmit8($C1);
  BinEmit8($D9); BinEmit8($FD);
  BinEmit8($DD); BinEmit8($D9);                  { → ST0=e^x }
  { store e^x to [ebp-4], compute e^-x }
  BinEmit8($D9); BinEmit8($55); BinEmit8($FC);  { fst dword [ebp-4] }
  BinEmit8($D9); BinEmit8($E8);                  { fld1 → ST0=1, ST1=e^x }
  BinEmit8($DE); BinEmit8($F1);                  { fdivrp st(1): ST1=ST0/ST1=1/e^x=e^-x, pop → ST0=e^-x }
  { load e^x, compute num=(e^x-e^-x) and den=(e^x+e^-x) }
  BinEmit8($D9); BinEmit8($45); BinEmit8($FC);  { fld dword [ebp-4] → ST0=e^x, ST1=e^-x }
  BinEmit8($D8); BinEmit8($E1);                  { fsub st(0),st(1) → ST0=e^x-e^-x=num, ST1=e^-x }
  BinEmit8($D9); BinEmit8($45); BinEmit8($FC);  { fld dword [ebp-4] → ST0=e^x, ST1=num, ST2=e^-x }
  BinEmit8($D8); BinEmit8($C2);                  { fadd st(0),st(2) → ST0=e^x+e^-x=den, ST1=num, ST2=e^-x }
  { tanh = num/den: FDIVP ST(1),ST(0) }
  BinEmit8($DE); BinEmit8($F9);                  { fdivp st(1): ST1=ST1/ST0=num/den=tanh, pop → ST0=tanh, ST1=e^-x }
  BinEmit8($DD); BinEmit8($D9);                  { fstp st(1) → ST0=tanh }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { TIME(): LongInt --- secondes depuis minuit via _sas_systime (38 octets) }
  { Appelle _SASRT_today qui remplit _sas_systime, puis lit wHour/wMinute/wSecond. }
  BinDefineLabel('_SASRT_time');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);                { push ebx,esi,edi }
  BinCallLabel('_SASRT_today');                                { remplit _sas_systime }
  BinMovRegLabel(7, '_sas_systime');                           { mov edi,&_sas_systime }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($47); BinEmit8($08); { movzx eax,word[edi+8]=wHour }
  BinEmit8($69); BinEmit8($C0); BinEmit8($10); BinEmit8($0E); BinEmit8($00); BinEmit8($00); { imul eax,3600 }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($57); BinEmit8($0A); { movzx edx,word[edi+10]=wMinute }
  BinEmit8($6B); BinEmit8($D2); BinEmit8($3C);               { imul edx,60 }
  BinEmit8($01); BinEmit8($D0);                               { add eax,edx }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($57); BinEmit8($0C); { movzx edx,word[edi+12]=wSecond }
  BinEmit8($01); BinEmit8($D0);                               { add eax,edx }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B); BinEmit8($5D); { pop edi,esi,ebx,ebp }
  BinEmit8($C3);                                               { ret (0 arg) }
  { TIMEPART(dt): dt mod 86400 → secondes depuis minuit (1 arg) }
  { 86400 = 0x00015180 → LE: $80 $51 $01 $00                    }
  BinDefineLabel('_SASRT_timepart');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8]    }
  BinEmit8($99);                                  { cdq                }
  BinEmit8($B9); BinEmit8($80); BinEmit8($51); BinEmit8($01); BinEmit8($00);
  BinEmit8($F7); BinEmit8($F9);                  { idiv ecx           }
  BinEmit8($89); BinEmit8($D0);                  { mov eax,edx        }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { TINV(p,df): quantile t approx par seuils de pourcentage entiers (2 args) }
  BinDefineLabel('_SASRT_tinv');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00); { cmp df,0 }
  BinJccLabel(14, '_tinv_done');                         { jle done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] p }
  BinEmit8($83); BinEmit8($F8); BinEmit8($01);           { cmp p,1 }
  BinJccLabel(14, '_tinv_m3');                           { jle -3 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($05);           { cmp p,5 }
  BinJccLabel(12, '_tinv_m2');                           { jl -2 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($32);           { cmp p,50 }
  BinJccLabel(12, '_tinv_m1');                           { jl -1 }
  BinJccLabel(4, '_tinv_zero');                          { je 0 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5F);           { cmp p,95 }
  BinJccLabel(12, '_tinv_p1');                           { jl 1 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($63);           { cmp p,99 }
  BinJccLabel(12, '_tinv_p2');                           { jl 2 }
  BinEmit8($B8); BinEmit32(3);                           { mov eax,3 }
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_m3');
  BinEmit8($B8); BinEmit32(-3);
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_m2');
  BinEmit8($B8); BinEmit32(-2);
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_m1');
  BinEmit8($B8); BinEmit32(-1);
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_zero');
  BinEmit8($31); BinEmit8($C0);
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_p1');
  BinEmit8($B8); BinEmit32(1);
  BinJmpLabel('_tinv_done');
  BinDefineLabel('_tinv_p2');
  BinEmit8($B8); BinEmit32(2);
  BinDefineLabel('_tinv_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { TNONCT(t,df,p): max(0, t - TINV(p,df)) approx (3 args) }
  BinDefineLabel('_SASRT_tnonct');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($0C);           { push df }
  BinEmit8($FF); BinEmit8($75); BinEmit8($10);           { push p }
  BinCallLabel('_SASRT_tinv');                           { eax=tinv(p,df) }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,t }
  BinEmit8($29); BinEmit8($C1);                          { sub ecx,eax }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14, '_tnonct_zero');                       { jle zero }
  BinEmit8($89); BinEmit8($C8);                          { mov eax,ecx }
  BinJmpLabel('_tnonct_done');
  BinDefineLabel('_tnonct_zero');
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinDefineLabel('_tnonct_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  { --- _SASRT_trigamma(x): psi'(x)=sum(1/k^2, k=x..x+99) floor'd (1 arg) }
  { [ebp+8]=x. Locaux (sub esp,16): [ebp-4]=k [ebp-8]=CW_orig [ebp-6]=CW_trunc [ebp-16]=acc }
  BinDefineLabel('_SASRT_trigamma');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($10);           { sub esp,16 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] x }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14,'_trig_zero');                           { jle: x<=0 }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);           { mov [ebp-4],eax k=x }
  BinEmit8($D9); BinEmit8($EE);                          { fldz }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] acc=0.0 }
  BinEmit8($B9); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,100 }
  BinDefineLabel('_trig_loop');
  BinEmit8($DB); BinEmit8($45); BinEmit8($FC);           { fild [ebp-4] k }
  BinEmit8($D8); BinEmit8($C8);                          { fmul st(0),st(0) k^2 }
  BinEmit8($D9); BinEmit8($E8);                          { fld1 }
  BinEmit8($DE); BinEmit8($F1);                          { fdivrp st(1),st -> 1/k^2 }
  BinEmit8($DC); BinEmit8($45); BinEmit8($F0);           { fadd qword[ebp-16] }
  BinEmit8($DD); BinEmit8($5D); BinEmit8($F0);           { fstp qword[ebp-16] store acc }
  BinEmit8($FF); BinEmit8($45); BinEmit8($FC);           { inc [ebp-4] k++ }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_trig_loop');                            { jnz }
  BinEmit8($D9); BinEmit8($7D); BinEmit8($F8);           { fnstcw [ebp-8] }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($45); BinEmit8($F8); { movzx eax,word[ebp-8] }
  BinEmit8($0D); BinEmit32($00000C00);                   { or eax,0x0C00 truncate }
  BinEmit8($66); BinEmit8($89); BinEmit8($45); BinEmit8($FA); { mov [ebp-6],ax }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($FA);           { fldcw [ebp-6] }
  BinEmit8($DD); BinEmit8($45); BinEmit8($F0);           { fld qword[ebp-16] }
  BinEmit8($DB); BinEmit8($5D); BinEmit8($FC);           { fistp [ebp-4] }
  BinEmit8($D9); BinEmit8($6D); BinEmit8($F8);           { fldcw [ebp-8] }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);           { mov eax,[ebp-4] }
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  BinDefineLabel('_trig_zero');
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($89); BinEmit8($EC);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { TRUNC(x,n): LongInt --- tronque x a n decimales (36 octets)        }
  { Pour n>=0: x inchange. Pour n<0: arrondi vers 0 aux puissances de 10. }
  { TRUNC(1234,-1)=1230, TRUNC(1234,-2)=1200, etc.                       }
  BinDefineLabel('_SASRT_trunc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($53);                                          { push ebx }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  x }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] n }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinEmit8($7D); BinEmit8($11);                          { jge .done (+17 → pop ebx) }
  BinEmit8($BB); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ebx,1 }
  BinEmit8($6B); BinEmit8($DB); BinEmit8($0A);           { .loop: imul ebx,ebx,10 }
  BinEmit8($41);                                          { inc ecx }
  BinEmit8($7C); BinEmit8($FA);                          { jl .loop (-6 → imul) }
  BinEmit8($99);                                          { cdq }
  BinEmit8($F7); BinEmit8($FB);                          { idiv ebx }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C3);           { imul eax,ebx }
  BinEmit8($5B);                                          { .done: pop ebx }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }
  { UNIFORM(seed): alias entier de RANUNI(seed), meme LCG (1 arg) }
  BinDefineLabel('_SASRT_uniform');
  BinJmpLabel('_SASRT_ranuni');
  { USS(x1,x2): LongInt --- x1^2+x2^2 via IMUL (21 octets) }
  { Somme des carres non corriges pour 2 valeurs.           }
  BinDefineLabel('_SASRT_uss');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  x1 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C0);           { imul eax,eax    x1^2 }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] x2 }
  BinEmit8($0F); BinEmit8($AF); BinEmit8($C9);           { imul ecx,ecx    x2^2 }
  BinEmit8($01); BinEmit8($C8);                          { add eax,ecx    x1^2+x2^2 }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }
  { VAR(x1,x2): LongInt --- variance echantillon = CSS = (x1-x2)^2/2 }
  { Pour 2 valeurs, VAR = CSS/(n-1) = CSS/1 = CSS.                    }
  BinDefineLabel('_SASRT_var');
  BinJmpLabel('_SASRT_css');
  { VARLEN(dsid,varnum): longueur numerique minimale 8 si ids valides (2 args) }
  BinDefineLabel('_SASRT_varlen');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_varlen_done');
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00);
  BinJccLabel(14, '_varlen_done');
  BinEmit8($B8); BinEmit32(8);
  BinDefineLabel('_varlen_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { VARNUM(dsid,varname): 1 si dsid valide et nom non vide, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_varnum');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_varnum_done');
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);
  BinEmit8($85); BinEmit8($D2);
  BinJccLabel(4, '_varnum_done');
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);
  BinJccLabel(4, '_varnum_done');
  BinEmit8($B8); BinEmit32(1);
  BinDefineLabel('_varnum_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { VARRAY(name): 1 si nom non vide, sinon 0 (1 arg) }
  BinDefineLabel('_SASRT_varray');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($8B); BinEmit8($55); BinEmit8($08);
  BinEmit8($85); BinEmit8($D2);
  BinJccLabel(4, '_varray_done');
  BinEmit8($80); BinEmit8($3A); BinEmit8($00);
  BinJccLabel(4, '_varray_done');
  BinEmit8($B8); BinEmit32(1);
  BinDefineLabel('_varray_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VARRAYX(expr): alias de VARRAY (1 arg) }
  BinDefineLabel('_SASRT_varrayx');
  BinJmpLabel('_SASRT_varray');
  { VARTYPE(dsid,varnum): 1 = numerique si ids valides, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_vartype');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_vartype_done');
  BinEmit8($83); BinEmit8($7D); BinEmit8($0C); BinEmit8($00);
  BinJccLabel(14, '_vartype_done');
  BinEmit8($B8); BinEmit32(1);
  BinDefineLabel('_vartype_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { VERIFY(str,chars): 1er char str absent de chars, 0 si tous presents (2 args) }
  { 53 octets : esi=str edi=chars ebx=pos(0-base) edx=chercheur cl=char_chars }
  BinDefineLabel('_SASRT_verify');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);           { push esi; push edi; push ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12] }
  BinEmit8($31); BinEmit8($DB);                           { xor ebx,ebx }
  { _outer(14): }
  BinEmit8($8A); BinEmit8($06);                           { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                           { test al,al }
  BinEmit8($74); BinEmit8($18);                           { jz _all_found +24→44 }
  BinEmit8($89); BinEmit8($FA);                           { mov edx,edi }
  { _search(22): }
  BinEmit8($8A); BinEmit8($0A);                           { mov cl,[edx] }
  BinEmit8($84); BinEmit8($C9);                           { test cl,cl }
  BinEmit8($74); BinEmit8($07);                           { jz _unique +7→35 }
  BinEmit8($38); BinEmit8($C8);                           { cmp al,cl }
  BinEmit8($74); BinEmit8($08);                           { je _next +8→40 }
  BinEmit8($42);                                           { inc edx }
  BinEmit8($EB); BinEmit8($F3);                           { jmp _search -13→22 }
  { _unique(35): }
  BinEmit8($8D); BinEmit8($43); BinEmit8($01);           { lea eax,[ebx+1] }
  BinEmit8($EB); BinEmit8($06);                           { jmp _done +6→46 }
  { _next(40): }
  BinEmit8($46);                                           { inc esi }
  BinEmit8($43);                                           { inc ebx }
  BinEmit8($EB); BinEmit8($E2);                           { jmp _outer -30→14 }
  { _all_found(44): }
  BinEmit8($31); BinEmit8($C0);                           { xor eax,eax }
  { _done(46): }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { VFORMATD(var): decimales format, 0 par defaut (1 arg) }
  BinDefineLabel('_SASRT_vformatd');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VFORMATDX(arg): alias de VFORMATD (1 arg) }
  BinDefineLabel('_SASRT_vformatdx');
  BinJmpLabel('_SASRT_vformatd');
  { VFORMATW(var): largeur format numerique minimale 8 si arg non nul (1 arg) }
  BinDefineLabel('_SASRT_vformatw');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_vformatw_done');
  BinEmit8($B8); BinEmit32(8);
  BinDefineLabel('_vformatw_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VFORMATWX(arg): alias de VFORMATW (1 arg) }
  BinDefineLabel('_SASRT_vformatwx');
  BinJmpLabel('_SASRT_vformatw');
  { VINARRAY(name): 1 si nom non vide, sinon 0 (1 arg) }
  BinDefineLabel('_SASRT_vinarray');
  BinJmpLabel('_SASRT_varray');
  { VINARRAYX(expr): alias de VINARRAY (1 arg) }
  BinDefineLabel('_SASRT_vinarrayx');
  BinJmpLabel('_SASRT_varray');
  { VINFORMATD(var): decimales informat, 0 par defaut (1 arg) }
  BinDefineLabel('_SASRT_vinformatd');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VINFORMATDX(arg): alias de VINFORMATD (1 arg) }
  BinDefineLabel('_SASRT_vinformatdx');
  BinJmpLabel('_SASRT_vinformatd');
  { VINFORMATW(var): largeur informat minimale 8 si arg non nul (1 arg) }
  BinDefineLabel('_SASRT_vinformatw');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_vinformatw_done');
  BinEmit8($B8); BinEmit32(8);
  BinDefineLabel('_vinformatw_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VINFORMATWX(arg): alias de VINFORMATW (1 arg) }
  BinDefineLabel('_SASRT_vinformatwx');
  BinJmpLabel('_SASRT_vinformatw');
  { VLENGTH(var): longueur numerique minimale 8 si arg non nul (1 arg) }
  BinDefineLabel('_SASRT_vlength');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($31); BinEmit8($C0);
  BinEmit8($83); BinEmit8($7D); BinEmit8($08); BinEmit8($00);
  BinJccLabel(14, '_vlength_done');
  BinEmit8($B8); BinEmit32(8);
  BinDefineLabel('_vlength_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { VLENGTHX(expr): alias de VLENGTH (1 arg) }
  BinDefineLabel('_SASRT_vlengthx');
  BinJmpLabel('_SASRT_vlength');
  { WEEKDAY(date): ((date+5) mod 7)+1, 1=dim 2=lun ... 7=sam (1 arg) }
  { 31 octets : formule modulo 7 avec correction pour valeurs negatives }
  BinDefineLabel('_SASRT_weekday');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($83); BinEmit8($C0); BinEmit8($05);           { add eax,5 }
  BinEmit8($99);                                           { cdq }
  BinEmit8($B9); BinEmit8($07); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,7 }
  BinEmit8($F7); BinEmit8($F9);                           { idiv ecx }
  BinEmit8($85); BinEmit8($D2);                           { test edx,edx }
  BinEmit8($79); BinEmit8($03);                           { jns .ok +3→24 }
  BinEmit8($83); BinEmit8($C2); BinEmit8($07);           { add edx,7 }
  BinEmit8($89); BinEmit8($D0);                           { .ok: mov eax,edx }
  BinEmit8($40);                                           { inc eax }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { YEAR: defini dans EmitRuntimeDateFunc (via _SASRT_ymd_calc) }
  { YIELDP(p,r): rendement approx r*100/p si p>0, sinon 0 (2 args) }
  BinDefineLabel('_SASRT_yieldp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,p }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14, '_yieldp_zero');                       { jle zero }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);           { mov eax,r }
  BinEmit8($6B); BinEmit8($C0); BinEmit8($64);           { imul eax,eax,100 }
  BinEmit8($99);                                        { cdq }
  BinEmit8($F7); BinEmit8($F9);                         { idiv ecx }
  BinJmpLabel('_yieldp_done');
  BinDefineLabel('_yieldp_zero');
  BinEmit8($31); BinEmit8($C0);
  BinDefineLabel('_yieldp_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);
  { YRDIF(d1,d2,basis): LongInt --- (d2-d1)/365 (21 octets) }
  { [ebp+8]=d1 [ebp+12]=d2 [ebp+16]=basis(ignore). }
  BinDefineLabel('_SASRT_yrdif');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);  { mov eax,[ebp+12] d2 }
  BinEmit8($2B); BinEmit8($45); BinEmit8($08);  { sub eax,[ebp+8]  d1 }
  BinEmit8($99);                                  { cdq }
  BinEmit8($B9); BinEmit8($6D); BinEmit8($01); BinEmit8($00); BinEmit8($00); { mov ecx,365 }
  BinEmit8($F7); BinEmit8($F9);                  { idiv ecx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00);
  { YYQ(year,quarter): LongInt --- premier jour du trimestre (88 octets) }
  { [ebp+8]=year [ebp+12]=quarter. month=quarter*3-2, day=1. Formule JDN.}
  BinDefineLabel('_SASRT_yyq');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);                { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);               { mov esi,[ebp+8] year }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);               { mov ecx,[ebp+12] quarter }
  BinEmit8($6B); BinEmit8($C9); BinEmit8($03);               { imul ecx,ecx,3 }
  BinEmit8($83); BinEmit8($E9); BinEmit8($02);               { sub ecx,2 → month }
  BinEmit8($BB); BinEmit8($01); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ebx,1 (day) }
  BinEmit8($83); BinEmit8($F9); BinEmit8($02);               { cmp ecx,2 }
  BinEmit8($7F); BinEmit8($04);                               { jg .no_adj }
  BinEmit8($4E);                                               { dec esi (year-1) }
  BinEmit8($83); BinEmit8($C1); BinEmit8($0C);               { add ecx,12 }
  { .no_adj: term1 = floor(1461*(year'+4716)/4) }
  BinEmit8($89); BinEmit8($F0);                               { mov eax,esi }
  BinEmit8($05); BinEmit8($6C); BinEmit8($12); BinEmit8($00); BinEmit8($00); { add eax,4716 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  { term2 = floor((153*(month'+1)+2)/5) }
  BinEmit8($8D); BinEmit8($79); BinEmit8($01);               { lea edi,[ecx+1] }
  BinEmit8($69); BinEmit8($FF); BinEmit8($99); BinEmit8($00); BinEmit8($00); BinEmit8($00); { imul edi,153 }
  BinEmit8($83); BinEmit8($C7); BinEmit8($02);               { add edi,2 }
  BinEmit8($50);                                               { push eax (save term1) }
  BinEmit8($89); BinEmit8($F8);                               { mov eax,edi }
  BinEmit8($99);                                               { cdq }
  BinEmit8($BF); BinEmit8($05); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov edi,5 }
  BinEmit8($F7); BinEmit8($FF);                               { idiv edi }
  BinEmit8($5F);                                               { pop edi (term1) }
  BinEmit8($01); BinEmit8($F8);                               { add eax,edi }
  BinEmit8($01); BinEmit8($D8);                               { add eax,ebx (day=1) }
  BinEmit8($2D); BinEmit8($48); BinEmit8($35); BinEmit8($25); BinEmit8($00); { sub eax,2438472 }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B); BinEmit8($5D); { pop edi,esi,ebx,ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);               { ret 8 }
  { ZIPFIPS(zip): table minimale; 100xx/101xx -> NY FIPS 36, sinon 0 (1 arg) }
  BinDefineLabel('_SASRT_zipfips');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,zip }
  BinEmit8($B9); BinEmit32(100);                         { mov ecx,100 }
  BinEmit8($99);                                        { cdq }
  BinEmit8($F7); BinEmit8($F9);                         { idiv ecx => eax=zip/100 }
  BinEmit8($83); BinEmit8($F8); BinEmit8($64);           { cmp eax,100 }
  BinJccLabel(4, '_zipfips_ny');                        { je NY }
  BinEmit8($83); BinEmit8($F8); BinEmit8($65);           { cmp eax,101 }
  BinJccLabel(4, '_zipfips_ny');                        { je NY }
  BinEmit8($31); BinEmit8($C0);                         { xor eax,eax }
  BinJmpLabel('_zipfips_done');
  BinDefineLabel('_zipfips_ny');
  BinEmit8($B8); BinEmit32(36);                         { mov eax,36 }
  BinDefineLabel('_zipfips_done');
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
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

  { SUM variadic est genere inline dans CodegenExprEAX }
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
  { Fonctions trigonometriques x87 (resultat entier) }
  If FName = 'ARCOS'   Then Begin BinCallLabel('_SASRT_arcos');   Exit; End;
  If FName = 'ARSIN'   Then Begin BinCallLabel('_SASRT_arsin');   Exit; End;
  If FName = 'ATAN'    Then Begin BinCallLabel('_SASRT_atan');    Exit; End;
  If FName = 'ATAN2'   Then Begin BinCallLabel('_SASRT_atan2');   Exit; End;
  { Fonctions mathematiques speciales }
  If FName = 'AIRY'    Then Begin BinCallLabel('_SASRT_airy');    Exit; End;
  If FName = 'BETAINV' Then Begin BinCallLabel('_SASRT_betainv'); Exit; End;
  { Fonctions de caractere }
  If FName = 'BYTE'    Then Begin BinCallLabel('_SASRT_byte');    Exit; End;
  { Fonctions d attribut de dataset }
  If FName = 'ATTRC'   Then Begin BinCallLabel('_SASRT_attrc');   Exit; End;
  If FName = 'ATTRN'   Then Begin BinCallLabel('_SASRT_attrn');   Exit; End;
  { CDF / CEILZ / CEXIST }
  If FName = 'CDF'     Then Begin BinCallLabel('_SASRT_cdf');     Exit; End;
  If FName = 'CEILZ'   Then Begin BinCallLabel('_SASRT_ceilz');   Exit; End;
  If FName = 'CEXIST'  Then Begin BinCallLabel('_SASRT_cexist');  Exit; End;
  { CINV / CLOSE / CNONCT }
  If FName = 'CINV'    Then Begin BinCallLabel('_SASRT_cinv');    Exit; End;
  If FName = 'CLOSE'   Then Begin BinCallLabel('_SASRT_close');   Exit; End;
  If FName = 'CNONCT'  Then Begin BinCallLabel('_SASRT_cnonct');  Exit; End;
  { COMB : combinaisons C(n,r) }
  If FName = 'COMB'    Then Begin BinCallLabel('_SASRT_comb');    Exit; End;
  { COMPBL : compression espaces multiples (retourne ptr) }
  If FName = 'COMPBL'  Then Begin BinCallLabel('_SASRT_compbl');  Exit; End;
  { COLLATE : sequence ASCII [start..end] }
  If FName = 'COLLATE' Then Begin BinCallLabel('_SASRT_collate'); Exit; End;
  { Finance/constantes }
  If FName = 'COMPOUND' Then Begin BinCallLabel('_SASRT_compound'); Exit; End;
  If FName = 'CONSTANT' Then Begin BinCallLabel('_SASRT_constant'); Exit; End;
  If FName = 'CONVX'   Then Begin BinCallLabel('_SASRT_convx');   Exit; End;
  If FName = 'CONVXP'  Then Begin BinCallLabel('_SASRT_convxp');  Exit; End;
  { Trigonometriques / hyperboliques }
  If FName = 'COS'     Then Begin BinCallLabel('_SASRT_cos');     Exit; End;
  If FName = 'COSH'    Then Begin BinCallLabel('_SASRT_cosh');    Exit; End;
  { Statistiques et attributs d observation }
  If FName = 'CSS'     Then Begin BinCallLabel('_SASRT_css');     Exit; End;
  If FName = 'CV'      Then Begin BinCallLabel('_SASRT_cv');      Exit; End;
  If FName = 'CUROBS'  Then Begin BinCallLabel('_SASRT_curobs');  Exit; End;
  { Amortissement }
  If FName = 'DACCDB'   Then Begin BinCallLabel('_SASRT_daccdb');   Exit; End;
  If FName = 'DACCDBSL' Then Begin BinCallLabel('_SASRT_daccdbsl'); Exit; End;
  If FName = 'DACCSL'   Then Begin BinCallLabel('_SASRT_daccsl');   Exit; End;
  If FName = 'DACCSYD'  Then Begin BinCallLabel('_SASRT_daccsyd');  Exit; End;
  If FName = 'DACCTAB'  Then Begin BinCallLabel('_SASRT_dacctab');  Exit; End;
  { Fonction speciale Airy derivee }
  If FName = 'DAIRY'   Then Begin BinCallLabel('_SASRT_dairy');   Exit; End;
  { Fonctions de date serie D }
  If FName = 'DATDIF'   Then Begin BinCallLabel('_SASRT_datdif');   Exit; End;
  If FName = 'DATE'     Then Begin BinCallLabel('_SASRT_date');     Exit; End;
  If FName = 'DATEJUL'  Then Begin BinCallLabel('_SASRT_datejul');  Exit; End;
  If FName = 'DATEPART' Then Begin BinCallLabel('_SASRT_datepart'); Exit; End;
  If FName = 'DATETIME' Then Begin BinCallLabel('_SASRT_datetime'); Exit; End;
  { Fonctions repertoire et dataset }
  If FName = 'DCLOSE'   Then Begin BinCallLabel('_SASRT_dclose');   Exit; End;
  If FName = 'DNUM'     Then Begin BinCallLabel('_SASRT_dnum');     Exit; End;
  If FName = 'DOPEN'    Then Begin BinCallLabel('_SASRT_dopen');    Exit; End;
  If FName = 'DOPTNUM'  Then Begin BinCallLabel('_SASRT_doptnum');  Exit; End;
  If FName = 'DROPNOTE' Then Begin BinCallLabel('_SASRT_dropnote'); Exit; End;
  { Fonctions chaines serie D }
  If FName = 'DEQUOTE'  Then Begin BinCallLabel('_SASRT_dequote');  Exit; End;
  If FName = 'DSNAME'   Then Begin BinCallLabel('_SASRT_dsname');   Exit; End;
  If FName = 'DINFO'    Then Begin BinCallLabel('_SASRT_dinfo');    Exit; End;
  If FName = 'DOPTNAME' Then Begin BinCallLabel('_SASRT_doptname'); Exit; End;
  If FName = 'DREAD'    Then Begin BinCallLabel('_SASRT_dread');    Exit; End;
  { Depreciation serie DEP }
  If FName = 'DEPDB'    Then Begin BinCallLabel('_SASRT_depdb');    Exit; End;
  If FName = 'DEPDBSL'  Then Begin BinCallLabel('_SASRT_depdbsl');  Exit; End;
  If FName = 'DEPSL'    Then Begin BinCallLabel('_SASRT_depsl');    Exit; End;
  If FName = 'DEPSYD'   Then Begin BinCallLabel('_SASRT_depsyd');   Exit; End;
  If FName = 'DEPTAB'   Then Begin BinCallLabel('_SASRT_deptab');   Exit; End;
  { Fonctions math et statistiques }
  If FName = 'DEVIANCE' Then Begin BinCallLabel('_SASRT_deviance'); Exit; End;
  If FName = 'DHMS'     Then Begin BinCallLabel('_SASRT_dhms');     Exit; End;
  If FName = 'DIF'      Then Begin BinCallLabel('_SASRT_dif');      Exit; End;
  If FName = 'DIGAMMA'  Then Begin BinCallLabel('_SASRT_digamma');  Exit; End;
  If FName = 'DUR'      Then Begin BinCallLabel('_SASRT_dur');      Exit; End;
  { Fonctions serie E-F (batch 4) }
  If FName = 'DURP'     Then Begin BinCallLabel('_SASRT_durp');     Exit; End;
  If FName = 'ERF'      Then Begin BinCallLabel('_SASRT_erf');      Exit; End;
  If FName = 'ERFC'     Then Begin BinCallLabel('_SASRT_erfc');     Exit; End;
  If FName = 'EXIST'    Then Begin BinCallLabel('_SASRT_exist');    Exit; End;
  If FName = 'FACT'     Then Begin BinCallLabel('_SASRT_fact');     Exit; End;
  If FName = 'FAPPEND'  Then Begin BinCallLabel('_SASRT_fappend');  Exit; End;
  If FName = 'FCLOSE'   Then Begin BinCallLabel('_SASRT_fclose');   Exit; End;
  If FName = 'FCOL'     Then Begin BinCallLabel('_SASRT_fcol');     Exit; End;
  If FName = 'FDELETE'  Then Begin BinCallLabel('_SASRT_fdelete');  Exit; End;
  If FName = 'FETCH'    Then Begin BinCallLabel('_SASRT_fetch');    Exit; End;
  If FName = 'FETCHOBS' Then Begin BinCallLabel('_SASRT_fetchobs'); Exit; End;
  If FName = 'FEXIST'   Then Begin BinCallLabel('_SASRT_fexist');   Exit; End;
  If FName = 'FGET'     Then Begin BinCallLabel('_SASRT_fget');     Exit; End;
  If FName = 'FILEEXIST' Then Begin BinCallLabel('_SASRT_fileexist'); Exit; End;
  If FName = 'FILENAME' Then Begin BinCallLabel('_SASRT_filename'); Exit; End;
  If FName = 'FILEREF'  Then Begin BinCallLabel('_SASRT_fileref');  Exit; End;
  If FName = 'FINFO'    Then Begin BinCallLabel('_SASRT_finfo');    Exit; End;
  If FName = 'FINV'     Then Begin BinCallLabel('_SASRT_finv');     Exit; End;
  If FName = 'FIPNAME'  Then Begin BinCallLabel('_SASRT_fipname');  Exit; End;
  If FName = 'FIPNAMEL' Then Begin BinCallLabel('_SASRT_fipnamel'); Exit; End;
  If FName = 'FIPSTATE' Then Begin BinCallLabel('_SASRT_fipstate'); Exit; End;
  { Fonctions serie F (suite batch 5) }
  If FName = 'FNONCT'   Then Begin BinCallLabel('_SASRT_fnonct');   Exit; End;
  If FName = 'FNOTE'    Then Begin BinCallLabel('_SASRT_fnote');    Exit; End;
  If FName = 'FOPEN'    Then Begin BinCallLabel('_SASRT_fopen');    Exit; End;
  If FName = 'FOPTNAME' Then Begin BinCallLabel('_SASRT_foptname'); Exit; End;
  If FName = 'FOPTNUM'  Then Begin BinCallLabel('_SASRT_foptnum');  Exit; End;
  If FName = 'FPOINT'   Then Begin BinCallLabel('_SASRT_fpoint');   Exit; End;
  If FName = 'FPOS'     Then Begin BinCallLabel('_SASRT_fpos');     Exit; End;
  If FName = 'FPUT'     Then Begin BinCallLabel('_SASRT_fput');     Exit; End;
  If FName = 'FREAD'    Then Begin BinCallLabel('_SASRT_fread');    Exit; End;
  If FName = 'FREWIND'  Then Begin BinCallLabel('_SASRT_frewind');  Exit; End;
  If FName = 'FRLEN'    Then Begin BinCallLabel('_SASRT_frlen');    Exit; End;
  If FName = 'FSEP'     Then Begin BinCallLabel('_SASRT_fsep');     Exit; End;
  If FName = 'FUZZ'     Then Begin BinCallLabel('_SASRT_fuzz');     Exit; End;
  If FName = 'FWRITE'   Then Begin BinCallLabel('_SASRT_fwrite');   Exit; End;
  { Fonctions serie G-H (batch 5) }
  If FName = 'GAMINV'   Then Begin BinCallLabel('_SASRT_gaminv');   Exit; End;
  If FName = 'GAMMA'    Then Begin BinCallLabel('_SASRT_gamma');    Exit; End;
  If FName = 'GETOPTION' Then Begin BinCallLabel('_SASRT_getoption'); Exit; End;
  If FName = 'GETVARC'  Then Begin BinCallLabel('_SASRT_getvarc');  Exit; End;
  If FName = 'GETVARN'  Then Begin BinCallLabel('_SASRT_getvarn');  Exit; End;
  If FName = 'HBOUND'   Then Begin BinCallLabel('_SASRT_hbound');   Exit; End;
  If FName = 'HMS'      Then Begin BinCallLabel('_SASRT_hms');      Exit; End;
  If FName = 'HOUR'     Then Begin BinCallLabel('_SASRT_hour');     Exit; End;
  { Fonctions serie H-K (batch 6) }
  If FName = 'HTMLDECODE' Then Begin BinCallLabel('_SASRT_htmldecode'); Exit; End;
  If FName = 'HTMLENCODE' Then Begin BinCallLabel('_SASRT_htmlencode'); Exit; End;
  If FName = 'IBESSEL'  Then Begin BinCallLabel('_SASRT_ibessel');  Exit; End;
  If FName = 'INDEXC'   Then Begin BinCallLabel('_SASRT_indexc');   Exit; End;
  If FName = 'INDEXW'   Then Begin BinCallLabel('_SASRT_indexw');   Exit; End;
  If FName = 'INPUT'    Then Begin BinCallLabel('_SASRT_input');    Exit; End;
  If FName = 'INPUTC'   Then Begin BinCallLabel('_SASRT_inputc');   Exit; End;
  If FName = 'INPUTN'   Then Begin BinCallLabel('_SASRT_inputn');   Exit; End;
  If FName = 'INTCK'    Then Begin BinCallLabel('_SASRT_intck');    Exit; End;
  If FName = 'INTNX'    Then Begin BinCallLabel('_SASRT_intnx');    Exit; End;
  If FName = 'INTRR'    Then Begin BinCallLabel('_SASRT_intrr');    Exit; End;
  If FName = 'IORCMSG'  Then Begin BinCallLabel('_SASRT_iorcmsg');  Exit; End;
  If FName = 'IRR'      Then Begin BinCallLabel('_SASRT_irr');      Exit; End;
  If FName = 'JBESSEL'  Then Begin BinCallLabel('_SASRT_jbessel');  Exit; End;
  If FName = 'JULDATE'  Then Begin BinCallLabel('_SASRT_juldate');  Exit; End;
  If FName = 'JULDATE7' Then Begin BinCallLabel('_SASRT_juldate7'); Exit; End;
  If FName = 'KCOMPARE' Then Begin BinCallLabel('_SASRT_kcompare'); Exit; End;
  If FName = 'KCOMPRESS' Then Begin BinCallLabel('_SASRT_kcompress'); Exit; End;
  If FName = 'KCOUNT'   Then Begin BinCallLabel('_SASRT_kcount');   Exit; End;
  If FName = 'KINDEX'   Then Begin BinCallLabel('_SASRT_kindex');   Exit; End;
  If FName = 'KINDEXC'  Then Begin BinCallLabel('_SASRT_kindexc');  Exit; End;
  If FName = 'KLEFT'    Then Begin BinCallLabel('_SASRT_kleft');    Exit; End;
  { Fonctions serie K (suite batch 7) }
  If FName = 'KLENGTH'   Then Begin BinCallLabel('_SASRT_klength');   Exit; End;
  If FName = 'KLOWCASE'  Then Begin BinCallLabel('_SASRT_klowcase');  Exit; End;
  If FName = 'KREVERSE'  Then Begin BinCallLabel('_SASRT_kreverse');  Exit; End;
  If FName = 'KRIGHT'    Then Begin BinCallLabel('_SASRT_kright');    Exit; End;
  If FName = 'KSCAN'     Then Begin BinCallLabel('_SASRT_kscan');     Exit; End;
  If FName = 'KSTRCAT'   Then Begin BinCallLabel('_SASRT_kstrcat');   Exit; End;
  If FName = 'KSUBSTR'   Then Begin BinCallLabel('_SASRT_ksubstr');   Exit; End;
  If FName = 'KSUBSTRB'  Then Begin BinCallLabel('_SASRT_ksubstrb');  Exit; End;
  If FName = 'KTRANSLATE' Then Begin BinCallLabel('_SASRT_ktranslate'); Exit; End;
  If FName = 'KTRIM'     Then Begin BinCallLabel('_SASRT_ktrim');     Exit; End;
  If FName = 'KTRUNCATE' Then Begin BinCallLabel('_SASRT_ktruncate'); Exit; End;
  If FName = 'KUPCASE'   Then Begin BinCallLabel('_SASRT_kupcase');   Exit; End;
  If FName = 'KUPDATE'   Then Begin BinCallLabel('_SASRT_kupdate');   Exit; End;
  If FName = 'KUPDATEB'  Then Begin BinCallLabel('_SASRT_kupdateb');  Exit; End;
  If FName = 'KURTOSIS'  Then Begin BinCallLabel('_SASRT_kurtosis');  Exit; End;
  If FName = 'KVERIFY'   Then Begin BinCallLabel('_SASRT_kverify');   Exit; End;
  { Fonctions serie L (batch 7) }
  If FName = 'LAG'       Then Begin BinCallLabel('_SASRT_lag');       Exit; End;
  If FName = 'LBOUND'    Then Begin BinCallLabel('_SASRT_lbound');    Exit; End;
  If FName = 'LGAMMA'    Then Begin BinCallLabel('_SASRT_lgamma');    Exit; End;
  If FName = 'LIBNAME'   Then Begin BinCallLabel('_SASRT_libname');   Exit; End;
  If FName = 'LIBREF'    Then Begin BinCallLabel('_SASRT_libref');    Exit; End;
  { Fonctions serie L-O (batch 8) }
  If FName = 'LOG10'    Then Begin BinCallLabel('_SASRT_log10');    Exit; End;
  If FName = 'LOG2'     Then Begin BinCallLabel('_SASRT_log2');     Exit; End;
  If FName = 'LOGPDF'   Then Begin BinCallLabel('_SASRT_logpdf');   Exit; End;
  If FName = 'LOGSDF'   Then Begin BinCallLabel('_SASRT_logsdf');   Exit; End;
  If FName = 'MEAN'     Then Begin BinCallLabel('_SASRT_mean');     Exit; End;
  If FName = 'MINUTE'   Then Begin BinCallLabel('_SASRT_minute');   Exit; End;
  If FName = 'MISSING'  Then Begin BinCallLabel('_SASRT_missing');  Exit; End;
  If FName = 'MODULEC'  Then Begin BinCallLabel('_SASRT_modulec');  Exit; End;
  If FName = 'MODULEIC' Then Begin BinCallLabel('_SASRT_moduleic'); Exit; End;
  If FName = 'MODULEIN' Then Begin BinCallLabel('_SASRT_modulein'); Exit; End;
  If FName = 'MODULEN'  Then Begin BinCallLabel('_SASRT_modulen');  Exit; End;
  If FName = 'MOPEN'    Then Begin BinCallLabel('_SASRT_mopen');    Exit; End;
  If FName = 'MORT'     Then Begin BinCallLabel('_SASRT_mort');     Exit; End;
  If FName = 'N'        Then Begin BinCallLabel('_SASRT_n');        Exit; End;
  If FName = 'NETPV'    Then Begin BinCallLabel('_SASRT_netpv');    Exit; End;
  If FName = 'NMISS'    Then Begin BinCallLabel('_SASRT_nmiss');    Exit; End;
  If FName = 'NORMAL'   Then Begin BinCallLabel('_SASRT_normal');   Exit; End;
  If FName = 'NOTE'     Then Begin BinCallLabel('_SASRT_note');     Exit; End;
  If FName = 'NPV'      Then Begin BinCallLabel('_SASRT_npv');      Exit; End;
  If FName = 'OPEN'     Then Begin BinCallLabel('_SASRT_open');     Exit; End;
  { Fonctions serie O-P (batch 9) }
  If FName = 'ORDINAL'  Then Begin BinCallLabel('_SASRT_ordinal');  Exit; End;
  If FName = 'PATHNAME' Then Begin BinCallLabel('_SASRT_pathname'); Exit; End;
  If FName = 'PDF'      Then Begin BinCallLabel('_SASRT_pdf');      Exit; End;
  If FName = 'PEEK'     Then Begin BinCallLabel('_SASRT_peek');     Exit; End;
  If FName = 'PEEKC'    Then Begin BinCallLabel('_SASRT_peekc');    Exit; End;
  If FName = 'PERM'     Then Begin BinCallLabel('_SASRT_perm');     Exit; End;
  If FName = 'POINT'    Then Begin BinCallLabel('_SASRT_point');    Exit; End;
  If FName = 'POISSON'  Then Begin BinCallLabel('_SASRT_poisson');  Exit; End;
  If FName = 'POKE'     Then Begin BinCallLabel('_SASRT_poke');     Exit; End;
  If FName = 'PROBBETA' Then Begin BinCallLabel('_SASRT_probbeta'); Exit; End;
  If FName = 'PROBBNML' Then Begin BinCallLabel('_SASRT_probbnml'); Exit; End;
  If FName = 'PROBBNRM' Then Begin BinCallLabel('_SASRT_probbnrm'); Exit; End;
  If FName = 'PROBCHI'  Then Begin BinCallLabel('_SASRT_probchi');  Exit; End;
  If FName = 'PROBF'    Then Begin BinCallLabel('_SASRT_probf');    Exit; End;
  If FName = 'PROBGAM'  Then Begin BinCallLabel('_SASRT_probgam');  Exit; End;
  If FName = 'PROBHYPR' Then Begin BinCallLabel('_SASRT_probhypr'); Exit; End;
  If FName = 'PROBIT'   Then Begin BinCallLabel('_SASRT_probit');   Exit; End;
  If FName = 'PROBMC'   Then Begin BinCallLabel('_SASRT_probmc');   Exit; End;
  If FName = 'PROBNEGB' Then Begin BinCallLabel('_SASRT_probnegb'); Exit; End;
  If FName = 'PROBNORM' Then Begin BinCallLabel('_SASRT_probnorm'); Exit; End;
  If FName = 'PROBT'    Then Begin BinCallLabel('_SASRT_probt');    Exit; End;
  If FName = 'PUTC'     Then Begin BinCallLabel('_SASRT_putc');     Exit; End;
  If FName = 'PUTN'     Then Begin BinCallLabel('_SASRT_putn');     Exit; End;
  If FName = 'PVP'      Then Begin BinCallLabel('_SASRT_pvp');      Exit; End;
  { Fonctions serie Q-S (batch 10) }
  If FName = 'QTR'      Then Begin BinCallLabel('_SASRT_qtr');      Exit; End;
  If FName = 'QUOTE'    Then Begin BinCallLabel('_SASRT_quote');    Exit; End;
  If FName = 'RANBIN'   Then Begin BinCallLabel('_SASRT_ranbin');   Exit; End;
  If FName = 'RANCAU'   Then Begin BinCallLabel('_SASRT_rancau');   Exit; End;
  If FName = 'RANEXP'   Then Begin BinCallLabel('_SASRT_ranexp');   Exit; End;
  If FName = 'RANGAM'   Then Begin BinCallLabel('_SASRT_rangam');   Exit; End;
  If FName = 'RANGE'    Then Begin BinCallLabel('_SASRT_range');    Exit; End;
  If FName = 'RANK'     Then Begin BinCallLabel('_SASRT_rank');     Exit; End;
  If FName = 'RANNOR'   Then Begin BinCallLabel('_SASRT_rannor');   Exit; End;
  If FName = 'RANPOI'   Then Begin BinCallLabel('_SASRT_ranpoi');   Exit; End;
  If FName = 'RANTBL'   Then Begin BinCallLabel('_SASRT_rantbl');   Exit; End;
  If FName = 'RANTRI'   Then Begin BinCallLabel('_SASRT_rantri');   Exit; End;
  If FName = 'RANUNI'   Then Begin BinCallLabel('_SASRT_ranuni');   Exit; End;
  If FName = 'REPEAT'   Then Begin BinCallLabel('_SASRT_repeat');   Exit; End;
  If FName = 'RESOLVE'  Then Begin BinCallLabel('_SASRT_resolve');  Exit; End;
  If FName = 'REVERSE'  Then Begin BinCallLabel('_SASRT_reverse');  Exit; End;
  If FName = 'REWIND'   Then Begin BinCallLabel('_SASRT_rewind');   Exit; End;
  If FName = 'RXMATCH'  Then Begin BinCallLabel('_SASRT_rxmatch');  Exit; End;
  If FName = 'RXPARSE'  Then Begin BinCallLabel('_SASRT_rxparse');  Exit; End;
  If FName = 'SAVING'   Then Begin BinCallLabel('_SASRT_saving');   Exit; End;
  If FName = 'SCAN'     Then Begin BinCallLabel('_SASRT_scan');     Exit; End;
  If FName = 'SDF'      Then Begin BinCallLabel('_SASRT_sdf');      Exit; End;
  { Fonctions serie S (batch 11) }
  If FName = 'SECOND'   Then Begin BinCallLabel('_SASRT_second');   Exit; End;
  If FName = 'SIN'      Then Begin BinCallLabel('_SASRT_sin');      Exit; End;
  If FName = 'SINH'     Then Begin BinCallLabel('_SASRT_sinh');     Exit; End;
  If FName = 'SKEWNESS' Then Begin BinCallLabel('_SASRT_skewness'); Exit; End;
  If FName = 'SOUNDEX'  Then Begin BinCallLabel('_SASRT_soundex');  Exit; End;
  If FName = 'SPEDIS'   Then Begin BinCallLabel('_SASRT_spedis');   Exit; End;
  If FName = 'STD'      Then Begin BinCallLabel('_SASRT_std');      Exit; End;
  If FName = 'STDERR'   Then Begin BinCallLabel('_SASRT_stderr');   Exit; End;
  If FName = 'STFIPS'   Then Begin BinCallLabel('_SASRT_stfips');   Exit; End;
  If FName = 'STNAME'   Then Begin BinCallLabel('_SASRT_stname');   Exit; End;
  If FName = 'STNAMEL'  Then Begin BinCallLabel('_SASRT_stnamel');  Exit; End;
  If FName = 'SYMGET'   Then Begin BinCallLabel('_SASRT_symget');   Exit; End;
  If FName = 'SYSGET'   Then Begin BinCallLabel('_SASRT_sysget');   Exit; End;
  If FName = 'SYSMSG'   Then Begin BinCallLabel('_SASRT_sysmsg');   Exit; End;
  If FName = 'SYSPARM'  Then Begin BinCallLabel('_SASRT_sysparm');  Exit; End;
  If FName = 'SYSPROD'  Then Begin BinCallLabel('_SASRT_sysprod');  Exit; End;
  If FName = 'SYSRC'    Then Begin BinCallLabel('_SASRT_sysrc');    Exit; End;
  If FName = 'SYSTEM'   Then Begin BinCallLabel('_SASRT_system');   Exit; End;
  { Fonctions serie T-U-V (batch 12) }
  If FName = 'TAN'       Then Begin BinCallLabel('_SASRT_tan');       Exit; End;
  If FName = 'TANH'      Then Begin BinCallLabel('_SASRT_tanh');      Exit; End;
  If FName = 'TIME'      Then Begin BinCallLabel('_SASRT_time');      Exit; End;
  If FName = 'TIMEPART'  Then Begin BinCallLabel('_SASRT_timepart');  Exit; End;
  If FName = 'TINV'      Then Begin BinCallLabel('_SASRT_tinv');      Exit; End;
  If FName = 'TNONCT'    Then Begin BinCallLabel('_SASRT_tnonct');    Exit; End;
  If FName = 'TRANSLATE' Then Begin BinCallLabel('_SASRT_translate'); Exit; End;
  If FName = 'TRANWRD'   Then Begin BinCallLabel('_SASRT_tranwrd');   Exit; End;
  If FName = 'TRIGAMMA'  Then Begin BinCallLabel('_SASRT_trigamma');  Exit; End;
  If FName = 'TRIMN'     Then Begin BinCallLabel('_SASRT_trimn');     Exit; End;
  If FName = 'TRUNC'     Then Begin BinCallLabel('_SASRT_trunc');     Exit; End;
  If FName = 'UNIFORM'   Then Begin BinCallLabel('_SASRT_uniform');   Exit; End;
  If FName = 'URLDECODE' Then Begin BinCallLabel('_SASRT_urldecode'); Exit; End;
  If FName = 'URLENCODE' Then Begin BinCallLabel('_SASRT_urlencode'); Exit; End;
  If FName = 'USS'       Then Begin BinCallLabel('_SASRT_uss');       Exit; End;
  If FName = 'VAR'       Then Begin BinCallLabel('_SASRT_var');       Exit; End;
  If FName = 'VARFMT'    Then Begin BinCallLabel('_SASRT_varfmt');    Exit; End;
  If FName = 'VARINFMT'  Then Begin BinCallLabel('_SASRT_varinfmt');  Exit; End;
  { Fonctions serie V (batch 13) }
  If FName = 'VARLABEL'    Then Begin BinCallLabel('_SASRT_varlabel');    Exit; End;
  If FName = 'VARLEN'      Then Begin BinCallLabel('_SASRT_varlen');      Exit; End;
  If FName = 'VARNAME'     Then Begin BinCallLabel('_SASRT_varname');     Exit; End;
  If FName = 'VARNUM'      Then Begin BinCallLabel('_SASRT_varnum');      Exit; End;
  If FName = 'VARRAY'      Then Begin BinCallLabel('_SASRT_varray');      Exit; End;
  If FName = 'VARRAYX'     Then Begin BinCallLabel('_SASRT_varrayx');     Exit; End;
  If FName = 'VARTYPE'     Then Begin BinCallLabel('_SASRT_vartype');     Exit; End;
  If FName = 'VERIFY'      Then Begin BinCallLabel('_SASRT_verify');      Exit; End;
  If FName = 'VFORMAT'     Then Begin BinCallLabel('_SASRT_vformat');     Exit; End;
  If FName = 'VFORMATD'    Then Begin BinCallLabel('_SASRT_vformatd');    Exit; End;
  If FName = 'VFORMATDX'   Then Begin BinCallLabel('_SASRT_vformatdx');   Exit; End;
  If FName = 'VFORMATN'    Then Begin BinCallLabel('_SASRT_vformatn');    Exit; End;
  If FName = 'VFORMATNX'   Then Begin BinCallLabel('_SASRT_vformatnx');   Exit; End;
  If FName = 'VFORMATW'    Then Begin BinCallLabel('_SASRT_vformatw');    Exit; End;
  If FName = 'VFORMATWX'   Then Begin BinCallLabel('_SASRT_vformatwx');   Exit; End;
  If FName = 'VFORMATX'    Then Begin BinCallLabel('_SASRT_vformatx');    Exit; End;
  If FName = 'VINARRAY'    Then Begin BinCallLabel('_SASRT_vinarray');    Exit; End;
  If FName = 'VINARRAYX'   Then Begin BinCallLabel('_SASRT_vinarrayx');   Exit; End;
  If FName = 'VINFORMAT'   Then Begin BinCallLabel('_SASRT_vinformat');   Exit; End;
  If FName = 'VINFORMATD'  Then Begin BinCallLabel('_SASRT_vinformatd');  Exit; End;
  If FName = 'VINFORMATDX' Then Begin BinCallLabel('_SASRT_vinformatdx'); Exit; End;
  If FName = 'VINFORMATN'  Then Begin BinCallLabel('_SASRT_vinformatn');  Exit; End;
  If FName = 'VINFORMATNX' Then Begin BinCallLabel('_SASRT_vinformatnx'); Exit; End;
  If FName = 'VINFORMATW'  Then Begin BinCallLabel('_SASRT_vinformatw');  Exit; End;
  If FName = 'VINFORMATWX' Then Begin BinCallLabel('_SASRT_vinformatwx'); Exit; End;
  If FName = 'VINFORMATX'  Then Begin BinCallLabel('_SASRT_vinformatx');  Exit; End;
  { Fonctions serie V-W-Y-Z (batch 14) }
  If FName = 'VLABEL'    Then Begin BinCallLabel('_SASRT_vlabel');    Exit; End;
  If FName = 'VLABELX'   Then Begin BinCallLabel('_SASRT_vlabelx');   Exit; End;
  If FName = 'VLENGTH'   Then Begin BinCallLabel('_SASRT_vlength');   Exit; End;
  If FName = 'VLENGTHX'  Then Begin BinCallLabel('_SASRT_vlengthx');  Exit; End;
  If FName = 'VNAME'     Then Begin BinCallLabel('_SASRT_vname');     Exit; End;
  If FName = 'VNAMEX'    Then Begin BinCallLabel('_SASRT_vnamex');    Exit; End;
  If FName = 'VTYPE'     Then Begin BinCallLabel('_SASRT_vtype');     Exit; End;
  If FName = 'VTYPEX'    Then Begin BinCallLabel('_SASRT_vtypex');    Exit; End;
  If FName = 'WEEKDAY'   Then Begin BinCallLabel('_SASRT_weekday');   Exit; End;
  If FName = 'YEAR'      Then Begin BinCallLabel('_SASRT_year');      Exit; End;
  If FName = 'YIELDP'    Then Begin BinCallLabel('_SASRT_yieldp');    Exit; End;
  If FName = 'YRDIF'     Then Begin BinCallLabel('_SASRT_yrdif');     Exit; End;
  If FName = 'YYQ'       Then Begin BinCallLabel('_SASRT_yyq');       Exit; End;
  If FName = 'ZIPFIPS'   Then Begin BinCallLabel('_SASRT_zipfips');   Exit; End;
  If FName = 'ZIPNAME'   Then Begin BinCallLabel('_SASRT_zipname');   Exit; End;
  If FName = 'ZIPNAMEL'  Then Begin BinCallLabel('_SASRT_zipnamel');  Exit; End;
  If FName = 'ZIPSTATE'  Then Begin BinCallLabel('_SASRT_zipstate');  Exit; End;

  CompileWarn('CodegenCall : fonction inconnue : ' + FName);
End;

{ ============================================================ }
{ TODO 24 — Runtime : fonctions chaines integrees              }
{ Convention stdcall ; les ptrs designent des buffers 256 o.  }
{ ============================================================ }
Procedure EmitRuntimeStrFunc;
Begin
  { --- _SASRT_strcpy(dst,src): dst --- 39 o stdcall ret 8            }
  { [ebp+8]=dst [ebp+12]=src ; NULL src → ecrit 0 en dst ; ok si     }
  { src est .rdata ou buffer .data ; retourne dst dans EAX.           }
  { Layout : jz null_src=+19(off13) jnz copy=-10(off23) jmp=-14(off37) }
  BinDefineLabel('_SASRT_strcpy');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                 { push esi; push edi    }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($08);  { mov edi,[ebp+8]  dst  }
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);  { mov esi,[ebp+12] src  }
  BinEmit8($85); BinEmit8($F6);                 { test esi,esi          }
  BinEmit8($74); BinEmit8($13);                 { jz null_src (+19 →34) }
  { copy_loop: offset 15 }
  BinEmit8($8A); BinEmit8($06);                 { mov al,[esi]          }
  BinEmit8($88); BinEmit8($07);                 { mov [edi],al          }
  BinEmit8($46); BinEmit8($47);                 { inc esi; inc edi      }
  BinEmit8($84); BinEmit8($C0);                 { test al,al            }
  BinEmit8($75); BinEmit8($F6);                 { jnz copy_loop (-10→15)}
  { done: offset 25 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);  { mov eax,[ebp+8]       }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi;esi;ebp       }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);  { ret 8                 }
  { null_src: offset 34 }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte [edi],0      }
  BinEmit8($EB); BinEmit8($F2);                 { jmp done (-14 →25)   }

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

  { --- _SASRT_upcase(s): ptr → copie src dans strtmp en maj, retourne strtmp }
  { Si src est .rdata (lecture seule), on ne modifie pas src.               }
  { Layout (49 o): jz _done +16(off17) jb _store +6(off21) ja _store +2(off25) }
  {                sub -22(off33) C6+B8+pops (off35)                          }
  BinDefineLabel('_SASRT_upcase');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                  { push esi; push edi    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]       }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp       }
  { _loop (offset 13): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]          }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($74); BinEmit8($10);                  { jz _done (→ off35)    }
  BinEmit8($3C); BinEmit8($61);                  { cmp al,'a'            }
  BinEmit8($72); BinEmit8($06);                  { jb _store (→ off29)   }
  BinEmit8($3C); BinEmit8($7A);                  { cmp al,'z'            }
  BinEmit8($77); BinEmit8($02);                  { ja _store (→ off29)   }
  BinEmit8($2C); BinEmit8($20);                  { sub al,0x20           }
  { _store (offset 29): }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al          }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi      }
  BinEmit8($EB); BinEmit8($EA);                  { jmp _loop (→ off13)   }
  { _done (offset 35): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte [edi],0      }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp       }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi; esi; ebp     }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                 }

  { --- _SASRT_lowcase(s): ptr → copie src dans strtmp en min, retourne strtmp }
  { Meme structure qu upcase : 'A'-'Z' → +0x20                                }
  BinDefineLabel('_SASRT_lowcase');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);
  BinMovRegLabel(7, '_sas_strtmp');
  { _loop (offset 13): }
  BinEmit8($8A); BinEmit8($06);
  BinEmit8($84); BinEmit8($C0);
  BinEmit8($74); BinEmit8($10);                  { jz _done (→ off35)    }
  BinEmit8($3C); BinEmit8($41);                  { cmp al,'A'            }
  BinEmit8($72); BinEmit8($06);                  { jb _store (→ off29)   }
  BinEmit8($3C); BinEmit8($5A);                  { cmp al,'Z'            }
  BinEmit8($77); BinEmit8($02);                  { ja _store (→ off29)   }
  BinEmit8($04); BinEmit8($20);                  { add al,0x20           }
  { _store (offset 29): }
  BinEmit8($88); BinEmit8($07);
  BinEmit8($46); BinEmit8($47);
  BinEmit8($EB); BinEmit8($EA);                  { jmp _loop (→ off13)   }
  { _done (offset 35): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);
  BinMovRegLabel(0, '_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_trim(s): ptr → copie+rogne espaces finaux dans strtmp        }
  { Une passe : copie char par char, ebx = pos apres dernier non-espace.    }
  { Layout (54 o): jz _null +10(off26) je _skip +3(off30) jmp -20(off36)   }
  BinDefineLabel('_SASRT_trim');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57); BinEmit8($53);  { push esi; edi; ebx    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]       }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp       }
  BinEmit8($31); BinEmit8($DB);                  { xor ebx,ebx           }
  BinEmit8($31); BinEmit8($C9);                  { xor ecx,ecx           }
  { _loop (offset 18): }
  BinEmit8($8A); BinEmit8($04); BinEmit8($0E);  { mov al,[esi+ecx]      }
  BinEmit8($88); BinEmit8($04); BinEmit8($0F);  { mov [edi+ecx],al      }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($74); BinEmit8($0A);                  { jz _nullterm (→ off38)}
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '            }
  BinEmit8($74); BinEmit8($03);                  { je _skip (→ off35)    }
  BinEmit8($8D); BinEmit8($59); BinEmit8($01);  { lea ebx,[ecx+1]       }
  { _skip (offset 35): }
  BinEmit8($41);                                  { inc ecx               }
  BinEmit8($EB); BinEmit8($EC);                  { jmp _loop (→ off18)   }
  { _nullterm (offset 38): }
  BinEmit8($C6); BinEmit8($04); BinEmit8($1F); BinEmit8($00); { mov [edi+ebx],0 }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp       }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);  { pop ebx; edi; esi     }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_left(s): ptr → saute espaces debut, copie reste dans strtmp  }
  { Layout (47 o): jz +7(off17) jne +3(off21) jmp -13(off24) jnz -10(off34)}
  BinDefineLabel('_SASRT_left');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                  { push esi; push edi    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]       }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp       }
  { _skip_loop (offset 13): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]          }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($74); BinEmit8($07);                  { jz _copy (→ off26)    }
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '            }
  BinEmit8($75); BinEmit8($03);                  { jne _copy (→ off26)   }
  BinEmit8($46);                                  { inc esi               }
  BinEmit8($EB); BinEmit8($F3);                  { jmp _skip_loop (→ off13) }
  { _copy (offset 26): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]          }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al          }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi      }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($75); BinEmit8($F6);                  { jnz _copy (→ off26)   }
  { _done (offset 36): }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp       }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi; esi; ebp     }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                 }

  { --- _SASRT_right(s): ptr --- deplace espaces finaux au debut dans strtmp }
  { [ebp+8]=s. EBX=nb_esp_fin, ECX=long_sig, ESI=src, EDI=dst. ret 4.     }
  BinDefineLabel('_SASRT_right');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);     { push ebx; push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);     { mov esi,[ebp+8] }
  { strlen(esi) → ecx }
  BinEmit8($31); BinEmit8($C9);                    { xor ecx,ecx }
  BinDefineLabel('_right_len');
  BinEmit8($8A); BinEmit8($04); BinEmit8($0E);    { mov al,[esi+ecx] }
  BinEmit8($84); BinEmit8($C0);                    { test al,al }
  BinJccLabel(4,'_right_tsp');                      { jz }
  BinEmit8($41);                                    { inc ecx }
  BinJmpLabel('_right_len');
  BinDefineLabel('_right_tsp');
  { Compter espaces de fin → ebx }
  BinEmit8($31); BinEmit8($DB);                    { xor ebx,ebx }
  BinDefineLabel('_right_tsp_loop');
  BinEmit8($85); BinEmit8($C9);                    { test ecx,ecx }
  BinJccLabel(4,'_right_fill');                     { jz → rien }
  BinEmit8($8A); BinEmit8($44); BinEmit8($0E); BinEmit8($FF); { mov al,[esi+ecx-1] }
  BinEmit8($3C); BinEmit8($20);                    { cmp al,' ' }
  BinJccLabel(5,'_right_fill');                     { jne → fin espaces }
  BinEmit8($43);                                    { inc ebx }
  BinEmit8($49);                                    { dec ecx }
  BinJmpLabel('_right_tsp_loop');
  BinDefineLabel('_right_fill');
  { ecx=long_sig, ebx=nb espaces. Remplir strtmp. }
  BinMovRegLabel(7,'_sas_strtmp');                  { mov edi,&strtmp }
  BinEmit8($85); BinEmit8($DB);                    { test ebx,ebx }
  BinJccLabel(4,'_right_sig');                      { jz }
  BinDefineLabel('_right_sp_loop');
  BinEmit8($C6); BinEmit8($07); BinEmit8($20);    { mov byte [edi],' ' }
  BinEmit8($47);                                    { inc edi }
  BinEmit8($4B);                                    { dec ebx }
  BinJccLabel(5,'_right_sp_loop');                 { jnz }
  BinDefineLabel('_right_sig');
  BinEmit8($85); BinEmit8($C9);                    { test ecx,ecx }
  BinJccLabel(4,'_right_done');                     { jz }
  BinDefineLabel('_right_sig_loop');
  BinEmit8($8A); BinEmit8($06);                    { mov al,[esi] }
  BinEmit8($88); BinEmit8($07);                    { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                    { inc esi; inc edi }
  BinEmit8($49);                                    { dec ecx }
  BinJccLabel(5,'_right_sig_loop');                { jnz }
  BinDefineLabel('_right_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);    { mov byte [edi],0 }
  BinMovRegLabel(0,'_sas_strtmp');                  { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);    { pop edi; pop esi; pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_substr(s,pos,len): ptr --- 69 o stdcall ret 12         }
  { [ebp+8]=s [ebp+12]=pos(1-base) [ebp+16]=len(0=fin) → strtmp     }
  { Layout : jnz copy_n=+12(off23) jnz copy_to_end=-10(off33)       }
  {          jmp done=+20(off35) jz write_nul=+13(off39)             }
  {          jz done=+10(off45) jmp copy_n=-17(off52)                }
  BinDefineLabel('_SASRT_substr');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp;mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                 { push esi; push edi   }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]  s   }
  BinEmit8($03); BinEmit8($75); BinEmit8($0C);  { add esi,[ebp+12] pos }
  BinEmit8($4E);                                { dec esi  (1-based)   }
  BinPushLabel('_sas_strtmp');                  { push strtmp ABS32    }
  BinEmit8($5F);                                { pop edi              }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);  { mov ecx,[ebp+16] len }
  { offset 21 : test ecx }
  BinEmit8($85); BinEmit8($C9);                 { test ecx,ecx         }
  BinEmit8($75); BinEmit8($0C);                 { jnz copy_n(+12→37)  }
  { copy_to_end: offset 25 }
  BinEmit8($8A); BinEmit8($06);                 { mov al,[esi]         }
  BinEmit8($88); BinEmit8($07);                 { mov [edi],al         }
  BinEmit8($46); BinEmit8($47);                 { inc esi; inc edi     }
  BinEmit8($84); BinEmit8($C0);                 { test al,al           }
  BinEmit8($75); BinEmit8($F6);                 { jnz copy_to_end(-10) }
  BinEmit8($EB); BinEmit8($14);                 { jmp done (+20 →57)  }
  { copy_n: offset 37 }
  BinEmit8($85); BinEmit8($C9);                 { test ecx,ecx         }
  BinEmit8($74); BinEmit8($0D);                 { jz write_nul(+13→54) }
  BinEmit8($8A); BinEmit8($06);                 { mov al,[esi]         }
  BinEmit8($84); BinEmit8($C0);                 { test al,al           }
  BinEmit8($74); BinEmit8($0A);                 { jz done (+10 →57)   }
  BinEmit8($88); BinEmit8($07);                 { mov [edi],al         }
  BinEmit8($46); BinEmit8($47);                 { inc esi; inc edi     }
  BinEmit8($49);                                { dec ecx              }
  BinEmit8($EB); BinEmit8($EF);                 { jmp copy_n (-17 →37) }
  { write_nul: offset 54 }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte [edi],0     }
  { done: offset 57 }
  BinPushLabel('_sas_strtmp');                  { push strtmp ABS32    }
  BinEmit8($58);                                { pop eax = strtmp ptr }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi;esi;ebp      }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);  { ret 12               }

  { --- _SASRT_index(s, sub): LongInt --- recherche sous-chaine, retourne position 1-base (57 octets) }
  { INDEX(s,sub): position 1-basee de la premiere occurrence de sub dans s, ou 0 si absente.        }
  { [ebp+8]=s, [ebp+12]=sub                                                                         }
  BinDefineLabel('_SASRT_index');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);           { push esi; push edi; push ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  s }
  BinEmit8($31); BinEmit8($C9);                          { xor ecx,ecx  offset=0 }
  { .outer (offset 11): }
  BinEmit8($8A); BinEmit8($14); BinEmit8($0E);           { mov dl,[esi+ecx] }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinEmit8($74); BinEmit8($19);                          { jz .notfound (+25 → 43) }
  BinEmit8($8B); BinEmit8($7D); BinEmit8($0C);           { mov edi,[ebp+12] sub }
  BinEmit8($89); BinEmit8($CB);                          { mov ebx,ecx }
  { .inner (offset 23): }
  BinEmit8($8A); BinEmit8($07);                          { mov al,[edi] }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinEmit8($74); BinEmit8($12);                          { jz .found (+18 → 47) }
  BinEmit8($8A); BinEmit8($24); BinEmit8($1E);           { mov ah,[esi+ebx] }
  BinEmit8($3A); BinEmit8($C4);                          { cmp al,ah }
  BinEmit8($75); BinEmit8($04);                          { jne .next (+4 → 40) }
  BinEmit8($47);                                          { inc edi }
  BinEmit8($43);                                          { inc ebx }
  BinEmit8($EB); BinEmit8($EF);                          { jmp .inner (-17 → 23) }
  { .next (offset 40): }
  BinEmit8($41);                                          { inc ecx }
  BinEmit8($EB); BinEmit8($E0);                          { jmp .outer (-32 → 11) }
  { .notfound (offset 43): }
  BinEmit8($31); BinEmit8($C0);                          { xor eax,eax }
  BinEmit8($EB); BinEmit8($03);                          { jmp .done (+3 → 50) }
  { .found (offset 47): }
  BinEmit8($8D); BinEmit8($41); BinEmit8($01);           { lea eax,[ecx+1] }
  { .done (offset 50): }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);           { pop ebx; pop edi; pop esi }
  BinEmit8($5D);                                          { pop ebp }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);           { ret 8 }

  { --- _SASRT_compress(s, c): ptr --- retire de s les chars presents dans c }
  { [ebp+8]=s, [ebp+12]=c. ESI=s, EDI=strtmp, EBX=c. 59 octets.           }
  { Offsets : _outer=17  _inner=25  _copy_char=38  _skip_char=41  _done=44 }
  BinDefineLabel('_SASRT_compress');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);           { push esi; push edi; push ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  s }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);           { mov ebx,[ebp+12] c }
  { _outer (offset 17): }
  BinEmit8($8A); BinEmit8($06);                           { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                           { test al,al }
  BinEmit8($74); BinEmit8($15);                           { jz _done (+21 → 44) }
  BinEmit8($89); BinEmit8($D9);                           { mov ecx,ebx }
  { _inner (offset 25): }
  BinEmit8($8A); BinEmit8($11);                           { mov dl,[ecx] }
  BinEmit8($84); BinEmit8($D2);                           { test dl,dl }
  BinEmit8($74); BinEmit8($07);                           { jz _copy_char (+7 → 38) }
  BinEmit8($3A); BinEmit8($C2);                           { cmp al,dl }
  BinEmit8($74); BinEmit8($06);                           { je _skip_char (+6 → 41) }
  BinEmit8($41);                                           { inc ecx }
  BinEmit8($EB); BinEmit8($F3);                           { jmp _inner (-13 → 25) }
  { _copy_char (offset 38): }
  BinEmit8($88); BinEmit8($07);                           { mov [edi],al }
  BinEmit8($47);                                           { inc edi }
  { _skip_char (offset 41): }
  BinEmit8($46);                                           { inc esi }
  BinEmit8($EB); BinEmit8($E5);                           { jmp _outer (-27 → 17) }
  { _done (offset 44): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte [edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');                       { mov eax,&strtmp }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);           { pop ebx; pop edi; pop esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00); { pop ebp; ret 8 }

  { --- _SASRT_cat(s1, s2): ptr --- concatenation s1+s2 → concat_buf (2 args) }
  BinDefineLabel('_SASRT_cat');
  BinJmpLabel('_SASRT_concat');

  { --- _SASRT_put(val,fmt): ptr → strtmp --- itoa(val), fmt ignore      }
  { [ebp+8]=val(int32) [ebp+12]=fmt. EBX=signe ESI=dst EDI=src. ret 8. }
  BinDefineLabel('_SASRT_put');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);       { push ebp; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);       { push ebx; push esi; push edi }
  BinEmit8($83); BinEmit8($EC); BinEmit8($20);       { sub esp,32 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);       { mov eax,[ebp+8] }
  BinEmit8($31); BinEmit8($DB);                      { xor ebx,ebx (signe=0) }
  BinEmit8($85); BinEmit8($C0);                      { test eax,eax }
  BinJccLabel(5,'_put_nonzero');                      { jnz }
  BinMovRegLabel(7,'_sas_strtmp');                    { mov edi,_sas_strtmp }
  BinEmit8($C6); BinEmit8($07); BinEmit8($30);      { mov byte [edi],'0' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($00);
  BinMovRegLabel(0,'_sas_strtmp');                    { mov eax,_sas_strtmp }
  BinJmpLabel('_put_epilog');
  BinDefineLabel('_put_nonzero');
  BinJccLabel(9,'_put_positive');                     { jns _put_positive }
  BinEmit8($F7); BinEmit8($D8);                      { neg eax }
  BinEmit8($BB); BinEmit32(1);                       { mov ebx,1 (negatif) }
  BinDefineLabel('_put_positive');
  { tampon local: [ebp-13]=octet nul, on ecrit vers la gauche }
  BinEmit8($8D); BinEmit8($7D); BinEmit8($F3);      { lea edi,[ebp-13] }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);      { mov byte [edi],0 (nul) }
  BinEmit8($4F);                                     { dec edi }
  BinEmit8($B9); BinEmit32(10);                      { mov ecx,10 }
  BinDefineLabel('_put_dig_loop');
  BinEmit8($31); BinEmit8($D2);                      { xor edx,edx }
  BinEmit8($F7); BinEmit8($F1);                      { div ecx (eax=q,edx=r) }
  BinEmit8($80); BinEmit8($C2); BinEmit8($30);      { add dl,'0' }
  BinEmit8($88); BinEmit8($17);                      { mov [edi],dl }
  BinEmit8($4F);                                     { dec edi }
  BinEmit8($85); BinEmit8($C0);                      { test eax,eax }
  BinJccLabel(5,'_put_dig_loop');                    { jnz }
  BinEmit8($85); BinEmit8($DB);                      { test ebx,ebx }
  BinJccLabel(4,'_put_copy');                         { jz _put_copy }
  BinEmit8($C6); BinEmit8($07); BinEmit8($2D);      { mov byte [edi],'-' }
  BinEmit8($4F);                                     { dec edi }
  BinDefineLabel('_put_copy');
  BinEmit8($47);                                     { inc edi (debut chaine) }
  BinMovRegLabel(6,'_sas_strtmp');                    { mov esi,_sas_strtmp }
  BinDefineLabel('_put_cpy_loop');
  BinEmit8($8A); BinEmit8($07);                      { mov al,[edi] }
  BinEmit8($88); BinEmit8($06);                      { mov [esi],al }
  BinEmit8($47); BinEmit8($46);                      { inc edi; inc esi }
  BinEmit8($84); BinEmit8($C0);                      { test al,al }
  BinJccLabel(5,'_put_cpy_loop');                    { jnz }
  BinMovRegLabel(0,'_sas_strtmp');                    { mov eax,_sas_strtmp }
  BinDefineLabel('_put_epilog');
  BinEmit8($83); BinEmit8($C4); BinEmit8($20);      { add esp,32 }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);      { pop edi; pop esi; pop ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_concat(src1,src2): ptr --- concat dans _sas_concat_buf    }
  { [ebp+8]=src1 [ebp+12]=src2 ; stdcall ret 8 ; EBX callee-saved       }
  { Phase 1 : strcpy(concat_buf,src1) ; Phase 2 : trouver fin ;          }
  { Phase 3 : copier src2 a partir de la fin ; EAX=concat_buf            }
  { _findend : cmp [eax],0 74 03 inc eax EB F8 (-8)                      }
  { _copy    : 8A 13 88 10 84 D2 74 04 40 43 EB F4 (-12)                 }
  BinDefineLabel('_SASRT_concat');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($53);                                    { push ebx              }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);    { mov eax,[ebp+8] src1  }
  BinEmit8($50);                                    { push src1             }
  BinPushLabel('_sas_concat_buf');                 { push concat_buf       }
  BinCallLabel('_SASRT_strcpy');                   { strcpy(buf,src1)      }
  BinPushLabel('_sas_concat_buf');                 { push concat_buf       }
  BinEmit8($58);                                    { pop eax               }
  { _findend: }
  BinEmit8($80); BinEmit8($38); BinEmit8($00);    { cmp byte [eax],0      }
  BinEmit8($74); BinEmit8($03);                    { jz +3 → apres inc+jmp }
  BinEmit8($40);                                    { inc eax               }
  BinEmit8($EB); BinEmit8($F8);                    { jmp _findend (-8)     }
  { _found_end: eax = adresse du \0 dans concat_buf }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);    { mov ebx,[ebp+12] src2 }
  { _copy: }
  BinEmit8($8A); BinEmit8($13);                    { mov dl,[ebx]          }
  BinEmit8($88); BinEmit8($10);                    { mov [eax],dl          }
  BinEmit8($84); BinEmit8($D2);                    { test dl,dl            }
  BinEmit8($74); BinEmit8($04);                    { jz +4 → _done         }
  BinEmit8($40);                                    { inc eax               }
  BinEmit8($43);                                    { inc ebx               }
  BinEmit8($EB); BinEmit8($F4);                    { jmp _copy (-12)       }
  { _done: }
  BinPushLabel('_sas_concat_buf');
  BinEmit8($58);                                    { pop eax = concat_buf  }
  BinEmit8($5B);                                    { pop ebx               }
  BinEmit8($5D);                                    { pop ebp               }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);    { ret 8                 }

  { --- _SASRT_strcmp(s1,s2): LongInt --- 0 si egal, <>0 sinon           }
  { [ebp+8]=s1 [ebp+12]=s2 ; stdcall ret 8 ; EBX=s1 ECX=s2             }
  { _cmp_loop offsets : jnz+8(→16) jz+17(→29) inc inc jmp-16           }
  { _cmp_diff (16) : movzx eax,al movzx edx,dl sub eax,edx pop ret      }
  { _cmp_equal(29) : xor eax,eax pop ret                                 }
  BinDefineLabel('_SASRT_strcmp');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($53);                                    { push ebx              }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($08);    { mov ebx,[ebp+8]  s1   }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);    { mov ecx,[ebp+12] s2   }
  { _cmp_loop: }
  BinEmit8($8A); BinEmit8($03);                    { mov al,[ebx]          }
  BinEmit8($8A); BinEmit8($11);                    { mov dl,[ecx]          }
  BinEmit8($38); BinEmit8($D0);                    { cmp al,dl             }
  BinEmit8($75); BinEmit8($08);                    { jnz +8 → _cmp_diff   }
  BinEmit8($84); BinEmit8($C0);                    { test al,al            }
  BinEmit8($74); BinEmit8($11);                    { jz +17 → _cmp_equal  }
  BinEmit8($43);                                    { inc ebx               }
  BinEmit8($41);                                    { inc ecx               }
  BinEmit8($EB); BinEmit8($F0);                    { jmp _cmp_loop (-16)   }
  { _cmp_diff: (offset 16 depuis debut loop) }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($C0);    { movzx eax,al          }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($D2);    { movzx edx,dl          }
  BinEmit8($29); BinEmit8($D0);                    { sub eax,edx           }
  BinEmit8($5B); BinEmit8($5D);                    { pop ebx; pop ebp      }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);    { ret 8                 }
  { _cmp_equal: (offset 29 depuis debut loop) }
  BinEmit8($31); BinEmit8($C0);                    { xor eax,eax           }
  BinEmit8($5B); BinEmit8($5D);                    { pop ebx; pop ebp      }
  BinEmit8($C2); BinEmit8($08); BinEmit8($00);    { ret 8                 }

  { --- _SASRT_compbl(src): ptr --- compresse espaces multiples            }
  { Copie src dans _sas_compbl_buf en remplacant tout run d espaces        }
  { consecutifs par un seul espace ; retourne ptr sur _sas_compbl_buf.     }
  { ESI=src EDI=dst DL=prev_was_space                                      }
  { Offsets des sauts : jz _end=74 17 ; jne _notspace=75 0B ;             }
  { jnz _skip=75 0C ; jmp _skip=EB 05 ; jmp _copy=EB E3                  }
  BinDefineLabel('_SASRT_compbl');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);    { push ebp; mov ebp,esp }
  BinEmit8($56);                                    { push esi              }
  BinEmit8($57);                                    { push edi              }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);    { mov esi,[ebp+8]  src  }
  BinMovRegLabel(7, '_sas_compbl_buf');            { mov edi, buf addr     }
  BinEmit8($30); BinEmit8($D2);                    { xor dl,dl (prev=0)   }
  { _copy: offset 15 }
  BinEmit8($8A); BinEmit8($06);                    { mov al,[esi]          }
  BinEmit8($84); BinEmit8($C0);                    { test al,al            }
  BinEmit8($74); BinEmit8($17);                    { jz _end (+23→44)      }
  BinEmit8($3C); BinEmit8($20);                    { cmp al,' '            }
  BinEmit8($75); BinEmit8($0B);                    { jne _notspace (+11→36)}
  BinEmit8($84); BinEmit8($D2);                    { test dl,dl            }
  BinEmit8($75); BinEmit8($0C);                    { jnz _skip (+12→41)    }
  BinEmit8($B2); BinEmit8($01);                    { mov dl,1              }
  BinEmit8($88); BinEmit8($07);                    { mov [edi],al          }
  BinEmit8($47);                                    { inc edi               }
  BinEmit8($EB); BinEmit8($05);                    { jmp _skip (+5→41)     }
  { _notspace: offset 36 }
  BinEmit8($30); BinEmit8($D2);                    { xor dl,dl             }
  BinEmit8($88); BinEmit8($07);                    { mov [edi],al          }
  BinEmit8($47);                                    { inc edi               }
  { _skip: offset 41 }
  BinEmit8($46);                                    { inc esi               }
  BinEmit8($EB); BinEmit8($E3);                    { jmp _copy (-29→15)    }
  { _end: offset 44 }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);    { mov byte[edi],0       }
  BinPushLabel('_sas_compbl_buf');                 { push buf addr         }
  BinEmit8($58);                                    { pop eax               }
  BinEmit8($5F); BinEmit8($5E);                    { pop edi; pop esi      }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00); { ret 4   }

  { --- _SASRT_collate(start,end): ptr --- string of ASCII chars [start..end] }
  BinDefineLabel('_SASRT_collate');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($57);                                          { push edi }
  BinMovRegLabel(7,'_sas_strtmp');                        { mov edi,&strtmp }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($0C);           { mov ecx,[ebp+12] end }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8]  start }
  BinEmit8($39); BinEmit8($C1);                           { cmp ecx,eax }
  BinEmit8($7C); BinEmit8($09);                           { jl +9 → done (end<start) }
  BinEmit8($29); BinEmit8($C1);                           { sub ecx,eax → count-1 }
  BinEmit8($41);                                          { inc ecx → count }
  BinEmit8($88); BinEmit8($07);                           { _loop: mov [edi],al }
  BinEmit8($47);                                          { inc edi }
  BinEmit8($40);                                          { inc eax }
  BinEmit8($E2); BinEmit8($FA);                           { loop _loop (-6) }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { _done: mov byte[edi],0 }
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F);                                          { pop edi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_dequote(src): ptr --- retire une paire de guillemets externes }
  BinDefineLabel('_SASRT_dequote');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);          { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);          { push esi; edi; ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);          { mov esi,[ebp+8] src }
  BinMovRegLabel(7, '_sas_strtmp');                     { mov edi,_sas_strtmp }
  BinEmit8($85); BinEmit8($F6);                         { test esi,esi }
  BinJccLabel(4, '_dequote_empty');                     { jz empty }
  BinEmit8($8A); BinEmit8($06);                         { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                         { test al,al }
  BinJccLabel(4, '_dequote_empty');                     { jz empty }
  BinEmit8($3C); BinEmit8($22);                         { cmp al,'"' }
  BinJccLabel(4, '_dequote_quoted');                    { je quoted }
  BinEmit8($3C); BinEmit8($27);                         { cmp al,'''' }
  BinJccLabel(5, '_dequote_copy_all');                  { jne copy_all }
  BinDefineLabel('_dequote_quoted');
  BinEmit8($88); BinEmit8($C2);                         { mov dl,al quote }
  BinEmit8($89); BinEmit8($F3);                         { mov ebx,esi scan }
  BinDefineLabel('_dequote_scan_end');
  BinEmit8($80); BinEmit8($3B); BinEmit8($00);          { cmp byte [ebx],0 }
  BinJccLabel(4, '_dequote_found_end');                 { je found }
  BinEmit8($43);                                        { inc ebx }
  BinJmpLabel('_dequote_scan_end');
  BinDefineLabel('_dequote_found_end');
  BinEmit8($4B);                                        { dec ebx -> dernier char }
  BinEmit8($39); BinEmit8($F3);                         { cmp ebx,esi }
  BinJccLabel(14, '_dequote_copy_all');                 { jle copy_all }
  BinEmit8($38); BinEmit8($13);                         { cmp [ebx],dl }
  BinJccLabel(5, '_dequote_copy_all');                  { jne copy_all }
  BinEmit8($46);                                        { inc esi -> apres quote }
  BinDefineLabel('_dequote_strip_loop');
  BinEmit8($39); BinEmit8($F3);                         { cmp ebx,esi }
  BinJccLabel(14, '_dequote_done');                     { jle done }
  BinEmit8($8A); BinEmit8($06);                         { mov al,[esi] }
  BinEmit8($88); BinEmit8($07);                         { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                         { inc esi; inc edi }
  BinJmpLabel('_dequote_strip_loop');
  BinDefineLabel('_dequote_copy_all');
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);          { mov esi,[ebp+8] src }
  BinDefineLabel('_dequote_copy_loop');
  BinEmit8($8A); BinEmit8($06);                         { mov al,[esi] }
  BinEmit8($88); BinEmit8($07);                         { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                         { inc esi; inc edi }
  BinEmit8($84); BinEmit8($C0);                         { test al,al }
  BinJccLabel(5, '_dequote_copy_loop');                 { jnz copy_loop }
  BinJmpLabel('_dequote_return');
  BinDefineLabel('_dequote_empty');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);          { mov byte [edi],0 }
  BinJmpLabel('_dequote_return');
  BinDefineLabel('_dequote_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);          { null-terminate }
  BinDefineLabel('_dequote_return');
  BinMovRegLabel(0, '_sas_strtmp');                     { mov eax,_sas_strtmp }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);          { pop ebx; edi; esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_dsname(dsid): ptr --- retourne "" (1 arg) }
  BinDefineLabel('_SASRT_dsname');
  BinJmpLabel('_sas_retempty1');

  { --- _SASRT_dinfo(did,info): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_dinfo');
  BinJmpLabel('_sas_retempty2');

  { --- _SASRT_doptname(did,n): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_doptname');
  BinJmpLabel('_sas_retempty2');

  { --- _SASRT_dread(did,n): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_dread');
  BinJmpLabel('_sas_retempty2');

  { --- _SASRT_finfo(fid,item): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_finfo');
  BinJmpLabel('_sas_retempty2');

  { === FIPSTATE: table FIPS 57 entrees x 2 octets === }
  BinJmpLabel('_fipstate_after_table');
  BinDefineLabel('_fipstate_table');
  BinEmit8($00); BinEmit8($00); { 0: invalide }
  BinEmit8($41); BinEmit8($4C); { 1: AL }
  BinEmit8($41); BinEmit8($4B); { 2: AK }
  BinEmit8($00); BinEmit8($00); { 3: gap }
  BinEmit8($41); BinEmit8($5A); { 4: AZ }
  BinEmit8($41); BinEmit8($52); { 5: AR }
  BinEmit8($43); BinEmit8($41); { 6: CA }
  BinEmit8($00); BinEmit8($00); { 7: gap }
  BinEmit8($43); BinEmit8($4F); { 8: CO }
  BinEmit8($43); BinEmit8($54); { 9: CT }
  BinEmit8($44); BinEmit8($45); { 10: DE }
  BinEmit8($44); BinEmit8($43); { 11: DC }
  BinEmit8($46); BinEmit8($4C); { 12: FL }
  BinEmit8($47); BinEmit8($41); { 13: GA }
  BinEmit8($00); BinEmit8($00); { 14: gap }
  BinEmit8($48); BinEmit8($49); { 15: HI }
  BinEmit8($49); BinEmit8($44); { 16: ID }
  BinEmit8($49); BinEmit8($4C); { 17: IL }
  BinEmit8($49); BinEmit8($4E); { 18: IN }
  BinEmit8($49); BinEmit8($41); { 19: IA }
  BinEmit8($4B); BinEmit8($53); { 20: KS }
  BinEmit8($4B); BinEmit8($59); { 21: KY }
  BinEmit8($4C); BinEmit8($41); { 22: LA }
  BinEmit8($4D); BinEmit8($45); { 23: ME }
  BinEmit8($4D); BinEmit8($44); { 24: MD }
  BinEmit8($4D); BinEmit8($41); { 25: MA }
  BinEmit8($4D); BinEmit8($49); { 26: MI }
  BinEmit8($4D); BinEmit8($4E); { 27: MN }
  BinEmit8($4D); BinEmit8($53); { 28: MS }
  BinEmit8($4D); BinEmit8($4F); { 29: MO }
  BinEmit8($4D); BinEmit8($54); { 30: MT }
  BinEmit8($4E); BinEmit8($45); { 31: NE }
  BinEmit8($4E); BinEmit8($56); { 32: NV }
  BinEmit8($4E); BinEmit8($48); { 33: NH }
  BinEmit8($4E); BinEmit8($4A); { 34: NJ }
  BinEmit8($4E); BinEmit8($4D); { 35: NM }
  BinEmit8($4E); BinEmit8($59); { 36: NY }
  BinEmit8($4E); BinEmit8($43); { 37: NC }
  BinEmit8($4E); BinEmit8($44); { 38: ND }
  BinEmit8($4F); BinEmit8($48); { 39: OH }
  BinEmit8($4F); BinEmit8($4B); { 40: OK }
  BinEmit8($4F); BinEmit8($52); { 41: OR }
  BinEmit8($50); BinEmit8($41); { 42: PA }
  BinEmit8($00); BinEmit8($00); { 43: gap }
  BinEmit8($52); BinEmit8($49); { 44: RI }
  BinEmit8($53); BinEmit8($43); { 45: SC }
  BinEmit8($53); BinEmit8($44); { 46: SD }
  BinEmit8($54); BinEmit8($4E); { 47: TN }
  BinEmit8($54); BinEmit8($58); { 48: TX }
  BinEmit8($55); BinEmit8($54); { 49: UT }
  BinEmit8($56); BinEmit8($54); { 50: VT }
  BinEmit8($56); BinEmit8($41); { 51: VA }
  BinEmit8($00); BinEmit8($00); { 52: gap }
  BinEmit8($57); BinEmit8($41); { 53: WA }
  BinEmit8($57); BinEmit8($56); { 54: WV }
  BinEmit8($57); BinEmit8($49); { 55: WI }
  BinEmit8($57); BinEmit8($59); { 56: WY }
  BinDefineLabel('_fipstate_after_table');

  { --- _SASRT_fipstate(code): ptr --- code FIPS → abreviation 2 lettres }
  BinDefineLabel('_SASRT_fipstate');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($57);                                          { push edi }
  BinMovRegLabel(7,'_sas_strtmp');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14,'_fs_empty');                            { jle → vide }
  BinEmit8($83); BinEmit8($F8); BinEmit8($38);           { cmp eax,56 }
  BinJccLabel(15,'_fs_empty');                            { jg → vide }
  BinEmit8($01); BinEmit8($C0);                          { add eax,eax }
  BinMovRegLabel(2,'_fipstate_table');                    { mov edx,&table }
  BinEmit8($03); BinEmit8($D0);                          { add edx,eax }
  BinEmit8($8A); BinEmit8($02);                          { mov al,[edx] }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinJccLabel(4,'_fs_empty');                             { jz gap → vide }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($8A); BinEmit8($42); BinEmit8($01);           { mov al,[edx+1] }
  BinEmit8($88); BinEmit8($47); BinEmit8($01);           { mov [edi+1],al }
  BinEmit8($C6); BinEmit8($47); BinEmit8($02); BinEmit8($00); { mov [edi+2],0 }
  BinJmpLabel('_fs_done');
  BinDefineLabel('_fs_empty');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov [edi],0 }
  BinDefineLabel('_fs_done');
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { === FIPNAME: table d'offsets (57x2) + pool de chaines (499 octets) === }
  BinJmpLabel('_fipname_data_end');
  BinDefineLabel('_fipname_offsets');
  { offsets 16-bit LE pour codes 0-56 dans le pool de chaines }
  BinEmit8($00); BinEmit8($00); { 0: vide à offset 0 }
  BinEmit8($01); BinEmit8($00); { 1: Alabama à 1 }
  BinEmit8($09); BinEmit8($00); { 2: Alaska à 9 }
  BinEmit8($10); BinEmit8($00); { 3: gap à 16 }
  BinEmit8($11); BinEmit8($00); { 4: Arizona à 17 }
  BinEmit8($19); BinEmit8($00); { 5: Arkansas à 25 }
  BinEmit8($22); BinEmit8($00); { 6: California à 34 }
  BinEmit8($2D); BinEmit8($00); { 7: gap à 45 }
  BinEmit8($2E); BinEmit8($00); { 8: Colorado à 46 }
  BinEmit8($37); BinEmit8($00); { 9: Connecticut à 55 }
  BinEmit8($43); BinEmit8($00); { 10: Delaware à 67 }
  BinEmit8($4C); BinEmit8($00); { 11: DC à 76 }
  BinEmit8($61); BinEmit8($00); { 12: Florida à 97 }
  BinEmit8($69); BinEmit8($00); { 13: Georgia à 105 }
  BinEmit8($71); BinEmit8($00); { 14: gap à 113 }
  BinEmit8($72); BinEmit8($00); { 15: Hawaii à 114 }
  BinEmit8($79); BinEmit8($00); { 16: Idaho à 121 }
  BinEmit8($7F); BinEmit8($00); { 17: Illinois à 127 }
  BinEmit8($88); BinEmit8($00); { 18: Indiana à 136 }
  BinEmit8($90); BinEmit8($00); { 19: Iowa à 144 }
  BinEmit8($95); BinEmit8($00); { 20: Kansas à 149 }
  BinEmit8($9C); BinEmit8($00); { 21: Kentucky à 156 }
  BinEmit8($A5); BinEmit8($00); { 22: Louisiana à 165 }
  BinEmit8($AF); BinEmit8($00); { 23: Maine à 175 }
  BinEmit8($B5); BinEmit8($00); { 24: Maryland à 181 }
  BinEmit8($BE); BinEmit8($00); { 25: Massachusetts à 190 }
  BinEmit8($CC); BinEmit8($00); { 26: Michigan à 204 }
  BinEmit8($D5); BinEmit8($00); { 27: Minnesota à 213 }
  BinEmit8($DF); BinEmit8($00); { 28: Mississippi à 223 }
  BinEmit8($EB); BinEmit8($00); { 29: Missouri à 235 }
  BinEmit8($F4); BinEmit8($00); { 30: Montana à 244 }
  BinEmit8($FC); BinEmit8($00); { 31: Nebraska à 252 }
  BinEmit8($05); BinEmit8($01); { 32: Nevada à 261 }
  BinEmit8($0C); BinEmit8($01); { 33: New Hampshire à 268 }
  BinEmit8($1A); BinEmit8($01); { 34: New Jersey à 282 }
  BinEmit8($25); BinEmit8($01); { 35: New Mexico à 293 }
  BinEmit8($30); BinEmit8($01); { 36: New York à 304 }
  BinEmit8($39); BinEmit8($01); { 37: North Carolina à 313 }
  BinEmit8($48); BinEmit8($01); { 38: North Dakota à 328 }
  BinEmit8($55); BinEmit8($01); { 39: Ohio à 341 }
  BinEmit8($5A); BinEmit8($01); { 40: Oklahoma à 346 }
  BinEmit8($63); BinEmit8($01); { 41: Oregon à 355 }
  BinEmit8($6A); BinEmit8($01); { 42: Pennsylvania à 362 }
  BinEmit8($77); BinEmit8($01); { 43: gap à 375 }
  BinEmit8($78); BinEmit8($01); { 44: Rhode Island à 376 }
  BinEmit8($85); BinEmit8($01); { 45: South Carolina à 389 }
  BinEmit8($94); BinEmit8($01); { 46: South Dakota à 404 }
  BinEmit8($A1); BinEmit8($01); { 47: Tennessee à 417 }
  BinEmit8($AB); BinEmit8($01); { 48: Texas à 427 }
  BinEmit8($B1); BinEmit8($01); { 49: Utah à 433 }
  BinEmit8($B6); BinEmit8($01); { 50: Vermont à 438 }
  BinEmit8($BE); BinEmit8($01); { 51: Virginia à 446 }
  BinEmit8($C7); BinEmit8($01); { 52: gap à 455 }
  BinEmit8($C8); BinEmit8($01); { 53: Washington à 456 }
  BinEmit8($D3); BinEmit8($01); { 54: West Virginia à 467 }
  BinEmit8($E1); BinEmit8($01); { 55: Wisconsin à 481 }
  BinEmit8($EB); BinEmit8($01); { 56: Wyoming à 491 }
  BinDefineLabel('_fipname_strings');
  BinEmit8($00); { offset 0: vide }
  { offset 1: Alabama }
  BinEmit8($41); BinEmit8($6C); BinEmit8($61); BinEmit8($62); BinEmit8($61); BinEmit8($6D); BinEmit8($61); BinEmit8($00);
  { offset 9: Alaska }
  BinEmit8($41); BinEmit8($6C); BinEmit8($61); BinEmit8($73); BinEmit8($6B); BinEmit8($61); BinEmit8($00);
  BinEmit8($00); { offset 16: vide (code 3) }
  { offset 17: Arizona }
  BinEmit8($41); BinEmit8($72); BinEmit8($69); BinEmit8($7A); BinEmit8($6F); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 25: Arkansas }
  BinEmit8($41); BinEmit8($72); BinEmit8($6B); BinEmit8($61); BinEmit8($6E); BinEmit8($73); BinEmit8($61); BinEmit8($73); BinEmit8($00);
  { offset 34: California }
  BinEmit8($43); BinEmit8($61); BinEmit8($6C); BinEmit8($69); BinEmit8($66); BinEmit8($6F); BinEmit8($72); BinEmit8($6E); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  BinEmit8($00); { offset 45: vide (code 7) }
  { offset 46: Colorado }
  BinEmit8($43); BinEmit8($6F); BinEmit8($6C); BinEmit8($6F); BinEmit8($72); BinEmit8($61); BinEmit8($64); BinEmit8($6F); BinEmit8($00);
  { offset 55: Connecticut }
  BinEmit8($43); BinEmit8($6F); BinEmit8($6E); BinEmit8($6E); BinEmit8($65); BinEmit8($63); BinEmit8($74); BinEmit8($69); BinEmit8($63); BinEmit8($75); BinEmit8($74); BinEmit8($00);
  { offset 67: Delaware }
  BinEmit8($44); BinEmit8($65); BinEmit8($6C); BinEmit8($61); BinEmit8($77); BinEmit8($61); BinEmit8($72); BinEmit8($65); BinEmit8($00);
  { offset 76: District of Columbia }
  BinEmit8($44); BinEmit8($69); BinEmit8($73); BinEmit8($74); BinEmit8($72); BinEmit8($69); BinEmit8($63); BinEmit8($74);
  BinEmit8($20); BinEmit8($6F); BinEmit8($66); BinEmit8($20);
  BinEmit8($43); BinEmit8($6F); BinEmit8($6C); BinEmit8($75); BinEmit8($6D); BinEmit8($62); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  { offset 97: Florida }
  BinEmit8($46); BinEmit8($6C); BinEmit8($6F); BinEmit8($72); BinEmit8($69); BinEmit8($64); BinEmit8($61); BinEmit8($00);
  { offset 105: Georgia }
  BinEmit8($47); BinEmit8($65); BinEmit8($6F); BinEmit8($72); BinEmit8($67); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  BinEmit8($00); { offset 113: vide (code 14) }
  { offset 114: Hawaii }
  BinEmit8($48); BinEmit8($61); BinEmit8($77); BinEmit8($61); BinEmit8($69); BinEmit8($69); BinEmit8($00);
  { offset 121: Idaho }
  BinEmit8($49); BinEmit8($64); BinEmit8($61); BinEmit8($68); BinEmit8($6F); BinEmit8($00);
  { offset 127: Illinois }
  BinEmit8($49); BinEmit8($6C); BinEmit8($6C); BinEmit8($69); BinEmit8($6E); BinEmit8($6F); BinEmit8($69); BinEmit8($73); BinEmit8($00);
  { offset 136: Indiana }
  BinEmit8($49); BinEmit8($6E); BinEmit8($64); BinEmit8($69); BinEmit8($61); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 144: Iowa }
  BinEmit8($49); BinEmit8($6F); BinEmit8($77); BinEmit8($61); BinEmit8($00);
  { offset 149: Kansas }
  BinEmit8($4B); BinEmit8($61); BinEmit8($6E); BinEmit8($73); BinEmit8($61); BinEmit8($73); BinEmit8($00);
  { offset 156: Kentucky }
  BinEmit8($4B); BinEmit8($65); BinEmit8($6E); BinEmit8($74); BinEmit8($75); BinEmit8($63); BinEmit8($6B); BinEmit8($79); BinEmit8($00);
  { offset 165: Louisiana }
  BinEmit8($4C); BinEmit8($6F); BinEmit8($75); BinEmit8($69); BinEmit8($73); BinEmit8($69); BinEmit8($61); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 175: Maine }
  BinEmit8($4D); BinEmit8($61); BinEmit8($69); BinEmit8($6E); BinEmit8($65); BinEmit8($00);
  { offset 181: Maryland }
  BinEmit8($4D); BinEmit8($61); BinEmit8($72); BinEmit8($79); BinEmit8($6C); BinEmit8($61); BinEmit8($6E); BinEmit8($64); BinEmit8($00);
  { offset 190: Massachusetts }
  BinEmit8($4D); BinEmit8($61); BinEmit8($73); BinEmit8($73); BinEmit8($61); BinEmit8($63); BinEmit8($68); BinEmit8($75); BinEmit8($73); BinEmit8($65); BinEmit8($74); BinEmit8($74); BinEmit8($73); BinEmit8($00);
  { offset 204: Michigan }
  BinEmit8($4D); BinEmit8($69); BinEmit8($63); BinEmit8($68); BinEmit8($69); BinEmit8($67); BinEmit8($61); BinEmit8($6E); BinEmit8($00);
  { offset 213: Minnesota }
  BinEmit8($4D); BinEmit8($69); BinEmit8($6E); BinEmit8($6E); BinEmit8($65); BinEmit8($73); BinEmit8($6F); BinEmit8($74); BinEmit8($61); BinEmit8($00);
  { offset 223: Mississippi }
  BinEmit8($4D); BinEmit8($69); BinEmit8($73); BinEmit8($73); BinEmit8($69); BinEmit8($73); BinEmit8($73); BinEmit8($69); BinEmit8($70); BinEmit8($70); BinEmit8($69); BinEmit8($00);
  { offset 235: Missouri }
  BinEmit8($4D); BinEmit8($69); BinEmit8($73); BinEmit8($73); BinEmit8($6F); BinEmit8($75); BinEmit8($72); BinEmit8($69); BinEmit8($00);
  { offset 244: Montana }
  BinEmit8($4D); BinEmit8($6F); BinEmit8($6E); BinEmit8($74); BinEmit8($61); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 252: Nebraska }
  BinEmit8($4E); BinEmit8($65); BinEmit8($62); BinEmit8($72); BinEmit8($61); BinEmit8($73); BinEmit8($6B); BinEmit8($61); BinEmit8($00);
  { offset 261: Nevada }
  BinEmit8($4E); BinEmit8($65); BinEmit8($76); BinEmit8($61); BinEmit8($64); BinEmit8($61); BinEmit8($00);
  { offset 268: New Hampshire }
  BinEmit8($4E); BinEmit8($65); BinEmit8($77); BinEmit8($20); BinEmit8($48); BinEmit8($61); BinEmit8($6D); BinEmit8($70); BinEmit8($73); BinEmit8($68); BinEmit8($69); BinEmit8($72); BinEmit8($65); BinEmit8($00);
  { offset 282: New Jersey }
  BinEmit8($4E); BinEmit8($65); BinEmit8($77); BinEmit8($20); BinEmit8($4A); BinEmit8($65); BinEmit8($72); BinEmit8($73); BinEmit8($65); BinEmit8($79); BinEmit8($00);
  { offset 293: New Mexico }
  BinEmit8($4E); BinEmit8($65); BinEmit8($77); BinEmit8($20); BinEmit8($4D); BinEmit8($65); BinEmit8($78); BinEmit8($69); BinEmit8($63); BinEmit8($6F); BinEmit8($00);
  { offset 304: New York }
  BinEmit8($4E); BinEmit8($65); BinEmit8($77); BinEmit8($20); BinEmit8($59); BinEmit8($6F); BinEmit8($72); BinEmit8($6B); BinEmit8($00);
  { offset 313: North Carolina }
  BinEmit8($4E); BinEmit8($6F); BinEmit8($72); BinEmit8($74); BinEmit8($68); BinEmit8($20); BinEmit8($43); BinEmit8($61); BinEmit8($72); BinEmit8($6F); BinEmit8($6C); BinEmit8($69); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 328: North Dakota }
  BinEmit8($4E); BinEmit8($6F); BinEmit8($72); BinEmit8($74); BinEmit8($68); BinEmit8($20); BinEmit8($44); BinEmit8($61); BinEmit8($6B); BinEmit8($6F); BinEmit8($74); BinEmit8($61); BinEmit8($00);
  { offset 341: Ohio }
  BinEmit8($4F); BinEmit8($68); BinEmit8($69); BinEmit8($6F); BinEmit8($00);
  { offset 346: Oklahoma }
  BinEmit8($4F); BinEmit8($6B); BinEmit8($6C); BinEmit8($61); BinEmit8($68); BinEmit8($6F); BinEmit8($6D); BinEmit8($61); BinEmit8($00);
  { offset 355: Oregon }
  BinEmit8($4F); BinEmit8($72); BinEmit8($65); BinEmit8($67); BinEmit8($6F); BinEmit8($6E); BinEmit8($00);
  { offset 362: Pennsylvania }
  BinEmit8($50); BinEmit8($65); BinEmit8($6E); BinEmit8($6E); BinEmit8($73); BinEmit8($79); BinEmit8($6C); BinEmit8($76); BinEmit8($61); BinEmit8($6E); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  BinEmit8($00); { offset 375: vide (code 43) }
  { offset 376: Rhode Island }
  BinEmit8($52); BinEmit8($68); BinEmit8($6F); BinEmit8($64); BinEmit8($65); BinEmit8($20); BinEmit8($49); BinEmit8($73); BinEmit8($6C); BinEmit8($61); BinEmit8($6E); BinEmit8($64); BinEmit8($00);
  { offset 389: South Carolina }
  BinEmit8($53); BinEmit8($6F); BinEmit8($75); BinEmit8($74); BinEmit8($68); BinEmit8($20); BinEmit8($43); BinEmit8($61); BinEmit8($72); BinEmit8($6F); BinEmit8($6C); BinEmit8($69); BinEmit8($6E); BinEmit8($61); BinEmit8($00);
  { offset 404: South Dakota }
  BinEmit8($53); BinEmit8($6F); BinEmit8($75); BinEmit8($74); BinEmit8($68); BinEmit8($20); BinEmit8($44); BinEmit8($61); BinEmit8($6B); BinEmit8($6F); BinEmit8($74); BinEmit8($61); BinEmit8($00);
  { offset 417: Tennessee }
  BinEmit8($54); BinEmit8($65); BinEmit8($6E); BinEmit8($6E); BinEmit8($65); BinEmit8($73); BinEmit8($73); BinEmit8($65); BinEmit8($65); BinEmit8($00);
  { offset 427: Texas }
  BinEmit8($54); BinEmit8($65); BinEmit8($78); BinEmit8($61); BinEmit8($73); BinEmit8($00);
  { offset 433: Utah }
  BinEmit8($55); BinEmit8($74); BinEmit8($61); BinEmit8($68); BinEmit8($00);
  { offset 438: Vermont }
  BinEmit8($56); BinEmit8($65); BinEmit8($72); BinEmit8($6D); BinEmit8($6F); BinEmit8($6E); BinEmit8($74); BinEmit8($00);
  { offset 446: Virginia }
  BinEmit8($56); BinEmit8($69); BinEmit8($72); BinEmit8($67); BinEmit8($69); BinEmit8($6E); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  BinEmit8($00); { offset 455: vide (code 52) }
  { offset 456: Washington }
  BinEmit8($57); BinEmit8($61); BinEmit8($73); BinEmit8($68); BinEmit8($69); BinEmit8($6E); BinEmit8($67); BinEmit8($74); BinEmit8($6F); BinEmit8($6E); BinEmit8($00);
  { offset 467: West Virginia }
  BinEmit8($57); BinEmit8($65); BinEmit8($73); BinEmit8($74); BinEmit8($20); BinEmit8($56); BinEmit8($69); BinEmit8($72); BinEmit8($67); BinEmit8($69); BinEmit8($6E); BinEmit8($69); BinEmit8($61); BinEmit8($00);
  { offset 481: Wisconsin }
  BinEmit8($57); BinEmit8($69); BinEmit8($73); BinEmit8($63); BinEmit8($6F); BinEmit8($6E); BinEmit8($73); BinEmit8($69); BinEmit8($6E); BinEmit8($00);
  { offset 491: Wyoming }
  BinEmit8($57); BinEmit8($79); BinEmit8($6F); BinEmit8($6D); BinEmit8($69); BinEmit8($6E); BinEmit8($67); BinEmit8($00);
  BinDefineLabel('_fipname_data_end');

  { --- _SASRT_fipname(code): ptr --- code FIPS → nom complet d'etat }
  BinDefineLabel('_SASRT_fipname');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($57);                                          { push edi }
  BinMovRegLabel(7,'_sas_strtmp');
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);           { mov eax,[ebp+8] }
  BinEmit8($85); BinEmit8($C0);                          { test eax,eax }
  BinJccLabel(14,'_fn_empty');                            { jle → vide }
  BinEmit8($83); BinEmit8($F8); BinEmit8($38);           { cmp eax,56 }
  BinJccLabel(15,'_fn_empty');                            { jg → vide }
  BinEmit8($01); BinEmit8($C0);                          { add eax,eax (*2) }
  BinMovRegLabel(2,'_fipname_offsets');                   { mov edx,&offsets }
  BinEmit8($03); BinEmit8($D0);                          { add edx,eax }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($02);           { movzx eax,word[edx] }
  BinMovRegLabel(2,'_fipname_strings');                   { mov edx,&strings }
  BinEmit8($03); BinEmit8($D0);                          { add edx,eax }
  BinDefineLabel('_fn_copy');
  BinEmit8($8A); BinEmit8($02);                          { mov al,[edx] }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinJccLabel(4,'_fn_done');
  BinEmit8($42); BinEmit8($47);                          { inc edx, inc edi }
  BinJmpLabel('_fn_copy');
  BinDefineLabel('_fn_empty');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov [edi],0 }
  BinDefineLabel('_fn_done');
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_fipnamel(code): ptr --- alias de fipname }
  BinDefineLabel('_SASRT_fipnamel');
  BinJmpLabel('_SASRT_fipname');

  { --- _SASRT_foptname(fid,n): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_foptname');
  BinJmpLabel('_sas_retempty2');

  { --- _SASRT_getoption(optname): ptr --- retourne "" (1 arg) }
  BinDefineLabel('_SASRT_getoption');
  BinJmpLabel('_sas_retempty1');

  { --- _SASRT_getvarc(dsid,varnum): ptr --- retourne "" (2 args) }
  BinDefineLabel('_SASRT_getvarc');
  BinJmpLabel('_sas_retempty2');

  { --- _SASRT_htmldecode(str): ptr --- decode &amp; &lt; &gt; &quot; (insensible casse) }
  BinDefineLabel('_SASRT_htmldecode');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                               { push esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);               { mov esi,[ebp+8] }
  BinMovRegLabel(7,'_sas_strtmp');
  BinDefineLabel('_hd_loop');
  BinEmit8($8A); BinEmit8($06);                              { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_hd_done');
  BinEmit8($3C); BinEmit8($26);                              { cmp al,'&' }
  BinJccLabel(4,'_hd_entity');
  BinEmit8($88); BinEmit8($07);
  BinEmit8($46); BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_entity');
  BinEmit8($8A); BinEmit8($46); BinEmit8($01);               { mov al,[esi+1] }
  BinEmit8($0C); BinEmit8($20);                              { or al,0x20 → minuscule }
  BinEmit8($3C); BinEmit8($61);                              { cmp al,'a' }
  BinJccLabel(4,'_hd_amp_check');
  BinEmit8($3C); BinEmit8($6C);                              { cmp al,'l' }
  BinJccLabel(4,'_hd_lt_check');
  BinEmit8($3C); BinEmit8($67);                              { cmp al,'g' }
  BinJccLabel(4,'_hd_gt_check');
  BinEmit8($3C); BinEmit8($71);                              { cmp al,'q' }
  BinJccLabel(4,'_hd_quot_check');
  BinJmpLabel('_hd_no_match');
  BinDefineLabel('_hd_amp_check');                            { "amp;" ou "AMP;" }
  BinEmit8($8A); BinEmit8($46); BinEmit8($02);               { mov al,[esi+2] }
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($6D);                              { cmp al,'m' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($8A); BinEmit8($46); BinEmit8($03);               { mov al,[esi+3] }
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($70);                              { cmp al,'p' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($80); BinEmit8($7E); BinEmit8($04); BinEmit8($3B); { cmp [esi+4],';' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);               { '&' }
  BinEmit8($83); BinEmit8($C6); BinEmit8($05);               { add esi,5 }
  BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_lt_check');                             { "lt;" ou "LT;" }
  BinEmit8($8A); BinEmit8($46); BinEmit8($02);
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($74);                              { cmp al,'t' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($80); BinEmit8($7E); BinEmit8($03); BinEmit8($3B);
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($C6); BinEmit8($07); BinEmit8($3C);               { '<' }
  BinEmit8($83); BinEmit8($C6); BinEmit8($04);
  BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_gt_check');                             { "gt;" ou "GT;" }
  BinEmit8($8A); BinEmit8($46); BinEmit8($02);
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($74);                              { cmp al,'t' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($80); BinEmit8($7E); BinEmit8($03); BinEmit8($3B);
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($C6); BinEmit8($07); BinEmit8($3E);               { '>' }
  BinEmit8($83); BinEmit8($C6); BinEmit8($04);
  BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_quot_check');                           { "quot;" ou "QUOT;" }
  BinEmit8($8A); BinEmit8($46); BinEmit8($02);
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($75);                              { cmp al,'u' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($8A); BinEmit8($46); BinEmit8($03);
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($6F);                              { cmp al,'o' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($8A); BinEmit8($46); BinEmit8($04);
  BinEmit8($0C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($74);                              { cmp al,'t' }
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($80); BinEmit8($7E); BinEmit8($05); BinEmit8($3B);
  BinJccLabel(5,'_hd_no_match');
  BinEmit8($C6); BinEmit8($07); BinEmit8($22);               { '"' }
  BinEmit8($83); BinEmit8($C6); BinEmit8($06);
  BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_no_match');
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);               { '&' brut }
  BinEmit8($46); BinEmit8($47);
  BinJmpLabel('_hd_loop');
  BinDefineLabel('_hd_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_htmlencode(str): ptr --- encode &<>" en entites HTML }
  BinDefineLabel('_SASRT_htmlencode');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                               { push esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);               { mov esi,[ebp+8] }
  BinMovRegLabel(7,'_sas_strtmp');
  BinDefineLabel('_he_loop');
  BinEmit8($8A); BinEmit8($06);                              { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_he_done');
  BinEmit8($46);                                              { inc esi }
  BinEmit8($3C); BinEmit8($26);                              { cmp al,'&' }
  BinJccLabel(4,'_he_amp');
  BinEmit8($3C); BinEmit8($3C);                              { cmp al,'<' }
  BinJccLabel(4,'_he_lt');
  BinEmit8($3C); BinEmit8($3E);                              { cmp al,'>' }
  BinJccLabel(4,'_he_gt');
  BinEmit8($3C); BinEmit8($22);                              { cmp al,'"' }
  BinJccLabel(4,'_he_quot');
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($47);
  BinJmpLabel('_he_loop');
  BinDefineLabel('_he_amp');                                  { &amp; }
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($61); { 'a' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($02); BinEmit8($6D); { 'm' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($03); BinEmit8($70); { 'p' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($04); BinEmit8($3B); { ';' }
  BinEmit8($83); BinEmit8($C7); BinEmit8($05);               { add edi,5 }
  BinJmpLabel('_he_loop');
  BinDefineLabel('_he_lt');                                   { &lt; }
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($6C); { 'l' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($02); BinEmit8($74); { 't' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($03); BinEmit8($3B); { ';' }
  BinEmit8($83); BinEmit8($C7); BinEmit8($04);               { add edi,4 }
  BinJmpLabel('_he_loop');
  BinDefineLabel('_he_gt');                                   { &gt; }
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($67); { 'g' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($02); BinEmit8($74); { 't' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($03); BinEmit8($3B); { ';' }
  BinEmit8($83); BinEmit8($C7); BinEmit8($04);
  BinJmpLabel('_he_loop');
  BinDefineLabel('_he_quot');                                 { &quot; }
  BinEmit8($C6); BinEmit8($07); BinEmit8($26);
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($71); { 'q' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($02); BinEmit8($75); { 'u' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($03); BinEmit8($6F); { 'o' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($04); BinEmit8($74); { 't' }
  BinEmit8($C6); BinEmit8($47); BinEmit8($05); BinEmit8($3B); { ';' }
  BinEmit8($83); BinEmit8($C7); BinEmit8($06);               { add edi,6 }
  BinJmpLabel('_he_loop');
  BinDefineLabel('_he_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);               { null-terminate }
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E);                              { pop edi,esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_inputc(source,informat): ptr --- retourne source tel quel }
  { [ebp+8]=source(ptr) [ebp+12]=informat. ret 8. }
  BinDefineLabel('_SASRT_inputc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);     { mov eax,[ebp+8] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_iorcmsg(): ptr --- retourne "" (0 args) }
  BinDefineLabel('_SASRT_iorcmsg');
  BinJmpLabel('_sas_retempty0');

  { --- _SASRT_kcompress(str,chars): ptr --- retire chars de str (= COMPRESS) }
  BinDefineLabel('_SASRT_kcompress');
  BinJmpLabel('_SASRT_compress');

  { --- _SASRT_kleft(str): ptr --- supprime espaces debut (= LEFT) }
  BinDefineLabel('_SASRT_kleft');
  BinJmpLabel('_SASRT_left');

  { --- _SASRT_klowcase(str): ptr --- conversion minuscules (= LOWCASE) }
  BinDefineLabel('_SASRT_klowcase');
  BinJmpLabel('_SASRT_lowcase');

  { --- _SASRT_kreverse(str): ptr --- inverse la chaine dans strtmp (53 octets) }
  { Passe 1 : strlen dans ECX. Passe 2 : copie [ESI+ECX-1..ESI] → EDI. }
  { Offsets : _strlen_loop=15  _rev_start=25  _rev_loop=30  _rev_done=39 }
  BinDefineLabel('_SASRT_kreverse');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);           { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57);                           { push esi; push edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] str }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  BinEmit8($31); BinEmit8($C9);                           { xor ecx,ecx  len=0 }
  { _strlen_loop (offset 15): }
  BinEmit8($8A); BinEmit8($04); BinEmit8($0E);           { mov al,[esi+ecx] }
  BinEmit8($84); BinEmit8($C0);                           { test al,al }
  BinEmit8($74); BinEmit8($03);                           { jz _rev_start (+3 → 25) }
  BinEmit8($41);                                           { inc ecx }
  BinEmit8($EB); BinEmit8($F6);                           { jmp _strlen_loop (-10 → 15) }
  { _rev_start (offset 25): }
  BinEmit8($85); BinEmit8($C9);                           { test ecx,ecx }
  BinEmit8($74); BinEmit8($0A);                           { jz _rev_done (+10 → 39) }
  BinEmit8($49);                                           { dec ecx  → index dernier char }
  { _rev_loop (offset 30): }
  BinEmit8($8A); BinEmit8($04); BinEmit8($0E);           { mov al,[esi+ecx] }
  BinEmit8($88); BinEmit8($07);                           { mov [edi],al }
  BinEmit8($47);                                           { inc edi }
  BinEmit8($49);                                           { dec ecx }
  BinEmit8($79); BinEmit8($F7);                           { jns _rev_loop (-9 → 30) }
  { _rev_done (offset 39): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte [edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');                       { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5E);                           { pop edi; pop esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00); { pop ebp; ret 4 }

  { --- _SASRT_kright(str): ptr --- retourne str tel quel (= RIGHT, sans padding) }
  BinDefineLabel('_SASRT_kright');
  BinJmpLabel('_SASRT_right');

  { --- _SASRT_kscan(str,n,delims): ptr --- ne mot (= SCAN, memes args) }
  BinDefineLabel('_SASRT_kscan');
  BinJmpLabel('_SASRT_scan');

  { --- _SASRT_kstrcat(str1,str2): ptr --- concatenation (= CONCAT) }
  BinDefineLabel('_SASRT_kstrcat');
  BinJmpLabel('_SASRT_concat');

  { --- _SASRT_ksubstr(str,pos,len): ptr --- sous-chaine (= SUBSTR) }
  BinDefineLabel('_SASRT_ksubstr');
  BinJmpLabel('_SASRT_substr');

  { --- _SASRT_ksubstrb(str,pos,len): ptr --- sous-chaine octet (= SUBSTR) }
  BinDefineLabel('_SASRT_ksubstrb');
  BinJmpLabel('_SASRT_substr');

  { --- _SASRT_ktranslate(str,to,from): ptr --- substitution chars (= TRANSLATE) }
  BinDefineLabel('_SASRT_ktranslate');
  BinJmpLabel('_SASRT_translate');

  { --- _SASRT_ktrim(str): ptr --- supprime espaces finaux (= TRIM) }
  BinDefineLabel('_SASRT_ktrim');
  BinJmpLabel('_SASRT_trim');

  { --- _SASRT_kupcase(str): ptr --- conversion majuscules (= UPCASE) }
  BinDefineLabel('_SASRT_kupcase');
  BinJmpLabel('_SASRT_upcase');

  { --- _SASRT_kupdate(str,pos,del,ins): ptr --- copie str, supprime del chars }
  { depuis pos (1-base), insere ins. Args: [ebp+8]=str [ebp+12]=pos      }
  { [ebp+16]=del [ebp+20]=ins                                             }
  BinDefineLabel('_SASRT_kupdate');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  str }
  BinMovRegLabel(7,'_sas_strtmp');
  { etape 1 : prefix = pos-1 bytes }
  BinEmit8($8B); BinEmit8($55); BinEmit8($0C);           { mov edx,[ebp+12] pos }
  BinEmit8($4A);                                          { dec edx }
  BinJccLabel(14,'_ku_step2');                            { jle pas de prefix }
  BinDefineLabel('_ku_prefix');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ku_step2');                             { jz src fini }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                          { inc esi; inc edi }
  BinEmit8($4A);                                          { dec edx }
  BinJccLabel(5,'_ku_prefix');                            { jnz boucle }
  { etape 2 : copie ins }
  BinDefineLabel('_ku_step2');
  BinEmit8($8B); BinEmit8($5D); BinEmit8($14);           { mov ebx,[ebp+20] ins }
  BinDefineLabel('_ku_ins_loop');
  BinEmit8($8A); BinEmit8($03);                          { mov al,[ebx] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ku_step3');
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($47); BinEmit8($43);                          { inc edi; inc ebx }
  BinJmpLabel('_ku_ins_loop');
  { etape 3 : saute del chars, copie le reste }
  BinDefineLabel('_ku_step3');
  BinEmit8($8B); BinEmit8($4D); BinEmit8($10);           { mov ecx,[ebp+16] del }
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(14,'_ku_tail');                             { jle copie reste direct }
  BinDefineLabel('_ku_skip');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ku_done');                              { src fini }
  BinEmit8($46);                                          { inc esi }
  BinEmit8($49);                                          { dec ecx }
  BinJccLabel(5,'_ku_skip');                              { jnz boucle }
  BinDefineLabel('_ku_tail');
  BinDefineLabel('_ku_tail_loop');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ku_done');
  BinEmit8($88); BinEmit8($07);
  BinEmit8($46); BinEmit8($47);
  BinJmpLabel('_ku_tail_loop');
  BinDefineLabel('_ku_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { null-terminate }
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($10); BinEmit8($00);

  { --- _SASRT_kupdateb: identique KUPDATE (byte-addressable = meme logique) }
  BinDefineLabel('_SASRT_kupdateb');
  BinJmpLabel('_SASRT_kupdate');

  { --- _SASRT_modulec(routine,arg): ptr --- retourne une copie de arg (2 args) }
  BinDefineLabel('_SASRT_modulec');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                         { push esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);           { mov esi,[ebp+12] arg }
  BinMovRegLabel(7, '_sas_strtmp');                      { mov edi,_sas_strtmp }
  BinEmit8($85); BinEmit8($F6);                          { test esi,esi }
  BinJccLabel(4, '_modulec_empty');                      { jz empty }
  BinDefineLabel('_modulec_loop');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                          { inc esi; inc edi }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinJccLabel(5, '_modulec_loop');                       { jnz loop }
  BinJmpLabel('_modulec_done');
  BinDefineLabel('_modulec_empty');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte[edi],0 }
  BinDefineLabel('_modulec_done');
  BinMovRegLabel(0, '_sas_strtmp');                      { mov eax,_sas_strtmp }
  BinEmit8($5F); BinEmit8($5E);                          { pop edi,esi }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_moduleic(routine,arg): ptr --- idem MODULEC }
  BinDefineLabel('_SASRT_moduleic');
  BinJmpLabel('_SASRT_modulec');

  { --- Batch 9 : fonctions retournant des chaines --- }

  { --- _SASRT_pathname(ref): ptr --- retourne "" (1 arg) }
  BinDefineLabel('_SASRT_pathname');
  BinJmpLabel('_sas_retempty1');

  { --- _SASRT_peekc(addr): ptr --- lit octet a addr, retourne string 1 char }
  BinDefineLabel('_SASRT_peekc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($57);                                          { push edi }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);           { mov ecx,[ebp+8] addr }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  BinEmit8($8A); BinEmit8($01);                           { mov al,[ecx] }
  BinEmit8($88); BinEmit8($07);                           { mov [edi],al }
  BinEmit8($C6); BinEmit8($47); BinEmit8($01); BinEmit8($00); { mov byte [edi+1],0 }
  BinMovRegLabel(0, '_sas_strtmp');                       { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5D);                           { pop edi; pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_putc(val,fmt): ptr --- retourne val (chaine car) tel quel }
  { [ebp+8]=val(ptr) [ebp+12]=fmt. ret 8. }
  BinDefineLabel('_SASRT_putc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);     { mov eax,[ebp+8] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_putn(val,fmt): ptr --- alias numerique de _SASRT_put }
  BinDefineLabel('_SASRT_putn');
  BinJmpLabel('_SASRT_put');

  { --- Batch 11 : fonctions chaines S --- }

  { --- _SASRT_soundex(s): ptr --- code Soundex phonetique (1 arg)           }
  { Retourne strtmp : 1 lettre + 3 chiffres (ex: Smith → S530).            }
  { Table Soundex A-Z : 0=transparent(HW) 7=voyelle/separateur 1-6=code.  }
  { Voyelles(AEIOUY)=7 reinitialisent last_code. H,W=0 sont transparents.  }
  { Registres : ESI=src EDI=dst EDX=table EBX=last_code ECX=digits_restants }
  BinJmpLabel('_sx_after_table');
  BinDefineLabel('_sx_table');
  BinEmit8(7);BinEmit8(1);BinEmit8(2);BinEmit8(3);BinEmit8(7);BinEmit8(1); {A-F}
  BinEmit8(2);BinEmit8(0);BinEmit8(7);BinEmit8(2);BinEmit8(2);BinEmit8(4); {G-L}
  BinEmit8(5);BinEmit8(5);BinEmit8(7);BinEmit8(1);BinEmit8(2);BinEmit8(6); {M-R}
  BinEmit8(2);BinEmit8(3);BinEmit8(7);BinEmit8(1);BinEmit8(0);BinEmit8(2); {S-X}
  BinEmit8(7);BinEmit8(2);                                                   {Y,Z}
  BinDefineLabel('_sx_after_table');
  BinDefineLabel('_SASRT_soundex');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8] s }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  BinMovRegLabel(2, '_sx_table');                         { mov edx,&_sx_table }
  { trouver premier char alpha }
  BinDefineLabel('_sx_find_first');
  BinEmit8($0F); BinEmit8($B6); BinEmit8($06);           { movzx eax,byte[esi] }
  BinEmit8($85); BinEmit8($C0);                           { test eax,eax }
  BinJccLabel(4, '_sx_empty');                             { jz → vide }
  BinEmit8($46);                                           { inc esi }
  BinEmit8($83); BinEmit8($F8); BinEmit8($61);           { cmp eax,'a' }
  BinJccLabel(2, '_sx_ff_check_az');                       { jb → upper range }
  BinEmit8($83); BinEmit8($F8); BinEmit8($7A);           { cmp eax,'z' }
  BinJccLabel(7, '_sx_find_first');                        { ja → non-alpha }
  BinEmit8($83); BinEmit8($E8); BinEmit8($20);           { sub eax,32 → majuscule }
  BinDefineLabel('_sx_ff_check_az');
  BinEmit8($83); BinEmit8($F8); BinEmit8($41);           { cmp eax,'A' }
  BinJccLabel(2, '_sx_find_first');                        { jb → non-alpha }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5A);           { cmp eax,'Z' }
  BinJccLabel(7, '_sx_find_first');                        { ja → non-alpha }
  BinEmit8($88); BinEmit8($07);                           { mov [edi],al premier char }
  BinEmit8($47);                                           { inc edi }
  { code du premier char → last_code }
  BinEmit8($89); BinEmit8($C3);                           { mov ebx,eax }
  BinEmit8($83); BinEmit8($EB); BinEmit8($41);           { sub ebx,'A' → 0-25 }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($1C); BinEmit8($1A); { movzx ebx,byte[edx+ebx] }
  BinEmit8($B9); BinEmit8($03); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,3 }
  { _sx_loop: }
  BinDefineLabel('_sx_loop');
  BinEmit8($85); BinEmit8($C9);                           { test ecx,ecx }
  BinJccLabel(4, '_sx_pad');                               { jz → rembourrer }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($06);           { movzx eax,byte[esi] }
  BinEmit8($85); BinEmit8($C0);                           { test eax,eax }
  BinJccLabel(4, '_sx_pad');                               { jz → fin chaine }
  BinEmit8($46);                                           { inc esi }
  BinEmit8($83); BinEmit8($F8); BinEmit8($61);           { cmp eax,'a' }
  BinJccLabel(2, '_sx_check_upper');                       { jb → upper }
  BinEmit8($83); BinEmit8($F8); BinEmit8($7A);           { cmp eax,'z' }
  BinJccLabel(7, '_sx_loop');                              { ja → non-alpha, sauter }
  BinEmit8($83); BinEmit8($E8); BinEmit8($20);           { sub eax,32 }
  BinDefineLabel('_sx_check_upper');
  BinEmit8($83); BinEmit8($F8); BinEmit8($41);           { cmp eax,'A' }
  BinJccLabel(2, '_sx_loop');                              { jb → sauter }
  BinEmit8($83); BinEmit8($F8); BinEmit8($5A);           { cmp eax,'Z' }
  BinJccLabel(7, '_sx_loop');                              { ja → sauter }
  BinEmit8($83); BinEmit8($E8); BinEmit8($41);           { sub eax,'A' → 0-25 }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($04); BinEmit8($02); { movzx eax,byte[edx+eax] }
  { 0=transparent(HW), 7=voyelle reset, 1-6=consonne }
  BinEmit8($85); BinEmit8($C0);                           { test eax,eax }
  BinJccLabel(4, '_sx_loop');                              { jz → H/W transparent, skip }
  BinEmit8($83); BinEmit8($F8); BinEmit8($07);           { cmp eax,7 }
  BinJccLabel(3, '_sx_vowel');                             { jae → voyelle, reinit last_code }
  BinEmit8($3B); BinEmit8($C3);                           { cmp eax,ebx }
  BinJccLabel(4, '_sx_loop');                              { je → doublon, sauter }
  BinEmit8($89); BinEmit8($C3);                           { mov ebx,eax last_code=code }
  BinEmit8($83); BinEmit8($C0); BinEmit8($30);           { add eax,'0' }
  BinEmit8($88); BinEmit8($07);                           { mov [edi],al }
  BinEmit8($47);                                           { inc edi }
  BinEmit8($49);                                           { dec ecx }
  BinJmpLabel('_sx_loop');
  BinDefineLabel('_sx_vowel');
  BinEmit8($31); BinEmit8($DB);                           { xor ebx,ebx  reset last_code=0 }
  BinJmpLabel('_sx_loop');
  { _sx_pad: }
  BinDefineLabel('_sx_pad');
  BinEmit8($85); BinEmit8($C9);                           { test ecx,ecx }
  BinJccLabel(4, '_sx_padded');                            { jz → fini }
  BinEmit8($C6); BinEmit8($07); BinEmit8($30);           { mov byte [edi],'0' }
  BinEmit8($47);                                           { inc edi }
  BinEmit8($49);                                           { dec ecx }
  BinJmpLabel('_sx_pad');
  BinDefineLabel('_sx_padded');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte [edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');                       { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);           { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  { _sx_empty: chaine vide → retourne "" }
  BinDefineLabel('_sx_empty');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);           { mov byte [edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_stname(abbrev): ptr --- retourne "" (1 arg) }
  BinDefineLabel('_SASRT_stname');
  BinJmpLabel('_sas_retempty1');

  { --- _SASRT_stnamel(abbrev): ptr --- retourne "" (1 arg) }
  BinDefineLabel('_SASRT_stnamel');
  BinJmpLabel('_sas_retempty1');

  { --- _SASRT_symput(name,value): stocke une macro-variable runtime (2 args) }
  BinDefineLabel('_SASRT_symput');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57); BinEmit8($51);          { push esi;edi;ecx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);          { mov esi,[ebp+8] name }
  BinMovRegLabel(7, '_sas_sym_name');                   { mov edi,&sym_name }
  BinEmit8($B9); BinEmit32(31);                         { mov ecx,31 }
  BinDefineLabel('_symput_name_loop');
  BinEmit8($85); BinEmit8($C9);                         { test ecx,ecx }
  BinJccLabel(4, '_symput_name_done');
  BinEmit8($8A); BinEmit8($06);                         { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                         { test al,al }
  BinJccLabel(4, '_symput_name_done');
  BinEmit8($88); BinEmit8($07);                         { mov [edi],al }
  BinEmit8($46); BinEmit8($47); BinEmit8($49);          { inc esi; inc edi; dec ecx }
  BinJmpLabel('_symput_name_loop');
  BinDefineLabel('_symput_name_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);          { nul terminal }
  BinEmit8($8B); BinEmit8($75); BinEmit8($0C);          { mov esi,[ebp+12] value }
  BinMovRegLabel(7, '_sas_sym_value');                  { mov edi,&sym_value }
  BinEmit8($B9); BinEmit32(255);                        { mov ecx,255 }
  BinDefineLabel('_symput_value_loop');
  BinEmit8($85); BinEmit8($C9);
  BinJccLabel(4, '_symput_value_done');
  BinEmit8($8A); BinEmit8($06);
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4, '_symput_value_done');
  BinEmit8($88); BinEmit8($07);
  BinEmit8($46); BinEmit8($47); BinEmit8($49);
  BinJmpLabel('_symput_value_loop');
  BinDefineLabel('_symput_value_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);
  BinEmit8($59); BinEmit8($5F); BinEmit8($5E);
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_symget(name): ptr --- retourne la valeur stockee par SYMPUT (1 arg) }
  BinDefineLabel('_SASRT_symget');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                         { push esi;edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);          { mov esi,[ebp+8] name }
  BinMovRegLabel(7, '_sas_sym_name');                   { mov edi,&sym_name }
  BinDefineLabel('_symget_cmp_loop');
  BinEmit8($8A); BinEmit8($06);                         { mov al,[esi] }
  BinEmit8($8A); BinEmit8($27);                         { mov ah,[edi] }
  BinEmit8($38); BinEmit8($E0);                         { cmp al,ah }
  BinJccLabel(5, '_symget_not_found');
  BinEmit8($84); BinEmit8($C0);                         { test al,al }
  BinJccLabel(4, '_symget_found');
  BinEmit8($46); BinEmit8($47);                         { inc esi; inc edi }
  BinJmpLabel('_symget_cmp_loop');
  BinDefineLabel('_symget_found');
  BinMovRegLabel(0, '_sas_sym_value');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);
  BinDefineLabel('_symget_not_found');
  BinMovRegLabel(0, '_sas_empty');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_sysget(name): ptr --- GetEnvironmentVariableA(name,strtmp,256) }
  { Layout (32 o): mov edi,&strtmp / clear / push 256 / push edi / push name / call / ret }
  BinDefineLabel('_SASRT_sysget');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp      }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte[edi],0      }
  BinEmit8($68); BinEmit8($00); BinEmit8($01); BinEmit8($00); BinEmit8($00); { push 256 }
  BinEmit8($57);                                  { push edi (buffer)    }
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);  { push [ebp+8] (name)  }
  BinCallImport('_GetEnvironmentVariableA@12');
  BinEmit8($89); BinEmit8($F8);                  { mov eax,edi          }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_sysmsg(): ptr --- retourne "" (0 args) }
  BinDefineLabel('_SASRT_sysmsg');
  BinJmpLabel('_sas_retempty0');

  { --- _SASRT_sysparm(): ptr --- retourne "" (0 args) }
  BinDefineLabel('_SASRT_sysparm');
  BinJmpLabel('_sas_retempty0');

  { --- Batch 10 : fonctions chaines Q-S --- }

  { --- _SASRT_quote(s): ptr --- entoure de guillemets dans strtmp (47 o) }
  { Layout: ecrit '"', copie s, ecrit '"', ecrit 0, retourne strtmp.     }
  { je _done_copy: after=23, target=29, delta=6 → 74 06                  }
  { jmp _copy: after=29, target=17, delta=-12=0xF4 → EB F4               }
  BinDefineLabel('_SASRT_quote');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                  { push esi; edi    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]  }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp  }
  BinEmit8($C6); BinEmit8($07); BinEmit8($22);  { mov [edi],'"'    }
  BinEmit8($47);                                  { inc edi          }
  { _copy (offset 17): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]     }
  BinEmit8($84); BinEmit8($C0);                  { test al,al       }
  BinEmit8($74); BinEmit8($06);                  { je _done (→ 29)  }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al     }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi }
  BinEmit8($EB); BinEmit8($F4);                  { jmp _copy (→ 17) }
  { _done_copy (offset 29): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($22);  { mov [edi],'"'    }
  BinEmit8($47);                                  { inc edi          }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov [edi],0      }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp  }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi;esi;ebp  }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4            }

  { --- _SASRT_repeat(s,n): ptr --- copie s (n+1) fois dans strtmp (54 o) }
  { ebx=n+1, edi=strtmp, esi=s; boucle outer x inner.                     }
  { jle _done: after=22, target=39, delta=17 → 7E 11                      }
  { je _inner_done: after=29, target=35, delta=6 → 74 06                  }
  { jmp _inner: after=35, target=23, delta=-12=0xF4 → EB F4               }
  { jmp _outer: after=39, target=18, delta=-21=0xEB → EB EB               }
  BinDefineLabel('_SASRT_repeat');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57); BinEmit8($53);  { push esi;edi;ebx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]  }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);  { mov ebx,[ebp+12] }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp  }
  BinEmit8($43);                                  { inc ebx  (n+1)   }
  { _outer (offset 18): }
  BinEmit8($85); BinEmit8($DB);                  { test ebx,ebx     }
  BinEmit8($7E); BinEmit8($11);                  { jle _done (→ 39) }
  BinEmit8($56);                                  { push esi         }
  { _inner (offset 23): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]     }
  BinEmit8($84); BinEmit8($C0);                  { test al,al       }
  BinEmit8($74); BinEmit8($06);                  { je _inner_done(→35)}
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al     }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi }
  BinEmit8($EB); BinEmit8($F4);                  { jmp _inner (→ 23)}
  { _inner_done (offset 35): }
  BinEmit8($5E);                                  { pop esi          }
  BinEmit8($4B);                                  { dec ebx          }
  BinEmit8($EB); BinEmit8($EB);                  { jmp _outer (→ 18)}
  { _done (offset 39): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov [edi],0      }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp  }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);  { pop ebx;edi;esi  }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($08); BinEmit8($00);

  { --- _SASRT_resolve(s): ptr --- retourne s tel quel (1 arg) }
  { [ebp+8]=s(ptr). ret 4. }
  BinDefineLabel('_SASRT_resolve');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);     { push ebp; mov ebp,esp }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);     { mov eax,[ebp+8] }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_reverse(s): ptr --- inverse s dans strtmp (51 o)            }
  { esi=src, eax=scan ptr, edi=dst. Phase1: scan to null. Phase2: backward }
  { je _found: after=20, target=23, delta=3 → 74 03                        }
  { jmp _scan: after=23, target=15, delta=-8=0xF8 → EB F8                  }
  { je _done: after=27, target=37, delta=10 → 74 0A                        }
  { jne _rev: after=37, target=27, delta=-10=0xF6 → 75 F6                  }
  BinDefineLabel('_SASRT_reverse');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57);                  { push esi; push edi     }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]        }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp        }
  BinEmit8($89); BinEmit8($F0);                  { mov eax,esi (scan ptr) }
  { _scan (offset 15): }
  BinEmit8($80); BinEmit8($38); BinEmit8($00);  { cmp byte[eax],0        }
  BinEmit8($74); BinEmit8($03);                  { je _found (→ 23)       }
  BinEmit8($40);                                  { inc eax                }
  BinEmit8($EB); BinEmit8($F8);                  { jmp _scan (→ 15)       }
  { _found (offset 23): eax→null, esi→first char }
  BinEmit8($39); BinEmit8($F0);                  { cmp eax,esi            }
  BinEmit8($74); BinEmit8($0A);                  { je _done (→ 37)        }
  { _rev (offset 27): }
  BinEmit8($48);                                  { dec eax                }
  BinEmit8($8A); BinEmit8($08);                  { mov cl,[eax]           }
  BinEmit8($88); BinEmit8($0F);                  { mov [edi],cl           }
  BinEmit8($47);                                  { inc edi                }
  BinEmit8($39); BinEmit8($F0);                  { cmp eax,esi            }
  BinEmit8($75); BinEmit8($F6);                  { jne _rev (→ 27)        }
  { _done (offset 37): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte[edi],0        }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp        }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi; esi; ebp      }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);  { ret 4                  }

  { --- _SASRT_scan(s,n,delim): ptr --- ne mot de s separe par espaces (99 o) }
  { [ebp+8]=s, [ebp+12]=n (1-based), [ebp+16]=delim (ignore, utilise ' ')    }
  { esi=s, ebx=n, edi=strtmp, ecx=wordcount. 3 phases: skip_sp / copy / skip }
  { jz _not_found1(24): after=26, target=83, delta=57 → 74 39                }
  { jne _start_word(28): after=30, target=33, delta=3 → 75 03                }
  { jmp _skip_sp(31): after=33, target=20, delta=-13=0xF3 → EB F3            }
  { jne _skip_word(36): after=38, target=70, delta=32 → 75 20                }
  { jz _word_done(42): after=44, target=54, delta=10 → 74 0A                 }
  { je _word_done(46): after=48, target=54, delta=6 → 74 06                  }
  { jmp _copy_word(52): after=54, target=38, delta=-16=0xF0 → EB F0          }
  { jz _not_found2(74): after=76, target=83, delta=7 → 74 07                 }
  { je _skip_sp2(78): after=80, target=20, delta=-60=0xC4 → 74 C4            }
  { jmp _skip_word2(81): after=83, target=70, delta=-13=0xF3 → EB F3         }
  BinDefineLabel('_SASRT_scan');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57); BinEmit8($53); BinEmit8($51); { push esi;edi;ebx;ecx }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]  ; s      }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);  { mov ebx,[ebp+12] ; n      }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp           }
  BinEmit8($31); BinEmit8($C9);                  { xor ecx,ecx               }
  { _skip_sp (offset 20): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]              }
  BinEmit8($84); BinEmit8($C0);                  { test al,al                }
  BinEmit8($74); BinEmit8($39);                  { jz _not_found (→ 83)      }
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '                }
  BinEmit8($75); BinEmit8($03);                  { jne _start_word (→ 33)    }
  BinEmit8($46);                                  { inc esi                   }
  BinEmit8($EB); BinEmit8($F3);                  { jmp _skip_sp (→ 20)       }
  { _start_word (offset 33): }
  BinEmit8($41);                                  { inc ecx                   }
  BinEmit8($39); BinEmit8($D9);                  { cmp ecx,ebx               }
  BinEmit8($75); BinEmit8($20);                  { jne _skip_word (→ 70)     }
  { _copy_word (offset 38): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]              }
  BinEmit8($84); BinEmit8($C0);                  { test al,al                }
  BinEmit8($74); BinEmit8($0A);                  { jz _word_done (→ 54)      }
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '                }
  BinEmit8($74); BinEmit8($06);                  { je _word_done (→ 54)      }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al              }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi          }
  BinEmit8($EB); BinEmit8($F0);                  { jmp _copy_word (→ 38)     }
  { _word_done (offset 54): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte[edi],0           }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp           }
  BinEmit8($59); BinEmit8($5B);                  { pop ecx; pop ebx          }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi; esi; ebp         }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);  { ret 12                    }
  { _skip_word (offset 70): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]              }
  BinEmit8($84); BinEmit8($C0);                  { test al,al                }
  BinEmit8($74); BinEmit8($07);                  { jz _not_found (→ 83)      }
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '                }
  BinEmit8($74); BinEmit8($C4);                  { je _skip_sp (→ 20)        }
  BinEmit8($46);                                  { inc esi                   }
  BinEmit8($EB); BinEmit8($F3);                  { jmp _skip_word (→ 70)     }
  { _not_found (offset 83): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte[edi],0           }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp           }
  BinEmit8($59); BinEmit8($5B);                  { pop ecx; pop ebx          }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5D);  { pop edi; esi; ebp         }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);  { ret 12                    }

  { --- _SASRT_translate(str,to,from): ptr --- 85 o stdcall ret 12          }
  { [ebp+8]=str [ebp+12]=to [ebp+16]=from                                   }
  { Pour chaque char c de str: cherche c dans from (ebx), si trouve a la   }
  { position i, emet to[i] (charge via [ebp+12]+i); sinon copie c.         }
  { Registres: esi=str edi=strtmp ebx=from edx=search_ptr/offset cl=search }
  { Offsets: _outer=17 _search=25 _no_match=38 _found=44 _write=63 _done=70}
  { jz _done=+47(0x2F) jz _no_match=+7 je _found=+9 jmp _search=-13(0xF3) }
  { jmp _outer(nm)=-27(0xE5) jnz _write=+4 jmp_outer(del)=-46(0xD2)       }
  { jmp_outer(wr)=-53(0xCB)                                                 }
  BinDefineLabel('_SASRT_translate');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);  { push ebp; mov ebp,esp }
  BinEmit8($56); BinEmit8($57); BinEmit8($53);  { push esi; edi; ebx    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]       }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp       }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($10);  { mov ebx,[ebp+16]      }
  { _outer (offset 17): }
  BinEmit8($8A); BinEmit8($06);                  { mov al,[esi]          }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($74); BinEmit8($2F);                  { jz _done (+47 →70)   }
  BinEmit8($89); BinEmit8($DA);                  { mov edx,ebx           }
  { _search (offset 25): }
  BinEmit8($8A); BinEmit8($0A);                  { mov cl,[edx]          }
  BinEmit8($84); BinEmit8($C9);                  { test cl,cl            }
  BinEmit8($74); BinEmit8($07);                  { jz _no_match (+7 →38)}
  BinEmit8($38); BinEmit8($C8);                  { cmp al,cl             }
  BinEmit8($74); BinEmit8($09);                  { je _found (+9 →44)   }
  BinEmit8($42);                                  { inc edx               }
  BinEmit8($EB); BinEmit8($F3);                  { jmp _search (-13 →25)}
  { _no_match (offset 38): }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al          }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi      }
  BinEmit8($EB); BinEmit8($E5);                  { jmp _outer (-27 →17) }
  { _found (offset 44): }
  BinEmit8($50);                                  { push eax              }
  BinEmit8($29); BinEmit8($DA);                  { sub edx,ebx           }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);  { mov eax,[ebp+12]      }
  BinEmit8($01); BinEmit8($D0);                  { add eax,edx           }
  BinEmit8($0F); BinEmit8($B6); BinEmit8($00);  { movzx eax,byte[eax]   }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($75); BinEmit8($04);                  { jnz _write (+4 →63)  }
  BinEmit8($58);                                  { pop eax               }
  BinEmit8($46);                                  { inc esi               }
  BinEmit8($EB); BinEmit8($D2);                  { jmp _outer (-46 →17) }
  { _write (offset 63): }
  BinEmit8($88); BinEmit8($07);                  { mov [edi],al          }
  BinEmit8($58);                                  { pop eax               }
  BinEmit8($46); BinEmit8($47);                  { inc esi; inc edi      }
  BinEmit8($EB); BinEmit8($CB);                  { jmp _outer (-53 →17) }
  { _done (offset 70): }
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);  { mov byte[edi],0       }
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp       }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);  { pop ebx; edi; esi     }
  BinEmit8($5D);                                  { pop ebp               }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);  { ret 12                }

  { --- _SASRT_tranwrd(str,from,to): ptr --- remplace toutes occurrences de from par to }
  { [ebp+8]=str [ebp+12]=from [ebp+16]=to. ESI=str, EDI=strtmp.                       }
  { ECX=match_idx. Si from vide (ECX=0 a la fin du match), copie un char.             }
  BinDefineLabel('_SASRT_tranwrd');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);           { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);           { mov esi,[ebp+8]  str }
  BinMovRegLabel(7, '_sas_strtmp');                       { mov edi,&strtmp }
  { _tw_loop: }
  BinDefineLabel('_tw_loop');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);                          { test al,al }
  BinJccLabel(4, '_tw_done');                             { jz done }
  BinEmit8($8B); BinEmit8($45); BinEmit8($0C);          { mov eax,[ebp+12] from }
  BinEmit8($31); BinEmit8($C9);                          { xor ecx,ecx }
  { _tw_match_loop: }
  BinDefineLabel('_tw_match_loop');
  BinEmit8($8A); BinEmit8($14); BinEmit8($08);          { mov dl,[eax+ecx] from[idx] }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinJccLabel(4, '_tw_match_found');                      { jz fully matched }
  BinEmit8($8A); BinEmit8($1C); BinEmit8($0E);          { mov bl,[esi+ecx] src[idx] }
  BinEmit8($3A); BinEmit8($DA);                          { cmp bl,dl }
  BinJccLabel(5, '_tw_match_fail');                       { jnz mismatch }
  BinEmit8($41);                                          { inc ecx }
  BinJmpLabel('_tw_match_loop');
  { _tw_match_found: ECX=flen }
  BinDefineLabel('_tw_match_found');
  BinEmit8($85); BinEmit8($C9);                          { test ecx,ecx }
  BinJccLabel(4, '_tw_match_fail');                       { jz empty from → skip }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);          { mov eax,[ebp+16] to }
  { _tw_copy_to: }
  BinDefineLabel('_tw_copy_to');
  BinEmit8($8A); BinEmit8($10);                          { mov dl,[eax] }
  BinEmit8($84); BinEmit8($D2);                          { test dl,dl }
  BinJccLabel(4, '_tw_advance_src');                      { jz → advance src }
  BinEmit8($88); BinEmit8($17);                          { mov [edi],dl }
  BinEmit8($47); BinEmit8($40);                          { inc edi; inc eax }
  BinJmpLabel('_tw_copy_to');
  { _tw_advance_src: }
  BinDefineLabel('_tw_advance_src');
  BinEmit8($03); BinEmit8($F1);                          { add esi,ecx }
  BinJmpLabel('_tw_loop');
  { _tw_match_fail: copie un char }
  BinDefineLabel('_tw_match_fail');
  BinEmit8($8A); BinEmit8($06);                          { mov al,[esi] }
  BinEmit8($88); BinEmit8($07);                          { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                          { inc esi; inc edi }
  BinJmpLabel('_tw_loop');
  { _tw_done: }
  BinDefineLabel('_tw_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);          { mov byte [edi],0 }
  BinMovRegLabel(0, '_sas_strtmp');                      { mov eax,&strtmp }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);          { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($0C); BinEmit8($00); { ret 12 }

  { --- _SASRT_trimn(s): ptr --- copie+rogne espaces finaux (1 arg)       }
  { Meme comportement que _SASRT_trim : copie src dans strtmp, ebx=dernier}
  { offset non-espace+1.                                                    }
  BinDefineLabel('_SASRT_trimn');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($56); BinEmit8($57); BinEmit8($53);  { push esi; edi; ebx    }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);  { mov esi,[ebp+8]       }
  BinMovRegLabel(7, '_sas_strtmp');              { mov edi,&strtmp       }
  BinEmit8($31); BinEmit8($DB);                  { xor ebx,ebx           }
  BinEmit8($31); BinEmit8($C9);                  { xor ecx,ecx           }
  { _loop (offset 18): }
  BinEmit8($8A); BinEmit8($04); BinEmit8($0E);  { mov al,[esi+ecx]      }
  BinEmit8($88); BinEmit8($04); BinEmit8($0F);  { mov [edi+ecx],al      }
  BinEmit8($84); BinEmit8($C0);                  { test al,al            }
  BinEmit8($74); BinEmit8($0A);                  { jz _nullterm (→38)   }
  BinEmit8($3C); BinEmit8($20);                  { cmp al,' '            }
  BinEmit8($74); BinEmit8($03);                  { je _skip (→35)       }
  BinEmit8($8D); BinEmit8($59); BinEmit8($01);  { lea ebx,[ecx+1]       }
  { _skip (offset 35): }
  BinEmit8($41);                                  { inc ecx               }
  BinEmit8($EB); BinEmit8($EC);                  { jmp _loop (→18)      }
  { _nullterm (offset 38): }
  BinEmit8($C6); BinEmit8($04); BinEmit8($1F); BinEmit8($00);
  BinMovRegLabel(0, '_sas_strtmp');              { mov eax,&strtmp       }
  BinEmit8($5B); BinEmit8($5F); BinEmit8($5E);  { pop ebx; edi; esi     }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_urldecode(s): ptr --- decode sequences %XX }
  BinDefineLabel('_SASRT_urldecode');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);               { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);               { mov esi,[ebp+8] }
  BinMovRegLabel(7,'_sas_strtmp');
  BinDefineLabel('_ud_loop');
  BinEmit8($8A); BinEmit8($06);                              { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ud_done');
  BinEmit8($3C); BinEmit8($25);                              { cmp al,'%' }
  BinJccLabel(4,'_ud_pct');
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($46); BinEmit8($47);                              { inc esi; inc edi }
  BinJmpLabel('_ud_loop');
  BinDefineLabel('_ud_pct');
  { nibble haut depuis [esi+1] }
  BinEmit8($8A); BinEmit8($46); BinEmit8($01);               { mov al,[esi+1] }
  BinEmit8($2C); BinEmit8($30);                              { sub al,'0' }
  BinEmit8($3C); BinEmit8($0A);                              { cmp al,10 }
  BinJccLabel(2,'_ud_h_ok');                                  { jb digit 0-9 }
  BinEmit8($2C); BinEmit8($11);                              { sub al,'A'-'0' }
  BinEmit8($3C); BinEmit8($06);                              { cmp al,6 }
  BinJccLabel(2,'_ud_h_alpha');                               { jb A-F }
  BinEmit8($2C); BinEmit8($20);                              { sub al,'a'-'A' }
  BinEmit8($3C); BinEmit8($06);                              { cmp al,6 }
  BinJccLabel(3,'_ud_copy_pct');                              { jae invalide }
  BinDefineLabel('_ud_h_alpha');
  BinEmit8($04); BinEmit8($0A);                              { add al,10 }
  BinDefineLabel('_ud_h_ok');
  BinEmit8($88); BinEmit8($C3);                              { mov bl,al }
  BinEmit8($C0); BinEmit8($E3); BinEmit8($04);               { shl bl,4 }
  { nibble bas depuis [esi+2] }
  BinEmit8($8A); BinEmit8($46); BinEmit8($02);               { mov al,[esi+2] }
  BinEmit8($2C); BinEmit8($30);
  BinEmit8($3C); BinEmit8($0A);
  BinJccLabel(2,'_ud_l_ok');
  BinEmit8($2C); BinEmit8($11);
  BinEmit8($3C); BinEmit8($06);
  BinJccLabel(2,'_ud_l_alpha');
  BinEmit8($2C); BinEmit8($20);
  BinEmit8($3C); BinEmit8($06);
  BinJccLabel(3,'_ud_copy_pct');
  BinDefineLabel('_ud_l_alpha');
  BinEmit8($04); BinEmit8($0A);
  BinDefineLabel('_ud_l_ok');
  BinEmit8($0A); BinEmit8($C3);                              { or al,bl }
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($83); BinEmit8($C6); BinEmit8($03);               { add esi,3 }
  BinEmit8($47);
  BinJmpLabel('_ud_loop');
  BinDefineLabel('_ud_copy_pct');
  BinEmit8($C6); BinEmit8($07); BinEmit8($25);               { mov byte[edi],'%' }
  BinEmit8($46); BinEmit8($47);
  BinJmpLabel('_ud_loop');
  BinDefineLabel('_ud_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);               { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_urlencode(s): ptr --- encode URL, chars non-reserves RFC 3986 passes }
  BinDefineLabel('_SASRT_urlencode');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);               { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($75); BinEmit8($08);               { mov esi,[ebp+8] }
  BinMovRegLabel(7,'_sas_strtmp');
  BinDefineLabel('_ue_loop');
  BinEmit8($8A); BinEmit8($06);                              { mov al,[esi] }
  BinEmit8($84); BinEmit8($C0);
  BinJccLabel(4,'_ue_done');
  BinEmit8($46);                                              { inc esi }
  { test A-Z }
  BinEmit8($3C); BinEmit8($41);                              { cmp al,'A' }
  BinJccLabel(2,'_ue_check_09');                              { jb verif 0-9 }
  BinEmit8($3C); BinEmit8($5A);                              { cmp al,'Z' }
  BinJccLabel(6,'_ue_copy');                                  { jbe A-Z safe }
  { test a-z }
  BinEmit8($3C); BinEmit8($61);                              { cmp al,'a' }
  BinJccLabel(2,'_ue_check_sp');                              { jb special }
  BinEmit8($3C); BinEmit8($7A);                              { cmp al,'z' }
  BinJccLabel(6,'_ue_copy');                                  { jbe a-z safe }
  BinJmpLabel('_ue_check_sp');                                { al>'z' → verifie aussi tilde }
  BinDefineLabel('_ue_check_09');
  BinEmit8($3C); BinEmit8($30);                              { cmp al,'0' }
  BinJccLabel(2,'_ue_check_sp');
  BinEmit8($3C); BinEmit8($39);                              { cmp al,'9' }
  BinJccLabel(6,'_ue_copy');                                  { jbe 0-9 safe }
  BinDefineLabel('_ue_check_sp');
  BinEmit8($3C); BinEmit8($2D);                              { cmp al,'-' }
  BinJccLabel(4,'_ue_copy');
  BinEmit8($3C); BinEmit8($5F);                              { cmp al,'_' }
  BinJccLabel(4,'_ue_copy');
  BinEmit8($3C); BinEmit8($2E);                              { cmp al,'.' }
  BinJccLabel(4,'_ue_copy');
  BinEmit8($3C); BinEmit8($7E);                              { cmp al,'~' }
  BinJccLabel(4,'_ue_copy');
  BinJmpLabel('_ue_encode');
  BinDefineLabel('_ue_copy');
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($47);
  BinJmpLabel('_ue_loop');
  BinDefineLabel('_ue_encode');
  BinEmit8($88); BinEmit8($C3);                              { mov bl,al (sauvegarde) }
  BinEmit8($C6); BinEmit8($07); BinEmit8($25);               { mov byte[edi],'%' }
  BinEmit8($47);
  { nibble haut }
  BinEmit8($8A); BinEmit8($C3);                              { mov al,bl }
  BinEmit8($C0); BinEmit8($E8); BinEmit8($04);               { shr al,4 }
  BinEmit8($3C); BinEmit8($0A);                              { cmp al,10 }
  BinJccLabel(2,'_ue_h0');
  BinEmit8($04); BinEmit8($07);                              { add al,7 ('A'-'0'-10) }
  BinDefineLabel('_ue_h0');
  BinEmit8($04); BinEmit8($30);                              { add al,'0' }
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($47);
  { nibble bas }
  BinEmit8($8A); BinEmit8($C3);                              { mov al,bl }
  BinEmit8($24); BinEmit8($0F);                              { and al,0x0F }
  BinEmit8($3C); BinEmit8($0A);                              { cmp al,10 }
  BinJccLabel(2,'_ue_l0');
  BinEmit8($04); BinEmit8($07);
  BinDefineLabel('_ue_l0');
  BinEmit8($04); BinEmit8($30);
  BinEmit8($88); BinEmit8($07);                              { mov [edi],al }
  BinEmit8($47);
  BinJmpLabel('_ue_loop');
  BinDefineLabel('_ue_done');
  BinEmit8($C6); BinEmit8($07); BinEmit8($00);
  BinMovRegLabel(0,'_sas_strtmp');
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);               { pop edi,esi,ebx }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- Metadonnees dataset (retournent "" — aucune infrastructure dataset) }
  BinDefineLabel('_SASRT_varfmt');    BinJmpLabel('_sas_retempty2');
  BinDefineLabel('_SASRT_varinfmt');  BinJmpLabel('_sas_retempty2');
  BinDefineLabel('_SASRT_varlabel');  BinJmpLabel('_sas_retempty2');
  BinDefineLabel('_SASRT_varname');   BinJmpLabel('_sas_retempty2');
  { --- Attributs de variable (retournent "") }
  BinDefineLabel('_SASRT_vformat');    BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vformatn');   BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vformatnx');  BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vformatx');   BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vinformat');  BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vinformatn'); BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vinformatnx');BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vinformatx'); BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vlabel');     BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vlabelx');    BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vname');      BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vnamex');     BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vtype');      BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_vtypex');     BinJmpLabel('_sas_retempty1');
  { --- Codes postaux (sans table de donnees = "") }
  BinDefineLabel('_SASRT_zipname');    BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_zipnamel');   BinJmpLabel('_sas_retempty1');
  BinDefineLabel('_SASRT_zipstate');   BinJmpLabel('_sas_retempty1');
End;

{ ============================================================ }
{ TODO 24 — Runtime : fonctions de date integrees              }
{ Dates SAS = entier (jours depuis 01/01/1960).                }
{ Runtime date courant via GetLocalTime et conversions entieres. }
{ ============================================================ }
Procedure EmitRuntimeDateFunc;
Begin
  { --- _SASRT_today(): LongInt --- date SAS courante (jours depuis 01/01/1960) }
  { Formule JDN : SAS = floor(1461*(y'+4716)/4) + floor((153*(m'+1)+2)/5) + D - 2438472 }
  { Si mois<=2 : y'=annee-1, m'=mois+12. Constante B=-13 valide de 1900 a 2099.         }
  BinDefineLabel('_SASRT_today');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);               { push ebp ; mov ebp,esp }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);               { push ebx,esi,edi }
  BinPushLabel('_sas_systime');                               { push &systime }
  BinCallImport('_GetLocalTime@4');                           { call [GetLocalTime] }
  BinMovRegLabel(0, '_sas_systime');                          { mov eax,&systime }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($30);               { movzx esi,word[eax]   = wYear }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($48); BinEmit8($02);{ movzx ecx,word[eax+2] = wMonth }
  BinEmit8($0F); BinEmit8($B7); BinEmit8($58); BinEmit8($06);{ movzx ebx,word[eax+6] = wDay (ebx survit idiv) }
  { si mois<=2 : annee'=annee-1, mois'=mois+12 }
  BinEmit8($83); BinEmit8($F9); BinEmit8($02);               { cmp ecx,2 }
  BinEmit8($7F); BinEmit8($04);                               { jg .no_adj (skip 4 octets) }
  BinEmit8($4E);                                               { dec esi }
  BinEmit8($83); BinEmit8($C1); BinEmit8($0C);               { add ecx,12 }
  { .no_adj: term1 = floor(1461*(annee'+4716)/4) }
  BinEmit8($89); BinEmit8($F0);                               { mov eax,esi }
  BinEmit8($05); BinEmit8($6C); BinEmit8($12); BinEmit8($00); BinEmit8($00); { add eax,4716 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  { term2 = floor((153*(mois'+1)+2)/5) }
  BinEmit8($8D); BinEmit8($79); BinEmit8($01);               { lea edi,[ecx+1] }
  BinEmit8($69); BinEmit8($FF); BinEmit8($99); BinEmit8($00); BinEmit8($00); BinEmit8($00); { imul edi,edi,153 }
  BinEmit8($83); BinEmit8($C7); BinEmit8($02);               { add edi,2 }
  BinEmit8($50);                                               { push eax (sauvegarde term1) }
  BinEmit8($89); BinEmit8($F8);                               { mov eax,edi }
  BinEmit8($99);                                               { cdq }
  BinEmit8($BF); BinEmit8($05); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov edi,5 }
  BinEmit8($F7); BinEmit8($FF);                               { idiv edi (detruit edx) }
  BinEmit8($5F);                                               { pop edi (term1) }
  BinEmit8($01); BinEmit8($F8);                               { add eax,edi }
  { + jour(ebx) - 2438472 (= 2436935 + 1524 + 13, constante de la formule JDN) }
  BinEmit8($01); BinEmit8($D8);                               { add eax,ebx (jour, pas edx!) }
  BinEmit8($2D); BinEmit8($48); BinEmit8($35); BinEmit8($25); BinEmit8($00); { sub eax,2438472 }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B); BinEmit8($5D); { pop edi,esi,ebx,ebp }
  BinEmit8($C3);                                               { ret (0 arg) }

  { ============================================================ }
  { _SASRT_ymd_calc(date): helper interne --- decompose date SAS }
  { en annee/mois/jour (algorithme JDN inverse). Remplit         }
  { _sas_ymd[0]=year [4]=month [8]=day. Retourne year dans EAX. }
  { ~184 octets, stdcall 1 arg.                                  }
  { Formule: l=date+2505504; n=(4*l)/146097;                     }
  {   l=l-(146097*n+3)/4; i=(4000*(l+1))/1461001;               }
  {   l=l-(1461*i)/4+31; j=(80*l)/2447;                         }
  {   day=l-(2447*j)/80; l=j/11;                                 }
  {   month=j+2-12*l; year=100*(n-49)+i+l.                      }
  { Registres: esi=l, ebx=n, edi=i/puis j, ecx=diviseur.        }
  { Locaux: [ebp-4]=j/month [ebp-8]=day.                        }
  { ============================================================ }
  BinDefineLabel('_SASRT_ymd_calc');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);                { push ebp; mov ebp,esp }
  BinEmit8($83); BinEmit8($EC); BinEmit8($08);                { sub esp,8 (2 locaux) }
  BinEmit8($53); BinEmit8($56); BinEmit8($57);                { push ebx,esi,edi }
  { l = date + 2505504 (= 0x263B20) }
  BinEmit8($8B); BinEmit8($45); BinEmit8($08);                { mov eax,[ebp+8] }
  BinEmit8($05); BinEmit8($20); BinEmit8($3B); BinEmit8($26); BinEmit8($00); { add eax,2505504 }
  BinEmit8($89); BinEmit8($C6);                               { mov esi,eax (l) }
  { n = (4*l) / 146097 (= 0x23AB1) }
  BinEmit8($C1); BinEmit8($E0); BinEmit8($02);               { shl eax,2 }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($B1); BinEmit8($3A); BinEmit8($02); BinEmit8($00); { mov ecx,146097 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($89); BinEmit8($C3);                               { mov ebx,eax (n) }
  { l = l - (146097*n + 3)/4 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B1); BinEmit8($3A); BinEmit8($02); BinEmit8($00); { imul eax,146097 }
  BinEmit8($83); BinEmit8($C0); BinEmit8($03);               { add eax,3 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  BinEmit8($29); BinEmit8($C6);                               { sub esi,eax }
  { i = (4000*(l+1)) / 1461001 (= 0x164B09) }
  BinEmit8($8D); BinEmit8($46); BinEmit8($01);               { lea eax,[esi+1] }
  BinEmit8($69); BinEmit8($C0); BinEmit8($A0); BinEmit8($0F); BinEmit8($00); BinEmit8($00); { imul eax,4000 }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($09); BinEmit8($4B); BinEmit8($16); BinEmit8($00); { mov ecx,1461001 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($89); BinEmit8($C7);                               { mov edi,eax (i) }
  { l = l - (1461*i)/4 + 31 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  BinEmit8($29); BinEmit8($C6);                               { sub esi,eax }
  BinEmit8($83); BinEmit8($C6); BinEmit8($1F);               { add esi,31 }
  { j = (80*l) / 2447 (= 0x98F) }
  BinEmit8($6B); BinEmit8($C6); BinEmit8($50);               { imul eax,esi,80 }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($8F); BinEmit8($09); BinEmit8($00); BinEmit8($00); { mov ecx,2447 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);               { mov [ebp-4],eax (j) }
  { day = l - (2447*j)/80 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($8F); BinEmit8($09); BinEmit8($00); BinEmit8($00); { imul eax,2447 }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($50); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,80 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($F7); BinEmit8($D8);                               { neg eax }
  BinEmit8($01); BinEmit8($F0);                               { add eax,esi (l-result=day) }
  BinEmit8($89); BinEmit8($45); BinEmit8($F8);               { mov [ebp-8],eax (day) }
  { l_new = j/11 }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);               { mov eax,[ebp-4] (j) }
  BinEmit8($99);                                               { cdq }
  BinEmit8($B9); BinEmit8($0B); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov ecx,11 }
  BinEmit8($F7); BinEmit8($F9);                               { idiv ecx }
  BinEmit8($89); BinEmit8($C6);                               { mov esi,eax (l_new) }
  { month = j + 2 - 12*l_new }
  BinEmit8($8B); BinEmit8($45); BinEmit8($FC);               { mov eax,[ebp-4] (j) }
  BinEmit8($83); BinEmit8($C0); BinEmit8($02);               { add eax,2 }
  BinEmit8($6B); BinEmit8($D6); BinEmit8($0C);               { imul edx,esi,12 }
  BinEmit8($29); BinEmit8($D0);                               { sub eax,edx }
  BinEmit8($89); BinEmit8($45); BinEmit8($FC);               { mov [ebp-4],eax (month) }
  { year = 100*(n-49) + i + l_new }
  BinEmit8($89); BinEmit8($D8);                               { mov eax,ebx (n) }
  BinEmit8($83); BinEmit8($E8); BinEmit8($31);               { sub eax,49 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($64); BinEmit8($00); BinEmit8($00); BinEmit8($00); { imul eax,100 }
  BinEmit8($01); BinEmit8($F8);                               { add eax,edi (i) }
  BinEmit8($03); BinEmit8($C6);                               { add eax,esi (l_new): 03=ADD r32,r/m32 }
  { stocker dans _sas_ymd }
  BinMovRegLabel(7, '_sas_ymd');                               { mov edi,&_sas_ymd }
  BinEmit8($89); BinEmit8($07);                               { mov [edi],eax (year) }
  BinEmit8($8B); BinEmit8($55); BinEmit8($FC);               { mov edx,[ebp-4] (month) }
  BinEmit8($89); BinEmit8($57); BinEmit8($04);               { mov [edi+4],edx }
  BinEmit8($8B); BinEmit8($55); BinEmit8($F8);               { mov edx,[ebp-8] (day) }
  BinEmit8($89); BinEmit8($57); BinEmit8($08);               { mov [edi+8],edx }
  { retourner year dans EAX }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B);               { pop edi,esi,ebx }
  BinEmit8($89); BinEmit8($EC); BinEmit8($5D);               { mov esp,ebp; pop ebp }
  BinEmit8($C2); BinEmit8($04); BinEmit8($00);               { ret 4 }

  { --- _SASRT_mdy(m,d,y): LongInt --- date SAS depuis mois/jour/annee }
  { [ebp+8]=m [ebp+12]=d [ebp+16]=y. Formule JDN directe (85 octets). }
  BinDefineLabel('_SASRT_mdy');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($53); BinEmit8($56); BinEmit8($57);                { push ebx,esi,edi }
  BinEmit8($8B); BinEmit8($45); BinEmit8($10);               { mov eax,[ebp+16] year }
  BinEmit8($8B); BinEmit8($4D); BinEmit8($08);               { mov ecx,[ebp+8]  month }
  BinEmit8($8B); BinEmit8($5D); BinEmit8($0C);               { mov ebx,[ebp+12] day }
  BinEmit8($83); BinEmit8($F9); BinEmit8($02);               { cmp ecx,2 }
  BinEmit8($7F); BinEmit8($04);                               { jg .no_adj }
  BinEmit8($48);                                               { dec eax (year-1) }
  BinEmit8($83); BinEmit8($C1); BinEmit8($0C);               { add ecx,12 }
  { .no_adj: term1 = floor(1461*(year'+4716)/4) }
  BinEmit8($05); BinEmit8($6C); BinEmit8($12); BinEmit8($00); BinEmit8($00); { add eax,4716 }
  BinEmit8($69); BinEmit8($C0); BinEmit8($B5); BinEmit8($05); BinEmit8($00); BinEmit8($00); { imul eax,1461 }
  BinEmit8($C1); BinEmit8($F8); BinEmit8($02);               { sar eax,2 }
  { term2 = floor((153*month' - 457)/5)  [formule correcte Gregorienne] }
  { Variante (153*(month'+1)+2)/5 etait incorrecte pour Novembre/Decembre }
  BinEmit8($69); BinEmit8($F9); BinEmit8($99); BinEmit8($00); BinEmit8($00); BinEmit8($00); { imul edi,ecx,153 }
  BinEmit8($81); BinEmit8($EF); BinEmit8($C9); BinEmit8($01); BinEmit8($00); BinEmit8($00); { sub edi,457 }
  BinEmit8($50);                                               { push eax (term1) }
  BinEmit8($89); BinEmit8($F8);                               { mov eax,edi }
  BinEmit8($99);                                               { cdq }
  BinEmit8($BF); BinEmit8($05); BinEmit8($00); BinEmit8($00); BinEmit8($00); { mov edi,5 }
  BinEmit8($F7); BinEmit8($FF);                               { idiv edi }
  BinEmit8($5F);                                               { pop edi (term1) }
  BinEmit8($01); BinEmit8($F8);                               { add eax,edi }
  BinEmit8($01); BinEmit8($D8);                               { add eax,ebx (day) }
  BinEmit8($2D); BinEmit8($CE); BinEmit8($34); BinEmit8($25); BinEmit8($00); { sub eax,2438350 }
  BinEmit8($5F); BinEmit8($5E); BinEmit8($5B); BinEmit8($5D); { pop edi,esi,ebx,ebp }
  BinEmit8($C2); BinEmit8($0C); BinEmit8($00);               { ret 12 (3 args) }

  { --- _SASRT_year(d): LongInt --- annee via _SASRT_ymd_calc (15 octets) }
  BinDefineLabel('_SASRT_year');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);                { push dword [ebp+8] }
  BinCallLabel('_SASRT_ymd_calc');                             { EAX=year }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_month(d): LongInt --- mois via _SASRT_ymd_calc (23 octets) }
  BinDefineLabel('_SASRT_month');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);
  BinCallLabel('_SASRT_ymd_calc');
  BinMovRegLabel(7, '_sas_ymd');                               { mov edi,&_sas_ymd }
  BinEmit8($8B); BinEmit8($47); BinEmit8($04);               { mov eax,[edi+4] (month) }
  BinEmit8($5D); BinEmit8($C2); BinEmit8($04); BinEmit8($00);

  { --- _SASRT_day(d): LongInt --- jour via _SASRT_ymd_calc (23 octets) }
  BinDefineLabel('_SASRT_day');
  BinEmit8($55); BinEmit8($89); BinEmit8($E5);
  BinEmit8($FF); BinEmit8($75); BinEmit8($08);
  BinCallLabel('_SASRT_ymd_calc');
  BinMovRegLabel(7, '_sas_ymd');                               { mov edi,&_sas_ymd }
  BinEmit8($8B); BinEmit8($47); BinEmit8($08);               { mov eax,[edi+8] (day) }
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
