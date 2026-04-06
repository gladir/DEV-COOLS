{ @author: Sylvain Maltais (support@gladir.com)
  @created: 2026
  @version: 0.1
  @website(https://www.gladir.com/dev-cools)
  @abstract(Target: Free Pascal 3.2)
  @description: Compilateur Visual Basic .NET vers assembleur 80386 pour Windows 32 bits
  @license: MIT
}

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

  TODO 10 - PARSEUR : STRUCTURES DE CONTROLE (IF, SELECT CASE) [A FAIRE]
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

  TODO 11 - PARSEUR : BOUCLES (FOR/NEXT, DO/LOOP, WHILE/END WHILE, FOR EACH) [A FAIRE]
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

  TODO 12 - PARSEUR : SUB ET FUNCTION (PROCEDURES ET FONCTIONS) [A FAIRE]
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

  TODO 13 - PARSEUR : FONCTIONS INTRINSEQUES ET METHODES SYSTEME [A FAIRE]
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

  TODO 14 - PARSEUR : OPERATIONS SUR CHAINES ET CLASSE STRING [A FAIRE]
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

  TODO 15 - PARSEUR : TABLEAUX (DIM, REDIM, ERASE) [A FAIRE]
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

  TODO 16 - PARSEUR : STRUCTURES (STRUCTURE...END STRUCTURE) ET ENUM [A FAIRE]
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

  TODO 17 - PARSEUR : CLASSES ET HERITAGE (CLASS, INHERITS, IMPLEMENTS) [A FAIRE]
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

  TODO 18 - PARSEUR : GESTION DES EXCEPTIONS (TRY/CATCH/FINALLY/THROW) [A FAIRE]
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

  TODO 19 - PARSEUR : E/S CONSOLE ET FICHIERS [A FAIRE]
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

  TODO 20 - BIBLIOTHEQUE RUNTIME (CHAINES, CONVERSION, E/S VIA WIN32 API) [A FAIRE]
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

  TODO 21 - ECRIVAIN BINAIRE PE (GENERATION .EXE WINDOWS 32 BITS) [A FAIRE]
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

  TODO 22 - ECRIVAIN COFF .OBJ (PARAMETRE -obj) [A FAIRE]
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

  TODO 23 - GENERATEUR DE LISTING ASSEMBLEUR (PARAMETRE -asm) [A FAIRE]
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

  TODO 24 - IMPORTS API WIN32 ET LIAISON (KERNEL32, USER32, MSVCRT) [A FAIRE]
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

  TODO 25 - OPTIMISATIONS, TESTS FINAUX ET INTEGRATION SAMPLES\VBNET\* [A FAIRE]
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

  { Mots-cles contextuels }
  KW_ASSEMBLY        = 195;
  KW_AUTO            = 196;
  KW_ANSI            = 197;
  KW_UNICODE         = 198;
  KW_PRESERVE        = 199;

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
  LexInit;

  { Analyser l unite de compilation VB.NET }
  ParseCompilationUnit;
  LexClose;

  { TODO 10..25 : Generation de code, etc. }

  { Statistiques finales }
  ShowStats;

  { Nettoyage }
  Cleanup;
End;

{ ============================================================ }
{ Programme principal                                          }
{ ============================================================ }

Begin
  Run;
End.
