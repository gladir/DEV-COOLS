{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 1.0
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Turbo Pascal 7, Free Pascal 3.2)
  @description: Generateur de code C aleatoire pour tester les compilateurs.
                Clone de Csmith (https://github.com/csmith-project/csmith)
                en Turbo Pascal / Free Pascal.
}

(* Voir DOC/TODO/CSMITH.txt pour la feuille de route des 25 TODOs *)

(*
  ============================================================
  LISTE DES 25 TODOs A IMPLEMENTER
  ============================================================

  TODO 01 - [IMPLEMENTE] INFRASTRUCTURE DE BASE ET OPTIONS CLI
            Programme principal CSMITH en Turbo Pascal / Free Pascal.
            Options de ligne de commande : --seed <n> (graine aleatoire),
            --max-funcs <n> (nombre max de fonctions), --max-block-depth <n>
            (profondeur max des blocs), --max-expr-depth <n> (profondeur
            max des expressions), --no-pointers (desactiver les pointeurs),
            --no-structs (desactiver les structures), --no-unions (desactiver
            les unions), --no-bitfields (desactiver les champs de bits),
            --no-volatiles (desactiver volatile), --no-consts (desactiver
            const), -o <file> (fichier de sortie), -h/--help (aide).
            Constantes globales : MAX_FUNCS, MAX_VARS, MAX_PARAMS,
            MAX_STRUCT_FIELDS, MAX_ARRAY_DIM, MAX_BLOCK_DEPTH, MAX_EXPR_DEPTH.

  TODO 02 - [IMPLEMENTE] TYPES INTERNES ET STRUCTURES DE DONNEES
            Definir les types internes pour la representation du code C :
            TTypeKind (TK_VOID, TK_CHAR, TK_SCHAR, TK_UCHAR, TK_SHORT,
            TK_USHORT, TK_INT, TK_UINT, TK_LONG, TK_ULONG, TK_LONGLONG,
            TK_ULONGLONG, TK_FLOAT, TK_DOUBLE, TK_STRUCT, TK_UNION,
            TK_ENUM, TK_POINTER, TK_ARRAY, TK_FUNC).
            TQualifier (Q_NONE, Q_CONST, Q_VOLATILE, Q_RESTRICT).
            TStorageClass (SC_AUTO, SC_STATIC, SC_EXTERN, SC_REGISTER).
            TCType : record avec Kind, Quals, Pointee, ArraySize, StructDef.
            TVariable : record avec Name, VType, Storage, Initialized, Scope.
            TFunction : record avec Name, RetType, Params, Body, NumParams.
            Fonctions : InitCType, InitVariable, InitField, InitStructDef,
            InitUnionDef, InitEnumDef, InitFunction, InitParam.
            Predicats : IsVoidType, IsIntegerType, IsSignedType, IsUnsignedType,
            IsFloatType, IsScalarType, IsPointerType, IsArrayType, IsStructType,
            IsUnionType, IsEnumType, IsFuncType, IsCompositeType, IsArithType,
            GetTypeSize, GetTypeSizeBits, AreTypesCompatible.

  TODO 03 - [IMPLEMENTE] GENERATEUR ALEATOIRE ET SEED
            Implanter un generateur de nombres pseudo-aleatoires reproductible
            (LCG - Linear Congruential Generator ou Xorshift).
            Fonctions : InitRandom(seed), RandomInt(max), RandomBool,
            RandomChoice(probability), RandomRange(min, max), RandomNext.
            Variables globales : RandomSeed, RandomState.
            La graine peut etre specifiee par --seed pour reproduire les
            tests. Si non specifiee, utiliser l'heure systeme.
            Afficher la graine utilisee en commentaire du fichier genere.

  TODO 04 - [IMPLEMENTE] EMISSION DE CODE : UTILITAIRES DE BASE
            Fonctions d'emission de code C : EmitOpen (ouvrir fichier),
            EmitClose (fermer fichier), EmitRaw (ecrire texte brut),
            EmitLine (ecrire ligne avec indentation), EmitIndent (augmenter
            indentation), EmitUnindent (diminuer indentation), EmitComment
            (ecrire commentaire), EmitBlankLine, EmitChar, EmitStr.
            Variables globales : OutFile (Text), OutFileOpen (Boolean),
            IndentLevel (Integer), IndentStr (String de 4 espaces),
            LineCount (compteur).
            Gerer les niveaux d'imbrication pour une indentation propre.

  TODO 05 - [IMPLEMENTE] EMISSION DES TYPES DE BASE C
            Fonctions pour emettre les types C de base :
            TypeToStr(T: TCType): String - convertir type en chaine C.
            EmitTypeDecl - emettre une declaration de type.
            EmitVarDecl - emettre une declaration de variable.
            EmitArrayDecl - emettre une declaration de tableau.
            EmitPointerDecl - emettre une declaration de pointeur.
            Gerer les qualificateurs (const, volatile, restrict) et
            les classes de stockage (static, extern, register).
            Supporter les types signes/non-signes, short/long/long long.

  TODO 06 - [IMPLEMENTE] GENERATION DE STRUCTURES (STRUCT)
            Generateur de definitions de structures C :
            GenStructDef - generer une definition de structure aleatoire.
            GenStructField - generer un champ de structure.
            GenStructName - generer un nom de structure unique.
            Supporter les champs : scalaires, tableaux, pointeurs,
            structures imbriquees (avec limite de profondeur).
            Eviter les cycles de structures (struct A contient struct A).
            Table des structures : StructDefs[], NumStructs.
            Emettre les declarations typedef struct { ... } NomStruct;

  TODO 07 - [IMPLEMENTE] GENERATION DE UNIONS
            Generateur de definitions d'unions C :
            GenUnionDef - generer une definition d'union aleatoire.
            GenUnionField - generer un champ d'union.
            Memes regles que les structures mais avec semantique union.
            Table des unions : UnionDefs[], NumUnions.
            Emettre les declarations typedef union { ... } NomUnion;
            Gerer l'alignement des champs pour eviter les comportements
            indefinis lors de l'acces au mauvais champ.

  TODO 08 - [A FAIRE] GENERATION DE CHAMPS DE BITS (BITFIELDS)
            Generateur de champs de bits dans les structures :
            GenBitfieldDecl - generer un champ de bits (type : width).
            Regles C : seuls int, unsigned int, signed int autorises.
            Largeur entre 1 et sizeof(int)*8 bits.
            Champ anonyme (: width) pour padding.
            Champ de largeur 0 (: 0) pour forcer l'alignement.
            Option --no-bitfields pour desactiver.
            Eviter les comportements indefinis (debordement de champ).

  TODO 09 - [A FAIRE] GENERATION D'ENUMERATIONS (ENUM)
            Generateur de definitions d'enumerations C :
            GenEnumDef - generer une definition d'enum aleatoire.
            GenEnumConstant - generer une constante d'enum.
            Supporter les valeurs implicites (auto-incrementees) et
            explicites (= valeur). Generer des noms uniques.
            Table des enums : EnumDefs[], NumEnums.
            Emettre typedef enum { A, B=5, C } NomEnum;

  TODO 10 - [A FAIRE] GENERATION DE TABLEAUX
            Generateur de declarations de tableaux C :
            GenArrayType - generer un type tableau aleatoire.
            GenArrayDimension - generer une dimension (1D, 2D, 3D...).
            GenArrayInit - generer un initialiseur de tableau.
            Supporter les tableaux de scalaires, structures, pointeurs.
            Limiter les dimensions (MAX_ARRAY_DIM) et la taille totale.
            Emettre int arr[10][20]; ou int arr[] = {1, 2, 3};

  TODO 11 - [A FAIRE] GENERATION DE POINTEURS
            Generateur de declarations et usages de pointeurs C :
            GenPointerType - generer un type pointeur aleatoire.
            GenPointerOp - generer une operation sur pointeur.
            Supporter les pointeurs vers : scalaires, tableaux, structs,
            fonctions, autres pointeurs (avec limite de niveaux).
            Operations : dereferencement (*p), adresse (&x), arithmetique
            (p++, p--, p+n, p-n, p1-p2). Option --no-pointers.
            Eviter les pointeurs invalides (UB) : NULL deref, out of bounds.

  TODO 12 - [A FAIRE] GENERATION DE CONSTANTES LITTERALES
            Generateur de constantes litterales C :
            GenIntLiteral - entier (decimal, octal 0n, hex 0xn).
            GenFloatLiteral - flottant (1.5, 1.5f, 1.5e10, .5, 5.).
            GenCharLiteral - caractere ('a', '\n', '\x41', '\0').
            GenStringLiteral - chaine ("hello", "line\n", escapes).
            Suffixes entiers : U, L, UL, LL, ULL.
            Suffixes flottants : F, L.
            Eviter les debordements (valeurs dans les limites du type).

  TODO 13 - [A FAIRE] GENERATION D'OPERATEURS ARITHMETIQUES
            Generateur d'expressions arithmetiques C :
            GenArithExpr - generer une expression arithmetique.
            Operateurs : + - * / % (modulo entier seulement).
            Gerer la precedence et l'associativite via parentheses.
            Eviter les comportements indefinis : division par zero,
            debordement signe (INT_MIN / -1, INT_MIN % -1).
            GenSafeDiv - generer une division securisee avec garde.
            Limiter la profondeur des expressions (MAX_EXPR_DEPTH).

  TODO 14 - [A FAIRE] GENERATION D'OPERATEURS RELATIONNELS ET LOGIQUES
            Generateur d'expressions relationnelles et logiques C :
            GenRelExpr - generer expression relationnelle (< > <= >= == !=).
            GenLogExpr - generer expression logique (&& || !).
            Gerer l'evaluation court-circuit (short-circuit).
            GenCompareExpr - comparaison de pointeurs (meme objet/tableau).
            Eviter les comparaisons de pointeurs non lies (UB).
            Produire des expressions booleennes pour les conditions.

  TODO 15 - [A FAIRE] GENERATION D'OPERATEURS BIT-A-BIT
            Generateur d'expressions bit-a-bit C :
            GenBitExpr - generer expression bit-a-bit.
            Operateurs : & | ^ ~ (complement) << >> (decalages).
            Regles : operandes entiers seulement.
            Eviter les UB : decalage negatif, decalage >= largeur du type,
            decalage gauche d'une valeur negative.
            GenSafeShift - generer un decalage securise.
            Appliquer les promotions entieres implicites.

  TODO 16 - [A FAIRE] GENERATION D'OPERATEURS D'AFFECTATION
            Generateur d'expressions d'affectation C :
            GenAssignExpr - generer une affectation (=).
            GenCompoundAssign - operateurs composes (+=, -=, *=, /=, %=,
            &=, |=, ^=, <<=, >>=). Operateur virgule (e1, e2).
            Operateurs d'increment/decrement (++x, x++, --x, x--).
            Respecter les regles de lvalue (cible modifiable).
            Eviter les effets de bord multiples sur meme variable.

  TODO 17 - [A FAIRE] GENERATION D'EXPRESSIONS CONDITIONNELLES
            Generateur d'expressions conditionnelles C :
            GenCondExpr - generer expression ternaire (cond ? e1 : e2).
            GenCastExpr - generer un cast explicite ((type)expr).
            GenSizeofExpr - generer sizeof(type) ou sizeof(expr).
            GenCommaExpr - generer expression virgule (e1, e2).
            Regles : types compatibles pour e1 et e2 dans ternaire.
            Gerer les conversions implicites et explicites.

  TODO 18 - [A FAIRE] GENERATION DE STATEMENTS SIMPLES
            Generateur de statements simples C :
            GenExprStmt - statement expression (expr;).
            GenDeclStmt - declaration de variable locale.
            GenReturnStmt - return avec/sans valeur.
            GenBreakStmt - break dans boucle/switch.
            GenContinueStmt - continue dans boucle.
            GenGotoStmt - goto label (optionnel, peut etre desactive).
            GenLabelStmt - etiquette pour goto.
            GenNullStmt - statement vide (;).

  TODO 19 - [A FAIRE] GENERATION DE BLOCS ET PORTEES
            Generateur de blocs et portees C :
            GenBlock - generer un bloc { statements }.
            GenScope - gerer la portee des variables locales.
            PushScope / PopScope - empiler/depiler les portees.
            Variables locales masquant les globales (shadowing).
            Limiter la profondeur des blocs (MAX_BLOCK_DEPTH).
            Table des symboles : ScopeStack[], CurrScope.

  TODO 20 - [A FAIRE] GENERATION DE CONDITIONNELLES (IF/ELSE)
            Generateur de statements conditionnels C :
            GenIfStmt - generer if (cond) stmt [else stmt].
            GenIfElseChain - generer if/else if/else enchaines.
            GenSwitchStmt - generer switch (expr) { case/default }.
            GenCaseLabel - generer case constante: ou default:.
            Regles switch : constantes entieres uniques, break optionnel,
            fall-through possible. Gerer la couverture des cas.

  TODO 21 - [A FAIRE] GENERATION DE BOUCLES
            Generateur de boucles C :
            GenWhileStmt - generer while (cond) stmt.
            GenDoWhileStmt - generer do stmt while (cond);
            GenForStmt - generer for (init; cond; update) stmt.
            Boucles bornees pour eviter les boucles infinies.
            Variable de boucle incrementee/decrementee vers une limite.
            Limiter les iterations max (guard counter).
            GenLoopGuard - compteur de garde pour terminer les boucles.

  TODO 22 - [A FAIRE] GENERATION DE FONCTIONS
            Generateur de fonctions C :
            GenFuncDecl - generer une declaration de fonction (prototype).
            GenFuncDef - generer une definition de fonction complete.
            GenFuncParams - generer la liste des parametres.
            GenFuncBody - generer le corps de la fonction.
            GenFuncCall - generer un appel de fonction.
            Fonctions : retour void ou type, 0 a MAX_PARAMS parametres.
            Gerer les appels recursifs (avec limite de profondeur).
            Fonctions statiques (static) ou externes.

  TODO 23 - [A FAIRE] GENERATION DU PROGRAMME COMPLET
            Generateur de programme C complet :
            GenProgram - generer un programme C complet.
            GenIncludes - generer #include <stdio.h> etc.
            GenGlobalVars - generer les variables globales.
            GenTypeDefs - generer les typedef struct/union/enum.
            GenFuncPrototypes - generer les prototypes de fonctions.
            GenMainFunc - generer la fonction main().
            GenChecksum - generer le calcul de checksum pour verification.
            Structure : includes, types, globales, prototypes, foncs, main.

  TODO 24 - [A FAIRE] VERIFICATION ET EVITEMENT DES COMPORTEMENTS INDEFINIS
            Systeme de verification pour eviter les undefined behaviors :
            CheckDivByZero - verifier division par zero.
            CheckOverflow - verifier debordement entier.
            CheckNullDeref - verifier dereferencement NULL.
            CheckArrayBounds - verifier acces tableau hors limites.
            CheckShiftAmount - verifier decalage valide.
            CheckUninitRead - verifier lecture de variable non initialisee.
            GenSafeExpr - generer expression avec gardes de securite.
            Utiliser les fonctions safe_* dans l'en-tete csmith.h.

  TODO 25 - [A FAIRE] OPTIONS AVANCEES ET STATISTIQUES
            Options avancees et statistiques de generation :
            ParseArgs - analyser les arguments de ligne de commande.
            ShowHelp - afficher l'aide (csmith --help).
            ShowStats - afficher les statistiques de generation.
            Statistiques : nombre de fonctions, variables, types, lignes,
            expressions, statements, profondeur max, complexite cyclomatique.
            Generer un en-tete de commentaire avec les parametres utilises.
            Mode verbeux (-v) pour afficher les etapes de generation.
            Mode quiet (-q) pour supprimer les messages.
            Verification de coherence du programme genere.

  ============================================================
*)

