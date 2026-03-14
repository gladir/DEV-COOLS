  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  RuntimeEmitted := False;
  IOEmitted := False;
  IfCount := 0;
  ForCount := 0;
  { Table des symboles (TODO 05) }
  SymInit;
  { Systeme de types (TODO 06) }
  TypeInit;
  { Segment de donnees (TODO 08) }
  DataInit;
End;
```
---
## SUMMARY FOR TODO 15 IMPLEMENTATION
### Key Components:
1. **Symbol Table Entry for Labels**:
   - Use `SK_LABEL` kind in `TSymKind`
   - Use `TY_IDX_LABEL` type index
   - Mangled name prefix: `_A60L_`
2. **Label Generation**:
   - User-defined labels: Add via `SymAdd(Name, SK_LABEL, TY_IDX_LABEL, 0)`
   - Compiler-generated labels: Use `LabelGen()` function
3. **GOTO Statement**:
   - Parse `GOTO identifier` → emit `JMP _A60L_identifier`
   - Parse `GO TO identifier` → synonymous handling
   - Parse `GOTO expression` for indirect jumps (switch array access)
4. **Lexical Scope**:
   - Labels are scoped to BEGIN/END blocks
   - Use existing `SymEnterScope`/`SymLeaveScope` mechanism
5. **Assembly Output**:
   - Use `EmitLabel(label)` to emit label in code
   - Use `EmitInstr('JMP', label)` for unconditional jumps
   - Use `EmitInstr('JMP', 'indirect')` for indirect jumps through registers
6. **Parsing Integration Points**:
   - Add GOTO/GO TO handling in `ParseStmt` (line 3250)
   - Add GOTO/GO TO handling in `Run` procedure (line 4356)
   - Handle label declarations before statements (format: `label:`)
EOF
cat /tmp/AL60C86_TODO15_REFERENCE.md
                EC=$?
                echo "___BEGIN___COMMAND_DONE_MARKER___$EC"
            }
___BEGIN___COMMAND_OUTPUT_MARKER___
# AL60C86.PAS - TODO 15 Implementation Reference (GOTO and LABELS)

## 1. TODO 15 SPECIFICATION (Lines 224-236)

```
TODO 15 - GOTO ET ETIQUETTES
            Declarations d etiquettes : nom: au debut d une instruction
            Table des etiquettes : LabelTab, LabelAdd, LabelFind
            GOTO label : JMP _A60L_label
            GO TO label : synonyme de GOTO (deux mots)
            GOTO expression designationnelle : GOTO switch[expr]
              Evaluer l expression, obtenir l adresse du label
              JMP indirect : JMP [BX] ou CALL/RET selon implementation
            Etiquettes locales a un bloc : portee du BEGIN/END englobant
            Restriction : GOTO ne peut pas sauter a l interieur d un bloc
              depuis l exterieur (seulement vers un bloc englobant)
            Etiquettes en tant que parametres : passage de label a une procedure
