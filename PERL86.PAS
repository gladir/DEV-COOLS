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

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  PERL86_VERSION = '1.0';
  PERL86_DATE    = '2026-03-05';

  { Limites des tableaux internes }
  MAX_SYM       = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_LABEL     = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
  MAX_SCOPE     = {$IFDEF FPC}64{$ELSE}32{$ENDIF};
  MAX_DATA      = {$IFDEF FPC}512{$ELSE}128{$ENDIF};
  MAX_TYPE      = {$IFDEF FPC}32{$ELSE}16{$ENDIF};
  MAX_PARAM     = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_LOOP_NEST = {$IFDEF FPC}16{$ELSE}8{$ENDIF};
  MAX_ERRORS    = {$IFDEF FPC}30{$ELSE}3{$ENDIF};
  MAX_STR       = {$IFDEF FPC}255{$ELSE}80{$ENDIF};
  MAX_INCLUDE   = {$IFDEF FPC}32{$ELSE}8{$ENDIF};
  MAX_PKG       = {$IFDEF FPC}16{$ELSE}4{$ENDIF};
  MAX_ARR_ELEMS  = 32;   { elements max par tableau @arr local (fixe) }
  MAX_HASH_PAIRS  = 16;   { paires cle/valeur max par %hash local       }
  MAX_HASH_KEYS   = 512;  { entrees totales dans la table de hachage    }
  STACK_SIZE      = 1024;

  { Prefixes de nommage ASM }
  PR_VAR_PFX  = '_PRV_';    { variable scalaire/tableau/hash }
  PR_FN_PFX   = '_PRF_';    { sous-routine sub              }
  PR_STR_PFX  = '_PRK_';    { constante chaine              }
  PR_RT_PFX   = '_PRRT_';   { routine runtime               }
  PR_LBL_PFX  = '_PRL_';    { label de saut interne         }
  PR_CAP_PFX  = '_PRCAP_';  { capture regexp $1/$2/...      }

  { Codes de sortie }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Contexte d''evaluation Perl }
  CTX_SCALAR = 0;  { scalaire : un seul entier/pointeur }
  CTX_LIST   = 1;  { liste   : plusieurs valeurs        }
  CTX_BOOL   = 2;  { booleen : test vrai/faux           }
  CTX_VOID   = 3;  { void   : valeur ignoree            }

  { Indices de types primitifs Perl }
  TY_IDX_SCALAR  = 0;   { scalaire entier/chaine unifie }
  TY_IDX_ARRAY   = 1;   { tableau @arr                  }
  TY_IDX_HASH    = 2;   { hash %h                       }
  TY_IDX_REF     = 3;   { reference \$v                 }
  TY_IDX_CODE    = 4;   { reference de code \&sub       }
  TY_IDX_UNDEF   = 5;   { undef                         }
  TY_IDX_MIXED   = 6;   { contexte indetermine          }
  TY_PRIM_COUNT  = 7;
  TY_UNKNOWN     = -1;

{ ============================================================
  TYPES
  ============================================================ }
