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
  TOK_LBRACE    = 14;   { { }
  TOK_RBRACE    = 15;   { } }
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
  CurTokType     : Integer;
  CurTokStr      : String;

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

{ TODO 08 : Table des symboles }
Function  FindSym(Const Name: String; Kind: Integer): Integer; Forward;
Function  AddSym(Const Name: String; Kind: Integer): Integer;  Forward;
Function  GetOrAddVar(Const Name: String;
                      IsChar: Boolean): Integer;               Forward;
Function  GetOrAddDataset(Const Name: String): Integer;        Forward;

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
Procedure BinAddEspImm8(N: Integer);                           Forward;
Procedure BinCallLabel(Const Name: String);                    Forward;
Procedure BinCallImport(Const FuncName: String);               Forward;
Procedure BinJmpLabel(Const Name: String);                     Forward;
Procedure BinJccLabel(CC: Integer; Const Name: String);        Forward;
Procedure EmitRuntimeIO;                                       Forward;

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
  CurLineNum     := 0;
  LexEOF         := False;
  LexLine        := '';
  LexLineLen     := 0;
  LexPos         := 1;
  LexInComment   := False;
  LexAtStmtStart := True;
  CurTokType     := TOK_EOF;
  CurTokStr      := '';
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

Procedure ParseProgram;
Begin
  { TODO 06 }
End;

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
  I := FindSym(Name, SK_NONE);
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
Var I: Integer;
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
  GetOrAddDataset := DsCount;
  Inc(DsCount);
End;

Procedure CodegenProgram;
Begin
  { TODO 25 }
End;

Procedure WritePE(Const FileName: String);
Begin
  { TODO 25 }
End;

Procedure WriteCOFF(Const FileName: String);
Begin
  { TODO 25 }
End;

Procedure WriteASM(Const FileName: String);
Begin
  { TODO 25 }
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

Procedure EmitRuntimeIO;
Begin
  { TODO 15 }
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }
Var
  I        : Integer;
  Arg      : String;
  ExpandedSrc : String;

Begin
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
End.
