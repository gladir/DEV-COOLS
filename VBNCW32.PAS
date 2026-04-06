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

  TODO 03 - RECONNAISSANCE DES MOTS-CLES VISUAL BASIC .NET [A FAIRE]
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

  TODO 04 - TABLE DES SYMBOLES (32 BITS) [A FAIRE]
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

  TODO 05 - GESTION DES PORTEES (NAMESPACE, MODULE, CLASS, STRUCTURE) [A FAIRE]
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

  TODO 06 - PARSEUR : IMPORTS, NAMESPACE ET MODULE [A FAIRE]
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

  TODO 07 - PARSEUR : DECLARATIONS (DIM, PUBLIC, PRIVATE, CONST) [A FAIRE]
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

  TODO 08 - PARSEUR : EXPRESSIONS ARITHMETIQUES ET LOGIQUES (32 BITS) [A FAIRE]
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

  TODO 09 - GENERATION DE CODE : OPERATIONS ARITHMETIQUES 80386 [A FAIRE]
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
  CurTokType := TOK_IDENT;
  CurTokNum  := 0;
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
{ Procedure principale : Run                                   }
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

  { Ouvrir et tokeniser le fichier source }
  LexInit;
  LexNextToken;
  While CurTokType <> TOK_EOF Do
    LexNextToken;
  LexClose;

  { TODO 03..25 : Compilation, generation de code, etc. }

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
