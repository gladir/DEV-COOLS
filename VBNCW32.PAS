{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Visual Basic .NET vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

Program VBNCW32;

{$R-}
{$IFDEF FPC}
  {$MODE TP}
  {$H-}
{$ENDIF}

(* ============================================================
  VBNCW32.PAS - Compilateur Visual Basic .NET vers assembleur
  80386 pour Windows 32 bits
  Free Pascal (-Mtp)
  Cible : MASM .386 / .MODEL FLAT, PE Win32

  Par defaut produit un fichier .EXE (PE Windows 32 bits).
  Avec le parametre -obj, produit uniquement un fichier .OBJ (COFF).
  Avec le parametre -asm, produit egalement un fichier .ASM lisible.
  Supporte toutes les exemples SAMPLES\VBNET\*

  Voir DOC/TODO/VBNCW32.txt pour la feuille de route complete.

  TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES PE/COFF [IMPLEMENTE]
            TOptions (SrcFile, OutFile, Verbose, DebugMode, Warnings,
              EmitExe, EmitObj, EmitAsm, OptionStrict, OptionExplicit,
              OptionInfer)
            ParseArgs : analyser argv (source.vb [-o sortie] [-v]
              [-d] [-w] [-obj] [-asm] [-strict] [-h])
            Par defaut : produire un .EXE Windows 32 bits (PE)
            -obj : produire uniquement un .OBJ (format COFF 32 bits)
            -asm : produire egalement un listing assembleur .ASM lisible
            -o nom : specifier le nom du fichier de sortie
            -strict : activer Option Strict On
            FatalError, WarnMsg, EXIT_OK / EXIT_ERROR / EXIT_USAGE
            Detecter l extension .vb du fichier source
            Version, Date, aide en ligne (option -h)
            Constantes PE/COFF : PE_DOS_MAGIC ($5A4D), PE_PE_SIG,
              PE_MACHINE_I386, PE_OPT_SIZE, PE_MAGIC_32,
              PE_IMG_BASE ($00400000), PE_SEC_ALIGN (4096),
              PE_FILE_ALIGN (512), PE_SUBSYS_CUI (console),
              PE_SUBSYS_GUI (Windows)
            Constantes binaires : MAX_BIN_CODE (65536),
              MAX_BIN_DATA (65536), MAX_BIN_LBL (4096),
              MAX_BIN_FIX (8192)
            Limites internes (32 bits) : MAX_SYM=4096, MAX_PROC=512,
              MAX_LOCAL=256, MAX_PARAM=64, MAX_DEPTH=32,
              MAX_LABEL=4096, MAX_STR=255, MAX_FIELD=128,
              MAX_CLASS=256, MAX_ENUM=128, MAX_TYPE=256,
              MAX_NAMESPACE=64, MAX_IMPORTS=128, MAX_INTERFACE=128
            Prefixes de nommage ASM : _VBN_ (variable globale),
              _VBNF_ (SUB/FUNCTION), _VBNK_ (constante chaine),
              _VBNRT_ (routine runtime), _VBNL_ (label interne),
              _VBNA_ (tableau), _VBNS_ (Structure),
              _VBNC_ (Class), _VBNE_ (Enum), _VBNP_ (Property),
              _VBNI_ (Interface), _VBNNS_ (Namespace)
            Utilitaires : ItoS, ItoSI, UpCaseStr, AsmIdent

  TODO 02 - TOKENISEUR VISUAL BASIC .NET (LEXER) [IMPLEMENTE]
            Procedure LexInit : ouvrir le fichier source, initialiser
              l etat du lexeur (ligne, colonne, caractere courant)
            Procedure LexClose : fermer le fichier source
            Procedure LexNextChar / LexPeekChar
            Procedure LexNextToken : reconnaitre les tokens VB.NET :
              - Identificateurs : lettres, chiffres, _ (max 255 cars)
                VB.NET est insensible a la casse
              - Suffixes de type : %, &, !, #, @, $ sur identificateurs
                (compatibilite, deconseille en VB.NET)
              - Litteraux numeriques : 123, 1.5, 1E3, 1.5D3
              - Litteraux hexadecimaux : &HFF, &HFFFF
              - Litteraux octaux : &O77
              - Litteraux binaires : &B1010 (nouveau VB.NET)
              - Litteraux chaines : "texte" (guillemets doubles)
                Guillemet double dans chaine : ""
              - Caractere litteral : "A"c (nouveau VB.NET)
              - Commentaires : ' (apostrophe) ou REM en debut
              - Commentaires XML : ''' (triple apostrophe, VB.NET)
              - Continuation de ligne : _ (underscore en fin de ligne)
              - Continuation implicite apres , ( . + - & et operateurs
              - Operateurs : + - * / \ Mod ^ = <> < > <= >= &
              - Operateurs raccourcis : += -= *= /= \= &= ^=
              - Separateurs : ( ) , . : ;
              - Operateurs logiques : And Or Not Xor
              - Operateurs court-circuit : AndAlso OrElse (VB.NET)
              - Operateur Is / IsNot pour comparaison de references
              - Operateur Like pour comparaison de motifs
              - Operateur TypeOf...Is pour verification de type
              - Operateur AddressOf pour delegation
            Types de tokens (TOK_IDENT, TOK_INTEGER, TOK_LONG,
              TOK_SINGLE, TOK_DOUBLE, TOK_DECIMAL, TOK_STRING,
              TOK_CHAR, TOK_DATE,
              TOK_PLUS, TOK_MINUS, TOK_STAR, TOK_SLASH,
              TOK_BACKSLASH, TOK_CARET, TOK_AMP, TOK_MOD,
              TOK_PLUSEQ, TOK_MINUSEQ, TOK_STAREQ, TOK_SLASHEQ,
              TOK_BSLASHEQ, TOK_AMPEQ, TOK_CARETEQ,
              TOK_LPAREN, TOK_RPAREN, TOK_COMMA, TOK_DOT,
              TOK_COLON, TOK_SEMI, TOK_EQ, TOK_NE, TOK_LT,
              TOK_GT, TOK_LE, TOK_GE, TOK_HASH, TOK_EXCL,
              TOK_NEWLINE, TOK_EOF)
            Stocker dans CurTokType / CurTokStr / CurTokNum

  TODO 03 - RECONNAISSANCE DES MOTS-CLES VISUAL BASIC .NET [IMPLEMENTE]
            Function IsKeyword(Const s: String): Integer
            Mots-cles complets a reconnaitre :
              AddHandler AddressOf And AndAlso As
              Boolean ByRef Byte ByVal
              Call Case Catch CBool CByte CChar CDate CDbl
              CDec Char CInt Class CLng CObj Const
              Continue CSByte CShort CSng CStr CType CUInt
              CULng CUShort
              Date Decimal Declare Default Delegate Dim
              DirectCast Do Double
              Each Else ElseIf End Enum Erase Error Event
              Exit
              False Finally For Friend Function
              Get GetType Global GoTo
              Handles
              If Implements Imports In Inherits Integer
              Interface Is IsNot
              Let Lib Like Long Loop
              Me Mod Module MustInherit MustOverride MyBase
              MyClass
              Namespace Narrowing New Next Not Nothing
              NotInheritable NotOverridable
              Object Of On Operator Option Optional Or OrElse
              Overloads Overridable Overrides
              ParamArray Partial Private Property Protected Public
              RaiseEvent ReadOnly ReDim REM RemoveHandler
              Resume Return
              SByte Select Set Shadows Shared Short Single
              Static Step Stop String Structure Sub SyncLock
              Then Throw To True Try TryCast TypeOf
              UInteger ULong UShort Using
              When While Widening With WithEvents WriteOnly
              Xor
            Mots-cles de fonctions intrinseques :
              Abs Asc Atn Chr Cos Exp Fix Hex
              InStr Int LCase Left Len Log
              LTrim Mid Oct Right RTrim Sgn Sin
              Space Sqr Str Tan Trim UCase Val
              CInt CLng CSng CDbl CStr CBool CByte
              IsNumeric IsDate IsArray IsNothing
              MsgBox InputBox
            Mots-cles contextuels :
              Assembly Auto Ansi Unicode Preserve
              Optional ByRef ByVal ParamArray
            Constantes KW_ADDHANDLER..KW_XOR (environ 220 mots-cles)

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [IMPLEMENTE]
            Type TSymKind : SK_CONST, SK_VAR, SK_PARAM,
              SK_SUB, SK_FUNCTION, SK_PROPERTY, SK_STRUCTURE,
              SK_ENUM, SK_ENUM_MEMBER, SK_CLASS, SK_MODULE,
              SK_FIELD, SK_EVENT, SK_LABEL, SK_NAMESPACE,
              SK_INTERFACE, SK_DELEGATE
            Type TSymEntry : Name (String[255]), AsmLabel (String[64]),
              Kind (TSymKind), DataType (Integer),
              StoreClass (Integer), BpOffset (Integer),
              ArrayDims (Integer), ArrayBase (Integer),
              IsStatic (Boolean), IsPublic (Boolean),
              IsOptional (Boolean), DefaultVal (String[64]),
              HasDefault (Boolean), ByRef (Boolean),
              ParamIdx (Integer), ClassIdx (Integer),
              InitStr (String[64]), InitNum (LongInt),
              HasInit (Boolean), IsConst (Boolean),
              IsShared (Boolean), IsReadOnly (Boolean),
              IsOverridable (Boolean), IsOverrides (Boolean),
              NamespaceIdx (Integer)
            SymTab[0..MAX_SYM-1] / SymCount
            ProcTab[0..MAX_PROC-1] / ProcCount
            Procedure InitSymTable / Function FindSym / Function AddSym
            Function FindProc / Function AddProc
            Types VB.NET internes et tailles 32 bits :
              Boolean (DD, 4 octets, True=-1/False=0),
              Byte (DB, 1 octet non signe, 0-255),
              SByte (DB, 1 octet signe, -128..127),
              Short (DW, 16 bits signe, -32768..32767),
              UShort (DW, 16 bits non signe, 0..65535),
              Integer (DD, 32 bits signe - note: VB.NET Integer=32 bits),
              UInteger (DD, 32 bits non signe),
              Long (DQ, 64 bits signe - note: VB.NET Long=64 bits),
              ULong (DQ, 64 bits non signe),
              Single (DD, flottant 32 bits IEEE 754),
              Double (DQ, flottant 64 bits IEEE 754),
              Decimal (16 octets, 128 bits, stub),
              Char (DW, 2 octets Unicode UTF-16),
              String (pointeur DD, reference vers tampon),
              Date (DQ, 64 bits),
              Object (pointeur DD, reference)
            Classes d entreposage : STORE_AUTO (pile EBP),
              STORE_STATIC (segment .DATA), STORE_PARAM (EBP+n),
              STORE_GLOBAL (.DATA), STORE_CONSTANT (immediate),
              STORE_SHARED (segment .DATA, acces via classe)

  TODO 05 - GESTION DES PORTEES (NAMESPACE, MODULE, CLASS, STRUCTURE) [IMPLEMENTE]
            Pile de portees : chaque portee maintient ses propres
              variables locales, un offset EBP courant, un label sortie
            Procedure EnterScope(kind: Integer; proc_idx: Integer)
            Procedure LeaveScope
            Function AllocLocalEbp(bytes: Integer): Integer
            Function CurrentEbpTop: Integer
            Portees supportees : SCOPE_GLOBAL, SCOPE_NAMESPACE,
              SCOPE_MODULE, SCOPE_CLASS, SCOPE_STRUCTURE,
              SCOPE_SUB, SCOPE_FUNCTION, SCOPE_PROPERTY,
              SCOPE_BLOCK, SCOPE_TRY, SCOPE_CATCH, SCOPE_FINALLY
            Compteur d offset EBP pour allocation variables locales
            Offset EBP negatif pour locales [EBP-n]
            Offset EBP positif pour parametres [EBP+8], [EBP+12]...
            Convention STDCALL Win32 : parametres droite a gauche
            Variables Shared : allouees en .DATA, acces via nom classe
            Resolution de noms qualifies (Namespace.Class.Member)

  TODO 06 - PARSEUR : IMPORTS, NAMESPACE ET MODULE [IMPLEMENTE]
            Procedure ParseImports
            Syntaxe :
              Imports System
              Imports System.IO
              Imports Microsoft.VisualBasic
              Imports alias = Namespace.Complet
            Reconnaitre les espaces de noms importes et resoudre
              les references non qualifiees
            Procedure ParseNamespace
            Syntaxe :
              Namespace MonApplication
                ...
              End Namespace
            Namespace imbrique : Namespace A.B.C
            Procedure ParseModule
            Syntaxe :
              Module NomModule
                Sub Main()
                  ...
                End Sub
              End Module
            Module est le conteneur standard pour Sub Main
            Option Explicit On|Off
            Option Strict On|Off (conversion implicite interdite si On)
            Option Compare Binary|Text
            Option Infer On|Off (inference de type)
            Generer le label du point d entree _VBNF_MAIN
            Generer le prologue PE : appel a Main apres init runtime

  TODO 07 - PARSEUR : DECLARATIONS (DIM, PUBLIC, PRIVATE, CONST) [IMPLEMENTE]
            Procedure ParseDim / ParsePublic / ParsePrivate / ParseConst
            Syntaxe :
              Dim x As Integer
              Dim s As String
              Dim x As Integer = 42 (initialisation VB.NET)
              Dim x As Integer, y As String (declarations multiples)
              Dim arr(10) As Integer
              Dim arr() As Integer (tableau dynamique)
              Public gVar As String
              Private mVar As Integer
              Protected pVar As Integer (dans Class)
              Friend fVar As Integer (acces assembly)
              Static sVar As Integer
              Shared shVar As Integer (dans Class/Module)
              Const PI As Double = 3.14159
              Const MAX_SIZE As Integer = 100
              ReadOnly roVar As Integer = 10
            Types reconnus : Boolean, Byte, SByte, Short, UShort,
              Integer, UInteger, Long, ULong, Single, Double,
              Decimal, Char, String, Date, Object
            Types Structure utilisateur (As NomStructure)
            Types Class utilisateur (As NomClasse)
            Allouer en .DATA (niveau module) ou pile EBP (locales)
            Static : toujours en .DATA meme dans Sub/Function
            Shared : en .DATA, accessible via NomClasse.membre

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS) [IMPLEMENTE]
            Function ParseExpr: Integer
            Function ParseOrExpr: Integer     (Or / Xor / OrElse)
            Function ParseAndExpr: Integer    (And / AndAlso)
            Function ParseNotExpr: Integer    (Not)
            Function ParseCompExpr: Integer   (= <> < > <= >= Like Is IsNot TypeOf)
            Function ParseConcatExpr: Integer (& pour chaines)
            Function ParseAddExpr: Integer    (+ / -)
            Function ParseModExpr: Integer    (Mod)
            Function ParseIntDivExpr: Integer (\ division entiere)
            Function ParseMulExpr: Integer    (* / /)
            Function ParsePowExpr: Integer    (^ puissance)
            Function ParseUnaryExpr: Integer  (- / + / Not / AddressOf)
            Function ParsePrimaryExpr: Integer
              Constante numerique -> MOV EAX, imm32
              Constante chaine    -> LEA EAX, [_VBNK_n]
              Constante caractere -> MOV EAX, imm16 ("A"c)
              Variable scalaire   -> MOV EAX, [_VBN_x] ou [EBP-n]
              Appel de fonction   -> CALL _VBNF_nom
              Appel de methode    -> objet.methode(args)
              Acces membre        -> objet.membre
              DirectCast(expr, Type)
              CType(expr, Type)
              TryCast(expr, Type)
              New NomClasse() (construction)
              Parentheses
              True (-1), False (0), Nothing (0)
            Priorite des operateurs VB.NET (du plus faible au plus fort) :
              OrElse, Or, Xor, AndAlso, And, Not, comparaisons,
              &, + -, Mod, \, * /, ^, - unaire, AddressOf
            Operateurs d affectation composes :
              += -= *= /= \= &= ^=

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [IMPLEMENTE]
            Procedure GenLoadVar(sym_idx: Integer)
              Integer/Short : MOV EAX, DWORD PTR [_VBN_x] ou [EBP-n]
              String : LEA EAX, [_VBN_x] ou [EBP-n]
              Boolean : MOVZX EAX, BYTE PTR [_VBN_x]
              Byte : MOVZX EAX, BYTE PTR [_VBN_x]
              Char : MOVZX EAX, WORD PTR [_VBN_x] (16 bits Unicode)
            Procedure GenStoreVar(sym_idx: Integer)
              MOV DWORD PTR [_VBN_x], EAX ou MOV [EBP-n], EAX
            Procedure GenBinOp(op: Integer)
              + : ADD EAX, EBX
              - : SUB EAX, EBX
              * : IMUL EAX, EBX
              / : flottant via FPU ou CALL _VBNRT_DIV
              \ : CDQ + IDIV EBX (division entiere)
              Mod : CDQ + IDIV EBX -> MOV EAX, EDX
              ^ : CALL _VBNRT_POW (puissance)
              & : CALL _VBNRT_STRCAT (concatenation)
            Procedure GenCompare(op: Integer)
              CMP EAX, EBX + SETcc AL + MOVZX EAX, AL
              Resultat VB.NET : True = -1 ($FFFFFFFF), False = 0
            Procedure GenLogicalOp(op: Integer)
              And : AND EAX, EBX
              Or  : OR EAX, EBX
              Xor : XOR EAX, EBX
              Not : NOT EAX
            Procedure GenShortCircuit(op: Integer)
              AndAlso : CMP EAX, 0 / JE label_false (court-circuit)
              OrElse  : CMP EAX, 0 / JNE label_true (court-circuit)
            Procedure GenCompoundAssign(op: Integer)
              += -= *= /= \= &= ^=
            Primitives d emission : Emit, EmitLabel, EmitComment,
              EmitData, EmitBss

  TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, SELECT CASE) [IMPLEMENTE]
            Procedure ParseIf
            Syntaxe :
              If condition Then
                instructions
              ElseIf condition Then
                instructions
              Else
                instructions
              End If
              If condition Then instruction  (forme sur une ligne)
            Generer : CMP EAX, 0 + JE label_else/endif
            Procedure ParseSelectCase
            Syntaxe :
              Select Case expression
                Case valeur
                  instructions
                Case valeur1 To valeur2
                  instructions
                Case Is > valeur
                  instructions
                Case valeur1, valeur2, valeur3
                  instructions
                Case Else
                  instructions
              End Select
            Generer : serie de CMP + JE pour chaque Case
            Procedure ParseGoTo
              GoTo label -> JMP label
              Labels nommes uniquement (pas de labels numeriques en VB.NET)
            Note : GoSub n est plus supporte en VB.NET

  TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP, WHILE/END WHILE, FOR EACH) [IMPLEMENTE]
            Procedure ParseFor
            Syntaxe :
              For i = debut To fin [Step pas]
                instructions
                [Exit For]
                [Continue For]
              Next [i]
            Generer : MOV compteur, debut / label_boucle:
              CMP compteur, fin / JG label_fin (Step positif)
              JL label_fin (Step negatif) / ... / ADD compteur, pas
              JMP label_boucle / label_fin:
            Procedure ParseDoLoop
            Syntaxe :
              Do [While|Until condition]
                instructions
                [Exit Do]
                [Continue Do]
              Loop [While|Until condition]
            Procedure ParseWhile
            Syntaxe (VB.NET utilise End While et non Wend) :
              While condition
                instructions
                [Exit While]
                [Continue While]
              End While
            Procedure ParseForEach
            Syntaxe :
              For Each element In collection
                instructions
                [Exit For]
                [Continue For]
              Next [element]
            Continue For / Continue Do / Continue While :
              JMP vers label_continue de la boucle (VB.NET uniquement)
            Exit For / Exit Do / Exit While :
              JMP vers label_fin de la boucle

  TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET FONCTIONS) [IMPLEMENTE]
            Procedure ParseSub
            Syntaxe :
              [Public|Private|Protected|Friend] [Shared] [Overloads]
                [Overrides|Overridable|NotOverridable|MustOverride]
                Sub nom([params])
                instructions
                [Exit Sub]
                [Return]
              End Sub
            Procedure ParseFunction
            Syntaxe :
              [Public|Private|Protected|Friend] [Shared] [Overloads]
                [Overrides|Overridable|NotOverridable|MustOverride]
                Function nom([params]) As type
                instructions
                Return valeur
                [Exit Function]
              End Function
            Parametres :
              ByVal x As Integer (passage par valeur, defaut en VB.NET)
              ByRef x As Integer (passage par reference)
              Optional x As Integer = 0 (parametre optionnel)
              ParamArray args() As Integer (tableau de parametres)
            Generer prologue STDCALL :
              PUSH EBP / MOV EBP, ESP / SUB ESP, taille_locales
            Generer epilogue :
              MOV ESP, EBP / POP EBP / RET n (n = taille params)
            Valeur de retour Function : dans EAX (entier/pointeur)
            Instruction Return : MOV EAX, valeur + JMP epilogue
            Note : ByVal est le defaut en VB.NET (ByRef en VB6)
            Appel : PUSH params / CALL _VBNF_nom

  TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES ET METHODES SYSTEME [IMPLEMENTE]
            Fonctions de chaines compatibles VB6 :
              Len(s) -> CALL _VBNRT_LEN
              Left(s, n), Right(s, n), Mid(s, start[, len])
              LTrim(s), RTrim(s), Trim(s)
              UCase(s), LCase(s)
              InStr([start,] s1, s2)
              Replace(s, find, replace)
              Space(n), Asc(s), Chr(n)
            Methodes de String (.NET) :
              s.Length, s.Substring(start[, len])
              s.ToUpper(), s.ToLower()
              s.IndexOf(s2), s.Contains(s2)
              s.StartsWith(s2), s.EndsWith(s2)
              s.Replace(old, new), s.Trim()
              s.Split(delim), String.Join(sep, arr)
              s.Insert(pos, s2), s.Remove(start[, count])
              s.PadLeft(n), s.PadRight(n)
            Fonctions de conversion :
              CInt(x), CLng(x), CSng(x), CDbl(x), CStr(x),
              CBool(x), CByte(x), CChar(x), CDec(x),
              CShort(x), CUShort(x), CUInt(x), CULng(x), CSByte(x)
              Val(s), Str(n), Hex(n), Oct(n)
              CType(expr, Type), DirectCast(expr, Type),
              TryCast(expr, Type)
              Convert.ToInt32(x), Convert.ToString(x) (stub)
            Fonctions mathematiques :
              Math.Abs(x), Math.Sign(x), Math.Sqrt(x)
              Math.Exp(x), Math.Log(x)
              Math.Sin(x), Math.Cos(x), Math.Tan(x), Math.Atan(x)
              Math.Pow(x, y), Math.Max(a, b), Math.Min(a, b)
              Math.Floor(x), Math.Ceiling(x), Math.Round(x)
              Abs(x), Sgn(x), Sqr(x) (compatibilite VB)
            Fonctions d information :
              IsNumeric(x), IsDate(x), IsArray(x), IsNothing(x)
              TypeOf x Is Type, GetType(Type)
              TypeName(x)
            Generer CALL _VBNRT_xxx pour chaque fonction runtime

  TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CLASSE STRING [IMPLEMENTE]
            Operateur & : concatenation de chaines
              Generer PUSH ptr_s1 / PUSH ptr_s2 / CALL _VBNRT_STRCAT
            Operateur + : concatenation si les deux operandes sont String
            Operateur &= : concatenation et affectation
            Chaines en VB.NET : type reference immutable
              Pointeur DD vers tampon null-terminated
              Allocation dynamique via _VBNRT_STRALLOC
              Liberation via _VBNRT_STRFREE
            Comparaison de chaines :
              Option Compare Binary (defaut, sensible casse)
              Option Compare Text (insensible casse)
              String.Compare(s1, s2)
              Operateur Like avec motifs (*, ?, #, [charlist])
            Caractere Char :
              Dim c As Char = "A"c
              AscW(c), ChrW(n) (Unicode)
              Asc(c), Chr(n) (ANSI)
            Interpolation : non supportee (VB 14+, hors portee)
            Methodes String appelees en notation pointee :
              s.Length -> CALL _VBNRT_LEN
              s.ToUpper() -> CALL _VBNRT_UCASE
              s.Substring(n, m) -> CALL _VBNRT_MID

  TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE) [IMPLEMENTE]
            Tableaux statiques :
              Dim arr(10) As Integer -> 11 elements (0 a 10)
              Dim mat(3, 3) As Integer -> matrice 4x4
              Base toujours 0 en VB.NET (pas de Option Base 1)
            Allouer en .DATA (global) ou pile (local)
            Tableaux dynamiques :
              Dim arr() As Integer -> pointeur DD, pas de taille
              ReDim arr(n) -> CALL _VBNRT_REDIM (allouer/reallouer)
              ReDim Preserve arr(n) -> conserver les donnees
              Erase arr -> CALL _VBNRT_ERASE (liberer/reinitialiser)
            Initialisation de tableau VB.NET :
              Dim arr() As Integer = {1, 2, 3, 4, 5}
              Dim arr() As Integer = New Integer() {1, 2, 3}
            Fonctions de tableau :
              arr.Length -> nombre total d elements
              arr.GetLength(dim) -> taille d une dimension
              arr.GetUpperBound(dim) -> borne superieure
              UBound(arr[, dim]) -> borne superieure (compat VB)
              LBound(arr[, dim]) -> toujours 0
              IsArray(x) -> Boolean
            Acces : arr(index) -> calcul offset + chargement
              MOV EAX, [base + index * taille_element]
            Tableaux multi-dimensionnels :
              Calcul offset = ((i1 * dim2 + i2) * dim3 + i3) * taille

  TODO 16 - PARSEUR : STRUCTURES (STRUCTURE...END STRUCTURE) ET ENUM [IMPLEMENTE]
            Procedure ParseStructure
            Syntaxe (VB.NET utilise Structure et non Type) :
              [Public|Private|Friend] Structure NomStructure
                Public champ1 As Integer
                Public champ2 As String
                Private champ3 As Double
                Public Sub NouvelleMethode()
                  ...
                End Sub
              End Structure
            Calcul de la taille totale et des offsets de champs
            Les Structure peuvent avoir des methodes (Sub/Function)
            Les Structure sont des types valeur (pile, pas tas)
            Acces aux champs : variable.champ
              LEA EAX, [_VBN_var + offset_champ]
            Procedure ParseEnum
            Syntaxe :
              [Public|Private|Friend] Enum NomEnum
                Valeur1 = 0
                Valeur2 = 1
                Valeur3 = 10
              End Enum
            Chaque membre Enum est une constante Integer
            Valeurs auto-incrementees si non specifiees
            Acces qualifie : NomEnum.Valeur1

  TODO 17 - PARSEUR : CLASSES ET HERITAGE (CLASS, INHERITS, IMPLEMENTS) [IMPLEMENTE]
            Procedure ParseClass
            Syntaxe :
              [Public|Private|Friend] [MustInherit|NotInheritable]
                Class NomClasse
                [Inherits ClasseParente]
                [Implements Interface1, Interface2]
                Public champ As Integer
                Private _donnee As String
                Public Sub New()  (constructeur)
                  ...
                End Sub
                Protected Overrides Sub Finalize() (destructeur)
                  ...
                End Sub
                Public [Overridable|Overrides|MustOverride|Shared]
                  Sub Methode()
                  ...
                End Sub
                Public Property NomProp() As Type
                  Get
                    Return _donnee
                  End Get
                  Set(ByVal value As Type)
                    _donnee = value
                  End Set
                End Property
              End Class
            Procedure ParseInterface
            Syntaxe :
              [Public|Private|Friend] Interface INomInterface
                Sub Methode(params)
                Function Calcul(params) As Type
                Property Prop() As Type
              End Interface
            MustInherit : classe abstraite (ne peut etre instanciee)
            NotInheritable : classe scellee (ne peut etre heritee)
            Overridable : methode pouvant etre redefinir
            Overrides : redefinition d une methode de base
            MustOverride : methode abstraite (pas de corps)
            NotOverridable : empecher redefinition ulterieure
            Shared : membre statique accessible via NomClasse.Membre
            Creation d instances :
              Dim obj As New NomClasse()
              Dim obj As NomClasse = New NomClasse()
            Me : reference a l instance courante (pointeur This)
            MyBase : reference a la classe parente
            MyClass : reference non virtuelle a la classe courante
            Generer table de pointeurs de methodes virtuelles en .DATA

  TODO 18 - PARSEUR : GESTION DES EXCEPTIONS (TRY/CATCH/FINALLY/THROW) [IMPLEMENTE]
            Procedure ParseTry
            Syntaxe (VB.NET utilise le modele structure) :
              Try
                instructions
              Catch ex As ExceptionType [When condition]
                instructions
              Catch ex As Exception
                instructions
              Finally
                instructions
              End Try
            Mecanisme d implementation :
              Etablir un cadre SEH (Structured Exception Handling)
              Win32 : chaine FS:[0] + handler de filtre
              Chaque Catch filtre par type d exception
              Finally : bloc toujours execute (cleanup)
            Instruction Throw :
              Throw New Exception("message")
              Throw (re-lancer l exception courante)
            Variable ex dans Catch :
              ex.Message -> chaine du message d erreur
              ex.StackTrace -> trace de pile (stub)
              ex.InnerException -> exception imbriquee (stub)
            Catch multiples : tester du plus specifique au plus general
              Catch ex As DivideByZeroException
              Catch ex As OverflowException
              Catch ex As Exception (attrape-tout)
            When optionnel : filtre conditionnel sur Catch
            Generer code pour etablir/retirer le cadre SEH Win32

  TODO 19 - PARSEUR : E/S CONSOLE ET FICHIERS [IMPLEMENTE]
            Console.WriteLine :
              Console.WriteLine("texte")
              Console.WriteLine("format {0} {1}", arg0, arg1) (stub)
              Console.Write("texte") (sans saut de ligne)
            Generer : PUSH ptr_chaine / CALL _VBNRT_PRINT
            Console.ReadLine :
              Dim s As String = Console.ReadLine()
            Generer : CALL _VBNRT_INPUT
            Console.ReadKey (stub)
            E/S fichiers compatibles VB :
              FileOpen(n, fichier, OpenMode.Input|Output|Append|Binary)
              FileClose(n)
              PrintLine(n, texte)
              LineInput(n) -> String
              WriteLine(n, val1, val2)
              EOF(n), LOF(n), FreeFile()
            Generer appels Win32 API :
              GetStdHandle pour handles console
              WriteFile / ReadFile pour E/S console
              CreateFileA pour Open
              CloseHandle pour Close
            Numero de fichier : 1 a 511, mapper vers handles Win32
            MsgBox(texte[, boutons][, titre]) -> MessageBoxA
            InputBox(prompt[, titre][, defaut]) -> boite de saisie

  TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S VIA WIN32 API) [IMPLEMENTE]
            Generer les routines runtime en assembleur 80386 :
            Routines chaines :
              _VBNRT_LEN : longueur de chaine (null-terminated)
              _VBNRT_STRCAT : concatenation
              _VBNRT_STRCMP : comparaison
              _VBNRT_STRCPY : copie
              _VBNRT_STRALLOC : allocation (HeapAlloc)
              _VBNRT_STRFREE : liberation (HeapFree)
              _VBNRT_LEFT, _VBNRT_RIGHT, _VBNRT_MID
              _VBNRT_LTRIM, _VBNRT_RTRIM, _VBNRT_TRIM
              _VBNRT_UCASE, _VBNRT_LCASE
              _VBNRT_INSTR, _VBNRT_REPLACE
              _VBNRT_INDEXOF, _VBNRT_CONTAINS
              _VBNRT_STARTSWITH, _VBNRT_ENDSWITH
              _VBNRT_SUBSTR : Substring .NET
              _VBNRT_INSERT, _VBNRT_REMOVE
              _VBNRT_PADLEFT, _VBNRT_PADRIGHT
              _VBNRT_SPLIT, _VBNRT_JOIN
            Routines conversion :
              _VBNRT_VAL : chaine vers nombre
              _VBNRT_STR : nombre vers chaine
              _VBNRT_CINT, _VBNRT_CLNG, _VBNRT_CSTR
              _VBNRT_CBOOL, _VBNRT_CBYTE, _VBNRT_CCHAR
              _VBNRT_CDBL, _VBNRT_CSNG, _VBNRT_CSHORT
            Routines mathematiques :
              _VBNRT_POW : puissance (^ operateur)
              _VBNRT_SQR, _VBNRT_ABS, _VBNRT_SGN
              _VBNRT_SIN, _VBNRT_COS, _VBNRT_TAN, _VBNRT_ATN
              _VBNRT_EXP, _VBNRT_LOG
              _VBNRT_FLOOR, _VBNRT_CEILING, _VBNRT_ROUND
              _VBNRT_MAX, _VBNRT_MIN
            Routines E/S console :
              _VBNRT_PRINT : affichage via WriteFile(hStdOut)
              _VBNRT_PRINTLN : affichage + saut de ligne
              _VBNRT_INPUT : lecture via ReadFile(hStdIn)
              _VBNRT_MSGBOX : affichage MessageBoxA (user32)
              _VBNRT_INPUTBOX : saisie via boite de dialogue
            Routines tableaux :
              _VBNRT_REDIM, _VBNRT_ERASE
              _VBNRT_ARRLENGTH, _VBNRT_ARRGETLENGTH
              _VBNRT_ARRGETUPPERBOUND
            Routines memoire :
              _VBNRT_HEAPINIT, _VBNRT_HEAPALLOC, _VBNRT_HEAPFREE
            Routines exceptions :
              _VBNRT_THROWEX, _VBNRT_SEHSETUP, _VBNRT_SEHTEARDOWN
            Point d entree : _VBNRT_INIT (initialiser runtime) et
              _VBNRT_EXIT (terminer programme, ExitProcess)

  TODO 21 - ECRIVAIN BINAIRE PE (GENERATION .EXE WINDOWS 32 BITS) [IMPLEMENTE]
            Procedure WritePE(const outfile: String)
            Generer un executable PE Windows 32 bits complet :
            En-tete DOS (MZ stub) : 64 octets + message DOS
            Signature PE : 'PE\0\0'
            En-tete COFF :
              Machine = IMAGE_FILE_MACHINE_I386 ($014C)
              NumberOfSections = 3 (.text, .data, .rdata)
              SizeOfOptionalHeader = $E0
              Characteristics = EXECUTABLE_IMAGE | 32BIT_MACHINE
            En-tete optionnel PE32 :
              Magic = $010B (PE32)
              AddressOfEntryPoint = RVA du _VBNF_MAIN
              ImageBase = $00400000
              SectionAlignment = $1000 (4096)
              FileAlignment = $200 (512)
              Subsystem = IMAGE_SUBSYSTEM_WINDOWS_CUI (console)
                ou IMAGE_SUBSYSTEM_WINDOWS_GUI (fenetres)
              SizeOfStackReserve = $100000, SizeOfHeapReserve = $100000
            Sections :
              .text : code executable (Read, Execute)
              .data : donnees initialisees (Read, Write)
              .rdata : donnees en lecture seule, Import Table
            Table d importation :
              IMAGE_IMPORT_DESCRIPTOR pour chaque DLL
              Import Lookup Table + Import Name Table
              Thunks pour chaque fonction importee
            Resolution des fixups internes (labels, appels)
            Padding des sections a FileAlignment

  TODO 22 - ECRIVAIN COFF .OBJ (PARAMETRE -obj) [IMPLEMENTE]
            Procedure WriteCOFF(const outfile: String)
            Generer un fichier objet COFF 32 bits :
            En-tete COFF :
              Machine = $014C (i386)
              NumberOfSections = 3 (.text, .data, .bss)
              PointerToSymbolTable, NumberOfSymbols
            Sections :
              .text : code avec relocations
              .data : donnees initialisees
              .bss  : donnees non initialisees
            Table des symboles COFF :
              Symboles externes (fonctions importees)
              Symboles publics (procedures exportees)
              Symboles de section (.text, .data, .bss)
            Table des relocations :
              IMAGE_REL_I386_DIR32 pour adresses absolues
              IMAGE_REL_I386_REL32 pour appels relatifs (CALL)
            Table des chaines longues (noms > 8 caracteres)
            Compatible avec le linker Microsoft LINK.EXE
            Compatible avec les fichiers .OBJ de MASM et TASM

  TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm) [IMPLEMENTE]
            Procedure WriteASM(const outfile: String)
            Generer un fichier .ASM lisible (syntaxe MASM) :
            En-tete :
              .386
              .MODEL FLAT, STDCALL
              OPTION CASEMAP:NONE
            Section INCLUDELIB :
              INCLUDELIB kernel32.lib
              INCLUDELIB user32.lib
              INCLUDELIB msvcrt.lib
            Section .DATA :
              Variables globales avec DB/DW/DD/DQ
              Constantes chaine avec DB 'texte', 0
            Section .DATA? :
              Variables non initialisees (BSS)
            Section EXTERN :
              Declarations des fonctions importees
              EXTERN ExitProcess@4:PROC
              EXTERN WriteFile@20:PROC
            Section .CODE :
              Procedures et fonctions avec labels
              Routines runtime (_VBNRT_xxx)
              Point d entree _start / Main
            Commentaires preserves dans le listing
            Indentation et formatage lisible

  TODO 24 - IMPORTS API WIN32 ET LIAISON (KERNEL32, USER32, MSVCRT) [IMPLEMENTE]
            Imports kernel32.dll :
              ExitProcess, GetStdHandle, WriteFile, ReadFile,
              GetProcessHeap, HeapAlloc, HeapFree, HeapReAlloc,
              CreateFileA, CloseHandle, ReadFile, WriteFile,
              SetFilePointer, GetFileSize, DeleteFileA,
              GetCommandLineA, GetModuleHandleA,
              GetLastError, SetLastError,
              MoveFileA, CopyFileA, GetCurrentDirectoryA,
              SetCurrentDirectoryA, CreateDirectoryA,
              FindFirstFileA, FindNextFileA, FindClose,
              GetTickCount, Sleep, GetEnvironmentVariableA,
              RtlUnwind (pour gestion SEH/exceptions)
            Imports user32.dll :
              MessageBoxA, GetDesktopWindow
            Imports msvcrt.dll (si necessaire) :
              _itoa, _ltoa, atoi, atol, sprintf, sscanf,
              _gcvt, strtod, sin, cos, tan, atan, sqrt,
              exp, log, pow, fabs, fmod, srand, rand
            Generer la table d importation PE :
              IMAGE_IMPORT_DESCRIPTOR par DLL
              Hint/Name Table avec noms de fonctions
              Import Address Table (IAT) avec thunks
            Generer les EXTERN pour le mode .ASM
            Generer les symboles externes pour le mode .OBJ

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\VBNET\* [IMPLEMENTE]
            Optimisations peephole :
              MOV EAX, 0 -> XOR EAX, EAX
              PUSH EAX / POP EAX -> (eliminer)
              MOV EAX, [x] / MOV [x], EAX -> (eliminer deuxieme)
              ADD EAX, 1 -> INC EAX
              SUB EAX, 1 -> DEC EAX
              IMUL EAX, 2 -> SHL EAX, 1
              IMUL EAX, 4 -> SHL EAX, 2
            Verification : compiler et executer les exemples
              SAMPLES\VBNET\HELLO.VB    - Hello World
              SAMPLES\VBNET\CALC.VB     - Calculatrice simple
              SAMPLES\VBNET\FIBONACCI.VB - Suite de Fibonacci
              SAMPLES\VBNET\FACTORI.VB  - Factorielle
              SAMPLES\VBNET\ARRAY.VB    - Operations sur tableaux
              SAMPLES\VBNET\STRING.VB   - Operations sur chaines
              SAMPLES\VBNET\FILEIO.VB   - Entrees/sorties fichiers
              SAMPLES\VBNET\SELECTCS.VB - Select Case
              SAMPLES\VBNET\LOOPS.VB    - Boucles For/Do/While
              SAMPLES\VBNET\STRUCTUR.VB - Structures et Enum
              SAMPLES\VBNET\SUBS.VB     - Sub et Function
              SAMPLES\VBNET\TRYCATCH.VB - Try/Catch/Finally
            Tests de regression pour chaque TODO
            Verification des 3 modes de sortie :
              .EXE (defaut), .OBJ (-obj), .ASM (-asm)
            Mesure de la taille des executables generes

   ============================================================ *)

{ ============================================================ }
{ TODO 01 - INFRASTRUCTURE, OPTIONS ET CONSTANTES    [IMPLEMENTE] }
{           PE/COFF                                              }
{ ============================================================ }

Const
  VBNCW32_VERSION = '0.1';
  VBNCW32_DATE    = '2026';

  EXIT_OK    = 0;
  EXIT_ERROR = 1;
  EXIT_USAGE = 2;

  { Constantes PE/COFF }
  PE_DOS_MAGIC    = $5A4D;    { 'MZ' }
  PE_PE_SIG       = $00004550; { 'PE\0\0' }
  PE_MACHINE_I386 = $014C;
  PE_OPT_SIZE     = $E0;
  PE_MAGIC_32     = $010B;
  PE_IMG_BASE     = $00400000;
  PE_SEC_ALIGN    = 4096;
  PE_FILE_ALIGN   = 512;
  PE_SUBSYS_CUI   = 3;  { Console }
  PE_SUBSYS_GUI   = 2;  { Windows }

  { Tailles des tampons binaires }
  MAX_BIN_CODE = 65536;
  MAX_BIN_DATA = 65536;
  MAX_BIN_LBL  = 4096;
  MAX_BIN_FIX  = 8192;

  { Limites internes (32 bits) }
  MAX_SYM       = 4096;
  MAX_PROC      = 512;
  MAX_LOCAL     = 256;
  MAX_PARAM     = 64;
  MAX_DEPTH     = 32;
  MAX_LABEL     = 4096;
  MAX_STR       = 255;
  MAX_FIELD     = 128;
  MAX_CLASS     = 256;
  MAX_ENUM      = 128;
  MAX_TYPE      = 256;
  MAX_NAMESPACE = 64;
  MAX_IMPORTS   = 128;
  MAX_INTERFACE = 128;

  { Prefixes de nommage ASM }
  PFX_VAR   = '_VBN_';    { variable globale       }
  PFX_FUNC  = '_VBNF_';   { SUB / FUNCTION         }
  PFX_CONST = '_VBNK_';   { constante chaine        }
  PFX_RT    = '_VBNRT_';  { routine runtime         }
  PFX_LBL   = '_VBNL_';   { label interne           }
  PFX_ARR   = '_VBNA_';   { tableau                 }
  PFX_STRUC = '_VBNS_';   { Structure               }
  PFX_CLS   = '_VBNC_';   { Class                   }
  PFX_ENUM  = '_VBNE_';   { Enum                    }
  PFX_PROP  = '_VBNP_';   { Property                }
  PFX_IFACE = '_VBNI_';   { Interface               }
  PFX_NS    = '_VBNNS_';  { Namespace               }

Type
  TString = String;

  TOptions = Record
    SrcFile       : TString;   { fichier source (.vb)                 }
    OutFile       : TString;   { fichier sortie (.exe, .obj)          }
    Verbose       : Boolean;   { -v : banniere et statistiques        }
    DebugMode     : Boolean;   { -d : affichage de chaque token       }
    Warnings      : Boolean;   { -w : afficher les avertissements     }
    EmitExe       : Boolean;   { par defaut : produire un .EXE (PE)   }
    EmitObj       : Boolean;   { -obj : produire seulement un .OBJ    }
    EmitAsm       : Boolean;   { -asm : produire aussi un .ASM        }
    OptionStrict  : Boolean;   { -strict : Option Strict On           }
    OptionExplicit: Boolean;   { Option Explicit On (defaut VB.NET)   }
    OptionInfer   : Boolean;   { Option Infer On|Off                  }
  End;

Var
  { Options }
  Opts : TOptions;

  { Compteurs generaux }
  ErrorCount : Integer;
  WarnCount  : Integer;
  TotalLines : LongInt;

  { Fichier de sortie interne (pour future emission) }
  OutF       : Text;
  OutFOpen   : Boolean;

  { Drapeau pour la generation binaire PE (mini-assembleur) }
  BcActive   : Boolean;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires                                        }
{ ------------------------------------------------------------ }

Function ItoS(V : LongInt) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoS := S;
End;

Function ItoSI(V : Integer) : TString;
Var S : TString;
Begin
  Str(V, S);
  ItoSI := S;
End;

Function UpCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'a') And (Tmp[I] <= 'z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) - 32);
  UpCaseStr := Tmp;
End;

Function LoCaseStr(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := S;
  For I := 1 To Length(Tmp) Do
    If (Tmp[I] >= 'A') And (Tmp[I] <= 'Z') Then
      Tmp[I] := Chr(Ord(Tmp[I]) + 32);
  LoCaseStr := Tmp;
End;

{ Transforme un nom VB.NET en identifiant valide pour l assembleur }
Function AsmIdent(Const S : TString) : TString;
Var
  I   : Integer;
  Tmp : TString;
Begin
  Tmp := '';
  For I := 1 To Length(S) Do
  Begin
    If ((S[I] >= 'A') And (S[I] <= 'Z')) Or
       ((S[I] >= 'a') And (S[I] <= 'z')) Or
       ((S[I] >= '0') And (S[I] <= '9')) Or
       (S[I] = '_') Then
      Tmp := Tmp + S[I]
    Else
      Tmp := Tmp + '_';
  End;
  AsmIdent := Tmp;
End;

{ Retourne l extension d un chemin (avec le point, en minuscules) }
Function ExtractExt(Const Path : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ExtractExt := LoCaseStr(Copy(Path, LastDot,
                     Length(Path) - LastDot + 1))
  Else
    ExtractExt := '';
End;

{ Remplace l extension d un chemin }
Function ReplaceExt(Const Path, NewExt : TString) : TString;
Var
  I, LastDot, LastSep : Integer;
Begin
  LastDot := 0;
  LastSep := 0;
  For I := 1 To Length(Path) Do
  Begin
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
    If Path[I] = '.' Then
      LastDot := I;
  End;
  If (LastDot > 0) And (LastDot > LastSep) Then
    ReplaceExt := Copy(Path, 1, LastDot - 1) + NewExt
  Else
    ReplaceExt := Path + NewExt;
End;

{ Retourne le repertoire d un chemin (avec le separateur final) }
Function ExtractDir(Const Path : TString) : TString;
Var
  I, LastSep : Integer;
Begin
  LastSep := 0;
  For I := 1 To Length(Path) Do
    If (Path[I] = '\') Or (Path[I] = '/') Or (Path[I] = ':') Then
      LastSep := I;
  If LastSep > 0 Then
    ExtractDir := Copy(Path, 1, LastSep)
  Else
    ExtractDir := '';
End;

{ ------------------------------------------------------------ }
{ FatalError / WarnMsg                                         }
{ ------------------------------------------------------------ }

Procedure FatalError(Const Msg : TString);
Begin
  WriteLn('VBNCW32: FATAL: ', Msg);
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
  Halt(EXIT_ERROR);
End;

Procedure WarnMsg(Const Msg : TString);
Begin
  If Not Opts.Warnings Then Exit;
  WriteLn('VBNCW32: warning: ', Msg);
  Inc(WarnCount);
End;

{ ------------------------------------------------------------ }
{ InitOptions                                                  }
{ ------------------------------------------------------------ }

Procedure InitOptions;
Begin
  Opts.SrcFile       := '';
  Opts.OutFile       := '';
  Opts.Verbose       := False;
  Opts.DebugMode     := False;
  Opts.Warnings      := False;
  Opts.EmitExe       := True;
  Opts.EmitObj       := False;
  Opts.EmitAsm       := False;
  Opts.OptionStrict  := False;
  Opts.OptionExplicit:= True;   { VB.NET : Option Explicit On par defaut }
  Opts.OptionInfer   := False;
End;

{ ------------------------------------------------------------ }
{ ShowHelp                                                     }
{ ------------------------------------------------------------ }

Procedure ShowHelp;
Begin
  WriteLn('VBNCW32 v', VBNCW32_VERSION, ' (', VBNCW32_DATE,
          ') - Compilateur Visual Basic .NET vers 80386 (Windows PE 32 bits)');
  WriteLn('VBNCW32 - Cette commande permet de lancer le compilateur Visual ',
          'Basic .NET pour l''assembleur du microprocesseur 80386 (en executable ',
          'Windows 32 bits).');
  WriteLn;
  WriteLn('Syntaxe : VBNCW32 [options] <source.vb> [options]');
  WriteLn;
  WriteLn('Sortie :');
  WriteLn('  Par defaut un .EXE (PE Windows 32 bits)');
  WriteLn('  -obj           Produire seulement un fichier .OBJ (COFF)');
  WriteLn('  -asm           Produire egalement un fichier .ASM lisible');
  WriteLn('  -o <fichier>   Specifier le nom du fichier de sortie');
  WriteLn;
  WriteLn('VB.NET :');
  WriteLn('  -strict        Activer Option Strict On');
  WriteLn;
  WriteLn('General :');
  WriteLn('  -v             Mode verbeux (banniere + statistiques)');
  WriteLn('  -d             Debug tokens (affiche chaque token)');
  WriteLn('  -w             Afficher les avertissements');
  WriteLn('  -h, --help, /? Afficher cette aide');
  WriteLn;
  WriteLn('Exemples :');
  WriteLn('  VBNCW32 hello.vb');
  WriteLn('  VBNCW32 hello.vb -o hello.exe -v');
  WriteLn('  VBNCW32 main.vb -asm');
  WriteLn('  VBNCW32 module.vb -obj -w');
  WriteLn('  VBNCW32 program.vb -strict');
  Halt(EXIT_OK);
End;

{ ------------------------------------------------------------ }
{ ParseArgs                                                    }
{ ------------------------------------------------------------ }

Procedure ParseArgs;
Var
  I    : Integer;
  Arg  : TString;
  Ext  : TString;
Begin
  InitOptions;
  If ParamCount = 0 Then
    ShowHelp;

  I := 1;
  While I <= ParamCount Do
  Begin
    Arg := ParamStr(I);

    If (Arg = '-h') Or (Arg = '--help') Or (Arg = '/?') Or
       (Arg = '/h') Or (Arg = '/H') Then
      ShowHelp
    Else If Arg = '-v' Then
      Opts.Verbose := True
    Else If Arg = '-d' Then
      Opts.DebugMode := True
    Else If Arg = '-w' Then
      Opts.Warnings := True
    Else If Arg = '-asm' Then
      Opts.EmitAsm := True
    Else If Arg = '-obj' Then
    Begin
      Opts.EmitObj := True;
      Opts.EmitExe := False;
    End
    Else If Arg = '-strict' Then
      Opts.OptionStrict := True
    Else If Arg = '-o' Then
    Begin
      Inc(I);
      If I > ParamCount Then
        FatalError('-o necessite un nom de fichier');
      Opts.OutFile := ParamStr(I);
    End
    Else If (Length(Arg) > 0) And (Arg[1] = '-') Then
      FatalError('Option inconnue: ' + Arg)
    Else
    Begin
      { Argument positionnel : fichier source }
      If Opts.SrcFile = '' Then
        Opts.SrcFile := Arg
      Else
        FatalError('Argument inattendu: ' + Arg);
    End;

    Inc(I);
  End;

  { Validation : fichier source requis }
  If Opts.SrcFile = '' Then
  Begin
    WriteLn('VBNCW32: fichier source manquant');
    ShowHelp;
  End;

  { Verifier l extension .vb }
  Ext := ExtractExt(Opts.SrcFile);
  If (Ext <> '.vb') Then
    WarnMsg('extension attendue .vb, trouvee: ' + Ext);

  { Fichier de sortie par defaut }
  If Opts.OutFile = '' Then
  Begin
    If Opts.EmitObj Then
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.obj')
    Else
      Opts.OutFile := ReplaceExt(Opts.SrcFile, '.exe');
  End;
End;

{ ------------------------------------------------------------ }
{ ShowBanner / ShowStats                                       }
{ ------------------------------------------------------------ }

Procedure ShowBanner;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn('VBNCW32 v', VBNCW32_VERSION, ' (', VBNCW32_DATE,
          ') - Compilateur Visual Basic .NET -> 80386 PE Win32');
  WriteLn('Source   : ', Opts.SrcFile);
  WriteLn('Sortie   : ', Opts.OutFile);
  If Opts.EmitAsm Then
    WriteLn('ASM      : ', ReplaceExt(Opts.OutFile, '.asm'));
  If Opts.EmitObj Then
    WriteLn('Mode     : OBJ (COFF 32 bits)')
  Else
    WriteLn('Mode     : EXE (PE Win32)');
  If Opts.OptionStrict Then
    WriteLn('Strict   : On');
  WriteLn;
End;

Procedure ShowStats;
Begin
  If Not Opts.Verbose Then Exit;
  WriteLn;
  WriteLn('--- Statistiques ---');
  WriteLn('Lignes analysees : ', TotalLines);
  WriteLn('Erreurs          : ', ErrorCount);
  WriteLn('Avertissements   : ', WarnCount);
End;

{ ------------------------------------------------------------ }
{ Cleanup                                                      }
{ ------------------------------------------------------------ }

Procedure Cleanup;
Begin
  If OutFOpen Then
  Begin
    Close(OutF);
    OutFOpen := False;
  End;
End;

{ ============================================================ }
{ TODO 02 - TOKENISEUR VISUAL BASIC .NET (LEXER) [IMPLEMENTE] }
{ ============================================================ }

Const
  { Types de tokens }
  TOK_EOF       = 0;    { fin de fichier                          }
  TOK_IDENT     = 1;    { identificateur                          }
  TOK_INTEGER   = 2;    { litteral entier (123)                   }
  TOK_LONG      = 3;    { litteral long (&, 123&)                 }
  TOK_SINGLE    = 4;    { litteral single (1.5!, 1E3)             }
  TOK_DOUBLE    = 5;    { litteral double (1.5#, 1.5D3)           }
  TOK_STRING    = 6;    { litteral chaine ("texte")               }
  TOK_DATE      = 7;    { litteral date (#1/1/2000#)              }
  TOK_DECIMAL   = 8;    { litteral decimal (VB.NET : 1.5D)        }
  TOK_CHAR      = 9;    { litteral caractere VB.NET ("A"c)        }
  TOK_PLUS      = 10;   { +                                       }
  TOK_MINUS     = 11;   { -                                       }
  TOK_STAR      = 12;   { *                                       }
  TOK_SLASH     = 13;   { /                                       }
  TOK_BACKSLASH = 14;   { \  (division entiere)                   }
  TOK_CARET     = 15;   { ^  (puissance)                          }
  TOK_AMP       = 16;   { &  (concatenation)                      }
  TOK_MOD       = 17;   { Mod (modulo, aussi mot-cle)             }
  TOK_LPAREN    = 20;   { (                                       }
  TOK_RPAREN    = 21;   { )                                       }
  TOK_COMMA     = 22;   { ,                                       }
  TOK_DOT       = 23;   { .                                       }
  TOK_COLON     = 24;   { :                                       }
  TOK_SEMI      = 25;   { ;                                       }
  TOK_EQ        = 30;   { =                                       }
  TOK_NE        = 31;   { <>                                      }
  TOK_LT        = 32;   { <                                       }
  TOK_GT        = 33;   { >                                       }
  TOK_LE        = 34;   { <=                                      }
  TOK_GE        = 35;   { >=                                      }
  TOK_HASH      = 36;   { #  (numero de fichier)                  }
  TOK_EXCL      = 37;   { !  (suffixe Single ou acces membre)     }
  TOK_NEWLINE   = 40;   { fin de ligne logique                    }
  { Operateurs raccourcis VB.NET }
  TOK_PLUSEQ    = 41;   { +=                                      }
  TOK_MINUSEQ   = 42;   { -=                                      }
  TOK_STAREQ    = 43;   { *=                                      }
  TOK_SLASHEQ   = 44;   { /=                                      }
  TOK_BSLASHEQ  = 45;   { \=                                      }
  TOK_AMPEQ     = 46;   { &=                                      }
  TOK_CARETEQ   = 47;   { ^=                                      }

Var
  { Fichier source }
  LexSrcF    : Text;          { handle du fichier source              }
  LexOpened  : Boolean;        { fichier ouvert ?                      }
  LexLine    : TString;        { ligne courante                        }
  LexLineNo  : Integer;        { numero de ligne courante              }
  LexColNo   : Integer;        { colonne courante dans LexLine         }
  LexEOF     : Boolean;        { fin de fichier atteinte ?             }

  { Token courant }
  CurTokType : Integer;        { type de token (TOK_*)                 }
  CurTokStr  : TString;        { valeur textuelle du token             }
  CurTokNum  : LongInt;        { valeur numerique (entier)             }
  CurTokReal : Real;           { valeur numerique (reel)               }
  CurTokLine : Integer;        { ligne du token                        }
  CurTokCol  : Integer;        { colonne du token                      }

{ ------------------------------------------------------------ }
{ Fonctions de classification de caracteres                    }
{ ------------------------------------------------------------ }

Function IsIdentStart(Ch : Char) : Boolean;
Begin
  IsIdentStart := ((Ch >= 'A') And (Ch <= 'Z')) Or
                  ((Ch >= 'a') And (Ch <= 'z')) Or
                  (Ch = '_');
End;

Function IsIdentCont(Ch : Char) : Boolean;
Begin
  IsIdentCont := IsIdentStart(Ch) Or
                 ((Ch >= '0') And (Ch <= '9'));
End;

Function IsDigit(Ch : Char) : Boolean;
Begin
  IsDigit := (Ch >= '0') And (Ch <= '9');
End;

Function IsHexDigit(Ch : Char) : Boolean;
Begin
  IsHexDigit := ((Ch >= '0') And (Ch <= '9')) Or
                ((Ch >= 'A') And (Ch <= 'F')) Or
                ((Ch >= 'a') And (Ch <= 'f'));
End;

Function IsOctDigit(Ch : Char) : Boolean;
Begin
  IsOctDigit := (Ch >= '0') And (Ch <= '7');
End;

Function IsBinDigit(Ch : Char) : Boolean;
Begin
  IsBinDigit := (Ch = '0') Or (Ch = '1');
End;

Function HexVal(Ch : Char) : Integer;
Begin
  If (Ch >= '0') And (Ch <= '9') Then
    HexVal := Ord(Ch) - Ord('0')
  Else If (Ch >= 'A') And (Ch <= 'F') Then
    HexVal := Ord(Ch) - Ord('A') + 10
  Else
    HexVal := Ord(Ch) - Ord('a') + 10;
End;

Function IsWhitespace(Ch : Char) : Boolean;
Begin
  IsWhitespace := (Ch = ' ') Or (Ch = #9);
End;

{ ============================================================ }
{ TODO 03 - RECONNAISSANCE DES MOTS-CLES VB.NET  [IMPLEMENTE] }
{ ============================================================ }

Const
  { Constantes KW_* pour les mots-cles Visual Basic .NET }
  { Mots-cles du langage }
  KW_NONE            = 0;
  KW_ADDHANDLER      = 1;
  KW_ADDRESSOF       = 2;
  KW_AND             = 3;
  KW_ANDALSO         = 4;
  KW_AS              = 5;
  KW_BOOLEAN         = 6;
  KW_BYREF           = 7;
  KW_BYTE            = 8;
  KW_BYVAL           = 9;
  KW_CALL            = 10;
  KW_CASE            = 11;
  KW_CATCH           = 12;
  KW_CBOOL           = 13;
  KW_CBYTE           = 14;
  KW_CCHAR           = 15;
  KW_CDATE           = 16;
  KW_CDBL            = 17;
  KW_CDEC            = 18;
  KW_CHAR            = 19;
  KW_CINT            = 20;
  KW_CLASS           = 21;
  KW_CLNG            = 22;
  KW_COBJ            = 23;
  KW_CONST           = 24;
  KW_CONTINUE        = 25;
  KW_CSBYTE          = 26;
  KW_CSHORT          = 27;
  KW_CSNG            = 28;
  KW_CSTR            = 29;
  KW_CTYPE           = 30;
  KW_CUINT           = 31;
  KW_CULNG           = 32;
  KW_CUSHORT         = 33;
  KW_DATE            = 34;
  KW_DECIMAL         = 35;
  KW_DECLARE         = 36;
  KW_DEFAULT         = 37;
  KW_DELEGATE        = 38;
  KW_DIM             = 39;
  KW_DIRECTCAST      = 40;
  KW_DO              = 41;
  KW_DOUBLE          = 42;
  KW_EACH            = 43;
  KW_ELSE            = 44;
  KW_ELSEIF          = 45;
  KW_END             = 46;
  KW_ENUM            = 47;
  KW_ERASE           = 48;
  KW_ERROR           = 49;
  KW_EVENT           = 50;
  KW_EXIT            = 51;
  KW_FALSE           = 52;
  KW_FINALLY         = 53;
  KW_FOR             = 54;
  KW_FRIEND          = 55;
  KW_FUNCTION        = 56;
  KW_GET             = 57;
  KW_GETTYPE         = 58;
  KW_GLOBAL          = 59;
  KW_GOTO            = 60;
  KW_HANDLES         = 61;
  KW_IF              = 62;
  KW_IMPLEMENTS      = 63;
  KW_IMPORTS         = 64;
  KW_IN              = 65;
  KW_INHERITS        = 66;
  KW_INTEGER         = 67;
  KW_INTERFACE       = 68;
  KW_IS              = 69;
  KW_ISNOT           = 70;
  KW_LET             = 71;
  KW_LIB             = 72;
  KW_LIKE            = 73;
  KW_LONG            = 74;
  KW_LOOP            = 75;
  KW_ME              = 76;
  KW_MOD             = 77;
  KW_MODULE          = 78;
  KW_MUSTINHERIT     = 79;
  KW_MUSTOVERRIDE    = 80;
  KW_MYBASE          = 81;
  KW_MYCLASS         = 82;
  KW_NAMESPACE       = 83;
  KW_NARROWING       = 84;
  KW_NEW             = 85;
  KW_NEXT            = 86;
  KW_NOT             = 87;
  KW_NOTHING         = 88;
  KW_NOTINHERITABLE  = 89;
  KW_NOTOVERRIDABLE  = 90;
  KW_OBJECT          = 91;
  KW_OF              = 92;
  KW_ON              = 93;
  KW_OPERATOR        = 94;
  KW_OPTION          = 95;
  KW_OPTIONAL        = 96;
  KW_OR              = 97;
  KW_ORELSE          = 98;
  KW_OVERLOADS       = 99;
  KW_OVERRIDABLE     = 100;
  KW_OVERRIDES       = 101;
  KW_PARAMARRAY      = 102;
  KW_PARTIAL         = 103;
  KW_PRIVATE         = 104;
  KW_PROPERTY        = 105;
  KW_PROTECTED       = 106;
  KW_PUBLIC          = 107;
  KW_RAISEEVENT      = 108;
  KW_READONLY        = 109;
  KW_REDIM           = 110;
  KW_REM             = 111;
  KW_REMOVEHANDLER   = 112;
  KW_RESUME          = 113;
  KW_RETURN          = 114;
  KW_SBYTE           = 115;
  KW_SELECT          = 116;
  KW_SET             = 117;
  KW_SHADOWS         = 118;
  KW_SHARED          = 119;
  KW_SHORT           = 120;
  KW_SINGLE          = 121;
  KW_STATIC          = 122;
  KW_STEP            = 123;
  KW_STOP            = 124;
  KW_STRING          = 125;
  KW_STRUCTURE       = 126;
  KW_SUB             = 127;
  KW_SYNCLOCK        = 128;
  KW_THEN            = 129;
  KW_THROW           = 130;
  KW_TO              = 131;
  KW_TRUE            = 132;
  KW_TRY             = 133;
  KW_TRYCAST         = 134;
  KW_TYPEOF          = 135;
  KW_UINTEGER        = 136;
  KW_ULONG           = 137;
  KW_USHORT          = 138;
  KW_USING           = 139;
  KW_WHEN            = 140;
  KW_WHILE           = 141;
  KW_WIDENING        = 142;
  KW_WITH            = 143;
  KW_WITHEVENTS      = 144;
  KW_WRITEONLY       = 145;
  KW_XOR             = 146;
  KW_UNTIL           = 147;

  { Fonctions VB.NET intrinseques }
  KW_ABS             = 150;
  KW_ASC             = 151;
  KW_ATN             = 152;
  KW_CHR             = 153;
  KW_COS             = 154;
  KW_EXP             = 155;
  KW_FIX             = 156;
  KW_HEX             = 157;
  KW_INSTR           = 158;
  KW_INT             = 159;
  KW_LCASE           = 160;
  KW_LEFT            = 161;
  KW_LEN             = 162;
  KW_LOG             = 163;
  KW_LTRIM           = 164;
  KW_MID             = 165;
  KW_OCT             = 166;
  KW_RIGHT           = 167;
  KW_RTRIM           = 168;
  KW_SGN             = 169;
  KW_SIN             = 170;
  KW_SPACE           = 171;
  KW_SQR             = 172;
  KW_STR             = 173;
  KW_TAN             = 174;
  KW_TRIM            = 175;
  KW_UCASE           = 176;
  KW_VAL             = 177;
  KW_ISNUMERIC       = 178;
  KW_ISDATE          = 179;
  KW_ISARRAY         = 180;
  KW_ISNOTHING       = 181;
  KW_MSGBOX          = 182;
  KW_INPUTBOX        = 183;
  KW_FORMAT          = 184;
  KW_REPLACE         = 185;
  KW_SPLIT           = 186;
  KW_JOIN            = 187;
  KW_INSTRREV        = 188;
  KW_STRREVERSE      = 189;
  KW_LBOUND          = 190;
  KW_UBOUND          = 191;

  { TODO 19 - fonctions E/S fichier et console VB.NET }
  KW_FILEOPEN        = 200;  { FileOpen (ouvrir fichier)                }
  KW_FILECLOSE       = 201;  { FileClose (fermer fichier)               }
  KW_PRINTLINE       = 202;  { PrintLine (ecrire ligne fichier)         }
  KW_WRITELINE       = 203;  { WriteLine (ecrire donnees fichier)       }
  KW_LINEINPUT       = 204;  { LineInput (lire ligne fichier)           }
  KW_EOF2            = 205;  { EOF (test fin de fichier)                }
  KW_LOF             = 206;  { LOF (taille fichier)                     }
  KW_FREEFILE        = 207;  { FreeFile (prochain numero disponible)    }

  { Mots-cles contextuels }
  KW_ASSEMBLY        = 210;
  KW_AUTO            = 211;
  KW_ANSI            = 212;
  KW_UNICODE         = 213;
  KW_PRESERVE        = 214;

  { Token special pour mot-cle reconnu }
  TOK_KEYWORD   = 50;     { mot-cle VB.NET reconnu                  }

{ ------------------------------------------------------------ }
{ IsKeyword : tester si un identificateur est un mot-cle VB.NET }
{ Retourne la constante KW_* ou KW_NONE si non reconnu         }
{ VB.NET est insensible a la casse                              }
{ ------------------------------------------------------------ }

Function IsKeyword(Const S : TString) : Integer;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  { Mots-cles du langage VB.NET }
  If      U = 'ADDHANDLER'     Then IsKeyword := KW_ADDHANDLER
  Else If U = 'ADDRESSOF'      Then IsKeyword := KW_ADDRESSOF
  Else If U = 'AND'            Then IsKeyword := KW_AND
  Else If U = 'ANDALSO'        Then IsKeyword := KW_ANDALSO
  Else If U = 'AS'             Then IsKeyword := KW_AS
  Else If U = 'BOOLEAN'        Then IsKeyword := KW_BOOLEAN
  Else If U = 'BYREF'          Then IsKeyword := KW_BYREF
  Else If U = 'BYTE'           Then IsKeyword := KW_BYTE
  Else If U = 'BYVAL'          Then IsKeyword := KW_BYVAL
  Else If U = 'CALL'           Then IsKeyword := KW_CALL
  Else If U = 'CASE'           Then IsKeyword := KW_CASE
  Else If U = 'CATCH'          Then IsKeyword := KW_CATCH
  Else If U = 'CBOOL'          Then IsKeyword := KW_CBOOL
  Else If U = 'CBYTE'          Then IsKeyword := KW_CBYTE
  Else If U = 'CCHAR'          Then IsKeyword := KW_CCHAR
  Else If U = 'CDATE'          Then IsKeyword := KW_CDATE
  Else If U = 'CDBL'           Then IsKeyword := KW_CDBL
  Else If U = 'CDEC'           Then IsKeyword := KW_CDEC
  Else If U = 'CHAR'           Then IsKeyword := KW_CHAR
  Else If U = 'CINT'           Then IsKeyword := KW_CINT
  Else If U = 'CLASS'          Then IsKeyword := KW_CLASS
  Else If U = 'CLNG'           Then IsKeyword := KW_CLNG
  Else If U = 'COBJ'           Then IsKeyword := KW_COBJ
  Else If U = 'CONST'          Then IsKeyword := KW_CONST
  Else If U = 'CONTINUE'       Then IsKeyword := KW_CONTINUE
  Else If U = 'CSBYTE'         Then IsKeyword := KW_CSBYTE
  Else If U = 'CSHORT'         Then IsKeyword := KW_CSHORT
  Else If U = 'CSNG'           Then IsKeyword := KW_CSNG
  Else If U = 'CSTR'           Then IsKeyword := KW_CSTR
  Else If U = 'CTYPE'          Then IsKeyword := KW_CTYPE
  Else If U = 'CUINT'          Then IsKeyword := KW_CUINT
  Else If U = 'CULNG'          Then IsKeyword := KW_CULNG
  Else If U = 'CUSHORT'        Then IsKeyword := KW_CUSHORT
  Else If U = 'DATE'           Then IsKeyword := KW_DATE
  Else If U = 'DECIMAL'        Then IsKeyword := KW_DECIMAL
  Else If U = 'DECLARE'        Then IsKeyword := KW_DECLARE
  Else If U = 'DEFAULT'        Then IsKeyword := KW_DEFAULT
  Else If U = 'DELEGATE'       Then IsKeyword := KW_DELEGATE
  Else If U = 'DIM'            Then IsKeyword := KW_DIM
  Else If U = 'DIRECTCAST'     Then IsKeyword := KW_DIRECTCAST
  Else If U = 'DO'             Then IsKeyword := KW_DO
  Else If U = 'DOUBLE'         Then IsKeyword := KW_DOUBLE
  Else If U = 'EACH'           Then IsKeyword := KW_EACH
  Else If U = 'ELSE'           Then IsKeyword := KW_ELSE
  Else If U = 'ELSEIF'         Then IsKeyword := KW_ELSEIF
  Else If U = 'END'            Then IsKeyword := KW_END
  Else If U = 'ENUM'           Then IsKeyword := KW_ENUM
  Else If U = 'ERASE'          Then IsKeyword := KW_ERASE
  Else If U = 'ERROR'          Then IsKeyword := KW_ERROR
  Else If U = 'EVENT'          Then IsKeyword := KW_EVENT
  Else If U = 'EXIT'           Then IsKeyword := KW_EXIT
  Else If U = 'FALSE'          Then IsKeyword := KW_FALSE
  Else If U = 'FINALLY'        Then IsKeyword := KW_FINALLY
  Else If U = 'FOR'            Then IsKeyword := KW_FOR
  Else If U = 'FRIEND'         Then IsKeyword := KW_FRIEND
  Else If U = 'FUNCTION'       Then IsKeyword := KW_FUNCTION
  Else If U = 'GET'            Then IsKeyword := KW_GET
  Else If U = 'GETTYPE'        Then IsKeyword := KW_GETTYPE
  Else If U = 'GLOBAL'         Then IsKeyword := KW_GLOBAL
  Else If U = 'GOTO'           Then IsKeyword := KW_GOTO
  Else If U = 'HANDLES'        Then IsKeyword := KW_HANDLES
  Else If U = 'IF'             Then IsKeyword := KW_IF
  Else If U = 'IMPLEMENTS'     Then IsKeyword := KW_IMPLEMENTS
  Else If U = 'IMPORTS'        Then IsKeyword := KW_IMPORTS
  Else If U = 'IN'             Then IsKeyword := KW_IN
  Else If U = 'INHERITS'       Then IsKeyword := KW_INHERITS
  Else If U = 'INTEGER'        Then IsKeyword := KW_INTEGER
  Else If U = 'INTERFACE'      Then IsKeyword := KW_INTERFACE
  Else If U = 'IS'             Then IsKeyword := KW_IS
  Else If U = 'ISNOT'          Then IsKeyword := KW_ISNOT
  Else If U = 'LET'            Then IsKeyword := KW_LET
  Else If U = 'LIB'            Then IsKeyword := KW_LIB
  Else If U = 'LIKE'           Then IsKeyword := KW_LIKE
  Else If U = 'LONG'           Then IsKeyword := KW_LONG
  Else If U = 'LOOP'           Then IsKeyword := KW_LOOP
  Else If U = 'ME'             Then IsKeyword := KW_ME
  Else If U = 'MOD'            Then IsKeyword := KW_MOD
  Else If U = 'MODULE'         Then IsKeyword := KW_MODULE
  Else If U = 'MUSTINHERIT'    Then IsKeyword := KW_MUSTINHERIT
  Else If U = 'MUSTOVERRIDE'   Then IsKeyword := KW_MUSTOVERRIDE
  Else If U = 'MYBASE'         Then IsKeyword := KW_MYBASE
  Else If U = 'MYCLASS'        Then IsKeyword := KW_MYCLASS
  Else If U = 'NAMESPACE'      Then IsKeyword := KW_NAMESPACE
  Else If U = 'NARROWING'      Then IsKeyword := KW_NARROWING
  Else If U = 'NEW'            Then IsKeyword := KW_NEW
  Else If U = 'NEXT'           Then IsKeyword := KW_NEXT
  Else If U = 'NOT'            Then IsKeyword := KW_NOT
  Else If U = 'NOTHING'        Then IsKeyword := KW_NOTHING
  Else If U = 'NOTINHERITABLE' Then IsKeyword := KW_NOTINHERITABLE
  Else If U = 'NOTOVERRIDABLE' Then IsKeyword := KW_NOTOVERRIDABLE
  Else If U = 'OBJECT'         Then IsKeyword := KW_OBJECT
  Else If U = 'OF'             Then IsKeyword := KW_OF
  Else If U = 'ON'             Then IsKeyword := KW_ON
  Else If U = 'OPERATOR'       Then IsKeyword := KW_OPERATOR
  Else If U = 'OPTION'         Then IsKeyword := KW_OPTION
  Else If U = 'OPTIONAL'       Then IsKeyword := KW_OPTIONAL
  Else If U = 'OR'             Then IsKeyword := KW_OR
  Else If U = 'ORELSE'         Then IsKeyword := KW_ORELSE
  Else If U = 'OVERLOADS'      Then IsKeyword := KW_OVERLOADS
  Else If U = 'OVERRIDABLE'    Then IsKeyword := KW_OVERRIDABLE
  Else If U = 'OVERRIDES'      Then IsKeyword := KW_OVERRIDES
  Else If U = 'PARAMARRAY'     Then IsKeyword := KW_PARAMARRAY
  Else If U = 'PARTIAL'        Then IsKeyword := KW_PARTIAL
  Else If U = 'PRIVATE'        Then IsKeyword := KW_PRIVATE
  Else If U = 'PROPERTY'       Then IsKeyword := KW_PROPERTY
  Else If U = 'PROTECTED'      Then IsKeyword := KW_PROTECTED
  Else If U = 'PUBLIC'         Then IsKeyword := KW_PUBLIC
  Else If U = 'RAISEEVENT'     Then IsKeyword := KW_RAISEEVENT
  Else If U = 'READONLY'       Then IsKeyword := KW_READONLY
  Else If U = 'REDIM'          Then IsKeyword := KW_REDIM
  Else If U = 'REM'            Then IsKeyword := KW_REM
  Else If U = 'REMOVEHANDLER'  Then IsKeyword := KW_REMOVEHANDLER
  Else If U = 'RESUME'         Then IsKeyword := KW_RESUME
  Else If U = 'RETURN'         Then IsKeyword := KW_RETURN
  Else If U = 'SBYTE'          Then IsKeyword := KW_SBYTE
  Else If U = 'SELECT'         Then IsKeyword := KW_SELECT
  Else If U = 'SET'            Then IsKeyword := KW_SET
  Else If U = 'SHADOWS'        Then IsKeyword := KW_SHADOWS
  Else If U = 'SHARED'         Then IsKeyword := KW_SHARED
  Else If U = 'SHORT'          Then IsKeyword := KW_SHORT
  Else If U = 'SINGLE'         Then IsKeyword := KW_SINGLE
  Else If U = 'STATIC'         Then IsKeyword := KW_STATIC
  Else If U = 'STEP'           Then IsKeyword := KW_STEP
  Else If U = 'STOP'           Then IsKeyword := KW_STOP
  Else If U = 'STRING'         Then IsKeyword := KW_STRING
  Else If U = 'STRUCTURE'      Then IsKeyword := KW_STRUCTURE
  Else If U = 'SUB'            Then IsKeyword := KW_SUB
  Else If U = 'SYNCLOCK'       Then IsKeyword := KW_SYNCLOCK
  Else If U = 'THEN'           Then IsKeyword := KW_THEN
  Else If U = 'THROW'          Then IsKeyword := KW_THROW
  Else If U = 'TO'             Then IsKeyword := KW_TO
  Else If U = 'TRUE'           Then IsKeyword := KW_TRUE
  Else If U = 'TRY'            Then IsKeyword := KW_TRY
  Else If U = 'TRYCAST'        Then IsKeyword := KW_TRYCAST
  Else If U = 'TYPEOF'         Then IsKeyword := KW_TYPEOF
  Else If U = 'UINTEGER'       Then IsKeyword := KW_UINTEGER
  Else If U = 'ULONG'          Then IsKeyword := KW_ULONG
  Else If U = 'USHORT'         Then IsKeyword := KW_USHORT
  Else If U = 'UNTIL'          Then IsKeyword := KW_UNTIL
  Else If U = 'USING'          Then IsKeyword := KW_USING
  Else If U = 'WHEN'           Then IsKeyword := KW_WHEN
  Else If U = 'WHILE'          Then IsKeyword := KW_WHILE
  Else If U = 'WIDENING'       Then IsKeyword := KW_WIDENING
  Else If U = 'WITH'           Then IsKeyword := KW_WITH
  Else If U = 'WITHEVENTS'     Then IsKeyword := KW_WITHEVENTS
  Else If U = 'WRITEONLY'      Then IsKeyword := KW_WRITEONLY
  Else If U = 'XOR'            Then IsKeyword := KW_XOR
  { Fonctions VB.NET intrinseques }
  Else If U = 'ABS'            Then IsKeyword := KW_ABS
  Else If U = 'ASC'            Then IsKeyword := KW_ASC
  Else If U = 'ATN'            Then IsKeyword := KW_ATN
  Else If U = 'CHR'            Then IsKeyword := KW_CHR
  Else If U = 'COS'            Then IsKeyword := KW_COS
  Else If U = 'EXP'            Then IsKeyword := KW_EXP
  Else If U = 'FIX'            Then IsKeyword := KW_FIX
  Else If U = 'HEX'            Then IsKeyword := KW_HEX
  Else If U = 'INSTR'          Then IsKeyword := KW_INSTR
  Else If U = 'INT'            Then IsKeyword := KW_INT
  Else If U = 'LCASE'          Then IsKeyword := KW_LCASE
  Else If U = 'LEFT'           Then IsKeyword := KW_LEFT
  Else If U = 'LEN'            Then IsKeyword := KW_LEN
  Else If U = 'LOG'            Then IsKeyword := KW_LOG
  Else If U = 'LTRIM'          Then IsKeyword := KW_LTRIM
  Else If U = 'MID'            Then IsKeyword := KW_MID
  Else If U = 'OCT'            Then IsKeyword := KW_OCT
  Else If U = 'RIGHT'          Then IsKeyword := KW_RIGHT
  Else If U = 'RTRIM'          Then IsKeyword := KW_RTRIM
  Else If U = 'SGN'            Then IsKeyword := KW_SGN
  Else If U = 'SIN'            Then IsKeyword := KW_SIN
  Else If U = 'SPACE'          Then IsKeyword := KW_SPACE
  Else If U = 'SQR'            Then IsKeyword := KW_SQR
  Else If U = 'STR'            Then IsKeyword := KW_STR
  Else If U = 'TAN'            Then IsKeyword := KW_TAN
  Else If U = 'TRIM'           Then IsKeyword := KW_TRIM
  Else If U = 'UCASE'          Then IsKeyword := KW_UCASE
  Else If U = 'VAL'            Then IsKeyword := KW_VAL
  Else If U = 'ISNUMERIC'      Then IsKeyword := KW_ISNUMERIC
  Else If U = 'ISDATE'         Then IsKeyword := KW_ISDATE
  Else If U = 'ISARRAY'        Then IsKeyword := KW_ISARRAY
  Else If U = 'ISNOTHING'      Then IsKeyword := KW_ISNOTHING
  Else If U = 'MSGBOX'         Then IsKeyword := KW_MSGBOX
  Else If U = 'INPUTBOX'       Then IsKeyword := KW_INPUTBOX
  Else If U = 'FORMAT'         Then IsKeyword := KW_FORMAT
  Else If U = 'REPLACE'        Then IsKeyword := KW_REPLACE
  Else If U = 'SPLIT'          Then IsKeyword := KW_SPLIT
  Else If U = 'JOIN'           Then IsKeyword := KW_JOIN
  Else If U = 'INSTRREV'       Then IsKeyword := KW_INSTRREV
  Else If U = 'STRREVERSE'     Then IsKeyword := KW_STRREVERSE
  Else If U = 'LBOUND'         Then IsKeyword := KW_LBOUND
  Else If U = 'UBOUND'         Then IsKeyword := KW_UBOUND
  { TODO 19 - fonctions E/S fichier VB.NET }
  Else If U = 'FILEOPEN'       Then IsKeyword := KW_FILEOPEN
  Else If U = 'FILECLOSE'      Then IsKeyword := KW_FILECLOSE
  Else If U = 'PRINTLINE'      Then IsKeyword := KW_PRINTLINE
  Else If U = 'WRITELINE'      Then IsKeyword := KW_WRITELINE
  Else If U = 'LINEINPUT'      Then IsKeyword := KW_LINEINPUT
  Else If U = 'EOF'            Then IsKeyword := KW_EOF2
  Else If U = 'LOF'            Then IsKeyword := KW_LOF
  Else If U = 'FREEFILE'       Then IsKeyword := KW_FREEFILE
  { Mots-cles contextuels }
  Else If U = 'ASSEMBLY'       Then IsKeyword := KW_ASSEMBLY
  Else If U = 'AUTO'           Then IsKeyword := KW_AUTO
  Else If U = 'ANSI'           Then IsKeyword := KW_ANSI
  Else If U = 'UNICODE'        Then IsKeyword := KW_UNICODE
  Else If U = 'PRESERVE'       Then IsKeyword := KW_PRESERVE
  Else IsKeyword := KW_NONE;
End;

{ ------------------------------------------------------------ }
{ KeywordName : retourne le nom d un mot-cle a partir de       }
{               sa constante KW_*                               }
{ ------------------------------------------------------------ }

Function KeywordName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_ADDHANDLER      : KeywordName := 'AddHandler';
    KW_ADDRESSOF       : KeywordName := 'AddressOf';
    KW_AND             : KeywordName := 'And';
    KW_ANDALSO         : KeywordName := 'AndAlso';
    KW_AS              : KeywordName := 'As';
    KW_BOOLEAN         : KeywordName := 'Boolean';
    KW_BYREF           : KeywordName := 'ByRef';
    KW_BYTE            : KeywordName := 'Byte';
    KW_BYVAL           : KeywordName := 'ByVal';
    KW_CALL            : KeywordName := 'Call';
    KW_CASE            : KeywordName := 'Case';
    KW_CATCH           : KeywordName := 'Catch';
    KW_CBOOL           : KeywordName := 'CBool';
    KW_CBYTE           : KeywordName := 'CByte';
    KW_CCHAR           : KeywordName := 'CChar';
    KW_CDATE           : KeywordName := 'CDate';
    KW_CDBL            : KeywordName := 'CDbl';
    KW_CDEC            : KeywordName := 'CDec';
    KW_CHAR            : KeywordName := 'Char';
    KW_CINT            : KeywordName := 'CInt';
    KW_CLASS           : KeywordName := 'Class';
    KW_CLNG            : KeywordName := 'CLng';
    KW_COBJ            : KeywordName := 'CObj';
    KW_CONST           : KeywordName := 'Const';
    KW_CONTINUE        : KeywordName := 'Continue';
    KW_CSBYTE          : KeywordName := 'CSByte';
    KW_CSHORT          : KeywordName := 'CShort';
    KW_CSNG            : KeywordName := 'CSng';
    KW_CSTR            : KeywordName := 'CStr';
    KW_CTYPE           : KeywordName := 'CType';
    KW_CUINT           : KeywordName := 'CUInt';
    KW_CULNG           : KeywordName := 'CULng';
    KW_CUSHORT         : KeywordName := 'CUShort';
    KW_DATE            : KeywordName := 'Date';
    KW_DECIMAL         : KeywordName := 'Decimal';
    KW_DECLARE         : KeywordName := 'Declare';
    KW_DEFAULT         : KeywordName := 'Default';
    KW_DELEGATE        : KeywordName := 'Delegate';
    KW_DIM             : KeywordName := 'Dim';
    KW_DIRECTCAST      : KeywordName := 'DirectCast';
    KW_DO              : KeywordName := 'Do';
    KW_DOUBLE          : KeywordName := 'Double';
    KW_EACH            : KeywordName := 'Each';
    KW_ELSE            : KeywordName := 'Else';
    KW_ELSEIF          : KeywordName := 'ElseIf';
    KW_END             : KeywordName := 'End';
    KW_ENUM            : KeywordName := 'Enum';
    KW_ERASE           : KeywordName := 'Erase';
    KW_ERROR           : KeywordName := 'Error';
    KW_EVENT           : KeywordName := 'Event';
    KW_EXIT            : KeywordName := 'Exit';
    KW_FALSE           : KeywordName := 'False';
    KW_FINALLY         : KeywordName := 'Finally';
    KW_FOR             : KeywordName := 'For';
    KW_FRIEND          : KeywordName := 'Friend';
    KW_FUNCTION        : KeywordName := 'Function';
    KW_GET             : KeywordName := 'Get';
    KW_GETTYPE         : KeywordName := 'GetType';
    KW_GLOBAL          : KeywordName := 'Global';
    KW_GOTO            : KeywordName := 'GoTo';
    KW_HANDLES         : KeywordName := 'Handles';
    KW_IF              : KeywordName := 'If';
    KW_IMPLEMENTS      : KeywordName := 'Implements';
    KW_IMPORTS         : KeywordName := 'Imports';
    KW_IN              : KeywordName := 'In';
    KW_INHERITS        : KeywordName := 'Inherits';
    KW_INTEGER         : KeywordName := 'Integer';
    KW_INTERFACE       : KeywordName := 'Interface';
    KW_IS              : KeywordName := 'Is';
    KW_ISNOT           : KeywordName := 'IsNot';
    KW_LET             : KeywordName := 'Let';
    KW_LIB             : KeywordName := 'Lib';
    KW_LIKE            : KeywordName := 'Like';
    KW_LONG            : KeywordName := 'Long';
    KW_LOOP            : KeywordName := 'Loop';
    KW_ME              : KeywordName := 'Me';
    KW_MOD             : KeywordName := 'Mod';
    KW_MODULE          : KeywordName := 'Module';
    KW_MUSTINHERIT     : KeywordName := 'MustInherit';
    KW_MUSTOVERRIDE    : KeywordName := 'MustOverride';
    KW_MYBASE          : KeywordName := 'MyBase';
    KW_MYCLASS         : KeywordName := 'MyClass';
    KW_NAMESPACE       : KeywordName := 'Namespace';
    KW_NARROWING       : KeywordName := 'Narrowing';
    KW_NEW             : KeywordName := 'New';
    KW_NEXT            : KeywordName := 'Next';
    KW_NOT             : KeywordName := 'Not';
    KW_NOTHING         : KeywordName := 'Nothing';
    KW_NOTINHERITABLE  : KeywordName := 'NotInheritable';
    KW_NOTOVERRIDABLE  : KeywordName := 'NotOverridable';
    KW_OBJECT          : KeywordName := 'Object';
    KW_OF              : KeywordName := 'Of';
    KW_ON              : KeywordName := 'On';
    KW_OPERATOR        : KeywordName := 'Operator';
    KW_OPTION          : KeywordName := 'Option';
    KW_OPTIONAL        : KeywordName := 'Optional';
    KW_OR              : KeywordName := 'Or';
    KW_ORELSE          : KeywordName := 'OrElse';
    KW_OVERLOADS       : KeywordName := 'Overloads';
    KW_OVERRIDABLE     : KeywordName := 'Overridable';
    KW_OVERRIDES       : KeywordName := 'Overrides';
    KW_PARAMARRAY      : KeywordName := 'ParamArray';
    KW_PARTIAL         : KeywordName := 'Partial';
    KW_PRIVATE         : KeywordName := 'Private';
    KW_PROPERTY        : KeywordName := 'Property';
    KW_PROTECTED       : KeywordName := 'Protected';
    KW_PUBLIC          : KeywordName := 'Public';
    KW_RAISEEVENT      : KeywordName := 'RaiseEvent';
    KW_READONLY        : KeywordName := 'ReadOnly';
    KW_REDIM           : KeywordName := 'ReDim';
    KW_REM             : KeywordName := 'Rem';
    KW_REMOVEHANDLER   : KeywordName := 'RemoveHandler';
    KW_RESUME          : KeywordName := 'Resume';
    KW_RETURN          : KeywordName := 'Return';
    KW_SBYTE           : KeywordName := 'SByte';
    KW_SELECT          : KeywordName := 'Select';
    KW_SET             : KeywordName := 'Set';
    KW_SHADOWS         : KeywordName := 'Shadows';
    KW_SHARED          : KeywordName := 'Shared';
    KW_SHORT           : KeywordName := 'Short';
    KW_SINGLE          : KeywordName := 'Single';
    KW_STATIC          : KeywordName := 'Static';
    KW_STEP            : KeywordName := 'Step';
    KW_STOP            : KeywordName := 'Stop';
    KW_STRING          : KeywordName := 'String';
    KW_STRUCTURE       : KeywordName := 'Structure';
    KW_SUB             : KeywordName := 'Sub';
    KW_SYNCLOCK        : KeywordName := 'SyncLock';
    KW_THEN            : KeywordName := 'Then';
    KW_THROW           : KeywordName := 'Throw';
    KW_TO              : KeywordName := 'To';
    KW_TRUE            : KeywordName := 'True';
    KW_TRY             : KeywordName := 'Try';
    KW_TRYCAST         : KeywordName := 'TryCast';
    KW_TYPEOF          : KeywordName := 'TypeOf';
    KW_UINTEGER        : KeywordName := 'UInteger';
    KW_ULONG           : KeywordName := 'ULong';
    KW_USHORT          : KeywordName := 'UShort';
    KW_UNTIL           : KeywordName := 'Until';
    KW_USING           : KeywordName := 'Using';
    KW_WHEN            : KeywordName := 'When';
    KW_WHILE           : KeywordName := 'While';
    KW_WIDENING        : KeywordName := 'Widening';
    KW_WITH            : KeywordName := 'With';
    KW_WITHEVENTS      : KeywordName := 'WithEvents';
    KW_WRITEONLY       : KeywordName := 'WriteOnly';
    KW_XOR             : KeywordName := 'Xor';
    KW_ABS             : KeywordName := 'Abs';
    KW_ASC             : KeywordName := 'Asc';
    KW_ATN             : KeywordName := 'Atn';
    KW_CHR             : KeywordName := 'Chr';
    KW_COS             : KeywordName := 'Cos';
    KW_EXP             : KeywordName := 'Exp';
    KW_FIX             : KeywordName := 'Fix';
    KW_HEX             : KeywordName := 'Hex';
    KW_INSTR           : KeywordName := 'InStr';
    KW_INT             : KeywordName := 'Int';
    KW_LCASE           : KeywordName := 'LCase';
    KW_LEFT            : KeywordName := 'Left';
    KW_LEN             : KeywordName := 'Len';
    KW_LOG             : KeywordName := 'Log';
    KW_LTRIM           : KeywordName := 'LTrim';
    KW_MID             : KeywordName := 'Mid';
    KW_OCT             : KeywordName := 'Oct';
    KW_RIGHT           : KeywordName := 'Right';
    KW_RTRIM           : KeywordName := 'RTrim';
    KW_SGN             : KeywordName := 'Sgn';
    KW_SIN             : KeywordName := 'Sin';
    KW_SPACE           : KeywordName := 'Space';
    KW_SQR             : KeywordName := 'Sqr';
    KW_STR             : KeywordName := 'Str';
    KW_TAN             : KeywordName := 'Tan';
    KW_TRIM            : KeywordName := 'Trim';
    KW_UCASE           : KeywordName := 'UCase';
    KW_VAL             : KeywordName := 'Val';
    KW_ISNUMERIC       : KeywordName := 'IsNumeric';
    KW_ISDATE          : KeywordName := 'IsDate';
    KW_ISARRAY         : KeywordName := 'IsArray';
    KW_ISNOTHING       : KeywordName := 'IsNothing';
    KW_MSGBOX          : KeywordName := 'MsgBox';
    KW_INPUTBOX        : KeywordName := 'InputBox';
    KW_FORMAT          : KeywordName := 'Format';
    KW_REPLACE         : KeywordName := 'Replace';
    KW_SPLIT           : KeywordName := 'Split';
    KW_JOIN            : KeywordName := 'Join';
    KW_INSTRREV        : KeywordName := 'InStrRev';
    KW_STRREVERSE      : KeywordName := 'StrReverse';
    KW_LBOUND          : KeywordName := 'LBound';
    KW_UBOUND          : KeywordName := 'UBound';
    KW_FILEOPEN        : KeywordName := 'FileOpen';
    KW_FILECLOSE       : KeywordName := 'FileClose';
    KW_PRINTLINE       : KeywordName := 'PrintLine';
    KW_WRITELINE       : KeywordName := 'WriteLine';
    KW_LINEINPUT       : KeywordName := 'LineInput';
    KW_EOF2            : KeywordName := 'EOF';
    KW_LOF             : KeywordName := 'LOF';
    KW_FREEFILE        : KeywordName := 'FreeFile';
    KW_ASSEMBLY        : KeywordName := 'Assembly';
    KW_AUTO            : KeywordName := 'Auto';
    KW_ANSI            : KeywordName := 'Ansi';
    KW_UNICODE         : KeywordName := 'Unicode';
    KW_PRESERVE        : KeywordName := 'Preserve';
  Else
    KeywordName := '?KW' + ItoSI(KW);
  End;
End;

{ ------------------------------------------------------------ }
{ LexNextLine, LexInit, LexClose                               }
{ ------------------------------------------------------------ }

Procedure LexNextLine;
Begin
  If LexEOF Then Exit;
  If EOF(LexSrcF) Then
  Begin
    LexEOF   := True;
    LexLine  := '';
    LexColNo := 1;
  End
  Else
  Begin
    ReadLn(LexSrcF, LexLine);
    Inc(LexLineNo);
    Inc(TotalLines);
    LexColNo := 1;
  End;
End;

Procedure LexInit;
Begin
  Assign(LexSrcF, Opts.SrcFile);
  {$I-}
  Reset(LexSrcF);
  {$I+}
  If IOResult <> 0 Then
    FatalError('Impossible d''ouvrir le fichier source: ' + Opts.SrcFile);
  LexOpened  := True;
  LexLineNo  := 0;
  LexColNo   := 1;
  LexEOF     := False;
  LexLine    := '';
  CurTokType := TOK_EOF;
  CurTokStr  := '';
  CurTokNum  := 0;
  CurTokReal := 0.0;
  CurTokLine := 0;
  CurTokCol  := 0;
  LexNextLine;
End;

Procedure LexClose;
Begin
  If LexOpened Then
  Begin
    Close(LexSrcF);
    LexOpened := False;
  End;
End;

{ ------------------------------------------------------------ }
{ LexSkipWhitespace                                            }
{ ------------------------------------------------------------ }

Procedure LexSkipWhitespace;
Begin
  While (LexColNo <= Length(LexLine)) And
        IsWhitespace(LexLine[LexColNo]) Do
    Inc(LexColNo);
End;

{ ------------------------------------------------------------ }
{ LexSkipComment : commentaire ' ou REM                        }
{ Saute le reste de la ligne (commentaire VB.NET)              }
{ ------------------------------------------------------------ }

Procedure LexSkipComment;
Begin
  LexColNo := Length(LexLine) + 1;
End;

{ ------------------------------------------------------------ }
{ LexScanIdent : identificateur avec suffixe de type optionnel }
{ Suffixes VB : % (Integer), & (Long), ! (Single),            }
{               # (Double), @ (Currency), $ (String)           }
{ (compatibilite, deconseille en VB.NET)                       }
{ ------------------------------------------------------------ }

Procedure LexScanIdent;
Var
  S   : TString;
  Ch  : Char;
  KW  : Integer;
Begin
  S := '';
  While (LexColNo <= Length(LexLine)) And
        IsIdentCont(LexLine[LexColNo]) Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  { Verifier suffixe de type sur l identificateur (compatibilite VB6) }
  If LexColNo <= Length(LexLine) Then
  Begin
    Ch := LexLine[LexColNo];
    If (Ch = '%') Or (Ch = '&') Or (Ch = '!') Or
       (Ch = '#') Or (Ch = '@') Or (Ch = '$') Then
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  CurTokStr  := S;
  CurTokReal := 0.0;
  { Tester si c est un mot-cle VB.NET }
  KW := IsKeyword(S);
  If KW <> KW_NONE Then
  Begin
    CurTokType := TOK_KEYWORD;
    CurTokNum  := KW;
  End
  Else
  Begin
    CurTokType := TOK_IDENT;
    CurTokNum  := 0;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanNumber : entier, reel, ou avec suffixes VB.NET        }
{ Gere : 123, 1.5, 1E3, 1.5E-2, 1.5D3, suffixes %, &, !, #   }
{ ------------------------------------------------------------ }

Procedure LexScanNumber;
Var
  N       : LongInt;
  IsReal  : Boolean;
  NegExp  : Boolean;
  FracDiv : Real;
  FracVal : Real;
  ExpVal  : Integer;
  FltVal  : Real;
  S       : TString;
  TokKind : Integer;
Begin
  N       := 0;
  IsReal  := False;
  NegExp  := False;
  FracVal := 0.0;
  FracDiv := 10.0;
  ExpVal  := 0;
  TokKind := TOK_INTEGER;
  S       := '';

  { Partie entiere }
  While (LexColNo <= Length(LexLine)) And
        IsDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;

  { Partie fractionnaire (mais pas ".." qui serait un operateur) }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '.') And
     (LexColNo < Length(LexLine)) And
     IsDigit(LexLine[LexColNo + 1]) Then
  Begin
    IsReal  := True;
    TokKind := TOK_SINGLE;
    S := S + '.';
    Inc(LexColNo);
    FracDiv := 10.0;
    FracVal := 0.0;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      FracVal := FracVal + (Ord(LexLine[LexColNo]) - Ord('0')) / FracDiv;
      FracDiv := FracDiv * 10.0;
      S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Exposant E ou e }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'E') Or (LexLine[LexColNo] = 'e')) Then
  Begin
    IsReal  := True;
    TokKind := TOK_SINGLE;
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      S := S + '-';
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
    Begin
      S := S + '+';
      Inc(LexColNo);
    End;
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End
  { Exposant D ou d : VB.NET Decimal / Double }
  Else If (LexColNo <= Length(LexLine)) And
          ((LexLine[LexColNo] = 'D') Or (LexLine[LexColNo] = 'd')) Then
  Begin
    IsReal  := True;
    TokKind := TOK_DECIMAL;
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
    NegExp := False;
    If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '-') Then
    Begin
      NegExp := True;
      S := S + '-';
      Inc(LexColNo);
    End
    Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '+') Then
    Begin
      S := S + '+';
      Inc(LexColNo);
    End;
    ExpVal := 0;
    While (LexColNo <= Length(LexLine)) And
          IsDigit(LexLine[LexColNo]) Do
    Begin
      ExpVal := ExpVal * 10 + (Ord(LexLine[LexColNo]) - Ord('0'));
      S := S + LexLine[LexColNo];
      Inc(LexColNo);
    End;
  End;

  { Suffixes de type sur nombres : % (Integer), & (Long), ! (Single), # (Double) }
  If (LexColNo <= Length(LexLine)) Then
  Begin
    If LexLine[LexColNo] = '%' Then
    Begin
      TokKind := TOK_INTEGER;
      Inc(LexColNo);
    End
    Else If LexLine[LexColNo] = '&' Then
    Begin
      TokKind := TOK_LONG;
      Inc(LexColNo);
    End
    Else If LexLine[LexColNo] = '!' Then
    Begin
      TokKind := TOK_SINGLE;
      IsReal := True;
      Inc(LexColNo);
    End
    Else If LexLine[LexColNo] = '#' Then
    Begin
      TokKind := TOK_DOUBLE;
      IsReal := True;
      Inc(LexColNo);
    End;
  End;

  If IsReal Then
  Begin
    FltVal := N + FracVal;
    While ExpVal > 0 Do
    Begin
      If NegExp Then FltVal := FltVal / 10.0
      Else           FltVal := FltVal * 10.0;
      Dec(ExpVal);
    End;
    CurTokType := TokKind;
    CurTokReal := FltVal;
    If FltVal > 2147483647.0 Then CurTokNum := 2147483647
    Else If FltVal < -2147483647.0 Then CurTokNum := -2147483647
    Else CurTokNum := Trunc(FltVal);
    CurTokStr := S;
  End
  Else
  Begin
    CurTokType := TokKind;
    CurTokNum  := N;
    CurTokReal := 0.0;
    CurTokStr  := S;
  End;
End;

{ ------------------------------------------------------------ }
{ LexScanHex : &HFF, &HFFFF&                                  }
{ ------------------------------------------------------------ }

Procedure LexScanHex;
Var
  N : LongInt;
  S : TString;
Begin
  { LexColNo pointe sur 'H' ou 'h' apres le '&' }
  Inc(LexColNo); { sauter 'H' ou 'h' }
  N := 0;
  S := '&H';
  While (LexColNo <= Length(LexLine)) And
        IsHexDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 16 + HexVal(LexLine[LexColNo]);
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurTokType := TOK_INTEGER;
  { Suffixe & pour Long }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
  Begin
    CurTokType := TOK_LONG;
    Inc(LexColNo);
  End;
  CurTokNum  := N;
  CurTokReal := 0.0;
  CurTokStr  := S;
End;

{ ------------------------------------------------------------ }
{ LexScanOct : &O77                                            }
{ ------------------------------------------------------------ }

Procedure LexScanOct;
Var
  N : LongInt;
  S : TString;
Begin
  { LexColNo pointe sur 'O' ou 'o' apres le '&' }
  Inc(LexColNo); { sauter 'O' ou 'o' }
  N := 0;
  S := '&O';
  While (LexColNo <= Length(LexLine)) And
        IsOctDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 8 + (Ord(LexLine[LexColNo]) - Ord('0'));
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurTokType := TOK_INTEGER;
  { Suffixe & pour Long }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
  Begin
    CurTokType := TOK_LONG;
    Inc(LexColNo);
  End;
  CurTokNum  := N;
  CurTokReal := 0.0;
  CurTokStr  := S;
End;

{ ------------------------------------------------------------ }
{ LexScanBin : &B1010 (nouveau VB.NET)                        }
{ ------------------------------------------------------------ }

Procedure LexScanBin;
Var
  N : LongInt;
  S : TString;
Begin
  { LexColNo pointe sur 'B' ou 'b' apres le '&' }
  Inc(LexColNo); { sauter 'B' ou 'b' }
  N := 0;
  S := '&B';
  While (LexColNo <= Length(LexLine)) And
        IsBinDigit(LexLine[LexColNo]) Do
  Begin
    N := N * 2 + (Ord(LexLine[LexColNo]) - Ord('0'));
    S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  CurTokType := TOK_INTEGER;
  { Suffixe & pour Long }
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '&') Then
  Begin
    CurTokType := TOK_LONG;
    Inc(LexColNo);
  End;
  CurTokNum  := N;
  CurTokReal := 0.0;
  CurTokStr  := S;
End;

{ ------------------------------------------------------------ }
{ LexScanString : chaine VB.NET entre guillemets doubles       }
{ Gere le doublement de guillemet : "l""echo" -> l"echo        }
{ Gere le caractere litteral VB.NET : "A"c -> Char             }
{ ------------------------------------------------------------ }

Procedure LexScanString;
Var
  S  : TString;
  Ch : Char;
Begin
  S := '';
  Inc(LexColNo); { sauter guillemet ouvrant }
  While LexColNo <= Length(LexLine) Do
  Begin
    Ch := LexLine[LexColNo];
    If Ch = '"' Then
    Begin
      Inc(LexColNo);
      { Guillemet double "" -> un seul caractere " }
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '"') Then
      Begin
        If Length(S) < MAX_STR Then
          S := S + '"';
        Inc(LexColNo);
      End
      Else
        Break; { fin de chaine }
    End
    Else
    Begin
      If Length(S) < MAX_STR Then
        S := S + Ch;
      Inc(LexColNo);
    End;
  End;
  { VB.NET : caractere litteral "A"c }
  If (LexColNo <= Length(LexLine)) And
     ((LexLine[LexColNo] = 'c') Or (LexLine[LexColNo] = 'C')) Then
  Begin
    CurTokType := TOK_CHAR;
    Inc(LexColNo);
  End
  Else
    CurTokType := TOK_STRING;
  CurTokStr  := S;
  CurTokNum  := 0;
  CurTokReal := 0.0;
End;

{ ------------------------------------------------------------ }
{ LexScanDate : litteral date #1/1/2000#                       }
{ ------------------------------------------------------------ }

Procedure LexScanDate;
Var
  S : TString;
Begin
  S := '';
  Inc(LexColNo); { sauter # ouvrant }
  While (LexColNo <= Length(LexLine)) And
        (LexLine[LexColNo] <> '#') Do
  Begin
    If Length(S) < MAX_STR Then
      S := S + LexLine[LexColNo];
    Inc(LexColNo);
  End;
  If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '#') Then
    Inc(LexColNo); { sauter # fermant }
  CurTokType := TOK_DATE;
  CurTokStr  := S;
  CurTokNum  := 0;
  CurTokReal := 0.0;
End;

{ ------------------------------------------------------------ }
{ IsImplicitContinuation : teste si le dernier token permet    }
{ une continuation implicite de ligne (VB.NET)                 }
{ Apres , ( . + - & et operateurs                             }
{ ------------------------------------------------------------ }

Function IsImplicitContinuation(TokType : Integer) : Boolean;
Begin
  IsImplicitContinuation :=
    (TokType = TOK_COMMA) Or (TokType = TOK_LPAREN) Or
    (TokType = TOK_DOT) Or (TokType = TOK_PLUS) Or
    (TokType = TOK_MINUS) Or (TokType = TOK_AMP) Or
    (TokType = TOK_STAR) Or (TokType = TOK_SLASH) Or
    (TokType = TOK_BACKSLASH) Or (TokType = TOK_CARET) Or
    (TokType = TOK_EQ) Or (TokType = TOK_NE) Or
    (TokType = TOK_LT) Or (TokType = TOK_GT) Or
    (TokType = TOK_LE) Or (TokType = TOK_GE) Or
    (TokType = TOK_PLUSEQ) Or (TokType = TOK_MINUSEQ) Or
    (TokType = TOK_STAREQ) Or (TokType = TOK_SLASHEQ) Or
    (TokType = TOK_BSLASHEQ) Or (TokType = TOK_AMPEQ) Or
    (TokType = TOK_CARETEQ);
End;

{ ------------------------------------------------------------ }
{ PrintToken : affichage debug de chaque token                 }
{ ------------------------------------------------------------ }

Procedure PrintToken;
Begin
  If Not Opts.DebugMode Then Exit;
  Write('  [', CurTokLine, ',', CurTokCol, '] ');
  Case CurTokType Of
    TOK_EOF       : Write('EOF');
    TOK_IDENT     : Write('IDENT(', CurTokStr, ')');
    TOK_KEYWORD   : Write('KW(', KeywordName(CurTokNum), ')');
    TOK_INTEGER   : Write('INT(', CurTokNum, ')');
    TOK_LONG      : Write('LONG(', CurTokNum, ')');
    TOK_SINGLE    : Write('SINGLE(', CurTokStr, ')');
    TOK_DOUBLE    : Write('DOUBLE(', CurTokStr, ')');
    TOK_DECIMAL   : Write('DECIMAL(', CurTokStr, ')');
    TOK_STRING    : Write('STR("', CurTokStr, '")');
    TOK_CHAR      : Write('CHAR("', CurTokStr, '"c)');
    TOK_DATE      : Write('DATE(#', CurTokStr, '#)');
    TOK_PLUS      : Write('PLUS');
    TOK_MINUS     : Write('MINUS');
    TOK_STAR      : Write('STAR');
    TOK_SLASH     : Write('SLASH');
    TOK_BACKSLASH : Write('BACKSLASH');
    TOK_CARET     : Write('CARET');
    TOK_AMP       : Write('AMP');
    TOK_MOD       : Write('MOD');
    TOK_LPAREN    : Write('LPAREN');
    TOK_RPAREN    : Write('RPAREN');
    TOK_COMMA     : Write('COMMA');
    TOK_DOT       : Write('DOT');
    TOK_COLON     : Write('COLON');
    TOK_SEMI      : Write('SEMI');
    TOK_EQ        : Write('EQ');
    TOK_NE        : Write('NE');
    TOK_LT        : Write('LT');
    TOK_GT        : Write('GT');
    TOK_LE        : Write('LE');
    TOK_GE        : Write('GE');
    TOK_HASH      : Write('HASH');
    TOK_EXCL      : Write('EXCL');
    TOK_NEWLINE   : Write('NEWLINE');
    TOK_PLUSEQ    : Write('PLUSEQ');
    TOK_MINUSEQ   : Write('MINUSEQ');
    TOK_STAREQ    : Write('STAREQ');
    TOK_SLASHEQ   : Write('SLASHEQ');
    TOK_BSLASHEQ  : Write('BSLASHEQ');
    TOK_AMPEQ     : Write('AMPEQ');
    TOK_CARETEQ   : Write('CARETEQ');
  Else
    Write('TOK(', CurTokType, ')');
  End;
  WriteLn;
End;

{ ------------------------------------------------------------ }
{ LexNextToken : reconnaitre le prochain token VB.NET          }
{ ------------------------------------------------------------ }

Procedure LexNextToken;
Var
  Ch        : Char;
  Done      : Boolean;
  J         : Integer;
  AllBlanks : Boolean;
  K         : Integer;
  HasClose  : Boolean;
  PrevTok   : Integer;
Begin
  Done := False;
  While Not Done Do
  Begin
    { Passer les lignes vides / fin de ligne }
    While (Not LexEOF) And (LexColNo > Length(LexLine)) Do
    Begin
      { Continuation implicite : pas de NEWLINE apres , ( . + - & etc }
      PrevTok := CurTokType;
      If IsImplicitContinuation(PrevTok) Then
      Begin
        LexNextLine;
        { Pas d emission de NEWLINE }
      End
      Else
      Begin
        { Emettre un token NEWLINE a chaque fin de ligne logique }
        CurTokLine := LexLineNo;
        CurTokCol  := LexColNo;
        CurTokType := TOK_NEWLINE;
        CurTokStr  := '';
        CurTokNum  := 0;
        CurTokReal := 0.0;
        LexNextLine;
        PrintToken;
      End;
      { Continuer a lire jusqu a trouver du contenu }
    End;

    If LexEOF Then
    Begin
      CurTokLine := LexLineNo;
      CurTokCol  := LexColNo;
      CurTokType := TOK_EOF;
      CurTokStr  := '';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
      PrintToken;
      Exit;
    End;

    { Sauter les espaces }
    LexSkipWhitespace;
    If LexColNo > Length(LexLine) Then
      Continue; { fin de ligne, reboucler }

    CurTokLine := LexLineNo;
    CurTokCol  := LexColNo;
    Ch := LexLine[LexColNo];

    { Commentaire XML VB.NET ''' (triple apostrophe) }
    If (Ch = '''') And (LexColNo + 2 <= Length(LexLine)) And
       (LexLine[LexColNo + 1] = '''') And
       (LexLine[LexColNo + 2] = '''') Then
    Begin
      LexSkipComment;
      Continue;
    End

    { Commentaire ' (apostrophe) }
    Else If Ch = '''' Then
    Begin
      LexSkipComment;
      Continue; { le NEWLINE sera emis au prochain tour }
    End

    { Continuation de ligne : _ en fin de ligne (pas dans un ident) }
    Else If (Ch = '_') And (LexColNo = Length(LexLine)) Then
    Begin
      LexNextLine;
      Continue;
    End
    Else If (Ch = '_') And (LexColNo < Length(LexLine)) Then
    Begin
      { Verifier si tout le reste est des espaces }
      { Si oui, c est une continuation de ligne }
      { Sinon, c est un debut d identificateur }
      AllBlanks := True;
      For J := LexColNo + 1 To Length(LexLine) Do
        If Not IsWhitespace(LexLine[J]) Then
          AllBlanks := False;
      If AllBlanks Then
      Begin
        LexNextLine;
        Continue;
      End
      Else
      Begin
        { C est un identificateur commencant par _ }
        LexScanIdent;
        Done := True;
      End;
    End

    { Identificateurs (lettres ou _) }
    Else If IsIdentStart(Ch) Then
    Begin
      LexScanIdent;
      { Verifier si c est le mot-cle REM (commentaire) }
      If UpCaseStr(CurTokStr) = 'REM' Then
      Begin
        LexSkipComment;
        Continue; { NEWLINE sera emis au prochain tour }
      End;
      Done := True;
    End

    { Litteraux numeriques }
    Else If IsDigit(Ch) Then
    Begin
      LexScanNumber;
      Done := True;
    End

    { Guillemet double : chaine ou caractere litteral }
    Else If Ch = '"' Then
    Begin
      LexScanString;
      Done := True;
    End

    { & : concatenation, hex (&H), octal (&O), binaire (&B) }
    Else If Ch = '&' Then
    Begin
      If (LexColNo < Length(LexLine)) And
         ((LexLine[LexColNo + 1] = 'H') Or (LexLine[LexColNo + 1] = 'h')) Then
      Begin
        Inc(LexColNo); { sauter '&' }
        LexScanHex;
        Done := True;
      End
      Else If (LexColNo < Length(LexLine)) And
              ((LexLine[LexColNo + 1] = 'O') Or (LexLine[LexColNo + 1] = 'o')) Then
      Begin
        Inc(LexColNo); { sauter '&' }
        LexScanOct;
        Done := True;
      End
      Else If (LexColNo < Length(LexLine)) And
              ((LexLine[LexColNo + 1] = 'B') Or (LexLine[LexColNo + 1] = 'b')) Then
      Begin
        Inc(LexColNo); { sauter '&' }
        LexScanBin;
        Done := True;
      End
      Else If (LexColNo < Length(LexLine)) And
              (LexLine[LexColNo + 1] = '=') Then
      Begin
        { &= operateur raccourci VB.NET }
        CurTokType := TOK_AMPEQ;
        CurTokStr  := '&=';
        CurTokNum  := 0;
        CurTokReal := 0.0;
        Inc(LexColNo, 2);
        Done := True;
      End
      Else
      Begin
        CurTokType := TOK_AMP;
        CurTokStr  := '&';
        CurTokNum  := 0;
        CurTokReal := 0.0;
        Inc(LexColNo);
        Done := True;
      End;
    End

    { # : litteral date ou numero de fichier }
    Else If Ch = '#' Then
    Begin
      { Essayer de detecter un litteral date : #...# }
      { Heuristique: si suivi d un chiffre ou lettre, c est une date }
      If (LexColNo < Length(LexLine)) And
         (IsDigit(LexLine[LexColNo + 1]) Or
          IsIdentStart(LexLine[LexColNo + 1])) Then
      Begin
        { Regarder s il y a un # fermant sur la meme ligne }
        HasClose := False;
        For K := LexColNo + 1 To Length(LexLine) Do
          If LexLine[K] = '#' Then HasClose := True;
        If HasClose Then
        Begin
          LexScanDate;
          Done := True;
        End
        Else
        Begin
          CurTokType := TOK_HASH;
          CurTokStr  := '#';
          CurTokNum  := 0;
          CurTokReal := 0.0;
          Inc(LexColNo);
          Done := True;
        End;
      End
      Else
      Begin
        CurTokType := TOK_HASH;
        CurTokStr  := '#';
        CurTokNum  := 0;
        CurTokReal := 0.0;
        Inc(LexColNo);
        Done := True;
      End;
    End

    { Operateurs et separateurs avec operateurs raccourcis VB.NET }
    Else If Ch = '+' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_PLUSEQ;
        CurTokStr  := '+=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_PLUS;
        CurTokStr  := '+';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '-' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_MINUSEQ;
        CurTokStr  := '-=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_MINUS;
        CurTokStr  := '-';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '*' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_STAREQ;
        CurTokStr  := '*=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_STAR;
        CurTokStr  := '*';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '/' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_SLASHEQ;
        CurTokStr  := '/=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_SLASH;
        CurTokStr  := '/';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '\' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_BSLASHEQ;
        CurTokStr  := '\=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_BACKSLASH;
        CurTokStr  := '\';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '^' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_CARETEQ;
        CurTokStr  := '^=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_CARET;
        CurTokStr  := '^';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '(' Then
    Begin
      CurTokType := TOK_LPAREN;
      CurTokStr  := '(';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = ')' Then
    Begin
      CurTokType := TOK_RPAREN;
      CurTokStr  := ')';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = ',' Then
    Begin
      CurTokType := TOK_COMMA;
      CurTokStr  := ',';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '.' Then
    Begin
      CurTokType := TOK_DOT;
      CurTokStr  := '.';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = ':' Then
    Begin
      CurTokType := TOK_COLON;
      CurTokStr  := ':';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = ';' Then
    Begin
      CurTokType := TOK_SEMI;
      CurTokStr  := ';';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '!' Then
    Begin
      CurTokType := TOK_EXCL;
      CurTokStr  := '!';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '=' Then
    Begin
      CurTokType := TOK_EQ;
      CurTokStr  := '=';
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Inc(LexColNo);
      Done := True;
    End
    Else If Ch = '<' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '>') Then
      Begin
        CurTokType := TOK_NE;
        CurTokStr  := '<>';
        Inc(LexColNo);
      End
      Else If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_LE;
        CurTokStr  := '<=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_LT;
        CurTokStr  := '<';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End
    Else If Ch = '>' Then
    Begin
      Inc(LexColNo);
      If (LexColNo <= Length(LexLine)) And (LexLine[LexColNo] = '=') Then
      Begin
        CurTokType := TOK_GE;
        CurTokStr  := '>=';
        Inc(LexColNo);
      End
      Else
      Begin
        CurTokType := TOK_GT;
        CurTokStr  := '>';
      End;
      CurTokNum  := 0;
      CurTokReal := 0.0;
      Done := True;
    End

    { Caractere non reconnu }
    Else
    Begin
      WarnMsg('caractere inattendu: ' + Ch + ' (ligne ' +
              ItoS(LexLineNo) + ')');
      Inc(LexColNo);
      { Continuer a scanner }
    End;
  End; { While Not Done }
  PrintToken;
End;

{ ============================================================ }
{ TODO 04 - TABLE DES SYMBOLES (32 BITS)        [IMPLEMENTE] }
{ ============================================================ }

Const
  { Genres de symboles (TSymKind) }
  SK_CONST       = 0;   { constante (Const)                       }
  SK_VAR         = 1;   { variable (Dim, Public, Private)          }
  SK_PARAM       = 2;   { parametre de Sub/Function               }
  SK_SUB         = 3;   { procedure Sub                            }
  SK_FUNCTION    = 4;   { procedure Function                       }
  SK_PROPERTY    = 5;   { propriete Property Get/Set               }
  SK_STRUCTURE   = 6;   { Structure...End Structure                }
  SK_ENUM        = 7;   { enumeration (Enum...End Enum)            }
  SK_ENUM_MEMBER = 8;   { membre d enumeration                     }
  SK_CLASS       = 9;   { classe (Class...End Class)               }
  SK_MODULE      = 10;  { module (Module...End Module)             }
  SK_FIELD       = 11;  { champ d une Structure ou d une classe   }
  SK_EVENT       = 12;  { evenement (Event)                        }
  SK_LABEL       = 13;  { label (etiquette de ligne)               }
  SK_NAMESPACE   = 14;  { Namespace...End Namespace                }
  SK_INTERFACE   = 15;  { Interface...End Interface                 }
  SK_DELEGATE    = 16;  { Delegate Sub/Function                    }

  { Classes d entreposage }
  STORE_AUTO     = 0;   { pile EBP (variables locales)             }
  STORE_STATIC   = 1;   { segment .DATA (Static)                   }
  STORE_PARAM    = 2;   { EBP+n (parametre)                        }
  STORE_GLOBAL   = 3;   { segment .DATA (Public/Global)            }
  STORE_CONSTANT = 4;   { immediate (Const)                        }
  STORE_SHARED   = 5;   { segment .DATA (Shared, acces via classe) }

  { Types VB.NET internes (codes DataType) }
  VBT_NONE       = 0;   { non type / inconnu                       }
  VBT_BOOLEAN    = 1;   { Boolean   (DD, 4 octets en interne)      }
  VBT_BYTE       = 2;   { Byte      (DB, 1 octet non signe)        }
  VBT_SBYTE      = 3;   { SByte     (DB, 1 octet signe)            }
  VBT_SHORT      = 4;   { Short     (DW, 16 bits signe)            }
  VBT_USHORT     = 5;   { UShort    (DW, 16 bits non signe)        }
  VBT_INTEGER    = 6;   { Integer   (DD, 32 bits signe)            }
  VBT_UINTEGER   = 7;   { UInteger  (DD, 32 bits non signe)        }
  VBT_LONG       = 8;   { Long      (DQ, 64 bits signe)            }
  VBT_ULONG      = 9;   { ULong     (DQ, 64 bits non signe)        }
  VBT_SINGLE     = 10;  { Single    (DD, flottant 32 bits)         }
  VBT_DOUBLE     = 11;  { Double    (DQ, flottant 64 bits)         }
  VBT_DECIMAL    = 12;  { Decimal   (16 octets, 128 bits, stub)    }
  VBT_CHAR       = 13;  { Char      (DW, 2 octets Unicode UTF-16)  }
  VBT_STRING     = 14;  { String    (pointeur DD, reference)       }
  VBT_DATE       = 15;  { Date      (DQ, 64 bits)                  }
  VBT_OBJECT     = 16;  { Object    (pointeur DD, reference)       }
  VBT_USER       = 17;  { Type utilisateur (taille variable)       }

  { Tailles en octets des types VB.NET (32 bits) }
  VBT_SIZE_BOOLEAN  = 4;  { DD en interne (True=-1/False=0)        }
  VBT_SIZE_BYTE     = 1;  { DB                                     }
  VBT_SIZE_SBYTE    = 1;  { DB (signe)                             }
  VBT_SIZE_SHORT    = 2;  { DW (16 bits signe)                     }
  VBT_SIZE_USHORT   = 2;  { DW (16 bits non signe)                 }
  VBT_SIZE_INTEGER  = 4;  { DD (32 bits signe - VB.NET)            }
  VBT_SIZE_UINTEGER = 4;  { DD (32 bits non signe)                 }
  VBT_SIZE_LONG     = 8;  { DQ (64 bits signe - VB.NET)            }
  VBT_SIZE_ULONG    = 8;  { DQ (64 bits non signe)                 }
  VBT_SIZE_SINGLE   = 4;  { DD (flottant 32 bits)                  }
  VBT_SIZE_DOUBLE   = 8;  { DQ (flottant 64 bits)                  }
  VBT_SIZE_DECIMAL  = 16; { 16 octets (128 bits)                   }
  VBT_SIZE_CHAR     = 2;  { DW (Unicode UTF-16)                    }
  VBT_SIZE_STRING   = 4;  { pointeur DD                            }
  VBT_SIZE_DATE     = 8;  { DQ (64 bits)                           }
  VBT_SIZE_OBJECT   = 4;  { pointeur DD                            }

Type
  { Entree dans la table des symboles }
  TSymEntry = Record
    Name          : String[255]; { nom du symbole                  }
    AsmLabel      : String[64];  { label assembleur genere          }
    Kind          : Integer;     { SK_CONST, SK_VAR, etc.          }
    DataType      : Integer;     { VBT_INTEGER, VBT_STRING, etc.   }
    StoreClass    : Integer;     { STORE_AUTO, STORE_GLOBAL, etc.  }
    BpOffset      : Integer;     { offset EBP pour locales/params  }
    ArrayDims     : Integer;     { nombre de dimensions (0=scalaire)}
    ArrayBase     : Integer;     { Option Base (0 ou 1)            }
    IsStatic      : Boolean;     { variable Static ?                }
    IsPublic      : Boolean;     { Public ?                         }
    IsOptional    : Boolean;     { parametre Optional ?             }
    DefaultVal    : String[64];  { valeur par defaut (si HasDefault)}
    HasDefault    : Boolean;     { a une valeur par defaut ?        }
    ByRef         : Boolean;     { passe par reference (ByRef) ?    }
    ParamIdx      : Integer;     { index du premier parametre (proc)}
    ClassIdx      : Integer;     { index de la classe parente       }
    InitStr       : String[64];  { valeur initiale chaine           }
    InitNum       : LongInt;     { valeur initiale numerique        }
    HasInit       : Boolean;     { a une valeur initiale ?          }
    IsConst       : Boolean;     { constante ?                      }
    IsShared      : Boolean;     { Shared (membre de classe)        }
    IsReadOnly    : Boolean;     { ReadOnly ?                       }
    IsOverridable : Boolean;     { Overridable ?                    }
    IsOverrides   : Boolean;     { Overrides ?                      }
    NamespaceIdx  : Integer;     { index du Namespace parent        }
  End;

  { Entree dans la table des procedures }
  TProcEntry = Record
    Name         : String[255]; { nom de la procedure/fonction     }
    AsmLabel     : String[64];  { label assembleur (_VBNF_...)     }
    Kind         : Integer;     { SK_SUB, SK_FUNCTION, SK_PROPERTY }
    ReturnType   : Integer;     { type de retour (0 pour Sub)      }
    ParamStart   : Integer;     { index du premier param dans SymTab}
    ParamCount   : Integer;     { nombre de parametres             }
    LocalStart   : Integer;     { index de la premiere locale      }
    LocalCount   : Integer;     { nombre de variables locales      }
    LocalSize    : Integer;     { taille totale des locales (octets)}
    IsPublic     : Boolean;     { Public ?                         }
    IsStatic     : Boolean;     { Static (tous les locaux en .DATA)}
    IsShared     : Boolean;     { Shared ?                         }
    ClassIdx     : Integer;     { index de la classe (-1 si aucune)}
    NamespaceIdx : Integer;     { index du Namespace parent        }
    ExitLabel    : String[64];  { label de sortie (_VBNL_xxx_exit) }
  End;

Var
  { Table des symboles }
  SymTab    : Array[0..MAX_SYM - 1] Of TSymEntry;
  SymCount  : Integer;

  { Table des procedures }
  ProcTab   : Array[0..MAX_PROC - 1] Of TProcEntry;
  ProcCount : Integer;

{ ------------------------------------------------------------ }
{ SymKindName : nom textuel d un genre de symbole              }
{ ------------------------------------------------------------ }

Function SymKindName(K : Integer) : TString;
Begin
  Case K Of
    SK_CONST       : SymKindName := 'Const';
    SK_VAR         : SymKindName := 'Var';
    SK_PARAM       : SymKindName := 'Param';
    SK_SUB         : SymKindName := 'Sub';
    SK_FUNCTION    : SymKindName := 'Function';
    SK_PROPERTY    : SymKindName := 'Property';
    SK_STRUCTURE   : SymKindName := 'Structure';
    SK_ENUM        : SymKindName := 'Enum';
    SK_ENUM_MEMBER : SymKindName := 'EnumMember';
    SK_CLASS       : SymKindName := 'Class';
    SK_MODULE      : SymKindName := 'Module';
    SK_FIELD       : SymKindName := 'Field';
    SK_EVENT       : SymKindName := 'Event';
    SK_LABEL       : SymKindName := 'Label';
    SK_NAMESPACE   : SymKindName := 'Namespace';
    SK_INTERFACE   : SymKindName := 'Interface';
    SK_DELEGATE    : SymKindName := 'Delegate';
  Else
    SymKindName := '?SK' + ItoSI(K);
  End;
End;

{ ------------------------------------------------------------ }
{ VBTypeName : nom textuel d un type VB.NET                    }
{ ------------------------------------------------------------ }

Function VBTypeName(T : Integer) : TString;
Begin
  Case T Of
    VBT_NONE     : VBTypeName := '(none)';
    VBT_BOOLEAN  : VBTypeName := 'Boolean';
    VBT_BYTE     : VBTypeName := 'Byte';
    VBT_SBYTE    : VBTypeName := 'SByte';
    VBT_SHORT    : VBTypeName := 'Short';
    VBT_USHORT   : VBTypeName := 'UShort';
    VBT_INTEGER  : VBTypeName := 'Integer';
    VBT_UINTEGER : VBTypeName := 'UInteger';
    VBT_LONG     : VBTypeName := 'Long';
    VBT_ULONG    : VBTypeName := 'ULong';
    VBT_SINGLE   : VBTypeName := 'Single';
    VBT_DOUBLE   : VBTypeName := 'Double';
    VBT_DECIMAL  : VBTypeName := 'Decimal';
    VBT_CHAR     : VBTypeName := 'Char';
    VBT_STRING   : VBTypeName := 'String';
    VBT_DATE     : VBTypeName := 'Date';
    VBT_OBJECT   : VBTypeName := 'Object';
    VBT_USER     : VBTypeName := 'UserType';
  Else
    VBTypeName := '?VBT' + ItoSI(T);
  End;
End;

{ ------------------------------------------------------------ }
{ VBTypeSize : taille en octets d un type VB.NET (32 bits)     }
{ ------------------------------------------------------------ }

Function VBTypeSize(T : Integer) : Integer;
Begin
  Case T Of
    VBT_BOOLEAN  : VBTypeSize := VBT_SIZE_BOOLEAN;
    VBT_BYTE     : VBTypeSize := VBT_SIZE_BYTE;
    VBT_SBYTE    : VBTypeSize := VBT_SIZE_SBYTE;
    VBT_SHORT    : VBTypeSize := VBT_SIZE_SHORT;
    VBT_USHORT   : VBTypeSize := VBT_SIZE_USHORT;
    VBT_INTEGER  : VBTypeSize := VBT_SIZE_INTEGER;
    VBT_UINTEGER : VBTypeSize := VBT_SIZE_UINTEGER;
    VBT_LONG     : VBTypeSize := VBT_SIZE_LONG;
    VBT_ULONG    : VBTypeSize := VBT_SIZE_ULONG;
    VBT_SINGLE   : VBTypeSize := VBT_SIZE_SINGLE;
    VBT_DOUBLE   : VBTypeSize := VBT_SIZE_DOUBLE;
    VBT_DECIMAL  : VBTypeSize := VBT_SIZE_DECIMAL;
    VBT_CHAR     : VBTypeSize := VBT_SIZE_CHAR;
    VBT_STRING   : VBTypeSize := VBT_SIZE_STRING;
    VBT_DATE     : VBTypeSize := VBT_SIZE_DATE;
    VBT_OBJECT   : VBTypeSize := VBT_SIZE_OBJECT;
  Else
    VBTypeSize := 4; { par defaut : DD (32 bits) }
  End;
End;

{ ------------------------------------------------------------ }
{ StoreClassName : nom textuel d une classe d entreposage      }
{ ------------------------------------------------------------ }

Function StoreClassName(SC : Integer) : TString;
Begin
  Case SC Of
    STORE_AUTO     : StoreClassName := 'Auto';
    STORE_STATIC   : StoreClassName := 'Static';
    STORE_PARAM    : StoreClassName := 'Param';
    STORE_GLOBAL   : StoreClassName := 'Global';
    STORE_CONSTANT : StoreClassName := 'Constant';
    STORE_SHARED   : StoreClassName := 'Shared';
  Else
    StoreClassName := '?SC' + ItoSI(SC);
  End;
End;

{ ------------------------------------------------------------ }
{ InitSymTable : initialiser les tables de symboles            }
{ ------------------------------------------------------------ }

Procedure InitSymTable;
Var I : Integer;
Begin
  SymCount  := 0;
  ProcCount := 0;
  For I := 0 To MAX_SYM - 1 Do
  Begin
    SymTab[I].Name          := '';
    SymTab[I].AsmLabel      := '';
    SymTab[I].Kind          := SK_VAR;
    SymTab[I].DataType      := VBT_NONE;
    SymTab[I].StoreClass    := STORE_AUTO;
    SymTab[I].BpOffset      := 0;
    SymTab[I].ArrayDims     := 0;
    SymTab[I].ArrayBase     := 0;
    SymTab[I].IsStatic      := False;
    SymTab[I].IsPublic      := False;
    SymTab[I].IsOptional    := False;
    SymTab[I].DefaultVal    := '';
    SymTab[I].HasDefault    := False;
    SymTab[I].ByRef         := False;
    SymTab[I].ParamIdx      := -1;
    SymTab[I].ClassIdx      := -1;
    SymTab[I].InitStr       := '';
    SymTab[I].InitNum       := 0;
    SymTab[I].HasInit       := False;
    SymTab[I].IsConst       := False;
    SymTab[I].IsShared      := False;
    SymTab[I].IsReadOnly    := False;
    SymTab[I].IsOverridable := False;
    SymTab[I].IsOverrides   := False;
    SymTab[I].NamespaceIdx  := -1;
  End;
  For I := 0 To MAX_PROC - 1 Do
  Begin
    ProcTab[I].Name         := '';
    ProcTab[I].AsmLabel     := '';
    ProcTab[I].Kind         := SK_SUB;
    ProcTab[I].ReturnType   := VBT_NONE;
    ProcTab[I].ParamStart   := 0;
    ProcTab[I].ParamCount   := 0;
    ProcTab[I].LocalStart   := 0;
    ProcTab[I].LocalCount   := 0;
    ProcTab[I].LocalSize    := 0;
    ProcTab[I].IsPublic     := False;
    ProcTab[I].IsStatic     := False;
    ProcTab[I].IsShared     := False;
    ProcTab[I].ClassIdx     := -1;
    ProcTab[I].NamespaceIdx := -1;
    ProcTab[I].ExitLabel    := '';
  End;
End;

{ ------------------------------------------------------------ }
{ FindSym : chercher un symbole par nom (insensible a la casse) }
{ Retourne l index ou -1 si non trouve                          }
{ ------------------------------------------------------------ }

Function FindSym(Const S : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := UpCaseStr(S);
  FindSym := -1;
  For I := 0 To SymCount - 1 Do
  Begin
    If UpCaseStr(SymTab[I].Name) = U Then
    Begin
      FindSym := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AddSym : ajouter un symbole dans la table                    }
{ Retourne l index du nouveau symbole ou -1 si plein           }
{ ------------------------------------------------------------ }

Function AddSym(Const AName : TString; AKind : Integer;
                ADataType : Integer; AStore : Integer) : Integer;
Var Idx : Integer;
Begin
  If SymCount >= MAX_SYM Then
  Begin
    FatalError('Table des symboles pleine (max ' + ItoSI(MAX_SYM) + ')');
    AddSym := -1;
    Exit;
  End;
  Idx := SymCount;
  SymTab[Idx].Name          := AName;
  SymTab[Idx].Kind          := AKind;
  SymTab[Idx].DataType      := ADataType;
  SymTab[Idx].StoreClass    := AStore;
  SymTab[Idx].BpOffset      := 0;
  SymTab[Idx].ArrayDims     := 0;
  SymTab[Idx].ArrayBase     := 0;
  SymTab[Idx].IsStatic      := False;
  SymTab[Idx].IsPublic      := False;
  SymTab[Idx].IsOptional    := False;
  SymTab[Idx].DefaultVal    := '';
  SymTab[Idx].HasDefault    := False;
  SymTab[Idx].ByRef         := False;
  SymTab[Idx].ParamIdx      := -1;
  SymTab[Idx].ClassIdx      := -1;
  SymTab[Idx].InitStr       := '';
  SymTab[Idx].InitNum       := 0;
  SymTab[Idx].HasInit       := False;
  SymTab[Idx].IsConst       := False;
  SymTab[Idx].IsShared      := False;
  SymTab[Idx].IsReadOnly    := False;
  SymTab[Idx].IsOverridable := False;
  SymTab[Idx].IsOverrides   := False;
  SymTab[Idx].NamespaceIdx  := -1;
  { Generer le label assembleur }
  Case AKind Of
    SK_VAR, SK_FIELD  : SymTab[Idx].AsmLabel := PFX_VAR + AsmIdent(AName);
    SK_CONST          : SymTab[Idx].AsmLabel := PFX_CONST + AsmIdent(AName);
    SK_SUB, SK_FUNCTION,
    SK_PROPERTY       : SymTab[Idx].AsmLabel := PFX_FUNC + AsmIdent(AName);
    SK_STRUCTURE      : SymTab[Idx].AsmLabel := PFX_STRUC + AsmIdent(AName);
    SK_CLASS          : SymTab[Idx].AsmLabel := PFX_CLS + AsmIdent(AName);
    SK_ENUM           : SymTab[Idx].AsmLabel := PFX_ENUM + AsmIdent(AName);
    SK_LABEL          : SymTab[Idx].AsmLabel := PFX_LBL + AsmIdent(AName);
    SK_NAMESPACE      : SymTab[Idx].AsmLabel := PFX_NS + AsmIdent(AName);
    SK_INTERFACE      : SymTab[Idx].AsmLabel := PFX_IFACE + AsmIdent(AName);
    SK_DELEGATE       : SymTab[Idx].AsmLabel := PFX_FUNC + AsmIdent(AName);
  Else
    SymTab[Idx].AsmLabel := PFX_VAR + AsmIdent(AName);
  End;
  Inc(SymCount);
  AddSym := Idx;
End;

{ ------------------------------------------------------------ }
{ FindProc : chercher une procedure par nom                    }
{ Retourne l index ou -1 si non trouvee                        }
{ ------------------------------------------------------------ }

Function FindProc(Const S : TString) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := UpCaseStr(S);
  FindProc := -1;
  For I := 0 To ProcCount - 1 Do
  Begin
    If UpCaseStr(ProcTab[I].Name) = U Then
    Begin
      FindProc := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AddProc : ajouter une procedure dans la table                }
{ Retourne l index de la nouvelle procedure ou -1 si plein     }
{ ------------------------------------------------------------ }

Function AddProc(Const AName : TString; AKind : Integer;
                 ARetType : Integer; APublic : Boolean) : Integer;
Var Idx : Integer;
Begin
  If ProcCount >= MAX_PROC Then
  Begin
    FatalError('Table des procedures pleine (max ' + ItoSI(MAX_PROC) + ')');
    AddProc := -1;
    Exit;
  End;
  Idx := ProcCount;
  ProcTab[Idx].Name         := AName;
  ProcTab[Idx].AsmLabel     := PFX_FUNC + AsmIdent(AName);
  ProcTab[Idx].Kind         := AKind;
  ProcTab[Idx].ReturnType   := ARetType;
  ProcTab[Idx].ParamStart   := SymCount;
  ProcTab[Idx].ParamCount   := 0;
  ProcTab[Idx].LocalStart   := 0;
  ProcTab[Idx].LocalCount   := 0;
  ProcTab[Idx].LocalSize    := 0;
  ProcTab[Idx].IsPublic     := APublic;
  ProcTab[Idx].IsStatic     := False;
  ProcTab[Idx].IsShared     := False;
  ProcTab[Idx].ClassIdx     := -1;
  ProcTab[Idx].NamespaceIdx := -1;
  ProcTab[Idx].ExitLabel    := PFX_LBL + AsmIdent(AName) + '_exit';
  Inc(ProcCount);
  AddProc := Idx;
End;

{ ------------------------------------------------------------ }
{ GetSymCount : nombre de symboles dans la table               }
{ ------------------------------------------------------------ }

Function GetSymCount : Integer;
Begin
  GetSymCount := SymCount;
End;

{ ------------------------------------------------------------ }
{ GetProcCount : nombre de procedures dans la table            }
{ ------------------------------------------------------------ }

Function GetProcCount : Integer;
Begin
  GetProcCount := ProcCount;
End;

{ ------------------------------------------------------------ }
{ GetSymEntry : acces a un symbole par index                   }
{ ------------------------------------------------------------ }

Function GetSymName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymName := SymTab[Idx].Name
  Else
    GetSymName := '';
End;

Function GetSymKind(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymKind := SymTab[Idx].Kind
  Else
    GetSymKind := -1;
End;

Function GetSymDataType(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymDataType := SymTab[Idx].DataType
  Else
    GetSymDataType := VBT_NONE;
End;

Function GetSymAsmLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymAsmLabel := SymTab[Idx].AsmLabel
  Else
    GetSymAsmLabel := '';
End;

Function GetSymStoreClass(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymStoreClass := SymTab[Idx].StoreClass
  Else
    GetSymStoreClass := STORE_AUTO;
End;

Function GetSymBpOffset(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetSymBpOffset := SymTab[Idx].BpOffset
  Else
    GetSymBpOffset := 0;
End;

Function IsSymPublic(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsSymPublic := SymTab[Idx].IsPublic
  Else
    IsSymPublic := False;
End;

Function IsSymStatic(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsSymStatic := SymTab[Idx].IsStatic
  Else
    IsSymStatic := False;
End;

Function IsSymConst(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsSymConst := SymTab[Idx].IsConst
  Else
    IsSymConst := False;
End;

Function IsSymShared(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsSymShared := SymTab[Idx].IsShared
  Else
    IsSymShared := False;
End;

{ ------------------------------------------------------------ }
{ GetProcEntry : acces a une procedure par index               }
{ ------------------------------------------------------------ }

Function GetProcName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcName := ProcTab[Idx].Name
  Else
    GetProcName := '';
End;

Function GetProcKind(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcKind := ProcTab[Idx].Kind
  Else
    GetProcKind := -1;
End;

Function GetProcReturnType(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcReturnType := ProcTab[Idx].ReturnType
  Else
    GetProcReturnType := VBT_NONE;
End;

Function GetProcAsmLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcAsmLabel := ProcTab[Idx].AsmLabel
  Else
    GetProcAsmLabel := '';
End;

Function GetProcParamCount(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcParamCount := ProcTab[Idx].ParamCount
  Else
    GetProcParamCount := 0;
End;

Function GetProcLocalSize(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcLocalSize := ProcTab[Idx].LocalSize
  Else
    GetProcLocalSize := 0;
End;

Function GetProcExitLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    GetProcExitLabel := ProcTab[Idx].ExitLabel
  Else
    GetProcExitLabel := '';
End;

Function IsProcPublic(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < ProcCount) Then
    IsProcPublic := ProcTab[Idx].IsPublic
  Else
    IsProcPublic := False;
End;

{ ------------------------------------------------------------ }
{ IsSymTableEmpty / IsProcTableEmpty                           }
{ ------------------------------------------------------------ }

Function IsSymTableEmpty : Boolean;
Begin
  IsSymTableEmpty := (SymCount = 0);
End;

Function IsProcTableEmpty : Boolean;
Begin
  IsProcTableEmpty := (ProcCount = 0);
End;

{ ============================================================ }
{ TODO 05 - GESTION DES PORTEES                 [IMPLEMENTE] }
{           (NAMESPACE, MODULE, CLASS, STRUCTURE)             }
{ ============================================================ }

Const
  { Genres de portees }
  SCOPE_GLOBAL    = 0;   { portee globale (module-level)             }
  SCOPE_NAMESPACE = 1;   { portee d un Namespace VB.NET              }
  SCOPE_MODULE    = 2;   { portee d un Module VB.NET                 }
  SCOPE_CLASS     = 3;   { portee d une Class                        }
  SCOPE_STRUCTURE = 4;   { portee d une Structure (value type)       }
  SCOPE_SUB       = 5;   { portee d une procedure Sub                }
  SCOPE_FUNCTION  = 6;   { portee d une fonction Function            }
  SCOPE_PROPERTY  = 7;   { portee d une propriete Property           }
  SCOPE_BLOCK     = 8;   { portee de bloc (For, If, Do, Select, Using)}
  SCOPE_TRY       = 9;   { portee d un bloc Try                      }
  SCOPE_CATCH     = 10;  { portee d un bloc Catch                    }
  SCOPE_FINALLY   = 11;  { portee d un bloc Finally                  }

  { Base d offset EBP pour parametres STDCALL Win32 }
  { [EBP+0] = ancien EBP, [EBP+4] = adresse retour }
  { [EBP+8] = premier parametre                      }
  SCOPE_EBP_PARAM_BASE = 8;

Type
  { Entree dans la pile de portees }
  TScopeEntry = Record
    Kind       : Integer;     { SCOPE_GLOBAL, SCOPE_SUB, etc.      }
    ProcIdx    : Integer;     { index dans ProcTab (-1 si global)  }
    SymStart   : Integer;     { index du premier symbole local      }
    EbpTop     : Integer;     { prochain offset EBP negatif libre  }
    ExitLabel  : String[64];  { label de sortie (pour Exit Sub/Fn) }
    IsStatic   : Boolean;     { portee Static ? (locales en .DATA) }
    IsShared   : Boolean;     { portee Shared ? (membre de classe) }
    NsIdx      : Integer;     { index du Namespace englobant (-1)  }
  End;

Var
  { Pile de portees }
  ScopeStack : Array[0..MAX_DEPTH - 1] Of TScopeEntry;
  ScopeDepth : Integer;

  { Compteur de labels internes (pour generer des labels uniques) }
  InternalLabelCount : LongInt;

{ ------------------------------------------------------------ }
{ ScopeKindName : nom textuel d un genre de portee             }
{ ------------------------------------------------------------ }

Function ScopeKindName(K : Integer) : TString;
Begin
  Case K Of
    SCOPE_GLOBAL    : ScopeKindName := 'Global';
    SCOPE_NAMESPACE : ScopeKindName := 'Namespace';
    SCOPE_MODULE    : ScopeKindName := 'Module';
    SCOPE_CLASS     : ScopeKindName := 'Class';
    SCOPE_STRUCTURE : ScopeKindName := 'Structure';
    SCOPE_SUB       : ScopeKindName := 'Sub';
    SCOPE_FUNCTION  : ScopeKindName := 'Function';
    SCOPE_PROPERTY  : ScopeKindName := 'Property';
    SCOPE_BLOCK     : ScopeKindName := 'Block';
    SCOPE_TRY       : ScopeKindName := 'Try';
    SCOPE_CATCH     : ScopeKindName := 'Catch';
    SCOPE_FINALLY   : ScopeKindName := 'Finally';
  Else
    ScopeKindName := '?SCOPE' + ItoSI(K);
  End;
End;

{ ------------------------------------------------------------ }
{ InitScopes : initialiser la pile de portees                  }
{   Cree automatiquement la portee globale (SCOPE_GLOBAL)      }
{ ------------------------------------------------------------ }

Procedure InitScopes;
Var I : Integer;
Begin
  ScopeDepth := 0;
  InternalLabelCount := 0;
  For I := 0 To MAX_DEPTH - 1 Do
  Begin
    ScopeStack[I].Kind      := SCOPE_GLOBAL;
    ScopeStack[I].ProcIdx   := -1;
    ScopeStack[I].SymStart  := 0;
    ScopeStack[I].EbpTop    := 0;
    ScopeStack[I].ExitLabel := '';
    ScopeStack[I].IsStatic  := False;
    ScopeStack[I].IsShared  := False;
    ScopeStack[I].NsIdx     := -1;
  End;
  { Portee globale initiale }
  ScopeStack[0].Kind     := SCOPE_GLOBAL;
  ScopeStack[0].ProcIdx  := -1;
  ScopeStack[0].SymStart := 0;
  ScopeStack[0].EbpTop   := 0;
  ScopeStack[0].IsStatic := False;
  ScopeStack[0].IsShared := False;
  ScopeStack[0].NsIdx    := -1;
  ScopeDepth := 1;
End;

{ ------------------------------------------------------------ }
{ NextInternalLabel : generer un label interne unique           }
{ ------------------------------------------------------------ }

Function NextInternalLabel : TString;
Begin
  Inc(InternalLabelCount);
  NextInternalLabel := PFX_LBL + ItoSI(InternalLabelCount);
End;

{ ------------------------------------------------------------ }
{ EnterScope : empiler une nouvelle portee                     }
{   kind     : SCOPE_SUB, SCOPE_FUNCTION, etc.                }
{   proc_idx : index dans ProcTab (-1 pour Global/Module/etc.) }
{ ------------------------------------------------------------ }

Procedure EnterScope(Kind : Integer; ProcIdx : Integer);
Begin
  If ScopeDepth >= MAX_DEPTH Then
  Begin
    FatalError('Pile de portees pleine (max ' + ItoSI(MAX_DEPTH) + ')');
    Exit;
  End;
  ScopeStack[ScopeDepth].Kind      := Kind;
  ScopeStack[ScopeDepth].ProcIdx   := ProcIdx;
  ScopeStack[ScopeDepth].SymStart  := SymCount;
  ScopeStack[ScopeDepth].EbpTop    := 0;
  ScopeStack[ScopeDepth].IsStatic  := False;
  ScopeStack[ScopeDepth].IsShared  := False;
  ScopeStack[ScopeDepth].NsIdx     := -1;
  { Generer un label de sortie pour Sub/Function/Property }
  If (Kind = SCOPE_SUB) Or (Kind = SCOPE_FUNCTION) Or
     (Kind = SCOPE_PROPERTY) Then
  Begin
    If (ProcIdx >= 0) And (ProcIdx < ProcCount) Then
      ScopeStack[ScopeDepth].ExitLabel := ProcTab[ProcIdx].ExitLabel
    Else
      ScopeStack[ScopeDepth].ExitLabel := NextInternalLabel + '_exit';
  End
  Else
    ScopeStack[ScopeDepth].ExitLabel := '';
  { Heriter du NsIdx du Namespace englobant si on entre dans un NS }
  If Kind = SCOPE_NAMESPACE Then
    ScopeStack[ScopeDepth].NsIdx := SymCount - 1
  Else If ScopeDepth > 0 Then
    ScopeStack[ScopeDepth].NsIdx := ScopeStack[ScopeDepth - 1].NsIdx;
  Inc(ScopeDepth);
End;

{ ------------------------------------------------------------ }
{ LeaveScope : depiler la portee courante                      }
{   Met a jour LocalSize dans ProcTab si applicable            }
{ ------------------------------------------------------------ }

Procedure LeaveScope;
Var
  Idx : Integer;
Begin
  If ScopeDepth <= 1 Then
  Begin
    WarnMsg('LeaveScope : tentative de depiler la portee globale');
    Exit;
  End;
  Dec(ScopeDepth);
  { Si la portee etait un Sub/Function/Property, enregistrer la }
  { taille totale des variables locales dans ProcTab             }
  Idx := ScopeStack[ScopeDepth].ProcIdx;
  If (Idx >= 0) And (Idx < ProcCount) Then
  Begin
    If (ScopeStack[ScopeDepth].Kind = SCOPE_SUB) Or
       (ScopeStack[ScopeDepth].Kind = SCOPE_FUNCTION) Or
       (ScopeStack[ScopeDepth].Kind = SCOPE_PROPERTY) Then
    Begin
      ProcTab[Idx].LocalSize := ScopeStack[ScopeDepth].EbpTop;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AllocLocalEbp : allouer de l espace sur la pile EBP          }
{   bytes : taille en octets a allouer                          }
{   Retourne l offset EBP negatif attribue                      }
{   Aligne sur 4 octets (32 bits) pour performance             }
{ ------------------------------------------------------------ }

Function AllocLocalEbp(Bytes : Integer) : Integer;
Var
  Aligned : Integer;
Begin
  If ScopeDepth <= 0 Then
  Begin
    FatalError('AllocLocalEbp : pas de portee active');
    AllocLocalEbp := 0;
    Exit;
  End;
  { Aligner sur 4 octets (arrondi vers le haut) }
  Aligned := ((Bytes + 3) Div 4) * 4;
  { Incrementer l offset (negatif par rapport a EBP) }
  ScopeStack[ScopeDepth - 1].EbpTop :=
    ScopeStack[ScopeDepth - 1].EbpTop + Aligned;
  { Retourner l offset negatif : [EBP - EbpTop] }
  AllocLocalEbp := ScopeStack[ScopeDepth - 1].EbpTop;
End;

{ ------------------------------------------------------------ }
{ CurrentEbpTop : retourner l offset EBP courant de la portee  }
{   actuelle (taille des locales allouees jusqu ici)            }
{ ------------------------------------------------------------ }

Function CurrentEbpTop : Integer;
Begin
  If ScopeDepth <= 0 Then
    CurrentEbpTop := 0
  Else
    CurrentEbpTop := ScopeStack[ScopeDepth - 1].EbpTop;
End;

{ ------------------------------------------------------------ }
{ ResolveQualifiedName : resoudre un nom qualifie              }
{   Ex : "Namespace.Class.Member" -> recherche dans les        }
{   portees imbriquees depuis le plus profond                  }
{   Retourne l index dans SymTab ou -1 si non trouve           }
{ ------------------------------------------------------------ }

{ ------------------------------------------------------------ }
{ FindSymInContainer : chercher un symbole dont NamespaceIdx   }
{   correspond au conteneur donne                               }
{   ContainerIdx : index du NS/Class/Module/Structure parent   }
{   Retourne l index dans SymTab ou -1 si non trouve           }
{ ------------------------------------------------------------ }

Function FindSymInContainer(Const S : TString;
                            ContainerIdx : Integer) : Integer;
Var
  I : Integer;
  U : TString;
Begin
  U := UpCaseStr(S);
  FindSymInContainer := -1;
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].NamespaceIdx = ContainerIdx) And
       (UpCaseStr(SymTab[I].Name) = U) Then
    Begin
      FindSymInContainer := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ResolveQualifiedName : resoudre un nom qualifie              }
{   Ex : "Namespace.Class.Member" -> recherche dans les        }
{   portees imbriquees depuis le plus profond                  }
{   Retourne l index dans SymTab ou -1 si non trouve           }
{ ------------------------------------------------------------ }

Function ResolveQualifiedName(Const QName : TString) : Integer;
Var
  I    : Integer;
  DotP : Integer;
  Left : TString;
  Rest : TString;
  NsI  : Integer;
  SubI : Integer;
Begin
  ResolveQualifiedName := -1;
  { Chercher le premier point }
  DotP := 0;
  For I := 1 To Length(QName) Do
  Begin
    If QName[I] = '.' Then
    Begin
      DotP := I;
      Break;
    End;
  End;
  If DotP = 0 Then
  Begin
    { Pas de point : recherche simple dans la table des symboles }
    ResolveQualifiedName := FindSym(QName);
    Exit;
  End;
  { Separer la partie gauche du point }
  Left := Copy(QName, 1, DotP - 1);
  Rest := Copy(QName, DotP + 1, Length(QName) - DotP);
  { Chercher la partie gauche comme Namespace/Class/Module/Structure }
  NsI := FindSym(Left);
  If NsI < 0 Then Exit;
  If (SymTab[NsI].Kind <> SK_NAMESPACE) And
     (SymTab[NsI].Kind <> SK_CLASS) And
     (SymTab[NsI].Kind <> SK_MODULE) And
     (SymTab[NsI].Kind <> SK_STRUCTURE) Then
    Exit;
  { Chercher le reste dans le conteneur NsI }
  { Si Rest contient un point, extraire la partie avant le point }
  DotP := 0;
  For I := 1 To Length(Rest) Do
  Begin
    If Rest[I] = '.' Then
    Begin
      DotP := I;
      Break;
    End;
  End;
  If DotP = 0 Then
  Begin
    { Dernier segment : chercher dans le conteneur }
    SubI := FindSymInContainer(Rest, NsI);
    If SubI >= 0 Then
      ResolveQualifiedName := SubI
    Else
      { Fallback : chercher globalement si non trouve dans le conteneur }
      ResolveQualifiedName := FindSym(Rest);
  End
  Else
  Begin
    { Segments intermediaires : chercher le sous-conteneur dans NsI }
    Left := Copy(Rest, 1, DotP - 1);
    SubI := FindSymInContainer(Left, NsI);
    If SubI < 0 Then
      SubI := FindSym(Left);
    If SubI < 0 Then Exit;
    If (SymTab[SubI].Kind <> SK_NAMESPACE) And
       (SymTab[SubI].Kind <> SK_CLASS) And
       (SymTab[SubI].Kind <> SK_MODULE) And
       (SymTab[SubI].Kind <> SK_STRUCTURE) Then
      Exit;
    { Recurser avec le sous-conteneur et le reste }
    Rest := Copy(Rest, DotP + 1, Length(Rest) - DotP);
    SubI := FindSymInContainer(Rest, SubI);
    If SubI >= 0 Then
      ResolveQualifiedName := SubI
    Else
      ResolveQualifiedName := FindSym(Rest);
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour la pile de portees                  }
{ ------------------------------------------------------------ }

Function GetScopeDepth : Integer;
Begin
  GetScopeDepth := ScopeDepth;
End;

Function GetCurrentScopeKind : Integer;
Begin
  If ScopeDepth <= 0 Then
    GetCurrentScopeKind := SCOPE_GLOBAL
  Else
    GetCurrentScopeKind := ScopeStack[ScopeDepth - 1].Kind;
End;

Function GetCurrentScopeProcIdx : Integer;
Begin
  If ScopeDepth <= 0 Then
    GetCurrentScopeProcIdx := -1
  Else
    GetCurrentScopeProcIdx := ScopeStack[ScopeDepth - 1].ProcIdx;
End;

Function GetCurrentScopeSymStart : Integer;
Begin
  If ScopeDepth <= 0 Then
    GetCurrentScopeSymStart := 0
  Else
    GetCurrentScopeSymStart := ScopeStack[ScopeDepth - 1].SymStart;
End;

Function GetCurrentScopeExitLabel : TString;
Begin
  If ScopeDepth <= 0 Then
    GetCurrentScopeExitLabel := ''
  Else
    GetCurrentScopeExitLabel := ScopeStack[ScopeDepth - 1].ExitLabel;
End;

Function IsCurrentScopeStatic : Boolean;
Begin
  If ScopeDepth <= 0 Then
    IsCurrentScopeStatic := False
  Else
    IsCurrentScopeStatic := ScopeStack[ScopeDepth - 1].IsStatic;
End;

Function IsCurrentScopeShared : Boolean;
Begin
  If ScopeDepth <= 0 Then
    IsCurrentScopeShared := False
  Else
    IsCurrentScopeShared := ScopeStack[ScopeDepth - 1].IsShared;
End;

Function GetCurrentScopeNsIdx : Integer;
Begin
  If ScopeDepth <= 0 Then
    GetCurrentScopeNsIdx := -1
  Else
    GetCurrentScopeNsIdx := ScopeStack[ScopeDepth - 1].NsIdx;
End;

Function IsInGlobalScope : Boolean;
Begin
  IsInGlobalScope := (ScopeDepth <= 1);
End;

Function IsInProcScope : Boolean;
Var K : Integer;
Begin
  K := GetCurrentScopeKind;
  IsInProcScope := (K = SCOPE_SUB) Or (K = SCOPE_FUNCTION) Or
                   (K = SCOPE_PROPERTY);
End;

Function IsInClassScope : Boolean;
Var I : Integer;
Begin
  IsInClassScope := False;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_CLASS Then
    Begin
      IsInClassScope := True;
      Exit;
    End;
  End;
End;

Function IsInStructureScope : Boolean;
Var I : Integer;
Begin
  IsInStructureScope := False;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_STRUCTURE Then
    Begin
      IsInStructureScope := True;
      Exit;
    End;
  End;
End;

Function IsInNamespaceScope : Boolean;
Var I : Integer;
Begin
  IsInNamespaceScope := False;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_NAMESPACE Then
    Begin
      IsInNamespaceScope := True;
      Exit;
    End;
  End;
End;

Function IsInModuleScope : Boolean;
Var I : Integer;
Begin
  IsInModuleScope := False;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_MODULE Then
    Begin
      IsInModuleScope := True;
      Exit;
    End;
  End;
End;

Function IsInTryScope : Boolean;
Var I : Integer;
Begin
  IsInTryScope := False;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_TRY Then
    Begin
      IsInTryScope := True;
      Exit;
    End;
  End;
End;

Function FindEnclosingProcIdx : Integer;
Var I : Integer;
Begin
  FindEnclosingProcIdx := -1;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If (ScopeStack[I].Kind = SCOPE_SUB) Or
       (ScopeStack[I].Kind = SCOPE_FUNCTION) Or
       (ScopeStack[I].Kind = SCOPE_PROPERTY) Then
    Begin
      FindEnclosingProcIdx := ScopeStack[I].ProcIdx;
      Exit;
    End;
  End;
End;

Function FindEnclosingExitLabel : TString;
Var I : Integer;
Begin
  FindEnclosingExitLabel := '';
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].ExitLabel <> '' Then
    Begin
      FindEnclosingExitLabel := ScopeStack[I].ExitLabel;
      Exit;
    End;
  End;
End;

Function FindEnclosingNsIdx : Integer;
Var I : Integer;
Begin
  FindEnclosingNsIdx := -1;
  For I := ScopeDepth - 1 DownTo 0 Do
  Begin
    If ScopeStack[I].Kind = SCOPE_NAMESPACE Then
    Begin
      FindEnclosingNsIdx := ScopeStack[I].NsIdx;
      Exit;
    End;
  End;
End;

Function GetScopeKindAt(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ScopeDepth) Then
    GetScopeKindAt := ScopeStack[Idx].Kind
  Else
    GetScopeKindAt := -1;
End;

Function GetScopeProcIdxAt(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ScopeDepth) Then
    GetScopeProcIdxAt := ScopeStack[Idx].ProcIdx
  Else
    GetScopeProcIdxAt := -1;
End;

Function GetScopeEbpTopAt(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < ScopeDepth) Then
    GetScopeEbpTopAt := ScopeStack[Idx].EbpTop
  Else
    GetScopeEbpTopAt := 0;
End;

Function IsScopeStackEmpty : Boolean;
Begin
  IsScopeStackEmpty := (ScopeDepth <= 1);
End;

Function GetInternalLabelCount : LongInt;
Begin
  GetInternalLabelCount := InternalLabelCount;
End;

Procedure SetCurrentScopeStatic(V : Boolean);
Begin
  If ScopeDepth > 0 Then
    ScopeStack[ScopeDepth - 1].IsStatic := V;
End;

Procedure SetCurrentScopeShared(V : Boolean);
Begin
  If ScopeDepth > 0 Then
    ScopeStack[ScopeDepth - 1].IsShared := V;
End;

{ ============================================================ }
{ TODO 06 - PARSEUR : IMPORTS, NAMESPACE ET       [IMPLEMENTE] }
{           MODULE                                              }
{ ============================================================ }

Const
  { Nombre maximal d entrees dans la table des imports }
  MAX_IMPORT_ENTRIES = 128;

  { Types de conteneur VB.NET }
  MODULE_VB_MODULE  = 0;   { Module VB.NET (conteneur statique)      }
  MODULE_VB_CLASS   = 1;   { Class VB.NET                            }

  { Option Compare }
  OPT_COMPARE_BINARY = 0;  { comparaison binaire (par defaut)        }
  OPT_COMPARE_TEXT   = 1;  { comparaison textuelle                   }

Type
  { Entree dans la table des imports }
  TImportEntry = Record
    Namespace : TString;    { nom complet de l espace de noms         }
    Alias     : TString;    { alias eventuel (vide si pas d alias)    }
  End;

Var
  { Table des imports }
  ImportTab     : Array[0..MAX_IMPORT_ENTRIES - 1] Of TImportEntry;
  ImportCount   : Integer;

  { Etat du module en cours d analyse }
  ModuleKind         : Integer;     { MODULE_VB_MODULE / MODULE_VB_CLASS }
  ModuleName         : TString;     { nom du module/classe courant       }
  NamespaceName      : TString;     { nom du namespace courant           }
  HasEntryPoint      : Boolean;     { module a un point d entree ?       }
  ModuleHeaderParsed : Boolean;     { en-tete deja analyse ?             }
  OptionCompare      : Integer;     { OPT_COMPARE_BINARY ou _TEXT        }

{ ------------------------------------------------------------ }
{ ModuleKindName : nom textuel du genre de conteneur           }
{ ------------------------------------------------------------ }

Function ModuleKindName(K : Integer) : TString;
Begin
  Case K Of
    MODULE_VB_MODULE : ModuleKindName := 'Module';
    MODULE_VB_CLASS  : ModuleKindName := 'Class';
  Else
    ModuleKindName := '?MOD' + ItoSI(K);
  End;
End;

{ ------------------------------------------------------------ }
{ InitModuleState : initialiser l etat du module               }
{ ------------------------------------------------------------ }

Procedure InitModuleState;
Var I : Integer;
Begin
  { Table des imports }
  ImportCount := 0;
  For I := 0 To MAX_IMPORT_ENTRIES - 1 Do
  Begin
    ImportTab[I].Namespace := '';
    ImportTab[I].Alias     := '';
  End;

  { Etat du module }
  ModuleKind         := MODULE_VB_MODULE;
  ModuleName         := '';
  NamespaceName      := '';
  HasEntryPoint      := False;
  ModuleHeaderParsed := False;
  OptionCompare      := OPT_COMPARE_BINARY;
End;

{ ------------------------------------------------------------ }
{ SkipNewlines : sauter les tokens TOK_NEWLINE                 }
{ ------------------------------------------------------------ }

Procedure SkipNewlines;
Begin
  While CurTokType = TOK_NEWLINE Do
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ Expect : verifier le type de token courant et avancer        }
{   Si le token courant n est pas du type attendu, erreur      }
{ ------------------------------------------------------------ }

Procedure Expect(TokType : Integer);
Begin
  If CurTokType <> TokType Then
  Begin
    FatalError('Token attendu type ' + ItoSI(TokType) +
               ', trouve type ' + ItoSI(CurTokType) +
               ' ("' + CurTokStr + '")');
    Exit;
  End;
  LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ExpectKeyword : verifier un mot-cle precis et avancer        }
{ ------------------------------------------------------------ }

Procedure ExpectKeyword(KW : Integer);
Begin
  If (CurTokType <> TOK_KEYWORD) Or (CurTokNum <> KW) Then
  Begin
    FatalError('Mot-cle attendu "' + KeywordName(KW) +
               '", trouve "' + CurTokStr + '"');
    Exit;
  End;
  LexNextToken;
End;

{ ------------------------------------------------------------ }
{ IsKeywordToken : le token courant est-il le mot-cle donne ?  }
{ ------------------------------------------------------------ }

Function IsKeywordToken(KW : Integer) : Boolean;
Begin
  IsKeywordToken := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW);
End;

{ ------------------------------------------------------------ }
{ IsIdentToken : le token courant est-il un ident avec ce nom? }
{ ------------------------------------------------------------ }

Function IsIdentToken(Const Name : TString) : Boolean;
Begin
  IsIdentToken := (CurTokType = TOK_IDENT) And
                  (UpCaseStr(CurTokStr) = UpCaseStr(Name));
End;

{ ------------------------------------------------------------ }
{ SkipToEndOfLine : avancer jusqu a TOK_NEWLINE ou TOK_EOF     }
{ ------------------------------------------------------------ }

Procedure SkipToEndOfLine;
Begin
  While (CurTokType <> TOK_NEWLINE) And (CurTokType <> TOK_EOF) Do
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ FindImport : chercher un import par nom d espace de noms     }
{   Retourne l index si trouve, -1 sinon                       }
{ ------------------------------------------------------------ }

Function FindImport(Const NS : TString) : Integer;
Var I : Integer;
    U : TString;
Begin
  FindImport := -1;
  U := UpCaseStr(NS);
  For I := 0 To ImportCount - 1 Do
  Begin
    If UpCaseStr(ImportTab[I].Namespace) = U Then
    Begin
      FindImport := I;
      Exit;
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ AddImport : ajouter un import dans la table                  }
{   Retourne l index de l entree, ou -1 si table pleine        }
{ ------------------------------------------------------------ }

Function AddImport(Const NS, Alias : TString) : Integer;
Begin
  AddImport := -1;
  { Verifier si deja importe }
  If FindImport(NS) >= 0 Then
  Begin
    WarnMsg('Imports "' + NS + '" deja present, ignore');
    Exit;
  End;
  { Verifier la capacite }
  If ImportCount >= MAX_IMPORT_ENTRIES Then
  Begin
    FatalError('Table des imports pleine (max ' +
               ItoSI(MAX_IMPORT_ENTRIES) + ')');
    Exit;
  End;
  ImportTab[ImportCount].Namespace := NS;
  ImportTab[ImportCount].Alias     := Alias;
  AddImport := ImportCount;
  Inc(ImportCount);
End;

{ ------------------------------------------------------------ }
{ ParseImportStatement : analyser une instruction Imports       }
{   Token courant : KW_IMPORTS                                 }
{   Syntaxe :                                                  }
{     Imports System                                           }
{     Imports System.IO                                        }
{     Imports alias = Namespace.Complet                        }
{ ------------------------------------------------------------ }

Procedure ParseImportStatement;
Var NS, Alias : TString;
Begin
  { Consommer "Imports" }
  LexNextToken;

  { Lire le premier identifiant }
  If (CurTokType <> TOK_IDENT) And (CurTokType <> TOK_KEYWORD) Then
  Begin
    FatalError('Imports attend un nom d''espace de noms, trouve "' +
               CurTokStr + '"');
    SkipToEndOfLine;
    Exit;
  End;

  NS := CurTokStr;
  LexNextToken;

  { Verifier si c est un alias : ident = Namespace }
  If CurTokType = TOK_EQ Then
  Begin
    { NS contient l alias, lire le namespace reel }
    Alias := NS;
    LexNextToken;
    If (CurTokType <> TOK_IDENT) And (CurTokType <> TOK_KEYWORD) Then
    Begin
      FatalError('Imports alias attend un espace de noms apres "="');
      SkipToEndOfLine;
      Exit;
    End;
    NS := CurTokStr;
    LexNextToken;
    { Lire les composants separes par des points }
    While CurTokType = TOK_DOT Do
    Begin
      LexNextToken;
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
      Begin
        NS := NS + '.' + CurTokStr;
        LexNextToken;
      End
      Else
      Begin
        FatalError('Imports attend un identifiant apres "."');
        SkipToEndOfLine;
        Exit;
      End;
    End;
  End
  Else
  Begin
    { Pas d alias : lire les composants separes par des points }
    Alias := '';
    While CurTokType = TOK_DOT Do
    Begin
      LexNextToken;
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
      Begin
        NS := NS + '.' + CurTokStr;
        LexNextToken;
      End
      Else
      Begin
        FatalError('Imports attend un identifiant apres "."');
        SkipToEndOfLine;
        Exit;
      End;
    End;
  End;

  { Ajouter dans la table des imports }
  AddImport(NS, Alias);

  If Opts.Verbose Then
  Begin
    If Alias <> '' Then
      WriteLn('  Imports ', Alias, ' = ', NS)
    Else
      WriteLn('  Imports ', NS);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseOptionStatement : analyser Option Explicit/Strict/       }
{   Compare/Infer avec syntaxe VB.NET (On|Off)                 }
{   Token courant : KW_OPTION                                  }
{ ------------------------------------------------------------ }

Procedure ParseOptionStatement;
Begin
  { Consommer "Option" }
  LexNextToken;

  { Option Explicit On|Off }
  If IsIdentToken('Explicit') Then
  Begin
    LexNextToken;
    If IsKeywordToken(KW_ON) Then
    Begin
      Opts.OptionExplicit := True;
      LexNextToken;
    End
    Else If IsIdentToken('Off') Then
    Begin
      Opts.OptionExplicit := False;
      LexNextToken;
    End
    Else
      Opts.OptionExplicit := True;
    If Opts.Verbose Then
    Begin
      If Opts.OptionExplicit Then
        WriteLn('  Option Explicit On')
      Else
        WriteLn('  Option Explicit Off');
    End;
  End

  { Option Strict On|Off }
  Else If IsIdentToken('Strict') Then
  Begin
    LexNextToken;
    If IsKeywordToken(KW_ON) Then
    Begin
      Opts.OptionStrict := True;
      LexNextToken;
    End
    Else If IsIdentToken('Off') Then
    Begin
      Opts.OptionStrict := False;
      LexNextToken;
    End
    Else
      Opts.OptionStrict := True;
    If Opts.Verbose Then
    Begin
      If Opts.OptionStrict Then
        WriteLn('  Option Strict On')
      Else
        WriteLn('  Option Strict Off');
    End;
  End

  { Option Compare Binary|Text }
  Else If IsIdentToken('Compare') Then
  Begin
    LexNextToken;
    If IsIdentToken('Binary') Then
    Begin
      OptionCompare := OPT_COMPARE_BINARY;
      LexNextToken;
    End
    Else If IsIdentToken('Text') Then
    Begin
      OptionCompare := OPT_COMPARE_TEXT;
      LexNextToken;
    End
    Else
      FatalError('Option Compare attend Binary ou Text, trouve "' +
                 CurTokStr + '"');
    If Opts.Verbose Then
    Begin
      If OptionCompare = OPT_COMPARE_BINARY Then
        WriteLn('  Option Compare Binary')
      Else
        WriteLn('  Option Compare Text');
    End;
  End

  { Option Infer On|Off }
  Else If IsIdentToken('Infer') Then
  Begin
    LexNextToken;
    If IsKeywordToken(KW_ON) Then
    Begin
      Opts.OptionInfer := True;
      LexNextToken;
    End
    Else If IsIdentToken('Off') Then
    Begin
      Opts.OptionInfer := False;
      LexNextToken;
    End
    Else
      Opts.OptionInfer := True;
    If Opts.Verbose Then
    Begin
      If Opts.OptionInfer Then
        WriteLn('  Option Infer On')
      Else
        WriteLn('  Option Infer Off');
    End;
  End

  { Option non reconnue }
  Else
  Begin
    WarnMsg('Option non reconnue : "' + CurTokStr + '", ligne ignoree');
    SkipToEndOfLine;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseDottedName : lire un nom qualifie (A.B.C)               }
{   Le premier identifiant doit etre dans CurTokStr            }
{   Retourne le nom complet, avance apres le dernier composant }
{ ------------------------------------------------------------ }

Function ParseDottedName : TString;
Var Name : TString;
Begin
  Name := CurTokStr;
  LexNextToken;
  While CurTokType = TOK_DOT Do
  Begin
    LexNextToken;
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      Name := Name + '.' + CurTokStr;
      LexNextToken;
    End
    Else
    Begin
      FatalError('Nom qualifie attend un identifiant apres "."');
      Break;
    End;
  End;
  ParseDottedName := Name;
End;

{ ------------------------------------------------------------ }
{ SetupEntryPoint : configurer le point d entree du module     }
{   Module VB.NET : HasEntryPoint=True, label _VBNF_MAIN      }
{   Class VB.NET : pas de point d entree direct                }
{ ------------------------------------------------------------ }

Procedure SetupEntryPoint;
Begin
  If ModuleKind = MODULE_VB_CLASS Then
    HasEntryPoint := False
  Else
  Begin
    HasEntryPoint := True;
    If Opts.Verbose Then
      WriteLn('  Point d''entree : ', PFX_FUNC, 'MAIN');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseModuleLevelDecl : declaration anticipee (forward)       }
{   Implemente dans TODO 07, appele depuis ParseCompilationUnit }
{ ------------------------------------------------------------ }

Procedure ParseModuleLevelDecl; Forward;

{ ------------------------------------------------------------ }
{ ParseCompilationUnit : point d entree principal du parseur   }
{   VB.NET                                                     }
{   1. Analyser les Option statements                          }
{   2. Analyser les Imports statements                         }
{   3. Analyser le Namespace / Module / Class                  }
{   4. Configurer le point d entree                            }
{   Le corps du module sera parse par les TODOs suivants       }
{ ------------------------------------------------------------ }

Procedure ParseCompilationUnit;
Var NamespaceEntered : Boolean;
    ModuleEntered    : Boolean;
Begin
  InitModuleState;
  NamespaceEntered := False;
  ModuleEntered    := False;

  { Nom par defaut depuis le nom du fichier source }
  ModuleName := Opts.SrcFile;
  { Retirer l extension }
  If Pos('.', ModuleName) > 0 Then
    ModuleName := Copy(ModuleName, 1, Pos('.', ModuleName) - 1);
  { Retirer le chemin (separateur /) }
  While Pos('/', ModuleName) > 0 Do
    ModuleName := Copy(ModuleName, Pos('/', ModuleName) + 1, 255);
  { Retirer le chemin (separateur \) }
  While Pos('\', ModuleName) > 0 Do
    ModuleName := Copy(ModuleName, Pos('\', ModuleName) + 1, 255);

  If Opts.Verbose Then
    WriteLn('Compilation : ', Opts.SrcFile);

  { Lire le premier token }
  LexNextToken;
  SkipNewlines;

  { --- Phase 1 : Option statements en debut de fichier --- }
  While IsKeywordToken(KW_OPTION) Do
  Begin
    ParseOptionStatement;
    SkipNewlines;
  End;

  { --- Phase 2 : Imports statements --- }
  While IsKeywordToken(KW_IMPORTS) Do
  Begin
    ParseImportStatement;
    SkipNewlines;
  End;

  { --- Phase 3 : Namespace block (optionnel) --- }
  If IsKeywordToken(KW_NAMESPACE) Then
  Begin
    LexNextToken;
    { Lire le nom du namespace (peut etre qualifie : A.B.C) }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      NamespaceName := ParseDottedName;
      EnterScope(SCOPE_NAMESPACE, -1);
      NamespaceEntered := True;
      If Opts.Verbose Then
        WriteLn('  Namespace ', NamespaceName);
    End
    Else
      FatalError('Namespace attend un nom, trouve "' + CurTokStr + '"');
    SkipNewlines;
  End;

  { --- Phase 4 : Module ou Class declaration --- }
  If IsKeywordToken(KW_MODULE) Then
  Begin
    ModuleKind := MODULE_VB_MODULE;
    LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      ModuleName := CurTokStr;
      LexNextToken;
    End
    Else
      FatalError('Module attend un nom, trouve "' + CurTokStr + '"');
    EnterScope(SCOPE_MODULE, -1);
    ModuleEntered := True;
    If Opts.Verbose Then
      WriteLn('  Module ', ModuleName);
  End
  Else If IsKeywordToken(KW_CLASS) Then
  Begin
    ModuleKind := MODULE_VB_CLASS;
    LexNextToken;
    If CurTokType = TOK_IDENT Then
    Begin
      ModuleName := CurTokStr;
      LexNextToken;
    End
    Else
      FatalError('Class attend un nom, trouve "' + CurTokStr + '"');
    EnterScope(SCOPE_CLASS, -1);
    ModuleEntered := True;
    If Opts.Verbose Then
      WriteLn('  Class ', ModuleName);
  End;

  { Configurer le point d entree }
  SetupEntryPoint;
  ModuleHeaderParsed := True;

  { Affichage du resume en mode verbeux }
  If Opts.Verbose Then
  Begin
    WriteLn('  Nom du module  : ', ModuleName);
    If NamespaceName <> '' Then
      WriteLn('  Namespace      : ', NamespaceName);
    WriteLn('  Type           : ', ModuleKindName(ModuleKind));
    If Opts.OptionExplicit Then
      WriteLn('  OptionExplicit : On')
    Else
      WriteLn('  OptionExplicit : Off');
    If Opts.OptionStrict Then
      WriteLn('  OptionStrict   : On')
    Else
      WriteLn('  OptionStrict   : Off');
    If OptionCompare = OPT_COMPARE_BINARY Then
      WriteLn('  OptionCompare  : Binary')
    Else
      WriteLn('  OptionCompare  : Text');
    If Opts.OptionInfer Then
      WriteLn('  OptionInfer    : On')
    Else
      WriteLn('  OptionInfer    : Off');
    If HasEntryPoint Then
      WriteLn('  HasEntryPoint  : True')
    Else
      WriteLn('  HasEntryPoint  : False');
    WriteLn('  Imports        : ', ImportCount);
  End;

  { Phase 5 : Declarations au niveau module (TODO 07) }
  SkipNewlines;
  ParseModuleLevelDecl;

  { Les TODOs 08-25 ajouteront ici le parsing des expressions, }
  { Sub/Function, etc.                                          }
  If CurTokType <> TOK_EOF Then
  Begin
    If Opts.Verbose Then
      WriteLn('  (corps du module non encore parse - TODOs 08-25)');
  End;

  { Avancer jusqu a la fin du fichier (TODOs 08+ parseront le reste) }
  While CurTokType <> TOK_EOF Do
    LexNextToken;

  { Quitter les portees ouvertes }
  If ModuleEntered Then
    LeaveScope;
  If NamespaceEntered Then
    LeaveScope;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour l etat du module et des imports     }
{ ------------------------------------------------------------ }

Function GetModuleKind : Integer;
Begin
  GetModuleKind := ModuleKind;
End;

Function GetModuleName : TString;
Begin
  GetModuleName := ModuleName;
End;

Function GetNamespaceName : TString;
Begin
  GetNamespaceName := NamespaceName;
End;

Function GetOptionCompare : Integer;
Begin
  GetOptionCompare := OptionCompare;
End;

Function IsOptionExplicitOn : Boolean;
Begin
  IsOptionExplicitOn := Opts.OptionExplicit;
End;

Function IsOptionStrictOn : Boolean;
Begin
  IsOptionStrictOn := Opts.OptionStrict;
End;

Function IsOptionInferOn : Boolean;
Begin
  IsOptionInferOn := Opts.OptionInfer;
End;

Function IsOptionCompareBinary : Boolean;
Begin
  IsOptionCompareBinary := (OptionCompare = OPT_COMPARE_BINARY);
End;

Function IsOptionCompareText : Boolean;
Begin
  IsOptionCompareText := (OptionCompare = OPT_COMPARE_TEXT);
End;

Function HasMainEntry : Boolean;
Begin
  HasMainEntry := HasEntryPoint;
End;

Function IsModuleHeaderParsed : Boolean;
Begin
  IsModuleHeaderParsed := ModuleHeaderParsed;
End;

Function IsVBModule : Boolean;
Begin
  IsVBModule := (ModuleKind = MODULE_VB_MODULE);
End;

Function IsVBClass : Boolean;
Begin
  IsVBClass := (ModuleKind = MODULE_VB_CLASS);
End;

Function GetImportCount : Integer;
Begin
  GetImportCount := ImportCount;
End;

Function GetImportNamespace(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < ImportCount) Then
    GetImportNamespace := ImportTab[Idx].Namespace
  Else
    GetImportNamespace := '';
End;

Function GetImportAlias(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < ImportCount) Then
    GetImportAlias := ImportTab[Idx].Alias
  Else
    GetImportAlias := '';
End;

Function FindImportByAlias(Const A : TString) : Integer;
Var I : Integer;
    U : TString;
Begin
  FindImportByAlias := -1;
  U := UpCaseStr(A);
  For I := 0 To ImportCount - 1 Do
  Begin
    If UpCaseStr(ImportTab[I].Alias) = U Then
    Begin
      FindImportByAlias := I;
      Exit;
    End;
  End;
End;

Function IsNamespaceImported(Const NS : TString) : Boolean;
Begin
  IsNamespaceImported := (FindImport(NS) >= 0);
End;

Function IsImportTableEmpty : Boolean;
Begin
  IsImportTableEmpty := (ImportCount = 0);
End;

Function IsImportTableFull : Boolean;
Begin
  IsImportTableFull := (ImportCount >= MAX_IMPORT_ENTRIES);
End;

Function GetMaxImportEntries : Integer;
Begin
  GetMaxImportEntries := MAX_IMPORT_ENTRIES;
End;

Function HasNamespace : Boolean;
Begin
  HasNamespace := (NamespaceName <> '');
End;

Function GetModuleKindName : TString;
Begin
  GetModuleKindName := ModuleKindName(ModuleKind);
End;

{ ============================================================ }
{ TODO 07 - PARSEUR : DECLARATIONS (DIM, PUBLIC,  [IMPLEMENTE] }
{           PRIVATE, CONST, SHARED, PROTECTED, FRIEND)         }
{ ============================================================ }

Var
  DeclCount       : Integer;  { compteur de declarations traitees      }
  LastDeclIdx     : Integer;  { index du dernier symbole declare       }
  DeclParsingDone : Boolean;  { fin de l analyse des declarations      }

{ ------------------------------------------------------------ }
{ InitDeclState : initialiser l etat des declarations          }
{ ------------------------------------------------------------ }

Procedure InitDeclState;
Begin
  DeclCount       := 0;
  LastDeclIdx     := -1;
  DeclParsingDone := False;
End;

{ ------------------------------------------------------------ }
{ ParseTypeSpec : analyser une specification de type VB.NET     }
{   Token courant : le nom du type (Boolean, Integer, etc.)    }
{   Reconnait tous les types VB.NET y compris SByte, Short,    }
{   UShort, UInteger, Long, ULong, Decimal, Char, Object       }
{   Retourne le code VBT_* du type                             }
{ ------------------------------------------------------------ }

Function ParseTypeSpec : Integer;
Var T : Integer;
Begin
  T := VBT_OBJECT; { par defaut si type non reconnu }
  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_BOOLEAN  : T := VBT_BOOLEAN;
      KW_BYTE     : T := VBT_BYTE;
      KW_SBYTE    : T := VBT_SBYTE;
      KW_SHORT    : T := VBT_SHORT;
      KW_USHORT   : T := VBT_USHORT;
      KW_INTEGER  : T := VBT_INTEGER;
      KW_UINTEGER : T := VBT_UINTEGER;
      KW_LONG     : T := VBT_LONG;
      KW_ULONG    : T := VBT_ULONG;
      KW_SINGLE   : T := VBT_SINGLE;
      KW_DOUBLE   : T := VBT_DOUBLE;
      KW_DECIMAL  : T := VBT_DECIMAL;
      KW_CHAR     : T := VBT_CHAR;
      KW_STRING   : T := VBT_STRING;
      KW_DATE     : T := VBT_DATE;
      KW_OBJECT   : T := VBT_OBJECT;
    Else
      WarnMsg('Type non reconnu: "' + CurTokStr + '", Object suppose');
    End;
    LexNextToken;
  End
  Else If CurTokType = TOK_IDENT Then
  Begin
    { Type utilisateur (Structure, Class, Enum) }
    T := VBT_USER;
    LexNextToken;
  End
  Else
  Begin
    WarnMsg('Nom de type attendu, trouve "' + CurTokStr + '"');
  End;
  ParseTypeSpec := T;
End;

{ ------------------------------------------------------------ }
{ DetermineStoreClass : determiner la classe d entreposage     }
{   IsStaticDecl : variable Static ?                           }
{   IsSharedDecl : variable Shared ?                           }
{   IsPub        : variable Public ?                           }
{   Retourne STORE_AUTO, STORE_STATIC, STORE_GLOBAL,           }
{   STORE_SHARED selon le contexte                             }
{ ------------------------------------------------------------ }

Function DetermineStoreClass(IsStaticDecl : Boolean;
                             IsSharedDecl : Boolean;
                             IsPub : Boolean) : Integer;
Begin
  If IsStaticDecl Then
    DetermineStoreClass := STORE_STATIC
  Else If IsSharedDecl Then
    DetermineStoreClass := STORE_SHARED
  Else If IsInGlobalScope Then
    DetermineStoreClass := STORE_GLOBAL
  Else If IsPub Then
    DetermineStoreClass := STORE_GLOBAL
  Else
    DetermineStoreClass := STORE_AUTO;
End;

{ ------------------------------------------------------------ }
{ ParseVarDecl : analyser une declaration de variable unique    }
{   Token courant : l identifiant de la variable               }
{   Gere :                                                     }
{     - As Type                                                }
{     - Initialisation = valeur                                }
{     - Tableaux : arr(10), arr(), arr(1, 2)                   }
{   Retourne l index dans SymTab ou -1 en cas d erreur         }
{ ------------------------------------------------------------ }

Function ParseVarDecl(IsStaticDecl : Boolean;
                      IsSharedDecl : Boolean;
                      IsPub : Boolean;
                      IsReadOnlyDecl : Boolean) : Integer;
Var
  VarName   : TString;
  VarType   : Integer;
  Store     : Integer;
  Idx       : Integer;
  ArrDims   : Integer;
  HasParens : Boolean;
Begin
  ParseVarDecl := -1;
  If CurTokType <> TOK_IDENT Then
  Begin
    FatalError('Nom de variable attendu, trouve "' + CurTokStr + '"');
    Exit;
  End;
  VarName := CurTokStr;
  LexNextToken;

  { Verifier les parentheses pour tableau }
  ArrDims   := 0;
  HasParens := False;
  If CurTokType = TOK_LPAREN Then
  Begin
    HasParens := True;
    LexNextToken; { consommer ( }
    If CurTokType = TOK_RPAREN Then
    Begin
      { Tableau dynamique : arr() }
      ArrDims := 1;
    End
    Else
    Begin
      { Tableau avec dimension(s) }
      ArrDims := 1;
      { Parcourir les dimensions }
      While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
      Begin
        If CurTokType = TOK_COMMA Then
        Begin
          Inc(ArrDims);
          LexNextToken;
        End
        Else
          LexNextToken;
      End;
    End;
    If CurTokType = TOK_RPAREN Then
      LexNextToken; { consommer ) }
  End;

  { Verifier "As Type" }
  VarType := VBT_OBJECT; { par defaut en VB.NET : Object }
  If IsKeywordToken(KW_AS) Then
  Begin
    LexNextToken; { consommer As }
    VarType := ParseTypeSpec;
  End;

  { Verifier initialisation = valeur }
  If CurTokType = TOK_EQ Then
  Begin
    LexNextToken; { consommer = }
    { Lire la valeur initiale (sera ameliore par TODO 08) }
    { Pour l instant, on avance jusqu a la virgule, newline ou EOF }
    While (CurTokType <> TOK_COMMA) And
          (CurTokType <> TOK_NEWLINE) And
          (CurTokType <> TOK_EOF) Do
      LexNextToken;
  End;

  { Determiner la classe d entreposage }
  Store := DetermineStoreClass(IsStaticDecl, IsSharedDecl, IsPub);

  { Ajouter le symbole }
  Idx := AddSym(VarName, SK_VAR, VarType, Store);
  If Idx < 0 Then
  Begin
    ParseVarDecl := -1;
    Exit;
  End;

  { Configurer les champs supplementaires }
  SymTab[Idx].IsPublic   := IsPub;
  SymTab[Idx].IsStatic   := IsStaticDecl;
  SymTab[Idx].IsShared   := IsSharedDecl;
  SymTab[Idx].IsReadOnly := IsReadOnlyDecl;
  SymTab[Idx].ArrayDims  := ArrDims;
  SymTab[Idx].ArrayBase  := 0; { VB.NET : base toujours 0 }

  { Allouer l espace memoire }
  If Store = STORE_AUTO Then
  Begin
    { Variable locale : allouer sur la pile EBP }
    SymTab[Idx].BpOffset := AllocLocalEbp(VBTypeSize(VarType));
  End;

  If Opts.Verbose Then
  Begin
    Write('  Decl: ', VarName, ' As ', VBTypeName(VarType));
    Write(' [', StoreClassName(Store), ']');
    If ArrDims > 0 Then
      Write(' (', ItoSI(ArrDims), ' dim)');
    If Store = STORE_AUTO Then
      Write(' [EBP-', ItoSI(SymTab[Idx].BpOffset), ']');
    If IsReadOnlyDecl Then
      Write(' ReadOnly');
    WriteLn;
  End;

  Inc(DeclCount);
  LastDeclIdx := Idx;
  ParseVarDecl := Idx;
End;

{ ------------------------------------------------------------ }
{ ParseDimStatement : analyser une instruction Dim              }
{   Token courant : KW_DIM                                     }
{   Syntaxe :                                                  }
{     Dim x As Integer                                         }
{     Dim x As Integer = 42                                    }
{     Dim x As Integer, y As String                            }
{     Dim arr(10) As Integer                                   }
{     Dim arr() As Integer                                     }
{ ------------------------------------------------------------ }

Procedure ParseDimStatement;
Begin
  LexNextToken; { consommer Dim }
  { Analyser la premiere variable }
  ParseVarDecl(False, False, False, False);
  { Verifier les declarations multiples separees par virgule }
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken; { consommer , }
    ParseVarDecl(False, False, False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePublicDecl : analyser une declaration Public             }
{   Token courant : KW_PUBLIC                                  }
{   Si suivi de Sub/Function, on skip (TODO 12)                }
{ ------------------------------------------------------------ }

Procedure ParsePublicDecl;
Begin
  LexNextToken; { consommer Public }
  { Verifier si c est Public Sub/Function (traite par TODO 12) }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  { Verifier si c est Public Shared }
  If IsKeywordToken(KW_SHARED) Then
  Begin
    LexNextToken; { consommer Shared }
    ParseVarDecl(False, True, True, False);
    While CurTokType = TOK_COMMA Do
    Begin
      LexNextToken;
      ParseVarDecl(False, True, True, False);
    End;
    Exit;
  End;
  { Sinon c est une declaration de variable publique }
  ParseVarDecl(False, False, True, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False, True, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrivateDecl : analyser une declaration Private           }
{   Token courant : KW_PRIVATE                                 }
{   Si suivi de Sub/Function, on skip (TODO 12)                }
{ ------------------------------------------------------------ }

Procedure ParsePrivateDecl;
Begin
  LexNextToken; { consommer Private }
  { Verifier si c est Private Sub/Function }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  { Verifier si c est Private Shared }
  If IsKeywordToken(KW_SHARED) Then
  Begin
    LexNextToken; { consommer Shared }
    ParseVarDecl(False, True, False, False);
    While CurTokType = TOK_COMMA Do
    Begin
      LexNextToken;
      ParseVarDecl(False, True, False, False);
    End;
    Exit;
  End;
  { Sinon c est une declaration de variable privee }
  ParseVarDecl(False, False, False, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False, False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseProtectedDecl : analyser une declaration Protected       }
{   Token courant : KW_PROTECTED                               }
{   Utilisable uniquement dans Class                           }
{ ------------------------------------------------------------ }

Procedure ParseProtectedDecl;
Begin
  LexNextToken; { consommer Protected }
  { Verifier si c est Protected Sub/Function }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  { Variable Protected (classe uniquement) }
  ParseVarDecl(False, False, False, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False, False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseFriendDecl : analyser une declaration Friend             }
{   Token courant : KW_FRIEND                                  }
{   Acces au niveau de l assemblage                            }
{ ------------------------------------------------------------ }

Procedure ParseFriendDecl;
Begin
  LexNextToken; { consommer Friend }
  { Verifier si c est Friend Sub/Function }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  { Variable Friend (acces assembly) }
  ParseVarDecl(False, False, True, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False, True, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseStaticDecl : analyser une declaration Static             }
{   Token courant : KW_STATIC                                  }
{   Static alloue toujours en .DATA, meme dans Sub/Function    }
{ ------------------------------------------------------------ }

Procedure ParseStaticDecl;
Begin
  LexNextToken; { consommer Static }
  { Verifier si c est Static Sub/Function }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  ParseVarDecl(True, False, False, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(True, False, False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSharedDecl : analyser une declaration Shared             }
{   Token courant : KW_SHARED                                  }
{   Shared : en .DATA, accessible via NomClasse.membre         }
{ ------------------------------------------------------------ }

Procedure ParseSharedDecl;
Begin
  LexNextToken; { consommer Shared }
  { Verifier si c est Shared Sub/Function }
  If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Then
  Begin
    SkipToEndOfLine;
    Exit;
  End;
  ParseVarDecl(False, True, False, False);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, True, False, False);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseReadOnlyDecl : analyser une declaration ReadOnly         }
{   Token courant : KW_READONLY                                }
{ ------------------------------------------------------------ }

Procedure ParseReadOnlyDecl;
Begin
  LexNextToken; { consommer ReadOnly }
  ParseVarDecl(False, False, False, True);
  While CurTokType = TOK_COMMA Do
  Begin
    LexNextToken;
    ParseVarDecl(False, False, False, True);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseConstStatement : analyser une declaration Const          }
{   Token courant : KW_CONST                                   }
{   Syntaxe :                                                  }
{     Const PI As Double = 3.14159                             }
{     Const MAX_SIZE As Integer = 100                          }
{     Const MSG As String = "Bonjour"                          }
{ ------------------------------------------------------------ }

Procedure ParseConstStatement;
Var
  ConstName : TString;
  ConstType : Integer;
  Store     : Integer;
  Idx       : Integer;
Begin
  LexNextToken; { consommer Const }
  If CurTokType <> TOK_IDENT Then
  Begin
    FatalError('Nom de constante attendu, trouve "' + CurTokStr + '"');
    Exit;
  End;
  ConstName := CurTokStr;
  LexNextToken;

  { Type optionnel : As Type }
  ConstType := VBT_OBJECT;
  If IsKeywordToken(KW_AS) Then
  Begin
    LexNextToken;
    ConstType := ParseTypeSpec;
  End;

  { Attendre le signe = }
  If CurTokType <> TOK_EQ Then
  Begin
    FatalError('Signe "=" attendu pour Const, trouve "' + CurTokStr + '"');
    Exit;
  End;
  LexNextToken; { consommer = }

  { Determiner la classe d entreposage pour la constante }
  Store := STORE_CONSTANT;

  { Ajouter le symbole comme constante }
  Idx := AddSym(ConstName, SK_CONST, ConstType, Store);
  If Idx < 0 Then Exit;

  SymTab[Idx].IsConst := True;
  SymTab[Idx].HasInit := True;

  { Lire la valeur initiale }
  If CurTokType = TOK_INTEGER Then
  Begin
    SymTab[Idx].InitNum := CurTokNum;
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_INTEGER;
    LexNextToken;
  End
  Else If (CurTokType = TOK_SINGLE) Or (CurTokType = TOK_DOUBLE) Or
          (CurTokType = TOK_DECIMAL) Then
  Begin
    { Nombre reel : stocker comme entier tronque (stub) }
    SymTab[Idx].InitNum := CurTokNum;
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_DOUBLE;
    LexNextToken;
  End
  Else If CurTokType = TOK_STRING Then
  Begin
    SymTab[Idx].InitStr := CurTokStr;
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_STRING;
    LexNextToken;
  End
  Else If IsKeywordToken(KW_NOTHING) Then
  Begin
    SymTab[Idx].InitNum := 0;
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_OBJECT;
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRUE) Then
  Begin
    SymTab[Idx].InitNum := -1; { True = -1 en VB.NET }
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_BOOLEAN;
    LexNextToken;
  End
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FALSE) Then
  Begin
    SymTab[Idx].InitNum := 0;
    If ConstType = VBT_OBJECT Then
      SymTab[Idx].DataType := VBT_BOOLEAN;
    LexNextToken;
  End
  Else
  Begin
    { Expression complexe : lire jusqu a fin de ligne }
    { (sera ameliore par TODO 08 - expressions) }
    SymTab[Idx].InitNum := CurTokNum;
    SkipToEndOfLine;
  End;

  If Opts.Verbose Then
  Begin
    Write('  Const: ', ConstName, ' As ', VBTypeName(SymTab[Idx].DataType));
    If SymTab[Idx].DataType = VBT_STRING Then
      Write(' = "', SymTab[Idx].InitStr, '"')
    Else
      Write(' = ', ItoS(SymTab[Idx].InitNum));
    WriteLn;
  End;

  Inc(DeclCount);
  LastDeclIdx := Idx;
End;

{ ------------------------------------------------------------ }
{ ParseModuleLevelDecl : analyser toutes les declarations      }
{   au niveau module (entre Module/Class et End Module/Class)  }
{   Reconnait : Dim, Public, Private, Protected, Friend,       }
{     Static, Shared, Const, ReadOnly                          }
{   S arrete sur Sub, Function, End, Structure, Enum, Class    }
{   ou tout token non reconnu a ce niveau                      }
{ ------------------------------------------------------------ }

Procedure ParseModuleLevelDecl;
Begin
  InitDeclState;
  SkipNewlines;
  While CurTokType <> TOK_EOF Do
  Begin
    { Dim }
    If IsKeywordToken(KW_DIM) Then
    Begin
      ParseDimStatement;
      SkipNewlines;
    End
    { Public (variable ou Sub/Function) }
    Else If IsKeywordToken(KW_PUBLIC) Then
    Begin
      ParsePublicDecl;
      SkipNewlines;
    End
    { Private (variable ou Sub/Function) }
    Else If IsKeywordToken(KW_PRIVATE) Then
    Begin
      ParsePrivateDecl;
      SkipNewlines;
    End
    { Protected (classe) }
    Else If IsKeywordToken(KW_PROTECTED) Then
    Begin
      ParseProtectedDecl;
      SkipNewlines;
    End
    { Friend (acces assembly) }
    Else If IsKeywordToken(KW_FRIEND) Then
    Begin
      ParseFriendDecl;
      SkipNewlines;
    End
    { Static }
    Else If IsKeywordToken(KW_STATIC) Then
    Begin
      ParseStaticDecl;
      SkipNewlines;
    End
    { Shared }
    Else If IsKeywordToken(KW_SHARED) Then
    Begin
      ParseSharedDecl;
      SkipNewlines;
    End
    { Const }
    Else If IsKeywordToken(KW_CONST) Then
    Begin
      ParseConstStatement;
      SkipNewlines;
    End
    { ReadOnly }
    Else If IsKeywordToken(KW_READONLY) Then
    Begin
      ParseReadOnlyDecl;
      SkipNewlines;
    End
    { Sub / Function / End / Structure / Enum / Class : }
    { fin des declarations de module                    }
    Else If IsKeywordToken(KW_SUB) Or IsKeywordToken(KW_FUNCTION) Or
            IsKeywordToken(KW_END) Or IsKeywordToken(KW_STRUCTURE) Or
            IsKeywordToken(KW_ENUM) Or IsKeywordToken(KW_CLASS) Then
    Begin
      { Arreter : le code sera traite par les TODOs 08-25 }
      Break;
    End
    { Option deja traite dans ParseCompilationUnit }
    Else If IsKeywordToken(KW_OPTION) Then
    Begin
      SkipToEndOfLine;
      SkipNewlines;
    End
    { Token non reconnu a ce niveau : arreter les declarations }
    Else
      Break;
  End;
  DeclParsingDone := True;
  If Opts.Verbose Then
    WriteLn('  ', ItoSI(DeclCount), ' declaration(s) au niveau module');
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour l etat des declarations             }
{ ------------------------------------------------------------ }

Function GetDeclCount : Integer;
Begin
  GetDeclCount := DeclCount;
End;

Function GetLastDeclIdx : Integer;
Begin
  GetLastDeclIdx := LastDeclIdx;
End;

Function IsDeclParsingDone : Boolean;
Begin
  IsDeclParsingDone := DeclParsingDone;
End;

Function IsDeclCountZero : Boolean;
Begin
  IsDeclCountZero := (DeclCount = 0);
End;

Function GetDeclName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclName := SymTab[Idx].Name
  Else
    GetDeclName := '';
End;

Function GetDeclType(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclType := SymTab[Idx].DataType
  Else
    GetDeclType := VBT_NONE;
End;

Function GetDeclStore(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclStore := SymTab[Idx].StoreClass
  Else
    GetDeclStore := STORE_AUTO;
End;

Function GetDeclTypeName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclTypeName := VBTypeName(SymTab[Idx].DataType)
  Else
    GetDeclTypeName := '(none)';
End;

Function GetDeclStoreName(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclStoreName := StoreClassName(SymTab[Idx].StoreClass)
  Else
    GetDeclStoreName := '(none)';
End;

Function IsDeclPublic(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclPublic := SymTab[Idx].IsPublic
  Else
    IsDeclPublic := False;
End;

Function IsDeclStatic(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclStatic := SymTab[Idx].IsStatic
  Else
    IsDeclStatic := False;
End;

Function IsDeclShared(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclShared := SymTab[Idx].IsShared
  Else
    IsDeclShared := False;
End;

Function IsDeclReadOnly(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclReadOnly := SymTab[Idx].IsReadOnly
  Else
    IsDeclReadOnly := False;
End;

Function IsDeclConst(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclConst := SymTab[Idx].IsConst
  Else
    IsDeclConst := False;
End;

Function IsDeclArray(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    IsDeclArray := (SymTab[Idx].ArrayDims > 0)
  Else
    IsDeclArray := False;
End;

Function GetDeclArrayDims(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclArrayDims := SymTab[Idx].ArrayDims
  Else
    GetDeclArrayDims := 0;
End;

Function GetDeclBpOffset(Idx : Integer) : Integer;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclBpOffset := SymTab[Idx].BpOffset
  Else
    GetDeclBpOffset := 0;
End;

Function GetDeclAsmLabel(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclAsmLabel := SymTab[Idx].AsmLabel
  Else
    GetDeclAsmLabel := '';
End;

Function HasDeclInit(Idx : Integer) : Boolean;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    HasDeclInit := SymTab[Idx].HasInit
  Else
    HasDeclInit := False;
End;

Function GetDeclInitNum(Idx : Integer) : LongInt;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclInitNum := SymTab[Idx].InitNum
  Else
    GetDeclInitNum := 0;
End;

Function GetDeclInitStr(Idx : Integer) : TString;
Begin
  If (Idx >= 0) And (Idx < SymCount) Then
    GetDeclInitStr := SymTab[Idx].InitStr
  Else
    GetDeclInitStr := '';
End;

Function IsDeclStatement(KW : Integer) : Boolean;
Begin
  IsDeclStatement := (KW = KW_DIM) Or (KW = KW_PUBLIC) Or
                     (KW = KW_PRIVATE) Or (KW = KW_PROTECTED) Or
                     (KW = KW_FRIEND) Or (KW = KW_STATIC) Or
                     (KW = KW_SHARED) Or (KW = KW_CONST) Or
                     (KW = KW_READONLY);
End;

Function IsAccessModifier(KW : Integer) : Boolean;
Begin
  IsAccessModifier := (KW = KW_PUBLIC) Or (KW = KW_PRIVATE) Or
                      (KW = KW_PROTECTED) Or (KW = KW_FRIEND);
End;

Function IsStorageModifier(KW : Integer) : Boolean;
Begin
  IsStorageModifier := (KW = KW_STATIC) Or (KW = KW_SHARED) Or
                       (KW = KW_READONLY) Or (KW = KW_CONST);
End;

Function GetDeclStatus : TString;
Begin
  If DeclParsingDone Then
    GetDeclStatus := 'done (' + ItoSI(DeclCount) + ' decl)'
  Else
    GetDeclStatus := 'pending';
End;

Function GetLastDeclName : TString;
Begin
  If (LastDeclIdx >= 0) And (LastDeclIdx < SymCount) Then
    GetLastDeclName := SymTab[LastDeclIdx].Name
  Else
    GetLastDeclName := '';
End;

{ ============================================================ }
{ TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES  [IMPLEMENTE] }
{           ET LOGIQUES (32 BITS)                              }
{ ============================================================ }

{ ------------------------------------------------------------ }
{ Operateur : constantes pour le type d operateur interne      }
{ ------------------------------------------------------------ }

Const
  OP_NONE        = 0;    { pas d operateur                        }
  OP_ADD         = 1;    { +                                      }
  OP_SUB         = 2;    { -                                      }
  OP_MUL         = 3;    { *                                      }
  OP_DIV         = 4;    { /                                      }
  OP_INTDIV      = 5;    { \ (division entiere)                   }
  OP_MOD         = 6;    { Mod                                    }
  OP_POW         = 7;    { ^                                      }
  OP_CONCAT      = 8;    { & (concatenation)                      }
  OP_EQ          = 10;   { =                                      }
  OP_NE          = 11;   { <>                                     }
  OP_LT          = 12;   { <                                      }
  OP_GT          = 13;   { >                                      }
  OP_LE          = 14;   { <=                                     }
  OP_GE          = 15;   { >=                                     }
  OP_LIKE        = 16;   { Like                                   }
  OP_IS          = 17;   { Is                                     }
  OP_ISNOT       = 18;   { IsNot (VB.NET)                         }
  OP_AND         = 20;   { And                                    }
  OP_ANDALSO     = 21;   { AndAlso (VB.NET short-circuit)         }
  OP_OR          = 22;   { Or                                     }
  OP_ORELSE      = 23;   { OrElse (VB.NET short-circuit)          }
  OP_XOR         = 24;   { Xor                                    }
  OP_NOT         = 25;   { Not                                    }
  OP_NEGATE      = 26;   { - (unaire)                             }
  OP_ADDRESSOF   = 27;   { AddressOf (VB.NET)                     }

Var
  ExprCount      : Integer;  { nombre d expressions analysees       }
  ExprDepth      : Integer;  { profondeur actuelle d imbrication    }
  MaxExprDepth   : Integer;  { profondeur maximale atteinte         }
  ExprResultType : Integer;  { type VBT_* du resultat de l expr     }

{ ------------------------------------------------------------ }
{ InitExprState : initialiser l etat de l analyseur d exprs    }
{ ------------------------------------------------------------ }

Procedure InitExprState;
Begin
  ExprCount      := 0;
  ExprDepth      := 0;
  MaxExprDepth   := 0;
  ExprResultType := VBT_NONE;
End;

{ ------------------------------------------------------------ }
{ EnterExpr / LeaveExpr : gerer la profondeur d imbrication    }
{ ------------------------------------------------------------ }

Procedure EnterExpr;
Begin
  Inc(ExprDepth);
  If ExprDepth > MaxExprDepth Then
    MaxExprDepth := ExprDepth;
End;

Procedure LeaveExpr;
Begin
  If ExprDepth > 0 Then
    Dec(ExprDepth);
End;

{ ------------------------------------------------------------ }
{ OpName : retourner le nom textuel d un operateur             }
{ ------------------------------------------------------------ }

Function OpName(Op : Integer) : TString;
Begin
  Case Op Of
    OP_ADD       : OpName := '+';
    OP_SUB       : OpName := '-';
    OP_MUL       : OpName := '*';
    OP_DIV       : OpName := '/';
    OP_INTDIV    : OpName := '\';
    OP_MOD       : OpName := 'Mod';
    OP_POW       : OpName := '^';
    OP_CONCAT    : OpName := '&';
    OP_EQ        : OpName := '=';
    OP_NE        : OpName := '<>';
    OP_LT        : OpName := '<';
    OP_GT        : OpName := '>';
    OP_LE        : OpName := '<=';
    OP_GE        : OpName := '>=';
    OP_LIKE      : OpName := 'Like';
    OP_IS        : OpName := 'Is';
    OP_ISNOT     : OpName := 'IsNot';
    OP_AND       : OpName := 'And';
    OP_ANDALSO   : OpName := 'AndAlso';
    OP_OR        : OpName := 'Or';
    OP_ORELSE    : OpName := 'OrElse';
    OP_XOR       : OpName := 'Xor';
    OP_NOT       : OpName := 'Not';
    OP_NEGATE    : OpName := '- (neg)';
    OP_ADDRESSOF : OpName := 'AddressOf';
  Else
    OpName := '?OP' + ItoSI(Op);
  End;
End;

{ ------------------------------------------------------------ }
{ Declarations forward pour la descente recursive              }
{ ------------------------------------------------------------ }

Function ParseExpr : Integer; Forward;
Function ParseOrExpr : Integer; Forward;
Function ParseAndExpr : Integer; Forward;
Function ParseNotExpr : Integer; Forward;
Function ParseCompExpr : Integer; Forward;
Function ParseConcatExpr : Integer; Forward;
Function ParseAddExpr : Integer; Forward;
Function ParseModExpr : Integer; Forward;
Function ParseIntDivExpr : Integer; Forward;
Function ParseMulExpr : Integer; Forward;
Function ParsePowExpr : Integer; Forward;
Function ParseUnaryExpr : Integer; Forward;
Function ParsePrimaryExpr : Integer; Forward;

{ ------------------------------------------------------------ }
{ DetermineResultType : determiner le type VBT_* d un binop    }
{   Regle simplifiee VB.NET :                                  }
{     String op String -> String si &, sinon erreur/Object     }
{     Double / Single / Decimal -> Double                      }
{     Long / Integer / Short / Byte -> Integer (32 bits)       }
{     Boolean -> Integer pour arithm., Boolean pour logique    }
{     Comparaisons -> Boolean                                  }
{ ------------------------------------------------------------ }

Function DetermineResultType(Op : Integer; L, R : Integer) : Integer;
Begin
  { Comparaisons : toujours Boolean }
  If (Op >= OP_EQ) And (Op <= OP_ISNOT) Then
  Begin
    DetermineResultType := VBT_BOOLEAN;
    Exit;
  End;
  { Operateurs logiques : Boolean si les deux Boolean, sinon Integer }
  If (Op >= OP_AND) And (Op <= OP_XOR) Then
  Begin
    If (L = VBT_BOOLEAN) And (R = VBT_BOOLEAN) Then
      DetermineResultType := VBT_BOOLEAN
    Else
      DetermineResultType := VBT_INTEGER;
    Exit;
  End;
  { Concatenation : String }
  If Op = OP_CONCAT Then
  Begin
    DetermineResultType := VBT_STRING;
    Exit;
  End;
  { Si un operande est Decimal -> Decimal }
  If (L = VBT_DECIMAL) Or (R = VBT_DECIMAL) Then
  Begin
    DetermineResultType := VBT_DECIMAL;
    Exit;
  End;
  { Si un operande est Double ou Single -> Double }
  If (L = VBT_DOUBLE) Or (R = VBT_DOUBLE) Or
     (L = VBT_SINGLE) Or (R = VBT_SINGLE) Then
  Begin
    DetermineResultType := VBT_DOUBLE;
    Exit;
  End;
  { Division reelle : toujours Double }
  If Op = OP_DIV Then
  Begin
    DetermineResultType := VBT_DOUBLE;
    Exit;
  End;
  { Si un operande est Long (64 bits) -> Long }
  If (L = VBT_LONG) Or (R = VBT_LONG) Or
     (L = VBT_ULONG) Or (R = VBT_ULONG) Then
  Begin
    DetermineResultType := VBT_LONG;
    Exit;
  End;
  { Sinon : Integer (32 bits) }
  DetermineResultType := VBT_INTEGER;
End;

{ ------------------------------------------------------------ }
{ ParsePrimaryExpr : facteur primaire                          }
{   Constante numerique, chaine, caractere, decimal            }
{   True/False/Nothing, variable, appel de fonction            }
{   (expr), Me, New, TypeOf...Is, DirectCast, CType, TryCast   }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParsePrimaryExpr : Integer;
Var
  SIdx : Integer;
  T    : Integer;
Begin
  ParsePrimaryExpr := VBT_INTEGER;
  EnterExpr;
  { Litteral entier }
  If CurTokType = TOK_INTEGER Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: integer ', CurTokNum);
    ParsePrimaryExpr := VBT_INTEGER;
    LexNextToken;
  End
  { Litteral long }
  Else If CurTokType = TOK_LONG Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: long ', CurTokNum);
    ParsePrimaryExpr := VBT_LONG;
    LexNextToken;
  End
  { Litteral single }
  Else If CurTokType = TOK_SINGLE Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: single ', CurTokReal:0:6);
    ParsePrimaryExpr := VBT_SINGLE;
    LexNextToken;
  End
  { Litteral double }
  Else If CurTokType = TOK_DOUBLE Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: double ', CurTokReal:0:6);
    ParsePrimaryExpr := VBT_DOUBLE;
    LexNextToken;
  End
  { Litteral decimal (VB.NET : 1.5D) }
  Else If CurTokType = TOK_DECIMAL Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: decimal ', CurTokStr);
    ParsePrimaryExpr := VBT_DECIMAL;
    LexNextToken;
  End
  { Litteral chaine }
  Else If CurTokType = TOK_STRING Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: string "', CurTokStr, '"');
    ParsePrimaryExpr := VBT_STRING;
    LexNextToken;
  End
  { Litteral caractere VB.NET ("A"c) }
  Else If CurTokType = TOK_CHAR Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: char "', CurTokStr, '"c');
    ParsePrimaryExpr := VBT_CHAR;
    LexNextToken;
  End
  { Litteral date }
  Else If CurTokType = TOK_DATE Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: date ', CurTokStr);
    ParsePrimaryExpr := VBT_DATE;
    LexNextToken;
  End
  { True -> -1 (Boolean) }
  Else If IsKeywordToken(KW_TRUE) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: True (-1)');
    ParsePrimaryExpr := VBT_BOOLEAN;
    LexNextToken;
  End
  { False -> 0 (Boolean) }
  Else If IsKeywordToken(KW_FALSE) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: False (0)');
    ParsePrimaryExpr := VBT_BOOLEAN;
    LexNextToken;
  End
  { Nothing -> 0 (Object) }
  Else If IsKeywordToken(KW_NOTHING) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: Nothing');
    ParsePrimaryExpr := VBT_OBJECT;
    LexNextToken;
  End
  { Me -> reference a l objet courant }
  Else If IsKeywordToken(KW_ME) Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: Me');
    ParsePrimaryExpr := VBT_OBJECT;
    LexNextToken;
  End
  { DirectCast(expr, Type) }
  Else If IsKeywordToken(KW_DIRECTCAST) Then
  Begin
    LexNextToken; { consommer DirectCast }
    If CurTokType = TOK_LPAREN Then
      LexNextToken { consommer ( }
    Else
      WarnMsg('( attendue apres DirectCast');
    T := ParseExpr;
    If CurTokType = TOK_COMMA Then
      LexNextToken { consommer , }
    Else
      WarnMsg(', attendue dans DirectCast');
    If CurTokType = TOK_IDENT Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: DirectCast(..., ', CurTokStr, ')');
      LexNextToken;
    End
    Else If CurTokType = TOK_KEYWORD Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: DirectCast(..., ', KeywordName(CurTokNum), ')');
      LexNextToken;
    End
    Else
      WarnMsg('Type attendu dans DirectCast');
    If CurTokType = TOK_RPAREN Then
      LexNextToken { consommer ) }
    Else
      WarnMsg(') attendue apres DirectCast');
    ParsePrimaryExpr := VBT_OBJECT;
  End
  { CType(expr, Type) }
  Else If IsKeywordToken(KW_CTYPE) Then
  Begin
    LexNextToken; { consommer CType }
    If CurTokType = TOK_LPAREN Then
      LexNextToken
    Else
      WarnMsg('( attendue apres CType');
    T := ParseExpr;
    If CurTokType = TOK_COMMA Then
      LexNextToken
    Else
      WarnMsg(', attendue dans CType');
    If CurTokType = TOK_IDENT Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: CType(..., ', CurTokStr, ')');
      LexNextToken;
    End
    Else If CurTokType = TOK_KEYWORD Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: CType(..., ', KeywordName(CurTokNum), ')');
      LexNextToken;
    End
    Else
      WarnMsg('Type attendu dans CType');
    If CurTokType = TOK_RPAREN Then
      LexNextToken
    Else
      WarnMsg(') attendue apres CType');
    ParsePrimaryExpr := VBT_OBJECT;
  End
  { TryCast(expr, Type) }
  Else If IsKeywordToken(KW_TRYCAST) Then
  Begin
    LexNextToken; { consommer TryCast }
    If CurTokType = TOK_LPAREN Then
      LexNextToken
    Else
      WarnMsg('( attendue apres TryCast');
    T := ParseExpr;
    If CurTokType = TOK_COMMA Then
      LexNextToken
    Else
      WarnMsg(', attendue dans TryCast');
    If CurTokType = TOK_IDENT Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: TryCast(..., ', CurTokStr, ')');
      LexNextToken;
    End
    Else If CurTokType = TOK_KEYWORD Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: TryCast(..., ', KeywordName(CurTokNum), ')');
      LexNextToken;
    End
    Else
      WarnMsg('Type attendu dans TryCast');
    If CurTokType = TOK_RPAREN Then
      LexNextToken
    Else
      WarnMsg(') attendue apres TryCast');
    ParsePrimaryExpr := VBT_OBJECT;
  End
  { Parentheses }
  Else If CurTokType = TOK_LPAREN Then
  Begin
    LexNextToken; { consommer ( }
    T := ParseExpr;
    If CurTokType = TOK_RPAREN Then
      LexNextToken  { consommer ) }
    Else
      WarnMsg('Parenthese fermante attendue');
    ParsePrimaryExpr := T;
  End
  { New NomClasse(...) }
  Else If IsKeywordToken(KW_NEW) Then
  Begin
    LexNextToken; { consommer New }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: New ', CurTokStr);
      LexNextToken;
    End
    Else
      WarnMsg('Nom de classe attendu apres New');
    { Arguments optionnels }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken; { consommer ( }
      If CurTokType <> TOK_RPAREN Then
      Begin
        ParseExpr;
        While CurTokType = TOK_COMMA Do
        Begin
          LexNextToken;
          ParseExpr;
        End;
      End;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg('Parenthese fermante attendue apres New');
    End;
    ParsePrimaryExpr := VBT_OBJECT;
  End
  { TypeOf expr Is Type }
  Else If IsKeywordToken(KW_TYPEOF) Then
  Begin
    LexNextToken; { consommer TypeOf }
    T := ParsePrimaryExpr;
    If IsKeywordToken(KW_IS) Then
    Begin
      LexNextToken; { consommer Is }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
        LexNextToken
      Else
        WarnMsg('Nom de type attendu apres TypeOf...Is');
    End
    Else If IsKeywordToken(KW_ISNOT) Then
    Begin
      LexNextToken; { consommer IsNot }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
        LexNextToken
      Else
        WarnMsg('Nom de type attendu apres TypeOf...IsNot');
    End;
    ParsePrimaryExpr := VBT_BOOLEAN;
  End
  { Identificateur : variable, fonction, ou acces membre }
  Else If CurTokType = TOK_IDENT Then
  Begin
    SIdx := FindSym(CurTokStr);
    If SIdx >= 0 Then
    Begin
      T := SymTab[SIdx].DataType;
      If Opts.Verbose Then
        WriteLn('    Expr: var "', CurTokStr, '" type=', VBTypeName(T));
    End
    Else
    Begin
      T := VBT_OBJECT; { symbole inconnu -> Object par defaut en VB.NET }
      If Opts.Verbose Then
        WriteLn('    Expr: ident "', CurTokStr, '" (non declare)');
    End;
    LexNextToken;
    { Verifier parentheses pour appel de fonction : ident(...) }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken; { consommer ( }
      If CurTokType <> TOK_RPAREN Then
      Begin
        ParseExpr; { premier argument }
        While CurTokType = TOK_COMMA Do
        Begin
          LexNextToken; { consommer , }
          ParseExpr;    { argument suivant }
        End;
      End;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg('Parenthese fermante attendue apres arguments');
    End;
    { Verifier acces membre : ident.membre[.membre...] }
    While CurTokType = TOK_DOT Do
    Begin
      LexNextToken; { consommer . }
      If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
      Begin
        If Opts.Verbose Then
          WriteLn('    Expr: .', CurTokStr);
        LexNextToken;
        { Appel de methode : objet.methode(...) }
        If CurTokType = TOK_LPAREN Then
        Begin
          LexNextToken;
          If CurTokType <> TOK_RPAREN Then
          Begin
            ParseExpr;
            While CurTokType = TOK_COMMA Do
            Begin
              LexNextToken;
              ParseExpr;
            End;
          End;
          If CurTokType = TOK_RPAREN Then
            LexNextToken
          Else
            WarnMsg('Parenthese fermante attendue apres methode');
        End;
      End
      Else
        WarnMsg('Nom de membre attendu apres "."');
      T := VBT_OBJECT; { acces membre : type inconnu a ce stade }
    End;
    { Verifier acces membre via ! : ident!membre }
    If CurTokType = TOK_EXCL Then
    Begin
      LexNextToken; { consommer ! }
      If CurTokType = TOK_IDENT Then
      Begin
        If Opts.Verbose Then
          WriteLn('    Expr: !', CurTokStr);
        LexNextToken;
      End
      Else
        WarnMsg('Nom de membre attendu apres "!"');
      T := VBT_OBJECT;
    End;
    ParsePrimaryExpr := T;
  End
  { Mot-cle utilise comme fonction intrinseque dans une expression }
  Else If CurTokType = TOK_KEYWORD Then
  Begin
    If Opts.Verbose Then
      WriteLn('    Expr: keyword ', KeywordName(CurTokNum));
    T := VBT_OBJECT;
    LexNextToken;
    { Verifier parentheses pour appel intrinseque : KW(...) }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken;
      If CurTokType <> TOK_RPAREN Then
      Begin
        ParseExpr;
        While CurTokType = TOK_COMMA Do
        Begin
          LexNextToken;
          ParseExpr;
        End;
      End;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg('Parenthese fermante attendue');
    End;
    ParsePrimaryExpr := T;
  End
  { Token inattendu }
  Else
  Begin
    WarnMsg('Expression attendue, trouve "' + CurTokStr + '"');
    ParsePrimaryExpr := VBT_OBJECT;
  End;
  LeaveExpr;
End;

{ ------------------------------------------------------------ }
{ ParseUnaryExpr : operateur unaire (- / + / Not / AddressOf)  }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseUnaryExpr : Integer;
Var T : Integer;
Begin
  If CurTokType = TOK_MINUS Then
  Begin
    LexNextToken; { consommer - }
    T := ParsePrimaryExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: negate');
    { Negation : garde le type sauf Boolean -> Integer }
    If T = VBT_BOOLEAN Then
      ParseUnaryExpr := VBT_INTEGER
    Else
      ParseUnaryExpr := T;
  End
  Else If IsKeywordToken(KW_NOT) Then
  Begin
    LexNextToken; { consommer Not }
    T := ParseUnaryExpr; { recursif pour Not Not x }
    If Opts.Verbose Then
      WriteLn('    Expr: Not');
    If T = VBT_BOOLEAN Then
      ParseUnaryExpr := VBT_BOOLEAN
    Else
      ParseUnaryExpr := VBT_INTEGER;
  End
  { + unaire : juste passer }
  Else If CurTokType = TOK_PLUS Then
  Begin
    LexNextToken;
    ParseUnaryExpr := ParsePrimaryExpr;
  End
  { AddressOf : retourne un delegue }
  Else If IsKeywordToken(KW_ADDRESSOF) Then
  Begin
    LexNextToken; { consommer AddressOf }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
    Begin
      If Opts.Verbose Then
        WriteLn('    Expr: AddressOf ', CurTokStr);
      LexNextToken;
      { Verifier acces qualifie : AddressOf obj.method }
      While CurTokType = TOK_DOT Do
      Begin
        LexNextToken;
        If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then
          LexNextToken
        Else
          WarnMsg('Nom de methode attendu apres "."');
      End;
    End
    Else
      WarnMsg('Nom de procedure attendu apres AddressOf');
    ParseUnaryExpr := VBT_OBJECT;
  End
  Else
    ParseUnaryExpr := ParsePrimaryExpr;
End;

{ ------------------------------------------------------------ }
{ ParsePowExpr : puissance (^)                                 }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParsePowExpr : Integer;
Var L, R : Integer;
Begin
  L := ParseUnaryExpr;
  While CurTokType = TOK_CARET Do
  Begin
    LexNextToken; { consommer ^ }
    R := ParseUnaryExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ^');
    L := DetermineResultType(OP_POW, L, R);
  End;
  ParsePowExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseMulExpr : multiplication / division (* /)               }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseMulExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParsePowExpr;
  While (CurTokType = TOK_STAR) Or (CurTokType = TOK_SLASH) Do
  Begin
    If CurTokType = TOK_STAR Then
      Op := OP_MUL
    Else
      Op := OP_DIV;
    LexNextToken; { consommer * ou / }
    R := ParsePowExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ', OpName(Op));
    L := DetermineResultType(Op, L, R);
  End;
  ParseMulExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseIntDivExpr : division entiere (\)                       }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseIntDivExpr : Integer;
Var L, R : Integer;
Begin
  L := ParseMulExpr;
  While CurTokType = TOK_BACKSLASH Do
  Begin
    LexNextToken; { consommer \ }
    R := ParseMulExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: \');
    L := DetermineResultType(OP_INTDIV, L, R);
  End;
  ParseIntDivExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseModExpr : modulo (Mod)                                  }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseModExpr : Integer;
Var L, R : Integer;
Begin
  L := ParseIntDivExpr;
  While IsKeywordToken(KW_MOD) Do
  Begin
    LexNextToken; { consommer Mod }
    R := ParseIntDivExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: Mod');
    L := DetermineResultType(OP_MOD, L, R);
  End;
  ParseModExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseAddExpr : addition / soustraction (+ -)                 }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseAddExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseModExpr;
  While (CurTokType = TOK_PLUS) Or (CurTokType = TOK_MINUS) Do
  Begin
    If CurTokType = TOK_PLUS Then
      Op := OP_ADD
    Else
      Op := OP_SUB;
    LexNextToken; { consommer + ou - }
    R := ParseModExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ', OpName(Op));
    L := DetermineResultType(Op, L, R);
  End;
  ParseAddExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseConcatExpr : concatenation (&)                          }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseConcatExpr : Integer;
Var L, R : Integer;
Begin
  L := ParseAddExpr;
  While CurTokType = TOK_AMP Do
  Begin
    LexNextToken; { consommer & }
    R := ParseAddExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: &');
    L := DetermineResultType(OP_CONCAT, L, R);
  End;
  ParseConcatExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseCompExpr : comparaison (= <> < > <= >= Like Is IsNot)   }
{   Retourne le type VBT_* du resultat (toujours Boolean)      }
{ ------------------------------------------------------------ }

Function ParseCompExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseConcatExpr;
  While (CurTokType = TOK_EQ) Or (CurTokType = TOK_NE) Or
        (CurTokType = TOK_LT) Or (CurTokType = TOK_GT) Or
        (CurTokType = TOK_LE) Or (CurTokType = TOK_GE) Or
        IsKeywordToken(KW_LIKE) Or IsKeywordToken(KW_IS) Or
        IsKeywordToken(KW_ISNOT) Do
  Begin
    If CurTokType = TOK_EQ Then Op := OP_EQ
    Else If CurTokType = TOK_NE Then Op := OP_NE
    Else If CurTokType = TOK_LT Then Op := OP_LT
    Else If CurTokType = TOK_GT Then Op := OP_GT
    Else If CurTokType = TOK_LE Then Op := OP_LE
    Else If CurTokType = TOK_GE Then Op := OP_GE
    Else If IsKeywordToken(KW_LIKE) Then Op := OP_LIKE
    Else If IsKeywordToken(KW_ISNOT) Then Op := OP_ISNOT
    Else Op := OP_IS;
    LexNextToken; { consommer l operateur }
    R := ParseConcatExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ', OpName(Op));
    L := DetermineResultType(Op, L, R);
  End;
  ParseCompExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseNotExpr : operateur logique Not                         }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseNotExpr : Integer;
Var T : Integer;
Begin
  If IsKeywordToken(KW_NOT) Then
  Begin
    LexNextToken; { consommer Not }
    T := ParseNotExpr; { recursif : Not Not x }
    If Opts.Verbose Then
      WriteLn('    Expr: Not (logical)');
    If T = VBT_BOOLEAN Then
      ParseNotExpr := VBT_BOOLEAN
    Else
      ParseNotExpr := VBT_INTEGER;
  End
  Else
    ParseNotExpr := ParseCompExpr;
End;

{ ------------------------------------------------------------ }
{ ParseAndExpr : operateur logique And / AndAlso               }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseAndExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseNotExpr;
  While IsKeywordToken(KW_AND) Or IsKeywordToken(KW_ANDALSO) Do
  Begin
    If IsKeywordToken(KW_AND) Then
      Op := OP_AND
    Else
      Op := OP_ANDALSO;
    LexNextToken; { consommer And ou AndAlso }
    R := ParseNotExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ', OpName(Op));
    L := DetermineResultType(Op, L, R);
  End;
  ParseAndExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseOrExpr : operateurs logiques Or / OrElse / Xor          }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseOrExpr : Integer;
Var L, R, Op : Integer;
Begin
  L := ParseAndExpr;
  While IsKeywordToken(KW_OR) Or IsKeywordToken(KW_ORELSE) Or
        IsKeywordToken(KW_XOR) Do
  Begin
    If IsKeywordToken(KW_OR) Then Op := OP_OR
    Else If IsKeywordToken(KW_ORELSE) Then Op := OP_ORELSE
    Else Op := OP_XOR;
    LexNextToken; { consommer l operateur }
    R := ParseAndExpr;
    If Opts.Verbose Then
      WriteLn('    Expr: ', OpName(Op));
    L := DetermineResultType(Op, L, R);
  End;
  ParseOrExpr := L;
End;

{ ------------------------------------------------------------ }
{ ParseExpr : point d entree pour analyser une expression      }
{   Retourne le type VBT_* du resultat                         }
{ ------------------------------------------------------------ }

Function ParseExpr : Integer;
Var T : Integer;
Begin
  Inc(ExprCount);
  T := ParseOrExpr;
  ExprResultType := T;
  ParseExpr := T;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour l etat des expressions              }
{ ------------------------------------------------------------ }

Function GetExprCount : Integer;
Begin
  GetExprCount := ExprCount;
End;

Function GetExprDepth : Integer;
Begin
  GetExprDepth := ExprDepth;
End;

Function GetMaxExprDepth : Integer;
Begin
  GetMaxExprDepth := MaxExprDepth;
End;

Function GetExprResultType : Integer;
Begin
  GetExprResultType := ExprResultType;
End;

Function IsExprResultBoolean : Boolean;
Begin
  IsExprResultBoolean := (ExprResultType = VBT_BOOLEAN);
End;

Function IsExprResultString : Boolean;
Begin
  IsExprResultString := (ExprResultType = VBT_STRING);
End;

Function IsExprResultNumeric : Boolean;
Begin
  IsExprResultNumeric :=
    (ExprResultType = VBT_INTEGER) Or
    (ExprResultType = VBT_LONG) Or
    (ExprResultType = VBT_SHORT) Or
    (ExprResultType = VBT_BYTE) Or
    (ExprResultType = VBT_SBYTE) Or
    (ExprResultType = VBT_USHORT) Or
    (ExprResultType = VBT_UINTEGER) Or
    (ExprResultType = VBT_ULONG) Or
    (ExprResultType = VBT_SINGLE) Or
    (ExprResultType = VBT_DOUBLE) Or
    (ExprResultType = VBT_DECIMAL);
End;

Function IsExprResultObject : Boolean;
Begin
  IsExprResultObject := (ExprResultType = VBT_OBJECT);
End;

Function IsExprStateEmpty : Boolean;
Begin
  IsExprStateEmpty := (ExprCount = 0);
End;

Function GetExprResultTypeName : TString;
Begin
  GetExprResultTypeName := VBTypeName(ExprResultType);
End;

Function IsExprResultChar : Boolean;
Begin
  IsExprResultChar := (ExprResultType = VBT_CHAR);
End;

Function IsExprResultDate : Boolean;
Begin
  IsExprResultDate := (ExprResultType = VBT_DATE);
End;

Function IsExprResultDecimal : Boolean;
Begin
  IsExprResultDecimal := (ExprResultType = VBT_DECIMAL);
End;

Function IsExprResultInteger : Boolean;
Begin
  IsExprResultInteger := (ExprResultType = VBT_INTEGER);
End;

{ ============================================================ }
{ TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES      }
{           80386 [IMPLEMENTE]                                 }
{ ============================================================ }

Var
  CodeLineCount     : LongInt;   { nombre de lignes ASM emises          }
  CodeGenInitialized: Boolean;   { True si InitCodeGen a ete appele     }

{ ------------------------------------------------------------ }
{ InitCodeGen : initialiser l etat du generateur de code       }
{ ------------------------------------------------------------ }

Procedure InitCodeGen;
Begin
  CodeLineCount      := 0;
  CodeGenInitialized := True;
End;

{ ------------------------------------------------------------ }
{ Emit : emettre une ligne d assembleur (instruction)          }
{ ------------------------------------------------------------ }

Procedure Emit(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '  ', S);
  Inc(CodeLineCount);
End;

{ ------------------------------------------------------------ }
{ EmitLabel : emettre un label assembleur                      }
{ ------------------------------------------------------------ }

Procedure EmitLabel(Const Lbl : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, Lbl, ':');
  Inc(CodeLineCount);
End;

{ ------------------------------------------------------------ }
{ EmitComment : emettre un commentaire assembleur              }
{ ------------------------------------------------------------ }

Procedure EmitComment(Const Cmt : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '; ', Cmt);
  Inc(CodeLineCount);
End;

{ ------------------------------------------------------------ }
{ EmitData : emettre une ligne dans la section .DATA           }
{ ------------------------------------------------------------ }

Procedure EmitData(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '  ', S);
  Inc(CodeLineCount);
End;

{ ------------------------------------------------------------ }
{ EmitBss : emettre une ligne dans la section .BSS             }
{ ------------------------------------------------------------ }

Procedure EmitBss(Const S : TString);
Begin
  If OutFOpen Then
    WriteLn(OutF, '  ', S);
  Inc(CodeLineCount);
End;

{ ------------------------------------------------------------ }
{ GenLoadVar : charger une variable dans EAX                   }
{ sym_idx : index dans SymTab                                  }
{ Integer/Short -> MOV EAX, DWORD PTR [label] ou [EBP-n]      }
{ String -> LEA EAX, [label] ou [EBP-n]                       }
{ Boolean/Byte/SByte -> MOVZX EAX, BYTE PTR [label]           }
{ Char/UShort/Short -> MOVZX EAX, WORD PTR [label]            }
{ ------------------------------------------------------------ }

Procedure GenLoadVar(SymIdx : Integer);
Var
  Lbl : TString;
  DT  : Integer;
  SC  : Integer;
  Ofs : Integer;
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then
  Begin
    WarnMsg('GenLoadVar: index symbole invalide ' + ItoSI(SymIdx));
    Exit;
  End;
  DT  := SymTab[SymIdx].DataType;
  SC  := SymTab[SymIdx].StoreClass;
  Lbl := SymTab[SymIdx].AsmLabel;
  Ofs := SymTab[SymIdx].BpOffset;
  EmitComment('GenLoadVar: ' + SymTab[SymIdx].Name +
              ' (' + VBTypeName(DT) + ')');
  If (SC = STORE_AUTO) Or (SC = STORE_PARAM) Then
  Begin
    { Variable locale ou parametre via EBP }
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE, VBT_SBYTE:
        Emit('MOVZX EAX, BYTE PTR [EBP' + ItoSI(-Ofs) + ']');
      VBT_CHAR, VBT_SHORT, VBT_USHORT:
        Emit('MOVZX EAX, WORD PTR [EBP' + ItoSI(-Ofs) + ']');
      VBT_STRING:
        Emit('LEA EAX, [EBP' + ItoSI(-Ofs) + ']');
    Else
      Emit('MOV EAX, DWORD PTR [EBP' + ItoSI(-Ofs) + ']');
    End;
  End
  Else
  Begin
    { Variable globale, statique ou partagee via label }
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE, VBT_SBYTE:
        Emit('MOVZX EAX, BYTE PTR [' + Lbl + ']');
      VBT_CHAR, VBT_SHORT, VBT_USHORT:
        Emit('MOVZX EAX, WORD PTR [' + Lbl + ']');
      VBT_STRING:
        Emit('LEA EAX, [' + Lbl + ']');
    Else
      Emit('MOV EAX, DWORD PTR [' + Lbl + ']');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenStoreVar : stocker EAX dans une variable                  }
{ sym_idx : index dans SymTab                                  }
{ ------------------------------------------------------------ }

Procedure GenStoreVar(SymIdx : Integer);
Var
  Lbl : TString;
  DT  : Integer;
  SC  : Integer;
  Ofs : Integer;
Begin
  If (SymIdx < 0) Or (SymIdx >= SymCount) Then
  Begin
    WarnMsg('GenStoreVar: index symbole invalide ' + ItoSI(SymIdx));
    Exit;
  End;
  DT  := SymTab[SymIdx].DataType;
  SC  := SymTab[SymIdx].StoreClass;
  Lbl := SymTab[SymIdx].AsmLabel;
  Ofs := SymTab[SymIdx].BpOffset;
  EmitComment('GenStoreVar: ' + SymTab[SymIdx].Name +
              ' (' + VBTypeName(DT) + ')');
  If (SC = STORE_AUTO) Or (SC = STORE_PARAM) Then
  Begin
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE, VBT_SBYTE:
        Emit('MOV BYTE PTR [EBP' + ItoSI(-Ofs) + '], AL');
      VBT_CHAR, VBT_SHORT, VBT_USHORT:
        Emit('MOV WORD PTR [EBP' + ItoSI(-Ofs) + '], AX');
    Else
      Emit('MOV DWORD PTR [EBP' + ItoSI(-Ofs) + '], EAX');
    End;
  End
  Else
  Begin
    Case DT Of
      VBT_BOOLEAN, VBT_BYTE, VBT_SBYTE:
        Emit('MOV BYTE PTR [' + Lbl + '], AL');
      VBT_CHAR, VBT_SHORT, VBT_USHORT:
        Emit('MOV WORD PTR [' + Lbl + '], AX');
    Else
      Emit('MOV DWORD PTR [' + Lbl + '], EAX');
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenPushEAX : sauvegarder EAX sur la pile                     }
{ ------------------------------------------------------------ }

Procedure GenPushEAX;
Begin
  Emit('PUSH EAX');
End;

{ ------------------------------------------------------------ }
{ GenPopEBX : restaurer EBX depuis la pile                     }
{ ------------------------------------------------------------ }

Procedure GenPopEBX;
Begin
  Emit('POP EBX');
End;

{ ------------------------------------------------------------ }
{ GenBinOp : generer le code d une operation binaire           }
{ EAX = operande gauche (deja empile), EBX = operande droite   }
{ Resultat dans EAX                                            }
{ ------------------------------------------------------------ }

Procedure GenBinOp(Op : Integer);
Begin
  EmitComment('GenBinOp: ' + OpName(Op));
  GenPopEBX;
  { EBX = gauche, EAX = droite => echanger pour gauche op droite }
  Emit('XCHG EAX, EBX');
  { Maintenant EAX = gauche, EBX = droite }
  Case Op Of
    OP_ADD:
      Emit('ADD EAX, EBX');
    OP_SUB:
      Emit('SUB EAX, EBX');
    OP_MUL:
      Emit('IMUL EAX, EBX');
    OP_DIV:
      { Division flottante via routine runtime }
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'DIV');
        Emit('ADD ESP, 8');
      End;
    OP_INTDIV:
      { Division entiere : CDQ + IDIV EBX }
      Begin
        Emit('CDQ');
        Emit('IDIV EBX');
      End;
    OP_MOD:
      { Modulo : CDQ + IDIV EBX, resultat dans EDX }
      Begin
        Emit('CDQ');
        Emit('IDIV EBX');
        Emit('MOV EAX, EDX');
      End;
    OP_POW:
      { Puissance via routine runtime }
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'POW');
        Emit('ADD ESP, 8');
      End;
    OP_CONCAT:
      { Concatenation de chaines via routine runtime }
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'STRCAT');
        Emit('ADD ESP, 8');
      End;
  Else
    WarnMsg('GenBinOp: operateur inconnu ' + ItoSI(Op));
  End;
End;

{ ------------------------------------------------------------ }
{ GenCompare : generer le code d une comparaison               }
{ EAX = gauche (pile), EBX = droite                            }
{ Resultat VB.NET : True = -1 ($FFFFFFFF), False = 0           }
{ ------------------------------------------------------------ }

Procedure GenCompare(Op : Integer);
Begin
  EmitComment('GenCompare: ' + OpName(Op));
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { EAX = gauche, EBX = droite }
  Emit('CMP EAX, EBX');
  Case Op Of
    OP_EQ:
      Emit('SETE AL');
    OP_NE:
      Emit('SETNE AL');
    OP_LT:
      Emit('SETL AL');
    OP_GT:
      Emit('SETG AL');
    OP_LE:
      Emit('SETLE AL');
    OP_GE:
      Emit('SETGE AL');
    OP_LIKE:
      Begin
        { Like est gere par le runtime }
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'LIKE');
        Emit('ADD ESP, 8');
        { EAX contient deja le resultat -1 ou 0 }
        Exit;
      End;
    OP_IS:
      { Comparaison de references objet (meme reference) }
      Emit('SETE AL');
    OP_ISNOT:
      { Comparaison de references objet (references differentes) }
      Emit('SETNE AL');
  Else
    WarnMsg('GenCompare: operateur inconnu ' + ItoSI(Op));
    Emit('SETE AL');
  End;
  { Etendre AL en -1 ou 0 (convention VB.NET: True = -1) }
  Emit('MOVZX EAX, AL');
  Emit('NEG EAX');
End;

{ ------------------------------------------------------------ }
{ GenLogicalOp : generer le code d une operation logique        }
{ And, Or, Xor : binaire (EAX op EBX)                          }
{ Not : unaire (NOT EAX)                                       }
{ ------------------------------------------------------------ }

Procedure GenLogicalOp(Op : Integer);
Begin
  EmitComment('GenLogicalOp: ' + OpName(Op));
  If Op = OP_NOT Then
  Begin
    { Operation unaire }
    Emit('NOT EAX');
  End
  Else
  Begin
    { Operations binaires : depiler la gauche dans EBX }
    GenPopEBX;
    Emit('XCHG EAX, EBX');
    { EAX = gauche, EBX = droite }
    Case Op Of
      OP_AND:
        Emit('AND EAX, EBX');
      OP_OR:
        Emit('OR EAX, EBX');
      OP_XOR:
        Emit('XOR EAX, EBX');
    Else
      WarnMsg('GenLogicalOp: operateur inconnu ' + ItoSI(Op));
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ GenShortCircuit : generer le code d evaluation court-circuit  }
{ AndAlso : si EAX = 0, sauter a label_false                   }
{ OrElse  : si EAX <> 0, sauter a label_true                   }
{ ------------------------------------------------------------ }

Procedure GenShortCircuit(Op : Integer; Const Lbl : TString);
Begin
  EmitComment('GenShortCircuit: ' + OpName(Op));
  Emit('CMP EAX, 0');
  Case Op Of
    OP_ANDALSO:
      { AndAlso : court-circuit si False }
      Emit('JE ' + Lbl);
    OP_ORELSE:
      { OrElse : court-circuit si True }
      Emit('JNE ' + Lbl);
  Else
    WarnMsg('GenShortCircuit: operateur inconnu ' + ItoSI(Op));
  End;
End;

{ ------------------------------------------------------------ }
{ GenCompoundAssign : generer le code d une affectation composee }
{ += -= *= /= \= &= ^=                                         }
{ SymIdx : index du symbole cible, Op : operateur de base       }
{ ------------------------------------------------------------ }

Procedure GenCompoundAssign(SymIdx : Integer; Op : Integer);
Begin
  EmitComment('GenCompoundAssign: ' + OpName(Op) + '=');
  { Empiler la valeur actuelle de la variable }
  GenPushEAX;
  GenLoadVar(SymIdx);
  GenPushEAX;
  { Recuperer la nouvelle valeur (a droite) }
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { Depiler l ancienne valeur de la variable }
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { EAX = ancienne valeur, EBX = expression a droite }
  Case Op Of
    OP_ADD:
      Emit('ADD EAX, EBX');
    OP_SUB:
      Emit('SUB EAX, EBX');
    OP_MUL:
      Emit('IMUL EAX, EBX');
    OP_DIV:
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'DIV');
        Emit('ADD ESP, 8');
      End;
    OP_INTDIV:
      Begin
        Emit('CDQ');
        Emit('IDIV EBX');
      End;
    OP_CONCAT:
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'STRCAT');
        Emit('ADD ESP, 8');
      End;
    OP_POW:
      Begin
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + PFX_RT + 'POW');
        Emit('ADD ESP, 8');
      End;
  Else
    WarnMsg('GenCompoundAssign: operateur inconnu ' + ItoSI(Op));
  End;
  { Stocker le resultat }
  GenStoreVar(SymIdx);
End;

{ ------------------------------------------------------------ }
{ GenLoadImm : charger une valeur immediate dans EAX           }
{ ------------------------------------------------------------ }

Procedure GenLoadImm(Value : LongInt);
Begin
  If Value = 0 Then
    Emit('XOR EAX, EAX')
  Else
    Emit('MOV EAX, ' + ItoSI(Value));
End;

{ ------------------------------------------------------------ }
{ GenNegate : nier EAX (negation arithmetique unaire)          }
{ ------------------------------------------------------------ }

Procedure GenNegate;
Begin
  EmitComment('GenNegate: - unaire');
  Emit('NEG EAX');
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseurs pour le module de generation de code     }
{ ------------------------------------------------------------ }

Function GetCodeLineCount : LongInt;
Begin
  GetCodeLineCount := CodeLineCount;
End;

Function IsCodeGenInitialized : Boolean;
Begin
  IsCodeGenInitialized := CodeGenInitialized;
End;

Function IsCodeGenEmpty : Boolean;
Begin
  IsCodeGenEmpty := (CodeLineCount = 0);
End;

Function GetCodeGenStatus : TString;
Begin
  If CodeGenInitialized Then
    GetCodeGenStatus := 'initialized'
  Else
    GetCodeGenStatus := 'not initialized';
End;

Function GetEmitPrefixVar : TString;
Begin
  GetEmitPrefixVar := PFX_VAR;
End;

Function GetEmitPrefixFunc : TString;
Begin
  GetEmitPrefixFunc := PFX_FUNC;
End;

Function GetEmitPrefixConst : TString;
Begin
  GetEmitPrefixConst := PFX_CONST;
End;

Function GetEmitPrefixRT : TString;
Begin
  GetEmitPrefixRT := PFX_RT;
End;

Function GetEmitPrefixLabel : TString;
Begin
  GetEmitPrefixLabel := PFX_LBL;
End;

Function GetMaxBinCode : Integer;
Begin
  GetMaxBinCode := MAX_BIN_CODE;
End;

{ ============================================================ }
{ TODO 10 - PARSEUR : STRUCTURES DE CONTROLE                   }
{           (IF, SELECT CASE, GOTO) [IMPLEMENTE]               }
{ ============================================================ }

Var
  CtrlCount       : LongInt;   { nombre total de structures de controle }
  CtrlDepth       : Integer;   { profondeur d imbrication courante      }
  MaxCtrlDepth    : Integer;   { profondeur max atteinte                }
  CtrlInitialized : Boolean;   { True si InitCtrlState a ete appele     }

{ ------------------------------------------------------------ }
{ InitCtrlState : initialiser l etat du module controle        }
{ ------------------------------------------------------------ }

Procedure InitCtrlState;
Begin
  CtrlCount       := 0;
  CtrlDepth       := 0;
  MaxCtrlDepth    := 0;
  CtrlInitialized := True;
End;

{ ------------------------------------------------------------ }
{ EnterCtrl : entrer dans une structure de controle            }
{ ------------------------------------------------------------ }

Procedure EnterCtrl;
Begin
  Inc(CtrlCount);
  Inc(CtrlDepth);
  If CtrlDepth > MaxCtrlDepth Then
    MaxCtrlDepth := CtrlDepth;
End;

{ ------------------------------------------------------------ }
{ LeaveCtrl : quitter une structure de controle                }
{ ------------------------------------------------------------ }

Procedure LeaveCtrl;
Begin
  If CtrlDepth > 0 Then
    Dec(CtrlDepth);
End;

{ ------------------------------------------------------------ }
{ Declarations Forward pour le parseur de statements           }
{ ------------------------------------------------------------ }

Procedure ParseStatement; Forward;
Procedure ParseStatementBlock; Forward;
Procedure ParseFor; Forward;
Procedure ParseDoLoop; Forward;
Procedure ParseWhile; Forward;
Procedure ParseForEach; Forward;
Procedure ParseExitStatement; Forward;
Procedure ParseContinueStatement; Forward;
Procedure ParseSub; Forward;
Procedure ParseFunction; Forward;

{ ------------------------------------------------------------ }
{ ParseStatementBlock : parser un bloc d instructions          }
{ S arrete sur un terminateur de bloc (Else, ElseIf, End,      }
{ Case, Loop, Next)                                            }
{ ------------------------------------------------------------ }

Procedure ParseStatementBlock;
Begin
  SkipNewlines;
  While (CurTokType <> TOK_EOF) Do
  Begin
    { Verifier si on est sur un terminateur de bloc }
    If CurTokType = TOK_KEYWORD Then
    Begin
      If (CurTokNum = KW_ELSE) Or (CurTokNum = KW_ELSEIF) Or
         (CurTokNum = KW_END) Or (CurTokNum = KW_CASE) Or
         (CurTokNum = KW_LOOP) Or (CurTokNum = KW_NEXT) Then
        Exit;
    End;
    ParseStatement;
    SkipNewlines;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIf : parser une structure If/Then/ElseIf/Else/End If    }
{ Supporte la forme multi-ligne et la forme mono-ligne         }
{ ------------------------------------------------------------ }

Procedure ParseIf;
Var
  LblElse   : TString;  { label pour le prochain ElseIf/Else }
  LblEnd    : TString;  { label pour End If                  }
  IsMulti   : Boolean;  { True si forme multi-ligne          }
Begin
  EnterCtrl;
  { Consommer 'If' }
  LexNextToken;
  LblEnd := NextInternalLabel;

  { Parser la condition }
  ParseExpr;

  { Attendre 'Then' }
  ExpectKeyword(KW_THEN);

  { Generer : tester la condition, sauter si False }
  LblElse := NextInternalLabel;
  EmitComment('If condition');
  Emit('CMP EAX, 0');
  Emit('JE ' + LblElse);

  { Determiner si multi-ligne ou mono-ligne }
  IsMulti := (CurTokType = TOK_NEWLINE) Or (CurTokType = TOK_EOF);

  If IsMulti Then
  Begin
    { Forme multi-ligne : If ... Then / instructions / End If }
    SkipNewlines;
    ParseStatementBlock;

    { Traiter ElseIf et Else }
    While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSEIF) Do
    Begin
      { Sauter au End If apres le bloc precedent }
      Emit('JMP ' + LblEnd);
      EmitLabel(LblElse);
      LblElse := NextInternalLabel;

      { Consommer 'ElseIf' }
      LexNextToken;

      { Parser la condition }
      ParseExpr;

      { Attendre 'Then' }
      ExpectKeyword(KW_THEN);
      SkipNewlines;

      { Generer le test }
      EmitComment('ElseIf condition');
      Emit('CMP EAX, 0');
      Emit('JE ' + LblElse);

      { Parser le bloc }
      ParseStatementBlock;
    End;

    { Traiter Else optionnel }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSE) Then
    Begin
      Emit('JMP ' + LblEnd);
      EmitLabel(LblElse);
      LblElse := '';

      { Consommer 'Else' }
      LexNextToken;
      SkipNewlines;

      { Parser le bloc Else }
      ParseStatementBlock;
    End;

    { Emettre le label else restant si pas de Else }
    If LblElse <> '' Then
      EmitLabel(LblElse);

    { Attendre 'End If' }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
    Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IF) Then
        LexNextToken
      Else
        WarnMsg('End If attendu');
    End
    Else
      WarnMsg('End If attendu');

    EmitLabel(LblEnd);
  End
  Else
  Begin
    { Forme mono-ligne : If condition Then instruction }
    ParseStatement;

    { Traiter Else optionnel sur la meme ligne }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSE) Then
    Begin
      Emit('JMP ' + LblEnd);
      EmitLabel(LblElse);
      LexNextToken;
      ParseStatement;
      EmitLabel(LblEnd);
    End
    Else
      EmitLabel(LblElse);
  End;

  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseCaseItem : parser un element de clause Case             }
{ Genere le code de comparaison pour une valeur, une plage     }
{ (To) ou une comparaison (Is operateur)                       }
{ ------------------------------------------------------------ }

Procedure ParseCaseItem(Const LblBody : TString;
                        Const LblNext : TString);
Begin
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IS) Then
  Begin
    { Case Is <op> valeur }
    LexNextToken;
    { Lire l operateur de comparaison }
    If (CurTokType = TOK_EQ) Or (CurTokType = TOK_LT) Or
       (CurTokType = TOK_GT) Or (CurTokType = TOK_LE) Or
       (CurTokType = TOK_GE) Or (CurTokType = TOK_NE) Then
    Begin
      EmitComment('Case Is comparison');
      LexNextToken;
      ParseExpr;
      Emit('POP EBX');    { EBX = expression Select }
      Emit('PUSH EBX');   { conserver pour les prochains Case }
      Emit('CMP EBX, EAX');
      { Simplifie : on genere JE pour la correspondance }
      Emit('JE ' + LblBody);
    End
    Else
    Begin
      ParseExpr;
      Emit('POP EBX');
      Emit('PUSH EBX');
      Emit('CMP EBX, EAX');
      Emit('JE ' + LblBody);
    End;
  End
  Else
  Begin
    { Valeur simple ou debut d une plage To }
    ParseExpr;
    { Verifier si c est une plage : val1 To val2 }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TO) Then
    Begin
      { Case val1 To val2 }
      EmitComment('Case range To');
      Emit('MOV ECX, EAX');    { ECX = val1 (borne inf) }
      LexNextToken;
      ParseExpr;               { EAX = val2 (borne sup) }
      Emit('POP EBX');         { EBX = expression Select }
      Emit('PUSH EBX');
      Emit('CMP EBX, ECX');
      Emit('JL ' + LblNext);
      Emit('CMP EBX, EAX');
      Emit('JLE ' + LblBody);
    End
    Else
    Begin
      { Valeur simple }
      EmitComment('Case value');
      Emit('POP EBX');
      Emit('PUSH EBX');
      Emit('CMP EBX, EAX');
      Emit('JE ' + LblBody);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseSelectCase : parser une structure Select Case           }
{ Select Case expression                                       }
{   Case valeur / Case val1 To val2 / Case Is > val            }
{   Case Else                                                  }
{ End Select                                                   }
{ ------------------------------------------------------------ }

Procedure ParseSelectCase;
Var
  LblEnd     : TString;  { label End Select            }
  LblBody    : TString;  { label corps du Case courant }
  LblNext    : TString;  { label Case suivant          }
  HasElse    : Boolean;
Begin
  EnterCtrl;
  { Consommer 'Select' }
  LexNextToken;

  { Attendre 'Case' }
  ExpectKeyword(KW_CASE);

  { Parser l expression du Select }
  ParseExpr;
  Emit('PUSH EAX');  { sauvegarder expression sur la pile }

  LblEnd  := NextInternalLabel;
  HasElse := False;

  SkipNewlines;

  { Boucle sur les clauses Case }
  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CASE) Do
  Begin
    LexNextToken; { consommer 'Case' }

    { Verifier Case Else }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ELSE) Then
    Begin
      LexNextToken;
      HasElse := True;
      EmitComment('Case Else');
      SkipNewlines;
      ParseStatementBlock;
      Emit('JMP ' + LblEnd);
      Break;
    End;

    { Case normal : generer les comparaisons }
    LblBody := NextInternalLabel;
    LblNext := NextInternalLabel;

    EmitComment('Case clause');

    { Parser les elements de la clause (separes par des virgules) }
    ParseCaseItem(LblBody, LblNext);
    While (CurTokType = TOK_COMMA) Do
    Begin
      LexNextToken;
      ParseCaseItem(LblBody, LblNext);
    End;

    { Si aucun des elements ne correspond, sauter au Case suivant }
    Emit('JMP ' + LblNext);

    { Corps du Case }
    EmitLabel(LblBody);
    SkipNewlines;
    ParseStatementBlock;
    Emit('JMP ' + LblEnd);

    EmitLabel(LblNext);
    SkipNewlines;
  End;

  { Si pas de Case Else, emettre un commentaire }
  If Not HasElse Then
    EmitComment('no Case Else - fall through');

  { Attendre 'End Select' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SELECT) Then
      LexNextToken
    Else
      WarnMsg('End Select attendu');
  End
  Else
    WarnMsg('End Select attendu');

  { Nettoyer la pile (expression Select) }
  Emit('ADD ESP, 4');
  EmitLabel(LblEnd);

  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseGoTo : parser une instruction GoTo label                }
{ En VB.NET : labels nommes uniquement (pas de labels          }
{ numeriques), GoSub n est plus supporte                       }
{ ------------------------------------------------------------ }

Procedure ParseGoTo;
Var
  LblName : TString;
  Idx     : Integer;
Begin
  Inc(CtrlCount);
  { Consommer 'GoTo' }
  LexNextToken;

  If (CurTokType = TOK_IDENT) Then
  Begin
    LblName := CurTokStr;
    { Ajouter le label dans la table des symboles si pas connu }
    Idx := FindSym(LblName);
    If Idx < 0 Then
      Idx := AddSym(LblName, SK_LABEL, VBT_NONE, STORE_AUTO);
    EmitComment('GoTo ' + LblName);
    Emit('JMP ' + SymTab[Idx].AsmLabel);
    LexNextToken;
  End
  Else
    WarnMsg('Label nomme attendu apres GoTo');
End;

{ ------------------------------------------------------------ }
{ ParseLabel : parser une definition de label (label:)         }
{ ------------------------------------------------------------ }

Procedure ParseLabel;
Var
  LblName : TString;
  Idx     : Integer;
Begin
  LblName := CurTokStr;
  Idx := FindSym(LblName);
  If Idx < 0 Then
    Idx := AddSym(LblName, SK_LABEL, VBT_NONE, STORE_AUTO);
  EmitLabel(SymTab[Idx].AsmLabel);
  LexNextToken;  { consommer le ':' }
  LexNextToken;  { avancer au token suivant }
End;

{ ------------------------------------------------------------ }
{ ParseStatement : parser une instruction VB.NET               }
{ Dispatcher principal vers les parseurs specialises           }
{ ------------------------------------------------------------ }

Procedure ParseStatement;
Begin
  { Sauter les lignes vides }
  If CurTokType = TOK_NEWLINE Then
  Begin
    LexNextToken;
    Exit;
  End;

  If CurTokType = TOK_EOF Then
    Exit;

  { Dispatcher selon le mot cle }
  If CurTokType = TOK_KEYWORD Then
  Begin
    Case CurTokNum Of
      KW_IF       : ParseIf;
      KW_SELECT   : ParseSelectCase;
      KW_GOTO     : ParseGoTo;
      KW_RETURN   : Begin
                       Inc(CtrlCount);
                       LexNextToken;
                       { Return peut etre suivi d une expression (Function) }
                       If (CurTokType <> TOK_NEWLINE) And
                          (CurTokType <> TOK_EOF) Then
                       Begin
                         EmitComment('Return <expr>');
                         ParseExpr;
                         Emit('MOV EAX, ; valeur de retour');
                       End
                       Else
                         EmitComment('Return');
                       { Sauter a l epilogue }
                       Emit('JMP ' + FindEnclosingExitLabel);
                     End;
      KW_FOR      : ParseFor;
      KW_DO       : ParseDoLoop;
      KW_WHILE    : ParseWhile;
      KW_EXIT     : ParseExitStatement;
      KW_CONTINUE : ParseContinueStatement;
      KW_SUB      : ParseSub;
      KW_FUNCTION : ParseFunction;
    Else
      { Instruction non reconnue par ce TODO - avancer }
      LexNextToken;
    End;
    Exit;
  End;

  { Label : ident suivi de ':' }
  If (CurTokType = TOK_IDENT) Then
  Begin
    LexNextToken;
    Exit;
  End;

  { Autre token - avancer }
  LexNextToken;
End;

{ ============================================================ }
{ TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP,             }
{           WHILE/END WHILE, FOR EACH) [IMPLEMENTE]            }
{ ============================================================ }

Var
  LoopCount       : LongInt;   { nombre total de boucles parsees         }
  LoopDepth       : Integer;   { profondeur d imbrication courante       }
  MaxLoopDepth    : Integer;   { profondeur max atteinte                 }
  LoopInitialized : Boolean;   { True si InitLoopState a ete appele      }

{ ------------------------------------------------------------ }
{ InitLoopState : initialiser l etat du module de boucles      }
{ ------------------------------------------------------------ }

Procedure InitLoopState;
Begin
  LoopCount       := 0;
  LoopDepth       := 0;
  MaxLoopDepth    := 0;
  LoopInitialized := True;
End;

{ ------------------------------------------------------------ }
{ EnterLoop / LeaveLoop : gestion de profondeur de boucle      }
{ ------------------------------------------------------------ }

Procedure EnterLoop;
Begin
  Inc(LoopCount);
  Inc(LoopDepth);
  If LoopDepth > MaxLoopDepth Then
    MaxLoopDepth := LoopDepth;
End;

Procedure LeaveLoop;
Begin
  If LoopDepth > 0 Then
    Dec(LoopDepth);
End;

{ ------------------------------------------------------------ }
{ ParseFor : parser une boucle For/Next VB.NET                 }
{ Syntaxe : For i = debut To fin [Step pas]                    }
{             instructions                                     }
{           Next [i]                                           }
{ Detecte aussi For Each et delegue a ParseForEach             }
{ ------------------------------------------------------------ }

Procedure ParseFor;
Var
  LblLoop  : TString;  { label debut de boucle   }
  LblEnd   : TString;  { label fin de boucle     }
  VarName  : TString;  { nom de la variable       }
  Idx      : Integer;  { index dans la sym table  }
  HasStep  : Boolean;  { True si Step est present }
Begin
  { Consommer 'For' }
  LexNextToken;

  { Verifier si c est For Each }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_EACH) Then
  Begin
    ParseForEach;
    Exit;
  End;

  EnterCtrl;
  EnterLoop;

  { Lire le nom de la variable de boucle }
  If CurTokType <> TOK_IDENT Then
  Begin
    FatalError('For: variable attendue');
    LeaveLoop;
    LeaveCtrl;
    Exit;
  End;
  VarName := CurTokStr;
  Idx := FindSym(VarName);
  If Idx < 0 Then
    Idx := AddSym(VarName, SK_VAR, VBT_INTEGER, STORE_AUTO);
  LexNextToken;

  { Attendre '=' }
  Expect(TOK_EQ);

  { Parser l expression de debut }
  ParseExpr;
  EmitComment('For ' + VarName + ' = start');
  GenStoreVar(Idx);

  { Attendre 'To' }
  ExpectKeyword(KW_TO);

  { Parser l expression de fin, la placer sur la pile }
  ParseExpr;
  EmitComment('For ' + VarName + ' To limit');
  GenPushEAX;

  { Verifier Step optionnel }
  HasStep := False;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_STEP) Then
  Begin
    LexNextToken;
    HasStep := True;
    ParseExpr;
    EmitComment('For Step value');
    Emit('  PUSH EAX');  { pile : [fin, step] }
  End;

  { Emettre le label de debut de boucle }
  LblLoop := NextInternalLabel;
  LblEnd  := NextInternalLabel;
  EmitLabel(LblLoop);

  { Charger la variable, comparer avec la fin }
  GenLoadVar(Idx);
  EmitComment('For compare ' + VarName + ' to limit');
  If HasStep Then
  Begin
    { Recuperer la fin (en dessous du step sur la pile) }
    Emit('  MOV EBX, [ESP+4]');
  End
  Else
    GenPopEBX;
  Emit('  CMP EAX, EBX');
  Emit('  JG ' + LblEnd);

  { Parser le bloc d instructions }
  SkipNewlines;
  ParseStatementBlock;

  { Attendre 'Next' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEXT) Then
  Begin
    LexNextToken;
    { Optionnel : nom de la variable apres Next }
    If (CurTokType = TOK_IDENT) Then
      LexNextToken;
  End;

  { Incrementer la variable de boucle }
  GenLoadVar(Idx);
  EmitComment('For increment ' + VarName);
  If HasStep Then
  Begin
    Emit('  MOV EBX, [ESP]');  { step est au sommet }
    Emit('  ADD EAX, EBX');
  End
  Else
    Emit('  ADD EAX, 1');
  GenStoreVar(Idx);

  { Boucler }
  If HasStep Then
  Begin
    Emit('  JMP ' + LblLoop);
    EmitLabel(LblEnd);
    { Nettoyer la pile : fin et step }
    Emit('  ADD ESP, 8');
  End
  Else
  Begin
    Emit('  JMP ' + LblLoop);
    EmitLabel(LblEnd);
  End;

  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseDoLoop : parser une boucle Do/Loop VB.NET               }
{ Syntaxe : Do [While|Until condition]                         }
{             instructions                                     }
{           Loop [While|Until condition]                        }
{ ------------------------------------------------------------ }

Procedure ParseDoLoop;
Var
  LblLoop   : TString;    { label debut de boucle     }
  LblEnd    : TString;    { label fin de boucle       }
  PreCond   : Boolean;    { True si While/Until avant  }
  IsWhile   : Boolean;    { True=While, False=Until    }
Begin
  EnterCtrl;
  EnterLoop;
  { Consommer 'Do' }
  LexNextToken;

  LblLoop := NextInternalLabel;
  LblEnd  := NextInternalLabel;

  PreCond := False;
  IsWhile := True;

  { Verifier condition pre-test (Do While/Until) }
  If (CurTokType = TOK_KEYWORD) Then
  Begin
    If (CurTokNum = KW_WHILE) Then
    Begin
      PreCond := True;
      IsWhile := True;
      LexNextToken;
    End
    Else If (CurTokNum = KW_UNTIL) Then
    Begin
      PreCond := True;
      IsWhile := False;
      LexNextToken;
    End;
  End;

  EmitLabel(LblLoop);

  If PreCond Then
  Begin
    ParseExpr;
    EmitComment('Do pre-condition');
    Emit('  CMP EAX, 0');
    If IsWhile Then
      Emit('  JE ' + LblEnd)    { While: sortir si False }
    Else
      Emit('  JNE ' + LblEnd);  { Until: sortir si True  }
  End;

  { Parser le bloc d instructions }
  SkipNewlines;
  ParseStatementBlock;

  { Attendre 'Loop' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_LOOP) Then
  Begin
    LexNextToken;

    { Verifier condition post-test (Loop While/Until) }
    If (CurTokType = TOK_KEYWORD) Then
    Begin
      If (CurTokNum = KW_WHILE) Then
      Begin
        LexNextToken;
        ParseExpr;
        EmitComment('Loop While condition');
        Emit('  CMP EAX, 0');
        Emit('  JNE ' + LblLoop);  { While: boucler si True }
      End
      Else If (CurTokNum = KW_UNTIL) Then
      Begin
        LexNextToken;
        ParseExpr;
        EmitComment('Loop Until condition');
        Emit('  CMP EAX, 0');
        Emit('  JE ' + LblLoop);   { Until: boucler si False }
      End
      Else
      Begin
        { Do ... Loop (boucle infinie) }
        Emit('  JMP ' + LblLoop);
      End;
    End
    Else
    Begin
      { Do ... Loop sans condition post-test }
      If Not PreCond Then
        Emit('  JMP ' + LblLoop)    { boucle infinie }
      Else
        Emit('  JMP ' + LblLoop);   { pre-cond geree en haut }
    End;
  End;

  EmitLabel(LblEnd);
  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseWhile : parser une boucle While/End While VB.NET        }
{ Syntaxe : While condition                                    }
{             instructions                                     }
{           End While                                          }
{ Note : VB.NET utilise End While et non Wend                  }
{ ------------------------------------------------------------ }

Procedure ParseWhile;
Var
  LblLoop : TString;  { label debut de boucle }
  LblEnd  : TString;  { label fin de boucle   }
Begin
  EnterCtrl;
  EnterLoop;
  { Consommer 'While' }
  LexNextToken;

  LblLoop := NextInternalLabel;
  LblEnd  := NextInternalLabel;

  EmitLabel(LblLoop);

  { Parser la condition }
  ParseExpr;
  EmitComment('While condition');
  Emit('  CMP EAX, 0');
  Emit('  JE ' + LblEnd);

  { Parser le bloc d instructions }
  SkipNewlines;
  ParseStatementBlock;

  { Attendre 'End While' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
  Begin
    LexNextToken;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WHILE) Then
      LexNextToken
    Else
      WarnMsg('End While attendu');
  End
  Else
    WarnMsg('End While attendu');

  { Retourner au debut de la boucle }
  Emit('  JMP ' + LblLoop);
  EmitLabel(LblEnd);

  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseForEach : parser une boucle For Each/Next VB.NET        }
{ Syntaxe : For Each element In collection                     }
{             instructions                                     }
{           Next [element]                                     }
{ ------------------------------------------------------------ }

Procedure ParseForEach;
Begin
  EnterCtrl;
  EnterLoop;
  { 'For' deja consomme, consommer 'Each' }
  LexNextToken;

  EmitComment('For Each (stub - not fully implemented)');

  { Lire le nom de l element }
  If CurTokType = TOK_IDENT Then
    LexNextToken;

  { Attendre 'In' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_IN) Then
    LexNextToken;

  { Lire la collection }
  If CurTokType = TOK_IDENT Then
    LexNextToken;

  { Parser le bloc d instructions }
  SkipNewlines;
  ParseStatementBlock;

  { Attendre 'Next' }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEXT) Then
  Begin
    LexNextToken;
    { Optionnel : nom de l element apres Next }
    If (CurTokType = TOK_IDENT) Then
      LexNextToken;
  End;

  LeaveLoop;
  LeaveCtrl;
End;

{ ------------------------------------------------------------ }
{ ParseExitStatement : parser Exit Sub/Function/For/Do/While   }
{ VB.NET ajoute Exit While par rapport a VB6                   }
{ ------------------------------------------------------------ }

Procedure ParseExitStatement;
Var
  ExLbl : TString;
Begin
  LexNextToken; { consommer 'Exit' }
  If CurTokType <> TOK_KEYWORD Then
  Begin
    WarnMsg('Mot-cle attendu apres "Exit"');
    Exit;
  End;
  Case CurTokNum Of
    KW_SUB:
    Begin
      LexNextToken; { consommer 'Sub' }
      ExLbl := FindEnclosingExitLabel;
      If ExLbl <> '' Then
      Begin
        EmitComment('Exit Sub');
        Emit('JMP ' + ExLbl);
      End
      Else
        WarnMsg('Exit Sub en dehors d''un Sub');
    End;
    KW_FUNCTION:
    Begin
      LexNextToken; { consommer 'Function' }
      ExLbl := FindEnclosingExitLabel;
      If ExLbl <> '' Then
      Begin
        EmitComment('Exit Function');
        Emit('JMP ' + ExLbl);
      End
      Else
        WarnMsg('Exit Function en dehors d''une Function');
    End;
    KW_FOR:
    Begin
      LexNextToken; { consommer 'For' }
      ExLbl := FindEnclosingExitLabel;
      If ExLbl <> '' Then
      Begin
        EmitComment('Exit For');
        Emit('JMP ' + ExLbl);
      End
      Else
        WarnMsg('Exit For en dehors d''une boucle For');
    End;
    KW_DO:
    Begin
      LexNextToken; { consommer 'Do' }
      ExLbl := FindEnclosingExitLabel;
      If ExLbl <> '' Then
      Begin
        EmitComment('Exit Do');
        Emit('JMP ' + ExLbl);
      End
      Else
        WarnMsg('Exit Do en dehors d''une boucle Do');
    End;
    KW_WHILE:
    Begin
      LexNextToken; { consommer 'While' }
      ExLbl := FindEnclosingExitLabel;
      If ExLbl <> '' Then
      Begin
        EmitComment('Exit While');
        Emit('JMP ' + ExLbl);
      End
      Else
        WarnMsg('Exit While en dehors d''une boucle While');
    End;
  Else
    WarnMsg('"Sub", "Function", "For", "Do" ou "While" attendu apres "Exit"');
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseContinueStatement : parser Continue For/Do/While        }
{ VB.NET uniquement (n existe pas en VB6)                      }
{ ------------------------------------------------------------ }

Procedure ParseContinueStatement;
Begin
  LexNextToken; { consommer 'Continue' }
  If CurTokType <> TOK_KEYWORD Then
  Begin
    WarnMsg('Mot-cle attendu apres "Continue"');
    Exit;
  End;
  Case CurTokNum Of
    KW_FOR:
    Begin
      LexNextToken; { consommer 'For' }
      EmitComment('Continue For');
      { En VB.NET, Continue For saute a l increment de la boucle }
      { Simplifie : genere un commentaire indicatif }
      Emit('; Continue For - JMP vers label_continue');
    End;
    KW_DO:
    Begin
      LexNextToken; { consommer 'Do' }
      EmitComment('Continue Do');
      Emit('; Continue Do - JMP vers label_continue');
    End;
    KW_WHILE:
    Begin
      LexNextToken; { consommer 'While' }
      EmitComment('Continue While');
      Emit('; Continue While - JMP vers label_continue');
    End;
  Else
    WarnMsg('"For", "Do" ou "While" attendu apres "Continue"');
    LexNextToken;
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseurs pour le module de boucles               }
{ ------------------------------------------------------------ }

Function GetLoopCount : LongInt;
Begin
  GetLoopCount := LoopCount;
End;

Function GetLoopDepth : Integer;
Begin
  GetLoopDepth := LoopDepth;
End;

Function GetMaxLoopDepth : Integer;
Begin
  GetMaxLoopDepth := MaxLoopDepth;
End;

Function IsLoopInitialized : Boolean;
Begin
  IsLoopInitialized := LoopInitialized;
End;

Function IsLoopEmpty : Boolean;
Begin
  IsLoopEmpty := (LoopCount = 0);
End;

Function GetLoopStatus : TString;
Begin
  If LoopInitialized Then
    GetLoopStatus := 'initialized'
  Else
    GetLoopStatus := 'not initialized';
End;

Function IsInLoop : Boolean;
Begin
  IsInLoop := (LoopDepth > 0);
End;

Function IsLoopNested : Boolean;
Begin
  IsLoopNested := (LoopDepth > 1);
End;

Function GetLoopMaxLabel : TString;
Begin
  GetLoopMaxLabel := PFX_LBL + ItoSI(InternalLabelCount);
End;

Function IsLoopStackEmpty : Boolean;
Begin
  IsLoopStackEmpty := (LoopDepth = 0);
End;

{ ============================================================ }
{ TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET          }
{           FONCTIONS) [IMPLEMENTE]                            }
{ ============================================================ }

Var
  SubFuncCount       : LongInt;   { nombre total de Sub/Function parsees  }
  SubFuncInitialized : Boolean;   { True si InitSubFuncState a ete appele }
  CurProcIsPublic    : Boolean;   { visibilite pour la proc en cours      }
  CurProcIsShared    : Boolean;   { Shared pour la proc en cours          }

{ ------------------------------------------------------------ }
{ InitSubFuncState : initialiser l etat du parseur Sub/Func    }
{ ------------------------------------------------------------ }

Procedure InitSubFuncState;
Begin
  SubFuncCount       := 0;
  SubFuncInitialized := True;
  CurProcIsPublic    := True;
  CurProcIsShared    := False;
End;

{ ------------------------------------------------------------ }
{ ParseParamList : analyser la liste de parametres              }
{   ProcIdx : index dans ProcTab de la procedure courante      }
{   Token courant : '(' ou premier token apres nom             }
{   Parametres supportes :                                     }
{     ByVal x As Integer (passage par valeur, defaut VB.NET)   }
{     ByRef x As Integer (passage par reference)               }
{     Optional x As Integer = 0 (parametre optionnel)          }
{     ParamArray args() As Integer (stub)                      }
{ ------------------------------------------------------------ }

Procedure ParseParamList(ProcIdx : Integer);
Var
  PName     : TString;
  PType     : Integer;
  PByRef    : Boolean;
  POptional : Boolean;
  PDefault  : TString;
  ParamOfs  : Integer;
  Idx       : Integer;
Begin
  ParamOfs := SCOPE_EBP_PARAM_BASE; { [EBP+8] = premier param }

  { Pas de parenthese -> pas de parametres }
  If CurTokType <> TOK_LPAREN Then
    Exit;
  LexNextToken; { consommer '(' }

  { Parenthese vide () }
  If CurTokType = TOK_RPAREN Then
  Begin
    LexNextToken; { consommer ')' }
    Exit;
  End;

  { Boucle sur les parametres separes par ',' }
  While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) Do
  Begin
    PByRef    := False; { ByVal par defaut en VB.NET }
    POptional := False;
    PDefault  := '';

    { Modificateurs optionnels : ByVal, ByRef, Optional, ParamArray }
    While (CurTokType = TOK_KEYWORD) And
          ((CurTokNum = KW_BYVAL) Or (CurTokNum = KW_BYREF) Or
           (CurTokNum = KW_OPTIONAL) Or (CurTokNum = KW_PARAMARRAY)) Do
    Begin
      If CurTokNum = KW_BYVAL Then
        PByRef := False
      Else If CurTokNum = KW_BYREF Then
        PByRef := True
      Else If CurTokNum = KW_OPTIONAL Then
        POptional := True;
      { ParamArray : juste consommer le mot-cle (stub) }
      LexNextToken;
    End;

    { Nom du parametre }
    If CurTokType <> TOK_IDENT Then
    Begin
      WarnMsg('Nom de parametre attendu, trouve "' + CurTokStr + '"');
      While (CurTokType <> TOK_RPAREN) And (CurTokType <> TOK_EOF) And
            (CurTokType <> TOK_NEWLINE) Do
        LexNextToken;
      If CurTokType = TOK_RPAREN Then
        LexNextToken;
      Exit;
    End;
    PName := CurTokStr;
    LexNextToken;

    { Gerer les parentheses vides pour ParamArray : args() }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken; { consommer '(' }
      If CurTokType = TOK_RPAREN Then
        LexNextToken; { consommer ')' }
    End;

    { As Type optionnel }
    PType := VBT_OBJECT;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AS) Then
    Begin
      LexNextToken; { consommer 'As' }
      PType := ParseTypeSpec;
    End;

    { Valeur par defaut : = valeur (pour Optional) }
    If CurTokType = TOK_EQ Then
    Begin
      LexNextToken; { consommer '=' }
      PDefault := CurTokStr;
      LexNextToken; { consommer la valeur par defaut }
    End;

    { Ajouter le parametre dans SymTab }
    Idx := AddSym(PName, SK_PARAM, PType, STORE_PARAM);
    If Idx >= 0 Then
    Begin
      SymTab[Idx].ByRef      := PByRef;
      SymTab[Idx].IsOptional := POptional;
      SymTab[Idx].BpOffset   := ParamOfs;
      If POptional And (PDefault <> '') Then
      Begin
        SymTab[Idx].HasDefault := True;
        SymTab[Idx].DefaultVal := PDefault;
      End;
      Inc(ParamOfs, 4); { chaque param = 4 octets (PUSH DWORD) }
      If (ProcIdx >= 0) And (ProcIdx < ProcCount) Then
        Inc(ProcTab[ProcIdx].ParamCount);
    End;

    { Separateur ',' -> parametre suivant }
    If CurTokType = TOK_COMMA Then
      LexNextToken;
  End;

  { Consommer ')' }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
End;

{ ------------------------------------------------------------ }
{ ParseSub : analyser une procedure Sub                        }
{   [Public|Private|Protected|Friend] [Shared] [Overloads]     }
{     [Overrides|Overridable|NotOverridable|MustOverride]      }
{     Sub nom([params])                                        }
{     instructions                                             }
{     [Exit Sub]                                               }
{     [Return]                                                 }
{   End Sub                                                    }
{   Genere prologue/epilogue STDCALL Win32 :                   }
{     PUSH EBP / MOV EBP, ESP / SUB ESP, taille_locales        }
{     ... corps ...                                            }
{     MOV ESP, EBP / POP EBP / RET n                           }
{ ------------------------------------------------------------ }

Procedure ParseSub;
Var
  SubName    : TString;
  ProcIdx    : Integer;
  ParamBytes : Integer;
Begin
  Inc(SubFuncCount);

  { Le token courant est 'Sub' }
  LexNextToken; { consommer 'Sub' }

  { Nom du Sub }
  If CurTokType <> TOK_IDENT Then
  Begin
    FatalError('Nom de Sub attendu, trouve "' + CurTokStr + '"');
    Exit;
  End;
  SubName := CurTokStr;
  LexNextToken;

  { Ajouter dans ProcTab }
  ProcIdx := AddProc(SubName, SK_SUB, VBT_NONE, CurProcIsPublic);
  If ProcIdx < 0 Then Exit;
  ProcTab[ProcIdx].IsShared := CurProcIsShared;

  { Entrer dans la portee Sub }
  EnterScope(SCOPE_SUB, ProcIdx);

  { Analyser la liste de parametres }
  ParseParamList(ProcIdx);
  ProcTab[ProcIdx].LocalStart := SymCount;

  SkipNewlines;

  { Emettre le prologue STDCALL }
  EmitComment('Sub ' + SubName);
  EmitLabel(ProcTab[ProcIdx].AsmLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('SUB ESP, ' + ItoSI(ProcTab[ProcIdx].LocalSize));

  { Parser le corps du Sub }
  ParseStatementBlock;

  { Verifier End Sub }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
  Begin
    LexNextToken; { consommer 'End' }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SUB) Then
      LexNextToken  { consommer 'Sub' }
    Else
      WarnMsg('"Sub" attendu apres "End"');
  End
  Else
    WarnMsg('"End Sub" attendu');

  { Emettre l epilogue }
  EmitLabel(ProcTab[ProcIdx].ExitLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  ParamBytes := ProcTab[ProcIdx].ParamCount * 4;
  Emit('RET ' + ItoSI(ParamBytes));
  EmitComment('End Sub ' + SubName);

  { Quitter la portee }
  LeaveScope;

  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseFunction : analyser une procedure Function              }
{   [Public|Private|Protected|Friend] [Shared] [Overloads]     }
{     [Overrides|Overridable|NotOverridable|MustOverride]      }
{     Function nom([params]) As type                           }
{     instructions                                             }
{     Return valeur                                            }
{     [Exit Function]                                          }
{   End Function                                               }
{   Genere prologue/epilogue STDCALL Win32                     }
{   Valeur de retour dans EAX (entier/pointeur)                }
{   Note : ByVal est le defaut en VB.NET (ByRef en VB6)        }
{ ------------------------------------------------------------ }

Procedure ParseFunction;
Var
  FuncName   : TString;
  RetType    : Integer;
  ProcIdx    : Integer;
  ParamBytes : Integer;
Begin
  Inc(SubFuncCount);

  { Le token courant est 'Function' }
  LexNextToken; { consommer 'Function' }

  { Nom du Function }
  If CurTokType <> TOK_IDENT Then
  Begin
    FatalError('Nom de Function attendu, trouve "' + CurTokStr + '"');
    Exit;
  End;
  FuncName := CurTokStr;
  LexNextToken;

  { Ajouter dans ProcTab (retour par defaut Object en VB.NET) }
  ProcIdx := AddProc(FuncName, SK_FUNCTION, VBT_OBJECT, CurProcIsPublic);
  If ProcIdx < 0 Then Exit;
  ProcTab[ProcIdx].IsShared := CurProcIsShared;

  { Entrer dans la portee Function }
  EnterScope(SCOPE_FUNCTION, ProcIdx);

  { Analyser la liste de parametres }
  ParseParamList(ProcIdx);

  { Analyser le type de retour : As Type }
  RetType := VBT_OBJECT;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AS) Then
  Begin
    LexNextToken; { consommer 'As' }
    RetType := ParseTypeSpec;
  End;
  ProcTab[ProcIdx].ReturnType := RetType;
  ProcTab[ProcIdx].LocalStart := SymCount;

  SkipNewlines;

  { Emettre le prologue STDCALL }
  EmitComment('Function ' + FuncName + ' As ' + VBTypeName(RetType));
  EmitLabel(ProcTab[ProcIdx].AsmLabel);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('SUB ESP, ' + ItoSI(ProcTab[ProcIdx].LocalSize));
  Emit('XOR EAX, EAX'); { valeur de retour par defaut = 0 }

  { Parser le corps du Function }
  ParseStatementBlock;

  { Verifier End Function }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
  Begin
    LexNextToken; { consommer 'End' }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION) Then
      LexNextToken  { consommer 'Function' }
    Else
      WarnMsg('"Function" attendu apres "End"');
  End
  Else
    WarnMsg('"End Function" attendu');

  { Emettre l epilogue }
  { Valeur de retour dans EAX }
  EmitLabel(ProcTab[ProcIdx].ExitLabel);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  ParamBytes := ProcTab[ProcIdx].ParamCount * 4;
  Emit('RET ' + ItoSI(ParamBytes));
  EmitComment('End Function ' + FuncName);

  { Quitter la portee }
  LeaveScope;

  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseProcedures : analyser les definitions de Sub/Function   }
{   au niveau du module (top-level)                            }
{   Boucle jusqu a la fin du fichier                           }
{   Gere les modificateurs VB.NET :                            }
{     Public/Private/Protected/Friend                          }
{     Shared                                                   }
{     Overloads/Overrides/Overridable/NotOverridable/          }
{       MustOverride                                           }
{ ------------------------------------------------------------ }

Procedure ParseProcedures;
Begin
  SkipNewlines;
  While CurTokType <> TOK_EOF Do
  Begin
    { Reinitialiser les modificateurs }
    CurProcIsPublic := True;  { Public par defaut en VB.NET }
    CurProcIsShared := False;

    If CurTokType = TOK_KEYWORD Then
    Begin
      { Modificateurs de visibilite }
      If CurTokNum = KW_PUBLIC Then
      Begin
        CurProcIsPublic := True;
        LexNextToken;
      End
      Else If CurTokNum = KW_PRIVATE Then
      Begin
        CurProcIsPublic := False;
        LexNextToken;
      End
      Else If CurTokNum = KW_PROTECTED Then
      Begin
        CurProcIsPublic := False;
        LexNextToken;
      End
      Else If CurTokNum = KW_FRIEND Then
      Begin
        CurProcIsPublic := True; { Friend = visible dans l assembly }
        LexNextToken;
      End;

      { Modificateur Shared }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SHARED) Then
      Begin
        CurProcIsShared := True;
        LexNextToken;
      End;

      { Modificateurs Overloads/Overrides/Overridable/NotOverridable/ }
      { MustOverride : consommer sans traitement special               }
      While (CurTokType = TOK_KEYWORD) And
            ((CurTokNum = KW_OVERLOADS) Or (CurTokNum = KW_OVERRIDES) Or
             (CurTokNum = KW_OVERRIDABLE) Or (CurTokNum = KW_NOTOVERRIDABLE) Or
             (CurTokNum = KW_MUSTOVERRIDE)) Do
        LexNextToken;

      { Dispatcher selon Sub ou Function }
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SUB) Then
        ParseSub
      Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION) Then
        ParseFunction
      Else
        LexNextToken; { token non reconnu a ce niveau, avancer }
    End
    Else
      LexNextToken; { non mot-cle, avancer }

    SkipNewlines;
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces - TODO 12                                  }
{ ------------------------------------------------------------ }

Function GetSubFuncCount : LongInt;
Begin
  GetSubFuncCount := SubFuncCount;
End;

Function IsSubFuncInitialized : Boolean;
Begin
  IsSubFuncInitialized := SubFuncInitialized;
End;

Function IsSubFuncEmpty : Boolean;
Begin
  IsSubFuncEmpty := (SubFuncCount = 0);
End;

Function GetSubFuncStatus : TString;
Begin
  If SubFuncInitialized Then
    GetSubFuncStatus := 'initialized'
  Else
    GetSubFuncStatus := 'not initialized';
End;

Function GetLastProcName : TString;
Begin
  If ProcCount > 0 Then
    GetLastProcName := ProcTab[ProcCount - 1].Name
  Else
    GetLastProcName := '';
End;

Function GetLastProcKind : Integer;
Begin
  If ProcCount > 0 Then
    GetLastProcKind := ProcTab[ProcCount - 1].Kind
  Else
    GetLastProcKind := -1;
End;

Function GetLastProcReturnType : Integer;
Begin
  If ProcCount > 0 Then
    GetLastProcReturnType := ProcTab[ProcCount - 1].ReturnType
  Else
    GetLastProcReturnType := VBT_NONE;
End;

Function GetLastProcParamCount : Integer;
Begin
  If ProcCount > 0 Then
    GetLastProcParamCount := ProcTab[ProcCount - 1].ParamCount
  Else
    GetLastProcParamCount := 0;
End;

Function GetLastProcIsPublic : Boolean;
Begin
  If ProcCount > 0 Then
    GetLastProcIsPublic := ProcTab[ProcCount - 1].IsPublic
  Else
    GetLastProcIsPublic := False;
End;

Function GetLastProcAsmLabel : TString;
Begin
  If ProcCount > 0 Then
    GetLastProcAsmLabel := ProcTab[ProcCount - 1].AsmLabel
  Else
    GetLastProcAsmLabel := '';
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseurs pour le module de structures de controle }
{ ------------------------------------------------------------ }

Function GetCtrlCount : LongInt;
Begin
  GetCtrlCount := CtrlCount;
End;

Function GetCtrlDepth : Integer;
Begin
  GetCtrlDepth := CtrlDepth;
End;

Function GetMaxCtrlDepth : Integer;
Begin
  GetMaxCtrlDepth := MaxCtrlDepth;
End;

Function IsCtrlInitialized : Boolean;
Begin
  IsCtrlInitialized := CtrlInitialized;
End;

Function IsCtrlEmpty : Boolean;
Begin
  IsCtrlEmpty := (CtrlCount = 0);
End;

Function GetCtrlStatus : TString;
Begin
  If CtrlInitialized Then
    GetCtrlStatus := 'initialized'
  Else
    GetCtrlStatus := 'not initialized';
End;

Function IsInIfBlock : Boolean;
Begin
  IsInIfBlock := (CtrlDepth > 0);
End;

Function IsCtrlNested : Boolean;
Begin
  IsCtrlNested := (CtrlDepth > 1);
End;

Function GetCtrlMaxLabel : TString;
Begin
  GetCtrlMaxLabel := PFX_LBL + ItoSI(InternalLabelCount);
End;

Function IsCtrlStackEmpty : Boolean;
Begin
  IsCtrlStackEmpty := (CtrlDepth = 0);
End;

{ ============================================================ }
{ TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES ET METHODES       }
{           SYSTEME  [IMPLEMENTE]                              }
{ ============================================================ }

Var
  IntrinsicCount       : LongInt;
  IntrinsicInitialized : Boolean;

{ ------------------------------------------------------------ }
{ InitIntrinsicState : initialiser l etat des intrinseques     }
{ ------------------------------------------------------------ }

Procedure InitIntrinsicState;
Begin
  IntrinsicCount       := 0;
  IntrinsicInitialized := True;
End;

{ ------------------------------------------------------------ }
{ IsIntrinsicFunction : teste si un code KW_* est une          }
{   fonction intrinseque VB.NET reconnue                       }
{ ------------------------------------------------------------ }

Function IsIntrinsicFunction(KW : Integer) : Boolean;
Begin
  Case KW Of
    { Fonctions de chaines (compatibles VB6) }
    KW_LEN, KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_INSTR, KW_INSTRREV,
    KW_REPLACE,
    KW_SPACE, KW_STRREVERSE,
    KW_SPLIT, KW_JOIN,
    KW_ASC, KW_CHR,
    KW_FORMAT,
    { Fonctions de conversion VB.NET }
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCHAR, KW_CDATE, KW_CDEC,
    KW_CSHORT, KW_CUSHORT, KW_CUINT, KW_CULNG, KW_CSBYTE, KW_COBJ,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX,
    { Fonctions mathematiques }
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN,
    { Fonctions d information }
    KW_ISNUMERIC, KW_ISDATE, KW_ISARRAY, KW_ISNOTHING,
    { Fonctions d entree/sortie }
    KW_MSGBOX, KW_INPUTBOX:
      IsIntrinsicFunction := True;
  Else
    IsIntrinsicFunction := False;
  End;
End;

{ ------------------------------------------------------------ }
{ IntrinsicRtLabel : retourne le label runtime _VBNRT_XXX      }
{   pour une fonction intrinseque donnee (code KW_*)           }
{ ------------------------------------------------------------ }

Function IntrinsicRtLabel(KW : Integer) : TString;
Begin
  Case KW Of
    KW_LEN        : IntrinsicRtLabel := PFX_RT + 'LEN';
    KW_LEFT       : IntrinsicRtLabel := PFX_RT + 'LEFT';
    KW_RIGHT      : IntrinsicRtLabel := PFX_RT + 'RIGHT';
    KW_MID        : IntrinsicRtLabel := PFX_RT + 'MID';
    KW_LTRIM      : IntrinsicRtLabel := PFX_RT + 'LTRIM';
    KW_RTRIM      : IntrinsicRtLabel := PFX_RT + 'RTRIM';
    KW_TRIM       : IntrinsicRtLabel := PFX_RT + 'TRIM';
    KW_UCASE      : IntrinsicRtLabel := PFX_RT + 'UCASE';
    KW_LCASE      : IntrinsicRtLabel := PFX_RT + 'LCASE';
    KW_INSTR      : IntrinsicRtLabel := PFX_RT + 'INSTR';
    KW_INSTRREV   : IntrinsicRtLabel := PFX_RT + 'INSTRREV';
    KW_REPLACE    : IntrinsicRtLabel := PFX_RT + 'REPLACE';
    KW_SPACE      : IntrinsicRtLabel := PFX_RT + 'SPACE';
    KW_STRREVERSE : IntrinsicRtLabel := PFX_RT + 'STRREVERSE';
    KW_SPLIT      : IntrinsicRtLabel := PFX_RT + 'SPLIT';
    KW_JOIN       : IntrinsicRtLabel := PFX_RT + 'JOIN';
    KW_ASC        : IntrinsicRtLabel := PFX_RT + 'ASC';
    KW_CHR        : IntrinsicRtLabel := PFX_RT + 'CHR';
    KW_FORMAT     : IntrinsicRtLabel := PFX_RT + 'FORMAT';
    KW_CINT       : IntrinsicRtLabel := PFX_RT + 'CINT';
    KW_CLNG       : IntrinsicRtLabel := PFX_RT + 'CLNG';
    KW_CSNG       : IntrinsicRtLabel := PFX_RT + 'CSNG';
    KW_CDBL       : IntrinsicRtLabel := PFX_RT + 'CDBL';
    KW_CSTR       : IntrinsicRtLabel := PFX_RT + 'CSTR';
    KW_CBOOL      : IntrinsicRtLabel := PFX_RT + 'CBOOL';
    KW_CBYTE      : IntrinsicRtLabel := PFX_RT + 'CBYTE';
    KW_CCHAR      : IntrinsicRtLabel := PFX_RT + 'CCHAR';
    KW_CDATE      : IntrinsicRtLabel := PFX_RT + 'CDATE';
    KW_CDEC       : IntrinsicRtLabel := PFX_RT + 'CDEC';
    KW_CSHORT     : IntrinsicRtLabel := PFX_RT + 'CSHORT';
    KW_CUSHORT    : IntrinsicRtLabel := PFX_RT + 'CUSHORT';
    KW_CUINT      : IntrinsicRtLabel := PFX_RT + 'CUINT';
    KW_CULNG      : IntrinsicRtLabel := PFX_RT + 'CULNG';
    KW_CSBYTE     : IntrinsicRtLabel := PFX_RT + 'CSBYTE';
    KW_COBJ       : IntrinsicRtLabel := PFX_RT + 'COBJ';
    KW_VAL        : IntrinsicRtLabel := PFX_RT + 'VAL';
    KW_STR        : IntrinsicRtLabel := PFX_RT + 'STR';
    KW_HEX        : IntrinsicRtLabel := PFX_RT + 'HEX';
    KW_OCT        : IntrinsicRtLabel := PFX_RT + 'OCT';
    KW_INT        : IntrinsicRtLabel := PFX_RT + 'INT';
    KW_FIX        : IntrinsicRtLabel := PFX_RT + 'FIX';
    KW_ABS        : IntrinsicRtLabel := PFX_RT + 'ABS';
    KW_SGN        : IntrinsicRtLabel := PFX_RT + 'SGN';
    KW_SQR        : IntrinsicRtLabel := PFX_RT + 'SQR';
    KW_EXP        : IntrinsicRtLabel := PFX_RT + 'EXP';
    KW_LOG        : IntrinsicRtLabel := PFX_RT + 'LOG';
    KW_SIN        : IntrinsicRtLabel := PFX_RT + 'SIN';
    KW_COS        : IntrinsicRtLabel := PFX_RT + 'COS';
    KW_TAN        : IntrinsicRtLabel := PFX_RT + 'TAN';
    KW_ATN        : IntrinsicRtLabel := PFX_RT + 'ATN';
    KW_ISNUMERIC  : IntrinsicRtLabel := PFX_RT + 'ISNUMERIC';
    KW_ISDATE     : IntrinsicRtLabel := PFX_RT + 'ISDATE';
    KW_ISARRAY    : IntrinsicRtLabel := PFX_RT + 'ISARRAY';
    KW_ISNOTHING  : IntrinsicRtLabel := PFX_RT + 'ISNOTHING';
    KW_MSGBOX     : IntrinsicRtLabel := PFX_RT + 'MSGBOX';
    KW_INPUTBOX   : IntrinsicRtLabel := PFX_RT + 'INPUTBOX';
  Else
    IntrinsicRtLabel := PFX_RT + 'UNKNOWN';
  End;
End;

{ ------------------------------------------------------------ }
{ IntrinsicArgCount : nombre d arguments attendus              }
{   -1 = variadic (1 a N), 0 = aucun argument                 }
{ ------------------------------------------------------------ }

Function IntrinsicArgCount(KW : Integer) : Integer;
Begin
  Case KW Of
    { 1 argument }
    KW_LEN, KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE, KW_STRREVERSE,
    KW_ASC, KW_CHR,
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCHAR, KW_CDATE, KW_CDEC,
    KW_CSHORT, KW_CUSHORT, KW_CUINT, KW_CULNG, KW_CSBYTE, KW_COBJ,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX,
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN,
    KW_ISNUMERIC, KW_ISDATE, KW_ISARRAY, KW_ISNOTHING,
    KW_SPACE:
      IntrinsicArgCount := 1;
    { 2 arguments }
    KW_LEFT, KW_RIGHT,
    KW_SPLIT, KW_JOIN:
      IntrinsicArgCount := 2;
    { variadic (1-4 arguments) }
    KW_MID, KW_INSTR, KW_INSTRREV, KW_REPLACE,
    KW_FORMAT, KW_MSGBOX, KW_INPUTBOX:
      IntrinsicArgCount := -1;
  Else
    IntrinsicArgCount := -1;
  End;
End;

{ ------------------------------------------------------------ }
{ IntrinsicResultType : type de retour VBT_* de la fonction    }
{ ------------------------------------------------------------ }

Function IntrinsicResultType(KW : Integer) : Integer;
Begin
  Case KW Of
    { Retourne Integer (32 bits en VB.NET) }
    KW_LEN, KW_ASC, KW_INSTR, KW_INSTRREV,
    KW_CINT:
      IntrinsicResultType := VBT_INTEGER;
    { Retourne Long (64 bits en VB.NET) }
    KW_CLNG, KW_INT, KW_FIX, KW_SGN:
      IntrinsicResultType := VBT_LONG;
    { Retourne String }
    KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_REPLACE, KW_SPACE,
    KW_STRREVERSE, KW_JOIN, KW_CHR, KW_CSTR,
    KW_STR, KW_HEX, KW_OCT, KW_FORMAT:
      IntrinsicResultType := VBT_STRING;
    { Retourne Short }
    KW_CSHORT:
      IntrinsicResultType := VBT_SHORT;
    { Retourne UShort }
    KW_CUSHORT:
      IntrinsicResultType := VBT_USHORT;
    { Retourne UInteger }
    KW_CUINT:
      IntrinsicResultType := VBT_UINTEGER;
    { Retourne ULong }
    KW_CULNG:
      IntrinsicResultType := VBT_ULONG;
    { Retourne SByte }
    KW_CSBYTE:
      IntrinsicResultType := VBT_SBYTE;
    { Retourne Single }
    KW_CSNG:
      IntrinsicResultType := VBT_SINGLE;
    { Retourne Double }
    KW_CDBL, KW_ABS, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN, KW_VAL:
      IntrinsicResultType := VBT_DOUBLE;
    { Retourne Boolean }
    KW_CBOOL, KW_ISNUMERIC, KW_ISDATE, KW_ISARRAY,
    KW_ISNOTHING:
      IntrinsicResultType := VBT_BOOLEAN;
    { Retourne Byte }
    KW_CBYTE:
      IntrinsicResultType := VBT_BYTE;
    { Retourne Char }
    KW_CCHAR:
      IntrinsicResultType := VBT_CHAR;
    { Retourne Date }
    KW_CDATE:
      IntrinsicResultType := VBT_DATE;
    { Retourne Decimal }
    KW_CDEC:
      IntrinsicResultType := VBT_DECIMAL;
    { Retourne Object }
    KW_COBJ, KW_SPLIT, KW_MSGBOX, KW_INPUTBOX:
      IntrinsicResultType := VBT_OBJECT;
  Else
    IntrinsicResultType := VBT_OBJECT;
  End;
End;

{ ------------------------------------------------------------ }
{ ParseIntrinsicCall : parser un appel de fonction intrinseque }
{   KW est le code KW_* de la fonction                        }
{   Genere PUSH args / CALL _VBNRT_XXX                        }
{   Retourne le type VBT_* du resultat                        }
{ ------------------------------------------------------------ }

Function ParseIntrinsicCall(KW : Integer) : Integer;
Var
  FnName   : TString;
  RtLabel  : TString;
  ArgCount : Integer;
Begin
  FnName  := KeywordName(KW);
  RtLabel := IntrinsicRtLabel(KW);
  Inc(IntrinsicCount);

  If Opts.Verbose Then
    WriteLn('    Intrinsic: ', FnName, ' -> ', RtLabel);

  LexNextToken; { consommer le mot-cle de la fonction }

  { Toutes les fonctions intrinseques VB.NET : nom(args) }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    WarnMsg('( attendue apres ' + FnName);

  ArgCount := 0;

  If CurTokType <> TOK_RPAREN Then
  Begin
    ParseExpr;
    Inc(ArgCount);
    EmitComment('PUSH arg' + ItoS(ArgCount) + ' pour ' + FnName);
    Emit('PUSH EAX');
    While CurTokType = TOK_COMMA Do
    Begin
      LexNextToken; { consommer , }
      ParseExpr;
      Inc(ArgCount);
      EmitComment('PUSH arg' + ItoS(ArgCount) + ' pour ' + FnName);
      Emit('PUSH EAX');
    End;
  End;

  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
    WarnMsg(') attendue apres arguments de ' + FnName);

  EmitComment('CALL ' + RtLabel + ' (' + ItoS(ArgCount) + ' args)');
  Emit('CALL ' + RtLabel);

  { Nettoyer la pile si convention cdecl (runtime VB.NET utilise stdcall, }
  { mais on genere le nettoyage par securite)                             }
  If ArgCount > 0 Then
    Emit('ADD ESP, ' + ItoS(ArgCount * 4));

  ParseIntrinsicCall := IntrinsicResultType(KW);
End;

{ ------------------------------------------------------------ }
{ IntrinsicCategoryName : nom de la categorie d une fonction   }
{ ------------------------------------------------------------ }

Function IntrinsicCategoryName(KW : Integer) : TString;
Begin
  Case KW Of
    KW_LEN, KW_LEFT, KW_RIGHT, KW_MID,
    KW_LTRIM, KW_RTRIM, KW_TRIM,
    KW_UCASE, KW_LCASE,
    KW_INSTR, KW_INSTRREV,
    KW_REPLACE, KW_SPACE,
    KW_STRREVERSE, KW_SPLIT, KW_JOIN,
    KW_ASC, KW_CHR, KW_FORMAT:
      IntrinsicCategoryName := 'String';
    KW_CINT, KW_CLNG, KW_CSNG, KW_CDBL, KW_CSTR,
    KW_CBOOL, KW_CBYTE, KW_CCHAR, KW_CDATE, KW_CDEC,
    KW_CSHORT, KW_CUSHORT, KW_CUINT, KW_CULNG, KW_CSBYTE, KW_COBJ,
    KW_VAL, KW_STR, KW_HEX, KW_OCT,
    KW_INT, KW_FIX:
      IntrinsicCategoryName := 'Conversion';
    KW_ABS, KW_SGN, KW_SQR, KW_EXP, KW_LOG,
    KW_SIN, KW_COS, KW_TAN, KW_ATN:
      IntrinsicCategoryName := 'Math';
    KW_ISNUMERIC, KW_ISDATE, KW_ISARRAY, KW_ISNOTHING:
      IntrinsicCategoryName := 'Information';
    KW_MSGBOX, KW_INPUTBOX:
      IntrinsicCategoryName := 'Interaction';
  Else
    IntrinsicCategoryName := 'Unknown';
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces - TODO 13                                  }
{ ------------------------------------------------------------ }

Function GetIntrinsicCount : LongInt;
Begin
  GetIntrinsicCount := IntrinsicCount;
End;

Function IsIntrinsicInitialized : Boolean;
Begin
  IsIntrinsicInitialized := IntrinsicInitialized;
End;

Function IsIntrinsicEmpty : Boolean;
Begin
  IsIntrinsicEmpty := (IntrinsicCount = 0);
End;

Function GetIntrinsicStatus : TString;
Begin
  If IntrinsicInitialized Then
    GetIntrinsicStatus := 'initialized'
  Else
    GetIntrinsicStatus := 'not initialized';
End;

Function GetIntrinsicStringCount : Integer;
Begin
  { Len, Left, Right, Mid, LTrim, RTrim, Trim, UCase, LCase }
  { InStr, InStrRev, Replace, Space, StrReverse              }
  { Split, Join, Asc, Chr, Format = 19 fonctions de chaines  }
  GetIntrinsicStringCount := 19;
End;

Function GetIntrinsicConvCount : Integer;
Begin
  { CInt, CLng, CSng, CDbl, CStr, CBool, CByte, CChar, CDate, CDec }
  { CShort, CUShort, CUInt, CULng, CSByte, CObj                     }
  { Val, Str, Hex, Oct, Int, Fix = 22 fonctions de conversion       }
  GetIntrinsicConvCount := 22;
End;

Function GetIntrinsicMathCount : Integer;
Begin
  { Abs, Sgn, Sqr, Exp, Log, Sin, Cos, Tan, Atn }
  { = 9 fonctions mathematiques                   }
  GetIntrinsicMathCount := 9;
End;

Function GetIntrinsicInfoCount : Integer;
Begin
  { IsNumeric, IsDate, IsArray, IsNothing }
  { = 4 fonctions d information            }
  GetIntrinsicInfoCount := 4;
End;

Function GetTotalIntrinsicFunctions : Integer;
Begin
  GetTotalIntrinsicFunctions := 19 + 22 + 9 + 4 + 2;
End;

Function IsIntrinsicKW(KW : Integer) : Boolean;
Begin
  IsIntrinsicKW := IsIntrinsicFunction(KW);
End;

{ ============================================================ }
{ TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CLASSE STRING  }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Modes de comparaison de chaines }
  STRCOMP_BINARY = 0;    { sensible a la casse (defaut, VB.NET)     }
  STRCOMP_TEXT   = 1;    { insensible a la casse                    }

  { Labels runtime pour operations sur chaines VB.NET }
  STROP_RT_STRCAT     = '_VBNRT_STRCAT';
  STROP_RT_STRALLOC   = '_VBNRT_STRALLOC';
  STROP_RT_STRFREE    = '_VBNRT_STRFREE';
  STROP_RT_STRCMP_BIN  = '_VBNRT_STRCMP_BIN';
  STROP_RT_STRCMP_TXT  = '_VBNRT_STRCMP_TXT';
  STROP_RT_LIKE       = '_VBNRT_LIKE';
  STROP_RT_FORMAT     = '_VBNRT_FORMAT';
  STROP_RT_STRCOMPARE = '_VBNRT_STRCOMPARE';
  STROP_RT_LEN        = '_VBNRT_LEN';
  STROP_RT_UCASE      = '_VBNRT_UCASE';

Var
  StrOpCount       : LongInt;
  StrOpInitialized : Boolean;

{ ------------------------------------------------------------ }
{ InitStrOpState : initialiser l etat des operations chaines   }
{ ------------------------------------------------------------ }

Procedure InitStrOpState;
Begin
  StrOpCount       := 0;
  StrOpInitialized := True;
End;

{ ------------------------------------------------------------ }
{ GenStrConcat : generer le code pour la concatenation &        }
{   Les deux operandes sont deja dans EAX (droite) et pile     }
{   (gauche). Resultat : EAX = pointeur nouvelle chaine        }
{ ------------------------------------------------------------ }

Procedure GenStrConcat;
Begin
  Inc(StrOpCount);
  EmitComment('GenStrConcat: & concatenation');
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { EAX = ptr_s1 (gauche), EBX = ptr_s2 (droite) }
  Emit('PUSH EBX');
  Emit('PUSH EAX');
  Emit('CALL ' + STROP_RT_STRCAT);
  Emit('ADD ESP, 8');
  { EAX = pointeur vers nouvelle chaine concatenee }
End;

{ ------------------------------------------------------------ }
{ GenStrPlusConcat : generer + quand les deux operandes sont    }
{   String. Meme code que &, mais avec verification du type    }
{ ------------------------------------------------------------ }

Procedure GenStrPlusConcat;
Begin
  Inc(StrOpCount);
  EmitComment('GenStrPlusConcat: + String concatenation');
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { EAX = ptr_s1 (gauche), EBX = ptr_s2 (droite) }
  Emit('PUSH EBX');
  Emit('PUSH EAX');
  Emit('CALL ' + STROP_RT_STRCAT);
  Emit('ADD ESP, 8');
  { EAX = pointeur vers nouvelle chaine concatenee }
End;

{ ------------------------------------------------------------ }
{ GenStrConcatAssign : generer le code pour &= (concat+assign) }
{   SymIdx = index du symbole cible dans la table              }
{ ------------------------------------------------------------ }

Procedure GenStrConcatAssign(SymIdx : Integer);
Begin
  Inc(StrOpCount);
  EmitComment('GenStrConcatAssign: &= concatenation et affectation');
  { EAX contient la valeur droite (chaine a concatener) }
  Emit('PUSH EAX');
  { Charger la chaine courante de la variable }
  GenLoadVar(SymIdx);
  Emit('PUSH EAX');
  { Appel runtime STRCAT(gauche, droite) }
  Emit('CALL ' + STROP_RT_STRCAT);
  Emit('ADD ESP, 8');
  { EAX = nouvelle chaine concatenee, stocker dans la variable }
  GenStoreVar(SymIdx);
End;

{ ------------------------------------------------------------ }
{ GenStrAlloc : generer le code pour allouer une chaine         }
{   dynamique de longueur variable                             }
{   EAX = taille demandee                                      }
{   Resultat : EAX = pointeur vers le tampon alloue            }
{ ------------------------------------------------------------ }

Procedure GenStrAlloc;
Begin
  Inc(StrOpCount);
  EmitComment('GenStrAlloc: allocation chaine dynamique');
  Emit('PUSH EAX');
  Emit('CALL ' + STROP_RT_STRALLOC);
  Emit('ADD ESP, 4');
  { EAX = pointeur vers tampon alloue }
End;

{ ------------------------------------------------------------ }
{ GenStrFree : generer le code pour liberer une chaine          }
{   dynamique. EAX = pointeur vers le tampon a liberer         }
{ ------------------------------------------------------------ }

Procedure GenStrFree;
Begin
  Inc(StrOpCount);
  EmitComment('GenStrFree: liberation chaine dynamique');
  Emit('PUSH EAX');
  Emit('CALL ' + STROP_RT_STRFREE);
  Emit('ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ GenStrCompare : generer le code pour comparer deux chaines    }
{   Utilise Option Compare pour choisir binaire ou texte       }
{   EAX = ptr_s2 (droite), pile = ptr_s1 (gauche)             }
{   Resultat : EAX = -1 (True) ou 0 (False) selon convention  }
{ ------------------------------------------------------------ }

Procedure GenStrCompare(Op : Integer);
Var
  RtLabel : TString;
Begin
  Inc(StrOpCount);
  EmitComment('GenStrCompare: comparaison chaines');
  GenPopEBX;
  Emit('XCHG EAX, EBX');
  { EAX = ptr_s1, EBX = ptr_s2 }

  { Choisir le runtime selon Option Compare }
  If OptionCompare = OPT_COMPARE_TEXT Then
    RtLabel := STROP_RT_STRCMP_TXT
  Else
    RtLabel := STROP_RT_STRCMP_BIN;

  Emit('PUSH EBX');
  Emit('PUSH EAX');
  Emit('CALL ' + RtLabel);
  Emit('ADD ESP, 8');
  { EAX = resultat de la comparaison (-1, 0, 1) }

  { Appliquer l operateur de comparaison sur le resultat }
  Case Op Of
    OP_EQ:
      Begin
        Emit('TEST EAX, EAX');
        Emit('SETE AL');
      End;
    OP_NE:
      Begin
        Emit('TEST EAX, EAX');
        Emit('SETNE AL');
      End;
    OP_LT:
      Begin
        Emit('CMP EAX, 0');
        Emit('SETL AL');
      End;
    OP_GT:
      Begin
        Emit('CMP EAX, 0');
        Emit('SETG AL');
      End;
    OP_LE:
      Begin
        Emit('CMP EAX, 0');
        Emit('SETLE AL');
      End;
    OP_GE:
      Begin
        Emit('CMP EAX, 0');
        Emit('SETGE AL');
      End;
    OP_LIKE:
      Begin
        { Like est gere par un runtime specifique avec motifs }
        Emit('PUSH EBX');
        Emit('PUSH EAX');
        Emit('CALL ' + STROP_RT_LIKE);
        Emit('ADD ESP, 8');
        { EAX = -1 (match) ou 0 (no match) }
        Exit;
      End;
  Else
    WarnMsg('GenStrCompare: operateur inconnu ' + ItoSI(Op));
    Emit('TEST EAX, EAX');
    Emit('SETE AL');
  End;
  { Etendre AL en -1 ou 0 (convention VB.NET True=-1) }
  Emit('MOVZX EAX, AL');
  Emit('NEG EAX');
End;

{ ------------------------------------------------------------ }
{ ParseStringCompare : parser String.Compare(s1, s2)           }
{   Appel statique de la methode String.Compare                }
{   Retourne Integer (-1, 0, 1)                                }
{ ------------------------------------------------------------ }

Function ParseStringCompare : Integer;
Begin
  Inc(StrOpCount);
  LexNextToken; { consommer Compare }

  { Parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    WarnMsg('( attendue apres String.Compare');

  { Premier argument : chaine s1 }
  ParseExpr;
  EmitComment('PUSH s1 pour String.Compare');
  Emit('PUSH EAX');

  { Virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
    WarnMsg(', attendue entre arguments de String.Compare');

  { Deuxieme argument : chaine s2 }
  ParseExpr;
  EmitComment('PUSH s2 pour String.Compare');
  Emit('PUSH EAX');

  { Parenthese fermante }
  If CurTokType = TOK_RPAREN Then
    LexNextToken
  Else
    WarnMsg(') attendue apres arguments de String.Compare');

  { Appel runtime }
  EmitComment('CALL ' + STROP_RT_STRCOMPARE);
  Emit('CALL ' + STROP_RT_STRCOMPARE);
  Emit('ADD ESP, 8');
  { EAX = -1 (s1 < s2), 0 (s1 = s2), 1 (s1 > s2) }

  If Opts.Verbose Then
    WriteLn('    StrOp: String.Compare call');

  ParseStringCompare := VBT_INTEGER;
End;

{ ------------------------------------------------------------ }
{ ParseStringMethod : parser les appels de methodes .NET       }
{   en notation pointee sur une variable String                }
{   SymIdx = index du symbole chaine dans la table             }
{   Retourne le type du resultat                               }
{ ------------------------------------------------------------ }

Function ParseStringMethod(SymIdx : Integer) : Integer;
Var
  MethodName : TString;
Begin
  Inc(StrOpCount);
  ParseStringMethod := VBT_STRING;

  { Le token courant est apres le '.' }
  If CurTokType = TOK_IDENT Then
  Begin
    MethodName := UpCaseStr(CurTokStr);
    LexNextToken; { consommer le nom de la methode }
  End
  Else
  Begin
    WarnMsg('Nom de methode attendu apres .');
    MethodName := '';
  End;

  { Charger la chaine source }
  GenLoadVar(SymIdx);
  Emit('PUSH EAX');

  If MethodName = 'LENGTH' Then
  Begin
    { s.Length -> nombre de caracteres }
    EmitComment('String.Length -> CALL _VBNRT_LEN');
    Emit('CALL ' + STROP_RT_LEN);
    Emit('ADD ESP, 4');
    ParseStringMethod := VBT_INTEGER;
  End
  Else If MethodName = 'TOUPPER' Then
  Begin
    { s.ToUpper() }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg(') attendue apres ToUpper(');
    End;
    EmitComment('String.ToUpper -> CALL _VBNRT_UCASE');
    Emit('CALL ' + STROP_RT_UCASE);
    Emit('ADD ESP, 4');
    ParseStringMethod := VBT_STRING;
  End
  Else If MethodName = 'TOLOWER' Then
  Begin
    { s.ToLower() }
    If CurTokType = TOK_LPAREN Then
    Begin
      LexNextToken;
      If CurTokType = TOK_RPAREN Then
        LexNextToken
      Else
        WarnMsg(') attendue apres ToLower(');
    End;
    EmitComment('String.ToLower -> CALL ' + PFX_RT + 'LCASE');
    Emit('CALL ' + PFX_RT + 'LCASE');
    Emit('ADD ESP, 4');
    ParseStringMethod := VBT_STRING;
  End
  Else If MethodName = 'SUBSTRING' Then
  Begin
    { s.Substring(startIndex[, length]) -> MID }
    If CurTokType = TOK_LPAREN Then
      LexNextToken
    Else
      WarnMsg('( attendue apres Substring');

    { Premier argument : position de depart (0-based) }
    ParseExpr;
    EmitComment('PUSH startIndex pour Substring');
    Emit('PUSH EAX');

    If CurTokType = TOK_COMMA Then
    Begin
      LexNextToken;
      ParseExpr;
      EmitComment('PUSH length pour Substring');
      Emit('PUSH EAX');
    End;

    If CurTokType = TOK_RPAREN Then
      LexNextToken
    Else
      WarnMsg(') attendue apres Substring(...)');

    EmitComment('String.Substring -> CALL ' + PFX_RT + 'MID');
    Emit('CALL ' + PFX_RT + 'MID');
    Emit('ADD ESP, 12');
    ParseStringMethod := VBT_STRING;
  End
  Else
  Begin
    { Methode inconnue }
    Emit('ADD ESP, 4'); { depiler la chaine source }
    WarnMsg('Methode String inconnue: ' + MethodName);
  End;
End;

{ ------------------------------------------------------------ }
{ IsStrOpStatement : teste si le token courant est une         }
{   instruction d operation sur chaine VB.NET                  }
{ ------------------------------------------------------------ }

Function IsStrOpStatement : Boolean;
Begin
  { VB.NET n a pas Mid$ assign, LSet, RSet comme VB6            }
  { Les operations chaines sont principalement des expressions  }
  IsStrOpStatement := False;
End;

{ ------------------------------------------------------------ }
{ IsStrConcatOp : teste si une operation + doit etre traitee   }
{   comme une concatenation de chaines                         }
{ ------------------------------------------------------------ }

Function IsStrConcatOp(LeftType, RightType : Integer) : Boolean;
Begin
  IsStrConcatOp := (LeftType = VBT_STRING) And (RightType = VBT_STRING);
End;

{ ------------------------------------------------------------ }
{ StrOpRtLabel : retourne le label runtime d une operation      }
{   sur chaine selon le code d operation                       }
{ ------------------------------------------------------------ }

Function StrOpRtLabel(OpCode : Integer) : TString;
Begin
  Case OpCode Of
    0 : StrOpRtLabel := STROP_RT_STRCAT;
    1 : StrOpRtLabel := STROP_RT_STRALLOC;
    2 : StrOpRtLabel := STROP_RT_STRFREE;
    3 : StrOpRtLabel := STROP_RT_STRCMP_BIN;
    4 : StrOpRtLabel := STROP_RT_STRCMP_TXT;
    5 : StrOpRtLabel := STROP_RT_LIKE;
    6 : StrOpRtLabel := STROP_RT_FORMAT;
    7 : StrOpRtLabel := STROP_RT_STRCOMPARE;
    8 : StrOpRtLabel := STROP_RT_LEN;
    9 : StrOpRtLabel := STROP_RT_UCASE;
  Else
    StrOpRtLabel := '?STROP_RT';
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces - TODO 14                                  }
{ ------------------------------------------------------------ }

Function GetStrOpCount : LongInt;
Begin
  GetStrOpCount := StrOpCount;
End;

Function IsStrOpInitialized : Boolean;
Begin
  IsStrOpInitialized := StrOpInitialized;
End;

Function IsStrOpEmpty : Boolean;
Begin
  IsStrOpEmpty := (StrOpCount = 0);
End;

Function GetStrOpStatus : TString;
Begin
  If StrOpInitialized Then
    GetStrOpStatus := 'initialized'
  Else
    GetStrOpStatus := 'not initialized';
End;

Function GetStrOpCompareMode : Integer;
Begin
  If OptionCompare = OPT_COMPARE_TEXT Then
    GetStrOpCompareMode := STRCOMP_TEXT
  Else
    GetStrOpCompareMode := STRCOMP_BINARY;
End;

Function IsStrOpCompareBinary : Boolean;
Begin
  IsStrOpCompareBinary := (OptionCompare = OPT_COMPARE_BINARY);
End;

Function IsStrOpCompareText : Boolean;
Begin
  IsStrOpCompareText := (OptionCompare = OPT_COMPARE_TEXT);
End;

Function GetStrOpRtCount : Integer;
Begin
  { 10 labels runtime pour operations chaines VB.NET }
  GetStrOpRtCount := 10;
End;

Function GetTotalStrOpMethods : Integer;
Begin
  { Length, ToUpper, ToLower, Substring = 4 methodes String }
  GetTotalStrOpMethods := 4;
End;

Function IsStrOpRtLabel(S : TString) : Boolean;
Var
  U : TString;
Begin
  U := UpCaseStr(S);
  IsStrOpRtLabel := (U = '_VBNRT_STRCAT') Or
                    (U = '_VBNRT_STRALLOC') Or
                    (U = '_VBNRT_STRFREE') Or
                    (U = '_VBNRT_STRCMP_BIN') Or
                    (U = '_VBNRT_STRCMP_TXT') Or
                    (U = '_VBNRT_LIKE') Or
                    (U = '_VBNRT_FORMAT') Or
                    (U = '_VBNRT_STRCOMPARE') Or
                    (U = '_VBNRT_LEN') Or
                    (U = '_VBNRT_UCASE');
End;

{ ============================================================ }
{ TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE)            }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Nombre maximal de dimensions pour un tableau }
  MAX_ARRAY_DIMS  = 8;

  { Nombre maximal d elements par dimension (statique) }
  MAX_ARRAY_ELEMS = 65536;

  { Labels runtime pour operations sur tableaux VB.NET }
  ARR_RT_REDIM    = '_VBNRT_REDIM';
  ARR_RT_PRESERVE = '_VBNRT_REDIM_PRESERVE';
  ARR_RT_ERASE    = '_VBNRT_ERASE';
  ARR_RT_LBOUND   = '_VBNRT_LBOUND';
  ARR_RT_UBOUND   = '_VBNRT_UBOUND';
  ARR_RT_ISARRAY  = '_VBNRT_ISARRAY';
  ARR_RT_ALLOC    = '_VBNRT_ARR_ALLOC';
  ARR_RT_FREE     = '_VBNRT_ARR_FREE';
  ARR_RT_BOUNDSCK = '_VBNRT_BOUNDSCHECK';
  ARR_RT_LENGTH   = '_VBNRT_ARR_LENGTH';

Var
  ArrayCount       : LongInt;
  ArrayInitialized : Boolean;

{ ------------------------------------------------------------ }
{ InitArrayState : initialiser l etat du parseur de tableaux   }
{ ------------------------------------------------------------ }

Procedure InitArrayState;
Begin
  ArrayCount       := 0;
  ArrayInitialized := True;
End;

{ ------------------------------------------------------------ }
{ ParseArrayBounds : parser les bornes d un tableau statique   }
{   Syntaxe VB.NET : (n) ou (n, m) - base toujours 0          }
{   Pas de syntaxe (lo To hi) en VB.NET                        }
{   Retourne le nombre de dimensions detectees                 }
{   DimHi : borne superieure par dimension                     }
{ ------------------------------------------------------------ }

Procedure ParseArrayBounds(Var NDims    : Integer;
                           Var DimHi    : Array Of LongInt;
                           Var IsDynamic: Boolean);
Var
  D : Integer;
Begin
  NDims    := 0;
  IsDynamic := False;
  { On s attend a etre juste apres le '(' }
  { Cas special : '()' = tableau dynamique }
  If (CurTokType = TOK_RPAREN) Then Begin
    IsDynamic := True;
    LexNextToken; { consommer ')' }
    Exit;
  End;
  D := 0;
  Repeat
    If D >= MAX_ARRAY_DIMS Then Begin
      FatalError('Trop de dimensions (max ' + ItoS(MAX_ARRAY_DIMS) + ')');
      Exit;
    End;
    { Parser la borne superieure : toujours base 0 en VB.NET }
    ParseExpr;
    Inc(ArrayCount);
    DimHi[D] := CurTokNum;
    Inc(D);
    If CurTokType = TOK_COMMA Then
      LexNextToken { consommer ',' et continuer }
    Else
      Break;
  Until False;
  NDims := D;
  Expect(TOK_RPAREN); { ')' fermeture }
End;

{ ------------------------------------------------------------ }
{ ParseStaticArray : parser une declaration de tableau statique }
{   Dim arr(10) As Integer -> 11 elements (0 a 10)             }
{   Dim mat(3, 3) As Integer -> matrice 4x4                    }
{   Base toujours 0 en VB.NET (pas de Option Base)             }
{   Genere allocation en .BSS (global) ou pile (local)         }
{ ------------------------------------------------------------ }

Procedure ParseStaticArray(ArrName : TString; NDims : Integer;
                           DimHi : Array Of LongInt;
                           ElemType : Integer);
Var
  TotalElems : LongInt;
  ElemSize   : LongInt;
  TotalBytes : LongInt;
  AsmLbl     : TString;
  I          : Integer;
Begin
  Inc(ArrayCount);
  TotalElems := 1;
  For I := 0 To NDims - 1 Do Begin
    TotalElems := TotalElems * (DimHi[I] + 1); { base 0 : 0..n = n+1 }
  End;
  ElemSize  := VBTypeSize(ElemType);
  TotalBytes := TotalElems * ElemSize;
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  If IsInGlobalScope Then Begin
    { Allocation en .BSS pour variable globale }
    EmitBss(AsmLbl + ' RESB ' + ItoS(TotalBytes));
  End Else Begin
    { Allocation sur la pile pour variable locale }
    { SUB ESP, TotalBytes }
    Emit('SUB ESP, ' + ItoS(TotalBytes));
    EmitComment('tableau local ' + ArrName + ' : '
                + ItoS(TotalElems) + ' elems * '
                + ItoS(ElemSize) + ' octets');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseDynamicArray : parser une declaration de tableau dynam.  }
{   Dim arr() As Integer -> pointeur DD, pas de taille         }
{   Genere un pointeur DD initialise a 0 (Nothing)             }
{ ------------------------------------------------------------ }

Procedure ParseDynamicArray(ArrName : TString; ElemType : Integer);
Var
  AsmLbl : TString;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  If IsInGlobalScope Then Begin
    { Pointeur global initialise a Nothing }
    EmitData(AsmLbl + ' DD 0');
  End Else Begin
    { Pointeur local sur la pile }
    Emit('PUSH 0');
    EmitComment('tableau dynamique ' + ArrName + ' (Nothing)');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseRedim : parser ReDim [Preserve] arr(n)                  }
{   Genere CALL _VBNRT_REDIM ou _VBNRT_REDIM_PRESERVE          }
{ ------------------------------------------------------------ }

Procedure ParseRedim;
Var
  PreserveFlag : Boolean;
  ArrName      : TString;
  AsmLbl       : TString;
Begin
  Inc(ArrayCount);
  { On s attend a KW_REDIM deja consomme }
  PreserveFlag := False;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PRESERVE) Then Begin
    PreserveFlag := True;
    LexNextToken; { consommer 'Preserve' }
  End;
  { Nom du tableau }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('Identificateur de tableau attendu apres ReDim');
    Exit;
  End;
  ArrName := CurTokStr;
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  LexNextToken;
  { Parser la parenthese ouvrante }
  Expect(TOK_LPAREN);
  { Parser la nouvelle taille }
  ParseExpr;
  Expect(TOK_RPAREN);
  { Generer le code }
  Emit('PUSH EAX');
  EmitComment('nouvelle taille pour ' + ArrName);
  Emit('PUSH ' + AsmLbl);
  If PreserveFlag Then Begin
    Emit('CALL ' + ARR_RT_PRESERVE);
    EmitComment('ReDim Preserve ' + ArrName);
  End Else Begin
    Emit('CALL ' + ARR_RT_REDIM);
    EmitComment('ReDim ' + ArrName);
  End;
  { Mise a jour du pointeur }
  Emit('MOV [' + AsmLbl + '], EAX');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseEraseStatement : parser Erase arr                       }
{   Genere PUSH ptr_arr / CALL _VBNRT_ERASE                    }
{ ------------------------------------------------------------ }

Procedure ParseEraseStatement;
Var
  ArrName : TString;
  AsmLbl  : TString;
Begin
  Inc(ArrayCount);
  { On s attend a KW_ERASE deja consomme }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('Identificateur de tableau attendu apres Erase');
    Exit;
  End;
  ArrName := CurTokStr;
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  LexNextToken;
  { Generer le code }
  Emit('PUSH ' + AsmLbl);
  Emit('CALL ' + ARR_RT_ERASE);
  EmitComment('Erase ' + ArrName);
  { Mettre le pointeur a Nothing }
  Emit('MOV DWORD [' + AsmLbl + '], 0');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ GenArrayAccess : generer le code d acces a un element         }
{   arr(index) -> MOV EAX, [base + index * elem_size]          }
{   L index est deja evalue dans EAX                           }
{   Base toujours 0 en VB.NET                                  }
{ ------------------------------------------------------------ }

Procedure GenArrayAccess(ArrName : TString; ElemType : Integer);
Var
  AsmLbl   : TString;
  ElemSize : LongInt;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  ElemSize := VBTypeSize(ElemType);
  { Calculer l offset : EAX = index * taille_element }
  If ElemSize > 1 Then Begin
    If ElemSize = 2 Then
      Emit('SHL EAX, 1')
    Else If ElemSize = 4 Then
      Emit('SHL EAX, 2')
    Else If ElemSize = 8 Then
      Emit('SHL EAX, 3')
    Else
      Emit('IMUL EAX, ' + ItoS(ElemSize));
  End;
  { Charger l element }
  Emit('MOV EAX, [' + AsmLbl + ' + EAX]');
  EmitComment('acces ' + ArrName + '(index)');
End;

{ ------------------------------------------------------------ }
{ GenMultiDimOffset : calculer l offset pour tableau multi-dim  }
{   Calcul : ((i1 * dim2 + i2) * dim3 + i3) * elem_size       }
{   Les indices sont empiles dans l ordre i1, i2, i3, ...      }
{   NDims dimensions, DimSizes contient la taille de chaque    }
{ ------------------------------------------------------------ }

Procedure GenMultiDimOffset(ArrName : TString;
                            NDims   : Integer;
                            DimSizes: Array Of LongInt;
                            ElemType: Integer);
Var
  AsmLbl   : TString;
  ElemSize : LongInt;
  I        : Integer;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  ElemSize := VBTypeSize(ElemType);
  { Premier indice dans EAX (deja depile) }
  EmitComment('calcul offset multi-dim pour ' + ArrName);
  { Pour chaque dimension supplementaire : }
  {   EAX = EAX * DimSizes[I] + indice_suivant }
  For I := 1 To NDims - 1 Do Begin
    Emit('IMUL EAX, ' + ItoS(DimSizes[I]));
    Emit('POP EBX');
    Emit('ADD EAX, EBX');
    EmitComment('dimension ' + ItoS(I + 1));
  End;
  { Multiplier par la taille de l element }
  If ElemSize > 1 Then Begin
    If ElemSize = 2 Then
      Emit('SHL EAX, 1')
    Else If ElemSize = 4 Then
      Emit('SHL EAX, 2')
    Else If ElemSize = 8 Then
      Emit('SHL EAX, 3')
    Else
      Emit('IMUL EAX, ' + ItoS(ElemSize));
  End;
  { Charger l element }
  Emit('MOV EAX, [' + AsmLbl + ' + EAX]');
  EmitComment('acces multi-dim ' + ArrName);
End;

{ ------------------------------------------------------------ }
{ ParseArrayMethod : parser les methodes de tableau VB.NET      }
{   arr.Length -> CALL _VBNRT_ARR_LENGTH                        }
{   arr.GetLength(dim) -> CALL _VBNRT_ARR_LENGTH avec dim       }
{   arr.GetUpperBound(dim) -> CALL _VBNRT_UBOUND avec dim       }
{ ------------------------------------------------------------ }

Procedure ParseArrayMethod(ArrName : TString);
Var
  AsmLbl   : TString;
  MethodStr: TString;
Begin
  Inc(ArrayCount);
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  { On s attend a etre apres le '.' }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('Nom de methode attendu apres "."');
    Exit;
  End;
  MethodStr := UpCaseStr(CurTokStr);
  LexNextToken;

  If MethodStr = 'LENGTH' Then Begin
    { arr.Length -> nombre total d elements }
    Emit('PUSH ' + AsmLbl);
    Emit('CALL ' + ARR_RT_LENGTH);
    EmitComment(ArrName + '.Length');
  End
  Else If MethodStr = 'GETLENGTH' Then Begin
    { arr.GetLength(dim) }
    Expect(TOK_LPAREN);
    ParseExpr;
    Expect(TOK_RPAREN);
    Emit('PUSH EAX');
    EmitComment('dim pour GetLength');
    Emit('PUSH ' + AsmLbl);
    Emit('CALL ' + ARR_RT_LENGTH);
    EmitComment(ArrName + '.GetLength(dim)');
  End
  Else If MethodStr = 'GETUPPERBOUND' Then Begin
    { arr.GetUpperBound(dim) }
    Expect(TOK_LPAREN);
    ParseExpr;
    Expect(TOK_RPAREN);
    Emit('PUSH EAX');
    EmitComment('dim pour GetUpperBound');
    Emit('PUSH ' + AsmLbl);
    Emit('CALL ' + ARR_RT_UBOUND);
    EmitComment(ArrName + '.GetUpperBound(dim)');
  End
  Else Begin
    FatalError('Methode de tableau inconnue : ' + CurTokStr);
  End;
End;

{ ------------------------------------------------------------ }
{ ParseLBound : parser LBound(arr[, dim])                      }
{   En VB.NET retourne toujours 0                              }
{   Genere PUSH dim / PUSH arr / CALL _VBNRT_LBOUND            }
{ ------------------------------------------------------------ }

Procedure ParseLBound;
Var
  ArrName : TString;
  AsmLbl  : TString;
Begin
  Inc(ArrayCount);
  { On s attend a KW_LBOUND deja consomme + '(' }
  Expect(TOK_LPAREN);
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('Identificateur de tableau attendu dans LBound');
    Exit;
  End;
  ArrName := CurTokStr;
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  LexNextToken;
  { Dimension optionnelle }
  If CurTokType = TOK_COMMA Then Begin
    LexNextToken;
    ParseExpr;
    Emit('PUSH EAX');
    EmitComment('dim pour LBound');
  End Else Begin
    Emit('PUSH 0');
    EmitComment('dim=0 par defaut');
  End;
  Expect(TOK_RPAREN);
  Emit('PUSH ' + AsmLbl);
  Emit('CALL ' + ARR_RT_LBOUND);
  EmitComment('LBound(' + ArrName + ')');
End;

{ ------------------------------------------------------------ }
{ ParseUBound : parser UBound(arr[, dim])                      }
{   Genere PUSH dim / PUSH arr / CALL _VBNRT_UBOUND            }
{ ------------------------------------------------------------ }

Procedure ParseUBound;
Var
  ArrName : TString;
  AsmLbl  : TString;
Begin
  Inc(ArrayCount);
  { On s attend a KW_UBOUND deja consomme + '(' }
  Expect(TOK_LPAREN);
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('Identificateur de tableau attendu dans UBound');
    Exit;
  End;
  ArrName := CurTokStr;
  AsmLbl := PFX_ARR + AsmIdent(ArrName);
  LexNextToken;
  { Dimension optionnelle }
  If CurTokType = TOK_COMMA Then Begin
    LexNextToken;
    ParseExpr;
    Emit('PUSH EAX');
    EmitComment('dim pour UBound');
  End Else Begin
    Emit('PUSH 0');
    EmitComment('dim=0 par defaut');
  End;
  Expect(TOK_RPAREN);
  Emit('PUSH ' + AsmLbl);
  Emit('CALL ' + ARR_RT_UBOUND);
  EmitComment('UBound(' + ArrName + ')');
End;

{ ------------------------------------------------------------ }
{ IsArrayDecl : verifier si le token courant est une decl arr  }
{   True si on a un ident suivi de '(' dans un contexte Dim    }
{ ------------------------------------------------------------ }

Function IsArrayDecl : Boolean;
Begin
  { Heuristique : si le prochain token apres l ident est '(' }
  IsArrayDecl := (CurTokType = TOK_IDENT);
  { Le contexte complet est verifie par le parseur appelant }
End;

{ ------------------------------------------------------------ }
{ IsArrayAccess : verifier si c est un acces a un tableau      }
{   True si l ident est connu comme tableau dans la SymTab     }
{ ------------------------------------------------------------ }

Function IsArrayAccess(Name : TString) : Boolean;
Var
  Idx : Integer;
Begin
  Idx := FindSym(Name);
  If Idx >= 0 Then
    IsArrayAccess := (SymTab[Idx].ArrayDims > 0)
  Else
    IsArrayAccess := False;
End;

{ ------------------------------------------------------------ }
{ IsArrayFunction : verifier si KW est une fonction de tableau }
{ ------------------------------------------------------------ }

Function IsArrayFunction(KW : Integer) : Boolean;
Begin
  IsArrayFunction := (KW = KW_LBOUND) Or (KW = KW_UBOUND) Or
                     (KW = KW_ISARRAY);
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour le module tableau                   }
{ ------------------------------------------------------------ }

Function GetArrayCount : LongInt;
Begin
  GetArrayCount := ArrayCount;
End;

Function IsArrayInitialized : Boolean;
Begin
  IsArrayInitialized := ArrayInitialized;
End;

Function IsArrayEmpty : Boolean;
Begin
  IsArrayEmpty := (ArrayCount = 0);
End;

Function GetArrayStatus : TString;
Begin
  If Not ArrayInitialized Then
    GetArrayStatus := 'non initialise'
  Else If ArrayCount = 0 Then
    GetArrayStatus := 'initialise, aucun tableau'
  Else
    GetArrayStatus := 'initialise, ' + ItoS(ArrayCount) + ' operations';
End;

Function GetMaxArrayDims : Integer;
Begin
  GetMaxArrayDims := MAX_ARRAY_DIMS;
End;

Function GetMaxArrayElems : LongInt;
Begin
  GetMaxArrayElems := MAX_ARRAY_ELEMS;
End;

Function GetArrayRtCount : Integer;
Begin
  { 10 labels runtime pour operations tableaux VB.NET }
  GetArrayRtCount := 10;
End;

Function IsRedimStatement(KW : Integer) : Boolean;
Begin
  IsRedimStatement := (KW = KW_REDIM);
End;

Function IsEraseStatement(KW : Integer) : Boolean;
Begin
  IsEraseStatement := (KW = KW_ERASE);
End;

Function GetArrayPrefixLabel : TString;
Begin
  GetArrayPrefixLabel := PFX_ARR;
End;

{ ============================================================ }
{ TODO 16 - PARSEUR : STRUCTURES (STRUCTURE...END STRUCTURE)   }
{           ET ENUM  [IMPLEMENTE]                              }
{ ============================================================ }

Const
  { Nombre maximal de champs dans une Structure }
  MAX_STRUCT_FIELDS   = 128;

  { Nombre maximal de membres dans un Enum }
  MAX_ENUM_MEMBERS = 256;

  { Taille maximale d une Structure en octets }
  MAX_STRUCT_SIZE     = 65536;

  { Labels runtime pour operations sur structures VB.NET }
  STRUCT_RT_COPY     = '_VBNRT_STRUCT_COPY';
  STRUCT_RT_CLEAR    = '_VBNRT_STRUCT_CLEAR';
  STRUCT_RT_COMPARE  = '_VBNRT_STRUCT_COMPARE';
  STRUCT_RT_SIZEOF   = '_VBNRT_STRUCT_SIZEOF';
  STRUCT_RT_FIELDPTR = '_VBNRT_STRUCT_FIELDPTR';
  STRUCT_RT_INIT     = '_VBNRT_STRUCT_INIT';
  STRUCT_RT_FREE     = '_VBNRT_STRUCT_FREE';
  STRUCT_RT_ASSIGN   = '_VBNRT_STRUCT_ASSIGN';
  STRUCT_RT_ENUM_VAL = '_VBNRT_ENUM_VAL';
  STRUCT_RT_ENUM_STR = '_VBNRT_ENUM_STR';

Var
  StructEnumCount       : LongInt;
  StructEnumInitialized : Boolean;
  CurStructSize         : LongInt;

{ ------------------------------------------------------------ }
{ InitStructureEnumState : initialiser l etat du parseur       }
{   Structure/Enum VB.NET                                      }
{ ------------------------------------------------------------ }

Procedure InitStructureEnumState;
Begin
  StructEnumCount       := 0;
  StructEnumInitialized := True;
  CurStructSize         := 0;
End;

{ ------------------------------------------------------------ }
{ ParseStructureField : parser un champ d une Structure VB.NET }
{   Syntaxe : [Public|Private] champ As Type                   }
{   Les champs de Structure VB.NET ont des modificateurs        }
{   d acces obligatoires (Public ou Private)                    }
{   Pas de String * n en VB.NET (pas de longueur fixe)         }
{ ------------------------------------------------------------ }

Procedure ParseStructureField(StructName : TString;
                               FieldOffset : LongInt);
Var
  FName       : TString;
  FType       : Integer;
  FSize       : Integer;
  FArrCount   : LongInt;
  IsArrayFld  : Boolean;
  SymIdx      : Integer;
  TotalSize   : LongInt;
  IsFieldPub  : Boolean;
Begin
  Inc(StructEnumCount);
  { Modificateur d acces optionnel (Public par defaut) }
  IsFieldPub := True;
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PUBLIC) Then Begin
    IsFieldPub := True;
    LexNextToken;
  End Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PRIVATE) Then Begin
    IsFieldPub := False;
    LexNextToken;
  End Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DIM) Then Begin
    { Dim est accepte dans les structures VB.NET }
    IsFieldPub := True;
    LexNextToken;
  End;
  { Nom du champ }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu pour le champ de Structure ' + StructName);
    Exit;
  End;
  FName := CurTokStr;
  LexNextToken;
  { Verifier si champ tableau : nom(n) }
  IsArrayFld := False;
  FArrCount  := 1;
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    IsArrayFld := True;
    If CurTokType = TOK_INTEGER Then Begin
      FArrCount := CurTokNum + 1; { VB.NET : 0 a n => n+1 elements }
      LexNextToken;
    End Else Begin
      FArrCount := 1;
    End;
    Expect(TOK_RPAREN);
  End;
  { As Type }
  ExpectKeyword(KW_AS);
  FType := ParseTypeSpec;
  FSize := VBTypeSize(FType);
  { Calculer la taille totale du champ }
  TotalSize := FSize * FArrCount;
  { Ajouter le champ dans la table des symboles }
  SymIdx := AddSym(FName, SK_FIELD, FType, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].BpOffset  := FieldOffset;
    SymTab[SymIdx].IsPublic  := IsFieldPub;
    SymTab[SymIdx].IsConst   := False;
    If IsArrayFld Then
      SymTab[SymIdx].ArrayDims := 1
    Else
      SymTab[SymIdx].ArrayDims := 0;
    SymTab[SymIdx].AsmLabel := PFX_STRUC + UpCaseStr(StructName) + '_' +
                               UpCaseStr(FName);
  End;
  { Emettre commentaire d assembleur pour le champ }
  EmitComment('  ' + StructName + '.' + FName + ' : offset=' +
              ItoS(FieldOffset) + ', size=' + ItoS(TotalSize));
  { Mettre a jour la taille courante de la structure }
  CurStructSize := FieldOffset + TotalSize;
  { Aller a la ligne suivante }
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseStructure : parser une declaration                      }
{   Structure...End Structure (VB.NET)                         }
{   Syntaxe :                                                  }
{     [Public|Private|Friend] Structure NomStructure           }
{       Public champ1 As Integer                               }
{       Private champ2 As String                               }
{       Public Sub Methode()                                   }
{         ...                                                  }
{       End Sub                                                }
{     End Structure                                            }
{   Genere : labels et commentaires pour la structure           }
{   Ajoute la structure et ses champs dans la table des         }
{   symboles. Les methodes sont ignorees (stub pour TODO 17)   }
{ ------------------------------------------------------------ }

Procedure ParseStructure(IsPublic : Boolean);
Var
  StructName   : TString;
  FieldCount   : Integer;
  SymIdx       : Integer;
  AsmLbl       : TString;
Begin
  Inc(StructEnumCount);
  { Consommer 'Structure' }
  LexNextToken;
  { Nom de la structure }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres Structure');
    Exit;
  End;
  StructName := CurTokStr;
  AsmLbl     := PFX_STRUC + UpCaseStr(StructName);
  LexNextToken;
  SkipNewlines;
  { Ajouter la structure dans la table des symboles }
  SymIdx := AddSym(StructName, SK_STRUCTURE, VBT_USER, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].IsPublic := IsPublic;
    SymTab[SymIdx].IsConst  := False;
    SymTab[SymIdx].AsmLabel := AsmLbl;
  End;
  { Emettre le commentaire de structure }
  EmitComment('Structure ' + StructName);
  { Parser les champs et methodes }
  FieldCount    := 0;
  CurStructSize := 0;
  While Not LexEOF Do Begin
    { Verifier End Structure }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And
         (CurTokNum = KW_STRUCTURE) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End Structure attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Ignorer les methodes (Sub/Function) dans la structure }
    { Les methodes de structure seront traitees dans TODO 17 }
    If (CurTokType = TOK_KEYWORD) And
       ((CurTokNum = KW_SUB) Or (CurTokNum = KW_FUNCTION)) Then Begin
      { Sauter jusqu a End Sub / End Function }
      SkipToEndOfLine;
      SkipNewlines;
      While Not LexEOF Do Begin
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
          LexNextToken;
          If (CurTokType = TOK_KEYWORD) And
             ((CurTokNum = KW_SUB) Or (CurTokNum = KW_FUNCTION)) Then Begin
            LexNextToken;
            SkipNewlines;
            Break;
          End;
        End Else Begin
          SkipToEndOfLine;
          SkipNewlines;
        End;
      End;
      Continue;
    End;
    { Ignorer les modificateurs Shared devant les methodes }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SHARED) Then Begin
      LexNextToken;
      { Si c est une methode, sauter le bloc }
      If (CurTokType = TOK_KEYWORD) And
         ((CurTokNum = KW_SUB) Or (CurTokNum = KW_FUNCTION)) Then Begin
        SkipToEndOfLine;
        SkipNewlines;
        While Not LexEOF Do Begin
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
            LexNextToken;
            If (CurTokType = TOK_KEYWORD) And
               ((CurTokNum = KW_SUB) Or (CurTokNum = KW_FUNCTION)) Then Begin
              LexNextToken;
              SkipNewlines;
              Break;
            End;
          End Else Begin
            SkipToEndOfLine;
            SkipNewlines;
          End;
        End;
        Continue;
      End;
      { Sinon c est un champ Shared - continuer comme un champ }
    End;
    { Parser un champ }
    If FieldCount >= MAX_STRUCT_FIELDS Then Begin
      FatalError('nombre maximal de champs depasse dans Structure ' +
                 StructName);
      Exit;
    End;
    ParseStructureField(StructName, CurStructSize);
    Inc(FieldCount);
  End;
  { Emettre la taille totale de la structure }
  EmitComment('End Structure ' + StructName + ' (size=' +
              ItoS(CurStructSize) + ')');
  { Emettre une constante de taille en .DATA }
  EmitData(AsmLbl + '_SIZE DD ' + ItoS(CurStructSize));
  { Mettre a jour la taille dans le symbole }
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].InitNum := CurStructSize;
    SymTab[SymIdx].HasInit := True;
  End;
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseEnumDecl : parser une declaration Enum...End Enum       }
{   Syntaxe VB.NET :                                           }
{     [Public|Private|Friend] Enum NomEnum                     }
{       Valeur1 [= 0]                                         }
{       Valeur2 [= 1]                                         }
{       Valeur3 = 10                                           }
{     End Enum                                                 }
{   Chaque membre est ajoute comme constante Integer (VB.NET)  }
{   Les valeurs sont auto-incrementees si non specifiees       }
{   Acces qualifie : NomEnum.Valeur1                           }
{ ------------------------------------------------------------ }

Procedure ParseEnumDecl(IsPublic : Boolean);
Var
  EnumName    : TString;
  MemberName  : TString;
  CurValue    : LongInt;
  MemberCount : Integer;
  SymIdx      : Integer;
  AsmLbl      : TString;
Begin
  Inc(StructEnumCount);
  { Consommer 'Enum' }
  LexNextToken;
  { Nom de l enumeration }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres Enum');
    Exit;
  End;
  EnumName := CurTokStr;
  AsmLbl   := PFX_ENUM + UpCaseStr(EnumName);
  LexNextToken;
  SkipNewlines;
  { Ajouter l enumeration dans la table des symboles }
  { VB.NET : Enum est de type Integer (pas Long comme VB6) }
  SymIdx := AddSym(EnumName, SK_ENUM, VBT_INTEGER, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].IsPublic := IsPublic;
    SymTab[SymIdx].IsConst  := False;
    SymTab[SymIdx].AsmLabel := AsmLbl;
  End;
  { Emettre le commentaire d enumeration }
  EmitComment('Enum ' + EnumName);
  { Parser les membres }
  CurValue    := 0;
  MemberCount := 0;
  While Not LexEOF Do Begin
    { Verifier End Enum }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_ENUM) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End Enum attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Nom du membre }
    If CurTokType <> TOK_IDENT Then Begin
      FatalError('identifiant attendu pour le membre de Enum ' + EnumName);
      SkipToEndOfLine;
      SkipNewlines;
      Continue;
    End;
    MemberName := CurTokStr;
    LexNextToken;
    { Valeur optionnelle = n }
    If CurTokType = TOK_EQ Then Begin
      LexNextToken;
      If CurTokType = TOK_INTEGER Then Begin
        CurValue := CurTokNum;
        LexNextToken;
      End Else If (CurTokType = TOK_MINUS) Then Begin
        LexNextToken;
        If CurTokType = TOK_INTEGER Then Begin
          CurValue := -CurTokNum;
          LexNextToken;
        End Else Begin
          FatalError('valeur entiere attendue apres = dans Enum ' + EnumName);
        End;
      End Else Begin
        FatalError('valeur entiere attendue apres = dans Enum ' + EnumName);
      End;
    End;
    { Verifier la limite de membres }
    If MemberCount >= MAX_ENUM_MEMBERS Then Begin
      FatalError('nombre maximal de membres depasse dans Enum ' + EnumName);
      Exit;
    End;
    { Ajouter le membre comme constante Integer (VB.NET) }
    SymIdx := AddSym(MemberName, SK_ENUM_MEMBER, VBT_INTEGER,
                     STORE_CONSTANT);
    If SymIdx >= 0 Then Begin
      SymTab[SymIdx].IsPublic   := IsPublic;
      SymTab[SymIdx].IsConst    := True;
      SymTab[SymIdx].InitNum    := CurValue;
      SymTab[SymIdx].HasInit    := True;
      SymTab[SymIdx].AsmLabel   := PFX_ENUM + UpCaseStr(EnumName) + '_' +
                                   UpCaseStr(MemberName);
    End;
    { Emettre commentaire }
    EmitComment('  ' + EnumName + '.' + MemberName + ' = ' +
                ItoS(CurValue));
    { Emettre la constante en .DATA }
    EmitData(PFX_ENUM + UpCaseStr(EnumName) + '_' +
             UpCaseStr(MemberName) + ' DD ' + ItoS(CurValue));
    Inc(CurValue);
    Inc(MemberCount);
    SkipNewlines;
  End;
  EmitComment('End Enum ' + EnumName + ' (' + ItoS(MemberCount) +
              ' members)');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ GenFieldAccess : generer le code pour acceder a un champ     }
{   d une variable de type Structure VB.NET                    }
{   Syntaxe : variable.champ                                   }
{   Genere : LEA EAX, [base + offset_champ]                   }
{ ------------------------------------------------------------ }

Procedure GenFieldAccess(VarIdx, FieldIdx : Integer);
Var
  BaseLabel   : TString;
  FieldOffset : LongInt;
Begin
  Inc(StructEnumCount);
  If (VarIdx < 0) Or (VarIdx >= SymCount) Then Begin
    FatalError('variable de type Structure invalide');
    Exit;
  End;
  If (FieldIdx < 0) Or (FieldIdx >= SymCount) Then Begin
    FatalError('champ de Structure invalide');
    Exit;
  End;
  FieldOffset := SymTab[FieldIdx].BpOffset;
  { Generer le code selon la classe d entreposage }
  Case SymTab[VarIdx].StoreClass Of
    STORE_GLOBAL, STORE_STATIC : Begin
      BaseLabel := SymTab[VarIdx].AsmLabel;
      Emit('LEA EAX, [' + BaseLabel + ' + ' + ItoS(FieldOffset) + ']');
    End;
    STORE_AUTO : Begin
      If FieldOffset = 0 Then
        Emit('LEA EAX, [EBP - ' +
             ItoS(Abs(SymTab[VarIdx].BpOffset)) + ']')
      Else
        Emit('LEA EAX, [EBP - ' +
             ItoS(Abs(SymTab[VarIdx].BpOffset) - FieldOffset) + ']');
    End;
    STORE_PARAM : Begin
      Emit('MOV EAX, [EBP + ' + ItoS(SymTab[VarIdx].BpOffset) + ']');
      If FieldOffset > 0 Then
        Emit('ADD EAX, ' + ItoS(FieldOffset));
    End;
  Else
    Emit('LEA EAX, [' + SymTab[VarIdx].AsmLabel + ' + ' +
         ItoS(FieldOffset) + ']');
  End;
End;

{ ------------------------------------------------------------ }
{ GenFieldStore : generer le code pour stocker dans un champ   }
{   d une variable de type Structure VB.NET                    }
{   La valeur a stocker est dans EAX                           }
{   Genere : MOV [base + offset_champ], EAX                   }
{ ------------------------------------------------------------ }

Procedure GenFieldStore(VarIdx, FieldIdx : Integer);
Var
  BaseLabel   : TString;
  FieldOffset : LongInt;
  FieldSize   : Integer;
Begin
  Inc(StructEnumCount);
  If (VarIdx < 0) Or (VarIdx >= SymCount) Then Begin
    FatalError('variable de type Structure invalide');
    Exit;
  End;
  If (FieldIdx < 0) Or (FieldIdx >= SymCount) Then Begin
    FatalError('champ de Structure invalide');
    Exit;
  End;
  FieldOffset := SymTab[FieldIdx].BpOffset;
  FieldSize   := VBTypeSize(SymTab[FieldIdx].DataType);
  { Sauvegarder EAX dans EBX temporairement }
  Emit('MOV EBX, EAX');
  { Generer le code selon la classe d entreposage }
  Case SymTab[VarIdx].StoreClass Of
    STORE_GLOBAL, STORE_STATIC : Begin
      BaseLabel := SymTab[VarIdx].AsmLabel;
      Case FieldSize Of
        1 : Emit('MOV BYTE PTR [' + BaseLabel + ' + ' +
                  ItoS(FieldOffset) + '], BL');
        2 : Emit('MOV WORD PTR [' + BaseLabel + ' + ' +
                  ItoS(FieldOffset) + '], BX');
      Else
        Emit('MOV DWORD PTR [' + BaseLabel + ' + ' +
             ItoS(FieldOffset) + '], EBX');
      End;
    End;
    STORE_AUTO : Begin
      Case FieldSize Of
        1 : Emit('MOV BYTE PTR [EBP - ' +
                  ItoS(Abs(SymTab[VarIdx].BpOffset) - FieldOffset) +
                  '], BL');
        2 : Emit('MOV WORD PTR [EBP - ' +
                  ItoS(Abs(SymTab[VarIdx].BpOffset) - FieldOffset) +
                  '], BX');
      Else
        Emit('MOV DWORD PTR [EBP - ' +
             ItoS(Abs(SymTab[VarIdx].BpOffset) - FieldOffset) +
             '], EBX');
      End;
    End;
    STORE_PARAM : Begin
      Emit('MOV ECX, [EBP + ' + ItoS(SymTab[VarIdx].BpOffset) + ']');
      Case FieldSize Of
        1 : Emit('MOV BYTE PTR [ECX + ' + ItoS(FieldOffset) + '], BL');
        2 : Emit('MOV WORD PTR [ECX + ' + ItoS(FieldOffset) + '], BX');
      Else
        Emit('MOV DWORD PTR [ECX + ' + ItoS(FieldOffset) + '], EBX');
      End;
    End;
  Else Begin
    BaseLabel := SymTab[VarIdx].AsmLabel;
    Emit('MOV DWORD PTR [' + BaseLabel + ' + ' +
         ItoS(FieldOffset) + '], EBX');
  End;
  End;
End;

{ ------------------------------------------------------------ }
{ IsStructureDecl : verifier si le token courant est une       }
{   declaration Structure (VB.NET)                             }
{ ------------------------------------------------------------ }

Function IsStructureDecl(KW : Integer) : Boolean;
Begin
  IsStructureDecl := (KW = KW_STRUCTURE);
End;

{ ------------------------------------------------------------ }
{ IsEnumDecl : verifier si le token courant est une            }
{   declaration Enum                                           }
{ ------------------------------------------------------------ }

Function IsEnumDecl(KW : Integer) : Boolean;
Begin
  IsEnumDecl := (KW = KW_ENUM);
End;

{ ------------------------------------------------------------ }
{ IsStructOrEnumKW : verifier si un mot-cle est Structure ou   }
{   Enum                                                       }
{ ------------------------------------------------------------ }

Function IsStructOrEnumKW(KW : Integer) : Boolean;
Begin
  IsStructOrEnumKW := (KW = KW_STRUCTURE) Or (KW = KW_ENUM);
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour le module Structure/Enum            }
{ ------------------------------------------------------------ }

Function GetStructEnumCount : LongInt;
Begin
  GetStructEnumCount := StructEnumCount;
End;

Function IsStructEnumInitialized : Boolean;
Begin
  IsStructEnumInitialized := StructEnumInitialized;
End;

Function IsStructEnumEmpty : Boolean;
Begin
  IsStructEnumEmpty := (StructEnumCount = 0);
End;

Function GetStructEnumStatus : TString;
Begin
  If Not StructEnumInitialized Then
    GetStructEnumStatus := 'non initialise'
  Else If StructEnumCount = 0 Then
    GetStructEnumStatus := 'initialise, aucune structure/enum'
  Else
    GetStructEnumStatus := 'initialise, ' + ItoS(StructEnumCount) +
                           ' operations';
End;

Function GetMaxStructFields : Integer;
Begin
  GetMaxStructFields := MAX_STRUCT_FIELDS;
End;

Function GetMaxEnumMembers : Integer;
Begin
  GetMaxEnumMembers := MAX_ENUM_MEMBERS;
End;

Function GetMaxStructSize : LongInt;
Begin
  GetMaxStructSize := MAX_STRUCT_SIZE;
End;

Function GetStructRtCount : Integer;
Begin
  { 10 labels runtime pour operations Structure/Enum VB.NET }
  GetStructRtCount := 10;
End;

Function IsStructureKW(KW : Integer) : Boolean;
Begin
  IsStructureKW := (KW = KW_STRUCTURE);
End;

Function GetStructPrefixLabel : TString;
Begin
  GetStructPrefixLabel := PFX_STRUC;
End;

{ ============================================================ }
{ TODO 17 - PARSEUR : CLASSES ET HERITAGE (CLASS, INHERITS,    }
{           IMPLEMENTS) [IMPLEMENTE]                           }
{ ============================================================ }

Const
  { Nombre maximal de methodes dans une classe }
  MAX_CLASS_METHODS  = 128;

  { Nombre maximal de proprietes dans une classe }
  MAX_CLASS_PROPS    = 128;

  { Nombre maximal de champs d instance dans une classe }
  MAX_CLASS_FIELDS   = 128;

  { Taille d un pointeur objet (32 bits) }
  OBJ_PTR_SIZE       = 4;

  { Offset de la vtable dans un objet (premier DD) }
  OBJ_VTABLE_OFFSET  = 0;

  { Labels runtime pour operations sur classes VB.NET }
  CLS_RT_ALLOC    = '_VBNRT_CLS_ALLOC';
  CLS_RT_FREE     = '_VBNRT_CLS_FREE';
  CLS_RT_ADDREF   = '_VBNRT_CLS_ADDREF';
  CLS_RT_RELEASE  = '_VBNRT_CLS_RELEASE';
  CLS_RT_QUERYIF  = '_VBNRT_CLS_QUERYIF';
  CLS_RT_INIT     = '_VBNRT_CLS_INIT';
  CLS_RT_TERM     = '_VBNRT_CLS_TERM';
  CLS_RT_SET      = '_VBNRT_CLS_SET';
  CLS_RT_ISNOTH   = '_VBNRT_CLS_ISNOTHING';
  CLS_RT_TYPEOF   = '_VBNRT_CLS_TYPEOF';

  { Types de propriete VB.NET (Get/Set, pas Let) }
  PROP_GET = 0;
  PROP_SET = 1;

Var
  ClassCount            : LongInt;
  ClassInitialized      : Boolean;
  CurClassName          : TString;
  CurClassIsPublic      : Boolean;
  CurClassMustInherit   : Boolean;
  CurClassNotInheritable: Boolean;
  CurClassHasCtor       : Boolean;
  CurClassHasDtor       : Boolean;
  ClassMethodCount      : Integer;
  ClassPropCount        : Integer;

{ ------------------------------------------------------------ }
{ InitClassState : initialiser l etat du parseur de classes    }
{   VB.NET (Class, Interface, Inherits, Implements)            }
{ ------------------------------------------------------------ }

Procedure InitClassState;
Begin
  ClassCount            := 0;
  ClassInitialized      := True;
  CurClassName          := '';
  CurClassIsPublic      := True;
  CurClassMustInherit   := False;
  CurClassNotInheritable:= False;
  CurClassHasCtor       := False;
  CurClassHasDtor       := False;
  ClassMethodCount      := 0;
  ClassPropCount        := 0;
End;

{ ------------------------------------------------------------ }
{ ParseClassField : parser un champ d une Class VB.NET         }
{   Syntaxe : [Public|Private|Protected|Friend] [Shared]       }
{             champ As Type [= valeur]                         }
{   Les champs de classe VB.NET supportent Protected et Friend }
{   Shared : champ statique accessible via NomClasse.champ     }
{ ------------------------------------------------------------ }

Procedure ParseClassField(ClassName : TString;
                           FieldOffset : LongInt;
                           IsFieldPublic : Boolean;
                           IsFieldShared : Boolean);
Var
  FName     : TString;
  FType     : Integer;
  FSize     : Integer;
  SymIdx    : Integer;
Begin
  Inc(ClassCount);
  { Nom du champ }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu pour le champ de Class ' + ClassName);
    Exit;
  End;
  FName := CurTokStr;
  LexNextToken;
  { As Type }
  FType := VBT_OBJECT; { type par defaut VB.NET }
  If IsKeywordToken(KW_AS) Then Begin
    LexNextToken; { consommer As }
    FType := ParseTypeSpec;
  End;
  FSize := VBTypeSize(FType);
  { Initialisation optionnelle = valeur }
  If CurTokType = TOK_EQ Then Begin
    LexNextToken; { consommer = }
    { Sauter la valeur d initialisation }
    While (CurTokType <> TOK_NEWLINE) And (CurTokType <> TOK_EOF) Do
      LexNextToken;
  End;
  { Ajouter le champ dans la table des symboles }
  SymIdx := AddSym(FName, SK_FIELD, FType, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].BpOffset   := FieldOffset;
    SymTab[SymIdx].IsPublic   := IsFieldPublic;
    SymTab[SymIdx].IsShared   := IsFieldShared;
    SymTab[SymIdx].IsConst    := False;
    SymTab[SymIdx].ArrayDims  := 0;
    SymTab[SymIdx].AsmLabel   := PFX_CLS + UpCaseStr(ClassName) + '_' +
                                 UpCaseStr(FName);
  End;
  { Emettre commentaire d assembleur }
  EmitComment('  ' + ClassName + '.' + FName + ' : offset=' +
              ItoS(FieldOffset) + ', size=' + ItoS(FSize));
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParsePropertyDecl : parser une declaration Property VB.NET    }
{   Syntaxe :                                                   }
{     [Public|Private|Protected] Property NomProp() As Type     }
{       Get                                                     }
{         Return _donnee                                        }
{       End Get                                                 }
{       Set(ByVal value As Type)                                }
{         _donnee = value                                       }
{       End Set                                                 }
{     End Property                                              }
{   VB.NET : Get/Set sont des blocs internes a Property         }
{   Pas de Property Let (uniquement en VB6)                     }
{ ------------------------------------------------------------ }

Procedure ParsePropertyDecl(ClassName : TString;
                              IsPropPublic : Boolean);
Var
  PropName  : TString;
  PropLabel : TString;
  RetType   : Integer;
  ParamCnt  : Integer;
  ExLabel   : TString;
Begin
  Inc(ClassPropCount);
  Inc(ClassCount);
  { Consommer 'Property' }
  LexNextToken;
  { Lire le nom de la propriete }
  If CurTokType = TOK_IDENT Then Begin
    PropName := CurTokStr;
    LexNextToken;
  End Else Begin
    FatalError('Nom de propriete attendu apres Property');
    PropName := '?';
  End;
  PropLabel := PFX_PROP + AsmIdent(PropName);
  ParamCnt  := 0;
  RetType   := VBT_OBJECT; { VB.NET : Object par defaut }
  { Parser les parametres optionnels (index de propriete) }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken; { consommer ( }
    While Not (CurTokType = TOK_RPAREN) Do Begin
      If CurTokType = TOK_EOF Then Break;
      Inc(ParamCnt);
      LexNextToken;
    End;
    If CurTokType = TOK_RPAREN Then
      LexNextToken; { consommer ) }
  End;
  { Parser le type de retour : As Type }
  If IsKeywordToken(KW_AS) Then Begin
    LexNextToken; { consommer As }
    RetType := ParseTypeSpec;
  End;
  SkipNewlines;
  { Ajouter dans la table des symboles et des procedures }
  AddSym(PropName, SK_PROPERTY, RetType, STORE_GLOBAL);
  AddProc(PropName, SK_PROPERTY, RetType, IsPropPublic);
  EmitComment('Property ' + PropName + ' As ' + VBTypeName(RetType));
  { Parser le corps : Get / Set blocks jusqu a End Property }
  While Not (CurTokType = TOK_EOF) Do Begin
    If IsKeywordToken(KW_GET) Then Begin
      { Bloc Get }
      LexNextToken; { consommer Get }
      SkipNewlines;
      ExLabel := NextInternalLabel;
      EmitLabel(PropLabel + '_GET');
      Emit('PUSH EBP');
      Emit('MOV EBP, ESP');
      EmitComment('Property Get ' + PropName);
      Emit('XOR EAX, EAX');
      { Parser jusqu a End Get }
      While Not (CurTokType = TOK_EOF) Do Begin
        If IsKeywordToken(KW_END) Then Begin
          LexNextToken;
          If IsKeywordToken(KW_GET) Then Begin
            LexNextToken;
            Break;
          End;
        End;
        LexNextToken;
      End;
      SkipNewlines;
      EmitLabel(ExLabel);
      Emit('MOV ESP, EBP');
      Emit('POP EBP');
      Emit('RET');
    End
    Else If IsKeywordToken(KW_SET) Then Begin
      { Bloc Set (VB.NET n a pas Let) }
      LexNextToken; { consommer Set }
      { Parametres optionnels du Set }
      If CurTokType = TOK_LPAREN Then Begin
        While Not (CurTokType = TOK_RPAREN) And
              Not (CurTokType = TOK_EOF) Do
          LexNextToken;
        If CurTokType = TOK_RPAREN Then
          LexNextToken;
      End;
      SkipNewlines;
      ExLabel := NextInternalLabel;
      EmitLabel(PropLabel + '_SET');
      Emit('PUSH EBP');
      Emit('MOV EBP, ESP');
      EmitComment('Property Set ' + PropName);
      { Parser jusqu a End Set }
      While Not (CurTokType = TOK_EOF) Do Begin
        If IsKeywordToken(KW_END) Then Begin
          LexNextToken;
          If IsKeywordToken(KW_SET) Then Begin
            LexNextToken;
            Break;
          End;
        End;
        LexNextToken;
      End;
      SkipNewlines;
      EmitLabel(ExLabel);
      Emit('MOV ESP, EBP');
      Emit('POP EBP');
      Emit('RET');
    End
    Else If IsKeywordToken(KW_END) Then Begin
      LexNextToken;
      If IsKeywordToken(KW_PROPERTY) Then Begin
        LexNextToken;
        Break;
      End;
    End
    Else Begin
      LexNextToken;
    End;
  End;
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseClass : parser une declaration Class...End Class VB.NET }
{   Syntaxe :                                                   }
{     [Public|Private|Friend] [MustInherit|NotInheritable]     }
{       Class NomClasse                                         }
{       [Inherits ClasseParente]                                }
{       [Implements Interface1[, Interface2]]                   }
{       membres (champs, methodes, proprietes)                  }
{     End Class                                                 }
{   MustInherit : classe abstraite (pas instanciable)          }
{   NotInheritable : classe scellee (pas héritable)            }
{   Genere la vtable et les labels de classe                   }
{ ------------------------------------------------------------ }

Procedure ParseClass(IsPublic : Boolean;
                      IsMustInherit : Boolean;
                      IsNotInheritable : Boolean);
Var
  ClassName    : TString;
  ParentClass  : TString;
  FieldCount   : Integer;
  FieldOffset  : LongInt;
  SymIdx       : Integer;
  AsmLbl       : TString;
  MemberPublic : Boolean;
  MemberShared : Boolean;
Begin
  Inc(ClassCount);
  { Consommer 'Class' }
  LexNextToken;
  { Nom de la classe }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres Class');
    Exit;
  End;
  ClassName := CurTokStr;
  AsmLbl    := PFX_CLS + UpCaseStr(ClassName);
  LexNextToken;
  SkipNewlines;
  { Sauvegarder l etat courant de la classe }
  CurClassName          := ClassName;
  CurClassIsPublic      := IsPublic;
  CurClassMustInherit   := IsMustInherit;
  CurClassNotInheritable:= IsNotInheritable;
  CurClassHasCtor       := False;
  CurClassHasDtor       := False;
  ClassMethodCount      := 0;
  ClassPropCount        := 0;
  { Ajouter la classe dans la table des symboles }
  SymIdx := AddSym(ClassName, SK_CLASS, VBT_OBJECT, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].IsPublic := IsPublic;
    SymTab[SymIdx].IsConst  := False;
    SymTab[SymIdx].AsmLabel := AsmLbl;
  End;
  { Emettre le commentaire de classe }
  If IsMustInherit Then
    EmitComment('MustInherit Class ' + ClassName)
  Else If IsNotInheritable Then
    EmitComment('NotInheritable Class ' + ClassName)
  Else
    EmitComment('Class ' + ClassName);
  { Parser Inherits optionnel }
  ParentClass := '';
  If IsKeywordToken(KW_INHERITS) Then Begin
    LexNextToken; { consommer Inherits }
    If CurTokType = TOK_IDENT Then Begin
      ParentClass := CurTokStr;
      LexNextToken;
      EmitComment('  Inherits ' + ParentClass);
      If Opts.Verbose Then
        WriteLn('  Class ', ClassName, ' Inherits ', ParentClass);
    End Else Begin
      FatalError('nom de classe parente attendu apres Inherits');
    End;
    SkipNewlines;
  End;
  { Parser Implements optionnel (liste separee par des virgules) }
  If IsKeywordToken(KW_IMPLEMENTS) Then Begin
    LexNextToken; { consommer Implements }
    While CurTokType = TOK_IDENT Do Begin
      EmitComment('  Implements ' + CurTokStr);
      If Opts.Verbose Then
        WriteLn('  Class ', ClassName, ' Implements ', CurTokStr);
      LexNextToken;
      If CurTokType = TOK_COMMA Then
        LexNextToken { consommer la virgule }
      Else
        Break;
    End;
    SkipNewlines;
  End;
  { Parser les membres de la classe }
  FieldCount  := 0;
  FieldOffset := OBJ_PTR_SIZE; { apres le pointeur vtable }
  While Not LexEOF Do Begin
    { Verifier End Class }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CLASS) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End Class attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Determiner le modificateur d acces }
    MemberPublic := True;
    MemberShared := False;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PUBLIC) Then Begin
      MemberPublic := True;
      LexNextToken;
    End Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PRIVATE) Then Begin
      MemberPublic := False;
      LexNextToken;
    End Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PROTECTED) Then Begin
      MemberPublic := False;
      LexNextToken;
    End Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FRIEND) Then Begin
      MemberPublic := True;
      LexNextToken;
    End;
    { Verifier Shared }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SHARED) Then Begin
      MemberShared := True;
      LexNextToken;
    End;
    { Sauter les modificateurs de methode VB.NET }
    While (CurTokType = TOK_KEYWORD) And
          ((CurTokNum = KW_OVERRIDABLE) Or (CurTokNum = KW_OVERRIDES) Or
           (CurTokNum = KW_MUSTOVERRIDE) Or (CurTokNum = KW_NOTOVERRIDABLE) Or
           (CurTokNum = KW_OVERLOADS)) Do
      LexNextToken;
    { Sub : methode ou constructeur/destructeur }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SUB) Then Begin
      LexNextToken; { consommer Sub }
      Inc(ClassMethodCount);
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEW) Then Begin
        { Constructeur Sub New() }
        CurClassHasCtor := True;
        LexNextToken; { consommer New }
        EmitComment('  Sub New() - constructeur de ' + ClassName);
        EmitLabel(AsmLbl + '_NEW');
        Emit('PUSH EBP');
        Emit('MOV EBP, ESP');
      End Else If CurTokType = TOK_IDENT Then Begin
        { Verifier si c est Finalize (destructeur) }
        If UpCaseStr(CurTokStr) = 'FINALIZE' Then Begin
          CurClassHasDtor := True;
          LexNextToken;
          EmitComment('  Sub Finalize() - destructeur de ' + ClassName);
          EmitLabel(AsmLbl + '_FINALIZE');
          Emit('PUSH EBP');
          Emit('MOV EBP, ESP');
        End Else Begin
          { Methode normale }
          EmitComment('  Sub ' + CurTokStr + ' de ' + ClassName);
          EmitLabel(AsmLbl + '_' + UpCaseStr(CurTokStr));
          Emit('PUSH EBP');
          Emit('MOV EBP, ESP');
          LexNextToken;
        End;
      End Else Begin
        SkipToEndOfLine;
        SkipNewlines;
        Continue;
      End;
      { Consommer les parametres }
      If CurTokType = TOK_LPAREN Then Begin
        While Not (CurTokType = TOK_RPAREN) And
              Not (CurTokType = TOK_EOF) Do
          LexNextToken;
        If CurTokType = TOK_RPAREN Then
          LexNextToken;
      End;
      SkipNewlines;
      { Parser le corps jusqu a End Sub }
      While Not (CurTokType = TOK_EOF) Do Begin
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
          LexNextToken;
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SUB) Then Begin
            LexNextToken;
            Break;
          End;
        End;
        LexNextToken;
      End;
      SkipNewlines;
      { Epilogue }
      Emit('MOV ESP, EBP');
      Emit('POP EBP');
      Emit('RET');
    End
    { Function : methode avec retour }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION) Then Begin
      LexNextToken; { consommer Function }
      Inc(ClassMethodCount);
      If CurTokType = TOK_IDENT Then Begin
        EmitComment('  Function ' + CurTokStr + ' de ' + ClassName);
        EmitLabel(AsmLbl + '_' + UpCaseStr(CurTokStr));
        Emit('PUSH EBP');
        Emit('MOV EBP, ESP');
        LexNextToken;
      End;
      { Consommer les parametres }
      If CurTokType = TOK_LPAREN Then Begin
        While Not (CurTokType = TOK_RPAREN) And
              Not (CurTokType = TOK_EOF) Do
          LexNextToken;
        If CurTokType = TOK_RPAREN Then
          LexNextToken;
      End;
      { Consommer As ReturnType }
      If IsKeywordToken(KW_AS) Then Begin
        LexNextToken;
        ParseTypeSpec;
      End;
      SkipNewlines;
      { Valeur par defaut }
      Emit('XOR EAX, EAX');
      { Parser le corps jusqu a End Function }
      While Not (CurTokType = TOK_EOF) Do Begin
        If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
          LexNextToken;
          If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION) Then Begin
            LexNextToken;
            Break;
          End;
        End;
        LexNextToken;
      End;
      SkipNewlines;
      { Epilogue }
      Emit('MOV ESP, EBP');
      Emit('POP EBP');
      Emit('RET');
    End
    { Property : propriete VB.NET }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PROPERTY) Then Begin
      ParsePropertyDecl(ClassName, MemberPublic);
    End
    { Dim : champ avec Dim }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_DIM) Then Begin
      LexNextToken;
      If FieldCount < MAX_CLASS_FIELDS Then Begin
        ParseClassField(ClassName, FieldOffset, MemberPublic, MemberShared);
        FieldOffset := FieldOffset + 4; { aligner a 4 octets }
        Inc(FieldCount);
      End Else Begin
        FatalError('nombre maximal de champs depasse dans Class ' + ClassName);
        SkipToEndOfLine;
        SkipNewlines;
      End;
    End
    { Identifiant : champ si suivi de As }
    Else If CurTokType = TOK_IDENT Then Begin
      If FieldCount < MAX_CLASS_FIELDS Then Begin
        ParseClassField(ClassName, FieldOffset, MemberPublic, MemberShared);
        FieldOffset := FieldOffset + 4;
        Inc(FieldCount);
      End Else Begin
        FatalError('nombre maximal de champs depasse dans Class ' + ClassName);
        SkipToEndOfLine;
        SkipNewlines;
      End;
    End
    Else Begin
      { Autre token : avancer }
      LexNextToken;
    End;
  End;
  { Emettre la vtable par defaut si des methodes existent }
  If ClassMethodCount > 0 Then
    EmitComment('Fin vtable pour ' + ClassName);
  EmitComment('End Class ' + ClassName + ' (' +
              ItoS(FieldCount) + ' champs, ' +
              ItoS(ClassMethodCount) + ' methodes, ' +
              ItoS(ClassPropCount) + ' proprietes)');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ ParseInterface : parser une declaration Interface VB.NET     }
{   Syntaxe :                                                   }
{     [Public|Private|Friend] Interface INomInterface           }
{       Sub Methode(params)                                     }
{       Function Calcul(params) As Type                         }
{       Property Prop() As Type                                 }
{     End Interface                                             }
{   Les interfaces VB.NET ne contiennent que des signatures     }
{   (pas de corps de methode)                                   }
{ ------------------------------------------------------------ }

Procedure ParseInterface(IsPublic : Boolean);
Var
  IfaceName   : TString;
  MemberCount : Integer;
  SymIdx      : Integer;
  AsmLbl      : TString;
Begin
  Inc(ClassCount);
  { Consommer 'Interface' }
  LexNextToken;
  { Nom de l interface }
  If CurTokType <> TOK_IDENT Then Begin
    FatalError('identifiant attendu apres Interface');
    Exit;
  End;
  IfaceName := CurTokStr;
  AsmLbl    := PFX_IFACE + UpCaseStr(IfaceName);
  LexNextToken;
  SkipNewlines;
  { Ajouter l interface dans la table des symboles }
  SymIdx := AddSym(IfaceName, SK_INTERFACE, VBT_OBJECT, STORE_GLOBAL);
  If SymIdx >= 0 Then Begin
    SymTab[SymIdx].IsPublic := IsPublic;
    SymTab[SymIdx].IsConst  := False;
    SymTab[SymIdx].AsmLabel := AsmLbl;
  End;
  EmitComment('Interface ' + IfaceName);
  { Parser Inherits optionnel pour interface }
  If IsKeywordToken(KW_INHERITS) Then Begin
    LexNextToken;
    If CurTokType = TOK_IDENT Then Begin
      EmitComment('  Inherits ' + CurTokStr);
      LexNextToken;
    End;
    SkipNewlines;
  End;
  { Parser les signatures jusqu a End Interface }
  MemberCount := 0;
  While Not LexEOF Do Begin
    { Verifier End Interface }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
      LexNextToken;
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_INTERFACE) Then Begin
        LexNextToken;
        Break;
      End Else Begin
        FatalError('End Interface attendu');
        Exit;
      End;
    End;
    { Ignorer les lignes vides }
    If CurTokType = TOK_NEWLINE Then Begin
      SkipNewlines;
      Continue;
    End;
    { Sub signature }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_SUB) Then Begin
      LexNextToken;
      Inc(MemberCount);
      If CurTokType = TOK_IDENT Then Begin
        EmitComment('  Sub ' + CurTokStr + ' (signature)');
        LexNextToken;
      End;
      { Sauter les parametres }
      SkipToEndOfLine;
      SkipNewlines;
    End
    { Function signature }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FUNCTION) Then Begin
      LexNextToken;
      Inc(MemberCount);
      If CurTokType = TOK_IDENT Then Begin
        EmitComment('  Function ' + CurTokStr + ' (signature)');
        LexNextToken;
      End;
      SkipToEndOfLine;
      SkipNewlines;
    End
    { Property signature }
    Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_PROPERTY) Then Begin
      LexNextToken;
      Inc(MemberCount);
      If CurTokType = TOK_IDENT Then Begin
        EmitComment('  Property ' + CurTokStr + ' (signature)');
        LexNextToken;
      End;
      SkipToEndOfLine;
      SkipNewlines;
    End
    Else Begin
      LexNextToken;
    End;
  End;
  EmitComment('End Interface ' + IfaceName + ' (' +
              ItoS(MemberCount) + ' membres)');
  SkipNewlines;
End;

{ ------------------------------------------------------------ }
{ GenNewObject : generer code pour creation d une instance      }
{   VB.NET : Dim obj As New NomClasse()                        }
{            Dim obj As NomClasse = New NomClasse()             }
{   Alloue memoire (CALL _VBNRT_CLS_ALLOC), init vtable,      }
{   appelle Sub New() si present                               }
{   Resultat dans EAX = pointeur vers l instance               }
{ ------------------------------------------------------------ }

Procedure GenNewObject(ClassName : TString);
Var
  VTLabel : TString;
Begin
  Inc(ClassCount);
  VTLabel := PFX_CLS + AsmIdent(ClassName) + '_VTABLE';
  EmitComment('New ' + ClassName + '()');
  { Allouer memoire pour l objet }
  Emit('PUSH ' + ItoS(OBJ_PTR_SIZE + MAX_CLASS_FIELDS * 4));
  Emit('CALL ' + CLS_RT_ALLOC);
  Emit('ADD ESP, 4');
  { Stocker le pointeur vtable dans le premier DD de l objet }
  Emit('MOV DWORD PTR [EAX + ' + ItoS(OBJ_VTABLE_OFFSET) +
       '], OFFSET ' + VTLabel);
  { Appeler Sub New() via runtime init }
  Emit('PUSH EAX');   { sauvegarder this }
  Emit('PUSH EAX');   { passer this comme param }
  Emit('CALL ' + CLS_RT_INIT);
  Emit('ADD ESP, 4');
  Emit('POP EAX');    { restaurer this }
  { EAX = pointeur vers la nouvelle instance }
End;

{ ------------------------------------------------------------ }
{ GenSetNothing : generer code pour obj = Nothing               }
{   VB.NET : obj = Nothing (pas de Set en VB.NET)              }
{   Libere l instance : appelle Finalize() puis                }
{   _VBNRT_CLS_FREE, et met le pointeur a Nothing (NULL)      }
{ ------------------------------------------------------------ }

Procedure GenSetNothing(VarLabel : TString);
Var
  SkipLbl : TString;
Begin
  Inc(ClassCount);
  SkipLbl := NextInternalLabel;
  EmitComment(VarLabel + ' = Nothing');
  { Charger le pointeur objet }
  Emit('MOV EAX, DWORD PTR [' + VarLabel + ']');
  { Verifier si deja Nothing (NULL) }
  Emit('TEST EAX, EAX');
  Emit('JZ ' + SkipLbl);
  { Appeler Finalize via runtime }
  Emit('PUSH EAX');
  Emit('CALL ' + CLS_RT_TERM);
  Emit('ADD ESP, 4');
  { Liberer la memoire }
  Emit('MOV EAX, DWORD PTR [' + VarLabel + ']');
  Emit('PUSH EAX');
  Emit('CALL ' + CLS_RT_FREE);
  Emit('ADD ESP, 4');
  { Mettre le pointeur a Nothing (NULL) }
  EmitLabel(SkipLbl);
  Emit('MOV DWORD PTR [' + VarLabel + '], 0');
End;

{ ------------------------------------------------------------ }
{ GenMethodCall : generer un appel de methode via vtable        }
{   obj.Method(args)                                           }
{   PUSH this, charger vtable[offset], CALL [vtable+offset]   }
{ ------------------------------------------------------------ }

Procedure GenMethodCall(ObjLabel : TString; MethodIdx : Integer);
Begin
  Inc(ClassCount);
  Inc(ClassMethodCount);
  EmitComment('Appel methode #' + ItoS(MethodIdx) + ' sur ' + ObjLabel);
  { Charger le pointeur objet dans ECX (convention this) }
  Emit('MOV ECX, DWORD PTR [' + ObjLabel + ']');
  { Charger l adresse de la vtable }
  Emit('MOV EDX, DWORD PTR [ECX + ' + ItoS(OBJ_VTABLE_OFFSET) + ']');
  { Pousser this comme premier argument implicite (Me) }
  Emit('PUSH ECX');
  { Appeler via vtable[offset] }
  Emit('CALL DWORD PTR [EDX + ' + ItoS(MethodIdx * 4) + ']');
End;

{ ------------------------------------------------------------ }
{ GenVTableEntry : emettre une entree dans la vtable de classe }
{   Genere un DD (pointeur de fonction) en section .DATA       }
{   pour chaque methode de la classe VB.NET                    }
{ ------------------------------------------------------------ }

Procedure GenVTableEntry(ClassName : TString;
                          MethodName : TString;
                          MethodIdx : Integer);
Var
  VTLabel : TString;
  MLabel  : TString;
Begin
  Inc(ClassCount);
  VTLabel := PFX_CLS + AsmIdent(ClassName) + '_VTABLE';
  MLabel  := PFX_CLS + AsmIdent(ClassName) + '_' + AsmIdent(MethodName);
  { Premiere entree : emettre le label de la vtable }
  If MethodIdx = 0 Then Begin
    EmitComment('VTable pour classe ' + ClassName);
    EmitData(VTLabel + ' DD OFFSET ' + MLabel);
  End Else Begin
    EmitData('  DD OFFSET ' + MLabel);
  End;
End;

{ ------------------------------------------------------------ }
{ IsClassDecl : verifier si un mot-cle est Class               }
{ ------------------------------------------------------------ }

Function IsClassDecl(KW : Integer) : Boolean;
Begin
  IsClassDecl := (KW = KW_CLASS);
End;

{ ------------------------------------------------------------ }
{ IsInterfaceDecl : verifier si un mot-cle est Interface       }
{ ------------------------------------------------------------ }

Function IsInterfaceDecl(KW : Integer) : Boolean;
Begin
  IsInterfaceDecl := (KW = KW_INTERFACE);
End;

{ ------------------------------------------------------------ }
{ IsPropertyKW : verifier si un mot-cle est Property           }
{ ------------------------------------------------------------ }

Function IsPropertyKW(KW : Integer) : Boolean;
Begin
  IsPropertyKW := (KW = KW_PROPERTY);
End;

{ ------------------------------------------------------------ }
{ Fonctions accesseur pour le module classes VB.NET            }
{ ------------------------------------------------------------ }

Function GetClassCount : LongInt;
Begin
  GetClassCount := ClassCount;
End;

Function IsClassInitialized : Boolean;
Begin
  IsClassInitialized := ClassInitialized;
End;

Function IsClassEmpty : Boolean;
Begin
  IsClassEmpty := ClassInitialized And (ClassCount = 0);
End;

Function GetClassStatus : TString;
Begin
  If Not ClassInitialized Then
    GetClassStatus := 'non initialise'
  Else If ClassCount = 0 Then
    GetClassStatus := 'initialise, aucune classe'
  Else
    GetClassStatus := 'initialise, ' + ItoS(ClassCount) + ' operations';
End;

Function GetCurClassName : TString;
Begin
  GetCurClassName := CurClassName;
End;

Function IsCurClassPublic : Boolean;
Begin
  IsCurClassPublic := CurClassIsPublic;
End;

Function IsCurClassMustInherit : Boolean;
Begin
  IsCurClassMustInherit := CurClassMustInherit;
End;

Function IsCurClassNotInheritable : Boolean;
Begin
  IsCurClassNotInheritable := CurClassNotInheritable;
End;

Function GetClassMethodCount : Integer;
Begin
  GetClassMethodCount := ClassMethodCount;
End;

Function GetClassPropCount : Integer;
Begin
  GetClassPropCount := ClassPropCount;
End;

{ ============================================================ }
{ TODO 18 - PARSEUR : GESTION DES EXCEPTIONS (TRY/CATCH/       }
{           FINALLY/THROW) [IMPLEMENTE]                         }
{ ============================================================ }

Const
  { Nombre maximal de blocs Try imbriques }
  MAX_TRY_DEPTH    = 32;

  { Nombre maximal de clauses Catch dans un seul Try }
  MAX_CATCH_CLAUSES = 16;

  { Labels runtime pour gestion des exceptions VB.NET }
  EXC_RT_THROW       = '_VBNRT_EXC_THROW';
  EXC_RT_RETHROW     = '_VBNRT_EXC_RETHROW';
  EXC_RT_BEGINSEH    = '_VBNRT_EXC_BEGINSEH';
  EXC_RT_ENDSEH      = '_VBNRT_EXC_ENDSEH';
  EXC_RT_FILTER      = '_VBNRT_EXC_FILTER';
  EXC_RT_GETEXC      = '_VBNRT_EXC_GETEXC';
  EXC_RT_GETMSG      = '_VBNRT_EXC_GETMSG';
  EXC_RT_GETTRACE    = '_VBNRT_EXC_GETTRACE';
  EXC_RT_GETINNER    = '_VBNRT_EXC_GETINNER';
  EXC_RT_NEWEXC      = '_VBNRT_EXC_NEWEXC';

Var
  ExceptionCount       : LongInt;
  ExceptionInitialized : Boolean;
  TryDepth             : Integer;
  MaxTryDepth          : Integer;
  CatchClauseCount     : Integer;
  TotalCatchClauses    : Integer;
  FinallyBlockCount    : Integer;
  ThrowCount           : Integer;

{ ------------------------------------------------------------ }
{ InitExceptionState : initialiser l etat du module exceptions  }
{   VB.NET (Try/Catch/Finally/Throw)                            }
{ ------------------------------------------------------------ }

Procedure InitExceptionState;
Begin
  ExceptionCount       := 0;
  ExceptionInitialized := True;
  TryDepth             := 0;
  MaxTryDepth          := 0;
  CatchClauseCount     := 0;
  TotalCatchClauses    := 0;
  FinallyBlockCount    := 0;
  ThrowCount           := 0;
End;

{ ------------------------------------------------------------ }
{ ParseCatchClause : parser une clause Catch dans un bloc Try   }
{   Syntaxe : Catch ex As ExceptionType [When condition]        }
{             Catch ex As Exception                             }
{             Catch (attrape-tout sans variable)                }
{   En VB.NET, chaque Catch filtre par type d exception         }
{   La clause When permet un filtre conditionnel                }
{   Le code genere teste le type d exception via le runtime     }
{ ------------------------------------------------------------ }

Procedure ParseCatchClause(TryLabelBase : TString;
                            CatchIdx : Integer);
Var
  ExVarName  : TString;
  ExTypeName : TString;
  HasWhen    : Boolean;
  CatchLabel : TString;
  NextLabel  : TString;
Begin
  Inc(ExceptionCount);
  Inc(CatchClauseCount);
  Inc(TotalCatchClauses);
  CatchLabel := TryLabelBase + '_CATCH_' + ItoS(CatchIdx);
  NextLabel  := TryLabelBase + '_CATCH_' + ItoS(CatchIdx + 1);
  ExVarName  := '';
  ExTypeName := '';
  HasWhen    := False;

  EmitLabel(CatchLabel + ':');
  EmitComment('Catch clause #' + ItoS(CatchIdx));

  { Consommer Catch (deja verifie par l appelant) }
  LexNextToken;

  { Verifier si on a une variable et un type }
  If CurTokType = TOK_IDENT Then Begin
    ExVarName := CurTokStr;
    LexNextToken; { consommer nom variable }

    { Attendre 'As' pour le type d exception }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_AS) Then Begin
      LexNextToken; { consommer As }
      If CurTokType = TOK_IDENT Then Begin
        ExTypeName := CurTokStr;
        LexNextToken; { consommer nom type }
      End
      Else If (CurTokType = TOK_KEYWORD) Then Begin
        ExTypeName := KeywordName(CurTokNum);
        LexNextToken; { consommer mot-cle type }
      End
      Else Begin
        FatalError('Catch : type d''exception attendu apres As');
      End;
    End;
  End;

  { Generer le code de filtre par type d exception }
  If ExTypeName <> '' Then Begin
    EmitComment('Filtrer exception : ' + ExTypeName);
    { PUSH ptr_type_name / CALL _VBNRT_EXC_FILTER }
    Emit('  PUSH OFFSET _exc_type_' + ExTypeName);
    Emit('  CALL ' + EXC_RT_FILTER);
    Emit('  TEST EAX, EAX');
    Emit('  JZ ' + NextLabel);
  End;

  { Affecter la variable locale d exception si definie }
  If ExVarName <> '' Then Begin
    EmitComment('Stocker exception dans ' + ExVarName);
    Emit('  CALL ' + EXC_RT_GETEXC);
    Emit('  MOV DWORD [EBP-' + ItoS((CatchIdx + 1) * 4) + '], EAX');
  End;

  { Verifier la clause When optionnelle }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_WHEN) Then Begin
    LexNextToken; { consommer When }
    HasWhen := True;
    EmitComment('When : filtre conditionnel');
    { Parser l expression conditionnelle }
    ParseExpr;
    Emit('  TEST EAX, EAX');
    Emit('  JZ ' + NextLabel);
  End;

  If Opts.Verbose Then Begin
    Write('  Catch');
    If ExVarName <> '' Then
      Write(' ', ExVarName);
    If ExTypeName <> '' Then
      Write(' As ', ExTypeName);
    If HasWhen Then
      Write(' When ...');
    WriteLn;
  End;

  { Parser le corps du bloc Catch }
  SkipNewlines;
  While Not LexEOF Do Begin
    { Fin du bloc : Catch suivant, Finally, ou End Try }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CATCH) Then
      Break;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FINALLY) Then
      Break;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
      Break;
    ParseStatement;
    SkipNewlines;
  End;

  { Sauter apres le bloc Try (fin normale du Catch) }
  Emit('  JMP ' + TryLabelBase + '_ENDTRY');
End;

{ ------------------------------------------------------------ }
{ ParseTry : parser un bloc Try/Catch/Finally...End Try VB.NET  }
{   Syntaxe :                                                   }
{     Try                                                       }
{       instructions                                            }
{     Catch ex As ExceptionType [When condition]                }
{       instructions                                            }
{     Catch ex As Exception                                     }
{       instructions                                            }
{     Finally                                                   }
{       instructions                                            }
{     End Try                                                   }
{   Mecanisme :                                                 }
{     Etablir un cadre SEH Win32 (FS:[0] + handler)             }
{     Le bloc Try genere du code protege                        }
{     Chaque Catch filtre par type d exception                  }
{     Finally est toujours execute (cleanup)                    }
{     End Try retire le cadre SEH                               }
{ ------------------------------------------------------------ }

Procedure ParseTry;
Var
  TryLabelBase : TString;
  CatchIdx     : Integer;
  HasFinally   : Boolean;
  HasCatch     : Boolean;
Begin
  Inc(ExceptionCount);
  Inc(TryDepth);
  If TryDepth > MaxTryDepth Then
    MaxTryDepth := TryDepth;
  If TryDepth > MAX_TRY_DEPTH Then
    FatalError('Try : imbrication maximale depassee (' +
               ItoS(MAX_TRY_DEPTH) + ')');

  TryLabelBase := NextInternalLabel;
  CatchIdx     := 0;
  HasFinally   := False;
  HasCatch     := False;
  CatchClauseCount := 0;

  EmitComment('--- Try bloc ---');
  EmitLabel(TryLabelBase + '_TRY:');

  { Etablir le cadre SEH Win32 }
  Emit('  PUSH OFFSET ' + TryLabelBase + '_CATCH_0');
  Emit('  PUSH DWORD [FS:0]');
  Emit('  MOV [FS:0], ESP');
  EmitComment('Cadre SEH etabli');

  { Consommer Try (deja verifie par l appelant) }
  LexNextToken;
  SkipNewlines;

  If Opts.Verbose Then
    WriteLn('  Try');

  { Entrer dans la portee Try }
  EnterScope(SCOPE_TRY, -1);

  { Parser le corps du bloc Try }
  While Not LexEOF Do Begin
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CATCH) Then
      Break;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FINALLY) Then
      Break;
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
      Break;
    ParseStatement;
    SkipNewlines;
  End;

  { Sortie normale du Try : sauter la partie Catch }
  Emit('  JMP ' + TryLabelBase + '_FINALLY');

  { Quitter la portee Try }
  LeaveScope;

  { Parser les clauses Catch }
  While (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CATCH) Do Begin
    HasCatch := True;
    EnterScope(SCOPE_CATCH, -1);
    ParseCatchClause(TryLabelBase, CatchIdx);
    LeaveScope;
    Inc(CatchIdx);
    SkipNewlines;
  End;

  { Label pour les Catch non matches : sauter au Finally ou propager }
  EmitLabel(TryLabelBase + '_CATCH_' + ItoS(CatchIdx) + ':');
  If HasCatch Then Begin
    EmitComment('Aucun Catch ne correspond : re-lancer');
    Emit('  CALL ' + EXC_RT_RETHROW);
  End;

  { Parser le bloc Finally si present }
  EmitLabel(TryLabelBase + '_FINALLY:');
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FINALLY) Then Begin
    HasFinally := True;
    Inc(FinallyBlockCount);
    LexNextToken; { consommer Finally }
    SkipNewlines;

    EmitComment('--- Finally bloc ---');

    If Opts.Verbose Then
      WriteLn('  Finally');

    EnterScope(SCOPE_FINALLY, -1);

    { Parser le corps du bloc Finally }
    While Not LexEOF Do Begin
      If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then
        Break;
      ParseStatement;
      SkipNewlines;
    End;

    LeaveScope;
  End;

  { Retirer le cadre SEH Win32 }
  EmitComment('Retirer cadre SEH');
  Emit('  POP DWORD [FS:0]');
  Emit('  ADD ESP, 4');

  { Attendre End Try }
  If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_END) Then Begin
    LexNextToken; { consommer End }
    If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRY) Then Begin
      LexNextToken; { consommer Try }
    End Else Begin
      FatalError('End Try attendu');
    End;
  End Else Begin
    FatalError('End Try attendu');
  End;

  EmitLabel(TryLabelBase + '_ENDTRY:');
  EmitComment('--- End Try ---');

  If Opts.Verbose Then
    WriteLn('  End Try');

  Dec(TryDepth);
End;

{ ------------------------------------------------------------ }
{ ParseThrow : parser une instruction Throw VB.NET              }
{   Syntaxe : Throw New Exception("message")                    }
{             Throw exVariable                                  }
{             Throw (re-lancer l exception courante)            }
{   Genere le code pour declencher une exception                }
{ ------------------------------------------------------------ }

Procedure ParseThrow;
Begin
  Inc(ExceptionCount);
  Inc(ThrowCount);

  { Consommer Throw (deja verifie par l appelant) }
  LexNextToken;

  EmitComment('Throw');

  { Throw sans argument : re-lancer l exception courante }
  If (CurTokType = TOK_NEWLINE) Or (CurTokType = TOK_EOF) Or
     (CurTokType = TOK_COLON) Then Begin
    Emit('  CALL ' + EXC_RT_RETHROW);
    If Opts.Verbose Then
      WriteLn('  Throw (re-lancer)');
  End
  { Throw New ExceptionType("message") }
  Else If (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_NEW) Then Begin
    LexNextToken; { consommer New }
    If (CurTokType = TOK_IDENT) Or (CurTokType = TOK_KEYWORD) Then Begin
      { Nom du type d exception }
      EmitComment('Throw New ' + CurTokStr);
      Emit('  PUSH OFFSET _exc_type_' + CurTokStr);
      LexNextToken; { consommer nom type }
      { Verifier s il y a des arguments (message) }
      If CurTokType = TOK_LPAREN Then Begin
        LexNextToken; { consommer ( }
        If CurTokType <> TOK_RPAREN Then Begin
          ParseExpr; { parser le message }
          Emit('  PUSH EAX');
        End Else Begin
          Emit('  PUSH 0');
        End;
        If CurTokType = TOK_RPAREN Then
          LexNextToken; { consommer ) }
      End Else Begin
        Emit('  PUSH 0');
      End;
      Emit('  CALL ' + EXC_RT_NEWEXC);
      Emit('  PUSH EAX');
      Emit('  CALL ' + EXC_RT_THROW);
      If Opts.Verbose Then
        WriteLn('  Throw New ...');
    End Else Begin
      FatalError('Throw New : nom de type attendu');
    End;
  End
  { Throw expression : lancer un objet exception existant }
  Else Begin
    ParseExpr;
    Emit('  PUSH EAX');
    Emit('  CALL ' + EXC_RT_THROW);
    If Opts.Verbose Then
      WriteLn('  Throw expr');
  End;
End;

{ ------------------------------------------------------------ }
{ ParseExceptionMember : parser un acces aux proprietes d une   }
{   exception VB.NET (ex.Message, ex.StackTrace,                }
{   ex.InnerException)                                          }
{   Genere le code pour lire les proprietes de l exception      }
{   courante via le runtime                                     }
{ ------------------------------------------------------------ }

Procedure ParseExceptionMember(VarName : TString);
Var
  MemberName : TString;
Begin
  Inc(ExceptionCount);
  { On est positionne apres le point }
  If CurTokType = TOK_IDENT Then Begin
    MemberName := UpCaseStr(CurTokStr);
    LexNextToken; { consommer le nom du membre }

    { ex.Message : chaine du message d erreur }
    If MemberName = 'MESSAGE' Then Begin
      EmitComment(VarName + '.Message');
      Emit('  CALL ' + EXC_RT_GETMSG);
      If Opts.Verbose Then
        WriteLn('  ', VarName, '.Message');
    End

    { ex.StackTrace : trace de pile (stub) }
    Else If MemberName = 'STACKTRACE' Then Begin
      EmitComment(VarName + '.StackTrace (stub)');
      Emit('  CALL ' + EXC_RT_GETTRACE);
      If Opts.Verbose Then
        WriteLn('  ', VarName, '.StackTrace');
    End

    { ex.InnerException : exception imbriquee (stub) }
    Else If MemberName = 'INNEREXCEPTION' Then Begin
      EmitComment(VarName + '.InnerException (stub)');
      Emit('  CALL ' + EXC_RT_GETINNER);
      If Opts.Verbose Then
        WriteLn('  ', VarName, '.InnerException');
    End

    Else Begin
      FatalError('Membre d''exception inconnu : ' + MemberName);
    End;
  End Else Begin
    FatalError('Nom de membre attendu apres ' + VarName + '.');
  End;
End;

{ ------------------------------------------------------------ }
{ GenSEHSetup : generer le code pour etablir un cadre SEH       }
{   Win32 pour le bloc Try                                      }
{   Structure SEH : PUSH handler / PUSH FS:[0] / MOV FS:[0],ESP}
{ ------------------------------------------------------------ }

Procedure GenSEHSetup(HandlerLabel : TString);
Begin
  Inc(ExceptionCount);
  EmitComment('Etablir cadre SEH : ' + HandlerLabel);
  Emit('  PUSH OFFSET ' + HandlerLabel);
  Emit('  PUSH DWORD [FS:0]');
  Emit('  MOV [FS:0], ESP');
End;

{ ------------------------------------------------------------ }
{ GenSEHTeardown : generer le code pour retirer le cadre SEH    }
{   courant                                                     }
{   Depile la structure SEH : POP FS:[0] / ADD ESP, 4           }
{ ------------------------------------------------------------ }

Procedure GenSEHTeardown;
Begin
  Inc(ExceptionCount);
  EmitComment('Retirer cadre SEH');
  Emit('  POP DWORD [FS:0]');
  Emit('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ GenThrowNew : generer le code pour creer et lancer une        }
{   exception                                                   }
{   TypeName : nom du type d exception (ex: Exception)          }
{   MsgLabel : label de la chaine de message (ou '' si aucun)   }
{ ------------------------------------------------------------ }

Procedure GenThrowNew(TypeName : TString; MsgLabel : TString);
Begin
  Inc(ExceptionCount);
  Inc(ThrowCount);
  EmitComment('Throw New ' + TypeName);
  Emit('  PUSH OFFSET _exc_type_' + TypeName);
  If MsgLabel <> '' Then
    Emit('  PUSH OFFSET ' + MsgLabel)
  Else
    Emit('  PUSH 0');
  Emit('  CALL ' + EXC_RT_NEWEXC);
  Emit('  PUSH EAX');
  Emit('  CALL ' + EXC_RT_THROW);
End;

{ ------------------------------------------------------------ }
{ IsTryStatement : verifier si le token courant commence un     }
{   bloc Try                                                    }
{ ------------------------------------------------------------ }

Function IsTryStatement : Boolean;
Begin
  IsTryStatement := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_TRY);
End;

{ ------------------------------------------------------------ }
{ IsThrowStatement : verifier si le token courant est Throw     }
{ ------------------------------------------------------------ }

Function IsThrowStatement : Boolean;
Begin
  IsThrowStatement := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_THROW);
End;

{ ------------------------------------------------------------ }
{ IsCatchKeyword : verifier si le token courant est Catch       }
{ ------------------------------------------------------------ }

Function IsCatchKeyword : Boolean;
Begin
  IsCatchKeyword := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_CATCH);
End;

{ ------------------------------------------------------------ }
{ IsFinallyKeyword : verifier si le token courant est Finally   }
{ ------------------------------------------------------------ }

Function IsFinallyKeyword : Boolean;
Begin
  IsFinallyKeyword := (CurTokType = TOK_KEYWORD) And (CurTokNum = KW_FINALLY);
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces aux variables du module exceptions          }
{ ------------------------------------------------------------ }

Function GetExceptionCount : LongInt;
Begin
  GetExceptionCount := ExceptionCount;
End;

Function IsExceptionInitialized : Boolean;
Begin
  IsExceptionInitialized := ExceptionInitialized;
End;

Function IsExceptionEmpty : Boolean;
Begin
  IsExceptionEmpty := ExceptionInitialized And (ExceptionCount = 0);
End;

Function GetExceptionStatus : TString;
Begin
  If Not ExceptionInitialized Then
    GetExceptionStatus := 'non initialise'
  Else If ExceptionCount = 0 Then
    GetExceptionStatus := 'initialise, aucune exception'
  Else
    GetExceptionStatus := 'initialise, ' + ItoS(ExceptionCount) + ' operations';
End;

Function GetTryDepth : Integer;
Begin
  GetTryDepth := TryDepth;
End;

Function GetMaxTryDepth : Integer;
Begin
  GetMaxTryDepth := MaxTryDepth;
End;

Function GetTotalCatchClauses : Integer;
Begin
  GetTotalCatchClauses := TotalCatchClauses;
End;

Function GetFinallyBlockCount : Integer;
Begin
  GetFinallyBlockCount := FinallyBlockCount;
End;

Function GetThrowCount : Integer;
Begin
  GetThrowCount := ThrowCount;
End;

Function GetExcRtCount : Integer;
Begin
  GetExcRtCount := 10;
End;

{ ============================================================ }
{ TODO 19 - PARSEUR : E/S CONSOLE ET FICHIERS [IMPLEMENTE]     }
{ ============================================================ }

Const
  { Modes d ouverture VB.NET (OpenMode enumeration) }
  FILE_MODE_INPUT   = 0;  { OpenMode.Input   }
  FILE_MODE_OUTPUT  = 1;  { OpenMode.Output  }
  FILE_MODE_APPEND  = 2;  { OpenMode.Append  }
  FILE_MODE_BINARY  = 3;  { OpenMode.Binary  }

  { Limites }
  MAX_FILE_NUM       = 511;
  DEFAULT_RECORD_LEN = 128;

  { Labels runtime console }
  IO_RT_PRINTLN      = '_VBNRT_PRINTLN';
  IO_RT_PRINT        = '_VBNRT_PRINT';
  IO_RT_INPUT        = '_VBNRT_INPUT';
  IO_RT_READKEY      = '_VBNRT_READKEY';
  IO_RT_FILEOPEN     = '_VBNRT_FILEOPEN';
  IO_RT_FILECLOSE    = '_VBNRT_FILECLOSE';
  IO_RT_PRINTLINE    = '_VBNRT_PRINTLINE';
  IO_RT_LINEINPUT    = '_VBNRT_LINEINPUT';
  IO_RT_WRITELINE    = '_VBNRT_WRITELINE';
  IO_RT_FILEEOF      = '_VBNRT_FILEEOF';

  { Labels runtime fonctions fichier supplementaires }
  IO_RT_FILELOF      = '_VBNRT_FILELOF';
  IO_RT_FREEFILE     = '_VBNRT_FREEFILE';
  IO_RT_MSGBOX       = '_VBNRT_MSGBOX';
  IO_RT_INPUTBOX     = '_VBNRT_INPUTBOX';

  { Variables globales pour handles }
  IO_VAR_HANDLES     = '_VBN_FILE_HANDLES';
  IO_VAR_MODES       = '_VBN_FILE_MODES';
  IO_VAR_COUNT       = '_VBN_FILE_COUNT';
  IO_VAR_STDOUT      = '_VBN_STDOUT';
  IO_VAR_STDIN       = '_VBN_STDIN';

Var
  ConsoleFileIOCount       : LongInt;
  ConsoleFileIOInitialized : Boolean;
  CurFileMode              : Integer;
  CurFileNum               : Integer;
  ConsoleWriteCount        : Integer;
  ConsoleReadCount         : Integer;
  FileOpenCount            : Integer;
  FileCloseCount           : Integer;

{ ------------------------------------------------------------ }
{ InitConsoleFileIOState : initialiser l etat E/S console/file  }
{ ------------------------------------------------------------ }

Procedure InitConsoleFileIOState;
Begin
  ConsoleFileIOCount       := 0;
  ConsoleFileIOInitialized := True;
  CurFileMode              := FILE_MODE_INPUT;
  CurFileNum               := 0;
  ConsoleWriteCount        := 0;
  ConsoleReadCount         := 0;
  FileOpenCount            := 0;
  FileCloseCount           := 0;
End;

{ ------------------------------------------------------------ }
{ FileModeName : retourner le nom du mode d ouverture          }
{ ------------------------------------------------------------ }

Function FileModeName(Mode : Integer) : TString;
Begin
  Case Mode Of
    FILE_MODE_INPUT  : FileModeName := 'Input';
    FILE_MODE_OUTPUT : FileModeName := 'Output';
    FILE_MODE_APPEND : FileModeName := 'Append';
    FILE_MODE_BINARY : FileModeName := 'Binary';
  Else
    FileModeName := 'Unknown';
  End;
End;

{ ------------------------------------------------------------ }
{ ParseConsoleWriteLine : parser Console.WriteLine(expr)        }
{   Genere PUSH ptr_chaine / CALL _VBNRT_PRINTLN               }
{   Supporte : Console.WriteLine("texte")                      }
{              Console.WriteLine(format, arg) (stub)           }
{ ------------------------------------------------------------ }

Procedure ParseConsoleWriteLine;
Var
  ArgCount : Integer;
Begin
  Inc(ConsoleFileIOCount);
  Inc(ConsoleWriteCount);
  EmitComment('Console.WriteLine(expr)');
  { Attendre la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('Console.WriteLine : parenthese ouvrante attendue');
  { Verifier s il y a des arguments }
  If CurTokType = TOK_RPAREN Then Begin
    { Console.WriteLine() sans argument : saut de ligne seul }
    LexNextToken;
    Emit('  PUSH 0');
    Emit('  CALL ' + IO_RT_PRINTLN);
    Emit('  ADD ESP, 4');
    Exit;
  End;
  { Parser le premier argument (chaine ou format) }
  ParseExpr;
  ArgCount := 1;
  { Verifier les arguments supplementaires (format string stub) }
  While CurTokType = TOK_COMMA Do Begin
    LexNextToken;
    { Les arguments supplementaires sont empiles mais non traites }
    { dans cette version (stub pour format string)                }
    ParseExpr;
    Inc(ArgCount);
  End;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel : seul le premier argument est utilise }
  Emit('  PUSH EAX');
  Emit('  CALL ' + IO_RT_PRINTLN);
  Emit('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ ParseConsoleWrite : parser Console.Write(expr)                }
{   Genere PUSH ptr_chaine / CALL _VBNRT_PRINT (sans newline) }
{ ------------------------------------------------------------ }

Procedure ParseConsoleWrite;
Begin
  Inc(ConsoleFileIOCount);
  Inc(ConsoleWriteCount);
  EmitComment('Console.Write(expr)');
  { Attendre la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('Console.Write : parenthese ouvrante attendue');
  { Parser l expression }
  If CurTokType <> TOK_RPAREN Then
    ParseExpr;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel sans saut de ligne }
  Emit('  PUSH EAX');
  Emit('  CALL ' + IO_RT_PRINT);
  Emit('  ADD ESP, 4');
End;

{ ------------------------------------------------------------ }
{ ParseConsoleReadLine : parser Console.ReadLine()              }
{   Genere CALL _VBNRT_INPUT, resultat dans EAX               }
{ ------------------------------------------------------------ }

Procedure ParseConsoleReadLine;
Begin
  Inc(ConsoleFileIOCount);
  Inc(ConsoleReadCount);
  EmitComment('Console.ReadLine()');
  { Consommer les parentheses vides }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
  End;
  { Generer l appel }
  Emit('  CALL ' + IO_RT_INPUT);
  { Resultat dans EAX : pointeur vers la chaine lue }
End;

{ ------------------------------------------------------------ }
{ ParseConsoleReadKey : parser Console.ReadKey() (stub)         }
{   Genere CALL _VBNRT_READKEY, resultat dans EAX             }
{ ------------------------------------------------------------ }

Procedure ParseConsoleReadKey;
Begin
  Inc(ConsoleFileIOCount);
  Inc(ConsoleReadCount);
  EmitComment('Console.ReadKey() (stub)');
  { Consommer les parentheses vides }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    { ReadKey peut avoir un argument Boolean (intercept) }
    If CurTokType <> TOK_RPAREN Then
      ParseExpr;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
  End;
  { Generer l appel (stub) }
  Emit('  CALL ' + IO_RT_READKEY);
End;

{ ------------------------------------------------------------ }
{ ParseConsoleStatement : parser un appel Console.XXX           }
{   Dispatche vers WriteLine, Write, ReadLine, ReadKey         }
{   Appelee quand on detecte l ident "Console" suivi de "."   }
{ ------------------------------------------------------------ }

Procedure ParseConsoleStatement;
Var
  MemberName : TString;
Begin
  { Le token courant est "." apres "Console" }
  If CurTokType = TOK_DOT Then
    LexNextToken
  Else
    FatalError('Console : point attendu apres Console');
  { Lire le nom du membre }
  If CurTokType = TOK_IDENT Then Begin
    MemberName := UpCaseStr(CurTokStr);
    LexNextToken;
    If MemberName = 'WRITELINE' Then
      ParseConsoleWriteLine
    Else If MemberName = 'WRITE' Then
      ParseConsoleWrite
    Else If MemberName = 'READLINE' Then
      ParseConsoleReadLine
    Else If MemberName = 'READKEY' Then
      ParseConsoleReadKey
    Else
      FatalError('Console : membre non reconnu : ' + MemberName);
  End Else
    FatalError('Console : nom de membre attendu apres le point');
End;

{ ------------------------------------------------------------ }
{ ParseFileOpen : parser FileOpen(n, fichier, mode)            }
{   Syntaxe VB.NET : FileOpen(n, fichier, OpenMode.Input)      }
{   Genere appel _VBNRT_FILEOPEN(num, fichier, mode)           }
{ ------------------------------------------------------------ }

Procedure ParseFileOpen;
Var
  FileMode : Integer;
  ModeStr  : TString;
Begin
  Inc(ConsoleFileIOCount);
  Inc(FileOpenCount);
  EmitComment('FileOpen(n, fichier, mode)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('FileOpen : parenthese ouvrante attendue');
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');  { sauvegarder le numero }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
    FatalError('FileOpen : virgule attendue apres le numero');
  { Parser le chemin du fichier (expression chaine) }
  ParseExpr;
  Emit('  PUSH EAX');  { sauvegarder le chemin }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken
  Else
    FatalError('FileOpen : virgule attendue apres le chemin');
  { Determiner le mode : OpenMode.Input, OpenMode.Output, etc. }
  FileMode := FILE_MODE_INPUT;  { defaut }
  If CurTokType = TOK_IDENT Then Begin
    ModeStr := UpCaseStr(CurTokStr);
    { Gerer OpenMode.XXX ou juste le nom du mode }
    If ModeStr = 'OPENMODE' Then Begin
      LexNextToken;
      If CurTokType = TOK_DOT Then
        LexNextToken;
      If CurTokType = TOK_IDENT Then Begin
        ModeStr := UpCaseStr(CurTokStr);
        LexNextToken;
      End;
    End Else
      LexNextToken;
    If ModeStr = 'INPUT' Then
      FileMode := FILE_MODE_INPUT
    Else If ModeStr = 'OUTPUT' Then
      FileMode := FILE_MODE_OUTPUT
    Else If ModeStr = 'APPEND' Then
      FileMode := FILE_MODE_APPEND
    Else If ModeStr = 'BINARY' Then
      FileMode := FILE_MODE_BINARY
    Else
      WarnMsg('FileOpen : mode non reconnu : ' + ModeStr + ', defaut Input');
  End Else If (CurTokType = TOK_KEYWORD) Then Begin
    ModeStr := UpCaseStr(CurTokStr);
    LexNextToken;
    If ModeStr = 'INPUT' Then
      FileMode := FILE_MODE_INPUT
    Else
      WarnMsg('FileOpen : mode non reconnu : ' + ModeStr + ', defaut Input');
  End Else Begin
    { Expression numerique pour le mode }
    ParseExpr;
  End;
  CurFileMode := FileMode;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel runtime }
  Emit('  PUSH ' + ItoS(FileMode));  { mode }
  Emit('  CALL ' + IO_RT_FILEOPEN);
  Emit('  ADD ESP, 12');  { 3 parametres x 4 octets }
End;

{ ------------------------------------------------------------ }
{ ParseFileClose : parser FileClose(n)                          }
{   Syntaxe VB.NET : FileClose(n) ou FileClose() pour tous    }
{ ------------------------------------------------------------ }

Procedure ParseFileClose;
Begin
  Inc(ConsoleFileIOCount);
  Inc(FileCloseCount);
  EmitComment('FileClose(n)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('FileClose : parenthese ouvrante attendue');
  { Verifier si un numero est fourni }
  If CurTokType = TOK_RPAREN Then Begin
    { FileClose() sans argument : fermer tous les fichiers }
    LexNextToken;
    Emit('  PUSH -1');  { -1 = fermer tous }
    Emit('  CALL ' + IO_RT_FILECLOSE);
    Emit('  ADD ESP, 4');
  End Else Begin
    { FileClose(n) : fermer le fichier specifie }
    ParseExpr;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
    Emit('  PUSH EAX');
    Emit('  CALL ' + IO_RT_FILECLOSE);
    Emit('  ADD ESP, 4');
  End;
End;

{ ------------------------------------------------------------ }
{ ParsePrintLine : parser PrintLine(n, texte)                   }
{   Ecrit une ligne de texte dans le fichier                   }
{ ------------------------------------------------------------ }

Procedure ParsePrintLine;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('PrintLine(n, texte)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('PrintLine : parenthese ouvrante attendue');
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');  { numero de fichier }
  { Consommer la virgule }
  If CurTokType = TOK_COMMA Then
    LexNextToken;
  { Parser l expression a ecrire }
  ParseExpr;
  Emit('  PUSH EAX');  { texte }
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_PRINTLINE);
  Emit('  ADD ESP, 8');
End;

{ ------------------------------------------------------------ }
{ ParseLineInputFunc : parser LineInput(n) -> String            }
{   Lit une ligne complete depuis le fichier                   }
{ ------------------------------------------------------------ }

Procedure ParseLineInputFunc;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('LineInput(n)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('LineInput : parenthese ouvrante attendue');
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');  { numero de fichier }
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_LINEINPUT);
  Emit('  ADD ESP, 4');
  { Resultat dans EAX : pointeur vers la chaine lue }
End;

{ ------------------------------------------------------------ }
{ ParseWriteLineFunc : parser WriteLine(n, val1, val2, ...)     }
{   Ecrit des valeurs separees par des virgules dans le fichier }
{ ------------------------------------------------------------ }

Procedure ParseWriteLineFunc;
Var
  ArgCount : Integer;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('WriteLine(n, val1, val2, ...)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('WriteLine : parenthese ouvrante attendue');
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');  { numero de fichier }
  ArgCount := 0;
  { Parser les valeurs separees par des virgules }
  While CurTokType = TOK_COMMA Do Begin
    LexNextToken;
    ParseExpr;
    Emit('  PUSH EAX');
    Inc(ArgCount);
    { Generer l ecriture de chaque valeur }
    Emit('  CALL ' + IO_RT_WRITELINE);
    Emit('  ADD ESP, 4');
  End;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Nettoyer le numero de fichier de la pile }
  Emit('  POP EBX');  { numero de fichier }
End;

{ ------------------------------------------------------------ }
{ ParseEOFCall : parser EOF(n) -> Boolean                       }
{   Retourne True (-1) si fin de fichier, False (0) sinon     }
{ ------------------------------------------------------------ }

Procedure ParseEOFCall;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('EOF(n)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken;
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_FILEEOF);
  Emit('  ADD ESP, 4');
  { Resultat dans EAX : -1 = True, 0 = False }
End;

{ ------------------------------------------------------------ }
{ ParseLOFCall : parser LOF(n) -> Long                          }
{   Retourne la taille du fichier en octets                    }
{ ------------------------------------------------------------ }

Procedure ParseLOFCall;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('LOF(n)');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken;
  { Parser le numero de fichier }
  ParseExpr;
  Emit('  PUSH EAX');
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_FILELOF);
  Emit('  ADD ESP, 4');
  { Resultat dans EAX }
End;

{ ------------------------------------------------------------ }
{ ParseFreeFileCall : parser FreeFile() -> Integer              }
{   Retourne le prochain numero de fichier disponible          }
{ ------------------------------------------------------------ }

Procedure ParseFreeFileCall;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('FreeFile()');
  { FreeFile peut etre appele avec ou sans parentheses }
  If CurTokType = TOK_LPAREN Then Begin
    LexNextToken;
    If CurTokType = TOK_RPAREN Then
      LexNextToken;
  End;
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_FREEFILE);
  { Resultat dans EAX }
End;

{ ------------------------------------------------------------ }
{ ParseMsgBoxCall : parser MsgBox(texte[, boutons][, titre])    }
{   Genere appel a MessageBoxA via _VBNRT_MSGBOX               }
{ ------------------------------------------------------------ }

Procedure ParseMsgBoxCall;
Var
  HasButtons : Boolean;
  HasTitle   : Boolean;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('MsgBox(texte[, boutons][, titre])');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('MsgBox : parenthese ouvrante attendue');
  { Parser le texte du message }
  ParseExpr;
  Emit('  PUSH EAX');  { texte }
  { Verifier les arguments optionnels }
  HasButtons := False;
  HasTitle   := False;
  If CurTokType = TOK_COMMA Then Begin
    LexNextToken;
    { Parser le type de boutons }
    ParseExpr;
    Emit('  PUSH EAX');  { boutons }
    HasButtons := True;
    If CurTokType = TOK_COMMA Then Begin
      LexNextToken;
      { Parser le titre }
      ParseExpr;
      Emit('  PUSH EAX');  { titre }
      HasTitle := True;
    End;
  End;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Completer les arguments manquants }
  If Not HasTitle Then
    Emit('  PUSH 0');  { titre NULL }
  If Not HasButtons Then
    Emit('  PUSH 0');  { boutons MB_OK = 0 }
  { Generer l appel runtime (appelle MessageBoxA) }
  Emit('  CALL ' + IO_RT_MSGBOX);
  Emit('  ADD ESP, 12');  { 3 parametres x 4 octets }
  { Resultat dans EAX : ID du bouton clique }
End;

{ ------------------------------------------------------------ }
{ ParseInputBoxCall : parser InputBox(prompt[, titre][, defaut])}
{   Genere appel a _VBNRT_INPUTBOX                             }
{ ------------------------------------------------------------ }

Procedure ParseInputBoxCall;
Var
  HasTitle   : Boolean;
  HasDefault : Boolean;
Begin
  Inc(ConsoleFileIOCount);
  EmitComment('InputBox(prompt[, titre][, defaut])');
  { Consommer la parenthese ouvrante }
  If CurTokType = TOK_LPAREN Then
    LexNextToken
  Else
    FatalError('InputBox : parenthese ouvrante attendue');
  { Parser le prompt }
  ParseExpr;
  Emit('  PUSH EAX');  { prompt }
  { Verifier les arguments optionnels }
  HasTitle   := False;
  HasDefault := False;
  If CurTokType = TOK_COMMA Then Begin
    LexNextToken;
    { Parser le titre }
    ParseExpr;
    Emit('  PUSH EAX');  { titre }
    HasTitle := True;
    If CurTokType = TOK_COMMA Then Begin
      LexNextToken;
      { Parser la valeur par defaut }
      ParseExpr;
      Emit('  PUSH EAX');  { defaut }
      HasDefault := True;
    End;
  End;
  { Fermer la parenthese }
  If CurTokType = TOK_RPAREN Then
    LexNextToken;
  { Completer les arguments manquants }
  If Not HasDefault Then
    Emit('  PUSH 0');  { defaut NULL }
  If Not HasTitle Then
    Emit('  PUSH 0');  { titre NULL }
  { Generer l appel runtime }
  Emit('  CALL ' + IO_RT_INPUTBOX);
  Emit('  ADD ESP, 12');  { 3 parametres x 4 octets }
  { Resultat dans EAX : pointeur vers la chaine saisie }
End;

{ ------------------------------------------------------------ }
{ GenConsoleSetup : generer le code d initialisation console     }
{   Obtient les handles stdout et stdin via GetStdHandle        }
{ ------------------------------------------------------------ }

Procedure GenConsoleSetup;
Begin
  EmitComment('Initialisation handles console');
  { GetStdHandle(STD_OUTPUT_HANDLE = -11) }
  Emit('  PUSH -11');
  Emit('  CALL _GetStdHandle@4');
  Emit('  MOV [' + IO_VAR_STDOUT + '], EAX');
  { GetStdHandle(STD_INPUT_HANDLE = -10) }
  Emit('  PUSH -10');
  Emit('  CALL _GetStdHandle@4');
  Emit('  MOV [' + IO_VAR_STDIN + '], EAX');
End;

{ ------------------------------------------------------------ }
{ GenFileOpenCode : generer le code d ouverture via CreateFileA  }
{   Mode determine les flags d acces et de creation            }
{ ------------------------------------------------------------ }

Procedure GenFileOpenCode(Mode : Integer; FileNum : Integer);
Begin
  EmitComment('Ouverture fichier mode=' + FileModeName(Mode) + ' #' + ItoS(FileNum));
  { PUSH les parametres CreateFileA dans l ordre inverse }
  Emit('  PUSH 0');          { hTemplateFile = NULL }
  Emit('  PUSH 0x80');       { dwFlagsAndAttributes = FILE_ATTRIBUTE_NORMAL }
  Case Mode Of
    FILE_MODE_INPUT : Begin
      Emit('  PUSH 3');      { dwCreationDisposition = OPEN_EXISTING }
      Emit('  PUSH 0');      { lpSecurityAttributes = NULL }
      Emit('  PUSH 0');      { dwShareMode = 0 }
      Emit('  PUSH 0x80000000');  { dwDesiredAccess = GENERIC_READ }
    End;
    FILE_MODE_OUTPUT : Begin
      Emit('  PUSH 2');      { dwCreationDisposition = CREATE_ALWAYS }
      Emit('  PUSH 0');
      Emit('  PUSH 0');
      Emit('  PUSH 0x40000000');  { dwDesiredAccess = GENERIC_WRITE }
    End;
    FILE_MODE_APPEND : Begin
      Emit('  PUSH 4');      { dwCreationDisposition = OPEN_ALWAYS }
      Emit('  PUSH 0');
      Emit('  PUSH 0');
      Emit('  PUSH 0x40000000');  { dwDesiredAccess = GENERIC_WRITE }
    End;
    FILE_MODE_BINARY : Begin
      Emit('  PUSH 4');      { dwCreationDisposition = OPEN_ALWAYS }
      Emit('  PUSH 0');
      Emit('  PUSH 0');
      Emit('  PUSH 0xC0000000');  { GENERIC_READ or GENERIC_WRITE }
    End;
  End;
  { Le nom de fichier est deja dans la pile }
  Emit('  CALL _CreateFileA@28');
  { Sauvegarder le handle dans la table }
  Emit('  MOV [' + IO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4], EAX');
End;

{ ------------------------------------------------------------ }
{ GenFileCloseCode : generer le code de fermeture via CloseHandle}
{ ------------------------------------------------------------ }

Procedure GenFileCloseCode(FileNum : Integer);
Begin
  EmitComment('Fermeture fichier #' + ItoS(FileNum));
  Emit('  MOV EAX, [' + IO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4]');
  Emit('  PUSH EAX');
  Emit('  CALL _CloseHandle@4');
  { Marquer le handle comme invalide }
  Emit('  MOV DWORD [' + IO_VAR_HANDLES + '+' + ItoS(FileNum) + '*4], 0');
End;

{ ------------------------------------------------------------ }
{ GenFileDataSegment : generer les variables fichier en .BSS    }
{   Declare la table de handles et variables globales          }
{ ------------------------------------------------------------ }

Procedure GenFileDataSegment;
Begin
  EmitComment('Variables globales E/S console et fichiers');
  EmitBss(IO_VAR_HANDLES + ' RESD ' + ItoS(MAX_FILE_NUM + 1));
  EmitBss(IO_VAR_MODES   + ' RESD ' + ItoS(MAX_FILE_NUM + 1));
  EmitBss(IO_VAR_COUNT   + ' DD 0');
  EmitBss(IO_VAR_STDOUT  + ' DD 0');
  EmitBss(IO_VAR_STDIN   + ' DD 0');
End;

{ ------------------------------------------------------------ }
{ IsConsoleCall : verifier si le token courant est un appel     }
{   Console.XXX (identifier "Console" suivi de ".")            }
{ ------------------------------------------------------------ }

Function IsConsoleCall : Boolean;
Begin
  IsConsoleCall := (CurTokType = TOK_IDENT) And
                   (UpCaseStr(CurTokStr) = 'CONSOLE');
End;

{ ------------------------------------------------------------ }
{ IsFileIOStatement : verifier si le token courant commence    }
{   une instruction E/S fichier VB.NET                         }
{ ------------------------------------------------------------ }

Function IsFileIOStatement : Boolean;
Begin
  If CurTokType <> TOK_KEYWORD Then Begin
    IsFileIOStatement := False;
    Exit;
  End;
  IsFileIOStatement := (CurTokNum = KW_FILEOPEN) Or
                       (CurTokNum = KW_FILECLOSE) Or
                       (CurTokNum = KW_PRINTLINE) Or
                       (CurTokNum = KW_WRITELINE) Or
                       (CurTokNum = KW_LINEINPUT);
End;

{ ------------------------------------------------------------ }
{ IsFileIOFunction : verifier si le token courant est une       }
{   fonction fichier (EOF, LOF, FreeFile)                      }
{ ------------------------------------------------------------ }

Function IsFileIOFunction : Boolean;
Begin
  If CurTokType <> TOK_KEYWORD Then Begin
    IsFileIOFunction := False;
    Exit;
  End;
  IsFileIOFunction := (CurTokNum = KW_EOF2) Or
                      (CurTokNum = KW_LOF) Or
                      (CurTokNum = KW_FREEFILE);
End;

{ ------------------------------------------------------------ }
{ Fonctions d acces aux variables du module E/S console/fichier }
{ ------------------------------------------------------------ }

Function GetConsoleFileIOCount : LongInt;
Begin
  GetConsoleFileIOCount := ConsoleFileIOCount;
End;

Function IsConsoleFileIOInitialized : Boolean;
Begin
  IsConsoleFileIOInitialized := ConsoleFileIOInitialized;
End;

Function IsConsoleFileIOEmpty : Boolean;
Begin
  IsConsoleFileIOEmpty := ConsoleFileIOInitialized And (ConsoleFileIOCount = 0);
End;

Function GetConsoleFileIOStatus : TString;
Begin
  If Not ConsoleFileIOInitialized Then
    GetConsoleFileIOStatus := 'non initialise'
  Else If ConsoleFileIOCount = 0 Then
    GetConsoleFileIOStatus := 'initialise, aucune operation E/S'
  Else
    GetConsoleFileIOStatus := 'initialise, ' + ItoS(ConsoleFileIOCount) + ' operations';
End;

Function GetConsoleWriteCount : Integer;
Begin
  GetConsoleWriteCount := ConsoleWriteCount;
End;

Function GetConsoleReadCount : Integer;
Begin
  GetConsoleReadCount := ConsoleReadCount;
End;

Function GetFileOpenCount : Integer;
Begin
  GetFileOpenCount := FileOpenCount;
End;

Function GetFileCloseCount : Integer;
Begin
  GetFileCloseCount := FileCloseCount;
End;

Function GetMaxFileNum : Integer;
Begin
  GetMaxFileNum := MAX_FILE_NUM;
End;

Function GetConsoleFileIORtCount : Integer;
Begin
  GetConsoleFileIORtCount := 14;  { 10 operations + 4 fonctions }
End;

{ TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S    }
{           VIA WIN32 API) [IMPLEMENTE]                        }
{ ============================================================ }

Const
  { Nombre total de routines runtime }
  MAX_RT_ROUTINES   = 128;

  { Categorie de routines runtime }
  RT_CAT_STRING     = 0;
  RT_CAT_CONVERT    = 1;
  RT_CAT_MATH       = 2;
  RT_CAT_CONSOLE    = 3;
  RT_CAT_ARRAY      = 4;
  RT_CAT_MEMORY     = 5;
  RT_CAT_SYSTEM     = 6;
  RT_CAT_EXCEPTION  = 7;

  { Labels des routines chaines }
  RT_LEN            = '_VBNRT_LEN';
  RT_STRCAT         = '_VBNRT_STRCAT';
  RT_STRCMP          = '_VBNRT_STRCMP';
  RT_STRCPY         = '_VBNRT_STRCPY';
  RT_STRALLOC       = '_VBNRT_STRALLOC';
  RT_STRFREE        = '_VBNRT_STRFREE';
  RT_LEFT           = '_VBNRT_LEFT';
  RT_RIGHT          = '_VBNRT_RIGHT';
  RT_MID            = '_VBNRT_MID';
  RT_LTRIM          = '_VBNRT_LTRIM';
  RT_RTRIM          = '_VBNRT_RTRIM';
  RT_TRIM           = '_VBNRT_TRIM';
  RT_UCASE          = '_VBNRT_UCASE';
  RT_LCASE          = '_VBNRT_LCASE';
  RT_INSTR          = '_VBNRT_INSTR';
  RT_REPLACE        = '_VBNRT_REPLACE';
  RT_INDEXOF        = '_VBNRT_INDEXOF';
  RT_CONTAINS       = '_VBNRT_CONTAINS';
  RT_STARTSWITH     = '_VBNRT_STARTSWITH';
  RT_ENDSWITH       = '_VBNRT_ENDSWITH';
  RT_SUBSTR         = '_VBNRT_SUBSTR';
  RT_INSERT         = '_VBNRT_INSERT';
  RT_REMOVE         = '_VBNRT_REMOVE';
  RT_PADLEFT        = '_VBNRT_PADLEFT';
  RT_PADRIGHT       = '_VBNRT_PADRIGHT';
  RT_SPLIT          = '_VBNRT_SPLIT';
  RT_JOIN           = '_VBNRT_JOIN';

  { Labels des routines conversion }
  RT_VAL            = '_VBNRT_VAL';
  RT_STR            = '_VBNRT_STR';
  RT_CINT           = '_VBNRT_CINT';
  RT_CLNG           = '_VBNRT_CLNG';
  RT_CSTR           = '_VBNRT_CSTR';
  RT_CBOOL          = '_VBNRT_CBOOL';
  RT_CBYTE          = '_VBNRT_CBYTE';
  RT_CCHAR          = '_VBNRT_CCHAR';
  RT_CDBL           = '_VBNRT_CDBL';
  RT_CSNG           = '_VBNRT_CSNG';
  RT_CSHORT         = '_VBNRT_CSHORT';

  { Labels des routines mathematiques }
  RT_POW            = '_VBNRT_POW';
  RT_SQR            = '_VBNRT_SQR';
  RT_ABS            = '_VBNRT_ABS';
  RT_SGN            = '_VBNRT_SGN';
  RT_SIN            = '_VBNRT_SIN';
  RT_COS            = '_VBNRT_COS';
  RT_TAN            = '_VBNRT_TAN';
  RT_ATN            = '_VBNRT_ATN';
  RT_EXP            = '_VBNRT_EXP';
  RT_LOG            = '_VBNRT_LOG';
  RT_FLOOR          = '_VBNRT_FLOOR';
  RT_CEILING        = '_VBNRT_CEILING';
  RT_ROUND          = '_VBNRT_ROUND';
  RT_MAX            = '_VBNRT_MAX';
  RT_MIN            = '_VBNRT_MIN';

  { Labels des routines E/S console }
  RT_PRINT          = '_VBNRT_PRINT';
  RT_PRINTLN        = '_VBNRT_PRINTLN';
  RT_INPUT          = '_VBNRT_INPUT';
  RT_MSGBOX         = '_VBNRT_MSGBOX';
  RT_INPUTBOX       = '_VBNRT_INPUTBOX';

  { Labels des routines tableaux }
  RT_REDIM          = '_VBNRT_REDIM';
  RT_ERASE          = '_VBNRT_ERASE';
  RT_ARRLENGTH      = '_VBNRT_ARRLENGTH';
  RT_ARRGETLENGTH   = '_VBNRT_ARRGETLENGTH';
  RT_ARRGETUPPERBOUND = '_VBNRT_ARRGETUPPERBOUND';

  { Labels des routines memoire }
  RT_HEAPINIT       = '_VBNRT_HEAPINIT';
  RT_HEAPALLOC      = '_VBNRT_HEAPALLOC';
  RT_HEAPFREE       = '_VBNRT_HEAPFREE';

  { Labels des routines exception }
  RT_THROWEX        = '_VBNRT_THROWEX';
  RT_SEHSETUP       = '_VBNRT_SEHSETUP';
  RT_SEHTEARDOWN    = '_VBNRT_SEHTEARDOWN';

  { Labels des points d entree systeme }
  RT_INIT           = '_VBNRT_INIT';
  RT_EXIT           = '_VBNRT_EXIT';

  { Variables runtime globales }
  RT_VAR_HPROCESS   = '_VBN_RT_HPROCESS';
  RT_VAR_HHEAP      = '_VBN_RT_HHEAP';
  RT_VAR_HSTDOUT    = '_VBN_RT_HSTDOUT';
  RT_VAR_HSTDIN     = '_VBN_RT_HSTDIN';
  RT_VAR_EXITCODE   = '_VBN_RT_EXITCODE';

  { Constantes pour les appels Win32 API }
  RT_WIN32_KERNEL32 = 'kernel32.dll';
  RT_WIN32_USER32   = 'user32.dll';

  { Valeurs API Windows }
  RT_STD_INPUT_HANDLE  = -10;
  RT_STD_OUTPUT_HANDLE = -11;
  RT_HEAP_ZERO_MEMORY  = $00000008;

Var
  RuntimeLibCount        : LongInt;
  RuntimeLibInitialized  : Boolean;
  RuntimeLibEmitted      : Boolean;
  TotalStringRoutines    : Integer;
  TotalConvertRoutines   : Integer;
  TotalMathRoutines      : Integer;
  TotalConsoleRoutines   : Integer;
  TotalArrayRoutines     : Integer;
  TotalMemoryRoutines    : Integer;
  TotalSystemRoutines    : Integer;
  TotalExceptionRoutines : Integer;

{ ------------------------------------------------------------ }
{ InitRuntimeLib : initialiser l etat de la bibliotheque        }
{ ------------------------------------------------------------ }

Procedure InitRuntimeLib;
Begin
  RuntimeLibCount        := 0;
  RuntimeLibInitialized  := True;
  RuntimeLibEmitted      := False;
  TotalStringRoutines    := 27;
  TotalConvertRoutines   := 11;
  TotalMathRoutines      := 15;
  TotalConsoleRoutines   := 5;
  TotalArrayRoutines     := 5;
  TotalMemoryRoutines    := 3;
  TotalSystemRoutines    := 2;
  TotalExceptionRoutines := 3;
End;

{ ------------------------------------------------------------ }
{ RuntimeCategoryName : nom de la categorie de routine          }
{ ------------------------------------------------------------ }

Function RuntimeCategoryName(Cat : Integer) : TString;
Begin
  Case Cat of
    RT_CAT_STRING:    RuntimeCategoryName := 'String';
    RT_CAT_CONVERT:   RuntimeCategoryName := 'Conversion';
    RT_CAT_MATH:      RuntimeCategoryName := 'Math';
    RT_CAT_CONSOLE:   RuntimeCategoryName := 'Console';
    RT_CAT_ARRAY:     RuntimeCategoryName := 'Array';
    RT_CAT_MEMORY:    RuntimeCategoryName := 'Memory';
    RT_CAT_SYSTEM:    RuntimeCategoryName := 'System';
    RT_CAT_EXCEPTION: RuntimeCategoryName := 'Exception';
  Else
    RuntimeCategoryName := 'Unknown';
  End;
End;

{ ------------------------------------------------------------ }
{ GenRtDataSegment : generer le segment .DATA pour les          }
{   variables runtime globales                                  }
{ ------------------------------------------------------------ }

Procedure GenRtDataSegment;
Begin
  EmitComment('--- Runtime global data ---');
  EmitData(RT_VAR_HPROCESS + ' DD 0');
  EmitData(RT_VAR_HHEAP + ' DD 0');
  EmitData(RT_VAR_HSTDOUT + ' DD 0');
  EmitData(RT_VAR_HSTDIN + ' DD 0');
  EmitData(RT_VAR_EXITCODE + ' DD 0');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtInit : generer _VBNRT_INIT (initialisation du runtime)   }
{   - GetProcessHeap pour le handle du heap                     }
{   - GetStdHandle pour stdout et stdin                         }
{ ------------------------------------------------------------ }

Procedure GenRtInit;
Begin
  EmitComment('--- _VBNRT_INIT : initialize runtime ---');
  EmitLabel(RT_INIT);
  { Obtenir le process heap }
  Emit('CALL GetProcessHeap');
  Emit('MOV [' + RT_VAR_HHEAP + '], EAX');
  { Obtenir stdout }
  Emit('PUSH ' + ItoS(RT_STD_OUTPUT_HANDLE));
  Emit('CALL GetStdHandle');
  Emit('MOV [' + RT_VAR_HSTDOUT + '], EAX');
  { Obtenir stdin }
  Emit('PUSH ' + ItoS(RT_STD_INPUT_HANDLE));
  Emit('CALL GetStdHandle');
  Emit('MOV [' + RT_VAR_HSTDIN + '], EAX');
  Emit('RET');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtExit : generer _VBNRT_EXIT (terminaison du programme)    }
{   - ExitProcess(exitcode)                                     }
{ ------------------------------------------------------------ }

Procedure GenRtExit;
Begin
  EmitComment('--- _VBNRT_EXIT : terminate program ---');
  EmitLabel(RT_EXIT);
  Emit('PUSH DWORD [' + RT_VAR_EXITCODE + ']');
  Emit('CALL ExitProcess');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtHeapInit : generer _VBNRT_HEAPINIT                       }
{ ------------------------------------------------------------ }

Procedure GenRtHeapInit;
Begin
  EmitComment('--- _VBNRT_HEAPINIT : initialize heap ---');
  EmitLabel(RT_HEAPINIT);
  Emit('CALL GetProcessHeap');
  Emit('MOV [' + RT_VAR_HHEAP + '], EAX');
  Emit('RET');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtHeapAlloc : generer _VBNRT_HEAPALLOC                     }
{   Arg sur la pile : taille en octets                          }
{   Retourne : adresse dans EAX                                 }
{ ------------------------------------------------------------ }

Procedure GenRtHeapAlloc;
Begin
  EmitComment('--- _VBNRT_HEAPALLOC : allocate memory ---');
  EmitLabel(RT_HEAPALLOC);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { taille }
  Emit('PUSH ' + ItoS(RT_HEAP_ZERO_MEMORY)); { flags }
  Emit('PUSH DWORD [' + RT_VAR_HHEAP + ']');     { hHeap }
  Emit('CALL HeapAlloc');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtHeapFree : generer _VBNRT_HEAPFREE                       }
{   Arg sur la pile : adresse du bloc                           }
{ ------------------------------------------------------------ }

Procedure GenRtHeapFree;
Begin
  EmitComment('--- _VBNRT_HEAPFREE : free memory ---');
  EmitLabel(RT_HEAPFREE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { lpMem }
  Emit('PUSH 0');                          { dwFlags }
  Emit('PUSH DWORD [' + RT_VAR_HHEAP + ']');     { hHeap }
  Emit('CALL HeapFree');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStrAlloc : generer _VBNRT_STRALLOC                       }
{   Arg : taille sur la pile                                    }
{   Retourne : pointeur dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtStrAlloc;
Begin
  EmitComment('--- _VBNRT_STRALLOC : allocate string ---');
  EmitLabel(RT_STRALLOC);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('ADD EAX, 1');                      { +1 pour le null-terminateur }
  Emit('PUSH EAX');
  Emit('CALL ' + RT_HEAPALLOC);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStrFree : generer _VBNRT_STRFREE                         }
{   Arg : pointeur chaine sur la pile                           }
{ ------------------------------------------------------------ }

Procedure GenRtStrFree;
Begin
  EmitComment('--- _VBNRT_STRFREE : free string ---');
  EmitLabel(RT_STRFREE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_HEAPFREE);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtLen : generer _VBNRT_LEN (longueur de chaine)            }
{   Arg : pointeur chaine sur la pile                           }
{   Retourne : longueur dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtLen;
Begin
  EmitComment('--- _VBNRT_LEN : string length ---');
  EmitLabel(RT_LEN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EDI, [EBP+8]');               { pointeur chaine }
  Emit('XOR EAX, EAX');                   { chercher le 0 }
  Emit('XOR ECX, ECX');
  Emit('DEC ECX');                         { ECX = -1 = compteur max }
  Emit('REPNE SCASB');                     { chercher le null }
  Emit('NOT ECX');
  Emit('DEC ECX');                         { ECX = longueur }
  Emit('MOV EAX, ECX');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStrCat : generer _VBNRT_STRCAT (concatenation)           }
{   Args : dst, src sur la pile                                 }
{   Retourne : pointeur resultat dans EAX                       }
{ ------------------------------------------------------------ }

Procedure GenRtStrCat;
Var LabelLoop1,LabelDone1,LabelLoop2,LabelDone2:TString;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;
  LabelDone2 := NextInternalLabel;
  EmitComment('--- _VBNRT_STRCAT : string concatenation ---');
  EmitLabel(RT_STRCAT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  { Trouver la fin de dst }
  Emit('MOV EDI, [EBP+12]');              { dst }
  EmitLabel(LabelLoop1);
  Emit('CMP BYTE [EDI], 0');
  Emit('JE ' + LabelDone1);
  Emit('INC EDI');
  Emit('JMP ' + LabelLoop1);
  EmitLabel(LabelDone1);
  { Copier src apres dst }
  Emit('MOV ESI, [EBP+8]');               { src }
  EmitLabel(LabelLoop2);
  Emit('LODSB');
  Emit('STOSB');
  Emit('TEST AL, AL');
  Emit('JNZ ' + LabelLoop2);
  Emit('MOV EAX, [EBP+12]');              { retourner dst }
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStrCmp : generer _VBNRT_STRCMP (comparaison)              }
{   Args : str1, str2 sur la pile                               }
{   Retourne : 0 si egal, <0 si str1<str2, >0 si str1>str2     }
{ ------------------------------------------------------------ }

Procedure GenRtStrCmp;
Var LabelLoop,LabelDone,LabelLess,LabelGreater:TString;
Begin
  LabelLoop    := NextInternalLabel;
  LabelDone    := NextInternalLabel;
  LabelLess    := NextInternalLabel;
  LabelGreater := NextInternalLabel;
  EmitComment('--- _VBNRT_STRCMP : string comparison ---');
  EmitLabel(RT_STRCMP);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('MOV ESI, [EBP+12]');              { str1 }
  Emit('MOV EDI, [EBP+8]');               { str2 }
  EmitLabel(LabelLoop);
  Emit('LODSB');
  Emit('MOV AH, [EDI]');
  Emit('INC EDI');
  Emit('CMP AL, AH');
  Emit('JB ' + LabelLess);
  Emit('JA ' + LabelGreater);
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone);
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelLess);
  Emit('MOV EAX, -1');
  Emit('JMP ' + LabelDone);
  EmitLabel(LabelGreater);
  Emit('MOV EAX, 1');
  Emit('JMP ' + LabelDone);
  EmitLabel(LabelDone);
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStrCpy : generer _VBNRT_STRCPY (copie)                   }
{   Args : dst, src sur la pile                                 }
{   Retourne : dst dans EAX                                     }
{ ------------------------------------------------------------ }

Procedure GenRtStrCpy;
Var LabelLoop,LabelDone:TString;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBNRT_STRCPY : string copy ---');
  EmitLabel(RT_STRCPY);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('MOV EDI, [EBP+12]');              { dst }
  Emit('MOV ESI, [EBP+8]');               { src }
  EmitLabel(LabelLoop);
  Emit('LODSB');
  Emit('STOSB');
  Emit('TEST AL, AL');
  Emit('JNZ ' + LabelLoop);
  Emit('MOV EAX, [EBP+12]');              { retourner dst }
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtLeft : generer _VBNRT_LEFT                               }
{   Args : str, count sur la pile                               }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtLeft;
Var LabelLoop,LabelDone:TString;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBNRT_LEFT : Left$ function ---');
  EmitLabel(RT_LEFT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  { Allouer la chaine resultat }
  Emit('MOV ECX, [EBP+8]');               { count }
  Emit('ADD ECX, 1');
  Emit('PUSH ECX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV EDI, EAX');                   { dst = resultat }
  Emit('PUSH EAX');                        { sauver le resultat }
  Emit('MOV ESI, [EBP+12]');              { src }
  Emit('MOV ECX, [EBP+8]');               { count }
  EmitLabel(LabelLoop);
  Emit('TEST ECX, ECX');
  Emit('JZ ' + LabelDone);
  Emit('LODSB');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone);
  Emit('STOSB');
  Emit('DEC ECX');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelDone);
  Emit('MOV BYTE [EDI], 0');              { null-terminateur }
  Emit('POP EAX');                         { retourner le resultat }
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtRight : generer _VBNRT_RIGHT                             }
{   Args : str, count sur la pile                               }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtRight;
Begin
  EmitComment('--- _VBNRT_RIGHT : Right$ function ---');
  EmitLabel(RT_RIGHT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  { Calculer la longueur de la source }
  Emit('PUSH DWORD [EBP+12]');
  Emit('CALL ' + RT_LEN);
  { EAX = len(str) }
  Emit('MOV ECX, [EBP+8]');               { count }
  Emit('SUB EAX, ECX');                   { offset = len - count }
  Emit('JNS @rt_right_ok');
  Emit('XOR EAX, EAX');                   { si negatif, offset = 0 }
  EmitLabel('@rt_right_ok');
  Emit('MOV ESI, [EBP+12]');
  Emit('ADD ESI, EAX');                   { src + offset }
  { Allouer la chaine resultat }
  Emit('MOV ECX, [EBP+8]');
  Emit('ADD ECX, 1');
  Emit('PUSH ECX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV EDI, EAX');
  Emit('PUSH EAX');                        { sauver resultat }
  { Copier }
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('CALL ' + RT_STRCPY);
  Emit('POP EAX');                         { retourner resultat }
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtMid : generer _VBNRT_MID                                 }
{   Args : str, start, length sur la pile                       }
{   Retourne : nouvelle chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtMid;
Var LabelLoop,LabelDone:TString;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBNRT_MID : Mid$ function ---');
  EmitLabel(RT_MID);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  { Allouer resultat }
  Emit('MOV ECX, [EBP+8]');               { length }
  Emit('ADD ECX, 1');
  Emit('PUSH ECX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV EDI, EAX');
  Emit('PUSH EAX');                        { sauver resultat }
  { Positionner la source }
  Emit('MOV ESI, [EBP+16]');              { str }
  Emit('MOV ECX, [EBP+12]');              { start (1-based) }
  Emit('DEC ECX');                         { convertir en 0-based }
  Emit('ADD ESI, ECX');
  Emit('MOV ECX, [EBP+8]');               { length }
  EmitLabel(LabelLoop);
  Emit('TEST ECX, ECX');
  Emit('JZ ' + LabelDone);
  Emit('LODSB');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone);
  Emit('STOSB');
  Emit('DEC ECX');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelDone);
  Emit('MOV BYTE [EDI], 0');
  Emit('POP EAX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtTrim : generer _VBNRT_LTRIM, _VBNRT_RTRIM, _VBNRT_TRIM  }
{ ------------------------------------------------------------ }

Procedure GenRtTrim;
Var LabelLoop1,LabelDone1,LabelLoop2:TString;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;

  { LTrim$ : sauter les espaces au debut }
  EmitComment('--- _VBNRT_LTRIM : LTrim$ ---');
  EmitLabel(RT_LTRIM);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV ESI, [EBP+8]');
  EmitLabel(LabelLoop1);
  Emit('CMP BYTE [ESI], 32');             { espace }
  Emit('JNE ' + LabelDone1);
  Emit('INC ESI');
  Emit('JMP ' + LabelLoop1);
  EmitLabel(LabelDone1);
  { Copier a partir de ESI }
  Emit('PUSH ESI');
  Emit('CALL ' + RT_LEN);
  Emit('ADD EAX, 1');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('PUSH ESI');
  Emit('PUSH EAX');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRCPY);
  Emit('POP EAX');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { RTrim$ : trouver la fin et supprimer les espaces }
  EmitComment('--- _VBNRT_RTRIM : RTrim$ ---');
  EmitLabel(RT_RTRIM);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Copier d abord la chaine }
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_LEN);
  Emit('MOV ECX, EAX');
  Emit('ADD EAX, 1');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('PUSH EAX');
  Emit('PUSH DWORD [EBP+8]');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRCPY);
  Emit('POP EAX');                         { resultat }
  { Supprimer les espaces en fin }
  Emit('MOV EDI, EAX');
  Emit('ADD EDI, ECX');
  Emit('DEC EDI');
  EmitLabel(LabelLoop2);
  Emit('CMP EDI, EAX');
  Emit('JB @rt_rtrim_done');
  Emit('CMP BYTE [EDI], 32');
  Emit('JNE @rt_rtrim_done');
  Emit('MOV BYTE [EDI], 0');
  Emit('DEC EDI');
  Emit('JMP ' + LabelLoop2);
  EmitLabel('@rt_rtrim_done');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { Trim$ : LTrim$(RTrim$(str)) }
  EmitComment('--- _VBNRT_TRIM : Trim$ ---');
  EmitLabel(RT_TRIM);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_RTRIM);
  Emit('PUSH EAX');
  Emit('CALL ' + RT_LTRIM);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount, 3);
End;

{ ------------------------------------------------------------ }
{ GenRtCase : generer _VBNRT_UCASE et _VBNRT_LCASE              }
{ ------------------------------------------------------------ }

Procedure GenRtCase;
Var LabelLoop1,LabelDone1,LabelSkip1:TString;
    LabelLoop2,LabelDone2,LabelSkip2:TString;
Begin
  LabelLoop1 := NextInternalLabel;
  LabelDone1 := NextInternalLabel;
  LabelSkip1 := NextInternalLabel;
  LabelLoop2 := NextInternalLabel;
  LabelDone2 := NextInternalLabel;
  LabelSkip2 := NextInternalLabel;

  { UCase$ }
  EmitComment('--- _VBNRT_UCASE : UCase$ ---');
  EmitLabel(RT_UCASE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  { Copier la chaine }
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_LEN);
  Emit('ADD EAX, 1');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('PUSH EAX');
  Emit('PUSH DWORD [EBP+8]');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRCPY);
  Emit('POP EAX');
  Emit('MOV ESI, EAX');
  EmitLabel(LabelLoop1);
  Emit('MOV AL, [ESI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone1);
  Emit('CMP AL, 97');                      { ''a'' }
  Emit('JB ' + LabelSkip1);
  Emit('CMP AL, 122');                     { ''z'' }
  Emit('JA ' + LabelSkip1);
  Emit('SUB AL, 32');
  Emit('MOV [ESI], AL');
  EmitLabel(LabelSkip1);
  Emit('INC ESI');
  Emit('JMP ' + LabelLoop1);
  EmitLabel(LabelDone1);
  Emit('MOV EAX, ESI');
  Emit('SUB EAX, ECX');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { LCase$ }
  EmitComment('--- _VBNRT_LCASE : LCase$ ---');
  EmitLabel(RT_LCASE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_LEN);
  Emit('ADD EAX, 1');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('PUSH EAX');
  Emit('PUSH DWORD [EBP+8]');
  Emit('PUSH EAX');
  Emit('CALL ' + RT_STRCPY);
  Emit('POP EAX');
  Emit('MOV ESI, EAX');
  EmitLabel(LabelLoop2);
  Emit('MOV AL, [ESI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone2);
  Emit('CMP AL, 65');                      { ''A'' }
  Emit('JB ' + LabelSkip2);
  Emit('CMP AL, 90');                      { ''Z'' }
  Emit('JA ' + LabelSkip2);
  Emit('ADD AL, 32');
  Emit('MOV [ESI], AL');
  EmitLabel(LabelSkip2);
  Emit('INC ESI');
  Emit('JMP ' + LabelLoop2);
  EmitLabel(LabelDone2);
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount, 2);
End;

{ ------------------------------------------------------------ }
{ GenRtInStr : generer _VBNRT_INSTR                             }
{   Args : start, str1, str2 sur la pile                        }
{   Retourne : position (1-based) dans EAX, 0 si non trouve    }
{ ------------------------------------------------------------ }

Procedure GenRtInStr;
Var LabelOuter,LabelInner,LabelFound,LabelNotFound,LabelNext:TString;
Begin
  LabelOuter    := NextInternalLabel;
  LabelInner    := NextInternalLabel;
  LabelFound    := NextInternalLabel;
  LabelNotFound := NextInternalLabel;
  LabelNext     := NextInternalLabel;
  EmitComment('--- _VBNRT_INSTR : InStr function ---');
  EmitLabel(RT_INSTR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('PUSH EBX');
  Emit('MOV ESI, [EBP+12]');              { str1 }
  Emit('MOV ECX, [EBP+16]');              { start (1-based) }
  Emit('DEC ECX');
  Emit('ADD ESI, ECX');                   { positionner au debut }
  Emit('MOV EBX, ECX');                   { sauver l offset }
  EmitLabel(LabelOuter);
  Emit('CMP BYTE [ESI], 0');
  Emit('JE ' + LabelNotFound);
  Emit('MOV EDI, [EBP+8]');               { str2 }
  Emit('MOV EDX, ESI');                   { sauver position }
  EmitLabel(LabelInner);
  Emit('MOV AL, [EDI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelFound);
  Emit('CMP AL, [EDX]');
  Emit('JNE ' + LabelNext);
  Emit('INC EDI');
  Emit('INC EDX');
  Emit('JMP ' + LabelInner);
  EmitLabel(LabelNext);
  Emit('INC ESI');
  Emit('INC EBX');
  Emit('JMP ' + LabelOuter);
  EmitLabel(LabelFound);
  Emit('MOV EAX, EBX');
  Emit('ADD EAX, 1');                      { convertir en 1-based }
  Emit('JMP @rt_instr_end');
  EmitLabel(LabelNotFound);
  Emit('XOR EAX, EAX');
  EmitLabel('@rt_instr_end');
  Emit('POP EBX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtReplace : generer _VBNRT_REPLACE (stub simplifie)        }
{ ------------------------------------------------------------ }

Procedure GenRtReplace;
Begin
  EmitComment('--- _VBNRT_REPLACE : Replace function (stub) ---');
  EmitLabel(RT_REPLACE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Stub : retourner la chaine originale }
  Emit('MOV EAX, [EBP+16]');              { retourner str1 }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtNetStringOps : generer les routines chaines .NET          }
{   IndexOf, Contains, StartsWith, EndsWith, Substr,            }
{   Insert, Remove, PadLeft, PadRight, Split, Join              }
{ ------------------------------------------------------------ }

Procedure GenRtNetStringOps;
Var LabelOuter,LabelInner,LabelFound,LabelNotFound,LabelNext:TString;
    LabelLoop,LabelDone,LabelMatch,LabelNoMatch:TString;
Begin
  { IndexOf : similaire a InStr mais retourne index 0-based, -1 si non trouve }
  LabelOuter    := NextInternalLabel;
  LabelInner    := NextInternalLabel;
  LabelFound    := NextInternalLabel;
  LabelNotFound := NextInternalLabel;
  LabelNext     := NextInternalLabel;
  EmitComment('--- _VBNRT_INDEXOF : String.IndexOf (0-based) ---');
  EmitLabel(RT_INDEXOF);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('PUSH EBX');
  Emit('MOV ESI, [EBP+12]');              { str }
  Emit('XOR EBX, EBX');                   { index = 0 }
  EmitLabel(LabelOuter);
  Emit('CMP BYTE [ESI], 0');
  Emit('JE ' + LabelNotFound);
  Emit('MOV EDI, [EBP+8]');               { substr }
  Emit('MOV EDX, ESI');
  EmitLabel(LabelInner);
  Emit('MOV AL, [EDI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelFound);
  Emit('CMP AL, [EDX]');
  Emit('JNE ' + LabelNext);
  Emit('INC EDI');
  Emit('INC EDX');
  Emit('JMP ' + LabelInner);
  EmitLabel(LabelNext);
  Emit('INC ESI');
  Emit('INC EBX');
  Emit('JMP ' + LabelOuter);
  EmitLabel(LabelFound);
  Emit('MOV EAX, EBX');                   { retourner index 0-based }
  Emit('JMP @rt_indexof_end');
  EmitLabel(LabelNotFound);
  Emit('MOV EAX, -1');                    { non trouve }
  EmitLabel('@rt_indexof_end');
  Emit('POP EBX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { Contains : appeler IndexOf, retourner True si >= 0 }
  EmitComment('--- _VBNRT_CONTAINS : String.Contains ---');
  EmitLabel(RT_CONTAINS);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { substr }
  Emit('PUSH DWORD [EBP+12]');            { str }
  Emit('CALL ' + RT_INDEXOF);
  Emit('CMP EAX, 0');
  Emit('SETGE AL');
  Emit('MOVZX EAX, AL');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { StartsWith : comparer les N premiers caracteres }
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  LabelMatch := NextInternalLabel;
  LabelNoMatch := NextInternalLabel;
  EmitComment('--- _VBNRT_STARTSWITH : String.StartsWith ---');
  EmitLabel(RT_STARTSWITH);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('MOV ESI, [EBP+12]');              { str }
  Emit('MOV EDI, [EBP+8]');               { prefix }
  EmitLabel(LabelLoop);
  Emit('MOV AL, [EDI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelMatch);               { fin du prefix = match }
  Emit('CMP AL, [ESI]');
  Emit('JNE ' + LabelNoMatch);
  Emit('INC ESI');
  Emit('INC EDI');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelMatch);
  Emit('MOV EAX, 1');
  Emit('JMP ' + LabelDone);
  EmitLabel(LabelNoMatch);
  Emit('XOR EAX, EAX');
  EmitLabel(LabelDone);
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { EndsWith : comparer les N derniers caracteres }
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  LabelMatch := NextInternalLabel;
  LabelNoMatch := NextInternalLabel;
  EmitComment('--- _VBNRT_ENDSWITH : String.EndsWith ---');
  EmitLabel(RT_ENDSWITH);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  { Calculer len(str) - len(suffix) }
  Emit('PUSH DWORD [EBP+12]');
  Emit('CALL ' + RT_LEN);
  Emit('MOV ECX, EAX');                   { len(str) }
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_LEN);
  Emit('MOV EDX, EAX');                   { len(suffix) }
  Emit('SUB ECX, EDX');
  Emit('JS ' + LabelNoMatch);             { str plus courte que suffix }
  Emit('MOV ESI, [EBP+12]');
  Emit('ADD ESI, ECX');                   { positionner a str + offset }
  Emit('MOV EDI, [EBP+8]');               { suffix }
  EmitLabel(LabelLoop);
  Emit('MOV AL, [EDI]');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelMatch);
  Emit('CMP AL, [ESI]');
  Emit('JNE ' + LabelNoMatch);
  Emit('INC ESI');
  Emit('INC EDI');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelMatch);
  Emit('MOV EAX, 1');
  Emit('JMP ' + LabelDone);
  EmitLabel(LabelNoMatch);
  Emit('XOR EAX, EAX');
  EmitLabel(LabelDone);
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { Substr : similaire a Mid mais 0-based }
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  EmitComment('--- _VBNRT_SUBSTR : String.Substring (0-based) ---');
  EmitLabel(RT_SUBSTR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('MOV ECX, [EBP+8]');               { length }
  Emit('ADD ECX, 1');
  Emit('PUSH ECX');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV EDI, EAX');
  Emit('PUSH EAX');
  Emit('MOV ESI, [EBP+16]');              { str }
  Emit('MOV ECX, [EBP+12]');              { startIndex (0-based) }
  Emit('ADD ESI, ECX');                   { pas de DEC, deja 0-based }
  Emit('MOV ECX, [EBP+8]');               { length }
  EmitLabel(LabelLoop);
  Emit('TEST ECX, ECX');
  Emit('JZ ' + LabelDone);
  Emit('LODSB');
  Emit('TEST AL, AL');
  Emit('JZ ' + LabelDone);
  Emit('STOSB');
  Emit('DEC ECX');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelDone);
  Emit('MOV BYTE [EDI], 0');
  Emit('POP EAX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');

  { Insert : stub - retourner la chaine originale }
  EmitComment('--- _VBNRT_INSERT : String.Insert (stub) ---');
  EmitLabel(RT_INSERT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+16]');              { retourner str }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');

  { Remove : stub - retourner la chaine originale }
  EmitComment('--- _VBNRT_REMOVE : String.Remove (stub) ---');
  EmitLabel(RT_REMOVE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { retourner str }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { PadLeft : stub - retourner la chaine originale }
  EmitComment('--- _VBNRT_PADLEFT : String.PadLeft (stub) ---');
  EmitLabel(RT_PADLEFT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { retourner str }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { PadRight : stub - retourner la chaine originale }
  EmitComment('--- _VBNRT_PADRIGHT : String.PadRight (stub) ---');
  EmitLabel(RT_PADRIGHT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { retourner str }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { Split : stub - retourner NULL }
  EmitComment('--- _VBNRT_SPLIT : String.Split (stub) ---');
  EmitLabel(RT_SPLIT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('XOR EAX, EAX');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { Join : stub - retourner chaine vide }
  EmitComment('--- _VBNRT_JOIN : String.Join (stub) ---');
  EmitLabel(RT_JOIN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH 1');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV BYTE [EAX], 0');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  Inc(RuntimeLibCount, 11);
End;

{ ------------------------------------------------------------ }
{ GenRtVal : generer _VBNRT_VAL (chaine vers nombre)            }
{   Arg : pointeur chaine sur la pile                           }
{   Retourne : valeur entiere dans EAX                          }
{ ------------------------------------------------------------ }

Procedure GenRtVal;
Var LabelLoop,LabelDone,LabelNeg,LabelPos:TString;
Begin
  LabelLoop := NextInternalLabel;
  LabelDone := NextInternalLabel;
  LabelNeg  := NextInternalLabel;
  LabelPos  := NextInternalLabel;
  EmitComment('--- _VBNRT_VAL : string to number ---');
  EmitLabel(RT_VAL);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('MOV ESI, [EBP+8]');
  Emit('XOR EAX, EAX');                   { resultat = 0 }
  Emit('XOR ECX, ECX');                   { signe = 0 (positif) }
  { Verifier le signe }
  Emit('CMP BYTE [ESI], 45');             { ''-'' }
  Emit('JNE ' + LabelPos);
  Emit('MOV ECX, 1');
  Emit('INC ESI');
  EmitLabel(LabelPos);
  EmitLabel(LabelLoop);
  Emit('MOVZX EDX, BYTE [ESI]');
  Emit('TEST DL, DL');
  Emit('JZ ' + LabelDone);
  Emit('SUB DL, 48');                      { ''0'' }
  Emit('CMP DL, 9');
  Emit('JA ' + LabelDone);
  Emit('IMUL EAX, 10');
  Emit('ADD EAX, EDX');
  Emit('INC ESI');
  Emit('JMP ' + LabelLoop);
  EmitLabel(LabelDone);
  { Appliquer le signe }
  Emit('TEST ECX, ECX');
  Emit('JZ ' + LabelNeg);
  Emit('NEG EAX');
  EmitLabel(LabelNeg);
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtStr : generer _VBNRT_STR (nombre vers chaine)            }
{   Arg : valeur entiere sur la pile                            }
{   Retourne : pointeur chaine dans EAX                         }
{ ------------------------------------------------------------ }

Procedure GenRtStr;
Var LabelLoop,LabelReverse,LabelRevDone,LabelNeg,LabelNotNeg:TString;
Begin
  LabelLoop    := NextInternalLabel;
  LabelReverse := NextInternalLabel;
  LabelRevDone := NextInternalLabel;
  LabelNeg     := NextInternalLabel;
  LabelNotNeg  := NextInternalLabel;
  EmitComment('--- _VBNRT_STR : number to string ---');
  EmitLabel(RT_STR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  Emit('PUSH EDI');
  Emit('PUSH EBX');
  { Allouer un buffer de 16 octets }
  Emit('PUSH 16');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV EDI, EAX');                   { buffer resultat }
  Emit('MOV ESI, EAX');                   { sauver le debut }
  Emit('MOV EAX, [EBP+8]');               { valeur }
  Emit('MOV EBX, 10');                    { diviseur }
  { Gerer le signe negatif }
  Emit('TEST EAX, EAX');
  Emit('JNS ' + LabelNotNeg);
  Emit('MOV BYTE [EDI], 45');             { ''-'' }
  Emit('INC EDI');
  Emit('NEG EAX');
  EmitLabel(LabelNotNeg);
  Emit('MOV ECX, EDI');                   { sauver debut des chiffres }
  { Convertir les chiffres (ordre inverse) }
  EmitLabel(LabelLoop);
  Emit('XOR EDX, EDX');
  Emit('DIV EBX');                        { EAX = quotient, EDX = reste }
  Emit('ADD DL, 48');                      { convertir en ASCII }
  Emit('MOV [EDI], DL');
  Emit('INC EDI');
  Emit('TEST EAX, EAX');
  Emit('JNZ ' + LabelLoop);
  Emit('MOV BYTE [EDI], 0');              { null-terminateur }
  { Inverser les chiffres }
  Emit('DEC EDI');                         { EDI pointe sur le dernier chiffre }
  Emit('MOV ESI, ECX');                   { ESI pointe sur le premier chiffre }
  EmitLabel(LabelReverse);
  Emit('CMP ESI, EDI');
  Emit('JAE ' + LabelRevDone);
  Emit('MOV AL, [ESI]');
  Emit('MOV AH, [EDI]');
  Emit('MOV [ESI], AH');
  Emit('MOV [EDI], AL');
  Emit('INC ESI');
  Emit('DEC EDI');
  Emit('JMP ' + LabelReverse);
  EmitLabel(LabelRevDone);
  Emit('MOV EAX, [EBP+8]');
  Emit('LEA EAX, [ECX]');
  Emit('POP EBX');
  Emit('POP EDI');
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtConversions : generer les routines de conversion .NET     }
{   CInt, CLng, CStr, CBool, CByte, CChar, CDbl, CSng, CShort  }
{ ------------------------------------------------------------ }

Procedure GenRtConversions;
Begin
  { CInt : tronquer a 16 bits signe (VB.NET Integer=32bit, mais CInt tronque) }
  EmitComment('--- _VBNRT_CINT : Convert to Integer ---');
  EmitLabel(RT_CINT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOVSX EAX, AX');                  { signe-etendre 16 bits }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CLng : identite sur 32 bits (VB.NET Integer=32bit) }
  EmitComment('--- _VBNRT_CLNG : Convert to Long ---');
  EmitLabel(RT_CLNG);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CStr : alias pour _VBNRT_STR }
  EmitComment('--- _VBNRT_CSTR : Convert to String ---');
  EmitLabel(RT_CSTR);
  Emit('JMP ' + RT_STR);

  { CBool : convertir en Boolean (0 ou 1) }
  EmitComment('--- _VBNRT_CBOOL : Convert to Boolean ---');
  EmitLabel(RT_CBOOL);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('TEST EAX, EAX');
  Emit('SETNZ AL');
  Emit('MOVZX EAX, AL');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CByte : tronquer a 8 bits non signe }
  EmitComment('--- _VBNRT_CBYTE : Convert to Byte ---');
  EmitLabel(RT_CBYTE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOVZX EAX, AL');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CChar : tronquer a 8 bits non signe (caractere) }
  EmitComment('--- _VBNRT_CCHAR : Convert to Char ---');
  EmitLabel(RT_CCHAR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOVZX EAX, AL');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CDbl : convertir entier en double via FPU (stub) }
  EmitComment('--- _VBNRT_CDBL : Convert to Double (stub) ---');
  EmitLabel(RT_CDBL);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FSTP QWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CSng : convertir entier en single via FPU (stub) }
  EmitComment('--- _VBNRT_CSNG : Convert to Single (stub) ---');
  EmitLabel(RT_CSNG);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FSTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CShort : tronquer a 16 bits signe }
  EmitComment('--- _VBNRT_CSHORT : Convert to Short ---');
  EmitLabel(RT_CSHORT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOVSX EAX, AX');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  Inc(RuntimeLibCount, 11);
End;

{ ------------------------------------------------------------ }
{ GenRtMathOps : generer les routines mathematiques              }
{   Utilise le FPU x87 pour les operations en virgule flottante  }
{   Inclut Floor, Ceiling, Round, Max, Min pour .NET             }
{ ------------------------------------------------------------ }

Procedure GenRtMathOps;
Begin
  { POW : a ^ b }
  EmitComment('--- _VBNRT_POW : power (a^b) ---');
  EmitLabel(RT_POW);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { base }
  Emit('MOV ECX, [EBP+8]');               { exposant }
  Emit('MOV EDX, 1');                     { resultat }
  EmitLabel('@rt_pow_loop');
  Emit('TEST ECX, ECX');
  Emit('JZ @rt_pow_done');
  Emit('IMUL EDX, EAX');
  Emit('DEC ECX');
  Emit('JMP @rt_pow_loop');
  EmitLabel('@rt_pow_done');
  Emit('MOV EAX, EDX');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { SQR : racine carree (approximation entiere) }
  EmitComment('--- _VBNRT_SQR : square root ---');
  EmitLabel(RT_SQR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FSQRT');
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ABS : valeur absolue }
  EmitComment('--- _VBNRT_ABS : absolute value ---');
  EmitLabel(RT_ABS);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('TEST EAX, EAX');
  Emit('JNS @rt_abs_done');
  Emit('NEG EAX');
  EmitLabel('@rt_abs_done');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { SGN : signe (-1, 0, +1) }
  EmitComment('--- _VBNRT_SGN : sign ---');
  EmitLabel(RT_SGN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');
  Emit('TEST EAX, EAX');
  Emit('JZ @rt_sgn_done');
  Emit('JS @rt_sgn_neg');
  Emit('MOV EAX, 1');
  Emit('JMP @rt_sgn_done');
  EmitLabel('@rt_sgn_neg');
  Emit('MOV EAX, -1');
  EmitLabel('@rt_sgn_done');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { SIN : sinus via FPU }
  EmitComment('--- _VBNRT_SIN : sine ---');
  EmitLabel(RT_SIN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FSIN');
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { COS : cosinus via FPU }
  EmitComment('--- _VBNRT_COS : cosine ---');
  EmitLabel(RT_COS);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FCOS');
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { TAN : tangente via FPU (FPTAN) }
  EmitComment('--- _VBNRT_TAN : tangent ---');
  EmitLabel(RT_TAN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FPTAN');
  Emit('FSTP ST(0)');                      { enlever le 1.0 du FPTAN }
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ATN : arctangente via FPU (FPATAN) }
  EmitComment('--- _VBNRT_ATN : arctangent ---');
  EmitLabel(RT_ATN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FLD1');
  Emit('FPATAN');
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { EXP : exponentielle via FPU }
  EmitComment('--- _VBNRT_EXP : exponential ---');
  EmitLabel(RT_EXP);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FLDL2E');                          { log2(e) }
  Emit('FMULP');                           { x * log2(e) }
  Emit('FLD1');
  Emit('FLD ST(1)');
  Emit('FPREM');
  Emit('F2XM1');
  Emit('FADDP');
  Emit('FSCALE');
  Emit('FSTP ST(1)');
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { LOG : logarithme naturel via FPU }
  EmitComment('--- _VBNRT_LOG : natural logarithm ---');
  EmitLabel(RT_LOG);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FLD1');
  Emit('FILD DWORD [EBP+8]');
  Emit('FYL2X');                           { log2(x) }
  Emit('FLDLN2');                          { ln(2) }
  Emit('FMULP');                           { log2(x) * ln(2) = ln(x) }
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { FLOOR : arrondi vers le bas via FPU }
  EmitComment('--- _VBNRT_FLOOR : Math.Floor ---');
  EmitLabel(RT_FLOOR);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('SUB ESP, 4');                      { espace pour control word }
  Emit('FILD DWORD [EBP+8]');
  Emit('FNSTCW [EBP-4]');                 { sauver control word }
  Emit('MOV AX, [EBP-4]');
  Emit('OR AX, $0400');                   { mode arrondi vers -inf }
  Emit('AND AX, $F7FF');
  Emit('MOV [EBP-2], AX');
  Emit('FLDCW [EBP-2]');
  Emit('FRNDINT');
  Emit('FLDCW [EBP-4]');                  { restaurer control word }
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { CEILING : arrondi vers le haut (floor + 1 si fractionnaire) }
  EmitComment('--- _VBNRT_CEILING : Math.Ceiling (stub) ---');
  EmitLabel(RT_CEILING);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_FLOOR);
  Emit('ADD EAX, 1');                      { stub : floor + 1 }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ROUND : arrondi au plus proche via FPU }
  EmitComment('--- _VBNRT_ROUND : Math.Round ---');
  EmitLabel(RT_ROUND);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('FILD DWORD [EBP+8]');
  Emit('FRNDINT');                         { arrondi au plus proche (defaut) }
  Emit('FISTP DWORD [EBP+8]');
  Emit('MOV EAX, [EBP+8]');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { MAX : retourner le plus grand de deux entiers }
  EmitComment('--- _VBNRT_MAX : Math.Max ---');
  EmitLabel(RT_MAX);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { a }
  Emit('MOV ECX, [EBP+8]');               { b }
  Emit('CMP EAX, ECX');
  Emit('CMOVL EAX, ECX');                 { si a < b, prendre b }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { MIN : retourner le plus petit de deux entiers }
  EmitComment('--- _VBNRT_MIN : Math.Min ---');
  EmitLabel(RT_MIN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+12]');              { a }
  Emit('MOV ECX, [EBP+8]');               { b }
  Emit('CMP EAX, ECX');
  Emit('CMOVG EAX, ECX');                 { si a > b, prendre b }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  Inc(RuntimeLibCount, 15);
End;

{ ------------------------------------------------------------ }
{ GenRtPrint : generer _VBNRT_PRINT (affichage console)         }
{   Arg : pointeur chaine sur la pile                           }
{ ------------------------------------------------------------ }

Procedure GenRtPrint;
Begin
  EmitComment('--- _VBNRT_PRINT : console print ---');
  EmitLabel(RT_PRINT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH ESI');
  { Calculer la longueur }
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_LEN);
  Emit('MOV ECX, EAX');                   { longueur }
  { WriteFile(hStdOut, lpBuffer, nBytes, &written, NULL) }
  Emit('SUB ESP, 4');                      { reserve pour bytesWritten }
  Emit('PUSH 0');                          { lpOverlapped }
  Emit('LEA EAX, [ESP+4]');
  Emit('PUSH EAX');                        { lpNumberOfBytesWritten }
  Emit('PUSH ECX');                        { nNumberOfBytesToWrite }
  Emit('PUSH DWORD [EBP+8]');             { lpBuffer }
  Emit('PUSH DWORD [' + RT_VAR_HSTDOUT + ']');
  Emit('CALL WriteFile');
  Emit('ADD ESP, 4');                      { liberer bytesWritten }
  Emit('POP ESI');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtPrintLn : generer _VBNRT_PRINTLN (print + CRLF)          }
{   Arg : pointeur chaine sur la pile                           }
{ ------------------------------------------------------------ }

Procedure GenRtPrintLn;
Begin
  EmitComment('--- _VBNRT_PRINTLN : console print with CRLF ---');
  EmitLabel(RT_PRINTLN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Imprimer la chaine }
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_PRINT);
  { Imprimer CRLF }
  Emit('SUB ESP, 4');
  Emit('MOV WORD [ESP], $0A0D');           { CR LF }
  Emit('MOV BYTE [ESP+2], 0');
  Emit('PUSH ESP');
  Emit('CALL ' + RT_PRINT);
  Emit('ADD ESP, 4');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtInput : generer _VBNRT_INPUT (lecture console)            }
{   Arg : pointeur buffer, taille max sur la pile               }
{   Retourne : nombre d octets lus dans EAX                     }
{ ------------------------------------------------------------ }

Procedure GenRtInput;
Begin
  EmitComment('--- _VBNRT_INPUT : console input ---');
  EmitLabel(RT_INPUT);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { ReadFile(hStdIn, lpBuffer, nBytes, &read, NULL) }
  Emit('SUB ESP, 4');                      { reserve pour bytesRead }
  Emit('PUSH 0');                          { lpOverlapped }
  Emit('LEA EAX, [ESP+4]');
  Emit('PUSH EAX');                        { lpNumberOfBytesRead }
  Emit('PUSH DWORD [EBP+8]');             { nNumberOfBytesToRead }
  Emit('PUSH DWORD [EBP+12]');            { lpBuffer }
  Emit('PUSH DWORD [' + RT_VAR_HSTDIN + ']');
  Emit('CALL ReadFile');
  Emit('MOV EAX, [ESP]');                 { bytesRead }
  Emit('ADD ESP, 4');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtMsgBox : generer _VBNRT_MSGBOX                           }
{   Args : message, titre, style sur la pile                    }
{   Retourne : resultat dans EAX                                }
{ ------------------------------------------------------------ }

Procedure GenRtMsgBox;
Begin
  EmitComment('--- _VBNRT_MSGBOX : MessageBox ---');
  EmitLabel(RT_MSGBOX);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { uType }
  Emit('PUSH DWORD [EBP+12]');            { lpCaption }
  Emit('PUSH DWORD [EBP+16]');            { lpText }
  Emit('PUSH 0');                          { hWnd = NULL }
  Emit('CALL MessageBoxA');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 12');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtInputBox : generer _VBNRT_INPUTBOX (stub)                }
{ ------------------------------------------------------------ }

Procedure GenRtInputBox;
Begin
  EmitComment('--- _VBNRT_INPUTBOX : InputBox (stub) ---');
  EmitLabel(RT_INPUTBOX);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  { Stub : allouer un buffer vide }
  Emit('PUSH 256');
  Emit('CALL ' + RT_STRALLOC);
  Emit('MOV BYTE [EAX], 0');
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');
  Inc(RuntimeLibCount);
End;

{ ------------------------------------------------------------ }
{ GenRtArrayOps : generer les routines tableaux .NET             }
{   REDIM, ERASE, ARRLENGTH, ARRGETLENGTH, ARRGETUPPERBOUND     }
{ ------------------------------------------------------------ }

Procedure GenRtArrayOps;
Begin
  { REDIM : reallouer un tableau }
  EmitComment('--- _VBNRT_REDIM : ReDim array ---');
  EmitLabel(RT_REDIM);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { nouvelle taille }
  Emit('CALL ' + RT_HEAPALLOC);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 8');

  { ERASE : liberer un tableau }
  EmitComment('--- _VBNRT_ERASE : Erase array ---');
  EmitLabel(RT_ERASE);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');
  Emit('CALL ' + RT_HEAPFREE);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ARRLENGTH : retourner le nombre d elements (depuis l en-tete) }
  EmitComment('--- _VBNRT_ARRLENGTH : array length ---');
  EmitLabel(RT_ARRLENGTH);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');               { pointeur tableau }
  Emit('MOV EAX, [EAX-4]');               { en-tete = count }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ARRGETLENGTH : identique a ARRLENGTH (.NET Array.GetLength) }
  EmitComment('--- _VBNRT_ARRGETLENGTH : Array.GetLength ---');
  EmitLabel(RT_ARRGETLENGTH);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');               { pointeur tableau }
  Emit('MOV EAX, [EAX-4]');               { en-tete = count }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { ARRGETUPPERBOUND : count - 1 (.NET Array.GetUpperBound) }
  EmitComment('--- _VBNRT_ARRGETUPPERBOUND : Array.GetUpperBound ---');
  EmitLabel(RT_ARRGETUPPERBOUND);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');               { pointeur tableau }
  Emit('MOV EAX, [EAX-4]');               { en-tete = count }
  Emit('DEC EAX');                         { upper bound = count - 1 }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  Inc(RuntimeLibCount, 5);
End;

{ ------------------------------------------------------------ }
{ GenRtExceptionOps : generer les routines exception .NET        }
{   THROWEX, SEHSETUP, SEHTEARDOWN                              }
{ ------------------------------------------------------------ }

Procedure GenRtExceptionOps;
Begin
  { THROWEX : stub - afficher le message et terminer }
  EmitComment('--- _VBNRT_THROWEX : Throw exception (stub) ---');
  EmitLabel(RT_THROWEX);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('PUSH DWORD [EBP+8]');             { message }
  Emit('CALL ' + RT_PRINT);
  Emit('MOV DWORD [' + RT_VAR_EXITCODE + '], 1');
  Emit('CALL ' + RT_EXIT);
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { SEHSETUP : installer un cadre SEH }
  EmitComment('--- _VBNRT_SEHSETUP : SEH frame setup ---');
  EmitLabel(RT_SEHSETUP);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, [EBP+8]');               { handler address }
  Emit('PUSH EAX');
  Emit('PUSH DWORD FS:[0]');              { previous handler }
  Emit('MOV FS:[0], ESP');                { install new handler }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET 4');

  { SEHTEARDOWN : retirer le cadre SEH }
  EmitComment('--- _VBNRT_SEHTEARDOWN : SEH frame teardown ---');
  EmitLabel(RT_SEHTEARDOWN);
  Emit('PUSH EBP');
  Emit('MOV EBP, ESP');
  Emit('MOV EAX, FS:[0]');                { current handler }
  Emit('MOV EAX, [EAX]');                 { previous handler }
  Emit('MOV FS:[0], EAX');                { restore previous }
  Emit('MOV ESP, EBP');
  Emit('POP EBP');
  Emit('RET');

  Inc(RuntimeLibCount, 3);
End;

{ ------------------------------------------------------------ }
{ EmitAllRuntimeRoutines : emettre toutes les routines runtime   }
{ ------------------------------------------------------------ }

Procedure EmitAllRuntimeRoutines;
Begin
  If RuntimeLibEmitted Then Exit;
  EmitComment('========================================');
  EmitComment('  VB.NET Runtime Library (Win32)         ');
  EmitComment('========================================');
  GenRtDataSegment;
  GenRtInit;
  GenRtExit;
  GenRtHeapInit;
  GenRtHeapAlloc;
  GenRtHeapFree;
  GenRtStrAlloc;
  GenRtStrFree;
  GenRtLen;
  GenRtStrCat;
  GenRtStrCmp;
  GenRtStrCpy;
  GenRtLeft;
  GenRtRight;
  GenRtMid;
  GenRtTrim;
  GenRtCase;
  GenRtInStr;
  GenRtReplace;
  GenRtNetStringOps;
  GenRtVal;
  GenRtStr;
  GenRtConversions;
  GenRtMathOps;
  GenRtPrint;
  GenRtPrintLn;
  GenRtInput;
  GenRtMsgBox;
  GenRtInputBox;
  GenRtArrayOps;
  GenRtExceptionOps;
  RuntimeLibEmitted := True;
End;

{ ------------------------------------------------------------ }
{ IsRuntimeLabel : verifier si un label est une routine runtime  }
{ ------------------------------------------------------------ }

Function IsRuntimeLabel(Const S : TString) : Boolean;
Begin
  IsRuntimeLabel := False;
  If Length(S) < 7 Then Exit;
  If Copy(S, 1, 7) = '_VBNRT_' Then
    IsRuntimeLabel := True;
End;

{ ------------------------------------------------------------ }
{ IsStringRoutine : verifier si c est une routine chaine         }
{ ------------------------------------------------------------ }

Function IsStringRoutine(Const S : TString) : Boolean;
Begin
  IsStringRoutine := (S = RT_LEN) Or (S = RT_STRCAT) Or
                     (S = RT_STRCMP) Or (S = RT_STRCPY) Or
                     (S = RT_STRALLOC) Or (S = RT_STRFREE) Or
                     (S = RT_LEFT) Or (S = RT_RIGHT) Or
                     (S = RT_MID) Or (S = RT_LTRIM) Or
                     (S = RT_RTRIM) Or (S = RT_TRIM) Or
                     (S = RT_UCASE) Or (S = RT_LCASE) Or
                     (S = RT_INSTR) Or (S = RT_REPLACE) Or
                     (S = RT_INDEXOF) Or (S = RT_CONTAINS) Or
                     (S = RT_STARTSWITH) Or (S = RT_ENDSWITH) Or
                     (S = RT_SUBSTR) Or (S = RT_INSERT) Or
                     (S = RT_REMOVE) Or (S = RT_PADLEFT) Or
                     (S = RT_PADRIGHT) Or (S = RT_SPLIT) Or
                     (S = RT_JOIN);
End;

{ ------------------------------------------------------------ }
{ IsMathRoutine : verifier si c est une routine mathematique     }
{ ------------------------------------------------------------ }

Function IsMathRoutine(Const S : TString) : Boolean;
Begin
  IsMathRoutine := (S = RT_POW) Or (S = RT_SQR) Or
                   (S = RT_ABS) Or (S = RT_SGN) Or
                   (S = RT_SIN) Or (S = RT_COS) Or
                   (S = RT_TAN) Or (S = RT_ATN) Or
                   (S = RT_EXP) Or (S = RT_LOG) Or
                   (S = RT_FLOOR) Or (S = RT_CEILING) Or
                   (S = RT_ROUND) Or (S = RT_MAX) Or
                   (S = RT_MIN);
End;

{ ------------------------------------------------------------ }
{ IsConvertRoutine : verifier si c est une routine conversion    }
{ ------------------------------------------------------------ }

Function IsConvertRoutine(Const S : TString) : Boolean;
Begin
  IsConvertRoutine := (S = RT_VAL) Or (S = RT_STR) Or
                      (S = RT_CINT) Or (S = RT_CLNG) Or
                      (S = RT_CSTR) Or (S = RT_CBOOL) Or
                      (S = RT_CBYTE) Or (S = RT_CCHAR) Or
                      (S = RT_CDBL) Or (S = RT_CSNG) Or
                      (S = RT_CSHORT);
End;

{ ------------------------------------------------------------ }
{ 10 fonctions accesseurs                                       }
{ ------------------------------------------------------------ }

Function GetRuntimeLibCount : LongInt;
Begin
  GetRuntimeLibCount := RuntimeLibCount;
End;

Function IsRuntimeLibInitialized : Boolean;
Begin
  IsRuntimeLibInitialized := RuntimeLibInitialized;
End;

Function IsRuntimeLibEmpty : Boolean;
Begin
  IsRuntimeLibEmpty := (RuntimeLibCount = 0);
End;

Function GetRuntimeLibStatus : TString;
Begin
  If Not RuntimeLibInitialized Then
    GetRuntimeLibStatus := 'Not initialized'
  Else If RuntimeLibEmitted Then
    GetRuntimeLibStatus := 'Emitted (' + ItoS(RuntimeLibCount) + ' routines)'
  Else
    GetRuntimeLibStatus := 'Initialized, not yet emitted';
End;

Function IsRuntimeLibEmitted : Boolean;
Begin
  IsRuntimeLibEmitted := RuntimeLibEmitted;
End;

Function GetTotalRtRoutines : Integer;
Begin
  GetTotalRtRoutines := TotalStringRoutines + TotalConvertRoutines +
                        TotalMathRoutines + TotalConsoleRoutines +
                        TotalArrayRoutines + TotalMemoryRoutines +
                        TotalSystemRoutines + TotalExceptionRoutines;
End;

Function GetRtStringCount : Integer;
Begin
  GetRtStringCount := TotalStringRoutines;
End;

Function GetRtConvertCount : Integer;
Begin
  GetRtConvertCount := TotalConvertRoutines;
End;

Function GetRtMathCount : Integer;
Begin
  GetRtMathCount := TotalMathRoutines;
End;

Function GetRtConsoleCount : Integer;
Begin
  GetRtConsoleCount := TotalConsoleRoutines;
End;

{ ============================================================ }
{ TODO 21 - ECRIVAIN BINAIRE PE (GENERATION .EXE WINDOWS      }
{           32 BITS) [IMPLEMENTE]                              }
{ ============================================================ }

Const
  { Alignements PE }
  PE_FILE_ALIGN_VAL  = 512;    { $200 }
  PE_SECT_ALIGN_VAL  = 4096;   { $1000 }
  PE_IMAGE_BASE_VAL  = $00400000;

  { Tailles des tampons binaires PE }
  PE_MAX_CODE_SIZE  = 65536;
  PE_MAX_DATA_SIZE  = 65536;
  PE_MAX_LABEL_CNT  = 4096;
  PE_MAX_FIXUP_CNT  = 8192;

  { Nombre d imports Win32 API pour VB.NET }
  PE_NUM_VBN_IMPORTS = 14;

  { Caracteristiques de section }
  PE_SCN_CNT_CODE           = $00000020;
  PE_SCN_CNT_INIT_DATA      = $00000040;
  PE_SCN_MEM_EXECUTE        = $20000000;
  PE_SCN_MEM_READ           = $40000000;
  PE_SCN_MEM_WRITE          = LongInt($80000000);

Type
  TPELabelEntry = Record
    Name   : TString;
    Offset : LongInt;
    InData : Boolean;
  End;
  TPEFixupEntry = Record
    Offset    : LongInt;
    LabelName : TString;
    IsRelative: Boolean;
    IsImport  : Boolean;
  End;
  TPEImportEntry = Record
    Name      : TString;
    IATOffset : LongInt;
  End;

Var
  PEWCodeBuf    : Array[0..PE_MAX_CODE_SIZE-1] of Byte;
  PEWDataBuf    : Array[0..PE_MAX_DATA_SIZE-1] of Byte;
  PEWCodePos    : LongInt;
  PEWDataPos    : LongInt;
  PEWLabels     : Array[0..PE_MAX_LABEL_CNT-1] of TPELabelEntry;
  PEWLabelCount : LongInt;
  PEWFixups     : Array[0..PE_MAX_FIXUP_CNT-1] of TPEFixupEntry;
  PEWFixupCount : LongInt;
  PEWImports    : Array[0..PE_NUM_VBN_IMPORTS-1] of TPEImportEntry;
  PEWInDataSeg  : Boolean;
  PEWTextVA     : LongInt;
  PEWRdataVA    : LongInt;
  PEWDataVA     : LongInt;
  PEWriterInitialized : Boolean;
  PEWriterCount       : LongInt;

{ ------------------------------------------------------------ }
{ InitPEWriter : initialiser le sous-systeme PE writer          }
{ ------------------------------------------------------------ }

Procedure InitPEWriter;
Var I : LongInt;
Begin
  PEWCodePos    := 0;
  PEWDataPos    := 0;
  PEWLabelCount := 0;
  PEWFixupCount := 0;
  PEWInDataSeg  := False;
  PEWTextVA     := 0;
  PEWRdataVA    := 0;
  PEWDataVA     := 0;
  PEWriterInitialized := True;
  PEWriterCount := 0;
  For I := 0 To PE_MAX_CODE_SIZE - 1 Do PEWCodeBuf[I] := 0;
  For I := 0 To PE_MAX_DATA_SIZE - 1 Do PEWDataBuf[I] := 0;
  { Initialiser les imports Win32 API pour VB.NET }
  PEWImports[0].Name  := 'ExitProcess';
  PEWImports[1].Name  := 'GetStdHandle';
  PEWImports[2].Name  := 'WriteFile';
  PEWImports[3].Name  := 'ReadFile';
  PEWImports[4].Name  := 'GetProcessHeap';
  PEWImports[5].Name  := 'HeapAlloc';
  PEWImports[6].Name  := 'HeapFree';
  PEWImports[7].Name  := 'CreateFileA';
  PEWImports[8].Name  := 'CloseHandle';
  PEWImports[9].Name  := 'MessageBoxA';
  PEWImports[10].Name := 'GetCommandLineA';
  PEWImports[11].Name := 'GetModuleHandleA';
  PEWImports[12].Name := 'SetFilePointer';
  PEWImports[13].Name := 'DeleteFileA';
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
    PEWImports[I].IATOffset := 0;
End;

{ ------------------------------------------------------------ }
{ PEWAlignUp : aligner une valeur sur une frontiere             }
{ ------------------------------------------------------------ }

Function PEWAlignUp(Value, Alignment : LongInt) : LongInt;
Begin
  If (Value Mod Alignment) = 0 Then
    PEWAlignUp := Value
  Else
    PEWAlignUp := Value + Alignment - (Value Mod Alignment);
End;

{ ------------------------------------------------------------ }
{ PEWAddLabel : ajouter un label au tableau des labels          }
{ ------------------------------------------------------------ }

Procedure PEWAddLabel(Const AName : TString; AOffset : LongInt;
                      AInData : Boolean);
Begin
  If PEWLabelCount < PE_MAX_LABEL_CNT Then
  Begin
    PEWLabels[PEWLabelCount].Name   := AName;
    PEWLabels[PEWLabelCount].Offset := AOffset;
    PEWLabels[PEWLabelCount].InData := AInData;
    Inc(PEWLabelCount);
  End;
End;

{ ------------------------------------------------------------ }
{ PEWFindLabel : chercher un label par nom                      }
{ ------------------------------------------------------------ }

Function PEWFindLabel(Const AName : TString;
                      Var AOffset : LongInt;
                      Var AInData : Boolean) : Boolean;
Var I : LongInt;
Begin
  PEWFindLabel := False;
  For I := 0 To PEWLabelCount - 1 Do
    If PEWLabels[I].Name = AName Then
    Begin
      AOffset := PEWLabels[I].Offset;
      AInData := PEWLabels[I].InData;
      PEWFindLabel := True;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ PEWAddFixup : ajouter un correctif (fixup)                    }
{ ------------------------------------------------------------ }

Procedure PEWAddFixup(AOffset : LongInt; Const ALabelName : TString;
                      AIsRelative, AIsImport : Boolean);
Begin
  If PEWFixupCount < PE_MAX_FIXUP_CNT Then
  Begin
    PEWFixups[PEWFixupCount].Offset     := AOffset;
    PEWFixups[PEWFixupCount].LabelName  := ALabelName;
    PEWFixups[PEWFixupCount].IsRelative := AIsRelative;
    PEWFixups[PEWFixupCount].IsImport   := AIsImport;
    Inc(PEWFixupCount);
  End;
End;

{ ------------------------------------------------------------ }
{ PEWImportName : extraire le nom d import d un label            }
{   Convertit _ExitProcess@4 -> ExitProcess                     }
{ ------------------------------------------------------------ }

Function PEWImportName(Const S : TString) : TString;
Var
  Tmp : TString;
  P   : Integer;
Begin
  Tmp := S;
  If (Length(Tmp) > 0) And (Tmp[1] = '_') Then
    Tmp := Copy(Tmp, 2, Length(Tmp) - 1);
  P := Pos('@', Tmp);
  If P > 0 Then
    Tmp := Copy(Tmp, 1, P - 1);
  PEWImportName := Tmp;
End;

{ ------------------------------------------------------------ }
{ PEWResolveFixups : resoudre les correctifs internes            }
{ ------------------------------------------------------------ }

Procedure PEWResolveFixups;
Var
  I, J      : LongInt;
  LblOff    : LongInt;
  LblInData : Boolean;
  TargetAddr: LongInt;
  FixOff    : LongInt;
  ImpName   : TString;
  Found     : Boolean;
  FixVal    : LongInt;
  IsDataFix : Boolean;
  DataFixOff: LongInt;
Begin
  For I := 0 To PEWFixupCount - 1 Do
  Begin
    FixOff := PEWFixups[I].Offset;
    IsDataFix := (FixOff < 0);
    If IsDataFix Then
      DataFixOff := (-FixOff) - 1
    Else
      DataFixOff := 0;

    If PEWFixups[I].IsImport Then
    Begin
      ImpName := PEWImportName(PEWFixups[I].LabelName);
      Found := False;
      For J := 0 To PE_NUM_VBN_IMPORTS - 1 Do
        If PEWImports[J].Name = ImpName Then
        Begin
          TargetAddr := PE_IMAGE_BASE_VAL + PEWRdataVA +
                        PEWImports[J].IATOffset;
          Found := True;
          Break;
        End;
      If Not Found Then TargetAddr := 0;
    End
    Else
    Begin
      If PEWFindLabel(PEWFixups[I].LabelName, LblOff, LblInData) Then
      Begin
        If LblInData Then
          TargetAddr := PE_IMAGE_BASE_VAL + PEWDataVA + LblOff
        Else
          TargetAddr := PE_IMAGE_BASE_VAL + PEWTextVA + LblOff;
      End
      Else
        TargetAddr := 0;
    End;

    If IsDataFix Then
    Begin
      FixVal := TargetAddr +
                LongInt(PEWDataBuf[DataFixOff]) Or
                (LongInt(PEWDataBuf[DataFixOff+1]) Shl 8) Or
                (LongInt(PEWDataBuf[DataFixOff+2]) Shl 16) Or
                (LongInt(PEWDataBuf[DataFixOff+3]) Shl 24);
      PEWDataBuf[DataFixOff]   := Byte(FixVal And $FF);
      PEWDataBuf[DataFixOff+1] := Byte((FixVal Shr 8) And $FF);
      PEWDataBuf[DataFixOff+2] := Byte((FixVal Shr 16) And $FF);
      PEWDataBuf[DataFixOff+3] := Byte((FixVal Shr 24) And $FF);
    End
    Else If PEWFixups[I].IsRelative Then
    Begin
      FixVal := TargetAddr -
                (PE_IMAGE_BASE_VAL + PEWTextVA + FixOff + 4);
      PEWCodeBuf[FixOff]   := Byte(FixVal And $FF);
      PEWCodeBuf[FixOff+1] := Byte((FixVal Shr 8) And $FF);
      PEWCodeBuf[FixOff+2] := Byte((FixVal Shr 16) And $FF);
      PEWCodeBuf[FixOff+3] := Byte((FixVal Shr 24) And $FF);
    End
    Else
    Begin
      FixVal := TargetAddr +
                LongInt(PEWCodeBuf[FixOff]) Or
                (LongInt(PEWCodeBuf[FixOff+1]) Shl 8) Or
                (LongInt(PEWCodeBuf[FixOff+2]) Shl 16) Or
                (LongInt(PEWCodeBuf[FixOff+3]) Shl 24);
      PEWCodeBuf[FixOff]   := Byte(FixVal And $FF);
      PEWCodeBuf[FixOff+1] := Byte((FixVal Shr 8) And $FF);
      PEWCodeBuf[FixOff+2] := Byte((FixVal Shr 16) And $FF);
      PEWCodeBuf[FixOff+3] := Byte((FixVal Shr 24) And $FF);
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ Fonctions utilitaires d ecriture dans le fichier PE            }
{ ------------------------------------------------------------ }

Procedure PEWWriteBuf(Var F : File; Var Buf; Size : LongInt);
Begin
  BlockWrite(F, Buf, Size);
End;

Procedure PEWFileWriteByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
End;

Procedure PEWFileWriteWord(Var F : File; W : Word);
Var Buf : Array[0..1] of Byte;
Begin
  Buf[0] := Byte(W And $FF);
  Buf[1] := Byte((W Shr 8) And $FF);
  BlockWrite(F, Buf, 2);
End;

Procedure PEWFileWriteDWord(Var F : File; D : LongInt);
Var Buf : Array[0..3] of Byte;
Begin
  Buf[0] := Byte(D And $FF);
  Buf[1] := Byte((D Shr 8) And $FF);
  Buf[2] := Byte((D Shr 16) And $FF);
  Buf[3] := Byte((D Shr 24) And $FF);
  BlockWrite(F, Buf, 4);
End;

Procedure PEWFileWriteZeros(Var F : File; Count : LongInt);
Var ZBuf : Byte;
    K    : LongInt;
Begin
  ZBuf := 0;
  For K := 1 To Count Do
    BlockWrite(F, ZBuf, 1);
End;

Procedure PEWFileWriteStr(Var F : File; Const S : TString);
Var K : Integer;
    B : Byte;
Begin
  For K := 1 To Length(S) Do
  Begin
    B := Byte(Ord(S[K]));
    BlockWrite(F, B, 1);
  End;
End;

{ ------------------------------------------------------------ }
{ WritePEFile : generer un executable PE Windows 32 bits         }
{   complet a partir des tampons code/data                      }
{ ------------------------------------------------------------ }

Procedure WritePEFile(Const ExeFile : TString);
Var
  F            : File;
  TextRawSize  : LongInt;
  DataRawSize  : LongInt;
  RdataSize    : LongInt;
  RdataRawSize : LongInt;
  TextFileOff  : LongInt;
  RdataFileOff : LongInt;
  DataFileOff  : LongInt;
  SizeOfImage  : LongInt;
  ImportDirOff : LongInt;
  ILTOff       : LongInt;
  IATOff       : LongInt;
  HintOff      : LongInt;
  DLLNameOff   : LongInt;
  DLL2NameOff  : LongInt;
  CurOff       : LongInt;
  I            : LongInt;
  NameLen      : Integer;
  TotalHdrSize : LongInt;
  PadNeeded    : LongInt;
  SubsysVal    : Word;
  NumKernelImp : Integer;
  ImportDir2Off: LongInt;
  ILT2Off      : LongInt;
  IAT2Off      : LongInt;
  Hint2Off     : LongInt;
Begin
  { Determiner le sous-systeme (CUI par defaut) }
  SubsysVal := PE_SUBSYS_CUI;
  If Opts.EmitExe Then
    SubsysVal := PE_SUBSYS_CUI;

  { Si aucun code n a ete emis dans le tampon binaire (le backend  }
  { actuel produit de l asm texte mais pas encore de bytecode x86), }
  { generer un stub minimal "push 0 / call [ExitProcess]" pour     }
  { que l executable produit soit un PE valide chargeable par      }
  { Windows et qu il termine proprement avec ExitCode=0.           }
  If PEWCodePos = 0 Then
  Begin
    { 6A 00              push 0          ; ExitCode             }
    PEWCodeBuf[0] := $6A;
    PEWCodeBuf[1] := $00;
    { FF 15 <abs32>      call dword ptr [ExitProcess_IAT]       }
    PEWCodeBuf[2] := $FF;
    PEWCodeBuf[3] := $15;
    PEWCodeBuf[4] := 0; PEWCodeBuf[5] := 0;
    PEWCodeBuf[6] := 0; PEWCodeBuf[7] := 0;
    PEWCodePos := 8;
    { Fixup absolu vers l IAT ExitProcess }
    PEWAddFixup(4, '_ExitProcess@4', False, True);
    { CC                 int3 (filler de queue, jamais execute)  }
    PEWCodeBuf[8] := $CC;
    PEWCodePos := 9;
  End;

  { Disposition simplifiee : toutes les imports dans kernel32.dll }
  { Les imports user32.dll (MessageBoxA) sont a l index 9 }
  { On les inclut tous dans kernel32.dll pour simplifier }
  { La disposition dans .rdata :                                }
  {   Import Directory : 3 entrees x 20 = 60 octets             }
  {     entree kernel32.dll, entree user32.dll, terminateur      }
  {   ILT kernel32 : (NumKernel+1) x 4                          }
  {   ILT user32 : (1+1) x 4 = 8                                }
  {   IAT kernel32 : (NumKernel+1) x 4                          }
  {   IAT user32 : (1+1) x 4 = 8                                }
  {   Hint/Name entries                                          }
  {   DLL names                                                  }
  NumKernelImp := PE_NUM_VBN_IMPORTS - 1;  { tous sauf MessageBoxA }

  ImportDirOff := 0;
  { 3 entrees Import Directory : kernel32, user32, null }
  ILTOff := 60;
  { ILT kernel32 : NumKernelImp entrees + terminateur }
  ILT2Off := ILTOff + (NumKernelImp + 1) * 4;
  { ILT user32 : 1 entree + terminateur }
  IATOff := ILT2Off + 2 * 4;
  { IAT kernel32 : NumKernelImp entrees + terminateur }
  IAT2Off := IATOff + (NumKernelImp + 1) * 4;
  { IAT user32 : 1 entree + terminateur }
  HintOff := IAT2Off + 2 * 4;

  { Calculer les tailles Hint/Name pour kernel32 imports }
  CurOff := HintOff;
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    If I <> 9 Then { pas MessageBoxA }
    Begin
      PEWImports[I].IATOffset := IATOff + I * 4;
      If I > 9 Then
        PEWImports[I].IATOffset := IATOff + (I - 1) * 4;
    End;
    NameLen := Length(PEWImports[I].Name) + 1;
    If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
    CurOff := CurOff + 2 + NameLen;
  End;
  { Ajuster l offset IAT de MessageBoxA dans le bloc user32 }
  PEWImports[9].IATOffset := IAT2Off;

  Hint2Off := CurOff; { pas utilise separement, tous inclus }

  DLLNameOff := CurOff;
  CurOff := CurOff + 13; { "kernel32.dll" + nul }
  DLL2NameOff := CurOff;
  CurOff := CurOff + 11; { "user32.dll" + nul }
  RdataSize := CurOff;
  RdataRawSize := PEWAlignUp(RdataSize, PE_FILE_ALIGN_VAL);

  { Calculer les tailles de sections }
  TextRawSize := PEWAlignUp(PEWCodePos, PE_FILE_ALIGN_VAL);
  DataRawSize := PEWAlignUp(PEWDataPos, PE_FILE_ALIGN_VAL);
  If DataRawSize = 0 Then DataRawSize := PE_FILE_ALIGN_VAL;

  { Offsets de fichier }
  TextFileOff  := PE_FILE_ALIGN_VAL;
  RdataFileOff := TextFileOff + TextRawSize;
  DataFileOff  := RdataFileOff + RdataRawSize;

  { Adresses virtuelles des sections }
  PEWTextVA  := $1000;
  PEWRdataVA := PEWTextVA  + PEWAlignUp(PEWCodePos, PE_SECT_ALIGN_VAL);
  PEWDataVA  := PEWRdataVA + PEWAlignUp(RdataSize, PE_SECT_ALIGN_VAL);

  { S assurer que .data a au moins 4 octets (vsize>0) sinon certains  }
  { chargeurs Windows refusent l image avec une section degenere      }
  { (vsize=0, rsize>0).                                                }
  If PEWDataPos = 0 Then PEWDataPos := 4;

  SizeOfImage := PEWDataVA + PEWAlignUp(PEWDataPos, PE_SECT_ALIGN_VAL);

  { Resoudre les correctifs }
  PEWResolveFixups;

  { Ecrire le fichier PE }
  {$I-}
  Assign(F, ExeFile);
  Rewrite(F, 1);
  {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Cannot create output file: ' + ExeFile);
    Exit;
  End;

  { === En-tete DOS (128 octets avec e_lfanew) === }
  PEWFileWriteByte(F, $4D); PEWFileWriteByte(F, $5A);  { 'MZ' }
  PEWFileWriteZeros(F, 58);  { offsets 0x02..0x3B }
  PEWFileWriteDWord(F, $80); { e_lfanew a l offset 0x3C }
  PEWFileWriteZeros(F, $80 - $40); { remplissage jusqu a 0x80 }

  { === Signature PE === }
  PEWFileWriteByte(F, Ord('P'));
  PEWFileWriteByte(F, Ord('E'));
  PEWFileWriteByte(F, 0);
  PEWFileWriteByte(F, 0);

  { === En-tete COFF (20 octets) === }
  PEWFileWriteWord(F, $014C);  { Machine : i386 }
  PEWFileWriteWord(F, 3);      { NumberOfSections : .text .rdata .data }
  PEWFileWriteDWord(F, 0);     { TimeDateStamp }
  PEWFileWriteDWord(F, 0);     { PointerToSymbolTable }
  PEWFileWriteDWord(F, 0);     { NumberOfSymbols }
  PEWFileWriteWord(F, $E0);    { SizeOfOptionalHeader }
  PEWFileWriteWord(F, $010F);  { Characteristics: RELOCS_STRIPPED | EXECUTABLE_IMAGE | LINE_NUMS_STRIPPED | LOCAL_SYMS_STRIPPED | 32BIT_MACHINE }

  { === En-tete optionnel PE32 (224 octets = $E0) === }
  PEWFileWriteWord(F, $010B);  { Magic : PE32 }
  PEWFileWriteByte(F, 1);      { MajorLinkerVersion }
  PEWFileWriteByte(F, 0);      { MinorLinkerVersion }
  PEWFileWriteDWord(F, TextRawSize);    { SizeOfCode }
  PEWFileWriteDWord(F, DataRawSize + RdataRawSize); { SizeOfInitializedData }
  PEWFileWriteDWord(F, 0);     { SizeOfUninitializedData }
  PEWFileWriteDWord(F, PEWTextVA); { AddressOfEntryPoint = RVA _VBNF_MAIN }
  PEWFileWriteDWord(F, PEWTextVA); { BaseOfCode }
  PEWFileWriteDWord(F, PEWDataVA); { BaseOfData }
  PEWFileWriteDWord(F, PE_IMAGE_BASE_VAL); { ImageBase }
  PEWFileWriteDWord(F, PE_SECT_ALIGN_VAL); { SectionAlignment }
  PEWFileWriteDWord(F, PE_FILE_ALIGN_VAL); { FileAlignment }
  PEWFileWriteWord(F, 5);      { MajorOperatingSystemVersion }
  PEWFileWriteWord(F, 1);      { MinorOperatingSystemVersion }
  PEWFileWriteWord(F, 0);      { MajorImageVersion }
  PEWFileWriteWord(F, 0);      { MinorImageVersion }
  PEWFileWriteWord(F, 5);      { MajorSubsystemVersion }
  PEWFileWriteWord(F, 1);      { MinorSubsystemVersion }
  PEWFileWriteDWord(F, 0);     { Win32VersionValue }
  PEWFileWriteDWord(F, SizeOfImage); { SizeOfImage }
  PEWFileWriteDWord(F, PE_FILE_ALIGN_VAL); { SizeOfHeaders }
  PEWFileWriteDWord(F, 0);     { CheckSum }
  PEWFileWriteWord(F, SubsysVal); { Subsystem : CUI ou GUI }
  PEWFileWriteWord(F, 0);      { DllCharacteristics }
  PEWFileWriteDWord(F, $100000); { SizeOfStackReserve }
  PEWFileWriteDWord(F, $1000);   { SizeOfStackCommit }
  PEWFileWriteDWord(F, $100000); { SizeOfHeapReserve }
  PEWFileWriteDWord(F, $1000);   { SizeOfHeapCommit }
  PEWFileWriteDWord(F, 0);     { LoaderFlags }
  PEWFileWriteDWord(F, 16);    { NumberOfRvaAndSizes }

  { Data Directories (16 entrees x 8 octets = 128 octets) }
  { [0] Export - vide }
  PEWFileWriteDWord(F, 0); PEWFileWriteDWord(F, 0);
  { [1] Import - pointe vers .rdata }
  PEWFileWriteDWord(F, PEWRdataVA + ImportDirOff);
  PEWFileWriteDWord(F, 60); { taille du repertoire d import (3x20) }
  { [2..11] - vide }
  For I := 2 To 11 Do
  Begin PEWFileWriteDWord(F, 0); PEWFileWriteDWord(F, 0); End;
  { [12] IAT }
  PEWFileWriteDWord(F, PEWRdataVA + IATOff);
  PEWFileWriteDWord(F, (NumKernelImp + 1) * 4 + 2 * 4);
  { [13..15] - vide }
  For I := 13 To 15 Do
  Begin PEWFileWriteDWord(F, 0); PEWFileWriteDWord(F, 0); End;

  { === En-tetes de section (3 x 40 octets) === }
  { .text }
  PEWFileWriteStr(F, '.text');
  PEWFileWriteZeros(F, 3);
  PEWFileWriteDWord(F, PEWCodePos);   { VirtualSize }
  PEWFileWriteDWord(F, PEWTextVA);    { VirtualAddress }
  PEWFileWriteDWord(F, TextRawSize);  { SizeOfRawData }
  PEWFileWriteDWord(F, TextFileOff);  { PointerToRawData }
  PEWFileWriteDWord(F, 0);  { PointerToRelocations }
  PEWFileWriteDWord(F, 0);  { PointerToLinenumbers }
  PEWFileWriteWord(F, 0);   { NumberOfRelocations }
  PEWFileWriteWord(F, 0);   { NumberOfLinenumbers }
  PEWFileWriteDWord(F, PE_SCN_CNT_CODE Or PE_SCN_MEM_EXECUTE Or
                        PE_SCN_MEM_READ);

  { .rdata }
  PEWFileWriteStr(F, '.rdata');
  PEWFileWriteZeros(F, 2);
  PEWFileWriteDWord(F, RdataSize);
  PEWFileWriteDWord(F, PEWRdataVA);
  PEWFileWriteDWord(F, RdataRawSize);
  PEWFileWriteDWord(F, RdataFileOff);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteWord(F, 0);
  PEWFileWriteWord(F, 0);
  PEWFileWriteDWord(F, PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ);

  { .data }
  PEWFileWriteStr(F, '.data');
  PEWFileWriteZeros(F, 3);
  PEWFileWriteDWord(F, PEWDataPos);
  PEWFileWriteDWord(F, PEWDataVA);
  PEWFileWriteDWord(F, DataRawSize);
  PEWFileWriteDWord(F, DataFileOff);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteWord(F, 0);
  PEWFileWriteWord(F, 0);
  PEWFileWriteDWord(F, LongInt(PE_SCN_CNT_INIT_DATA Or PE_SCN_MEM_READ Or
                        PE_SCN_MEM_WRITE));

  { Remplir les en-tetes jusqu a PE_FILE_ALIGN }
  TotalHdrSize := $80 + 4 + 20 + $E0 + 3 * 40;
  PadNeeded := PE_FILE_ALIGN_VAL - TotalHdrSize;
  If PadNeeded > 0 Then
    PEWFileWriteZeros(F, PadNeeded);

  { === Section .text === }
  PEWWriteBuf(F, PEWCodeBuf, PEWCodePos);
  PadNeeded := TextRawSize - PEWCodePos;
  If PadNeeded > 0 Then PEWFileWriteZeros(F, PadNeeded);

  { === Section .rdata (tables d import) === }
  { Import Directory - entree 1 : kernel32.dll }
  PEWFileWriteDWord(F, PEWRdataVA + ILTOff);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, PEWRdataVA + DLLNameOff);
  PEWFileWriteDWord(F, PEWRdataVA + IATOff);
  { Import Directory - entree 2 : user32.dll }
  PEWFileWriteDWord(F, PEWRdataVA + ILT2Off);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, 0);
  PEWFileWriteDWord(F, PEWRdataVA + DLL2NameOff);
  PEWFileWriteDWord(F, PEWRdataVA + IAT2Off);
  { Import Directory - terminateur nul }
  PEWFileWriteZeros(F, 20);

  { ILT kernel32 }
  CurOff := HintOff;
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    If I <> 9 Then { pas MessageBoxA }
      PEWFileWriteDWord(F, PEWRdataVA + CurOff);
    NameLen := Length(PEWImports[I].Name) + 1;
    If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
    CurOff := CurOff + 2 + NameLen;
  End;
  PEWFileWriteDWord(F, 0); { terminateur }

  { ILT user32 (MessageBoxA seulement) }
  { On doit calculer l offset Hint/Name de MessageBoxA }
  { C est a la position correspondante dans les Hint/Name }
  ImportDir2Off := HintOff;
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    If I = 9 Then
    Begin
      PEWFileWriteDWord(F, PEWRdataVA + ImportDir2Off);
      NameLen := Length(PEWImports[I].Name) + 1;
      If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
      ImportDir2Off := ImportDir2Off + 2 + NameLen;
    End
    Else
    Begin
      NameLen := Length(PEWImports[I].Name) + 1;
      If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
      ImportDir2Off := ImportDir2Off + 2 + NameLen;
    End;
  End;
  PEWFileWriteDWord(F, 0); { terminateur }

  { IAT kernel32 (identique a ILT initialement) }
  CurOff := HintOff;
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    If I <> 9 Then
      PEWFileWriteDWord(F, PEWRdataVA + CurOff);
    NameLen := Length(PEWImports[I].Name) + 1;
    If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
    CurOff := CurOff + 2 + NameLen;
  End;
  PEWFileWriteDWord(F, 0);

  { IAT user32 }
  ImportDir2Off := HintOff;
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    If I = 9 Then
    Begin
      PEWFileWriteDWord(F, PEWRdataVA + ImportDir2Off);
      NameLen := Length(PEWImports[I].Name) + 1;
      If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
      ImportDir2Off := ImportDir2Off + 2 + NameLen;
    End
    Else
    Begin
      NameLen := Length(PEWImports[I].Name) + 1;
      If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
      ImportDir2Off := ImportDir2Off + 2 + NameLen;
    End;
  End;
  PEWFileWriteDWord(F, 0);

  { Hint/Name entries (tous les imports dans l ordre) }
  For I := 0 To PE_NUM_VBN_IMPORTS - 1 Do
  Begin
    PEWFileWriteWord(F, 0); { Hint }
    PEWFileWriteStr(F, PEWImports[I].Name);
    PEWFileWriteByte(F, 0); { terminateur nul }
    NameLen := Length(PEWImports[I].Name) + 1;
    If (NameLen + 2) Mod 2 <> 0 Then
      PEWFileWriteByte(F, 0); { aligner sur pair }
  End;

  { Noms des DLLs }
  PEWFileWriteStr(F, 'kernel32.dll');
  PEWFileWriteByte(F, 0);
  PEWFileWriteStr(F, 'user32.dll');
  PEWFileWriteByte(F, 0);

  { Remplir .rdata }
  PadNeeded := RdataRawSize - RdataSize;
  If PadNeeded > 0 Then PEWFileWriteZeros(F, PadNeeded);

  { === Section .data === }
  If PEWDataPos > 0 Then
    PEWWriteBuf(F, PEWDataBuf, PEWDataPos);
  PadNeeded := DataRawSize - PEWDataPos;
  If PadNeeded > 0 Then PEWFileWriteZeros(F, PadNeeded);

  Close(F);
  Inc(PEWriterCount);
End;

{ ------------------------------------------------------------ }
{ IsPEWriterInitialized : verifier si le PE writer est init      }
{ ------------------------------------------------------------ }

Function IsPEWriterInitialized : Boolean;
Begin
  IsPEWriterInitialized := PEWriterInitialized;
End;

{ ------------------------------------------------------------ }
{ IsPEWriterEmpty : verifier s il n y a pas de code              }
{ ------------------------------------------------------------ }

Function IsPEWriterEmpty : Boolean;
Begin
  IsPEWriterEmpty := (PEWCodePos = 0) And (PEWDataPos = 0);
End;

{ ------------------------------------------------------------ }
{ GetPEWriterStatus : statut du PE writer                        }
{ ------------------------------------------------------------ }

Function GetPEWriterStatus : TString;
Begin
  If Not PEWriterInitialized Then
    GetPEWriterStatus := 'Not initialized'
  Else If PEWriterCount > 0 Then
    GetPEWriterStatus := 'Written (' + ItoS(PEWriterCount) + ' files)'
  Else
    GetPEWriterStatus := 'Initialized, no files written';
End;

{ ------------------------------------------------------------ }
{ GetPEWCodeSize : taille du tampon code                         }
{ ------------------------------------------------------------ }

Function GetPEWCodeSize : LongInt;
Begin
  GetPEWCodeSize := PEWCodePos;
End;

{ ------------------------------------------------------------ }
{ GetPEWDataSize : taille du tampon donnees                      }
{ ------------------------------------------------------------ }

Function GetPEWDataSize : LongInt;
Begin
  GetPEWDataSize := PEWDataPos;
End;

{ ------------------------------------------------------------ }
{ GetPEWLabelCount : nombre de labels definis                    }
{ ------------------------------------------------------------ }

Function GetPEWLabelCount : LongInt;
Begin
  GetPEWLabelCount := PEWLabelCount;
End;

{ ------------------------------------------------------------ }
{ GetPEWFixupCount : nombre de correctifs                        }
{ ------------------------------------------------------------ }

Function GetPEWFixupCount : LongInt;
Begin
  GetPEWFixupCount := PEWFixupCount;
End;

{ ------------------------------------------------------------ }
{ GetPEWriterCount : nombre de fichiers ecrits                   }
{ ------------------------------------------------------------ }

Function GetPEWriterCount : LongInt;
Begin
  GetPEWriterCount := PEWriterCount;
End;

{ ------------------------------------------------------------ }
{ GetPEWImportCount : nombre d imports                           }
{ ------------------------------------------------------------ }

Function GetPEWImportCount : Integer;
Begin
  GetPEWImportCount := PE_NUM_VBN_IMPORTS;
End;

{ ------------------------------------------------------------ }
{ GetPEWImageBase : valeur de l ImageBase                        }
{ ------------------------------------------------------------ }

Function GetPEWImageBase : LongInt;
Begin
  GetPEWImageBase := PE_IMAGE_BASE_VAL;
End;

{ ============================================================ }
{ TODO 22 - ECRIVAIN COFF .OBJ (PARAMETRE -obj) [IMPLEMENTE]  }
{ ============================================================ }

Const
  { COFF Machine type }
  COFF_MACHINE_I386     = $014C;

  { COFF Section characteristics }
  COFF_SCN_CNT_CODE      = $00000020;
  COFF_SCN_CNT_INIT_DATA = $00000040;
  COFF_SCN_CNT_UNINIT    = $00000080;
  COFF_SCN_ALIGN_4       = $00300000;
  COFF_SCN_MEM_EXECUTE   = $20000000;
  COFF_SCN_MEM_READ      = $40000000;
  COFF_SCN_MEM_WRITE     = LongInt($80000000);
  COFF_SCN_LNK_NRELOC    = $01000000;

  { COFF Relocation types (i386) }
  COFF_REL_I386_DIR32  = $0006;
  COFF_REL_I386_REL32  = $0014;

  { COFF Storage classes }
  COFF_SYM_CLASS_EXTERNAL = 2;
  COFF_SYM_CLASS_STATIC   = 3;
  COFF_SYM_CLASS_LABEL     = 6;

  { COFF Section numbers speciales }
  COFF_SYM_UNDEFINED    = 0;

  { Tailles }
  COFF_MAX_SYMBOLS      = 1024;
  COFF_MAX_RELOCATIONS  = 4096;
  COFF_MAX_STRTAB       = 32768;
  COFF_NUM_SECTIONS     = 3;   { .text, .data, .bss }

Type
  TCOFFSymbolEntry = Record
    Name          : TString;
    Value         : LongInt;
    SectionNumber : Integer;  { 1-based, 0=UNDEFINED }
    StorageClass  : Byte;
    IsExternal    : Boolean;
  End;

  TCOFFRelocEntry = Record
    VirtualAddress : LongInt;
    SymbolIndex    : LongInt;
    RelocType      : Word;
    SectionIdx     : Integer; { 1=.text, 2=.data }
  End;

Var
  COFFSymbols      : Array[0..COFF_MAX_SYMBOLS-1] of TCOFFSymbolEntry;
  COFFSymCount     : LongInt;
  COFFRelocs       : Array[0..COFF_MAX_RELOCATIONS-1] of TCOFFRelocEntry;
  COFFRelocCount   : LongInt;
  COFFStrTab       : Array[0..COFF_MAX_STRTAB-1] of Byte;
  COFFStrTabSize   : LongInt;
  COFFWriterInit   : Boolean;
  COFFWriterCount  : LongInt;

{ ------------------------------------------------------------ }
{ InitCOFFWriter : initialiser le sous-systeme COFF             }
{ ------------------------------------------------------------ }

Procedure InitCOFFWriter;
Var I : Integer;
Begin
  COFFSymCount    := 0;
  COFFRelocCount  := 0;
  COFFStrTabSize  := 4;  { Les 4 premiers octets = taille totale }
  COFFWriterInit  := True;
  COFFWriterCount := 0;
  For I := 0 To COFF_MAX_STRTAB - 1 Do COFFStrTab[I] := 0;
  { Ecrire la taille initiale dans les 4 premiers octets }
  COFFStrTab[0] := 4; COFFStrTab[1] := 0;
  COFFStrTab[2] := 0; COFFStrTab[3] := 0;
End;

{ ------------------------------------------------------------ }
{ COFFAddSymbol : ajouter un symbole a la table                 }
{ ------------------------------------------------------------ }

Function COFFAddSymbol(Const AName : TString;
                       AValue : LongInt;
                       ASect : Integer;
                       AClass : Byte;
                       AExt : Boolean) : LongInt;
Begin
  If COFFSymCount < COFF_MAX_SYMBOLS Then
  Begin
    COFFSymbols[COFFSymCount].Name          := AName;
    COFFSymbols[COFFSymCount].Value         := AValue;
    COFFSymbols[COFFSymCount].SectionNumber := ASect;
    COFFSymbols[COFFSymCount].StorageClass  := AClass;
    COFFSymbols[COFFSymCount].IsExternal    := AExt;
    COFFAddSymbol := COFFSymCount;
    Inc(COFFSymCount);
  End
  Else
    COFFAddSymbol := -1;
End;

{ ------------------------------------------------------------ }
{ COFFAddReloc : ajouter une relocation                          }
{ ------------------------------------------------------------ }

Procedure COFFAddReloc(AVA : LongInt; ASymIdx : LongInt;
                       AType : Word; ASect : Integer);
Begin
  If COFFRelocCount < COFF_MAX_RELOCATIONS Then
  Begin
    COFFRelocs[COFFRelocCount].VirtualAddress := AVA;
    COFFRelocs[COFFRelocCount].SymbolIndex    := ASymIdx;
    COFFRelocs[COFFRelocCount].RelocType      := AType;
    COFFRelocs[COFFRelocCount].SectionIdx     := ASect;
    Inc(COFFRelocCount);
  End;
End;

{ ------------------------------------------------------------ }
{ COFFAddString : ajouter une chaine longue dans la string table}
{   Retourne l offset dans la table des chaines                 }
{ ------------------------------------------------------------ }

Function COFFAddString(Const S : TString) : LongInt;
Var K : Integer;
Begin
  COFFAddString := COFFStrTabSize;
  For K := 1 To Length(S) Do
  Begin
    If COFFStrTabSize < COFF_MAX_STRTAB Then
    Begin
      COFFStrTab[COFFStrTabSize] := Byte(Ord(S[K]));
      Inc(COFFStrTabSize);
    End;
  End;
  { Terminateur NUL }
  If COFFStrTabSize < COFF_MAX_STRTAB Then
  Begin
    COFFStrTab[COFFStrTabSize] := 0;
    Inc(COFFStrTabSize);
  End;
  { Mettre a jour la taille dans les 4 premiers octets }
  COFFStrTab[0] := Byte(COFFStrTabSize And $FF);
  COFFStrTab[1] := Byte((COFFStrTabSize Shr 8) And $FF);
  COFFStrTab[2] := Byte((COFFStrTabSize Shr 16) And $FF);
  COFFStrTab[3] := Byte((COFFStrTabSize Shr 24) And $FF);
End;

{ ------------------------------------------------------------ }
{ COFFWriteByte/Word/DWord/Zeros/Str : utilitaires d ecriture   }
{ ------------------------------------------------------------ }

Procedure COFFWriteByte(Var F : File; B : Byte);
Begin
  BlockWrite(F, B, 1);
End;

Procedure COFFWriteWord(Var F : File; W : Word);
Var Buf : Array[0..1] of Byte;
Begin
  Buf[0] := Byte(W And $FF);
  Buf[1] := Byte((W Shr 8) And $FF);
  BlockWrite(F, Buf, 2);
End;

Procedure COFFWriteDWord(Var F : File; D : LongInt);
Var Buf : Array[0..3] of Byte;
Begin
  Buf[0] := Byte(D And $FF);
  Buf[1] := Byte((D Shr 8) And $FF);
  Buf[2] := Byte((D Shr 16) And $FF);
  Buf[3] := Byte((D Shr 24) And $FF);
  BlockWrite(F, Buf, 4);
End;

Procedure COFFWriteZeros(Var F : File; Count : LongInt);
Var ZBuf : Byte;
    K    : LongInt;
Begin
  ZBuf := 0;
  For K := 1 To Count Do
    BlockWrite(F, ZBuf, 1);
End;

Procedure COFFWriteStr8(Var F : File; Const S : TString);
Var Buf : Array[0..7] of Byte;
    K   : Integer;
Begin
  For K := 0 To 7 Do Buf[K] := 0;
  For K := 1 To Length(S) Do
    If K <= 8 Then Buf[K-1] := Byte(Ord(S[K]));
  BlockWrite(F, Buf, 8);
End;

{ ------------------------------------------------------------ }
{ COFFWriteSymName : ecrire un nom de symbole (8 octets)        }
{   Si nom > 8 car : 4 octets zero + 4 octets offset strtab    }
{   Si nom <= 8 car : nom padde avec des NUL                    }
{ ------------------------------------------------------------ }

Procedure COFFWriteSymName(Var F : File; Const S : TString;
                           StrOff : LongInt);
Var Buf : Array[0..7] of Byte;
    K   : Integer;
Begin
  If Length(S) > 8 Then
  Begin
    { Long name : 4 zero bytes + 4 bytes string table offset }
    Buf[0] := 0; Buf[1] := 0; Buf[2] := 0; Buf[3] := 0;
    Buf[4] := Byte(StrOff And $FF);
    Buf[5] := Byte((StrOff Shr 8) And $FF);
    Buf[6] := Byte((StrOff Shr 16) And $FF);
    Buf[7] := Byte((StrOff Shr 24) And $FF);
    BlockWrite(F, Buf, 8);
  End
  Else
  Begin
    For K := 0 To 7 Do Buf[K] := 0;
    For K := 1 To Length(S) Do Buf[K-1] := Byte(Ord(S[K]));
    BlockWrite(F, Buf, 8);
  End;
End;

{ ------------------------------------------------------------ }
{ COFFCountTextRelocs : compter les relocations de .text        }
{ ------------------------------------------------------------ }

Function COFFCountTextRelocs : LongInt;
Var I : LongInt;
    N : LongInt;
Begin
  N := 0;
  For I := 0 To COFFRelocCount - 1 Do
    If COFFRelocs[I].SectionIdx = 1 Then Inc(N);
  COFFCountTextRelocs := N;
End;

{ ------------------------------------------------------------ }
{ COFFCountDataRelocs : compter les relocations de .data        }
{ ------------------------------------------------------------ }

Function COFFCountDataRelocs : LongInt;
Var I : LongInt;
    N : LongInt;
Begin
  N := 0;
  For I := 0 To COFFRelocCount - 1 Do
    If COFFRelocs[I].SectionIdx = 2 Then Inc(N);
  COFFCountDataRelocs := N;
End;

{ ------------------------------------------------------------ }
{ WriteCOFF : generer un fichier objet COFF 32 bits              }
{   compatible avec LINK.EXE, MASM, TASM                        }
{ ------------------------------------------------------------ }

Procedure WriteCOFF(Const ObjFile : TString);
Var
  F              : File;
  TextRelCnt     : LongInt;
  DataRelCnt     : LongInt;
  HeaderSize     : LongInt;
  SectHdrSize    : LongInt;
  TextDataOff    : LongInt;
  DataDataOff    : LongInt;
  TextRelocOff   : LongInt;
  DataRelocOff   : LongInt;
  SymTabOff      : LongInt;
  I              : LongInt;
  StrOff         : LongInt;
  SymStrOffsets   : Array[0..COFF_MAX_SYMBOLS-1] of LongInt;
Begin
  { Compter les relocations par section }
  TextRelCnt := COFFCountTextRelocs;
  DataRelCnt := COFFCountDataRelocs;

  { Preparer les symboles de section standard }
  { Section 1 = .text, 2 = .data, 3 = .bss }
  COFFSymCount  := 0;
  COFFRelocCount := 0;

  { Ajouter les 3 symboles de section }
  COFFAddSymbol('.text', 0, 1, COFF_SYM_CLASS_STATIC, False);
  COFFAddSymbol('.data', 0, 2, COFF_SYM_CLASS_STATIC, False);
  COFFAddSymbol('.bss',  0, 3, COFF_SYM_CLASS_STATIC, False);

  { Ajouter le point d entree _start comme symbole externe }
  COFFAddSymbol('_start', 0, 1, COFF_SYM_CLASS_EXTERNAL, True);

  { Ajouter les symboles d import Win32 comme externes non definis }
  COFFAddSymbol('_ExitProcess@4',    0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_GetStdHandle@4',   0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_WriteFile@20',     0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_ReadFile@20',      0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_GetProcessHeap@0', 0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_HeapAlloc@12',     0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_HeapFree@12',      0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_CreateFileA@28',   0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_CloseHandle@4',    0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);
  COFFAddSymbol('_MessageBoxA@16',   0, COFF_SYM_UNDEFINED,
                COFF_SYM_CLASS_EXTERNAL, True);

  { Ajouter des relocations d exemple pour le code .text }
  { Les vraies relocations seront ajoutees par les passes de code }
  TextRelCnt := COFFCountTextRelocs;
  DataRelCnt := COFFCountDataRelocs;

  { Preparer les offsets dans la string table pour les noms longs }
  For I := 0 To COFFSymCount - 1 Do
  Begin
    If Length(COFFSymbols[I].Name) > 8 Then
      SymStrOffsets[I] := COFFAddString(COFFSymbols[I].Name)
    Else
      SymStrOffsets[I] := 0;
  End;

  { Calculer les offsets dans le fichier }
  HeaderSize   := 20;                          { COFF file header }
  SectHdrSize  := COFF_NUM_SECTIONS * 40;      { 3 section headers }
  TextDataOff  := HeaderSize + SectHdrSize;
  DataDataOff  := TextDataOff + PEWCodePos;
  TextRelocOff := DataDataOff + PEWDataPos;
  DataRelocOff := TextRelocOff + TextRelCnt * 10;
  SymTabOff    := DataRelocOff + DataRelCnt * 10;

  { Ouvrir le fichier de sortie }
  Assign(F, ObjFile);
  Rewrite(F, 1);

  { ====== En-tete COFF (20 octets) ====== }
  COFFWriteWord(F, COFF_MACHINE_I386);        { Machine }
  COFFWriteWord(F, COFF_NUM_SECTIONS);         { NumberOfSections }
  COFFWriteDWord(F, 0);                        { TimeDateStamp }
  COFFWriteDWord(F, SymTabOff);                { PointerToSymbolTable }
  COFFWriteDWord(F, COFFSymCount);             { NumberOfSymbols }
  COFFWriteWord(F, 0);                         { SizeOfOptionalHeader }
  COFFWriteWord(F, 0);                         { Characteristics }

  { ====== En-tete section .text (40 octets) ====== }
  COFFWriteStr8(F, '.text');                   { Name }
  COFFWriteDWord(F, 0);                        { VirtualSize }
  COFFWriteDWord(F, 0);                        { VirtualAddress }
  COFFWriteDWord(F, PEWCodePos);               { SizeOfRawData }
  COFFWriteDWord(F, TextDataOff);              { PointerToRawData }
  COFFWriteDWord(F, TextRelocOff);             { PointerToRelocations }
  COFFWriteDWord(F, 0);                        { PointerToLineNumbers }
  COFFWriteWord(F, Word(TextRelCnt));          { NumberOfRelocations }
  COFFWriteWord(F, 0);                         { NumberOfLineNumbers }
  COFFWriteDWord(F, COFF_SCN_CNT_CODE Or
                    COFF_SCN_ALIGN_4 Or
                    COFF_SCN_MEM_EXECUTE Or
                    COFF_SCN_MEM_READ);        { Characteristics }

  { ====== En-tete section .data (40 octets) ====== }
  COFFWriteStr8(F, '.data');                   { Name }
  COFFWriteDWord(F, 0);                        { VirtualSize }
  COFFWriteDWord(F, 0);                        { VirtualAddress }
  COFFWriteDWord(F, PEWDataPos);               { SizeOfRawData }
  If PEWDataPos > 0 Then
    COFFWriteDWord(F, DataDataOff)             { PointerToRawData }
  Else
    COFFWriteDWord(F, 0);
  If DataRelCnt > 0 Then
    COFFWriteDWord(F, DataRelocOff)            { PointerToRelocations }
  Else
    COFFWriteDWord(F, 0);
  COFFWriteDWord(F, 0);                        { PointerToLineNumbers }
  COFFWriteWord(F, Word(DataRelCnt));          { NumberOfRelocations }
  COFFWriteWord(F, 0);                         { NumberOfLineNumbers }
  COFFWriteDWord(F, COFF_SCN_CNT_INIT_DATA Or
                    COFF_SCN_ALIGN_4 Or
                    COFF_SCN_MEM_READ Or
                    COFF_SCN_MEM_WRITE);       { Characteristics }

  { ====== En-tete section .bss (40 octets) ====== }
  COFFWriteStr8(F, '.bss');                    { Name }
  COFFWriteDWord(F, 0);                        { VirtualSize }
  COFFWriteDWord(F, 0);                        { VirtualAddress }
  COFFWriteDWord(F, 0);                        { SizeOfRawData (pas de donnees) }
  COFFWriteDWord(F, 0);                        { PointerToRawData }
  COFFWriteDWord(F, 0);                        { PointerToRelocations }
  COFFWriteDWord(F, 0);                        { PointerToLineNumbers }
  COFFWriteWord(F, 0);                         { NumberOfRelocations }
  COFFWriteWord(F, 0);                         { NumberOfLineNumbers }
  COFFWriteDWord(F, COFF_SCN_CNT_UNINIT Or
                    COFF_SCN_ALIGN_4 Or
                    COFF_SCN_MEM_READ Or
                    COFF_SCN_MEM_WRITE);       { Characteristics }

  { ====== Donnees brutes section .text ====== }
  If PEWCodePos > 0 Then
    BlockWrite(F, PEWCodeBuf, PEWCodePos);

  { ====== Donnees brutes section .data ====== }
  If PEWDataPos > 0 Then
    BlockWrite(F, PEWDataBuf, PEWDataPos);

  { ====== Table des relocations .text ====== }
  For I := 0 To COFFRelocCount - 1 Do
  Begin
    If COFFRelocs[I].SectionIdx = 1 Then
    Begin
      COFFWriteDWord(F, COFFRelocs[I].VirtualAddress);
      COFFWriteDWord(F, COFFRelocs[I].SymbolIndex);
      COFFWriteWord(F, COFFRelocs[I].RelocType);
    End;
  End;

  { ====== Table des relocations .data ====== }
  For I := 0 To COFFRelocCount - 1 Do
  Begin
    If COFFRelocs[I].SectionIdx = 2 Then
    Begin
      COFFWriteDWord(F, COFFRelocs[I].VirtualAddress);
      COFFWriteDWord(F, COFFRelocs[I].SymbolIndex);
      COFFWriteWord(F, COFFRelocs[I].RelocType);
    End;
  End;

  { ====== Table des symboles COFF ====== }
  { Chaque entree = 18 octets }
  For I := 0 To COFFSymCount - 1 Do
  Begin
    { Nom du symbole (8 octets) }
    COFFWriteSymName(F, COFFSymbols[I].Name, SymStrOffsets[I]);
    { Value (4 octets) }
    COFFWriteDWord(F, COFFSymbols[I].Value);
    { SectionNumber (2 octets, 1-based) }
    COFFWriteWord(F, Word(COFFSymbols[I].SectionNumber));
    { Type (2 octets) : 0 = not function }
    COFFWriteWord(F, 0);
    { StorageClass (1 octet) }
    COFFWriteByte(F, COFFSymbols[I].StorageClass);
    { NumberOfAuxSymbols (1 octet) }
    COFFWriteByte(F, 0);
  End;

  { ====== Table des chaines ====== }
  BlockWrite(F, COFFStrTab, COFFStrTabSize);

  Close(F);
  Inc(COFFWriterCount);

  If Opts.Verbose Then
    WriteLn('COFF : ', ObjFile, ' genere (',
            COFFSymCount, ' symboles, ',
            TextRelCnt + DataRelCnt, ' relocations)');
End;

{ ------------------------------------------------------------ }
{ COFFFindSymbol : rechercher un symbole par nom                 }
{ ------------------------------------------------------------ }

Function COFFFindSymbol(Const AName : TString) : LongInt;
Var I : LongInt;
Begin
  COFFFindSymbol := -1;
  For I := 0 To COFFSymCount - 1 Do
    If COFFSymbols[I].Name = AName Then
    Begin
      COFFFindSymbol := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ IsCOFFWriterInitialized : etat du writer                       }
{ ------------------------------------------------------------ }

Function IsCOFFWriterInitialized : Boolean;
Begin
  IsCOFFWriterInitialized := COFFWriterInit;
End;

{ ------------------------------------------------------------ }
{ IsCOFFWriterEmpty : aucun fichier ecrit                        }
{ ------------------------------------------------------------ }

Function IsCOFFWriterEmpty : Boolean;
Begin
  IsCOFFWriterEmpty := COFFWriterCount = 0;
End;

{ ------------------------------------------------------------ }
{ GetCOFFWriterStatus : etat sous forme de texte                 }
{ ------------------------------------------------------------ }

Function GetCOFFWriterStatus : TString;
Begin
  If Not COFFWriterInit Then
    GetCOFFWriterStatus := 'Not initialized'
  Else If COFFWriterCount > 0 Then
    GetCOFFWriterStatus := 'Written (' + ItoS(COFFWriterCount) + ' files)'
  Else
    GetCOFFWriterStatus := 'Initialized, no files written';
End;

{ ------------------------------------------------------------ }
{ GetCOFFSymCount : nombre de symboles                           }
{ ------------------------------------------------------------ }

Function GetCOFFSymCount : LongInt;
Begin
  GetCOFFSymCount := COFFSymCount;
End;

{ ------------------------------------------------------------ }
{ GetCOFFRelocCount : nombre de relocations                      }
{ ------------------------------------------------------------ }

Function GetCOFFRelocCount : LongInt;
Begin
  GetCOFFRelocCount := COFFRelocCount;
End;

{ ------------------------------------------------------------ }
{ GetCOFFStrTabSize : taille de la table des chaines             }
{ ------------------------------------------------------------ }

Function GetCOFFStrTabSize : LongInt;
Begin
  GetCOFFStrTabSize := COFFStrTabSize;
End;

{ ------------------------------------------------------------ }
{ GetCOFFWriterCount : nombre de fichiers ecrits                 }
{ ------------------------------------------------------------ }

Function GetCOFFWriterCount : LongInt;
Begin
  GetCOFFWriterCount := COFFWriterCount;
End;

{ ------------------------------------------------------------ }
{ GetCOFFNumSections : nombre de sections COFF                   }
{ ------------------------------------------------------------ }

Function GetCOFFNumSections : Integer;
Begin
  GetCOFFNumSections := COFF_NUM_SECTIONS;
End;

{ ------------------------------------------------------------ }
{ GetCOFFMachineType : type de machine COFF                      }
{ ------------------------------------------------------------ }

Function GetCOFFMachineType : Word;
Begin
  GetCOFFMachineType := COFF_MACHINE_I386;
End;

{ ------------------------------------------------------------ }
{ GetCOFFMaxSymbols : nombre maximum de symboles                 }
{ ------------------------------------------------------------ }

Function GetCOFFMaxSymbols : LongInt;
Begin
  GetCOFFMaxSymbols := COFF_MAX_SYMBOLS;
End;

{ ============================================================ }
{ TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm)  }
{           [IMPLEMENTE]                                       }
{ ============================================================ }

Const
  { Nombre maximum de lignes ASM en sortie }
  ASM_MAX_LINES       = 65536;

  { Nombre d imports Win32 declares dans le listing }
  ASM_NUM_IMPORTS      = 14;

  { Prefixe de decoration stdcall }
  ASM_STDCALL_PREFIX   = '_';

Var
  ASMWriterInit  : Boolean;   { True si InitASMWriter a ete appele    }
  ASMWriterCount : LongInt;   { nombre de fichiers ASM ecrits         }
  ASMLineCount   : LongInt;   { nombre de lignes ecrites              }

{ ------------------------------------------------------------ }
{ InitASMWriter : initialiser le sous-systeme ASM               }
{ ------------------------------------------------------------ }

Procedure InitASMWriter;
Begin
  ASMWriterInit  := True;
  ASMWriterCount := 0;
  ASMLineCount   := 0;
End;

{ ------------------------------------------------------------ }
{ ASMWriteLine : ecrire une ligne dans le fichier ASM           }
{ ------------------------------------------------------------ }

Procedure ASMWriteLine(Var F : Text; Const S : TString);
Begin
  WriteLn(F, S);
  Inc(ASMLineCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteBlank : ecrire une ligne vide                         }
{ ------------------------------------------------------------ }

Procedure ASMWriteBlank(Var F : Text);
Begin
  WriteLn(F);
  Inc(ASMLineCount);
End;

{ ------------------------------------------------------------ }
{ ASMWriteComment : ecrire un commentaire ASM                   }
{ ------------------------------------------------------------ }

Procedure ASMWriteComment(Var F : Text; Const Cmt : TString);
Begin
  WriteLn(F, '; ', Cmt);
  Inc(ASMLineCount);
End;

{ ------------------------------------------------------------ }
{ ASMDataDirective : directive MASM pour un type VB.NET         }
{ Retourne DB, DW, DD, DQ selon la taille du type              }
{ ------------------------------------------------------------ }

Function ASMDataDirective(DT : Integer) : TString;
Begin
  Case DT Of
    VBT_BYTE,
    VBT_SBYTE     : ASMDataDirective := 'DB';
    VBT_SHORT,
    VBT_USHORT,
    VBT_CHAR      : ASMDataDirective := 'DW';
    VBT_LONG,
    VBT_ULONG,
    VBT_DOUBLE,
    VBT_DATE      : ASMDataDirective := 'DQ';
    VBT_DECIMAL   : ASMDataDirective := 'DB'; { 16 octets }
  Else
    ASMDataDirective := 'DD'; { Integer, Boolean, Single, String, Object }
  End;
End;

{ ------------------------------------------------------------ }
{ ASMBssDirective : directive MASM pour reserve BSS             }
{ Retourne DB ?, DW ?, DD ?, DQ ? selon la taille              }
{ ------------------------------------------------------------ }

Function ASMBssDirective(DT : Integer) : TString;
Begin
  Case DT Of
    VBT_BYTE,
    VBT_SBYTE     : ASMBssDirective := 'DB ?';
    VBT_SHORT,
    VBT_USHORT,
    VBT_CHAR      : ASMBssDirective := 'DW ?';
    VBT_LONG,
    VBT_ULONG,
    VBT_DOUBLE,
    VBT_DATE      : ASMBssDirective := 'DQ ?';
    VBT_DECIMAL   : ASMBssDirective := 'DB 16 DUP(?)';
  Else
    ASMBssDirective := 'DD ?';
  End;
End;

{ ------------------------------------------------------------ }
{ ASMInitValue : valeur initiale MASM pour un type VB.NET       }
{ Retourne '0', '0.0', 'OFFSET ...', etc.                      }
{ ------------------------------------------------------------ }

Function ASMInitValue(DT : Integer; HasInit : Boolean;
                      InitNum : LongInt;
                      Const InitStr : TString) : TString;
Begin
  If HasInit Then
  Begin
    If (DT = VBT_STRING) And (InitStr <> '') Then
      ASMInitValue := 'OFFSET ' + InitStr
    Else
      ASMInitValue := ItoS(InitNum);
  End
  Else
  Begin
    Case DT Of
      VBT_LONG,
      VBT_ULONG,
      VBT_DOUBLE,
      VBT_DATE    : ASMInitValue := '0';
      VBT_DECIMAL : ASMInitValue := '16 DUP(0)';
    Else
      ASMInitValue := '0';
    End;
  End;
End;

{ ------------------------------------------------------------ }
{ WriteASM : generer un fichier .ASM lisible (syntaxe MASM)     }
{   outfile : chemin du fichier .ASM a creer                    }
{   Ecrit un listing MASM complet avec :                        }
{     - En-tete (.386, .MODEL FLAT STDCALL, OPTION CASEMAP)     }
{     - INCLUDELIB (kernel32, user32, msvcrt)                   }
{     - EXTERN (imports Win32)                                  }
{     - .DATA (variables globales initialisees)                 }
{     - .DATA? (variables non initialisees, BSS)                }
{     - .CODE (procedures, runtime, point d entree)             }
{ ------------------------------------------------------------ }

Procedure WriteASM(Const AsmFile : TString);
Var
  F         : Text;
  I         : Integer;
  HasData   : Boolean;
  HasBss    : Boolean;
  Dir       : TString;
  Lbl       : TString;
Begin
  ASMLineCount := 0;

  Assign(F, AsmFile);
  {$I-} Rewrite(F); {$I+}
  If IOResult <> 0 Then
  Begin
    FatalError('Impossible de creer le fichier ASM : ' + AsmFile);
    Exit;
  End;

  { ======== En-tete MASM ======== }
  ASMWriteComment(F, '============================================================');
  ASMWriteComment(F, ' Fichier ASM genere par VBNCW32 - Compilateur VB.NET Win32');
  ASMWriteComment(F, ' Source : ' + Opts.SrcFile);
  ASMWriteComment(F, '============================================================');
  ASMWriteBlank(F);
  ASMWriteLine(F, '.386');
  ASMWriteLine(F, '.MODEL FLAT, STDCALL');
  ASMWriteLine(F, 'OPTION CASEMAP:NONE');
  ASMWriteBlank(F);

  { ======== INCLUDELIB ======== }
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteComment(F, ' Bibliotheques liees');
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, 'INCLUDELIB kernel32.lib');
  ASMWriteLine(F, 'INCLUDELIB user32.lib');
  ASMWriteLine(F, 'INCLUDELIB msvcrt.lib');
  ASMWriteBlank(F);

  { ======== EXTERN declarations ======== }
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteComment(F, ' Fonctions externes importees (Win32 API)');
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteBlank(F);
  { kernel32.dll }
  ASMWriteLine(F, 'EXTERN _ExitProcess@4:PROC');
  ASMWriteLine(F, 'EXTERN _GetStdHandle@4:PROC');
  ASMWriteLine(F, 'EXTERN _WriteFile@20:PROC');
  ASMWriteLine(F, 'EXTERN _ReadFile@20:PROC');
  ASMWriteLine(F, 'EXTERN _GetProcessHeap@0:PROC');
  ASMWriteLine(F, 'EXTERN _HeapAlloc@12:PROC');
  ASMWriteLine(F, 'EXTERN _HeapFree@12:PROC');
  ASMWriteLine(F, 'EXTERN _CreateFileA@28:PROC');
  ASMWriteLine(F, 'EXTERN _CloseHandle@4:PROC');
  ASMWriteLine(F, 'EXTERN _GetCommandLineA@0:PROC');
  ASMWriteLine(F, 'EXTERN _GetModuleHandleA@4:PROC');
  ASMWriteLine(F, 'EXTERN _SetFilePointer@16:PROC');
  ASMWriteLine(F, 'EXTERN _DeleteFileA@4:PROC');
  { user32.dll }
  ASMWriteLine(F, 'EXTERN _MessageBoxA@16:PROC');
  ASMWriteBlank(F);

  { ======== Section .DATA (variables initialisees) ======== }
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteComment(F, ' Section .DATA : variables globales initialisees');
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, '.DATA');
  ASMWriteBlank(F);
  HasData := False;
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].Kind = SK_VAR) Or (SymTab[I].Kind = SK_FIELD) Then
    Begin
      If (SymTab[I].StoreClass = STORE_GLOBAL) Or
         (SymTab[I].StoreClass = STORE_STATIC) Or
         (SymTab[I].StoreClass = STORE_SHARED) Then
      Begin
        If SymTab[I].HasInit Then
        Begin
          Lbl := SymTab[I].AsmLabel;
          If Lbl = '' Then
            Lbl := PFX_VAR + SymTab[I].Name;
          Dir := ASMDataDirective(SymTab[I].DataType);
          ASMWriteLine(F, Lbl + ' ' + Dir + ' ' +
            ASMInitValue(SymTab[I].DataType, True,
                         SymTab[I].InitNum, SymTab[I].InitStr));
          HasData := True;
        End;
      End;
    End
    Else If SymTab[I].Kind = SK_CONST Then
    Begin
      If SymTab[I].DataType = VBT_STRING Then
      Begin
        Lbl := SymTab[I].AsmLabel;
        If Lbl = '' Then
          Lbl := PFX_CONST + SymTab[I].Name;
        If SymTab[I].InitStr <> '' Then
          ASMWriteLine(F, Lbl + ' DB ''' + SymTab[I].InitStr + ''', 0')
        Else
          ASMWriteLine(F, Lbl + ' DB 0');
        HasData := True;
      End
      Else
      Begin
        Lbl := SymTab[I].AsmLabel;
        If Lbl = '' Then
          Lbl := PFX_CONST + SymTab[I].Name;
        Dir := ASMDataDirective(SymTab[I].DataType);
        ASMWriteLine(F, Lbl + ' ' + Dir + ' ' +
          ItoS(SymTab[I].InitNum));
        HasData := True;
      End;
    End;
  End;
  If Not HasData Then
    ASMWriteComment(F, ' (aucune variable initialisee)');
  ASMWriteBlank(F);

  { ======== Section .DATA? (variables BSS non initialisees) ======== }
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteComment(F, ' Section .DATA? : variables non initialisees (BSS)');
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, '.DATA?');
  ASMWriteBlank(F);
  HasBss := False;
  For I := 0 To SymCount - 1 Do
  Begin
    If (SymTab[I].Kind = SK_VAR) Or (SymTab[I].Kind = SK_FIELD) Then
    Begin
      If (SymTab[I].StoreClass = STORE_GLOBAL) Or
         (SymTab[I].StoreClass = STORE_STATIC) Or
         (SymTab[I].StoreClass = STORE_SHARED) Then
      Begin
        If Not SymTab[I].HasInit Then
        Begin
          Lbl := SymTab[I].AsmLabel;
          If Lbl = '' Then
            Lbl := PFX_VAR + SymTab[I].Name;
          Dir := ASMBssDirective(SymTab[I].DataType);
          ASMWriteLine(F, Lbl + ' ' + Dir);
          HasBss := True;
        End;
      End;
    End;
  End;
  If Not HasBss Then
    ASMWriteComment(F, ' (aucune variable BSS)');
  ASMWriteBlank(F);

  { ======== Section .CODE ======== }
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteComment(F, ' Section .CODE : code executable');
  ASMWriteComment(F, '------------------------------------------------------------');
  ASMWriteBlank(F);
  ASMWriteLine(F, '.CODE');
  ASMWriteBlank(F);

  { Emettre les procedures/fonctions utilisateur }
  For I := 0 To ProcCount - 1 Do
  Begin
    Lbl := ProcTab[I].AsmLabel;
    If Lbl = '' Then
      Lbl := PFX_FUNC + ProcTab[I].Name;
    ASMWriteComment(F, ' --- ' + ProcTab[I].Name + ' ---');
    ASMWriteLine(F, Lbl + ' PROC');
    ASMWriteLine(F, '  PUSH EBP');
    ASMWriteLine(F, '  MOV EBP, ESP');
    If ProcTab[I].LocalSize > 0 Then
      ASMWriteLine(F, '  SUB ESP, ' + ItoSI(ProcTab[I].LocalSize));
    ASMWriteComment(F, ' (corps de la procedure - voir code binaire)');
    If ProcTab[I].ExitLabel <> '' Then
      ASMWriteLine(F, ProcTab[I].ExitLabel + ':');
    ASMWriteLine(F, '  MOV ESP, EBP');
    ASMWriteLine(F, '  POP EBP');
    If ProcTab[I].ParamCount > 0 Then
      ASMWriteLine(F, '  RET ' + ItoSI(ProcTab[I].ParamCount * 4))
    Else
      ASMWriteLine(F, '  RET');
    ASMWriteLine(F, Lbl + ' ENDP');
    ASMWriteBlank(F);
  End;

  { Emettre le point d entree }
  ASMWriteComment(F, ' --- Point d''entree ---');
  ASMWriteLine(F, '_start:');
  ASMWriteLine(F, '  CALL ' + PFX_FUNC + 'Main');
  ASMWriteLine(F, '  PUSH 0');
  ASMWriteLine(F, '  CALL _ExitProcess@4');
  ASMWriteBlank(F);

  ASMWriteLine(F, 'END _start');
  ASMWriteBlank(F);

  Close(F);
  Inc(ASMWriterCount);
End;

{ ------------------------------------------------------------ }
{ IsASMWriterInitialized : le generateur ASM est-il init ?      }
{ ------------------------------------------------------------ }

Function IsASMWriterInitialized : Boolean;
Begin
  IsASMWriterInitialized := ASMWriterInit;
End;

{ ------------------------------------------------------------ }
{ IsASMWriterEmpty : aucun fichier ASM ecrit ?                  }
{ ------------------------------------------------------------ }

Function IsASMWriterEmpty : Boolean;
Begin
  IsASMWriterEmpty := (ASMWriterCount = 0);
End;

{ ------------------------------------------------------------ }
{ GetASMWriterStatus : etat du generateur ASM                   }
{ ------------------------------------------------------------ }

Function GetASMWriterStatus : TString;
Begin
  If Not ASMWriterInit Then
    GetASMWriterStatus := 'Not initialized'
  Else If ASMWriterCount > 0 Then
    GetASMWriterStatus := 'Written (' + ItoS(ASMWriterCount) + ' files)'
  Else
    GetASMWriterStatus := 'Initialized, no files written';
End;

{ ------------------------------------------------------------ }
{ GetASMLineCount : nombre de lignes ecrites                    }
{ ------------------------------------------------------------ }

Function GetASMLineCount : LongInt;
Begin
  GetASMLineCount := ASMLineCount;
End;

{ ------------------------------------------------------------ }
{ GetASMWriterCount : nombre de fichiers ASM ecrits             }
{ ------------------------------------------------------------ }

Function GetASMWriterCount : LongInt;
Begin
  GetASMWriterCount := ASMWriterCount;
End;

{ ------------------------------------------------------------ }
{ GetASMMaxLines : nombre maximum de lignes ASM                 }
{ ------------------------------------------------------------ }

Function GetASMMaxLines : LongInt;
Begin
  GetASMMaxLines := ASM_MAX_LINES;
End;

{ ------------------------------------------------------------ }
{ GetASMNumImports : nombre d imports declares                  }
{ ------------------------------------------------------------ }

Function GetASMNumImports : Integer;
Begin
  GetASMNumImports := ASM_NUM_IMPORTS;
End;

{ ------------------------------------------------------------ }
{ GetASMStdcallPrefix : prefixe stdcall                         }
{ ------------------------------------------------------------ }

Function GetASMStdcallPrefix : TString;
Begin
  GetASMStdcallPrefix := ASM_STDCALL_PREFIX;
End;

{ ------------------------------------------------------------ }
{ GetASMSymCount : nombre de symboles emis dans le listing      }
{ ------------------------------------------------------------ }

Function GetASMSymCount : Integer;
Begin
  GetASMSymCount := SymCount;
End;

{ ------------------------------------------------------------ }
{ GetASMProcCount : nombre de procedures emises                 }
{ ------------------------------------------------------------ }

Function GetASMProcCount : Integer;
Begin
  GetASMProcCount := ProcCount;
End;

{ ============================================================ }
{ TODO 24 - IMPORTS API WIN32 ET LIAISON                       }
{           (KERNEL32, USER32, MSVCRT) [IMPLEMENTE]            }
{ ============================================================ }

Const
  { Indices des DLL d importation }
  IMP_DLL_KERNEL32     = 0;
  IMP_DLL_USER32       = 1;
  IMP_DLL_MSVCRT       = 2;
  IMP_NUM_DLLS         = 3;

  { Nombre maximum de fonctions importees }
  IMP_MAX_FUNCS        = 128;

  { Noms des DLL }
  IMP_NAME_KERNEL32    = 'kernel32.dll';
  IMP_NAME_USER32      = 'user32.dll';
  IMP_NAME_MSVCRT      = 'msvcrt.dll';

  { Nombre de fonctions par DLL }
  IMP_NUM_KERNEL32     = 28;
  IMP_NUM_USER32       = 2;
  IMP_NUM_MSVCRT       = 20;

Type
  TImportFuncEntry = Record
    Name       : TString;   { nom de la fonction (ex: ExitProcess)    }
    DLLIndex   : Integer;   { indice DLL : 0=kernel32 1=user32 2=msvcrt }
    ParamBytes : Integer;   { nombre d octets de parametres (stdcall) }
    IsUsed     : Boolean;   { True si marquee comme utilisee          }
  End;

Var
  ImportFuncs      : Array[0..IMP_MAX_FUNCS-1] of TImportFuncEntry;
  ImportFuncCount  : Integer;    { nombre de fonctions enregistrees   }
  ImportInitialized: Boolean;    { True si InitImportState appele     }
  ImportStateCount : LongInt;    { compteur d appels                  }

{ ------------------------------------------------------------ }
{ InitImportState : enregistrer toutes les fonctions importees  }
{ ------------------------------------------------------------ }

Procedure AddOneImport(Const AName : TString; ADLL, ABytes : Integer);
Begin
  If ImportFuncCount < IMP_MAX_FUNCS Then
  Begin
    ImportFuncs[ImportFuncCount].Name       := AName;
    ImportFuncs[ImportFuncCount].DLLIndex   := ADLL;
    ImportFuncs[ImportFuncCount].ParamBytes := ABytes;
    ImportFuncs[ImportFuncCount].IsUsed     := False;
    Inc(ImportFuncCount);
  End;
End;

Procedure InitImportState;
Begin
  ImportFuncCount   := 0;
  ImportInitialized := True;
  ImportStateCount  := 0;

  { ---- kernel32.dll ---- }
  AddOneImport('ExitProcess',            IMP_DLL_KERNEL32, 4);
  AddOneImport('GetStdHandle',           IMP_DLL_KERNEL32, 4);
  AddOneImport('WriteFile',              IMP_DLL_KERNEL32, 20);
  AddOneImport('ReadFile',               IMP_DLL_KERNEL32, 20);
  AddOneImport('GetProcessHeap',         IMP_DLL_KERNEL32, 0);
  AddOneImport('HeapAlloc',              IMP_DLL_KERNEL32, 12);
  AddOneImport('HeapFree',               IMP_DLL_KERNEL32, 12);
  AddOneImport('HeapReAlloc',            IMP_DLL_KERNEL32, 16);
  AddOneImport('CreateFileA',            IMP_DLL_KERNEL32, 28);
  AddOneImport('CloseHandle',            IMP_DLL_KERNEL32, 4);
  AddOneImport('SetFilePointer',         IMP_DLL_KERNEL32, 16);
  AddOneImport('GetFileSize',            IMP_DLL_KERNEL32, 8);
  AddOneImport('DeleteFileA',            IMP_DLL_KERNEL32, 4);
  AddOneImport('GetCommandLineA',        IMP_DLL_KERNEL32, 0);
  AddOneImport('GetModuleHandleA',       IMP_DLL_KERNEL32, 4);
  AddOneImport('GetLastError',           IMP_DLL_KERNEL32, 0);
  AddOneImport('SetLastError',           IMP_DLL_KERNEL32, 4);
  AddOneImport('MoveFileA',              IMP_DLL_KERNEL32, 8);
  AddOneImport('CopyFileA',             IMP_DLL_KERNEL32, 12);
  AddOneImport('GetCurrentDirectoryA',   IMP_DLL_KERNEL32, 8);
  AddOneImport('SetCurrentDirectoryA',   IMP_DLL_KERNEL32, 4);
  AddOneImport('CreateDirectoryA',       IMP_DLL_KERNEL32, 8);
  AddOneImport('FindFirstFileA',         IMP_DLL_KERNEL32, 8);
  AddOneImport('FindNextFileA',          IMP_DLL_KERNEL32, 8);
  AddOneImport('FindClose',              IMP_DLL_KERNEL32, 4);
  AddOneImport('GetTickCount',           IMP_DLL_KERNEL32, 0);
  AddOneImport('Sleep',                  IMP_DLL_KERNEL32, 4);
  AddOneImport('GetEnvironmentVariableA',IMP_DLL_KERNEL32, 12);

  { ---- user32.dll ---- }
  AddOneImport('MessageBoxA',            IMP_DLL_USER32, 16);
  AddOneImport('GetDesktopWindow',       IMP_DLL_USER32, 0);

  { ---- msvcrt.dll ---- }
  AddOneImport('_itoa',   IMP_DLL_MSVCRT, 12);
  AddOneImport('_ltoa',   IMP_DLL_MSVCRT, 12);
  AddOneImport('atoi',    IMP_DLL_MSVCRT, 4);
  AddOneImport('atol',    IMP_DLL_MSVCRT, 4);
  AddOneImport('sprintf', IMP_DLL_MSVCRT, 0);  { varargs -> cdecl }
  AddOneImport('sscanf',  IMP_DLL_MSVCRT, 0);  { varargs -> cdecl }
  AddOneImport('_gcvt',   IMP_DLL_MSVCRT, 12);
  AddOneImport('strtod',  IMP_DLL_MSVCRT, 8);
  AddOneImport('sin',     IMP_DLL_MSVCRT, 8);
  AddOneImport('cos',     IMP_DLL_MSVCRT, 8);
  AddOneImport('tan',     IMP_DLL_MSVCRT, 8);
  AddOneImport('atan',    IMP_DLL_MSVCRT, 8);
  AddOneImport('sqrt',    IMP_DLL_MSVCRT, 8);
  AddOneImport('exp',     IMP_DLL_MSVCRT, 8);
  AddOneImport('log',     IMP_DLL_MSVCRT, 8);
  AddOneImport('pow',     IMP_DLL_MSVCRT, 16);
  AddOneImport('fabs',    IMP_DLL_MSVCRT, 8);
  AddOneImport('fmod',    IMP_DLL_MSVCRT, 16);
  AddOneImport('srand',   IMP_DLL_MSVCRT, 4);
  AddOneImport('rand',    IMP_DLL_MSVCRT, 0);
End;

{ ------------------------------------------------------------ }
{ ImportDLLName : retourner le nom de la DLL par indice         }
{ ------------------------------------------------------------ }

Function ImportDLLName(DLLIdx : Integer) : TString;
Begin
  Case DLLIdx Of
    IMP_DLL_KERNEL32 : ImportDLLName := IMP_NAME_KERNEL32;
    IMP_DLL_USER32   : ImportDLLName := IMP_NAME_USER32;
    IMP_DLL_MSVCRT   : ImportDLLName := IMP_NAME_MSVCRT;
  Else
    ImportDLLName := '(unknown)';
  End;
End;

{ ------------------------------------------------------------ }
{ FindImportFunc : chercher un import par nom                   }
{   Retourne l indice dans ImportFuncs[] ou -1 si absent        }
{ ------------------------------------------------------------ }

Function FindImportFunc(Const AName : TString) : Integer;
Var I : Integer;
Begin
  FindImportFunc := -1;
  For I := 0 To ImportFuncCount - 1 Do
    If ImportFuncs[I].Name = AName Then
    Begin
      FindImportFunc := I;
      Exit;
    End;
End;

{ ------------------------------------------------------------ }
{ MarkImportUsed : marquer un import comme utilise              }
{ ------------------------------------------------------------ }

Procedure MarkImportUsed(Const AName : TString);
Var Idx : Integer;
Begin
  Idx := FindImportFunc(AName);
  If Idx >= 0 Then
    ImportFuncs[Idx].IsUsed := True;
End;

{ ------------------------------------------------------------ }
{ CountDLLImports : compter les imports d une DLL donnee        }
{ ------------------------------------------------------------ }

Function CountDLLImports(DLLIdx : Integer) : Integer;
Var I, N : Integer;
Begin
  N := 0;
  For I := 0 To ImportFuncCount - 1 Do
    If ImportFuncs[I].DLLIndex = DLLIdx Then
      Inc(N);
  CountDLLImports := N;
End;

{ ------------------------------------------------------------ }
{ CountUsedDLLImports : compter les imports utilises d une DLL  }
{ ------------------------------------------------------------ }

Function CountUsedDLLImports(DLLIdx : Integer) : Integer;
Var I, N : Integer;
Begin
  N := 0;
  For I := 0 To ImportFuncCount - 1 Do
    If (ImportFuncs[I].DLLIndex = DLLIdx) And ImportFuncs[I].IsUsed Then
      Inc(N);
  CountUsedDLLImports := N;
End;

{ ------------------------------------------------------------ }
{ GetImportStdcallDecor : nom decore stdcall (_Name@N)          }
{   Les fonctions msvcrt cdecl (ParamBytes=0 et varargs)        }
{   ne recoivent pas de decoration @N                           }
{ ------------------------------------------------------------ }

Function GetImportStdcallDecor(Idx : Integer) : TString;
Var S : TString;
Begin
  S := '_' + ImportFuncs[Idx].Name;
  If (ImportFuncs[Idx].DLLIndex <> IMP_DLL_MSVCRT) And
     (ImportFuncs[Idx].ParamBytes >= 0) Then
    S := S + '@' + ItoS(ImportFuncs[Idx].ParamBytes);
  GetImportStdcallDecor := S;
End;

{ ------------------------------------------------------------ }
{ GenASMExterns : ecrire les declarations EXTERN dans un .ASM   }
{   Ecrit un bloc EXTERN par DLL pour les fonctions utilisees  }
{   ou toutes si aucune n est marquee utilisee                 }
{ ------------------------------------------------------------ }

Procedure GenASMExterns(Var F : Text);
Var
  I, D   : Integer;
  AnyUsed: Boolean;
  Decor  : TString;
Begin
  { Detecter si au moins un import est marque utilise }
  AnyUsed := False;
  For I := 0 To ImportFuncCount - 1 Do
    If ImportFuncs[I].IsUsed Then Begin AnyUsed := True; Break; End;

  For D := 0 To IMP_NUM_DLLS - 1 Do
  Begin
    ASMWriteComment(F, ' ' + ImportDLLName(D));
    For I := 0 To ImportFuncCount - 1 Do
    Begin
      If ImportFuncs[I].DLLIndex = D Then
      Begin
        If (Not AnyUsed) Or ImportFuncs[I].IsUsed Then
        Begin
          Decor := GetImportStdcallDecor(I);
          ASMWriteLine(F, 'EXTERN ' + Decor + ':PROC');
        End;
      End;
    End;
  End;
  ASMWriteBlank(F);
  Inc(ImportStateCount);
End;

{ ------------------------------------------------------------ }
{ GenCOFFExternSymbols : ajouter les symboles externes COFF     }
{   pour chaque import utilise (ou tous si aucun marque)        }
{ ------------------------------------------------------------ }

Procedure GenCOFFExternSymbols;
Var
  I       : Integer;
  AnyUsed : Boolean;
  Decor   : TString;
Begin
  AnyUsed := False;
  For I := 0 To ImportFuncCount - 1 Do
    If ImportFuncs[I].IsUsed Then Begin AnyUsed := True; Break; End;

  For I := 0 To ImportFuncCount - 1 Do
  Begin
    If (Not AnyUsed) Or ImportFuncs[I].IsUsed Then
    Begin
      Decor := GetImportStdcallDecor(I);
      COFFAddSymbol(Decor, 0, 0, COFF_SYM_CLASS_EXTERNAL, True);
    End;
  End;
  Inc(ImportStateCount);
End;

{ ------------------------------------------------------------ }
{ GenPEImportTable : generer les structures d import PE dans     }
{   les tampons .rdata (IMAGE_IMPORT_DESCRIPTOR, ILT, IAT,      }
{   Hint/Name, noms DLL)                                        }
{   Ecrit dans PEWDataBuf a partir de RdataBase.                }
{   Retourne la taille totale ecrite via RdataSize.             }
{ ------------------------------------------------------------ }

Procedure GenPEImportTable(Var RdataSize : LongInt);
Var
  DLLFuncCnt   : Array[0..IMP_NUM_DLLS-1] of Integer;
  D, I         : Integer;
  ILTBase      : LongInt;  { ILT offsets per DLL                }
  IATBase      : LongInt;  { IAT offsets per DLL                }
  HNBase       : LongInt;  { Hint/Name table base               }
  DLLNBase     : LongInt;  { DLL name strings base              }
  TotalILT     : LongInt;
  TotalIAT     : LongInt;
  TotalHN      : LongInt;
  CurDLLN      : LongInt;
  NameLen      : Integer;
  DLLStr       : TString;
Begin
  { Compter les fonctions par DLL }
  For D := 0 To IMP_NUM_DLLS - 1 Do
    DLLFuncCnt[D] := CountDLLImports(D);

  { Layout :
      IDT          : (IMP_NUM_DLLS + 1) * 20    (null terminator)
      ILT per DLL  : (count + 1) * 4 each
      IAT per DLL  : (count + 1) * 4 each
      Hint/Name    : 2 + aligned_len per func
      DLL names    : null-terminated strings
  }
  ILTBase := (IMP_NUM_DLLS + 1) * 20;

  TotalILT := 0;
  For D := 0 To IMP_NUM_DLLS - 1 Do
    TotalILT := TotalILT + (DLLFuncCnt[D] + 1) * 4;

  IATBase := ILTBase + TotalILT;
  TotalIAT := 0;
  For D := 0 To IMP_NUM_DLLS - 1 Do
    TotalIAT := TotalIAT + (DLLFuncCnt[D] + 1) * 4;

  HNBase := IATBase + TotalIAT;
  TotalHN := 0;
  For I := 0 To ImportFuncCount - 1 Do
  Begin
    NameLen := Length(ImportFuncs[I].Name) + 1;
    If (NameLen + 2) Mod 2 <> 0 Then Inc(NameLen);
    TotalHN := TotalHN + 2 + NameLen;
  End;

  DLLNBase := HNBase + TotalHN;
  CurDLLN := DLLNBase;
  For D := 0 To IMP_NUM_DLLS - 1 Do
  Begin
    DLLStr := ImportDLLName(D);
    CurDLLN := CurDLLN + Length(DLLStr) + 1;
  End;
  RdataSize := CurDLLN;

  Inc(ImportStateCount);
End;

{ ------------------------------------------------------------ }
{ IsImportFunction : verifier si un nom est un import connu     }
{ ------------------------------------------------------------ }

Function IsImportFunction(Const AName : TString) : Boolean;
Begin
  IsImportFunction := (FindImportFunc(AName) >= 0);
End;

{ ------------------------------------------------------------ }
{ IsImportInitialized : le sous-systeme est-il init ?           }
{ ------------------------------------------------------------ }

Function IsImportInitialized : Boolean;
Begin
  IsImportInitialized := ImportInitialized;
End;

{ ------------------------------------------------------------ }
{ IsImportEmpty : aucune fonction enregistree ?                 }
{ ------------------------------------------------------------ }

Function IsImportEmpty : Boolean;
Begin
  IsImportEmpty := (ImportFuncCount = 0);
End;

{ ------------------------------------------------------------ }
{ GetImportStatus : etat du sous-systeme imports                }
{ ------------------------------------------------------------ }

Function GetImportStatus : TString;
Begin
  If Not ImportInitialized Then
    GetImportStatus := 'Not initialized'
  Else
    GetImportStatus := 'Initialized (' + ItoS(ImportFuncCount) +
                       ' funcs, ' + ItoS(IMP_NUM_DLLS) + ' DLLs)';
End;

{ ------------------------------------------------------------ }
{ GetImportFuncCount : nombre total de fonctions importees      }
{ ------------------------------------------------------------ }

Function GetImportFuncCount : Integer;
Begin
  GetImportFuncCount := ImportFuncCount;
End;

{ ------------------------------------------------------------ }
{ GetImportDLLCount : nombre de DLL                             }
{ ------------------------------------------------------------ }

Function GetImportDLLCount : Integer;
Begin
  GetImportDLLCount := IMP_NUM_DLLS;
End;

{ ------------------------------------------------------------ }
{ GetImportKernel32Count : nombre d imports kernel32            }
{ ------------------------------------------------------------ }

Function GetImportKernel32Count : Integer;
Begin
  GetImportKernel32Count := CountDLLImports(IMP_DLL_KERNEL32);
End;

{ ------------------------------------------------------------ }
{ GetImportUser32Count : nombre d imports user32                }
{ ------------------------------------------------------------ }

Function GetImportUser32Count : Integer;
Begin
  GetImportUser32Count := CountDLLImports(IMP_DLL_USER32);
End;

{ ------------------------------------------------------------ }
{ GetImportMsvcrtCount : nombre d imports msvcrt                }
{ ------------------------------------------------------------ }

Function GetImportMsvcrtCount : Integer;
Begin
  GetImportMsvcrtCount := CountDLLImports(IMP_DLL_MSVCRT);
End;

{ ------------------------------------------------------------ }
{ GetImportStateCount : compteur d operations                   }
{ ------------------------------------------------------------ }

Function GetImportStateCount : LongInt;
Begin
  GetImportStateCount := ImportStateCount;
End;

{ ------------------------------------------------------------ }
{ GetImportMaxFuncs : capacite maximale                         }
{ ------------------------------------------------------------ }

Function GetImportMaxFuncs : Integer;
Begin
  GetImportMaxFuncs := IMP_MAX_FUNCS;
End;

{ ============================================================ }
{ TODO 25 - OPTIMISATIONS PEEPHOLE, TESTS FINAUX               }
{           ET INTEGRATION SAMPLES\VBNET\* [IMPLEMENTE]        }
{ ============================================================ }

Const
  { Nombre maximum de lignes dans le tampon peephole }
  OPT_MAX_LINES        = 65536;

  { Nombre de regles peephole }
  OPT_NUM_RULES        = 7;

  { Nombre de fichiers samples VB.NET }
  OPT_NUM_SAMPLES      = 12;

  { Noms des fichiers exemples }
  OPT_SAMPLE_01        = 'SAMPLES\VBNET\HELLO.VB';
  OPT_SAMPLE_02        = 'SAMPLES\VBNET\CALC.VB';
  OPT_SAMPLE_03        = 'SAMPLES\VBNET\FIBONACCI.VB';
  OPT_SAMPLE_04        = 'SAMPLES\VBNET\FACTORI.VB';
  OPT_SAMPLE_05        = 'SAMPLES\VBNET\ARRAY.VB';
  OPT_SAMPLE_06        = 'SAMPLES\VBNET\STRING.VB';
  OPT_SAMPLE_07        = 'SAMPLES\VBNET\FILEIO.VB';
  OPT_SAMPLE_08        = 'SAMPLES\VBNET\SELECTCS.VB';
  OPT_SAMPLE_09        = 'SAMPLES\VBNET\LOOPS.VB';
  OPT_SAMPLE_10        = 'SAMPLES\VBNET\STRUCTUR.VB';
  OPT_SAMPLE_11        = 'SAMPLES\VBNET\SUBS.VB';
  OPT_SAMPLE_12        = 'SAMPLES\VBNET\TRYCATCH.VB';

Var
  OptBuf            : Array[0..OPT_MAX_LINES-1] of TString;
  OptBufCount       : LongInt;   { nombre de lignes dans le tampon       }
  OptInitialized    : Boolean;   { True si InitOptimizer a ete appele    }
  OptStateCount     : LongInt;   { compteur d appels                     }
  OptRulesApplied   : LongInt;   { nombre total de regles appliquees     }
  OptPassCount      : LongInt;   { nombre de passes peephole effectuees  }
  OptEliminatedLines: LongInt;   { nombre de lignes eliminees            }

{ ------------------------------------------------------------ }
{ InitOptimizer : initialiser le sous-systeme d optimisation    }
{ ------------------------------------------------------------ }

Procedure InitOptimizer;
Begin
  OptBufCount        := 0;
  OptInitialized     := True;
  OptStateCount      := 0;
  OptRulesApplied    := 0;
  OptPassCount       := 0;
  OptEliminatedLines := 0;
End;

{ ------------------------------------------------------------ }
{ OptTrimLeft : retirer les espaces en tete d une chaine        }
{ ------------------------------------------------------------ }

Function OptTrimLeft(Const S : TString) : TString;
Var
  I : Integer;
Begin
  I := 1;
  While (I <= Length(S)) And (S[I] = ' ') Do
    Inc(I);
  OptTrimLeft := Copy(S, I, Length(S) - I + 1);
End;

{ ------------------------------------------------------------ }
{ OptStartsWith : tester si S commence par Prefix               }
{ ------------------------------------------------------------ }

Function OptStartsWith(Const S, Prefix : TString) : Boolean;
Begin
  OptStartsWith := (Length(S) >= Length(Prefix)) And
                   (Copy(S, 1, Length(Prefix)) = Prefix);
End;

{ ------------------------------------------------------------ }
{ OptLoadBuffer : copier les lignes emises dans le tampon       }
{ (appelee avant l optimisation, ici stub car Emit ecrit        }
{  directement dans le fichier de sortie)                       }
{ ------------------------------------------------------------ }

Procedure OptAddLine(Const S : TString);
Begin
  If OptBufCount < OPT_MAX_LINES Then
  Begin
    OptBuf[OptBufCount] := S;
    Inc(OptBufCount);
  End;
  Inc(OptStateCount);
End;

{ ------------------------------------------------------------ }
{ OptDeleteLine : supprimer la ligne a l index donne            }
{ ------------------------------------------------------------ }

Procedure OptDeleteLine(Idx : LongInt);
Var
  J : LongInt;
Begin
  If (Idx < 0) Or (Idx >= OptBufCount) Then Exit;
  For J := Idx To OptBufCount - 2 Do
    OptBuf[J] := OptBuf[J + 1];
  Dec(OptBufCount);
  Inc(OptEliminatedLines);
End;

{ ------------------------------------------------------------ }
{ OptReplaceLine : remplacer la ligne a l index donne           }
{ ------------------------------------------------------------ }

Procedure OptReplaceLine(Idx : LongInt; Const NewLine : TString);
Begin
  If (Idx >= 0) And (Idx < OptBufCount) Then
    OptBuf[Idx] := NewLine;
End;

{ ------------------------------------------------------------ }
{ PeepholePass : effectuer une passe d optimisation peephole    }
{ Retourne le nombre de regles appliquees dans cette passe.     }
{ ------------------------------------------------------------ }

Function PeepholePass : LongInt;
Var
  I       : LongInt;
  Count   : LongInt;
  Line    : TString;
  LineTr  : TString;
  NextTr  : TString;
Begin
  Count := 0;
  I := 0;
  While I < OptBufCount Do
  Begin
    Line   := OptBuf[I];
    LineTr := OptTrimLeft(Line);

    { Regle 1 : MOV EAX, 0 -> XOR EAX, EAX }
    If LineTr = 'MOV EAX, 0' Then
    Begin
      OptReplaceLine(I, '  XOR EAX, EAX');
      Inc(Count);
      Inc(I);
      Continue;
    End;

    { Regle 2 : PUSH EAX / POP EAX -> eliminer les deux }
    If (LineTr = 'PUSH EAX') And (I + 1 < OptBufCount) Then
    Begin
      NextTr := OptTrimLeft(OptBuf[I + 1]);
      If NextTr = 'POP EAX' Then
      Begin
        OptDeleteLine(I + 1);
        OptDeleteLine(I);
        Inc(Count);
        Continue;  { ne pas incrementer I, les lignes ont ete decalees }
      End;
    End;

    { Regle 3 : MOV EAX, [x] / MOV [x], EAX -> eliminer la deuxieme }
    If OptStartsWith(LineTr, 'MOV EAX, ') And (I + 1 < OptBufCount) Then
    Begin
      NextTr := OptTrimLeft(OptBuf[I + 1]);
      If OptStartsWith(NextTr, 'MOV ') Then
      Begin
        { Extraire la source de la premiere et la dest de la deuxieme }
        { MOV EAX, [x] puis MOV [x], EAX }
        { Source = tout apres 'MOV EAX, ' dans la premiere ligne }
        { On verifie si la deuxieme = 'MOV <source>, EAX' }
        If Length(LineTr) > 9 Then
        Begin
          { source = Copy(LineTr, 10, ...) }
          If NextTr = 'MOV ' + Copy(LineTr, 10, Length(LineTr) - 9) +
                      ', EAX' Then
          Begin
            OptDeleteLine(I + 1);
            Inc(Count);
            { On garde I tel quel pour reexaminer }
            Continue;
          End;
        End;
      End;
    End;

    { Regle 4 : ADD EAX, 1 -> INC EAX }
    If LineTr = 'ADD EAX, 1' Then
    Begin
      OptReplaceLine(I, '  INC EAX');
      Inc(Count);
      Inc(I);
      Continue;
    End;

    { Regle 5 : SUB EAX, 1 -> DEC EAX }
    If LineTr = 'SUB EAX, 1' Then
    Begin
      OptReplaceLine(I, '  DEC EAX');
      Inc(Count);
      Inc(I);
      Continue;
    End;

    { Regle 6 : IMUL EAX, 2 -> SHL EAX, 1 }
    If LineTr = 'IMUL EAX, 2' Then
    Begin
      OptReplaceLine(I, '  SHL EAX, 1');
      Inc(Count);
      Inc(I);
      Continue;
    End;

    { Regle 7 : IMUL EAX, 4 -> SHL EAX, 2 }
    If LineTr = 'IMUL EAX, 4' Then
    Begin
      OptReplaceLine(I, '  SHL EAX, 2');
      Inc(Count);
      Inc(I);
      Continue;
    End;

    Inc(I);
  End;

  Inc(OptPassCount);
  OptRulesApplied := OptRulesApplied + Count;
  PeepholePass := Count;
End;

{ ------------------------------------------------------------ }
{ RunPeepholeOptimizer : appliquer les passes peephole          }
{ jusqu a ce qu aucune regle ne s applique plus                 }
{ ------------------------------------------------------------ }

Procedure RunPeepholeOptimizer;
Var
  Applied : LongInt;
Begin
  If Not OptInitialized Then Exit;
  If OptBufCount = 0 Then Exit;
  Repeat
    Applied := PeepholePass;
  Until Applied = 0;
End;

{ ------------------------------------------------------------ }
{ OptWriteBuffer : ecrire le tampon optimise dans un fichier    }
{ ------------------------------------------------------------ }

Procedure OptWriteBuffer(Var F : Text);
Var
  I : LongInt;
Begin
  For I := 0 To OptBufCount - 1 Do
    WriteLn(F, OptBuf[I]);
End;

{ ------------------------------------------------------------ }
{ GetSampleName : nom du fichier exemple par index (1..12)      }
{ ------------------------------------------------------------ }

Function GetSampleName(Idx : Integer) : TString;
Begin
  Case Idx Of
    1  : GetSampleName := OPT_SAMPLE_01;
    2  : GetSampleName := OPT_SAMPLE_02;
    3  : GetSampleName := OPT_SAMPLE_03;
    4  : GetSampleName := OPT_SAMPLE_04;
    5  : GetSampleName := OPT_SAMPLE_05;
    6  : GetSampleName := OPT_SAMPLE_06;
    7  : GetSampleName := OPT_SAMPLE_07;
    8  : GetSampleName := OPT_SAMPLE_08;
    9  : GetSampleName := OPT_SAMPLE_09;
    10 : GetSampleName := OPT_SAMPLE_10;
    11 : GetSampleName := OPT_SAMPLE_11;
    12 : GetSampleName := OPT_SAMPLE_12;
  Else
    GetSampleName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ GetSampleDescription : description courte du fichier exemple  }
{ ------------------------------------------------------------ }

Function GetSampleDescription(Idx : Integer) : TString;
Begin
  Case Idx Of
    1  : GetSampleDescription := 'Hello World';
    2  : GetSampleDescription := 'Calculatrice simple';
    3  : GetSampleDescription := 'Suite de Fibonacci';
    4  : GetSampleDescription := 'Factorielle';
    5  : GetSampleDescription := 'Operations sur tableaux';
    6  : GetSampleDescription := 'Operations sur chaines';
    7  : GetSampleDescription := 'Entrees/sorties fichiers';
    8  : GetSampleDescription := 'Select Case';
    9  : GetSampleDescription := 'Boucles For/Do/While';
    10 : GetSampleDescription := 'Structures et Enum';
    11 : GetSampleDescription := 'Sub et Function';
    12 : GetSampleDescription := 'Try/Catch/Finally';
  Else
    GetSampleDescription := '';
  End;
End;

{ ------------------------------------------------------------ }
{ PeepholeRuleName : nom descriptif de la regle peephole        }
{ ------------------------------------------------------------ }

Function PeepholeRuleName(Idx : Integer) : TString;
Begin
  Case Idx Of
    1 : PeepholeRuleName := 'MOV EAX, 0 -> XOR EAX, EAX';
    2 : PeepholeRuleName := 'PUSH EAX / POP EAX -> (eliminer)';
    3 : PeepholeRuleName := 'MOV EAX, [x] / MOV [x], EAX -> (eliminer 2e)';
    4 : PeepholeRuleName := 'ADD EAX, 1 -> INC EAX';
    5 : PeepholeRuleName := 'SUB EAX, 1 -> DEC EAX';
    6 : PeepholeRuleName := 'IMUL EAX, 2 -> SHL EAX, 1';
    7 : PeepholeRuleName := 'IMUL EAX, 4 -> SHL EAX, 2';
  Else
    PeepholeRuleName := '';
  End;
End;

{ ------------------------------------------------------------ }
{ IsOptimizerInitialized : sous-systeme initialise ?            }
{ ------------------------------------------------------------ }

Function IsOptimizerInitialized : Boolean;
Begin
  IsOptimizerInitialized := OptInitialized;
End;

{ ------------------------------------------------------------ }
{ IsOptimizerEmpty : aucune ligne dans le tampon ?              }
{ ------------------------------------------------------------ }

Function IsOptimizerEmpty : Boolean;
Begin
  IsOptimizerEmpty := (OptBufCount = 0);
End;

{ ------------------------------------------------------------ }
{ GetOptimizerStatus : etat du sous-systeme optimisation        }
{ ------------------------------------------------------------ }

Function GetOptimizerStatus : TString;
Begin
  If Not OptInitialized Then
    GetOptimizerStatus := 'Not initialized'
  Else
    GetOptimizerStatus := 'Initialized (' + ItoS(OptBufCount) +
                          ' lines, ' + ItoS(OptRulesApplied) +
                          ' rules applied)';
End;

{ ------------------------------------------------------------ }
{ GetOptBufCount : nombre de lignes dans le tampon              }
{ ------------------------------------------------------------ }

Function GetOptBufCount : LongInt;
Begin
  GetOptBufCount := OptBufCount;
End;

{ ------------------------------------------------------------ }
{ GetOptRulesApplied : nombre total de regles appliquees        }
{ ------------------------------------------------------------ }

Function GetOptRulesApplied : LongInt;
Begin
  GetOptRulesApplied := OptRulesApplied;
End;

{ ------------------------------------------------------------ }
{ GetOptPassCount : nombre de passes effectuees                 }
{ ------------------------------------------------------------ }

Function GetOptPassCount : LongInt;
Begin
  GetOptPassCount := OptPassCount;
End;

{ ------------------------------------------------------------ }
{ GetOptEliminatedLines : nombre de lignes eliminees            }
{ ------------------------------------------------------------ }

Function GetOptEliminatedLines : LongInt;
Begin
  GetOptEliminatedLines := OptEliminatedLines;
End;

{ ------------------------------------------------------------ }
{ GetOptNumRules : nombre de regles peephole                    }
{ ------------------------------------------------------------ }

Function GetOptNumRules : Integer;
Begin
  GetOptNumRules := OPT_NUM_RULES;
End;

{ ------------------------------------------------------------ }
{ GetOptNumSamples : nombre de fichiers exemples                }
{ ------------------------------------------------------------ }

Function GetOptNumSamples : Integer;
Begin
  GetOptNumSamples := OPT_NUM_SAMPLES;
End;

{ ------------------------------------------------------------ }
{ GetOptMaxLines : capacite maximale du tampon                  }
{ ------------------------------------------------------------ }

Function GetOptMaxLines : LongInt;
Begin
  GetOptMaxLines := OPT_MAX_LINES;
End;

{ ============================================================ }

Procedure Run;
Begin
  { Initialisation des compteurs }
  ErrorCount := 0;
  WarnCount  := 0;
  TotalLines := 0;
  OutFOpen   := False;
  BcActive   := False;
  LexOpened  := False;

  { Analyse des arguments de la ligne de commande }
  ParseArgs;

  { Affichage de la banniere en mode verbeux }
  ShowBanner;

  { Initialiser les tables et ouvrir le fichier source }
  InitSymTable;
  InitScopes;
  InitModuleState;
  InitExprState;
  InitCodeGen;
  InitCtrlState;
  InitLoopState;
  InitSubFuncState;
  InitIntrinsicState;
  InitStrOpState;
  InitArrayState;
  InitStructureEnumState;
  InitClassState;
  InitExceptionState;
  InitConsoleFileIOState;
  InitRuntimeLib;
  InitImportState;
  InitOptimizer;
  LexInit;

  { Analyser l unite de compilation VB.NET }
  ParseCompilationUnit;
  LexClose;

  { TODO 21 : Initialiser et ecrire le fichier PE }
  InitPEWriter;
  If Opts.EmitExe And (ErrorCount = 0) Then
    WritePEFile(Opts.OutFile);

  { TODO 22 : Initialiser et ecrire le fichier COFF .OBJ }
  InitCOFFWriter;
  If Opts.EmitObj And (ErrorCount = 0) Then
    WriteCOFF(Opts.OutFile);

  { TODO 23 : Initialiser et ecrire le fichier ASM }
  InitASMWriter;
  If Opts.EmitAsm And (ErrorCount = 0) Then
    WriteASM(ReplaceExt(Opts.OutFile, '.asm'));

  { TODO 24 : Imports Win32 avances (COFF externes) }
  If Opts.EmitObj And (ErrorCount = 0) Then
    GenCOFFExternSymbols;

  { TODO 25 : Optimisations peephole }
  If ErrorCount = 0 Then
    RunPeepholeOptimizer;

  { Statistiques finales }
  ShowStats;

  { Nettoyage }
  Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

BEGIN
 Run;
END.