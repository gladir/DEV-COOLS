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
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;
  str_lit_count: Integer;
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
  err_count    := 0;
  warn_count   := 0;
  instr_count  := 0;
  str_lit_count:= 0;
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
  Programme principal
  ============================================================ }

Begin
  InitTables;
  ParseArgs;
  OpenFiles;

  Writeln('F77C86 v', F77_VERSION, ' - Compilation de ', src_fname);

  { TODOs 04-25 : implementation a venir }

  CloseFiles;

  Writeln('Compilation terminee : ', err_count, ' erreur(s), ',
          warn_count, ' avertissement(s).');
  If err_count > 0 Then Halt(1);
End.