```

---

## 2. CONSTANTS DEFINITION

### Symbol Kind Constants (Line 539)
```pascal
{ ---- Categories de symboles (TODO 05) -------------------- }
TSymKind = (
  SK_VAR,      { variable scalaire (INTEGER, REAL, BOOLEAN)  }
  SK_PARAM,    { parametre formel de procedure               }
  SK_PROC,     { procedure / fonction                        }
  SK_LABEL,    { etiquette de saut (label)                   }
  SK_SWITCH,   { aiguillage (switch)                         }
  SK_ARRAY,    { tableau (ARRAY)                             }
  SK_OWN       { variable OWN (statique, persistante)        }
);
```

### Type Kind Constants (Lines 560-569)
```pascal
TTypeKind = (
  TYK_INTEGER,   { entier 16 bits signe (INTEGER)              }
  TYK_REAL,      { reel (stub: entier tronque 16 bits)         }
  TYK_BOOLEAN,   { booleen 0 ou 1 dans AX (BOOLEAN)            }
  TYK_STRING,    { pointeur vers chaine dans DATA (STRING)      }
  TYK_LABEL,     { adresse de code / etiquette (LABEL)          }
  TYK_SWITCH,    { tableau de labels / aiguillage (SWITCH)      }
  TYK_PROCEDURE, { pointeur de code / sous-programme (PROCEDURE)}
  TYK_ARRAY,     { tableau a bornes dynamiques (ARRAY)          }
  TYK_UNKNOWN    { type inconnu ou non determine                }
);
```

### Type Index Constants (Lines 458-467)
```pascal
TY_IDX_INTEGER   = 0;  { entier 16 bits signe                }
TY_IDX_REAL      = 1;  { reel (stub)                         }
TY_IDX_BOOLEAN   = 2;  { 0 ou 1 dans AX                      }
TY_IDX_STRING    = 3;  { pointeur chaine DATA                }
TY_IDX_LABEL     = 4;  { adresse de code (etiquette)         }
TY_IDX_SWITCH    = 5;  { tableau de labels (aiguillage)      }
TY_IDX_PROCEDURE = 6;  { pointeur de code (sous-programme)   }
TY_IDX_ARRAY     = 7;  { tableau a bornes dynamiques         }
TY_PRIM_COUNT    = 8;
TY_UNKNOWN       = -1;
```

### Maximum Limits (Line 432)
```pascal
MAX_LABEL = {$IFDEF FPC}2048{$ELSE}100{$ENDIF};
```

### ASM Naming Prefixes (Lines 442-450)
```pascal
A60_VAR_PFX  = '_A60V_';   { variable scalaire               }
A60_FN_PFX   = '_A60P_';   { procedure / fonction            }
A60_STR_PFX  = '_A60K_';   { constante chaine litterale      }
A60_RT_PFX   = '_A60RT_';  { routine runtime                 }
A60_LBL_PFX  = '_A60L_';   { label de saut interne           }
A60_SW_PFX   = '_A60S_';   { table switch (aiguillage)       }
A60_OWN_PFX  = '_A60O_';   { variable OWN (statique)         }
A60_THK_PFX  = '_A60T_';   { thunk (call by name)            }
```

---

## 3. GLOBAL VARIABLES

```pascal
{ Label sequentiel }
LabelSeq   : Integer;  (Line 616)
```

Initialized in GlobalInit (line 992):
```pascal
LabelSeq := 0;
```

---

## 4. FORWARD DECLARATIONS (Lines 700-750)

Symbol Table Functions (Lines 703-713):
```pascal
Function  SymNameClean(Const Name : TString) : TString; Forward;
Function  SymMangle(Const Name : TString; Kind : TSymKind) : TString; Forward;
Function  SymFind(Const Name : TString) : Integer; Forward;
Function  SymFindInScope(Const Name : TString;
                         Level : Integer) : Integer; Forward;
Function  SymAdd(Const Name : TString; Kind : TSymKind;
                 TypeIdx, Offset : Integer) : Integer; Forward;
Procedure SymEnterScope; Forward;
Procedure SymLeaveScope; Forward;
Function  SymNextOffset : Integer; Forward;
Procedure SymInit;       Forward;
```

Label/Emit Functions (Line 690, 732):
```pascal
Procedure EmitLabel(Const Lbl : TString); Forward;
Procedure EmitExprRuntime; Forward;
```

---

## 5. SYMBOL TABLE FUNCTIONS

### SymInit (Lines 2596-2603)
```pascal
Procedure SymInit;
Begin
  SymCount     := 0;
  ScopeTop     := 0;
  CurScope     := 0;
  CurFrameSize := 0;
  ScopeStack[0] := 0;
End;
```

### SymNameClean (Lines 2608-2621)
```pascal
Function SymNameClean(Const Name : TString) : TString;
Var
  S : TString;
  I : Integer;
Begin
  S := Name;
  For I := 1 To Length(S) Do
    If Not (((S[I] >= 'A') And (S[I] <= 'Z')) Or
            ((S[I] >= 'a') And (S[I] <= 'z')) Or
            ((S[I] >= '0') And (S[I] <= '9')) Or
            (S[I] = '_')) Then
      S[I] := '_';
  SymNameClean := S;
