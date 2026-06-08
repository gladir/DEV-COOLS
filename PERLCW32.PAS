{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Perl vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program PERLCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  PERLCW32.PAS - Compilateur Perl vers assembleur 80386 pour
  Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte tous les exemples SAMPLES\PERL\*.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, StrictMode, LoadPath)
            ParseArgs : argv source.pl [-o out] [-v] [-d] [-w]
              [-obj] [-asm] [-h]
            Defaut : produire .EXE PE Win32 ; -obj : .OBJ COFF ;
              -asm : aussi .ASM lisible ; -o : nom de sortie
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter extensions .pl / .pm / .perl
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_IMG_BASE ($00400000),
              PE_SEC_ALIGN (4096), PE_FILE_ALIGN (512),
              PE_SUBSYS_CUI / PE_SUBSYS_GUI
            Limites : MAX_SYM=4096, MAX_SUB=512, MAX_LOCAL=256,
              MAX_PARAM=64, MAX_LABEL=4096, MAX_REGEX=256,
              MAX_FORMAT=128, MAX_STR=255, MAX_ERRORS=30
            Prefixes ASM : _PL_ (gvar $), _PLF_ (sub),
              _PLK_ (str), _PLRT_ (runtime), _PLL_ (label),
              _PLA_ (array @), _PLH_ (hash %), _PLRE_ (regex),
              _PLPKG_ (package)

  TODO 02 - TOKENISEUR PERL (LEXER)
            LexInit (gerer shebang #!/usr/bin/perl), LexClose,
              LexNextChar, LexPeekChar, LexPeekChar2, LexNextToken
            Identificateurs : lettres, chiffres, _ ; sensibles a la
              casse ; sigils $ @ % & *
            Numeriques : 123, 1_000, 1.5, 1.5e3, 0xFF, 0o77, 0b101,
              0777 (octal legacy) ; suffixe L/U ignore (compatibilite)
            Chaines simples 'x' (echappement \\ \' uniquement)
            Chaines doubles "x $var @arr" (interpolation, \n \t \r
              \0 \xFF \x{FFFF} \N{name} \cX \l \u \L \U \E \Q)
            Heredoc <<EOF, <<'EOF' (litteral), <<"EOF" (interpole),
              <<~EOF (squiggly retire indentation commune)
            Expressions regulieres : /pattern/flags, m/pat/flags,
              s/pat/rpl/flags, tr/list/list/flags, qr/pat/flags
            Litteraux : q{...} qq{...} qw(...) qx{...} qr/.../
            Commentaires : # jusqu en fin de ligne
            Operateurs :
              Arithmetiques : + - * / % ** ++ --
              Chaines : . x .= x=
              Bit : & | ^ ~ << >>
              Logique : && || ! not and or ; // (defini-ou)
              Comparaison num : == != < > <= >= <=>
              Comparaison str : eq ne lt gt le ge cmp
              Affectation : = += -= *= /= %= **= .= x=
                &&= ||= //= &= |= ^= <<= >>=
              Fleche : -> ; Virgule epaisse : =>
              Gamme : .. ...
              Ternaire : ?:
              Regex : =~ !~
              Ref : \ ; Deref : ${ } @{ } %{ } &{ }
            Types token : TOK_IDENT, TOK_SIGIL_SCALAR, TOK_SIGIL_ARRAY,
              TOK_SIGIL_HASH, TOK_SIGIL_CODE, TOK_INTEGER, TOK_FLOAT,
              TOK_STRING, TOK_DSTRING, TOK_HEREDOC, TOK_REGEX,
              TOK_SUBST, TOK_TRANS, TOK_QWORD, TOK_DOTDOT,
              TOK_DOTDOTDOT, TOK_SPACESHIP, TOK_CMP, TOK_FATCOMMA,
              TOK_DEFOR, TOK_MATCH, TOK_NMATCH, TOK_EOF

  TODO 03 - MOTS-CLES ET FONCTIONS INTEGREES PERL
            IsKeyword(s : String) : Integer
            Reserves : and BEGIN CORE DESTROY do else elsif END
              eq eval for foreach format ge goto gt if last le
              local lt my ne next no not or our package pop print
              printf push redo return reverse scalar shift sort
              sprintf sub tie tied unless until use values wantarray
              while x xor
            Pseudo-mots-cles / fonctions globales importantes :
              abs atan2 binmode chdir chmod chomp chop chr closedir
              cos defined delete die eof eval exec exists exp
              getc goto hex index int join keys kill length lc
              lcfirst log map oct open opendir ord pop pos print
              printf push rand read readdir readline rename
              reset reverse rewinddir rindex scalar seek seekdir
              sin sleep sort splice sprintf sqrt srand stat study
              substr tie time times uc ucfirst unlink unshift
              untie utime values warn write
            Fichiers de test couverts :
              use strict (TODO 23), use warnings (TODO 23),
              abs (math.pl), push/scalar/foreach (arrays.pl),
              exists/delete (hashes.pl), print/. /x (hello.pl)

  TODO 04 - TYPES SCALAIRES ET REPRESENTATION RUNTIME
            Scalaire Perl : valeur peut etre nombre OU chaine
              (dualvar), undef, reference
            Representation 32 bits (tagged) :
              Entier 31 bits : ((n shl 1) or 1)
              Undef : 0x00000000
              Flottant IEEE 754 : ptr heap (RT_FLOAT)
              Chaine : ptr heap (RT_STRING, buf, len, cap)
              Reference : ptr heap (RT_REF, pointee_ptr)
            TPerlVal (union Pascal : tag + data)
            Coercions automatiques :
              str->num : leading digits, oct/hex prefixe 0/0x
              num->str : sprintf "%g" ou "%d" selon valeur
              undef->num : 0 ; undef->str : ""
              Warnings si -w ou use warnings
            Contexte scalaire (demande une valeur) vs liste
              (demande une liste) determine a la compilation
            Fonctions de coercion runtime :
              _PLRT_to_num, _PLRT_to_str, _PLRT_to_bool,
              _PLRT_is_undef, _PLRT_to_int

  TODO 05 - VARIABLES : SCALAIRES, TABLEAUX, HASHES, LOCALES, GLOBALES
            Scalaires : $name, $name[i] (elem tableau),
              $name{key} (elem hash), $#name (dernier index)
            Tableaux : @name, @name[list] (slice), @name{list}
              (hash slice)
            Hashes : %name, %name{list}
            my $x : lexicale, portee bloc/sub (la plus courante)
            our $x : package global (visible partout dans package)
            local $x : dynamique (save/restore autour d un bloc)
            Portees : fichier, sous-routine, bloc if/while/for
            TSym (Name, Kind, SigilType, Scope, Offset, Package)
              Kinds : SK_SCALAR, SK_ARRAY, SK_HASH, SK_CODE,
                SK_FORMAT, SK_GLOB
              Scopes : SCOPE_LEXICAL, SCOPE_PACKAGE, SCOPE_DYNAMIC
            FindSym, AddSym, EnterScope, LeaveScope
            Variables speciales reservees : voir TODO 18
            Package courant : $CurrentPackage (defaut 'main')
            Symbol table par package : %main::, %Foo::

  TODO 06 - PARSEUR D'EXPRESSIONS (PRECEDENCE PERL)
            ParseExpr -> ParseDefOr -> ParseTernary -> ParseOr
              -> ParseAnd -> ParseNot -> ParseComparison
              -> ParseRange -> ParseAdd -> ParseMul -> ParsePow
              -> ParseUnary -> ParsePostfix -> ParsePrimary
            Hierarchie Perl (haute -> basse, doc perlop) :
              ->                          (postfix)
              ++ --                       (auto-inc)
              **                          (droit-assoc)
              ! ~ \ unaires + -
              =~ !~
              * / % x
              + - .
              << >>
              < > <= >= lt gt le ge
              == != <=> eq ne cmp ~~
              &
              | ^
              &&
              ||  //
              ..  ...
              ?:
              = += -= etc.
              , =>
              list operators (namedunary)
              not
              and
              or  xor
            Affectations chainables : $a = $b = 5
            Affectation liste : ($a, $b) = (1, 2)
            Swap : ($a, $b) = ($b, $a)
            Wantarray (contexte liste vs scalaire)
            qw() -> liste constante
            Appels de sous-routines : foo(), foo, &foo, foo->bar

  TODO 07 - PARSEUR DE STATEMENTS
            ParseStatement, ParseBlock, ParseStatementList
            Statements :
              my/our/local + affectation, affectation simple/liste
              Appel de sous-routine (avec et sans parens)
              if/elsif/else, unless/else (terminaison ; ou })
              while (COND) BLOCK, until (COND) BLOCK
              do { BLOCK } while (COND)
              for (INIT; COND; STEP) BLOCK
              foreach my $var (LIST) BLOCK
              foreach my $var (@array) BLOCK
              last, next, redo (avec ou sans label)
              return [EXPR]
              die, warn, exit
              use Module [LIST]
              package NAME
              sub NAME BLOCK, sub NAME (PROTO) BLOCK
              BEGIN { BLOCK }, END { BLOCK }
              Modifieurs suffixes :
                STMT if COND ; STMT unless COND ;
                STMT while COND ; STMT until COND ;
                STMT for LIST (foreach suffixe)
            Labels : LABEL: STMT (pour last/next/redo)
            Terminateurs : ; ou fin de bloc }

  TODO 08 - SOUS-ROUTINES (SUB) ET PARAMETRES (@_)
            ParseSubDef : sub name { BLOCK }
            Prototypes : sub name ($$;$) { } (optionnel, hint)
            Parametres : passes via @_ (pile Perl)
              my ($a, $b) = @_ ; my $a = shift ;
              Lvalue @_ : modification affecte les originaux
            Appel : foo(args) ou foo args ou &foo
            Valeur de retour : return EXPR, derniere expr evaluee,
              ou liste en contexte liste (wantarray)
            Sous-routines anonymes : my $f = sub { ... }
            Fermetures : capturent variables my lexicales
            Recursion directe et mutuelle (math.pl: fact, fib)
            Prologue ASM : PUSH EBP / MOV EBP, ESP / SUB ESP, locals
              Conventions : cdecl ; EAX = retour scalaire ;
              EDX:EAX = retour 64 bits ; pile = args
            Symbole genere : _PLF_<package>_<name>
            Sous-routines AUTOLOAD, DESTROY (hooks speciaux)

  TODO 09 - TABLEAUX (@) ET FONCTIONS DE TABLEAUX
            Declaration : my @arr ; my @arr = (1, 2, 3) ;
            Acces : $arr[i] (sigil $ pour element scalaire)
            $#arr : dernier index ; scalar(@arr) : nombre d elements
            Tableau en contexte scalaire : nombre d elements
            Tranche : @arr[2, 4] ; @arr[1..3]
            Boucle : foreach my $v (@arr) { ... }
            Fonctions :
              push(@arr, LIST) : ajoute en fin
              pop(@arr) : retire et retourne dernier
              shift(@arr) : retire et retourne premier
              unshift(@arr, LIST) : insere en debut
              splice(@arr, OFFSET, LEN, LIST) : insertion/suppression
              sort LIST ; sort { $a <=> $b } LIST (numerique)
              sort { $a cmp $b } LIST (chaine)
              reverse LIST
              join(SEP, LIST) : concatène en chaine
              grep { COND } LIST ; grep /REGEX/, LIST
              map { EXPR } LIST ; map EXPR, LIST
              wantarray : vrai si contexte liste
              scalar(@arr) : nombre d elements
              exists $arr[i], delete $arr[i]
            Tableaux de arrays.pl : @nums, @mots, @pile
            Codegen : allocation heap, _PLRT_array_new/push/get/len

  TODO 10 - HASHES (%) ET FONCTIONS DE HASHES
            Declaration : my %h ; my %h = (k1, v1, k2, v2)
              ou my %h = (k1 => v1, k2 => v2)
            Acces : $h{key} (cle string, auto-quoting des
              identificateurs simples)
            Tranche : @h{qw(a b)} (retourne liste de valeurs)
            exists $h{key} : teste l existence de la cle
            delete $h{key} : supprime et retourne la valeur
            Fonctions :
              keys %h : liste des cles (ordre non garanti)
              values %h : liste des valeurs
              each %h : retourne (cle, valeur) suivant
              scalar %h : fraction buckets utilises (Perl 5)
              delete $h{k}, exists $h{k}
            Hash de hashes.pl : %scores, %pays, %compteurs
            Hash en contexte booleen : vrai si non vide
            Codegen : table de hachage open addressing,
              _PLRT_hash_new/set/get/exists/delete/keys/values

  TODO 11 - CONTEXTE SCALAIRE VS LISTE ET OPERATEURS SPECIFIQUES
            Contexte determine le comportement de beaucoup d ops
            Scalaire : retourne un seul scalaire
              @arr en contexte scalaire -> nombre d elements
              keys %h en scalaire -> nombre de cles
              localtime en scalaire -> chaine
            Liste : retourne plusieurs valeurs
              ($a, $b, $c) = foo() ; @arr = bar()
            Contexte booleen : 0, "" , "0", undef = faux ;
              tout autre valeur = vrai
            Operateurs specifiques :
              .. (gamme) : 1..5 en liste -> (1,2,3,4,5)
                en scalaire -> flip-flop (lecture ligne)
              x (repetition) : "abc" x 3 -> "abcabcabc"
                (1,2) x 3 -> (1,2,1,2,1,2) en contexte liste
              <=> (spaceship) et cmp : comparaison 3 voies
              // (defini-ou, Perl 5.10+) : $a // $b -> $a si
                defini sinon $b
              && et || : retournent un operande (court-circuit)
            Wantarray : detecter contexte depuis le code Perl
            Codegen : analyser contexte a la compilation,
              emettre variantes _list vs _scalar des runtimes

  TODO 12 - CHAINES : INTERPOLATION, HEREDOC, OPERATEURS
            String runtime : header (RT_STRING, flags, refcount),
              buffer, len, cap, encoding (Latin-1 ou UTF-8)
            Litteraux segment .rdata, prefixe _PLK_
            'simple' : litteral, aucune interpolation sauf \\ \'
            "double" : interpolation $var @arr {expr} et echappements
              \n \t \r \f \b \0 \a \e \xFF \x{FFFF} \cX
              \l \u \L \U \Q \E
            Interpolation de tableau : "@arr" insere join($", @arr)
            Heredoc : <<EOF, <<'EOF' (litteral), <<"EOF" (interpole)
              <<~EOF : squiggly (retire indentation commune Perl 5.26+)
            Operateur . (concatenation) : $s1 . $s2
            Operateur .= (concatenation composee)
            Operateur x (repetition) : $s x $n
            Fonctions chaines :
              length($s), substr($s, OFF, LEN), index($s, SUB),
              rindex($s, SUB), uc($s), lc($s), ucfirst, lcfirst,
              chomp($s) (retire \n), chop($s) (retire dernier car),
              reverse($s), sprintf(FMT, ...), chr(N), ord($s),
              hex($s), oct($s), pos($s)
            hello.pl : . .= x ; math.pl : abs()

  TODO 13 - EXPRESSIONS REGULIERES : m//, =~, !~, qr//
            Reconnaissance /pattern/flags, m/pat/flags,
              m{pat}flags, m!pat!flags (delimiter variable)
            Flags : i (insensible casse), g (global), m (multiline),
              s (. inclut \n), x (commentaires etendus),
              e (eval remplacement), r (non-destructif)
            Operateur =~ : $s =~ /pat/ (retourne 1 si match)
            Operateur !~ : $s !~ /pat/ (retourne 1 si pas match)
            Captures :
              $1..$9 : groupes numerotes
              $& : match entier, $` : avant, $' : apres
              %+ : groupes nommes (?<name>...)
              @+ / @- : positions debut/fin de chaque groupe
            Regex compilee : qr/pat/flags -> reference regex
            Patterns :
              . * + ? {n} {n,m} {n,} gourmands et ? lazy
              [] [^] \\d \\D \\w \\W \\s \\S \\b \\B
              () (?:) (?<name>) (?=) (?!) (?<=) (?<!)
              ^ $ \\A \\Z \\z | alternance
            Engine : NFA minimaliste (classes, quantifieurs, groupes)
            Codegen : _PLRT_regex_match, _PLRE_<n> (data pattern
              compilee), gestion captures dans variables speciales

  TODO 14 - SUBSTITUTION ET TRANSLITTERATION : s///, tr///
            Substitution : s/PATTERN/REMPLACEMENT/flags
              Delimiters variables : s{pat}{rpl}, s!pat!rpl!
              Flags : g (toutes occurrences), i, m, s, x, e, r
              e : evaluer remplacement comme expression Perl
              r (non-destructif, Perl 5.14+) : retourne copie
              $var =~ s/foo/bar/ modifie $var en place
              $var =~ s/foo/bar/g remplace toutes les occurrences
              regex_test.pl / regex_test2.pl / regex.pl : s/World/Perl/
            Translitteration : tr/LIST/LIST/flags (alias y///)
              Flags : c (complement), d (delete), s (squeeze)
              tr/a-z/A-Z/ : convertir en majuscules
              tr/0-9// en scalaire : compte les chiffres
            Operateur s/// genere :
              _PLRT_subst_once (1ere occurrence)
              _PLRT_subst_global (flag g)
              _PLRT_tr (translitteration)
            Stockage pattern s/// : _PLRE_<n> (partie match)
              et _PLK_<n> (partie remplacement si pas /e)

  TODO 15 - STRUCTURES DE CONTROLE : IF / ELSIF / ELSE / UNLESS
            if (COND) { BLOCK }
            if (COND) { BLOCK } else { BLOCK }
            if (COND) { BLOCK } elsif (COND) { BLOCK } ... else { }
            unless (COND) { BLOCK } [else { BLOCK }]
            Modifieurs suffixes (une seule instruction) :
              STMT if COND ;
              STMT unless COND ;
            Ternaire : COND ? EXPR_VRAI : EXPR_FAUX
            Operateurs logiques court-circuit :
              COND && EXPR ; COND || EXPR ;
              COND // EXPR (defini-ou)
              and or not (basse precedence)
            Booleens Perl : seuls undef, 0, "0", "" = faux
            Codegen : CMP / JE / JNE / JMP
              labels _PLL_IF_<n>_ELSE, _PLL_IF_<n>_END
            control.pl : if ($n > 15), elsif, else, if simple,
              conditions imbriquees

  TODO 16 - BOUCLES : WHILE / UNTIL / FOR / FOREACH / DO-WHILE
            while (COND) { BLOCK }
            until (COND) { BLOCK }
            do { BLOCK } while (COND)  (boucle do-while)
            for (INIT; TEST; STEP) { BLOCK }  (style C)
            foreach my $var (LIST) { BLOCK }
            foreach my $var (@array) { BLOCK }
            $_ par defaut si pas de variable
            Controle de boucle :
              last [LABEL] : sortie (comme break C)
              next [LABEL] : iteration suivante (comme continue C)
              redo [LABEL] : recommence iteration courante
            Labels de boucle : OUTER: while (...) { ... last OUTER }
            Iterateur de champ : for (1..5), foreach (qw(a b c))
            Codegen : labels _PLL_LOOP_<n>_TOP, _PLL_LOOP_<n>_CONT,
              _PLL_LOOP_<n>_END
            control.pl : while ($i <= 5), while decroissant,
              foreach (10, 20, 30)
            arrays.pl : foreach my $v (1..5), foreach sur plage

  TODO 17 - REFERENCES ET DEREFERENCEMENT
            Creation de reference : \ (backslash)
              $sref = \$scalar ; $aref = \@array ;
              $href = \%hash ; $cref = \&sub
            References anonymes :
              $aref = [1, 2, 3]   (tableau anonyme)
              $href = {a => 1}    (hash anonyme)
              $cref = sub { ... } (sous-routine anonyme)
            Dereferencement :
              $$sref (scalaire) ; @$aref (tableau) ;
              %$href (hash) ; &$cref(...) (appel)
              $$aref[i] == $aref->[i] (element)
              $$href{k} == $href->{k} (element)
            Operateur fleche -> : dereferencement sucre
            Structures de donnees imbriquees :
              $data = [ [1,2], [3,4] ]  (AoA)
              $data = { a => [1,2] }    (HoA)
            ref($var) : retourne le type ('SCALAR', 'ARRAY',
              'HASH', 'CODE', 'REF', '')
            Counted references (refcount) :
              _PLRT_ref_inc, _PLRT_ref_dec, _PLRT_ref_free
            Codegen : ptr 32 bits + tag type en header heap

  TODO 18 - VARIABLES SPECIALES PERL
            Scalaires speciaux :
              $_ : variable par defaut (for, while, map, grep)
              $! / $ERRNO : code erreur systeme
              $@ : erreur eval
              $0 : nom du programme
              $/ : separateur d entree (defaut \n)
              $\ : separateur de sortie print
              $, : separateur entre args print
              $; : separateur multi-cle hash
              $. : numero de ligne courant
              $| : flush automatique (autoflush)
              $$ : PID du processus
            Variables regex :
              $& $` $' $1..$9 $+ (dernier groupe)
              @+ @- (positions des groupes)
            Tableaux speciaux :
              @_ : parametres sous-routine
              @ARGV : arguments ligne de commande
              @INC : chemins de recherche modules
              @ISA : heritage de classe
            Hashes speciaux :
              %ENV : variables d environnement
              %SIG : gestionnaires de signaux (stub)
              %INC : modules charges
            STDIN, STDOUT, STDERR : handles fichier
            Filehandles STDIN/STDOUT : GetStdHandle Win32
            Codegen : segment .data prefixe _PL_ ; ARGV depuis
              GetCommandLineA / CommandLineToArgvW

  TODO 19 - CONTEXT BOOLEEN, OPERATEURS ET FONCTIONS NUMERIQUES
            Verite Perl :
              Faux : undef, 0, 0.0, "0", ""
              Vrai : tout autre valeur (y compris "00", "0.0")
            Operateurs numeriques :
              + - * / % ** ++ -- (pre/post)
              Entier : div (pas d operateur, utiliser int())
              abs($n) : valeur absolue
              int($n) : troncature vers zero
            Fonctions mathematiques :
              abs, int, sqrt, exp, log
              sin, cos, atan2 (retournent radians)
              hex("FF") -> 255 ; oct("077") -> 63 ;
              oct("0b101") -> 5 ; oct("0xFF") -> 255
            Conversions explicites :
              int($f), sprintf("%d", $f)
            Operateurs bit :
              & | ^ ~ << >> (travaillent sur entiers)
            Comparaisons numeriques : == != < > <= >= <=>
            Comparaisons chaines : eq ne lt gt le ge cmp
            math.pl : add, sub2, mul, divmod, fact, fib, abs
            Codegen : ADD/SUB/IMUL/IDIV/CMP 32 bits ;
              _PLRT_pow, _PLRT_abs, _PLRT_sqrt

  TODO 20 - FONCTIONS INTEGREES GENERALES
            Entree/sortie : print, say, printf, sprintf, warn, die
              print LIST : ecrit sur STDOUT (ou handle specifie)
              print HANDLE LIST ; print $fh LIST
              say : comme print mais ajoute \n
              printf FMT, LIST ; sprintf(FMT, LIST) -> chaine
              warn : comme die mais continue
              die : leve exception (voir $@)
            Conversions : chr, ord, hex, oct, int, abs, sprintf
            Chaines : length, substr, index, rindex, uc, lc,
              ucfirst, lcfirst, chomp, chop, reverse, pos,
              quotemeta, sprintf
            Listes : sort, reverse, grep, map, join, split,
              splice, push, pop, shift, unshift, scalar,
              wantarray, each, keys, values, exists, delete
            Maths : abs, atan2, cos, sin, sqrt, exp, log, int,
              rand, srand
            Divers : defined, undef, ref, tied, tie, untie,
              caller, local, my, our, pos, reset, scalar,
              wantarray, exit, sleep, time
            Codegen :
              _PLRT_print, _PLRT_say, _PLRT_printf,
              _PLRT_sprintf, _PLRT_die, _PLRT_warn,
              _PLRT_split, _PLRT_join, _PLRT_sort,
              _PLRT_grep, _PLRT_map, _PLRT_defined

  TODO 21 - I/O FICHIERS : OPEN / CLOSE / READLINE / PRINT / EOF
            Ouverture : open(my $fh, MODE, FICHIER) ou
              open(FH, "MODE FICHIER") (ancien style)
            Modes : '<' lecture, '>' ecriture (efface),
              '>>' ajout, '+<' lecture-ecriture,
              '+>' lecture-ecriture (efface)
              '|-' pipe ecriture, '-|' pipe lecture
            Lecture :
              readline($fh) ou <$fh> : lit une ligne (avec \n)
              <STDIN> / readline(STDIN) : stdin
              <> : lit ARGV ou STDIN si vide (magic diamond)
            Ecriture :
              print $fh LIST ; printf $fh FMT, LIST
            Fermeture : close($fh) ; retourne 1 si succes
            eof($fh) : vrai si fin de fichier
            Handles predefined : STDIN STDOUT STDERR
            Fonctions fichier : rename, unlink, chmod,
              stat, -e -f -d -r -w -x (tests fichier)
            Implementation Win32 API :
              CreateFileA, ReadFile, WriteFile, CloseHandle,
              GetStdHandle, SetFilePointer
            file_io_test.pl : open/print/close/readline
            file_io_test2.pl : mode append, eof

  TODO 22 - NUMERIQUES, CHAINES ET PRAGMAS DE TYPES
            Entiers : 32 bits signes (Perl natif > 32 bits,
              mais cible 80386 : on limite a 32 bits)
            Litteral entier : 42, -5, 0xFF, 0b101, 0777, 1_000
            Flottant : IEEE 754 double 64 bits
              1.5, 1.5e3, 1.5E-3, .5, 1.
            Promotion automatique : int op float -> float
            Debordement 32 bits : comportement C (wrap)
            Chaines numeriques : "42abc" -> 42 avec warning
              "0xFF" -> 0 sans warning en contexte num (hex())
            Litteraux speciaux : undef (ni num ni str)
            Pragmas affectant les types :
              use integer : force arithmetique entiere
              use warnings 'numeric' : warning coercions
              use strict 'vars' : interdit vars sans my/our
            Constantes : use constant PI => 3.14159 ;
              Codegen : remplace l ident par la valeur inline
            Codegen : MOV EAX, <n> pour entier 32 bits ;
              FLD / FSTP / FADDP etc. pour float (co-proc 387)

  TODO 23 - USE STRICT / USE WARNINGS / PRAGMAS / PACKAGES
            use strict : sous-pragma 'vars' 'refs' 'subs'
              vars : interdit $x sans my/our/local
              refs : interdit dereferencement de chaine
              subs : interdit appel bareword non declare
            use warnings : active avertissements categoriels
              Categorie 'numeric', 'uninitialized', 'redefine',
                'deprecated', 'once', 'shadow'
              use warnings FATAL => 'all' : warnings mortels
            no strict ; no warnings : desactive localement
            package NAME : change package courant
              package NAME VERSION ; (Perl 5.12+)
              package NAME { BLOCK } (Perl 5.14+)
            use MODULE LIST : import compile-time
              Appelle MODULE->import(LIST) a compile-time
              use strict <=> BEGIN { require strict; strict->import }
            BEGIN { } / END { } / CHECK { } / INIT { }
            use constant NAME => VALUE ;
              use constant { A => 1, B => 2 } ;
            use parent 'Base' ; use base 'Base' (heritage)
            Fichiers couverts : tous les .pl avec 'use strict'
              et 'use warnings' (hello.pl, math.pl, etc.)
            Codegen : BEGIN execute a la compilation Pascal ;
              packages generes en prefixes de symboles ASM

  TODO 24 - GENERATEUR DE CODE 80386 ET SORTIE .ASM
            Backend codegen :
              GenLoadInt(N), GenLoadStr(LblIdx)
              GenLoadVar/StoreVar(Idx) (resout scope)
              GenLoadElem(ArrIdx, Subscript) (element tableau)
              GenLoadHash(HashIdx, Key) (element hash)
              GenCall(SubName, Argc), GenCallRef(CrefReg, Argc)
              GenJmp/JZ/JNZ/Label, GenPush/Pop
              GenAdd/Sub/Mul/Div, GenMod, GenPow
              GenConcat, GenRepeat (x)
              GenComp(Op) : CMP + Jxx pour == != < > etc.
              GenStrComp(Op) : _PLRT_strcmp + test EAX
              GenPushArgs / GenPopArgs (preparation appel @_)
            Convention d appel Perl (cdecl) :
              Pile = arg1..argN (gauche -> droite)
              EAX = retour scalaire ; ou ptr liste
              @_ : mise a jour avant appel pour aliasing
            Frame : PUSH EBP / MOV EBP, ESP / SUB ESP, locals
              [EBP+8]=arg1, [EBP-4..-N]=my variables
            Sortie .ASM (-asm) : MASM 6/8 ou JWasm
              .386 .MODEL FLAT, STDCALL
              .DATA .RDATA .BSS .CODE
              EXTRN ExitProcess, GetStdHandle, WriteFile,
                ReadFile, CreateFileA, ...
            EmitComment, EmitLabel, Emit (instruction brute)
            GenRuntime : insere blobs asm du runtime en ligne

  TODO 25 - BACKEND BINAIRE .OBJ COFF + .EXE PE WIN32
            Backend binaire (independant du backend ASM) :
              BinCode/BinData : Array Of Byte
              BinLabels : Array Of TLabel
              BinFixups : Array Of TFixup (REL32, ABS32, IMP32)
              BinImports : Array Of TImport (Win32 IAT)
              BinEmit8/16/32, BinEmitInstr (encodeur 80386 minimal :
                PUSH POP MOV ADD SUB IMUL IDIV CMP TEST JMP JCC
                CALL RET ENTER LEAVE INT SHL SHR SAR SAL AND OR
                XOR NOT)
              BinDefineLabel, BinResolveLabel, BinAddFixup,
                BinResolveFixups
            OBJ COFF Win32 (-obj) :
              IMAGE_FILE_HEADER (Machine=I386)
              Sections .text .data .rdata .bss
              Symbol table COFF (statique + externes)
              Relocations par section
            EXE PE Win32 (defaut) :
              MZ stub DOS minimal
              PE sig + IMAGE_FILE_HEADER + IMAGE_OPTIONAL_HEADER32
              Sections : .text (RX) .data (RW) .rdata (R) .bss (RW)
                .idata (R) IAT
              IAT KERNEL32.DLL : GetStdHandle WriteFile ReadFile
                ExitProcess GetCommandLineA GetEnvironmentStringsA
                CreateFileA CloseHandle HeapAlloc HeapFree GetProcessHeap
              IAT MSVCRT.DLL (ou pure-Win32) : printf malloc free sprintf
              Subsystem CUI 3 par defaut
              Entry _PLSTART : init runtime, appel main, ExitProcess
              ImageBase $00400000, SectionAlign 4096, FileAlign 512
            Runtime embarque (linke statiquement dans .text/.rdata) :
              _PLRT_start, _PLRT_exit
              _PLRT_print, _PLRT_say, _PLRT_warn, _PLRT_die
              _PLRT_alloc, _PLRT_free
              _PLRT_to_num, _PLRT_to_str, _PLRT_to_bool
              _PLRT_strconcat, _PLRT_strrepeat, _PLRT_streq,
                _PLRT_strcmp, _PLRT_strlen
              _PLRT_to_s_int, _PLRT_to_s_float
              _PLRT_array_new/push/pop/get/set/len
              _PLRT_hash_new/set/get/exists/delete/keys/values
              _PLRT_regex_match, _PLRT_subst_once, _PLRT_subst_global
              _PLRT_sprintf_lite (sous-ensemble de printf)
              _PLRT_file_open, _PLRT_file_close, _PLRT_file_readline
                _PLRT_file_write, _PLRT_file_eof
              _PLRT_sort, _PLRT_join, _PLRT_split
            Validation : tous les SAMPLES\PERL\*.pl compilent et
              produisent un .EXE PE Win32 fonctionnel
  ============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF      }
{ ============================================================ }

