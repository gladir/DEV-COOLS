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
  TOK_FTEST        = 295;   { -e -f -d ... : test fichier }
  TOK_DIAMOND      = 296;   { <> : lecture stdin magique }
  TOK_ANGLE_RD     = 297;   { <HANDLE> <$fh> : lecture filehandle }

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
  NK_INTERP     = 39;   { chaine avec interpolation : enfants = segments }

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

Const
  MAX_CONST_TABLE = 256;

Type
  TConstEntry = Record
    Name:   String;
    Kind:   Integer;   { TOK_INTEGER, TOK_FLOAT, TOK_STRING }
    IVal:   LongInt;
    FText:  String;    { texte de la valeur float ou chaine }
  End;
  TConstTable = Array[1..MAX_CONST_TABLE] Of TConstEntry;

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
  PLKCount:       Integer;   { compteur labels _PLK_ chaines .rdata }
  PLRECount:      Integer;   { compteur labels _PLRE_ regex compilee }
  PLLCount:       Integer;   { compteur labels _PLL_ sauts internes }
  PLFCount:       Integer;   { compteur labels _PLF_ flottants .rdata }
  AsmOut:         Text;      { fichier de sortie ASM (-asm) }
  AsmOutOpen:     Boolean;   { AsmOut est ouvert }
  UseIntPragma:   Boolean;   { use integer : force aritmetique entiere }
  StrictVars:     Boolean;   { use strict 'vars'  }
  StrictRefs:     Boolean;   { use strict 'refs'  }
  StrictSubs:     Boolean;   { use strict 'subs'  }
  WarnFlags:      Integer;   { bitmask categories warnings actives }
  WarnFatal:      Boolean;   { use warnings FATAL => 'all' }
  ConstTable:     TConstTable;
  ConstCount:     Integer;
  PLFQueue:       Array[1..MAX_CONST_TABLE] Of String;   { valeur DQ }
  PLFQueueLbl:    Array[1..MAX_CONST_TABLE] Of String;   { label }
  PLFQueueLen:    Integer;
  AsmRoot:        Integer;  { noeud racine AST pour le programme }
  AsmFrameSz:     Integer;  { taille frame principale (top-level) }

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

Procedure ParseError(Msg: String);
Begin
  Inc(ParseErrors);
  WriteLn('PERLCW32: erreur ligne ', LexLine, ': ', Msg);
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

Function IsFileTestLetter(C: Char): Boolean;
Begin
  IsFileTestLetter := (C = 'e') Or (C = 'f') Or (C = 'd') Or (C = 'r') Or
                      (C = 'w') Or (C = 'x') Or (C = 'l') Or (C = 's') Or
                      (C = 'z') Or (C = 'M') Or (C = 'A') Or (C = 'C') Or
                      (C = 'p') Or (C = 'S') Or (C = 'b') Or (C = 'c') Or
                      (C = 'T') Or (C = 'B');
End;

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

