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
  NK_CODE_BLOCK = 38;   { bloc expression pour sort/grep/map }

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
    Ctx:         Integer;   { CTX_VOID / CTX_SCALAR / CTX_LIST / CTX_BOOL }
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

{ ============================================================ }
{ TODO 02 - TOKENISEUR PERL (LEXER)                            }
{ ============================================================ }

Function IsKeyword(S: String): Integer; Forward;

Function ItoS(N: LongInt): String;
Var S: String;
Begin Str(N, S); ItoS := S; End;

Procedure AppendTok(C: Char);
Begin
  If Length(CurTokStr) < 255 Then CurTokStr := CurTokStr + C;
End;

Function IsAlpha(C: Char): Boolean;
Begin
  IsAlpha := ((C >= 'A') And (C <= 'Z')) Or ((C >= 'a') And (C <= 'z')) Or
             (C = '_');
End;

Function IsDigit(C: Char): Boolean;
Begin IsDigit := (C >= '0') And (C <= '9'); End;

Function IsHexDigit(C: Char): Boolean;
Var U: Char;
Begin
  U := UpCase(C);
  IsHexDigit := IsDigit(C) Or ((U >= 'A') And (U <= 'F'));
End;

Function IsIdentChar(C: Char): Boolean;
Begin IsIdentChar := IsAlpha(C) Or IsDigit(C); End;

Function HexVal(C: Char): Integer;
Begin
  C := UpCase(C);
  If IsDigit(C) Then HexVal := Ord(C) - Ord('0')
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

Function LexPeekChar: Char;
Begin
  If LexPos > SrcLen Then LexPeekChar := #0
  Else LexPeekChar := SrcBuf[LexPos];
End;

Function LexPeekChar2: Char;
Begin
  If LexPos + 1 > SrcLen Then LexPeekChar2 := #0
  Else LexPeekChar2 := SrcBuf[LexPos + 1];
End;

Function LexPeekChar3: Char;
Begin
  If LexPos + 2 > SrcLen Then LexPeekChar3 := #0
  Else LexPeekChar3 := SrcBuf[LexPos + 2];
End;

Function LexNextChar: Char;
Var C: Char;
Begin
  If LexPos > SrcLen Then Begin LexNextChar := #0; Exit; End;
  C := SrcBuf[LexPos];
  Inc(LexPos);
  If C = #10 Then Begin Inc(LexLine); LexCol := 1; End
  Else If C <> #13 Then Inc(LexCol);
  LexNextChar := C;
End;

Procedure LexInit(FileName: String);
Var
  F: File;
  N: LongInt;