Const
  PERLCW32_VERSION = '0.1';
  PERLCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Constantes PE/COFF }
  PE_DOS_MAGIC           = $5A4D;
  PE_PE_SIG              = $00004550;
  PE_MACHINE_I386        = $014C;
  PE_IMG_BASE            = $00400000;
  PE_SEC_ALIGN           = 4096;
  PE_FILE_ALIGN          = 512;
  PE_SUBSYS_CUI          = 3;
  PE_SUBSYS_GUI          = 2;
  PE_OPT_MAGIC_PE32      = $010B;
  PE_SCN_CNT_CODE        = $00000020;
  PE_SCN_CNT_INIT_DATA   = $00000040;
  PE_SCN_CNT_UNINIT_DATA = $00000080;
  PE_SCN_MEM_EXECUTE     = $20000000;
  PE_SCN_MEM_READ        = $40000000;
  PE_SCN_MEM_WRITE       = -2147483648;
  COFF_SYM_CLASS_EXTERNAL= 2;
  COFF_SYM_CLASS_STATIC  = 3;
  COFF_REL_I386_DIR32    = $0006;
  COFF_REL_I386_REL32    = $0014;
  BIN_SEC_TEXT           = 1;
  BIN_SEC_DATA           = 2;
  BIN_SEC_RDATA          = 3;
  BIN_SEC_BSS            = 4;
  BIN_FIX_REL32          = 1;
  BIN_FIX_ABS32          = 2;
  BIN_FIX_IMP32          = 3;

  { Limites internes }
  MAX_SYM        = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_SUB        = {$IFDEF FPC}512{$ELSE}64{$ENDIF};
  MAX_LOCAL      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_PARAM      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_LABEL      = {$IFDEF FPC}4096{$ELSE}256{$ENDIF};
  MAX_REGEX      = {$IFDEF FPC}256{$ELSE}32{$ENDIF};
  MAX_FORMAT_LIT = {$IFDEF FPC}128{$ELSE}16{$ENDIF};
  MAX_STR        = 255;
  MAX_ERRORS     = {$IFDEF FPC}30{$ELSE}5{$ENDIF};
  MAX_SCOPE      = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_STRING_LIT = {$IFDEF FPC}1024{$ELSE}128{$ENDIF};
  MAX_ARRAY_LIT  = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};
  MAX_HASH_LIT   = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};
  MAX_NUM_LIT    = {$IFDEF FPC}1024{$ELSE}64{$ENDIF};
  MAX_LOOP_NEST  = {$IFDEF FPC}64{$ELSE}8{$ENDIF};
  MAX_LOAD_PATH  = {$IFDEF FPC}64{$ELSE}8{$ENDIF};
  MAX_BIN        = 65536;
  MAX_BIN_LABEL  = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};
  MAX_BIN_FIXUP  = {$IFDEF FPC}4096{$ELSE}512{$ENDIF};
  MAX_BIN_IMPORT = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_CONTROL    = {$IFDEF FPC}2048{$ELSE}128{$ENDIF};
  MAX_AST        = {$IFDEF FPC}8192{$ELSE}512{$ENDIF};

  { Prefixes de nommage ASM }
  ASM_PFX_GVAR    = '_PL_';     { variable globale $ (package)     }
  ASM_PFX_SUB     = '_PLF_';    { sous-routine / sub               }
  ASM_PFX_STRING  = '_PLK_';    { constante chaine                 }
  ASM_PFX_RUNTIME = '_PLRT_';   { routine runtime                  }
  ASM_PFX_LABEL   = '_PLL_';    { label de saut interne            }
  ASM_PFX_ARRAY   = '_PLA_';    { variable tableau @               }
  ASM_PFX_HASH    = '_PLH_';    { variable hash %                  }
  ASM_PFX_REGEX   = '_PLRE_';   { expression reguliere             }
  ASM_PFX_PKG     = '_PLPKG_';  { symbole de package               }

  { Types de tokens }
  TOK_EOF          = 0;
  TOK_IDENT        = 256;
  TOK_SIGIL_SCALAR = 257;   { $var }
  TOK_SIGIL_ARRAY  = 258;   { @var }
  TOK_SIGIL_HASH   = 259;   { %var }
  TOK_SIGIL_CODE   = 260;   { &sub }
  TOK_INTEGER      = 261;
  TOK_FLOAT        = 262;
  TOK_STRING       = 263;   { 'simple' }
  TOK_DSTRING      = 264;   { "double" avec interpolation }
  TOK_HEREDOC      = 265;
  TOK_REGEX        = 266;   { /pat/flags ou m/pat/flags }
  TOK_SUBST        = 267;   { s/pat/rpl/flags }
  TOK_TRANS        = 268;   { tr/lst/lst/flags ou y/// }
  TOK_QWORD        = 269;   { qw(...) }
  TOK_DOTDOT       = 270;   { .. }
  TOK_DOTDOTDOT    = 271;   { ... }
  TOK_FATCOMMA     = 272;   { => }
  TOK_SPACESHIP    = 273;   { <=> }
  TOK_CMP          = 274;   { cmp }
  TOK_DEFOR        = 275;   { // defini-ou }
  TOK_MATCH        = 276;   { =~ }
  TOK_NMATCH       = 277;   { !~ }
  TOK_POW          = 278;   { ** }
  TOK_SHL          = 279;   { << }
  TOK_SHR          = 280;   { >> }
  TOK_LE           = 281;   { <= }
  TOK_GE           = 282;   { >= }
  TOK_EQ           = 283;   { == }
  TOK_NE           = 284;   { != }
  TOK_ANDAND       = 285;   { && }
  TOK_OROR         = 286;   { || }
  TOK_ASSIGN_OP    = 287;   { += -= *= /= .= etc. }
  TOK_ARROW        = 288;   { -> }
  TOK_DEREF_SCALAR = 289;   { deref scalaire }
  TOK_DEREF_ARRAY  = 290;   { deref tableau  }
  TOK_DEREF_HASH   = 291;   { deref hash     }
  TOK_INCR         = 292;   { ++ }
  TOK_DECR         = 293;   { -- }
  TOK_HASHNUM      = 294;   { $#arr dernier index }

  { Mots-cles reserves Perl }
  KW_AND         = 1000;
  KW_BEGIN       = 1001;
  KW_CHOMP       = 1002;
  KW_CHOP        = 1003;
  KW_CLOSE       = 1004;
  KW_DEFINED     = 1005;
  KW_DELETE      = 1006;
  KW_DIE         = 1007;
  KW_DO          = 1008;
  KW_EACH        = 1009;
  KW_ELSE        = 1010;
  KW_ELSIF       = 1011;
  KW_END         = 1012;
  KW_EOF_FUNC    = 1013;
  KW_EQ_STR      = 1014;
  KW_EVAL        = 1015;
  KW_EXISTS      = 1016;
  KW_EXIT        = 1017;
  KW_FOR         = 1018;
  KW_FOREACH     = 1019;
  KW_FORMAT      = 1020;
  KW_GE_STR      = 1021;
  KW_GOTO        = 1022;
  KW_GT_STR      = 1023;
  KW_IF          = 1024;
  KW_KEYS        = 1025;
  KW_LAST        = 1026;
  KW_LE_STR      = 1027;
  KW_LOCAL       = 1028;
  KW_LT_STR      = 1029;
  KW_MAP         = 1030;
  KW_MY          = 1031;
  KW_NE_STR      = 1032;
  KW_NEXT        = 1033;
  KW_NO          = 1034;
  KW_NOT         = 1035;
  KW_OPEN        = 1036;
  KW_OR          = 1037;
  KW_OUR         = 1038;
  KW_PACKAGE     = 1039;
  KW_POP         = 1040;
  KW_PRINT       = 1041;
  KW_PRINTF      = 1042;
  KW_PUSH        = 1043;
  KW_REDO        = 1044;
  KW_RETURN      = 1045;
  KW_REVERSE     = 1046;
  KW_SCALAR      = 1047;
  KW_SHIFT       = 1048;
  KW_SORT        = 1049;
  KW_SPLICE      = 1050;
  KW_SPRINTF     = 1051;
  KW_SUB         = 1052;
  KW_TIE         = 1053;
  KW_TIED        = 1054;
  KW_UNLESS      = 1055;
  KW_UNSHIFT     = 1056;
  KW_UNTIL       = 1057;
  KW_USE         = 1058;
  KW_VALUES      = 1059;
  KW_WANTARRAY   = 1060;
  KW_WARN        = 1061;
  KW_WHILE       = 1062;
  KW_XOR         = 1063;
  KW_UNDEF       = 1064;
  KW_GREP        = 1065;
  KW_JOIN        = 1066;
  KW_SPLIT       = 1067;
  KW_LENGTH      = 1068;
  KW_SUBSTR      = 1069;
  KW_INDEX_FUNC  = 1070;
  KW_UC          = 1071;
  KW_LC          = 1072;
  KW_READLINE    = 1073;
  KW_ABS         = 1074;
  KW_INT_FUNC    = 1075;
  KW_SQRT        = 1076;
  KW_CHR         = 1077;
  KW_ORD         = 1078;
  KW_HEX         = 1079;
  KW_OCT         = 1080;
  KW_REF         = 1081;
  KW_BLESS       = 1082;
  KW_SAY         = 1083;
  KW_CMP_STR     = 1084;

  { Kinds de symboles }
  SK_NONE    = 0;
  SK_SCALAR  = 1;   { $var }
  SK_ARRAY   = 2;   { @var }
  SK_HASH    = 3;   { %var }
  SK_CODE    = 4;   { &sub }
  SK_FORMAT  = 5;
  SK_GLOB    = 6;   { *typeglob }

  { Portees de symboles }
  SCOPE_LEXICAL = 0;   { my }
  SCOPE_PACKAGE = 1;   { our }
  SCOPE_DYNAMIC = 2;   { local }

  SC_TOPLEVEL = 0;
  SC_SUB      = 1;
  SC_BLOCK    = 2;

  { Types runtime scalaires }
  RT_UNDEF   = 0;
  RT_INTEGER = 1;
  RT_FLOAT   = 2;
  RT_STRING  = 3;
  RT_REF     = 4;
  RT_ARRAY   = 5;
  RT_HASH    = 6;
  RT_CODE    = 7;

  { Tag entier 31 bits (((n shl 1) or 1)) }
  RV_UNDEF_TAG   = $00000000;
  RV_INTEGER_TAG = $00000001;

  { Kinds de noeuds AST }
  NK_NONE       = 0;
  NK_LITERAL    = 1;
  NK_VAR        = 2;
  NK_UNARY      = 3;
  NK_BINARY     = 4;
  NK_ASSIGN     = 5;
  NK_TERNARY    = 6;
  NK_RANGE      = 7;
  NK_CALL       = 8;
  NK_INDEX      = 9;
  NK_ARRAY_LIT  = 10;
  NK_HASH_LIT   = 11;
  NK_LIST       = 12;
  NK_STMT_LIST  = 13;
  NK_IF         = 14;
  NK_UNLESS     = 15;
  NK_WHILE      = 16;
  NK_UNTIL      = 17;
  NK_FOR_C      = 18;   { for (;;) style C }
  NK_FOREACH    = 19;
  NK_DO_WHILE   = 20;
  NK_RETURN     = 21;
  NK_LAST       = 22;
  NK_NEXT       = 23;
  NK_REDO       = 24;
  NK_SUB_DEF    = 25;
  NK_ANON_SUB   = 26;
  NK_REGEX      = 27;
  NK_SUBST      = 28;
  NK_TRANS      = 29;
  NK_USE        = 30;
  NK_PACKAGE    = 31;
  NK_BEGIN_HOOK = 32;
  NK_END_HOOK   = 33;
  NK_DEREF      = 34;
  NK_REF_OP     = 35;
  NK_SLICE      = 36;
  NK_EMPTY      = 37;

  { Flags de chaines }
  STRF_SIMPLE   = $0001;   { 'single quoted' }
  STRF_INTERP   = $0002;   { "double quoted" }
  STRF_HEREDOC  = $0004;
  STRF_SQUIGGLY = $0008;   { <<~ }
  STRF_FROZEN   = $0010;

  { Flags de regex }
  REGF_IGNORE_CASE = $0001;   { /i }
  REGF_GLOBAL      = $0002;   { /g }
  REGF_MULTILINE   = $0004;   { /m }
  REGF_SINGLELINE  = $0008;   { /s }
  REGF_EXTENDED    = $0010;   { /x }
  REGF_EVAL        = $0020;   { /e (s///) }
  REGF_NONDESTR    = $0040;   { /r (Perl 5.14+) }

  { Flags de symboles }
  SF_PARAM    = $0001;
  SF_USED     = $0002;
  SF_ASSIGNED = $0004;
  SF_GLOBAL   = $0008;
  SF_SPECIAL  = $0010;

  { Flags de structures de controle }
  CTRLF_UNLESS   = $0001;
  CTRLF_MODIFIER = $0002;
  CTRLF_TERNARY  = $0004;
  CTRLF_DOWHILE  = $0008;
  CTRLF_FOREACH  = $0010;

Type
  TStringList64 = Array[1..MAX_LOAD_PATH] Of String;

  TSym = Record
    Name:    String;
    Kind:    Integer;   { SK_SCALAR, SK_ARRAY, SK_HASH, SK_CODE, ... }
    RType:   Integer;   { RT_xxx }
    ScopeKd: Integer;   { SCOPE_LEXICAL / SCOPE_PACKAGE / SCOPE_DYNAMIC }
    Depth:   Integer;   { niveau d imbrication }
    Offset:  Integer;   { [EBP - Offset] pour my lexicale }
    Flags:   Integer;
    AsmName: String;
    Package: String;
  End;

  TSymTable   = Array[1..MAX_SYM]   Of TSym;
  TScopeStack = Array[0..MAX_SCOPE] Of Integer;

  TStringLit = Record
    Text:    String;
    AsmName: String;
    Len:     Integer;
    Flags:   Integer;
  End;

  TStringLitTable = Array[1..MAX_STRING_LIT] Of TStringLit;

  TRegexLit = Record
    Pattern:      String;
    Flags:        Integer;
    AsmName:      String;
    CaptureCount: Integer;
  End;

  TRegexLitTable = Array[1..MAX_REGEX] Of TRegexLit;

  TNumLit = Record
    Text:    String;
    AsmName: String;
    RType:   Integer;
    Base:    Integer;
  End;

  TNumLitTable = Array[1..MAX_NUM_LIT] Of TNumLit;

  TArrayLit = Record
    AsmName: String;
    Count:   Integer;
  End;

  TArrayLitTable = Array[1..MAX_ARRAY_LIT] Of TArrayLit;

  THashLit = Record
    AsmName: String;
    Count:   Integer;
  End;

  THashLitTable = Array[1..MAX_HASH_LIT] Of THashLit;

  TBinBuffer = Array[0..MAX_BIN - 1] Of Byte;

  TBinLabel = Record
    Name:    String;
    Section: Integer;
    Offset:  LongInt;
    Defined: Boolean;
  End;

  TBinFixup = Record
    Section:  Integer;
    Offset:   LongInt;
    LabelRef: Integer;
    Kind:     Integer;
  End;

  TBinImport = Record
    DllName:  String;
    ProcName: String;
    Hint:     Integer;
    IATRva:   LongInt;
  End;

  TBinLabelTable  = Array[1..MAX_BIN_LABEL]  Of TBinLabel;
  TBinFixupTable  = Array[1..MAX_BIN_FIXUP]  Of TBinFixup;
  TBinImportTable = Array[1..MAX_BIN_IMPORT] Of TBinImport;

  TASTNode = Record
    Kind:        Integer;
    Tok:         Integer;
    Text:        String;
    Left:        Integer;
    Right:       Integer;
    Third:       Integer;
    FirstChild:  Integer;
    NextSibling: Integer;
    SymRef:      Integer;
    Line:        Integer;
  End;

  TASTTable = Array[1..MAX_AST] Of TASTNode;

  TControlInfo = Record
    Kind:     Integer;
    CondNode: Integer;
    ThenNode: Integer;
    ElseNode: Integer;
    EndLabel: String;
    LoopTop:  String;
    LoopCont: String;
    Flags:    Integer;
  End;

  TControlTable = Array[1..MAX_CONTROL] Of TControlInfo;

  TOptions = Record
    SrcFile:       String;
    OutFile:       String;
    Verbose:       Boolean;
    DebugMode:     Boolean;
    Warnings:      Boolean;
    EmitExe:       Boolean;
    EmitObj:       Boolean;
    EmitAsm:       Boolean;
    StrictMode:    Boolean;
    LoadPath:      TStringList64;
    LoadPathCount: Integer;
  End;

Var
  Opt:            TOptions;
  SrcBuf:         Array[1..65535] Of Char;
  SrcLen:         LongInt;
  LexPos:         LongInt;
  LexLine:        LongInt;
  LexCol:         LongInt;
  CurTokType:     Integer;
  CurTokStr:      String;
  CurTokNum:      LongInt;
  CurTokFloat:    Double;
  CurTokLine:     LongInt;
  CurTokCol:      LongInt;
  LastTokType:    Integer;
  SymTable:       TSymTable;
  SymCount:       Integer;
  ScopeLevel:     Integer;
  ScopeBase:      TScopeStack;
  ScopeNextLocal: TScopeStack;
  CurrentPkg:     String;
  StringTable:    TStringLitTable;
  StringCount:    Integer;
  RegexLitTable:  TRegexLitTable;
  RegexLitCount:  Integer;
  NumLitTable:    TNumLitTable;
  NumLitCount:    Integer;
  ArrayLitTable:  TArrayLitTable;
  ArrayLitCount:  Integer;
  HashLitTable:   THashLitTable;
  HashLitCount:   Integer;
  AstTable:       TASTTable;
  AstCount:       Integer;
  ControlTable:   TControlTable;
  ControlCount:   Integer;
  LoopStack:      Array[1..MAX_LOOP_NEST] Of Integer;
  LoopDepth:      Integer;
  ParseErrors:    Integer;
  BinCode:        TBinBuffer;
  BinData:        TBinBuffer;
  BinRData:       TBinBuffer;
  BinCodeSize:    LongInt;
  BinDataSize:    LongInt;
  BinRDataSize:   LongInt;
  BinBssSize:     LongInt;
  BinLabels:      TBinLabelTable;
  BinLabelCount:  Integer;
  BinFixups:      TBinFixupTable;
  BinFixupCount:  Integer;
  BinImports:     TBinImportTable;
  BinImportCount: Integer;

Procedure FatalError(Msg: String); Forward;
Procedure WarnMsg(Msg: String); Forward;

Function UpCaseStr(S: String): String;
Var I: Integer;
Begin
  For I := 1 To Length(S) Do S[I] := UpCase(S[I]);
  UpCaseStr := S;
End;

Function IsPathSep(C: Char): Boolean;
Begin
  IsPathSep := (C = '\') Or (C = '/');
End;

Function FileExt(S: String): String;
Var I: Integer;
Begin
  FileExt := '';
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      FileExt := Copy(S, I, Length(S) - I + 1);
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Exit;
  End;
End;

Function ChangeExt(S, NewExt: String): String;
Var I: Integer;
Begin
  For I := Length(S) DownTo 1 Do Begin
    If S[I] = '.' Then Begin
      ChangeExt := Copy(S, 1, I - 1) + NewExt;
      Exit;
    End;
    If IsPathSep(S[I]) Or (S[I] = ':') Then Break;
  End;
  ChangeExt := S + NewExt;
End;

Function IsPerlSourceName(S: String): Boolean;
Var E: String;
Begin
  E := UpCaseStr(FileExt(S));
  IsPerlSourceName := (E = '.PL') Or (E = '.PM') Or (E = '.PERL');
End;

Function DirName(Path: String): String;
Var I: Integer;
Begin
  DirName := '.';
  For I := Length(Path) DownTo 1 Do Begin
    If IsPathSep(Path[I]) Then Begin
      If I = 1 Then DirName := Copy(Path, 1, 1)
      Else DirName := Copy(Path, 1, I - 1);
      Exit;
    End;
  End;
End;

Function IsAbsPath(Path: String): Boolean;
Begin
  IsAbsPath := ((Length(Path) >= 2) And (Path[2] = ':')) Or
               ((Length(Path) >= 1) And IsPathSep(Path[1]));
End;

Function PathJoin(A, B: String): String;
Begin
  If A = '' Then PathJoin := B
  Else If B = '' Then PathJoin := A
  Else If IsAbsPath(B) Then PathJoin := B
  Else If IsPathSep(A[Length(A)]) Then PathJoin := A + B
  Else PathJoin := A + '\' + B;
End;

Function NormalizePath(Path: String): String;
Var I: Integer;
Begin
  For I := 1 To Length(Path) Do
    If Path[I] = '/' Then Path[I] := '\';
  NormalizePath := Path;
End;

Function FileExistsLocal(Path: String): Boolean;
Var
  F:    File;
  Code: Integer;
Begin
  Assign(F, Path);
  {$I-}
  Reset(F);
  {$I+}
  Code := IOResult;
  FileExistsLocal := Code = 0;
  If Code = 0 Then Close(F);
End;

Function AddPerlExt(Path: String): String;
Begin
  If FileExt(Path) = '' Then AddPerlExt := Path + '.pl'
  Else AddPerlExt := Path;
End;

Procedure Usage;
Begin
  WriteLn('PERLCW32 - Cette commande permet de lancer le compilateur Perl ',
          'pour l''assembleur du microprocesseur 80386 pour le systeme ',
          'd''exploitation Windows 32 bits (PE Win32).');
  WriteLn;
  WriteLn('Syntaxe: PERLCW32 source.pl [-o out] [-v] [-d] [-w] [-obj] [-asm] [-h]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -o out     Nom du fichier de sortie');
  WriteLn('  -v         Mode verbeux');
  WriteLn('  -d         Informations de debogage');
  WriteLn('  -w         Activer les avertissements');
  WriteLn('  -obj       Produire uniquement un .OBJ COFF 32 bits');
  WriteLn('  -asm       Produire aussi un listing assembleur .ASM');
  WriteLn('  -h         Afficher cette aide');
End;

Procedure FatalError(Msg: String);
Begin
  WriteLn('PERLCW32: erreur: ', Msg);
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Msg: String);
Begin
  If Opt.Warnings Then WriteLn('PERLCW32: avertissement: ', Msg);
End;

Procedure InitOptions;
Begin
  FillChar(Opt, SizeOf(Opt), 0);
  Opt.Warnings      := False;
  Opt.EmitExe       := True;
  Opt.EmitObj       := False;
  Opt.EmitAsm       := False;
  Opt.StrictMode    := False;
  Opt.LoadPathCount := 0;
End;

Procedure ParseArgs;
Var
  I: Integer;
  A, U: String;
Begin
  InitOptions;
  I := 1;
  While I <= ParamCount Do Begin
    A := ParamStr(I);
    U := UpCaseStr(A);
    If (U = '-H') Or (U = '/H') Or (U = '-?') Or (U = '/?') Or
       (U = '--HELP') Then Begin
      Usage;
      Halt(EXIT_USAGE);
    End Else If U = '-OBJ' Then Begin
      Opt.EmitObj := True;
      Opt.EmitExe := False;
    End Else If U = '-ASM' Then Begin
      Opt.EmitAsm := True;
    End Else If U = '-O' Then Begin
      Inc(I);
      If I > ParamCount Then FatalError('option -o sans argument');
      Opt.OutFile := ParamStr(I);
    End Else If Copy(U, 1, 2) = '-O' Then Begin
      Opt.OutFile := Copy(A, 3, Length(A) - 2);
      If Opt.OutFile = '' Then FatalError('option -o sans argument');
    End Else If U = '-V' Then Begin
      Opt.Verbose := True;
    End Else If U = '-D' Then Begin
      Opt.DebugMode := True;
    End Else If U = '-W' Then Begin
      Opt.Warnings := True;
    End Else If (Length(A) > 0) And ((A[1] = '-') Or (A[1] = '/')) Then Begin
      FatalError('option inconnue: ' + A);
    End Else Begin
      If Opt.SrcFile <> '' Then FatalError('plusieurs fichiers source specifies');
      Opt.SrcFile := A;
    End;
    Inc(I);
  End;

  If Opt.SrcFile = '' Then Begin
    Usage;
    Halt(EXIT_USAGE);
  End;
  If Not IsPerlSourceName(Opt.SrcFile) Then
    FatalError('extension source invalide (attendu .pl, .pm ou .perl)');

  If Opt.OutFile = '' Then Begin
    If Opt.EmitObj Then Opt.OutFile := ChangeExt(Opt.SrcFile, '.obj')
    Else Opt.OutFile := ChangeExt(Opt.SrcFile, '.exe');
  End;
End;

Begin
  ParseArgs;
  WriteLn('PERLCW32 v', PERLCW32_VERSION, ' (', PERLCW32_DATE,
          ') - Compilateur Perl -> 80386 PE Win32');
  If Opt.Verbose Then Begin
    WriteLn('Source : ', Opt.SrcFile);
    WriteLn('Sortie : ', Opt.OutFile);
    If Opt.EmitObj Then WriteLn('Format : OBJ COFF 32 bits')
    Else WriteLn('Format : EXE PE Win32');
    If Opt.EmitAsm Then WriteLn('ASM    : oui');
    If Opt.DebugMode Then WriteLn('Debug  : oui');
    If Opt.Warnings Then WriteLn('Warnings : oui');
  End;
  WriteLn('PERLCW32: TODO - compilateur en cours d''implementation');
  Halt(EXIT_OK);
End.