Program CSMITH;

{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}
{$I-}

Uses DOS;

{ ============================================================
  CONSTANTES GLOBALES
  ============================================================ }
Const
  CSMITH_VERSION = '1.0';
  CSMITH_DATE    = '2026-03-30';

  { Limites des tableaux internes }
  MAX_FUNCS          = {$IFDEF FPC}256{$ELSE}64{$ENDIF};
  MAX_VARS           = {$IFDEF FPC}1024{$ELSE}256{$ENDIF};
  MAX_PARAMS         = 8;
  MAX_STRUCT_FIELDS  = 16;
  MAX_UNION_FIELDS   = 8;
  MAX_ENUM_CONSTS    = 32;
  MAX_ARRAY_DIM      = 4;
  MAX_ARRAY_SIZE     = 100;
  MAX_BLOCK_DEPTH    = 8;
  MAX_EXPR_DEPTH     = 5;
  MAX_LOOP_ITER      = 1000;
  MAX_RECURSION      = 10;
  MAX_POINTER_DEPTH  = 3;
  MAX_STRUCTS        = {$IFDEF FPC}128{$ELSE}32{$ENDIF};
  MAX_UNIONS         = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_ENUMS          = {$IFDEF FPC}64{$ELSE}16{$ENDIF};
  MAX_SCOPES         = 32;
  MAX_LABELS         = 64;
  MAX_NAME_LEN       = 31;

  { Codes de retour }
  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Chaine max }
  MAX_STR = 255;

Type
  TString = String[MAX_STR];

{ ============================================================
  TODO 02 : TYPES INTERNES ET STRUCTURES DE DONNEES [IMPLEMENTE]
  ============================================================ }

