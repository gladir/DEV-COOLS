(* BCPL86.PAS - Compilateur BCPL vers assembleur 8086
   Turbo Pascal / Free Pascal (-Mtp)
   ================================================================

   LISTE DES TRAVAUX A REALISER (25 TODOS)
   ========================================

   TODO 01 - INFRASTRUCTURE DE BASE
     Constantes globales (VERSION, MAX_SYM, MAX_SCOPE, MAX_GLOBAL,
     MAX_LABELS, MAX_ERRORS, MAX_STR, MAX_PARAM, MAX_PROC, MAX_VEC,
     MAX_SWITCH, STACK_SIZE). Types fondamentaux (TString, TToken,
     TTokenKind, TSymKind, TSymRec). Cadre principal : arguments en
     ligne de commande (source .B ou .BCL, sortie .ASM, options -v -d
     -nr), ouverture des fichiers, prefixes labels ASM BL_ BK_ BV_
     BRT_. En BCPL tout est un mot machine 16 bits (WORD).

   TODO 02 - ANALYSEUR LEXICAL (LEXER)
     LexChar, LexPeek, LexAdvance, lignes/colonnes. Tokens BCPL :
     mots-cles LET AND BE IS INTO TO BY DO IF UNLESS TEST THEN ELSE
     OR WHILE UNTIL FOR LOOP BREAK RETURN RESULTIS SWITCHON CASE
     ENDCASE DEFAULT VALOF VEC TRUE FALSE MANIFEST STATIC GLOBAL
     SECTION GET TABLE NEEDS FINISH REPEAT REPEATWHILE REPEATUNTIL.
     Entiers decimaux, octaux (#NNN), hexadecimaux (#xHHH).
     Chars 'c' et sequences etoile *N *T *S ** *'. Chaines "abc"
     (octet 0 = longueur). Commentaires // et /* ... */.
     Operateurs := = ~= < <= > >= + - * / MOD REM ABS
     << >> & | ~ ! % @ SLCT EQV XOR.
     Delimiteurs $(  $)  {  }  ( ) , ; : ->.

   TODO 03 - TABLE DES SYMBOLES ET GESTION DE LA PORTEE
     SymEnter, SymFind, SymFindLocal. Portees imbriquees (ScopeEnter
     / ScopeLeave) pour routines et blocs. Categories :
     SK_MANIFEST (constante entiere resolue au compile-time),
     SK_GLOBAL (slot numerote dans le vecteur global G!n),
     SK_STATIC (variable DATA initialisee), SK_LOCAL (pile BP),
     SK_PARAM (parametre pile BP positif), SK_PROC (routine LET),
     SK_VEC (vecteur local : LET v = VEC n), SK_LABEL.
     Le vecteur global G! est un tableau de mots en DATA, BX pointe
     sur sa base ; acces : lecture [BX+2*slot], ecriture idem.

   TODO 04 - GESTION DU VECTEUR GLOBAL ET DES SEGMENTS
     Table des slots globaux (GLOBAL $( F : 12 $)) -> slot_table.
     Adresse slot n : [_BG_ + 2*n]. Initialisation BX = _BG_ au
     demarrage. Routine principale = G!1 (slot 1). STATIC : emettre
     chaque variable en DATA avec valeur initiale (DW). MANIFEST :
     synonyme de constante entiere, aucune emission DATA.

   TODO 05 - GENERATEUR DE CODE 8086 - PRIMITIVES
     EmitLabel, EmitI0..EmitI2, EmitComment, EmitDB, EmitDW, EmitDup.
     Compteur instr_count. Basculement out_file / tmp_file via
     SwitchToMain / SwitchToTmp. Fichier .ASM MASM/TASM, modele SMALL.
     Convention appel BCPL : args empiles gauche->droite, resultat AX,
     caller nettoie. Registre BX = base vecteur global (preserve).

   TODO 06 - DECLARATIONS MANIFEST ET CONSTANTES
     Sections MANIFEST $( name = expr ; ... $) et formes { }.
     Evaluer expressions constantes : entiers, TRUE (-1), FALSE (0),
     operations arithmetiques et logiques. Stocker SK_MANIFEST.
     MANIFEST remplace les identificateurs partout sans generer
     de code ni de donnee (comme #define C sans parametre).

   TODO 07 - DECLARATIONS LET SIMPLES (VARIABLES ET ALIASES)
     LET name = expr (variable locale sur la pile, offset -BP).
     LET name1 = e1 AND name2 = e2 (declarations multiples liees).
     VEC n dans un LET : allouer n+1 mots sur la pile, stocker
     l'adresse de base (LEA). Supporter les TABLE val1, val2, ...
     (constante vecteur en DATA). Portees imbriquees dans les blocs.

   TODO 08 - VARIABLES GLOBALES ET STATIQUES (GLOBAL / STATIC)
     GLOBAL $( name : numero $) : associer nom a slot dans vecteur.
     Generer acces : lecture MOV AX,[BX+2*slot], ecriture inverse.
     STATIC $( name = valeur $) : emettre DW en DATA. Initialiser
     BX = adresse _BG_ au START. MAX_GLOBAL = 256 slots.

   TODO 09 - EXPRESSIONS - NIVEAU PRIMAIRE
     Litteraux entiers (decimal, octal #NNN, hex #xHHH), TRUE (-1),
     FALSE (0). Chars 'c' et *N *T *S. Chaines "abc" : adresse DATA.
     Identificateurs : MANIFEST -> immediate, LOCAL -> [BP-n],
     GLOBAL -> [BX+2*slot], PARAM -> [BP+n].
     Operateur @ (LEA adresse-de). Operateur ! (indirect / indexe) :
     !x = [x], x!n = [x+2*n]. Operateur % (octet) : x%n=[x+n] (AL).
     Parentheses. VALOF $( ... RESULTIS expr $).

   TODO 10 - EXPRESSIONS - OPERATEURS ET PRIORITES
     Unaires : - (NEG), ~ (NOT bit), ABS (valeur absolue), @ (LEA).
     Termes : * (IMUL), / (IDIV), MOD (modulo positif) ou REM,
     << (SAL/SHL), >> (SHR logique).
     Additifs : + (ADD), - (SUB), SLCT n:p:x (champ de bits).
     Logiques : & (AND), | (OR), EQV (NOT XOR), XOR.
     Relations : = ~= < <= > >= -> TRUE=-1 ou FALSE=0.
     Priorites BCPL (differentes du C).

   TODO 11 - INSTRUCTION D'AFFECTATION (:=)
     Lvalue : nom simple, !expr (indirect), expr!n (indexe mot),
     expr%n (indexe octet). Rvalue : expression. Affectations
     multiples : lv1, lv2 := rv1, rv2. Pas de copie implicite
     de chaine (BCPL = types non distincts, tout est un mot).

   TODO 12 - COMMANDES CONDITIONNELLES (IF / UNLESS / TEST)
     IF cond DO cmd [ELSE cmd]. UNLESS cond DO cmd (= IF NOT cond).
     TEST cond THEN cmd ELSE cmd (ternaire commande).
     Sauts conditionnels 8086 avec etiquettes. La condition BCPL :
     zero = FALSE, non-zero = TRUE (convention inverse du C).

   TODO 13 - BOUCLES (WHILE / UNTIL / FOR / REPEAT)
     WHILE cond DO cmd. UNTIL cond DO cmd (inverse). REPEAT (infini).
     REPEATWHILE cond. REPEATUNTIL cond. FOR v=d TO f [BY p] DO cmd.
     LOOP (continuer iteration courante). BREAK (sortir boucle).
     Pile de break-labels et continue-labels (loop_break_stk).

   TODO 14 - COMMANDE SWITCHON
     SWITCHON expr INTO $( CASE val: cmds ENDCASE ... DEFAULT: $).
     Etiquettes entiÃ¨res. ENDCASE explicite (pas de fall-through).
     Table de sauts (dense) ou cascade CMP/JE (sparse). DEFAULT.
     MAX_SWITCH = 128 cases par SWITCHON.

   TODO 15 - BLOCS DE COMMANDES ET PORTEE
     Blocs $( cmd1; cmd2; ... $) ou {  }. Declarations LET
     imbriquees : variables locales supplementaires. A l'entree :
     noter SP ou compteur locaux, a la sortie restaurer. Forme
     VALOF $( ... RESULTIS expr $) comme expression bloc.

   TODO 16 - DECLARATIONS DE ROUTINES (LET ... BE / = VALOF)
     LET name(p1,..) BE cmd : procedure, retourne 0. LET name(p1,..)=
     expr : fonction. Prologue (PUSH BP/MOV BP,SP/SUB SP,locaux),
     epilogue (MOV SP,BP/POP BP/RET). RESULTIS expr -> MOV AX,val +
     JMP epilogue. Corps dans tmp_file, fusion MergeTmpToMain.
     LET f...AND g... : definitions mutuellement recursives.

   TODO 17 - APPELS DE ROUTINES ET VALOF
     Appels directs et indirects ((!vect)(args)). Empilement args
     gauche->droite. Resultat dans AX. VALOF $( RESULTIS expr $)
     en position expression. RETURN (retour, resultat=0). FINISH
     (HALT, exit code 0, INT 21h AH=4Ch AL=0).

   TODO 18 - TABLE ET VECTEUR (TABLE, VEC, acces ! et %)
     VEC n : allouer n+1 mots pile, stocker adresse base dans var.
     ARRAYS 0-indexes : v!0..v!n. TABLE v1,v2... : constante en DATA.
     v!i -> [base+2*i]. v%i -> [base+i] (byte, zero-extend).
     Optimiser les offset constants. Passage par adresse de vecteur.

   TODO 19 - GESTION DES CHAINES BCPL
     Format : octet 0 = longueur, octets 1..n = chars. Litteraux
     en DATA (DB n, 'a','b',..., 0). WRITEF "%S %N %C %I".
     WRITES, WRITEN, WRITECH, NEWLINE, READS, READN, READCH.
     COPYSTRING(s,d), COMPSTRING(s1,s2). PACKSTRING / UNPACKSTRING.

   TODO 20 - ROUTINES RUNTIME 8086 (BRT_xxx)
     BRT_WRITES : [SI]=chaine BCPL -> DOS. BRT_WRITEN : AX->decimal.
     BRT_WRITECH : AL->DOS INT 21h. BRT_NEWLINE : CR LF.
     BRT_READCH : AL=char. BRT_READN : ligne -> AX entier.
     BRT_READS : ligne -> tampon BCPL [BX]. BRT_STOP : exit AX.
     BRT_GLOBE : BX = _BG_. Entree START : init DS BX, copier
     adresses routines globales dans _BG_, sauter G!1 (main).

   TODO 21 - DIRECTIVE GET ET MULTI-FICHIERS
     GET "fichier" : inclure source (pile contextes lexicaux).
     Profondeur max d'inclusion. SECTION "nom" : commentaire ASM.
     NEEDS "module" : note dependance (non resolue en phase 1).
     Option -I pour chemin de recherche des fichiers inclus.

   TODO 22 - OPERATEURS AVANCES : SLCT, EQV, XOR, >>
     SLCT n:p:x : SHR AX,p puis AND AX,((1<<n)-1). EQV : XOR+NOT.
     XOR : XOR AX,BX. >> : SHR (logique, non signe).
     ABS : NEG+JNS. MOD vs REM : modulo toujours positif vs reste.
     IMUL 16x16 en BCPL (resultat tronque a 16 bits).

   TODO 23 - LET ... AND (DEFINITIONS MUTUELLES)
     Passe de collecte : scanner tous les noms du groupe LET/AND
     avant de compiler les corps. LET f AND g : inscrit f et g dans
     sym_table, puis compile les corps. LET v1=e1 AND v2=e2 pour
     multi-declarations. Coherence des portees entre membres AND.

   TODO 24 - GESTION DES ERREURS ET MODE VERBEUX
     Messages situes (fichier(ligne,col) : msg). Comptage erreurs/
     avertissements, continuation en mode recuperation, arret apres
     MAX_ERRORS. Mode -v : statistiques (lignes, tokens, symboles,
     slots globaux, routines, instructions, fichiers inclus, erreurs).
     Mode -d : dump table des symboles (SymDumpVerbose).

   TODO 25 - INTEGRATION FINALE ET TESTS
     ParseProgram : BCPL top-level. Prologue .ASM (SMALL, DOSSEG,
     .MODEL, .STACK 512, .DATA avec _BG_ DW MAXGLOB DUP(?), .CODE,
     END START). START : MOV AX,_DATA ; MOV DS,AX ; LEA BX,[_BG_] ;
     copier adresses routines globales ; CALL WORD PTR [BX+2].
     Tests : HelloWorld, arithmetique+boucles, vecteurs+tri, chaines
     WRITEF, routines recursives (factorielle, Hanoi), SWITCHON,
     definitions mutuelles LET/AND. TASM/MASM + DOSBox.

   ================================================================ *)
Program BCPL86;

{$I-}   { desactiver les IO-check pour gerer nous-memes les erreurs }

{ ============================================================
  TODO 01 - INFRASTRUCTURE DE BASE
  ============================================================ }

{ --- Constantes de dimensionnement --- }
Const
  BCPL86_VERSION = '1.0';
  BCPL86_DATE    = '2026-03-03';

  MAX_SYM    = {$IFDEF FPC}1024{$ELSE}100{$ENDIF};   { entrees table des symboles               }
  MAX_PROC   = {$IFDEF FPC}128{$ELSE}50{$ENDIF};    { routines LET                             }
  MAX_PARAM  = {$IFDEF FPC}16{$ELSE}8{$ENDIF};     { parametres par routine                   }
  MAX_FIELD  = 64;     { non utilise en BCPL (pas de RECORD)      }
  MAX_CONST  = 256;    { constantes MANIFEST                      }
  MAX_TYPE   = 32;     { descripteurs de type (juste WORD en BCPL) }
  MAX_LABEL  = 1024;   { labels internes (IF/WHILE/SWITCHON...)   }
  MAX_SCOPE  = 32;     { profondeur maximale de portee            }
  MAX_ERRORS = 30;     { arret apres N erreurs                    }
  MAX_STR    = {$IFDEF FPC}128{$ELSE}80{$ENDIF};    { longueur maximale d'une TString          }
  MAX_IMPORT = 16;     { fichiers inclus (GET directive)          }
  MAX_GLOBAL = 256;    { slots dans le vecteur global G!          }
  MAX_SWITCH = 128;    { cases par SWITCHON                       }
  STACK_SIZE = 512;    { taille segment pile en octets            }

  { Prefixes des labels assembleur 8086 }
  BV_PFX  = '_BV_';   { variables statiques (.DATA)              }
  BP_PFX  = '_BP_';   { procedures / routines BCPL               }
  BL_PFX  = '_BL_';   { etiquettes de controle (IF/WHILE/SWITCH) }
  BRT_PFX = '_BRT_';  { routines runtime BCPL                    }
  BK_PFX  = '_BK_';   { constantes de chaines litterales         }
  BG_NAME = '_BG_';   { vecteur global BCPL (tableau de mots)    }

{ --- Types fondamentaux --- }
Type
  TString = String[MAX_STR];

  { ---- Tokens ---- }
  TTokenKind = (
    TK_IDENT,     { identificateur                                }
    TK_INTEGER,   { litteral entier                               }
    TK_REAL,      { litteral reel                                 }
    TK_CHAR,      { litteral caractere  0X ou 'X'                 }
    TK_STRING,    { litteral chaine  'abc' ou "abc"              }
    TK_KEYWORD,   { mot-cle BCPL reserve                          }
    TK_OP,        { operateur symbolique                          }
    TK_PUNCT,     { ponctuation  : ; . , ( ) [ ] ^ &             }
    TK_EOF        { fin de fichier source                         }
  );

  TToken = Record
    kind     : TTokenKind;
    val      : TString;       { representation brute              }
    int_val  : LongInt;       { si TK_INTEGER ou TK_CHAR          }
    real_val : Real;          { si TK_REAL                        }
    line     : Integer;       { ligne dans le source              }
    col      : Integer;       { colonne dans le source            }
  End;

  { ---- Types BCPL : tout est un mot 16 bits non type ---- }
  TTypeKind = (
    TYK_WORD,     { mot 16 bits - type unique de BCPL             }
    TYK_STRING    { adresse d'une chaine au format BCPL            }
  );

  { ---- Descripteur de type (minimal pour BCPL) ---- }
  TTypeRec = Record
    kind     : TTypeKind;
    bit_size : Integer;       { 16 pour WORD, 8 pour STRING/byte  }
    base_idx : Integer;       { non utilise en BCPL               }
    arr_len  : Integer;       { non utilise en BCPL               }
    rec_sym  : Integer;       { non utilise en BCPL               }
    rec_nfld : Integer;       { non utilise en BCPL               }
  End;

  { ---- Categories de symboles BCPL ---- }
  TSymKind = (
    SK_NONE,      { entree non utilisee                           }
    SK_MANIFEST,  { constante entiere MANIFEST (compile-time)     }
    SK_GLOBAL,    { variable dans le vecteur global G!slot        }
    SK_STATIC,    { variable statique initialisee (.DATA)         }
    SK_LOCAL,     { variable locale sur la pile (BP-n)            }
    SK_PARAM,     { parametre de routine (BP+n)                   }
    SK_PROC,      { routine BCPL (LET name(...) BE ...)           }
    SK_VEC,       { vecteur local (VEC n) = adresse BP-n          }
    SK_LABEL      { etiquette de SWITCHON/CASE                    }
  );

  { ---- Portee d'un symbole ---- }
  TScope = (
    SC_GLOBAL,    { niveau module (segment DATA / registre)       }
    SC_LOCAL,     { niveau procedure (pile BP)                    }
    SC_PARAM,     { parametre (pile BP, offset positif)           }
    SC_CONST      { constante evaluee au compile-time             }
  );

  { ---- Entree de la table des symboles BCPL ---- }
  TSymbol = Record
    name       : TString;     { nom tel que declare (casse conservee)  }
    kind       : TSymKind;
    scope      : TScope;
    type_idx   : Integer;     { index dans type_table (toujours TYP_WORD) }
    asm_label  : TString;     { label ASM                              }
    bp_offset  : Integer;     { offset BP pour variables locales/param }
    is_var_par : Boolean;     { non utilise en BCPL (pas de VAR param) }
    const_ival : LongInt;     { valeur si SK_MANIFEST                  }
    const_sval : TString;     { non utilise en BCPL                    }
    proc_idx   : Integer;     { si SK_PROC : index dans proc_table     }
    fld_offset : Integer;     { non utilise en BCPL                    }
    glob_slot  : Integer;     { si SK_GLOBAL : numero de slot G!n      }
    scope_level: Integer;     { niveau de portee lors de la declaration}
  End;

  TSymbolTable = Array[1..MAX_SYM]  of TSymbol;
  TTypeTable   = Array[1..MAX_TYPE] of TTypeRec;

  { ---- Parametre formel de procedure ---- }
  TParamRec = Record
    name       : TString;
    type_idx   : Integer;
    is_var_par : Boolean;     { VAR param -> passe par adresse         }
    bp_offset  : Integer;
  End;

  { ---- Entree de procedure / fonction ---- }
  TProcRec = Record
    name         : TString;
    asm_label    : TString;   { ex : _OP_<module>_<nom>               }
    ret_type_idx : Integer;   { 0 si procedure sans retour             }
    param_count  : Integer;
    params       : Array[1..MAX_PARAM] of TParamRec;
    local_size   : Integer;   { octets du cadre local sur la pile      }
    is_export    : Boolean;   { PROCEDURE* (export pour liaison)       }
  End;

  TProcTable = Array[1..MAX_PROC] of TProcRec;

  { ---- Constante nommee (section CONST) ---- }
  TConstRec = Record
    name     : TString;
    type_idx : Integer;
    ival     : LongInt;       { valeur entiere / booleen / char        }
    sval     : TString;       { valeur chaine                          }
    is_real  : Boolean;
    rval     : Real;
  End;

  TConstTable = Array[1..MAX_CONST] of TConstRec;

  { ---- Fichier inclus (directive GET) ---- }
  TImportRec = Record
    mod_name : TString;       { nom du fichier inclus (GET "file")     }
    alias    : TString;       { section associee si SECTION            }
  End;

  { Pointeur sur fichier texte - nomme pour eviter incompatibilite TP }
  TTextPtr = ^Text;

{ --- Variables globales du compilateur --- }
Var
  { Tables allouees dynamiquement }
  sym_table   : ^TSymbolTable;
  type_table  : ^TTypeTable;
  proc_table  : ^TProcTable;
  const_table : ^TConstTable;

  { Fichiers }
  src_file     : Text;
  out_file     : Text;
  tmp_file     : Text;
  str_file     : Text;             { chaÃ®nes litterales differees (TODO 25) }
  cur_out      : TTextPtr;   { pointe sur out_file ou tmp_file       }
  src_fname    : TString;
  out_fname    : TString;
  tmp_fname    : TString;
  str_fname    : TString;          { nom du fichier de chaines litterales }

  { Compteurs }
  sym_count    : Integer;
  type_count   : Integer;
  proc_count   : Integer;
  const_count  : Integer;
  label_count  : Integer;
  err_count    : Integer;
  warn_count   : Integer;
  instr_count  : Integer;
  str_lit_count: Integer;
  tok_count    : Integer;   { TODO 24 : tokens lus depuis la source }

  { Etat lexer }
  lex_lineno   : Integer;
  lex_colno    : Integer;
  lex_line     : String[255];
  lex_pos      : Integer;
  cur_tok      : TToken;
  peek_tok     : TToken;
  has_peek     : Boolean;
  lex_eof      : Boolean;       { vrai quand le source est epuise         }

  { Contexte de compilation }
  module_name  : TString;
  cur_proc_idx : Integer;      { 0 = niveau module                     }
  scope_sp     : Integer;      { pointeur de pile de portee            }
  scope_base   : Array[0..MAX_SCOPE] of Integer;  { base sym par portee }

  { Options }
  opt_verbose  : Boolean;
  opt_debug    : Boolean;
  opt_no_rt    : Boolean;

  { Modules importes }
  import_count : Integer;
  import_table : Array[1..MAX_IMPORT] of TImportRec;

  { Pile de labels boucle (WHILE/REPEAT/LOOP) }
  loop_depth       : Integer;
  loop_break_stk   : Array[1..MAX_SCOPE] of TString;
  loop_cont_stk    : Array[1..MAX_SCOPE] of TString;

  { Label de retour de la procedure courante (RETURN -> JMP cur_ret_lbl) }
  cur_ret_lbl      : TString;

  { Type BCPL unique (index dans type_table) }
  TYP_WORD     : Integer;     { type unique : mot 16 bits             }
  TYP_STRING   : Integer;     { adresse chaine BCPL                   }

  { Vecteur global BCPL : G!slot }
  glob_vec_size : Integer;    { plus grand slot G! utilise            }
  glob_slots    : Array[0..MAX_GLOBAL-1] of Integer; { slot -> sym idx }
  glob_routine  : Array[0..MAX_GLOBAL-1] of TString; { slot -> label proc }

  { Generation de code BCPL }
  cur_local_off  : Integer;   { offset BP courant pour LET locaux     }
  valof_lbl      : TString;   { label RESULTIS courant                }
  valof_depth    : Integer;   { profondeur VALOF imbriques            }
  cur_switch_lbl : TString;   { label fin SWITCHON courant            }

{ ============================================================
  Utilitaires generaux (stubs - implementation dans TODO 02+)
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

{ ============================================================
  TODO 02 - ANALYSEUR LEXICAL (LEXER)
  ============================================================ }

{ --- Predicats de caracteres --- }

Function LexIsAlpha(c : Char) : Boolean;
Begin
  LexIsAlpha := ((c >= 'A') And (c <= 'Z')) Or ((c >= 'a') And (c <= 'z')) Or (c = '_');
End;

Function LexIsDigit(c : Char) : Boolean;
Begin
  LexIsDigit := (c >= '0') And (c <= '9');
End;

Function LexIsHexDigit(c : Char) : Boolean;
Begin
  LexIsHexDigit := ((c >= '0') And (c <= '9'))
    Or ((c >= 'A') And (c <= 'F'))
    Or ((c >= 'a') And (c <= 'f'));
End;

Function LexIsAlNum(c : Char) : Boolean;
Begin
  LexIsAlNum := LexIsAlpha(c) Or LexIsDigit(c);
End;

Function LexIsWS(c : Char) : Boolean;
Begin
  LexIsWS := (c = ' ') Or (c = #9) Or (c = #13);
End;

Function UpChr(c : Char) : Char;
Begin
  If (c >= 'a') And (c <= 'z') Then
    UpChr := Chr(Ord(c) - 32)
  Else
    UpChr := c;
End;

Function HexVal(c : Char) : Integer;
Begin
  If (c >= '0') And (c <= '9') Then HexVal := Ord(c) - Ord('0')
  Else If (c >= 'A') And (c <= 'F') Then HexVal := Ord(c) - Ord('A') + 10
  Else HexVal := Ord(c) - Ord('a') + 10;
End;

{ --------------------------------------------------------------------------
  LexRefill : lire la prochaine ligne du fichier source dans lex_line.
  Met lex_eof a True quand le fichier est epuise.
  -------------------------------------------------------------------------- }
Procedure LexRefill;
Begin
  If Eof(src_file) Then
  Begin
    lex_eof  := True;
    lex_line := '';
    lex_pos  := 1;
  End
  Else
  Begin
    ReadLn(src_file, lex_line);
    Inc(lex_lineno);
    lex_pos   := 1;
    lex_colno := 1;
  End;
End;

{ --------------------------------------------------------------------------
  LexCurChar : retourner le caractere courant ou #0 si fin de ligne/fichier.
  -------------------------------------------------------------------------- }
Function LexCurChar : Char;
Begin
  If lex_eof Then
    LexCurChar := #0
  Else If lex_pos > Length(lex_line) Then
    LexCurChar := #0
  Else
    LexCurChar := lex_line[lex_pos];
End;

{ --------------------------------------------------------------------------
  LexPeekChar : regarder en avance de n positions sans consommer.
  -------------------------------------------------------------------------- }
Function LexPeekChar(n : Integer) : Char;
Var p : Integer;
Begin
  p := lex_pos + n;
  If lex_eof Or (p < 1) Or (p > Length(lex_line)) Then
    LexPeekChar := #0
  Else
    LexPeekChar := lex_line[p];
End;

{ --------------------------------------------------------------------------
  LexAdvance : avancer d'un caractere ; passer a la ligne suivante si besoin.
  -------------------------------------------------------------------------- }
Procedure LexAdvance;
Begin
  If Not lex_eof Then
  Begin
    Inc(lex_pos);
    Inc(lex_colno);
    If lex_pos > Length(lex_line) + 1 Then
      LexRefill;
  End;
End;

{ --------------------------------------------------------------------------
  LexSkipLineComment : sauter un commentaire de ligne  // ...
  On est positionne sur le premier '/' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure LexSkipLineComment;
Begin
  { Avancer jusqu'a la fin de la ligne }
  While (Not lex_eof) And (LexCurChar <> #0) Do
    LexAdvance;
End;

{ --------------------------------------------------------------------------
  LexSkipBlockComment : sauter un commentaire bloc  /* ... */  (non imbrique).
  On est positionne sur le premier '/' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure LexSkipBlockComment;
Begin
  LexAdvance;  { sauter '/' }
  LexAdvance;  { sauter '*' }
  While Not lex_eof Do
  Begin
    If LexCurChar = #0 Then
      LexRefill
    Else If (LexCurChar = '*') And (LexPeekChar(1) = '/') Then
    Begin
      LexAdvance;  { sauter '*' }
      LexAdvance;  { sauter '/' }
      Break;
    End
    Else
      LexAdvance;
  End;
End;

{ --------------------------------------------------------------------------
  LexSkipWS : sauter les blancs et les commentaires BCPL // et /* ... */.
  -------------------------------------------------------------------------- }
Procedure LexSkipWS;
Begin
  Repeat
    { Sauter espaces et tabulations }
    While (Not lex_eof) And (LexCurChar <> #0) And LexIsWS(LexCurChar) Do
      LexAdvance;

    { Fin de ligne -> ligne suivante }
    If (Not lex_eof) And (LexCurChar = #0) Then
    Begin
      LexRefill;
      Continue;
    End;

    { Commentaire de ligne  // ... fin-de-ligne }
    If (LexCurChar = '/') And (LexPeekChar(1) = '/') Then
    Begin
      LexSkipLineComment;
      Continue;
    End;

    { Commentaire bloc  /* ... */ }
    If (LexCurChar = '/') And (LexPeekChar(1) = '*') Then
    Begin
      LexSkipBlockComment;
      Continue;
    End;

    Break;
  Until False;
End;

{ --------------------------------------------------------------------------
  LexIsKeyword : verifier si s est un mot-cle BCPL (en majuscules).
  BCPL est insensible a la casse ; tous les mots-cles sont compares
  apres conversion en majuscules.
  -------------------------------------------------------------------------- }
Function LexIsKeyword(Const s : TString) : Boolean;
Begin
  LexIsKeyword :=
    (s = 'LET')         Or (s = 'AND')          Or (s = 'BE')           Or
    (s = 'IS')          Or (s = 'INTO')          Or
    (s = 'TO')          Or (s = 'BY')            Or (s = 'DO')           Or
    (s = 'IF')          Or (s = 'UNLESS')        Or
    (s = 'TEST')        Or (s = 'THEN')          Or (s = 'ELSE')         Or
    (s = 'OR')          Or
    (s = 'WHILE')       Or (s = 'UNTIL')         Or
    (s = 'FOR')         Or (s = 'LOOP')          Or
    (s = 'BREAK')       Or (s = 'RETURN')        Or (s = 'RESULTIS')     Or
    (s = 'SWITCHON')    Or (s = 'CASE')          Or (s = 'ENDCASE')      Or
    (s = 'DEFAULT')     Or
    (s = 'VALOF')       Or (s = 'VEC')           Or
    (s = 'TRUE')        Or (s = 'FALSE')         Or
    (s = 'MANIFEST')    Or (s = 'STATIC')        Or (s = 'GLOBAL')       Or
    (s = 'SECTION')     Or (s = 'GET')           Or (s = 'TABLE')        Or
    (s = 'NEEDS')       Or
    (s = 'FINISH')      Or
    (s = 'REPEAT')      Or (s = 'REPEATWHILE')   Or (s = 'REPEATUNTIL')  Or
    (s = 'MOD')         Or (s = 'REM')           Or (s = 'ABS')          Or
    (s = 'EQV')         Or (s = 'XOR')           Or
    (s = 'SLCT')        Or (s = 'NOT');
End;

{ --------------------------------------------------------------------------
  LexMakeTok : construire un TToken passe par reference.
  -------------------------------------------------------------------------- }
Procedure LexMakeTok(Var t : TToken; k : TTokenKind; Const v : TString);
Begin
  t.kind     := k;
  t.val      := v;
  t.int_val  := 0;
  t.real_val := 0.0;
  t.line     := lex_lineno;
  t.col      := lex_colno;
End;

{ --------------------------------------------------------------------------
  LexReadIdent : lire un identifiant ou un mot-cle BCPL.
  BCPL est insensible a la casse ; on compare la version majuscule
  pour la detection du mot-cle, mais on stocke la version majuscule
  comme identifiant (BCPL conventionnellement en majuscules).
  -------------------------------------------------------------------------- }
Procedure LexReadIdent(Var t : TToken);
Var s  : TString;
    su : TString;
Begin
  s  := '';
  su := '';
  While (Not lex_eof) And (LexIsAlNum(LexCurChar) Or (LexCurChar = '_')) Do
  Begin
    If Length(s) < MAX_STR Then
    Begin
      s  := s  + LexCurChar;
      su := su + UpChr(LexCurChar);
    End;
    LexAdvance;
  End;
  If LexIsKeyword(su) Then
    LexMakeTok(t, TK_KEYWORD, su)   { mots-cles toujours en majuscules }
  Else
    LexMakeTok(t, TK_IDENT, su);    { identifiants en majuscules aussi  }
End;

{ --------------------------------------------------------------------------
  LexReadNumber : lire un entier decimal seulement (# est gere dans LexNext).
  Le prefixe # (octal ou hex) est traite directement dans LexNext.
  -------------------------------------------------------------------------- }
Procedure LexReadNumber(Var t : TToken);
Var s   : TString;
    n   : LongInt;
    i   : Integer;
Begin
  s := '';
  n := 0;

  While (Not lex_eof) And LexIsDigit(LexCurChar) Do
  Begin
    If Length(s) < MAX_STR Then s := s + LexCurChar;
    LexAdvance;
  End;

  { Entier decimal pur }
  n := 0;
  For i := 1 To Length(s) Do
    n := n * 10 + (Ord(s[i]) - Ord('0'));
  LexMakeTok(t, TK_INTEGER, s);
  t.int_val := n;
End;

{ --------------------------------------------------------------------------
  LexReadBcplNumber : lire un entier BCPL prefixe par '#'.
  Formes : #NNN (octal)  #xHHH ou #XHHH (hexadecimal).
  On est positionne sur '#' au moment de l'appel.
  -------------------------------------------------------------------------- }
Procedure LexReadBcplNumber(Var t : TToken);
Var s   : TString;
    n   : LongInt;
    i   : Integer;
Begin
  LexAdvance;  { sauter '#' }
  n := 0;
  s := '';

  { Hexadecimal : #x ou #X }
  If (LexCurChar = 'x') Or (LexCurChar = 'X') Then
  Begin
    LexAdvance;  { sauter 'x' }
    While (Not lex_eof) And LexIsHexDigit(LexCurChar) Do
    Begin
      If Length(s) < MAX_STR Then s := s + LexCurChar;
      LexAdvance;
    End;
    n := 0;
    For i := 1 To Length(s) Do
      n := n * 16 + HexVal(s[i]);
    LexMakeTok(t, TK_INTEGER, '#x' + s);
    t.int_val := n;
  End
  Else
  Begin
    { Octal : digits 0-7 seulement }
    While (Not lex_eof) And (LexCurChar >= '0') And (LexCurChar <= '7') Do
    Begin
      If Length(s) < MAX_STR Then s := s + LexCurChar;
      LexAdvance;
    End;
    n := 0;
    For i := 1 To Length(s) Do
      n := n * 8 + (Ord(s[i]) - Ord('0'));
    LexMakeTok(t, TK_INTEGER, '#' + s);
    t.int_val := n;
  End;
End;

{ --------------------------------------------------------------------------
  LexReadString : lire une chaine BCPL entre guillemets doubles "texte".
  Support des sequences etoile : *N *T *S *P *C ** *'
  -------------------------------------------------------------------------- }
Procedure LexReadString(Var t : TToken);
Var s : TString;
    c : Char;
Begin
  s := '';
  LexAdvance;  { sauter '"' ouvrant }
  While (Not lex_eof) And (LexCurChar <> '"') And (LexCurChar <> #0) Do
  Begin
    If LexCurChar = '*' Then
    Begin
      LexAdvance;  { sauter '*' }
      Case UpChr(LexCurChar) Of
        'N' : c := #10;   { newline    }
        'T' : c := #9;    { tabulation }
        'S' : c := ' ';   { espace     }
        'P' : c := #12;   { form-feed  }
        'C' : c := #13;   { CR         }
        '*' : c := '*';
        '''' : c := '''';
        '"' : c := '"';
        Else  c := LexCurChar;
      End;
      If Length(s) < MAX_STR Then s := s + c;
      LexAdvance;
    End
    Else
    Begin
      If Length(s) < MAX_STR Then s := s + LexCurChar;
      LexAdvance;
    End;
  End;
  If LexCurChar = '"' Then
    LexAdvance;  { sauter '"' fermant }
  LexMakeTok(t, TK_STRING, s);
  If Length(s) = 1 Then
    t.int_val := Ord(s[1]);
End;

{ --------------------------------------------------------------------------
  LexReadCharLit : lire un caractere BCPL entre apostrophes  'c'  ou '*X'.
  Sequences etoile : *N *T *S *P *C ** *'
  -------------------------------------------------------------------------- }
Procedure LexReadCharLit(Var t : TToken);
Var c    : Char;
    cval : Integer;
Begin
  LexAdvance;  { sauter apostrophe ouvrante }
  cval := 0;
  If LexCurChar = '*' Then
  Begin
    LexAdvance;  { sauter '*' }
    Case UpChr(LexCurChar) Of
      'N' : cval := 10;
      'T' : cval := 9;
      'S' : cval := 32;
      'P' : cval := 12;
      'C' : cval := 13;
      '*' : cval := Ord('*');
      '''' : cval := Ord('''');
    Else
      cval := Ord(LexCurChar);
    End;
    LexAdvance;
  End
  Else
  Begin
    cval := Ord(LexCurChar);
    LexAdvance;
  End;
  { Sauter apostrophe fermante si presente }
  If LexCurChar = '''' Then LexAdvance;
  c := Chr(Byte(cval));
  LexMakeTok(t, TK_CHAR, c);
  t.int_val := cval;
End;

{ --------------------------------------------------------------------------
  LexReadOp : lire un operateur ou signe de ponctuation BCPL.
  Operateurs BCPL : := = ~= < <= > >= + - * / << >> & | ~ ! % @ ->
  Delimiteurs bloc : $( et $) ou accolades
  -------------------------------------------------------------------------- }
Procedure LexReadOp(Var t : TToken);
Var s : TString;
    c : Char;
Begin
  c := LexCurChar;
  LexAdvance;
  s := c;

  Case c Of
    ':' : If LexCurChar = '=' Then
          Begin
            s := ':=';
            LexAdvance;
          End;
    '~' : If LexCurChar = '=' Then
          Begin
            s := '~=';
            LexAdvance;
          End;
    '<' : If LexCurChar = '=' Then
          Begin
            s := '<=';
            LexAdvance;
          End
          Else If LexCurChar = '<' Then
          Begin
            s := '<<';
            LexAdvance;
          End;
    '>' : If LexCurChar = '=' Then
          Begin
            s := '>=';
            LexAdvance;
          End
          Else If LexCurChar = '>' Then
          Begin
            s := '>>';
            LexAdvance;
          End;
    '-' : If LexCurChar = '>' Then
          Begin
            s := '->';
            LexAdvance;
          End;
    '$' : If LexCurChar = '(' Then
          Begin
            s := '$(';
            LexAdvance;
          End
          Else If LexCurChar = ')' Then
          Begin
            s := '$)';
            LexAdvance;
          End;
  End;

  { Classement en ponctuation ou en operateur }
  If (s = '(') Or (s = ')') Or (s = '[') Or (s = ']') Or
     (s = ';') Or (s = ',') Or (s = '.') Or
     (s = ':') Or (s = '{') Or (s = '}') Then
    LexMakeTok(t, TK_PUNCT, s)
  Else
    LexMakeTok(t, TK_OP, s);
End;

{ --------------------------------------------------------------------------
  LexNext : produire le token suivant dans cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexNext;
Begin
  { Consommer le token anticipe si disponible }
  If has_peek Then
  Begin
    cur_tok  := peek_tok;
    has_peek := False;
    Exit;
  End;

  Inc(tok_count);   { TODO 24 : compter les tokens fraichement scans }
  LexSkipWS;
  lex_colno := lex_pos;

  If lex_eof Or (LexCurChar = #0) Then
  Begin
    LexMakeTok(cur_tok, TK_EOF, '');
    Exit;
  End;

  { Identifiant ou mot-cle : commence par une lettre ou '_' }
  If LexIsAlpha(LexCurChar) Or (LexCurChar = '_') Then
  Begin
    LexReadIdent(cur_tok);
    Exit;
  End;

  { Litteraux numeriques : entiers decimaux }
  If LexIsDigit(LexCurChar) Then
  Begin
    LexReadNumber(cur_tok);
    Exit;
  End;

  { Nombre BCPL prefixe # : octal ou hexadecimal }
  If LexCurChar = '#' Then
  Begin
    LexReadBcplNumber(cur_tok);
    Exit;
  End;

  { Litteraux chaine  "..." }
  If LexCurChar = '"' Then
  Begin
    LexReadString(cur_tok);
    Exit;
  End;

  { Litteraux caractere BCPL  'c'  ou  '*X' }
  If LexCurChar = '''' Then
  Begin
    LexReadCharLit(cur_tok);
    Exit;
  End;

  { Operateurs et ponctuation BCPL }
  LexReadOp(cur_tok);
End;

{ --------------------------------------------------------------------------
  LexPeek : anticiper le token suivant sans consommer cur_tok.
  -------------------------------------------------------------------------- }
Procedure LexPeek;
Var saved : TToken;
Begin
  If Not has_peek Then
  Begin
    saved    := cur_tok;
    LexNext;
    peek_tok := cur_tok;
    cur_tok  := saved;
    has_peek := True;
  End;
End;

{ Forward TODO 24 : ErrorMsg est utilise par LexExpect / LexExpectKind }
Procedure ErrorMsg(Const msg : TString); Forward;

{ --------------------------------------------------------------------------
  LexExpect : consommer cur_tok en verifiant que sa valeur est 'val'.
  -------------------------------------------------------------------------- }
Procedure LexExpect(Const val : TString);
Begin
  If cur_tok.val <> val Then
    ErrorMsg('attendu ''' + val + ''' mais lu ''' + cur_tok.val + '''');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexExpectKind : consommer cur_tok en verifiant son TTokenKind.
  -------------------------------------------------------------------------- }
Procedure LexExpectKind(k : TTokenKind);
Begin
  If cur_tok.kind <> k Then
    ErrorMsg('identifiant attentu, lu : ''' + cur_tok.val + '''');
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexInit : ouvrir le fichier source et charger le premier token.
  -------------------------------------------------------------------------- }
Procedure LexInit(Const fname : TString);
Begin
  Assign(src_file, fname);
  Reset(src_file);
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible d''ouvrir ', fname);
    Halt(1);
  End;
  lex_line    := '';
  lex_pos     := 1;
  lex_lineno  := 0;
  lex_colno   := 1;
  lex_eof     := False;
  has_peek    := False;
  LexRefill;
  LexNext;
End;

{ --------------------------------------------------------------------------
  LexClose : fermer le fichier source.
  -------------------------------------------------------------------------- }
Procedure LexClose;
Begin
  If Not lex_eof Then
    Close(src_file);
End;

{ ============================================================
  TODO 03 - TABLE DES SYMBOLES ET GESTION DE LA PORTEE
  ============================================================ }

{ ============================================================
  TODO 24 - GESTION DES ERREURS ET MODE VERBEUX
  ============================================================ }

{ --------------------------------------------------------------------------
  ErrorMsg : afficher un message d'erreur situe, incrementer err_count.
  Stoppe la compilation apres MAX_ERRORS.
  -------------------------------------------------------------------------- }
Procedure ErrorMsg(Const msg : TString);
Begin
  Inc(err_count);
  WriteLn(src_fname, '(', lex_lineno, ',', lex_colno, ') Erreur : ', msg);
  If err_count >= MAX_ERRORS Then
  Begin
    WriteLn(src_fname, ' : trop d''erreurs (', MAX_ERRORS,
            ') - compilation abandonnee.');
    Halt(1);
  End;
End;

Procedure WarnMsg(Const msg : TString);
Begin
  Inc(warn_count);
  WriteLn(src_fname, '(', lex_lineno, ',', lex_colno, ') Avertissement : ', msg);
End;

{ --------------------------------------------------------------------------
  AsmIdent : convertir un identifiant Oberon en label ASM valide.
  Les caracteres non autorises en MASM sont remplaces par '_'.
  -------------------------------------------------------------------------- }
Function AsmIdent(Const s : TString) : TString;
Var i   : Integer;
    r   : TString;
    c   : Char;
Begin
  r := '';
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If LexIsAlNum(c) Or (c = '_') Then
      r := r + c
    Else
      r := r + '_';
  End;
  AsmIdent := r;
End;

{ --------------------------------------------------------------------------
  NewLabel : generer un label de controle unique  _OL_nnn.
  -------------------------------------------------------------------------- }
Function NewLabel : TString;
Var s : TString;
Begin
  Inc(label_count);
  Str(label_count, s);
  NewLabel := BL_PFX + s;
End;

{ --------------------------------------------------------------------------
  Pile de labels de boucle (WHILE / REPEAT / LOOP).
  -------------------------------------------------------------------------- }
Procedure PushLoopLabels(Const lbl_break, lbl_cont : TString);
Begin
  If loop_depth >= MAX_SCOPE Then
  Begin
    ErrorMsg('Imbrication de boucles trop profonde');
    Exit;
  End;
  Inc(loop_depth);
  loop_break_stk[loop_depth] := lbl_break;
  loop_cont_stk[loop_depth]  := lbl_cont;
End;

Procedure PopLoopLabels;
Begin
  If loop_depth > 0 Then
    Dec(loop_depth);
End;

Function TopBreakLabel : TString;
Begin
  If loop_depth > 0 Then
    TopBreakLabel := loop_break_stk[loop_depth]
  Else
    TopBreakLabel := '';
End;

Function TopContLabel : TString;
Begin
  If loop_depth > 0 Then
    TopContLabel := loop_cont_stk[loop_depth]
  Else
    TopContLabel := '';
End;

{ --------------------------------------------------------------------------
  ScopeEnter : ouvrir un nouveau niveau de portee.
  On memorise l'indice de sym_count courant dans scope_base.
  -------------------------------------------------------------------------- }
Procedure ScopeEnter;
Begin
  If scope_sp >= MAX_SCOPE Then
  Begin
    ErrorMsg('Portee trop imbriquee');
    Exit;
  End;
  Inc(scope_sp);
  scope_base[scope_sp] := sym_count;
End;

{ --------------------------------------------------------------------------
  ScopeLeave : fermer le niveau de portee courant.
  Les symboles declares dans cette portee restent en table (acces lecture)
  mais scope_sp recule ; les futures recherches ne remonteront plus ici.
  Pour liberer les entrees locales : ClearLocalSymbols.
  -------------------------------------------------------------------------- }
Procedure ScopeLeave;
Begin
  If scope_sp > 1 Then
  Begin
    { Marquer les symboles locaux comme hors portee }
    sym_count := scope_base[scope_sp];
    Dec(scope_sp);
  End
  Else If scope_sp = 1 Then
    Dec(scope_sp);
End;

{ --------------------------------------------------------------------------
  SymEnter : ajouter un symbole dans la table.
  Retourne l'index 1-base ou 0 si la table est pleine.
  -------------------------------------------------------------------------- }
Function SymEnter(Const name : TString; kind : TSymKind;
                  scope : TScope; type_idx : Integer) : Integer;
Begin
  If sym_count >= MAX_SYM Then
  Begin
    ErrorMsg('Table des symboles saturee');
    SymEnter := 0;
    Exit;
  End;
  Inc(sym_count);
  sym_table^[sym_count].name        := name;
  sym_table^[sym_count].kind        := kind;
  sym_table^[sym_count].scope       := scope;
  sym_table^[sym_count].type_idx    := type_idx;
  sym_table^[sym_count].asm_label   := BV_PFX + AsmIdent(name);
  sym_table^[sym_count].bp_offset   := 0;
  sym_table^[sym_count].is_var_par  := False;
  sym_table^[sym_count].const_ival  := 0;
  sym_table^[sym_count].const_sval  := '';
  sym_table^[sym_count].proc_idx    := 0;
  sym_table^[sym_count].fld_offset  := 0;
  sym_table^[sym_count].glob_slot   := -1;
  sym_table^[sym_count].scope_level := scope_sp;
  SymEnter := sym_count;
End;

{ --------------------------------------------------------------------------
  SymFind : chercher un symbole par son nom (casse significative en Oberon).
  Parcourt la table de sym_count vers 1 (dernier declare en premier).
  Retourne l'index ou 0 si non trouve.
  -------------------------------------------------------------------------- }
Function SymFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If sym_table^[i].name = name Then
    Begin
      SymFind := i;
      Exit;
    End;
  SymFind := 0;
End;

{ --------------------------------------------------------------------------
  SymFindLocal : chercher uniquement dans la portee courante.
  La portee courante commence a scope_base[scope_sp]+1.
  -------------------------------------------------------------------------- }
Function SymFindLocal(Const name : TString) : Integer;
Var i    : Integer;
    base : Integer;
Begin
  If scope_sp > 0 Then
    base := scope_base[scope_sp]
  Else
    base := 0;
  For i := sym_count DownTo base + 1 Do
    If sym_table^[i].name = name Then
    Begin
      SymFindLocal := i;
      Exit;
    End;
  SymFindLocal := 0;
End;

{ --------------------------------------------------------------------------
  SymFindInScope : chercher dans une portee donnee (par son niveau 0-based).
  -------------------------------------------------------------------------- }
Function SymFindInScope(Const name : TString; level : Integer) : Integer;
Var i : Integer;
Begin
  For i := sym_count DownTo 1 Do
    If (sym_table^[i].name = name) And (sym_table^[i].scope_level = level) Then
    Begin
      SymFindInScope := i;
      Exit;
    End;
  SymFindInScope := 0;
End;

{ --------------------------------------------------------------------------
  ProcEnter : enregistrer une procedure / fonction dans proc_table.
  Retourne l'index 1-base ou 0 si la table est pleine.
  -------------------------------------------------------------------------- }
Function ProcEnter(Const name : TString; ret_type_idx : Integer;
                   is_export : Boolean) : Integer;
Var pi  : Integer;
    si  : Integer;
Begin
  If proc_count >= MAX_PROC Then
  Begin
    ErrorMsg('Trop de procedures');
    ProcEnter := 0;
    Exit;
  End;
  Inc(proc_count);
  pi := proc_count;
  proc_table^[pi].name         := name;
  proc_table^[pi].ret_type_idx := ret_type_idx;
  proc_table^[pi].param_count  := 0;
  proc_table^[pi].local_size   := 0;
  proc_table^[pi].is_export    := is_export;
  { Construire le label ASM : _BP_<module>_<name> }
  proc_table^[pi].asm_label := BP_PFX + AsmIdent(module_name) + '_' + AsmIdent(name);

  { Enregistrer aussi dans sym_table comme SK_PROC }
  si := SymEnter(name, SK_PROC, SC_GLOBAL, ret_type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].proc_idx  := pi;
    sym_table^[si].asm_label := proc_table^[pi].asm_label;
    sym_table^[si].glob_slot := -1;
  End;
  ProcEnter := pi;
End;

{ --------------------------------------------------------------------------
  ProcFind : chercher une routine BCPL par son nom.
  Retourne l'index dans proc_table ou 0.
  -------------------------------------------------------------------------- }
Function ProcFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := proc_count DownTo 1 Do
    If proc_table^[i].name = name Then
    Begin
      ProcFind := i;
      Exit;
    End;
  ProcFind := 0;
End;

{ --------------------------------------------------------------------------
  ProcAddParam : ajouter un parametre formel a la routine BCPL.
  L'offset BP est calcule (convention near) :
    BP+4 = premier parametre, BP+6 = deuxieme, etc.
  -------------------------------------------------------------------------- }
Procedure ProcAddParam(pi : Integer; Const pname : TString;
                       type_idx : Integer; is_var : Boolean);
Var pp  : Integer;
    si  : Integer;
    ofs : Integer;
Begin
  If proc_table^[pi].param_count >= MAX_PARAM Then
  Begin
    ErrorMsg('Trop de parametres pour ' + proc_table^[pi].name);
    Exit;
  End;
  Inc(proc_table^[pi].param_count);
  pp := proc_table^[pi].param_count;
  proc_table^[pi].params[pp].name       := pname;
  proc_table^[pi].params[pp].type_idx   := type_idx;
  proc_table^[pi].params[pp].is_var_par := is_var;
  { Offset BP : BP+4 pour le premier, +2 par parametre supplementaire }
  ofs := 4 + (pp - 1) * 2;
  proc_table^[pi].params[pp].bp_offset  := ofs;

  { Ajouter le parametre aussi dans sym_table (portee locale) }
  si := SymEnter(pname, SK_PARAM, SC_PARAM, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].bp_offset  := ofs;
    sym_table^[si].is_var_par := is_var;
    sym_table^[si].asm_label  := '';
  End;
End;

{ --------------------------------------------------------------------------
  ProcAddLocal : allouer une variable locale dans le cadre de pile courant.
  L'offset BP negatif est calcule et mis a jour dans proc_table^[pi].local_size.
  -------------------------------------------------------------------------- }
Function ProcAddLocal(pi : Integer; Const vname : TString;
                      type_idx : Integer; byte_size : Integer) : Integer;
Var si  : Integer;
    ofs : Integer;
Begin
  { Aligner sur 2 octets }
  If byte_size Mod 2 <> 0 Then Inc(byte_size);
  proc_table^[pi].local_size := proc_table^[pi].local_size + byte_size;
  ofs := -proc_table^[pi].local_size;

  si := SymEnter(vname, SK_LOCAL, SC_LOCAL, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].bp_offset  := ofs;
    sym_table^[si].asm_label  := '';
  End;
  ProcAddLocal := si;
End;

{ --------------------------------------------------------------------------
  ConstEnter : ajouter une constante nommee dans const_table.
  Retourne l'index ou 0 si plein.
  -------------------------------------------------------------------------- }
Function ConstEnter(Const name : TString; type_idx : Integer;
                    ival : LongInt; Const sval : TString;
                    is_real : Boolean; rval : Real) : Integer;
Var ci : Integer;
    si : Integer;
Begin
  If const_count >= MAX_CONST Then
  Begin
    ErrorMsg('Table des constantes saturee');
    ConstEnter := 0;
    Exit;
  End;
  Inc(const_count);
  ci := const_count;
  const_table^[ci].name     := name;
  const_table^[ci].type_idx := type_idx;
  const_table^[ci].ival     := ival;
  const_table^[ci].sval     := sval;
  const_table^[ci].is_real  := is_real;
  const_table^[ci].rval     := rval;

  { Enregistrer aussi dans sym_table }
  si := SymEnter(name, SK_MANIFEST, SC_CONST, type_idx);
  If si > 0 Then
  Begin
    sym_table^[si].const_ival := ival;
    sym_table^[si].const_sval := sval;
  End;
  ConstEnter := ci;
End;

{ --------------------------------------------------------------------------
  ConstFind : chercher une constante par son nom.
  Retourne l'index dans const_table ou 0.
  -------------------------------------------------------------------------- }
Function ConstFind(Const name : TString) : Integer;
Var i : Integer;
Begin
  For i := const_count DownTo 1 Do
    If const_table^[i].name = name Then
    Begin
      ConstFind := i;
      Exit;
    End;
  ConstFind := 0;
End;

{ Forward TODO 24 : TypeName est utilise par SymDumpVerbose }
Function TypeName(ti : Integer) : TString; Forward;

{ --------------------------------------------------------------------------
  SymDumpVerbose : afficher la table des symboles (mode -v -d).
  -------------------------------------------------------------------------- }
Procedure SymDumpVerbose;
Const
  KNames : Array[TSymKind] of String[10] =
    ('NONE', 'MANIFEST', 'GLOBAL', 'STATIC', 'LOCAL', 'PARAM', 'PROC', 'VEC', 'LABEL');
Var i   : Integer;
    ti  : Integer;
Begin
  WriteLn('--- Table des symboles (', sym_count, ' entrees) ---');
  For i := 1 To sym_count Do
  Begin
    ti := sym_table^[i].type_idx;
    Write('  [', i:3, '] ', sym_table^[i].name:-20, ' ',
          KNames[sym_table^[i].kind]:9, '  lv=', sym_table^[i].scope_level);
    If sym_table^[i].asm_label <> '' Then
      Write('  asm=', sym_table^[i].asm_label);
    If sym_table^[i].bp_offset <> 0 Then
      Write('  bp+', sym_table^[i].bp_offset);
    If sym_table^[i].kind = SK_MANIFEST Then
      Write('  val=', sym_table^[i].const_ival);
    If sym_table^[i].kind = SK_GLOBAL Then
      Write('  slot=', sym_table^[i].glob_slot);
    If (sym_table^[i].kind = SK_PROC) And (sym_table^[i].proc_idx > 0) Then
      Write('  proc=', sym_table^[i].proc_idx);
    WriteLn;
  End;
End;

{ ============================================================
  TODO 04 - SYSTEME DE TYPES
  ============================================================ }

{ --------------------------------------------------------------------------
  Constructeurs de types : allouer un descripteur dans type_table.
  -------------------------------------------------------------------------- }

Function TypeNew(k : TTypeKind; bits : Integer) : Integer;
Begin
  If type_count >= MAX_TYPE Then
  Begin
    WriteLn('FATAL : table des types saturee');
    Halt(1);
  End;
  Inc(type_count);
  type_table^[type_count].kind     := k;
  type_table^[type_count].bit_size := bits;
  type_table^[type_count].base_idx := 0;
  type_table^[type_count].arr_len  := 0;
  type_table^[type_count].rec_sym  := 0;
  type_table^[type_count].rec_nfld := 0;
  TypeNew := type_count;
End;

{ Constructeurs de types BCPL (tout renvoie TYP_WORD, BCPL n'a qu'un type) }
Function TypeNewArray(base_idx, len : Integer) : Integer;
Begin TypeNewArray := TYP_WORD; End;

Function TypeNewOpenArray(base_idx : Integer) : Integer;
Begin TypeNewOpenArray := TYP_WORD; End;

Function TypeNewRecord(first_field, nfld : Integer) : Integer;
Begin TypeNewRecord := TYP_WORD; End;

Function TypeNewPointer(base_idx : Integer) : Integer;
Begin TypeNewPointer := TYP_WORD; End;

Function TypeNewProc(ret_idx : Integer) : Integer;
Begin TypeNewProc := TYP_WORD; End;

{ En BCPL tout est un mot 16 bits - taille toujours 16 bits / 2 octets }
Function TypeBitSize(ti : Integer) : Integer;
Begin TypeBitSize := 16; End;

Function TypeByteSize(ti : Integer) : Integer;
Begin TypeByteSize := 2; End;

{ Predicats de type : en BCPL tout est WORD donc toujours "numerique" }
Function TypeIsInteger (ti : Integer) : Boolean; Begin TypeIsInteger  := True; End;
Function TypeIsBoolean (ti : Integer) : Boolean; Begin TypeIsBoolean  := False; End;
Function TypeIsChar    (ti : Integer) : Boolean; Begin TypeIsChar     := False; End;
Function TypeIsReal    (ti : Integer) : Boolean; Begin TypeIsReal     := False; End;
Function TypeIsSet     (ti : Integer) : Boolean; Begin TypeIsSet      := False; End;
Function TypeIsPointer (ti : Integer) : Boolean; Begin TypeIsPointer  := False; End;
Function TypeIsRecord  (ti : Integer) : Boolean; Begin TypeIsRecord   := False; End;
Function TypeIsArray   (ti : Integer) : Boolean; Begin TypeIsArray    := False; End;
Function TypeIsOrdinal (ti : Integer) : Boolean; Begin TypeIsOrdinal  := True;  End;
Function TypeIsNumeric (ti : Integer) : Boolean; Begin TypeIsNumeric  := True;  End;
Function TypeIsString  (ti : Integer) : Boolean; Begin TypeIsString   := False; End;

{ En BCPL tout est compatible avec tout }
Function TypeCompat(t1, t2 : Integer) : Boolean;
Begin TypeCompat := True; End;

Function TypeAssignCompat(t1, t2 : Integer) : Boolean;
Begin TypeAssignCompat := True; End;
{ --------------------------------------------------------------------------
  TypeName : retourner une representation lisible du type (debug/erreurs).
  En BCPL il n'y a que deux types : WORD et STRING.
  -------------------------------------------------------------------------- }
Function TypeName(ti : Integer) : TString;
Const
  KStr : Array[TTypeKind] of String[10] = ('WORD', 'STRING');
Begin
  If (ti < 1) Or (ti > type_count) Then
  Begin
    TypeName := 'WORD';  { par defaut en BCPL }
    Exit;
  End;
  TypeName := KStr[type_table^[ti].kind];
End;

{ --------------------------------------------------------------------------
  TypeCheckCompat : verifier la compatibilite et signaler une erreur si non.
  -------------------------------------------------------------------------- }
Procedure TypeCheckCompat(t1, t2 : Integer; Const ctx : TString);
Begin
  If Not TypeCompat(t1, t2) Then
    ErrorMsg('Types incompatibles dans ' + ctx
             + ' (' + TypeName(t1) + ' vs ' + TypeName(t2) + ')');
End;

Procedure TypeCheckAssign(t1, t2 : Integer);
Begin
  If Not TypeAssignCompat(t1, t2) Then
    ErrorMsg('Affectation incompatible : ' + TypeName(t2)
             + ' vers ' + TypeName(t1));
End;

{ --------------------------------------------------------------------------
  TypeDump : afficher tous les descripteurs de type (mode -v -d).
  -------------------------------------------------------------------------- }
Procedure TypeDump;
Var i : Integer;
Begin
  WriteLn('--- Table des types (', type_count, ' entrees) ---');
  For i := 1 To type_count Do
  Begin
    WriteLn('  [', i:3, '] ', TypeName(i):30,
            '  bits=', TypeBitSize(i));
  End;
End;

{ ============================================================
  Initialisation et liberation des tables
  ============================================================ }

Procedure InitTables;
Begin
  New(sym_table);
  New(type_table);
  New(proc_table);
  New(const_table);
  sym_count    := 0;
  type_count   := 0;
  proc_count   := 0;
  const_count  := 0;
  label_count  := 0;
  err_count    := 0;
  warn_count   := 0;
  instr_count  := 0;
  str_lit_count := 0;
  tok_count    := 0;
  scope_sp     := 0;
  cur_proc_idx := 0;
  import_count := 0;
  loop_depth   := 0;
  glob_vec_size := 0;
  cur_local_off  := 0;
  valof_depth    := 0;
  has_peek     := False;
  lex_eof      := False;
  module_name  := 'PROGRAM';  { sera ecrase a la lecture de SECTION "nom" }
End;

Procedure FreeTables;
Begin
  Dispose(sym_table);
  Dispose(type_table);
  Dispose(proc_table);
  Dispose(const_table);
End;

{ Types primitifs BCPL - tout est un mot 16 bits }
Procedure InitBcplSystem;
Var si : Integer;
Begin
  { Un seul type reel en BCPL : le mot 16 bits }
  TYP_WORD   := TypeNew(TYK_WORD,   16);
  TYP_STRING := TypeNew(TYK_STRING,  8);

  { Initialiser le vecteur global }
  glob_vec_size := 0;
  FillChar(glob_slots,   SizeOf(glob_slots),   0);
  FillChar(glob_routine, SizeOf(glob_routine),  0);

  { TRUE = -1, FALSE = 0 en BCPL }
  si := SymEnter('TRUE',  SK_MANIFEST, SC_CONST, TYP_WORD);
  sym_table^[si].const_ival := -1;
  si := SymEnter('FALSE', SK_MANIFEST, SC_CONST, TYP_WORD);
  sym_table^[si].const_ival := 0;

  cur_local_off  := 0;
  valof_lbl      := '';
  valof_depth    := 0;
  cur_switch_lbl := '';
End;

{ ============================================================
  Impression de l'usage
  ============================================================ }

Procedure PrintUsage;
Begin
  WriteLn('BCPL86 v', BCPL86_VERSION, ' - Compilateur BCPL -> MASM 8086');
  WriteLn('Usage : BCPL86 source.b [sortie.asm] [options]');
  WriteLn('Options :');
  WriteLn('  -v   mode verbeux (statistiques et symboles)');
  WriteLn('  -d   mode debug   (trace de parsing)');
  WriteLn('  -nr  pas de liaison avec le runtime');
  Halt(1);
End;

{ ============================================================
  Lecture des arguments de la ligne de commande
  ============================================================ }

Procedure ParseArgs;
Var
  i   : Integer;
  arg : TString;
Begin
  src_fname    := '';
  out_fname    := '';
  opt_verbose  := False;
  opt_debug    := False;
  opt_no_rt    := False;

  For i := 1 To ParamCount Do
  Begin
    arg := ParamStr(i);
    If arg = '-v'  Then opt_verbose := True
    Else If arg = '-d'  Then opt_debug   := True
    Else If arg = '-nr' Then opt_no_rt   := True
    Else If arg[1] = '-' Then
    Begin
      WriteLn('Option inconnue : ', arg);
      PrintUsage;
    End
    Else If src_fname = '' Then src_fname := arg
    Else If out_fname = '' Then out_fname := arg
    Else
    Begin
      WriteLn('Argument inattendu : ', arg);
      PrintUsage;
    End;
  End;

  If src_fname = '' Then PrintUsage;

  If out_fname = '' Then
    out_fname := ChangeExtension(src_fname, '.asm');

  tmp_fname := ChangeExtension(src_fname, '.tmp');
  str_fname := ChangeExtension(src_fname, '.str');
End;

{ ============================================================
  TODO 05 - GENERATEUR DE CODE 8086 - PRIMITIVES
  ============================================================ }

Const
  ASM_INDENT = '        ';    { 8 espaces avant les mnemoniques }
  SEP_LINE   = '; ' + '------------------------------------------------------------';

{ --------------------------------------------------------------------------
  Routines de base d'emission vers cur_out.
  -------------------------------------------------------------------------- }

Procedure Emit(Const s : TString);
Begin
  WriteLn(cur_out^, s);
End;

Procedure EmitBlank;
Begin
  WriteLn(cur_out^);
End;

Procedure EmitComment(Const s : TString);
Begin
  WriteLn(cur_out^, '; ', s);
End;

Procedure EmitSep;
Begin
  WriteLn(cur_out^, SEP_LINE);
End;

Procedure EmitLabel(Const lbl : TString);
Begin
  WriteLn(cur_out^, lbl, ':');
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Instructions ASM (8 espaces d'indentation).
  -------------------------------------------------------------------------- }

Procedure EmitI0(Const op : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op);
  Inc(instr_count);
End;

Procedure EmitI1(Const op, a : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a);
  Inc(instr_count);
End;

Procedure EmitI2(Const op, a, b : TString);
Begin
  WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b);
  Inc(instr_count);
End;

{ Instruction avec commentaire fin de ligne }
Procedure EmitIC(Const op, a, b, cmt : TString);
Begin
  If cmt = '' Then
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b)
  Else
    WriteLn(cur_out^, ASM_INDENT, op, '  ', a, ', ', b, '  ; ', cmt);
  Inc(instr_count);
End;

{ --------------------------------------------------------------------------
  Helpers de formatage de labels DATA.
  -------------------------------------------------------------------------- }

Function PadLabel(Const lbl : TString) : TString;
Var s : TString;
    i : Integer;
Begin
  s := lbl;
  For i := Length(s) To 23 Do
    s := s + ' ';
  PadLabel := s;
End;

{ --------------------------------------------------------------------------
  Emission de donnees dans le segment DATA.
  -------------------------------------------------------------------------- }

Procedure EmitDB(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DB      ', v);
End;

Procedure EmitDW(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DW      ', v);
End;

Procedure EmitDD(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'DD      ', v);
End;

{ EmitDup : lbl  DB/DW/DD  n DUP(init)    sz=1->DB  sz=2->DW  sz=4->DD }
Procedure EmitDup(Const lbl : TString; n : Integer;
                  Const init : TString; sz : Integer);
Var dir : TString;
Begin
  Case sz Of
    1 : dir := 'DB';
    4 : dir := 'DD';
  Else
    dir := 'DW';
  End;
  WriteLn(cur_out^, PadLabel(lbl), dir, '      ',
          IntToStr(n), ' DUP(', init, ')');
End;

Procedure EmitEqu(Const lbl, v : TString);
Begin
  WriteLn(cur_out^, PadLabel(lbl), 'EQU     ', v);
End;

{ --------------------------------------------------------------------------
  Gestion des fichiers de sortie (code principal <-> temporaire procedures).
  -------------------------------------------------------------------------- }

Procedure SwitchToTmp;
Begin
  cur_out := @tmp_file;
End;

Procedure SwitchToMain;
Begin
  cur_out := @out_file;
End;

{ Copier tmp_file ligne par ligne dans out_file, puis effacer tmp_file. }
Procedure MergeTmpToMain;
Var line : String[255];
Begin
  SwitchToMain;
  Close(tmp_file);
  Assign(tmp_file, tmp_fname);
  Reset(tmp_file);
  While Not Eof(tmp_file) Do
  Begin
    ReadLn(tmp_file, line);
    WriteLn(out_file, line);
  End;
  Close(tmp_file);
  Erase(tmp_file);
End;

{ --------------------------------------------------------------------------
  En-tete du fichier ASM genere (commentaire, modele, pile).
  -------------------------------------------------------------------------- }

Procedure GenFileHeader;
Begin
  EmitSep;
  EmitComment(' Fichier genere par BCPL86 v' + BCPL86_VERSION);
  EmitComment(' Date   : ' + BCPL86_DATE);
  EmitComment(' Source : ' + src_fname);
  EmitComment(' Section: ' + module_name);
  EmitComment(' Cible  : MASM 8086, modele SMALL, convention BCPL');
  EmitSep;
  EmitBlank;
End;

Procedure GenModelDirectives;
Begin
  Emit('        .MODEL  SMALL');
  Emit('        .8086');
  EmitBlank;
End;

Procedure GenStackSegment;
Begin
  EmitComment(' ----- Segment STACK -----');
  Emit('_STACK          SEGMENT PARA STACK ''STACK''');
  Emit('                DB      ' + IntToStr(STACK_SIZE) + ' DUP (?)');
  Emit('_STACK          ENDS');
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Segments DATA : ouverture, variables systeme Oberon, fermeture.
  -------------------------------------------------------------------------- }

Procedure GenDataHeader;
Begin
  EmitComment(' ----- Segment DATA -----');
  Emit('_DATA           SEGMENT WORD PUBLIC ''DATA''');
  EmitBlank;
End;

Procedure GenDataFooter;
Begin
  EmitBlank;
  Emit('_DATA           ENDS');
  EmitBlank;
End;

{ Variables systeme emises avant les variables utilisateur. }
Procedure GenSystemVarsData;
Begin
  EmitComment(' ----- Variables systeme BCPL86 -----');
  EmitDup('_BV_OUTBUF',  256, '0', 1);  { buffer sortie WRITES/WRITEF     }
  EmitDup('_BV_INBUF',   128, '0', 1);  { buffer entree READN/READS       }
  EmitDup('_BV_INTBUF',   12, '0', 1);  { buffer conversion entier        }
  EmitDB ('_BV_CRLF',  '0Dh, 0Ah, ''$''');
  EmitDB ('_BV_TMPCH', '0, 0');          { stockage temporaire caractere   }
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Segment CODE : ouverture, point d'entree START, fermeture.
  -------------------------------------------------------------------------- }

Procedure GenCodeHeader;
Begin
  EmitComment(' ----- Segment CODE -----');
  Emit('_CODE           SEGMENT WORD PUBLIC ''CODE''');
  EmitBlank;
  Emit('                ASSUME CS:_CODE, DS:_DATA, SS:_STACK');
  EmitBlank;
End;

Procedure GenCodeFooter;
Begin
  EmitBlank;
  Emit('_CODE           ENDS');
  EmitBlank;
End;

{ Prologue du point d'entree BCPL START : init DS, BX = base vecteur global. }
Procedure GenStartEntry;
Begin
  EmitComment(' Point d''entree BCPL : init DS, vecteur global, appel G!1 (main)');
  EmitLabel('START');
  EmitI2('MOV', 'AX', '_DATA');
  EmitI2('MOV', 'DS', 'AX');
  { BX = adresse du vecteur global _BG_ (preservee dans toutes les routines) }
  EmitI2('LEA', 'BX', '[' + BG_NAME + ']');
  EmitBlank;
End;

{ Epilogue du point d'entree START (appele apres la derniere instruction). }
Procedure GenStartExit;
Begin
  EmitBlank;
  EmitComment(' Fin normale du programme');
  EmitI2('MOV', 'AX', '4C00h');
  EmitI0('INT  21h');
  EmitBlank;
End;

{ Directive END avec point d'entree. }
Procedure GenEndDirective;
Begin
  Emit('                END     START');
End;

{ --------------------------------------------------------------------------
  Prologue / epilogue de procedure (near, convention cdecl).
  -------------------------------------------------------------------------- }

{ Prologue : PUSH BP / MOV BP,SP / SUB SP,local_size / PUSH SI DI BX }
Procedure GenProcPrologue(pi : Integer);
Begin
  EmitLabel(proc_table^[pi].asm_label);
  EmitI1('PUSH', 'BP');
  EmitI2('MOV',  'BP', 'SP');
  If proc_table^[pi].local_size > 0 Then
    EmitI2('SUB', 'SP', IntToStr(proc_table^[pi].local_size));
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitI1('PUSH', 'BX');
  EmitBlank;
End;

{ Epilogue : POP BX DI SI / MOV SP,BP / POP BP / RET }
Procedure GenProcEpilogue(pi : Integer);
Begin
  EmitBlank;
  EmitI1('POP', 'BX');
  EmitI1('POP', 'DI');
  EmitI1('POP', 'SI');
  EmitI2('MOV', 'SP', 'BP');
  EmitI1('POP', 'BP');
  EmitI0('RET');
  EmitBlank;
  { Marque de fin de procedure }
  EmitComment(' END ' + proc_table^[pi].name);
  EmitBlank;
End;

{ --------------------------------------------------------------------------
  Chargement / stockage de variables dans AX selon leur portee.
  Ces helpers seront appeles par les parseurs d'expression (TODO 09+).
  -------------------------------------------------------------------------- }

{ Charger une variable globale (sym_table[si]) dans AX (ou DX:AX si 32 bits). }
Procedure GenLoadVar(si : Integer);
Var lbl  : TString;
    bits : Integer;
Begin
  lbl  := sym_table^[si].asm_label;
  bits := TypeBitSize(sym_table^[si].type_idx);
  Case bits Of
     8 : Begin EmitI2('MOV', 'AL', '[' + lbl + ']'); EmitI0('CBW'); End;
    32 : Begin
           EmitI2('MOV', 'AX', '[' + lbl + ']');
           EmitI2('MOV', 'DX', '[' + lbl + '+2]');
         End;
  Else
    EmitI2('MOV', 'AX', '[' + lbl + ']');
  End;
End;

{ Charger une variable locale / parametre (offset BP) dans AX. }
Procedure GenLoadLocal(si : Integer);
Var ofs  : Integer;
    bits : Integer;
    ref  : TString;
Begin
  ofs  := sym_table^[si].bp_offset;
  bits := TypeBitSize(sym_table^[si].type_idx);
  If ofs >= 0 Then
    ref := '[BP+' + IntToStr(ofs) + ']'
  Else
    ref := '[BP-' + IntToStr(-ofs) + ']';

  If sym_table^[si].is_var_par Then
  Begin
    { Parametre VAR : charger l'adresse puis deref }
    EmitI2('MOV', 'BX', ref);
    Case bits Of
       8 : Begin EmitI2('MOV', 'AL', '[BX]'); EmitI0('CBW'); End;
      32 : Begin EmitI2('MOV', 'AX', '[BX]'); EmitI2('MOV', 'DX', '[BX+2]'); End;
    Else
      EmitI2('MOV', 'AX', '[BX]');
    End;
  End
  Else
  Begin
    Case bits Of
       8 : Begin EmitI2('MOV', 'AL', ref); EmitI0('CBW'); End;
      32 : Begin
             EmitI2('MOV', 'AX', ref);
             If ofs >= 0 Then
               EmitI2('MOV', 'DX', '[BP+' + IntToStr(ofs + 2) + ']')
             Else
               EmitI2('MOV', 'DX', '[BP-' + IntToStr(-(ofs + 2)) + ']');
           End;
    Else
      EmitI2('MOV', 'AX', ref);
    End;
  End;
End;

{ Stocker AX dans une variable globale. }
Procedure GenStoreVar(si : Integer);
Var lbl  : TString;
    bits : Integer;
Begin
  lbl  := sym_table^[si].asm_label;
  bits := TypeBitSize(sym_table^[si].type_idx);
  Case bits Of
     8 : EmitI2('MOV', '[' + lbl + ']', 'AL');
    32 : Begin
           EmitI2('MOV', '[' + lbl + ']',     'AX');
           EmitI2('MOV', '[' + lbl + '+2]',   'DX');
         End;
  Else
    EmitI2('MOV', '[' + lbl + ']', 'AX');
  End;
End;

{ Stocker AX dans une variable locale / parametre. }
Procedure GenStoreLocal(si : Integer);
Var ofs  : Integer;
    bits : Integer;
    ref  : TString;
Begin
  ofs  := sym_table^[si].bp_offset;
  bits := TypeBitSize(sym_table^[si].type_idx);
  If ofs >= 0 Then
    ref := '[BP+' + IntToStr(ofs) + ']'
  Else
    ref := '[BP-' + IntToStr(-ofs) + ']';

  If sym_table^[si].is_var_par Then
  Begin
    EmitI2('MOV', 'BX', ref);
    Case bits Of
       8 : EmitI2('MOV', '[BX]', 'AL');
      32 : Begin EmitI2('MOV', '[BX]', 'AX'); EmitI2('MOV', '[BX+2]', 'DX'); End;
    Else
      EmitI2('MOV', '[BX]', 'AX');
    End;
  End
  Else
  Begin
    Case bits Of
       8 : EmitI2('MOV', ref, 'AL');
      32 : Begin
             EmitI2('MOV', ref, 'AX');
             If ofs >= 0 Then
               EmitI2('MOV', '[BP+' + IntToStr(ofs + 2) + ']', 'DX')
             Else
               EmitI2('MOV', '[BP-' + IntToStr(-(ofs + 2)) + ']', 'DX');
           End;
    Else
      EmitI2('MOV', ref, 'AX');
    End;
  End;
End;

{ Dispatcher : charger / stocker selon la portee du symbole. }
Procedure GenLoad(si : Integer);
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    GenLoadVar(si)
  Else
    GenLoadLocal(si);
End;

Procedure GenStore(si : Integer);
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    GenStoreVar(si)
  Else
    GenStoreLocal(si);
End;

{ ==========================================================================
  TODO 21 - TABLEAUX ET ENREGISTREMENTS
  ========================================================================== }

{ --------------------------------------------------------------------------
  GenStructCopy : copier n_bytes octets de SI (source) vers DI (dest).
  Utilise REP MOVSW, puis MOVSB si le compte est impair.
  SI et DI doivent etre charges par l'appelant avant cet appel.
  -------------------------------------------------------------------------- }
Procedure GenStructCopy(n_bytes : Integer);
Var w : Integer;
    r : Integer;
Begin
  If n_bytes <= 0 Then Exit;
  w := n_bytes Div 2;
  r := n_bytes Mod 2;
  If w > 0 Then
  Begin
    EmitI2('MOV', 'CX', IntToStr(w));
    EmitI0('REP  MOVSW');
  End;
  If r = 1 Then
    EmitI0('MOVSB');
End;

{ ============================================================
  TODO 06 - DECLARATIONS DE CONSTANTES (CONST)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseConstExprInt : evaluer une expression constante entiere/booleenne
  au compile-time.
  Grammaire simplifiee :
    expr  = signe? terme ( op_add terme )*
    terme = fac ( op_mul fac )*
    fac   = entier | ident_const | TRUE | FALSE | '(' expr ')'
  Retourne la valeur entiere. Pour les booleens : 0=FALSE, 1=TRUE.
  -------------------------------------------------------------------------- }
Function ParseConstExprInt : LongInt; Forward;

Function ParseConstExprPrimary : LongInt;
Var ci : Integer;
    v  : LongInt;
    si : Integer;
Begin
  { Signe unaire }
  If cur_tok.val = '-' Then
  Begin
    LexNext;
    ParseConstExprPrimary := -ParseConstExprPrimary;
    Exit;
  End;
  If cur_tok.val = '+' Then
  Begin
    LexNext;
    ParseConstExprPrimary := ParseConstExprPrimary;
    Exit;
  End;
  If cur_tok.val = 'NOT' Then
  Begin
    LexNext;
    v := ParseConstExprPrimary;
    If v = 0 Then ParseConstExprPrimary := 1
    Else           ParseConstExprPrimary := 0;
    Exit;
  End;

  { Parentheses }
  If cur_tok.val = '(' Then
  Begin
    LexNext;
    v := ParseConstExprInt;
    LexExpect(')');
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteral entier }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    v := cur_tok.int_val;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteral caractere  nnnX }
  If cur_tok.kind = TK_CHAR Then
  Begin
    v := cur_tok.int_val;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  { Litteraux booleens }
  If cur_tok.val = 'TRUE' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 1;
    Exit;
  End;
  If cur_tok.val = 'FALSE' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 0;
    Exit;
  End;

  { NIL -> 0 }
  If cur_tok.val = 'NIL' Then
  Begin
    LexNext;
    ParseConstExprPrimary := 0;
    Exit;
  End;

  { Identificateur = constante nommee }
  If cur_tok.kind = TK_IDENT Then
  Begin
    ci := ConstFind(cur_tok.val);
    If ci > 0 Then
      v := const_table^[ci].ival
    Else
    Begin
      { Chercher dans sym_table }
      si := SymFind(cur_tok.val);
      If (si > 0) And (sym_table^[si].kind = SK_MANIFEST) Then
        v := sym_table^[si].const_ival
      Else
      Begin
        ErrorMsg('Constante inconnue : ' + cur_tok.val);
        v := 0;
      End;
    End;
    LexNext;
    ParseConstExprPrimary := v;
    Exit;
  End;

  ErrorMsg('Expression constante attendue, lu : ' + cur_tok.val);
  LexNext;
  ParseConstExprPrimary := 0;
End;

Function ParseConstExprFactor : LongInt;
Var v, r : LongInt;
Begin
  v := ParseConstExprPrimary;
  While (cur_tok.val = '*') Or (cur_tok.val = 'DIV')
     Or (cur_tok.val = 'MOD') Or (cur_tok.val = 'AND') Do
  Begin
    If cur_tok.val = '*' Then
    Begin
      LexNext; r := ParseConstExprPrimary; v := v * r;
    End
    Else If cur_tok.val = 'DIV' Then
    Begin
      LexNext; r := ParseConstExprPrimary;
      If r <> 0 Then v := v Div r Else Begin ErrorMsg('Division par zero'); v := 0; End;
    End
    Else If cur_tok.val = 'MOD' Then
    Begin
      LexNext; r := ParseConstExprPrimary;
      If r <> 0 Then v := v Mod r Else Begin ErrorMsg('Modulo par zero'); v := 0; End;
    End
    Else { AND }
    Begin
      LexNext; r := ParseConstExprPrimary;
      v := v And r;
    End;
  End;
  ParseConstExprFactor := v;
End;

Function ParseConstExprInt : LongInt;
Var v, r : LongInt;
Begin
  v := ParseConstExprFactor;
  While (cur_tok.val = '+') Or (cur_tok.val = '-') Or (cur_tok.val = 'OR') Do
  Begin
    If cur_tok.val = '+' Then
    Begin
      LexNext; r := ParseConstExprFactor; v := v + r;
    End
    Else If cur_tok.val = '-' Then
    Begin
      LexNext; r := ParseConstExprFactor; v := v - r;
    End
    Else { OR }
    Begin
      LexNext; r := ParseConstExprFactor; v := v Or r;
    End;
  End;
  ParseConstExprInt := v;
End;

{ --------------------------------------------------------------------------
  ParseConstExprReal : evaluer une expression constante reelle.
  Retourne un Real. Si l'expression est entiere, la convertit.
  -------------------------------------------------------------------------- }
Function ParseConstExprReal : Real;
Var r  : Real;
    ci : Integer;
    err: Integer;
Begin
  { Signe unaire }
  If cur_tok.val = '-' Then
  Begin
    LexNext;
    ParseConstExprReal := -ParseConstExprReal;
    Exit;
  End;
  If cur_tok.val = '+' Then
  Begin
    LexNext;
    ParseConstExprReal := ParseConstExprReal;
    Exit;
  End;

  If cur_tok.kind = TK_REAL Then
  Begin
    Val(cur_tok.val, r, err);
    If err <> 0 Then r := 0.0;
    LexNext;
    ParseConstExprReal := r;
    Exit;
  End;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    r := cur_tok.int_val;
    LexNext;
    ParseConstExprReal := r;
    Exit;
  End;

  { Constante nommee reelle }
  If cur_tok.kind = TK_IDENT Then
  Begin
    ci := ConstFind(cur_tok.val);
    If (ci > 0) And const_table^[ci].is_real Then
    Begin
      r := const_table^[ci].rval;
      LexNext;
      ParseConstExprReal := r;
      Exit;
    End;
    { Retomber sur l'entier }
    ParseConstExprReal := ParseConstExprInt;
    Exit;
  End;

  ParseConstExprReal := ParseConstExprInt;
End;

{ --------------------------------------------------------------------------
  GenStringLitData : emettre un litteral de chaine en DATA.
  Retourne le label ASM genere (_OK_nnn).
  -------------------------------------------------------------------------- }
Function GenStringLitData(Const s : TString) : TString;
Var lbl      : TString;
    i        : Integer;
    out_s    : TString;
    c        : Char;
    save_out : TTextPtr;
    in_quote : Boolean;
    tmp_n    : TString;
Begin
  Inc(str_lit_count);
  Str(str_lit_count, lbl);
  lbl := BK_PFX + lbl;

  { Construire la valeur DB : blocs 'texte' + octets decimaux + terminateur 0 }
  out_s    := '';
  in_quote := False;
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (Ord(c) >= 32) And (c <> '''') Then
    Begin
      { Caractere imprimable (hors apostrophe) : ouvrir bloc si necessaire }
      If Not in_quote Then
      Begin
        If out_s <> '' Then out_s := out_s + ', ';
        out_s    := out_s + '''';
        in_quote := True;
      End;
      out_s := out_s + c;
    End
    Else
    Begin
      { Caractere special ou apostrophe : fermer bloc et emettre en decimal }
      If in_quote Then
      Begin
        out_s    := out_s + '''';
        in_quote := False;
      End;
      If out_s <> '' Then out_s := out_s + ', ';
      Str(Ord(c), tmp_n);
      out_s := out_s + tmp_n + 'd';
    End;
  End;
  { Fermer le bloc ouvert et ajouter terminateur nul }
  If in_quote Then
    out_s := out_s + '''';
  If out_s = '' Then
    out_s := '0'
  Else
    out_s := out_s + ', 0';

  { Emettre dans str_file (fusionne dans _DATA apres le CODE) }
  save_out := cur_out;
  cur_out  := @str_file;
  EmitDB(lbl, out_s);
  cur_out  := save_out;
  GenStringLitData := lbl;
End;

{ --------------------------------------------------------------------------
  ParseConstDecl : en BCPL ce n'est pas utilise directement (use ParseManifestSection).
  Stub maintenu pour compatibilite avec les appels restants.
  -------------------------------------------------------------------------- }
Procedure ParseConstDecl;
Var
  cname : TString;
  ival  : LongInt;
Begin
  cname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect('=');
  ival := ParseConstExprInt;
  If SymFindLocal(cname) > 0 Then
    ErrorMsg('Manifest deja declare : ' + cname);
  ConstEnter(cname, TYP_WORD, ival, '', False, 0.0);
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseConstSection : parser la section CONST ident = expr ;
  -------------------------------------------------------------------------- }
{ ============================================================
  TODO 06 - DECLARATIONS MANIFEST ET CONSTANTES BCPL
  ============================================================ }

{ --------------------------------------------------------------------------
  OpenBlock / CloseBlock : consommer $( et $) (delimiteurs de blocs BCPL)
  En BCPL les blocs sont delimites par  $( ... $)
  -------------------------------------------------------------------------- }
Procedure OpenBlock;
Begin
  If (cur_tok.val = '$(') Or (cur_tok.val = '{') Then
    LexNext
  Else
    ErrorMsg('Debut de bloc BCPL (''$('') attendu, lu : ' + cur_tok.val);
End;

Procedure CloseBlock;
Begin
  If (cur_tok.val = '$)') Or (cur_tok.val = '}') Then
    LexNext
  Else
    ErrorMsg('Fin de bloc BCPL (''$)'') attendue, lu : ' + cur_tok.val);
End;

{ --------------------------------------------------------------------------
  ParseManifestSection : MANIFEST $( name = expr [;] ... $)
  Les constantes MANIFEST sont evaluees au compile-time (entiers uniquement).

  En BCPL : MANIFEST $( name = expr ; name = expr ; ... $)
             ou        { name = expr ; ... }
  -------------------------------------------------------------------------- }
Procedure ParseManifestSection;
Var name : TString;
    val  : LongInt;
    si   : Integer;
Begin
  LexExpect('MANIFEST');
  OpenBlock;
  While (cur_tok.val <> '$)') And (cur_tok.val <> '}') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identifiant attendu dans MANIFEST, lu : ' + cur_tok.val);
      LexNext;
      Break;
    End;
    name := cur_tok.val;  LexNext;
    LexExpect('=');
    val := ParseConstExprInt;
    If SymFindLocal(name) > 0 Then
      WarnMsg('MANIFEST deja declare dans cette portee : ' + name);
    si := SymEnter(name, SK_MANIFEST, SC_CONST, TYP_WORD);
    If si > 0 Then
      sym_table^[si].const_ival := val;
    If opt_debug Then
      WriteLn('MANIFEST ', name, ' = ', val);
    If cur_tok.val = ';' Then LexNext;
  End;
  CloseBlock;
End;

{ --------------------------------------------------------------------------
  ParseGlobalSection : GLOBAL $( name : slot [;] ... $)
  Associe chaque nom a un slot dans le vecteur global  G!slot.
  L'acces a l'execution : [BX + slot*2]  (BX pointe sur _BG_).
  -------------------------------------------------------------------------- }
Procedure ParseGlobalSection;
Var name : TString;
    slot : LongInt;
    si   : Integer;
Begin
  LexExpect('GLOBAL');
  OpenBlock;
  While (cur_tok.val <> '$)') And (cur_tok.val <> '}') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identifiant attendu dans GLOBAL, lu : ' + cur_tok.val);
      LexNext;
      Break;
    End;
    name := cur_tok.val;  LexNext;
    LexExpect(':');
    slot := ParseConstExprInt;
    If slot < 0 Then slot := 0;
    If slot >= MAX_GLOBAL Then
    Begin
      ErrorMsg('Slot global trop grand (max ' + IntToStr(MAX_GLOBAL-1) + ')');
      slot := MAX_GLOBAL - 1;
    End;
    si := SymEnter(name, SK_GLOBAL, SC_GLOBAL, TYP_WORD);
    If si > 0 Then
    Begin
      sym_table^[si].glob_slot  := slot;
      sym_table^[si].asm_label  := BG_NAME;   { acces via [BX+2*slot] }
      glob_slots[slot] := si;
      If slot > glob_vec_size Then glob_vec_size := slot;
    End;
    If opt_debug Then
      WriteLn('GLOBAL ', name, ' : slot ', slot);
    If cur_tok.val = ';' Then LexNext;
  End;
  CloseBlock;
End;

{ --------------------------------------------------------------------------
  ParseStaticSection : STATIC $( name = valeur [;] ... $)
  Variables statiques initialisees emises dans le segment DATA.
  -------------------------------------------------------------------------- }
Procedure ParseStaticSection;
Var name : TString;
    val  : LongInt;
    si   : Integer;
    lbl  : TString;
Begin
  LexExpect('STATIC');
  OpenBlock;
  While (cur_tok.val <> '$)') And (cur_tok.val <> '}') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If cur_tok.kind <> TK_IDENT Then
    Begin
      ErrorMsg('Identifiant attendu dans STATIC, lu : ' + cur_tok.val);
      LexNext;
      Break;
    End;
    name := cur_tok.val;  LexNext;
    LexExpect('=');
    val  := ParseConstExprInt;
    lbl  := BV_PFX + AsmIdent(name);
    si := SymEnter(name, SK_STATIC, SC_GLOBAL, TYP_WORD);
    If si > 0 Then
    Begin
      sym_table^[si].asm_label  := lbl;
      sym_table^[si].const_ival := val;
    End;
    { Emettre dans le segment DATA (cur_out doit pointer sur DATA ou tmp a fusionner) }
    EmitDW(lbl, IntToStr(val));
    If opt_debug Then
      WriteLn('STATIC ', name, ' = ', val);
    If cur_tok.val = ';' Then LexNext;
  End;
  CloseBlock;
End;

{ ============================================================
  TODO 07 - DECLARATIONS LET ET TYPES (BCPL N'A PAS DE TYPES)
  *** La section TYPE de Modula-2 n'existe pas en BCPL ***
  *** Les declarations LET sont traitees dans TODO 16.  ***
  ============================================================ }

{ ParseTypeSection n'existe pas en BCPL.                         }
{ Placeholder vide pour compatibilite avec les appels existants. }
Function ParseTypeRef : Integer; Forward;

{ --------------------------------------------------------------------------
  ParseArrayType : ARRAY constExpr OF typeRef
  -------------------------------------------------------------------------- }
Function ParseArrayType : Integer;
Var len : LongInt;
    base: Integer;
Begin
  LexExpect('ARRAY');
  len  := ParseConstExprInt;
  LexExpect('OF');
  base := ParseTypeRef;
  ParseArrayType := TypeNewArray(base, len);
End;

{ --------------------------------------------------------------------------
  ParseRecordType : RECORD ident-list : typeRef ; ... END
  Chaque champ est inscrit dans sym_table comme SK_FIELD avec son offset.
  -------------------------------------------------------------------------- }
Function ParseRecordType : Integer;
Var first_fld : Integer;
    nfld      : Integer;
    off       : Integer;
    fti       : Integer;
    si        : Integer;
    names     : Array[1..MAX_FIELD] of TString;
    nnames    : Integer;
    k         : Integer;
Begin
  LexExpect('RECORD');
  first_fld := sym_count + 1;
  nfld      := 0;
  off       := 0;
  While (cur_tok.kind = TK_IDENT) Do
  Begin
    { Collecter les noms de champs : ident, ident, ... }
    nnames      := 1;
    names[1]    := cur_tok.val;
    LexNext;
    While cur_tok.val = ',' Do
    Begin
      LexNext;
      If nnames < MAX_FIELD Then
      Begin
        Inc(nnames);
        names[nnames] := cur_tok.val;
      End;
      LexExpectKind(TK_IDENT);
    End;
    LexExpect(':');
    fti := ParseTypeRef;
    { Inscrire chaque champ dans sym_table }
    For k := 1 To nnames Do
    Begin
      si := SymEnter(names[k], SK_FIELD, SC_GLOBAL, fti);
      If si > 0 Then
      Begin
        sym_table^[si].fld_offset := off;
        Inc(off, TypeByteSize(fti));
        Inc(nfld);
      End;
    End;
    { Separateur ; optionnel entre groupes de champs }
    If cur_tok.val = ';' Then
      LexNext
    Else If cur_tok.val <> 'END' Then
      ErrorMsg('Point-virgule ou END attendu dans RECORD');
  End;
  LexExpect('END');
  ParseRecordType := TypeNewRecord(first_fld, nfld);
End;

{ --------------------------------------------------------------------------
  ParsePointerType : POINTER TO typeRef
  -------------------------------------------------------------------------- }
Function ParsePointerType : Integer;
Var base : Integer;
Begin
  LexExpect('POINTER');
  LexExpect('TO');
  base := ParseTypeRef;
  ParsePointerType := TypeNewPointer(base);
End;

{ --------------------------------------------------------------------------
  ParseProcType : PROCEDURE [ ( params ) ] [ : typeRef ]
  Simplifie : on capture le type de retour ; le detail des parametres
  formels sera gere en TODO 17 (on saute les parentheses ici).
  -------------------------------------------------------------------------- }
Function ParseProcType : Integer;
Var ret_ti : Integer;
    depth  : Integer;
Begin
  LexExpect('PROCEDURE');
  ret_ti := 0;
  { Sauter les parametres entre parentheses - sera traite en TODO 17 }
  If cur_tok.val = '(' Then
  Begin
    depth := 1;
    LexNext;   { consomme '(' }
    While (depth > 0) And (cur_tok.kind <> TK_EOF) Do
    Begin
      If cur_tok.val = '(' Then Inc(depth)
      Else If cur_tok.val = ')' Then Dec(depth);
      LexNext;
    End;
    { apres la boucle, '(' final vient d'etre consomme par le dernier LexNext }
  End;
  { Type de retour facultatif }
  If cur_tok.val = ':' Then
  Begin
    LexNext;
    ret_ti := ParseTypeRef;
  End;
  ParseProcType := TypeNewProc(ret_ti);
End;

{ --------------------------------------------------------------------------
  ParseTypeRef : parser une designation de type Oberon.
  Retourne l'index dans type_table.
    ident              -> alias de type (SK_TYPE dans sym_table)
    ARRAY  n OF T      -> ParseArrayType
    RECORD ... END     -> ParseRecordType
    POINTER TO T       -> ParsePointerType
    PROCEDURE [(.)] :T -> ParseProcType
  -------------------------------------------------------------------------- }
Function ParseTypeRef;
Var tok : TString;
    si  : Integer;
Begin
  tok := cur_tok.val;
  If tok = 'ARRAY' Then
    ParseTypeRef := ParseArrayType
  Else If tok = 'RECORD' Then
    ParseTypeRef := ParseRecordType
  Else If tok = 'POINTER' Then
    ParseTypeRef := ParsePointerType
  Else If tok = 'PROCEDURE' Then
    ParseTypeRef := ParseProcType
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    LexNext;   { consommer le nom }
    si := SymFind(tok);
    If (si > 0) And (sym_table^[si].kind = SK_TYPE) Then
      ParseTypeRef := sym_table^[si].type_idx
    Else
    Begin
      ErrorMsg('Type inconnu : ' + tok);
      ParseTypeRef := TYP_WORD;
    End;
  End
  Else
  Begin
    ErrorMsg('Designation de type attendue, obtenu : ' + cur_tok.val);
    LexNext;
    ParseTypeRef := TYP_WORD;
  End;
End;

{ --------------------------------------------------------------------------
  ParseTypeDecl : ident = typeRef ;
  Cree un alias de type et l'inscrit comme SK_TYPE dans sym_table.
  -------------------------------------------------------------------------- }
Procedure ParseTypeDecl;
Var tname : TString;
    ti    : Integer;
    si    : Integer;
Begin
  tname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect('=');
  ti := ParseTypeRef;
  If SymFindLocal(tname) > 0 Then
    WarnMsg('Type deja declare dans cette portee : ' + tname);
  si := SymEnter(tname, SK_TYPE, SC_GLOBAL, ti);
  If si > 0 Then
    sym_table^[si].asm_label := '';   { les types n'ont pas de label ASM }
  LexExpect(';');
End;

{ --------------------------------------------------------------------------
  ParseTypeSection : TYPE ident = typeRef ; ...
  -------------------------------------------------------------------------- }
Procedure ParseTypeSection;
Begin
  LexExpect('TYPE');
  While (cur_tok.kind = TK_IDENT) Do
    ParseTypeDecl;
End;

{ ============================================================
  TODO 08 - VARIABLES LOCALES LET (BCPL)
  ============================================================ }

{ --------------------------------------------------------------------------
  GenGlobalVarData : emettre la reserve DATA pour une variable statique BCPL.
  -------------------------------------------------------------------------- }
Procedure GenGlobalVarData(si : Integer);
Var lbl : TString;
Begin
  lbl := sym_table^[si].asm_label;
  { En BCPL tout est un mot 16 bits }
  EmitDW(lbl, '0');
End;

{ --------------------------------------------------------------------------
  ParseVarDecl : en BCPL les variables locales sont declarees avec LET.
  Cette procedure adapte ParseVarDecl pour LET name = expr (TODO 16).
  is_local=True -> variable locale (BP-n) ; is_local=False -> STATIC (.DATA)
  -------------------------------------------------------------------------- }
Procedure ParseVarDecl(is_local : Boolean; Var local_off : Integer);
Var vname : TString;
    si    : Integer;
Begin
  { BCPL : LET name = expr (syntaxe: on arrive apres avoir lu le nom) }
  vname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  { Allouer sur la pile ou en DATA }
  If is_local Then
  Begin
    Dec(local_off, 2);   { mot 16 bits }
    si := SymEnter(vname, SK_LOCAL, SC_LOCAL, TYP_WORD);
    If si > 0 Then
    Begin
      sym_table^[si].bp_offset := local_off;
      sym_table^[si].asm_label := '';
    End;
    { Initialiser la variable : =  expr }
    If cur_tok.val = '=' Then
    Begin
      LexNext;
      { code genere par ParseLetDecl }
    End;
  End
  Else
  Begin
    si := SymEnter(vname, SK_STATIC, SC_GLOBAL, TYP_WORD);
    If si > 0 Then
    Begin
      sym_table^[si].asm_label := BV_PFX + AsmIdent(vname);
      EmitDW(sym_table^[si].asm_label, '0');
    End;
  End;
End;

{ --------------------------------------------------------------------------
  ParseVarSection : en BCPL, cette section est remplacee par LET declarations.
  Appele par compatibilite - ne doit pas etre rencontre dans un source BCPL.
  -------------------------------------------------------------------------- }
Procedure ParseVarSection(is_local : Boolean; Var local_off : Integer);
Begin
  ErrorMsg('VAR n''existe pas en BCPL ; utilisez LET ou GLOBAL');
  { Sauter jusqu''a la prochaine section connue }
  While (cur_tok.kind <> TK_EOF) And
        (cur_tok.val <> 'LET') And (cur_tok.val <> 'MANIFEST') And
        (cur_tok.val <> 'GLOBAL') Do
    LexNext;
End;
End;

{ ============================================================
  TODO 09 - EXPRESSIONS - NIVEAU PRIMAIRE
  ============================================================ }

{ Forward : ParseExpr est defini en TODO 10 ; ParseFactor l'appelle
  pour les sous-expressions entre parentheses et les index de tableau. }
Function ParseExpr : Integer; Forward;

{ Forward : ParseProcCallArgs defini en TODO 18 ; ParseDesignator l'appelle. }
Function ParseProcCallArgs(pi : Integer) : Integer; Forward;

{ Forward : ParseBuiltinFunc defini en TODO 19 ; ParseFactor l'appelle. }
Function ParseBuiltinFunc(Const fname : TString) : Integer; Forward;

{ Forwards supplementaires TODO 19 utilises dans ParseFactor et ParseStatement. }
Function IsBuiltinProc(Const name : TString) : Boolean; Forward;
Function IsBuiltinFunc(Const name : TString) : Boolean; Forward;
Procedure ParseBuiltinProc(Const fname : TString); Forward;

{ Forwards TODO 20 - modules standard Out / In. }
Function  IsStdModuleIdent(Const name : TString) : Boolean; Forward;
Function  ParseStdModuleExpr : Integer; Forward;
Procedure ParseStdModuleCall; Forward;

{ Forwards TODO 23 - clause IMPORT et modules Math / SYSTEM. }
Procedure ParseImportSection; Forward;

{ --------------------------------------------------------------------------
  GenLoadConst : charger une valeur immediate dans AX (ou DX:AX si 32 bits).
  -------------------------------------------------------------------------- }
Procedure GenLoadConst(v : LongInt; ti : Integer);
Begin
  If (ti >= 1) And (ti <= type_count) And (TypeBitSize(ti) = 32) Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(v And $FFFF));
    EmitI2('MOV', 'DX', IntToStr((v Shr 16) And $FFFF));
    Exit;
  End;
  EmitI2('MOV', 'AX', IntToStr(v And $FFFF));
End;

{ --------------------------------------------------------------------------
  GenLoadAddr : charger l'adresse (near ptr) d'un symbole dans BX.
  -------------------------------------------------------------------------- }
Procedure GenLoadAddr(si : Integer);
Var ofs : Integer;
Begin
  If sym_table^[si].scope = SC_GLOBAL Then
    EmitI2('LEA', 'BX', '[' + sym_table^[si].asm_label + ']')
  Else
  Begin
    ofs := sym_table^[si].bp_offset;
    If ofs >= 0 Then
      EmitI2('LEA', 'BX', '[BP+' + IntToStr(ofs) + ']')
    Else
      EmitI2('LEA', 'BX', '[BP-' + IntToStr(-ofs) + ']');
  End;
End;

{ --------------------------------------------------------------------------
  ParseDesignator : ident postfix*
    postfix = '.' ident          (champ de RECORD)
            | '[' expr ']'       (element de tableau)
            | '^'                (dereferencement de pointeur)
  Charge la valeur finale dans AX (ou BX pour les aggregats).
  Retourne le type_idx resultant.
  -------------------------------------------------------------------------- }
Function ParseDesignator : Integer;
Var name       : TString;
    si         : Integer;
    ti         : Integer;
    el_ti      : Integer;
    el_size    : Integer;
    fld_idx    : Integer;
    k          : Integer;
    pi2        : Integer;
    n_a        : Integer;
    addr_in_bx : Boolean;   { True si la valeur courante est une adresse dans BX }
Begin
  name := cur_tok.val;
  LexExpectKind(TK_IDENT);
  si := SymFind(name);
  If si = 0 Then
  Begin
    ErrorMsg('Identifiant inconnu : ' + name);
    ParseDesignator := TYP_WORD;
    Exit;
  End;

  ti := sym_table^[si].type_idx;
  addr_in_bx := False;

  { Charger la valeur ou l'adresse de base selon la nature du symbole }
  Case sym_table^[si].kind Of
    SK_MANIFEST :
      GenLoadConst(sym_table^[si].const_ival, ti);
    SK_TYPE :
      ErrorMsg('Nom de type non valide dans une expression : ' + name);
    SK_PROC :
      Begin
        { Appel de procedure/fonction (TODO 18) }
        pi2 := sym_table^[si].proc_idx;
        If cur_tok.val = '(' Then
        Begin
          n_a := ParseProcCallArgs(pi2);
          EmitI1('CALL', sym_table^[si].asm_label);
          If n_a > 0 Then
            EmitI2('ADD', 'SP', IntToStr(n_a * 2));
        End
        Else
        Begin
          { Appel sans parentheses (procedure sans parametres) }
          EmitI1('CALL', sym_table^[si].asm_label);
        End;
        If (pi2 > 0) And (pi2 <= proc_count) Then
          ti := proc_table^[pi2].ret_type_idx
        Else
          ti := 0;
      End;
  Else
    { SK_VAR, SK_PARAM, SK_FIELD }
    { Pour les agregats (ARRAY, RECORD), charger l'adresse dans BX }
    If TypeIsArray(ti) Or TypeIsRecord(ti) Then
    Begin
      GenLoadAddr(si);     { BX = adresse de base de l'agregat }
      addr_in_bx := True;
    End
    Else
      GenLoad(si);         { AX = valeur scalaire }
  End;

  { Post-fixes }
  While (cur_tok.val = '.') Or (cur_tok.val = '[') Or (cur_tok.val = '^') Do
  Begin
    If cur_tok.val = '.' Then
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_RECORD) Then
        ErrorMsg('Selection de champ sur un type non RECORD');
      If Not addr_in_bx Then
      Begin
        { On avait un pointeur vers RECORD dans AX }
        EmitI2('MOV', 'BX', 'AX');
      End;
      name := cur_tok.val;
      LexExpectKind(TK_IDENT);
      fld_idx := 0;
      For k := type_table^[ti].rec_sym To
               type_table^[ti].rec_sym + type_table^[ti].rec_nfld - 1 Do
        If (k >= 1) And (k <= sym_count) And (sym_table^[k].name = name) Then
        Begin
          fld_idx := k;
          Break;
        End;
      If fld_idx = 0 Then
        ErrorMsg('Champ inconnu : ' + name)
      Else
      Begin
        If sym_table^[fld_idx].fld_offset > 0 Then
          EmitI2('ADD', 'BX', IntToStr(sym_table^[fld_idx].fld_offset));
        ti := sym_table^[fld_idx].type_idx;
        If TypeIsArray(ti) Or TypeIsRecord(ti) Then
          addr_in_bx := True
        Else
        Begin
          EmitI2('MOV', 'AX', '[BX]');
          addr_in_bx := False;
        End;
      End;
    End
    Else If cur_tok.val = '[' Then
    Begin
      LexNext;
      If (ti < 1) Or ((type_table^[ti].kind <> TYK_ARRAY) And
                      (type_table^[ti].kind <> TYK_OPENARRAY)) Then
        ErrorMsg('Acces indexe sur un type non ARRAY');
      el_ti   := type_table^[ti].base_idx;
      el_size := TypeByteSize(el_ti);
      If el_size < 1 Then el_size := 1;
      { Si la base n'est pas encore dans BX, la placer }
      If Not addr_in_bx Then
        EmitI2('MOV', 'BX', 'AX');
      EmitI0('PUSH BX');              { sauvegarder adresse de base }
      ParseExpr;                       { index -> AX }
      { Verification de bornes (0 <= i < len) pour tableaux de taille connue }
      If (type_table^[ti].kind = TYK_ARRAY) And
         (type_table^[ti].arr_len > 0) Then
      Begin
        EmitI2('CMP', 'AX', IntToStr(type_table^[ti].arr_len));
        EmitI1('JAE', '_ORT_BOUNDS_ERR');  { non signe : capte < 0 et >= len }
      End;
      { Calculer l'offset : AX = index * el_size }
      If el_size = 2 Then
        EmitI0('SHL  AX, 1')
      Else If el_size > 2 Then
      Begin
        EmitI2('MOV', 'CX', IntToStr(el_size));
        EmitI0('MUL  CX');
      End;
      EmitI0('POP  BX');
      EmitI2('ADD', 'BX', 'AX');
      ti := el_ti;
      If TypeIsArray(ti) Or TypeIsRecord(ti) Then
        addr_in_bx := True
      Else
      Begin
        EmitI2('MOV', 'AX', '[BX]');
        addr_in_bx := False;
      End;
      LexExpect(']');
    End
    Else
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_POINTER) Then
        ErrorMsg('Dereferencement sur un type non POINTER');
      { Obtenir la valeur du pointeur dans BX }
      If addr_in_bx Then
        EmitI2('MOV', 'BX', '[BX]')  { deref adresse en BX }
      Else
        EmitI2('MOV', 'BX', 'AX');   { pointer etait dans AX }
      { Verification NIL a l'execution (TODO 22) }
      EmitI2('OR',  'BX', 'BX');
      EmitI1('JZ',  '_ORT_NIL_ERR');
      ti := type_table^[ti].base_idx;
      If TypeIsArray(ti) Or TypeIsRecord(ti) Then
        addr_in_bx := True
      Else
      Begin
        EmitI2('MOV', 'AX', '[BX]');
        addr_in_bx := False;
      End;
    End;
  End;

  { Si on termine en mode adresse (agregat), mettre l'adresse dans AX aussi }
  If addr_in_bx Then
    EmitI2('MOV', 'AX', 'BX');
  ParseDesignator := ti;
End;

{ --------------------------------------------------------------------------
  ParseFactor : facteur primaire Oberon.
  Grammaire :
    factor = integer | char | real | string
           | TRUE | FALSE | NIL
           | '~' factor
           | '(' expr ')'
           | designator [ '(' ExprList ')' ]
  Resultat dans AX ; type retourne.
  Les appels de fonction sont des stubs (TODO 18).
  -------------------------------------------------------------------------- }
Function ParseFactor : Integer;
Var ti    : Integer;
    lbl   : TString;
    n_str : TString;
    bname : TString;
Begin
  ti := TYP_WORD;

  If cur_tok.kind = TK_INTEGER Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    ti := TYP_INTEGER;
    LexNext;
  End
  Else If cur_tok.kind = TK_CHAR Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    ti := TYP_CHAR;
    LexNext;
  End
  Else If cur_tok.kind = TK_REAL Then
  Begin
    { Constante reelle : emettre une reserve DD dans DATA et charger l'adresse }
    Inc(str_lit_count);
    Str(str_lit_count, n_str);
    lbl := BK_PFX + 'R' + n_str;
    EmitDD(lbl, cur_tok.val);
    EmitI2('LEA', 'AX', '[' + lbl + ']');
    ti := TYP_REAL;
    LexNext;
  End
  Else If cur_tok.kind = TK_STRING Then
  Begin
    lbl := GenStringLitData(cur_tok.val);
    EmitI2('LEA', 'AX', '[' + lbl + ']');
    ti := TypeNewArray(TYP_CHAR, Length(cur_tok.val) + 1);
    LexNext;
  End
  Else If cur_tok.val = 'TRUE' Then
  Begin
    EmitI2('MOV', 'AX', '1');
    ti := TYP_BOOLEAN;
    LexNext;
  End
  Else If cur_tok.val = 'FALSE' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_BOOLEAN;
    LexNext;
  End
  Else If cur_tok.val = 'NIL' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_NIL;
    LexNext;
  End
  Else If cur_tok.val = '~' Then
  Begin
    LexNext;
    ti := ParseFactor;
    If Not TypeIsBoolean(ti) Then
      ErrorMsg('NOT applicable uniquement sur BOOLEAN');
    EmitI2('XOR', 'AX', '1');
  End
  Else If cur_tok.val = '(' Then
  Begin
    LexNext;
    ti := ParseExpr;
    LexExpect(')');
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    If IsStdModuleIdent(cur_tok.val) Then
    Begin
      LexPeek;
      If peek_tok.val = '.' Then
        ti := ParseStdModuleExpr
      Else
        ti := ParseDesignator;
    End
    Else If IsBuiltinFunc(cur_tok.val) Then
    Begin
      bname := cur_tok.val;
      LexNext;
      ti := ParseBuiltinFunc(bname);
    End
    Else
      ti := ParseDesignator;
  End
  Else
  Begin
    ErrorMsg('Facteur attendu, obtenu : ' + cur_tok.val);
    LexNext;
  End;

  ParseFactor := ti;
End;

{ ============================================================
  TODO 10 - EXPRESSIONS - OPERATEURS ET PRIORITES
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseTerm : facteurs lies par operateurs de multiplicite.
  Oberon : * , DIV, MOD, AND
  Resultat dans AX ; gauche et droit evalues, pile utilisee.
  -------------------------------------------------------------------------- }
Function ParseTerm : Integer;
Var ti   : Integer;
    ti2  : Integer;
    op   : TString;
Begin
  ti := ParseFactor;
  While (cur_tok.val = '*') Or (cur_tok.val = 'DIV')
     Or (cur_tok.val = 'MOD') Or (cur_tok.val = 'AND') Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI0('PUSH AX');             { sauvegarder gauche }
    ti2 := ParseFactor;            { evaluer droit -> AX }
    EmitI2('MOV', 'CX', 'AX');    { CX = droit }
    EmitI0('POP  AX');             { AX = gauche }
    If op = '*' Then
    Begin
      If TypeIsBoolean(ti) Then
        EmitI2('AND', 'AX', 'CX') { AND logique bits }
      Else
        EmitI0('IMUL CX');         { AX * CX -> DX:AX }
      ti := TYP_INTEGER;
    End
    Else If op = 'DIV' Then
    Begin
      EmitI0('CWD');               { etendre AX -> DX:AX }
      EmitI0('IDIV CX');           { quotient -> AX }
      ti := TYP_INTEGER;
    End
    Else If op = 'MOD' Then
    Begin
      EmitI0('CWD');
      EmitI0('IDIV CX');
      EmitI2('MOV', 'AX', 'DX');  { reste -> AX }
      ti := TYP_INTEGER;
    End
    Else { AND }
    Begin
      EmitI2('AND', 'AX', 'CX');
      ti := TYP_BOOLEAN;
    End;
    If ti2 = TYP_WORD Then ti := TYP_WORD;
  End;
  ParseTerm := ti;
End;

{ --------------------------------------------------------------------------
  ParseSimpleExpr : termes lies par operateurs additifs.
  Oberon : + , - , OR (avec signe unaire optionnel en debut)
  -------------------------------------------------------------------------- }
Function ParseSimpleExpr : Integer;
Var ti   : Integer;
    ti2  : Integer;
    op   : TString;
    uneg : Boolean;
Begin
  uneg := False;
  If cur_tok.val = '-' Then Begin LexNext; uneg := True;  End
  Else If cur_tok.val = '+' Then LexNext;
  ti := ParseTerm;
  If uneg Then EmitI0('NEG  AX');
  While (cur_tok.val = '+') Or (cur_tok.val = '-') Or (cur_tok.val = 'OR') Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI0('PUSH AX');
    ti2 := ParseTerm;
    EmitI2('MOV', 'CX', 'AX');
    EmitI0('POP  AX');
    If op = '+' Then
    Begin
      EmitI2('ADD', 'AX', 'CX');
      If Not TypeIsBoolean(ti) Then ti := TYP_INTEGER;
    End
    Else If op = '-' Then
    Begin
      EmitI2('SUB', 'AX', 'CX');
      ti := TYP_INTEGER;
    End
    Else { OR }
    Begin
      EmitI2('OR',  'AX', 'CX');
      ti := TYP_BOOLEAN;
    End;
    If ti2 = TYP_WORD Then ti := TYP_WORD;
  End;
  ParseSimpleExpr := ti;
End;

{ --------------------------------------------------------------------------
  ParseExpr : implementation complete - remplace le stub TODO 09.
  Relations Oberon : = # < <= > >= IN IS
  Gauche dans AX, droit dans CX, resultat BOOLEAN dans AX (0 ou 1).
  -------------------------------------------------------------------------- }
Function ParseExpr;
Var ti   : Integer;
    ti2  : Integer;
    op   : TString;
    lbl  : TString;
Begin
  ti := ParseSimpleExpr;
  If (cur_tok.val = '=')  Or (cur_tok.val = '#')
  Or (cur_tok.val = '<')  Or (cur_tok.val = '<=')
  Or (cur_tok.val = '>')  Or (cur_tok.val = '>=')
  Or (cur_tok.val = 'IN') Or (cur_tok.val = 'IS') Then
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI0('PUSH AX');             { sauvegarder gauche }
    ti2  := ParseSimpleExpr;      { evaluer droit -> AX }
    EmitI2('MOV', 'CX', 'AX');    { CX = droit }
    EmitI0('POP  AX');             { AX = gauche }

    If op = 'IN' Then
    Begin
      { x IN s : tester le bit AX dans le mot de bits CX }
      EmitI2('MOV', 'BX', 'CX');  { BX = s }
      EmitI2('MOV', 'CX', 'AX');  { CL = x (compteur de decalage) }
      EmitI2('MOV', 'AX', 'BX');  { AX = s }
      EmitI0('SAR  AX, CL');       { AX = s >> x }
      EmitI2('AND', 'AX', '1');    { bit x }
    End
    Else If op = 'IS' Then
    Begin
      { IS : verification de type dynamique - stub (TODO 22+) }
      EmitI2('MOV', 'AX', '0');
    End
    Else
    Begin
      { Relations ordinales : CMP gauche, droit puis saut conditionnel }
      lbl := NewLabel;
      EmitI2('CMP', 'AX', 'CX');
      EmitI2('MOV', 'AX', '0');    { hypothese : faux }
      If      op = '='  Then EmitI1('JNE', lbl)
      Else If op = '#'  Then EmitI1('JE',  lbl)
      Else If op = '<'  Then EmitI1('JGE', lbl)
      Else If op = '<=' Then EmitI1('JG',  lbl)
      Else If op = '>'  Then EmitI1('JLE', lbl)
      Else                   EmitI1('JL',  lbl);  { >= }
      EmitI2('MOV', 'AX', '1');    { vrai }
      EmitLabel(lbl);
    End;
    ti := TYP_BOOLEAN;
    If ti2 = TYP_WORD Then ti := TYP_WORD;
  End;
  ParseExpr := ti;
End;

{ ============================================================
  TODO 11 - INSTRUCTION D'AFFECTATION (:=)
  ============================================================ }

{ --------------------------------------------------------------------------
  GenLValueAddr : calculer l'adresse de la cible dans BX.
  Le symbole de base si est connu ; les postfixes (. [ ^) sont consommes.
  Retourne le type_idx de la cible finale.
  -------------------------------------------------------------------------- }
Function GenLValueAddr(si : Integer) : Integer;
Var ti      : Integer;
    el_ti   : Integer;
    el_size : Integer;
    fld_idx : Integer;
    fname   : TString;
    k       : Integer;
Begin
  ti := sym_table^[si].type_idx;
  GenLoadAddr(si);                     { BX = adresse de base }
  While (cur_tok.val = '.') Or (cur_tok.val = '[') Or (cur_tok.val = '^') Do
  Begin
    If cur_tok.val = '.' Then
    Begin
      LexNext;
      If (ti < 1) Or (type_table^[ti].kind <> TYK_RECORD) Then
        ErrorMsg('Selection de champ sur un type non RECORD');
      fname    := cur_tok.val;
      LexExpectKind(TK_IDENT);
      fld_idx := 0;
      For k := type_table^[ti].rec_sym To
               type_table^[ti].rec_sym + type_table^[ti].rec_nfld - 1 Do
        If (k >= 1) And (k <= sym_count) And (sym_table^[k].name = fname) Then
        Begin
          fld_idx := k;
          Break;
        End;
      If fld_idx = 0 Then
        ErrorMsg('Champ inconnu : ' + fname)
      Else
      Begin
        If sym_table^[fld_idx].fld_offset > 0 Then
          EmitI2('ADD', 'BX', IntToStr(sym_table^[fld_idx].fld_offset));
        ti := sym_table^[fld_idx].type_idx;
      End;
    End
    Else If cur_tok.val = '[' Then
    Begin
      LexNext;
      If (ti < 1) Or ((type_table^[ti].kind <> TYK_ARRAY) And
                      (type_table^[ti].kind <> TYK_OPENARRAY)) Then
        ErrorMsg('Acces indexe sur un type non ARRAY');
      el_ti   := type_table^[ti].base_idx;
      el_size := TypeByteSize(el_ti);
      If el_size < 1 Then el_size := 1;
      EmitI0('PUSH BX');              { sauvegarder adresse de base }
      ParseExpr;                       { index -> AX }
      { Verification de bornes }
      If (type_table^[ti].kind = TYK_ARRAY) And
         (type_table^[ti].arr_len > 0) Then
      Begin
        EmitI2('CMP', 'AX', IntToStr(type_table^[ti].arr_len));
        EmitI1('JAE', '_ORT_BOUNDS_ERR');
      End;
      If el_size = 2 Then
        EmitI0('SHL  AX, 1')
      Else If el_size > 2 Then
      Begin
        EmitI2('MOV', 'CX', IntToStr(el_size));
        EmitI0('MUL  CX');
      End;
      EmitI0('POP  BX');
      EmitI2('ADD', 'BX', 'AX');
      ti := el_ti;
      LexExpect(']');
    End
    Else
    Begin
      LexNext;                         { consommer '^' }
      If (ti < 1) Or (type_table^[ti].kind <> TYK_POINTER) Then
        ErrorMsg('Dereferencement sur un type non POINTER');
      EmitI2('MOV', 'BX', '[BX]');    { deref }
      { Verification NIL a l'execution (TODO 22) }
      EmitI2('OR',  'BX', 'BX');
      EmitI1('JZ',  '_ORT_NIL_ERR');
      ti := type_table^[ti].base_idx;
    End;
  End;
  GenLValueAddr := ti;
End;

{ --------------------------------------------------------------------------
  ParseAssignment : designateur := expression
  Gere : variable simple, element de tableau, champ de RECORD, deref ptr.
  -------------------------------------------------------------------------- }
Procedure ParseAssignment;
Var vname   : TString;
    si      : Integer;
    ti_lhs  : Integer;
    ti_rhs  : Integer;
    simple  : Boolean;
    bits    : Integer;
    nb      : Integer;
Begin
  vname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  si := SymFind(vname);
  If si = 0 Then
  Begin
    ErrorMsg('Identifiant inconnu : ' + vname);
    LexExpect(':=');
    ParseExpr;
    Exit;
  End;
  If sym_table^[si].kind = SK_MANIFEST Then
  Begin
    ErrorMsg('Impossible d''affecter a une constante : ' + vname);
    LexExpect(':=');
    ParseExpr;
    Exit;
  End;

  { Detecter la presence de postfixes }
  simple := (cur_tok.val <> '.') And (cur_tok.val <> '[') And (cur_tok.val <> '^');

  If simple Then
  Begin
    ti_lhs := sym_table^[si].type_idx;
    { Affectation de structure : RECORD ou ARRAY -> copie bloc }
    If TypeIsRecord(ti_lhs) Or TypeIsArray(ti_lhs) Then
    Begin
      GenLoadAddr(si);             { BX = adresse de la destination }
      EmitI2('MOV', 'DI', 'BX');  { DI = destination }
      LexExpect(':=');
      ti_rhs := ParseExpr;        { ParseDesignator met l'adresse source dans AX }
      EmitI2('MOV', 'SI', 'AX');  { SI = source }
      TypeCheckAssign(ti_lhs, ti_rhs);
      nb := TypeByteSize(ti_lhs);
      GenStructCopy(nb);
    End
    Else
    Begin
      LexExpect(':=');
      ti_rhs := ParseExpr;
      TypeCheckAssign(ti_lhs, ti_rhs);
      GenStore(si);
    End;
  End
  Else
  Begin
    ti_lhs := GenLValueAddr(si);   { BX = adresse de la cible }
    LexExpect(':=');
    ti_rhs := ParseExpr;           { resultat dans AX }
    TypeCheckAssign(ti_lhs, ti_rhs);
    { Affectation de structure vers adresse calculee }
    If TypeIsRecord(ti_lhs) Or TypeIsArray(ti_lhs) Then
    Begin
      EmitI0('PUSH BX');
      EmitI2('MOV', 'SI', 'AX');   { SI = source (adresse en AX) }
      EmitI0('POP  DI');           { DI = destination }
      nb := TypeByteSize(ti_lhs);
      GenStructCopy(nb);
    End
    Else
    Begin
      bits := TypeBitSize(ti_lhs);
      Case bits Of
         8 : EmitI2('MOV', '[BX]', 'AL');
        32 : Begin
               EmitI2('MOV', '[BX]',   'AX');
               EmitI2('MOV', '[BX+2]', 'DX');
             End;
      Else
        EmitI2('MOV', '[BX]', 'AX');
      End;
    End;
  End;
End;

{ ============================================================
  TODO 12 - INSTRUCTION IF / ELSIF / ELSE
  ============================================================ }

{ Forward : ParseStatement est complete en TODO 13+ ;
  ParseStatementSeq l'appelle pour les corps de IF/WHILE/etc. }
Procedure ParseStatement; Forward;

{ --------------------------------------------------------------------------
  ParseStatementSeq : suite d'instructions separees par ';'.
  Oberon : StatementSequence = Statement [ ";" Statement ]*
  On s'arrete sur END, ELSE, ELSIF, UNTIL, '|' ou EOF.
  -------------------------------------------------------------------------- }
Procedure ParseStatementSeq;
Begin
  ParseStatement;
  While cur_tok.val = ';' Do
  Begin
    LexNext;
    { Ne pas essayer de parser une instruction apres le dernier ';' }
    If (cur_tok.val = 'END')   Or (cur_tok.val = 'ELSE')
    Or (cur_tok.val = 'ELSIF') Or (cur_tok.val = 'UNTIL')
    Or (cur_tok.val = '|')     Or (cur_tok.kind = TK_EOF) Then
      Exit;
    ParseStatement;
  End;
End;

{ --------------------------------------------------------------------------
  ParseIfStmt : IF expr THEN seq [ELSIF expr THEN seq]* [ELSE seq] END
  Strategie de labels :
    lbl_end   = label de sortie global (apres tout le bloc IF)
    lbl_next  = label du prochain ELSIF/ELSE (mis a jour a chaque branche)
  -------------------------------------------------------------------------- }
Procedure ParseIfStmt;
Var lbl_end  : TString;
    lbl_next : TString;
    ti       : Integer;
Begin
  lbl_end := NewLabel;
  LexExpect('IF');

  { --- branche principale IF --- }
  lbl_next := NewLabel;
  ti := ParseExpr;
  If Not TypeIsBoolean(ti) Then
    ErrorMsg('Condition IF doit etre de type BOOLEAN');
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_next);          { si faux, sauter vers ELSIF/ELSE }
  LexExpect('THEN');
  ParseStatementSeq;
  EmitI1('JMP', lbl_end);            { sortir du bloc IF complet }
  EmitLabel(lbl_next);

  { --- branches ELSIF --- }
  While cur_tok.val = 'ELSIF' Do
  Begin
    LexNext;
    lbl_next := NewLabel;
    ti := ParseExpr;
    If Not TypeIsBoolean(ti) Then
      ErrorMsg('Condition ELSIF doit etre de type BOOLEAN');
    EmitI2('CMP', 'AX', '0');
    EmitI1('JE',  lbl_next);
    LexExpect('THEN');
    ParseStatementSeq;
    EmitI1('JMP', lbl_end);
    EmitLabel(lbl_next);
  End;

  { --- branche ELSE facultative --- }
  If cur_tok.val = 'ELSE' Then
  Begin
    LexNext;
    ParseStatementSeq;
  End;

  LexExpect('END');
  EmitLabel(lbl_end);
End;

{ ============================================================
  TODO 13 - INSTRUCTION WHILE / REPEAT / LOOP / EXIT
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseWhileStmt : WHILE expr DO StatementSeq END
  -------------------------------------------------------------------------- }
Procedure ParseWhileStmt;
Var lbl_top  : TString;
    lbl_end  : TString;
    ti       : Integer;
Begin
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  LexExpect('WHILE');
  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);
  ti := ParseExpr;
  If Not TypeIsBoolean(ti) Then
    ErrorMsg('Condition WHILE doit etre de type BOOLEAN');
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_end);
  LexExpect('DO');
  ParseStatementSeq;
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  LexExpect('END');
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseRepeatStmt : REPEAT StatementSeq UNTIL expr
  -------------------------------------------------------------------------- }
Procedure ParseRepeatStmt;
Var lbl_top : TString;
    lbl_end : TString;
    ti      : Integer;
Begin
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  LexExpect('REPEAT');
  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);
  ParseStatementSeq;
  LexExpect('UNTIL');
  ti := ParseExpr;
  If Not TypeIsBoolean(ti) Then
    ErrorMsg('Condition UNTIL doit etre de type BOOLEAN');
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_top);   { si encore faux, reboucler }
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseLoopStmt : LOOP StatementSeq END
  Boucle infinie ; EXIT genere un JMP vers lbl_end.
  -------------------------------------------------------------------------- }
Procedure ParseLoopStmt;
Var lbl_top : TString;
    lbl_end : TString;
Begin
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  LexExpect('LOOP');
  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);
  ParseStatementSeq;
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  LexExpect('END');
  PopLoopLabels;
End;

{ ============================================================
  TODO 14 - INSTRUCTION FOR
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseForStmt : FOR v := start TO end [BY step] DO StatementSeq END
  Strategie 8086 :
    - SI    = valeur limite (end), calculee une seule fois avant la boucle
    - [v]   = variable de controle (SK_VAR ordinal)
    - step  = constante entiere evaluee au compile-time (defaut +1)
  Le prologue de procedure sauvegarde deja SI (TODO 17) ; au niveau module
  SI est libre apres GenStartEntry (qui ne fait que MOV DS).
  -------------------------------------------------------------------------- }
Procedure ParseForStmt;
Var vname   : TString;
    si_var  : Integer;
    step    : LongInt;
    lbl_top : TString;
    lbl_end : TString;
    ti      : Integer;
    neg     : Boolean;
Begin
  LexExpect('FOR');
  vname  := cur_tok.val;
  LexExpectKind(TK_IDENT);
  si_var := SymFind(vname);
  If si_var = 0 Then
    ErrorMsg('Variable de boucle inconnue : ' + vname)
  Else If sym_table^[si_var].kind <> SK_VAR Then
    ErrorMsg('La variable de boucle doit etre une variable : ' + vname);

  LexExpect(':=');
  { Evaluer debut -> AX, stocker dans v }
  ti := ParseExpr;
  If Not TypeIsOrdinal(ti) Then
    WarnMsg('Variable de boucle doit etre ordinale');
  If si_var > 0 Then GenStore(si_var);

  LexExpect('TO');
  { Evaluer fin -> AX, charger dans SI }
  ParseExpr;
  EmitI2('MOV', 'SI', 'AX');

  { Optionnel : BY constante }
  step := 1;
  neg  := False;
  If cur_tok.val = 'BY' Then
  Begin
    LexNext;
    If cur_tok.val = '-' Then
    Begin
      neg := True;
      LexNext;
    End;
    step := ParseConstExprInt;
    If neg Then step := -step;
  End;

  LexExpect('DO');
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  PushLoopLabels(lbl_end, lbl_top);

  EmitLabel(lbl_top);
  { Test de borne : charger v, comparer avec SI }
  If si_var > 0 Then GenLoad(si_var)
  Else EmitI2('MOV', 'AX', '0');
  EmitI2('CMP', 'AX', 'SI');
  If step >= 0 Then
    EmitI1('JG', lbl_end)      { v > end -> sortir }
  Else
    EmitI1('JL', lbl_end);     { v < end -> sortir }

  ParseStatementSeq;

  { Incrementer/decrementer v }
  If si_var > 0 Then GenLoad(si_var);
  If step = 1 Then
    EmitI0('INC  AX')
  Else If step = -1 Then
    EmitI0('DEC  AX')
  Else If step >= 0 Then
    EmitI2('ADD', 'AX', IntToStr(step And $FFFF))
  Else
    EmitI2('SUB', 'AX', IntToStr((-step) And $FFFF));
  If si_var > 0 Then GenStore(si_var);

  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  LexExpect('END');
  PopLoopLabels;
End;

{ ============================================================
  TODO 15 - INSTRUCTION CASE
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseCaseStmt : CASE expr OF arm [| arm]* [ELSE seq] END

  CaseLabelList = label [.. label] [, label [.. label]]*
  Labels = constantes entieres ou caracteres.

  Schema ASM emis (forward-jump monopasse) :
      MOV CX, AX          ; expr dans CX
      JMP lbl_disp         ; vers le bloc de tests
  lbl_arm1:
      corps1 ... JMP lbl_end
  lbl_arm2:
      corps2 ... JMP lbl_end
  lbl_else:
      corps_else ... JMP lbl_end
  lbl_disp:
      CMP CX, v1 / JE lbl_arm1
      CMP CX, lo / JL skip / CMP CX, hi / JLE lbl_arm2 / skip:
      ...
      JMP lbl_else
  lbl_end:
  -------------------------------------------------------------------------- }
Procedure ParseCaseStmt;
Const
  MAX_ARM = 16;
  MAX_LBL = 8;
Var
  arm_lbl     : Array[1..MAX_ARM] of TString;
  arm_lbl_cnt : Array[1..MAX_ARM] of Integer;
  lbl_lo      : Array[1..MAX_ARM, 1..MAX_LBL] of LongInt;
  lbl_hi      : Array[1..MAX_ARM, 1..MAX_LBL] of LongInt;
  lbl_rng     : Array[1..MAX_ARM, 1..MAX_LBL] of Boolean;
  arm_cnt     : Integer;
  lbl_end     : TString;
  lbl_else    : TString;
  lbl_disp    : TString;
  lbl_skip    : TString;
  lo, hi      : LongInt;
  ti          : Integer;
  a, l        : Integer;
Begin
  LexExpect('CASE');
  ti := ParseExpr;
  If Not TypeIsOrdinal(ti) Then
    WarnMsg('Expression CASE doit etre de type ordinal');
  EmitI2('MOV', 'CX', 'AX');      { CX = valeur de controle }
  lbl_end  := NewLabel;
  lbl_else := NewLabel;
  lbl_disp := NewLabel;
  EmitI1('JMP', lbl_disp);        { saut vers le bloc de tests }
  LexExpect('OF');
  arm_cnt := 0;

  { Boucle sur les bras }
  While (cur_tok.val <> 'ELSE') And (cur_tok.val <> 'END')
     And (cur_tok.kind <> TK_EOF) Do
  Begin
    If cur_tok.val = '|' Then LexNext;
    If (cur_tok.val = 'ELSE') Or (cur_tok.val = 'END') Then Break;
    If arm_cnt >= MAX_ARM Then
    Begin
      ErrorMsg('Trop de bras dans CASE (max 16)');
      Break;
    End;
    Inc(arm_cnt);
    arm_lbl[arm_cnt]     := NewLabel;
    arm_lbl_cnt[arm_cnt] := 0;

    { Collecter les labels du bras }
    lo := ParseConstExprInt;
    hi := lo;
    If cur_tok.val = '..' Then Begin LexNext; hi := ParseConstExprInt; End;
    Inc(arm_lbl_cnt[arm_cnt]);
    l := arm_lbl_cnt[arm_cnt];
    lbl_lo[arm_cnt, l]  := lo;
    lbl_hi[arm_cnt, l]  := hi;
    lbl_rng[arm_cnt, l] := (hi <> lo);

    While cur_tok.val = ',' Do
    Begin
      LexNext;
      lo := ParseConstExprInt;
      hi := lo;
      If cur_tok.val = '..' Then Begin LexNext; hi := ParseConstExprInt; End;
      If arm_lbl_cnt[arm_cnt] < MAX_LBL Then
      Begin
        Inc(arm_lbl_cnt[arm_cnt]);
        l := arm_lbl_cnt[arm_cnt];
        lbl_lo[arm_cnt, l]  := lo;
        lbl_hi[arm_cnt, l]  := hi;
        lbl_rng[arm_cnt, l] := (hi <> lo);
      End;
    End;

    LexExpect(':');
    EmitLabel(arm_lbl[arm_cnt]);   { point d'entree du corps }
    ParseStatementSeq;
    EmitI1('JMP', lbl_end);        { sortir du CASE apres le corps }
  End;

  { Corps ELSE }
  EmitLabel(lbl_else);
  If cur_tok.val = 'ELSE' Then
  Begin
    LexNext;
    ParseStatementSeq;
  End;
  EmitI1('JMP', lbl_end);

  { Bloc de dispatch (atteint par le JMP lbl_disp initial) }
  EmitLabel(lbl_disp);
  For a := 1 To arm_cnt Do
    For l := 1 To arm_lbl_cnt[a] Do
    Begin
      If lbl_rng[a, l] Then
      Begin
        lbl_skip := NewLabel;
        EmitI2('CMP', 'CX', IntToStr(lbl_lo[a, l] And $FFFF));
        EmitI1('JL',  lbl_skip);
        EmitI2('CMP', 'CX', IntToStr(lbl_hi[a, l] And $FFFF));
        EmitI1('JLE', arm_lbl[a]);
        EmitLabel(lbl_skip);
      End
      Else
      Begin
        EmitI2('CMP', 'CX', IntToStr(lbl_lo[a, l] And $FFFF));
        EmitI1('JE',  arm_lbl[a]);
      End;
    End;
  EmitI1('JMP', lbl_else);         { aucun label ne correspond }
  EmitLabel(lbl_end);
  LexExpect('END');
End;

{ ============================================================
  TODO 16 - INSTRUCTION WITH (GARDE DE TYPE)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseWithStmt : WITH v : T DO StatementSeq END

  Semantique Oberon :
    v doit etre un pointeur ou un enregistrement.
    T est un type etendu de celui de v (sous-type).
    Dans le corps, v est vu comme ayant le type T (transtypage de portee).
    Le test de type dynamique (IS) est emis comme commentaire/stub ici
    et sera complete en TODO 22 quand le RTTI sera implemente.

  Implementation :
    1. Rechercher v dans sym_table -> si_v
    2. Rechercher T dans sym_table -> ti_T
    3. Emettre un commentaire de garde (stub runtime)
    4. Ouvrir une nouvelle portee
    5. Ajouter un alias de v avec type_idx = ti_T dans cette portee
    6. Parser le corps
    7. Fermer la portee
    8. Supports plusieurs gardes : WITH v1:T1 DO | v2:T2 DO seq END
  -------------------------------------------------------------------------- }
Procedure ParseWithStmt;
Var vname  : TString;
    tname  : TString;
    si_v   : Integer;
    si_t   : Integer;
    ti_T   : Integer;
    si_alias : Integer;
    lbl_end  : TString;
    lbl_else : TString;
Begin
  LexExpect('WITH');
  lbl_end  := NewLabel;
  lbl_else := NewLabel;

  { Boucle sur les gardes v : T }  
  Repeat
    vname := cur_tok.val;
    LexExpectKind(TK_IDENT);
    LexExpect(':');
    tname := cur_tok.val;
    LexExpectKind(TK_IDENT);

    { Verifier que v existe }
    si_v := SymFind(vname);
    If si_v = 0 Then
      ErrorMsg('Variable inconnue dans WITH : ' + vname);

    { Verifier que T est un type connu }
    si_t := SymFind(tname);
    If (si_t = 0) Or (sym_table^[si_t].kind <> SK_TYPE) Then
    Begin
      ErrorMsg('Type inconnu dans WITH : ' + tname);
      ti_T := TYP_WORD;
    End
    Else
      ti_T := sym_table^[si_t].type_idx;

    { Emettre la garde de type - stub (RTTI complet en TODO 22) }
    EmitComment(' WITH ' + vname + ' : ' + tname + ' (type guard stub)');
    If si_v > 0 Then
      GenLoad(si_v);             { charger v dans AX }
    EmitI2('CMP', 'AX', '0');   { test basique NIL }
    EmitI1('JE',  lbl_else);    { si NIL, sauter vers ELSE }

    { Ouvrir une portee pour l'alias retypee }
    ScopeEnter;

    { Ajouter un alias de v avec le type T }
    si_alias := SymEnter(vname, SK_VAR,
                         sym_table^[si_v].scope, ti_T);
    If si_alias > 0 Then
    Begin
      sym_table^[si_alias].asm_label  := sym_table^[si_v].asm_label;
      sym_table^[si_alias].bp_offset  := sym_table^[si_v].bp_offset;
      sym_table^[si_alias].is_var_par := sym_table^[si_v].is_var_par;
    End;

    LexExpect('DO');
    ParseStatementSeq;

    EmitI1('JMP', lbl_end);
    EmitLabel(lbl_else);
    lbl_else := NewLabel;        { nouveau lbl_else pour la prochaine garde }

    ScopeLeave;

  Until cur_tok.val <> '|';     { plusieurs gardes separees par '|' }

  { Corps ELSE implicite (quand aucune garde ne correspond)
    On atterrit ici si le dernier JE lbl_else a saute }
  { pas de corps ELSE en Oberon-2 WITH - on emet juste le label }

  LexExpect('END');
  EmitLabel(lbl_end);
End;

{ --------------------------------------------------------------------------
  ParseStatement : dispatch complet.
  Gere : IF, WHILE, REPEAT, LOOP, EXIT, FOR, CASE, WITH, affectation / appel.
  Les TODOs suivants (17-19) ajouteront PROCEDURE, RETURN, stdlib, etc.
  -------------------------------------------------------------------------- }
Procedure ParseStatement;
Var brk      : TString;
    bname    : TString;
    call_si  : Integer;
    call_pi  : Integer;
    call_na  : Integer;
Begin
  If cur_tok.val = 'IF' Then
    ParseIfStmt
  Else If cur_tok.val = 'WHILE' Then
    ParseWhileStmt
  Else If cur_tok.val = 'REPEAT' Then
    ParseRepeatStmt
  Else If cur_tok.val = 'LOOP' Then
    ParseLoopStmt
  Else If cur_tok.val = 'FOR' Then
    ParseForStmt
  Else If cur_tok.val = 'CASE' Then
    ParseCaseStmt
  Else If cur_tok.val = 'WITH' Then
    ParseWithStmt
  Else If cur_tok.val = 'EXIT' Then
  Begin
    LexNext;
    brk := TopBreakLabel;
    If brk = '' Then
      ErrorMsg('EXIT en dehors d''une boucle LOOP')
    Else
      EmitI1('JMP', brk);
  End
  Else If cur_tok.val = 'RETURN' Then
  Begin
    LexNext;
    { Si la procedure retourne une valeur, evaluer l'expression -> AX }
    If (cur_proc_idx > 0) And
       (proc_table^[cur_proc_idx].ret_type_idx > 0) And
       (cur_tok.kind <> TK_EOF) And
       (cur_tok.val <> ';') And
       (cur_tok.val <> 'END') Then
      ParseExpr;
    If cur_ret_lbl <> '' Then
      EmitI1('JMP', cur_ret_lbl)
    Else
      EmitI0('RET');
  End
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    If IsStdModuleIdent(cur_tok.val) Then
    Begin
      LexPeek;
      If peek_tok.val = '.' Then
        ParseStdModuleCall
      Else
        ParseAssignment;         { fallback si Out/In utilise comme ident simple }
    End
    Else If IsBuiltinProc(cur_tok.val) Then
    Begin
      bname := cur_tok.val;
      LexNext;                { consommer le nom de la procedure integree }
      ParseBuiltinProc(bname);
    End
    Else
    Begin
      { Distinguer appel de procedure utilisateur (SK_PROC) et affectation (:=) }
      call_si := SymFind(cur_tok.val);
      If (call_si > 0) And (sym_table^[call_si].kind = SK_PROC) Then
      Begin
        call_pi := sym_table^[call_si].proc_idx;
        LexNext;              { consommer l'identificateur }
        call_na := 0;
        If cur_tok.val = '(' Then
          call_na := ParseProcCallArgs(call_pi);
        EmitI1('CALL', sym_table^[call_si].asm_label);
        If call_na > 0 Then
          EmitI2('ADD', 'SP', IntToStr(call_na * 2));
      End
      Else
        ParseAssignment;
    End;
  End;
  { Builtins, stdlib -> TODOs 19-20 (dispatche ci-dessus) }
End;

{ ============================================================
  TODO 18 - APPELS DE PROCEDURES ET DE FONCTIONS
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseProcCallArgs : parser la liste d'arguments '(' expr (, expr) ')'.
  Convention near cdecl, push gauche -> droite :
    - parametre valeur : evalue -> AX, PUSH AX
    - parametre VAR    : adresse -> BX via LEA, PUSH BX
  Le site appelant nettoie la pile apres le CALL (ADD SP, n*2).
  Retourne le nombre d'arguments pousses.
  -------------------------------------------------------------------------- }
Function ParseProcCallArgs(pi : Integer) : Integer;
Var n_args : Integer;
    is_var : Boolean;
    aname  : TString;
    asi    : Integer;
Begin
  n_args := 0;
  LexExpect('(');
  If cur_tok.val <> ')' Then
  Repeat
    Inc(n_args);
    is_var := False;
    If (pi > 0) And (pi <= proc_count) And
       (n_args <= proc_table^[pi].param_count) Then
      is_var := proc_table^[pi].params[n_args].is_var_par;
    If is_var Then
    Begin
      { Parametre VAR : passer l'adresse de la variable (LEA -> PUSH BX) }
      If cur_tok.kind <> TK_IDENT Then
        ErrorMsg('Parametre VAR : identificateur attendu')
      Else
      Begin
        aname := cur_tok.val;
        LexExpectKind(TK_IDENT);
        asi := SymFind(aname);
        If asi > 0 Then
          GenLoadAddr(asi)   { LEA BX, [addr] }
        Else
          ErrorMsg('Symbole inconnu pour parametre VAR : ' + aname);
        EmitI0('PUSH BX');
      End;
    End
    Else
    Begin
      { Parametre valeur : evaluer l''expression -> AX, puis empiler }
      ParseExpr;
      EmitI0('PUSH AX');
    End;
    If cur_tok.val = ',' Then LexNext Else Break;
  Until False;
  LexExpect(')');
  ParseProcCallArgs := n_args;
End;

{ ============================================================
  TODO 19 - PROCEDURES ET FONCTIONS INTEGREES (STANDARD)
  ============================================================ }

{ --------------------------------------------------------------------------
  IsBuiltinProc : vrai si nom est une procedure standard Modula-2.
  -------------------------------------------------------------------------- }
Function IsBuiltinProc(Const name : TString) : Boolean;
Begin
  IsBuiltinProc :=
    (name = 'INC')     Or (name = 'DEC')     Or
    (name = 'INCL')    Or (name = 'EXCL')    Or
    (name = 'NEW')     Or (name = 'DISPOSE') Or
    (name = 'HALT')    Or (name = 'ASSERT');
End;

{ --------------------------------------------------------------------------
  IsBuiltinFunc : vrai si nom est une fonction standard Modula-2.
  -------------------------------------------------------------------------- }
Function IsBuiltinFunc(Const name : TString) : Boolean;
Begin
  IsBuiltinFunc :=
    (name = 'ABS')      Or (name = 'ODD')      Or
    (name = 'CAP')      Or (name = 'ORD')      Or
    (name = 'CHR')      Or (name = 'LEN')      Or
    (name = 'HIGH')     Or
    (name = 'SHORT')    Or (name = 'LONG')     Or
    (name = 'ENTIER')   Or (name = 'SIZE')     Or
    (name = 'TSIZE')    Or
    (name = 'MIN')      Or (name = 'MAX')      Or
    (name = 'FLOAT')    Or (name = 'TRUNC')    Or
    (name = 'VAL')      Or (name = 'CARDINAL');
End;

{ --------------------------------------------------------------------------
  ParseBuiltinProc : code pour INC DEC INCL EXCL NEW DISPOSE HALT ASSERT.
  Le nom de la procedure a deja ete consomme par l'appelant.
  -------------------------------------------------------------------------- }
Procedure ParseBuiltinProc(Const fname : TString);
Var ti1       : Integer;
    ti2       : Integer;
    si1       : Integer;
    lbl_skip  : TString;
    v_str     : TString;
    exit_code : Integer;
Begin
  LexExpect('(');

  If (fname = 'INC') Or (fname = 'DEC') Then
  Begin
    { INC/DEC(v [, n]) : ajouter/soustraire n (defaut 1) a v }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If si1 = 0 Then
      ErrorMsg('INC/DEC : identificateur inconnu : ' + v_str)
    Else
      GenLoadAddr(si1);              { BX = adresse de v }
    If cur_tok.val = ',' Then
    Begin
      LexNext;
      ti1 := ParseExpr;             { n -> AX }
      If fname = 'INC' Then
        EmitI2('ADD', 'Word Ptr [BX]', 'AX')
      Else
        EmitI2('SUB', 'Word Ptr [BX]', 'AX');
    End
    Else
    Begin
      If fname = 'INC' Then
        EmitI1('INC', 'Word Ptr [BX]')
      Else
        EmitI1('DEC', 'Word Ptr [BX]');
    End;
  End

  Else If (fname = 'INCL') Or (fname = 'EXCL') Then
  Begin
    { INCL(s, e) : ajouter e au SET s  ;  EXCL(s, e) : retirer e du SET s }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If si1 = 0 Then
      ErrorMsg('INCL/EXCL : identificateur inconnu : ' + v_str)
    Else
      GenLoadAddr(si1);              { BX = adresse du SET }
    LexExpect(',');
    ti1 := ParseExpr;               { e -> AX }
    EmitI2('MOV', 'CX', 'AX');
    EmitI2('MOV', 'AX', '1');
    EmitI0('SHL  AX, CL');          { AX = masque de bit e }
    If fname = 'INCL' Then
      EmitI2('OR',  'Word Ptr [BX]', 'AX')
    Else
    Begin
      EmitI1('NOT', 'AX');
      EmitI2('AND', 'Word Ptr [BX]', 'AX');
    End;
  End

  Else If fname = 'NEW' Then
  Begin
    { NEW(p) : allouer sizeof(p^) octets dans le heap interne.              }
    { Appelle _ORT_HEAP_ALLOC(BX = taille) -> AX = near ptr, 0 si echec.  }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If si1 > 0 Then
    Begin
      ti1 := sym_table^[si1].type_idx;
      { Calcul de la taille : sizeof(pointee type) }
      If (ti1 >= 1) And (ti1 <= type_count) And
         (type_table^[ti1].kind = TYK_POINTER) Then
        EmitI2('MOV', 'BX', IntToStr(TypeByteSize(type_table^[ti1].base_idx)))
      Else
        EmitI2('MOV', 'BX', '2');        { fallback : 2 octets }
      EmitI1('CALL', '_ORT_HEAP_ALLOC');
      { Verifier echec (AX = 0) }
      EmitI2('OR',  'AX', 'AX');
      EmitI1('JZ',  '_ORT_NIL_ERR');     { heap sature = erreur fatale }
      { Stocker le near ptr dans p }
      EmitI0('PUSH AX');
      GenLoadAddr(si1);                  { BX = adresse de p }
      EmitI0('POP  AX');
      EmitI2('MOV', 'Word Ptr [BX]', 'AX');
    End
    Else
      ErrorMsg('NEW : pointeur inconnu : ' + v_str);
  End

  Else If fname = 'DISPOSE' Then
  Begin
    { DISPOSE(p) : liberer le bloc heap et mettre p a NIL. }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If si1 > 0 Then
    Begin
      GenLoad(si1);                      { AX = valeur du pointeur }
      EmitI1('CALL', '_ORT_HEAP_FREE'); { stub bump-allocator }
      GenLoadAddr(si1);                  { BX = adresse de p }
      EmitI2('MOV', 'Word Ptr [BX]', '0');  { p := NIL }
    End
    Else
      ErrorMsg('DISPOSE : pointeur inconnu : ' + v_str);
  End

  Else If fname = 'HALT' Then
  Begin
    { HALT[(n)] : terminer le programme
      Modula-2 : HALT sans argument -> code 0
      Oberon   : HALT(n) avec code n }
    If cur_tok.val = ')' Then
    Begin
      { HALT() sans code -> exit 0 }
      EmitI2('MOV', 'AX', '4C00h');
    End
    Else
    Begin
      ti1 := ParseExpr;               { n -> AX }
      EmitI2('MOV', 'AH', '4Ch');
    End;
    EmitI0('INT  21h');
  End

  Else If fname = 'ASSERT' Then
  Begin
    { ASSERT(b [, n]) : si b = FALSE alors HALT avec code n (defaut 1) }
    lbl_skip  := NewLabel;
    exit_code := 1;
    ti1 := ParseExpr;               { b -> AX }
    EmitI2('CMP', 'AX', '0');
    EmitI1('JNE', lbl_skip);
    If cur_tok.val = ',' Then
    Begin
      LexNext;
      If cur_tok.kind = TK_INTEGER Then
      Begin
        exit_code := cur_tok.int_val;
        LexNext;
      End
      Else
      Begin
        ti2 := ParseExpr;           { code -> AX, ignore }
        exit_code := 1;
      End;
    End;
    EmitI2('MOV', 'AX', IntToStr($4C00 + exit_code));
    EmitI0('INT  21h');
    EmitLabel(lbl_skip);
  End

  Else
    ErrorMsg('Procedure integree inconnue : ' + fname);

  LexExpect(')');
End;

{ --------------------------------------------------------------------------
  ParseBuiltinFunc : code pour ABS ODD CAP ORD CHR LEN HIGH SHORT LONG
    SIZE TSIZE MIN MAX FLOAT TRUNC VAL CARDINAL.
  Le nom de la fonction a deja ete consomme par l'appelant.
  Resultat dans AX ; retourne le type_idx.
  -------------------------------------------------------------------------- }
Function ParseBuiltinFunc(Const fname : TString) : Integer;
Var ti1      : Integer;
    si1      : Integer;
    lbl_skip : TString;
    v_str    : TString;
    t_name   : TString;
    si_type  : Integer;
    ti_res   : Integer;
Begin
  ti_res := TYP_INTEGER;
  LexExpect('(');

  If fname = 'ABS' Then
  Begin
    { ABS(x) : valeur absolue de x }
    lbl_skip := NewLabel;
    ti1      := ParseExpr;
    EmitI2('OR',  'AX', 'AX');
    EmitI1('JNS', lbl_skip);
    EmitI1('NEG', 'AX');
    EmitLabel(lbl_skip);
    ti_res := ti1;
  End

  Else If fname = 'ODD' Then
  Begin
    { ODD(x) : vrai si x est impair }
    ti1 := ParseExpr;
    EmitI2('AND', 'AX', '1');
    ti_res := TYP_BOOLEAN;
  End

  Else If fname = 'CAP' Then
  Begin
    { CAP(c) : majuscule du caractere c }
    ti1 := ParseExpr;
    EmitI2('AND', 'AX', '0DFh');
    ti_res := TYP_CHAR;
  End

  Else If fname = 'ORD' Then
  Begin
    { ORD(x) : valeur ordinale de x (CHAR/BOOLEAN -> INTEGER) }
    ti1 := ParseExpr;
    EmitI2('AND', 'AX', '0FFh');
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'CHR' Then
  Begin
    { CHR(n) : convertir un entier en CHAR }
    ti1 := ParseExpr;
    EmitI2('AND', 'AX', '0FFh');
    ti_res := TYP_CHAR;
  End

  Else If fname = 'LEN' Then
  Begin
    { LEN(a [, d]) : nombre d'elements du tableau a (dimension d ignoree) }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If cur_tok.val = ',' Then
    Begin
      LexNext;
      ti1 := ParseExpr;            { dimension optionnelle ignoree }
    End;
    If (si1 > 0) And TypeIsArray(sym_table^[si1].type_idx) Then
      EmitI2('MOV', 'AX',
             IntToStr(type_table^[sym_table^[si1].type_idx].arr_len))
    Else
    Begin
      ErrorMsg('LEN : argument doit etre un tableau');
      EmitI2('MOV', 'AX', '0');
    End;
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'HIGH' Then
  Begin
    { HIGH(a) : index maximal du tableau a (arr_len - 1) }
    v_str := cur_tok.val;
    si1   := SymFind(v_str);
    LexExpectKind(TK_IDENT);
    If (si1 > 0) And TypeIsArray(sym_table^[si1].type_idx) Then
      EmitI2('MOV', 'AX',
             IntToStr(type_table^[sym_table^[si1].type_idx].arr_len - 1))
    Else
    Begin
      ErrorMsg('HIGH : argument doit etre un tableau');
      EmitI2('MOV', 'AX', '0');
    End;
    ti_res := TYP_CARDINAL;
  End

  Else If (fname = 'FLOAT') Or (fname = 'REAL') Then
  Begin
    { FLOAT(i) : convertir entier en reel (stub : resultat entier dans AX) }
    ti1    := ParseExpr;
    EmitComment(' FLOAT : conversion entier->reel (stub sans FPU)');
    ti_res := TYP_REAL;
  End

  Else If fname = 'TRUNC' Then
  Begin
    { TRUNC(r) : convertir reel en entier par troncature (stub) }
    ti1    := ParseExpr;
    EmitComment(' TRUNC : conversion reel->entier (stub sans FPU)');
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'TSIZE' Then
  Begin
    { TSIZE(T) : synonyme de SIZE en Modula-2 }
    t_name  := cur_tok.val;
    si_type := SymFind(t_name);
    LexExpectKind(TK_IDENT);
    { Ignorer les arguments supplementaires optionnels }
    While cur_tok.val = ',' Do
    Begin
      LexNext;
      ti1 := ParseExpr;
    End;
    If (si_type > 0) And (sym_table^[si_type].kind = SK_TYPE) Then
      EmitI2('MOV', 'AX', IntToStr(TypeByteSize(sym_table^[si_type].type_idx)))
    Else
    Begin
      ErrorMsg('TSIZE : type inconnu : ' + t_name);
      EmitI2('MOV', 'AX', '0');
    End;
    ti_res := TYP_CARDINAL;
  End

  Else If fname = 'VAL' Then
  Begin
    { VAL(T, x) : convertir x vers le type T (coercition) }
    t_name  := cur_tok.val;
    si_type := SymFind(t_name);
    LexExpectKind(TK_IDENT);
    LexExpect(',');
    ti1    := ParseExpr;             { x -> AX }
    { La valeur reste dans AX, on assure juste la taille }
    If (si_type > 0) And (sym_table^[si_type].kind = SK_TYPE) Then
      ti_res := sym_table^[si_type].type_idx
    Else
      ti_res := TYP_INTEGER;
    EmitComment(' VAL : coercition de type');
  End

  Else If fname = 'CARDINAL' Then
  Begin
    { CARDINAL(x) : etendre sur 16 bits non signes }
    ti1    := ParseExpr;             { x -> AX }
    EmitI2('AND', 'AX', '0FFFFh');  { masque 16 bits }
    ti_res := TYP_CARDINAL;
  End

  Else If (fname = 'SHORT') Or (fname = 'LONG') Or (fname = 'ENTIER') Then
  Begin
    { SHORT/LONG/ENTIER : conversions numeriques, resultat dans AX }
    ti1    := ParseExpr;
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'SIZE' Then
  Begin
    { SIZE(T) : taille en octets du type T }
    t_name  := cur_tok.val;
    si_type := SymFind(t_name);
    LexExpectKind(TK_IDENT);
    If (si_type > 0) And (sym_table^[si_type].kind = SK_TYPE) Then
      EmitI2('MOV', 'AX', IntToStr(TypeByteSize(sym_table^[si_type].type_idx)))
    Else
    Begin
      ErrorMsg('SIZE : type inconnu : ' + t_name);
      EmitI2('MOV', 'AX', '0');
    End;
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'MIN' Then
  Begin
    { MIN(T) : valeur minimale du type T (stub : 8000h pour INTEGER) }
    t_name := cur_tok.val;
    LexExpectKind(TK_IDENT);
    EmitI2('MOV', 'AX', '8000h');
    ti_res := TYP_INTEGER;
  End

  Else If fname = 'MAX' Then
  Begin
    { MAX(T) : valeur maximale du type T (stub : 7FFFh pour INTEGER) }
    t_name := cur_tok.val;
    LexExpectKind(TK_IDENT);
    EmitI2('MOV', 'AX', '7FFFh');
    ti_res := TYP_INTEGER;
  End

  Else
  Begin
    ErrorMsg('Fonction integree inconnue : ' + fname);
    EmitI2('MOV', 'AX', '0');
  End;

  LexExpect(')');
  ParseBuiltinFunc := ti_res;
End;

{ ============================================================
  TODO 20 - MODULE D'ENTREE/SORTIE (InOut / Terminal / STORAGE)
  ============================================================ }

{ --------------------------------------------------------------------------
  IsStdModuleIdent : vrai si name est un module standard Modula-2.
  -------------------------------------------------------------------------- }
Function IsStdModuleIdent(Const name : TString) : Boolean;
Var i : Integer;
Begin
  If (name = 'InOut') Or (name = 'Terminal') Or (name = 'STORAGE') Or
     (name = 'Out') Or (name = 'In') Or (name = 'Math') Or (name = 'SYSTEM') Then
  Begin
    IsStdModuleIdent := True;
    Exit;
  End;
  For i := 1 To import_count Do
    If (import_table[i].alias = name) Or (import_table[i].mod_name = name) Then
    Begin
      IsStdModuleIdent := True;
      Exit;
    End;
  IsStdModuleIdent := False;
End;

{ --------------------------------------------------------------------------
  GenOutInRuntime : emettre les procedures runtime Out/In dans tmp_file.
  Appelee une fois depuis le programme principal, avant MergeTmpToMain.
  -------------------------------------------------------------------------- }
Procedure GenOutInRuntime;
Begin
  SwitchToTmp;
  EmitSep;
  EmitComment(' ====== RUNTIME InOut / Terminal - MODII86 TODO 20 ====== ');
  EmitBlank;

  { _ORT_WRITESTR : SI = pointeur vers chaine null-terminee, imprime char par char }
  EmitLabel('_ORT_WRITESTR');
  EmitI1('PUSH', 'AX');
  EmitI1('PUSH', 'DX');
  EmitLabel('_ORT_WS_LOOP');
  EmitI2('MOV',  'DL', '[SI]');
  EmitI2('CMP',  'DL', '0');
  EmitI1('JE',   '_ORT_WS_END');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI1('INC',  'SI');
  EmitI1('JMP',  '_ORT_WS_LOOP');
  EmitLabel('_ORT_WS_END');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'AX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_WRITELN : imprimer CR LF }
  EmitLabel('_ORT_WRITELN');
  EmitI1('PUSH', 'AX');
  EmitI1('PUSH', 'DX');
  EmitI2('MOV',  'DL', '0Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Ah');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'AX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_WRITEINT : AX = entier signe 16 bits -> affichage decimal }
  EmitLabel('_ORT_WRITEINT');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI2('XOR',  'SI', 'SI');           { SI = compteur de chiffres empiles }
  EmitI2('OR',   'AX', 'AX');
  EmitI1('JNS',  '_ORT_WI_POS');
  { Negatif : imprimer '-' puis NEG AX }
  EmitI1('NEG',  'AX');
  EmitI1('PUSH', 'AX');
  EmitI2('MOV',  'DL', '2Dh');          { ASCII '-' }
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI0('POP  AX');
  EmitLabel('_ORT_WI_POS');
  EmitI2('MOV',  'BX', '10');
  EmitLabel('_ORT_WI_LOOP');
  EmitI2('XOR',  'DX', 'DX');
  EmitI1('DIV',  'BX');                 { AX = quotient, DX = chiffre }
  EmitI0('PUSH DX');
  EmitI1('INC',  'SI');
  EmitI2('OR',   'AX', 'AX');
  EmitI1('JNZ',  '_ORT_WI_LOOP');
  EmitLabel('_ORT_WI_PRINT');
  EmitI0('POP  DX');
  EmitI2('ADD',  'DL', '30h');          { '0' + chiffre }
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI1('DEC',  'SI');
  EmitI1('JNZ',  '_ORT_WI_PRINT');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_READCHAR : lire un caractere avec echo dans AL }
  EmitLabel('_ORT_READCHAR');
  EmitI2('MOV',  'AH', '1');
  EmitI0('INT  21h');
  EmitI2('XOR',  'AH', 'AH');
  EmitI0('RET');
  EmitBlank;

  { _ORT_READINT : lire une ligne, la convertir en entier signe -> AX }
  { Utilise _OV_INBUF comme tampon DOS AH=0Ah. }
  EmitLabel('_ORT_READINT');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI2('MOV',  'Byte Ptr [_OV_INBUF]', '126');
  EmitI2('LEA',  'DX', '[_OV_INBUF]');
  EmitI2('MOV',  'AH', '0Ah');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Ah');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('LEA',  'SI', '[_OV_INBUF+2]');
  EmitI2('XOR',  'BX', 'BX');          { BX = accumulateur }
  EmitI2('XOR',  'DX', 'DX');          { DX = signe (0=positif) }
  EmitI2('CMP',  'Byte Ptr [SI]', '2Dh');  { ''-'' }
  EmitI1('JNE',  '_ORT_RI_LOOP');
  EmitI2('MOV',  'DX', '1');
  EmitI1('INC',  'SI');
  EmitLabel('_ORT_RI_LOOP');
  EmitI2('MOV',  'AL', '[SI]');
  EmitI2('CMP',  'AL', '30h');          { ''0'' }
  EmitI1('JB',   '_ORT_RI_DONE');
  EmitI2('CMP',  'AL', '39h');          { ''9'' }
  EmitI1('JA',   '_ORT_RI_DONE');
  EmitI2('SUB',  'AL', '30h');
  EmitI2('XOR',  'AH', 'AH');
  EmitI0('PUSH AX');
  EmitI2('MOV',  'AX', 'BX');
  EmitI2('MOV',  'CX', '10');
  EmitI0('MUL  CX');
  EmitI0('POP  CX');
  EmitI2('ADD',  'AX', 'CX');
  EmitI2('MOV',  'BX', 'AX');
  EmitI1('INC',  'SI');
  EmitI1('JMP',  '_ORT_RI_LOOP');
  EmitLabel('_ORT_RI_DONE');
  EmitI2('MOV',  'AX', 'BX');
  EmitI2('OR',   'DX', 'DX');
  EmitI1('JZ',   '_ORT_RI_OK');
  EmitI1('NEG',  'AX');
  EmitLabel('_ORT_RI_OK');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_READSTR : lire une ligne dans le tampon pointe par BX (null-termine) }
  { Lit via DOS AH=0Ah dans _OV_INBUF, copie ensuite dans [BX]. }
  EmitLabel('_ORT_READSTR');
  EmitI1('PUSH', 'AX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitI2('MOV',  'DI', 'BX');           { DI = destination }
  EmitI2('MOV',  'Byte Ptr [_OV_INBUF]', '126');
  EmitI2('LEA',  'DX', '[_OV_INBUF]');
  EmitI2('MOV',  'AH', '0Ah');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Ah');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('LEA',  'SI', '[_OV_INBUF+2]');
  EmitI2('XOR',  'AH', 'AH');
  EmitI2('MOV',  'AL', '[_OV_INBUF+1]');
  EmitI2('MOV',  'CX', 'AX');           { CX = nb de chars lus }
  EmitLabel('_ORT_RS_COPY');
  EmitI2('OR',   'CX', 'CX');
  EmitI1('JZ',   '_ORT_RS_DONE');
  EmitI2('MOV',  'AL', '[SI]');
  EmitI2('MOV',  '[DI]', 'AL');
  EmitI1('INC',  'SI');
  EmitI1('INC',  'DI');
  EmitI1('DEC',  'CX');
  EmitI1('JMP',  '_ORT_RS_COPY');
  EmitLabel('_ORT_RS_DONE');
  EmitI2('MOV',  'Byte Ptr [DI]', '0');  { null-terminate }
  EmitI1('POP',  'DI');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'AX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_BOUNDS_ERR : sortie avec code 2 (debordement tableau) }
  EmitLabel('_ORT_BOUNDS_ERR');
  EmitI2('MOV',  'AX', '4C02h');
  EmitI0('INT  21h');
  EmitBlank;

  { _ORT_NIL_ERR : acces par un pointeur NIL -> exit code 3 }
  EmitLabel('_ORT_NIL_ERR');
  EmitI2('MOV',  'AX', '4C03h');
  EmitI0('INT  21h');
  EmitBlank;

  { _ORT_HEAP_ALLOC : allouer BX octets dans le heap interne (bump allocator).  }
  { Entree  : BX = nombre d'octets a allouer (aligne sur 2 par la routine).     }
  { Sortie  : AX = near ptr vers le bloc alloue, ou 0 si heap sature.           }
  EmitLabel('_ORT_HEAP_ALLOC');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'DX');
  { Aligner BX sur 2 }
  EmitI2('ADD',  'BX', '1');
  EmitI2('AND',  'BX', '0FFFEh');
  { AX = ptr courant }
  EmitI2('MOV',  'AX', '[_OV_HEAP_PTR]');
  { DX = AX + BX (nouvelle position) }
  EmitI2('MOV',  'DX', 'AX');
  EmitI2('ADD',  'DX', 'BX');
  { Verifier debordement : DX > OFFSET _OV_HEAP_BUF + 4096 }
  EmitI2('CMP',  'DX', 'OFFSET _OV_HEAP_BUF + 4096');
  EmitI1('JA',   '_ORT_HA_OOM');
  { Mettre a jour le pointeur }
  EmitI2('MOV',  '[_OV_HEAP_PTR]', 'DX');
  EmitI1('JMP',  '_ORT_HA_OK');
  EmitLabel('_ORT_HA_OOM');
  EmitI2('XOR',  'AX', 'AX');          { retourner 0 = echec }
  EmitLabel('_ORT_HA_OK');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _ORT_HEAP_FREE : stub - liberer bloc pointe par AX (bump = on ne libere pas) }
  { L'appelant est charge de mettre le pointeur a NIL apres l'appel.             }
  EmitLabel('_ORT_HEAP_FREE');
  EmitI0('RET');
  EmitBlank;

  SwitchToMain;
End;

{ --------------------------------------------------------------------------
  ParseStdModuleExpr : module.membre utilise dans un contexte d'expression.
  Gere uniquement In.Done (BOOLEAN).
  Le jeton courant est le nom du module.
  -------------------------------------------------------------------------- }
Function ParseStdModuleExpr : Integer;
Var modname  : TString;
    methname : TString;
Begin
  modname := cur_tok.val;
  LexNext;
  LexExpect('.');
  methname := cur_tok.val;
  LexExpectKind(TK_IDENT);
  ParseStdModuleExpr := TYP_WORD;
  If (modname = 'In') And (methname = 'Done') Then
  Begin
    EmitI2('MOV', 'AX', '[_OV_IN_DONE]');
    ParseStdModuleExpr := TYP_BOOLEAN;
  End

  { ---- TODO 23 : Math.xxx -> stub FPU ---- }
  Else If (modname = 'Math') Then
  Begin
    EmitComment(' Math.' + methname + '(x) : stub - FPU non supporte - retourne 0');
    If cur_tok.val = '(' Then
    Begin
      LexNext;
      If cur_tok.val <> ')' Then
      Begin
        ParseExpr;
        While cur_tok.val = ',' Do
        Begin
          LexNext;
          ParseExpr;
        End;
      End;
      LexExpect(')');
    End;
    EmitI2('XOR', 'AX', 'AX');
    ParseStdModuleExpr := TYP_REAL;
  End

  { ---- TODO 23 : SYSTEM.ADR / SYSTEM.VAL / SYSTEM.BIT ---- }
  Else If modname = 'SYSTEM' Then
  Begin
    If methname = 'ADR' Then
    Begin
      LexExpect('(');
      ParseExpr;
      LexExpect(')');
      EmitComment(' SYSTEM.ADR : adresse en AX (approximation via valeur)');
      ParseStdModuleExpr := TYP_INTEGER;
    End
    Else If methname = 'VAL' Then
    Begin
      LexExpect('(');
      ParseTypeRef;
      LexExpect(',');
      ParseExpr;
      LexExpect(')');
      EmitComment(' SYSTEM.VAL : transtypage - valeur dans AX');
      ParseStdModuleExpr := TYP_INTEGER;
    End
    Else If methname = 'BIT' Then
    Begin
      LexExpect('(');
      ParseExpr;
      EmitI1('PUSH', 'AX');
      LexExpect(',');
      ParseExpr;
      EmitI2('MOV', 'CX', 'AX');
      EmitI1('POP',  'AX');
      EmitI2('SHR',  'AX', 'CL');
      EmitI2('AND',  'AX', '1');
      LexExpect(')');
      ParseStdModuleExpr := TYP_BOOLEAN;
    End
    Else
    Begin
      EmitComment(' SYSTEM.' + methname + ' : stub expression');
      If cur_tok.val = '(' Then
      Begin
        LexNext;
        If cur_tok.val <> ')' Then
        Begin
          ParseExpr;
          While cur_tok.val = ',' Do
          Begin
            LexNext;
            ParseExpr;
          End;
        End;
        LexExpect(')');
      End;
      EmitI2('XOR', 'AX', 'AX');
      ParseStdModuleExpr := TYP_INTEGER;
    End;
  End

  Else
    ErrorMsg(modname + '.' + methname + ' : inutilisable dans une expression');
End;

{ --------------------------------------------------------------------------
  ParseStdModuleCall : InOut.xxx / Terminal.xxx / Out.xxx / In.xxx en position instruction.
  Le jeton courant est le nom du module.
  -------------------------------------------------------------------------- }
Procedure ParseStdModuleCall;
Var modname  : TString;
    methname : TString;
    si_var   : Integer;
    vname    : TString;
    bs       : Integer;
Begin
  modname := cur_tok.val;
  LexNext;                        { consommer 'Out' ou 'In' }
  LexExpect('.');
  methname := cur_tok.val;
  LexExpectKind(TK_IDENT);

  If (modname = 'Out') Or (modname = 'InOut') Then
  Begin
    If (methname = 'Ln') Or (methname = 'WriteLn') Then
    Begin
      EmitI1('CALL', '_ORT_WRITELN');
    End
    Else If (methname = 'Open') Or (methname = 'OpenOutput') Then
    Begin
      { InOut.OpenOutput / Out.Open : rien a faire en DOS (stdout toujours disponible) }
    End
    Else If (methname = 'Char') Or (methname = 'WriteChar') Then
    Begin
      LexExpect('(');
      ParseExpr;                    { c -> AX }
      LexExpect(')');
      EmitI2('MOV', 'DL', 'AL');
      EmitI2('MOV', 'AH', '2');
      EmitI0('INT  21h');
    End
    Else If (methname = 'String') Or (methname = 'WriteString') Then
    Begin
      LexExpect('(');
      ParseExpr;                    { s -> AX (pointeur null-termine) }
      LexExpect(')');
      EmitI2('MOV', 'SI', 'AX');
      EmitI1('CALL', '_ORT_WRITESTR');
    End
    Else If (methname = 'Int') Or (methname = 'WriteInt') Or (methname = 'WriteCard') Then
    Begin
      LexExpect('(');
      ParseExpr;                    { r -> stub }
      LexExpect(',');
      ParseExpr;                    { w -> stub }
      LexExpect(')');
      EmitComment(' Out.Real : emulation REAL non implementee (TODO 21+)');
    End
    Else
      ErrorMsg('InOut/Out : methode inconnue : ' + methname);
  End

  { Modula-2 Terminal : Write, WriteLn, Read }
  Else If modname = 'Terminal' Then
  Begin
    If methname = 'WriteLn' Then
    Begin
      EmitI1('CALL', '_ORT_WRITELN');
    End
    Else If methname = 'Write' Then
    Begin
      LexExpect('(');
      ParseExpr;                    { c -> AX }
      LexExpect(')');
      EmitI2('MOV', 'DL', 'AL');
      EmitI2('MOV', 'AH', '2');
      EmitI0('INT  21h');
    End
    Else If methname = 'Read' Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      si_var := SymFind(vname);
      LexExpectKind(TK_IDENT);
      LexExpect(')');
      EmitI1('CALL', '_ORT_READCHAR');
      EmitI2('XOR',  'AH', 'AH');
      If si_var > 0 Then
        GenStore(si_var)
      Else
        ErrorMsg('Terminal.Read : variable inconnue : ' + vname);
    End
    Else
      ErrorMsg('Terminal : methode inconnue : ' + methname);
  End

  { Modula-2 STORAGE : ALLOCATE, DEALLOCATE }
  Else If modname = 'STORAGE' Then
  Begin
    If (methname = 'ALLOCATE') Or (methname = 'NEW') Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      si_var := SymFind(vname);
      LexExpectKind(TK_IDENT);
      LexExpect(',');
      ParseExpr;                    { taille -> AX }
      LexExpect(')');
      EmitI2('MOV', 'BX', 'AX');
      EmitI1('CALL', '_ORT_HEAP_ALLOC');
      If si_var > 0 Then
        GenStore(si_var)
      Else
        ErrorMsg('STORAGE.ALLOCATE : variable inconnue : ' + vname);
    End
    Else If (methname = 'DEALLOCATE') Or (methname = 'DISPOSE') Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      LexExpectKind(TK_IDENT);
      LexExpect(',');
      ParseExpr;
      LexExpect(')');
      EmitComment(' STORAGE.DEALLOCATE : stub (heap bump, pas de liberation)');
    End
    Else
      ErrorMsg('STORAGE : methode inconnue : ' + methname);
  End

  Else If (modname = 'In') Or (modname = 'InOut') Then
  Begin
    If (methname = 'Open') Or (methname = 'OpenInput') Then
    Begin
      EmitI2('MOV', 'Word Ptr [_OV_IN_DONE]', '1');
    End
    Else If (methname = 'Char') Or (methname = 'ReadChar') Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      si_var := SymFind(vname);
      LexExpectKind(TK_IDENT);
      LexExpect(')');
      EmitI1('CALL', '_ORT_READCHAR');
      EmitI2('XOR',  'AH', 'AH');
      If si_var > 0 Then
        GenStore(si_var)
      Else
        ErrorMsg('In.Char : variable inconnue : ' + vname);
      EmitI2('MOV', 'Word Ptr [_OV_IN_DONE]', '1');
    End
    Else If (methname = 'Int') Or (methname = 'ReadInt') Or (methname = 'ReadCard') Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      si_var := SymFind(vname);
      LexExpectKind(TK_IDENT);
      LexExpect(')');
      EmitI1('CALL', '_ORT_READINT');
      If si_var > 0 Then
        GenStore(si_var)
      Else
        ErrorMsg('In.Int : variable inconnue : ' + vname);
      EmitI2('MOV', 'Word Ptr [_OV_IN_DONE]', '1');
    End
    Else If (methname = 'String') Or (methname = 'ReadString') Then
    Begin
      LexExpect('(');
      vname  := cur_tok.val;
      si_var := SymFind(vname);
      LexExpectKind(TK_IDENT);
      LexExpect(')');
      If si_var > 0 Then
      Begin
        bs := TypeByteSize(sym_table^[si_var].type_idx);
        If bs < 2 Then bs := 128;
        GenLoadAddr(si_var);         { BX = adresse de la variable chaine }
        EmitI1('CALL', '_ORT_READSTR');
      End
      Else
        ErrorMsg('In.String : variable inconnue : ' + vname);
      EmitI2('MOV', 'Word Ptr [_OV_IN_DONE]', '1');
    End
    Else
      ErrorMsg('InOut/In : methode inconnue : ' + methname);
  End

  { ---- TODO 23 : Math.xxx(...) en position instruction : stub FPU ---- }
  Else If modname = 'Math' Then
  Begin
    EmitComment(' Math.' + methname + '() : stub instruction - FPU non supporte');
    If cur_tok.val = '(' Then
    Begin
      LexNext;
      If cur_tok.val <> ')' Then
      Begin
        ParseExpr;
        While cur_tok.val = ',' Do
        Begin
          LexNext;
          ParseExpr;
        End;
      End;
      LexExpect(')');
    End;
  End

  { ---- TODO 23 : SYSTEM.MOVE / SYSTEM.xxx en position instruction ---- }
  Else If modname = 'SYSTEM' Then
  Begin
    If methname = 'MOVE' Then
    Begin
      LexExpect('(');
      ParseExpr;
      EmitI2('MOV', 'SI', 'AX');
      LexExpect(',');
      ParseExpr;
      EmitI2('MOV', 'DI', 'AX');
      LexExpect(',');
      ParseExpr;
      EmitI2('MOV', 'CX', 'AX');
      LexExpect(')');
      EmitI1('PUSH', 'DS');
      EmitI0('POP  ES');
      EmitI0('REP  MOVSB');
    End
    Else
    Begin
      EmitComment(' SYSTEM.' + methname + ' : stub instruction');
      If cur_tok.val = '(' Then
      Begin
        LexNext;
        If cur_tok.val <> ')' Then
        Begin
          ParseExpr;
          While cur_tok.val = ',' Do
          Begin
            LexNext;
            ParseExpr;
          End;
        End;
        LexExpect(')');
      End;
    End;
  End

  Else
    ErrorMsg('Module inconnu : ' + modname);
End;

{ ============================================================
  TODO 23 - CLAUSE IMPORT
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseImportSection : parser les clauses IMPORT / FROM ... IMPORT du module Modula-2.
  Deux formes :
    IMPORT [alias :=] ModName (, [alias :=] ModName)* ;
    FROM ModName IMPORT ident (, ident)* ;
  -------------------------------------------------------------------------- }
Procedure ParseImportSection;
Var alias   : TString;
    modname : TString;
    ident   : TString;
    dummy   : Integer;
Begin
  If cur_tok.val = 'FROM' Then
  Begin
    { FROM ModName IMPORT ident (, ident)* ; }
    LexNext;                           { consommer 'FROM' }
    modname := cur_tok.val;
    LexExpectKind(TK_IDENT);
    LexExpect('IMPORT');
    { Enregistrer le module }
    If import_count < MAX_IMPORT Then
    Begin
      Inc(import_count);
      import_table[import_count].mod_name := modname;
      import_table[import_count].alias    := modname;
    End;
    dummy := SymEnter(modname, SK_MODULE, SC_GLOBAL, 0);
    { Enregistrer chaque identificateur importe directement }
    Repeat
      ident := cur_tok.val;
      LexExpectKind(TK_IDENT);
      { L'ident est enregistre comme alias direct dans la portee courante }
      dummy := SymEnter(ident, SK_MODULE, SC_GLOBAL, 0);
      If cur_tok.val = ',' Then
        LexNext
      Else
        Break;
    Until False;
    LexExpect(';');
  End
  Else
  Begin
    { IMPORT [alias :=] ModName (, ...)* ; }
    LexExpect('IMPORT');
    Repeat
      alias   := cur_tok.val;
      LexExpectKind(TK_IDENT);
      If cur_tok.val = ':=' Then
      Begin
        LexNext;
        modname := cur_tok.val;
        LexExpectKind(TK_IDENT);
      End
      Else
        modname := alias;
      If import_count < MAX_IMPORT Then
      Begin
        Inc(import_count);
        import_table[import_count].mod_name := modname;
        import_table[import_count].alias    := alias;
      End
      Else
        ErrorMsg('Table des imports saturee');
      dummy := SymEnter(alias, SK_MODULE, SC_GLOBAL, 0);
      If cur_tok.val = ',' Then
        LexNext
      Else
        Break;
    Until False;
    LexExpect(';');
  End;
End;

{ --------------------------------------------------------------------------
  ParseExportSection : parser EXPORT [QUALIFIED] ident (, ident)* ; (Modula-2).
  -------------------------------------------------------------------------- }
Procedure ParseExportSection;
Var ident   : TString;
    is_qual : Boolean;
Begin
  LexExpect('EXPORT');
  is_qual := False;
  If cur_tok.val = 'QUALIFIED' Then
  Begin
    is_qual := True;
    LexNext;
  End;
  Repeat
    ident := cur_tok.val;
    LexExpectKind(TK_IDENT);
    { TODO : marquer le symbole comme exporte }  { is_qual -> acces qualifie }
    If cur_tok.val = ',' Then
      LexNext
    Else
      Break;
  Until False;
  LexExpect(';');
End;


{ --------------------------------------------------------------------------
  ParseFormalParams : parser la liste de parametres formels.
  FormalParams = '(' [ [VAR] IdentList ':' T (; [VAR] IdentList ':' T) ] ')'
  Les parametres sont inscrits dans proc_table et sym_table.
  Convention near cdecl : BP+4 = 1er param, BP+6 = 2e, etc.
  -------------------------------------------------------------------------- }
Procedure ParseFormalParams(pi : Integer);
Var is_var  : Boolean;
    names   : Array[1..MAX_PARAM] of TString;
    nnames  : Integer;
    ti      : Integer;
    k       : Integer;
    n_par   : Integer;
    ofs_fix : Integer;
    si_fix  : Integer;
Begin
  LexExpect('(');
  While cur_tok.val <> ')' Do
  Begin
    is_var := False;
    If cur_tok.val = 'VAR' Then
    Begin
      is_var := True;
      LexNext;
    End;
    { Collecter la liste d'identificateurs }
    nnames   := 1;
    names[1] := cur_tok.val;
    LexExpectKind(TK_IDENT);
    While cur_tok.val = ',' Do
    Begin
      LexNext;
      If nnames < MAX_PARAM Then
      Begin
        Inc(nnames);
        names[nnames] := cur_tok.val;
      End;
      LexExpectKind(TK_IDENT);
    End;
    LexExpect(':');
    ti := ParseTypeRef;
    For k := 1 To nnames Do
      ProcAddParam(pi, names[k], ti, is_var);
    { Separateur ';' entre groupes de parametres }
    If cur_tok.val = ';' Then
      LexNext
    Else If cur_tok.val <> ')' Then
      Break;
  End;
  LexExpect(')');

  { Fixup des offsets BP : convention push gauche->droite.                }
  { Les args sont pousses L->R ; le 1er arg termine a l'offset le plus    }
  { eleve (BP + 4 + (n-1)*2), le dernier arg a BP+4.                       }
  { param[k].bp_offset := 4 + (n_par - k) * 2                             }
  n_par := proc_table^[pi].param_count;
  For k := 1 To n_par Do
  Begin
    ofs_fix := 4 + (n_par - k) * 2;
    proc_table^[pi].params[k].bp_offset := ofs_fix;
    { Mettre a jour l'entree sym_table correspondante }
    si_fix := SymFind(proc_table^[pi].params[k].name);
    If si_fix > 0 Then
      sym_table^[si_fix].bp_offset := ofs_fix;
  End;
End;

{ --------------------------------------------------------------------------
  ParseProcDecl : parser une declaration de procedure / fonction complete.
  PROCEDURE [*] name [(params)] [: T] ;
  [ CONST ... ] [ TYPE ... ] [ VAR ... ]
  BEGIN StatementSeq END name ;
  Le corps de la procedure est emis dans tmp_file.
  -------------------------------------------------------------------------- }
Procedure ParseProcDecl;
Var pname     : TString;
    is_export : Boolean;
    pi        : Integer;
    ret_ti    : Integer;
    local_off : Integer;
    save_ret  : TString;
    save_pidx : Integer;
    end_name  : TString;
    si_p      : Integer;
Begin
  LexExpect('PROCEDURE');

  { Export marker '*' }
  is_export := False;
  If cur_tok.val = '*' Then
  Begin
    is_export := True;
    LexNext;
  End;

  pname := cur_tok.val;
  LexExpectKind(TK_IDENT);

  { Enregistrer dans proc_table + sym_table }
  ret_ti := 0;
  pi     := ProcEnter(pname, 0, is_export);
  If pi = 0 Then Exit;

  { Ouvrir une portee pour les parametres et locals }
  ScopeEnter;

  { Parametres formels }
  If cur_tok.val = '(' Then
    ParseFormalParams(pi);

  { Type de retour facultatif }
  If cur_tok.val = ':' Then
  Begin
    LexNext;
    ret_ti := ParseTypeRef;
    proc_table^[pi].ret_type_idx := ret_ti;
    { Mettre a jour le symbole dans sym_table }
    If pi > 0 Then
    Begin
      si_p := SymFind(pname);
      If si_p > 0 Then
        sym_table^[si_p].type_idx := ret_ti;
    End;
  End;

  LexExpect(';');

  { Declarations locales (CONST TYPE VAR), dans l'ordre }
  local_off := 0;
  If cur_tok.val = 'CONST' Then ParseConstSection;
  If cur_tok.val = 'TYPE'  Then ParseTypeSection;
  If cur_tok.val = 'VAR'   Then ParseVarSection(True, local_off);
  { Support des procedures imbriquees : boucle sur PROCEDURE }
  While cur_tok.val = 'PROCEDURE' Do
    ParseProcDecl;

  { Ici local_size est connu -> emettre le prologue dans tmp_file }
  save_pidx   := cur_proc_idx;
  cur_proc_idx := pi;
  save_ret    := cur_ret_lbl;
  cur_ret_lbl := OP_PFX + AsmIdent(module_name) + '_' + AsmIdent(pname) + '_RET';

  SwitchToTmp;
  GenProcPrologue(pi);

  { Corps }
  LexExpect('BEGIN');
  ParseStatementSeq;

  { Epilogue : label de retour }
  EmitLabel(cur_ret_lbl);
  GenProcEpilogue(pi);
  SwitchToMain;

  { Fermer la portee }
  cur_proc_idx := save_pidx;
  cur_ret_lbl  := save_ret;
  ScopeLeave;

  { END name ; }
  LexExpect('END');
  end_name := cur_tok.val;
  If cur_tok.kind = TK_IDENT Then
  Begin
    If end_name <> pname Then
      ErrorMsg('Nom de fin de procedure incorrect : ' + end_name +
               ' (attendu : ' + pname + ')');
    LexNext;
  End;
  LexExpect(';');
End;

{ ============================================================
  TODO 25 - INTEGRATION FINALE : ParseModule
  ============================================================ }

{ --------------------------------------------------------------------------
  FlushStringLiterals : rouvrir le segment _DATA apres le code et y injecter
  toutes les chaines litterales accumulees dans str_file.
  Appele depuis ParseModule apres GenCodeFooter, avant GenEndDirective.
  -------------------------------------------------------------------------- }
Procedure FlushStringLiterals;
Var line : String[255];
Begin
  Close(str_file);
  Assign(str_file, str_fname);
  Reset(str_file);
  If Eof(str_file) Then
  Begin
    Close(str_file);
    Erase(str_file);
    Exit;
  End;
  SwitchToMain;
  EmitBlank;
  EmitComment(' ----- Chaines litterales differees (TODO 25) -----');
  Emit('_DATA           SEGMENT WORD PUBLIC ''DATA''');
  EmitBlank;
  While Not Eof(str_file) Do
  Begin
    ReadLn(str_file, line);
    WriteLn(out_file, line);
  End;
  EmitBlank;
  Emit('_DATA           ENDS');
  EmitBlank;
  Close(str_file);
  Erase(str_file);
End;

{ --------------------------------------------------------------------------
  ParseModule : parser un module Modula-2 complet.
  Syntaxe : DEFINITION|IMPLEMENTATION MODULE name ;
            IMPORT|FROM..IMPORT EXPORT CONST TYPE VAR (Proc)* BEGIN corps END name .
  Gere : en-tetes ASM, emissions DATA/CODE, runtime, corps principal.
  -------------------------------------------------------------------------- }
Procedure ParseModule;
Var dummy_off : Integer;
    mname_end : TString;
    is_def    : Boolean;    { DEFINITION MODULE }
    is_impl   : Boolean;    { IMPLEMENTATION MODULE }
Begin
  is_def  := False;
  is_impl := False;

  { --- En-tete Modula-2 --- }
  If cur_tok.val = 'DEFINITION' Then
  Begin
    is_def := True;
    LexNext;                { consommer DEFINITION }
  End
  Else If cur_tok.val = 'IMPLEMENTATION' Then
  Begin
    is_impl := True;
    LexNext;                { consommer IMPLEMENTATION }
  End;
  LexExpect('MODULE');
  module_name := cur_tok.val;
  LexExpectKind(TK_IDENT);
  LexExpect(';');

  { --- Prologue ASM : commentaire + modele memoire + pile --- }
  GenFileHeader;
  GenModelDirectives;
  GenStackSegment;

  { --- Segment DATA : variables systeme puis declarations utilisateur --- }
  GenDataHeader;
  GenSystemVarsData;

  { --- Clauses IMPORT / FROM ... IMPORT (repetees) --- }
  While (cur_tok.val = 'IMPORT') Or (cur_tok.val = 'FROM') Do
    ParseImportSection;

  { --- Clause EXPORT (DEFINITION MODULE) --- }
  If cur_tok.val = 'EXPORT' Then
    ParseExportSection;

  { --- Sections CONST / TYPE (pas de donnees en DATA) --- }
  While cur_tok.val = 'CONST' Do ParseConstSection;
  While cur_tok.val = 'TYPE'  Do ParseTypeSection;

  { --- Section VAR globale : emise en DATA --- }
  dummy_off := 0;
  If cur_tok.val = 'VAR' Then
    ParseVarSection(False, dummy_off);

  { --- Fermer DATA, ouvrir CODE --- }
  GenDataFooter;
  GenCodeHeader;
  GenStartEntry;

  { --- Routines runtime I/O dans tmp_file --- }
  GenOutInRuntime;

  { --- Ouvrir le fichier de chaines litterales differees --- }
  str_fname := ChangeExtension(src_fname, '.str');
  Assign(str_file, str_fname);
  Rewrite(str_file);

  { --- Declarations de procedures (corps -> tmp_file) --- }
  While cur_tok.val = 'PROCEDURE' Do
    ParseProcDecl;

  { --- Corps du module : BEGIN StatementSeq --- }
  LexExpect('BEGIN');
  ParseStatementSeq;

  { --- Epilogue du point d'entree --- }
  GenStartExit;

  { --- Fusionner les procedures A L'INTERIEUR du segment CODE --- }
  MergeTmpToMain;

  { --- Fermer CODE --- }
  GenCodeFooter;

  { --- Injecter les chaines litterales dans un _DATA rouvert --- }
  FlushStringLiterals;

  { --- END START --- }
  GenEndDirective;

  { --- Verifier le nom de fin : END name . --- }
  LexExpect('END');
  mname_end := cur_tok.val;
  If cur_tok.kind = TK_IDENT Then
  Begin
    If mname_end <> module_name Then
      ErrorMsg('Fin de module incorrecte : attendu ' + module_name
               + ', lu ' + mname_end);
    LexNext;
  End;
  LexExpect('.');
End;

{ ============================================================
  Programme principal
  ============================================================ }

Begin
  { --- Arguments --- }
  ParseArgs;

  { --- Initialisation --- }
  InitTables;
  InitBuiltinTypes;

  { --- Ouverture du source et lancement du lexer --- }
  LexInit(src_fname);  { ouvre src_file, charge le premier token }

  { --- Portee module (niveau 1) --- }
  ScopeEnter;

  { --- Ouverture de la sortie --- }
  Assign(out_file, out_fname);
  Rewrite(out_file);
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur : impossible de creer ', out_fname);
    Close(src_file);
    Halt(1);
  End;
  cur_out := @out_file;

  { --- Ouverture du fichier temporaire (code des procedures) --- }
  Assign(tmp_file, tmp_fname);
  Rewrite(tmp_file);

  { --- Compilation complete : ParseModule gere toute l'emission ASM --- }
  ParseModule;

  { --- Fermeture --- }
  ScopeLeave;  { fermer la portee module }
  LexClose;
  Close(out_file);

  { --- Rapport final (TODO 24) --- }
  If opt_verbose Then
  Begin
    WriteLn;
    WriteLn('=== RAPPORT DE COMPILATION : ', src_fname, ' ===');
    WriteLn('  Lignes     : ', lex_lineno);
    WriteLn('  Tokens     : ', tok_count);
    WriteLn('  Symboles   : ', sym_count);
    WriteLn('  Procedures : ', proc_count);
    WriteLn('  Types      : ', type_count);
    WriteLn('  Constantes : ', const_count);
    WriteLn('  Modules imp: ', import_count);
    WriteLn('  Instructions ASM : ', instr_count);
    WriteLn('  Erreurs    : ', err_count);
    WriteLn('  Avertissements   : ', warn_count);
    WriteLn('  Sortie     : ', out_fname);
    If opt_debug Then
    Begin
      WriteLn;
      TypeDump;
      WriteLn;
      SymDumpVerbose;
    End;
  End;

  FreeTables;

  If err_count > 0 Then
  Begin
    WriteLn(err_count, ' erreur(s) - compilation echouee.');
    Halt(1);
  End
  Else
  Begin
    If opt_verbose Then
      WriteLn('Compilation reussie -> ', out_fname);
  End;
End.
