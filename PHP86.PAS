{ ============================================================
  PHP86.PAS - Compilateur PHP vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode)
            ParseArgs : analyser argv (fichier.php [sortie.asm] [-v] [-d])
            FatalError, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS PHP)
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_IDENT, TK_VAR (prefixe $), TK_KEYWORD, TK_OP, TK_PUNCT
            Balises PHP : <?php  ?>  (mode texte ignore sauf echo inline)
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString (guillemets simples et doubles avec interpolation)
            LexScanOp (. -> :: ===  !==  **  <=>  etc.)
            IsPhpKeyword : liste complete des mots-cles PHP
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux, hexadecimaux (0x), octaux (0), binaires (0b)
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines simple-quote : pas d'interpolation, sequences \\ et \'
            Chaines double-quote : interpolation de $var, sequences \n \t \r
            Heredoc / Nowdoc : syntaxe <<<LABEL et <<<'LABEL'
            true / false / null : constantes booleennes et null

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques   : + - * / % ** (puissance)
            Concatenation   : . et .=
            Comparaison     : == != === !== < <= > >= <=>
            Logiques        : && || ! and or not (deux niveaux de precedence)
            Bitwise         : & | ^ ~ << >>
            Ternaire        : cond ? a : b   et   expr ?: default (Elvis)
            Null-coalescing : ?? et ??=
            BinOpPrec : table de precedences Pratt pour ParseExprPrec

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_VAR (locale), SC_GLOBAL, SC_PARAM,
              SC_FN, SC_CLASS, SC_CONST
            TSymRec : Name, MangledName, Cat, TypeIdx, Offset, IsMut, IsRef
            SymAdd, SymFind, SymFindCat, SymMangle
            SymEnterScope / SymLeaveScope (gestion des portees imbriquees)
            Variables $var : le $ est consomme par le lexeur (TK_VAR)
            Constantes define() et const NAME = expr;

  TODO 06 - SYSTEME DE TYPES PHP
            TTypeKind : TKD_INT, TKD_FLOAT, TKD_STRING, TKD_BOOL,
              TKD_NULL, TKD_ARRAY, TKD_OBJECT, TKD_MIXED, TKD_VOID
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeFind, TypeSizeof (int=2o, string=ptr 2o, bool=1o)
            TypeMangle : nom mangle du type pour les labels ASM
            Promotion automatique : bool et null -> int sur la pile

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PHL_NNNNN)
            Prefixes : _PHV_ (var), _PHF_ (fn), _PHK_ (string), _PHRT_ (runtime)

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR), IntVal, StrVal
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd : enregistrer une entree dans DataTab
            EmitDataSeg : ecrire _DATA SEGMENT PUBLIC 'DATA' ... _DATA ENDS
            Chaines litterales echo "..." -> entree DK_STR automatique

  TODO 09 - VARIABLES ET AFFECTATIONS
            Variables locales $var : allouees sur la pile (SUB SP, 2)
            Variables globales : dans le segment DATA (DK_WORD)
            Affectation simple : $var = expr  -> ExprLoad + MOV [BP-n], AX
            Affectation par reference : $a = &$b  -> LEA + stockage pointeur
            global $var : lier au segment DATA depuis une fonction
            static $var : variable locale persistante entre appels

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, $var,
              operateurs unaires (- ! ~ ++ -- pre/post),
              groupement parenthese,
              cast (int) (string) (bool) (float)
            ExprMakeImm, ExprMakeNone : constructeurs TExprVal (Var Res)
            ExprLoad : materialiser la valeur dans AX

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
            ParseExprPrec(MinPrec, Var Res) : boucle Pratt
            ExprEmitBinOp : ADD/SUB/IMUL/IDIV, CMP+SETcc, AND/OR/XOR
            Concatenation . : appel _PHRT_CONCAT(SI=buf, DI=src, CX=len)
            Ternaire cond ? a : b : emission avec labels _PHL_TERN_N
            Null-coalescing ?? : test EK_NONE et branchement

  TODO 12 - ECHO / PRINT / VAR_DUMP
            ParseEchoStmt : echo $a, "str", 42; (liste d'expressions)
            Chaines constantes : MOV SI, OFFSET lbl + CALL _PHRT_PRINT
            Entiers : CALL _PHRT_ITOA puis _PHRT_PRINT
            print expr ; (une seule expression, retourne 1)
            var_dump(expr) : emet le type et la valeur (mode debug)
            Retour a la ligne implicite de println / echo "...\n"

  TODO 13 - IF / ELSEIF / ELSE
            ParseIfStmt : if (cond) BLOC [elseif (cond) BLOC]* [else BLOC]
            Labels _PHL_ELSEIF_N, _PHL_ELSE_N, _PHL_ENDIF_N
            Condition : ExprLoad + TEST AX, AX + JZ/JNZ
            if (isset($v)) et if (is_null($v)) : cas speciaux optimises
            Syntaxe alternative : if (): ... endif;

  TODO 14 - BOUCLES : while / do..while / for
            ParseWhileStmt : while (cond) BLOC
            ParseDoWhileStmt : do BLOC while (cond);
            ParseForStmt : for (init; cond; incr) BLOC (3 parties separees)
            LoopPush / LoopPop : pile de labels break/continue
            break N et continue N : sortie de N niveaux de boucle
            Syntaxes alternatives : while (): ... endwhile; etc.

  TODO 15 - FOREACH
            ParseForeachStmt : foreach ($arr as $val) et as $key => $val
            Tableaux indexes simples : iteration sur [0..n-1]
              MOV CX, taille / boucle INC index / acces $arr[idx]
            Variable de cle $k : entier incrementiel sur la pile
            break et continue dans foreach

  TODO 16 - SWITCH / CASE / DEFAULT
            ParseSwitchStmt : switch (expr) { case lit: ... default: ... }
            Sujet evalue dans BX (une seule fois avant la table)
            Chaque case : CMP BX, val + JNE suivant
            Fall-through naturel : pas de JMP entre cases consecutifs
            break obligatoire pour sortir, default en dernier
            Syntaxe alternative : switch (): ... endswitch;

  TODO 17 - FONCTIONS
            ParseFnDecl : function name($p1, $p2 = def, ...$rest)
            Parametres par defaut : test AX avec valeur sentinelle
            Parametres variadiques ...$args : non pris en charge (warning)
            Parametres par reference &$param : IsRef = True
            Valeur de retour : return expr; -> AX ou pile selon taille
            Fonctions anonymes / lambdas : function() use($x) {} (simplifie)
            ParseCallArgs, EmitCallSite (cdecl 16 bits)

  TODO 18 - PORTEE, PILE ET CADRES
            CurFrameSize : taille incrementale du cadre local
            Prologue : PUSH BP / MOV BP, SP
            Epilogue : MOV SP, BP / POP BP / RET
            Variables locales : SUB SP, 2 par $var declare
            Parametres : [BP+4] premier, [BP+6] deuxieme, ...
            Fermeture de portee : SymLeaveScope + restauration SP

  TODO 19 - TABLEAUX PHP
            array() et syntaxe courte [] : tableaux indexes
            Representation : pointeur vers bloc memoire en DATA ou pile
            Acces $a[i] (i constant) : calcul offset + MOV
            count($a) : retourne la taille stockee en [ptr-2]
            array_push($a, v) : appel _PHRT_ARRAY_PUSH
            Tableaux associatifs : keys dans DATA (non pris en charge, warning)

  TODO 20 - FONCTIONS INTEGREES (BUILTINS)
            strlen($s) -> CALL _PHRT_STRLEN (retourne CX puis AX)
            intval($s) -> CALL _PHRT_ATOI
            strval($n) -> CALL _PHRT_ITOA
            isset($v)  -> test EK_NONE dans SymTab (bool AX)
            is_null($v)-> idem
            defined(NAME) -> recherche dans SymTab constantes
            abs($n), min($a,$b), max($a,$b) -> implementation inline
            die/exit : MOV AX, 4C00h + INT 21h

  TODO 21 - CLASSES PHP (BASIQUE)
            ParseClassDecl : class Name [extends Parent] { membres }
            Proprietes : public/protected/private $prop = val
            Methodes : fonction avec $this implicite comme premier parametre
            new ClassName(args) : allocation sur la pile (taille fixe compile)
            Acces $obj->prop et $obj->method() : offset compile
            Pas d'heritage dynamique (avertissement si extends non trivial)

  TODO 22 - RUNTIME MINIMAL
            _PHRT_PRINT(SI=msg, CX=len) : INT 21h AH=40h BX=1
            _PHRT_PRINTLN : _PHRT_PRINT + emet Chr(13)+Chr(10)
            _PHRT_ITOA(AX=n, DI=buf) : conversion entier -> chaine ASCII
            _PHRT_STRLEN(SI=str) : compte octets jusqu'a 0 -> AX
            _PHRT_CONCAT(DI=dst, SI=src) : copie src dans dst
            _PHRT_PANIC(SI=msg) : affiche message + INT 21h AH=4Ch AL=1
            RuntimeEmitted : flag pour n'emettre le runtime qu'une fois

  TODO 23 - INCLUDE / REQUIRE
            ParseIncludeStmt : include / require / include_once / require_once
            Resolution du chemin au moment de la compilation (chemin relatif)
            Ouverture et analyse du fichier inclus comme sous-compilation
            Symboles du fichier inclus ajoutes a la table courante
            Garde d'inclusion unique (_once) : table des fichiers deja inclus
            Erreur fatale si require echoue ; avertissement pour include

  TODO 24 - PREPROCESSEUR ET CONSTANTES
            define('NOM', val) : ajout SC_CONST dans SymTab
            const NOM = val ; (niveau global et dans les classes)
            Macros PHP_INT_MAX, PHP_EOL, PHP_OS : constantes predefinis
            PHP_EOL -> entree DK_STR avec Chr(13)+Chr(10)
            Conditionnels : if (defined('NOM')) -> evaluation au compile
            __LINE__, __FILE__, __FUNCTION__ : constantes magiques

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT
            Run : pipeline complet LexInit -> parse -> EmitRuntime ->
              _TEXT ENDS / EmitDataSeg / END _PHF_main
            Fichiers SAMPLES\PHP\ a creer :
              hello.php   (echo, variables, concatenation)
              math.php    (fonctions, arithmetique, return)
              control.php (if/elseif/else, while, for, switch)
              array.php   (tableaux, foreach, count, array_push)
            Smoke tests : RUST86.EXE -v SAMPLES\PHP\*.php
  ============================================================ }

Program PHP86;
Begin
End.