Type
  { Types de base C }
  TTypeKind = (
    TK_VOID,
    TK_CHAR,
    TK_SCHAR,      { signed char }
    TK_UCHAR,      { unsigned char }
    TK_SHORT,
    TK_USHORT,
    TK_INT,
    TK_UINT,
    TK_LONG,
    TK_ULONG,
    TK_LONGLONG,
    TK_ULONGLONG,
    TK_FLOAT,
    TK_DOUBLE,
    TK_LONGDOUBLE,
    TK_STRUCT,
    TK_UNION,
    TK_ENUM,
    TK_POINTER,
    TK_ARRAY,
    TK_FUNC
  );

  { Qualificateurs }
  TQualifier = (
    Q_NONE,
    Q_CONST,
    Q_VOLATILE,
    Q_RESTRICT,
    Q_CONST_VOLATILE
  );

  { Classes de stockage }
  TStorageClass = (
    SC_AUTO,
    SC_STATIC,
    SC_EXTERN,
    SC_REGISTER
  );

  { Type C complet }
  TCType = Record
    Kind      : TTypeKind;
    Quals     : TQualifier;
    PointeeIdx: Integer;     { index vers le type pointe (pour TK_POINTER) }
    ArraySize : Integer;     { taille du tableau (pour TK_ARRAY) }
    ElemIdx   : Integer;     { index vers le type element (pour TK_ARRAY) }
    StructIdx : Integer;     { index vers la definition (pour TK_STRUCT/TK_UNION/TK_ENUM) }
  End;

  { Variable }
  TVariable = Record
    Name       : TString;
    VType      : TCType;
    Storage    : TStorageClass;
    Initialized: Boolean;
    ScopeLevel : Integer;
    IsParam    : Boolean;
    IsGlobal   : Boolean;
  End;

  { Champ de structure/union }
  TField = Record
    Name     : TString;
    FType    : TCType;
    BitWidth : Integer;    { 0 = pas un champ de bits, >0 = largeur en bits }
  End;

  { Definition de structure }
  TStructDef = Record
    Name      : TString;
    Fields    : Array[1..MAX_STRUCT_FIELDS] Of TField;
    NumFields : Integer;
    IsComplete: Boolean;
  End;

  { Definition d'union }
  TUnionDef = Record
    Name      : TString;
    Fields    : Array[1..MAX_UNION_FIELDS] Of TField;
    NumFields : Integer;
    IsComplete: Boolean;
  End;

  { Constante d'enumeration }
  TEnumConst = Record
    Name  : TString;
    Value : LongInt;
    HasVal: Boolean;   { True si valeur explicite }
  End;

  { Definition d'enum }
  TEnumDef = Record
    Name      : TString;
    Consts    : Array[1..MAX_ENUM_CONSTS] Of TEnumConst;
    NumConsts : Integer;
  End;

  { Parametre de fonction }
  TParam = Record
    Name  : TString;
    PType : TCType;
  End;

  { Fonction }
  TFunction = Record
    Name      : TString;
    RetType   : TCType;
    Params    : Array[1..MAX_PARAMS] Of TParam;
    NumParams : Integer;
    IsStatic  : Boolean;
    IsDefined : Boolean;
  End;

  { Portee (scope) }
  TScope = Record
    StartVarIdx: Integer;
    NumVars    : Integer;
    Level      : Integer;
  End;

  { Label pour goto }
  TLabel = Record
    Name    : TString;
    Defined : Boolean;
    Used    : Boolean;
  End;

  { Options du programme }
  TOptions = Record
    Seed           : LongInt;
    MaxFuncs       : Integer;
    MaxBlockDepth  : Integer;
    MaxExprDepth   : Integer;
    OutputFile     : TString;
    NoPointers     : Boolean;
    NoStructs      : Boolean;
    NoUnions       : Boolean;
    NoBitfields    : Boolean;
    NoVolatiles    : Boolean;
    NoConsts       : Boolean;
    NoFloats       : Boolean;
    NoGoto         : Boolean;
    Verbose        : Boolean;
    Quiet          : Boolean;
    ShowHelp       : Boolean;
  End;

{ ============================================================
  VARIABLES GLOBALES
  ============================================================ }
Var
  { Options }
  Opts: TOptions;

  { Tables des symboles }
  Vars       : Array[1..MAX_VARS] Of TVariable;
  NumVars    : Integer;
  Funcs      : Array[1..MAX_FUNCS] Of TFunction;
  NumFuncs   : Integer;
  Structs    : Array[1..MAX_STRUCTS] Of TStructDef;
  NumStructs : Integer;
  Unions     : Array[1..MAX_UNIONS] Of TUnionDef;
  NumUnions  : Integer;
  Enums      : Array[1..MAX_ENUMS] Of TEnumDef;
  NumEnums   : Integer;
  Labels     : Array[1..MAX_LABELS] Of TLabel;
  NumLabels  : Integer;

  { Portees }
  ScopeStack : Array[1..MAX_SCOPES] Of TScope;
  CurrScope  : Integer;

  { Emission }
  OutFile     : Text;
  OutFileName : TString;
  OutFileOpen : Boolean;
  IndentLevel : Integer;
  IndentStr   : TString;   { Chaine d'indentation (2 ou 4 espaces) }
  LineCount   : LongInt;

  { Generateur aleatoire }
  RandomSeed  : LongInt;
  RandomState : LongInt;

  { Statistiques }
  StatFuncs    : Integer;
  StatVars     : Integer;
  StatExprs    : Integer;
  StatStmts    : Integer;
  StatLines    : Integer;
  StatMaxDepth : Integer;

  { Compteurs pour noms uniques }
  VarCounter    : Integer;
  FuncCounter   : Integer;
  StructCounter : Integer;
  UnionCounter  : Integer;
  EnumCounter   : Integer;
  LabelCounter  : Integer;

{ ============================================================
  FONCTIONS UTILITAIRES
  ============================================================ }

Function IntToStr(N: LongInt): TString;
Var
  S: TString;
Begin
  Str(N, S);
  IntToStr := S;
End;

Function StrToInt(Const S: TString): LongInt;
Var
  N: LongInt;
  Code: Integer;
Begin
  Val(S, N, Code);
  If Code = 0 Then
    StrToInt := N
  Else
    StrToInt := 0;
End;

Function UpCaseStr(Const S: TString): TString;
Var
  I: Integer;
  R: TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['a'..'z'] Then
      R[I] := Chr(Ord(R[I]) - 32);
  UpCaseStr := R;
End;

Function LowerStr(Const S: TString): TString;
Var
  I: Integer;
  R: TString;
Begin
  R := S;
  For I := 1 To Length(R) Do
    If R[I] In ['A'..'Z'] Then
      R[I] := Chr(Ord(R[I]) + 32);
  LowerStr := R;
End;

Function FileExists(Const FileName: TString): Boolean;
Var
  F: File;
Begin
  {$I-}
  Assign(F, FileName);
  Reset(F);
  {$I+}
  If IOResult = 0 Then
  Begin
    Close(F);
    FileExists := True;
  End
  Else
    FileExists := False;
End;

Function ChangeFileExt(Const FileName, NewExt: TString): TString;
Var
  D: DirStr;
  N: NameStr;
  E: ExtStr;
Begin
  FSplit(FileName, D, N, E);
  ChangeFileExt := D + N + NewExt;
End;

{ ============================================================
  TODO 02 : FONCTIONS POUR TYPES INTERNES [IMPLEMENTE]
  ============================================================ }

{ --- Fonctions d'initialisation --- }

Procedure InitCType(Var T: TCType);
Begin
  T.Kind := TK_INT;
  T.Quals := Q_NONE;
  T.PointeeIdx := -1;
  T.ArraySize := 0;
  T.ElemIdx := -1;
  T.StructIdx := -1;
End;

Function MakeBasicType(Kind: TTypeKind): TCType;
Var
  T: TCType;
Begin
  InitCType(T);
  T.Kind := Kind;
  MakeBasicType := T;
End;

Function MakeQualifiedType(Kind: TTypeKind; Quals: TQualifier): TCType;
Var
  T: TCType;
Begin
  InitCType(T);
  T.Kind := Kind;
  T.Quals := Quals;
  MakeQualifiedType := T;
End;

Procedure InitVariable(Var V: TVariable);
Begin
  V.Name := '';
  InitCType(V.VType);
  V.Storage := SC_AUTO;
  V.Initialized := False;
  V.ScopeLevel := 0;
  V.IsParam := False;
  V.IsGlobal := False;
End;

Procedure InitField(Var F: TField);
Begin
  F.Name := '';
  InitCType(F.FType);
  F.BitWidth := 0;
End;

Procedure InitStructDef(Var S: TStructDef);
Var
  I: Integer;
Begin
  S.Name := '';
  For I := 1 To MAX_STRUCT_FIELDS Do
    InitField(S.Fields[I]);
  S.NumFields := 0;
  S.IsComplete := False;
End;

Procedure InitUnionDef(Var U: TUnionDef);
Var
  I: Integer;
Begin
  U.Name := '';
  For I := 1 To MAX_UNION_FIELDS Do
    InitField(U.Fields[I]);
  U.NumFields := 0;
  U.IsComplete := False;
End;

Procedure InitEnumConst(Var E: TEnumConst);
Begin
  E.Name := '';
  E.Value := 0;
  E.HasVal := False;
End;

Procedure InitEnumDef(Var E: TEnumDef);
Var
  I: Integer;
Begin
  E.Name := '';
  For I := 1 To MAX_ENUM_CONSTS Do
    InitEnumConst(E.Consts[I]);
  E.NumConsts := 0;
End;

Procedure InitParam(Var P: TParam);
Begin
  P.Name := '';
  InitCType(P.PType);
End;

Procedure InitFunction(Var F: TFunction);
Var
  I: Integer;
Begin
  F.Name := '';
  InitCType(F.RetType);
  F.RetType.Kind := TK_INT;
  For I := 1 To MAX_PARAMS Do
    InitParam(F.Params[I]);
  F.NumParams := 0;
  F.IsStatic := False;
  F.IsDefined := False;
End;

Procedure InitScope(Var S: TScope);
Begin
  S.StartVarIdx := 0;
  S.NumVars := 0;
  S.Level := 0;
End;

Procedure InitLabel(Var L: TLabel);
Begin
  L.Name := '';
  L.Defined := False;
  L.Used := False;
End;

{ --- Predicats de type --- }

Function IsVoidType(Const T: TCType): Boolean;
Begin
  IsVoidType := (T.Kind = TK_VOID);
End;

Function IsCharType(Const T: TCType): Boolean;
Begin
  IsCharType := (T.Kind = TK_CHAR) Or (T.Kind = TK_SCHAR) Or (T.Kind = TK_UCHAR);
End;

Function IsIntegerType(Const T: TCType): Boolean;
Begin
  IsIntegerType := T.Kind In [TK_CHAR, TK_SCHAR, TK_UCHAR, TK_SHORT, TK_USHORT,
                              TK_INT, TK_UINT, TK_LONG, TK_ULONG,
                              TK_LONGLONG, TK_ULONGLONG];
End;

Function IsSignedType(Const T: TCType): Boolean;
Begin
  { Note: TK_CHAR n'est pas inclus car son signe est implementation-defined en C }
  IsSignedType := T.Kind In [TK_SCHAR, TK_SHORT, TK_INT,
                             TK_LONG, TK_LONGLONG];
End;

Function IsUnsignedType(Const T: TCType): Boolean;
Begin
  IsUnsignedType := T.Kind In [TK_UCHAR, TK_USHORT, TK_UINT,
                               TK_ULONG, TK_ULONGLONG];
End;

Function IsFloatType(Const T: TCType): Boolean;
Begin
  IsFloatType := T.Kind In [TK_FLOAT, TK_DOUBLE, TK_LONGDOUBLE];
End;

Function IsArithType(Const T: TCType): Boolean;
Begin
  IsArithType := IsIntegerType(T) Or IsFloatType(T);
End;

Function IsScalarType(Const T: TCType): Boolean;
Begin
  IsScalarType := IsArithType(T) Or (T.Kind = TK_POINTER) Or (T.Kind = TK_ENUM);
End;

Function IsPointerType(Const T: TCType): Boolean;
Begin
  IsPointerType := (T.Kind = TK_POINTER);
End;

Function IsArrayType(Const T: TCType): Boolean;
Begin
  IsArrayType := (T.Kind = TK_ARRAY);
End;

Function IsStructType(Const T: TCType): Boolean;
Begin
  IsStructType := (T.Kind = TK_STRUCT);
End;

Function IsUnionType(Const T: TCType): Boolean;
Begin
  IsUnionType := (T.Kind = TK_UNION);
End;

Function IsEnumType(Const T: TCType): Boolean;
Begin
  IsEnumType := (T.Kind = TK_ENUM);
End;

Function IsFuncType(Const T: TCType): Boolean;
Begin
  IsFuncType := (T.Kind = TK_FUNC);
End;

Function IsCompositeType(Const T: TCType): Boolean;
Begin
  IsCompositeType := (T.Kind = TK_STRUCT) Or (T.Kind = TK_UNION) Or (T.Kind = TK_ARRAY);
End;

Function IsAggregateType(Const T: TCType): Boolean;
Begin
  IsAggregateType := (T.Kind = TK_STRUCT) Or (T.Kind = TK_UNION);
End;

Function IsConstQualified(Const T: TCType): Boolean;
Begin
  IsConstQualified := (T.Quals = Q_CONST) Or (T.Quals = Q_CONST_VOLATILE);
End;

Function IsVolatileQualified(Const T: TCType): Boolean;
Begin
  IsVolatileQualified := (T.Quals = Q_VOLATILE) Or (T.Quals = Q_CONST_VOLATILE);
End;

{ --- Taille des types --- }

Function GetTypeSize(Const T: TCType): Integer;
Begin
  Case T.Kind Of
    TK_VOID:       GetTypeSize := 0;
    TK_CHAR,
    TK_SCHAR,
    TK_UCHAR:      GetTypeSize := 1;
    TK_SHORT,
    TK_USHORT:     GetTypeSize := 2;
    TK_INT,
    TK_UINT,
    TK_FLOAT:      GetTypeSize := 4;
    TK_LONG,
    TK_ULONG:      GetTypeSize := 4;  { 32-bit platform }
    TK_LONGLONG,
    TK_ULONGLONG,
    TK_DOUBLE:     GetTypeSize := 8;
    TK_LONGDOUBLE: GetTypeSize := 10; { x86 extended }
    TK_POINTER:    GetTypeSize := 4;  { 32-bit platform }
    TK_ENUM:       GetTypeSize := 4;  { enum = int }
    TK_ARRAY:      GetTypeSize := 0;  { need element type }
    TK_STRUCT,
    TK_UNION:      GetTypeSize := 0;  { need struct definition }
    TK_FUNC:       GetTypeSize := 0;
  Else
    GetTypeSize := 0;
  End;
End;

Function GetTypeSizeBits(Const T: TCType): Integer;
Begin
  GetTypeSizeBits := GetTypeSize(T) * 8;
End;

{ --- Compatibilite des types --- }

Function AreTypesCompatible(Const T1, T2: TCType): Boolean;
Begin
  { Compatibilite de base: meme Kind }
  If T1.Kind <> T2.Kind Then
  Begin
    AreTypesCompatible := False;
    Exit;
  End;
  { Pour les types composes, verifier l'index }
  Case T1.Kind Of
    TK_STRUCT,
    TK_UNION,
    TK_ENUM:       AreTypesCompatible := (T1.StructIdx = T2.StructIdx);
    TK_POINTER:    AreTypesCompatible := (T1.PointeeIdx = T2.PointeeIdx);
    TK_ARRAY:      AreTypesCompatible := (T1.ElemIdx = T2.ElemIdx) And
                                         (T1.ArraySize = T2.ArraySize);
  Else
    AreTypesCompatible := True;
  End;
End;

Function CanConvertTo(Const FromType, ToType: TCType): Boolean;
Begin
  { Conversions implicites autorisees }
  If AreTypesCompatible(FromType, ToType) Then
  Begin
    CanConvertTo := True;
    Exit;
  End;
  { Conversions arithmetiques }
  If IsArithType(FromType) And IsArithType(ToType) Then
  Begin
    CanConvertTo := True;
    Exit;
  End;
  { Pointeur vers void* }
  If IsPointerType(FromType) And IsPointerType(ToType) Then
  Begin
    CanConvertTo := True;
    Exit;
  End;
  { Enum vers int }
  If IsEnumType(FromType) And IsIntegerType(ToType) Then
  Begin
    CanConvertTo := True;
    Exit;
  End;
  CanConvertTo := False;
End;

{ ============================================================
  TODO 03 : GENERATEUR ALEATOIRE [IMPLEMENTE]
  ============================================================ }

Procedure InitRandom(Seed: LongInt);
Var
  H, M, S, S100: Word;
Begin
  If Seed = 0 Then
  Begin
    { Utiliser l'heure systeme si pas de graine specifiee }
    GetTime(H, M, S, S100);
    Seed := LongInt(H) * 3600000 + LongInt(M) * 60000 + LongInt(S) * 1000 + S100;
    If Seed = 0 Then Seed := 1;
  End;
  RandomSeed := Seed;
  RandomState := Seed;
End;

Function RandomNext: LongInt;
Begin
  { Linear Congruential Generator (parametres de MINSTD) }
  RandomState := (RandomState * 48271) Mod 2147483647;
  RandomNext := RandomState;
End;

Function RandomInt(Max: Integer): Integer;
Begin
  If Max <= 0 Then
    RandomInt := 0
  Else
    RandomInt := Abs(RandomNext) Mod Max;
End;

Function RandomBool: Boolean;
Begin
  RandomBool := (RandomInt(2) = 1);
End;

Function RandomChoice(Probability: Integer): Boolean;
Begin
  { Probability est un pourcentage (0-100) }
  RandomChoice := (RandomInt(100) < Probability);
End;

Function RandomRange(MinVal, MaxVal: Integer): Integer;
Begin
  If MaxVal <= MinVal Then
    RandomRange := MinVal
  Else
    RandomRange := MinVal + RandomInt(MaxVal - MinVal + 1);
End;

{ ============================================================
  TODO 04 : EMISSION DE CODE [IMPLEMENTE]
  ============================================================ }

Procedure InitEmitter;
{ Initialise les variables d'emission. }
Begin
  OutFileName := '';
  OutFileOpen := False;
  IndentLevel := 0;
  IndentStr := '    ';  { 4 espaces par defaut }
  LineCount := 0;
End;

Procedure EmitOpen(Const FileName: TString);
{ Ouvre un fichier pour l'emission de code C. }
Begin
  OutFileName := FileName;
  Assign(OutFile, FileName);
  {$I-}
  Rewrite(OutFile);
  {$I+}
  If IOResult <> 0 Then
  Begin
    WriteLn('Erreur: Impossible de creer le fichier ', FileName);
    Halt(EXIT_ERROR);
  End;
  OutFileOpen := True;
  IndentLevel := 0;
  LineCount := 0;
End;

Procedure EmitClose;
{ Ferme le fichier de sortie. }
Begin
  If OutFileOpen Then
  Begin
    {$I-}
    Close(OutFile);
    {$I+}
    OutFileOpen := False;
  End;
  StatLines := LineCount;
End;

Procedure EmitChar(C: Char);
{ Ecrit un seul caractere dans le fichier de sortie. }
Begin
  Write(OutFile, C);
End;

Procedure EmitStr(Const S: TString);
{ Ecrit une chaine dans le fichier de sortie sans retour a la ligne. }
Begin
  Write(OutFile, S);
End;

Procedure EmitRaw(Const S: TString);
{ Ecrit du texte brut (alias de EmitStr pour compatibilite). }
Begin
  Write(OutFile, S);
End;

Procedure EmitLn;
{ Ecrit un retour a la ligne. }
Begin
  WriteLn(OutFile);
  Inc(LineCount);
End;

Procedure EmitIndentStr;
{ Ecrit l'indentation courante selon IndentLevel. }
Var
  I: Integer;
Begin
  For I := 1 To IndentLevel Do
    Write(OutFile, IndentStr);
End;

Procedure EmitLine(Const S: TString);
{ Ecrit une ligne avec indentation. }
Begin
  EmitIndentStr;
  WriteLn(OutFile, S);
  Inc(LineCount);
End;

Procedure EmitBlankLine;
{ Ecrit une ligne vide. }
Begin
  WriteLn(OutFile);
  Inc(LineCount);
End;

Procedure EmitComment(Const S: TString);
{ Ecrit un commentaire C de style /* ... */. }
Begin
  EmitIndentStr;
  WriteLn(OutFile, '/* ', S, ' */');
  Inc(LineCount);
End;

Procedure EmitLineComment(Const S: TString);
{ Ecrit un commentaire C de style // ... }
Begin
  EmitIndentStr;
  WriteLn(OutFile, '// ', S);
  Inc(LineCount);
End;

Procedure EmitMultiLineComment(Const Lines: Array Of TString);
{ Ecrit un commentaire multi-lignes. }
Var
  I: Integer;
Begin
  EmitIndentStr;
  WriteLn(OutFile, '/*');
  Inc(LineCount);
  For I := Low(Lines) To High(Lines) Do
  Begin
    EmitIndentStr;
    WriteLn(OutFile, ' * ', Lines[I]);
    Inc(LineCount);
  End;
  EmitIndentStr;
  WriteLn(OutFile, ' */');
  Inc(LineCount);
End;

Procedure EmitIndent;
{ Augmente le niveau d'indentation. }
Begin
  Inc(IndentLevel);
End;

Procedure EmitUnindent;
{ Diminue le niveau d'indentation. }
Begin
  If IndentLevel > 0 Then
    Dec(IndentLevel);
End;

Procedure SetIndentStr(NumSpaces: Integer);
{ Configure la chaine d'indentation (2 ou 4 espaces typiquement). }
Var
  I: Integer;
Begin
  IndentStr := '';
  For I := 1 To NumSpaces Do
    IndentStr := IndentStr + ' ';
End;

{ ============================================================
  TODO 05 : EMISSION DES TYPES [IMPLEMENTE]
  ============================================================ }

Function TypeKindToStr(Kind: TTypeKind): TString;
Begin
  Case Kind Of
    TK_VOID:       TypeKindToStr := 'void';
    TK_CHAR:       TypeKindToStr := 'char';
    TK_SCHAR:      TypeKindToStr := 'signed char';
    TK_UCHAR:      TypeKindToStr := 'unsigned char';
    TK_SHORT:      TypeKindToStr := 'short';
    TK_USHORT:     TypeKindToStr := 'unsigned short';
    TK_INT:        TypeKindToStr := 'int';
    TK_UINT:       TypeKindToStr := 'unsigned int';
    TK_LONG:       TypeKindToStr := 'long';
    TK_ULONG:      TypeKindToStr := 'unsigned long';
    TK_LONGLONG:   TypeKindToStr := 'long long';
    TK_ULONGLONG:  TypeKindToStr := 'unsigned long long';
    TK_FLOAT:      TypeKindToStr := 'float';
    TK_DOUBLE:     TypeKindToStr := 'double';
    TK_LONGDOUBLE: TypeKindToStr := 'long double';
    TK_STRUCT:     TypeKindToStr := 'struct';
    TK_UNION:      TypeKindToStr := 'union';
    TK_ENUM:       TypeKindToStr := 'enum';
    TK_POINTER:    TypeKindToStr := 'pointer';
    TK_ARRAY:      TypeKindToStr := 'array';
    TK_FUNC:       TypeKindToStr := 'function';
  Else
    TypeKindToStr := '?';
  End;
End;

Function QualifierToStr(Q: TQualifier): TString;
Begin
  Case Q Of
    Q_NONE:           QualifierToStr := '';
    Q_CONST:          QualifierToStr := 'const ';
    Q_VOLATILE:       QualifierToStr := 'volatile ';
    Q_RESTRICT:       QualifierToStr := 'restrict ';
    Q_CONST_VOLATILE: QualifierToStr := 'const volatile ';
  Else
    QualifierToStr := '';
  End;
End;

Function StorageClassToStr(SC: TStorageClass): TString;
Begin
  Case SC Of
    SC_AUTO:     StorageClassToStr := '';
    SC_STATIC:   StorageClassToStr := 'static ';
    SC_EXTERN:   StorageClassToStr := 'extern ';
    SC_REGISTER: StorageClassToStr := 'register ';
  Else
    StorageClassToStr := '';
  End;
End;

Function TypeToStr(Const T: TCType): TString;
{ Convertit un type C complet en chaine C.
  Pour les types simples : retourne le nom du type avec qualificateurs.
  Pour les pointeurs : retourne le type pointe avec *.
  Pour les tableaux : retourne le type element avec [].
  Pour les struct/union/enum : retourne struct/union/enum + nom. }
Var
  Result: TString;
  BaseStr: TString;
Begin
  Result := QualifierToStr(T.Quals);
  
  Case T.Kind Of
    TK_VOID..TK_LONGDOUBLE:
      Begin
        Result := Result + TypeKindToStr(T.Kind);
      End;
    TK_STRUCT:
      Begin
        If (T.StructIdx >= 1) And (T.StructIdx <= NumStructs) Then
          Result := Result + 'struct ' + Structs[T.StructIdx].Name
        Else
          Result := Result + 'struct';
      End;
    TK_UNION:
      Begin
        If (T.StructIdx >= 1) And (T.StructIdx <= NumUnions) Then
          Result := Result + 'union ' + Unions[T.StructIdx].Name
        Else
          Result := Result + 'union';
      End;
    TK_ENUM:
      Begin
        If (T.StructIdx >= 1) And (T.StructIdx <= NumEnums) Then
          Result := Result + 'enum ' + Enums[T.StructIdx].Name
        Else
          Result := Result + 'enum';
      End;
    TK_POINTER:
      Begin
        { Pour un pointeur, on a besoin du type pointe }
        If (T.PointeeIdx >= 1) And (T.PointeeIdx <= NumVars) Then
          Result := TypeToStr(Vars[T.PointeeIdx].VType) + ' *'
        Else
          Result := 'void *';
      End;
    TK_ARRAY:
      Begin
        { Pour un tableau, type element + [taille] }
        If (T.ElemIdx >= 1) And (T.ElemIdx <= NumVars) Then
          BaseStr := TypeToStr(Vars[T.ElemIdx].VType)
        Else
          BaseStr := 'int';
        Result := BaseStr;
        { La taille du tableau sera ajoutee par EmitArrayDecl }
      End;
    TK_FUNC:
      Begin
        { Type fonction - simplifie }
        Result := Result + 'function';
      End;
  Else
    Result := Result + '?';
  End;
  
  TypeToStr := Result;
End;

Function GetBaseTypeStr(Const T: TCType): TString;
{ Retourne seulement le type de base sans qualificateurs }
Begin
  Case T.Kind Of
    TK_VOID..TK_LONGDOUBLE:
      GetBaseTypeStr := TypeKindToStr(T.Kind);
    TK_STRUCT:
      If (T.StructIdx >= 1) And (T.StructIdx <= NumStructs) Then
        GetBaseTypeStr := 'struct ' + Structs[T.StructIdx].Name
      Else
        GetBaseTypeStr := 'struct';
    TK_UNION:
      If (T.StructIdx >= 1) And (T.StructIdx <= NumUnions) Then
        GetBaseTypeStr := 'union ' + Unions[T.StructIdx].Name
      Else
        GetBaseTypeStr := 'union';
    TK_ENUM:
      If (T.StructIdx >= 1) And (T.StructIdx <= NumEnums) Then
        GetBaseTypeStr := 'enum ' + Enums[T.StructIdx].Name
      Else
        GetBaseTypeStr := 'enum';
  Else
    GetBaseTypeStr := TypeKindToStr(T.Kind);
  End;
End;

Procedure EmitTypeDecl(Const TypeName: TString; Const T: TCType);
{ Emet une declaration de type (typedef).
  Exemple : typedef int MonType; }
Var
  S: TString;
Begin
  S := 'typedef ' + TypeToStr(T) + ' ' + TypeName + ';';
  EmitLine(S);
End;

Procedure EmitVarDecl(Const V: TVariable);
{ Emet une declaration de variable.
  Gere les classes de stockage et les qualificateurs.
  Exemple : static const int maVar; }
Var
  S: TString;
Begin
  S := StorageClassToStr(V.Storage) + TypeToStr(V.VType) + ' ' + V.Name + ';';
  EmitLine(S);
End;

Procedure EmitVarDeclInit(Const V: TVariable; Const InitVal: TString);
{ Emet une declaration de variable avec initialisation.
  Exemple : static int maVar = 42; }
Var
  S: TString;
Begin
  S := StorageClassToStr(V.Storage) + TypeToStr(V.VType) + ' ' + V.Name + ' = ' + InitVal + ';';
  EmitLine(S);
End;

Procedure EmitArrayDecl(Const Name: TString; Const ElemType: TCType;
                        Size: Integer; SC: TStorageClass);
{ Emet une declaration de tableau.
  Exemple : static int arr[10]; }
Var
  S: TString;
Begin
  S := StorageClassToStr(SC) + TypeToStr(ElemType) + ' ' + Name + '[' + IntToStr(Size) + '];';
  EmitLine(S);
End;

Procedure EmitArrayDeclMulti(Const Name: TString; Const ElemType: TCType;
                             Sizes: Array Of Integer; NumDims: Integer;
                             SC: TStorageClass);
{ Emet une declaration de tableau multidimensionnel.
  Exemple : int arr[10][20][5]; }
Var
  S: TString;
  I: Integer;
Begin
  S := StorageClassToStr(SC) + TypeToStr(ElemType) + ' ' + Name;
  For I := 0 To NumDims - 1 Do
    S := S + '[' + IntToStr(Sizes[I]) + ']';
  S := S + ';';
  EmitLine(S);
End;

Procedure EmitPointerDecl(Const Name: TString; Const PointeeType: TCType;
                          Levels: Integer; SC: TStorageClass; Q: TQualifier);
{ Emet une declaration de pointeur.
  Levels : nombre de niveaux d'indirection (1 = *, 2 = **, etc.)
  Exemple : static const int **ptrPtr; }
Var
  S: TString;
  I: Integer;
Begin
  S := StorageClassToStr(SC) + QualifierToStr(Q) + TypeToStr(PointeeType) + ' ';
  For I := 1 To Levels Do
    S := S + '*';
  S := S + Name + ';';
  EmitLine(S);
End;

Procedure EmitFuncPtrDecl(Const Name: TString; Const RetType: TCType;
                          Const ParamTypes: Array Of TString;
                          NumParams: Integer; SC: TStorageClass);
{ Emet une declaration de pointeur de fonction.
  Exemple : int (*funcPtr)(int, char); }
Var
  S: TString;
  I: Integer;
Begin
  S := StorageClassToStr(SC) + TypeToStr(RetType) + ' (*' + Name + ')(';
  If NumParams = 0 Then
    S := S + 'void'
  Else
  Begin
    For I := 0 To NumParams - 1 Do
    Begin
      If I > 0 Then S := S + ', ';
      S := S + ParamTypes[I];
    End;
  End;
  S := S + ');';
  EmitLine(S);
End;

Procedure EmitSimpleVarDecl(Const Name: TString; Kind: TTypeKind;
                            SC: TStorageClass; Q: TQualifier);
{ Raccourci pour emettre une declaration de variable simple.
  Exemple : static volatile int count; }
Var
  S: TString;
Begin
  S := StorageClassToStr(SC) + QualifierToStr(Q) + TypeKindToStr(Kind) + ' ' + Name + ';';
  EmitLine(S);
End;

Procedure EmitSimpleVarDeclInit(Const Name: TString; Kind: TTypeKind;
                                SC: TStorageClass; Q: TQualifier;
                                Const InitVal: TString);
{ Raccourci pour emettre une declaration de variable simple avec init.
  Exemple : const int MAX = 100; }
Var
  S: TString;
Begin
  S := StorageClassToStr(SC) + QualifierToStr(Q) + TypeKindToStr(Kind) + ' ' + Name + ' = ' + InitVal + ';';
  EmitLine(S);
End;

{ ============================================================
  TODO 06 : GENERATION DE STRUCTURES (STRUCT) [IMPLEMENTE]
  ============================================================ }

{ Constantes pour la generation de structures }
Const
  MIN_STRUCT_FIELDS = 1;
  MAX_STRUCT_DEPTH  = 3;  { Profondeur max pour les structures imbriquees }

{ --- Fonctions utilitaires pour les structures --- }

Function GenStructName: TString;
{ Genere un nom de structure unique de la forme 'struct_N'. }
Begin
  Inc(StructCounter);
  GenStructName := 's_' + IntToStr(StructCounter);
End;

Function GenFieldName(StructIdx, FieldNum: Integer): TString;
{ Genere un nom de champ unique de la forme 'f_N'. }
Begin
  GenFieldName := 'f' + IntToStr(FieldNum);
End;

Function IsValidFieldType(Kind: TTypeKind; CurrentDepth: Integer): Boolean;
{ Verifie si un type est valide pour un champ de structure.
  Evite les types void et limite la profondeur des structures imbriquees. }
Begin
  If Kind = TK_VOID Then
    IsValidFieldType := False
  Else If Kind = TK_FUNC Then
    IsValidFieldType := False  { Pas de fonctions dans les structs }
  Else If (Kind = TK_STRUCT) And (CurrentDepth >= MAX_STRUCT_DEPTH) Then
    IsValidFieldType := False  { Limite la profondeur }
  Else
    IsValidFieldType := True;
End;

Function GenRandomFieldType(CurrentDepth: Integer): TCType;
{ Genere un type aleatoire valide pour un champ de structure. }
Var
  T: TCType;
  R: Integer;
Begin
  InitCType(T);
  
  { Choix du type de base : privilegier les types simples }
  R := RandomInt(100);
  
  If R < 70 Then
  Begin
    { 70% : Type scalaire simple }
    Case RandomInt(8) Of
      0: T.Kind := TK_CHAR;
      1: T.Kind := TK_SCHAR;
      2: T.Kind := TK_UCHAR;
      3: T.Kind := TK_SHORT;
      4: T.Kind := TK_USHORT;
      5: T.Kind := TK_INT;
      6: T.Kind := TK_UINT;
      7: T.Kind := TK_LONG;
    End;
  End
  Else If (R < 85) And (Not Opts.NoFloats) Then
  Begin
    { 15% : Type flottant si autorise }
    If RandomBool Then
      T.Kind := TK_FLOAT
    Else
      T.Kind := TK_DOUBLE;
  End
  Else If (R < 95) And (CurrentDepth < MAX_STRUCT_DEPTH) And
          (Not Opts.NoStructs) And (NumStructs > 0) Then
  Begin
    { 10% : Structure imbriquee si possible }
    T.Kind := TK_STRUCT;
    T.StructIdx := RandomInt(NumStructs) + 1;
  End
  Else
  Begin
    { 5% : Retour au type int par defaut }
    T.Kind := TK_INT;
  End;
  
  { Ajouter des qualificateurs aleatoirement }
  If (Not Opts.NoConsts) And RandomChoice(10) Then
    T.Quals := Q_CONST
  Else If (Not Opts.NoVolatiles) And RandomChoice(5) Then
    T.Quals := Q_VOLATILE
  Else
    T.Quals := Q_NONE;
  
  GenRandomFieldType := T;
End;

Function GenStructField(StructIdx, FieldNum, CurrentDepth: Integer): TField;
{ Genere un champ de structure aleatoire. }
Var
  F: TField;
Begin
  InitField(F);
  F.Name := GenFieldName(StructIdx, FieldNum);
  F.FType := GenRandomFieldType(CurrentDepth);
  F.BitWidth := 0;  { Pas de champ de bits pour l'instant (TODO 08) }
  GenStructField := F;
End;

Function AddStructDef(Const S: TStructDef): Integer;
{ Ajoute une definition de structure a la table.
  Retourne l'index de la structure (1-based) ou 0 si erreur. }
Begin
  If NumStructs >= MAX_STRUCTS Then
  Begin
    AddStructDef := 0;
    Exit;
  End;
  Inc(NumStructs);
  Structs[NumStructs] := S;
  AddStructDef := NumStructs;
End;

Function GenStructDef(CurrentDepth: Integer): Integer;
{ Genere une definition de structure aleatoire.
  CurrentDepth permet de limiter l'imbrication des structures.
  Retourne l'index de la nouvelle structure (1-based) ou 0 si erreur. }
Var
  S: TStructDef;
  NumFields: Integer;
  I: Integer;
Begin
  InitStructDef(S);
  
  { Generer un nom unique }
  S.Name := GenStructName;
  
  { Determiner le nombre de champs }
  NumFields := RandomRange(MIN_STRUCT_FIELDS, MAX_STRUCT_FIELDS);
  S.NumFields := NumFields;
  
  { Generer les champs }
  For I := 1 To NumFields Do
    S.Fields[I] := GenStructField(NumStructs + 1, I, CurrentDepth);
  
  S.IsComplete := True;
  
  { Ajouter a la table }
  GenStructDef := AddStructDef(S);
End;

{ --- Fonctions d'emission pour les structures --- }

Procedure EmitFieldDecl(Const F: TField);
{ Emet la declaration d'un champ de structure. }
Var
  S: TString;
Begin
  S := '    ' + TypeToStr(F.FType) + ' ' + F.Name;
  If F.BitWidth > 0 Then
    S := S + ' : ' + IntToStr(F.BitWidth);
  S := S + ';';
  EmitLine(S);
End;

Procedure EmitStructDef(StructIdx: Integer);
{ Emet la definition complete d'une structure.
  Format : typedef struct ... Name; }
Var
  I: Integer;
Begin
  If (StructIdx < 1) Or (StructIdx > NumStructs) Then
    Exit;
  
  With Structs[StructIdx] Do
  Begin
    EmitLine('typedef struct {');
    
    { Emettre les champs }
    For I := 1 To NumFields Do
      EmitFieldDecl(Fields[I]);
    
    EmitLine('} ' + Name + ';');
  End;
End;

Procedure EmitAllStructDefs;
{ Emet toutes les definitions de structures. }
Var
  I: Integer;
Begin
  If NumStructs > 0 Then
  Begin
    EmitComment('Definitions de structures');
    For I := 1 To NumStructs Do
    Begin
      EmitStructDef(I);
      EmitBlankLine;
    End;
  End;
End;

Function GetStructByName(Const Name: TString): Integer;
{ Recherche une structure par son nom.
  Retourne l'index (1-based) ou 0 si non trouvee. }
Var
  I: Integer;
Begin
  GetStructByName := 0;
  For I := 1 To NumStructs Do
    If Structs[I].Name = Name Then
    Begin
      GetStructByName := I;
      Exit;
    End;
End;

Function GetStructField(StructIdx, FieldIdx: Integer): TField;
{ Retourne un champ d'une structure. }
Var
  F: TField;
Begin
  InitField(F);
  If (StructIdx >= 1) And (StructIdx <= NumStructs) And
     (FieldIdx >= 1) And (FieldIdx <= Structs[StructIdx].NumFields) Then
    F := Structs[StructIdx].Fields[FieldIdx];
  GetStructField := F;
End;

Function MakeStructType(StructIdx: Integer): TCType;
{ Cree un type structure a partir de l'index d'une definition. }
Var
  T: TCType;
Begin
  InitCType(T);
  T.Kind := TK_STRUCT;
  T.StructIdx := StructIdx;
  MakeStructType := T;
End;

{ ============================================================
  TODO 07 : GENERATION DE UNIONS [IMPLEMENTE]
  ============================================================ }

{ Constantes pour la generation d'unions }
Const
  MIN_UNION_FIELDS = 2;  { Une union a au moins 2 champs (sinon inutile) }
  MAX_UNION_DEPTH  = 2;  { Profondeur max pour les unions imbriquees }

{ --- Fonctions utilitaires pour les unions --- }

Function GenUnionName: TString;
{ Genere un nom d'union unique de la forme 'u_N'. }
Begin
  Inc(UnionCounter);
  GenUnionName := 'u_' + IntToStr(UnionCounter);
End;

Function GenUnionFieldName(UnionIdx, FieldNum: Integer): TString;
{ Genere un nom de champ d'union unique de la forme 'uf_N'. }
Begin
  GenUnionFieldName := 'uf' + IntToStr(FieldNum);
End;

Function IsValidUnionFieldType(Kind: TTypeKind; CurrentDepth: Integer): Boolean;
{ Verifie si un type est valide pour un champ d'union.
  Evite les types void et limite la profondeur des unions imbriquees. }
Begin
  If Kind = TK_VOID Then
    IsValidUnionFieldType := False
  Else If Kind = TK_FUNC Then
    IsValidUnionFieldType := False  { Pas de fonctions dans les unions }
  Else If (Kind = TK_UNION) And (CurrentDepth >= MAX_UNION_DEPTH) Then
    IsValidUnionFieldType := False  { Limite la profondeur }
  Else
    IsValidUnionFieldType := True;
End;

Function GenRandomUnionFieldType(CurrentDepth: Integer): TCType;
{ Genere un type aleatoire valide pour un champ d'union.
  Les unions peuvent contenir differentes representations d'une meme donnee. }
Var
  T: TCType;
  R: Integer;
Begin
  InitCType(T);
  
  { Choix du type de base : privilegier les types simples pour les unions }
  R := RandomInt(100);
  
  If R < 50 Then
  Begin
    { 50% : Type entier de differentes tailles (utile pour unions) }
    Case RandomInt(6) Of
      0: T.Kind := TK_CHAR;
      1: T.Kind := TK_SHORT;
      2: T.Kind := TK_INT;
      3: T.Kind := TK_LONG;
      4: T.Kind := TK_UINT;
      5: T.Kind := TK_ULONG;
    End;
  End
  Else If R < 70 Then
  Begin
    { 20% : Type unsigned pour reinterpretation de bits }
    Case RandomInt(4) Of
      0: T.Kind := TK_UCHAR;
      1: T.Kind := TK_USHORT;
      2: T.Kind := TK_UINT;
      3: T.Kind := TK_ULONG;
    End;
  End
  Else If (R < 85) And (Not Opts.NoFloats) Then
  Begin
    { 15% : Type flottant si autorise }
    If RandomBool Then
      T.Kind := TK_FLOAT
    Else
      T.Kind := TK_DOUBLE;
  End
  Else If (R < 92) And (CurrentDepth < MAX_UNION_DEPTH) And
          (Not Opts.NoUnions) And (NumUnions > 0) Then
  Begin
    { 7% : Union imbriquee si possible }
    T.Kind := TK_UNION;
    T.StructIdx := RandomInt(NumUnions) + 1;
  End
  Else If (R < 98) And (CurrentDepth < MAX_STRUCT_DEPTH) And
          (Not Opts.NoStructs) And (NumStructs > 0) Then
  Begin
    { 6% : Structure comme membre d'union }
    T.Kind := TK_STRUCT;
    T.StructIdx := RandomInt(NumStructs) + 1;
  End
  Else
  Begin
    { 2% : Retour au type int par defaut }
    T.Kind := TK_INT;
  End;
  
  { Les champs d'union sont rarement const/volatile }
  If (Not Opts.NoVolatiles) And RandomChoice(3) Then
    T.Quals := Q_VOLATILE
  Else
    T.Quals := Q_NONE;
  
  GenRandomUnionFieldType := T;
End;

Function GenUnionField(UnionIdx, FieldNum, CurrentDepth: Integer): TField;
{ Genere un champ d'union aleatoire. }
Var
  F: TField;
Begin
  InitField(F);
  F.Name := GenUnionFieldName(UnionIdx, FieldNum);
  F.FType := GenRandomUnionFieldType(CurrentDepth);
  F.BitWidth := 0;  { Pas de champ de bits dans les unions normalement }
  GenUnionField := F;
End;

Function AddUnionDef(Const U: TUnionDef): Integer;
{ Ajoute une definition d'union a la table.
  Retourne l'index de l'union (1-based) ou 0 si erreur. }
Begin
  If NumUnions >= MAX_UNIONS Then
  Begin
    AddUnionDef := 0;
    Exit;
  End;
  Inc(NumUnions);
  Unions[NumUnions] := U;
  AddUnionDef := NumUnions;
End;

Function GenUnionDef(CurrentDepth: Integer): Integer;
{ Genere une definition d'union aleatoire.
  CurrentDepth permet de limiter l'imbrication des unions.
  Retourne l'index de la nouvelle union (1-based) ou 0 si erreur. }
Var
  U: TUnionDef;
  NumFields: Integer;
  I: Integer;
Begin
  InitUnionDef(U);
  
  { Generer un nom unique }
  U.Name := GenUnionName;
  
  { Determiner le nombre de champs (minimum 2 pour une union utile) }
  NumFields := RandomRange(MIN_UNION_FIELDS, MAX_UNION_FIELDS);
  U.NumFields := NumFields;
  
  { Generer les champs }
  For I := 1 To NumFields Do
    U.Fields[I] := GenUnionField(NumUnions + 1, I, CurrentDepth);
  
  U.IsComplete := True;
  
  { Ajouter a la table }
  GenUnionDef := AddUnionDef(U);
End;

{ --- Fonctions d'emission pour les unions --- }

Procedure EmitUnionFieldDecl(Const F: TField);
{ Emet la declaration d'un champ d'union. }
Var
  S: TString;
Begin
  S := '    ' + TypeToStr(F.FType) + ' ' + F.Name + ';';
  EmitLine(S);
End;

Procedure EmitUnionDef(UnionIdx: Integer);
{ Emet la definition complete d'une union.
  Format : typedef union ... Name; }
Var
  I: Integer;
Begin
  If (UnionIdx < 1) Or (UnionIdx > NumUnions) Then
    Exit;
  
  With Unions[UnionIdx] Do
  Begin
    EmitLine('typedef union {');
    
    { Emettre les champs }
    For I := 1 To NumFields Do
      EmitUnionFieldDecl(Fields[I]);
    
    EmitLine('} ' + Name + ';');
  End;
End;

Procedure EmitAllUnionDefs;
{ Emet toutes les definitions d'unions. }
Var
  I: Integer;
Begin
  If NumUnions > 0 Then
  Begin
    EmitComment('Definitions d''unions');
    For I := 1 To NumUnions Do
    Begin
      EmitUnionDef(I);
      EmitBlankLine;
    End;
  End;
End;

Function GetUnionByName(Const Name: TString): Integer;
{ Recherche une union par son nom.
  Retourne l'index (1-based) ou 0 si non trouvee. }
Var
  I: Integer;
Begin
  GetUnionByName := 0;
  For I := 1 To NumUnions Do
    If Unions[I].Name = Name Then
    Begin
      GetUnionByName := I;
      Exit;
    End;
End;

Function GetUnionField(UnionIdx, FieldIdx: Integer): TField;
{ Retourne un champ d'une union. }
Var
  F: TField;
Begin
  InitField(F);
  If (UnionIdx >= 1) And (UnionIdx <= NumUnions) And
     (FieldIdx >= 1) And (FieldIdx <= Unions[UnionIdx].NumFields) Then
    F := Unions[UnionIdx].Fields[FieldIdx];
  GetUnionField := F;
End;

Function MakeUnionType(UnionIdx: Integer): TCType;
{ Cree un type union a partir de l'index d'une definition. }
Var
  T: TCType;
Begin
  InitCType(T);
  T.Kind := TK_UNION;
  T.StructIdx := UnionIdx;  { Reutilise StructIdx pour les unions aussi }
  MakeUnionType := T;
End;

{ ============================================================
  INITIALISATION
  ============================================================ }

Procedure InitTables;
Begin
  NumVars := 0;
  NumFuncs := 0;
  NumStructs := 0;
  NumUnions := 0;
  NumEnums := 0;
  NumLabels := 0;
  CurrScope := 0;
  VarCounter := 0;
  FuncCounter := 0;
  StructCounter := 0;
  UnionCounter := 0;
  EnumCounter := 0;
  LabelCounter := 0;
  StatFuncs := 0;
  StatVars := 0;
  StatExprs := 0;
  StatStmts := 0;
  StatLines := 0;
  StatMaxDepth := 0;
  { Initialiser l'emetteur }
  InitEmitter;
End;

Procedure InitOptions;
Begin
  Opts.Seed := 0;
  Opts.MaxFuncs := 10;
  Opts.MaxBlockDepth := MAX_BLOCK_DEPTH;
  Opts.MaxExprDepth := MAX_EXPR_DEPTH;
  Opts.OutputFile := '';
  Opts.NoPointers := False;
  Opts.NoStructs := False;
  Opts.NoUnions := False;
  Opts.NoBitfields := False;
  Opts.NoVolatiles := False;
  Opts.NoConsts := False;
  Opts.NoFloats := False;
  Opts.NoGoto := True;  { goto desactive par defaut }
  Opts.Verbose := False;
  Opts.Quiet := False;
  Opts.ShowHelp := False;
End;

{ ============================================================
  TODO 25 : OPTIONS CLI ET AIDE [A FAIRE]
  ============================================================ }

Procedure ShowHelp;
Begin
  WriteLn('CSMITH v', CSMITH_VERSION, ' - Generateur de code C aleatoire');
  WriteLn('Copyright (c) 2026 Gladir.com - Turbo Pascal / Free Pascal');
  WriteLn;
  WriteLn('Usage: CSMITH [options]');
  WriteLn;
  WriteLn('Options:');
  WriteLn('  --seed <n>           Graine pour le generateur aleatoire');
  WriteLn('  --max-funcs <n>      Nombre maximum de fonctions (defaut: 10)');
  WriteLn('  --max-block-depth <n>  Profondeur max des blocs (defaut: ', MAX_BLOCK_DEPTH, ')');
  WriteLn('  --max-expr-depth <n>   Complexite max des expressions (defaut: ', MAX_EXPR_DEPTH, ')');
  WriteLn('  -o <file>            Fichier de sortie (defaut: stdout)');
  WriteLn('  --no-pointers        Desactiver les pointeurs');
  WriteLn('  --no-structs         Desactiver les structures');
  WriteLn('  --no-unions          Desactiver les unions');
  WriteLn('  --no-bitfields       Desactiver les champs de bits');
  WriteLn('  --no-volatiles       Desactiver volatile');
  WriteLn('  --no-consts          Desactiver const');
  WriteLn('  --no-floats          Desactiver les types flottants');
  WriteLn('  --enable-goto        Activer les goto (desactive par defaut)');
  WriteLn('  -v, --verbose        Mode verbeux');
  WriteLn('  -q, --quiet          Mode silencieux');
  WriteLn('  -h, --help           Afficher cette aide');
  WriteLn;
  WriteLn('Exemple:');
  WriteLn('  CSMITH --seed 12345 -o test.c');
End;

Procedure ParseArgs;
Var
  I: Integer;
  Arg: TString;
Begin
  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);
    If (Arg = '-h') Or (Arg = '--help') Then
      Opts.ShowHelp := True
    Else If (Arg = '-v') Or (Arg = '--verbose') Then
      Opts.Verbose := True
    Else If (Arg = '-q') Or (Arg = '--quiet') Then
      Opts.Quiet := True
    Else If Arg = '--no-pointers' Then
      Opts.NoPointers := True
    Else If Arg = '--no-structs' Then
      Opts.NoStructs := True
    Else If Arg = '--no-unions' Then
      Opts.NoUnions := True
    Else If Arg = '--no-bitfields' Then
      Opts.NoBitfields := True
    Else If Arg = '--no-volatiles' Then
      Opts.NoVolatiles := True
    Else If Arg = '--no-consts' Then
      Opts.NoConsts := True
    Else If Arg = '--no-floats' Then
      Opts.NoFloats := True
    Else If Arg = '--enable-goto' Then
      Opts.NoGoto := False
    Else If Arg = '--seed' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.Seed := StrToInt(ParamStr(I));
    End
    Else If Arg = '--max-funcs' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.MaxFuncs := StrToInt(ParamStr(I));
    End
    Else If Arg = '--max-block-depth' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.MaxBlockDepth := StrToInt(ParamStr(I));
    End
    Else If Arg = '--max-expr-depth' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.MaxExprDepth := StrToInt(ParamStr(I));
    End
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I <= ParamCount Then
        Opts.OutputFile := ParamStr(I);
    End
    Else
    Begin
      { Argument non reconnu : considerer comme fichier de sortie }
      If Opts.OutputFile = '' Then
        Opts.OutputFile := Arg;
    End;
    Inc(I);
  End;
End;

{ ============================================================
  TODO 23 : GENERATION DU PROGRAMME COMPLET [A FAIRE]
  ============================================================ }

Procedure GenIncludes;
Begin
  EmitLine('#include <stdio.h>');
  EmitLine('#include <stdlib.h>');
  EmitLine('#include <stdint.h>');
  EmitLine('#include <string.h>');
  EmitBlankLine;
End;

Procedure GenChecksumVars;
Begin
  EmitComment('Variables globales pour le checksum');
  EmitLine('static unsigned long g_checksum = 0;');
  EmitBlankLine;
End;

Procedure GenChecksumFunc;
Begin
  EmitComment('Fonction de mise a jour du checksum');
  EmitLine('static void update_checksum(int val) {');
  EmitIndent;
  EmitLine('g_checksum = (g_checksum + val) * 31;');
  EmitUnindent;
  EmitLine('}');
  EmitBlankLine;
End;

Procedure GenMainFunc;
Begin
  EmitComment('Fonction principale');
  EmitLine('int main(void) {');
  EmitIndent;
  EmitLine('printf("checksum = %lu\\n", g_checksum);');
  EmitLine('return 0;');
  EmitUnindent;
  EmitLine('}');
End;

Procedure GenProgram;
Var
  I, NumGen: Integer;
Begin
  EmitComment('Programme C genere par CSMITH v' + CSMITH_VERSION);
  EmitComment('Graine: ' + IntToStr(RandomSeed));
  EmitComment('Date: ' + CSMITH_DATE);
  EmitBlankLine;
  GenIncludes;
  
  { Generer quelques structures si autorisees }
  If Not Opts.NoStructs Then
  Begin
    NumGen := RandomRange(1, 4);  { Generer 1 a 4 structures }
    For I := 1 To NumGen Do
      GenStructDef(0);  { Profondeur initiale = 0 }
    EmitAllStructDefs;
  End;
  
  { Generer quelques unions si autorisees }
  If Not Opts.NoUnions Then
  Begin
    NumGen := RandomRange(1, 3);  { Generer 1 a 3 unions }
    For I := 1 To NumGen Do
      GenUnionDef(0);  { Profondeur initiale = 0 }
    EmitAllUnionDefs;
  End;
  
  GenChecksumVars;
  GenChecksumFunc;
  { TODO: Generer les variables globales et fonctions }
  EmitBlankLine;
  GenMainFunc;
End;

{ ============================================================
  PROCEDURE PRINCIPALE
  ============================================================ }

Procedure Run;
Begin
  InitOptions;
  ParseArgs;

  If Opts.ShowHelp Then
  Begin
    ShowHelp;
    Halt(EXIT_OK);
  End;

  InitTables;
  InitRandom(Opts.Seed);

  If Not Opts.Quiet Then
  Begin
    WriteLn('CSMITH v', CSMITH_VERSION, ' - Generateur de code C aleatoire');
    WriteLn('Graine: ', RandomSeed);
  End;

  If Opts.OutputFile <> '' Then
  Begin
    EmitOpen(Opts.OutputFile);
    GenProgram;
    EmitClose;
    If Not Opts.Quiet Then
      WriteLn('Fichier genere: ', Opts.OutputFile, ' (', LineCount, ' lignes)');
  End
  Else
  Begin
    { Sortie sur stdout - rediriger OutFile vers output }
    Assign(OutFile, '');
    Rewrite(OutFile);
    IndentLevel := 0;
    LineCount := 0;
    GenProgram;
    Close(OutFile);
  End;
End;

{ ============================================================
  PROGRAMME PRINCIPAL
  ============================================================ }
Begin
  Run;
End.