End;
```

### SymMangle (Lines 2631-2647)
```pascal
Function SymMangle(Const Name : TString; Kind : TSymKind) : TString;
Var
  Clean : TString;
Begin
  Clean := SymNameClean(Name);
  Case Kind Of
    SK_VAR    : SymMangle := A60_VAR_PFX + Clean;
    SK_PARAM  : SymMangle := '';
    SK_PROC   : SymMangle := A60_FN_PFX  + Clean;
    SK_LABEL  : SymMangle := A60_LBL_PFX + Clean;      { <-- LABELS }
    SK_SWITCH : SymMangle := A60_SW_PFX  + Clean;
    SK_ARRAY  : SymMangle := A60_VAR_PFX + Clean;
    SK_OWN    : SymMangle := A60_OWN_PFX + Clean;
  Else
    SymMangle := A60_VAR_PFX + Clean;
  End;
End;
```

### SymFind (Lines 2652-2665)
```pascal
Function SymFind(Const Name : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If StrUpperCase(SymTab[I].Name) = U Then
    Begin
      SymFind := I;
      Exit;
    End;
  SymFind := -1;
End;
```

### SymFindInScope (Lines 2669-2684)
```pascal
Function SymFindInScope(Const Name : TString;
                        Level : Integer) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := StrUpperCase(Name);
  For I := SymCount - 1 DownTo 0 Do
    If (StrUpperCase(SymTab[I].Name) = U) And
       (SymTab[I].ScopeLevel = Level) Then
    Begin
      SymFindInScope := I;
      Exit;
    End;
  SymFindInScope := -1;
End;
```

### SymAdd (Lines 2689-2715 - partial)
```pascal
Function SymAdd(Const Name : TString; Kind : TSymKind;
                TypeIdx, Offset : Integer) : Integer;
Var
  Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    CompileError('table des symboles pleine (max=' +
                 IntToStr_(MAX_SYM) + ')');
    SymAdd := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name        := Name;
  SymTab[Idx].MangledName := SymMangle(Name, Kind);
  SymTab[Idx].Kind        := Kind;
  SymTab[Idx].TypeIdx     := TypeIdx;
  SymTab[Idx].ScopeLevel  := CurScope;
  SymTab[Idx].Offset      := Offset;
  SymTab[Idx].IsOwn       := (Kind = SK_OWN);
  SymTab[Idx].IsValue     := False;
  SymTab[Idx].IsName      := False;
  { ... more initialization ... }
```

### SymEnterScope (Lines 2725-2736)
```pascal
Procedure SymEnterScope;
Begin
  If ScopeTop >= MAX_SCOPE - 1 Then
  Begin
    CompileError('profondeur de portee maximale atteinte (max=' +
                 IntToStr_(MAX_SCOPE) + ')');
    Exit;
  End;
  Inc(CurScope);
  Inc(ScopeTop);
  ScopeStack[ScopeTop] := SymCount;
End;
```

### SymLeaveScope (Lines 2741-2751)
```pascal
Procedure SymLeaveScope;
Begin
  If ScopeTop <= 0 Then
  Begin
    CompileError('desequilibre de portees : LeaveScope sans EnterScope');
    Exit;
  End;
  SymCount := ScopeStack[ScopeTop];
  Dec(ScopeTop);
  Dec(CurScope);
End;
```

---

## 6. LABEL GENERATION

### LabelGen Function (Lines 1612-1620)
```pascal
{ ---- LabelGen : generateur de labels uniques _A60L_N ------- }
Function LabelGen : TString;
Var
  S : TString;
Begin
  Inc(LabelSeq);
  Str(LabelSeq, S);
  LabelGen := A60_LBL_PFX + S;  { Returns: _A60L_1, _A60L_2, etc. }
End;
```

**Note**: This generates compiler-internal labels like `_A60L_1`, `_A60L_2`, etc.
For user-defined labels, use `SymAdd(Name, SK_LABEL, TY_IDX_LABEL, 0)` to create
an entry with SK_LABEL and then generate the mangled name.

---

## 7. EMIT LABEL PROCEDURE

### EmitLabel (Lines 1956-1959)
```pascal
Procedure EmitLabel(Const Lbl : TString);
Begin
  EmitRaw(Lbl + ':');
End;
```

**Output Example**: 
```asm
_A60L_1:
_A60L_myLabel:
```

---

## 8. KEYWORD RECOGNITION (Line 1062)

The GOTO keyword is recognized in IsKeyword function:
```pascal
(U = 'GOTO')      Or (U = 'SWITCH')    Or (U = 'VALUE')     Or
```

**Location**: Line 1062 in IsKeyword function (lines 1050-1069)

Full context:
```pascal
Function IsKeyword(Const S : TString) : Boolean;
Var
  U : TString;
Begin
  U := StrUpperCase(S);
  IsKeyword :=
    (U = 'BEGIN')     Or (U = 'END')       Or (U = 'IF')        Or
    (U = 'THEN')      Or (U = 'ELSE')      Or (U = 'FOR')       Or
    (U = 'DO')        Or (U = 'STEP')      Or (U = 'UNTIL')     Or
    (U = 'WHILE')     Or (U = 'GO')        Or (U = 'TO')        Or
    (U = 'GOTO')      Or (U = 'SWITCH')    Or (U = 'VALUE')     Or  { <-- LINE 1062 }
    (U = 'OWN')       Or (U = 'BOOLEAN')   Or (U = 'INTEGER')   Or
    (U = 'REAL')      Or (U = 'ARRAY')     Or (U = 'PROCEDURE') Or
    (U = 'STRING')    Or (U = 'LABEL')     Or (U = 'COMMENT')   Or
    (U = 'TRUE')      Or (U = 'FALSE')     Or (U = 'NOT')       Or
    (U = 'AND')       Or (U = 'OR')        Or (U = 'IMPL')      Or
    (U = 'EQUIV')     Or (U = 'DIV');
End;
```

**GO TO support**: Note that 'GO' and 'TO' are separate keywords (line 1061).
The compiler should handle "GO TO" (two words) as a synonym for "GOTO".

---

## 9. PARSING: ParseStmt (Lines 3222-3251)

```pascal
{ ---- ParseStmt : dispatcher d instructions ------------------- }
{ Dispatche vers ParseDeclStmt pour les mots-cles de type
  (INTEGER, REAL, BOOLEAN, STRING), vers ParseIfStmt pour IF,
  vers ParseForStmt pour FOR,
  et vers ParseExprStmt pour les identifiants et expressions.   }
Procedure ParseStmt;
Begin
  { Declaration : mot-cle de type }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'INTEGER') Or (CurToken.Val = 'REAL') Or
      (CurToken.Val = 'BOOLEAN') Or (CurToken.Val = 'STRING')) Then
  Begin
    ParseDeclStmt;
    Exit;
  End;

  { Instruction conditionnelle (TODO 13) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParserAdvance;  { consommer IF }
    ParseIfStmt;
    Exit;
  End;

  { Boucle FOR (TODO 14) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FOR') Then
  Begin
    ParserAdvance;  { consommer FOR }
    ParseForStmt;
    Exit;
  End;

  { Expression ou affectation }
  ParseExprStmt;
End;
```

**IMPLEMENTATION NOTE**: Add GOTO handling after ParseForStmt (before ParseExprStmt):
```pascal
{ GOTO et GO TO }
If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GOTO') Then
Begin
  ParserAdvance;  { consommer GOTO }
  ParseGotoStmt;  { NEW PROCEDURE TO IMPLEMENT }
  Exit;
End;
If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'GO') Then
Begin
  ParserAdvance;  { consommer GO }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'TO') Then
  Begin
    ParserAdvance;  { consommer TO }
    ParseGotoStmt;  { NEW PROCEDURE TO IMPLEMENT }
  End
  Else
    CompileError('TO attendu apres GO');
  Exit;