Function IsAngleReadAhead: Boolean;
Var I: LongInt; Ch: Char;
Begin
  IsAngleReadAhead := False;
  I := LexPos + 1;
  If I > SrcLen Then Exit;
  Ch := SrcBuf[I];
  If Not (IsAlpha(Ch) Or (Ch = '$')) Then Exit;
  Inc(I);
  While I <= SrcLen Do Begin
    Ch := SrcBuf[I];
    If Ch = '>' Then Begin IsAngleReadAhead := True; Exit; End;
    If Not (IsAlpha(Ch) Or IsDigit(Ch) Or (Ch = ':')) Then Exit;
    Inc(I);
  End;
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
           End Else If (LexPeekChar = '$') And
                       (IsAlpha(LexPeekChar2) Or (LexPeekChar2 = '_')) Then Begin
             { $$varname : dereference scalaire }
             CurTokType := TOK_DEREF_SCALAR;
             LexNextChar;  { consomme le 2eme $ sans l'ajouter }
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
           End Else
             ReadSpecialScalar;
         End;
    '@': Begin
           CurTokType := TOK_SIGIL_ARRAY;
           If (LexPeekChar = '$') And
              (IsAlpha(LexPeekChar2) Or (LexPeekChar2 = '_')) Then Begin
             { @$varname : dereference tableau }
             CurTokType := TOK_DEREF_ARRAY;
             LexNextChar;
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
           End Else If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar)
           Else If (LexPeekChar = '+') Or (LexPeekChar = '-') Then
             AppendTok(LexNextChar);
         End;
    '%': Begin
           CurTokType := TOK_SIGIL_HASH;
           If (LexPeekChar = '$') And
              (IsAlpha(LexPeekChar2) Or (LexPeekChar2 = '_')) Then Begin
             { %$varname : dereference hash }
             CurTokType := TOK_DEREF_HASH;
             LexNextChar;
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar);
           End Else If IsAlpha(LexPeekChar) Or (LexPeekChar = '_') Then
             While IsIdentChar(LexPeekChar) Do AppendTok(LexNextChar)
           Else If LexPeekChar = '+' Then
             AppendTok(LexNextChar);
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
    If (C = ' ') Or (C = #9) Or (C = #10) Or (C = #13) Then LexNextChar
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
    End Else If IsFileTestLetter(C2) And Not IsIdentChar(C3) Then Begin
      CurTokType := TOK_FTEST;
      LexNextChar;              { consomme '-' sans l'ajouter }
      AppendTok(LexNextChar);   { consomme et ajoute la lettre dans CurTokStr }
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
  Else If C = '<' Then Begin
    If C2 = '>' Then Begin
      CurTokType := TOK_DIAMOND; LexNextChar; LexNextChar;
    End Else If IsAngleReadAhead Then Begin
      CurTokType := TOK_ANGLE_RD;
      LexNextChar; { consomme '<' sans l'ajouter }
      While (LexPeekChar <> '>') And (LexPeekChar <> #0) And (LexPeekChar <> #10) Do
        AppendTok(LexNextChar);
      If LexPeekChar = '>' Then LexNextChar; { consomme '>' }
    End Else Begin CurTokType := Ord('<'); AppendTok(LexNextChar); End;
  End
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
    TOK_FTEST:        TokenName := 'TOK_FTEST';
    TOK_DIAMOND:      TokenName := 'TOK_DIAMOND';
    TOK_ANGLE_RD:     TokenName := 'TOK_ANGLE_RD';
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
{ TODO 07/08/09/11/12/13 cross-section forwards }
Function ParseBlock:                        Integer; Forward;
Function ScanProtoStr:                      String;  Forward;
Procedure RegisterSubParams;                Forward;
Function ParseCodeBlock:                    Integer; Forward;
Function ParseSortGrepMap(KwTok: Integer; S: String): Integer; Forward;
Procedure PropagateCtx(Node, InCtx: Integer); Forward;
Function ParseInterpolatedStr(Src: String; TokT: Integer): Integer; Forward;
Function ExtractRegexPat(S: String): String;  Forward;
Function ExtractRegexFlags(S: String): String; Forward;
Function ExtractSubstRpl(S: String): String;  Forward;
Function ExtractSubstFlags(S: String): String; Forward;
Function ParseRegexFlags(F: String): Integer; Forward;
Function ParseTransFlags(F: String): Integer; Forward;
{ TODO 14 cross-section forwards }
Function ExpandTransList(S: String): String;   Forward;
Function ProcessSubstRepl(S: String): String;  Forward;
{ TODO 15 cross-section forwards }
Procedure CodegenNode(Node: Integer); Forward;
Function  NumToStr(N: Integer): String; Forward;
Function  MakePLLLabel(Pfx: String; N: Integer; Suf: String): String; Forward;
Procedure EmitLine(S: String);    Forward;
Procedure EmitLabel(L: String);   Forward;
Procedure EmitComment(C: String); Forward;
Procedure EmitBoolTest(Node: Integer); Forward;
{ TODO 17 cross-section forwards }
Procedure CodegenDeref(Node: Integer);  Forward;
Procedure CodegenRefOp(Node: Integer);  Forward;
{ TODO 18 cross-section forwards }
Procedure CodegenVar(Node: Integer);        Forward;
Procedure EmitDataDecl(Lbl, Decl: String);  Forward;
Procedure EmitSpecialVarDecls;              Forward;
Procedure CodegenPrologue;                  Forward;
{ TODO 19 cross-section forwards }
Procedure CodegenLiteral(Node: Integer);    Forward;
Procedure CodegenBinaryOp(Node: Integer);   Forward;
Procedure CodegenUnaryArith(Node: Integer); Forward;
Procedure CodegenMathCall(Node: Integer);   Forward;
{ TODO 20 cross-section forwards }
Function  EmitPushArgs(Node: Integer): Integer;   Forward;
Procedure CodegenBuiltinCall(Node: Integer);      Forward;
{ TODO 21 cross-section forwards }
Procedure CodegenFileIO(Node: Integer);           Forward;
{ TODO 22 cross-section forwards }
Function  FindConst(Name: String): Integer;       Forward;
Procedure RegisterConst(CName: String; Kind: Integer;
                        IVal: LongInt; FText: String); Forward;
Procedure FlushFloatConsts;                       Forward;
{ TODO 23 cross-section forwards }
Procedure CheckStrictVar(VName: String; Sigil: Char); Forward;
Procedure CodegenPragma(Node: Integer);               Forward;
{ TODO 24 cross-section forwards - aucun : definis avant CodegenNode }
{ TODO 25 cross-section forwards }
Procedure BinInit;                                              Forward;
Procedure BinCodegenProgram(Root: Integer; FrameSz: Integer);  Forward;
Procedure WriteCOFF(FileName: String);                         Forward;
Procedure WritePE(FileName: String);                           Forward;

{ Constantes de flags regex/trans et warnings, definies ici avant ParsePrimary }
Const
  WARN_NUMERIC    = 1;    { warning coercions numeriques }
  WARN_UNINIT     = 2;    { warning variable non initialisee }
  WARN_REDEFINE   = 4;    { warning redefinition de sub }
  WARN_DEPRECATED = 8;    { warning fonctionnalite obsolete }
  WARN_ONCE       = 16;   { warning utilise une seule fois }
  WARN_SHADOW     = 32;   { warning masquage de variable }
  WARN_ALL        = 63;   { tous les warnings actives }

  REGEX_FLAG_I = 1;    { case insensitive }
  REGEX_FLAG_G = 2;    { global }
  REGEX_FLAG_M = 4;    { multiline }
  REGEX_FLAG_S = 8;    { singleline (. inclut \n) }
  REGEX_FLAG_X = 16;   { extended (espaces ignores) }
  REGEX_FLAG_E = 32;   { eval du remplacement }
  REGEX_FLAG_R = 64;   { non-destructif }
  TRANS_FLAG_C = 1;    { complement de la liste source }
  TRANS_FLAG_D = 2;    { supprime les non-correspondants }
  TRANS_FLAG_S = 4;    { squeeze des repetitions }

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
  End Else If T = TOK_STRING Then Begin
    N := NewNode(NK_LITERAL, T, CurTokStr); LexNextToken;
  End Else If (T = TOK_DSTRING) Or (T = TOK_HEREDOC) Then Begin
    S := CurTokStr; LexNextToken;
    N := ParseInterpolatedStr(S, T);
  End Else If T = TOK_REGEX Then Begin
    { NK_REGEX : Text=pattern, Left=flags bitmask, Third=index PLRE }
    N := NewNode(NK_REGEX, T, ExtractRegexPat(CurTokStr));
    AstTable[N].Left  := ParseRegexFlags(ExtractRegexFlags(CurTokStr));
    Inc(PLRECount);
    AstTable[N].Third := PLRECount;
    LexNextToken;
  End Else If T = TOK_SUBST Then Begin
    { NK_SUBST : Text=pattern, Left=flags, Third=PLRE_idx, Right=PLK_idx }
    { FirstChild -> noeud remplacement (NK_INTERP ou NK_LITERAL si /e)    }
    N := NewNode(NK_SUBST, T, ExtractRegexPat(CurTokStr));
    AstTable[N].Left  := ParseRegexFlags(ExtractSubstFlags(CurTokStr));
    Inc(PLRECount);
    AstTable[N].Third := PLRECount;
    S := ProcessSubstRepl(ExtractSubstRpl(CurTokStr));
    If (AstTable[N].Left And REGEX_FLAG_E) <> 0 Then Begin
      { /e : remplacement est du code Perl - stocke brut pour codegen }
      VarN := NewNode(NK_LITERAL, TOK_STRING, S);
    End Else Begin
      { interpolation du remplacement ($1, $var, etc.) }
      VarN := ParseInterpolatedStr(S, TOK_DSTRING);
      Inc(PLKCount);
      AstTable[N].Right := PLKCount;
    End;
    AstTable[N].FirstChild := VarN;
    LexNextToken;
  End Else If T = TOK_TRANS Then Begin
    { NK_TRANS : Text=src_etendu, Left=flags, FirstChild=NK_LITERAL(dst_etendu) }
    N := NewNode(NK_TRANS, T, ExpandTransList(ExtractRegexPat(CurTokStr)));
    AstTable[N].Left  := ParseTransFlags(ExtractSubstFlags(CurTokStr));
    VarN := NewNode(NK_LITERAL, TOK_STRING, ExpandTransList(ExtractSubstRpl(CurTokStr)));
    AstTable[N].FirstChild := VarN;
    LexNextToken;
  End Else If T = TOK_QWORD Then Begin
    N := NewNode(NK_ARRAY_LIT, T, CurTokStr); LexNextToken;
  End Else If T = TOK_HASHNUM Then Begin
    VName := Copy(CurTokStr, 3, Length(CurTokStr));
    N := NewNode(NK_VAR, T, VName); LexNextToken;
  End Else If T = TOK_SIGIL_SCALAR Then Begin
    VName := Copy(CurTokStr, 2, Length(CurTokStr)); LexNextToken;
    CheckStrictVar(VName, '$');
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
    CheckStrictVar(VName, '@');
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
    CheckStrictVar(VName, '%');
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
    End Else Begin
      { Cherche si c'est une constante nommee (use constant) }
      Sigil := FindConst(S);
      If Sigil > 0 Then Begin
        N := NewNode(NK_LITERAL, ConstTable[Sigil].Kind, ConstTable[Sigil].FText);
        AstTable[N].Left := ConstTable[Sigil].IVal;
      End Else
        N := NewNode(NK_LITERAL, TOK_IDENT, S);
    End;
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
  End Else If T = TOK_DEREF_SCALAR Then Begin
    { $$varname : dereference scalaire }
    VName := Copy(CurTokStr, 2, Length(CurTokStr));
    N := NewNode(NK_DEREF, T, VName);
    AstTable[N].SymRef := FindSym(VName, SK_SCALAR);
    LexNextToken;
    If CurTokType = Ord('[') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord(']'));
      VarN := N;
      N := NewNode(NK_INDEX, Ord('['), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End Else If CurTokType = Ord('{') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
      VarN := N;
      N := NewNode(NK_INDEX, Ord('{'), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End;
  End Else If T = TOK_DEREF_ARRAY Then Begin
    { @$varname : dereference tableau }
    VName := Copy(CurTokStr, 2, Length(CurTokStr));
    N := NewNode(NK_DEREF, T, VName);
    AstTable[N].SymRef := FindSym(VName, SK_SCALAR);
    LexNextToken;
    If CurTokType = Ord('[') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord(']'));
      VarN := N;
      N := NewNode(NK_INDEX, Ord('['), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End;
  End Else If T = TOK_DEREF_HASH Then Begin
    { %$varname : dereference hash }
    VName := Copy(CurTokStr, 2, Length(CurTokStr));
    N := NewNode(NK_DEREF, T, VName);
    AstTable[N].SymRef := FindSym(VName, SK_SCALAR);
    LexNextToken;
    If CurTokType = Ord('{') Then Begin
      LexNextToken; IdxN := ParseExpr; Expect(Ord('}'));
      VarN := N;
      N := NewNode(NK_INDEX, Ord('{'), '');
      AstTable[N].Left := VarN; AstTable[N].Right := IdxN;
    End;
  End Else If T = TOK_FTEST Then Begin
    { Test fichier : -e EXPR, -f EXPR, -d EXPR, etc. }
    S := CurTokStr; LexNextToken;
    N := NewNode(NK_UNARY, TOK_FTEST, S);
    AstTable[N].Left := ParsePrimary;
  End Else If T = TOK_DIAMOND Then Begin
    { <> : lecture magique ARGV/stdin }
    LexNextToken;
    N := NewNode(NK_CALL, KW_READLINE, '<>');
  End Else If T = TOK_ANGLE_RD Then Begin
    { <HANDLE> ou <$fh> : readline sur filehandle }
    S := CurTokStr; LexNextToken;
    N := NewNode(NK_CALL, KW_READLINE, S);
    If (Length(S) > 0) And (S[1] = '$') Then Begin
      VName := Copy(S, 2, Length(S));
      VarN  := NewNode(NK_VAR, TOK_SIGIL_SCALAR, VName);
      AstTable[VarN].SymRef := FindSym(VName, SK_SCALAR);
      AppendArg(N, VarN);
    End;
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
    AstTable[N].Left  := ParseBlock;
    AstTable[N].Third := CurrentSubLocalSize;  { taille frame locale }
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
      SubName := CurTokStr; AstTable[N].Text := SubName; LexNextToken;
      If SubName = 'strict' Then Begin
        { use strict [SUBPRAGMA] }
        If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then Begin
          If CurTokStr = 'vars'  Then StrictVars := True
          Else If CurTokStr = 'refs'  Then StrictRefs := True
          Else If CurTokStr = 'subs'  Then StrictSubs := True;
        End Else Begin
          StrictVars := True; StrictRefs := True; StrictSubs := True;
        End;
      End Else If SubName = 'warnings' Then Begin
        { use warnings [CATEGORIE | FATAL => 'all'] }
        If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then Begin
          If      CurTokStr = 'numeric'     Then WarnFlags := WarnFlags Or WARN_NUMERIC
          Else If CurTokStr = 'uninitialized' Then WarnFlags := WarnFlags Or WARN_UNINIT
          Else If CurTokStr = 'redefine'    Then WarnFlags := WarnFlags Or WARN_REDEFINE
          Else If CurTokStr = 'deprecated'  Then WarnFlags := WarnFlags Or WARN_DEPRECATED
          Else If CurTokStr = 'once'        Then WarnFlags := WarnFlags Or WARN_ONCE
          Else If CurTokStr = 'shadow'      Then WarnFlags := WarnFlags Or WARN_SHADOW
          Else If CurTokStr = 'all'         Then WarnFlags := WarnFlags Or WARN_ALL;
        End Else If (CurTokType = TOK_IDENT) And (CurTokStr = 'FATAL') Then Begin
          LexNextToken;
          If (CurTokType = TOK_FATCOMMA) Or (CurTokType = Ord('=')) Then LexNextToken;
          WarnFatal := True; WarnFlags := WarnFlags Or WARN_ALL;
        End Else Begin
          WarnFlags := WarnFlags Or WARN_ALL;
        End;
      End Else If SubName = 'constant' Then Begin
        { use constant NAME => VALUE ou forme hash }
        If CurTokType = Ord('{') Then Begin
          { forme hash multi-constantes }
          LexNextToken;
          While (CurTokType <> Ord('}')) And (CurTokType <> TOK_EOF) Do Begin
            If CurTokType = TOK_IDENT Then Begin
              SubName := CurTokStr; LexNextToken;
              If (CurTokType = TOK_FATCOMMA) Or (CurTokType = Ord('=')) Then
                LexNextToken;
              If CurTokType = TOK_INTEGER Then
                RegisterConst(SubName, TOK_INTEGER, CurTokNum, CurTokStr)
              Else If CurTokType = TOK_FLOAT Then
                RegisterConst(SubName, TOK_FLOAT, 0, CurTokStr)
              Else If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then
                RegisterConst(SubName, TOK_STRING, 0, CurTokStr);
            End;
            While (CurTokType <> Ord(',')) And (CurTokType <> Ord('}'))
                  And (CurTokType <> TOK_EOF) Do LexNextToken;
            If CurTokType = Ord(',') Then LexNextToken;
          End;
          If CurTokType = Ord('}') Then LexNextToken;
        End Else If CurTokType = TOK_IDENT Then Begin
          { forme simple : use constant NAME => VALUE }
          SubName := CurTokStr; LexNextToken;
          If (CurTokType = TOK_FATCOMMA) Or (CurTokType = Ord('=')) Then
            LexNextToken;
          If CurTokType = TOK_INTEGER Then
            RegisterConst(SubName, TOK_INTEGER, CurTokNum, CurTokStr)
          Else If CurTokType = TOK_FLOAT Then
            RegisterConst(SubName, TOK_FLOAT, 0, CurTokStr)
          Else If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then
            RegisterConst(SubName, TOK_STRING, 0, CurTokStr);
        End;
      End Else If SubName = 'integer' Then Begin
        UseIntPragma := True;
      End Else If (SubName = 'parent') Or (SubName = 'base') Then Begin
        { use parent 'Base' ; use base 'Base' : heritage (enregistrement seul) }
        AstTable[N].Left := 1;  { flag : module heritage }
      End;
    End;
    While (CurTokType <> Ord(';')) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
    If CurTokType = Ord(';') Then LexNextToken;
    ParseStatement := N;
    Exit;
  End;

  { no MODULE : desactive un pragma }
  If CurTokType = KW_NO Then Begin
    LexNextToken;
    N := NewNode(NK_USE, KW_NO, '');
    If CurTokType = TOK_IDENT Then Begin
      SubName := CurTokStr; AstTable[N].Text := SubName; LexNextToken;
      If SubName = 'strict' Then Begin
        If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then Begin
          If CurTokStr = 'vars'  Then StrictVars := False
          Else If CurTokStr = 'refs'  Then StrictRefs := False
          Else If CurTokStr = 'subs'  Then StrictSubs := False;
        End Else Begin
          StrictVars := False; StrictRefs := False; StrictSubs := False;
        End;
      End Else If SubName = 'warnings' Then Begin
        If (CurTokType = TOK_STRING) Or (CurTokType = TOK_DSTRING) Then Begin
          If      CurTokStr = 'numeric'     Then WarnFlags := WarnFlags And Not WARN_NUMERIC
          Else If CurTokStr = 'uninitialized' Then WarnFlags := WarnFlags And Not WARN_UNINIT
          Else If CurTokStr = 'redefine'    Then WarnFlags := WarnFlags And Not WARN_REDEFINE
          Else If CurTokStr = 'deprecated'  Then WarnFlags := WarnFlags And Not WARN_DEPRECATED
          Else If CurTokStr = 'once'        Then WarnFlags := WarnFlags And Not WARN_ONCE
          Else If CurTokStr = 'shadow'      Then WarnFlags := WarnFlags And Not WARN_SHADOW
          Else If CurTokStr = 'all'         Then WarnFlags := 0;
        End Else Begin
          WarnFlags := 0; WarnFatal := False;
        End;
      End Else If SubName = 'integer' Then Begin
        UseIntPragma := False;
      End;
    End;
    While (CurTokType <> Ord(';')) And (CurTokType <> TOK_EOF) Do LexNextToken;
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
{ TODO 13 : Expressions regulieres m//, =~, !~, qr//           }
{ ============================================================ }

{ REGEX_FLAG_* et TRANS_FLAG_* sont declares avant ParsePrimary }

{ PLRECount est declare dans la section globale Var principale }

{ Genere un label unique _PLRE_N pour les donnees de regex compilees }
Function MakePLRELabel: String;
Var S: String;
Begin
  Inc(PLRECount);
  Str(PLRECount, S);
  MakePLRELabel := '_PLRE_' + S;
End;

{ Trouve la position du N-ieme slash dans S }
Function NthSlash(S: String; N: Integer): Integer;
Var I, Count: Integer;
Begin
  Count := 0;
  For I := 1 To Length(S) Do Begin
    If S[I] = '/' Then Begin
      Inc(Count);
      If Count = N Then Begin NthSlash := I; Exit; End;
    End;
  End;
  NthSlash := 0;
End;

{ Pour "pat/flags" (TOK_REGEX) -> retourne pat }
Function ExtractRegexPat(S: String): String;
Var P: Integer;
Begin
  P := NthSlash(S, 1);
  If P = 0 Then ExtractRegexPat := S
  Else ExtractRegexPat := Copy(S, 1, P-1);
End;

{ Pour "pat/flags" (TOK_REGEX) -> retourne flags }
Function ExtractRegexFlags(S: String): String;
Var P: Integer;
Begin
  P := NthSlash(S, 1);
  If P = 0 Then ExtractRegexFlags := ''
  Else ExtractRegexFlags := Copy(S, P+1, Length(S));
End;

{ Pour "pat/rpl/flags" (TOK_SUBST/TOK_TRANS) -> retourne rpl ou dst }
Function ExtractSubstRpl(S: String): String;
Var P1, P2: Integer;
Begin
  P1 := NthSlash(S, 1);
  P2 := NthSlash(S, 2);
  If (P1 = 0) Or (P2 = 0) Then ExtractSubstRpl := ''
  Else ExtractSubstRpl := Copy(S, P1+1, P2-P1-1);
End;

{ Pour "pat/rpl/flags" -> retourne flags apres le 2eme slash }
Function ExtractSubstFlags(S: String): String;
Var P: Integer;
Begin
  P := NthSlash(S, 2);
  If P = 0 Then ExtractSubstFlags := ''
  Else ExtractSubstFlags := Copy(S, P+1, Length(S));
End;

{ Convertit la chaine de flags regex en bitmask REGEX_FLAG_* }
Function ParseRegexFlags(F: String): Integer;
Var Bits, I: Integer;
Begin
  Bits := 0;
  For I := 1 To Length(F) Do
    Case F[I] Of
      'i': Bits := Bits Or REGEX_FLAG_I;
      'g': Bits := Bits Or REGEX_FLAG_G;
      'm': Bits := Bits Or REGEX_FLAG_M;
      's': Bits := Bits Or REGEX_FLAG_S;
      'x': Bits := Bits Or REGEX_FLAG_X;
      'e': Bits := Bits Or REGEX_FLAG_E;
      'r': Bits := Bits Or REGEX_FLAG_R;
    End;
  ParseRegexFlags := Bits;
End;

{ Convertit la chaine de flags tr/// en bitmask TRANS_FLAG_* }
Function ParseTransFlags(F: String): Integer;
Var Bits, I: Integer;
Begin
  Bits := 0;
  For I := 1 To Length(F) Do
    Case F[I] Of
      'c': Bits := Bits Or TRANS_FLAG_C;
      'd': Bits := Bits Or TRANS_FLAG_D;
      's': Bits := Bits Or TRANS_FLAG_S;
    End;
  ParseTransFlags := Bits;
End;

{ Noms des fonctions runtime pour les expressions regulieres }
Function PlRtRegexMatch:   String; Begin PlRtRegexMatch   := '_PLRT_regex_match';   End;
Function PlRtRegexCompile: String; Begin PlRtRegexCompile := '_PLRT_regex_compile'; End;
Function PlRtRegexCapture: String; Begin PlRtRegexCapture := '_PLRT_regex_capture'; End;
Function PlRtSubstOnce:    String; Begin PlRtSubstOnce    := '_PLRT_subst_once';    End;
Function PlRtSubstGlobal:  String; Begin PlRtSubstGlobal  := '_PLRT_subst_global';  End;
Function PlRtTrans:        String; Begin PlRtTrans        := '_PLRT_tr';            End;

{ ============================================================ }
{ TODO 12 : Chaines : interpolation, heredoc, operateurs       }
{ ============================================================ }

Const
  RT_STR_REFCOUNT_OFS = 0;    { Int32 : compteur de references }
  RT_STR_FLAGS_OFS    = 4;    { Int32 : drapeaux d encodage    }
  RT_STR_LEN_OFS      = 8;    { Int32 : longueur en octets     }
  RT_STR_CAP_OFS      = 12;   { Int32 : capacite allouee       }
  RT_STR_BUF_OFS      = 16;   { Ptr32 : pointeur vers donnees  }
  RT_STR_HEADER_SIZE  = 20;
  RT_STR_FLAG_LATIN1  = 0;
  RT_STR_FLAG_UTF8    = 1;
  RT_STR_FLAG_STATIC  = 2;    { chaine en .rdata, non heap     }

{ PLKCount est declare dans la section globale Var principale }

{ Genere un label unique _PLK_N pour un litteral de chaine }
Function MakePLKLabel: String;
Var S: String;
Begin
  Inc(PLKCount);
  Str(PLKCount, S);
  MakePLKLabel := '_PLK_' + S;
End;

{ Noms des fonctions runtime pour les chaines }
Function PlRtStrConcat:  String; Begin PlRtStrConcat  := '_PLRT_strconcat';   End;
Function PlRtStrRepeat:  String; Begin PlRtStrRepeat  := '_PLRT_strrepeat';   End;
Function PlRtStrLen:     String; Begin PlRtStrLen     := '_PLRT_strlen';      End;
Function PlRtStrEq:      String; Begin PlRtStrEq      := '_PLRT_streq';       End;
Function PlRtStrCmp:     String; Begin PlRtStrCmp     := '_PLRT_strcmp';      End;
Function PlRtStrToInt:   String; Begin PlRtStrToInt   := '_PLRT_to_s_int';    End;
Function PlRtStrToFloat: String; Begin PlRtStrToFloat := '_PLRT_to_s_float';  End;
Function PlRtStrUC:      String; Begin PlRtStrUC      := '_PLRT_str_uc';      End;
Function PlRtStrLC:      String; Begin PlRtStrLC      := '_PLRT_str_lc';      End;
Function PlRtStrUCFirst: String; Begin PlRtStrUCFirst := '_PLRT_str_ucfirst'; End;
Function PlRtStrLCFirst: String; Begin PlRtStrLCFirst := '_PLRT_str_lcfirst'; End;
Function PlRtStrChomp:   String; Begin PlRtStrChomp   := '_PLRT_str_chomp';   End;
Function PlRtStrChop:    String; Begin PlRtStrChop    := '_PLRT_str_chop';    End;
Function PlRtStrSubstr:  String; Begin PlRtStrSubstr  := '_PLRT_str_substr';  End;
Function PlRtStrIndex:   String; Begin PlRtStrIndex   := '_PLRT_str_index';   End;
Function PlRtStrRindex:  String; Begin PlRtStrRindex  := '_PLRT_str_rindex';  End;
Function PlRtStrSprintf: String; Begin PlRtStrSprintf := '_PLRT_sprintf';      End;
Function PlRtStrChr:     String; Begin PlRtStrChr     := '_PLRT_str_chr';     End;
Function PlRtStrOrd:     String; Begin PlRtStrOrd     := '_PLRT_str_ord';     End;
Function PlRtStrHex:     String; Begin PlRtStrHex     := '_PLRT_str_hex';     End;
Function PlRtStrOct:     String; Begin PlRtStrOct     := '_PLRT_str_oct';     End;
Function PlRtStrPos:     String; Begin PlRtStrPos     := '_PLRT_str_pos';     End;
Function PlRtStrReverse: String; Begin PlRtStrReverse := '_PLRT_str_reverse'; End;
Function PlRtStrJoin:    String; Begin PlRtStrJoin    := '_PLRT_str_join';    End;

{ Analyse une chaine avec hints ($S, @A) issus du lexeur et        }
{ construit NK_LITERAL si pas d interpolation, ou NK_INTERP avec   }
{ des enfants : NK_LITERAL pour les segments, NK_VAR / NK_CALL     }
{ pour les variables interpolees                                    }
Function ParseInterpolatedStr(Src: String; TokT: Integer): Integer;
Var
  N, Child, VarN, ListN: Integer;
  Buf, VName: String;
  I: Integer;
  HasInterp: Boolean;
  C: Char;
Begin
  HasInterp := False;
  I := 1;
  While I < Length(Src) Do Begin
    If ((Src[I] = '$') And (Src[I+1] = 'S')) Or
       ((Src[I] = '@') And (Src[I+1] = 'A')) Then Begin
      HasInterp := True; Break;
    End;
    Inc(I);
  End;
  If Not HasInterp Then Begin
    ParseInterpolatedStr := NewNode(NK_LITERAL, TokT, Src);
    Exit;
  End;
  N   := NewNode(NK_INTERP, TokT, '');
  Buf := '';
  I   := 1;
  While I <= Length(Src) Do Begin
    C := Src[I];
    If (C = '$') And (I < Length(Src)) And (Src[I+1] = 'S') Then Begin
      If Buf <> '' Then Begin
        AppendArg(N, NewNode(NK_LITERAL, TOK_STRING, Buf));
        Buf := '';
      End;
      Inc(I, 2);
      VName := '';
      If (I <= Length(Src)) And (Src[I] = '{') Then Begin
        Inc(I);
        While (I <= Length(Src)) And (Src[I] <> '}') Do Begin
          VName := VName + Src[I]; Inc(I);
        End;
        If I <= Length(Src) Then Inc(I);
      End Else Begin
        While (I <= Length(Src)) And IsIdentChar(Src[I]) Do Begin
          VName := VName + Src[I]; Inc(I);
        End;
      End;
      VarN := NewNode(NK_VAR, TOK_SIGIL_SCALAR, VName);
      AstTable[VarN].SymRef := FindSym(VName, SK_SCALAR);
      AppendArg(N, VarN);
    End Else If (C = '@') And (I < Length(Src)) And (Src[I+1] = 'A') Then Begin
      If Buf <> '' Then Begin
        AppendArg(N, NewNode(NK_LITERAL, TOK_STRING, Buf));
        Buf := '';
      End;
      Inc(I, 2);
      VName := '';
      While (I <= Length(Src)) And IsIdentChar(Src[I]) Do Begin
        VName := VName + Src[I]; Inc(I);
      End;
      { "@arr" dans chaine -> represente comme join(@arr) }
      { le separateur $" sera insere au codegen            }
      VarN  := NewNode(NK_CALL, KW_JOIN, 'join');
      ListN := NewNode(NK_VAR, TOK_SIGIL_ARRAY, VName);
      AstTable[ListN].SymRef    := FindSym(VName, SK_ARRAY);
      AstTable[VarN].FirstChild := ListN;
      AppendArg(N, VarN);
    End Else Begin
      If Length(Buf) < 255 Then Buf := Buf + C;
      Inc(I);
    End;
  End;
  If Buf <> '' Then
    AppendArg(N, NewNode(NK_LITERAL, TOK_STRING, Buf));
  ParseInterpolatedStr := N;
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

{ ============================================================ }
{ TODO 25 : Backend binaire .OBJ COFF + .EXE PE Win32          }
{ ============================================================ }

{ Registres 80386 }
Const
  REG_EAX = 0; REG_ECX = 1; REG_EDX = 2; REG_EBX = 3;
  REG_ESP = 4; REG_EBP = 5; REG_ESI = 6; REG_EDI = 7;

{ Codes condition JCC }
  CC_O  = 0;  CC_NO = 1;  CC_B  = 2;  CC_AE = 3;
  CC_E  = 4;  CC_NE = 5;  CC_BE = 6;  CC_A  = 7;
  CC_S  = 8;  CC_NS = 9;  CC_P  = 10; CC_NP = 11;
  CC_L  = 12; CC_GE = 13; CC_LE = 14; CC_G  = 15;

Var
  BinCurSec: Integer;   { section courante : BIN_SEC_TEXT/DATA/RDATA }

Procedure BinInit;
Begin
  BinCodeSize  := 0; BinDataSize  := 0;
  BinRDataSize := 0; BinBssSize   := 0;
  BinLabelCount := 0; BinFixupCount := 0; BinImportCount := 0;
  BinCurSec := BIN_SEC_TEXT;
End;

Procedure BinEmit8(B: Byte);
Begin
  Case BinCurSec Of
    1: Begin BinCode [BinCodeSize]  := B; Inc(BinCodeSize);  End;
    2: Begin BinData [BinDataSize]  := B; Inc(BinDataSize);  End;
    3: Begin BinRData[BinRDataSize] := B; Inc(BinRDataSize); End;
  End;
End;

Procedure BinEmit16(W: Integer);
Begin
  BinEmit8(W And $FF); BinEmit8((W Shr 8) And $FF);
End;

Procedure BinEmit32(D: LongInt);
Begin
  BinEmit8(D And $FF);      BinEmit8((D Shr 8)  And $FF);
  BinEmit8((D Shr 16) And $FF); BinEmit8((D Shr 24) And $FF);
End;

Function BinCurOffset: LongInt;
Begin
  Case BinCurSec Of
    1: BinCurOffset := BinCodeSize;
    2: BinCurOffset := BinDataSize;
    3: BinCurOffset := BinRDataSize;
  Else BinCurOffset := 0;
  End;
End;

Function BinDefineLabel(LName: String): Integer;
Var I: Integer;
Begin
  For I := 1 To BinLabelCount Do
    If BinLabels[I].Name = LName Then Begin
      BinLabels[I].Section := BinCurSec;
      BinLabels[I].Offset  := BinCurOffset;
      BinLabels[I].Defined := True;
      BinDefineLabel := I; Exit;
    End;
  If BinLabelCount < MAX_BIN_LABEL Then Begin
    Inc(BinLabelCount);
    BinLabels[BinLabelCount].Name    := LName;
    BinLabels[BinLabelCount].Section := BinCurSec;
    BinLabels[BinLabelCount].Offset  := BinCurOffset;
    BinLabels[BinLabelCount].Defined := True;
    BinDefineLabel := BinLabelCount;
  End Else BinDefineLabel := 0;
End;

Function BinLookupLabel(LName: String): Integer;
Var I: Integer;
Begin
  For I := 1 To BinLabelCount Do
    If BinLabels[I].Name = LName Then Begin BinLookupLabel := I; Exit; End;
  If BinLabelCount < MAX_BIN_LABEL Then Begin
    Inc(BinLabelCount);
    BinLabels[BinLabelCount].Name    := LName;
    BinLabels[BinLabelCount].Section := BinCurSec;
    BinLabels[BinLabelCount].Offset  := 0;
    BinLabels[BinLabelCount].Defined := False;
    BinLookupLabel := BinLabelCount;
  End Else BinLookupLabel := 0;
End;

Procedure BinAddFixup(LIdx: Integer; Kind: Integer);
Begin
  If BinFixupCount >= MAX_BIN_FIXUP Then Exit;
  Inc(BinFixupCount);
  BinFixups[BinFixupCount].Section  := BinCurSec;
  BinFixups[BinFixupCount].Offset   := BinCurOffset;
  BinFixups[BinFixupCount].LabelRef := LIdx;
  BinFixups[BinFixupCount].Kind     := Kind;
End;

Procedure BinEmitRef32(LName: String; Kind: Integer);
Var LIdx: Integer;
Begin
  LIdx := BinLookupLabel(LName);
  BinAddFixup(LIdx, Kind);
  BinEmit32(0);
End;

Function BinAddImport(DName, PName: String): Integer;
Var I: Integer;
Begin
  For I := 1 To BinImportCount Do
    If (BinImports[I].DllName = DName) And (BinImports[I].ProcName = PName) Then Begin
      BinAddImport := I; Exit;
    End;
  If BinImportCount < MAX_BIN_IMPORT Then Begin
    Inc(BinImportCount);
    BinImports[BinImportCount].DllName  := DName;
    BinImports[BinImportCount].ProcName := PName;
    BinImports[BinImportCount].Hint     := 0;
    BinImports[BinImportCount].IATRva   := 0;
    BinAddImport := BinImportCount;
  End Else BinAddImport := 0;
End;

{ Encodeur 80386 : emit PUSH reg32 }
Procedure BinPushReg(R: Integer);
Begin BinEmit8($50 + R); End;

{ Encodeur 80386 : emit POP reg32 }
Procedure BinPopReg(R: Integer);
Begin BinEmit8($58 + R); End;

{ Encodeur 80386 : emit PUSH imm32 }
Procedure BinPushImm32(V: LongInt);
Begin BinEmit8($68); BinEmit32(V); End;

{ Encodeur 80386 : emit MOV reg, imm32 }
Procedure BinMovRegImm32(Rd: Integer; V: LongInt);
Begin BinEmit8($B8 + Rd); BinEmit32(V); End;

{ Encodeur 80386 : emit MOV reg32, reg32  (2 octets : 89 /r) }
Procedure BinMovRegReg(Rd, Rs: Integer);
Begin BinEmit8($8B); BinEmit8($C0 Or (Rd Shl 3) Or Rs); End;

{ Encodeur 80386 : emit XOR reg, reg }
Procedure BinXorRegReg(R: Integer);
Begin BinEmit8($33); BinEmit8($C0 Or (R Shl 3) Or R); End;

{ Encodeur 80386 : emit PUSH [disp32] }
Procedure BinPushMem32(Disp: LongInt);
Begin BinEmit8($FF); BinEmit8($35); BinEmit32(Disp); End;

{ Encodeur 80386 : emit MOV EAX, [disp32]  (A1 disp32) }
Procedure BinMovEaxMem32(Disp: LongInt);
Begin BinEmit8($A1); BinEmit32(Disp); End;

{ Encodeur 80386 : emit MOV [disp32], EAX  (A3 disp32) }
Procedure BinMovMem32Eax(Disp: LongInt);
Begin BinEmit8($A3); BinEmit32(Disp); End;

{ Encodeur 80386 : emit MOV EAX, [EBP-N] }
Procedure BinMovEaxEbpN(N: Integer);
Begin
  BinEmit8($8B); BinEmit8($45); BinEmit8((- N) And $FF);
End;

{ Encodeur 80386 : emit MOV [EBP-N], EAX }
Procedure BinMovEbpNEax(N: Integer);
Begin
  BinEmit8($89); BinEmit8($45); BinEmit8((- N) And $FF);
End;

{ Encodeur 80386 : emit SUB ESP, imm8 }
Procedure BinSubEspImm8(N: Integer);
Begin BinEmit8($83); BinEmit8($EC); BinEmit8(N And $FF); End;

{ Encodeur 80386 : emit ADD ESP, imm8 }
Procedure BinAddEspImm8(N: Integer);
Begin BinEmit8($83); BinEmit8($C4); BinEmit8(N And $FF); End;

{ Encodeur 80386 : emit ADD ESP, imm32 }
Procedure BinAddEspImm32(N: LongInt);
Begin BinEmit8($81); BinEmit8($C4); BinEmit32(N); End;

{ Encodeur 80386 : emit PUSH EBP + MOV EBP, ESP }
Procedure BinEmitPrologue(FrameSz: Integer);
Begin
  BinPushReg(REG_EBP);
  BinEmit8($8B); BinEmit8($EC);      { MOV EBP, ESP }
  If FrameSz > 0 Then Begin
    If FrameSz <= 127 Then BinSubEspImm8(FrameSz)
    Else Begin BinEmit8($81); BinEmit8($EC); BinEmit32(FrameSz); End;
  End;
End;

{ Encodeur 80386 : emit epilogue : XOR EAX, EAX / MOV ESP, EBP / POP EBP / RET }
Procedure BinEmitEpilogue;
Begin
  BinXorRegReg(REG_EAX);
  BinEmit8($8B); BinEmit8($E5);   { MOV ESP, EBP }
  BinPopReg(REG_EBP);
  BinEmit8($C3);                  { RET }
End;

{ Encodeur 80386 : emit CALL rel32 avec fixup }
Procedure BinCallLabel(LName: String);
Var LIdx: Integer;
Begin
  BinEmit8($E8);
  LIdx := BinLookupLabel(LName);
  BinAddFixup(LIdx, BIN_FIX_REL32);
  BinEmit32(0);
End;

{ Encodeur 80386 : emit JMP rel32 avec fixup }
Procedure BinJmpLabel(LName: String);
Var LIdx: Integer;
Begin
  BinEmit8($E9);
  LIdx := BinLookupLabel(LName);
  BinAddFixup(LIdx, BIN_FIX_REL32);
  BinEmit32(0);
End;

{ Encodeur 80386 : emit JCC rel32 avec fixup (0F 8x ...) }
Procedure BinJccLabel(CC: Integer; LName: String);
Var LIdx: Integer;
Begin
  BinEmit8($0F); BinEmit8($80 Or CC);
  LIdx := BinLookupLabel(LName);
  BinAddFixup(LIdx, BIN_FIX_REL32);
  BinEmit32(0);
End;

{ Encodeur 80386 : emit CMP EAX, 0 (83 F8 00) }
Procedure BinCmpEaxZero;
Begin BinEmit8($83); BinEmit8($F8); BinEmit8(0); End;

{ Encodeur 80386 : emit ADD/SUB EAX, ECX (03 C1 / 2B C1) }
Procedure BinAddEaxEcx; Begin BinEmit8($03); BinEmit8($C1); End;
Procedure BinSubEaxEcx; Begin BinEmit8($2B); BinEmit8($C1); End;
Procedure BinImulEaxEcx; Begin BinEmit8($0F); BinEmit8($AF); BinEmit8($C1); End;

{ Encodeur 80386 : emit IDIV ECX (F7 F9) }
Procedure BinIdivEcx;
Begin
  BinEmit8($99);    { CDQ }
  BinEmit8($F7); BinEmit8($F9);
End;

{ Encodeur 80386 : emit PUSH EAX / CALL [IAT entry] / ADD ESP, N }
Procedure BinCallImport(ProcName: String; ArgBytes: Integer);
Var LName: String;
Begin
  LName := '__imp__' + ProcName;
  BinEmit8($FF); BinEmit8($15);
  BinEmitRef32(LName, BIN_FIX_IMP32);
  If ArgBytes > 0 Then BinAddEspImm8(ArgBytes);
End;

{ Resolution des fixups intra-section (rel32 uniquement) }
Procedure BinResolveFixups;
Var I: Integer; LIdx: Integer; Loc, Target, Rel: LongInt;
    Buf: ^TBinBuffer;
Begin
  For I := 1 To BinFixupCount Do Begin
    If BinFixups[I].Kind <> BIN_FIX_REL32 Then Continue;
    LIdx := BinFixups[I].LabelRef;
    If (LIdx = 0) Or (Not BinLabels[LIdx].Defined) Then Continue;
    If BinFixups[I].Section <> BinLabels[LIdx].Section Then Continue;
    Loc    := BinFixups[I].Offset;
    Target := BinLabels[LIdx].Offset;
    Rel    := Target - (Loc + 4);
    Case BinFixups[I].Section Of
      1: Buf := @BinCode;
      2: Buf := @BinData;
      3: Buf := @BinRData;
    Else Continue;
    End;
    Buf^[Loc]     := Rel And $FF;
    Buf^[Loc + 1] := (Rel Shr 8)  And $FF;
    Buf^[Loc + 2] := (Rel Shr 16) And $FF;
    Buf^[Loc + 3] := (Rel Shr 24) And $FF;
  End;
End;

{ Aligne N sur Align (puissance de 2) }
Function AlignUp(N, Align: LongInt): LongInt;
Begin
  If (N Mod Align) = 0 Then AlignUp := N
  Else AlignUp := N + Align - (N Mod Align);
End;

{ Ecrit N octets zero dans F }
Procedure WritePad(Var F: File; N: LongInt);
Var Z: Byte; I: LongInt;
Begin
  Z := 0;
  For I := 1 To N Do BlockWrite(F, Z, 1);
End;

{ Ecrit un WORD (2 octets LE) dans F }
Procedure WriteWord(Var F: File; W: Integer);
Var B: Byte;
Begin
  B := W And $FF; BlockWrite(F, B, 1);
  B := (W Shr 8) And $FF; BlockWrite(F, B, 1);
End;

{ Ecrit un DWORD (4 octets LE) dans F }
Procedure WriteDWord(Var F: File; D: LongInt);
Var B: Byte;
Begin
  B := D And $FF; BlockWrite(F, B, 1);
  B := (D Shr 8)  And $FF; BlockWrite(F, B, 1);
  B := (D Shr 16) And $FF; BlockWrite(F, B, 1);
  B := (D Shr 24) And $FF; BlockWrite(F, B, 1);
End;

{ Ecrit une chaine de longueur fixe N (complete de zeros) }
Procedure WriteStr8(Var F: File; S: String; Len: Integer);
Var I: Integer; Z: Byte;
Begin
  Z := 0;
  For I := 1 To Len Do Begin
    If I <= Length(S) Then BlockWrite(F, S[I], 1) Else BlockWrite(F, Z, 1);
  End;
End;

{ ============================================================ }
{ Runtime binaire minimal embarque dans .text                  }
{ ============================================================ }

Procedure BinEmitRuntimeStub(PName: String; ImpName: String; ArgN: Integer);
Begin
  BinDefineLabel(PName);
  BinPushReg(REG_EBP); BinEmit8($8B); BinEmit8($EC);
  BinCallImport(ImpName, 0);
  BinPopReg(REG_EBP); BinEmit8($C3);
End;

Procedure BinEmitRuntime;
Var I: Integer;
Begin
  { _PLRT_exit : push arg / call ExitProcess }
  BinDefineLabel('_PLRT_exit');
  BinEmit8($FF); BinEmit8($74); BinEmit8($24); BinEmit8($04);
  BinCallImport('_ExitProcess@4', 4);
  BinEmit8($C3);

  { _PLRT_get_handle : push arg / call GetStdHandle / ret }
  BinDefineLabel('_PLRT_get_handle');
  BinEmit8($FF); BinEmit8($74); BinEmit8($24); BinEmit8($04);
  BinCallImport('_GetStdHandle@4', 4);
  BinEmit8($C3);

  { _PLRT_int_to_str stub : retourne ptr chaine statique "0" }
  BinDefineLabel('_PLRT_int_to_str');
  BinXorRegReg(REG_EAX);
  BinEmit8($C3);

  { _PLRT_print stub : retourne 0 }
  BinDefineLabel('_PLRT_print');
  BinXorRegReg(REG_EAX);
  BinEmit8($C3);

  { Stubs pour toutes autres fonctions runtime }
  For I := 1 To 0 Do ; { placeholder }
End;

{ ============================================================ }
{ Codegen binaire (AST -> BinCode/BinData/BinRData)            }
{ ============================================================ }

Procedure BinCodegenNode(Node: Integer); Forward;

Procedure BinCodegenLiteral(Node: Integer);
Var V: LongInt;
Begin
  Case AstTable[Node].Tok Of
    261 { TOK_INTEGER }: BinMovRegImm32(REG_EAX, AstTable[Node].Left);
    263, 264 { TOK_STRING/DSTRING }: Begin
      { pointeur vers constante : fixup ABS32 vers _PLK_N }
      BinEmit8($B8);
      BinEmitRef32(AstTable[Node].Text, BIN_FIX_ABS32);
    End;
  Else
    BinXorRegReg(REG_EAX);
  End;
End;

Procedure BinCodegenVar(Node: Integer);
Var SIdx: Integer;
Begin
  SIdx := AstTable[Node].SymRef;
  If SIdx = 0 Then Begin BinXorRegReg(REG_EAX); Exit; End;
  If SymTable[SIdx].ScopeKd = SCOPE_LEXICAL Then
    BinMovEaxEbpN(SymTable[SIdx].Offset)
  Else Begin
    BinEmit8($A1);
    BinEmitRef32(SymTable[SIdx].AsmName, BIN_FIX_ABS32);
  End;
End;

Procedure BinCodegenAssign(Node: Integer);
Var LN, RN, SIdx: Integer;
Begin
  LN := AstTable[Node].Left; RN := AstTable[Node].Right;
  BinCodegenNode(RN);
  SIdx := 0;
  If AstTable[LN].Kind = 7 { NK_VAR } Then SIdx := AstTable[LN].SymRef;
  If SIdx = 0 Then Exit;
  If SymTable[SIdx].ScopeKd = SCOPE_LEXICAL Then
    BinMovEbpNEax(SymTable[SIdx].Offset)
  Else Begin
    BinEmit8($A3);
    BinEmitRef32(SymTable[SIdx].AsmName, BIN_FIX_ABS32);
  End;
End;

Procedure BinCodegenBlock(Node: Integer);
Var Ch: Integer;
Begin
  Ch := AstTable[Node].FirstChild;
  While Ch <> 0 Do Begin
    BinCodegenNode(Ch);
    Ch := AstTable[Ch].NextSibling;
  End;
End;

Procedure BinCodegenNode(Node: Integer);
Begin
  If Node = 0 Then Exit;
  Case AstTable[Node].Kind Of
    0 { NK_BLOCK }:   BinCodegenBlock(Node);
    2 { NK_LITERAL }: BinCodegenLiteral(Node);
    5 { NK_ASSIGN }:  BinCodegenAssign(Node);
    7 { NK_VAR }:     BinCodegenVar(Node);
  Else
    BinXorRegReg(REG_EAX);
  End;
End;

Procedure BinCodegenProgram(Root: Integer; FrameSz: Integer);
Begin
  BinCurSec := BIN_SEC_TEXT;
  BinDefineLabel('_PLSTART');
  BinEmitPrologue(FrameSz);
  BinCodegenNode(Root);
  BinXorRegReg(REG_EAX);
  BinPushReg(REG_EAX);
  BinCallImport('_ExitProcess@4', 4);
  BinEmitRuntime;
  BinResolveFixups;
  { Donnees initialisees }
  BinCurSec := BIN_SEC_DATA;
  { Fin de la generation binaire }
End;

{ ============================================================ }
{ WriteCOFF : ecrit un fichier .OBJ COFF Win32                 }
{ ============================================================ }

Procedure WriteCOFF(FileName: String);
Var F: File;
    TextRVA, DataRVA, RDataRVA: LongInt;
    SymOff, StrTabOff: LongInt;
    TextOff, DataOff, RDataOff: LongInt;
    NSec, NSym: Integer;
    I: Integer;
    LI: LongInt;
    TextSz, DataSz, RDataSz: LongInt;
    Dummy: Byte;
Begin
  Assign(F, FileName); Rewrite(F, 1);
  TextSz  := AlignUp(BinCodeSize,  4);
  DataSz  := AlignUp(BinDataSize,  4);
  RDataSz := AlignUp(BinRDataSize, 4);
  NSec := 2;
  If BinDataSize  > 0 Then Inc(NSec);
  If BinRDataSize > 0 Then Inc(NSec);
  If BinBssSize   > 0 Then Inc(NSec);
  { Header offset layout }
  TextOff  := 20 + NSec * 40;
  DataOff  := TextOff  + TextSz;
  RDataOff := DataOff  + DataSz;
  SymOff   := RDataOff + RDataSz;
  NSym     := BinLabelCount + 4;

  { IMAGE_FILE_HEADER }
  WriteWord(F,  PE_MACHINE_I386);   { Machine }
  WriteWord(F,  NSec);              { NumberOfSections }
  WriteDWord(F, 0);                 { TimeDateStamp }
  WriteDWord(F, SymOff);            { PointerToSymbolTable }
  WriteDWord(F, NSym);              { NumberOfSymbols }
  WriteWord(F,  0);                 { SizeOfOptionalHeader }
  WriteWord(F,  0);                 { Characteristics }

  { Section headers }
  WriteStr8(F, '.text',  8);
  WriteDWord(F, BinCodeSize);  WriteDWord(F, 0);
  WriteDWord(F, TextSz);       WriteDWord(F, TextOff);
  WriteDWord(F, 0);            WriteDWord(F, 0);
  WriteWord(F, 0);             WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  WriteStr8(F, '.data',  8);
  WriteDWord(F, BinDataSize);  WriteDWord(F, 0);
  WriteDWord(F, DataSz);       WriteDWord(F, DataOff);
  WriteDWord(F, 0);            WriteDWord(F, 0);
  WriteWord(F, 0);             WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  If BinRDataSize > 0 Then Begin
    WriteStr8(F, '.rdata', 8);
    WriteDWord(F, BinRDataSize); WriteDWord(F, 0);
    WriteDWord(F, RDataSz);      WriteDWord(F, RDataOff);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteWord(F, 0);             WriteWord(F, 0);
    WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ);
  End;

  If BinBssSize > 0 Then Begin
    WriteStr8(F, '.bss', 8);
    WriteDWord(F, BinBssSize);   WriteDWord(F, 0);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteDWord(F, 0);            WriteDWord(F, 0);
    WriteWord(F, 0);             WriteWord(F, 0);
    WriteDWord(F, PE_SCN_CNT_UNINIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);
  End;

  { Section data }
  For LI := 0 To BinCodeSize - 1  Do BlockWrite(F, BinCode[LI],  1);
  WritePad(F, TextSz  - BinCodeSize);
  For LI := 0 To BinDataSize - 1  Do BlockWrite(F, BinData[LI],  1);
  WritePad(F, DataSz  - BinDataSize);
  If BinRDataSize > 0 Then Begin
    For LI := 0 To BinRDataSize - 1 Do BlockWrite(F, BinRData[LI], 1);
    WritePad(F, RDataSz - BinRDataSize);
  End;

  { COFF symbol table (minimal) }
  For I := 1 To BinLabelCount Do Begin
    If Not BinLabels[I].Defined Then Continue;
    WriteStr8(F, BinLabels[I].Name, 8);
    WriteDWord(F, BinLabels[I].Offset);
    WriteWord(F, BinLabels[I].Section);
    WriteWord(F, 0);
    Dummy := COFF_SYM_CLASS_EXTERNAL; BlockWrite(F, Dummy, 1);
    Dummy := 0; BlockWrite(F, Dummy, 1);
  End;

  { String table }
  WriteDWord(F, 4);
  Close(F);
End;

{ ============================================================ }
{ WritePE : ecrit un fichier .EXE PE Win32                     }
{ ============================================================ }

Procedure WritePE(FileName: String);
Const
  MZ_STUB_SZ   = 64;
  IMP_KERN32_N = 11;
Var
  F: File;
  I: Integer;
  LI: LongInt;

  { Constantes de layout PE }
  ImageBase : LongInt;
  FileAlign : LongInt;
  SecAlign  : LongInt;

  { Offsets fichier }
  PEHdrOff  : LongInt;
  Sec1Off   : LongInt;
  Sec2Off   : LongInt;
  Sec3Off   : LongInt;
  Sec4Off   : LongInt;
  IDataOff  : LongInt;

  { Tailles alignees }
  TextSz    : LongInt;
  DataSz    : LongInt;
  RDataSz   : LongInt;
  BssSz     : LongInt;
  IDataSz   : LongInt;

  { RVA de chaque section }
  TextRVA   : LongInt;
  DataRVA   : LongInt;
  RDataRVA  : LongInt;
  BssRVA    : LongInt;
  IDataRVA  : LongInt;

  { Taille image et entetes }
  HdrsSz    : LongInt;
  ImageSz   : LongInt;
  CodeSz    : LongInt;
  InitDataSz: LongInt;

  { IAT layout }
  IATRva    : LongInt;
  IATSz     : LongInt;
  Dummy     : Byte;

  Kern32Names: Array[1..11] Of String;
  EntryRVA  : LongInt;

Begin
  Assign(F, FileName); Rewrite(F, 1);

  ImageBase := PE_IMG_BASE;
  FileAlign := PE_FILE_ALIGN;
  SecAlign  := PE_SEC_ALIGN;

  Kern32Names[1]  := 'GetStdHandle';
  Kern32Names[2]  := 'WriteFile';
  Kern32Names[3]  := 'ReadFile';
  Kern32Names[4]  := 'ExitProcess';
  Kern32Names[5]  := 'GetCommandLineA';
  Kern32Names[6]  := 'GetEnvironmentStringsA';
  Kern32Names[7]  := 'CreateFileA';
  Kern32Names[8]  := 'CloseHandle';
  Kern32Names[9]  := 'HeapAlloc';
  Kern32Names[10] := 'HeapFree';
  Kern32Names[11] := 'GetProcessHeap';

  TextSz   := AlignUp(BinCodeSize,  FileAlign);
  DataSz   := AlignUp(BinDataSize,  FileAlign);
  If DataSz  = 0 Then DataSz  := FileAlign;
  RDataSz  := AlignUp(BinRDataSize, FileAlign);
  If RDataSz = 0 Then RDataSz := FileAlign;
  BssSz    := 0;
  IDataSz  := AlignUp(IMP_KERN32_N * 4 + 8 + 20 + 16, FileAlign);
  If IDataSz < FileAlign Then IDataSz := FileAlign;

  HdrsSz   := AlignUp(MZ_STUB_SZ + 248 + 5 * 40, FileAlign);

  TextRVA  := AlignUp(HdrsSz, SecAlign);
  DataRVA  := AlignUp(TextRVA  + AlignUp(BinCodeSize,  SecAlign), SecAlign);
  If DataRVA  = TextRVA  Then DataRVA  := TextRVA  + SecAlign;
  RDataRVA := AlignUp(DataRVA  + AlignUp(BinDataSize,  SecAlign), SecAlign);
  If RDataRVA = DataRVA  Then RDataRVA := DataRVA  + SecAlign;
  BssRVA   := AlignUp(RDataRVA + AlignUp(BinRDataSize, SecAlign), SecAlign);
  If BssRVA  = RDataRVA Then BssRVA   := RDataRVA + SecAlign;
  IDataRVA := AlignUp(BssRVA   + SecAlign, SecAlign);

  { IAT RVA = debut de .idata }
  IATRva  := IDataRVA;
  IATSz   := (IMP_KERN32_N + 1) * 4;

  ImageSz   := AlignUp(IDataRVA + SecAlign, SecAlign);
  CodeSz    := AlignUp(BinCodeSize, FileAlign);
  InitDataSz:= DataSz + RDataSz + IDataSz;
  EntryRVA  := TextRVA;

  PEHdrOff  := MZ_STUB_SZ;
  Sec1Off   := HdrsSz;
  Sec2Off   := Sec1Off + TextSz;
  Sec3Off   := Sec2Off + DataSz;
  Sec4Off   := Sec3Off + RDataSz;
  IDataOff  := Sec4Off + 0;

  { MZ stub (64 octets) }
  WriteWord(F, PE_DOS_MAGIC);
  WriteWord(F, $0090);
  WriteWord(F, 3);
  WriteWord(F, 0);
  WriteWord(F, 4);
  WriteWord(F, 0);
  WriteWord(F, -1);   { MaxAlloc = $FFFF }
  WriteWord(F, 0);
  WriteWord(F, $0000);
  WriteWord(F, 0);
  WriteWord(F, 0);
  WriteWord(F, 0);
  WriteWord(F, 0);
  WriteWord(F, 0);
  WriteDWord(F, 0);                       { 28-2B reserved }
  WriteDWord(F, 0);                       { 2C-2F reserved }
  WriteDWord(F, 0);                       { 30-33 reserved }
  WriteDWord(F, 0);                       { 34-37 reserved }
  WriteDWord(F, 0);                       { 38-3B reserved }
  WriteDWord(F, PEHdrOff);               { e_lfanew }

  { PE signature }
  WriteDWord(F, PE_PE_SIG);

  { IMAGE_FILE_HEADER }
  WriteWord(F,  PE_MACHINE_I386);
  WriteWord(F,  5);                       { 5 sections }
  WriteDWord(F, 0);                       { TimeDateStamp }
  WriteDWord(F, 0);                       { PointerToSymbolTable }
  WriteDWord(F, 0);                       { NumberOfSymbols }
  WriteWord(F,  224);                     { SizeOfOptionalHeader }
  WriteWord(F,  $0102);                   { Characteristics: exec, 32bit }

  { IMAGE_OPTIONAL_HEADER32 }
  WriteWord(F,  PE_OPT_MAGIC_PE32);
  WriteWord(F,  0);                       { LinkerVersion }
  WriteDWord(F, CodeSz);
  WriteDWord(F, InitDataSz);
  WriteDWord(F, 0);                       { SizeOfUninitializedData }
  WriteDWord(F, EntryRVA);               { AddressOfEntryPoint }
  WriteDWord(F, TextRVA);               { BaseOfCode }
  WriteDWord(F, DataRVA);               { BaseOfData }
  WriteDWord(F, ImageBase);
  WriteDWord(F, SecAlign);
  WriteDWord(F, FileAlign);
  WriteWord(F,  4); WriteWord(F, 0);     { OSVersion }
  WriteWord(F,  0); WriteWord(F, 0);     { ImageVersion }
  WriteWord(F,  4); WriteWord(F, 0);     { SubsystemVersion }
  WriteDWord(F, 0);                       { Win32VersionValue }
  WriteDWord(F, ImageSz);
  WriteDWord(F, HdrsSz);
  WriteDWord(F, 0);                       { CheckSum }
  WriteWord(F,  PE_SUBSYS_CUI);
  WriteWord(F,  0);                       { DllCharacteristics }
  WriteDWord(F, $00100000);              { SizeOfStackReserve }
  WriteDWord(F, $00001000);              { SizeOfStackCommit }
  WriteDWord(F, $00100000);              { SizeOfHeapReserve }
  WriteDWord(F, $00001000);              { SizeOfHeapCommit }
  WriteDWord(F, 0);                       { LoaderFlags }
  WriteDWord(F, 16);                      { NumberOfRvaAndSizes }
  { Data directories x16 }
  For I := 1 To 14 Do WriteDWord(F, 0);
  WriteDWord(F, IATRva); WriteDWord(F, IATSz); { 12 = IAT dir }
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteDWord(F, 0); WriteDWord(F, 0);

  { Section headers }
  WriteStr8(F, '.text',  8);
  WriteDWord(F, BinCodeSize);
  WriteDWord(F, TextRVA);
  WriteDWord(F, CodeSz);
  WriteDWord(F, Sec1Off);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteWord(F, 0);  WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or PE_SCN_MEM_READ);

  WriteStr8(F, '.data',  8);
  WriteDWord(F, BinDataSize);
  WriteDWord(F, DataRVA);
  WriteDWord(F, DataSz);
  WriteDWord(F, Sec2Off);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteWord(F, 0);  WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  WriteStr8(F, '.rdata', 8);
  WriteDWord(F, BinRDataSize);
  WriteDWord(F, RDataRVA);
  WriteDWord(F, RDataSz);
  WriteDWord(F, Sec3Off);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteWord(F, 0);  WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ);

  WriteStr8(F, '.bss',   8);
  WriteDWord(F, SecAlign);
  WriteDWord(F, BssRVA);
  WriteDWord(F, 0);
  WriteDWord(F, 0);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteWord(F, 0);  WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_UNINIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  WriteStr8(F, '.idata', 8);
  WriteDWord(F, IATSz + 20 + IMP_KERN32_N * 6 + 16);
  WriteDWord(F, IDataRVA);
  WriteDWord(F, IDataSz);
  WriteDWord(F, IDataOff);
  WriteDWord(F, 0); WriteDWord(F, 0);
  WriteWord(F, 0);  WriteWord(F, 0);
  WriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or PE_SCN_MEM_WRITE);

  { Pad headers to HdrsSz }
  Dummy := 0;
  For LI := MZ_STUB_SZ + 4 + 20 + 224 + 5 * 40 To HdrsSz - 1 Do
    BlockWrite(F, Dummy, 1);

  { .text section }
  For LI := 0 To BinCodeSize - 1 Do BlockWrite(F, BinCode[LI], 1);
  WritePad(F, TextSz - BinCodeSize);

  { .data section }
  For LI := 0 To BinDataSize - 1 Do BlockWrite(F, BinData[LI], 1);
  WritePad(F, DataSz - BinDataSize);

  { .rdata section }
  For LI := 0 To BinRDataSize - 1 Do BlockWrite(F, BinRData[LI], 1);
  WritePad(F, RDataSz - BinRDataSize);

  { .idata section : IAT + IDT + hint/name stubs }
  { IAT : IMP_KERN32_N+1 entries de 4 octets }
  For I := 1 To IMP_KERN32_N Do
    WriteDWord(F, ImageBase + IDataRVA + (IMP_KERN32_N + 2) * 4 + (I - 1) * 6);
  WriteDWord(F, 0);  { fin IAT }

  { IDT : 1 entree KERNEL32 + 1 entree vide }
  WriteDWord(F, IDataRVA + (IMP_KERN32_N + 2) * 4 + IMP_KERN32_N * 6);
  WriteDWord(F, 0);   WriteDWord(F, 0);
  WriteDWord(F, IDataRVA + (IMP_KERN32_N + 2) * 4 + IMP_KERN32_N * 6 + 12);
  WriteDWord(F, IDataRVA);
  WriteWord(F, 0); WriteWord(F, 0); WriteDWord(F, 0); WriteDWord(F, 0); WriteDWord(F, 0);

  { Hint/Name stubs pour KERNEL32.DLL }
  For I := 1 To IMP_KERN32_N Do Begin
    WriteWord(F, I);
    WriteStr8(F, Kern32Names[I], Length(Kern32Names[I]) + 1);
  End;
  WriteStr8(F, 'KERNEL32.DLL', 13);

  Close(F);
End;

{ ============================================================ }
{ TODO 24 : Generateur de code 80386 et sortie .ASM            }
{ ============================================================ }

{ Convertit une chaine Pascal en declaration MASM DB avec terminateur NUL }
Function StringToAsmDB(S: String): String;
Var
  I: Integer;
  C: Char;
  Res, Ns: String;
  InQ: Boolean;
Begin
  Res := '';
  InQ := False;
  For I := 1 To Length(S) Do Begin
    C := S[I];
    If (Ord(C) >= 32) And (Ord(C) <= 126) And (C <> '"') Then Begin
      If Not InQ Then Begin
        If Length(Res) > 0 Then Res := Res + ',';
        Res := Res + '"';
        InQ := True;
      End;
      Res := Res + C;
    End Else Begin
      If InQ Then Begin Res := Res + '"'; InQ := False; End;
      If Length(Res) > 0 Then Res := Res + ',';
      Str(Ord(C), Ns);
      Res := Res + Ns;
    End;
  End;
  If InQ Then Res := Res + '"';
  If Length(Res) > 0 Then Res := Res + ',0' Else Res := '0';
  StringToAsmDB := Res;
End;

{ Emet une ligne brute sans indentation (directives, en-tetes de section) }
Procedure EmitRaw(S: String);
Begin
  If AsmOutOpen Then WriteLn(AsmOut, S)
  Else WriteLn(S);
End;

{ Vide le StringTable dans la section .DATA courante (DB declarations) }
Procedure FlushStringConsts;
Var I: Integer;
Begin
  For I := 1 To StringCount Do
    EmitRaw(StringTable[I].AsmName + '  DB  ' +
            StringToAsmDB(StringTable[I].Text));
End;

{ Emet les stubs ASM du runtime Perl inline dans le fichier de sortie }
Procedure GenRuntime;
Begin
  EmitRaw('');
  EmitRaw('; ====== Runtime PERLCW32 ======');
  EmitRaw('.DATA');
  EmitRaw('_PLRT_itoa_buf  DB  24 DUP(0)');
  EmitRaw('.CODE');

  { _PLRT_to_bool(val) -> 0 ou 1 }
  EmitRaw('_PLRT_to_bool:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'mov eax, dword ptr [ebp+8]');
  EmitRaw(#9+'test eax, eax');
  EmitRaw(#9+'setnz al');
  EmitRaw(#9+'movzx eax, al');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_to_int(val) -> val (identite entiere) }
  EmitRaw('_PLRT_to_int:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'mov eax, dword ptr [ebp+8]');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_get_handle(type) -> HANDLE Win32 }
  EmitRaw('_PLRT_get_handle:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'push dword ptr [ebp+8]');
  EmitRaw(#9+'call _GetStdHandle@4');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_get_pid() -> PID processus }
  EmitRaw('_PLRT_get_pid:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'call _GetCurrentProcessId@0');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_int_to_str(n) -> ptr chaine ASCII (buffer statique) }
  EmitRaw('_PLRT_int_to_str:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'push edi');
  EmitRaw(#9+'push ebx');
  EmitRaw(#9+'mov eax, dword ptr [ebp+8]');
  EmitRaw(#9+'lea edi, _PLRT_itoa_buf');
  EmitRaw(#9+'add edi, 23');
  EmitRaw(#9+'mov byte ptr [edi], 0');
  EmitRaw(#9+'test eax, eax');
  EmitRaw(#9+'jge _plrt_its_pos');
  EmitRaw(#9+'neg eax');
  EmitRaw(#9+'mov bl, 1');
  EmitRaw(#9+'jmp _plrt_its_loop');
  EmitRaw('_plrt_its_pos:');
  EmitRaw(#9+'xor bl, bl');
  EmitRaw(#9+'test eax, eax');
  EmitRaw(#9+'jnz _plrt_its_loop');
  EmitRaw(#9+'dec edi');
  EmitRaw(#9+'mov byte ptr [edi], 48');
  EmitRaw(#9+'jmp _plrt_its_done');
  EmitRaw('_plrt_its_loop:');
  EmitRaw(#9+'test eax, eax');
  EmitRaw(#9+'jz _plrt_its_sign');
  EmitRaw(#9+'xor edx, edx');
  EmitRaw(#9+'push ecx');
  EmitRaw(#9+'mov ecx, 10');
  EmitRaw(#9+'div ecx');
  EmitRaw(#9+'pop ecx');
  EmitRaw(#9+'add dl, 48');
  EmitRaw(#9+'dec edi');
  EmitRaw(#9+'mov byte ptr [edi], dl');
  EmitRaw(#9+'jmp _plrt_its_loop');
  EmitRaw('_plrt_its_sign:');
  EmitRaw(#9+'test bl, bl');
  EmitRaw(#9+'jz _plrt_its_done');
  EmitRaw(#9+'dec edi');
  EmitRaw(#9+'mov byte ptr [edi], 45');
  EmitRaw('_plrt_its_done:');
  EmitRaw(#9+'mov eax, edi');
  EmitRaw(#9+'pop ebx');
  EmitRaw(#9+'pop edi');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_print(hFile, count, arg1..argN) }
  { Chaque arg < 65536 : converti int->str ; sinon : traite comme ptr chaine }
  EmitRaw('_PLRT_print:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'sub esp, 4');
  EmitRaw(#9+'push esi');
  EmitRaw(#9+'push edi');
  EmitRaw(#9+'push ebx');
  EmitRaw(#9+'mov ebx, dword ptr [ebp+8]');
  EmitRaw(#9+'mov esi, dword ptr [ebp+12]');
  EmitRaw(#9+'lea edi, dword ptr [ebp+16]');
  EmitRaw('_plrt_prt_loop:');
  EmitRaw(#9+'test esi, esi');
  EmitRaw(#9+'jz _plrt_prt_done');
  EmitRaw(#9+'mov eax, dword ptr [edi]');
  EmitRaw(#9+'cmp eax, 65536');
  EmitRaw(#9+'jae _plrt_prt_isstr');
  EmitRaw(#9+'push eax');
  EmitRaw(#9+'call _PLRT_int_to_str');
  EmitRaw(#9+'add esp, 4');
  EmitRaw('_plrt_prt_isstr:');
  EmitRaw(#9+'mov edx, eax');
  EmitRaw(#9+'xor ecx, ecx');
  EmitRaw('_plrt_prt_len:');
  EmitRaw(#9+'cmp byte ptr [edx+ecx], 0');
  EmitRaw(#9+'je _plrt_prt_write');
  EmitRaw(#9+'inc ecx');
  EmitRaw(#9+'jmp _plrt_prt_len');
  EmitRaw('_plrt_prt_write:');
  EmitRaw(#9+'test ecx, ecx');
  EmitRaw(#9+'jz _plrt_prt_next');
  EmitRaw(#9+'push 0');
  EmitRaw(#9+'lea eax, dword ptr [ebp-4]');
  EmitRaw(#9+'push eax');
  EmitRaw(#9+'push ecx');
  EmitRaw(#9+'push edx');
  EmitRaw(#9+'push ebx');
  EmitRaw(#9+'call _WriteFile@20');
  EmitRaw('_plrt_prt_next:');
  EmitRaw(#9+'add edi, 4');
  EmitRaw(#9+'dec esi');
  EmitRaw(#9+'jmp _plrt_prt_loop');
  EmitRaw('_plrt_prt_done:');
  EmitRaw(#9+'mov eax, 1');
  EmitRaw(#9+'pop ebx');
  EmitRaw(#9+'pop edi');
  EmitRaw(#9+'pop esi');
  EmitRaw(#9+'mov esp, ebp');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_exit / _PLRT_exit_fn : termine le processus }
  EmitRaw('_PLRT_exit_fn:');
  EmitRaw('_PLRT_exit:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'push dword ptr [ebp+8]');
  EmitRaw(#9+'call _ExitProcess@4');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');

  { _PLRT_die : termine avec code 1 }
  EmitRaw('_PLRT_die:');
  EmitRaw(#9+'push 1');
  EmitRaw(#9+'call _ExitProcess@4');
  EmitRaw(#9+'ret');

  { Stubs pour toutes les autres fonctions runtime : retournent 0 }
  EmitRaw('_PLRT_say:');
  EmitRaw('_PLRT_printf:');
  EmitRaw('_PLRT_sprintf_fn:');
  EmitRaw('_PLRT_sprintf_int:');
  EmitRaw('_PLRT_sprintf_float:');
  EmitRaw('_PLRT_sprintf_str:');
  EmitRaw('_PLRT_warn:');
  EmitRaw('_PLRT_concat:');
  EmitRaw('_PLRT_repeat:');
  EmitRaw('_PLRT_strcmp:');
  EmitRaw('_PLRT_strcasecmp:');
  EmitRaw('_PLRT_regex_match:');
  EmitRaw('_PLRT_regex_subst:');
  EmitRaw('_PLRT_trans:');
  EmitRaw('_PLRT_chomp:');
  EmitRaw('_PLRT_chop:');
  EmitRaw('_PLRT_uc:');
  EmitRaw('_PLRT_lc:');
  EmitRaw('_PLRT_ucfirst:');
  EmitRaw('_PLRT_lcfirst:');
  EmitRaw('_PLRT_length:');
  EmitRaw('_PLRT_substr:');
  EmitRaw('_PLRT_index_fn:');
  EmitRaw('_PLRT_rindex:');
  EmitRaw('_PLRT_split_fn:');
  EmitRaw('_PLRT_join_fn:');
  EmitRaw('_PLRT_reverse_fn:');
  EmitRaw('_PLRT_sort_fn:');
  EmitRaw('_PLRT_ref_new:');
  EmitRaw('_PLRT_ref_inc:');
  EmitRaw('_PLRT_ref_dec:');
  EmitRaw('_PLRT_ref_free:');
  EmitRaw('_PLRT_ref_type:');
  EmitRaw('_PLRT_deref_scalar:');
  EmitRaw('_PLRT_deref_array:');
  EmitRaw('_PLRT_deref_hash:');
  EmitRaw('_PLRT_deref_code:');
  EmitRaw('_PLRT_anon_array:');
  EmitRaw('_PLRT_anon_hash:');
  EmitRaw('_PLRT_array_new:');
  EmitRaw('_PLRT_array_push:');
  EmitRaw('_PLRT_array_pop:');
  EmitRaw('_PLRT_array_get:');
  EmitRaw('_PLRT_array_set:');
  EmitRaw('_PLRT_array_len:');
  EmitRaw('_PLRT_array_shift:');
  EmitRaw('_PLRT_array_unshift:');
  EmitRaw('_PLRT_array_splice:');
  EmitRaw('_PLRT_array_slice:');
  EmitRaw('_PLRT_array_exists:');
  EmitRaw('_PLRT_hash_new:');
  EmitRaw('_PLRT_hash_set:');
  EmitRaw('_PLRT_hash_get:');
  EmitRaw('_PLRT_hash_exists:');
  EmitRaw('_PLRT_hash_delete:');
  EmitRaw('_PLRT_hash_keys:');
  EmitRaw('_PLRT_hash_values:');
  EmitRaw('_PLRT_hash_each:');
  EmitRaw('_PLRT_hash_len:');
  EmitRaw('_PLRT_hash_scalar:');
  EmitRaw('_PLRT_hash_slice:');
  EmitRaw('_PLRT_hash_merge:');
  EmitRaw('_PLRT_open:');
  EmitRaw('_PLRT_close:');
  EmitRaw('_PLRT_readline:');
  EmitRaw('_PLRT_eof:');
  EmitRaw('_PLRT_binmode:');
  EmitRaw('_PLRT_rename_fn:');
  EmitRaw('_PLRT_unlink_fn:');
  EmitRaw('_PLRT_stat_fn:');
  EmitRaw('_PLRT_chdir_fn:');
  EmitRaw('_PLRT_filetest:');
  EmitRaw('_PLRT_argv_init:');
  EmitRaw('_PLRT_env_init:');
  EmitRaw('_PLRT_cmd_line:');
  EmitRaw('_PLRT_is_defined:');
  EmitRaw('_PLRT_wantarray:');
  EmitRaw('_PLRT_caller_fn:');
  EmitRaw(#9+'push ebp');
  EmitRaw(#9+'mov ebp, esp');
  EmitRaw(#9+'xor eax, eax');
  EmitRaw(#9+'pop ebp');
  EmitRaw(#9+'ret');
  EmitRaw('');
  EmitRaw('; ====== Fin Runtime PERLCW32 ======');
End;

{ Emet l'en-tete du fichier ASM : directives, .DATA, .CODE, entree _PL_main }
Procedure EmitAsmHeader(FrameSz: Integer);
Begin
  EmitRaw('    .386');
  EmitRaw('    .MODEL FLAT, C');
  EmitRaw('    OPTION CASEMAP:NONE');
  EmitRaw('');
  EmitRaw('    EXTRN _ExitProcess@4:NEAR');
  EmitRaw('    EXTRN _GetStdHandle@4:NEAR');
  EmitRaw('    EXTRN _WriteFile@20:NEAR');
  EmitRaw('    EXTRN _ReadFile@20:NEAR');
  EmitRaw('    EXTRN _CreateFileA@28:NEAR');
  EmitRaw('    EXTRN _CloseHandle@4:NEAR');
  EmitRaw('    EXTRN _GetCommandLineA@0:NEAR');
  EmitRaw('    EXTRN _GetEnvironmentStringsA@0:NEAR');
  EmitRaw('    EXTRN _GetCurrentProcessId@0:NEAR');
  EmitRaw('');
  EmitRaw('.DATA');
  EmitSpecialVarDecls;
  EmitRaw('');
  EmitRaw('.CODE');
  EmitRaw('_PL_main:');
  EmitLine('push ebp');
  EmitLine('mov ebp, esp');
  If FrameSz > 0 Then
    EmitLine('sub esp, ' + NumToStr(FrameSz));
End;

{ Emet la fin du fichier ASM : runtime, constantes, directive END }
Procedure EmitAsmFooter;
Begin
  GenRuntime;
  EmitRaw('');
  EmitRaw('.DATA');
  FlushStringConsts;
  FlushFloatConsts;
  EmitRaw('');
  EmitRaw('    END _PL_main');
End;

{ Charge la variable SymRef dans EAX : lexicale [ebp-N] ou globale [label] }
Procedure LoadVarEax(SIdx: Integer);
Begin
  If SIdx = 0 Then Begin
    EmitComment('STUB load var non resolue');
    EmitLine('xor eax, eax');
    Exit;
  End;
  If SymTable[SIdx].ScopeKd = SCOPE_LEXICAL Then
    EmitLine('mov eax, dword ptr [ebp - ' + NumToStr(SymTable[SIdx].Offset) + ']')
  Else
    EmitLine('mov eax, dword ptr [' + SymTable[SIdx].AsmName + ']');
End;

{ Stocke EAX dans la variable SymRef : lexicale [ebp-N] ou globale [label] }
Procedure StoreVarEax(SIdx: Integer);
Begin
  If SIdx = 0 Then Begin
    EmitComment('STUB store var non resolue');
    Exit;
  End;
  If SymTable[SIdx].ScopeKd = SCOPE_LEXICAL Then
    EmitLine('mov dword ptr [ebp - ' + NumToStr(SymTable[SIdx].Offset) + '], eax')
  Else
    EmitLine('mov dword ptr [' + SymTable[SIdx].AsmName + '], eax');
End;

{ Codegen NK_INDEX : charge element de tableau a[i] ou hash h-k- }
{ Left=var arr/hash, Right=index/cle, Tok=Ord('[') ou Ord(123)  }
Procedure CodegenIndex(Node: Integer);
Begin
  CodegenNode(AstTable[Node].Right);  { EAX = index ou cle }
  EmitLine('push eax');               { 2e arg : index/cle }
  CodegenNode(AstTable[Node].Left);   { EAX = ptr tableau ou hash }
  EmitLine('push eax');               { 1er arg : ptr }
  If AstTable[Node].Tok = Ord('[') Then
    EmitLine('call ' + PlRtArrayGet)
  Else
    EmitLine('call ' + PlRtHashGet);
  EmitLine('add esp, 8');
End;

{ Codegen NK_SLICE : tranche de tableau ou hash (STUB) }
Procedure CodegenSlice(Node: Integer);
Begin
  EmitComment('STUB slice ligne ' + NumToStr(AstTable[Node].Line));
  EmitLine('xor eax, eax');
End;

{ Codegen NK_ASSIGN : affectation LHS = RHS (ou .= += -= etc.) }
{ Left=LHS, Right=RHS }
Procedure CodegenAssign(Node: Integer);
Var
  LN, RN, Ln2: Integer;
  LIdx: Integer;
Begin
  LN := AstTable[Node].Left;
  RN := AstTable[Node].Right;
  If AstTable[LN].Kind = NK_VAR Then Begin
    { Scalaire simple : $x = expr }
    CodegenNode(RN);
    StoreVarEax(AstTable[LN].SymRef);
  End Else If AstTable[LN].Kind = NK_INDEX Then Begin
    { Element de tableau a[i]=val ou hash h-k-=val }
    CodegenNode(RN);
    EmitLine('push eax');              { val (3e arg) }
    CodegenNode(AstTable[LN].Right);   { EAX = index ou cle }
    EmitLine('push eax');              { idx/cle (2e arg) }
    CodegenNode(AstTable[LN].Left);    { EAX = ptr arr/hash }
    EmitLine('push eax');              { ptr (1er arg) }
    If AstTable[LN].Tok = Ord('[') Then
      EmitLine('call ' + PlRtArraySet)
    Else
      EmitLine('call ' + PlRtHashSet);
    EmitLine('add esp, 12');
  End Else If AstTable[LN].Kind = NK_LIST Then Begin
    { Affectation de liste : ($a, $b, ...) = (val1, val2, ...) }
    CodegenNode(RN);                   { EAX = ptr liste source }
    EmitLine('push eax');              { sauve ptr liste }
    LIdx := 0;
    Ln2 := AstTable[LN].FirstChild;
    While Ln2 <> 0 Do Begin
      If AstTable[Ln2].Kind = NK_VAR Then Begin
        EmitLine('mov eax, dword ptr [esp]');
        EmitLine('push dword ' + NumToStr(LIdx));
        EmitLine('push eax');
        EmitLine('call ' + PlRtArrayGet);
        EmitLine('add esp, 8');
        StoreVarEax(AstTable[Ln2].SymRef);
        Inc(LIdx);
      End;
      Ln2 := AstTable[Ln2].NextSibling;
    End;
    EmitLine('pop eax');               { nettoie ptr liste }
  End Else Begin
    CodegenNode(RN);
    EmitComment('STUB assign LHS kind=' + NumToStr(AstTable[LN].Kind) +
                ' ligne ' + NumToStr(AstTable[Node].Line));
  End;
End;

{ Codegen NK_SUB_DEF et NK_ANON_SUB : definition de sous-routine }
{ Left=corps, Right=prototype, Text=nom, Third=taille frame locale }
Procedure CodegenSubDef(Node: Integer);
Var
  Nm:        String;
  FrameSz:   Integer;
  EpilLabel: String;
  SIdx:      Integer;
Begin
  Nm      := AstTable[Node].Text;
  FrameSz := AstTable[Node].Third;
  SIdx    := AstTable[Node].SymRef;
  If (FrameSz > 0) And ((FrameSz Mod 4) <> 0) Then
    FrameSz := FrameSz + (4 - (FrameSz Mod 4));
  { Label d'entree }
  If Nm = '' Then Begin
    Inc(PLLCount);
    EpilLabel := MakePLLLabel('SUBEP', PLLCount, 'END');
    EmitLabel(MakePLLLabel('ANON', PLLCount, 'ENTRY'));
  End Else Begin
    EpilLabel := '_PLL_SUBEP_' + Nm;
    If SIdx > 0 Then
      EmitLabel(SymTable[SIdx].AsmName)
    Else
      EmitLabel('_PLF_' + Nm);
  End;
  { Prologue }
  EmitLine('push ebp');
  EmitLine('mov ebp, esp');
  If FrameSz > 0 Then
    EmitLine('sub esp, ' + NumToStr(FrameSz));
  { Corps }
  If AstTable[Node].Left <> 0 Then
    CodegenNode(AstTable[Node].Left);
  { Epilogue }
  EmitLabel(EpilLabel);
  EmitLine('xor eax, eax');
  EmitLine('mov esp, ebp');
  EmitLine('pop ebp');
  EmitLine('ret');
End;

{ ============================================================ }
{ TODO 23 : use strict / use warnings / pragmas / packages     }
{ ============================================================ }

{ Verifie qu'une variable est declaree quand use strict 'vars' }
Procedure CheckStrictVar(VName: String; Sigil: Char);
Begin
  If Not StrictVars Then Exit;
  If FindSym(VName, SK_NONE) = 0 Then
    ParseError('Global symbol "' + Sigil + VName +
               '" requires explicit package name');
End;

{ Retourne True si la categorie de warning est active }
Function WarnActive(Flag: Integer): Boolean;
Begin WarnActive := (WarnFlags And Flag) <> 0; End;

{ Retourne la categorie warning correspondant a une chaine }
Function ParseWarnCategory(S: String): Integer;
Begin
  If      S = 'numeric'       Then ParseWarnCategory := WARN_NUMERIC
  Else If S = 'uninitialized' Then ParseWarnCategory := WARN_UNINIT
  Else If S = 'redefine'      Then ParseWarnCategory := WARN_REDEFINE
  Else If S = 'deprecated'    Then ParseWarnCategory := WARN_DEPRECATED
  Else If S = 'once'          Then ParseWarnCategory := WARN_ONCE
  Else If S = 'shadow'        Then ParseWarnCategory := WARN_SHADOW
  Else If S = 'all'           Then ParseWarnCategory := WARN_ALL
  Else ParseWarnCategory := 0;
End;

{ Emet un warning de compilation si la categorie est active }
Procedure EmitCompileWarn(Category: Integer; Msg: String);
Begin
  If (WarnFlags And Category) = 0 Then Exit;
  If WarnFatal Then FatalError(Msg)
  Else WarnMsg(Msg);
End;

{ Codegen pour NK_USE : directive de compilation, pas de code runtime }
Procedure CodegenPragma(Node: Integer);
Begin
  Case AstTable[Node].Tok Of
    KW_USE:
      EmitComment('; use ' + AstTable[Node].Text);
    KW_NO:
      EmitComment('; no ' + AstTable[Node].Text);
    Else
      EmitComment('; pragma ' + AstTable[Node].Text);
  End;
End;

{ ============================================================ }
{ TODO 22 : Numeriques, chaines et pragmas de types            }
{ ============================================================ }

{ Recherche une constante nommee dans la table (use constant).
  Retourne l'indice 1..ConstCount ou 0 si absente.             }
Function FindConst(Name: String): Integer;
Var I: Integer;
Begin
  FindConst := 0;
  For I := 1 To ConstCount Do
    If ConstTable[I].Name = Name Then Begin FindConst := I; Exit; End;
End;

{ Enregistre une constante nommee (use constant NAME => VALUE) }
Procedure RegisterConst(CName: String; Kind: Integer;
                        IVal: LongInt; FText: String);
Begin
  If ConstCount >= MAX_CONST_TABLE Then Exit;
  Inc(ConstCount);
  ConstTable[ConstCount].Name  := CName;
  ConstTable[ConstCount].Kind  := Kind;
  ConstTable[ConstCount].IVal  := IVal;
  ConstTable[ConstCount].FText := FText;
End;

{ Genere un label unique _PLF_N pour un litteral flottant }
Function MakePLFLabel: String;
Var S: String;
Begin
  Inc(PLFCount);
  Str(PLFCount, S);
  MakePLFLabel := '_PLF_' + S;
End;

{ Met en file d'attente un flottant a emettre en section .rdata }
Procedure EmitFloatConst(Lbl, Text: String);
Begin
  If PLFQueueLen >= MAX_CONST_TABLE Then Exit;
  Inc(PLFQueueLen);
  PLFQueueLbl[PLFQueueLen] := Lbl;
  PLFQueue[PLFQueueLen]    := Text;
End;

{ Emet toutes les constantes flottantes en file d'attente }
Procedure FlushFloatConsts;
Var I: Integer;
Begin
  If PLFQueueLen = 0 Then Exit;
  EmitComment('--- Constantes flottantes segment .rdata ---');
  For I := 1 To PLFQueueLen Do
    EmitDataDecl(PLFQueueLbl[I], 'DQ ' + PLFQueue[I]);
  PLFQueueLen := 0;
End;

{ Codegen NK_LITERAL pour TOK_FLOAT : charge ST(0) via FPU puis EAX }
Procedure CodegenLiteralFloat(Node: Integer);
Var FLbl: String;
Begin
  FLbl := MakePLFLabel;
  EmitFloatConst(FLbl, AstTable[Node].Text);
  EmitLine('fld qword [' + FLbl + ']');
  If UseIntPragma Then
    EmitComment('use integer: resultat FPU tronque vers EAX');
  EmitLine('sub esp, 4');
  EmitLine('fistp dword [esp]');
  EmitLine('pop eax');
End;

{ Codegen NK_LITERAL pour TOK_STRING : label .rdata + adresse }
Procedure CodegenLiteralString(Node: Integer);
Var Lbl: String;
Begin
  Lbl := MakePLKLabel;
  If StringCount < MAX_STRING_LIT Then Begin
    Inc(StringCount);
    StringTable[StringCount].Text    := AstTable[Node].Text;
    StringTable[StringCount].AsmName := Lbl;
    StringTable[StringCount].Len     := Length(AstTable[Node].Text);
    StringTable[StringCount].Flags   := RT_STR_FLAG_STATIC;
  End;
  EmitLine('mov eax, ' + Lbl);
End;

{ ============================================================ }
{ TODO 21 : I/O Fichiers : open / close / readline / eof      }
{ ============================================================ }

Function PlRtOpen:     String; Begin PlRtOpen     := '_PLRT_open';     End;
Function PlRtClose:    String; Begin PlRtClose    := '_PLRT_close';    End;
Function PlRtReadLine: String; Begin PlRtReadLine := '_PLRT_readline'; End;
Function PlRtEof:      String; Begin PlRtEof      := '_PLRT_eof';      End;
Function PlRtBinmode:  String; Begin PlRtBinmode  := '_PLRT_binmode';  End;
Function PlRtRename:   String; Begin PlRtRename   := '_PLRT_rename';   End;
Function PlRtUnlink:   String; Begin PlRtUnlink   := '_PLRT_unlink';   End;
Function PlRtStat:     String; Begin PlRtStat     := '_PLRT_stat';     End;
Function PlRtChdir:    String; Begin PlRtChdir    := '_PLRT_chdir';    End;
Function PlRtFileTest: String; Begin PlRtFileTest := '_PLRT_filetest'; End;

{ Codegen NK_CALL pour I/O fichier : open close readline eof
  binmode rename unlink stat chdir                             }
Procedure CodegenFileIO(Node: Integer);
Var Op, Cnt, A: Integer;
Begin
  Op  := AstTable[Node].Tok;
  Cnt := 0;
  A   := 0;
  Case Op Of
    KW_OPEN: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtOpen);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;
    KW_CLOSE: Begin
      A := AstTable[Node].FirstChild;
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtClose);
      EmitLine('add esp, 4');
    End;
    KW_READLINE: Begin
      A := AstTable[Node].FirstChild;
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtReadLine);
      EmitLine('add esp, 4');
    End;
    KW_EOF_FUNC: Begin
      A := AstTable[Node].FirstChild;
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtEof);
      EmitLine('add esp, 4');
    End;
    KW_BINMODE: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtBinmode);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;
    KW_RENAME: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtRename);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;
    KW_UNLINK: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtUnlink);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;
    KW_STAT: Begin
      A := AstTable[Node].FirstChild;
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStat);
      EmitLine('add esp, 4');
    End;
    KW_CHDIR: Begin
      A := AstTable[Node].FirstChild;
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtChdir);
      EmitLine('add esp, 4');
    End;
    Else
      EmitComment('STUB fileio tok=' + NumToStr(Op) +
                  ' ' + AstTable[Node].Text +
                  ' ligne ' + NumToStr(AstTable[Node].Line));
  End;
  Cnt := Cnt; A := A; { evite warnings variables inutilisees }
End;

{ ============================================================ }
{ TODO 20 : Fonctions integrees generales                      }
{ ============================================================ }

Function PlRtPrint:     String; Begin PlRtPrint     := '_PLRT_print';      End;
Function PlRtSay:       String; Begin PlRtSay       := '_PLRT_say';        End;
Function PlRtPrintf:    String; Begin PlRtPrintf    := '_PLRT_printf';     End;
Function PlRtDie:       String; Begin PlRtDie       := '_PLRT_die';        End;
Function PlRtWarn:      String; Begin PlRtWarn      := '_PLRT_warn';       End;
Function PlRtExitFn:    String; Begin PlRtExitFn    := '_PLRT_exit';       End;
Function PlRtPushArr:   String; Begin PlRtPushArr   := '_PLRT_push';       End;
Function PlRtPopArr:    String; Begin PlRtPopArr    := '_PLRT_pop';        End;
Function PlRtShiftArr:  String; Begin PlRtShiftArr  := '_PLRT_shift';      End;
Function PlRtUnshiftArr:String; Begin PlRtUnshiftArr:= '_PLRT_unshift';    End;
Function PlRtScalarLen: String; Begin PlRtScalarLen := '_PLRT_scalar_len'; End;
Function PlRtKeys:      String; Begin PlRtKeys      := '_PLRT_keys';       End;
Function PlRtValues:    String; Begin PlRtValues    := '_PLRT_values';     End;
Function PlRtEach:      String; Begin PlRtEach      := '_PLRT_each';       End;
Function PlRtExists:    String; Begin PlRtExists    := '_PLRT_exists';     End;
Function PlRtDelete:    String; Begin PlRtDelete    := '_PLRT_delete';     End;
Function PlRtDefined:   String; Begin PlRtDefined   := '_PLRT_defined';    End;
Function PlRtSortFn:    String; Begin PlRtSortFn    := '_PLRT_sort';       End;
Function PlRtGrepFn:    String; Begin PlRtGrepFn    := '_PLRT_grep';       End;
Function PlRtMapFn:     String; Begin PlRtMapFn     := '_PLRT_map';        End;
Function PlRtSplitFn:   String; Begin PlRtSplitFn   := '_PLRT_split';      End;
Function PlRtSleep:     String; Begin PlRtSleep     := '_PLRT_sleep';      End;
Function PlRtTime:      String; Begin PlRtTime      := '_PLRT_time';       End;
Function PlRtSrand:     String; Begin PlRtSrand     := '_PLRT_srand';      End;
Function PlRtRefTypeFn: String; Begin PlRtRefTypeFn := '_PLRT_ref_type';   End;
Function PlRtWantarray: String; Begin PlRtWantarray := '_PLRT_wantarray';  End;

{ Emet les args d un builtin L->R, puis le compte, retourne N args pousses }
Function EmitPushArgs(Node: Integer): Integer;
Var A, Cnt: Integer;
Begin
  A := AstTable[Node].FirstChild;
  Cnt := 0;
  While A <> 0 Do Begin
    CodegenNode(A);
    EmitLine('push eax');
    A := AstTable[A].NextSibling;
    Inc(Cnt);
  End;
  EmitPushArgs := Cnt;
End;

{ Codegen NK_CALL pour fonctions integrees generales }
Procedure CodegenBuiltinCall(Node: Integer);
Var
  A, Cnt: Integer;
  Op:     Integer;
Begin
  Op  := AstTable[Node].Tok;
  A   := AstTable[Node].FirstChild;
  Cnt := 0;
  Case Op Of

    KW_PRINT, KW_SAY, KW_PRINTF: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('push dword [_PL_STDOUT]');
      If Op = KW_PRINT Then EmitLine('call ' + PlRtPrint)
      Else If Op = KW_SAY Then EmitLine('call ' + PlRtSay)
      Else EmitLine('call ' + PlRtPrintf);
      EmitLine('add esp, ' + NumToStr((Cnt + 2) * 4));
    End;

    KW_WARN: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtWarn);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_DIE: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtDie);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_EXIT: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtExitFn);
      EmitLine('add esp, 4');
    End;

    KW_SPRINTF: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtStrSprintf);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_LENGTH: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrLen);
      EmitLine('add esp, 4');
    End;

    KW_CHOMP: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrChomp);
      EmitLine('add esp, 4');
    End;

    KW_CHOP: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrChop);
      EmitLine('add esp, 4');
    End;

    KW_UC: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrUC);
      EmitLine('add esp, 4');
    End;

    KW_LC: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrLC);
      EmitLine('add esp, 4');
    End;

    KW_UCFIRST: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrUCFirst);
      EmitLine('add esp, 4');
    End;

    KW_LCFIRST: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrLCFirst);
      EmitLine('add esp, 4');
    End;

    KW_REVERSE: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrReverse);
      EmitLine('add esp, 4');
    End;

    KW_CHR: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrChr);
      EmitLine('add esp, 4');
    End;

    KW_ORD: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PL__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtStrOrd);
      EmitLine('add esp, 4');
    End;

    KW_SUBSTR: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtStrSubstr);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_INDEX_FUNC: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtStrIndex);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_RINDEX: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtStrRindex);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_JOIN: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtStrJoin);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_SPLIT: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtSplitFn);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_PUSH: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtPushArr);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_POP: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PLA__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtPopArr);
      EmitLine('add esp, 4');
    End;

    KW_SHIFT: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PLA__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtShiftArr);
      EmitLine('add esp, 4');
    End;

    KW_UNSHIFT: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtUnshiftArr);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_SCALAR: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('mov eax, [_PLA__]');
      EmitLine('push eax');
      EmitLine('call ' + PlRtScalarLen);
      EmitLine('add esp, 4');
    End;

    KW_KEYS: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtKeys);
      EmitLine('add esp, 4');
    End;

    KW_VALUES: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtValues);
      EmitLine('add esp, 4');
    End;

    KW_EACH: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtEach);
      EmitLine('add esp, 4');
    End;

    KW_EXISTS: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtExists);
      EmitLine('add esp, 4');
    End;

    KW_DELETE: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtDelete);
      EmitLine('add esp, 4');
    End;

    KW_DEFINED: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtDefined);
      EmitLine('add esp, 4');
    End;

    KW_SORT: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtSortFn);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_GREP: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtGrepFn);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_MAP: Begin
      Cnt := EmitPushArgs(Node);
      EmitLine('push dword ' + NumToStr(Cnt));
      EmitLine('call ' + PlRtMapFn);
      EmitLine('add esp, ' + NumToStr((Cnt + 1) * 4));
    End;

    KW_SLEEP: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtSleep);
      EmitLine('add esp, 4');
    End;

    KW_TIME: Begin
      EmitLine('call ' + PlRtTime);
    End;

    KW_SRAND: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtSrand);
      EmitLine('add esp, 4');
    End;

    KW_WANTARRAY: Begin
      EmitLine('call ' + PlRtWantarray);
    End;

    KW_REF: Begin
      If A <> 0 Then CodegenNode(A) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtRefTypeFn);
      EmitLine('add esp, 4');
    End;

    Else
      CodegenFileIO(Node);
  End;
  Cnt := Cnt; A := A; { evite warnings variables inutilisees }
End;

{ ============================================================ }
{ TODO 19 : Operateurs numeriques, booleen, comparaisons       }
{ ============================================================ }

Function PlRtPow:      String; Begin PlRtPow      := '_PLRT_pow';       End;
Function PlRtAbsFn:    String; Begin PlRtAbsFn    := '_PLRT_abs';       End;
Function PlRtIntTrunc: String; Begin PlRtIntTrunc := '_PLRT_int_trunc'; End;
Function PlRtSqrtFn:   String; Begin PlRtSqrtFn   := '_PLRT_sqrt';      End;
Function PlRtExpFn:    String; Begin PlRtExpFn    := '_PLRT_exp';       End;
Function PlRtLogFn:    String; Begin PlRtLogFn    := '_PLRT_log';       End;
Function PlRtSinFn:    String; Begin PlRtSinFn    := '_PLRT_sin';       End;
Function PlRtCosFn:    String; Begin PlRtCosFn    := '_PLRT_cos';       End;
Function PlRtAtan2Fn:  String; Begin PlRtAtan2Fn  := '_PLRT_atan2';     End;
Function PlRtHexFn:    String; Begin PlRtHexFn    := '_PLRT_hex';       End;
Function PlRtOctFn:    String; Begin PlRtOctFn    := '_PLRT_oct';       End;
Function PlRtNumToStr: String; Begin PlRtNumToStr := '_PLRT_num_to_str';End;
Function PlRtRandFn:   String; Begin PlRtRandFn   := '_PLRT_rand';      End;
{ PlRtToNum, PlRtStrCmp, PlRtStrConcat deja declares dans sections anterieures }

{ Codegen NK_LITERAL : entier -> mov eax,N ; undef -> xor eax,eax ; autres STUB }
Procedure CodegenLiteral(Node: Integer);
Var Tok: Integer;
Begin
  Tok := AstTable[Node].Tok;
  If Tok = TOK_INTEGER Then
    EmitLine('mov eax, ' + NumToStr(AstTable[Node].Left))
  Else If Tok = KW_UNDEF Then
    EmitLine('xor eax, eax')
  Else If Tok = TOK_FLOAT Then
    CodegenLiteralFloat(Node)
  Else If (Tok = TOK_STRING) Or (Tok = TOK_DSTRING) Then
    CodegenLiteralString(Node)
  Else
    EmitComment('STUB literal tok=' + NumToStr(Tok) +
                ' val=' + AstTable[Node].Text);
End;

{ Codegen NK_BINARY : arithmetique, bitwise, comparaisons num et chaines }
Procedure CodegenBinaryOp(Node: Integer);
Var
  Op, LNum: Integer;
  A1, A2:   Integer;
Begin
  Op := AstTable[Node].Tok;
  A1 := 0; A2 := 0;
  If (Op = Ord('+')) Or (Op = Ord('-')) Or (Op = Ord('*')) Or
     (Op = Ord('/')) Or (Op = Ord('%')) Or (Op = TOK_POW)  Or
     (Op = Ord('&')) Or (Op = Ord('|')) Or (Op = Ord('^')) Or
     (Op = TOK_SHL)  Or (Op = TOK_SHR) Or
     (Op = TOK_EQ)   Or (Op = TOK_NE)  Or (Op = Ord('<')) Or
     (Op = Ord('>')) Or (Op = TOK_LE)  Or (Op = TOK_GE)   Or
     (Op = TOK_SPACESHIP) Then Begin
    CodegenNode(AstTable[Node].Left);
    EmitLine('push eax');
    CodegenNode(AstTable[Node].Right);
    EmitLine('mov ecx, eax');
    EmitLine('pop eax');
    Case Op Of
      Ord('+'): EmitLine('add eax, ecx');
      Ord('-'): EmitLine('sub eax, ecx');
      Ord('*'): EmitLine('imul eax, ecx');
      Ord('/'): Begin
        EmitLine('cdq');
        EmitLine('idiv ecx');
      End;
      Ord('%'): Begin
        EmitLine('cdq');
        EmitLine('idiv ecx');
        EmitLine('mov eax, edx');
      End;
      TOK_POW: Begin
        EmitLine('push ecx');
        EmitLine('push eax');
        EmitLine('call ' + PlRtPow);
        EmitLine('add esp, 8');
      End;
      Ord('&'): EmitLine('and eax, ecx');
      Ord('|'): EmitLine('or eax, ecx');
      Ord('^'): EmitLine('xor eax, ecx');
      TOK_SHL:  EmitLine('shl eax, cl');
      TOK_SHR:  EmitLine('sar eax, cl');
      TOK_EQ:  Begin
        EmitLine('cmp eax, ecx'); EmitLine('sete al');
        EmitLine('movzx eax, al');
      End;
      TOK_NE:  Begin
        EmitLine('cmp eax, ecx'); EmitLine('setne al');
        EmitLine('movzx eax, al');
      End;
      Ord('<'): Begin
        EmitLine('cmp eax, ecx'); EmitLine('setl al');
        EmitLine('movzx eax, al');
      End;
      Ord('>'): Begin
        EmitLine('cmp eax, ecx'); EmitLine('setg al');
        EmitLine('movzx eax, al');
      End;
      TOK_LE:  Begin
        EmitLine('cmp eax, ecx'); EmitLine('setle al');
        EmitLine('movzx eax, al');
      End;
      TOK_GE:  Begin
        EmitLine('cmp eax, ecx'); EmitLine('setge al');
        EmitLine('movzx eax, al');
      End;
      TOK_SPACESHIP: Begin
        Inc(PLLCount); LNum := PLLCount;
        EmitLine('cmp eax, ecx');
        EmitLine('jl ' + MakePLLLabel('SHIP', LNum, 'NEG'));
        EmitLine('jg ' + MakePLLLabel('SHIP', LNum, 'POS'));
        EmitLine('xor eax, eax');
        EmitLine('jmp ' + MakePLLLabel('SHIP', LNum, 'END'));
        EmitLabel(MakePLLLabel('SHIP', LNum, 'NEG'));
        EmitLine('mov eax, -1');
        EmitLine('jmp ' + MakePLLLabel('SHIP', LNum, 'END'));
        EmitLabel(MakePLLLabel('SHIP', LNum, 'POS'));
        EmitLine('mov eax, 1');
        EmitLabel(MakePLLLabel('SHIP', LNum, 'END'));
      End;
    End;
  End Else If (Op = KW_EQ_STR) Or (Op = KW_NE_STR) Or
              (Op = KW_LT_STR) Or (Op = KW_GT_STR) Or
              (Op = KW_LE_STR) Or (Op = KW_GE_STR) Or
              (Op = TOK_CMP)   Or (Op = KW_CMP_STR) Then Begin
    { cdecl : push droite d'abord, puis gauche -> gauche = premier parametre }
    CodegenNode(AstTable[Node].Right);
    EmitLine('push eax');
    CodegenNode(AstTable[Node].Left);
    EmitLine('push eax');
    EmitLine('call ' + PlRtStrCmp);
    EmitLine('add esp, 8');
    If (Op <> TOK_CMP) And (Op <> KW_CMP_STR) Then Begin
      Case Op Of
        KW_EQ_STR: Begin
          EmitLine('test eax, eax'); EmitLine('sete al');
          EmitLine('movzx eax, al');
        End;
        KW_NE_STR: Begin
          EmitLine('test eax, eax'); EmitLine('setne al');
          EmitLine('movzx eax, al');
        End;
        KW_LT_STR: Begin
          EmitLine('test eax, eax'); EmitLine('setl al');
          EmitLine('movzx eax, al');
        End;
        KW_GT_STR: Begin
          EmitLine('test eax, eax'); EmitLine('setg al');
          EmitLine('movzx eax, al');
        End;
        KW_LE_STR: Begin
          EmitLine('test eax, eax'); EmitLine('setle al');
          EmitLine('movzx eax, al');
        End;
        KW_GE_STR: Begin
          EmitLine('test eax, eax'); EmitLine('setge al');
          EmitLine('movzx eax, al');
        End;
      End;
    End;
  End Else
    EmitComment('STUB binary op=' + NumToStr(Op) +
                ' ligne ' + NumToStr(AstTable[Node].Line));
  A1 := A1; A2 := A2; { evite warning variables inutilisees }
End;

{ Codegen NK_UNARY : -, ~, !, not, +, ++, -- }
Procedure CodegenUnaryArith(Node: Integer);
Var Op: Integer;
Begin
  Op := AstTable[Node].Tok;
  If Op = Ord('+') Then Begin
    CodegenNode(AstTable[Node].Left);
  End Else If Op = Ord('-') Then Begin
    CodegenNode(AstTable[Node].Left);
    EmitLine('neg eax');
  End Else If Op = Ord('~') Then Begin
    CodegenNode(AstTable[Node].Left);
    EmitLine('not eax');
  End Else If (Op = Ord('!')) Or (Op = KW_NOT) Then Begin
    CodegenNode(AstTable[Node].Left);
    EmitLine('push eax');
    EmitLine('call ' + PlRtToBool);
    EmitLine('add esp, 4');
    EmitLine('xor eax, 1');
  End Else If (Op = TOK_INCR) Or (Op = TOK_DECR) Then Begin
    EmitComment('STUB incr/decr ligne ' + NumToStr(AstTable[Node].Line));
    CodegenNode(AstTable[Node].Left);
    If Op = TOK_INCR Then EmitLine('inc eax')
    Else EmitLine('dec eax');
  End Else If Op = TOK_FTEST Then Begin
    { Test fichier : -e -f -d -r -w -x etc. }
    If AstTable[Node].Left <> 0 Then
      CodegenNode(AstTable[Node].Left)
    Else
      EmitLine('xor eax, eax');
    EmitLine('push eax');
    If Length(AstTable[Node].Text) > 0 Then
      EmitLine('push dword ' + NumToStr(Ord(AstTable[Node].Text[1])))
    Else
      EmitLine('push dword ' + NumToStr(Ord('e')));
    EmitLine('call ' + PlRtFileTest);
    EmitLine('add esp, 8');
  End Else
    EmitComment('STUB unary op=' + NumToStr(Op) +
                ' ligne ' + NumToStr(AstTable[Node].Line));
End;

{ Codegen NK_CALL pour fonctions math : abs int sqrt exp log sin cos atan2 hex oct rand }
Procedure CodegenMathCall(Node: Integer);
Var A1, A2: Integer;
Begin
  A1 := AstTable[Node].FirstChild;
  A2 := 0;
  Case AstTable[Node].Tok Of
    KW_ABS: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtAbsFn);
      EmitLine('add esp, 4');
    End;
    KW_INT_FUNC: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtIntTrunc);
      EmitLine('add esp, 4');
    End;
    KW_SQRT: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtSqrtFn);
      EmitLine('add esp, 4');
    End;
    KW_EXP: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtExpFn);
      EmitLine('add esp, 4');
    End;
    KW_LOG: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtLogFn);
      EmitLine('add esp, 4');
    End;
    KW_SIN: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtSinFn);
      EmitLine('add esp, 4');
    End;
    KW_COS: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtCosFn);
      EmitLine('add esp, 4');
    End;
    KW_ATAN2: Begin
      If A1 <> 0 Then A2 := AstTable[A1].NextSibling;
      { cdecl : push x (2eme arg) d'abord, puis y (1er) }
      If A2 <> 0 Then CodegenNode(A2) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtAtan2Fn);
      EmitLine('add esp, 8');
    End;
    KW_HEX: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtHexFn);
      EmitLine('add esp, 4');
    End;
    KW_OCT: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtOctFn);
      EmitLine('add esp, 4');
    End;
    KW_RAND: Begin
      If A1 <> 0 Then CodegenNode(A1) Else EmitLine('xor eax, eax');
      EmitLine('push eax');
      EmitLine('call ' + PlRtRandFn);
      EmitLine('add esp, 4');
    End;
    Else
      EmitComment('STUB math call tok=' + NumToStr(AstTable[Node].Tok) +
                  ' ligne ' + NumToStr(AstTable[Node].Line));
  End;
  A2 := A2; { evite warning variable inutilisee }
End;

{ ============================================================ }
{ TODO 18 : Variables speciales Perl                           }
{ ============================================================ }

Const
  WIN32_STD_INPUT_HANDLE  = -10;
  WIN32_STD_OUTPUT_HANDLE = -11;
  WIN32_STD_ERROR_HANDLE  = -12;

  ASM_LABEL_STDIN  = '_PL_STDIN';
  ASM_LABEL_STDOUT = '_PL_STDOUT';
  ASM_LABEL_STDERR = '_PL_STDERR';

{ Retourne le label ASM du segment .data pour une variable speciale }
{ Sig = '$' '@' '%' ; Name = nom sans sigil ; '' si pas speciale    }
Function SpecialVarLabel(Name: String; Sig: Char): String;
Var S: String;
Begin
  SpecialVarLabel := '';
  If Sig = '$' Then Begin
    If      Name = '_'    Then SpecialVarLabel := '_PL__'
    Else If Name = '!'    Then SpecialVarLabel := '_PL_ERRNO'
    Else If Name = '@'    Then SpecialVarLabel := '_PL_EVAL_ERR'
    Else If Name = '0'    Then SpecialVarLabel := '_PL_ARG0'
    Else If Name = '/'    Then SpecialVarLabel := '_PL_RS'
    Else If Name = '\'    Then SpecialVarLabel := '_PL_OFS'
    Else If Name = ','    Then SpecialVarLabel := '_PL_OFS_SEP'
    Else If Name = ';'    Then SpecialVarLabel := '_PL_SUBSEP'
    Else If Name = '.'    Then SpecialVarLabel := '_PL_LINENO'
    Else If Name = '|'    Then SpecialVarLabel := '_PL_AUTOFLUSH'
    Else If Name = '$'    Then SpecialVarLabel := '_PL_PID'
    Else If Name = '&'    Then SpecialVarLabel := '_PL_MATCH'
    Else If Name = '`'    Then SpecialVarLabel := '_PL_PREMATCH'
    Else If Name = ''''   Then SpecialVarLabel := '_PL_POSTMATCH'
    Else If Name = '+'    Then SpecialVarLabel := '_PL_LASTGROUP'
    Else If (Length(Name) = 1) And
            (Name[1] >= '1') And (Name[1] <= '9') Then
      SpecialVarLabel := '_PL_CAPT_' + Name;
  End Else If Sig = '@' Then Begin
    If      Name = '_'    Then SpecialVarLabel := '_PLA__'
    Else If Name = 'ARGV' Then SpecialVarLabel := '_PLA_ARGV'
    Else If Name = 'INC'  Then SpecialVarLabel := '_PLA_INC'
    Else If Name = 'ISA'  Then SpecialVarLabel := '_PLA_ISA'
    Else If Name = '+'    Then SpecialVarLabel := '_PLA_MATCH_START'
    Else If Name = '-'    Then SpecialVarLabel := '_PLA_MATCH_END';
  End Else If Sig = '%' Then Begin
    If      Name = 'ENV'  Then SpecialVarLabel := '_PLH_ENV'
    Else If Name = 'SIG'  Then SpecialVarLabel := '_PLH_SIG'
    Else If Name = 'INC'  Then SpecialVarLabel := '_PLH_INC';
  End;
  S := S; { evite warning variable inutilisee }
End;

Function IsSpecialVar(Name: String; Sig: Char): Boolean;
Begin
  IsSpecialVar := SpecialVarLabel(Name, Sig) <> '';
End;

{ Retourne '$' '@' ou '%' a partir du token de sigil }
Function SigilChar(Tok: Integer): Char;
Begin
  If Tok = TOK_SIGIL_ARRAY Then SigilChar := '@'
  Else If Tok = TOK_SIGIL_HASH Then SigilChar := '%'
  Else SigilChar := '$';
End;

{ Noms des fonctions runtime pour variables speciales }
Function PlRtEnvGet:    String; Begin PlRtEnvGet    := '_PLRT_env_get';    End;
Function PlRtEnvSet:    String; Begin PlRtEnvSet    := '_PLRT_env_set';    End;
Function PlRtEnvInit:   String; Begin PlRtEnvInit   := '_PLRT_env_init';   End;
Function PlRtArgvInit:  String; Begin PlRtArgvInit  := '_PLRT_argv_init';  End;
Function PlRtGetPid:    String; Begin PlRtGetPid    := 'GetCurrentProcessId'; End;
Function PlRtCmdLine:   String; Begin PlRtCmdLine   := 'GetCommandLineA';  End;
Function PlRtGetHandle: String; Begin PlRtGetHandle := 'GetStdHandle';     End;

{ Emet une declaration de donnee MASM : "Label DD 0" }
Procedure EmitDataDecl(Lbl, Decl: String);
Begin
  If AsmOutOpen Then WriteLn(AsmOut, Lbl + ' ' + Decl)
  Else WriteLn(Lbl + ' ' + Decl);
End;

{ Emet les declarations .data pour toutes les variables speciales }
Procedure EmitSpecialVarDecls;
Var I: Integer;
Begin
  EmitComment('--- Variables speciales Perl (segment .data) ---');
  EmitDataDecl('_PL__',           'DD 0');   { $_ }
  EmitDataDecl('_PL_RS',          'DD 0');   { $/ }
  EmitDataDecl('_PL_OFS',         'DD 0');   { $\ }
  EmitDataDecl('_PL_OFS_SEP',     'DD 0');   { $, }
  EmitDataDecl('_PL_SUBSEP',      'DD 0');   { $; }
  EmitDataDecl('_PL_LINENO',      'DD 0');   { $. }
  EmitDataDecl('_PL_AUTOFLUSH',   'DD 0');   { $| }
  EmitDataDecl('_PL_PID',         'DD 0');   { $$ }
  EmitDataDecl('_PL_ERRNO',       'DD 0');   { $! }
  EmitDataDecl('_PL_EVAL_ERR',    'DD 0');   { $@ }
  EmitDataDecl('_PL_ARG0',        'DD 0');   { $0 }
  EmitDataDecl('_PL_MATCH',       'DD 0');   { $& }
  EmitDataDecl('_PL_PREMATCH',    'DD 0');   { $` }
  EmitDataDecl('_PL_POSTMATCH',   'DD 0');   { $' }
  EmitDataDecl('_PL_LASTGROUP',   'DD 0');   { $+ }
  For I := 1 To 9 Do
    EmitDataDecl('_PL_CAPT_' + NumToStr(I), 'DD 0');  { $1..$9 }
  EmitDataDecl('_PL_STDIN',       'DD 0');
  EmitDataDecl('_PL_STDOUT',      'DD 0');
  EmitDataDecl('_PL_STDERR',      'DD 0');
  EmitDataDecl('_PLA__',          'DD 0');   { @_ }
  EmitDataDecl('_PLA_ARGV',       'DD 0');   { @ARGV }
  EmitDataDecl('_PLA_INC',        'DD 0');   { @INC }
  EmitDataDecl('_PLA_ISA',        'DD 0');   { @ISA }
  EmitDataDecl('_PLA_MATCH_START','DD 0');   { @+ }
  EmitDataDecl('_PLA_MATCH_END',  'DD 0');   { @- }
  EmitDataDecl('_PLH_ENV',        'DD 0');   { %ENV }
  EmitDataDecl('_PLH_SIG',        'DD 0');   { %SIG }
  EmitDataDecl('_PLH_INC',        'DD 0');   { %INC }
End;

{ Emet le prologue programme : handles Win32, $$, @ARGV, %ENV }
Procedure CodegenPrologue;
Begin
  EmitComment('=== Prologue : init variables speciales ===');
  EmitLine('push dword ' + NumToStr(WIN32_STD_OUTPUT_HANDLE));
  EmitLine('call ' + PlRtGetHandle);
  EmitLine('add esp, 4');
  EmitLine('mov [' + ASM_LABEL_STDOUT + '], eax');
  EmitLine('push dword ' + NumToStr(WIN32_STD_INPUT_HANDLE));
  EmitLine('call ' + PlRtGetHandle);
  EmitLine('add esp, 4');
  EmitLine('mov [' + ASM_LABEL_STDIN + '], eax');
  EmitLine('push dword ' + NumToStr(WIN32_STD_ERROR_HANDLE));
  EmitLine('call ' + PlRtGetHandle);
  EmitLine('add esp, 4');
  EmitLine('mov [' + ASM_LABEL_STDERR + '], eax');
  EmitLine('call ' + PlRtGetPid);
  EmitLine('mov [_PL_PID], eax');
  EmitLine('call ' + PlRtCmdLine);
  EmitLine('push eax');
  EmitLine('call ' + PlRtArgvInit);
  EmitLine('add esp, 4');
  EmitLine('mov [_PLA_ARGV], eax');
  EmitLine('call ' + PlRtEnvInit);
  EmitLine('mov [_PLH_ENV], eax');
End;

{ Codegen pour NK_VAR : charge EAX depuis variable speciale ou STUB }
Procedure CodegenVar(Node: Integer);
Var
  Sig: Char;
  Lbl: String;
  Nm:  String;
Begin
  Nm  := AstTable[Node].Text;
  Sig := SigilChar(AstTable[Node].Tok);
  Lbl := SpecialVarLabel(Nm, Sig);
  If Lbl <> '' Then Begin
    EmitComment('load special ' + Sig + Nm + ' -> ' + Lbl);
    EmitLine('mov eax, [' + Lbl + ']');
  End Else Begin
    LoadVarEax(AstTable[Node].SymRef);
  End;
End;

{ ============================================================ }
{ TODO 17 : References et dereferencement                      }
{ ============================================================ }

Const
  PERL_REF_SCALAR = 1;   { tag type reference scalaire }
  PERL_REF_ARRAY  = 2;   { tag type reference tableau  }
  PERL_REF_HASH   = 3;   { tag type reference hash     }
  PERL_REF_CODE   = 4;   { tag type reference code     }
  PERL_REF_REF    = 5;   { tag type reference de ref   }

{ Noms des fonctions runtime pour les references }
Function PlRtRefNew:     String; Begin PlRtRefNew     := '_PLRT_ref_new';      End;
Function PlRtRefInc:     String; Begin PlRtRefInc     := '_PLRT_ref_inc';      End;
Function PlRtRefDec:     String; Begin PlRtRefDec     := '_PLRT_ref_dec';      End;
Function PlRtRefFree:    String; Begin PlRtRefFree    := '_PLRT_ref_free';     End;
Function PlRtRefType:    String; Begin PlRtRefType    := '_PLRT_ref_type';     End;
Function PlRtDerefScalar:String; Begin PlRtDerefScalar:= '_PLRT_deref_scalar'; End;
Function PlRtDerefArray: String; Begin PlRtDerefArray := '_PLRT_deref_array';  End;
Function PlRtDerefHash:  String; Begin PlRtDerefHash  := '_PLRT_deref_hash';   End;
Function PlRtDerefCode:  String; Begin PlRtDerefCode  := '_PLRT_deref_code';   End;
Function PlRtAnonArray:  String; Begin PlRtAnonArray  := '_PLRT_anon_array';   End;
Function PlRtAnonHash:   String; Begin PlRtAnonHash   := '_PLRT_anon_hash';    End;

{ Codegen pour l'operateur backslash : \$var \@arr \%hash \&sub }
{ Cree un objet reference sur le heap, retourne le ptr dans EAX  }
Procedure CodegenRefOp(Node: Integer);
Var
  TagStr: String;
  OpKind: Integer;
Begin
  If AstTable[Node].Left = 0 Then Begin
    EmitComment('STUB ref backslash noeud vide');
    Exit;
  End;
  OpKind := AstTable[AstTable[Node].Left].Tok;
  { Determiner le type de reference a creer }
  If OpKind = TOK_SIGIL_ARRAY Then TagStr := NumToStr(PERL_REF_ARRAY)
  Else If OpKind = TOK_SIGIL_HASH Then TagStr := NumToStr(PERL_REF_HASH)
  Else If OpKind = TOK_SIGIL_CODE Then TagStr := NumToStr(PERL_REF_CODE)
  Else TagStr := NumToStr(PERL_REF_SCALAR);
  EmitComment('\\expr -> ref ligne ' + NumToStr(AstTable[Node].Line));
  { Generer l'expression pour obtenir l'adresse de l'operande }
  EmitComment('STUB lea eax, addr(operande)');
  CodegenNode(AstTable[Node].Left);
  EmitLine('push eax');
  EmitLine('push dword ' + TagStr);
  EmitLine('call ' + PlRtRefNew);
  EmitLine('add esp, 8');
End;

{ Codegen pour NK_DEREF : $$ref @$ref %$ref }
{ Charge la variable ref dans EAX, puis appelle le deref runtime }
Procedure CodegenDeref(Node: Integer);
Var
  DerefFn: String;
Begin
  EmitComment('deref ' + AstTable[Node].Text +
              ' ligne ' + NumToStr(AstTable[Node].Line));
  { Charger la variable ref -> EAX }
  EmitComment('STUB mov eax, [ebp - offset(' + AstTable[Node].Text + ')]');
  { Choisir la fonction de dereferencement }
  Case AstTable[Node].Tok Of
    TOK_DEREF_ARRAY: DerefFn := PlRtDerefArray;
    TOK_DEREF_HASH:  DerefFn := PlRtDerefHash;
    Else             DerefFn := PlRtDerefScalar;
  End;
  EmitLine('push eax');
  EmitLine('call ' + DerefFn);
  EmitLine('add esp, 4');
End;

{ Codegen pour NK_ARRAY_LIT avec Tok=Ord('[') : tableau anonyme [...]  }
{ Construit un tableau sur le heap et retourne sa reference dans EAX    }
Procedure CodegenAnonArray(Node: Integer);
Var
  C:  Integer;
  Cnt: Integer;
Begin
  Cnt := 0;
  EmitComment('anon array [...] ligne ' + NumToStr(AstTable[Node].Line));
  EmitLine('call ' + PlRtAnonArray);
  EmitLine('push eax');  { save array ptr }
  C := AstTable[Node].FirstChild;
  While C <> 0 Do Begin
    Inc(Cnt);
    CodegenNode(C);
    EmitLine('push eax');
    EmitLine('push dword [esp+4]');    { array ptr }
    EmitLine('push dword ' + NumToStr(Cnt - 1));  { index }
    EmitLine('call ' + PlRtArraySet);
    EmitLine('add esp, 12');
    C := AstTable[C].NextSibling;
  End;
  EmitLine('pop eax');   { array ptr -> EAX }
End;

{ Codegen pour NK_HASH_LIT avec Tok=Ord-brace : hash anonyme          }
{ Construit un hash sur le heap et retourne sa reference dans EAX      }
Procedure CodegenAnonHash(Node: Integer);
Var
  C:    Integer;
  IsKey: Boolean;
Begin
  EmitComment('anon hash ... ligne ' + NumToStr(AstTable[Node].Line));
  EmitLine('call ' + PlRtAnonHash);
  EmitLine('push eax');   { save hash ptr }
  C      := AstTable[Node].FirstChild;
  IsKey  := True;
  While C <> 0 Do Begin
    If IsKey Then Begin
      { Empiler la cle }
      CodegenNode(C);
      EmitLine('push eax');   { key }
      IsKey := False;
    End Else Begin
      { Valeur : empiler avec la cle et appeler hash_set }
      CodegenNode(C);
      EmitLine('push eax');   { value }
      EmitLine('push dword [esp+8]');   { hash ptr }
      EmitLine('call ' + PlRtHashSet);
      EmitLine('add esp, 12');  { clean value + key + hash ptr }
      IsKey := True;
    End;
    C := AstTable[C].NextSibling;
  End;
  EmitLine('pop eax');   { hash ptr -> EAX }
End;

{ ============================================================ }
{ TODO 16 : Boucles : WHILE / UNTIL / FOR / FOREACH / DO-WHILE }
{ ============================================================ }

{ Empile l'index de label de la boucle courante }
Procedure PushLoop(LabelN: Integer);
Begin
  If LoopDepth >= MAX_LOOP_NEST Then FatalError('trop de boucles imbriquees');
  Inc(LoopDepth);
  LoopStack[LoopDepth] := LabelN;
End;

{ Depile le label de la boucle courante }
Procedure PopLoop;
Begin
  If LoopDepth > 0 Then Dec(LoopDepth);
End;

{ Retourne l'index PLL de la boucle active (0 si hors boucle) }
Function CurrentLoop: Integer;
Begin
  If LoopDepth > 0 Then CurrentLoop := LoopStack[LoopDepth]
  Else CurrentLoop := 0;
End;

{ Noms runtime pour les iterateurs foreach }
Function PlRtIterCreate: String; Begin PlRtIterCreate := '_PLRT_iter_create'; End;
Function PlRtIterNext:   String; Begin PlRtIterNext   := '_PLRT_iter_next';   End;
Function PlRtIterFree:   String; Begin PlRtIterFree   := '_PLRT_iter_free';   End;

{ --- Declarations locales pour appels croises dans TODO 16 --- }
Procedure CodegenWhile(Node: Integer);    Forward;
Procedure CodegenDoWhile(Node: Integer);  Forward;
Procedure CodegenForC(Node: Integer);     Forward;
Procedure CodegenForeach(Node: Integer);  Forward;
Procedure CodegenLoopCtrl(Node: Integer); Forward;

{ Codegen NK_WHILE / NK_UNTIL : while-COND-BODY }
{ Left=condition, Right=corps }
Procedure CodegenWhile(Node: Integer);
Var
  LabelN:  Integer;
  TopLbl:  String;
  ContLbl: String;
  EndLbl:  String;
Begin
  Inc(PLLCount);
  LabelN  := PLLCount;
  TopLbl  := MakePLLLabel('LOOP', LabelN, 'TOP');
  ContLbl := MakePLLLabel('LOOP', LabelN, 'CONT');
  EndLbl  := MakePLLLabel('LOOP', LabelN, 'END');
  PushLoop(LabelN);
  EmitComment('while/until ligne ' + NumToStr(AstTable[Node].Line));
  EmitLabel(TopLbl);
  EmitBoolTest(AstTable[Node].Left);
  If AstTable[Node].Kind = NK_WHILE Then
    EmitLine('jz ' + EndLbl)
  Else
    EmitLine('jnz ' + EndLbl);        { until : saute si vrai }
  CodegenNode(AstTable[Node].Right);   { corps }
  EmitLabel(ContLbl);
  EmitLine('jmp ' + TopLbl);
  EmitLabel(EndLbl);
  PopLoop;
End;

{ Codegen NK_DO_WHILE : do-BODY-while/until-COND }
{ Left=corps, Right=condition, Tok=KW_UNTIL si do-until }
Procedure CodegenDoWhile(Node: Integer);
Var
  LabelN:  Integer;
  TopLbl:  String;
  ContLbl: String;
  EndLbl:  String;
Begin
  Inc(PLLCount);
  LabelN  := PLLCount;
  TopLbl  := MakePLLLabel('LOOP', LabelN, 'TOP');
  ContLbl := MakePLLLabel('LOOP', LabelN, 'CONT');
  EndLbl  := MakePLLLabel('LOOP', LabelN, 'END');
  PushLoop(LabelN);
  EmitComment('do-while/until ligne ' + NumToStr(AstTable[Node].Line));
  EmitLabel(TopLbl);
  CodegenNode(AstTable[Node].Left);    { corps }
  EmitLabel(ContLbl);
  EmitBoolTest(AstTable[Node].Right);  { condition }
  If AstTable[Node].Tok = KW_UNTIL Then
    EmitLine('jz ' + TopLbl)          { do-until : reboucle si faux }
  Else
    EmitLine('jnz ' + TopLbl);        { do-while : reboucle si vrai }
  EmitLabel(EndLbl);
  PopLoop;
End;

{ Codegen NK_FOR_C : for-INIT-COND-INCR-BODY }
{ Left=init (0=vide), Right=cond (0=vide), Third=incr (0=vide) }
{ FirstChild=corps }
Procedure CodegenForC(Node: Integer);
Var
  LabelN:  Integer;
  TopLbl:  String;
  ContLbl: String;
  EndLbl:  String;
Begin
  Inc(PLLCount);
  LabelN  := PLLCount;
  TopLbl  := MakePLLLabel('LOOP', LabelN, 'TOP');
  ContLbl := MakePLLLabel('LOOP', LabelN, 'CONT');
  EndLbl  := MakePLLLabel('LOOP', LabelN, 'END');
  PushLoop(LabelN);
  EmitComment('for (;;) ligne ' + NumToStr(AstTable[Node].Line));
  If AstTable[Node].Left <> 0 Then
    CodegenNode(AstTable[Node].Left);   { initialisation }
  EmitLabel(TopLbl);
  If AstTable[Node].Right <> 0 Then Begin
    EmitBoolTest(AstTable[Node].Right); { condition }
    EmitLine('jz ' + EndLbl);
  End;
  CodegenNode(AstTable[Node].FirstChild); { corps }
  EmitLabel(ContLbl);
  If AstTable[Node].Third <> 0 Then
    CodegenNode(AstTable[Node].Third);  { increment }
  EmitLine('jmp ' + TopLbl);
  EmitLabel(EndLbl);
  PopLoop;
End;

{ Codegen NK_FOREACH : foreach var LIST BODY }
{ Left=var (0=dollar-underscore), Right=liste, FirstChild=corps }
{ Iteration par index sur tableau temporaire }
Procedure CodegenForeach(Node: Integer);
Var
  LabelN:  Integer;
  TopLbl:  String;
  ContLbl: String;
  EndLbl:  String;
Begin
  Inc(PLLCount);
  LabelN  := PLLCount;
  TopLbl  := MakePLLLabel('LOOP', LabelN, 'TOP');
  ContLbl := MakePLLLabel('LOOP', LabelN, 'CONT');
  EndLbl  := MakePLLLabel('LOOP', LabelN, 'END');
  PushLoop(LabelN);
  EmitComment('foreach ligne ' + NumToStr(AstTable[Node].Line));
  { Evaluer la liste dans EAX (ptr tableau) }
  CodegenNode(AstTable[Node].Right);
  { Empiler ptr tableau ; obtenir la longueur }
  EmitLine('push eax');
  EmitLine('push eax');
  EmitLine('call ' + PlRtArrayLen);
  EmitLine('add esp, 4');
  { EAX=longueur ; [esp]=ptr-tableau }
  EmitLine('push eax');
  { [esp+0]=longueur [esp+4]=ptr-tableau }
  EmitLine('push dword 0');
  { [esp+0]=index [esp+4]=longueur [esp+8]=ptr-tableau }
  EmitLabel(TopLbl);
  EmitLine('mov ecx, [esp]');
  EmitLine('cmp ecx, [esp+4]');
  EmitLine('jge ' + EndLbl);
  { Charger l element courant }
  EmitLine('mov eax, [esp+8]');
  EmitLine('push ecx');
  EmitLine('push eax');
  EmitLine('call ' + PlRtArrayGet);
  EmitLine('add esp, 8');
  { EAX = element courant -> assigner a la variable de boucle }
  If AstTable[Node].Left <> 0 Then
    EmitComment('STUB assign loop var node=' + NumToStr(AstTable[Node].Left))
  Else
    EmitComment('STUB assign $_');
  CodegenNode(AstTable[Node].FirstChild);  { corps }
  EmitLabel(ContLbl);
  EmitLine('inc dword [esp]');
  EmitLine('jmp ' + TopLbl);
  EmitLabel(EndLbl);
  EmitLine('add esp, 12');   { libere index + longueur + ptr-tableau }
  PopLoop;
End;

{ Codegen NK_LAST / NK_NEXT / NK_REDO }
{ Text=label nomme (vide si boucle courante) }
Procedure CodegenLoopCtrl(Node: Integer);
Var
  LN:     Integer;
  Target: String;
Begin
  If AstTable[Node].Text <> '' Then Begin
    { saut vers label de boucle nomme (STUB) }
    EmitComment('STUB ' + KeywordName(AstTable[Node].Tok) +
                ' vers label ' + AstTable[Node].Text);
    Exit;
  End;
  LN := CurrentLoop;
  If LN = 0 Then Begin
    EmitComment('ERREUR : ' + KeywordName(AstTable[Node].Tok) + ' hors boucle');
    Exit;
  End;
  Case AstTable[Node].Kind Of
    NK_LAST: Target := MakePLLLabel('LOOP', LN, 'END');
    NK_NEXT: Target := MakePLLLabel('LOOP', LN, 'CONT');
    NK_REDO: Target := MakePLLLabel('LOOP', LN, 'TOP');
    Else Target := '';
  End;
  If Target <> '' Then Begin
    EmitComment(KeywordName(AstTable[Node].Tok) + ' -> ' + Target);
    EmitLine('jmp ' + Target);
  End;
End;

{ ============================================================ }
{ TODO 15 : Structures de controle : IF / UNLESS / ternaire    }
{ ============================================================ }

{ Convertit un entier en chaine (sans espaces) }
Function NumToStr(N: Integer): String;
Var S: String;
Begin
  Str(N, S);
  NumToStr := S;
End;

{ Genere un label de saut interne  _PLL_<Pfx>_<N>_<Suf>       }
{ Ex: MakePLLLabel('IF',1,'ELSE') -> '_PLL_IF_1_ELSE'          }
Function MakePLLLabel(Pfx: String; N: Integer; Suf: String): String;
Begin
  MakePLLLabel := '_PLL_' + Pfx + '_' + NumToStr(N) + '_' + Suf;
End;

{ Emet une instruction ASM (indentee d'une tabulation) }
Procedure EmitLine(S: String);
Begin
  If AsmOutOpen Then WriteLn(AsmOut, #9 + S)
  Else WriteLn(#9 + S);
End;

{ Emet un label ASM (non indente, sans espace) }
Procedure EmitLabel(L: String);
Begin
  If AsmOutOpen Then WriteLn(AsmOut, L + ':')
  Else WriteLn(L + ':');
End;

{ Emet une ligne de commentaire ASM }
Procedure EmitComment(C: String);
Begin
  If AsmOutOpen Then WriteLn(AsmOut, #9 + '; ' + C)
  Else WriteLn(#9 + '; ' + C);
End;

{ PlRtToBool est deja declare dans TODO 04 }
{ Nom runtime pour test defined }
Function PlRtIsDefined: String; Begin PlRtIsDefined := '_PLRT_is_defined'; End;

{ --- Declarations locales pour appels croise dans TODO 15 --- }
Procedure CodegenIf(Node: Integer);          Forward;
Procedure CodegenTernary(Node: Integer);     Forward;
Procedure CodegenShortCircuit(Node: Integer); Forward;

{ Evalue le noeud condition via CodegenNode -> EAX (valeur Perl),    }
{ puis appelle _PLRT_to_bool ; laisse EAX=0/1 et ZF positionne.      }
Procedure EmitBoolTest(Node: Integer);
Begin
  CodegenNode(Node);
  EmitLine('push eax');
  EmitLine('call ' + PlRtToBool);
  EmitLine('add esp, 4');
  EmitLine('test eax, eax');
End;

{ Codegen pour NK_IF / NK_UNLESS }
{ Left=cond, Right=then-block, Third=else/elsif (0 si absent)         }
Procedure CodegenIf(Node: Integer);
Var
  LabelN:    Integer;
  ElseLabel: String;
  EndLabel:  String;
  ThirdN:    Integer;
Begin
  Inc(PLLCount);
  LabelN    := PLLCount;
  ElseLabel := MakePLLLabel('IF', LabelN, 'ELSE');
  EndLabel  := MakePLLLabel('IF', LabelN, 'END');
  ThirdN    := AstTable[Node].Third;

  EmitComment('if/unless ligne ' + NumToStr(AstTable[Node].Line));
  EmitBoolTest(AstTable[Node].Left);
  If AstTable[Node].Kind = NK_IF Then
    EmitLine('jz ' + ElseLabel)
  Else
    EmitLine('jnz ' + ElseLabel);   { unless : branche si vrai }

  CodegenNode(AstTable[Node].Right);

  If ThirdN <> 0 Then Begin
    EmitLine('jmp ' + EndLabel);
    EmitLabel(ElseLabel);
    { elsif -> ThirdN est NK_IF ; else -> ThirdN est NK_STMT_LIST wrapper }
    If AstTable[ThirdN].Kind = NK_STMT_LIST Then
      CodegenNode(AstTable[ThirdN].Left)   { deplie le wrapper else }
    Else
      CodegenNode(ThirdN);                 { recurse sur elsif }
    EmitLabel(EndLabel);
  End Else Begin
    EmitLabel(ElseLabel);
  End;
End;

{ Codegen pour NK_TERNARY : COND ? VRAI : FAUX }
{ Left=cond, Right=expr-vrai, Third=expr-faux   }
Procedure CodegenTernary(Node: Integer);
Var
  LabelN:    Integer;
  ElseLabel: String;
  EndLabel:  String;
Begin
  Inc(PLLCount);
  LabelN    := PLLCount;
  ElseLabel := MakePLLLabel('IF', LabelN, 'ELSE');
  EndLabel  := MakePLLLabel('IF', LabelN, 'END');

  EmitBoolTest(AstTable[Node].Left);
  EmitLine('jz ' + ElseLabel);
  CodegenNode(AstTable[Node].Right);
  EmitLine('jmp ' + EndLabel);
  EmitLabel(ElseLabel);
  CodegenNode(AstTable[Node].Third);
  EmitLabel(EndLabel);
End;

{ Codegen pour operateurs court-circuit : && || // and or         }
{ Preserve la valeur gauche dans EAX si elle est la valeur finale }
Procedure CodegenShortCircuit(Node: Integer);
Var
  LabelN:  Integer;
  EndLabel: String;
  Op:      Integer;
Begin
  Inc(PLLCount);
  LabelN   := PLLCount;
  EndLabel := MakePLLLabel('IF', LabelN, 'END');
  Op := AstTable[Node].Tok;

  CodegenNode(AstTable[Node].Left);

  If (Op = TOK_ANDAND) Or (Op = KW_AND) Then Begin
    { && / and : si gauche faux -> retourner gauche ; sinon -> droite }
    EmitLine('push eax');
    EmitLine('push eax');
    EmitLine('call ' + PlRtToBool);
    EmitLine('add esp, 4');
    EmitLine('test eax, eax');
    EmitLine('pop eax');
    EmitLine('jz ' + EndLabel);
    CodegenNode(AstTable[Node].Right);
    EmitLabel(EndLabel);
  End Else If (Op = TOK_OROR) Or (Op = KW_OR) Then Begin
    { || / or : si gauche vrai -> retourner gauche ; sinon -> droite }
    EmitLine('push eax');
    EmitLine('push eax');
    EmitLine('call ' + PlRtToBool);
    EmitLine('add esp, 4');
    EmitLine('test eax, eax');
    EmitLine('pop eax');
    EmitLine('jnz ' + EndLabel);
    CodegenNode(AstTable[Node].Right);
    EmitLabel(EndLabel);
  End Else Begin
    { // defini-ou : si gauche est defini -> retourner gauche ; sinon -> droite }
    EmitLine('push eax');
    EmitLine('push eax');
    EmitLine('call ' + PlRtIsDefined);
    EmitLine('add esp, 4');
    EmitLine('test eax, eax');
    EmitLine('pop eax');
    EmitLine('jnz ' + EndLabel);
    CodegenNode(AstTable[Node].Right);
    EmitLabel(EndLabel);
  End;
End;

{ Generateur de code principal : dispatche selon le type de noeud AST }
{ TODO 15 : NK_STMT_LIST, NK_IF, NK_UNLESS, NK_TERNARY, NK_BINARY &&||// }
{ TODO 16+ : boucles, sous-routines, expressions, etc.                    }
Procedure CodegenNode(Node: Integer);
Var C: Integer;
Begin
  If Node = 0 Then Exit;
  Case AstTable[Node].Kind Of
    NK_NONE:   ;
    NK_EMPTY:  ;

    NK_STMT_LIST: Begin
      C := AstTable[Node].FirstChild;
      While C <> 0 Do Begin
        CodegenNode(C);
        C := AstTable[C].NextSibling;
      End;
    End;

    NK_IF, NK_UNLESS: CodegenIf(Node);

    NK_TERNARY: CodegenTernary(Node);

    NK_WHILE, NK_UNTIL: CodegenWhile(Node);

    NK_DO_WHILE: CodegenDoWhile(Node);

    NK_FOR_C: CodegenForC(Node);

    NK_FOREACH: CodegenForeach(Node);

    NK_LAST, NK_NEXT, NK_REDO: CodegenLoopCtrl(Node);

    NK_LITERAL: CodegenLiteral(Node);

    NK_INTERP:
      EmitComment('STUB interp string ligne ' + NumToStr(AstTable[Node].Line));

    NK_DEREF: CodegenDeref(Node);

    NK_UNARY: Begin
      If AstTable[Node].Tok = Ord('\') Then
        CodegenRefOp(Node)
      Else
        CodegenUnaryArith(Node);
    End;

    NK_ARRAY_LIT: Begin
      If AstTable[Node].Tok = Ord('[') Then
        CodegenAnonArray(Node)
      Else
        EmitComment('STUB array lit ligne ' + NumToStr(AstTable[Node].Line));
    End;

    NK_HASH_LIT: Begin
      If AstTable[Node].Tok = Ord('{') Then
        CodegenAnonHash(Node)
      Else
        EmitComment('STUB hash lit ligne ' + NumToStr(AstTable[Node].Line));
    End;

    NK_BINARY: Begin
      If (AstTable[Node].Tok = TOK_ANDAND) Or
         (AstTable[Node].Tok = TOK_OROR)   Or
         (AstTable[Node].Tok = TOK_DEFOR)  Or
         (AstTable[Node].Tok = KW_AND)     Or
         (AstTable[Node].Tok = KW_OR) Then
        CodegenShortCircuit(Node)
      Else
        CodegenBinaryOp(Node);
    End;

    NK_CALL: Begin
      If (AstTable[Node].Tok = KW_ABS)      Or
         (AstTable[Node].Tok = KW_INT_FUNC) Or
         (AstTable[Node].Tok = KW_SQRT)     Or
         (AstTable[Node].Tok = KW_EXP)      Or
         (AstTable[Node].Tok = KW_LOG)      Or
         (AstTable[Node].Tok = KW_SIN)      Or
         (AstTable[Node].Tok = KW_COS)      Or
         (AstTable[Node].Tok = KW_ATAN2)    Or
         (AstTable[Node].Tok = KW_HEX)      Or
         (AstTable[Node].Tok = KW_OCT)      Or
         (AstTable[Node].Tok = KW_RAND) Then
        CodegenMathCall(Node)
      Else
        CodegenBuiltinCall(Node);
    End;

    NK_ASSIGN:
      CodegenAssign(Node);

    NK_SUB_DEF, NK_ANON_SUB:
      CodegenSubDef(Node);

    NK_INDEX:
      CodegenIndex(Node);

    NK_SLICE:
      CodegenSlice(Node);

    NK_VAR:
      CodegenVar(Node);

    NK_USE:
      CodegenPragma(Node);

    NK_PACKAGE:
      EmitComment('; package ' + AstTable[Node].Text);

    NK_BEGIN_HOOK: Begin
      EmitComment('; BEGIN block');
      CodegenNode(AstTable[Node].Left);
    End;

    NK_END_HOOK:
      EmitComment('; END block (execution differee a la sortie)');

    Else
      EmitComment('STUB node kind=' + NumToStr(AstTable[Node].Kind) +
                  ' ligne ' + NumToStr(AstTable[Node].Line));
  End;
End;

{ ============================================================ }
{ TODO 14 : Substitution et translitteration s///, tr///       }
{ ============================================================ }

{ Etend les plages de caracteres dans les listes tr///          }
{ 'a-z' -> 'abcdefghijklmnopqrstuvwxyz', '\n' -> #10, etc.    }
Function ExpandTransList(S: String): String;
Var
  I:       Integer;
  Lo, Hi, C: Char;
  R:       String;
Begin
  R := '';
  I := 1;
  While I <= Length(S) Do Begin
    If (I + 2 <= Length(S)) And (S[I+1] = '-') And
       (Ord(S[I+2]) >= Ord(S[I])) Then Begin
      Lo := S[I]; Hi := S[I+2];
      C  := Lo;
      While C <= Hi Do Begin
        If Length(R) < 255 Then R := R + C;
        If C = Hi Then Break;
        C := Chr(Ord(C) + 1);
      End;
      Inc(I, 3);
    End Else If (S[I] = '\') And (I < Length(S)) Then Begin
      Inc(I);
      Case S[I] Of
        'n': If Length(R) < 255 Then R := R + #10;
        't': If Length(R) < 255 Then R := R + #9;
        'r': If Length(R) < 255 Then R := R + #13;
        '\': If Length(R) < 255 Then R := R + '\';
        Else If Length(R) < 255 Then R := R + S[I];
      End;
      Inc(I);
    End Else Begin
      If Length(R) < 255 Then R := R + S[I];
      Inc(I);
    End;
  End;
  ExpandTransList := R;
End;

{ Traite les echappements et ajoute les hints '$S'/'@A' pour          }
{ l'interpolation dans le remplacement s///                            }
{ $var -> $Svar,  $1 -> $S1,  @arr -> @Aarr,  \n -> #10              }
Function ProcessSubstRepl(S: String): String;
Var
  I: Integer;
  C: Char;
  R: String;
Begin
  R := '';
  I := 1;
  While I <= Length(S) Do Begin
    C := S[I];
    If (C = '\') And (I < Length(S)) Then Begin
      Inc(I);
      Case S[I] Of
        'n': If Length(R) < 255 Then R := R + #10;
        't': If Length(R) < 255 Then R := R + #9;
        'r': If Length(R) < 255 Then R := R + #13;
        'f': If Length(R) < 255 Then R := R + #12;
        'a': If Length(R) < 255 Then R := R + #7;
        'e': If Length(R) < 255 Then R := R + #27;
        '\': If Length(R) < 255 Then R := R + '\';
        '$': If Length(R) < 255 Then R := R + '$';
        '@': If Length(R) < 255 Then R := R + '@';
        Else If Length(R) < 254 Then R := R + '\' + S[I];
      End;
      Inc(I);
    End Else If (C = '$') And (I < Length(S)) And
                (IsAlpha(S[I+1]) Or IsDigit(S[I+1])) Then Begin
      { variable scalaire ($var) ou reference de capture ($1, $2...) }
      If Length(R) < 254 Then R := R + '$S';
      Inc(I);
      While (I <= Length(S)) And IsIdentChar(S[I]) Do Begin
        If Length(R) < 255 Then R := R + S[I];
        Inc(I);
      End;
    End Else If (C = '$') And (I < Length(S)) And (S[I+1] = '{') Then Begin
      { forme dollar-brace: varname brace }
      If Length(R) < 254 Then R := R + '$S';
      Inc(I, 2);
      While (I <= Length(S)) And (S[I] <> '}') Do Begin
        If Length(R) < 255 Then R := R + S[I];
        Inc(I);
      End;
      If I <= Length(S) Then Inc(I);
    End Else If (C = '@') And (I < Length(S)) And IsAlpha(S[I+1]) Then Begin
      { tableau interpole: @arr }
      If Length(R) < 254 Then R := R + '@A';
      Inc(I);
      While (I <= Length(S)) And IsIdentChar(S[I]) Do Begin
        If Length(R) < 255 Then R := R + S[I];
        Inc(I);
      End;
    End Else Begin
      { caractere ordinaire ou $ non suivi d'un identifiant }
      If Length(R) < 255 Then R := R + C;
      Inc(I);
    End;
  End;
  ProcessSubstRepl := R;
End;

{ Noms des fonctions runtime supplementaires pour s/// et tr/// }
Function PlRtSubstInterp: String; Begin PlRtSubstInterp := '_PLRT_subst_interp'; End;
Function PlRtTransExpand:  String; Begin PlRtTransExpand  := '_PLRT_tr_expand';   End;
Function PlRtTransCount:   String; Begin PlRtTransCount   := '_PLRT_tr_count';    End;
Function PlRtTransBuild:   String; Begin PlRtTransBuild   := '_PLRT_tr_build';    End;

{ Genere le nom du label _PLK_N pour une chaine de remplacement s/// }
Function MakeSubstRplLabel(PLKIdx: Integer): String;
Var S: String;
Begin
  Str(PLKIdx, S);
  MakeSubstRplLabel := '_PLK_' + S;
End;

{ Genere le nom du label _PLRE_N pour un pattern compile de s/// }
Function MakeSubstPatLabel(PLREIdx: Integer): String;
Var S: String;
Begin
  Str(PLREIdx, S);
  MakeSubstPatLabel := '_PLRE_' + S;
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
    LexInit(Opt.SrcFile);
    DumpTokens;
    Halt(EXIT_OK);
  End;
  WriteLn('PERLCW32: compilation de ', Opt.SrcFile);
  LexInit(Opt.SrcFile);
  AsmRoot    := ParseProgram;
  AsmFrameSz := CurrentSubLocalSize;
  If ParseErrors > 0 Then Begin
    WriteLn('PERLCW32: ', ParseErrors, ' erreur(s) de syntaxe, abandon');
    Halt(EXIT_ERROR);
  End;
  { Sortie .ASM lisible (optionnelle) }
  If Opt.EmitAsm Then Begin
    Assign(AsmOut, Opt.OutFile + '.asm');
    Rewrite(AsmOut);
    AsmOutOpen := True;
    EmitAsmHeader(AsmFrameSz);
    CodegenPrologue;
    CodegenNode(AsmRoot);
    EmitLine('xor eax, eax');
    EmitLine('push eax');
    EmitLine('call _ExitProcess@4');
    EmitAsmFooter;
    Close(AsmOut);
    AsmOutOpen := False;
    WriteLn('PERLCW32: asm -> ', Opt.OutFile + '.asm');
  End;
  { Backend binaire (sortie principale) }
  BinInit;
  BinCodegenProgram(AsmRoot, AsmFrameSz);
  If Opt.EmitObj Then Begin
    WriteCOFF(Opt.OutFile);
    WriteLn('PERLCW32: obj -> ', Opt.OutFile);
  End Else Begin
    WritePE(Opt.OutFile);
    WriteLn('PERLCW32: exe -> ', Opt.OutFile);
  End;
  Halt(EXIT_OK);
END.
