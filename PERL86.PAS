(* ============================================================
  PERL86.PAS - Compilateur Perl vers assembleur 8086
  Turbo Pascal / Free Pascal (-Mtp)
  Cible : MASM .MODEL SMALL, DOS 16 bits

  FEUILLE DE ROUTE - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE ET OPTIONS
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Strict, Warnings)
            ParseArgs : analyser argv (script.pl [sortie.asm] [-v] [-d] [-w])
            FatalError, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Shebang : ignorer la premiere ligne #!/usr/bin/perl ou #!/usr/bin/env perl
            Programme principal : validation des arguments et appel Run

  TODO 02 - LEXEUR (TOKENS PERL)
            TTokenKind : TK_EOF, TK_INTEGER, TK_FLOAT, TK_STRING,
              TK_HEREDOC, TK_REGEXP, TK_IDENT, TK_SCALAR ($), TK_ARRAY (@),
              TK_HASH (%), TK_KEYWORD, TK_OP, TK_PUNCT, TK_FILEHANDLE
            Sigils : $ @ % reconnus et consommes comme prefixe de token
            LexInit, LexClose, LexNextToken, LexScanIdent, LexScanNumber
            LexScanString : simple-quote (\\ \'), double-quote (interpolation
              de $var @arr et sequences \n \t \r \0 \x1B), backtick (`)
            LexScanRegexp : /pattern/flags apres =~ ou m// ou s///replacement/flags
            Commentaires : # jusqu'a fin de ligne  (pas de /* */ en Perl)
            IsKeyword : liste complete my our local sub use require package
              if elsif else unless while until for foreach do last next redo
              return print say printf sprintf die exit wantarray chomp chop
            Mode debug -d : affichage de chaque token avec PrintToken

  TODO 03 - LITTERAUX ET CONSTANTES
            Entiers decimaux, hexadecimaux (0x), octaux (0), binaires (0b)
            Separateurs numeriques : 1_000_000 -> 1000000
            Flottants : reconnus par le lexeur, traites comme entiers (trunc)
            Chaines simple-quote : pas d'interpolation, uniquement \\ et \'
            Chaines double-quote : interpolation de $scalaire, @tableau
              (liste entre parens), sequences \n \t \r \f \e \0 \xNN \cX
            Backtick ` : commande systeme, non supporte -> warning + chaine vide
            Heredoc : <<LABEL / <<"LABEL" (interpolation) / <<'LABEL' (literal)
              Fin au label seul en debut de ligne
            Expressions qw() : liste de mots separes par espaces -> tableau litteral
            true / false / undef : constantes booleennes et valeur indefinie

  TODO 04 - OPERATEURS ET PRECEDENCE
            Arithmetiques   : + - * / % ** (puissance)
            Concatenation   : . et .=
            Repetition      : x et x= ($str x 3 / @arr x 2)
            Comparaison num : == != < <= > >= <=> (spaceship)
            Comparaison str : eq ne lt le gt ge cmp
            Logiques haute  : && || // (or-defined) ! (precedence C)
            Logiques basse  : and or not (precedence tres basse)
            Bitwise         : & | ^ ~ << >>
            Ternaire        : cond ? a : b
            Plage           : .. et ... (range dans for/foreach)
            Assignation     : = += -= *= /= %= .= //= &&= ||= x=
            BinOpPrec : table de precedences Pratt adaptee a Perl

  TODO 05 - TABLE DES SYMBOLES
            TSymCat : SC_SCALAR, SC_ARRAY_VAR, SC_HASH_VAR,
              SC_PARAM, SC_FN, SC_PKG, SC_CONST, SC_FILEHANDLE
            TSymRec : Name, SigilName (avec $/@/%), MangledName, Cat,
              TypeIdx, Offset, IsMy, IsOur, IsLocal, IsRef
            SymAdd, SymFind, SymFindCat, SymMangle
            Portee lexicale my : SymEnterScope / SymLeaveScope
            Portee dynamique local : sauvegarde de la valeur sur la pile
            Portee globale our : pointeur vers la table du package courant
            use strict -> activation du mode strict (toute var doit etre declaree)
            use constant NOM => val : ajout SC_CONST dans SymTab

  TODO 06 - SYSTEME DE TYPES ET CONTEXTE
            TTypeKind : TKD_SCALAR (int/float/str unifie), TKD_ARRAY,
              TKD_HASH, TKD_REF, TKD_CODE, TKD_UNDEF, TKD_FILEHANDLE
            TypeTab, TypeInit : enregistrer les types primitifs
            TypeSizeof : scalar=2o (ptr ou int), ref=2o, array=ptr 2o
            Contexte scalaire vs liste : distinction a la compilation
              scalaire(@arr) -> nombre d'elements ; @arr dans liste -> elements
            Context booleen : 0, "", "0", undef = faux ; tout autre = vrai
            TypeMangle : nom mangle du type pour les labels ASM

  TODO 07 - EMETTEUR DE CODE ASM
            TEmitter : OutF (Text), OutFOpen, EmitOpen, EmitClose
            EmitRaw, EmitLabel, EmitInstr (formatage 8 espaces)
            EmitComment, EmitBlankLine
            LabelGen global (compteur unique _PRL_NNNNN)
            Prefixes : _PRV_ (variable), _PRF_ (sub/fonction),
              _PRK_ (constante chaine), _PRRT_ (runtime), _PRL_ (label)
            EmitHeader : .MODEL SMALL / .STACK 1024 / _TEXT SEGMENT

  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
            TDataRec : LblName, Kind (DK_WORD/DK_BYTE/DK_STR/DK_ARRAY),
              IntVal, StrVal, ElemCount
            DataTab[0..MAX_DATA-1], DataCount
            DataAdd : enregistrer une entree dans DataTab
            EmitDataSeg : ecrire _DATA SEGMENT ... _DATA ENDS
            Chaines litterales -> entree DK_STR automatique (terminateur 0)
            Variables globales our/use : entrees DK_WORD dans DataTab
            Constantes use constant : entrees DK_WORD ou DK_STR

  TODO 09 - VARIABLES ET AFFECTATIONS
            Scalaires my $var : alloues sur la pile (SUB SP, 2)
            Scalaires our $var : dans le segment DATA (DK_WORD)
            Affectation simple : $var = expr -> ExprLoad + MOV [BP-n], AX
            Operateurs composes : += -= *= .= etc. -> load/op/store
            Affectation de liste : ($a, $b) = ($b, $a) -> via pile temporaire
            local $var : sauvegarde de la valeur globale avant modif, restaure
            Dereferencement d'affectation : $$ref = expr ; @$ref = liste
            Affectation en chaine : $a = $b = expr -> associatif droite

  TODO 10 - EXPRESSIONS PRIMAIRES
            ParsePrimary : literal entier, literal chaine, $scalaire,
              @tableau (contexte liste), %hash (contexte hash),
              operateurs unaires (- ! ~ ++ -- pre/post), not, defined($v)
            Groupement parenthese, liste (a, b, c)
            ref($v) -> retourne chaine du type ; \$v -> reference scalaire
            undef : constante -> AX=0 ; defined($v) : test pointeur non nul
            Appel de sous-routine : nomSub(args) ou &nomSub(args)
            ExprMakeImm, ExprMakeNone, ExprMakeUndef : constructeurs TExprVal

  TODO 11 - EXPRESSIONS BINAIRES (PRATT)
            ParseExprPrec(MinPrec, Var Res) : boucle Pratt complete
            ExprEmitBinOp : ADD/SUB/IMUL/IDIV/REM, CMP+SETcc, AND/OR/XOR
            Concatenation . : appel _PRRT_CONCAT(DI=dst, SI=src)
            Repetition x : boucle inline ou appel _PRRT_STRREPEAT
            Spaceship <=> : CMP + SETL/SETE/SETG -> AX=-1/0/1
            Operateur // (defined-or) : test EK_UNDEF puis branchement
            Ternaire cond ? a : b : emission avec labels _PRL_TERN_N

  TODO 12 - PRINT / SAY / PRINTF / SPRINTF / WARN / DIE
            ParsePrintStmt : print LIST; print FILEHANDLE LIST;
            say LIST : identique a print avec \n final automatique
            printf FORMAT, LIST : interpretation du format simplifie
              %d -> CALL _PRRT_ITOA  %s -> chaine directe  %% -> '%'
            sprintf FORMAT, LIST : meme logique, retourne chaine (buffer)
            warn MSG : affiche sur STDERR (INT 21h BX=2)
            die MSG : affiche + exit code 255
            Filehandles STDOUT / STDERR / STDIN : BX=1/2/0 dans INT 21h

  TODO 13 - IF / ELSIF / ELSE / UNLESS + MODIFICATEURS DE STATEMENT
            ParseIfStmt : if (cond) BLOC [elsif (cond) BLOC]* [else BLOC]
            unless (cond) BLOC [else BLOC] : condition inversee
            Labels _PRL_ELSIF_N, _PRL_ELSE_N, _PRL_ENDIF_N
            Modificateurs de fin de statement : expr if cond ;
              expr unless cond ; expr while cond ; expr until cond ;
              expr for LIST ; expr foreach LIST ;
            Traduction en IF/WHILE inline avec label court

  TODO 14 - BOUCLES : while / until / for / foreach / do+while
            ParseWhileStmt : while (cond) { BLOC } [continue { BLOC }]
            ParseUntilStmt : until (cond) BLOC (condition inversee)
            ParseForStmt : for (init; cond; incr) BLOC (style C)
            ParseForeachStmt : foreach my $elem (LIST) { BLOC }
              Plage : foreach (A..B) -> iteration [A,B] incremental
            do { BLOC } while (cond) et do { BLOC } until (cond)
            LoopPush / LoopPop : pile de labels last/next
            last [LABEL], next [LABEL], redo [LABEL] :
              last = break, next = continue, redo = recommence sans retest
            Labels de boucle : BOUCLE: while { ... }

  TODO 15 - TABLEAUX (@array)
            Declaration : my @arr et initialisation my @arr = (1,2,3)
            Representation memoire : entete [count:word] suivi des elements
            Acces $arr[i] (i constant ou expr) : calcul offset, MOV/CMP
            Acces $arr[-1] : index negatif -> count+index
            Affectation $arr[i] = expr
            push @arr, val : CALL _PRRT_PUSH (realloc non supporte, taille fixe)
            pop @arr, shift @arr, unshift @arr, val
            scalar(@arr) -> AX = count ; wantarray -> AX = 0 (contexte)
            Slices @arr[1,2,3] : avertissement + acces sequentiel
            reverse, sort (tri numerique/alphabetique inline ou builtins)

  TODO 16 - HASHES (%hash)
            Declaration : my %h et initialisation my %h = (cle => val, ...)
            Representation : paires cle/valeur dans DATA (taille fixe a compile)
            Acces $h{key} (cle constante chaine) : offset precompile
            Acces $h{$k} (cle variable) : linearisation sequentielle + CMP
            Affectation $h{key} = expr
            exists $h{key} : recherche et retourne bool -> AX
            delete $h{key} : mise a zero de la valeur (cle conservee)
            keys %h, values %h -> liste en contexte liste
            each %h -> paires ($k, $v) en iteration
            Hashes profonds (reference) : avertissement, non pris en charge

  TODO 17 - SOUS-ROUTINES (sub)
            ParseSubDecl : sub nom PROTO BLOC et sub nom { BLOC }
            Signature @_ : tableau des arguments passes par l'appelant
              my ($a, $b) = @_; -> shift de @_ dans les parametres locaux
            Prototypes sub nom ($$$) : verification d'arite (warning seulement)
            Valeur de retour : return expr; ou derniere expr evaluee -> AX
            Contexte de retour : wantarray() -> 0 (scalaire) dans impl. simplifiee
            Sous-routines anonymes : my $f = sub { BLOC }; -> pointeur code
            Appel : $f->() ou &$f() ; dereferencer pointeur + CALL AX
            ParseCallArgs, EmitCallSite : convention cdecl 16 bits
            sub BEGIN, END : executes au compile/fin (stub ou avertissement)

  TODO 18 - PORTEE, PILE ET CADRES
            Convention d'appel : cdecl 16 bits, args de gauche a droite
            Prologue sous-routine : PUSH BP / MOV BP, SP
            Epilogue : MOV SP, BP / POP BP / RET N
            Variables my : allouees sur la pile (SUB SP, 2 par scalaire)
            Arguments @_ : adresses des args sur la pile, copie dans locaux
            Fermeture de portee : SymLeaveScope + restauration SP
            Sauvegarde registres : SI, DI, ES preserves dans sub (si utilises)
            CurFrameSize : taille courante du cadre local

  TODO 19 - EXPRESSIONS REGULIERES (basique)
            TRegexpRec : Pattern, Flags (g i m s x)
            $str =~ /pattern/ : emission de CALL _PRRT_REMATCH(SI,DI) -> AX
            $str =~ s/pattern/replacement/ : CALL _PRRT_RESUB -> AX
            $str =~ tr/chars/chars/ : CALL _PRRT_TRANSLITERATE
            $str !~ /pattern/ : negation du resultat
            Captures $1 $2 : variables globales _PRCAP_1 _PRCAP_2 dans DATA
            Support minimal : pattern fixe (chaine litterale sans meta)
            Patterns avec metacaracteres ^ $ . * + ? : avertissement complexite

  TODO 20 - FONCTIONS INTEGREES (BUILTINS)
            length($s) -> CALL _PRRT_STRLEN -> AX
            substr($s, off [, len]) -> CALL _PRRT_SUBSTR
            index($s, $sub [, pos]) -> CALL _PRRT_INDEX -> AX (ou -1)
            rindex($s, $sub [, pos]) -> CALL _PRRT_RINDEX -> AX
            uc($s), lc($s), ucfirst, lcfirst -> CALL _PRRT_UC / _LC
            chomp($s) : supprime \n final ; chop($s) : supprime dernier char
            split(/pat/, $str) -> tableau (taille fixe) ; join($sep, @arr)
            int($n), abs($n), sprintf("%d", $n)
            hex($s), oct($s) -> conversion de base -> AX
            chr($n) -> char ; ord($s) -> AX
            defined($v) -> AX=0/1 ; undef($v) -> mise a zero

  TODO 21 - PACKAGES ET MODULES (basique)
            ParsePackageDecl : package NomModule; -> nouveau namespace
            use strict -> active SC_STRICT : toute var doit etre declaree
            use warnings -> active SC_WARNINGS : active les avertissements
            use constant NOM => val -> ajout SC_CONST dans SymTab
            use POSIX () -> avertissement, non pris en charge
            require 'fichier.pl' -> include conditionnel (comme PHP require)
            do 'fichier.pl' -> execute fichier dans la portee courante
            BEGIN { } / END { } : blocs speciaux -> executes en phase parse
              BEGIN : evaluation immediate (constantes only) ; END : stub

  TODO 22 - REFERENCES ET DEREFERENCEMENT
            Constructeur de reference : \$scalar -> MOV AX, offset [BP-n]
              \@arr -> MOV AX, OFFSET _PRV_arr  \%hash -> idem
              \&sub -> MOV AX, OFFSET _PRF_sub
            Dereferencement scalaire : $$ref, ${$ref} -> MOV AX, [BX]
            Dereferencement tableau : @$ref, @{$ref} -> utiliser ptr comme base
            Dereferencement hash : %$ref, %{$ref}
            Operateur fleche : $ref->[$i], $ref->{key}, $ref->()
            Tableaux de references : @aoa (array of arrays) -> avertissement
            Hashes de references : %hoh -> avertissement
            Verification ref($v) -> chaine 'SCALAR'/'ARRAY'/'HASH'/'CODE'

  TODO 23 - I/O FICHIERS (basique)
            open(my $fh, '<', 'fichier.txt') -> INT 21h AH=3Dh
            open(my $fh, '>', 'fichier.txt') -> INT 21h AH=3Ch (creation)
            open(my $fh, '>>', 'fichier.txt') -> INT 21h AH=3Dh mode append
            close($fh) -> INT 21h AH=3Eh
            print $fh, LIST -> INT 21h AH=40h BX=handle
            readline($fh) / <$fh> -> CALL _PRRT_READLINE -> AX=ptr
            eof($fh) -> AX=1 si fin de fichier (INT 21h AH=3Fh = 0 octets)
            Modes non supportes : pipe, socket -> avertissement

  TODO 24 - RUNTIME MINIMAL
            _PRRT_PRINT(BX=handle, SI=msg, CX=len) : INT 21h AH=40h
            _PRRT_PRINTLN : _PRRT_PRINT + emet CR+LF
            _PRRT_ITOA(AX=n, DI=buf) : conversion entier -> chaine ASCII
            _PRRT_STRLEN(SI=str) : compte octets jusqu'a 0 -> AX et CX
            _PRRT_CONCAT(DI=dst, SI=src) : copie src dans dst (strcat)
            _PRRT_STRREPEAT(DI=dst, SI=src, CX=n) : repete src n fois
            _PRRT_REMATCH(SI=str, DI=pat) : recherche pattern fixe -> AX
            _PRRT_RESUB(SI=str, DI=pat, BX=repl) : substitution -> AX
            _PRRT_PUSH(SI=arr_ptr, AX=val) : pousse val dans tableau (fixe)
            _PRRT_INDEX(SI=str, DI=sub) : position -> AX (-1 si absent)
            _PRRT_PANIC(SI=msg) : affiche msg + MOV AX,4C01h + INT 21h
            RuntimeEmitted : flag pour n'emettre le runtime qu'une fois

  TODO 25 - GENERATION FINALE ET FICHIERS EXEMPLES
            EmitClose : END _PRF_main dans _TEXT ENDS / DATA ENDS
            Run : pipeline complet LexInit -> ParseStmt loop ->
              EmitRuntime -> _TEXT ENDS / EmitDataSeg / END _PRF_main
            Fichiers SAMPLES\PERL\ a creer :
              hello.pl    (print, variables scalaires, concatenation, say)
              math.pl     (sous-routines, arithmetique, return, recursion)
              control.pl  (if/elsif/else/unless, while, for, foreach, last/next)
              arrays.pl   (tableaux, push/pop/shift, foreach, sort, reverse)
              hashes.pl   (hashes, keys/values, exists/delete, each)
              regex.pl    (=~ correspondance et substitution simples)
            Smoke tests : PERL86.EXE -v SAMPLES\PERL\*.pl

  ============================================================ *)

{ ============================================================
  PERL86 - Compilateur Perl -> assembleur 8086
  Version : 1.0  Date : 2026-03-05
  Compilation : ppc386 -O2 -Mtp PERL86.PAS
  ============================================================ }

Program PERL86;

Begin
End.