End;
```

---

## 10. PARSING: ParseExprStmt (Lines 3162-3215)

```pascal
Procedure ParseExprStmt;
Var
  SIdx : Integer;
  VarName : TString;
  E : TExprVal;
  Op : TString;
  Prec, NextPrec : Integer;
  Right : TExprVal;
Begin
  { Verifier si c est un identifiant suivi de := }
  If CurToken.Kind = TK_IDENT Then
  Begin
    VarName := CurToken.Val;
    SIdx := SymFind(VarName);
    If SIdx >= 0 Then
    Begin
      { Sauvegarder la position, avancer pour voir si := suit }
      ParserAdvance;  { consommer l identifiant }
      If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
      Begin
        ParserAdvance;  { consommer := }
        { Affectation possiblement multiple : a := b := expr }
        ParseExpr(E);
        ExprFlushToAX(E);
        ExprStore(SIdx);
        EmitComment(VarName + ' := ...');
        Exit;
      End
      Else
      Begin
        { Pas d affectation : c est une expression qui commence
          par cet identifiant. On charge la variable et on continue
          la boucle de precedence Pratt en mode infixe. }
        ExprLoad(SIdx, E);
        { Boucle infixe Pratt manuelle }
        While CurTokIsInfixOp Do
        Begin
          Op := CurToken.Val;
          Prec := BinOpPrec(Op);
          If Prec < 1 Then Break;
          ParserAdvance;  { consommer l operateur }
          If BinOpIsRight(Op) Then NextPrec := Prec
          Else NextPrec := Prec + 1;
          ParseExprPrec(NextPrec, Right);
          ExprEmitBinOp(Op, E, Right);
        End;
        Exit;
      End;
    End;
  End;

  { Pas un identifiant connu ou pas un identifiant : expression simple }
  ParseExpr(E);
