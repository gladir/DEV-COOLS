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

  { Construire la valeur DB :
    Format BCPL : octet 0 = longueur, puis les octets de la chaine.
    PAS de terminateur nul (contrairement aux chaines C). }
  Str(Length(s), tmp_n);
  out_s    := tmp_n;          { premier octet = longueur }
  in_quote := False;
  For i := 1 To Length(s) Do
  Begin
    c := s[i];
    If (Ord(c) >= 32) And (c <> '''') Then
    Begin
      { Caractere imprimable (hors apostrophe) : ouvrir bloc si necessaire }
      If Not in_quote Then
      Begin
        out_s    := out_s + ', ''';
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
      out_s := out_s + ', ';
      Str(Ord(c), tmp_n);
      out_s := out_s + tmp_n + 'd';
    End;
  End;
  { Fermer le bloc ouvert -- PAS de 0 final (format BCPL avec longueur) }
  If in_quote Then
    out_s := out_s + '''';

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
  ParseManifestSection : parser la section CONST ident = expr ;
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
  Chaque champ est inscrit dans sym_table comme SK_LOCAL avec son offset.
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
      si := SymEnter(names[k], SK_LOCAL, SC_GLOBAL, fti);
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
    ident              -> alias de type (SK_MANIFEST dans sym_table)
    ARRAY  n OF T      -> ParseArrayType
    RECORD ... END     -> ParseRecordType
    POINTER TO T       -> ParsePointerType
    PROCEDURE [(.)] :T -> ParseProcType
  -------------------------------------------------------------------------- }
Function ParseTypeRef:Integer;
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
    If (si > 0) And (sym_table^[si].kind = SK_MANIFEST) Then
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
  Cree un alias de type et l'inscrit comme SK_MANIFEST dans sym_table.
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
  si := SymEnter(tname, SK_MANIFEST, SC_GLOBAL, ti);
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

{ Forward : ParseStatementSeq / ParseStatement / ParseLetDecl utilises dans VALOF (ParseFactor). }
Procedure ParseStatementSeq; Forward;
Procedure ParseStatement; Forward;
Procedure ParseLetDecl; Forward;

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
    { SK_LOCAL, SK_PARAM, SK_LOCAL }
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
      If (ti < 1) Or (type_table^[ti].kind <> TYK_WORD) Then
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
      If (ti < 1) Or ((type_table^[ti].kind <> TYK_WORD) And
                      (type_table^[ti].kind <> TYK_WORD)) Then
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
      If (type_table^[ti].kind = TYK_WORD) And
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
      If (ti < 1) Or (type_table^[ti].kind <> TYK_WORD) Then
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
  ParseFactor : facteur primaire BCPL (TODO 09)
  factor = integer | char | string
         | TRUE (-1) | FALSE (0)
         | tilde-factor  = NOT bit
         | minus-factor  = negation
         | ABS factor    = valeur absolue
         | at-ident      = adresse de
         | bang-factor   = mot indirect
         | ( expr )
         | VALOF bloc
         | ident
  Postfixes : e!n (mot indexe) et e%%n (octet indexe).
  -------------------------------------------------------------------------- }
Function ParseFactor : Integer;
Var ti       : Integer;
    lbl      : TString;
    lbl_end  : TString;
    n_str    : TString;
    si       : Integer;
    bname    : TString;
Begin
  ti := TYP_WORD;

  { Litteraux entiers decimal/octal/hex }
  If cur_tok.kind = TK_INTEGER Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    LexNext;
  End
  Else If cur_tok.kind = TK_CHAR Then
  Begin
    EmitI2('MOV', 'AX', IntToStr(cur_tok.int_val));
    ti := TYP_WORD;
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
    ti := TYP_WORD;
    LexNext;
  End
  Else If cur_tok.kind = TK_STRING Then
  Begin
    lbl := GenStringLitData(cur_tok.val);
    EmitI2('LEA', 'AX', '[' + lbl + ']');
    ti := TypeNewArray(TYP_WORD, Length(cur_tok.val) + 1);
    LexNext;
  End
  Else If cur_tok.val = 'TRUE' Then
  Begin
    EmitI2('MOV', 'AX', '1');
    ti := TYP_WORD;
    LexNext;
  End
  Else If cur_tok.val = 'FALSE' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_WORD;
    LexNext;
  End
  Else If cur_tok.val = 'NIL' Then
  Begin
    EmitI2('MOV', 'AX', '0');
    ti := TYP_WORD;
    LexNext;
  End
  Else If cur_tok.val = '~' Then
  Begin
    LexNext;
    ti := ParseFactor;
    EmitI1('NOT', 'AX');         { BCPL ~ = bitwise NOT (NOT AX) }
  End
  Else If cur_tok.val = '-' Then
  Begin
    { Moins unaire BCPL }
    LexNext;
    ti := ParseFactor;
    EmitI1('NEG', 'AX');
  End
  Else If cur_tok.val = '+' Then
  Begin
    { Plus unaire BCPL (identite) }
    LexNext;
    ti := ParseFactor;
  End
  Else If cur_tok.val = '(' Then
  Begin
    LexNext;
    ti := ParseExpr;
    LexExpect(')');
  End
  { VALOF $( ... RESULTIS expr $) : bloc expression }
  Else If cur_tok.val = 'VALOF' Then
  Begin
    LexNext;
    lbl_end := NewLabel;
    valof_lbl := lbl_end;
    OpenBlock;
    ParseStatementSeq;
    CloseBlock;
    EmitLabel(lbl_end);
    valof_lbl := '';
    ti := TYP_WORD;
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
  ParseTerm : facteurs lies par operateurs de multiplicite BCPL (TODO 10).
  BCPL  : * / MOD REM & << >>
  -------------------------------------------------------------------------- }
Function ParseTerm : Integer;
Var ti   : Integer;
    ti2  : Integer;
    op   : TString;
Begin
  ti := ParseFactor;
  While (cur_tok.val = '*')   Or (cur_tok.val = '/')
     Or (cur_tok.val = 'MOD') Or (cur_tok.val = 'REM')
     Or (cur_tok.val = '&')   Or (cur_tok.val = '<<')
     Or (cur_tok.val = '>>') Do
  Begin
    op := cur_tok.val;
    LexNext;
    If (op = '<<') Or (op = '>>') Then
    Begin
      EmitI0('PUSH AX');
      ti2 := ParseFactor;
      EmitI2('MOV', 'CX', 'AX');
      EmitI0('POP  AX');
      If op = '<<' Then
        EmitI0('SHL  AX, CL')
      Else
        EmitI0('SHR  AX, CL');
    End
    Else
    Begin
      EmitI0('PUSH AX');
      ti2 := ParseFactor;
      EmitI2('MOV', 'CX', 'AX');
      EmitI0('POP  AX');
      If op = '*' Then
        EmitI0('IMUL CX')
      Else If op = '/' Then
      Begin
        EmitI0('CWD');
        EmitI0('IDIV CX');
      End
      Else If (op = 'MOD') Or (op = 'REM') Then
      Begin
        EmitI0('CWD');
        EmitI0('IDIV CX');
        EmitI2('MOV', 'AX', 'DX');
      End
      Else { & }
        EmitI2('AND', 'AX', 'CX');
    End;
    ti := TYP_WORD;
  End;
  ParseTerm := ti;
End;

{ --------------------------------------------------------------------------
  ParseSimpleExpr : termes lies par operateurs additifs BCPL (TODO 10).
  BCPL : + - | EQV XOR  (le signe unaire est dans ParseFactor)
  -------------------------------------------------------------------------- }
Function ParseSimpleExpr : Integer;
Var ti   : Integer;
    ti2  : Integer;
    op   : TString;
Begin
  ti := ParseTerm;
  While (cur_tok.val = '+')   Or (cur_tok.val = '-')
     Or (cur_tok.val = '|')   Or (cur_tok.val = 'EQV')
     Or (cur_tok.val = 'XOR') Do
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI0('PUSH AX');
    ti2 := ParseTerm;
    EmitI2('MOV', 'CX', 'AX');
    EmitI0('POP  AX');
    If      op = '+' Then EmitI2('ADD', 'AX', 'CX')
    Else If op = '-' Then EmitI2('SUB', 'AX', 'CX')
    Else If op = '|' Then EmitI2('OR',  'AX', 'CX')
    Else If op = 'XOR' Then EmitI2('XOR', 'AX', 'CX')
    Else { EQV = XNOR }
    Begin
      EmitI2('XOR', 'AX', 'CX');
      EmitI1('NOT', 'AX');
    End;
    ti := TYP_WORD;
  End;
  ParseSimpleExpr := ti;
End;

{ --------------------------------------------------------------------------
  ParseExpr : relations BCPL (TODO 10).
  BCPL : = ~= < <= > >=     Resultat : TRUE=-1  FALSE=0
  -------------------------------------------------------------------------- }
Function ParseExpr:Integer;
Var ti    : Integer;
    ti2   : Integer;
    op    : TString;
    lbl_t : TString;
    lbl_f : TString;
    lbl_e : TString;
Begin
  ti := ParseSimpleExpr;
  If (cur_tok.val = '=')  Or (cur_tok.val = '~=')
  Or (cur_tok.val = '<')  Or (cur_tok.val = '<=')
  Or (cur_tok.val = '>')  Or (cur_tok.val = '>=') Then
  Begin
    op := cur_tok.val;
    LexNext;
    EmitI0('PUSH AX');
    ti2  := ParseSimpleExpr;
    EmitI2('MOV', 'CX', 'AX');
    EmitI0('POP  AX');
    lbl_t := NewLabel;
    lbl_f := NewLabel;
    EmitI2('CMP', 'AX', 'CX');
    If      op = '='  Then EmitI1('JE',  lbl_t)
    Else If op = '~=' Then EmitI1('JNE', lbl_t)
    Else If op = '<'  Then EmitI1('JL',  lbl_t)
    Else If op = '<=' Then EmitI1('JLE', lbl_t)
    Else If op = '>'  Then EmitI1('JG',  lbl_t)
    Else                   EmitI1('JGE', lbl_t);
    EmitI2('MOV', 'AX', '0');
    EmitI1('JMP', lbl_f);
    EmitLabel(lbl_t);
    EmitI2('MOV', 'AX', '0FFFFh');  { TRUE = -1 en BCPL }
    EmitLabel(lbl_f);
    ti := TYP_WORD;
  End;
  { Expression conditionnelle BCPL : cond -> val_vrai, val_faux }
  If cur_tok.val = '->' Then
  Begin
    LexNext;
    lbl_t := NewLabel;   { label branche vraie }
    lbl_e := NewLabel;   { label fin }
    EmitI2('CMP', 'AX', '0');
    EmitI1('JNE', lbl_t);
    { Ici on doit evaluer val_faux mais on a besoin de sauter val_vrai }
    { Schema : cmp->jne lbl_t ; sauter val_vrai }
    { L'ordre BCPL est : -> val_vrai , val_faux }
    { On evalue d'abord val_vrai (si vrai suit immediatement la condition) }
    { => on doit inverser : si faux, sauter a lbl_else }
    lbl_f := NewLabel;   { label branche fausse }
    EmitI1('JMP', lbl_f);
    EmitLabel(lbl_t);
    ti2 := ParseExpr;    { val_vrai -> AX }
    EmitI1('JMP', lbl_e);
    EmitLabel(lbl_f);
    LexExpect(',');
    ti2 := ParseExpr;    { val_faux -> AX }
    EmitLabel(lbl_e);
    ti := TYP_WORD;
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
      If (ti < 1) Or (type_table^[ti].kind <> TYK_WORD) Then
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
      If (ti < 1) Or ((type_table^[ti].kind <> TYK_WORD) And
                      (type_table^[ti].kind <> TYK_WORD)) Then
        ErrorMsg('Acces indexe sur un type non ARRAY');
      el_ti   := type_table^[ti].base_idx;
      el_size := TypeByteSize(el_ti);
      If el_size < 1 Then el_size := 1;
      EmitI0('PUSH BX');              { sauvegarder adresse de base }
      ParseExpr;                       { index -> AX }
      { Verification de bornes }
      If (type_table^[ti].kind = TYK_WORD) And
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
      If (ti < 1) Or (type_table^[ti].kind <> TYK_WORD) Then
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

{ Forwards : ParseStatement et ParseLetDecl necessaires avant leur usage.
  (Deja declares plus haut - conservation du commentaire uniquement) }

{ --------------------------------------------------------------------------
  ParseStatementSeq BCPL : suite de commandes.
  En BCPL les commandes sont separees par point-virgule optionnel.
  On s'arrete sur $-) ou accolade-fermante, ELSE, THEN, ENDCASE, DEFAULT ou EOF.
  -------------------------------------------------------------------------- }
Procedure ParseStatementSeq;
  Function IsSeqStop : Boolean;
  Begin
    IsSeqStop :=
      (cur_tok.val = '$)')     Or (cur_tok.val = '}')
      Or (cur_tok.val = 'ELSE')  Or (cur_tok.val = 'THEN')
      Or (cur_tok.val = 'ENDCASE') Or (cur_tok.val = 'DEFAULT')
      Or (cur_tok.val = 'CASE')                              { evite boucle infinie si CASE inattendu }
      Or (cur_tok.kind = TK_EOF);
  End;
Begin
  { En BCPL le ';' entre commandes est optionnel.
    On boucle tant qu'on n'est pas sur un token d'arret. }
  While Not IsSeqStop Do
  Begin
    ParseStatement;
    If cur_tok.val = ';' Then LexNext;  { separateur optionnel }
  End;
End;

{ --------------------------------------------------------------------------
  ParseIfStmt BCPL : IF cond DO cmd [ELSE cmd]
  En BCPL : IF expr DO commande   (pas de THEN, pas de END)
  La condition est vraie si expression <> 0.
  -------------------------------------------------------------------------- }
Procedure ParseIfStmt;
Var lbl_else : TString;
    lbl_end  : TString;
    ti       : Integer;
Begin
  LexExpect('IF');
  lbl_else := NewLabel;
  lbl_end  := NewLabel;
  ti := ParseExpr;
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_else);
  LexExpect('DO');
  ParseStatement;
  EmitI1('JMP', lbl_end);
  EmitLabel(lbl_else);
  If cur_tok.val = 'ELSE' Then
  Begin
    LexNext;
    ParseStatement;
  End;
  EmitLabel(lbl_end);
End;

{ --------------------------------------------------------------------------
  ParseUnlessStmt BCPL : UNLESS cond DO cmd [ELSE cmd]  (= IF NOT cond DO ...)
  -------------------------------------------------------------------------- }
Procedure ParseUnlessStmt;
Var lbl_else : TString;
    lbl_end  : TString;
    ti       : Integer;
Begin
  LexExpect('UNLESS');
  lbl_else := NewLabel;
  lbl_end  := NewLabel;
  ti := ParseExpr;
  EmitI2('CMP', 'AX', '0');
  EmitI1('JNE', lbl_else);  { sauter si VRAI (= condition UNLESS verifiee) }
  LexExpect('DO');
  ParseStatement;
  EmitI1('JMP', lbl_end);
  EmitLabel(lbl_else);
  If cur_tok.val = 'ELSE' Then
  Begin
    LexNext;
    ParseStatement;
  End;
  EmitLabel(lbl_end);
End;

{ --------------------------------------------------------------------------
  ParseTestStmt BCPL : TEST cond THEN cmd ELSE cmd
  -------------------------------------------------------------------------- }
Procedure ParseTestStmt;
Var lbl_else : TString;
    lbl_end  : TString;
    ti       : Integer;
Begin
  LexExpect('TEST');
  lbl_else := NewLabel;
  lbl_end  := NewLabel;
  ti := ParseExpr;
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_else);
  LexExpect('THEN');
  ParseStatement;
  EmitI1('JMP', lbl_end);
  EmitLabel(lbl_else);
  LexExpect('ELSE');
  ParseStatement;
  EmitLabel(lbl_end);
End;

{ ============================================================
  TODO 13 - INSTRUCTION WHILE / REPEAT / LOOP / EXIT
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseWhileStmt BCPL : WHILE cond DO cmd
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
  EmitI2('CMP', 'AX', '0');
  EmitI1('JE',  lbl_end);
  LexExpect('DO');
  ParseStatement;
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseUntilStmt BCPL : UNTIL cond DO cmd  (= WHILE NOT cond DO ...)
  -------------------------------------------------------------------------- }
Procedure ParseUntilStmt;
Var lbl_top  : TString;
    lbl_end  : TString;
    ti       : Integer;
Begin
  lbl_top := NewLabel;
  lbl_end := NewLabel;
  LexExpect('UNTIL');
  PushLoopLabels(lbl_end, lbl_top);
  EmitLabel(lbl_top);
  ti := ParseExpr;
  EmitI2('CMP', 'AX', '0');
  EmitI1('JNE', lbl_end);   { sortir si condition vraie }
  LexExpect('DO');
  ParseStatement;
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseRepeatStmt BCPL : REPEAT cmd [REPEATWHILE cond | REPEATUNTIL cond]
  Formes :
    REPEAT              : boucle infinie
    REPEAT cmd REPEATWHILE cond : repeter tant que cond vraie
    REPEAT cmd REPEATUNTIL cond : repeter jusqu'a ce que cond vraie
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
  ParseStatement;
  If cur_tok.val = 'REPEATWHILE' Then
  Begin
    LexNext;
    ti := ParseExpr;
    EmitI2('CMP', 'AX', '0');
    EmitI1('JNE', lbl_top);   { continuer si vrai }
  End
  Else If cur_tok.val = 'REPEATUNTIL' Then
  Begin
    LexNext;
    ti := ParseExpr;
    EmitI2('CMP', 'AX', '0');
    EmitI1('JE',  lbl_top);   { continuer si faux }
  End
  Else
  Begin
    { REPEAT seul = boucle infinie }
    EmitI1('JMP', lbl_top);
  End;
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ --------------------------------------------------------------------------
  ParseLoopStmt BCPL : LOOP cmd    (boucle infinie - BREAK en sort)
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
  ParseStatement;
  EmitI1('JMP', lbl_top);
  EmitLabel(lbl_end);
  PopLoopLabels;
End;

{ ============================================================
  TODO 14 - INSTRUCTION FOR
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseForStmt : FOR v := start TO end [BY step] DO StatementSeq END
  Strategie 8086 :
    - SI    = valeur limite (end), calculee une seule fois avant la boucle
    - [v]   = variable de controle (SK_LOCAL ordinal)
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
  Else If sym_table^[si_var].kind <> SK_LOCAL Then
    ErrorMsg('La variable de boucle doit etre une variable locale : ' + vname);

  LexExpect('=');
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

  ParseStatement;

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
  PopLoopLabels;
End;

{ ============================================================
  TODO 14 - COMMANDE SWITCHON BCPL
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseSwitchonStmt : SWITCHON expr INTO $( CASE val: cmds ENDCASE ... DEFAULT: $)

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
Procedure ParseSwitchonStmt;
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
  { SWITCHON expr INTO $( CASE v: cmds ENDCASE ... DEFAULT: cmds $) }
  LexExpect('SWITCHON');
  ti := ParseExpr;
  EmitI2('MOV', 'CX', 'AX');
  lbl_end  := NewLabel;
  lbl_else := NewLabel;
  lbl_disp := NewLabel;
  EmitI1('JMP', lbl_disp);
  LexExpect('INTO');
  OpenBlock;
  arm_cnt := 0;

  While (cur_tok.val <> 'DEFAULT') And (cur_tok.val <> '$)')
     And (cur_tok.val <> '}') And (cur_tok.kind <> TK_EOF) Do
  Begin
    If (cur_tok.val = 'DEFAULT') Or (cur_tok.val = '$)') Or
       (cur_tok.val = '}') Then Break;
    If arm_cnt >= MAX_ARM Then
    Begin
      ErrorMsg('Trop de bras dans CASE (max 16)');
      Break;
    End;
    Inc(arm_cnt);
    arm_lbl[arm_cnt]     := NewLabel;
    arm_lbl_cnt[arm_cnt] := 0;

    { CASE val: [CASE val2:] ... cmds ENDCASE
      Support des CASE labels multiples (fall-through BCPL) }
    Repeat
      LexExpect('CASE');
      lo := ParseConstExprInt;
      hi := lo;
      Inc(arm_lbl_cnt[arm_cnt]);
      If arm_lbl_cnt[arm_cnt] > MAX_LBL Then
      Begin
        ErrorMsg('Trop de valeurs CASE pour un bras (max 8)');
        arm_lbl_cnt[arm_cnt] := MAX_LBL;
      End;
      l := arm_lbl_cnt[arm_cnt];
      lbl_lo[arm_cnt, l]  := lo;
      lbl_hi[arm_cnt, l]  := hi;
      lbl_rng[arm_cnt, l] := False;
      LexExpect(':');
    Until cur_tok.val <> 'CASE';  { plusieurs CASE -> meme bras }

    EmitLabel(arm_lbl[arm_cnt]);
    ParseStatementSeq;
    If cur_tok.val = 'ENDCASE' Then LexNext;
    EmitI1('JMP', lbl_end);
  End;

  { Corps DEFAULT }
  EmitLabel(lbl_else);
  If cur_tok.val = 'DEFAULT' Then
  Begin
    LexNext;
    LexExpect(':');
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
  EmitI1('JMP', lbl_else);
  EmitLabel(lbl_end);
  CloseBlock;
End;

{ ============================================================
  TODO 15 - BLOCS BCPL (deja traites via OpenBlock/CloseBlock)
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
    If (si_t = 0) Or (sym_table^[si_t].kind <> SK_MANIFEST) Then
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
    si_alias := SymEnter(vname, SK_LOCAL,
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
{ --------------------------------------------------------------------------
  ParseStatement BCPL (TODO 11-17).
  Commandes BCPL : IF UNLESS TEST WHILE UNTIL FOR LOOP REPEAT
    SWITCHON BREAK LOOP RETURN RESULTIS FINISH $( bloc $) ou affectation.
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
  Else If cur_tok.val = 'UNLESS' Then
    ParseUnlessStmt
  Else If cur_tok.val = 'TEST' Then
    ParseTestStmt
  Else If cur_tok.val = 'WHILE' Then
    ParseWhileStmt
  Else If cur_tok.val = 'UNTIL' Then
    ParseUntilStmt
  Else If cur_tok.val = 'REPEAT' Then
    ParseRepeatStmt
  Else If cur_tok.val = 'LOOP' Then
    ParseLoopStmt
  Else If cur_tok.val = 'FOR' Then
    ParseForStmt
  Else If cur_tok.val = 'SWITCHON' Then
    ParseSwitchonStmt
  { Bloc : $( cmds $) }
  Else If (cur_tok.val = '$(') Or (cur_tok.val = '{') Then
  Begin
    OpenBlock;
    ParseStatementSeq;
    CloseBlock;
  End
  { BREAK : sortir de la boucle courante (LOOP/WHILE/FOR) }
  Else If cur_tok.val = 'BREAK' Then
  Begin
    LexNext;
    brk := TopBreakLabel;
    If brk = '' Then
      ErrorMsg('BREAK en dehors d''une boucle')
    Else
      EmitI1('JMP', brk);
  End
  { LOOP : passer a l'iteration suivante (= LOOP continue) }
  { En BCPL LOOP = continuer l'iteration = JMP vers le debut }
  { Pas de LexNext ici, c'est dans le dispatch du FOR/WHILE }
  { RETURN : retour de routine, resultat 0 }
  Else If (cur_tok.val = 'RETURN') Or (cur_tok.val = 'FINISH') Then
  Begin
    If cur_tok.val = 'FINISH' Then
    Begin
      LexNext;
      EmitI2('MOV', 'AX', '4C00h');
      EmitI0('INT  21h');
    End
    Else
    Begin
      LexNext;
      EmitI2('XOR', 'AX', 'AX');
      If cur_ret_lbl <> '' Then
        EmitI1('JMP', cur_ret_lbl)
      Else
        EmitI0('RET');
    End;
  End
  { RESULTIS expr : retour de valeur depuis VALOF ou corps de fonction }
  Else If cur_tok.val = 'RESULTIS' Then
  Begin
    LexNext;
    ParseExpr;
    If valof_lbl <> '' Then
      EmitI1('JMP', valof_lbl)
    Else If cur_ret_lbl <> '' Then
      EmitI1('JMP', cur_ret_lbl)    { dans un corps BE, RESULTIS = RETURN avec valeur }
    Else
      ErrorMsg('RESULTIS en dehors d''un VALOF ou d''une fonction');
  End
  { LET : declaration locale dans un bloc }
  Else If cur_tok.val = 'LET' Then
    ParseLetDecl
  Else If cur_tok.kind = TK_IDENT Then
  Begin
    If IsBuiltinProc(cur_tok.val) Then
    Begin
      bname := cur_tok.val;
      LexNext;
      ParseBuiltinProc(bname);
    End
    Else
    Begin
      call_si := SymFind(cur_tok.val);
      If (call_si > 0) And (sym_table^[call_si].kind = SK_PROC) Then
      Begin
        call_pi := sym_table^[call_si].proc_idx;
        LexNext;
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
  End
  Else If cur_tok.kind <> TK_EOF Then
  Begin
    { Token non reconnu comme commande : eviter boucle infinie }
    ErrorMsg('Commande BCPL inattendue : ' + cur_tok.val);
    LexNext;
  End;
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
  { Procedures BCPL integrees }
  IsBuiltinProc :=
    (name = 'WRITES')    Or (name = 'WRITEF')  Or
    (name = 'WRITEN')    Or (name = 'WRITECH') Or
    (name = 'NEWLINE')   Or (name = 'STOP')    Or
    (name = 'HALT');
End;

{ --------------------------------------------------------------------------
  IsBuiltinFunc : vrai si nom est une fonction standard Modula-2.
  -------------------------------------------------------------------------- }
Function IsBuiltinFunc(Const name : TString) : Boolean;
Begin
  { Fonctions BCPL integrees }
  IsBuiltinFunc :=
    (name = 'ABS')    Or (name = 'READCH')  Or
    (name = 'READN')  Or (name = 'READS')   Or
    (name = 'GETBYTE') Or (name = 'PUTBYTE');
End;

{ --------------------------------------------------------------------------
  ParseBuiltinProc BCPL : WRITES WRITEF WRITEN WRITECH NEWLINE STOP HALT.
  Le nom a deja ete consomme par l'appelant.
  -------------------------------------------------------------------------- }
Procedure ParseBuiltinProc(Const fname : TString);
Var ti1       : Integer;
    ti2       : Integer;
    lbl_skip  : TString;
    exit_code : Integer;
    n_args    : Integer;
Begin
  { Consommer la parenthese ouvrante -- toutes les proc. BCPL utilisent () }
  LexExpect('(');

  If (fname = 'WRITES') Then
  Begin
    { WRITES(str) : afficher la chaine BCPL pointee par AX -> SI }
    ti1 := ParseExpr;                  { adresse chaine -> AX }
    EmitI2('MOV', 'SI', 'AX');
    EmitI1('CALL', '_BRT_WRITES');
  End

  Else If fname = 'WRITEN' Then
  Begin
    { WRITEN(n) : afficher l'entier n }
    ti1 := ParseExpr;                  { entier -> AX }
    EmitI1('CALL', '_BRT_WRITEN');
  End

  Else If fname = 'WRITECH' Then
  Begin
    { WRITECH(c) : afficher le caractere c (code ASCII dans AX) }
    ti1 := ParseExpr;                  { code char -> AX }
    EmitI1('PUSH', 'AX');
    EmitI1('PUSH', 'DX');
    EmitI2('MOV',  'DL', 'AL');
    EmitI2('MOV',  'AH', '2');
    EmitI0('INT  21h');
    EmitI1('POP',  'DX');
    EmitI1('POP',  'AX');
  End

  Else If fname = 'NEWLINE' Then
  Begin
    { NEWLINE() : emettre CR LF }
    EmitI1('CALL', '_BRT_NEWLINE');
  End

  Else If fname = 'WRITEF' Then
  Begin
    { WRITEF(fmt [, arg1, arg2, ...]) : formateur BCPL (stub) }
    ti1 := ParseExpr;                  { format -> AX }
    n_args := 0;
    While cur_tok.val = ',' Do
    Begin
      LexNext;
      EmitI1('PUSH', 'AX');            { sauver format si premier arg }
      ti2 := ParseExpr;               { arg -> AX }
      EmitI0('PUSH AX');
      Inc(n_args);
    End;
    { Pour l'instant : juste afficher la chaine de format (stub) }
    If n_args > 0 Then
    Begin
      EmitI2('ADD', 'SP', IntToStr(n_args * 2));
      EmitI1('POP', 'AX');
    End;
    EmitI2('MOV', 'SI', 'AX');
    EmitI1('CALL', '_BRT_WRITES');
  End

  Else If fname = 'STOP' Then
  Begin
    { STOP(n) : terminer le programme avec code n }
    ti1 := ParseExpr;                  { code -> AX }
    EmitI1('CALL', '_BRT_STOP');
  End

  Else If fname = 'HALT' Then
  Begin
    { HALT() ou HALT(n) : terminer }
    If cur_tok.val = ')' Then
      EmitI2('MOV', 'AX', '4C00h')
    Else
    Begin
      ti1 := ParseExpr;
      EmitI2('MOV', 'AH', '4Ch');
    End;
    EmitI0('INT  21h');
  End

  Else If fname = 'ASSERT' Then
  Begin
    { ASSERT(b [, n]) : si b = FALSE alors exit avec code n }
    lbl_skip  := NewLabel;
    exit_code := 1;
    ti1 := ParseExpr;
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
        ti2 := ParseExpr;
        exit_code := 1;
      End;
    End;
    EmitI2('MOV', 'AX', IntToStr($4C00 + exit_code));
    EmitI0('INT  21h');
    EmitLabel(lbl_skip);
  End

  Else
    ErrorMsg('Procedure integree BCPL inconnue : ' + fname);

  LexExpect(')');
End;

{ --------------------------------------------------------------------------
  ParseBuiltinFunc BCPL : ABS READCH READN READS GETBYTE PUTBYTE.
  Le nom de la fonction a deja ete consomme par l'appelant.
  Resultat dans AX.
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
  ti_res := TYP_WORD;
  LexExpect('(');

  If fname = 'ABS' Then
  Begin
    lbl_skip := NewLabel;
    ti1      := ParseExpr;
    EmitI2('OR',  'AX', 'AX');
    EmitI1('JNS', lbl_skip);
    EmitI1('NEG', 'AX');
    EmitLabel(lbl_skip);
  End

  Else If fname = 'READCH' Then
  Begin
    { READCH() : lire un caractere -> AX }
    LexExpect(')');
    EmitI1('CALL', '_BRT_READCH');
    ParseBuiltinFunc := TYP_WORD;
    Exit;
  End

  Else If fname = 'READN' Then
  Begin
    { READN() : lire un entier -> AX }
    LexExpect(')');
    EmitI1('CALL', '_BRT_READN');
    ParseBuiltinFunc := TYP_WORD;
    Exit;
  End

  Else If fname = 'READS' Then
  Begin
    { READS(buf) : lire une chaine BCPL dans buf, retourner longueur }
    ti1 := ParseExpr;
    EmitI2('MOV', 'BX', 'AX');
    EmitI1('CALL', '_BRT_READS');
  End

  Else If fname = 'GETBYTE' Then
  Begin
    { GETBYTE(s, i) : octet i de la chaine s }
    ti1 := ParseExpr;
    LexExpect(',');
    EmitI1('PUSH', 'AX');
    ParseExpr;
    EmitI0('POP  BX');
    EmitI2('ADD', 'BX', 'AX');
    EmitI2('XOR', 'AX', 'AX');
    EmitI2('MOV', 'AL', '[BX]');
  End

  Else If fname = 'PUTBYTE' Then
  Begin
    { PUTBYTE(s, i, c) : stocker l'octet c a la position i de s }
    ti1 := ParseExpr;
    LexExpect(',');
    EmitI1('PUSH', 'AX');
    ParseExpr;
    LexExpect(',');
    EmitI1('PUSH', 'AX');
    ParseExpr;
    EmitI2('MOV', 'CL', 'AL');   { c -> CL }
    EmitI0('POP  AX');            { i }
    EmitI0('POP  BX');            { base }
    EmitI2('ADD', 'BX', 'AX');
    EmitI2('MOV', '[BX]', 'CL');
    EmitI2('XOR', 'AX', 'AX');
  End

  Else
  Begin
    ErrorMsg('Fonction BCPL integree inconnue : ' + fname);
    EmitI2('XOR', 'AX', 'AX');
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
  GenBcplRuntime : emettre le runtime BCPL (_BRT_xxx) dans tmp_file (TODO 20).
  _BRT_WRITES : SI = chaine BCPL (octet 0 = longueur)
  _BRT_WRITEN : AX = entier signe -> decimal sur stdout
  _BRT_WRITEF : simple formateur %S %N %C
  _BRT_NEWLINE : CR LF
  _BRT_READCH : AL = caractere lu
  _BRT_READN  : AX = entier lu
  _BRT_READS  : BX = ptr tampon BCPL ; retourne longueur dans AX
  _BRT_STOP   : exit AX
  -------------------------------------------------------------------------- }
Procedure GenBcplRuntime;
Begin
  SwitchToTmp;
  EmitSep;
  EmitComment(' ====== RUNTIME BCPL (BRT) - BCPL86 TODO 20 ====== ');
  EmitBlank;

  { _BRT_WRITES : SI pointe vers chaine BCPL (octet 0 = longueur) }
  EmitLabel('_BRT_WRITES');
  EmitI1('PUSH', 'AX');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI2('XOR',  'AH', 'AH');
  EmitI2('MOV',  'AL', '[SI]');   { AL = longueur }
  EmitI2('MOV',  'CX', 'AX');    { CX = compteur }
  EmitI1('INC',  'SI');           { SI -> 1er caractere }
  EmitLabel('_BRT_WS_LOOP');
  EmitI2('OR',   'CX', 'CX');
  EmitI1('JZ',   '_BRT_WS_END');
  EmitI2('MOV',  'DL', '[SI]');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI1('INC',  'SI');
  EmitI1('DEC',  'CX');
  EmitI1('JMP',  '_BRT_WS_LOOP');
  EmitLabel('_BRT_WS_END');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'BX');
  EmitI1('POP',  'AX');
  EmitI0('RET');
  EmitBlank;

  { _BRT_NEWLINE : emettre CR LF }
  EmitLabel('_BRT_NEWLINE');
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

  { _BRT_WRITEN : AX = entier signe 16 bits -> affichage decimal }
  EmitLabel('_BRT_WRITEN');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI2('XOR',  'SI', 'SI');
  EmitI2('OR',   'AX', 'AX');
  EmitI1('JNS',  '_BRT_WN_POS');
  EmitI1('NEG',  'AX');
  EmitI1('PUSH', 'AX');
  EmitI2('MOV',  'DL', '2Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI0('POP  AX');
  EmitLabel('_BRT_WN_POS');
  EmitI2('MOV',  'BX', '10');
  EmitLabel('_BRT_WN_LOOP');
  EmitI2('XOR',  'DX', 'DX');
  EmitI1('DIV',  'BX');
  EmitI0('PUSH DX');
  EmitI1('INC',  'SI');
  EmitI2('OR',   'AX', 'AX');
  EmitI1('JNZ',  '_BRT_WN_LOOP');
  EmitLabel('_BRT_WN_PRINT');
  EmitI0('POP  DX');
  EmitI2('ADD',  'DL', '30h');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI1('DEC',  'SI');
  EmitI1('JNZ',  '_BRT_WN_PRINT');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _BRT_READCH : lire un caractere dans AL (avec echo) }
  EmitLabel('_BRT_READCH');
  EmitI2('MOV',  'AH', '1');
  EmitI0('INT  21h');
  EmitI2('XOR',  'AH', 'AH');
  EmitI0('RET');
  EmitBlank;

  { _BRT_READN : lire un entier signe depuis stdin -> AX }
  EmitLabel('_BRT_READN');
  EmitI1('PUSH', 'BX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI2('MOV',  'Byte Ptr [_BV_INBUF]', '126');
  EmitI2('LEA',  'DX', '[_BV_INBUF]');
  EmitI2('MOV',  'AH', '0Ah');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Ah');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('LEA',  'SI', '[_BV_INBUF+2]');
  EmitI2('XOR',  'BX', 'BX');
  EmitI2('XOR',  'DX', 'DX');
  EmitI2('CMP',  'Byte Ptr [SI]', '2Dh');
  EmitI1('JNE',  '_BRT_RN_LOOP');
  EmitI2('MOV',  'DX', '1');
  EmitI1('INC',  'SI');
  EmitLabel('_BRT_RN_LOOP');
  EmitI2('MOV',  'AL', '[SI]');
  EmitI2('CMP',  'AL', '30h');
  EmitI1('JB',   '_BRT_RN_DONE');
  EmitI2('CMP',  'AL', '39h');
  EmitI1('JA',   '_BRT_RN_DONE');
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
  EmitI1('JMP',  '_BRT_RN_LOOP');
  EmitLabel('_BRT_RN_DONE');
  EmitI2('MOV',  'AX', 'BX');
  EmitI2('OR',   'DX', 'DX');
  EmitI1('JZ',   '_BRT_RN_OK');
  EmitI1('NEG',  'AX');
  EmitLabel('_BRT_RN_OK');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _BRT_READS : lire une ligne dans tampon BCPL pointe par BX }
  { Format BCPL : octet 0 = longueur, octets 1..n = chars }
  EmitLabel('_BRT_READS');
  EmitI1('PUSH', 'AX');
  EmitI1('PUSH', 'CX');
  EmitI1('PUSH', 'DX');
  EmitI1('PUSH', 'SI');
  EmitI1('PUSH', 'DI');
  EmitI2('MOV',  'DI', 'BX');
  EmitI2('MOV',  'Byte Ptr [_BV_INBUF]', '126');
  EmitI2('LEA',  'DX', '[_BV_INBUF]');
  EmitI2('MOV',  'AH', '0Ah');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Dh');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('MOV',  'DL', '0Ah');
  EmitI2('MOV',  'AH', '2');
  EmitI0('INT  21h');
  EmitI2('LEA',  'SI', '[_BV_INBUF+2]');
  EmitI2('XOR',  'AH', 'AH');
  EmitI2('MOV',  'AL', '[_BV_INBUF+1]');
  EmitI2('MOV',  'CX', 'AX');
  { Stocker longueur a l'octet 0 du tampon BCPL }
  EmitI2('MOV',  '[DI]', 'AL');
  EmitI1('INC',  'DI');
  EmitLabel('_BRT_RS_COPY');
  EmitI2('OR',   'CX', 'CX');
  EmitI1('JZ',   '_BRT_RS_DONE');
  EmitI2('MOV',  'AL', '[SI]');
  EmitI2('MOV',  '[DI]', 'AL');
  EmitI1('INC',  'SI');
  EmitI1('INC',  'DI');
  EmitI1('DEC',  'CX');
  EmitI1('JMP',  '_BRT_RS_COPY');
  EmitLabel('_BRT_RS_DONE');
  EmitI1('POP',  'DI');
  EmitI1('POP',  'SI');
  EmitI1('POP',  'DX');
  EmitI1('POP',  'CX');
  EmitI1('POP',  'AX');
  EmitI0('RET');
  EmitBlank;

  { _BRT_WRITEF : formateur simple BCPL  %S %N %C %I }
  { Convention : SI = format, CX = nb args, stack = args (deja empiles) }
  EmitLabel('_BRT_WRITEF');
  EmitComment(' _BRT_WRITEF : formateur stub - imprime le format brut en TODO 19');
  EmitI1('PUSH', 'BX');
  EmitI2('MOV',  'AX', 'SI');
  EmitI2('MOV',  'SI', 'AX');
  EmitI1('CALL', '_BRT_WRITES');
  EmitI1('POP',  'BX');
  EmitI0('RET');
  EmitBlank;

  { _BRT_STOP : exit avec code AX }
  EmitLabel('_BRT_STOP');
  EmitI2('MOV',  'AH', '4Ch');
  EmitI0('INT  21h');
  EmitBlank;

  { _ORT_WRITESTR : alias pour compatibilite }
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
    ParseStdModuleExpr := TYP_WORD;
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
    ParseStdModuleExpr := TYP_WORD;
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
      ParseStdModuleExpr := TYP_WORD;
    End
    Else If methname = 'VAL' Then
    Begin
      LexExpect('(');
      ParseTypeRef;
      LexExpect(',');
      ParseExpr;
      LexExpect(')');
      EmitComment(' SYSTEM.VAL : transtypage - valeur dans AX');
      ParseStdModuleExpr := TYP_WORD;
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
      ParseStdModuleExpr := TYP_WORD;
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
      ParseStdModuleExpr := TYP_WORD;
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
    dummy := SymEnter(modname, SK_PROC, SC_GLOBAL, 0);
    { Enregistrer chaque identificateur importe directement }
    Repeat
      ident := cur_tok.val;
      LexExpectKind(TK_IDENT);
      { L'ident est enregistre comme alias direct dans la portee courante }
      dummy := SymEnter(ident, SK_PROC, SC_GLOBAL, 0);
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
      dummy := SymEnter(alias, SK_PROC, SC_GLOBAL, 0);
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
  If cur_tok.val = 'CONST' Then ParseManifestSection;
  If cur_tok.val = 'TYPE'  Then ParseTypeSection;
  If cur_tok.val = 'VAR'   Then ParseVarSection(True, local_off);
  { Support des procedures imbriquees : boucle sur PROCEDURE }
  While cur_tok.val = 'PROCEDURE' Do
    ParseProcDecl;

  { Ici local_size est connu -> emettre le prologue dans tmp_file }
  save_pidx   := cur_proc_idx;
  cur_proc_idx := pi;
  save_ret    := cur_ret_lbl;
  cur_ret_lbl := BP_PFX + AsmIdent(module_name) + '_' + AsmIdent(pname) + '_RET';

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
  TODO 16 - DECLARATIONS LET BCPL  (ParseLetDecl)
  ============================================================ }

{ --------------------------------------------------------------------------
  ParseLetDecl : LET nom [(params)] BE cmd  ou  LET nom [(params)] = expr
  Et aussi : LET v = VEC n  (vecteur local)
  Formes multiples : LET f ... AND g ...
  -------------------------------------------------------------------------- }
Procedure ParseLetDecl;
Var pname     : TString;
    is_func   : Boolean;
    pi        : Integer;
    ret_ti    : Integer;
    local_off : Integer;
    save_ret  : TString;
    save_pidx : Integer;
    si_var    : Integer;
    is_vec    : Boolean;
    vec_size  : Integer;
    k         : Integer;
    n_par     : Integer;
    ofs_fix   : Integer;
    si_fix    : Integer;
Begin
  LexExpect('LET');
  pname := cur_tok.val;
  LexExpectKind(TK_IDENT);

  { Forme : LET v = expr  ou  LET v = VEC n  (variable locale) }
  If cur_tok.val = '=' Then
  Begin
    LexNext;
    If cur_tok.val = 'VEC' Then
    Begin
      { LET v = VEC n : allouer n+1 mots sur la pile, stocker adresse dans v }
      LexNext;
      vec_size := ParseConstExprInt;
      local_off := cur_local_off;
      Inc(cur_local_off, (vec_size + 1) * 2);
      si_var := SymEnter(pname, SK_VEC, SC_LOCAL, TYP_WORD);
      If si_var > 0 Then
      Begin
        sym_table^[si_var].bp_offset  := -(local_off + (vec_size + 1) * 2);
        sym_table^[si_var].const_ival := vec_size;
        sym_table^[si_var].asm_label  := '';
        EmitI2('SUB', 'SP', IntToStr((vec_size + 1) * 2));
        EmitI2('LEA', 'AX', '[BP-' + IntToStr(local_off + (vec_size + 1) * 2) + ']');
        GenStore(si_var);
      End;
    End
    Else
    Begin
      { LET v = expr : variable locale scalaire }
      Inc(cur_local_off, 2);
      si_var := SymEnter(pname, SK_LOCAL, SC_LOCAL, TYP_WORD);
      If si_var > 0 Then
        sym_table^[si_var].bp_offset := -cur_local_off;
      ParseExpr;
      If si_var > 0 Then GenStore(si_var);
    End;
    { AND : declarations multiples liees }
    While cur_tok.val = 'AND' Do
    Begin
      LexNext;
      ParseLetDecl;
    End;
    Exit;
  End;

  { Forme routine : LET nom [(params)] BE cmd  ou  = expr }
  is_func := False;
  pi := ProcEnter(pname, 0, True);
  If pi = 0 Then Exit;

  ScopeEnter;

  { Parametres formels BCPL }
  If cur_tok.val = '(' Then
  Begin
    LexNext;
    While cur_tok.val <> ')' Do
    Begin
      ProcAddParam(pi, cur_tok.val, TYP_WORD, False);
      LexExpectKind(TK_IDENT);
      If cur_tok.val = ',' Then LexNext
      Else If cur_tok.val <> ')' Then Break;
    End;
    LexExpect(')');
    { Ajuster offsets BP : les args sont en [BP+4], [BP+6], ... }
    n_par := proc_table^[pi].param_count;
    For k := 1 To n_par Do
    Begin
      ofs_fix := 4 + (k - 1) * 2;
      proc_table^[pi].params[k].bp_offset := ofs_fix;
      si_fix := SymFind(proc_table^[pi].params[k].name);
      If si_fix > 0 Then
        sym_table^[si_fix].bp_offset := ofs_fix;
    End;
  End;

  { Corps : BE commande  ou  = expression (fonction VALOF implicite) }
  save_pidx    := cur_proc_idx;
  cur_proc_idx := pi;
  save_ret     := cur_ret_lbl;
  cur_ret_lbl  := BP_PFX + AsmIdent(pname) + '_RET';

  SwitchToTmp;
  GenProcPrologue(pi);

  If cur_tok.val = 'BE' Then
  Begin
    LexNext;
    ParseStatement;
  End
  Else If cur_tok.val = '=' Then
  Begin
    LexNext;
    ParseExpr;
    { resultat dans AX : c'est le retour de valeur }
  End
  Else
    ErrorMsg('BE ou = attendu apres LET ' + pname);

  { Epilogue }
  EmitLabel(cur_ret_lbl);
  GenProcEpilogue(pi);
  SwitchToMain;

  cur_proc_idx := save_pidx;
  cur_ret_lbl  := save_ret;
  ScopeLeave;

  { AND : routines mutuellement recursives }
  While cur_tok.val = 'AND' Do
  Begin
    LexNext;
    ParseLetDecl;
  End;
End;

{ ============================================================
  TODO 25 - INTEGRATION FINALE : ParseProgram + ParseModule
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
  ParseProgram BCPL : parser le source BCPL complet (TODO 25).
  Structure BCPL (pas de MODULE) :
    [GET "fichier"] [SECTION "nom"]
    [MANIFEST $( ... $)] [GLOBAL $( ... $)] [STATIC $( ... $)]
    LET nom(params) BE commande [AND nom2 ...]
    ...
  Le point d'entree est G!1 (la routine affectee au slot 1 dans GLOBAL).
  -------------------------------------------------------------------------- }
Procedure ParseProgram;
Begin
  module_name := ChangeExtension(src_fname, '');
  If module_name = '' Then module_name := 'BCPROG';

  { --- Prologue ASM --- }
  GenFileHeader;
  GenModelDirectives;
  GenStackSegment;
  GenDataHeader;
  GenSystemVarsData;
  GenDataFooter;
  GenCodeHeader;
  GenStartEntry;

  { --- Runtime BCPL dans tmp_file --- }
  GenBcplRuntime;

  { --- Fichier de chaines litterales differees --- }
  str_fname := ChangeExtension(src_fname, '.str');
  Assign(str_file, str_fname);
  Rewrite(str_file);

  { --- Sections top-level BCPL repetes --- }
  While cur_tok.kind <> TK_EOF Do
  Begin
    If cur_tok.val = 'GET' Then
    Begin
      LexNext;
      { GET "fichier" : ignorer pour l'instant (TODO 21) }
      If cur_tok.kind = TK_STRING Then LexNext;
    End
    Else If cur_tok.val = 'SECTION' Then
    Begin
      LexNext;
      If cur_tok.kind = TK_STRING Then
      Begin
        EmitComment(' SECTION ' + cur_tok.val);
        LexNext;
      End;
    End
    Else If cur_tok.val = 'MANIFEST' Then
      ParseManifestSection
    Else If cur_tok.val = 'GLOBAL' Then
      ParseGlobalSection
    Else If cur_tok.val = 'STATIC' Then
      ParseStaticSection
    Else If cur_tok.val = 'LET' Then
      ParseLetDecl
    Else
    Begin
      { instruction corps de module (rare en BCPL) }
      ErrorMsg('Directive BCPL inattendue en niveau module : ' + cur_tok.val);
      LexNext;
    End;
  End;

  { --- Fin du corps du module (inline dans START) --- }
  GenStartExit;
  MergeTmpToMain;
  GenCodeFooter;
  FlushStringLiterals;
  GenEndDirective;
End;

{ --------------------------------------------------------------------------
  ParseModule : alias pour ParseProgram (compatibilite interne).
  -------------------------------------------------------------------------- }
Procedure ParseModule;
Begin
  ParseProgram;
End;

{ ============================================================
  Programme principal
  ============================================================ }

Begin
  { --- Arguments --- }
  ParseArgs;

  { --- Initialisation --- }
  InitTables;
  InitBcplSystem;

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
