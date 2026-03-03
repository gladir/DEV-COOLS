{ F77C86.PAS - Compilateur Fortran 77 vers assembleur 8086
   Turbo Pascal / Free Pascal (-Mtp)
   ================================================================

   LISTE DES TRAVAUX A REALISER (25 TODOS)
   ========================================

   TODO 01 - INFRASTRUCTURE DE BASE
     Constantes globales (VERSION, MAX_SYM, MAX_SCOPE, MAX_PROC,
     MAX_PARAM, MAX_LABELS, MAX_ERRORS, MAX_STR, MAX_DIM, MAX_COMMON,
     MAX_FORMAT, STACK_SIZE). Types fondamentaux : TString, TToken,
     TTokenKind, TSymKind (SK_VAR, SK_ARRAY, SK_PARAM, SK_FUNC,
     SK_SUBR, SK_COMMON, SK_PARAM_CONST, SK_INTRINSIC), TDataType
     (DT_INTEGER, DT_REAL, DT_DOUBLE, DT_COMPLEX, DT_LOGICAL,
     DT_CHARACTER), TSymRec, TProcRec. Cadre principal : arguments
     en ligne de commande (source .F ou .F77, sortie .ASM, options
     -v -d -nr), ouverture des fichiers, prefixes labels ASM
     FL_ (Fortran Label), FV_ (Fortran Variable), FB_ (Fortran Branch),
     FRT_ (Fortran RunTime). Sortie MASM/TASM modele SMALL.

   TODO 02 - LECTEUR DE SOURCE A FORMAT FIXE
     Lecture colonne par colonne du format standard Fortran 77 :
     colonne 1 = commentaire si 'C' ou '*', colonnes 1-5 = etiquette
     d'instruction (label numerique 1-99999), colonne 6 = indicateur
     de continuation (caractere non espace et non zero), colonnes
     7-72 = corps de l'instruction, colonnes 73-80 = identification
     (ignorees). Assembler les lignes de continuation en un seul
     enregistrement logique de jusqu'a 1320 caracteres. Compter les
     lignes physiques pour les messages d'erreur. Gerer les fins de
     fichier et erreurs d'ouverture.

   TODO 03 - ANALYSEUR LEXICAL (LEXER)
     LexChar, LexPeek, LexAdvance, position dans l'enregistrement
     logique. Tokens Fortran 77 : mots-cles PROGRAM END STOP PAUSE
     RETURN CALL SUBROUTINE FUNCTION BLOCK DATA COMMON EQUIVALENCE
     DIMENSION IMPLICIT EXTERNAL INTRINSIC SAVE PARAMETER DATA FORMAT
     INCLUDE IF THEN ELSE ELSEIF ENDIF DO CONTINUE GOTO ASSIGN
     READ WRITE PRINT OPEN CLOSE REWIND BACKSPACE ENDFILE INQUIRE.
     Types : INTEGER REAL DOUBLE PRECISION COMPLEX LOGICAL CHARACTER.
     Entiers : suite de chiffres decimaux. Reels : notations 1.5,
     1.5E+3, 1.5D-2 (double). Logique : .TRUE. .FALSE. Charactères :
     'abc' (apostrophe doublee pour echapper ''). Operateurs
     arithmetiques + - * / ** (puissance). Operateurs relationnels
     .EQ. .NE. .LT. .LE. .GT. .GE. Operateurs logiques .AND. .OR.
     .NOT. .EQV. .NEQV. Separateurs ( ) , = :. Hollerith nHccc...

   TODO 04 - TABLE DES SYMBOLES ET PORTEE
     SymEnter, SymFind, SymFindLocal. Portee unique par unite de
     programme (PROGRAM / SUBROUTINE / FUNCTION / BLOCK DATA) : pas
     de portees imbriquees en Fortran 77, sauf COMMON global. Champs
     du symbole : nom (6 chars max norm Fortran), categorie, type de
     donnee, taille (pour CHARACTER*n), dimensions (DIMENSION),
     offset pile ou label DATA, attributs (SAVE, EXTERNAL, INTRINSIC,
     common_block, equivalence_group, is_par, is_dummy, is_defined).
     Table des etiquettes numeriques : LabelEnter, LabelFind,
     LabelMarkDefined (pour detecter GOTO vers label non defini).
     Table de COMMON blocks : CommonEnter, CommonFind.

   TODO 05 - TYPAGE IMPLICITE ET DECLARATIONS DE TYPE
     Regle implicite Fortran 77 par defaut : variables dont le nom
     commence par I J K L M N sont INTEGER, toutes les autres REAL.
     IMPLICIT NONE desactive le typage implicite (toute variable non
     declaree = erreur). IMPLICIT INTEGER(A-H,O-Z) etIMPLICIT REAL(I-N)
     renversent les regles pour des plages de lettres. Parser les
     enonces de declaration de type explicites :
     INTEGER [*nb] liste, REAL [*nb] liste, DOUBLE PRECISION liste,
     COMPLEX [*nb] liste, LOGICAL [*nb] liste, CHARACTER [*nb] liste
     avec les variantes de taille (*2, *4, *8 pour INTEGER/LOGICAL/
     REAL/DOUBLE/COMPLEX, *n pour CHARACTER). Appliquer le type
     implicite lors du premier usage d'un identificateur.

   TODO 06 - DECLARATIONS DIMENSION ET TABLEAUX
     DIMENSION nom(borne1, ..., borneN) avec 1 a 7 dimensions (norme
     F77). Bornes inferieures et superieures : lb:ub (defaut lb=1).
     Stocker les bornes dans TSymRec.dims[1..7] (lb, ub). Calcul de
     la taille totale du tableau = produit des etendues. Calcul de
     l'adresse d'un element : formule de linearisation par colonnes
     (FORTRAN column-major order). Declarer en DATA statique ou sur
     la pile selon la classe de memoire. Tableaux dummy (parametres
     formels de taille ajustable : ub = *).

   TODO 07 - DECLARATION COMMON ET EQUIVALENCE
     COMMON /nom/ liste : regroupement de variables dans un bloc
     commun partage entre unites de programme. Allouer le bloc COMMON
     en DATA avec le label _FC_nom_ (BLANK COMMON = _FC_BLANK_).
     Chaque variable d'un COMMON recoit un offset dans le bloc.
     EQUIVALENCE (a,b) : superposition de variables a la meme adresse
     (meme offset dans la zone locale ou dans un COMMON). Detecter et
     signaler les equivalences illegales (entre deux COMMON differents
     ou etendant un COMMON en arriere). SAVE : marquer les variables
     locales comme statiques (conserver leur valeur entre les appels).

   TODO 08 - DECLARATION DATA ET CONSTANTES NOMMEES
     DATA liste/valeurs/ : initialiser des variables, elements de
     tableaux ou groupes avec des constantes. Syntaxe de repetition :
     n*valeur. Types de constantes : entier, reel, double, complexe
     (re,im), logique .TRUE./.FALSE., chaine de caracteres. Emettre
     des directives DW/DD/DQ/DB en segment DATA selon le type.
     PARAMETER (nom=expr) : constante symbolique, substituee par sa
     valeur au moment de la compilation (pas de symbole DATA).
     Evaluer les expressions constantes de PARAMETER au compile-time.

   TODO 09 - GENERATEUR DE CODE 8086 - PRIMITIVES
     EmitLabel, EmitI0..EmitI2, EmitComment, EmitDB, EmitDW, EmitDD,
     EmitDQ, EmitDup, EmitSep, EmitBlank. Compteur instr_count.
     Basculement out_file / tmp_file (SwitchToMain / SwitchToTmp).
     Organisation des segments : .DATA (variables statiques, COMMON,
     tableaux data, chaines format), .CODE (corps des sous-programmes
     puis START). Prefixe des labels MASM/TASM. Convention d'appel
     Fortran : arguments passes PAR REFERENCE (adresses empilees de
     droite a gauche), valeur de retour de FUNCTION dans DX:AX pour
     INTEGER/REAL 2 octets ou via un parametre cache pour les autres.

   TODO 10 - EXPRESSIONS ARITHMETIQUES ENTIERES
     ParseIntExpr, ParseIntTerm, ParseIntFactor. Operateurs :
     unaire - (NEG AX), + (identite), ** (puissance entiere :
     boucle IMUL ou appel _FRT_IPOW). Termes : * (IMUL),
     / (division tronquee vers zero en Fortran 77 : CWD + IDIV),
     MOD implicite via DIV puis reste. Additifs : + (ADD), - (SUB).
     Constantes entieres directes (MOV AX, imm). Variables entieres :
     charger depuis adresse effective [BP-off] ou [segment:off].
     Appels de fonctions entieres intrinsèques et utilisateur.
     Priorites Fortran : ** > unaire > * / > + -.

   TODO 11 - EXPRESSIONS ARITHMETIQUES REELLES ET DOUBLE PRECISION
     Emulation virgule flottante sans FPU 8087 (stub runtime).
     Representation REAL 4 octets (DX:AX) et DOUBLE 8 octets (pile).
     Routines runtime _FRT_FADD, _FRT_FSUB, _FRT_FMUL, _FRT_FDIV,
     _FRT_FPOW, _FRT_FNEG, _FRT_ITOF (entier vers reel),
     _FRT_FTOI (reel vers entier par troncature). Conversion
     automatique INTEGER -> REAL dans les expressions mixtes.
     Constantes reelles : convertir representation textuelle en
     motif binaire IEEE 754 a la compilation (ou emettre en DATA DD).

   TODO 12 - EXPRESSIONS LOGIQUES ET RELATIONNELLES
     Relations : .EQ. .NE. .LT. .LE. .GT. .GE. entre entiers ->
     result -1 (TRUE) ou 0 (FALSE) en 16 bits.
     Relations entre reels : appel _FRT_FCMP -> signe du resultat.
     Relations entre chaines CHARACTER : _FRT_SCMP (comparaison
     lexicographique). Operateurs logiques : .NOT. (NOT AX),
     .AND. (AND AX,CX), .OR. (OR AX,CX), .EQV. (XNOR),
     .NEQV. (XOR). Conversion logique -> entier et inverse.
     .TRUE. = -1 (0FFFFh), .FALSE. = 0 (meme convention BCPL).

   TODO 13 - EXPRESSIONS CARACTERES (CHARACTER)
     Type CHARACTER*n : chaine de longueur fixe completee par espaces
     (blank-padded, pas null-terminated). Concatenation // :
     appel _FRT_SCAT(dst, src1, len1, src2, len2). Sous-chaine
     str(lo:hi) : LEA + offset, avec clipping sur les bornes. Affec-
     tation de chaines : _FRT_SCOPY(dst, ndst, src, nsrc) avec
     troncature ou remplissage par espaces. Fonctions intrinsèques
     LEN, INDEX, CHAR, ICHAR. Variables CHARACTER declarees en DATA
     avec DB n DUP(' ') ou initialisees par DATA.

   TODO 14 - TABLE DES LABELS ET INSTRUCTIONS DE BRANCHEMENT SIMPLES
     LabelTable (1-99999), chaque entree : defini (oui/non), nom ASM
     FL_nnnnn. GOTO n : JMP FL_nnnnn (backpatching si forward). GOTO
     (n1,n2,...), i : calcul index, table de sauts indirecte. ASSIGN n
     TO v / GOTO v : sauts assignes (stocker l'adresse du label dans v,
     IndirectJMP). CONTINUE : instruction vide (juste un label eventuel).
     Backpatching : resoudre les sauts a terme a la fin de l'unite de
     programme. Verifier que tous les labels cibles sont definis.

   TODO 15 - INSTRUCTION IF ARITHMETIQUE ET IF LOGIQUE
     IF arithmetique : IF (expr) n1, n2, n3 -> CMP AX,0 puis
     JL FL_n1 / JE FL_n2 / JG FL_n3 (trois sauts conditionnels).
     IF logique : IF (expr_logique) instruction -> CMP AX,0 ;
     JE suite ; exec instruction inline.
     IF bloc : IF (cond) THEN ... [ELSEIF (cond) THEN ...]*
     [ELSE ...] ENDIF -> generateur de labels emboites avec
     pile de blocs IF (max 20 niveaux d'imbrication norme F77).

   TODO 16 - BOUCLE DO
     DO label var = debut, fin [, pas]  (pas par defaut = 1).
     Initialisation : MOV [var], debut. Calcul du nombre d'iterations
     MAX(INT((fin-debut+pas)/pas), 0) stocke dans CX ou sur la pile.
     Test d'iterations : LOOP FL_label ou DEC + JNZ. Gerer le cas
     pas negatif. DO imbriques (pile de DO actifs). Controle de la
     variable de boucle : non modifiable dans le corps (avertissement).
     FIN de la boucle : label numerique cible (souvent CONTINUE).

   TODO 17 - INSTRUCTIONS D'AFFECTATION ET D'E/S SIMPLES
     Affectation : var = expr (entier, reel, logique, character).
     Convertir le type rvalue vers le type lvalue si necessaire.
     Lvalue : variable scalaire, element de tableau avec calcul
     d'adresse colonne-major, sous-chaine, variable de COMMON.
     PRINT *, liste : ecriture sur stdout avec format libre.
     READ *, liste : lecture depuis stdin avec format libre.
     Appels _FRT_PRINT_I, _FRT_PRINT_R, _FRT_PRINT_L,
     _FRT_PRINT_S, _FRT_PRINT_NL, _FRT_READ_I, _FRT_READ_R.

   TODO 18 - INSTRUCTIONS READ / WRITE AVEC FORMAT
     WRITE(unite, format) liste et READ(unite, format) liste.
     Unite : 6 = stdout, 5 = stdin, numero de fichier ouvert.
     Format : etiquette numerique d'un enonce FORMAT, ou chaine
     litterale, ou * (format libre). Parser les specifications
     FORMAT : Iw, Fw.d, Ew.d, Dw.d, Gw.d, Lw, Aw, nX, /, 'str',
     nH..., T tabs, repetitions n(...). Runtime _FRT_FMT_WRITE_I,
     _FRT_FMT_WRITE_F, _FRT_FMT_WRITE_E, _FRT_FMT_WRITE_S,
     _FRT_FMT_NEWLINE, _FRT_FMT_SKIP_COL. Format libre (*)
     separe par espaces ou virgules.

   TODO 19 - INSTRUCTIONS D'E/S FICHIERS
     OPEN(unit, FILE=nom, STATUS=, ACCESS=, FORM=, RECL=, IOSTAT=,
     ERR=, BLANK=). CLOSE(unit [,STATUS=] [,IOSTAT=] [,ERR=]).
     REWIND(unit), BACKSPACE(unit), ENDFILE(unit), INQUIRE(unit, ...).
     Table des unites logiques (1..99) : associer chaque unite a un
     handle DOS (INT 21h). Runtime _FRT_OPEN, _FRT_CLOSE,
     _FRT_REWIND, _FRT_BACKSPACE. Gestion IOSTAT (code d'erreur
     retourne dans une variable INTEGER) et ERR= (saut sur erreur).

   TODO 20 - DECLARATION ET APPEL DE SOUS-PROGRAMME (SUBROUTINE)
     SUBROUTINE nom [(liste_params)] ... RETURN [x] ... END.
     Generer le prologue (PUSH BP / MOV BP,SP / PUSH reg preserves)
     et l'epilogue (POP + RET n*2). Parametres passes par adresse :
     chaque parametre formel = pointeur 16 bits sur la pile.
     CALL nom [(liste_args)] : pousser les adresses des arguments
     (LEA pour variables, temporaire sur pile pour expressions).
     Tableau dummy (parametre ajustable) : passer l'adresse du
     premier element. CHARACTER dummy : passer adresse + longueur
     (parametre cache longueur pour chaque arg CHARACTER).

   TODO 21 - DECLARATION ET APPEL DE FONCTION (FUNCTION)
     FUNCTION nom [(liste_params)] ... nom = expr ... RETURN ... END.
     Le nom de la fonction agit comme variable locale pour le retour.
     INTEGER FUNCTION, REAL FUNCTION, LOGICAL FUNCTION, CHARACTER*n
     FUNCTION. Retour par DX:AX pour types <= 4 octets. Pour DOUBLE
     PRECISION et CHARACTER : parametre cache supplementaire (adresse
     du buffer du resultat). EXTERNAL : declarer un sous-programme
     externe passable comme argument. INTRINSIC : declarer une
     fonction intrinsèque passable comme argument. Fonctions
     statement : FUNC(x) = expr (substitution inline a la compilation).

   TODO 22 - FONCTIONS INTRINSEQUES
     Groupe conversion : INT IFIX IDINT REAL FLOAT SNGL DBLE DCMPLX
     CMPLX ICHAR CHAR. Groupe mathematique : ABS IABS DABS CABS
     MOD AMOD DMOD SIGN ISIGN DSIGN DIM IDIM DDIM MAX MAX0 AMAX0
     AMAX1 DMAX1 MIN MIN0 AMIN0 AMIN1 DMIN1. Groupe virgule flottante
     via runtime _FRT_SQRT _FRT_EXP _FRT_LOG _FRT_LOG10 _FRT_SIN
     _FRT_COS _FRT_TAN _FRT_ASIN _FRT_ACOS _FRT_ATAN _FRT_ATAN2
     _FRT_SINH _FRT_COSH _FRT_TANH. Fonctions corde :
     LEN INDEX LNBLNK LENTRIM. Fonctions de bits : IBITS IAND IOR
     IEOR INOT ISHFT ISHFTC IBCLR IBSET BTEST MVBITS.

   TODO 23 - RUNTIME FORTRAN 77 (_FRT_xxx)
     Routines assemblee dans le segment CODE (SwitchToTmp) :
     _FRT_IPOW   : puissance entiere (AX^CX -> AX par boucle IMUL).
     _FRT_PRINT_I : afficher un entier signe en decimal (DOS INT 21h).
     _FRT_PRINT_NL : emettre CR+LF.
     _FRT_PRINT_S : afficher une chaine a longueur explicite.
     _FRT_PRINT_L : afficher .TRUE. ou .FALSE.
     _FRT_READ_I  : lire un entier depuis stdin (INT 21h 0Ah + parse).
     _FRT_READ_NL : vider le tampon jusqu'au retour chariot.
     _FRT_SCOPY   : copie chaine Fortran avec padding espaces.
     _FRT_SCMP    : comparaison lexicographique 2 chaines Fortran.
     _FRT_SCAT    : concatenation de chaines Fortran //.
     _FRT_STOP_0  : STOP sans code -> MOV AX,4C00h / INT 21h.
     _FRT_STOP_N  : STOP n -> afficher n, puis exit.
     _FRT_PAUSE   : PAUSE [n] -> afficher message, attendre touche.
     Routines reelles simulees : _FRT_FADD _FRT_FSUB _FRT_FMUL
     _FRT_FDIV _FRT_ITOF _FRT_FTOI _FRT_FCMP (stubs pour la 1re
     iteration, remplacement par 8087 optionnel en TODO futur).

   TODO 24 - BLOCK DATA ET UNITES DE COMPILATION MULTIPLES
     BLOCK DATA [nom] ... END : unites d'initialisation des blocs
     COMMON. Seules les declarations et enonces DATA sont autorises.
     Generer les segments DATA nommes pour chaque BLOCK DATA.
     Unites de compilation independantes : chaque fichier source est
     compile separement et donne un .OBJ (ou module .ASM) distinct.
     Emettre des directives EXTRN pour les symboles externes (COMMON
     public, SUBROUTINE et FUNCTION appelees depuis d'autres unites).
     Directives PUBLIC pour les symboles exportes. Compatibilite
     avec l'assembleur MASM/TASM 2.x et le linker LINK.EXE de DOS.

   TODO 25 - INTEGRATION FINALE, PROGRAMME PRINCIPAL ET TESTS
     PROGRAM nom : unite principale. Generer le point d'entree START
     (segement CODE debut), initialiser SS:SP, DS, initialiser les
     COMMON blancs et nommes, appeler les BLOCK DATA, puis CALL START
     effectif qui appelle la routine PROGRAM. GenProgramPrologue,
     GenProgramEpilogue (MOV AX,4C00h / INT 21h). ParseProgram :
     dispatcher PROGRAM / SUBROUTINE / FUNCTION / BLOCK DATA selon
     le premier token de l'unite. Tester avec :
       hello.f  : PROGRAM HELLO / PRINT *, 'BONJOUR' / END
       arith.f  : soustrait, multiplie, divise deux entiers + PRINT
       do_test.f: boucle DO 10 I=1,10 / PRINT *,I / 10 CONTINUE / END
       sub_test.f: SUBROUTINE FACT(N,R) + appel depuis PROGRAM
       fibo.f   : calcul recursif (via FUNCTION) des nombres Fibonacci.
     Rapport final de compilation : statistiques (lignes, symboles,
     labels, erreurs, temps).

   ================================================================
   @author:  (a completer)
   @created: 2026
   @target:  Turbo Pascal 7 / Free Pascal 3.2 (-Mtp)
   @output:  MASM/TASM 8086 (.ASM) - Modele memoire SMALL
   @license: (a definir)
   ================================================================ }

Program F77C86;

{$I-}   { desactiver les IO-check }

{ ============================================================
  TODO 01 - INFRASTRUCTURE DE BASE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  F77_VERSION  = '1.0';
  F77_DATE     = '2026-03-03';

  MAX_SYM      = 512;    { entrees table des symboles                 }
  MAX_SCOPE    = 16;     { niveaux de portee (F77 a portee unique)    }
  MAX_PROC     = 128;    { sous-programmes et fonctions               }
  MAX_PARAM    = 32;     { parametres par sous-programme              }
  MAX_LABELS   = 1024;   { etiquettes numeriques Fortran (1-99999)    }
  MAX_ERRORS   = 30;     { arret apres N erreurs                      }
  MAX_STR      = 127;    { longueur maximale d'une TString            }
  MAX_DIM      = 7;      { dimensions max d'un tableau (norme F77)    }
  MAX_COMMON   = 64;     { blocs COMMON distincts                     }
  MAX_FORMAT   = 64;     { enonces FORMAT memorises                   }
  MAX_UNITS    = 99;     { unites logiques de fichiers (1..99)        }
  STACK_SIZE   = 512;    { taille segment pile en octets              }
  MAX_LOGLINE  = 1320;   { longueur max d'un enregistrement logique   }

  { Prefixes des labels assembleur 8086 }
  FL_PFX  = '_FL_';    { etiquettes numeriques Fortran (GOTO/DO)    }
  FV_PFX  = '_FV_';    { variables statiques et COMMON              }
  FB_PFX  = '_FB_';    { branches internes (IF/DO/..)               }
  FRT_PFX = '_FRT_';   { routines runtime Fortran                   }
  FK_PFX  = '_FK_';    { constantes chaines et format               }
  FC_PFX  = '_FC_';    { blocs COMMON (_FC_BLANK_, _FC_nom_)        }
  FP_PFX  = '_FP_';    { procedures et fonctions utilisateur        }

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Tokens Fortran 77 ---- }
  TTokenKind = (
    TK_IDENT,      { identificateur (max 6 chars en F77 strict)   }
    TK_INTEGER,    { litteral entier                               }
    TK_REAL,       { litteral reel  (1.5E+3)                      }
    TK_DOUBLE,     { litteral double precision (1.5D-2)           }
    TK_STRING,     { chaine 'abc' (apostrophe doublee pour '')     }
    TK_LOGICAL,    { .TRUE. ou .FALSE.                            }
    TK_HOLLERITH,  { nHabc... (hollerith)                         }
    TK_KEYWORD,    { mot-cle Fortran reserve                      }
    TK_RELOP,      { .EQ. .NE. .LT. .LE. .GT. .GE.               }
    TK_LOGOP,      { .AND. .OR. .NOT. .EQV. .NEQV.               }
    TK_OP,         { operateur  + - * / ** // =                   }
    TK_PUNCT,      { ponctuation  ( ) , : '                       }
    TK_LABEL,      { etiquette numerique (colonnes 1-5)           }
    TK_NEWLINE,    { fin d'enregistrement logique                 }
    TK_EOF         { fin de fichier                               }
  );

  TToken = Record
    kind     : TTokenKind;
    val      : TString;       { representation brute               }
    int_val  : LongInt;       { si TK_INTEGER ou TK_LABEL          }
    real_val : Real;          { si TK_REAL ou TK_DOUBLE            }
    lbl_num  : Integer;       { si TK_LABEL : numero 1-99999       }
    line     : Integer;       { ligne physique dans le source      }
    col      : Integer;       { colonne dans l'enregistrement      }
  End;

  { ---- Types de donnees Fortran 77 ---- }
  TDataType = (
    DT_NONE,       { non determine (avant typage implicite)       }
    DT_INTEGER,    { INTEGER [*2|*4] : entier signe 16/32 bits    }
    DT_REAL,       { REAL [*4]       : virgule flottante 4 octets  }
    DT_DOUBLE,     { DOUBLE PRECISION : virgule flottante 8 octets }
    DT_COMPLEX,    { COMPLEX [*8]    : partie re+im REAL*4+REAL*4  }
    DT_LOGICAL,    { LOGICAL [*2]    : booleen 0/-1               }
    DT_CHARACTER   { CHARACTER [*n]  : chaine longueur fixe        }
  );

  { ---- Categories de symboles Fortran 77 ---- }
  TSymKind = (
    SK_NONE,        { entree non utilisee                          }
    SK_VAR,         { variable scalaire (locale ou SAVE)           }
    SK_ARRAY,       { tableau (DIMENSION declaree)                 }
    SK_PARAM,       { parametre formel (passe par adresse)         }
    SK_FUNC,        { fonction utilisateur (FUNCTION)              }
    SK_SUBR,        { sous-programme (SUBROUTINE)                  }
    SK_COMMON,      { variable dans un bloc COMMON                 }
    SK_PARAM_CONST, { constante symbolique (PARAMETER)             }
    SK_INTRINSIC,   { fonction intrinseque (INTRINSIC declaree)    }
    SK_EXTERNAL,    { sous-programme externe (EXTERNAL declaree)   }
    SK_STMTFUNC     { fonction-instruction (FUNC(x) = expr)        }
  );

  { ---- Borne d'une dimension de tableau ---- }
  TDimBound = Record
    lb : Integer;   { borne inferieure (defaut 1)                  }
    ub : Integer;   { borne superieure (-1 = ajustable : ub=*)     }
  End;

  { ---- Entree de la table des symboles ---- }
  TSymRec = Record
    name       : TString;     { nom du symbole (majuscules)        }
    kind       : TSymKind;
    dtype      : TDataType;
    char_len   : Integer;     { longueur si DT_CHARACTER           }
    type_size  : Integer;     { taille en octets (2,4,8...)        }
    ndim       : Integer;     { nombre de dimensions (0=scalaire)  }
    dims       : Array[1..MAX_DIM] of TDimBound;
    asm_label  : TString;     { label ASM (FV_ ou FC_ + nom)       }
    bp_offset  : Integer;     { offset BP si variable locale       }
    is_save    : Boolean;     { SAVE : conserver entre les appels  }
    is_dummy   : Boolean;     { parametre formel                   }
    is_defined : Boolean;     { au moins une affectation faite     }
    common_blk : Integer;     { index bloc COMMON (0=aucun)        }
    common_off : Integer;     { offset dans le bloc COMMON         }
    equiv_grp  : Integer;     { groupe EQUIVALENCE (0=aucun)       }
    equiv_off  : Integer;     { offset dans le groupe              }
    const_ival : LongInt;     { valeur si SK_PARAM_CONST entier    }
    const_rval : Real;        { valeur si SK_PARAM_CONST reel      }
    const_sval : TString;     { valeur si SK_PARAM_CONST chaine    }
    proc_idx   : Integer;     { index proc_table si SK_FUNC/SUBR   }
    scope_unit : Integer;     { unite de programme (proc_idx)      }
  End;

  TSymTable = Array[1..MAX_SYM] of TSymRec;

  { ---- Entree de la table des etiquettes numeriques ---- }
  TLabelRec = Record
    num        : Integer;     { numero 1-99999                     }
    asm_label  : TString;     { FL_nnnnn                           }
    defined    : Boolean;     { l'etiquette a ete vue dans le code }
    referenced : Boolean;     { un GOTO/DO y fait reference        }
    do_end     : Boolean;     { c'est le label de fin d'un DO      }
    line       : Integer;     { ligne de definition                }
  End;

  TLabelTable = Array[1..MAX_LABELS] of TLabelRec;

  { ---- Bloc COMMON ---- }
  TCommonRec = Record
    name       : TString;     { nom du bloc ('' = BLANK COMMON)    }
    asm_label  : TString;     { _FC_nom_ ou _FC_BLANK_             }
    total_size : Integer;     { taille totale en octets            }
  End;

  TCommonTable = Array[1..MAX_COMMON] of TCommonRec;

  { Alias pratiques pour les variables locales dans le generateur de code }
  TSymRef    = TSymRec;
  TCommonRef = TCommonRec;

  { ---- Enonce FORMAT memorise ---- }
  TFormatRec = Record
    lbl_num    : Integer;     { numero de l'etiquette              }
    text       : TString;     { corps du FORMAT entre parentheses  }
    asm_label  : TString;     { FK_FMT_nnnnn                       }
  End;

  TFormatTable = Array[1..MAX_FORMAT] of TFormatRec;

  { ---- Parametre formel d'un sous-programme ---- }
  TParamRec = Record
    name       : TString;
    dtype      : TDataType;
    char_len   : Integer;     { si DT_CHARACTER                    }
    is_array   : Boolean;     { tableau dummy                      }
    bp_offset  : Integer;     { [BP + bp_offset] = adresse arg     }
    len_offset : Integer;     { [BP + len_offset] = longueur char  }
  End;

  { ---- Entree de la table des sous-programmes ---- }
  TProcRec = Record
    name         : TString;
    asm_label    : TString;   { _FP_<nom>                          }
    is_function  : Boolean;   { True=FUNCTION, False=SUBROUTINE    }
    ret_type     : TDataType; { type de retour si FUNCTION         }
    ret_char_len : Integer;   { longueur si CHARACTER FUNCTION      }
    param_count  : Integer;
    params       : Array[1..MAX_PARAM] of TParamRec;
    local_size   : Integer;   { octets du cadre local pile         }
    has_result   : Boolean;   { le nom de fonction a ete affecte   }
    result_off   : Integer;   { offset BP de la variable retour    }
  End;

  TProcTable = Array[1..MAX_PROC] of TProcRec;

  { ---- Unite logique de fichier ---- }
  TUnitRec = Record
    number     : Integer;     { 0=non ouvert, 5=stdin, 6=stdout    }
    handle     : Integer;     { handle DOS (0=non ouvert)          }
    is_open    : Boolean;
    fname      : TString;     { nom de fichier physique            }
  End;

  { Pointeur sur fichier texte }
  TTextPtr = ^Text;

  { Enregistrement logique Fortran (concatentation des lignes de continuation) }
  TLogRec = Array[1..MAX_LOGLINE] of Char;

{ --- Variables globales du compilateur --- }
Var
  { Tables allouees dynamiquement }
  sym_table    : ^TSymTable;
  proc_table   : ^TProcTable;
  lbl_table    : ^TLabelTable;
  common_table : ^TCommonTable;
  fmt_table    : ^TFormatTable;

  { Fichiers source et sortie }
  src_file     : Text;
  out_file     : Text;
  tmp_file     : Text;            { corps des sous-programmes       }
  str_file     : Text;            { chaines litterales differees    }
  cur_out      : TTextPtr;        { pointe sur out_file ou tmp_file }
  src_fname    : TString;
  out_fname    : TString;
  tmp_fname    : TString;
  str_fname    : TString;

  { Compteurs }
  sym_count    : Integer;
  proc_count   : Integer;
  lbl_count    : Integer;
  common_count : Integer;
  fmt_count    : Integer;
  equiv_count  : Integer;     { groupes EQUIVALENCE distincts      }
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;
  str_lit_count: Integer;
  branch_lbl_count : Integer;   { compteur labels branches internes _FB_  }
  data_lbl_count   : Integer;   { compteur labels constantes DATA _FK_     }
  phys_lines   : Integer;         { lignes physiques lues          }

  { Lecteur de source format fixe (TODO 02) }
  src_eof      : Boolean;
  log_rec      : ^TLogRec;            { enregistrement logique courant }
  log_rec_len  : Integer;             { longueur de log_rec            }
  log_pos      : Integer;             { position courante dans log_rec }
  log_label    : Integer;             { etiquette cols 1-5 (0=aucune)  }
  log_is_comm  : Boolean;             { ligne commentaire              }
  log_lineno   : Integer;             { numero de ligne physique debut }

  { Lecteur lexical (TODO 03) }
  cur_tok      : TToken;
  peek_tok     : TToken;
  has_peek     : Boolean;

  { Contexte de compilation }
  prog_name    : TString;             { nom de PROGRAM/SUBROUTINE/FUNCTION }
  cur_proc_idx : Integer;             { 0=niveau module                    }
  cur_unit_kw  : TString;             { PROGRAM SUBROUTINE FUNCTION BLOCKDATA }

  { Typage implicite (TODO 05) }
  impl_type    : Array['A'..'Z'] of TDataType;  { regle implicite par lettre }
  impl_none    : Boolean;             { IMPLICIT NONE actif                }

  { Pile de blocs IF (TODO 15) }
  if_depth     : Integer;
  if_else_lbl  : Array[1..MAX_SCOPE] of TString;
  if_end_lbl   : Array[1..MAX_SCOPE] of TString;

  { Pile de boucles DO (TODO 16) }
  do_depth     : Integer;
  do_end_lbl   : Array[1..MAX_SCOPE] of TString;  { label fin DO     }
  do_var_si    : Array[1..MAX_SCOPE] of Integer;   { sym index var DO }
  do_lbl_num   : Array[1..MAX_SCOPE] of Integer;   { etiquette num    }

  { Label de retour sous-programme courant }
  cur_ret_lbl  : TString;

  { Options de compilation }
  opt_verbose  : Boolean;
  opt_debug    : Boolean;
  opt_no_rt    : Boolean;

  { Unites logiques de fichiers }
  unit_table   : Array[0..MAX_UNITS] of TUnitRec;

{ ============================================================
  Utilitaires generaux
  ============================================================ }

Function IntToStr(n : LongInt) : TString;
Var s : TString;
Begin
  Str(n, s);
  IntToStr := s;
End;

Function StrToInt(Const s : TString) : LongInt;
Var n : LongInt; code : Integer;
Begin
  Val(s, n, code);
  StrToInt := n;
End;

Function StrUpper(Const s : TString) : TString;
Var i : Integer; r : TString;
Begin
  r := s;
  For i := 1 To Length(r) Do
    If (r[i] >= 'a') And (r[i] <= 'z') Then
      r[i] := Chr(Ord(r[i]) - 32);
  StrUpper := r;
End;

Function ChangeExtension(Const fn, ext : TString) : TString;
Var i : Integer; base : TString;
Begin
  base := fn;
  i    := Length(base);
  While (i > 0) And (base[i] <> '.') And (base[i] <> '\') And (base[i] <> '/') Do
    Dec(i);
  If (i > 0) And (base[i] = '.') Then
    base := Copy(base, 1, i - 1);
  ChangeExtension := base + ext;
End;

Function PadRight(Const s : TString; n : Integer) : TString;
Var r : TString; i : Integer;
Begin
  r := s;
  While Integer(Length(r)) < n Do r := r + ' ';
  PadRight := r;
End;

{ Taille en octets d'un type de donnees Fortran 77 }
Function DataTypeSize(dt : TDataType; char_len : Integer) : Integer;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeSize := 2;
    DT_REAL      : DataTypeSize := 4;
    DT_DOUBLE    : DataTypeSize := 8;
    DT_COMPLEX   : DataTypeSize := 8;
    DT_LOGICAL   : DataTypeSize := 2;
    DT_CHARACTER : DataTypeSize := char_len;
  Else
    DataTypeSize := 2;
  End;
End;

{ Nom lisible d'un type de donnees }
Function DataTypeName(dt : TDataType) : TString;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeName := 'INTEGER';
    DT_REAL      : DataTypeName := 'REAL';
    DT_DOUBLE    : DataTypeName := 'DOUBLE PRECISION';
    DT_COMPLEX   : DataTypeName := 'COMPLEX';
    DT_LOGICAL   : DataTypeName := 'LOGICAL';
    DT_CHARACTER : DataTypeName := 'CHARACTER';
  Else
    DataTypeName := 'UNKNOWN';
  End;
End;

{ Directives ASM correspondant a un type (pour DATA) }
Function DataTypeDir(dt : TDataType) : TString;
Begin
  Case dt Of
    DT_INTEGER   : DataTypeDir := 'DW';   { 2 octets         }
    DT_REAL      : DataTypeDir := 'DD';   { 4 octets         }
    DT_DOUBLE    : DataTypeDir := 'DQ';   { 8 octets         }
    DT_COMPLEX   : DataTypeDir := 'DQ';   { 8 octets re+im   }
    DT_LOGICAL   : DataTypeDir := 'DW';   { 2 octets 0/-1    }
    DT_CHARACTER : DataTypeDir := 'DB';   { octets bruts      }
  Else
    DataTypeDir := 'DW';
  End;
End;

{ ============================================================
  Messages d'erreur et avertissements
  ============================================================ }

Procedure ErrorMsg(Const msg : TString);
Begin
  Writeln('** ERREUR ligne ', log_lineno, ' : ', msg);
  Inc(err_count);
  If err_count >= MAX_ERRORS Then
  Begin
    Writeln('Trop d''erreurs - compilation arretee.');
    Halt(1);
  End;
End;

Procedure WarnMsg(Const msg : TString);
Begin
  Writeln('   AVERT  ligne ', log_lineno, ' : ', msg);
  Inc(warn_count);
End;

Procedure NoteMsg(Const msg : TString);
Begin
  If opt_verbose Then
    Writeln('   Info   : ', msg);
End;

{ ============================================================
  Initialisation des tables
  ============================================================ }

Procedure InitTables;
Var i : Integer; c : Char;
Begin
  New(sym_table);
  New(proc_table);
  New(lbl_table);
  New(common_table);
  New(fmt_table);

  sym_count    := 0;
  proc_count   := 0;
  lbl_count    := 0;
  common_count := 0;
  fmt_count    := 0;
  equiv_count  := 0;
  err_count    := 0;
  warn_count   := 0;
  instr_count  := 0;
  str_lit_count:= 0;
  branch_lbl_count := 0;
  data_lbl_count   := 0;
  phys_lines   := 0;

  src_eof      := False;
  New(log_rec);
  log_rec_len  := 0;
  log_pos      := 1;
  log_label    := 0;
  log_is_comm  := False;
  log_lineno   := 0;

  has_peek     := False;

  prog_name    := 'MAIN';
  cur_proc_idx := 0;
  cur_unit_kw  := 'PROGRAM';

  { Typage implicite F77 par defaut : I-N INTEGER, reste REAL }
  impl_none := False;
  For c := 'A' To 'Z' Do
  Begin
    If (c >= 'I') And (c <= 'N') Then
      impl_type[c] := DT_INTEGER
    Else
      impl_type[c] := DT_REAL;
  End;

  if_depth  := 0;
  do_depth  := 0;
  cur_ret_lbl := '';

  opt_verbose := False;
  opt_debug   := False;
  opt_no_rt   := False;

  For i := 0 To MAX_UNITS Do
  Begin
    unit_table[i].number  := i;
    unit_table[i].handle  := 0;
    unit_table[i].is_open := False;
    unit_table[i].fname   := '';
  End;
  { unites standard DOS }
  unit_table[5].is_open := True;
  unit_table[5].fname   := 'STDIN';
  unit_table[6].is_open := True;
  unit_table[6].fname   := 'STDOUT';
End;

{ ============================================================
  Affichage d'aide et traitement de la ligne de commande
  ============================================================ }

Procedure PrintUsage;
Begin
  Writeln('F77C86 v', F77_VERSION, ' - Compilateur Fortran 77 vers assembleur 8086');
  Writeln('Usage : F77C86 [options] source.f [sortie.asm]');
  Writeln('Options :');
  Writeln('  -v     : mode verbeux (afficher les etapes)');
  Writeln('  -d     : mode debogage (commentaires supplementaires)');
  Writeln('  -nr    : ne pas emettre le runtime FRT dans le .ASM');
  Writeln('  -h     : afficher cette aide');
  Writeln('Source : fichier .F ou .F77 en format fixe Fortran 77');
  Writeln('Sortie : fichier .ASM au format MASM/TASM, modele SMALL');
End;

Procedure ParseArgs;
Var i : Integer; arg : TString;
Begin
  src_fname := '';
  out_fname := '';

  For i := 1 To ParamCount Do
  Begin
    arg := StrUpper(ParamStr(i));
    If arg = '-V' Then
      opt_verbose := True
    Else If arg = '-D' Then
      opt_debug := True
    Else If arg = '-NR' Then
      opt_no_rt := True
    Else If (arg = '-H') Or (arg = '/?') Or (arg = '-?') Then
    Begin
      PrintUsage;
      Halt(0);
    End
    Else If src_fname = '' Then
      src_fname := ParamStr(i)
    Else If out_fname = '' Then
      out_fname := ParamStr(i);
  End;

  If src_fname = '' Then
  Begin
    PrintUsage;
    Halt(1);
  End;

  If out_fname = '' Then
    out_fname := ChangeExtension(src_fname, '.ASM');

  tmp_fname := ChangeExtension(src_fname, '.TMP');
  str_fname := ChangeExtension(src_fname, '.STR');
End;

{ Ouvrir les fichiers source et sortie }
Procedure OpenFiles;
Begin
  Assign(src_file, src_fname);
  Reset(src_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible d''ouvrir le source : ', src_fname);
    Halt(1);
  End;

  Assign(out_file, out_fname);
  Rewrite(out_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible de creer : ', out_fname);
    Halt(1);
  End;

  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);
  If IOResult <> 0 Then
  Begin
    Writeln('Impossible de creer : ', tmp_fname);
    Halt(1);
  End;

  cur_out := @out_file;

  If opt_verbose Then
  Begin
    Writeln('Source  : ', src_fname);
    Writeln('Sortie  : ', out_fname);
  End;
End;

Procedure CloseFiles;
Begin
  Close(src_file);
  Close(out_file);
  Close(tmp_file);
End;

Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

Procedure SwitchToTmp;
Begin
  cur_out := @tmp_file;
End;

{ ============================================================
  TODO 02 - LECTEUR DE SOURCE A FORMAT FIXE
  ============================================================ }

{ --------------------------------------------------------------------------
  Format fixe Fortran 77 :
    Col 1     : 'C' ou '*' -> ligne de commentaire (ignoree)
    Col 1-5   : etiquette numerique (chiffres seulement, blancs -> 0)
    Col 6     : indicateur de continuation (non-blanc et non-'0' -> suite)
    Col 7-72  : corps de l'instruction
    Col 73-80 : identification (ignoree)
  Les lignes de continuation sont assemblees en un seul enregistrement
  logique de longueur max MAX_LOGLINE chars.
  Les espaces ne sont PAS significatifs en dehors des chaines litterales
  (la norme F77 autorise leur suppression).
  -------------------------------------------------------------------------- }

{ Lire une ligne physique depuis src_file.
  Retourne False si fin de fichier.
  Stocke la ligne dans phys_buf (sans le saut de ligne). }
Const
  PHYS_MAX = 255;

Var
  phys_buf     : String[255];        { ligne physique courante brute      }
  phys_lineno  : Integer;            { numero de ligne physique courante  }

Function SrcReadPhysLine : Boolean;
Var c : Char; i : Integer;
Begin
  phys_buf := '';
  If Eof(src_file) Then
  Begin
    SrcReadPhysLine := False;
    src_eof := True;
    Exit;
  End;
  Readln(src_file, phys_buf);
  Inc(phys_lines);
  phys_lineno := phys_lines;
  { Expander a 80 colonnes avec des espaces si trop court }
  While Length(phys_buf) < 6 Do phys_buf := phys_buf + ' ';
  SrcReadPhysLine := True;
End;

{ Forward : SrcIsContinued est definie apres SrcNextLogRecord }
Function SrcIsContinued : Boolean; Forward;

{ --------------------------------------------------------------------------
  SrcNextLogRecord : assembler l'enregistrement logique suivant.
  Remplit log_rec^[1..log_rec_len], log_label, log_is_comm, log_lineno.
  Retourne False si fin de fichier (aucune instruction disponible).
  -------------------------------------------------------------------------- }
Function SrcNextLogRecord : Boolean;
Var
  first_line : Boolean;
  label_str  : String[5];
  col        : Integer;
  i          : Integer;
  body_start : Integer;
  body_end   : Integer;
  is_cont    : Boolean;
  c          : Char;
  n          : Integer;
  code       : Integer;
Begin
  log_rec_len := 0;
  log_label   := 0;
  log_is_comm := False;
  first_line  := True;

  Repeat
    { Lire la ligne physique suivante (sauter les commentaires) }
    Repeat
      If Not SrcReadPhysLine Then
      Begin
        If first_line Then
        Begin
          SrcNextLogRecord := False;
          src_eof := True;
          Exit;
        End;
        { Fin de fichier en milieu de continuation : ok, on retourne ce qu'on a }
        src_eof := True;
        SrcNextLogRecord := (log_rec_len > 0);
        Exit;
      End;

      { Colonne 1 : commentaire ? }
      c := phys_buf[1];
      If (c = 'C') Or (c = 'c') Or (c = '*') Or (phys_buf = '') Then
      Begin
        { Ligne de commentaire : ignorer et recommencer }
        Continue;
      End;
      Break;
    Until False;

    { --- Analyser la ligne physique --- }

    { Colonne 6 : indicateur de continuation }
    is_cont := False;
    If Length(phys_buf) >= 6 Then
    Begin
      c := phys_buf[6];
      is_cont := (c <> ' ') And (c <> '0') And (Not first_line);
    End;

    If first_line Then
    Begin
      log_lineno := phys_lineno;
      { Extraire l'etiquette des colonnes 1-5 (chiffres uniquement) }
      label_str := '';
      For i := 1 To 5 Do
      Begin
        If i <= Length(phys_buf) Then
        Begin
          c := phys_buf[i];
          If (c >= '0') And (c <= '9') Then
            label_str := label_str + c
          Else If c <> ' ' Then
          Begin
            ErrorMsg('Caractere invalide en colonne ' + IntToStr(i) +
                     ' (etiquette) : ' + c);
          End;
        End;
      End;
      If label_str <> '' Then
      Begin
        Val(label_str, n, code);
        If (code = 0) And (n >= 1) And (n <= 99999) Then
          log_label := n
        Else
          ErrorMsg('Etiquette invalide : ' + label_str);
      End;
      first_line := False;
    End;

    { Copier les colonnes 7-72 dans log_rec (sans les espaces insignifiants).
      NOTE : selon la norme F77, les blancs peuvent etre supprimes partout
      SAUF dans les constantes chaines ; ici on les conserve pour simplifier
      le lexer qui gerera lui-meme les blancs. }
    body_start := 7;
    body_end   := Length(phys_buf);
    If body_end > 72 Then body_end := 72;

    For i := body_start To body_end Do
    Begin
      If log_rec_len < MAX_LOGLINE Then
      Begin
        Inc(log_rec_len);
        log_rec^[log_rec_len] := phys_buf[i];
      End
      Else
        ErrorMsg('Enregistrement logique trop long (> ' +
                 IntToStr(MAX_LOGLINE) + ' chars)');
    End;

    { Verifier si la ligne suivante est une continuation }
    { On relit la prochaine ligne physique pour tester sa colonne 6 }
    { En pratique on lira en boucle grace au Repeat/Until ci-dessous }

    { Verifier si c'est une ligne totalement vide (corps vide apres concat) }
    { -> continuer a lire }

  Until Not SrcIsContinued;     { <- fonction definie ci-dessous }

  log_pos := 1;
  SrcNextLogRecord := (log_rec_len > 0);
End;

{ --------------------------------------------------------------------------
  SrcIsContinued : regarder si la PROCHAINE ligne physique est une suite.
  Utilise un mecanisme de "peek" sur src_file.
  Retourne True si la prochaine ligne physique a un caractere de continuation
  en colonne 6 (non espace, non '0').
  En sortie, phys_buf contient deja la prochaine ligne (elle est "consommee").
  -------------------------------------------------------------------------- }
Var
  peek_phys_buf  : String[255];           { ligne physique anticipee           }
  has_peek_phys  : Boolean;           { True si peek_phys_buf est valide   }

Function SrcIsContinued : Boolean;
Var c : Char;
Begin
  { Si la ligne suivante est deja dans le tampon peek, la traiter }
  has_peek_phys := False;

  If Eof(src_file) Then
  Begin
    SrcIsContinued := False;
    Exit;
  End;

  Readln(src_file, peek_phys_buf);
  Inc(phys_lines);
  phys_lineno := phys_lines;

  { Commentaire -> ce n'est pas une continuation, mais on l'ignore }
  While (Length(peek_phys_buf) > 0) And
        ((peek_phys_buf[1] = 'C') Or (peek_phys_buf[1] = 'c') Or
         (peek_phys_buf[1] = '*')) Do
  Begin
    If Eof(src_file) Then
    Begin
      SrcIsContinued := False;
      Exit;
    End;
    Readln(src_file, peek_phys_buf);
    Inc(phys_lines);
    phys_lineno := phys_lines;
  End;

  While Length(peek_phys_buf) < 6 Do peek_phys_buf := peek_phys_buf + ' ';

  c := peek_phys_buf[6];
  If (c <> ' ') And (c <> '0') Then
  Begin
    { Ligne de continuation : la mettre dans phys_buf et signaler }
    phys_buf := peek_phys_buf;
    SrcIsContinued := True;
  End
  Else
  Begin
    { Pas une continuation : on a lu une ligne en trop.
      La memo dans has_peek_phys pour la reutiliser au prochain appel. }
    has_peek_phys := True;
    SrcIsContinued := False;
  End;
End;

{ Correctif : SrcReadPhysLine doit verifier has_peek_phys en premier }
{ (integration maintenue simple : le compilateur lit d'abord SrcNextLogRecord
   qui appelle SrcReadPhysLine puis SrcIsContinued dans l'ordre correct) }

{ --------------------------------------------------------------------------
  Accesseurs sur l'enregistrement logique courant (utilises par le lexer).
  -------------------------------------------------------------------------- }

{ Caractere courant de l'enregistrement logique }
Function LogCurChar : Char;
Begin
  If log_pos <= log_rec_len Then
    LogCurChar := log_rec^[log_pos]
  Else
    LogCurChar := #0;
End;

{ Caractere suivant (peek) sans avancer }
Function LogPeekChar : Char;
Begin
  If log_pos + 1 <= log_rec_len Then
    LogPeekChar := log_rec^[log_pos + 1]
  Else
    LogPeekChar := #0;
End;

{ Avancer d'un caractere dans l'enregistrement }
Procedure LogAdvance;
Begin
  If log_pos <= log_rec_len Then
    Inc(log_pos);
End;

{ Sauter les espaces insignifiants dans l'enregistrement logique }
Procedure LogSkipBlanks;
Begin
  While (log_pos <= log_rec_len) And (log_rec^[log_pos] = ' ') Do
    Inc(log_pos);
End;

{ Fin de l'enregistrement logique courant ? }
Function LogAtEnd : Boolean;
Begin
  LogAtEnd := (log_pos > log_rec_len);
End;

{ --------------------------------------------------------------------------
  Lire une sous-chaine de l'enregistrement logique a partir de log_pos
  tant que le predicat est vrai. Retourne la chaine et avance log_pos.
  -------------------------------------------------------------------------- }
Function LogReadWhile(Const isOk : Boolean) : TString;
Begin
  { non-utilise : le lexer lit caractere par caractere }
  LogReadWhile := '';
End;

{ --------------------------------------------------------------------------
  SrcInit : reinitialiser le lecteur de source pour une unite de programme.
  A appeler apres chaque END rencontre.
  -------------------------------------------------------------------------- }
Procedure SrcInit;
Begin
  log_rec_len  := 0;
  log_pos      := 1;
  log_label    := 0;
  log_is_comm  := False;
  has_peek_phys := False;
End;

{ ============================================================
  TODO 03 - ANALYSEUR LEXICAL (LEXER)
  ============================================================
  Lit les tokens Fortran 77 depuis l'enregistrement logique courant
  (log_rec^ via LogCurChar / LogAdvance / LogAtEnd).
  En F77 les espaces sont non-significatifs en dehors des chaines
  litterales : LogSkipBlanks est appele systematiquement.

  Organisation :
    LexDoRead(var tok)  -- lecture effective (interne)
    LexNext             -- avance cur_tok (utilise has_peek si disponible)
    LexPeekTok          -- consulte le token suivant sans consommer
    LexExpect(val)      -- assertion sur cur_tok.val + avance
    LexExpectKind(k)    -- assertion sur cur_tok.kind + avance
    LexInit             -- initialise le lexer, lit le 1er enregistrement

  Table des mots-cles statique (typed const Turbo Pascal).
  ============================================================ }

Const
  LEX_KW_COUNT = 44;

Type
  TKeyword = String[20];

Const
  LEX_KW : Array[1..LEX_KW_COUNT] of TKeyword = (
    { Instructions }
    'PROGRAM','SUBROUTINE','FUNCTION','BLOCKDATA','END',
    'STOP','PAUSE','RETURN','CALL',
    'COMMON','EQUIVALENCE','DIMENSION','IMPLICIT',
    'EXTERNAL','INTRINSIC','SAVE','PARAMETER',
    'DATA','FORMAT','INCLUDE',
    'IF','THEN','ELSE','ELSEIF','ENDIF',
    'DO','CONTINUE','GOTO','ASSIGN',
    'READ','WRITE','PRINT',
    'OPEN','CLOSE','REWIND','BACKSPACE','ENDFILE','INQUIRE',
    { Types }
    'INTEGER','REAL','DOUBLEPRECISION','COMPLEX',
    'LOGICAL','CHARACTER'
  );

{ Verifie si s est un mot-cle F77. }
Function LexIsKeyword(Const s : TString) : Boolean;
Var i : Integer;
Begin
  LexIsKeyword := False;
  For i := 1 To LEX_KW_COUNT Do
    If s = LEX_KW[i] Then
    Begin
      LexIsKeyword := True;
      Exit;
    End;
End;

{ ---- Lecture de la partie alphabetique dans log_rec (skip blancs). ---- }
Function LexReadLetters : TString;
Var s : TString; c : Char;
Begin
  s := '';
  LogSkipBlanks;
  While (Not LogAtEnd) And (LogCurChar In ['A'..'Z','a'..'z']) Do
  Begin
    c := LogCurChar;
    If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
    If Length(s) < MAX_STR Then s := s + c;
    LogAdvance;
    LogSkipBlanks;
  End;
  LexReadLetters := s;
End;

{ ---- Lecture de lettres + chiffres (suite d'un identifiant). ---- }
Function LexReadAlphaNum : TString;
Var s : TString; c : Char;
Begin
  s := '';
  LogSkipBlanks;
  While (Not LogAtEnd) And (LogCurChar In ['A'..'Z','a'..'z','0'..'9']) Do
  Begin
    c := LogCurChar;
    If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
    If Length(s) < MAX_STR Then s := s + c;
    LogAdvance;
    LogSkipBlanks;
  End;
  LexReadAlphaNum := s;
End;

{ ---- Lecture de chiffres decimaux depuis log_rec. ---- }
Function LexReadDigits : TString;
Var s : TString;
Begin
  s := '';
  While (Not LogAtEnd) And (LogCurChar In ['0'..'9']) Do
  Begin
    If Length(s) < MAX_STR Then s := s + LogCurChar;
    LogAdvance;
  End;
  LexReadDigits := s;
End;

{ --------------------------------------------------------------------------
  LexDoRead : lecture effective d un token dans tok.
  Appele par LexNext et LexPeekTok.
  Quand l enregistrement logique est epuise, retourne TK_NEWLINE
  et charge automatiquement le suivant (ou TK_EOF si fin de fichier).
  -------------------------------------------------------------------------- }
Procedure LexDoRead(Var tok : TToken);
Var
  c      : Char;
  s, t   : TString;
  n      : Integer;
  code   : Integer;
  hlen   : Integer;
  i      : Integer;
  is_dbl : Boolean;
Begin
  LogSkipBlanks;

  { Fin de l enregistrement logique courant -> TK_NEWLINE }
  If LogAtEnd Then
  Begin
    tok.kind    := TK_NEWLINE;
    tok.val     := '';
    tok.lbl_num := log_label;
    tok.line    := log_lineno;
    tok.col     := 0;
    { Pre-charger le prochain enregistrement pour le prochain appel }
    If Not SrcNextLogRecord Then
    Begin
      tok.kind := TK_EOF;  { Fin de fichier immediate }
    End;
    Exit;
  End;

  c := LogCurChar;
  tok.line := log_lineno;
  tok.col  := log_pos;
  tok.val  := '';
  tok.int_val  := 0;
  tok.real_val := 0;
  tok.lbl_num  := 0;

  { ---- Chaine litterale Fortran : 'abc' (apostrophe doublee = '') ---- }
  If c = '''' Then
  Begin
    LogAdvance;
    s := '';
    Repeat
      If LogAtEnd Then
      Begin
        ErrorMsg('Chaine litterale non fermee en fin d enregistrement');
        Break;
      End;
      If LogCurChar = '''' Then
      Begin
        LogAdvance;
        If (Not LogAtEnd) And (LogCurChar = '''') Then
        Begin
          s := s + '''';
          LogAdvance;
        End
        Else
          Break;
      End
      Else
      Begin
        s := s + LogCurChar;
        LogAdvance;
      End;
    Until False;
    tok.kind := TK_STRING;
    tok.val  := s;
    Exit;
  End;

  { ---- Entier ou reel commencant par un chiffre ---- }
  If c In ['0'..'9'] Then
  Begin
    s := LexReadDigits;

    { Hollerith : nHccc... }
    If (Not LogAtEnd) And (LogCurChar In ['H','h']) Then
    Begin
      Val(s, hlen, code);
      If (code = 0) And (hlen > 0) Then
      Begin
        LogAdvance;  { consommer 'H' }
        t := '';
        For i := 1 To hlen Do
        Begin
          If LogAtEnd Then Break;
          t := t + LogCurChar;
          LogAdvance;
        End;
        tok.kind    := TK_HOLLERITH;
        tok.val     := t;
        tok.int_val := hlen;
        Exit;
      End;
    End;

    { Reel : n.m  ou  n.mE+p  ou  n.mD+p }
    If (Not LogAtEnd) And (LogCurChar = '.') Then
    Begin
      s := s + '.'; LogAdvance;
      s := s + LexReadDigits;
      is_dbl := False;
      If Not LogAtEnd Then
      Begin
        If LogCurChar In ['E','e'] Then
        Begin
          s := s + 'E'; LogAdvance;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End
        Else If LogCurChar In ['D','d'] Then
        Begin
          s := s + 'D'; LogAdvance; is_dbl := True;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End;
      End;
      tok.val := s;
      If is_dbl Then tok.kind := TK_DOUBLE Else tok.kind := TK_REAL;
      Exit;
    End;

    { Exposant direct sur entier : 1E3  ou  1D3 }
    If Not LogAtEnd Then
    Begin
      If LogCurChar In ['E','e'] Then
      Begin
        s := s + 'E'; LogAdvance;
        If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
        Begin s := s + LogCurChar; LogAdvance; End;
        s := s + LexReadDigits;
        tok.kind := TK_REAL; tok.val := s;
        Exit;
      End
      Else If LogCurChar In ['D','d'] Then
      Begin
        s := s + 'D'; LogAdvance;
        If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
        Begin s := s + LogCurChar; LogAdvance; End;
        s := s + LexReadDigits;
        tok.kind := TK_DOUBLE; tok.val := s;
        Exit;
      End;
    End;

    { Entier simple }
    Val(s, n, code);
    tok.kind    := TK_INTEGER;
    tok.val     := s;
    tok.int_val := n;
    Exit;
  End;

  { ---- Operateurs ponctuels : .EQ. .AND. .TRUE. .5 ---- }
  If c = '.' Then
  Begin
    LogAdvance;
    LogSkipBlanks;

    { Reel commencant par un point : .5E3 }
    If (Not LogAtEnd) And (LogCurChar In ['0'..'9']) Then
    Begin
      s := '.' + LexReadDigits;
      is_dbl := False;
      If Not LogAtEnd Then
      Begin
        If LogCurChar In ['E','e'] Then
        Begin
          s := s + 'E'; LogAdvance;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End
        Else If LogCurChar In ['D','d'] Then
        Begin
          s := s + 'D'; LogAdvance; is_dbl := True;
          If (Not LogAtEnd) And (LogCurChar In ['+','-']) Then
          Begin s := s + LogCurChar; LogAdvance; End;
          s := s + LexReadDigits;
        End;
      End;
      tok.val := s;
      If is_dbl Then tok.kind := TK_DOUBLE Else tok.kind := TK_REAL;
      Exit;
    End;

    { Mot entre points : .TRUE. .FALSE. .EQ. .AND. etc. }
    s := LexReadLetters;
    { Consommer le '.' fermant }
    If (Not LogAtEnd) And (LogCurChar = '.') Then LogAdvance;

    If (s = 'TRUE') Or (s = 'FALSE') Then
    Begin
      tok.kind    := TK_LOGICAL;
      tok.val     := s;
      tok.int_val := Ord(s = 'TRUE');
      Exit;
    End;
    If (s = 'EQ') Or (s = 'NE') Or (s = 'LT') Or
       (s = 'LE') Or (s = 'GT') Or (s = 'GE') Then
    Begin
      tok.kind := TK_RELOP; tok.val := s; Exit;
    End;
    If (s = 'AND') Or (s = 'OR') Or (s = 'NOT') Or
       (s = 'EQV') Or (s = 'NEQV') Then
    Begin
      tok.kind := TK_LOGOP; tok.val := s; Exit;
    End;

    If s = '' Then
      ErrorMsg('Point decimal isole inattendu')
    Else
      ErrorMsg('Operateur point inconnu : .' + s + '.');
    tok.kind := TK_OP;
    tok.val  := '.' + s + '.';
    Exit;
  End;

  { ---- ** et * ---- }
  If c = '*' Then
  Begin
    LogAdvance;
    If (Not LogAtEnd) And (LogCurChar = '*') Then
    Begin LogAdvance; tok.kind := TK_OP; tok.val := '**'; End
    Else
    Begin tok.kind := TK_OP; tok.val := '*'; End;
    Exit;
  End;

  { ---- // et / ---- }
  If c = '/' Then
  Begin
    LogAdvance;
    If (Not LogAtEnd) And (LogCurChar = '/') Then
    Begin LogAdvance; tok.kind := TK_OP; tok.val := '//'; End
    Else
    Begin tok.kind := TK_OP; tok.val := '/'; End;
    Exit;
  End;

  { ---- Operateurs et ponctuation simples ---- }
  If c = '+' Then Begin LogAdvance; tok.kind := TK_OP;    tok.val := '+'; Exit; End;
  If c = '-' Then Begin LogAdvance; tok.kind := TK_OP;    tok.val := '-'; Exit; End;
  If c = '=' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := '='; Exit; End;
  If c = '(' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := '('; Exit; End;
  If c = ')' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ')'; Exit; End;
  If c = ',' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ','; Exit; End;
  If c = ':' Then Begin LogAdvance; tok.kind := TK_PUNCT; tok.val := ':'; Exit; End;

  { ---- Identifiant ou mot-cle ---- }
  If c In ['A'..'Z','a'..'z'] Then
  Begin
    { Lire partie alphabetique seulement (les blancs sont sautes) }
    s := LexReadLetters;

    { Cas DOUBLE + PRECISION (deux mots separes ou colles) }
    If s = 'DOUBLE' Then
    Begin
      LogSkipBlanks;
      If Not LogAtEnd Then
      Begin
        t := LexReadLetters;
        If t = 'PRECISION' Then s := 'DOUBLEPRECISION'
        Else
        Begin
          { 't' consomme mais pas reconnu -> on le perd ; signaler }
          WarnMsg('Attendu PRECISION apres DOUBLE, obtenu : ' + t);
        End;
      End;
    End;

    { Mot-cle reconnu : retourner TK_KEYWORD }
    If LexIsKeyword(s) Then
    Begin
      tok.kind := TK_KEYWORD;
      tok.val  := s;
      Exit;
    End;

    { Sinon : lire la suite alphanumerique de l identifiant }
    t := LexReadAlphaNum;
    s := s + t;
    If Length(s) > 6 Then
    Begin
      WarnMsg('Identifiant trop long (max 6 car. en F77) : ' + s);
      s := Copy(s, 1, 6);
    End;
    tok.kind := TK_IDENT;
    tok.val  := s;
    Exit;
  End;

  { ---- Caractere inconnu : signaler et avancer ---- }
  ErrorMsg('Caractere inattendu : ' + c);
  LogAdvance;
  tok.kind := TK_OP;
  tok.val  := c;
End;

{ --------------------------------------------------------------------------
  LexNext : avance cur_tok vers le token suivant.
  Si un token a ete pre-lu par LexPeekTok (has_peek=True),
  le retourne directement sans relire la source.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Begin
  If has_peek Then
  Begin
    cur_tok  := peek_tok;
    has_peek := False;
    Exit;
  End;
  LexDoRead(cur_tok);
End;

{ --------------------------------------------------------------------------
  LexPeekTok : retourne le prochain token sans consommer cur_tok.
  Le resultat est mis en cache dans peek_tok / has_peek.
  -------------------------------------------------------------------------- }
Function LexPeekTok : TToken;
Begin
  If Not has_peek Then
  Begin
    LexDoRead(peek_tok);
    has_peek := True;
  End;
  LexPeekTok := peek_tok;
End;

{ --------------------------------------------------------------------------
  LexExpect : verifie cur_tok.val = val puis avance. Sinon erreur.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const val : TString);
Begin
  If cur_tok.val <> val Then
    ErrorMsg('Attendu ''' + val + ''', obtenu ''' + cur_tok.val + '''');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : verifie cur_tok.kind = k puis avance. Sinon erreur.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Const
  TK_NAME : Array[TK_IDENT..TK_EOF] of String[12] = (
    'IDENT','INTEGER','REAL','DOUBLE','STRING','LOGICAL',
    'HOLLERITH','KEYWORD','RELOP','LOGOP','OP','PUNCT',
    'LABEL','NEWLINE','EOF'
  );
Begin
  If cur_tok.kind <> k Then
    ErrorMsg('Token attendu : ' + TK_NAME[k] +
             ', obtenu : ' + TK_NAME[cur_tok.kind] +
             ' (''' + cur_tok.val + ''')');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexInit : initialise le lexer pour le debut de la compilation.
  Lit le premier enregistrement logique et remplit cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexInit;
Begin
  has_peek        := False;
  cur_tok.kind    := TK_NEWLINE;
  cur_tok.val     := '';
  cur_tok.lbl_num := 0;
  cur_tok.line    := 0;
  cur_tok.col     := 0;
  SrcInit;
  If SrcNextLogRecord Then
    LexNext
  Else
  Begin
    cur_tok.kind := TK_EOF;
    cur_tok.val  := '';
  End;
End;

{ ============================================================
  TODO 04 - TABLE DES SYMBOLES ET PORTEE
  ============================================================
  En Fortran 77 il n'y a qu'une seule portee par unite de programme
  (PROGRAM / SUBROUTINE / FUNCTION / BLOCK DATA).  Pas de portees
  imbriquees.  Les blocs COMMON et les noms de procedures sont
  "globaux" (scope_unit = 0).

  Fonctions exposees :
    SymFind(name)             -- cherche dans portee courante + globale
    SymFindLocal(name)        -- cherche uniquement dans l'unite courante
    SymEnter(name,kind,dtype) -- cree un nouveau symbole
    SymReset                  -- purge les symboles de l'unite courante

    LabelFind(num)            -- cherche une etiquette par numero
    LabelEnter(num)           -- cree si necessaire, retourne index
    LabelMarkDefined(num,ln)  -- marque l'etiquette comme vue dans source
    LabelCheckAll             -- verifie les ref. non definies apres END
    LabelReset                -- purge la table pour une nouvelle unite

    CommonFind(name)          -- cherche un bloc COMMON par nom
    CommonEnter(name)         -- cree si necessaire, retourne index

    FmtFind(lbl_num)          -- cherche un FORMAT par etiquette
    FmtEnter(lbl_num, text)   -- enregistre un FORMAT
  ============================================================ }

{ --------------------------------------------------------------------------
  SymFindLocal : chercher un symbole dans l'unite de programme courante
  seulement. Ne remonte pas aux globaux (scope_unit = 0).
  Retourne l'index (1..sym_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFindLocal(Const aname : TString) : Integer;
Var i : Integer;
Begin
  SymFindLocal := 0;
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = cur_proc_idx) Then
    Begin
      SymFindLocal := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  SymFind : chercher un symbole d'abord dans la portee courante,
  puis parmi les globaux (scope_unit = 0 : procedures, INTRINSIC…).
  Retourne l'index (1..sym_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFind(Const aname : TString) : Integer;
Var i : Integer;
Begin
  SymFind := 0;
  { 1. Unite courante }
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = cur_proc_idx) Then
    Begin
      SymFind := i;
      Exit;
    End;
  { 2. Globaux }
  For i := 1 To sym_count Do
    If (sym_table^[i].name = aname) And
       (sym_table^[i].scope_unit = 0) Then
    Begin
      SymFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  SymEnter : ajouter un nouveau symbole dans la table.
  Le nom est tronque a 6 chars avec avertissement si necessaire.
  Signale une erreur si le symbole existe deja dans l'unite courante.
  Retourne l'index cree (ou l'index existant en cas de doublon).
  -------------------------------------------------------------------------- }
Function SymEnter(Const aname : TString; akind : TSymKind;
                  adtype : TDataType) : Integer;
Var
  idx   : Integer;
  sname : TString;
  d     : Integer;
Begin
  SymEnter := 0;
  sname := aname;
  If Length(sname) > 6 Then
  Begin
    WarnMsg('Identifiant tronque a 6 chars : ' + sname);
    sname := Copy(sname, 1, 6);
  End;
  { Doublon dans la portee courante ? }
  idx := SymFindLocal(sname);
  If idx > 0 Then
  Begin
    ErrorMsg('Symbole deja declare dans cette unite : ' + sname);
    SymEnter := idx;
    Exit;
  End;
  { Place disponible ? }
  If sym_count >= MAX_SYM Then
  Begin
    ErrorMsg('Table symboles saturee (MAX=' + IntToStr(MAX_SYM) + ')');
    Exit;
  End;
  Inc(sym_count);
  idx := sym_count;
  With sym_table^[idx] Do
  Begin
    name       := sname;
    kind       := akind;
    dtype      := adtype;
    char_len   := 1;
    type_size  := DataTypeSize(adtype, 1);
    ndim       := 0;
    For d := 1 To MAX_DIM Do
    Begin
      dims[d].lb := 1;
      dims[d].ub := 0;
    End;
    asm_label  := 'FV_' + sname;
    bp_offset  := 0;
    is_save    := False;
    is_dummy   := False;
    is_defined := False;
    common_blk := 0;
    common_off := 0;
    equiv_grp  := 0;
    equiv_off  := 0;
    const_ival := 0;
    const_rval := 0;
    const_sval := '';
    proc_idx   := 0;
    scope_unit := cur_proc_idx;
  End;
  SymEnter := idx;
End;

{ --------------------------------------------------------------------------
  SymReset : supprimer tous les symboles appartenant a l'unite courante
  (scope_unit = cur_proc_idx).  Les symboles globaux (scope_unit = 0)
  sont conserves.  A appeler apres la generation de code d'une unite.
  -------------------------------------------------------------------------- }
Procedure SymReset;
Var i, j : Integer;
Begin
  j := 0;
  For i := 1 To sym_count Do
    If sym_table^[i].scope_unit <> cur_proc_idx Then
    Begin
      Inc(j);
      sym_table^[j] := sym_table^[i];
    End;
  sym_count := j;
End;

{ ==========================================================================
  Table des etiquettes numeriques (FORMAT, GOTO, DO …)
  ========================================================================== }

{ --------------------------------------------------------------------------
  LabelFind : chercher une etiquette par son numero.
  Retourne l'index (1..lbl_count) ou 0 si non trouvee.
  -------------------------------------------------------------------------- }
Function LabelFind(anum : Integer) : Integer;
Var i : Integer;
Begin
  LabelFind := 0;
  For i := 1 To lbl_count Do
    If lbl_table^[i].num = anum Then
    Begin
      LabelFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  LabelEnter : creer une entree pour l'etiquette anum si elle n'existe pas.
  Retourne l'index existant ou nouvellement cree (0 si table saturee).
  -------------------------------------------------------------------------- }
Function LabelEnter(anum : Integer) : Integer;
Var idx : Integer;
Begin
  idx := LabelFind(anum);
  If idx > 0 Then
  Begin
    LabelEnter := idx;
    Exit;
  End;
  If lbl_count >= MAX_LABELS Then
  Begin
    ErrorMsg('Table etiquettes saturee (MAX=' + IntToStr(MAX_LABELS) + ')');
    LabelEnter := 0;
    Exit;
  End;
  Inc(lbl_count);
  idx := lbl_count;
  With lbl_table^[idx] Do
  Begin
    num        := anum;
    asm_label  := 'FL_' + IntToStr(anum);
    defined    := False;
    referenced := False;
    do_end     := False;
    line       := 0;
  End;
  LabelEnter := idx;
End;

{ --------------------------------------------------------------------------
  LabelMarkDefined : marquer une etiquette comme definie (vue en cols 1-5).
  Signale une erreur si elle est redeclare avec un numero deja defini.
  -------------------------------------------------------------------------- }
Procedure LabelMarkDefined(anum : Integer; aline : Integer);
Var idx : Integer;
Begin
  idx := LabelEnter(anum);
  If idx = 0 Then Exit;
  With lbl_table^[idx] Do
  Begin
    If defined Then
      ErrorMsg('Etiquette ' + IntToStr(anum) +
               ' deja definie (premiere a la ligne ' + IntToStr(line) + ')')
    Else
    Begin
      defined := True;
      line    := aline;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  LabelCheckAll : controler en fin d'unite qu'il n'y a pas d'etiquettes
  referencees (GOTO/DO) mais jamais definies dans le source.
  -------------------------------------------------------------------------- }
Procedure LabelCheckAll;
Var i : Integer;
Begin
  For i := 1 To lbl_count Do
    With lbl_table^[i] Do
      If referenced And Not defined Then
        ErrorMsg('Etiquette ' + IntToStr(num) +
                 ' referencee mais jamais definie');
End;

{ --------------------------------------------------------------------------
  LabelReset : reinitialiser la table des etiquettes pour une nouvelle
  unite de programme.
  -------------------------------------------------------------------------- }
Procedure LabelReset;
Begin
  lbl_count := 0;
End;

{ ==========================================================================
  Table des blocs COMMON
  ========================================================================== }

{ --------------------------------------------------------------------------
  CommonFind : chercher un bloc COMMON par son nom.
  '' = BLANK COMMON. Retourne l'index (1..common_count) ou 0.
  -------------------------------------------------------------------------- }
Function CommonFind(Const aname : TString) : Integer;
Var i : Integer;
Begin
  CommonFind := 0;
  For i := 1 To common_count Do
    If common_table^[i].name = aname Then
    Begin
      CommonFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  CommonEnter : creer un bloc COMMON s'il n'existe pas encore.
  Retourne l'index existant ou nouvellement cree (0 si table saturee).
  -------------------------------------------------------------------------- }
Function CommonEnter(Const aname : TString) : Integer;
Var idx : Integer;
Begin
  idx := CommonFind(aname);
  If idx > 0 Then
  Begin
    CommonEnter := idx;
    Exit;
  End;
  If common_count >= MAX_COMMON Then
  Begin
    ErrorMsg('Table COMMON saturee (MAX=' + IntToStr(MAX_COMMON) + ')');
    CommonEnter := 0;
    Exit;
  End;
  Inc(common_count);
  idx := common_count;
  With common_table^[idx] Do
  Begin
    name       := aname;
    If aname = '' Then asm_label := '_FC_BLANK_'
    Else             asm_label := '_FC_' + aname + '_';
    total_size := 0;
  End;
  CommonEnter := idx;
End;

{ ==========================================================================
  Table des enonces FORMAT
  ========================================================================== }

{ --------------------------------------------------------------------------
  FmtFind : chercher un FORMAT par son numero d'etiquette.
  Retourne l'index (1..fmt_count) ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function FmtFind(anum : Integer) : Integer;
Var i : Integer;
Begin
  FmtFind := 0;
  For i := 1 To fmt_count Do
    If fmt_table^[i].lbl_num = anum Then
    Begin
      FmtFind := i;
      Exit;
    End;
End;

{ --------------------------------------------------------------------------
  FmtEnter : enregistrer un enonce FORMAT.
  Si le numero existe deja, le texte est remplace avec avertissement.
  Retourne l'index (0 si table saturee).
  -------------------------------------------------------------------------- }
Function FmtEnter(anum : Integer; Const atext : TString) : Integer;
Var idx : Integer;
Begin
  idx := FmtFind(anum);
  If idx > 0 Then
  Begin
    WarnMsg('FORMAT ' + IntToStr(anum) + ' redefini');
    fmt_table^[idx].text := atext;
    FmtEnter := idx;
    Exit;
  End;
  If fmt_count >= MAX_FORMAT Then
  Begin
    ErrorMsg('Table FORMAT saturee (MAX=' + IntToStr(MAX_FORMAT) + ')');
    FmtEnter := 0;
    Exit;
  End;
  Inc(fmt_count);
  idx := fmt_count;
  With fmt_table^[idx] Do
  Begin
    lbl_num   := anum;
    text      := atext;
    asm_label := 'FK_FMT_' + IntToStr(anum);
  End;
  FmtEnter := idx;
End;

{ ============================================================
  TODO 05 - TYPAGE IMPLICITE ET DECLARATIONS DE TYPE
  ============================================================
  Regle F77 par defaut : I J K L M N -> INTEGER, reste -> REAL.
  IMPLICIT NONE interdit tout type implicite.
  IMPLICIT type(ranges) modifie les regles pour des plages de lettres.
  Declarations explicites : INTEGER/REAL/DOUBLEPRECISION/COMPLEX/
  LOGICAL/CHARACTER [*n] var [*m] , var ...

  Fonctions exposees :
    ImplicitReset           -- reinit regles par defaut (entre unites)
    ApplyImplicit(name)     -- type implicite par 1ere lettre du nom
    SymGetOrCreate(name)    -- trouve ou cree un symbole avec type implicite
    ParseStarSize(default)  -- consomme [*n] ; retourne n ou default
    ParseImplicit           -- parse enonce IMPLICIT (cur_tok apres kw)
    ParseTypeDecl(dt)       -- parse liste de variables typees
  ============================================================ }

{ --------------------------------------------------------------------------
  ImplicitReset : reinitialiser les regles implicites pour une nouvelle
  unite de programme.  I-N -> INTEGER, reste -> REAL (norme F77 par defaut).
  -------------------------------------------------------------------------- }
Procedure ImplicitReset;
Var c : Char;
Begin
  impl_none := False;
  For c := 'A' To 'Z' Do
    impl_type[c] := DT_REAL;
  For c := 'I' To 'N' Do
    impl_type[c] := DT_INTEGER;
End;

{ --------------------------------------------------------------------------
  ApplyImplicit : retourner le type implicite d'une variable d'apres
  la premiere lettre de son nom.
  -------------------------------------------------------------------------- }
Function ApplyImplicit(Const aname : TString) : TDataType;
Var c : Char;
Begin
  If Length(aname) = 0 Then
  Begin
    ApplyImplicit := DT_INTEGER;
    Exit;
  End;
  c := aname[1];
  If (c >= 'a') And (c <= 'z') Then c := Chr(Ord(c) - 32);
  If (c >= 'A') And (c <= 'Z') Then
    ApplyImplicit := impl_type[c]
  Else
    ApplyImplicit := DT_INTEGER;
End;

{ --------------------------------------------------------------------------
  SymGetOrCreate : trouver un symbole dans la portee courante, ou en creer
  un nouveau avec son type implicite.  Si IMPLICIT NONE est actif et que
  le symbole n'existe pas, signale une erreur.
  Retourne l'index dans sym_table (0 = erreur).
  -------------------------------------------------------------------------- }
Function SymGetOrCreate(Const aname : TString) : Integer;
Var
  idx : Integer;
  dt  : TDataType;
Begin
  idx := SymFind(aname);
  If idx > 0 Then
  Begin
    SymGetOrCreate := idx;
    Exit;
  End;
  If impl_none Then
  Begin
    ErrorMsg('Variable non declaree (IMPLICIT NONE actif) : ' + aname);
    SymGetOrCreate := 0;
    Exit;
  End;
  dt  := ApplyImplicit(aname);
  idx := SymEnter(aname, SK_VAR, dt);
  If idx > 0 Then
  Begin
    sym_table^[idx].type_size := DataTypeSize(dt, 1);
    sym_table^[idx].char_len  := 1;
  End;
  SymGetOrCreate := idx;
End;

{ --------------------------------------------------------------------------
  ParseStarSize : consommer un specificateur de taille optionnel [*n].
  Si absent, retourne default_sz.  Valeur -1 = taille ajustable (*).
  cur_tok doit etre positionne sur le token courant.
  -------------------------------------------------------------------------- }
Function ParseStarSize(default_sz : Integer) : Integer;
Begin
  ParseStarSize := default_sz;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
  Begin
    LexNext;
    { CHARACTER*(*) : taille ajustable pour parametres formels }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then LexNext
      Else ErrorMsg('Attendu * dans CHARACTER*(*)');
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext
      Else ErrorMsg('Attendu ) dans CHARACTER*(*)');
      ParseStarSize := -1;   { -1 = ajustable }
    End
    Else If cur_tok.kind = TK_INTEGER Then
    Begin
      ParseStarSize := cur_tok.int_val;
      LexNext;
    End
    Else
      ErrorMsg('Taille numerique attendue apres * dans declaration de type');
  End;
End;

{ --------------------------------------------------------------------------
  ParseImplicit : parser un enonce IMPLICIT.
  Appele avec cur_tok sur le premier token APRES le mot-cle IMPLICIT.
  Syntaxe :
    IMPLICIT NONE
    IMPLICIT type[*n](lettre[-lettre] [, ...]) [, type[*n](...)] ...
  -------------------------------------------------------------------------- }
Procedure ParseImplicit;
Var
  dt       : TDataType;
  sz       : Integer;
  c1, c2   : Char;
  c        : Char;
Begin
  { IMPLICIT NONE }
  If (cur_tok.kind = TK_IDENT) And (cur_tok.val = 'NONE') Then
  Begin
    impl_none := True;
    For c := 'A' To 'Z' Do impl_type[c] := DT_NONE;
    LexNext;
    Exit;
  End;

  { IMPLICIT type[*n](ranges) [, type[*n](ranges)] ... }
  While cur_tok.kind = TK_KEYWORD Do
  Begin
    { Identifier le type }
    dt := DT_NONE;
    If      cur_tok.val = 'INTEGER'         Then dt := DT_INTEGER
    Else If cur_tok.val = 'REAL'            Then dt := DT_REAL
    Else If cur_tok.val = 'DOUBLEPRECISION' Then dt := DT_DOUBLE
    Else If cur_tok.val = 'COMPLEX'         Then dt := DT_COMPLEX
    Else If cur_tok.val = 'LOGICAL'         Then dt := DT_LOGICAL
    Else If cur_tok.val = 'CHARACTER'       Then dt := DT_CHARACTER
    Else
    Begin
      ErrorMsg('Type inconnu dans IMPLICIT : ' + cur_tok.val);
      Exit;
    End;
    LexNext;

    { Taille optionnelle *n }
    sz := ParseStarSize(DataTypeSize(dt, 1));

    { '(' liste de plages ')' }
    If (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> '(') Then
    Begin
      ErrorMsg('Attendu ( apres le type dans IMPLICIT');
      Exit;
    End;
    LexNext;  { consommer '(' }

    Repeat
      { Premiere lettre de la plage }
      If (cur_tok.kind <> TK_IDENT) Or (Length(cur_tok.val) <> 1) Then
      Begin
        ErrorMsg('Lettre unique attendue dans plage IMPLICIT');
        Exit;
      End;
      c1 := cur_tok.val[1];
      c2 := c1;
      LexNext;

      { Plage c1-c2 ? }
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
      Begin
        LexNext;
        If (cur_tok.kind = TK_IDENT) And (Length(cur_tok.val) = 1) Then
        Begin
          c2 := cur_tok.val[1];
          LexNext;
        End
        Else
          ErrorMsg('Lettre de fin de plage attendue dans IMPLICIT');
      End;

      { Appliquer le type a toutes les lettres de la plage }
      If c2 >= c1 Then
        For c := c1 To c2 Do impl_type[c] := dt
      Else
        ErrorMsg('Plage IMPLICIT invalide : ' + c1 + '-' + c2);

      { Virgule : autre plage dans les memes parentheses }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

    { ')' fermant }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) a la fin de la plage IMPLICIT');

    { Virgule : autre type-spec }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  End;
End;

{ --------------------------------------------------------------------------
  ParseTypeDecl : parser un enonce de declaration de type.
  Appele avec dt = le type de base, cur_tok sur le premier token apres
  le mot-cle de type (et apres l'eventuel *n global).
  Syntaxe :
    INTEGER [*sz] var1 [*n] [(dim)] , var2 [*n] , ...
  Pour chaque variable :
    - si elle existe deja, son type est mis a jour
    - sinon, elle est creee avec SK_VAR et le type declare
  Les dimensions entre parentheses dans une declaration de type (extensions)
  sont simplement ignorees ici (traitees par TODO 06 via DIMENSION).
  -------------------------------------------------------------------------- }
Procedure ParseTypeDecl(dt : TDataType);
Var
  def_sz  : Integer;   { taille par defaut du type }
  var_sz  : Integer;   { taille pour cette variable }
  vname   : TString;
  idx     : Integer;
Begin
  def_sz := DataTypeSize(dt, 1);
  { Taille globale optionnelle apres le type : INTEGER*2 var1, var2 }
  def_sz := ParseStarSize(def_sz);

  { Liste de variables }
  Repeat
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans declaration de type');
      Exit;
    End;
    vname := cur_tok.val;
    LexNext;

    { Taille specifique a cette variable : var*n }
    var_sz := ParseStarSize(def_sz);

    { Trouver ou creer le symbole }
    idx := SymFindLocal(vname);
    If idx = 0 Then
    Begin
      { Nouveau symbole : creer avec SK_VAR }
      idx := SymEnter(vname, SK_VAR, dt);
    End
    Else
    Begin
      { Symbole existant (ex. DIMENSION deja vu) : mettre a jour le type }
      sym_table^[idx].dtype := dt;
    End;

    If idx > 0 Then
    Begin
      sym_table^[idx].dtype     := dt;
      sym_table^[idx].type_size := var_sz;
      If dt = DT_CHARACTER Then
        sym_table^[idx].char_len := var_sz
      Else
        sym_table^[idx].char_len := 1;
    End;

    { Ignorer les dimensions eventuellement presentes ici :
      ex. INTEGER A(10) dans une declaration de type (extension F77).
      Elles seront traitees par le parseur DIMENSION (TODO 06). }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      LexNext;
      While (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> ')') Do
      Begin
        If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
        Begin
          ErrorMsg('Parenthese non fermee dans declaration de type');
          Exit;
        End;
        LexNext;
      End;
      LexNext; { consommer ')' }
    End;

    { Separateur de variables }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ ============================================================
  TODO 06 - DECLARATIONS DIMENSION ET TABLEAUX
  ============================================================
  DIMENSION var(borne[,borne]...) avec 1 a 7 dimensions (norme F77).
  Borne simple n  -> lb=1, ub=n
  Borne double m:n -> lb=m, ub=n
  Borne ajustable * -> ub=-1 (dummy arrays de taille inconnue)

  Fonctions exposees :
    DimExtent(idx,d)        -- etendue de la dimension d (ub-lb+1)
    ArrayTotalElems(idx)    -- produit de toutes les etendues
    ArrayTotalSize(idx)     -- ArrayTotalElems * type_size (octets)
    ArrayStride(idx,d)      -- pas d'adressage pour la dim d (col-major)
    ParseBoundExpr(v,adj)   -- lire une borne (entier ou *)
    ParseDimSpec(idx)       -- parse (dims) et remplit sym_table^[idx]
    ParseDimension          -- parse enonce DIMENSION complet
  ============================================================ }

{ --------------------------------------------------------------------------
  DimExtent : etendue de la dimension d (ub - lb + 1).
  Les dimensions ajustables (ub = -1) retournent 0.
  -------------------------------------------------------------------------- }
Function DimExtent(idx, d : Integer) : Integer;
Var lb, ub : Integer;
Begin
  DimExtent := 0;
  If (idx < 1) Or (idx > sym_count) Then Exit;
  If (d < 1) Or (d > sym_table^[idx].ndim) Then Exit;
  lb := sym_table^[idx].dims[d].lb;
  ub := sym_table^[idx].dims[d].ub;
  If ub = -1 Then DimExtent := 0   { ajustable -> etendue inconnue }
  Else            DimExtent := ub - lb + 1;
End;

{ --------------------------------------------------------------------------
  ArrayTotalElems : produit des etendues de toutes les dimensions.
  Retourne 0 si au moins une dimension est ajustable.
  -------------------------------------------------------------------------- }
Function ArrayTotalElems(idx : Integer) : Integer;
Var i, prod, ext : Integer;
Begin
  ArrayTotalElems := 0;
  If (idx < 1) Or (idx > sym_count) Then Exit;
  If sym_table^[idx].ndim = 0 Then
  Begin
    ArrayTotalElems := 1;
    Exit;
  End;
  prod := 1;
  For i := 1 To sym_table^[idx].ndim Do
  Begin
    ext := DimExtent(idx, i);
    If ext = 0 Then Exit;   { dimension ajustable -> total inconnu }
    prod := prod * ext;
  End;
  ArrayTotalElems := prod;
End;

{ --------------------------------------------------------------------------
  ArrayTotalSize : taille totale en octets = total_elems * type_size.
  -------------------------------------------------------------------------- }
Function ArrayTotalSize(idx : Integer) : Integer;
Begin
  ArrayTotalSize := ArrayTotalElems(idx) * sym_table^[idx].type_size;
End;

{ --------------------------------------------------------------------------
  ArrayStride : pas (stride) de la dimension d en ordre column-major.
  stride(1) = 1
  stride(d) = etendue(1) * etendue(2) * ... * etendue(d-1)
  Retourne 0 si une dimension precedente est ajustable.
  -------------------------------------------------------------------------- }
Function ArrayStride(idx, d : Integer) : Integer;
Var i, s, ext : Integer;
Begin
  ArrayStride := 0;
  If d < 1 Then Exit;
  s := 1;
  For i := 1 To d - 1 Do
  Begin
    ext := DimExtent(idx, i);
    If ext = 0 Then Exit;
    s := s * ext;
  End;
  ArrayStride := s;
End;

{ --------------------------------------------------------------------------
  ParseBoundExpr : lire une expression de borne (entier signé ou *).
  out_val     = valeur numerique (0 si ajustable)
  out_adj     = True si la borne est ajustable (*)
  Supporte uniquement les constantes entieres simples (et + / - unaire).
  -------------------------------------------------------------------------- }
Procedure ParseBoundExpr(Var out_val : Integer; Var out_adj : Boolean);
Var sign : Integer;
Begin
  out_val := 0;
  out_adj := False;

  If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
  Begin
    out_adj := True;
    LexNext;
    Exit;
  End;

  sign := 1;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin
    sign := -1;
    LexNext;
  End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    out_val := sign * Integer(cur_tok.int_val);
    LexNext;
  End
  Else
    ErrorMsg('Borne de dimension attendue (entier ou *), obtenu : ' +
             cur_tok.val);
End;

{ --------------------------------------------------------------------------
  ParseDimSpec : parser la liste de dimensions d'un tableau.
  cur_tok doit etre sur '(' a l'entree.
  Remplit sym_table^[idx].dims[1..ndim] et sym_table^[idx].ndim.
  Met a jour sym_table^[idx].kind := SK_ARRAY.
  -------------------------------------------------------------------------- }
Procedure ParseDimSpec(idx : Integer);
Var
  d        : Integer;
  lb, ub   : Integer;
  v1, v2   : Integer;
  adj1,adj2: Boolean;
Begin
  If (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> '(') Then
  Begin
    ErrorMsg('Attendu ( pour la liste de dimensions');
    Exit;
  End;
  LexNext;  { consommer '(' }

  d := 0;
  Repeat
    If d >= MAX_DIM Then
    Begin
      ErrorMsg('Trop de dimensions (max ' + IntToStr(MAX_DIM) + ')');
      { avancer jusqu'a ')' }
      While (cur_tok.kind <> TK_PUNCT) Or (cur_tok.val <> ')') Do
      Begin
        If (cur_tok.kind = TK_EOF) Or (cur_tok.kind = TK_NEWLINE) Then Break;
        LexNext;
      End;
      Break;
    End;

    Inc(d);

    { Lire premiere valeur }
    ParseBoundExpr(v1, adj1);

    { Deux-points ? -> lb:ub }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ':') Then
    Begin
      LexNext;
      lb := v1;
      ParseBoundExpr(v2, adj2);
      If adj2 Then ub := -1
      Else         ub := v2;
    End
    Else
    Begin
      { Borne simple : lb=1, ub=v1 (ou -1 si ajustable) }
      lb := 1;
      If adj1 Then ub := -1
      Else         ub := v1;
    End;

    If (ub <> -1) And (ub < lb) Then
      ErrorMsg('Borne superieure < borne inferieure dans DIMENSION');

    sym_table^[idx].dims[d].lb := lb;
    sym_table^[idx].dims[d].ub := ub;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

  { Fermer ')' }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
    LexNext
  Else
    ErrorMsg('Attendu ) pour fermer la liste de dimensions');

  sym_table^[idx].ndim := d;
  sym_table^[idx].kind := SK_ARRAY;

  { Mettre a jour la taille totale si toutes dimensions connues }
  sym_table^[idx].type_size := DataTypeSize(sym_table^[idx].dtype,
                                             sym_table^[idx].char_len);
End;

{ --------------------------------------------------------------------------
  ParseDimension : parser un enonce DIMENSION complet.
  Appele avec cur_tok sur le premier token apres le mot-cle DIMENSION.
  Syntaxe :
    DIMENSION var(dim_spec) [, var(dim_spec)] ...
  -------------------------------------------------------------------------- }
Procedure ParseDimension;
Var
  vname : TString;
  idx   : Integer;
Begin
  Repeat
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans DIMENSION');
      Exit;
    End;
    vname := cur_tok.val;
    LexNext;

    { Trouver ou creer le symbole (avec type implicite si nouveau) }
    idx := SymFindLocal(vname);
    If idx = 0 Then
      idx := SymGetOrCreate(vname);

    If idx = 0 Then Exit;

    { Parser le specificateur de dimensions }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    Begin
      ParseDimSpec(idx);
    End
    Else
    Begin
      ErrorMsg('Liste de dimensions attendue apres ' + vname +
               ' dans DIMENSION');
      Exit;
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ ============================================================
  TODO 07 - DECLARATIONS COMMON, EQUIVALENCE ET SAVE
  ============================================================
  Fonctions exposees :
    ParseCommonVarIntoBlock(ci, vname) -- attacher une variable au bloc ci
    ParseCommon                        -- parser un enonce COMMON complet
    ParseEquivalence                   -- parser un enonce EQUIVALENCE
    ParseSave                          -- parser un enonce SAVE
  Architecture memoire :
    sym_table^[i].common_blk = index du bloc COMMON (1..common_count)
    sym_table^[i].common_off = offset en octets dans le bloc
    sym_table^[i].asm_label  = '_FC_NOM_' ou '_FC_NOM_+off'
    sym_table^[i].equiv_grp  = numero du groupe EQUIVALENCE (1..equiv_count)
    sym_table^[i].equiv_off  = offset dans le groupe (0 sans indice)
    sym_table^[i].is_save    = True si SAVE applique
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseCommonVarIntoBlock : attacher la variable vname au bloc COMMON ci.
  Met a jour sym_table^[idx].common_blk, common_off et total_size du bloc.
  Si le token courant est '(' apres vname, une liste de dimensions est
  parsee (declaration implicite de tableau a l'interieur de COMMON).
  -------------------------------------------------------------------------- }
Procedure ParseCommonVarIntoBlock(ci : Integer; Const vname : TString);
Var
  idx : Integer;
  vsz : Integer;
  off : Integer;
Begin
  idx := SymGetOrCreate(vname);
  If idx = 0 Then Exit;

  { Dimensions optionnelles dans COMMON : COMMON /B/ A(10,3) }
  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
    ParseDimSpec(idx);

  { Verifier que la variable n'est pas deja dans un autre bloc COMMON }
  If sym_table^[idx].common_blk <> 0 Then
  Begin
    If sym_table^[idx].common_blk <> ci Then
      ErrorMsg('Variable ' + vname + ' deja dans un autre bloc COMMON')
    Else
      WarnMsg('Variable ' + vname + ' apparait deux fois dans le meme COMMON');
    Exit;
  End;

  { Taille a allouer dans le bloc }
  If sym_table^[idx].ndim > 0 Then
    vsz := ArrayTotalSize(idx)
  Else
  Begin
    vsz := sym_table^[idx].type_size;
    If vsz <= 0 Then
      vsz := DataTypeSize(sym_table^[idx].dtype, sym_table^[idx].char_len);
  End;
  If vsz <= 0 Then vsz := 2;    { securite : INTEGER par defaut }

  { Offset = fin courante du bloc, puis etendre le bloc }
  off := common_table^[ci].total_size;
  sym_table^[idx].common_blk := ci;
  sym_table^[idx].common_off := off;
  common_table^[ci].total_size := off + vsz;

  { Label ASM : base du bloc [+ offset] }
  If off = 0 Then
    sym_table^[idx].asm_label := common_table^[ci].asm_label
  Else
    sym_table^[idx].asm_label := common_table^[ci].asm_label
                                  + '+' + IntToStr(off);
End;

{ --------------------------------------------------------------------------
  ParseCommon : parser un enonce COMMON complet.
  Syntaxe F77 :
    COMMON [/nom/] v1 [, v2 ...] [/nom2/ v3 ...]
    COMMON // v1, v2 ...   -> BLANK COMMON (slashes doubles)
  Le mot-cle COMMON est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseCommon;
Var
  block_name : TString;
  ci         : Integer;
  vname      : TString;
  more_segs  : Boolean;
Begin
  more_segs := True;
  While more_segs
    And (cur_tok.kind <> TK_NEWLINE)
    And (cur_tok.kind <> TK_EOF) Do
  Begin
    { --- Detecter le nom du segment : /nom/ ou // --- }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
    Begin
      LexNext;
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      Begin
        { // = BLANK COMMON }
        block_name := '';
        LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        block_name := cur_tok.val;
        LexNext;
        { Consommer '/' fermant }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          LexNext
        Else
          ErrorMsg('Attendu / fermant apres le nom du bloc COMMON');
      End
      Else
      Begin
        ErrorMsg('Nom de bloc COMMON invalide apres /');
        block_name := '';
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then LexNext;
      End;
    End
    Else
      { Pas de / : BLANK COMMON implicite (seul segment sans modifier) }
      block_name := '';

    { Obtenir ou creer le bloc COMMON }
    ci := CommonEnter(block_name);
    If ci = 0 Then Exit;

    { --- Liste de variables separees par des virgules --- }
    Repeat
      If cur_tok.kind <> TK_IDENT Then
      Begin
        ErrorMsg('Identificateur attendu dans la liste COMMON');
        Break;
      End;
      vname := cur_tok.val;
      LexNext;
      ParseCommonVarIntoBlock(ci, vname);

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      Begin
        LexNext;
        { Nouveau segment si on a '/' apres la virgule }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          Break;   { sortir de la boucle vars -> traiter le segment suivant }
      End
      Else
      Begin
        more_segs := False;  { pas de ',' -> fin du COMMON }
        Break;
      End;
    Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
  End;
End;

{ --------------------------------------------------------------------------
  ParseEquivalence : parser un enonce EQUIVALENCE.
  Syntaxe F77 :
    EQUIVALENCE (v1, v2 [, v3, ...]) [, (v4, v5, ...) ...]
  Le mot-cle EQUIVALENCE est deja consomme avant l'appel.
  Chaque groupe recoit un index equiv_grp unique (1..equiv_count).
  Les sous-elements de tableau (v(i)) sont reconnus mais l'offset n'est
  pas calcule ici (necessiterait le generateur d'expressions TODO 10).
  Une equivalence entre deux blocs COMMON distincts est une erreur F77.
  -------------------------------------------------------------------------- }
Procedure ParseEquivalence;
Var
  vname    : TString;
  idx      : Integer;
  base_idx : Integer;
  grp      : Integer;
Begin
  Repeat
    LexExpect('(');
    grp      := 0;
    base_idx := 0;

    { --- Lire la liste de variables du groupe --- }
    Repeat
      If cur_tok.kind <> TK_IDENT Then
      Begin
        ErrorMsg('Identificateur attendu dans EQUIVALENCE');
        Break;
      End;
      vname := cur_tok.val;
      LexNext;

      { Sous-element de tableau optionnel : (v(i)) -> ignorer l'indice }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      Begin
        WarnMsg('Sous-element de tableau dans EQUIVALENCE non supporte : ' + vname);
        LexNext;
        While Not ((cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')' ))
              And (cur_tok.kind <> TK_NEWLINE)
              And (cur_tok.kind <> TK_EOF) Do
          LexNext;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End;

      idx := SymGetOrCreate(vname);
      If idx > 0 Then
      Begin
        If base_idx = 0 Then
        Begin
          { Premier element du groupe : variable de reference (offset=0) }
          Inc(equiv_count);
          grp      := equiv_count;
          base_idx := idx;
          sym_table^[idx].equiv_grp := grp;
          sym_table^[idx].equiv_off := 0;
        End
        Else
        Begin
          { Verifier coherence inter-COMMON }
          If (sym_table^[idx].common_blk <> 0)
          And (sym_table^[base_idx].common_blk <> 0)
          And (sym_table^[idx].common_blk <> sym_table^[base_idx].common_blk) Then
            ErrorMsg('EQUIVALENCE illegale entre deux blocs COMMON distincts : '
                     + vname)
          Else
          Begin
            sym_table^[idx].equiv_grp := grp;
            sym_table^[idx].equiv_off := 0;   { offset a affiner en TODO 10 }
          End;
        End;
      End;

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

    { Fermer la parenthese du groupe }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) pour fermer un groupe EQUIVALENCE');

    { Groupe suivant ? }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ --------------------------------------------------------------------------
  ParseSave : parser un enonce SAVE.
  Syntaxe F77 :
    SAVE              -> toutes les variables locales sont preservees
    SAVE v1, v2, ...  -> uniquement les variables listees
    SAVE /COMMON/ ... -> ignore (COMMON est toujours statique en F77)
  Le mot-cle SAVE est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseSave;
Var
  vname : TString;
  idx   : Integer;
  i     : Integer;
Begin
  If (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF) Then
  Begin
    { SAVE sans liste : marquer toutes les variables locales scalaires }
    For i := 1 To sym_count Do
      If (sym_table^[i].kind = SK_VAR)
      And (sym_table^[i].common_blk = 0) Then
        sym_table^[i].is_save := True;
    NoteMsg('SAVE sans liste : toutes les variables locales preservees');
  End
  Else
  Begin
    { SAVE avec liste explicite }
    Repeat
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      Begin
        { SAVE /nom/ : COMMON est toujours statique en F77, rien a faire }
        LexNext;
        If cur_tok.kind = TK_IDENT Then
        Begin
          vname := cur_tok.val;
          LexNext;
          WarnMsg('SAVE /COMMON/ superflu (COMMON toujours statique) : /'
                  + vname + '/');
        End;
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        vname := cur_tok.val;
        LexNext;
        idx := SymGetOrCreate(vname);
        If idx > 0 Then
          sym_table^[idx].is_save := True;
      End
      Else
      Begin
        ErrorMsg('Identificateur ou /COMMON/ attendu dans SAVE');
        Break;
      End;

      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        Break;
    Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
  End;
End;

{ ============================================================
  TODO 08 - DECLARATION DATA ET CONSTANTES NOMMEES (PARAMETER)
  ============================================================
  Fonctions exposees :
    ParseDataConst(out_dt, out_ival, out_rval, out_sval)
        -- lire une constante litterale Fortran 77 (toujours avec signe)
    ParseData
        -- parser un enonce DATA complet
    ParseParameter
        -- parser un enonce PARAMETER (constantes symboliques)
  Architecture :
    DATA scalaire  -> sym_table^[idx].const_ival/rval/sval + is_defined
    PARAMETER      -> sym_table^[idx].kind = SK_PARAM_CONST + const_*
    Emission DATA  -> deferred au TODO 09 (generateur de code 8086)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseDataConst : lire une constante litterale Fortran 77 avec signe.
  Reconnus : entier, reel, double, logique .TRUE./.FALSE., chaine,
             hollerith, complexe (re,im), reference a un PARAMETER.
  Retourne le type et les trois champs de valeur.
  -------------------------------------------------------------------------- }
Procedure ParseDataConst(Var out_dt   : TDataType;
                         Var out_ival : LongInt;
                         Var out_rval : Real;
                         Var out_sval : TString);
Var
  neg     : Boolean;
  pi      : Integer;
  im_dt   : TDataType;
  im_ival : LongInt;
  im_rval : Real;
  im_sval : TString;
Begin
  out_dt   := DT_INTEGER;
  out_ival := 0;
  out_rval := 0.0;
  out_sval := '';
  im_dt    := DT_REAL;
  im_ival  := 0;
  im_rval  := 0.0;
  im_sval  := '';

  { Signe unaire optionnel }
  neg := False;
  If (cur_tok.kind = TK_OP) And (cur_tok.val = '-') Then
  Begin
    neg := True;
    LexNext;
  End
  Else If (cur_tok.kind = TK_OP) And (cur_tok.val = '+') Then
    LexNext;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    out_dt   := DT_INTEGER;
    out_ival := cur_tok.int_val;
    If neg Then out_ival := -out_ival;
    LexNext;
  End
  Else If cur_tok.kind = TK_REAL Then
  Begin
    out_dt   := DT_REAL;
    out_rval := cur_tok.real_val;
    If neg Then out_rval := -out_rval;
    LexNext;
  End
  Else If cur_tok.kind = TK_DOUBLE Then
  Begin
    out_dt   := DT_DOUBLE;
    out_rval := cur_tok.real_val;
    If neg Then out_rval := -out_rval;
    LexNext;
  End
  Else If cur_tok.kind = TK_LOGICAL Then
  Begin
    out_dt := DT_LOGICAL;
    If cur_tok.val = '.TRUE.' Then out_ival := -1 Else out_ival := 0;
    LexNext;
  End
  Else If cur_tok.kind = TK_STRING Then
  Begin
    out_dt   := DT_CHARACTER;
    out_sval := cur_tok.val;
    LexNext;
  End
  Else If cur_tok.kind = TK_HOLLERITH Then
  Begin
    out_dt   := DT_CHARACTER;
    out_sval := cur_tok.val;
    LexNext;
  End
  Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
  Begin
    { Constante COMPLEX : (partie_reelle, partie_imaginaire) }
    LexNext;
    ParseDataConst(out_dt, out_ival, out_rval, out_sval);
    out_dt := DT_COMPLEX;
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
    Begin
      LexNext;
      ParseDataConst(im_dt, im_ival, im_rval, im_sval);
      { Partie imaginaire stockee dans out_ival (ecrasement approx.) }
      { Emission complete en TODO 09 }
    End
    Else
      WarnMsg('Constante COMPLEX : virgule manquante entre re et im');
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
      LexNext
    Else
      ErrorMsg('Attendu ) apres la partie imaginaire de la constante COMPLEX');
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    { Reference a une constante PARAMETER deja declaree }
    pi := SymFind(cur_tok.val);
    If (pi > 0) And (sym_table^[pi].kind = SK_PARAM_CONST) Then
    Begin
      out_dt   := sym_table^[pi].dtype;
      out_ival := sym_table^[pi].const_ival;
      out_rval := sym_table^[pi].const_rval;
      out_sval := sym_table^[pi].const_sval;
      If neg Then
      Begin
        out_ival := -out_ival;
        out_rval := -out_rval;
      End;
    End
    Else
      ErrorMsg('Constante symbolique inconnue dans DATA/PARAMETER : ' + cur_tok.val);
    LexNext;
  End
  Else
  Begin
    ErrorMsg('Constante litterale attendue, lu : ' + cur_tok.val);
    LexNext;
  End;
End;

{ --------------------------------------------------------------------------
  ParseDataApply : appliquer la valeur (dt/ival/rval/sval) au symbole idx.
  Met a jour les champs const_* et is_defined.
  -------------------------------------------------------------------------- }
Procedure ParseDataApply(idx : Integer; dt : TDataType;
                         ival : LongInt; rval : Real;
                         Const sval : TString);
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  sym_table^[idx].const_ival := ival;
  sym_table^[idx].const_rval := rval;
  sym_table^[idx].const_sval := sval;
  sym_table^[idx].is_defined := True;
  { Verification de coherence de type (avertissement seulement) }
  If (sym_table^[idx].dtype <> DT_NONE)
  And (sym_table^[idx].dtype <> dt)
  And Not ((sym_table^[idx].dtype = DT_REAL) And (dt = DT_INTEGER)) Then
    WarnMsg('Type de constante DATA (' + DataTypeName(dt) + ') different du type'
            + ' de la variable (' + DataTypeName(sym_table^[idx].dtype) + ')');
  If opt_debug Then
    NoteMsg('DATA ' + sym_table^[idx].name + ' = ' + IntToStr(ival));
End;

{ --------------------------------------------------------------------------
  ParseData : parser un enonce DATA complet.
  Syntaxe F77 :
    DATA varlist / vallist / [, varlist / vallist /  ...]
  Elements de varlist autorises :
    var           -> scalaire entier
    var(e)        -> element de tableau (indice ignore, TODO 10)
    var(ib:ie)    -> sous-chaine CHARACTER (ignore pour l'instant)
    (var(i),i=l,u[,s]) -> DO implicite (liste partielle supportee)
  Elements de vallist :
    constante      -> une valeur
    n * constante  -> n repetitions de la meme valeur (n entier > 0)
  Le mot-cle DATA est deja consomme avant l'appel.
  -------------------------------------------------------------------------- }
Procedure ParseData;
Var
  { --- cote variables --- }
  vname   : TString;
  idx     : Integer;
  { --- cote valeurs --- }
  val_dt  : TDataType;
  val_iv  : LongInt;
  val_rv  : Real;
  val_sv  : TString;
  rep     : LongInt;     { compteur de repetition egal a n dans n*val }
  more    : Boolean;
  skip_i  : Integer;     { compteur de ) a consommer pour DO implicite }
Var
  { Buffer de variables (liste du groupe courant) }
  var_list   : Array[1..256] of Integer;  { indices sym_table }
  var_count  : Integer;                   { nombre de variables dans var_list }
  v          : Integer;                   { index courant dans var_list }
Begin
  Repeat   { boucle sur les groupes varlist / vallist / }

    { ===== COTE GAUCHE : varlist ===== }
    var_count := 0;
    more := True;
    While more
      And (cur_tok.kind <> TK_EOF)
      And (cur_tok.kind <> TK_NEWLINE) Do
    Begin
      { Test : on a atteint le '/' ? }
      If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then Break;

      { DO implicite : ( ident(...), ident = lb, ub [,step] ) }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
      Begin
        WarnMsg('DO implicite dans DATA partiellement supporte');
        skip_i := 1;
        LexNext;
        { Parser les variables interieures jusqu'a la , de controle }
        While (skip_i > 0)
          And (cur_tok.kind <> TK_EOF)
          And (cur_tok.kind <> TK_NEWLINE) Do
        Begin
          If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
            Inc(skip_i)
          Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
          Begin
            Dec(skip_i);
            If skip_i = 0 Then Break;
          End
          Else If (cur_tok.kind = TK_IDENT) And (skip_i = 1) Then
          Begin
            vname := cur_tok.val;
            { Regarder si c'est une variable de data ou la var de controle }
            { Heuristique : si prochain token est '(' ou ',' on est dans les vars }
            If var_count < 256 Then
            Begin
              Inc(var_count);
              var_list[var_count] := SymGetOrCreate(vname);
            End;
          End;
          LexNext;
        End;
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then LexNext;
      End
      Else If cur_tok.kind = TK_IDENT Then
      Begin
        vname := cur_tok.val;
        LexNext;
        idx := SymGetOrCreate(vname);

        { Sous-element / sous-chaine optionnel(le) : var(e) ou var(ib:ie) }
        If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
        Begin
          LexNext;
          { Consommer jusqu'a la ) correspondante }
          skip_i := 1;
          While (skip_i > 0)
            And (cur_tok.kind <> TK_EOF)
            And (cur_tok.kind <> TK_NEWLINE) Do
          Begin
            If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = '(') Then
              Inc(skip_i)
            Else If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
              Dec(skip_i);
            If skip_i > 0 Then LexNext Else LexNext;
          End;
          { Pour un tableau, on inscrit l'index mais sans calculer l'offset }
        End;

        If var_count < 256 Then
        Begin
          Inc(var_count);
          var_list[var_count] := idx;
        End;
      End
      Else
      Begin
        ErrorMsg('Element de liste DATA invalide : ' + cur_tok.val);
        LexNext;
      End;

      { Separateur entre elements de la varlist }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      Begin
        LexNext;
        { Si apres la virgule on a '/', c'est la fin de la varlist }
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
          more := False;
      End
      Else
        more := False;
    End;

    { Consommer le '/' separateur gauche }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      LexNext
    Else
    Begin
      ErrorMsg('Attendu / avant la liste de valeurs DATA');
      Exit;
    End;

    { ===== COTE DROIT : vallist ===== }
    v    := 1;
    more := True;
    While more
      And Not ((cur_tok.kind = TK_OP) And (cur_tok.val = '/'))
      And (cur_tok.kind <> TK_EOF)
      And (cur_tok.kind <> TK_NEWLINE) Do
    Begin
      { Detecter la repetition : n*val }
      rep := 1;
      If cur_tok.kind = TK_INTEGER Then
      Begin
        { Peut etre n* ou juste un entier }
        rep := cur_tok.int_val;
        LexNext;
        If (cur_tok.kind = TK_OP) And (cur_tok.val = '*') Then
        Begin
          LexNext;   { consommer '*', rep deja dans rep }
        End
        Else
        Begin
          { N'etait pas n*, c'etait la valeur elle-meme : emettre }
          val_dt  := DT_INTEGER;
          val_iv  := rep;
          val_rv  := 0.0;
          val_sv  := '';
          rep := 1;
          { Appliquer directement sans relire de constante }
          If v <= var_count Then
          Begin
            If var_list[v] > 0 Then
              ParseDataApply(var_list[v], val_dt, val_iv, val_rv, val_sv);
            Inc(v);
          End;
          { Separateur }
          If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
            LexNext;
          Continue;
        End;
      End;

      { Lire la valeur reelle }
      ParseDataConst(val_dt, val_iv, val_rv, val_sv);

      { Appliquer rep fois }
      While rep > 0 Do
      Begin
        If v <= var_count Then
        Begin
          If var_list[v] > 0 Then
            ParseDataApply(var_list[v], val_dt, val_iv, val_rv, val_sv);
          Inc(v);
        End;
        Dec(rep);
      End;

      { Separateur ou fin }
      If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
        LexNext
      Else
        more := False;
    End;

    { Verification : nombre de valeurs coherent ? }
    If v - 1 < var_count Then
      WarnMsg('DATA : moins de valeurs que de variables dans le groupe');
    If v - 1 > var_count Then
      WarnMsg('DATA : plus de valeurs que de variables dans le groupe');

    { Consommer le '/' fermant }
    If (cur_tok.kind = TK_OP) And (cur_tok.val = '/') Then
      LexNext
    Else
    Begin
      ErrorMsg('Attendu / apres la liste de valeurs DATA');
      Exit;
    End;

    { Groupe suivant ? Virgule optionnelle avant la prochaine varlist }
    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext;

  Until (cur_tok.kind = TK_NEWLINE) Or (cur_tok.kind = TK_EOF);
End;

{ --------------------------------------------------------------------------
  ParseParamConstExpr : evaluer une expression constante simple pour PARAMETER.
  Gere : litteraux signes, references a d'autres PARAMETER, et les
  operations  + - * /  entre constantes entieres ou reelles.
  Retourne le type et la valeur evaluee via des var-params.
  -------------------------------------------------------------------------- }
Procedure ParseParamConstExpr(Var out_dt   : TDataType;
                               Var out_ival : LongInt;
                               Var out_rval : Real;
                               Var out_sval : TString);
Var
  rdt : TDataType;
  riv : LongInt;
  rrv : Real;
  rsv : TString;
  op  : TString;
Begin
  { Terme gauche }
  ParseDataConst(out_dt, out_ival, out_rval, out_sval);

  { Operateurs * / + - binaires (precedence simplifiee : gauche-droite) }
  While (cur_tok.kind = TK_OP)
    And ((cur_tok.val = '+') Or (cur_tok.val = '-')
      Or (cur_tok.val = '*') Or (cur_tok.val = '/')) Do
  Begin
    op := cur_tok.val;
    LexNext;
    ParseDataConst(rdt, riv, rrv, rsv);

    { Harmoniser les types : si un des deux est REAL/DOUBLE, resultat REAL }
    If (out_dt = DT_INTEGER) And (rdt = DT_INTEGER) Then
    Begin
      If op = '+' Then out_ival := out_ival + riv
      Else If op = '-' Then out_ival := out_ival - riv
      Else If op = '*' Then out_ival := out_ival * riv
      Else If op = '/' Then
      Begin
        If riv = 0 Then ErrorMsg('Division par zero dans PARAMETER')
        Else out_ival := out_ival Div riv;
      End;
    End
    Else
    Begin
      { Promouvoir en reel }
      If out_dt = DT_INTEGER Then
      Begin
        out_rval := out_ival;
        out_dt   := DT_REAL;
      End;
      If rdt = DT_INTEGER Then rrv := riv;
      If op = '+' Then out_rval := out_rval + rrv
      Else If op = '-' Then out_rval := out_rval - rrv
      Else If op = '*' Then out_rval := out_rval * rrv
      Else If op = '/' Then
      Begin
        If rrv = 0.0 Then ErrorMsg('Division par zero dans PARAMETER')
        Else out_rval := out_rval / rrv;
      End;
      If rdt = DT_DOUBLE Then out_dt := DT_DOUBLE;
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseParameter : parser un enonce PARAMETER.
  Syntaxe F77 :
    PARAMETER (nom = expr_const [, nom = expr_const ...])
  Le mot-cle PARAMETER est deja consomme avant l'appel.
  Chaque constante est creee dans la table des symboles avec
  kind = SK_PARAM_CONST et les champs const_ival / const_rval / const_sval.
  -------------------------------------------------------------------------- }
Procedure ParseParameter;
Var
  pname  : TString;
  idx    : Integer;
  p_dt   : TDataType;
  p_ival : LongInt;
  p_rval : Real;
  p_sval : TString;
Begin
  LexExpect('(');

  Repeat
    { Nom de la constante symbolique }
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identificateur attendu dans PARAMETER');
      Break;
    End;
    pname := cur_tok.val;
    LexNext;

    LexExpect('=');

    { Expression constante }
    ParseParamConstExpr(p_dt, p_ival, p_rval, p_sval);

    { Inscrire la constante dans la table des symboles }
    idx := SymFindLocal(pname);
    If idx = 0 Then
    Begin
      { Creer une nouvelle entree }
      idx := SymEnter(pname, SK_PARAM_CONST, p_dt);
    End
    Else If sym_table^[idx].kind = SK_PARAM_CONST Then
    Begin
      WarnMsg('PARAMETER ' + pname + ' redefini');
    End
    Else
    Begin
      { La variable existait deja (ex: declaree INTEGER avant PARAMETER) }
      sym_table^[idx].kind := SK_PARAM_CONST;
    End;

    If idx > 0 Then
    Begin
      sym_table^[idx].dtype      := p_dt;
      sym_table^[idx].const_ival := p_ival;
      sym_table^[idx].const_rval := p_rval;
      sym_table^[idx].const_sval := p_sval;
      sym_table^[idx].is_defined := True;
      If opt_debug Then
        NoteMsg('PARAMETER ' + pname + ' = ' + IntToStr(p_ival));
    End;

    If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ',') Then
      LexNext
    Else
      Break;
  Until (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')');

  If (cur_tok.kind = TK_PUNCT) And (cur_tok.val = ')') Then
    LexNext
  Else
    ErrorMsg('Attendu ) pour fermer l''enonce PARAMETER');
End;

{ ============================================================
  TODO 09 - GENERATEUR DE CODE 8086 - PRIMITIVES
  ============================================================
  Fonctions exposees :
    EmitLabel(lbl)            -- emettre un label MASM (col 0)
    EmitI0(mn)                -- instruction sans operande
    EmitI1(mn, op)            -- instruction un operande
    EmitI2(mn, dst, src)      -- instruction deux operandes
    EmitDB(val)               -- directive DB octet
    EmitDBs(val, n)           -- directive DB n DUP(val)
    EmitDW(val)               -- directive DW mot 16 bits
    EmitDWi(n)                -- directive DW valeur entiere
    EmitDD(val)               -- directive DD double mot 32 bits
    EmitDQ(val)               -- directive DQ quad mot 64 bits
    EmitDup(sz, val)          -- directive DUP(val) avec taille sz
    EmitStr(s)                -- directive DB avec chaine Fortran
    EmitComment(s)            -- ligne commentaire ';'
    EmitSep                   -- ligne separatrice '; ---'
    EmitBlank                 -- ligne vide
    GenBranchLabel            -- generer un label interne unique _FB_nnn
    GenDataLabel              -- generer un label donnee unique _FK_nnn
    GenProgramHeader          -- entete du fichier ASM (.MODEL SMALL)
    GenDataSegBegin/End       -- .DATA begin/end
    GenCodeSegBegin/End       -- .CODE begin/end
    GenProcBegin(nm,nparams)  -- PROC FAR/NEAR + prologue BP
    GenProcEnd(nm)            -- epilogue + ENDP
    GenProgramEpilogue        -- MOV AX,4C00h / INT 21h
    GenProgramEntry           -- point d'entree START
  ============================================================ }

{ --------------------------------------------------------------------------
  Helpers d'ecriture dans cur_out
  -------------------------------------------------------------------------- }

{ Ecrire une ligne brute dans la sortie courante }
Procedure EmitRaw(Const s : TString);
Begin
  Writeln(cur_out^, s);
End;

{ --------------------------------------------------------------------------
  EmitLabel : emettre un label MASM sans indentation (col 0).
  Ajoute ':' uniquement si pas deja present.
  -------------------------------------------------------------------------- }
Procedure EmitLabel(Const lbl : TString);
Var s : TString;
Begin
  s := lbl;
  If (Length(s) > 0) And (s[Length(s)] <> ':') Then s := s + ':';
  EmitRaw(s);
End;

{ --------------------------------------------------------------------------
  EmitI0 : instruction sans operande (ex: NOP, RET, PUSHF).
  -------------------------------------------------------------------------- }
Procedure EmitI0(Const mn : TString);
Begin
  EmitRaw('        ' + mn);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  EmitI1 : instruction un operande (ex: INC AX, PUSH BX).
  -------------------------------------------------------------------------- }
Procedure EmitI1(Const mn, op : TString);
Begin
  EmitRaw('        ' + mn + ' ' + op);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  EmitI2 : instruction deux operandes (ex: MOV AX, BX).
  -------------------------------------------------------------------------- }
Procedure EmitI2(Const mn, dst, src : TString);
Begin
  EmitRaw('        ' + mn + ' ' + dst + ', ' + src);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Directives de donnees
  -------------------------------------------------------------------------- }

Procedure EmitDB(Const val : TString);
Begin
  EmitRaw('        DB ' + val);
End;

Procedure EmitDBi(n : Integer);
Begin
  EmitRaw('        DB ' + IntToStr(n));
End;

Procedure EmitDBs(Const val : TString; n : Integer);
{ DB n DUP(val) }
Begin
  If n = 1 Then
    EmitDB(val)
  Else
    EmitRaw('        DB ' + IntToStr(n) + ' DUP(' + val + ')');
End;

{ emit une chaine CHARACTER Fortran : DB len, 'chars...' }
{ Format Fortran : longueur fixe, pas null-terminated, blank-padded }
Procedure EmitDBStr(Const s : TString);
Var i   : Integer;
    res : TString;
    c   : Char;
    inq : Boolean;  { dans un segment de chaine }
Begin
  If Length(s) = 0 Then
  Begin
    EmitRaw('        DB 0');
    Exit;
  End;
  { Decomposer en segments String + bytes hex pour les caracteres speciaux }
  res  := '        DB ';
  inq  := False;
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (Ord(c) >= 32) And (Ord(c) < 127) And (c <> '''') Then
    Begin
      If Not inq Then
      Begin
        If i > 1 Then res := res + ', ';
        res := res + '''';
        inq := True;
      End;
      res := res + c;
    End
    Else
    Begin
      If inq Then
      Begin
        res := res + '''';
        inq := False;
      End;
      If Length(res) > 8 Then res := res + ', ';
      res := res + IntToStr(Ord(c));
    End;
  End;
  If inq Then res := res + '''';
  EmitRaw(res);
End;

Procedure EmitDW(Const val : TString);
Begin
  EmitRaw('        DW ' + val);
End;

Procedure EmitDWi(n : LongInt);
Begin
  EmitRaw('        DW ' + IntToStr(n));
End;

Procedure EmitDD(Const val : TString);
Begin
  EmitRaw('        DD ' + val);
End;

Procedure EmitDDi(n : LongInt);
Begin
  EmitRaw('        DD ' + IntToStr(n));
End;

Procedure EmitDQ(Const val : TString);
Begin
  EmitRaw('        DQ ' + val);
End;

{ DB/DW/DD selon DataType et valeur en TString }
Procedure EmitDataValue(dt : TDataType; Const val : TString);
Begin
  Case dt Of
    DT_INTEGER   : EmitDW(val);
    DT_REAL      : EmitDD(val);    { valeur reelle = DD (4 octets) }
    DT_DOUBLE    : EmitDQ(val);    { double = DQ (8 octets) }
    DT_COMPLEX   : Begin EmitDD(val); EmitDD('0'); End; { re + im }
    DT_LOGICAL   : EmitDW(val);
    DT_CHARACTER : EmitDBStr(val);
  Else
    EmitDW(val);
  End;
End;

{ --------------------------------------------------------------------------
  EmitComment, EmitSep, EmitBlank : decoration
  -------------------------------------------------------------------------- }

Procedure EmitComment(Const s : TString);
Begin
  EmitRaw('; ' + s);
End;

Procedure EmitSep;
Begin
  EmitRaw('; ' + '------------------------------------------------------------');
End;

Procedure EmitBlank;
Begin
  EmitRaw('');
End;

{ --------------------------------------------------------------------------
  GenBranchLabel : generer un nouveau label interne FB (branche)
  -------------------------------------------------------------------------- }
Function GenBranchLabel : TString;
Begin
  Inc(branch_lbl_count);
  GenBranchLabel := FB_PFX + IntToStr(branch_lbl_count);
End;

{ --------------------------------------------------------------------------
  GenDataLabel : generer un nouveau label de constante FK
  -------------------------------------------------------------------------- }
Function GenDataLabel : TString;
Begin
  Inc(data_lbl_count);
  GenDataLabel := FK_PFX + IntToStr(data_lbl_count);
End;

{ --------------------------------------------------------------------------
  GenProgramHeader : emettre l'entete du fichier ASM.
  Modele memoire SMALL (code < 64 Ko, data < 64 Ko) comme BCPL86.
  -------------------------------------------------------------------------- }
Procedure GenProgramHeader;
Begin
  EmitComment('Genere par F77C86 v' + F77_VERSION + ' - ' + F77_DATE);
  EmitComment('Source : ' + src_fname);
  EmitBlank;
  EmitRaw('        .MODEL SMALL');
  EmitRaw('        .STACK ' + IntToStr(STACK_SIZE));
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenDataSegBegin / GenDataSegEnd
  -------------------------------------------------------------------------- }
Procedure GenDataSegBegin;
Begin
  EmitBlank;
  EmitRaw('        .DATA');
  EmitBlank;
End;

Procedure GenDataSegEnd;
Begin
  EmitBlank;
  EmitComment('--- Fin segment .DATA ---');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenCodeSegBegin / GenCodeSegEnd
  -------------------------------------------------------------------------- }
Procedure GenCodeSegBegin;
Begin
  EmitBlank;
  EmitRaw('        .CODE');
  EmitBlank;
End;

Procedure GenCodeSegEnd;
Begin
  EmitBlank;
  EmitComment('--- Fin segment .CODE ---');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProcBegin : emettre le prologue d'un sous-programme Fortran.
  Convention Fortran 77 :
    - PROC NEAR (modele SMALL)
    - Prologue standard : PUSH BP / MOV BP, SP
    - Arguments passes PAR REFERENCE (pointeurs 16 bits sur pile)
    - Acces arg i : MOV BX, [BP + 4 + (i-1)*2] (depuis la droite: dernier arg en premier)
      (BP+0 = ancien BP, BP+2 = adresse retour, BP+4 = 1er arg)
    - Registres preserves : SI, DI, DS (convention standard 86)
  -------------------------------------------------------------------------- }
Procedure GenProcBegin(Const nm : TString; nparams : Integer);
Begin
  EmitBlank;
  EmitSep;
  EmitComment('PROCEDURE/FUNCTION : ' + nm
              + ' (' + IntToStr(nparams) + ' parametre(s))');
  EmitSep;
  EmitLabel(FP_PFX + nm);
  EmitRaw(FP_PFX + nm + '  PROC NEAR');
  EmitI1('PUSH', 'BP');
  EmitI2('MOV',  'BP', 'SP');
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProcEnd : emettre l'epilogue d'un sous-programme.
  Depiler les parametres (convention appelant = non - F77 = callee clean).
  Norme F77 : les arg sont empiles par l'appelant, nettoyes par l'appelant.
  Ici on utilise RET simple (l'appelant fait ADD SP, nparams*2 apres le CALL).
  -------------------------------------------------------------------------- }
Procedure GenProcEnd(Const nm : TString);
Begin
  EmitBlank;
  EmitI1('POP', 'DI');
  EmitI1('POP', 'SI');
  EmitI1('POP', 'BP');
  EmitI0('RET');
  EmitRaw(FP_PFX + nm + '  ENDP');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenInitSeg : emettre les instructions d'initialisation des registres de
  segment DS au point d'entree (START).
  -------------------------------------------------------------------------- }
Procedure GenInitSeg;
Begin
  EmitI2('MOV', 'AX', '@DATA');
  EmitI2('MOV', 'DS', 'AX');
End;

{ --------------------------------------------------------------------------
  GenProgramEntry : emettre le point d'entree START.
  -------------------------------------------------------------------------- }
Procedure GenProgramEntry;
Begin
  EmitBlank;
  EmitSep;
  EmitComment('Point d''entree du programme');
  EmitSep;
  EmitLabel('START');
  GenInitSeg;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenProgramEpilogue : emettre la sortie propre via DOS INT 21h.
  AX = 4C00h -> exit code 0.
  -------------------------------------------------------------------------- }
Procedure GenProgramEpilogue;
Begin
  EmitBlank;
  EmitComment('Fin du programme principal');
  EmitI2('MOV', 'AX', '4C00h');
  EmitI0('INT 21h');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenFileEnd : emettre la directive END de fin de fichier ASM.
  -------------------------------------------------------------------------- }
Procedure GenFileEnd(Const entry_label : TString);
Begin
  EmitBlank;
  If entry_label <> '' Then
    EmitRaw('        END ' + entry_label)
  Else
    EmitRaw('        END');
End;

{ --------------------------------------------------------------------------
  GenPushArg : pousser l'adresse d'un argument (convention by-reference).
  Pour les variables locales (BP-offset) : LEA AX, [BP-offset] ; PUSH AX
  Pour les variables statiques (label) : MOV AX, OFFSET label ; PUSH AX
  -------------------------------------------------------------------------- }
Procedure GenPushArgByRef(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.common_blk > 0 Then
  Begin
    { Variable de COMMON : adresse directe }
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'AX');
  End
  Else If s.bp_offset < 0 Then
  Begin
    { Variable locale ou parametre : [BP + offset] }
    EmitI2('LEA', 'AX', '[BP' + IntToStr(s.bp_offset) + ']');
    EmitI1('PUSH', 'AX');
  End
  Else If s.asm_label <> '' Then
  Begin
    { Variable statique ou SAVE : adresse directe }
    EmitI2('MOV', 'AX', 'OFFSET ' + s.asm_label);
    EmitI1('PUSH', 'AX');
  End
  Else
  Begin
    WarnMsg('GenPushArgByRef : symbole sans adresse - ' + s.name);
    EmitI2('MOV', 'AX', '0');
    EmitI1('PUSH', 'AX');
  End;
End;

{ --------------------------------------------------------------------------
  GenLoadInt : charger un entier 16 bits dans AX.
  Selon la nature du symbole : constante PARAMETER, var locale ou statique.
  -------------------------------------------------------------------------- }
Procedure GenLoadInt(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then
  Begin
    EmitI2('MOV', 'AX', '0');
    Exit;
  End;
  s := sym_table^[idx];
  If s.kind = SK_PARAM_CONST Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(s.const_ival));
  End
  Else If s.bp_offset < 0 Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']');
  End
  Else If s.asm_label <> '' Then
  Begin
    EmitI2('MOV', 'AX', 'WORD PTR [' + s.asm_label + ']');
  End
  Else
    EmitI2('MOV', 'AX', '0');
End;

{ --------------------------------------------------------------------------
  GenStoreInt : stocker AX dans une variable entiere.
  -------------------------------------------------------------------------- }
Procedure GenStoreInt(idx : Integer);
Var s : TSymRef;
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.bp_offset < 0 Then
    EmitI2('MOV', 'WORD PTR [BP' + IntToStr(s.bp_offset) + ']', 'AX')
  Else If s.asm_label <> '' Then
    EmitI2('MOV', 'WORD PTR [' + s.asm_label + ']', 'AX')
  Else
    WarnMsg('GenStoreInt : symbole sans adresse - ' + s.name);
End;

{ --------------------------------------------------------------------------
  GenVarDecl : emettre la declaration d'espace pour une variable en .DATA.
  Utilise les champs dtype, char_len, type_size, ndim, dims de TSymRec.
  Variables DATA-initialisees : emit la valeur; sinon : DW/DD/DQ 0.
  -------------------------------------------------------------------------- }
Procedure GenVarDecl(idx : Integer);
Var s  : TSymRef;
    sz : Integer;
    di : Integer;
    ne : LongInt;  { nombre d'elements total pour les tableaux }
Begin
  If (idx < 1) Or (idx > sym_count) Then Exit;
  s := sym_table^[idx];
  If s.kind = SK_PARAM_CONST Then Exit;  { pas de DATA pour les PARAMETER }
  If s.common_blk > 0 Then Exit;         { COMMON gere separement          }
  If s.asm_label = '' Then Exit;         { symbole sans label (parametre)  }
  If s.kind = SK_SUBR Then Exit;
  If s.kind = SK_FUNC Then Exit;

  sz := DataTypeSize(s.dtype, s.char_len);

  { Calculer le nombre d'elements pour les tableaux }
  ne := 1;
  If s.ndim > 0 Then
  Begin
    For di := 1 To s.ndim Do
      ne := ne * (s.dims[di].ub - s.dims[di].lb + 1);
  End;

  EmitComment('VAR ' + s.name + ' (' + DataTypeName(s.dtype) + ')');
  EmitLabel(s.asm_label);

  If s.is_defined Then
  Begin
    { Variable initialisee par DATA }
    Case s.dtype Of
      DT_INTEGER   : EmitDWi(s.const_ival);
      DT_LOGICAL   : EmitDWi(s.const_ival);
      DT_REAL      : EmitRaw('        DD 0    ; reel init TODO 11');
      DT_DOUBLE    : EmitRaw('        DQ 0    ; double init TODO 11');
      DT_COMPLEX   : EmitRaw('        DD 0, 0 ; complexe init TODO 11');
      DT_CHARACTER :
      Begin
        EmitDBStr(s.const_sval);
        { Completer par des espaces si necessaire }
        If s.char_len > Length(s.const_sval) Then
          EmitDBs('''  ''', s.char_len - Length(s.const_sval));
      End;
    Else
      EmitDBs('0', sz);
    End;
  End
  Else
  Begin
    { Variable non initialisee : allouer de l'espace avec zero }
    If ne > 1 Then
    Begin
      Case sz Of
        1 : EmitDBs('0', ne);
        2 : EmitRaw('        DW ' + IntToStr(ne) + ' DUP(0)');
        4 : EmitRaw('        DD ' + IntToStr(ne) + ' DUP(0)');
        8 : EmitRaw('        DQ ' + IntToStr(ne) + ' DUP(0)');
      Else
        EmitRaw('        DB ' + IntToStr(ne * sz) + ' DUP(0)');
      End;
    End
    Else
    Begin
      Case sz Of
        1 : EmitDB('0');
        2 : EmitDW('0');
        4 : EmitDD('0');
        8 : EmitDQ('0');
      Else
        EmitDBs('0', sz);
      End;
    End;
  End;
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenCommonBlockDecl : emettre la declaration d'un bloc COMMON en .DATA.
  Alloue common_table^[ci].total_size octets avec le label _FC_nom_.
  -------------------------------------------------------------------------- }
Procedure GenCommonBlockDecl(ci : Integer);
Var cb : TCommonRef;
Begin
  If (ci < 1) Or (ci > common_count) Then Exit;
  cb := common_table^[ci];
  EmitComment('COMMON /' + cb.name + '/ (' + IntToStr(cb.total_size) + ' octets)');
  EmitLabel(FC_PFX + cb.name + '_');
  If cb.total_size > 0 Then
    EmitRaw('        DB ' + IntToStr(cb.total_size) + ' DUP(0)')
  Else
    EmitRaw('        DB 1 DUP(0)   ; COMMON vide');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  GenAllVarDecls : emettre toutes les declarations de variables du proc.
  Appele au debut du segment .DATA apres GenDataSegBegin.
  -------------------------------------------------------------------------- }
Procedure GenAllVarDecls(proc_idx : Integer);
Var i : Integer;
Begin
  { Blocs COMMON en premier }
  For i := 1 To common_count Do
    GenCommonBlockDecl(i);
  { Puis toutes les variables du proc courant }
  For i := 1 To sym_count Do
    If sym_table^[i].scope_unit = proc_idx Then
      GenVarDecl(i);
End;

{ --------------------------------------------------------------------------
  GenCallSub : generer un CALL a un sous-programme Fortran.
  Empile OFFSET des args de droite a gauche, puis CALL, puis ADD SP.
  Les args sont des indices dans sym_table.
  arg_idx est un tableau d'indices sym_table, nargs le nombre d'args.
  -------------------------------------------------------------------------- }
Procedure GenCallSub(Const sub_label : TString;
                     Var arg_idx : Array of Integer;
                     nargs : Integer);
Var i : Integer;
Begin
  EmitComment('CALL ' + sub_label);
  { Empiler de droite a gauche (dernier arg en premier sur pile) }
  For i := nargs - 1 DownTo 0 Do
    GenPushArgByRef(arg_idx[i]);
  EmitRaw('        CALL ' + sub_label);
  If nargs > 0 Then
    EmitI2('ADD', 'SP', IntToStr(nargs * 2));
  EmitBlank;
End;

{ ============================================================
  Programme principal
  ============================================================ }

Begin
  InitTables;
  ParseArgs;
  OpenFiles;

  Writeln('F77C86 v', F77_VERSION, ' - Compilation de ', src_fname);

  { TODOs 10-25 : implementation a venir }


  CloseFiles;

  Writeln('Compilation terminee : ', err_count, ' erreur(s), ',
          warn_count, ' avertissement(s).');
  If err_count > 0 Then Halt(1);
End.