End;
```

---

## 11. PARSING: ParsePrimary (Lines 2340-2420)

Key sections:
```pascal
{ Parentheses ( expr ) }
If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
Begin
  ParserAdvance;  { consommer ( }
  ParseExpr(Res);
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ')') Then
    ParserAdvance  { consommer ) }
  Else
    CompileError(') attendu');
  Exit;
End;

{ Expression conditionnelle IF expr THEN expr ELSE expr }
If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
Begin
  ParserAdvance;  { consommer IF }
  ParseExpr(Res);
  ExprFlushToAX(Res);
  LblElse := LabelGen;
  LblEnd  := LabelGen;
  EmitInstr('OR', 'AX, AX');
  EmitInstr('JZ', LblElse);  { si faux -> else }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'THEN') Then
    ParserAdvance  { consommer THEN }
  Else
    CompileError('THEN attendu');
  ParseExpr(Res);
  ExprFlushToAX(Res);
  EmitInstr('JMP', LblEnd);
  EmitLabel(LblElse);
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'ELSE') Then
    ParserAdvance  { consommer ELSE }
  Else
    CompileError('ELSE attendu dans expression conditionnelle');
  ParseExpr(Res);
  ExprFlushToAX(Res);
  EmitLabel(LblEnd);
  ExprMakeAX(Res.TypeIdx, Res);
  Exit;
End;

