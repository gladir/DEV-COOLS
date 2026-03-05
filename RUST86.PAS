{ @author: Sylvain Maltais
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Compilateur Rust vers assembleur 8086
}

(*
  ============================================================
  PLAN DE DEVELOPPEMENT - 25 TODOS
  ============================================================

  TODO 01 - INFRASTRUCTURE GENERALE
            Definir les constantes de dimensionnement (MAX_SYM, MAX_PROC,
            MAX_LABEL, MAX_SCOPE, MAX_ERRORS, MAX_STR, etc.) et les
            types fondamentaux TString/TToken; etablir la structure
            du programme principal (ParseArgs, Run, Cleanup).

  TODO 02 - LEXER : TOKENS DE BASE
            Implanter le scanner de caracteres (ouverture fichier,
            buffer ligne, gestion lignes/colonnes, AvanceChar,
            PeekChar). Reconnaitre les identifiants, les entiers
            decimaux/hexadecimaux (0x...) et les caracteres de
            ponctuation simples.

  TODO 03 - LEXER : LITTERAUX CHAINES ET CARACTERES
            Gerer les litteraux '' (char) et "" (str), les
            sequences d'echappement (\n \t \r \\ \0 \uXXXX),
            les raw strings r#"..."# et les byte literals b'X'.

  TODO 04 - LEXER : OPERATEURS ET MOTS-CLES RUST
            Reconnaitre tous les operateurs Rust (-> :: .. ..=
            => && || != >= <= ** << >> &= |= ^= += -= *= /= %=
            <<=  >>= etc.) et la liste complete des mots-cles
            reserves (fn, let, mut, if, else, match, loop, while,
            for, in, return, struct, enum, impl, trait, use, mod,
            pub, self, Self, super, crate, const, static, type,
            where, unsafe, extern, as, ref, break, continue, dyn).

  TODO 05 - TABLE DES SYMBOLES
            Creer la table des symboles (identifiant, categorie,
            type, portee, offset BP / adresse statique, mutabilite,
            flag reference). Implanter Add/Find/EnterScope/
            LeaveScope avec pile de portees imbriquees.

  TODO 06 - SYSTEME DE TYPES PRIMITIFS
            Modeliser les types scalaires Rust cibles 8086 :
            i8, u8 (1 octet), i16, u16, isize, usize (2 octets),
            i32, u32 (4 octets - paire de registres), bool (1 octet),
            char (4 octets Unicode tronque a u8 sur 8086), () (unit).
            Calculer sizeof et alignement pour chaque type.

  TODO 07 - TYPES COMPOSES : TUPLES ET TABLEAUX
            Gerer les types tuple (T1, T2, ...) et les tableaux
            de taille fixe [T; N]. Calculer l'offset de chaque
            element dans la disposition memoire et generer les
            acces par indice en assembleur 8086.

  TODO 08 - TYPES COMPOSES : STRUCT
            Analyser les declarations struct (struct Nom { champ:
            Type, ... }). Construire la table des champs avec
            offsets 8086 alignes. Gerer les struct tuple
            (struct Foo(T1, T2)) et les struct unites (struct Foo;).

  TODO 09 - TYPES COMPOSES : ENUM
            Analyser les declarations enum (enum Nom { Var1,
            Var2(T), Var3 { champ: T }, ... }). Encoder le
            discriminant (tag 8 bits) suivi des donnees de la
            variante. Etablir la representation memoire 8086
            (taille = tag + max_payload).

  TODO 10 - TRAITS ET IMPL (SANS DYNAMIC DISPATCH)
            Analyser les blocs impl Type { fn ... } et impl Trait
            for Type { fn ... }. Stocker les methodes dans la table
            des symboles avec mungling de nom (_IMPL_Type_fn).
            Exclure le dynamic dispatch (dyn Trait) de la
            cible 8086/TP7 (erreur explicite si rencontre).

  TODO 11 - REFERENCES ET EMPRUNTS (BORROW SIMPLIFIE)
            Modeliser &T et &mut T comme pointeurs 16 bits (offset
            ou segment:offset en mode far optionnel). Implanter la
            verification statique de base : une seule reference
            mutable active par variable. Signaler les violations
            comme erreur de compilation sans implementer la duree
            de vie complete.

  TODO 12 - DUREES DE VIE (LIFETIME ELISION UNIQUEMENT)
            Accepter les annotations de duree de vie ('a) en
            syntaxe sans les verifier au-dela de l'elision
            standard (une seule reference en entree -> meme
            lifetime en sortie). Emettre un avertissement pour
            les lifetimes explicites complexes non verifies.

  TODO 13 - EXPRESSIONS : ARITHMETIQUE ET LOGIQUE
            Implanter le parseur d'expressions par precedence
            (Pratt ou recursif descendant). Couvrir : +, -, *,
            /, %, &, |, ^, !, <<, >>, &&, ||, ==, !=, <, >,
            <=, >= , as (cast), unaire -, !, *deref, &borrow.
            Generer le code 8086 correspondant (ADD, SUB, IMUL,
            IDIV, AND, OR, XOR, SHL, SHR, NEG, NOT, CMP + Jcc).

  TODO 14 - EXPRESSIONS : APPELS DE FONCTIONS ET METHODES
            Gerer les appels fn(args), objet.methode(args) et
            Trait::fn(args). Implanter la convention d'appel
            cdecl 8086 : arguments empiles droite a gauche,
            retour dans AX (8/16 bits) ou DX:AX (32 bits),
            nettoyage par l'appelant.

  TODO 15 - INSTRUCTIONS : LET, AFFECTATION, BLOCS
            Analyser let [mut] motif [: Type] [= expr];.
            Allouer l'espace sur la pile (SUB SP, n). Generer
            les affectations simples et les affectations
            composees (+=, -= etc.). Gerer les blocs { ... }
            comme expressions retournant une valeur.

  TODO 16 - INSTRUCTIONS : IF / ELSE / IF LET
            Analyser if cond { } [else { }] et la forme if let
            Motif = expr { }. Generer les sauts conditionnels
            8086 avec labels locaux _L_THEN_N / _L_ELSE_N /
            _L_ENDIF_N. Gerer if comme expression (les deux
            branches doivent produire le meme type).

  TODO 17 - INSTRUCTIONS : BOUCLES (loop, while, for..in)
            Analyser loop { }, while cond { } et for var in
            expr { } (iterateurs simples : intervalles a..b
            et a..=b sur entiers). Generer les labels de boucle
            _L_LOOP_N / _L_BREAK_N et les instructions break /
            continue avec support des labels de boucle (break
            'label).

  TODO 18 - PATTERN MATCHING (match)
            Analyser match expr { motif => expr, ... }.
            Supporter les motifs : litteral, _, variable,
            tuple, struct, enum incluant les gardes (if cond).
            Generer une chaine de tests 8086 (CMP + Jcc) pour
            les discriminants enum et les litteraux entiers.

  TODO 19 - CLOSURES (FORME SIMPLIFIEE)
            Analyser la syntaxe |params| expr et |params| {
            bloc }. Traiter les closures non-capturantes comme
            des fonctions anonymes emises directement. Emettre
            une erreur explicite pour la capture de variables
            (Fn / FnMut / FnOnce) non implantee sur cible 8086.

  TODO 20 - GESTION MEMOIRE : PILE ET CADRE DE PILE
            Generer le prologue 8086 (PUSH BP / MOV BP,SP /
            SUB SP,N) et l'epilogue (MOV SP,BP / POP BP / RET).
            Calculer N (taille totale des variables locales) en
            fin d'analyse de la fonction. Respecter l'alignement
            8086 sur 2 octets.

  TODO 21 - SEGMENT DE DONNEES : STATICS ET CONSTS
            Emettre les declarations static et const Rust dans
            le segment .DATA de l'assembleur 8086. Gerer les
            chaines litterales (tableau d'octets termine par 0
            ou avec longueur prepend selon le contexte). Attribuer
            des etiquettes prefixees _RS_ (Rust Static).

  TODO 22 - MODULES ET USE
            Analyser les declarations mod nom { ... } et
            use chemin::nom [as alias]. Implanter une resolution
            de noms par chaine de modules imbriquee. Traduire
            les chemins absolus vers les etiquettes assembleur
            par mungling : _MOD_sousmod_fn.

  TODO 23 - BLOCS UNSAFE ET POINTEURS BRUTS
            Reconnaitre unsafe { } et les types *const T / *mut T.
            Dans un bloc unsafe, autoriser la deref de pointeur
            brut (MOV reg,[adr]) et l'appel de fonctions externse
            (extern "C" fn). Hors unsafe, interdire ces operations
            et emettre une erreur de compilation.

  TODO 24 - RUNTIME MINIMAL ET PANIC
            Emettre les routines runtime en assembleur 8086 :
            _RS_PANIC (affiche message + INT 20h), _RS_MEMSET,
            _RS_MEMCPY, _RS_ITOA (formatage entier), _RS_PRINT
            (appel DOS INT 21h AH=40h). Generer l'appel a
            _RS_PANIC pour les cas unreachable!() et les debordements
            verifies (debug_assert).

  TODO 25 - GENERATION FINALE ET FICHIER .ASM
            Assembler les segments produits (en-tete .MODEL SMALL,
            .STACK, .DATA, .CODE) dans le fichier de sortie .ASM.
            Emettre les directives EXTRN et PUBLIC adequats pour
            chaque symbole. Implanter les options de ligne de
            commande (fichier source, fichier sortie, -v verbose,
            -d debug tokens, --edition 2021 etc.) et afficher les
            statistiques de compilation (lignes, symboles, erreurs).

  ============================================================
*)

Program RUST86;

{$I-}   { Desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  TODO 01 - INFRASTRUCTURE GENERALE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  RUST86_VERSION = '1.0';
  RUST86_DATE    = '2026-03-04';

  MAX_SYM    = {$IFDEF FPC}2048{$ELSE}256{$ENDIF};   { entrees table des symboles             }
  MAX_PROC   = {$IFDEF FPC}256{$ELSE}64{$ENDIF};     { fonctions fn                           }
  MAX_PARAM  = {$IFDEF FPC}32{$ELSE}16{$ENDIF};      { parametres par fonction                }
  MAX_FIELD  = 64;    { champs par struct/enum                     }
  MAX_CONST  = 512;   { constantes (const / static immuable)       }
  MAX_TYPE   = 64;    { descripteurs de type                       }
  MAX_LABEL  = 2048;  { labels internes (if/loop/match/break...)   }
  MAX_SCOPE  = 64;    { profondeur maximale de portee              }
  MAX_ERRORS = 30;    { arret apres N erreurs                      }
  MAX_STR    = {$IFDEF FPC}255{$ELSE}127{$ENDIF};    { longueur maximale d'une TString        }
  MAX_IMPORT = 32;    { fichiers mod / use inclus                  }
  MAX_SWITCH = 256;   { branches par match                         }
  MAX_MANGLE = 128;   { longueur maximale d'un nom mangle          }
  STACK_SIZE = 1024;  { taille segment pile en octets              }

  { Prefixes des etiquettes assembleur 8086 }
  RS_VAR_PFX  = '_RSV_';   { variables statiques / statics (.DATA)    }
  RS_FN_PFX   = '_RSF_';   { fonctions Rust                            }
  RS_IMPL_PFX = '_IMP_';   { methodes impl Type::fn                    }
  RS_LABEL_PFX= '_RSL_';   { etiquettes de controle (if/loop/match)   }
  RS_STR_PFX  = '_RSK_';   { constantes de chaines litterales          }
  RS_RT_PFX   = '_RSRT_';  { routines runtime (panic, print, memcpy)   }

  { Codes de sortie du programme }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Categories de tokens ---- }
  TTokenKind = (
    TK_IDENT,     { identificateur / mot-cle                      }
    TK_INTEGER,   { litteral entier : 42  0xFF  0b1010  0o17      }
    TK_FLOAT,     { litteral flottant : 3.14  1e10                }
    TK_CHAR,      { litteral caractere : 'A'  '\n'                }
    TK_STRING,    { litteral chaine : "hello"  r#"raw"#           }
    TK_BYTE,      { byte literal : b'A'                           }
    TK_OP,        { operateur simple ou compose (+ += -> :: ...)   }
    TK_PUNCT,     { ponctuation : ; , . ( ) [ ] < > @ # _ $      }
    TK_LIFETIME,  { lifetime annotation : 'a  'static             }
    TK_EOF        { fin de fichier source                          }
  );

  { ---- Enregistrement d'un token ---- }
  TToken = Record
    Kind     : TTokenKind;
    Val      : TString;       { representation brute du token      }
    IntVal   : LongInt;       { si TK_INTEGER ou TK_CHAR (codepoint) }
    FloatVal : Real;          { si TK_FLOAT                        }
    Line     : Integer;       { ligne dans le source (1-base)      }
    Col      : Integer;       { colonne dans le source (1-base)    }
  End;

  { ---- Options de la ligne de commande ---- }
  TOptions = Record
    SrcFile    : TString;     { fichier source .rs                 }
    OutFile    : TString;     { fichier sortie .asm (defaut: src.asm) }
    Verbose    : Boolean;     { -v : messages detailles            }
    DebugTok   : Boolean;     { -d : afficher chaque token         }
    Edition    : Integer;     { --edition : 2015/2018/2021 (defaut 2021) }
    NoOptim    : Boolean;     { --no-opt : desactiver optimisations }
  End;

{ --- Variables globales du compilateur --- }
Var
  Opts       : TOptions;
  ErrorCount : Integer;      { nombre d'erreurs rencontrees        }
  WarnCount  : Integer;      { nombre d'avertissements             }
  TotalLines : LongInt;      { lignes sources analysees            }
  TotalSyms  : Integer;      { symboles enregistres                }

{ --- Variables globales du lexer (TODO 02) --- }
Var
  LexSrcF   : Text;          { fichier source ouvert              }
  LexLine   : String;        { ligne courante                     }
  LexLineNo : Integer;       { numero de ligne (1-base)           }
  LexColNo  : Integer;       { colonne courante dans LexLine      }
  LexEOF    : Boolean;       { vrai si fin de fichier atteinte    }
  LexOpened : Boolean;       { vrai si LexSrcF est ouvert         }
  CurToken  : TToken;        { token courant                      }

{ ============================================================
  Procedure : Erreur fatale
  ============================================================ }
Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('RUST86: Erreur fatale: ', Msg);
  Halt(EXIT_ERROR);
End;

{ ============================================================
  Procedure : Afficher aide et quitter
  ============================================================ }
Procedure ShowHelp;
Begin
  WriteLn('RUST86 v', RUST86_VERSION, ' (', RUST86_DATE, ')');
  WriteLn('Compilateur Rust vers assembleur 8086');
  WriteLn;
  WriteLn('Usage: RUST86 <source.rs> [<sortie.asm>] [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  -v              Mode verbeux (messages detailles)');
  WriteLn('  -d              Debug tokens (affiche chaque token analyse)');
  WriteLn('  --edition N     Edition Rust cible : 2015, 2018 ou 2021 (defaut: 2021)');
  WriteLn('  --no-opt        Desactiver les optimisations peephole');
  WriteLn('  -h, --help      Afficher cette aide');
  WriteLn;
  WriteLn('Exemples:');
  WriteLn('  RUST86 hello.rs');
  WriteLn('  RUST86 hello.rs hello.asm -v');
  WriteLn('  RUST86 main.rs main.asm --edition 2018');
  Halt(EXIT_OK);
End;

{ ============================================================
  Procedure : Initialiser les options par defaut
  ============================================================ }
Procedure InitOptions;
Begin
  Opts.SrcFile  := '';
  Opts.OutFile  := '';
  Opts.Verbose  := False;
  Opts.DebugTok := False;
  Opts.Edition  := 2021;
  Opts.NoOptim  := False;
End;

{ ============================================================
  Procedure : Construire le nom de sortie par defaut
             Remplace l'extension .rs par .asm
  ============================================================ }
Procedure BuildOutName;
Var
  I   : Integer;
  Base: TString;
Begin
  Base := Opts.SrcFile;
  { Chercher le dernier point dans le nom }
  I := Length(Base);
  While (I > 0) And (Base[I] <> '.') Do Dec(I);
  If I > 1 Then
    Opts.OutFile := Copy(Base, 1, I - 1) + '.asm'
  Else
    Opts.OutFile := Base + '.asm';
End;

{ ============================================================
  Procedure : Analyser les arguments de la ligne de commande
  ============================================================ }
Procedure ParseArgs;
Var
  I   : Integer;
  Arg : TString;
Begin
  If ParamCount = 0 Then ShowHelp;
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugTok := True
    Else If Arg = '--no-opt' Then
      Opts.NoOptim := True
    Else If Arg = '--edition' Then
    Begin
      Inc(I);
      If I > ParamCount Then FatalError('--edition attend un argument (2015/2018/2021)');
      Arg := ParamStr(I);
      If Arg = '2015' Then Opts.Edition := 2015
      Else If Arg = '2018' Then Opts.Edition := 2018
      Else If Arg = '2021' Then Opts.Edition := 2021
      Else FatalError('Edition inconnue: ' + Arg + ' (valeurs: 2015 2018 2021)');
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else If Opts.SrcFile = '' Then
      Opts.SrcFile := Arg
    Else If Opts.OutFile = '' Then
      Opts.OutFile := Arg
    Else
      FatalError('Argument inattendu: ' + Arg);
    Inc(I);
  End;
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('RUST86: Erreur - aucun fichier source specifie.');
    WriteLn('Utilisez RUST86 --help pour l''aide.');
    Halt(EXIT_USAGE);
  End;
  If Opts.OutFile = '' Then BuildOutName;
End;

{ ============================================================
  Procedure : Afficher le banneau de demarrage
  ============================================================ }
Procedure ShowBanner;
Begin
  If Opts.Verbose Then
  Begin
    WriteLn('RUST86 v', RUST86_VERSION, ' - Compilateur Rust -> 8086');
    WriteLn('Source  : ', Opts.SrcFile);
    WriteLn('Sortie  : ', Opts.OutFile);
    WriteLn('Edition : ', Opts.Edition);
    WriteLn;
  End;
End;

{ ============================================================
  Procedure : Afficher les statistiques de compilation
  ============================================================ }
Procedure ShowStats;
Begin
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Symboles         : ', TotalSyms);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
  If ErrorCount = 0 Then
    WriteLn('Compilation reussie -> ', Opts.OutFile)
  Else
    WriteLn('Compilation echouee (', ErrorCount, ' erreur(s))');
End;

{ ============================================================
  TODO 02 - LEXER : TOKENS DE BASE
  ============================================================ }

{ ============================================================
  Fonction : LexCurChar - caractere a la position courante
  ============================================================ }
Function LexCurChar : Char;
Begin
  If (LexColNo >= 1) And (LexColNo <= Length(LexLine)) Then
    LexCurChar := LexLine[LexColNo]
  Else
    LexCurChar := #0;
End;

{ ============================================================
  Procedure : LexAdvance - avancer d'un caractere
  ============================================================ }
Procedure LexAdvance;
Begin
  Inc(LexColNo);
End;

{ ============================================================
  Fonction : LexPeek - regarder le caractere suivant sans avancer
  ============================================================ }
Function LexPeek : Char;
Begin
  If LexColNo + 1 <= Length(LexLine) Then
    LexPeek := LexLine[LexColNo + 1]
  Else
    LexPeek := #0;
End;

{ ============================================================
  Procedure : LexNextLine - lire la prochaine ligne du fichier
  ============================================================ }
Procedure LexNextLine;
Begin
  If EOF(LexSrcF) Then
  Begin
    LexEOF  := True;
    LexLine := '';
    LexColNo := 1;
  End Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

{ ============================================================
  Procedure : LexError - erreur lexicale (non fatale)
  ============================================================ }
Procedure LexError(Const Msg : TString);
Begin
  WriteLn('RUST86:', LexLineNo, ':', LexColNo, ': Erreur: ', Msg);
  Inc(ErrorCount);
  If ErrorCount >= MAX_ERRORS Then
    FatalError('Trop d''erreurs - compilation abandonnee');
End;

{ ============================================================
  Procedure : MakeToken - initialiser un TToken
  ============================================================ }
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

{ ============================================================
  Procedure : LexSkipLineComment - ignorer commentaire // ...
  ============================================================ }
Procedure LexSkipLineComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ============================================================
  Procedure : LexSkipBlockComment - ignorer commentaire /* ... */
             Rust supporte les commentaires blocs imbriques.
  ============================================================ }
Procedure LexSkipBlockComment;
Var
  Depth : Integer;
  C     : Char;
Begin
  Depth := 1;
  While (Not LexEOF) And (Depth > 0) Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexNextLine;
      Continue;
    End;
    C := LexCurChar;
    LexAdvance;
    If C = '/' Then
    Begin
      If LexCurChar = '*' Then
      Begin
        LexAdvance;
        Inc(Depth);
      End;
    End Else If C = '*' Then
    Begin
      If LexCurChar = '/' Then
      Begin
        LexAdvance;
        Dec(Depth);
      End;
    End;
  End;
  If Depth > 0 Then
    LexError('Commentaire bloc non ferme en fin de fichier');
End;

{ ============================================================
  Procedure : LexSkipWS - ignorer espaces et commentaires
  ============================================================ }
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
    Else If (C = '/') And (LexPeek = '/') Then
      LexSkipLineComment
    Else If (C = '/') And (LexPeek = '*') Then
    Begin
      LexAdvance;  { consommer '/' }
      LexAdvance;  { consommer '*' }
      LexSkipBlockComment;
    End Else
      Exit;
  Until False;
End;

{ ============================================================
  Fonctions utilitaires sur les caracteres
  ============================================================ }
Function IsAlpha(C : Char) : Boolean;
Begin
  IsAlpha := ((C >= 'a') And (C <= 'z')) Or
             ((C >= 'A') And (C <= 'Z')) Or
             (C = '_');
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

{ ============================================================
  Procedure : LexScanIdent - lire un identifiant ou mot-cle
  ============================================================ }
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
  MakeToken(T, TK_IDENT, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanNumber - lire un litteral entier
             Bases supportees : decimal, 0x hex, 0b binaire, 0o octal
             Les underscores de lisibilite sont ignores.
             Le suffixe de type (u8, i32, usize...) est stocke
             dans Val mais non interprete (reserve pour TODO 06).
  ============================================================ }
Procedure LexScanNumber(Var T : TToken; SL, SC : Integer);
Var
  S     : TString;
  Val   : LongInt;
  Base  : Integer;
  C     : Char;
  Fv    : Real;     { partie flottante                      }
  Div10 : Real;     { diviseur de position decimale         }
Begin
  S    := '';
  Val  := 0;
  Base := 10;
  C    := LexCurChar;

  { Detecter le prefixe de base }
  If (C = '0') And (LexPeek <> #0) Then
  Begin
    Case LexPeek Of
      'x','X': Begin
        S := '0x'; LexAdvance; LexAdvance;
        Base := 16;
      End;
      'b','B': Begin
        S := '0b'; LexAdvance; LexAdvance;
        Base := 2;
      End;
      'o','O': Begin
        S := '0o'; LexAdvance; LexAdvance;
        Base := 8;
      End;
    Else
      Val := 0; S := '0'; LexAdvance;
    End;
  End Else
  Begin
    Val := Ord(C) - Ord('0');
    S   := C;
    LexAdvance;
  End;

  { Lire les chiffres selon la base, underscores ignores }
  While (Not LexEOF) And (LexColNo <= Length(LexLine)) Do
  Begin
    C := LexCurChar;
    If C = '_' Then Begin LexAdvance; Continue; End;
    Case Base Of
      2  : If (C = '0') Or (C = '1') Then
           Begin
             Val := Val * 2 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      8  : If (C >= '0') And (C <= '7') Then
           Begin
             Val := Val * 8 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      10 : If IsDigit(C) Then
           Begin
             Val := Val * 10 + (Ord(C) - Ord('0'));
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
      16 : If IsHexDigit(C) Then
           Begin
             Val := Val * 16 + HexVal(C);
             If Length(S) < MAX_STR Then S := S + C;
             LexAdvance;
           End Else Break;
    End;
  End;

  { Suffixe de type optionnel : u8 i8 u16 i16 u32 i32 usize isize }
  If (Not LexEOF) And (LexColNo <= Length(LexLine)) Then
  Begin
    C := LexCurChar;
    If (C = 'u') Or (C = 'i') Then
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
  End;

  { ---- Detection flottant (base decimale uniquement) ---- }
  If (Base = 10) And (Not LexEOF) And (LexColNo <= Length(LexLine)) And
     (LexCurChar = '.') And (LexPeek <> '.') And IsDigit(LexPeek) Then
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
    { Exposant optionnel e/E }
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
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsDigit(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    End;
    { Suffixe f32 / f64 }
    If (Not LexEOF) And (LexColNo <= Length(LexLine)) And
       (LexCurChar = 'f') Then
      While (Not LexEOF) And (LexColNo <= Length(LexLine)) And
            IsAlNum(LexCurChar) Do
      Begin
        If Length(S) < MAX_STR Then S := S + LexCurChar;
        LexAdvance;
      End;
    MakeToken(T, TK_FLOAT, S, SL, SC);
    T.FloatVal := Fv;
    Exit;
  End;
  MakeToken(T, TK_INTEGER, S, SL, SC);
  T.IntVal := Val;
End;

{ ============================================================
  TODO 03 - LEXER : LITTERAUX CHAINES ET CARACTERES
  ============================================================ }

{ ============================================================
  Fonction : LexScanEscape - decoder une sequence d'echappement
             Appelee apres consommation du backslash.
             Retourne le caractere; IntOut = valeur numerique.
  ============================================================ }
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
    'n'  : Begin LexScanEscape := #10;  IntOut := 10; End;
    't'  : Begin LexScanEscape := #9;   IntOut := 9;  End;
    'r'  : Begin LexScanEscape := #13;  IntOut := 13; End;
    '0'  : Begin LexScanEscape := #0;   IntOut := 0;  End;
    #34  : Begin LexScanEscape := #34;  IntOut := 34; End;
    '''' : Begin LexScanEscape := ''''; IntOut := 39; End;
    #92  : Begin LexScanEscape := #92;  IntOut := 92; End;
    'x'  : Begin
             { \xNN - deux chiffres hexadecimaux 00..FF }
             Code := 0;
             For I := 1 To 2 Do
             Begin
               If (LexColNo > Length(LexLine)) Or
                  (Not IsHexDigit(LexCurChar)) Then
               Begin
                 LexError('x: 2 chiffres hexa attendus');
                 Break;
               End;
               Code := Code * 16 + HexVal(LexCurChar);
               LexAdvance;
             End;
             IntOut := Code;
             LexScanEscape := Chr(Code And $FF);
           End;
    'u'  : Begin
             { sequence u Unicode, tronque a 8 bits sur 8086 }
             Code := 0;
             If (LexColNo <= Length(LexLine)) And (LexCurChar = '{') Then
               LexAdvance
             Else
               LexError('u: accolade ouvrante attendue');
             While (LexColNo <= Length(LexLine)) And
                   (LexCurChar <> '}') Do
             Begin
               If IsHexDigit(LexCurChar) Then
                 Code := Code * 16 + HexVal(LexCurChar)
               Else
               Begin
                 LexError('Chiffre hexa attendu dans sequence unicode');
                 Break;
               End;
               LexAdvance;
             End;
             If (LexColNo <= Length(LexLine)) And (LexCurChar = '}') Then
               LexAdvance
             Else
               LexError('u: accolade fermante manquante');
             IntOut := Code;
             LexScanEscape := Chr(Code And $FF);
           End;
  Else
    LexError('Sequence d''echappement inconnue');
    LexScanEscape := C;
    IntOut := Ord(C);
  End;
End;

{ ============================================================
  Procedure : LexScanCharLit - lire un litteral caractere 'X'
  ============================================================ }
Procedure LexScanCharLit(Var T : TToken; SL, SC : Integer);
Var
  C  : Char;
  IV : LongInt;
Begin
  LexAdvance; { consommer guillemet-simple ouverture }
  IV := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Litteral caractere non ferme');
    MakeToken(T, TK_CHAR, '''?''', SL, SC);
    Exit;
  End;
  C := LexCurChar;
  If Ord(C) = 92 Then  { backslash }
  Begin
    LexAdvance;
    C := LexScanEscape(IV);
  End Else
  Begin
    IV := Ord(C);
    LexAdvance;
  End;
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '''') Then
    LexAdvance
  Else
    LexError('Guillemet-simple fermant manquant dans litteral caractere');
  MakeToken(T, TK_CHAR, '''' + C + '''', SL, SC);
  T.IntVal := IV;
End;

{ ============================================================
  Procedure : LexScanStrLit - lire un litteral chaine "..."
  ============================================================ }
Procedure LexScanStrLit(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  Done : Boolean;
Begin
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Chaine non fermee en fin de ligne');
      Done := True;
    End Else If Ord(LexCurChar) = 34 Then  { guillemet-double fermant }
    Begin
      LexAdvance;
      Done := True;
    End Else If Ord(LexCurChar) = 92 Then  { backslash }
    Begin
      LexAdvance;
      C := LexScanEscape(IV);
      If Length(S) < MAX_STR Then S := S + C;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If Length(S) < MAX_STR Then S := S + C;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanRawStr - lire une raw string r"..." ou r#"..."#
             Le nombre de # doit correspondre en ouverture et fermeture.
             Les raw strings peuvent couvrir plusieurs lignes.
  ============================================================ }
Procedure LexScanRawStr(Var T : TToken; SL, SC : Integer);
Var
  S      : TString;
  Hashes : Integer;
  K      : Integer;
  C      : Char;
  Done   : Boolean;
Begin
  LexAdvance; { consommer 'r' }
  Hashes := 0;
  While (LexColNo <= Length(LexLine)) And (LexCurChar = '#') Do
  Begin
    Inc(Hashes);
    LexAdvance;
  End;
  If (LexColNo > Length(LexLine)) Or (Ord(LexCurChar) <> 34) Then
  Begin
    LexError('Raw string: guillemet-double attendu');
    MakeToken(T, TK_STRING, '', SL, SC);
    Exit;
  End;
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      { Raw strings Rust peuvent s''etendre sur plusieurs lignes }
      If Length(S) < MAX_STR Then S := S + #10;
      LexNextLine;
      If LexEOF Then
      Begin
        LexError('Raw string non fermee en fin de fichier');
        Done := True;
      End;
    End Else
    Begin
      C := LexCurChar;
      If Ord(C) <> 34 Then
      Begin
        LexAdvance;
        If Length(S) < MAX_STR Then S := S + C;
      End Else
      Begin
        LexAdvance; { consommer guillemet-double potentiel de fermeture }
        K := 0;
        While (K < Hashes) And (LexColNo <= Length(LexLine)) And
              (LexCurChar = '#') Do
        Begin
          Inc(K);
          LexAdvance;
        End;
        If K = Hashes Then
          Done := True
        Else
        Begin
          { Pas la vraie fermeture - reintegrer les chars lus }
          If Length(S) < MAX_STR Then S := S + #34;
          While K > 0 Do
          Begin
            If Length(S) < MAX_STR Then S := S + '#';
            Dec(K);
          End;
        End;
      End;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanByteLit - lire un byte literal b'X'
  ============================================================ }
Procedure LexScanByteLit(Var T : TToken; SL, SC : Integer);
Var
  C  : Char;
  IV : LongInt;
Begin
  LexAdvance; { consommer 'b' }
  LexAdvance; { consommer guillemet-simple ouverture }
  IV := 0;
  If LexColNo > Length(LexLine) Then
  Begin
    LexError('Byte literal non ferme');
    MakeToken(T, TK_BYTE, 'b?', SL, SC);
    Exit;
  End;
  C := LexCurChar;
  If Ord(C) = 92 Then  { backslash }
  Begin
    LexAdvance;
    C := LexScanEscape(IV);
  End Else
  Begin
    IV := Ord(C) And $FF;
    LexAdvance;
  End;
  If (LexColNo <= Length(LexLine)) And (LexCurChar = '''') Then
    LexAdvance
  Else
    LexError('Guillemet-simple fermant manquant dans byte literal');
  MakeToken(T, TK_BYTE, 'b' + '''' + C + '''', SL, SC);
  T.IntVal := IV And $FF;
End;

{ ============================================================
  Procedure : LexScanByteStr - lire une byte string b"..."
  ============================================================ }
Procedure LexScanByteStr(Var T : TToken; SL, SC : Integer);
Var
  S    : TString;
  C    : Char;
  IV   : LongInt;
  Done : Boolean;
Begin
  LexAdvance; { consommer 'b' }
  LexAdvance; { consommer guillemet-double ouverture }
  S    := '';
  Done := False;
  While Not Done Do
  Begin
    If LexColNo > Length(LexLine) Then
    Begin
      LexError('Byte string non fermee en fin de ligne');
      Done := True;
    End Else If Ord(LexCurChar) = 34 Then
    Begin
      LexAdvance;
      Done := True;
    End Else If Ord(LexCurChar) = 92 Then
    Begin
      LexAdvance;
      C := LexScanEscape(IV);
      If Length(S) < MAX_STR Then S := S + C;
    End Else
    Begin
      C := LexCurChar;
      LexAdvance;
      If Length(S) < MAX_STR Then S := S + C;
    End;
  End;
  MakeToken(T, TK_STRING, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanLifetime - lire une annotation de duree de vie
             Exemples : 'a  'static  'lifetime_name
  ============================================================ }
Procedure LexScanLifetime(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  LexAdvance; { consommer guillemet-simple }
  S := '''';
  While (LexColNo <= Length(LexLine)) And IsAlNum(LexCurChar) Do
  Begin
    If Length(S) < MAX_STR Then S := S + LexCurChar;
    LexAdvance;
  End;
  MakeToken(T, TK_LIFETIME, S, SL, SC);
End;

{ ============================================================
  Procedure : LexScanPunct - consommer un caractere de ponctuation
  ============================================================ }
Procedure LexScanPunct(Var T : TToken; SL, SC : Integer);
Var
  S : TString;
Begin
  S := LexCurChar;
  LexAdvance;
  MakeToken(T, TK_PUNCT, S, SL, SC);
End;

{ ============================================================
  Procedure : LexNextToken - produire le token suivant
  ============================================================ }
Procedure LexNextToken(Var T : TToken);
Var
  SL, SC : Integer;
  C      : Char;
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
  { Raw string r"..." ou r#"..."# }
  If (C = 'r') And ((Ord(LexPeek) = 34) Or (LexPeek = '#')) Then
  Begin
    LexScanRawStr(T, SL, SC); Exit;
  End;
  { Byte string b"..." ou byte literal b'.' }
  If C = 'b' Then
  Begin
    If Ord(LexPeek) = 34 Then Begin LexScanByteStr(T, SL, SC); Exit; End;
    If LexPeek = ''''     Then Begin LexScanByteLit(T, SL, SC); Exit; End;
  End;
  { Identifiant ou mot-cle }
  If IsAlpha(C) Then
  Begin
    LexScanIdent(T, SL, SC); Exit;
  End;
  { Litteraux numeriques }
  If IsDigit(C) Then
  Begin
    LexScanNumber(T, SL, SC); Exit;
  End;
  { Litteral chaine "..." }
  If Ord(C) = 34 Then Begin LexScanStrLit(T, SL, SC); Exit; End;
  { Litteral caractere 'X' OU annotation de duree de vie 'a }
  { Heuristique : ' + lettre + pas de ' en col+2 -> lifetime }
  If C = '''' Then
  Begin
    If IsAlpha(LexPeek) And
       ((LexColNo + 2 > Length(LexLine)) Or
        (LexLine[LexColNo + 2] <> '''')) Then
    Begin
      LexScanLifetime(T, SL, SC); Exit;
    End;
    LexScanCharLit(T, SL, SC); Exit;
  End;
  { Ponctuation simple - les operateurs composes sont en TODO 04 }
  LexScanPunct(T, SL, SC);
End;

{ ============================================================
  Procedure : LexInit - ouvrir le fichier et initialiser l'etat
  ============================================================ }
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
  LexNextLine;
End;

{ ============================================================
  Procedure : LexClose - fermer le fichier source
  ============================================================ }
Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ============================================================
  Procedure : PrintToken - afficher un token (mode -d)
  ============================================================ }
Procedure PrintToken(Const T : TToken);
Var
  KS : String[10];
  NS : TString;
Begin
  Case T.Kind Of
    TK_IDENT    : KS := 'IDENT   ';
    TK_INTEGER  : KS := 'INTEGER ';
    TK_FLOAT    : KS := 'FLOAT   ';
    TK_CHAR     : KS := 'CHAR    ';
    TK_STRING   : KS := 'STRING  ';
    TK_BYTE     : KS := 'BYTE    ';
    TK_OP       : KS := 'OP      ';
    TK_PUNCT    : KS := 'PUNCT   ';
    TK_LIFETIME : KS := 'LIFETIME';
    TK_EOF      : KS := 'EOF     ';
  End;
  Write('[', T.Line, ':', T.Col, '] ', KS, ' "', T.Val, '"');
  If T.Kind = TK_INTEGER Then
  Begin
    Str(T.IntVal, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_FLOAT Then
  Begin
    Str(T.FloatVal : 0 : 6, NS);
    Write(' =', NS);
  End Else If T.Kind = TK_CHAR Then
  Begin
    Str(T.IntVal, NS);
    Write(' cp=', NS);
  End Else If T.Kind = TK_BYTE Then
  Begin
    Str(T.IntVal, NS);
    Write(' val=', NS);
  End;
  WriteLn;
End;

{ ============================================================
  Procedure : Corps principal de la compilation
  ============================================================ }
Procedure Run;
Var
  T : TToken;
Begin
  LexInit;
  If Opts.Verbose Then
    WriteLn('RUST86: Analyse lexicale de ', Opts.SrcFile, ' ...');
  Repeat
    LexNextToken(T);
    If Opts.DebugTok Then PrintToken(T);
  Until T.Kind = TK_EOF;
  If Opts.Verbose Then
    WriteLn('RUST86: Analyse lexicale terminee.');
  { TODO 03-04 : litteraux chaines/char, operateurs composes }
  { TODO 05+   : parsing, types, generation de code          }
End;

{ ============================================================
  Procedure : Liberation des ressources
  ============================================================ }
Procedure Cleanup;
Begin
  LexClose;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  TotalSyms  := 0;
  LexOpened  := False;
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