Begin
  SrcLen := 0;
  Assign(F, FileName);
  {$I-} Reset(F, 1); {$I+}
  If IOResult <> 0 Then FatalError('impossible d''ouvrir ' + FileName);
  BlockRead(F, SrcBuf, 65535, N);
  SrcLen := N;
  If Not Eof(F) Then Begin Close(F); FatalError('fichier source trop volumineux'); End;
  Close(F);
  LexPos  := 1; LexLine := 1; LexCol := 1;
  CurTokType := TOK_EOF; CurTokStr := ''; CurTokNum := 0;
  CurTokFloat := 0; LastTokType := TOK_EOF;
  { Sauter shebang #!/usr/bin/perl en premiere ligne }
  If (SrcLen >= 2) And (SrcBuf[1] = '#') And (SrcBuf[2] = '!') Then
    While (LexPos <= SrcLen) And (SrcBuf[LexPos] <> #10) Do Inc(LexPos);
End;

Procedure LexClose;
Begin
  SrcLen := 0; LexPos := 1; LexLine := 1; LexCol := 1;
End;

Procedure SkipLineComment;
Begin
  While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do LexNextChar;
End;

(* Delimiteur fermant pour m-pat-, s-pat-rpl-, qw(), etc. *)
Function MatchingDelim(C: Char): Char;
Begin
  Case C Of
    '(': MatchingDelim := ')';
    '[': MatchingDelim := ']';
    '{': MatchingDelim := '}';
    '<': MatchingDelim := '>';
  Else MatchingDelim := C;
  End;
End;

{ Lit un identificateur ; detecte les mots-cles }
Procedure ReadIdent;
Var K: Integer;
Begin
  While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
  K := IsKeyword(CurTokStr);
  If K <> 0 Then CurTokType := K
  Else CurTokType := TOK_IDENT;
End;

{ Lit les variables speciales $! $/ $\ $0 $1..$9 $$ $_ etc. }
Procedure ReadSpecialScalar;
Var C: Char;
Begin
  C := LexPeekChar;
  { $0..$9 : variables capture regex }
  If IsDigit(C) Then Begin AppendTok(LexNextChar); Exit; End;
  { $_ $! $/ $\ $, $; $. $| $$ $0 $@ $& $` $' $+ $~ $- $= $^ }
  Case C Of
    '_','!','/','|',',',';','.','$','@','&','`','+','~','-','=','^','<','>':
      Begin AppendTok(LexNextChar); Exit; End;
    '\': Begin AppendTok(LexNextChar); Exit; End;
    '"': Begin AppendTok(LexNextChar); Exit; End;
  End;
  { $name : variable scalaire normale }
  If IsAlpha(C) Then
    While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
End;

{ Lit $var, @var, %var, &sub, $#arr }
Procedure ReadSigil;
Var
  Sigil: Char;
Begin
  Sigil := LexNextChar;
  AppendTok(Sigil);
  Case Sigil Of
    '$': Begin
           CurTokType := TOK_SIGIL_SCALAR;
           { $#arr -> dernier index }
           If (LexPeekChar = '#') And IsAlpha(LexPeekChar2) Then Begin
             CurTokType := TOK_HASHNUM;
             AppendTok(LexNextChar);
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
           End Else
             ReadSpecialScalar;
         End;
    '@': Begin
           CurTokType := TOK_SIGIL_ARRAY;
           If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
         End;
    '%': Begin
           CurTokType := TOK_SIGIL_HASH;
           If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
         End;
    '&': Begin
           CurTokType := TOK_SIGIL_CODE;
           If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
         End;
  End;
End;

{ Lit un nombre : 123, 1_000, 0xFF, 0b101, 0777, 1.5, 1.5e3 }
Procedure ReadNumber;
Var
  Base, V: Integer;
  IsFloat: Boolean;
  C: Char;
Begin
  CurTokType := TOK_INTEGER;
  CurTokNum  := 0;
  IsFloat    := False;
  Base       := 10;
  If (LexPeekChar = '0') And
     ((UpCase(LexPeekChar2) = 'X') Or (UpCase(LexPeekChar2) = 'B') Or
      (UpCase(LexPeekChar2) = 'O')) Then Begin
    AppendTok(LexNextChar);
    C := UpCase(LexNextChar); AppendTok(C);
    If C = 'X' Then Base := 16
    Else If C = 'B' Then Base := 2
    Else Base := 8;
  End Else If LexPeekChar = '0' Then
    Base := 8;

  While True Do Begin
    C := LexPeekChar;
    If C = '_' Then Begin AppendTok(LexNextChar); Continue; End;
    If (Base = 16) And IsHexDigit(C) Then Begin
      V := HexVal(C); CurTokNum := CurTokNum * Base + V; AppendTok(LexNextChar);
    End Else If (Base = 10) And IsDigit(C) Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0'); AppendTok(LexNextChar);
    End Else If (Base = 8) And (C >= '0') And (C <= '7') Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0'); AppendTok(LexNextChar);
    End Else If (Base = 2) And ((C = '0') Or (C = '1')) Then Begin
      CurTokNum := CurTokNum * Base + Ord(C) - Ord('0'); AppendTok(LexNextChar);
    End Else Break;
  End;

  If (Base = 10) And (LexPeekChar = '.') And IsDigit(LexPeekChar2) Then Begin
    IsFloat := True; AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Or (LexPeekChar = '_') Do AppendTok(LexNextChar);
  End;
  If (Base = 10) And (UpCase(LexPeekChar) = 'E') Then Begin
    IsFloat := True; AppendTok(LexNextChar);
    If (LexPeekChar = '+') Or (LexPeekChar = '-') Then AppendTok(LexNextChar);
    While IsDigit(LexPeekChar) Or (LexPeekChar = '_') Do AppendTok(LexNextChar);
  End;
  If IsFloat Then Begin
    CurTokType := TOK_FLOAT;
    CurTokFloat := 0;
  End;
End;

{ Lit une chaine simple 'text' : echappements \\ et \' seulement }
Procedure ReadSingleString;
Var C: Char;
Begin
  CurTokType := TOK_STRING;
  LexNextChar; { consume ' }
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('chaine simple non terminee');
    If C = '''' Then Break;
    If C = '\' Then Begin
      C := LexNextChar;
      If C = #0 Then FatalError('chaine simple non terminee');
      If (C = '\') Or (C = '''') Then AppendTok(C)
      Else Begin AppendTok('\'); AppendTok(C); End;
    End Else AppendTok(C);
  End;
End;

(* Lecture echappement \xHHHH ou \xHH *)
Procedure ReadHexEscape;
Var
  H1, H2: Char;
  Depth: Integer;
Begin
  If LexPeekChar = '{' Then Begin
    LexNextChar; Depth := 0;
    While (LexPeekChar <> #0) And (LexPeekChar <> '}') Do Begin
      H1 := LexNextChar;
      If IsHexDigit(H1) And (Depth < 2) Then
        AppendTok(Chr(HexVal(H1)));
      Inc(Depth);
    End;
    If LexPeekChar = '}' Then LexNextChar;
  End Else Begin
    H1 := LexNextChar; H2 := LexNextChar;
    If IsHexDigit(H1) And IsHexDigit(H2) Then
      AppendTok(Chr(HexVal(H1) * 16 + HexVal(H2)))
    Else FatalError('echappement \x invalide');
  End;
End;

{ Lit une chaine double "text $var @arr \n \t \xFF" }
Procedure ReadDoubleString;
Var C: Char;
Begin
  CurTokType := TOK_DSTRING;
  LexNextChar; { consume " }
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('chaine double non terminee');
    If C = '"' Then Break;
    If C = '\' Then Begin
      C := LexNextChar;
      If C = #0 Then FatalError('chaine double non terminee');
      Case C Of
        'n': AppendTok(#10);
        't': AppendTok(#9);
        'r': AppendTok(#13);
        'f': AppendTok(#12);
        'a': AppendTok(#7);
        'e': AppendTok(#27);
        '0': AppendTok(#0);
        '\': AppendTok('\');
        '"': AppendTok('"');
        '$': AppendTok('$');
        '@': AppendTok('@');
        'x': ReadHexEscape;
        'l','u','L','U','Q','E': { modificateurs casse : ignore pour compat }
          AppendTok(C);
      Else
        AppendTok('\'); AppendTok(C);
      End;
    End Else If C = '$' Then Begin
      AppendTok(C);
      { Marque le debut d interpolation scalaire ou tableau }
      If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Or (LexPeekChar = '{') Then
        AppendTok('S')  { hint pour parseur d interpolation }
    End Else If C = '@' Then Begin
      AppendTok(C);
      If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
        AppendTok('A')  { hint tableau }
    End Else
      AppendTok(C);
  End;
End;

{ Lit un heredoc : <<EOF, <<'EOF', <<"EOF", <<~EOF }
Function TryReadHeredoc: Boolean;
Var
  SavePos, SaveLine, SaveCol: LongInt;
  C, Quote: Char;
  Delim, Line, Check: String;
  Squiggly: Boolean;

  Procedure AppBody(S: String);
  Var I: Integer;
  Begin For I := 1 To Length(S) Do AppendTok(S[I]); End;

  Function LTrim(S: String): String;
  Begin
    While (Length(S) > 0) And ((S[1] = ' ') Or (S[1] = #9)) Do Delete(S, 1, 1);
    LTrim := S;
  End;
Begin
  TryReadHeredoc := False;
  SavePos := LexPos; SaveLine := LexLine; SaveCol := LexCol;
  CurTokStr := ''; Delim := ''; Squiggly := False;
  LexNextChar; LexNextChar; { consume << }
  If LexPeekChar = '~' Then Begin Squiggly := True; LexNextChar; End
  Else If LexPeekChar = '-' Then LexNextChar; { <<-EOF : equivalent a <<~ }
  While (LexPeekChar = ' ') Or (LexPeekChar = #9) Do LexNextChar;
  Quote := #0;
  If (LexPeekChar = '"') Or (LexPeekChar = '''') Or (LexPeekChar = '`') Then
    Quote := LexNextChar;
  If Not IsAlpha(LexPeekChar) Then Begin
    LexPos := SavePos; LexLine := SaveLine; LexCol := SaveCol;
    CurTokStr := ''; Exit;
  End;
  While IsIdentChar(LexPeekChar) Do Begin
    C := LexNextChar;
    If Length(Delim) < 255 Then Delim := Delim + C;
  End;
  If Quote <> #0 Then Begin
    C := LexNextChar;
    If C <> Quote Then FatalError('delimiteur heredoc invalide');
  End;
  { Sauter reste de la ligne courante }
  While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do LexNextChar;
  If LexPeekChar = #10 Then LexNextChar;
  CurTokStr := '';
  While True Do Begin
    Line := '';
    While (LexPeekChar <> #0) And (LexPeekChar <> #10) Do Begin
      C := LexNextChar;
      If (C <> #13) And (Length(Line) < 255) Then Line := Line + C;
    End;
    Check := Line;
    If Squiggly Then Check := LTrim(Check);
    If Check = Delim Then Begin
      If LexPeekChar = #10 Then LexNextChar;
      Break;
    End;
    AppBody(Line);
    If LexPeekChar = #10 Then Begin AppendTok(#10); LexNextChar; End
    Else If LexPeekChar = #0 Then FatalError('heredoc non termine : ' + Delim);
  End;
  If Quote = '''' Then CurTokType := TOK_STRING
  Else CurTokType := TOK_HEREDOC;
  TryReadHeredoc := True;
End;

{ Lit /pattern/flags ou le corps apres m (delimiteur deja consomme) }
Procedure ReadRegexBody(OpenDelim: Char);
Var
  C:        Char;
  CloseD:   Char;
  InClass:  Boolean;
  Depth:    Integer;
Begin
  CloseD  := MatchingDelim(OpenDelim);
  Depth   := 1;
  InClass := False;
  If OpenDelim = CloseD Then Begin
    { Delimiteur non paire : /pat/ }
    While True Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('regex non terminee');
      If (C = OpenDelim) And Not InClass Then Break;
      If C = '\' Then Begin
        AppendTok(C); C := LexNextChar;
        If C = #0 Then FatalError('regex non terminee');
      End Else If C = '[' Then InClass := True
      Else If C = ']' Then InClass := False;
      AppendTok(C);
    End;
  End Else Begin
    (* Delimiteur paire : m-pat- *)
    AppendTok(OpenDelim);
    While Depth > 0 Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('regex non terminee');
      If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End
      Else If C = OpenDelim Then Inc(Depth)
      Else If C = CloseD Then Begin Dec(Depth); If Depth = 0 Then Break; End;
      AppendTok(C);
    End;
    AppendTok(CloseD);
  End;
  AppendTok('/'); { marqueur fin pattern dans CurTokStr }
  { Lire les flags : i g m s x e r }
  While LexPeekChar In ['i','g','m','s','x','e','r','o'] Do
    AppendTok(LexNextChar);
End;

(* Lit s/pat/rpl/flags ou s-pat--rpl-flags *)
Procedure ReadSubst(OpenDelim: Char);
Var
  C, CloseD, OpenR, CloseR: Char;
  InClass: Boolean;
  Depth: Integer;
Begin
  CurTokType := TOK_SUBST;
  CloseD := MatchingDelim(OpenDelim);
  InClass := False;
  { Pattern }
  If OpenDelim = CloseD Then Begin
    While True Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('s/// pattern non termine');
      If (C = OpenDelim) And Not InClass Then Break;
      If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End
      Else If C = '[' Then InClass := True
      Else If C = ']' Then InClass := False;
      AppendTok(C);
    End;
    AppendTok('/');
    { Remplacement }
    While True Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('s/// remplacement non termine');
      If C = OpenDelim Then Break;
      If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End;
      AppendTok(C);
    End;
    AppendTok('/');
  End Else Begin
    (* s-pat--rpl- *)
    AppendTok(OpenDelim);
    Depth := 1;
    While Depth > 0 Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('s{}{} pattern non termine');
      If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End
      Else If C = OpenDelim Then Inc(Depth)
      Else If C = CloseD Then Begin Dec(Depth); If Depth = 0 Then Break; End;
      AppendTok(C);
    End;
    AppendTok(CloseD);
    While (LexPeekChar = ' ') Or (LexPeekChar = #9) Do LexNextChar;
    OpenR  := LexNextChar; CloseR := MatchingDelim(OpenR);
    AppendTok(OpenR);
    Depth := 1;
    While Depth > 0 Do Begin
      C := LexNextChar;
      If C = #0 Then FatalError('s{}{} remplacement non termine');
      If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End
      Else If C = OpenR Then Inc(Depth)
      Else If C = CloseR Then Begin Dec(Depth); If Depth = 0 Then Break; End;
      AppendTok(C);
    End;
    AppendTok(CloseR);
  End;
  While LexPeekChar In ['i','g','m','s','x','e','r','o'] Do AppendTok(LexNextChar);
End;

{ Lit tr/lst/lst/flags ou y/lst/lst/flags }
Procedure ReadTrans(OpenDelim: Char);
Var
  C, CloseD: Char;
Begin
  CurTokType := TOK_TRANS;
  CloseD := MatchingDelim(OpenDelim);
  { Liste source }
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('tr/// liste non terminee');
    If C = OpenDelim Then Break;
    If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End;
    AppendTok(C);
  End;
  AppendTok('/');
  { Delimiteur de remplacement (peut etre different si paire) }
  If OpenDelim <> CloseD Then Begin
    While (LexPeekChar = ' ') Or (LexPeekChar = #9) Do LexNextChar;
    OpenDelim := LexNextChar; CloseD := MatchingDelim(OpenDelim);
    AppendTok(OpenDelim);
  End;
  While True Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('tr/// remplacement non termine');
    If C = CloseD Then Break;
    If C = '\' Then Begin AppendTok(C); C := LexNextChar; If C = #0 Then Break; End;
    AppendTok(C);
  End;
  AppendTok('/');
  While LexPeekChar In ['c','d','s'] Do AppendTok(LexNextChar);
End;

(* Lit qw() -> TOK_QWORD, q-x- -> TOK_STRING, qq-x- -> TOK_DSTRING *)
Procedure ReadQuoteLike(Kind: Char; OpenDelim: Char);
Var
  C, CloseD: Char;
  Depth: Integer;
Begin
  Case Kind Of
    'w': CurTokType := TOK_QWORD;
    'q': CurTokType := TOK_STRING;
  Else CurTokType := TOK_DSTRING;
  End;
  CloseD := MatchingDelim(OpenDelim);
  Depth := 1;
  While Depth > 0 Do Begin
    C := LexNextChar;
    If C = #0 Then FatalError('litteral q non termine');
    If C = '\' Then Begin
      AppendTok(C); C := LexNextChar;
      If C = #0 Then FatalError('litteral q non termine');
      AppendTok(C); Continue;
    End;
    If OpenDelim <> CloseD Then Begin
      If C = OpenDelim Then Inc(Depth)
      Else If C = CloseD Then Begin Dec(Depth); If Depth = 0 Then Break; End;
    End Else If C = OpenDelim Then Begin
      Dec(Depth); If Depth = 0 Then Break;
    End;
    AppendTok(C);
  End;
End;

{ Vrai si le token precedent peut terminer une expression }
Function TokCanEndExpr(T: Integer): Boolean;
Begin
  TokCanEndExpr :=
    (T = TOK_IDENT) Or (T = TOK_SIGIL_SCALAR) Or (T = TOK_SIGIL_ARRAY) Or
    (T = TOK_SIGIL_HASH) Or (T = TOK_SIGIL_CODE) Or (T = TOK_HASHNUM) Or
    (T = TOK_INTEGER) Or (T = TOK_FLOAT) Or
    (T = TOK_STRING) Or (T = TOK_DSTRING) Or (T = TOK_HEREDOC) Or
    (T = TOK_QWORD) Or (T = TOK_REGEX) Or (T = TOK_SUBST) Or (T = TOK_TRANS) Or
    (T = TOK_INCR) Or (T = TOK_DECR) Or
    (T = Ord(')')) Or (T = Ord(']')) Or (T = Ord('}')) Or
    (T = KW_UNDEF) Or (T = KW_MY) Or (T = KW_OUR) Or (T = KW_LOCAL);
End;

Procedure LexNextToken;
Var
  C, C2, C3: Char;
  Done: Boolean;
  PrevEnd: Boolean;
  K: Integer;
Begin
  CurTokStr := ''; CurTokNum := 0; CurTokFloat := 0;
  PrevEnd := TokCanEndExpr(LastTokType);
  Done := False;
  While Not Done Do Begin
    C := LexPeekChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Then LexNextChar
    Else If C = '#' Then SkipLineComment
    Else Done := True;
  End;

  CurTokLine := LexLine; CurTokCol := LexCol;
  C  := LexPeekChar;
  C2 := LexPeekChar2;
  C3 := LexPeekChar3;

  If C = #0 Then CurTokType := TOK_EOF

  Else If (C = '$') Or (C = '@') Or (C = '%') Then ReadSigil
  Else If C = '&' Then Begin
    { & seul peut etre AND bit ou appel &sub }
    If IsAlpha(C2) Or (C2 = '_') Then ReadSigil
    Else If C2 = '&' Then Begin
      If C3 = '=' Then Begin
        CurTokType := TOK_ASSIGN_OP;
        AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
      End Else Begin
        CurTokType := TOK_ANDAND;
        AppendTok(LexNextChar); AppendTok(LexNextChar);
      End;
    End Else If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin
      CurTokType := Ord('&'); AppendTok(LexNextChar);
    End;
  End

  Else If IsAlpha(C) Then Begin
    (* Mots-cles speciaux : m// s/// tr/// y/// q qq qw qr *)
    AppendTok(LexNextChar);
    If (CurTokStr = 'm') And Not IsIdentChar(LexPeekChar) Then Begin
      (* m/pat/flags ou m-pat- *)
      CurTokType := TOK_REGEX; CurTokStr := '';
      ReadRegexBody(LexNextChar);
    End Else If (CurTokStr = 's') And Not IsIdentChar(LexPeekChar) Then Begin
      CurTokStr := ''; ReadSubst(LexNextChar);
    End Else If ((CurTokStr = 'tr') Or (CurTokStr = 'y')) And Not IsIdentChar(LexPeekChar) Then Begin
      If CurTokStr = 'y' Then C2 := LexNextChar  { y/// }
      Else C2 := LexNextChar;
      CurTokStr := ''; ReadTrans(C2);
    End Else If (CurTokStr = 'q') And Not IsIdentChar(LexPeekChar) Then Begin
      CurTokStr := ''; ReadQuoteLike('q', LexNextChar);
    End Else If (CurTokStr = 'qq') And Not IsIdentChar(LexPeekChar) Then Begin
      CurTokStr := ''; ReadQuoteLike('Q', LexNextChar);
    End Else If (CurTokStr = 'qw') And Not IsIdentChar(LexPeekChar) Then Begin
      CurTokStr := ''; ReadQuoteLike('w', LexNextChar);
    End Else If (CurTokStr = 'qr') And Not IsIdentChar(LexPeekChar) Then Begin
      CurTokType := TOK_REGEX; CurTokStr := '';
      ReadRegexBody(LexNextChar);
    End Else Begin
      { Continuer la lecture de l identificateur }
      While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
      { tr necessite deux caracteres lus avant verification }
      If ((CurTokStr = 'tr') Or (CurTokStr = 'y')) And Not IsIdentChar(LexPeekChar) Then Begin
        CurTokStr := ''; ReadTrans(LexNextChar);
      End Else Begin
        K := IsKeyword(CurTokStr);
        If K <> 0 Then CurTokType := K Else CurTokType := TOK_IDENT;
      End;
    End;
  End

  Else If IsDigit(C) Then ReadNumber
  Else If C = '''' Then ReadSingleString
  Else If C = '"' Then ReadDoubleString

  { Heredoc << }
  Else If (C = '<') And (C2 = '<') And Not PrevEnd And TryReadHeredoc Then Begin
    { TryReadHeredoc a rempli CurTokStr et CurTokType }
  End

  { Operateurs multi-caracteres }
  Else If (C = '<') And (C2 = '<') And (C3 = '=') Then Begin
    CurTokType := TOK_ASSIGN_OP;
    AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '>') And (C2 = '>') And (C3 = '=') Then Begin
    CurTokType := TOK_ASSIGN_OP;
    AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '*') And (C2 = '*') And (C3 = '=') Then Begin
    CurTokType := TOK_ASSIGN_OP;
    AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '<') And (C2 = '=') And (C3 = '>') Then Begin
    CurTokType := TOK_SPACESHIP;
    AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '.') And (C2 = '.') And (C3 = '.') Then Begin
    CurTokType := TOK_DOTDOTDOT;
    AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '.') And (C2 = '.') Then Begin
    CurTokType := TOK_DOTDOT; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '=') And (C2 = '>') Then Begin
    CurTokType := TOK_FATCOMMA; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '=') And (C2 = '~') Then Begin
    CurTokType := TOK_MATCH; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '!') And (C2 = '~') Then Begin
    CurTokType := TOK_NMATCH; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '-') And (C2 = '>') Then Begin
    CurTokType := TOK_ARROW; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '*') And (C2 = '*') Then Begin
    CurTokType := TOK_POW; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '<') And (C2 = '<') Then Begin
    CurTokType := TOK_SHL; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '>') And (C2 = '>') Then Begin
    CurTokType := TOK_SHR; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '<') And (C2 = '=') Then Begin
    CurTokType := TOK_LE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '>') And (C2 = '=') Then Begin
    CurTokType := TOK_GE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '=') And (C2 = '=') Then Begin
    CurTokType := TOK_EQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '!') And (C2 = '=') Then Begin
    CurTokType := TOK_NE; AppendTok(LexNextChar); AppendTok(LexNextChar);
  End
  Else If (C = '|') And (C2 = '|') Then Begin
    If C3 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP;
      AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin
      CurTokType := TOK_OROR; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End;
  End
  Else If C = '|' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin
      CurTokType := Ord('|'); AppendTok(LexNextChar);
    End;
  End
  { // defini-ou vs division }
  Else If (C = '/') And (C2 = '/') Then Begin
    If C3 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP;
      AppendTok(LexNextChar); AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin
      CurTokType := TOK_DEFOR; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End;
  End
  Else If C = '/' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else If Not PrevEnd Then Begin
      { Regex }
      CurTokType := TOK_REGEX; LexNextChar;
      ReadRegexBody('/');
    End Else Begin
      CurTokType := Ord('/'); AppendTok(LexNextChar);
    End;
  End
  Else If C = '+' Then Begin
    If C2 = '+' Then Begin
      CurTokType := TOK_INCR; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('+'); AppendTok(LexNextChar); End;
  End
  Else If C = '-' Then Begin
    If C2 = '-' Then Begin
      CurTokType := TOK_DECR; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('-'); AppendTok(LexNextChar); End;
  End
  Else If C = '*' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('*'); AppendTok(LexNextChar); End;
  End
  Else If C = '%' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('%'); AppendTok(LexNextChar); End;
  End
  Else If C = '.' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else If IsDigit(C2) Then ReadNumber
    Else Begin CurTokType := Ord('.'); AppendTok(LexNextChar); End;
  End
  Else If C = '^' Then Begin
    If C2 = '=' Then Begin
      CurTokType := TOK_ASSIGN_OP; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('^'); AppendTok(LexNextChar); End;
  End
  Else If C = '~' Then Begin CurTokType := Ord('~'); AppendTok(LexNextChar); End
  Else If C = '!' Then Begin CurTokType := Ord('!'); AppendTok(LexNextChar); End
  Else If C = '=' Then Begin
    If C2 = '=' Then Begin
      { Deja traite plus haut mais au cas ou }
      CurTokType := TOK_EQ; AppendTok(LexNextChar); AppendTok(LexNextChar);
    End Else Begin CurTokType := Ord('='); AppendTok(LexNextChar); End;
  End
  Else If C = '<' Then Begin CurTokType := Ord('<'); AppendTok(LexNextChar); End
  Else If C = '>' Then Begin CurTokType := Ord('>'); AppendTok(LexNextChar); End
  Else Begin
    CurTokType := Ord(C); AppendTok(LexNextChar);
  End;

  LastTokType := CurTokType;
End;

Function TokenName(T: Integer): String;
Begin
  Case T Of
    TOK_EOF:          TokenName := 'TOK_EOF';
    TOK_IDENT:        TokenName := 'TOK_IDENT';
    TOK_SIGIL_SCALAR: TokenName := 'TOK_SIGIL_SCALAR';
    TOK_SIGIL_ARRAY:  TokenName := 'TOK_SIGIL_ARRAY';
    TOK_SIGIL_HASH:   TokenName := 'TOK_SIGIL_HASH';
    TOK_SIGIL_CODE:   TokenName := 'TOK_SIGIL_CODE';
    TOK_INTEGER:      TokenName := 'TOK_INTEGER';
    TOK_FLOAT:        TokenName := 'TOK_FLOAT';
    TOK_STRING:       TokenName := 'TOK_STRING';
    TOK_DSTRING:      TokenName := 'TOK_DSTRING';
    TOK_HEREDOC:      TokenName := 'TOK_HEREDOC';
    TOK_REGEX:        TokenName := 'TOK_REGEX';
    TOK_SUBST:        TokenName := 'TOK_SUBST';
    TOK_TRANS:        TokenName := 'TOK_TRANS';
    TOK_QWORD:        TokenName := 'TOK_QWORD';
    TOK_DOTDOT:       TokenName := 'TOK_DOTDOT';
    TOK_DOTDOTDOT:    TokenName := 'TOK_DOTDOTDOT';
    TOK_FATCOMMA:     TokenName := 'TOK_FATCOMMA';
    TOK_SPACESHIP:    TokenName := 'TOK_SPACESHIP';
    TOK_CMP:          TokenName := 'TOK_CMP';
    TOK_DEFOR:        TokenName := 'TOK_DEFOR';
    TOK_MATCH:        TokenName := 'TOK_MATCH';
    TOK_NMATCH:       TokenName := 'TOK_NMATCH';
    TOK_POW:          TokenName := 'TOK_POW';
    TOK_SHL:          TokenName := 'TOK_SHL';
    TOK_SHR:          TokenName := 'TOK_SHR';
    TOK_LE:           TokenName := 'TOK_LE';
    TOK_GE:           TokenName := 'TOK_GE';
    TOK_EQ:           TokenName := 'TOK_EQ';
    TOK_NE:           TokenName := 'TOK_NE';
    TOK_ANDAND:       TokenName := 'TOK_ANDAND';
    TOK_OROR:         TokenName := 'TOK_OROR';
    TOK_ASSIGN_OP:    TokenName := 'TOK_ASSIGN_OP';
    TOK_ARROW:        TokenName := 'TOK_ARROW';
    TOK_INCR:         TokenName := 'TOK_INCR';
    TOK_DECR:         TokenName := 'TOK_DECR';
    TOK_HASHNUM:      TokenName := 'TOK_HASHNUM';
    TOK_DEREF_SCALAR: TokenName := 'TOK_DEREF_SCALAR';
    TOK_DEREF_ARRAY:  TokenName := 'TOK_DEREF_ARRAY';
    TOK_DEREF_HASH:   TokenName := 'TOK_DEREF_HASH';
    KW_MY:            TokenName := 'KW_MY';
    KW_OUR:           TokenName := 'KW_OUR';
    KW_LOCAL:         TokenName := 'KW_LOCAL';
    KW_SUB:           TokenName := 'KW_SUB';
    KW_IF:            TokenName := 'KW_IF';
    KW_ELSIF:         TokenName := 'KW_ELSIF';
    KW_ELSE:          TokenName := 'KW_ELSE';
    KW_UNLESS:        TokenName := 'KW_UNLESS';
    KW_WHILE:         TokenName := 'KW_WHILE';
    KW_UNTIL:         TokenName := 'KW_UNTIL';
    KW_FOR:           TokenName := 'KW_FOR';
    KW_FOREACH:       TokenName := 'KW_FOREACH';
    KW_DO:            TokenName := 'KW_DO';
    KW_LAST:          TokenName := 'KW_LAST';
    KW_NEXT:          TokenName := 'KW_NEXT';
    KW_REDO:          TokenName := 'KW_REDO';
    KW_RETURN:        TokenName := 'KW_RETURN';
    KW_USE:           TokenName := 'KW_USE';
    KW_PACKAGE:       TokenName := 'KW_PACKAGE';
    KW_PRINT:         TokenName := 'KW_PRINT';
    KW_SAY:           TokenName := 'KW_SAY';
    KW_PRINTF:        TokenName := 'KW_PRINTF';
    KW_SPRINTF:       TokenName := 'KW_SPRINTF';
    KW_PUSH:          TokenName := 'KW_PUSH';
    KW_POP:           TokenName := 'KW_POP';
    KW_SHIFT:         TokenName := 'KW_SHIFT';
    KW_UNSHIFT:       TokenName := 'KW_UNSHIFT';
    KW_SORT:          TokenName := 'KW_SORT';
    KW_REVERSE:       TokenName := 'KW_REVERSE';
    KW_SCALAR:        TokenName := 'KW_SCALAR';
    KW_KEYS:          TokenName := 'KW_KEYS';
    KW_VALUES:        TokenName := 'KW_VALUES';
    KW_EACH:          TokenName := 'KW_EACH';
    KW_EXISTS:        TokenName := 'KW_EXISTS';
    KW_DELETE:        TokenName := 'KW_DELETE';
    KW_DEFINED:       TokenName := 'KW_DEFINED';
    KW_UNDEF:         TokenName := 'KW_UNDEF';
    KW_DIE:           TokenName := 'KW_DIE';
    KW_WARN:          TokenName := 'KW_WARN';
    KW_OPEN:          TokenName := 'KW_OPEN';
    KW_CLOSE:         TokenName := 'KW_CLOSE';
    KW_READLINE:      TokenName := 'KW_READLINE';
    KW_EOF_FUNC:      TokenName := 'KW_EOF';
    KW_AND:           TokenName := 'KW_AND';
    KW_OR:            TokenName := 'KW_OR';
    KW_NOT:           TokenName := 'KW_NOT';
    KW_XOR:           TokenName := 'KW_XOR';
    KW_MAP:           TokenName := 'KW_MAP';
    KW_GREP:          TokenName := 'KW_GREP';
    KW_JOIN:          TokenName := 'KW_JOIN';
    KW_SPLIT:         TokenName := 'KW_SPLIT';
    KW_ABS:           TokenName := 'KW_ABS';
    KW_CHOMP:         TokenName := 'KW_CHOMP';
    KW_LENGTH:        TokenName := 'KW_LENGTH';
    KW_SUBSTR:        TokenName := 'KW_SUBSTR';
    KW_UC:            TokenName := 'KW_UC';
    KW_LC:            TokenName := 'KW_LC';
    KW_BEGIN:         TokenName := 'KW_BEGIN';
    KW_END:           TokenName := 'KW_END';
    KW_FORMAT:        TokenName := 'KW_FORMAT';
    KW_WANTARRAY:     TokenName := 'KW_WANTARRAY';
    KW_REF:           TokenName := 'KW_REF';
    KW_BLESS:         TokenName := 'KW_BLESS';
  Else
    If (T > 0) And (T < 128) Then TokenName := '''' + Chr(T) + ''''
    Else TokenName := 'TOK_' + ItoS(T);
  End;
End;

Procedure DumpTokens;
Begin
  LexInit(Opt.SrcFile);
  Repeat
    LexNextToken;
    WriteLn(CurTokLine:4, ':', CurTokCol:3, '  ', TokenName(CurTokType),
            '  [', CurTokStr, ']');
  Until CurTokType = TOK_EOF;
  LexClose;
End;

{ ============================================================ }
{ TODO 03 - MOTS-CLES ET FONCTIONS INTEGREES PERL              }
{ ============================================================ }

Const
  KW_X_REP    = 1085;  { operateur x : "str" x N, LIST x N }
  KW_BINMODE  = 1087;
  KW_LCHOP    = 1088;  { lcfirst }
  KW_UCHOP    = 1089;  { ucfirst }
  KW_RINDEX   = 1090;
  KW_POS      = 1091;
  KW_SPRINTF2 = 1092;  { alias }
  KW_UNLINK   = 1093;
  KW_RENAME   = 1094;
  KW_STAT     = 1095;
  KW_CHDIR    = 1096;
  KW_SLEEP    = 1097;
  KW_TIME     = 1098;
  KW_RAND     = 1099;
  KW_SRAND    = 1100;
  KW_ATAN2    = 1101;
  KW_SIN      = 1102;
  KW_COS      = 1103;
  KW_LOG      = 1104;
  KW_EXP      = 1105;
  KW_QUOTEMETA= 1106;
  KW_LCASE    = 1107;  { lc }
  KW_UCFIRST  = 1108;
  KW_LCFIRST  = 1109;
  KW_SPRINTF3 = 1110;
  KW_TIED2    = 1111;
  KW_UNTIE    = 1112;
  KW_DO_FILE  = 1113;  { do "file" }
  KW_REQUIRE  = 1114;
  KW_IMPORT   = 1115;
  KW_CALLER   = 1116;
  KW_WANTARR2 = 1117;

Function IsKeyword(S: String): Integer;
Begin
  IsKeyword := 0;
  { --- Mots-cles structures (reserves stricts) --- }
  If      S = 'and'       Then IsKeyword := KW_AND
  Else If S = 'BEGIN'     Then IsKeyword := KW_BEGIN
  Else If S = 'END'       Then IsKeyword := KW_END
  Else If S = 'do'        Then IsKeyword := KW_DO
  Else If S = 'else'      Then IsKeyword := KW_ELSE
  Else If S = 'elsif'     Then IsKeyword := KW_ELSIF
  Else If S = 'eval'      Then IsKeyword := KW_EVAL
  Else If S = 'for'       Then IsKeyword := KW_FOR
  Else If S = 'foreach'   Then IsKeyword := KW_FOREACH
  Else If S = 'format'    Then IsKeyword := KW_FORMAT
  Else If S = 'goto'      Then IsKeyword := KW_GOTO
  Else If S = 'if'        Then IsKeyword := KW_IF
  Else If S = 'last'      Then IsKeyword := KW_LAST
  Else If S = 'local'     Then IsKeyword := KW_LOCAL
  Else If S = 'my'        Then IsKeyword := KW_MY
  Else If S = 'next'      Then IsKeyword := KW_NEXT
  Else If S = 'no'        Then IsKeyword := KW_NO
  Else If S = 'not'       Then IsKeyword := KW_NOT
  Else If S = 'or'        Then IsKeyword := KW_OR
  Else If S = 'our'       Then IsKeyword := KW_OUR
  Else If S = 'package'   Then IsKeyword := KW_PACKAGE
  Else If S = 'redo'      Then IsKeyword := KW_REDO
  Else If S = 'return'    Then IsKeyword := KW_RETURN
  Else If S = 'sub'       Then IsKeyword := KW_SUB
  Else If S = 'tie'       Then IsKeyword := KW_TIE
  Else If S = 'tied'      Then IsKeyword := KW_TIED
  Else If S = 'unless'    Then IsKeyword := KW_UNLESS
  Else If S = 'until'     Then IsKeyword := KW_UNTIL
  Else If S = 'use'       Then IsKeyword := KW_USE
  Else If S = 'while'     Then IsKeyword := KW_WHILE
  Else If S = 'xor'       Then IsKeyword := KW_XOR
  Else If S = 'undef'     Then IsKeyword := KW_UNDEF
  Else If S = 'x'         Then IsKeyword := KW_X_REP
  Else If S = 'wantarray' Then IsKeyword := KW_WANTARRAY
  Else If S = 'require'   Then IsKeyword := KW_REQUIRE
  Else If S = 'import'    Then IsKeyword := KW_IMPORT
  Else If S = 'caller'    Then IsKeyword := KW_CALLER
  { --- Operateurs de comparaison chaine --- }
  Else If S = 'eq'        Then IsKeyword := KW_EQ_STR
  Else If S = 'ne'        Then IsKeyword := KW_NE_STR
  Else If S = 'lt'        Then IsKeyword := KW_LT_STR
  Else If S = 'gt'        Then IsKeyword := KW_GT_STR
  Else If S = 'le'        Then IsKeyword := KW_LE_STR
  Else If S = 'ge'        Then IsKeyword := KW_GE_STR
  Else If S = 'cmp'       Then IsKeyword := TOK_CMP
  { --- Fonctions integrees E/S --- }
  Else If S = 'print'     Then IsKeyword := KW_PRINT
  Else If S = 'say'       Then IsKeyword := KW_SAY
  Else If S = 'printf'    Then IsKeyword := KW_PRINTF
  Else If S = 'sprintf'   Then IsKeyword := KW_SPRINTF
  Else If S = 'warn'      Then IsKeyword := KW_WARN
  Else If S = 'die'       Then IsKeyword := KW_DIE
  Else If S = 'exit'      Then IsKeyword := KW_EXIT
  Else If S = 'open'      Then IsKeyword := KW_OPEN
  Else If S = 'close'     Then IsKeyword := KW_CLOSE
  Else If S = 'readline'  Then IsKeyword := KW_READLINE
  Else If S = 'eof'       Then IsKeyword := KW_EOF_FUNC
  Else If S = 'binmode'   Then IsKeyword := KW_BINMODE
  Else If S = 'read'      Then IsKeyword := KW_READLINE
  { --- Fonctions tableaux --- }
  Else If S = 'push'      Then IsKeyword := KW_PUSH
  Else If S = 'pop'       Then IsKeyword := KW_POP
  Else If S = 'shift'     Then IsKeyword := KW_SHIFT
  Else If S = 'unshift'   Then IsKeyword := KW_UNSHIFT
  Else If S = 'splice'    Then IsKeyword := KW_SPLICE
  Else If S = 'scalar'    Then IsKeyword := KW_SCALAR
  Else If S = 'reverse'   Then IsKeyword := KW_REVERSE
  Else If S = 'sort'      Then IsKeyword := KW_SORT
  Else If S = 'grep'      Then IsKeyword := KW_GREP
  Else If S = 'map'       Then IsKeyword := KW_MAP
  Else If S = 'join'      Then IsKeyword := KW_JOIN
  Else If S = 'split'     Then IsKeyword := KW_SPLIT
  { --- Fonctions hashes --- }
  Else If S = 'keys'      Then IsKeyword := KW_KEYS
  Else If S = 'values'    Then IsKeyword := KW_VALUES
  Else If S = 'each'      Then IsKeyword := KW_EACH
  Else If S = 'exists'    Then IsKeyword := KW_EXISTS
  Else If S = 'delete'    Then IsKeyword := KW_DELETE
  { --- Fonctions chaines --- }
  Else If S = 'length'    Then IsKeyword := KW_LENGTH
  Else If S = 'substr'    Then IsKeyword := KW_SUBSTR
  Else If S = 'index'     Then IsKeyword := KW_INDEX_FUNC
  Else If S = 'rindex'    Then IsKeyword := KW_RINDEX
  Else If S = 'uc'        Then IsKeyword := KW_UC
  Else If S = 'lc'        Then IsKeyword := KW_LC
  Else If S = 'ucfirst'   Then IsKeyword := KW_UCFIRST
  Else If S = 'lcfirst'   Then IsKeyword := KW_LCFIRST
  Else If S = 'chomp'     Then IsKeyword := KW_CHOMP
  Else If S = 'chop'      Then IsKeyword := KW_CHOP
  Else If S = 'chr'       Then IsKeyword := KW_CHR
  Else If S = 'ord'       Then IsKeyword := KW_ORD
  Else If S = 'hex'       Then IsKeyword := KW_HEX
  Else If S = 'oct'       Then IsKeyword := KW_OCT
  Else If S = 'quotemeta' Then IsKeyword := KW_QUOTEMETA
  Else If S = 'pos'       Then IsKeyword := KW_POS
  { --- Fonctions numeriques --- }
  Else If S = 'abs'       Then IsKeyword := KW_ABS
  Else If S = 'int'       Then IsKeyword := KW_INT_FUNC
  Else If S = 'sqrt'      Then IsKeyword := KW_SQRT
  Else If S = 'atan2'     Then IsKeyword := KW_ATAN2
  Else If S = 'sin'       Then IsKeyword := KW_SIN
  Else If S = 'cos'       Then IsKeyword := KW_COS
  Else If S = 'log'       Then IsKeyword := KW_LOG
  Else If S = 'exp'       Then IsKeyword := KW_EXP
  Else If S = 'rand'      Then IsKeyword := KW_RAND
  Else If S = 'srand'     Then IsKeyword := KW_SRAND
  { --- Fonctions de test / typage --- }
  Else If S = 'defined'   Then IsKeyword := KW_DEFINED
  Else If S = 'ref'       Then IsKeyword := KW_REF
  Else If S = 'bless'     Then IsKeyword := KW_BLESS
  { --- Fonctions systeme --- }
  Else If S = 'stat'      Then IsKeyword := KW_STAT
  Else If S = 'unlink'    Then IsKeyword := KW_UNLINK
  Else If S = 'rename'    Then IsKeyword := KW_RENAME
  Else If S = 'chdir'     Then IsKeyword := KW_CHDIR
  Else If S = 'sleep'     Then IsKeyword := KW_SLEEP
  Else If S = 'time'      Then IsKeyword := KW_TIME
  Else If S = 'untie'     Then IsKeyword := KW_UNTIE;
End;

{ Vrai si le token est un mot-cle modificateur de statement (suffixe) }
Function IsModifierKW(T: Integer): Boolean;
Begin
  IsModifierKW := (T = KW_IF)    Or (T = KW_UNLESS) Or
                  (T = KW_WHILE) Or (T = KW_UNTIL)  Or
                  (T = KW_FOR)   Or (T = KW_FOREACH);
End;

{ Vrai si le token est un operateur de comparaison chaine }
Function IsStrCompKW(T: Integer): Boolean;
Begin
  IsStrCompKW := (T = KW_EQ_STR) Or (T = KW_NE_STR) Or
                 (T = KW_LT_STR) Or (T = KW_GT_STR) Or
                 (T = KW_LE_STR) Or (T = KW_GE_STR) Or
                 (T = TOK_CMP);
End;

{ Vrai si le token est une fonction integree de liste }
Function IsListOperator(T: Integer): Boolean;
Begin
  IsListOperator :=
    (T = KW_PRINT)   Or (T = KW_SAY)     Or (T = KW_PRINTF) Or
    (T = KW_WARN)    Or (T = KW_DIE)     Or (T = KW_PUSH)   Or
    (T = KW_POP)     Or (T = KW_SHIFT)   Or (T = KW_UNSHIFT)Or
    (T = KW_SPLICE)  Or (T = KW_SORT)    Or (T = KW_REVERSE)Or
    (T = KW_GREP)    Or (T = KW_MAP)     Or (T = KW_JOIN)   Or
    (T = KW_SPLIT)   Or (T = KW_KEYS)    Or (T = KW_VALUES) Or
    (T = KW_EACH)    Or (T = KW_EXISTS)  Or (T = KW_DELETE) Or
    (T = KW_DEFINED) Or (T = KW_CHOMP)   Or (T = KW_CHOP)   Or
    (T = KW_SCALAR)  Or (T = KW_OPEN)    Or (T = KW_CLOSE)  Or
    (T = KW_READLINE)Or (T = KW_SPRINTF);
End;

{ Vrai si le token est une fonction a un seul argument (unaire) }
Function IsUnaryBuiltin(T: Integer): Boolean;
Begin
  IsUnaryBuiltin :=
    (T = KW_ABS)    Or (T = KW_INT_FUNC)Or (T = KW_SQRT)  Or
    (T = KW_LENGTH) Or (T = KW_CHOMP)   Or (T = KW_CHOP)  Or
    (T = KW_UC)     Or (T = KW_LC)      Or (T = KW_UCFIRST)Or
    (T = KW_LCFIRST)Or (T = KW_CHR)     Or (T = KW_ORD)   Or
    (T = KW_HEX)    Or (T = KW_OCT)     Or (T = KW_DEFINED)Or
    (T = KW_REF)    Or (T = KW_SCALAR)  Or (T = KW_UNDEF) Or
    (T = KW_EOF_FUNC);
End;

{ Nom lisible d un keyword pour debug / messages d erreur }
Function KeywordName(T: Integer): String;
Begin
  Case T Of
    KW_AND:       KeywordName := 'and';
    KW_BEGIN:     KeywordName := 'BEGIN';
    KW_END:       KeywordName := 'END';
    KW_DO:        KeywordName := 'do';
    KW_ELSE:      KeywordName := 'else';
    KW_ELSIF:     KeywordName := 'elsif';
    KW_EVAL:      KeywordName := 'eval';
    KW_FOR:       KeywordName := 'for';
    KW_FOREACH:   KeywordName := 'foreach';
    KW_FORMAT:    KeywordName := 'format';
    KW_GOTO:      KeywordName := 'goto';
    KW_IF:        KeywordName := 'if';
    KW_LAST:      KeywordName := 'last';
    KW_LOCAL:     KeywordName := 'local';
    KW_MY:        KeywordName := 'my';
    KW_NEXT:      KeywordName := 'next';
    KW_NO:        KeywordName := 'no';
    KW_NOT:       KeywordName := 'not';
    KW_OR:        KeywordName := 'or';
    KW_OUR:       KeywordName := 'our';
    KW_PACKAGE:   KeywordName := 'package';
    KW_REDO:      KeywordName := 'redo';
    KW_RETURN:    KeywordName := 'return';
    KW_SUB:       KeywordName := 'sub';
    KW_TIE:       KeywordName := 'tie';
    KW_TIED:      KeywordName := 'tied';
    KW_UNLESS:    KeywordName := 'unless';
    KW_UNTIL:     KeywordName := 'until';
    KW_USE:       KeywordName := 'use';
    KW_WHILE:     KeywordName := 'while';
    KW_XOR:       KeywordName := 'xor';
    KW_UNDEF:     KeywordName := 'undef';
    KW_X_REP:     KeywordName := 'x';
    KW_WANTARRAY: KeywordName := 'wantarray';
    KW_REQUIRE:   KeywordName := 'require';
    KW_EQ_STR:    KeywordName := 'eq';
    KW_NE_STR:    KeywordName := 'ne';
    KW_LT_STR:    KeywordName := 'lt';
    KW_GT_STR:    KeywordName := 'gt';
    KW_LE_STR:    KeywordName := 'le';
    KW_GE_STR:    KeywordName := 'ge';
    TOK_CMP:      KeywordName := 'cmp';
    KW_PRINT:     KeywordName := 'print';
    KW_SAY:       KeywordName := 'say';
    KW_PRINTF:    KeywordName := 'printf';
    KW_SPRINTF:   KeywordName := 'sprintf';
    KW_WARN:      KeywordName := 'warn';
    KW_DIE:       KeywordName := 'die';
    KW_EXIT:      KeywordName := 'exit';
    KW_OPEN:      KeywordName := 'open';
    KW_CLOSE:     KeywordName := 'close';
    KW_READLINE:  KeywordName := 'readline';
    KW_EOF_FUNC:  KeywordName := 'eof';
    KW_PUSH:      KeywordName := 'push';
    KW_POP:       KeywordName := 'pop';
    KW_SHIFT:     KeywordName := 'shift';
    KW_UNSHIFT:   KeywordName := 'unshift';
    KW_SPLICE:    KeywordName := 'splice';
    KW_SCALAR:    KeywordName := 'scalar';
    KW_REVERSE:   KeywordName := 'reverse';
    KW_SORT:      KeywordName := 'sort';
    KW_GREP:      KeywordName := 'grep';
    KW_MAP:       KeywordName := 'map';
    KW_JOIN:      KeywordName := 'join';
    KW_SPLIT:     KeywordName := 'split';
    KW_KEYS:      KeywordName := 'keys';
    KW_VALUES:    KeywordName := 'values';
    KW_EACH:      KeywordName := 'each';
    KW_EXISTS:    KeywordName := 'exists';
    KW_DELETE:    KeywordName := 'delete';
    KW_LENGTH:    KeywordName := 'length';
    KW_SUBSTR:    KeywordName := 'substr';
    KW_INDEX_FUNC:KeywordName := 'index';
    KW_RINDEX:    KeywordName := 'rindex';
    KW_UC:        KeywordName := 'uc';
    KW_LC:        KeywordName := 'lc';
    KW_UCFIRST:   KeywordName := 'ucfirst';
    KW_LCFIRST:   KeywordName := 'lcfirst';
    KW_CHOMP:     KeywordName := 'chomp';
    KW_CHOP:      KeywordName := 'chop';
    KW_CHR:       KeywordName := 'chr';
    KW_ORD:       KeywordName := 'ord';
    KW_HEX:       KeywordName := 'hex';
    KW_OCT:       KeywordName := 'oct';
    KW_ABS:       KeywordName := 'abs';
    KW_INT_FUNC:  KeywordName := 'int';
    KW_SQRT:      KeywordName := 'sqrt';
    KW_ATAN2:     KeywordName := 'atan2';
    KW_SIN:       KeywordName := 'sin';
    KW_COS:       KeywordName := 'cos';
    KW_LOG:       KeywordName := 'log';
    KW_EXP:       KeywordName := 'exp';
    KW_RAND:      KeywordName := 'rand';
    KW_SRAND:     KeywordName := 'srand';
    KW_DEFINED:   KeywordName := 'defined';
    KW_REF:       KeywordName := 'ref';
    KW_BLESS:     KeywordName := 'bless';
    KW_STAT:      KeywordName := 'stat';
    KW_UNLINK:    KeywordName := 'unlink';
    KW_RENAME:    KeywordName := 'rename';
    KW_CHDIR:     KeywordName := 'chdir';
    KW_SLEEP:     KeywordName := 'sleep';
    KW_TIME:      KeywordName := 'time';
    KW_QUOTEMETA: KeywordName := 'quotemeta';
    KW_POS:       KeywordName := 'pos';
    KW_BINMODE:   KeywordName := 'binmode';
    KW_UNTIE:     KeywordName := 'untie';
  Else
    KeywordName := TokenName(T);
  End;
End;

(* ============================================================ *)
(* TODO 04 - TYPES SCALAIRES ET REPRESENTATION RUNTIME         *)
(* ============================================================ *)

Const
  CTX_VOID   = 0;
  CTX_SCALAR = 1;
  CTX_LIST   = 2;
  CTX_BOOL   = 3;

  PV_UNDEF   = 0;
  PV_INTEGER = 1;
  PV_FLOAT   = 2;
  PV_STRING  = 3;

Type
  TPerlVal = Record
    Tag:  Integer;
    IVal: LongInt;
    FVal: Double;
    SVal: String;
  End;

Function PerlValUndef: TPerlVal;
Var V: TPerlVal;
Begin
  V.Tag  := PV_UNDEF;
  V.IVal := 0;
  V.FVal := 0.0;
  V.SVal := '';
  PerlValUndef := V;
End;

Function PerlValInt(N: LongInt): TPerlVal;
Var V: TPerlVal;
Begin
  V.Tag  := PV_INTEGER;
  V.IVal := N;
  V.FVal := N;
  V.SVal := '';
  PerlValInt := V;
End;

Function PerlValFloat(F: Double): TPerlVal;
Var V: TPerlVal;
Begin
  V.Tag  := PV_FLOAT;
  V.IVal := Round(F);
  V.FVal := F;
  V.SVal := '';
  PerlValFloat := V;
End;

Function PerlValStr(S: String): TPerlVal;
Var V: TPerlVal;
Begin
  V.Tag  := PV_STRING;
  V.IVal := 0;
  V.FVal := 0.0;
  V.SVal := S;
  PerlValStr := V;
End;

Function IsUndefVal(V: TPerlVal): Boolean;
Begin
  IsUndefVal := (V.Tag = PV_UNDEF);
End;

Function IntValStr(N: LongInt): String;
Var S: String;
Begin
  Str(N, S);
  IntValStr := S;
End;

Function FloatValStr(F: Double): String;
Var S: String;
    IsInt: Boolean;
    Truncated: LongInt;
Begin
  Truncated := Round(F);
  IsInt := (F = Truncated) And (Abs(F) < 1.0E15);
  If IsInt Then Begin
    Str(Truncated, S);
  End Else Begin
    Str(F:0:6, S);
    While (Length(S) > 1) And (S[Length(S)] = '0') Do
      Delete(S, Length(S), 1);
    If (Length(S) > 0) And (S[Length(S)] = '.') Then
      Delete(S, Length(S), 1);
  End;
  FloatValStr := S;
End;

{ Parse leading numeric prefix from a Perl string }
Function StrToNum(S: String): LongInt;
Var I, Sign: Integer;
    N: LongInt;
    IsHex, IsOct: Boolean;
    C: Char;
Begin
  I    := 1;
  Sign := 1;
  N    := 0;
  IsHex := False;
  IsOct := False;
  While (I <= Length(S)) And (S[I] = ' ') Do Inc(I);
  If (I <= Length(S)) And (S[I] = '-') Then Begin
    Sign := -1; Inc(I);
  End Else If (I <= Length(S)) And (S[I] = '+') Then
    Inc(I);
  If (I <= Length(S)) And (S[I] = '0') Then Begin
    Inc(I);
    If (I <= Length(S)) And ((S[I] = 'x') Or (S[I] = 'X')) Then Begin
      IsHex := True; Inc(I);
    End Else
      IsOct := True;
  End;
  If IsHex Then Begin
    While I <= Length(S) Do Begin
      C := S[I];
      If (C >= '0') And (C <= '9') Then
        N := N * 16 + (Ord(C) - Ord('0'))
      Else If (C >= 'a') And (C <= 'f') Then
        N := N * 16 + (Ord(C) - Ord('a') + 10)
      Else If (C >= 'A') And (C <= 'F') Then
        N := N * 16 + (Ord(C) - Ord('A') + 10)
      Else
        Break;
      Inc(I);
    End;
  End Else If IsOct Then Begin
    While (I <= Length(S)) And (S[I] >= '0') And (S[I] <= '7') Do Begin
      N := N * 8 + (Ord(S[I]) - Ord('0'));
      Inc(I);
    End;
  End Else Begin
    While (I <= Length(S)) And (S[I] >= '0') And (S[I] <= '9') Do Begin
      N := N * 10 + (Ord(S[I]) - Ord('0'));
      Inc(I);
    End;
  End;
  StrToNum := Sign * N;
End;

Function ValToInt(V: TPerlVal): LongInt;
Begin
  Case V.Tag Of
    PV_UNDEF:   ValToInt := 0;
    PV_INTEGER: ValToInt := V.IVal;
    PV_FLOAT:   ValToInt := Round(V.FVal);
    PV_STRING:  ValToInt := StrToNum(V.SVal);
  Else
    ValToInt := 0;
  End;
End;

Function ValToStr(V: TPerlVal): String;
Begin
  Case V.Tag Of
    PV_UNDEF:   ValToStr := '';
    PV_INTEGER: ValToStr := IntValStr(V.IVal);
    PV_FLOAT:   ValToStr := FloatValStr(V.FVal);
    PV_STRING:  ValToStr := V.SVal;
  Else
    ValToStr := '';
  End;
End;

Function ValToNum(V: TPerlVal): LongInt;
Begin
  ValToNum := ValToInt(V);
End;

{ Perl truth: false if undef, 0, "0", or "" }
Function IsTrueVal(V: TPerlVal): Boolean;
Begin
  Case V.Tag Of
    PV_UNDEF:   IsTrueVal := False;
    PV_INTEGER: IsTrueVal := (V.IVal <> 0);
    PV_FLOAT:   IsTrueVal := (V.FVal <> 0.0);
    PV_STRING:  IsTrueVal := (V.SVal <> '') And (V.SVal <> '0');
  Else
    IsTrueVal := False;
  End;
End;

Function ValTypeName(V: TPerlVal): String;
Begin
  Case V.Tag Of
    PV_UNDEF:   ValTypeName := 'undef';
    PV_INTEGER: ValTypeName := 'integer';
    PV_FLOAT:   ValTypeName := 'float';
    PV_STRING:  ValTypeName := 'string';
  Else
    ValTypeName := 'unknown';
  End;
End;

Function CtxName(C: Integer): String;
Begin
  Case C Of
    CTX_VOID:   CtxName := 'void';
    CTX_SCALAR: CtxName := 'scalar';
    CTX_LIST:   CtxName := 'list';
    CTX_BOOL:   CtxName := 'bool';
  Else
    CtxName := 'unknown';
  End;
End;

{ Tagged 31-bit integer encoding for runtime: ((n shl 1) or 1) }
Function MakePerlTaggedInt(N: LongInt): LongInt;
Begin
  MakePerlTaggedInt := (N Shl 1) Or 1;
End;

Function UntagPerlInt(Tagged: LongInt): LongInt;
Begin
  UntagPerlInt := Tagged Shr 1;
End;

{ Runtime symbol name helpers for code generation }
Function PlRtToNum: String;   Begin PlRtToNum   := '_PLRT_to_num';   End;
Function PlRtToStr: String;   Begin PlRtToStr   := '_PLRT_to_str';   End;
Function PlRtToBool: String;  Begin PlRtToBool  := '_PLRT_to_bool';  End;
Function PlRtIsUndef: String; Begin PlRtIsUndef := '_PLRT_is_undef'; End;
Function PlRtToInt: String;   Begin PlRtToInt   := '_PLRT_to_int';   End;

(* ============================================================ *)
(* TODO 05 - VARIABLES : SCALAIRES, TABLEAUX, HASHES           *)
(* ============================================================ *)

Const
  SF_DEAD      = $0020;
  SCK_TOPLEVEL = 0;
  SCK_SUB      = 1;
  SCK_BLOCK    = 2;

Var
  ScopeKindStk: Array[0..MAX_SCOPE] Of Integer;

Procedure InitSymTable;
Var I: Integer;
Begin
  For I := 1 To MAX_SYM Do Begin
    SymTable[I].Name    := '';
    SymTable[I].Kind    := SK_NONE;
    SymTable[I].RType   := RT_UNDEF;
    SymTable[I].ScopeKd := SCOPE_LEXICAL;
    SymTable[I].Depth   := 0;
    SymTable[I].Offset  := 0;
    SymTable[I].Flags   := 0;
    SymTable[I].AsmName := '';
    SymTable[I].Package := '';
  End;
  SymCount := 0;
  ScopeLevel := 0;
  ScopeBase[0] := 1;
  ScopeNextLocal[0] := 0;
  ScopeKindStk[0] := SCK_TOPLEVEL;
  CurrentPkg := 'main';
End;

Function SkKindName(K: Integer): String;
Begin
  Case K Of
    SK_SCALAR: SkKindName := 'scalar';
    SK_ARRAY:  SkKindName := 'array';
    SK_HASH:   SkKindName := 'hash';
    SK_CODE:   SkKindName := 'code';
    SK_FORMAT: SkKindName := 'format';
    SK_GLOB:   SkKindName := 'glob';
  Else
    SkKindName := 'none';
  End;
End;

Function ScopeKdStr(K: Integer): String;
Begin
  Case K Of
    SCOPE_LEXICAL: ScopeKdStr := 'lexical';
    SCOPE_PACKAGE: ScopeKdStr := 'package';
    SCOPE_DYNAMIC: ScopeKdStr := 'dynamic';
  Else
    ScopeKdStr := 'unknown';
  End;
End;

{ Replace non-identifier chars; :: becomes __ }
Function SafeAsmIdent(S: String): String;
Var R: String;
    I: Integer;
    C: Char;
Begin
  R := '';
  I := 1;
  While I <= Length(S) Do Begin
    C := S[I];
    If (I < Length(S)) And (C = ':') And (S[I+1] = ':') Then Begin
      R := R + '__';
      Inc(I, 2);
    End Else If ((C >= 'A') And (C <= 'Z')) Or
                ((C >= 'a') And (C <= 'z')) Or
                ((C >= '0') And (C <= '9')) Or
                (C = '_') Then Begin
      R := R + C;
      Inc(I);
    End Else Begin
      R := R + '_';
      Inc(I);
    End;
  End;
  If R = '' Then R := 'anon';
  SafeAsmIdent := R;
End;

Function MakeSymAsmName(Name: String; Kind, ScopeKd: Integer; Pkg: String): String;
Var Base, PkgPfx: String;
Begin
  Base := SafeAsmIdent(Name);
  If Pkg = 'main' Then PkgPfx := ''
  Else PkgPfx := SafeAsmIdent(Pkg) + '_';
  Case Kind Of
    SK_CODE: MakeSymAsmName := ASM_PFX_SUB + PkgPfx + Base;
    SK_ARRAY: Begin
      If ScopeKd = SCOPE_PACKAGE Then
        MakeSymAsmName := ASM_PFX_ARRAY + PkgPfx + Base
      Else
        MakeSymAsmName := ASM_PFX_ARRAY + Base;
    End;
    SK_HASH: Begin
      If ScopeKd = SCOPE_PACKAGE Then
        MakeSymAsmName := ASM_PFX_HASH + PkgPfx + Base
      Else
        MakeSymAsmName := ASM_PFX_HASH + Base;
    End;
  Else
    If ScopeKd = SCOPE_PACKAGE Then
      MakeSymAsmName := ASM_PFX_GVAR + PkgPfx + Base
    Else
      MakeSymAsmName := ASM_PFX_GVAR + Base;
  End;
End;

Function AllocLocalOffset: Integer;
Begin
  Inc(ScopeNextLocal[ScopeLevel], 4);
  AllocLocalOffset := ScopeNextLocal[ScopeLevel];
End;

Procedure EnterScope(Kind: Integer);
Begin
  If ScopeLevel >= MAX_SCOPE Then FatalError('pile de portees pleine');
  Inc(ScopeLevel);
  ScopeBase[ScopeLevel] := SymCount + 1;
  ScopeKindStk[ScopeLevel] := Kind;
  If Kind = SCK_SUB Then
    ScopeNextLocal[ScopeLevel] := 0
  Else
    ScopeNextLocal[ScopeLevel] := ScopeNextLocal[ScopeLevel - 1];
End;

Procedure LeaveScope;
Var I, Leaving: Integer;
Begin
  If ScopeLevel = 0 Then FatalError('impossible de quitter la portee racine');
  Leaving := ScopeLevel;
  For I := ScopeBase[Leaving] To SymCount Do
    If (SymTable[I].ScopeKd = SCOPE_LEXICAL) Or
       (SymTable[I].ScopeKd = SCOPE_DYNAMIC) Then
      SymTable[I].Flags := SymTable[I].Flags Or SF_DEAD;
  Dec(ScopeLevel);
End;

Function FindSym(Name: String; Kind: Integer): Integer;
Var I: Integer;
Begin
  FindSym := 0;
  For I := SymCount DownTo 1 Do
    If (SymTable[I].Name = Name) And
       ((SymTable[I].Flags And SF_DEAD) = 0) And
       ((Kind = SK_NONE) Or (SymTable[I].Kind = Kind)) Then Begin
      FindSym := I;
      Exit;
    End;
End;

Function FindSymInLevel(Name: String; Kind, Level: Integer): Integer;
Var I: Integer;
Begin
  FindSymInLevel := 0;
  For I := SymCount DownTo 1 Do
    If (SymTable[I].Depth = Level) And
       (SymTable[I].Name = Name) And
       ((SymTable[I].Flags And SF_DEAD) = 0) And
       ((Kind = SK_NONE) Or (SymTable[I].Kind = Kind)) Then Begin
      FindSymInLevel := I;
      Exit;
    End;
End;

Function FindSymPkg(Name: String; Kind: Integer; Pkg: String): Integer;
Var I: Integer;
Begin
  FindSymPkg := 0;
  For I := SymCount DownTo 1 Do
    If (SymTable[I].Name = Name) And
       (SymTable[I].Package = Pkg) And
       (SymTable[I].ScopeKd = SCOPE_PACKAGE) And
       ((SymTable[I].Flags And SF_DEAD) = 0) And
       ((Kind = SK_NONE) Or (SymTable[I].Kind = Kind)) Then Begin
      FindSymPkg := I;
      Exit;
    End;
End;

Function AddSym(Name: String; Kind, ScopeKd, InFlags: Integer): Integer;
Var Existing: Integer;
Begin
  If ScopeKd = SCOPE_PACKAGE Then Begin
    Existing := FindSymPkg(Name, Kind, CurrentPkg);
    If Existing <> 0 Then Begin
      AddSym := Existing;
      Exit;
    End;
  End;
  If SymCount >= MAX_SYM Then FatalError('table de symboles pleine');
  Inc(SymCount);
  SymTable[SymCount].Name    := Name;
  SymTable[SymCount].Kind    := Kind;
  SymTable[SymCount].RType   := RT_UNDEF;
  SymTable[SymCount].ScopeKd := ScopeKd;
  SymTable[SymCount].Depth   := ScopeLevel;
  SymTable[SymCount].Flags   := InFlags;
  SymTable[SymCount].Package := CurrentPkg;
  If (ScopeKd = SCOPE_LEXICAL) Or (ScopeKd = SCOPE_DYNAMIC) Then
    SymTable[SymCount].Offset := AllocLocalOffset
  Else
    SymTable[SymCount].Offset := 0;
  If ScopeKd = SCOPE_PACKAGE Then
    SymTable[SymCount].AsmName := MakeSymAsmName(Name, Kind, ScopeKd, CurrentPkg)
  Else
    SymTable[SymCount].AsmName := '';
  AddSym := SymCount;
End;

{ Total local frame size for current sub }
Function CurrentSubLocalSize: Integer;
Begin
  CurrentSubLocalSize := ScopeNextLocal[ScopeLevel];
End;

Procedure DumpSymTable;
Var
  I: Integer;
  FlagStr, NumStr: String;
Begin
  WriteLn('=== TABLE DES SYMBOLES (', SymCount, ' entrees) ===');
  For I := 1 To SymCount Do Begin
    FlagStr := '';
    If (SymTable[I].Flags And SF_PARAM)    <> 0 Then FlagStr := FlagStr + 'P';
    If (SymTable[I].Flags And SF_USED)     <> 0 Then FlagStr := FlagStr + 'U';
    If (SymTable[I].Flags And SF_ASSIGNED) <> 0 Then FlagStr := FlagStr + 'A';
    If (SymTable[I].Flags And SF_GLOBAL)   <> 0 Then FlagStr := FlagStr + 'G';
    If (SymTable[I].Flags And SF_SPECIAL)  <> 0 Then FlagStr := FlagStr + 'S';
    If (SymTable[I].Flags And SF_DEAD)     <> 0 Then FlagStr := FlagStr + 'D';
    If FlagStr = '' Then FlagStr := '-';
    Str(I, NumStr);
    While Length(NumStr) < 4 Do NumStr := ' ' + NumStr;
    WriteLn(NumStr, ' [', SymTable[I].Package, '] ',
            SkKindName(SymTable[I].Kind), ' ', SymTable[I].Name,
            ' ', ScopeKdStr(SymTable[I].ScopeKd),
            ' d=', SymTable[I].Depth,
            ' off=', SymTable[I].Offset,
            ' asm=', SymTable[I].AsmName,
            ' fl=', FlagStr);
  End;
End;

(* ============================================================ *)
(* TODO 06 - PARSEUR D'EXPRESSIONS (PRECEDENCE PERL)           *)
(* ============================================================ *)

Function ParseExpr:    Integer; Forward;
Function ParseOrLo:    Integer; Forward;
Function ParseAndLo:   Integer; Forward;
Function ParseNotLo:   Integer; Forward;
Function ParseAssign:  Integer; Forward;
Function ParseTernary: Integer; Forward;
Function ParseRange:   Integer; Forward;
Function ParseOrHi:    Integer; Forward;
Function ParseAndHi:   Integer; Forward;
Function ParseBitOr:   Integer; Forward;
Function ParseBitAnd:  Integer; Forward;
Function ParseCompare: Integer; Forward;
Function ParseShift:   Integer; Forward;
Function ParseAdd:     Integer; Forward;
Function ParseMul:     Integer; Forward;
Function ParseBind:    Integer; Forward;
Function ParsePow:     Integer; Forward;
Function ParseUnary:   Integer; Forward;
Function ParsePostfix: Integer; Forward;
Function ParsePrimary: Integer; Forward;
{ TODO 07/08/09/11 cross-section forwards }
Function ParseBlock:            Integer; Forward;
Function ScanProtoStr:          String;  Forward;
Procedure RegisterSubParams;    Forward;
Function ParseCodeBlock:        Integer; Forward;
Function ParseSortGrepMap(KwTok: Integer; S: String): Integer; Forward;
Procedure PropagateCtx(Node, InCtx: Integer); Forward;

Function NewNode(K, Tok: Integer; Txt: String): Integer;
Var N: Integer;
Begin
  If AstCount >= MAX_AST Then FatalError('trop de noeuds AST');
  Inc(AstCount);
  N := AstCount;
  AstTable[N].Kind        := K;
  AstTable[N].Tok         := Tok;
  AstTable[N].Text        := Txt;
  AstTable[N].Left        := 0;
  AstTable[N].Right       := 0;
  AstTable[N].Third       := 0;
  AstTable[N].FirstChild  := 0;
  AstTable[N].NextSibling := 0;
  AstTable[N].SymRef      := 0;
  AstTable[N].Line        := CurTokLine;
  AstTable[N].Ctx         := CTX_VOID;
  NewNode := N;
End;

Function NewBin(Op, L, R: Integer): Integer;
Var N: Integer;
Begin
  N := NewNode(NK_BINARY, Op, '');
  AstTable[N].Left  := L;
  AstTable[N].Right := R;
  NewBin := N;
End;

Function NewUn(Op, Child: Integer): Integer;
Var N: Integer;
Begin
  N := NewNode(NK_UNARY, Op, '');
  AstTable[N].Left := Child;
  NewUn := N;
End;

Procedure AppendArg(Parent, Arg: Integer);
Var Last: Integer;
Begin
  If AstTable[Parent].FirstChild = 0 Then
    AstTable[Parent].FirstChild := Arg
  Else Begin
    Last := AstTable[Parent].FirstChild;
    While AstTable[Last].NextSibling <> 0 Do
      Last := AstTable[Last].NextSibling;
    AstTable[Last].NextSibling := Arg;
  End;
End;

Function EatIf(T: Integer): Boolean;
Begin
  If CurTokType = T Then Begin LexNextToken; EatIf := True; End
  Else EatIf := False;
End;

Procedure Expect(T: Integer);
Begin
  If CurTokType <> T Then
    FatalError('attendu ' + TokenName(T) + ' mais ' + TokenName(CurTokType));
  LexNextToken;
End;

Procedure InitAST;
Begin
  AstCount := 0;
End;

Function IsArgStopper(T: Integer): Boolean;
Begin
  IsArgStopper := (T = Ord(';')) Or (T = TOK_EOF) Or
                  (T = Ord('}')) Or (T = Ord(')')) Or (T = Ord(']')) Or
                  IsModifierKW(T) Or
                  (T = KW_OR) Or (T = KW_AND) Or
                  (T = KW_NOT) Or (T = KW_XOR);
End;

Function ParseArgList: Integer;
Var Head: Integer;
Begin
  Head := NewNode(NK_LIST, 0, '');
  While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
    AppendArg(Head, ParseAssign);
    If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
      LexNextToken
    Else
      Break;
  End;
  ParseArgList := Head;
End;

Function ParseVarDecl(DeclKw: Integer): Integer;
Var
  N, ListN, ScopeKd, SymIdx, Sigil: Integer;
  VName: String;
Begin
  If DeclKw = KW_MY Then ScopeKd := SCOPE_LEXICAL
  Else If DeclKw = KW_OUR Then ScopeKd := SCOPE_PACKAGE
  Else ScopeKd := SCOPE_DYNAMIC;
  If CurTokType = Ord('(') Then Begin
    LexNextToken;
    ListN := NewNode(NK_LIST, DeclKw, '');
    While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
      Sigil := CurTokType;
      If (Sigil = TOK_SIGIL_SCALAR) Or (Sigil = TOK_SIGIL_ARRAY) Or
         (Sigil = TOK_SIGIL_HASH) Then Begin
        VName := Copy(CurTokStr, 2, Length(CurTokStr));
        LexNextToken;
        N := NewNode(NK_VAR, DeclKw, VName);
        AstTable[N].Left := Sigil;
        If Sigil = TOK_SIGIL_SCALAR Then
          SymIdx := AddSym(VName, SK_SCALAR, ScopeKd, 0)
        Else If Sigil = TOK_SIGIL_ARRAY Then
          SymIdx := AddSym(VName, SK_ARRAY, ScopeKd, 0)
        Else
          SymIdx := AddSym(VName, SK_HASH, ScopeKd, 0);
        AstTable[N].SymRef := SymIdx;
        AppendArg(ListN, N);
      End Else Break;
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
    Expect(Ord(')'));
    ParseVarDecl := ListN;
    Exit;
  End;
  Sigil := CurTokType;
  If (Sigil <> TOK_SIGIL_SCALAR) And (Sigil <> TOK_SIGIL_ARRAY) And
     (Sigil <> TOK_SIGIL_HASH) Then
    FatalError('variable attendue apres ' + KeywordName(DeclKw));
  VName := Copy(CurTokStr, 2, Length(CurTokStr));
  LexNextToken;
  N := NewNode(NK_VAR, DeclKw, VName);
  AstTable[N].Left := Sigil;
  If Sigil = TOK_SIGIL_SCALAR Then
    SymIdx := AddSym(VName, SK_SCALAR, ScopeKd, 0)
  Else If Sigil = TOK_SIGIL_ARRAY Then
    SymIdx := AddSym(VName, SK_ARRAY, ScopeKd, 0)
  Else
    SymIdx := AddSym(VName, SK_HASH, ScopeKd, 0);
  AstTable[N].SymRef := SymIdx;
  ParseVarDecl := N;
End;

Function ParseBuiltin(KwTok: Integer; S: String): Integer;
Var N, ArgList: Integer;
Begin
  N       := NewNode(NK_CALL, KwTok, S);
  ArgList := NewNode(NK_LIST, 0, '');
  If CurTokType = Ord('(') Then Begin
    LexNextToken;
    While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
      AppendArg(ArgList, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
    Expect(Ord(')'));
  End Else Begin
    While Not IsArgStopper(CurTokType) Do Begin
      AppendArg(ArgList, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
  End;
  AstTable[N].FirstChild := AstTable[ArgList].FirstChild;
  ParseBuiltin := N;
End;

Function ParsePrimary: Integer;
Var
  N, VarN, IdxN, ArgList, ListN, ProtoN: Integer;
  S, VName, ProtoStr: String;
  T, Sigil: Integer;
Begin
  T := CurTokType;
  N := 0;
  If T = TOK_INTEGER Then Begin
    N := NewNode(NK_LITERAL, T, CurTokStr);
    AstTable[N].Left := CurTokNum;
    LexNextToken;
  End Else If T = TOK_FLOAT Then Begin
    N := NewNode(NK_LITERAL, T, CurTokStr); LexNextToken;
  End Else If (T = TOK_STRING) Or (T = TOK_DSTRING) Or
              (T = TOK_HEREDOC) Then Begin
    N := NewNode(NK_LITERAL, T, CurTokStr); LexNextToken;
  End Else If T = TOK_REGEX Then Begin
    N := NewNode(NK_REGEX, T, CurTokStr); LexNextToken;
  End Else If T = TOK_SUBST Then Begin
    N := NewNode(NK_SUBST, T, CurTokStr); LexNextToken;
  End Else If T = TOK_TRANS Then Begin
    N := NewNode(NK_TRANS, T, CurTokStr); LexNextToken;
  End Else If T = TOK_QWORD Then Begin
    N := NewNode(NK_ARRAY_LIT, T, CurTokStr); LexNextToken;
  End Else If T = TOK_HASHNUM Then Begin
    VName := Copy(CurTokStr, 3, Length(CurTokStr));
    N := NewNode(NK_VAR, T, VName); LexNextToken;
  End Else If T = TOK_SIGIL_SCALAR Then Begin
    VName := Copy(CurTokStr, 2, Length(CurTokStr)); LexNextToken;
    VarN  := NewNode(NK_VAR, TOK_SIGIL_SCALAR, VName);
    AstTable[VarN].SymRef := FindSym(VName, SK_SCALAR);
    If CurTokType = Ord('[') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord(']'));
      N := NewNode(NK_INDEX, Ord('['), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else If CurTokType = Ord('{') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
      N := NewNode(NK_INDEX, Ord('{'), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else N := VarN;
  End Else If T = TOK_SIGIL_ARRAY Then Begin
    VName := Copy(CurTokStr, 2, Length(CurTokStr)); LexNextToken;
    VarN  := NewNode(NK_VAR, TOK_SIGIL_ARRAY, VName);
    AstTable[VarN].SymRef := FindSym(VName, SK_ARRAY);
    If CurTokType = Ord('[') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord(']'));
      N := NewNode(NK_SLICE, Ord('['), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else If CurTokType = Ord('{') Then Begin
      { tranche de hash : @h[...] }
      LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
      N := NewNode(NK_SLICE, Ord('{'), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else N := VarN;
  End Else If T = TOK_SIGIL_HASH Then Begin
    VName := Copy(CurTokStr, 2, Length(CurTokStr)); LexNextToken;
    VarN  := NewNode(NK_VAR, T, VName);
    AstTable[VarN].SymRef := FindSym(VName, SK_HASH);
    If CurTokType = Ord('{') Then Begin
      { tranche hash cle+valeur }
      LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
      N := NewNode(NK_SLICE, Ord('{'), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else N := VarN;
  End Else If T = TOK_SIGIL_CODE Then Begin
    VName := Copy(CurTokStr, 2, Length(CurTokStr)); LexNextToken;
    N := NewNode(NK_CALL, T, VName);
    If CurTokType = Ord('(') Then Begin
      LexNextToken;
      ArgList := ParseArgList; Expect(Ord(')'));
      AstTable[N].FirstChild := AstTable[ArgList].FirstChild;
    End;
  End Else If T = KW_UNDEF Then Begin
    N := NewNode(NK_LITERAL, T, ''); LexNextToken;
  End Else If T = Ord('(') Then Begin
    LexNextToken;
    If CurTokType = Ord(')') Then Begin
      N := NewNode(NK_LIST, 0, ''); LexNextToken;
    End Else Begin
      N := ParseAssign;
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then Begin
        ListN := NewNode(NK_LIST, 0, '');
        AppendArg(ListN, N);
        While (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Do Begin
          LexNextToken;
          If CurTokType = Ord(')') Then Break;
          AppendArg(ListN, ParseAssign);
        End;
        N := ListN;
      End;
      Expect(Ord(')'));
    End;
  End Else If T = Ord('[') Then Begin
    LexNextToken;
    N := NewNode(NK_ARRAY_LIT, Ord('['), '');
    While (CurTokType <> Ord(']')) And (CurTokType <> TOK_EOF) Do Begin
      AppendArg(N, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
    Expect(Ord(']'));
  End Else If (T = KW_MY) Or (T = KW_OUR) Or (T = KW_LOCAL) Then Begin
    LexNextToken; N := ParseVarDecl(T);
  End Else If T = TOK_IDENT Then Begin
    S := CurTokStr; LexNextToken;
    If CurTokType = Ord('(') Then Begin
      LexNextToken;
      N := NewNode(NK_CALL, TOK_IDENT, S);
      ArgList := ParseArgList; Expect(Ord(')'));
      AstTable[N].FirstChild := AstTable[ArgList].FirstChild;
    End Else
      N := NewNode(NK_LITERAL, TOK_IDENT, S);
  End Else If (T = KW_PRINT) Or (T = KW_SAY) Or (T = KW_PRINTF) Then Begin
    S := KeywordName(T); LexNextToken; N := ParseBuiltin(T, S);
  End Else If (T = KW_SORT) Or (T = KW_GREP) Or (T = KW_MAP) Then Begin
    S := KeywordName(T); LexNextToken; N := ParseSortGrepMap(T, S);
  End Else If (T = KW_PUSH) Or (T = KW_POP) Or (T = KW_SHIFT) Or
              (T = KW_UNSHIFT) Or (T = KW_SPLICE) Or (T = KW_REVERSE) Or
              (T = KW_JOIN) Or (T = KW_SPLIT) Or
              (T = KW_KEYS) Or
              (T = KW_VALUES) Or (T = KW_EACH) Or (T = KW_DELETE) Or
              (T = KW_EXISTS) Or (T = KW_SCALAR) Or (T = KW_OPEN) Or
              (T = KW_CLOSE) Or (T = KW_READLINE) Or (T = KW_BINMODE) Or
              (T = KW_DIE) Or (T = KW_WARN) Or (T = KW_EXIT) Or
              (T = KW_SPRINTF) Or (T = KW_SUBSTR) Or (T = KW_INDEX_FUNC) Or
              (T = KW_RINDEX) Or (T = KW_ATAN2) Or (T = KW_SLEEP) Or
              (T = KW_SRAND) Or (T = KW_STAT) Or (T = KW_UNLINK) Or
              (T = KW_RENAME) Or (T = KW_CHDIR) Or (T = KW_CALLER) Or
              (T = KW_EOF_FUNC) Then Begin
    S := KeywordName(T); LexNextToken; N := ParseBuiltin(T, S);
  End Else If (T = KW_LENGTH) Or (T = KW_CHOMP) Or (T = KW_CHOP) Or
              (T = KW_DEFINED) Or (T = KW_REF) Or (T = KW_BLESS) Or
              (T = KW_CHR) Or (T = KW_ORD) Or (T = KW_UC) Or
              (T = KW_LC) Or (T = KW_UCFIRST) Or (T = KW_LCFIRST) Or
              (T = KW_INT_FUNC) Or (T = KW_ABS) Or (T = KW_SQRT) Or
              (T = KW_SIN) Or (T = KW_COS) Or (T = KW_LOG) Or
              (T = KW_EXP) Or (T = KW_RAND) Or (T = KW_HEX) Or
              (T = KW_OCT) Or (T = KW_QUOTEMETA) Or
              (T = KW_WANTARRAY) Or (T = KW_TIME) Or (T = KW_POS) Then Begin
    S := KeywordName(T); LexNextToken; N := ParseBuiltin(T, S);
  End Else If T = Ord('{') Then Begin
    { Litteral hash-ref en contexte expression }
    LexNextToken;
    N := NewNode(NK_HASH_LIT, Ord('{'), '');
    While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do Begin
      AppendArg(N, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then LexNextToken
      Else Break;
    End;
    Expect(Ord('}'));
  End Else If T = KW_SUB Then Begin
    { Sous-routine anonyme : sub [PROTO] BLOCK }
    LexNextToken;
    ProtoStr := '';
    ProtoN   := 0;
    If CurTokType = Ord('(') Then Begin
      ProtoStr := ScanProtoStr;
      ProtoN   := NewNode(NK_LITERAL, 0, ProtoStr);
    End;
    N := NewNode(NK_ANON_SUB, KW_SUB, '');
    AstTable[N].Right := ProtoN;
    EnterScope(SCK_SUB);
    RegisterSubParams;
    AstTable[N].Left := ParseBlock;
    LeaveScope;
  End Else
    N := NewNode(NK_EMPTY, T, TokenName(T));
  ParsePrimary := N;
End;

Function ParsePostfix: Integer;
Var
  Base, N, IdxN, ArgList: Integer;
  MName: String;
Begin
  N := ParsePrimary;
  While True Do Begin
    If CurTokType = TOK_INCR Then Begin
      Base := N; LexNextToken;
      N := NewUn(TOK_INCR, Base);
      AstTable[N].Third := 1;  { postfix }
    End Else If CurTokType = TOK_DECR Then Begin
      Base := N; LexNextToken;
      N := NewUn(TOK_DECR, Base);
      AstTable[N].Third := 1;  { postfix }
    End Else If CurTokType = TOK_ARROW Then Begin
      LexNextToken;
      Base := N;
      If CurTokType = Ord('[') Then Begin
        LexNextToken; IdxN := ParseExpr; Expect(Ord(']'));
        N := NewNode(NK_INDEX, TOK_ARROW, '[');
        AstTable[N].Left := Base; AstTable[N].Right := IdxN;
      End Else If CurTokType = Ord('{') Then Begin
        LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
        N := NewNode(NK_INDEX, TOK_ARROW, '{');
        AstTable[N].Left := Base; AstTable[N].Right := IdxN;
      End Else If CurTokType = TOK_IDENT Then Begin
        MName := CurTokStr; LexNextToken;
        N := NewNode(NK_BINARY, TOK_ARROW, MName);
        AstTable[N].Left := Base;
        If CurTokType = Ord('(') Then Begin
          LexNextToken;
          ArgList := ParseArgList; Expect(Ord(')'));
          AstTable[N].Right := ArgList;
        End;
      End Else Break;
    End Else Break;
  End;
  ParsePostfix := N;
End;

Function ParsePow: Integer;
Var L, R: Integer;
Begin
  L := ParsePostfix;
  If CurTokType = TOK_POW Then Begin
    LexNextToken;
    R := ParseUnary;  { right-assoc; ParseUnary allows 2**-3 }
    L := NewBin(TOK_POW, L, R);
  End;
  ParsePow := L;
End;

Function ParseUnary: Integer;
Var T: Integer;
Begin
  T := CurTokType;
  If (T = TOK_INCR) Or (T = TOK_DECR) Then Begin
    LexNextToken;
    ParseUnary := NewUn(T, ParseUnary);
  End Else If (T = Ord('!')) Or (T = Ord('~')) Or (T = Ord('\')) Or
              (T = Ord('+')) Or (T = Ord('-')) Then Begin
    LexNextToken;
    ParseUnary := NewUn(T, ParseUnary);
  End Else
    ParseUnary := ParsePow;
End;

Function ParseBind: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseUnary;
  While (CurTokType = TOK_MATCH) Or (CurTokType = TOK_NMATCH) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseUnary;
    L := NewBin(Op, L, R);
  End;
  ParseBind := L;
End;

Function ParseMul: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseBind;
  While (CurTokType = Ord('*')) Or (CurTokType = Ord('/')) Or
        (CurTokType = Ord('%')) Or (CurTokType = KW_X_REP) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseBind;
    L := NewBin(Op, L, R);
  End;
  ParseMul := L;
End;

Function ParseAdd: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseMul;
  While (CurTokType = Ord('+')) Or (CurTokType = Ord('-')) Or
        (CurTokType = Ord('.')) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseMul;
    L := NewBin(Op, L, R);
  End;
  ParseAdd := L;
End;

Function ParseShift: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseAdd;
  While (CurTokType = TOK_SHL) Or (CurTokType = TOK_SHR) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseAdd;
    L := NewBin(Op, L, R);
  End;
  ParseShift := L;
End;

Function ParseCompare: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseShift;
  While (CurTokType = Ord('<')) Or (CurTokType = Ord('>')) Or
        (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Or
        (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Or
        (CurTokType = TOK_SPACESHIP) Or
        (CurTokType = KW_EQ_STR) Or (CurTokType = KW_NE_STR) Or
        (CurTokType = KW_LT_STR) Or (CurTokType = KW_GT_STR) Or
        (CurTokType = KW_LE_STR) Or (CurTokType = KW_GE_STR) Or
        (CurTokType = KW_CMP_STR) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseShift;
    L := NewBin(Op, L, R);
  End;
  ParseCompare := L;
End;

Function ParseBitAnd: Integer;
Var L, R: Integer;
Begin
  L := ParseCompare;
  While CurTokType = Ord('&') Do Begin
    LexNextToken; R := ParseCompare;
    L := NewBin(Ord('&'), L, R);
  End;
  ParseBitAnd := L;
End;

Function ParseBitOr: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseBitAnd;
  While (CurTokType = Ord('|')) Or (CurTokType = Ord('^')) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseBitAnd;
    L := NewBin(Op, L, R);
  End;
  ParseBitOr := L;
End;

Function ParseAndHi: Integer;
Var L, R: Integer;
Begin
  L := ParseBitOr;
  While CurTokType = TOK_ANDAND Do Begin
    LexNextToken; R := ParseBitOr;
    L := NewBin(TOK_ANDAND, L, R);
  End;
  ParseAndHi := L;
End;

Function ParseOrHi: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseAndHi;
  While (CurTokType = TOK_OROR) Or (CurTokType = TOK_DEFOR) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseAndHi;
    L := NewBin(Op, L, R);
  End;
  ParseOrHi := L;
End;

Function ParseRange: Integer;
Var LeftN, R, Op, N: Integer;
Begin
  LeftN := ParseOrHi;
  If (CurTokType = TOK_DOTDOT) Or (CurTokType = TOK_DOTDOTDOT) Then Begin
    Op := CurTokType; LexNextToken;
    R  := ParseOrHi;
    N  := NewNode(NK_RANGE, Op, '');
    AstTable[N].Left  := LeftN;
    AstTable[N].Right := R;
    ParseRange := N;
  End Else
    ParseRange := LeftN;
End;

Function ParseTernary: Integer;
Var L, ThenN, ElseN, N: Integer;
Begin
  L := ParseRange;
  If CurTokType = Ord('?') Then Begin
    LexNextToken;
    ThenN := ParseAssign;
    Expect(Ord(':'));
    ElseN := ParseAssign;
    N := NewNode(NK_TERNARY, Ord('?'), '');
    AstTable[N].Left  := L;
    AstTable[N].Right := ThenN;
    AstTable[N].Third := ElseN;
    ParseTernary := N;
  End Else
    ParseTernary := L;
End;

Function ParseAssign: Integer;
Var L, R, Op, N: Integer;
    OpStr: String;
Begin
  L     := ParseTernary;
  Op    := CurTokType;
  OpStr := CurTokStr;
  If (Op = Ord('=')) Or (Op = TOK_ASSIGN_OP) Then Begin
    LexNextToken;
    R := ParseAssign;  { right-assoc }
    N := NewNode(NK_ASSIGN, Op, OpStr);
    AstTable[N].Left  := L;
    AstTable[N].Right := R;
    ParseAssign := N;
  End Else
    ParseAssign := L;
End;

Function ParseNotLo: Integer;
Begin
  If CurTokType = KW_NOT Then Begin
    LexNextToken;
    ParseNotLo := NewUn(KW_NOT, ParseAssign);
  End Else
    ParseNotLo := ParseAssign;
End;

Function ParseAndLo: Integer;
Var L, R: Integer;
Begin
  L := ParseNotLo;
  While CurTokType = KW_AND Do Begin
    LexNextToken; R := ParseNotLo;
    L := NewBin(KW_AND, L, R);
  End;
  ParseAndLo := L;
End;

Function ParseOrLo: Integer;
Var L, R, Op: Integer;
Begin
  L := ParseAndLo;
  While (CurTokType = KW_OR) Or (CurTokType = KW_XOR) Do Begin
    Op := CurTokType; LexNextToken;
    R := ParseAndLo;
    L := NewBin(Op, L, R);
  End;
  ParseOrLo := L;
End;

Function ParseExpr: Integer;
Begin
  ParseExpr := ParseOrLo;
End;

{ ============================================================ }
{ TODO 07 : Parseur de statements                              }
{ ============================================================ }

{ Scanne SrcBuf a partir de LexPos (apres '(' deja consomme) }
{ Retourne vrai si on trouve un ';' a profondeur 0 -> for C   }
Function HasSemiAtDepth1: Boolean;
Var I, D: Integer;
Begin
  HasSemiAtDepth1 := False;
  D := 0;
  I := LexPos;
  While I <= SrcLen Do Begin
    Case SrcBuf[I] Of
      '(': Inc(D);
      ')': Begin
             If D = 0 Then Exit;
             Dec(D);
           End;
      ';': If D = 0 Then Begin
             HasSemiAtDepth1 := True;
             Exit;
           End;
      '#': While (I <= SrcLen) And (SrcBuf[I] <> #10) Do Inc(I);
    End;
    Inc(I);
  End;
End;

{ TODO 07 forward declarations }
Function ParseStatement: Integer; Forward;
Function ParseStatementList: Integer; Forward;

Function ParseBlock: Integer;
Var N: Integer;
Begin
  Expect(Ord('{'));
  EnterScope(SCK_BLOCK);
  N := ParseStatementList;
  LeaveScope;
  Expect(Ord('}'));
  ParseBlock := N;
End;

Function ParseStatementList: Integer;
Var Head, S: Integer;
Begin
  Head := NewNode(NK_STMT_LIST, 0, '');
  While (CurTokType <> TOK_EOF) And (CurTokType <> Ord('}')) Do Begin
    S := ParseStatement;
    If S <> 0 Then AppendArg(Head, S);
  End;
  ParseStatementList := Head;
End;

Function ParseStatement: Integer;
Var N, Cond, Body, Init, IncN, ElseN, Prev3, VarN, ListN, ProtoN: Integer;
    SubName, ProtoStr: String;
    IsCSuf: Boolean;
Begin
  ParseStatement := 0;

  { Skip bare semicolons }
  While CurTokType = Ord(';') Do LexNextToken;
  If (CurTokType = TOK_EOF) Or (CurTokType = Ord('}')) Then Exit;

  { if / unless }
  If (CurTokType = KW_IF) Or (CurTokType = KW_UNLESS) Then Begin
    N := NewNode(0, CurTokType, '');
    If CurTokType = KW_IF Then AstTable[N].Kind := NK_IF
    Else AstTable[N].Kind := NK_UNLESS;
    LexNextToken;
    Expect(Ord('('));
    Cond := ParseExpr;
    Expect(Ord(')'));
    Body := ParseBlock;
    AstTable[N].Left  := Cond;
    AstTable[N].Right := Body;
    { elsif / else chain }
    ElseN := 0;
    Prev3 := N;
    While CurTokType = KW_ELSIF Do Begin
      LexNextToken;
      Expect(Ord('('));
      Cond := ParseExpr;
      Expect(Ord(')'));
      Body := ParseBlock;
      ElseN := NewNode(NK_IF, KW_ELSIF, '');
      AstTable[ElseN].Left  := Cond;
      AstTable[ElseN].Right := Body;
      AstTable[Prev3].Third := ElseN;
      Prev3 := ElseN;
    End;
    If CurTokType = KW_ELSE Then Begin
      LexNextToken;
      Body := ParseBlock;
      ElseN := NewNode(NK_STMT_LIST, 0, '');
      AstTable[ElseN].Left := Body;
      AstTable[Prev3].Third := ElseN;
    End;
    ParseStatement := N;
    Exit;
  End;

  { while / until }
  If (CurTokType = KW_WHILE) Or (CurTokType = KW_UNTIL) Then Begin
    If CurTokType = KW_WHILE Then N := NewNode(NK_WHILE, KW_WHILE, '')
    Else N := NewNode(NK_UNTIL, KW_UNTIL, '');
    LexNextToken;
    Expect(Ord('('));
    Cond := ParseExpr;
    Expect(Ord(')'));
    Body := ParseBlock;
    AstTable[N].Left  := Cond;
    AstTable[N].Right := Body;
    ParseStatement := N;
    Exit;
  End;

  { do BLOCK while/until }
  If CurTokType = KW_DO Then Begin
    LexNextToken;
    If CurTokType = Ord('{') Then Begin
      Body := ParseBlock;
      If (CurTokType = KW_WHILE) Or (CurTokType = KW_UNTIL) Then Begin
        IsCSuf := (CurTokType = KW_UNTIL);
        LexNextToken;
        Expect(Ord('('));
        Cond := ParseExpr;
        Expect(Ord(')'));
        N := NewNode(NK_DO_WHILE, 0, '');
        AstTable[N].Left  := Body;
        AstTable[N].Right := Cond;
        If IsCSuf Then AstTable[N].Tok := KW_UNTIL;
        If CurTokType = Ord(';') Then LexNextToken;
        ParseStatement := N;
      End Else Begin
        If CurTokType = Ord(';') Then LexNextToken;
        ParseStatement := Body;
      End;
      Exit;
    End Else Begin
      { do EXPR - treated as expression statement }
      N := ParsePrimary;   { re-entry won't work; fall through to expr below }
      If CurTokType = Ord(';') Then LexNextToken;
      ParseStatement := N;
      Exit;
    End;
  End;

  { for / foreach }
  If (CurTokType = KW_FOR) Or (CurTokType = KW_FOREACH) Then Begin
    LexNextToken;
    If CurTokType = Ord('(') Then Begin
      { C-style or foreach — peek for semicolon }
      LexNextToken;  { consume '(' }
      If HasSemiAtDepth1 Then Begin
        { for (init; cond; incr) body }
        If CurTokType = Ord(';') Then Init := 0
        Else Init := ParseExpr;
        Expect(Ord(';'));
        If CurTokType = Ord(';') Then Cond := 0
        Else Cond := ParseExpr;
        Expect(Ord(';'));
        If CurTokType = Ord(')') Then IncN := 0
        Else IncN := ParseExpr;
        Expect(Ord(')'));
        Body := ParseBlock;
        N := NewNode(NK_FOR_C, KW_FOR, '');
        AstTable[N].Left  := Init;
        AstTable[N].Right := Cond;
        AstTable[N].Third := IncN;
        AstTable[N].FirstChild := Body;
        ParseStatement := N;
        Exit;
      End Else Begin
        { foreach (LIST) or foreach my $var (LIST) }
        VarN := 0;
        If (CurTokType = KW_MY) Or (CurTokType = KW_OUR) Or
           (CurTokType = KW_LOCAL) Then Begin
          VarN := ParseVarDecl(CurTokType);
        End Else If CurTokType = TOK_SIGIL_SCALAR Then Begin
          VarN := ParsePrimary;
        End;
        ListN := ParseExpr;
        Expect(Ord(')'));
        Body := ParseBlock;
        N := NewNode(NK_FOREACH, KW_FOREACH, '');
        AstTable[N].Left      := VarN;
        AstTable[N].Right     := ListN;
        AstTable[N].FirstChild := Body;
        ParseStatement := N;
        Exit;
      End;
    End Else Begin
      { foreach without parens (rare bare form) - treat as expr stmt }
    End;
  End;

  { return }
  If CurTokType = KW_RETURN Then Begin
    LexNextToken;
    N := NewNode(NK_RETURN, KW_RETURN, '');
    If (CurTokType <> Ord(';')) And (CurTokType <> TOK_EOF) And
       (CurTokType <> Ord('}')) Then Begin
      AstTable[N].Left := ParseExpr;
    End;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { last / next / redo }
  If (CurTokType = KW_LAST) Or (CurTokType = KW_NEXT) Or
     (CurTokType = KW_REDO) Then Begin
    If CurTokType = KW_LAST Then N := NewNode(NK_LAST, KW_LAST, '')
    Else If CurTokType = KW_NEXT Then N := NewNode(NK_NEXT, KW_NEXT, '')
    Else N := NewNode(NK_REDO, KW_REDO, '');
    LexNextToken;
    { optional label }
    If CurTokType = TOK_IDENT Then Begin
      AstTable[N].Text := CurTokStr;
      LexNextToken;
    End;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { sub NAME [PROTO] BLOCK }
  If CurTokType = KW_SUB Then Begin
    LexNextToken;
    SubName  := '';
    ProtoStr := '';
    ProtoN   := 0;
    If CurTokType = TOK_IDENT Then Begin
      SubName := CurTokStr; LexNextToken;
    End;
    { prototype optionnel : sub foo ($$;@) }
    If CurTokType = Ord('(') Then Begin
      ProtoStr := ScanProtoStr;
      ProtoN   := NewNode(NK_LITERAL, 0, ProtoStr);
    End;
    N := NewNode(NK_SUB_DEF, KW_SUB, SubName);
    AstTable[N].Right := ProtoN;
    If SubName <> '' Then
      AstTable[N].SymRef := AddSym(SubName, SK_CODE, SCOPE_PACKAGE, 0);
    EnterScope(SCK_SUB);
    RegisterSubParams;
    AstTable[N].Left := ParseBlock;
    LeaveScope;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { use MODULE }
  If CurTokType = KW_USE Then Begin
    LexNextToken;
    N := NewNode(NK_USE, KW_USE, '');
    If CurTokType = TOK_IDENT Then Begin
      AstTable[N].Text := CurTokStr; LexNextToken;
    End;
    While (CurTokType <> Ord(';')) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { package NAME }
  If CurTokType = KW_PACKAGE Then Begin
    LexNextToken;
    N := NewNode(NK_PACKAGE, KW_PACKAGE, '');
    If CurTokType = TOK_IDENT Then Begin
      AstTable[N].Text := CurTokStr;
      CurrentPkg := CurTokStr;
      LexNextToken;
    End;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { BEGIN-BLOCK }
  If CurTokType = KW_BEGIN Then Begin
    LexNextToken;
    N := NewNode(NK_BEGIN_HOOK, KW_BEGIN, '');
    AstTable[N].Left := ParseBlock;
    ParseStatement := N;
    Exit;
  End;

  { END-BLOCK }
  If CurTokType = KW_END Then Begin
    LexNextToken;
    N := NewNode(NK_END_HOOK, KW_END, '');
    AstTable[N].Left := ParseBlock;
    ParseStatement := N;
    Exit;
  End;

  { Bare block }
  If CurTokType = Ord('{') Then Begin
    N := ParseBlock;
    ParseStatement := N;
    Exit;
  End;

  { Expression statement (y compris my/our/local, appels, affectations) }
  N := ParseExpr;
  { Suffix modifiers }
  If IsModifierKW(CurTokType) Then Begin
    Cond := 0;
    VarN := 0;
    Case CurTokType Of
      KW_IF: Begin
               LexNextToken;
               Cond := ParseExpr;
               Body := N;
               N := NewNode(NK_IF, KW_IF, '');
               AstTable[N].Left  := Cond;
               AstTable[N].Right := Body;
             End;
      KW_UNLESS: Begin
               LexNextToken;
               Cond := ParseExpr;
               Body := N;
               N := NewNode(NK_UNLESS, KW_UNLESS, '');
               AstTable[N].Left  := Cond;
               AstTable[N].Right := Body;
             End;
      KW_WHILE: Begin
               LexNextToken;
               Cond := ParseExpr;
               Body := N;
               N := NewNode(NK_WHILE, KW_WHILE, '');
               AstTable[N].Left  := Cond;
               AstTable[N].Right := Body;
               AstTable[N].Third := 1;  { suffix marker }
             End;
      KW_UNTIL: Begin
               LexNextToken;
               Cond := ParseExpr;
               Body := N;
               N := NewNode(NK_UNTIL, KW_UNTIL, '');
               AstTable[N].Left  := Cond;
               AstTable[N].Right := Body;
               AstTable[N].Third := 1;
             End;
      KW_FOR, KW_FOREACH: Begin
               LexNextToken;
               { optionnel: my $var }
               VarN := 0;
               If (CurTokType = KW_MY) Or (CurTokType = KW_OUR) Then
                 VarN := ParseVarDecl(CurTokType)
               Else If CurTokType = TOK_SIGIL_SCALAR Then
                 VarN := ParsePrimary;
               If CurTokType = Ord('(') Then Begin
                 LexNextToken;
                 ListN := ParseExpr;
                 Expect(Ord(')'));
               End Else
                 ListN := ParseExpr;
               Body := N;
               N := NewNode(NK_FOREACH, KW_FOREACH, '');
               AstTable[N].Left      := VarN;
               AstTable[N].Right     := ListN;
               AstTable[N].FirstChild := Body;
               AstTable[N].Third     := 1;  { suffix marker }
             End;
    End;
  End;
  If CurTokType = Ord(';') Then LexNextToken;
  ParseStatement := N;
End;

Function ParseProgram: Integer;
Var Root, S: Integer;
Begin
  InitAST;
  InitSymTable;
  LexNextToken;
  Root := NewNode(NK_STMT_LIST, 0, '');
  While CurTokType <> TOK_EOF Do Begin
    S := ParseStatement;
    If S <> 0 Then AppendArg(Root, S);
  End;
  PropagateCtx(Root, CTX_VOID);
  ParseProgram := Root;
End;

{ ============================================================ }
{ TODO 09 : Tableaux (@) et fonctions de tableaux              }
{ ============================================================ }

{ Noms des fonctions runtime pour les tableaux }
Function PlRtArrayNew:     String; Begin PlRtArrayNew     := '_PLRT_array_new';     End;
Function PlRtArrayPush:    String; Begin PlRtArrayPush    := '_PLRT_array_push';    End;
Function PlRtArrayPop:     String; Begin PlRtArrayPop     := '_PLRT_array_pop';     End;
Function PlRtArrayGet:     String; Begin PlRtArrayGet     := '_PLRT_array_get';     End;
Function PlRtArraySet:     String; Begin PlRtArraySet     := '_PLRT_array_set';     End;
Function PlRtArrayLen:     String; Begin PlRtArrayLen     := '_PLRT_array_len';     End;
Function PlRtArrayShift:   String; Begin PlRtArrayShift   := '_PLRT_array_shift';   End;
Function PlRtArrayUnshift: String; Begin PlRtArrayUnshift := '_PLRT_array_unshift'; End;
Function PlRtArraySplice:  String; Begin PlRtArraySplice  := '_PLRT_array_splice';  End;
Function PlRtArraySlice:   String; Begin PlRtArraySlice   := '_PLRT_array_slice';   End;
Function PlRtArrayExists:  String; Begin PlRtArrayExists  := '_PLRT_array_exists';  End;
Function PlRtArrayDelete:  String; Begin PlRtArrayDelete  := '_PLRT_array_delete';  End;
Function PlRtArrayReverse: String; Begin PlRtArrayReverse := '_PLRT_array_reverse'; End;
Function PlRtArraySort:    String; Begin PlRtArraySort    := '_PLRT_array_sort';    End;
Function PlRtArrayGrep:    String; Begin PlRtArrayGrep    := '_PLRT_array_grep';    End;
Function PlRtArrayMap:     String; Begin PlRtArrayMap     := '_PLRT_array_map';     End;
Function PlRtArrayJoin:    String; Begin PlRtArrayJoin    := '_PLRT_array_join';    End;
Function PlRtArraySplit:   String; Begin PlRtArraySplit   := '_PLRT_array_split';   End;
Function PlRtArrayScalar:  String; Begin PlRtArrayScalar  := '_PLRT_array_scalar';  End;

{ Bloc expression entre accolades pour sort/grep/map }
Function ParseCodeBlock: Integer;
Var N: Integer;
Begin
  Expect(Ord('{'));
  N := NewNode(NK_CODE_BLOCK, 0, '');
  If CurTokType <> Ord('}') Then
    AstTable[N].Left := ParseExpr;
  Expect(Ord('}'));
  ParseCodeBlock := N;
End;

{ Parser special pour sort, grep, map (acceptent un bloc en 1er arg) }
Function ParseSortGrepMap(KwTok: Integer; S: String): Integer;
Var N, ArgList, CmpN, SaIdx, SbIdx: Integer;
Begin
  N       := NewNode(NK_CALL, KwTok, S);
  ArgList := NewNode(NK_LIST, 0, '');
  SaIdx   := 0;
  SbIdx   := 0;

  If CurTokType = Ord('{') Then Begin
    { bloc comparateur/filtre/transformateur }
    If KwTok = KW_SORT Then Begin
      { $a et $b sont visibles dans le bloc de comparaison }
      SaIdx := AddSym('a', SK_SCALAR, SCOPE_LEXICAL, 0);
      SbIdx := AddSym('b', SK_SCALAR, SCOPE_LEXICAL, 0);
    End;
    CmpN := ParseCodeBlock;
    AstTable[CmpN].Tok := KwTok;
    AppendArg(ArgList, CmpN);
    { marquer $a et $b comme morts apres le bloc (sort seulement) }
    If KwTok = KW_SORT Then Begin
      If SaIdx > 0 Then SymTable[SaIdx].Flags := SymTable[SaIdx].Flags Or SF_DEAD;
      If SbIdx > 0 Then SymTable[SbIdx].Flags := SymTable[SbIdx].Flags Or SF_DEAD;
    End;
    { virgule optionnelle apres le bloc }
    If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then LexNextToken;
  End Else If (KwTok = KW_SORT) And (CurTokType = TOK_IDENT) Then Begin
    { sort SUBNAME LIST : sous-routine comparateur }
    CmpN := NewNode(NK_LITERAL, TOK_IDENT, CurTokStr);
    LexNextToken;
    AppendArg(ArgList, CmpN);
    If (CurTokType = Ord(',')) Then LexNextToken;
  End;

  { arguments restants (la liste) }
  If CurTokType = Ord('(') Then Begin
    LexNextToken;
    While (CurTokType <> Ord(')')) And (CurTokType <> TOK_EOF) Do Begin
      AppendArg(ArgList, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
    Expect(Ord(')'));
  End Else Begin
    While Not IsArgStopper(CurTokType) Do Begin
      AppendArg(ArgList, ParseAssign);
      If (CurTokType = Ord(',')) Or (CurTokType = TOK_FATCOMMA) Then
        LexNextToken
      Else Break;
    End;
  End;
  AstTable[N].FirstChild := AstTable[ArgList].FirstChild;
  ParseSortGrepMap := N;
End;

{ ============================================================ }
{ TODO 08 : Sous-routines et parametres (@_)                   }
{ ============================================================ }

{ Scanne les caracteres bruts du prototype depuis LexPos       }
{ Appele quand CurTokType = '(' : LexPos pointe apres '('      }
{ Apres retour : LexNextToken a ete appele, CurTokType = token suivant }
Function ScanProtoStr: String;
Var P: String; C: Char;
Begin
  P := '';
  While LexPos <= SrcLen Do Begin
    C := SrcBuf[LexPos];
    If C = ')' Then Begin Inc(LexPos); Break; End;
    If C >= ' ' Then P := P + C;
    Inc(LexPos);
  End;
  LexNextToken;
  ScanProtoStr := P;
End;

{ ============================================================ }
{ TODO 11 : Contexte scalaire vs liste et operateurs           }
{ ============================================================ }

{ Propage le contexte d evaluation dans l arbre AST            }
{ InCtx = contexte attendu par le parent du noeud              }
Procedure PropagateCtx(Node, InCtx: Integer);
Var C, Next, RCtx, LKind, LTok: Integer;
Begin
  If Node = 0 Then Exit;
  AstTable[Node].Ctx := InCtx;
  Case AstTable[Node].Kind Of

    NK_STMT_LIST: Begin
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        Next := AstTable[C].NextSibling;
        If Next = 0 Then PropagateCtx(C, InCtx)
        Else PropagateCtx(C, CTX_VOID);
        C := Next;
      End;
    End;

    NK_IF, NK_UNLESS: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_BOOL);
      PropagateCtx(AstTable[Node].Right, InCtx);
      PropagateCtx(AstTable[Node].Third, InCtx);
    End;

    NK_WHILE, NK_UNTIL: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_BOOL);
      PropagateCtx(AstTable[Node].Right, CTX_VOID);
    End;

    NK_DO_WHILE: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_VOID);
      PropagateCtx(AstTable[Node].Right, CTX_BOOL);
    End;

    NK_FOR_C: Begin
      PropagateCtx(AstTable[Node].Left,      CTX_VOID);
      PropagateCtx(AstTable[Node].Right,     CTX_BOOL);
      PropagateCtx(AstTable[Node].Third,     CTX_VOID);
      PropagateCtx(AstTable[Node].FirstChild,CTX_VOID);
    End;

    NK_FOREACH: Begin
      PropagateCtx(AstTable[Node].Left,      CTX_SCALAR);
      PropagateCtx(AstTable[Node].Right,     CTX_LIST);
      PropagateCtx(AstTable[Node].FirstChild,CTX_VOID);
    End;

    NK_ASSIGN: Begin
      { le sigil du LHS determine le contexte du RHS }
      LKind := 0; LTok := 0;
      If AstTable[Node].Left <> 0 Then Begin
        LKind := AstTable[AstTable[Node].Left].Kind;
        LTok  := AstTable[AstTable[Node].Left].Tok;
      End;
      If (LTok = TOK_SIGIL_ARRAY) Or (LTok = TOK_SIGIL_HASH) Or
         (LKind = NK_LIST) Then
        RCtx := CTX_LIST
      Else
        RCtx := CTX_SCALAR;
      PropagateCtx(AstTable[Node].Left,  CTX_SCALAR);
      PropagateCtx(AstTable[Node].Right, RCtx);
    End;

    NK_TERNARY: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_BOOL);
      PropagateCtx(AstTable[Node].Right, InCtx);
      PropagateCtx(AstTable[Node].Third, InCtx);
    End;

    NK_BINARY: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_SCALAR);
      PropagateCtx(AstTable[Node].Right, CTX_SCALAR);
    End;

    NK_UNARY: Begin
      PropagateCtx(AstTable[Node].Left, CTX_SCALAR);
    End;

    NK_RANGE: Begin
      { .. -> liste ou flip-flop selon InCtx (deja marque) }
      PropagateCtx(AstTable[Node].Left,  CTX_SCALAR);
      PropagateCtx(AstTable[Node].Right, CTX_SCALAR);
    End;

    NK_CALL: Begin
      { les arguments sont en contexte scalaire par defaut }
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        PropagateCtx(C, CTX_SCALAR);
        C := AstTable[C].NextSibling;
      End;
    End;

    NK_CODE_BLOCK: Begin
      PropagateCtx(AstTable[Node].Left, CTX_SCALAR);
    End;

    NK_RETURN: Begin
      PropagateCtx(AstTable[Node].Left, InCtx);
    End;

    NK_LIST: Begin
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        PropagateCtx(C, CTX_SCALAR);
        C := AstTable[C].NextSibling;
      End;
    End;

    NK_ARRAY_LIT: Begin
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        PropagateCtx(C, CTX_SCALAR);
        C := AstTable[C].NextSibling;
      End;
    End;

    NK_HASH_LIT: Begin
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        PropagateCtx(C, CTX_SCALAR);
        C := AstTable[C].NextSibling;
      End;
    End;

    NK_INDEX: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_SCALAR);
      PropagateCtx(AstTable[Node].Right, CTX_SCALAR);
    End;

    NK_SLICE: Begin
      PropagateCtx(AstTable[Node].Left,  CTX_LIST);
      PropagateCtx(AstTable[Node].Right, CTX_LIST);
    End;

    NK_SUB_DEF, NK_ANON_SUB: Begin
      PropagateCtx(AstTable[Node].Left, CTX_VOID);
    End;

    NK_BEGIN_HOOK, NK_END_HOOK: Begin
      PropagateCtx(AstTable[Node].Left, CTX_VOID);
    End;

  End;
End;

{ ============================================================ }
{ TODO 10 : Hashes (%) et fonctions de hashes                  }
{ ============================================================ }

{ Noms des fonctions runtime pour les hashes }
Function PlRtHashNew:    String; Begin PlRtHashNew    := '_PLRT_hash_new';    End;
Function PlRtHashSet:    String; Begin PlRtHashSet    := '_PLRT_hash_set';    End;
Function PlRtHashGet:    String; Begin PlRtHashGet    := '_PLRT_hash_get';    End;
Function PlRtHashExists: String; Begin PlRtHashExists := '_PLRT_hash_exists'; End;
Function PlRtHashDelete: String; Begin PlRtHashDelete := '_PLRT_hash_delete'; End;
Function PlRtHashKeys:   String; Begin PlRtHashKeys   := '_PLRT_hash_keys';   End;
Function PlRtHashValues: String; Begin PlRtHashValues := '_PLRT_hash_values'; End;
Function PlRtHashEach:   String; Begin PlRtHashEach   := '_PLRT_hash_each';   End;
Function PlRtHashLen:    String; Begin PlRtHashLen    := '_PLRT_hash_len';    End;
Function PlRtHashScalar: String; Begin PlRtHashScalar := '_PLRT_hash_scalar'; End;
Function PlRtHashSlice:  String; Begin PlRtHashSlice  := '_PLRT_hash_slice';  End;
Function PlRtHashMerge:  String; Begin PlRtHashMerge  := '_PLRT_hash_merge';  End;

{ Enregistre @_ dans la portee courante (portee de sous-routine) }
Procedure RegisterSubParams;
Var Idx: Integer;
Begin
  Idx := AddSym('_', SK_ARRAY, SCOPE_DYNAMIC, 0);
  If Opt.Verbose Then
    WriteLn('  [sub] @_ registre idx=', Idx);
End;

BEGIN
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
  If Opt.DebugMode Then Begin
    WriteLn('PERLCW32: mode debug - dump des tokens');
    DumpTokens;
  End Else
    WriteLn('PERLCW32: TODO - compilateur en cours d''implementation');
  Halt(EXIT_OK);
END.