{ Identificateur : resolution via SymFind (TODO 09+10+12) }
If CurToken.Kind = TK_IDENT Then
Begin
  IdName := CurToken.Val;

  { Intrinsics I/O (TODO 12) : intercepter avant SymFind }
  If (IdName = 'OUTINTEGER') Or (IdName = 'OUTREAL') Or
     (IdName = 'OUTSTRING') Or (IdName = 'OUTBOOLEAN') Or
     (IdName = 'ININTEGER') Or (IdName = 'INREAL') Or
     (IdName = 'INCHAR') Or (IdName = 'PRINT') Or
     (IdName = 'NEWLINE') Or (IdName = 'SYSACT') Then
  Begin
    ParserAdvance;  { consommer l identifiant }
    ParseIOIntrinsic(IdName, Res);
    Exit;
  End;

  SIdx := SymFind(IdName);
  ParserAdvance;  { consommer l identifiant }

  If SIdx >= 0 Then
  Begin
    { Appel de fonction/procedure : ident( ... ) (TODO 10) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '(') Then
    Begin
      ParserAdvance;  { consommer ( }
      ParseProcCall(IdName, SIdx, Res);
      Exit;
    End;

    { Acces tableau : ident[ ... ] (TODO 10) }
    If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '[') Then
    Begin
      ParserAdvance;  { consommer [ }
      If SymTab[SIdx].Kind = SK_SWITCH Then
        ParseSwitchAccess(SIdx, Res)
      Else
        ParseArrayAccess(SIdx, Res);
      Exit;
    End;
    { ... }
```

**LABEL REFERENCE NOTE**: When a label identifier is found via SymFind,
check if `SymTab[SIdx].Kind = SK_LABEL`. If so, it should return the
label's address (the mangled name as a label reference).

---

## 12. PARSING: ParseForStmt - Body Handling (Lines 4187-4202)

```pascal
If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
Begin
  ParserAdvance;
  SymEnterScope;
  While Not ((CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END'))
        And (CurToken.Kind <> TK_EOF) Do
  Begin
    While (CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';') Do
      ParserAdvance;
    If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
      Break;
    ParseStmt;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
    ParserAdvance;
  SymLeaveScope;
End
Else
  ParseStmt;
```

This pattern is used for scoped blocks in FOR loops. **Labels declared within
a BEGIN/END block should be scoped to that block.**

---

## 13. RUN PROCEDURE (Lines 4270-4386)

Complete Run procedure with GOTO/GO TO handling:

```pascal
Procedure Run;
{ Premier token }
ParserAdvance;

{ Boucle principale : parser les instructions (TODO 09) }
While CurToken.Kind <> TK_EOF Do
Begin
  { Fin de programme }
  If (CurToken.Kind = TK_PUNCT) And (CurToken.Val = '.') Then
    Break;

  { Separateurs : ; , : [ ] ( ) }
  If (CurToken.Kind = TK_PUNCT) And
     ((CurToken.Val = ';') Or (CurToken.Val = ',') Or
      (CurToken.Val = ':') Or (CurToken.Val = '[') Or
      (CurToken.Val = ']') Or (CurToken.Val = '(') Or
      (CurToken.Val = ')')) Then
  Begin
    ParserAdvance;
    Continue;
  End;

  { BEGIN / END : gestion de portee }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'BEGIN') Then
  Begin
    SymEnterScope;
    EmitComment('BEGIN (scope ' + IntToStr_(CurScope) + ')');
    ParserAdvance;
    Continue;
  End;
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'END') Then
  Begin
    EmitComment('END (scope ' + IntToStr_(CurScope) + ')');
    SymLeaveScope;
    ParserAdvance;
    Continue;
  End;

  { Declarations de type : dispatcher vers ParseDeclStmt (TODO 09) }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'INTEGER') Or (CurToken.Val = 'REAL') Or
      (CurToken.Val = 'BOOLEAN') Or (CurToken.Val = 'STRING')) Then
  Begin
    ParseDeclStmt;
    Continue;
  End;

  { Instruction conditionnelle IF (TODO 13) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'IF') Then
  Begin
    ParserAdvance;  { consommer IF }
    ParseIfStmt;
    Continue;
  End;

  { Boucle FOR (TODO 14) }
  If (CurToken.Kind = TK_KEYWORD) And (CurToken.Val = 'FOR') Then
  Begin
    ParserAdvance;  { consommer FOR }
    ParseForStmt;
    Continue;
  End;

  { Affectation ident := expr (TODO 09) }
  If (CurToken.Kind = TK_IDENT) Then
  Begin
    ParseExprStmt;
    Continue;
  End;

  { Affectation orpheline := : parser l expression droite }
  If (CurToken.Kind = TK_OP) And (CurToken.Val = ':=') Then
  Begin
    ParserAdvance;  { consommer := }
    If (CurToken.Kind <> TK_EOF) And
       Not ((CurToken.Kind = TK_PUNCT) And (CurToken.Val = ';')) Then
      ParseExpr(GExprDummy);
    Continue;
  End;

  { Mots-cles non-geres : on les saute pour l instant }
  If (CurToken.Kind = TK_KEYWORD) And
     ((CurToken.Val = 'ARRAY') Or
      (CurToken.Val = 'LABEL') Or
      (CurToken.Val = 'PROCEDURE') Or (CurToken.Val = 'OWN') Or
      (CurToken.Val = 'VALUE') Or (CurToken.Val = 'SWITCH') Or
      (CurToken.Val = 'COMMENT') Or
      (CurToken.Val = 'GO') Or (CurToken.Val = 'GOTO') Or        { <-- SKIPPED }
      (CurToken.Val = 'THEN') Or
      (CurToken.Val = 'ELSE') Or (CurToken.Val = 'TO')) Then
  Begin
    ParserAdvance;
    Continue;
  End;

  { Autre token : parser une expression }
  ParseExpr(GExprDummy);