Type
  TString = String[MAX_STR];

  { ---- Tokens Perl ---------------------------------------- }
  TTokenKind = (
    TK_EOF,         { fin de fichier                       }
    TK_IDENT,       { identificateur (mot-cle ou bare-word) }
    TK_KEYWORD,     { mot-cle Perl reconnu                  }
    TK_SCALAR,      { variable scalaire $nom               }
    TK_ARRAY_SIG,   { variable tableau @nom                }
    TK_HASH_SIG,    { variable hash %nom                   }
    TK_INTEGER,     { litteral entier                      }
    TK_FLOAT,       { litteral flottant                    }
    TK_STRING,      { litteral chaine (simple- ou double-q) }
    TK_HEREDOC,     { heredoc <<LABEL                      }
    TK_REGEXP,      { expression reguliere /pat/flags      }
    TK_FILEHANDLE,  { descripteur STDOUT STDERR STDIN <FH> }
    TK_OP,          { operateur                            }
    TK_PUNCT        { ponctuation () [] ; , ->              }
  );

  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;       { valeur textuelle brute             }
    IntVal   : LongInt;       { valeur entiere (TK_INTEGER)        }
    FloatVal : Real;          { valeur flottante (TK_FLOAT)        }
    Line     : Integer;       { ligne source (1-base)              }
    Col      : Integer;       { colonne source (1-base)            }
  End;

  { ---- Options de compilation ----------------------------- }
  TOptions = Record
    SrcFile   : TString;   { script source (.pl)                  }
    OutFile   : TString;   { fichier assembleur de sortie (.asm)  }
    Verbose   : Boolean;   { -v : banniere et statistiques        }
    DebugTok  : Boolean;   { -d : affichage de chaque token       }
    Strict    : Boolean;   { -s : equivalence use strict          }
    Warnings  : Boolean;   { -w : equivalence use warnings        }
  End;

  { ---- Categories de symboles ----------------------------- }
  TSymCat = (
    SC_SCALAR,       { my/our $var scalaire              }
    SC_ARRAY_VAR,    { my/our @arr tableau                }
    SC_HASH_VAR,     { my/our %h hash                    }
    SC_PARAM,        { parametre de sous-routine          }
    SC_FN,           { sous-routine (sub)                 }
    SC_PKG,          { package / namespace                }
    SC_CONST,        { use constant NOM => val            }
    SC_FILEHANDLE    { filehandle open(my $fh, ...)       }
  );

  TSymRec = Record
    Name        : TString;   { nom Perl sans sigil             }
    SigilName   : TString;   { nom avec sigil ($foo @foo %foo) }
    MangledName : TString;   { _PRV_foo / _PRF_foo             }
    Cat         : TSymCat;
    TypeIdx     : Integer;   { indice dans TypeTab             }
    ScopeLevel  : Integer;
    Offset      : Integer;   { [BP-n] pour locaux, DATA sinon  }
    IsMy        : Boolean;   { lexical my                      }
    IsOur       : Boolean;   { global our                      }
    IsLocal     : Boolean;   { dynamique local                 }
    IsRef       : Boolean;   { passe par reference \$p         }
    DeclLine    : Integer;
  End;

  { ---- Types internes ------------------------------------- }
  TTypeKind = (
    TKD_SCALAR,
    TKD_ARRAY,
    TKD_HASH,
    TKD_REF,
    TKD_CODE,
    TKD_UNDEF,
    TKD_MIXED,
    TKD_UNKNOWN
  );

  TTypeRec = Record
    Name    : TString;
    Kind    : TTypeKind;
    Size    : Integer;   { taille en octets : scalar=2, ref=2 }
    ElemIdx : Integer;   { type des elements (TKD_ARRAY)      }
  End;

  { ---- Valeurs d'expression ------------------------------- }
  TExprKind = (
    EK_NONE,   { void / pas de valeur  }
    EK_IMM,    { immediat dans ImmVal  }
    EK_AX,     { valeur dans AX        }
    EK_DXAX,   { valeur longue DX:AX   }
    EK_MEM     { adresse [BP+Offset] ou [_PRV_x] }
  );

  TExprVal = Record
    Kind    : TExprKind;
    ImmVal  : LongInt;
    TypeIdx : Integer;
    Offset  : Integer;
  End;

  { ---- Segment de donnees --------------------------------- }
  TDataKind = (DK_WORD, DK_BYTE, DK_STR, DK_ARRAY_BLK);

  TDataRec = Record
    LblName   : TString;
    Kind      : TDataKind;
    IntVal    : LongInt;
    StrVal    : TString;
    ElemCount : Integer;   { DK_ARRAY_BLK : nombre d'elements }
  End;

  { ---- Table de hachage (compile-time) ------------------- }
  { Pour chaque paire cle/valeur d'un %hash local, on stocke  }
  { l'indice du hash dans SymTab, la cle Perl (string) et le  }
  { numero de slot (0..MAX_HASH_PAIRS-1).                     }
  THashKeyRec = Record
    HashSym : Integer;   { indice SymTab du %hash              }
    KeyStr  : TString;   { cle Perl (chaine ou bareword)       }
    SlotIdx : Integer;   { slot 0..MAX_HASH_PAIRS-1            }
    KeyLbl  : TString;   { label ASM de la cle en DATA         }
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts : TOptions;

  { Compteurs globaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;
  TotalSyms  : Integer;

  { Valeur fictive pour ignorer un retour TExprVal }
  GExprDummy : TExprVal;

  { Lexeur }
  LexSrcF   : Text;
  LexLine   : String;
  LexLineNo : Integer;
  LexColNo  : Integer;
  LexEOF    : Boolean;
  LexOpened : Boolean;
  CurToken  : TToken;

  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymRec;
  SymCount  : Integer;
  ScopeStack: Array[0..MAX_SCOPE - 1] Of Integer;
  ScopeTop  : Integer;
  CurScope  : Integer;
  LabelSeq  : Integer;

  { Table des types }
  TypeTab   : Array[0..MAX_TYPE - 1] Of TTypeRec;
  TypeCount : Integer;

  { Emetteur ASM }
  OutF         : Text;
  OutFOpen     : Boolean;
  CurFrameSize : Integer;   { taille du cadre local courant        }
  CurFnDepth   : Integer;   { 0 = global, >0 = dans une sub       }
  CurFnRetLbl  : TString;   { label epilogue de la sub courante    }
  CurFnName    : TString;   { nom de la sub courante               }
  LoopTop      : Integer;
  LoopBreakLbl : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopContLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;
  LoopRedoLbl  : Array[0..MAX_LOOP_NEST - 1] Of TString;

  { Segment de donnees statiques }
  DataTab   : Array[0..MAX_DATA - 1] Of TDataRec;
  DataCount : Integer;

  { Table de hachage compile-time pour %hash locaux }
  HashKeyTab   : Array[0..MAX_HASH_KEYS - 1] Of THashKeyRec;
  HashKeyCount : Integer;

  { Etat general }
  RuntimeEmitted : Boolean;

  { Garde d'inclusion (require_once / use) }
  IncludeTab   : Array[0..MAX_INCLUDE - 1] Of TString;
  IncludeCount : Integer;

  { Package courant }
  CurPackage : TString;   { 'main' par defaut }

  { Flag : le mot-cle courant a deja ete consomme avant l''appel }
  GKwConsumed : Boolean;
  { TODO 17 : compteur d''args du dernier appel + arg shift @_ }
  GCallArgCount  : Integer;  { nb args du dernier ParseCallArgs }
  CurArgShiftIdx : Integer;  { index prochain shift dans @_ }

{ ============================================================
  FORWARD DECLARATIONS
  ============================================================ }
Procedure LexInit;       Forward;
Procedure LexClose;      Forward;
Procedure EmitOpen;      Forward;
Procedure EmitClose;     Forward;
Procedure EmitDataSeg;   Forward;
Procedure EmitRuntime;   Forward;
Procedure EmitHeader;    Forward;
Procedure ParserAdvance; Forward;
Procedure ParseStmt;     Forward;
Procedure TypeInit;      Forward;
Procedure SymInit;       Forward;
Function  DataAddStr(Const S : TString) : Integer; Forward;
Function  DataAdd(Const ALbl : TString; AKind : TDataKind;
                  AInt : LongInt; Const AStr : TString) : Integer; Forward;
{ TODO 08 }
Procedure EmitDataStr(Const Lbl, S : TString); Forward;
Function  DataAddWord(Const ALbl : TString; AVal : LongInt) : Integer; Forward;
Function  DataAddConst(Const ALbl : TString; AVal : LongInt;
                       Const AStr : TString) : Integer; Forward;
Function  DataFindByLabel(Const ALbl : TString) : Integer; Forward;
{ TODO 09 }
Procedure EmitAllocLocal(Sz : Integer); Forward;
Procedure EmitStoreScalar(Const Lv : TExprVal); Forward;
Function  ExprMakeMem(SymIdx : Integer) : TExprVal; Forward;
Procedure ParseVarDecl; Forward;
{ TODO 10 }
Procedure ParseCallArgs; Forward;
Procedure EmitIncrDecr(Const Lv : TExprVal; IsInc : Boolean; Pre : Boolean;
                       Var Res : TExprVal); Forward;
Procedure ParsePostfixOps(Var Res : TExprVal); Forward;
{ TODO 12 }
Procedure EmitPrintVal(Const BXval : TString; Var E : TExprVal); Forward;
Procedure ParsePrintStmt; Forward;
{ TODO 13 }
Procedure ParseBlock; Forward;
Procedure ParseIfStmt; Forward;
{ TODO 14 }
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString); Forward;
Procedure LoopPop; Forward;
Procedure ParseWhileStmt; Forward;
Procedure ParseForStmt; Forward;
Procedure ParseForeachStmt; Forward;
Procedure ParseDoStmt; Forward;
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal); Forward;
Procedure ExprMakeNone(Var Res : TExprVal); Forward;
Procedure ExprMakeUndef(Var Res : TExprVal); Forward;
Procedure LitEval(Const T : TToken; Var Res : TExprVal); Forward;
{ TODO 15 }
Procedure ParseArrElemAccess(ArrIdx : Integer; Var Res : TExprVal); Forward;
Procedure ParseArrBuiltin(IsStmt : Boolean); Forward;
{ TODO 16 }
Function  HashSlotFind(HashSym : Integer; Const Key : TString) : Integer; Forward;
Function  HashSlotAdd(HashSym : Integer; Const Key : TString;
                      Const KeyLbl : TString) : Integer; Forward;
Procedure ParseHashElemAccess(HashIdx : Integer; Var Res : TExprVal); Forward;
{ TODO 17 }
Procedure ParseSubDecl; Forward;
{ TODO 04 }
Function  BinOpPrec(Const Op : TString) : Integer; Forward;
Function  IsRightAssoc(Const Op : TString) : Boolean; Forward;
Procedure ExprLoad(Var E : TExprVal); Forward;
Procedure ExprEmitBinOp(Const Op : TString;
                         Var Left, Right : TExprVal;
                         Var Res         : TExprVal); Forward;
Procedure ParsePrimary(Var Res : TExprVal); Forward;
Function  CurTokIsInfixOp(Var OpStr : TString) : Boolean; Forward;
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal); Forward;
Procedure ParseExpr(Var Res : TExprVal); Forward;
{ TODO 05 }
Function  SymMangle(Cat : TSymCat; IsMy : Boolean;
                    Const Name, Pkg : TString;
                    SeqN : Integer) : TString; Forward;
Function  SymAdd(Const Name : TString; Sigil : Char; Cat : TSymCat;
                 TypeIdx : Integer;
                 IsMy, IsOur, IsLocal : Boolean) : Integer; Forward;
Function  SymFind(Const Name : TString; Sigil : Char) : Integer; Forward;
Function  SymFindCat(Const Name : TString; Cat : TSymCat) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Procedure SymWarn(Const Msg : TString); Forward;
Procedure SymError(Const Msg : TString); Forward;
{ TODO 06 }
Function  TypeSizeof(TypeIdx : Integer) : Integer; Forward;
Function  TypeMangle(TypeIdx : Integer) : TString; Forward;
Function  TypeKindName(TypeIdx : Integer) : TString; Forward;
Function  TypeIsCompatible(SrcIdx, DstIdx : Integer) : Boolean; Forward;
Function  ExprIsBoolFalse(Const E : TExprVal) : Boolean; Forward;
{ TODO 07 }
Function  LabelGen(Const Prefix : TString) : TString; Forward;
Procedure EmitRaw(Const S : TString); Forward;
Procedure EmitBlankLine; Forward;
Procedure EmitComment(Const S : TString); Forward;
Procedure EmitLabel(Const Name : TString); Forward;
Procedure EmitInstr(Const Mnem, Ops : TString); Forward;
Procedure EmitInstr1(Const Mnem : TString); Forward;

{ ============================================================
  TODO 01 - INFRASTRUCTURE ET OPTIONS
  ============================================================ }

{ ---- Erreur fatale ---------------------------------------- }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('PERL86: ERREUR FATALE - ', Msg);
  Halt(EXIT_ERROR);
End;

{ ---- Aide en ligne ---------------------------------------- }
Procedure ShowHelp;
Begin
  WriteLn('Usage: PERL86 <source.pl> [sortie.asm] [-v] [-d] [-s] [-w]');
  WriteLn('  -v   mode verbeux (banniere + statistiques)');
  WriteLn('  -d   debug tokens (affiche chaque token)');
  WriteLn('  -s   use strict (toute variable doit etre declaree)');
  WriteLn('  -w   use warnings (avertissements supplementaires)');
  WriteLn('  -h   cette aide');
  WriteLn('');
  WriteLn('Le fichier source doit avoir l''extension .pl');
  WriteLn('Le fichier de sortie defaut remplace .pl par .asm');
  Halt(EXIT_OK);
End;

{ ---- Initialisation des options --------------------------- }
Procedure InitOptions;
Begin
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugTok := False;
  Opts.Strict   := False;
  Opts.Warnings := False;
End;

{ ---- Construction du nom de sortie par defaut ------------- }
Procedure BuildOutName;
Var
  Base : TString;
  I    : Integer;
Begin
  Base := Opts.SrcFile;
  { Retrancher l'extension .pl ou .PL }
  For I := Length(Base) DownTo 1 Do
  Begin
    If Base[I] = '.' Then
    Begin
      If (Copy(Base, I, 3) = '.pl') Or (Copy(Base, I, 3) = '.PL') Then
        Base := Copy(Base, 1, I - 1);
      Break;
    End;
  End;
  Opts.OutFile := Base + '.asm';
End;

{ ---- Analyse des arguments de la ligne de commande -------- }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then
    ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-d') Or (Arg = '--debug') Then
      Opts.DebugTok := True
    Else If (Arg = '-s') Or (Arg = '--strict') Then
      Opts.Strict := True
    Else If (Arg = '-w') Or (Arg = '--warnings') Then
      Opts.Warnings := True
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
    Begin
      WriteLn('PERL86: option inconnue : ', Arg);
      Halt(EXIT_USAGE);
    End
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
    Begin
      WriteLn('PERL86: argument inattendu : ', Arg);
      Halt(EXIT_USAGE);
    End;
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('PERL86: aucun fichier source specifie.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then
    BuildOutName;
End;

{ ---- Banniere --------------------------------------------- }
Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('================================================');
  WriteLn(' PERL86 v', PERL86_VERSION, ' (', PERL86_DATE, ')');
  WriteLn(' Compilateur Perl -> assembleur 8086 / DOS');
  WriteLn('================================================');
  WriteLn(' Source  : ', Opts.SrcFile);
  WriteLn(' Sortie  : ', Opts.OutFile);
  If Opts.Strict   Then WriteLn(' Mode    : use strict');
  If Opts.Warnings Then WriteLn(' Mode    : use warnings');
  WriteLn('------------------------------------------------');
End;

{ ---- Statistiques finales --------------------------------- }
Procedure ShowStats;
Begin
  WriteLn('------------------------------------------------');
  WriteLn(' Lignes   : ', TotalLines);
  WriteLn(' Symboles : ', SymCount);
  WriteLn(' Erreurs  : ', ErrorCount);
  WriteLn(' Avert.   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn(' Resultat : OK -> ', Opts.OutFile)
  Else
    WriteLn(' Resultat : ECHEC (', ErrorCount, ' erreur(s))');
  WriteLn('================================================');
End;

{ ---- Nettoyage des ressources ----------------------------- }
Procedure Cleanup;
Begin
  LexClose;
  EmitClose;
End;

{ ============================================================
  STUBS DES TODOS 03-25 (seront implementes dans les TODOs suivants)
  ============================================================ }

Procedure TypeInit;
Var
  I : Integer;
Begin
  TypeCount := 0;
  For I := 0 To MAX_TYPE - 1 Do
  Begin
    TypeTab[I].Name    := '';
    TypeTab[I].Kind    := TKD_UNKNOWN;
    TypeTab[I].Size    := 0;
    TypeTab[I].ElemIdx := TY_UNKNOWN;
  End;
  { TY_IDX_SCALAR = 0 : scalaire unifie int/float/str, taille 2 octets (mot) }
  TypeTab[TY_IDX_SCALAR].Name    := 'scalar';
  TypeTab[TY_IDX_SCALAR].Kind    := TKD_SCALAR;
  TypeTab[TY_IDX_SCALAR].Size    := 2;
  TypeTab[TY_IDX_SCALAR].ElemIdx := TY_UNKNOWN;
  { TY_IDX_ARRAY = 1 : tableau @arr, represente comme pointeur (2 octets) }
  TypeTab[TY_IDX_ARRAY].Name    := 'array';
  TypeTab[TY_IDX_ARRAY].Kind    := TKD_ARRAY;
  TypeTab[TY_IDX_ARRAY].Size    := 2;
  TypeTab[TY_IDX_ARRAY].ElemIdx := TY_IDX_SCALAR;
  { TY_IDX_HASH = 2 : hash %h, represente comme pointeur (2 octets) }
  TypeTab[TY_IDX_HASH].Name    := 'hash';
  TypeTab[TY_IDX_HASH].Kind    := TKD_HASH;
  TypeTab[TY_IDX_HASH].Size    := 2;
  TypeTab[TY_IDX_HASH].ElemIdx := TY_IDX_SCALAR;
  { TY_IDX_REF = 3 : reference \$v ou \@arr, taille 2 octets (pointeur) }
  TypeTab[TY_IDX_REF].Name    := 'ref';
  TypeTab[TY_IDX_REF].Kind    := TKD_REF;
  TypeTab[TY_IDX_REF].Size    := 2;
  TypeTab[TY_IDX_REF].ElemIdx := TY_UNKNOWN;
  { TY_IDX_CODE = 4 : reference de code \&sub, taille 2 octets }
  TypeTab[TY_IDX_CODE].Name    := 'code';
  TypeTab[TY_IDX_CODE].Kind    := TKD_CODE;
  TypeTab[TY_IDX_CODE].Size    := 2;
  TypeTab[TY_IDX_CODE].ElemIdx := TY_UNKNOWN;
  { TY_IDX_UNDEF = 5 : undef, taille 2 octets (valeur 0) }
  TypeTab[TY_IDX_UNDEF].Name    := 'undef';
  TypeTab[TY_IDX_UNDEF].Kind    := TKD_UNDEF;
  TypeTab[TY_IDX_UNDEF].Size    := 2;
  TypeTab[TY_IDX_UNDEF].ElemIdx := TY_UNKNOWN;
  { TY_IDX_MIXED = 6 : contexte indetermine (liste heterogene) }
  TypeTab[TY_IDX_MIXED].Name    := 'mixed';
  TypeTab[TY_IDX_MIXED].Kind    := TKD_MIXED;
  TypeTab[TY_IDX_MIXED].Size    := 2;
  TypeTab[TY_IDX_MIXED].ElemIdx := TY_UNKNOWN;
  TypeCount := TY_PRIM_COUNT;  { 7 types primitifs enregistres }
End;

Procedure SymInit;
Var
  I : Integer;
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  LabelSeq     := 0;
  CurFrameSize := 0;
  CurFnDepth   := 0;
  LoopTop      := 0;
  GKwConsumed  := False;
  CurFnRetLbl  := '';
  CurFnName    := '';
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name        := '';
    SymTab[I].SigilName   := '';
    SymTab[I].MangledName := '';
    SymTab[I].Cat         := SC_SCALAR;
    SymTab[I].TypeIdx     := TY_UNKNOWN;
    SymTab[I].ScopeLevel  := 0;
    SymTab[I].Offset      := 0;
    SymTab[I].IsMy        := False;
    SymTab[I].IsOur       := False;
    SymTab[I].IsLocal     := False;
    SymTab[I].IsRef       := False;
    SymTab[I].DeclLine    := 0;
  End;
End;

Procedure EmitOpen;
Begin
  Assign(OutF, Opts.OutFile);
  Rewrite(OutF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier de sortie : ' + Opts.OutFile);
  OutFOpen := True;
  EmitHeader;   { emet le preambule ASM }
End;

Procedure EmitClose;
Begin
  If Not OutFOpen Then Exit;
  { Code de sortie par defaut : exit(0) en cas de chute de fin de script }
  EmitBlankLine;
  EmitComment('Fin du script Perl - sortie implicite code 0');
  EmitInstr('MOV', 'AX, 4C00h');
  EmitInstr('INT', '21h');
  EmitRaw('_PRF_main ENDP');
  EmitBlankLine;
  EmitRaw('_TEXT   ENDS');
  EmitBlankLine;
  EmitDataSeg;   { TODO 08 : segment de donnees }
  EmitBlankLine;
  EmitRaw('        END     _PRF_main');
  Close(OutF);
  OutFOpen := False;
End;

Procedure EmitHeader;
Begin
  EmitComment('Generated by PERL86 v' + PERL86_VERSION + ' - ' + PERL86_DATE);
  EmitComment('Source : ' + Opts.SrcFile);
  EmitBlankLine;
  EmitRaw('        .MODEL  SMALL');
  EmitRaw('        .STACK  1024');
  EmitBlankLine;
  EmitRaw('_TEXT   SEGMENT WORD PUBLIC ''CODE''');
  EmitRaw('        ASSUME  CS:_TEXT, DS:_DATA');
  EmitBlankLine;
  EmitRaw('_PRF_main PROC NEAR');
  EmitInstr('MOV', 'AX, @DATA');
  EmitInstr('MOV', 'DS, AX');
  EmitBlankLine;
End;

Procedure EmitDataSeg;
{ Emet le segment _DATA complet : DW (scalaires our/constantes),           }
{ DB (octets), DB '...',0 (chaines litterales), DW N DUP(0) (tableaux).    }
Var
  I   : Integer;
  Tmp : TString;
Begin
  EmitRaw('_DATA   SEGMENT WORD PUBLIC ''DATA''');
  If DataCount = 0 Then
    EmitRaw('; _PRL_DUMMY  DB  0')  { segment vide : rien a emettre }
  Else
    For I := 0 To DataCount - 1 Do
    Begin
      EmitBlankLine;
      Case DataTab[I].Kind Of
        DK_WORD :
          Begin
            Str(DataTab[I].IntVal, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DW  ' + Tmp);
          End;
        DK_BYTE :
          Begin
            Str(DataTab[I].IntVal And $FF, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DB  ' + Tmp);
          End;
        DK_STR :
          EmitDataStr(DataTab[I].LblName, DataTab[I].StrVal);
        DK_ARRAY_BLK :
          Begin
            Str(DataTab[I].ElemCount, Tmp);
            EmitRaw(DataTab[I].LblName + ':');
            EmitRaw('        DW  ' + Tmp + ' DUP(0)');
          End;
      End;
    End;
  EmitBlankLine;
  EmitRaw('_DATA   ENDS');
End;

Procedure EmitRuntime;
Begin
End;

{ ============================================================
  TODO 17 - ParseSubDecl : declare et compile une sous-routine
  Supporte : sub nom BLOC et sub anonyme dans expression
  Convention : push gauche->droite, callee fait PUSH BP/MOV BP,SP
  var_k depuis @_ = WORD PTR [BP + 4 + (N-1-k)*2]
  ============================================================ }
Procedure ParseSubDecl;
Var
  SubName    : TString;
  SubSeq     : TString;
  LblEnd     : TString;
  LblRet     : TString;
  SaveFrame  : Integer;
  SaveDepth  : Integer;
  SaveRetLbl : TString;
  SaveFnName : TString;
  SaveArgSh  : Integer;
  IsAnon     : Boolean;
  Idx        : Integer;
Begin
  { Consommer 'sub' si encore present }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'sub') Then
    ParserAdvance;
  { Verifier si sub anonyme (pas d''identifiant avant le bloc) }
  IsAnon := Not (CurToken.Kind = TK_IDENT);
  If Not IsAnon Then
  Begin
    SubName := CurToken.Val;
    ParserAdvance;  { consommer le nom }
    { Ignorer le prototype eventuel (...) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
        ParserAdvance;
    End;
    { Enregistrer dans la table des symboles }
    Idx := SymAdd(SubName, '&', SC_FN, TY_IDX_CODE, False, True, False);
  End Else
  Begin
    { Sous-routine anonyme : generer un nom unique }
    Inc(LabelSeq);
    Str(LabelSeq, SubSeq);
    SubName := '_ANON_' + SubSeq;
  End;
  { Generer les labels uniques }
  Inc(LabelSeq);
  Str(LabelSeq, SubSeq);
  LblEnd := '_PRL_SUBEND_' + SubSeq;
  LblRet := '_PRL_SUBRET_' + SubSeq;
  { Sauter le corps de la sous-routine a l''execution }
  EmitInstr('JMP', LblEnd);
  EmitLabel(PR_FN_PFX + SubName);
  EmitInstr1('PUSH BP');
  EmitInstr('MOV', 'BP, SP');
  { Sauver le contexte du compilateur }
  SaveFrame  := CurFrameSize;
  SaveDepth  := CurFnDepth;
  SaveRetLbl := CurFnRetLbl;
  SaveFnName := CurFnName;
  SaveArgSh  := CurArgShiftIdx;
  CurFrameSize   := 0;
  CurFnDepth     := CurFnDepth + 1;
  CurFnRetLbl    := LblRet;
  CurFnName      := SubName;
  CurArgShiftIdx := 0;
  SymEnterScope;
  ParseBlock;
  SymLeaveScope;
  EmitLabel(LblRet);
  EmitInstr('MOV', 'SP, BP');
  EmitInstr1('POP BP');
  EmitInstr1('RET');
  EmitLabel(LblEnd);
  { Restaurer le contexte }
  CurFrameSize   := SaveFrame;
  CurFnDepth     := SaveDepth;
  CurFnRetLbl    := SaveRetLbl;
  CurFnName      := SaveFnName;
  CurArgShiftIdx := SaveArgSh;
  { Pour sous-routine anonyme : charger l''offset dans AX }
  If IsAnon Then
    EmitInstr('MOV', 'AX, OFFSET ' + PR_FN_PFX + SubName);
End;

Procedure ParseStmt;
{ Analyse une instruction Perl et emet le code ASM correspondant.         }
{ Reconnait : my/our/local ; use ; print/say ; if/unless ; expr [MOD] ;   }
Var
  KW                       : TString;
  E                        : TExprVal;
  LblBody, LblCond, LblEnd : TString;
  HasMod                   : Boolean;
  ModKW                    : TString;
  CondE                    : TExprVal;
Begin
  { Ignorer les points-virgules isoles (instructions vides) }
  While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
    ParserAdvance;
  If CurToken.Kind = TK_EOF Then Exit;
  { Mots-cles de declaration et instructions speciales }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    KW := CurToken.Val;
    If (KW = 'my') Or (KW = 'our') Or (KW = 'local') Then
    Begin
      ParseVarDecl;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    { use strict ; use warnings ; use constant ... : ignorer pour l''instant }
    If KW = 'use' Then
    Begin
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
      Exit;
    End;
    { TODO 12 : print / say / printf / warn / die }
    If (KW = 'print') Or (KW = 'say') Or (KW = 'printf') Or
       (KW = 'warn') Or (KW = 'die') Then
    Begin
      ParsePrintStmt;
      Exit;
    End;
    { TODO 13 : if / unless }
    If (KW = 'if') Or (KW = 'unless') Then
    Begin
      ParseIfStmt;
      Exit;
    End;
    { TODO 14 : while / until / foreach / do }
    If (KW = 'while') Or (KW = 'until') Then
    Begin
      ParseWhileStmt;
      Exit;
    End;
    If KW = 'foreach' Then
    Begin
      ParseForeachStmt;
      Exit;
    End;
    If KW = 'for' Then
    Begin
      { Avancer au-dela de 'for' pour detecter le style de boucle }
      ParserAdvance;   { CurToken = token apres 'for' }
      GKwConsumed := True;
      { foreach-alias : for my $var (...) ou for $var (...) }
      If ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my')) Or
          (CurToken.Kind = TK_SCALAR) Then
        ParseForeachStmt
      Else
        ParseForStmt;
      GKwConsumed := False;
      Exit;
    End;
    If KW = 'do' Then
    Begin
      ParseDoStmt;
      Exit;
    End;
    { TODO 14 : last / next / redo }
    If KW = 'last' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopBreakLbl[LoopTop - 1])
      Else
        EmitComment('last: hors d''une boucle (ignore)');
      { eventuel label de boucle (on ignore) }
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    If KW = 'next' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopContLbl[LoopTop - 1])
      Else
        EmitComment('next: hors d''une boucle (ignore)');
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    If KW = 'redo' Then
    Begin
      If LoopTop > 0 Then
        EmitInstr('JMP', LoopRedoLbl[LoopTop - 1])
      Else
        EmitComment('redo: hors d''une boucle (ignore)');
      If CurToken.Kind = TK_IDENT Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
    { TODO 15 : push / pop / shift / unshift / scalar sur @arr }
    If (KW = 'push') Or (KW = 'pop') Or
       (KW = 'shift') Or (KW = 'unshift') Then
    Begin
      ParseArrBuiltin(True);
      Exit;
    End;
    { TODO 17 : sub declaration }
    If KW = 'sub' Then
    Begin
      ParseSubDecl;
      Exit;
    End;
    { TODO 17 : return [expr] }
    If KW = 'return' Then
    Begin
      ParserAdvance;  { consommer 'return' }
      If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
         (CurToken.Kind <> TK_EOF) Then
      Begin
        ParseExpr(E);
        ExprLoad(E);
      End Else
        EmitInstr('XOR', 'AX, AX');  { return; sans valeur -> 0 }
      If CurFnDepth > 0 Then
        EmitInstr('JMP', CurFnRetLbl)  { retour sous-routine }
      Else
      Begin
        { return au niveau global -> sortie programme }
        EmitInstr('MOV', 'BX, AX');
        EmitInstr('MOV', 'AH, 4Ch');
        EmitInstr1('INT 21h');
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
      Exit;
    End;
  End;
  { ----------------------------------------------------------- }
  { Instruction expression avec modificateur potentiel          }
  { Structure :                                                  }
  {   JMP Lcond                                                  }
  {   Lbody:  [corps - expression Perl]                         }
  {           JMP Lend                                          }
  {   Lcond:  [condition] JNZ/JZ Lbody  ou  JMP Lbody          }
  {   Lend:                                                      }
  { ----------------------------------------------------------- }
  LblBody := LabelGen('_PRL_SMBOD_');
  LblCond := LabelGen('_PRL_SMCND_');
  LblEnd  := LabelGen('_PRL_SMEND_');
  EmitInstr('JMP', LblCond);
  EmitLabel(LblBody);
  ParseExpr(E);
  EmitInstr('JMP', LblEnd);
  EmitLabel(LblCond);
  { Detecter modificateur if / unless / while / until }
  HasMod := False;
  ModKW  := '';
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    ModKW := CurToken.Val;
    If (ModKW = 'if') Or (ModKW = 'unless') Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(CondE);
      ExprLoad(CondE);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If ModKW = 'if' Then
        EmitInstr('JNZ', LblBody)   { if: executer si VRAI }
      Else
        EmitInstr('JZ', LblBody);   { unless: executer si FAUX }
      HasMod := True;
    End Else If (ModKW = 'while') Or (ModKW = 'until') Then
    Begin
      { Structure deja en place : LblCond est le bon point d'entree }
      { On emet la condition ici et on reboucle vers LblBody }
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(CondE);
      ExprLoad(CondE);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If ModKW = 'while' Then
        EmitInstr('JNZ', LblBody)   { while: executer tant que VRAI }
      Else
        EmitInstr('JZ', LblBody);   { until: executer tant que FAUX }
      HasMod := True;
    End;
  End;
  If Not HasMod Then
    EmitInstr('JMP', LblBody);  { pas de modificateur : toujours executer }
  EmitLabel(LblEnd);
  { Consommer '';'' ou tolerer EOF }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance
  Else If CurToken.Kind <> TK_EOF Then
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: '';'' attendu, obtenu ''',
            CurToken.Val, '''');
    Inc(ErrorCount);
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
              (CurToken.Kind <> TK_EOF) Do
      ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
      ParserAdvance;
  End;
End;

{ ============================================================
  TODO 02 - LEXEUR PERL
  ============================================================ }

{ ---- Primitives de bas niveau ----------------------------- }
Function LexCurChar : Char;
Begin
  If (LexEOF) Or (LexColNo > Length(LexLine)) Then
    LexCurChar := #0
  Else
    LexCurChar := LexLine[LexColNo];
End;

Function LexPeek : Char;
Begin
  If (LexEOF) Or (LexColNo + 1 > Length(LexLine)) Then
    LexPeek := #0
  Else
    LexPeek := LexLine[LexColNo + 1];
End;

Function LexPeek2 : Char;
Begin
  If (LexEOF) Or (LexColNo + 2 > Length(LexLine)) Then
    LexPeek2 := #0
  Else
    LexPeek2 := LexLine[LexColNo + 2];
End;

Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ---- Erreur lexicale (non fatale) ------------------------- }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('PERL86:', LexLineNo, ':', LexColNo, ': Erreur: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d''erreurs - compilation abandonnee');
End;

{ ---- Constructeur de token -------------------------------- }
Procedure MakeToken(Var T : TToken; K : TTokenKind;
                    Const V : TString; L, C : Integer);
Begin
  T.Kind     := K;
  T.Val      := V;
  T.IntVal   := 0;
  T.FloatVal := 0.0;
  T.Line     := L;
  T.Col      := C;
End;

{ ---- Commentaires Perl : # jusqu''a la fin de ligne ------- }
{ (Perl n''a pas de /* */ contrairement a PHP)                }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ---- Passer les espaces et les commentaires --------------- }
Procedure LexSkipWS;
Var
  C : Char;
Begin
  Repeat
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
      LexNextLine;
    If LexEOF Then Exit;
    C := LexCurChar;
    If (C = ' ') Or (C = #9) Or (C = #13) Or (C = #10) Then
      LexAdvance
    Else If C = '#' Then
      LexSkipLineComment   { seul type de commentaire en Perl }
    Else
      Exit;
  Until False;
End;

{ ---- Utilitaires caracteres ------------------------------- }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or (C = '_');
End;

Function IsDigit(C : Char) : Boolean;
Begin
  IsDigit := (C >= '0') And (C <= '9');
End;

Function IsAlNum(C : Char) : Boolean;
Begin
  IsAlNum := IsAlpha(C) Or IsDigit(C);
End;

Function IsHexDigit(C : Char) : Boolean;
Begin
  IsHexDigit := IsDigit(C) Or
                ((C >= 'a') And (C <= 'f')) Or
                ((C >= 'A') And (C <= 'F'));
End;

Function HexVal(C : Char) : Integer;
Begin
  If   (C >= '0') And (C <= '9') Then HexVal := Ord(C) - Ord('0')
  Else If (C >= 'a') And (C <= 'f') Then HexVal := Ord(C) - Ord('a') + 10
  Else HexVal := Ord(C) - Ord('A') + 10;
End;

{ ---- Table des mots-cles Perl ----------------------------- }
Const
  PERL_KW_COUNT = 66;
  PERL_KW : Array[0..65] Of String[14] = (
    { Declaration de portee }
    'my',           'our',          'local',
    { Sous-routines }
    'sub',          'return',       'wantarray',
    { Packages et modules }
    'use',          'require',      'package',
    'BEGIN',        'END',
    { Conditionnels }
    'if',           'elsif',        'else',
    'unless',
    { Boucles }
    'while',        'until',        'for',
    'foreach',      'do',
    'last',         'next',         'redo',
    { E/S et print }
    'print',        'say',          'printf',
    'sprintf',      'warn',         'die',
    'exit',
    { Tableaux }
    'push',         'pop',          'shift',
    'unshift',      'splice',       'reverse',
    'sort',         'join',         'split',
    'grep',         'map',
    { Hashes }
    'keys',         'values',       'each',
    'exists',       'delete',
    { Scalaires et types }
    'defined',      'undef',        'ref',
    'chomp',        'chop',         'length',
    'substr',       'index',        'int',
    'abs',          'hex',          'oct',
    'chr',          'ord',          'lc',
    'uc',
    { Logiques basse precedence }
    'not',          'and',          'or',
    { Operateur de repetition }
    'x'
  );

Function IsPerlKeyword(Const S : TString) : Boolean;
Var
  I : Integer;
Begin
  IsPerlKeyword := False;
  For I := 0 To PERL_KW_COUNT - 1 Do
    If S = PERL_KW[I] Then
    Begin IsPerlKeyword := True; Exit; End;
End;

{ ---- LexScanIdent : identificateur, mot-cle ou bareword --- }
{ Les barewords STDOUT STDERR STDIN deviennent TK_FILEHANDLE  }
Procedure LexScanIdent(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := '';
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
        IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  { Filehandles connus }
  If (S = 'STDOUT') Or (S = 'STDERR') Or (S = 'STDIN') Then
    MakeToken(T, TK_FILEHANDLE, S, SL, SC)
  Else If IsPerlKeyword(S) Then
    MakeToken(T, TK_KEYWORD, S, SL, SC)
  Else
    MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ---- LexScanNumber : entier ou flottant ------------------- }
{ Perl : 0x hex, 0b binaire, 0 octal, 1_000 separateurs       }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;
  Div10 : Real;
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin S := '0x'; LexAdvance; LexAdvance; Base := 16; End;
      'b','B': Begin S := '0b'; LexAdvance; LexAdvance; Base := 2;  End;
    Else
      { octal classique en Perl : 0NNN }
      If IsDigit(LexPeek) Then
      Begin
        S := '0'; Val := 0;
        LexAdvance;
        Base := 8;
      End Else
      Begin
        S := '0'; Val := 0; LexAdvance;
      End;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;  { separateur numerique }
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin Val:=Val*2+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin Val:=Val*8+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      10 : If IsDigit(C) Then
           Begin Val:=Val*10+(Ord(C)-Ord('0')); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
      16 : If IsHexDigit(C) Then
           Begin Val:=Val*16+HexVal(C); If Length(S)<MAX_STR Then S:=S+C; LexAdvance; End
           Else Break;
    End;
  End;
  { Detection flottant (base 10 uniquement) }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And IsDigit(LexPeek) Then
  Begin
    Fv    := Val * 1.0;
    Div10 := 10.0;
    If Length(S) < MAX_STR Then S := S + '.';
    LexAdvance;
    While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
          (IsDigit(LexCurChar) Or (LexCurChar = '_')) Do
    Begin
      If LexCurChar <> '_' Then
      Begin
        Fv    := Fv + (Ord(LexCurChar) - Ord('0')) / Div10;
        Div10 := Div10 * 10.0;
        If Length(S) < MAX_STR Then S := S + LexCurChar;
      End;
      LexAdvance;
    End;
    { Exposant e/E }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       ((LexCurChar = 'e') Or (LexCurChar = 'E')) Then
    Begin
      If Length(S) < MAX_STR Then S := S + LexCurChar;
      LexAdvance;
      If (LexColNo <= Length(LexLine)) And
         ((LexCurChar = '+') Or (LexCurChar = '-')) Then
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ---- LexScanEscape : sequence d''echappement (double-quote) }
{ Perl : \n \t \r \f \e \0 \\ \' \" \$ \@ \xNN \NNN (octal)  }
Function LexScanEscape(Var IntOut : LongInt) : Char;
Var
  C    : Char;
  Code : LongInt;
  I    : Integer;
Begin
  IntOut := 0;
  Code   := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Sequence d''echappement incomplete');
    LexScanEscape := '?';
    Exit;
  End;
  C := LexCurChar;
  LexAdvance;
  Case C Of
    'n' : Begin LexScanEscape := #10; IntOut := 10;  End;
    't' : Begin LexScanEscape := #9;  IntOut := 9;   End;
    'r' : Begin LexScanEscape := #13; IntOut := 13;  End;
    'f' : Begin LexScanEscape := #12; IntOut := 12;  End;
    'e' : Begin LexScanEscape := #27; IntOut := 27;  End;  { ESC }
    '0' : Begin LexScanEscape := #0;  IntOut := 0;   End;
    '"' : Begin LexScanEscape := '"'; IntOut := 34;  End;
    '''': Begin LexScanEscape := ''''; IntOut := 39; End;
    '\' : Begin LexScanEscape := '\'; IntOut := 92;  End;
    '$' : Begin LexScanEscape := '$'; IntOut := 36;  End;
    '@' : Begin LexScanEscape := '@'; IntOut := 64;  End;
    'x' : Begin
            Code := 0;
            For I := 1 To 2 Do
            Begin
              If (LexColNo > Length(LexLine)) Or (Not IsHexDigit(LexCurChar)) Then
              Begin LexError('\x: 2 chiffres hexa attendus'); Break; End;
              Code := Code * 16 + HexVal(LexCurChar);
              LexAdvance;
            End;
            IntOut := Code;
            LexScanEscape := Chr(Code And $FF);
          End;
  Else
    LexScanEscape := C;
    IntOut := Ord(C);
  End;
End;

{ ---- LexScanStrSingle : simple-quote (pas d''interpolation) }
Procedure LexScanStrSingle(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-simple ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      { Continuer sur la ligne suivante (chaine multi-ligne) }
      If LexEOF Then
      Begin
        LexError('Chaine simple-quote non fermee (EOF)');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 39 Then                { '  : fermeture }
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then       { \  : echappement limite }
      Begin
        LexAdvance;
        If (LexColNo <= Length(LexLine)) And
           ((LexCurChar = #39) Or (LexCurChar = #92)) Then
        Begin
          If Length(S) < MAX_STR Then S := S + LexCurChar;
          LexAdvance;
        End Else
          If Length(S) < MAX_STR Then S := S + '\';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanStrDouble : double-quote avec interpolation ---- }
{ Les interpolations $var et @arr sont encodees dans Val :     }
{   $nom  -> #1 + nom + #2                                     }
{   @nom  -> #3 + nom + #4                                     }
Procedure LexScanStrDouble(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  VN   : TString;
  Done : Boolean;
Begin
  LexAdvance; { consommer le guillemet-double ouverture }
  S    := '';
  Done := False;
  Repeat
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then
      Begin
        LexError('Chaine double-quote non fermee (EOF)');
        Done := True;
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + #10;
        LexNextLine;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) = 34 Then                { "  : fermeture }
      Begin
        LexAdvance; Done := True;
      End Else If Ord(C) = 92 Then       { \  : echappement }
      Begin
        LexAdvance;
        C := LexScanEscape(IV);
        If Length(S) < MAX_STR Then S := S + C;
      End Else If C = '$' Then           { $var : interpolation scalaire }
      Begin
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #1;  { marqueur debut $var }
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #2;  { marqueur fin $var   }
        End Else
          If Length(S) < MAX_STR Then S := S + '$';
      End Else If C = '@' Then           { @arr : interpolation tableau }
      Begin
        LexAdvance;
        VN := '';
        While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
        Begin
          If Length(VN) < 30 Then VN := VN + LexCurChar;
          LexAdvance;
        End;
        If VN <> '' Then
        Begin
          If Length(S) < MAX_STR Then S := S + #3;  { marqueur debut @arr }
          If Length(S) + Length(VN) <= MAX_STR Then S := S + VN;
          If Length(S) < MAX_STR Then S := S + #4;  { marqueur fin @arr   }
        End Else
          If Length(S) < MAX_STR Then S := S + '@';
      End Else
      Begin
        If Length(S) < MAX_STR Then S := S + C;
        LexAdvance;
      End;
    End;
  Until Done;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ---- LexScanStrBacktick : backtick ` (commande systeme) ---  }
{ Non supporte sur DOS 8086 : on consomme et on emet warning   }
Procedure LexScanStrBacktick(Var T : TToken; SL, SC : Integer);
Var
  C : Char;
Begin
  LexAdvance; { consommer le backtick ouverture }
  While Not LexEOF Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      If LexEOF Then Break;
      LexNextLine;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If C = '`' Then Break;
    End;
  End;
  WriteLn('PERL86:', SL, ':', SC,
          ': Avertissement: backtick (commande systeme) non supporte - chaine vide');
  Inc(WarnCount);
  MakeToken(T, TK_STRING, '', SL, SC);
End;

{ ---- LexScanHeredoc : << LABEL, <<"LABEL", <<''LABEL''     }
{ Fin : ligne contenant exactement le label (sans espaces)    }
Procedure LexScanHeredoc(Var T : TToken; SL, SC : Integer);
Var
  Lbl      : TString;
  IsNowdoc : Boolean;
  S        : TString;
  LLen     : Integer;
Begin
  { Consommer '<< ' (deux caracteres, le curseur est sur le 2e '<') }
  LexAdvance; LexAdvance;  { passer << (le 1er '<' a deja ete vu dans LexNextToken) }
  IsNowdoc := False;
  Lbl      := '';
  { Ignorer les espaces apres << }
  While (LexColNo <= Length(LexLine)) And (LexCurChar = ' ') Do LexAdvance;
  If (LexColNo <= Length(LexLine)) Then
  Begin
    Case LexCurChar Of
      '''': { Nowdoc <<'LABEL' : pas d''interpolation }
        Begin
          IsNowdoc := True;
          LexAdvance;
          While (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) <> 39) Do
          Begin
            If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
            LexAdvance;
          End;
          If LexColNo <= Length(LexLine) Then LexAdvance; { fermer ' }
        End;
      '"': { Heredoc <<"LABEL" : avec interpolation (meme comportement que sans quote) }
        Begin
          LexAdvance;
          While (LexColNo <= Length(LexLine)) And (Ord(LexCurChar) <> 34) Do
          Begin
            If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
            LexAdvance;
          End;
          If LexColNo <= Length(LexLine) Then LexAdvance; { fermer " }
        End;
    Else
      { Heredoc <<LABEL }
      While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(Lbl) < 30 Then Lbl := Lbl + LexCurChar;
        LexAdvance;
      End;
    End;
  End;
  If Lbl = '' Then
  Begin
    LexError('Heredoc: label manquant apres <<');
    MakeToken(T, TK_STRING, '', SL, SC);
    Exit;
  End;
  { Passer a la premiere ligne de contenu }
  LexNextLine;
  S    := '';
  LLen := Length(Lbl);
  While Not LexEOF Do
  Begin
    { Le label de fermeture doit etre seul sur sa ligne }
    If (Length(LexLine) = LLen) And (Copy(LexLine, 1, LLen) = Lbl) Then
    Begin
      LexColNo := LLen + 1;  { positionner apres le label }
      MakeToken(T, TK_HEREDOC, S, SL, SC);
      Exit;
    End;
    If (Length(LexLine) > LLen) And
       (Copy(LexLine, 1, LLen) = Lbl) And
       (LexLine[LLen + 1] = ';') Then
    Begin
      LexColNo := LLen + 1;  { laisser ';' pour le parseur }
      MakeToken(T, TK_HEREDOC, S, SL, SC);
      Exit;
    End;
    { Accumuler la ligne }
    If Length(S) + Length(LexLine) < MAX_STR Then
      S := S + LexLine;
    If Length(S) < MAX_STR Then S := S + #10;
    LexNextLine;
  End;
  LexError('Heredoc: label de fermeture "' + Lbl + '" introuvable (EOF)');
  MakeToken(T, TK_HEREDOC, S, SL, SC);
End;

{ ---- LexScanOp : operateurs Perl (simples et composes) ---- }
{ Specificites Perl vs PHP :                                   }
{   x=   repetition-assigne                                    }
{   ..   plage (range)                                         }
{   ...  plage exclusive                                       }
{   //   defined-or (PAS un commentaire en Perl !)             }
{   //=  defined-or-assign                                     }
{   ->   dereferencement fleche                                }
{   =>   grosse-virgule (fat comma)                            }
{   <=>  spaceship numerique                                   }
{   ~~   smartmatch (tokenise mais non supporte)               }
Procedure LexScanOp(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
  C : Char;
  P : Char;
  P2: Char;
Begin
  C  := LexCurChar;
  P  := LexPeek;
  P2 := LexPeek2;
  S  := C;
  LexAdvance;
  Case C Of
    '+': If P = '+' Then Begin S := '++'; LexAdvance; End
         Else If P = '=' Then Begin S := '+='; LexAdvance; End;
    '-': If P = '-' Then Begin S := '--'; LexAdvance; End
         Else If P = '>' Then Begin S := '->'; LexAdvance; End
         Else If P = '=' Then Begin S := '-='; LexAdvance; End;
    '*': If P = '*' Then
         Begin
           S := '**'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '**='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '*='; LexAdvance; End;
    '/': If P = '/' Then
         Begin
           S := '//'; LexAdvance;          { defined-or, PAS commentaire }
           If LexCurChar = '=' Then Begin S := '//='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '/='; LexAdvance; End;
    '%': If P = '=' Then Begin S := '%='; LexAdvance; End;
    '.': If P = '.' Then
         Begin
           S := '..'; LexAdvance;
           If LexCurChar = '.' Then Begin S := '...'; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '.='; LexAdvance; End;
    '!': If P = '=' Then Begin S := '!='; LexAdvance; End
         Else If P = '~' Then Begin S := '!~'; LexAdvance; End;  { not-match }
    '=': If P = '=' Then
         Begin
           S := '=='; LexAdvance;
           If LexCurChar = '=' Then Begin S := '==='; LexAdvance; End;  { non-Perl, securite }
         End
         Else If P = '>' Then Begin S := '=>'; LexAdvance; End  { fat comma }
         Else If P = '~' Then Begin S := '=~'; LexAdvance; End; { match }
    '<': If P = '=' Then
         Begin
           S := '<='; LexAdvance;
           If LexCurChar = '>' Then Begin S := '<=>'; LexAdvance; End; { spaceship }
         End
         Else If P = '<' Then
         Begin
           S := '<<'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '<<='; LexAdvance; End;
         End;
    '>': If P = '=' Then Begin S := '>='; LexAdvance; End
         Else If P = '>' Then
         Begin
           S := '>>'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '>>='; LexAdvance; End;
         End;
    '&': If P = '&' Then Begin S := '&&'; LexAdvance; End
         Else If P = '=' Then Begin S := '&='; LexAdvance; End;
    '|': If P = '|' Then
         Begin
           S := '||'; LexAdvance;
           If LexCurChar = '=' Then Begin S := '||='; LexAdvance; End;
         End
         Else If P = '=' Then Begin S := '|='; LexAdvance; End;
    '^': If P = '=' Then Begin S := '^='; LexAdvance; End;
    ':': If P = ':' Then Begin S := '::'; LexAdvance; End;  { separateur package }
    '~': If P = '~' Then Begin S := '~~'; LexAdvance; End;  { smartmatch (tokenise) }
    '?': ; { ternaire simple }
  End;
  MakeToken(T, TK_OP, S, SL, SC);
End;

{ ---- LexScanPunct : ponctuation simple -------------------- }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ---- LexNextToken : produire le prochain token Perl ------- }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
  S      : TString;
Begin
  LexSkipWS;
  If LexEOF Or (LexColNo > Length(LexLine)) Then
  Begin
    MakeToken(T, TK_EOF, '', LexLineNo, LexColNo);
    Exit;
  End;
  SL := LexLineNo;
  SC := LexColNo;
  C  := LexCurChar;

  { Sigil $ : variable scalaire $nom }
  If C = '$' Then
  Begin
    LexAdvance;
    S := '';
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlpha(LexCurChar) Then
    Begin
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End Else If (LexColNo <= Length(LexLine)) And (LexCurChar = '{') Then
    Begin
      (* Forme avec accolades : $-nom- *)
      LexAdvance;
      While (LexColNo <= Length(LexLine)) And (LexCurChar <> '}') Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      If LexColNo <= Length(LexLine) Then LexAdvance; (* fermer l'accolade de ${nom} *)
    End;
    MakeToken(T, TK_SCALAR, S, SL, SC);
    Exit;
  End;

  { Sigil @ : variable tableau @nom }
  If C = '@' Then
  Begin
    LexAdvance;
    S := '';
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlpha(LexCurChar) Then
    Begin
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    MakeToken(T, TK_ARRAY_SIG, S, SL, SC);
    Exit;
  End;

  { Sigil % : variable hash %nom }
  If C = '%' Then
  Begin
    { Attention : '%=' est un operateur, '%' seul suivi d''ident = hash }
    If IsAlpha(LexPeek) Then
    Begin
      LexAdvance;
      S := '';
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
      MakeToken(T, TK_HASH_SIG, S, SL, SC);
      Exit;
    End;
    { Sinon : operateur % ou %= }
    LexScanOp(T, SL, SC);
    Exit;
  End;

  { Identifiant ou mot-cle }
  If IsAlpha(C) Then Begin LexScanIdent(T, SL, SC); Exit; End;

  { Litteraux numeriques }
  If IsDigit(C) Then Begin LexScanNumber(T, SL, SC); Exit; End;

  { Chaine simple-quote }
  If Ord(C) = 39 Then Begin LexScanStrSingle(T, SL, SC); Exit; End;

  { Chaine double-quote }
  If Ord(C) = 34 Then Begin LexScanStrDouble(T, SL, SC); Exit; End;

  { Backtick : commande systeme (non supporte) }
  If C = '`' Then Begin LexScanStrBacktick(T, SL, SC); Exit; End;

  { Heredoc : << (detecter avant LexScanOp qui consomme '<') }
  { Condition : suivant est '<' et caractere suivant n''est PAS '<' }
  { (C = '<' et LexPeek = '<' et LexPeek2 != '<')                  }
  If (C = '<') And (LexPeek = '<') And (LexPeek2 <> '<') Then
  Begin
    { Verifier que ce n''est pas un operateur binaire :            }
    { heuristique : si la chaine apres << commence par un ident,   }
    { une quote ou un espace -> heredoc                            }
    If IsAlpha(LexPeek2) Or (LexPeek2 = '''') Or
       (LexPeek2 = '"')  Or (LexPeek2 = ' ')  Then
    Begin
      LexAdvance;  { consommer le 1er '<' }
      LexScanHeredoc(T, SL, SC);
      Exit;
    End;
  End;

  { Operateurs Perl }
  Case C Of
    '+','-','*','/','.',
    '!','=','<','>','&','|','^','~','?',':':
      Begin LexScanOp(T, SL, SC); Exit; End;
  End;

  { Ponctuation }
  LexScanPunct(T, SL, SC);
End;

{ ---- LexInit : ouvrir le fichier source et initialiser ---- }
{ Gestion du shebang : si la 1ere ligne commence par #!,      }
{ elle est ignoree silencieusement.                           }
Procedure LexInit;
Begin
  LexOpened := False;
  Assign(LexSrcF, Opts.SrcFile);
  Reset(LexSrcF);
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir: ' + Opts.SrcFile);
  LexOpened := True;
  LexEOF    := False;
  LexLineNo := 0;
  LexColNo  := 1;
  LexLine   := '';
  { Lire la premiere ligne }
  LexNextLine;
  { Shebang : ignorer #!/usr/bin/perl ou #!/usr/bin/env perl }
  If (Length(LexLine) >= 2) And
     (LexLine[1] = '#') And (LexLine[2] = '!') Then
  Begin
    LexSkipLineComment;  { sauter toute la ligne }
    LexNextLine;         { passer a la ligne suivante }
  End;
End;

{ ---- LexClose : fermer le fichier source ------------------ }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ---- PrintToken : mode debug -d --------------------------- }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[12];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT      : KS := 'IDENT   ';
    TK_KEYWORD    : KS := 'KEYWORD ';
    TK_SCALAR     : KS := 'SCALAR  ';
    TK_ARRAY_SIG  : KS := 'ARRAY@  ';
    TK_HASH_SIG   : KS := 'HASH%   ';
    TK_INTEGER    : KS := 'INTEGER ';
    TK_FLOAT      : KS := 'FLOAT   ';
    TK_STRING     : KS := 'STRING  ';
    TK_HEREDOC    : KS := 'HEREDOC ';
    TK_REGEXP     : KS := 'REGEXP  ';
    TK_FILEHANDLE : KS := 'FILEHND ';
    TK_OP         : KS := 'OP      ';
    TK_PUNCT      : KS := 'PUNCT   ';
    TK_EOF        : KS := 'EOF     ';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin Str(T.IntVal, NS); Write(' =', NS); End
  Else If T.Kind = TK_FLOAT Then
  Begin Str(T.FloatVal : 0 : 6, NS); Write(' =', NS); End;
  WriteLn;
End;

{ ---- ParserAdvance : lire le prochain token --------------- }
Procedure ParserAdvance;
Begin
  LexNextToken(CurToken);
  If Opts.DebugTok Then
    PrintToken(CurToken);
End;

{ ============================================================
  TODO 03 - LITTERAUX ET CONSTANTES PERL
  ============================================================ }

{ ---- DataAdd / DataAddStr : table de donnees statiques ------- }
{ Implementation complete (initialement ebauche TODO 03, stabilise TODO 08) }
Function DataAdd(Const ALbl : TString; AKind : TDataKind;
                 AInt : LongInt; Const AStr : TString) : Integer;
Begin
  If DataCount >= MAX_DATA Then
  Begin
    WriteLn('PERL86: ERREUR - table de donnees saturee (MAX_DATA=', MAX_DATA, ')');
    Inc(ErrorCount);
    DataAdd := -1;
    Exit;
  End;
  DataTab[DataCount].LblName   := ALbl;
  DataTab[DataCount].Kind      := AKind;
  DataTab[DataCount].IntVal    := AInt;
  DataTab[DataCount].StrVal    := AStr;
  DataTab[DataCount].ElemCount := 0;
  DataAdd := DataCount;
  Inc(DataCount);
End;

Function DataAddStr(Const S : TString) : Integer;
Var
  I   : Integer;
  Lbl : TString;
  Seq : TString;
Begin
  { Chercher si la chaine existe deja pour eviter les doublons }
  For I := 0 To DataCount - 1 Do
    If (DataTab[I].Kind = DK_STR) And (DataTab[I].StrVal = S) Then
    Begin
      DataAddStr := I;
      Exit;
    End;
  { Nouvelle entree }
  Inc(LabelSeq);
  Str(LabelSeq, Seq);
  Lbl := PR_STR_PFX + Seq;
  DataAddStr := DataAdd(Lbl, DK_STR, 0, S);
End;

{ ---- ExprMakeImm : construire une valeur immediate -------- }
{ TP7 : pas de retour de Record -> parametre Var Res          }
Procedure ExprMakeImm(AVal : LongInt; ATypeIdx : Integer;
                      Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := AVal;
  Res.TypeIdx := ATypeIdx;
  Res.Offset  := 0;
End;

{ ---- ExprMakeNone : valeur void/invalide ------------------ }
Procedure ExprMakeNone(Var Res : TExprVal);
Begin
  Res.Kind    := EK_NONE;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_UNKNOWN;
  Res.Offset  := 0;
End;

{ ---- ExprMakeUndef : valeur undef (pointeur nul) ---------- }
{ En Perl, undef est la valeur « non definie » ; on la         }
{ represente par un immediat 0 avec le type TY_IDX_UNDEF.      }
Procedure ExprMakeUndef(Var Res : TExprVal);
Begin
  Res.Kind    := EK_IMM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_UNDEF;
  Res.Offset  := 0;
End;

{ ---- LitEvalInt : token TK_INTEGER -> TExprVal ------------ }
{ IntVal est deja calcule par LexScanNumber (hex/bin/oct/dec)  }
Procedure LitEvalInt(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeImm(T.IntVal, TY_IDX_SCALAR, Res);
End;

{ ---- LitEvalFloat : TK_FLOAT -> int tronque + warning ----- }
{ Cible 8086 sans FPU : les flottants sont tronques en entier. }
Procedure LitEvalFloat(Const T : TToken; Var Res : TExprVal);
Var
  IV : LongInt;
Begin
  IV := Trunc(T.FloatVal);
  ExprMakeImm(IV, TY_IDX_SCALAR, Res);
  WriteLn('PERL86:', T.Line, ':', T.Col,
          ': Avertissement: flottant tronque a ', IV,
          ' (pas de FPU sur 8086)');
  Inc(WarnCount);
End;

{ ---- LitEvalStr : TK_STRING -> EK_MEM pointant dans DataSeg }
{ La chaine est ajoutee au segment de donnees.                 }
{ Les interpolations encodees (#1nom#2, #3nom#4) seront        }
{ resolues par EmitInterpolatedStr dans les TODOs suivants.    }
Procedure LitEvalStr(Const T : TToken; Var Res : TExprVal);
Begin
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.Offset  := DataAddStr(T.Val);
End;

{ ---- LitEvalHeredoc : TK_HEREDOC -> meme chemin que STRING -- }
Procedure LitEvalHeredoc(Const T : TToken; Var Res : TExprVal);
Begin
  Res.Kind    := EK_MEM;
  Res.ImmVal  := 0;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.Offset  := DataAddStr(T.Val);
End;

{ ---- ParseQwList : qw(mot1 mot2 mot3) -> tableau statique -- }
{ Consomme les tokens jusqu''a la parenthese fermante.         }
{ Retourne le nombre d''elements lus (max MAX_PARAM).          }
{ Les elements sont deposes dans DataTab comme DK_STR.         }
{ Res reçoit EK_NONE (les elements seront utilises par TODO 15) }
Function ParseQwList(Var Items : Array Of Integer;
                     Var ItemCount : Integer) : Boolean;
Var
  S    : TString;
  Sep  : Char;
Begin
  ParseQwList := False;
  ItemCount  := 0;
  { CurToken doit etre '(' }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: ''('' attendu apres qw');
    Inc(ErrorCount);
    Exit;
  End;
  { Determiner le separateur de fermeture }
  Sep := ')';
  ParserAdvance;  { consommer ''('' }
  { Accumuler les barewords separes par des espaces ou virgules }
  S := '';
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        Not (CurToken.Kind = TK_EOF) Do
  Begin
    { Les tokens dans qw() sont des IDENTs ou mot-cles (barewords) }
    If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_KEYWORD) Or
       (CurToken.Kind = TK_INTEGER) Or (CurToken.Kind = TK_STRING) Then
    Begin
      S := CurToken.Val;
      If ItemCount <= High(Items) Then
      Begin
        Items[ItemCount] := DataAddStr(S);
        Inc(ItemCount);
      End;
    End Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
    Begin
      { virgule optionnelle : on ignore }
    End;
    ParserAdvance;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance;  { consommer '')'' }
  ParseQwList := True;
End;

{ ---- LitEval : dispatcher principal des litteraux Perl ----- }
{ Tokens traites : TK_INTEGER, TK_FLOAT, TK_STRING,           }
{   TK_HEREDOC, TK_KEYWORD (undef / true / false).            }
Procedure LitEval(Const T : TToken; Var Res : TExprVal);
Begin
  ExprMakeNone(Res);  { valeur par defaut }
  Case T.Kind Of
    TK_INTEGER : LitEvalInt(T, Res);
    TK_FLOAT   : LitEvalFloat(T, Res);
    TK_STRING  : LitEvalStr(T, Res);
    TK_HEREDOC : LitEvalHeredoc(T, Res);
    TK_KEYWORD :
    Begin
      If T.Val = 'undef' Then
        ExprMakeUndef(Res)
      Else If (T.Val = 'not') Then
        ExprMakeImm(1, TY_IDX_SCALAR, Res) { sera inverse par l''expression parente }
      Else
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Erreur: mot-cle non utilisable comme litteral : ', T.Val);
        Inc(ErrorCount);
      End;
    End;
    TK_IDENT :
    Begin
      { Bareword : traite comme chaine litterale en contexte litteral }
      { Ex: print FOO; -> "FOO" }
      If Opts.Strict Then
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Erreur (strict): bareword "', T.Val, '" non autorise');
        Inc(ErrorCount);
      End Else
      Begin
        WriteLn('PERL86:', T.Line, ':', T.Col,
                ': Avertissement: bareword "', T.Val,
                '" interprete comme chaine');
        Inc(WarnCount);
        Res.Kind    := EK_MEM;
        Res.ImmVal  := 0;
        Res.TypeIdx := TY_IDX_SCALAR;
        Res.Offset  := DataAddStr(T.Val);
      End;
    End;
  Else
    WriteLn('PERL86:', T.Line, ':', T.Col,
            ': Erreur: token non litteral : ', T.Val);
    Inc(ErrorCount);
  End;
End;

{ ============================================================
  TODO 04 - OPERATEURS ET PRECEDENCE (PRATT PARSER)
  ============================================================ }

{ ---- BinOpPrec : precedence d''un operateur binaire -------- }
{ Retourne 0 si ce n''est pas un operateur binaire infix.      }
{ Perl : deux familles logiques :                              }
{   haute  &&  ||  //  !   (precedence C-style)               }
{   basse  and  or  not    (precedence tres basse)             }
{ Niveaux numeriques : plus le chiffre est eleve, plus l''op   }
{ est prioritaire dans les expressions.                        }
Function BinOpPrec(Const Op : TString) : Integer;
Begin
  { Prec 1 (plus basse) : or xor }
  If (Op = 'or') Or (Op = 'xor') Then Begin BinOpPrec := 1; Exit; End;
  { Prec 2 : and }
  If Op = 'and' Then Begin BinOpPrec := 2; Exit; End;
  { Prec 3 : affectations = += -= *= /= %= .= //= &&= ||= x= **= <<= >>= &= |= ^= }
  If (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or (Op = '*=')  Or
     (Op = '/=')  Or (Op = '%=')  Or (Op = '.=')  Or (Op = '//=') Or
     (Op = '&&=') Or (Op = '||=') Or (Op = 'x=')  Or (Op = '**=') Or
     (Op = '<<=') Or (Op = '>>=') Or (Op = '&=')  Or (Op = '|=')  Or
     (Op = '^=')  Then Begin BinOpPrec := 3; Exit; End;
  { Prec 4 : ternaire '?' et ':' traites directement dans ParseExprPrec }
  { Prec 5 : .. et ... (plage) }
  If (Op = '..') Or (Op = '...') Then Begin BinOpPrec := 5; Exit; End;
  { Prec 6 : || // (defined-or) }
  If (Op = '||') Or (Op = '//') Then Begin BinOpPrec := 6; Exit; End;
  { Prec 7 : && }
  If Op = '&&' Then Begin BinOpPrec := 7; Exit; End;
  { Prec 8 : | ^ (bitwise or / xor) }
  If (Op = '|') Or (Op = '^') Then Begin BinOpPrec := 8; Exit; End;
  { Prec 9 : & (bitwise and) }
  If Op = '&' Then Begin BinOpPrec := 9; Exit; End;
  { Prec 10 : == != <=> eq ne cmp ~~ }
  If (Op = '==')  Or (Op = '!=')  Or (Op = '<=>') Or
     (Op = 'eq')  Or (Op = 'ne')  Or (Op = 'cmp') Or
     (Op = '~~')  Then Begin BinOpPrec := 10; Exit; End;
  { Prec 11 : < > <= >= lt gt le ge }
  If (Op = '<')  Or (Op = '>')  Or (Op = '<=') Or (Op = '>=') Or
     (Op = 'lt') Or (Op = 'gt') Or (Op = 'le') Or (Op = 'ge') Then
  Begin BinOpPrec := 11; Exit; End;
  { Prec 12 : << >> (decalage bit) }
  If (Op = '<<') Or (Op = '>>') Then Begin BinOpPrec := 12; Exit; End;
  { Prec 13 : + - . (addition, soustraction, concatenation) }
  If (Op = '+') Or (Op = '-') Or (Op = '.') Then Begin BinOpPrec := 13; Exit; End;
  { Prec 14 : * / % x (multiplication, modulo, repetition) }
  If (Op = '*') Or (Op = '/') Or (Op = '%') Or (Op = 'x') Then
  Begin BinOpPrec := 14; Exit; End;
  { Prec 15 (plus haute, binaire) : ** (puissance, assoc droite) }
  If Op = '**' Then Begin BinOpPrec := 15; Exit; End;
  BinOpPrec := 0;  { Pas un operateur binaire connu }
End;

{ ---- IsRightAssoc : operateur droite-associatif ? ---------- }
{ En Perl : = += -= etc. et ** sont associatifs a droite       }
{ Ex : $a = $b = 5  -> $a = ($b = 5)                          }
{       2 ** 3 ** 4 -> 2 ** (3 ** 4)                          }
Function IsRightAssoc(Const Op : TString) : Boolean;
Begin
  IsRightAssoc :=
    (Op = '=')   Or (Op = '+=')  Or (Op = '-=')  Or (Op = '*=')  Or
    (Op = '/=')  Or (Op = '%=')  Or (Op = '.=')  Or (Op = '//=') Or
    (Op = '&&=') Or (Op = '||=') Or (Op = 'x=')  Or (Op = '**=') Or
    (Op = '<<=') Or (Op = '>>=') Or (Op = '&=')  Or (Op = '|=')  Or
    (Op = '^=')  Or (Op = '**');
End;

{ ---- ExprLoad : charger une TExprVal dans le registre AX -- }
{ Stub - implementation complete dans TODO 07 (emetteur ASM)   }
{ En mode stub, on marque simplement la valeur comme etant en  }
{ AX pour que le parseur puisse continuer a travailler.        }
Procedure ExprLoad(Var E : TExprVal);
{ Convention EK_MEM :                                          }
{   ImmVal = 0 -> Offset = indice DataTab (donnee statique)    }
{   ImmVal = 1 -> Offset = deplacement pile (local [BP-Offset]) }
Var
  S : TString;
Begin
  Case E.Kind Of
    EK_IMM :
    Begin
      Str(E.ImmVal, S);
      EmitInstr('MOV', 'AX, ' + S);
    End;
    EK_MEM :
    Begin
      If E.ImmVal = 1 Then
      Begin
        { Variable locale my/local : acces [BP - Offset] }
        Str(E.Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else If E.ImmVal = 2 Then
      Begin
        { Element tableau dynamique : adresse deja dans BX }
        EmitInstr('MOV', 'AX, [BX]');
      End Else
      Begin
        { Donnee statique DATA : Offset = indice dans DataTab }
        If (E.Offset >= 0) And (E.Offset < DataCount) Then
        Begin
          If DataTab[E.Offset].Kind = DK_STR Then
            EmitInstr('MOV', 'AX, OFFSET ' + DataTab[E.Offset].LblName)
          Else
            EmitInstr('MOV', 'AX, [' + DataTab[E.Offset].LblName + ']');
        End Else
          EmitInstr('MOV', 'AX, 0');  { securite : indice invalide }
      End;
    End;
    EK_AX   : ;  { deja dans AX, rien a emettre }
    EK_DXAX : ;  { deja dans DX:AX, rien a emettre }
    EK_NONE : ;  { expression vide, rien a emettre }
  End;
  E.Kind := EK_AX;
End;

{ ---- ExprEmitBinOp : code ASM pour un operateur binaire ---- }
{ Stub - implementation complete dans TODO 11 (expressions)    }
{ Convention d''appel :                                         }
{   Left  : operande gauche (ExprLoad l''a mis en AX)          }
{   Right : operande droite (sera charge en BX ou CX)          }
{   Res   : valeur resultante -> EK_AX                         }
{ Operateurs impliques :                                        }
{   +  -> ADD  AX, BX        -  -> SUB  AX, BX                }
{   *  -> IMUL BX            /  -> CWD / IDIV BX -> AX = quotient }
{   %  -> CWD / IDIV BX -> residue dans DX                    }
{   ** -> appel runtime _PRRT_POW (entier, boucle de mul)      }
{   .  -> appel runtime _PRRT_CONCAT(DI=dst, SI=src)           }
{   x  -> appel runtime _PRRT_STRREPEAT(DI, SI, CX)           }
{   == -> CMP AX, BX ; SETE  AL ; MOVZX AX, AL               }
{   != -> CMP AX, BX ; SETNE AL ; MOVZX AX, AL               }
{   <  -> CMP AX, BX ; SETL  AL  etc.                         }
{   <=> -> CMP AX, BX ; SETL/SETE -> AX=-1/0/1                }
{   && -> court-circuit via labels _PRL_LAND_N                 }
{   || -> court-circuit via labels _PRL_LOR_N                  }
{   // -> test defined (!=undef) puis court-circuit             }
{   &  -> AND AX, BX  |  -> OR AX, BX  ^  -> XOR AX, BX      }
{   << -> SAL AX, CL   >> -> SAR AX, CL                       }
{   eq / ne / lt / le / gt / ge / cmp -> _PRRT_STRCMP          }
{ ---- ExprEmitBinOp : code ASM pour un operateur binaire ---- }
{ Convention d''appel (etablie par ParseExprPrec) :             }
{   Affectations (prec=3) : Left=EK_MEM (lvalue), AX=Right     }
{   Tous les autres (prec>=4 et prec=1,2) :                    }
{     BX = valeur gauche, AX = valeur droite                    }
{   &&, ||, // : traites directement dans ParseExprPrec         }
Procedure ExprEmitBinOp(Const Op : TString;
                         Var Left, Right : TExprVal;
                         Var Res         : TExprVal);
Var
  LblA : TString;
  LblB : TString;
  LblC : TString;
  SaveLeft : TExprVal;   { copie de Left pour affectations composees }
Begin
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  { ==============================================================
    Affectation simple '=' : Left=EK_MEM, AX=Right
    ============================================================== }
  If Op = '=' Then
  Begin
    EmitStoreScalar(Left);
    Res.TypeIdx := Left.TypeIdx;
    Exit;
  End;
  { ==============================================================
    Affectations composees : Left=EK_MEM, AX=Right (valeur)
    On sauve Right dans CX, charge Left, applique l''op, re-stocke.
    ============================================================== }
  SaveLeft := Left;   { garder l''adresse lvalue }
  If (Op = '+=') Or (Op = '-=') Or (Op = '*=') Or (Op = '/=') Or
     (Op = '%=') Or (Op = '&=') Or (Op = '|=') Or (Op = '^=') Or
     (Op = '<<=') Or (Op = '>>=') Or (Op = '.=') Or (Op = '**=') Or
     (Op = '||=') Or (Op = '&&=') Or (Op = '//=') Or (Op = 'x=') Then
  Begin
    { CX = Right (valeur du membre droit) }
    EmitInstr('MOV', 'CX, AX');
    { Charger Left dans AX }
    ExprLoad(SaveLeft);
    { Appliquer l''operation }
    If      Op = '+='  Then EmitInstr('ADD',  'AX, CX')
    Else If Op = '-='  Then EmitInstr('SUB',  'AX, CX')
    Else If Op = '*='  Then
    Begin EmitInstr('IMUL', 'CX'); End
    Else If Op = '/='  Then
    Begin EmitInstr1('CWD'); EmitInstr('IDIV', 'CX'); End
    Else If Op = '%='  Then
    Begin EmitInstr1('CWD'); EmitInstr('IDIV', 'CX'); EmitInstr('MOV', 'AX, DX'); End
    Else If Op = '&='  Then EmitInstr('AND',  'AX, CX')
    Else If Op = '|='  Then EmitInstr('OR',   'AX, CX')
    Else If Op = '^='  Then EmitInstr('XOR',  'AX, CX')
    Else If Op = '<<=' Then Begin EmitInstr('MOV', 'CL, CL'); EmitInstr('SHL', 'AX, CL'); End
    Else If Op = '>>=' Then Begin EmitInstr('SAR', 'AX, CL'); End
    Else If Op = '||=' Then
    Begin
      { AX = Left ; si non-zero, ne rien changer ; sinon AX = Right (CX) }
      EmitInstr('TEST', 'AX, AX');
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('JNZ', LblA);
      EmitInstr('MOV', 'AX, CX');
      EmitLabel(LblA);
    End
    Else If (Op = '&&=') Or (Op = '//=') Then
    Begin
      { AX = Left ; si zero, ne rien changer ; sinon AX = Right (CX) }
      EmitInstr('TEST', 'AX, AX');
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('JZ', LblA);
      EmitInstr('MOV', 'AX, CX');
      EmitLabel(LblA);
    End
    Else { .= **= x= : stub, garder l''ancienne valeur }
      EmitComment(Op + ' : stub, valeur inchangee');
    { Stocker le resultat dans la lvalue }
    EmitStoreScalar(Left);
    Exit;
  End;
  { ==============================================================
    Operateurs binaires standard : BX=Left, AX=Right
    ============================================================== }
  { ---- Arithmetiques ---- }
  If Op = '+' Then Begin EmitInstr('ADD', 'AX, BX'); Exit; End;
  If Op = '-' Then
  Begin
    { AX = Right, BX = Left -> voulons Left-Right }
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('SUB',  'AX, BX');
    Exit;
  End;
  If Op = '*' Then Begin EmitInstr('IMUL', 'BX'); Exit; End;
  If Op = '/' Then
  Begin
    { BX=Left, AX=Right : voulons Left/Right -> AX=Left, BX=Right }
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr1('CWD');
    EmitInstr('IDIV', 'BX');
    Exit;
  End;
  If Op = '%' Then
  Begin
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr1('CWD');
    EmitInstr('IDIV', 'BX');
    EmitInstr('MOV', 'AX, DX');
    Exit;
  End;
  If Op = '**' Then
  Begin
    { Puissance entiere : stub -> CALL _PRRT_POW (TODO 24) }
    EmitComment('** : CALL _PRRT_POW non implemente (stub)');
    EmitInstr('MOV', 'AX, 1');
    Exit;
  End;
  { ---- Concatenation et repetition ---- }
  If Op = '.' Then
  Begin
    EmitComment('. : concat -> CALL _PRRT_CONCAT (TODO 24)');
    Exit;
  End;
  If Op = 'x' Then
  Begin
    EmitComment('x : repet -> CALL _PRRT_STRREPEAT (TODO 24)');
    Exit;
  End;
  { ---- Comparaisons numeriques : BX=Left, AX=Right ---- }
  If Op = '==' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETE',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '!=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETNE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<'  Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETL',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETLE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '>'  Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETG',  'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '>=' Then
  Begin EmitInstr('CMP', 'BX, AX'); EmitInstr('SETGE', 'AL'); EmitInstr('MOVZX', 'AX, AL'); Exit; End;
  If Op = '<=>' Then
  Begin
    { Spaceship : BX=Left, AX=Right -> AX = -1/0/+1 }
    LblA := LabelGen(PR_LBL_PFX);   { label ''Left < Right'' }
    LblB := LabelGen(PR_LBL_PFX);   { label ''Left = Right'' }
    LblC := LabelGen(PR_LBL_PFX);   { label ''fin'' }
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('JL',  LblA);
    EmitInstr('JE',  LblB);
    { Left > Right }
    EmitInstr('MOV', 'AX, 1');
    EmitInstr('JMP', LblC);
    EmitLabel(LblA);
    EmitInstr('MOV', 'AX, 0FFFFh');  { -1 en 16 bits }
    EmitInstr('JMP', LblC);
    EmitLabel(LblB);
    EmitInstr('XOR', 'AX, AX');
    EmitLabel(LblC);
    Exit;
  End;
  { ---- Comparaisons de chaines : stub ---- }
  If (Op = 'eq') Or (Op = 'ne') Or (Op = 'lt') Or (Op = 'le') Or
     (Op = 'gt') Or (Op = 'ge') Or (Op = 'cmp') Then
  Begin
    EmitComment(Op + ' : CALL _PRRT_STRCMP (TODO 24)');
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  { ---- Bitwise ---- }
  If Op = '&' Then Begin EmitInstr('AND', 'AX, BX'); Exit; End;
  If Op = '|' Then Begin EmitInstr('OR',  'AX, BX'); Exit; End;
  If Op = '^' Then Begin EmitInstr('XOR', 'AX, BX'); Exit; End;
  If Op = '<<' Then
  Begin
    { BX=Left, AX=Right (shift count) : Left << Right }
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'AX, BX');
    EmitInstr('SHL', 'AX, CL');
    Exit;
  End;
  If Op = '>>' Then
  Begin
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'AX, BX');
    EmitInstr('SAR', 'AX, CL');
    Exit;
  End;
  { ---- Logiques bas niveau : BX=Left, AX=Right ---- }
  { ''and'' : equiv && mais prec basse : booleens sans court-circuit }
  If Op = 'and' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('AND', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  If Op = 'or' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('OR',  'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  If Op = 'xor' Then
  Begin
    EmitInstr('TEST', 'BX, BX');
    EmitInstr('SETNE', 'BL');
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('XOR', 'AL, BL');
    EmitInstr('MOVZX', 'AX, AL');
    Exit;
  End;
  { ---- Plage .. et ... : stub ---- }
  If (Op = '..') Or (Op = '...') Then
  Begin
    EmitComment(Op + ' : plage, stub TODO 14');
    EmitInstr('XOR', 'AX, AX');
    Exit;
  End;
  { Operateur inconnu : ne rien emettre }
  EmitComment('ExprEmitBinOp : operateur non gere : ' + Op);
End;

{ ---- ParsePrimary : expression primaire (atome) - TODO 10 -- }
{ Unaires : -  !  ~  not  pre++ pre--  \(ref)                  }
{ Parens, litteraux, $var, @arr/%hash scalaire, func(), &sub() }
{ defined($v), ref($v), mots-cles builtins a 1 arg             }
Procedure ParsePrimary(Var Res : TExprVal);
Var
  Op      : TString;
  Sub     : TExprVal;
  Idx     : Integer;
  NStr    : TString;
  S       : TString;
  NCStr   : TString;   { TODO 17 : taille nettoyage pile apres CALL }
  HKIdx   : Integer;   { indice entree HashKeyTab pour hash }
  SlotIdx : Integer;   { slot 0..MAX_HASH_PAIRS-1           }
Begin
  ExprMakeNone(Res);
  { ---- Operateurs unaires prefixes ---- }
  If CurToken.Kind = TK_OP Then
  Begin
    Op := CurToken.Val;
    If (Op = '-') Or (Op = '!') Or (Op = '~') Then
    Begin
      ParserAdvance;   { consommer l''operateur }
      ParsePrimary(Sub);
      ExprLoad(Sub);
      If Op = '-' Then
        EmitInstr1('NEG AX')
      Else If Op = '!' Then
      Begin
        EmitInstr('TEST',  'AX, AX');
        EmitInstr('SETE',  'AL');
        EmitInstr('MOVZX', 'AX, AL');
      End Else
        EmitInstr1('NOT AX');
      Res.Kind    := EK_AX;
      Res.TypeIdx := Sub.TypeIdx;
      Res.ImmVal  := 0;
      Res.Offset  := 0;
      Exit;
    End;
    { Pre-++ et pre-- : EmitIncrDecr }
    If (Op = '++') Or (Op = '--') Then
    Begin
      ParserAdvance;
      ParsePrimary(Sub);
      EmitIncrDecr(Sub, Op = '++', True, Res);
      Exit;
    End;
    { \ (reference) : LEA si lvalue memoire, sinon adresse OFFSET }
    If Op = '\' Then
    Begin
      ParserAdvance;
      ParsePrimary(Sub);
      If (Sub.Kind = EK_MEM) And (Sub.ImmVal = 1) Then
      Begin
        Str(Sub.Offset, S);
        EmitInstr('LEA', 'AX, [BP-' + S + ']');
      End Else If (Sub.Kind = EK_MEM) And (Sub.ImmVal = 0) And
                  (Sub.Offset >= 0) And (Sub.Offset < DataCount) Then
        EmitInstr('MOV', 'AX, OFFSET ' + DataTab[Sub.Offset].LblName)
      Else
        ExprLoad(Sub);
      Res.Kind    := EK_AX;
      Res.TypeIdx := TY_IDX_REF;
      Res.ImmVal  := 0;
      Res.Offset  := 0;
      Exit;
    End;
  End;
  { ---- Unaire 'not' (mot-cle, basse precedence) ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'not') Then
  Begin
    ParserAdvance;
    ParsePrimary(Sub);
    ExprLoad(Sub);
    EmitInstr('TEST',  'AX, AX');
    EmitInstr('SETE',  'AL');
    EmitInstr('MOVZX', 'AX, AL');
    Res.Kind    := EK_AX;
    Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Exit;
  End;
  { ---- defined($v) : AX = (AX != 0) ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'defined') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParsePrimary(Sub);
    ExprLoad(Sub);
    EmitInstr('TEST',  'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- ref($v) : AX = (AX != 0) ---- }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ref') Then
  Begin
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParsePrimary(Sub);
    ExprLoad(Sub);
    EmitInstr('TEST',  'AX, AX');
    EmitInstr('SETNE', 'AL');
    EmitInstr('MOVZX', 'AX, AL');
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- Builtins a un argument : chomp, chr, ord, length, lc, uc, int ... ---- }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    NStr := CurToken.Val;
    If (NStr = 'chomp') Or (NStr = 'chop')    Or (NStr = 'chr')     Or
       (NStr = 'ord')   Or (NStr = 'length')  Or (NStr = 'lc')      Or
       (NStr = 'uc')    Or (NStr = 'lcfirst') Or (NStr = 'ucfirst') Or
       (NStr = 'int')   Or (NStr = 'abs')     Or (NStr = 'hex')     Or
       (NStr = 'oct')   Or (NStr = 'sqrt')    Or (NStr = 'pos')     Or
       (NStr = 'chdir')   Then
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParsePrimary(Sub);
      ExprLoad(Sub);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { TODO 16 : exists et delete sur hash }
    If (NStr = 'exists') Or (NStr = 'delete') Then
    Begin
      Op := NStr;   { sauver 'exists'/'delete' avant de reutiliser NStr }
      ParserAdvance;  { consommer 'exists'/'delete' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      { Detecter hash-aware : $h[key] }
      If CurToken.Kind = TK_SCALAR Then
      Begin
        S := CurToken.Val;  { nom du hash }
        ParserAdvance;  { consommer $h }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
        Begin
          Idx := SymFindCat(S, SC_HASH_VAR);
          If Idx >= 0 Then
          Begin
            ParserAdvance;  { consommer '{' }
            { Cle constante : bareword ou chaine }
            NStr := '';
            If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Then
            Begin
              NStr := CurToken.Val;
              ParserAdvance;
            End;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
            HKIdx := HashSlotFind(Idx, NStr);
            If HKIdx >= 0 Then
            Begin
              SlotIdx := HashKeyTab[HKIdx].SlotIdx;
              Str(SymTab[Idx].Offset + 4 + SlotIdx * 4, S);
              If Op = 'exists' Then
                EmitInstr('MOV', 'AX, 1')  { cle connue -> existe toujours }
              Else
              Begin
                { delete : zeroiser la valeur }
                EmitInstr('MOV', 'WORD PTR [BP-' + S + '], 0');
                EmitInstr('MOV', 'AX, 1');
              End;
            End Else
              EmitInstr('MOV', 'AX, 0');  { cle inconnue }
            Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
            Res.ImmVal := 0; Res.Offset := 0;
            If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
            Exit;
          End;
        End;
        { Fallback : traitement generique }
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
      End Else
      Begin
        ParsePrimary(Sub);
        ExprLoad(Sub);
        Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
        Res.ImmVal := 0; Res.Offset := 0;
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Exit;
    End;
    { TODO 15 : pop / shift en contexte expression }
    If (NStr = 'pop') Or (NStr = 'shift') Then
    Begin
      ParseArrBuiltin(False);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { TODO 15 : scalar(@arr) en contexte expression }
    If NStr = 'scalar' Then
    Begin
      ParserAdvance;  { consommer 'scalar' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If CurToken.Kind = TK_ARRAY_SIG Then
      Begin
        Idx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
        If Idx >= 0 Then
        Begin
          Str(SymTab[Idx].Offset, S);
          EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
        End Else
          EmitInstr('MOV', 'AX, 0');
        ParserAdvance;
      End Else
        EmitInstr('MOV', 'AX, 0');
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { TODO 17 : wantarray() -> 0 (contexte toujours scalaire dans impl.) }
    If NStr = 'wantarray' Then
    Begin
      ParserAdvance;  { consommer 'wantarray' }
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('MOV', 'AX, 0');
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { TODO 17 : sous-routine anonyme en contexte expression }
    If NStr = 'sub' Then
    Begin
      ParseSubDecl;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_CODE;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    { Appel de sous-routine avec mot-cle non reconnu : avancer }
    ParserAdvance;
    ExprMakeNone(Res);
    Exit;
  End;
  { ---- Appel &sub(args) ---- }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '&') Then
  Begin
    ParserAdvance;
    If CurToken.Kind = TK_IDENT Then
    Begin
      NStr := CurToken.Val;
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        ParseCallArgs;
      EmitInstr('CALL', PR_FN_PFX + NStr);
      If GCallArgCount > 0 Then
      Begin
        Str(GCallArgCount * 2, NCStr);
        EmitInstr('ADD', 'SP, ' + NCStr);
      End;
    End;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- Sous-expression parenthesee ---- }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;     { consommer '(' }
    ParseExpr(Res);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
      ParserAdvance    { consommer ')' }
    Else
    Begin
      WriteLn('PERL86:', CurToken.Line, ': Erreur: '')'' attendu dans expression');
      Inc(ErrorCount);
    End;
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- Litteraux directs ---- }
  If (CurToken.Kind = TK_INTEGER) Or
     (CurToken.Kind = TK_FLOAT)   Or
     (CurToken.Kind = TK_STRING)  Or
     (CurToken.Kind = TK_HEREDOC) Or
     ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'undef')) Then
  Begin
    LitEval(CurToken, Res);
    ParserAdvance;
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- Variable scalaire $var ---- }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    NStr := CurToken.Val;
    Idx  := SymFind(NStr, '$');
    ParserAdvance;
    { Acces a un element de hash : signe $ suivi de accolade }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{') Then
    Begin
      HKIdx := SymFindCat(NStr, SC_HASH_VAR);
      If HKIdx >= 0 Then
      Begin
        ParseHashElemAccess(HKIdx, Res);
        ParsePostfixOps(Res);
        Exit;
      End;
    End;
    { Acces a un element de tableau : $arr[idx] }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      { Chercher d''abord un tableau @arr avec le meme nom }
      Idx := SymFindCat(NStr, SC_ARRAY_VAR);
      If Idx >= 0 Then
      Begin
        ParseArrElemAccess(Idx, Res);
        ParsePostfixOps(Res);
        Exit;
      End;
    End;
    If Idx < 0 Then
    Begin
      If Opts.Strict Then
        SymError('Variable non declaree : $' + NStr);
      ExprMakeNone(Res);
      Exit;
    End;
    Res := ExprMakeMem(Idx);
    ParsePostfixOps(Res);
    Exit;
  End;
  { ---- @arr en contexte scalaire -> nombre d''elements ---- }
  If (CurToken.Kind = TK_ARRAY_SIG) Or (CurToken.Kind = TK_HASH_SIG) Then
  Begin
    If CurToken.Kind = TK_ARRAY_SIG Then
    Begin
      { scalar(@arr) = mot [BP-Offset] = count }
      Idx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
      If Idx >= 0 Then
      Begin
        Str(SymTab[Idx].Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else
        EmitInstr('MOV', 'AX, 0');  { tableau inconnu -> 0 }
    End Else
    Begin
      { %hash en contexte scalaire -> count }
      Idx := SymFindCat(CurToken.Val, SC_HASH_VAR);
      If Idx >= 0 Then
      Begin
        Str(SymTab[Idx].Offset, S);
        EmitInstr('MOV', 'AX, WORD PTR [BP-' + S + ']');
      End Else
        EmitInstr('MOV', 'AX, 0');  { hash inconnu -> 0 }
    End;
    ParserAdvance;
    Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
    Res.ImmVal := 0; Res.Offset := 0;
    Exit;
  End;
  { ---- TK_IDENT : appel de fonction ou bareword ---- }
  If CurToken.Kind = TK_IDENT Then
  Begin
    NStr := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParseCallArgs;
      EmitInstr('CALL', PR_FN_PFX + NStr);
      If GCallArgCount > 0 Then
      Begin
        Str(GCallArgCount * 2, NCStr);
        EmitInstr('ADD', 'SP, ' + NCStr);
      End;
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Exit;
    End;
    If Opts.Warnings Then
      WriteLn('PERL86:', CurToken.Line, ': Avert: bareword ''', NStr, '''');
    ExprMakeNone(Res);
    Exit;
  End;
  { ---- Fin ou ponctuation non reconnue : ne rien consommer ---- }
End;

{ ---- CurTokIsInfixOp : le token courant est-il un op infix? }
{ Retourne True si le token peut etre un operateur binaire     }
{ infix, et place le nom de l''operateur dans OpStr.           }
{ Teste : TK_OP avec prec > 0, et TK_KEYWORD pour and/or etc. }
Function CurTokIsInfixOp(Var OpStr : TString) : Boolean;
Begin
  OpStr := '';
  CurTokIsInfixOp := False;
  If CurToken.Kind = TK_OP Then
  Begin
    OpStr := CurToken.Val;
    If BinOpPrec(OpStr) > 0 Then
    Begin CurTokIsInfixOp := True; Exit; End;
    OpStr := '';
    Exit;
  End;
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If (CurToken.Val = 'and') Or (CurToken.Val = 'or')  Or
       (CurToken.Val = 'xor') Or (CurToken.Val = 'eq')  Or
       (CurToken.Val = 'ne')  Or (CurToken.Val = 'lt')  Or
       (CurToken.Val = 'le')  Or (CurToken.Val = 'gt')  Or
       (CurToken.Val = 'ge')  Or (CurToken.Val = 'cmp') Or
       (CurToken.Val = 'x')   Then
    Begin
      OpStr := CurToken.Val;
      CurTokIsInfixOp := True;
    End;
  End;
End;

{ ---- ParseExprPrec : coeur du parseur Pratt - TODO 11 ------ }
{ Convention BX=Left, AX=Right pour les ops non-affectation.    }
{ Court-circuit inline pour && || //.                           }
{ Ternaire ? : avec labels _PRL_N.                              }
Procedure ParseExprPrec(MinPrec : Integer; Var Res : TExprVal);
Var
  Op    : TString;
  Prec  : Integer;
  Right : TExprVal;
  Left  : TExprVal;
  CondT : TExprVal;
  TSeq  : TString;
  TernL : Integer;
  LblA  : TString;
  LblB  : TString;
Begin
  ParsePrimary(Left);
  Res := Left;
  Repeat
    { ---- Ternaire '?' : traitement special avec labels ---- }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '?') And
       (MinPrec <= 4) Then
    Begin
      ParserAdvance;
      Inc(LabelSeq); TernL := LabelSeq; Str(TernL, TSeq);
      ExprLoad(Left);
      LblA := PR_LBL_PFX + 'TE' + TSeq;   { ternaire else }
      LblB := PR_LBL_PFX + 'TD' + TSeq;   { ternaire done }
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ',   LblA);
      ParseExprPrec(1, CondT);
      ExprLoad(CondT);
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      If Not ((CurToken.Kind = TK_OP) And (CurToken.Val = ':')) Then
      Begin
        WriteLn('PERL86:', CurToken.Line, ': Erreur: '':'' attendu');
        Inc(ErrorCount);
      End Else
        ParserAdvance;
      ParseExprPrec(4, Right);
      ExprLoad(Right);
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Operateur binaire standard ---- }
    If Not CurTokIsInfixOp(Op) Then Break;
    Prec := BinOpPrec(Op);
    If Prec < MinPrec Then Break;
    ParserAdvance;
    { ---- Court-circuit && : si Left faux, sauter Right ---- }
    If (Op = '&&') Or (Op = 'and') Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      LblB := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JZ',   LblA);
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitInstr('XOR', 'AX, AX');   { Left etait faux -> 0 }
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit || : si Left vrai, sauter Right ---- }
    If (Op = '||') Or (Op = 'or') Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      LblB := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ',  LblA);
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('SETNE', 'AL');
      EmitInstr('MOVZX', 'AX, AL');
      EmitInstr('JMP', LblB);
      EmitLabel(LblA);
      EmitInstr('MOV', 'AX, 1');    { Left etait vrai -> 1 }
      EmitLabel(LblB);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Court-circuit // (defined-or) : si Left defini (!=0) ---- }
    If Op = '//' Then
    Begin
      ExprLoad(Left);
      LblA := LabelGen(PR_LBL_PFX);
      EmitInstr('TEST', 'AX, AX');
      EmitInstr('JNZ',  LblA);   { defini : garder AX }
      If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
      Else ParseExprPrec(Prec + 1, Right);
      ExprLoad(Right);
      EmitLabel(LblA);
      Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
      Res.ImmVal := 0; Res.Offset := 0;
      Left := Res;
      Continue;
    End;
    { ---- Affectations (prec=3) : garder Left en EK_MEM ---- }
    If Prec = 3 Then
    Begin
      { Evaluer Right (IsRightAssoc pour toutes les affectations) }
      ParseExprPrec(Prec, Right);
      ExprLoad(Right);
      ExprEmitBinOp(Op, Left, Right, Res);
      Left := Res;
      Continue;
    End;
    { ---- Autres operateurs binaires : BX=Left, AX=Right ---- }
    If IsRightAssoc(Op) Then ParseExprPrec(Prec, Right)
    Else ParseExprPrec(Prec + 1, Right);
    { Charger Left dans BX avant de charger Right dans AX }
    ExprLoad(Left);
    EmitInstr('PUSH', 'AX');   { sauver Left }
    ExprLoad(Right);
    EmitInstr('POP', 'BX');    { BX = Left, AX = Right }
    ExprEmitBinOp(Op, Left, Right, Res);
    Left := Res;
  Until False;
  Res := Left;
End;

{ ---- ParseExpr : point d''entree principal des expressions -- }
{ Accepte tous les operateurs (precedence minimale = 1).        }
{ C''est la procedure a appeler depuis ParseStmt et les autres  }
{ contextes d''expressions.                                      }
Procedure ParseExpr(Var Res : TExprVal);
Begin
  ParseExprPrec(1, Res);
End;

{ ============================================================
  TODO 05 - TABLE DES SYMBOLES
  ============================================================ }

{ ---- SymWarn / SymError : messages contextuels -----------  }
Procedure SymWarn(Const Msg : TString);
Begin
  WriteLn('PERL86:', CurToken.Line, ': Avertissement: ', Msg);
  Inc(WarnCount);
End;

Procedure SymError(Const Msg : TString);
Begin
  WriteLn('PERL86:', CurToken.Line, ': Erreur: ', Msg);
  Inc(ErrorCount);
End;

{ ---- SymMangle : generer le nom mangle ASM d''un symbole -- }
{ Convention de nommage :                                      }
{   SC_FN             -> _PRF_nom                             }
{   SC_FILEHANDLE     -> nom (tel quel)                       }
{   SC_CONST          -> _PRV_PKG_nom                         }
{   SC_SCALAR/ARRAY/HASH/PARAM (our)  -> _PRV_PKG_nom         }
{   SC_SCALAR/ARRAY/HASH/PARAM (my)   -> _PRV_nom_Nseq        }
{     (les vars my sont sur la pile ; le label sert au debug)  }
Function SymMangle(Cat : TSymCat; IsMy : Boolean;
                   Const Name, Pkg : TString;
                   SeqN : Integer) : TString;
Var
  Seq : TString;
Begin
  Case Cat Of
    SC_FN :
      SymMangle := PR_FN_PFX + Name;
    SC_FILEHANDLE :
      SymMangle := Name;
  Else
    { SC_SCALAR, SC_ARRAY_VAR, SC_HASH_VAR, SC_PARAM, SC_PKG, SC_CONST }
    If IsMy Then
    Begin
      { Variable lexicale : suffixe de sequence pour unicite }
      Str(SeqN, Seq);
      SymMangle := PR_VAR_PFX + Name + '_' + Seq;
    End Else
    Begin
      { Variable globale our / constante : prefixe package }
      If Pkg = 'main' Then
        SymMangle := PR_VAR_PFX + Name
      Else
        SymMangle := PR_VAR_PFX + Pkg + '_' + Name;
    End;
  End;
End;

{ ---- SymAdd : ajouter un symbole dans la table ------------ }
{ Retourne l''indice du nouveau symbole, ou -1 en cas d''erreur }
{ IsMy    : portee lexicale (variable sur la pile)             }
{ IsOur   : portee package (variable dans DATA)               }
{ IsLocal : portee dynamique (sauvegarde/restauration pile)    }
Function SymAdd(Const Name : TString; Sigil : Char; Cat : TSymCat;
                TypeIdx : Integer;
                IsMy, IsOur, IsLocal : Boolean) : Integer;
Var
  R   : TSymRec;
  Seq : TString;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    SymError('Table des symboles saturee (MAX_SYM)');
    SymAdd := -1;
    Exit;
  End;
  { En mode strict, toute redeclaration est une erreur }
  If Opts.Strict And (SymFind(Name, Sigil) >= 0) And
     (Cat = SC_SCALAR) Then
    SymWarn('Redeclaration de ' + Sigil + Name);
  R.Name        := Name;
  R.SigilName   := Sigil + Name;
  R.Cat         := Cat;
  R.TypeIdx     := TypeIdx;
  R.IsMy        := IsMy;
  R.IsOur       := IsOur;
  R.IsLocal     := IsLocal;
  R.IsRef       := False;
  R.DeclLine    := CurToken.Line;
  R.ScopeLevel  := CurScope;
  { Offset dans le cadre de pile (IsMy ou IsLocal) }
  If IsMy Or IsLocal Then
  Begin
    Inc(CurFrameSize, 2);       { un scalaire = 1 mot de 2 octets }
    R.Offset := CurFrameSize;   { acces via [BP - Offset] }
  End Else
    R.Offset := 0;              { resoluble via MangledName dans DATA }
  { Nom mangle : generer un numero de sequence unique }
  Inc(LabelSeq);
  R.MangledName := SymMangle(Cat, IsMy, Name, CurPackage, LabelSeq);
  SymTab[SymCount] := R;
  SymAdd          := SymCount;
  Inc(SymCount);
  Inc(TotalSyms);
End;

{ ---- SymAddFn : raccourci pour declarer une sous-routine -- }
{ Retourne l''indice, ou -1. Toujours global (our implicite).   }
Function SymAddFn(Const Name : TString) : Integer;
Begin
  SymAddFn := SymAdd(Name, '&', SC_FN, TY_IDX_CODE,
                     False{ IsMy }, True{ IsOur }, False{ IsLocal });
End;

{ ---- SymFind : chercher un symbole par nom et sigil ------- }
{ Parcourt la table de bas en haut pour respecter la portee    }
{ lexicale (le symbole le plus recent a la priorite).          }
{ Sigil : ''$'' ''@'' ''%'' ''&'' (utiliser #0 pour toute categorie) }
{ Retourne l''indice dans SymTab, ou -1 si introuvable.         }
Function SymFind(Const Name : TString; Sigil : Char) : Integer;
Var
  I    : Integer;
  SCat : TSymCat;
Begin
  SymFind := -1;
  If Sigil = '&' Then SCat := SC_FN
  Else SCat := SC_SCALAR;  { valeur par defaut, non utilisee si Sigil=#0 }
  For I := SymCount - 1 DownTo 0 Do
  Begin
    If SymTab[I].Name <> Name Then Continue;
    If Sigil = #0 Then
    Begin
      { Chercher quelle que soit la categorie }
      SymFind := I; Exit;
    End;
    If Sigil = '&' Then
    Begin
      If SymTab[I].Cat = SC_FN Then Begin SymFind := I; Exit; End;
    End Else If Sigil = '$' Then
    Begin
      If SymTab[I].Cat In [SC_SCALAR, SC_PARAM, SC_CONST] Then
      Begin SymFind := I; Exit; End;
    End Else If Sigil = '@' Then
    Begin
      If SymTab[I].Cat = SC_ARRAY_VAR Then Begin SymFind := I; Exit; End;
    End Else If Sigil = '%' Then
    Begin
      If SymTab[I].Cat = SC_HASH_VAR Then Begin SymFind := I; Exit; End;
    End Else
    Begin
      { Sigil inconnu : comparer le premier caractere de SigilName }
      If (Length(SymTab[I].SigilName) > 0) And
         (SymTab[I].SigilName[1] = Sigil) Then
      Begin SymFind := I; Exit; End;
    End;
  End;
End;

{ ---- SymFindCat : chercher par nom et categorie exacte ---- }
Function SymFindCat(Const Name : TString; Cat : TSymCat) : Integer;
Var
  I : Integer;
Begin
  SymFindCat := -1;
  For I := SymCount - 1 DownTo 0 Do
    If (SymTab[I].Name = Name) And (SymTab[I].Cat = Cat) Then
    Begin
      SymFindCat := I;
      Exit;
    End;
End;

{ ---- SymFindOrError : chercher ou signaler une erreur ----- }
{ Utilisee quand une variable doit obligatoirement etre declaree }
{ (notamment en mode use strict).                              }
Function SymFindOrError(Const Name : TString; Sigil : Char) : Integer;
Var
  Idx : Integer;
Begin
  Idx := SymFind(Name, Sigil);
  If Idx < 0 Then
  Begin
    If Opts.Strict Then
      SymError('Variable non declaree: ' + Sigil + Name +
               ' (use strict actif)')
    Else
      SymWarn('Variable non declaree: ' + Sigil + Name);
  End;
  SymFindOrError := Idx;
End;

{ ---- SymEnterScope : entrer dans un nouveau bloc ---------- }
{ Sauvegarde l''index courant de SymCount pour restauration     }
{ lors de SymLeaveScope. Aussi utilise pour gerer le cadre     }
{ local d''une sous-routine (CurFrameSize).                     }
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE Then
    FatalError('Trop d''imbrications de blocs (MAX_SCOPE)');
  ScopeStack[ScopeTop] := SymCount;
  Inc(ScopeTop);
  Inc(CurScope);
End;

{ ---- SymLeaveScope : sortir du bloc courant --------------- }
{ Supprime les symboles my/local ajoutes dans ce bloc.         }
{ Les symboles our (globaux) sont compactes et conserves.      }
Procedure SymLeaveScope;
Var
  I, Base, NewCount : Integer;
Begin
  If ScopeTop = 0 Then
  Begin
    SymError('SymLeaveScope: pas de portee ouverte (erreur interne)');
    Exit;
  End;
  Dec(ScopeTop);
  Dec(CurScope);
  Base     := ScopeStack[ScopeTop];  { limite inferieure ancienne }
  { Conserver les symboles our (portee package) en compactant }
  NewCount := Base;
  For I := Base To SymCount - 1 Do
    If SymTab[I].IsOur Or (SymTab[I].Cat = SC_FN) Then
    Begin
      If NewCount <> I Then
        SymTab[NewCount] := SymTab[I];
      Inc(NewCount);
    End;
  SymCount := NewCount;
End;

{ ---- SymDump : affichage de la table (mode debug -d) ------ }
Procedure SymDump;
Var
  I   : Integer;
  CS  : TString;
Begin
  WriteLn('--- TABLE DES SYMBOLES (', SymCount, ' entrees) ---');
  For I := 0 To SymCount - 1 Do
  Begin
    Case SymTab[I].Cat Of
      SC_SCALAR    : CS := 'SCALAR';
      SC_ARRAY_VAR : CS := 'ARRAY ';
      SC_HASH_VAR  : CS := 'HASH  ';
      SC_PARAM     : CS := 'PARAM ';
      SC_FN        : CS := 'FN    ';
      SC_PKG       : CS := 'PKG   ';
      SC_CONST     : CS := 'CONST ';
      SC_FILEHANDLE: CS := 'FILEHD';
    End;
    Write('[', I, '] ', CS, ' ', SymTab[I].SigilName);
    Write(' scope=', SymTab[I].ScopeLevel);
    Write(' ofs=', SymTab[I].Offset);
    If SymTab[I].IsMy    Then Write(' my');
    If SymTab[I].IsOur   Then Write(' our');
    If SymTab[I].IsLocal Then Write(' local');
    WriteLn('  -> ', SymTab[I].MangledName);
  End;
  WriteLn('---');
End;

{ ============================================================
  TODO 06 - SYSTEME DE TYPES ET CONTEXTE
  ============================================================ }

{ ---- TypeSizeof : taille en octets d''un type --------------- }
{ Sur 8086 DOS : scalaire = 2 octets (mot 16 bits)             }
{   ref = 2 octets (pointeur near 16 bits)                     }
{   array/hash = 2 octets (pointeur vers bloc memoire)         }
Function TypeSizeof(TypeIdx : Integer) : Integer;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeSizeof := TypeTab[TypeIdx].Size
  Else
    TypeSizeof := 2;  { defaut : 1 mot }
End;

{ ---- TypeMangle : suffixe de type pour les labels ASM ------ }
{ Exemples : TY_IDX_SCALAR -> 'S', TY_IDX_ARRAY -> 'A', ...   }
{ Ces suffixes sont utilises dans les labels de runtime        }
{ _PRRT_CONCAT_S, _PRRT_PUSH_A, etc.                          }
Function TypeMangle(TypeIdx : Integer) : TString;
Begin
  Case TypeIdx Of
    TY_IDX_SCALAR : TypeMangle := 'S';
    TY_IDX_ARRAY  : TypeMangle := 'A';
    TY_IDX_HASH   : TypeMangle := 'H';
    TY_IDX_REF    : TypeMangle := 'R';
    TY_IDX_CODE   : TypeMangle := 'C';
    TY_IDX_UNDEF  : TypeMangle := 'U';
    TY_IDX_MIXED  : TypeMangle := 'M';
  Else
    TypeMangle := 'X';
  End;
End;

{ ---- TypeKindName : nom lisible d''un type (messages, debug) -}
Function TypeKindName(TypeIdx : Integer) : TString;
Begin
  If (TypeIdx >= 0) And (TypeIdx < TypeCount) Then
    TypeKindName := TypeTab[TypeIdx].Name
  Else
    TypeKindName := 'unknown';
End;

{ ---- TypeIsCompatible : deux types sont-ils compatibles ? -- }
{ Regles simplifiees pour 8086 DOS :                           }
{   - UNDEF est compatible avec tout (affectation d''undef)    }
{   - MIXED est compatible avec tout                           }
{   - Meme TypeIdx toujours compatible                         }
{   - SCALAR <-> REF : accepte (pointeur vs entier)            }
{   - Sinon : incompatible -> warning (pas erreur fatale)      }
Function TypeIsCompatible(SrcIdx, DstIdx : Integer) : Boolean;
Begin
  If (SrcIdx = DstIdx) Or
     (SrcIdx = TY_IDX_UNDEF) Or (DstIdx = TY_IDX_UNDEF) Or
     (SrcIdx = TY_IDX_MIXED) Or (DstIdx = TY_IDX_MIXED) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  { Scalaire <-> Reference : tolere (usage courant en Perl) }
  If ((SrcIdx = TY_IDX_SCALAR) And (DstIdx = TY_IDX_REF)) Or
     ((SrcIdx = TY_IDX_REF)    And (DstIdx = TY_IDX_SCALAR)) Then
  Begin
    TypeIsCompatible := True;
    Exit;
  End;
  TypeIsCompatible := False;
End;

{ ---- ExprIsBoolFalse : tester la faussete d''une expression - }
{ Perl boolean : faux = undef, 0 (entier), "" (chaine vide),   }
{   "0" (chaine contenant zero).                               }
{ Pour les immediats connus a la compilation, on peut           }
{ determiner la valeur booleenne sans emettre de code.         }
{ Retourne True si expr est CERTAINEMENT fausse (EK_IMM=0 ou   }
{ EK_NONE). Pour toute autre valeur -> False (incertain).      }
Function ExprIsBoolFalse(Const E : TExprVal) : Boolean;
Begin
  If E.Kind = EK_NONE Then
    ExprIsBoolFalse := True
  Else If (E.Kind = EK_IMM) And
          ((E.ImmVal = 0) Or (E.TypeIdx = TY_IDX_UNDEF)) Then
    ExprIsBoolFalse := True
  Else
    ExprIsBoolFalse := False;
End;

{ ---- ExprIsBoolTrue : tester la verite certaine a la compile }
{ Retourne True si on sait avec certitude que E est vraie.     }
Function ExprIsBoolTrue(Const E : TExprVal) : Boolean;
Begin
  If (E.Kind = EK_IMM) And
     (E.TypeIdx <> TY_IDX_UNDEF) And
     (E.ImmVal <> 0) Then
    ExprIsBoolTrue := True
  Else
    ExprIsBoolTrue := False;
End;

{ ---- TypeWarn : avertissement de type --------------------- }
Procedure TypeWarn(SrcIdx, DstIdx : Integer);
Begin
  WriteLn('PERL86:', CurToken.Line,
          ': Avertissement: conversion de type ',
          TypeKindName(SrcIdx), ' -> ', TypeKindName(DstIdx));
  Inc(WarnCount);
End;

{ ============================================================
  TODO 08 - SEGMENT DE DONNEES ET STATIQUES
  ============================================================ }

{ ---- EmitDataStr : emettre une chaine DB dans le segment DATA }
{ Format : label:         <- ligne du label                     }
{          DB  b,b,...,0  <- octets par tranches de 16          }
{ Caracteres printables (32..126 sauf '') = litteral MASM.      }
{ Autres : valeur decimale.                                     }
{ Le quote simple dans MASM se double : '' -> ''''              }
Procedure EmitDataStr(Const Lbl, S : TString);
Const
  CHUNK = 16;
Var
  I      : Integer;
  C      : Char;
  InQ    : Boolean;
  Line   : TString;
  Tmp    : TString;
  NeedSep: Boolean;
  Count  : Integer;
Begin
  EmitRaw(Lbl + ':');
  I      := 1;
  { Boucle sur tous les octets de S + 1 octet pour le zero final }
  While I <= Length(S) + 1 Do
  Begin
    Line    := '        DB  ';
    InQ     := False;
    NeedSep := False;
    Count   := 0;
    While (Count < CHUNK) And (I <= Length(S) + 1) Do
    Begin
      If I > Length(S) Then
      Begin
        { Zero final : fermer quote si ouverte }
        If InQ Then Begin Line := Line + ''''; InQ := False; End;
        If NeedSep Then Line := Line + ',';
        Line := Line + '0';
        NeedSep := True;
        Inc(I);
      End Else
      Begin
        C := S[I];
        If (Ord(C) >= 32) And (Ord(C) <= 126) And (C <> '''') Then
        Begin
          { Caractere imprimable (sauf quote simple traitee comme non-imprimable) }
          If Not InQ Then
          Begin
            If NeedSep Then Line := Line + ',';
            Line    := Line + '''';
            InQ     := True;
            NeedSep := False;
          End;
          Line := Line + C;
        End Else
        Begin
          { Caractere non imprimable ou quote : valeur decimale }
          If InQ Then Begin Line := Line + ''''; InQ := False; End;
          If NeedSep Then Line := Line + ',';
          Str(Ord(C), Tmp);
          Line    := Line + Tmp;
          NeedSep := True;
        End;
        Inc(I);
      End;
      Inc(Count);
    End;
    If InQ Then Line := Line + '''';
    EmitRaw(Line);
  End;
End;

{ ---- DataAddWord : ajouter une variable globale DK_WORD ----- }
{ Utilise pour : our $var (valeur initiale 0), use constant N.  }
{ Retourne l''indice dans DataTab, ou -1 si sature.              }
Function DataAddWord(Const ALbl : TString; AVal : LongInt) : Integer;
Begin
  DataAddWord := DataAdd(ALbl, DK_WORD, AVal, '');
End;

{ ---- DataAddConst : constante use constant NOM => val ------- }
{ Si AStr <> '' -> DK_STR ; sinon -> DK_WORD.                  }
Function DataAddConst(Const ALbl : TString; AVal : LongInt;
                      Const AStr : TString) : Integer;
Begin
  If AStr <> '' Then
    DataAddConst := DataAdd(ALbl, DK_STR, 0, AStr)
  Else
    DataAddConst := DataAdd(ALbl, DK_WORD, AVal, '');
End;

{ ---- DataFindByLabel : chercher une entree par son label ---- }
{ Retourne l''indice dans DataTab, ou -1 si introuvable.         }
Function DataFindByLabel(Const ALbl : TString) : Integer;
Var
  I : Integer;
Begin
  DataFindByLabel := -1;
  For I := 0 To DataCount - 1 Do
    If DataTab[I].LblName = ALbl Then
    Begin
      DataFindByLabel := I;
      Exit;
    End;
End;

{ ---- DataDump : affichage de la table de donnees (debug) ---- }
Procedure DataDump;
Var
  I  : Integer;
  KS : TString;
Begin
  WriteLn('--- TABLE DE DONNEES (', DataCount, ' entrees) ---');
  For I := 0 To DataCount - 1 Do
  Begin
    Case DataTab[I].Kind Of
      DK_WORD      : KS := 'DW';
      DK_BYTE      : KS := 'DB';
      DK_STR       : KS := 'STR';
      DK_ARRAY_BLK : KS := 'ARR';
    End;
    Write('[', I, '] ', KS, ' ', DataTab[I].LblName);
    If DataTab[I].Kind = DK_STR Then
      WriteLn(' = "', Copy(DataTab[I].StrVal, 1, 32), '.."')
    Else
    Begin
      WriteLn(' = ', DataTab[I].IntVal);
    End;
  End;
  WriteLn('---');
End;

{ ============================================================
  TODO 09 - VARIABLES ET AFFECTATIONS
  ============================================================ }

{ ---- ExprMakeMem : construire EK_MEM pour un symbole ------- }
{ Convention EK_MEM :                                           }
{   ImmVal=1, Offset=n  -> variable locale my/local [BP-n]    }
{   ImmVal=0, Offset=di -> donnee statique DataTab[di]         }
Function ExprMakeMem(SymIdx : Integer) : TExprVal;
Var
  Res : TExprVal;
  Di  : Integer;
Begin
  Res.TypeIdx := SymTab[SymIdx].TypeIdx;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  Res.Kind    := EK_MEM;
  If SymTab[SymIdx].IsMy Or SymTab[SymIdx].IsLocal Then
  Begin
    { Variable locale : acces [BP - Offset] }
    Res.ImmVal := 1;
    Res.Offset := SymTab[SymIdx].Offset;
  End Else
  Begin
    { Variable globale our : dans le segment DATA }
    Di := DataFindByLabel(SymTab[SymIdx].MangledName);
    If Di >= 0 Then
      Res.Offset := Di
    Else
      Res.Offset := 0;   { securite }
  End;
  ExprMakeMem := Res;
End;

{ ---- EmitAllocLocal : allouer des octets sur la pile ------- }
{ Emet SUB SP, Sz pour reserver de l''espace pour une locale.   }
Procedure EmitAllocLocal(Sz : Integer);
Var
  S : TString;
Begin
  Str(Sz, S);
  EmitInstr('SUB', 'SP, ' + S);
End;

{ ---- EmitStoreScalar : stocker AX dans une lvalue ---------- }
{ Si Lv.ImmVal=1 -> MOV WORD PTR [BP-n], AX (locale)          }
{ Si Lv.ImmVal=0 -> MOV [label], AX          (statique)        }
Procedure EmitStoreScalar(Const Lv : TExprVal);
Var
  S : TString;
Begin
  If Lv.Kind <> EK_MEM Then Exit;  { rien a stocker }
  If Lv.ImmVal = 2 Then
  Begin
    { Element tableau dynamique : adresse deja dans BX }
    EmitInstr('MOV', '[BX], AX');
  End Else If Lv.ImmVal = 1 Then
  Begin
    { Variable locale my/local }
    Str(Lv.Offset, S);
    EmitInstr('MOV', 'WORD PTR [BP-' + S + '], AX');
  End Else
  Begin
    { Donnee statique our }
    If (Lv.Offset >= 0) And (Lv.Offset < DataCount) Then
      EmitInstr('MOV', '[' + DataTab[Lv.Offset].LblName + '], AX')
    Else
      EmitComment('EmitStoreScalar: indice DataTab invalide');
  End;
End;

{ ---- ParseVarDecl : declaration my/our/local $var [= expr] - }
{ Ajoute le symbole dans SymTab, emet l''allocation et l''init.  }
Procedure ParseVarDecl;
Var
  Kw        : TString;
  IsMy      : Boolean;
  IsOur     : Boolean;
  IsLoc     : Boolean;
  Sigil     : Char;
  VName     : TString;
  Cat       : TSymCat;
  TIdx      : Integer;
  Idx       : Integer;
  E         : TExprVal;
  Lv        : TExprVal;
  OffS      : TString;
  ElemCount : Integer;
  TmpS      : TString;
  KeyCount  : Integer;
  KeyStr    : TString;
  KeyLbl    : TString;
  SlotIdx   : Integer;
  HKIdx     : Integer;   { indice entrée dans HashKeyTab }
  ParamNames: Array[0..MAX_PARAM - 1] Of TString;  { TODO 17 }
  I         : Integer;   { TODO 17 : index de boucle }
  Idx2      : Integer;   { TODO 17 : second indice SymTab }
Begin
  Kw    := CurToken.Val;
  IsMy  := Kw = 'my';
  IsOur := Kw = 'our';
  IsLoc := Kw = 'local';
  ParserAdvance;   { consommer 'my'/'our'/'local' }
  { TODO 17 : my ($a, $b, ...) = @_ : liste de parametres }
  If (Kw = 'my') And (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
  Begin
    ParserAdvance;  { consommer '(' }
    { Collecter les noms de params scalaires }
    Idx := 0;
    While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
              (CurToken.Kind <> TK_EOF) And (Idx < MAX_PARAM) Do
    Begin
      If CurToken.Kind = TK_SCALAR Then
      Begin
        ParamNames[Idx] := CurToken.Val;
        ParserAdvance;
        Inc(Idx);
      End;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Consommer '=' }
    If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
    Begin
      ParserAdvance;
      { Verifier '@_' ou expression liste }
      If CurToken.Kind = TK_ARRAY_SIG Then
      Begin
        If CurToken.Val = '_' Then
        Begin
          { Assignation depuis @_ : [BP+4+(N-1-k)*2] pour param k }
          ParserAdvance;  { consommer '@_' }
          ElemCount := Idx;  { nombre de params }
          For I := 0 To ElemCount - 1 Do
          Begin
            Idx2 := SymAdd(ParamNames[I], '$', SC_SCALAR, TY_IDX_SCALAR, True, False, False);
            EmitAllocLocal(2);
            Str(SymTab[Idx2].Offset, OffS);
            EmitComment('param $' + ParamNames[I] + ' depuis @_[' + ParamNames[I] + ']');
            { arg[k] = [BP + 4 + (N-1-k)*2] avec notre convention push gauche->droite }
            Str(4 + (ElemCount - 1 - I) * 2, TmpS);
            EmitInstr('MOV', 'AX, WORD PTR [BP+' + TmpS + ']');
            EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], AX');
          End;
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
          Exit;
        End;
      End;
      { Fallback : evaluer l''expression liste et ignorer }
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
    Exit;
  End;
  { Determiner le sigil et le type associe }
  If CurToken.Kind = TK_SCALAR Then
  Begin
    Sigil := '$';  Cat := SC_SCALAR;    TIdx := TY_IDX_SCALAR;
  End Else If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    Sigil := '@';  Cat := SC_ARRAY_VAR; TIdx := TY_IDX_ARRAY;
  End Else If CurToken.Kind = TK_HASH_SIG Then
  Begin
    Sigil := '%';  Cat := SC_HASH_VAR;  TIdx := TY_IDX_HASH;
  End Else
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: variable attendue apres ''', Kw, '''');
    Inc(ErrorCount);
    Exit;
  End;
  VName := CurToken.Val;
  ParserAdvance;   { consommer le nom de variable }
  { Enregistrer dans la table des symboles }
  Idx := SymAdd(VName, Sigil, Cat, TIdx, IsMy, IsOur, IsLoc);
  { Allouer / reserver l''espace selon la portee }
  If IsMy Or IsLoc Then
  Begin
    If Cat = SC_ARRAY_VAR Then
    Begin
      { Tableau @arr : mot de count + MAX_ARR_ELEMS slots de 2 octets }
      EmitAllocLocal(2);   { SymAdd a deja incremente CurFrameSize de 2 }
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init @' + VName + ' : count=0, ' + OffS + ' slots');
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
      { Reserver les slots elements : CurFrameSize avance manuellement }
      Inc(CurFrameSize, 2 * MAX_ARR_ELEMS);
      Str(2 * MAX_ARR_ELEMS, TmpS);
      EmitInstr('SUB', 'SP, ' + TmpS);
      { Init optionnelle depuis liste : my @arr = (e1, e2, ...) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;   { consommer '=' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;  { consommer '(' }
        ElemCount := 0;
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                  (CurToken.Kind <> TK_EOF) And
                  (ElemCount < MAX_ARR_ELEMS) Do
        Begin
          ParseExpr(E);
          ExprLoad(E);
          { Stocker AX dans arr[ElemCount] = [BP - (Offset+2 + ElemCount*2)] }
          Str(SymTab[Idx].Offset + 2 + ElemCount * 2, TmpS);
          EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], AX');
          Inc(ElemCount);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        { Mettre a jour le count }
        Str(SymTab[Idx].Offset, OffS);
        Str(ElemCount, TmpS);
        EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], ' + TmpS);
      End;
      Exit;
    End Else If Cat = SC_HASH_VAR Then
    Begin
      { Hash %h : mot de count + MAX_HASH_PAIRS*(key_ptr+val) slots }
      EmitAllocLocal(2);   { CurFrameSize += 2, count word }
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init %' + VName + ' : count=0, ' + OffS);
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
      Inc(CurFrameSize, MAX_HASH_PAIRS * 4);
      Str(MAX_HASH_PAIRS * 4, TmpS);
      EmitInstr('SUB', 'SP, ' + TmpS);
      { Init optionnelle : my %h = (cle => val, ...) }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
      Begin
        ParserAdvance;   { consommer '=' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
          ParserAdvance;  { consommer '(' }
        KeyCount := 0;
        While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
                  (CurToken.Kind <> TK_EOF) And
                  (KeyCount < MAX_HASH_PAIRS) Do
        Begin
          { -- Parse cle (bareword, chaine ou scalaire) -- }
          KeyStr := '';
          If (CurToken.Kind = TK_IDENT) Or
             ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val <> 'undef')) Then
          Begin
            KeyStr := CurToken.Val;   { bareword : stringification }
            ParserAdvance;
          End Else If CurToken.Kind = TK_STRING Then
          Begin
            KeyStr := CurToken.Val;
            ParserAdvance;
          End Else
          Begin
            { Cle variable ou complexe : traiter comme expr mais pas stocker }
            ParseExpr(E);
            ExprLoad(E);
            KeyStr := '__var__';
          End;
          { Consommer '=>' ou ',' separant cle et valeur }
          If (CurToken.Kind = TK_OP) And (CurToken.Val = '=>') Then
            ParserAdvance
          Else If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
          { -- Parse valeur -- }
          ParseExpr(E);
          ExprLoad(E);   { AX = valeur }
          { -- Enregistrer la paire cle/valeur -- }
          If KeyStr <> '__var__' Then
          Begin
            SlotIdx := -1;
            HKIdx   := HashSlotFind(Idx, KeyStr);
            If HKIdx < 0 Then
            Begin
              { Ajouter la cle dans DATA }
              ElemCount := DataAddStr(KeyStr);
              KeyLbl    := DataTab[ElemCount].LblName;
              SlotIdx   := HashSlotAdd(Idx, KeyStr, KeyLbl);
            End Else
            Begin
              SlotIdx := HashKeyTab[HKIdx].SlotIdx;
              KeyLbl  := HashKeyTab[HKIdx].KeyLbl;
            End;
            { key_ptr[SlotIdx] = OFFSET KeyLbl }
            Str(SymTab[Idx].Offset + 2 + SlotIdx * 4, TmpS);
            EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], OFFSET ' + KeyLbl);
            { val[SlotIdx] = AX }
            Str(SymTab[Idx].Offset + 4 + SlotIdx * 4, TmpS);
            EmitInstr('MOV', 'WORD PTR [BP-' + TmpS + '], AX');
          End;
          Inc(KeyCount);
          If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
            ParserAdvance;
        End;
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
          ParserAdvance;
        { Mettre a jour count }
        Str(SymTab[Idx].Offset, OffS);
        Str(KeyCount, TmpS);
        EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], ' + TmpS);
      End;
      Exit;
    End Else
    Begin
      { Variable scalaire : SymAdd a incremente CurFrameSize, emet SUB SP, 2 }
      EmitAllocLocal(2);
      Str(SymTab[Idx].Offset, OffS);
      EmitComment('init my ' + Sigil + VName);
      EmitInstr('MOV', 'WORD PTR [BP-' + OffS + '], 0');
    End;
  End Else If IsOur Then
  Begin
    { Variable globale : reservee dans _DATA }
    DataAddWord(SymTab[Idx].MangledName, 0);
    EmitComment('our ' + Sigil + VName + ' dans _DATA');
  End;
  { Affectation initiale optionnelle : my $x = expr }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '=') Then
  Begin
    ParserAdvance;   { consommer ''='' }
    ParseExpr(E);
    ExprLoad(E);
    { Stocker AX dans la variable nouvellement declaree }
    Lv := ExprMakeMem(Idx);
    EmitStoreScalar(Lv);
  End;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS PRIMAIRES
  ============================================================ }

{ ---- ParseCallArgs : evaluer + empiler les arguments -------- }
{ Parse ''('' expr, expr, ... '')'' ; empile chaque arg en AX.   }
{ Retourne le nombre d''arguments empiles dans N (var globale).  }
Procedure ParseCallArgs;
Var
  A    : TExprVal;
  ArgN : Integer;
Begin
  ArgN := 0;
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(')) Then
  Begin GCallArgCount := 0; Exit; End;
  ParserAdvance;   { consommer '(' }
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) And
        (CurToken.Kind <> TK_EOF) Do
  Begin
    ParseExpr(A);
    ExprLoad(A);
    EmitInstr1('PUSH AX');
    Inc(ArgN);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance
    Else
      Break;
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance
  Else
  Begin
    WriteLn('PERL86:', CurToken.Line, ': Erreur: '')'' attendu dans appel');
    Inc(ErrorCount);
  End;
  GCallArgCount := ArgN;
End;

{ ---- EmitIncrDecr : ++ ou -- avec effet de bord ------------ }
{ Pre=True  -> pre  : inc d''abord, puis charge AX dans Res     }
{ Pre=False -> post : charge AX d''abord, puis inc dans memoire  }
Procedure EmitIncrDecr(Const Lv : TExprVal; IsInc : Boolean; Pre : Boolean;
                       Var Res : TExprVal);
Var
  S      : TString;
  Addr   : TString;
  LvKind : TExprKind;   { copie locale : Lv et Res peuvent etre aliases }
  LvImmV : LongInt;
  LvOff  : Integer;
Begin
  { Copier les champs de Lv avant de toucher a Res (aliasing possible) }
  LvKind := Lv.Kind;
  LvImmV := Lv.ImmVal;
  LvOff  := Lv.Offset;
  Res.Kind    := EK_AX;
  Res.TypeIdx := TY_IDX_SCALAR;
  Res.ImmVal  := 0;
  Res.Offset  := 0;
  If LvKind <> EK_MEM Then
  Begin
    EmitComment('++ / -- sur non-lvalue : ignore');
    EmitInstr('MOV', 'AX, 0');
    Exit;
  End;
  If LvImmV = 1 Then
  Begin
    Str(LvOff, S);
    Addr := 'WORD PTR [BP-' + S + ']';
  End Else
  Begin
    If (LvOff >= 0) And (LvOff < DataCount) Then
      Addr := 'WORD PTR [' + DataTab[LvOff].LblName + ']'
    Else
    Begin
      EmitComment('++ / -- : indice DataTab invalide');
      EmitInstr('MOV', 'AX, 0');
      Exit;
    End;
  End;
  If Pre Then
  Begin
    If IsInc Then EmitInstr('INC', Addr)
    Else          EmitInstr('DEC', Addr);
    EmitInstr('MOV', 'AX, ' + Addr);
  End Else
  Begin
    EmitInstr('MOV', 'AX, ' + Addr);
    If IsInc Then EmitInstr('INC', Addr)
    Else          EmitInstr('DEC', Addr);
  End;
End;

{ ---- ParsePostfixOps : operateurs postfixe apres une primaire }
{ Boucle sur post-++ post-- .                                    }
Procedure ParsePostfixOps(Var Res : TExprVal);
Var
  ArgCnt : Integer;
  S      : TString;
Begin
  Repeat
    If CurToken.Kind = TK_OP Then
    Begin
      If CurToken.Val = '++' Then
      Begin ParserAdvance; EmitIncrDecr(Res, True,  False, Res); Continue; End;
      If CurToken.Val = '--' Then
      Begin ParserAdvance; EmitIncrDecr(Res, False, False, Res); Continue; End;
      { TODO 17 : appel via coderef $f->(args) }
      If CurToken.Val = '->' Then
      Begin
        ParserAdvance;  { consommer '->' }
        If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
        Begin
          ExprLoad(Res);         { AX = adresse de la sous-routine }
          EmitInstr('MOV', 'BX, AX');  { sauver dans BX }
          ParseCallArgs;
          ArgCnt := GCallArgCount;
          EmitInstr('CALL', 'BX');
          If ArgCnt > 0 Then
          Begin
            Str(ArgCnt * 2, S);
            EmitInstr('ADD', 'SP, ' + S);
          End;
          Res.Kind := EK_AX; Res.TypeIdx := TY_IDX_SCALAR;
          Res.ImmVal := 0; Res.Offset := 0;
          Continue;
        End;
      End;
    End;
    Break;
  Until False;
End;

{ ============================================================
  TODO 12 - PRINT / SAY / PRINTF / WARN / DIE
  ============================================================ }

{ ---- EmitPrintVal : emet AX ou chaine statique sur handle -- }
{ BXval = '1' (STDOUT), '2' (STDERR), '0' (STDIN)             }
{ Chaine statique DK_STR -> MOV SI,OFFSET lbl + _PRRT_STRLEN  }
{ Sinon : ExprLoad -> AX puis _PRRT_ITOA + _PRRT_STRLEN        }
Procedure EmitPrintVal(Const BXval : TString; Var E : TExprVal);
Var
  DidStr : Boolean;
  Idx    : Integer;
Begin
  DidStr := False;
  { Chaine statique dans DataTab }
  If (E.Kind = EK_MEM) And (E.ImmVal = 0) Then
  Begin
    Idx := E.Offset;
    If (Idx >= 0) And (Idx < DataCount) And (DataTab[Idx].Kind = DK_STR) Then
    Begin
      EmitInstr('MOV', 'SI, OFFSET ' + DataTab[Idx].LblName);
      EmitInstr('CALL', '_PRRT_STRLEN');
      EmitInstr('MOV', 'CX, AX');
      EmitInstr('MOV', 'BX, ' + BXval);
      EmitInstr('CALL', '_PRRT_PRINT');
      DidStr := True;
    End;
  End;
  If Not DidStr Then
  Begin
    { Valeur entiere : charger AX puis convertir via _PRRT_ITOA }
    ExprLoad(E);
    { S'assurer que le buffer ITOA est dans DataTab }
    If DataFindByLabel('_PRRT_IBUF') < 0 Then
    Begin
      Idx := DataAdd('_PRRT_IBUF', DK_ARRAY_BLK, 0, '');
      If Idx >= 0 Then DataTab[Idx].ElemCount := 8;  { 8 DW = 16 octets }
    End;
    EmitInstr('MOV', 'DI, OFFSET _PRRT_IBUF');
    EmitInstr('CALL', '_PRRT_ITOA');
    EmitInstr('MOV', 'SI, DI');
    EmitInstr('CALL', '_PRRT_STRLEN');
    EmitInstr('MOV', 'CX, AX');
    EmitInstr('MOV', 'BX, ' + BXval);
    EmitInstr('CALL', '_PRRT_PRINT');
  End;
End;

{ ---- ParsePrintStmt : print / say / printf / warn / die --- }
{ CurToken.Val = le mot-cle. Le consomme puis parse la liste.  }
Procedure ParsePrintStmt;
Var
  KW    : TString;
  BXval : TString;
  IsSay : Boolean;
  IsDie : Boolean;
  E     : TExprVal;
Begin
  KW    := CurToken.Val;
  ParserAdvance;                            { consommer le mot-cle }
  BXval := '1';                             { STDOUT par defaut }
  IsSay := (KW = 'say');
  IsDie := (KW = 'die');
  If (KW = 'warn') Or IsDie Then BXval := '2';  { STDERR }
  { Filehandle explicite : STDOUT / STDERR / STDIN sans sigil }
  If CurToken.Kind = TK_IDENT Then
  Begin
    If      CurToken.Val = 'STDOUT' Then Begin BXval := '1'; ParserAdvance; End
    Else If CurToken.Val = 'STDERR' Then Begin BXval := '2'; ParserAdvance; End
    Else If CurToken.Val = 'STDIN'  Then Begin BXval := '0'; ParserAdvance; End;
    { Sinon : identifiant inconnu -> traiter comme premiere expression }
  End;
  { printf : note dans le commentaire ASM }
  If KW = 'printf' Then
    EmitComment('printf : format interprete simple (TODO 20)');
  { Evaluer et imprimer chaque argument de la liste }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) And
         (CurToken.Kind <> TK_EOF) Then
  Begin
    ParseExpr(E);
    EmitPrintVal(BXval, E);
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then Break;
      If CurToken.Kind = TK_EOF Then Break;
      ParseExpr(E);
      EmitPrintVal(BXval, E);
    End;
  End;
  { say : saut de ligne final via _PRRT_PRINTLN }
  If IsSay Then
  Begin
    EmitInstr('MOV', 'BX, ' + BXval);
    EmitInstr('CALL', '_PRRT_PRINTLN');
  End;
  { die : terminer le programme avec code 255 }
  If IsDie Then
  Begin
    EmitInstr('MOV', 'AX, 4CFFh');
    EmitInstr('INT', '21h');
  End;
  { Consommer le '';'' de fin de statement }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
    ParserAdvance;
End;

{ ============================================================
  TODO 13 - IF / ELSIF / ELSE / UNLESS + MODIFICATEURS DE STATEMENT
  ============================================================ }

{ ---- ParseBlock : parse un bloc de stmts avec portee lexicale ---- }
Procedure ParseBlock;
Begin
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '{')) Then
  Begin
    WriteLn('PERL86:', CurToken.Line,
            ': Erreur: ''{'' attendu pour bloc, obtenu ''', CurToken.Val, '''');
    Inc(ErrorCount);
    Exit;
  End;
  ParserAdvance;   { consommer '{' }
  SymEnterScope;
  While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
            (CurToken.Kind <> TK_EOF) Do
    ParseStmt;
  SymLeaveScope;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then
    ParserAdvance;  { consommer accolade fermante }
End;

{ ---- ParseIfStmt : if/unless/elsif/else ------------------- }
{ if (cond) BLOC [elsif (cond) BLOC]* [else BLOC]             }
{ unless (cond) BLOC [else BLOC]  (condition inversee)        }
Procedure ParseIfStmt;
Var
  KW       : TString;
  IsUnless : Boolean;
  LblNext  : TString;
  LblEnd   : TString;
  Cond     : TExprVal;
Begin
  KW       := CurToken.Val;   { 'if' ou 'unless' }
  IsUnless := (KW = 'unless');
  ParserAdvance;               { consommer 'if' ou 'unless' }
  LblEnd  := LabelGen('_PRL_ENDIF_');
  LblNext := LabelGen('_PRL_ELSE_');
  { Evaluer la condition (parentheses optionnelles) }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  ParseExpr(Cond);
  ExprLoad(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('TEST', 'AX, AX');
  If IsUnless Then
    EmitInstr('JNZ', LblNext)  { unless: sauter vers else/fin si VRAI }
  Else
    EmitInstr('JZ', LblNext);  { if: sauter vers else/fin si FAUX }
  { Bloc then }
  ParseBlock;
  { Chaines elsif }
  While (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'elsif') Do
  Begin
    EmitInstr('JMP', LblEnd);
    EmitLabel(LblNext);
    LblNext := LabelGen('_PRL_ELSE_');
    ParserAdvance;  { consommer 'elsif' }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
    ParseExpr(Cond);
    ExprLoad(Cond);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblNext);
    ParseBlock;
  End;
  { Saut vers la fin + etiquette de la branche suivante/else }
  EmitInstr('JMP', LblEnd);
  EmitLabel(LblNext);
  { Bloc else optionnel }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'else') Then
  Begin
    ParserAdvance;  { consommer 'else' }
    ParseBlock;
  End;
  EmitLabel(LblEnd);
End;

{ ============================================================
  TODO 14 - BOUCLES : while / until / for / foreach / do
  ============================================================ }

{ ---- LoopPush / LoopPop : gestion de la pile de boucles --- }
Procedure LoopPush(Const BrkLbl, ContLbl, RedoLbl : TString);
Begin
  If LoopTop >= MAX_LOOP_NEST Then
  Begin
    WriteLn('PERL86: Erreur: Boucles trop imbriquees (max=', MAX_LOOP_NEST, ')');
    Inc(ErrorCount);
    Exit;
  End;
  LoopBreakLbl[LoopTop] := BrkLbl;
  LoopContLbl[LoopTop]  := ContLbl;
  LoopRedoLbl[LoopTop]  := RedoLbl;
  Inc(LoopTop);
End;

Procedure LoopPop;
Begin
  If LoopTop > 0 Then Dec(LoopTop);
End;

{ ---- ParseWhileStmt : while/until (cond) BLOC [continue BL] }
{ CurToken.Val = 'while' ou 'until'                            }
Procedure ParseWhileStmt;
Var
  IsUntil : Boolean;
  LblTop  : TString;
  LblEnd  : TString;
  LblCont : TString;
  Cond    : TExprVal;
Begin
  IsUntil := (CurToken.Val = 'until');
  ParserAdvance;  { consommer 'while'/'until' }
  LblTop  := LabelGen('_PRL_WTOP_');
  LblEnd  := LabelGen('_PRL_WEND_');
  LblCont := LabelGen('_PRL_WCNT_');
  LoopPush(LblEnd, LblCont, LblTop);
  EmitLabel(LblTop);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  ParseExpr(Cond);
  ExprLoad(Cond);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('TEST', 'AX, AX');
  If IsUntil Then
    EmitInstr('JNZ', LblEnd)   { until: sortir si VRAI }
  Else
    EmitInstr('JZ', LblEnd);   { while: sortir si FAUX }
  ParseBlock;
  { bloc continue (optionnel) }
  EmitLabel(LblCont);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'continue') Then
  Begin
    ParserAdvance;
    ParseBlock;
  End;
  EmitInstr('JMP', LblTop);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ---- ParseForStmt : for (init; cond; incr) BLOC (style C) -- }
Procedure ParseForStmt;
Var
  LblTop  : TString;
  LblEnd  : TString;
  LblIncr : TString;
  Cond    : TExprVal;
  Dummy   : TExprVal;
Begin
  If Not GKwConsumed Then ParserAdvance;  { consommer 'for' }
  GKwConsumed := False;
  LblTop  := LabelGen('_PRL_FTOP_');
  LblEnd  := LabelGen('_PRL_FEND_');
  LblIncr := LabelGen('_PRL_FINCR_');
  LoopPush(LblEnd, LblIncr, LblTop);
  { Parenthese ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  { Init : my $i = expr ; ou expr ; ou juste ; }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'my') Or (CurToken.Val = 'our')) Then
    ParseVarDecl
  Else If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(Dummy);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  { Test de condition }
  EmitLabel(LblTop);
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
  Begin
    ParseExpr(Cond);
    ExprLoad(Cond);
    EmitInstr('TEST', 'AX, AX');
    EmitInstr('JZ', LblEnd);
  End;
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then ParserAdvance;
  { Sauvegarder l'expression d'incrementation a la fin du bloc }
  { On emet un JMP vers le corps, puis l'increment, puis JMP LblTop }
  { Structure : LblTop; [cond]; JZ LblEnd; JMP LblBody; }
  {             LblIncr: [incr]; JMP LblTop; }
  {             LblBody: [bloc]; JMP LblIncr; LblEnd: }
  { Simple : on place l'increment dans le "continue" }
  { Pour simplifier : on emmet l'increment inline apres le corps }
  { via goto LblIncr apres le bloc, LblIncr: [incr] JMP LblTop }
  { On doit lire l'expr incr maintenant et la "stocker" - impossible }
  { Solution : lire et ignorer l'incr sur le plan textuel est mauvais }
  { On emet: JMP LblBody; LblIncr: [incr]; JMP LblTop; LblBody: [bloc]; JMP LblIncr }
  EmitInstr('JMP', '_PRL_FBOD_' + Copy(LblTop, 10, 20));
  EmitLabel(LblIncr);
  { Lire l'expression d'incrementation }
  If Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')')) Then
    ParseExpr(Dummy);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
  EmitInstr('JMP', LblTop);
  EmitLabel('_PRL_FBOD_' + Copy(LblTop, 10, 20));
  ParseBlock;
  EmitInstr('JMP', LblIncr);
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ---- ParseForeachStmt : foreach [my $var] (LIST) BLOC ------- }
Procedure ParseForeachStmt;
Var
  VarName    : TString;
  SymIdx     : Integer;
  LblTop     : TString;
  LblEnd     : TString;
  LblCont    : TString;
  ListLbl    : TString;
  CntLbl     : TString;
  IdxLbl     : TString;
  E          : TExprVal;
  HasVar     : Boolean;
  RangeStart : TExprVal;
  RangeEnd   : TExprVal;
  IsRange    : Boolean;
  DummyE     : TExprVal;
Begin
  If Not GKwConsumed Then ParserAdvance;  { consommer 'foreach'/'for' }
  GKwConsumed := False;
  LblTop  := LabelGen('_PRL_EITOP_');
  LblEnd  := LabelGen('_PRL_EIEND_');
  LblCont := LabelGen('_PRL_EICNT_');
  HasVar  := False;
  IsRange := False;
  SymIdx  := -1;
  VarName := '_';
  { Variable d'iteration optionnelle : my $var }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'my') Then
  Begin
    ParserAdvance;  { consommer 'my' }
    If CurToken.Kind = TK_SCALAR Then
    Begin
      VarName := CurToken.Val;
      ParserAdvance;
      SymIdx := SymAdd(VarName, '$', SC_SCALAR, TY_IDX_SCALAR,
                       True, False, False);
      If SymIdx >= 0 Then EmitAllocLocal(2);
      HasVar := True;
    End;
  End;
  LoopPush(LblEnd, LblCont, LblTop);
  { Parenthese ouvrante }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
  { Detecter plage A..B }
  ParseExpr(RangeStart);
  If (CurToken.Kind = TK_OP) And (CurToken.Val = '..') Then
  Begin
    IsRange := True;
    ParserAdvance;  { consommer '..' }
    ParseExpr(RangeEnd);
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Allouer compteur de boucle sur la pile }
    CntLbl := LabelGen('_PRL_FECNT_');
    { Chargement de la valeur de debut dans $var et le compteur }
    ExprLoad(RangeStart);
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'WORD PTR [BP-' + CntLbl + '], AX');
    End;
    EmitLabel(LblTop);
    { Test : compteur <= fin }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'AX, WORD PTR [BP-' + CntLbl + ']');
    End Else
      EmitInstr('MOV', 'AX, 0');
    ExprLoad(RangeEnd);
    EmitInstr('XCHG', 'AX, BX');
    EmitInstr('MOV', 'AX, BX');
    { BX = courant, AX charge RangeEnd - on veut courant <= fin }
    { En fait: charger courant dans BX, fin dans AX }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'BX, WORD PTR [BP-' + CntLbl + ']');
      ExprLoad(RangeEnd);
    End Else
      EmitInstr('MOV', 'BX, 0');
    EmitInstr('CMP', 'BX, AX');
    EmitInstr('JG', LblEnd);
    LoopPush(LblEnd, LblCont, LblTop);
    ParseBlock;
    EmitLabel(LblCont);
    { Incrementer $var }
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('INC', 'WORD PTR [BP-' + CntLbl + ']');
    End;
    EmitInstr('JMP', LblTop);
    EmitLabel(LblEnd);
    LoopPop;
  End Else
  Begin
    { Liste simple : foreach (expr, ...) }
    { Allocation : compteur d'index dans DATA }
    IdxLbl  := LabelGen('_PRL_FEIDX_');
    ListLbl := IdxLbl;
    { Evaluer et imprimer la premiere expr  }
    ExprLoad(RangeStart);
    If HasVar And (SymIdx >= 0) Then
    Begin
      Str(SymTab[SymIdx].Offset, CntLbl);
      EmitInstr('MOV', 'WORD PTR [BP-' + CntLbl + '], AX');
    End;
    { Consommer le reste de la liste silencieusement }
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Do
    Begin
      ParserAdvance;
      ParseExpr(DummyE);
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
    { Boucle simplifiee : une seule iteration (limitation) }
    EmitComment('foreach: boucle simplifiee (liste literale 1 iteration)');
    LoopPush(LblEnd, LblCont, LblTop);
    EmitLabel(LblTop);
    ParseBlock;
    EmitLabel(LblCont);
    EmitLabel(LblEnd);
    LoopPop;
  End;
  LoopPop;
End;

{ ---- ParseDoStmt : do BLOC [while/until cond]  --------------- }
Procedure ParseDoStmt;
Var
  LblTop  : TString;
  LblEnd  : TString;
  LblCont : TString;
  Cond    : TExprVal;
  HasLoop : Boolean;
  IsUntil : Boolean;
Begin
  ParserAdvance;  { consommer 'do' }
  LblTop  := LabelGen('_PRL_DOTOP_');
  LblEnd  := LabelGen('_PRL_DOEND_');
  LblCont := LabelGen('_PRL_DOCNT_');
  HasLoop := False;
  IsUntil := False;
  LoopPush(LblEnd, LblCont, LblTop);
  EmitLabel(LblTop);
  ParseBlock;
  EmitLabel(LblCont);
  { do BLOC while/until cond }
  If CurToken.Kind = TK_KEYWORD Then
  Begin
    If (CurToken.Val = 'while') Or (CurToken.Val = 'until') Then
    Begin
      IsUntil := (CurToken.Val = 'until');
      ParserAdvance;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then ParserAdvance;
      ParseExpr(Cond);
      ExprLoad(Cond);
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then ParserAdvance;
      EmitInstr('TEST', 'AX, AX');
      If IsUntil Then
        EmitInstr('JZ', LblTop)    { until: reboucler si FAUX }
      Else
        EmitInstr('JNZ', LblTop);  { while: reboucler si VRAI }
      HasLoop := True;
      If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Then
        ParserAdvance;
    End;
  End;
  If Not HasLoop Then
  Begin
    { do BLOC seul (pas de while/until) : executer une fois }
    EmitComment('do BLOC : execution unique');
  End;
  EmitLabel(LblEnd);
  LoopPop;
End;

{ ============================================================
  TODO 15 - TABLEAUX @arr
  ============================================================ }

{ ---- ParseArrElemAccess : $arr[idx] -> TExprVal lvalue ----- }
{ ArrIdx = indice dans SymTab de @arr.                         }
{ Layout pile : [BP-Offset]=count, [BP-Offset-2]=elem[0], ... }
{ Pour idx constant (EK_IMM), Res = EK_MEM ImmVal=1 direct.   }
{ Pour idx variable, adresse calculee dans BX : EK_MEM ImmVal=2 }
Procedure ParseArrElemAccess(ArrIdx : Integer; Var Res : TExprVal);
Var
  IdxE    : TExprVal;
  ElemOff : LongInt;
  S       : TString;
  BaseOff : Integer;
Begin
  ParserAdvance;  { consommer '[' }
  ParseExpr(IdxE);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ']') Then
    ParserAdvance;
  BaseOff := SymTab[ArrIdx].Offset;
  If IdxE.Kind = EK_IMM Then
  Begin
    { Index constant : acces direct [BP - (BaseOff+2 + idx*2)] }
    ElemOff := BaseOff + 2 + IdxE.ImmVal * 2;
    Str(ElemOff, S);
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 1;
    Res.Offset  := ElemOff;
    Res.TypeIdx := TY_IDX_SCALAR;
  End Else
  Begin
    { Index dynamique : calculer adresse dans BX }
    ExprLoad(IdxE);      { AX = index }
    EmitInstr('MOV', 'SI, AX');
    EmitInstr('SHL', 'SI, 1');         { SI = idx * 2 }
    Str(BaseOff + 2, S);
    EmitInstr('ADD', 'SI, ' + S);      { SI = offset base elements + idx*2 }
    EmitInstr('MOV', 'BX, BP');
    EmitInstr('SUB', 'BX, SI');        { BX = &arr[idx] }
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 2;
    Res.Offset  := 0;
    Res.TypeIdx := TY_IDX_SCALAR;
  End;
End;

{ ---- ParseArrBuiltin : push / pop / shift / unshift @arr -- }
{ push  @arr, val => ajouter val a la fin, incr count         }
{ pop   @arr      => retirer dernier elem dans AX, decr count }
{ shift @arr      => retirer premier elem dans AX, decr count }
{ unshift @arr, val => inserer val au debut, incr count       }
Procedure ParseArrBuiltin(IsStmt : Boolean);
Var
  KW     : TString;
  ArrIdx : Integer;
  E      : TExprVal;
  OffS   : TString;
  BaseS  : TString;
  I      : Integer;
  IS     : TString;
Begin
  KW := CurToken.Val;
  ParserAdvance;  { consommer le keyword }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    ParserAdvance;
  { Identifier @arr }
  ArrIdx := -1;
  If CurToken.Kind = TK_ARRAY_SIG Then
  Begin
    ArrIdx := SymFindCat(CurToken.Val, SC_ARRAY_VAR);
    ParserAdvance;
  End;
  If KW = 'push' Then
  Begin
    { push @arr, val }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;    ParseExpr(E);
    ExprLoad(E);  { AX = valeur a pousser }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('push @arr');
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');  { CX = count }
      EmitInstr('MOV', 'SI, CX');
      EmitInstr('SHL', 'SI, 1');          { SI = count*2 }
      EmitInstr('ADD', 'SI, ' + BaseS);   { SI = offset de arr[count] }
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');         { BX = &arr[count] }
      EmitInstr('MOV', '[BX], AX');       { arr[count] = val }
      EmitInstr('INC', 'WORD PTR [BP-' + OffS + ']');  { count++ }
    End;
  End Else If KW = 'pop' Then
  Begin
    { pop @arr : retourne dernier element dans AX }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('pop @arr');
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');  { CX = count }
      EmitInstr('DEC', 'CX');             { CX = last idx }
      EmitInstr('DEC', 'WORD PTR [BP-' + OffS + ']');  { count-- }
      EmitInstr('MOV', 'SI, CX');
      EmitInstr('SHL', 'SI, 1');
      EmitInstr('ADD', 'SI, ' + BaseS);
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');
      EmitInstr('MOV', 'AX, [BX]');      { AX = valeur retournee }
    End Else
      EmitInstr('MOV', 'AX, 0');
  End Else If KW = 'shift' Then
  Begin
    { shift @arr : retirer et retourner premier element, decaler }
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('shift @arr');
      { Sauvegarder arr[0] dans AX }
      Str(SymTab[ArrIdx].Offset + 2, IS);
      EmitInstr('MOV', 'AX, WORD PTR [BP-' + IS + ']');
      EmitInstr('PUSH', 'AX');  { sauver valeur retournee }
      { Decaler arr[1..n-1] vers arr[0..n-2] via boucle }
      EmitInstr('MOV', 'CX, WORD PTR [BP-' + OffS + ']');
      EmitInstr('DEC', 'CX');   { CX = count-1 (nombre d''elements a decaler) }
      EmitInstr('JCXZ', '_PRL_SHFTE_' + OffS);
      EmitLabel('_PRL_SHFTS_' + OffS);
      { BX = &arr[1] initialement -> avancer }
      EmitInstr('MOV', 'SI, ' + BaseS);
      EmitInstr('MOV', 'BX, BP');
      EmitInstr('SUB', 'BX, SI');     { BX = &arr[0] }
      EmitInstr('MOV', 'DI, SI');
      EmitInstr('SUB', 'DI, 2');      { DI = offset arr[1] }
      EmitInstr('MOV', 'DX, BP');
      EmitInstr('SUB', 'DX, DI');     { DX = &arr[1] = src }
      EmitInstr('MOV', 'AX, [DX]');
      EmitInstr('MOV', '[BX], AX');
      EmitLabel('_PRL_SHFTE_' + OffS);
      EmitInstr('DEC', 'WORD PTR [BP-' + OffS + ']');
      EmitInstr('POP', 'AX');
    End Else If CurFnDepth > 0 Then
    Begin
      { TODO 17 : shift sans @arr explicite dans un sub -> shift @_ }
      { Convention push gauche->droite : arg0=[BP+4+(N-1)*2], arg1=[BP+4+(N-2)*2] }
      { CurArgShiftIdx 0 = dernier argument pousse = [BP+4] }
      Str(4 + CurArgShiftIdx * 2, OffS);
      EmitComment('shift @_[' + OffS + ']');
      EmitInstr('MOV', 'AX, WORD PTR [BP+' + OffS + ']');
      Inc(CurArgShiftIdx);
    End Else
      EmitInstr('MOV', 'AX, 0');
  End Else If KW = 'unshift' Then
  Begin
    { unshift @arr, val : inserer val en tete }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ',') Then
      ParserAdvance;
    ParseExpr(E);
    ExprLoad(E);
    If ArrIdx >= 0 Then
    Begin
      Str(SymTab[ArrIdx].Offset, OffS);
      Str(SymTab[ArrIdx].Offset + 2, BaseS);
      EmitComment('unshift @arr');
      { Incr count d''abord }
      EmitInstr('INC', 'WORD PTR [BP-' + OffS + ']');
      { Stocker val dans arr[0] }
      Str(SymTab[ArrIdx].Offset + 2, IS);
      EmitInstr('MOV', 'WORD PTR [BP-' + IS + '], AX');
    End;
  End;
End;  { ParseArrBuiltin }

{ ---- HashSlotFind : chercher une cle dans HashKeyTab ------- }
{ Retourne l''indice de l''entree dans HashKeyTab, ou -1.       }
Function HashSlotFind(HashSym : Integer; Const Key : TString) : Integer;
Var
  I : Integer;
Begin
  HashSlotFind := -1;
  For I := 0 To HashKeyCount - 1 Do
    If (HashKeyTab[I].HashSym = HashSym) And (HashKeyTab[I].KeyStr = Key) Then
    Begin
      HashSlotFind := I;
      Exit;
    End;
End;

{ ---- HashSlotAdd : ajouter une nouvelle cle dans le hash --- }
{ Retourne le SlotIdx (position 0..N-1) dans le hash.         }
Function HashSlotAdd(HashSym : Integer; Const Key : TString;
                     Const KeyLbl : TString) : Integer;
Var
  I     : Integer;
  SlotN : Integer;
Begin
  { Compter les slots existants pour ce hash }
  SlotN := 0;
  For I := 0 To HashKeyCount - 1 Do
    If HashKeyTab[I].HashSym = HashSym Then
      Inc(SlotN);
  { Ajouter la nouvelle entree }
  If HashKeyCount < MAX_HASH_KEYS Then
  Begin
    HashKeyTab[HashKeyCount].HashSym := HashSym;
    HashKeyTab[HashKeyCount].KeyStr  := Key;
    HashKeyTab[HashKeyCount].SlotIdx := SlotN;
    HashKeyTab[HashKeyCount].KeyLbl  := KeyLbl;
    Inc(HashKeyCount);
  End Else
  Begin
    WriteLn('PERL86: ERREUR - HashKeyTab pleine (MAX_HASH_KEYS=', MAX_HASH_KEYS, ')');
    Inc(ErrorCount);
  End;
  HashSlotAdd := SlotN;
End;

{ ---- ParseHashElemAccess : acces element hash -> TExprVal -- }
{ HashIdx = indice dans SymTab du %hash.                       }
{ Layout pile :                                                }
{   [BP-hashOff]           = count (paires initialisees)       }
{   [BP-hashOff-2-k*4]     = key_ptr[k] (OFFSET string DATA)  }
{   [BP-hashOff-4-k*4]     = val[k]     (mot valeur)           }
{ Cle constante -> EK_MEM ImmVal=1 (acces direct [BP-n])       }
{ Cle variable  -> stub, EK_AX = 0                             }
Procedure ParseHashElemAccess(HashIdx : Integer; Var Res : TExprVal);
Var
  KeyStr  : TString;
  HKIdx   : Integer;
  SlotIdx : Integer;
  KeyLbl  : TString;
  ValOff  : Integer;
  S       : TString;
  ElemIdx : Integer;
Begin
  ParserAdvance;  { consommer '{' }
  { -- Cle constante : bareword, string ou keyword-as-string -- }
  If (CurToken.Kind = TK_IDENT) Or (CurToken.Kind = TK_STRING) Or
     ((CurToken.Kind = TK_KEYWORD) And
      (CurToken.Val <> 'undef') And (CurToken.Val <> 'my') And
      (CurToken.Val <> 'our')   And (CurToken.Val <> 'if')) Then
  Begin
    KeyStr := CurToken.Val;
    ParserAdvance;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
    HKIdx := HashSlotFind(HashIdx, KeyStr);
    If HKIdx >= 0 Then
    Begin
      { Cle deja connue : acces direct }
      SlotIdx := HashKeyTab[HKIdx].SlotIdx;
    End Else
    Begin
      { Cle inconnue : ajouter en DATA + enregistrer }
      ElemIdx := DataAddStr(KeyStr);
      KeyLbl  := DataTab[ElemIdx].LblName;
      SlotIdx := HashSlotAdd(HashIdx, KeyStr, KeyLbl);
      { Initialiser key_ptr au moment de la premiere mention }
      Str(SymTab[HashIdx].Offset + 2 + SlotIdx * 4, S);
      EmitInstr('MOV', 'WORD PTR [BP-' + S + '], OFFSET ' + KeyLbl);
      { Incremeter count pour ce nouveau slot }
      Str(SymTab[HashIdx].Offset, S);
      EmitInstr('INC', 'WORD PTR [BP-' + S + ']');
    End;
    ValOff      := SymTab[HashIdx].Offset + 4 + SlotIdx * 4;
    Res.Kind    := EK_MEM;
    Res.ImmVal  := 1;
    Res.Offset  := ValOff;
    Res.TypeIdx := TY_IDX_SCALAR;
  End Else
  Begin
    { -- Cle variable : stub -> retourner 0 -- }
    EmitComment('$h var-key : runtime non implemente (stub TODO 16)');
    EmitInstr('MOV', 'AX, 0');
    If (CurToken.Kind <> TK_PUNCT) Or (CurToken.Val <> '}') Then
    Begin
      { Consommer la cle variable }
      While Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}')) And
                (CurToken.Kind <> TK_EOF) Do
        ParserAdvance;
    End;
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '}') Then ParserAdvance;
    Res.Kind    := EK_AX;
    Res.ImmVal  := 0;
    Res.Offset  := 0;
    Res.TypeIdx := TY_IDX_SCALAR;
  End;
End;

{ ============================================================
  TODO 07 - EMETTEUR DE CODE ASM
  ============================================================ }

{ ---- LabelGen : generateur de labels ASM uniques ---------- }
{ Incremente LabelSeq et retourne Prefix + N.                  }
{ Ex : LabelGen(PR_LBL_PFX) -> ''_PRL_42''                     }
Function LabelGen(Const Prefix : TString) : TString;
Var
  S : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  LabelGen := Prefix + S;
End;

{ ---- EmitRaw : ecriture directe dans le fichier de sortie - }
Procedure EmitRaw(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, S);
End;

{ ---- EmitBlankLine : ligne vide --------------------------- }
Procedure EmitBlankLine;
Begin
  EmitRaw('');
End;

{ ---- EmitComment : commentaire ASM (prefixe ;) ------------ }
Procedure EmitComment(Const S : TString);
Begin
  EmitRaw('; ' + S);
End;

{ ---- EmitLabel : etiquette ASM (non indentee) ------------- }
{ Convention MASM : label sur sa propre ligne, suivi de '':''. }
Procedure EmitLabel(Const Name : TString);
Begin
  EmitRaw(Name + ':');
End;

{ ---- EmitInstr : instruction a 2 operandes (indenation 8sp) }
{ Format : ''        MNEM  OPS''                               }
Procedure EmitInstr(Const Mnem, Ops : TString);
Begin
  EmitRaw('        ' + Mnem + '  ' + Ops);
End;

{ ---- EmitInstr1 : instruction sans operande (MOV SP,BP ...) }
Procedure EmitInstr1(Const Mnem : TString);
Begin
  EmitRaw('        ' + Mnem);
End;

{ ============================================================
  TODO 25 - RUN (stub minimal, complete en TODO 25)
  ============================================================ }
Procedure Run;
Begin
  TypeInit;
  SymInit;
  EmitOpen;
  If ErrorCount > 0 Then Exit;
  { Lexeur + analyse syntaxique }
  LexInit;
  ParserAdvance;
  If Opts.DebugTok Then
  Begin
    { Mode debug : afficher tous les tokens sans emettre de code }
    While CurToken.Kind <> TK_EOF Do
      ParserAdvance;
  End
  Else
  Begin
    { Analyse normale : stub - ParseStmt sera complete dans les TODOs suivants }
    While CurToken.Kind <> TK_EOF Do
      ParseStmt;
  End;
  LexClose;
  EmitClose;
  If Opts.Verbose Then
    WriteLn('PERL86: ', TotalLines, ' ligne(s) lues depuis ', Opts.SrcFile);
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount   := 0;
  WarnCount    := 0;
  TotalLines   := 0;
  TotalSyms    := 0;
  LexOpened    := False;
  OutFOpen     := False;
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  LabelSeq     := 0;
  TypeCount    := 0;
  DataCount    := 0;
  CurFrameSize := 0;
  CurFnDepth   := 0;
  LoopTop      := 0;
  GKwConsumed  := False;
  CurFnRetLbl  := '';
  CurFnName    := '';
  CurPackage   := 'main';
  RuntimeEmitted := False;
  IncludeCount := 0;
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  InitOptions;
  ParseArgs;
  ShowBanner;
  Run;
  Cleanup;
  If Opts.Verbose Then ShowStats;
  If ErrorCount > 0 Then
    Halt(EXIT_ERROR)
  Else
    Halt(EXIT_OK);
End.