End;

LexClose;
EmitExprRuntime;                  { routines runtime (TODO 11) }
EmitIORuntime;                    { routines I/O (TODO 12) }
EmitRaw('_TEXT   ENDS');
EmitBlankLine;
EmitDataSeg;
EmitBlankLine;
EmitRaw('        END');
EmitClose;

If Opts.Verbose Then ShowStats;

Cleanup;

If ErrorCount > 0 Then
  Halt(EXIT_ERROR)
Else
  Halt(EXIT_OK);
End;
```

**TODO 15 INTEGRATION**: Replace the skipping of 'GO' and 'GOTO' with
proper parsing - add ParserAdvance before calling ParseGotoStmt or similar.

---

## 14. GLOBALINIT PROCEDURE (Lines 1000-1031)

```pascal
{ Fragment relevant a TODO 15 }
{ Table des symboles (TODO 05) }
SymInit;
{ Systeme de types (TODO 06) }
TypeInit;
{ Segment de donnees (TODO 08) }
DataInit;
```

Full context (lines 1000-1031):
```pascal
  CurToken.Val     := '';
  CurToken.IntVal  := 0;
  CurToken.FloatVal := 0.0;
  CurToken.Line    := 0;
  CurToken.Col     := 0;
  { Segment de donnees }
  DataCount := 0;
  For I := 0 To MAX_DATA - 1 Do
  Begin
    DataTab[I].LblName   := '';
    DataTab[I].Kind      := DK_WORD;
    DataTab[I].IntVal    := 0;
    DataTab[I].StrVal    := '';
    DataTab[I].ElemCount := 0;
  End;
  { Expression dummy }
  GExprDummy.Kind    := EK_NONE;
  GExprDummy.ImmVal  := 0;
  GExprDummy.TypeIdx := TY_UNKNOWN;
  GExprDummy.Offset  := 0;
  GExprDummy.SymIdx  := -1;
  RuntimeEmitted := False;
  IOEmitted := False;
  IfCount := 0;
  ForCount := 0;
  { Table des symboles (TODO 05) }
  SymInit;
  { Systeme de types (TODO 06) }
  TypeInit;
  { Segment de donnees (TODO 08) }
  DataInit;
End;
```

---

## SUMMARY FOR TODO 15 IMPLEMENTATION

### Key Components:

1. **Symbol Table Entry for Labels**:
   - Use `SK_LABEL` kind in `TSymKind`
   - Use `TY_IDX_LABEL` type index
   - Mangled name prefix: `_A60L_`

2. **Label Generation**:
   - User-defined labels: Add via `SymAdd(Name, SK_LABEL, TY_IDX_LABEL, 0)`
   - Compiler-generated labels: Use `LabelGen()` function

3. **GOTO Statement**:
   - Parse `GOTO identifier` → emit `JMP _A60L_identifier`
   - Parse `GO TO identifier` → synonymous handling
   - Parse `GOTO expression` for indirect jumps (switch array access)

4. **Lexical Scope**:
   - Labels are scoped to BEGIN/END blocks
   - Use existing `SymEnterScope`/`SymLeaveScope` mechanism

5. **Assembly Output**:
   - Use `EmitLabel(label)` to emit label in code
   - Use `EmitInstr('JMP', label)` for unconditional jumps
   - Use `EmitInstr('JMP', 'indirect')` for indirect jumps through registers

6. **Parsing Integration Points**:
   - Add GOTO/GO TO handling in `ParseStmt` (line 3250)
   - Add GOTO/GO TO handling in `Run` procedure (line 4356)
   - Handle label declarations before statements (format: `label:`)

___BEGIN___COMMAND_DONE_MARKER___0
